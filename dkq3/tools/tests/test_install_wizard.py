"""Focused installer checks using synthetic retail data and release products."""
import json
from pathlib import Path
import tempfile
import unittest
from unittest import mock

import install_wizard
import hd_plan
import postfx
import release_bundle


class InstallerTests(unittest.TestCase):
    def test_hd_plan_keeps_highest_tier_across_palette_variants(self):
        manifest = {'textures': {
            'texture-a': {'key': 'wall', 'maps': ['maps/e1m1a.bsp']},
            'texture-b': {'key': 'wall', 'maps': ['maps/e4m2.bsp']},
        }}
        self.assertEqual(hd_plan.build(manifest)['wall']['tier'], 'hero')

    def test_hd_metrics_accept_tiny_original_textures(self):
        import numpy as np
        self.assertEqual(postfx.light_spread(np.zeros((4, 4, 3), dtype=np.uint8)), 0.0)

    def test_steam_and_custom_sources_require_four_original_paks(self):
        with tempfile.TemporaryDirectory() as temporary:
            home = Path(temporary)
            game = home / '.steam/steam/steamapps/common/Daikatana/data'
            game.mkdir(parents=True)
            for index in range(1, 5):
                (game / f'PAK{index}.PAK').write_bytes(b'owner data')
            with mock.patch.object(Path, 'home', return_value=home):
                self.assertEqual(install_wizard.steam_sources(), [game.resolve()])
            self.assertEqual(install_wizard.game_data(game.parent), game.resolve())
            self.assertEqual(install_wizard.profile_for(game), 'retail')
            (game / 'pak6.pak').write_bytes(b'patch')
            (game / 'pak5.zip').write_bytes(b'patch')
            self.assertEqual(install_wizard.profile_for(game), '1.3')
            (game / 'PAK4.PAK').unlink()
            self.assertIsNone(install_wizard.game_data(game.parent))

    def test_release_bundle_contains_launchers_and_no_game_data(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            prefix = root / 'products'
            for name in release_bundle.PRODUCTS['linux-x64']:
                path = prefix / 'bin' / name
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_bytes(b'binary')
            for name in release_bundle.MODULES['linux-x64']:
                path = prefix / 'lib/dk3' / name
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_bytes(b'module')
            for name in ('rules.json', 'scripts/dk3-projectile-weather.shader'):
                path = prefix / 'share/dk3' / name
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text('{}')
            runtime = root / 'python'
            (runtime / 'bin').mkdir(parents=True)
            (runtime / 'bin/python3').write_bytes(b'python')
            wheels = root / 'wheels'
            wheels.mkdir()
            (wheels / 'numpy-2.4.3-py3-none-any.whl').write_bytes(b'wheel')
            ffmpeg = root / 'ffmpeg'
            ffmpeg.write_bytes(b'ffmpeg')
            license_file = root / 'ffmpeg-license'
            license_file.write_text('license')
            bundle = root / 'bundle'
            bundle.mkdir()
            repository = Path(__file__).resolve().parents[3]
            release_bundle.fill(bundle, repository, prefix, 'linux-x64', runtime, ffmpeg, license_file, wheels)
            manifest = json.loads((bundle / 'bundle.json').read_text())
            self.assertIn('bin/dk3', manifest['files'])
            self.assertIn('dkq3/tools/install_wizard.py', manifest['files'])
            install_wizard.verify_bundle(bundle)
            self.assertTrue((bundle / 'install.sh').stat().st_mode & 0o111)
            self.assertFalse((bundle / 'data').exists())
            installed = root / 'installed'
            install_wizard.copy_products(bundle, installed)
            install_wizard.write_launcher(installed)
            self.assertTrue((installed / 'tools/play.py').is_file())
            self.assertIn('play.py', (installed / 'play.sh').read_text())
            (bundle / 'bin/dk3').write_bytes(b'changed')
            with self.assertRaisesRegex(ValueError, 'changed release file'):
                install_wizard.verify_bundle(bundle)


if __name__ == '__main__':
    unittest.main()
