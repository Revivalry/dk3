# Native Zig runtime

Accepted 2026-09-26; implementation starts at **runtime-zig-217**. This decision
supersedes the general C/QVM requirement for dk3 gameplay, client and UI modules.
The Zig runtime is now the only source/build runtime; the old runtime is removed.
This is a development decision, not a claim of gameplay acceptance.
Implemented code and verified acceptance are tracked separately in the run log.

## Branch and layout

All unfinished runtime development is on `rewrite/native-zig-runtime`. `main` was
restored to the pre-rewrite working tree (`ed0755f`) by restoration commit `e3966c4`.
Do not merge or push this work to main without an explicit release/merge request.
The old-runtime removal decision applies to this feature branch.

The permanent source root is `src/`, layered by ownership (sequence 409): `engine/` (ioquake3
ABI), `core/` (game-agnostic runtime), `mechanics/` (shared Daikatana mechanisms: `domain`,
`server`, `client`, `ui`, `policy`), `game/` (class registries and the component list) and
`classes/<actors|weapons|items|entities>/<class>/` (everything one class owns), with the module
roots and catalogs at the top. `build/runtime.zig` composes native modules and tests from the same
named dependencies. Architectural checks reject private gameplay headers, engine/system imports
from pure domain/policy code, and game code in `core/` or `engine/`. See
[`src/README.md`](../src/README.md) for ownership rules.

## Scope and boundaries

Replace all game-owned behavior, including Quake III game-module foundations under
engine/ioquake3. Retain engine rendering, audio, collision/BSP, platform, filesystem,
module-loading and other engine infrastructure. Retain existing Zig networking,
online services and guard; Python asset/development tooling stays supported.
Use Gold as private behavioral reference plus accepted fixes, never as imported
implementation. Preserve licenses and original installations/assets/saves.

Three native module entrypoints (server game, client game and UI) depend on explicit
engine adapters, shared domain rules and ECS infrastructure. Domain code cannot
import g_local.h, cg_local.h or engine globals. Engine-facing structs are transport
projections; authoritative state belongs to the server ECS. Client ECS owns replicated,
predicted and presentation state. Menu navigation uses ordinary typed state.
Pure weapon definitions and rules have one owner. Native ECS systems consume them
through engine adapters; do not maintain a second gameplay backend.

## ECS and scheduling

Use a project-owned archetype ECS with typed component registration, aligned chunks,
generational handles, independent persistent IDs and engine slots. No component
addresses or row indices cross structural barriers. Deferred create/destroy/add/remove
commands commit in deterministic system/job/entity order. Chunk storage and scratch
lifetimes are explicit and bounded. Authoritative capacity exhaustion is an error;
only documented cosmetic effects may be dropped.

Parallel systems declare component/resource reads, writes, dependencies and engine
thread affinity. Disjoint chunks may run concurrently; conflicts establish ordering.
All ioquake3 calls remain on the owning thread. Workers produce typed requests and
commands, engine queries resolve at barriers, and dependent work resumes in the same
step. Transactional pushing and order-sensitive gameplay commits stay serial.
Worker completion order cannot choose entity IDs, event order or RNG draws. Preserve
simulation time and input timing. dk3_jobs=0 runs inline; positive values select workers,
default CPUs minus one capped at eight. Join jobs before save capture, teardown/unload.

## SOLID / DRY / KISS

Each state and transition has one owner. Separate simulation, persistence and
presentation. Concrete actor/weapon policies satisfy checked contracts; shared
mechanisms do not become a universal behavior interpreter. Engine/test services obey
the same contracts. Separate collision/storage/audio/rendering interfaces; avoid a
service locator. Prefer compile-time composition and use runtime interfaces only at
real substitution boundaries. Share prediction/server rules and schemas. Keep the
ECS tailored to the game; no plugin or dependency-injection framework. Explicit state
unions, allocators and recoverable errors replace implicit flags/global mutation.

## Class contract

Shared modules are mechanisms; concrete classes own policy. This makes the SOLID rule above
checkable.

- **Roles.** Line 2 of every runtime, actor, weapon and item module declares its role:
  `//! Shared mechanism: ...`, or `//! actor-class: <policy>` / `weapon-class: <description>` /
  `item-class: <name>` / `entity-class: <name>`. A class module is named after its class, never
  generically (the guard controller once lived in a module called `hostiles.zig`).
- **What a shared module may not contain.** Actor kind comparisons or switch arms (R1, R2), map
  classname literals (R3), weapon-id literals or named weapons (R4), reads of a class policy or
  class sub-state (R5), imports of a class-owned module (R7), and switch arms naming a class's
  union tag: an attack payload, flight or world control in a switch over `.attack`, `.flight` or
  `.action`, or a class component in a switch over a component id (R8).
  `dkq3/tools/class_ownership.py` counts these and missing role headers (R6).
  `dkq3/tools/tests/test_class_ownership.py` fails the build when a count rises, or when it falls
  without the baseline (`class_ownership_baseline.json`) being lowered with
  `python3 dkq3/tools/class_ownership.py --update`.
- **Where class code goes.**
  - Everything lives in the class folder `src/classes/<kind>/<class>/`: pure decisions, state,
    timing and Gold-derived constants in the policy at its root; engine plumbing in its
    `server/`, `client/` and `domain/` adapters.
- **How shared code reaches a class.** Only through contracts that are checked at compile time:
  - weapon description hooks found with `@hasDecl` in `src/weapon_catalog.zig`;
  - actor class adapters through `mechanics/server/actor_classes/registry.zig`: a comptime kind→adapter table
    with default hooks in `common.zig`, plus `traits` declared by each policy;
  - the classname registry for map entities;
  - the render-tag registry on the client;
  - the phase and hook registries below.
  A missing or duplicate owner is a compile error. Every registry keeps its class list in a
  data-only `//! Class registry:` module (`classes.zig` beside each `registry.zig`,
  `weapons/classes.zig`, and the `*_classes.zig` files); the dispatching module never imports a
  class module itself.
