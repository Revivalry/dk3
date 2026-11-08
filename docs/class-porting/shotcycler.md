# Shotcycler bot engagement range (sequence 581)

Reference review: private Gold `dlls/weapons/shotcycler.cpp`, firing and pellet
trace semantics, lines 403–490. Provenance only; no implementation is imported.
Existing native animation inventory remains `ready`, `away`, `shoot`, `ambc`.
The six-shot burst, pellet cone, damage, inertial hits, ammunition and player
trace distance are unchanged.

Processing replay417 selects this weapon against a ceiling turret roughly620
units away. It spends repeated bursts for approximately7 damage per attack and
dies under continuing return fire. The class now declares384 units as its bot
engagement limit; the shared selector already consumes that checked declaration.
The regression keeps the spread weapon in hand, requires a ranged alternative
at620, and retains the spread weapon at192. The unused cross-class sword import
is removed. Native420 passes. Processing421 passes the earlier distant turret
section, then dies later in the upper hall; it is not a complete map pass.
Prison425 leaves the cramped lift before fighting, passes Prison A/B and
Crematorium A/B/C and reaches Processing without a death. Fresh episode
acceptance remains separate.
