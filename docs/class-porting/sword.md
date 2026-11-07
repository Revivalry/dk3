# Sword — Episode 2 bot handling (sequence 579)

Reference provenance: Gold `dlls/weapons/daikatana.cpp`, reviewed arc and swing
contracts; the official GameSpot Episode 2 guide. This repair changes bot handling
and starting equipment, without changing strike geometry, damage or timings.

| Section | Contract and scope |
|---|---|
| Identity | `weapon_daikatana`, weapon 8; existing global sword model. |
| Spawn | Fresh Episode 2 starts with the sword. The hammer remains an authored later pickup. |
| Goals and tasks | Close to a conservative 56-unit bot reach before swinging. A listed weapon range is not a reliable stand at the outer end of an animated arc. |
| Animation | Existing six swings and supplied ready/away/idle clips; no new animation dependency. |
| Timing and skill | Existing experience-dependent swing timing, strike deadlines and follow-through; unchanged. |
| Perception and combat | Class declares body-origin aim and held attack input for chained swings. Shared targeting and delayed melee resolution remain authoritative. A nominal first-swing trace cannot reject all other swing arcs. Firing stands use the actual face of a thin brush. A melee engagement holds its reach instead of applying a ranged retreat. |
| Audio and events | Existing class fire and contact sounds; unchanged. |
| Persistence | Existing sword experience and pending melee actions; no new saved state. |
| Open questions | Complete combat, rendered animation/audio and episode acceptance remain open. |

Converted `models/global/w_daikatana.dkm.anim` inventory: `amba` 0–34,
`ataka` 35–54, `atakb` 55–88, `atakc` 89–103, `atake` 104–138,
`atakf` 139–153, `atakg` 154–174, `away` 175–184, `ready` 185–196.

`lemnos-plank-face-38/` demonstrates actual destruction of the first crypt plank
with ordinary sword input. Its later spike-pit death rejects the complete run.
`lemnos-body-aim-46/` reaches the crypt with health75/armor101 and crosses the
pit, then fails in later combat. `lemnos-near-gates-50/` collects the drachma
after restricting off-corridor planner detours; its statue ambush remains failed.
Held-trigger replays improve individual kills but still exhaust the death cap.
These are scoped observations, not complete encounter or episode acceptance.