- **Hook registries** (server unless noted). Each lists its classes in the order the shared
  schedule runs them; a class declares only the hooks it needs.

  | Registry | Hooks | Run by |
  |---|---|---|
  | `world_system_classes.zig` | `worldSpawn`, `worldPrepare`/`worldMove`/`worldFinish`/`worldArrive` (brush movers), `worldStep`; movers also `publishPart`, `authoredPart`, `nextStop`, `carryPart`/`delayPart`/`samplePart`, `ownsPart`, `pathPhase`; `probes` (`probe`) | `world_systems.zig` (fixed phases; spawn order fixes slot numbers), `pusher.zig`, `attachments.zig`, `platforms.zig`, `coop_bot.zig`, `world_probe.zig` |
  | `projection_classes.zig` | `projected` components, `project`, `restorable`, `effect`, `modelless`; load hooks `restoreAdmit`/`restoreBegin`/`restoreEnd` | `persistence.zig` |
  | `damage_classes.zig` | `admitsDamage` | `damage.zig` |
  | `attack_classes.zig` | per payload owner: `publish`, `step`, `holds`, `damaged`, `admitsDamage`, `actionOwner`, `linkedOwner` | `actor_attacks.zig` |
  | `session_classes.zig` | `sessionReset`, `restoreDefaults`, `camera`, `releasePlayer`, `takesView`; `party` (the party provider: membership, travel capture and arrival, orders, exits, pickups, eye height, bot summaries) | `server.zig`, `clients.zig`, `cinematics.zig`, `damage.zig`, `items.zig`, the bots |
  | `use_classes.zig` | `useTarget` per router stage, `killed` | `targets.zig` |
  | `prop_classes.zig` | `propAge`, `propTick`, `propContact` | `props.zig` |
  | `destructible_classes.zig` | `destructibleUse`, `destructibleStep`, `destructibleRecipient` | `world_actions.zig`, `damage.zig` |
  | `hazard_classes.zig` | `contact_missile`, `hazard` + `forecast`, `probe`, `diagnostic_name` | `bot_evasion.zig`, `combat_probe.zig`, `coop_bot.zig` |
  | `linked_tag_classes.zig` | `linked_body_tags`, `linked_overlay_tags` | `region_presentation.zig` |
  | `domain/control_classes.zig` | `controls` (`.{ .tag, .State }`: the saved `WorldControl` variants) | `domain/world_controls.zig` builds `Action` |
  | `client/client_classes.zig` | `reset`, `world_state`, `screen`, `command`, `viewOffset` | `client.zig` |
  | `entity_classes` (by control tag) | `passage`, `soundtrack`, `current`, `touchesWithBody` | `bot_routes.zig`, `music.zig`, `bot_pilot.zig`, `interactions.zig` |

- **Declarations assembled at compile time.** Shared unions are built from what classes declare,
  so a new class never edits them: actor attack payloads (`attack_payloads`:
  `.{ .tag, .Payload, .modelless }`), projectile flights (`flight_tag` + `BallisticState`; the
  one `void` state is `ballistics.stateless`), world-control states (`controls`), and laser looks
  (`laser_look` on the class owning a `laser.Kind`: model, tag, lifetime, splash, contact
  sounds). Tags are the saved names, so old saves keep loading.
- **Weapon entity hooks** (`server/weapon_classes`): besides the table below, `holds` (a victim
  held frozen), `actionOwner`/`actionSource`/`actionInvolves`/`removeAction` (who runs an action
  entity, for disconnection and travel), `effectOwner`/`effectSecond` (slots an effect names) and
  `probeBeam`/`probeArea` (probe output).
- **Actor class adapters.** Every policy in `src/actor_catalog.zig` `owners` has exactly one
  adapter in its class folder (`classes/actors/<policy>/server/`), listed in
  `game/server/actor_classes/classes.zig`. An adapter declares only
  the hooks its class needs; the registry's header table lists every hook with its default, and
  the defaults live once in `common.zig`. Signatures are checked at compile time, and a public
  function that is not a hook (a misspelling would silently take the default) is a compile error
  unless the adapter lists it in `helpers`.
  - **Load:** `attacks`, `attackLoad` (optional clips, event rows, second strikes, jump strikes),
    `clips` (named clip slots with fallbacks), `routes`, `requires`, `varied_idle`,
    `loadAnimations`, `preload`.
  - **Per-map state:** a `Store` type with `enterMap` and `tick`, held by the actor system in
    `stores` (the companions' weapon poses and teleport nodes).
  - **Spawn and death:** `spawn`, `vanish_on_death`, `own_death`, `die`, `mustGib`.
  - **Step, in order:** `sense`, the freeze check, `prepare`, `scriptable`/`follows`, `perceive`,
    `preempt`, `path_gait`/`pathMove`, `takeover`, `think`, `move`, `settle`.
  - **Publish:** `playback` (the shared mode mapping applies when it returns null; `View.open()`
    says whether a shared pose takes precedence), `decorate` (render tags, loop sounds), `upright`.
  - **Mechanisms:** `idleVaries`, `frame_attack_audio`, `audio_follows_playback`, `admitDamage`,
    `afterDamage`, `immovable`, `use`/`use_after_scripts`, `pausesScript`, `diagnose`.
  - **Ground melee:** classes that fight on foot pass a `ground_combat.Spec` (pain, reach,
    admission rolls, attack choice, transitions, leaps, strike events) to the shared mechanism.
- **Traits.** Capabilities shared systems may read without naming a class are declared per kind
  in the policy's `classes` (`src/mechanics/policy/actors/traits.zig`): attack style, pain clips, ambient,
  aquatic, bystander, party, bloodless, senses and remains (gib material).
- **Class data owned by the class.** Aidata beyond the shared columns is the policy's
  `ClassTuning` with `parseTuning` (stored in `Definition.class`, read with
  `definition.tuning(policy)`). A launched payload shared by several classes keeps a saved
  variant per launcher, and each launching policy declares the variant's style: `rocket_styles`
  (missiles), `shaft_styles` (spears, bolts, knives by touch: knife, axe, magic), `fireball_styles`,
  `spit_styles` (venom spit) and `burst_styles` (burst fire). The mechanism reads only the style.
- **Class state across saves.** A class `State` declares `rebase(delta)`, `validate(check)` and
  `remapIds(map)`; the snapshot code loops over the actor's fields and calls whichever exist
  (`src/mechanics/policy/actors/saved_time.zig` holds the shared primitives).
- **Weapon class adapters.** Pure weapon behaviour stays in the descriptions
  (`classes/weapons/<weapon>/<weapon>.zig`, `@hasDecl` hooks in `weapon_catalog.zig`: `grants`, `aliases`,
  `timer`, `default_muzzle`/`parseValues`, `swordExperience`). Engine behaviour lives in
  the weapon folder's `server/` adapter (`fire` for the `.owned` combat policy, `launch`,
  `prepareFlight`, `seeded`, `publishProjectile`/`decorateProjectile`, `step`, slot `links`,
  `lingering`, `admitsDamage`, `command`) and its `client/` adapter (`drawEffect`,
  `drawSprite`, `drawMissile`, `decorateMissile`, `viewEnd`). `catalog.count` replaces the
  weapon-count literals.
