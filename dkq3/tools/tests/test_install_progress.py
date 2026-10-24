"""Exercise real child progress, diagnostics, cancellation, and terminal rendering."""
import io
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

from install_ui import InstallerUI


class ProgressTests(unittest.TestCase):
    def command(self, code):
        tools = str(Path(__file__).resolve().parents[1])
        return [sys.executable, '-u', '-c', f'import sys; sys.path.insert(0, {tools!r}); ' + code]

    def test_child_progress_and_diagnostics_survive_without_a_tty(self):
        output = io.StringIO()
        ui = InstallerUI(plain=True, stream=output)
        with tempfile.TemporaryDirectory() as temporary:
            with ui.session(Path(temporary)):
                ui.run(self.command('from install_progress import emit; '
                    'print("full diagnostic detail"); '
                    'emit(1, 3, "e1m1a", stage="navigation"); '
                    'emit(3, 3, "e1m2a", stage="navigation"); '
                    'emit(stage="navigation", state="done")'))
            self.assertIn('full diagnostic detail', ui.log.read_text())
            self.assertNotIn('full diagnostic detail', output.getvalue())
            self.assertIn('Building navigation', output.getvalue())
            self.assertEqual(ui.done, {'navigation'})
            self.assertNotIn('\x1b', output.getvalue())

    def test_failed_child_keeps_partial_progress_and_names_its_log(self):
        output = io.StringIO()
        ui = InstallerUI(plain=True, stream=output)
        with tempfile.TemporaryDirectory() as temporary:
            with ui.session(Path(temporary)):
                with self.assertRaises(subprocess.CalledProcessError) as raised:
                    ui.run(self.command('from install_progress import emit; '
                        'emit(1, 3, "map-a", stage="navigation"); '
                        'print("compiler failure: useful reason"); sys.exit(7)'))
            self.assertEqual(raised.exception.returncode, 7)
            self.assertFalse(ui.done)
            self.assertIn('compiler failure: useful reason', output.getvalue())
            self.assertIn(str(ui.log), output.getvalue())

    @unittest.skipIf(os.name == 'nt', 'POSIX process-group cancellation')
    def test_cancel_waits_for_its_worker_to_exit(self):
        ui = InstallerUI(plain=True, stream=io.StringIO())
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            pid = root / 'worker.pid'
            original_poll = ui.poll
            def cancel_when_running():
                original_poll()
                if pid.is_file():
                    raise KeyboardInterrupt
            ui.poll = cancel_when_running
            with ui.session(root):
                with self.assertRaises(KeyboardInterrupt):
                    ui.run(self.command('import os,time; from pathlib import Path; '
                                        f'Path({str(pid)!r}).write_text(str(os.getpid())); time.sleep(60)'))
            with self.assertRaises(ProcessLookupError):
                os.kill(int(pid.read_text()), 0)

    def test_partial_event_is_read_on_the_next_poll(self):
        ui = InstallerUI(plain=True, stream=io.StringIO())
        with tempfile.TemporaryDirectory() as temporary:
            with ui.session(Path(temporary)):
                event = json.dumps(dict(stage='models', state='done', cached=True))
                ui.events.write_text(event[:12])
                ui.poll()
                self.assertFalse(ui.done)
                with ui.events.open('a') as output:
                    output.write(event[12:] + '\n')
                ui.poll()
                self.assertEqual(ui.done, {'models'})

    def test_rich_terminal_renders_real_counts_and_literal_names(self):
        output = io.StringIO()
        ui = InstallerUI(stream=output)
        if ui.console is None:
            self.skipTest('Rich wheelhouse not on the test import path')
        ui.console = type(ui.console)(file=output, force_terminal=True, width=110, markup=False)
        ui.animated = True
        with tempfile.TemporaryDirectory() as temporary:
            with ui.session(Path(temporary)):
                ui.update(dict(stage='navigation', completed=23, total=98, detail='e1m1a[red]'))
                ui.progress.refresh()
                self.assertEqual(ui.progress.tasks[-1].completed, 23)
                self.assertEqual(ui.progress.tasks[-1].total, 98)
                self.assertEqual(ui.progress.tasks[ui.overall].completed, 0)
                ui.update(dict(stage='navigation', state='done'))
                ui.update(dict(stage='Checking installation'))
                self.assertIsNone(ui.progress.tasks[-1].total)
            self.assertIn('23/98', output.getvalue())
            self.assertIn('e1m1a[red]', output.getvalue())


if __name__ == '__main__':
    unittest.main()
