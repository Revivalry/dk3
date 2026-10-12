#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-or-later
"""Guarded local pickup capture for an explicitly installed HD weapon preview."""
import argparse
import json
from pathlib import Path
import shutil
import subprocess
import tempfile

from runtime_input import NativeInput, engine_failure
from runtime_probe import client_settings, stage_client_modules, wait


def run(args):
    args.report.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='dk3-hd-weapon-review-') as temporary:
        home = Path(temporary)
        stage_client_modules(args.prefix, home)
        log = args.report / f'{args.renderer}.log'
        command = [str(args.guard), '--headless', '--screen', '960x540', '--timeout', '90s', '--mem', '8G',
                   '--', str(args.engine / 'bin/dk3')]
        for key, value in client_settings(args.engine, home, args.renderer).items():
            command.extend(('+set', key, value))
        command.extend(('+devmap', args.map))
        inputs = []
        (args.report / f'{args.renderer}-command.json').write_text(json.dumps(command, indent=2) + '\n')
        with log.open('w') as output:
            process = subprocess.Popen(command, stdout=output, stderr=subprocess.STDOUT)
            try:
                wait(process, log, lambda text: 'dk3 zig client: first snapshot applied' in text or engine_failure(text), 45)
                driver = NativeInput(process, home / 'dk3/commands.fifo', log, home, inputs, diagnostic=True)
                state = driver.observe()
                driver.aim(state['angles'][1], 23)
                before = len(driver.text())
                driver.issue('dk3_runtime_spawn_item weapon_glock')
                wait(process, log, lambda text: 'dk3 fixture item:' in text[before:] or engine_failure(text[before:]), 10)
                driver.elapsed(700)
                before = len(driver.text())
                driver.issue('screenshotJPEG glock-hd-pickup')
                screenshot = home / 'dk3/screenshots/glock-hd-pickup.jpg'
                wait(process, log, lambda text: screenshot.is_file() and screenshot.stat().st_size > 0 or engine_failure(text[before:]), 10)
                shutil.copy2(screenshot, args.report / f'{args.renderer}-glock-pickup.jpg')
                text = driver.text()
                if 'dk3 HD weapon: models/e4/a_glock.dkm -> models/hd-weapons/glock/world.iqm' not in text:
                    raise RuntimeError('HD Glock world replacement was not registered')
                (args.report / f'{args.renderer}-inputs.json').write_text(json.dumps(inputs, indent=2) + '\n')
                return {'renderer': args.renderer, 'map': args.map, 'replacement_loaded': True,
                        'screenshot': str(args.report / f'{args.renderer}-glock-pickup.jpg'),
                        'state': 'implemented; visual review pending'}
            finally:
                if process.poll() is None:
                    try:
                        from runtime_probe import send
                        send(home / 'dk3/commands.fifo', 'quit')
                        process.wait(timeout=10)
                    except (OSError, subprocess.TimeoutExpired):
                        process.terminate()
                        process.wait(timeout=10)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--engine', type=Path, required=True)
    parser.add_argument('--prefix', type=Path, required=True)
    parser.add_argument('--guard', type=Path, required=True)
    parser.add_argument('--report', type=Path, required=True)
    parser.add_argument('--renderer', choices=('opengl2', 'vulkan'), default='opengl2')
    parser.add_argument('--map', default='e4m1a')
    args = parser.parse_args()
    for key in ('engine', 'prefix', 'guard', 'report'):
        setattr(args, key, getattr(args, key).resolve())
    print(json.dumps(run(args), indent=2))


if __name__ == '__main__':
    main()