- **Map-entity class adapters.** `classes/entities/<class>/server/`, listed in its registry:
  world controls declare their `WorldControl.action` variant (`tag`) and `spawn`, `bind`, `use`,
  `touches`/`touch`, `step`, `publish`, `savedModel`, `validateSaved`; authored brushes and
  triggers declare `brush`, `pass`/`prepare` and `useAuthored` (the level exit's travel request
  is its own). Classes declare `traits` (button, player usable, relay, touch volume, touch once,
  breakable, door, liquid, capture zone, level exit, decoration, monitor, exploding wall, train,
  team flag) that bots, navigation, interactions and saves read instead of classnames, and
  `passage` (where touching it sends an actor) for route planning.
- **Render classes.** A class folder's `client/` render module (a shared mechanism's in
  `mechanics/client/render_classes/`) draws by render tag: a general entity's
  body tag (`generic1`) and overlay tag (`time2`) select `drawEffect`, `decorate` and `overlay`.
- **Saved class state.** The snapshot decoder calls back class validators supplied by the game
  root (`saved_classes`, dependency inversion): world controls validate themselves; actor class
  states rebase, validate and remap their own ids; control states rebase themselves.
  - **Actor attacks.** Each `ActorAttack` payload owns its save contract, all optional:
    `rebase(delta)`, `remapIds(map)`, `validSaved(born_ms, stepped_ms)` (its own bounds) and
    `saved_components` (component names its entity carries). `domain/actor_attack.zig` loops over
    the payload union. Relations to other entities (Nharre's held victim, Wyndrax's bolt parents)
    are checked by the launching class's adapter hook `validateSavedAttack`.
  - **Emitters.** A component owned by one class states its own source or carrier classname
    (`firefly.State.sourceClassname`, `wisp.Swarm.saved_classname`).
  - Class validators run only in the game module: unit tests run under the test runner's root, so
    a class's own validator is tested beside its adapter.
- **Class registries.** A module whose role is `//! Class registry:` enumerates classes as data
  (the actor catalog's frozen save order, item classnames and rings, the item catalog, the ECS
  component list in `domain/components.zig` with its frozen ids, and the hook registries above).
  It may name classes (R3, R5, named weapons, R7); it holds no behaviour and never compares
  weapon ids. Each actor policy defines its classnames (`definitions`) and
  declares its actor state slot (`state_field`), from which the actor state is assembled.
- **Shared behaviour.** When several classes need the same behaviour (pain, perception, melee
  cycle, wander, cover), it is a shared mechanism taking class-supplied parameters, such as
  `actor_pain.generic(hurt, previous_threat, chance, limit)`. A default lives once and classes
  override it, never copy it. Interactions between classes go through a registry hook too: a party
  member opens a door through the entity registry's `openForParty`, Wyndrax collects wisps through
  the shared collectable swarm (`energy_swarm`).
  - **Pain** follows the reference's acquiring rule in one place (`actor_pain.acquiring`): the hit
    that makes a player the enemy skips the first roll (`generic`, the ground-combat `.roll`;
    a class whose own callback flinches regardless opts out).
  - **Spawnflags** (`src/mechanics/policy/actors/spawnflags.zig`) name the authored monster bits once (wander, path
    follow, node wander, random wander, ignore player, sniper, do-not-move, take cover). Each class
    decides which goals it supports.
  - **Cover** (`src/mechanics/policy/actors/cover.zig` rules and saved state, `server/actor_cover.zig` complete
    visibility and hide-node choice) and **wander** (`src/mechanics/policy/actors/wander.zig` `Roam`,
    `server/actor_wander.zig` leg choice) keep their state in the shared actor fields `cover` and
    `roam`, beside `evasion` (`server/actor_evasion.zig` `sidestep` for blocked shots). A class
    composes them in its `think` and `move` (`common.roam` picks legs, `common.moveTo` walks them);
    the Mishima guard and the civilians use them.
  - The ground node graph (`Actors.ground_routes`, adapter `routes.ground`) carries hide nodes
    (flag 0x1000) and water nodes (0x2).
  - **Props** (`domain/props.zig`, `server/props.zig`): authored decorations, gibs, corpses,
    debris and explosion sprites share one physical body (the `Scenery` component); their roles
    add `propAge`/`propTick`/`propContact`. Explosion sprites are `props.explosion*`.
  - **Locks** (`server/locks.zig`): an authored `keyname` admits only activators holding the key.
  - **Platforms** (`server/platforms.zig`): whether an entity is a mover part, and a path
    platform's phase, for riders, bots and the pusher.
  - **Held victims** (`server/held.zig`): an entity is held when its motion owner (an attack or
    a weapon entity) answers `holds`.
  - **Psychic warp** (`domain/psychic_warp.zig`, `server/psychic_warp.zig`): an ailment like
    poison or freezing; psyclaws inflict it.
  - **Lightstyles** (`domain/lightstyle_table.zig`): the 256-level transport and default styles;
    light classes only pick patterns.
  - **Scorch marks** (`weapons/impact.zig` `scorch_mark_tag`): an authored effect's impact.
- **Save ABI.** `Actor.definition` is an index into `actors/catalog.zig` `entries` and is saved,
  so that order is frozen. Saved field names change only with a snapshot schema migration.

The migration from the existing leaks is staged (sequences 389–400 and 403 in the run log). The
baseline records what is left.

Gold behaviour is ported per class following [class porting](class-porting.md).

## Build and compatibility

Only the Zig runtime is built. The optional -Dgame-runtime=zig spelling remains
accepted for existing commands; legacy is rejected. Development installations require
their own prefix and isolated profile. There is no legacy gameplay fallback. ABI bridges remain mechanical and layout checked. Keep native module
exports and engine-facing layouts where practical; never expose Zig-native layouts.

Current schema-5 saves and optional fields, persistent IDs, relative deadlines and
visited worlds require explicit record mappings. Validate staged state before publish;
never serialize pointers, chunk memory or jobs. Retain protocol layouts where practical,
but require matching verified runtime builds; mixed-runtime play is not required.

## Connected implementation stages

1. Boundary, alternative build/module entrypoints and baseline replay harness.
2. ECS, parallel scheduler, identity/time/RNG, movement/inventory and weapon adapters.
3. World spawning, movers, interactions, combat, actors/navigation, companions/bots.
4. Scripts, cinematics, progression, travel and persistence.
5. Prediction, model/animation/effects/audio/HUD and complete UI/multiplayer flows.
6. Complete gameplay acceptance and qualify installation/release flows.

