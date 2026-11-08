#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-or-later
"""Guarded admission and party retaliation fixtures; no campaign-pass claims."""
import argparse
import math
from pathlib import Path
import re
import shutil
import time

from runtime_bugfix_probe import run
from runtime_opening_route import actors
from runtime_physics_repair_probe import attributes


def inventory(driver):
    text = driver.diagnostics('dk3_runtime_inventory', 'zig inventory ')
    found = re.search(r'owned=([0-9a-f]+) weapon=(\d+)', text)
    assert found, text
    return dict(owned=int(found[1], 16), weapon=int(found[2]))


def greece(driver, report, capture):
    state = driver.until(lambda s: s['mode'] == 'normal' and s['map'] == 'e2m1a')
    before = inventory(driver)
    assert before == dict(owned=1 << 8, weapon=8), before
    capture('greece-daikatana-only')
    saved = driver.save('greece_admission')
    shutil.copy2(saved, report / saved.name)
    driver.load('greece_admission')
    after = inventory(driver)
    assert after == before, (before, after)
    return dict(initial=state, inventory=before, restored=after,
                scope='Fresh Greece admission and save restoration; authored Episode 1 handoff is a separate scenario.')


def retaliation(driver, report, capture):
    driver.until(lambda s: s['mode'] == 'normal')
    initial = driver.observe()
    fixtures = []
    for classname in ('mikiko', 'superfly'):
        found = None
        for dx, dy in ((72, 0), (0, 72), (-72, 0), (0, -72), (96, 96), (-96, -96)):
            x, y, z = initial['pos']
            text = driver.diagnostics(f'dk3_runtime_actor_spawn {classname} {x+dx} {y+dy} {z+16} 180 e2m1a 1 ground', 'dk3 actor ')
            found = re.search(r'fixture: id=(\d+).*hull-clear=1.*grounded=1', text)
            if found:
                fixtures.append(int(found[1]))
                break
        assert found, f'No clear grounded fixture for {classname}'
    driver.elapsed(200)
    party = {identity: row for identity, row in actors(driver).items()
             if row['class'] in ('mikiko', 'superfly') and row['health'] > 0}
    assert len(party) == 2, party
    # Preserve both members through the explicit twenty-contact provocation.
    # The subsequent retaliation uses ordinary movement and physical attacks.
    for identity in party:
        driver.diagnostics(f'dk3_runtime_probe_health 10000 {identity}', f'id={identity} health=10000')
    owner = driver.observe()
    assert owner['health'] > 5, owner
    target = next(iter(party))
    for _ in range(20):
        driver.diagnostics(f'dk3_runtime_hurt {target} 1', 'dk3 probe hurt:')
        driver.elapsed(100)
    provoked = actors(driver)
    samples = []
    try:
        driver.until(lambda s: samples.append(dict(now=s['now'], health=s['health'], source=s['source']))
                     or s['health'] <= 5, seconds=40, description='physical party retaliation reaches mercy floor')
    finally:
        actors(driver)
    end = driver.observe()
    assert end['health'] == 5 and end['source'] in party, (end, party)
    capture('party-rebuke-at-five-health')
    driver.elapsed(5500)
    quiet = driver.observe()
    assert quiet['health'] == 5 and quiet['mode'] == 'normal', quiet
    saved = driver.save('forgiven')
    shutil.copy2(saved, report / saved.name)
    driver.load('forgiven')
    driver.elapsed(1000)
    assert driver.observe()['health'] == 5
    return dict(party=party, provoked=provoked, fixtures=fixtures, contacts=20, samples=samples, end=end, quiet=quiet,
                scope='Explicit grounded party fixtures and diagnostic owner contacts, then ordinary party pursuit/attacks, nonlethal stop and save restoration. Hidden cooldown policy has separate pure coverage.')


def shield(driver, report, capture):
    driver.until(lambda s: s['mode'] == 'normal')
    driver.aim(0, 0)
    text = driver.diagnostics('dk3_runtime_spawn_item item_megashield', 'dk3 fixture item:')
    identity = int(re.search(r'id=(\d+)', text)[1])
    capture('megashield-first')
    driver.elapsed(900)
    capture('megashield-rotated')
    text = driver.diagnostics('dk3_runtime_projections item_megashield', 'dk3 projection: complete')
    row = next(line for line in text.splitlines() if f'id={identity} ' in line)
    assert 'spin=100.0' in row, row
    return dict(identity=identity, projection=row,
                scope='Native angular trajectory and two rendered views; visual inspection required.')


