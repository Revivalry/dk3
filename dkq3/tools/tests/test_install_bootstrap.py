"""Run the public shell bootstrap through verification failures and stalled services."""
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest
import zipfile


BOOTSTRAP = Path(__file__).resolve().parents[3] / 'install.sh'


@unittest.skipUnless(sys.platform == 'linux' and shutil.which('timeout'),
                     'Linux bootstrap uses coreutils timeout')
class BootstrapTests(unittest.TestCase):
    def run_bootstrap(self, mode='success'):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            commands = root / 'commands'
            commands.mkdir()
            temporary = root / 'temporary'
            temporary.mkdir()
            wizard = root / 'wizard.json'
            archive = root / 'installer.zip'
            with zipfile.ZipFile(archive, 'w') as output:
                script = zipfile.ZipInfo('dk3-installer-linux-x64/install.sh')
                script.create_system = 3
                script.external_attr = 0o100755 << 16
                output.writestr(script, f'''#!{sys.executable}
import json, os, sys
from pathlib import Path
Path(os.environ['WIZARD_RESULT']).write_text(json.dumps({{
    'args': sys.argv[1:], 'input': sys.stdin.read()
}}))
''')
            digest = hashlib.sha256(archive.read_bytes()).hexdigest()
            if mode in ('mismatch', 'skip-mismatch'):
                digest = '0' * 64
            (root / 'SHA256SUMS').write_text(
                ('invalid' if mode == 'invalid' else digest)
                + '  dk3-installer-linux-x64.zip\n')
            shim = f'''#!{sys.executable}
import json, os, shutil, subprocess, sys
from pathlib import Path
name, args = Path(sys.argv[0]).name, sys.argv[1:]
with open(os.environ['COMMAND_LOG'], 'a') as log:
    log.write(json.dumps([name, *args]) + '\\n')
mode = os.environ['BOOTSTRAP_MODE']
if name == 'timeout':
    # Exercise real timeout/signalling, with short test-only deadlines.
    args = ['0.15s' if arg in ('20s', '120s') else arg for arg in args]
    os.execv(os.environ['REAL_TIMEOUT'], ['timeout', *args])
elif name == 'curl':
    checksum = any(arg.endswith('/SHA256SUMS') for arg in args)
    if checksum and mode == 'checksum-failure':
        print('curl: connection timed out', file=sys.stderr)
        sys.exit(28)
    source = 'SHA256SUMS' if checksum else 'installer.zip'
    shutil.copyfile(Path(os.environ['FIXTURE_ROOT']) / source, args[args.index('-o') + 1])
elif name == 'gh':
    auth = args[:2] == ['auth', 'status']
    if (auth and mode == 'auth-hang') or (not auth and mode == 'provenance-hang'):
        os.execl(os.environ['REAL_SLEEP'], 'sleep', '60')
    if auth:
        print('private authentication diagnostic')
        sys.exit(1 if mode == 'signed-out' else 0)
    assert os.environ['GH_PROMPT_DISABLED'] == '1'
    assert os.environ['GH_PAGER'] == 'cat'
    if mode == 'provenance-failure':
        print('signature rejected', file=sys.stderr)
        sys.exit(1)
    print('signed provenance verified')
'''
            for name in ('curl', 'gh', 'timeout'):
                path = commands / name
                path.write_text(shim)
                path.chmod(0o755)
            environment = {
                **os.environ, 'PATH': str(commands) + os.pathsep + os.environ['PATH'],
                'TMPDIR': str(temporary), 'FIXTURE_ROOT': str(root),
                'WIZARD_RESULT': str(wizard), 'COMMAND_LOG': str(root / 'commands.jsonl'),
                'REAL_TIMEOUT': shutil.which('timeout'), 'REAL_SLEEP': shutil.which('sleep'),
                'BOOTSTRAP_MODE': mode,
                'DK3_SKIP_ATTESTATION': '1' if mode in ('skip-provenance', 'skip-mismatch') else '0',
            }
            result = subprocess.run(
                ['sh', str(BOOTSTRAP), '--destination', '/a path/$literal', '--plain'],
                env=environment, input='wizard input\n', text=True,
                stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=5)
            calls = [json.loads(line) for line in (root / 'commands.jsonl').read_text().splitlines()]
            installed = json.loads(wizard.read_text()) if wizard.exists() else None
            self.assertEqual(list(temporary.iterdir()), [], 'bootstrap must clean its temporary files')
            self.assertNotIn('private authentication diagnostic', result.stdout)
            return result, calls, installed

    def test_verified_archive_reaches_wizard_with_arguments_and_terminal_input(self):
        result, calls, installed = self.run_bootstrap()
        self.assertEqual(result.returncode, 0, result.stdout)
        self.assertEqual(installed, {
            'args': ['--destination', '/a path/$literal', '--plain'], 'input': 'wizard input\n'})
        self.assertIn('Verifying signed build provenance', result.stdout)
        self.assertLess(result.stdout.index('Archive SHA-256 verified.'),
                        result.stdout.index('Verifying signed build provenance'))
        for call in calls:
            if call[0] == 'curl':
                self.assertIn('--connect-timeout', call)
                self.assertIn('--max-time', call)
                self.assertIn('--speed-time', call)

    def test_checksum_failures_never_run_provenance_or_wizard(self):
        for mode, diagnostic in (
                ('mismatch', 'Release checksum did not match'),
                ('invalid', 'Release checksum is missing or invalid'),
                ('checksum-failure', 'Checksum download failed')):
            with self.subTest(mode=mode):
                result, calls, installed = self.run_bootstrap(mode)
                self.assertNotEqual(result.returncode, 0)
                self.assertIn(diagnostic, result.stdout)
                self.assertFalse(any(call[0] == 'gh' for call in calls))
                self.assertIsNone(installed)

    def test_stalled_authentication_reports_its_stage_and_stops(self):
        result, calls, installed = self.run_bootstrap('auth-hang')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('GitHub CLI authentication timed out', result.stdout)
        self.assertFalse(any(call[:3] == ['gh', 'attestation', 'verify'] for call in calls))
        self.assertIsNone(installed)

    def test_stalled_provenance_reports_its_stage_and_stops(self):
        result, _, installed = self.run_bootstrap('provenance-hang')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('Signed build provenance verification timed out', result.stdout)
        self.assertIsNone(installed)

    def test_rejected_provenance_is_not_treated_as_a_timeout_or_skipped(self):
        result, _, installed = self.run_bootstrap('provenance-failure')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('signature rejected', result.stdout)
        self.assertIn('Signed build provenance could not be verified', result.stdout)
        self.assertNotIn('timed out', result.stdout)
        self.assertIsNone(installed)

    def test_signed_out_cli_keeps_existing_checksum_only_installation(self):
        result, calls, installed = self.run_bootstrap('signed-out')
        self.assertEqual(result.returncode, 0, result.stdout)
        self.assertIn('Sign in with gh', result.stdout)
        self.assertFalse(any(call[:3] == ['gh', 'attestation', 'verify'] for call in calls))
        self.assertIsNotNone(installed)

    def test_explicit_checksum_only_retry_avoids_github_and_sigstore(self):
        result, calls, installed = self.run_bootstrap('skip-provenance')
        self.assertEqual(result.returncode, 0, result.stdout)
        self.assertIn('Signed provenance check explicitly skipped', result.stdout)
        self.assertIn('archive SHA-256 verified', result.stdout)
        self.assertFalse(any(call[0] == 'gh' for call in calls))
        self.assertIsNotNone(installed)

    def test_explicit_provenance_skip_still_requires_a_matching_checksum(self):
        result, calls, installed = self.run_bootstrap('skip-mismatch')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('Release checksum did not match', result.stdout)
        self.assertFalse(any(call[0] == 'gh' for call in calls))
        self.assertIsNone(installed)


if __name__ == '__main__':
    unittest.main()
