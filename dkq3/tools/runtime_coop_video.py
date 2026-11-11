#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-or-later
"""Record a visible campaign pilot as demos, then render them to 720p MP4.

Every engine invocation uses dkguard and a private X display/profile. Demo
capture retains authoritative gameplay at its original simulation rate; AVI
playback mixes game audio and renders at 30 fps independently of machine speed.
"""
import argparse
import fcntl
import json
import os
from pathlib import Path
import re
import shutil
import signal
import subprocess
import time

from runtime_coop_bot import digest, parse_event, summarise
from runtime_probe import client_settings, send, stage_client_modules

ROOT = Path(__file__).resolve().parents[2]


def launch(args, home, values, commands, log):
    pid_file = home / 'state/dk3/dk3.pid'
    if pid_file.exists():
        try:
            pid = int(pid_file.read_text())
            os.kill(pid, 0)
        except (ValueError, ProcessLookupError):
            # A crashed private capture must not open a recovery dialog on
            # its invisible X display. Preserve logs, clear only its stale PID.
            pid_file.unlink()
    # ioquake3 accepts only 32 command-line console lines. Load the full
    # configuration before renderer initialization, with only profile paths
    # on the command line, so +map/+demo cannot silently disappear.
    (home / 'dk3/autoexec.cfg').write_text(''.join(
        f'set {key} "{value}"\n' for key, value in values.items()))
    if args.mode == 'record' and args.software_record:
        command = [str(args.guard), '--headless', '--screen', '320x180', '--mem', '16G',
                   '--timeout', f'{args.timeout}s', '--', str(args.engine / 'bin/dk3')]
    elif args.software_render:
        command = [str(args.guard), '--headless', '--screen', '1280x720', '--mem', '16G',
                   '--timeout', f'{args.timeout}s', '--', str(args.replay_client or args.engine / 'bin/dk3')]
    else:
        command = [str(args.guard), '--gpu', '--mem', '16G', '--timeout', f'{args.timeout}s', '--',
                   'xvfb-run', '-a', '-s', '-screen 0 1280x720x24', 'env',
                   'SDL_AUDIODRIVER=dummy', str(args.replay_client or args.engine / 'bin/dk3')]
    for key in ('fs_basepath', 'fs_homepath', 'fs_homedatapath', 'fs_homestatepath', 'com_basegame',
                'com_hunkMegs', 'com_zoneMegs'):
        value = values[key]
        command += ['+set', key, str(value)]
    command += commands
    with log.with_suffix('.launch.json').open('w') as stream:
        json.dump(command, stream, indent=2)
    output = log.open('w')
    process = subprocess.Popen(command, stdout=output, stderr=subprocess.STDOUT)
    output.close()
    return process


def base(args, home):
    values = client_settings(args.engine, home, renderer='vulkan')
    values.update(r_customwidth='1280', r_customheight='720', r_swapInterval='0',
                  com_hunkMegs='1024', com_zoneMegs='128',
                  com_maxfps='0', com_maxfpsUnfocused='0', com_maxfpsMinimized='0',
                  s_useOpenAL='0', s_sdlSpeed='48000',
                  con_notifytime='0', cl_noprint='1',
                  dk3_resume='0', dk3_travel_pending='0', dk3_cinematics='1',
                  dk3_coop_render='1', dk3_coop_capture_no_refresh='0', g_residentWorlds='1')
    if args.motion_trace:
        values.update(cg_debugReplay='1', dk3_coop_motion_trace='1')
    return values


def quit_private(home, process):
    if process.poll() is None:
        try:
            send(home / 'dk3/commands.fifo', 'stoprecord; stopvideo; quit')
            process.wait(timeout=20)
        except (OSError, subprocess.TimeoutExpired):
            process.terminate()  # dkguard cleans its owned process group.
            process.wait(timeout=20)


