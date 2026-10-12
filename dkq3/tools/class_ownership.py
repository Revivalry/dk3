"""Class-ownership lint for the native Zig runtime.

Shared modules implement mechanisms; concrete actor, weapon, item and map-entity classes own their
policy (docs/runtime-zig.md "Class contract", src/README.md). Ownership follows the source tree:

  src/classes/<actors|weapons|items|entities>/<class>/...  -> class-owned; its line-2 header must be
                                                              `//! <kind>-class: <class>`
  src/engine, src/core                                    -> game-agnostic layers (R11: they import
                                                              no mechanics, class, game or catalog)
  src/mechanics, src/game, src/*.zig                      -> shared: `//! Shared mechanism: ...`, or
                                                              `//! Class registry: ...` for a pure
                                                              class enumeration, which may name
                                                              classes (R3, R5, named weapons in R4,
                                                              R7) but holds no behaviour

This scanner counts the ways a shared module can name a concrete class.

Registries may import class modules (they enumerate them); shared mechanisms may not (R7): they reach
classes only through a registry's checked hooks.

A module without a valid role header counts as shared. Counts are ratcheted against
class_ownership_baseline.json: they may only go down. After removing violations, lower the baseline:

  python3 dkq3/tools/class_ownership.py --update
"""
import argparse
import json
import re
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
BASELINE = Path(__file__).resolve().with_name('class_ownership_baseline.json')
SCANNED = ('src/engine', 'src/core', 'src/mechanics', 'src/game', 'src/classes')
# Module roots at the top of src/.
ROOT_FILES = ('src/server.zig', 'src/client.zig', 'src/ui.zig', 'src/audit.zig', 'src/runtime_tests.zig',
              'src/actor_catalog.zig', 'src/weapon_catalog.zig', 'src/item_catalog.zig', 'src/inventory_rules.zig')
EXCLUDED = ()
CLASS_KINDS = {'actors': 'actor', 'weapons': 'weapon', 'items': 'item', 'entities': 'entity'}
ROLE = re.compile(r'^//! (Shared mechanism:|Class registry:|(actor|weapon|item|entity)-class: ([a-z0-9_]+)\b)')
RULES = {
    'R1': 'actor kind comparison',
    'R2': 'switch arm naming actor kinds',
    'R3': 'map classname literal',
    'R4': 'weapon id literal or named weapon',
    'R5': 'reaches into a class policy or class state',
    'R6': 'missing role header',
    'R7': 'imports a class-owned module',
    'R8': 'switch arm naming a class tag (attack payload, flight, world control, class component)',
    'R9': 'names a class-owned component type',
    'R10': "a class module reads another class's policy",
    'R11': 'a game-agnostic layer (core, engine) imports game code',
}


def strip_comments(text, strings=True):
    """Source without // comments; literal contents are kept, or blanked when `strings` is false."""
    out = []
    for line in text.splitlines():
        result, quote, escaped, i = [], None, False, 0
        while i < len(line):
            ch = line[i]
            if quote:
                result.append(ch if strings or ch == quote and not escaped else ' ')
                if escaped:
                    escaped = False
                elif ch == '\\':
                    escaped = True
                elif ch == quote:
                    quote = None
            elif ch in '"\'':
                quote = ch
                result.append(ch)
            elif line.startswith('//', i):
                break
            else:
                result.append(ch)
            i += 1
        out.append(''.join(result))
    return '\n'.join(out)


TEST_BLOCK = re.compile(r'^test\b[^\n]*\{[ \t]*\n.*?^\}[ \t]*$', re.M | re.S)


def strip_tests(text):
    """Source without top-level test blocks: tests may use concrete classes as fixtures."""
    return TEST_BLOCK.sub('', text)


