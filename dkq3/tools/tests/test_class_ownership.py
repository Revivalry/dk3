"""Shared runtime modules never gain class-specific logic (docs/runtime-zig.md "Class contract")."""
import unittest
from pathlib import Path

import class_ownership
from tests.support import REPO_ROOT


class ClassOwnershipTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.baseline = class_ownership.load_baseline()
        cls.vocabulary = class_ownership.Vocabulary(Path(REPO_ROOT), cls.baseline)

    def test_rules_recognise_class_logic(self):
        sample = '\n'.join([
            'if (policy.kind == .mishima_guard) return;',
            '    .sealcaptain, .uzigang => try think(),',
            'if (std.mem.eql(u8, object.classname, "func_door")) {}',
            'if (id == 23) grant();',
            'const pain = catalog.mishima.pain_chance + actor.guard.rounds;',
            '// kind == .crox in a comment is ignored',
            'const text = "kind == .crox inside a string is not code";',
        ])
        counts = self.vocabulary.count(sample)
        self.assertEqual({'R1': 1, 'R2': 1, 'R3': 1, 'R4': 1, 'R5': 2}, counts)
        self.assertEqual({}, self.vocabulary.count('if (light.kind == .light) step(actor.melee.pose);'))
        self.assertEqual({}, self.vocabulary.count('if (id == 0 or weapon != 0) return;'))
        self.assertEqual({}, self.vocabulary.count('const weapons = @import("weapon_catalog");'))
        self.assertEqual({'R5': 1}, self.vocabulary.count('const tag = @import("actor_catalog").psyclaw.render_tag;'))
        self.assertEqual({}, self.vocabulary.count('if (std.mem.startsWith(u8, name, "trigger_")) return;'))
        self.assertEqual({}, self.vocabulary.count('test "fixture" {\n    if (kind == .crox) {}\n}\n'))
        self.assertEqual({}, self.vocabulary.count('if (@hasDecl(A, "effect_links")) return A.effect_links;'))
        self.assertEqual({}, self.vocabulary.count('.{ "ammoMax", "ammo_max" }, .{ "ammoCost", "ammo_per_use" }'))
        self.assertEqual({'R3': 1}, self.vocabulary.count('if (eql(name, "ammo_ionpack")) {}'))
        self.assertEqual({'R8': 1}, self.vocabulary.count('switch (control.action) {\n    .music => |m| {},\n    else => {},\n}\n'))
        self.assertEqual({}, self.vocabulary.count('switch (task.kind) {\n    .teleport => {},\n    else => {},\n}\n'))
        self.assertEqual({'R8': 1}, self.vocabulary.count('if (attack.attack == .psyclaw_sphere) return;'))
        # A shared mechanism's own payload tags are not class tags.
        self.assertEqual({}, self.vocabulary.count('if (attack.attack == .gunner_burst) return;'))
        self.assertEqual({'R9': 1}, self.vocabulary.count('const chain = world.get(entity, data.ZeusBolt) catch null;'))
        self.assertEqual({}, self.vocabulary.count('const pose = world.get(entity, data.Transform) catch null;'))
        self.assertEqual(1, self.vocabulary.foreign_policies('const tag = catalog.kage.render_tag;', 'ghost'))
        self.assertEqual(0, self.vocabulary.foreign_policies('const rounds = catalog.mishima.rounds;', 'mishima_guard'))
        # A class module may import shared mechanisms and its own modules, never another class's.
        root = Path(REPO_ROOT)
        roles = {'src/classes/actors/knights/knights.zig': ('actor', 'knights'), 'src/mechanics/policy/actors/thrown_range.zig': ('shared', ''), 'src/classes/actors/thief/thief.zig': ('actor', 'thief')}
        thief = root / 'src/classes/actors/thief/thief.zig'
        self.assertEqual(1, class_ownership.foreign_imports(thief, 'const r = @import("../knights/knights.zig").inRange;', 'thief', root, roles))
        self.assertEqual(0, class_ownership.foreign_imports(thief, 'const r = @import("../../../mechanics/policy/actors/thrown_range.zig").inRange;', 'thief', root, roles))
        # The folder decides ownership; the layer rule keeps core and engine free of game code.
        self.assertEqual(('actor', 'thief'), class_ownership.location_role('src/classes/actors/thief/server/thieves.zig'))
        self.assertIsNone(class_ownership.location_role('src/mechanics/server/actor_pain.zig'))
        self.assertEqual(1, class_ownership.layer_imports(root / 'src/core/domain/x.zig', 'const c = @import("actor_catalog");', root))
        # A registry may name classes, but never compares weapon ids.
        self.assertEqual({}, self.vocabulary.count('pub const all = .{ catalog.mishima, weapons.classes.c4.id };', registry=True))
        self.assertEqual({'R4': 1}, self.vocabulary.count('if (id == 23) grant();', registry=True))

    def test_role_headers_name_real_classes(self):
        self.assertTrue(self.vocabulary.valid_role(('actor', 'mishima_guard')))
        self.assertTrue(self.vocabulary.valid_role(('weapon', 'venom')))
        self.assertFalse(self.vocabulary.valid_role(('actor', 'hostiles')))
        self.assertEqual(('registry', ''), self.vocabulary.role('// x\n//! Class registry: actor classes.\n'))
        _, invalid = class_ownership.scan(Path(REPO_ROOT), self.baseline)
        self.assertEqual([], invalid, 'role headers must name a class module that exists')

    def test_shared_modules_only_lose_class_logic(self):
        violations, _ = class_ownership.scan(Path(REPO_ROOT), self.baseline)
        failures = class_ownership.compare(violations, self.baseline)
        self.assertEqual([], failures, '\n' + '\n'.join(failures))


if __name__ == '__main__':
    unittest.main()
