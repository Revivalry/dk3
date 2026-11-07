#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-or-later
"""Paired local locomotion evaluation on frozen, physically qualified map cases.

The server moves private controller copies against real map collision. This is
neither a campaign pass nor a complete actor-AI benchmark. No catches, warps,
weapon damage or player input contribute to success. Baseline manifests freeze
the eligible inputs; candidate failures and missing rows remain in the divisor.
"""
import argparse
from concurrent.futures import ThreadPoolExecutor, as_completed
import hashlib
import json
import os
from pathlib import Path
import re
import signal
import shutil
import subprocess
import tempfile
import zipfile

from runtime_probe import send, wait

ROOT = Path(__file__).resolve().parents[2]
CASE = re.compile(r'^dk3 naveval: (case .+)$', re.M)
RESULT = re.compile(r'dk3 naveval: result case=(\d+) controller=(actor|follower) class=(\S+) reached=([01]) hazardous=([01]) distance=([\d.]+) time_ms=(\d+)')
INVENTORY = re.compile(r'dk3 naveval: inventory supported=(\d+) embedded=(\d+) unsupported=(\d+) eligible=(\d+) recoverable=(\d+)')
COMPLETE = re.compile(r'dk3 naveval: complete cases=(\d+)')


def digest(path):
    with Path(path).open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def evaluate(args, name):
    row = dict(map=name, status='failed', results=[])
    with tempfile.TemporaryDirectory(prefix='dk3-naveval-') as temporary:
        home = Path(temporary)
        game = home / 'dk3'
        game.mkdir()
        shutil.copy2(args.modules / 'qagame.so', game / 'qagame.so')
        manifest = None
        if args.baseline:
            manifest = args.baseline / f'{name}.cases'
            if not manifest.exists():
                return dict(row, error='missing baseline manifest')
            shutil.copy2(manifest, game / 'naveval.cfg')
            # The engine deliberately rejects zero-byte files. A newline is
            # an empty token stream, preserving the canonical zero-case input.
            if manifest.stat().st_size == 0:
                (game / 'naveval.cfg').write_text('\n')
        settings = dict(dedicated='1', net_enabled='0', fs_basepath=str(args.assets), fs_homepath=str(home),
                        fs_homedatapath=str(home), fs_homestatepath=str(home / 'state'), com_basegame='dk3',
                        com_pipefile='commands.fifo', vm_game='0', sv_pure='0', g_gametype='2',
                        dk3_runtime_probe='2', g_spSkill=str(args.skill), dk3_cinematics='0',
                        g_residentWorlds='0', dk3_jobs='0', developer='0')
        command = [str(args.guard), '--mem', '8G', '--timeout', f'{args.timeout + 120}s', '--', str(args.engine / 'bin/dk3ded')]
        for key, value in settings.items():
            command += ['+set', key, value]
        command += ['+map', name]
        row['command'] = command
        log = args.report / f'{name}.log'
        with log.open('w') as output:
            process = subprocess.Popen(command, stdout=output, stderr=subprocess.STDOUT, start_new_session=True)
            try:
                pipe = game / 'commands.fifo'
                wait(process, log, lambda text: pipe.exists() and 'isolated bootstrap' in text, 120)
                offset = log.stat().st_size
                send(pipe, 'dk3_runtime_nav_eval' + (' naveval.cfg' if manifest else ''))
                text = wait(process, log, lambda value: COMPLETE.search(value[offset:]) is not None or 'dk3 naveval: failed' in value[offset:], args.timeout)[offset:]
                cases = CASE.findall(text)
                manifest_text = ''.join(case + '\n' for case in cases)
                (args.report / f'{name}.cases').write_text(manifest_text)
                row['cases_sha256'] = hashlib.sha256(manifest_text.encode()).hexdigest()
                inventory = INVENTORY.search(text)
                if inventory:
                    row['inventory'] = dict(zip(('supported', 'embedded', 'unsupported', 'eligible', 'recoverable'), map(int, inventory.groups())))
                row['results'] = [dict(case=int(case), controller=controller, classname=classname,
                                       reached=bool(int(reached)), hazardous=bool(int(hazardous)),
                                       distance=float(distance), time_ms=int(milliseconds))
                                  for case, controller, classname, reached, hazardous, distance, milliseconds in RESULT.findall(text)]
                complete = COMPLETE.search(text)
                if not complete:
                    raise RuntimeError('server probe failed; retain log')
                row['cases'] = int(complete[1])
                if row['cases'] != len(cases) or len(row['results']) != 2 * len(cases):
                    raise RuntimeError('incomplete case results')
                if len({(r['case'], r['controller']) for r in row['results']}) != len(row['results']):
                    raise RuntimeError('duplicate case result')
                if manifest and manifest_text != manifest.read_text():
                    raise RuntimeError('candidate changed frozen inputs')
                row['status'] = 'reported'
                send(pipe, 'quit')
                process.wait(timeout=30)
            except Exception as error:
                row['error'] = str(error)
            finally:
                if process.poll() is None:
                    # This process group belongs to the unique temporary profile.
                    os.killpg(process.pid, signal.SIGTERM)
                    try:
                        process.wait(timeout=15)
                    except subprocess.TimeoutExpired:
                        os.killpg(process.pid, signal.SIGKILL)
                        process.wait(timeout=15)
    return row


