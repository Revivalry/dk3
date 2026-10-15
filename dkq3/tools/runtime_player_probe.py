#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-or-later
"""Isolated native client/movement probe; does not certify campaign acceptance."""
import argparse
import json
import math
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import time

from runtime_probe import send, wait, stage_client_modules, client_settings


def movement_scenario(args, issue, capture, log):
    issue("viewpos")
    capture("standing")
    issue("+forward", 1)
    issue("-forward")
    issue("viewpos")
    issue("+movedown", 0.5)
    capture("crouching")
    issue("-movedown")
    issue("+moveup", 0.3)
    issue("-moveup", 1)
    issue("viewpos")
    if args.mover is not None:
        issue(f"dk3_runtime_activate {args.mover}", 0.25)
        issue("dk3_runtime_movers", 0.05)
        issue(f"dk3_runtime_activate {args.mover}", 0.25)
        issue("dk3_runtime_movers", 2)
        issue("dk3_runtime_movers", 4)
        issue("dk3_runtime_movers")
    text = log.read_text(errors="replace")
    positions = re.findall(r"zig viewpos: ([^\n]+)", text)
    if len(positions) != 3:
        raise RuntimeError(f"missing movement diagnostics: {log}")
    if args.mover is not None:
        states = re.findall(rf"zig mover id={args.mover} .*state=(\w+)", text)
        if len(states) != 4 or states[:2] != ["opening", "opening"] or states[-1] != "open":
            raise RuntimeError(f"unexpected repeated activation/delayed arrival: {states}")
    return {"positions": positions, "scope": "native connection and movement diagnostics; authored gameplay unqualified"}


def lift_scenario(issue, capture, log):
    # Valid standing position from the existing recorded lift regression; no save is modified.
    issue("dk3_runtime_place 818.916 -479.481 -823.875", 0.5)
    issue("viewpos")
    capture("lift-bottom")
    issue("dk3_runtime_activate 3", 0.25)
    issue("dk3_runtime_activate 3", 0.25)
    samples = []
    top_captured = False
    deadline = time.monotonic() + 40
    while time.monotonic() < deadline:
        issue("dk3_runtime_trains", 0.05)
        issue("viewpos", 0.05)
        issue("dk3_runtime_status", 0.2)
        text = log.read_text(errors="replace")
        lines = re.findall(r"zig train id=3 name=bigplat ([^\n]+)", text)
        if not lines:
            raise RuntimeError("bigplat diagnostics missing")
        fields = dict(re.findall(r"(\w+)=([^ ]+)", lines[-1]))
        positions = re.findall(r"zig viewpos: ([^,]+),", text)
        times = re.findall(r"dk3 zig: entities=\d+ frames=\d+ time=(\d+)", text)
        sample = {"phase": fields["phase"], "wait": int(fields["wait"]),
                  "due": None if fields["due"] == "null" else int(fields["due"]),
                  "train_z": float(fields["pos"].split(",")[2]),
                  "player_z": float(positions[-1].split()[2]), "time": int(times[-1])}
        samples.append(sample)
        if sample["phase"] == "dwelling" and not top_captured:
            capture("lift-top")
            top_captured = True
        if top_captured and sample["phase"] == "paused":
            break
    (log.parent / "lift-samples.json").write_text(json.dumps(samples, indent=2) + "\n")
    top = [sample for sample in samples if sample["phase"] == "dwelling"]
    if not top or any(abs(sample["train_z"] + 274) > 0.01 or sample["wait"] != 10000 for sample in top):
        raise RuntimeError("lift did not reach the authored upper dwell")
    if len({sample["due"] for sample in top}) != 1 or top[-1]["time"] - top[0]["time"] < 9000:
        raise RuntimeError("lift returned before its ten-second dwell")
    if samples[-1]["phase"] != "paused" or abs(samples[-1]["train_z"] + 902) > 0.01:
        raise RuntimeError("lift did not return to trigger-only lower rest")
    if max(sample["player_z"] for sample in samples) - samples[-1]["player_z"] < 500:
        raise RuntimeError("rider was not carried to the upper stop")
    capture("lift-returned")
    return {"samples": len(samples), "scope": "e1m3a lift ride, departure dwell and return; diagnostic activation, not full campaign acceptance"}


def special_scenario(args, issue, capture, log):
    identity = 43 if args.scenario == "secret" else 72

    def sample():
        issue("dk3_runtime_special", 0.4)
        values = re.findall(rf"zig special id={identity} phase=(\w+) pos=([^\n]+) angles=([^\n]+)", log.read_text(errors="replace"))
        if not values:
            raise RuntimeError("special mover diagnostics missing")
        return values[-1]

    if args.scenario == "secret":
        issue(f"dk3_runtime_activate {identity}")
        phases = []
        deadline = time.monotonic() + 35
        while time.monotonic() < deadline:
            phases.append(sample()[0])
            if "open" in phases and phases[-1] == "closed":
                break
        if not all(phase in phases for phase in ("waiting_first", "open", "waiting_return")) or phases[-1] != "closed":
            raise RuntimeError(f"incomplete secret-door cycle: {phases}")
        return {"phases": phases, "scope": "e3dm1 secret-door cycle; diagnostic activation, shoot activation unqualified"}
    first, second = sample(), sample()
    if first[0] != "rotating" or second[0] != "rotating" or first[2] == second[2]:
        raise RuntimeError("authored rotation did not start")
    issue(f"dk3_runtime_activate {identity}")
    stopped, held = sample(), sample()
    if stopped != held or stopped[0] != "stopped":
        raise RuntimeError("rotation failed to remain stopped")
    issue(f"dk3_runtime_activate {identity}")
    resumed, moving = sample(), sample()
    if resumed[0] != "rotating" or moving[0] != "rotating" or resumed[2] == moving[2]:
        raise RuntimeError("rotation did not resume")
    return {"samples": [first, second, stopped, held, resumed, moving],
            "scope": "e1m3b rotating brush start, toggle and resume; rotating riders unqualified"}


def inventory_scenario(issue, capture, log):
    def mover_state(identity):
        issue("dk3_runtime_movers")
        states = re.findall(rf"zig mover id={identity} .*state=(\w+)", log.read_text(errors="replace"))
        if not states:
            raise RuntimeError(f"missing mover {identity}")
        return states[-1]

    issue("dk3_runtime_activate 85 player", 0.5)
    if mover_state(85) != "closed":
        raise RuntimeError("key-locked button opened without key")
    issue("dk3_runtime_items")
    text = log.read_text(errors="replace")
    values = re.findall(r"zig item id=2 class=item_control_card_blue visible=(\d) ground=(\w+) pos=([^\n]+)", text)
    if not values or values[-1][0] != "1" or values[-1][1] == "null":
        raise RuntimeError("key did not settle on the floor")
    x, y, z = map(float, values[-1][2].split(","))
    issue(f"dk3_runtime_place {x + 80} {y} {z + 24}", 0.2)
    issue("dk3_look 180 15")
    capture("key-before")
    issue(f"dk3_runtime_place {x} {y} {z + 24}", 0.5)
    issue("dk3_runtime_inventory")
    issue("dk3_runtime_items")
    text = log.read_text(errors="replace")
    keys = re.findall(r"zig inventory keys=([0-9a-f]+)", text)
    if not keys or int(keys[-1], 16) & (1 << 0) == 0:
        raise RuntimeError("touch failed to collect blue keycard")
    if not re.search(r"zig item id=2 class=item_control_card_blue visible=0", text):
        raise RuntimeError("collected key remained visible")
    issue("dk3_runtime_activate 85 player", 0.3)
    state = mover_state(85)
    if state not in ("opening", "open"):
        raise RuntimeError("collected key did not unlock button")
    issue("dk3_runtime_items", 1)
    if mover_state(82) not in ("opening", "open"):
        raise RuntimeError("button arrival failed to activate four-way door")
    capture("key-collected")
    return {"keys": keys[-1], "button_state": state,
            "scope": "e1m6a key floor settlement, touch pickup and locked button target; diagnostic positioning, full authored progression unqualified"}


def effects_scenario(issue, capture, log):
    issue("set developer 1")

    def collect(identity, classname):
        issue("dk3_runtime_items")
        values = re.findall(rf"zig item id={identity} class={classname} visible=(\d) ground=(\w+) pos=([^\n]+)", log.read_text(errors="replace"))
        if not values or values[-1][0] != "1" or values[-1][1] == "null":
            raise RuntimeError(f"pickup {identity} missing or not settled")
        x, y, z = map(float, values[-1][2].split(","))
        issue(f"dk3_runtime_place {x} {y} {z + 24}", 0.5)
        issue("dk3_runtime_items")
        if not re.search(rf"zig item id={identity} class={classname} visible=0", log.read_text(errors="replace")):
            raise RuntimeError(f"pickup {identity} not collected")

    def character():
        issue("dk3_runtime_character")
        lines = re.findall(r"zig character ([^\n]+)", log.read_text(errors="replace"))
        return {key: int(value) for key, value in re.findall(r"(\w+)=(\d+)", lines[-1])}

    collect(320, "item_speed_boost")
    boosted = character()
    if boosted["speed"] != 1 or not 28000 <= boosted["boost_until"] - boosted["time"] <= 30000:
        raise RuntimeError("speed boost did not apply for thirty seconds")
    collect(14, "item_invincibility")
    protected = character()
    issue("dk3_runtime_damage 40")
    if not re.search(r"zig damage blood=0 armor=0 killed=0", log.read_text(errors="replace")):
        raise RuntimeError("invincibility failed to protect the player")
    deadline = time.monotonic() + 40
    samples = []
    while time.monotonic() < deadline:
        current = character()
        samples.append(current)
        if current["time"] >= max(protected["invincible"], boosted["boost_until"]):
            break
        issue("dk3_runtime_status", 1)
    if samples[-1]["speed"] != 0 or samples[-1]["time"] < protected["invincible"]:
        raise RuntimeError("timed pickups failed to expire")
    issue("dk3_runtime_damage 40")
    damage = re.findall(r"zig damage blood=(\d+) armor=(\d+)", log.read_text(errors="replace"))
    if not damage or int(damage[-1][0]) <= 0:
        raise RuntimeError("expired protection still blocked damage")
    text = log.read_text(errors="replace")
    sounds = text.count("dk3 zig: snapshot sound dispatched")
    if sounds < 2 or "could not find sounds/" in text.lower():
        raise RuntimeError("pickup sound assets/dispatch missing")
    capture("effects-expired")
    return {"boosted": boosted, "protected": protected, "expired": samples[-1], "sound_events": sounds,
            "scope": "e4m4b pickup timers, protection and snapshot audio dispatch; diagnostic positioning/damage, physical audio and combat parity unqualified"}


def combat_scenario(issue, capture, log):
    issue("developer 1")
    results = []
    for weapon in (21, 2, 4, 22, 23):
        issue("dk3_runtime_clear_targets")
        issue(f"dk3_runtime_equip {weapon}")
        issue("dk3_runtime_target")
        issue("dk3_runtime_targets")
        before = len(log.read_text(errors="replace"))
        issue("+attack", 4)
        issue("-attack", 0.3)
        issue("dk3_runtime_targets")
        text = log.read_text(errors="replace")[before:]
        health = re.findall(r"zig combat: target=(\d+) health=(-?\d+)", text)
        if not health or int(health[-1][1]) > 0 or "killed=1" not in text:
            raise RuntimeError(f"weapon {weapon} did not kill target through normal attack input: {log}")
        results.append({"weapon": weapon, "target": int(health[-1][0]), "health": int(health[-1][1])})
        capture(f"combat-{weapon}")
    text = log.read_text(errors="replace")
    for weapon in (4, 23):
        if f"zig pellets: weapon={weapon}" not in text:
            raise RuntimeError(f"weapon {weapon} did not dispatch its pellet policy")
    return {"attacks": results, "scope": "normal fire input against diagnostic ECS targets; Glock/Ion/Shotcycler/Ripgun/Slugger damage and death; not actor/campaign or complete visual parity acceptance"}


def presentation_scenario(issue, capture, log):
    issue("developer 1")
    issue("cg_shinyWeapons 0")
    for weapon in (1, 21, 2):
        issue(f"dk3_runtime_equip {weapon}", 1)
        issue(f"weapon {weapon}", 1)
        capture(f"weapon-{weapon}-idle")
        issue("+attack", 0.02)
        capture(f"weapon-{weapon}-fire")
        issue("-attack", 1)
    issue("weapon 21", 1)
    issue("+attack", 5.9)
    capture("glock-reload")
    issue("-attack", 2)
    capture("glock-idle-after-reload")
    issue("cg_shinyWeapons 2")
    capture("glock-shine")
    issue("inventory")
    capture("inventory")
    text = log.read_text(errors="replace")
    for weapon in (1, 21, 2):
        for phase in ("fire", "idle"):
            if f"zig view: weapon={weapon} phase={phase}" not in text:
                raise RuntimeError(f"missing view transition {weapon}/{phase}")
    if "zig view: weapon=21 phase=reload" not in text:
        raise RuntimeError("Glock did not enter its class-owned reload animation")
    if "missing weapon animation" in text or "could not find sounds/" in text.lower():
        raise RuntimeError("missing weapon presentation media")
    return {"scope": "three native view weapons, finite attacks/idle, Glock reload, shine and inventory; captures require visual inspection, all-weapon presentation remains open"}


def impacts_scenario(issue, capture, log):
    issue("developer 1")
    issue("dk3_runtime_equip 2")
    issue("dk3_runtime_face_target 10", 0.3)
    placements = re.findall(r"zig combat: fixture player=([\d.,-]+) target=10", log.read_text(errors="replace"))
    if not placements:
        raise RuntimeError("no standing point near authored worker 10")
    player = list(map(float, placements[-1].split(',')))
    for _ in range(40):
        issue("dk3_runtime_actors", 0.05)
        samples = re.findall(r"zig actor: id=10 state=\w+ health=(-?\d+) pos=([\d.,-]+)", log.read_text(errors="replace"))
        if not samples or int(samples[-1][0]) <= 0:
            break
        target = list(map(float, samples[-1][1].split(',')))
        dx, dy, dz = target[0] - player[0], target[1] - player[1], target[2] + 8 - (player[2] + 22)
        issue(f"dk3_look {math.degrees(math.atan2(dy, dx))} {-math.degrees(math.atan2(dz, math.hypot(dx, dy)))}", 0.05)
        issue("+attack", 0.1)
    issue("-attack", 0.2)
    capture("ion-worker-impact")
    issue("dk3_look 0 65")
    issue("+attack", 0.6)
    capture("ion-world-impact")
    issue("-attack", 0.3)
    for weapon, duration in ((4, 1.9), (22, 1.1), (23, 0.2)):
        issue(f"dk3_runtime_equip {weapon}", 0.8)
        issue("dk3_look 0 65")
        issue("+attack", duration)
        capture(f"impact-{weapon}-fire")
        issue("-attack", 2.2)
        capture(f"impact-{weapon}-settled")
    text = log.read_text(errors="replace")
    if not re.search(r"impact: weapon=2 kind=flesh sound=e1/we_ionexplode", text):
        raise RuntimeError("Ion did not select a flesh explosion sound")
    if not re.search(r"impact: weapon=2 kind=(?:world|metal|wood) sound=global/e_electronspr", text):
        raise RuntimeError("Ion did not select a world spark sound")
    if not re.search(r"impact: weapon=(?:4|22|23).*marks=[1-9]", text):
        raise RuntimeError("weapon impacts did not project world decals")
    if "weapon=22 phase=settle pose=spdn" not in text:
        raise RuntimeError("Ripgun did not spin down after releasing fire")
    if "missing weapon animation" in text or "could not find sounds/" in text.lower():
        raise RuntimeError("missing weapon presentation media")
    return {"scope": "Ion authored flesh/world sound selection, clipped world marks, Shotcycler burst and Ripgun spin-down; diagnostic placement/equipment, captures require inspection, physical audio/full weapon parity open"}


def ballistics_scenario(issue, capture, log, process):
    def impact_frame(name, weapon, after):
        wait(process, log, lambda text: f"impact: weapon={weapon}" in text[after:] and
             (weapon != 27 or "sound=global/e_explode1.wav" in text[after:]), 8)
        capture(name)

    issue("developer 1")
    issue("dk3_runtime_probe_health 500")
    results = []
    for weapon in (16, 5):
        issue("dk3_runtime_clear_targets")
        issue(f"dk3_runtime_equip {weapon}", 0.8)
        issue(f"weapon {weapon}", 0.6)
        issue("dk3_runtime_target")
        before = len(log.read_text(errors="replace"))
        issue("+attack", 0.15)
        if weapon == 5:
            impact_frame(f"ballistics-{weapon}-fire", weapon, before)
        else:
            capture(f"ballistics-{weapon}-fire")
        issue("+attack", 3.85)
        issue("-attack", 0.4)
        issue("dk3_runtime_targets")
        text = log.read_text(errors="replace")[before:]
        health = re.findall(r"zig combat: target=(\d+) health=(-?\d+)", text)
        if not health or int(health[-1][1]) > 0 or "killed=1" not in text:
            raise RuntimeError(f"projectile weapon {weapon} did not kill its target: {log}")
        results.append({"weapon": weapon, "health": int(health[-1][1])})
        capture(f"ballistics-{weapon}")
    issue("dk3_runtime_clear_targets")
    issue("dk3_runtime_equip 16", 0.8)
    issue("weapon 16", 0.6)
    issue("dk3_look 0 65")
    issue("+attack", 0.05)
    issue("-attack", 0.3)
    before = len(log.read_text(errors="replace"))
    issue("dk3_runtime_projectiles")
    text = log.read_text(errors="replace")[before:]
    bolts = re.findall(r"projectile state: id=(\d+) weapon=16 stuck=1", text)
    if not bolts:
        raise RuntimeError("Bolter did not stick in the static floor")
    issue("save stuck_bolt", 0.2)
    issue("load stuck_bolt", 0.3)
    before = len(log.read_text(errors="replace"))
    issue("dk3_runtime_projectiles")
    if f"projectile state: id={bolts[-1]} weapon=16 stuck=1" not in log.read_text(errors="replace")[before:]:
        raise RuntimeError("native save lost the stuck bolt")
    capture("bolter-restored")
    issue("dk3_runtime_equip 27", 0.8)
    issue("weapon 27", 0.6)
    issue("dk3_runtime_probe_health 500")
    issue("dk3_look 0 45")
    issue("+attack", 0.05)
    issue("-attack", 0.3)
    issue("save grenade_fuse", 0.2)
    before = len(log.read_text(errors="replace"))
    issue("load grenade_fuse", 0.3)
    issue("dk3_runtime_projectiles")
    impact_frame("cordite-detonation", 27, before)
    issue("viewpos", 0.5)
    issue("dk3_runtime_projectiles")
    text = log.read_text(errors="replace")[before:]
    if "saved world restored" not in text or not re.search(r"projectile: weapon=27 exploded age=3\d\d\d bounces=[1-9]", text):
        raise RuntimeError("Cordite did not resume its saved bouncing/fuse state and explode")
    capture("cordite-restored-detonation")
    text = log.read_text(errors="replace")
    if "missing weapon animation" in text or "could not find sounds/" in text.lower():
        raise RuntimeError("missing ballistic weapon media")
    return {"attacks": results, "scope": "Bolter/Sidewinder normal fire damage, Bolter world stick and save restoration, Cordite bounce/fuse restoration and blast dispatch; diagnostic targets/equipment, full flight/water/actor/visual parity remains open"}


def grenade_contact_scenario(issue, capture, log):
    issue("developer 1")
    issue("dk3_runtime_probe_health 500")
    issue("dk3_runtime_equip 27", 0.6)
    issue("weapon 27", 0.6)
    issue("dk3_runtime_face_target 166", 0.2)
    placement = re.findall(r"zig combat: fixture player=([\d.,-]+) target=166", log.read_text(errors="replace"))
    if not placement:
        raise RuntimeError("no clear standing point near guard 166")
    player = list(map(float, placement[-1].split(',')))
    before = len(log.read_text(errors="replace"))
    for _ in range(40):
        issue("dk3_runtime_actors", 0.05)
        samples = re.findall(r"zig actor: id=166 state=\w+ health=(-?\d+) pos=([\d.,-]+)", log.read_text(errors="replace"))
        if not samples or int(samples[-1][0]) <= 0:
            break
        target = list(map(float, samples[-1][1].split(',')))
        dx, dy, dz = target[0] - player[0], target[1] - player[1], target[2] + 8 - (player[2] + 22)
        issue(f"dk3_look {math.degrees(math.atan2(dy, dx))} {-math.degrees(math.atan2(dz, math.hypot(dx, dy)))}", 0.05)
        issue("+attack", 0.1)
    issue("-attack", 0.3)
    text = log.read_text(errors="replace")[before:]
    ages = re.findall(r"projectile: weapon=27 exploded age=(\d+)", text)
    if not any(int(age) < 1000 for age in ages) or "impact: weapon=27 kind=flesh" not in text:
        raise RuntimeError("Cordite did not detonate on the authored actor before its fuse")
    if not re.search(r"combat: target=166 blood=[1-9]", text):
        raise RuntimeError("Cordite actor contact did not damage the guard")
    capture("cordite-actor-contact")
    return {"explosion_ages_ms": list(map(int, ages)), "scope": "normal Cordite attacks detonate on an authored guard and apply blast damage before fuse expiry; diagnostic positioning/equipment, complete actor/campaign parity open"}


