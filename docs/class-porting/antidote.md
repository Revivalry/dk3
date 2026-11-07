# Antidote — sequence 579

Reference provenance: Gold `dlls/world/artifacts.cpp`, `item_antidote` and
`item_add_to_inventory`; `base/physics/com_sub.cpp`, toxin damage admission.
The official GameSpot guide's Medusa walkthrough requires bottles through the
poison river. Review found that the native pickup only cleared ailments.

| Section | Reviewed contract |
|---|---|
| Identity | `item_antidote`, supplied `models/global/a_antidote.dkm`; an ordinary admitted pickup. |
| Spawn | Existing pickup placement, visibility, bounds and respawn handling. No new flags or grants. |
| Goals and tasks | Collecting a bottle adds 100 protection points. Points stack. Episode 2 slime and poison damage consume them; the final protected hit is fully absorbed even when larger than the remainder. Further hits damage normally. |
| Animation | None; existing pickup presentation. |
| Timing | No protection deadline: damage consumes points. Poison retains its ordinary tick deadlines. |
| Skill | No class multiplier; incoming damage determines consumption. |
| Perception | None. |
| Combat | Protection applies only to toxic damage in Episode 2. Other episodes and ordinary damage leave the reserve untouched. It does not grant invulnerability or permanently cure an ongoing poison. Explicit protection bypass remains authoritative. |
| Audio and events | `artifacts/antidoteuse.wav` on an absorbed hit. Depletion text and inventory-icon presentation remain unverified. |
| Persistence | Optional default-zero class-owned points, embedded in the item-protection registry state. Negative saved points are rejected. No timer needs rebasing. Older native saves have zero points. |
| Open questions | Initial poison delivery damage needs separate class-by-class flag review; this repair marks ongoing poison ticks and measured slime damage. Full Episode2 river traversal passes in159; rendered depletion feedback remains unverified. |

Animation inventory: none.

The class supplies its acquisition and damage-absorption hooks. Shared pickup and
damage mechanisms dispatch through registries. Shared mechanisms do not inspect
the antidote's state. The old shared acquisition branch has been removed.

Policy regression covers stacking, episode restriction, ordinary damage, exact
depletion and absorbing the final complete hit. Scenario acceptance remains open
in [sequence 579](../native-acceptance.md).

`medusa-submerged-to-ending-63/` exposed an ECS query lifetime failure when an
absorbed poison tick created its sound carrier. Timed ailment dispatch now
collects entity handles and releases its query before damage hooks run, matching
the environment dispatcher. `medusa-flame-fields-65/` replays the affected save
through C, D, Medusa, the awakened waves and both ending films into Episode 3
without a crash or death. Full Episode2 pass159 subsequently traverses both
poison-river sections. Finite-charge and absorbed-tick regressions pass in
`runtime-checks-02.log`; rendered depletion acceptance remains open.
