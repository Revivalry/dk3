# Train — review sheet

Sequence 580, `episode1-handoff`: blocked trains were applying authored crush
damage every simulation tick. Review of the private Gold `train_blocked`
contract establishes a 500 ms interval shared by that train's blocking contacts.
The reviewed default is 10 damage when no nonzero damage is authored; the prior
native fallback of 2 prolonged live blocking contacts. Existing saves retain
their recorded damage. The independent implementation keeps this cooldown in the train's own saved
state, rebases its deadline on restoration, and admits older native JSON saves
through the field's inactive default. No reference implementation is imported.

| Behavior | State |
|---|---|
| Repeated blocking contacts | Implemented; aggregate verification pending. Class policy test covers twenty 50 ms ticks, interval boundaries and authored damage. |
| Save/restore during cooldown | Implemented; aggregate verification pending. Native snapshot roundtrip checks the rebased deadline. |
| Nonblocking corpse under a cart | Scoped passed. Run273 identifies a dead Crox holding the sewer cart against the world; run274 completes the repaired return and crosses into Sewer B. Shared pusher collision excludes bodies outside the player-solid mask, with a regression distinguishing corpse and live body contents. |
| Vault moving-platform crush scene | Scoped passed in runs225/230, both zero-death continuations into Episode 2. Earlier runs211/212 retain the per-tick damage failure; runs214/215 observe the corrected interval before separate route failures. |
| Presentation | Existing moving/arrival sounds remain; no animation changes. |

Sequence587 reviews Gold `DOOR.CPP`, `train_next` and `train_check_rotation`:
a final path corner can rotate the train without another destination. With no
translation or supplied angular rate, finite rotation defaults to90 degrees
per second. The native class previously paused at the last positional arrival,
omitting that final turn. Dungeon C's spiral consequently stopped180 degrees
away from its authored walkway. Terminal turns now run as a stationary motion
leg after the preceding dwell; they do not emit a second positional arrival or
its targets. No new saved fields or assets. Native127 retains the final corner
identity for subsequent deliberate uses; it supersedes126's identity-discarding
version. Debug50 passes546/546, including turn timing, endpoint, single arrival
and a subsequent use. `dungeon-upper-bridge-01` climbs the completed spiral and
crosses onto the upper bridge with zero deaths through that section. Its later
combat death remains recorded; this is not complete Dungeon acceptance.

Native136 also reviews Gold `train_next`'s path selection and departure-target
contract. A relay can share a path corner's target name. The native lookup now
selects the corner among all matches, rather than rejecting the first relay.
Departure queues the previous corner's ordinary target dispatch exactly once;
its saved identity is remapped on restore. This retains delays and linked
controls without granting any target activation from a route script.
`tower-train-targets-01` completes the lightning control, passes the previously
blocked gate and rides the crypt lift without deaths; its subsequent crypt
door approach fails. Debug57 and the dedicated build pass; ownership09 remains
zero for R1–R11. Fresh campaign regression coverage remains required.
