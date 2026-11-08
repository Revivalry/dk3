#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-or-later
"""Compare rendered locomotion to unsmoothed poses from the same snapshots.

This measures presentation, not navigation success. Only continuous, grounded,
moving frames count; map/load/teleport cuts and cinematics are excluded.
"""
import argparse
import json
import math
from pathlib import Path


def rows(path, marker, cut_markers=()):
    result = []
    segment = 0
    for line in path.read_text(errors='replace').splitlines():
        if any(cut in line for cut in cut_markers):
            segment += 1
        if marker not in line:
            continue
        row = {}
        for field in line.split(marker, 1)[1].split():
            key, value = field.split('=', 1)
            row[key] = tuple(map(float, value.split(','))) if ',' in value else float(value)
        row['_segment'] = segment
        result.append(row)
    return result


def distance(first, last):
    return math.hypot(last[0] - first[0], last[1] - first[1])


def percentile(values, fraction):
    return sorted(values)[min(len(values) - 1, int((len(values) - 1) * fraction))] if values else None


def evaluate(record_log, render_log):
    frames = rows(render_log, 'dk3 replay pose: ')
    raw, smooth, within_snapshot, snapshot_gaps = [], [], [], []
    cuts = 0
    for first, last in zip(frames, frames[1:]):
        dt = (last['now'] - first['now']) / 1000
        if not 0 < dt <= 0.1 or any(first[k] != last[k] for k in ('world', 'spawn', 'teleport')):
            cuts += 1
            continue
        if first['ground'] != 2046 or last['ground'] != 2046:
            continue
        if min(math.hypot(*first['velocity']), math.hypot(*last['velocity'])) < 40:
            continue
        if distance(first['source'], last['source']) > 64:
            cuts += 1
            continue
        raw.append(distance(first['source'], last['source']) / dt)
        smooth.append(distance(first['pos'], last['pos']) / dt)
        if last['snapshot'] > first['snapshot']:
            snapshot_gaps.append(last['snapshot'] - first['snapshot'])
        if first['snapshot'] == last['snapshot']:
            within_snapshot.append(distance(first['pos'], last['pos']))
    # Restoring a checkpoint or entering an authored landing can rotate the
    # player without a large XY displacement. The adjacent issued commands
    # belong to different authoritative poses, just as world/respawn cuts do
    # in the rendered-frame comparison. Retain and count these explicit cuts.
    commands = rows(record_log, 'dk3 coop motion: ', (
        'dk3 zig client: restoration applied',
        'dk3 world transfer:', 'dk3 coop: event=admitted'))
    turns = []
    command_cuts = 0
    for first, last in zip(commands, commands[1:]):
        if first['_segment'] != last['_segment']:
            command_cuts += 1
            continue
        dt = (last['now'] - first['now']) / 1000
        if not 0 < dt <= 0.1 or distance(first['pos'], last['pos']) > 64:
            continue
        yaw = abs((last['angles'][1] - first['angles'][1] + 180) % 360 - 180)
        turns.append(yaw / dt)
    frozen = lambda values: sum(value < 0.01 for value in values) / len(values) if values else None
    result = dict(scope='Paired presentation comparison on identical captured snapshots; no navigation acceptance claim.',
        render_log=str(render_log), record_log=str(record_log), rendered_frames=len(frames),
        continuous_grounded_moving_pairs=len(raw), excluded_cuts=cuts,
        raw_frozen_fraction=frozen(raw), interpolated_frozen_fraction=frozen(smooth),
        raw_speed_p95=percentile(raw, .95), interpolated_speed_p95=percentile(smooth, .95),
        within_snapshot_moving_frames=sum(value > .01 for value in within_snapshot),
        moving_snapshot_gap_median_ms=percentile(snapshot_gaps, .5),
        moving_snapshot_gap_p95_ms=percentile(snapshot_gaps, .95),
        command_turn_samples=len(turns), command_explicit_cuts=command_cuts,
        command_yaw_rate_max=max(turns) if turns else None)
    result['passed'] = (len(raw) >= 50 and len(turns) >= 50 and
        result['within_snapshot_moving_frames'] >= 10 and
        result['interpolated_frozen_fraction'] < result['raw_frozen_fraction'] and
        result['interpolated_speed_p95'] < result['raw_speed_p95'] and
        result['command_yaw_rate_max'] <= 361 and
        result['moving_snapshot_gap_median_ms'] <= 50 and
        result['moving_snapshot_gap_p95_ms'] <= 100)
    result['criteria'] = 'Movement gate v2: interpolation, bounded issued turns and median 50 ms / p95 at most 100 ms moving snapshot cadence.'
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('report', type=Path)
    parser.add_argument('--clip', type=int, default=0)
    args = parser.parse_args()
    result = evaluate(args.report / 'record.log', args.report / f'render-{args.clip:03d}.log')
    output = args.report / f'motion-{args.clip:03d}.json'
    output.write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps(result, indent=2))
    if not result['passed']:
        raise SystemExit('Movement evaluation failed; inspect retained frames and poses.')


if __name__ == '__main__':
    main()
