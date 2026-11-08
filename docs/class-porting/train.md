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