class Vocabulary:
    """Concrete class names read from the catalogs, so the rules follow the code."""

    def __init__(self, root=REPO_ROOT, extra=None):
        actors = (root / 'src/actor_catalog.zig').read_text()
        kinds = re.search(r'pub const Kind = enum \{([^}]*)\}', (root / 'src/mechanics/policy/actors/kinds.zig').read_text()).group(1)
        self.kinds = [name.strip() for name in kinds.split(',') if name.strip()]
        imports = dict(re.findall(r'pub const (\w+) = @import\("([^"]+)\.zig"\)', actors))
        # Catalog alias -> the class folder holding that policy (the class name in role tags).
        self.policy_stem = {name: path.split('/')[2] for name, path in imports.items() if path.startswith('classes/actors/')}
        self.policies = sorted(self.policy_stem)
        self.actor_classes = folders(root, 'actors')
        # Class state slots: each policy names its actor field (`state_field`).
        self.substates = sorted(set(re.findall(r'^pub const state_field = "(\w+)";', '\n'.join(
            p.read_text() for p in (root / 'src/classes/actors').glob('*/*.zig')), re.M)))
        weapons = (root / 'src/game/weapons/classes.zig').read_text()
        self.weapons = sorted(re.findall(r'pub const (\w+) = @import\("[^"]*classes/weapons/\w+/\w+\.zig"\)', weapons))
        self.weapon_classes = folders(root, 'weapons')
        self.entity_classes = sorted(set((extra or {}).get('entity_classes', [])) | set(folders(root, 'entities')))
        self.item_classes = sorted(set((extra or {}).get('item_classes', [])) | set(folders(root, 'items')))
        self.union_tags, self.component_tags = self._class_tags(root)
        self.union_tags -= set(self.kinds)
        self.component_types = sorted(''.join(part.capitalize() for part in tag.split('_')) for tag in self.component_tags)
        self.component_tags -= set(self.kinds)
        kind = '|'.join(self.kinds)
        self.patterns = {
            'R1': re.compile(rf'\bkind\s*[!=]=\s*\.(?:{kind})\b'),
            'R2': re.compile(rf'^\s*\.(?:{kind})(?:\s*,\s*\.(?:{kind}))*\s*=>', re.M),
            # A bare family prefix ("trigger_") is a naming convention, not a class.
            # Weapon-table columns (ammo_max, ammo_per_use) share the ammo_ prefix but name no class.
            'R3': re.compile(r'"(?!ammo_(?:max|per_use)")(?:monster|weapon|item|ammo|func|trigger|target|effect|sfx|deco)_[A-Za-z0-9][A-Za-z0-9_]*'),
            # Weapon ids start at 1; comparisons with 0 test for "none".
            'R4-literal': re.compile(r'\b(?:weapon|id)\s*[!=]=\s*[1-9]\d*\b|\bammo\[\d+\]'),
            'R4': re.compile(r'\b(?:weapon|id)\s*[!=]=\s*[1-9]\d*\b|\bammo\[\d+\]'
                             rf'|\b(?:weapon_catalog"\)|catalog|weapons)\.(?:classes\.)?(?:{"|".join(self.weapons)})\.'),
            'R9': re.compile(rf'\bdata\.(?:{"|".join(self.component_types)})\b') if self.component_types else re.compile(r'(?!)'),
            'R5': re.compile(rf'(?:actor_catalog"\)|\bcatalog)\.(?:{"|".join(self.policies)})\b'
                             rf'|\bactor\.(?:{"|".join(self.substates)})\b|\.workers\.(?:owns|skinny)\('),
        }

    @staticmethod
    def _class_tags(root):
        """-> (union tags, component tags) naming one class: attack payloads, flights and world
        controls; the ECS components whose type a class module owns."""
        tags, components_owned = set(), set()
        # A shared mechanism's payloads are its own, not a class's: only class folders count.
        for path in (root / 'src/classes/actors').rglob('*.zig'):
            text = path.read_text()
            if 'attack_payloads' in text:
                block = text[text.index('attack_payloads'):].split(';', 1)[0]
                tags |= set(re.findall(r'\.tag = "(\w+)"', block))
        for path in (root / 'src/classes/weapons').rglob('*.zig'):
            tags |= set(re.findall(r'pub const flight_tag = "(\w+)"', path.read_text())) - {'ion'}
        for path in [*(root / 'src/classes').rglob('*.zig'), *(root / 'src/mechanics/domain').rglob('*.zig'), *(root / 'src/game/domain').rglob('*.zig')]:
            text = path.read_text()
            if 'pub const controls' in text:
                block = text[text.index('pub const controls'):].split(';', 1)[0]
                tags |= set(re.findall(r'\.tag = "(\w+)"', block))
        components_path = root / 'src/game/domain/components.zig'
        components = components_path.read_text()
        ids = set(re.findall(r'(\w+) = \d+', components[components.index('ComponentId'):]))
        policies = dict(re.findall(r'pub const (\w+) = @import\("([^"]+)\.zig"\)', (root / 'src/actor_catalog.zig').read_text()))
        for name, source in re.findall(r'^pub const (\w+) = (@import\("[^"]+"\)[^;]*);', components, re.M):
            module = re.match(r'@import\("([^"]+)"\)', source).group(1)
            owned = (module == 'weapon_catalog' and '.classes.' in source) or module == 'item_catalog'
            if module == 'actor_catalog':
                alias = source.split(').')[1].split('.')[0]
                owned = policies.get(alias, '').startswith('classes/')
            if module.endswith('.zig'):
                target = (components_path.parent / module).resolve()
                owned = 'src/classes/' in target.as_posix()
            snake = re.sub(r'(?<!^)(?=[A-Z])', '_', name).lower()
            if owned and snake in ids:
                components_owned.add(snake)
        return tags, components_owned

    SWITCH = re.compile(r'switch \((?:comptime )?([^()]*(?:\([^()]*\))?[^()]*)\) \{')

    def class_arms(self, code):
        """Switch arms naming a class tag: union tags in a switch over `.action`, `.flight` or
        `.attack`, component tags in a switch over a component id."""
        count = 0
        for match in self.SWITCH.finditer(code):
            subject = match.group(1).strip()
            if re.search(r'(?:^|\.)(?:action|flight|attack)$', subject):
                tags = self.union_tags
            elif subject in ('id', 'kind', 'component'):
                tags = self.component_tags
            else:
                continue
            depth, i = 1, match.end()
            while i < len(code) and depth:
                depth += {'{': 1, '}': -1}.get(code[i], 0)
                i += 1
            body = code[match.end():i]
            for arm in re.findall(r'^\s*(?:inline\s+)?((?:\.\w+\s*,\s*)*\.\w+)\s*=>', body, re.M):
                if any(name.strip()[1:] in tags for name in arm.split(',')):
                    count += 1
        # Direct comparisons of a union's active tag: `attack.attack == .gunner_burst`.
        for tag in re.findall(r'\b(?:action|flight|attack)\s*[!=]=\s*\.(\w+)\b', code):
            if tag in self.union_tags:
                count += 1
        return count

    def foreign_policies(self, text, own):
        """References from an actor class module to another class's policy."""
        code = strip_comments(strip_tests(text), strings=False).replace('@import("actor_catalog")', 'catalog')
        return sum(1 for name in re.findall(r'\bcatalog\.(\w+)\b', code)
                   if name in self.policy_stem and self.policy_stem[name] != own)

    def role(self, text):
        """-> ('shared'|'actor'|'weapon'|'item'|'entity', name) or None when the header is missing."""
        lines = text.splitlines()
        match = ROLE.match(lines[1]) if len(lines) > 1 else None
        if not match:
            return None
        if match.group(1) == 'Class registry:':
            return ('registry', '')
        if match.group(2) is None:
            return ('shared', '')
        return (match.group(2), match.group(3))

    def valid_role(self, role):
        kind, name = role
        return kind in ('shared', 'registry') or name in {'actor': self.actor_classes, 'weapon': self.weapon_classes,
                                            'item': self.item_classes, 'entity': self.entity_classes}[kind]

    def count(self, text, registry=False):
        """-> {rule: count} for a shared module's (or, with `registry`, a class registry's) source."""
        # Classnames are string literals; every other rule reads code only.
        text = strip_tests(text)
        # Catalog imports are references, not literals: `@import("actor_catalog").policy`.
        for module, alias in (('actor_catalog', 'catalog'), ('weapon_catalog', 'weapons'), ('item_catalog', 'items')):
            text = text.replace(f'@import("{module}")', alias)
        code, literals = strip_comments(text, strings=False), strip_comments(text)
        # Module names in @import and declaration names in @hasDecl/@field are not classnames.
        literals = re.sub(r'@import\("[^"]*"\)', '@import("")', literals)
        literals = re.sub(r'@(hasDecl|hasField|field|FieldType)\(([^,()]*), "[^"]*"\)', r'@\1(\2, "")', literals)
        counts = {rule: len(pattern.findall(literals if rule == 'R3' else code)) for rule, pattern in self.patterns.items()}
        if arms := self.class_arms(code):
            counts['R8'] = arms
        # A registry names classes; it may still not compare weapon ids.
        literal = counts.pop('R4-literal')
        if registry:
            counts['R4'] = literal
            counts.pop('R8', None)
            counts.pop('R9', None)
            counts.pop('R3')
            counts.pop('R5')
        return {rule: n for rule, n in counts.items() if n}