def melee_scenario(issue, capture, log, process):
    def progression():
        issue("dk3_runtime_progression", 0.1)
        samples = re.findall(r"progression state: experience=(\d+) sword=(\d+) level=(\d+) points=(\d+)", log.read_text(errors="replace"))
        if not samples:
            raise RuntimeError("missing progression state")
        return tuple(map(int, samples[-1]))

    def actor(identity):
        issue("dk3_runtime_actors", 0.04)
        samples = re.findall(rf"zig actor: id={identity} state=\w+ health=(-?\d+) pos=([\d.,-]+)", log.read_text(errors="replace"))
        if not samples:
            raise RuntimeError(f"missing authored melee target {identity}")
        return int(samples[-1][0]), list(map(float, samples[-1][1].split(',')))

    issue("developer 1")
    initial = progression()
    results = []
    for weapon, identity in ((15, 10), (8, 9)):
        issue(f"dk3_runtime_equip {weapon}", 0.7)
        issue(f"weapon {weapon}", 0.7)
        before = len(log.read_text(errors="replace"))
        for _ in range(50):
            health, _ = actor(identity)
            if health <= 0:
                break
            # Collision-checked setup follows the moving civilian. Damage still
            # comes exclusively from ordinary attack input and class strike timing.
            issue(f"dk3_runtime_face_target {identity} 48", 0.04)
            placements = re.findall(rf"fixture player=([\d.,-]+) target={identity}", log.read_text(errors="replace"))
            if not placements:
                raise RuntimeError("no close standing point for melee scenario")
            player = list(map(float, placements[-1].split(',')))
            _, target = actor(identity)
            dx, dy = target[0] - player[0], target[1] - player[1]
            issue(f"dk3_look {math.degrees(math.atan2(dy, dx))} 0", 0.04)
            issue("+attack", 0.15)
        issue("-attack", 0.4)
        health, _ = actor(identity)
        text = log.read_text(errors="replace")[before:]
        if health > 0 or not re.search(rf"melee: weapon={weapon} .*hit=1", text):
            raise RuntimeError(f"melee weapon {weapon} did not kill authored actor {identity}")
        results.append({"weapon": weapon, "actor": identity, "health": health, "progression": progression()})
        capture(f"melee-{weapon}-victim")
    after = progression()
    if after[0] <= initial[0] or results[0]["progression"][1] != initial[1] or after[1] <= initial[1]:
        raise RuntimeError("melee kills failed ordinary/sword experience ownership")
    issue("save melee_rewards", 0.1)
    issue("load melee_rewards", 0.3)
    if progression() != after:
        raise RuntimeError("restored dead actors changed kill rewards")

    # Save between the two class-owned strikes of a real generated swing. No
    # selected-sequence or action-state override is used by this fixture.
    issue("dk3_look 0 65", 0.1)
    cursor = len(log.read_text(errors="replace"))
    issue("+attack", 0.02)
    selected = None
    deadline = time.monotonic() + 20
    while time.monotonic() < deadline:
        text = log.read_text(errors="replace")
        for sequence, age, identity in re.findall(r"melee: weapon=8 sequence=(\d+) strike=0 age=(\d+) hit=\d+ id=(\d+)", text[cursor:]):
            if int(sequence) & 7 == 1:
                selected = int(identity)
                break
        cursor = len(text)
        if selected is not None:
            break
        time.sleep(0.025)
    if selected is None:
        raise RuntimeError("normal sword attack did not generate its two-strike swing")
    issue("save sword_second_strike", 0.02)
    issue("-attack", 0.02)
    before = len(log.read_text(errors="replace"))
    issue("load sword_second_strike", 0.02)
    wait(process, log, lambda text: re.search(rf"melee: weapon=8 .*strike=1 .*id={selected}\b", text[before:]) is not None, 5)
    capture("sword-restored-strike")
    text = log.read_text(errors="replace")[before:]
    if "saved world restored" not in text or re.search(rf"melee: weapon=8 .*strike=0 .*id={selected}\b", text):
        raise RuntimeError("restored sword action repeated its consumed strike")
    if "zig view: weapon=8 phase=fire pose=atakb" not in text or "zig view: weapon=8 phase=ready" in text:
        raise RuntimeError("restored sword resumed damage without its matching attack pose")
    if progression() != after:
        raise RuntimeError("corpse melee or a second restore awarded repeated experience")
    text = log.read_text(errors="replace")
    for weapon in (8, 15):
        if f"zig view: weapon={weapon} phase=fire" not in text:
            raise RuntimeError(f"missing melee view animation for weapon {weapon}")
    if "missing weapon animation" in text or "could not find sounds/" in text.lower():
        raise RuntimeError("missing melee media")
    return {"kills": results, "saved_action": selected, "scope": "normal Silverclaw/Daikatana attacks against authored civilians, kill experience and persistent corpse rewards, two-strike save continuation without replay; collision-checked diagnostic placement/equipment, full arc/defense/visual parity remains open"}


def status_weapons_scenario(issue, capture, log, process, driver):
    def aim(identity, radius, flat=False):
        cursor = len(log.read_text(errors="replace"))
        issue(f"dk3_runtime_face_target {identity} {radius}", 0.04)
        wait(process, log, lambda text: re.search(rf"fixture player=[\d.,-]+ target={identity}", text[cursor:]) is not None, 4)
        placements = re.findall(rf"fixture player=([\d.,-]+) target={identity}", log.read_text(errors="replace"))
        if not placements:
            raise RuntimeError(f"no standing point for status target {identity}")
        player = list(map(float, placements[-1].split(',')))
        cursor = len(log.read_text(errors="replace"))
        issue("dk3_runtime_actors", 0.04)
        wait(process, log, lambda text: f"zig actor: id={identity} " in text[cursor:], 4)
        samples = re.findall(rf"zig actor: id={identity} state=\w+ health=(-?\d+) pos=([\d.,-]+)", log.read_text(errors="replace"))
        if not samples:
            raise RuntimeError("missing authored status target")
        target = list(map(float, samples[-1][1].split(',')))
        dx, dy, dz = target[0] - player[0], target[1] - player[1], target[2] + 8 - (player[2] + 16)
        pitch = 0 if flat else -math.degrees(math.atan2(dz, math.hypot(dx, dy)))
        issue(f"dk3_look {math.degrees(math.atan2(dy, dx))} {pitch}", 0.04)
        return int(samples[-1][0])

    issue("developer 1")
    issue("dk3_runtime_probe_health 1000")
    issue("dk3_runtime_equip 7", 1.6)
    issue("weapon 7", 1.6)
    for _ in range(12):
        if aim(383, 48) <= 0:
            break
        issue("+attack", 0.15)
    issue("-attack", 0.6)
    if aim(383, 48) > 0:
        raise RuntimeError("Gas Hands did not kill its authored target")
    capture("gas-hands-hit")

    issue("dk3_runtime_equip 11", 0.8)
    issue("weapon 11", 0.8)
    aim(384, 64, flat=True)
    before = len(log.read_text(errors="replace"))
    issue("+attack", 0.03)
    issue("-attack", 0.3)
    wait(process, log, lambda text: "status: target=384 effect=poison" in text[before:], 4)
    issue("save venom_poison", 0.05)
    issue("load venom_poison", 0.2)
    issue("dk3_runtime_ailments", 0.05)
    capture("venom-bite-restored")
    before = len(log.read_text(errors="replace"))
    wait(process, log, lambda text: re.search(r"status tick: target=384 weapon=11 .*killed=1", text[before:]) is not None, 7)
    issue("dk3_runtime_progression", 0.05)

    issue("dk3_runtime_equip 24", 0.8)
    issue("weapon 24", 0.8)
    aim(166, 256)
    before = len(log.read_text(errors="replace"))
    issue("+attack", 0.02)
    issue("-attack", 0.02)
    wait(process, log, lambda text: "status: target=166 effect=freeze" in text[before:], 4)
    issue("dk3_look 0 -30", 0.02)  # Divert the remaining burst while preserving the live frozen target.
    issue("save kinetic_freeze", 0.05)
    issue("load kinetic_freeze", 0.2)
    issue("dk3_runtime_ailments", 0.05)
    capture("kinetic-freeze-restored")
    text = log.read_text(errors="replace")
    if not re.search(r"ailment state: id=166 mask=4 freeze=0\.[1-9]", text):
        raise RuntimeError("native save lost the guard's freezing effect")
    aim(166, 256)
    capture("kinetic-frozen-guard")
    issue("dk3_look 0 35", 0.05)
    issue("+attack", 0.2)
    capture("kinetic-flight")
    issue("-attack", 2)
    issue("dk3_runtime_equip 11", 1.2)
    issue("weapon 11", 1.2)
    aim(166, 256, flat=True)
    driver.ready(11)
    driver.fire()
    saved = driver.save("venom_launch")
    if not re.search(rb'"owner":\d+,"weapon":11,"sequence":\d+,"charge":\d+,"execute_ms":', saved.read_bytes()):
        raise RuntimeError("Venom launch fixture did not save a pending release")
    before = len(driver.text())
    driver.load("venom_launch")
    deadline = time.monotonic() + 5
    released = False
    while time.monotonic() < deadline:
        state = driver.diagnostics("dk3_runtime_projectiles", "projectile states complete")
        evidence = driver.text()[before:]
        released = "weapon=11 stuck=0" in state or ("target=166 blood=30" in evidence and "impact: weapon=11 kind=flesh" in evidence)
        if released:
            break
    if not released:
        raise RuntimeError("saved Venomous launch produced neither flight nor confirmed contact")
    capture("venom-release-restored")
    issue("dk3_look 0 50", 0.7)
    before = len(log.read_text(errors="replace"))
    issue("+attack", 0.03)
    issue("-attack", 0.4)
    pools = []
    deadline = time.monotonic() + 6
    while time.monotonic() < deadline:
        issue("dk3_runtime_projectiles", 0.1)
        pools = re.findall(r"projectile state: id=(\d+) weapon=11 stuck=0 resting=1 .*position=([\d.,-]+)", log.read_text(errors="replace")[before:])
        if pools:
            break
    if not pools:
        raise RuntimeError("Venomous did not settle into a contact pool")
    issue("save venom_pool", 0.05)
    issue("load venom_pool", 0.1)
    cursor = len(log.read_text(errors="replace"))
    issue("viewpos", 0.05)
    wait(process, log, lambda text: "zig viewpos:" in text[cursor:], 4)
    position = re.findall(r"zig viewpos: ([^,]+),", log.read_text(errors="replace"))[-1]
    player = list(map(float, position.split()))
    x, y, z = map(float, pools[-1][1].split(','))
    dx, dy, dz = x - player[0], y - player[1], z - (player[2] + 22)
    issue(f"dk3_look {math.degrees(math.atan2(dy, dx))} {-math.degrees(math.atan2(dz, math.hypot(dx, dy)))}", 0.1)
    capture("venom-pool-restored")
    before = len(log.read_text(errors="replace"))
    issue(f"dk3_runtime_place {x} {y} {z + 22}", 0.2)
    issue("dk3_runtime_ailments", 0.1)
    if not re.search(r"status: target=\d+ effect=poison .*weapon=11", log.read_text(errors="replace")[before:]):
        raise RuntimeError("restored poison pool did not poison its owner on contact")
    capture("venom-pool-contact")
    text = log.read_text(errors="replace")
    if "missing weapon animation" in text or "could not find sounds/" in text.lower():
        raise RuntimeError("missing status-weapon media")
    return {"scope": "Gas Hands kill, Venomous bite/poison death, saved delayed launch and restored pool contact, Kineticore freeze/save and flight; ordinary attack input with diagnostic equipment/placement, complete water/trail/reference acceptance open"}


def zeus_scenario(issue, capture, log, process, home):
    def diagnostic():
        cursor = len(log.read_text(errors="replace"))
        issue("dk3_runtime_beams", 0.03)
        wait(process, log, lambda text: "beam states complete" in text[cursor:], 3)
        return log.read_text(errors="replace")[cursor:]

    issue("developer 1")
    issue("dk3_runtime_probe_health 10000")
    issue("dk3_runtime_equip 14", 0.8)
    issue("weapon 14", 0.8)
    cursor = len(log.read_text(errors="replace"))
    issue("dk3_runtime_face_target 9 128", 0.03)
    wait(process, log, lambda text: "target=9" in text[cursor:], 3)
    player = list(map(float, re.findall(r"fixture player=([\d.,-]+)", log.read_text(errors="replace")[cursor:])[-1].split(',')))
    dx, dy, dz = 288 - player[0], -152 - player[1], -64 - player[2] - 22
    issue(f"dk3_look {math.degrees(math.atan2(dy, dx))} {-math.degrees(math.atan2(dz, math.hypot(dx, dy)))}", 0.03)
    cursor = len(log.read_text(errors="replace"))
    issue("+attack", 0.03)
    issue("-attack", 0.03)
    pending = diagnostic()
    if "phase=pending" not in pending or "weapon=14 ammo=5" not in pending:
        raise RuntimeError("Zeus consumed ammunition before target selection")
    issue("save zeus_pending", 0.03)
    issue("load zeus_pending", 0.03)
    wait(process, log, lambda text: "dk3 zig zeus: strike" in text[cursor:], 5)
    issue("save zeus_chain", 0.03)
    saved = home / "state/dk3/saves/zeus_chain.sav"
    wait(process, log, lambda _: saved.exists(), 3)
    if b'zeus_bolt' not in saved.read_bytes():
        raise RuntimeError("active Zeus bolts were omitted from the native save")
    issue("load zeus_chain", 0.03)
    capture("zeus-active-restored")
    wait(process, log, lambda text: "zeus: closed" in text[cursor:], 6)
    text = log.read_text(errors="replace")[cursor:]
    for target in (9, 10):
        if not re.search(rf"target={target} .*killed=1", text):
            raise RuntimeError(f"Zeus chain failed to kill authored worker {target}")
    state = diagnostic()
    if "weapon=14 ammo=4" not in state:
        raise RuntimeError("Zeus chain charged more than one round")
    capture("zeus-closed")
    issue("-attack", 5.5)
    issue("+attack", 0.03)
    issue("-attack", 2.2)
    state = diagnostic()
    if "weapon=14 ammo=4" not in state:
        raise RuntimeError("single-player Zeus miss incorrectly consumed ammunition")
    capture("zeus-no-target")
    return {"scope": "Zeus saved pending strike and active chain, two authored worker kills, one ammo charge, closure and single-player miss; diagnostic equipment and placement"}


def meteors_scenario(issue, capture, log, process, home):
    def diagnostic(command, marker):
        cursor = len(log.read_text(errors="replace"))
        issue(command, 0.03)
        wait(process, log, lambda text: marker in text[cursor:], 3)
        return log.read_text(errors="replace")[cursor:]

    def face(target, radius, point, pitch_adjust=0):
        placement = diagnostic(f"dk3_runtime_face_target {target} {radius}", f"target={target}")
        player = list(map(float, re.findall(r"fixture player=([\d.,-]+)", placement)[-1].split(',')))
        dx, dy, dz = point[0] - player[0], point[1] - player[1], point[2] - player[2] - 22
        issue(f"dk3_look {math.degrees(math.atan2(dy, dx))} {-math.degrees(math.atan2(dz, math.hypot(dx, dy))) + pitch_adjust}", 0.03)

    issue("developer 1")
    issue("dk3_runtime_probe_health 10000")
    issue("dk3_runtime_equip 17", 0.8)
    issue("weapon 17", 0.8)
    face(383, 160, (-1180, 1310, -288))
    cursor = len(log.read_text(errors="replace"))
    issue("+attack", 0.03)
    issue("-attack", 0.12)
    issue("save meteor_growing", 0.03)
    issue("load meteor_growing", 0.03)
    capture("meteor-growing-restored")
    wait(process, log, lambda text: "stavros: exploded fragment=0" in text[cursor:], 6)
    issue("save meteor_fragments", 0.03)
    issue("load meteor_fragments", 0.03)
    fragments = diagnostic("dk3_runtime_projectiles", "projectile states complete")
    capture("meteor-fragments-restored")
    wait(process, log, lambda text: bool(re.search(r"target=383 .*killed=1", text[cursor:])), 5)
    issue("-attack", 6.2)
    if "stavros state:" in diagnostic("dk3_runtime_projectiles", "projectile states complete"):
        raise RuntimeError("meteor fragments did not expire")

    issue("dk3_runtime_equip 10", 0.8)
    issue("weapon 10", 0.8)
    face(384, 128, (168, 1096, -160), 22.5)
    cursor = len(log.read_text(errors="replace"))
    issue("+attack", 0.03)
    issue("-attack", 0.03)
    wait(process, log, lambda text: "sunflare: burning" in text[cursor:], 5)
    issue("imagelist", 0.03)
    issue("shaderlist", 0.03)
    issue("r_picmip", 0.03)
    capture("sunflare-media-close")
    issue("+back", 0.4)
    issue("-back", 0.03)
    capture("sunflare-media-distance")
    return {"scope": "Stavros saved growth, primary blast, fragment save/expiry and worker kill; Sunflare close/distant material captures with renderer media diagnostics", "restored_fragment_observed": "fragment=1" in fragments}


def returning_fire_scenario(issue, capture, log, process, home):
    def diagnostic(command, marker):
        cursor = len(log.read_text(errors="replace"))
        issue(command, 0.03)
        wait(process, log, lambda text: marker in text[cursor:], 3)
        return log.read_text(errors="replace")[cursor:]

    def face(target, radius, point, pitch_adjust=0):
        placement = diagnostic(f"dk3_runtime_face_target {target} {radius}", f"target={target}")
        player = list(map(float, re.findall(r"fixture player=([\d.,-]+)", placement)[-1].split(',')))
        dx, dy, dz = point[0] - player[0], point[1] - player[1], point[2] - player[2] - 22
        issue(f"dk3_look {math.degrees(math.atan2(dy, dx))} {-math.degrees(math.atan2(dz, math.hypot(dx, dy))) + pitch_adjust}", 0.03)

    issue("developer 1")
    issue("dk3_runtime_probe_health 10000")
    issue("dk3_runtime_equip 9", 0.8)
    issue("weapon 9", 0.8)
    face(383, 64, (-1180, 1310, -288))
    cursor = len(log.read_text(errors="replace"))
    issue("+attack", 0.03)
    issue("-attack", 0.03)
    issue("save discus_melee", 0.03)
    issue("load discus_melee", 0.5)
    issue("+attack", 0.7)
    issue("-attack", 0.1)
    wait(process, log, lambda text: bool(re.search(r"target=383 .*killed=1", text[cursor:])), 4)
    capture("discus-melee")

    face(166, 256, (-448, 1080, -160))
    issue("dk3_runtime_probe_health 35 166", 0.03)
    cursor = len(log.read_text(errors="replace"))
    issue("+attack", 0.03)
    issue("-attack", 0.03)
    issue("save discus_pending", 0.03)
    issue("load discus_pending", 0.2)
    issue("save discus_flight", 0.03)
    issue("load discus_flight", 0.03)
    capture("discus-flight-restored")
    wait(process, log, lambda text: "dk3 zig discus: caught" in text[cursor:], 8)
    if not re.search(r"target=166 .*killed=1", log.read_text(errors="replace")[cursor:]):
        raise RuntimeError("returning Discus failed to hit the authored guard")
    capture("discus-caught")

    issue("dk3_runtime_equip 10", 0.8)
    issue("weapon 10", 0.8)
    face(384, 128, (168, 1096, -160), 22.5)
    cursor = len(log.read_text(errors="replace"))
    issue("+attack", 0.03)
    issue("-attack", 0.03)
    issue("save sunflare_pending", 0.03)
    issue("load sunflare_pending", 0.03)
    wait(process, log, lambda text: "sunflare: burning" in text[cursor:], 5)
    first = diagnostic("dk3_runtime_projectiles", "projectile states complete")
    states = re.findall(r"sunflare state: id=(\d+) phase=burning flames=(\d+)", first)
    if not states:
        raise RuntimeError("Sunflare failed to create a burning field")
    identity, flames = states[-1]
    issue("save sunflare_active", 0.03)
    issue("load sunflare_active", 0.03)
    restored = diagnostic("dk3_runtime_projectiles", "projectile states complete")
    if f"sunflare state: id={identity} phase=burning flames={flames}" not in restored:
        raise RuntimeError("Sunflare flame field changed identity/count after restoration")
    capture("sunflare-active-restored")
    wait(process, log, lambda text: bool(re.search(r"target=384 .*killed=1", text[cursor:])), 6)
    issue("-attack", 5.3)
    cooling = diagnostic("dk3_runtime_projectiles", "projectile states complete")
    if f"sunflare state: id={identity} phase=cooling" not in cooling:
        raise RuntimeError("Sunflare did not stop damage for its final cooldown")
    capture("sunflare-cooling")
    issue("-attack", 5.1)
    if f"sunflare state: id={identity}" in diagnostic("dk3_runtime_projectiles", "projectile states complete"):
        raise RuntimeError("Sunflare did not expire")
    text = log.read_text(errors="replace")
    if "missing weapon animation" in text or "could not find sounds/" in text.lower():
        raise RuntimeError("missing Discus/Sunflare media")
    return {"scope": "saved Discus melee, throw, authored guard hit/catch; saved Sunflare release/field, worker kill, cooling and expiry; diagnostic equipment, placement and guard health"}


