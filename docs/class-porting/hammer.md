# Hammer: bot charge and damage admission (sequence 579)

Reference review: Gold `dlls/weapons/hammer.cpp`, delayed strike and
`hammer_radiusDamage`, lines 274–402; `hammer.h`, `HAMMER_DAMAGE_RADIUS`.
Provenance only; no reference implementation is imported.

The class owns `weapon_hammer` (12), its charge controller, delayed strike,
partial-charge radius damage and full-charge quake. The reviewed radius uses
the weapon table's range, falling back to 128. The supplied native table gives
256; the class keeps its conservative 110-unit bot engagement limit.
The bot releases its ordinary attack at the declared 900 ms charge;
damage, charge scaling, strike timing, ammo, self damage and quake behavior are
unchanged. An unused import of the sword class's policy is removed.

Animation inventory: existing `ready`, `away`, `shoota` and the existing charge
frames/timing. No new clips, models or audio are introduced. Existing saved
charge and delayed-action state remain authoritative.

`athens-column-fire-55/` preserves the guardian failure: the bot marked its
hammer ineffective and refused to fire it despite every alternative being
immune. Shared fallback now requires a damage-admitted alternative and clears
target-specific reservations when acquiring another target. The first encounter
passes in `athens-column-admission-56/`, but that run later fails in Athens B.
The target-admitted fallback, charge release/restart and ammo-free admission
regressions pass in `runtime-checks-02.log`. Full headless Episode2 pass159
includes the required Athens guardian encounter. Matched animation/audio and
all other class interactions remain outside that gameplay result.

Sequence581 changes only the class's bot charge preference from 900 to 1800 ms.
The official GameSpot guide's Hammer section describes charging before a close
strike and using the full-charge ground wave against living statues. The
player's existing charge/strike/quake implementation and damage remain intact.
`athens-full-hammer-161/` uses the optimized native engine/modules and a copied
campaign arrival: the guardian fight completes in 6.95 seconds. Its later
centurion death is retained; this is encounter evidence, not episode acceptance.
The release/restart regression now covers continuing at half charge, releasing
at full charge, and starting the next attack with the previous saved charge.

Sequence581 follow-up327 keeps an already started class-declared charge across
temporary aim/range loss; it still releases at the declared1800 ms. Charging
frames no longer count as individual ineffective shots. The shared mechanism
uses the catalog's charge declaration and names no weapon class. Native328
passes the charge/release regression. Athens329 defeats the real guardian in
4.65 seconds with a full-charge strike; its later centurion death is retained.
The player's strike, damage, quake and self-damage rules are unchanged.
