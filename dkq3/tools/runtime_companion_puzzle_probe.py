#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-or-later
"""Automatic companion station in a copied owner save; invoke with dkguard --headless.

The initial player steps away through normal movement. Completion uses diagnostic
placement and ordinary use, or explicit --diagnostic-release activation of the
authored wheel. --active-world-only labels a room fixture omitting other resident
worlds. No companion orders are issued.
"""
import argparse
import hashlib
import json
import math
from pathlib import Path
import re
import shutil
import struct
import zlib

from runtime_bugfix_probe import run
from runtime_saved_mover_probe import movers, records
from runtime_probe import wait


def setup(home, report):
    directory = home / 'state/dk3/saves'
    directory.mkdir(parents=True, exist_ok=True)
    if args.active_world_only:
        # Isolate the exact room/entity state from the owner's resident worlds.
        # This is a labelled diagnostic fixture, never a replacement owner save.
        original = args.save.read_bytes()
        offset, chunks = 24, []
        while offset < len(original):
            size = struct.unpack_from('<I', original, offset)[0]
            length = original[offset + 10]
            name = original[offset + 12:offset + 12 + length]
            if name in (b'campaign', b'native_entity'):
                chunks.append(original[offset:offset + size])
            offset += size
        payload = b''.join(chunks)
        header = struct.pack('<8sIIII', b'DK3SAVE\0', 1, 24 + len(payload), len(chunks), zlib.crc32(payload))
        (directory / 'reported.sav').write_bytes(header + payload)
    else:
        shutil.copy2(args.save, directory / 'reported.sav')
    (report / 'source.json').write_text(json.dumps(dict(path=str(args.save), sha256=args.source_hash), indent=2))


def exercise(driver, report, capture):
    driver.issue('load reported')
    wait(driver.process, driver.log, lambda t: 'dk3 zig: saved world restored' in t and 'dk3 zig client: restoration applied' in t, 120)
    driver.until(lambda s: s['map'] == 'e2m4b' and s['mode'] == 'normal', seconds=120)
    driver.aim(0, 20)
    capture('reported-switch')
    driver.issue('+back')
    driver.elapsed(400)
    driver.issue('-back')
    marker = len(driver.text())
    driver.until(lambda _: 'why=puzzle-hold' in driver.text()[marker:], seconds=40, description='Mikiko physically activates the plate without orders')
    required = [i for i, row in args.rows.items() if 'mover' in row and row['map_object']['targetname'] in ('leftbutdown', 'exbars', 'exdoors')]
    assert len(required) == 4
    held = {}
    def doors_open(state):
        nonlocal held
        held = movers(driver)
        return state['mode'] == 'normal' and all(held[i]['state'] == 'open' for i in required)
    driver.until(doors_open, seconds=15, description='Authored monitor finishes and all exit doors open')
    assert all(held[i]['state'] == 'open' for i in required), {i: held[i] for i in required}
    capture('automatic-hold')
    persistence = {}
    try:
        if args.skip_save:
            raise RuntimeError('Save check omitted in full-region replay; separate room fixture covers persistence')
        saved = driver.save('holding')
        shutil.copy2(saved, report / 'holding.sav')
        companion = next(json.loads(fields['companion']) for name, _, fields in records(saved.read_bytes()) if name == 'native_entity' and 'companion' in fields)
        assert companion['puzzle']['holding']
        driver.load('holding')
        driver.until(lambda _: 'why=puzzle-hold' in driver.text().split('dk3 zig client: restoration applied')[-1], seconds=10)
        persistence['passed'] = True
    except RuntimeError as error:
        persistence.update(passed=False, error=str(error))
    # The wheel's authored target unlocks the return path and removes the
    # station's event chain. A physical use must make the helper rejoin.
    identity, wheel = next((i, r) for i, r in args.rows.items() if r.get('map_object', {}).get('model') == '*28')
    origin = wheel['transform']['position']
    center = [origin[i] + (wheel['body']['mins'][i] + wheel['body']['maxs'][i]) / 2 for i in range(3)]
    # Face the wheel's thin brush axis; looking along its plane hits the wall.
    axis = min(range(3), key=lambda i: wheel['body']['maxs'][i] - wheel['body']['mins'][i])
    point = list(center)
    point[axis] -= 64
    point[2] -= 22
    marker = len(driver.text())
    if args.diagnostic_release:
        driver.issue(f'dk3_runtime_activate {identity} player')
    else:
        driver.issue('dk3_runtime_place ' + ' '.join(map(str, point)))
        driver.elapsed(300)
        player = driver.observe()
        delta = [center[i] - player['pos'][i] - (22 if i == 2 else 0) for i in range(3)]
        driver.aim(math.degrees(math.atan2(delta[1], delta[0])), -math.degrees(math.atan2(delta[2], math.hypot(*delta[:2]))))
        driver.issue('use')
    driver.until(lambda _: "The way is open. I'm coming with you." in driver.text()[marker:], seconds=20, description='Authored release returns the helper')
    driver.issue('cin_skip')
    driver.elapsed(500)
    capture('automatic-return')
    if persistence.get('passed'):
        released = driver.save('released')
        shutil.copy2(released, report / 'released.sav')
        companion = next(json.loads(fields['companion']) for name, _, fields in records(released.read_bytes()) if name == 'native_entity' and 'companion' in fields)
        assert companion['puzzle'] is None and companion['order'] == 'follow'
    assert hashlib.sha256(args.save.read_bytes()).hexdigest() == args.source_hash
    return dict(held=held, persistence=persistence, wheel=identity, source_unchanged=True, active_world_only=args.active_world_only, diagnostic_release=args.diagnostic_release,
                scope='Copied save, automatic physical approach/hold, normal player backstep. Release uses diagnostic wheel activation when explicitly selected, otherwise diagnostic placement and ordinary use. No companion orders. Full campaign traversal remains unverified.')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--engine', type=Path, required=True)
    parser.add_argument('--save', type=Path, required=True)
    parser.add_argument('--report', type=Path, required=True)
    parser.add_argument('--renderer', default='opengl1')
    parser.add_argument('--active-world-only', action='store_true')
    parser.add_argument('--skip-save', action='store_true')
    parser.add_argument('--diagnostic-release', action='store_true')
    args = parser.parse_args()
    args.engine, args.save, args.report = args.engine.resolve(), args.save.resolve(), args.report.resolve()
    args.source_hash = hashlib.sha256(args.save.read_bytes()).hexdigest()
    args.rows = {i: {k: json.loads(v) for k, v in fields.items()} for name, i, fields in records(args.save.read_bytes()) if name == 'native_entity'}
    args.scenario, args.start_map, args.developer = 'companion-puzzle', 'e2m4b', True
    args.capture_size = (320, 240)
    run(args, exercise, setup)