def beams_scenario(issue, capture, log, process, home):
    def diagnostic(command, marker):
        cursor = len(log.read_text(errors="replace"))
        issue(command, 0.03)
        wait(process, log, lambda text: marker in text[cursor:], 3)
        return log.read_text(errors="replace")[cursor:]

    issue("developer 1")
    issue("dk3_runtime_probe_health 10000")
    issue("dk3_runtime_equip 25", 0.8)
    issue("weapon 25", 0.8)
    placement = diagnostic("dk3_runtime_face_target 383 128", "target=383")
    player = list(map(float, re.findall(r"fixture player=([\d.,-]+)", placement)[-1].split(',')))
    dx, dy, dz = -1180 - player[0], 1310 - player[1], -288 - player[2] - 22
    issue(f"dk3_look {math.degrees(math.atan2(dy, dx))} {-math.degrees(math.atan2(dz, math.hypot(dx, dy)))}", 0.03)
    cursor = len(log.read_text(errors="replace"))
    issue("+attack", 0.03)
    issue("-attack", 0.03)
    issue("save nova_pending", 0.03)
    issue("load nova_pending", 0.03)
    wait(process, log, lambda text: "novabeam:" in text[cursor:] and "phase=firing" in text[cursor:], 4)
    first = diagnostic("dk3_runtime_beams", "beam states complete")
    state = re.findall(r"nova state: id=(\d+) phase=firing remaining=([\d.]+)", first)
    if not state:
        raise RuntimeError("Novabeam did not begin its saved pending discharge")
    identity, remaining = state[-1][0], float(state[-1][1])
    issue("save nova_active", 0.03)
    issue("load nova_active", 0.03)
    resumed = diagnostic("dk3_runtime_beams", "beam states complete")
    restored = re.findall(rf"nova state: id={identity} phase=firing remaining=([\d.]+)", resumed)
    if not restored or float(restored[-1]) > remaining:
        raise RuntimeError("Novabeam restarted its spent damage after restoration")
    capture("novabeam-active-restored")
    wait(process, log, lambda text: f"novabeam: id={identity} phase=finished" in text, 4)
    capture("novabeam-finished")
    if not re.search(r"target=383 .*killed=1", log.read_text(errors="replace")[cursor:]):
        raise RuntimeError("Novabeam failed to kill its authored target")
    issue("-attack", 1.3)
    if f"nova state: id={identity}" in diagnostic("dk3_runtime_beams", "beam states complete"):
        raise RuntimeError("Novabeam controller outlived its cooldown")

    issue("dk3_runtime_equip 28", 0.8)
    issue("weapon 28", 0.8)
    capture("flashlight-off")
    issue("+attack", 0.4)
    state = diagnostic("dk3_runtime_beams", "beam states complete")
    if "flashlight state:" not in state:
        raise RuntimeError("held flashlight did not create its light")
    capture("flashlight-on")
    issue("save flashlight_active", 0.03)
    saved = home / "state/dk3/saves/flashlight_active.sav"
    wait(process, log, lambda _: saved.exists(), 3)
    if b'flashlight' not in saved.read_bytes():
        raise RuntimeError("flashlight controller was omitted from save")
    issue("load flashlight_active", 0.1)
    capture("flashlight-restored")
    issue("-attack", 0.3)
    if "flashlight state:" in diagnostic("dk3_runtime_beams", "beam states complete"):
        raise RuntimeError("released flashlight did not expire")
    capture("flashlight-released")
    text = log.read_text(errors="replace")
    if "missing weapon animation" in text or "could not find sounds/" in text.lower():
        raise RuntimeError("missing beam/light media")
    return {"scope": "Novabeam saved release, authored kill, spent burst restoration, closure/cooldown; held flashlight, native save and release expiry; diagnostic equipment and placement"}


def linked_projectiles_scenario(issue, capture, log, process, home):
    def diagnostic(command, marker):
        cursor = len(log.read_text(errors="replace"))
        issue(command, 0.03)
        wait(process, log, lambda text: marker in text[cursor:], 3)
        return log.read_text(errors="replace")[cursor:]

    def face(identity, radius=128):
        placement = diagnostic(f"dk3_runtime_face_target {identity} {radius}", f"target={identity}")
        player = list(map(float, re.findall(r"fixture player=([\d.,-]+)", placement)[-1].split(',')))
        actors = diagnostic("dk3_runtime_actors", f"zig actor: id={identity}")
        target = list(map(float, re.findall(rf"zig actor: id={identity} .*pos=([\d.,-]+)", actors)[-1].split(',')))
        dx, dy, dz = target[0] - player[0], target[1] - player[1], target[2] + 8 - player[2] - 22
        issue(f"dk3_look {math.degrees(math.atan2(dy, dx))} {-math.degrees(math.atan2(dz, math.hypot(dx, dy)))}", 0.03)
        return player

    issue("developer 1")
    issue("dk3_runtime_probe_health 10000")
    issue("dk3_runtime_equip 13", 0.8)
    issue("weapon 13", 0.8)
    face(383)
    cursor = len(log.read_text(errors="replace"))
    issue("+attack", 0.03)
    issue("-attack", 0.4)
    hits = log.read_text(errors="replace")[cursor:]
    if not re.search(r"target=383 .*killed=1", hits):
        raise RuntimeError("Trident's three close tips did not kill worker 383")
    capture("trident-close-impact")

    issue("dk3_runtime_equip 18", 0.8)
    issue("weapon 18", 0.8)
    face(384, 64)
    issue("dk3_runtime_probe_health 500 384")  # Keep a supplied actor alive to observe transport/pinning.
    cursor = len(log.read_text(errors="replace"))
    issue("+attack", 0.03)
    issue("-attack", 0.03)
    issue("save ballista_release", 0.03)
    issue("load ballista_release", 0.03)
    wait(process, log, lambda text: re.search(r"ballista: bolt=\d+ victim=384", text[cursor:]), 4)
    issue("save ballista_victim", 0.03)
    saved = home / "state/dk3/saves/ballista_victim.sav"
    wait(process, log, lambda _: saved.exists(), 3)
    if b'"victim":384' not in saved.read_bytes():
        raise RuntimeError("Ballista fixture did not capture an active carried actor")
    restored_at = len(log.read_text(errors="replace"))
    issue("load ballista_victim", 0.03)
    state = diagnostic("dk3_runtime_projectiles", "projectile states complete")
    restored = log.read_text(errors="replace")[restored_at:]
    if not re.search(r"ballista state: .*victim=384", state) and not re.search(r"ballista: removed=\d+ explode=1 releases=1", restored):
        raise RuntimeError("Ballista lost its carried actor across save/load")
    capture("ballista-victim-restored")
    issue("-attack", 2.5)
    state = diagnostic("dk3_runtime_projectiles", "projectile states complete")
    if re.search(r"ballista state: .*victim=384", state):
        raise RuntimeError("Ballista failed to release its actor")

    issue("dk3_runtime_equip 13", 0.8)
    issue("weapon 13", 0.8)
    best = None
    for identity in (166, 383, 384):
        placement = diagnostic(f"dk3_runtime_face_target {identity} 256", f"target={identity}")
        point = re.findall(r"fixture player=([\d.,-]+)", placement)[-1]
        lane = diagnostic("dk3_runtime_shot_lanes", "shot lane:")
        yaw, pitch, clearance = map(float, re.findall(r"shot lane: yaw=([\d.-]+) pitch=([\d.-]+) clearance=([\d.-]+)", lane)[-1])
        if best is None or clearance > best[0]:
            best = (clearance, point, yaw, pitch)
    if best[0] < 800:
        raise RuntimeError(f"linked-projectile fixture has no clear merge lane: {best}")
    issue("dk3_runtime_place " + best[1].replace(',', ' '), 0.03)
    issue(f"dk3_look {best[2]} {best[3]}", 0.03)
    cursor = len(log.read_text(errors="replace"))
    issue("+attack", 0.03)
    issue("-attack", 0.03)
    issue("save trident_linked", 0.03)
    issue("load trident_linked", 0.03)
    wait(process, log, lambda text: "merged age=" in text[cursor:], 4)
    capture("trident-merged")
    issue("-attack", 0.5)
    if not re.search(r"trident: impact=\d+ charged=1", log.read_text(errors="replace")[cursor:]):
        raise RuntimeError("restored linked tips did not produce a charged impact")
    # Reuse the measured unobstructed lane to exercise Shockwave's trail media.
    issue("dk3_runtime_equip 6", 0.8)
    issue("weapon 6", 0.8)
    issue("dk3_runtime_place " + best[1].replace(',', ' '), 0.03)
    issue(f"dk3_look {best[2]} {best[3]}", 0.03)
    issue("+attack", 0.03)
    issue("-attack", 1.95)
    capture("shockwave-open-trail")
    text = log.read_text(errors="replace")
    if "missing weapon animation" in text or "could not find sounds/" in text.lower():
        raise RuntimeError("missing linked-projectile media")
    return {"scope": "Trident close kill, saved group merge/charged impact, saved Ballista release and carried actor/release, Shockwave trail; diagnostic equipment/placement and 500-health worker", "lane": best}


def shockwave_scenario(issue, capture, log, process):
    def diagnostic(command, marker):
        cursor = len(log.read_text(errors="replace"))
        issue(command, 0.03)
        wait(process, log, lambda text: marker in text[cursor:], 3)
        return log.read_text(errors="replace")[cursor:]

    def aim(player, target):
        dx, dy, dz = target[0] - player[0], target[1] - player[1], target[2] - player[2] - 22
        issue(f"dk3_look {math.degrees(math.atan2(dy, dx))} {-math.degrees(math.atan2(dz, math.hypot(dx, dy)))}", 0.03)

    issue("developer 1")
    issue("dk3_runtime_probe_health 10000")
    issue("dk3_runtime_equip 6", 0.8)
    issue("weapon 6", 0.8)
    placement = diagnostic("dk3_runtime_face_target 383 128", "target=383")
    player = list(map(float, re.findall(r"fixture player=([\d.,-]+)", placement)[-1].split(',')))
    actors = diagnostic("dk3_runtime_actors", "zig actor: id=383")
    target = list(map(float, re.findall(r"zig actor: id=383 .*pos=([\d.,-]+)", actors)[-1].split(',')))
    target[2] += 8
    aim(player, target)
    cursor = len(log.read_text(errors="replace"))
    issue("+attack", 0.03)
    issue("-attack", 0.03)
    issue("save shock_release", 0.03)
    issue("load shock_release", 0.08)
    capture("shockwave-release-restored")
    wait(process, log, lambda text: "shockwave: center=" in text[cursor:], 5)
    text = log.read_text(errors="replace")[cursor:]
    if not re.search(r"target=383 .*killed=1", text):
        raise RuntimeError("saved Shockwave release did not hit the authored worker")
    center = re.findall(r"shockwave: center=(\d+)", text)[-1]
    initial = diagnostic("dk3_runtime_area_weapons", "area weapon states complete")
    if f"shockwave state: id={center}" not in initial:
        raise RuntimeError("Shockwave did not retain its expanding bands")
    capture("shockwave-first-ring")
    issue("save shock_bands", 0.03)
    issue("load shock_bands", 0.08)
    restored = diagnostic("dk3_runtime_area_weapons", "area weapon states complete")
    state = re.findall(rf"shockwave state: id={center} age=(\d+) rings=(\d+) .*position=([\d.,-]+)", restored)
    if not state:
        raise RuntimeError("saved Shockwave bands did not resume")
    issue(f"dk3_runtime_place {player[0]} {player[1]} {player[2]}", 0.03)
    aim(player, list(map(float, state[-1][2].split(','))))
    capture("shockwave-bands-restored")
    wait(process, log, lambda text: f"shockwave: center={center} rings=6" in text, 5)
    capture("shockwave-six-rings")
    issue("dk3_runtime_inventory", 0.1)
    issue("-attack", 3.4)
    if f"shockwave state: id={center}" in diagnostic("dk3_runtime_area_weapons", "area weapon states complete"):
        raise RuntimeError("Shockwave did not remove its completed controller")

    issue("dk3_runtime_place -998.981 1491.019 -295.875", 0.1)
    issue("dk3_look 135 -10", 0.1)
    cursor = len(log.read_text(errors="replace"))
    issue("+attack", 0.03)
    issue("-attack", 1.58)
    samples = diagnostic("dk3_runtime_projectiles", "projectile states complete")
    flying = re.findall(r"projectile state: id=(\d+) weapon=6", samples)
    if flying:
        issue("save shock_orb", 0.03)
        issue("load shock_orb", 0.08)
        capture("shockwave-orb-restored")
    wait(process, log, lambda text: "shockwave: center=" in text[cursor:], 10)
    capture("shockwave-ricochet-blast")
    text = log.read_text(errors="replace")
    if "missing weapon animation" in text or "could not find sounds/" in text.lower():
        raise RuntimeError("missing Shockwave media")
    return {"scope": "saved delayed Shockwave release, authored direct kill, persistent six-band expansion and completion, restored waves, wall-flight detonation; ordinary attacks with diagnostic equipment/placement", "orb_save_observed": bool(flying)}


def attached_charge_scenario(issue, capture, log, process):
    def charge_state():
        cursor = len(log.read_text(errors="replace"))
        issue("dk3_runtime_area_weapons", 0.03)
        wait(process, log, lambda text: "area weapon states complete" in text[cursor:], 3)
        values = re.findall(r"charge state: id=(\d+) attached=(\d+) .*parent=(\d+) position=([\d.,-]+)", log.read_text(errors="replace")[cursor:])
        if len(values) != 1:
            raise RuntimeError(f"expected one attached lift charge: {values}")
        identity, attached, parent, position = values[0]
        return identity, attached, parent, list(map(float, position.split(',')))

    issue("developer 1")
    issue("dk3_runtime_probe_health 10000")
    issue("dk3_runtime_equip 3", 0.8)
    issue("weapon 3", 0.8)
    issue("dk3_runtime_place 818.916 -479.481 -823.875", 0.2)
    issue("dk3_look 0 75", 0.1)
    issue("+attack", 0.03)
    issue("-attack", 0.1)
    first = charge_state()
    if first[1:3] != ("1", "3"):
        raise RuntimeError(f"C4 did not attach to bigplat: {first}")
    # Move outside proximity range while leaving the charge on the lift.
    issue(f"dk3_runtime_face_target {first[0]} 256", 0.1)
    issue("dk3_runtime_activate 3", 0.3)
    second = charge_state()
    if second[3][2] <= first[3][2] + 10:
        raise RuntimeError("C4 did not follow the moving lift")
    issue("save attached_charge", 0.03)
    issue("load attached_charge", 0.08)
    restored = charge_state()
    if restored[:3] != first[:3] or restored[3][2] < second[3][2]:
        raise RuntimeError("saved C4 mover attachment did not resume")
    capture("c4-lift-restored")
    issue("weapon 3", 0.2)
    wait(process, log, lambda text: f"charge: id={first[0]} exploded" in text, 3)
    return {"scope": "C4 attached to authored bigplat, moved with lift, saved/restored attachment and remote detonation; diagnostic standing position/activation"}


def area_weapons_scenario(issue, capture, log, process):
    def diagnostics():
        cursor = len(log.read_text(errors="replace"))
        issue("dk3_runtime_area_weapons", 0.03)
        wait(process, log, lambda text: "area weapon states complete" in text[cursor:], 3)
        return log.read_text(errors="replace")[cursor:]

    def charges():
        return re.findall(r"charge state: id=(\d+) attached=(\d+) .*position=([\d.,-]+)", diagnostics())

    def place_near(identity, distance=256, minimum=0):
        cursor = len(log.read_text(errors="replace"))
        issue(f"dk3_runtime_face_target {identity} {distance} {minimum}", 0.03)
        wait(process, log, lambda text: f"target={identity}" in text[cursor:], 3)
        point = re.findall(rf"fixture player=([\d.,-]+) target={identity}", log.read_text(errors="replace")[cursor:])
        if not point:
            raise RuntimeError("area-weapon fixture has no clear standing point")
        return list(map(float, point[-1].split(',')))

    def look_at(player, target):
        dx, dy, dz = target[0] - player[0], target[1] - player[1], target[2] - player[2] - 22
        issue(f"dk3_look {math.degrees(math.atan2(dy, dx))} {-math.degrees(math.atan2(dz, math.hypot(dx, dy)))}", 0.03)

    issue("developer 1")
    issue("dk3_runtime_probe_health 10000")
    issue("dk3_runtime_equip 3", 0.8)
    issue("weapon 3", 0.8)
    place_near(383, 128)
    # The placement keeps the authored target visible; orient through normal input.
    issue("dk3_runtime_actors", 0.1)
    worker = re.findall(r"zig actor: id=383 state=\w+ health=(-?\d+) pos=([\d.,-]+)", log.read_text(errors="replace"))[-1]
    player = place_near(383, 128)
    target = list(map(float, worker[1].split(',')))
    target[2] += 8
    look_at(player, target)
    cursor = len(log.read_text(errors="replace"))
    issue("+attack", 0.03)
    issue("-attack", 0.5)
    wait(process, log, lambda text: "target=383" in text[cursor:] and "killed=1" in text[cursor:], 5)
    capture("c4-contact")
    issue("dk3_runtime_place -998.981 1491.019 -295.875", 0.1)
    issue("dk3_look 0 60", 1.1)
    issue("+attack", 0.03)
    issue("-attack", 0.1)
    found = charges()
    if not found or found[-1][1] != "1":
        raise RuntimeError("C4 did not attach to the floor")
    charge_id = found[-1][0]
    issue("save c4_attached", 0.03)
    issue("load c4_attached", 0.08)
    if not any(row[0] == charge_id and row[1] == "1" for row in charges()):
        raise RuntimeError("C4 attachment was lost in native save")
    cursor = len(log.read_text(errors="replace"))
    issue("weapon 3", 0.04)  # Ordinary reselect presses the remote detonator.
    capture("c4-remote-button")
    wait(process, log, lambda text: f"charge: id={charge_id} exploded" in text[cursor:], 3)

    issue("dk3_look 0 60", 1.2)
    issue("+attack", 0.03)
    issue("-attack", 0.1)
    found = charges()
    if not found:
        raise RuntimeError("missing charge for shot-triggered detonation")
    charge_id, attached, position = found[-1]
    player = place_near(charge_id, minimum=160)
    point = list(map(float, position.split(',')))
    issue("dk3_runtime_equip 21", 0.8)
    issue("weapon 21", 0.8)
    look_at(player, point)
    cursor = len(log.read_text(errors="replace"))
    issue("+attack", 0.04)
    issue("-attack", 0.2)
    wait(process, log, lambda text: f"charge: id={charge_id} exploded" in text[cursor:], 3)
    capture("c4-shot-detonation")

    issue("dk3_runtime_equip 3", 0.8)
    issue("weapon 3", 0.8)
    issue("dk3_look 0 60", 0.1)
    issue("+attack", 0.03)
    issue("-attack", 0.1)
    first = charges()[-1]
    player = place_near(first[0], minimum=160)
    point = list(map(float, first[2].split(',')))
    aim = point.copy()
    aim[1] += 40
    aim[2] += 40  # Compensate for the thrown charge's gravity over this distance.
    look_at(player, aim)
    issue("-attack", 1.4)
    issue("+attack", 0.03)
    issue("-attack", 0.5)
    found = charges()
    if len(found) != 2 or not all(row[1] == "1" for row in found):
        raise RuntimeError(f"chain fixture did not retain two attached charges: {found}")
    player = place_near(found[-1][0], minimum=160)
    point = list(map(float, found[-1][2].split(',')))
    issue("save c4_chain", 0.03)
    issue("load c4_chain", 0.1)
    issue("dk3_runtime_equip 21", 0.8)
    issue("weapon 21", 0.8)
    look_at(player, point)
    cursor = len(log.read_text(errors="replace"))
    issue("+attack", 0.04)
    issue("-attack", 0.4)
    wait(process, log, lambda text: len(re.findall(r"zig charge: id=\d+ exploded", text[cursor:])) == 2, 3)
    if "chain=2" not in log.read_text(errors="replace")[cursor:]:
        raise RuntimeError("C4 chain did not amplify its initiating blast")
    capture("c4-restored-chain")

    issue("dk3_runtime_equip 12", 0.8)
    issue("weapon 12", 0.8)
    place_near(384, 64)
    issue("dk3_look 180 0", 0.1)
    cursor = len(log.read_text(errors="replace"))
    issue("+attack", 0.4)
    issue("-attack", 0.03)
    issue("save hammer_strike", 0.03)
    issue("load hammer_strike", 0.08)
    if "hammer state:" not in diagnostics():
        raise RuntimeError("Hammer's pending strike was not restored")
    wait(process, log, lambda text: "zig hammer: strike" in text[cursor:] and "quake=0" in text[cursor:], 3)
    capture("hammer-partial-strike")
    issue("dk3_look 180 65", 0.8)
    cursor = len(log.read_text(errors="replace"))
    issue("+attack", 2)
    capture("hammer-full-charge")
    issue("-attack", 0.03)
    wait(process, log, lambda text: "charge=1800" in text[cursor:] and "quake=1" in text[cursor:], 3)
    capture("hammer-quake")
    issue("save hammer_quake", 0.03)
    issue("load hammer_quake", 0.08)
    states = diagnostics()
    if not re.search(r"hammer state: .*quake_remaining=[1-9]\d+", states):
        raise RuntimeError("saved Hammer quake did not resume")
    capture("hammer-quake-restored")
    issue("dk3_runtime_actors", 0.2)
    text = log.read_text(errors="replace")
    if not re.search(r"target=90 .*killed=1", text):
        raise RuntimeError("Hammer quake did not kill the visible nearby guard")
    worker = re.findall(r"zig actor: id=384 state=\w+ health=(-?\d+)", text)
    if not worker or not 0 < int(worker[-1]) < 50:
        raise RuntimeError("Hammer's full quake ignored the obstruction protecting the injured worker")
    issue("dk3_runtime_inventory", 0.2)
    text = log.read_text(errors="replace")
    if "missing weapon animation" in text or "could not find sounds/" in text.lower():
        raise RuntimeError("missing area-weapon media")
    return {"scope": "C4 contact kill, saved attachment, remote reselect, shooting detonation and saved chain amplification; Hammer saved partial strike, charged quake, visible guard kill, occluded worker protection and quake save; ordinary attacks with diagnostic equipment/placement"}


