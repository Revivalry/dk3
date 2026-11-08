#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-or-later
"""Replay opening e2m4c combat from a copied arrival save, through dkguard.

Firing placement and high player health are diagnostic fixtures. Attacks, enemy
deaths and the companion's autonomous combat use ordinary game controllers.
"""
import argparse
import hashlib
import json
from pathlib import Path
import shutil

from runtime_bugfix_probe import run, aim_actor
from runtime_opening_route import actors, terminal_contact
from runtime_probe import wait


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--engine', type=Path, default=Path('zig-out/native-dev/play/current'))
    parser.add_argument('--save', type=Path, required=True)
    parser.add_argument('--report', type=Path, required=True)
    parser.add_argument('--renderer', default='opengl1')
    parser.add_argument('--health', type=int, default=1000)
    parser.add_argument('--developer', action='store_true', default=True)
    parser.add_argument('--debugger', action='store_true')
    args = parser.parse_args()
    args.engine, args.save, args.report = args.engine.resolve(), args.save.resolve(), args.report.resolve()
    args.scenario, args.start_map, args.capture_size = 'arrival-combat', 'e2m4c', (640, 360)
    source_hash = hashlib.sha256(args.save.read_bytes()).hexdigest()

    def setup(home, report):
        directory = home / 'state/dk3/saves'
        directory.mkdir(parents=True, exist_ok=True)
        shutil.copy2(args.save, directory / 'reported.sav')
        (report / 'source.json').write_text(json.dumps(dict(path=str(args.save), sha256=source_hash)))

    def exercise(driver, report, capture):
        driver.issue('load reported')
        wait(driver.process, driver.log, lambda text: 'dk3 zig: saved world restored' in text and
             'dk3 zig client: restoration applied' in text, 120)
        driver.until(lambda state: state['map'] == args.start_map and state['mode'] == 'normal', seconds=120)
        capture('arrival')
        if args.health:
            driver.issue(f'dk3_runtime_probe_health {args.health}')
            driver.until(lambda state: state['health'] == args.health)
        initial = actors(driver)
        targets = (486539316, 486539321)
        if any(identity not in initial or initial[identity]['health'] <= 0 for identity in targets):
            raise RuntimeError('The copied arrival does not contain both living opening enemies')
        killed = []
        dead_before_approach = []
        for identity in targets:
            row = actors(driver).get(identity)
            if row is None or row['health'] <= 0:
                if row is None and terminal_contact(driver.text(), identity) is None:
                    raise RuntimeError(f'Enemy {identity} disappeared without a death receipt')
                # Autonomous companion combat can finish the second enemy
                # while the first encounter's quake is still settling.
                killed.append(identity)
                dead_before_approach.append(identity)
                capture(f'enemy-{identity}-already-dead')
                driver.elapsed(1500)
                continue
            driver.diagnostics(f'dk3_runtime_face_target {identity} 64', f'target={identity}')
            driver.elapsed(400)
            row = actors(driver).get(identity)
            if row is not None and row['health'] > 0:
                aim_actor(driver, row)
            capture(f'enemy-{identity}')
            for _ in range(4):
                driver.ready(12)
                row = actors(driver).get(identity)
                if row is None or row['health'] <= 0:
                    break
                aim_actor(driver, row)
                driver.issue('+attack')
                driver.elapsed(1850)
                driver.issue('-attack')
                driver.elapsed(1400)
            row = actors(driver).get(identity)
            if row is not None and row['health'] > 0:
                raise RuntimeError(f'Enemy {identity} survived the encounter: {row}')
            if row is None and terminal_contact(driver.text(), identity) is None:
                raise RuntimeError(f'Enemy {identity} disappeared without a death receipt')
            killed.append(identity)
            driver.elapsed(1500)
        driver.elapsed(6000)
        capture('after-kills')
        if hashlib.sha256(args.save.read_bytes()).hexdigest() != source_hash:
            raise RuntimeError('Source save changed during the replay')
        return dict(killed=killed, dead_before_approach=dead_before_approach,
                    source_unchanged=True, player_health_fixture=args.health,
                    scope='Copied arrival save; diagnostic firing placement; normal charged Hammer attacks, '
                          'enemy deaths and autonomous companion combat. Not a walked campaign route.')

    run(args, exercise, setup)


if __name__ == '__main__':
    main()
