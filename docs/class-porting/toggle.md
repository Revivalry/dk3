# Toggle volumes — review sheet

Reference provenance: `dlls/world/Triggers.cpp`, `trigger_toggle_touch`,
`trigger_toggle_think`, `trigger_toggle`. Behaviour reviewed; no reference code imported.

| Section | Contract |
|---|---|
| Identity | `trigger_toggle`, invisible authored brush; no animation or model clips. |
| Spawn | Flag 8 accepts companions only; flag 4 also admits companions; flag 1 fires again on departure. |
| Goals and tasks | First admitted occupant fires the target chain. Other occupants cannot replace it. Departure rearms it. |
| Timing | Occupant departure checked every 200 simulation ms against the authored radius. |
| Skill | None. |
| Perception | Physical overlap; no remote activation. |
| Combat | None. |
| Audio and events | Authored targets own effects and audio. |
| Persistence | Occupant ID, center, radius and ready time survive saves. |
| Automatic companion duty | Owner-requested improvement: companion-only volumes advertise a physical station through a checked registry hook. The companion holds until the authored target chain is removed. Explicit orders and scenes take priority. |
| Open questions | Future companion-only stations whose completion does not remove their target chain need their class to supply an explicit completion contract. Never substitute a timeout. |

The supplied campaign corpus contains one companion-only toggle: e2m4b's
`leftevent` station. `openformk` removes that event generator and the depressed
plate after the player opens the return route. That authored removal releases
the automatic duty. Animation inventory: none.