Implement connected code before systematic scenarios. Required acceptance includes
ECS relocation/stale handles/capacity, scheduler conflicts and worker-count equivalence,
all 28 weapons, implemented campaign systems, saves/recovery/visited worlds, recorded
regressions (including lifts, crouching, menu loads, Superfly and lasers), both renderers,
input/audio/UI, matching-build dedicated/Internet rooms, bots/reconnect/rotation,
compatibility rejection, and repeated performance/memory/query measurements. Audit
replacement builds for legacy C behavior and domain imports. Run the applicable broad
suite after integrated repairs, not per-item duplicate gates. Engine runs use dkguard.
Full four-episode completion is separate from implemented-scope acceptance. Keep the old
installation for rollback and preserve user profiles throughout.

## Active decision: runtime-zig-223

The owner requested removal of the old runtime, not parallel maintenance. Remove its
C gameplay/client/UI, C-dependent Zig adapters and old-runtime tests from the active
checkout. Keep bundled ioquake3 infrastructure, native domain policies, networking,
online services and asset tools. Upstream movement remains a test-only differential
reference. Engine save-envelope validation stays engine infrastructure; native save
restoration remains open. Git history preserves retired independent implementations.

Development uses `zig build game test-runtime --prefix zig-out/native-dev`, followed
by affected isolated native scenarios. Broad checks cover surviving components once
per integrated batch. Do not add legacy parity adapters or require old-runtime builds.
Keep original installations and saves untouched. Removing old tests does not certify
their scenarios: actor witnesses, laser shutdown, scripts, full weapon effects and
campaign progression still need native implementation and acceptance.

Next connected work: weapon events → hit/projectile simulation → damage/death → actor
reactions, with simulation rules owned by domain code and collision/audio/rendering
resolved by explicit adapters. Then progression/scripts, persistence/travel, and UI.
The following checkpoints are historical and their old-default statements no longer
apply to the source/build policy.

## Foundation checkpoint: runtime-zig-217 (historical)

**The replacement is not playable and cutover has not occurred.** The ordinary
`dk3` installation continues to use the legacy runtime. Server, client and UI
entrypoints reject unqualified gameplay explicitly; they do not delegate back to
legacy game code. `play` and `play-install` reject the replacement selection.

Implemented foundation:

- Native module build, public-header ABI boundary and layout checks.
- Archetype chunks, explicit component IDs, generational handles, persistent IDs,
  deferred structural commands and independent engine-slot allocation.
- Bounded persistent worker pool, access/dependency scheduler, frozen schedule
  contracts and owning-thread engine collision barriers.
- Ballistic probe through that scheduler, exact engine-frame clock and relative
  deadline helpers. These are not replacements for player movement or actor physics.
- Map metadata ingestion retaining all authored properties; entity behaviors remain
  to be implemented.
- Portable existing save-record codec and read-only exact-roundtrip inspector.
  Gameplay schema validation, staged ECS reconstruction and save/load remain open.
- One shared inventory acquisition transition used by the existing weapon backend
  and the replacement Inventory component. Weapon controllers, policies and
  presentation still require backend extraction.

Stages 1–2 are partially implemented. Stages 3–6, player movement, playable
client/UI, full weapon adapters, persistence restoration and cutover acceptance
remain open. Codec validation and bootstrap probes are not campaign acceptance.

Build and exercise the isolated foundation with local converted assets:

```sh
zig build game runtime-audit --prefix zig-out/replacement -Dgame-runtime=zig
zig build test-runtime
python3 dkq3/tools/runtime_probe.py --engine zig-out/play/current --prefix zig-out/replacement
zig-out/replacement/bin/dk3-runtime-audit /path/to/existing.sav
```

The probe uses a temporary home, copies only the replacement server module, invokes
`dkguard`, and records logs/inputs in `zig-out/reports/runtime-zig-217`. It compares
0/1/4 workers and map restarts. The audit command only reads its input. Neither
command installs a replacement into the normal launcher or writes existing saves.

## Active implementation: runtime-zig-218

The native development client now connects with `dk3_runtime_probe=2`. All three
modules embed the same source rules identity; the UI advertises it before connect,
the server checks userinfo, and the client checks the server configstring. Normal
launch/install still uses the existing runtime. This is not a qualified playable
replacement, and the complete accepted migration remains active.

Implemented, with acceptance still incomplete:

- Shared native server/client player movement and collision adapters: crouching,
  stepping/sliding, jumping, water, ladders, gravity, spectator and noclip paths.
  ECS owns player, transform, velocity and weapon state; snapshots are projections.
- One pure catalog for all 28 weapon descriptions, input policies and supplied
  numeric tuning. Legacy and native adapters use the same firing/switching rules,
  inventory acquisition, sword calculations and special input transitions.
  Native shot events do not yet dispatch damage or projectile controllers.
- Native BSP/brush rendering, snapshot ingestion and command replay. Full HUD,
  model/animation/effect/sound presentation and actual UI screens remain absent.
- Binary translating/rotating doors, buttons and platforms, grouped travel,
  authored delays and dwell, accelerated/bouncing curves, transactional player
  pushing, use rays, rider-only automatic platform activation and door proximity.
- Bounded target routing and delayed actions, killtargets, repeated/once triggers,
  counters and relays. Authored key locks are preserved; key inventory, scripts,
  cinematics, trains, secret doors and other interactions remain open.

Focused evidence: 1,440 command frames agree with bundled movement on flat-ground
walking/diagonal motion/crouch/jump/gravity and shallow/deep-water swimming; weapon controller checks cover all 28
policies and specific burst/reload/charge/spin transitions. Isolated e1m3b client
connection, movement captures and repeated delayed-door activation have run.
These checks do not certify movement through all geometry, blocked assemblies,
rider transport, actor behavior, damage, progression or multiplayer parity.

The movement differential fixture links bundled GPL C movement **only into the
test executable**. Replacement products link no legacy gameplay C sources.
Adapted movement retains upstream attribution; no private reference source or
assets were imported.

Reproduce the native development client probe (local converted assets required):

```sh
zig build game --prefix zig-out/replacement -Dgame-runtime=zig
python3 dkq3/tools/runtime_player_probe.py --engine zig-out/play/current --prefix zig-out/replacement --mover 255
```

The script runs software rendering through `dkguard --headless`, uses a temporary
profile, and keeps inputs/logs/captures under the ignored report directory. The
optional mover assertion is specific to e1m3b's delayed door. Visual captures need
inspection; diagnostic command success does not establish scenario acceptance.

