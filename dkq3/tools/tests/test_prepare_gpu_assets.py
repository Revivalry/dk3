"""Prepared GPU packages preserve exact integer filtering and source identity."""
import hashlib
import io
import struct
import tempfile
import unittest
from pathlib import Path
import zipfile
import zlib

import numpy as np
from PIL import Image
import prepare_gpu_assets as prepare


def png(width, height, seed=0):
    pixels = ((np.arange(width * height * 4, dtype=np.uint32) + seed) % 256).astype(np.uint8).reshape(height, width, 4)
    output = io.BytesIO()
    Image.fromarray(pixels).save(output, format='PNG')
    return output.getvalue(), pixels


class PreparedGpuAssetsTest(unittest.TestCase):
    def test_shards_respect_budget_and_admission_checks_every_package(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            source = root/'source.pk3'
            with zipfile.ZipFile(source, 'w') as archive:
                for i in range(10):
                    archive.writestr(f'textures/{i}.png', png(16, 16, i)[0])
            manifest = prepare.build_generation([source], root/'generation', package_limit=10000)
            self.assertGreater(len(manifest['packages']), 1)
            packages = prepare.validate_generation(root/'generation')
            self.assertEqual(len(manifest['packages']), len(packages))
            self.assertTrue(all(path.stat().st_size <= 10000 for path in packages))
            package = packages[0]
            package.write_bytes(package.read_bytes() + b'changed')
            with self.assertRaises(ValueError):
                prepare.validate_generation(root/'generation')
            with self.assertRaises(FileExistsError):
                prepare.build_generation([source], root/'generation', package_limit=10000)

    def test_exact_mips_cover_odd_sizes_and_single_axes(self):
        for width, height in ((7, 3), (1, 17), (17, 1), (1, 1), (16, 8)):
            source, pixels = png(width, height)
            result = prepare.prepare_texture(source)
            self.assertEqual(result[:8], b'DK3TEX1\0')
            self.assertEqual(result[24:56], hashlib.sha256(source).digest())
            self.assertEqual(struct.unpack_from('<I', result, 56)[0], zlib.crc32(result[64:]))
            w, h, count, reserved = struct.unpack_from('<4I', result, 8)
            self.assertEqual((w, h, reserved), (width, height, 0))
            for level in range(count):
                offset, size, w, h = struct.unpack_from('<4I', result, 64 + level * 16)
                self.assertEqual((w, h), (pixels.shape[1], pixels.shape[0]))
                self.assertEqual(result[offset:offset + size], pixels.tobytes())
                if w == h == 1:
                    self.assertEqual(level, count - 1)
                    break
                next_pixels = np.empty((max(h // 2, 1), max(w // 2, 1), 4), dtype=np.uint8)
                for y in range(next_pixels.shape[0]):
                    for x in range(next_pixels.shape[1]):
                        for channel in range(4):
                            next_pixels[y, x, channel] = sum(int(pixels[min(2*y+dy, h-1), min(2*x+dx, w-1), channel]) for dy in (0, 1) for dx in (0, 1)) // 4
                pixels = next_pixels

    def test_parallel_packages_are_deterministic_and_preserve_override_priority(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            first, second = root/'first.pk3', root/'second.pk3'
            original = png(7, 3)[0]
            override = png(7, 3, 19)[0]
            with zipfile.ZipFile(first, 'w') as archive:
                archive.writestr('textures/a.png', original)
                archive.writestr('textures/b.png', png(1, 9)[0])
            with zipfile.ZipFile(second, 'w') as archive:
                archive.writestr('textures/a.png', override)
            for workers in (1, 4):
                prepare.build_package([first, second], root/f'gpu-{workers}.pk3', workers)
            self.assertEqual((root/'gpu-1.pk3').read_bytes(), (root/'gpu-4.pk3').read_bytes())
            with zipfile.ZipFile(root/'gpu-4.pk3') as archive:
                self.assertEqual(archive.read(prepare.texture_path('textures/a.png'))[24:56], hashlib.sha256(override).digest())
            self.assertEqual(prepare.texture_path('TEXTURES\\A.PNG'), prepare.texture_path('textures/a.png'))
            with self.assertRaises(ValueError):
                prepare.build_package([first], root/'gpu-1.pk3')
            with self.assertRaises(ValueError):
                prepare.build_package([first], root/'invalid.pk3', 9)

    def test_corrupt_input_does_not_publish_partial_package(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            source = root/'source.pk3'
            content = png(7, 3)[0]
            with zipfile.ZipFile(source, 'w', compression=zipfile.ZIP_STORED) as archive:
                archive.writestr('textures/a.png', content)
            blob = bytearray(source.read_bytes())
            blob[blob.index(content) + len(content)//2] ^= 1
            source.write_bytes(blob)
            with self.assertRaises(zipfile.BadZipFile):
                prepare.build_package([source], root/'gpu.pk3')
            self.assertFalse((root/'gpu.pk3').exists())
            self.assertFalse((root/'gpu.pk3.tmp').exists())