def save_scenario(issue, capture, log, home):
    def inventory():
        issue("dk3_runtime_inventory")
        values = re.findall(r"zig inventory .*health=(-?\d+) armor=(\d+)", log.read_text(errors="replace"))
        if not values:
            raise RuntimeError("missing saved-player diagnostics")
        return list(map(int, values[-1]))

    def position():
        issue("viewpos", 0.05)
        values = re.findall(r"zig viewpos: ([^,]+),", log.read_text(errors="replace"))
        return list(map(float, values[-1].split()))

    def saved(slot):
        path = home / f"state/dk3/saves/{slot}.sav"
        if not path.exists():
            raise RuntimeError(f"native save not written: {log}")
        return path

    issue("dk3_runtime_place 818.916 -479.481 -823.875", 0.5)
    issue("dk3_runtime_probe_health 100")
    issue("dk3_runtime_equip 21")
    issue("dk3_runtime_activate 3", 0.7)
    issue("save native_lift", 0.1)
    saved("native_lift")
    initial = position()
    capture("lift-saved")
    issue("dk3_runtime_damage 40", 2)
    moved = position()
    if inventory()[0] != 60 or math.dist(initial, moved) < 50:
        raise RuntimeError("save fixture failed to change health and lift position")
    issue("load native_lift", 0.1)
    restored = position()
    if inventory()[0] != 100 or math.dist(initial, restored) > 32:
        raise RuntimeError(f"mid-lift state not restored: {initial}, {restored}")
    capture("lift-restored")
    issue("save quick")
    issue("dk3_runtime_damage 40")
    issue("save quick")
    saved("quick")
    issue("load quick previous")
    if inventory()[0] != 100:
        raise RuntimeError("previous native save was not recovered")
    damaged = bytearray(saved("quick").read_bytes())
    damaged[-1] ^= 1
    (home / "state/dk3/saves/damaged.sav").write_bytes(damaged)
    before = len(log.read_text(errors="replace"))
    issue("load damaged")
    if inventory()[0] != 100 or "Save/load refused: Checksum" not in log.read_text(errors="replace")[before:]:
        raise RuntimeError("corrupt save changed the live world or lacked a checksum diagnostic")
    issue("dk3_runtime_trains")
    capture("corruption-refused")
    return {"saved_position": initial, "moved_position": moved, "restored_position": restored,
            "scope": "native mid-lift world/player restoration, atomic previous-save recovery and corruption rejection; diagnostic placement/activation/damage; original schema-5 migration, other mid-action states and menu load remain open"}


def civilians_scenario(issue, capture, log):
    def actors():
        issue("dk3_runtime_actors", 0.05)
        result = {}
        for identity, mode, health, position, threat, witness in re.findall(
                r"zig actor: id=(\d+) state=(\w+) health=(-?\d+) pos=([\d.,-]+) threat=(\d+) witness=(-?\d+)",
                log.read_text(errors="replace")):
            result[int(identity)] = {"state": mode, "health": int(health), "position": list(map(float, position.split(','))),
                                     "threat": int(threat), "witness": int(witness)}
        return result
    issue("developer 1")
    issue("cl_debugMove 3")
    initial = actors()
    issue("dk3_runtime_face_target 10", 0.3)
    placement = re.findall(r"zig combat: fixture player=([\d.,-]+) target=10", log.read_text(errors="replace"))
    if not placement:
        raise RuntimeError("no clear standing point near authored worker 10")
    player = list(map(float, placement[-1].split(',')))
    issue("dk3_runtime_equip 21")
    issue("dk3_runtime_inventory")
    issue("viewpos")
    capture("workers-before")
    latest = initial
    for _ in range(70):
        latest = actors()
        if latest[10]["health"] <= 0:
            break
        target = latest[10]["position"]
        dx, dy, dz = target[0] - player[0], target[1] - player[1], target[2] + 8 - (player[2] + 22)
        yaw = math.degrees(math.atan2(dy, dx))
        pitch = -math.degrees(math.atan2(dz, math.hypot(dx, dy)))
        issue(f"dk3_look {yaw} {pitch}", 0.05)
        issue("+attack", 0.1)
    issue("-attack", 0.2)
    issue("dk3_runtime_inventory")
    issue("viewpos")
    after = actors()
    capture("worker-death-witness")
    if after[10]["health"] > 0 or after[10]["state"] != "dead":
        raise RuntimeError(f"authored worker 10 did not die: {after[10]}")
    if after[9]["state"] != "flee" or after[9]["witness"] < 0:
        raise RuntimeError(f"nearby worker 9 did not witness the killing: {after[9]}")
    if math.dist(after[9]["position"], initial[9]["position"]) < 1:
        issue("dk3_runtime_actors", 0.5)
        after = actors()
    return {"before": {str(i): initial[i] for i in (9, 10)}, "after": {str(i): after[i] for i in (9, 10)},
            "scope": "e1m2a authored civilian bodies, normal Glock input, death and witness panic; diagnostic player positioning/equipment, navigation and full actor parity unqualified"}


# e1m3a civilians: worker 25 stands idle with no work script; plain prisoner 462 has no
# spawnflags, plain prisoner 318 carries 128 (do not move).
HIDING_WORKER = 25
ALERTED_PRISONER = 462
STILL_PRISONER = 318


def workers_scenario(issue, capture, log):
    issue("developer 1")
    issue("cl_debugMove 3")
    # A worker that sees the player runs (runa) and then cowers (gamba 692-711 or gambc 720-727).
    worker = HIDING_WORKER
    issue("dk3_runtime_place 1600 -400 -120 180", 0.3)
    deadline = time.monotonic() + 12
    text = ""
    while time.monotonic() < deadline:
        issue(f"dk3_runtime_projections monster_skinnyworker", 0.05)
        issue("dk3_runtime_actors", 0.3)
        text = log.read_text(errors="replace")
        if re.search(rf"zig actor: id={worker} state=idle .*worker=cower", text):
            break
    if not re.search(rf"zig actor: id={worker} state=flee ", text):
        raise RuntimeError(f"worker {worker} did not hide from the player in sight")
    if not re.search(rf"worker: fear voice id={worker} |zig actor: id={worker} .*worker=cower", text):
        raise RuntimeError(f"worker {worker} did not cower")
    issue("dk3_runtime_projections monster_skinnyworker", 0.4)
    frames = [int(value) for value in re.findall(rf"dk3 projection: id={worker} .*? frame=(\d+)", log.read_text(errors="replace"))]
    cowering = [frame for frame in frames if 692 <= frame <= 711 or 720 <= frame <= 727]
    if not cowering:
        raise RuntimeError(f"worker {worker} showed no cower clip: {frames[-12:]}")
    capture("worker-cower")
    # A plain prisoner never flees: hurt by the player, he calls out and wanders (walka 260-279).
    prisoner = ALERTED_PRISONER
    # The player's attack input does not reach the server from the probe pipe (open), so the
    # player hurts him through the normal damage path instead.
    still = STILL_PRISONER
    for identity in (prisoner, still):
        issue(f"dk3_runtime_probe_health 1000 {identity}")
        issue(f"dk3_runtime_hurt {identity} 10", 0.3)
    deadline = time.monotonic() + 12
    while time.monotonic() < deadline:
        issue("dk3_runtime_projections monster_prisoner", 0.05)
        issue("dk3_runtime_actors", 0.3)
    text = log.read_text(errors="replace")
    states = re.findall(rf"zig actor: id={prisoner} state=(\w+) health=(-?\d+)", text)
    if not states or int(states[-1][1]) >= 1000:
        raise RuntimeError(f"prisoner {prisoner} was not hurt")
    if any(state == "flee" for state, _ in states):
        raise RuntimeError(f"prisoner {prisoner} fled; plain prisoners never do")
    if not re.search(rf"zig actor: id={prisoner} state=chase .*roam=", text):
        raise RuntimeError(f"alerted prisoner {prisoner} did not wander")
    still_states = re.findall(rf"zig actor: id={still} state=(\w+) health=(-?\d+) pos=([\d.,-]+) threat=(\d+)", text)
    if not still_states or int(still_states[-1][3]) == 0 or len({position for _, _, position, _ in still_states}) != 1:
        raise RuntimeError(f"do-not-move prisoner {still} was not alerted in place: {still_states[-1:]}")
    walking = [int(value) for value in re.findall(rf"dk3 projection: id={prisoner} .*? frame=(\d+)", text) if 260 <= int(value) <= 279]
    if not walking:
        raise RuntimeError(f"prisoner {prisoner} wandered without walka")
    capture("prisoner-wander")
    return {"worker": worker, "cower_frames": cowering[:8], "prisoner": prisoner, "walk_frames": walking[:8],
            "scope": "e1m3a worker sight hide, run and cower clip; plain prisoner hurt by the player (diagnostic damage) wanders with walka and never flees; work scripts and Gold timing parity unqualified"}


# e1m2b skinny worker 51 carries spawnflag 4 (node wander).
WANDERING_WORKER = 51


def worker_wander_scenario(issue, capture, log):
    issue("developer 1")
    worker = WANDERING_WORKER
    deadline = time.monotonic() + 10
    while time.monotonic() < deadline:
        issue("dk3_runtime_projections monster_skinnyworker", 0.05)
        issue("dk3_runtime_actors", 0.3)
    text = log.read_text(errors="replace")
    states = re.findall(rf"zig actor: id={worker} state=(\w+) health=-?\d+ pos=([\d.,-]+)", text)
    walking = [list(map(float, position.split(','))) for state, position in states if state == "chase"]
    if len(walking) < 2 or math.dist(walking[0][:2], walking[-1][:2]) < 32:
        raise RuntimeError(f"worker {worker} did not wander: {states[-3:]}")
    frames = [int(value) for value in re.findall(rf"dk3 projection: id={worker} .*? frame=(\d+)", text) if 983 <= int(value) <= 1002]
    if not frames:
        raise RuntimeError(f"worker {worker} wandered without walka")
    capture("worker-wander")
    return {"worker": worker, "travel": round(math.dist(walking[0][:2], walking[-1][:2]), 1), "walk_frames": frames[:8],
            "scope": "e1m2b spawnflag-4 worker node wander with walka; leg choice and timing parity unqualified"}


# e1m3a surgeon 471 (SRGNasta, spawnflag 16) assists at the operating table, ignoring the player;
# its scripts are brief one-shots (SRGNfyst and the others loop theirs, and a working surgeon is
# blind, so after its cower it returns to work).
CALM_SURGEON = 471


def surgeon_scenario(issue, capture, log):
    issue("developer 1")
    surgeon = CALM_SURGEON
    # It ignores the player beside it until he hurts it; then it cowers in place (gamba 540-559 or
    # gambc 568-575) and, after its ten-second reconsider with the player close and in sight, runs
    # from him (runa 576-589) and cowers again where it stops.
    issue("dk3_runtime_place 2010 -388 -470 0", 0.3)
    issue("dk3_runtime_probe_health 10000")
    for _ in range(12):
        issue("dk3_runtime_actors", 0.25)
    text = log.read_text(errors="replace")
    if re.search(rf"zig actor: id={surgeon} state=flee ", text) or not re.search(rf"zig actor: id={surgeon} .* surgeon=calm", text):
        raise RuntimeError(f"surgeon {surgeon} did not ignore the player")
    issue(f"dk3_runtime_probe_health 1000 {surgeon}")
    issue(f"dk3_runtime_hurt {surgeon} 5", 0.3)
    deadline = time.monotonic() + 40
    while time.monotonic() < deadline:
        issue("dk3_runtime_projections monster_surgeon", 0.05)
        issue("dk3_runtime_actors", 0.3)
        text = log.read_text(errors="replace")
        hid = re.search(rf"zig actor: id={surgeon} state=flee .* surgeon=hide", text)
        if hid and re.search(rf"zig actor: id={surgeon} .* surgeon=cower", text[hid.end():]):
            break
    text = log.read_text(errors="replace")
    rows = re.findall(rf"zig actor: id={surgeon} state=(\w+) .*?now=(\d+).* surgeon=(\w+)", text)
    hurt_at = next((int(now) for _, now, phase in rows if phase == "cower"), None)
    hide_at = next((int(now) for state, now, phase in rows if phase == "hide"), None)
    if hurt_at is None:
        raise RuntimeError(f"surgeon {surgeon} did not cower when hurt: {rows[-3:]}")
    if hide_at is None or hide_at - hurt_at < 9500:
        raise RuntimeError(f"surgeon {surgeon} did not hide after its reconsider delay: cower={hurt_at} hide={hide_at}")
    frames = [int(value) for value in re.findall(rf"dk3 projection: id={surgeon} .*? frame=(\d+)", text)]
    cowering = [frame for frame in frames if 540 <= frame <= 559 or 568 <= frame <= 575]
    running = [frame for frame in frames if 576 <= frame <= 589]
    if not cowering or not running:
        raise RuntimeError(f"surgeon {surgeon} clips: cower={cowering[:4]} run={running[:4]}")
    # Monster clips play at the reference's 20 fps.
    rates = set(re.findall(rf"dk3 projection: id={surgeon} .* rate=(\d+)", text))
    if rates != {"20"}:
        raise RuntimeError(f"surgeon {surgeon} clip rates {rates}")
    capture("surgeon-hide")
    return {"surgeon": surgeon, "cower_ms": hurt_at, "hide_ms": hide_at, "cower_frames": cowering[:8], "run_frames": running[:8],
            "scope": "e1m3a surgeon ignores the player until hurt (diagnostic damage), cowers in place, then after the reconsider delay hides from the player in sight and cowers again; hide-node choice and Gold timing parity unqualified"}


def lasergat_scenario(issue, capture, log):
    issue("developer 1")
    issue("dk3_runtime_probe_health 10000")
    # A lasergat that sees the player turns onto him and fires once per shot cycle: its clip runs
    # 500 ms to its last frame (the reference cycle), never faster. A turret spawned in the start
    # hall, 160 units ahead of the player and above him, has him in sight.
    issue("dk3_runtime_actor_spawn monster_lasergat -576 184 180 90", 0.5)
    fixtures = re.findall(r"actor fixture: id=(\d+)", log.read_text(errors="replace"))
    if not fixtures:
        raise RuntimeError("lasergat fixture did not spawn")
    turret = int(fixtures[-1])
    deadline = time.monotonic() + 15
    while time.monotonic() < deadline:
        issue("dk3_runtime_actors", 0.4)
    text = log.read_text(errors="replace")
    identity = turret
    times = [int(now) for now in re.findall(rf"lasergat: id={turret} fired now=(\d+)", text)]
    gaps = [after - before for before, after in zip(times, times[1:])]
    if len(times) < 4 or min(gaps) < 500:
        raise RuntimeError(f"lasergat {identity} shot cycle: {times[:12]}")
    capture("lasergat-fire")
    # Hits from its enemy stall it now and then (75%, at most once per 500 ms): the cycle restarts
    # after a 100 ms pause, so the next shot comes at least 300 ms after the stall.
    issue(f"dk3_runtime_probe_health 10000 {turret}")
    for _ in range(8):
        issue(f"dk3_runtime_hurt {turret} 1", 0.7)
    text = log.read_text(errors="replace")
    stalls = [int(now) for now in re.findall(rf"lasergat: id={turret} stalled now=(\d+)", text)]
    after = [int(now) for now in re.findall(rf"lasergat: id={turret} fired now=(\d+)", text)]
    if not stalls:
        raise RuntimeError(f"lasergat {turret} never stalled when hurt")
    for stall in stalls:
        following = [shot for shot in after if shot > stall]
        if following and following[0] - stall < 300:
            raise RuntimeError(f"lasergat {turret} fired {following[0] - stall} ms after a stall")
    return {"lasergat": identity, "shots": len(times), "gaps": gaps[:10], "stalls": len(stalls),
            "scope": "e1m4a lasergat fixture turns onto the player and fires at its 500 ms cycle; hits from the player stall and restart the cycle; unseen tracking unqualified in game"}


def fight_and_flinch(issue, capture, log, pain, name, rounds=14):
    """For each class in `pain` (classname -> its hita frames), one at a time: spawn it south of
    the e2m1a start, check it attacks the player, land small diagnostic hits until it flinches
    with its hita, then kill it so it cannot block the next one's approach."""
    issue("developer 1")
    issue("dk3_runtime_probe_health 10000")
    fixtures, flinched = {}, {}
    for classname, frames_of_pain in pain.items():
        for x, y in ((-580, 1272), (-460, 1272), (-520, 1192), (-640, 1192), (-400, 1192), (-520, 1112)):
            text = log.read_text(errors="replace")
            issue(f"dk3_runtime_actor_spawn {classname} {x} {y} 1440 90 e2m1a 1 ground", 0.4)
            found = re.findall(rf"actor fixture: id=(\d+) class={classname} .* grounded=1", log.read_text(errors="replace")[len(text):])
            if found:
                identity = fixtures[classname] = int(found[-1])
                break
        else:
            raise RuntimeError(f"no clear spot for {classname}")
        mark = len(log.read_text(errors="replace"))
        deadline = time.monotonic() + 12
        while time.monotonic() < deadline:
            issue("dk3_runtime_actors", 0.4)
            if re.search(rf"zig actor: id={identity} state=attack ", log.read_text(errors="replace")[mark:]):
                break
        text = log.read_text(errors="replace")[mark:]
        if not re.search(rf"zig actor: id={identity} state=attack ", text):
            raise RuntimeError(f"{classname} {identity} never attacked: {re.findall(rf'zig actor: id={identity} state=(\w+)', text)[-3:]}")
        issue(f"dk3_runtime_probe_health 10000 {identity}")
        for _ in range(rounds):
            issue(f"dk3_runtime_hurt {identity} 1", 0.05)
            for _ in range(4):
                issue(f"dk3_runtime_projections {classname}", 0.05)
        text = log.read_text(errors="replace")[mark:]
        frames = [int(value) for value in re.findall(rf"dk3 projection: id={identity} .*? frame=(\d+)", text)]
        flinched[classname] = [frame for frame in frames if frame in frames_of_pain][:6]
        if not flinched[classname]:
            raise RuntimeError(f"{classname} {identity} never flinched: {frames[-12:]}")
        issue(f"dk3_runtime_probe_health 1 {identity}")
        issue(f"dk3_runtime_hurt {identity} 1000", 0.5)
    capture(name)
    return fixtures, flinched


def e2_melee_scenario(issue, capture, log):
    # A spider and a skeleton fight the player and flinch with their hita (skeleton 244-253,
    # generic 20% rolls; spider 81-100, one 75% roll) once the acquiring hit has made him their enemy.
    fixtures, flinched = fight_and_flinch(issue, capture, log, {"monster_spider": range(81, 101), "monster_skeleton": range(244, 254)}, "e2-melee")
    return {"fixtures": fixtures, "pain_frames": flinched,
            "scope": "e2m1a skeleton and spider fixtures attack the player and flinch with hita under diagnostic hits; attack choice, leap and Gold timing parity unqualified"}


def e4_fighters_scenario(issue, capture, log):
    # A lab monkey (hita 296-315), a femgang (hita 143-158) and a rocketdude (hita 200-219), all
    # on the generic pain handler, fight the player and flinch under diagnostic hits.
    fixtures, flinched = fight_and_flinch(issue, capture, log, {"monster_labmonkey": range(296, 316), "monster_femgang": range(143, 159), "monster_rocketdude": range(200, 220)}, "e4-fighters", rounds=30)
    return {"fixtures": fixtures, "pain_frames": flinched,
            "scope": "e2m1a lab monkey, femgang and rocketdude fixtures attack the player and flinch with hita under diagnostic hits; leaps, hops, evasion, rockets and Gold timing parity unqualified"}


def e4_gunfighters_scenario(issue, capture, log):
    # A rocket MP (hita 140-159), a white prisoner (310-324), a seal captain (173-187) and a
    # chaingang (360-369, one 75% roll; its AI starts 2.2 s after spawning) fight the player
    # and flinch under diagnostic hits.
    fixtures, flinched = fight_and_flinch(issue, capture, log, {"monster_rocketmp": range(140, 160), "monster_whiteprisoner": range(310, 325), "monster_sealcaptain": range(173, 188), "monster_chaingang": range(360, 370)}, "e4-gunfighters", rounds=30)
    return {"fixtures": fixtures, "pain_frames": flinched,
            "scope": "e2m1a rocket MP, white prisoner, seal captain and chaingang fixtures attack the player and flinch with hita under diagnostic hits; rockets, rocks, bursts, flight and Gold timing parity unqualified"}


def e3_creatures_scenario(issue, capture, log):
    # A lycanthir (generic pain 15%, limit 35; hita 227-241) and a plague rat (generic pain 25%,
    # limit 35; hita 145-153) fight the player and flinch under diagnostic hits.
    fixtures, flinched = fight_and_flinch(issue, capture, log, {"monster_lycanthir": range(227, 242), "monster_plague_rat": range(145, 154)}, "e3-creatures", rounds=24)
    return {"fixtures": fixtures, "pain_frames": flinched,
            "scope": "e2m1a lycanthir and plague rat fixtures attack the player and flinch with hita under diagnostic hits; leaps, evasion, resurrection and Gold timing parity unqualified"}


