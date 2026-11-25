#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-or-later
"""Assemble completed bot-demo exports with explicit checkpoint chapter cards.

The JSON specification names output, title, and parts (report + label). Failed
attempts keep their recorded outcome. This produces a walkthrough, not evidence
of a fresh uninterrupted episode pass.
"""
import argparse
import json
from pathlib import Path
import subprocess
import textwrap
import time

from runtime_coop_bot import digest
from verify_coop_video import video_cadence


def probe(path):
    return json.loads(subprocess.check_output(['ffprobe', '-v', 'error', '-show_streams',
        '-show_format', '-of', 'json', str(path)], text=True))


def metadata_value(value):
    return ''.join('\\' + character if character in '\\=;#\n' else character
                   for character in value)


def run(specification):
    spec = json.loads(specification.read_text())
    target = Path(spec['output']).resolve()
    target.parent.mkdir(parents=True, exist_ok=True)
    if target.exists():
        raise RuntimeError(f'Output already exists: {target}')
    work = target.parent / (target.stem + '-assembly')
    work.mkdir(exist_ok=True)
    paths, frames, chapters, evidence = [], [], [], []
    elapsed = 0.0
    font = subprocess.check_output(['fc-match', '-f', '%{file}', 'DejaVuSans'], text=True)
    for number, part in enumerate(spec['parts']):
        report = Path(part['report']).resolve()
        result = json.loads((report / 'result.json').read_text())
        indices = part.get('clips', list(range(len(result['demos']))))
        if not indices or len(set(indices)) != len(indices) or any(i < 0 or i >= len(result['demos']) for i in indices):
            raise RuntimeError('Invalid source demo selection')
        clips = [report / 'clips' / f'{i:03d}.mp4' for i in indices]
        for i, clip in zip(indices, clips):
            if not clip.exists() or 'dk3-video-complete' not in (report / f'render-{i:03d}.log').read_text(errors='replace'):
                raise RuntimeError(f'Demo export has not completed: {clip}')
            # Older already-running exporters publish their concatenation
            # directly. Wait for its final metadata relocation to settle.
            while time.time() - clip.stat().st_mtime < 3:
                time.sleep(0.25)
        label = part['label']
        title = work / f'{number:02d}-title.txt'
        title.write_text(spec['title'] + '\n\n' + '\n'.join(textwrap.wrap(label, 58)) +
                         '\n\nRecorded checkpoint continuation' * (number > 0) + '\n')
        card = work / f'{number:02d}-title.mp4'
        if not card.exists():
            subprocess.run(['ffmpeg', '-hide_banner', '-loglevel', 'error', '-y',
                '-f', 'lavfi', '-i', 'color=c=black:s=1280x720:r=30:d=3',
                '-f', 'lavfi', '-i', 'anullsrc=r=48000:cl=stereo',
                '-vf', f'drawtext=fontfile={font}:textfile={title}:expansion=none:fontcolor=white:fontsize=30:x=(w-tw)/2:y=(h-th)/2',
                '-t', '3', '-c:v', 'libx264', '-preset', 'fast', '-crf', '21', '-pix_fmt', 'yuv420p',
                '-c:a', 'aac', '-b:a', '160k', str(card)], check=True)
        start = elapsed
        paths.append(card)
        frames.append(round(float(probe(card)['format']['duration']) * 30))
        elapsed += frames[-1] / 30
        clip_evidence = []
        for i, clip in zip(indices, clips):
            info = probe(clip)
            video = next(s for s in info['streams'] if s['codec_type'] == 'video')
            source_size = [video['width'], video['height']]
            paths.append(clip)
            frames.append(round(float(info['format']['duration']) * 30))
            elapsed += frames[-1] / 30
            motion = report / f'motion-{i:03d}.json'
            render_inputs = report / f'render-{i:03d}.inputs.json'
            clip_evidence.append(dict(path=str(clip), sha256=digest(clip), source_size=source_size,
                render_log_sha256=digest(report / f'render-{i:03d}.log'),
                render_inputs_sha256=digest(render_inputs) if render_inputs.exists() else None,
                motion_evaluation_sha256=digest(motion) if motion.exists() else None))
        chapters.append((start, elapsed, label))
        evidence.append(dict(report=str(report), result_sha256=digest(report / 'result.json'),
            render_inputs_sha256=digest(report / 'render-inputs.json') if (report / 'render-inputs.json').exists() else None,
            inputs_sha256=digest(report / 'inputs.json'), demos=result['demos'],
            outcome=result['outcome'], maps=result['maps'], deaths=len(result['deaths']),
            actions_started=result['actions_started'], actions_done=result['actions_done'],
            failed_actions=len(result['failures']), included_demo_indices=indices, clips=clip_evidence,
            observed_failure=json.loads((report / 'observed-failure.json').read_text())
                if (report / 'observed-failure.json').exists() else None,
            observed_failure_sha256=digest(report / 'observed-failure.json')
                if (report / 'observed-failure.json').exists() else None))
    metadata = work / 'chapters.txt'
    metadata.write_text(';FFMETADATA1\ntitle=' + metadata_value(spec['title']) + '\n' + ''.join(
        f'[CHAPTER]\nTIMEBASE=1/1000\nSTART={round(start*1000)}\nEND={round(end*1000)}\ntitle={metadata_value(label)}\n'
        for start, end, label in chapters))
    partial = work / 'assembled.mp4'
    # Decode each source with its own H.264 headers. A stream copy of nested
    # clip concatenations can corrupt packets when encoder headers differ.
    inputs, filters, segments = [], [], []
    for index, (path, count) in enumerate(zip(paths, frames)):
        inputs += ['-threads', '2', '-i', str(path)]
        filters += [
            f'[{index}:v]scale=1280:720:force_original_aspect_ratio=decrease,'
            'pad=1280:720:(ow-iw)/2:(oh-ih)/2,setsar=1,fps=30:start_time=0,'
            f'tpad=stop_mode=clone:stop_duration=1,trim=end_frame={count},setpts=PTS-STARTPTS[v{index}]',
            f'[{index}:a]aresample=48000:async=1:first_pts=0,aformat=channel_layouts=stereo,'
            f'apad,atrim=end_sample={count * 1600},asetpts=PTS-STARTPTS[a{index}]',
        ]
        segments.append(f'[v{index}][a{index}]')
    filters.append(''.join(segments) + f'concat=n={len(paths)}:v=1:a=1[joined][sound]')
    filters.append('[joined]fps=30:start_time=0,settb=1/30,setpts=N[video]')
    filters.append('[sound]asettb=1/48000,asetpts=N[audio]')
    subprocess.run(['ffmpeg', '-hide_banner', '-loglevel', 'error', '-xerror', '-y', *inputs,
        '-i', str(metadata), '-filter_complex_threads', '2', '-filter_complex', ';'.join(filters),
        '-map', '[video]', '-map', '[audio]', '-map_metadata', str(len(paths)),
        '-map_chapters', str(len(paths)), '-r', '30', '-fps_mode', 'cfr', '-enc_time_base:v', '1/30',
        '-c:v', 'libx264', '-threads', '6', '-preset', 'fast', '-crf', '21', '-pix_fmt', 'yuv420p',
        '-c:a', 'aac', '-b:a', '160k', '-movflags', '+faststart', str(partial)], check=True)
    info = probe(partial)
    video = next(s for s in info['streams'] if s['codec_type'] == 'video')
    cadence = video_cadence(partial, video)
    assert (video['width'], video['height'], video['r_frame_rate'], video['avg_frame_rate']) == (1280, 720, '30/1', '30/1')
    assert cadence['passed'], cadence
    assert int(video['nb_frames']) == sum(frames), (video['nb_frames'], sum(frames))
    assert any(s['codec_type'] == 'audio' for s in info['streams'])
    assert abs(float(info['format']['duration']) - elapsed) < 1, (info['format']['duration'], elapsed)
    partial.rename(target)
    info['format']['filename'] = str(target)
    target.with_suffix('.json').write_text(json.dumps(dict(title=spec['title'],
        scope='Recorded bot walkthrough assembled from labelled attempts and ordinary checkpoint continuations; not a fresh uninterrupted pass.',
        sha256=digest(target), duration_seconds=float(info['format']['duration']),
        chapters=chapters, sources=evidence, media=info,
        normalized_timestamps=True, cadence=cadence), indent=2) + '\n')
    print(target, flush=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('specification', type=Path)
    run(parser.parse_args().specification)