def modules(root=REPO_ROOT):
    for relative in ROOT_FILES:
        if (root / relative).exists():
            yield relative, root / relative
    for directory in SCANNED:
        for path in sorted((root / directory).rglob('*.zig')):
            relative = path.relative_to(root).as_posix()
            if not relative.startswith(EXCLUDED):
                yield relative, path


def folders(root, kind):
    """The class folders of one kind (src/classes/<kind>/<class>/)."""
    return sorted(p.name for p in (root / 'src/classes' / kind).iterdir() if p.is_dir())


def location_role(relative):
    """-> (kind, class) for a module inside a class folder, else None."""
    parts = relative.split('/')
    if len(parts) > 3 and parts[1] == 'classes' and parts[2] in CLASS_KINDS:
        return (CLASS_KINDS[parts[2]], parts[3])
    return None


GAME_AGNOSTIC = ('src/core/', 'src/engine/')
GAME_CODE = ('src/mechanics/', 'src/classes/', 'src/game/')


def layer_imports(path, text, root):
    """Imports of game code (or a catalog module) from a game-agnostic layer."""
    code = strip_comments(strip_tests(text))
    count = sum(1 for name in re.findall(r'@import\("(\w+)"\)', code) if name.endswith('_catalog') or name == 'inventory_rules')
    for name in IMPORT.findall(code):
        try:
            relative = (path.parent / name).resolve().relative_to(root.resolve()).as_posix()
        except ValueError:
            continue
        if relative.startswith(GAME_CODE) or relative in ROOT_FILES:
            count += 1
    return count


