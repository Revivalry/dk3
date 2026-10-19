#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-or-later
"""Guarded local pickup capture for an explicitly installed HD weapon preview."""
import argparse
import json
from pathlib import Path
import shutil
import subprocess
import tempfile
import zipfile

import hd_weapons

from runtime_input import NativeInput, engine_failure
from runtime_probe import client_settings, stage_client_modules, wait


def run(args):
    weapon = next((row for row in hd_weapons.roster() if row['class_name'] == args.class_name), None)
    if weapon is None:
        raise ValueError(f'unknown weapon class: {args.class_name}')
    with zipfile.ZipFile(args.package) as archive:
        mapping = dict(line.split() for line in archive.read(hd_weapons.MAPPING).decode().splitlines())
    source = weapon['view' if args.view else 'world']
    if source is None or source not in mapping:
        raise ValueError(f'{args.class_name}: requested representation is absent from the preview package')
    replacement = f'{source} -> {mapping[source]}'
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
                if args.view:
                    driver.issue(f'dk3_runtime_equip {args.weapon_id}')
                    driver.elapsed(700)
                    driver.issue(f'screenshotJPEG {args.class_name}-hd-warmup')
                    warmup = home / f'dk3/screenshots/{args.class_name}-hd-warmup.jpg'
                    wait(process, log, lambda text: warmup.is_file() and warmup.stat().st_size > 0 or engine_failure(text), 10)
                    wait(process, log, lambda text: 'dk3 HD weapon: ' + replacement in text or engine_failure(text), 10)
                    driver.elapsed(350)
                    if args.view_action == 'fire':
                        driver.issue('+attack')
                        driver.elapsed(80)
                        driver.issue('-attack')
                else:
                    driver.aim(state['angles'][1], 23)
                    before = len(driver.text())
                    driver.issue(f'dk3_runtime_spawn_item weapon_{args.class_name}')
                    wait(process, log, lambda text: 'dk3 fixture item:' in text[before:] or engine_failure(text[before:]), 10)
                    driver.issue('dk3_runtime_items')
                    driver.issue('cg_drawGun 0')
                    driver.issue('+back')
                    driver.elapsed(500)
                    driver.issue('-back')
                    driver.aim(state['angles'][1], 35)
                    driver.elapsed(700)
                before = len(driver.text())
                screenshot_name = (f'{args.class_name}-hd-view-fire' if args.view_action == 'fire' else
                                   f'{args.class_name}-hd-view') if args.view else f'{args.class_name}-hd-pickup'
                driver.issue('screenshotJPEG ' + screenshot_name)
                screenshot = home / f'dk3/screenshots/{screenshot_name}.jpg'
                wait(process, log, lambda text: screenshot.is_file() and screenshot.stat().st_size > 0 or engine_failure(text[before:]), 10)
                image = args.report / f'{args.renderer}-{args.class_name}-{"view-fire" if args.view_action == "fire" else "view" if args.view else "pickup"}.jpg'
                shutil.copy2(screenshot, image)
                text = driver.text()
                if 'dk3 HD weapon: ' + replacement not in text:
                    raise RuntimeError('HD weapon replacement was not registered: ' + replacement)
                (args.report / f'{args.renderer}-inputs.json').write_text(json.dumps(inputs, indent=2) + '\n')
                return {'renderer': args.renderer, 'map': args.map, 'representation': 'view' if args.view else 'world',
                        'replacement_loaded': True, 'screenshot': str(image),
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
    parser.add_argument('--package', type=Path, required=True, help='installed preview package containing the expected mapping')
    parser.add_argument('--class-name', required=True, help='registered weapon class')
    parser.add_argument('--weapon-id', type=int, help='numeric runtime weapon id for a view capture')
    parser.add_argument('--guard', type=Path, required=True)
    parser.add_argument('--report', type=Path, required=True)
    parser.add_argument('--renderer', choices=('opengl2', 'vulkan'), default='opengl2')
    parser.add_argument('--map', default='e4m1a')
    parser.add_argument('--view', action='store_true', help='capture the first-person replacement instead of a pickup')
    parser.add_argument('--view-action', choices=('idle', 'fire'), default='idle')
    args = parser.parse_args()
    if args.view_action != 'idle' and not args.view:
        parser.error('--view-action requires --view')
    if args.view and args.weapon_id is None:
        parser.error('--view requires --weapon-id')
    for key in ('engine', 'prefix', 'package', 'guard', 'report'):
        setattr(args, key, getattr(args, key).resolve())
    print(json.dumps(run(args), indent=2))


if __name__ == '__main__':
    main()
