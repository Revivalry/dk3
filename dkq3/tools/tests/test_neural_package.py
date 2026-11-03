# SPDX-License-Identifier: GPL-2.0-or-later
import hashlib
import json
from pathlib import Path
import tempfile
import unittest
import zipfile
import struct
import zlib
from unittest.mock import patch

from neural_package import MANIFEST, prune_props, validate_package, classic_archive, require_classic_directory


class PackageTest(unittest.TestCase):
    def validation_fixture(self, root, *, invalid_hash=False, invalid_png=False):
        base = root / 'base.pk3'
        base.write_bytes(b'fixed converted models')
        def chunk(kind, data):
            return struct.pack('>I', len(data)) + kind + data + struct.pack('>I', zlib.crc32(kind + data))
        png = (b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', 1, 1, 8, 6, 0, 0, 0)) +
               chunk(b'IDAT', zlib.compress(b'\0\x11\x22\x33\xff')) + chunk(b'IEND', b''))
        files = {MANIFEST: b'models/global/m_hiro.dkm models/neural/hiro.iqm\n',
                 'models/neural/hiro.iqm': b'fixed skeletal model',
                 'models/neural/body.png': b'invalid' if invalid_png else png}
        report = dict(format=1, source_models_sha256=hashlib.sha256(base.read_bytes()).hexdigest(),
                      files={name: hashlib.sha256(data).hexdigest() for name, data in files.items()})
        if invalid_hash:
            report['files']['models/neural/body.png'] = '0' * 64
        path = root / 'neural.pk3'
        with zipfile.ZipFile(path, 'w', compression=zipfile.ZIP_STORED) as archive:
            for name, data in files.items(): archive.writestr(name, data)
            archive.writestr('dk3/neural-assets.json', json.dumps(report))
        return path, base

    def test_admitted_payload_retains_hashes_crc_and_png_signature_validation(self):
        with tempfile.TemporaryDirectory() as temporary:
            path, base = self.validation_fixture(Path(temporary))
            report = validate_package(path, base)
            self.assertIn('models/neural/body.png', report['files'])
            path, base = self.validation_fixture(Path(temporary), invalid_hash=True)
            with self.assertRaisesRegex(ValueError, 'invalid neural package entry'):
                validate_package(path, base)
            path, base = self.validation_fixture(Path(temporary), invalid_png=True)
            with self.assertRaisesRegex(ValueError, 'invalid PNG texture encoding'):
                validate_package(path, base)

    def test_crc_corruption_in_payload_or_manifest_is_rejected(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            for name in ('models/neural/body.png', 'dk3/neural-assets.json'):
                path, base = self.validation_fixture(root)
                with zipfile.ZipFile(path) as archive:
                    entry = archive.getinfo(name)
                data = bytearray(path.read_bytes())
                # ZIP_STORED changes bytes without altering central-directory
                # lengths, so both paths must detect the stale entry CRC.
                offset = entry.header_offset + 30 + len(entry.filename.encode()) + len(entry.extra)
                data[offset + entry.file_size - 1] ^= 1
                path.write_bytes(data)
                with self.assertRaisesRegex(ValueError, 'corrupt neural archive'):
                    validate_package(path, base)

    def test_rewritten_package_stores_png_without_changing_payload_or_admission(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            source, base = self.validation_fixture(root)
            original = validate_package(source, base)
            source_sha = hashlib.sha256(source.read_bytes()).hexdigest()
            output, repeated = root / 'stored.pk3', root / 'repeated.pk3'
            self.assertEqual([], prune_props(source, output, base))
            self.assertEqual([], prune_props(source, repeated, base))
            self.assertEqual(source_sha, hashlib.sha256(source.read_bytes()).hexdigest())
            self.assertEqual(output.read_bytes(), repeated.read_bytes())
            self.assertEqual(original['files'], validate_package(output, base)['files'])
            with zipfile.ZipFile(source) as before, zipfile.ZipFile(output) as after:
                self.assertEqual(sorted(before.namelist()), sorted(after.namelist()))
                for name in original['files']:
                    self.assertEqual(before.read(name), after.read(name))
                self.assertEqual(zipfile.ZIP_STORED, after.getinfo('models/neural/body.png').compress_type)
                self.assertEqual(zipfile.ZIP_DEFLATED, after.getinfo('models/neural/hiro.iqm').compress_type)
                self.assertEqual(zipfile.ZIP_DEFLATED, after.getinfo('dk3/neural-assets.json').compress_type)

    def test_parallel_admission_propagates_integrity_errors_and_releases_readers(self):
        with tempfile.TemporaryDirectory() as temporary, \
                patch('neural_package._VALIDATION_PARALLEL_MIN_BYTES', 0), \
                patch('neural_package._VALIDATION_WORKERS', 2), \
                patch('neural_package.os.cpu_count', return_value=2):
            root = Path(temporary)
            path, base = self.validation_fixture(root)
            receipt = validate_package(path, base)
            self.assertEqual(len(receipt['files']), 3)
            path, base = self.validation_fixture(root, invalid_hash=True)
            with self.assertRaisesRegex(ValueError, 'invalid neural package entry'):
                validate_package(path, base)
            # Replacing the failed input and immediately reopening it exercises
            # cleanup/joining after a worker exception, then a healthy repeat.
            path, base = self.validation_fixture(root)
            self.assertEqual(validate_package(path, base), receipt)

    def test_sparse_archive_above_two_gib_retains_native_offsets_and_payload(self):
        # Sparse prefix crosses Python's conservative boundary without a
        # multi-gigabyte test payload or a change to the reviewed contents.
        previous=zipfile.ZIP64_LIMIT
        payload=b'shader and model bytes remain exact'
        with tempfile.TemporaryDirectory() as temporary:
            for compatible in (False,True):
                path=Path(temporary)/('classic.pk3' if compatible else 'zip64.pk3')
                with path.open('w+b') as stream:
                    stream.seek((1<<31)+64)
                    writer=classic_archive(stream) if compatible else zipfile.ZipFile(stream,'w')
                    with writer as archive:archive.writestr('scripts/probe.shader',payload)
                with zipfile.ZipFile(path) as archive:
                    self.assertEqual(archive.read('scripts/probe.shader'),payload)
                    if compatible:
                        require_classic_directory(path,archive)
                        self.assertGreater(archive.getinfo('scripts/probe.shader').header_offset,1<<31)
                    else:
                        with self.assertRaisesRegex(ValueError,'ZIP32'):require_classic_directory(path,archive)
        self.assertEqual(zipfile.ZIP64_LIMIT,previous)

    def test_forced_zip64_local_header_is_rejected_even_with_classic_directory(self):
        with tempfile.TemporaryDirectory() as temporary:
            path=Path(temporary)/'forced.pk3'
            with zipfile.ZipFile(path,'w') as archive:
                with archive.open('scripts/probe.shader','w',force_zip64=True) as stream:stream.write(b'unchanged')
            with zipfile.ZipFile(path) as archive:
                self.assertEqual(archive.read('scripts/probe.shader'),b'unchanged')
                with self.assertRaisesRegex(ValueError,'ZIP32'):require_classic_directory(path,archive)

    def test_prop_repair_retains_other_performances_and_package_integrity(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            base = root / 'base.pk3'
            base.write_bytes(b'original converted models remain unchanged')
            source, output = root / 'bad.pk3', root / 'fixed.pk3'
            files = {
                MANIFEST: b'models/e1/d1_supertorture.dkm models/neural/rack.iqm\nmodels/cinematic/c_super_e1m3.dkm models/neural/super.iqm\n',
                'models/neural/rack.iqm': b'incorrect generated body',
                'models/neural/rack.iqm.0.skin': b'incorrect skin',
                'models/neural/super.iqm': b'unchanged authored performance',
                'models/neural/super.iqm.0.skin': b'unchanged skin',
            }
            report = dict(format=1, source_models_sha256=hashlib.sha256(base.read_bytes()).hexdigest(),
                          files={name: hashlib.sha256(data).hexdigest() for name, data in files.items()},
                          models=[dict(source='models/e1/d1_supertorture.dkm'), dict(source='models/cinematic/c_super_e1m3.dkm')])
            with zipfile.ZipFile(source, 'w') as archive:
                for name, data in files.items(): archive.writestr(name, data)
                archive.writestr('dk3/neural-assets.json', json.dumps(report))
            original_hash = hashlib.sha256(source.read_bytes()).hexdigest()
            with self.assertRaisesRegex(ValueError, 'non-character prop'):
                validate_package(source, base)
            self.assertEqual(['models/neural/rack.iqm'], prune_props(source, output, base))
            self.assertEqual(original_hash, hashlib.sha256(source.read_bytes()).hexdigest())
            fixed = validate_package(output, base)
            self.assertEqual([dict(source='models/cinematic/c_super_e1m3.dkm')], fixed['models'])
            with zipfile.ZipFile(output) as archive:
                self.assertNotIn('models/neural/rack.iqm', archive.namelist())
                self.assertNotIn('models/neural/rack.iqm.0.skin', archive.namelist())
                self.assertEqual(files['models/neural/super.iqm'], archive.read('models/neural/super.iqm'))
                self.assertEqual(files['models/neural/super.iqm.0.skin'], archive.read('models/neural/super.iqm.0.skin'))
