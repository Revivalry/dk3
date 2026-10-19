# Engine architecture

dk3 combines ioquake3's platform services with native Zig game modules and a Zig
Vulkan renderer. The engine handles the application window, audio, virtual filesystem,
map collision and module loading. The game modules supply simulation, prediction,
presentation and menus.

## Engine and modules

```text
                         ioquake3 engine
                platform · filesystem · audio · collision
                         │ native ABI
             ┌───────────┼─────────────┐
         qagame.so    cgame.so       ui.so
         simulation   prediction    menus
                      presentation
                         │
             Vulkan / OpenGL renderer interface
```

`qagame.so` owns authoritative state. `cgame.so` receives snapshots, predicts local
movement and builds scenes. `ui.so` handles menu navigation and settings. These
modules use engine services through `src/engine` rather than reaching into engine
implementation state.

The renderer is a separate library. The engine can select Vulkan, OpenGL2 or OpenGL1
without changing the game module's scene-submission interface.

## Gameplay code

The source is organized by responsibility:

- `src/core` provides game-independent ECS, jobs, math, collision, animation,
  navigation and save-stream machinery.
- `src/mechanics` provides shared game systems such as damage, target routing,
  world progression and presentation.
- `src/classes` contains each actor, weapon, item and map entity's policy and adapters.
- `src/game` enumerates the classes and components used to compose the runtime.

Registries connect a class's hooks to shared systems. For example, a weapon supplies
its firing behavior and projectile style; shared code handles the reusable transport
and collision work. A new class joins a registry instead of adding branches to every
system that might use it.

This separation keeps class-specific rules together while allowing several classes
to use the same mechanism with different parameters. The [class implementation guide](../how-to/extend-class.md)
describes where to add those parameters and hooks.

## Entity state and identities

The archetype ECS groups entities with the same component set into aligned chunks.
Systems query those chunks rather than walking an engine struct containing every
possible gameplay field.

An ECS handle is generational. A persistent ID serves a different purpose: it
identifies an object across saving, loading or world transfer. Neither identity is
an engine entity slot or a row address. Engine structs project the state needed for
collision and network transport.

Adding or removing components can move an entity. Systems therefore cannot keep
component pointers across structural changes. They record commands and resolve the
entity again after a structural barrier.

## Simulation and jobs

Systems declare component/resource access and dependencies. Independent chunk work
can run on workers; conflicting operations remain ordered. Engine calls execute on
the owning thread. Workers return requests for engine queries, and the runtime
resolves those requests at barriers.

Deferred structural changes commit in deterministic system/job/entity order.
Worker completion order does not select object IDs, event order or random draws.
This is important when comparing inline and worker execution or resuming a save.

`dk3_jobs=0` runs jobs inline. Positive values select up to eight workers. Saving
and teardown join outstanding work before taking or releasing owned state.

## A frame through the game

1. The engine receives input and network messages.
2. Client prediction applies local input using the movement rules.
3. The server advances gameplay systems and commits their deferred changes.
4. Network projections describe the state relevant to each client.
5. The client combines snapshots, interpolation and prediction into a rendered scene.

Resident maps add another ownership dimension to this flow. Each map keeps its
collision, gameplay, resources and identities, while a region coordinates their
readiness and traversal. See [Connected worlds](worlds.md).