## Active implementation: runtime-zig-219

Train path legs, angular travel, departure-corner dwell, trigger-only stops,
redirected/elevator activation and teleport corners are connected. Persistent
parent IDs define bounded attachment hierarchies with cycle rejection. Initial
placement/teleports carry descendants; ordinary movement prepares complete poses
before collision and commits or delays the assembly together. Static brush parents
can own animated children. Arrival dispatch runs after both mover families finish.
These additions remain part of the unqualified replacement, not a production cutover.

Focused checks now total 26 replacement tests. The real e1m3a `bigplat` replay
carries the player upward, holds its authored ten-second dwell, descends and rests
at the lower trigger-only corner. The probe uses explicit diagnostic positioning
and activation; original saves are untouched. It does not certify the physical
button/trigger chain or full campaign progression. Multi-part obstruction, rotating
riders and compound attached-mover scenarios remain open.

```sh
python3 dkq3/tools/runtime_player_probe.py --engine zig-out/play/current --prefix zig-out/replacement --scenario lift
```

Combat/projectiles, actors/navigation, secret/continuous movers, scripts/cinematics,
save restoration/travel, full presentation/UI and overall acceptance remain open.


## Active implementation: runtime-zig-220

Two-leg secret doors and continuous rotating brushes now use the same transactional
attachment/pusher path as binary movers and trains. World-system ordering has one
coordinator; engine trajectory encoding is shared. Attached special movers sample
independent motion before parent composition and defer their motion clocks on rollback.

Focused real-map probes demonstrate e3dm1 secret door 43 opening both legs, waiting,
and retracing to its closed position; e1m3b rotating brush 72 starts, stops without
drift, and resumes. The affected e1m3a lift and e1m3b delayed door still pass. These
use diagnostic activation; shoot activation, rotating riders, sounds and compound
obstructions remain unqualified. Replacement modules and domain checks build.

Reproduce with `runtime_player_probe.py --engine zig-out/play/current --prefix
zig-out/replacement --scenario secret` (or `--scenario rotation`). The normal
launcher still uses the existing runtime. Combat, actors, inventory progression,
scripts/cinematics, restore/travel and full presentation/UI remain implementation work.


## Active implementation: runtime-zig-221

Native keys, weapon/ammunition pickups, health and armor are connected to floor
physics, MD3-derived bounds, model configstrings/rendering, visibility, respawn
policy, target dispatch and player-state projection. Key names unlock doors/buttons
through persistent player IDs. Weapon selection commands and server acquisition
selection are connected. Shared metadata serves C and Zig; shared ammunition and
Gas Hands duration policies avoid parallel weapon-rule implementations.

Map spawning now applies mode/difficulty restrictions before behavior registration,
without renumbering authored IDs. ECS relocation supports tagged component unions.
Native products and 37 focused tests pass. The e1m6a blue-card probe verifies floor
settlement, touch collection, rejection before key ownership and button/door activation
afterward. The affected lift and delayed-door probes still pass. Diagnostic placement
and activation are recorded; this is not a full authored route or cinematic replay.

```sh
python3 dkq3/tools/runtime_player_probe.py --engine zig-out/play/current --prefix zig-out/replacement --scenario inventory
```

Boost/status pickups, pickup audio/messages, moving-platform item transport, native
combat/actors, progression, scripts/cinematics, restoration/travel and full UI/HUD
remain open. The normal installation and saves remain untouched.

## Active implementation: runtime-zig-224–225

Normal fire events dispatch Glock/Disruptor hitscan and Ion projectile policies into
native damage. Ion bolts own persistent shooter identity, collision/bounce state and
lifetimes in ECS. Class metadata owns projectile tuning; the server owns collision
and event delivery. Native client models and sound events show those entities.
The other 25 weapon combat policies remain pending, even though their input
controllers and metadata exist. Full effects, knockback and Gold combat parity remain open.

Four civilian classes load supplied health, bounds, speed and animation sequences.
Workers/prisoners have native movement, damage receipts, death animation/target dispatch
and visible-death witness panic. Actor metadata is owned by world-system state and
allocated for the map lifetime. Movers can transactionally push actors/corpses using
the same assembly mechanism as players. Navigation, scripted actor control, hostile
attacks, actor sounds and final-pose corpse bounds remain open.

The e1m2a civilian scenario demonstrates Glock damage killing authored worker 10 and
worker 9 witnessing the death, entering flee and moving away. Player positioning and
equipment are diagnostic; this is not a campaign-route or full actor acceptance.

```sh
zig build game test-runtime --prefix zig-out/native-dev
python3 dkq3/tools/runtime_player_probe.py --engine /path/to/local/engine-generation --prefix zig-out/native-dev --scenario civilians
```

## Active implementation: runtime-zig-226

Mishima guards now have a class-owned pistol controller: eight rounds, supplied
attack sequences/strike timing, pose selection, reload sound timing and randomized
recovery. Supplied aidata provides health, speed, sight/FOV, damage, spread, muzzle
offset and model scale. The hostile adapter acquires visible living players, reacts
to player damage, traces shots and routes damage through the shared service.
Actor animations and scaling project through public snapshots. Definition data is
validated before use; mutable controller/RNG state belongs to each actor.

The authored e1m3b guard 166 scenario demonstrates retaliation, rounds 7 through 0,
player damage, and reload animation/audio dispatch. Diagnostic placement/equipment
and increased player health keep the fixture alive across the full cycle. The
worker witness and Glock/Ion scenarios still pass after hostile actor integration.
Cover, path navigation, pain responses, authored actor script activation, difficulty
scaling and complete Gold behavior remain unqualified or unimplemented.

Named Zig imports do not automatically include their module's tests. The runtime
check target now explicitly runs the actor catalog tests alongside the runtime root;
46 runtime/catalog checks pass. This prevents a class-policy test from merely
compiling without executing.


## runtime-zig-227 — navigation and world action ownership

Implemented, with focused pursuit/witness/laser scenarios passing: the engine navigation adapter
owns botlib setup, map checksum/mode selection, frame updates and entity projections.
Domain navigation owns route progress/cache policy; actor locomotion consumes those
values and collision services without moving through blockers or unsupported ground.
Guard perception retains the last seen position and expires lost threats.

World actions now have typed ECS state for destructible controls, toggle walls, hurt
volumes and ordered target events. Their authoritative state drives collision and
presentation together. Campaign-specific corrections remain explicit in
`server/campaign_rules.zig`; the e1m3b disabled laser circuit cannot retain damage.
New scenarios are tracked in sequence 227 of the run log. Remaining weapons, actors,
air/water navigation, scripts/cinematics, saves/travel, presentation/UI and multiplayer
integration still require implementation and acceptance.

