# Trident: bot splash admission (sequence 579)

Reference provenance: Gold weapon trident behaviour; official GameSpot guide's
Episode 2 weapon and Medusa walkthroughs. This is a scoped bot-policy repair.

| Section | Contract and scope |
|---|---|
| Identity | `weapon_trident`, weapon 13; Poseidon's Trident, supplied rifle grip and projectile models. |
| Spawn | Existing weapon and trident-tip pickups; no change. |
| Goals and tasks | Existing owned projectile sequence; the bot must respect its declared 100-unit splash radius. |
| Animation | Existing `ready`, `away`, `shoot`, `amba`; no new clips or inventory dependency. |
| Timing | Existing class interval and release timing; unchanged. |
| Skill | Existing bot aim and shared handling; unchanged damage. |
| Perception | Existing target and lane queries. |
| Combat | Existing projectile has zero direct scale, splash scale one and radius 100. The missing splash-hazard declaration bypassed bot range and muzzle safety checks. Admit those checks through the class spec. |
| Audio and events | Existing fire, ready, away and blast sounds; unchanged. |
| Persistence | Existing owned projectiles; no new saved state. |
| Open questions | Full weapon parity and rendered animation/audio acceptance remain open. |

Animation inventory: no new dependency; existing class clips listed above.

Implementation is the class-owned `splash_hazard` declaration. Shared selection,
fire admission and lane checking consume this registry parameter. The muzzle
check now traces the class's actual projectile bounds instead of assigning every
blast round an artificial six-unit box. Trident tips use point collision; the
larger probe incorrectly rejected valid crouched shots from the Medusa altar.
The E2 replay exposed fatal self-hits with weapon 13 in
`aegis-direct-dial-17/`. `medusa-round-clearance-59/` verifies the post-boss battle:
all ten awakened monsters die, the real ending counter fires, both ending films
play and the party reaches Episode 3 with zero deaths. This is a scoped replay
from a normal post-boss checkpoint, not complete Episode 2 acceptance.

Sequence587 native297 adds a class-declared close-shot budget before the360ms
tip merge: at most three ordinary tips, including a conservative water bonus,
with the existing0.325 self-damage scale and an additional40HP reserve. The
shared pilot checks the supplied damage/speed and actual muzzle lane, retains
ally safety, and uses ordinary attack input when the budget permits it. The
weapon's actual self damage is unchanged; its existing scale now lives once
in the class spec. Low health, too-close origins and long-flight shots retain
the original veto. Debug178 passes those cases. Native298 also retains the
nearby-ally query for this allowance.

`cerberus-reviewed-close-splash194-343` records actual lethal Trident damage to
the boss during the approach, followed by travel through all five Medusa maps
without a death until the Medusa gaze. It uses the legitimate temple soul40,
not granted health or ammunition. Complete fresh Episode2 remains open.
