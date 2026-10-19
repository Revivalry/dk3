# Knights — review sheet

The reference files are `dlls/world/knight1.cpp`, `dlls/world/knight2.cpp` and the generic AI. Provenance only.

The native code is `src/classes/actors/knights/` (`knights.zig`: choice, re-rolled reach, pain, saved zap; `server/knights.zig`: attacks; `server/knight_attacks.zig`: zap and punch effects; `server/actor_knights.zig`: hooks). The flame knight's fireball is the shared fireball (`lit` style).

| Section | Reference behaviour | Native status |
|---|---|---|
| Identity | `monster_knight1` (27, flame) and `monster_knight2` (26, lightning), aidata 200 HP; knight1 swing 40 + rnd·5 reach 120, fireball 30 + rnd·5 over radius 128; knight2 punch 40 + rnd·5 reach 120 (knock-back), zap 5 per tick | Implemented |
| Reach | Re-rolled: under 120 always; under 700 (knight1) or 800 (knight2) on 60%; 100–250 on a further 60% | Implemented (`thrown_range`) |
| Knight1 attack | Facing: ≤ 80 `ataka` swing (strike 21), beyond `atakb` fireball (fire 20; blocked shot sidesteps) | Implemented |
| Knight2 attack | Beyond 80 `atakc` zap (fire 26). Within 80 its model has no melee clip: it runs in place (`runa`) and punches once per 800 ms loop | Implemented (sequence 411: in-place `runa` punch) |
| Zap | Two bolts at +100/+200 ms, each 5 within 90 units for three 100 ms ticks: at most 30 | Implemented |
| Sword glow | Lit while its enemy is in sight | Implemented (`sword_lit`) |
| Pain | Knight1: one 5% roll (`hita`; its own handler is never installed). Knight2: generic handler, two 5% rolls, limit 35. The acquiring hit skips the first | Implemented (sequence 410) |
| Death | Knight1 always `diea`; knight2 `diea`/`dieb` 50/50 | Implemented |
| Open questions | Knight2's 75% evasion after each zap and knight2's broken take cover (no map sets 512) are not ported | Open |

## Animation inventory (converted `.anim`)

`m_knight1`: `amba` 0–28, `ambb` 29–58, `ataka` 59–99, `atakb` 100–139, `diea` 140–164, `hita` 210–225, `runa` 247–260, `walka` 261–284. `m_knight2`: `amba` 0–29, `ambb` 30–75, `atakc` 76–118, `diea` 119–134, `dieb` 135–156, `hita` 157–172, `runa` 209–224, `walka` 225–244. All the clips used are present; knight2 has no `ataka`/`atakb` (Gold defect, handled as above).

## Verification (sequence 411)

- Implemented, not yet verified in game.
