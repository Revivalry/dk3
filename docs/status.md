# Current game state

**Assessment: 20 October 2026 · game-state-427.** The native rewrite was merged into
`main` as PR #1 on 19 October (`25a8d07`). Main now contains the Zig game/client/UI
runtime. The separate preserved installation and its saves remain local and untouched.

**dk3 is a playable development build. The complete game is not accepted.**
The source covers campaign systems and multiplayer, with substantial focused scenario
evidence. Sequence 579 (5 November 2026) now records a complete Episode 2 headless
scripted pass from fresh Lemnos through every rune revisit, both bosses and the
ten-enemy ending into Episode 3, with zero deaths in final run168 (earlier run159
used two combat checkpoint retries). This is
authoritative gameplay evidence; full rendered/audio episode acceptance and the
complete four-episode campaign remain open. There is no defensible overall
completion percentage. See the [current scenario ledger](native-acceptance.md#sequence-579--episode2-coop--authored-progression-and-repair-pass)
for later repair replays and final-build status; the assessment below retains
its original 20 October scope.

Sequence583 (6 November 2026) adds a complete fresh resident Episode1 headless
pass: New Game/intro, all17 maps, ending and Greece/Lemnos A into B. Run148 uses
two normal combat checkpoint recoveries within unchanged limits and loses no
companions. The tested ReleaseSafe generation is installed for `zig build play`,
with all107 owner profile/save/cache files unchanged. See the
[Episode1 acceptance](native-acceptance.md#sequence-583--episode1-pass--resume-complete-episode-1-verification)
for frozen inputs and scope. Cinematic character rendering, audio, prediction
and hardware FPS are not exercised by this dedicated-server pass.

Sequence584 adds recorded bot walkthroughs across all17 Episode1 maps and19
Episode2 maps, including endings and next-episode arrivals. They are edited
failed attempts and labelled ordinary checkpoint continuations, not fresh
uninterrupted passes. Episode1's91-minute and Episode2's70-minute chaptered MP4s
pass full video/audio decoding and sampled-frame inspection. See the
[video evidence](native-acceptance.md#sequence-584--coop-video--record-episode-1-and-episode-2).
This does not establish cinematic artistic parity or full campaign acceptance.

Owner review found teleport-like movement in the sequence584 recordings.
Sequence585 adds player-camera interpolation, a campaign turn cap that also covers
local corridor corrections, full-cadence snapshot capture and required-media replay
admission. The88-minute Episode1 replacement passes measured movement gates,
uniform packet timing, full decoding and sampled-frame inspection. Episode2's
73m41s replacement passes the same gates through its ending and Episode3
arrival. Both retain labelled checkpoint continuations and source failures;
owner saves/settings remain unchanged. File decoding alone did not
establish movement quality in the earlier videos.

## Assessment basis

This review checked the merged source, class registries, the latest
[native acceptance ledger](native-acceptance.md), class review sheets and available
local report results through sequence 426. It also checked the merged branch's
[successful component CI](https://github.com/dmytrogajewski/dk3/actions/runs/39318618327)
and prepared a new isolated installation from current code and existing local assets.
The component suite passed 542 Zig tests and 350 Python tests before this documentation
pass. Those checks establish build/regression health, not campaign completion.

The source inspection and recorded scenarios below have different evidentiary weight.
A feature being present, a map loading or a historical scenario passing does not
establish acceptance of every path in the current game.

## System assessment

| Area | Current implementation and recorded evidence | Remaining acceptance |
| --- | --- | --- |
| Engine and architecture | Bundled ioquake3/BSPC, Linux x86-64 client/server, Zig 0.16 native modules, ECS/jobs and checked class hooks. Ownership baseline: zero violations. Source lives in `src/engine`, `core`, `mechanics`, `game` and `classes`. | Final source/provenance review and fresh public clone → build → legally supplied assets → play acceptance. No legacy game runtime or required QVM backend is maintained. |
| Campaign and navigation | Four-episode content admission and campaign machinery exist. Sequence 340 records 84 map admissions and two continuous Ronin driver routes from New Game/intro to e1m3b with candidate navigation. | The candidate route is historical, scoped evidence. It is not a fresh run of this assessment or a complete Episode 1. Continue from e1m3b and verify all episodes, bosses, puzzles, cinematics and endings. |
| Weapons and progression | All 28 weapon classes have native policies, firing/controller integration and saved action state, including the intentional Flashlight extension. Focused firing, damage, status and restoration checks are recorded. | Full per-weapon campaign/multiplayer interactions, timing/audio/effect comparisons and progression branches. HD weapon art is a separate pipeline: no HD replacement is enabled by default and its Glock pilot remains visually unaccepted. |
| Actors | Class-owned adapters and 57 review sheets cover episode actors. Correction passes 402–413 and later Crox/rat fixtures provide scoped behavior evidence. | Many review sheets still explicitly lack in-game acceptance for some changes. Per-class implementation and review are not all-encounter or campaign coverage. |
| Companions | Orders/HUD, stop/teleport nodes, breathing, careful footing, treading water and out-of-view catch-up are connected. Seven sequence-426 fixtures have passing result files. | These use diagnostic setup, high health and/or enemy removal. Liquid samples are one second apart. Slick-floor braking, liquid self-escape, full encounter behavior and cross-world/campaign party availability remain open. An unexplained five-point dry-floor health loss is retained in the nitro-map record. |
| Saves, menus and difficulty | Validated native saves, resident/visited world archives, copied-save migration, save dates/previews and live difficulty rescaling exist. The recorded guard changes from 50 health to 63 on Shogun and 38 on Ronin. | Complete mid-action, party, cinematic, cross-episode and development-save matrix. The second GL1 preview capture still shows HUD; Vulkan save-preview acceptance is open. Original Daikatana saves are not imported. |
| Streaming and transitions | Resident-world admission is opt-in and off by default; classic map reload retains visited progress. Asynchronous image/preview/checkpoint optimizations are implemented. The ledger records GPU transition timing improvements. | Those timing claims are recorded measurements; the named timing directories were not found during this artifact review and were not remeasured here. Classic versus resident campaign traversal and remaining autosave/RT admission stalls require coverage. |
| Rendering | Vulkan 1.3 with classic presentation and ray tracing off is default; GL2 fallback and GL1 selection remain. HDR/materials, liquids, weather, RT, DDGI, optional path tracing, bundled FSR 3.1 and optional external DLSS are implemented. Later scoped GPU measurements supersede early smoke-only claims. | Overall owner visual acceptance, all-map/material/hardware comparisons and complete performance coverage remain open. Hardware-specific FPS samples are not general guarantees. |
| Cinematics and generated characters | Source vertex cinematic models are the default; skeletal cinematics are opt-in. Playback, restoration and authored humanoid action work have focused evidence. Rejected motion candidates were withdrawn. | Complete cinematic recreation, acting/facial/body quality and matched-shot acceptance. The white-gi Hiro candidate failed owner review; structural metrics do not override that result. |
| Multiplayer | Native DM, CTF, deathtag, bots, browser/lobby and online service code exist. Earlier scoped matches/network lifecycle tests are recorded. | Fresh complete mode/map/human-network coverage remains open. Sequence 340 deathtag carriers did not capture in its 600-second run. Historical online deployment success is not current-service or native-migration acceptance. Co-op multiplayer is outside scope. |
| Assets and release | A terminal bundle installer selects Steam or custom source data, offers local HD generation, and installs to an isolated destination. The Windows x86-64 GNU cross build succeeds. Source builds need no proprietary assets or private reference code. | Windows installer/gameplay acceptance, optional HD production on target hardware, retail-profile play acceptance, conversion-loss review, final publication/license review and complete installation-to-ending acceptance remain open. Original/converted data, generated asset packages and saves remain local. |

## Fresh assessment probes

The assessment uses the isolated native development installation, temporary profiles,
`dkguard --headless`, software OpenGL1 and existing legally supplied local assets.
Both accepted runs used the synchronized scenario driver under `dkguard --headless`
with an 8 GiB cap and a 180-second timeout. Their immutable installation/module/asset
identity is `98392cd5628d6695e4acefd2a6f7c0361a750a438d4e71d4455fced1544547a1`.
The first legacy movement/save attempts started during region admission and were
invalid setup: movement diagnostics were incomplete and save correctly refused
`RegionAdmissionInProgress`. Those attempts are retained, not counted as gameplay
failures or accepted runs. The synchronized replay waits for admission and processed input.

These are diagnostic integration probes, not a new campaign playthrough or visual
acceptance of the Vulkan renderer. Private logs/captures stay in
`zig-out/reports/game-state-427/`.

| Scenario | State | Scope |
| --- | --- | --- |
| Isolated `zig build play-install` | Passed | Current engine/native modules installed with completed local assets and optional overlays; preserved installation/saves untouched |
| Processed movement and crouch input | Passed | After initial admission: position (1608, −2592, 561) → (1601.770, −2578.734, 552.125), forward release and crouch input observed |
| Native save/load | Passed | Saved health 997, changed to 900, restored 997 with processed input on e1m1a |
| Resident-region save/load and death recovery | Passed | Controlled e1m1a/e1m1b transfers preserve independently changed actor health, player identity and saved health 73; death recovery restores the same state |

## Current technical identities

| Interface | Identity | Authority |
| --- | --- | --- |
| Wire protocol | 1351 | `engine/ioquake3/code/qcommon/qcommon.h`, `src/online/api.zig` |
| Renderer export ABI | 13 | `engine/ioquake3/code/renderercommon/tr_public.h` |
| Native gameplay save schema | 2, with schema-1 migration | `src/mechanics/domain/snapshot.zig` |
| Portable save stream | Codec version 1, `DK3SAVE\0` | `src/core/domain/save_stream.zig` |
| Only game/client/UI runtime | Zig 0.16 | `build/runtime.zig`, native module roots |

These identities describe different interfaces and must not be conflated. See
[engine architecture](engine.md), [protocol](protocol.md) and [save format](save-format.md).

## Next acceptance work

1. Continue current-candidate campaign verification after Episode1/Lemnos B
   acceptance148: repeat Episode2 on the current pilot as needed, author
   Episodes3–4 and preserve encounter, death, save/reload and transition evidence.
2. Close class/companion and cinematic visual gaps with scoped scenarios and owner
   review. Keep failed/rejected candidates and unrun cases visible.
3. Complete native multiplayer, retail/fresh-install, independence and release matrices.
   Run broad component checks after connected implementation/repair work, without
   duplicating `make lint`, `make test` and `zig build test`.

The [roadmap](rewrite-roadmap.md) defines the complete scope; the
[workflow](development-workflow.md) defines implementation and verification cadence.
The [acceptance ledger](native-acceptance.md) and
[run journal](../specs/runs/RUN-dk3-independent-port.md) retain historical inputs and
limits. Earlier journal coverage stops at sequence 423; results 424–426 are summarized in
the acceptance ledger and local artifacts. This assessment adds the sequence-427 entry.
