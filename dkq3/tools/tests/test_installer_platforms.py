# SPDX-License-Identifier: GPL-2.0-or-later
"""Windows installer regressions using synthetic data and recorded child commands."""
import json
from pathlib import Path
import struct
import subprocess
import sys
import tempfile
from types import SimpleNamespace
import unittest
from unittest import mock

import dkpak
import install_wizard

TOOLS = Path(__file__).resolve().parents[1]


class InstallerPlatforms(unittest.TestCase):
    def test_conversion_without_unix_resource_module(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            archive = root / 'fixture.pak'
            # One uncompressed, top-origin 24-bit TGA, two pixels wide.
            tga = struct.pack('<BBBHHBHHHHBB', 0, 0, 2, 0, 0, 0, 0, 0, 2, 1, 24, 32)
            dkpak.write_pak(str(archive), {'pics/fixture.tga': tga + bytes([0, 0, 255, 0, 255, 0])})
            bootstrap = ('import sys; sys.modules["resource"] = None; '
                         f'sys.path.insert(0, {str(TOOLS)!r}); '
                         'import dkm2md3, dk_extract; '
                         'raise SystemExit(dk_extract.main())')
            result = subprocess.run([sys.executable, '-B', '-c', bootstrap, str(archive),
                '--out', str(root / 'images'), '--manifest', str(root / 'manifest.json'),
                '--summary', str(root / 'summary.txt'), '--workers', '2'],
                text=True, capture_output=True, timeout=60)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            record = json.loads((root / 'manifest.json').read_text())['images']['pics/fixture']
            self.assertEqual(record['status'], 'image')
            self.assertTrue((root / 'images/pics/fixture.png').is_file())
            self.assertIn('peak RSS unavailable', result.stderr)

    def test_windows_hd_installs_cuda_torch_before_requirements_and_probe(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            (root / 'dkq3/tools').mkdir(parents=True)
            (root / 'dkq3/tools/produce.py').touch()
            commands = []
            ui = SimpleNamespace(run=commands.append, update=lambda event: None)
            with mock.patch.object(install_wizard, 'os', SimpleNamespace(name='nt')), \
                 mock.patch.object(install_wizard.assets, 'current_generation', return_value=root), \
                 mock.patch.object(install_wizard, 'bundle_tool', return_value=root / 'dkguard.exe'):
                install_wizard.generate_hd(root, root / 'python.exe', root, root, ['esrgan'], ui)
            torch, requirements, probe = commands[:3]
            self.assertIn('torch==2.11.0+cu128', torch)
            self.assertEqual(torch[torch.index('--index-url') + 1],
                             'https://download.pytorch.org/whl/cu128')
            self.assertIn('--upgrade', torch)
            self.assertIn('-r', requirements)
            self.assertIn('torch.cuda.is_available()', probe[-1])


if __name__ == '__main__':
    unittest.main()