def record(args):
    if args.report.exists() and any(args.report.iterdir()):
        raise RuntimeError('Recording report must be fresh')
    args.report.mkdir(parents=True, exist_ok=True)
    home = (args.report / 'profile').resolve()
    stage_client_modules(args.engine, home, installation=args.engine)
    shutil.copytree(ROOT / 'dkq3/coop', home / 'dk3/coop')
    if args.load:
        route = home / 'dk3/coop' / args.script
        assert route.is_file()
        with route.open('a') as stream:
            stream.write('\n-- Admit this copied healthy checkpoint for ordinary death recovery.\nsettings {resume_saves = true}\n')
    values = base(args, home)
    values.update(g_spSkill='1', dk3_coop_script=f'coop/{args.script}', dk3_coop_skill='10',
                  dk3_coop_quit='1', dk3_coop_status_ms='1000', cl_autoRecordDemo='1',
                  dk3_coop_fast='1', dk3_coop_fast_frame_ms='16', fixedtime='16', timedemo='1',
                  sv_fps='20', snaps='20', rate='90000', sv_minRate='10000000')
    if args.software_record:
        # Capture needs the real client's admission/command processing, not
        # live rasterization. The demo is later rendered normally on the GPU.
        values.update(dk3_coop_capture_no_refresh='1', cl_renderer='opengl2', r_customwidth='320', r_customheight='180',
                      r_norefresh='1', r_picmip='3')
    if args.load:
        saves = home / 'state/dk3/saves'
        saves.mkdir(parents=True)
        shutil.copy2(args.load, saves / 'coop-resume.sav')
        values['dk3_coop_load'] = 'coop-resume'
        if args.stage:
            values.update(dk3_coop_level=args.map, dk3_coop_checkpoint=f'{args.map} {args.stage}',
                          dk3_coop_resume_checkpoint=f'{args.map} {args.stage}')
    identity = {str(path.relative_to(home)): digest(path) for path in
                sorted((home / 'dk3').rglob('*')) if path.is_file()}
    identity['bin/dk3'] = digest(args.engine / 'bin/dk3')
    (args.report / 'inputs.json').write_text(json.dumps(dict(settings=values, identity=identity,
        continuation=dict(save=str(args.load), sha256=digest(args.load), stage=args.stage,
                          admit_resume_checkpoint=True) if args.load else None), indent=2) + '\n')
    log = args.report / 'record.log'
    started = time.monotonic()
    process = launch(args, home, values, ['+map', args.map], log)
    offset, events, stopped, engine_error = 0, [], None, None
    try:
        while process.poll() is None:
            text = log.read_text(errors='replace')
            complete, _, _ = text[offset:].rpartition('\n')
            offset += len(complete) + (1 if complete else 0)
            for line in complete.splitlines():
                if line.startswith('ERROR:'):
                    engine_error = line
                    break
                event = parse_event(line)
                if event:
                    events.append(event)
                    if event.get('event') in ('level', 'death', 'finish', 'fail'):
                        print(line, flush=True)
                    if event.get('event') in ('finish', 'fail'):
                        stopped = 'finished' if event['event'] == 'finish' else 'failed'
                    if args.until_map and event.get('event') == 'level' and f'map={args.until_map} ' in event.get('detail', '') + ' ':
                        stopped = 'episode boundary'
                    if args.seconds and int(event.get('t', '0')) >= args.seconds * 1000:
                        stopped = 'sample'
            if stopped or engine_error:
                break
            time.sleep(0.25)
    finally:
        quit_private(home, process)
    events = [e for e in map(parse_event, log.read_text(errors='replace').splitlines()) if e]
    result = summarise(events, wall_seconds=time.monotonic() - started, exit_code=process.returncode)
    if stopped:
        result['outcome'] = stopped
    if engine_error:
        result.update(outcome='failed', engine_error=engine_error)
    demos = sorted((home / 'dk3/demos').glob('*.dm_*'), key=lambda p: (p.stat().st_mtime_ns, p.name))
    result['demos'] = [dict(path=str(p.relative_to(args.report.resolve())), bytes=p.stat().st_size,
                            sha256=digest(p)) for p in demos]
    (args.report / 'result.json').write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps(result, indent=2), flush=True)
    if result['outcome'] not in ('finished', 'episode boundary', 'sample') or not demos:
        raise RuntimeError('Recorded run did not complete its requested scope')


def render(args):
    # Independent episodes may render in parallel, but a report owns one
    # playback profile, capture directory and set of output clip paths.
    with (args.report / '.render.lock').open('a') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        render_locked(args)


