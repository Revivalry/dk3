# Class porting

How an actor, weapon, item or map-entity class gets Daikatana Gold behaviour into the native
runtime. Gold (`~/sources/daikatana/reference/dk-gold`) is a private behavioural reference. It is
never imported, never translated line by line, and never a build or check input (AGENTS.md,
CONTRIBUTING.md). We port behaviour, not code.

Every port goes through the five steps below, in order. Code is written only in the class's own
modules (docs/runtime-zig.md "Class contract").

## 1. Review sheet

Record the class's reference behaviour in `docs/class-porting/<class>.md`, citing reference file
names and functions as provenance only. Fill in every section below; write "none" when the class
doesn't have one.

| Section | Questions |
|---|---|
| Identity | Classnames, model, aidata row, actor kind or weapon id, related classes (projectiles, spawned effects) |
| Spawn | Spawnflags and their goals: wander, node wander, path follow, ignore player, do-not-move, take cover, snipe. Map keys: `default_aiscript`, `aiscript`, sight range, health override, `uniqueid` |
| Goals and tasks | Idle and ambients, wander, path follow, chase, attack, take cover, sidestep, flee, cower, scripted actions. What each one is entered from and what it exits to |
| Animation | Each state's clip, weights, loop/once/hold, what plays between attacks, reload, pain threshold and chance, death variants, transitions (`cin`/`cout`, stops), how playback rate relates to speed |
| Timing | Attack cadence, reaction delays, rests, cooldowns, in simulation milliseconds |
| Skill | The aidata multiplier (0.75/1/1.25 for health, damage, speeds, sight range) and any class-specific skill tables or rolls |
| Perception | FOV, sight range, the 256-unit proximity rule, hearing and alerts, how damage acquires a target |
| Combat | Weapons, hitscan or projectile, spread, leading, damage and its random part, the damage-admission roll |
| Audio and events | Sounds per state and frame, voice lines, effects |
| Persistence | What must survive a save: phases, timers, counters |
| Open questions | Anything the reference leaves ambiguous, plus the decision taken |

## 2. Animation inventory

List every clip the sheet needs and check it against the converted `.anim` metadata
(`unzip -p …/dk3-models.pk3 models/…/<model>.dkm.anim`). A missing or misnamed clip is fixed in
the converter, not worked around in class code.

## 3. Class-owned implementation

- **Class folder** (`src/classes/<actors|weapons|items|entities>/<class>/`): everything the class
  owns. Its **pure policy** sits at the folder root (constants, `traits`, `State`, timing and
  decision functions, all unit-testable without the engine). Its **adapters** sit in `server/`,
  `client/` and `domain/`: engine plumbing hooked into the registries (listed in `src/game`). An
  adapter only overrides the hooks the class needs; each registry's header lists every hook and
  its default.
- **Shared needs:** (in `src/mechanics`) a behaviour several classes use (wander, cover from hide nodes, sidestep,
  pain) becomes a shared mechanism with class parameters, documented as one. Shared code never
  lists the classes that use it.
- **Pain** uses the shared mechanisms with the class's constants in its policy: the reference's
  generic handler (two rolls, a heavy-hit limit) is `actor_pain.generic(hurt, previous_threat,
  chance, limit)`; its single `AI_StartPain` roll is `common.flinch` or the ground-combat
  `.roll`. All apply the reference's acquiring rule (`actor_pain.acquiring`): the hit that makes
  a player the enemy starts the fight and skips the first roll. Capture `previous_threat` before
  perception adopts the attacker.
- **Clip events** follow the reference's frame rule, applied once in the shared loader and
  `Sequence`: an event on table frame k is raised when the clip advances past it (it reaches
  k + 1, so (k + 1) × 50 ms at 20 fps); a clip played once ends, and a pain lock expires, when
  it reaches its last frame (`Sequence.lastFrameMs`, one frame before `duration`). A leap's
  strike is its row's second sound frame and does not exist when that column is empty. Use
  `duration` only for whole loops and presentation windows.
  An empty second-attack cell never strikes (the reference keeps it at −1).
