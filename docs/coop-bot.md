# Scripted co-op bot

Sequence 335 (`coop-bot`) adds a player bot that plays the single-player
campaign headless, to verify the game end to end. Current sequence581 has routes
covering Episodes1/2, including the episode boundaries. Fresh Episode2 run394
completes every map and rune revisit through Episode3 arrival with zero deaths.
Sequence583 fresh Episode1 run148 completes New Game through Greece/Lemnos B
with two combat checkpoint recoveries and no companion losses.
Episodes3/4 still have placeholder routes. Campaign verification uses Ronin
(`--skill 1`); results retain their actual recovery counts and configured limits.
See [native acceptance](native-acceptance.md).

## What it is

- The bot is the single-player client (slot 0) of a dedicated server. It is
  admitted through the ordinary begin path once the spawn has settled, and
  re-admitted after every full map load (New Game, death checkpoint, save load).
- Everything it does is ordinary player input: `usercmd_t` movement, view,
  attack and weapon selection, plus the client commands `use`, `save`, `load`
  and `attribute`. It never places the player, grants items or fires targets.
- It also performs the client's network duties: it drains reliable commands and
  acknowledges regional world publication (`dk3_world_ack`, `dk3_world_patch_ack`)
  after validating each payload digest and the runtime identity, so resident
  worlds and campaign travel are admitted exactly as for a real client.
- A sandboxed Lua 5.4 route chooses what to do; the native driver decides how.
- Simulation runs faster than real time with exact 50 ms frames
  (`fixedtime 50`, `timedemo 1`): physics, AI, scripts, cinematics and travel
  are the normal game. The intro (115 shots, 567 s of game time) plays in full
  in about 30 s of wall time.

Not exercised: rendering, audio, client prediction and HUD (the dedicated
server has no client module). Use the existing probes for those.

## Gameplay recordings

Sequence584 adds `dk3_coop_render 1`: the pilot controls the ordinary local
single-player client instead of allocating a dedicated-server bot. The real
client receives snapshots and acknowledges resident-world publication. Only
pilot-origin user commands move its player; idle keyboard commands are ignored.
The view uses authoritative state, as demo playback does, rather than predicting
unrelated local keyboard input. Dedicated and ordinary player modes are unchanged.
The recorder explicitly enables `dk3_coop_fast 1` with16 ms client frames;
the server retains its normal50 ms simulation ticks. Client frames between
server ticks and unrestricted private local transport drain fragmented snapshots
instead of dropping their cadence during accelerated capture. Gamestate admission
resets timing cvars, so the opt-in driver restores these recorder settings.
This changes neither `sv_cheats` nor gameplay rules; playback uses normal time.

`dkq3/tools/runtime_coop_video.py record` stages all three native modules and
frozen routes in its report's private profile, then records ordinary engine demos
under a guarded private X display. `render` replays those demos, captures 720p
30 fps AVI with mixed game audio, and encodes H.264/AAC MP4. Logs, module/route
hashes, demo hashes, actual deaths and failed actions remain in the report.
The owner profile is never used. Supply an immutable `play/<generation>` as
`--engine`, a fresh `--report`, and the appropriate route/map:

```sh
python3 dkq3/tools/runtime_coop_video.py record --engine "$generation" \
  --report zig-out/reports/coop-video-584/episode1 \
  --script episode1-connected.lua --map intro --until-map e2m1a
python3 dkq3/tools/runtime_coop_video.py render --engine "$generation" \
  --report zig-out/reports/coop-video-584/episode1 --output episode1.mp4
```