def rats_scenario(issue, capture, log):
    """Each rat spawned about 200 units from the player on a diagonal must close in and bite: the
    player's health drops (a leap alone never damages)."""
    issue("developer 1")
    deadline = time.monotonic() + 15
    origin = [0.0, 0.0, 0.0]
    while origin == [0.0, 0.0, 0.0] and time.monotonic() < deadline:
        issue("viewpos", 0.5)
        origin = [float(value) for value in re.findall(r"zig viewpos: (-?[\d.]+) (-?[\d.]+) (-?[\d.]+)", log.read_text(errors="replace"))[-1]]
    results = {}
    for classname in ("monster_plague_rat", "monster_piperat"):
        issue("dk3_runtime_probe_health 1000")
        for dx, dy in ((140, 140), (-140, 140), (140, -140), (-140, -140), (200, 0), (0, 200), (-200, 0), (0, -200)):
            text = log.read_text(errors="replace")
            issue(f"dk3_runtime_actor_spawn {classname} {origin[0] + dx:.0f} {origin[1] + dy:.0f} {origin[2] + 16:.0f} 0 e2m1a 1 ground", 0.4)
            found = re.findall(rf"actor fixture: id=(\d+) class={classname} .* grounded=1", log.read_text(errors="replace")[len(text):])
            if found:
                identity = int(found[-1])
                break
        else:
            raise RuntimeError(f"no clear spot for {classname}")
        mark = len(log.read_text(errors="replace"))
        deadline = time.monotonic() + 15
        bitten = None
        while time.monotonic() < deadline and bitten is None:
            issue("dk3_runtime_inventory", 0.3)
            issue("dk3_runtime_actors", 0.2)
            health = re.findall(r"zig inventory .*health=(-?\d+)", log.read_text(errors="replace")[mark:])
            if health and int(health[-1]) < 1000:
                bitten = int(health[-1])
        text = log.read_text(errors="replace")[mark:]
        states = re.findall(rf"zig actor: id={identity} state=(\w+) health=-?\d+ pos=([\d.,-]+)", text)
        if bitten is None:
            raise RuntimeError(f"{classname} {identity} never bit the player: {states[:2]} .. {states[-2:]}")
        results[classname] = {"id": identity, "health": bitten, "first": states[0] if states else None, "last": states[-1] if states else None}
        capture(f"bitten-{classname}")
        issue(f"dk3_runtime_probe_health 1 {identity}")
        issue(f"dk3_runtime_hurt {identity} 1000", 0.5)
    return {"rats": results, "scope": "e2m1a plague and pipe rat fixtures spawned about 200 units off on a diagonal close in and bite the player (health drop); nest routing off the player areas and Gold timing parity unqualified"}


def e3_knights_scenario(issue, capture, log):
    issue("developer 1")
    issue("dk3_runtime_probe_health 10000")
    # A lightning knight has no melee clip: within 80 units it runs in place (runa 209-224) and
    # punches once per loop. A dwarf beside it chops or throws. Both are spawned south of the
    # e2m1a start; the player is then placed beside the knight.
    fixtures = {}
    for classname in ("monster_knight2", "monster_dwarf"):
        for x, y in ((-580, 1272), (-460, 1272), (-520, 1192), (-640, 1192), (-400, 1192), (-520, 1112)):
            if any(spot == (x, y) for spot in fixtures.values()):
                continue
            text = log.read_text(errors="replace")
            issue(f"dk3_runtime_actor_spawn {classname} {x} {y} 1440 90 e2m1a 1 ground", 0.4)
            found = re.findall(rf"actor fixture: id=(\d+) class={classname} .* grounded=1", log.read_text(errors="replace")[len(text):])
            if found:
                fixtures[classname] = (x, y)
                fixtures[classname + "#"] = int(found[-1])
                break
        else:
            raise RuntimeError(f"no clear spot for {classname}")
    knight = fixtures["monster_knight2#"]
    dwarf = fixtures["monster_dwarf#"]
    issue("dk3_runtime_actors", 0.4)
    position = re.findall(rf"zig actor: id={knight} state=\w+ health=-?\d+ pos=(-?[\d.]+),(-?[\d.]+),(-?[\d.]+)", log.read_text(errors="replace"))
    if not position:
        raise RuntimeError(f"knight {knight} position unknown")
    x, y, z = (float(value) for value in position[-1])
    issue(f"dk3_runtime_place {x} {y + 60} {z + 24}", 0.5)
    deadline = time.monotonic() + 10
    while time.monotonic() < deadline:
        issue("dk3_runtime_actors", 0.2)
        issue("dk3_runtime_projections monster_knight2", 0.2)
    text = log.read_text(errors="replace")
    for identity, classname in ((knight, "monster_knight2"), (dwarf, "monster_dwarf")):
        if not re.search(rf"zig actor: id={identity} state=attack ", text):
            raise RuntimeError(f"{classname} {identity} never attacked: {re.findall(rf'zig actor: id={identity} state=(\w+)', text)[-3:]}")
    frames = [int(value) for value in re.findall(rf"dk3 projection: id={knight} .*? frame=(\d+)", text)]
    running = [frame for frame in frames if 209 <= frame <= 224]
    if not running:
        raise RuntimeError(f"knight2 {knight} never ran in place: {frames[-12:]}")
    capture("e3-knights")
    return {"knight2": knight, "dwarf": dwarf, "runa_frames": running[:8],
            "scope": "knight2 beside the player plays its in-place runa punch and attacks; a dwarf attacks; zap, axe flight and Gold timing parity unqualified"}


# e1m3b guards: 65 has no spawnflags (eight-round cycle, chases); 90 carries spawnflag 512
# (fights from cover: one shot per two seconds, no rounds, hide nodes, never chases).
CYCLE_GUARD = 65
COVER_GUARD = 90
# Unflagged guard whose seeded pursuit leads around occlusion into a firing position (65's
# fixture stalls at a corner on every build).
PURSUIT_GUARD = 380


def guard_scenario(issue, capture, log):
    identity = CYCLE_GUARD
    issue("developer 1")
    issue("dk3_runtime_probe_health 1000")
    issue(f"dk3_runtime_face_target {identity}", 0.3)
    placement = re.findall(rf"zig combat: fixture player=([\d.,-]+) target={identity}", log.read_text(errors="replace"))
    if not placement:
        raise RuntimeError(f"no clear standing point near guard {identity}")
    issue("dk3_runtime_actors")
    if not re.search(rf"zig actor: id={identity} state=", log.read_text(errors="replace")):
        raise RuntimeError("guard did not spawn")
    capture("guard-sighting")
    deadline = time.monotonic() + 25
    text = ""
    while time.monotonic() < deadline:
        issue("dk3_runtime_inventory", 0.4)
        text = log.read_text(errors="replace")
        if f"guard: id={identity} reload sound dispatched" in text:
            break
    shots = [int(value) for value in re.findall(rf"guard: id={identity} fired rounds=(\d+)", text)]
    health = re.findall(r"zig inventory .*health=(-?\d+)", text)
    if shots[:8] != list(range(7, -1, -1)) or f"guard: id={identity} reload sound dispatched" not in text:
        raise RuntimeError(f"guard did not complete eight rounds and reload: {shots}")
    if not health or int(health[-1]) >= 1000:
        raise RuntimeError("guard fire did not damage the player")
    capture("guard-reload")
    # The cover guard: seen from the stairs above it, it shoots without spending rounds, at most
    # once per two seconds, and picks a hide node the player cannot see.
    cover = COVER_GUARD
    issue("dk3_runtime_place 312 1048 -60 180", 0.3)
    deadline = time.monotonic() + 14
    while time.monotonic() < deadline:
        issue("dk3_runtime_actors", 0.4)
    text = log.read_text(errors="replace")
    cover_shots = [int(value) for value in re.findall(rf"guard: id={cover} fired rounds=(\d+)", text)]
    # Shot times from the fire events themselves (sampled phases are 0.4 s apart).
    starts = [int(value) for value in re.findall(rf"guard: id={cover} fired rounds=\d+ enemy=\d+ now=(\d+)", text)]
    if len(cover_shots) < 3 or set(cover_shots) != {8} or f"guard: id={cover} reload sound dispatched" in text:
        raise RuntimeError(f"cover guard spent rounds or did not fire: {cover_shots}")
    if any(b - a < 1900 for a, b in zip(starts, starts[1:])):
        raise RuntimeError(f"cover guard fired faster than its two-second cooldown: {starts}")
    if not re.search(rf"zig actor: id={cover} state=chase .*cover=", text):
        raise RuntimeError("cover guard never ran for a hide node")
    capture("guard-cover")
    return {"guard": identity, "rounds": shots, "player_health": int(health[-1]), "cover_guard": cover, "cover_shots": len(cover_shots),
            "scope": "e1m3b unflagged guard eight-round cycle, reload and player damage; spawnflag-512 guard cover shots (no rounds, two-second cooldown) and hide-node run; diagnostic placement/1000 health, pain and full actor parity unqualified"}


def sidekick_talk_scenario(issue, capture, log):
    issue("developer 1")
    issue("dk3_runtime_probe_health 10000")
    # e3m1a starts with both sidekicks. The player stands on Superfly's opening talk node 85,
    # 101 units from where Superfly starts; following him, Superfly reaches it with the player
    # near and in sight and says its line (e3m1_sf_01a) once.
    deadline = time.monotonic() + 8
    while time.monotonic() < deadline:
        issue("dk3_runtime_actors", 0.5)
        if re.search(r"zig actor: id=\d+ .*class=superfly", log.read_text(errors="replace")):
            break
    if not re.search(r"zig actor: id=\d+ .*class=superfly", log.read_text(errors="replace")):
        raise RuntimeError("Superfly is not in e3m1a")
    issue("dk3_runtime_place -3416 -522 -208 0", 0.5)
    deadline = time.monotonic() + 20
    while time.monotonic() < deadline:
        issue("dk3_runtime_actors", 0.5)
        if "companion talk: superfly says" in log.read_text(errors="replace"):
            break
    said = re.findall(r"companion talk: (\w+) says (\S+)", log.read_text(errors="replace"))
    if not any(who == "superfly" for who, _ in said):
        raise RuntimeError(f"no authored sidekick line was said: {said}")
    capture("sidekick-talk")
    return {"lines": said, "scope": "e3m1a Superfly says his authored talk-node line once when he reaches the node with the player near and in sight; audibility and the other talk nodes unqualified"}


def sidekick_stop_scenario(issue, capture, log):
    """e1m4b's stop node (1089,1030,-503) makes Superfly wait where he stands while the player goes
    on; its teleport node (2022,991,-256) sends him to (1319,-508,-528) and ends the wait, and he
    follows again (reference CLIENT_HandleStopGoingFurther, CLIENT_HandleTeleportAndComeNear)."""
    issue("developer 1")
    issue("dk3_runtime_probe_health 10000")

    def superfly(after=0):
        rows = re.findall(r"dk3 sidekick: t=\d+ who=superfly [^\n]*?pos=(-?\d+),(-?\d+),(-?\d+) [^\n]* why=(\w*)", log.read_text(errors="replace")[after:])
        return [((int(x), int(y), int(z)), why) for x, y, z, why in rows]

    deadline = time.monotonic() + 10
    while time.monotonic() < deadline and not superfly():
        issue("dk3_runtime_actors", 0.5)
    if not superfly():
        issue("viewpos", 0.3)
        x, y, z = re.findall(r"zig viewpos: (-?[\d.]+) (-?[\d.]+) (-?[\d.]+)", log.read_text(errors="replace"))[-1]
        issue(f"dk3_runtime_actor_spawn superfly {float(x) + 64:.0f} {float(y):.0f} {float(z):.0f} 0 e1m4b 1 ground", 2.0)
    if not superfly():
        raise RuntimeError("Superfly is not in e1m4b")
    # Bring him along to the stop node: place the player beside it, wait for him, then step on it.
    issue("dk3_runtime_place 1089 1130 -480 0", 0.5)
    mark = len(log.read_text(errors="replace"))
    issue("dk3_runtime_place 1089 1030 -480 0", 2.0)
    if "dk3 sidekick node: stop" not in log.read_text(errors="replace")[mark:]:
        raise RuntimeError("the stop node did not fire")
    issue("dk3_runtime_place 1500 1030 -480 0", 0.5)
    mark = len(log.read_text(errors="replace"))
    time.sleep(5)
    waiting = superfly(mark)
    if not waiting or any(why != "stopped" for _, why in waiting) or math.dist(waiting[0][0], waiting[-1][0]) > 48:
        raise RuntimeError(f"Superfly did not wait at the stop: {waiting}")
    capture("superfly-waiting")
    mark = len(log.read_text(errors="replace"))
    issue("dk3_runtime_place 2022 991 -240 0", 3.0)
    if "dk3 sidekick node: teleport" not in log.read_text(errors="replace")[mark:]:
        raise RuntimeError("the teleport node did not fire")
    time.sleep(3)
    resumed = superfly(mark)
    if not resumed or resumed[-1][1] == "stopped":
        raise RuntimeError(f"the teleport node did not end the wait: {resumed}")
    capture("superfly-resumed")
    return {"waiting": waiting, "resumed": resumed, "scope": "e1m4b stop node holds Superfly while the player leaves; the teleport node sends him on and he no longer waits; the stop line's audibility and the second sidekick's stagger unqualified"}


def sidekick_water_scenario(issue, capture, log):
    """Superfly follows the player to the bottom of e1m1c's 704-unit pool for 60 s: he dives after
    the player, surfaces for air and dives again, and must not drown (his air refills at the
    surface). Every other actor is removed first, so only the water can hurt him."""
    issue("developer 1")
    issue("dk3_runtime_probe_health 10000")
    issue("dk3_runtime_actors", 0.5)
    actors = re.findall(r"zig actor: id=(\d+) state=(?!dead)\w+ [^\n]*class=(\w+)", log.read_text(errors="replace"))
    for identity in {i for i, kind in actors if kind not in ("superfly", "mikiko", "mikikofly")}:
        issue(f"dk3_runtime_probe_health 1 {identity}", 0.02)
        issue(f"dk3_runtime_hurt {identity} 1000", 0.02)
    mark = len(log.read_text(errors="replace"))
    if not any(kind == "superfly" for _, kind in actors):
        # The first clear spot in the pool, near its surface.
        for x, y in ((1744, 272), (1650, 272), (1840, 272), (1744, 180), (1744, 360), (1600, 150), (1900, 400)):
            before = len(log.read_text(errors="replace"))
            issue(f"dk3_runtime_actor_spawn superfly {x} {y} 380 0 e1m1c 1", 0.6)
            if "class=superfly" in log.read_text(errors="replace")[before:]:
                pool = (x, y)
                break
        else:
            raise RuntimeError("no clear spot for Superfly in the pool")
    else:
        pool = (1744, 272)
    # He starts in the pool beside the player and follows him to the bottom.
    bottom = f"dk3_runtime_place {pool[0]} {pool[1] - 40} -250 0"
    issue(bottom, 0.5)
    deadline = time.monotonic() + 60
    rows = []
    while time.monotonic() < deadline:
        issue(bottom, 2.0)
        rows = re.findall(r"dk3 sidekick: t=(\d+) who=superfly health=(-?\d+)/(\d+) pos=(\S+) [^\n]* water=(\d) ", log.read_text(errors="replace")[mark:])
        if rows and int(rows[-1][1]) <= 0:
            break
    submerged = sum(1 for row in rows if row[4] == "3")
    capture("superfly-pool")
    if not rows or int(rows[-1][1]) < int(rows[-1][2]):
        raise RuntimeError(f"Superfly lost health in the water: {rows[-3:]}")
    if submerged < 10:
        raise RuntimeError(f"Superfly was not held under water long enough to test: {submerged} submerged samples")
    return {"samples": len(rows), "submerged": submerged, "last": rows[-1], "scope": "e1m1c pool: Superfly follows the player under water for 60 s, surfacing and diving again, without drowning; enemies removed; the player's own air is diagnostic health"}


# Lethal-pool scenarios: brush contents (CONTENTS_SLIME 16, CONTENTS_LAVA 8, CONTENTS_DK3_NITRO 0x800).
HAZARD_SCENARIOS = {"sidekick-nitro": (0x800, "nitrogen"), "sidekick-slime": (16, "slime"), "sidekick-lava": (8, "lava")}


