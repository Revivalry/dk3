# Connected worlds

A campaign can connect several map files into one traversable region. dk3 keeps
each map as an owned world rather than combining their BSP geometry into one map.

## Map ownership

Each world has its own collision context, gameplay state, navigation, resources,
rendering data and persistent-identity namespace. An active engine slot or renderer
handle is temporary; saved references use the world's identity and persistent IDs.

This lets two maps contain objects with the same authored local identifier without
confusing those objects during loading or transfer.

## Admission

A region cannot release the player as soon as the first map has loaded. Collision,
gameplay, navigation and client resources for its required members must be ready.
The initial loading screen remains active while that work completes.

The server prepares resource descriptions, and the client acknowledges their
admission. A `collision_ready` message describes only collision data. The first
snapshot also does not mean the complete region has finished loading.

Preparing several maps increases initial loading work and memory use, but allows
movement within a ready region without loading each map at its boundary.

## Traversal

Connections come from authored exits, landing points and portal transforms. Map
names alone do not define a connection. At a passage, ownership changes while the
player keeps persistent identity, inventory and action state.

Some exits are cuts, such as cinematic or episode transitions. A cut can remain
held until its destination is ready. It does not need to behave like a continuous
corridor.

## Saving a region

A region save stores its active world, resident members and visited archives.
Resources and object references must remain valid across those members. Restoring
the root map alone is insufficient: the client must also admit the required region
resources before input resumes.

The [save format](../reference/saves.md) describes the records. If a save is refused
while loading, see [Troubleshoot startup](../how-to/troubleshoot.md#saveload-reports-regionadmissioninprogress).