## runtime-zig-228 — weapon presentation and HUD

The client owns view-model media, interpolated finite poses, predicted/server fire
deduplication, reload/ready/away cues, muzzle placement, additive flashes, hum and
optional weapon shine. Pure presentation transitions consume class-owned animation
and audio metadata. Glock reload detection is dispatched through the class contract.
The game build installs its independent effect shader alongside the modules.

Shared client/UI drawing uses validated supplied DKF metrics. The native HUD draws
health, armor, ammunition, level, attribute boosts/points, weapon models and campaign
inventory. Selection and attribute commands dispatch to the authoritative server.
The three implemented combat weapons have focused animation and rendered evidence;
remaining weapon-specific poses/effects, complete HUD states and menus remain open.

## runtime-zig-229 — native menu ownership

The UI ABI composes typed menu state, settings, controls and artwork modules through
a public engine UI adapter. Selection persists independently of pointer hover.
Supplied menu plates animate, difficulty figures start the chosen campaign difficulty,
settings expose real engine/client options, and rebinding requires a deliberate choice
when replacing an occupied key. Mouse coordinates use the same letterboxed layout
as drawing. Keyboard focus survives zero-delta mouse events; pause/resume releases
input and restores simulation. Native C-int VM arguments decode their low signed
32 bits so negative mouse deltas cannot trigger checked-cast failures.

The guarded UI scenario uses XTest input, an isolated X display and temporary profile;
it exercises mouse settings, keyboard category selection, conflict cancel/replace,
difficulty start and pause/resume. At that checkpoint save/load and multiplayer screens still required
their native runtime services; loading a campaign is not script/cinematic acceptance.

## runtime-zig-230 — native persistence and save selection

Native schema 1 uses the portable named-record envelope with explicit typed component
values, persistent identities, resource names and scheduled target actions. It never
stores chunk rows, pointers or engine memory. Decoding owns all strings in an isolated
world and checks structure, numeric bounds, component requirements, player identity,
transport slots, actor classes and loaded-map model availability before publication.
Every timestamp-bearing component has an explicit rebase mapping; durations retain
their values. Engine storage supplies atomic replacement and previous-save recovery.

Save/load commands and menu actions share this service. Save rows retain selection
when the pointer moves to the Load button. The menu validates a selected save before
starting its recorded map directly, avoiding an intermediate first-level startup.
Focused evidence covers a moving lift, player health/inventory, previous recovery,
checksum rejection, real mouse input and main-menu restoration. Native saves do not
yet translate the independent runtime's schema-5 records or contain visited worlds;
original saves and the preserved installation remain untouched. Full mid-action,
campaign and compatibility acceptance remains open.

## runtime-zig-231 — authored travel and visited worlds

Implemented with focused scenario evidence. Typed exit latches
route ordinary touch/target activation to one departure request at the frame barrier.
Pure travel rules distinguish submap, chapter and episode boundaries. Authored target
names choose arrival starts; compatible submap landings use the exit offset, with
collision fallback to the authored start. An overlapping arrival exit remains latched
until the player leaves its volume. Health, equipment, ammunition, keys, character
progress and rebased protection deadlines transfer independently of the old map pose.
Episode changes reset keys/loadout through class-owned starting/campaign equipment.

An atomic transfer file includes the outgoing world and flat visited-world records.
Returning restores the prior map while applying the incoming traveler at its landing.
Full saves contain those archives; nested checksums, structural state, duplicate map
identities, recursion and capacity are validated before live publication. Chapter and
episode transitions discard prior submap archives, matching the Gold transition type.
There is no loose external archive index that can disagree with a saved campaign.
Earlier native schema-1 records reconstruct absent exit latches from authored objects.
Companion-gated, cinematic and ending exits report their missing native service;
their requirements are not bypassed. Schema-5 migration remains separate work.

The guarded e1m3b → e1m3a → e1m3b touch-exit scenario preserves the destroyed laser
control and the incoming player's selected Glock and health (333 outbound, 222 on
return). Loading a full campaign save after discarding temporary transfer files
restores its visited laser world and incoming health 333. Captures were inspected.
Diagnostic positioning/equipment were used; the fixture's console pause requests
were rejected by the read-only engine cvar (corrected in sequence 233). This is not
full authored route, offset/blocker, companion or cinematic acceptance.

## runtime-zig-232 — pellets, rotary fire and impact presentation

Implemented with focused native combat and rendered evidence. Shotcycler and Slugger
own their pellet geometry, victim limits, damage scaling and recoil policies; Ripgun
uses its rapid trace controller. Persistent player RNG produces pellet spread and
continues across native save/load. Shared movement prediction applies Shotcycler
recoil. Living actors/players receive mass-scaled inertial hits; rising actors retain
their impulse instead of reacquiring ground prematurely.

Authoritative contact events carry weapon, material/flesh/water classification,
normal and serial. Class-owned impact cues select sounds, decals, particles and light;
Ion uses explosion sounds for flesh and electrical sparks for world contacts. The
client clips decals through the engine collision adapter and owns bounded cosmetic
pools, independent of gameplay state. Nearby repeated decals replace one another
and rotate deterministically to prevent alpha fringes accumulating into opaque
rectangles. Save capture excludes transient impact/sound
events. Snapshot validation rejects imported transient events and invalid body mass.
Shotcycler retains one burst pose and finish cue; Ripgun loops firing and spins down
on release. Six combat policies are connected; the remaining 22, projectile trails,
full impact art/audio parity and complete all-weapon acceptance remain open.

## runtime-zig-233 — projectile policies and sprite presentation

Implemented with focused projectile/save, actor-contact and rendered evidence.
Bolter, Sidewinder
and Cordite use class-owned launch, flight, water and contact functions through typed
pure contracts. The server owns collision, lifetimes, radius visibility, damage and
projection; fire-intent resolution and weapon damage are separate modules. Sidewinder
recoil is shared with prediction. Flight state is a tagged union of class-owned state,
with native save validation checking its weapon contract and lifetime component.

Bolter damages living/destructible targets, embeds in static world geometry and
expires after sticking; brush contacts remove it. Sidewinder launches its paired
offsets, accelerates once after 400 units, and uses reduced launch speed underwater.
Cordite starts gravity after its initial flight, bounces off scenery and explodes on
actors or at its fuse deadline. Water damping is independent of simulation step size.
Gold's Cordite delay, damping and Bolter brush behavior were consulted directly.

