# Exit behavior review

Identity: `trigger_changelevel`, an authored brush volume. No model animation,
attack, perception or skill scaling. Brush bounds and target routing stay shared.

Reference provenance: Gold `dlls/world/Triggers.cpp`,
`trigger_changelevel_touch`, `trigger_sidekick_detect`,
`trigger_changelevel_message_reset`, and `trigger_changelevel_use`.
This records behavior; reference implementation is not a build input.

Spawn and goals: authored destination/start/cinematic and companion flags retain
their existing meaning. Required living companions must be within 150 units.
Missing companions produce a center message, and sustained contact becomes
eligible again after 2500 simulation milliseconds. Preserve locks, the normal
activation router, cinematic departure and ending behavior.
On a companion-distance refusal, the party's checked hook calls required members
to the player using their existing saved Come order, ahead of discretionary
combat/collection. Reference provenance also includes
`AI_SIDEKICK_ALEXWANTSYOURASSTHERE`; no reference implementation is imported.

Animation inventory: none. Audio/event change: center feedback only, with the
same retry interval limiting repeats. No new media or actor-specific names.

Persistence: keep the existing exit latch and rebased `ready_ms`; no new field
or save schema. Refusing a party clears the latch and arms the cooldown, so a
save made while waiting can retry after reload. Arrival-disarmed latches stay
disarmed until the player leaves the brush, preventing immediate return travel.
Dead/frozen players do not create ordinary touch requests. Old saves already
latched by the defective refusal still need an exit/reentry; this patch does not
guess whether an old latch meant arrival protection or a rejected departure.

Implementation: contact and retry behavior belong to the exit class. The shared
contact mechanism dispatches the optional checked `touchAuthored` hook, removing
its direct reads of exit state. Required-party checks use the session registry.

Verification: copied e2m3b save, delayed companion catch-up, natural B-to-A
movement and a save/load while waiting pass headlessly. A separate explicitly
controlled fixture at the authored B landing passes B-to-C with actual party
summons and unchanged proximity checks. Arrival overlap has an ECS regression;
full campaign cuts and traversal remain open.
The first unchanged-installation replay confirms a refusal followed by Mikiko
within roughly 136 units while the player remains inside an inert latched exit.

Final connected qualification: build 90/90; aggregate 57/57 steps, 553 native
contracts plus C contracts and 383 Python tests. Both natural return and
controlled forward cases pass on frozen runtime-summon, with a blocked-state
save/load and stable arrivals. Evidence remains local under sequence 507.

Sequence 567 requalifies both crossings with the integrated parallel-loading
rewrite. `qualification-natural-final` passes the natural refusal, blocked-state
save/load, companion catch-up and stable B→A arrival. Prepared-cache and raw-GPU
scenarios pass controlled B→C, save/reload and renderer restart. These guarded
software runs preserve the authored proximity check; full campaign cuts remain open.
