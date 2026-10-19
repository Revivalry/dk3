# Armed prisoners — review sheet

The reference files are `dlls/world/blackpris.cpp`, `whitepris.cpp` and the generic AI. Provenance only. The unarmed prisoners are in [civilians](civilians.md).

The native code is `src/classes/actors/prisoners/` (`prisoners.zig`: reach, choice, pain; `server/prisoners.zig`: attacks; `server/prisoner_rocks.zig`: thrown rocks; `server/actor_prisoners.zig`: hooks).

| Section | Reference behaviour | Native status |
|---|---|---|
| Identity | `monster_blackprisoner` (87) and `monster_whiteprisoner` (104), e4m1–e4m2, aidata 135 HP; punch 5 + rnd·10, reach 64; rock 5 + rnd·10 at 600 u/s | Implemented |
| Reach | Within 64, or 350–500 on a 10% roll (re-rolled) | Implemented |
| Attack | Under 207 a punch (`ataka`/`atakb`/`atakc` by thirds), else a lobbed rock (`atakd`) on a ballistic arc; at a clip end within 64, 30% evasion when targeted | Implemented |
| Punch sound | `m_punchc` whenever the punch's trace hits anything, walls too | Implemented (sequence 412) |
| Pain | Generic handler: black 10% / limit 35, white 20% / limit 40 | Implemented |
| Death | `diea` for hits under 20 or on 30%, else `dieb` | Implemented |
| Decisions | A rock thrown straight down is dropped (the reference divides by zero); a 1 s re-admission gate after a chase-admitted attack (negligible) | Decided |

## Animation inventory (converted `.anim`)

`m_bpris` / `m_wpris`: `ataka`, `atakb`, `atakc`, `atakd`, `hita`, `diea`, `dieb`, `runa`, `walka`, idles (`hitb`, `jumpa` unused). All present.

## Verification (sequence 412)

- Implemented, not yet verified in game.
