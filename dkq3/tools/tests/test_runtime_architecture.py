"""Keep native simulation independent of engine/private gameplay headers."""
from pathlib import Path
import re
import unittest

from tests.support import REPO_ROOT


class RuntimeArchitectureTest(unittest.TestCase):
    @staticmethod
    def pure(root, path):
        """Engine-free code: domain and ECS layers, class policies (a class folder's root files),
        shared policy helpers, the catalogs and the pure game tables."""
        parts = path.relative_to(root / 'src').parts
        return ('domain' in parts or 'ecs' in parts or parts[:2] == ('mechanics', 'policy')
                or (parts[0] == 'classes' and len(parts) == 4) or parts[:2] in (('game', 'weapons'), ('game', 'items'))
                or parts in (('actor_catalog.zig',), ('weapon_catalog.zig',), ('item_catalog.zig',), ('inventory_rules.zig',),
                             ('multiplayer', 'appearance.zig')))

    def test_pure_layers_do_not_import_runtime_adapters(self):
        root = Path(REPO_ROOT)
        # `root` is the dependency-inversion hook: a game module's root may supply class hooks
        # (domain/snapshot.zig `class_validators`), so pure layers still name no adapter.
        named = {'std', 'root', 'inventory_rules', 'weapon_catalog', 'item_catalog', 'actor_catalog', 'appearance_catalog'}
        files = [path for path in (root / 'src').rglob('*.zig') if self.pure(root, path)]
        self.assertGreater(len(files), 200)
        for path in files:
            text = path.read_text()
            self.assertNotIn('@cImport', text, str(path))
            for dependency in re.findall(r'@import\("([^"]+)"\)', text):
                if dependency in named:
                    continue
                resolved = (path.parent / dependency).resolve()
                self.assertTrue(resolved.is_file(), f'{path}: missing {dependency}')
                self.assertTrue(self.pure(root, resolved), f'{path}: forbidden dependency {dependency}')

    def test_native_runtime_uses_only_public_engine_headers(self):
        root = Path(REPO_ROOT) / 'src'
        forbidden = {'g_local.h', 'cg_local.h', 'ui_local.h'}
        for path in (path for layer in ('engine', 'core', 'mechanics', 'game', 'classes') for path in (root / layer).rglob('*.zig')):
            for header in re.findall(r'@cInclude\("([^"]+)"\)', path.read_text()):
                self.assertNotIn(Path(header).name, forbidden, str(path))
