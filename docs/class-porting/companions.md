# Companions (Superfly and Mikiko) — review sheet

Sequence587, native352 scoped replay passed: preserve the shared pilot's
qualified flight through the companion sink as well as its qualified run-up.
Actual western-run-up probe598 records a safe forecast at211,715,-925 toward
225,535,-912; the sink's held-command drop forecast then replaces forward/jump
with a right sidestep. That command no longer matches the qualified flight and
returns the carrier to the rubble. The sink now leaves an active qualified
flight to its feedback controller; ordinary walking, coasting and unplanned
falls retain the bounded-drop guard. No collision or position is bypassed.
Strict probe599 passes both physical gaps from the actual563 failure save,
8/8 actions and zero deaths. Connected603 passes the first pillar but exposes
a second defect: Move changes to Stay while passing within24 units of its
destination in flight, cancelling the final landing controller. Native353
keeps Move until supported (or swimming) and the qualified flight has finished.
Connected605 passes both Dungeon A jumps, settles the carrier at171,266,-936
on actual support, crosses both timed gates and enters Dungeon B with zero
deaths through that boundary. Full fresh Episode3 acceptance remains open.

The connected incoming replay614 still fails the first pillar. Its trace
shows the same sink guard replacing a motor-qualified ground stroke toward
229,701,-936 with a sidestep before the next jump. Native354's attempt to defer
new corridor recovery until a sliced jump search finishes also fails in618;
that experiment is reverted. Native355 instead preserves a declared qualified
ground stroke through the held-command guard, alongside run-ups and flights.
Every stroke still receives the shared pilot's live motor/collision/hazard
qualification. Broad129 passes on355; incoming623 still fails because its
ground leg advances within12 units, before finishing its lateral correction
off the raised corpse. Native356 retains grounded legs until the controller's
two-unit arrival disk; jump transfers retain12. The existing stair-corridor
regression checks the early lateral handoff.356 passes the first incoming
pillar but exposes a second-bank completion while still coasting.357 keeps
Move until horizontal speed is at most48 as well. Incoming631 passes both
pillars, both timed gates, all Dungeon B encounters and the three C cranks,
zero deaths; its later supplied-node approach fails.636 passes the corrected
approach, Stavros, the complete C spiral/walkways and Castle A/B into Crypt,
zero deaths through those boundaries. Broad130 passes on357. A later Crypt
combat death remains recorded; no complete fresh Episode3 pass.

Sequence587, native225: a carrying companion can complete retaliation through
the existing contact response despite having no usable firearm. The retaliation
plan approaches the owner without requesting ranged fire or combat close-in
jumps. Contact still requires reach, a clear solid ray and the normal cooldown;
mercy stops damage at5HP and clears anger through the ordinary party mechanism.
`nharre-carrier-retaliation-recovery-01` records actual contact down to5HP,
followed by ordinary medicine collection. `nharre-recovered-party-pillar-landing-01`
brings the carrier across both pillars and into the Throne without deaths.
The bot can query a checked registry hook for party hostility; it cannot read
or change the hidden anger level. Debug125 runtime checks and ownership47 pass.
Fresh campaign and rendered retaliation acceptance remain open.

Sequence587 continuation, native155: the ground-corridor fallback now tries
nearby supported endpoints through the full motor, including local jumps when
compiled jump reachability is missing. These endpoints enter the same jump,
run-up, liquid and hazard qualification as compiled links. A qualified run-up
retains control of its takeoff instead of being cancelled by the second landing
guard. Closed doors receive a qualified near-side approach, and the existing
class-dispatched party-door contact follows the active corridor direction.
Door locks, remote controllers and physical collision remain authoritative.
`nharre-runup-guard-01` restores the carrier stranded near the Crypt entrance,
brings him through its descending stairs, ordinary door and pillar jumps, and
enters the Throne with no deaths. Later Throne progression fails. Debug75 passes
the native runtime checks, including a missing compiled jump with a safe local
endpoint and refusal of the same endpoint over harmful liquid. Fresh complete
campaign and rendered acceptance remain open.

Sequence587, implemented; scoped escort continuation passed: `SIDEKICK_Init` sets the standing
hull to `(-16,-16,-24)..(16,16,32)` for all party identities, including the
carrying companion. The class tuning hook now overrides the smaller AIDATA
model bounds with that hull. Movement forecasts and the authoritative motor
read the same class definition. Restored actors acquire the corrected hull
through the ordinary motor update once the expanded hull clears the world;
they retain the saved footprint while beneath a narrow lintel. Regressions
cover the table override and deferred expansion. `dungeon-companion-40`
crosses both catwalk jumps, settles on supported hallway floor, brings the
carrying companion through both timed gates and enters Dungeon B with zero
deaths. The cell lever is operated after the companion crosses: opening its
rotating leaf early blocks the second landing. This is checkpoint continuation
evidence, not a complete fresh Dungeon or Episode3 acceptance.

