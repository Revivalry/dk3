"""Development installation publishes complete builds and preserves player state."""
import json
import hashlib
import struct
from pathlib import Path
import tempfile
import unittest
import zipfile
from unittest.mock import patch

import play


class PlayInstallTest(unittest.TestCase):
    def test_admission_stream_retains_canonical_gameplay_identity(self):
        with tempfile.TemporaryDirectory() as temporary:
            _, assets = self.fixture(Path(temporary))
            source = assets / 'current'
            path = source / 'packages/dk3-data.pk3'
            manifest = json.loads((source / 'manifest.json').read_text())
            expected = None
            for compression in (zipfile.ZIP_STORED, zipfile.ZIP_DEFLATED):
                with zipfile.ZipFile(path, 'w', compression=compression) as archive:
                    archive.writestr('Mixed/Last', bytes(range(256)) * 8201)
                    archive.writestr('Mixed/', b'')
                    archive.writestr('aaa/empty', b'')
                    archive.writestr('Z-first', b'canonical ordering')
                manifest['packages'][path.name]['sha256'] = play.digest(path)
                (source / 'manifest.json').write_text(json.dumps(manifest))
                reference = hashlib.sha256()
                for name in ('base', 'maps', 'data', 'navigation'):
                    with zipfile.ZipFile(source / 'packages' / f'dk3-{name}.pk3') as archive:
                        for entry in sorted(archive.namelist()):
                            if entry.endswith('/'):
                                continue
                            reference.update(entry.lower().encode() + b'\0')
                            reference.update(hashlib.sha256(archive.read(entry)).digest())
                admitted, actual = play.checked_assets(source)
                self.assertEqual(admitted, manifest)
                self.assertEqual(actual, reference.hexdigest())
                if expected is not None:
                    self.assertEqual(actual, expected)
                expected = actual

    def test_admission_crc_checks_gameplay_and_cosmetic_payloads(self):
        with tempfile.TemporaryDirectory() as temporary:
            _, assets = self.fixture(Path(temporary))
            source = assets / 'current'
            manifest = json.loads((source / 'manifest.json').read_text())
            for name in ('data', 'textures'):
                path = source / 'packages' / f'dk3-{name}.pk3'
                original = path.read_bytes()
                with zipfile.ZipFile(path) as archive:
                    entry = archive.infolist()[0]
                payload = bytearray(original)
                offset = entry.header_offset + 30 + len(entry.filename.encode()) + len(entry.extra)
                payload[offset] ^= 1
                path.write_bytes(payload)
                # A matching package SHA must not bypass the entry CRC check.
                manifest['packages'][path.name]['sha256'] = play.digest(path)
                (source / 'manifest.json').write_text(json.dumps(manifest))
                with self.assertRaisesRegex(ValueError, 'corrupt entry'):
                    play.checked_assets(source)
                path.write_bytes(original)
                manifest['packages'][path.name]['sha256'] = play.digest(path)
                (source / 'manifest.json').write_text(json.dumps(manifest))

    def test_parallel_product_hashes_retain_identity_and_join_after_failure(self):
        with tempfile.TemporaryDirectory() as temporary, \
                patch('play._HASH_PARALLEL_MIN_BYTES', 0), \
                patch('play.os.cpu_count', return_value=2):
            root = Path(temporary)
            files = {name: root / name for name in ('small', 'large', 'middle')}
            for index, path in enumerate(files.values()):
                path.write_bytes(bytes([index]) * (19 + index * 37))
            expected = {name: hashlib.sha256(path.read_bytes()).hexdigest() for name, path in files.items()}
            self.assertEqual(play._installation_hashes(files), expected)
            self.assertEqual(list(play._installation_hashes(files)), list(files))
            original = play.digest
            def failed(path):
                if path.name == 'large':
                    raise OSError('controlled hash reader failure')
                return original(path)
            with patch('play.digest', side_effect=failed):
                with self.assertRaisesRegex(OSError, 'controlled hash reader failure'):
                    play._installation_hashes(files)
            files['large'].write_bytes(b'changed bytes after failed read')
            expected['large'] = hashlib.sha256(files['large'].read_bytes()).hexdigest()
            self.assertEqual(play._installation_hashes(files), expected)

    def fixture(self, root):
        prefix, assets = root / 'native', root / 'assets'
        source = assets / 'generation'
        (source / 'packages').mkdir(parents=True)
        (assets / 'current').symlink_to(source.name)
        records = {}
        for index, name in enumerate(play.PACKAGES):
            path = source / 'packages' / f'dk3-{name}.pk3'
            with zipfile.ZipFile(path, 'w') as archive:
                for entry in play.REQUIRED_ENTRIES if index == 0 else (f'fixture/{name}',):
                    archive.writestr(entry, 'fixture')
                if name == 'maps':
                    # Installation now derives the campaign graph from real BSP
                    # authoring, so provide a valid empty map rather than text.
                    bsp = bytearray(144)
                    struct.pack_into('<4si', bsp, 0, b'IBSP', 46)
                    archive.writestr('maps/e1m1a.bsp', bsp)
            records[path.name] = {'sha256': play.digest(path)}
        (source / 'manifest.json').write_text(json.dumps(dict(
            format=1, profile='retail', key='fixture', packages=records)))
        for name in (*[f'bin/{name}' for name in play.BINARIES],
                     *[f'lib/dk3/{name}' for name in play.MODULES],
                     *[f'share/dk3/{name}' for name in play.RUNTIME_MEDIA], *play.RUNTIME_NOTICES):
            path = prefix / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(b'{}' if name.endswith('.json') else b'first build')
        return prefix, assets

    def test_new_code_publishes_separately_and_keeps_saves(self):
        with tempfile.TemporaryDirectory() as temporary:
            prefix, assets = self.fixture(Path(temporary))
            play.install(prefix, assets)
            original = (prefix / 'play/current').resolve()
            for notice in play.RUNTIME_NOTICES:
                self.assertEqual((original / notice).read_bytes(), (prefix / notice).read_bytes())
            save = prefix / 'play/state/dk3/saves/user.sav'
            save.parent.mkdir(parents=True)
            save.write_bytes(b'user save')
            (prefix / 'lib/dk3/qagame.so').write_bytes(b'second build')
            play.install(prefix, assets)
            published = (prefix / 'play/current').resolve()
            self.assertNotEqual(original, published)
            self.assertEqual((original / 'share/dk3/qagame.so').read_bytes(), b'first build')
            self.assertEqual((published / 'share/dk3/qagame.so').read_bytes(), b'second build')
            self.assertEqual(save.read_bytes(), b'user save')

    def test_incomplete_build_and_corrupt_assets_keep_current_generation(self):
        with tempfile.TemporaryDirectory() as temporary:
            prefix, assets = self.fixture(Path(temporary))
            play.install(prefix, assets)
            original = (prefix / 'play/current').resolve()
            (prefix / 'lib/dk3/qagame.so').unlink()
            with self.assertRaisesRegex(ValueError, 'missing independent build product'):
                play.install(prefix, assets)
            self.assertEqual((prefix / 'play/current').resolve(), original)
            (assets / 'current/packages/dk3-base.pk3').write_bytes(b'corrupt')
            with self.assertRaisesRegex(ValueError, 'changed or corrupt package'):
                play.install(prefix, assets)
            self.assertEqual((prefix / 'play/current').resolve(), original)

    def test_first_run_explains_asset_setup(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            with self.assertRaisesRegex(ValueError, 'zig build assets'):
                play.install(root, root / 'absent')

    def test_neural_overlay_preserves_gameplay_and_rejects_wrong_generation(self):
        with tempfile.TemporaryDirectory() as temporary:
            prefix, assets = self.fixture(Path(temporary))
            play.install(prefix, assets)
            stock = (prefix / 'play/current').resolve()
            gameplay = json.loads((stock / 'share/dk3/compatibility.json').read_text())['gameplay']
            package = Path(temporary) / 'neural.pk3'
            entries = {'dk3/neural-models.cfg': b'models/global/m_hiro.dkm models/neural/hiro.iqm\n',
                       'models/neural/hiro.iqm': b'fixture'}
            report = dict(format=1, source_models_sha256=play.digest(assets / 'current/packages/dk3-models.pk3'),
                          files={k: hashlib.sha256(v).hexdigest() for k, v in entries.items()})

            def write():
                with zipfile.ZipFile(package, 'w') as archive:
                    for name, data in entries.items(): archive.writestr(name, data)
                    archive.writestr('dk3/neural-assets.json', json.dumps(report))

            write()
            play.install(prefix, assets, neural_assets=package)
            installed = (prefix / 'play/current').resolve()
            self.assertEqual((installed / 'share/dk3/zz-dk3-neural.pk3').read_bytes(), package.read_bytes())
            self.assertEqual(json.loads((installed / 'share/dk3/compatibility.json').read_text())['gameplay'], gameplay)
            guard = Path(temporary) / 'dkguard'
            guard.touch()
            with patch('play.os.execv') as execute:
                play.launch(prefix, guard, [])
            self.assertEqual(execute.call_args.args[1][-3:], ['+set', 'r_picmip', '0'])
            command = execute.call_args.args[1]
            self.assertEqual(command[command.index('dk3_runtime_probe') + 1], '2')
            report['source_models_sha256'] = 'wrong'
            write()
            with self.assertRaisesRegex(ValueError, 'another model generation'):
                play.install(prefix, assets, neural_assets=package)
            self.assertEqual((prefix / 'play/current').resolve(), installed)

    def test_shared_hd_default_preserves_gameplay_and_local_overrides(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            prefix, assets = self.fixture(root)
            shared = root / 'hd-textures/dkq3-textures_hd.pk3'
            local = prefix / 'hd-textures/dkq3-textures_hd.pk3'
            explicit = root / 'custom.pk3'

            def publish():
                play.install(prefix, assets, hd_textures_fallback=shared)
                return (prefix / 'play/current').resolve()

            stock = publish()  # A checkout without optional HD assets still works.
            gameplay = json.loads((stock / 'share/dk3/compatibility.json').read_text())['gameplay']
            overlay = 'share/dk3/zz-dk3-textures-hd.pk3'
            self.assertFalse((stock / overlay).exists())
            for source in (shared, local, explicit):
                source.parent.mkdir(parents=True, exist_ok=True)
                with zipfile.ZipFile(source, 'w') as archive:
                    archive.writestr('textures/fixture/wall.png', str(source))
                if source == explicit:
                    play.install(prefix, assets, explicit, hd_textures_fallback=shared)
                    installed = (prefix / 'play/current').resolve()
                else:
                    installed = publish()
                self.assertEqual((installed / overlay).read_bytes(), source.read_bytes())
                compatibility = json.loads((installed / 'share/dk3/compatibility.json').read_text())
                self.assertEqual(compatibility['gameplay'], gameplay)
                self.assertEqual(compatibility['cosmetic'], 'hd-textures-v1')
            guard = root / 'dkguard'
            guard.touch()
            with patch('play.os.execv') as execute:
                play.launch(prefix, guard, [])
            self.assertEqual(execute.call_args.args[1][-3:], ['+set', 'r_picmip', '0'])