- **Ally alerts** are shared (`actor_alert.zig`, hooked once in the actor step): a monster
  that takes a new enemy, keeps one in sight while chasing (one second in ten), or dies passes
  it on within its `speak` radius (0.15 × aidata active distance, or the map's `speak` key).
  Classes never alert by hand.
- **Navigation** is compiled for the player's standing hull: actor motion queries routes from
  where a player standing on the actor's floor would be (`actor_motion.navigationOrigin`), so
  small actors (rats, spiders) route like everyone else.
- **Cover** (spawnflag 512) is shared: `actor_cover.cycle` (shoot while the enemy is completely
  visible, rest 2–8 s, hide between shots, look out now and then) with the class's own shot;
  the guard keeps its own cadence and uses `actor_cover.between` and `destination`.
- **Melee hit sound:** the shared ground combat plays the clip's second sound when a strike's
  trace hits anything (the reference's punch and bite); a class with a silent weapon clears
  `hit_sound`.
- **Saves:** new persistent state goes on the class `State`, with `rebase`/`validate` hooks.
  Old saves must keep loading: add fields with defaults; never rename or remove a saved field
  or class key (the strict snapshot parser rejects unknown keys).

## 4. Tests

- Policy unit tests for every decision and timing rule on the sheet.
- A probe scenario that samples the class in game: `dk3_runtime_projections <classname>` prints
  its frame each tick. The clip sequence it shows must match the sheet.
- The ownership lint must pass, with the baseline the same or lower.

## 5. Acceptance

Add a run-log section (`## Sequence N — <slug> — <summary>`) with a **Change.** paragraph and
a scenario table. Record implemented and verified separately, and mark parity gaps explicitly.

## Backlog

The class registries exist (sequences 390–400): actor, weapon, map-entity and render classes all
plug in through their adapters. Each backlog item needs a review sheet first.

1. Mishima guard: done in sequence 402 (cover, side-steps, wander, do-not-move, pain, holding
   the attack pose). The sheet is at [mishima_guard](class-porting/mishima_guard.md). The other
   classes the reference lets take cover (thief, dwarf, fletcher, rocket gang, rocket MP) reuse
   `cover` and `actor_cover` with their own shot when their sheets are written.
2. Workers and prisoners: done in sequence 404 (sight hiding, run-away, cowering, alerted
   prisoners' wander, spawnflags 1/4, 16 and 128, work scripts). The sheet is at
   [civilians](class-porting/civilians.md); the armed prisoners were already in line with it.
3. Episode 1: sheets for froginator, skeeter, thunderskeet, vermin and sludge (sequence 405);
   surgeon, inmater, lasergat, protopod, cambot, psyclaw, cryotech, crox, rockgat, battleboar,
   deathsphere and ragemaster (sequence 406); firefly (sequence 410); kage, stavros,
   armed prisoners, fish and seagull (sequence 412); companions (sequence 413). Every actor class
   has a sheet. Open across sheets: sidekick dialogue and commands, Kage's hum volume, fish
   dormancy, the commando's tracer.
   Episode 2: centurion, cerberus, thief, spider and small spider, skeleton, satyr, column,
   griffon, harpy and medusa (sequence 410).
   Episode 3: dwarf, fletcher, knights, nharre, wyndrax, wisp, garroth, lycanthir, rotworm,
   rats (plague and pipe), doombat, dragon and buboid (sequence 411).
   Episode 4: chaingang, femgang, lab monkey, rocket gang, rocket MP, shark, the gunners (seals
   and Uzi gang) and Mikiko's monster form (sequence 411).
4. Monster clip rate: done in sequence 407. Actors play their clips at the reference's 20 fps
   (`clip_fps`, default 20; the lasergat 10); the converted `.anim` rate is the engine's 10.
   The neural models follow: their rate-0 clips are retimed to the authoritative duration and
   their fixed-cadence locomotion keeps its own clock.
5. Clip event timing: done in sequence 411 (strikes and attack sounds one frame later, clip
   ends and pain locks one frame earlier, matching the reference's frame update).
