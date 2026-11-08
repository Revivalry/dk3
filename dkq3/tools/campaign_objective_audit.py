#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-or-later
"""Validate objective bindings against a converted map package without distributing local assets."""
import argparse
import collections
import hashlib
import json
from pathlib import Path
import re
import struct
import zipfile


def audit(package, catalog):
    goals = collections.defaultdict(list)
    for line in catalog.read_text().splitlines():
        if not line or line.startswith("#"):
            continue
        name, stage, rule, identities, text = line.split("|")
        rule, separator, amount = rule.partition(":")
        quantity = int(amount) if separator else 0
        if separator and not 2 <= quantity <= 15:
            raise ValueError(f"invalid counter quantity: {line}")
        goals[name].append(dict(stage=int(stage), rule=rule, quantity=quantity, ids=list(map(int, identities.split(","))), text=text))
    results = []
    with zipfile.ZipFile(package) as archive:
        maps = {name[5:-4] for name in archive.namelist() if re.fullmatch(r"maps/e[1-4]m\d+[a-z]\.bsp", name)}
        if set(goals) != maps:
            raise ValueError(f"campaign map mismatch: {set(goals) ^ maps}")
        for name in sorted(maps):
            blob = archive.read(f"maps/{name}.bsp")
            start, length = struct.unpack_from("<ii", blob, 8)
            entities = [dict(re.findall(r'"([^"\n]*)"\s*"([^"\n]*)"', block)) for block in re.findall(r"\{([^}]*)\}", blob[start:start+length].decode("latin1"))]
            prior = -1
            for goal in goals[name]:
                if goal["stage"] < prior or len(goal["ids"]) > 8 or len(goal["text"]) > 100:
                    raise ValueError(f"invalid goal shape: {name}: {goal}")
                prior = goal["stage"]
                for identity in goal["ids"]:
                    if goal["rule"] == "owned":
                        if not 1 <= identity <= 32:
                            raise ValueError(f"invalid key identity {identity}")
                        continue
                    entity = entities[identity-1]
                    kind = entity["classname"]
                    if goal["quantity"] and (goal["rule"] != "used" or len(goal["ids"]) != 1 or
                                              kind != "trigger_counter" or int(entity.get("count", 0)) != goal["quantity"]):
                        raise ValueError(f"wrong counter binding: {name} #{identity}: {goal}")
                    valid = (goal["rule"] == "taken" and kind.startswith(("item_", "weapon_")) or
                             goal["rule"] == "exit" and kind == "trigger_changelevel" or
                             goal["rule"] == "defeated" and kind.startswith("monster_") or
                             goal["rule"] == "broken" and kind in ("func_explosive", "func_wall_explode") or
                             goal["rule"] == "used" and kind.startswith(("func_", "trigger_")))
                    if not valid:
                        raise ValueError(f"wrong objective binding: {name} #{identity} {kind}: {goal}")
            results.append(dict(map=name, goals=len(goals[name]), authored_entities=len(entities)))
    return dict(scope="authored ordinal/type admission only; no traversal acceptance", maps=results,
                goals=sum(len(value) for value in goals.values()), catalog_sha256=hashlib.sha256(catalog.read_bytes()).hexdigest())


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--maps", type=Path, required=True)
    parser.add_argument("--catalog", type=Path, default=Path("src/game/domain/campaign_objectives.tsv"))
    parser.add_argument("--report", type=Path)
    args = parser.parse_args()
    result = audit(args.maps, args.catalog)
    if args.report:
        args.report.parent.mkdir(parents=True, exist_ok=True)
        args.report.write_text(json.dumps(result, indent=2) + "\n")
    print(f"Admitted {result['goals']} goals across {len(result['maps'])} campaign maps; traversal unverified.")


if __name__ == "__main__":
    main()
