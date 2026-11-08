# Venomous — Episode 2 bot handling (sequence 579)

Reference provenance: Gold `dlls/weapons/venomous.cpp`, `venomousUse` and
`venomousBite`, plus `VEN_BITE_DIST` in `venomous.h`; official GameSpot guide,
Lemnos niche and Medusa.
This repair changes bot admission and aim, not projectile or damage rules.

| Section | Contract and scope |
|---|---|
| Identity | `weapon_venomous`, weapon 11; existing Episode 2 weapon and ammunition. |
| Spawn | Real authored weapon niche and pickups; no grants or new flags. |
| Goals and tasks | The bot retains the existing close bite when ammunition is empty, within the class-declared conservative 128-unit reach. |
| Animation | Existing `ready`, `away`, `shoota`, `melee`, `amba`; this change adds no clip dependency. Complete converted inventory review remains open. |
| Timing and skill | Existing 400 ms close action plus recovery and normal attack scaling; unchanged. |
| Perception and combat | The known close plan supplies its actual muzzle origin and collision qualification. A wall or raised ledge in front of the victim requires closing, rather than holding a futile firing stand. |
| Audio and events | Existing fire, bite and impact events; unchanged. |
| Persistence | Existing inventory and pending strike state; no new saved class state. |
| Ownership | Removed an unused import of another weapon's policy. The class declares its own bot range; shared mechanisms use checked registry declarations. |
| Open questions | Empty-bite encounter replay, full projectile behaviour and rendered animation/audio acceptance remain open. |

`lemnos-courtyard-supplies-53/` physically opens both statue tiles and collects the
niche weapon. Its later statue fight fails, so it establishes pickup traversal
only. Final run168 completes all 19 Episode 2 maps into Episode 3 with zero deaths;
this establishes the connected headless route, while full per-weapon visual/audio
and reference parity remain open in [native acceptance](../native-acceptance.md).
