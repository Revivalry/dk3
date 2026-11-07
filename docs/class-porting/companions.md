# Companions (Superfly and Mikiko) — review sheet

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
| Orders | `SIDEKICK_ParseCommand`: get (the item the owner looks at, 800 units), come (a clear spot 64 in front of the owner, then follow), stay, attack (the enemy the owner faces; otherwise only willing to fight), back off (no attacking, keep with the owner); each answered with a voice line in the owner's PVS (`cmd_mi_*`, `cmd_su_*`; a refusal says no, a refused pickup `_n1`) | Implemented (sequence 422): new `come` and `backoff` orders; `sidekick_<order> [who]`, `companion <order> [who]` (the default binds' follow/wait/attack/pickup now work) and `sidekick <who> <order>` |
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