Sequence 580 repair, implemented; unverified: automatic required-party recall at
an exit now restores Follow instead of assigning an explicit Come destination.
The latter excluded ordinary stranded-follower recovery and pinned Superfly behind
the Icelab exit. A required follower more than 150 units away near that exit also
retains the existing eight-second no-headway recovery even when AAS reports a route
through blocked geometry. Visibility and hidden supported destination checks remain.
Required identities, living-state checks and the 150-unit admission distance remain
unchanged. Explicit player Come orders retain their existing
behavior outside automatic departure recall. No animation or save-field changes;
the existing departure regression now expects Follow. Scoped replay178 crosses
Icelab A/B/C into the Vault with zero deaths. Followers also retain a vertical
goal when above their leader: the previous one-sided settling test left Superfly
on the raised Vault platform indefinitely. The class-owned policy and regression
cover both directions; replay173 demonstrates the descending platform and both
cage rides. Complete campaign and rendered acceptance remain open.

Further sequence580 repair: a required follower near an exit prioritizes its
follow position before selecting a stationary firefight and uses a 64-unit
comfort limit there. The previous 112-unit trailing distance and combat hold
made the leader repeatedly cross the 150-unit admission boundary and back away.
`icelab-close-party-exit-242/` passes the formerly oscillating B exit and C into
Vault A (one combat retry elsewhere). Admission still checks the same living
identities and strict 150-unit distance. Aggregate verification remains pending.

Sequence 579 continuation: `athens-corridor-snapshot-62/` preserves a narrow-corridor
deadlock: Mikiko's navigation repeatedly requests a combat sidestep which reserves
44 of the requested 64 units, leaving insufficient passing room. The class's lane
yield now requests full clearance, or backs along the leader's heading when the
corridor is too narrow. Each candidate requires a clear hull and supported floor.
The shared standing-walk query tries level movement before raising the hull for
a step; its former compulsory rise falsely rejected low-ceiling corridors.
Ordinary movement/collision still perform the yielding. Loading that exact save in
`athens-corridor-clearance-63/` clears the blockage in 2.45 seconds with zero deaths.
No position changes or collision exemptions are used. Full Athens acceptance is open.

Later sequence579 evidence: a copied D return checkpoint leaves Mikiko hopping
on disconnected lower footing near the exit (`acropolis-party-bank-snapshot-154/`).
The co-op driver no longer repeatedly chases her raw position off its supplied
corridor. The existing class-owned catch-up timer now treats a routeless follower
over150 units away as stranded even below its ordinary512-unit separation rule.
It retains the eight-second no-headway interval, explicit-order exclusions,
visibility checks and hidden supported destination requirement. The normal
recovery and D-to-C seam pass in `acropolis-stranded-follower-recovery-157/`;
that longer run later fails combat and does not establish full acceptance.
No diagnostic placement or grant is used. The adapter's unconditional empty-melee
attack override is removed: ordinary empty-weapon strikes now retain the shared
pilot's lane, facing and reach qualifications. This does not remove authored
friendly-fire or delayed strike collision. The passing-clearance and catch-up
regressions pass in `runtime-checks-02.log`; full headless Episode2 pass159 retains
companions across every required seam. Final control/supply run168 completes all
19 Episode 2 maps into Episode 3 with zero deaths and retains the party throughout.

Sequence587 also corrects Come destination selection. Gold's `SIDEKICK_ParseCommand`
computes a forward point but selects its task destination through
`SIDEKICK_FindClearSpotFrom` near the owner. Native Come now searches around the
owner with companion hull clearance, sight, supported floor and liquid checks,
and refuses when no safe destination exists. Debug31 passes536 native tests,
including wall-facing, narrow-corner and missing-floor cases. Dungeon escort09
passes the previously unreachable rally before gate742; the subsequent timed
gate crossing remains failed and under repair. This is scoped evidence, not a
complete escort or episode pass.

The reference files are `dlls/world/Sidekick.cpp`, `Sidekick.h`, `items.cpp` (item permission) and `client.cpp` (carrying across levels). Provenance only.

The native code is `src/classes/actors/companions/` (brain, navigation, items, damage, triggers, pose) driven by the shared bot pilot (`mechanics/server/bot_pilot.zig`); the design is in [bots-zig](../bots-zig.md) and [coop-bot](../coop-bot.md).

