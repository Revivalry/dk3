#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-or-later
"""Decode an assembled walkthrough and retain audio and sampled-frame evidence."""
import argparse
from collections import Counter
from fractions import Fraction
import hashlib
import json
from pathlib import Path
import re
import subprocess


def video_cadence(video, stream):
    packets = subprocess.check_output([
        'ffprobe', '-v', 'error', '-select_streams', 'v:0', '-show_packets',
        '-show_entries', 'packet=pts,duration', '-of', 'csv=p=0', str(video)], text=True)
    rows = [tuple(map(int, line.split(',')[:2])) for line in packets.splitlines() if line]
    points = sorted(row[0] for row in rows)
    step = Fraction(1, 30) / Fraction(stream['time_base'])
    gaps = Counter(last - first for first, last in zip(points, points[1:]))
    durations = Counter(row[1] for row in rows)
    return dict(packets=len(rows), expected_step_ticks=str(step),
        pts_gaps=dict(gaps), packet_durations=dict(durations),
        passed=len(rows) > 1 and step.denominator == 1 and
            set(gaps) == {step.numerator} and set(durations) == {step.numerator})


def verify(video):
    manifest = json.loads(video.with_suffix('.json').read_text())
    output = video.with_name(video.stem + '-validation.json')
    if output.exists():
        raise RuntimeError(f'Validation already exists: {output}')
    info = json.loads(subprocess.check_output([
        'ffprobe', '-v', 'error', '-show_streams', '-show_format', '-show_chapters',
        '-of', 'json', str(video)], text=True))
    visual = next(s for s in info['streams'] if s['codec_type'] == 'video')
    sound = next(s for s in info['streams'] if s['codec_type'] == 'audio')
    assert (visual['width'], visual['height'], visual['r_frame_rate'],
            visual['avg_frame_rate']) == (1280, 720, '30/1', '30/1')
    cadence = video_cadence(video, visual)
    assert cadence['passed'], cadence
    assert sound['sample_rate'] == '48000' and sound['channels'] == 2
    assert len(info.get('chapters', [])) == len(manifest['chapters'])
    for chapter, (start, end, title) in zip(info['chapters'], manifest['chapters']):
        assert chapter['tags']['title'] == title
        assert abs(float(chapter['start_time']) - start) < .05
        assert abs(float(chapter['end_time']) - end) < .05
    checksum = hashlib.file_digest(video.open('rb'), 'sha256').hexdigest()
    assert checksum == manifest['sha256']
    progress = video.with_name(video.stem + '-decode.progress')
    with video.with_name(video.stem + '-decode.log').open('w') as log:
        subprocess.run([
            'ffmpeg', '-hide_banner', '-loglevel', 'error', '-xerror', '-i', str(video),
            '-map', '0:v:0', '-map', '0:a:0', '-fps_mode', 'passthrough',
            '-progress', str(progress), '-nostats', '-f', 'null', '-'],
            stdout=log, stderr=subprocess.STDOUT, check=True)
    frames = [int(n) for n in re.findall(r'^frame=(\d+)$', progress.read_text(), re.M)]
    assert frames and frames[-1] == int(visual['nb_frames'])
    audio = subprocess.run([
        'ffmpeg', '-hide_banner', '-i', str(video), '-vn', '-af', 'volumedetect',
        '-f', 'null', '-'], capture_output=True, text=True, check=True)
    video.with_name(video.stem + '-audio.log').write_text(audio.stderr)
    peak = re.search(r'max_volume: (-?[\d.]+) dB', audio.stderr)
    assert peak and float(peak[1]) > -60, 'Missing audible game sound'
    shots = video.with_name(video.stem + '-frames')
    shots.mkdir(exist_ok=True)
    duration = float(info['format']['duration'])
    stamps = [duration * (i + 0.5) / 12 for i in range(12)]
    stamps[0], stamps[-1] = 1.0, max(0, duration - 1)
    for i, stamp in enumerate(stamps):
        subprocess.run([
            'ffmpeg', '-hide_banner', '-loglevel', 'error', '-y', '-ss', str(stamp),
            '-i', str(video), '-map', '0:v:0', '-frames:v', '1', '-vf', 'scale=320:180',
            str(shots / f'frame-{i:02d}.jpg')], check=True)
    contact = video.with_name(video.stem + '-contact.jpg')
    subprocess.run([
        'ffmpeg', '-hide_banner', '-loglevel', 'error', '-y', '-framerate', '1',
        '-i', str(shots / 'frame-%02d.jpg'), '-vf', 'tile=3x4', '-frames:v', '1',
        str(contact)], check=True)
    result = dict(path=str(video), bytes=video.stat().st_size, sha256=checksum,
        duration_seconds=duration, decoded_video_frames=frames[-1], video=visual,
        audio=sound, peak_volume_db=float(peak[1]), chapters=len(info['chapters']),
        cadence=cadence,
        full_decode_exit=0, contact_sheet=str(contact), sample_seconds=stamps,
        visual_review='pending; inspect the contact sheet separately')
    output.write_text(json.dumps(result, indent=2) + '\n')
    print(f'Media passed: {duration:.1f}s, {frames[-1]} frames; visual review pending', flush=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('video', type=Path)
    verify(parser.parse_args().video)