def hazard_volumes(engine, map_name, mask):
    """Axis-aligned bounds of the map's brushes with any of `mask`'s contents (read from the
    engine generation's converted BSP: shader content flags, axial brush sides)."""
    import struct
    import zipfile
    with zipfile.ZipFile(engine / "share/dk3/dk3-maps.pk3") as package:
        data = package.read(f"maps/{map_name}.bsp")
    lump = lambda index: struct.unpack_from("<ii", data, 8 + index * 8)
    offset, length = lump(1)
    shaders = [struct.unpack_from("<64sii", data, offset + index * 72) for index in range(length // 72)]
    offset, length = lump(2)
    planes = [struct.unpack_from("<4f", data, offset + index * 16) for index in range(length // 16)]
    offset, length = lump(8)
    brushes = [struct.unpack_from("<3i", data, offset + index * 12) for index in range(length // 12)]
    side_offset, _ = lump(9)
    volumes = []
    for first, count, shader in brushes:
        if shaders[shader][2] & mask == 0:
            continue
        low, high = [-1e9] * 3, [1e9] * 3
        for side in range(first, first + count):
            plane = planes[struct.unpack_from("<2i", data, side_offset + side * 8)[0]]
            normal, distance = plane[:3], plane[3]
            for axis in range(3):
                if abs(normal[axis] - 1) < 1e-4:
                    high[axis] = min(high[axis], distance)
                elif abs(normal[axis] + 1) < 1e-4:
                    low[axis] = max(low[axis], -distance)
        if all(abs(value) < 1e8 for value in low + high) and high[0] - low[0] >= 48 and high[1] - low[1] >= 48:
            volumes.append((tuple(low), tuple(high)))
    return volumes


def spawn_superfly_beside(issue, log, map_name):
    """Superfly beside the player (an existing one is kept): the first clear floor round the
    player's settled position. Returns his persistent id."""
    issue("dk3_runtime_actors", 0.5)
    found = re.findall(r"zig actor: id=(\d+) state=(?!dead)\w+ [^\n]*class=superfly", log.read_text(errors="replace"))
    if found:
        return found[-1]
    issue("viewpos", 0.3)
    x, y, z = (float(value) for value in re.findall(r"zig viewpos: (-?[\d.]+) (-?[\d.]+) (-?[\d.]+)", log.read_text(errors="replace"))[-1])
    for dx, dy in ((-48, 0), (48, 0), (0, -48), (0, 48), (-64, 0), (64, 0), (0, -64), (0, 64), (-40, -40), (40, 40), (-40, 40), (40, -40)):
        before = len(log.read_text(errors="replace"))
        # (Above the player's origin: Superfly's hull reaches lower; the server grounds him.)
        issue(f"dk3_runtime_actor_spawn superfly {x + dx:.0f} {y + dy:.0f} {z + 16:.0f} 0 {map_name} 1 ground", 0.6)
        spawned = re.findall(r"dk3 actor fixture: id=(\d+) class=superfly [^\n]*water=(\d+)", log.read_text(errors="replace")[before:])
        if spawned and spawned[-1][1] == "0" and abs(z - viewpos_z(issue, log, spawned[-1][0])) < 40:
            return spawned[-1][0]
        if spawned:
            # In liquid or fallen below the player's floor: not a fixture.
            issue(f"dk3_runtime_probe_health 1 {spawned[-1][0]}", 0.02)
            issue(f"dk3_runtime_hurt {spawned[-1][0]} 100000", 0.3)
    raise RuntimeError(f"no clear floor for Superfly beside the player in {map_name} at {x:.0f},{y:.0f},{z:.0f}")


def viewpos_z(issue, log, identity):
    """An actor's height from the actor listing (z of `pos=`)."""
    issue("dk3_runtime_actors", 0.4)
    found = re.findall(rf"zig actor: id={identity} [^\n]*?pos=\(?(-?[\d.]+),\s*(-?[\d.]+),\s*(-?[\d.]+)", log.read_text(errors="replace"))
    return float(found[-1][2]) if found else float("inf")


def dry_floor(issue, log, map_name, x, y, z):
    """The origin height of a player-sized body standing on dry floor under (x, y, z), probed with
    a throwaway fixture the server grounds (within 128 units) and then removes; None without one."""
    before = len(log.read_text(errors="replace"))
    issue(f"dk3_runtime_actor_spawn monster_plague_rat {x:.0f} {y:.0f} {z:.0f} 0 {map_name} 1 ground", 0.4)
    spawned = re.findall(r"dk3 actor fixture: id=(\d+) class=monster_plague_rat [^\n]*water=(\d+)", log.read_text(errors="replace")[before:])
    if not spawned:
        return None
    identity, water = spawned[-1]
    height = viewpos_z(issue, log, identity)
    issue(f"dk3_runtime_probe_health 1 {identity}", 0.02)
    issue(f"dk3_runtime_hurt {identity} 100000", 0.2)
    # (The rat's origin sits lower over its floor than a player's: 24 units for the player.)
    return None if water != "0" or not math.isfinite(height) else height


def settled_viewpos(issue, log):
    """The player's view position once it stops changing (a placement falls to the floor)."""
    last = None
    for _ in range(8):
        issue("viewpos", 0.4)
        found = re.findall(r"zig viewpos: (-?[\d.]+) (-?[\d.]+) (-?[\d.]+)", log.read_text(errors="replace"))
        current = tuple(float(value) for value in found[-1]) if found else None
        if current is not None and last is not None and math.dist(current, last) < 1:
            return current
        last = current
    return last


def sidekick_hazard_scenario(issue, capture, log, engine, map_name, mask, label):
    """Superfly follows the player along the rims of the map's lethal pools (lava, slime or
    nitrogen) for about 70 s: the player stands on the floor beside each pool's sides in turn, so
    the follow spots behind and beside him often lie over the liquid. Every other actor is removed
    and Superfly is given 10000 health: any loss is contact with the pool (nitrogen kills a party
    member three seconds after contact whatever its health)."""
    issue("developer 1")
    issue("dk3_runtime_probe_health 10000")
    volumes = hazard_volumes(engine, map_name, mask)
    if not volumes:
        raise RuntimeError(f"{map_name} has no {label} pools")
    def clear_hostiles():
        # Monsters the map spawns later (triggers, waves) are removed too: only the pools may hurt.
        before = len(log.read_text(errors="replace"))
        issue("dk3_runtime_actors", 0.4)
        actors = re.findall(r"zig actor: id=(\d+) state=(?!dead)\w+ [^\n]*class=(\w+)", log.read_text(errors="replace")[before:])
        for identity in {i for i, kind in actors if kind not in ("superfly", "mikiko", "mikikofly")}:
            issue(f"dk3_runtime_probe_health 1 {identity}", 0.02)
            issue(f"dk3_runtime_hurt {identity} 1000", 0.02)

    clear_hostiles()

    # Rim stands: 56 units out from the middle of each side of each pool, on a floor no lower
    # than the pool's top (the player must land there, not in the pool or below it).
    rims = []
    for low, high in sorted(volumes, key=lambda box: -(box[1][0] - box[0][0]) * (box[1][1] - box[0][1]))[:6]:
        middle = ((low[0] + high[0]) / 2, (low[1] + high[1]) / 2)
        for x, y, yaw in ((low[0] - 56, middle[1], 0), (high[0] + 56, middle[1], 180), (middle[0], low[1] - 56, 90), (middle[0], high[1] + 56, 270)):
            # The rim itself, or a catwalk above the pool's edge (e1m6c's rooms).
            for lift in (40, 160, 280):
                floor = dry_floor(issue, log, map_name, x, y, high[2] + lift)
                if floor is not None and floor >= high[2] - 8:
                    rims.append((x, y, floor + 32, yaw))
                    break
        if len(rims) >= 8:
            break
    if not rims:
        raise RuntimeError(f"no floor beside any {label} pool in {map_name}: {volumes[:4]}")
    first = rims[0]
    issue(f"dk3_runtime_place {first[0]:.0f} {first[1]:.0f} {first[2]:.0f} {first[3]}", 0.5)

    def superfly(after=0):
        rows = re.findall(r"dk3 sidekick: t=\d+ who=superfly health=(-?\d+)/(\d+) pos=(-?\d+),(-?\d+),(-?\d+) [^\n]* water=(\d) escaping=(\d) [^\n]*why=(\S*)", log.read_text(errors="replace")[after:])
        return [(int(health), (int(x), int(y), int(z)), int(water), int(escaping), why) for health, _, x, y, z, water, escaping, why in rows]

    settled_viewpos(issue, log)
    identity = spawn_superfly_beside(issue, log, map_name)
    issue(f"dk3_runtime_probe_health 10000 {identity}", 0.2)
    mark = len(log.read_text(errors="replace"))
    deadline = time.monotonic() + 70
    index = 0
    while time.monotonic() < deadline:
        rim = rims[index % len(rims)]
        issue(f"dk3_runtime_place {rim[0]:.0f} {rim[1]:.0f} {rim[2]:.0f} {rim[3]}", 3.0)
        clear_hostiles()
        index += 1
        rows = superfly(mark)
        if rows and rows[-1][0] <= 0:
            break
    rows = superfly(mark)
    capture(f"superfly-{label}")
    catchups = re.findall(r"dk3 sidekick: catch-up who=superfly reason=(\w+)", log.read_text(errors="replace")[mark:])
    if not rows:
        raise RuntimeError("no Superfly status lines")
    wet = [row for row in rows if row[2] or row[3]]
    if wet:
        raise RuntimeError(f"Superfly was in the {label}: {wet[:6]}")
    if rows[-1][0] <= 0:
        raise RuntimeError(f"Superfly died: {rows[-4:]}")
    # Lava and slime hurt every tenth of a second and nitrogen kills within three: a touch between
    # the one-second samples still shows as a large loss; small losses elsewhere (a hurting volume
    # on the way, a landing) are reported.
    lost = rows[0][0] - min(row[0] for row in rows)
    if lost >= 100:
        raise RuntimeError(f"Superfly lost {lost} health following round the {label}: {rows[-4:]}")
    return {"rims": len(rims), "pools": len(volumes), "samples": len(rows), "catch_ups": catchups, "health_lost": lost, "health": rows[-1][0], "scope": f"{map_name}: Superfly follows the player round {label} pool rims for 70 s, never in the {label} at a sample and alive; enemies removed"}


def sidekick_surface_scenario(issue, capture, log):
    """Superfly starts in e1m1c's pool while the player stands dry at the map's start: he must
    get out of the water (or be caught up) rather than sink, and never stay with his head under
    for more than 3 s while nothing calls him down."""
    issue("developer 1")
    issue("dk3_runtime_probe_health 10000")
    # Dry floor: the map's authored player start from e1m1b's side, 1200 units from the pool.
    start = (680, -152, 904)
    issue("dk3_runtime_actors", 0.5)
    actors = re.findall(r"zig actor: id=(\d+) state=(?!dead)\w+ [^\n]*class=(\w+)", log.read_text(errors="replace"))
    for identity in {i for i, kind in actors if kind not in ("superfly", "mikiko", "mikikofly")}:
        issue(f"dk3_runtime_probe_health 1 {identity}", 0.02)
        issue(f"dk3_runtime_hurt {identity} 1000", 0.02)
    existing = re.findall(r"zig actor: id=(\d+) state=(?!dead)\w+ [^\n]*class=superfly", log.read_text(errors="replace"))
    mark = len(log.read_text(errors="replace"))
    # Into the pool: the existing Superfly is sent there by placing the player in it first.
    issue("dk3_runtime_place 1744 232 300 0", 0.5)
    if not existing:
        for x, y in ((1744, 272), (1650, 272), (1840, 272), (1744, 180), (1744, 360)):
            before = len(log.read_text(errors="replace"))
            issue(f"dk3_runtime_actor_spawn superfly {x} {y} 300 0 e1m1c 1", 0.6)
            if "class=superfly" in log.read_text(errors="replace")[before:]:
                break
        else:
            raise RuntimeError("no clear spot for Superfly in the pool")
    time.sleep(8)
    mark = len(log.read_text(errors="replace"))
    issue(f"dk3_runtime_place {start[0]} {start[1]} {start[2]} 0", 0.5)
    rows = []
    deadline = time.monotonic() + 45
    while time.monotonic() < deadline:
        time.sleep(1)
        rows = re.findall(r"dk3 sidekick: t=(\d+) who=superfly health=(-?\d+)/(\d+) pos=(\S+) [^\n]* water=(\d) ", log.read_text(errors="replace")[mark:])
        if len(rows) > 5 and all(row[4] == "0" for row in rows[-5:]):
            break
    capture("superfly-surface")
    catchups = re.findall(r"dk3 sidekick: catch-up who=superfly reason=(\w+)[^\n]*", log.read_text(errors="replace")[mark:])
    if not rows:
        raise RuntimeError("no Superfly status lines")
    longest = run = 0
    for row in rows:
        run = run + 1 if row[4] == "3" else 0
        longest = max(longest, run)
    if rows[-1][4] != "0":
        raise RuntimeError(f"Superfly is still in the water after 45 s: {rows[-5:]}")
    if float(rows[-1][3].split(",")[2]) < -400:
        raise RuntimeError(f"Superfly fell out of the world: {rows[-5:]}")
    if longest > 3:
        raise RuntimeError(f"Superfly stayed under water {longest} s: {rows}")
    if int(rows[-1][1]) < int(rows[0][1]):
        raise RuntimeError(f"Superfly lost health: {rows[0][1]} -> {rows[-1][1]}")
    return {"samples": len(rows), "longest_submerged_s": longest, "catch_ups": catchups, "last": rows[-1], "scope": "e1m1c: Superfly leaves the pool for the dry player instead of sinking; catch-up may bring him when the way is long"}


def sidekick_catchup_scenario(issue, capture, log):
    """e1m4b: with Superfly beside the player, the player is moved 2850 units away, across the map:
    Superfly, further than 1536 for 3 s, must reappear near the player within 20 s, where the
    player sees neither his departure nor his arrival (logged `catch-up`)."""
    issue("developer 1")
    issue("dk3_runtime_probe_health 10000")

    def superfly(after=0):
        rows = re.findall(r"dk3 sidekick: t=\d+ who=superfly [^\n]*?pos=(-?\d+),(-?\d+),(-?\d+) [^\n]* why=(\S*)", log.read_text(errors="replace")[after:])
        return [((int(x), int(y), int(z)), why) for x, y, z, why in rows]

    issue("developer 2")

    def clear_hostiles():
        before = len(log.read_text(errors="replace"))
        issue("dk3_runtime_actors", 0.4)
        actors = re.findall(r"zig actor: id=(\d+) state=(?!dead)\w+ [^\n]*class=(\w+)", log.read_text(errors="replace")[before:])
        for identity in {i for i, kind in actors if kind not in ("superfly", "mikiko", "mikikofly")}:
            issue(f"dk3_runtime_probe_health 1 {identity}", 0.02)
            issue(f"dk3_runtime_hurt {identity} 1000", 0.02)

    clear_hostiles()
    issue("dk3_runtime_place 1089 1130 -480 0", 0.5)
    settled_viewpos(issue, log)
    # The map's own Superfly joins the player here; a fixture only without him.
    deadline = time.monotonic() + 10
    while time.monotonic() < deadline and not superfly():
        time.sleep(0.5)
    if not superfly():
        spawn_superfly_beside(issue, log, "e1m4b")
    clear_hostiles()
    time.sleep(3)
    if not superfly():
        raise RuntimeError("Superfly is not flown in e1m4b")
    # Beside the shotcycler and rockets on the far side of the map, 2850 units away.
    far = (1054, -1654, 200)
    mark = len(log.read_text(errors="replace"))
    issue(f"dk3_runtime_place {far[0]} {far[1]} {far[2]} 90", 0.5)
    landed = settled_viewpos(issue, log)
    deadline = time.monotonic() + 20
    caught = []
    while time.monotonic() < deadline:
        clear_hostiles()
        time.sleep(0.6)
        caught = re.findall(r"dk3 sidekick: catch-up who=superfly reason=(\w+) from=(\S+) to=(-?\d+),(-?\d+),(-?\d+)", log.read_text(errors="replace")[mark:])
        if caught:
            break
    time.sleep(2)
    rows = superfly(mark)
    capture("superfly-caught-up")
    if not rows:
        raise RuntimeError("no Superfly status lines")
    distance = math.dist(rows[-1][0], far)
    if not caught:
        pending = sorted(set(re.findall(r"catch-up pending who=superfly reason=(\w+) \(([^)]*)\)", log.read_text(errors="replace")[mark:])))
        raise RuntimeError(f"Superfly did not catch up: {distance:.0f} from the player at {landed}; pending {pending}; {rows[-3:]}")
    if distance > 512:
        raise RuntimeError(f"Superfly caught up but is {distance:.0f} from the player: {caught}; {rows[-3:]}")
    return {"catch_ups": caught, "final_distance": round(distance), "last": rows[-1], "scope": "e1m4b: Superfly left 2850 units behind reappears near the player out of his view; the arrival's invisibility is judged by the server's sight test, not the capture"}


def conveyor_meat_scenario(issue, capture, log):
    """e1m5a "Processing": the START_ON train `4am` carries its body parts down the belt right
    after the map loads, before any trigger (reference train_find), and then waits at slice1."""
    issue("developer 1")
    issue("dk3_runtime_probe_health 10000")
    samples = []
    deadline = time.monotonic() + 16
    while time.monotonic() < deadline:
        mark = len(log.read_text(errors="replace"))
        issue("dk3_runtime_trains", 1.0)
        row = re.findall(r"zig train id=\d+ name=4am phase=(\w+) [^\n]* pos=(-?[\d.]+),(-?[\d.]+),(-?[\d.]+)", log.read_text(errors="replace")[mark:])
        if row:
            samples.append((row[-1][0], float(row[-1][1])))
    moving = [x for phase, x in samples if phase == "moving"]
    if not moving or max(x for _, x in samples) < 400:
        raise RuntimeError(f"4am did not carry its meat down the belt after load: {samples}")
    issue("dk3_runtime_place -560 1840 -780 0", 0.3)
    issue("dk3_look 0 15", 1.0)
    capture("belt")
    return {"samples": samples, "scope": "e1m5a 4am leaves its wait-for-trigger first corner at load (START_ON) and crosses the belt; the timed chopper/pile show after the trigger is unchanged"}


def robot_gibs_scenario(issue, capture, log):
    """A lasergat destroyed in plain view: its mechanical chunks render (they now use the scripted
    `@alpha` variant of their skin, depth-tested, not the 2D shader that drew through walls)."""
    issue("developer 1")
    issue("dk3_runtime_probe_health 10000")
    deadline = time.monotonic() + 15
    origin = [0.0, 0.0, 0.0]
    while origin == [0.0, 0.0, 0.0] and time.monotonic() < deadline:
        issue("viewpos", 0.5)
        origin = [float(value) for value in re.findall(r"zig viewpos: (-?[\d.]+) (-?[\d.]+) (-?[\d.]+)", log.read_text(errors="replace"))[-1]]
    issue("dk3_look 90 10", 0.3)
    for depth in range(160, 400, 40):
        mark = len(log.read_text(errors="replace"))
        issue(f"dk3_runtime_actor_spawn monster_lasergat {origin[0]:.0f} {origin[1] + depth:.0f} {origin[2]:.0f} 270 e1m3b 1 ground", 0.4)
        found = re.findall(r"actor fixture: id=(\d+) class=monster_lasergat", log.read_text(errors="replace")[mark:])
        if found:
            break
    else:
        raise RuntimeError("no clear spot ahead for the lasergat")
    identity = int(found[-1])
    issue("dk3_runtime_pacify_monsters", 0.2)
    capture("before-gibs")
    issue(f"dk3_runtime_probe_health 1 {identity}", 0.05)
    issue(f"dk3_runtime_hurt {identity} 1000", 0.15)
    mark = len(log.read_text(errors="replace"))
    issue("dk3_runtime_presentation", 0.05)
    capture("gibs")
    presented = [(int(g), int(k)) for g, k in re.findall(r"dk3 presentation: .* gibs=(\d+) chunks=(\d+)", log.read_text(errors="replace")[mark:])]
    if not presented or presented[-1][0] + presented[-1][1] == 0:
        raise RuntimeError(f"no mechanical chunks were drawn: {presented}")
    return {"depth": depth, "presented": presented, "scope": "e1m3b: a destroyed lasergat's chunks render in view with the scripted @alpha skin variant; occlusion behind walls follows from that shader's depth test (code), not from a capture"}


def sidekick_hud_scenario(issue, capture, log):
    issue("developer 1")
    issue("dk3_runtime_probe_health 10000")
    # e3m1a starts with both sidekicks beside the player: both flaps fade in. Hurting Mikiko
    # darkens her face and shortens her health bar. The command window opens on its key, steps
    # to STAY and orders Mikiko, then switches to Superfly and orders him to come.
    deadline = time.monotonic() + 8
    while time.monotonic() < deadline:
        issue("dk3_runtime_actors", 0.5)
        text = log.read_text(errors="replace")
        if re.search(r"zig actor: id=\d+ .*class=superfly", text) and re.search(r"zig actor: id=\d+ .*class=mikiko", text):
            break
    text = log.read_text(errors="replace")
    if not (re.search(r"class=superfly", text) and re.search(r"class=mikiko", text)):
        raise RuntimeError("e3m1a does not start with both sidekicks")
    issue("dk3_runtime_actors", 2.0)
    capture("flaps")
    issue("dk3_runtime_damage 2000 mikiko", 1.0)
    capture("flaps-hurt")
    issue("sidekick_next", 0.6)
    capture("window-open")
    issue("sidekick_next", 0.2)
    issue("sidekick_next", 0.6)
    capture("window-stay")
    issue("sidekick_apply", 1.0)
    issue("sidekick_swap", 0.4)
    issue("sidekick_prev", 0.2)
    issue("sidekick_prev", 0.2)
    issue("sidekick_next", 0.6)
    capture("window-superfly")
    issue("sidekick_apply", 1.0)
    issue("companion follow", 1.0)
    text = log.read_text(errors="replace")
    orders = re.findall(r"companion order: (\w+) (\w+) -> (\w+) refused=(\d)", text)
    if ("mikiko", "stay", "stay", "0") not in orders:
        raise RuntimeError(f"the window did not order Mikiko to stay: {orders}")
    if ("superfly", "come", "come", "0") not in orders:
        raise RuntimeError(f"the window did not order Superfly to come: {orders}")
    if not any(o[1] == "follow" for o in orders):
        raise RuntimeError(f"the default companion bind gave no order: {orders}")
    # The reference's HUD cycle: a profile without the cycle binds gets them (o, k, l, ;); o steps
    # weapons, items, Superfly's then Mikiko's command mode; ; gives the lit order.
    mark = len(log.read_text(errors="replace"))
    for key in ("o", "k", "l", "SEMICOLON"):
        issue(f"bind {key}", 0.1)
    binds = dict(re.findall(r'"(\w+)" = "([^"]*)"', re.sub(r"\^\d", "", log.read_text(errors="replace")[mark:])))
    if [binds.get(key) for key in ("o", "k", "l", ";")] != ["hud_cycle", "hud_prev", "hud_next", "hud_use"] and [binds.get(key) for key in ("o", "k", "l", "SEMICOLON")] != ["hud_cycle", "hud_prev", "hud_next", "hud_use"]:
        raise RuntimeError(f"the HUD cycle binds were not added: {binds}")
    issue("hud_cycle", 0.6)
    capture("cycle-superfly")
    issue("hud_next", 0.3)
    issue("hud_use", 1.0)
    issue("hud_cycle", 0.6)
    capture("cycle-mikiko")
    issue("hud_use", 1.0)
    cycled = re.findall(r"companion order: (\w+) (\w+) -> (\w+) refused=(\d)", log.read_text(errors="replace")[mark:])
    if [o[0] for o in cycled][:2] != ["superfly", "mikiko"]:
        raise RuntimeError(f"the HUD cycle did not order Superfly then Mikiko: {cycled}")
    return {"orders": orders, "cycled": cycled, "binds": binds, "scope": "e3m1a sidekick flaps fade in, hurt face and bars, command window open/step/STAY to Mikiko, swap and COME to Superfly, default companion bind, HUD cycle binds added to a profile without them and the cycle ordering Superfly then Mikiko; voice acknowledgements and ammo gauge levels visual only"}


def save_preview_scenario(issue, capture, log, home):
    issue("developer 1")
    issue("dk3_runtime_probe_health 10000")
    # Two saves made as the player makes them: each writes its info sidecar (wall-clock time, map,
    # difficulty, picture name) and the client takes a HUD-free picture. The Load page lists the
    # newest first with its picture, time and map.
    deadline = time.monotonic() + 20
    while time.monotonic() < deadline and "dk3 autosave: saved" not in log.read_text(errors="replace"):
        issue("dk3_runtime_actors", 0.5)
    saves = home / "state/dk3/saves"
    issue("save probe_one", 2.0)
    deadline = time.monotonic() + 60
    while time.monotonic() < deadline and not (saves / "probe_one.info").exists():
        issue("dk3_runtime_actors", 1.0)
    issue("dk3_runtime_place 818.916 -479.481 -823.875", 3.0)
    issue("save probe_two", 2.0)
    deadline = time.monotonic() + 60
    while time.monotonic() < deadline and not (saves / "probe_two.info").exists():
        issue("dk3_runtime_actors", 1.0)
    results = {}
    for slot in ("probe_one", "probe_two"):
        info_path = saves / f"{slot}.info"
        if not info_path.exists():
            raise RuntimeError(f"no info sidecar for {slot}")
        info = info_path.read_text()
        shot = re.search(r'shot "([^"]+)"', info)
        date = re.search(r'date "([^"]+)"', info)
        if not shot or not date or not date.group(1):
            raise RuntimeError(f"{slot} info lacks a picture or date: {info}")
        picture = home / "dk3/screenshots" / f"{shot.group(1)}.jpg"
        deadline = time.monotonic() + 60
        while time.monotonic() < deadline and not (picture.exists() and picture.stat().st_size >= 1000):
            issue("dk3_runtime_actors", 1.0)
        if not picture.exists() or picture.stat().st_size < 1000:
            raise RuntimeError(f"{slot} picture not written: {picture}")
        results[slot] = {"date": date.group(1), "shot": shot.group(1), "bytes": picture.stat().st_size}
        shutil.copy2(picture, log.parent / f"picture-{slot}.jpg")
    issue("dk3_menu_page 2", 4.0)
    capture("load-page")
    issue("dk3_menu_page 3", 4.0)
    capture("save-page")
    return {"saves": results, "scope": "e1m3b: two saves write their info sidecars and HUD-free pictures; Load and Save pages show newest first with picture, time and map (visual)"}


def difficulty_scenario(issue, capture, log):
    issue("developer 1")
    # Changing the difficulty during play rescales living monsters at once, keeping their share of
    # health: a 50-health Samurai guard becomes 63 on Shogun (x1.25) and 38 on Ronin (x0.6).
    def guards():
        issue("dk3_runtime_actors", 1.0)
        text = log.read_text(errors="replace")
        block = text[text.rfind("dk3 zig actor: id="):]
        return {int(i): int(h) for i, h in re.findall(r"zig actor: id=(\d+) state=\w+ health=(-?\d+) [^\n]*class=monster_mishimaguard", text[-200000:])}
    deadline = time.monotonic() + 20
    while time.monotonic() < deadline and "dk3 autosave: saved" not in log.read_text(errors="replace"):
        issue("dk3_runtime_actors", 0.5)
    issue("g_spSkill 3", 1.0)
    before = guards()
    issue("g_spSkill 5", 1.5)
    shogun = guards()
    issue("g_spSkill 1", 1.5)
    ronin = guards()
    changes = re.findall(r"dk3 difficulty: skill=(\d) ratio=([\d.]+)", log.read_text(errors="replace"))
    guard = next((i for i, h in before.items() if h == 50 and i in shogun and i in ronin), None)
    if guard is None:
        raise RuntimeError(f"no full-health Samurai guard to follow: {before}")
    if shogun[guard] != 63 or ronin[guard] != 38:
        raise RuntimeError(f"guard {guard} health {before[guard]} -> {shogun[guard]} -> {ronin[guard]}, changes {changes}")
    issue("dk3_menu_page 9", 1.0)
    capture("options-difficulty")
    return {"guard": guard, "health": [before[guard], shogun[guard], ronin[guard]], "changes": changes,
            "scope": "e1m3b g_spSkill 3 -> 5 -> 1 during play rescales a guard's health 50 -> 63 -> 38; Options page shows Difficulty (visual)"}


def kage_scenario(issue, capture, log):
    issue("developer 1")
    issue("dk3_runtime_probe_health 10000")
    # Kage spawned south of the e2m1a start fights the player; brought below his recharge
    # threshold he summons his ring of protector ghosts (one every 0.65 s) and refunds damage.
    identity = None
    for x, y in ((-580, 1272), (-460, 1272), (-520, 1192), (-640, 1192)):
        text = log.read_text(errors="replace")
        issue(f"dk3_runtime_actor_spawn monster_kage {x} {y} 1440 90 e2m1a 1 ground", 0.4)
        found = re.findall(r"actor fixture: id=(\d+) class=monster_kage .* grounded=1", log.read_text(errors="replace")[len(text):])
        if found:
            identity = int(found[-1])
            break
    if identity is None:
        raise RuntimeError("no clear spot for Kage")
    mark = len(log.read_text(errors="replace"))
    deadline = time.monotonic() + 12
    while time.monotonic() < deadline:
        issue("dk3_runtime_actors", 0.4)
        if re.search(rf"zig actor: id={identity} state=attack ", log.read_text(errors="replace")[mark:]):
            break
    if not re.search(rf"zig actor: id={identity} state=attack ", log.read_text(errors="replace")[mark:]):
        raise RuntimeError(f"Kage {identity} never attacked")
    issue(f"dk3_runtime_probe_health 100 {identity}")
    mark = len(log.read_text(errors="replace"))
    deadline = time.monotonic() + 6
    while time.monotonic() < deadline:
        issue("dk3_runtime_actors", 0.5)
    text = log.read_text(errors="replace")[mark:]
    ghosts = set(re.findall(r"zig actor: id=(\d+) state=\w+ health=-?\d+ .*class=monster_ghost", text))
    if len(ghosts) < 3:
        raise RuntimeError(f"Kage {identity} summoned {len(ghosts)} protector ghosts")
    before = [int(h) for h in re.findall(rf"zig actor: id={identity} state=\w+ health=(-?\d+)", text)][-1]
    issue(f"dk3_runtime_hurt {identity} 40", 0.6)
    issue("dk3_runtime_actors", 0.3)
    after = [int(h) for h in re.findall(rf"zig actor: id={identity} state=\w+ health=(-?\d+)", log.read_text(errors="replace"))][-1]
    if after < before:
        raise RuntimeError(f"Kage {identity} lost health while recharging: {before} -> {after}")
    capture("kage-recharge")
    return {"kage": identity, "ghosts": len(ghosts), "health_before_hit": before, "health_after_hit": after,
            "scope": "e2m1a Kage fixture attacks, summons protector ghosts below his recharge threshold and refunds damage while recharging; smoke escape, shield and Gold timing parity unqualified"}


def seal_cover_scenario(issue, capture, log):
    issue("developer 1")
    issue("dk3_runtime_probe_health 10000")
    # A seal girl spawned with spawnflag 512 south of the e2m1a start shoots from cover only
    # while the player is completely visible, rests 2-8 s after each shot (her ataka runs 2.85 s
    # to its last frame) and hides between shots.
    identity = None
    for x, y in ((-580, 1272), (-460, 1272), (-520, 1192), (-640, 1192)):
        text = log.read_text(errors="replace")
        issue(f"dk3_runtime_actor_spawn monster_sealgirl {x} {y} 1440 90 e2m1a 1 ground 512", 0.4)
        found = re.findall(r"actor fixture: id=(\d+) class=monster_sealgirl .* grounded=1", log.read_text(errors="replace")[len(text):])
        if found:
            identity = int(found[-1])
            break
    if identity is None:
        raise RuntimeError("no clear spot for the cover seal girl")
    mark = len(log.read_text(errors="replace"))
    deadline = time.monotonic() + 24
    while time.monotonic() < deadline:
        issue("dk3_runtime_actors", 0.3)
    text = log.read_text(errors="replace")[mark:]
    samples = re.findall(rf"zig actor: id={identity} state=(\w+) .*? now=(\d+)", text)
    starts = [int(now) for (state, now), (before, _) in zip(samples[1:], samples) if state == "attack" and before != "attack"]
    if len(starts) < 2:
        raise RuntimeError(f"cover seal girl {identity} fired fewer than two shots: {[state for state, _ in samples][-12:]}")
    if any(b - a < 4400 for a, b in zip(starts, starts[1:])):
        raise RuntimeError(f"cover seal girl {identity} shot again without resting: {starts}")
    ran = bool(re.search(rf"zig actor: id={identity} state=chase .*cover=", text))
    capture("seal-cover")
    return {"girl": identity, "shot_starts": starts, "ran_for_cover": ran,
            "scope": "e2m1a seal girl fixture with spawnflag 512 fires from cover with a rest of at least 2 s after each 2.85 s shot; hide-node choice recorded, not required; damage and Gold timing parity unqualified"}


def guard_aim_scenario(issue, capture, log):
    # A guard that may not move (spawnflag 128), below the e1m3b stairs, engages the player
    # above it: its skeletal model bends its chest and head toward him (remaster aim), compared
    # with the authored level pose (cg_skeletalAim 0).
    issue("developer 1")
    issue("dk3_runtime_probe_health 10000")
    issue("dk3_runtime_place 312 1048 -60 180", 0.5)
    text = log.read_text(errors="replace")
    found = []
    # Nearest clear floor first: the closer the guard, the larger it is in the captures.
    for spot in ("250 980 -140", "230 960 -140", "210 940 -140", "200 920 -140", "175 880 -140"):
        issue(f"dk3_runtime_actor_spawn monster_mishimaguard {spot} 45 e1m3b 1 ground 128", 0.5)
        found = re.findall(r"actor fixture: id=(\d+) class=monster_mishimaguard .* grounded=1", log.read_text(errors="replace")[len(text):])
        if found:
            break
    if not found:
        raise RuntimeError("no clear spot for the aiming guard")
    guard = int(found[-1])
    deadline = time.monotonic() + 10
    engaged = None
    while time.monotonic() < deadline:
        issue("dk3_runtime_actors", 0.4)
        states = re.findall(rf"zig actor: id={guard} state=(\w+) health=-?\d+ pos=([\d.,-]+) threat=(\d+)", log.read_text(errors="replace"))
        if states and states[-1][2] != "0":
            engaged = states[-1]
            break
    if engaged is None:
        raise RuntimeError(f"guard {guard} never engaged the player")
    target = list(map(float, engaged[1].split(',')))
    dx, dy, dz = target[0] - 312, target[1] - 1048, target[2] + 10 - (-60 + 22)
    issue(f"dk3_look {math.degrees(math.atan2(dy, dx))} {-math.degrees(math.atan2(dz, math.hypot(dx, dy)))}", 1.0)
    issue("set cg_skeletalAim 1", 0.4)
    capture("guard-aim-on")
    issue("set cg_skeletalAim 0", 0.4)
    capture("guard-aim-off")
    issue("set cg_skeletalAim 1", 0.1)
    mark = len(log.read_text(errors="replace"))
    for _ in range(30):
        issue("dk3_runtime_projections monster_mishimaguard", 0.1)
    frames = [int(value) for value in re.findall(rf"dk3 projection: id={guard} .*? frame=(\d+)", log.read_text(errors="replace")[mark:])]
    return {"guard": guard, "guard_position": engaged[1], "rise": round(-dz, 1), "frames": frames,
            "scope": "e1m3b do-not-move guard fixture engaging the player above it, captured with and without skeletal aim; visual inspection only"}


def human_poses_scenario(issue, capture, log):
    # Each humanoid class as a do-not-move fixture on the e1m3b floor, seen level from a clear
    # point: its neural model plays the class's own source clips (sequence 418).
    issue("developer 1")
    issue("dk3_runtime_probe_health 10000")
    issue("set cg_skeletalAim 0")
    # Clear floor around the room below the stairs, nearest first; big hulls take the open middle.
    spots = sorted((f"{x} {y} -130" for x in range(-40, 441, 40) for y in range(700, 1181, 40)),
                   key=lambda spot: math.hypot(float(spot.split()[0]) - 200, float(spot.split()[1]) - 920))
    result = {}
    for classname in ("monster_mishimaguard", "monster_cryotech", "monster_surgeon", "monster_skinnyworker", "monster_fatworker",
                      "monster_inmater", "monster_ragemaster", "monster_sludgeminion"):
        found = []
        while spots and not found:
            mark = len(log.read_text(errors="replace"))
            spot = spots.pop(0)
            issue(f"dk3_runtime_actor_spawn {classname} {spot} 45 e1m3b 1 ground 128", 0.2)
            found = re.findall(rf"actor fixture: id=(\d+) class={classname} .* grounded=1", log.read_text(errors="replace")[mark:])
            # Keep later fixtures clear of this one.
            if found: spots = [other for other in spots if math.dist(map(float, other.split()[:2]), map(float, spot.split()[:2])) > 90]
        if not found:
            raise RuntimeError(f"no clear spot for {classname}")
        identity = int(found[-1])
        time.sleep(2)  # a class seen for the first time registers its model
        # Nothing attacks during the capture, so no damage flash tints it; idle clips play.
        issue("dk3_runtime_pacify_monsters", 1.2)
        mark = len(log.read_text(errors="replace"))
        issue(f"dk3_runtime_face_target {identity} 110", 0.4)
        issue("dk3_runtime_actors", 0.3)
        text = log.read_text(errors="replace")[mark:]
        player = re.findall(rf"zig combat: fixture player=([\d.,-]+) target={identity}", text)
        target = re.findall(rf"zig actor: id={identity} state=\w+ health=-?\d+ pos=([\d.,-]+)", text)
        if player and target:
            eye = list(map(float, player[-1].split(",")))
            aim = list(map(float, target[-1].split(",")))
            dx, dy, dz = aim[0] - eye[0], aim[1] - eye[1], aim[2] + 8 - (eye[2] + 22)
            issue(f"dk3_look {math.degrees(math.atan2(dy, dx))} {-math.degrees(math.atan2(dz, math.hypot(dx, dy)))}", 0.8)
        mark = len(log.read_text(errors="replace"))
        for _ in range(12):
            issue("dk3_runtime_projections " + classname, 0.1)
        frames = [int(value) for value in re.findall(rf"dk3 projection: id={identity} .*? frame=(\d+)", log.read_text(errors="replace")[mark:])]
        capture(classname.removeprefix("monster_"))
        result[classname] = {"id": identity, "frames": frames}
    issue("set cg_skeletalAim 1")
    result["scope"] = "human NPC fixtures framed level; visual inspection of the retargeted source clips"
    return result


def ragdoll_deaths_scenario(issue, capture, log):
    # A humanoid fixture killed by a single 30-point hit (an ion bolt) in front of the camera:
    # with the remaster gib thresholds it keeps its body, and its physical fall is captured.
    issue("developer 1")
    issue("dk3_runtime_probe_health 10000")
    issue("set cg_skeletalAim 0")
    spots = sorted((f"{x} {y} -130" for x in range(-40, 441, 40) for y in range(700, 1181, 40)),
                   key=lambda spot: math.hypot(float(spot.split()[0]) - 200, float(spot.split()[1]) - 920))
    result = {}
    for classname in ("monster_mishimaguard", "monster_skinnyworker"):
        found = []
        while spots and not found:
            mark = len(log.read_text(errors="replace"))
            spot = spots.pop(0)
            issue(f"dk3_runtime_actor_spawn {classname} {spot} 45 e1m3b 1 ground 128", 0.2)
            found = re.findall(rf"actor fixture: id=(\d+) class={classname} .* grounded=1", log.read_text(errors="replace")[mark:])
            if found: spots = [other for other in spots if math.dist(map(float, other.split()[:2]), map(float, spot.split()[:2])) > 90]
        if not found:
            raise RuntimeError(f"no clear spot for {classname}")
        identity = int(found[-1])
        time.sleep(2)
        issue("dk3_runtime_pacify_monsters", 1.2)
        mark = len(log.read_text(errors="replace"))
        issue(f"dk3_runtime_face_target {identity} 110", 0.4)
        issue("dk3_runtime_actors", 0.3)
        text = log.read_text(errors="replace")[mark:]
        player = re.findall(rf"zig combat: fixture player=([\d.,-]+) target={identity}", text)
        target = re.findall(rf"zig actor: id={identity} state=\w+ health=(-?\d+) pos=([\d.,-]+)", text)
        if player and target:
            eye = list(map(float, player[-1].split(",")))
            aim = list(map(float, target[-1][1].split(",")))
            dx, dy, dz = aim[0] - eye[0], aim[1] - eye[1], aim[2] - 8 - (eye[2] + 22)
            issue(f"dk3_look {math.degrees(math.atan2(dy, dx))} {-math.degrees(math.atan2(dz, math.hypot(dx, dy)))}", 0.6)
        name = classname.removeprefix("monster_")
        capture(f"{name}-alive")
        mark = len(log.read_text(errors="replace"))
        health = int(target[-1][0]) if target else 30
        # Wounded first, then killed by a 30-point hit (an ion bolt).
        if health > 10: issue(f"dk3_runtime_hurt {identity} {health - 10}", 0.6)
        issue(f"dk3_runtime_hurt {identity} 30", 0.05)
        started = time.monotonic()
        heights = {}
        for moment in (0.15, 0.3, 0.5, 0.7, 1.0, 1.4, 2.0, 3.0):
            time.sleep(max(0, started + moment - time.monotonic()))
            if moment in (0.3, 0.7, 1.4, 3.0): capture(f"{name}-dead-{moment}s")
            before = len(log.read_text(errors="replace"))
            issue("dk3_runtime_presentation", 0.05)
            issue("dk3_runtime_actors", 0.05)
            issue(f"dk3_runtime_projections {classname}", 0.05)
            recent = log.read_text(errors="replace")[before:]
            sample = re.findall(rf"dk3 ragdoll: slot=\d+ identity={identity} .*? contacts=(\d+) sleep=(\d) pelvis=[\d.-]+,[\d.-]+,([\d.-]+)", recent)
            state = re.findall(rf"zig actor: id={identity} state=(\w+)", recent)
            frame = re.findall(rf"dk3 projection: id={identity} .*? frame=(\d+)", recent)
            heights[moment] = {"pelvis_z": float(sample[-1][2]) if sample else None, "contacts": int(sample[-1][0]) if sample else None,
                               "asleep": sample[-1][1] == "1" if sample else None, "state": state[-1] if state else None, "frame": int(frame[-1]) if frame else None}
        text = log.read_text(errors="replace")[mark:]
        result[classname] = {"id": identity, "killing_hit": 30, "fall": heights,
                             "gibbed": f"retired: " in text and bool(re.search(rf"actor retired: .* id={identity} reason=gibbed", text)),
                             "ragdoll": len(re.findall(r"dk3 ragdoll: ", text))}
    issue("set cg_skeletalAim 1")
    result["scope"] = "single-hit kills of humanoid fixtures with the remaster gib thresholds; physical falls captured for inspection"
    return result


def navigation_scenario(issue, capture, log):
    issue("developer 1")
    issue(f"dk3_runtime_chase {PURSUIT_GUARD}", 0.2)
    text = log.read_text(errors="replace")
    fixtures = re.findall(rf"navigation fixture: actor={PURSUIT_GUARD} start=([\d.,-]+) goal=([\d.,-]+) travel=(\d+) occluded=1", text)
    if not fixtures:
        raise RuntimeError("no occluded reachable pursuit fixture")
    start = list(map(float, fixtures[-1][0].split(',')))
    goal = list(map(float, fixtures[-1][1].split(',')))
    issue(f"dk3_look {math.degrees(math.atan2(start[1] - goal[1], start[0] - goal[0]))} 0")
    capture("pursuit-start")
    deadline = time.monotonic() + 9
    samples = []
    while time.monotonic() < deadline:
        issue("dk3_runtime_actors", 0.3)
        text = log.read_text(errors="replace")
        states = re.findall(rf"zig actor: id={PURSUIT_GUARD} state=(\w+) health=(-?\d+) pos=([\d.,-]+)", text)
        if states:
            samples.append(states[-1])
        if f"guard: id={PURSUIT_GUARD} fired" in text:
            break
    capture("pursuit-arrival")
    displacement = max((math.dist(start, list(map(float, sample[2].split(',')))) for sample in samples), default=0)
    if displacement < 24 or f"guard: id={PURSUIT_GUARD} fired" not in text:
        raise RuntimeError(f"guard failed to navigate from occlusion into a firing position: {displacement=} {samples=}")
    return {"fixture": fixtures[-1], "samples": samples, "displacement": displacement,
            "scope": "e1m3b guard physically pursues a seeded last-seen goal around occlusion and resumes normal fire; diagnostic player placement, sight memory and health; full navigation matrix open"}


def laser_scenario(issue, capture, log):
    issue("developer 1")
    issue("dk3_runtime_probe_health 1000")
    issue("dk3_runtime_world")
    text = log.read_text(errors="replace")
    fields = re.findall(r"hazard: id=110 name=laser_dam enabled=(\d) center=([\d.,-]+)", text)
    if not fields or fields[-1][0] != '0':
        raise RuntimeError("laser damage field must start disabled")
    center = list(map(float, fields[-1][1].split(',')))
    issue("dk3_runtime_activate 110 player")
    issue("dk3_runtime_place " + ' '.join(map(str, center)), 0.6)
    if "hazard hit: id=110" not in log.read_text(errors="replace"):
        raise RuntimeError("enabled damage field did not hurt the player")
    issue("dk3_runtime_face_target 125", 0.2)
    text = log.read_text(errors="replace")
    placements = re.findall(r"fixture player=([\d.,-]+) target=125", text)
    boxes = re.findall(r"destructible: id=125 .*center=([\d.,-]+)", text)
    if not placements or not boxes:
        raise RuntimeError("no clear firing position near the supply box")
    player = list(map(float, placements[-1].split(',')))
    box = list(map(float, boxes[-1].split(',')))
    dx, dy, dz = box[0] - player[0], box[1] - player[1], box[2] + 8 - (player[2] + 22)
    issue("dk3_runtime_equip 21")
    issue(f"dk3_look {math.degrees(math.atan2(dy, dx))} {-math.degrees(math.atan2(dz, math.hypot(dx, dy)))}")
    capture("laser-box-intact")
    for _ in range(3):
        issue("+attack", 0.15)
        issue("-attack", 0.8)
    issue("dk3_runtime_world", 4.5)
    issue("dk3_runtime_world")
    text = log.read_text(errors="replace")
    if not re.search(r"destructible: id=125 health=-?\d+ broken=1", text) or "disabled e1m3b laser damage with removed controls" not in text:
        raise RuntimeError("shooting supply box did not finish laser shutdown")
    cutoff = len(text)
    for y in (center[1] - 72, center[1], center[1] + 72, center[1]):
        issue(f"dk3_runtime_place {center[0]} {y} {center[2]}", 0.6)
    capture("lasers-disabled")
    after = log.read_text(errors="replace")[cutoff:]
    if "hazard hit: id=110" in after:
        raise RuntimeError("disabled lasers still caused damage from the reverse approach")
    issue("save laser_off")
    issue("dk3_runtime_damage 40")
    cutoff = len(log.read_text(errors="replace"))
    issue("load laser_off")
    issue("dk3_runtime_world")
    after = log.read_text(errors="replace")[cutoff:]
    if "saved world restored" not in after or not re.search(r"destructible: id=125 health=-?\d+ broken=1", after):
        raise RuntimeError("save did not restore the broken laser control")
    for y in (center[1] + 72, center[1], center[1] - 72, center[1]):
        issue(f"dk3_runtime_place {center[0]} {y} {center[2]}", 0.6)
    if "hazard hit: id=110" in log.read_text(errors="replace")[cutoff:]:
        raise RuntimeError("loading a save reactivated the disabled lasers")
    capture("laser-shutdown-restored")
    return {"hazard_center": center, "box": 125,
            "scope": "ordinary Glock fire breaks authored supply box; timed target chain removes controls; enabled hurt field damages, disabled field stays harmless at both approaches before and after native save/load; diagnostic placement/equipment/health, beam/audio presentation unqualified"}


def dormant_effects_scenario(issue, capture, log, home, process):
    # Effects left in a map outlive the player's departure; when that map goes dormant (its worlds
    # released) the client must drop them, not fail on their released world. As in play: from
    # e1m2a into e1m2b (a resident world), shoot there, then leave for e1m3a.
    issue("developer 1")
    issue("dk3_runtime_probe_health 1000")

    def leave(destination):
        issue("dk3_runtime_world")
        exits = re.findall(rf"zig exit: id=(\d+) map={destination} .*center=([\d.,-]+)", log.read_text(errors="replace"))
        if not exits:
            raise RuntimeError(f"no exit to {destination}")
        center = list(map(float, exits[-1][1].split(',')))
        issue(f"dk3_runtime_place {center[0] + 400} {center[1]} {center[2]}", 0.1)
        before = len(log.read_text(errors="replace"))
        issue("dk3_runtime_place " + ' '.join(map(str, center)), 0.05)
        wait(process, log, lambda text: "traveler entered authored landing" in text[before:])
        return before

    leave("e1m2b")
    time.sleep(1)
    issue("dk3_runtime_probe_health 1000")
    issue("dk3_runtime_equip 4", 0.8)
    mark = len(log.read_text(errors="replace"))
    # Shotcycler pellets all round, so some leave marks (they last 10 s; metal takes none).
    for yaw, pitch in ((0, 10), (90, 10), (180, 10), (270, 10), (45, 60), (225, 60)):
        issue(f"dk3_look {yaw} {pitch}", 0.1)
        issue("+attack", 0.5)
        issue("-attack", 0.2)
    marks = sum(int(m) for m in re.findall(r"zig impact: .* marks=(\d+)", log.read_text(errors="replace")[mark:]))
    if marks == 0:
        raise RuntimeError("no shot left a mark in e1m2b")
    shot_at = time.monotonic()
    before = leave("e1m3a")
    deadline = time.monotonic() + 25
    while time.monotonic() < deadline and "map=e1m2b dormant" not in log.read_text(errors="replace")[before:]:
        issue("dk3_runtime_actors", 0.5)
    dormant_at = time.monotonic()
    for _ in range(6):
        issue("dk3_runtime_actors", 0.5)
    text = log.read_text(errors="replace")[before:]
    if "Lost entity" in text or process.poll() is not None:
        raise RuntimeError("the client failed on a released world")
    if "map=e1m2b dormant" not in text:
        raise RuntimeError("e1m2b never went dormant")
    capture("dormant-effects")
    return {"dormant_after_shots_s": round(dormant_at - shot_at, 1),
            "scope": "effects fired in e1m2b (entered from e1m2a) just before leaving for e1m3a, when e1m2b goes dormant; no client failure"}


def travel_scenario(issue, capture, log, home, process):
    # Exercise a changed authored world, then visit/revisit through its real exits.
    laser_scenario(issue, capture, log)
    issue("dk3_runtime_probe_health 333")
    issue("dk3_runtime_equip 21")

    def leave(identity, destination):
        issue("dk3_runtime_world")
        matches = re.findall(rf"zig exit: id={identity} map={destination} .*center=([\d.,-]+)", log.read_text(errors="replace"))
        if not matches:
            raise RuntimeError(f"missing authored exit {identity} to {destination}")
        center = list(map(float, matches[-1].split(',')))
        # Clear any arrival latch before making ordinary touch contact.
        issue(f"dk3_runtime_place {center[0] + 400} {center[1]} {center[2]}", 0.1)
        before = len(log.read_text(errors="replace"))
        issue("dk3_runtime_place " + ' '.join(map(str, center)), 0.05)
        wait(process, log, lambda text: "traveler entered authored landing" in text[before:])
        time.sleep(0.7)
        segment = log.read_text(errors="replace")[before:]
        maps = re.findall(r"^Server: ([^\n]+)", segment, re.M)
        if maps != [destination]:
            raise RuntimeError(f"authored exit started unexpected maps: {maps}")
        departed = re.findall(r"campaign departure .*health=(\d+)", segment)
        arrived = re.findall(r"traveler entered authored landing health=(\d+) weapon=(\d+)", segment)
        if not departed or not arrived or departed[-1] != arrived[-1][0] or arrived[-1][1] != "21":
            raise RuntimeError(f"travel lost incoming health or equipment: {departed}, {arrived}")
        issue("viewpos")
        return int(arrived[-1][0])

    leave(127, "e1m3a")
    capture("arrival-e1m3a")
    issue("dk3_runtime_probe_health 333")
    issue("save visited_lasers")
    save = home / "state/dk3/saves/visited_lasers.sav"
    if not save.exists() or b"visited_level" not in save.read_bytes():
        raise RuntimeError("campaign save omitted the visited laser world")
    saved_health = int(re.search(r"^health (-?\d+)$", save.with_suffix(".info").read_text(), re.M)[1])
    issue("dk3_runtime_probe_health 222")
    leave(131, "e1m3b")
    issue("dk3_runtime_world")
    text = log.read_text(errors="replace")
    if not re.search(r"destructible: id=125 health=-?\d+ broken=1", text[text.rfind("saved world restored"):]):
        raise RuntimeError("revisit lost world changes or replaced the incoming traveler")
    capture("revisited-laser-world")
    before = len(log.read_text(errors="replace"))
    issue("devmap e1m3a", 0.05)  # Discard live campaign state before loading its archive.
    wait(process, log, lambda text: "player entered isolated movement runtime" in text[before:])
    for path in save.parent.glob("dk3-*"):
        if path.is_file():
            path.unlink()  # Only this fixture's temporary internal transfer files.
    before = len(log.read_text(errors="replace"))
    issue("load visited_lasers", 0.4)
    restored = re.findall(r"saved world restored health=(-?\d+)", log.read_text(errors="replace")[before:])
    if not restored or int(restored[-1]) != saved_health:
        raise RuntimeError("campaign save did not restore its player")
    leave(131, "e1m3b")
    before = len(log.read_text(errors="replace"))
    issue("dk3_runtime_world")
    text = log.read_text(errors="replace")[before:]
    if not re.search(r"destructible: id=125 health=-?\d+ broken=1", text):
        raise RuntimeError("saved visited-world archive was not restored independently")
    capture("saved-archive-revisited")
    return {"scope": "authored e1m3b/e1m3a exit touch, named arrival, incoming inventory/health, changed visited-world restoration and complete native campaign save after discarding internal transfer files; diagnostic placement/equipment, not authored route traversal or companion/cinematic acceptance"}


def run(args):
    if not __debug__:
        raise RuntimeError("Native probes require Python assertions enabled")
    args.report.mkdir(parents=True, exist_ok=True)
    from runtime_input import record_identity
    identity = record_identity(args.engine, args.prefix, args.report)
    log = args.report / "client.log"
    inputs = []
    with tempfile.TemporaryDirectory(prefix="dk3-runtime-client-", delete=not os.environ.get("DK3_PROBE_KEEP_HOME")) as temporary:
        home = Path(temporary)
        stage_client_modules(args.prefix, home)
        command = [str(args.guard), "--headless", "--screen", "960x540",
                   "--timeout", "180s" if args.scenario in ("controllers", "crox", "sidekick-water", "sidekick-surface", "sidekick-nitro", "sidekick-slime", "sidekick-lava") else "90s", "--mem", "8G", "--", str(args.engine / "bin/dk3")]
        settings = client_settings(args.engine, home, args.renderer, args.workers)
        if args.scenario in ("opening-actors", "bridge", "trigger-bounds", "crox", "rockgat", "tree-settlement", "frog-landing", "arena-damage"):
            settings["g_spSkill"] = "3"
        if args.scenario == "frog-landing":
            settings["dk3_cinematics"] = "1"
        for name, value in settings.items():
            command += ["+set", name, value]
        command += ["+devmap", args.map]
        with log.open("w") as output:
            process = subprocess.Popen(command, stdout=output, stderr=subprocess.STDOUT)
            pipe = home / "dk3/commands.fifo"

            def issue(value, delay=0.15):
                inputs.append({"command": value, "settle_seconds": delay})
                send(pipe, value)
                time.sleep(delay)

            def capture(name):
                issue(f"screenshotJPEG {name}")
                source = home / f"dk3/screenshots/{name}.jpg"
                wait(process, log, lambda _: source.exists(), 10)
                shutil.copy2(source, args.report / f"{name}.jpg")

            try:
                wait(process, log, lambda text: "player entered isolated movement runtime" in text)
                if args.scenario in ("controllers", "bridge", "trigger-bounds", "opening-actors", "crox", "rockgat", "tree-settlement", "frog-landing", "arena-damage"):
                    from runtime_input import NativeInput
                    if args.scenario == "arena-damage":
                        from runtime_arena_probe import scenario
                    elif args.scenario == "frog-landing":
                        from runtime_frog_landing_probe import scenario
                    elif args.scenario == "tree-settlement":
                        from runtime_tree_settlement_probe import scenario
                    elif args.scenario == "rockgat":
                        from runtime_rockgat_probe import scenario
                    elif args.scenario == "crox":
                        from runtime_crox_probe import scenario
                    elif args.scenario == "opening-actors":
                        from runtime_opening_actors_probe import scenario
                    elif args.scenario == "trigger-bounds":
                        from runtime_trigger_bounds_probe import scenario
                    elif args.scenario == "bridge":
                        from runtime_bridge_probe import scenario
                    else:
                        from runtime_weapon_completion_probe import scenario
                    wait(process, log, lambda text: "dk3 zig client: first snapshot applied" in text)
                    driver = NativeInput(process, pipe, log, home, inputs, diagnostic=True)
                    result = scenario(driver, args.report, args.checkpoint) if args.scenario in ("frog-landing", "arena-damage") else scenario(driver, args.report)
                elif args.scenario == "navigation":
                    result = navigation_scenario(issue, capture, log)
                elif args.scenario == "travel":
                    result = travel_scenario(issue, capture, log, home, process)
                elif args.scenario == "laser":
                    result = laser_scenario(issue, capture, log)
                elif args.scenario == "lift":
                    result = lift_scenario(issue, capture, log)
                elif args.scenario == "guard":
                    result = guard_scenario(issue, capture, log)
                elif args.scenario == "e2-melee":
                    result = e2_melee_scenario(issue, capture, log)
                elif args.scenario == "conveyor-meat":
                    result = conveyor_meat_scenario(issue, capture, log)
                elif args.scenario == "robot-gibs":
                    result = robot_gibs_scenario(issue, capture, log)
                elif args.scenario == "sidekick-water":
                    result = sidekick_water_scenario(issue, capture, log)
                elif args.scenario == "sidekick-surface":
                    result = sidekick_surface_scenario(issue, capture, log)
                elif args.scenario == "sidekick-catchup":
                    result = sidekick_catchup_scenario(issue, capture, log)
                elif args.scenario in HAZARD_SCENARIOS:
                    mask, label = HAZARD_SCENARIOS[args.scenario]
                    result = sidekick_hazard_scenario(issue, capture, log, args.engine, args.map, mask, label)
                elif args.scenario == "sidekick-stop":
                    result = sidekick_stop_scenario(issue, capture, log)
                elif args.scenario == "e3-creatures":
                    result = e3_creatures_scenario(issue, capture, log)
                elif args.scenario == "rats":
                    result = rats_scenario(issue, capture, log)
                elif args.scenario == "e4-fighters":
                    result = e4_fighters_scenario(issue, capture, log)
                elif args.scenario == "e4-gunfighters":
                    result = e4_gunfighters_scenario(issue, capture, log)
                elif args.scenario == "guard-aim":
                    result = guard_aim_scenario(issue, capture, log)
                elif args.scenario == "human-poses":
                    result = human_poses_scenario(issue, capture, log)
                elif args.scenario == "ragdoll-deaths":
                    result = ragdoll_deaths_scenario(issue, capture, log)
                elif args.scenario == "dormant-effects":
                    result = dormant_effects_scenario(issue, capture, log, home, process)
                elif args.scenario == "sidekick-talk":
                    result = sidekick_talk_scenario(issue, capture, log)
                elif args.scenario == "difficulty":
                    result = difficulty_scenario(issue, capture, log)
                elif args.scenario == "save-preview":
                    result = save_preview_scenario(issue, capture, log, home)
                elif args.scenario == "sidekick-hud":
                    result = sidekick_hud_scenario(issue, capture, log)
                elif args.scenario == "kage":
                    result = kage_scenario(issue, capture, log)
                elif args.scenario == "seal-cover":
                    result = seal_cover_scenario(issue, capture, log)
                elif args.scenario == "e3-knights":
                    result = e3_knights_scenario(issue, capture, log)
                elif args.scenario == "lasergat":
                    result = lasergat_scenario(issue, capture, log)
                elif args.scenario == "surgeon":
                    result = surgeon_scenario(issue, capture, log)
                elif args.scenario == "worker-wander":
                    result = worker_wander_scenario(issue, capture, log)
                elif args.scenario == "workers":
                    result = workers_scenario(issue, capture, log)
                elif args.scenario == "civilians":
                    result = civilians_scenario(issue, capture, log)
                elif args.scenario == "combat":
                    result = combat_scenario(issue, capture, log)
                elif args.scenario == "presentation":
                    result = presentation_scenario(issue, capture, log)
                elif args.scenario == "impacts":
                    result = impacts_scenario(issue, capture, log)
                elif args.scenario == "ballistics":
                    result = ballistics_scenario(issue, capture, log, process)
                elif args.scenario == "grenade-contact":
                    result = grenade_contact_scenario(issue, capture, log)
                elif args.scenario == "melee":
                    result = melee_scenario(issue, capture, log, process)
                elif args.scenario == "shockwave":
                    result = shockwave_scenario(issue, capture, log, process)
                elif args.scenario == "linked-projectiles":
                    result = linked_projectiles_scenario(issue, capture, log, process, home)
                elif args.scenario == "zeus":
                    result = zeus_scenario(issue, capture, log, process, home)
                elif args.scenario == "meteors":
                    result = meteors_scenario(issue, capture, log, process, home)
                elif args.scenario == "returning-fire":
                    result = returning_fire_scenario(issue, capture, log, process, home)
                elif args.scenario == "beams":
                    result = beams_scenario(issue, capture, log, process, home)
                elif args.scenario == "attached-charge":
                    result = attached_charge_scenario(issue, capture, log, process)
                elif args.scenario == "area-weapons":
                    result = area_weapons_scenario(issue, capture, log, process)
                elif args.scenario == "status-weapons":
                    from runtime_input import NativeInput
                    result = status_weapons_scenario(issue, capture, log, process, NativeInput(process, pipe, log, home, inputs, diagnostic=True))
                elif args.scenario == "save":
                    result = save_scenario(issue, capture, log, home)
                elif args.scenario == "effects":
                    result = effects_scenario(issue, capture, log)
                elif args.scenario == "inventory":
                    result = inventory_scenario(issue, capture, log)
                elif args.scenario in ("secret", "rotation"):
                    result = special_scenario(args, issue, capture, log)
                else:
                    result = movement_scenario(args, issue, capture, log)
                issue("quit", 0)
                if process.wait(timeout=15) != 0:
                    raise RuntimeError(f"engine shutdown failed: {log}")
                (args.report / "result.json").write_text(json.dumps({**result, "workers": args.workers, "identity": identity}, indent=2) + "\n")
            finally:
                (args.report / "inputs.json").write_text(json.dumps({"launch": command, "inputs": inputs}, indent=2) + "\n")
                if process.poll() is None:
                    process.terminate()
                    process.wait(timeout=15)
    print(f"Native client probe passed. Inspect captures in {args.report}; gameplay acceptance remains open.")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--engine", type=Path, required=True)
    parser.add_argument("--prefix", type=Path, required=True)
    parser.add_argument("--guard", type=Path, default=Path("zig-out/native-dev/bin/dkguard"))
    parser.add_argument("--report", type=Path, default=None)
    parser.add_argument("--map")
    parser.add_argument("--checkpoint", type=Path, help="Captured native save for a checkpoint diagnostic")
    parser.add_argument("--scenario", choices=("movement", "lift", "secret", "rotation", "inventory", "effects", "combat", "presentation", "impacts", "ballistics", "grenade-contact", "melee", "status-weapons", "area-weapons", "attached-charge", "shockwave", "linked-projectiles", "beams", "returning-fire", "meteors", "zeus", "controllers", "bridge", "trigger-bounds", "opening-actors", "crox", "rockgat", "tree-settlement", "frog-landing", "arena-damage", "save", "travel", "civilians", "workers", "worker-wander", "surgeon", "lasergat", "e2-melee", "e3-knights", "e3-creatures", "rats", "e4-fighters", "seal-cover", "kage", "e4-gunfighters", "sidekick-talk", "sidekick-hud", "sidekick-stop", "sidekick-water", "sidekick-surface", "sidekick-catchup", "sidekick-nitro", "sidekick-slime", "sidekick-lava", "robot-gibs", "conveyor-meat", "save-preview", "difficulty", "dormant-effects", "guard-aim", "human-poses", "ragdoll-deaths", "guard", "navigation", "laser"), default="movement")
    parser.add_argument("--workers", type=int, choices=range(9), default=4)
    parser.add_argument("--renderer", choices=("opengl1", "opengl2", "vulkan"), default="opengl1")
    parser.add_argument("--mover", type=int, help="optional known delayed-door persistent ID; e1m3b uses 255")
    args = parser.parse_args()
    defaults = {
        "movement": ("e1m3b", "runtime-zig-218/client"),
        "lift": ("e1m3a", "runtime-zig-219/lift"),
        "secret": ("e3dm1", "runtime-zig-220/secret"),
        "rotation": ("e1m3b", "runtime-zig-220/rotation"),
        "inventory": ("e1m6a", "runtime-zig-221/inventory"),
        "effects": ("e4m4b", "runtime-zig-222/effects"),
        "combat": ("e1m3b", "runtime-zig-224/combat"),
        "presentation": ("e1m3b", "runtime-zig-228/presentation"),
        "impacts": ("e1m2a", "runtime-zig-232/impacts"),
        "ballistics": ("e1m3b", "runtime-zig-233/ballistics"),
        "grenade-contact": ("e1m3b", "runtime-zig-233/grenade-contact"),
        "melee": ("e1m2a", "runtime-zig-234/melee"),
        "status-weapons": ("e1m3b", "runtime-zig-235/status-weapons"),
        "area-weapons": ("e1m3b", "runtime-zig-236/area-weapons"),
        "attached-charge": ("e1m3a", "runtime-zig-236/attached-charge"),
        "shockwave": ("e1m3b", "runtime-zig-237/shockwave"),
        "linked-projectiles": ("e1m3b", "runtime-zig-238/linked-projectiles"),
        "beams": ("e1m3b", "runtime-zig-239/beams"),
        "returning-fire": ("e1m3b", "runtime-zig-240/returning-fire"),
        "meteors": ("e1m3b", "runtime-zig-241/meteors"),
        "zeus": ("e1m2a", "runtime-zig-242/zeus"),
        "controllers": ("e1m2a", "runtime-zig-243/controllers"),
        "bridge": ("e1m1b", "runtime-zig-247/bridge"),
        "trigger-bounds": ("e1m1a", "runtime-zig-248/trigger-bounds"),
        "opening-actors": ("e1m1a", "runtime-zig-249/opening-actors"),
        "crox": ("e1m1b", "runtime-zig-250/crox"),
        "rockgat": ("e1m1b", "runtime-zig-250/rockgat"),
        "tree-settlement": ("e1m1b", "runtime-zig-252/tree-settlement"),
        "frog-landing": ("e1m1a", "runtime-zig-253/frog-landing"),
        "arena-damage": ("e1m1b", "runtime-zig-291/arena-damage"),
        "save": ("e1m3a", "runtime-zig-230/save"),
        "civilians": ("e1m2a", "runtime-zig-225/civilians"),
        "workers": ("e1m3a", "runtime-zig-403/workers"),
        "worker-wander": ("e1m2b", "runtime-zig-403/worker-wander"),
        "surgeon": ("e1m3a", "runtime-zig-406/surgeon"),
        "lasergat": ("e1m4a", "runtime-zig-406/lasergat"),
        "e2-melee": ("e2m1a", "runtime-zig-410/e2-melee"),
        "e3-knights": ("e2m1a", "runtime-zig-411/e3-knights"),
        "e3-creatures": ("e2m1a", "runtime-zig-411/e3-creatures"),
        "rats": ("e2m1a", "runtime-zig-424/rats"),
        "seal-cover": ("e2m1a", "runtime-zig-411/seal-cover"),
        "e4-fighters": ("e2m1a", "runtime-zig-411/e4-fighters"),
        "kage": ("e2m1a", "runtime-zig-412/kage"),
        "sidekick-talk": ("e3m1a", "runtime-zig-413/sidekick-talk"),
        "sidekick-hud": ("e3m1a", "runtime-zig-422/sidekick-hud"),
        "sidekick-stop": ("e1m4b", "runtime-zig-424/sidekick-stop"),
        "sidekick-water": ("e1m1c", "runtime-zig-425/sidekick-water"),
        "sidekick-surface": ("e1m1c", "runtime-zig-426/sidekick-surface"),
        "sidekick-catchup": ("e1m4b", "runtime-zig-426/sidekick-catchup"),
        "sidekick-nitro": ("e1m6c", "runtime-zig-426/sidekick-nitro"),
        "sidekick-slime": ("e2m5c", "runtime-zig-426/sidekick-slime"),
        "sidekick-lava": ("e3m3c", "runtime-zig-426/sidekick-lava"),
        "robot-gibs": ("e1m3b", "runtime-zig-425/robot-gibs"),
        "conveyor-meat": ("e1m5a", "runtime-zig-425/conveyor-meat"),
        "save-preview": ("e1m3b", "runtime-zig-423/save-preview"),
        "difficulty": ("e1m3b", "runtime-zig-423/difficulty"),
        "dormant-effects": ("e1m2a", "runtime-zig-416/dormant-effects"),
        "guard-aim": ("e1m3b", "runtime-zig-417/guard-aim"),
        "human-poses": ("e1m3b", "runtime-zig-418/human-poses"),
        "ragdoll-deaths": ("e1m3b", "runtime-zig-419/ragdoll-deaths"),
        "e4-gunfighters": ("e2m1a", "runtime-zig-412/e4-gunfighters"),
        "guard": ("e1m3b", "runtime-zig-226/guard"),
        "navigation": ("e1m3b", "runtime-zig-227/navigation"),
        "laser": ("e1m3b", "runtime-zig-227/laser"),
        "travel": ("e1m3b", "runtime-zig-231/travel"),
    }
    expected_map, report_name = defaults[args.scenario]
    if args.map is None:
        args.map = expected_map
    if args.report is None:
        args.report = Path("zig-out/reports") / report_name
    if args.scenario != "movement" and (args.map != expected_map or args.mover is not None):
        parser.error(f"{args.scenario} scenario uses {expected_map}; omit --mover")
    if not re.fullmatch(r"[a-zA-Z0-9_]+", args.map):
        parser.error("map must be a simple map name")
    for name in ("engine", "prefix", "guard", "report"):
        setattr(args, name, getattr(args, name).resolve())
    run(args)


if __name__ == "__main__":
    main()
