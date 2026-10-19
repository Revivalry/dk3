# Protopod — review sheet

The reference files are `dlls/world/protopod.cpp`, `skeeter.cpp` (the hatchling) and the generic AI (`ai_think.cpp`, `ai_func.cpp`). Provenance only.

The native code is `src/classes/actors/protopod/protopod.zig` (policy: hatch rule and phases) and `src/classes/actors/protopod/server/protopod.zig` with `server/protopods.zig`.

| Section | Reference behaviour | Native status |
|---|---|---|
| Identity | `monster_protopod`, model `m_proto`, aidata 50 HP, FOV 360, scale 2.5; robotic, bloodless, always gibs; falls under gravity; no pain (chance 0), no attack | Implemented |
| Spawn | Generic spawnflags; 16 stops sight acquisition (it still hatches when used or shot). Maps set `sight` 64–512; 14 pods are hatched by triggers | Honoured: 16; the `sight` key is its acquisition range |
| Acquisition | Sight with line of sight in any direction within its active distance (`sight` key, else 800); a hit from a player acquires the attacker | Implemented (sequence 406: the class no longer overrides the range with 512) |
| Hatch | Polled every 100 ms: a visible enemy within 200 units horizontally, or within 512 on a 5% roll. The hatch starts 100 ms later (the reference's 0.5–3.5 s random delay is dead code). `hatcha` once, a slaughterskeet rises from origin + 10 with the pod's enemy; at the clip's end the pod becomes an inert husk (health 1, small box) | Implemented (sequence 406: effective 100 ms delay) |
| Use | Triggered, it hatches at once | Implemented |
| Death | Always gibs (robotic) | Implemented (shared remains) |
| Sounds | `m_protohatcha` on hatching; ambient `m_protoamba` (10–40 s gate); no sight sound | Implemented |
| Open questions | A pod hatched by use while idle stays a full-health monster frozen on its last frame in the reference (task-order defect); native always leaves the inert husk. A pod whose enemy dies waits forever in the reference; native too | Decisions recorded |

## Animation inventory (converted `.anim`)

`m_proto`: `amba` 0–10, `hatcha` 11–22. All present.

## Verification (sequence 406)

- Unit test: the pod hatches once, on the think after it notices its enemy (near rule, far roll, no repeat after the husk).
- Implemented, not yet verified in game: the hatch delay and the `sight` range.
