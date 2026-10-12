# Dwarf — review sheet

The reference files are `dlls/world/dwarf.cpp` and the generic AI. Provenance only.

The native code is `src/classes/actors/dwarf/` (`dwarf.zig`: choice, re-rolled reach, axe tuning and lifecycle; `server/dwarf.zig`: the shared ground combat with dwarf hooks; `server/dwarf_axes.zig`: the thrown axe). The re-rolled reach is the shared `mechanics/policy/actors/thrown_range.zig`.

| Section | Reference behaviour | Native status |
|---|---|---|
| Identity | `monster_dwarf` (53, e3m3–e3m5), model `m_dwarf`, aidata 200 HP, FOV 180; punch 15 + rnd·5, reach 80; axe 10 + rnd·20 at 600 u/s | Implemented |
| Reach | Re-rolled on every call: under 80 always; under 500 on 60%; 100–250 on a further 60% | Implemented (`thrown_range`) |
| Attack | Facing: ≤ 80 `ataka` chop (strike 18); 100–250 70% `atakc` running chop (strike 15, closes at attack speed), else `atakd` throw (release 16) | Implemented |
| Axe | Sticks in the world (pitch 300, `m_bodyhitc`), drops flat off its victim (`e_bulfleshc`); fades 4–5 s after impact; a flying axe is removed at 3 s | Implemented |
| Pain | Generic handler: two 20% rolls, `hita` on the second for 15+, the acquiring hit skips the first | Implemented (sequence 410) |
| Death | `diea`/`dieb` 50/50 | Implemented |
| Open questions | The per-think projectile check that sidesteps a blocked throw is not ported; take cover (512) is used by no map | Open |

## Animation inventory (converted `.anim`)

`m_dwarf`: `amba` 0–19, `ambb` 20–49, `ataka` 50–80, `atakc` 112–128, `atakd` 129–158, `diea` 159–179, `dieb` 180–200, `hita` 201–215, `runa` 244–260, `walka` 261–291 (`atakb`, `hitb` unused). All present.

## Verification (sequence 411)

- Implemented, not yet verified in game.
