# Mover: blocked movement attribution (sequence 579)

Reference provenance: Gold `dlls/world/DOOR.CPP`, blocked door handlers.
This sheet covers damage attribution and door grouping; complete mover acceptance
remains open.

Sequence587 control planning: sliding and rotating door declarations expose
their existing target-forwarding behavior through the registry relay trait.
The shared planner recognizes an unnamed manually usable mover as a control,
including an interior lift lever; named remote doors still require their
authored control. `waterfalls-return-07` operates the trolley's rotating lever97,
rides its real travel and opens cage101 at both ends. The same continuation
opens pedestrian door118 through upper lever191 before descending. Timed use
observations include the mover return deadline, so refreshing an already-open
control is distinguishable from a missed press. Native regressions cover relay
metadata, manual-control eligibility and refreshed deadlines. Rendered/audio
acceptance and complete campaign traversal remain open.

Sequence 579 continuation: Gold `DOOR.CPP` `TouchingDoor`/`DoorFindTouching` and
`common.h` link touching leaves unless flag4 forbids linking. Repeated editor
team names do not link distant door pairs. Athens C reused `golddoor` for the
entrance and the far exit; the native global team grouping made the bot seek the
entrance when blocked at the exit. Door groups now derive from touching closed
bounds and retain separate target names, including on save admission. Overlapping
plates130/584 in Acropolis B have independent control names: linking them caused
`acropolis-plate-main-room-116/` to crash when one was removed. The equal-name
guard and its regression preserve those independent controls. Other teamed movers retain their existing
grouping. Motion, angles, damage, sounds and deadlines are preserved. A regression
covers two distant pairs sharing a team and an unlinked leaf. The grouping,
independent-control and swing regressions pass in sequence579's native checks
(`runtime-checks-02.log`); the full headless Episode2 pass159 traverses these doors.

The same Gold `door_open` review covers ROTATE_SWING (flag512): each leaf
chooses its opening sign from the user's position and view-right vector.
The native mover previously ignored this flag and always used the authored
positive end, allowing a paired leaf to swing into the approach. Each accepted
opening now recomputes that leaf's authored endpoint before choosing its sign;
closing still returns to its saved closed end. A pure opposite-leaf regression
passes in the consolidated native checks. `acropolis-pickup-lanes-110/` traverses the formerly blocked
Acropolis A doors into B with no death in A, with the swing and pickup-lane
repairs connected. Full headless Episode2 gameplay subsequently passes in159;
rendered/audio mover parity remains open.

| Section | Reviewed behaviour and native decision |
|---|---|
| Identity | Registry mover class; brush models and existing class declarations own the admitted door, platform and rotating brush variants. |
| Spawn | Existing authored keys and flags remain authoritative; this change adds no spawn rule. |
| Goals and tasks | Closed, opening, open and closing. A blocked damaging brush attributes the hit to itself, allowing a victim's ordinary motor to escape. Blocking does not authorize a teleport or reversing the brush. |
| Animation | None; brush transforms follow mover motion. |
| Timing | Existing blocked damage cadence and motion durations are unchanged. Victim walking recovery is a shared pilot mechanism, held briefly to avoid immediately following an ally back into the sweep. |
| Skill | None for attribution; existing authored damage remains unchanged. |
| Perception | None for the brush. Its persistent identity accompanies the damage event. |
| Combat | Blocked damage uses the existing damage admission path with the mover as source. |
| Audio and events | Existing start, loop and stop events; no new media. |
| Persistence | Existing motion phase, endpoints and deadlines; no new saved mover state. Pilot escape is transient and recalculated from a new hit. |
| Open questions | Complete mover parity remains unverified. The closing Acropolis door trapping Mikiko is the acceptance case for this repair. |

Animation inventory: none (brush transforms).

Implementation: `src/classes/entities/mover/server/movers.zig` supplies the
persistent source identity. Shared physical escape considers moving solids through
components, tests supported collision paths and issues ordinary movement commands.
The motor never changes an actor's position directly.

Acceptance: scoped gameplay and native regression checks passed in sequence 579 of
[native acceptance](../native-acceptance.md).

Sequence581 supersedes the earlier ordinary-door obstruction policy above.
The owner requested physical pushes without obstruction damage. Ordinary doors
attempt the transactional swept push; blocked opening travel holds its clock.
A blocked closing door without the authored force flag reopens its whole group
from the committed transform. This motion reversal does not activate use targets
again. Force movers, platforms and water keep their separate policies. No saved
field or new animation is introduced. The hinge sign now follows physical leaf
motion away from the activator, independent of view yaw.

Rendered probe190 verifies paired leaves from both sides and unchanged player
and centurion health during closing pushes. Fresh E2 run217 exposes a separate
closing jamb trap at Aegis B door583. The blocked-closing reversal is implemented
in repair222 and awaits that saved-approach replay; the earlier push probe alone
does not accept the new reversal.

Sequence587 reviews Gold `DOOR.CPP` toggle/reverse target semantics after
Alcatraz's two-operation cellblock lever leaves the opposite passage closed.
Both deliberate directions operate the linked doors. The native class emitted
targets only at opening arrival, so returning the lever never restored its
targets. Door/water toggle and use-to-close arrivals now emit their return
targets too; an ordinary automatic return and a button release do not gain
another activation. This is a class-owned rule over the existing binary motion
mechanism, with no new saved field and no imported reference implementation.
START_OPEN swaps the endpoint labels, so obstruction recovery now identifies
physical closing before reversing; it never reverses physical opening into an
occupant. Neither repair introduces saved state. The flag/class and endpoint
regressions pass in the consolidated652-test run. Alcatraz continuations
`e4-41`/`e4-42` demonstrate the two-operation passage, cell release and later
third lever operation opening the yard, with zero deaths. Other door families
and complete episode traversal retain their separate acceptance requirements.

Sequence587 sewer continuation reviews moving-water spawn policy in Gold
`dlls/world/func_various.cpp`. With no authored wait, water holds at either end
and the next activation reverses it; it does not inherit an ordinary door's
three-second return. Its default speed is25 and lip is0. Explicit map values
remain authoritative. Native spawn now supplies those class-owned defaults.
Saved admission removes the erroneous implicit return and recognizes the old
eight-unit default lip, remapping the saved travel fraction (including
START_OPEN) without resetting the phase or emitting targets. Existing explicit
wait/lip/speed values are preserved. A focused regression covers hold, second
activation, old-save endpoints and an explicit wait. Sewer replay is pending.

Sequence587 also repairs support acquisition for resting pickups. The shared
brush transaction checks exact contact with the moved brush beneath each nearby
world-grounded visible pickup before moving. Existing item support poses then
carry it once; pickups remain nonblocking triggers and do not veto the brush
transaction. No saved fields are added. This restores the map-placed Stavros
staff rising with its platform, demonstrated in `stavros-support-diagnostic-01`;
collection and complete Dungeon traversal remain open. Debug46 passes544/544,
including support contact, hidden/unsupported exclusions and repeated settlement.

Native138 repairs an authored actor already overlapping a retracted brush.
The previous full-translation push moved the Hideout upper guard downward into
its fixed floor; the ladder consequently remained held forever. A non-rider
whose hull contacted the brush before movement can now resolve that existing
overlap from its original pose within18 units, using exact live collision and
the existing transactional rollback. New contacts, riders and deep overlaps
retain the ordinary push/refusal path. `hideout-pusher-overlap-01` lowers457 and
climbs both initial hub ladders; its later guard combat death remains failed.
Debug59 and the dedicated native build pass; ownership10 remains zero.
