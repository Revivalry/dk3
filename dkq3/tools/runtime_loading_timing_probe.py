#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-or-later
"""Headless stage timings for New Game and copied-save menu loading.

Run under dkguard --headless (software rendering). Uses only the engine command
pipe on an isolated X display, never desktop input or window activation. Current
modules enter the real UI actions through the developer-only dk3_menu_loading
command; --console-only labels the limited baseline for older installations.
--save-only starts at copied-save loading in a fresh process, without visiting
intro or the first map. OS page-cache state remains uncontrolled.
--settled-menu captures a completed menu frame before starting the loading action,
separating initial menu rendering from the subsequent load.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import resource
import shutil
import subprocess
import tempfile
import threading
import time

from runtime_input import NativeInput, engine_failure, record_identity
from runtime_probe import stage_client_modules, wait


def isolated_display():
    """Require an actual Xvfb server before any engine process can be created."""
    if os.environ.get("LIBGL_ALWAYS_SOFTWARE") != "1" or os.environ.get("WAYLAND_DISPLAY"):
        return False
    display = re.fullmatch(r":(\d+)(?:\.\d+)?", os.environ.get("DISPLAY", ""))
    if not display:
        return False
    try:
        pid = int(Path(f"/tmp/.X{display[1]}-lock").read_text().strip())
        return Path(f"/proc/{pid}/comm").read_text().strip() == "Xvfb"
    except (OSError, ValueError):
        return False


def timings(text):
    stages = []
    for stage, fields in re.findall(r"dk3 loading timing: stage=(\S+) ([^\n]+)", text):
        values = {key: int(value) if value.lstrip("-").isdigit() else value
                  for key, value in re.findall(r"(\w+)=(\S+)", fields)}
        stages.append(dict(stage=stage, **values))
    marks = [(stage, int(ms)) for stage, ms in re.findall(r"dk3 loading: phase=(\S+) ms=(\d+)", text)]
    images = [dict(name=name, read_decode_ms=int(read), prepare_upload_ms=int(upload))
              for name, read, upload in re.findall(
                  r"dk3 image admission: name=(\S+) size=\S+ read_decode_ms=(\d+) prepare_upload_ms=(\d+)", text)]
    return dict(stages=stages, client_marks=marks, images=images)


def sample(args, report, after_load=None):
    inputs, events = [], []
    result = {"status": "failed", "path": "console baseline" if args.console_only else "UI actions"}
    with tempfile.TemporaryDirectory(prefix="dk3-loading-headless-") as temporary:
        home = Path(temporary)
        stage_client_modules(args.prefix, home)
        shutil.copy2(args.profile, home / "dk3/dk3config.cfg")
        saves = home / "state/dk3/saves"
        saves.mkdir(parents=True)
        for index, source in enumerate(args.save):
            shutil.copy2(source, saves / f"reported{index}.sav")
        settings = {
            "fs_basepath": str(args.engine / "share"), "fs_homepath": str(home),
            "fs_homedatapath": str(home), "fs_homestatepath": str(home / "state"),
            "com_basegame": "dk3", "com_pipefile": "commands.fifo", "net_enabled": "0",
            "vm_game": "0", "vm_cgame": "0", "vm_ui": "0", "dk3_runtime_probe": "2",
            "g_gametype": "2", "developer": "1", "in_nograb": "1", "cl_renderer": args.renderer,
            "r_fullscreen": "0", "r_mode": "-1", "r_customwidth": "960", "r_customheight": "540",
            "s_useOpenAL": "0", "dk3_cinematics": "1", "com_maxfps": "60",
            # The software benchmark measures CPU loading stages. Do not copy
            # the desktop's hardware tracing tier into lavapipe.
            "r_vkRayTracing": "0",
        }
        if args.decode_cache_mib is not None:
            settings["r_imageDecodeCacheMegs"] = str(args.decode_cache_mib)
        if args.model_prefetch is not None:
            settings["r_modelImagePrefetch"] = str(args.model_prefetch)
        if args.model_prefetch_slots is not None:
            settings["r_modelImagePrefetchSlots"] = str(args.model_prefetch_slots)
        command = [str(args.prefix / "bin/dk3")]
        for name, value in settings.items():
            command += ["+set", name, value]
        if args.gdb:
            command = ["gdb", "-q", "-batch", "-ex", "set debuginfod enabled off",
                       "-ex", "set print thread-events off", "-ex", "run",
                       "-ex", "thread apply all bt 4", "-ex", "info registers",
                       "-ex", "x/16i $pc-24", "--args", *command]
        (report / "command.json").write_text(json.dumps(command, indent=2) + "\n")
        log = report / "client.log"
        children_before = resource.getrusage(resource.RUSAGE_CHILDREN)
        launched = time.monotonic()
        with log.open("w") as output:
            environment = dict(os.environ, SDL_VIDEODRIVER="x11")
            process = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                       text=True, bufsize=1, env=environment)

            def collect():
                for line in process.stdout:
                    at = time.monotonic() - launched
                    output.write(line)
                    output.flush()
                    if any(marker in line for marker in (
                        "Server:", "RE_Shutdown", "R_Init", "loading:", "loading timing:", "CL_InitCGame:",
                        "first snapshot applied", "restoration", "world restored", "VK_", "image admission:",
                    )):
                        events.append({"seconds": round(at, 6), "line": line.strip()})

            reader = threading.Thread(target=collect, daemon=True)
            reader.start()
            observer = NativeInput(process, home / "dk3/commands.fifo", log, home, inputs,
                                   diagnostic=True, response_timeout=args.observe_timeout)

            def expect(predicate, offset=0):
                text = wait(process, log, lambda t: predicate(t[offset:]) or engine_failure(t[offset:]) or
                            "loading probe refused:" in t[offset:] or "Load refused:" in t[offset:], args.timeout)
                if failure := engine_failure(text[offset:]):
                    raise RuntimeError(failure)
                if "refused:" in text[offset:]:
                    raise RuntimeError(text[offset:][-1500:])
                return text[offset:]

            def capture(name):
                source = home / f"dk3/screenshots/{name}.jpg"
                observer.issue(f"screenshotJPEG {name}")
                expect(lambda _: source.exists() and source.stat().st_size > 0)
                shutil.copy2(source, report / source.name)
                return time.monotonic()

            def disconnect():
                offset = len(observer.text())
                observer.issue("disconnect")
                expect(lambda text: "Server Shutdown" in text, offset)
                # Queue behind disconnect; subsequent actions run on the main menu.
                observer.issue("dk3_menu_page 0")

            def image_admission(started):
                if args.renderer != "vulkan":
                    return []
                deadline, samples = time.monotonic() + args.timeout, []
                while time.monotonic() < deadline:
                    text = observer.diagnostics("dk3_image_pending", "dk3 pending images:",
                                                seconds=args.observe_timeout)
                    match = re.search(r"dk3 pending images: count=(\d+) failed=(\d+)", text)
                    if not match:
                        raise RuntimeError("renderer did not provide complete image admission status")
                    pending, failed = map(int, match.groups())
                    samples.append(dict(seconds=time.monotonic() - started, pending=pending, failed=failed))
                    if failed:
                        raise RuntimeError("renderer kept a failed deferred-image placeholder")
                    if not pending:
                        return samples
                raise TimeoutError("deferred image admission did not finish")

            try:
                expect(lambda t: "native menus initialized" in t and observer.pipe.exists())
                result["menu_startup_seconds"] = time.monotonic() - launched
                text = observer.text()
                result["device"] = next((line for line in text.splitlines() if "VK_RENDERER:" in line or "GL_RENDERER:" in line), None)
                if not result["device"] or not any(name in result["device"].lower() for name in ("llvmpipe", "lavapipe", "software")):
                    raise RuntimeError("headless software renderer not confirmed")
                if getattr(args, "settled_menu", False):
                    # File completion includes readback/JPEG encoding: an upper bound,
                    # unlike the earlier native-menu-initialized event.
                    result["menu_capture_upper_bound_seconds"] = capture("menu-startup") - launched
                if not args.save_only:
                    offset, started = len(text), time.monotonic()
                    observer.issue("map intro" if args.console_only else "dk3_menu_loading new-game")
                    expect(lambda t: "first snapshot applied" in t, offset)
                    state = observer.until(lambda s: s["map"] == "intro" and s["cinematic"], seconds=args.timeout)
                    input_ready = time.monotonic()
                    admission = image_admission(started)
                    ready = time.monotonic()
                    result["new_game"] = dict(ready_seconds=ready - started,
                        input_ready_seconds=input_ready - started, image_admission=admission,
                        capture_upper_bound_seconds=capture("intro") - started,
                        state=state, **timings(observer.text()[offset:]))
                    disconnect()
                    # Direct-map timing excludes authored movie playback;
                    # it does not establish campaign traversal acceptance.
                    observer.issue("set dk3_cinematics 0")
                    offset, started = len(observer.text()), time.monotonic()
                    observer.issue("map e1m1a")
                    expect(lambda t: "first snapshot applied" in t, offset)
                    state = observer.until(lambda s: s["map"] == "e1m1a" and s["mode"] == "normal", seconds=args.timeout)
                    input_ready = time.monotonic()
                    admission = image_admission(started)
                    ready = time.monotonic()
                    result["first_map"] = dict(ready_seconds=ready - started,
                        input_ready_seconds=input_ready - started, image_admission=admission,
                        capture_upper_bound_seconds=capture("first-map") - started,
                        state=state, **timings(observer.text()[offset:]))
                    disconnect()
                else:
                    result["workload"] = ("fresh-process save after menu capture; OS page cache uncontrolled"
                                          if getattr(args, "settled_menu", False) else
                                          "fresh-process save from menu; OS page cache uncontrolled")
                observer.issue("set dk3_cinematics 0")
                result["loads"] = []
                for index, source in enumerate(args.save):
                    offset, started = len(observer.text()), time.monotonic()
                    observer.issue(f"dk3_loadmenu reported{index}" if args.console_only else f"dk3_menu_loading load reported{index}")
                    expect(lambda t: "restoration applied" in t, offset)
                    state = observer.until(lambda s: s["mode"] == "normal", seconds=args.timeout)
                    input_ready = time.monotonic()
                    admission = image_admission(started)
                    ready = time.monotonic()
                    result["loads"].append(dict(source=str(source), ready_seconds=ready - started,
                        launch_ready_seconds=ready - launched,
                        input_ready_seconds=input_ready - started, image_admission=admission,
                        capture_upper_bound_seconds=capture(f"restored-{index}") - started,
                        state=state, **timings(observer.text()[offset:])))
                    # Optional local diagnostic after measured readiness; callers
                    # keep these extended-process resources separate from A/B runs.
                    if after_load is not None:
                        result["loads"][-1]["diagnostic"] = after_load(observer, report, capture)
                    disconnect()
                observer.issue("quit")
                if process.wait(timeout=15) != 0:
                    raise RuntimeError("engine did not exit cleanly")
                children_after = resource.getrusage(resource.RUSAGE_CHILDREN)
                result["child_peak_rss_kib"] = children_after.ru_maxrss
                result["child_cpu_user_seconds"] = children_after.ru_utime - children_before.ru_utime
                result["child_cpu_system_seconds"] = children_after.ru_stime - children_before.ru_stime
                result["child_major_faults"] = children_after.ru_majflt - children_before.ru_majflt
                result["status"] = "passed"
            except Exception as error:
                result["error"] = str(error)
                raise
            finally:
                if process.poll() is None:
                    try:
                        observer.issue("quit")
                        process.wait(timeout=10)
                    except (OSError, subprocess.TimeoutExpired):
                        process.terminate()
                        try:
                            process.wait(timeout=10)
                        except subprocess.TimeoutExpired:
                            process.kill()
                            process.wait(timeout=10)
                reader.join(timeout=5)
                crash = home / "dk3/crashlog.txt"
                if crash.is_file():
                    shutil.copy2(crash, report / "engine-crashlog.txt")
                (report / "inputs.json").write_text(json.dumps(inputs, indent=2) + "\n")
                (report / "events.json").write_text(json.dumps(events, indent=2) + "\n")
                (report / "result.json").write_text(json.dumps(result, indent=2) + "\n")
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ("engine", "prefix", "profile", "report"):
        parser.add_argument("--" + name, type=Path, required=True)
    parser.add_argument("--save", type=Path, action="append", required=True)
    parser.add_argument("--console-only", action="store_true")
    parser.add_argument("--save-only", action="store_true",
                        help="load copied saves directly from a fresh menu; no intro/map cache priming (OS page cache uncontrolled)")
    parser.add_argument("--settled-menu", action="store_true",
                        help="capture a completed menu frame before loading; report its capture upper bound separately")
    parser.add_argument("--gdb", action="store_true", help="retain a batch crash trace; diagnostic timings only")
    parser.add_argument("--renderer", choices=("opengl1", "opengl2", "vulkan"), default="opengl2")
    parser.add_argument("--decode-cache-mib", type=int, choices=range(0, 1025), metavar="0..1024")
    parser.add_argument("--model-prefetch", type=int, choices=(0, 1),
                        help="compare bounded initial model preparation with ordinary registration")
    parser.add_argument("--model-prefetch-slots", type=int, choices=(1, 2, 3),
                        help="bounded model preparation slots for controlled CPU/resource comparisons")
    parser.add_argument("--repeats", type=int, default=3)
    parser.add_argument("--timeout", type=float, default=90)
    parser.add_argument("--observe-timeout", type=float, default=5,
                        help="response bound for instrumented software-renderer frames")
    args = parser.parse_args()
    if not isolated_display():
        parser.error("run under dkguard --headless; desktop runs are prohibited")
    if args.repeats < 1 or args.timeout <= 0 or args.observe_timeout <= 0:
        parser.error("repeats and timeout must be positive")
    for name in ("engine", "prefix", "profile", "report"):
        setattr(args, name, getattr(args, name).resolve())
    args.save = [source.resolve() for source in args.save]
    if args.report.exists():
        raise RuntimeError("timing evidence requires a fresh report directory")
    args.report.mkdir(parents=True)
    # The executable/renderers are selected from prefix; packages from engine.
    record_identity(args.engine, args.prefix, args.report)
    runtime = [args.prefix / "bin/dk3", *sorted((args.prefix / "bin").glob("renderer*.so"))]
    sources = {str(path): hashlib.sha256(path.read_bytes()).hexdigest()
               for path in [args.profile, *args.save, *runtime]}
    (args.report / "sources.json").write_text(json.dumps(sources, indent=2) + "\n")
    results = []
    try:
        for index in range(1, args.repeats + 1):
            report = args.report / f"sample-{index:03}"
            report.mkdir()
            result = sample(args, report)
            results.append(result)
            summary = {"sample": index, "loads": [row["ready_seconds"] for row in result["loads"]]}
            if "new_game" in result:
                summary["new_game"] = result["new_game"]["ready_seconds"]
            if "workload" in result:
                summary["workload"] = result["workload"]
            print(json.dumps(summary), flush=True)
    finally:
        preserved = {str(path): hashlib.sha256(path.read_bytes()).hexdigest() == sources[str(path)]
                     for path in [args.profile, *args.save]}
        (args.report / "preservation.json").write_text(json.dumps(preserved, indent=2) + "\n")
        if not all(preserved.values()):
            raise RuntimeError("source configuration/save changed during probe")
    (args.report / "passed.json").write_text(json.dumps(results, indent=2) + "\n")


if __name__ == "__main__":
    main()