def boosts(driver, report, capture):
    driver.until(lambda s: s['mode'] == 'normal' and s['ground'] != 2047)
    driver.issue('developer 2')
    origin = driver.stop_forward(settle_vertical=True)['pos']

    def reset():
        driver.issue('dk3_runtime_place ' + ' '.join(map(str, origin)))
        driver.until(lambda s: s['ground'] != 2047)

    def jump():
        reset()
        start = driver.observe()
        driver.issue('+moveup')
        samples, airborne, released = [], False, False
        deadline = time.monotonic() + 6
        try:
            while time.monotonic() < deadline:
                state = driver.observe()
                samples.append(state)
                airborne |= state['ground'] == 2047
                if not released and state['now'] > start['now'] + 120:
                    driver.issue('-moveup')
                    released = True
                if airborne and state['ground'] != 2047 and state['now'] > start['now'] + 300:
                    break
            else:
                raise TimeoutError('Jump did not leave and return to the floor')
        finally:
            driver.issue('-moveup')
        return dict(height=max(s['pos'][2] for s in samples) - start['pos'][2], samples=samples)

    def pickup(name, index):
        reset()
        driver.aim(-90, 0)
        driver.diagnostics(f'dk3_runtime_spawn_item item_{name}_boost', 'dk3 fixture item:')
        driver.issue('+forward')
        deadline = time.monotonic() + 5
        try:
            while time.monotonic() < deadline:
                state = attributes(driver.diagnostics('dk3_runtime_character', 'zig character time='), 'zig character attributes ')
                if state['effective'][index] == 5:
                    return state
            raise TimeoutError(f'Ordinary {name} pickup contact failed')
        finally:
            driver.stop_forward()

    normal = jump()
    acro = pickup('acro', 3)
    boosted = jump()
    assert boosted['height'] > normal['height'] * 2, (normal, boosted)
    power = pickup('power', 0)
    driver.ready(8)
    driver.fire()
    driver.elapsed(300)
    text = driver.text()
    for sound in ('global/acroboost.wav', 'global/a_powerquad.wav'):
        assert f'dk3 sound event: name={sound} ' in text, f'No client dispatch for {sound}'
    capture('boosts-after-real-actions')
    return dict(normal_jump=normal, boosted_jump=boosted, acro=acro, power=power,
                scope='Diagnostic boost spawns acquired by ordinary contact, normal jump/attack inputs, measured rise and actual client sound dispatch. Audio mix listening remains separate.')


