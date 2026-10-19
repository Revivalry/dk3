# Native runtime

`server.zig`, `client.zig` and `ui.zig` are native ioquake3 module entrypoints. The catalogs
(`actor_catalog.zig`, `weapon_catalog.zig`, `item_catalog.zig`, `inventory_rules.zig`) are module
roots too. They compose the layers below; this is the game's runtime, not an alternate backend.

The path decides what a module is. Game-agnostic layers know nothing of Daikatana; shared
mechanisms know Daikatana but no concrete class; a class folder holds everything one class owns.

| Directory | Owns | Dependencies |
|---|---|---|
| `engine/` | The ioquake3 ABI: syscalls, collision/filesystem services, transport projections | Public engine headers and `core/` |
| `core/` | Game-agnostic runtime: ECS (`core/ecs`), math, animation, collision, navigation, save streams, tables, sprites, audio parameters, mover kinematics | Zig standard library and other `core/` modules |
| `mechanics/` | Shared Daikatana mechanisms: `domain/` (pure rules and state), `server/` (authoritative systems), `client/` (presentation), `ui/` (menus), `policy/` (pure helpers for class policies), and the registries' dispatch (`*/actor_classes/registry.zig` and the like) | `core/`, `engine/`, the catalogs, registries |
| `game/` | Data-only class registries (`classes.zig` beside each registry, `*_classes.zig` hook phases) and the component list | Class modules (it enumerates them) |
| `classes/<actors\|weapons\|items\|entities>/<class>/` | One class: its pure policy at the folder root, its adapters in `server/`, `client/`, `domain/` | `core/`, `mechanics/`, `engine/`; never another class |
| `tests/` | Differential fixtures and runtime contracts | Test-only references; never linked into products |

Line 2 of every module states its role, and inside `classes/` it repeats the folder
(`//! actor-class: <class>`, `weapon-class:`, `item-class:`, `entity-class:`). Shared modules are
`//! Shared mechanism: ...` or `//! Class registry: ...`, and consume classes only through checked
contracts (catalog hooks, traits, class-declared styles and registries), never through kind/tag
comparisons, switch arms, classname literals, weapon-ID literals, another class's state or an
import of a class module. Class policies are reached only through their catalog module
(`@import("actor_catalog")`), never by relative path. `dkq3/tools/tests/test_class_ownership.py`
enforces this, and `core/`/`engine/` importing game code (R11), against a baseline that only goes
down; see the class contract in [the runtime plan](../docs/runtime-zig.md). Runtime
configuration and local converted asset data provide numeric tuning and authored content.

Component pointers never survive structural mutations. Systems copy intent/state
before spawning entities, resolve persistent IDs at use time, and call ioquake3 only
on its owning thread. Engine structs are projections, not authoritative game state.

See [the runtime plan](../docs/runtime-zig.md) for full scope and implemented versus verified status.
The native rewrite reached `main` on 19 October 2026. Connected native work continues
on `rewrite/native-zig-runtime` and reaches main through reviewed merges. The separate
preserved installation and saves remain local.
