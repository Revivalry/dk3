# Native Zig weapons

The owner's explicit weapons rewrite overrides the general C game/client guidance
for this subsystem. Both native modules link Zig 0.16 weapon implementations.
The engine's existing C ABI provides collision, entities, snapshots, renderer,
audio, filesystem, generic model animation and damage services.

Every selectable weapon is a description module in its class folder, `src/classes/weapons/<weapon>/<weapon>.zig`
(`//! weapon-class: <name>`). It owns its data (`spec`) and the hooks for prediction,
firing, projectile contact and lifecycle, presentation, inventory exceptions and
restoration. `src/weapon_catalog.zig` aggregates the descriptions, dispatches optional
hooks with `@hasDecl`, and checks the required ones at compile time. The ownership
lint (docs/runtime-zig.md "Class contract") rejects weapon ids in shared code. Shared Zig components implement mechanisms; they do not choose an
attack from a weapon ID. There is no C combat implementation or C behavior-plan
interpreter in the build.

Prediction and server movement use the same Zig controller and concrete updates.
Server entity callbacks re-enter Zig directly. Client view animation players are
instantiated per concrete type. Weapon-owned actions override their transitions.
Per-weapon effects and bounded transient pools are reset on client initialization
and time reversal. Fire presentation uses the engine’s event-sequence replay suppression, preserving
distinct shots delivered in the same render frame.

Existing numeric IDs and engine snapshot/save fields remain the compatibility
boundary. Do not serialize Zig pointers or native struct memory. Persistent entity
references use stable IDs. The Metamaser decodes its existing save fields into a
named Cube/Lock representation; restoring an entity rebinds its owning type's
callbacks. Retaining the wire layout does not require retaining C execution.

Sequence587 repairs the stave's missing splash-hazard declaration. Gold
`dlls/weapons/stavros.cpp`, `meteor_touch` and its fragment touch, establish
radial explosions; the existing native class already implements that damage.
Its weapon description now admits the same close-impact and party safety
checks as other explosive weapons, with a200-unit declared planning radius.
The actual impact damage/radius still uses the class's existing runtime tuning.
Debug51 passes546/546 after this metadata and the proximity-door query repair.
Later Dungeon combat and the complete weapon presentation matrix remain open.

The later Dungeon replay also exposes the stave table's range200 as a blast
radius rather than its flight reach. Applying that number to bot firing range
while rejecting splash inside200 leaves no useful firing interval. The stave
class now declares bot reach2000; its shot still passes actual projectile-hull,
impact and ally checks. A class-owned regression admits a shot at600, rejects
one inside199 and keeps the stand-off outside the blast. The repaired221 build
and Debug120 checks pass; `dungeon-stavros-flight-reach-01` kills the three
upper-room guards that previously remained undamaged.

Sequence587 native226 connects generic projectile, C4 and cube launch direction
to the existing ballistics convergence policy. A close crosshair hit can lie
behind the offset muzzle; substituting the view direction misses it. Ion
already used this policy. All-module226 and Debug126 pass; the connected
crypt return replay is still required to establish the observed encounter fix.

The connected implementation pass is complete. Integrated native builds, the shared
prediction/inventory contracts, all 28 authoritative firing paths, representative
restoration and liquid-contact scenarios, and the broad suite have been exercised.
[Sequence 200](../specs/runs/RUN-dk3-independent-port.md#weapons-gold-review--sequence-200)
records the latest inputs, repaired failures and precise remaining acceptance limits,
including corrections to earlier assertion and submerged-player evidence. Full
weapon parity and game completion remain open; see [current status](status.md).

In Zig, each source file is a concrete struct namespace type. `registry` registers
those types, and `inline for`/`@hasDecl` check and instantiate their methods. There is
no behavior opcode to interpret and no inheritance hierarchy. Shared mechanisms
accept a compile-time weapon type and call its methods; they do not switch on named
weapons. Stateful view players use `View(Weapon)` instances. Weapon owners alone
interpret their persistent controller fields; the named save schema and snapshot
layout are adapters to the engine, not a second implementation.

The Gold review in sequence 200 adds optional relative-time `dk_weaponholduntil`
and stable-ID `dk_weaponparentid` save fields. Missing fields default to zero.
Weapon controller links must use `weaponParentId`; `parentId` is exclusively a
mover attachment and is validated as such. Ballista, Wyndrax and Metamaser launch
delays are ordinary saved controllers, and reconstruct current player aim when
the authored fire frame arrives.

Sequence587 repairs the Ballista's class-supplied bot safety metadata. Its
existing authoritative removal applies half-damage splash within128 units;
Gold `ballista.cpp` also supplies physical launch recoil through `weapon_kick`.
The class now declares `splash_hazard`, so shared weapon selection and muzzle
clearance apply their existing close-range and party safeguards. No damage,
radius, recoil, timing, animation or save representation changes. Dungeon B
exit continuation02 survives the encounter that killed01, but then stalls on
a separate switch-priority defect; this is not complete encounter acceptance.
The authored weapon preference can use a smaller, checked firing margin than
autonomous selection, while actual muzzle-impact, self and ally blast checks
remain mandatory. Injury alone no longer discards an explicitly selected safe
shot. `cell-fight-02` clears the barred Dungeon cell with the Ballista from the
back edge of its corridor, then collects the fragment after the Silverclaw duel;
zero deaths. The released-guard retreat remains under repair.

Metamaser packs lock deadlines relative to the entity birth time, which the save
codec already rebases. Slot 31 distinguishes that representation from legacy
absolute deadlines. Legacy cubes retain phase, health and charge state while
re-acquiring locks after restoration. [Sequence 200](../specs/runs/RUN-dk3-independent-port.md#weapons-gold-review--sequence-200) records the focused Gold review and acceptance.
