# Event generator — review sheet

Provenance: `dlls/world/func_event_generator.cpp`, `func_event_generator_use`,
`func_event_generator_touch`, `func_event_generator_think`; `com->ValidTouch`
admits the player and sidekicks, while `ValidTouch2` also admits monsters.
Behaviour reviewed; no reference code imported.

| Section | Contract |
|---|---|
| Identity | `func_event_generator`, invisible authored brush; no animation clips. |
| Spawn | Flag 1 runs once, flag 2 enables touch, flag 4 admits other monsters. Numeric properties declare timed target events. |
| Goals and tasks | An admitted activator starts a sequence; active sequences cannot restart. Ordered events fire through normal target routing. |
| Timing | Authored event offsets and repeat wait use simulation milliseconds. |
| Skill | None. |
| Perception | Target use or an enabled touch volume. Players and companions admitted by default; other actors require flag 4. Dead actors may fire death targets. |
| Combat | No damage or weapon logic. |
| Audio and events | Authored sound at sequence start; each event's target owns its effects. |
| Persistence | Event list, cursor, activation ID, once/used state, start and ready times are saved. |
| Open questions | Full campaign audiovisual timing remains unverified. |

Animation inventory: none. Sequence 571 exercises the e2m4b companion-only
plate's event chain and return-route release with a copied owner save.
