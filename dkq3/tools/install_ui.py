"""Scrollback-friendly installer presentation and supervised, logged operations."""
from contextlib import contextmanager
import json
import os
from pathlib import Path
import signal
import shlex
import subprocess
import sys
import time

from install_progress import STAGES


class InstallerUI:
    def __init__(self, bundle=None, plain=False, stream=None):
        self.stream = stream or sys.stdout
        self.console = self.progress = None
        self.log = self.events = None
        self.offset = 0
        self.pending = ''
        self.done = set()
        self.current_stage = None
        self.last_notice = 0
        self.detail = ''
        self.operation = 'Installation'
        # Pure Python wheels are zip-importable before pip or NumPy exists.
        # Their original distribution metadata and licenses stay in the bundle.
        if bundle:
            sys.path[:0] = [str(path) for path in sorted((bundle / 'runtime/wheels').glob('*-none-any.whl'))]
        if not plain:
            try:
                from rich.console import Console
                self.console = Console(file=self.stream, highlight=False, markup=False)
            except ImportError:
                pass
        self.animated = bool(self.console and self.console.is_terminal and os.environ.get('TERM') != 'dumb')

    def message(self, text, style=None):
        if self.console:
            self.console.print(str(text), style=style)
        else:
            print(text, file=self.stream, flush=True)

    def welcome(self):
        if self.console:
            from rich.panel import Panel
            from rich.text import Text
            self.console.print(Panel(Text('dk3 · Installation\nChoose your game data, destination, and texture quality.'),
                                     border_style='cyan', expand=False))
        else:
            self.message('\ndk3 · Installation')
        self.message('Your original game and saves stay in their current location.')

    def choose(self, label, options, default=0):
        self.message('\n' + label, 'bold cyan')
        for index, option in enumerate(options, 1):
            self.message(f'  {index}. {option}' + ('  ← default' if index == default + 1 else ''))
        while True:
            response = input(f'Choose 1–{len(options)} [Enter = {default + 1}]: ').strip()
            if not response:
                return default
            if response.isdigit() and 1 <= int(response) <= len(options):
                return int(response) - 1
            self.message('Please enter a listed number, or press Enter for the default.', 'yellow')

    def summary(self, source, destination, textures):
        self.message('\nReady to install', 'bold cyan')
        self.message(f'  Game data:   {source}\n  Install to:  {destination}\n  Textures:    {textures}')
        self.message('Conversion can take a while, especially navigation. Completed work is kept for resume.')

    @contextmanager
    def session(self, destination):
        installer = destination / '.installer'
        installer.mkdir(parents=True, exist_ok=True)
        self.log = installer / 'install.log'
        self.events = installer / 'progress.jsonl'
        self.events.write_text('', encoding='utf-8')
        self.offset, self.pending = 0, ''
        self.message(f'\nInstallation log: {self.log}')
        self.message('Ctrl+C cancels installation. Run the installer again with this destination to resume.')
        if self.animated:
            from rich.progress import Progress, SpinnerColumn, TextColumn, BarColumn, TimeElapsedColumn
            from rich.table import Column
            self.progress = Progress(SpinnerColumn(), TextColumn('{task.description}', markup=False),
                                     BarColumn(bar_width=None), TextColumn('{task.fields[count]}', markup=False),
                                     TextColumn('{task.fields[detail]}', markup=False,
                                                table_column=Column(max_width=28, overflow='ellipsis')),
                                     TimeElapsedColumn(), console=self.console, refresh_per_second=4,
                                     expand=True, redirect_stdout=False, redirect_stderr=False)
            self.overall = self.progress.add_task('Asset stages', total=len(STAGES), count=f'0/{len(STAGES)}', detail='')
            self.task = self.progress.add_task('Starting', total=None, count='', detail='')
            self.progress.start()
        try:
            yield self
        finally:
            if self.progress:
                self.progress.stop()
                self.progress = None

    def update(self, event):
        stage = event.get('stage', '')
        label = STAGES.get(stage, stage or 'Working')
        state = event.get('state', 'running')
        completed, total = event.get('completed'), event.get('total')
        changed = stage != self.current_stage
        if state == 'done' and stage in STAGES:
            self.done.add(stage)
        if stage == 'complete':
            self.done.update(STAGES)
            label = 'Game data ready'
        self.current_stage = stage
        self.detail = str(event.get('detail') or '')
        count = f'{completed}/{total}' if total is not None and completed is not None else ''
        if state == 'done':
            count = 'Reused' if event.get('cached') else 'Done'
            total, completed = 1, 1
        if self.progress:
            if changed or self.progress.tasks[-1].total != total:
                self.reset_task(label, total)
            self.progress.update(self.task, description=label, total=total, completed=completed or 0,
                                 count=count, detail=self.detail)
            self.progress.update(self.overall, completed=len(self.done), count=f'{len(self.done)}/{len(STAGES)}')
        elif changed or state == 'done' or time.monotonic() - self.last_notice >= 10:
            self.message(f'  {label}: {count or "working"}' + (f' · {self.detail}' if self.detail else ''))
            self.last_notice = time.monotonic()

    def reset_task(self, label, total=None):
        # Rich.reset(total=None) preserves the previous total. A fresh task is
        # needed when the next operation has no measurable total.
        self.progress.remove_task(self.task)
        self.task = self.progress.add_task(label, total=total, count='', detail='')

    def poll(self):
        if self.events:
            with self.events.open(encoding='utf-8') as stream:
                stream.seek(self.offset)
                self.pending += stream.read()
                self.offset = stream.tell()
            lines = self.pending.split('\n')
            self.pending = lines.pop()
            for line in lines:
                try:
                    self.update(json.loads(line))
                except (ValueError, TypeError, AttributeError):
                    continue
        if not self.progress and time.monotonic() - self.last_notice >= 30:
            self.message('  Still working' + (f' · {self.detail}' if self.detail else '') + ' …')
            self.last_notice = time.monotonic()

    @contextmanager
    def phase(self, label):
        self.operation = label
        self.message('\n' + label, 'bold cyan')
        if self.log:
            with self.log.open('a', encoding='utf-8') as output:
                output.write('\n=== ' + label + ' ===\n')
        self.last_notice = time.monotonic()
        self.detail = ''
        self.current_stage = None
        if self.progress:
            self.reset_task(label)
        try:
            yield
        except BaseException:
            if self.progress:
                self.progress.update(self.task, description=label + ' · stopped', count='')
            raise
        else:
            if self.progress:
                self.progress.update(self.task, total=1, completed=1, count='Done')

    def run(self, command):
        if self.log is None:
            return subprocess.run(command, check=True)
        environment = dict(os.environ, DK3_INSTALL_PROGRESS=str(self.events))
        with self.log.open('ab') as output:
            output.write(('\n--- ' + str(command[0]) + ' ---\n').encode())
            output.flush()
            process = subprocess.Popen(command, stdout=output, stderr=subprocess.STDOUT, env=environment,
                                       start_new_session=os.name != 'nt')
            try:
                while True:
                    self.poll()
                    try:
                        status = process.wait(timeout=0.2)
                        break
                    except subprocess.TimeoutExpired:
                        continue
            except BaseException:
                try:
                    if os.name != 'nt':
                        os.killpg(process.pid, signal.SIGTERM)
                    else:
                        process.terminate()
                except ProcessLookupError:
                    pass
                try:
                    process.wait(timeout=10)
                except subprocess.TimeoutExpired:
                    if os.name != 'nt':
                        os.killpg(process.pid, signal.SIGKILL)
                    else:
                        process.kill()
                    process.wait()
                raise
            self.poll()
        if status:
            tail = self.log.read_text(errors='replace').splitlines()[-12:]
            self.message('\n' + '\n'.join(tail), 'red')
            raise subprocess.CalledProcessError(status, command)
        return subprocess.CompletedProcess(command, status)

    def result(self, destination, desktop=None):
        self.message('\nInstallation complete', 'bold green')
        launcher = destination / ('play.cmd' if os.name == 'nt' else 'play.sh')
        command = shlex.quote(str(launcher)) if os.name != 'nt' else f'"{launcher}"'
        self.message('Run in a terminal:')
        if self.console:
            self.console.print('  ' + command, soft_wrap=True)
        else:
            self.message('  ' + command)
        if desktop:
            self.message('Or open Applications and search for “dk3”.')
            self.message(f'Application shortcut: {desktop}')
        if self.log:
            self.message(f'Installation log: {self.log}')
