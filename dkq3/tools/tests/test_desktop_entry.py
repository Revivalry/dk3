"""Validate application discovery and execute its literal path through GIO."""
import io
import os
from pathlib import Path
import shlex
import shutil
import subprocess
import sys
import tempfile
import time
import unittest
from unittest import mock

import desktop_entry
from install_ui import InstallerUI


@unittest.skipUnless(sys.platform.startswith('linux'), 'Linux XDG integration')
class DesktopTests(unittest.TestCase):
    def fixture(self, root):
        installation = root / 'Games with spaces' / 'dk3 $literal`"%name=1'
        (installation / 'play/current').mkdir(parents=True)
        (installation / 'play/current/installation.json').write_text('{}')
        (installation / 'share/dk3').mkdir(parents=True)
        (installation / 'share/dk3/dk3.svg').write_text('<svg xmlns="http://www.w3.org/2000/svg"/>')
        proof = root / 'launched'
        (installation / 'play.sh').write_text('#!/bin/sh\nprintf started > ' + shlex.quote(str(proof)) + '\n')
        return installation, proof

    def test_xdg_entry_is_discovered_and_launches_a_literal_custom_path(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            installation, proof = self.fixture(root)
            environment = dict(os.environ, XDG_DATA_HOME=str(root / 'xdg'))
            with mock.patch.dict(os.environ, environment):
                entry = desktop_entry.register(installation)
                self.assertEqual(desktop_entry.register(installation), entry)
            self.assertEqual(len(list(entry.parent.glob('*.desktop'))), 1)
            validator = shutil.which('desktop-file-validate')
            if validator:
                subprocess.run([validator, str(entry)], check=True, capture_output=True)
            gio = shutil.which('gio')
            if gio:
                result = subprocess.run([gio, 'launch', str(entry)], env=environment,
                                        capture_output=True, text=True)
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                deadline = time.monotonic() + 3
                while not proof.exists() and time.monotonic() < deadline:
                    time.sleep(0.02)
                self.assertEqual(proof.read_text(), 'started')
            # GLib's application database is the lookup used by GNOME. This is
            # optional on build hosts; descriptor and launch checks remain useful.
            check = subprocess.run(['/usr/bin/python3', '-c',
                'from gi.repository import Gio; '
                f'app=Gio.DesktopAppInfo.new({entry.name!r}); '
                'assert app is not None; assert app.get_display_name()=="dk3"; '
                'assert app.get_show_in("GNOME")'], env=environment, capture_output=True, text=True)
            if 'No module named' not in check.stderr:
                self.assertEqual(check.returncode, 0, check.stderr)

    def test_relative_xdg_path_uses_the_standard_home_fallback(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            installation, _ = self.fixture(root)
            with mock.patch.dict(os.environ, XDG_DATA_HOME='relative/not-valid'), \
                 mock.patch.object(Path, 'home', return_value=root):
                entry = desktop_entry.register(installation)
            self.assertEqual(entry.parent, root / '.local/share/applications')

    def test_incomplete_installation_does_not_publish_a_shortcut(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            with mock.patch.dict(os.environ, XDG_DATA_HOME=str(root / 'xdg')):
                with self.assertRaisesRegex(ValueError, 'no completed dk3 installation'):
                    desktop_entry.register(root)
            self.assertFalse((root / 'xdg').exists())

    def test_completion_command_is_shell_copyable(self):
        output = io.StringIO()
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            installation, proof = self.fixture(root)
            (installation / 'play.sh').chmod(0o755)
            InstallerUI(plain=True, stream=output).result(installation, root / 'dk3.desktop')
            command = output.getvalue().split('Run in a terminal:\n  ', 1)[1].splitlines()[0]
            subprocess.run(['/bin/sh', '-c', command], check=True)
            self.assertEqual(proof.read_text(), 'started')
            self.assertIn('search for “dk3”', output.getvalue())
