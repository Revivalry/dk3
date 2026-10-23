#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-or-later
"""Derive local HD production tiers from the completed texture manifest."""
import argparse
import json
from pathlib import Path


def build(manifest):
    uses = {}
    for record in manifest['textures'].values():
        uses.setdefault(record['key'], set()).update(record['maps'])
    plan = {}
    for key, maps in uses.items():
        tier = ('hero' if maps & {'maps/e1m1a.bsp', 'maps/e1m1b.bsp'}
                else 'mid' if maps else 'tail')
        plan[key] = {'tier': tier, 'prompt': 'weathered surface, flat albedo texture',
                               'area': len(maps)}
    return plan


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--textures-manifest', type=Path, required=True)
    parser.add_argument('--out', type=Path, required=True)
    args = parser.parse_args()
    plan = build(json.loads(args.textures_manifest.read_text()))
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(plan, sort_keys=True, indent=2) + '\n')


if __name__ == '__main__':
    main()
