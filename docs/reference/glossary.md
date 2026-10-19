# Glossary

**AAS**
: Area Awareness System navigation data used by ground actors and multiplayer bots.

**Asset generation**
: A completed set of converted packages identified by its inputs and converter settings.

**BSP**
: Binary Space Partition map data containing geometry and collision information.

**Class**
: An actor, weapon, item or map-entity implementation with its own policy and adapters.

**Cvar**
: An engine console variable, such as `cl_renderer` or `r_fullscreen`.

**ECS**
: Entity Component System. Runtime state is stored in typed components grouped by archetype.

**Installation**
: A generated directory combining a code build with a converted asset generation.

**Latched setting**
: A setting applied at the next relevant subsystem restart rather than immediately.

**Persistent ID**
: An object identity that survives save/load or transfer, independent of a recycled engine slot.

**PK3**
: A ZIP-format package read by the engine's virtual filesystem.

**Region**
: A set of connected maps prepared together for traversal.

**Resident world**
: A loaded map context with its own collision, rendering, gameplay and navigation state.

**Snapshot**
: A projection of server state sent to a client. A save snapshot is the separate persistent representation written to disk.