def doors(driver, report, capture):
    driver.until(lambda s: s['mode'] == 'normal' and s['map'] == 'e2m1b')
    driver.issue('dk3_runtime_pacify_monsters')
    initial = driver.save('closed_doors')
    shutil.copy2(initial, report / initial.name)

    def leaves():
        text = driver.diagnostics('dk3_runtime_movers', 'zig mover id=51 ')
        found = {}
        for line in text.splitlines():
            row = dict(re.findall(r'(\w+)=([^ ]*)', line))
            if row.get('id') in ('50', '51'):
                for key in ('pos', 'end', 'angles'):
                    row[key] = tuple(map(float, row[key].split(',')))
                found[int(row['id'])] = row
        assert len(found) == 2, text
        return found

    observations = []
    for side in (1, -1):
        if side == -1:
            driver.load('closed_doors')
        driver.issue(f'dk3_runtime_place {24 + side*72} -3104 704')
        driver.until(lambda s: abs(s['pos'][0] - (24 + side*72)) < 2 and s['ground'] != 2047)
        driver.aim(180 if side == 1 else 0, 0)
        before = leaves()
        driver.issue('use')
        driver.elapsed(1300)
        opened = leaves()
        for identity, offset in ((50, 32), (51, -32)):
            row = opened[identity]
            assert row['state'] == 'open', opened
            assert abs(abs(row['angles'][1]) - 90) < 1, row
            # The centre's X motion is -sin(yaw)*local-Y. Both leaves
            # must move away from the activator's side of the doorway.
            displacement = -math.sin(math.radians(row['angles'][1])) * offset
            assert displacement * side < 0, (side, identity, opened)
        capture(f'double-door-open-side-{side}')
        observations.append(dict(side=side, before=before, opened=opened))

    driver.load('closed_doors')
    driver.issue('dk3_runtime_place 96 -3104 704')
    driver.until(lambda s: abs(s['pos'][0] - 96) < 2 and s['ground'] != 2047)
    driver.aim(180, 0)
    driver.issue('use')
    driver.elapsed(1300)
    text = driver.diagnostics('dk3_runtime_actor_spawn monster_centurion 0 -3056 720 0 e2m1b 1 ground', 'dk3 actor ')
    spawned = re.search(r'id=(\d+).*hull-clear=1.*grounded=1', text)
    assert spawned, text
    enemy_id = int(spawned[1])
    driver.issue('dk3_runtime_pacify_monsters')
    enemy_start = actors(driver)[enemy_id]
    driver.issue('dk3_runtime_place 0 -3104 704')
    start = driver.until(lambda s: abs(s['pos'][0]) < 2 and s['ground'] != 2047)
    samples = []
    deadline = time.monotonic() + 8
    while time.monotonic() < deadline:
        state = driver.observe()
        samples.append(state)
        assert state['health'] == start['health'], (start, state)
        if state['now'] > start['now'] + 5500:
            break
    assert max(math.dist(s['pos'], start['pos']) for s in samples) > 2, 'Closing door did not physically push fixture'
    enemy_end = actors(driver)[enemy_id]
    assert enemy_end['health'] == enemy_start['health'], (enemy_start, enemy_end)
    assert math.dist(enemy_start['pos'], enemy_end['pos']) > 2, 'Closing door did not physically push the enemy fixture'
    capture('closing-door-push-without-damage')
    return dict(sides=observations, push_start=start, push_samples=samples, enemy_start=enemy_start, enemy_end=enemy_end,
                scope='Explicit authored doorway/grounded enemy placements, ordinary use from both sides, real rotating brush motion and closing-door player/enemy pushes with unchanged health. Other door types remain separate.')


def passing(driver, report, capture):
    driver.until(lambda s: s['mode'] == 'normal' and s['map'] == 'e2m4d')
    driver.issue('dk3_runtime_pacify_monsters')
    driver.issue('dk3_runtime_place -2048 612 -880')
    start = driver.until(lambda s: abs(s['pos'][0] + 2048) < 2 and s['ground'] != 2047)
    text = driver.diagnostics('dk3_runtime_actor_spawn mikiko -2079 612 -856 0 e2m4d 1 ground', 'dk3 actor ')
    spawned = re.search(r'fixture: id=(\d+).*hull-clear=1.*grounded=1', text)
    assert spawned, text
    identity = int(spawned[1])
    before = actors(driver)[identity]
    begin = len(driver.text())
    driver.aim(180, 0)
    samples = []
    driver.issue('+forward')
    try:
        end = driver.until(lambda s: samples.append(s) or s['pos'][0] < -2110,
                           seconds=12, description='ordinary walking passes the companion on the narrow stairs')
    finally:
        driver.issue('-forward')
    after = actors(driver)[identity]
    assert after['pos'][0] < before['pos'][0] - 32, (before, after)
    assert 'dk3 sidekick: catch-up who=' not in driver.text()[begin:], 'Passing used a catch-up warp'
    capture('companion-yields-up-stairs')
    return dict(initial=start, final=end, companion_before=before, companion_after=after, samples=samples,
                scope='Explicit grounded fixtures at the recorded Aegis stair obstruction; ordinary movement and companion yielding, without catch-up teleportation. Separate from campaign acceptance.')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--engine', type=Path, required=True)
    parser.add_argument('--report', type=Path, required=True)
    parser.add_argument('--scenario', choices=('greece', 'retaliation', 'shield', 'boosts', 'doors', 'passing'), required=True)
    parser.add_argument('--renderer', default='opengl2')
    args = parser.parse_args()
    args.engine, args.report = args.engine.resolve(), args.report.resolve()
    args.start_map = dict(doors='e2m1b', passing='e2m4d').get(args.scenario, 'e2m1a')
    args.developer = True
    run(args, dict(greece=greece, retaliation=retaliation, shield=shield, boosts=boosts, doors=doors, passing=passing)[args.scenario])