The client consumes validated converted sprite dimensions/origins for animated,
additive explosion quads, plus projectile scale, class-owned loop audio, light and
stuck-bolt fade. Cosmetic media are owned by the client; restoring server projections
does not register class loop sounds. Nine weapon combat policies are connected;
remaining combat, trails, complete material/fade parity and campaign acceptance stay
open. Focused evidence and diagnostic-input limits are recorded in the run log.

## runtime-zig-234 — timed melee and kill progression

Implemented with focused melee, progression, save and rendered evidence.
Silverclaw and Daikatana own strike timing, arc geometry, directional damage,
animation and contact sound policies. The server resolves collision for persistent
melee actions using current owner poses. Saved actions preserve the strike cursor
and relative start time; consumed strikes do not replay. Sword immunity, backstab,
parry and experience rules stay in the sword class. Actor death dispatch awards
ordinary experience once, using the recorded weapon/source for sword progression.

Normal-input scenarios on both renderers kill authored civilians and retain both
experience totals across save/load. They use collision-checked diagnostic placement
and equipment. Visual inspection found that a restored swing resumed damage while
playing the draw pose. The repair retains the last fire time and sends the resumed
attack timestamp with the restoration notice, so the client can sample the saved
animation position. Both repaired renderer replays pass; the aggregate suite passes
208 Zig and 44 Python checks. Eleven combat policies are connected; remaining combat,
complete defense/arc/audio parity, multiplayer rewards and campaign acceptance stay
open. Scenario details and final verification belong to the run log.

## runtime-zig-235 — poison, freezing and timed releases

Implemented with focused status, save and rendered evidence. Gas Hands uses a timed strike;
Venomous chooses a close bite or delayed projectile release, alternating supplied
muzzle offsets. Poison projectiles bounce, settle into contact hazards and dissolve
in water. Kineticore ricochets, ages its damage, recovers lost velocity and applies
freezing. Each concrete class owns its combat, flight, damage and effect requests.

Persistent ailments own poison deadlines and time-based freeze decay. Actor/player
systems consume the same effects, including armor/protection, death, source credit,
cures and travel reset. Delayed projectile releases have persistent owner IDs and
rebased deadlines. Sprite projectiles and poison pools use converted sprite metadata;
frost and player status overlays remain client presentation. Fourteen combat policies
are connected in code. Authored kills, poison ticks, freezing, saved delayed launch
and restored pool contact pass on both renderers. The prior projectile regression
also passes. Full rendered/audio, water behavior and campaign acceptance remain
open; the pool capture is occluded and does not verify its complete appearance.

## runtime-zig-236 — persistent C4 charges and Hammer quakes

Implemented with focused native combat, save and mover evidence. C4 owns arming,
proximity thresholds, detonation scheduling and contact cues. Its server controller
resolves flight, shootable hulls, remote selection, mover attachments and staggered
chains. Charges use the existing transactional attachment system, including saved
parent identity. Damage from a C4 blast cannot bypass the chain's pending deadline.

Hammer owns charge/release timing, quake strength and visual parameters. Its server
controller resolves the delayed small-box strike and radius hit, then retains a
six-second quake for grounded full charges. Full quakes cost 20 health, require
visibility for their initial area damage and apply later ground impulses without
repeating the damage. Saved strikes and quakes rebase their deadlines. Class-owned
charge animation and sounds, C4 button presses, oriented ring sprites and camera
shake remain client presentation. Shared area geometry and engine entity lifetimes
are separate mechanisms, not another weapon behavior interpreter.

Sixteen combat policies are connected. Focused scenarios cover C4 direct contact,
saved remote detonation, shooting, chain amplification and an attachment carried by
the authored bigplat lift. Hammer scenarios cover saved partial strikes, full-charge
self damage, a visible guard kill, protection of an occluded worker and quake
restoration. Both renderers pass the combat/save scenario; rendered/audio parity,
all C4 deployment/lifetime/material cases, complete quake motion and multiplayer
remain open. Evidence and repairs are recorded in the run log.

## runtime-zig-237 — Shockwave flight and expanding bands

Shockwave now owns its delayed release, water/ricochet rules, trail and impact cues,
six expanding damage bands, and ground impulses. Its server controller resolves
collision, damage and visibility; the client reconstructs rotating translucent
rings from saved birth times and band offsets. Native saves retain the pending shot,
orb state and consumed band radii, so restoring does not restart damage expansion.
Muzzle sprites and oriented impact sprites use the shared converted-sprite renderer.

Seventeen combat policies are connected. Both renderer scenarios pass delayed-shot
restoration, an authored worker kill, active-band restoration and completion, and
saved ricochet flight. Inspected captures show the blue rings without opaque sprite
backgrounds. Full water, muzzle timing, quake motion, effect/audio parity and campaign
acceptance remain open. The development orb has a bounded 60-second cleanup; this
is not a claim that Gold uses that flight deadline. Evidence belongs to the run log.

## runtime-zig-238 — linked Trident tips and Ballista transport

Implemented; integrated verification continues. Trident consumes up to three rounds,
uses all three supplied muzzle offsets, steers surviving outer tips and combines the
group after its expansion. Water and charged contact damage remain class-owned.
Ballista releases after its animation delay, halves underwater launch velocity,
strikes and transports actors, pins suitable wall contacts, and releases on timeout,
death, expiry, travel or disconnect. A body motion owner prevents actor steering from
overwriting transport; actual movement still resolves collision. Native snapshots
validate group and victim references and preserve relative controller clocks.

Nineteen combat policies are connected in code. Focused live evidence demonstrates
Trident's close-range three-tip kill and Ballista's saved pending shot, saved victim,
wall pin, repeated pin damage and release. The Trident merge scenario remains open:
the first lane intersects outer tips before merging. Complete trail/impact/audio,
water, actor motion regressions and multiplayer qualification also remain open.
The Shockwave trail binding now uses the supplied e1 asset path; open-flight rendered
verification is pending. This checkpoint is not a gate on dependent implementation.

## runtime-zig-239 — continuous beams and personal action lifetime

Novabeam owns its delayed discharge, ammunition ticks, diminishing damage and closing
phase. Flashlight owns its battery curve, held-input consumption and surface lights.
Their server controllers retain persistent owner IDs and rebased deadlines; the
client draws replicated beam/light state using shared beam and sprite mechanisms.
Personal attacks are cancelled on player arrival and disconnect, while independent
world projectiles remain world state. The flashlight uses Gold's internal battery
defaults when the supplied internal weapon row has no ammunition values.