Episode2 uses `--script episode2-connected.lua --map e2m1a` and finishes on
Episode3 arrival. `--seconds N` records an explicitly labelled short sample,
which does not establish episode acceptance. Full recording acceptance is
tracked in [native acceptance](native-acceptance.md).
`--load <recorded.sav> --stage N --map <map>` records an ordinary checkpoint
continuation. Export a failed attempt only with explicit `--include-failed`;
its actual failure stays in result.json. An assembled video must label such
attempts and continuations, and does not count as a fresh episode pass.
`assemble_coop_video.py <specification.json>` combines completed exports with
chapter cards. Its specification names `title`, `output`, and ordered `parts`
containing `report` and `label`. It verifies every demo reached natural EOF,
normalizes the output canvas while preserving aspect ratio, and writes a source
and media manifest beside the MP4. `--software-record` lets demo capture use
guarded software rendering while an independent GPU replay exports video.
An optional `clips` list selects original demo indices for a part; include it in
the retained specification when trimming bootstrap loads or duplicate retries.
The output manifest records the selected indices alongside the complete source
outcomes and demo hashes, so editing does not become a fresh-pass claim.
`render --clips 1 3` exports only the named original demo indices; use the same
selection in the assembly specification. `verify_coop_video.py <assembled.mp4>`
checks its adjacent source manifest, frame rate, chapters, complete video/audio
decoding and audible sound, then produces a sampled contact sheet. Review that
sheet separately before marking visual acceptance. For arrival saves, pass
`--stage 1` explicitly: replaying an already-completed arrival cinematic can wait
indefinitely for a sequence that will not start again.

Sequence585 interpolates the first-person replay's feet and view between actual
snapshots, retaining cuts for teleport/load/respawn/world/cinematic boundaries.
It does not apply mover carry twice or predict unrelated keyboard commands.
Campaign steering caps view turns at360 degrees/second, including physical local
corridor corrections; perception and aiming skill are independent of that cap.
Required resident media finishes before a replay consumes a world reference.

For a movement sample, add `--seconds 120 --motion-trace` to recording and
`--motion-trace` to rendering, then run
`python3 dkq3/tools/evaluate_replay_motion.py <report>`. It compares interpolated
and raw positions on identical grounded-moving frames, checks real issued turns
and snapshot cadence, and writes the retained metrics. Console notification text
is hidden from recordings while logs retain those measurements. A reviewed
presentation-only update can replay a frozen recording with
`render --update-presentation`; the recorded game/UI modules must remain identical,
the new cgame must match its immutable installation, and completed old exports
must first be retained separately. `render-inputs.json` records actual modules;
assembly includes its hash alongside original recording inputs.

The assembler and verifier also check actual packet presentation gaps and
durations. Explicit filter/encoder time bases and sequential timestamps keep
chapter boundaries on the30 Hz grid; a nominal30 fps header alone is insufficient.
`verify_coop_video.py` produces machine evidence and a contact sheet; retain a
separate sampled visual review after inspecting it. Sequence585's replacement
Episode1/Episode2 videos pass these checks and retain labelled source failures
and checkpoint continuations. See the scenario ledger for their exact scope.

## Run it

Episode 2 has a dedicated entry, `--script episode2-pass.lua --map e2m1a
--skill 1`. Sequence581 run394 uses the stricter `episode2-connected.lua` entry
and completes the fresh headless route with zero deaths. Full rendered/audio
episode acceptance remains open; see [native acceptance](native-acceptance.md).
`zig build game-server --prefix zig-out/native-dev` builds only the game module
for dedicated-server iteration. The runner also accepts `--resident-worlds` for
explicit regional admission coverage; a loaded save always retains its saved
ownership graph.

```sh
zig build engine-server game --prefix zig-out/native-dev
python3 dkq3/tools/runtime_coop_bot.py --report zig-out/reports/runtime-zig-335/newgame
```

Options: `--map` (default `intro`, i.e. New Game), `--skill 1|3|5`
(Ronin/Samurai/Shogun, default 3), `--bot-skill 1..10` (perception/handling
ladder of [bots-zig](bots-zig.md), default 10), `--cinematics 0|1`,
`--realtime`, `--timeout` (wall seconds), `--verbose` (1 Hz status lines),
`--developer 1` (dodge diagnostics) or `2` (also every spray forecast).
The runner uses dkguard, a temporary profile, the installed asset generation
(`zig-out/native-dev/play/current/share`) and never touches the preserved
installation or its saves.

Route development: every level entry is saved as `coop-<map>` once its arrival
scene ends, and the runner copies all saves into the report. Resume from one:

```sh
python3 dkq3/tools/runtime_coop_bot.py --map e1m1c \
  --load zig-out/reports/…/saves/coop-e1m1c.sav --report …
```