def render_locked(args):
    result = json.loads((args.report / 'result.json').read_text())
    if (result['outcome'] not in ('finished', 'episode boundary', 'sample') and not args.include_failed) or not result['demos']:
        raise RuntimeError('Refusing to label an incomplete run as a playthrough')
    indices = args.clips if args.clips is not None else list(range(len(result['demos'])))
    if not indices or len(set(indices)) != len(indices) or any(i < 0 or i >= len(result['demos']) for i in indices):
        raise RuntimeError('Invalid original demo selection')
    home = (args.report / 'playback').resolve()
    if not home.exists():
        stage_client_modules(args.engine, home, installation=args.engine)
        (home / 'dk3/demos').mkdir()
    if args.update_presentation:
        # Presentation folders are excluded from the rules identity. Admit only
        # a reviewed cgame update while the recorded server/UI remain identical.
        installation = args.engine / 'share/dk3'
        for name in ('qagame', 'ui'):
            expected = digest(installation / f'{name}.so')
            if expected != digest(args.report / f'profile/dk3/{name}.so') or expected != digest(home / f'dk3/{name}.so'):
                raise RuntimeError('Presentation update changed recorded game/UI modules')
        candidate = installation / 'cgame.so'
        manifest = json.loads((args.engine / 'installation.json').read_text())['files']
        if digest(candidate) != manifest['share/dk3/cgame.so']:
            raise RuntimeError('Presentation module differs from immutable installation')
        for index in indices:
            if not (args.report / 'clips' / f'{index:03d}.mp4').exists():
                continue
            provenance = args.report / f'render-{index:03d}.inputs.json'
            if (not provenance.exists() or
                json.loads(provenance.read_text()).get('modules', {}).get('cgame.so') != manifest['share/dk3/cgame.so']):
                raise RuntimeError('Existing clip uses another presentation; retain it separately before re-exporting')
        shutil.copy2(candidate, home / 'dk3/cgame.so')
    client = args.replay_client or args.engine / 'bin/dk3'
    (args.report / 'render-inputs.json').write_text(json.dumps(dict(
        engine=str(args.engine), presentation_update=args.update_presentation, selected_demo_indices=indices,
        replay_client=str(client), replay_client_sha256=digest(client),
        raw_video=args.raw_video, software_render=args.software_render,
        modules={p.name: digest(p) for p in sorted((home / 'dk3').glob('*.so'))},
        recorded_modules={p.name: digest(p) for p in sorted((args.report / 'profile/dk3').glob('*.so'))}), indent=2) + '\n')
    output = args.report / 'clips'
    output.mkdir(exist_ok=True)
    for number, entry in enumerate(result['demos']):
        if number not in indices:
            continue
        source = args.report / entry['path']
        if digest(source) != entry['sha256']:
            raise RuntimeError(f'Demo changed: {source}')
        target = output / f'{number:03d}.mp4'
        if target.exists():
            continue
        demo = home / 'dk3/demos' / source.name
        if not demo.exists():
            os.link(source, demo)
        values = base(args, home)
        values.update(dk3_coop_script='', cl_autoRecordDemo='0', fixedtime='0', timedemo='0',
                      cl_aviFrameRate='30', cl_aviMotionJpeg='0' if args.raw_video else '1', nextdemo='echo dk3-video-complete; quit')
        log = args.report / f'render-{number:03d}.log'
        shutil.copyfile(args.report / 'render-inputs.json', log.with_suffix('.inputs.json'))
        process = launch(args, home, values, ['+demo', demo.stem, '+video', f'clip-{number:03d}'], log)
        parts, handled = [], set()

        def encode_closed():
            # The engine prints this only after closing the AVI and its index.
            # Encode rollover chunks while replay continues, bounding raw disk
            # use rather than retaining hours of Motion JPEG until completion.
            output_log = log.read_text(errors='replace')
            if any(marker in output_log for marker in ('\nERROR:', 'AVI capture error:', 'Z_Malloc: failed')):
                raise RuntimeError(f'Demo playback reported an engine error: {log}')
            names = re.findall(r'Wrote (\d+):\d+ frames to videos/(\S+)', output_log)
            for frames, name in names:
                if name in handled:
                    continue
                if not re.fullmatch(rf'clip-{number:03d}\.avi(?:_+|_[0-9]{{6,10}})?', name):
                    raise RuntimeError(f'Unexpected capture name: {name}')
                if len(parts) >= 32 and name.endswith('_'):
                    raise RuntimeError('Legacy AVI rollover may truncate this replay; use a numbered AVI client')
                video = home / 'dk3/videos' / name
                encoded = output / f'{number:03d}-part-{len(parts):03d}.mp4'
                paused = None
                if args.raw_video and process.poll() is None:
                    # Raw chunks can be produced faster than they are encoded.
                    # Pause only this private offline replay while encoding;
                    # AVI advances at fixed frame steps, independently of wall time.
                    pid_file = home / 'state/dk3/dk3.pid'
                    try:
                        pid = int(pid_file.read_text())
                        argv = Path(f'/proc/{pid}/cmdline').read_bytes().split(b'\0')
                        if os.fsencode(home) not in argv:
                            raise RuntimeError('Replay PID does not own this private profile')
                        os.kill(pid, signal.SIGSTOP)
                        paused = pid
                    except (FileNotFoundError, ProcessLookupError):
                        if process.poll() is None and 'dk3-video-complete' not in log.read_text(errors='replace'):
                            raise RuntimeError('Live raw replay has no owned PID for bounded encoding')
                try:
                    encode_video(video, encoded, int(frames))
                finally:
                    if paused is not None:
                        try:
                            os.kill(paused, signal.SIGCONT)
                        except ProcessLookupError:
                            pass
                parts.append(encoded)
                handled.add(name)
                video.unlink()  # Only our successfully encoded intermediates.
                print(f'Encoded chunk {number}:{len(parts)}', flush=True)

        try:
            while process.poll() is None:
                encode_closed()
                time.sleep(0.5)
            encode_closed()
        finally:
            quit_private(home, process)
        if process.returncode or not parts or 'dk3-video-complete' not in log.read_text(errors='replace'):
            raise RuntimeError(f'Demo rendering failed: {log}')
        join(parts, target)
        for part in parts:
            part.unlink()
        print(f'Encoded {number + 1}/{len(result["demos"])}: {target}', flush=True)
    join([output / f'{i:03d}.mp4' for i in indices], args.report / args.output)


