#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-or-later
"""Isolated HUD/save integration evidence; remote switch fixtures do not certify campaign traversal."""
import argparse
from pathlib import Path
import re
import shutil
import time


def scenario(issue, capture, log, home, *, legacy_expected=False, checkpoint=None):
    if checkpoint is not None:
        saves = home / "state/dk3/saves"
        saves.mkdir(parents=True, exist_ok=True)
        shutil.copy2(checkpoint, saves / "campaign_counter_source.sav")
        issue("developer 1")
        issue("cg_minimap 1")
        issue("cg_objectives 1")

        def counter(partial=False):
            mark = len(log.read_text(errors="replace"))
            deadline = time.monotonic() + 25
            while time.monotonic() < deadline:
                issue("dk3_runtime_objectives", 0.5)
                rows = re.findall(r"dk3 goal: index=1 .*progress=(\d+)/(\d+) done=(\d)", log.read_text(errors="replace")[mark:])
                if rows:
                    value = tuple(map(int, rows[-1]))
                    if not partial or 0 < value[0] < value[1]:
                        return value
            raise RuntimeError("no restored counter objective report")

        def load_ready(slot):
            mark = len(log.read_text(errors="replace"))
            issue(f"load {slot}", 0.5)
            deadline = time.monotonic() + 60
            while time.monotonic() < deadline:
                if "phase=region-ready" in log.read_text(errors="replace")[mark:]:
                    return
                time.sleep(0.2)
            raise RuntimeError("loaded counter world did not finish region admission")

        load_ready("campaign_counter_source")
        before = counter(partial=True)
        if not (0 < before[0] < before[1] == 10 and before[2] == 0):
            raise RuntimeError(f"checkpoint did not retain partial wave progress: {before}")
        capture("counter-progress")
        issue("save campaign_counter_roundtrip", 0.5)
        saved = counter()
        load_ready("campaign_counter_roundtrip")
        restored = counter(partial=True)
        if restored != saved:
            raise RuntimeError(f"counter save/load changed progress: {saved} -> {restored}")
        capture("counter-restored")
        issue("objectives")
        capture("counter-objectives-off")
        issue("minimap")
        capture("counter-minimap-off")
        return {"map": "e2m5e", "checkpoint": str(checkpoint), "progress": before,
                "saved_progress": saved, "restored_progress": restored,
                "scope": "HUD rendering/toggles and save roundtrip from an ordinary gameplay counter save; no remote activation, grants or placement"}
    issue("developer 1")
    issue("cg_objectives 0")
    issue("cg_minimap 1")
    capture("minimap")
    issue("objectives")
    capture("objectives")
    for key, command in (("o", "objectives"), ("p", "hud_cycle"), ("[", "hud_prev"), ("]", "hud_next"), ("m", "minimap")):
        mark = len(log.read_text(errors="replace"))
        issue(f"bind {key}")
        if not re.search(r'"' + re.escape(key) + r'" = "' + command + '"', re.sub(r"\^\d", "", log.read_text(errors="replace")[mark:])):
            raise RuntimeError(f"missing default {key}: {command}")
    legacy = legacy_expected
    if legacy:
        mark = len(log.read_text(errors="replace"))
        issue("bind F7")
        if '"F7" = "viewpos"' not in re.sub(r"\^\d", "", log.read_text(errors="replace")[mark:]):
            raise RuntimeError("profile migration replaced an unrelated custom binding")
        issue("dk3_binds")
        if not re.search(r'"dk3_binds" is:"3', re.sub(r"\^\d", "", log.read_text(errors="replace")[mark:])):
            raise RuntimeError("profile binding version was not migrated")
    issue("minimap")
    issue("cg_minimap")
    if not re.search(r'"cg_minimap" is:"0', re.sub(r"\^\d", "", log.read_text(errors="replace"))):
        raise RuntimeError("minimap toggle did not update its cvar")
    capture("minimap-off")
    issue("minimap")

    def progress():
        mark = len(log.read_text(errors="replace"))
        issue("dk3_runtime_objectives", 0.3)
        rows = re.findall(r"dk3 goal: index=0 .*progress=(\d+)/(\d+) done=(\d)", log.read_text(errors="replace")[mark:])
        if not rows:
            raise RuntimeError("no authoritative objective report")
        return tuple(map(int, rows[-1]))

    if progress() != (0, 2, 0):
        raise RuntimeError("new map did not start with two unpressed tiles")
    issue("dk3_runtime_activate 44", 1)
    if progress() != (1, 2, 0):
        raise RuntimeError("first tile failed to advance the multi-control goal")
    capture("one-tile")
    issue("save campaign_hud_probe", 0.4)
    if not (home / "state/dk3/saves/campaign_hud_probe.sav").exists():
        raise RuntimeError("isolated objective save was not written")
    issue("dk3_runtime_activate 45", 1)
    if progress() != (2, 2, 1):
        raise RuntimeError("second tile did not complete the goal")
    capture("two-tiles")
    issue("load campaign_hud_probe", 1)
    if progress() != (1, 2, 0):
        raise RuntimeError("load did not restore partial objective progress")
    capture("restored-one-tile")
    issue("objectives")
    capture("objectives-off")
    return {"map": "e2m1a", "legacy_profile": legacy, "progress": ["0/2", "1/2", "2/2", "load:1/2"],
            "scope": "HUD rendering/toggles, defaults, authoritative partial progress and save rollback; diagnostic remote switch activation; campaign traversal remains unverified"}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--engine", type=Path, required=True)
    parser.add_argument("--prefix", type=Path, required=True)
    parser.add_argument("--guard", type=Path, default=Path("zig-out/native-dev/bin/dkguard"))
    parser.add_argument("--report", type=Path, default=Path("zig-out/reports/campaign-hud-578"))
    parser.add_argument("--renderer", choices=("opengl1", "opengl2", "vulkan"), default="opengl2")
    parser.add_argument("--legacy-profile", action="store_true")
    parser.add_argument("--checkpoint", type=Path, help="Ordinary gameplay save with partial ending-counter progress")
    parser.add_argument("--map", default="e2m1a")
    args = parser.parse_args()
    args.scenario, args.workers, args.mover = "campaign-hud", 4, None
    if args.legacy_profile:
        args.profile_config = ('// campaign-hud legacy profile fixture\nseta dk3_binds "2"\n'
                               'bind o "hud_cycle"\nbind p "attribute_next"\n'
                               'bind k "hud_prev"\nbind l "hud_next"\nbind F7 "viewpos"\n')
    for name in ("engine", "prefix", "guard", "report"):
        setattr(args, name, getattr(args, name).resolve())
    from runtime_player_probe import run
    run(args)


if __name__ == "__main__":
    main()