`--stage N` treats a mid-level save as a restoration inside stage N.

Evidence: `server.log` contains `dk3 coop:` lines (`level`, `stage`, `action`,
`done`, `failed`, `hurt`, `death`, `detour`, `develop`, `status` at 1 Hz,
`fail`, `finish`); `result.json` summarises maps visited, actions, deaths,
failures, game time and speed-up; `inputs.json` records the launch and the
SHA-256 of the module, server and every route file.

For a scoped repair, `episode1-repair.lua` and `episode2-repair.lua` use the same
routes and stop at the first death, retaining its evidence. Use the corresponding
`*-pass.lua` entry for the final campaign replay and its declared combat retries.

## Route language

`leap(takeoff, {index = platform}, opts)` follows the current surface of a
moving platform throughout the jump and succeeds only when that platform supports
the player. Point landings retain their existing behavior. Moving decks need a
real run-up and an ordinary jump; this does not place the player or move a deck.
`move({index = platform}, {around = {x_offset,y_offset,z_offset}, direct = true})`
settles at an offset from its current top surface, so a run-up stays aligned while
the deck rises or falls. Offsets belong to the brush's local coordinates and
rotate with it. Surface positions use the physical brush pose, since linked
collision bounds can expand to a sphere during rotation. `dk3.entity` exposes
`pitch`, `yaw` and `roll` for observing an authored rotation cycle.
Explicit jumps and these stances own their departure;
ordinary lift rides retain the pilot's protection against leaving mid-ride.
An explicit direct dive with a height/depth tolerance owns its underwater route:
automatic breathing does not turn it back toward a previous surface mid-tunnel.
Normal air depletion and drowning remain active, so the authored route must reach
its next air pocket.

Routes live in `dkq3/coop/` and are loaded through the engine filesystem as
`coop/<file>`. `campaign.lua` is the entry; `include "coop/episode1.lua"`
composes files. Lua is sandboxed: base, coroutine, string, table, math and
utf8 only; no io/os/package/debug, no bytecode, bounded memory (64 MiB) and
instructions between yields (50 M).

```lua
settings { level_deaths = 4 }          -- restorations allowed per map

level("e1m1a", function(visit, resumed)
  pickup { class = "weapon_ionblaster" }
  exit "e1m1b"
end)

level("e1m1b", function(visit, resumed)
  if visit > 1 then return exit "e1m1c" end   -- hub maps are re-entered
  return stages {
    { "river", function()
      path { {-445, -1430, 536}, {-302, -1314, 581} }
      shoot { index = 91 }                     -- authored entity index
    end },
    { "bridge", function() … end },
  }(visit, resumed)
end)
```

Targets: a targetname string, a point `{x, y, z}`, or a selector
`{ name=, class=, id=, index=, near={x,y,z} }`. `index` is the BSP entity index
of the current map (see the survey tool below).

An explicit fountain approach can use `cautious=false` to keep moving while
firing instead of starting unrelated combat or health-pickup trips. A control-use
action is never interrupted by an automatic health trip.

`exit({index = N})` selects the actual seam, including maps with several exits
to the same destination. `dk3.ground_route(t)` reads the supplied node links;
`nodepath(t)` walks that corridor with ordinary commands, using a 24-unit height
tolerance unless explicitly overridden. Its first landing above ladder rungs is
walked rather than being repeatedly skipped. A cautious direct segment preserves
its original footing during combat or a health trip and routes back there before
resuming. Node links are authoring
data, not proof of live reachability: separate water drops, jumps and puzzle
controls still need explicit route intent and recorded traversal. `dk3.has_key(n)`
reads the one-based campaign key ordinal used by objective catalog `owned` rows;
use inventory facts for revisits and mid-episode saved games. Named kill targets
are chased beyond the default room scan unless an explicit radius is supplied.

