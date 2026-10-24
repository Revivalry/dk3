"""Focused installer checks using synthetic retail data and release products."""
from contextlib import closing
import json
from pathlib import Path
import tempfile
import subprocess
import sys
import shutil
import unittest
import zipfile
from unittest import mock

import install_wizard
import assets
import asset_source
import dkpak
import hd_plan
import postfx
import release_bundle


class InstallerTests(unittest.TestCase):
    def runtime_update_fixture(self, root):
        from tests.test_play_install import PlayInstallTest
        import play
        destination, cache = PlayInstallTest().fixture(root)
        hd = root / 'local-art.pk3'
        with zipfile.ZipFile(hd, 'w') as archive:
            archive.writestr('textures/fixture.png', b'local artwork fixture')
        play.install(destination, cache, hd_textures=hd)
        (destination / '.installer').mkdir()
        shutil.move(str(cache), destination / '.installer/assets')
        bundle = root / 'bundle'
        for directory in ('bin', 'lib', 'share'):
            shutil.copytree(destination / directory, bundle / directory)
        (bundle / 'lib/dk3/qagame.so').write_bytes(b'updated native module')
        tools = bundle / 'dkq3/tools'
        tools.mkdir(parents=True)
        for script in Path(install_wizard.__file__).parent.glob('*.py'):
            shutil.copy2(script, tools / script.name)
        return bundle, destination

    def test_runtime_update_keeps_assets_saves_settings_and_local_art(self):
        with tempfile.TemporaryDirectory() as temporary:
            bundle, destination = self.runtime_update_fixture(Path(temporary))
            previous = (destination / 'play/current').resolve()
            manifest = destination / '.installer/assets/current/manifest.json'
            original = (manifest.read_bytes(), manifest.stat().st_mtime_ns)
            save = destination / 'play/state/dk3/saves/user.sav'
            save.parent.mkdir(parents=True)
            save.write_bytes(b'owner save')
            settings = destination / 'play/home/dk3/dk3config.cfg'
            settings.parent.mkdir(parents=True)
            settings.write_text('owner settings')
            with mock.patch.object(install_wizard, 'python_environment', return_value=Path(sys.executable)), \
                 mock.patch.object(install_wizard, 'register_desktop'):
                install_wizard.update_runtime(bundle, destination)
            current = (destination / 'play/current').resolve()
            self.assertNotEqual(current, previous)
            self.assertEqual((current / 'share/dk3/qagame.so').read_bytes(), b'updated native module')
            self.assertEqual((previous / 'share/dk3/qagame.so').read_bytes(), b'first build')
            self.assertEqual((current / 'share/dk3/zz-dk3-textures-hd.pk3').read_bytes(),
                             (previous / 'share/dk3/zz-dk3-textures-hd.pk3').read_bytes())
            self.assertEqual((manifest.read_bytes(), manifest.stat().st_mtime_ns), original)
            self.assertEqual(save.read_bytes(), b'owner save')
            self.assertEqual(settings.read_text(), 'owner settings')

    def test_runtime_update_rejects_corrupt_assets_without_replacing_current(self):
        with tempfile.TemporaryDirectory() as temporary:
            bundle, destination = self.runtime_update_fixture(Path(temporary))
            previous = (destination / 'play/current').resolve()
            (destination / '.installer/assets/current/packages/dk3-models.pk3').write_bytes(b'corrupt')
            with mock.patch.object(install_wizard, 'python_environment', return_value=Path(sys.executable)), \
                 mock.patch.object(install_wizard, 'register_desktop'):
                with self.assertRaises(subprocess.CalledProcessError):
                    install_wizard.update_runtime(bundle, destination)
            self.assertEqual((destination / 'play/current').resolve(), previous)

    def test_hd_plan_keeps_highest_tier_across_palette_variants(self):
        manifest = {'textures': {
            'texture-a': {'key': 'wall', 'maps': ['maps/e1m1a.bsp']},
            'texture-b': {'key': 'wall', 'maps': ['maps/e4m2.bsp']},
        }}
        self.assertEqual(hd_plan.build(manifest)['wall']['tier'], 'hero')

    def test_hd_metrics_accept_tiny_original_textures(self):
        import numpy as np
        self.assertEqual(postfx.light_spread(np.zeros((4, 4, 3), dtype=np.uint8)), 0.0)

    def test_steam_and_custom_sources_accept_three_original_paks(self):
        with tempfile.TemporaryDirectory() as temporary:
            home = Path(temporary)
            game = home / '.steam/steam/steamapps/common/Daikatana/data'
            game.mkdir(parents=True)
            for index in range(1, 4):
                (game / f'PAK{index}.PAK').write_bytes(b'owner data')
            with mock.patch.object(Path, 'home', return_value=home):
                self.assertEqual(install_wizard.steam_sources(), [game.resolve()])
            self.assertEqual(install_wizard.game_data(game.parent), game.resolve())
            self.assertEqual(install_wizard.profile_for(game), 'retail')
            (game / 'pak6.pak').write_bytes(b'patch')
            (game / 'pak5.zip').write_bytes(b'patch')
            self.assertEqual(install_wizard.profile_for(game), '1.3')
            (game / 'PAK2.PAK').unlink()
            self.assertIsNone(install_wizard.game_data(game.parent))

    def test_retail_conversion_prepares_three_paks_and_optional_update(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            data = root / 'data'
            data.mkdir()
            for index in range(1, 4):
                dkpak.write_pak(str(data / f'PAK{index}.PAK'),
                               {'tables/example.vsc': f'archive {index}'.encode()})
            archives, loose, records = assets.inventory(data, 'retail')
            self.assertEqual([name for name, _ in archives], ['pak1.pak', 'pak2.pak', 'pak3.pak'])
            self.assertEqual(len(records), 3)
            prepared = root / 'prepared'
            assets.prepare(prepared, archives, loose, 'retail')
            self.assertEqual(asset_source.archive_order(prepared), ['pak3.pak', 'pak2.pak', 'pak1.pak'])
            with closing(dkpak.Pak(prepared / 'pak3.pak')) as archive:
                self.assertEqual(archive.read('tables/example.vsc'), b'archive 3')
            dkpak.write_pak(str(data / 'pak4.pak'), {'tables/example.vsc': b'optional update'})
            archives, loose, _ = assets.inventory(data, 'retail')
            self.assertEqual([name for name, _ in archives], ['pak1.pak', 'pak2.pak', 'pak3.pak', 'pak4.pak'])
            (data / 'PAK2.PAK').unlink()
            with self.assertRaisesRegex(ValueError, 'missing required input: .*pak2.pak'):
                assets.inventory(data, 'retail')

    def test_13_conversion_still_requires_its_update_archives(self):
        with tempfile.TemporaryDirectory() as temporary:
            data = Path(temporary)
            for index in (1, 2, 3, 5, 6):
                (data / f'pak{index}.pak').write_bytes(b'owner data')
            with self.assertRaisesRegex(ValueError, 'missing required input: .*pak4.pak'):
                assets.inventory(data, '1.3')
            (data / 'pak4.pak').write_bytes(b'update')
            archives, _, _ = assets.inventory(data, '1.3')
            self.assertEqual([name for name, _ in archives],
                             ['pak1.pak', 'pak2.pak', 'pak3.pak', 'pak4.pak', 'pak6.pak', 'pak5.pak'])

    def test_final_install_uses_private_python_when_wizard_has_no_numpy(self):
        from tests.test_play_install import PlayInstallTest
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            destination, cache = PlayInstallTest().fixture(root)
            (destination / '.installer').mkdir()
            shutil.move(str(cache), destination / '.installer/assets')
            tools = Path(install_wizard.__file__).parent
            (destination / 'tools').mkdir()
            for script in tools.glob('*.py'):
                shutil.copy2(script, destination / 'tools' / script.name)
            bundle, source = root / 'bundle', root / 'original'
            (bundle / 'bin').mkdir(parents=True)
            (bundle / 'bin/dkguard').touch()
            (bundle / 'bin/bspc').touch()
            (bundle / 'runtime/ffmpeg').mkdir(parents=True)
            (bundle / 'runtime/ffmpeg/ffmpeg').touch()
            source.mkdir()
            script = '''import importlib.util, subprocess, sys
from pathlib import Path
from unittest.mock import patch
tools, bundle, source, destination, private = map(Path, sys.argv[1:])
sys.path.insert(0, str(tools))
assert importlib.util.find_spec('numpy') is None, 'parent must reproduce the bare bundled runtime'
import install_wizard
real_run = subprocess.run
def run(command, **kwargs):
    if command[0] == str(bundle / 'bin/dkguard'):
        return subprocess.CompletedProcess(command, 0)
    return real_run(command, **kwargs)
with patch.object(install_wizard, 'python_environment', return_value=private), \\
     patch.object(install_wizard, 'copy_products'), \\
     patch.object(install_wizard, 'register_desktop'), \\
     patch.object(install_wizard.InstallerUI, 'run', side_effect=run):
    install_wizard.install(bundle, source, destination, 'retail', [])
'''
            result = subprocess.run([sys.executable, '-S', '-B', '-c', script, str(tools), str(bundle),
                                     str(source), str(destination), sys.executable],
                                    capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertTrue((destination / 'play/current/installation.json').is_file())
            self.assertTrue((destination / 'share/dk3/dk3/campaign-regions.cfg').is_file())

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
            for requirement in (Path(release_bundle.__file__).parent / 'requirements-tui.txt').read_text().splitlines():
                package, version = requirement.split('==')
                (wheels / f'{package.replace("-", "_")}-{version}-py3-none-any.whl').write_bytes(b'wheel')
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
            # Load the real consumers in a separate process outside the checkout.
            # A manifest alone cannot catch an omitted runtime data dependency.
            result = subprocess.run([sys.executable, '-I', '-B', '-c',
                'import json,sys; from pathlib import Path; '
                'sys.path.insert(0,sys.argv[1]); import appearances,navigation; '
                'print(json.dumps({"catalog":appearances.catalog(),"aas":navigation.CONFIG.read_text()}))',
                str(bundle / 'dkq3/tools')], cwd=root, capture_output=True, text=True, check=True)
            consumed = json.loads(result.stdout)
            self.assertEqual(len(consumed['catalog']), 36)
            self.assertIn('phys_maxstep', consumed['aas'])
            self.assertIn('src/multiplayer/appearances.csv', manifest['files'])
            self.assertIn('dkq3/tools/dk3-aas.cfg', manifest['files'])
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
            for name in assets.CONVERSION_INPUTS:
                with self.subTest(missing_conversion_input=name):
                    omitted = dict(manifest, files={k: v for k, v in manifest['files'].items() if k != name})
                    (bundle / 'bundle.json').write_text(json.dumps(omitted))
                    with self.assertRaisesRegex(ValueError, 'missing release conversion input'):
                        install_wizard.verify_bundle(bundle)


if __name__ == '__main__':
    unittest.main()
