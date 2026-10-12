# Gunners (seals and Uzi gang) — review sheet

The reference files are `dlls/world/sealcap.cpp`, `scomndo.cpp`, `sgirl.cpp`, `uzigang.cpp` and the generic AI. Provenance only.

The native code is `src/classes/actors/gunners/` (`gunners.zig`: choices, thresholds, pain limits, burst styles; `server/gunners.zig`: attacks; `server/actor_gunners.zig`: hooks). Bursts are the shared gunner bursts (`mechanics/policy/actors/bursts.zig`).

| Section | Reference behaviour | Native status |
|---|---|---|
| Identity | `monster_sealcaptain` (41), `monster_sealcommando` (91), `monster_sealgirl` (58), Episode 4 bases; `monster_uzigang` (15, e4m3) | Implemented |
| Weapons | Captain and girl: one shotgun trace, full damage to 256 then falling to 0 at 500. Commando: six-bullet chaingun bursts (two muzzles on `ataka`). Uzi: a stream until its frame 80. Bullets hit on rnd > 0.5/(skill+1) | Implemented |
| Commando | Ranged: chases into 350, stands and fires `ataka`/`atakb` 50/50; a blocked shot sidesteps | Implemented |
| Captain, girl, Uzi | Chasing fire (`atakb`); stand and fire `ataka` under 300 (captain, repeating while in reach) or 200 (girl once; the Uzi repeats only with its enemy out of reach yet in sight, the reference's inverted test); after a sidestep they return to chasing fire | Implemented (sequence 411: Uzi test, after a sidestep) |
| Strikes | One shot per authored attack frame; empty second-attack cells never fire | Implemented (sequence 411: the captain's and girl's running shot and the Uzi's standing stream no longer fire twice) |
| Pain | Generic handler, 20% rolls, limits 35 / 45 / 35 / 50 | Implemented |
| Death | Seals 50/50; the Uzi `diea` when a hit over 10 comes from within 45° in front, else `dieb` | Implemented |
| Take cover | Spawnflag 512 (2 captains, 4 commandos, 9 girls): shoots `ataka` only while its enemy is completely visible, rests 2–8 s after each shot, hides at the nearest hide node the enemy cannot see and now and then looks out (shared cover cycle) | Implemented (sequence 411) |
| Open questions | The commando's tracer; the Uzi's flash follows him (native) | Open |

## Animation inventory (converted `.anim`)

`m_sealcap`: `amba` 0–19, `ambb` 20–54, `ataka` 55–96, `atakb` 97–112, `diea` 113–137, `dieb` 138–172, `hita` 173–187, `runa` 214–229, `walka` 230–249. `m_scomndo`: `amba` 0–39, `ambb` 40–70, `ataka` 71–106, `atakb` 107–137, `diea` 138–163, `dieb` 164–184, `hita` 185–207, `runa` 229–244, `walka` 245–264. `m_sgirl`: `ataka` 60–117, `atakb` 118–132, `diea` 133–154, `dieb` 155–182, `hita` 183–197, `runa` 228–242. `m_uzi`: `ataka` 60–84, `atakb` 85–100, `diea` 101–115, `dieb` 116–128, `hita` 129–147, `runa` 205–220, `walka` 221–244. All present.

## Verification (sequence 411)

- Implemented, not yet verified in game.