IMPORT = re.compile(r'@import\("([^"]+\.zig)"\)')


def class_imports(path, text, owned):
    """Imports of class-owned modules (resolved paths in `owned`) in a module's code."""
    code = strip_comments(strip_tests(text))
    return sum(1 for name in IMPORT.findall(code) if (path.parent / name).resolve() in owned)


def foreign_imports(path, text, policy, root, roles):
    """Imports, in a class module, of another class's modules."""
    code = strip_comments(strip_tests(text))
    count = 0
    for name in IMPORT.findall(code):
        try:
            relative = (path.parent / name).resolve().relative_to(root.resolve()).as_posix()
        except ValueError:
            continue
        role = roles.get(relative)
        if role is not None and role[0] not in ('shared', 'registry') and role[1] != policy:
            count += 1
    return count


def scan(root=REPO_ROOT, extra=None):
    """-> (violations {path: {rule: count}}, invalid [(path, header)])."""
    vocabulary = Vocabulary(root, extra)
    violations, invalid = {}, []
    texts = {relative: path.read_text() for relative, path in modules(root)}
    roles = {relative: vocabulary.role(text) for relative, text in texts.items()}
    # A class folder decides ownership; its modules' headers must name the same class.
    for relative, role in list(roles.items()):
        if (located := location_role(relative)) is not None:
            if role != located:
                invalid.append((relative, texts[relative].splitlines()[1] + f'  (folder says {located[0]}-class: {located[1]})'))
            roles[relative] = located
        elif role is not None and role[0] not in ('shared', 'registry'):
            invalid.append((relative, texts[relative].splitlines()[1] + '  (class modules live in src/classes/<kind>/<class>/)'))
    owned = {(root / relative).resolve() for relative, role in roles.items()
             if role is not None and role[0] not in ('shared', 'registry')}
    for relative, path in modules(root):
        text = texts[relative]
        role = roles[relative]
        if role is not None and not vocabulary.valid_role(role):
            invalid.append((relative, text.splitlines()[1]))
            continue
        if any(relative == entry[0] for entry in invalid):
            continue
        if role is not None and role[0] == 'actor':
            if foreign := vocabulary.foreign_policies(text, role[1]) + foreign_imports(path, text, role[1], root, roles):
                violations[relative] = {'R10': foreign}
            continue
        if role is not None and role[0] not in ('shared', 'registry'):
            continue
        registry = role is not None and role[0] == 'registry'
        counts = vocabulary.count(text, registry)
        if relative.startswith(GAME_AGNOSTIC) and (layered := layer_imports(path, text, root)):
            counts['R11'] = layered
        if not registry and (imports := class_imports(path, text, owned)):
            counts['R7'] = imports
        if role is None:
            counts['R6'] = 1
        if counts:
            violations[relative] = counts
    return violations, invalid


