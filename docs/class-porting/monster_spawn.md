# Monster spawn factory

| Section | Reviewed contract and native decision |
|---|---|
| Identity | `target_monster_spawn`; no model or actor kind of its own. Resolves its supplied class through the catalog. Private provenance: `target.cpp`, `target_monster_spawn_use`; `com_sub.cpp`, `com_SpawnDynamicEntity`. No reference source is admitted. |
| Spawn | Copy authored monster properties, map `muniqueid` to `uniqueid`, retain death outputs, inherit flags from an activating actor when present. Consume the factory after spawning. Preserve the small collision epsilon. Native robustness: a body initially intersecting solid geometry may use the existing collision separation mechanism within48 units. A clear authored origin stays unchanged. The rotated thief statue plus the live hull needs44.3 units of horizontal separation during the activation frame. |
| Goals and tasks | One activation creates one actor or item; no AI tasks belong to the factory. The spawned class owns its AI. |
| Animation inventory | None. Spawned classes own their converted clips. |
| Timing | Immediate activation; no independent cooldown. |
| Skill | Spawned class/catalog tuning; no factory multiplier. |
| Perception | None. |
| Combat | None; forwards `deathtarget` and `spawnname` for the spawned actor's normal death handling. |
| Audio and events | Optional authored spawn sound. |
| Persistence | No new saved state; consumed factories disappear normally. The spawned actor keeps its normal state and identity. |
| Open questions | The reference preserves the authored origin plus an epsilon. Native full-hull collision can leave the final Medusa thief embedded in brush107. Bounded separation is an independent placement safeguard, not a claim of exact Gold placement parity. If no nearby separating plane exists, retain the original pose and emit a diagnostic; broader invalid-map recovery remains open. |

Implementation and metadata tests live in the class folder. Collision separation
already has bounded-plane/corner tests in core. Sequence587 native347 replay574
passes the actual Medusa awakened-monster wave, ending counter and full Episode3
arrival with zero deaths. Native348 replay580 and native350 replay587 repeat that
ending after the complete Temple continuation, also with zero deaths. These are
saved continuations; fresh current Episode2 acceptance remains open. No scenario
command grants actor positions or outputs.