| Action | Completes when |
|---|---|
| `move(t, {radius, vertical_radius, direct, crouch, cautious, pace})` | within `radius` (default 40); `vertical_radius` optionally sets precise depth/height tolerance instead of the normal step allowance; `direct` steers straight and brakes into the goal, settling on dry land while admitting a passing waypoint in water; `pace` (0.1–1) walks it; `cautious` stops to fight whatever engages the player and resumes when the engagement ends |
| `path({points}, opts)` | every point reached, starting at the point nearest the player |
| `touch(t)` | the hull overlaps the trigger, or it fired/was consumed |
| `use(t)` | the control reacted (mover/trigger state); presses are retried with re-aim |
| `shoot(t, {from = {spots}, weapon, around})` | the target broke or died; `from` fires from the first spot with a lane; `weapon` names the weapon (the glove for glass under water); `around` names the part of a long target to aim at first (a window's far end, away from a companion's splash) |
| `pickup(t)` | taken (absent already counts as done) |
| `ride(lift)` | the bot rode the platform and it stopped at the end of its run (a train pausing at a corner part-way along, whose next corner carries on the same way, is pressed on from its on-board button) |
| `kill(t, {radius, around, count, hold, arena})` / `clear(opts)` | matching hostiles in the area are dead; `hold` fights from the current spot (strafing, dodging, repositioning when the prey hides); `arena` bounds that movement |
| `exit(map)` | the campaign travelled (identity seams, cuts and landings) |
| `cinematic()` | a scene played and released control (3 s grace if none starts) |
| `leap(takeoff, landing, {pace = f})` | a running jump landed on the far side; `pace` (0.1–1) slows the run-up and jump for a short hop onto a narrow ledge |
| `look(yaw, pitch)`, `weapon(id)`, `jump()`, `wait(s)`, `save(slot)` | as named |
| `wait_until(fn, {timeout, reason})` | `fn()` is true (polled each frame) |
| `heal(tree)`, `try(fn, …)`, `expect(cond, msg)`, `checkpoint(name)`, `finish()` | helpers |
| `dk3.sidekick(who, order)`, `companion_take(item, who)` | a companion order (`stay`, `follow`, …); `collect` for the item the player looks at |
| `regroup(radius, timeout)` | every living sidekick is within `radius` (one let through a door just opened for it) |
| `tend(radius, fraction)` | a hurt sidekick was sent for the reachable health nearest it until healthy or none is near (also run before stage checkpoints and exits: a sidekick's death loses the level) |
| `survey(map)`, `trace(t, from)`, `flood(goals, box, step, from, hull)` | read-only authoring logs: reachable controls, the area graph's route, a live flood fill through air and water (routes with their longest stretch under water); optional `from` changes the queried origin, without moving the player; `hull` defaults to standing and accepts `"crouch"` for low passages |
| `walkflood(goals, box, step, opts)` | read-only floor search; `opts.from` selects the query origin, `jump` is the probe's rise and `jump_span` (1–8) permits jump rays spanning several grid cells; `crouch` admits low passages. These geometric probes do not establish ballistic jump or traversal acceptance. |

Routes state intent: what to operate, shoot, take or reach, by entity. Getting
there is navigation's job, including closed doors, switched lasers and force
fields, lifts and breakables on the way (the planner in
[navigation](navigation.md#generic-navigation-sequence-340-generic-navigation)),
so a route survives map changes that keep the progression. Explicit moves remain
only for what the area graph cannot express (a boosted jump, a draught). e1m3a is
written this way.

Every action takes `timeout` (seconds) and `fight` (default true). Movement
can use `settle = false` for a through-point at the top of a climb, followed
immediately by its landing; ordinary direct moves wait for supported footing.
`vertical_radius` also supplies precise depth control on direct submerged moves.
Movement
actions also fail after 25 s without approaching the goal (along the area
graph's route where there is one, so a long way round counts), or 8 s without
any navigation route. A failure raises a Lua error naming the route line.

Read-only queries: `dk3.time()`, `dk3.map()`, `dk3.visit()`, `dk3.position()`,
`dk3.health()` (current, maximum, armor), `dk3.alive()`, `dk3.mode()`,
`dk3.weapon()`, `dk3.has_weapon(id)`, `dk3.entity(t)` (id, classname, x/y/z,
health, state, visible, wanted, fruit), `dk3.mover(t)`, `dk3.hostiles(radius)`,
`dk3.visible(t)`, `dk3.cinematic()`, `dk3.log(text)`. For authoring:
`dk3.route(t, from)` (the area graph's predicted route as points, from the
player or a given point), `dk3.trace(start, end, hull)` (live collision against
world and movers: fraction, end point, normal, class and entity index,
`start_solid`, `ladder`), `dk3.contents(point)` (contents bits there, liquids
from movers included: water 32, slime 16, lava 8, solid 1), `dk3.pickups(radius)`,
`dk3.reachable(t, kind)`, `dk3.controls()` and `dk3.plan(t)` (the navigation
planner's next step toward `t`: the control to operate, `{wait=true}` while the
gate in the way is moving, or nil). A zero-length hull trace tells
whether a player fits at a point; with `dk3.contents` that is enough for a
route-local flood fill through air and water when the area graph (built
without movers such as a train of water) cannot answer.

### Stages, checkpoints and deaths

For a checkpoint on constrained footing, use `supplies = false` alongside
`checkpoint = true`. The health admission rule and save still apply; the stage
does not automatically leave its catwalk for healing, ammunition or companion
supplies. Required supplies can be collected explicitly from a safe approach.
An explicit combat `arena` also keeps a held order bounded when its target
remains out of sight; the blind-target pursuit fallback applies only without
an arena.

Game saves include the bot's `coop-<map>` arrival save, the game's arrival and
60 s periodic autosaves. During a scripted run, periodic files remain available
on disk but do not replace the explicit stage recovery checkpoint: restarting
a stage from its midpoint can repeat an already operated lift or control.
Normal player autosave recovery is unchanged. Admitted checkpoints record the
running stage and how many of its actions had completed. When the bot dies it requests
the authored death checkpoint (attack); the world restores (often a full map
load), the bot is re-admitted and the level body resumes at that stage,
replanning it from the restored position and live objective state. Generated
paths and conditional pickups must never be resumed by skipping an action
ordinal: their action sequence changes with the saved world. Stage bodies
must check completed controls and collected items before operating them. Retries vary the
bot's own choices per attempt (strafe sides, dodge order, aim noise), so a
deterministic replay is a new attempt. `level_deaths` (default 3) bounds
restorations per map (`map_deaths = { e1m2a = 10 }` raises it for one map);
`deaths` optionally bounds the whole run. Long levels
mark stages `{ "canal", checkpoint = true, function() … end }`: the stage saves
as it begins (slot `coop-<map>-<index>`). Supply preparation tries to reach60%
health. Save admission requires at least25% health, with health plus half the
armor (capped at maximum health) reaching50% of maximum health. A later death
resumes there rather than at the arrival. The runtime does not spend save gems
on saves.
Saves are not counted among a stage's actions (one may be written after the
next action began), and a checkpoint save records its stage with none of the
body's actions done. `runtime_coop_bot.py --load <save> --stage N` resumes a
mid-level save inside stage N, for iterating on one stage.

Precise leaps default to `fight = false` so weapon recoil cannot change their
takeoff or landing. Moving-platform waits accept `crouch`, including through
`wait_until`; the declared surface offset follows the platform's physical pose.

## How the bot plays

Wanted pickups must actually leave the world or stop being wanted. A nearby
approach that remains above a submerged item fails rather than silently advancing
the route; authored dive legs can assert key ownership before leaving a puzzle.
Nearby harmless hazard forecasts do not suppress normal combat retreat. A bank
ambush must be fought before an explicitly noncombat underwater passage.

`server/coop_motor.zig` turns one frame of intent into a command:

- AAS routing with waypoint commitment (adjacent areas can route through each
  other's entrances), authored route controls/lifts/teleporter passages from
  the multiplayer bot adapters, local sidestepping around actors and props,
  hop-and-route recovery when straight steering stalls.
- A door that stays shut in front of the route (opened from elsewhere) sends
  the bot to its authored control first, following buttons, relays, triggers
  and event generators; progress is then measured toward that control.
- Climbs ladder surfaces (including rungs that slide out of a wall, which the
  area graph lacks) when the goal is above; rides platforms and carts standing
  still on them, steering straight at their centre, and never chases one that
  left without it; steps off an actor it landed on.
- Never steps into an exit other than the targeted one, or within 48 units of
  a lethal hazard (laser barriers); off-route steps (sidestep, charge, unstick,
  dodge, strafe) require supported floor along the way and no liquids.
- Engagement inside the skill ladder's view cone; fire only when the view has
  settled; lead projectiles by target velocity; aim above the surface at wading
  targets and wait for a steady shot; shoot what hunts the player, is near, or
  was ordered killed; keep the last 12 rounds for authored targets and fight up
  close with the glove meanwhile. Never fires the ion blaster from the water or
  into water within reach of its discharge (64 units: the shooter is hurt too);
  takes up a splash weapon only with half its radius again to spare, so an
  approaching enemy does not cause weapon swaps; never chooses a proximity
  charge (C4) itself, since charges left for prey that never arrives go off
  under the player further along the route. Keeps its current target unless
  another is clearly nearer, and holds fire for a moment when five shots over
  three seconds have not hurt the target (a ledge or the water takes them).
- Dodging: hostile projectiles and slow missiles by closest approach, Thunderskeet
  spray by the server's own forecast; the chosen step minimises total expected
  splash at impact time, favours breaking the line it is being led along, and
  stays on floor away from edges (within shallow water it already wades in,
  never into harmful liquids). No dodging or charging from a ladder or in
  mid-air, where the step would only carry the player off the rungs or past a
  narrow landing.
- Swims at the surface, or at the route's depth under water (passages below
  barriers and fallen slabs), diving toward a waypoint that is more below than
  beside it; surfaces after 9 s under water where air lies straight above (a
  player has 12 s of air; under a ceiling the stroke stays on the route). Spends
  attribute points (power, attack, vitality, …) and detours to a health
  pickup below 45% health except during held fights.

Added in sequence 340 from runs on the episode-1 chain: a stride that would meet
cover before its target holds fire, and a kill action treats a seen-but-covered prey
as not yet engaged (bolts are boxes: e1m3a's corridor guard, its cell-block panel);
after its own bolt comes back the bot holds fire briefly; a body standing on a
precise segment is stepped around (e1m1c's worker); narrow footing above a drop is
walked rather than run, except on precise segments, which keep the route's pace; the
bot leans away from a current beside a drop (e1m2b's beam); swimming, it dives
under a ceiling edge it would otherwise float against; health stations are used
from within their 64-unit reach; a health detour needs a way back and never starts
while the route waits; presses of other controls do not count as presses of a `use`
objective.

Added in sequence 345 from runs on e1m3b–e1m5a (the shared pilot, so companions
get the movement parts): standing to shoot, the bot ducks where the target stays
in sight from down there (a guard's rounds aimed at the chest mostly pass over a
crouched player); a weapon whose shots have not hurt the target is set aside for
that target and another that reaches it is tried before the target counts as
futile (a blast weapon after two rounds and 1.5 s: its round leaves from the
muzzle, below the eye, and up a ramp the rising floor takes it, which the blast
lane check now traces from the muzzle); the wide berth by lethal volumes holds in
a fight only, and walking along one (a floor fan at the edge of a crawlway) the
bot keeps a hand's breadth off it, looking a stride ahead but not past the
route's next corner; straight steering ducks under a low ceiling as routed
strides do; an open door with a part still in the way is walked round once
pressing on has stalled; circling the same route point (overshooting it each way
against a closed door) counts as a stall, so the door's control is sought; an
aggressor hunting the player from out of sight and more than 600 units off is
not gone round the map for. Movement stalls are measured along the area graph's
route (botlib travel time), so a long way round is progress. Navigation: a
player pressed against a wall just outside the graph's expanded solid, whose
botlib area has no route, plans from the nearest area a short unobstructed step
away; a destination is the area containing it or one a little above (an item's
base in a crawlway lies below the lowest origin there); door gates leave out
areas a crouched player passes beneath; damaging volumes also gate the thin
areas beside them where every position puts the hull inside. `ride` presses on
from a train's intermediate stop and finishes only once the rider has landed again;
standing on a mover the bot never hops to get unstuck. Also: blast weapons are put
away when badly hurt while another weapon reaches; with nothing in view the bot keeps
a close-quarters weapon ready; a fight being lost (20 health gone in a few seconds
against much less dealt) is backed out of into cover for two seconds; a control's
use and shots trace through trigger volumes as the game's own do. `regroup`, `tend` and the exit's approach (the
health about the door) keep the party alive across maps.
A route that takes a lift standing away which the traveller may not call (a
companion: it operates no controls) is planned round the lift on foot when a
way exists. An object shot at (a grate, a crate) with one of the party in the
lane or beside it is not shot with a blast weapon while another reaches, and a
blast round is fired at one only along a clear lane from the muzzle and with
nobody of the party within its splash where it lands. After a companion loss,
each reload sets the stage the save it loads resumes at (the checkpoint's own,
the resumed save's, else the arrival's), whichever save an earlier reload tried.

Added in sequence 350 from runs on e1m6a–e1m6c (all of it the shared pilot
unless noted): a hop armed for a stalled stride refuses itself when the ground
ahead falls a long way below the feet or is a gas that kills, and says so
(`event=hop-refused` at developer 2) — e1m6a's lab killed the bot on every
attempt by a hop off the ledge beside the button's room; careful footing judges
a stride by what the body's hull stands on rather than what a slim column
happens to touch, so a catwalk's lip over the nitrogen is walked instead of
refused for ever (e1m6c's ring froze on its doors for this); a `ride` whose
deck is not in the area graph boards it directly — the mover has no floor in
the graph at all, so the first phase steps onto the deck beside it rather than
routing to a point under it; a heading is bent away from a lethal-liquid edge
that runs beside the body, the way a player gives a lip a wide berth — the
area graph walks an area's centre, and where a diagonal edge closes on the way
the centre lies within a couple of units of the drop, while a hull that keeps
only part of its width on the plank is supported until it keeps none (e1m6c's
west catwalks over the nitrogen).

Two parts of the reference's sidekick logic came from e1m4b, whose exit wants
Superfly: its AI node graph carries a sidekick teleport node at the vent's exit
over the keypad room, which sends the party to the far end of the casket
corridor, and the graph's way from there runs through "sfdoor", a door nothing
in the map opens. The runtime now reads the converted node graph
(`dk3/routes/<map>.json`): a player within 32 units of a sidekick teleport node
(once per map entry or restoration) teleports each living companion to the
node's point as an authored teleport does, and a door that a ground-node link
crosses, carrying an AI node name and a name nothing targets, is a party door —
companions open it on contact as they do an unnamed door, and navigation gates
never hold it shut. Only e1m4b's sfdoor and e3m5a's death doors qualify. The
companion door check also now matches Daikatana's `func_door_rotate`. A
companion whose leader is within 320 units of an exit that requires it no longer
settles up to 192 units off: it closes to within 112, inside the 150 the exit
counts (Superfly settled 155 off by e1m4b's exit while the player waited for him).

## Tools

`dkq3/tools/coop_route_survey.py e1m1c` lists a map's starts, exits, keys, locks,
named controls, companions, weapons and monsters from the local converted map
package, with entity indices for `index =` selectors.
`dkq3/tools/coop_route_map.py e1m2a --out map.png [--band z0 z1] [--region …] [--mark x,y,z]`
renders walkable floors top-down by height with controls, exits, starts, movers
and pickups marked and liquid surfaces hatched (plus a JSON legend), for reading
layouts and stuck positions.
`dkq3/tools/coop_route_aas.py e1m2a path -- x,y,z x,y,z` answers offline what
navigation will do: the reachability path between two points (walk, swim,
water jump, walk-off-ledge…), `area` for a point's area, and `flood [--reverse]`
for everything a point can reach (or that can reach it) with the map's
controls, exits and pickups marked reachable or not; `--avoid box` treats a
closed door's areas as blocked. Movers are not in the area graph: use
`dk3.trace` in a route to probe doors, slabs and lifts in their live state.
In a route, `survey("e1m2b")` logs which controls and exit the area graph can
reach from the bot's position; `advance`/`progress` operate reachable controls
(buttons, touch triggers, shootable controls, use-doors) never operated before
on that visit. Existing ordinary-input drivers (`runtime_*_route.py`) are good
sources of authored waypoints.

## Layout

| File | Owns |
|---|---|
| `engine/lua/`, `engine/LUA-UPSTREAM.json` | Unmodified Lua 5.4.7 (MIT) and its file hashes |
| `src/engine/lua.zig` | Sandboxed VM, coroutines, budgets |
| `src/mechanics/domain/coop_route.zig` | Typed actions, targets, pure geometry |
| `src/mechanics/server/coop_bot.zig` | Driver: admission, levels, stages, actions, deaths, evidence |
| `src/mechanics/server/bot_pilot.zig` | Body-agnostic locomotion and combat planning (shared with companions) |
| `src/mechanics/server/coop_motor.zig` | Client adapter: pilot frame from the player, command to `usercmd_t` |
| `src/mechanics/server/bot_evasion.zig` | Threat prediction and evasion |
| `src/mechanics/server/bot_survival.zig` | Aggressor choice, hold/approach/break-off, health detours (shared with companions) |
| `src/mechanics/server/coop_targets.zig` | Selector resolution |
| `src/mechanics/server/coop_link.zig` | Client duties: reliable commands, world publication acks |
| `src/mechanics/server/coop_script.zig`, `coop_prelude.lua` | Lua boundary and the route language |
| `dkq3/coop/` | Campaign routes |
| `dkq3/tools/runtime_coop_bot.py` | Headless runner and evidence |
| `dkq3/tools/coop_route_survey.py`, `coop_route_map.py`, `coop_route_aas.py` | Route authoring: entity survey, floor maps, offline area graph |

## Open work

- Episode 1's complete route is authored, including the Vault crate vent,
  moving platforms, companion return and brain/guardian finale. The earlier
  walled-yard block is passed through the guide's actual vent loop and return
  panel. Sequence583 fresh resident New Game148 completes all17 Episode1 maps,
  the ending and Lemnos A into B on native candidate84, with two normal combat
  checkpoint recoveries, no companion losses and unchanged recovery limits.
  This is a continuous headless campaign pass with cinematics enabled;
  rendering/audio remain unverified. The frozen inputs and exact installed
  native generation are reconciled in `episode1-pass-583/acceptance-151.json`.
  A standalone finale start lacks the campaign's arsenal and is not encounter
  acceptance.
  Episode 2 is now fully authored and its fresh Ronin headless run168 completes
  every map into Episode 3 with zero deaths. Episodes 3–4 retain generic
  `progress` bodies and need authored puzzle and encounter steps.
  `episode1-pass.lua` runs the normal campaign with `settings {finish_map =
  "e2m1b"}`: finish only after ordinary arrival preparation in that map, having
  crossed the E1/E2 boundary and traversed Lemnos A. This setting does not skip
  an exit, force travel or replace a level body.
- Companion handling in routes (Superfly, Mikiko): orders and exits that
  require them. The companions themselves now fly the same pilot; see
  [bots-zig](bots-zig.md#companions).
- Runs are not bit-for-bit deterministic: resident-world preparation is
  paced by the wall clock, so encounters can shift between runs.
- Co-op with a second (human) player is not supported; the bot occupies the
  single-player slot.

## Shared pilot

The motor is split in two. `bot_pilot.zig` plans one frame from an intent and
a body description (movement state, hull, collision, weapon table, slot) and
returns a movement command: view angles, forward/right/up, attack, use,
weapon. `coop_motor.zig` only builds that description from the client's player
and encodes the command as a `usercmd_t` (angles relative to the server's
delta angles). Capabilities gate what the body may do beyond walking and
fighting (authored controls, operating lifts, teleporter passages, exit
avoidance, use, shooting a blocking civilian); the co-op bot has all of them.
`bot_survival.zig` holds the driver's aggressor choice, hold/approach/break-off
decision, ignore list and health detour, for reuse by companions.

The split is behaviour-preserving for the co-op bot: from New Game the event
stream (every `dk3 coop:` line except status) is byte-identical before and after
(`zig-out/reports/sidekick-pilot/{baseline,final}-newgame`).
