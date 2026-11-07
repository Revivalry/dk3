# Discus: bot ammunition policy (sequence 579)

Reference provenance: Gold `dlls/weapons/Discus.cpp`, `discusUse`,
`discusMelee`, `discusShoot`, `discusThink`, `discusTouch`, `discusPickup`.
This sheet records the bot repair and existing class contract; full weapon
parity is not established by it.

| Section | Behaviour and native contract |
|---|---|
| Identity | `weapon_discus`, weapon 9, Discus of Daedalus; Episode 2 glove grip and supplied discus world/view/projectile models. |
| Spawn | Existing weapon pickup and projectile recovery; no new spawn flags or grants. |
| Goals and tasks | A shot flies, steers, returns, drops or becomes recoverable. Close contact can select the existing melee swing. Bots must allow the sole disc to be thrown rather than reserve it indefinitely. |
| Animation | Existing `readya`, `awaya`, `shootb`, `shootc`, `shootd`, `amba`, `ambb`; no new clips. |
| Timing | Existing 650 ms weapon interval, 400/350 ms raise/drop, 250 ms melee release. Bot deviation: wait up to 3000 ms for recoverable ammunition before abandoning a fight; this does not manufacture ammunition or promise a return. |
| Skill | Existing shared bot accuracy and handling; no damage or projectile changes. |
| Perception | Existing bot target selection and collision. |
| Combat | Existing thrown or melee release and native damage. Bot reserve is zero; the brief empty-ammo grace preserves an engagement while a disc returns. An empty weapon retains its normal close strike at a conservative 96-unit bot reach; the known strike plan supplies muzzle-origin aim and collision qualification. |
| Audio and events | Existing ready, away, throw, melee and impact sounds; unchanged. |
| Persistence | Existing class-owned flight timers, target and recovery state. Engagement's empty-ammo timer is transient bot state, not a new save field. |
| Open questions | Full projectile, melee, audio and animation parity remains unverified by the E2 route pass. |

Animation inventory: this repair adds no animation dependency. The existing
description names the clips above; a complete converted inventory audit remains
outside this scoped bot-policy repair.

Implementation: the class supplies `bot_ammo_reserve` and `bot_rearm_ms` through
the weapon registry, plus `bot_contact_melee_range`. Shared bots consume those parameters without naming the class.
Ordinary attack, collision, ammunition expenditure and catches remain authoritative.

Acceptance: implemented; E2 corridor and encounter replays are recorded separately
in sequence 579 of [native acceptance](../native-acceptance.md).