Twenty-one combat policies are connected. The focused live scenario passes saved
pending and active Novabeam, an authored worker kill, closing/expiry, held flashlight
consumption, restoration and release. Inspected captures show the orange beam and
surface illumination. Full audio/effect parity, second renderer, action cancellation
through travel, multiplayer and the refreshed aggregate suite remain open.

## runtime-zig-240 — returning Discus and Sunflare fields

Discus owns its two melee swings, animation release, seeking, water slowdown,
reflection, return and recoverable dropped state. Sunflare owns its thrown pot,
impact damage, flame count/radius, timed burning/cooling and buoyancy. Dedicated
server controllers resolve collision and inventory transfer; saved flight state
retains target IDs, damage cursors, random streams and relative clocks. The shared
projectile launcher now applies pitch adjustment before calculating the muzzle.

Twenty-three combat policies are connected. The live scenario demonstrates saved
melee/release/flight, Discus contact and catch, and a restored Sunflare field killing
an authored worker before cooling and expiry. Captures exposed Sunflare's incorrect
blend mode; Gold's additive flag binding is repaired and the second-renderer replay
passes gameplay/save assertions. Bright effect boundaries remain visible; complete
presentation acceptance is open. Complete trail/smoke/audio, liquid/drop cases, motion regressions,
multiplayer and refreshed broad checks remain open. Both controllers use a bounded
60-second airborne cleanup, an independent limit rather than a claimed Gold deadline.

## runtime-zig-241 — growing meteors and fragments

Stavros now uses its reviewed meteor model, displaced launch, staged growth and
acceleration, main blast and single-player fragments. Fragments retain independent
scale, spin, gravity, bounce and expiry. Client projections preserve launch origins
and scale for the portal/glow presentation. Native saves retain growth, random state
and individual fragment state. Twenty-four combat policies are connected.

The live scenario passes growing-meteor restoration, primary explosion, restored
fragments, authored worker kill and fragment expiry. Captures confirm the meteor
model and fragments; full smoke, portal, light/audio and visual parity remain open.
The shared campaign travel regression passes after personal-action cleanup changes.
The aggregate batch result and remaining effect diagnostics are recorded in the run log.

## runtime-zig-242 — Zeus chains

Zeus owns its delayed strike, paid hit/free single-player miss, branching target
selection, damage falloff and closing phase. Typed native chains and bolts retain
references and clocks through saves. Focused live diagnostics exercise pending and
active saves, two worker kills, ammunition and closure. Water, maximum target count,
multiplayer and full sound/effect comparison remain open.

## runtime-zig-243 — remaining weapon controllers and campaign priority

Wyndrax owns its homing oscillator, retained targets, pulses and fade. Nightmare owns
its casting, marking, victim control, reaping and release. Metamaser owns its thrown
cube, arming, retained/acquired targets, charges, damage response and destruction
rings/lasers. Supplied tuning remains authoritative: Metamaser has 30 charges and
300 health. All 28 class policies are now connected; this is dispatch coverage, not
complete weapon acceptance. Native saves retain controller identities and rebased
state. Nightmare freezes both authority and prediction without stealing another
controller's body ownership.

The diagnostic driver now observes processed input, readiness, actual firing and
both server/client restoration. Its ordinary-input mode rejects fixture mutations.
Assertions are required, failures invalidate the scenario, and reports hash the
actual executable/modules/assets. The current outcome matrix is
[native-acceptance.md](native-acceptance.md). Connected opening progression now takes
priority: full intro, arrival, opening hostiles, bridge scripts and authored exits.

## runtime-zig-300 — resident region persistence

Schema 2 retains the active world and resident member records in one atomic save.
It preserves allocation namespaces, checksums, activation state, resource identities
and pending actions, and validates references across explicit world/entity pairs.
Schema 1 remains readable. Hidden restored contexts and actual client readiness
precede input admission. Controlled two-map save/death restoration passes in both
renderers, together with a real schema-1 fixture and the inactive-snapshot regression.
See [current acceptance](native-acceptance.md) for exact identities, evidence and
limits; authored seamless traversal and complete legacy visited-region conversion
remain open.

## runtime-zig-301 — automatic region progression

The local installation derives a campaign graph and pins reviewed opening seam
geometry to both BSP hashes. Single-player initial admission prepares its region
before control; outgoing regions prepare during play. Ordinary exits use resident
ownership with existing authored preconditions and cut/traveler policies. Carried
weapon actions retain their identity and class-owned projection. Other corridors
retain authored landing semantics pending geometric qualification.

A six-world restore regression exposed the four-reader queue boundary and both
renderer/navigation exhaustion of the original fixed memory zone. Bounded client
admission and independently releasable owner heaps repair those cases. Current
identities, failed evidence and exact acceptance limits are in
[native-acceptance.md](native-acceptance.md). Portal views/cross-boundary gameplay,
old visited-archive migration and full campaign acceptance remain open.

## runtime-zig-302 — visited migration and admission lifetime repairs

Old flat native visited archives are converted on demand into resident namespaces,
with explicitly mapped entity references and one current traveler. Unrequested
archives remain cold; admitted maps save once as schema-2 members. Typed migration
contracts cover overlapping identities, delayed actions and counters that must not
change. Original save bytes remain untouched.

Resident brush models no longer exhaust the renderer’s shared ordinary-model
table. Authored doubled sound separators normalize to the supplied asset. The
client uses the actual gamestate reliable boundary to discard old resident
commands during load while keeping current-map readiness validation strict.
Exact consolidated evidence and limitations live in [native acceptance](native-acceptance.md).
Portal views, cross-world gameplay, residency eviction and complete campaign
acceptance remain required work.

## runtime-zig-322 — multiplayer bot ladder and sight

Multiplayer bots previously searched every client regardless of facing, aimed exactly
on the acquiring tick and ignored the difficulty value they were created with, so every
match played at maximum strength. One ten-level ladder in
`src/mechanics/domain/bot_skill.zig` now governs view cone, sight range, target memory,
reaction delay, view turn rate, aim error, burst discipline and gunshot-awareness error,
and the same value is selected on both hosting pages and carried through the room
service as `dk3_bot_skill`. Target acquisition is a cone around the bot's own view, the
commanded view is rate limited, a target-less bot sweeps search headings as it walks, and
a fresh injury receipt makes it face the shooter rather than see through cover. Authored
actors keep the five-level scale through the published pairing.
**Implemented; unverified**: bot-only matches have been sampled at levels 10, 5 and 1
with the cone, view and navigation telemetry read back, but no human has played a level and
the balance is unreviewed. See [bot skill and sight](bots-zig.md) and
[native acceptance](native-acceptance.md).
