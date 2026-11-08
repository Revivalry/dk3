# Medusa — review sheet

The reference files are `dlls/world/medusa.cpp` and the generic AI. Provenance only.

The native code is `src/classes/actors/medusa/` (`medusa.zig`: range, spit style; `server/medusas.zig`: attacks, gaze, petrify); her spit is the shared venom spit.

| Section | Reference behaviour | Native status |
|---|---|---|
| Identity | `monster_medusa` (one, e2m5e, spawnflags 192: do-not-move), model `m_medusa`, aidata 1200 HP; bite 15 + rnd·10, reach 80 (poisons); spit 10 + rnd·5 at 400 u/s, reach 350; her death fires the mid-level cinematic | Implemented |
| Range | Re-rolled: within 80 always; within 350 on 50%; within 1250 on 5% | Implemented |
| Attack | Within 80 the bite (`ataka`); beyond 350 or on a 5% roll the gaze; otherwise the spit (`atakb`) | Implemented |
| Gaze | Rattle (`atakc`, 3 s: grey flashes and gravel sounds on odd seconds), gaze (`atakd`, 3 s: eye contact petrifies), set down (`atake`); no pain for the whole gaze | Implemented |
| Pain | One 1% roll (`hita`, 850 ms) | Implemented |
| Death | `diea`, or gibs on a heavy kill | Implemented |

## Animation inventory (converted `.anim`)

`m_medusa`: `amba` 0–29, `ataka` 30–69, `atakb` 70–109, `atakc` 110–131, `atakd` 132–151, `atake` 152–161, `diea` 162–190, `hita` 191–208, `runa` 209–226, `walka` 227–250. All present.

## Verification (sequence 410)

- Implemented, not yet verified in game.

Sequence 579 adds a class-owned bot hazard hook for her rattle/gaze phases.
The warned target averts its view and holds fire while the source is visible,
then resumes ordinary aiming. The shared pilot discovers this declaration
through the hazard registry; it does not inspect Medusa state. No attack timing,
gaze admission, damage or animation is changed. Full encounter replay remains open.

Sequence585 records a lethal gaze in the rendered Episode2 continuation. The
warning hook traces to the actor's feet and accepts only a completely empty ray;
an actor-body hit or a floor lip can incorrectly suppress its warning. The repair
aims within the source body and admits a ray reaching that same actor through the
existing checked region-collision mechanism. Class-owned attack timing, mutual
eye-contact admission, petrified pose and damage remain unchanged. This repair is
verified by focused run22 on generation
`b2069a612bade486dc5a75acbf745176beed69b7e7b88fa91e25bb1c376a839c`:
147 issued commands avert the view during warnings. The run defeats Medusa,
completes the ten awakened-monster counter and timestream, and arrives in Episode3
with zero deaths. Visible continuation07 repeats the encounter and reaches
Episode3 with zero deaths; its rendered export passes movement and full media
checks. Hiro is visible in the inspected timestream ending frame. Artistic
gaze/cinematic comparison remains a separate gate.

The same run exposes a separate driver recovery defect: a lethally petrified
player retains frozen mode. The shared driver and input motor now recognize
nonpositive health when requesting the ordinary checkpoint restart. Regression
tests distinguish that case from a living cinematic hold and retain the existing
companion-loss path. This is a recovery mechanism change, not a new Medusa rule.