def encode_video(video, encoded, frames):
    subprocess.run(['ffmpeg', '-hide_banner', '-loglevel', 'error', '-xerror', '-y', '-i', str(video),
                    '-vf', 'scale=1280:720:force_original_aspect_ratio=decrease,pad=1280:720:(ow-iw)/2:(oh-ih)/2,setsar=1',
                    '-c:v', 'libx264', '-threads', '4', '-preset', 'fast', '-crf', '21', '-pix_fmt', 'yuv420p',
                    '-c:a', 'aac', '-b:a', '160k', '-movflags', '+faststart', str(encoded)], check=True)
    probe = subprocess.check_output(['ffprobe', '-v', 'error', '-show_streams', '-show_format',
                                     '-of', 'json', str(encoded)], text=True)
    streams = json.loads(probe)['streams']
    if not any(s['codec_type'] == 'video' for s in streams) or not any(s['codec_type'] == 'audio' for s in streams):
        raise RuntimeError(f'Video or audio missing: {encoded}')
    if int(next(s for s in streams if s['codec_type'] == 'video')['nb_frames']) != frames:
        raise RuntimeError(f'Encoded frame count differs from engine capture: {encoded}')
    (encoded.with_suffix('.json')).write_text(probe)


def join(paths, target):
    listing = target.with_suffix('.concat.txt')
    listing.write_text(''.join(f"file '{p.resolve()}'\n" for p in paths))
    pending = target.with_name(target.stem + '.joining.mp4')
    subprocess.run(['ffmpeg', '-hide_banner', '-loglevel', 'error', '-y', '-f', 'concat', '-safe', '0',
                    '-i', str(listing), '-c', 'copy', '-movflags', '+faststart', str(pending)], check=True)
    pending.replace(target)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('mode', choices=('record', 'render'))
    parser.add_argument('--engine', type=Path, required=True, help='immutable play installation')
    parser.add_argument('--replay-client', type=Path, help='render with a reviewed client binary while retaining the staged modules and assets')
    parser.add_argument('--guard', type=Path, default=ROOT / 'zig-out/native-dev/bin/dkguard')
    parser.add_argument('--report', type=Path, required=True)
    parser.add_argument('--script', default='episode1-connected.lua')
    parser.add_argument('--map', default='intro')
    parser.add_argument('--until-map')
    parser.add_argument('--load', type=Path, help='continue from an ordinary recorded checkpoint')
    parser.add_argument('--stage', type=int, help='resume this checkpoint stage')
    parser.add_argument('--include-failed', action='store_true', help='explicitly render a failed attempt; its outcome is retained')
    parser.add_argument('--raw-video', action='store_true', help='render through uncompressed AVI chunks instead of Motion JPEG; requires more temporary disk bandwidth')
    parser.add_argument('--software-record', action='store_true', help='capture demos without live scene rasterization; replay renders full video')
    parser.add_argument('--software-render', action='store_true', help='render full video with the headless software renderer')
    parser.add_argument('--seconds', type=int, help='explicit short sample, not episode acceptance')
    parser.add_argument('--motion-trace', action='store_true', help='retain per-frame replay poses and authoritative bot turns for movement evaluation')
    parser.add_argument('--update-presentation', action='store_true', help='explicitly replay with a reviewed cgame update while recorded game/UI module identities remain unchanged')
    parser.add_argument('--clips', type=int, nargs='+', help='render only these original zero-based demo indices; all raw recordings/outcomes remain retained')
    parser.add_argument('--timeout', type=int, default=14400)
    parser.add_argument('--output', default='playthrough.mp4')
    args = parser.parse_args()
    args.engine, args.guard, args.report = args.engine.resolve(), args.guard.resolve(), args.report.resolve()
    if args.software_render and args.mode != 'render':
        parser.error('--software-render requires render mode')
    if args.replay_client:
        args.replay_client = args.replay_client.resolve()
        if args.mode != 'render' or not args.replay_client.is_file() or not os.access(args.replay_client, os.X_OK):
            parser.error('--replay-client requires an executable and render mode')
    (record if args.mode == 'record' else render)(args)


if __name__ == '__main__':
    main()
