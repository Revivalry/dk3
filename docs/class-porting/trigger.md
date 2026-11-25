# Trigger volumes — review sheet

Behaviour source: authored map properties and the official GameSpot guide's
Alcatraz vents and laboratory firing range. Original implementation; no reference
code or guide prose imported. Animation inventory: none; these are invisible
brush volumes whose targets own moving geometry, sound and effects.

| Contract | Implementation |
|---|---|
| Identity | `trigger_once`, `trigger_multiple`, `trigger_relay`, `trigger_counter` |
| Normal activation | Existing limits, target delays, locks and counters remain in the target router |
| Shooting target | Positive authored health creates damageable health and a hurt receipt; shot-only runtime box excludes player collision and touch activation |
| Completion | Reaching zero health invokes normal activation with the shooter's identity; spent one-shot targets leave collision, repeatable targets reset health |
| Cooldown | Damage during the saved trigger cooldown or after its limit is rejected |
| Saves | Existing health/uses/cooldown survive restoration; older saves acquire missing health from retained properties without rearming a spent trigger |
| Skills | Authored health does not change by skill |
| Acceptance | Sequence587 native regression checks pass; ordinary shots open Alcatraz targets373/139/375/377 after restoring an older save. Firing-range traversal remains unrun. Exact inputs and failures remain under `zig-out/reports/episode34-progression-587/`. |