| Section | Reference behaviour | Native status |
|---|---|---|
| Identity | Superfly, Mikiko and Superfly carrying Mikiko; single player only, one of each; carried across levels with health, armour and inventory | Implemented |
| Health | The aidata row over the class's 100, skill-scaled: retail Superfly 150, Mikiko 100; the 1.3 profile's rows give 5000 (Superfly carrying Mikiko 10000) | Implemented (sequence 413: was a fixed 100) |
| Talk nodes | Reaching one of its talk nodes (117 across the episodes) with its owner within 800 and in sight, a sidekick says the node's line once a level; full volume within 512 of the owner, fading to a tenth by 1500; Superfly then keeps quiet 1 s, Mikiko 5 s | Implemented (sequence 414: "reaching" is within 128, as native sidekicks route by area) |
| Items | Every authored item is off-limits to both until its spawnflags admit Superfly (1) or Mikiko (2); an ordered pickup ignores that; items that appear later are never sought; needs: health under 95%, better armour, episode weapons and their ammunition | Implemented (sequence 413: the permission was inverted) |
| Orders | Follow, stay, attack the looked-at monster; a hit while staying returns it to following (and fighting) | Implemented (sequence 413: a hit ends stay) |
| Run-from rules | Always keeps away from the column, medusa and cerberus; holding only a close-quarters weapon it refuses sludge minions, inmaters, ragemasters, deathspheres, battleboars, psyclaws, skeeters, lasergats, doombats, dragons, the knights and the bosses (each class's `sidekicks` trait) | Implemented (sequence 413) |
| `trigger_sidekick` | Only toggles a HUD panel (inverted test); never stops the sidekick | Implemented (sequence 413: it used to disable the AI) |
| HUD flaps | `cl_scrn.cpp`: a flap for each sidekick in the player's view, Mikiko bottom left and Superfly bottom right, fading in and out (0.04 a frame to `statusbar_alpha` 0.6). Face by health in fifths (`calc_faceframe_index`), red health and yellow armour bars (3 wide, 100/2.8 tall), and an ammunition gauge (`SIDEKICK_GetAmmoCount`: 75%/35% Mikiko, 75%/40% Superfly; a weapon without ammunition plenty at range, low in close quarters). Server stats from `SetMikikoStats`/`SetSflyStats` | Implemented (sequence 422): the party's `status` session hook packs each member's presence, view (PVS), health %, armour % of the worn armour's capacity and gauge into player-state stats 8–11; `companion_hud.zig` draws them. Invisibility and invulnerability faces are not shown (sidekicks carry neither natively) |
| Command window | `cl_selector.cpp`/`draw_sidekickcommand_info`: the commanded sidekick's portrait over GET, COME, STAY, ATTACK, BACK OFF; selector keys step and apply; `sidekick_swap` changes who is commanded; the window fades in, holds, then fades out | Implemented (sequence 422): `sidekick_next`, `sidekick_prev`, `sidekick_apply`, `sidekick_swap` (default keys Z, X, V); the window holds 5.25 s after the last key and takes the weapon list's column while open |
| Orders | `SIDEKICK_ParseCommand`: get (the item the owner looks at, 800 units), come (a checked clear spot near the owner, then follow), stay, attack (the enemy the owner faces; otherwise only willing to fight), back off (no attacking, keep with the owner); each answered with a voice line in the owner's PVS (`cmd_mi_*`, `cmd_su_*`; a refusal says no, a refused pickup `_n1`) | Implemented (sequence 422; Come clearance corrected587): `come` and `backoff` orders; `sidekick_<order> [who]`, `companion <order> [who]` (the default binds' follow/wait/attack/pickup now work) and `sidekick <who> <order>` |
| Death | Drops its weapon; the game is over, the camera on the sidekick | Implemented |
| Documented deviations | Combat by the shared pilot (strafing, dodging, scored weapons) instead of planting and shooting; side-by-side following instead of the chain; it also engages hostiles it sees (the reference reacts only to attackers); a wider item scan | Recorded in bots-zig |
| Automatic puzzle assistance (owner requested) | A free companion takes nearby visible companion-only stations, physically steps onto them and holds until the authored completion releases the station. Explicit orders, carrying and scenes take priority. | Implemented; sequence 571 verifies the actual plate/door chain, isolated-room held saves and authored release. Whole-region save/transport replay still fails. Class-owned offers through `companionDuty`; no concrete map/class branches in shared code. |
| Delayed weapon posture (sequence 574) | Companion weapon releases use the companion's own movement posture, including crouch and eye height | Implemented; focused verification passed. `weaponMotion` supplies the current class motor through the actor registry. Shared delayed throws and melee never require a player component from a companion; save admission retains those pending actions. Native posture/save regressions and copied e2m4c arrival combat pass in software OpenGL/Vulkan; diagnostic placement and health, not a walked route. |
| Hazards and water (sequence 426, deviation) | The reference has no avoidance: `AI_CheckWaterDamage` only hurts in lava, slime and nitrogen, and a drowning sidekick walks to its nearest ground node | Careful footing in the shared pilot: lethal liquid is checked as far ahead as the body would slide (further on ice), on straight steering too; hops that would land in it are not taken; a slide toward it is counter-steered; in lava or slime it climbs straight out to the nearest dry floor. It treads water instead of sinking, rises to the surface unless a route dives, and a forward stroke no longer follows the aim pitch down. It is never settled under water, in water the leader is not in, or below its follow spot |
| Catch-up (sequence 426, deviation) | None: only authored teleport nodes move a sidekick (`SIDEKICK_DoTeleportAndComeNear`) | `companion_catchup.zig`: further than 1536 from the leader for 3 s; 8 s without getting 64 closer, either beyond 512 or in water the leader is not in; 2.5 s in lava or slime (or with no way out); or under water with 2.5 s of air left. It is put on safe footing beside the leader (behind first, then the leader's trail), where the leader sees neither the departure nor the arrival (a rescue from liquid may leave in view). Never under an order, a stop, an authored action, a cinematic or while carrying. Nitrogen contact stays fatal |
| Open questions | Stop nodes are implemented (sequence 375: they precede teleport nodes, hold without changing the order, and the first sidekick says the line); still open: teleport-node media, the second sidekick's 1 s stagger; a said line is not saved (a reload can repeat it); the remaining sidekick voice lines (yes/no permission questions); Hiro's exit-refusal voice line (sequence 507 implements centre feedback and the required sidekick running over); defending the other sidekick; ladder and look/kick idles; the Episode 3 freeze death | Open |

## Animation inventory (converted `.anim`)

`m_superfly`, `m_mikiko`, `m_mikikofly`: grip-specific idles, runs, attacks, pain and deaths (read by `companion_pose`). The look, kick and ladder idles are not used yet.

Automatic station duties use the same locomotion and idle inventory. They add
text acknowledgements rather than claiming a new recorded voice line. See
[sequence 571](../native-acceptance.md#sequence-571--companion-puzzles--automatic-station-duties)
for the exact save, fixtures and outstanding region failures.

## Verification (sequences 413, 414)

- Unit tests: item permission by authored spawnflags; talk volume and pauses.
- `--scenario sidekick-talk` (e3m1a): Superfly says his opening line `e3m1_sf_01a` once.
- Other changes: implemented, not yet verified in game.

## Verification (sequence 422)

- Unit tests: the status survives the 16-bit stat transport; window commands, default binds and acknowledgement names; ammunition gauge thresholds; face frames and the commanded sidekick; armour capacity.
- `--scenario sidekick-hud` (e3m1a): both flaps fade in; a 2000-point hit on Mikiko darkens her face and shortens her health bar; the window opens, steps to STAY and orders Mikiko (`why=stay`); after `sidekick_swap` it shows Superfly and his COME order moves him; `companion follow` orders both. Captures in `zig-out/reports/runtime-zig-422/sidekick-hud`.
- Not verified: the voice acknowledgements' audibility, the ammunition gauge in play (both sidekicks were unarmed in the probe), gameplay acceptance.

## Verification (sequence 426)

- Unit tests: stopping reach on ordinary and slick floor; lethal liquid seen ahead within the reach only; hops that would land in it; the nearest dry floor out of a lava pool; never settled under water, in water the leader is not in, or below the spot; catch-up timing (far, stuck, stuck in water, headway, eligibility, lava and air rescue).
- Passed: `sidekick-lava` (e3m3c), `sidekick-slime` (e2m5c), `sidekick-nitro` (e1m6c), `sidekick-water` and `sidekick-surface` (e1m1c), `sidekick-catchup` and `sidekick-stop` (e1m4b). Evidence is in `zig-out/reports/runtime-zig-426/`; details are in the run log.
- Not verified: slick-floor braking in game, an escape from lava by the sidekick itself (the scenarios kept him out of it), and gameplay acceptance over a campaign.

## Sequence 507 — required companions at a blocked exit

Reference provenance: Gold `dlls/world/Triggers.cpp`, `trigger_sidekick_detect`
and `AI_SIDEKICK_ALEXWANTSYOURASSTHERE`. A departure that lacks a required
nearby member explicitly calls that member to the player. The companion class
owns the request and its flag mapping; exits use the checked party hook.

Use the existing saved Come order and ordinary motor, clearing discretionary
collection, stopped/scripted pose and transient route state for a requested
living enabled member. Keep an already-current request instead of resetting
its route on every retry. Unrequested members keep their orders. Required
distance remains strictly below 150 units; no actor is teleported or spawned.

The connected headless e2m3b/e2m3c regression passes with the request active.
The unchanged user save also passes natural B-to-A movement and a save/load
while waiting in the exit. Player identity, health, inventory and ammunition
are preserved. Latest aggregate verification is recorded in sequence 507's
acceptance entry; full campaign traversal and refusal voice media remain open.

## Sequence 581 — physical passing and hidden anger

The requested anger policy is class-owned: five points per distinct owner hit,
five points of cooling per five quiet seconds, party retaliation at100 and an
exact five-health stop, followed by the supplied text rebuke. Delayed forgiven
party shots are cancelled before armor/impulse; no new recording is supplied.
Probe176 exercises both attackers, the mercy floor and save restoration.

Yielding now uses the existing supported stair rollout directly. A redundant
flat hull sweep previously rejected backing up one tread, locking two bodies
face to face. The regression covers a16-unit retreat step and an unsupported
gap. Live fixtures238/239 both pass the player; the earlier version hops above
the stair, while239 retreats to the supported floor without catch-up warping.
The shared pilot also preserves active body sidesteps when applying a cached
physical corridor. Frozen navigation replay234 retains the previous numerical
results; campaign follow/rejoin and existing catch-up rescues are separate.

Sequence581 follow-up280 also traces the owner's actual hull forward when a
companion is within96 units. This catches peripheral body overlap that the
centre-angle test misses and requests the same supported passing manoeuvre.
Replay282 completes first Aegis C through all remaining Episode2 visits and the
Episode3 arrival with zero deaths. Campaign completion and every physical rejoin
remain separate from this scoped passing evidence.

Sequence581 shared survival follow-up323 rejects a health detour that exhausts
its trip deadline while still moving without collecting the pack. It retains
the existing avoidance ring and eight-second pause, preventing immediate
reselection of the same failed destination. Native324/328 include the moving
timeout regression. Processing326 passes the previously failed Processing B
continuation and reaches Icelab A, where it later dies in combat; this is bot
route evidence, not a separate companion healing acceptance.

## Sequence 587 — ground links after a moving floor

The lowered Dungeon arena exposes a gap in the static area graph: the carrier
walked underneath the upper bridge rather than taking the completed spiral.
The companion pilot now caches an authored ground-node corridor when ordinary
routing reports no route. Each new leg projects onto live support and passes the
shared motor rollout, including the traveller's hull, stairs, liquids, hurt brushes
and persistent contact fields. Movement remains ordinary input. Dynamic blockers
remain solid; links do not operate controls or grant jumps or positions.

The cache is transient, resets with orders/maps/restores, expires after a stalled
leg and throttles failed searches to once per second. It applies to Follow/Come
outside authored stops, retaliation, collection and active combat. A regression
covers retaining the original corridor through a stranded hold, expiry and goal
replacement. Debug53 passes548 runtime tests; ownership07 remains zero.

Native173 extends recovery to ordinary partial endpoints: avoidance sidesteps
inside a64-unit pocket no longer reset the progress timer. Before sparse
authored links, a bounded local floor search retains multiple height layers at
each16-unit grid column. Its1024-node budget and192-unit horizontal envelope
bound work and memory. Every proposed edge sweeps the actual hull, requires
support with at most18 units of ascent or32 units of descent and rejects supplied hazards/liquids; the companion
still qualifies each live leg with its motor. Supported-point arrival requires
the actual stair height within8 units. Search exhaustion grants no movement.
`dungeon-carrier-stair-clear-01` climbs the previously stalled Dungeon B spiral
and crosses both upper gates; its later combat death remains separate. Debug86
and ownership24 pass. This does not establish the full navigation75% gate.

`dungeon-spiral-carrier-02` climbs from the moved arena floor to the upper bridge.
`dungeon-bridge-carrier-03` then escorts the carrier across the extended bridge and
exits into `e3m4a` with both companions retained and zero deaths in Dungeon C.
The later Tower approach still fails. These are checkpoint continuations, not
fresh complete episode or navigation-matrix acceptance.

Native133 makes an explicit Move/Come order request disembarkation rather than
letting the pilot's default riding intent override its destination.
`hideout-lower-landing-06` demonstrates Mikiko leaving264 onto supported lower
ground before208 calls the lift back, then remaining with Hiro through173;
zero deaths. The later final-window route remains unverified. Native135 also
rejects route-floor projections whose initial foot slab is embedded in a
solid floor, while retaining overhang-only recovery. Debug56 passes548.

Native161 preserves an authored STAY teleport into unsupported cinematic staging
space without running gravity there. A normal following teleport still waits
for supported footing. Supported placement and episode travel clear the parked
state, which persists through saves. `submarine-continuation-01` confirms both
gameplay companions stay near the authored e4m6c staging coordinates through
the hallway continuation instead of falling indefinitely. Debug80 adds a parked
motor/placement-release regression. This establishes headless state behavior;
rendered cinematic actor visibility remains a separate open gate.

Sequence587 native230/231 qualifies yielding at actual hull corners, including
supported32-unit descents, and keeps owner retaliation above yielding. Debug130
and ownership52 pass. `carrier-retaliation-yield-priority231-01` records the
actual final9→5HP contact, forgiveness and medicine recovery with zero deaths.
The Dungeon B continuation passes the stair corner and C admission. Dynamic
raised-spiral following still fails below the upper landing. Native232 retains
128 grounded leader footholds and tries their chronological corridor with live
motor qualification before stale authored nodes; it neither places the body nor
permits an unqualified jump. Implemented; affected replay pending.

The232 and234 spiral continuations still fail.235 additionally keeps footing
across normal orders, while placement/travel clears it and both cancel pending
firing; Debug134/server235 pass. The actual first obstruction is door1003,
closed behind the leader, not the spiral's shape. The canonical inside-lever
escort passes it in `stavros-entrance-inside-lever236-01`, requiring physical
carrier clearance before the boss. The carrier now reaches the spiral's gap;
its ascent still fails.238 admits nearby same-height trail entries through the
existing supported transfer path, with the shared pilot retaining jump
qualification. Implemented; no successful carrier ascent claimed.

Native240 repairs rejection of explicitly supplied32–64-unit transfers by the
shared jump candidate filter. `stavros-short-trail-transfer240-01` demonstrates
the real carrier gap, raised spiral and upper walkways without placement.
`dungeon-north-shooters-before-ammo241-01` also passes the northern stairs and
extended bridge. `dungeon-upper-gate-inside-come241-01` stands deeper in the
eastern room so Come's clear spot lies beyond the timed leaf, then brings the
party into Tower A. Zero deaths in Dungeon C; later Tower failures and fresh
complete-episode acceptance remain open. Debug138 repair and ownership59 pass.


Sequence587 native250 replays refine the route evidence. Keeping the carrier
on each supported spiral turn, with firing disabled there to avoid delayed
Ballista recoil, passes the actual gap and both revolutions in
`stavros-spiral-escort-without-recoil250-02`. Clearing upper-room shooters before
waiting passes the northern stair and bridge in
`dungeon-upper-room-before-carrier-rally250-02`. The final door130 requires an
actual crossed-side predicate and its opposite lever908; proximity alone accepts
the closed door's other side. A subsequent Follow formation can still return
through that doorway, so holding the admitted carrier until the leader leaves
the jamb is implemented/unverified. No fresh full Episode3 acceptance follows.

The251 developer3 diagnostic refines that hypothesis: the carrier crossed,
but projectile evasion moved Hiro back outside during a lever-release wait
without a stance. A stance and bounded inside-room arena, followed by clearing
the admitted room on Stay, pass the remaining Dungeon C into Tower A in
`dungeon-carrier-bounded-release-wait251-03`. The Throne then exposes a separate
hazard: following the rotating lift sends Superfly off the bank into lava.
Stay after the lower lever preserves his3406HP through the authored separate
lift sequence. `throne-carrier-wait-on-bank252-01` passes the Throne, Garroth,
timestream34 and completed Episode4 arrival with zero deaths. Fresh complete
Episode3 remains open.

Sequence587 native257 adds a bounded ring of supported yielding directions
after the six existing preferences. The exact blocked Dungeon spiral save
keeps the carrier enabled, alive3665HP and on Stay. The old256 controller
cannot clear Hiro's path within8 seconds;257 walks him through in2.1 seconds
with the same carrier health. Full-hull collision, support, step/drop and
hazard checks remain active. The curved-corridor regression and existing
narrow-lane cases pass in Debug155; ownership74 stays zero. This live
single-case result is separate from the250 frozen62-map controller metric.

Sequence587 native260 prevents automatic supply selection and retained automatic
item pursuits while a companion is on Stay or stopped. Explicit collection
orders retain their forced path. Debug160b passes a positive ordinary-health
item fixture proving both refusal and forced collection; ownership78 remains
zero. This repairs the mechanism behind the Processing niche escort detour;
that complete secret-pickup scenario remains under repair separately.

Sequence587 native291 preserves the16-unit hull while refining compact Come
placements by one/two units and checking separation against the owner's actual
body. Ronin running pace keeps the authored300 minimum before freeze scaling;
higher difficulty still scales upward. Debug171 and ownership86 pass.
`dungeon-nudged-carrier-pace194-292` demonstrates both broken spans, carrier
rallies and the remaining Dungeon A gates into B with zero deaths. That run
later times out at a barred-cell duel; it is scoped companion traversal
acceptance, not a complete episode pass.

Sequence587 native302, implemented; integrated traversal acceptance open: review of Gold's active
`SIDEKICK_Init` selects `MASK_MONSTERSOLID`; the adjacent `MASK_NPCSOLID` line is
commented out. The native class incorrectly selected the latter policy
(player/NPC clips, no monster clips). All three party identities now inherit
the shared live-monster default. Living actors rederive their current class
mask on restore; corpses retain their saved mask. This is a reviewed collision
policy correction, not permission to ignore clipping geometry. The failing
Stavros spiral escort remains the live acceptance case; native296's tighter
rally and same-floor Come preference did not complete it.

Native305 retains16-unit supported trail turns and prefers their motor-qualified
approach before a new floor search. Native307 also begins that recovery before
an unsupported raised approach, and qualifies follow spots with the companion's
actual collision mask. All307/Debug186 and the zero ownership baseline pass;
the live spiral remains under replay365. Earlier360/362/364 failures are retained.
The default stopped-brush forecast experiment303 is withdrawn after357 fails;
it is not part of307. Scoped Hideout boarding354 and late training-to-credits359
pass with both ordinary companions and real encounter/health inputs, zero deaths
through their respective accepted sections; these use302 before the later trail
changes and do not establish a full current four-episode companion pass.

Native311 extends the physical command guard to grounded coasting and bounds
unintended descents; a safe floor a storey below cannot substitute for the
requested stair. Debug189 tests stopped-contact braking and harmless lower-floor
rejection. All311 and ownership97 pass. Actual375 climbs both spiral revolutions
and the upper walkways with the carrier, no companion loss, before the player
dies at a later stair ambush. The ordinary follow distance is retained; rallying
requires real support on spiral37 and a32-unit height envelope. This is scoped
spiral acceptance, not the fresh four-episode companion gate.

Native312 adds an ordinary motor departure when standing on a living body and
the nearby requested landing is18–80 units below. The existing collision and
bounded-drop checks still qualify the command; no pose is assigned. All312,
Debug190 and ownership98 pass. Crypt380/383 pass the first head-standing stall
but expose a separate carrier obstruction in the player's jump run-up. The
authored route now parks the carrier on a surveyed bank through the ordinary
aimed Move command; current continuation388 passes both pillars and Nharre
into the Throne. Complete fresh episode acceptance remains open.

Crypt380 also establishes unintended owner-Wisp targeting as an anger trigger,
with an actual weapon19 damage receipt. Native317's class-supplied automatic
target role filter excludes story party members before generic Actor admission;
it does not exempt intended friendly fire from the anger rules. See
[automatic weapon targets](automatic-targets.md). All317/Debug195 and ownership99
pass. Current saved continuations387/388 preserve normal health, inventory,
orders and collision instead of granting progress or resetting anger.

Sequence587 fresh660 exposes a lane yield overriding the final Dungeon landing
while the carrier is airborne. Native359 defers yielding until supported and
outside an owned run-up/flight; a regression retains the landing intent through
airborne and brief edge-contact states. Integrated359 and Broad132 pass, R1–R11
zero. Its affected667 replay instead fails the earlier first pillar; no new live
landing acceptance is claimed. Read-only671 measures the carrier's full hull
on the corpse-adjacent run-up. Stricter staging672 catches Move completing on a
tread16 units above the requested floor. Native360 requires vertical proximity
within8 before Move completion; integrated build and gameplay replay are pending.

Native360 integrated build passes.674 replays the actual failed stage4 input and
passes both carrier gaps, the supported final bank and all Dungeon A gates into B.
The player later dies under zero-death repair limits:73/74 actions,183 simulated
seconds,30.0 wall seconds. Fresh E3/E4 replays677/678 and Broad133 are running;
the crossing pass is scoped and does not establish fresh complete episodes.

Native361 fixes an intermediate Move requested while the leader continues ahead.
Read-only inspection of696 finds the real first-pillar landing in the remembered
trail; the old newest-footing distance guard nevertheless discards the whole
trail after the leader advances beyond256. The class now retains its existing
prefix through the most recent observed footing near that requested landing.
It adds no destination point and retains collision/motor/jump qualification.
A native regression checks the retained landing, omitted later leader path and
refusal of an unobserved remote goal. Integrated361 passes. Actual failure-input
replay698 passes the return, both gaps, final bank and all A gates into B before
the hero dies later under zero-death limits:226/227 actions,115.0 wall seconds.
Broad134 and fresh episodes are running; full current acceptance remains open.

Sequence587 native363 follows the correct live756 carrier457 witness. Its
remembered route contains the real first pillar and a western approach bank54
units below the raised rubble, but the former48-unit transfer band skips that
bank. Supplied downward transfers now use the existing compiled-drop128-unit
limit, retain the48-unit upward limit, and still qualify support, the complete
motor flight and hazards. The shared pilot owns that bound and drop handling;
the class corridor declares its transfer through that mechanism. A motor
fixture reaches an actual54-unit lower platform and rejects129 units. This
batch is implemented; integrated build/affected scenario checks are pending.

Native363 integrated build and Broad135 subsequently pass, including the54-unit
motor fixture; ownership remains zero. Continuation759 passes both strict
Dungeon A gap/bank rallies and gates into B/C with zero deaths, then fails a
later C rally.765 repeats both A gaps after the Village coffin repair and fails
a later B blade-gate rally. This qualifies the affected A crossing on those
recorded inputs; fresh complete E3 and the later carrier failures remain open.

Sequence587 native367 continuation797 qualifies western Crypt parking outside
the owner's yielding lane. Fresh792's actual save shows the carrier still on
Stay but actively yielding into the first run-up, with Hiro standing on its
head. Read-only795/796 measure the supported western bank and order rays;
797 uses an ordinary Move there, then completes both Crypt pillars, Nharre,
Throne/Garroth and full E4 arrival with zero deaths:272/274 actions,149.7 wall
seconds. Stay's normal yielding behavior is retained. The route also parks the
party before the solo Village crypt stair after798 exposes a blocking follower.
These are route-specific acceptance results; complete fresh E3 remains open.

Sequence587 native368 adds grounded blocked-Move stasis recovery for the exact
fresh815 spiral stall.818 retains the saved Move and reproduces zero progress;
its nearby goal bypasses the older endpoint and raised-approach triggers.368
builds and819 starts recovery, but actual input stays zero despite a safe motor
forecast because the shared final stroke gate excludes settled mover supports.
369 checks the existing registry's current motion at that gate. The class
continues to own its stasis policy and only requests qualified corridor legs;
shared code names no class. Integrated369 passes; exact saved-order820 reaches
supported spiral footing in200 simulated milliseconds with no new order or
deaths. C821 passes the full spiral then dies in a later Dwarf encounter under
zero-death repair limits. Broad138 passes414 Python plus native/component
checks; formatting and ownership remain zero. Full fresh E4 run823 subsequently
passes on native369 with four ordinary recoveries and no companion losses.

Fresh825 loses the carrier on another spiral tread.826 reproduces the fall and
shows the class forecasting a walk toward one point, then steering at its
nearby supported arrival instead. Native370 stores the forecast target and
arrival separately; its walking stroke submits the original target and still
uses supported arrival/progress checks. The stair regression checks retention
and release of the distinct target. Integrated370 and Broad139 pass; formatting
and ownership remain zero.827 passes the full spiral with3637HP unchanged.
Fresh828 instead stops at Passage's narrow gathering stand;832's wider bank
preserves the90-unit check and passes both Dungeon A crossings into B.
Fresh833 later stops at Crypt parking after its carrier yields into an order
ray during the look action.842 rechecks the selected floor after aiming and
completes both pillars, Throne and full E4 arrival with zero deaths. This
driver correction preserves ordinary Move/yield behavior. Fresh native370 E4
run841 subsequently passes all maps, both finals and credits with zero deaths
and no companion losses.855's live B-gate trace shows the carrier admitted
before its Move finishes, then yielding west through the closing doorway.
856's deeper eastern landing prevents that return and passes the blade gate
and bend into the moving-blade stage.859 then qualifies aimed nearby bank
Moves for Passage members whose Come finishes outside the unchanged90-unit
gather. Each admitted member stays before the next is called. Fresh860 then
completes all E3 through full E4 arrival with zero deaths and no companion losses. The
90-unit gather and engine travel requirements remain unchanged. Native370
therefore has separate full E3/E4 zero-death headless passes; presentation and
combined-campaign gates remain open.
