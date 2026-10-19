# Rockgat — review sheet

The reference file is `dlls/world/rockgat.cpp` (a self-contained turret: no generic AI, aidata only for its model). Provenance only.

The native code is `src/classes/actors/rockgat/rockgat.zig` (policy: phases, raise/lower frames, bursts, double damage) and `src/classes/actors/rockgat/server/rockgat.zig` with `server/rockgats.zig`.

| Section | Reference behaviour | Native status |
|---|---|---|
| Identity | `monster_rockgat`, model `a1_rockgun` (`up` 0–10 only); 500 HP (map `health`), ±16 box, robotic, bloodless; map keys `height`/`frames`, `sound`, `sound_up`, `sound_down`, `fire_rate`, `range`, `basedmg`, `rnddmg`, `health` | Implemented |
| Spawnflag 1 | Toggle turret: starts disabled; `use` raises (or scans at once with height 0) and lowers it | Implemented (`State.use`) |
| States | Passive (a client within range raises it), raising (`up` 0→height at 100 ms per frame, first shot 1 s later), scanning (snap yaw to the target, fire when in sight and less than about 20° above), lowering (height−1→0) when it loses its target | Implemented |
| Fire | A trigger every 200 ms (0.13 s quantised by the 100 ms think): six bullets over about 500 ms, 1 + rnd damage each, hit roll 0.5/(skill+1); the shot sound every other trigger | Implemented (`bursts`) |
| Damage | Every hit counts double (its pain callback subtracts again); destroyed it gibs and vanishes, no kill credit to the player | Implemented (`painDamage`) |
| Open questions | Target choice is the first client in range, not the nearest (single player: no difference). A NOTARGET enemy stays locked | Recorded |

## Animation inventory (converted `.anim`)

`a1_rockgun`: `up` 0–10. The reference uses no other clip.

## Verification (sequence 406)

- Unit tests: raise and lower frames, bursts, double damage.
- `runtime_player_probe.py --scenario rockgat` (e1m1b): popup delay, contact, save and restore while raising, firing and lowered.