def load_baseline(path=BASELINE):
    return json.loads(path.read_text())


def compare(violations, baseline):
    """-> list of human-readable failures against the ratchet baseline."""
    allowed = baseline['shared_modules']
    failures = []
    for relative, counts in sorted(violations.items()):
        for rule, n in sorted(counts.items()):
            limit = allowed.get(relative, {}).get(rule, 0)
            if n > limit:
                failures.append(f'{relative}: {RULES[rule]} ({rule}) {n} > baseline {limit}; move the class logic '
                                'into its class module (docs/runtime-zig.md "Class contract")')
    for relative, counts in sorted(allowed.items()):
        for rule, limit in sorted(counts.items()):
            n = violations.get(relative, {}).get(rule, 0)
            if n < limit:
                failures.append(f'{relative}: {rule} improved to {n} (baseline {limit}); lock it in with '
                                'python3 dkq3/tools/class_ownership.py --update')
    return failures


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.split('\n\n')[0])
    parser.add_argument('--update', action='store_true', help='rewrite the baseline from the current tree')
    args = parser.parse_args(argv)
    baseline = load_baseline()
    violations, invalid = scan(extra=baseline)
    for relative, header in invalid:
        print(f'{relative}: invalid role header: {header}', file=sys.stderr)
    if args.update:
        if invalid:
            return 1
        baseline['shared_modules'] = {path: dict(sorted(counts.items())) for path, counts in sorted(violations.items())}
        BASELINE.write_text(json.dumps(baseline, indent=1) + '\n')
        totals = {rule: sum(c.get(rule, 0) for c in violations.values()) for rule in RULES}
        print('class-ownership baseline:', ', '.join(f'{rule}={n}' for rule, n in totals.items()))
        return 0
    failures = compare(violations, baseline)
    for failure in failures:
        print(failure, file=sys.stderr)
    return 1 if failures or invalid else 0


if __name__ == '__main__':
    sys.exit(main())