def totals(rows):
    result = {}
    for controller in ('actor', 'follower'):
        samples = [value for row in rows for value in row['results'] if value['controller'] == controller]
        result[controller] = dict(cases=len(samples), failed=sum(not r['reached'] for r in samples),
                                  hazardous=sum(r['hazardous'] for r in samples),
                                  success_rate=sum(r['reached'] for r in samples) / len(samples) if samples else None)
    return result


def compare(baseline, rows):
    candidate = {row['map']: row for row in rows}
    result = dict(target_relative_failure_reduction=0.75, controllers={}, valid=True, met=True)
    for controller in ('actor', 'follower'):
        before = after = cases = hazards_before = hazards_after = regressions = 0
        for source in baseline['maps']:
            current = candidate.get(source['map'], {})
            valid = current.get('status') == 'reported' and current.get('cases_sha256') == source.get('cases_sha256')
            result['valid'] &= valid
            values = {(r['case'], r['controller']): r for r in current.get('results', [])} if valid else {}
            expected = {(r['case'], r['controller']) for r in source['results']}
            valid &= set(values) == expected and len(values) == len(current.get('results', []))
            result['valid'] &= valid
            if not valid:
                values = {}
            for original in source['results']:
                if original['controller'] != controller:
                    continue
                cases += 1
                value = values.get((original['case'], controller))
                before += not original['reached']
                after += value is None or not value['reached']
                hazards_before += original['hazardous']
                hazards_after += value is None or value['hazardous']
                regressions += original['reached'] and (value is None or not value['reached'])
        reduction = (before - after) / before if before else None
        met = cases > 0 and ((reduction >= 0.75) if before else after == 0) and hazards_after <= hazards_before and regressions == 0
        result['controllers'][controller] = dict(cases=cases, baseline_failed=before, candidate_failed=after,
                                                relative_failure_reduction=reduction, regressions=regressions,
                                                baseline_hazardous=hazards_before, candidate_hazardous=hazards_after, met=met)
        result['met'] &= met
    result['met'] &= result['valid']
    return result


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--engine', type=Path, default=ROOT / 'zig-out/native-dev')
    parser.add_argument('--modules', type=Path)
    parser.add_argument('--assets', type=Path, default=ROOT / 'zig-out/native-dev/play/current/share')
    parser.add_argument('--guard', type=Path, default=ROOT / 'zig-out/bin/dkguard')
    parser.add_argument('--baseline', type=Path, help='completed baseline report directory; replay its exact cases')
    parser.add_argument('--maps', nargs='+')
    parser.add_argument('--skill', type=int, choices=(1, 3, 5), default=3)
    parser.add_argument('--jobs', type=int, default=2)
    parser.add_argument('--timeout', type=int, default=600)
    parser.add_argument('--report', type=Path, required=True)
    args = parser.parse_args(argv)
    args.engine, args.assets, args.guard, args.report = [p.resolve() for p in (args.engine, args.assets, args.guard, args.report)]
    args.modules = (args.modules or args.engine / 'lib/dk3').resolve()
    if args.report.exists() and any(args.report.iterdir()):
        parser.error('report must be fresh')
    args.report.mkdir(parents=True, exist_ok=True)
    assets = {name: digest(args.assets / 'dk3' / name) for name in ('dk3-maps.pk3', 'dk3-navigation.pk3', 'dk3-data.pk3')}
    protocol = hashlib.sha256(Path(__file__).read_bytes() + (ROOT / 'src/mechanics/server/navigation_eval.zig').read_bytes()).hexdigest()
    inputs = dict(qagame=digest(args.modules / 'qagame.so'), engine=digest(args.engine / 'bin/dk3ded'), assets=assets, skill=args.skill, protocol=protocol)
    baseline = None
    if args.baseline:
        args.baseline = args.baseline.resolve()
        baseline = json.loads((args.baseline / 'evaluation.json').read_text())
        if not baseline['maps'] or any(row['status'] != 'reported' for row in baseline['maps']):
            parser.error('baseline must be complete, with every map reported')
        if any(inputs[key] != baseline['inputs'][key] for key in ('engine', 'assets', 'skill', 'protocol')):
            parser.error('baseline engine, collision/navigation/data assets, skill and evaluation protocol must match')
        expected = [row['map'] for row in baseline['maps']]
        if args.maps and sorted(args.maps) != sorted(expected):
            parser.error('candidate must retain every baseline map')
        args.maps = expected
    if not args.maps:
        with zipfile.ZipFile(args.assets / 'dk3/dk3-maps.pk3') as package:
            args.maps = sorted({Path(name).stem for name in package.namelist() if name.endswith('.bsp') and re.fullmatch(r'e[1-4]m\d+[a-z]?', Path(name).stem)})
    rows = []
    with ThreadPoolExecutor(max_workers=max(1, args.jobs)) as executor:
        pending = {executor.submit(evaluate, args, name): name for name in args.maps}
        for completed in as_completed(pending):
            row = completed.result()
            rows.append(row)
            rows.sort(key=lambda value: value['map'])
            report = dict(inputs=inputs, scope='local controller rollouts; campaign, full AI and visual acceptance excluded', maps=rows, totals=totals(rows))
            if baseline:
                report['comparison'] = compare(baseline, rows)
            (args.report / 'evaluation.json').write_text(json.dumps(report, indent=2) + '\n')
            print(f"{row['map']}: {row['status']} cases={row.get('cases', 0)} {row.get('error', '')}", flush=True)
    return 0 if all(row['status'] == 'reported' for row in rows) and (not baseline or report['comparison']['met']) else 1


if __name__ == '__main__':
    raise SystemExit(main())
