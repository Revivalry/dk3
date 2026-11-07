# Debris contact forecasts (sequence 581)

Reference review: private Gold `dlls/world/MISC.CPP`, lines 499–524,
632–670, 789–807 and 908–925. Semantics only; no source is imported.
The authored brush fragments retain activation, delayed hull expansion,
gravity, bounce, spin, contact damage proportional to speed, activator credit
and finite lifetime. Animation inventory: brush transforms only; no new clips,
models or audio.

The class now supplies a transient contact forecast through the hazard registry.
Sixteen ballistic chords include observer motion and the pending hull expansion.
The shared bot mechanism consumes the checked hook without naming the class.
This adds no immunity, health, ammunition, teleport or damage reduction.

`catacombs-self-damage-371` preserves the failure: the bridge continuation
receives raw 170 damage at 1750 ms and raw 84 at 3950 ms. These are falling
debris contacts, not landing or environmental damage. Native377 passes the
ballistic observer-motion and transient-corridor regressions. Live378 crosses
the same bridge continuation into Catacombs C at86 health without either debris
hit. Its later skeleton death is retained; this is bridge acceptance only.
