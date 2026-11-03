# Native port acceptance

The [current game assessment](status.md) reconciles this historical scenario ledger
with the merged source as of 20 October 2026. Results below retain their original
runtime, assets and limits. Implementation and focused passes do not establish
complete episode/campaign or artistic acceptance.

## Sequence 572 — perf-main-rebase — integrated PR and regression qualification

The owner requested publishing pending code, merging performance PR #14 into
main, then rebasing this checkout and updating its existing PR. The performance
worktree was clean and matched its published head `2c5587f`. Canonical pending
code was committed and pushed as `3f9b785` before #14 merged at `39e7e20`.
The feature branch was then rebased onto that main commit and PR #13 updated.
The pre-rebase branch is preserved locally as `backup/bots-pass-before-perf-572`.
Local saves, `.keep`, screenshots and video files were excluded from publication.

Conflict resolution retains main's complete loading, prepared-save, ECS and
Vulkan implementations. The resulting gameplay PR has no renderer, snapshot
decoder or ECS changes relative to main. Water-clearance coverage retains both
checkouts' nonblocking-volume cases. The automatic companion duty and authored
co-op routing remain on the rebased feature branch.

| Scenario | State | Evidence / limits |
|---|---|---|
| Perf integration and branch ancestry | Passed | #14 merged through GitHub with its green checks and pinned head. Local main is `39e7e20`; both main and `perf/loading-rendering` are ancestors of the rebased branch. |
| Integrated build and installation | Passed | `zig build test play-install -j4` with the existing pinned Python test environment builds the engine, all renderers and native modules and prepares generation `25af466ba3efe2d0bcb1bc76ef64a56744375f439c232d55edf73a8d5aafee29`. No desktop game launched. |
| Python/component checks | Passed | All 397 Python tests pass with Pillow/scipy/yaml from the pinned test environment; codec, online, process and C contracts pass. Earlier sequence 571's Python dependency/fixture failures no longer occur after integration. |
| Native integration regression | Repaired; passed | First aggregate: 579/580 Zig tests, one crash. Co-op target diagnostics queried verbosity inside perf's engine-free exit-arrival fixture. The fixture now binds/restores a gateway admitting only the cvar query; unexpected calls still fail. `zig build test-runtime -j4 --summary all` passes 33/33 steps and 437/437 tests. Together with the unchanged aggregate checks, all 580 Zig tests pass. No production exit behavior changed by this repair. |
| Exact owner-save plate and return chain | Passed, scoped | `perf-main-rebase-572/full-save/`: complete original region copy, automatic physical press/hold, all four exit movers open, diagnostic activation of the actual release wheel, then automatic return. No companion orders. The original save hash is unchanged. This is not a walked route or ordinary wheel-use acceptance. |
| Saving that copied region | Failed | The same replay still reports `Save/load refused: InvalidRegion`; its result explicitly records `persistence.passed=false`. Sequence 571's isolated-room persistence result remains scoped to that fixture. Full-region save acceptance remains open; the completed replay does not prove the earlier transport overflow generally resolved. |
| Ownership and format | Passed | R1–R11 remain zero; Zig formatting and Git whitespace checks pass. |

The final fixture repair changes test setup only, after the coherent installed
runtime replay. No duplicate broad aggregate was run: affected native checks
were refreshed while still-valid Python, codec, online, process and C results
were retained. Gameplay evidence stays local under
`zig-out/reports/perf-main-rebase-572/`.

## Sequence 571 — companion-puzzles — automatic station duties

**Change.** Free companions now take physical puzzle stations advertised by an
entity class's checked `companionDuty` hook. On encountering a nearby visible
station the companion announces its intent, walks onto it through normal
collision/navigation, holds it, and follows again when its class reports the
authored completion. Explicit orders, carrying, stops, teleports and scenes
take priority. A station has one living helper. The held duty is optional
class-owned save state; older saves default to no duty.

The owner's latest save was `save2.sav` in the performance checkout, e2m4b,
with Hiro at approximately (519.718, -3488.865, 310.895), standing on the edge
of the `leftbutdown` plate. Its `trigger_toggle` is companion-only (flags 9).
There was also a real progression bug: the plate admitted Mikiko, but its
event generator rejected companions unless monsters were enabled. Timeline
admission now belongs to the event-generator class and accepts companions by
default, retaining the flag requirement for other monsters. The original save
was read/copied only; its SHA-256 is unchanged.

The supplied 84-map BSP corpus has one toggle, this companion-only plate,
plus 11 authored sidekick-stop and 19 teleport volumes (and one HUD trigger).
The existing stop/teleport choreography remains in place. The new station
contract applies through the registry wherever a class offers it; it does
not invent a timeout or a proximity shortcut for an unknown puzzle's release.
Here, `openformk` removes `leftevent` and the depressed plate while opening the
return path, which releases the helper safely.

| Scenario | State | Evidence / limits |
|---|---|---|
| Latest owner save identified | Passed | `floor-switch-570/come/source.json`, `companion-puzzles-571/monitor-clock/source.json`; original hash unchanged. Earlier canonical e2m3b saves were older. |
| Automatic approach, press, hold and exit doors | Passed | Exact owner-save copy in `monitor-clock/`: Mikiko reaches the plate without a companion order, it depresses eight units, the bars rise 216 units and both exit-door leaves open. The player takes an ordinary backward step to clear her approach. |
| Hold through save/reload | Passed in isolated room | `room-ready/holding.sav`; the labelled fixture retains the owner's active-map entity state but omits other resident worlds. `authored-release/` reloads that held state, saves/reloads it again and retains the physical occupant and duty. |
| Authored completion releases the helper | Passed in isolated room | `authored-release/passed.json`, `released.sav`: diagnostic activation of the actual release wheel runs its ordinary mover/target chain; Mikiko announces her return, clears the duty and resumes `follow`. No companion orders. This does not qualify walking the route or physically using the wheel. |
| Complete region save and long replay | Failed | Before the feature, the copied region already refused saves with `InvalidRegion` (`floor-switch-570/replay/`). The longer camera replay also drops with `Server command overflow` (`installed/`, `monitor-clock/`). Neither failure is hidden by the room fixture. Whole-region persistence/transport acceptance remains open. |
| Native tests and ownership | Passed | `zig build test`: all 559 Zig tests pass, including duty ownership, explicit-order/carrying/scene eligibility, default admission for companions, monster exclusion, old-save defaults and held-duty identity/JSON preservation; R1–R11 remain zero. |
| Full aggregate test command | Failed | Python tooling reports 10 errors: eight missing-Pillow imports, the release-bundle libdeflate-license fixture, and the runtime-media `checked_assets` fixture mismatch. The native, codec, online, process and formatting checks pass. |
| Canonical play installation | Passed | `zig build play-install --summary all`: 90/90 steps. Generation `efe8db74c828f7265d06ad41081a09a6e010063eeb7efe6b76a21e8bbcfd5594`; prior generations and saves preserved. Performance-checkout code/install was not modified. |

Evidence is under `zig-out/reports/companion-puzzles-571/`; the reproducible
driver is `dkq3/tools/runtime_companion_puzzle_probe.py`. All engine runs use
dkguard with headless software rendering. The first rejected target chain,
full-region failures and unsuccessful wheel-placement diagnostics are retained.
This is focused station assistance, not complete four-episode traversal acceptance.

## Sequence 569 — Greece pool, statue descent and the actual play checkout

The owner launches with `zig build play` in `~/sources/dk3`. Earlier sequence
568's water fix existed only in the separate performance checkout, so that
launch still used the old movement motor. The water correction and regression
coverage are now present in this canonical checkout as well. The upper ledge
probe tests the mover's collision mask; nonblocking detail/monster-only clips
above the Greece pool rim no longer suppress water jumps. Solids, player clips
and bodies still block them.

The e2m3b guardian also oscillated on its plinth while playing chase animation.
Two connected locomotion issues were exposed: its 48-unit descent exceeded the
default 32-unit support probe, and diagonal floor-to-floor clearance sweeps cut
through the plinth edge. The column class supplies a bounded 64-unit descent to
the shared mechanism. Direct routes probe from the last supported height and
test horizontal clearance before gravity handles the descent. Other classes
keep their default bound; unsupported cliffs and hazardous floors remain rejected.
No class branches were added to shared mechanisms, and no collision bypass,
teleport, damage, animation, save-schema or asset edit is part of the fix.

| Scenario | Result | Evidence / limits |
|---|---|---|
| Integrated native build/contracts | Passed | `pool-statue-569/build-final.log`: 114/114 steps, 411/411 tests plus C contracts; class ownership R1–R11 zero. |
| Water exit in this checkout | Passed | Both actual e2m3b pool side edges reach a dry bank; `canonical-pool-after-v3/` trajectories/captures. |
| Guardian leaves its plinth | Passed | From authored x=352,y=2784, it reaches y=2897.258, z=-247.795: about 113 horizontal units and the surrounding floor. It then attacks; player health 100→33 with damage source 501 (the guardian). |
| Descent safety | Passed | Default limit rejects the synthetic 48-unit descent, the class limit accepts it; 128-unit cliffs and lava/slime/nitro floors remain rejected. Existing locomotion and differential movement checks pass. |
| Canonical play preparation | Passed | Plain `zig build play-install` prepares a new native development generation without launching a window; the previous generation and owner saves are preserved. |
| Performance-checkout play setup | Passed | Its missing local converted-asset cache caused the reported launch failure. Local cache/artwork links now reuse the existing converted inputs; plain `zig build play-install test-runtime` passes 136/136 steps and 430/430 tests. Its GPU defaults remain 1. |

Evidence lives under `zig-out/reports/pool-statue-569/`; the performance checkout
also retains the first failed descent test, the intermediate statue-still-stuck
replay, repaired builds and probes under `perf-water-defaults-568/`. The useful
failed replay was retained and the diagonal sweep was corrected before final
acceptance. All engine checks use guarded headless software rendering and copied
saves. These scenarios place the player diagnostically above/near the actual
pool and let ordinary movement/gravity/combat proceed; they do not qualify a
full authored traversal. No desktop game is started by the agent.

## Sequence 568 — water-exit-contents and optimization defaults

The owner requested all implemented optimization paths enabled by default and
reported being unable to jump out of the Greece pool near a living statue after
a level transition. `r_vkGpuTexturePrep` and `r_vkGpuWorldDraws` now default to 1,
alongside `r_vkPreparedAssets=1`. Explicit archived settings still apply. Missing
prepared assets and unsupported/exhausted GPU preparation retain source/CPU
fallback. Prior sequence 567's opt-in defaults and timing results are historical;
they do not describe the new default configuration or prove hardware FPS gains.

The shared movement motor's upper ledge probe incorrectly required contents == 0.
The e2m3b pool beside `monster_column` has `CONTENTS_DETAIL|CONTENTS_MONSTERCLIP`
(`0x08020000`) above its bank, starting above z=-256. These contents do not block
the player's collision mask. The motor now tests that mask instead of rejecting
all nonzero contents; solid, player clip and body obstructions still reject a
water jump. Both authoritative and predicted movement use the same correction.
No gravity, jump height, water speed, map geometry or save schema changes.

| Scenario | Result | Evidence / limit |
|---|---|---|
| Connected build/contracts | Passed | `perf-water-defaults-568/build.log`: 134/134 steps, 429/429 runtime tests, C movement/image/collision contracts; ownership R1–R11 zero. |
| Upper-ledge contents regression | Passed | Actual motor with water/trigger/area contents permits ascent; solid, player clip and bodies retain rejection. Existing differential walk/swim/jump replays pass. |
| New defaults in real engine | Passed | Private profile omits all three optimization variables; console reports each as `1`, the default. Default GPU paths render/load under software Vulkan validation without errors. |
| Statue pool west edge | Passed | Frozen old build remains wet at x=15.125,z=-269.017; corrected build reaches dry bank x=-240.874,z=-231.875. |
| Statue pool east edge | Passed | Old build remains wet at x=688.875,z=-275.594; corrected build reaches dry bank x=944.874,z=-231.875. |

Evidence: `zig-out/reports/perf-water-defaults-568/`, frozen runtime/module hashes,
source hashes, trajectories, captures and `water-exit-results.json`. Engine runs
use `dkguard --headless`, no `--gpu`, private profiles and copied arrival save.
The decisive replay loads standalone e2m3b, places the player **above** each pool
edge through the existing diagnostic command, lets gravity settle, then uses
ordinary movement/jump commands. This qualifies the actual bank collision and
movement correction, not traversal from the saved arrival position. The first
unrelated/resident placements and the north placement overlapped geometry and
are retained as invalid setups, not passing water-exit scenarios. The owner had
not saved at the exact screenshot position; no exact saved-pose replay is claimed.
No owner installation, save, asset or desktop display is modified.

## Sequence 567 — perf-parallel-preparation — all six directions implemented

The owner authorized the complete larger-refactor plan: bounded concurrent loading,
GPU-ready assets, deferred world restoration, GPU texture preparation/uploads,
bulk ECS/save restoration and GPU visibility/index compaction/indirect drawing.
Implementation and qualification stay in the isolated performance checkout;
the canonical checkout, owner installation, original assets and owner saves remain
untouched. No commit, push, PR update or installation refresh is part of this pass.
See [architecture and usage](performance-pipeline.md). Evidence is local under
`zig-out/reports/perf-pipeline-567/`.

Gregg's scientific method, workload characterization, USE and measurement sanity
checks guide the experiments. This hybrid CPU has four faster physical cores and
eight slower cores; unpinned component runs split into timing bands. Those first
runs remain in the report, but component comparisons use the same four fast cores
and SMT siblings. Engine runs use private Xvfb through `dkguard --headless`, no
`--gpu`, dummy audio, private profiles and copied saves. Standalone physical-GPU
contracts create no window, SDL instance, surface or swapchain.

| Scenario | Result | Evidence and limits |
|---|---|---|
| Integrated build and aggregate | Passed | `final-build-and-contracts.log`: 173/173 steps, 571/571 native tests, 389 Python tests; Zig 0.16.0, pinned Python/dependencies. Class ownership R1–R11 remains zero. |
| New SHA qualification | Passed | Exact known vectors, every 0–256-byte tail at 32 alignments and concurrent callers against portable stdlib; separately targeted archive exports only `dk3_sha256_hardware`, contains SHA instructions and no compiler-rt overrides. Unsupported CPUs retain portable SHA; other physical CPU families were not exercised. |
| GPU compute output | Passed | `gpu-contracts-hardware-v2.log` and software evidence: 40 texture cases (including 4K, odd/thin sizes, color tables, separate/in-place output) and 14 world batches (1–256 surfaces, culling/no-cull), zero failures under validation. Kernel/test source hashes match final source. Physical device: RTX 5090 Laptop GPU; no hardware engine/FPS claim. |
| Owner-save restoration | Passed | Three newly copied saves and the immutable controlled crossing fixture; full UI/class validation, save/reload, preserved player/gameplay state and source history. Greece restores 3 worlds and retains 29 original cold snapshots; the smaller save retains 21. |
| Prepared assets, bad-cache fallback and cancellation | Passed | `qualification-final-prepared-fallback`: four loads, save/reload, B→C crossing, crossed save/reload and renderer restart during admission followed by successful re-request. 19 prepared-world and 2387 prepared-texture admissions; source/settings mismatch, payload CRC damage and a truncated world cache fall back to original assets. Zero failed images or Vulkan validation errors. |
| GPU paths without sidecars | Passed | `qualification-final-raw-gpu`: same four loads/crossing/restart; four deferred 4K GPU texture chains, ordinary synchronous GPU preparations and indirect world drawing; all four save handoffs hit, no failed images/validation errors. |
| Natural Greece exit retry | Passed | `qualification-natural-final`: ordinary movement from copied B save to authored party refusal; save with unlatched timed retry, reload, companion catch-up and automatic B→A transition while still at the exit; health/player retained and no bounce. This is a bounded exit scenario, not full-map/campaign traversal. |
| Deferred-world correctness | Passed with limit | Namespace/state/opaque-byte and malformed-input contracts, cold save preservation and current-region engine crossings. Full campaign travel across every cold-region boundary remains unverified. |
| Local prepared generation | Passed | 591 textures and 6 BSPs in four additive stored shards, 1,445,711,987 package bytes from the 434,474,981-byte fixture package. Exact integer mip/color and geometry/HDR contracts; deterministic overrides, bounded shards, installer hash/CRC/namespace rejection. More disk/I/O in exchange for avoided conversion. |
| Notice propagation | Passed | MIT stdlib notice retained in source/native prefix/development install/release bundle. Ten focused install tests and the release-contents test pass after the packaging-only update. |

Coherent accepted runtime: `runtime-accepted/`, twelve artifact hashes in
`runtime-accepted-identities.json`, 1204 compiled/tool source identities in
`source-accepted-identities.json`, compiler/std-sha2/rules identity in
`compiler-final.json`. Final rules are
`21f07514c020456a7afd77e32b709ccb5e6039be53562f780746294e1c4e5d8b`;
protocol 1351, durable snapshot schema 2, volatile prepared schema 4. Frozen v3
runtime, failed builds and first benchmark artifacts remain available separately.
`runtime-final/` preserves the version before the deferred small-skin repair.
Only `renderer_vulkan.so` and `src/renderer_vulkan/image.zig` differ. Its first
fresh-load block found that routing every small cached skin through the two
large-cache slots serialized cheap work across frames: B/A prepared readiness
5.233/5.991 s versus published 4.026/4.778 s. The failed experiment remains in
`final-loading-comparison.json`. Chains up to 2 MiB now retain the original
background PNG/inline admission path; large sidecars retain bounded async reads.
The affected build/contracts (`deferred-small-build.log`, 110/110 steps and ten
image tests) and four-load/restart/bad-cache replay
(`qualification-accepted-prepared-fallback`) pass. It records 18 prepared-world
and 2381 prepared-texture admissions, four save-cache hits and no validation errors.
Gameplay/module identities and rules match the aggregate-qualified runtime.

Three interleaved component trials use one warmup and five samples per process.
Values below are medians of those trial medians, B/A respectively:

| Work | Before → after | Interpretation |
|---|---|---|
| Complete source-validated save handoff wall | Two decodes 157.555/168.338 → prepared handoff 120.126/125.824 ms | 23.8%/25.3%; includes full UI decode, compact encoding/planning/exact allocation, two SHA checks, two byte copies, selected restore and source rebinding. Excludes renderer, dormant-store publication and asset admission. |
| Initial handoff regression repaired | 173.264/179.400 → 120.126/125.824 ms | Initial version lost to two decodes and excluded scratch allocation from its timer; not accepted as a gain. Final timing includes that allocation. |
| Handoff component peak RSS | Initial 131780/131280 → 69128/67864 KiB | About 47.5%/48.3% below the first handoff; the two-decode control is smaller at 45348/44384 KiB. Engine byte-cache reuse has a real memory cost. |
| Selected server reconstruction wall | 4.995/4.830 ms | Three current-region worlds; full UI validation/encoding is accounted above. Never present this isolated decoder speed as whole-load speed. |
| Full ordinary decode | Approximately unchanged | The initial 9.5 KiB/entity temporary regressed decode to 93–95 ms; direct final-column writes and compact wire work restore the published 76–78 ms band in the matched wire experiment. Final block has host variation; no universal full-decode speedup claim. |
| Canonical durable output | Exact | Every roundtrip sample has the original save's SHA-256; IDs, component data, residents and ordering survive. Roundtrip timing is mixed, no writer speedup claimed. |

Fresh settled-menu engine comparisons use three interleaved trials per arm/save,
one save per fresh process and a private initially empty Mesa cache. The OS page
cache is uncontrolled. Lavapipe has four threads; ordinary CPU affinity and host
pressure are recorded. Readiness includes normal input and zero deferred images,
not all future-region preparation. Results are medians, with the three-sample
range in brackets, B/A respectively (`accepted-loading-summary.json`):

| Workload | Published 563 | Accepted without sidecars | Accepted prepared packages |
|---|---|---|---|
| B ready, seconds | 4.129 [3.873–4.232] | 4.026 [3.927–4.130], −2.5% | 4.177 [4.125–4.931], +1.2% |
| A ready, seconds | 4.578 [4.277–4.729] | 4.528 [4.478–4.581], −1.1% | 4.129 [4.125–4.379], −9.8% |
| Process CPU, seconds B/A | 10.298/11.768 | 10.073/11.652 | 8.856/8.861, −14.0%/−24.7% |
| Peak RSS, KiB B/A | 1839960/1819644 | 1838300/1826972 | 1694472/1669400, −7.9%/−8.3% |

Prepared current-map loading improves A while B is approximately flat/slower; a
universal speedup or confidence/tail claim is unsupported. Without sidecars the
small wall gains are within observed run variation. These engine results include
validation/encoding, source/cache reads, rendering and completed image admission;
component timers cannot replace them. Prepared packages are an explicit local
installation option, with the disk-space tradeoff recorded above.

Real CPU mip preparation (`image-component-comparison.json`) covers 256², 512²
and 4096² PNGs, identity and nonidentity gamma/intensity, picmip/device limits,
and copied/borrowed/prepared paths: 27 arms, seven samples after one warmup.
Every pixel digest, dimension, mip/skip count, alpha and average matches. At 4096²
with identity tables, borrowed CPU preparation is 8.088 ms versus 0.032 ms for an
already validated prepared chain, with owned mip bytes 22369620 → 0. With gamma=2,
intensity=2, full resolution, copied/borrowed/prepared are 43.053/42.551/38.649 ms;
with picmip 1 they are 32.267/32.413/28.245 ms. Cache validation, PNG decode, reads
and GPU upload are outside these component timers; especially the identity-table
reuse is not a whole-load speedup.

No sum of independent speedups is meaningful.
GPU preparation and GPU drawing remain opt-in (`r_vkGpuTexturePrep=0`,
`r_vkGpuWorldDraws=0`) pending measured hardware-frame benefit. CPU parallel and
prepared-cache paths remain available by default, with source fallback.
Previously saved exits that were already latched by the old refusal bug still
require leaving and re-entering the brush: their saved latch is indistinguishable
from intentional arrival protection. New refusals and saves made while waiting
are repaired; no speculative durable-save rewrite is performed.

First failures retained: parameter shadow/missing dedicated link; UI identity
dependency across the pure-layer boundary; default test-runner identity fallback;
benchmark-only first directory setup; SHA inline-asm output syntax; notice-test
invocation missing `PYTHONPATH`. Each was repaired and its affected check passed.
The rejected bulk temporary and oversized scratch/hashing experiments are retained
in `source-before-wire/`, frozen binaries and paired reports. Inspected loaded
Greece and post-restart scenes retain textured geometry/HUD; JPEG inspection is
not exact frame equivalence or full artistic/campaign acceptance.

## Historical session handoff — optimization paused; retained through 563

The owner paused optimization and requested publication. The unfinished 566
serialization experiment only built a baseline harness; its temporary repack mode
has been restored out of production. No experiment is running. All fourteen
selected source and eleven runtime identities match qualified 563. Historical
entries below describe their state at the time, including requests to continue.

Changes since the previous publication at 503 retain the following matched gains.
Each row has its own preceding control: percentages are not additive, and there
is no same-environment start-to-final whole-branch comparison. B/A denote the
copied Greece e2m3b/e2m3a saves. Engine measurements use isolated software-only
headless runs; original installation/assets/saves stay unchanged.

| Retained change | Matched result | Scope and cost |
| --- | --- | --- |
| Earlier model prefetch, 506 | Resident B 4.128 → 3.981 s; A 4.585 → 4.283 s; first-model waits 194/206 → 0/0 ms in the separate standalone block | Complete loading; resident A peak RSS +21416 KiB, CPU mixed. Profiles differ between blocks and are not pooled. |
| Four model slots, 509 | Same binary, three/four slots: standalone B 2.826 → 2.766 s; A 3.276 → 3.124 s. Resident B 4.029 → 3.828 s; A 4.389 → 4.229 s | Resident B RSS +36036 KiB; standalone A CPU increases. Worst temporary bound 1248 → 1664 MiB. |
| Parallel package admission, 512 | Warm preparation 5.286 → 4.752 s; stored-PNG block 4.547 → 4.088 s (both 10.1%) | Identical generation; stored-PNG CPU +6.4%; bounded four readers. |
| Engine save CRC, 514 | Engine validation/staging 156 → 12 ms; B ready 4.135 → 3.927 s; A 4.688 → 4.636 s | All checks retained; A process CPU increases. |
| Portable native CRC, 516 | Actual payload CRC about 23.1 → 4.1 ms | Historical step, subsequently extended by 551; fresh A did not improve. |
| Surface admission cadence, 517v2 | Remaining renderer target 33.081 → 18.134 s (45.2%) | Target readiness, not complete region/gameplay readiness or FPS. |
| Cheap normal polls, 520 | Remaining target 19.127 → 11.824 s (38.2%) | Same 9903 surfaces/47 pages; peak RSS +24.2 MiB. |
| Prioritized lightmap batching, 526 | Remaining target 12.272 → 9.418 s (23.3%) | Fresh loads mixed; unchanged budgets and pages. |
| Eight HDR view reservations, 527 | Remaining target 9.319 → 8.095 s (13.1%) | Bounded earlier storage; fresh A consistently +36/+51/+53 ms. |
| Four-slot/4-MiB RGBA8 storage pool, 530 | Remaining target 8.264873 → 7.551208 s (8.6%) | Peak RSS median +8484 KiB; exact pixels/lifetimes verified. |
| Component-name dispatch, 538 | UI decode B 95.576 → 91.201 ms; A 94.243 → 91.231 ms | 4.6%/3.2% component gains; no whole-load claim. |
| One bounded low-CPU continuation, 542 | Remaining target 7.174411 → 6.273695 s (12.6%) | At most one extra step/eight total; frames/fresh loads mixed. |
| JSON field dispatch, 543 | UI decode −1.28%/−0.88%; server −1.55%/−1.92% | Eleven of twelve pairs faster; no causal whole-load claim. |
| Lowest-free-slot hint, 548 | UI decode −0.61%/−1.21% | Same slot/ID/failure ordering; one of six pairs slower. |
| Runtime-dispatched native CRC, 551 | UI decode 85.990 → 79.539 / 85.903 → 79.639 ms; canonical roundtrip 243.605 → 219.628 / 241.289 → 222.803 ms | UI 7.5%/7.3%, server 6.8%/7.1%; exact bytes, portable fallback and concurrent callers verified. |
| Reused scanner nesting storage, 560 | UI decode −4.34%/−4.55%; server −5.93%/−4.96%; decoder RSS about 2.6–3.0 MiB lower | Whole-load effect unresolved: four of six A pairs slower, median paired +79.9 ms; same-binary controls also vary. |
| Construction-only chunk reuse, 563 | Decoder RSS 58900 → 44500 / 59004 → 43264 KiB (24.45%/26.68%); retained chunks 1703 → 820, empty 883 → 0 | 13.85 MiB less retained chunk storage; server CPU −2.17%/−1.64%; UI B flat/A −2.55%; fresh/frame/roundtrip CPU mixed. |

Final qualified build: 90/90 steps. Latest aggregate: 59/59 steps, 560 native
tests plus C contracts and 384 Python tests in the recorded pinned environment.
Ownership R1–R11 remains zero. Actual original saves preserve all 32 worlds,
canonical bytes, active slots, masks, query/view order and epochs; malformed
errors match. Native UI/intro/E1/Greece saves and reloads, controlled B→C arrival
reload and cold cancellation/restart/re-request pass validation. All seventeen
latest normal logs are GPU-query-free; owner saves are hash-unchanged.

Rejected work stays out: weather empty-marker shortcut, extra image pumping,
material handoffs, larger/blind texture-pool policies, JSON scratch/writer reuse,
engine-to-native CRC bridge, eight CRC streams, nested/ordered/key-token JSON
specializations. Static inspection also falsified duplicate chunk initialization.
The separate 507 Greece companion catch-up fix remains isolated, not deployed or
included in this performance branch. Physical-GPU and full-campaign acceptance
remain unverified. Detailed individual costs, controls and failures follow.

## Sequence 566 — perf-save-field-initialization — paused before prototype

The owner stopped the loop after a baseline-only repack harness build (3/3).
Restore the temporary benchmark mode exactly to retained 563; no writer change
was implemented, timed, retained or published. Private design/baseline artifacts
remain under zig-out/reports/perf-save-field-initialization-566/ for a future
explicit resume.

## Sequence 565 — perf-save-writer-initialization — characterization complete

Actual retained 563 generic ReleaseSafe Writer.raw emits one full reservation
memset followed by separate name/data memcpy calls; source reservation size is
8+name+payload, so the payload clear survives before its overwrite. The bounded
record header/name also clears before copying. Integers has no standalone emitted
symbol; do not infer staging cost from source alone. No timing gain or source
change yet. Preserve full self-validation/CRC and allocator safety; consider
header-only initialization with an unchanged alias fallback. Evidence:
zig-out/reports/perf-save-writer-initialization-565/.

## Sequence 564 — perf-json-key-token — rejected; restored 563

Read complete Scanner object-key tokens directly through its public next API,
avoiding nextAllocMax's generic peek/list path. Partial tokens retain standard
continuation/ownership; other sources keep the stock API. No UTF8/grammar/value
validation bypass or borrowed-value change. Preserve stock complete borrowed-key
limit behavior, including its difference from allocated escaped keys. Six focused
contracts pass with standard-parser differential Unicode/surrogate/escape/error/
length cases and scratch-OOM/reuse. Freeze a private generic CPU candidate and
restore normal source before three interleaved pairs per original save. No
accepted gain. Evidence: zig-out/reports/perf-json-key-token-564/.

Private build passes 3/3. Initial arrival CPU 72.526267 → 72.910336 ms (+0.53%);
autosave 74.238915 → 72.647456 ms (−2.14%). A bounded counterbalanced confirmation
gives 73.171811 → 72.812262 ms (−0.49%) and 73.133283 → 72.692541 ms (−0.60%).
All six autosave pairs improve, but four of six arrival pairs are slower, with
paired increases including +2.133/+4.297 ms. Keep every sample. Reject the
inconsistent representative-input result without native rollout or layout tuning.
Normal fourteen source and eleven runtime identities match retained 563 before
both blocks; no duplicate broad suite for the discarded prototype.

## Sequence 563 — perf-save-chunk-reuse — retained memory gain

Private isolated-world construction may retain two empty tail chunks for reuse,
counted inside the physical chunk cap. Detach only the tail so active row/chunk
indices and archetype registration stay stable. Restore a consumed spare on
append OOM; finish frees spares before copying ownership into Loaded, and deinit
cleans failed construction. Default live-world retention stays unchanged. Select
from 562's 883 empty chunks/1703 total and zero row swaps in actual reconstruction.
Current 560 generic CPU baseline build passes 3/3. Nine focused core contracts
pass, including new cap/OOM/retry/lifecycle and values/slots/query-order/epoch
parity across large components, middle-row changes and handle reuse. Freeze the
candidate CPU build and restore both normal sources before interleaved real-save
measurements. Evidence:
zig-out/reports/perf-save-chunk-reuse-563/.

Both actual 32-world saves preserve exact active slots, masks, archetype/chunk
views, query order, epochs, next IDs and free-slot hints, with exact canonical
bytes. Final retained chunks fall 1703 → 820, empty chunks 883 → 0, saving
14523584 bytes (13.85 MiB) of retained chunk storage. Private diagnostic timings
are excluded. Matched generic UI decode process peak RSS falls 58900 → 44500 KiB
(24.45%) and 59004 → 43264 KiB (26.68%); minor faults fall roughly 3700–4100 per
process. Server RSS falls 58512 → 44192 and 59004 → 42712 KiB. These are decoder
component measurements, not whole-engine RSS reductions.

Three interleaved process pairs per save, seven measured decodes after warmup:
UI arrival CPU 76.715952 → 76.767675 ms (+0.067%, roughly flat), autosave
78.459080 → 76.459885 ms (2.55% better); five of six pairs improve. Server CPU
76.623317 → 74.963793 ms (2.17%) and 76.036471 → 74.789074 ms (1.64%), all six
pairs faster. Canonical roundtrip CPU is mixed (−0.31%/+0.83% arm medians),
with every measured output exact. Roundtrip RSS medians fall about 13.5/17.3 MiB.

Normal fresh-load timings are mixed: B medians 3.776819 → 3.783285 s, paired
+97/−45/−42 ms; A 4.334370 → 4.385222 s, paired +207/−154/−96 ms. Preserve all
samples; claim no overall load speedup. Unique model/PNG sets and player state
match; A duplicate PNG counts vary. Two dynamic frame pairs have means
21.733 → 22.864 and 23.114 → 22.044 ms, maxima 41 → 45 and 42 → 36 ms.
Unequal windows and two pairs do not establish FPS/tail changes. Renderer
allocated ELF sections remain exact 560; no physical-GPU performance claim.

Five original/produced saves canonically match all four baseline/candidate UI/
server readers; seven malformed cases return exact errors. Coherent UI intro/E1,
both Greece saves and in-place save/reload, controlled B→C with arrival reload,
and cold cancellation/vid_restart/re-request pass under validation. Controlled
nearby-party crossing does not qualify the separate natural catch-up fix 507.
Native build passes 90/90; one aggregate 59/59 steps, 560 native tests plus C
contracts and 384 pinned Python tests. Ownership R1–R11 stays zero. Seventeen
normal engine logs are GPU-query-free and contain no validation errors. All
fourteen source and eleven runtime files match frozen identities; all three
owner saves are hash-unchanged, and diff checks pass. Rules
`309d101604c95b94bcb205548b93eb91e6f67c94bd13812120b07745fbe66600` match 708
selected source files and all three modules; protocol 1351/schema unchanged.
Retain for demonstrated memory gains and continue the active optimization loop.

## Sequence 562 — perf-ecs-storage-work — characterization complete

Private generic ReleaseSafe counters observe both actual 32-world saves: 1703
chunks allocated/destroyed, 28010944 bytes, with 883 empty chunks remaining after
reconstruction. Final rows/entities/worlds match identity (14168/14174 entities).
All 61890/61910 component puts relocate; no row swaps occur. Archetype requests
scan 903717/904991 entries; row reservations scan 79980/80006 chunks, maximum
twelve per archetype. Logical existing-component copies total about 5.91 MB and
new undefined-column writes 5.86 MB; these are logical sizes, not bus traffic.
Select bounded reconstruction-only empty-chunk reuse before tuning searches.
Freeze the diagnostic then restore both normal sources; all fourteen source and
eleven runtime identities match retained 560 before samples. First diagnostic
loop-syntax failure is preserved; repaired build passes 3/3. Instrumented timings
are excluded, no normal source change or duplicate aggregate. Evidence:
zig-out/reports/perf-ecs-storage-work-562/.

## Sequence 561 — perf-ecs-chunk-initialization — hypothesis rejected

Inspect actual 551 and retained 560 generic ReleaseSafe reserveRow disassembly,
using 559's captured allocation call stack. Both emit one 16448-byte 0xAA fill
then the count=1 store. The compiler already removes the suspected duplicate
whole-chunk initialization. Other fills initialize/free pointer-array buffers;
they are separate allocations. No source change, prototype, performance claim
or duplicate suite. Evidence: zig-out/reports/perf-ecs-chunk-initialization-561/.

## Sequence 560 — perf-json-scanner-reuse — retained component gain

Retain one scanner nesting allocation across a decodeWorld's component payloads.
Reset every scanner state between complete inputs, retaining only nesting
capacity; owned values stay on the existing strings arena. Parser lifetime ends
on success or failure, with recursive worlds owning independent parsers. This
differs from rejected 540's per-call local fallback buffer. Predict less repeated
allocation/free/poison work observed by 559. Freeze private CPU candidate and
restore both normal sources before interleaved original-save measurements;
expand qualification only if useful. No disabled safety or depth bound.
Evidence: zig-out/reports/perf-json-scanner-reuse-560/.

Three interleaved process pairs per original save, seven measured samples after
warmup, improve actual UI decode median CPU 79.336367 → 75.890019 ms for arrival
(4.34%) and 80.249599 → 76.598040 ms for autosave (4.55%). Server-root decoding
improves 80.970692 → 76.168607 ms (5.93%) and 86.608256 → 82.312655 ms (4.96%).
All twelve decode pairs improve. Isolated decoder peak RSS medians fall about
2.6–3.0 MiB; this is not a whole-engine memory claim. Canonical decode/encode/SHA/
deinit CPU improves 1.47%/1.70%, all six pairs faster and every measured output's
bytes/hash exact. Roundtrip peak RSS is mixed; do not generalize the memory gain.

Owned-value/input replacement, repeated reuse without further nesting allocation,
reordered/escaped/duplicate/unknown/malformed fields, recovery after errors,
allocation failure and 1200-level nesting growth pass. Two original plus three
native-produced saves canonically match through baseline/candidate UI/server
readers; all seven malformed cases produce exact errors. Three final native saves
also canonically match all four readers. Final coherent UI intro/E1, both Greece
saves and in-place saves/reloads, controlled B→C with arrival reload, and cold
admission cancellation/vid_restart/re-request pass under validation. Controlled
nearby-party crossing does not qualify the separate 507 natural catch-up fix.

Whole-load effect remains unresolved. Original arrival ready median is 3.777351 →
3.724608 s (paired −251/−53/+0.4 ms). Original autosave is 4.232968 → 4.378216 s,
all three slower (+50/+194/+146 ms); counterbalanced confirmation yields
−149/+110/−197 ms. Across all six A pairs, four are slower and the median paired
cost is +79.9 ms. Identical-binary baseline controls yield +8.5/−3.9/−99.7 ms,
showing appreciable variation, not proving the candidate cost absent. Retain for
demonstrated component gains with this explicit unresolved end-to-end limit;
claim no whole-load speedup. Unique model/PNG work and player state match; A PNG
duplicate counts vary. All original, confirmation and control samples are kept.

Two dynamic frame pairs have means 22.1825 → 22.2133 and 22.1818 → 22.2612 ms;
maxima 40 → 40 and 36 → 35 ms. Unequal task windows and two pairs cannot establish
FPS/tail changes. Renderer allocated ELF sections remain exact 551; file metadata
differs. Normal thirty engine logs are GPU-query-free and contain no validation
errors. No physical-GPU performance claim.

Final native build passes 90/90; aggregate retry passes 59/59 steps, 558 native
tests plus C contracts and 384 pinned-environment Python tests. First aggregate's
functional tests all pass but its formatting gate fails; preserve that attempt.
Repair is whitespace-only in a test fixture; rebuild/replay qualify final rules
`a43f99eec6c41edcc75d88335e00a007a849a750c1e63df5c580649a23a46ac3`, verified
against 708 selected source files and all three native modules. Ownership R1–R11
remains zero. All fourteen final source and eleven runtime identities match;
temporary benchmark/profiling modules are absent and all three owner saves are
unchanged. Protocol 1351 and portable schema remain unchanged. Active loop continues.

## Sequence 559 — perf-save-decode-stacks — characterization complete

Twenty-four bounded GDB owner snapshots of retained 551's actual UI decoder all
succeed. All 300 interrupted decode iterations finish with exact input hash and
32-world identity. Repeated scanner token/peek/whitespace paths occur for Body,
MapObject, Actor, Pose and Binding. Other observations include ECS chunk allocation
poison filling, scanner nesting-stack free/poison and push/capacity, numeric
conversion and validation. Sparse stacks do not establish profile percentages;
optimized locals can be unavailable. Interrupted timings are diagnostic only.
No production change. Evidence: zig-out/reports/perf-save-decode-stacks-559/.

## Sequence 558 — perf-json-ordered-field-hint — rejected; restored 551

Check the next declaration's field name before retained static lookup. A matching
ordered field bypasses the general lookup; reordered/omitted fields fall back,
with existing unknown/duplicate/default/ownership/scanner handling. No nested
parser change. Predict lower actual save decode CPU. Freeze generic ReleaseSafe
private CPU executable and restore normal source before three interleaved process
pairs per original save. Expand qualification only for useful component benefit.
Evidence: zig-out/reports/perf-json-ordered-field-hint-558/.

Private build 3/3 passes. Arrival median decode CPU 79.529291 → 80.003851 ms
(+0.597%); autosave 79.461494 → 80.317296 ms (+1.077%). All six paired
processes are slower, with paired increases 0.437–2.865 ms. Preserve all twelve
processes, seven measured decodes each, exact input digest/world identities.
Reject; no canonical/native acceptance or extra broad suite for the discarded
prototype. Normal fourteen source and eleven runtime identities remain 551.

## Sequence 557 — perf-json-nested-dispatch — rejected; restored 551

Extend retained top-level static JSON field dispatch to directly nested plain
nonempty structs, keeping tuples, custom parsers, arrays and optionals on stock
parsing. Typed JSON remains the measured decode CPU limiter. Predict a component
gain for nested actor state with the same ownership/default/error contracts.
Freeze a private generic-x86_64 ReleaseSafe CPU executable and restore normal
source before three interleaved process pairs per original save. No engine or
normal runtime change at this stage. Evidence:
zig-out/reports/perf-json-nested-dispatch-557/.

Private CPU build passes 3/3. UI arrival median CPU 80.170824 → 80.477689 ms
(+0.383%); autosave 80.847270 → 81.172659 ms (+0.402%). Five of six paired
processes are slower; retain all samples. Each completes seven measured decodes
after warmup with exact input digest and 32-world identity. No useful component
gain: reject without expanded engine/canonical qualification or broad suite.
All fourteen normal sources and eleven runtime files remain exact 551.

## Sequence 556 — perf-view-driver-stacks — characterization complete

Four bounded batch GDB attachments during the actual copied-save e2m3b/background
e2m4a workload all succeed. Two owner snapshots show libc syscall → driver
futex_wait → lvp_CreateImageView, respectively HDR 128²/one mip lightmap storage
and RGBA8 256²/nine mip surface storage. Concurrent software-renderer workers are
inside shade_quads/JIT shader code. The other snapshots show normal server input
and scene shadow preparation. This establishes blocking inside the driver in
those observations; sparse snapshots do not quantify its frequency or prove
which driver's synchronization condition is being waited on. Preserve all worker
stacks and driver identities. Completed target readiness, pending zero, no
validation errors; all timings include debugger interruption and are diagnostic.
No production change. Evidence: zig-out/reports/perf-view-driver-stacks-556/.

## Sequence 555 — perf-view-resource-waits — characterization complete

Recharacterize normal-admission 2D image-view wall/owner CPU by required/reserved
resource, actual format/extent/mips/usage/aspect, world and admission phase. Reuse
531's phase/API instrumentation on byte-identical renderer source, adding bounded
512-group counts and >=1/10 ms events. Check group/API/phase/window accounting,
no dropped groups, exact completed work and player state. Freeze the private build
and restore normal 551 sources/all eleven runtime files, including dedicated,
before off/on/off headless validation samples. No shader/storage change, GPU query
or normal timing claim. Evidence: zig-out/reports/perf-view-resource-waits-555/.

All three off/on/off samples pass accounting, zero overflow/failures, complete
9903-face/47-page target readiness, pending zero, and unchanged player identity,
health, armor and ammo. Normal 2D image views take 1.62/1.75/1.66 s wall but
1.77/8.57/1.86 ms owner CPU. RGBA8 surface views account for 1.26/1.35/1.23 s;
HDR lightmap views account for 0.363/0.402/0.432 s. The 127 finalization RGBA8
views collectively take only 0.120/0.486/0.105 ms. Optional reserves remain cheap,
10.6–13.0 ms total across 52–53 views. Counts cover profiled normal admission,
not earlier initialization or other view types. Runnable-delay counters remain
unavailable. API elapsed time alone does not identify a driver lock or GPU wait.
All fourteen normal source identities and eleven runtime files remain exact 551;
private profiling module absent. No production change or duplicate broad suite.

## Sequence 554 — perf-crc-eight-streams — rejected; restored 551

Test eight independent 128-bit folding streams versus retained 551's four,
using the same reviewed polynomial/reduction, CPU gate and portable/tail paths.
Some upstream targets need more streams for latency hiding; benefit on this CPU
is unproven. Compare exact vectors and actual save payloads at their real +24
unaligned buffer offset, freezing the prototype and restoring normal 551 before
timing. Only proceed to complete decode/native qualification for a useful gain;
otherwise restore and choose a separate limiter. Evidence:
zig-out/reports/perf-crc-eight-streams-554/.

All 33,220 vectors pass, but actual save CRC remains about 0.75 ms with either
implementation; paired variation is only microseconds, with no useful gain. Reject
and retain the four-stream implementation. The initial expanded compilation exceeds
the 5,000-branch comptime-formatting quota; selecting the three literal assembly
immediates fixes compilation without a runtime/ISA change. Preserve both the failure
and prototype, but retain no unrelated formatting change. Normal 551 source/runtime
hashes match before and after timing; its aggregate remains valid. Move to renderer
image-view resource-class/wait characterization instead of further CRC tuning.

## Sequence 553 — perf-engine-save-checksum — rejected; restored 551

Route the engine save-format checksum through a small ioquake3 ABI/export root
and shared static library using the retained native Zig CRC. Client/server and
the independent C compatibility contracts link the same implementation. Keep
streaming ZIP, protocol, saved bytes and all validation unchanged, with assertions
enabled. Build the connected ABI/C/build batch before native scenarios, compare
actual production C validation and binary/resource costs, then fresh/frame guards
and one aggregate before retention. Evidence:
zig-out/reports/perf-engine-save-checksum-553/.

Actual production ABI C validation improves about 60%, but A fresh-load guards
are +97/+156/+196 ms. Three justified targeted follow-ups give -0.027/+297/+9.8 ms:
five of six are slower, one effectively equal; median paired cost is +126.6 ms,
arm medians 4.32798→4.43034 s. This outweighs the ~1.2 ms validation component
gain; reject without assigning an unproven layout/scheduling cause. B improves
or stays equal; frame means are mixed (22.609→21.910 and 21.954→23.170 ms), with
no FPS/tail claim. Preserve every sample. A separate ABI library initially adds
~0.8 MB of allocated code/data; composing exports with the existing native ABI
reduces this to +17,328 allocated file bytes/-944 zero bytes and retains all 59
network exports in both products. That resource iteration is recorded but rejected
with the integration.

Candidate native scenarios, C bitwise/unaligned/empty/corrupt/truncated contracts
and one aggregate 61/61 steps, 556 native/C plus 384 Python tests pass. Three
produced saves canonically match input through retained 551 UI/server readers.
All 22 normal logs are query-free and original owner saves are unchanged. Restore
the original network root/C/build sources, remove prototype ABI files, and rebuild
the normal prefix from cache: 90/90 passes, all fourteen tracked sources/ten frozen
runtime files match 551 exactly, and the dedicated engine is also restored/frozen.
No duplicate broad suite for unchanged restored code; 551 acceptance remains valid.
Next test eight-stream CRC privately before any further production change.

## Sequence 552 — perf-engine-save-crc — component probe complete

Compile unchanged actual C save-format validation with bundled zlib versus a
private macro-selected native Zig checksum shim, identical generic compiler/FFI
and preloaded inputs. Three interleaved batches/input, seven groups of eight calls
after warmup, reduce C validation CPU B 2.120328→0.928967 ms (-56.2%) and A
2.101091→0.899575 ms (-57.2%); all six pairs improve. Same actual record/field
counts, original bytes and corruption/truncation errors. Existing independent
bitwise CRC contracts pass 256 payload/alignment plus empty-stream cases against
the candidate. Preserve the initial NDEBUG compilation refusal; all C units were
rebuilt with assertions explicitly enabled before successful comparison. Internal
symbol binding prevents system-zlib interposition. This is engine flat-stream
validation, not nested class/JSON admission or whole-load acceptance. Production
551 remains unchanged during probes. Next integrate/qualify the actual engine ABI.
Evidence: zig-out/reports/perf-engine-save-crc-552/.

## Sequence 551 — perf-save-crc-folding — retained

Integrate the 550-qualified native Zig CRC prototype for actual UI/shared and
server-class-hook save decode comparisons against retained 548. Keep checksums,
numeric bounds, owned values, protocol/schema and malformed rejection unchanged.
Extend portable/accelerated equivalence and concurrent-caller contracts; qualify
unsupported-target/forced-portable paths, coherent native saves/transitions and
fresh/frame guards before one aggregate acceptance. No speedup beyond the isolated
550 checksum result was accepted before qualification. Evidence:
zig-out/reports/perf-save-crc-folding-551/.

All twelve paired decode processes improve: UI/shared B 85.990426→79.538716 ms
(-7.50%), A 85.903010→79.639111 (-7.29%); server B 87.092334→81.155975 (-6.82%),
A 86.609659→80.467529 (-7.09%). Three process pairs/input/root, seven samples after
warmup. Canonical roundtrip CPU, including decode/encode/SHA/deinit, falls B
243.604510→219.628458 ms (-9.84%), A 241.288922→222.803443 (-7.66%), all six pairs
faster and every output byte-identical to input. No isolated encoding claim.

Both original 32-world and three native-produced saves roundtrip byte for byte
through old/new UI/server readers. Seven malformed cases retain errors, including
invalid root CRC and invalid child CRC inside a repaired parent stream. Actual
new-native UI, both Greece restores/reloads, controlled crossing/arrival reload,
cancellation/restart/re-request pass validation. Forced fallback passes 33,218
vectors and AArch64 compilation; no AArch64 execution claim. ReleaseSafe contracts
cover portable equivalence and four concurrent callers. Actual CRC disassembly
contains legacy PCLMUL without AVX/VEX/EVEX mnemonics.

Fresh B pairs -95/+511/+52 ms and A +42/-557/+202 ms are mixed: no established
whole-load gain. Same unique PNG/model sets; A duplicate events vary. Frame mean
pairs 22.007→21.924 and 22.052→21.867 ms, maxima 41→36 and 36→41 ms, are dynamic
unequal windows, not FPS/tail evidence. Renderer bytes match retained 548. Build
90/90 and one aggregate 59/59 steps, 556 native/C and 384 Python tests pass with
pinned environment; R1–R11 stays zero. The 708-source rules hash, all three native
modules, fourteen tracked sources/ten runtime files, sixteen query-free measurement
logs, original owner saves and retained MIT notices pass audits. No new hash-time
allocation or system dependency. Software-only scope and separate 507 retry-fix
status remain. Next measure the remaining engine save-format CRC path.

## Sequence 550 — perf-bundled-crc-review — complete; native accepted by 551

Recover the original pinned 465 archive after web-cache/DNS failures; verify its
existing SHA/size and reviewed CRC/template/multiplier files against the archive.
Review IEEE polynomial, 128-bit folding, Barrett reduction, input bounds and CPU
dispatch. Prototype the mechanism in Zig with full upstream MIT notice, four
independent 128-bit streams, bounded loads and the existing scalar tail. Runtime
CPUID is atomically cached; legacy SSE/PCLMUL requires no AVX state. Unsupported
targets and short inputs retain slice-16. No C files or system dependency are added.

All 33,220 vectors match portable, installed-system and independent zlib CRCs.
Three interleaved batches/input reduce actual payload CRC CPU about 4.1→0.75 ms
(~82%). This is isolated component evidence, not native load acceptance. Freeze
the prototype library/source and restore normal 548 source/all ten runtime files
before sampling. Next 551 measures full actual UI/server decode and qualifies
fallback/portability/native scenarios. Evidence:
zig-out/reports/perf-bundled-crc-review-550/.

## Sequence 549 — perf-native-crc-dispatch — characterization complete

Compare a generic x86-64 ReleaseSafe export of the actual portable slice-16 CRC
with installed libdeflate 1.26 through the same ctypes signature and preloaded
actual save payloads. All 33,220 vectors (known/empty, 32 alignments, short tails,
large boundaries and two actual save CRCs) match independent zlib and input guards
remain unchanged. Three interleaved batches/input, seven measured groups of eight
calls after warmup, reduce B CRC CPU 4.101937→0.232661 ms and A 4.089402→0.240687 ms
(about 94%, 17–18x). This is a CRC component probe, not native load acceptance or
a whole-load percentage. The admitted decoder subset deliberately excludes CRC;
no system-library dependency or production CRC change is introduced. All retained
548 source/runtime files remain exact. Next review the pinned upstream CRC subset
and test a standalone bundled build before integration. Evidence:
zig-out/reports/perf-native-crc-dispatch-549/.

## Sequence 548 — perf-ecs-free-slot-hint — retained

Following 539's measured entity-creation CPU, replace repeated slot-zero prefix
scans with a conservative lowest-free-slot hint. Advance only after successful
creation and lower on valid destruction. Preserve lowest-slot ordering, retired
generation-zero checks, clone allocation, persistent identities and failure behavior.
No allocation or format change. Benchmark actual save decode and canonical output
before native acceptance. Evidence: zig-out/reports/perf-ecs-free-slot-hint-548/.

UI/shared actual save decode CPU falls B 86.936630→86.404638 ms (-0.61%) and A
86.735115→85.684995 ms (-1.21%), three interleaved process pairs/save and seven
samples after warmup. Five pairs improve; one B pair is +0.512 ms. Two original
32-world and three native-produced saves canonically match input through both
readers; five malformed checkpoints retain errors. Real coherent native UI,
both Greece restores/reloads, controlled crossing/arrival reload and cancellation/
restart/re-request pass validation. Full-pool/lowest-slot, stale/retired-generation
and failed-creation regressions pass. Fresh medians B 3.924718→3.824467 s and A
4.429772→4.332268 s exceed the measured decoder gain: no causal whole-load claim.
Same unique PNG/model sets; A duplicate events vary. Frame means 21.970→22.044 and
22.245→21.926 ms, maxima 42→36 and 43→44 ms, establish no FPS/tail improvement.

Native build 90/90 and one aggregate 59/59 steps, 555 native/C plus 384 Python
tests pass; R1–R11 remains zero. Rules from 707 sources, all three native modules,
twelve tracked sources/ten runtime files, sixteen query-free normal measurement
logs and original owner saves pass audits. One usize hint per world; no allocation
or serialized-format addition. Retain prior 542/543 gains without compounding;
software-only scope and separate 507 natural companion-retry status remain.

## Sequence 547 — perf-save-serializer-codegen — characterization complete

Inspect frozen 546 baseline/candidate symbol sizes and capture disassembly. Reuse
reduces capture text from 95,508 to 87,255 bytes and static indirect call sites
from 74 to 15; generic serializer write-function size multisets match. These are
static counts, not executed calls or cost attribution, and do not explain 546's
measured regression. Keep both allocation prototypes rejected and target a separate
measured limiter. No production changes. Evidence:
zig-out/reports/perf-save-serializer-codegen-547/.

## Sequence 546 — perf-save-json-reuse — rejected; restored 543

Use one standard allocating JSON writer per capture, clear its length before each
value, serialize with the unchanged options/bounds and synchronously copy bytes
into the existing portable save writer. Release capacity on every capture exit;
no global cache or borrowed save data. This targets 545's measured allocation and
shrink churn. Compare matched canonical roundtrip CPU and exact bytes first; normal
543 sources/runtime will be restored while frozen CPU binaries are measured.
Evidence: zig-out/reports/perf-save-json-reuse-546/.

All six paired processes are slower: B median canonical roundtrip CPU
243.746440→247.502337 ms (+1.54%), A 245.772511→249.100663 ms (+1.35%). Preserve
one A process's +76.7 ms outlier; the other five pairs are also slower. Every
measured canonical result remains byte-identical to input. Allocation counts alone
did not predict endpoint CPU benefit; inspect code generation before assigning a
cause. Normal sources/all ten runtime files match retained 543 before and after
frozen measurements. No broad suite for discarded code; 543 acceptance stays valid.

## Sequence 545 — perf-save-encode-allocations — characterization complete

Use a private transparent allocator wrapper around actual JSON serialization to
count allocations, resizes, remaps and frees, output bytes and bounded size buckets
per registry field. Reset for each canonical benchmark sample; account for observer
overhead separately and verify exact save bytes. Freeze this diagnostic and restore
retained 543 source/runtime before sampling. This determines whether reusing one
allocating JSON writer per capture is justified after 544's negative result.
Evidence: zig-out/reports/perf-save-encode-allocations-545/.

B/A captures perform 61,922/61,942 temporary output allocations, 98,344/98,313
successful remaps and matching allocation/free counts, for 13,445,905/13,435,245
JSON bytes. About 97% of outputs are at most 512 bytes. Sizes sum to calls; these
are the final measured roundtrip's counts after resetting each loop, excluding
warmup. Three measured canonical samples per input/arm match original bytes.
Reference/diagnostic CPU differs -1.7%/+0.27% in one process pair per input: this
is observer-sensitive characterization, not an optimization or overhead bound.
Normal source/all ten runtime files match 543. Next test one reusable standard
allocating JSON writer per capture, retaining validation, ownership and output.

## Sequence 544 — perf-save-json-scratch — rejected; restored 543

Test 512-byte local scratch with the original allocator as fallback for temporary
JSON serialization output, then copy into the existing portable save writer before
the local buffer expires. Large outputs retain heap allocation; owned decoded values
and all serialization/bounds checks stay unchanged. This targets save-encoding
buffers, distinct from 540's rejected parser nesting scratch. Compare actual canonical
roundtrip CPU and exact output on both original 32-world saves before native acceptance.
Evidence: zig-out/reports/perf-save-json-scratch-544/.

All six process pairs are slower. Canonical roundtrip median CPU changes B
244.132386→252.103905 ms (+3.27%) and A 243.960897→251.621926 ms (+3.14%).
Every measured sample retains input-identical canonical bytes, but there is no
useful gain. Preserve all samples and resource observations; do not assign the
cost to one allocator/copy/layout cause without evidence. Normal sources and all
ten runtime files match retained 543 before and after frozen CPU measurements.
No extra broad suite for discarded code; 543's acceptance remains valid. Next
characterize actual serialization allocations/output sizes before another change.

## Sequence 543 — perf-json-field-dispatch — retained

Following 539's JSON CPU profile, test generic static lookup of plain top-level
struct field names before typed dispatch to the unchanged standard nested parser.
Keep owned values, scanner limits, defaults, unknown/duplicate-field errors and
snapshot numeric/region checks. Custom JSON types, tuples and nonstruct values
retain the standard parser. Portable UI/shared and actual server-class-hook
benchmark roots match their frozen baselines. Evidence:
zig-out/reports/perf-json-field-dispatch-543/.

Three interleaved process pairs/save/root, seven samples after warmup, reduce
UI/shared decode CPU by 1.28% (B) and 0.88% (A), actual server by 1.55% and 1.92%.
Eleven of twelve process pairs improve; one server-B pair is 0.451 ms slower.
Both original 32-world saves and three native-produced saves canonically match
their input bytes through old/new UI/server readers; five malformed checkpoints
retain exact errors. Differential standard-parser and ownership/limit tests pass.
Real new-native UI, both saves/reloads, controlled crossing/arrival reload and
cancellation/restart/re-request pass under validation. All six fresh-load pairs
are faster, with medians B 4.025772→3.775018 s and A 4.489322→4.381080 s, but these
changes exceed the measured 1–2 ms decoder gain and include a large baseline
outlier: no causal whole-load claim. Unique PNG/model sets match; A duplicate PNG
events vary. Frame mean pairs 21.886→22.530 and 22.311→22.451 ms, maxima 43→40
and 64→37 ms, are dynamic unequal windows, with no frame/FPS/tail claim. Renderer
bytes are unchanged and all client allocated code/data differ solely in the actual
compatibility identifier; server/UI code size decreases.

Build 90/90 and one aggregate 59/59 steps, 553 native/C and 384 Python tests pass
with pinned environment recorded; ownership R1–R11 is zero. The 707-file rules
hash, all three native module identities, eleven tracked source/ten runtime hashes,
sixteen query-free normal measurement logs and three unchanged owner saves pass.
Software rendering only. Retain 542's scheduler and the separate status of 507's
natural companion-retry fix. Next measure save-encoding temporary allocation.

## Sequence 542 — perf-low-cpu-admission-continuation — retained

Test one extra normal admission step after a first-step wall-limit exit whose
owner-thread CPU consumption is below 500 us. Preserve the eight-step cap and
held-loading policy. Require CPU clock resolution at most 31.25 us; unavailable
or coarse clocks retain the existing wall policy. Only the client module changes;
rules and all other frozen runtime files match retained 538. The full build passes
90/90 after correcting and preserving a shadowed-capture compilation failure.
Candidate acceptance requires actual headless save/reload, crossing, cancellation
and paired background measurements, with foreground and fresh-load guards if useful.
Evidence:
zig-out/reports/perf-low-cpu-admission-continuation-542/.

Three query-free interleaved pairs reduce completed background world preparation
from median 7.174411 to 6.273695 seconds (-12.6%); all three pairs improve, with
the same 9,903 faces/47 pages and stable player state. Background process CPU,
including continued rendering/simulation, falls from median 81.73 to 70.98 seconds;
complete-process peak RSS changes by -9,296 KiB. Fresh B loads have paired changes
-146/+103/+55 ms and A +97/+202/-54 ms: no established fresh-load gain. Same unique
PNG/model sets; one A run has an extra duplicate PNG event. Four frame-processing
pairs have mean changes +1.072/-0.046/+0.385/-0.405 ms and maxima 36→34/40→42/
36→40/45→43 ms. Mixed dynamic windows establish neither a consistent regression
nor FPS/tail guarantees; the extra two pairs resolve the original mixed result
without discarding samples.

Real coherent-native UI, both Greece restores and private save/reloads, controlled
B→C crossing/arrival reload, PNG cancellation and restart/re-request pass validation.
All three produced saves canonically roundtrip byte for byte. Private diagnostics
observe 26 grants, at most one per frame and eight normal steps, all below 500 us;
coarse/unavailable resolution injections grant none. Diagnostic hooks are absent
from restored normal source/runtime. One aggregate passes 59/59 steps, 551 native/C
and 384 Python tests; ownership R1–R11 stays zero. All ten tracked sources and ten
runtime files match frozen 542, all 26 normal measurement logs are query-free, and
the three original owner saves are unchanged. Software rendering only; the natural
companion-retry fix remains separate. Continue with measured JSON parsing costs.

## Sequence 541 — perf-native-admission-budget — characterization complete

Recharacterize current 538 normal admission after retained renderer batching.
Measure per-frame/per-step owner thread CPU and monotonic wall, eight-step versus
one-ms time/idle exits, step histograms, and CPU work at wall-limit exits. Leave
the scheduling policy unchanged. Use a private subcommand on the existing world
diagnostic; client presentation-only instrumentation preserves the actual rules
identity without overrides. Freeze artifacts and restore normal source/all ten
runtime files before off/on/off headless samples, hiding notifications with GPU
queries disabled. Millisecond wall-clock quantization and timer overhead matter;
do not blindly replace this with a precise one-ms CPU quota or attribute all
wall-minus-CPU to a specific lock. Evidence:
zig-out/reports/perf-native-admission-budget-541/.

All three off/on/off samples complete 9,903 surfaces/47 pages with no pending or
failed images, stable player fields and no GPU queries. Time exits account for
93.3/96.9/94.5% of normal passes. Among those exits, owner CPU is below one ms in
53.6/52.9/51.6%, and below 500 us in 27.3/14.2/21.1%. First-step time exits number
181/192/170. Total admission wall is 2.328/2.620/2.370 seconds versus CPU
0.478/0.564/0.480. This supports testing one bounded continuation after a first
low-CPU wall-limit exit, not replacing the entire quota or assuming every pause
is one named lock. A controller result-key typo occurred after the first engine
finished successfully; preserve it and recover that sample without rerunning it.
All normal 538 source/runtime files are restored exactly. Next compare actual
endpoints/frame/fresh/cancellation for a single-extra-step prototype, with a
qualified CPU clock and the existing wall policy where that clock is unsuitable.

## Sequence 540 — perf-json-scanner-scratch — rejected; restored 538

Use 64 bytes of local scratch for JSON scanner nesting with the original allocator
as fallback; parsed values keep their existing caller allocator and ownership.
Use the same standard parser/options, with no depth cap, format change or skipped
validation. The scanner documents its allocator as nesting-only. Prediction: avoid
repeated transient arena allocations across 62,000 JSON values and reduce CPU or
memory. Compare full uninstrumented UI/shared and server-hook decoders against
538; do not infer a speedup from the 539 profile. If promising, verify scratch
lifetime and deep fallback plus canonical/error/native acceptance before retaining.
Evidence: zig-out/reports/perf-json-scanner-scratch-540/.

Both UI/server prototypes build 3/3 and complete all 24 processes with matching
input hashes/world counts. However, 11 of 12 process pairs are slower. UI CPU
medians B 86.970 to 89.832 ms, A 88.652 to 89.640; server B 88.824 to 88.995,
A 89.521 to 90.138. UI paired changes are +2.655/+2.761/+4.572 ms and
+2.944/+0.988/+4.829; server B +0.114/+0.171/+0.239, A -16.034/+0.588/+1.682.
The negative server delta includes a baseline outlier, preserved. Peak RSS has
no consistent benefit. Remove the prototype helper and restore all normal 538
source/runtime identities and benchmark exactly. Additional acceptance suites
are unnecessary for the discarded change. Return to the larger measured
background admission waits and characterize current scheduler CPU versus wall
budget exits before changing them.

## Sequence 539 — perf-save-phase-costs — characterization complete

Separate UI/shared validation from the real server saved_classes hooks. Freeze
unprofiled UI/server and instrumented UI/server CPU benchmarks of the actual 538
decoder. Measure checksum/header, typed JSON, bounds, entity creation, ECS put,
region validation and deinit; keep per-component counts/bytes/costs and calibrate
empty MONOTONIC clock pairs. Check disjoint accounting against whole decode wall
and process CPU. Restore all ten normal 538 source and runtime identities before
sampling; no engine or private game-module run is needed. Observer overhead and
code placement are diagnostics, not normal speedups. Evidence:
zig-out/reports/perf-save-phase-costs-539/.

All counts and disjoint phase accounting pass; both private roles round-trip both
32-world inputs to original bytes. UI reference 87.46/89.10 ms versus profile
93.91/93.99; server reference 88.74/89.14 versus profile 96.42/95.56, about 5–9%
observer overhead. Clock pairs have 10-ns minimum and 16–21-ns mean. JSON totals
62–64 ms, including about 21 ms for map_object (13,939 calls/4.23 MB) and 16–17 ms
for actor state (604 calls/3.97 MB). Nested CRC is 8.1–8.2 ms, ECS put 8.4–8.6,
creation about 2, validation 4.1 UI/4.9 server, bounds about 2.5 including clock
floor, deinit about 0.9. These are diagnostic wall costs, not deployed gains.
Normal 538 source, runtime and benchmark binary remain exactly restored.

## Sequence 538 — perf-save-component-dispatch — retained

Resolve each component field name once through the component registry's static
enum lookup, then dispatch generically to its existing typed parser. Keep portable
field validation, owned JSON values, numeric bounds, region validation and schema
unchanged. No concrete class branch or component-ID change. Three interleaved
process pairs/save, seven samples after one warmup, lower full decode CPU medians
95.576 to 91.201 ms for Greece B (-4.6%) and 94.243 to 91.231 ms for A (-3.2%);
every pair improves. This is the UI/shared-validation benchmark root; real server
class hooks are included in native qualification and runtime tests, and profiled
separately in 539. Timing includes identity counting and deinit, with preloaded
input/generic x86_64/ReleaseSafe. It is not a whole-load speedup claim.

Both actual saves decode and reserialize all 32 worlds to exactly their original
14.8-MB bytes with baseline and candidate. Unknown component, wrong component kind,
duplicate component, duplicate JSON member and unbounded-number fixtures reject
with identical errors. Freeze timing and roundtrip binaries separately; the
roundtrip harness additions are not pooled with the earlier timing measurements.
A coherent native build and actual UI/save/reload/crossing, fresh-load guards and
one applicable aggregate qualify the change. Snapshot changes alter the
conservative rules identity; all three modules use current 32c40af4... rules,
independently verified against 706 source files. Production checks remain enabled;
the old 516 recording is not used as acceptance of the new native modules.
Evidence: zig-out/reports/perf-save-component-dispatch-538/.

Both real Greece saves pass in-place save/reload, and the controlled world crossing
passes saving/reloading at arrival. All three candidate-produced save files also
decode and roundtrip byte-identically through the baseline reader. Intro/E1 and
renderer restart/PNG cancellation/rerequest pass under validation. The renderer's
whole-file equality assertion initially fails; exhaustive comparison proves every
byte outside nonallocated debug_line matches qualified 530. Preserve that failure
and the actual whole-file hashes; no renderer executable/data change is admitted.

Fresh B medians 3.827191 to 3.834300 seconds have +103/-8/-46 ms paired changes;
A 4.429426 to 4.492790 has +205/-51/-48 ms. These mixed results establish no
whole-load gain. Unique image/model sets and player state agree; A's strict PNG
job multiset varies and remains a measurement limitation. Frame CPU means are
21.653595 to 21.767442 and 21.987220 to 21.783172 ms, maxima 40 to 41 and 36 to 37;
unequal dynamic windows support no FPS/tail claims. Component peak RSS median B
61,548 to 61,696 KiB (+148); A 61,756 unchanged. One aggregate passes 59/59 steps,
551 native/C and 384 Python tests with the verified pinned environment. Ownership
R1–R11 remains zero; 16 engine timing/diagnostic logs are GPU-query-free. Frozen
source/artifact identities and all three original owner saves remain exact.
Headless software only; hardware/full-campaign behavior remains unverified.

## Sequence 537 — perf-save-decode-characterization — complete

Add a read-only actual save-decoder CPU benchmark with CRC/header, outer portable
stream and full typed snapshot reconstruction modes. Use immutable 513 Greece
saves, generic production CPU, ReleaseSafe, preloaded input and one discarded
warmup followed by seven repetitions. Both full decodes take about 95 ms CPU;
outer CRC is 4.13 ms and outer stream validation 4.16–4.18 ms. The latter treats
nested checkpoint bytes as opaque, so it is not full recursive validation.
Build with zig build bench-save-decode. The installed save-decode-benchmark takes
FILE MODE REPEATS, where modes are crc, stream, decode and roundtrip. The last
includes canonical encoding/hashing and is correctness evidence, not decode-only
timing. Input characterization finds 32 streams, about 14,200 records, 62,000 fields and
13.4 MB of JSON, with only 137,000 possible prior-name comparisons. Avoid an
unsupported duplicate-field hashing hypothesis; examine the component registry
scan and typed reconstruction. No loading gain admitted from characterization.
Evidence: zig-out/reports/perf-save-decode-characterization-537/.

## Sequence 536 — perf-surface-material-handoff — rejected; restored 530

After the normal eligible surface phase uses its four-ms slice, walk at most 64
already admitted surfaces and start/poll the next unprepared material's PNG batch
before yielding. Keep that batch's existing world ownership and defer compiling
the new material to a later call, even if its read is already ready. Primary,
held and pending-image loads retain their previous cadence. Retain 530's storage
pool unchanged. Prediction: overlap the next material read with foreground work
instead of beginning it a frame later. This differs from the rejected 519
intrabatch handoff and still needs actual paired endpoints/frame/fresh checks.
Evidence: zig-out/reports/perf-surface-material-handoff-536/.

Build 90/90 and validation intro/E1/two Greece saves/controlled crossing/restart/
cancellation/rerequest pass. Three normal background pairs improve the remaining
full target endpoint 6.888300 to 6.633150 seconds median (3.7%), every pair faster.
Baseline 6.639291/6.888300/7.285732; candidate 6.428167/6.633150/6.678492. All
9,903 surfaces/47 pages complete with no GPU queries or errors. Polls 157 to 144;
owner admission wall rises 690 to 759 ms, consistent with doing additional bounded
work before yielding. Process CPU 78.17 to 74.42 seconds includes foreground work;
peak RSS 2,101,672 to 2,107,672 KiB. This screening triggered queued-only handoff
lifetime, exact pixels, frame and fresh-load guards against 530. Shared image/
allocator helpers are unchanged from 530's qualified aggregate. Measurements use
the frozen 536 source and runtime identities.

Private held handoff checks pass: a real queued batch stays world-owned before
surface compilation; existing failure and shutdown cleanup release it, then a
rerequest finishes all 44 pages. Exact two TGA/private RGB outputs pass; all 22
normal timing/diagnostic logs are query-free and stable player state is preserved.
However Greece A fresh loads are slower in all three pairs (+346/+150/+4 ms),
median 4.380632 to 4.530467 seconds (+3.4%). Its PNG job multiset varies, so the
precise causal share is unproven; this tradeoff does not justify retention.
Fresh B has +50/-1229/-49 ms paired changes, including a large baseline outlier;
do not claim its apparent median improvement. Frame processing means are
22.618 to 24.251 and 24.140 to 22.814 ms, maxima 44 to 41 and 47 to 46; unequal
dynamic windows are not FPS/tail evidence. Reject and restore all six source and
nine runtime identities exactly to qualified 530. All three owner saves remain
identical. Next characterize actual save decoding, whose menu/server timings
exceed the already optimized CRC cost. No duplicate unchanged aggregate suite.

## Sequence 535 — perf-storage-retirement-model — not implemented

Model stale unused-entry retirement with every abandoned bump allocation charged
until content shutdown, keeping live plus retired charges below four MiB. On the
three current traces, one-spare retirement improves only one trace by one modeled
hit; two-spare variants range 43–59 hits, add 3–7 extra creations and abandon
0.36–1.94 MiB. No consistent advantage warrants lifecycle complexity or wasted
space. Retain 530 unchanged and move to the material-read handoff at the surface
time yield. Evidence: zig-out/reports/perf-storage-retirement-model-535/.

## Sequence 534 — perf-storage-order-trace — characterization complete

Trace current retained 530 eligible texture dimensions, actual allocation
requirements and cumulative hit/prefill/failure/unused charge at each commit.
Freeze the private renderer, then restore normal source and all nine artifacts
exactly before validation off/on/off samples. Hide notifications and keep GPU
queries off. Save both complete and post-request traces at the full target-ready
event; post-endpoint reporting is separate. Reconstruct pool ownership/charge
from observed actions before simulating alternatives. Instrumentation can change
ordering, and counterfactual policies can change existing-block availability.
No timing gain follows from this diagnostic. Evidence:
zig-out/reports/perf-storage-order-trace-534/.

All actual pool actions reconstruct exactly over 133/133/134 requests: 51/46/50
hits, 1/2/2 unused entries, peak charge 2,980,348/2,980,348/2,630,908 bytes. Optional
failures 1/1/2 all have logical budget room, which alone cannot distinguish
existing-memory exhaustion from creation/bind/view failure. Requirements are
stable by shape; full target/readiness/validation/query-free checks pass. Normal
530 source/runtime remain exact. On these current-order traces, optimistic fixed
two-spare models yield only 30/39/28 hits versus one-spare 51/50/51. Five-prior
frequency gating yields 55/52/54 with 1/1/3 unused: too modest and speculative to
justify implementation alone. Earlier trace predictions do not transfer reliably.
Next model stale-entry retirement only with explicit per-content charges for
abandoned bump allocations; no unaccounted eviction or larger bounds.

## Sequence 533 — perf-storage-policy-model — characterization complete

Replay the original 529 request sequences with a second spare gated on two,
three, four or five prior occurrences in the eight-request history. Preserve
four slots/four-MiB bounds, no eviction and no lookahead. Two-prior gating models
63/59 hits versus one-spare 51/52, but leaves an extra unused object on both traces.
Other thresholds trade hits against unused objects without a clear winner.
Evidence: zig-out/reports/perf-storage-policy-model-533/. No source change or gain
accepted. These traces precede 530; the rejected 532 real-world counterexample
shows why predicted hits alone cannot justify another policy. Collect current
530 request order, actual allocation/failure and pool state before selecting it.

## Sequence 532 — perf-content-storage-depth — rejected; restored 530

Test up to two spare empty textures after a repeated shape instead of one. Keep
530's four unused slots, four-MiB conservative charge, existing-block-only fallback,
history and eligibility; stop filling on budget exhaustion or failure. Sequence
529 modeled more hits, while 531 found spare views cheap and required views still
dominant. This is a prediction, not an accepted gain. Compare actual endpoint,
unused memory, frame/fresh guards and exact outputs against retained 530.
Evidence: zig-out/reports/perf-content-storage-depth-532/.

Build 90/90 and intro/E1/two Greece saves/controlled crossing/restart/cancellation
qualification pass under validation. Full target work and query-free checks pass
in all six normal background runs. However, median endpoint worsens 6.981361 to
7.182287 seconds (+2.9%), with two of three pairs slower. Baseline samples are
6.877285/6.981361/7.283582; candidate 7.182287/7.338216/6.691221. Actual hits vary
57/37/67 with unused entries 2/3/2: deeper speculation is order-sensitive and can
hold the wrong shapes. No gain admitted; preserve all samples and the candidate.
Restore all six normal source identities and nine runtime artifacts exactly to
qualified 530. Additional acceptance suites are unnecessary for the discarded
prototype. Continue with offline policy characterization before another change.

## Sequence 531 — perf-content-api-waits — diagnostic complete

Recharacterize retained 530 with owner wall/thread CPU timers around required
and optional create/requirements/allocation/bind/view calls, texture uploads and
descriptor writes, plus complete owner admission phase costs. Freeze the private
renderer, restore normal source and all nine runtime artifacts exactly to 530,
then sample validation off/on/off with notifications hidden and GPU queries off.
Scheduling delay stays unavailable when kernel schedstats is disabled. Use full
target readiness and additive accounting checks; infer no normal speedup from
instrumented endpoints. Evidence: zig-out/reports/perf-content-api-waits-531/.

All three off/on/off samples complete full target work with additive accounting
and no GPU queries. Required image-view calls take 1.802/1.840/1.820 seconds wall
versus 1.889/9.625/2.022 ms owner CPU; 52 spare views take 9.940/12.416/12.221 ms.
Combined view calls account for 78.7/76.1/77.4% of measured owner admission wall.
These totals include all coexisting normal-admission worlds, not only e2m4a.
Phase surface wall is 1.721/1.742/1.693 seconds; lightmaps 0.484/0.576/0.571.
No exact lock or GPU cause is proven from wall-minus-CPU. Source and all nine normal
runtime artifacts remain exactly retained 530; private module removed. Next test
bounded two-spare policy, retaining normal endpoint and memory regression guards.

## Sequence 530 — perf-content-storage-pool — retained

Prototype four unused RGBA8 texture slots with a four-MiB conservative allocation
charge. A repeated shape within eight eligible surface requests may prepare one
empty texture using existing content memory only. Taking a slot transfers ownership
before upload; failed optional allocation destroys its objects and restores the
exclusive bump cursor. No eviction, new optional memory blocks or pixel changes.
Required allocations retain their existing path. Qualification covers lifetime,
fallback, memory growth, exact pixels and paired completion/frame/fresh loads.
Evidence: zig-out/reports/perf-content-storage-pool-530/.

Build 90/90, intro/E1/two Greece saves/controlled crossing/PNG cancellation and
rerequest pass under validation. A frozen private renderer proves a hit transfers
the exact image/view without advancing the allocator, a forced post-view failure
destroys temporary objects and rolls back the cursor, and restart destroys the one
unused entry and resets state. Private hooks are absent from normal source/binary.
Both TGA captures and private-screen RGB exactly match qualified 527. Only the
Vulkan renderer differs among nine runtime artifacts; native rules remain 507.

Three interleaved pairs lower complete remaining e2m4a renderer admission from
8.264873 to 7.551208 seconds median (8.6%); every pair improves. Individual baseline
samples are 7.946490/8.610627/8.264873, candidate 7.551208/6.924728/7.894171.
All 9,903 surfaces and 47 lightmap pages complete with pending/failed images zero.
Owner admission wall falls 1.108 to 0.700 seconds, polls 175 to 161. Process CPU
92.08 to 81.07 seconds includes fewer foreground rendering/simulation frames.
Post-endpoint storage reporting occurs only in the candidate and is excluded from
that interval; complete-process CPU is not used as a paired gain. Each candidate
serves 51/134 requests from storage. End unused count is 0/2/2, charge 0/1,579,646/
1,579,646 bytes. Pool bounds remain four objects/four MiB; existing-block-only
reservation can consume space earlier and does not prove unchanged later growth.
Peak RSS median rises 2,098,540 to 2,107,024 KiB (+8,484 KiB); paired changes range
from -3,896 to +27,800 KiB. This is a measured memory tradeoff.

Fresh Greece B medians 3.925064 to 3.925379 seconds are neutral. Greece A medians
4.485113 to 4.429146 have mixed paired changes +208/0/-349 ms. Its initial PNG job
multisets differ (287/288 jobs), despite identical 263 unique image/dimension pairs,
models and stable player state. The strict audit failure and duplicate-name delta
are preserved; no fresh-A gain or strict work-equivalence claim. Two frame pairs
show mean CPU processing 34.666 to 22.545 and 22.427 to 22.000 ms; the first baseline
is an outlier, retained without attributing its cause. Unequal dynamic windows and
only two pairs do not establish FPS/tail improvements. All 22 timing/diagnostic
logs are GPU-query-free. One aggregate passes 59/59 steps, 551 native/C and 384
Python tests with the pinned virtual environment; ownership baseline stays zero.
Original three saves remain byte-identical. Headless software rendering only;
physical GPU and full-campaign behavior remain unverified. Continue by measuring
the remaining waits on this retained implementation, without publishing/deploying.

## Sequence 529 — perf-content-texture-shapes — characterization complete

Record chronological RGBA8 content texture dimensions, mip counts, texel bytes and
actual Vulkan allocation size/alignment/type bits only during eligible normal
world surface admission. Compare validation off/on with notifications hidden and
GPU queries disabled. Freeze the private renderer, then restore source and all
nine runtime files exactly to retained 527 before sampling. The trace will guide
a bounded reuse simulation before implementation; it is not a normal timing run.
Evidence: zig-out/reports/perf-content-texture-shapes-529/.

Off/on traces contain 134/133 eligible allocations. Both include 59 square512
images with 10 levels and 1,399,040 allocation bytes, plus 39 square256 images
with 9 levels and 350,464 bytes: about 73% share these two shapes. Observed
requirements are stable by shape, alignment64/typebits1. Full target admission
and validation/query-free checks pass; actual production source/runtime remain
exactly retained 527.

A non-evicting simulation with four unused slots, a four-MiB allocation/alignment
charge, dimensions at most512 and one prefill after a repeat within eight requests
models 51/134 and 52/133 hits (38–39%). Peak unused charge is 2,799,805 bytes;
both traces end with zero unused objects and no added total view creations.
This predicts requests served from already-created empty storage, not seconds
saved. More aggressive prefill is not automatically better and can fill the pool
with unused shapes. Instrumentation/order effects, optional allocation failures,
actual GPU lifetime and physical allocator-block growth need real testing.
No pool or performance gain is admitted from this simulation. Next prototype
bounded best-effort storage reuse with complete fallback and direct ownership/
pixel/frame/fresh-load comparisons; do not evict uncharged bump allocations.

## Sequence 528 — perf-lightmap-reservation-progress — rejected; restored 527

Continue from bounded image-view reservation into the existing texel/page/time
checks instead of returning pending with no uploaded pages. Keep the eight-slot
bound, formats, priority conditions and required work. Prediction: remove empty
admission passes and reduce waiting; the consistent small Greece A cost from 527
may change, but its cause is unproven. Measure frame/step costs because work can
continue after a blocking view call. Verify mixed committed/unpublished cleanup
with a private paused variant before timing. Evidence:
zig-out/reports/perf-lightmap-reservation-progress-528/.

Build 90/90 and normal intro/E1/two Greece saves/controlled crossing/restart/
rerequest qualification pass. A private pause/reject variant verifies two
committed pages remain in the image registry while six pending pages are absent;
failure and cancellation each discard exactly six, then a rerequest finishes all
44 E3 pages under validation. No production hold hook remains, verified in source
and actual binaries. The shared image helper is unchanged from 527, so its broad
551/C/384 aggregate is not duplicated. Actual pixel/frame/paired loading checks
are rerun. The prior A timing differences already start before region-ready;
an empty-pass explanation is unproven and will not be inferred from medians alone.

Normal background medians 8.048 -> 8.158 seconds (+1.4%) give two slower pairs
despite two to four fewer target polls. Fresh B 3.925 -> 3.885 seconds is mixed;
A 4.381 -> 4.431 remains consistently slower (+139, +49, +2 ms paired).
CPU medians 92.51 -> 89.48 seconds include foreground variation and do not establish
a useful loading gain. Exact pixels and all functional/ownership checks pass, but
the scheduling change is rejected. Source and all nine runtime artifacts are
restored exactly to retained 527; raw measurements and mixed-state proof remain.
Next characterize actual content texture shapes/mips and order before designing
any bounded storage reuse. Unused speculative images cannot be evicted freely
without accounting for the engine's content-lifetime bump allocations.

## Sequence 527 — perf-lightmap-view-reservations — retained; ownership and output verified

Reserve up to eight unpublished HDR lightmap image/view objects in one normal
background call, then upload the identical pages through existing time checks.
Primary, held, pending-image and non-HDR paths retain immediate creation.
Reservations have no descriptors or GPU command references; finishing moves
lifetime ownership to the image registry before recording references, and world
cleanup destroys every unused reservation. At most eight pages (about one MiB)
per active world are allocated ahead; no extra workers, formats or shader changes.
Prediction: share an expensive image-view quiet interval across a bounded group,
reducing repeated waits while keeping complete pixels and readiness. Add a private
paused-upload cancellation scenario before accepting this new ownership state.
Evidence: zig-out/reports/perf-lightmap-view-reservations-527/.

Final connected build and normal intro/E1/two Greece saves/controlled crossing/
cancellation qualification pass. An isolated paused-upload renderer then proves
eight unpublished reservations are absent from the image registry, eight are
discarded on forced admission failure, another eight on vid_restart, and a fresh
request completes all 44 E3 lightmap pages with zero pending/failed images under
validation. The temporary hold exists only in its frozen diagnostic binary;
production source/runtime are restored before timing. It is excluded from timing.

The integrated shared-image batch passes 59/59 steps, 551 native plus C contracts
and 384 Python tests with the recorded pinned interpreter. After those checks,
only a per-group success log and stale comment are removed; ownership/upload/
failure cleanup source is otherwise identical, explicitly compared in the report.
The quiet timing artifact is frozen separately and checked to contain no private
hold flag. Pixel/frame/normal loading comparisons against retained 526 follow;
normal results below use that quiet artifact.

Remaining target renderer admission is 9.120/9.372/9.319 seconds before and
8.412/7.738/8.095 after: medians 9.319 -> 8.095 (13.1%), all three pairs
faster. All 9,903 surfaces/47 lightmap pages finish, pending/failed images reach
zero, and player identity/health/armor/weapon/ammo remain unchanged. Owner
admission wall medians 1.331 -> 1.026 seconds and target polls 186 -> 172 support
reduced scheduling/wait cycles; the required texture/view count is unchanged.
Process CPU 102.90 -> 91.68 seconds includes fewer coexisting foreground frames.
Peak RSS medians 2,100,624 -> 2,101,692 KiB add about 1.04 MiB. Earlier allocation
is bounded by eight pages per world; device-memory bump blocks keep their existing
content lifetime even when an unused image object is discarded.

Fresh Greece B medians 3.87626 -> 3.87616 seconds are neutral. Greece A
4.43206 -> 4.48264 (+1.1%) has consistent paired costs +36, +51, +53 ms;
preserve this cost rather than claiming uniform loading gains. Separate
query-free frame processing means are 21.854 -> 21.835 and 23.227 -> 21.907 ms,
observed maxima 45 -> 43 and 46 -> 46. Dynamic task windows differ; no FPS,
hardware or tail claim is made. The first extra reservation-only pass is a
candidate for further measurement, not a proven explanation of the A cost.

All 22 timing/frame-diagnostic logs are GPU-query-free; six source and nine runtime
identities match the frozen quiet candidate. Only Vulkan differs from retained
526. Original owner saves remain unchanged; ownership R1–R11 remains zero.
Global PNG sets vary with coexisting worlds/cache, and this metric remains target
renderer admission after a post-load request, not whole-region gameplay readiness.
Exact pixels retain the established E1/foreign-preview scope, with actual Greece
functional checks separate; full campaign and physical GPU acceptance stay open.

## Sequence 526 — perf-lightmap-image-priority — retained; priority guards verified

Keep one-page lightmap time checks while deferred images remain pending, as well
as during primary/held loading. Permit normal two-page batching only after that
admission clears. Prediction: preserve background gain without competing for
owner/driver work before initial images finish. This tests a priority hypothesis;
525's earlier native/held-stage variation lies outside the changed branch and
cannot be attributed to it. Compare against retained 520, with the same full
scenario/output/frame/fresh-load guards. Evidence:
`zig-out/reports/perf-lightmap-image-priority-526/`.

Normal remaining target renderer admission is 12.272/12.892/11.862 seconds
before and 9.418/9.009/9.629 after, medians 12.272 -> 9.418 (23.3%). All
three pairs improve with the full 9,903 surfaces and 47 lightmap pages, pending
and failed images zero, and player state preserved. Process CPU medians
134.95 -> 106.36 seconds include fewer foreground simulation/rendering frames;
they are not raw decoder or FPS gains. Peak RSS medians 2,111,244 -> 2,099,016
KiB vary with scheduling/cache; resource budgets are unchanged. Other restored
worlds coexist and global PNG job sets differ. This is the remaining renderer
endpoint after a post-load request, not whole-region gameplay readiness.

Fresh e2m3b first-block medians 3.92469 -> 3.87504 seconds have mixed pairs.
Opposite-order confirmation is 3.82771 -> 3.87536, also mixed; all six candidate
B samples stay below four seconds in this experiment. The earlier 525 spikes
do not repeat, but this small sample does not prove their cause or rule out
tails. Fresh e2m3a 4.48317 -> 4.53987 seconds (+1.3%) has paired deltas
+246, -103, +8 ms. No uniform fresh-load gain is claimed. Preserve both B blocks,
the A cost and all superseded 525 data.

Separate GPU-query-free frame diagnostics give processing-wall means
21.665 -> 21.911 and 21.980 -> 22.014 ms, observed maxima 45 -> 41 and
44 -> 45 ms. These unequal dynamic task windows have millisecond resolution
and establish no FPS/tail result. Every diagnostic and normal timing log is
checked for absent GPU-stat queries.

Build 90/90; real intro/E1, both original Greece saves, controlled B-to-C crossing,
loading-flag reset and cold E3 partial-batch cancellation/restart/full rerequest
pass under validation. Exact TGAs/private RGB match retained 520 with the same
unmodified native516 E1 recording and limited correctness-only settings. Seven
other frozen artifacts match exactly; rebuilt cgame's allocated sections,
addresses, sizes and bytes match 520 despite a debug-metadata hash difference,
with proof tied to the same frozen 525 cgame binary. Only Vulkan world behavior
changes; no version override or disabled checks. Original owner saves remain
unchanged, ownership R1–R11 stays zero. Unchanged native551/C/Python384 broad
inputs retain their results without another duplicate suite. Actual affected
renderer/client scenarios above are rerun. Hardware and full campaign acceptance
remain unverified.

## Sequence 525 — perf-lightmap-page-pairs — superseded; not retained

Allow at least two fixed 128x128 lightmap pages before the normal background
4-ms check; primary and held loading still check after each page. At most one
extra page precedes the existing yield; workers, memory budgets, formats and
required work remain unchanged. Prediction: reuse the quiet interval after an
expensive first image-view call instead of submitting another foreground frame
between pages. The driver wait mechanism is inferred from clocks, not a stack
proof. Compare full readiness/output, frame costs and fresh-load guards before
retaining. Evidence: `zig-out/reports/perf-lightmap-page-pairs-525/`.

Build 90/90, actual UI/intro/E1/two saves/controlled crossing/cancellation and
exact pixels pass. Normal background medians 11.800 -> 9.513 seconds (19.4%)
improve in all three pairs, with full 9,903 surfaces/47 pages. However, fresh
e2m3b has a +1.123-second paired outlier; an opposite-order confirmation adds a
+0.614-second outlier. Both B block medians are about 53 ms slower. Keep both
blocks and all first failures. e2m3a is 4.582 -> 4.484 seconds with mixed/neutral
pairs. These data do not establish startup neutrality.

Frame diagnostic processing means 22.40 -> 26.21 and 23.05 -> 22.17 ms include
maxima 43 -> 81 and 41 -> 47 ms; the first candidate's surface stage reaches
61 ms. A later normal candidate lightmap step peaks at 57 ms. These are observed
costs with unequal dynamic windows, not tail estimates or FPS evidence. Seven
other files match exactly; rebuilt cgame's allocated sections match retained 520
byte-for-byte despite different debug metadata. Preserve the first overly strict
identity assertion and section proof. No 525 gain is retained. Some added startup
delay occurs after input while deferred images remain pending, motivating 526's
guard; the precise cause remains unproven.

## Sequence 524 — perf-vulkan-admission-api — diagnostic complete

Scope nonoverlapping image-create/requirements/allocation/bind/view, texture-upload
and descriptor-write paths with owner CPU and wall clocks only during normal
admission. Retain whole-phase totals and observation-window accounting. Parent
main-thread CPU/context-switch/scheduler observations distinguish unavailable
runnable-delay counters from zero. Compare validation off/on/off before deciding
which wait to remove or batch. Freeze the private renderer and restore all three
production files, remove its temporary profiler module, and restore retained 520
runtime before sampling. Evidence: `zig-out/reports/perf-vulkan-admission-api-524/`.

Validation off/on/off samples spend 6.004/5.638/5.823 seconds in image-view
creation, against only 5.75/20.52/5.69 ms of owner CPU. This is 90–92% of
whole measured normal-admission wall. Other flat scopes are small: descriptor
writes take 0.56/7.79/0.53 ms, and texture uploads remain tens of milliseconds.
Do not attribute the major wait to these other calls or optimize raw owner
compute. Kernel sched_schedstats is disabled; runnable delay is unavailable,
recorded as null, and no system settings change. Main-thread context switches
include coexisting rendering and command delivery; they do not identify a lock.

All three copied-save/full-target runs pass. Flat API wall/CPU sums fit within
whole-phase totals, and CPU <= wall <= parent-window checks hold. Build 90/90;
all production source/runtime files remain retained 520 and the temporary module
is removed. No normal performance gain is claimed from these private diagnostics.

## Sequence 523 — perf-renderer-owner-costs — diagnostic complete

A private renderer measures normal admission subphases with monotonic wall time
and CLOCK_THREAD_CPUTIME_ID, without GPU queries. Reset/query commands bracket
the same target window. Freeze the variant, restore source/runtime exactly to
520, then run validation off/on/off. Evidence:
`zig-out/reports/perf-renderer-owner-costs-523/`.

Aggregate owner CPU is 0.516/0.541/0.510 seconds against wall 6.533/6.387/6.333.
Lightmaps contribute wall 3.787/3.692/3.603 seconds but CPU 0.110/0.141/0.105;
surfaces wall 2.619/2.581/2.614 and CPU 0.350/0.345/0.353. Raw owner compute
does not explain most renderer wall time. Wall minus CPU includes blocking,
runnable delay and measurement overhead; it does not identify a GPU wait or
particular lock. Next scope actual Vulkan allocation/upload/descriptor calls
and check main-thread scheduling delay before choosing an optimization.

All three copied-save/full-target runs pass; owner CPU <= wall and summed phase
wall <= the parent observation-window bound. Build 90/90; original source and
all nine runtime files are restored to retained 520 before sampling. Worker CPU
is excluded from the owner clock. Instrumentation/code-layout effects and command
boundaries prevent using these runs for normal loading/FPS claims.

## Sequence 522 — perf-resident-owner-phases — diagnostic complete

Attribute each existing normal resident step to actual renderer, collision,
config, inline-model, model, sound or finalization work, reusing existing engine
millisecond stamps. Counters are private; freeze the diagnostic cgame and restore
both source files/all nine runtime files to retained 520 before sampling.
Evidence: `zig-out/reports/perf-resident-owner-phases-522/`.

Validation off/on/off runs attribute renderer wall totals 8,537/9,741/6,435 ms,
versus collision 31/41/36, model 52/82/48 and inline 0/1/0 ms. Other native
phases have no work in this target window. Renderer exceeds 98% of attributed
owner wall in all three. Step/call additivity holds and copied-save/background
completion checks pass. Time-budget exits also dominate validation-off calls
(510/522 and 508/516), confirming that 521's conclusion is not solely validation
overhead. Preserve both off samples and their variation. These are integer wall
times, not CPU or GPU measurements. Other worlds coexist; target renderer-ready
does not finish every native resource admission. Next split renderer subphases
and owner-thread CPU versus wall before choosing a compute/wait optimization.

## Sequence 521 — perf-resident-poll-limits — diagnostic complete; no cap increase

Measure whether retained 520's normal owner calls stop at eight steps, one
millisecond, or no pending work before tuning either cap. A private diagnostic
cgame adds counters without extra per-step clocks; a private console command
prints/resets them around the same background target. Timings are diagnostic
only and exclude normal performance comparisons. Freeze the diagnostic, then
restore production source/runtime exactly to retained 520 before sampling.
Evidence: `zig-out/reports/perf-resident-poll-limits-521/`.

Both copied-save/background-target diagnostic runs pass under validation. Normal
calls/steps/time exits/count exits/idle exits are 518/818/509/9/0 and
519/861/501/18/0; additive and step-bound checks pass. Time ends 96.5–98.3% of
calls, the count cap only 1.7–3.5%, so raising the poll count lacks support.
Next attribute actual owner work to renderer and native resource phases using
existing clocks. These are instrumented call counts, not per-frame/FPS evidence;
console reset/read boundaries include command delivery. Production source and
all nine runtime files remain exactly retained 520. No optimization is admitted
from this diagnostic, and its timings are not pooled with normal measurements.
All 521 runs enable Vulkan validation, so its normal-mode distribution initially
applies to that diagnostic workload. Sequence 522 repeats without validation
before using the distribution to choose further work.

## Sequence 520 — perf-resident-cheap-polls — retained; bounded progress verified

Normal resident admission currently performs one global resource poll per frame,
even if it only checks an unfinished worker. Permit at most eight existing steps,
yielding after one millisecond of elapsed owner work; held admission retains its
256-step/30-ms path. Each existing resource remains cooperative and can exceed
the time budget on its own. Earlier cheap work can add less than one millisecond
before that operation. Preserve round-robin fairness, complete readiness, worker
and image bounds, resources and output. Prediction: reduce round-robin worker
scheduling gaps; compare complete renderer admission, fresh loads and query-free
frame diagnostics before retaining. Baseline is qualified 517v2, with rejected
518/519 absent. Evidence: `zig-out/reports/perf-resident-cheap-polls-520/`.

Normal paired background renderer readiness is 20.056/19.127/17.939 seconds
before and 11.824/12.489/11.718 after: medians 19.127 -> 11.824 (38.2%), all
three pairs faster. The target retains 9,903 surfaces and all 47 lightmap pages;
pending/failed images finish at zero and player state is preserved. Owner
admission wall medians are 1.827 -> 1.734 seconds; this gain reduces scheduling gaps rather
than proving faster decoding. Process CPU 204.60 -> 133.61 seconds includes fewer
coexisting foreground frames. Peak RSS median 2,086,144 -> 2,110,924 KiB adds
24.2 MiB despite unchanged worker/cache budgets. Other restored worlds coexist;
global PNG work differs. This is remaining target renderer admission after a
post-load request, not whole-region gameplay readiness or cold-storage latency.

Fresh e2m3b medians 3.97834 -> 3.97650 seconds are neutral. e2m3a 4.43870 ->
4.47991 seconds (+0.9%) includes paired deltas +298, -108, -150 ms. Keep every
sample and make no fresh-load improvement claim. Separate query-free frame
diagnostics give processing-wall means 22.11 -> 21.81 and 21.90 -> 23.11 ms,
maxima 43 -> 43 and 35 -> 42 ms. Timers resolve milliseconds and task windows
have different durations/work densities; these establish neither FPS nor tail
latencies. GPU stats are absent from every verified diagnostic log.

Build 90/90, intro/E1, both actual Greece saves, tighter controlled B-to-C
crossing, loading-flag reset and cold E3 partial-batch cancellation/restart/reuse
pass under validation. Exact TGAs/private RGB match the qualified 517v2 reference
with the same unmodified native516 E1 recording/rules identity. This remains a
limited single-world/foreign-preview pixel fixture. Original Greece saves remain
unchanged. Seven other frozen files match 517v2 exactly; cgame changes behavior.
Rebuilt Vulkan has a different whole-file hash but every allocated ELF section,
address, size and byte matches 517v2: nonallocated debug metadata differs. Preserve
the first overly strict whole-file identity assertion failure and section proof.
Ownership R1–R11 remains zero; unchanged native/C/Python aggregate inputs retain
their 551/C/384 results without a duplicate broad suite. Actual client paths,
outputs and timing guards above are rerun. No full campaign/hardware acceptance.

## Sequence 519 — perf-image-read-handoff — rejected; source/runtime restored

Replace experimental 518's extra frame hook with a bounded handoff in the existing
image-batch poll. Once one image completes, release its input and decoder, then
dispatch only the next asynchronous read. Do not poll that read, decode inline,
iterate over more completions, or alter the one-read/one-decoder pixel budgets.
Prediction: remove one owner scheduling gap per image while preserving complete
readiness and output. Compare against qualified 517v2, with the same immutable
Greece inputs and separate diagnostics. Add contracts for decoder/cache completion,
next-read dispatch failure, cancellation immediately after handoff, and premature
batch selection. Evidence: `zig-out/reports/perf-image-read-handoff-519/`.

Build 90/90, real UI/intro/two Greece saves/controlled crossing/cancellation pass.
A fresh recording with unmodified native modules gives exact TGAs/private RGB
across two baseline processes and the candidate. The added C tests change the
conservative native identifier because the rules hash includes tests: comparison
arms use identical new unmodified modules, changing only renderers. No version
override or disabled check. Aggregate 59/59 steps, 551 native plus C contracts and
384 Python tests pass with the recorded pinned interpreter. PNG contracts cover
decoder/cache completion, next-read failure and cancellation after handoff.

Background median 17.920 -> 17.732 seconds is mixed across pairs. Fresh e2m3b
median 3.8782 -> 3.8765 seconds is effectively neutral; e2m3a 4.581 -> 4.490
includes a final paired 251-ms regression. All samples remain. This is insufficient
evidence to retain the added handoff. Restore C/tests and all nine runtime files
exactly to 517v2, including its native rules manifest. Many per-material batches
cannot benefit unless they contain multiple images; batch-size frequency has not
been measured. No loading/CPU/FPS gain is accepted from 519.

## Sequence 518 — perf-world-image-progress — superseded; measurements preserved

Advance at most one existing background material-image batch after frame
submission, round-robin across pending worlds. Keep primary/held and reentrant
admission unchanged. Never create, select, fill or release batches in this hook;
GPU admission and uploads remain in their existing owner path. Reset the cursor
on shutdown. Existing byte/thread bounds stay fixed, but earlier completion/cache
copies cost owner CPU. Keep that work outside the old submit/present timer and
give it a separate optional CPU profile label. Prediction: reduce frame-level
read/decode/completion gaps and complete background renderer admission. Compare
actual output, endpoints, frame intervals, memory and cancellation before retaining.
Evidence: `zig-out/reports/perf-world-image-progress-518/`.

Build passes; only the Vulkan renderer differs from qualified 517v2. Both actual
Greece saves load under validation. Preserve the first controlled-crossing failure:
the old follow fixture refuses once, then remains latched even when Mikiko catches
up to 73 units, matching the separately verified 507 bug. A tighter private
fixture puts the existing companion at the portal with the existing Stay order;
the same 150-unit rule remains. Intro/E1, both actual saves and this controlled
B-to-C movement/stable arrival pass. No production party behavior is changed.

A fresh private single-world E1 cancellation diagnostic starts a cold E3 image
batch, observes PNG progress before world readiness, interrupts with vid_restart,
then requests the world again and reaches readiness. No owner save is converted
to another residency mode. Reproducible foreign-preview TGAs/private RGB match
517v2 exactly with the same unmodified native recording and limited correctness
settings. All normal Greece timing retains resident1 and normal visual settings.
Frame-stat diagnostics precede uninstrumented matched endpoint trials.

GPU-query frame diagnostics expose an observer effect: baseline target readiness
is 12.830 seconds/113 polls with r_vkStats, versus roughly 17–18 seconds/194–198
polls without it. Owner admission wall also shifts substantially. Preserve this
measurement-path difference and do not use GPU-query timing to assert normal
frame cost. The new scope is present; its largest printed group average is
0.059 ms/frame, not a per-call maximum. The instrumented frame means 29.14 ->
30.71 ms have unequal task windows/work densities and establish no normal FPS
regression or improvement.

A separate query-free diagnostic uses unchanged engine com_speeds timers and a
report-only copy of the collector that timestamps console frame completions.
GPU stats stay off in all four verified logs; debug notification text is hidden.
Two opposite-order pairs give completion-interval means 22.29 -> 22.40 and
24.21 -> 22.16 ms; engine processing wall means 21.78 -> 22.03 and 23.68 ->
21.78 ms. Engine timers resolve milliseconds; console timestamps include delivery
jitter. These dynamic task windows are diagnostics, not per-frame tail/steady FPS
claims. Raw groups, all samples and the original profiler difference remain.

Normal background renderer readiness falls from median 17.279 to 14.552 seconds
over three pairs, with all target surfaces/lightmaps complete. Fresh e2m3b is
neutral (3.822 -> 3.824 seconds), but the original e2m3a block is slower in all
three pairs (4.279 -> 4.444 seconds). An opposite-order confirmation is mixed
(4.379 -> 4.282 seconds); keep both blocks, with no uniform fresh-load claim.
A structural r_vkStats=1 load trace contains no hook CPU scope during held
admission; the helper's positive-control assertion then fails because no hook
ran before capture ended. Actual hook activity is established separately in
background diagnostics. This does not support adding a priority guard to explain
held-load variation. Preserve all failed assertions and outputs. Remove 518's
extra frame hook while evaluating 519's narrower existing-poll handoff against
qualified 517v2. Frozen 518 binaries and measurements remain; 518 is not retained.

## Sequence 517 — perf-world-surface-budget — retained v2; renderer modes verified

Greece maps contain 7491/7491/10636 surfaces. The extra 64-surface yield imposes
at least 118/118/167 calls to the surface stage even when work takes less than
its existing 4 ms allowance. Final v2 removes that count-based yield only during
normal background work; primary and held loading retain it. Always retain the
elapsed-time check after every surface, asynchronous waits, ordering, validation,
memory ownership and complete readiness. A single shader operation may exceed
the cooperative time budget in either implementation. Prediction: reduce required
resident-world admission delays without reducing work or changing pixels. Freeze
qualified 516 as baseline, build the connected renderer and compare actual native
UI/loading, counts and phase peaks before retaining. Evidence:
`zig-out/reports/perf-world-surface-budget-517/`.

Initial causal hypothesis is corrected before acceptance: the client pumps up to
256 calls per frame with a 30 ms allowance while waiting, and actual ready-world
logs show thousands of polls. The count cap does not force one frame per chunk
during initial loading. Normal background admission performs one step per frame,
so measure that separately as well as matched complete fresh loads. Preserve the
original design and this falsification; no gain is accepted from primed smoke
times compared with fresh-process baseline times. Candidate native UI/intro/
e1m1a/two-save qualification passes under validation; original inputs are intact.

Only the Vulkan renderer artifact changes; the other eight frozen 516 artifacts
match exactly. A fresh unmodified 516 demo in the previously qualified E1/459
fixture gives exact repeated TGAs/private RGB across two baseline processes and
the candidate after complete foreign e2m4a admission and a visible authored-start
preview. This correctness-only fixture fixes the clock and disables TAA/auto
exposure; normal current-Greece UI and timings retain resident1 and normal visual
settings. Both complete reference/candidate runs pass validation and clean exit.

Keep first useful failures: a broad helper initially treated expected demo-start
disconnect as an error; scoping that transition exposes unchanged-516 resident
Greece demo InvalidWorldChunk. Latest Greece with residency disabled also emits
checkpoint InvalidRegion, so it is not admitted as a correctness fixture. The
established E1 fixture avoids both without disabling validation. Its first pixel
callback finishes but shared cleanup waits for a server already disconnected by
demo playback; cancel that exact private guard and fix callback cleanup to return
to a live private map. Raw failures and first pixels remain; later complete runs
are the acceptance reference. No production workaround is introduced for these
baseline/harness limits. Background and matched fresh-load evidence is pending.

First candidate v1 completes three interleaved background pairs: target e2m4a's
9903 surfaces/47 pages become ready at median 41.724 -> 18.380 seconds (55.9%),
ranges 32.533–43.259 / 17.827–20.044. Target polls fall 358/358/361 -> 199 each;
player state remains stable. Coexisting normal restored-world work makes global
PNG sets differ at this target endpoint; do not claim whole-region completion or
equal global work. Every target page finishes and static preview pixels match.

Twelve matched fresh-load trials expose v1's tradeoff: e2m3b median 3.830 -> 3.774
seconds, but e2m3a 4.379 -> 4.579, all three e2m3a pairs slower by 110–205 ms,
with CPU medians 18.288 -> 19.961 seconds. Preserve v1's source/runtime/results
and supersede it. Connected v2 reads the existing client-owned dk3_region_loading
flag and whether a primary world is selected: retain the original 64-surface cap
during primary/held admission, use the existing
4 ms time allowance alone during normal background work. No new game policy,
native ABI, thread, memory or format change. Build and qualify both modes before
acceptance; source/native modules remain otherwise fixed to 516. Evidence lives
under the same report's `v2/`. Keeping primary registration unchanged also retains
506's model-prefetch pump cadence between synchronous admission chunks. The first
held-only v2 build is preserved as unqualified; final v2 covers both cases.

Final v2 passes its integrated build with the other eight runtime artifacts
byte-identical to 516. Static foreign-world TGAs/private RGB remain exact against
the reproducible baseline. Native current-asset resident1 qualification covers
intro/e1m1a, both actual Greece saves, controlled authored B-to-C movement and
stable arrival with player/loadout preserved. The existing region-loading flag
reads zero after every completed admission. This controlled crossing does not
claim the separate party-retry fix is installed or natural full-map traversal.

Six interleaved live background trials with unchanged visual settings measure
remaining e2m4a renderer preparation after the post-load request: median 33.081 -> 18.134
seconds (45.2%), ranges 31.557–33.157 / 17.935–18.139. All three pairs improve.
Target polls 358/360/361 -> 201/196/198; every target's 9903 surfaces and 47 pages
finish. Other normal restored background worlds coexist, so global PNG/skin work
at this target endpoint differs: no whole-region, full gameplay admission or
equal-global-work claim. The endpoint is the render world's ready event.
Process CPU during the interval falls 371.59 -> 204.39 seconds, including fewer
foreground rendering/simulation frames before target completion; this is not a
steady FPS or per-frame compute gain. Peak RSS medians 2088868 -> 2088712 KiB
are effectively unchanged; the first candidate pair increases 16436 KiB. Observed
maximum poll-step times span 27–30 ms in both arms, not a hard 4 ms guarantee.

Twelve matched fresh loads give e2m3b median 3.774 -> 3.877 seconds, including a
291 ms slower candidate pair; e2m3a 4.430 -> 4.328. CPU medians fall slightly in
that block. Resolve the e2m3b concern with a separate six-process reversed-order
block using the same immutable inputs/binaries: 3.774 -> 3.773 seconds, two paired
deltas within 2 ms and one candidate +54 ms. Its CPU median rises 13.967 ->
14.713 seconds. Preserve both blocks and every outlier; no uniform fresh-load or
CPU improvement is claimed. Stable player fields, required models and completed
image admission pass throughout; time-dependent positions/global duplicate PNG
preparations retain their raw variation. No physical-GPU or latency-tail claim.

Source/runtime fingerprints remain frozen; ownership stays R1–R11 zero. The
551-native/C/384-Python aggregate from 516 still covers unchanged native/tool/
image-level inputs: this renderer-only batch uses the actual renderer build and
affected scenarios above, without duplicating the unchanged broad suite. No Git
publication, original save or installation write. Next inspect residual image-batch
polling gaps while retaining the same foreground/held behavior.

## Sequence 516 — perf-native-crc — retained; native components and integration verified

The isolated portable Zig experiment compares std's byte-at-a-time CRC with
eight/sixteen-byte lookup groups at the actual generic x86_64 target. All three
algorithms match Python zlib for 131104 length/alignment cases. Three component
blocks per actual save give about 23.1 / 5.2 / 4.1 ms for the outer body. These
are resident-memory component results, not complete decoding or loading gains.

Select sixteen-byte groups for the core IEEE CRC mechanism and connect both
Reader.init and Writer.finish. Keep every outer/nested checksum and final writer
validation, error, bound and format byte unchanged. The fixed table is 16 KiB
per linked copy, with no per-save allocation or new CPU feature requirement.
Include known vectors, all short tails, unaligned and larger boundaries against
the independent std implementation. Prediction: reduce native decode/capture
work and complete save loading; verify native UI/save compatibility and endpoint
timings before accepting. Evidence: `zig-out/reports/perf-native-crc-516/`.

Integrated build passes 90/90; renderer binary is byte-identical to 514. Both
Greece saves pass native UI load, new write, independent Python outer/nested CRC
validation, the original bitwise C validator, native reload and a second write
with player loadout/keys preserved under Vulkan validation. Aggregate passes
59/59 steps, 551/551 native tests plus C contracts and 384 Python tests. Class
ownership stays R1–R11 zero. Source/runtime hashes remain exact after checks.

Twelve interleaved fresh-process loads use identical original saves/profile/assets
and private cold Mesa caches. e2m3b readiness median 4.028 -> 3.732 seconds (7.4%);
all three pairs improve. e2m3a 4.488 -> 4.529, a 0.9% regression: preserve two
slower pairs and claim no uniform endpoint improvement. Native menu decode
medians 168 -> 103 / 142 -> 114 ms, server decode 147 -> 100 / 137 -> 102,
restore 225 -> 149 / 228 -> 150. Retain the demonstrated component gain and
e2m3b latency gain with e2m3a limits explicit. Full-process CPU medians rise
14.233 -> 14.782 / 18.696 -> 19.119 seconds; RSS medians change -4976/-2140 KiB.
Do not claim CPU/memory savings from this small complete-process comparison.

Map/player/health/armor/loadout and completed admission match. e2m3b's 273 PNG
preparations match across all trials. e2m3a has 288/287/288 preparations in each
arm: one duplicate varies within unchanged baseline too, while every paired
name/dimension multiset matches. Keep the raw across-trial work mismatch and
moving-position variation; neither is suppressed as exact-state equivalence.
New native rules identity 5071c870... requires a fresh recording before future
demo performance tests; no version override entered these timing/acceptance runs.
No Git publication or installation change. Next investigate the separate resident
surface-admission cadence, retaining its existing time budget.

## Sequence 515 — perf-native-save-profile — diagnostic verified; no runtime change

An isolated shared probe calls the actual core save Reader and std CRC under
generic x86_64 Linux ReleaseSafe, using the same two copied Greece saves. Five
resident-memory samples after warmup measure about 23.1 ms for the outer 15 MB
CRC, Reader.init and top-level Reader.validate alike. Full snapshot decoding is
not measured by this probe. Each save contains 31 resident snapshots totaling
nearly another complete body; snapshot.decode validates their individual CRCs
as well. Do not remove either outer or nested validation. This identifies a
portable native checksum component for a separate algorithm experiment; it does
not establish a new loading gain or an additive time budget. No production source
changes. Evidence: `zig-out/reports/perf-native-save-profile-515/`.

## Sequence 514 — perf-save-crc — retained; component and integrated verified

Replace the engine save stream's bit-at-a-time IEEE CRC32 with its already
bundled zlib implementation, retaining the polynomial, initial/final state,
256 MiB size limit, every format check and exact saved bytes. GCC component
validation of copied 15 MB Greece saves falls from roughly 95–105 ms to 4–7 ms;
keep those sequential component samples separate from actual engine results.
Both accept original saves and reject payload corruption. The new C contract
compares the writer against an independent bitwise reference for 256 payload/
alignment cases plus empty streams, corruption and truncation.

Final integrated build passes 90/90. Actual DK_SaveOpen calls bundled crc32;
source and binary identities are frozen. Adding the C contract changes the
conservative native rules identity; qualify both Greece saves with the complete
unmodified final runtime under validation. For the matched comparison, compose
the unchanged qualified 509 modules/renderer with only the new engine executable:
no byte patch or version override. Final renderer allocated sections match 509;
its raw hash changes only in .debug_line. No duplicate shader/pixel suite is run.

Twelve balanced fresh-process trials use the same copied profile/saves and exact
31db9148... assets, resident worlds enabled, private cold Mesa caches and warm/
uncontrolled OS pages. Engine validation/staging median falls 156 -> 12 ms on
both maps. e2m3b readiness median 4.135 -> 3.927 seconds (5.0%); all three pairs
improve by 103–293 ms. e2m3a 4.688 -> 4.636 (1.1%); preserve the 5 ms slower pair
and baseline staging outlier 235 ms. CPU medians 15.209 -> 14.723 / 18.616 ->
19.511 seconds; all three e2m3a CPU values increase. RSS medians rise 5700 /
13112 KiB, despite adding no per-save scratch allocation. These complete-process
resource observations include startup, rendering, restored simulation and capture;
do not attribute their changes solely to CRC or claim uniform CPU gains.

Every load preserves input files and completes image admission with pending/
failed zero. Map, player ID, health, armor, weapon and ammo match. The moving
e2m3a save starts with velocity [98,-177,0]; sampled post-load positions vary
slightly in both unchanged baseline and candidate as it decelerates. Preserve
the raw exact-state mismatch rather than call these time-dependent positions
byte-identical. CRC/stream compatibility is established independently above.
Aggregate passes 59/59 steps, 550/550 native tests plus C contracts and 384 Python
tests with the pinned interpreter. No installation, original save, schema, visual
quality or Git publication changes. Evidence: `zig-out/reports/perf-save-crc-514/`.
Next profile the remaining native save decode and resident admission costs.

## Sequence 513 — perf-greece-loading — diagnostic verified; no new optimization

Profile the owner's copied e2m3b/e2m3a saves and immutable profile from 507 under
qualified 509/default4 with resident worlds enabled. This extends characterization
beyond the e1m1b benchmark, rather than assuming its bottlenecks represent Greece.
Use guarded headless software rendering, cold private Mesa caches and validation;
times in this diagnostic are instrumented and establish no performance gain.
Record source-save preservation, restored state, completed image admission and
stage/model waits. No source/runtime change is introduced. Evidence:
`zig-out/reports/perf-greece-loading-513/`.

Preserve the first SaveAssetMismatch from the older 459 fixture: it does not match
the latest saves. Correct the fixture to the exact read-only installed 31db9148...
generation previously qualified in 507, without bypassing any save check. Both
unmodified saves restore their actual Greece maps, state and complete images under
validation, with input preservation passing. All three companion model waits are
zero. Cumulative region-wait -> region-ready spans 849 -> 2405 ms / 691 -> 2798 ms;
save menu decode is about 140 ms, engine validation/staging about 153–155 ms,
server decode 133 ms, restore 229–230 ms. These instrumented single observations
are diagnostic, not comparative gains. Investigate the engine's bitwise CRC before
touching serialization/validation semantics; resident admission remains separate.

## Sequence 512 — perf-package-admission — retained; tooling verified

Sequence 511 profiles warm launcher preparation using a private CoW fixture with
current runtime files and copied HD/neural/material overlays. Three warm calls
take 4.32–5.15 seconds; package admission stays 1.384 seconds, neural validation
1.70–2.21, final hashing 1.05–1.22. The initial seed/publication is excluded.
Evidence: `zig-out/reports/perf-launcher-stages-511/`.

Admit independent packages with at most four workers for inputs above 32 MiB;
small installations remain serial. Preserve every full-package SHA, streamed
entry CRC, gameplay entry SHA and namespace requirement. Collect results in
original package order and join/cancel on error. Prediction: overlap independent
hash/decompression work and reduce complete warm preparation without changing
the published generation. Check corruption, cleanup, deterministic gameplay and
installation identities before retaining. No engine build is needed for this
tool-only change. Evidence: `zig-out/reports/perf-package-admission-512/`.

Six interleaved fresh launcher processes with the older compressed neural overlay
reduce complete warm preparation median 5.286 -> 4.752 seconds (10.1%); all three
paired totals improve. Admission median 1.410 -> 0.974 seconds (31.0%). Full total
ranges are 4.612–5.349 / 4.036–4.882; CPU medians 15.297 -> 15.122 seconds are
near neutral and individual pairs vary. Peak RSS medians 61908 -> 61680 KiB do not
remove the extra bound of four active streaming readers. All installed file
records, gameplay compatibility and generation keys match exactly across arms.
Focused checks cover both stored/deflated identity and CRC rejection under serial
and parallel admission, plus peer-reader joining on error. All 384 Python tests
pass with the pinned interpreter and explicit DKGUARD. Preserve first harness
failures (missing PYTHONPATH, then missing DKGUARD) and corrected runs. No native
source changed in this batch. Separate stored-PNG confirmation uses six fresh
processes and an independently seeded private prefix. Preparation median falls
4.547 -> 4.088 seconds (10.1%); all three pairs improve by 359–581 ms. Admission
1.423 -> 1.116 seconds. CPU median rises 12.405 -> 13.205 seconds (6.4%), with all
three candidate CPU samples higher; retain this cost rather than claim CPU savings.
RSS medians 63252 -> 62564 KiB; every published record matches between arms.
Keep the lower user-visible preparation latency with the CPU tradeoff explicit.
Do not pool overlay workloads or extrapolate to cold storage, engine FPS or GPU
throughput. Runtime 509 is unchanged. No additional Git publication is performed.

## Sequence 510 — perf-model-image-progress — rejected; qualified 509 restored

Advance existing model batches before and after synchronous owner image admission,
so the next PNG read/decode can overlap other images' mip/upload work. Keep the
calls out of worker-safe prepareLevels/Deferred.work. Pump never fills/releases
slots or selects a different batch; selected pixels remain independently owned
across cache eviction. Four slots, thread/pixel budgets, images and GPU ownership
stay fixed. Prediction: reduce the remaining Superfly waits (30–97 ms in five of
six four-slot samples) and complete loading. Cache copies still cost owner time;
a lower wait timer alone is not an accepted gain. Build and native UI qualification
pass, but twelve matched fresh-process loads regress readiness: arrival median
2.765 -> 2.816 seconds; autosave 2.974 -> 3.070. Arrival CPU falls slightly
11.229 -> 11.091 seconds, while autosave rises 12.795 -> 12.986. Retain all samples;
reject the experiment. Restore image.zig and all nine frozen runtime artifacts
exactly to qualified 509, with source/runtime hashes verified. No repeat aggregate
or pixel suite is required for rejected code. Next measure warm launcher stages.
Evidence:
`zig-out/reports/perf-model-image-progress-510/`.

## Sequence 509 — perf-model-four-slots — retained; integrated and aggregate verified

Extend the bounded preparation array and probe control to four slots, keeping
default three until endpoint evidence selects it. Qualified 506 early overlap
still waits about 203–207 ms across later model groups. Prediction: preparing the
fourth group during world work reduces those waits and complete fresh-save
readiness. Per-slot limits stay 32 MiB model / 128 MiB pixels; the approximate
worst temporary bound rises 1248 -> 1664 MiB when four are requested. Measure
actual RSS/CPU, names/order, decoded work and complete image admission. Compare
qualified 506/three, extended/three and extended/four in balanced three-arm
processes using one immutable profile. Sequential build passes; four-slot native
UI qualification is running. No gain/default change is accepted yet. Evidence:
`zig-out/reports/perf-model-four-slots-509/`.

Eighteen fresh-process trials complete with one immutable resident-disabled
profile, cold private Mesa caches and uncontrolled/warm OS pages. Same extended
binary three/four readiness medians: arrival 2.826 -> 2.766 seconds; autosave
3.276 -> 3.124. All six paired readiness values improve. Arrival process CPU
median falls 11.36 -> 10.71 seconds; autosave rises 12.65 -> 12.88, with all three
autosave CPU deltas +0.205 to +0.441 seconds. These include startup/capture work,
not isolated decoder CPU. RSS medians 2440396 -> 2428160 / 2478380 -> 2454756 KiB;
one arrival pair increases 1096 KiB. Preserve the larger worst-case bound above
despite lower measured RSS. Qualified 506/three control readiness is 2.966/3.321
seconds; do not attribute its whole difference to the extra slot. All arms
register the same eight model names/order and 64 PNG name/dimension jobs per save,
restore identical state and complete admission with pending/failed zero.

Select four as the default for unset configurations after the controlled setting
comparison; explicit saved limits still apply. Final default-only build passes
90/90. A private profile with the old limit removed proves actual four-slot native
UI/intro/e1m1a/two-save admission. Cache-off/four and one-slot cases pass under
validation and preserve inputs. Classic/Neutral/AgX TGA/private RGB match using
the explicitly limited old-demo version-literal diagnostic; production renderer
is exact and unmodified native modules qualify all UI/loading/timing results.
Final source/runtime hashes match frozen runtime-default4. One aggregate passes
57/57 steps, 550/550 native tests plus C contracts and 383 Python tests with the
pinned interpreter/dependencies verified. Keep the modest latency gain and
autosave CPU tradeoff without confidence/tail, cold-storage or physical-GPU claims.

Separate resident-enabled qualification uses one immutable profile and the same
final binary explicitly set to three/four slots. Twelve fresh-process loads
reduce arrival readiness 4.029 -> 3.828 seconds and autosave 4.389 -> 4.229;
CPU medians fall slightly. Arrival RSS rises 36036 KiB (about 35 MiB), autosave
falls 13268 KiB. Preserve the first slower four-slot arrival pair and every other
sample. Do not pool these measurements with the standalone workload. Four remains
the selected default after both workload comparisons; resource costs remain real.

## Sequence 508 — perf-weather-prepared-empty — rejected; qualified 506 shader source restored

Use the otherwise-unused fourth component of each prepared splash corner as a
has_position marker. The main vertex shader already loads that vec4; absent
states have exactly zero color, so skip the separate color fetch only for those
states. Corner xyz, invariant geometry dependency, all particle work/counts,
80-byte layout, capacity and fallback stay fixed. This tests conditional buffer
load overhead against the added branch; no throughput gain is accepted yet.
The qualified baseline is frozen 506. A sequential build reuses its clean local
cache; source/runtime identities and exact images precede timing. Use immutable
copied profiles for every comparison. Evidence:
`zig-out/reports/perf-weather-prepared-empty-508/`. The unrelated Greece fix
remains isolated and verified under 507; continuous headless optimization resumes.

Three rain modes/private RGB, two authored snow views and resize checks pass
exactly. Actual embedded SPIR-V contains a conditional color load, but that is
not a throughput gain. Record a new demo with the unmodified coherent 506 runtime
so both timing arms use normal native checks; no compatibility override or RNG
override enters timing. All eighteen work rows match. Three paired processes
give frame-average median 52.18 -> 52.69 ms (ranges 50.06–55.27 / 50.78–56.17),
CPU per 384 frames 137.25 -> 137.10 seconds, essentially neutral. Two paired
frame medians regress. Preserve candidate CPU outlier 144.17 seconds and every
other sample. Reject without additional cold-load or aggregate repetition and
restore both shaders exactly to 506. Continue with bounded model concurrency.

## Sequence 507 — save-world-transition — focused fix verified; isolated from perf PR

The owner reports Greece exits failing to start the next world, possibly after
save/load. Private copies of development-profile autosave-arrival (e2m3b),
autosave (e2m3a), save2 (e2m1b), metadata/profile and exact installed generation
31db9148... are preserved. Newest internal restart/resume files are e1m7b and
are not substituted for the Greece fixtures. Original source saves are unchanged.
Evidence: `zig-out/reports/save-world-transition-507/`.

On the unchanged installation, normal movement from the actual e2m3b save into
the return exit reproduces ExitRequiresCompanions. The exit stays latched after
that refusal, even when Mikiko catches up to roughly 136 units (inside the
required 150). There is no visible party-refusal explanation. Save/load itself
passes, so this is not evidence of corrupt saves. A forward diagnostic additionally
exposes missing reference behavior: an attempted departure must call required
companions over, ahead of discretionary combat/collection. First wrong-side and
800-coordinate forward setups are retained as limited/invalid diagnostics; a
successful harness exit alone never establishes an actual crossing.

Implement the connected fix in independent source snapshot
`/home/dmitriy/sources/dk3-save-world-fix`, outside the perf branch and dirty co-op
checkout. Exit-owned authored touch clears the latch on a party refusal and
retries/messages after 2500 simulation milliseconds. A checked party hook calls
only required living enabled members using their existing saved Come order and
normal motor. Proximity remains below 150; no schema/field, teleport, spawn,
asset or installation change. Arrival-disarmed latches still require leaving
and reentering, preventing bounce-back. Shared contact handling now dispatches
a checked hook instead of reading exit state directly. Reference provenance and
limits are recorded in the exit/companion class review sheets.

Latest frozen `runtime-summon` passes: actual copied user save, natural B-to-A
movement, a save/load while waiting in the exit, real companion catch-up and
automatic crossing without leaving/reentering, stable arrival and subsequent save.
Player ID 433, health 100, weapon 9, ammo 2, inventory 7936 and keys 10240 persist.
A separate controlled fixture at the exact authored B landing, with the existing
required companion nearby, passes normal movement B-to-C and stable arrival with
summons active. This is not full traversal of the Greek map. Source, input and
runtime identities accompany both cases. Build 90/90 and one final aggregate
57/57 steps, 553/553 native contracts plus C contracts, 383 Python tests pass;
R1–R11 stay zero. Earlier latch-only 552-test aggregate is superseded for the
connected summons change. Class contracts cover arrival disarming/reentry and
selective summons without waiving distance requirements.

No fix publication or deployment is performed. The reviewed patch is local at
`save-world-transition-507/save-world-fix.patch`; the perf PR remains at 7f279fd.
An old save already latched by the defective refusal cannot be distinguished
from intentional arrival protection: leave/reenter once for that old state.
Full campaign/cut/artistic acceptance and the refusal voice line remain open.
The ongoing headless performance goal continues after this focused repair.

## Sequence 506 — perf-model-prefetch-overlap — retained locally; integrated and aggregate verified

Move the optional model preparation hint after collision admission and before
renderer world admission, then advance existing model-image jobs between world
admission phases. Keep three slots, all input/pixel bounds, model registration
order and owner-thread GPU admission. Add explicit client init-error cancellation
and a generic renderer error-cleanup hook before engine longjmp; format error text
before releasing its possible borrowed inputs. Prediction: overlap the observed
180 ms first-model wait with useful world work, reducing complete save readiness
without more resident memory than justified by the gain. Earlier overlap can
increase world/model contention and peak RSS; both require measurement. The
sequential fresh-cache build and frozen runtime are prepared; headless native UI
qualification is running. No performance gain is accepted yet. Evidence:
`zig-out/reports/perf-model-prefetch-overlap-506/`.

Final evidence: twelve fresh-process loads reduce median arrival readiness
3.175 -> 3.068 seconds and autosave 3.520 -> 3.369; preserve the 3.792-second
candidate arrival outlier. First-model waits fall 194/206 -> 0/0 ms, total model
waits 410/417 -> 207/203 ms; all eight model names/order and restored state match.
Native UI intro/e1m1a/two saves, cache-off Vulkan and optional-hint OpenGL2 pass,
with complete images, clean ordinary validation and preserved original inputs.
One aggregate passes 57/57 steps, 550/550 native contracts plus C contracts and
383 Python tests with the pinned interpreter/dependencies verified.

An independent twelve-process block uses a different owner profile: resident
worlds changed from zero to one between blocks. Each block's arms share one
verified profile hash throughout; retain recovered immutable copies and never
pool the different workloads. In the resident-enabled block, arrival readiness
4.128 -> 3.981 seconds; autosave 4.585 -> 4.283. Arrival RSS median falls 16096
KiB; autosave rises 21416 KiB. CPU is mixed, and one autosave pair regresses.
Initial RSS medians fall 6596/10348 KiB. Three slots and per-slot bounds stay
unchanged; earlier overlap still has a real resident-workload memory tradeoff.
Retain the modest loading gain in both settings without confidence/tail claims.

The older frozen demo first fails RuntimeMismatch because src/client.zig is
included in the conservative native rules hash. Preserve that failure. A separate
correctness-only copy changes only recorded dk3-zig version literals in native
modules; all differing offsets/hashes are recorded, and the renderer is exactly
the production candidate. Classic/Neutral/AgX TGA/private RGB match exactly and
resize admission/dimensions pass. This is limited diagnostic pixel evidence,
separate from unmodified native UI/runtime acceptance and all timing. Production
version checks remain intact. The owner-reported Greece issue is not closed by
these loading results; focused transition diagnosis follows as 507.

Qualified changes through 503 were committed as `7f279fd` and pushed to the perf
branch; PR 14 now records matched gains, resource costs and rejected experiments.
This newer experiment remains local and the continuous optimization loop is active.

## Sequence 505 — perf-weather-cache-read — rejected; qualified 503 restored

Test the cached validity flag before unpacking the whole basis. An empty state
returns the original WeatherParams eye position and zero color; state construction
guarantees these values whenever has_position is false. Keep all-weather coverage,
64-byte format, arithmetic and counts. Compare qualified 503, eager 504 and this
505 reader in balanced three-arm frame trials, then compare fresh loads against
503. Exact images and unchanged visible work remain required. Evidence:
`zig-out/reports/perf-weather-cache-read-505/`.

Exact rain/private RGB and both snow views pass, but balanced three-arm trials
do not support retention. Pooled frame-average median is 51.26 ms for qualified
503 versus 51.87 ms for 505; CPU per 384 frames is 135.51 versus 138.19 seconds.
Twelve fresh loads are mixed: arrival readiness 3.119 -> 3.219 seconds, autosave
3.470 -> 3.370, with more resident memory. Reject both all-weather basis-cache
variants 504/505. All six affected renderer source files are restored byte-for-byte
to qualified 503; failed experiments remain local evidence, not shipped changes.

## Sequence 504 — perf-weather-basis-cache — not selected; qualified fallback remains 503

Cache one full-precision basis in four vec4s (64 bytes) per particle and expand
the original corner formula in main draws. The shared packed shader type and
native extern mirror define the layout. Extend preparation to all visual styles;
inline variants remain 0..2, prepared main variants add three to the same base
style. Bind the corresponding specialized preparation pipeline per draw. Preserve
the invariant clip dependency, capability fallback and whole-draw capacity fallback.
Scratch is capped at 24 MiB/frame and uses remaining stream capacity; later CPU
allocations can still grow the ring in other scenes, so measure real growth/RSS.
The fixed scene needs 389180 * 64 = 24.90752 MB plus normal stream data and fits
the existing 24 MiB chunk. Build 90/90 passes. Classic/Neutral/AgX images and
private RGB match exactly; the first authored snow view matches. Actual coverage
is all 389180 particles in eighteen preparation draws with no stream growth in
the held scene. Further snow, frame/load and fallback/resource validation remains
in progress. Qualified frozen 503 is the fallback. Evidence:
`zig-out/reports/perf-weather-basis-cache-504/`.

Both snow views pass. Three paired frame processes do not support admission:
pooled frame-average median 52.22 -> 55.64 ms, CPU per 384 frames 134.18 ->
134.59 seconds. Keep the 69.90 ms baseline process median/outliers; one noisy
baseline improves the candidate comparison but the other pairs do not. Twelve
fresh loads are near neutral: arrival readiness 3.269 -> 3.272 seconds, capture
3.423 -> 3.475; autosave readiness 3.422 -> 3.470, capture 3.674 -> 3.673.
RSS increases about 40 MiB relative to 503. Reject this eager reader as a frame
optimization and investigate unnecessary per-corner state loads with 505; no
loading gain or all-weather performance improvement is claimed.

## Sequence 503 — perf-weather-vertex-preparation — retained; integrated and aggregate verified

The guarded CPU device supports vertex storage writes; vertex subgroup operations
are unavailable, so do not assume corner lanes can broadcast shared values. Test
one rasterizer-discard vertex pass per splash particle, shared basis/corner math
and cached main draws. Keep the original inline fallback for unsupported devices
or bounded scratch exhaustion. Target the measured repeated splash work while
keeping the vertex stage used for procedural arithmetic. Require exact pixels,
explicit preparation coverage, bounded memory, complete loading and repeated
whole-frame endpoints. Qualified frozen 502 is the fallback; implementation is
unverified. Evidence: `zig-out/reports/perf-weather-vertex-preparation-503/`.

Connected implementation builds 90/90. First validation exposes the point-list
PointSize requirement and depth setters issued after binding a discard pipeline
without depth state; both are repaired before measurements. Clean v2 still has
the identical 171-pixel mismatch from 500, disproving a stage-only explanation.
V3 connects the shared basis/corner values to invariant gl_Position using the
actual clip transform: Neutral TGA returns to the golden 5794386f..., private RGB
matches exactly, all 155975 splashes prepare in seven draws and validation is clean.
Classic, AgX and both authored snow views also match exactly. Resize admission,
dimensions and validation checks pass.
No performance result is admitted until loading and scratch/feature fallback
checks complete. Initial three paired processes: median 128-frame average
60.06 -> 51.08 ms, CPU per 384 frames 153.28 -> 133.46 seconds; all paired CPU
values improve. Candidate has seven additional preparation draws, 12.478 MB scratch
per frame (16 MiB cap), stream 101 -> 12287 KiB and records 386 -> 392 KiB, with no
stream/record growth. Visible world/entity/UI/particle work must stay equal after
accounting separately for preparation. Resident memory and cold-loading costs
remain under measurement; the qualified fallback is still frozen 502.

Final admission: three paired frame processes and twelve fresh loads pass. Arrival
readiness 3.070 -> 3.120 seconds, capture 3.273 -> 3.273; autosave readiness
3.370 -> 3.370, capture 3.625 -> 3.623. Loading is near neutral; all saves preserve
their admitted state and original inputs. Peak RSS rises 33220 KiB / 23808 KiB for
the two saves (about 32 / 23 MiB), acknowledged despite no GPU-buffer growth.
Density-two capacity diagnostic preserves all 711520 weather particles and exact
pixels: 180224 of 278528 splashes prepare, 98304 fall back inline, with five prep
draws and no stream growth. A logical-device build with vertex stores disabled
renders exact Neutral/private RGB and resizes with zero preparation; this tests
the fallback, not another physical GPU. Normal source/native files are restored
to frozen v3. Restoration rebuild differs only in nonallocated .debug_line;
allocated ELF sections match, both artifacts are preserved and the exact frozen
binary is restored. Final UI/intro/e1m1a/two-save checks pass. One aggregate passes
57/57 steps, 550/550 native contracts and 383 Python tests with pinned environment.
Admit the measured 15.0% frame-average / 12.9% CPU gain for this software fixture;
physical GPU performance, tails/confidence and additive whole-PR gains remain
unverified. Qualified runtime: `perf-weather-vertex-preparation-503/runtime-v3`.

## Sequence 502 — perf-weather-integer-division — retained; integrated and aggregate verified

Replace runtime particle/tile quotient and remainder operations with multiply-high
and one exact correction using per-draw CPU reciprocal metadata. For n < 262144
and divisor <= 65536, ceil(2^32/d) gives the correct quotient or one too large;
the correction product cannot overflow. Unit divisors return n. Append one aligned
uvec4 to weather parameters and refresh near-rain metadata after its tile changes.
No floating-point particle formulas change and shader int64 is not required.
Actual helper versus built-in GPU quotient/remainder passes 33,554,400 comparisons
in 128 dispatch cases, including repeated boundaries: all numerators for sixteen
representative divisors, every divisor at quotient boundaries, random pairs and
partial workgroups. Outputs complete, bytes match, validation is clean. This is
component conformance, not a performance claim or proof of engine parameter ABI.
Source is implemented while 501 confirmation uses its immutable runtime; development
binaries remain 501 until a new build. Require actual engine images and endpoints
before admission. Evidence: `zig-out/reports/perf-weather-integer-division-502/`.

Both frozen modules contain their verified compiled vertex bytes. Variable tile
quotient/remainder pairs become two UMulExtended operations; remaining / and %
are constant corner-index operations. Capabilities are unchanged. Exact Classic,
Neutral, AgX, private RGB, resize and two authored snow views pass. Across six
paired processes per arm, 36 logical work records match: median 128-frame average
64.24 -> 59.00 ms, ranges 58.81–96.98 / 56.71–92.36. Independent confirmation is
64.35 -> 61.11 ms; five paired frame medians improve. CPU per 384 frames is near
neutral: 138.67 -> 138.20 seconds, ranges 136.42–162.28 / 132.97–146.03.
Keep all host-pressure variation/outliers; no confidence or tail claim. Independent
elapsed time confirms the intervals. All 58 threads stay stable in confirmation;
their CPU sum matches the process counter within 0.1 second. Runnable-delay
duration is unavailable because kernel scheduler-wait accounting is disabled.

Twenty-four fresh-process loads preserve state and complete image admission.
Initial autosave readiness regresses 3.270 -> 3.520 seconds; independent confirmation
is 3.771 -> 3.775, so the larger regression does not repeat. Combined arrival
readiness is 3.196 -> 3.269 (capture 3.374 -> 3.446); autosave 3.598 -> 3.623
(capture 3.825 -> 3.875). These are mixed small loading tradeoffs, not a loading
gain. Metadata adds 16 bytes/draw, 288 bytes in the fixture; stream stays 101 KiB
with no growth. Final UI/intro/e1m1a/two-save validation and input preservation
pass. One aggregate checkpoint passes 57/57 steps, 550/550 native contracts and
383 Python tests with the pinned interpreter identity verified. Admit the software
frame gain; physical GPU behavior and an additive whole-PR speedup remain unverified.

## Sequence 501 — perf-weather-seed-cull — retained; focused verification passed

Move the existing splash h0.x > 0.7 rejection immediately after seed generation,
before terminal-speed exp. Rejected particles return exactly the same empty vertex;
survivors keep the original vertex-stage calculations. Qualified 499 is the frozen
baseline. Require exact images, unchanged logical work and useful whole-frame/load
results before admission. Evidence: `zig-out/reports/perf-weather-seed-cull-501/`.

Build 89/89, three rain modes/private RGB/resizes and both authored snow views pass
exactly. All eighteen work rows match. Initial frame median 61.60 -> 58.78 ms,
CPU per 384 frames 138.95 -> 138.87 seconds. Keep the broad baseline variation
(process medians 59.09, 61.60, 65.11 ms) and confirm with three more pairs before
claiming a gain. Twelve fresh-process loads complete admission and preserve state:
arrival readiness 2.967 -> 2.966 seconds, capture 3.170 -> 3.168; autosave readiness
3.269 -> 3.318, capture 3.471 -> 3.521. Fresh-load CPU medians 10.101 -> 10.021 /
11.451 -> 11.325 seconds. Source now also contains unbuilt 502 integration; current
501 confirmation continues exclusively with the frozen 499/501 prefixes.

Independent confirmation completes six paired processes per arm. All 36 work
records match; frame median 60.60 -> 59.43 ms (ranges 58.75–78.60 / 57.70–64.18),
CPU per 384 frames 139.885 -> 139.435 seconds (136.35–141.67 / 136.21–140.75).
Five paired frame medians improve, one regresses slightly. The second batch also
has a lower frame median. Keep every sample, including the 78.60 ms baseline
interval; variation overlaps and CPU is near neutral. Admit the modest software
frame improvement without confidence/tail or physical-GPU claims. The only source
change in this retained batch is the relocated seed guard, with no memory/API cost.
Qualified frozen 501 is now the fallback for integrated integer-division work 502.

## Sequence 500 — perf-weather-splash-compute — rejected; qualified 499 source restored

Move splash preparation to a compute dispatch using the same shared particle helper
for all four corners, then read positions/color in vertex specialization 3. Inline
specialization 2 remains the fallback. Scratch is capped at 16 MiB per frame and
uses only existing frame-stream capacity; allocation exhaustion keeps inline draws.
Rain/snow formulas, particle counts and fragment shading remain unchanged. Extend
roof-map synchronization to vertex/compute readers. Test exact images, actual
preparation coverage, memory behavior, whole frames and fresh loading before
admission. Qualified frozen 499 is the fallback; this source prototype is unverified.
Evidence: `zig-out/reports/perf-weather-splash-compute-500/`.

Reject at the first exact-image gate: 171 of 518400 pixels / 440 RGB channels
differ, maximum channel delta 59. All 155975 splashes prepare without stream-ring
growth. One-corner invocation and specialization-default variants produce the same
failed image. Split diagnostics implicate the position path: computed positions
with original color reproduce the full mismatch; inline positions with computed
color leave 300 differing channels. Moving clip transform/depth before storage
also leaves the identical full mismatch. This does not prove the exact driver or
floating-point cause. Preserve all failed images, binaries and source snapshots;
no speedup is admitted or timed before correctness. Restore every renderer source
hash to qualified 499, then implement the smaller same-stage experiment 501.
All compute preparation, ring API, new shader files, counters and barriers are
removed from working code; historical prototype descriptions above are not retained
implementation. Development binaries become 501 only after its build completes.

## Sequence 499 — perf-weather-uniform-samplers — retained; focused verification passed

Remove nonuniform descriptor markers only from the two draw-wide weather light-grid
indices and the roof-map slot passed to rainSurface. All originate in immutable
parameters/view through push.record. Coordinates, arithmetic, particle counts and
rainExposure are unchanged. Compare frozen rain/snow images and interleaved whole
frames against qualified 496 before admission; software Vulkan evidence only.
Evidence: `zig-out/reports/perf-weather-uniform-samplers-499/`.

Measurement scope for these frozen-render experiments: each frame_ms row is a CPU
monotonic average over 128 frames. Reported medians summarize these averages, not
individual-frame latency percentiles. Independent Python elapsed time over each
384-frame block agrees with the three-row mean within 0.06 ms/frame for 499 and
0.12 ms/frame for 501. Preserve whole-block comparisons in wall-timer-crosscheck.json.

Classic/Neutral/AgX rain TGA and private-screen RGB match exactly; resize checks and
two authored snow views pass under validation. Snow uses the previously qualified
fixed-noise correctness fixture only; normal timing has no RNG override. Initial
six-process results suggested a small frame gain with mixed CPU, so a second six
process batch independently confirms before retention. Across both batches, 36
measured work rows match: frame median 60.155 -> 59.220 ms, ranges 58.94–63.53 /
58.14–63.67; CPU median per 384 frames 140.575 -> 138.600 seconds, ranges
137.06–141.48 / 136.56–140.72. Four paired frame medians improve; two are nearly
neutral. Overlapping ranges and six pairs do not support tail/confidence claims.
Twelve fresh-process loads complete admission and preserve fixtures/state: arrival
readiness 2.922 -> 2.919 seconds, capture bound 3.125 -> 3.071; autosave readiness
3.225 -> 3.271, capture bound 3.428 -> 3.524. Keep the autosave tradeoff and all
samples, including baseline arrival readiness 3.677 seconds. No added modules,
features, memory or arithmetic. Shader build 89/89 and affected engine checks pass;
the unchanged native/Python aggregate from 496 is not rerun for these shader hints.

## Sequence 498 — perf-weather-cost — diagnosis verified; no source change

Measure particle cost before a larger per-particle compute/precomputation design.
Same qualified 496 binary/process/held demo: normal, no splash crowns, no particles,
normal restored; 32 warmup plus 96 measured frames per phase. Verify density=1,
splashes=1 and volumetric=0 first, so changing density does not remove froxel work.
Keep logical world/model/UI work fixed; particles change HDR/post inputs, so this
is a coupled removal upper bound, not isolated vertex cost or an admitted speedup.
Restore normal settings before ordinary exit and preserve all inputs. Evidence:
`zig-out/reports/perf-weather-cost-498/`.

Measured frame medians: normal 61.73 ms, no splashes 42.30 ms, no particles
23.57 ms, restored normal 60.68 ms. CPU seconds per 96 frames: 35.38, 33.54,
31.40, 35.14. Particle counts: 389180, 233205, 0, 389180; other logical work
remains fixed. Ordinary exit and source preservation pass. Wall savings roughly
match one CPU's work per frame, consistent with serialized critical-path weather
work; this does not isolate a particular shader instruction or driver cause.

## Sequence 497 — perf-taa-reset-loop — rejected; qualified 496 source restored

Guard only the original constant-bound halo-loading loop with uniform !reset,
keep the barrier unconditional, reconstruct current color once after the barrier
and bounds check, and return on reset before any shared-neighbourhood statistics
read. This avoids the duplicated Catmull-Rom code of rejected 493/495. Test whether
reset fetch/statistic savings survive without their normal CPU tradeoff. Normal
formulas/order/loop bound stay fixed; extra control flow may still carry a cost.
Baseline is qualified 496. Require actual shader output and component evidence
before native frame/load trials. Evidence: `zig-out/reports/perf-taa-reset-loop-497/`.
The loading loop is guarded by a dispatch-uniform reset flag, its original
constant bound is unchanged, and every invocation still reaches the barrier.
Reset returns after the single current-color reconstruction and before any read
of skipped shared data. Actual shader output and component comparisons are running;
the development binaries remain the qualified 496 version until a new build.
All 704 actual shader output cases pass with validation and output-written
checks. Twenty-four component trials: native normal CPU per 128 dispatches
8.672 →8.563 s, scaled normal 8.476 →8.506 s; native reset 5.380 →3.117 s,
scaled reset 5.312 →3.098 s. Wall medians normal 0.516 →0.510 / 0.525 →0.518 s,
reset 0.328 →0.195 / 0.317 →0.190 s. The reset CPU saving is about 42%, with
normal component results near neutral rather than a proven whole-game gain.
Build and matched native/scaled frame and native fresh-load trials follow against
qualified frozen 496; the scaled profile matches the already-qualified settings.
Build 89/89 and actual runtime/source identities are frozen; only the Vulkan
renderer differs from qualified 496. Native/scaled normal-frame and native fresh
loads now run sequentially. The working source/development prefix is this 497
prototype; 496 remains the verified fallback until endpoint admission is decided.
Endpoint evidence rejects the loop guard: six native processes give frame median
59.17 →60.03 ms and CPU per 384 frames 136.32 →140.09 s, about 2.8% more CPU.
Six scaled processes give 58.36 →56.50 ms but CPU 116.69 →117.47 s, about 0.7%
more CPU. Twelve native fresh loads are broadly neutral: arrival readiness
2.917 →2.967 s and autosave 3.270 →3.218 s. The component reset gain does not
justify a common-path CPU regression. Preserve all samples and restore 496;
no feature removal or rejected code is retained as a performance improvement.
Restoration build 89/89; current renderer source hashes and all nine development
runtime file hashes exactly match the qualified 496 snapshot. Its unchanged
integrated/scaled/aggregate checks therefore remain applicable without rerunning
the same suites.

## Sequence 496 — perf-taa-uniform-only — retained; integrated and aggregate verified

Test the remaining combination: original 492 shared neighbourhood and late
history-reset branch, with only known-uniform sampler annotations removed. The
three-way 495 results favor 492 for normal work, so isolate the annotation change
from early-reset control flow. Qualify actual outputs/component costs before
any native frame/load comparison. Evidence:
`zig-out/reports/perf-taa-uniform-only-496/`.
All 704 direct output cases pass with no validation errors. Native normal CPU
per 128 component dispatches 9.000 →8.997 s is effectively unchanged; scaled
normal 9.212 →8.646 s, about 6.1% lower. Native/scaled reset CPU 5.606 →5.394 /
5.622 →5.380 s. Wall medians normal 0.581 →0.585 / 0.597 →0.551 s, reset
0.381 →0.339 / 0.365 →0.340 s. Qualify actual native frames and a separate
forced-builtin 0.667-scale workload with identical configuration in both arms;
never attribute reducing render resolution to this annotation change. Native
fresh-load trials will check cold cost before final connected-batch selection.
Native build 89/89 and frozen runtime/source identities are recorded. The current
source is uniform-only 496, with late history reset; normal 492-versus-496 frame
trials, separate same-configuration builtin-scaled trials, and native fresh loads
were measured sequentially. Final selected-source integrated smoke and one aggregate
are recorded below; no TAA prototype has been published.
Twelve normal-quality frame processes (three pairs per native/scaled workload)
retain every timing/work row. Native frame median 60.90 →60.17 ms (ranges
59.74–63.44 / 59.53–63.90), CPU per 384 frames 139.98 →136.98 s (ranges
137.90–140.42 / 135.61–137.47), about 2.1% less CPU. Scaled frame median
58.90 →59.02 ms is neutral within variation; scaled CPU 118.79 →115.94 s
(ranges 117.80–121.07 / 115.29–118.75), about 2.4% lower. All six paired CPU
totals improve; this is software-only evidence, not a physical-GPU/tail claim.

Twelve native fresh loads: arrival readiness 3.067 →3.167 s and JPEG capture
3.269 →3.320 s; autosave readiness 3.318 →3.270 s and capture 3.521 →3.521 s.
Process CPU 10.221 →10.441 / 11.571 →11.447 s. Preserve the small arrival-load
tradeoff; no universal loading gain is accepted. Select shared tile plus uniform
samplers and late reset for common-path efficiency, excluding early-reset 493/495.
Final native integrated smoke, actual scaled-CVar qualification and one applicable
aggregate were then run before admission.
Final qualification passes native UI new-game/intro, e1m1a and both copied saves;
the scaled run explicitly reads active quality=6, scale=0.667, upscaler=0, TAA=1,
with 960×540 windowed output. GPU inputs are 640×360 as derived from the verified
window allocation code and settings. No validation errors, zero pending/failed
images, and all original saves/configuration remain preserved. One aggregate
passes 57/57 steps, 550/550 Zig tests plus C contracts and 383 Python tests using
the unchanged pinned virtual-environment interpreter path. Current source and all
nine development runtime files match the frozen qualified candidate exactly.
Admit 496; 493/495 early-reset implementations remain rejected alternatives.
New code stays local, with no Git or publication action.

## Sequence 495 — perf-taa-uniform-samplers — combined variant not selected

TAA sampler indices come only from dispatch-wide push constants, including the
Catmull-Rom slot arguments. Remove nonuniformEXT annotations from these known
uniform descriptor accesses, following the existing post-histogram pattern.
Preserve every coordinate/filter/arithmetic/control-flow expression and device
features. Test whether this permits cheaper descriptor handling; the driver may
already infer uniformity, so output equivalence alone does not establish a gain.
Compare actual SPIR-V, direct shader outputs and component costs before native
frame/load tests. Evidence: `zig-out/reports/perf-taa-uniform-samplers-495/`.
Compiled SPIR-V removes all NonUniform decorations and the two corresponding
capabilities, with no new capability requirement. The first preparation assertion
also exposes a log-capture boundary race in 494: one partial report has two work
rows because the wait returned at the third timing header before its statistics
line. The complete client log recovers all three measured work rows, identical
to every other sample; preserve the partial report and normalized evidence. Future
measurement capture waits for both timing and work rows. No frame/CPU sample is
discarded or changed by this recovery.
All 704 actual shader output cases match with no validation errors. Twenty-four
actual-component samples: native normal CPU per 128 dispatches 8.827 →8.765 s,
scaled normal 8.862 →8.504 s; native reset 2.681 →2.389 s, scaled reset
2.712 →2.414 s. Wall medians 0.517 →0.504 / 0.522 →0.513 s for normal and
0.161 →0.152 / 0.164 →0.156 s for reset. Record these as warm-input component
gains only. Rotating normal 492/493/495 frame/load trials will test the combined
choice; the repaired capture waits for all three work rows as well as timing rows.
Build 89/89; native UI new-game/intro, e1m1a and both copied saves pass under
validation, with original saves/profile preserved. Freeze actual modules and
renderer source hashes. Rotating 492/493/495 normal frame/load measurements are
in progress; no full-frame or cold-load gain is admitted from component data alone.
Nine processes retain all 27 work rows with the repaired wait. Frame medians
492 / 493 / 495: 60.73 / 62.00 / 61.84 ms; CPU per 384 frames 137.21 / 139.90 /
139.79 s. Eighteen fresh loads: arrival readiness 3.072 / 3.118 / 3.069 s,
autosave 3.470 / 3.472 / 3.419 s. The combined variant does not recover 492's
normal CPU advantage; do not select it from the component gain. Preserve all
three-way outcomes and test uniform access alone as sequence 496. No broad check
is repeated while the connected TAA batch's source selection is pending.

## Sequence 494 — perf-taa-reset-confirmation — measured tradeoff confirmed

Independently repeat the frozen 492/493 comparison because component, full-frame
and loading results disagree. Three interleaved process pairs for normal frames
then three pairs per fresh save, keeping both blocks and every sample. No source
change or rebuild; compare actual binary/input identities. Evidence:
`zig-out/reports/perf-taa-reset-confirmation-494/`.
Second six normal-frame processes: median 60.59 →60.66 ms, CPU 137.83 →140.67 s
per 384 frames. Second twelve fresh loads: arrival readiness 3.069 →2.971 s,
autosave 3.369 →3.219 s; process CPU 10.285 →9.918 / 11.252 →11.193 s. Loading
benefit repeats while normal CPU remains a tradeoff; no isolated cause or universal
speedup is claimed. Keep all block-specific outcomes and test the known-uniform
sampler follow-up before final connected-batch selection.

## Sequence 493 — perf-taa-reset — measured tradeoff; admission deferred

Move the dispatch-uniform history-reset branch before shared neighbourhood loads
and barrier. Reset output uses only original current-color reconstruction; every
invocation returns through this uniform branch, with output bounds checked inside.
Leave the normal temporal path unchanged. Test exact shader outputs, reset and
normal component timings, then whole-frame/loading outcomes before admission;
additional control flow/code layout may carry costs. Evidence:
`zig-out/reports/perf-taa-reset-493/`.
Build 89/89; the actual 492/493 SPIR-V outputs match in all 352 native-half and
352 float32 cases with validation and output-written checks. A separate actual
shader component experiment measures normal/reset modes: native/scaled fixed HDR,
depth, history and motion inputs; eight warmup and 128 measured dispatches, three
interleaved pairs per mode. Process CPU and wall include command recording,
dispatch dependencies and one readback, with first-use compilation outside the
measured samples. This is component evidence; complete game frames/loads remain
required before admission.
All 24 interleaved component samples complete: native reset CPU per 128
dispatches 5.653 →2.681 s, wall 0.350 →0.173 s; scaled reset CPU 5.785 →2.728 s,
wall 0.393 →0.199 s. Normal-history native CPU 8.946 →9.013 s and scaled
9.160 →9.065 s; wall 0.548 →0.557 / 0.610 →0.599 s. Roughly half the reset
CPU is removed, while normal component results are mixed around one percent.
These fixed warm-input component results do not establish whole-game gains.
Freeze renderer/source identities and measure normal frames and complete loads.
First six normal-frame processes give medians 62.36 →64.46 ms and CPU
142.91 →144.37 s per 384 frames; ranges 61.11–66.80 / 60.88–69.43 ms and
139.88–144.20 / 138.12–145.05 s show substantial variation. Two process frame
medians improve, the third worsens. Twelve fresh loads favor the candidate:
arrival readiness 3.118 →3.017 s, autosave 3.930 →3.369 s; process CPU medians
10.336 →10.257 / 11.884 →11.287 s. Component reset savings alone do not explain
the loading difference. Preserve this block and confirm independently before
choosing between shared-neighbourhood 492 and early-reset 493.

## Sequence 492 — perf-taa-neighborhood — retained for connected follow-up

Test shared reuse of current-color/depth neighbourhood samples: an 8×8 group
currently performs 576 fetches from each texture; its 10×10 neighbourhood needs
100 from each. A shared vec4(YCoCg, depth) tile costs 1,600 bytes plus a barrier.
Preserve integer clamping, color conversion/accumulation order and depth ties;
barrier precedes out-of-range return. Qualify native/scaled extents, jitter and
partial groups, with actual deterministic history/motion shader-output equivalence
before timing. Software shared-memory/barrier overhead may defeat the benefit.
Keep full temporal behavior; compare normal loads and equal-work frames against
frozen 489. Evidence: `zig-out/reports/perf-taa-neighborhood-492/`.
The shader now loads the shared tile, synchronizes every invocation before
out-of-range return, and reads the same 3×3 samples in the original order.
A local CPU-Vulkan harness executes the actual baseline/candidate SPIR-V on
identical synthetic HDR, depth, history and motion textures. Initial 256 cases
(eight extents/scales × sixteen jitter phases × reset/nonreset) match all native
half-float output bytes. Expanded edge/full-resolution and float32 output checks
run with validation before normal-quality integrated timing. Diagnostic harness
code/binaries and test inputs remain local; no original game data is included.
Expanded direct comparison passes 352 native-half and 352 float32 output cases
with zero differing bytes and no validation errors, including full resolution,
partial groups, native/scaled and 3×3-output/1×1-input edges. Every output alpha
is checked to catch unwritten results. Preserve the earlier diagnostic-only
float32 buffer-offset alignment failure; fixed 16-byte region alignment, host
visibility barrier and output-written checks qualify the final harness. Integrated
build 89/89. Freeze candidate identities, unchanged engine/game modules and all
renderer source fingerprints; equal-work normal-quality timing is running.
Six normal-quality processes, 64 warmup plus 384 measured frames each, retain
all 18 logical work-count intervals. Frame median 63.57 →61.41 ms (ranges
60.58–67.22 / 60.07–63.16), about 3.4% lower; CPU per process 145.24 →140.40 s
(ranges 140.46–146.95 / 138.04–141.11), about 3.3% lower by median. Paired CPU
deltas −8.91/−4.84/+0.65 s show variation; no uniform per-run gain is claimed.
Twelve normal fresh-process save-loading trials now check for cold regressions;
record compute-pipeline calls as context without treating their wall time as
isolated compiler CPU. Admission remains pending those results.
The twelve loading processes pass: arrival readiness 2.917 →2.918 s, autosave
3.225 →3.176 s; process CPU medians 9.931 →9.730 / 11.255 →11.018 s. No material
cold regression is observed; ranges overlap and no universal loading gain is
claimed. Keep the change and freeze it as the sequence-493 reset-path baseline.
Final integrated smoke and aggregate checks follow the connected TAA batch.

## Sequence 491 — perf-taa-cost — diagnosis complete; no source change

Cross-check the reported roughly 5 ms temporal-resolve interval against actual
whole-frame CPU/wall cost before implementing neighbourhood tile reuse. Same
retained-489 binary/process/demo, TAA on/off/on with 32 warmup plus 96 measured
frames per phase. Assert logical world/model/weather/UI work identity and restore
TAA before ordinary exit. Jitter and history also change, so this is a coupled
upper-bound diagnostic, not isolated resolve time or a feature-off optimization.
Evidence: `zig-out/reports/perf-taa-cost-491/`.
Frame medians on/off/on are 61.56 / 53.85 / 59.13 ms; CPU per 96 measured
frames is 34.91 / 26.67 / 34.65 s. All logical work counts remain identical,
including 442 draws, 268 UI quads and 389,180 particles. TAA is restored before
ordinary exit (guard status 0), validation is clean and sources are preserved.
The roughly 23% CPU drop establishes a material coupled cost, not an isolated
resolve percentage or an accepted gain. Next test neighbourhood reuse while
preserving temporal behavior; do not retain disabled TAA.

## Sequence 490 — perf-weather-kind — rejected; selected vertex-only source restored

Specialize rain versus snow in both weather stages, while preserving dynamic
rain/splash selection from the original parameter. One rain pipeline now covers
streaks, near-camera drops and splash crowns, matching the original PSO count.
Particle counts, formulas, buffers and module count remain unchanged. Test whether
this retains the vertex saving with lower cold cost than sequence 489; compare
retained 485, frozen vertex-only 489 and the new candidate under rotating trials.
Evidence: `zig-out/reports/perf-weather-kind-490/`.
Build 89/89. Three rain output modes, normalized private-screen RGB and two
resolution restarts match exactly. Both authored snow views match the qualified
fixed-noise retained-485 references; fixed noise remains correctness-only.
Eighteen loading processes give 485 / vertex-only / kind-only arrival readiness
2.920 / 2.971 / 2.970 s, autosave 3.417 / 3.219 / 3.221 s. Arrival candidate
paired deltas +0.302/+0.001/+0.000 s; autosave −0.403/−0.249/+0.003 s. No
universal loading gain is claimed. Nine equal-work rendering processes retain all
27 work-count intervals: frame medians 63.88 / 60.31 / 63.15 ms and CPU medians
146.15 / 141.76 / 141.99 s per 384 frames. The kind-only prototype saves CPU
but gives up most of the vertex-only frame benefit; its loading results do not
justify selecting it instead. Restore sequence-489 sources, build 89/89, and
verify their fingerprints against the frozen qualified runtime.

Across both independent 489/490 blocks, six processes per retained-485/selected
arm measure 2,304 frames each: frame medians 63.88 →60.36 ms (ranges 62.40–67.17 /
58.88–64.21), about 5.5% lower; CPU medians per 384 frames 145.99 →142.39 s
(ranges 143.73–146.42 / 140.13–144.86), about 2.5% lower. All six paired CPU
totals and all six process frame medians improve. Small software-only samples;
loading is broadly neutral/mixed, and no physical-GPU or tail claim is made.

Final selected-source UI smoke passes new-game/intro, e1m1a and both copied saves,
zero pending/failed images, no Vulkan errors, preserved original saves/profile.
One applicable aggregate passes 57/57 steps, 550/550 Zig tests plus C contracts,
383 Python tests with the original pinned virtual-environment interpreter path.
New specialization changes remain local; earlier published PR contents are unchanged.

## Sequence 489 — perf-weather-vertex-style — rendering gain confirmed; selected for follow-up

Keep sequence-488 typed particle style and vertex specialization, but restore the
original common weather fragment implementation. Test whether the vertex change
retains the measured frame benefit while avoiding duplicated cold fragment work.
Pipeline-call wall totals differ by only a few milliseconds and do not explain
the whole-load regression; compiler/cache reuse remains a hypothesis. Compare
retained 485, frozen 488 and this candidate with strict images and normal-quality
loading/rendering measurements. Evidence:
`zig-out/reports/perf-weather-vertex-style-489/`.
Build 89/89; classic/Neutral/AgX rain TGA/private-Xvfb RGB and two resolution
restarts pass. The initial snow view also proves vulnerable to process-random
sky lightning: retain its first failed comparison, then qualify both snow views
with fixed noise for image diagnostics only. Two initial-view baseline processes
and the candidate match exactly, as does the candidate against the previously
repeated rotated-view fixed-noise baseline. The timing controller asserts the
diagnostic preload is absent before running the normal three-arm measurements.
Eighteen fresh processes: arrival readiness medians 2.868 / 2.917 / 2.969 s for
485 / both-stage 488 / vertex-only 489, with overlapping ranges; autosave
3.170 / 3.170 / 3.167 s. Arrival CPU medians 9.979 / 9.934 / 10.005 s; autosave
11.384 / 11.291 / 11.155 s. Retain both this block and the earlier 488 loading
regression rather than assigning a universal cold-load conclusion.

Nine rendering processes, three per rotating arm, each warm 64 and measure 384
frames. All 27 intervals match work counts. Median frame intervals are
63.88 / 61.17 / 60.59 ms; process CPU medians 145.83 / 144.64 / 143.02 s.
Vertex-only has about 5.2% lower median frame time and 1.9% less CPU versus 485;
all three paired CPU values are lower (−5.70/−3.40/−0.37 s). Observed CPU ranges
144.94–146.42 / 140.13–144.57 s. These are software-only small-sample results,
not physical-GPU or tail claims. Select vertex-only for the next comparison;
aggregate admission waits for the connected specialization batch to settle.

## Sequence 488 — perf-weather-style — measured rendering benefit; admission deferred

The CPU already knows rain, snow and splash style when constructing each weather
draw. Test a typed style passed through the existing pipeline variant to specialize
both weather stages, removing irrelevant style branches from each compiled path.
Keep original formulas, data and module count; do not retain sequence-487 culling.
Additional pipelines may increase cold cost, so require loading and equal-work
render measurements, strict rain images and the two new authored snow fixtures.
Evidence: `zig-out/reports/perf-weather-style-488/`.
The owner resumed the loop. A typed Style travels through Draw and Mesh into
the existing pipeline variant; both weather shader stages specialize constant 0.
No new modules or buffers are introduced. Original formulas and dynamic params
remain unchanged; the comparison baseline is the retained sequence-485 runtime.
Build 89/89 and strict rain classic/Neutral/AgX TGA/private-Xvfb RGB, two
resolution restarts, and the initial snow view pass. The rotated snow comparison
first fails against its historical image; unchanged baseline replay also fails.
Inspection identifies randomized sky lightning: Com_InitRand seeds libc rand
from OS randomness, R_NoiseInit consumes it, and the authored sky has a noise
waveform. A diagnostic-only fixed-srand preload makes two baseline runs and the
candidate byte-identical, including the visible flakes. Preserve the initial
failures; the override is excluded from normal performance runs. Sources remain
preserved, validation reports no new errors. Twelve normal fresh-process loading
trials give arrival readiness 3.221 →3.429 s, CPU 10.540 →11.177 s; autosave
3.624 →3.624 s, CPU 12.152 →12.153 s. Arrival paired deltas −0.051/+0.308/+0.202 s;
autosave +0.150/−0.001/+0.148 s. No loading gain is accepted.

Six equal-work rendering processes measure 64 warmup plus 384 frames each.
All 18 intervals retain identical draws/UI/particles/indices. Frame medians
64.12 →60.17 ms (ranges 62.84–65.61 / 59.12–63.75), about 6.2% lower. Process
CPU medians 144.67 →143.12 s (ranges 144.47–147.63 / 139.68–143.57); all three
paired candidate CPU totals are lower. This is a software-only rendering benefit
with an observed loading tradeoff, not an admitted whole-task improvement. Keep
the frozen candidate and test vertex-only specialization next before selecting
retained source. OS page cache is uncontrolled; all samples remain recorded.

## Sequence 487 — perf-weather-distance — rejected; source reverted

Return before lighting, gust and corner construction when the existing distance
fade already makes the entire particle transparent. Rain endpoints are ≤4 or
≥800 units, snow ≤8 or ≥2000, splash crowns ≥800. Named shader constants are
shared with the original fade expressions; no fade curve or visible-particle
equation changes. The first version keeps roof rejection in its original order.
Weather uses source-alpha blending, no depth writes and no motion-attachment
writes; alpha zero contributes nothing to color/HDR alpha. Existing out-of-bounds
particles use the same invisible degenerate-vertex return. Build 89/89; exact
classic/Neutral/AgX frozen TGA and private-Xvfb RGB pass, including two resolution
restarts. Real episode-three e3m1a snow snapshots match exactly at the initial
and rotated view, with 6,720 / 2,112 submitted particles. New immutable demos and
golden images are retained for future weather verification. These are renderer
diagnostics, not episode/campaign acceptance.

Six repeated rain processes retain identical work counts. Frame median
65.77 → 65.14 ms overlaps widely; CPU per 384 measured frames 147.68 →145.72 s
(observed ranges 146.77–150.28 / 144.61–145.85), about 1.3% less CPU. Twelve
fresh-process, completed-menu loading comparisons show arrival readiness
3.018 →2.974 s but autosave 3.270 →3.423 s; all three autosave pairs are slower.
Autosave CPU medians 11.302 →11.918 s. Reject this small rendering-CPU/cold-load
tradeoff, preserve every sample and revert the guard/constants. No specific
shader-compilation cause is proved by these timings. Evidence:
`zig-out/reports/perf-weather-distance-487/`.

## Sequence 486 — perf-ui-cost — diagnosis complete; no batching admitted

Measure actual 2D submission cost before adding batching complexity. A temporary
renderer-only normal/skip/normal diagnostic on the same held demo will compare
whole-frame CPU/wall intervals while retaining world/model/weather work counts.
The controlled same-binary normal/skip/normal phases each warm 32 frames and
measure 96. Frame medians 63.47 / 69.23 / 64.96 ms; CPU 35.69 / 36.37 / 36.08 s.
Draws change 442 →174→442 while world/model/weather counts remain identical,
including 389,180 particles. Removing all 268 2D draws does not show a material
CPU saving in this fixture. The slower skip phase does not prove UI accelerates
the engine; scheduling/state effects are not isolated. Do not add batching based
on draw count alone. Restore normal drawing before ordinary exit, verify source
preservation, and remove the diagnostic cvar/branch from current source.
Evidence: `zig-out/reports/perf-ui-cost-486/`.

## Sequence 485 — perf-display-fragment — startup improvement retained; correctness and aggregate checks verified

Broaden the narrow fragment contract from 2D-only to all matching display-space
stages: classic target, no prepass/prepassed state, debug view off, no secondary
texture and no flags except optional opaque overlay. The original fragment then
has exactly the same texture × vertex-color result, alpha rejection and opaque
override regardless of geometry kind. All vertex, depth and blend behavior stays
shared. The shader/program are named for display composition, not a UI-only limit.

Add optional `--settled-menu` to the loading probe: capture a completed menu frame
before loading and report its capture upper bound separately from the earlier
native-initialization event. Each load also records launch-to-ready time. This
separates initial menu JIT from subsequent save/map admission; screenshots include
readback/JPEG overhead. Historical workloads remain unchanged by default.
Eighteen three-arm, rotating fresh processes compare the original baseline,
UI-only 483 final and broadened candidate on both saves. Across six identical
startup workloads per arm, menu capture medians are 1.107 → 1.056 → 0.956 s;
the broadened candidate improves five of six paired captures, about 13.7% by
median. Ranges overlap (baseline 0.857–1.157 / candidate 0.705–1.058 s); these
include readback/JPEG and do not measure an exact first-present timestamp.

Subsequent warmed-menu save admission is broadly neutral: arrival 3.324 → 3.323 s,
autosave 3.674 → 3.622 s, with overlapping ranges. Launch-to-admitted-save medians
(including the menu capture) are 4.429 → 4.180 / 4.678 → 4.577 s. Whole-process
CPU medians are 11.148 → 10.542 / 12.583 → 12.071 s; retain all samples and avoid
per-frame or population/tail CPU claims from these unconstrained loading frames.

Six equal-work held-scene processes measure 64 warmup plus 384 measured frames
each. All 18 reporting intervals match 442 draws, 268 UI quads and 389,180
particles. Whole-frame median 64.89 → 65.02 ms; CPU per measured process
144.14 → 145.10 s, both with overlapping ranges. No rendering throughput gain
is accepted. Retain the small display path for its measured startup benefit.
Private Mesa caches start empty per process; OS page cache remains uncontrolled.
These are headless software results, with no physical-GPU or Windows execution claim.

Build 89/89. Classic/Neutral/AgX frozen TGA and normalized private-Xvfb RGB match
the unchanged baseline exactly, including matching real menu JPEG hashes across
arms. Two resolution restarts and the integrated UI new-game/intro, e1m1a and both
copied saves pass with zero pending/failed images, preserved sources and no Vulkan
validation errors. General-path unused-motion-output warnings remain pre-existing.

Final aggregate: 57/57 steps, 550/550 Zig tests plus C contracts, 383 Python tests.
Retain the initial missing-dependency and fixture failures. Install only declared
pinned test dependencies in a local virtual environment; preserve its interpreter
path rather than resolving its symlink into the global interpreter. The release
fixture now provides/verifies runtime notices, runtime-media uses real valid asset
fixtures instead of its obsolete validator mock, and the Rich terminal test sets
a non-dumb TERM while simulating live output. Production installer behavior is
unchanged. Publication uses the separate performance branch and PR #14,
independent of co-op PR #13; local benchmark artifacts remain excluded. Evidence:
`zig-out/reports/perf-display-fragment-485/`.

## Sequence 484 — perf-ui-contract — actual fallback captured

The first general classic-fragment pipeline before map load comes from native
`Art.render` through UI scene rendering: MD3 geometry, two_d=false, menu icon
`dkq3/menu/ib_singleplay`. Optimized DWARF omits the record pointer, so its flags
and secondary slot are not directly observed; new eligibility must check actual
record fields. The first debugger script crashes GDB after deleting its own
breakpoint in a stop callback. Retain that failure; the repaired frame walker
defers deletion, captures the real contract and passes ordinary copied-save
replay with preserved sources. No engine source changes in this diagnostic.
Evidence: `zig-out/reports/perf-ui-contract-484/`.

## Sequence 483 — perf-ui-fragment — verified prototype; superseded by broader contract

Single-texture display-space UI stages with no flags except optional opaque
overlay select a narrow fragment program. All other stages retain the existing
general material program. Vertex generation, texture sampling, blend state and
alpha comparisons remain unchanged; alpha rejection lives once in common.glsl.
The smaller fragment consumes only color and UV, rather than world/lighting/motion
varyings. Debug view uses the general path. Build 89/89; prototype and cleaned
final shader both match classic/Neutral/AgX TGA and private-screen RGB exactly,
including two renderer resizes. Remove the UI motion output and explicitly
require a classic target; general-path unused-motion warnings are pre-existing.

Initial three autosave pairs show readiness 3.970 → 3.731 s and CPU 11.581 →
10.747 s. The twelve-run final confirmation is mixed: arrival readiness
3.625 → 3.519 s, CPU 10.158 → 9.569 s; autosave readiness 3.769 → 3.922 s, CPU
11.319 → 10.854 s, with a 4.381 s candidate outlier retained. These start at the
native-menu-initialized event, before its first completed frame; no warmed-menu
loading or stable autosave latency gain is accepted. The actual menu MD3 fallback
motivates the broader sequence-485 contract and separated startup measurement.
Evidence: `zig-out/reports/perf-ui-fragment-483/`.

## Sequence 482 — perf-static-vertex — rejected; source reverted

Specialize the existing vertex shader for batches whose geometry kind is already
known to be static. Vertex constant 1 folds only MD3/IQM fetch and previous-pose
branches; all static vertex data, deformation, UV, color, clipping and motion
equations remain shared and unchanged. The pipeline key carries that invariant
for both depth and shading passes. Dynamic model batches keep the existing path.
Build 88/88, exact classic/Neutral/AgX TGA and private-screen RGB, two renderer
resizes, validation/ordinary exit and source preservation pass. Three alternating
fresh-autosave pairs regress readiness 3.770 → 3.971 s; CPU 11.214 → 11.134 s has
overlapping ranges, and candidate RSS rises about 16 MiB. No gain is admitted;
revert the specialization and extra pipeline-key variants. Rendering throughput
is not separately benchmarked for this rejected loading regression. Evidence:
`zig-out/reports/perf-static-vertex-482/`.

## Sequence 481 — perf-pipeline-overlap — diagnosis verified; prototype reverted

Move first-use creation of the unchanged swapchain composite pipeline before scene
submission, with explicit begin/end markers. This tests whether the original
pipeline-call wall timer includes waits for deferred driver work from earlier UI
draws. Relocating a timer is not an optimization claim. Only window host-call
ordering changes. Build 88/88 and four fresh-save processes pass state, image
admission and source preservation. The unchanged copy PSO takes 367.749/464.245 ms
after scene submission versus 1.715/2.519 ms before it. Readiness does not improve
(two-run medians 3.698 → 3.847 s), nor total CPU (10.908 → 11.192 s). The large
call timer is not an isolated copy-shader cost: preceding software work/order can
dominate it. Precise backend synchronization is not isolated. Revert the ordering
prototype and add this observation limit to the machine-local perf skill; admit
no optimization from the relocated timer. Evidence:
`zig-out/reports/perf-pipeline-overlap-481/`.

## Sequence 480 — perf-copy-descriptor — rejected; source reverted

Actual sequence-479 stacks motivate testing a single sampled-image descriptor for
display copies, in place of dynamic access through the global bindless array.
The proposed mechanism is broader sampler/format variant compilation; it remains
a hypothesis. Neither smaller fragment input experiment changed descriptor access.
The prototype uses one sampled-image descriptor per persistent scene/final target,
a dedicated copy pipeline layout and the original nearest/linear clamp samplers.
Descriptors are released after idle, before image views; layouts outlive pipelines.
Build 89/89. Classic/Neutral/AgX TGA and private-Xvfb RGB match the unchanged
baseline exactly. Validation and ordinary exit pass; 960×540 → 800×450 → 960×540
renderer restarts capture correct dimensions without validation errors.

Three alternating fresh-autosave pairs give neutral readiness (3.871 → 3.872 s)
and overlapping composite pipeline time (535.216 → 528.580 ms). CPU consumption
falls 11.399 → 11.106 s, with nonoverlapping observed ranges, but these processes
may render different frame counts. Six frozen-scene processes then measure 64
warmup frames and 384 measured frames each, with console notifications suppressed
in both arms and normal TAA/exposure/weather. All 18 intervals match 442 draws,
268 UI quads and 389,180 particles. CPU medians 146.80 → 144.93 s have overlapping
ranges (146.11–147.00 / 143.02–147.31) and mixed paired results; frame medians
63.50 → 63.87 ms also overlap widely. The apparent loading CPU gain does not
establish a robust equal-work improvement. Reject the added descriptor/layout
lifetime code, retaining exact source snapshots, binaries and every observation.
Evidence: `zig-out/reports/perf-copy-descriptor-480/`.

## Sequence 479 — perf-loading-cpu — thread accounting and actual stack diagnosis verified

Current kernel perf_event_paranoid is 2 and `perf stat -e task-clock:u -- true`
succeeds, but CPU-clock and task-clock sampling are denied even outside the guard.
No policy changes. Alternative 50 ms per-thread scheduler observations capture
10.710 CPU seconds versus 11.133 seconds getrusage (96.2%), across 92 observations
and 75 threads. Main CPU 1.680 s, runnable delay 0.002833 s; many sleeping-main
observations wait on futexes. This run does not establish the historical outlier
cause. Approximate event windows retain 50 ms plus stdout-delivery uncertainty;
whole-process counters include menu, capture and shutdown.

Repair the first GDB batch sampler, which exited at its first interrupt; retain
that failed run. Eight bounded intrusive stack observations then complete with
ordinary save replay and source preservation. Actual stacks include software
sampler JIT registration, NIR optimization and LLVM fragment compilation. In
sample 8, an active worker compiles a fragment variant while main waits in
`lvp_shader_compile` under `window.composite`. These identify mechanisms, not
CPU-population percentages; debugger timings are excluded from performance claims.
Accepted runtime and native-dev binaries match the frozen baseline SHA throughout
after both rejected experiments are reverted. Evidence:
`zig-out/reports/perf-loading-cpu-479/` in the performance worktree.

## Sequence 478 — perf-composite-copy — rejected; source reverted

Following the rejected specialization experiment, a standalone fragment shader
copies display-ready images without HDR resources in the driver input. Classic
final composition and swapchain presentation select that program; remaster final
composition retains its original HDR program. Same push prefix, sampling, alpha,
formats and depth-free pipeline contract. After repairing a malformed shader
extension line, build passes 89/89. All three candidate modes match the preserved
identical-baseline frozen TGA and private-Xvfb RGB bytes; validation/ordinary exit
and source preservation pass. The compiled copy SPIR-V is 856 bytes.

Three fresh alternating autosave pairs show readiness 3.819 → 3.830 s (overlapping
ranges 3.772–4.119 / 3.669–3.970), CPU 11.328 → 11.437 s, and composite pipeline
creation 524.299 → 517.172 ms with wide overlap. No demonstrated gain; remove the
prototype. Restored source builds 88/88. Both composite experiments leave the
accepted runtime unchanged. Evidence: `zig-out/reports/perf-composite-copy-478/`
in the separate performance worktree.

## Sequence 477 — perf-composite-specialization — rejected; source reverted

Specializing composite copy/HDR mode through fragment constant 0 preserves exact
frozen classic, Neutral and AgX TGA bytes and normalized private-Xvfb screen RGB.
All six correctness processes pass ordinary Vulkan validation and preserve source
saves/configuration. The old co-op-branch demo is rejected with RuntimeMismatch;
retain that first failure and record a compatible main-based demo for both arms.
A second harness assertion wrongly demanded remaster weather in classic mode;
correct it to require zero there. Neither failure is renderer acceptance.

Three alternating fresh-autosave pairs with private empty Mesa caches, validation
off and uncontrolled OS page cache show readiness 4.478 → 4.476 s; CPU 12.254 →
12.605 s; composite pipeline creation 549.389 → 557.781 ms. No demonstrated gain:
remove the prototype, retaining its frozen binaries and every sample. Build 88/88.
Evidence: `zig-out/reports/perf-composite-specialization-477/` in the performance
worktree. Gregg §2.5.6 and §12.3.8 guide falsification and work/output sanity checks.

Six additional historical sequence-476 frozen-scene runs complete with matched
518 draws, 344 UI quads and 389,180 particles. Software frame times vary greatly:
baseline process medians 78.84/304.30/106.82 ms; candidate 71.64/72.25/230.89 ms.
CPU consumption per measured frame varies much less (0.371–0.430 s across arms).
Keep all outliers; no additional frame-speed claim is accepted from this set.
External CPU workloads and runnable pressure are observed subsequently, but no
cause of those historical outliers is proved. Evidence remains in the original
checkout's `zig-out/reports/perf-weather-program-476/`.

## Sequence 476 — perf-weather-program — loading, exact pixels and main-based smoke replay verified

Owner paused the continuous performance loop. Dedicated weather vertex/fragment
programs move the existing particle and shape functions out of the general
material shaders. The fixed weather-stage contract removes unused skinning,
deform, texmod and material paths; weather varyings shrink from 23 to 7 scalar
components. Particle IDs, indices, lighting, fog and clip equations are retained.
The vertex helper bodies match preserved source byte for byte. Frozen actual
frames match the original repeated-corner TGA SHA exactly, with 389,180 particles.

Build passes 88/88. Twelve fresh-process, default-validation-off loading runs
(three pairs per save, warm/uncontrolled OS page cache) preserve identical restored
state, model order, source files and zero pending/failed images. Arrival medians
3.671 → 3.420 s (ranges overlap); autosave 4.328 → 3.822 s. Autosave CPU consumption
12.153 → 11.353 seconds, peak RSS 2,498,408 → 2,462,444 KiB. A matched autosave
pair's post-map pipeline creation sum falls 334.0 → 174.7 ms. No physical-GPU
throughput claim. At the owner's stop, repeated frame-time benchmarking and the
wider four-loading-fixture replay remained unrun. PR isolation subsequently
builds the performance changes directly on `main` (`8ced3b8`), without the co-op
branch commits. That fresh build passes 88/88 steps, 407/407 runtime tests plus
C contracts, 23 focused Python tests, and ownership R1–R11 stays zero. Its guarded
headless software replay passes the real UI new-game action, e1m1a, and both copied
e1m1b saves: zero pending/failed images, clean ordinary Vulkan validation/exit and
unchanged source saves/configuration. Local smoke evidence is
`/tmp/dk3-perf-pr-smoke/`; no game assets, saves or binaries enter the PR. Repeated
frame-time benchmarking subsequently runs with severe variation; see sequence 477.
Evidence: `zig-out/reports/perf-weather-program-476/`.

## Sequence 475 — perf-weather-index-window — initialization diagnosed; no window optimization admitted

The existing 6 MiB topology buffer takes 1,704 us to allocate/fill on the host and
317 us to allocate/stage/record its upload in the diagnostic save. This excludes
GPU execution and late driver compilation. Reject host initialization as sufficient
explanation for the earlier 229 ms timing difference. No smaller index window is
implemented; retain the once-per-content developer timing. Build 86/86 and the
focused headless diagnostic pass. Evidence:
`zig-out/reports/perf-weather-index-window-475/`.

## Sequence 474 — perf-weather-indexed — rendering and exact pixels verified; timing configurations separated

Replace the rejected instancing prototype with one shared 6 MiB index buffer for
at most 262,144 particles per draw. Identical two-triangle ordering references
four corner IDs per particle in one indexed draw, permitting post-transform reuse
without per-instance overhead. Temporary host/staging bytes are bounded; content
shutdown destroys the buffer before freeing its memory. The existing upload
barrier covers index reads. Counts distinguish submitted indices, nonindexed
vertices and particles; unique IDs do not prove actual invocation counts.
The prototype's `r_vkWeatherIndexed` switch initially defaults off. Its alternate
shader path and switch are removed from the final candidate: weather always uses
the indexed topology, with generator bounds asserted before submission.

The first same-binary 0/1/0 classification shows indexed steady frames around
79 ms versus original 93–102 ms with the same 389,180 particles. Its pixel setup
is rejected: even cheat-enabled devmap clamps time scale zero to a positive
server rate. A private recorded demo with `cl_freezeDemo` is the next exact-image
fixture; no time/quality controls enter performance claims.

Five balanced same-process pairs in the stationary arrival scene retain exactly
389,180 particles: reporting-interval medians 94.74 → 80.275 ms, ranges
88.34–96.04 / 78.56–85.32 ms. Discard the predefined first interval of every phase,
retain all others. Live autosave camera/particles move (226,450–363,606 particles),
so its aggregate is exploratory and cannot establish equal-work performance.
The repaired frozen-demo qualification produces four exact TGA matches against
the repeated-corner path and clean ordinary exit; the first run's expected
disconnect into demo playback confused the generic helper after successful
pixels. Keep that failure and use scoped checking when returning to a live map.

The first twelve fresh-save runs expose a loading regression: arrival
3.975 → 4.124 s, autosave 4.425 → 4.875 s, with autosave ranges not overlapping.
Do not hide this behind the rendering gain. New-binary post-map pipeline creation
costs about 70/140 ms more in the two fixtures. Six additional autosave runs in
the same executable isolate drawing: repeated corners 4.779 s, indexed 4.428 s.
This points toward expanded prototype code as a contributor, without assigning
the entire regression to compilation. Remove the diagnostic alternate shader;
the smaller candidate restores observed pipeline compilation to the old range.
The final direct shader passes exact cross-binary frozen pixels and the four
loading fixtures. Three paired held-scene rendering processes retain identical
work: median frame interval 88.17 → 71.86 ms, ranges 87.08–89.99 / 70.76–75.70.
Six validation-enabled autosave pairs retain a 4.300 → 4.529 s median increase.
A separate normal-default validation-off comparison does not reproduce it:
4.271 → 4.231 s with overlapping ranges. Preserve both configurations; do not
attribute all validation-layer cumulative stack time to validation overhead.
The shared buffer adds 6 MiB plus temporary host/staging work. No density or
visual settings are reduced. CPU sampling experiments retain their observability
limits: process-wide timers mischarge blocked threads, per-thread coverage is
incomplete, and live module maps are needed before dlclose for symbolization.
Full build 86/86 and runtime aggregate 26/26, 407/407 plus C contracts pass;
the aggregate covers unchanged native runtime code, not shader output. Ownership
stays zero. Evidence:
`zig-out/reports/perf-weather-indexed-474/`.

## Sequence 473 — perf-weather-quads — rejected; functional prototype removed

Sequence 472's whole-frame experiment identifies the software weather workload.
An experimental, initially disabled `r_vkWeatherInstancing` path retains particle
IDs, random sequences, triangle winding/order, density and material settings. It
draws four distinct corners as one triangle-strip instance per particle in place
of six repeated triangle-list vertices. The pipeline cache key includes topology;
only weather uses the strip. Normal-feature frame intervals and work counts must
improve before promotion. Frozen same-process captures compare exact pixels;
their time/TAA/exposure/notification controls are correctness fixtures, not a
performance shortcut. The first full build fails Vulkan signed/unsigned topology
inference; the repaired build passes 86/86. The same-process 0/1/0 experiment
reduces vertices 2,335,080 → 1,556,720 at equal 389,180 particles but regresses
steady frame intervals from roughly 95–98 to 125.73/126.17 ms. Do not infer the
cause (software SIMD utilization/instance overhead remain hypotheses). Reject
and remove instancing, its topology key and experimental setting. Pixel comparison
is not reached because camera/time controls are cheat protected in the save
fixture; retain the assertion and clean source/ordinary-exit evidence. No
correctness or physical-GPU acceptance is claimed for the rejected candidate.
Evidence: `zig-out/reports/perf-weather-quads-473/`.

## Sequence 472 — perf-render-2d — diagnostics qualified; weather limiter cross-checked

Each stretch-picture request currently submits its stages separately. Add overlay
quad/stage work counts and one CPU/software-Vulkan timestamp scope per consecutive
2D segment, closing before the next 3D view, frame submission or content release.
CPU segment time includes caller work between requests; its first quad allocation
precedes the scope. Counters printed by the existing stats line describe that last
frame, while timings average the reporting period. Disabled profiling performs no
per-glyph clock reads. No batching or visual change is implemented yet.

Prediction: glyph-heavy developer notifications may contribute measurable draw
submission work. First characterize the unchanged workload, including profiler
output overhead, before deciding whether to batch. Headless software timings
cannot establish physical-GPU throughput.

Overlay CPU segments average about 1.5 ms; main frames are 94–100 ms. Raw GPU
query intervals fail additive accounting: a 58 ms gap sits between world and
weather scopes, and changing boundaries drastically moves apparent category
costs. Experimental rendering splits do not repair attribution and are removed.
Retain a one-frame `r_vkStatsTrace` raw interval diagnostic, fractional query
samples/frame and explicit dropped-scope counts. Do not use the original
0.2–1.8 ms particle subscopes to rule weather out. Three one-second thread
samples consume 4.27–4.29 CPU seconds, with the busiest process thread at
0.82–0.83 seconds each; these identify CPU work, not its call stacks.

A same-process density 1/0/1 classification retains live actors and a stationary
camera. After the transition interval, density zero frames take 35.68/36.47 ms
versus restored-density 101.06/101.10/98.65 ms, and submitted weather vertices
change from 2,335,080 to zero and back. Disabling density is not retained as an
optimization. Bump 1/0/1 gives no material benefit and that hypothesis is rejected.
The first attempted manual pause fails because menu refresh resets `cl_paused`;
preserve the failure and label repaired scenarios unpaused. All completed runs
preserve source saves/configs and have clean ordinary validation. Full build
passes 86/86; ownership R1–R11 stays zero. No duplicate runtime suite for timers.
Evidence:
`zig-out/reports/perf-render-2d-472/`.

## Sequence 471 — perf-paeth-dispatch — exact CPU gain and connected loading verified

Actual portable-renderer disassembly uses SSE2 while the host-native PNG
microbenchmark emits newer instructions. `bench-png` now has the explicit
`-DPNG_BENCH_BASELINE_CPU=true` mode and records its target. The candidate keeps
portable Paeth and selects an SSSE3/SSE4.1 implementation only after CPUID checks,
once per eligible image/pass, with no shared mutable dispatch state. Newer
absolute-value/blend instructions preserve the exact predictor/tie rules.

The first seven-pair/core run exposes a 3–4% RGB control loss despite neutral
inflate/unfilter phases and identical 324 normalized conversion instructions.
An explicit alignment attempt does not repair it and is removed. Restoring the
benchmark's original reporting source (removing a prototype-only CPU-capability
printf) restores the control: preserve the first candidate, alignment and smoke
records. This is an observability/code-placement effect; no general linker or
microarchitectural cause is established. Seven new same-harness pairs per input
on separately pinned CPUs 3 and 7 retain exact pixels/Adler, source/input/binary
identities and all variation. Advertised core caps differ; observed frequencies
or migration causation are not inferred.

RGBA medians on CPU3: full decode 185.834 → 164.214 ms, filter 77.294 →
55.857 ms; CPU7: 276.355 → 241.918 / 119.085 → 86.395 ms. RGB control
81.637 → 81.115 / 118.958 → 118.384 ms, effectively neutral. Fast-core trials
contain retained inflate outliers. RSS/fault counts are neutral; no storage or
whole-game gain is inferred. Full build passes 86/86, shared aggregate 26/26,
407/407 tests and C contracts. Both predictors pass every 8-bit triple across
four lanes against the independent scalar reference. Guarded memory pages also
exercise exact row ends, unaligned starts and short/tail widths on both paths.
The PNG translation unit cross-compiles for Windows x86_64; execution remains
unverified there. Headless Vulkan, OpenGL and the controlled deferred 4096² worker
pass with preserved sources and clean ordinary validation. Twelve paired first-save
runs retain identical state and completed image admission. Arrival readiness is
4.124 → 4.075 s and autosave 4.480 → 4.478 s; model stages are 1043 → 999 ms
and 1031 → 998 ms. CPU/RSS ranges overlap. Retain the demonstrated component
gain without claiming a general whole-load or physical-GPU improvement.
Evidence: `zig-out/reports/perf-paeth-dispatch-471/`.

## Sequence 470 — perf-base-view — exact outputs, ownership and measured work reduction verified

Synchronous image creation still duplicates a 64 MiB level zero even when its
identity/no-light-scale path never mutates it. The candidate adds explicit
caller-lifetime borrowed preparation: level views are const, owned allocations
are tracked separately, generated mips remain owned, and nonidentity color maps
retain the owned fallback. Synchronous create stages every level before source
release; deferred workers keep ordinary fully owned preparation. The existing
owned API remains fully owned. Added ownership/unaligned/color-fallback tests
and CPU benchmark `borrow` mode compare identical uploaded bytes and actual owned
allocation volume. Existing image diagnostics record base borrowing. Initial full
build passes 86/86; aggregate plus benchmark build passes 29/29, 407/407 tests
and C contracts. Final connected install plus CPU profiler build passes 90/90.
The 64-case matrix preserves every historical mip SHA, output metadata and owned/
borrowed equality, including unscaled and nonidentity fallbacks. Seven alternating
CPU pairs per large fixture reduce mip preparation 27.893 → 7.946 ms (RGBA),
31.300 → 11.222 ms (RGB). Owned allocation volume is 89478484 → 22369620 bytes
per 4096-square chain: 64 MiB less copying/allocation. Process peak RSS medians
181664 → 159744 / 173808 → 135468 KiB include PNG decoding too; user/system
time and minor faults fall. Physical file I/O and major faults are zero. Large
PNG hashes equal their historical sequence434 identities; all fixtures are read-only.

Standard and deliberate intensity-1.4 color-fallback four-fixture qualifications
pass, with actual base-borrow and owned-fallback diagnostics respectively. A
dynamic 4096-square deferred body also completes through fully owned worker mips.
Every qualification passes complete admission, ordinary validation, normal exit
and source preservation. First twelve paired save runs reduce model/shader work
but yield inconsistent arrival readiness (original three medians 3.925 → 4.322 s).
Keep these results. Exactly five additional arrival pairs are declared before
running; all original samples remain in the combined eight-pair summary.
Combined arrival medians are 4.174 → 4.023 s, with overlapping 3.923–4.373 /
3.874–4.378 s ranges. Autosave's original three-pair median is 4.628 → 4.374 s.
All 22 paired saves retain identical restored state/model hints and zero image/
validation/source-preservation errors. Whole-run arrival CPU is neutral; whole
RSS ranges overlap. Retain the exact component/work gain and disclose readiness
variation; do not extrapolate microbenchmark RSS or software frames to GPU play.
Local sysfs additionally shows 5.158/3.289 GHz advertised core cap groups; this
alone does not prove migration caused the observed variation. Ownership stays zero.
Evidence: `zig-out/reports/perf-base-view-470/`.

## Sequence 469 — perf-prepared-view — contracts, work reduction and connected comparison verified

Sequence468 excludes geometry/poses as a major current limiter. Prepared images
still allocate/copy 64 MiB on their owner (~12 ms each) before prepareLevels
creates its own mutable levels. The candidate exposes an immutable completed-batch
view to synchronous Vulkan image admission, retaining explicit allocation ownership
for ordinary loads. Levels own their data before the selected batch can be freed.
Deferred consumers explicitly disallow views because their batch is released before
mip work; C/OpenGL loaders retain fresh owned copies and repeated alias isolation.
No cache/format/quality policy changes. Existing image timing lines record whether
a source was borrowed, without extra per-image lines. Contracts cover incomplete/
failed/missing/freed selection, no RI allocation/re-read, repeated views, interleaved
batch lifetime and mutation/free of independent owned copies. Full build passes
86/86; shared aggregate 26/26, 405/405 tests and C contracts; ownership R1–R11
stays zero. Standard/cache-off/OpenGL2 four-fixture qualifications and an actual
4096-square deferred-worker fixture pass all admission, normal-exit ordinary
validation and source-preservation checks. The worker path retains owned copies.

Twelve balanced fresh-process save runs compare frozen468/frozen469 with the same
IQM diagnostics, assets and settings. Every case restores identical state, eight
model hints and complete images without errors. At least 512 MiB of observed
RGBA copying is avoided per first save (work volume, not peak RSS). Large model
image read/copy totals drop 97/95 → 0/0 ms; shader/image phase medians reduce
512.762/518.845 → 413.272/427.936 ms; model stages 1226/1230 → 1132/1149 ms.
Full readiness is neutral for arrival (4.225 → 4.224 s), autosave median
4.678 → 4.527 s with overlapping ranges. Whole CPU medians are
10.956 → 11.009 / 12.298 → 12.583 s; no total-CPU saving is claimed. Peak RSS
medians 2456616 → 2450156 / 2523236 → 2516424 KiB overlap. Retain the exact
component work reduction; do not claim a general end-to-end or peak-memory gain.
Evidence: `zig-out/reports/perf-prepared-view-469/`.

## Sequence 468 — perf-iqm-phases — diagnostic qualified

Remaining first-save model registration is about 1.2 seconds after preparation
and decoding improvements. The IQM loader now records bounded per-model phase
totals for packed geometry/validation/allocation, shader/image admission, joint/
pose/bounds preparation and staging the model buffer, alongside actual work counts.
These are owner wall times; `buffer_stage_us` is not physical-GPU execution time.
One developer line per new model avoids per-vertex/per-mesh trace overhead. No
algorithm or allocation policy changes yet. Full build passes 86/86; two actual
first-save diagnostics pass restoration, complete image admission, ordinary
validation and source preservation. Across eight IQMs per case, geometry packing
takes 9.283/9.536 ms; poses/joints/bounds 3.629/3.649 ms; buffer staging
4.229/5.015 ms, versus shader/image admission 512.822/524.041 ms. Sixteen records
retain work counts and stage sums. Geometry/pose rewrites are not justified by
this workload; investigate redundant prepared-image copies instead. Instrumented
readiness is not a speedup claim; the frozen profiled runtime provides the next
same-diagnostics baseline.
Evidence: `zig-out/reports/perf-iqm-phases-468/`.

## Sequence 467 — perf-small-mips — bounded scheduling and connected comparison verified

First-save traces show six 64/256-square weapon/flash images decoding below the
millisecond timer resolution, then waiting another worker/frame cycle for mip
preparation. The candidate finishes already-decoded images of at most 256 KiB
source inline, capped at 2 MiB source per frame, and revisits the entry immediately
under the unchanged eight-image/four-MiB upload budget. Larger mip chains retain
workers and cancellation/join ownership. Added aggregate per-image `mip_us` and
`owner_mip` fields will measure actual owner cost; no extra diagnostic lines.
Full build passes 86/86; shared aggregate 26/26, 405/405 tests plus C contracts.
The standard four-fixture qualification passes complete admission, copied saves,
ordinary validation and source preservation. Fourteen small chains run inline,
67 us median / 151 us maximum. A separate controlled actor fixture completes an
actual deferred 4096-square body through the worker: 37359 us mip work,
`owner_mip=0`, zero pending/failed images and ordinary validation errors.

That fixture first fails because the older single-world save cannot resolve a
requested resident-world name. Empty requested world selects the active root;
no gameplay fix or asset substitution is made. The failed record also contains
command-buffer/layout validation errors during forced SIGTERM teardown. Those
are retained and unresolved, outside successful normal-exit validation claims.
The driver now tries ordinary quit before signal fallback on diagnostic failure.
The repaired actor qualification exits normally without validation errors.

Twelve paired fresh-process save runs use frozen runtime465/runtime467 and pass
identical restored state, eight model hints, zero pending/failed images and all
source-preservation/ordinary-validation checks. The observed inline source and
upload work obey their separate bounds. Median full readiness: arrival
4.331 → 4.123 s; autosave 4.880 → 4.624 s. Whole-process CPU medians
11.610 → 11.087 s and 13.011 → 12.622 s, including fewer software-rendered
waiting frames; do not attribute the whole CPU delta to thread creation.
Model/world stages are broadly neutral. RSS medians 2447692 → 2461816 KiB
and 2520332 → 2515156 KiB; ranges overlap and are retained. All have one major
fault. Retain the bounded change; no physical-GPU/cold-storage claim.
Evidence: `zig-out/reports/perf-small-mips-467/`.

## Sequence 466 — perf-first-save — fresh-process workload and comparison verified

The four-fixture loop primes decoded images with intro and e1m1a before restoring
saves. It cannot establish first-save-from-menu latency. The driver now supports
`--save-only`, retaining real UI actions, copied saves, guarded software display,
source preservation and complete image admission. One save per process removes
prior image-cache priming; OS page cache is explicitly uncontrolled, not cold.
Balanced trials compare frozen runtime464 without preparation, the same binary
with three slots, and runtime465 with the same three slots. Both supplied e1m1b
saves are independent process fixtures. Stage time, restored state, job bounds,
CPU, RSS, pressure and every sample are retained. No new engine change is made.
The first qualification passes engine restoration but its normal-mode summary
assumes `new_game` exists and fails after exit. That record remains; optional
summary fields repair the driver, followed by a new qualification and 18 balanced
first-save trials. All pass ordinary validation, full image admission, source
preservation and identical restored map/mode/position/health/armor/weapon/ammo
within each fixture. Enabled arms consume the same eight model hints at most
three slots; disabled preparation consumes none. All have one major fault.

Median readiness for serial / prepared / faster decoder: arrival save
5.484 / 4.879 / 4.425 s; autosave 6.038 / 5.037 / 4.833 s. Model stages are
2411 / 1514 / 1226 ms and 2404 / 1489 / 1255 ms. CPU medians are
11.808 / 12.433 / 11.545 s and 13.200 / 13.554 / 13.232 s. RSS medians
2413484 / 2440376 / 2452676 KiB and 2484364 / 2507068 / 2524324 KiB.
Variation is retained; do not add gains from these medians to the differently
primed four-fixture sequence. This verifies first-process restoration with warm/
uncontrolled OS pages, not cold-storage latency. Remaining deferred small-image
frame hops motivate sequence467. Evidence: `zig-out/reports/perf-first-save-466/`.

## Sequence 465 — perf-inflate-library — CPU/contracts and connected comparison verified

PNG inflate remains a measured CPU cost. Compare the actual bundled zlib with
the installed libdeflate 1.26 in one CPU-only executable, using the two fixed PNG
IDAT streams. Prediction: a full-buffer decoder reduces inflate CPU without
changing filtered bytes. Both arms include codec allocation/cleanup, exact
input/output bounds, zlib checksum validation, one discarded warmup and full
byte comparison outside timing. Record seven alternating pairs, source/binary
identities, CPU/RSS and all samples. Official v1.26 public header and COPYING
are retained locally. The same-binary native-target experiment gives median
inflate 140.743 → 64.983 ms (RGBA) and 75.634 → 43.633 ms (RGB), exact full
filtered-byte/CRC/Adler equality in all seven pairs. This first experiment links
the installed library; it does not alone establish engine performance.

The candidate now includes a reviewed, pinned, unmodified 21-file decoder-only
subset under `engine/ioquake3/code/thirdparty/libdeflate-1.26/`. MIT notices and
COPYING are retained; COPYING installs under `share/licenses/dk3/`. No system
runtime dependency, compression/gzip code or game runtime is added. Each PNG call
owns a decompressor and retains exact filtered-size, checksum and complete-input
checks; failure frees matching ownership without a fallback codec. The source
review and archive hash are in the component's `DK3-REVIEW.md`.

The first generic-target build exposes an upstream AVX512 Adler target-attribute
incompatibility (`evex512`). Using upstream's documented AVX512VNNI opt-out
retains AVX2/SSE2 and unmodified source. Repaired full build passes 86/86; shared
runtime contracts and PNG benchmark build pass 29/29 steps, 405/405 tests and C
contracts. Added valid-chunk-CRC cases reach truncated zlib, bad Adler/header,
FDICT, reserved block type and trailing-input rejection. Independently encoded
short/overlapping/window match data also passes the new decoder with unaligned
output, capacity rejection and guards. Ownership remains R1–R11 zero.

Seven paired actual owner-loader trials include parsing, CRC, inflation, filtering,
conversion and allocation/copies: RGBA 237.781 → 166.831 ms, RGB 110.989 →
81.430 ms, identical pixel CRCs throughout. Actual generic-build inflate stages
are 161.146 → 90.592 / 88.539 → 58.787 ms; filter time is neutral. Peak RSS
stays approximately 186/135 MiB respectively; CPU falls and all major faults
are zero. Detailed ranges and source/executable identities are retained.

The first headless replay refuses an incomplete frozen prefix before launching
the game (modules omitted from the copy). Its record is retained; exact modules
and shared shader from the same build repair the fixture. Qualification then
passes default three slots on the deflated archive, cache disabled on the stored
archive, and OpenGL2. Each passes all four fixtures, ordinary validation and
source preservation. Restored Vulkan images match the baseline's geometry,
textures and HUD, including the pre-existing top-row developer glyph artifact.
Three alternating stored-archive pairs pass with frozen original/candidate
prefixes and the same three-slot setting. Median complete first-map readiness is
3.380 → 3.218 s; saves 2.668/2.617 → 2.468/2.419 s. Model stages reduce
1098/1266/1237 → 1000/1118/1091 ms. Intro is neutral. Whole-run CPU medians
38.178 → 37.151 s; peak RSS 2773672 → 2764188 KiB with overlapping ranges;
all have one major fault. All nine successful four-fixture runs pass complete
image admission, unchanged model order, copied-save restoration, ordinary
validation and source preservation. These are warm-asset software measurements;
the library is retained without a cold-storage or physical-GPU claim.
Development/release assembly now retains COPYING too; all eight existing
installation contracts pass, including the notice in the published test tree.
Evidence: `zig-out/reports/perf-inflate-465/`.

## Sequence 464 — perf-model-slots — bounded three-slot comparison verified

Two-slot traces still wait roughly 230–260 ms for successive independent PNG
groups. The candidate supports a bounded third slot and polls earlier reads before
loading later model metadata. It snapshots exclusions from every older active
slot, with a 4096-name hard cap, rather than only one peer. Per-slot model input
and pixel limits stay 32/128 MiB. Worst-case temporary model/compressed/filtered/
decoded bounds scale approximately 832 → 1248 MiB; actual RSS/CPU cost and full
readiness must justify the third slot. Normal registration order and output remain
unchanged. Multi-peer snapshot/cancellation and cap regressions are added. The
full build and 26-step/405-test shared aggregate pass with these changes. Slot
count is controlled by `r_modelImagePrefetchSlots` (clamped 1–3) and
the probe's `--model-prefetch-slots`. The comparison includes the frozen original
two-slot path, tuned two slots and tuned three slots; tuned arms share one binary
so resource changes can be separated from earlier-read polling. Full build passes
85/85. Qualification passes with three slots, with one slot/cache disabled and
with the optional hint on OpenGL2 (normal registration, no prepared models).
Nine balanced headless Vulkan runs pass all four fixtures, complete admission,
copied-save restoration and ordinary validation; source saves/configuration stay
unchanged. All arms register the same 26 models and prepare 26 PNGs; observed
concurrency matches the requested bound.

Median complete readiness for original two slots / tuned two / tuned three:
first map 3.622 / 3.621 / 3.320 s; saves 2.873/2.921 / 2.871/2.872 /
2.719/2.618 s. Intro is neutral. Model registration stages support the result:
first map 1344 / 1332 / 1106 ms, saves 1454/1604 / 1529/1582 / 1327/1277 ms.
Whole-run CPU medians are 38.148 / 38.522 / 38.834 s; peak RSS medians
2724848 / 2724016 / 2729376 KiB, with overlapping ranges retained. These
warm-asset software results support default three; one/two remain available.
The default-only source change follows this same-binary comparison. Worst-case
memory bounds above still apply; no cold-storage or physical-GPU claim.
Evidence: `zig-out/reports/perf-model-slots-464/` including resource ranges.

## Sequence 463 — perf-model-aliases — work reduction and connected comparison verified

The model-preparation trace repeats shared 4096-square body/head PNGs in adjacent
IQM model slots. Both actual models reuse the same registered shaders, so these
extra reads and 64 MiB pixel copies are unnecessary. A later slot now snapshots
the earlier slot's queued source names during metadata preparation. Excluded names
remain ordinary validated image loads if the earlier hint fails, is cancelled or
registers out of order. Snapshot ownership avoids retaining a pointer to the
earlier batch, and names are released before dispatch/cancellation. Worker limits,
actual model/shader registration and GPU ownership stay unchanged.

Added regressions exercise source-batch destruction, excluded-source normal-load
fallback, independent prepared output and failed-peer handling. Full build passes
85/85; the shared aggregate passes 26/26, 405/405 tests and C contracts; ownership
remains R1–R11 zero. The first six four-fixture headless runs pass all admission,
save and ordinary-validation checks with unchanged actual model registration lists.
Prepared model PNG jobs fall 34 → 26 and pixels 2281701376 → 1744830464 bytes
per run (512 MiB less preparation work). This is work volume, not peak memory.
The trace also reveals 552 per-mesh exclusion messages. Those diagnostics now
aggregate at dispatch; the focused PNG contracts and full build pass after this
repair. Timed comparisons are repeated with aggregate logging before admitting an
end-to-end gain; first results remain preserved. Evidence:
`zig-out/reports/perf-model-aliases-463/`.
The repaired six-run comparison retains the same 26 actual model registrations
and 26 prepared PNG jobs versus baseline 34; 552 repeated queue requests now
produce only four aggregate messages. All four fixtures pass complete admission,
copied-save restoration and ordinary validation in every run. Median first-map
readiness is 3.622 → 3.575 s; saves 3.072/2.922 → 3.021/2.870 s. Model stages
1392/1638/1573 → 1347/1536/1494 ms support the work reduction. Intro varies;
no intro speedup is claimed. RSS and whole-process CPU variation are retained,
without an isolated peak-memory or CPU-total claim. Source saves/configuration
remain unchanged. The verified two-slot runtime is frozen for the next experiment.

## Sequence 462 — perf-model-prefetch — contracts and same-binary comparison verified

Remaining corrected save image read/decode work is approximately 1.3 seconds,
including serial large RGBA decodes. The candidate resolves the existing optional
model mappings, passes a generic initial model hint through native renderer ABI
14/import 717, and runs at most two preparation slots. Each retains at most
32 MiB model input plus the existing 128 MiB decoded batch limit. Only immutable
PNG bytes decode on workers; model/shader/GPU registration stays on the owner and
waits for its complete batch. Prepared model input is consumed once, avoiding
another model read. Cancellation joins workers before input/pixel cleanup.

Explicit cached batches use the unchanged source-byte-checked PNG cache on their
owner, with independent batch and canonical allocations so shrinking the cache
cannot invalidate a pending batch. World/deferred batches keep their original
policy. Normal registration remains available when a preparation hint cannot be
used. No class-specific dispatch or graphics quality changes are introduced.
`r_modelImagePrefetch` (default 1) and the probe's `--model-prefetch 0|1`
support same-binary comparisons. Other renderers may omit this optional hint.
The shared aggregate passes 26/26 steps, 405/405 tests and C contracts, including
new prepared-cache admission, no-repeat-decode, cache-shrink copy isolation,
changed-source rejection and budget rejection. Ownership remains R1–R11 zero.
The first integrated compile caught constness mismatches in the owned model-file
handoff; callback/slot types now match the actual mutable file allocation and
destructor. Full build passes 85/85. The first headless qualification and three
alternating off/on pairs use the same frozen runtime462 and corrected stored-PNG
fixture. All seven four-fixture runs pass complete image admission with zero
ordinary validation errors and unchanged source saves/configuration. Each enabled
run prepares 26 models, observes at most two slots, and completes every hint;
disabled runs observe no preparation. Largest prepared model input is 12426648
bytes, below the 32 MiB cap.

Median complete first-map readiness reduces 3.926 → 3.673 s; saves 3.429/3.275 →
2.969/2.923 s. Corresponding model registration stages reduce 1699/1954/1949 →
1376/1610/1612 ms. Intro registration is neutral; no isolated intro claim is made.
Peak RSS medians rise 2681088 → 2711852 KiB (about 30 MiB). Whole-process CPU
medians remain near 38 seconds over the four-fixture run; ranges are retained,
with 1–4 major faults and software-renderer/polling work included. These are warm
asset-workload software results, not cold-storage or physical-GPU acceptance.
The resource/readiness data support the bounded strategy; the loop remains active.
Evidence: `zig-out/reports/perf-model-prefetch-462/`.

## Sequence 461 — perf-zip-buffer — CPU/syscall and connected verification passed

The actual ZIP-reader strace records 10039 read and 6145 lseek calls for the
fixed RGBA lookup plus three complete reads. Traced timings are discarded. The
candidate raises the per-stream upper read bound from 16 to 128 KiB to amortize
seek/read calls, while allocating at most each entry's compressed size (one byte
for empty entries). Remaining compressed bytes bound every read; CRC and error
checks stay. At four large readers this adds at most 448 KiB. Small entries no
longer allocate the full block. Prediction: fewer syscalls and lower read CPU
time, with exact data and unchanged integrity. Evidence:
`zig-out/reports/perf-zip-buffer-461/`.
Seven alternating fresh-process trials with five reads after warmup reduce
RGBA deflated/stored reads 12.162/11.421 → 11.209/10.501 ms and RGB
46.045/7.947 → 45.350/7.456 ms. Required CRCs match. Repeated separate strace
reduces read/lseek counts 10039/6145 → 1279/1765, including identical archive
lookup/setup. This confirms fewer syscalls; traced timing is excluded. Native
build passes 85/85 and the shared aggregate passes 26/26 with 405/405 tests and
C contracts. A separate actual-reader qualification passes 216 independent stored/
deflated cases, empty/tiny/16-KiB/128-KiB boundary entries, partial/unaligned output,
zero-length requests, every byte, completion CRC and allocator balance. Connected
package/runtime replay passes all six four-fixture runs recorded in sequence 459.

## Sequence 460 — perf-zip-copy — CPU and connected verification passed

Sequence 459's actual-reader comparison exposed an important counterexample:
stored RGBA reads take 32.985 ms versus 12.376 ms deflated, while stored RGB
23.289 ms beats deflated 46.733 ms. Archive size alone did not predict read cost.
Inspection shows the stored/raw path copies its disjoint private input buffer to
caller output byte by byte. The candidate replaces only this bounded copy with
memcpy; CRC updates, completion/error checks and all stream offsets stay intact.
Evidence: `zig-out/reports/perf-zip-copy-460/`. Seven alternating fresh-process
trials with five measured reads after warmup reduce stored RGBA 32.733 →
11.272 ms and stored RGB 23.211 → 7.888 ms. Deflated reads remain neutral,
11.954/45.862 → 11.971/45.868 ms. Required CRCs match throughout. Combined
with sequence 459's stored PNGs, RGB avoids the expensive outer inflation;
RGBA no longer regresses. Connected native build/contracts and all six four-fixture
headless replays pass in sequence 459.

## Sequence 459 — perf-png-archive — package equivalence and connected comparison passed

The actual neural package contains 223 PNG entries: 1663003797 PNG bytes are
wrapped in another deflate layer, which saves only 6145429 bytes (0.370%). The
next experiment isolates the actual bundled ZIP reader, including required CRC
completion, from graphics and then compares an isolated package variant. Neural
writers now share one compression policy: store exact PNG bytes, continue
deflating models/scripts/manifests. Entry hashes/signatures/CRCs and ZIP32 admission
remain required. The original installation and converted generation are unchanged.
A connected writer regression checks deterministic output, unchanged entry bytes,
mixed methods and normal package validation. No runtime gain is claimed yet.
Evidence: `zig-out/reports/perf-png-archive-459/`.
An isolated 2202283688-byte variant is 6145429 bytes larger than the original
2196138259-byte package. All 940 entry SHA-256 values, native ZIP32 constraints,
CRCs and complete validation receipts match; source package SHA is unchanged.
Seven shared package tests pass. All connected writers use the existing classic
archive context so the real greater-than-2-GiB package remains ZIP32-compatible.
The actual-reader benchmark passes both methods and rejects damaged CRCs. The
first seven alternating trials reveal the stored-copy bottleneck in sequence 460;
the packaging change remains unqualified pending that connected experiment.
First replay failures are preserved: the identity recorder required a fixture
binary link; the next attempt correctly rejected SaveAssetMismatch because the
fixture-copy script followed the neural archive symlink and picked up different
map packages. A preflight then found the older diagnostic fixture used a base
model package different from the neural overlay's validated source generation.
Both new comparison fixtures use one matching model package, retain the exact
stock map package for the supplied saves, and have identical non-neural package
SHA-256 values. Both neural validation receipts match. See
`validated-fixture-proof.json`. Earlier same-fixture performance comparisons keep
their recorded scope; this correction is not a new release installation or an
artistic acceptance claim. Fresh paired replays use only the corrected fixtures.
Three alternating runs per method use the same frozen runtime461, ordinary
validation, fresh private Mesa caches and the corrected fixed inputs. All six
complete New Game, direct first map and both copied saves with zero pending/failed
images, zero ordinary validation errors and unchanged source saves/configuration.
Median first-map readiness is 4.033 → 3.924 s; second save 3.324 → 3.224 s.
First save 3.426 → 3.426 s is neutral with variation, despite lower texture-read
work. First-map/save image read/decode diagnostics are 1181/1394/1390 →
1068/1338/1291 ms. Intro varies; no isolated intro speedup is claimed. Process
RSS medians 2681672 → 2684516 KiB are effectively unchanged. The extra package
size is the explicit disk tradeoff; no original installation/generation was
overwritten. Full evidence and ranges are retained; the loop remains active.

## Sequence 458 — perf-png-owner — CPU and connected renderer comparison verified

The synchronous PNG loader decodes to malloc-owned pixels, then allocates a
renderer-owned copy even when the decoded result cannot enter the bounded cache.
The CPU benchmark now optionally runs that actual owner path on borrowed fixture
bytes, separating allocation/copy overhead from archive I/O. Prediction: decoding
uncached results directly into their final allocator removes one full-image copy
and allocation while retaining the same cache, worker ownership and error cleanup.
Source/artifact identities and evidence: `zig-out/reports/perf-png-owner-458/`.
The shared decoder now accepts an output allocator/cleanup pair. Workers retain
malloc ownership; owner cache candidates retain immutable malloc pixels; results
that cannot enter the unchanged cache decode directly into renderer ownership.
Failed output preparation invokes the matching cleanup callback. Cache hits still
return fresh copies. Seven alternating fresh-process trials with two measured
samples after warmup reduce actual owner-path RGBA 258.603 → 237.142 ms and RGB
130.653 → 110.313 ms. Pixel CRCs and filtered checksums match throughout. These
include allocation/cache-locality effects, not solely a timed memcpy. Median RGB
peak RSS drops 151416 → 135124 KiB; RGBA peak stays near 185000 KiB. No major faults
occur; user/system CPU samples are retained. An independently encoded valid-zlib
PNG with an invalid scanline filter exercises cleanup after output allocation in
both owner/cache modes. Shared aggregate passes 26/26 steps, 405/405 tests and C
contracts; full build passes 85/85. Three alternating complete-admission headless
trials per implementation compare the pre-455 runtime with combined 455–458 on
identical HD assets, ordinary validation and fresh private Mesa caches. All six
complete New Game, direct first map and both copied saves with zero pending/failed
images and zero ordinary validation errors. Median first-map readiness reduces
4.225 → 4.125 s; saves 3.725/3.624 → 3.479/3.424 s. Intro 3.974 → 3.723 s varies
substantially across runs; no isolated intro gain is inferred. Save image
read/decode diagnostics reduce 1537/1524 → 1399/1403 ms. Median whole-process
peak RSS remains approximately 2.52 GiB. Source saves/configuration are unchanged;
ownership R1–R11 remains zero. Baseline/current restored frames were inspected:
scene/HUD are present in both; existing top-row developer glyph artifacts remain.
These are software renderer results, not physical-GPU or complete artistic acceptance.

## Sequence 457 — perf-inflate-refill — CPU and connected verification passed

Actual optimized machine code still loads and shifts each byte separately for
the two-byte bit refill. A local candidate assembles exactly the same two
little-endian bytes and shifts once; input/output bounds and parser state stay.
Both direct CPU variants use identical compiler flags, full source fingerprints,
and retained disassembly. Prediction: fewer dependent shifts reduce the measured
inflation cost without skipping checks. No new renderer code is admitted yet.
Evidence: `zig-out/reports/perf-inflate-refill-457/`. Seven alternating fresh-process
pairs, with two measured decodes after warmup, give RGBA decode 240.233 →
237.358 ms (inflate 163.215 → 160.866 ms) and RGB decode 115.517 → 114.706 ms
(inflate 90.303 → 88.939 ms). All decoded CRCs and filtered checksums match.
The candidate is admitted to source; the connected build, contracts and six
four-fixture headless replays pass as recorded in sequence 458.

## Sequence 456 — perf-inflate-matches — CPU and connected verification passed

Instrumented actual-inflater counters characterize match lengths/distances on the
fixed PNGs; diagnostic timings are discarded. RGBA has 11.24 million matches per
inflate, 87.95% length 4–7 and 10.64% length 8–15; RGB has 2.10 million matches,
64.16% length 4–7 and 21.38% length 8–15. Neither fixture uses window fallback in
this full-output workload. The candidate copies exact four-byte groups when
distance is at least four, then exact tail bytes; each group is disjoint, and
successive groups preserve forward overlapping expansion. Existing distance-one,
long disjoint, short-distance and sliding-window paths stay. Prediction: fewer
dependent byte stores improve short-match-heavy inflation, with exact output and
no extra memory. Evidence: `zig-out/reports/perf-inflate-matches-456/`.
Seven paired trials first show only a small gain for the general four-byte loop.
The retained variant specializes lengths 4–7 before the other match-copy cases.
A separate seven-pair comparison gives RGBA decode 246.540 → 240.679 ms and
inflate 170.289 → 164.347 ms; RGB decode 116.874 → 115.190 ms and inflate
91.776 → 90.322 ms. All decoded CRCs and filtered checksums match. Independent
fixed-code fixture coverage spans every distance 1–33 and length 3–35,257,258,
including unaligned outputs, tiny input/output chunks and window crossings.
Python's standard zlib independently validates the encoded fixture. The shared
aggregate passes 26/26 steps, 405/405 tests and C contracts. No whole-load gain
is inferred from these component results.
The full build and connected six four-fixture headless replays pass in sequence 458.

## Sequence 455 — perf-image-alpha — CPU and integrated verification passed

The remaining CPU image preparation includes a scalar full-image alpha scan.
The candidate checks bounded vectors of RGBA pixels and retains a scalar tail,
without altering pixels, mip levels, average color or the transparency decision.
Prediction: opaque large images improve; an image with early alpha remains near
neutral. The actual CPU preparation benchmark and exact golden outputs are the
acceptance metric before any integrated claim. Evidence:
`zig-out/reports/perf-image-alpha-455/`.
Seven alternating source-fingerprinted fresh-process trials with two measured
preparations after warmup give RGBA 27.628 → 27.234 ms, opaque RGB 32.965 →
31.623 ms. The 64-case exact output/metadata matrix passes. Permanent tests check
every alpha lane, early/last transparency, vector boundaries and unaligned inputs.
Full build passes 85/85; shared aggregate passes 26/26 with 405/405 tests and C
contracts. Memory allocation and image bytes are unchanged. This is a modest
component gain; no additional whole-load improvement is claimed. The CPU benchmark
now embeds and prints the actual image implementation's SHA-256 as well.
Current headless software-Vulkan New Game, direct first map and both copied saves
pass with zero pending/failed images and zero ordinary validation errors. Source
configuration/save hashes remain unchanged; ownership R1–R11 remains zero. This
qualification replay does not establish a further whole-load timing gain.

## Sequence 454 — perf-inflate — alternative rejected

Inflation remains approximately 170 ms of the 248 ms RGBA decode in the fixed
4096-square fixture. The next CPU-only experiment compares the actual bundled
inflater with Zig 0.16's standard-library inflater on the same concatenated IDAT
bytes. Both paths must complete the exact output bound, consume the stream and
validate the zlib checksum; the Zig API only exposes the footer, so the experiment
explicitly verifies it with the existing checksum implementation. Full filtered
output SHA-256 must match. No replacement decoder has been admitted to the engine.
Evidence: `zig-out/reports/perf-inflate-454/`. Five alternating fresh-process
trials per input/implementation, with two measured samples after warmup, compare
one ReleaseSafe native-CPU executable. The Zig path is slower: RGBA 167.697 →
265.015 ms, RGB 88.421 → 154.627 ms, with identical full filtered SHA-256.
The bundled implementation stays; no runtime code or format validation changes.

## Sequence 453 — perf-experiment-integrity — source/build proof passed

The owner supplied Brendan Gregg's *Systems Performance*, second edition, as
the ongoing experiment guide. Relevant local PDF sections were read: scientific
method, USE, workload characterization, observing observability, active
benchmarking, sanity checks, statistics and benchmark questions. The adapted perf
skill now applies these methods explicitly. Evidence workspace:
`zig-out/reports/perf-experiment-integrity-453/` records the supplied book's identity.

A benchmark sanity check found `bench-png` reusing an unchanged executable after
its included decoder .c changed. No sequence-452 gain was measured or accepted
from that artifact. Explicit included-source content stamps now enter C-only
benchmark/contract build keys, alongside header stamps; the benchmark prints its
source/header fingerprints. Fresh original/candidate builds have distinct verified
source stamps and executable hashes, recorded in `build-proof.json`. The rebuilt
shared aggregate passes 26/26 steps, 404/404 tests and C contracts. This is a
measurement integrity repair, not a claimed decoder speedup.

## Sequence 452 — perf-png-pairs — candidate rejected

The Paeth candidate shares RGBA input/output operations across adjacent pixels
while evaluating each left dependency in order. The predictor formula, tie order,
byte wrapping and scalar tail remain unchanged. Independent forward-filtered
coverage now spans 1–19 columns for every 1–8-byte stride and all five filters.
Evidence: `zig-out/reports/perf-png-pairs-452/`. The exact prior decoder/source are
retained. The first attempted build was stale (sequence 453); only fresh,
source-stamped original/candidate executables enter the seven alternating trials
with two measured decodes and one discarded warmup per process. RGBA filtering
59.401 → 57.183 ms does not improve complete decode (247.639 → 248.475 ms);
RGB decode is 116.903 → 118.378 ms. All decoded CRCs and filtered checksums match.
The candidate is removed; expanded independent filter coverage remains. Active
250-ms process observations show one running thread, no physical input reads,
no major faults or swap. Scheduler statistics are disabled, so runqueue wait
counters cannot establish absence of contention. This is a warm CPU workload,
not evidence about cold storage or physical-GPU performance.

## Sequence 451 — perf-adler — CPU and integrated verification passed

The actual PNG-decoder benchmark now times an additional Adler-32 pass over its
filtered output, separately from decode/inflate/unfilter, and records the checksum.
Evidence: `zig-out/reports/perf-adler-451/`. The pass accounts for about 14 ms in
the RGBA fixture and 10 ms in RGB. The candidate folds sixteen byte updates into
exact weighted SSE2 sums, preserving upstream NMAX/modulo boundaries and the
portable fallback. Notices remain intact and the source alteration is marked.
Seven alternating fresh-process trials per implementation reduce checksum medians
13.838 → 2.777 ms and 10.401 → 2.110 ms; full PNG decode medians reduce
262.798 → 246.179 ms and 124.767 → 114.534 ms. Both filtered Adler-32 and decoded
pixel CRCs match in every sample. No validation is skipped. These are decoder
measurements, not a further whole-load claim.

Added independent scalar checksum comparisons cover short/vector/NMAX boundaries,
alignment, worst-case bytes, deterministic random input, seeds and streaming.
Four permanent mip/color golden tests join `test-runtime` through the new
`test-image-levels` target, covering the related 449/450 changes without a graphics
device. The full build passes 85/85 steps; the shared aggregate passes 26/26
steps, 404/404 tests and C contracts, including all new checksum boundaries and
permanent golden pixels. Current headless software-Vulkan New Game, direct first
map and both copied saves complete with zero pending/failed images and zero
ordinary validation errors. Original configuration/save hashes remain unchanged;
ownership remains R1–R11 zero. No additional whole-load speedup is inferred from
this single qualification replay. The optimization loop remains active.

## Sequence 450 — perf-image-mips — CPU and connected renderer comparison verified

The remaining measured CPU preparation cost includes the scalar RGBA box filter.
It now sums adjacent pixels from two rows in widened vector lanes, preserving
the original truncation and independent alpha exactly. Small/tail columns retain
the clamped scalar path. Evidence workspace: `zig-out/reports/perf-image-mips-450/`.
The existing 64-case exact mip/color matrix passes against the retained scalar
goldens, including odd rows and alpha tails. Seven alternating fresh-process
trials per implementation, with one discarded warmup and two measured samples,
reduce preparation 53.493 → 36.692 ms for the RGBA fixture and 61.148 → 41.191 ms
for RGB. Every uploaded-mip SHA-256 matches. Host load differs from sequence 449;
these are paired comparisons within this experiment, not compounded cross-run
whole-load percentages. The connected renderer build passes 85/85 steps.

Three alternating complete-admission headless trials per implementation compare
the pre-449 CPU preparation against combined 449/450, with identical assets,
ordinary Khronos validation and fresh private Mesa disk caches. All six complete
New Game, direct first map and both copied saves, with zero pending/failed images
and zero ordinary validation errors. Median readiness changes 4.480 → 4.278 s for
intro, 5.186 → 4.884 s for first map, and 4.843/4.641 → 4.330/4.290 s for the saves.
Save preparation/upload diagnostics reduce 940/923 → 606/600 ms. Host variation
remains; complete timing and stage samples are retained in this report. Source
configuration/saves remain unchanged; ownership remains R1–R11 zero. The existing
instrumented shader arithmetic issue from 448 is still open; these changes do not
modify shader source or establish physical-GPU/artistic acceptance.

## Sequence 449 — perf-image-levels — CPU equivalence and connected replay verified

CPU image preparation previously rewrote every RGB byte even when gamma/intensity
tables were identities. It now composes the two byte lookups at initialization
and skips identity passes. Nonidentity mappings retain the same integer lookup
results. The actual mip/color implementation is exposed to a pure CPU profiling
target, `zig build bench-image-levels`, with the actual bundled PNG decoder,
discarded warmup and complete uploaded-mip SHA-256/metadata output. It initializes
no window or graphics device. Evidence: `zig-out/reports/perf-image-levels-449/`.
Seven alternating fresh-process trials per implementation, with discarded warmups
and two measured preparations each, reduce median preparation 65.816 → 46.049 ms
for the 4096² RGBA fixture and 71.935 → 52.145 ms for the RGB fixture. Every
uploaded-mip SHA-256 matches. A 64-case equivalence matrix also matches all mip
bytes, dimensions, skip/count, alpha and average-color metadata across actual
textures, gamma/intensity changes, plain/unscaled paths, picmip/device limits,
odd/small widths and a final transparent pixel. The pure CPU benchmark links only
libc; no graphics library/device is initialized. The full build passes 85/85 steps.
Connected renderer replay is verified together with sequence 450, as recorded
above, rather than repeating the same scenarios between related CPU changes.

## Sequence 448 — perf-image-commit — complete-admission comparison passed; shader issue open

The pending-image trace shows small weapon skins decoding in under a millisecond,
then waiting for the one-image-per-frame upload gate. Deferred uploads now admit
at most eight images and 4 MiB per frame. One oversized image may progress by
itself, preserving the prior large-texture behavior. Decoding, mip generation,
pixels, texture resolution and fresh bindless-slot ownership are unchanged.
Per-commit byte/time counters expose the actual burst. Evidence workspace:
`zig-out/reports/perf-image-commit-448/`, with an exact baseline runtime. The
integrated build passes 85/85 steps. Three alternating trials per implementation
use identical assets and fresh private Mesa disk caches, requiring zero pending
and failed images before readiness/captures. Median direct first-map readiness
changes 4.679 → 4.380 s; two save loads change 4.437/4.382 → 3.980/4.029 s.
Initial New Game varies 3.873/3.722 s, without isolating a batching-specific gain.
Input timings are recorded separately; the first save's median input readiness
is essentially unchanged at 3.727/3.728 s. This gain is completion of image
admission after input restores, not faster simulation or reduced texture quality.

Logs show at most six images/1,441,784 bytes in a measured batch, within both
bounds. Median fresh-process peak RSS is essentially unchanged, 2,662,604 versus
2,662,472 KiB. Individual software-driver commit calls may still block (maximum
207 ms observed); this does not claim all frame stalls are eliminated. Source
configuration/save hashes remain unchanged across all six runs.

GPU-AV completes all four fixtures but reproduces the preexisting fragment FMax
NaN report at SPIR-V instruction 4315, also seen before this change in sequence
446. No buffer/lifetime/API error is reported. This later replay means the earlier
zero-NaN run does not establish general shader numerical acceptance; the arithmetic
issue remains open. Shader source is unchanged by the upload scheduling change.

## Sequence 447 — perf-admission-ready — complete-admission scenario verified

The Vulkan backend exposes owner-thread deferred-image pending/failure counts.
The loading probe separates first processed input from complete CPU image
admission, waits for decoding/mip preparation/commit before its readiness mark,
and refuses a failed placeholder. Captures then fence the submitted uploads.
Synchronous GL backends retain their existing readiness definition. Evidence
workspace: `zig-out/reports/perf-admission-ready-447/`. The full build passes
85/85 steps; current headless software-Vulkan New Game/first-map/two-save replay
passes with zero validation errors, zero failed placeholders, and original source
configuration/saves unchanged. Ownership remains R1–R11 zero; the adapted skill
validates. No duplicate runtime aggregate was run for these renderer/tool changes.

The single diagnostic sample finds two deferred images still pending on the first
map and six after each save restores input. First-map input is observed at
3.070 s and zero pending images at 4.728 s; the two saves observe input at
3.774/3.675 s and zero pending at 4.529/4.482 s. These are observed upper bounds,
including command delivery/frame waits, not isolated worker times or speedups.
New Game's first status response already reports zero pending images. The probe
now prevents snapshot-ready timing from being mistaken for completed admission.

## Sequence 446 — perf-pipeline — cache rejected; software-renderer fixes verified

The software-Vulkan baseline crashed while capturing its first scene. Khronos
validation identified VUID 00605: color/motion attachments use different blend
states, but independentBlend was not enabled. Device qualification/creation now
require/enable the feature. GDB also identified a null lighting-buffer load in a
lavapipe worker. Zero-light views now supply one neutral 32-byte record while
keeping the actual light count zero. This removes the observed crash. The later
sequence-448 numerical finding limits the earlier zero-NaN observation. No
lighting feature or quality setting is disabled.

Evidence: `zig-out/reports/perf-pipeline-446/`. Both ordinary Khronos validation
and instrumented GPU-AV runs complete New Game, direct first map and both copied
saves, with zero validation errors and inspected captures. The full native build
passes 85/85 steps. These are focused software-renderer scenarios; physical-GPU,
complete campaign and artistic acceptance remain separate.

The in-memory Vulkan pipeline-cache candidate was compared using the corrected
renderer, identical shaders and a fresh private Mesa disk-cache directory for
each trial. Three alternating trials per setting each create the same 27
pipelines. Median total compilation is 1,274.223 ms without the candidate and
1,265.822 ms with it: no material gain established. The candidate was removed;
its source and exact runtime remain in the report. Developer compilation timers
remain for subsequent profiling. Snapshot/input timings from that experiment do
not establish completion of deferred texture admission; sequence 447 checks it.

The loading probe now retains crash reports before deleting disposable profiles,
kills a private engine after failed graceful shutdown, preserves source hashes on
failure, and supports longer response bounds and batch GDB traces. Ordinary input
keeps its five-second default; all 14 input-tool tests pass. Original configurations
and saves remain unchanged. The optimization loop remains active.

## Sequence 445 — perf-inflate — match copying verified; loop ongoing

The bundled inflater now fills distance-one output matches and uses memcpy only
for disjoint matches of at least 16 bytes. Other overlapping matches retain
upstream forward copying; window handling, bounds and format/checksum admission
are unchanged. The alterations are marked in the source and upstream notices
remain intact. No new library or runtime dependency was admitted.

Evidence: `zig-out/reports/perf-inflate-445/`. Five alternating fresh-process
trials per configuration, each with one discarded warmup and two measured decodes,
reduce the RGB fixture's median decode 147.664 → 136.036 ms and inflate
118.825 → 107.485 ms. RGBA decode is approximately unchanged (269.034/273.759 ms),
with inflate 193.176/192.352 ms. All decoded pixel CRCs match. These are decoder
measurements, not a claimed whole-game loading or physical-GPU rendering gain.

The full native build passes 85/85 steps. All 400 Zig runtime tests and the other
C contracts pass; the new inflater boundary fixture initially failed because its
manually transcribed compressed bytes were truncated (system zlib also rejected
them). Regenerating the independent fixture repairs the test; focused PNG/C worker
checks pass 3/3 steps. Coverage combines 1/7/full-byte input chunks with 1/257/258/
8192-byte output buffers across repeating matches and sliding-window boundaries.
Current headless software-GL2 New Game and both copied save loads pass. Source
configuration/saves remain unchanged. No duplicate 400-test aggregate was run
after the test-only fixture correction. The performance loop remains active.

## Sequence 444 — perf-png-input — lower scratch memory verified; loop ongoing

Single-IDAT PNGs now borrow the already validated contiguous immutable compressed
input through inflation, avoiding a redundant allocation/copy. Multi-IDAT images
retain their existing concatenation path. The input owner outlives inflation;
borrowed input is never freed by the decoder. Exact output bounds, zlib checksum
and trailing-input rejection remain unchanged.

Evidence: `zig-out/reports/perf-png-input-444/`. Five fresh-process comparisons
retain exact pixel CRCs. The single-IDAT RGB fixture reduces median peak RSS
153,296 → 134,788 KiB. Timings do not establish a consistent decode speedup.
A broader multi-IDAT streaming candidate reduced memory but regressed RGBA decode
287.714 → 347.349 ms; it was reverted. This pass claims the smaller memory gain.

The full native build passes 85/85 steps; runtime checks pass 23/23 steps and
400/400 tests plus C contracts. Added independent IDAT repackaging covers every
split of the fixture stream, empty IDATs, bytewise fragmentation and trailing
nonempty input. The first contract failure was signed overflow in the test-only
CRC byte-swap helper; unsigned byte stores repair it. Current New Game and both
copied save loads pass via dkguard software/headless execution. Source-save and
configuration preservation checks pass. The ownership baseline remains zero.

## Sequence 443 — perf-admission — shared CRC/hash reads verified; loop ongoing

Converted package admission now derives canonical gameplay entry SHA-256 values
during its complete CRC-checked reads, instead of decompressing gameplay packages
again. Reads use bounded 1-MiB blocks. Compatibility retains package order,
sorted entry order, lowercase names, directory exclusion and duplicate-name
semantics; every cosmetic entry still receives its CRC check. The separate full
package SHA-256 checks remain mandatory.

Evidence: `zig-out/reports/perf-admission-443/`. Seven alternating focused trials
per implementation have medians 2.539 → 2.184 s and identical compatibility SHA.
Heavy concurrent host workloads produce wide timing ranges. Three full preparation
trials per implementation have medians 5.832/5.635 s but overlapping, noisy ranges
(baseline 5.539–7.071 s, combined 5.559–9.072 s); these do not establish a reliable
whole-preparation gain. All six retain the same installation-generation identity.
Eight installation tests pass, including both ZIP storage methods, multi-block
entries, empty entries, canonical ordering, and gameplay/cosmetic CRC corruption
with matching package SHA-256. No runtime code changed in this pass.

## Sequence 442 — perf-identity — parallel full hashes verified; loop ongoing

Installation identity still hashes every product in full. Large builds now use
at most four independent readers, scheduling large files first; small builds
remain sequential. Failure joins the workers before returning, and published key
order and SHA-256 values are unchanged. No admission check is skipped or cached.

Local evidence: `zig-out/reports/perf-identity-442/`. Three alternating warm
preparation trials per configuration reduce the median 7.506 → 5.823 s against
the immediately preceding implementation. All six retain the sequence-441
installation identity. Six installation tests pass, including worker failure,
cleanup and a subsequent successful reread. This measures warm preparation with
private assets, not compilation, cold publication or game loading. Runtime code
was unchanged; no duplicate native aggregate was run.

## Sequence 441 — perf-prepare — complete warm preparation comparison passed

Local evidence: `zig-out/reports/perf-prepare-441/`. A private development prefix
was seeded with independent Btrfs CoW files, preserving source inode permissions
and original installations. Publication/copying is excluded from measured trials.
The existing-generation preparation path runs all package CRC/hash checks,
compatibility generation and installation identity construction. The reconstructed
baseline uses the retained original neural validator and uncached campaign
derivation; optimized trials use the current streaming/parallel validator and
validated derivation cache. All other stages and inputs are identical.

Three alternating trials per configuration reduce median preparation 21.469 →
7.462 s. All six produce exactly the same installation-generation identity,
`d12de96805a7d7bf23358c36aa813bca1e13b5b6549a895d3cf4c60bc4d3d844`.
The original material overlay's SHA-256 remains unchanged. This is the full warm
preparation function, not Zig compilation, cold publication or game-menu time.
The loop remains active; repeated hash/check overhead is a next profiling target,
not an implemented or claimed additional optimization.

## Sequence 440 — perf-derived — warm authoring reuse verified; loop ongoing

Development installation previously regenerated the campaign authoring manifest
from all maps on every invocation. The derived output is now reused only when
the already-verified map-package SHA-256, derivation/parser source hashes, Python
version and output SHA-256 match its private receipt. Missing, damaged, changed or
incompatible cached data is regenerated. Publication is locked and atomic; a bad
new map does not replace the prior output. Package hash/CRC admission still runs.

Local evidence: `zig-out/reports/perf-derived-440/`. Three uncached derivations of
the same installed maps take a median 1.526 s. A cache miss takes 1.471 s; nine
warm derivations take a median 0.091 ms after the caller's package verification,
with identical output SHA-256. This excludes package validation and is not a
whole-launch claim. Eight campaign tests and five installation tests pass,
including output corruption, changed map geometry, changed tooling and failed
new input preserving old output. No runtime aggregate was repeated for this
Python-only change.

## Sequence 439 — perf-png-threshold — candidate rejected; verified implementation retained

An alternative SIMD predictor used endpoint thresholds in place of three Paeth
distances. Nine direct-decoder samples measured filter-stage medians 60.495 and
59.979 ms, which do not establish a material gain. The candidate was reverted;
the production decoder matches the verified baseline source SHA-256 exactly.
Evidence and the rejection remain in `zig-out/reports/perf-png-439/`. Exhaustive
predictor coverage was retained for the existing implementation: all 16,777,216
byte triples across four lane permutations, in addition to scanline/PNG/caching
contracts. The focused `zig build test-png --summary all` passes 3/3 steps;
the actual contract executable takes 100 ms. No new end-to-end speedup is claimed.

## Sequence 438 — perf-png-cache — bounded cache verified; loop ongoing

The remaining measured loading cost includes decoding identical large textures
after renderer content resets. The owner-thread PNG loader now retains a bounded
initial working set of immutable source bytes and canonical RGBA pixels across
map resets. Cache hits require equality of every source byte, and return a new
renderer-owned copy before gamma/mipmap/material processing. Missing, changed or
damaged files cannot use a path-only stale result. Background decode workers keep
their existing independent lifetime and never access this cache.

`r_imageDecodeCacheMegs` defaults to 256 MiB, may be disabled with 0, and is capped
at 1024 MiB. Both encoded input and decoded output count against the bound; only
images with at least 32 MiB of decoded pixels are eligible, and entry count is
bounded to 16. A full cache skips new admissions rather than thrashing its initial
working set. GL1, GL2 and Vulkan clear it on full renderer shutdown. Lowering the
budget clears retained data on the next PNG request. No texture quality is reduced.

Local evidence: `zig-out/reports/perf-png-cache-438/`. Three software-GL2 headless
samples per cache setting, with identical executable/modules/maps/overlays/saves,
change median direct-e1m1a readiness 3.916 → 3.133 s and two save-load medians
4.513/4.470 → 3.847/4.060 s. Logs confirm reuse of three large images, retaining
251,946,208 bytes including their encoded inputs. These are warm-cache gains;
initial New Game does not gain a cold-decode improvement from caching.

A separate fresh-process resource sample checks the cost: cache off peaks at
1,576,600 KiB RSS, 256 MiB at 1,820,480 KiB, and 512 MiB at 2,099,276 KiB. The
512-MiB experiment loads the two saves in 3.330/3.592 s in its single trial; that
does not change the conservative 256-MiB default or establish a three-sample median.
Timing variation and software-renderer limits still apply.

The integrated build, source-preservation checks and headless scenarios pass.
`zig build test-runtime -j4 --summary all` passes 23/23 steps, 400/400 tests and
the C contracts. Added actual-loader checks cover caller-copy isolation, aliases,
same-length corrupt source replacement, disable/shrink behavior, admission limits,
entry bounds and full cache cleanup. Ownership remains zero for R1–R11. Native
Vulkan shutdown is built, but its visual/hardware behavior is not claimed by GL2
headless acceptance. Further optimization work remains active.

## Sequence 437 — perf-frame — measured; software-backend limit recorded

Local evidence: `zig-out/reports/perf-frame-437/`. A headless software-GL2 opening-map
fixture runs ten seconds after admission/warmup with `com_speeds 1`, at 960x540,
HD overlays, uncapped FPS and unchanged quality. Across 419 frames, median total
frame work is 24 ms, including 21 ms in the renderer backend; game work is below
the timer's one-millisecond resolution. The total-frame p95 is 30 ms. There are
no invalid-model-frame warnings in this fixture. This supports further loading
work rather than an unmeasured game-simulation rewrite. No physical-GPU throughput
or complete gameplay/rendering acceptance is inferred.

## Sequence 436 — perf-package-stream — verified; loop ongoing

The next measured cost was CPU-bound validation of independent ZIP entries.
Admission streams SHA-256/CRC checks in one-MiB blocks, hashes the base package
without a whole-file allocation, and uses at most four workers for archives above
32 MiB. Small packages remain sequential. Workers own their decompressor/hash
state; `ZipFile` serializes shared-file access, and all workers join before the
archive closes, including exceptions/cancellation. Required validation is retained.

Local evidence: `zig-out/reports/perf-package-stream-436/`. Three alternating trials
in fresh processes, with identical validation-receipt SHA-256, reduce median
admission from 6.280 to 2.625 s. Median process peak RSS falls from 489,836 to 51,440
KiB. The tradeoff is higher total user CPU (5.154 → 7.241 s), bounded to four workers,
for lower latency and memory. The earlier original validator took 12.897 s.
These are package-admission results, not whole-application launch timings.

Six package tests and five installation tests pass, including concurrent integrity
failure propagation and a healthy reopen after a failed worker. Runtime/renderer
code was not changed in this iteration, so its still-valid 434 runtime checks were
not repeated. Further work remains active.

## Sequences 434–435 — perf-loop — initial optimizations verified; loop ongoing

The owner requested a continuing optimization loop on 1 November 2026. The local
`.agents/skills/perf/SKILL.md` adapts codefang's measurement-first workflow to
dk3's Zig/C ownership, headless-only runs and integrated verification cadence.
No desktop input, physical display runs, deployment or Git operations are part
of the loop. The preserved installation, profiles and saves remain untouched.

**434, PNG decoding.** Direct measurements of the actual bundled decoder separated
inflate from filter reversal. Linux sampling was denied by the host's perf/MAC
policy; the retained logs record that limitation. The `bench-png` build target
provides actual-decoder stage timings, a discarded warmup, output CRCs and process
resource counters without a renderer or desktop. Fixed 4096x4096 RGBA and RGB
fixtures measured nine times give median decode changes of 394.825 → 290.006 ms
and 194.152 → 158.160 ms. The RGBA filter stage changes 147.328 → 61.646 ms.

The decoder dispatches the PNG filter once per scanline, copies 8-bit RGBA rows,
specializes opaque RGB conversion and uses SSE2's independent byte channels for
four-channel Paeth prediction, retaining the scalar path on other architectures.
Predictor ties and byte wraparound remain exact. Both real inputs retain their
baseline decoded CRCs; forward-encoded tests cover all five filters, channel
strides 1–8, first rows, leading bytes, malformed streams and worker cleanup.

Local evidence: `zig-out/reports/perf-png-434/`. A controlled replay uses the exact
sequence-433 baseline renderer recovered by SHA-256, with current executable/game
modules and identical packages/profile/save fixtures. Three headless software-GL2
samples per variant show median direct-e1m1a readiness 4.161 → 3.952 s and save
readiness 4.972/5.006 → 4.771/4.777 s. Intro readiness is effectively unchanged
(2.687 → 2.695 s); the decoder microbenchmark gain is not the total-load gain.

**435, neural-package admission.** Validation previously decompressed the archive
for a CRC pass, read every entry again for SHA-256, and reread PNGs for their
signature. Complete `ZipFile.read` already verifies CRC. Admission now shares a
single image read between the hash and signature checks and omits the redundant
archive pass; namespace, exact-base identity, ZIP32, CRC, per-file SHA-256, PNG
signature and skeleton validation remain. CRC failures are normalized to the
existing admission error. Payload buffers are released before the next entry.

Local evidence: `zig-out/reports/perf-package-435/`. Three alternating before/after
trials on the same 2.1-GiB package reduce median validation 12.897 → 6.270 s and
user CPU 10.659 → 5.292 s. These are validator timings, not whole-launch timings.

Validation: the integrated native build and headless loading scenarios pass;
`zig build test-runtime -j4 --summary all` passes 23/23 steps and 400/400 tests
plus the actual PNG/engine C contracts. Five package tests and five installation
tests pass, including damaged payload/manifest CRCs, bad SHA-256, bad PNG signature,
ZIP64 refusal and preservation of existing installations/saves. The ownership
baseline remains zero for R1–R11. Further measured optimizations remain active.

## Sequence 433 — loading-performance — headless stage measurements passed

Investigated 1 November 2026. Developer timing now separates UI save validation,
engine save validation/staging, filesystem restart, collision loading, gameplay
spawn, save read/decode, and restoration. Existing client resource timing remains.
`developer 1` enables `dk3_menu_loading new-game` and `dk3_menu_loading load <slot>`;
these invoke the actual menu actions, including `Browser.validate`, through the
command pipe without keyboard, mouse, window focus or desktop access.

`dkq3/tools/runtime_loading_timing_probe.py` runs under `dkguard --headless` on a
private 960x540 X display, software OpenGL2, dummy audio and temporary profiles.
It copies the supplied configuration and saves, records runtime/package/source
hashes, checks that source configurations/saves remain unchanged, and requires
observed cinematic/normal input plus completed screenshot files. The opening
movie's playback duration is excluded; the first playable map is a separate
direct-map timing fixture. These are loading diagnostics, not campaign acceptance.

Private evidence: `zig-out/reports/loading-performance-433/`. Each completed
configuration has three samples, each with New Game, direct e1m1a, and two copied
e1m1b saves (796,907 and 725,677 bytes). Medians, seconds to observed readiness:

| Runtime/assets and entry path | New Game / intro | Direct e1m1a | Arrival save | Latest autosave |
| --- | ---: | ---: | ---: | ---: |
| Preserved installed runtime and stock assets, console baseline | 1.064 | 0.922 | 1.130 | 1.131 |
| Instrumented current runtime, installed stock assets, UI actions | 1.168 | 0.975 | 1.029 | 1.083 |
| Instrumented current runtime, same stock maps plus development HD/neural/material overlays, UI actions | 2.648 | 4.146 | 5.047 | 5.024 |

The installed-runtime console baseline omits the Zig UI's extra validation and
is labelled accordingly. `headless-stock-gl2-001/` and `headless-hd-gl2-002/`
exercise that validation through the real action handler. The original development
installation has different e1m1b geometry, so `matched-hd/` references the installed
stock maps with the existing development cosmetic overlays; this prevents a save
geometry mismatch from confounding the comparison. No source assets are rewritten.

Across the six UI save loads in each configuration:

| Measured stage | Stock, ms | HD overlays, ms |
| --- | ---: | ---: |
| UI read, full snapshot decode/validation and cleanup | 7–10 | 6–11 |
| Engine portable validation and internal save staging | 8–14 | 8–13 |
| Filesystem restart | 41–45 | 73–83 |
| Server collision load | 13–18 | 13–15 |
| Gameplay spawn | 16–23 | 16–18 |
| Server snapshot decode | 6–8 | 6–7 |
| Gameplay restoration | 35–50 | 32–40 |
| Complete engine server initialization (includes several rows above) | 131–144 | 159–181 |
| Client model registration | 167–216 | 3,720–3,889 |

HD save-load image diagnostics account for 2,716–2,808 ms of reading/decoding
and 479–537 ms of preparation/upload inside model registration. Initial e1m1a
model registration takes 3,244–3,546 ms with overlays versus 181–187 ms stock.
The supplied 4096x4096 character PNGs load synchronously during model registration;
ordinary map loading tears down renderer content, so later loads repeat the work.
This is the measured dominant HD loading cost. Save validation, entity setup and
restoration do not explain the several-second HD difference. Nested stage timings
must not be added together, and image diagnostics omit individual loads below
their logging threshold.

The larger installed-game delay reported by the owner remains unreproduced in
these headless CPU-path measurements. Hardware behavior and cold-cache storage
performance are not inferred. The probe records frame capture as an upper bound
including readback, encoding and polling; readiness timing excludes that work.
Earlier fullscreen/windowed GPU attempts were abandoned at the owner's request.
Two software Vulkan attempts crashed during the opening-frame capture; their
failure logs remain in `headless-stock-001/` and `headless-stock-002/`. Neither
those failures nor the mismatched-map setup are counted as passing timings.

Validation: the native build and `zig build test-runtime -j4 --summary all` pass
(23/23 steps, 400/400 tests and the C engine contracts). The ownership baseline
remains zero for R1–R11; changed Zig files pass formatting checks. A separate
headless scenario confirms that the diagnostic command cannot start a map with
`developer 0`, and that an absent save is refused without starting a server.
The probe also checks that its display is served by Xvfb before creating an engine
process, rejecting desktop execution even if software-rendering variables are set.

## Sequence 427 — game-state-assessment — focused input and persistence replay passed

Assessed 20 October 2026, after PR #1 merged the native runtime into `main`.
The [current game state](status.md) replaces the stale prototype-era summary.
Current source identities are protocol 1351, renderer ABI 13, native save schema 2
and portable save codec 1. A source/evidence review covered class registries, review
sheets, local result artifacts and later renderer documentation.

Fresh runs used an immutable `zig build play-install` generation with existing local
assets/overlays. The accepted replays used `dkguard --headless --screen 960x540
--mem 8G --timeout 180s`, software OpenGL1 and temporary profiles/saves.
Installation/module/asset identity:
`98392cd5628d6695e4acefd2a6f7c0361a750a438d4e71d4455fced1544547a1`.
Private evidence: `zig-out/reports/game-state-427/`.

| Scenario | State | Scope and limits |
| --- | --- | --- |
| Isolated current-code installation | Passed | Completed existing assets, current engine/modules, preserved installation/saves untouched |
| Normal input after admission | Passed | Processed forward input moves the player more than eight units; release and crouch input acknowledged. Diagnostic health setup; no authored-route claim |
| Save/load after admission | Passed | Save at health 997, change to 900, load restores 997 and normal processed input on e1m1a |
| Resident region and death recovery | Passed | Controlled e1m1a/e1m1b transfers, independently changed actors, player identity, health 73, native save/load and actual death checkpoint restore. Diagnostic transfers/placement/health, not campaign traversal |
| Legacy movement/save fixture startup | Invalid setup; retained | Started before region admission committed. Missing movement diagnostics and `RegionAdmissionInProgress` save refusal do not establish gameplay regressions. Replayed with the existing state-synchronized driver |
| Full campaign, multiplayer matrix and Vulkan visual acceptance | Unrun in this assessment | Earlier focused evidence retains its original scope |

The engine manual and public documentation site are built from reviewed Markdown,
with search, class reviews and historical records. Site verification includes strict
build, all rendered internal links/anchors, search indexing, desktop/mobile navigation
and inspected browser captures. No proprietary packages or local report artifacts
are included in the website.

## Sequence 426 — sidekick-hazards — implemented; focused scenarios passed

**Change.** Sidekicks kept walking into lava, slime and liquid nitrogen and sank in water. Gold had the same weaknesses, so this is a recorded deviation. The shared pilot gains `careful_footing` and `tread_water` capabilities, which companions set. The brain no longer settles under water, in water the leader is not in, or below its spot. A new catch-up warp brings a stuck companion beside the leader out of the leader's sight. The route graph already classes nitrogen as lava (bspc `map_q3.c`, since commit c0448ef); that graph is in the asset generation of 11 October (`zig-out/assets/current`), not in the older `zig-out/play/current` installation.

Runs used the current engine built into `zig-out/engine-426` with that asset generation and the game from `zig-out/native-dev`: `runtime_player_probe.py --engine zig-out/engine-426 --prefix zig-out/native-dev --scenario <name>`. Evidence is in `zig-out/reports/runtime-zig-426/<name>/`.

| Defect | Change | State and evidence | Limits |
|---|---|---|---|
| Steps into lava, slime or nitrogen at a run, on ice, on straight steering, by hops | Look-ahead as far as the body slides before stopping (further on slick floor), straight steering guarded, hop landings checked, slides counter-steered; in lava or slime it climbs out to the nearest dry floor (rings out to 576) | Passed. The player stood on pool rims in turn for 70 s each map, with monsters removed and Superfly at 10000 health. `sidekick-lava` (e3m3c, 8 rims of 19 pools) and `sidekick-slime` (e2m5c, 9 rims of 27 pools): never in liquid at a 1 s sample, no health lost. `sidekick-nitro` (e1m6c, 5 rims of 6 pools): never in nitrogen and alive, which rules out contact (contact kills within 3 s) | Samples are 1 s apart. Knockback still lands where it lands. Nitrogen stays fatal after contact. On e1m6c Superfly lost 5 health on dry floor away from the pools; the cause was not identified. Slick-floor braking has no in-game scenario |
| Sinks in water | Treads water and rises unless the route dives; the stroke compensates for aim pitch; never settled under water or in water the leader is not in; with no free follow spot there, heads for the leader instead of holding still | Passed. `sidekick-water` (e1m1c): follows the player under water for 60 s at full health. `sidekick-surface` (e1m1c): with the player dry at the map's start, Superfly leaves the pool; never more than 1 s under water | In `sidekick-surface` the way out of the pool to the start is long: he was brought out by the `stuck` catch-up, not by swimming out |
| Stuck far from the leader forever | `companion_catchup.zig`: further than 1536 for 3 s; 8 s without getting 64 closer beyond 512 or in water the leader is not in; 2.5 s in lava or slime or with no way out; 2.5 s of air left. It warps to safe footing that the leader cannot see (rings round the leader behind first, then the leader's trail), only when the departure is unseen too, except for rescues from liquid. Not under an order, stop, authored action, cinematic, collection or carrying | Passed. `sidekick-catchup` (e1m4b): the player moved 2850 units away; Superfly warped (`far`) and settled 64 units from him. `sidekick-stop` (e1m4b) still holds him at a stop node | Being unseen is judged by the server's sight test, not by the capture. No warp across resident worlds. In the rim scenarios the player jumps between distant pools, so `far` and `stuck` warps happen there too |

Unit tests: 399/399 runtime tests pass, including stopping reach, lethal liquid ahead, landings of hops, the nearest dry floor out of a pool, settling rules and catch-up timing. The class-ownership lint passes.

## Sequences 424–425 — play-feedback-fixes — implemented; focused scenarios passed

Owner-reported defects from play. Evidence is in `zig-out/reports/runtime-zig-424/`, from installation
`4b47f7…` (and later reinstalls with the same source plus timing prints). These runs are diagnostic
fixtures, not campaign acceptance.

| Defect | Change | State and evidence | Limits |
| --- | --- | --- | --- |
| Crox found dead | The new `amphibious` trait (crox, froginator, pipe and plague rats): water never drowns them, as with the reference's MOVETYPE_SWIM switch | Passed: `crox/`. A submerged Crox keeps 150 health after 32 s of game time; the shared land rule had killed it in 21–27 s | Lava, slime and nitro rules are unchanged |
| Rats never attack and stay in one spot | Ground support and line-of-travel probes test world geometry only (a chased body is not a missing floor). Rats fall back to the node graph where the player areas have no route | Passed: `rats/`. Plague and pipe rats spawned about 200 units off on a diagonal close in and bite (health 1000 → 997 and 995) | Nest routing in e4m1c pipes is not driven. The before/after comparison could not run: the old installation does not start with the current staged modules |
| Sidekick command window never shown | Gold HUD cycle `hud_cycle`/`hud_next`/`hud_prev`/`hud_use` (o, k, l, ;). Saved profiles get the missing binds once (`dk3_binds 2`): `companion wait/pickup` are renamed and `o attribute_increase` becomes `hud_cycle` | Passed: `sidekick-hud/`. The binds are added to a profile without them; the cycle opens Superfly's and then Mikiko's window and orders each | `default.cfg` in `dk3-base.pk3` changes only after the next asset generation |
| Sidekicks do not wait or catch up | Reference stop nodes (NODETYPE_STOPSIDEKICK) load and take precedence over teleport nodes; the first sidekick says the node's line. A stop holds without rewriting the order. A teleport node ends it; a flagless teleport trigger keeps it. A stranded sidekick retries after 1 s (at most 2 s), not after 4–16 s | Passed: `sidekick-stop/` on e1m4b: Superfly waits stationary for 5 s while the player leaves, then the teleport node sends him on and he follows | Gold has no automatic distance warp, so none was added. The stop line's audibility and the second sidekick's 1 s stagger are not qualified. Stranded retry is unit-tested only |
| Superfly drowns following the player into water | Party members breathe like the player: 12 s of air, refilled whenever the head is above water. The old rule refilled only when fully out of the water, and the damage ramp kept growing from the first time air ran out. The shared bot pilot measures the distance to air straight above (up to 1024 units) and starts rising in time to reach it. Under a ceiling it swims to the nearest open water with air above, else back to where it last breathed. Before, it surfaced only after 9 s and only with air within 160 units | Passed: `runtime-zig-425/sidekick-water/` in e1m1c's 704-unit pool. Superfly follows the player to the bottom, rises about 400 units in time, breathes and dives again, at full health for 60 s. Before the fix he sat 270 units down and drowned, health falling faster and faster. A unit test covers repeated dives | Escape from under a ceiling is implemented but not tested in game: the only covered spot found (e1m2a) is an enclosed shaft with no way out |
| Robot gib chunks visible through walls | Mechanical chunks used their robot's plain skin name as a custom shader. No script defines that name, so registering it from a module made the 2D GUI shader, which has no depth test (GL1 and Vulkan alike). They now use the scripted `@alpha` variant, which is depth-tested and opaque at alpha 255 | Passed: `runtime-zig-425/robot-gibs/`. A destroyed lasergat's chunks render lit and opaque in view | Occlusion behind walls follows from the shader's depth test. The behind-wall capture was inconclusive (the robot outside the visible set is never sent) |
| Processing (e1m5a) conveyors empty | Trains leave their first corner at once by the reference train_find rule. START_ON leaves even a wait-for-trigger corner, so `4am` carries its body parts down the belt at load. The timed chopper and pile cycle after the trigger was already ported | Passed: `runtime-zig-425/conveyor-meat/`. `4am` crosses the belt from x −712 to 483 after load with no trigger, then waits at slice1 | The cycle that repeats every 20 s after the trigger was observed only in the investigation's diagnostic run |
| Freezes around level transitions | Model and skin PNGs registered during play decode and mip on workers behind a placeholder, one commit a frame. Save pictures are sampled to 400×300 from host-cached readback memory, and the old name check that skipped the downscale is fixed. The checkpoint is a hard link (`G_DK3_SAVE_LINK_V1`), not a read-back copy | Measured with `--gpu` (`transition-admission/`, `transition-crossing/`): next-region model admission went from 330–510 ms frames to at most 45–68 ms. Save capture went from about 220 ms to 4–7 ms. A seamless crossing now peaks at one frame of about 100–120 ms | That remaining frame is the arrival autosave (about 87 ms: resident capture 27, region capture 14, validation decode 32) plus the RT world build (about 20 ms). Map loads behind the loading screen are unchanged |

## Sequence 374 — hd-weapons-part-pipeline — implemented; visual acceptance open

The [HD weapon pipeline](hd-weapons.md) inventories all 28 classes, validates
source-compatible IQM replacement packages, and assembles authored rigid parts
on source animation frames. An isolated Glock preview now contains a world
model plus first-person gun, glove, and forearm parts. Guarded OpenGL2 idle,
firing, and pickup captures loaded both replacements; firing consumed one
round. The cuff anchor and remaining fused gun details need motion review. No
HD weapon is selected by default; articulated acceptance and the other 27
weapon assets remain open.

## Sequences 358–373 — vulkan-remaster — implemented; owner visual acceptance open

The owner directed the remaster roadmap in [vulkan-remaster.md](vulkan-remaster.md)
to completion after milestone 1. Every item below is implemented. Each one only
passed a lavapipe smoke run (`dkguard --headless`, 1280x720, e1m1a), which shows it
runs and composites. None is verified: the owner asked to judge visuals in game,
and the RT tier still needs a `--gpu` run on the RTX 5090.

Also fixed in this pass: the native client set `refEntity.dk3World` to the network
world id instead of the renderer's world handle (`client.zig`, `owner.render`).
The two numberings only matched under OpenGL, so Vulkan dropped every model
except the view weapon.

| # | Slug | State | Smoke evidence (`zig-out/reports/vulkan-remaster/`) |
| --- | --- | --- | --- |
| 358 | `vulkan-renderer-hdr-pbr-core` | Implemented | `rm1/` |
| 359 | `native-runtime-environment` | Implemented (underwater composite from brush contents) | `water1/` |
| 360 | `vulkan-renderer-water` | Implemented | `water1/` |
| 361 | `vulkan-renderer-volumetrics` | Implemented; extinction tuned against e1m1a fog | `vol2/`, `vol3/` |
| 362 | `vulkan-renderer-taa-fsr` | Implemented; `r_vkRenderScale 0.5` vid_restart smoke | `taa1/` |
| 363 | `vulkan-renderer-weather-gpu` | Implemented; new syscall `CG_DK3_R_WEATHER_V1` (716) | `wx1/`, `wx2/` |
| 364 | `vulkan-renderer-clustered-lights-shadows` | Implemented | `sh1/` |
| 365 | `material-sidecars` | Implemented: 3,960 sidecars, 3,851 normal maps in 6 s | `mat1/` |
| 366 | `vulkan-renderer-rt-shadows-reflections` | Implemented: lavapipe builds 16,208-triangle structures for e1m1a | `rt1/` |
| 367 | `vulkan-renderer-ddgi` | Implemented | `gi1/` |
| 368 | `lightmap-rebake-directional` | Implemented: 25 e1m1a pages baked progressively | `bk4/` (direction view), `bk5/` |
| 369 | `vulkan-renderer-path-tracing` | Implemented, off by default; ray facing flipped for Quake 3 winding (also fixes DDGI validity) | `pt3/` (mask, lighting), `pt4/` |
| 370 | `vulkan-renderer-m1-gaps` | Beams/rails/lightning and model shadows implemented; material scan Passed (`definitions=7086 unknown_keywords=0`, `final1/`); AVI Blocked: `demo` playback stops at once, so `video` refuses | `final1/`, `avi1/` |
| 372 | `vulkan-renderer-lighting-scale` | Implemented from the owner's second set of screenshots ("everything is white"): remaster lightmaps now normalise each texel like the original (`world.linearLight`, brightest channel capped at white with a quarter stop of headroom) instead of keeping the full x4 overbright range that lit surfaces up to 21x; dynamic lights add at that scale; the composite defaults to Khronos PBR Neutral without its black toe (`r_vkTonemap 0`, AgX stays as 1; `r_vkSaturation` 1); auto exposure adapts within [0.75, 1.25]; the baked-light sheen uses a roughness floor of 0.5; authored fog coverage is remapped to the original display-space blend with dynamic-light glow kept in its own froxel pair; opaque model pixels mark HDR alpha so TAA stops accumulating history over moving limbs. Headless e1m1a: mean luma 0.314 -> 0.124 (classic 0.086), saturation back to the classic range. A locally extracted validation layer (`val5/`) found two device-creation omissions, fixed: update-after-bind storage images and shader demote need their features enabled. PBR dynamic lights now cap at the light's own colour (they peaked at ~50x at the source). Against an OpenGL1 capture of the same cutscene shot (`cine-gl1b/`), the remaster character was ~1.4x too bright with grey hair and skin: the probe ambient now may at most double the grid ambient and emissive surfaces count at most 0.5 in the probe gather; model skins get specular 0.4; `r_vkDebugView 6`/`7` show texture colour / light only. Found on the RTX 5090 (`gpu*/`, `wf*/`): distant objects turned white from Schlick Fresnel rising to 1 at grazing angles (now limited by roughness and specular strength; model skins specular 0), and waterfalls were drawn as pool surfaces (vertical faces now keep their authored stages); both match OpenGL1 captures of the same views. Open: the intro map faults lavapipe in shader code after the froxel passes (`r_vkVolumetric 0` avoids it); the owner's screenshots show the same map rendering on the RTX 5090 | `wx4/`, `wx5/`, `val5/` |
| 373 | `vulkan-renderer-rain-realism` | Implemented: physical drops (1-3 mm, Gunn-Kinzer speeds, 1/30 s streaks, pixel-wide with coverage alpha), per-drop lighting with back-lit glints, distant rain as froxel fog under open sky, crown splashes, puddle-only ripples, porosity darkening, TAA motion mark. Also: crashes now write `crashlog.txt` with a backtrace (`crashtest/`); ion-blaster glow no longer floods the fog (`fire1/`) | `rain1/`, `rain2/` (RTX 5090) |
| 371 | `vulkan-renderer-rain-occlusion` | Implemented from the owner's first in-game screenshots: rain occlusion map (`shadows.rainCamera`, lower half of the shadow atlas) hides drops, flakes and splashes under roofs and lands splashes on the stored surface; only exposed surfaces get wet or snowed on. Also: procedural bump off for model skins and faded under magnification (blocky faces), wider baked-light specular lobe and glossy rather than mirror-like wet walls (white speckles), sky column fogged at the authored `fog_skyend` coverage, liquids translucent from below, and a dangling draw-list slice in `renderView` that the new pass exposed (segfault) | `wx3/` (no validation layer was installed on the dev host at the time, so the `r_vkValidation 1` run there proves nothing) |

Historical open items at the end of that pass included first GPU qualification,
alpha-tested geometry, skinned RT shadows and FSR integration. Later work supersedes
those implementation gaps: scoped GPU measurements are recorded, alpha-tested world
geometry and skinned character shadow rays are implemented, and MIT FSR 3.1 shaders
are bundled (sequence 380). Optional DLSS remains user-supplied. See
[Vulkan and remaster](vulkan-remaster.md). Overall artistic acceptance, complete
hardware coverage and path-tracing brightness tuning remain open.

## Sequences 347–357 — vulkan-renderer — milestone 1 implemented; owner visual acceptance open

`renderer_vulkan.so` (Zig 0.16, `src/renderer_vulkan/`) implements the complete
refexport v13 surface on Vulkan 1.3 and is now the default `cl_renderer`; OpenGL2
loads automatically when the module is missing or refuses the machine. Scope,
design and the later remaster roadmap: [vulkan-remaster.md](vulkan-remaster.md).
The native client again submits worldspawn fog (`client/fog.zig`), which also
restores fog in both OpenGL renderers. `r_mode -2` renders at the native,
high-DPI drawable; fullscreen is borderless desktop size.

| Evidence (`zig-out/reports/vulkan-renderer-357/`) | State | Limits |
| --- | --- | --- |
| `boot1/`, `boot-gl2/` | Passed: lavapipe boot, menu 2D, fonts and lit menu models inspected against OpenGL2 | `dkguard --headless`, 1280x720 |
| `map1/`, `map-opengl1/`, `map-opengl2/` | Passed: e1m1a lightmaps, rain, view weapon, HUD inspected; matches OpenGL1's overbright model | Single view; no RMSE tolerance recorded |
| `fog-vulkan/`, `fog-opengl1/` | Passed: e2m1a authored fog identical in both renderers | — |
| `preview-vulkan/`, `preview-opengl1/` | Passed: resident e1m1b preview from e1m1a, distinct inline handles | `runtime_render_world_probe.py` itself times out on both renderers: its ready-line wait predates region admission |
| `combat-vulkan/`, `combat-opengl1/` | Passed: glove fire view, 400x300 `dk3-save-*` preview, 128x128 levelshot | `video` only runs during demo playback: AVI capture unverified |
| `default-native/`, `fallback/` | Passed: default loads Vulkan with a native drawable; with every Vulkan driver disabled the client logs the refusal and runs OpenGL2 | — |

Open: owner in-game inspection on the RTX 5090; Khronos validation run (layer not
installed on the host); skeletal cinematic characters. `RT_BEAM`/rail/lightning
entities and model shadows are drawn since sequence 370.

## Sequence 342 — cinematic-performance-pivot — diagnostic gate implemented; new performance unverified

The default client now uses original vertex-model presentation for cinematic
source paths even with a skeletal package installed. Explicit native skeletal
previews use `cg_neuralCinematics 1`. Guarded native records with that package
present finish all 11 shots in both modes. Fallback yields 140 original frame
diagnostics and zero skeletal diagnostics. The paired review aligns 140 frames;
the audit compares actual skinned IQM geometry to original source frames and
50/50 linked Hiro frames fail on the rejected sequence-341 body. This is a
rejection gate, not a replacement performance.
[Data flow, commands and evidence](cinematic-performance-pivot.md).
`blender-shot-008-lit/` is a headless, hash-pinned 3D authoring stage at the
failed 51-second pose; it shows the original and actual skinned IQM meshes.
The integrated build and `test-runtime` pass; consolidated `zig build test
-Dpython=/usr/bin/python3` passes 318 Python and 453 Zig tests. A stale co-op
test fixture was fixed after the first broad run.

## Sequence 341 — cinematic-model-identity — failed visual candidate

The generated white-gi Hiro remains **Failed** after the owner inspected the
native opening scene. The approved facial mesh and texture were restored and
verified by hash, and all eleven preview shots ran, but head placement, raised
shoulders, arms and overall acting still look wrong. Passing clip validators
and package checks do not establish visual acceptance. The sequence-341 archive
is local diagnostic evidence and must not be installed or selected by default.

The next candidate uses the recorded original performance as a visual
reference, a newly calibrated character rig and authored skeletal acting.
Shot timing and choreography may change; dialogue and required story events
remain. See [cinematic model preservation](cinematic-model-preservation.md).

## Sequence 340 — generic-navigation — implemented; partially verified

Navigation now follows the world as it stands and routes state intent
([navigation](navigation.md#generic-navigation-sequence-340-generic-navigation),
[co-op bot](coop-bot.md)). Evidence is local under
`zig-out/reports/runtime-zig-340/`; the regenerated navigation package (all maps,
the bundled BSPC of this sequence) is `dk3-navigation-340.pk3` there and is not
installed into the preserved game.

| Scenario | State | Evidence and limits |
|---|---|---|
| Every supplied map loads in the native runtime | Passed | `coverage/navcov-final/`: 84/84 maps report (73 before). Fixed: satyr side-change poses optional (the supplied model has none), a map naming scripts without an action program loads (e1m7b), an empty authored `spawnflags` reads as 0 (e4m2a). |
| Navigation coverage, all maps | Passed (measured) | Same 73 maps as the original navigation: uncovered floors 26,378 → 3,550, unrouted 74,127 → 62,773. e4m4c, e1m2b (a flooded room), e1dm2 and e4m6b still route fewer floors than before. |
| Gates, planner, lifts, intent objectives | Implemented | Live gates (doors, walls, hazards, sliding floors, breakables; lifts excluded), planner with nested controls, train lift links both ways, lift boarding/operation from the shared `liftStep`, firing positions, touch points, use doors, crouch-only areas. |
| New Game → intro → e1m1a → e1m1b → e1m1c → e1m2a → e1m2b → e1m3a → e1m3b, continuous (Ronin, candidate navigation) | Passed | `coop/final7-newgame/`: no deaths, 1,719 s of game time to e1m3b (171 s wall); e1m3a played by its objective route. |
| e1m1a → … → e1m3b, continuous, same build | Passed | `coop/final7-chain/`: no deaths, 1,117 s of game time to e1m3b. Earlier builds in this sequence failed on the way (RUN log); each failure was fixed and the pair rerun. |
| Episode 1 on the installed (original) navigation | Not claimed | The objective e1m3a route needs this sequence's navigation (the crawlway into the pit, train lift links); with the installed package it stops in its first stage. The candidate package must be installed with the next asset build. |
| Deathtag e1dt1 with gates | Regression fixed; captures open | `match/mp-long-new/` (bots idle up to 110 s at gated lift doors) → `match/mp-final2/` on the final module: travel 593k vs the original build's 590k, longest stand 18.5 s, one objective carrier (two in `match/mp-final/`, three in the original). No run, the original build included, captures in 600 s. |
| Game crashes found by the bot | Fixed | A drained health station hit by a bolt (`MissingComponent`, `coop/crash2/` trace, `coop/crash4/` after); a hurt arrival no longer replaces a healthy death checkpoint (death loops at 2 and 10 health). |
| Build checks | Passed | `zig build test-runtime` (a leftover test print made the step fail although all 225 tests passed) and `zig build test -Dpython=/usr/bin/python3` (293 Python tests; four test modules imported a sibling by bare name). The shell's default `python3` here is an unrelated 3.12 environment without Pillow. |
| e1m3b onward by the bot | Unverified | e1m3b's planner now has a real goal (touchable exit, touch point), but the map needs route work (big door, laser dam, Superfly). |

## Sequence 339 — cinematic-body — visual acceptance failed

The owner rejected the delivered native result: swollen shoulders, broken neck,
smeared cloth and lapels, and poor hand geometry. The candidate is **Failed**;
the numerical and playback receipts below do not qualify its appearance. The
raw generated model retained better cloth and proportions than the delivered
repair. Sequence 341 investigates that loss before another cinematic build.

The original-body subdivision was rejected. A new white-gi body and 4096×4096
atlas are generated and rigged onto the captured cinematic bind. No original
body triangles or UVs enter it. The independent detailed head is retained with
an explicit collar cut, and original props/performance remain. See
[reproduction](generated-dojo-model.md) and the
[native review](../zig-out/reports/cinematic-body-339/cinematic-review.html).

| Scenario | State | Evidence and limits |
|---|---|---|
| New cosmetic master and frozen clip build | Passed | `package-proof.json`; 148,974 vertices, 108,341 triangles, 44 joints; 23 clips pass. New geometry/materials are admitted explicitly; subsequent clips freeze bind, geometry, weights, normals and UVs. Original body triangles: zero. |
| Mapping, timing, fallback and variants | Passed within fixture | Source-model mapping, compact clip table and authored scene bytes exact with 338; all entries retained, 931/940 original entries exact; alpha/fullbright variants retained. Actual original-only run excludes the optional archive. |
| Native GL2/GL1, restore and video | Passed | `owner-native/`, `owner-native-gl1/`, `owner-native-video/`, `native-legacy/`, `native-legacy-video/`; all eleven shots and release, both presentations restore active cinematics; exact recorded runtime/overlay identity replay. GL2 log admits 4096×4096 body/head textures with picmip 0. |
| Fresh-process reproduction and compilation | Passed | `reproduction-proof.json`: master, receipt and all 28 animation outputs exact. `idempotence-proof.json`: check-only passes; unchanged output retains inode/mtime. |
| Tooling and current runtime tests | Passed within recorded scope | `python-owner-candidate.log`: 293 tests. `zig-tests.log`: build exit 0, native C contracts and ragdoll debug-stderr warning; direct execution resolves it with 225/225 domain tests in `zig-domain-detail.log`. No runtime edits in this change. |
| Delivered visual quality | Failed | Owner screenshot retained in `visual-rejection/owner.png`; broken neck, inflated shoulders and smeared cloth were visible in the earlier captures and should have prevented delivery. |
| Remaining cinematics | Unrun | Facial acting, walking contacts, full opening/campaign reconstruction and campaign handoff remain unqualified. |

Evidence is under `zig-out/reports/cinematic-body-339/`; final local products are
under `zig-out/cinematic-body-339/reviewed-generated/`. Optional archive SHA-256:
`8f2abb082266c0af96f2d30ffc0cc5f1190eacee41e6dcef4627189ae87a73d2`.
Runs use an isolated dereferenced native installation; ordinary selectors,
retail assets and owner saves remain untouched. Generated binaries remain local.

## Sequence 338 — cinematic-fidelity — original-body candidate rejected; superseded by 339 candidate

The owner’s three review frames expose mismatched arm gestures, sideways sword,
neck/armor separation and the dojo costume mismatch. Sequence 337's mechanical
passes are retained; visual performance/model acceptance is **Failed**. Repair
uses actual source motion and a source-specific dojo replacement rather than
propagating that candidate into more scenes. Owner frames are retained under
`zig-out/reports/cinematic-fidelity-338/owner-{1,2,3}.png`.

## Sequence 337 — cinematic-performance — complete dojo block verified; full recreation and artistic acceptance pending

Original opening shots 15–25 are recorded with original models. A separate
64.8-second, eleven-shot scene preserves the two actors' original queues,
transforms, dialogue, door use and timing while replacing the camera curves.
Twelve Hiro and eleven Ebihara clips are reconstructed onto their frozen IQM rigs.
Measured head axes, hand/finger inheritance, loop-aware elbow poles, grouped prop
grips, staff orientation/floor contact and skinned boot sole placement are baked
offline. See [reproduction and limits](cinematic-reconstruction.md) and the
[interactive review](../zig-out/reports/cinematic-performance-337/cinematic-review.html).

| Scenario | State | Evidence and limits |
|---|---|---|
| Original reference and new scene with original models, GL2 | Passed | `original-recording/`, `original-video/`, `final-legacy/`, `final-legacy-video/`; eleven shots, release and active save/load; optional IQM archive actually absent. |
| Final deterministic IQMs, GL2/GL1 and replay | Passed | `deterministic-skeletal/`, `deterministic-skeletal-gl1/`, `deterministic-skeletal-video/`; eleven shots and camera release, GL2 active save/load; nineteen observed source ranges select declared targets at authoritative-duration-following rate 0. Four other aliases are offline-only. |
| Original actor/audio/use/timing contract | Passed | `performance-contract-final.json`; consumed fields equal; new camera curves excluded. Original empty negative-time animation is ignored as the runtime does; timed empty requests remain barriers. |
| Serialized motion and preservation | Passed | `deterministic-package-proof.json`; 23 clips pass unchanged limits; max sole height error 0.32942 (<0.5), grip 0.000801 (<0.02), staff floor 0.000817 (<0.1); 936/940 entries exact, two cinematic IQMs/table/provenance change; geometry, binds, weights, UVs, normals and textures exact. |
| Fresh-process determinism and unchanged output | Passed | `deterministic-reproduction-proof.json`: all 27 payloads plus receipt byte exact; generated channels canonicalized at twelve decimals to remove 1e-15 residual ranges. `deterministic-scene-proof.json`, `manifest-idempotence-proof.json`: scene program bytes exact; manifest output inode/mtime retained. |
| Headless inspection and review controls | Passed | `hiro-deterministic-blender/`, `ebihara-deterministic-blender/`: twelve CPU Blender 5.1.2 views; `browser-review.json`: three videos decode, paired seek/play/half speed and all eleven selectors exercised. Every native shot and exact full-body samples technically inspected; human artistic approval pending. |
| Tooling aggregate / retained runtime contracts | Passed within recorded scope | `python-aggregate-deterministic.log`: 256 tests, including 17 continuation regressions. Sequence 336 `zig-runtime-final.log`: retained 312/312 tests and C contracts; no Zig/runtime changes here, no duplicate broad suite or claim for other concurrent edits. |
| Rest of opening, other scenes and original campaign handoff | Unrun | Separate scene namespace; no campaign replacement, installation activation or original/save overwrite. Fixture keeps original geometry/control entities and exact rebuilt navigation; it does not prove the campaign's original entry/exit. |
| Facial/eye, expressive fingers, cloth/deformation, moving contacts | Unverified | Fixed rigs and materials retained. Walking plants are undeclared and unqualified; numerical success does not establish artistic quality. |

Evidence is under `zig-out/reports/cinematic-performance-337/`; final IQM build
and closed package are under `zig-out/cinematic-performance-337/deterministic/`.
The separately authored scene package remains `final/dk3-dojo-dialogue.pk3`.
Optional package SHA-256:
`907c6f6fcd9bb8e71a65c32577a0f1db4237ee33ec22e1cadef107a6d10622c8`.
Guarded software runs use immutable generation `0b3f6bbb…`, runtime identity
`87c4af02a78616375e32d0bb3abf1c86eff356e7e3c78d07c0a1cbc72cf0adef`.
Original master/installation inputs are hash-verified. Earlier fit, thumb, pole,
prop/floor/sole and reproduction failures remain retained. No original program,
normal selector, owner save, network or save representation is modified.

## Sequence 336 — cinematic-reconstruction — verified first slice; artistic and campaign acceptance pending

Original opening shots 12–14 are recorded with converted original models. A
hash-pinned surface-marker capture reconstructs three Hiro performances onto
the frozen IQM rig; a new 16-second dojo scene compiles to the existing cinematic
format and is packed separately. Full opening replacement, other actors, facial
acting, neutral-head calibration and hand-to-hilt fit remain open. See
[architecture and reproduction](cinematic-reconstruction.md) and the
[paired interactive review](../zig-out/reports/cinematic-reconstruction-336/cinematic-review.html).

| Scenario | State | Evidence and limits |
|---|---|---|
| Original shot reference, original models, GL2 | Passed | `cinematic-reconstruction-336/original-reference-nav/` and `original-video/`; original cameras/audio/tasks plus checked spawn; all three shots, release and active save/load. |
| New scene with optional models absent, GL2 | Passed | `retake-original/` and `retake-original-video/`; actual optional archive excluded in a disposable base path; all shots, release and active save/load. |
| New scene with reconstructed IQM, GL2 and GL1 | Passed | `retake-skeletal-final/`, `retake-skeletal-video/`, `retake-skeletal-gl1/`; GL2 active save/load; all three mapped ranges observed with source-duration-following rate 0. |
| Capture/serialized motion/package/reproduction | Passed | `package-proof.json`, `reproduction-proof.json`; max marker RMS 0.94482 units, max plant displacement 0.16271; all twelve payloads reproduce; 937/940 package entries exact, only cinematic IQM, clip table and metadata change; geometry/bind/weights/textures exact. |
| Headless Blender and browser inspection | Passed | `blender-job/result.json`, six CPU full-body views; `browser-review.json`, three videos decode, paired controls/half speed and all capture selectors exercised. Numerical/browser checks do not establish artistic approval. |
| Python and Zig contracts | Passed | `aggregate-refreshed.log`: 239 tests; `zig-runtime-final.log`: exit 0, 312/312 tests and C contracts (existing ragdoll debug stderr retained). |
| Full campaign reconstruction and original handoff | Unrun | Fixture substitutes only the BSP entity lump and rebuilds its exact navigation; original 16 geometric lumps stay byte exact. No campaign program, completion target, installation selector or owner save is changed. |

All evidence lives under `zig-out/reports/cinematic-reconstruction-336/`.
Engine jobs use dkguard software rendering and explicit immutable installation
`0b3f6bbb325cc304ec1be2254645af17afc34caf2e3273769a7d7ce80fb24b47`,
runtime identity `87c4af02a78616375e32d0bb3abf1c86eff356e7e3c78d07c0a1cbc72cf0adef`.
The latest source tests are separate from that installed runtime. Earlier failed
navigation, contact fitting and SIGTERM capture reports are retained. Local-only
scene and skeletal products are not activated in the ordinary installation.

## Sequence 335 — coop-bot — implemented; New Game through e1m2b passed headless (Ronin)

A scripted player bot plays the single-player campaign on a dedicated server at
13–22× real time with exact 50 ms frames (`fixedtime 50`, `timedemo 1`). It is the
ordinary slot-0 client: user commands, `use`/`save`/`load`/`attribute` client
commands, and the client's world-publication acknowledgements with digest and
runtime-identity validation. A sandboxed bundled Lua 5.4.7 route
(`dkq3/coop/`) chooses actions; staged level bodies resume after death
checkpoints. See [coop-bot](coop-bot.md). The campaign verification runs at
Ronin (`--skill 1`): Samurai's extra sludgeminions in e1m2b (authentic 275 hp,
10–30 per glob at 900 u/s) outlast the bot's ammunition; Samurai still passes
the opening and e1m2a. e1m3a is partly routed; later maps and episodes 2–4 have
no authored route yet.

| Scenario | State | Evidence and limits |
|---|---|---|
| New Game → full intro → e1m1a → e1m1b → e1m1c → e1m2a → e1m2b arrival, continuous, Samurai | Passed | `zig-out/reports/runtime-zig-335/newgame-e1m2b/` (final code and routes: 0 deaths through the whole of e1m2a, 1208 s game / 100.1 s wall, 12.1×; its saves include the `coop-e1m2b` arrival for route work), earlier `newgame-final/` and `newgame-opening-6/` (963 s game time in 71.3 s wall, 0 deaths, 201 completed actions); all 115 intro shots and every arrival scene played; both e1m1b turret controls destroyed, ford Crox, health trees, Thunderskeet boss killed with Ion fire, plateau drop and river swim; e1m1c pipe climb with running jump, gate, yard, switch and monitor, raised platform, liftmaster descent, authored cut. Module/server/route SHA-256 in `inputs.json`. Ends at e1m2b by design (no route). |
| Death checkpoint restoration mid-level | Passed | Bridge-stage deaths (e.g. `runs` of e1m1b with 1–4 restorations): the game reloads its checkpoint (full map load), the bot is re-admitted and resumes at the saved stage, skipping actions already reflected in the save. |
| Region admission and travel by the bot client | Passed | Identity seams, landings and the e1m1c→e1m2a cut all depart and admit with the bot answering `dk3_world_begin/data/patch` (digest-validated) through `BOTLIB_EA_COMMAND`. |
| Lua sandbox and budgets | Passed (unit) | `engine/lua.zig` tests: io/os/package/debug/load/dofile absent, `string.dump` rejected, instruction budget stops runaway loops, memory cap fails the script. 223/223 runtime tests pass when run directly; the `test-runtime` build step is reported failed by a concurrent work-in-progress `domain/ragdoll.zig` test that prints to stderr. |
| Runner evidence parsing | Passed (unit) | `dkq3/tools/tests/test_coop_bot.py` 4/4; architecture checks pass. |
| e1m2a (Sewer System), from its arrival save to the e1m2b exit, Samurai | Passed with restorations | `zig-out/reports/runtime-zig-335/e1m2a-sewers/`: lift, hatch event, flooded drum crossed round its stationary paddles, tube, cart ride to the pump rooms and back (train 123, buttons 125/385), C4 room button 159 opening the drum room's east grate, upper sewer, both leaves of use-door 267/268, pod room button 48 and the ten-second dash over the waterfall walkway through doors 250/251, rockfall slab and the deep canal passage, ladder rungs (button 160) climbed, travel to e1m2b; 6 deaths (upper sewer sludgeminions), each restored from the stage-9 checkpoint; 244 s game / 97 s wall. Runs are stochastic: other replays failed at the same fights before the per-map allowance (`map_deaths`) and the health-gated checkpoints. Continuous New Game through e1m2a: see the next row. |
| New Game → intro → e1m1a → e1m1b → e1m1c → e1m2a → e1m2b → e1m3a arrival, continuous, Ronin | Passed | `zig-out/reports/runtime-zig-335/ronin-newgame-e1m3a/`: 0 deaths, 1600 s game / 148 s wall (10.8×). e1m2b in full: off the gratings into the water chute (its trigger raises the sluice), over the falls into the flooded tank, under water through the submerged lower level to the control room (window broken with the glove, health packs, drain button), back over the spinning drum fan before the water falls, through the sunken hugedoor and the passage into the pit, up to the valve walkway (worker cleared from the wheel, wheel confirmed open), back over the beams to the timed west doors, the wading channels' sludgeminions fought from chosen spots, the hall, the lift, and the end room's single-player end button with its closing scene. The run then stops in e1m3a, whose old generic body cannot route the prison. |
| e1m3a (Solitary), from its arrival save | Implemented, unverified | Guard post button (cell block doors), back through the plate-operated hydraulic door, panel shot from the pit beneath it (crouching back out through its crawlway), cell block and stairs to platdoor (button either side), the big platform to the shaft top. Beyond the shaft top the area graph has no route to the e1m3b exit; not yet routed. |
| e1m3b onward | Unrun | Placeholder `progress` bodies only. |

Runs are not bit-identical: resident-world preparation is paced by the wall clock,
so encounter timing varies; the opening passed repeatedly only after the motor
gained the recorded skills (fire discipline, ammunition reserve, threat-forecast
dodging, ledge/liquid/hazard guards, waypoint commitment, stall hops). Rendering,
audio and prediction are not exercised by this headless verification.

## Sequence 334 — animation-authoring — verified toolchain and isolated clips; visual acceptance partial

The authoring pass adds strict YAML clip and cinematic sources, a typed
headless Blender adapter, BVH/FBX motion interchange, directional retargeting to
the admitted IQM bind rigs, contact cleanup, loop/joint/attachment validators,
cosmetic packaging and generated native preview maps with demo-to-video capture.
The source recipes preserve authoritative animation ranges/rates and compile to
the current `neural-animations.cfg` and `dk3_cinematic 1` formats. Masked runtime
layers, facial channels and a new deformation rig remain separate migrations.

The [tool guide](animation-authoring.md) documents commands, formats, source
licenses and limits. Local evidence is under `zig-out/reports/animation-authoring-334/`;
`animation-review.html` includes the full native video, all GL2 captures, corrected
body/head material previews, recipes and unresolved source findings.

| Scenario | State | Evidence and limits |
|---|---|---|
| Licensed sources and motion interchange | Passed within selected-data scope | Pinned CMU 07_01 walk and 09_01 run plus full conversion notice. BVH imports retain actual 317/149-frame action ranges; FBX round-trip retains 317 walk frames, maximum 0.084 source-unit/0.648° error. FreeMoCap footage returns 403; CMU AVI reference downloads fail TLS chain verification and remain unadmitted. |
| Rig retarget, prop policy and serialized validators | Passed for three aliases | `qualified-build/build.json`: 63 neutral, 32 walk and 22 run frames at 30 Hz on the frozen 33-joint rig. Contact cleanup reduces final walk displacement 2.0204 → 0.4853 units, below 0.5; all declared contact, anatomy, fixed-length, loop and attachment checks pass. Hidden prop channels prevent a floating sword. Neutral remains procedural. |
| Source-performance audit | Failed for 12 original clips; retained | `source-anatomy-audit.json`: 12 of 42 original Hiro clips exceed the anatomical joint-step limit. Prop rotations are excluded from that body limit. No blanket repair/acceptance of original performances follows from the three new aliases. |
| Native compiled three-shot studio | Passed within isolated scope | `native-final/` and `native-final-gl1/`: exact final bundle on software GL2/GL1; all shots, measured-speed walk/run arrivals, camera ownership and normal release. `native-final-clip-proof.json` observes actual 30 Hz target ranges; GL2 active save/load resumes and completes. |
| Engine video and review | Passed | `video-final/`: receipt-matched native demo → AVI → 960×540 30 Hz H.264; `browser-review.json` checks decoded video, all shot/pose selectors and half-speed playback. Ten final Blender samples use separate head/body atlases; earlier single-atlas reviews were defective and remain retained. |
| Package/input preservation | Passed with measured frame re-encoding | `package-proof.json`: 940 entries, 937 payload hashes exact; one IQM and clip table change, provenance refreshed. Geometry/UVs/normals/weights/triangles/binds/parents/atlases exact. Original 955 frames re-quantize by ≤0.00097 rigid-joint units/0.00278°, scale exact. Original master inputs and installed source PK3 remain exact. |
| Aggregate and installation isolation | Passed within tooling scope | `aggregate-final.log`: 218 tests including 25 authoring regressions. `final-policy-proof.json` confirms the latest root/FPS handling reproduces every native-qualified payload byte. `qualification.json`: sequence-333 immutable selectors/launcher exact; all saves/runs in disposable profiles through dkguard. No runtime changes, duplicate native suite, installation activation or campaign acceptance. |

The separate candidate is `zig-out/animation-authoring/dk3-neural-qualified.pk3`,
SHA-256 `5bb319d0b57183aea2690b3b49b62b39c1af91a1a50ecba13ba9dd07fd216162`.
The reviewed normal generation remains `6ac17090…`. Early import dependencies,
padded holds, floating props, material assignment, missing studio navigation/trigger,
headless-X collision and fixture syntax failures retain their original reports;
affected runs and the invalid aggregate are refreshed after repairs.

The native task called `head` rotates the whole performer. The compiler correctly
emits absolute angles, smooth look curves and native yaw-rate compensation; no
independent head/eye layer is claimed. Open: original source failures, full story
and campaign visual playback, contact/acting quality beyond selected clips,
hardware rendering, masked layers, facial channels, new rigs and footage reconstruction.

## Sequence 333 — human-arms-locomotion — verified motion repairs; visual acceptance partial

The reported opening gate walk is reproduced in fresh authored shot 26. Hiro's
left wrist now follows the forearm instead of flipping upward; the elbow stays
beside the body. Cinematic fitting derives connected arm rotation from the solved
chain, constrains elbow planes, and bounds wrist bend separately from forearm
roll. Generated human palms follow the forearms while held weapons retain their
established axes. Gameplay retains full per-grip arm motion. Running has bent
elbows, opposed arm swing and a flight phase; player publication distinguishes
walk/run using character-relative horizontal speed. Cinematic movement selects a
run sequence when running is queued, retaining explicit authored animations and
fallback for classes without that sequence. Mishima and Usagi use their actual
rendered model's playback ranges. Five human NPCs receive refreshed idle/locomotion
on their admitted bind rigs; original authority intervals and events remain.

Evidence is local under `zig-out/reports/runtime-zig-333/`. The
`human-motion-review.html` page includes the owner's screenshot, the matching
rear gate capture, all five walk/run recordings, held weapons and paired model
contact sheets. The complete 102-model cinematic review inspects 206 paired
samples; five NPCs add 15. This is sampled deformation review, not full visual
acceptance of every clip or story scene.

| Scenario | State | Evidence and limits |
|---|---|---|
| Full opening and arrival | Passed within authored playback scope | `opening-gl2/result.json`: all 115 intro shots, seven e1m1a arrival shots, completed save/load and normal control on the final runtime. Ordinary dkguard software GL2. |
| Reported gate walk | Passed within sampled visual scope | `gate-walk-native/`: fresh opening, actual authored walking cameras; shot 26 at 8,000 ms matches the owner's rear view and shows the repaired wrist/elbow. `gate-replay-native/` and `gate-pan-native/` separately inspect restored gate dialogue and a complete camera pan. |
| Five multiplayer walk/run appearances | Passed within LAN scope | `network-run/` and `network-walk-fixed/`: Hiro, Mikiko, Superfly, Mishima and Usagi rendered remotely over UDP. Twenty samples each per mode; 24-frame walk and 15-frame run cycles at 30 Hz. Ordinary movement, fire, death/respawn, reconnect and restart checks also pass. Public-room acceptance is outside these runs. |
| Held sword/rifle/pistol | Passed within controlled grip scope | `held-weapons/`: real two-client remote ready and attack captures for Daikatana, Ion rifle and Glock. |
| Companion and five human NPCs | Passed within diagnostic scope | `companion-motion/` exercises live Superfly movement/save/load. `npc-native/` and `npc-dry-native/` exercise class-owned grounded fixtures and save/load for Cryotech, Mishima Guard, Fatworker, Skinnyworker and Surgeon; native loop mappings play at 30 Hz. Continuous campaign chase/navigation and every attack remain unqualified. |
| Asset preservation | Passed | `package-proof.json`: all 132 serialized IQMs compared; 115 motion outputs change, 17 remain exact. Vertex arrays, UVs, normals, weights, triangles, bind joints and parents stay exact for all 132. All textures, skins and model/physics mappings remain exact; all 15 character master inputs stay exact. |
| Aggregate checks | Passed | `aggregate-final.log`: 54/54 steps, 446/446 Zig tests, 193 Python tests and engine C contracts, including 21 anatomical/prop rig checks. |
| Reviewed installation | Passed | `install-final.json`: exact tested immutable generation active in native-dev and neural-monsters-dev, all 25 manifest files per prefix verified, 106 latest owner-state hashes exact, loose JapanDM preserved, launcher/main/online/previous generations exact. |

The installed development generation is
`6ac170908fc2ddd0a3b0536218b6349eb5e524857b49f8fc7a119cf9595c2825`;
the tested runtime identity is
`a9d6bbbc5a28a620d0e0bec883be5fbcaf955040513e1ba10c1b0fbd2893c5d0`.
The classic ZIP32 episode archive is 2,196,041,740 bytes, SHA-256
`59854041cfb853cc787a079efe593a13c0b87be33fdc3863dd66142604b3f564`.
Both development selectors use that exact tested generation; previous generations
and current owner state are preserved. An independently running launcher changed
the native selector and 14 save files during this pass; `concurrent-launcher.json`
records that change and the refreshed preservation baseline. Its dropped loose
JapanDM archive is restored in the installed native generation. Both canonical
install builds pass 43/43 steps, but picked up concurrent unrelated native/Lua
source edits and produced generation `8d61f363…`. `reviewed-activation.json`
records the locked atomic selection of the already staged, exact tested `6ac17090…`
generation. Concurrent source/build products and that unqualified generation stay
preserved. This sequence's aggregate/runtime evidence belongs to the tested
generation and does not qualify those unrelated later edits.

Earlier failed walk-driver filtering and the unavailable Python interpreter's
Pillow import remain recorded; the corrected walk probe and explicit system
Python aggregate pass. A rejected 34-unit run stride exceeded Superfly's existing
hip bound; the admitted 32-unit stride retains the flight phase and passes the
rig checks. No duplicate broad suite follows the valid final aggregate.

Open: Charon task/camera timing; cloth and extreme rolled/death pose fidelity;
Osaka/Casseti/Mikiko visual repair; full visual playback of every story scene,
hardware rendering and connected campaign completion. No facial morphs are added.

## Sequence 332 — cinematic-motion-publication — verified playback repairs installed; visual acceptance partial

The opening's reliable-command failures came from primary-world configstrings
bypassing the bounded regional publication stream. Primary updates now use that
stream too; repeated lightstyles coalesce and the four-command acknowledgement
window remains enforced. The engine retains the actual world registry for
gamestate/reconnection without also broadcasting ordinary `cs` commands.
Snapshots defer entities whose model or sound definition is still being published.
The separate transport flag preserves publisher visibility and collision links.
The actual server registry/broadcast C contract and native publication contracts
cover these boundaries. A fresh Superfly map exposed the missing primary snapshot
barrier; its original `InvalidSoundPath` failure is retained.

Two cinematic fits change. Ninja scale uses reviewed standing frame 143 rather
than a crouched reference. SHA-pinned anatomical source vertices keep torso
rotation from following the wrist during running/jumping. The female guard's
36 original short-blade triangles are recovered from the connected body and
attached as two independent weapons. Six ninja and four female-guard paired
frames were visually inspected against the original and exact serialized IQMs.
The final package contains those exact candidates; all 130 other IQMs, all master
geometry/atlases, both prisoners and model/physics mappings remain exact.
The 100 unchanged cinematic models retain sequence 330's sampled inspection.
Original frame/clip order and the approved artwork remain the input contract.

Cinematic performers now publish floor contact and ride moving brushes, including
borrowed actors. Pushing uses the cinematic rider's configured collision mask
instead of adding player-only clip geometry. A retained Charon trace records 511
blocked pushes before that correction; the final boat proceeds beyond the former
stall. Event-generator `cinetrigger`/`target` metadata no longer gets parsed as a
numeric timer; real custom delay fields remain strictly validated.

| Scenario | State | Evidence and limits |
|---|---|---|
| Complete opening and destination arrival | Passed within authored playback scope | `opening-final-runtime-gl2/`: final runtime, all 115 opening shots, actual handoff to e1m1a, all seven destination arrival shots, completed save/load and normal control. Ordinary guarded software GL2, without GDB. `opening-resource-barrier-gl2/` retains the earlier successful publication candidate replay. |
| Opening ninja performance | Passed within sampled visual scope | `opening-ninja-motion-gl2/`: eight in-shot captures spanning shots 95–100; paired review covers frames 12/46/85/143/150/162. Upright running torso/standing size repaired; cloth and legs still approximate the original. |
| Superfly full authored scene | Passed within diagnostic scope | `superfly-final-runtime-gl2/`: fresh map, diagnostic activation of the actual authored trigger, all 13 shots, cleanup and completed save/load. `superfly-resource-barrier-gl2/shots-contact.jpg` inspected. Copied historical active-save completion is separately retained; continuous rescue/current owner save acceptance is not claimed. |
| Copied historical active Superfly save | Passed within restoration scope | `superfly-historical-final-runtime-gl2/`: final runtime restores cursor 1, completes all remaining shots 1–12 and restores the completed scene with control released. Copied source save hash unchanged; no owner-state writes. |
| Charon arrival admission and boat motion | Passed within diagnostic scope | `charon-mask-final-gl2/`, `charon-all-shots-final-gl2/`: all 17 shots, completed save/load; recorded actor positions travel beyond the previous blocked push. Resident admission succeeds after event metadata repair. |
| Charon visual performance | Failed; further work required | All-shot native captures show the boat/actors in several views, but many cameras miss them and Hiro's queued movement trails the authored framing. Successful scene completion does not establish visual acceptance. |
| Episode-four boat arrival | Passed within diagnostic scope | `femaleguard-boat-final-gl2/`: all 19 shots, completed save/load; ten captures inspected, boat riders and arrival actors visible. This scene does not visibly exercise the repaired female guard's blades. |
| Female guard blade fit | Passed within serialized sample scope | Four paired frames 0/70/96/182 show both original short blades with independent hand attachment. Native blade scene remains unqualified. |
| GL1 opening regression | Passed within partial diagnostic scope | `opening-final-runtime-gl1/`: ordinary guarded software GL1 passes shots 10–18 beyond the prior overflow point. Complete GL1 playback remains unqualified. |
| Aggregate checks | Passed | `aggregate-resource-barrier-final.log`: 54/54 steps, 445/445 Zig tests, 190 Python tests and C contracts. Supersedes the aggregate before the primary snapshot barrier. |
| Authorized development installation | Passed within installation scope | `cinematic-user-install.json`: both development prefixes select the qualified generation; 25 manifest files verified per prefix, 106 owner-state hashes exact, launcher/main/online selectors and previous generation preserved. Native development's loose japanDM package survives activation. Both installs pass 43/43 steps. |

Episode package: 2,195,922,456 bytes, classic ZIP32, SHA-256
`e58108e57ef159b85003d8ab5c426b037f82e7a1dc5b9971a52d5c0769db52d6`.
Only two IQMs, four female-guard skins and the receipt change relative to 330.
Runtime/engine modules and compatibility records also change in the installation;
this is not an archive-only update. Installed generation:
`b895461e6ab7c59844540bac9d0b76c0adbca1a63b6cc9de86d98f8cac20ba6f`.

Evidence remains under `zig-out/reports/runtime-zig-331/`; sequence 331 in the
journal belongs to the concurrent japanDM task. See `cinematic-native-review.html`
for paired poses and actual native captures. Osaka/Casseti/Mikiko visual repair,
rolled/death poses, cloth, facial morphs, full visual playback of every story scene,
hardware rendering and connected campaign completion remain open. Engine runs
use dkguard `--headless` without `--gpu`. No Git operations.

## Sequence 330 — neural-visible-quality — reviewed replacements installed; cinematic acceptance partial

This is the historical checkpoint. Sequence 332 above supersedes its native
opening/Superfly playback failures and the two admitted ninja/female-guard fit
defects. Its other visual and campaign limits remain open unless qualified above.

The owner rejected the torn Toshiro forehead/neck, other facial artifacts and
cartoonish anatomy. Six dedicated reconstructions now replace Toshiro, Hiro,
Superfly, Usagi, Garroth and Charon heads with realistic proportions. Accepted
master concepts remain the style target. Closed geometry, local jaw/neck repairs
and anatomical head weights replace the failed portrait-fitting approach.
Five fixed mesh-conditioned camera guides paint separate 4096-pixel head atlases;
full combined-model depth limits projection visibility. Usagi's garment interior
uses a bounded two-sided collar painting exception. Body conversions remain
frozen parents, and the original joint/bind/frame channels stay exact.

Hiro's head is now 1.15 times the preceding replacement size. Eight actual albedo
and lit views and six serialized gameplay poses were inspected before admission;
the installed opening close-ups also show the larger head. Accepted body concepts
remain unchanged. Current front/quarter/both-side views and animated join reviews
identify each candidate by SHA-256. Admission copies those exact renders into the
gallery. All 37 masters and 11,458 frames pass the current structural/skinning
audit. The final aggregate passes 52/52 steps, 442/442 Zig tests, 173 Python tests
and C contracts in `aggregate-final-zip32.log`.
Duplicate gameplay pose blocks now share exact storage, keeping the high-detail
Superfly IQM within the engine's 16 MiB bound. Every named movement and attack
pose of the five gameplay masters remains bit-identical after serialization.

The cinematic fitter now keeps semantic head/torso/leg surfaces through source
deduplication, calibrates limbs from source anatomical landmarks and preserves
original prop rotations. Head orientation no longer follows an arm gesture.
Connected fixed-length IK constrains knees and ankles. Quantized hidden weapon
pieces and rigid long staffs are recovered; Toshiro's staff uses the standing
reference grip rather than a fallen wrist near the shaft end. Upright first poses
remain upright even when most source frames are recumbent. Source-pinned landmarks
restore Hiro's kneeling ending, and Charon's weapon is extracted from its connected
original hand mesh. Original clip/frame ordering and named hardpoints remain intact.

All 102 cinematic variants were rebuilt with matching skins. The paired review
viewer exports the original vertex animation and exact serialized replacement,
with every frame and clip available at a shared camera scale. Numeric joint-step
triage covers 55,604 frames and 2,081 clips, excluding clip boundaries. All 13
contact sheets were visually inspected: 300 samples cover every model's initial,
movement and flagged poses. This establishes sampled inspection of every model;
it does not establish full visual playback of every clip or native scene timing.

| Scenario | State | Evidence and limits |
|---|---|---|
| Six actual serialized face materials and motion | Passed within scope | `head-admissions.json`, per-actor `visual-review.json`, four albedo/four lit views and actual animated master renders. No facial morphs. |
| Current original image resolution | Passed | Head and body both upload at 4096 pixels. Fine faces previously occupied a small part of the whole-body atlas. Separate head atlases increase facial coverage. |
| Larger Hiro head | Passed within scope | `hiro-owner-size-admission.json`, `hiro-owner-size-eight-views.jpg`, `hiro-owner-size-gameplay-poses.jpg`; installed GL2 shot 14/15 close-ups inspected. |
| Toshiro/Hiro installed opening faces | Passed within sampled diagnostic scope | `installed-opening-heads-zip32-ack-debug/`: exact installed package, guarded software GL2 under GDB, shots 10–18 and animated samples. Hiro face/gesture and Toshiro shot-18 face inspected; both head images upload at 4096. This debugger replay does not qualify ordinary complete playback. Older direct previews remain identified separately. |
| All cinematic model sample inspection | Passed within scope | `all-cinematic-final-inspection.json`, `all-cinematic-sampled-review/`, `cinematic-pose-review.json`, `final-cinematic-candidate-proof.json`. All 102 models inspected in 300 paired samples; 2,081 clips receive numeric triage. |
| Usagi/Garroth authored scene samples | Passed within scope | `usagi-nomipmaps-paced-gl2/` confirms the affected Usagi face-filtering repair. `garroth-final-guarded-gl2/` shows authored scene samples from the earlier builder; final staff poses are reviewed in serialized samples. Complete native performances remain unqualified. |
| Superfly native movement, shadow and save | Passed within scope | `superfly-final-native-gl2/` direct isolated probe. Guarded copied active encounter captures show actual head motion, but the scene completion later exits on signal 4; completion is failed. |
| Charon native story presentation | Unverified | Diagnostic single-map scenes load the model/material but inspected authored cameras do not visibly show Charon. Serialized animated master review passes; actor binding/presentation does not. Resident-region admission also fails in the normal e2m2a scene. |
| Native filtering change | Passed within scope | `usagi-nomipmaps-paced-gl2/`: actual affected face/neck comparison inspected. Separate head shaders use `nomipmaps`; final installed Hiro/Toshiro retain sharp face detail. Body materials retain mipmaps. |
| Normal installed opening playback | Failed | `installed-opening-heads-zip32-gl2/` drops after shot 17 with “illegible client message”; `installed-toshiro-zip32-gl1/` drops during early practice with server-command overflow. The latter pending queue is dominated by ordinary `cs 29` lightstyle updates alongside bounded world patches. GDB does not reproduce the drop through shot 18; no playback repair or full-intro acceptance is claimed. |
| Remaining cinematic pose/prop repair | Open | Female guard weapon absent in affected samples; ninja crouched-reference size/airborne poses; rolled/death poses, torso lean, robes and cloth still approximate the original vertex performance. No facial morphs. |
| Remaining whole-gallery visual repair | Open | Osaka beard/hair shards, Casseti stretched beard projection and Mikiko style remain visible in the inspected side renders. They remain rejected, not visually accepted. |
| Final package and authorized installation | Passed within scope | `head-final-package.json`, `zip32-format-repair.json`, `head-user-install.json`; both development prefixes select generation `22352873871ec98a877aa919368ae48b05a45b40a6f609cc5ba7da28f46dc3e5`. Normal launcher remains guarded. Final install passes 43/43 build steps. Owner hardware testing is pending. |

Final episode package: 2,195,897,606 bytes, SHA-256
`cc2637bd3efcb4d3404c64d2312e965665c49e0f5f888407bafbb27906174267`.
It contains 132 IQMs: 110 character variants change and all 22 monster IQMs remain
exact relative to the fresh pre-repair package. Both prisoners, model/physics
mappings, engine, native modules, renderers and base content remain exact.
Only `share/dk3/zz-dk3-neural.pk3` changes in the installation. Previous generations,
package backups, owner state, launcher and preserved main/online selectors are
verified against `head-install.before.json` by `head-user-install.json`.

The first combined package crossed Python's conservative 2 GiB ZIP64 threshold.
The bundled ZIP32 reader misread the extra ZIP64 directory bytes and trapped while
listing shaders; the original failure and GDB trace are retained. The packager now
writes classic unsigned ZIP32 offsets below 4 GiB and rejects ZIP64 before admission.
All 939 reviewed payload hashes remain exact across this format-only repair.
Sparse-archive regression coverage exercises the actual boundary above 2 GiB.

Evidence and retained failures are under `zig-out/reports/runtime-zig-330/`.
New engine runs use dkguard `--headless` without `--gpu`; direct older preview
runs are identified separately. Full 115-shot intro, all story performances,
campaign completion, owner hardware rendering and higher-load software behavior
remain unverified. Both prisoners, previous immutable installations, owner saves
and preserved main/online installations stay protected. No Git operations.

## Sequence 329 — neural-face-quality — structural/scenario checks passed; visual acceptance reopened by 330

The close-up repair pass admits 19 closed-surface masters: the 15 character
identities and Mishima Guard, Fatworker, Skinnyworker and Surgeon. Their rebuilt
meshes and 4096-pixel atlases exactly reproduce the reviewed candidates. All 41
registered front/side views have a positive sampled Jacobian, with a minimum of
0.2377788665 on the 201-square grid. Topology and UV
checks pass; joint names, hierarchy, bind channels and animation channels are
unchanged, with zero measured frame-channel error. Both prisoners retain their
protected inputs and products.

The baker now rejects folded registrations, contributes no backward-facing camera
weight outside the named anterior orbital exception, and limits frontal eye
priority to measured anterior eye regions. Independent side portraits repair
ear/neck albedo. Corrected Tatsuo
glasses, jaw and collar landmarks remove the observed projected stripes. Candidate
and production evidence is under `zig-out/reports/runtime-zig-328/`, including
`texture-candidate-production-proof.json`, `registration-jacobians-final.json`
and `texture-quality-review/closed/`.

Packaging, isolated installation and serialized-pose review are complete. All
37 conversions retain their current products. The shared bounded baker also
refreshes Psyclaw's atlas while preserving its exact IQM and source texels outside
the face mask. Its refreshed eye/pose review and provenance are recorded separately.
The all-frame audit passes 37 masters and 11,458 frames; current render receipts
cover 217 sampled poses and 19 separately lit faces. Ten new independent side
portraits and their exact built-in imagegen prompts are recorded in
`texture-quality-review/closed/continuation-side-artwork.json`.

The isolated installation is
`d0d76e7161d12122ad295efa5948e2f0bfe67456112978e4d6a47fe82337354e`;
combined executable/module/asset identity:
`f159f7bccf495ac482c130e0117001156a9136fdabb14ae29b8fefa64a3c838c`.
Package: `zig-out/neural-monsters/episode1/dk3-neural-episode.pk3`,
1,875,536,283 bytes, SHA-256
`a3cce6c208de4e7977798ba2efd7959076ede55a48eb7990b2ff36466fde3ff1`.
It contains 132 IQMs: 110 character variants and 22 monsters. Compared with
sequence 328, 114 IQMs change and 18 remain byte-identical; the model/physics
mappings and both published prisoners remain exact. Executables, modules,
renderers and base content match the preceding qualified installation. At the
owner's explicit request, both `zig-out/neural-monsters-dev/play/current` and
`zig-out/native-dev/play/current` now select that installation. The normal `dk3`
command launches the native development prefix through its dkguard. The default
local neural-package selector also chooses this package for `zig build play`.
The previous native installation, preserved `zig-out/play/current` and
`zig-out/online/play/current` selectors, and all 120 snapshotted save/settings
files remain exact. Previous package and launcher bytes are retained; installation
proof is `zig-out/reports/runtime-zig-328/texture-user-install.json`. Owner manual
hardware testing is pending. No Git operations.

Evidence: `zig-out/reports/runtime-zig-328/texture-final-evidence.json`,
`texture-native-review.html`, `texture-native-executions.json`,
`texture-package-diff.json`, and per-case commands/inputs/captures/receipts.
All engine runs use dkguard, isolated profiles and `--headless` without `--gpu`.
GL2 qualification uses 960×540 captures with two software workers; GL1 uses
960×540 with eight workers. Controlled setup and ordinary resulting actions
remain recorded separately by the existing probes.

| Scenario | State | Evidence and limits |
|---|---|---|
| All episode-one monsters | Passed | `texture-all-monsters-gl2/`: all 22 skeletal actors render and restore, including the frozen prisoners and updated Psyclaw atlas. Controlled worlds; no full level route. |
| Guard death and default fragments | Passed | `texture-guard-body-gl2/`: ordinary Glock death, articulated contacts, sleep and alive restoration in e1m3b. `texture-guard-gibs-gl2/` verifies the default class gibs. `texture-guard-body-gl1-opening/` qualifies articulated death/restoration in e1m1a on GL1. |
| Five UDP character appearances | Passed | `texture-network-characters-gl2/` and `texture-network-characters-gl1-workers/`: real client/server admission, 15-frame gait at 30 Hz, moving/stationary attacks, complete deaths, respawn, retained bodies, sleep and cleanup for Hiro, Mikiko, Superfly, Mishima and Usagi. |
| Held weapons, carry and companion | Passed | `texture-held-weapons-gl2/`, `texture-carry-gl2/`, `texture-companion-body-gl2/`: sword/rifle/Glock grips and attacks, carried Mikiko performance, companion articulated death and actual alive save restoration. |
| Intro motion and close face views | Passed within scope | `texture-intro-motion-gl2-standard/`: practice motion, early camera angles and Hiro face burst, playback through shot 35 and mid-cinematic save/load. Full 115-shot intro remains unverified. |
| Saved Superfly encounter | Passed | `texture-encounter-gl2/`: ordinary trigger contact, all 13 authored shots, retained torture apparatus, active/completed restoration and player control release. Source autosave is copied and remains unchanged. |
| Aggregate and asset provenance | Passed | One `zig build test` aggregate: 52/52 steps, 442/442 Zig tests, 130 Python tests and C contracts. Exact candidate/production, registration, render receipts, package lineage, conversion retention and prisoner proofs pass. |
| Higher-load software profiles | Failed; unqualified | The 1920×1080 intro capture overflows reliable server commands. Initial GL1 firing/gait windows expire; e1m3b guard replays also overflow commands, and drop cleanup reports `StaleEntity` in the reduced-size attempt. These failed reports remain preserved; opening-map and standard-size passes do not qualify those paths. |

The structural and scenario receipts above remain available. The owner's later
close-up test reopens visual acceptance in sequence 330 above.
Full campaign, every story performance, hardware rendering, higher-load software
behavior and reliable-command drop cleanup remain open. Body collision remains
approximate; runtime materials use base color and have no facial morphs. Concepts
remain 1280 pixels. Earlier pod, Crox, robot and Venomvermin scenario evidence from
sequence 328 retains its exact runtime geometry/materials and engine/module inputs.

## Sequence 328 — neural-characters-episode1 — first integration verified; close-up repairs superseded by 329

The owner reopened visual acceptance after finding eye placement, texture stripes
and ragged surface edges. The package/scenarios below record the completed first
integration, not acceptance of those defects. Further surface and registered
material repairs are completed by sequence 329 above under
`zig-out/reports/runtime-zig-328/texture-quality-review/`; the installed package
remains available as historical evidence.

The local pipeline photographs admitted original models, records reviewed detailed
concepts, runs the pinned TRELLIS.2 deployment on the RTX 5090 and converts the
inferred bodies to textured IQM. Its 37-master roster includes all 22 episode-one
monsters, the five established characters and ten additional story identities.
The prisoners retain their exact protected chained performances. Suitable bipeds
use the shared anatomical character rig and new motion; creature trajectories
retain authored frame/event intervals. Character variant construction preserves
cinematic props, hardpoints, carry performance, moving weapon stances, team skins
and face tint protection. Humanoid and generic creature physics use native Zig.

Completed: 35 new reconstructed masters and two protected prisoners; 132 published
IQM variants (110 character performances/appearances and 22 monsters). The final
structural audit checks 37 masters and 11,458 frames. Asset review records 217
sampled poses, 20 registered face/eye edits and 19 lit face reviews. Local deployment,
capture/concept intake, reconstruction, conversion, review, packaging and replay
instructions are in [the pipeline documentation](neural-monsters.md).

Visual repairs include neutral torso centering, source-faithful guard identity,
standing Toshiro alignment, robot frontal polarity, continuous robe hems and
released hands, rigid pod petals, measured mechanical arms, connected Venomvermin
quadruped motion, UV-seam welding before decimation, bounded face re-registration
and valid serialized lighting normals. The two face shapes that exceeded the seam
registration bounds received fresh registered edits. Normal reconstruction changes
only IQM normal/tangent arrays; binary proofs retain the other geometry/motion bytes.
The bundled engine's cumulative file-read counter now uses unsigned 64-bit
accounting: repeated large-package restoration previously overflowed its signed
32-bit counter and trapped in ReleaseSafe. Game/client/UI behavior remains Zig.

Final isolated installation:
`b39371cb7fb58d6c4a57b3c88af78c3061b5875da7b1770bf1b7b3e4138099a2`;
combined executable/module/asset identity:
`79582fa0f439d63a0ab768c1cdbe1ab155c0e98629fe971095322239d1bf9c08`.
Package: `zig-out/neural-monsters/episode1/dk3-neural-episode.pk3`,
1,874,338,862 bytes, SHA-256
`e58e1d7ca38e82b734032f328445c8547b0ae829704918d736dc563b625cf7c0`.
The current link now selects the sequence 329 installation above.
The preserved installation and original save remain untouched; no Git operations.

Evidence: `zig-out/reports/runtime-zig-328/final-evidence.json`, `native-review.html`,
per-scenario inputs/captures/receipts, and `zig-out/neural-monsters/verification/`.
All engine runs use canonical dkguard, isolated profiles and `--headless` without
`--gpu`. Controlled spawning, facing, health/equipment and fragment suppression are
recorded explicitly. Ordinary attacks, native animation events, contacts, respawn
and actual save/load provide the resulting behavior.

| Scenario | State | Evidence and limits |
|---|---|---|
| All episode-one monsters | Passed | `all-monsters-final-gl2/passed.json`: all 22 installed skeletal models render, each from an independently restored controlled world. Includes the two frozen prisoners. No full level route acceptance. |
| Living guard, body and default gibs | Passed | `guard-body-seams-gl2/`: ordinary Glock death with fragments disabled, 30 joints, 23 samples, 5,707 contacts, sleep and alive restore. `guard-gibs-seams-gl2/` separately verifies default class gibs and corpse retirement. |
| Generic Crox body | Passed | `crox-body-seams-gl2/`: seven joints, 23 samples, 98 contacts, sleep and alive restoration. |
| Mechanical bipeds | Passed | `sludge-body-seams-gl2/` and `rage-body-seams-gl2/`: 28 joints, 24 samples each, ordinary death and alive restoration; 10,313/3,518 contacts. Ragemaster sleeps; Sludgeminion is still awake at the end of this short sample. |
| Connected Venomvermin quadruped | Passed | `venom-body-final-gl2/`: 16 joints, 22 samples, 7,406 contacts, sleep and alive restoration. New run/strike pose reviews retain source event intervals; all-frame edge-stretch p99 is 1.92. |
| Protopod and mechanical mosquito | Passed | `pod-hatch-opening-gl2/`: grounded visible pod 343 in e1m1a hatches the separate `monster_slaughterskeet` actor 345, loads its own IQM, and records 12 hatch views. Existing hatch timing and child gameplay remain authoritative. |
| Five multiplayer characters | Passed | `network-characters-final-gl2/result.json`: two real UDP clients; Hiro, Mikiko, Superfly, Mishima and Usagi have 15-frame gait at 30 Hz, moving/stationary attacks, complete death playback before respawn, retained bodies and sleep. Final contacts are 2,462/3,023/2,360/3,020/1,979. Disabling ragdolls clears retained presentations. Four recorded map restarts use the same authored spawn for each appearance. LAN lifecycle checks also pass. |
| Held weapons and carry | Passed | `held-weapons-seams-gl2/`: remote sword, rifle and Glock grips/attacks. `carry-seams-gl2/`: carried Mikiko/Superfly performance, movement, shadows and alive save restoration. |
| Companion death/restoration | Passed | `companion-body-opening-gl2/`: ordinary Glock kills Mikiko; 30 joints, 24 physical samples, 2,960 contacts and sleep. Actual load restores her alive and clears the corpse. Collision-checked observer placement and torso aim are recorded. |
| Intro practice/dialogue | Passed within scope | `intro-motion-seams-gl2/`: Hiro/Usagi models, practice motion bursts, sampled poses through shot 35 and actual mid-cinematic save restoration. The complete 115-shot intro and all story performances remain unverified. |
| Saved Superfly encounter | Passed | `encounter-seams-gl2/`: copied autosave, ordinary trigger 50 contact, all 13 authored shots, original torture apparatus retained, active/completed scene restoration and player control release. Later rescue/full campaign remain unverified. |
| Final package lineage | Passed | `verification/package-quadruped-diff.json`: final correction changes only Venomvermin IQM and the manifest; all other 131 runtime models, textures, skins, shaders and physics mapping match the seam-qualified package. Engine/modules/base content also match the earlier passing scenario identities. Thus unchanged affected scenarios retain their exact qualified assets. |
| Broad aggregate | Passed | `aggregate-final.log`: 52/52 steps, 442/442 Zig tests, 125 Python tests and C contracts. Contracts cover anatomy, mechanical/pod rigidity, quadruped event/length preservation, bounded face registration, lighting-only byte changes, missing normals, frozen prisoners, stage invalidation and strict package reuse/admission. |
| Protected assets/state | Passed | `verification/protected-final.json`: prisoner inputs, concepts, prompts, conversion metadata, IQMs and atlases are unchanged; published prisoner meshes/atlases match. Source autosave SHA-256 remains `6241cc17800ea58c99d293e16173bb0f9163b6ce890b6434e591540d97b7355d`. |

Earlier failed diagnostics remain visible. The e1m3b pod fixture lacked authored
air routes for the child's later retreat; the successful replay uses e1m1a. An
intermediate `e1m1` spelling was not an installed map. The e1m3b companion fixture
lost its shot lane behind a pillar and a subsequent low-health ally could be killed
by surrounding enemies before the observer's shot; the isolated opening fixture
qualifies ordinary fire and restoration. A wall/stair-adjacent multiplayer Mishima
body remained awake after 8.4 seconds. Equal-spawn replay settles all five rigs;
general settling at that earlier placement remains a known physics limit. None of
these failed runs is counted as a passing complete scenario.

Physics is cosmetic and collision volumes approximate the skinned bodies. Exact
cloth/triangle/body-to-body collision, persisted physical poses, every placement,
all cinematic performances, full campaign and hardware rendering are not qualified.
Concept output is 1280 pixels despite the requested 2048; generated GLBs retain
4096-pixel PBR atlases, while runtime materials use base color and no facial morphs.

## Sequence 327 — skills-attachments-corpse-physics — verified on focused saved and multiplayer scenarios

Fresh multiplayer advancement starts with all five attributes at zero for every
appearance. Earned advancement still survives respawn. Timed skill pickups expose
level five through the shared character rules, movement parameters and HUD, without
changing permanent attributes; their existing expiry remains intact.

Attached models now sample their parent's pose at render time using persistent
parent/world identities, including nested attachments. Tossed pickups recover a
partly embedded hull before settling, keep the precise contact point, and follow
moving supports. Grounded pickups no longer repeatedly restart their gravity path.

Weapon damage carries cumulative, sequenced body impulses in snapshots. Dead players
and retained multiplayer bodies remain damageable, with score/death processing only
once. Respawn retains the same body identity in an ordinary entity slot. Powerful
lethal hits, substantial lethal explosions and sufficient overkill produce flesh
fragments, and fragmented bodies retire their cosmetic ragdolls. Body solvers inherit authoritative velocity, release
joint constraints gradually, and wake on localized subsequent impulses. Projectile
splash now admits dead bodies and uses the blast direction without duplicating the
shared death impulse. Console suicide retains its ordinary ragdoll path.

Engine and native entity delta schemas advance together to protocol 1351. Matching
client/server builds are required. Generated room compatibility metadata now uses
the same protocol instead of the stale 1349 literal. Original saves remain compatible;
source saves and the preserved installation are untouched. All runs use dkguard, copied state,
isolated profiles and software rendering. No Git operations or service deployment.

Final installation used by `zig build play`:
`81687de5a239474418de2ff1240c08e8f88d79d95733f1386d1e68ff18a6d49a`;
combined executable/module/asset identity
`d6d73498e12c6414fa05d1aa289e9ceeb2b43455174b637bad6023b32f4db0f1`.
Earlier focused scenario identities remain recorded in their own evidence files;
final refresh adds the matching protocol metadata and a test-literal correction.

Evidence: `zig-out/reports/runtime-zig-327/`. Reproducible scenario driver:
`dkq3/tools/runtime_physics_repair_probe.py`. Diagnostic placement, elevated health,
equipment and spawned pickups are recorded; contact, button use, attacks and respawn
use ordinary client input. These are focused defect checks, not continuous campaign
acceptance.

| Scenario | State | Evidence and limits |
|---|---|---|
| Five full-bar single-player pickups | Passed | `skills-final-gl2/` and the later `skills-admission-gl2/passed.json`: ordinary contact fills all five bars; inspected capture shows five segments per bar; save/load retains active boosts; expiry restores permanent zero attributes. |
| Autosave lift attachment | Passed | `saved-gl2/` and `saved-final-gl1/`: copied e1m3b autosave, ordinary t478 button use; 188.9/186.2 units of lift travel, zero X/Z offset range, three units of the button's own Y travel. Saved state reloads; original autosave hash remains `6241cc17800ea58c99d293e16173bb0f9163b6ce890b6434e591540d97b7355d`. |
| Grounded pickups near autosave | Passed | Same runs: four visible grounded pickups, including the health pack, show zero sampled position range. More maps/support geometries remain unverified. |
| Multiplayer skills, deaths and corpse hits | Passed | `network-final-gl2/` and `network-friction-gl1/`: two real UDP clients, zero bars across all five character selections; ordinary speed pickup fills the bar and expiry returns it to zero. Glock death produces an articulated body; respawn retains its identity; a later Glock hit wakes and moves it (GL1 pelvis displacement 0.573 units). Sidewinder hits fragment both the retained body and a living player; corpse hits do not award another kill. Screenshots inspected. |
| Single-player companion and restore | Passed | `companion-ragdoll/passed.json`: ordinary Glock fire kills grounded Mikiko, her bone solver settles with world contacts, and actual load restores her alive and removes the dead presentation. Existing fixture/movement/shadow captures retained. |
| Installed multiplayer checkpoint | Passed | `installed-network-gl2/result.json`: all multiplayer checks pass on the final play installation; combined identity matches the recorded installation identity. |
| Broad aggregate and focused repair | Passed | `aggregate.log`: all other targets pass (227 Zig tests, 113 Python tests and C contracts); runtime-root compilation caught an ambiguous new test literal. After its correction, `runtime-repair-checks.log` passes 64/64 steps and 302 runtime/catalog tests. There are 442 distinct Zig tests across these results, with the 87 catalog tests counted once. No duplicate whole-suite rerun. New contracts cover full-bar expiry, zero MP advancement, nested attachments, gib policy, corpse damage without another kill, gradual pose release/waking, and retained-body native save admission/rebasing. |
| Preserved state | Passed | `original-save.json`: original autosave is byte-identical. No Git, preserved-installation, or external-service mutation. |

The articulated bone solver remains cosmetic, with an approximate authoritative
corpse hull. Exact bone hit locations, identical articulated trajectories on every
client, all weapons/materials/maps and hardware rendering are not qualified here.
The sandbox-only first renderer launch could not connect to X11; approved virtual
display runs succeeded. `skills-gl2-approved/` retained a failed pickup setup after
the path reached a wall. The corrected driver returns to a known grounded origin
before each actual pickup; no attribute grant is used. `network-gl2/` exposed
the lethal-explosion threshold edge case (68 damage left −38 health without gibs);
the repaired weapon policy qualifies substantial lethal explosive hits. Its final
replay fragments that case. `network-final-gl1/` measured movement below an imposed
one-unit handgun slide threshold; floor friction arrested the body after a real
response. `network-friction-gl1/` checks motion above diagnostic resolution instead
of prescribing a fixed displacement for every weapon. Failed setup/assertion evidence
is retained and is not included in the passing results.

## Sequence 326 — superfly-encounter-prop — verified on the saved encounter

The owner's screenshot from reaching Superfly in e1m3b was reproduced through
ordinary contact with encounter trigger 50. The cinematic camera was looking
through giant limbs because the cosmetic package replaced the torture apparatus
`models/e1/d1_supertorture.dkm` with a generated Superfly body. The character
classifier admitted this multipart prop as a humanoid, and fitting to the whole
device produced a body with Z bounds −34.005 to 459.499. The converted apparatus's
own bounds are −23.726 to 106.274. Neither the authored camera nor the player's
death state caused this view; the player is alive and frozen for the scene.

The classifier now leaves this device with its converted prop geometry. Package
admission rejects that invalid body substitution, and the package tool can prune
it from an existing local overlay without refitting other performances. The
installed local overlay was repaired: its faulty IQM and four skins are removed,
the manifest/report hashes are refreshed, and all 594 other non-manifest entries
remain byte-identical. The original converted model package is unchanged; the
old local cosmetic overlay is retained in the report directory. Native movement,
actor placement, authored camera paths and saved model identities are unchanged.

Installed build
`925b35601295734af913ac3e57c14dd55e39cf2554b91107b6665ed2ac4dd7d9`;
combined executable/module/asset identity
`060db5bdb0e15f70909b02b9cb27352a44e2ae6f4c6b9c344e5778e20d15be13`.
Evidence: `zig-out/reports/runtime-zig-326/`. Driver:
`dkq3/tools/runtime_superfly_cinematic_probe.py`, through dkguard with isolated
profiles and software rendering. `zig build play-install -j8` refreshed the
installation used by ordinary `zig build play`.

| Scenario | State | Evidence and limits |
|---|---|---|
| Reported giant limbs | Expected defect reproduced | `encounter-before/`: prior installation and copied autosave; actual forward contact removes the first decorative stand-in and starts `e1m3_cinemid`. First-shot captures reproduce the supplied view; generated prop height exceeds 400 units. |
| Corrected encounter view | Passed | `encounter-final/`: inspected first-shot captures show the apparatus in place of the giant body. The apparatus remains an authored world entity; the trigger removes `superdeco` as authored. Subsequent Hiro/Superfly shots also captured and sampled visually. |
| Entire encounter and restoration | Passed | `encounter-final/passed.json`: all 13 encounter shots observed; saving/loading within the active first shot retains frozen viewer ownership and the corrected view. Natural completion returns normal control; saving/loading the completed encounter keeps it completed. Diagnostic placement outside the trigger, ordinary forward contact, original saved health/difficulty/inventory. This is the encounter cinematic, not the later four-shot rescue or full campaign. |
| Cosmetic package repair | Passed | `package-repair.json`: removes only the faulty prop IQM/four skins and updates the two manifests; 594 other entries match the old overlay byte-for-byte. Corrected overlay passes normal package admission against the same converted models. Old overlay retained as `neural-before.pk3`, local assets only. |
| Broad checks | Passed | `aggregate.log`: 52/52 steps, 435/435 Zig tests, 109 Python tests and C contracts. The new package regression rejects the invalid override, repairs a local overlay, and verifies unrelated performance bytes and admission integrity. |
| Original save | Passed | `original-save.json`: source autosave hash unchanged. No Git operations or preserved installation/main changes. |
| Other props/cinematics | Unverified | This repair excludes the identified multipart apparatus. It is not acceptance of the full cosmetic model classification or cinematic catalog, all facial performances, the later rescue sequence, or hardware rendering. |

## Sequence 325 — saved-button-travel-and-lift-carry — verified on copied Solitary saves

The fixes in sequences 323–324 did not repair existing native saves. The owner's
`save2.sav` still contained the old travel endpoints for all 25 e1m3a buttons;
`autosave.sav` retained them for all 14 e1m3b buttons. Restoring the saved mover
replaced the corrected fresh-map component, so a flush panel still travelled two
units behind its wall. Admission now recognizes that old hull-based formula,
repairs the endpoints and remaps the saved pose and trajectory together. A
`travel_version` marker makes this idempotent. Already-correct markerless saves
keep their endpoints; used latches, target delivery, travel timing and dwell
remain saved state. Explicit platform heights and angular travel stay intact.

Lift prediction had two faults. The server's pusher had already carried the player
to snapshot time, but command replay carried that origin again and tested against
brush geometry at render time. Replay now uses the snapshot's committed geometry,
then adjusts grounded presentation once from snapshot time to render time, including
render frames before the newest snapshot. Separately, a platform catching a falling
stationary player could turn a tiny outward collision residue into the full falling
speed upward. Ground movement now discards that residue when there is no tangential
motion. An engine replay measured the former −79 → +79 velocity reversal and lost
ground contact; the repaired landing keeps vertical velocity zero. Existing bundled
movement differential cases still pass; the new stationary-support case explicitly
corrects this edge case rather than asserting reference parity for it.

Saved movers also lacked the later authored audio fields. Restoration now resolves
those fields against the saved resource registry, with the active world's bindings
published before the initial gamestate. Leading slashes in authored sound paths are
normalized: restored resident maps exposed `sounds//doors/...` causing media admission
failure. Mixer audibility is **unverified in these saved-game runs**: ordinary load
disables cheats, so `s_show` rejects channel inspection. Sound dispatch and persisted
bindings alone are not evidence that a sample was heard.

Final play installation:
`d61c5af7426f2faccf5939b8f5e66735743dd525662c5cb88a05d84358e92109`;
combined executable/module/asset identity
`b6645c24846cf38389c047c0c3eea535d9049fb0d9225eeda58554d26549fcfe`.
`zig build play-install -j8` refreshed the isolated installation used by
`zig build play`. Evidence is under `zig-out/reports/runtime-zig-325/`;
the reproducible driver is `dkq3/tools/runtime_saved_mover_probe.py`.

| Scenario | State | Evidence and limits |
|---|---|---|
| Old saved endpoints | Expected defect reproduced | `saved-before-101/`: previous sequence-324 installation restores all 25 incorrect e1m3a button endpoints; flush terminal 101 still travels two units. This run's immediate pressed capture used the terminal's remote camera and does not prove disappearance visually. |
| e1m3a saved buttons | Passed | `save2-verified/`: all 25 endpoints match authored travel; ordinary use of flush terminal 101 keeps its face visible, including after actual save/load. The permanent used latch stays open and audio binding is retained. Captures inspected after the authored remote camera returns. Diagnostic placement, original saved inventory/difficulty. |
| e1m3b saved buttons | Passed | `autosave-verified/`: all 14 endpoints match; ordinary use of panel 357 leaves the triangle visible, also after save/load. Press travels three units rather than five. Captures inspected; restored press binding and sound dispatch recorded, audibility unverified. |
| Saved platform ascent and landing | Passed | `save2-verified/lift-frames.json` and `view-summary.json`: 751 rendered frames, 743 supported rider frames, zero feet/deck or camera/deck range and no authoritative-ground loss, including initial landing. 717 supported frames precede snapshot time. Living rider contact renews this platform's upper dwell; this is ascent/dwell acceptance, not a descended cycle. |
| Saved large lift ascent/descent | Passed | `save2-verified/big-lift-frames.json` and `view-summary.json`: 2,180 supported frames, 169 rising and 156 falling samples; feet/deck and camera/deck range below 0.0003 units, zero lost ground. Button 110 is pressed with ordinary use; elevated player health permits observation amid Inmater attacks. No trajectory or geometry fixture. |
| Fresh platform ascent and dwell | Passed | `fresh-lift-final/`: 705 rendered frames, 658 supported, 43 rising samples, zero camera/deck and feet/deck range, zero lost ground. Elevated health keeps the observation alive. The platform correctly holds its upper dwell while touched. |
| Broad checks | Passed | `aggregate-landing.log`: 52/52 build steps, 435/435 Zig tests including 208 runtime checks; 108 Python tests and C contracts pass. Compiler-cache writes initially failed in the sandbox; approved runs succeeded. |
| Preserved saves | Passed | `original-saves.json`: both source saves remain byte-identical. All engine runs use dkguard, isolated profiles and software rendering. No Git operation, main merge, preserved installation or service change. |
| Other mover/save cases | Implemented; unverified in engine | Recognized translating-door and implicit-platform save travel is admitted by the shared migration; other maps, parent-rotated saves, every mover class and hardware rendering are not qualified by these cases. Full campaign acceptance remains open. |

Failed setup and intermediate evidence is retained. `saved-final-101/` exposed the
leading-slash resident-media fault; `save2-final/` captured the actual landing bounce
before repair. `save2-landing-final/` passed the repaired panel and platform, but its
large-lift placement landed on the raised button instead of the deck and the player
died during the wait. The corrected fixture clears that button's hull and records
elevated health. `fresh-lift-verified/` crossed into the death camera, invalidating
its camera range; `fresh-lift-living-verified/` incorrectly required descent while
living contact held the platform open. Neither is accepted as a living full-cycle
test. Earlier `--audible` failures were unavailable cheat-protected instrumentation,
not demonstrated mixer silence. The final rows above supersede those outcomes and
the earlier saved-game/living-rider acceptance claims.
An additional `autosave-before-defect/` visual comparison could not start because
the previous immutable installation had been removed during subsequent installation
refreshes. It supplies no old-panel visual acceptance; the original expected-defect
endpoint report and final inspected panel captures remain the recorded evidence.

## Sequence 324 — Authored mover motion, settling and looping audio — verified on Solitary

Sequence 323 made the buttons of "Solitary" (e1m3a) audible and stopped them sinking into the
wall, and recorded the rest of mover audio as unread. This sequence reads that remainder: the
motion pair `sound_opening`/`sound_closing` and `sound_up`/`sound_down`, the settling pair
`sound_open_finish`/`sound_close_finish` and `sound_top`/`sound_bottom`, the authored loudness and
attenuation keys, and the looped form of a motion sound. Across the 84 converted maps 900 brushes
author `sound_opening`, 622 `sound_closing`, 551 the open-settling key and 508 the close-settling
key; 23 platforms use the up/down pair and 20 of those the top/bottom pair; the loop spawnflag sits
on 297 sliding doors, 110 rotating doors and 55 trains. Trains stay silent by authoring intent: no
reference train source reads any of these keys, so nothing is lost by not reading them here. The
door family and the platform family share one pair of slots, so a brush needs only the spelling its
classname uses. Authored `volume`, `min` and `max` reach the mixer when present and the ordinary
attenuation distances otherwise, which are also the distances the reference uses when a mover
authors none.

Two defects stood between those keys and the player's ear, and neither was about reading them.

A settling sound was started at the middle of the brush that owns it, which for a sliding panel is
inside the wall pocket it vanishes into. The server assembles each client's snapshot from the
potentially-visible set, so an entity outside that set is never transmitted at all, and the event
disappeared before any client could weigh it: a door closing behind the player, or one whose
settled position sits in a pocket the player cannot see into, was silent while the same brush's
start sound, emitted before it moved, came through. Sound events are now broadcast to every client
and the mixer decides audibility from the emitter distance, which is what the engine's own sound
entry point did before the native runtime replaced it. The position stays on the event; only the
visibility test moved to where the listener is. That is also what the reference produced, so a busy
scene now sends every sound to every client and lets the mixer discard what is too far away: no run
here came near the snapshot limit, and none reported an overflow.

A looping motion sound cannot ride the brush it belongs to. Compiled inline brushes here keep their
own world coordinates and leave the entity position at the map origin, so a loop offered on the
brush entity is heard from the origin of the level, and every looping mover sound in the game was
inaudible wherever the player actually stood. The reference reaches that same sample through the
entity's sound origin, which in its build is the middle of the brush. Motion loops now travel on a
carrier entity of their own, placed at the audible middle of the brush's committed bounds, following
the brush's own trajectory and withdrawn the frame the brush settles — the convention the authored
ambient emitters already use. `Mover.loop_carrier` names the carrier and is transient: a mover
restored in mid-flight simply regains one on the next frame, and a carrier whose mover vanished is
collected by the ordinary event expiry. The mover diagnostic reports `loop_offer` and `carrier`
rather than a loop flag on the brush, which is what the numbers below come from; the probes under
`dkq3/tools` read only the fields ahead of those, so they were unaffected.

`zig build test -j8` exits 0 with 204 runtime checks passing, one new among them: it pins that a
carrier starts at the middle of its brush, tracks the authored travel, and stops with the settled
brush rather than drifting past it. That check failed when first written, because the authored
travel of that brush is its extent minus the lip, not its thickness. Evidence is under
`zig-out/reports/runtime-zig-324/`, produced by build
`54ad4da4f8880812bc56e10625082b03d62d8d08f31efb12e105ea73a8ebd9a6` through dkguard with isolated
profiles; the preserved installation and saves are untouched. The drivers are kept in `tools/`.

Audibility is read from the mixer itself rather than from the sound-start trace: with `s_show 2` the
engine prints every audible channel each mixing frame, and a local addition (see the deviation row)
makes it report looping channels too, which stock reporting omits — without it a loop can only be
shown as submitted, never as heard.

| Scenario | State | Evidence and limits |
|---|---|---|
| Looping door (loop spawnflag) | Passed in engine | `mixer/mixer.json`, `mixer/mixer-report.txt`: while door 28 travels on button 27, `sounds/doors/e1/hydrolic2loop.wav` is reported as a looping channel on 245 mixing frames, peak 118 against the mixer's 127 master, carried by one entity throughout (`loop_offer=4`, `carrier=770`); `sounds/doors/e1/hydrolic2end.wav` then settles the open end. |
| One-shot door | Passed in engine | `sounds/doors/e1/celldoor1openloop.wav` mixed on 42 frames and `sounds/doors/e1/celldoor1openend.wav` on 20, with no loop offered and no carrier for door 259 — the unlooped form plays once per transition. |
| Authored lift platform | Passed in engine | Mover 19 (`func_plat`, height 120, speed 200) cycled closed → opening → open → closing → closed with the player riding it (ground entity 71 throughout): `sounds/doors/e1/lift1loop.wav` as a looping channel on 73 frames, on one carrier for the rise and a second for the fall (`carrier=803`, then `810`), and `sounds/doors/e1/lift1stop.wav` at both ends of the travel. |
| Settling sounds reach the player | Passed in engine, defect-driven | All three settling sounds above are heard from the settled brush, two of which sit inside their wall pocket. Before the broadcast change none of them reached the client at all, although the same brush's motion sound did. |
| Sequence 323 regressions | Passed | `sound/sound.json`: press audio still starts for buttons 75, 268 and 435. `travel/travel.json`: all 25 authored buttons match extent-minus-lip, mismatches 0. |
| Unit coverage | Passed | 204 runtime checks, exit 0, including the new carrier-trajectory check. One stray `failed command:` line still appears beside the ragdoll test's own raw diagnostics. |
| Engine fork deviation | Implemented, owner review requested | `tools/mixer-probe.diff` adds looping channels to the `s_show 2` debug report in `engine/ioquake3/code/client/snd_dma.c`, three lines, debug output only. Stock reporting cannot show a loop being heard, and a verification aid that is thrown away leaves no reproducible evidence behind. Revert it if the fork should stay closer to upstream. |
| Authored loudness on a mover | Implemented, not exercised | `volume`/`min`/`max` are resolved and sent on both the one-shot and the carrier path, but the movers driven here author none of them, so the authored values were not heard in engine. `func_train` also ignores them in the reference. |
| Rotating-door loop flag | Not exercised | The rotating-door loop spelling is read, and maps author it, but no rotating brush with it was driven in this run. |
| Save during a travel | Not exercised | A mover restored mid-travel resumes its motion but not its loop until the next transition; the carrier itself is never restored, by design. |
| Channel choice | Differs from reference | Motion and settling sounds use the automatic channel; the reference forces its own override channel, which this engine's sound interface does not offer, so two sounds can now share a brush where the reference would have cut one off. |
| Secret-door step lengths | Unchanged, approximate | As recorded in sequence 323: the reference drives that brush from an authored distance rather than brush size, and that path was deliberately left alone. |

## Sequence 323 — Solitary mover audio, button travel and ridden-lift camera — two verified, one sampled

Reported while playing the first chapter ("Solitary", e1m3a): wall buttons disappeared when
used, buttons and wall terminals produced no sound, and standing on a lift that travels
up or down made the view twitch.

Silence had two independent causes. The authored press and pop-back keys on a button were
never read anywhere in the runtime, so nothing was registered or started; and even once
registered, a brush entity's own origin is model-local, so an event placed at the entity
origin lands at the map origin, while one placed at the brush's audible centre but addressed
to a listener position is dropped by the audible-set filter — a player standing 56 units in
front of a panel heard nothing. `src/classes/entities/mover/server/movers.zig` now resolves those two keys
through the map sound registry into two fields on the mover component
(`src/core/domain/movers.zig`) and starts them from the centre of the brush's committed
world bounds on the broadcast path. Archives written before the fields existed stay silent,
which the new `domain/snapshot` test pins.

The disappearing panels were a travel-distance defect. Mover travel is the brush extent along
the movement axis minus the authored lip, but that extent was taken from the clipper's hull,
which widens every inline brush by one unit per side; the reference server state derives its
mover size by contracting the loaded model hull by exactly that amount so that authored lips
behave as written. Every one of the 25 buttons on this map therefore pressed two units deeper
than authored, and six of them are authored with lip equal to their thickness, meaning they
were built not to move at all — those sank behind the wall surface and vanished. Travel now
uses the authored extents. `src/runtime_tests.zig` also imports `server/movers.zig` for test
collection, because its checks had never been reachable.

The twitch was a prediction gap, not a mover defect: the server carries a rider positionally,
but client prediction had no notion of ground-mover motion, so the camera advanced at snapshot
rate while the ridden brush is trajectory-evaluated every frame. `src/client.zig` now
carries the ridden brush's trajectory inside each replayed command.

`zig build test -j8` exits 0; 203 runtime tests pass, including three new ones. Its progress
output still prints one stray `failed command:` line beside the ragdoll test's own raw
diagnostics; running that test binary directly reports `All 203 tests passed` with status 0.
Evidence is under `zig-out/reports/runtime-zig-323/`, produced by build
`c971f00b83361242f81073cccc435273cc072fcadf6a2147572da96690b80764` through dkguard with
isolated profiles; the preserved installation and saves are untouched.

| Scenario | State | Evidence and limits |
|---|---|---|
| Authored press and return audio | Passed in engine | `sound/sound.json` with `s_show 1`: `sounds/global/b_009.wav`, `sounds/doors/e1/button1in.wav` and `sounds/global/b_010.wav` start with the player 56 units in front of buttons 75, 268 and 435, and button 268's `button1out` follows after its dwell. The weapon-fire control line did not appear in the final run, so the channel proof rests on the button lines themselves. |
| Travel of every authored button on the map | Passed | `travel/travel.json`: all 25 `func_button` movers match the authored extent-minus-lip vector exactly (25/25, mismatches 0), taken from the map's own model bounds. Before the change all 25 were two units deep on the moving axis. |
| Panel stays visible while pressed | Passed, inspected | `visual/`: before/open/hold/after captures for buttons 27, 47 and 75 plus the pre-fix pair for 27, where the panel was gone. The drawn-brush count stays at 34 and 41 across the use, so the brush is still being drawn rather than culled. |
| Riding the authored lift | Sampled, not frame-complete | `lift/camera-series.txt`: 90 camera reports across 24 distinct rendered frames, monotone +79.3 units, one zero-motion frame and no reversal beyond two units; the earlier snapshot-rate staircase is absent. One +16.4-unit step at the ride boundary is unexplained — a per-frame comparison against the brush needed a temporary client probe that has since been removed, so no before/after exists on this build. |
| Unit coverage | Passed | 203 runtime tests, including authored travel from a real hull, a zero-travel button, silent pre-audio archives, and the newly reachable `server/movers.zig` root. |
| Other authored mover audio | Not implemented | `sound_opening`, `sound_closing`, the open/close finish pair and the train/platform up/top/down/bottom set are still unread, as are looping mover sounds. Buttons are the only class that emits. |
| Secret-door step lengths | Unchanged, approximate | `func_door_secret` still measures the spread hull, and the reference drives that brush from an authored distance rather than brush size. Left alone deliberately; not re-measured. |

## Sequence 322 — multiplayer bot skill ladder and field of view — implemented; unverified

Bots in a multiplayer match played at maximum strength: target choice ignored facing,
the commanded view snapped onto the enemy centre on the acquiring tick, the difficulty
value written into bot userinfo was never read, and only the LAN page had a control that
wrote the five-level single-player cvar. One ten-level ladder now defines view cone,
sight range, proximity radius, target memory, reaction delay, view turn rate, aim error
and settle, burst interval, search period and gunshot-bearing error. Selection lives on
both hosting pages, travels in the room configuration and reaches the server as
`dk3_bot_skill` (1–10, default 5), with `dk3_bot_fov` reserved for diagnosis.
Definitions, measured turn-to-notice times and the investigation are in
[bot skill and sight](bots-zig.md).

`zig build test -j1 --summary all`: 52 steps, 427 tests pass. The aggregate check had
been failing at its `zig fmt --check` step on `src/mechanics/server/bots.zig`, not on a test
abort; the file is formatted and the whole graph runs. Sampled dedicated-match evidence is
in `zig-out/reports/runtime-zig-322/`, produced by the new
`dkq3/tools/runtime_bot_skill_probe.py` (parser covered by
`dkq3/tools/tests/test_bot_skill_probe.py`). Sampling also corrected three things written
earlier in this sequence: the `dk3_bot_fov` diagnostic wrapped 359° to 0° instead of
clamping, forward and right movement were projected onto the sweeping view so a bot
checking its shoulder walked sideways, and the report line printed the ladder cone instead
of the cone actually in force, so an override was invisible in its own evidence.

| Scenario | State | Evidence and limits |
|---|---|---|
| Pure ladder policy | Passed | `zig test src/mechanics/domain/bot_skill.zig`: monotone 1→10, cone/proximity/range admission, rate-limited turning, an enemy at the bot's back is never visible without turning, bounded reproducible aim noise. Unit coverage only, not gameplay. |
| Cone acquisition in a real match | Sampled, unverified | e1dm2a FFA, four bots, levels changed live (`zig-out/reports/runtime-zig-322/ladder`): samples holding a target fell 38% → 21% → 12% across levels 10/5/1 with 0 faults. Same map and levels with `dk3_bot_fov 2`: 27% → 2% → 2%. Unscheduled encounters, so the gaps are indicative; the cone geometry itself is pinned by the policy tests. No human client involved. |
| Look-around search | Sampled, unverified | In every run the commanded view differs from the previous sample on 79–90 of 84–92 reports and the sweep headings {-80,-40,0,40,80} all appear, so the view is never locked forward. Not observed: a specific hidden enemy becoming visible only because a sweep reached it — that still needs a scripted approach from behind. |
| Difficulty selection while hosting | Unrun | Code path is in place on both pages (`ui_roomSkill` → `dk3_bot_skill` for LAN, `RoomConfig.skill` 1..10 for the coordinator, browser row carries `bots` and `skill`). Needs real menu input on the LAN page and the Create Internet room page to confirm the level reaches the server, the room record and the browser row. |
| Reaction and burst discipline | Unrun | Timed firefights at levels 1, 5 and 10 against a stationary and a moving human-controlled client are still required; sampled runs only show 1–5 hurt-alert turns per match. |
| Navigation regression with scanning | Sampled, unverified | Across the sampled runs `blocked` appeared in 0–2 reports per ~90 and 50–59 distinct waypoint edges were traversed, with jumps and ladders still taken. The accepted bot lift and deathtag course replays have not been re-run since the view became rate limited. |
| Level balance | Unrun | Owner review of playability at each level; not a decision this sequence makes. Encounter frequency on large maps is gated by sight range before the cone, so emptiness on big maps is a sight-range question. |


## Sequence 321 — stable skeletal geometry — focused scenarios passed

Ragdoll child anchors now remain connected through the skeleton hierarchy, so
physics constraint residuals cannot stretch the rendered bone chain. Local neural
weights are rebuilt around rigid segment targets and joint transitions, relaxed
on the welded surface to avoid sharp seams. The first strictly rigid/two-bone
attempt worsened boundary stretch and was rejected (`deformation-preview.log`).
The accepted candidate uses continuous surface transitions.

Evidence: `zig-out/reports/runtime-zig-321/`. Reviewed local package
`58a44924f8c91c20dbc86ed54477c2579bcb3d48f2fccecac9ca354a881a505e`.
`package-invariants.json` verifies 96 IQMs changed only in weights/indices and
bounds; 504 other entries are identical. Faces, motion bytes and props are retained.
`deformation-final.log` samples 20 gameplay frames per character: 99th-percentile
edge-length ratios decrease for all five (Hiro 1.486→1.451, Mikiko 1.808→1.265,
Superfly 1.614→1.340, Mishima 1.824→1.474, Usagi 2.968→2.170). These are deformation
diagnostics, not complete visual acceptance; isolated worst-case triangles remain,
and some maxima increase. Hard joint cuts, topology problems and every cinematic
performance are not claimed repaired.

| Scenario | State | Evidence and limits |
|---|---|---|
| Package preservation and weight regression | Passed | Exact byte-range comparison; rigid section, seam and joint-transition unit coverage. |
| Multiplayer deaths and lifecycle | Passed, sampled scope | `deaths/`: all five characters, stationary/moving attacks, physical falls/settling, retained bodies, disable/reset and complete LAN lifecycle. Rendered anchors follow the connected skeleton. |
| Cinematic and carrying presentation | Passed, sampled scope | `intro/`: Hiro practice motion bursts, Usagi scene through shot 35, actual save/load; `carry/`: combined Mikiko/Superfly body, movement and restoration. Textures/prop animation bytes are unchanged. Full cinematic catalog remains unverified. |
| Aggregate checks | Passed | `tests.log`: 52/52 steps, 426 Zig tests, 105 Python tests. Includes concurrent bot-skill unit coverage present when the suite ran. |

`cinematic-deformation.log` adds 24 sampled intro/carry poses: Usagi and carrying
improve their 99th-percentile edge ratios; Hiro's ratio slightly increases
(1.310→1.330), while its worst stretch and count above twice rest length decrease.
This is a targeted stability improvement, not an assertion of distortion-free
skinning. The initial combined `network/` run walked into blocking geometry before
its moving-attack assertion; the separate `deaths/` replay passes. Both are retained.
Only guarded software rendering was exercised for this pass. The old package is
retained locally as `dk3-neural-320.pk3`; the preserved game/saves were not changed.

The reviewed installation is `79a60df85f2bd04aafc79263deb82fb9d803f38a5e13d6673f4eba890512969a`.
A later normal rebuild failed in concurrently edited `src/online/worker_main.zig`
(import outside module root) and `src/mechanics/ui/multiplayer.zig` (i32/f32 mismatch).
Those unrelated edits were preserved. The exact immutable build used by the
passing scenarios was published to native-dev after verifying every manifest hash
(`publish-tested.log`); this does not claim the current concurrent source tree
builds. State/save directories were not modified.

## Sequence 320 — physical skeletal deaths — focused scenarios passed

The native Zig client now simulates articulated ragdolls from the living pose,
with gravity, inherited movement, joint limits, world collision, friction and
settling. Both renderers accept owned live IQM skin matrices and physics bounds
(renderer ABI 13). Players and actors publish an explicit death flag. Retained
bodies survive multiplayer respawn and clear on presentation reset. No external
physics implementation or new asset package is admitted.

Evidence: `zig-out/reports/runtime-zig-320/`. The sequence-319 neural package is
unchanged (`d529be7652e69d1014f930d301e521c396ef37e1499cf2212d15d5178a56dd18`).
Installed build: `34026a8d5a8ae6664027ac8de7f453615a5a760b6229b767201288848f5c7a3c`.

| Scenario | State | Evidence and limits |
|---|---|---|
| Multiplayer physical deaths | Passed, sampled scope | `network-final/`: two real UDP clients, all five characters, live skin matrices, falling pelvis, world contacts and sleeping bodies after respawn. Includes e1dm1 stairway landings. Attacks, respawn, spectator/rejoin, reconnect and map restart also pass. |
| Campaign actor death and restore | Passed, sampled scope | `actor-mikiko/`: ordinary Glock fire kills a grounded Mikiko; physical collapse and sleep render in e1m3b. Loading the earlier save restores her alive and removes the ragdoll. Companion-death flow remains active. Other actor-specific death policies are not exhaustively replayed. |
| Renderer comparison | Passed, sampled scope | OpenGL2 multiplayer/actor captures and `network-gl1/` Hiro live-pose fall, contacts, settling and retained body. These runs use guarded software rendering, not hardware-GPU acceptance. |
| Solver terrain and transforms | Passed | Floor and slope settle; descending stair treads/landing reject particle penetration and retain limb lengths. 30/60-Hz presentation produces matching fixed-step results. Bind-matrix inversion and antiparallel limb rotations preserve positions/lengths. |
| Aggregate checks | Passed | `tests.log`: 52/52 build steps, 421 Zig tests, 104 Python checks. |

This is cosmetic character physics, not a general server physics replacement.
Classic vertex models and scripted cinematic/carrying models use authored death
poses. Exact corpse bone positions are not saved or synchronized between clients.
Collision volumes approximate the body; corpse-to-corpse pushing, post-death
weapon impulses, moving-platform wakeup and exhaustive campaign acceptance remain
outside this implementation. See [runtime details](neural-assets.md).
Earlier sliding/fixture failures remain in the report; `network-framed/` adds
camera inspection but exposed a probe selecting an older retained body's sleep
state. The installed replay (`network-installed/`) filters by victim identity and
explicitly requires all five new bodies to settle; those checks pass. Its final
disable check used a bare, unregistered cvar command and failed. The corrected
`set cg_ragdolls 0` check passes separately in `network-toggle/`, together with
Hiro death/settling and the complete LAN lifecycle on the installed build.
`ragdolls.mp4` retains the installed fall captures at their sampled timing. Visual review is not owner acceptance.

## Sequence 319 — character references, leg limits and combat motion — focused scenarios passed

Mikiko, Superfly, Mishima and Usagi receive reference-based face bakes; Hiro keeps
the accepted 318 atlas. All five rigs now constrain knee flexion, hip target
direction, ankle/toe rotation and leg twist during conversion. Moving multiplayer
attacks combine upper-body firing poses with the current leg cycle. Respawn waits
for the complete death animation plus a 300 ms final-pose hold.

Evidence: `zig-out/reports/runtime-zig-319/`. Package
`d529be7652e69d1014f930d301e521c396ef37e1499cf2212d15d5178a56dd18`;
installation `9695396d351af4d8435b824afd18c0a710eb6c966c54c2e7bb54f1c05e0502de`.

| Scenario | State | Evidence and limits |
|---|---|---|
| Reference face bakes | Reviewed | `face-edits.md` links the built-in imagegen outputs, exact prompts, final atlases and four-angle mesh reviews. Earlier patchy bakes are retained. Existing facial geometry and painted eyes remain limitations. |
| Remote attacks, deaths and LAN lifecycle | Passed, sampled scope | `network-final/`: two real UDP clients, all five appearances, stationary/moving attacks, 22–26 distinct death frames reaching the final pose with attack held to request respawn throughout. Respawn, spectator/rejoin, reconnect and restart pass. Captures and `remote-combat.mp4` retain observed timing. No ragdoll or slope-contact acceptance is implied. |
| Intro practice and restoration | Passed, sampled scope | `intro-final/`: 1920×1080 OpenGL2 playback through shot 36, timed practice poses, close-ups and actual mid-cinematic save/load. Forward knee bends reviewed. Full intro/later performances remain outside this sample. |
| Companions, carrying and Kage | Passed, sampled scope | `actor-*`: grounded Mikiko, Superfly, carrying and Kage in e1m3b, movement/shadow comparison; companions also save/load. Kage's translucent phase remains. These are presentation fixtures, not full campaign behavior acceptance. |
| Sword, rifle and pistol attacks | Passed, sampled scope | `held-weapons/`: remotely rendered ready/attack poses for Daikatana, Ion and Glock; hand attachments reviewed. Weapon contact behavior is outside this fixture. |
| Aggregate checks | Passed | `tests.log`: 52/52 build steps, 417/417 Zig tests and 104 Python checks. Includes planted feet, fixed lengths, extreme folded/twisted input rejection, attack/leg composition and death respawn timing. Native build and package validation pass. |

The animation constraints are offline pose limits, not a physics engine. The
procedural clips use Quake III naming conventions and contain no imported Quake
motion data. Full ragdolls, body-part collision and all cinematic performances
remain unverified/unimplemented as appropriate. Failed driver invocations before
the UDP run are retained in `network-path-error.log` and `network-combat.log`.
At sequence 319 the default local package and `zig-out/native-dev/play/current` selected this revision;
the preserved installation and saves remain untouched. Visual review is not owner
acceptance. Existing background geometry/MD3 prop problems are not repaired by
these character changes.

## Sequence 318 — Hiro eye placement — revised close-ups reviewed

The owner rejected 317's high eyes and downward appearance. The face bake now
lowers the orbital projection by up to 0.42 mesh units while leaving the nose,
mouth and forehead registered. A separate generated eye/brow edit reduces brow
thickness. Its admission mask replaces old dark eyebrow texels instead of
preserving them as hair, and excludes unwanted generated cheek changes. Lateral
hanging locks and multiplayer face color remain protected.

Evidence: `zig-out/reports/runtime-zig-318/`. Final package
`10ab7bc20741d08cfc2bf3d10d6805b30733d7407bc083d4a3fcdb205adaa08a`;
installation `6ded2e0b902f93357213c4d37343823e6a46bfcea062fefdff1833143bbe67ca`.
The stage retains the final atlas, bake provenance and face tint mask.

| Scenario | State | Evidence and limits |
|---|---|---|
| Actual mesh front and sides | Reviewed | `review-detail/`; lower eyes and reduced brows. Earlier `review*` retain failed mask/brow iterations. |
| OpenGL2 intro and save/load | Passed, sampled scope | `intro-final/`: playback through shot 15 and restored cinematic. Shot 14 and six subsequent camera samples show the reported angle; `intro-face/` is the superseded thick-brow attempt. Visual review is not owner acceptance. |
| Package and tooling | Passed | 102 Python checks, package validation, and final changed-entry audit. Only 13 Hiro PNG entries and metadata change; models, skeletons, clips and other characters match 317. No native changes; prior motion/runtime evidence remains applicable. |

Built-in imagegen outputs and both exact prompts are linked in local `face-edit.md`.
The original Hiro head texture was inspected read-only as an additional style
reference. Eyes remain painted on the existing mesh; facial animation is outside
this revision. No original installation, saves, or Git state was changed.

## Sequence 317 — reference Hiro face — eye placement rejected by owner

The owner subsequently rejected this revision: eyes sit too high, crowd the brows,
and appear to look downward. Sequence 318 addresses that defect. The scenario
results below establish playback and packaging only, not accepted eye placement.

The owner rejected the 316 face close-up: oversized eyes, soft features and a pale
jaw patch. The replacement uses the selected local `neural_experimental_assets/hiro.png`
identity reference, front/side skin projections, and a per-texel mask protecting
hair and multiplayer facial color. The eyes are narrower, the brow heavier and
the stubble follows the jaw. This remains a texture on the existing head mesh;
no animated eyes or facial morphs are introduced.

Evidence: `zig-out/reports/runtime-zig-317/`. Package
`fb2955550b41241213a4a9af622a8eecb60f682b0f838eb0b4880922e42df6ce`;
installation `60b7710b30a16609f5e20bb8cf3ac77cc7f006908906d5b9ea5d8e0d33f03395`.
Exactly thirteen Hiro texture entries and package metadata changed; all model,
animation, shader and other-character hashes match 316. That motion evidence
is unaffected. The new atlas/provenance/tint mask are retained in the staged mesh
folder so subsequent full builds retain this revision.

| Scenario | State | Evidence and limits |
|---|---|---|
| Front and both side mesh views | Reviewed | Four fixed orthographic views in `review-final`; earlier mask failures retained in `review*`. |
| Actual intro close-ups and save/load | Passed, sampled scope | `intro-face`: 1920×1080 OpenGL2 captures through shot 15 and restoration. Shot 14 reproduces the owner's reported angle; shots 6/13 show front and opposite side. `intro-closeups` adds camera-motion samples through shot 9. Visual review is not owner acceptance or full cinematic qualification. |
| Asset/tool checks | Passed | 102 Python tests; includes unchanged protected face pixels across all eleven tinted variants while armor still changes. Package validation and the changed-entry audit pass. Native code is unchanged; the 316 Zig results remain applicable. |

The three exact built-in imagegen prompts, selected projection outputs and baked
atlas are recorded in `face-edit.md` and `prompts.json` in the local report.
Blender's local OCIO data/runtime version mismatch required a report-local profile
override; system files were not modified. No original assets or user saves changed.

## Sequence 316 — skeletal motion and face repair — focused scenarios passed

The owner rejected 315's animation quality: floating swords, slow multiplayer
motion and Hiro's missing eyes. This pass replaces all five experimental skeletons
and weights with reviewed anatomical rigs, authors new fixed-length IK clips, and
keeps loop cadence independent of the old vertex-animation frame count. The client
interpolates clips and blends sequence changes; gameplay/contact clocks stay on
the server. Held props use hand transforms, split cinematic sword pieces share one
grip, and the gameplay sword has a measured handle offset. Hiro's local atlas now
contains a repaired face with visible eyes; facial morphs remain unsupported.

Local package `281e53a5ceb65913d2224b88f320a30641c435801707b957bc9246f388fe4d2a`
contains 94 replacements and two additional multiplayer bodies, with 60 skins.
All 96 IQMs have finite animation channels and normalized weights. Sources and
converted assets remain local. See [tooling and limits](neural-assets.md).

Evidence is under `zig-out/reports/runtime-zig-316/`. Final native grip build:
`a429afe57550787fb0066e9fef7dbe362b8c0af3f3227a3ca6ea3ce8b8f99f9a`.
This build is installed as `zig-out/native-dev/play/current`; the default local
package is selected by `zig build play`. The prior `84420b…` build has identical
rigs, timing and cinematic code; only the
class-owned gameplay sword offset differs. Its unaffected results remain valid.

| Scenario | State | Evidence and scope |
|---|---|---|
| Remote gait and LAN lifecycle | Passed | `network-motion`: all five appearances over real UDP. Actual rendered run frames follow 30 Hz / 15-frame loops across 595–732 ms of settled motion per character; captures and `remote-gaits.mp4` retain measured timing. Fire, respawn, spectator/rejoin, reconnect and restart pass. |
| Cinematic practice and restoration | Passed, sampled scope | `intro-final`: playback through shot 36, 36 timed motion captures, nine shot captures, actual save/load. Practice sword remains hand-attached in reviewed poses; Hiro's face has visible eyes. Full intro and all later performances are not qualified by this sample. |
| Gameplay weapon grips | Passed, sampled scope | `held-weapons-fixed`: remote sword, Ion and Glock ready/attack captures. Sword handle offset removes the observed gap. These are presentation fixtures, not weapon contact acceptance. |
| Companions, carrying and Kage | Passed, sampled scope | `actor-*`: grounded Mikiko, Superfly, carried Mikiko and Kage in e1m3b, movement and shadow comparison; companions also save/load. Mikiko replays on OpenGL1. Kage retains his authored translucent phase. This is not full companion/boss behavior acceptance. |
| Aggregate checks | Passed | `tests.log`: `zig build test --summary all`, 52/52 build steps, 417/417 Zig tests and 101 Python tests. Includes planted-foot/fixed-bone checks across five rigs, clip cadence, released props and split-sword visibility. |

Retained failures: `network-preview` reached a wall before recording enough gait
samples; `network-final` sampled less than the required settled interval. Combined
render/diagnostic captures repair the driver without weakening timing assertions.
`held-weapons` exposed the gameplay sword's offset mesh origin; the class-owned
handle correction and replay address it. Black/angular background geometry in
intro/arrival images also occurs without neural assets (315 stock comparison);
it is not accepted as repaired here.

## Sequence 315 — neural skeletal characters — superseded visual result

The optional skeletal package, native routing, five appearances and shadow bounds
were implemented. Local load, selected cinematic/companion and LAN lifecycle
checks passed, but the owner rejected animation and face quality. Successful
registration and still images did not establish motion acceptance. Sequence 316
replaces the rig/clip conversion; historical evidence remains under
`zig-out/reports/runtime-zig-315/`.

Development: `rewrite/native-zig-runtime`. Preserve main
`e3966c4d40678dbf91619034b5dcb33b763dcbed`, installed playable game, user saves and
live service. The removed gameplay backend remains disconnected. Complete four-episode
campaign, companions, multiplayer/bots, UI, persistence and independent release stay in scope.

Owner-directed cadence: finish the broad connected coding pass, then consolidate the
build/assets and run verification with repairs. No per-item suite/engine gates.
Implementation checkpoints 255–284 add no connected acceptance. No overall percentage
is inferred from class counts or test volume.

## Current outcome matrix

> Historical matrix from the sequence-315 period. The current assessment is
> [status.md](status.md); later sections above supersede individual implementation claims.

Sequence 309 repairs the shared actor ground-departure check, camera mode
transport and multiplayer weapon presentation lifetime, and adds worker fear,
party-health autosaves and softer Cambot lights. Sequence 310 adds the installed-map
picker for Internet Create and LAN hosting. Sequence 311 repairs pickup raises,
first-person stair/duck smoothing, pickup rotation/lighting and weapon shine.
Sequence 312 repairs saved-region loading, worker ZIP cleanup and wet-floor
robot navigation. Sequence 313 enables model silhouette shadows and makes the
launcher explicitly select OpenGL2. Sequence 314 gives the multiplayer Load menu
a local campaign transition. Latest coherent build: `a429af…`,
protocol 1350; earlier gameplay evidence retains its recorded identity below.
**Seamless campaign acceptance remains incomplete.** Fresh opening development
reaches the bridge boss but has not completed the milestone. Ground-controller
changes require replay of earlier encounter/route evidence. Wider weapon
interactions, navigation, party actions, multiple views, seam qualification and
remaining admission stalls stay open. Supporting checks do not measure completion.

| Milestone | Implemented | Contract-tested | Running native engine / connected play | Reference comparison and remaining work |
|---|---|---|---|---|
| Seamless connected regions | Region admission/ordinary exits, qualified collision, actor/projectile transfer, specialized weapons, party ownership and authored script scope | 402 Zig, 82 Python and actual C owner/collision/inline-handle contracts pass | On `187506…`: eleven weapon contact cases, selected controller restores, real turret/frog contact, both renderer combat paths, enemy/companion/player crossing and region save/death restoration | One reviewed corridor and selected interactions. Broader navigation/party actions, multiple views, seam qualification, eviction/admission stalls and fresh route remain open. [Evidence](#sequence-305-specialized-weapons-across-seams). |
| Ground actors and workers | Floor-departure and wet-floor routing repairs; worker retreat/cower and fear audio connected | Settled-motor/jump, capability exclusions and class roots pass through 312 | On `268649…`, Sludgeminion pursues from the unchanged user save; guard dry-ground pursuit/fire replays. Worker/Crox evidence retains its 309 identity | Private ground/water behavior inspected. Full ground-class/worker/campaign routes remain unverified; earlier affected route evidence requires revalidation |
| Weapons | All 28 class-owned controllers connected; 305 extends spatial and persistent ownership | Class roots and ownership/slot/cancellation contracts execute at 305 | Eleven controlled specialized weapon contacts across A/B; Wyndrax, Nightmare, Metamaser and pending Zeus restore on `187506…`. Three actual Trident tips confirmed | Not all interactions: Trident merge/water, Ballista carried crossing/pin restoration, destruction variants, return/pickup and complete audiovisual comparison remain open |
| Fresh opening gate | Intro, actors, authored controls, progression and saves connected | Applicable contract roots execute through 308 | **Not accepted:** fresh 305 and superseded 306 runs reach the bridge encounter and fail. A separate legitimate factory checkpoint reaches e1m2a alive | Full coherent New Game→M2 route still required; boss avoidance/firing-lane strategy remains a driver blocker. No modified inventory or assembled checkpoint chain qualifies. |
| All four episodes | Additional hostile/ambient/boss controllers, scripts, cinematics, companions, world effects and ending connected | Coding-pass contract roots pass at 285; connected scenarios unrun | No complete episode accepted on native runtime | Broader ability/task audit, connected boss/puzzle/companion traversal and ending remain |
| Saves and visited worlds | Region recovery, autosaves, bounded loading work, actual progress and owner-thread ZIP finalization | Runtime/party-health and actual concurrent ZIP/CRC/cancellation contracts pass at 312 | On `268649…`, user autosave/save2 restore via both menus and death recovery in both renderers with all 10/12 resident worlds; original files preserved | Full live-party autosave and fresh campaign restoration remain unverified. 309 autosave timing retains its identity; historical state stays mandatory. [Evidence](#sequence-312-native-restoration-wet-ground) |
| Multiplayer and bots | Native sessions/modes/bots; spawn-aware shared weapon presentation; protocol 1350 | Wire, counter-wrap and respawn contracts pass at 309 | Final 309: two actual UDP clients show advancing attack frames before/after respawn and pass spectate/rejoin/reconnect/restart | Every weapon interaction, full CTF/deathtag, public admission/authenticated rooms and full modes remain open. No service deployment |
| World/effects | Authored controls, hazards, debris, lighting and sky connected; softer Cambot lights and default model silhouettes | Applicable aggregate contracts pass at 313 | Final 313: character floor/wall shadows and restoration in both backends; armor/ammunition shadows and resident combat in OpenGL2. Earlier Cambot/sky evidence retains its identity | Full material/terrain, foreign-view shadow generation, brush casting and performance remain open; Cambot enhancement is not a shadow-mapped spotlight |
| Presentation and cinematic input | Menus/loading art, interpolation, cinematic input and all camera modes connected | Three-bit camera modes survive actual message encoding at 309 | Final 309: ordinary e1m1c button use, remote door view, release and finished-scene save/load. Earlier intro/menu evidence retains its recorded identity | Full fresh intro, all authored scenes, menu equivalence and audiovisual comparison remain unverified |
| Pickup and first-person feedback | Shared class-owned raise transition, stair/duck offsets, selected rotating pickups, minimum model light and neutral shine | Acquisition/queued-input, rotation exclusions and camera replay/boundary contracts execute at 311 | Final 311: one actual Ion pickup draw, smooth crouch/stand and ready-weapon restore in both renderers; three actual e1m1c step rises; armor/ammo/shine captures inspected | Main camera timing and private pickup behavior inspected. Controlled setup; broader weapon interactions, custom rotation overrides and exact glow/material parity remain open |
| Independent release | Bare `zig build play` builds/installs native code with the existing local cache | Build/contracts and installer preservation pass at 286 | Guarded native menu, e1m1a admission and actual save/load pass; explicit map and disabled intro | Full independent fresh-checkout/release and campaign qualification remain |

## Sequence 314 — native-host-to-save

Build `83d6e0d090472eed29e915d8da2a30db37ca0e3fdbc14812c3acc2d05641a4bb`;
combined identity `be918e9f14163e479fcbafa82bdfe73360d933f8bed38a44587bc9bf44249dc8`.
Protocol 1350, renderer ABI 12, assets, shadows and renderer defaults are unchanged.

The native Load menu validates the selected save before closing. During a hosted
or remote match it now disconnects and starts the local saved campaign through
`dk3_loadmenu`, which stages the save and selects single-player mode. An active
local campaign keeps its existing `load` path. Previously the menu forwarded
`load` to the match; the actual hosted reproduction refuses it with
`SaveRequiresSinglePlayer`.

The reported screenshot also showed missing 2D HUD art/text while 3D inventory
models remained visible. The owner clarified that this happened immediately
after Escape → Load in a hosted match and recovered about a minute later.
That transient rendering symptom has **not been reproduced or independently
confirmed fixed**. No speculative renderer change is included in this sequence.

Evidence is under `zig-out/reports/runtime-zig-314/`. All runs use dkguard and
isolated profiles with copied saves; the owner's live files remain untouched.
The original autosave advanced during investigation, so later probes retain a
frozen `source.sav` and its digest rather than assuming the live slot is unchanged.

| Evidence | State and result | Limits |
|---|---|---|
| `build-approved.log` | Passed: integrated native installation, 43/43 build steps | Initial sandbox build lacked writable Zig compiler cache; no duplicate broad suite |
| `direct-old/` | Failed as expected: real hosted Escape → Load refuses the save with `SaveRequiresSinglePlayer` | Reproduces the menu routing defect, not the transient missing HUD |
| `direct-fixed/`, `direct-e1m2b/` | Passed: actual hosted Escape → Load restores copied e1m3a/e1m2b saves, confirms `g_gametype 2`, draws the loading screen and complete HUD when gameplay resumes | OpenGL2 software. Inspected captures plus fixed POWER-label pixel checks across 20/12 subsequent samples at two-second intervals; not proof of the original transient symptom's cause |
| `baseline-restore/`, `baseline-multiplayer/`, `baseline-bots-complete/`, `loading-baseline/`, `background-baseline/`, `loading-opengl1/` | Completed: copied-save restoration from a disconnected menu, loading/background observations in software | Pre-change investigations; both renderers represented. Initial `baseline-bots/` used an insufficient observation timeout |
| `hardware-baseline/` | Completed on NVIDIA RTX 5090 Laptop GPU: disconnected restore retains HUD | Pre-change OpenGL2, console transition, copied settings; no desktop input injection |

## Sequence 313 — native-model-shadows

Build `aa5a4cb4bcf90ec1a1492b265ec393e9217b7f34c6166a500d14b149944bc1cd`;
combined identity `b8934fe160e3976b7751d679773e3bb9d659cabfbeef6ca4ee2f57cded6a49c5`.
Protocol 1350, renderer ABI 12 and local asset packages are unchanged.

The default `cg_shadows 1` now
selects model silhouette shadows in both backends: stencil volumes in OpenGL1,
projected shadow maps in OpenGL2. Video settings expose an archived Model shadows
On/Off control. Opaque actors, corpses, pickups, held weapons and ordinary model
props participate; first-person weapons, fading models and effect overlays do not.
OpenGL2 validates MD3 frame indices before shadow bounds reads, covers both
animation poses and nonuniform scale, and excludes other resident worlds.
Both backends bias low light directions upward to retain a ground silhouette.
OpenGL2 uses a consistent orthographic depth range and compares receiver depth
against the caster; the old occupancy-only lookup could shadow surfaces in front
of the model. The launcher selects OpenGL2 even with an older saved renderer
setting; an explicit trailing `+set cl_renderer opengl1` still takes precedence.

| Evidence | State and verified outcome | Limits |
|---|---|---|
| `aggregate.log` | Passed: 52/52 steps, 415 Zig tests, 87 Python tests and existing actual C contracts | One consolidated suite after renderer/scenario repairs; no full campaign or hardware-performance claim |
| `final-solid-opengl1/`, `final-solid-opengl2/` | Passed: default On, Off/On captures with inspected character silhouettes on floor/wall, save/load and restored rendering in both backends | Diagnostic grounded worker in e1m3b, player placement/health. Lightmap-only views separate shadow geometry from authored textures; timed lighting still advances |
| `final-solid-opengl2/pixel-evidence.json` | Shadow floor sample attenuates to 0.339 of its Off value versus 0.734 in the unshadowed control | Fixed small image regions corroborate inspection; not a whole-image or performance claim |
| `final-pickups-opengl2/` | Passed: authored armor/ammunition Off/On captures inspected; visible armor footprint and ammunition shadows on alcove rock | Controlled crouched viewpoints; not every pickup/prop |
| `launcher.json` | Passed: ordinary launch selects OpenGL2, explicit OpenGL1 argument wins | Captured actual launcher arguments with a temporary synthetic installation |
| `final-resident-opengl2/` | Passed: foreign target rendering, late model registration and Glock/Ion/Sidewinder contact through the resident aperture; view inspected | Controlled two-world setup; destination shadows remain suppressed rather than borrowing source-world maps |

Foreign portal views suppress source-world shadow maps; destination-view shadow
generation remains open. Static BSP lighting remains baked; this does not add
dynamic brush casting or a shadow for the omitted local first-person body.
OpenGL2 retains the bounded 16-map shadow budget. Transparent receivers and
fading casters, all terrain/material cases and hardware performance are not
qualified by these focused scenes.

Evidence is under `zig-out/reports/runtime-zig-313/`. Initial worker setup used
the wrong class assertion, and the first software run could not open X inside
the sandbox. A slow-timescale comparison stalled and is not acceptance. Early
captures retain the missing ground projection and incorrect shadow-depth lookup;
the final renderer scenes supersede those appearances. Full campaign acceptance
remains open.

## Sequence 312 — native-restoration-wet-ground

Build `26864935fe82571da35369cc415d47920647333b6d74d38998ad7db711cf1ca0`;
combined executable/module/asset identity
`4144b1501f1e32fe307155cc2258d8c80f5bb8e95a68d87d1b56e52442f521eb`.
Protocol 1350 and renderer ABI 12 remain unchanged. Each final report's
`identity.json` records every admitted asset hash; base/HD/region manifest remain
at sequence 311 identities. Evidence: `zig-out/reports/runtime-zig-312/`.

Loading a saved region previously consumed a frame for every preparation step
and kept its progress bar empty. Loading now processes at most 64 steps or an
8 ms scheduling budget per frame; individual engine calls retain their existing
limits. Ordinary background prefetch still yields after one step. Progress counts
actual admitted resources/worlds, and restoration still requires every saved world.
A reproduced loader crash exposed background ZIP closure freeing the engine zone
from workers. Stream finalization and CRC validation now follow the reader join on
the engine owner thread; no zone-size increase or discarded history masks the issue.

The reported robot is an authored Sludgeminion. The supplied hull has valid floor
support, but the old ground routing flags reject water areas, including walkable
shallow floors. Native AAS now allows water areas for ground walking without
adding swimming, water-jump, ladder, elevator or hazardous-liquid capabilities.
Class-owned speed, collision, damage and authored geometry remain unchanged.

| Evidence | State and verified outcome | Limits |
|---|---|---|
| `aggregate.log` | Passed: 52/52 steps, 415 Zig tests, 87 Python tests and actual C contracts, including the new background ZIP reader root | Assertions enabled; runtime root explicitly includes navigation and client admission tests |
| `read-fixed.log`, `read-defective.log` | Actual bundled minizip/shared reader passes concurrent completion, repeated polling, cancellation, size rejection and CRC failure; moving cleanup back to the worker fails the owner-thread assertion | Synthetic local ZIP, no private assets or alternate runtime |
| `wading-before-defect.json`, `robot-diagnostic/` | Expected defect reproduced: living chasing robot remains horizontally stationary across actual engine samples | Intermediate build `ff196a…` with loader diagnostics, preceding navigation repair; not product acceptance |
| `wading-final/` | Passed: untouched autosave's robot 83886443 moves 28 units during measured pursuit at supplied speed 80; actual AAS travel cost is 0 without water admission and 1377 with it | User's saved easy difficulty and inventory retained; player position unchanged during pursuit. Camera placement occurs only after acceptance. Not fresh traversal |
| `ui-autosave-input-fixed/` | Passed: real mouse selection and Load from paused/main menus, visible nonzero progress, restored input and actual death recovery in e1m2b, OpenGL2 | Untouched copied user autosave with ten resident worlds; menu loads 7.21/6.59 s, death recovery 10.61 s including death delay. Local software-renderer timings, not a performance guarantee |
| `ui-save2-opengl1/` | Passed: same menu/death sequence using untouched copied save2 in e1m3a, OpenGL1 | Twelve resident worlds; menu loads 9.66/7.60 s, death recovery 11.62 s. Both save scenarios assert retained dead actors and restored player identity/weapon |
| `ground-regression/` | Passed: authored guard navigates around occlusion, moves over 32 units and fires | Controlled last-seen goal/player placement; unaffected dry-ground regression, not campaign completion |
| `region-save-isolated/` | Passed: independently changed actor health in e1m1a/e1m1b, active world/player identity and inventory restore after explicit load and death in the other world | Controlled health/placement and resident transfer; not connected campaign traversal |

The initial console reproductions could restore the user saves but required long
admission waits. `robot-wading-isolated/` preserves the pre-cleanup-fix real zone
allocation crash. Failed UI setup runs did not exercise Load: one shared display
received another window's input, and another used relative mouse grab with an
absolute XTest driver. The corrected driver uses the existing ungrabbed UI test
mode and asserts actual pause before clicking. Concurrent display teardown also
invalidated `region-save-regression/`; engine regressions run alone afterward.
None of those failed setups counts as acceptance.

Original save files remain byte-identical; main, the preserved installation and
online service are unchanged. Full campaign, broader ground-actor/worker routes,
all weapon interactions and multiplayer qualification remain open. Earlier route
results affected by shared navigation changes still require replay.

## Sequence 311 — native-pickup-view-feedback

Build `e1e3c7fd4ac9f463c5e75d8368463f1d9038b5a68a75ae87830ac0a608f6b78a`;
combined identity `f626e617c965cccbdf342c9e92cd395c2ff6148be5d09d7a18354ea39b6ac446`.
Base, HD and region manifest remain at sequence 306 identities; protocol 1350
and renderer ABI 12 are unchanged. Evidence: `zig-out/reports/runtime-zig-311/`.

Weapon acquisition now enters its class-owned raise transition, preventing queued
old-selection input from starting another draw. Ammunition pickups preserve the
current transition. Restoration initializes the presentation incarnation once.
First-person stairs and crouch follow main's admitted 200/100 ms presentation
contract; predicted command replay cannot accumulate the same step twice.
Collision, damage and player speed are unchanged.

Armor and the reviewed rotating pickup classes use the existing angular trajectory;
ammunition and single-player world weapons retain placed orientation. Pickups sample
light above their base and request minimum light, now honored by both renderers.
Neutral texture-modulated shine replaces the blue additive veil. These lighting
changes are documented enhancements, not complete original-material equivalence.

| Evidence | State and verified outcome | Limits |
|---|---|---|
| `aggregate.log`, `runtime-approved.log` | Passed: aggregate 50/50 steps, 413 Zig and 87 Python tests plus actual C roots; affected runtime 273/273 | Assertions enabled, new roots execute. Controller fixtures explicitly begin already equipped; acquisition has its own regression |
| `pickup-defect/` | Reproduced defect on prior native `e2df24…`: ordinary contact produces two Ion ready animations | Expected-defect run, not product acceptance; combined identity `0c2bbf287f59879aa0cb4be92856e979b7e669258bcba3d6617559c922fac8b9` |
| `view-final-opengl1/`, `view-admitted-opengl2/` | Passed on final build: actual pickup contact produces one ready animation, crouch/stand include intermediate eye heights, save/load does not duplicate the ready animation. Fixed-camera armor rotation, readable alcove armor/ammo and Off/Original/Enhanced shine captures inspected | Diagnostic positioning/health, ordinary pickup contact, isolated profiles. Actual crouch and grounded alcove setup asserted. Not a fresh playthrough or every pickup class |
| `stairs-final-opengl1/` | Passed: ordinary walking climbs three authored e1m1c step rises, with negative camera offsets that decay to zero | Diagnostic placement, no jump or geometry changes; not full traversal or frame-time qualification |
| `network-final/` | Passed on final build: two real UDP clients move/fire with advancing weapon frames, respawn, spectate/rejoin, reconnect and restart | Ordinary DM inventory; commanded death. Affected shared-presentation regression, not complete multiplayer or every weapon interaction |

Failed setup runs remain invalid: early input observations preceded the final region
admission event; initial item viewpoints intersected rock, and the first stair
route was a ramp. The driver now waits for final admission and asserts walkable
placement. The first renderer correction was excluded by build flags; final
lighting captures supersede it. Existing `d1_swp3` out-of-range frame warnings are
still visible with developer diagnostics and remain a separate presentation issue.
Earlier local report directories disappeared during this session; sequence-311
evidence above was recreated. Historical journal outcomes retain their identities,
but missing artifacts are not treated as fresh native acceptance. No preserved
installation, saves, main branch or service was changed. Full-port and connected
campaign acceptance remain open.

## Sequence 310 — native-multiplayer-map-picker

Build `e2df24ee6037eda462fc9d81f3482d609e560337ff884c46f1533f1ec4e36d0b`;
combined identity `48e0b439886dd6c50e4c17efa4b5f7a45909d6d04b480b6b96d1df4039855666`.
Base, HD and region manifest remain at sequence 306 identities; protocol 1350 and
renderer ABI 12 remain unchanged. Evidence: `zig-out/reports/runtime-zig-310/`.

Internet Create and LAN hosting now share a paged map picker instead of requiring
a typed map identifier. Names, titles and mode capabilities come from the existing
local `dk3/maps.cfg`; only mounted BSPs are offered. Mouse or keyboard selection
persists in the existing room-map setting. Changing mode retains a compatible
selection or chooses the first available map. Missing/incompatible selections
cannot launch a room. Mode labels now show Deathmatch, CTF and Deathtag directly.

| Evidence | State and verified outcome | Limits |
|---|---|---|
| `build-approved.log` | Passed: 62/62 build/check steps, 270 Zig tests and actual C runtime roots; map-catalog root explicitly executes | Applicable runtime suite and native installation only; no duplicate broad suite |
| `map-picker-approved/` | Passed: actual XTest mouse and keyboard selection, paging, Escape cancellation, DM/CTF/DT filtering, selection shared by Create/LAN and a real e1dm1 LAN launch with processed player input. Captures inspected | Isolated profile, OpenGL1 software rendering. Internet Create selection is verified; no Internet room was submitted. This is UI acceptance, not broader multiplayer/campaign acceptance |

The first build could not write the compiler cache inside the sandbox. The first
engine setup could not access its virtual X display and exercised no menu. Both
failures are retained; the approved replays above completed outside that sandbox
using dkguard and temporary profiles. No private reference source/assets, preserved
installation/saves or live service were changed. Earlier gameplay evidence keeps
its recorded build identity; complete-port acceptance remains open.

## Sequence 309 — native gameplay feedback and grounded actors

Build `18681cf879b513dd84b471dd4e6b9cfe6d0c0cf9356badfa7fb353e29b4282d5`;
combined identity `a7211a68e66400d48df29e744ecf970c732b5e79b443e590a2edf4799936b0d0`.
Base, HD and region manifest remain at the identities recorded in sequence 306.
Protocol 1350, renderer ABI 12. Evidence: `zig-out/reports/runtime-zig-309/`.
Native clients and servers must use the matching protocol; the live service is
unchanged. `zig build play` selects this isolated development build with HD assets.

The actor motor no longer mistakes the 0.04 upward velocity left by floor
collision for an actual jump. Its departure rule matches the admitted slide/player
contract. Worker-specific fear consumes witnessed injury/death and existing
navigation, vocal and animation services; blocked/finished retreat stops in an
authored cower/ambient pose. Private reference behavior was inspected, without
importing implementation. Original hide-node route equivalence remains unverified.

Monitor mode 2 and ending mode 4 previously vanished in a one-bit snapshot field,
while the server correctly used the remote view for visibility. Three bits retain
all modes. Multiplayer already uses shared class-owned weapon controllers; the
repair gives presentation a spawn lifetime and consistent 16-bit shot ordering.
It does not create separate single-player/multiplayer weapon implementations.

Playable arrivals write `autosave-arrival`; periodic saves write `autosave` after
60 simulation seconds, only when Hiro and every recruited companion exceed 90%
of their own maximum health. Stopped/carried members and connected neighboring
worlds participate. Successful saves also refresh death recovery; manual slots
are untouched. Cambot lights use a small emitter, a softer beam and a contact
surface pool with range attenuation; this is an enhancement, not a shadow-mapped
spotlight or a claim of original rendering parity.

| Evidence | State and verified outcome | Setup limits |
|---|---|---|
| `aggregate-final.log` | Passed: 93/93 build/check steps, 409 Zig, 87 Python and actual C roots | Assertions enabled; explicit worker, companion-health, camera-wire and movement roots execute |
| `ground-defect.log`, `ground-defect.json` | Passed regression sensitivity: restoring the strict upward-sign rejection in a temporary copy fails the actual actor-motor test | Captured resting velocity, ordinary slide collision; no production source mutation |
| `ground/`, `crox-ready/` | Passed: actual guard pursuit around occlusion and subsequent fire; Crox swimming, restored pending melee and real contact | Ground-equivalent build `21d238…`, combined `ec768240c73d1296d224f65ff92df1227a4b204759c08f219025fa2c49fbe036`; diagnostic positioning/health, no route acceptance |
| `monitor-final-opengl1/`, `workers-final-opengl1/` | Passed on final build: ordinary button use selects the actual remote camera, releases input and restores a finished scene; witnessed worker injury/death dispatches fear vocals, settles into the stopped pose and restores fear state | Diagnostic placement/equipment. Fat worker uses ambient fallback; skinny cower frame ranges appear during the living victim's injury. No full cinematic/task parity claim |
| `lighting-final-opengl1/`, `lighting-final-opengl2/` | Passed on final build: Cambot acquisition, actual lamp submission and inspected close/wide captures | Enhanced appearance, not full renderer equivalence or independent shadow/occlusion qualification |
| `multiplayer-final/` | Passed on final build: two real UDP clients advance/interpolate attack frames before and after respawn, then spectate/rejoin/reconnect/restart | Ordinary starting weapon; this does not qualify every weapon interaction or multiplayer mode |
| `progression-final/`, `region-save-final/` | Passed on final build: ordinary movement across both authored A/B exits retains identity/input and creates a B arrival autosave; independent actor states and active world survive save/load and death recovery | Controlled approach/state changes; no fresh playthrough. `arrival-b.sav` and `.info` retain the actual boundary evidence |
| `autosaves-final-opengl1/` | Passed on final build: actual arrival save, real 60-second eligibility boundary rejects 90% health, saves at 91% and restores 91% after subsequent damage | Controlled health setup; companion maximum/ownership/stopped/carried eligibility is contract-tested, not yet exercised as a complete live party autosave scenario |

Earlier successful `monitor-input/` and `autosaves-ready/` use `6201ad…`, combined
`1d6004cdfc56d92014bb8734ab308b2f3482a0c22098f6f3931661a5cd834295`.
`workers-terminal/`, `multiplayer-input/` and initial `lighting/` use `21d238…`;
the latter's close-range pool was too bright and is superseded by reduced gain.
Failed setup runs remain: early monitor aim preceded floor settling, multiplayer
held attack through the normal respawn guard, initial world readiness timed out,
and a killed worker was correctly retired before the driver's next sample.
These invalidate those scenarios; later runs require actual input/attack, camera,
readiness, contact and save-completion evidence. Ground contract fixture failures
preceded correction of its contact-depth tolerance; final assertions and the
negative mutation both execute. Fresh intro/campaign, broad ground-class traversal,
full multiplayer modes and the complete independent port remain unaccepted.

## Sequence 308 — background PNG preparation and recoverable lookahead

Final build `d3db133f78affc07113642a685d540a4a20ef01d19144ead550a9219d82a5813`;
combined identity `940837b5c7363d6a6ea9923efba3054b3488daf6295323170b31ddc52b23c4c9`.
Base, HD and region manifest identities remain those recorded at 306; protocol
1349 and renderer ABI 12 are unchanged. Evidence: `zig-out/reports/runtime-zig-308/`.
`zig build play` installs this isolated native implementation with HD enabled.

World surface admission discovers each actual material's PNG inputs using the
existing shader definitions and backend format preferences. Independent file reads
feed pure CPU decode workers; completed pixels are consumed by the ordinary owner
thread material compiler and GPU uploader. Each material has a 128 MiB pixel bound;
cancellation joins before releasing input/output. No engine filesystem, renderer
allocation, logging or GL calls occur on decode workers. Other image formats,
generated normal maps, GPU uploads, collision decode and gameplay admission still
include synchronous work. This is not complete loader/frame-time acceptance.

Rejected lookahead no longer crashes the current world. A required failed
destination is refused before traveler ownership changes, including a pending
cut; a held source resumes its clocks and input. New saves exclude unfinished
preparations with no exposure or restored/migrated state. Already exposed or
historical worlds remain mandatory; no existing gameplay history is discarded.

| Evidence | Verified outcome | Limits |
|---|---|---|
| `async-opengl1/`, `async-opengl2/`, `admission-summary.json` | Both renderers admit A/B/C and pass actual foreign Glock/Ion/Sidewinder contacts, owned portal presentation and late resources. Each prepares 189 PNGs; measured surface peaks 8/11 ms. GL2 aperture inspected | Renderer-consolidated build `af21d5416d577bdf23d259d4fa3615cd83afa90290b41411cf1b46d3598e1216`, combined `efcc2d9468dd22191f26c800f12a33f31195ff4a880a302d2bb6d398fb38a8a1`, precedes server failure repairs. Renderer code is unchanged in final build. Controlled setup, not fresh campaign acceptance. |
| `failed-prefetch-save-boundary/` | On final build, a confirmed corrupt future PNG fails admission while current identity, connection and processed movement survive. Current save/load succeeds; a new failure is observed after restoration, entry into the failed factory region is refused, and ordinary control remains available | Temporary profile-only PNG override, recorded in `setup.json`; diagnostic placement/health. Original assets/saves untouched. |
| `region-save-final/`, `restore-final/` | On final build, both A/B actor states survive actual load and death/reload; the unchanged six-world save admits all five resident members, completes its arrival cinematic and permits normal movement/saving | Controlled/historical fixtures. No fresh traversal acceptance; simultaneous final restore runs are not used for frame-time comparison. |
| `aggregate-failure-repair.log`, `runtime-final.log`, `png-asan-final.log`, `worker-defect/` | Repair aggregate: 50/50 steps, 403 Zig and 87 Python plus actual C roots. Final save-boundary change: affected runtime suite 19/19 steps, 264 Zig and C roots. Worker/cleanup ASAN passes. Inline dispatch in a temporary source copy fails the required non-owner-thread assertion | Assertions enabled. Unaffected aggregate roots are retained rather than rerun. Tests exercise actual decoder pixels, two owners, cancellation during read/decode, prepared-cache consumption, corrupt input and budget failure. |

Failed evidence remains: `failed-prefetch/` incorrectly equated renderer/server
handles (invalid setup); `failed-prefetch-owner/` exposed the actual fatal future
admission; `failed-prefetch-recovered/` exposed a saved unfinished second map that
later failed restoration. All remain failed, superseded by the final recovery run.
The latter uses build `4f46b1…`; positive six-world `restore-opengl2/` on `af21d5…`
is superseded by `restore-final/`. No acceptance is transferred from the removed
runtime. Wider seam qualification/transforms, multiple views, navigation, residency,
remaining admission work and the fresh campaign gate are still open.

## Sequence 307 — HD PNG admission and collision forecasting

Build `99ea9654869df4e10be7ddc2eed76e49bbe91da4eaa034a255cf9ffb98293123`;
combined identity `499e7f690756d540e13b8aba24c3d6687835c6079392851c015c045773cb3028`. Base, HD and region manifest
identities are unchanged from 306. Protocol 1349 and renderer ABI 12 unchanged.
Evidence: `zig-out/reports/runtime-zig-307/`.

The actual image timings identify PNG read/decode as the dominant HD material
stall. Both renderers now use the already bundled zlib inflater once, with an
exact scanline allocation bound, retaining the existing pixel/filter/alpha
conversion. Empty IDAT chunks consume their CRC; oversized palettes are rejected.
The zlib header/checksum is now validated, a deliberate stricter malformed-input
contract. No private runtime, assets or new third-party component is admitted.

| Evidence | Verified outcome | Limits |
|---|---|---|
| `png-opengl1/`, `png-opengl2/` | Both actual renderers admit A/B/C, display an owned portal and record actual foreign Glock/Ion/Sidewinder contact; HD textures enabled | Controlled setup. Surface phase peaks 26/33 ms respectively, versus 107–111/101–107 ms in 306 final runs. Decoding/upload still occur on the owner thread; no frame-time or full asynchronous-loader claim. GL2 aperture inspected. |
| `aggregate-final.log`, `png-contract.log`, `png-defect/` | 50/50 steps, 402 Zig, 87 Python and actual C roots pass; synthetic PNG checks exercise filters, alpha, bit depths, Adam7, empty/split IDAT, malformed streams and cleanup | Initial aggregate had a missing SDL include in the new C root; fixed. The unmodified prior public decoder fails the valid empty-IDAT fixture. Assertions enabled. |
| `bridge-collision-forecast/` | Read-only forecast copies the actual spray controller and traces the existing geometry; six eventual impacts match within 0.008 units and 8–35 ms frame quantization | **Failed boss encounter** on earlier `4fd0ae…`, combined `d69b3e…`; Hiro dies with boss health 270. Forecast validity does not establish successful avoidance or campaign traversal. No gameplay damage/rule changes. |

`306/fresh-opening/` is now a failed superseded-build development route: full
intro/arrival, marsh and ordinary bridge progression reach the boss; the driver
falls into water and loses its firing lane. `305/fresh-opening-defenders/` also
fails at the boss. Neither is a fresh complete milestone. Checkpointed factory
exit evidence remains narrow. Next work removes remaining decode stalls and
uses a materially different legitimate encounter route before replaying the gate.

## Sequence 306 — incremental lightmap admission

Build `96438935d3357b5ea701fa315569de849be720e40110ca43cf2b9c0d47c87073`;
combined identity `825ee3cbe14bc71fce6672b97b9f92aaeb58bbb3a8e625c23a4a0634c783a428`.
Base assets `e7dbc2565c3c1f9ce1add690e6d713841d55d9ef740b3be85de7f4a3375df9ff`;
HD `d2e8d95bdbcb52de5529d932d8a3be378b46ac293fe2ec15849c7ac2d299c645`;
region manifest `f0cb127dcc3fa705a51cc5d9fd597960396e7bfdc3ca2cc55e709998e6a1368d`.
Protocol 1349 and renderer ABI 12 unchanged. Evidence:
`zig-out/reports/runtime-zig-306/`. `zig build play` uses this isolated installation.

Both renderers retain per-world lightmap upload progress and yield between uploads
at the existing four-millisecond work target. GL2 retains merged-page allocation
progress. Definitions, lightmaps and fog have separate admission phases; reported
phase peaks distinguish the remaining synchronous surface/texture work. GL1's
single-lightmap workaround duplicates the supplied image instead of reading past
its lump; both lightmap converters supply an explicit alpha byte for RGB pixels.

| Evidence | Verified outcome | Limits |
|---|---|---|
| `loader-final-opengl1/`, `loader-final-opengl2/` | Actual region admission, owned portal presentation/late resources and Glock/Ion/Sidewinder foreign contact pass on the consolidated build | Controlled synthetic target/equipment. Inspected GL2 aperture frame; no full reference comparison. Lightmap phases peak at 2–4 ms, but surface phases still reach 111 ms across these two runs. |
| `restore-final-opengl2/` | Immutable six-world save restores its five resident members, arrival cinematic finishes, ordinary movement and saving resume | Historical controlled fixture; includes cancelling initial preparation. No fresh traversal claim. |
| `region-save-final/`, `crossing-final/` | Actual A/B save/death restoration and retained-connection A→B→A movement pass | Controlled actors/placement/health edits and one corridor. |
| `aggregate.log`, `python-final.log`, `lightmap-defect/` | 48/48 steps, 402 Zig, original 85 Python tests and both new actual C renderer roots pass. Subsequent driver batch: 86 Python tests pass. Removing only GL1's upload yield in an isolated source copy fails the interleaving assertion | Assertions remain enabled. C roots check interleaved owner uploads/pixels, merged deluxe pairs and a guard-page-protected single-lightmap lump. No production mutation for the defect run. |
| `bridge-retreat/`, `bridge-open-bank/` | Failed legitimate-checkpoint boss encounters | Driver no longer loops at the northern obstruction; avoidance still fails to keep Hiro alive. No damage, geometry or class-rule change. Improve prediction or use a legitimate supply route before further retries. |
| `fresh-opening/` | Failed ordinary-input development replay on **superseded** `258815…`, combined `e537ba…` | Full intro/arrival and bridge progression reach the boss; driver falls into water and loses its firing lane. Cannot establish the consolidated-build fresh milestone. |
| `lan-final/` | Two real UDP clients pass movement/fire/death/respawn/spectate/rejoin/reconnect/fast restart | Existing lifecycle scope; no target-contact, full modes/bots or public-service acceptance. |

Campaign driver repairs distinguish a terminal damage event from an actor leaving
the local owner, maintain combat during health-tree climbs, observe a health pickup
and its consumption despite damage during the approach, and try one ordinary jump
at a confirmed blocked bank lip. The actual final-bank replay on unchanged `187506…`
reaches e1m2a alive with all nine arrival shots and retained identity/connection:
`runtime-zig-305/factory-bank-input/`. Checkpoint progress never transfers to a fresh
run. Full-route acceptance now separately requires all ten observed bridge wave
actors; a checkpoint encounter reports only the waves actually observed.

Earlier `loader-opengl1/`, `loader-opengl2/`, `restore-opengl2/` results belong to
`258815…` and are superseded by the final replays above. The remaining texture
admission stalls, unreviewed seams/transforms, multiple portal views, wider actor
navigation/party interactions, residency and full campaign/multiplayer remain open.

## Sequence 305 — specialized weapons across seams

Immutable build `18750658f9ccb2d67fe6f782a277dcb754fafadbeb26058e236ec474171c5c13`;
combined identity `abaccd1628f849daca0e1c96b1df01de9232dc33543e2ad466baf63dbed7ada3`.
Base assets `e7dbc2565c3c1f9ce1add690e6d713841d55d9ef740b3be85de7f4a3375df9ff`;
HD `d2e8d95bdbcb52de5529d932d8a3be378b46ac293fe2ec15849c7ac2d299c645`;
region manifest `f0cb127dcc3fa705a51cc5d9fd597960396e7bfdc3ca2cc55e709998e6a1368d`.
Evidence: `zig-out/reports/runtime-zig-305/`. Protocol 1349 and renderer ABI 12
unchanged. The native build is coherent; diagnostic setups are not campaign play.

| Evidence | Verified outcome | Setup and limits |
|---|---|---|
| `nightmare-final/` | Real attack captures the required B-owned worker, transfers the ritual into B, restores the same ritual/victim and actual body freeze, then damages/releases that victim and completes | Controlled dry grounded worker, player placement, health and equipment. The ritual processes its other acquired actors first; bounded driver wait follows the actual required victim. |
| `wyndrax-final/` | A-owned wisp acquires the B worker, saves/loads with the same controller identity, then damages the required foreign target | Real class actor and input; controlled placement/equipment. Not every fade, bounce or cancellation interaction. |
| `metamaser-final/` | Thrown cube moves A→B, reaches tracking, saves/loads the same controller and damages the B worker afterward. Original save inspection also proves the B cube damaged and retained a lock on A-owned fly 357 before saving | `saved-owners.json` retains actual physical owner, lock and Hurt receipt (source Hiro, weapon 26, damage 40), rather than inferring ownership from birth ID. Post-load fly contact is logged but its then-current physical map is not separately asserted. Not destruction-controller acceptance. |
| `zeus-final/` | Pending chain saves/loads with the same identity, then ordinary delayed strike damages the B worker | Pending phase only; not a restored expanded branch graph. |
| `trident-final/`, `ballista-final/` | Actual three-tip Trident launch contacts the B worker. Ballista contacts and reports skewer of that same real foreign actor | Dry, uncharged Trident contact; not merge/water. Ballista contact/skewer only, not carried crossing, pinning or active transport restoration. |
| `discus-final/`, `c4-final/`, `sunflare-final/`, `stavros-final/`, `shockwave-final/` | Each ordinary attack damages the required B-owned worker while Hiro remains in A | Controlled setup and actual qualified target ray/contact; no blanket return/pickup, remote chain, water, secondary blast or reference presentation claim. |
| `sentry-final/`, `spit-final/` | Real Rockgat attack and identified Froginator spit again contact Hiro across the seam | Controlled class placement; frog setup checks grounded, dry and actual attack occurrence. |
| `foreign-final-opengl1/`, `foreign-final-opengl2/` | Glock/Ion/Sidewinder qualified foreign contact, owning model registry and late resource publication replay in both renderers | Synthetic target/equipment and one aperture. |
| `region-save-final/` | Independently modified A/B actors and player state restore after real save/load and death/reload | Diagnostic placements, ownership and health edits. |
| `pursuit-final/`, `companion-final/`, `crossing-final/` | Real Slaughterskeet pursuit and Superfly follow cross B→A and restore their identities/health/authored home. Ordinary player A→B→A movement retains connection, input and identity | Controlled initial placements and class spawns; one corridor. |
| `lan-final/` | Two actual UDP clients pass movement/fire/death/respawn/spectate/rejoin/reconnect/fast restart | Existing lifecycle scope, not full modes/bots or public service acceptance. |
| `legacy-visited-final/`, `cinematic-restore-final/` | Unmodified older archives restore all 53 checked actors at installation; schema-2 migration/reload and obsolete-command rejection replay. Six-world factory cinematic restores/completes and ordinary movement/saving resumes | Historical immutable fixtures, not fresh campaign traversal. |
| `aggregate-final.log`, `python-final.log`, `c4-regression/` | 44/44 steps, 402 Zig and original 81 Python tests pass; actual C contracts execute. After the driver correction, all 82 Python tests pass. Removing neighbor detonation from a temporary source copy fails the C4 assertion (`expected 2, found 1`) | Runtime/catalog roots use ReleaseSafe assertions, other roots Debug. Production code was not modified for the defect run. The 18 affected driver contracts also pass in `driver-regressions.log`. |
| `fresh-opening/` | **Failed driver observation:** ordinary New Game reaches living normal e1m1a after intro/arrival; it stops before saving because sampled shot 69 was missed | `observation-diagnosis.json` records actual server transition evidence. Finished cursor 115 cannot replace a missing shot. This run remains failed. |
| `fresh-opening-events/` | Full intro/arrival and save/load pass; route fails at the first tree while a live mosquito blocks the jump | Driver had disabled combat on the supply climb. Game build unchanged; this remains a failed fresh run. |
| `factory-checkpoint/`, `factory-retirement-events/` | First run fails when a killed mosquito retires between observations. Corrected replay uses the tree, operates both factory controls, restores the monitor, rides both lifts and defeats the lower Crox; movement stops at the final bank lip | Legitimate checkpoint development, not fresh acceptance. The lip rises above its destination waypoint; driver repair/replay pending. |
| `marsh-defender-events/` | Both marsh health-tree climbs and retained A→B crossing complete from a legitimate checkpoint; bridge health check fails under a pursuing Crox | Actual samples show the 25-point pickup, masked by damage over the whole approach. Driver must fight the visible Crox and confirm item consumption plus the observed heal. |
| `fresh-opening-defenders/` | Fresh normal-input route reaches the bridge boss, then dies during combat | Immutable `187506…`; full intro, arrival restore, marsh supplies, ordinary A→B crossing and bridge controls traversed. Failed full milestone. |
| `bridge-defender-events/`, `bridge-local-tracking/` | First run loses local tracking of an actor near the seam; repaired run collects health/ammo and reaches the boss, then gets stuck retreating at the northern edge | Legitimate checkpoint development. Missing local actors never imply death; retain actual terminal damage or lost-target evidence. |
| `factory-bank-input/` | Actual lower-bank movement, Crox encounter, authored e1m2a exit and all nine arrival shots complete alive with retained connection/identity | Unmodified legitimate factory checkpoint on `187506…`, not fresh campaign acceptance. |

Implementation also covers Hammer radius recipients, NPC offset muzzle ownership,
Metamaser destruction controllers, class-owned liquid/visibility masks, projectile
step guards and global cancellation. Lightning hops attach to their physical
source separately from player ownership. Persistent references remap after all
foreign presentation slots exist; Metamaser laser endpoints remain coordinates.
These paths have only the contract/runtime coverage stated above.

Failed setups and superseded builds are retained. The first worker-health setup
could not address a foreign actor; read-only/controller diagnostics and the
explicit health fixture now resolve persistent identity. The next Nightmare
driver timeout expired while earlier acquired victims were being processed;
Wyndrax's post-restore driver awaited damage logging with `developer` disabled.
Both driver repairs preserve class timing, damage and acquisition. No failed
setup is counted as weapon acceptance.

Selected weapon screenshots were inspected. Developer output still reports an
invalid frame on a marsh swap model (`d1_swp3.dkm.md3`); finer presentation remains
open. No private reference implementation or original assets enter the source tree.

## Sequence 304 — actor and party ownership

Immutable build `0262fb30b698ef5ff862e23df2f37ae32fcb4adf210c3250477a99a9ac4dedef`;
combined identity `d2bb6e1d893f014c64c65bfd4f69cec75b95d97d24dade5c4186b8ba118ee710`.
Base assets `e7dbc2565c3c1f9ce1add690e6d713841d55d9ef740b3be85de7f4a3375df9ff`;
HD `d2e8d95bdbcb52de5529d932d8a3be378b46ac293fe2ec15849c7ac2d299c645`;
region manifest `f0cb127dcc3fa705a51cc5d9fd597960396e7bfdc3ca2cc55e709998e6a1368d`.
Evidence: `zig-out/reports/runtime-zig-304/`. Protocol 1349 and renderer ABI 12
are unchanged. Original saves and the installed game were not modified.

| Evidence | Verified outcome | Setup and limits |
|---|---|---|
| `sentry-final/`, `spit-final/` | A real B-owned Rockgat acquires and hits Hiro in A. A real Froginator launches an identified spit controller which contacts Hiro and deals damage across the seam. | Controlled placement, real class spawns and player health. Frog additionally uses explicit seed 1 and checked dry grounded setup. Class decisions, damage, geometry and puzzle rules unchanged; no authored encounter claim. |
| `pursuit-final/`, `companion-final/` | Slaughterskeet pursuit and normal Superfly follow input physically cross B→A, preserving identity, health, threat/party ownership and authored home. Both actually save/load with those properties retained. No connection restart during crossing. | Controlled starting positions/spawns. One corridor; not broad ground/air/swim navigation, rescue/cut scripts or full saved-controller acceptance. Initial rendered enemy/companion frames were inspected. |
| `foreign-final-opengl1/`, `foreign-final-opengl2/` | Existing confirmed foreign-target ray, ordinary Glock/Ion/Sidewinder input, damage, owning renderer and late resource definition replay. | Synthetic target/equipment, one aperture; not all specialized weapons or reference presentation. |
| `crossing-final/` | Ordinary movement through the actual A→B→A brushes retains identity, input, health and connection; save succeeds. | Controlled initial approach. |
| `region-save-synchronized/` | Modified authored actor health in both A/B worlds, hero inventory/health and identity restore after actual save/load and death/reload. | Diagnostic placements, health edits and ownership commands; not continuous campaign traversal. |
| `legacy-visited-final/` | Unmodified sequence-294 flat archives restore all 53 A/B actor identities/health before simulation; later class-owned retirement, controlled visits, schema-2 reload and obsolete-handoff rejection replay. | Original fixture untouched; not fresh traversal. |
| `cinematic-restore-final/` | Unmodified six-world fixture restores, factory cinematic completes, ordinary movement resumes and saving succeeds during preparation. | Same sequence-301 controlled fixture as 303; no fresh intro/factory progression. |
| `lan-final/` | Two real UDP clients replay movement/fire/death/respawn/spectate/rejoin/reconnect/fast restart. | Existing LAN lifecycle scope; full modes and public service remain unverified. |
| `aggregate-final.log`, `trigger-regression/` | 44/44 steps, 400 Zig and 81 Python tests pass. Runtime/catalog roots execute with ReleaseSafe assertions; other roots use Debug. Actual C contracts also execute. A temporary defective trigger comparison fails the new owner assertion. | The first aggregate had one undersized test fixture (`Capacity`); its repair and focused runtime replay are in `checks/`. Production capacity was unchanged. |

Implementation also connects class-owned ranged/melee effects, qualified radius
recipients, accepted-motion ownership through alternate step probes, attached
bursts/personal actions, typed clock restoration, cross-world use/order targets,
party exit capture and map-owned named/script/death outputs. These are
implemented/contract-tested where covered above, **not blanket engine acceptance
of every class or authored action**. Script programs remain local converted
assets, loaded by authored home; no private reference implementation is imported.

Earlier failures are retained. `spit-initial/` used a fixture that jumped and bit,
so it cannot establish spit behavior; `spit-final/` checks grounded/dry setup and
actual launch/contact. `region-save-final/` used a pre-region driver timeout before
initial admission completed. Its synchronized replay waits for the real admission
event and removes the redundant preload request; no game loading behavior was
changed for that driver. The initial three narrow passing actor cases used build
`22c438…`; final cases above replay them on `0262fb…`.

Remaining work includes specialized player weapon interactions and muzzle-origin
ownership, authored party pickup/teleport/cut coverage, broader navigation and
witness/hearing behavior, multiple/recursive views, remaining seam qualification,
resource eviction/admission stalls, fresh campaign and complete multiplayer modes.

## Sequence 303 — connected views and qualified combat

Immutable build `f9ba99b696f7ac14bf84776586b4affcee55b42b27c439690e26c30e319b6b11`;
combined identity `5f174004f53ad81db214e07b8c84591e34358b03c99e30a0600715426c20c9cd`.
Base assets `e7dbc2565c3c1f9ce1add690e6d713841d55d9ef740b3be85de7f4a3375df9ff`;
HD `d2e8d95bdbcb52de5529d932d8a3be378b46ac293fe2ec15849c7ac2d299c645`;
local region manifest `f0cb127dcc3fa705a51cc5d9fd597960396e7bfdc3ca2cc55e709998e6a1368d`.
Evidence: `zig-out/reports/runtime-zig-303/`. No fresh campaign route is claimed.

| Evidence | Outcome | Limits |
|---|---|---|
| `foreign-final-opengl1/`, `foreign-final-opengl2/` | Qualified ray confirms B-world target contact while the hero stays in A. Normal attack input from Glock, Ion and Sidewinder reduces health. Target model is submitted through its owning renderer; a newly registered episode-two model reaches B while the hero remains in A. Normal/destination-only screenshots retained. | Diagnostic placement, equipment and synthetic `runtime_target`; one aperture, no authored encounter/pursuit, fresh route or reference-presentation acceptance. |
| `crossing-final/` | Ordinary movement after controlled approach enters B and returns to A with retained identity, health, input and connection; region save succeeds. | No continuous opening campaign route. |
| `legacy-visited-boundary/` | Unmodified sequence-294 fixture restores all 17 A and 36 B actors with exact health at the actual installation boundary. Hero identity/health, controlled visits, schema-2 save/reload and obsolete-handoff rejection pass. | 36 already-dead actors subsequently retire through observed class-owned gib cleanup; their later absence is not presented as restoration loss. Fixture unchanged. |
| `cinematic-restore-final/` | Six-world saved factory arrival restores, cinematic completes, movement resumes and saving succeeds during further preparation. | Earlier controlled fixture, not full intro or fresh factory traversal. |
| `lan-final/` | Two real UDP clients exercise the complete existing lifecycle scenario on protocol 1349. | Full multiplayer modes/online service remain unverified. |
| `aggregate-final.log` | 44/44 steps, 398 Zig and 81 Python tests pass; actual C owner/collision/inline-handle checks execute. New ownership, slot leases, aperture, cycle, config/ack and party contracts execute explicitly. | Supports the narrow engine cases; it is not campaign acceptance. |

Useful earlier failure/repair evidence is preserved:

- `foreign-combat-grounded/`, build
  `9add9da80de1d5f3dfa3963db9a91d6b0a2f75aeeb86a0e7e61c0aa6b1431322`:
  a checked trace reaches the target's actual B-world slot while the player remains
  in A. Ordinary Glock, Ion and Sidewinder attack input reduces its health without
  a handoff or reconnection. No rendering claim on this build. The preceding
  `foreign-combat-initial/` setup failed while aiming during a fall and is invalid.
- `aperture-opengl2-debug/`, build
  `3cbfe91cb550c02318b1e718720904c4300f0f23d89f58b701a46308046f6f21`:
  actual GL2 crash backtrace reaches `R_DlightBmodel` through the resident portal.
  A source brush was indexed against destination surfaces. Both renderers now
  filter scene entities and polygons by checked owner before generating surfaces.
- `qualified-snapshots-opengl2/`, build
  `1e648c7718893d0ba5aea08debe9ea8ec48f2ec7179950cafcf86aec2d2ee73c`,
  combined identity `efc1aea42f1f0ce7f3ee040bce21691848b68c5ff3752a9ac2e3cfee2cb87e25`:
  the same attack diagnostic passes with the foreign target actually submitted
  through its own model registry. Normal and destination-only screenshots were
  inspected: the target is visible beyond the seam. This establishes that narrow
  view, not multiple simultaneous/recursive portal composition or actor pursuit.
- `foreign-combat-config-opengl1/` and `foreign-combat-config-opengl2/`, build
  `08d9e620a0d0a55bfa25bbddadce8b13cd9b62ba9c0883d19a1a3c7a7b2fc93d`:
  resource-publication regression fails with `InvalidSoundPath` and reliable
  command overflow respectively. Repairs preserve newer active configstrings,
  prioritize resource definitions and bound outstanding update chunks by actual
  client acknowledgements. The scenario now also demands a model newly registered
  in B while the player stays in A; the final replay above proves its delivery.

Protocol 1349 carries each entity's resource owner and persistent identity.
Foreign presentation borrows transport slots without duplicating ECS actors or
solids. Owner-scoped media, interpolation keys, transient effects and collision
queries prevent local slot/resource aliases. Ordinary multiplayer arenas retain
match boundaries. Party birth-ID rebinding and all specialized cross-world weapon,
actor/companion/navigation, multi-aperture, resource eviction and further seam work
remain separately unverified or incomplete; earlier full scenarios need revalidation.

`legacy-visited/` and `legacy-visited-lifecycle/` used observations after gameplay
resumed, so ordinary corpse removal raced the assertion and even the requested
save. The final runner requires an opt-in, read-only ECS audit before simulation,
then accepts later absence only with an actual class-owned retirement event. All
restored health is checked before that allowance. No damage, corpse lifetime or
world simulation was changed to make this probe pass.

The first aggregate passed all 398 Zig checks but caught an engine config helper
inside the pure domain layer. It now lives in the client adapter; the final suite
passes without weakening the architectural boundary check. Main, preserved game,
user saves and live service remain unchanged.

## Sequence 302 — visited migration and admission lifetime repairs

Consolidated installation `10b056cafcf909dd3114a3e6dd97bd40bfe302de30a00daffdfbf5b4595f7581`;
combined identity `93ed84bcc6e64b701b3991e8176d4111adf9a1600df61401c53f0e350bad4733`.
Base assets `e7dbc2565c3c1f9ce1add690e6d713841d55d9ef740b3be85de7f4a3375df9ff`;
HD `d2e8d95bdbcb52de5529d932d8a3be378b46ac293fe2ec15849c7ac2d299c645`;
local region manifest `af0c2eea2324fd08577c5db4a0293175424540d1b94e3b3f1babd843d8835320`.
Evidence: `zig-out/reports/runtime-zig-302/`.

| Evidence | Outcome | Limits |
|---|---|---|
| `legacy-visited-final/` | Unmodified sequence-294 save loads into C with hero 574 at health 89. A/B archives become namespaces 1/2, preserving all 53 recorded actors' health (42 dead), without stale player copies. Both maps are inspected in-engine, schema-2 save/reload succeeds, and a handoff plus load in one command batch correctly discards obsolete world commands. Original fixture hash remains `7e3a04f8e4dcb4c7eaae9ede1c41f71941a369d0109526b6288a4b76dd5dbf73`. | Controlled transfers/placement for inspection; no ordinary traversal or fresh campaign claim. Broader saved controller/party combinations remain unverified. |
| `cinematic-restore-final/` | Six-world save restores in GL2; the saved factory arrival cinematic advances through completion, normal movement resumes, and saving succeeds while the next region preloads. Final rendered frame inspected. | Immutable controlled sequence-301 fixture, hash `4d04edef2e1f2d2cbaca9a0ace7610fc48c3b72b0609e6d670fa597c91271b73`; not full intro or connected factory progression. |
| `automatic-crossing-final/` | GL1 automatic A→B→A authored touches preserve identity, health, input and connection after inline-model ownership changes. | Controlled initial approach; no portal view or cross-world combat claim. |
| `lan-final/` | Two real UDP clients pass movement/fire/death/respawn/spectator/rejoin/reconnect/fast restart with the new cgame initialization boundary. | Full multiplayer modes remain open. |
| `aggregate-final.log` | 44/44 steps, 387 Zig and 81 Python tests pass; actual C collision/owner-allocation/inline-handle contracts execute with assertions enabled. Migration roots explicitly execute. | Contracts support the narrower running scenarios above. |

Before/after evidence is retained. The additional sequence-301
`six-world-cinematic-restore/` run fails on the renderer's shared 1,024-model table.
`cinematic-restore-inline-models/` on `63d52…` passes that allocation point, then
fails on the supplied `global//e_forcefield.wav` spelling. Map-owned brush handles
and sound separator normalization repair those defects; no substitute asset or
raised global model ceiling is used. `cinematic-restore-normalized-sounds/` on
`2f4b6…` first passes complete cinematic restoration; the consolidated run above
replays it after the reliable-command repair.

`legacy-visited/` has an invalid driver timeout: root restoration completes before
required region admission releases input. The driver now waits for actual processed
input with the bounded restoration timeout. `legacy-visited-synchronized/` then
preserves and inspects both worlds but fails its second load with `WorldNotAdmitted`:
an unexecuted world-entry command belonged to the old gamestate. The final replay
explicitly queues that race and records the obsolete command's sequence before the
new gamestate boundary. Current-map readiness errors remain strict.

The full fresh opening milestone, portal clipping and qualified cross-map gameplay,
other seam geometry, party identity/transfer, residency eviction, admission stalls
and complete campaign/multiplayer acceptance remain open. Earlier broad scenarios
are historical evidence and require replay after the shared owner/restore changes.

## Sequence 301 — automatic region progression

Current installation `af499dc7237f74b162e5a6d49ea7b55758c1b2b22b2440bc5a07335833c945c9`,
combined identity `ff127b1a20c07fc3fcfdcb16b395773f8899ddcd837cb447db239dad637012e7`.
Base assets `e7dbc2565c3c1f9ce1add690e6d713841d55d9ef740b3be85de7f4a3375df9ff`;
HD SHA `d2e8d95bdbcb52de5529d932d8a3be378b46ac293fe2ec15849c7ac2d299c645`.
Local region manifest SHA `af0c2eea2324fd08577c5db4a0293175424540d1b94e3b3f1babd843d8835320`.
Evidence: `zig-out/reports/runtime-zig-301/`.

| Evidence | Outcome | Limits |
|---|---|---|
| `automatic-crossing-owned-memory/` | A→B→A authored touch handoffs retain player 341, health, command time and ordinary movement, without Server Initialization or ClientBegin. | Controlled approach placement; not continuous campaign acceptance, portal views or cross-map combat. |
| `authored-cuts-opengl2/` | Skipped intro invokes its authored exit, all seven A arrival shots complete, and the C exit reaches prefetched e1m2a. Connection retained through both cuts; six worlds save and reload. | Explicit transfer to C and placement inside its exit brush. Final restored sample is in the saved M2 arrival cinematic; full intro, factory puzzle and complete cinematic restoration are not inferred. |
| `lan-owned-memory/` | Two real UDP clients pass movement/fire/death/respawn/spectator/rejoin/reconnect/restart after allocator changes. | Full multiplayer modes remain open. |
| `six-world-restore-owned-memory/` | Actual saved e1m2a plus intro/A/B/C/e1m2b restore after cancellation of initial preparation. Every member reaches client readiness; player 433 retains health 100 and processed input; resaving succeeds. | Immutable controlled save from `authored-cuts-controlled-overlap/`, not fresh campaign evidence. |
| `aggregate-final.log` | 44/44 steps, 384 Zig tests, 81 Python tests and actual C collision/owned-memory checks pass. | Assertions enabled; all intended roots execute. |

Regression history is retained. `authored-cuts-cinematic/` on `6eb60…` exhausts
OpenGL2's fixed zone while preparing the next region. `authored-cuts-controlled-overlap/`
on `6b260…` completes both cuts and saves, then the fifth restored map exceeds the
four-reader admission limit. `six-world-restore-window/` on `efc409…` restores all
members, then navigation exhausts the fixed zone while preparing the next region.
The final replay repairs both ownership capacity defects and the admission queue.

`authored-cuts-initial/` has cinematics disabled and is invalid setup.
`authored-cuts-renderer-memory/` samples the single normal handoff frame before
arrival playback, then transfers during that cinematic: invalid setup.
`authored-cuts-synchronized/` reaches the unchanged locked factory door, which blocks
its diagnostic approach. The focused cut test explicitly places inside the supplied
exit brush; it does not qualify unlocking or traversing the door.

`geometry-candidates.json` and its recorded analysis driver retain registration
candidates for other exits, not admitted portal transforms. Prior campaign and
cross-world action scenarios need applicable replay. No fresh opening or full
campaign acceptance is inferred from these subsystem results.

## Sequence 300 — resident region save and death restoration

Verified installation `c8b457464b3fdf7d48dd3de77248314667a744a39872e5c8c970da7fbcc4d118`,
combined identity `9d91f01c0fc2fbdd98c24261c3c465c4ab3a38900416aba4f941c246718727fe`.
Base assets `e7dbc2565c3c1f9ce1add690e6d713841d55d9ef740b3be85de7f4a3375df9ff`;
HD SHA `d2e8d95bdbcb52de5529d932d8a3be378b46ac293fe2ec15849c7ac2d299c645`.
Evidence is under `zig-out/reports/runtime-zig-300/`.

| Evidence | Verified outcome | Limits |
|---|---|---|
| `region-save-active-snapshot/`, `region-save-opengl2/` | A actor 9 and B actor 16777312 have saved health 37/53. After changing both to 9/7, actual load restores both. Player 341 saves in B with health 73, dies in A, and recovers in B with health 73; returning to A retains its saved actor state. Native input resumes after client readiness. Captures inspected. | Controlled placement, health and transfer commands. Saving/reloading a region restarts the connection and asynchronously prepares its member maps before control; this is not seamless travel or continuous campaign acceptance. |
| `legacy-schema-one/` | Actual sequence-296 single-world save restores health 73 in A and can be resaved by schema 2. Original fixture remains unchanged; source hash and driver recorded. | Old flat visited archives remain readable, but their conversion into simultaneous region namespaces is still open. |
| `lan-regression/` | Two UDP clients pass movement/fire/death/respawn/spectator/rejoin/reconnect/fast restart after the snapshot admission correction. | Other modes and full campaigns remain open. |
| `aggregate.log` | 44/44 steps, 383 Zig tests, 79 Python tests and actual-engine collision contracts pass with assertions enabled. | Contract evidence supports these narrow scenarios. |

The regression detects `SnapshotWorldMismatch` on build `b26e55…` in
`region-save-opengl1/`. Native cgame previously ingested `SNAPFLAG_NOT_ACTIVE`
loading frames before ClientBegin. The fix follows the bundled engine's existing
connection contract, retains active-world validation, and the repaired runs observe
the actual inactive frames before both successful restorations.
`region-save-initial/` is invalid setup: a sloping placement enters the return trigger.
`region-save-safe-setup/` stops at the diagnostic's old `sv_cheats` restriction after
load. These results do not count as region restoration passes.

## Sequence 299 — resident client admission and player transfer

Verified installation `3647922bc510e353c08ae9c595919a33685146e3eb6dbe8607e1c35fe533c429`,
combined identity `ba5b77659ac22f9925c747c93c75521af2079ca766d12f90741ba8c3c615a114`.
Base assets `e7dbc2565c3c1f9ce1add690e6d713841d55d9ef740b3be85de7f4a3375df9ff`;
HD SHA `d2e8d95bdbcb52de5529d932d8a3be378b46ac293fe2ec15849c7ac2d299c645`.
Evidence is under `zig-out/reports/runtime-zig-299/`.

- `transfer-initial/passed.json` (OpenGL1) and `transfer-opengl2/passed.json`:
  actual checksum/media readiness precedes three transfers. Player 341 retains
  health 100, weapon/ammunition and monotonic command time. Position is copied
  without a landing teleport; gravity continues normally during observations.
  Client prediction and ordinary movement work in B, without server initialization
  or ClientBegin. Captures inspected. Controlled placement and explicit transfer
  commands make these subsystem diagnostics, not authored campaign acceptance.
- `aggregate.log`: 44/44 steps, 381 Zig tests, 79 Python tests and actual engine
  collision contracts pass with assertions enabled and all intended roots executed.
- `lan-regression/result.json`: two actual UDP clients pass movement, firing,
  death/respawn, spectator/rejoin, reconnect and fast restart on protocol 1348.
- Earlier `admission-initial/` verifies B/C/e1m2a admission on installation
  `e3a84ae8830e937d778531ca931a8d0f31d3cba4096103598a19e909176437e4`.
  It predates the wire/transfer changes and does not extend the coherent transfer
  result to all three destinations.

Protocol 1348 explicitly qualifies the active snapshot world and forbids cross-world
delta baselines. Live service is unchanged. Full campaign, remaining multiplayer modes,
restoration and effects require applicable replay after these shared changes.
Region save/restore and active encounters across boundaries remain unimplemented;
the diagnostic transfer is not exposed as ordinary travel yet.

## Sequence 298 — resident rendering and gameplay ownership

Verified installation `046e4b21e4992c3983ee9cd5a50c96bb0237341e845ead17c53a515c2d88b599`,
combined identity `06da21e56dd1705e128883060e48949ce8e14144e2333016868767568ff687e8`.
Base assets `e7dbc2565c3c1f9ce1add690e6d713841d55d9ef740b3be85de7f4a3375df9ff`;
HD SHA `d2e8d95bdbcb52de5529d932d8a3be378b46ac293fe2ec15849c7ac2d299c645`.
Evidence below is under `zig-out/reports/runtime-zig-298/`.

| Evidence | Verified outcome | Limits |
|---|---|---|
| `world-contexts-contacts/passed.json` | A retains input and save/load while B/C/e1m2a retain 518/518/455 entities. All 27/81/65 actors return actual dynamic collision contacts in their owning world; navigation queries return 6098/3961/315. Dormant actor health/position hashes survive repeated selection, A movement and A restoration. Releasing all three preserves A. | Controlled preparation, not traversal or region-save restoration. |
| `render-staged-opengl1/`, `render-staged-opengl2/` | Both neighboring static maps render with distinct inline handles; original A view restores. Captures inspected. Surface preparation yields across frames. | No portal clipping, actor transfer or frame-time acceptance. Largest steps: B 26 ms in both; C 91/101 ms. |
| `lan-regression/result.json` | Two actual UDP clients retain movement, fire, death/respawn, spectator/rejoin, reconnect and fast restart after server/AAS ownership changes. | Existing arenas; full modes remain open. |
| `presentation-opengl2/passed.json` | Real New Game, intro skip, native Marsh presentation, save/load and pause pass on the same build. | Full intro and connected campaign were not replayed. |
| `aggregate.log` | 44/44 steps, 379 Zig tests, 79 Python tests and actual-engine collision executable pass with assertions active. | Supporting contracts, not campaign acceptance. |
| `connections.json`, `seam-vertex-evidence.json` | All 84 maps inventoried; 32 authored cuts, 92 geometry-unreviewed exits. Opening corridor geometry supports identity transforms. | Four missing named landings remain; no seamless portal qualified. |

The initial `world-contexts-opengl1/` failed a navigation setup assertion: the
literal e1m2a start sample was outside an AAS area. Its replay uses z=441, inside
area 315; this changes only the diagnostic sample. Earlier `3c96d…` renderer and
`bd44be…` gameplay-context results are superseded by the consolidated identity above.
Existing full campaign results require replay after these shared ownership changes.
Ordinary exits still load maps. Player/world transfer, qualified snapshot/resource
identities, portal rendering/combat and atomic region persistence remain unimplemented.

## Sequence 297 — resident collision preparation

Verified installation:
`zig-out/native-dev/play/feeda104ab302c3a0aac69c07ccaa6bb2a4ba553e8239a88f6584600b2b348bc`.
Combined engine/modules/renderers/assets identity:
`1ee73a1054d8554a6e6b14f1d07bc838f944147761413f5bc029b5174c9b594b`.
Asset generation remains
`e7dbc2565c3c1f9ce1add690e6d713841d55d9ef740b3be85de7f4a3375df9ff`;
default HD overlay remains `d2e8d95b…645` from sequence 295.
Evidence root: `zig-out/reports/runtime-zig-297/`.

| Evidence | Exact outcome / limitations |
|---|---|
| `resident-opengl1/passed.json` | Four separately owned maps reach collision readiness while e1m1a remains active. Floor traces hit each actual destination; normal movement, save/load, release and generation reuse pass. Controlled preparation commands, not a campaign crossing. Owner-thread admission measures 7–9 ms; no frame-time guarantee. |
| `presentation-opengl2/result.json` | Existing real New Game, intro/arrival Escape, movement snapshot presentation, save/load and pause pass after the shared collision allocation change. Full intro is skipped. |
| `lan-regression/result.json` | Two real UDP clients pass movement/fire/death/respawn, spectator/rejoin, reconnect and fast restart. Existing match semantics; no connected multiplayer maps. |
| `aggregate.log` | 379 Zig tests, 78 Python tests and the standalone actual-engine collision contract executable pass; 44/44 build steps. Contract checks remain active independent of C `NDEBUG`; Zig roots use Debug/ReleaseSafe. |
| `connections.json` | Local inventory of all 84 supplied maps and 124 exits: 22 explicit authored cuts, 102 geometry-unreviewed exits, four missing named landings. No portal admitted as seamless. The initial episode-name filter omitted transition maps and was corrected before retaining this inventory. |

Ordinary exits still use the existing map-loading path. The accepted continuous
movement/cross-boundary combat plan is **incomplete**, not replaced with file-cache
warming. Collision preparation is opt-in through developer diagnostics until the
remaining owners exist; ordinary play remains available via `zig build play`.
No save schema or wire format changed in this slice. Prior connected campaign and
collision-dependent encounter results require replay on the eventual consolidated
region build; these diagnostics do not transfer that acceptance. The withdrawn
death-restoration report produced no gameplay change in this sequence.

## Sequence 296 — opening repair acceptance

Exact native installation `0c6cc7ebd055e0dcd902d2605d8c4c2389fd3642344066f1b34170282dca43b5`,
combined identity `bc98d6be01d9c0b82c99df73adf400061c264d478721e6a66844ed927cd9e2dd`.
Base manifest `e7dbc2565c3c1f9ce1add690e6d713841d55d9ef740b3be85de7f4a3375df9ff` and
HD SHA `d2e8d95bdbcb52de5529d932d8a3be378b46ac293fe2ec15849c7ac2d299c645` are unchanged.
All evidence below is under `zig-out/reports/runtime-zig-296/`.

| Outcome | Running evidence | Limits / remaining blockers |
|---|---|---|
| Ion electrical flight/light; Cambot lamp; smooth actor motion | `opening/`: real shots, rendered effects and intermediate positions inspected | Controlled placements/equipment; fine impact parity and all-class animation comparison open |
| Protopod hatches and enemy fragments render | `opening/`: actual authored pod spawns hostile skeeter; real shot kills pod and produces mechanical gibs | Close acquisition contract checked; not all actor deaths or gore presentation compared |
| Crox swims and attacks | `crox/`: observed water state, movement, pending-attack restoration and real 25.69-damage contact | Controlled position/health; not full amphibious traversal |
| Fire/jump reloads death checkpoint | `opening/`: actual deaths restore entry health 100 and manually saved health 73 after the four-second delay | Internal slot only; connected campaign death/visited-world replay still required |
| Destroyed bridge produces saved stone chunks | `bridge-camera/`: ten chunks visibly fly, then survive save/load | Diagnostic activation; connected encounter needs revalidation |
| Moving cloud/lightning shader active | `sky-repaired-driver/`: fixed camera, 12 captures, visible motion and illumination variation | Original lightning timing remains unqualified |
| Menu/cinematic/restore regression | `presentation-opengl2/`: real New Game/Escape, loading artwork, animation, save/load/pause | Intro skipped; not fresh campaign acceptance; existing `d1_swp3` invalid authored frame remains open |
| LAN regression | `lan-regression/`: two actual UDP clients, movement/fire/death/respawn/reconnect/restart | Full modes/public service acceptance still open |
| Applicable aggregate | `aggregate.log`: 379 Zig + 75 Python pass; five native roots execute 240 tests | Counts are supporting evidence only |

`82e96c…` / `presentation-initial/` is superseded and records the real incorrect
snapshot clock. `bridge/` lacks an aimed visual capture; `bridge-camera/` supplies it.
`sky/` fails driver setup before observation (missing Pillow); no product failure or
acceptance is inferred. The repaired driver uses installed ImageMagick. The full
[sequence journal](../specs/runs/RUN-dk3-independent-port.md#sequence-296--opening-gameplay-and-effects-repairs)
records implementation/reference boundaries. **The fresh opening gate is still not
accepted; earlier connected results require replay after these shared changes.**

## Sequence 295 — default HD textures

Plain `zig build play` now selects the admitted local HD image package from
the build prefix or shared `zig-out/hd-textures` cache. An explicit
`-Dhd-textures` package takes precedence. The isolated development installation
is `d9159285c80cceffca37abbe0d5ab582d260967db4964b1a780c25cdd29740dc`,
combined identity `2e0054e56e2893e26bdc08524ded2a47aa7c145bec9b413329e899dad10e4db5`.
Native code, both renderers and gameplay asset identity are byte-identical to
`a2f70c11…`; only the HD overlay and cosmetic compatibility field change.
The base asset manifest remains `e7dbc256…` below.

`runtime-zig-295/hd-default-repaired/` passes actual default-launcher admission
to e1m1a, full resolution despite saved `r_picmip 2`, and 22 renderer image
uploads matching the HD package dimensions above the original dimensions
(for example `mossrk_02`: 1024×1024 versus 256×256). The capture is inspected.
Six installer/media tests pass, including lookup precedence and unchanged
gameplay compatibility. The first `hd-default/` setup exceeds the engine's
32-startup-command limit and never loads the map; it is not acceptance.
No campaign or complete visual-parity acceptance is transferred by this check.

## Sequence 294 — presentation integration

Latest repair installation:
`a2f70c11a6a0395d5fc6041869f100394c3cf0eac41bac4b763b2f043ac0ba98`;
combined identity `af35d8e2c6c2e4a4d6d78065416b2d77d7fda48f11333adf448202bdefd1f22f`.
It passes **233** native contracts (150 runtime, 49 actor, 24 weapon, 2 inventory,
8 item). A subsequent e1m3a menu-save check exposed the laser/knight render-tag
collision; the new catalog uniqueness regression fails on that real duplicate,
then passes after assigning the knight policy its own tag.
`ui-saves-paused-fixture/` passes mouse-select-then-click Save/Load, corrupt-slot
rejection, actual health restoration and direct main-menu e1m3a load without a
Marsh detour. This uses explicit diagnostic placement, health and damage.
`ui-saves/` retains the renderer crash; `ui-saves-effect-tag-repaired/` invalidates
its setup because an actual enemy hit the player before the fixture established
its health. The final setup establishes and observes health while paused.
The changed tag affects knight attacks and unblocks actor lasers; earlier
all-class visual results remain unverified. The failed fresh opening used
one immutable `4c2502…` build below; it is not assembled from these runs.

`ui-menus/` on `4c2502…` also passes actual setting changes, binding conflict
cancel/replace and difficulty selection; its final Escape captures are not pause
acceptance, which belongs to the synchronized presentation probe. Seventeen
input-driver/evidence contracts pass. UI probes now record installation identity,
verify staged bytes and reject disabled assertions or existing evidence.

The integrated `zig build test --summary all` passes all 42 build steps,
372 Zig tests and 74 Python tests (`aggregate-passed.log`). The first aggregate
run retains a setup failure in the media-installer fixture: it mocked package
validation but omitted the completed asset manifest required at admission.
The repaired fixture provides that manifest without weakening the installer.

Consolidated installation:
`4c25028796de74cce9737556b75a39bc3292f7fdbd22c5d29103381f92f35314`.
Combined executable/modules/assets identity:
`1194391e024e485761e5da742dc7604d20433f37b8182a911a3996dcfd64690c`.
Asset manifest remains
`e7dbc2565c3c1f9ce1add690e6d713841d55d9ef740b3be85de7f4a3375df9ff`.
Evidence is under `zig-out/reports/runtime-zig-294/`.

| Player outcome | State and evidence | Limits / remaining work |
|---|---|---|
| Select normal difficulty, skip intro and arrival with real Escape, resume with 100 health/ordinary glove, save/load and pause | Passed: `presentation-final-opengl1/`, `presentation-opengl2-sky-repaired/` | Skipped intro is a focused input regression, never full campaign acceptance |
| Original button and slider artwork, supplied Marsh loading plaque and progress, smooth intermediate model poses | Rendered/captured in the same two runs; images inspected; actual differing frames and fractional blends observed | Covers New Game/sound menus and one authored animated Hiro shot. Full menu layout, all actors and audiovisual reference comparison remain open |
| Restore an active factory monitor, operate both lifts, reach the authored e1m2a exit, finish its nine arrival shots | Passed: `monitor-factory-regression/`; living final state 89 health, 13 armor, 94 Ion | Legitimate sequence-293 console checkpoint; no earlier campaign acceptance transferred |
| Open the factory gate, clear the blocked doorway, cross the yard, use health trees, restore the active monitor, ride both lifts and reach e1m2a | Passed: `factory-gate-combat/` on `4c2502…`; all nine arrival shots finish with 89 health and 95 armor | Starts from the legitimate upper-control checkpoint. Earlier slope and pipe fixes have narrow evidence in separately failed runs, not a continuous factory or fresh-campaign pass |
| New Game → full intro → marsh → bridge encounter → factory → e1m2a | Failed: `fresh-opening/` on the consolidated installation above completes the intro, bridge and visited-world round trip, then the driver fails a factory slope jump assertion | Ordinary inventory/difficulty, no grants/placement or checkpoint substitution. Alive at failure; the complete fresh milestone remains unaccepted |
| Actual LAN client lifecycle / contested CTF after shared rendering and bot changes | Passed: `lan-regression/` exercises two real UDP clients through admission/movement/fire/death/respawn/spectator/rejoin/reconnect/fast restart; `ctf-regression/` records all four bots moving, picking up weapons, firing, receiving opponent damage and respawning, plus one contested capture | Does not close natural deathtag or complete multiplayer/public-room scope |

The 232 contract results (150 runtime, 48 actor, 24 weapon, 2 inventory, 8 item)
use installation
`6bf5b349dcffd1ea4ed5dffb744021242a52886f7dfde1388672a8f549cacbac`;
combined identity
`65468105f6a50c4160aa6010704bfa5e9ff2242f62f6069ffa3c981147cd49da`.
OpenGL1 presentation and the monitor checkpoint also ran there. Comparing the
installed manifest bytes shows the final `4c2502…` changes **only**
`bin/renderer_opengl2.so`; gameplay/client/UI, OpenGL1 and assets are identical.
The final OpenGL2 replay uses the actual OpenAL backend with its null output
device; this establishes execution, not listening-based sound qualification.

Failures retained: `presentation/` queried held establishing poses before any
authored animation and is invalid setup. `presentation-authored-pose/` confirms
that the original Escape hook was compiled out and opened pause instead of
skipping. `presentation-escape-repaired/` successfully skips the intro but the
driver presses Escape during the next connection and cancels it; the synchronized
replay passes on that same build. `presentation-final-opengl2/` reproduces
`SHADER_MAX_VERTEXES hit in DrawSkySideVBO()` on entering Marsh. The repaired
renderer reuses the source-polygon buffer after computing sky-face visibility;
its identical scenario now passes. Assertions remain enabled and the added
animation, interpolation and cinematic-audio roots execute.

The fresh route's slope failure is retained. `factory-slope-walking/` clears
that slope and resupplies, then misses the raised pipe joint. The repaired
`factory-joint-waypoint/` proves supported takeoff, actual jumping and gate
operation, then stalls against Froginator 456 while combat is disabled on the
doorway approach. `factory-gate-combat/` enables the existing ordinary combat
policy there and passes from the unmodified upper-control save through e1m2a.
These corrections affect only the input driver. They do not renew the failed
fresh route or change gameplay rules.

Actor/performer/scenery/remote-player rendering changed in this sequence.
Earlier broad visual results need affected revalidation; they are not renewed
by the single interpolated Hiro sample. Supplied decoration frames can still
produce renderer warnings (for example `d1_swp3` frame 2 with two model frames).
Complete weapon/actor interactions, remaining episodes, companion routes,
multiplayer/public rooms and independent release acceptance stay open.

## Sequence 293 — checkpoint progression and unresolved bot departure

`runtime-zig-293/visited-return-driver/` passes legitimate bridge-reward
checkpoint → resupply → C→B→C visited-world restoration → factory controls/pipe/
monitor/lifts → authored e1m2a exit and all nine arrival shots. Final state:
89 health, 13 armor, 100 Ion ammo. Installation `57afcd…`, combined identity
`97ba4cb3c64e3f917322ff90f092d9a1b35efc3260ff4fe0aea1d38f6df7d9ee`;
229 contracts pass. Exact full installation IDs are in the sequence-293 journal.
This does not repeat the boss/death encounter before the checkpoint.

`lift-exit-geometry/` records real westward walking through the authored
teleporter; its requested lower-floor assertion was unsuitable, so it remains
failed. `lift-teleporter-recovery/` on `57afcd…` and
`lift-trigger-contact/` on `512eb1…` both carry the controlled bot on the lift
but still fail to select the departure passage. No natural capture is accepted.
No geometry, damage, enemy or puzzle rules were changed for driver convenience.

## Sequence 292 historical integration evidence

All runs retain the asset manifest below. `zig build play` continues to build and
launch the native development installation with separate saves.

- Water-jump installation
  `de45755964a5b0c6cc489ee4d7036c07be80b5461dd6ce787e24ab34382d2f22`
  passes 228 native contracts; combined identity
  `17b3120f52ffb5788525f65ca1d20e46eeff95249db099cb9b169e0d71235ba1`.
  `runtime-zig-292/ctf-waterjump-regression/` passes all four bots' movement,
  pickups, attack, opponent damage and respawn, plus one contested capture.
  `deathtag-waterjump/` still fails capture after carriers appear. The outbound
  path requires damaging slime as well as water-jump travel; the first read-only
  route diagnostic omitted that explicit permission and remains failed.
- Read-only route-observation installation
  `c81263026da2d17e2bfe5cbc8d7f9143f8321d05bf4b26446681c296f46bbab9`, combined
  identity `9372e4fc48deab295c802c877fdabb3108aad82f8cf6f8d4e248243881dd7596`:
  `deathtag-slime-waterjump-routes/` reaches all three destinations (90/60/1
  edges) with explicit slime permission. Supplied-graph analysis confirms no
  outbound path without both permissions. This is route feasibility, not actual
  water contact or completed traversal. `fresh-opening/` completes all 115 intro
  shots, marsh, bridge boss/all ten waves, reward contact, death/reload, the
  north-tree resupply and first factory arrival. After disk save/load and an
  authored return to the bridge, restored progress matches. The driver then
  oscillates outside its 32-unit return waypoint and times out, alive with 75
  health. **Fresh gate failed; driver failure, not game death or disconnection.**
- Scheduled-lift installation
  `08642247fd1ef54fb7b40b95260b81984f7b44053e0531583d1eb7699c8f6450`
  passes 228 native contracts. Lift centering now requires actual motion or a
  scheduled return that approaches the requested floor. The added stationary
  carrier regression rejects the former indefinite wait. `lift-departure-before/` reproduces the carrier waiting on the raised lift.
  `lift-departure-after/` selects the real lower route but still cannot depart;
  `deathtag-scheduled-lift/` remains a failed natural match. No departure/capture
  acceptance is claimed. Campaign behavior is unaffected.
- Descent-observation installation
  `da72b58b1c975b939f5118988f11654ab253d772155beaeec13e9c308176e647`
  passes 228 native contracts and its affected `ctf-lift-regression/` passes.
  Downward floor changes now seek a physical controller, preserving the vertical
  trace when standing on a mover. `lift-departure-floor-trace/` still fails:
  the controller search selects a remote prerequisite behind the same descent.
  The observed AAS waypoint lies beneath the raised platform. A locally clear
  route off its edge must be established before further natural deathtag replay.
  The intermediate `8496ea…` build was contract-tested only. Seventeen driver/
  evidence checks pass. The fresh campaign retains its unchanged `c81263…`
  installation; these later bot-only changes do not alter its gameplay.
- `factory-walking-takeoff/` fails because it jumps before reaching the raised
  pipe joint. `factory-joint-takeoff/` observes the supported joint, crosses the
  pipe, opens the gate, traverses the yard, operates/restores the monitor and
  rides both lifts, then dies to a Froginator near the lower landing. Both use
  legitimate checkpoints on `0bfdec…`, not fresh acceptance. `factory-side-tree/`
  starts from the legitimate yard checkpoint on `c81263…`, successfully uses
  authored tree 428 and rides both lifts with 58 health, then dies to Crox 160
  in the lower pool. `factory-lower-crox/` clears that Crox from the dry bank
  with actual contact, reaches the authored e1m2a exit and completes all nine
  arrival shots alive with 58 health. These are checkpoint results. No damage/
  geometry/enemy/puzzle rules were changed for these driver corrections.

## Build and asset identity

Sequence 291 separates ordinary play from controlled damage/lift diagnostics.
All installations below use asset manifest
`e7dbc2565c3c1f9ce1add690e6d713841d55d9ef740b3be85de7f4a3375df9ff`.

- Read-only damage/ground observation installation
  `2b7895321ce99ca74d8214edcf60b9655009de6ce38976c4e4d5b3247b94b60c`, combined
  identity `4e0a777ef0d07adb0f27f5d9cc08039589e073f46bfe61f48e88b07ebe5065b5`:
  `runtime-zig-291/fresh-opening/` reaches the bridge boss from New Game, normal
  inventory/difficulty and all 115 intro shots, then dies at the authored
  5000-damage barrier (source 126). Reload restores living arrival state; the
  route remains failed. `arena-damage/` defeats the boss and collects its 400 armor
  shield with **explicit 10000 health**, proving damage receipts/reward contact
  only. `bot-lift-controlled/` places one equipped bot on the lowered lift and
  verifies actual riding/objective contact. Neither diagnostic is campaign/match
  acceptance. `ctf-control-regression/` passes all four bots' movement, weapon
  pickups, attacks, opponent damage and respawns, plus one contested capture.
- Restart repair installation
  `b5cc3d6b5d59b73d8f03b34a0bef7e03efcee15b8fad3c1aa1463e1f7bf1fd10`, combined
  identity `177866301449b33451876b314a9418ad9f54a466479d1241d486babe55ce733d`:
  `lan-restart-repaired/` passes two actual UDP clients through the lifecycle
  above; rendered post-restart frames are inspected. `lan-synchronized/` retains
  the pre-repair `SV_Bot_HunkAlloc: Alloc with marks already set` crash. Earlier
  `lan-clients/`, `lan-clients-corrected/`, and `lan-lifecycle/` are driver setup,
  status parsing and reliable-command-throttle failures, respectively. LAN
  reconnect starts a new session; authenticated identity restoration is untested.
  `bridge-boundary-retreat/` starts from this fresh run's legitimate boss checkpoint,
  avoids the lethal east crossing but dies from boss spray; it is not completion.
- Bot ascent repair installation
  `0bfdec9bd5a2a4d75ff206012a608212175412050723bcfefe3a33607a4afa9d`, combined
  identity `f1ce5450bb03ed4935ea9b993a467ae685cf71aa571b40583f84fe09eb0303c9`:
  `bot-lift-approach/` reproduces oscillation below the raised lift and a later
  crushing death on `2b789…`. `bot-lift-ascent-repaired/` uses the same
  controlled gate/placement/equipment setup and verifies a real button press,
  lift travel and carried objective. No door timings or gameplay rules change.
  `ctf-ascent-regression/` passes all four participants' movement/pickups/attacks/
  opponent damage/respawns and one capture. `dm-restart-admission/` repeats real
  movement/pickups by all four bots, combat by slots 0/3 and respawn by slot 0
  after repopulating a fast restart. `dm-fast-restart/` was invalidated by the
  driver's admission counter retaining the first match's sample count.
  `deathtag-ascent-repaired/` fails capture after actual carriers appear.
  `deathtag-carrier-routes/` demonstrates no outbound route from area 6435 to
  3956 while its reverse and an adjacent control route pass. The supplied graph
  needs two water-jump edges, supported by the motor but omitted from route flags.
  `bridge-observation-batch/` uses fewer query round trips, defeats the real boss
  with ordinary checkpoint health/inventory, collects the shield and verifies
  death/reload plus C→B→C persistence. It later dies approaching the factory tree
  with four incoming health. `bridge-exit-resupply/` then uses the actual north
  bridge health tree, reaches 100 health, repeats the factory/visited-world
  transition and reaches the upper pipe with 71 health. Its failure is driver
  overshoot at a straight pipe waypoint. The safe approach region now retains
  actual height/ground assertions. `factory-pipe-approach/` passes that approach
  and the supported takeoff, then overshoots the upper landing after its jump.
  No fresh campaign result is assembled from these checkpoints.
  Consolidated checks: 228 native contracts and 17 driver/evidence checks pass.

Sequence-290 consolidated installation
`b55eef1a5de4fe3fdbb54020b83889f649264cb3b8a650690b19d9b868710e54`
uses unchanged manifest
`e7dbc2565c3c1f9ce1add690e6d713841d55d9ef740b3be85de7f4a3375df9ff`.
Its 228 native contracts and 17 driver/evidence checks pass. Immutable-run combined
identity: `f31deb83ece0f3de17e7730797d948b1fb17131af838145e90051051842c602a`.

- `runtime-zig-290/cinematic-before-{e3m4b,e3m6a,credits}/` reproduces the three
  admission failures on the preceding `c3908767…` installation. The repaired
  `cinematic-after-e3m4b/` admits the map, retains normal control and restores a
  completed save. e3m6a then completes all 16 shots of its diagnostically activated mid-cinematic and restores; credits completes both shots and restores. These pass admission/playback/control restoration, not full boss/credits presentation or campaign completion.
  Explicit map admission and diagnostic triggers are not connected traversal.
- Item projections now clear a preceding sound event's frame/flags before publishing
  a reused slot. The poison-frame contract passes; running spawned-pickup rendering
  remains to be inspected. Earlier broken-ammo frames are not accepted presentation.
- `bridge-second-pool/` clears the omitted Crox from the dry bank and reaches the boss
  through ordinary movement. It then fails a blocked firing line. `bridge-open-bank/`
  and `bridge-east-plateau-coherent/` retain distinct failed combat strategies; neither
  is a completed bridge result. `bridge-wave-defense/` reaches the authored east 5000-damage barrier because its patrol is too wide. `bridge-barrier-clearance/` defeats the boss but dies to remaining attacks before collecting its shield. `bridge-reward-resupply/` retains another combat death before the reward becomes available; no bridge completion is accepted. Further combat diagnosis needs actual damage-source evidence before another route replay. No gameplay rules were changed for these driver failures.
- `bridge-east-plateau/` is **invalid setup**: a mutable build prefix changed while
  modules were staged. Its guarded process group was terminated and all acceptance
  rejected. Campaign/match runners now default to immutable installation files,
  verify identity and copied bytes, and explicitly label mixed diagnostic modules.
  A regression reproduces replacement between hashing and staging.
- `deathtag-control-continuation/` uses a recorded Debug diagnostic combination and
  demonstrates real prerequisite/final presses on both authored control chains.
  `deathtag-lift-rider/` on `c3908767…` still fails: all four bots move, collect weapons,
  fire, receive opponent damage and respawn, but no carrier appears. Rider centering
  is contract-tested; its complete lift/objective route remains unaccepted. No further
  unchanged long match is running. CTF needs affected replay after these bot changes.

Latest bot consolidation installation
`edf131c18aecec693aaae945bb0ab7dd9983a23781867eedaf7d7fd07a2b60b3`
passes 222 native contracts. `runtime-zig-289/ctf-consolidated/` revalidates actual
pickup, movement, attack, opponent damage and respawn by all four bots, with one
contested capture. Exact combined identity:
`b9cbc6d200b60bb8f8f5beddf68e60abfca67fd33cd2cbc997e92379c67f5331`.
`deathtag-consolidated/` failed its carrier/capture requirement. The fresh campaign below retains its
original immutable `0490b…` installation and staged modules; the later changes
affect bot control and optional pickup routing, not its campaign behavior.

Sequence-289 cinematic repair installation
`0490b20023b7306d69ee4088db4e70a5dc706cf4fdd45851afd67f7c8ce5f159`
uses the unchanged asset manifest below. `runtime-zig-289/factory-arrival-repaired/`
verifies normal contact with the authored factory exit, e1m2a admission, all nine
arrival shots and release alive with incoming health/armor/ammunition. It starts
from an unmodified legitimate factory checkpoint: no fresh gate is claimed.
Exact combined identity: `31b5d79d732239f1dd02c127318a39e597c6bdd4c6bee9dcd6e5a1c85f22e2ce`.
`factory-departure/` retains the former class-admission failure and demonstrates
the platform, upper passage, controlled descent and lower route on `fa467c…`.
`factory-exit-repaired/` retains the subsequent missing-sound client failure.
The preload repair follows unique-ID binding; absent authored sound media is
reported without aborting playback, matching the reference contract.
The native contract batch passes 222 tests; the driver batch passes 16.
`fresh-opening/` is a failed full campaign replay on `0490b…`: all 115 intro shots, arrival restoration, marsh traversal and bridge resupply run, then the driver enters the second pool with Crox 425 alive. Hiro still had 135 Ion rounds before death; the death state clears the inventory. Its automatic arrival reload verifies restoration only.

Read-only deathtag diagnostics under the same sequence establish separate failures:
closed lift doors whose buttons sit behind another named door, and a dry ledge
whose escape crosses slime. The observed player water level is **zero**, correcting
the earlier inference of a submerged player. `deathtag-controls-repaired/` proves
that accepting an initially solid floor trace alone does not clear the button
approach: the final standing hull intersects the second door. Debug-module
`deathtag-control-chain/` and `deathtag-control-escape/` demonstrate movement toward
prerequisite controls and combat/respawn by all four bots; the 120-second diagnostic
still has no carrier. These are diagnostic build combinations, not mode acceptance.
The latest safe-return pickup policy is contract-tested; deathtag capture remains open.

Sequence-288 installation
`fa467c30668dee2537bd194a18c872f57c3eb7d22f6bf1408655eaf743b48344`
uses unchanged asset manifest
`e7dbc2565c3c1f9ce1add690e6d713841d55d9ef740b3be85de7f4a3375df9ff`.
Its 220 native contracts and 12 input-driver checks pass. Exact engine/module/asset
identities accompany each report under `zig-out/reports/runtime-zig-288/`.

- `visited-admission-repaired/` verifies same-map saved-resource admission, actual
  bridge surfacing, authored e1m1c arrival and C→B→C after disk save/load. Boss death,
  broken controls, remaining fruit and consumed reward persist. The later factory
  pipe driver fails while correcting a small overshoot; its legitimate takeoff
  checkpoint is replaying in `factory-pipe/`. No fresh gate is accepted.
- `portal-regression-before/` reproduces four AAS routing cycles on the old engine
  with the new read-only diagnostic module; it is deliberately a diagnostic build
  combination. Two unaffected local routes pass. `portal-regression-after/` reaches
  all six destinations on the coherent repaired build (up to 77 edges).
- `ctf/` verifies ordinary four-bot weapon pickups, actual combat/contact, deaths,
  respawns and one contested flag capture. `deathtag/` still fails: all bots collect
  weapons and move, combat/respawn occur, but no bomb carrier appears. Its remaining
  blocked corridors and an apparent submerged route required diagnosis (corrected
  above by actual water-level and collision evidence). This is not full
  multiplayer or human-network acceptance.

The prior surfacing repair (`5414bcb6…`, sequence 287) exposed reliable-command
exhaustion while restoring the visited bridge. Initial sequence-288 replay
`visited-restoration/` also failed same-map saved-resource replacement. Both failures
are retained separately; the successful replay above supersedes their repaired
restoration cases only.

Sequence 287 protocol repair installation
`807f488be71e81716955e106b77363730afe74bfd2a168f4a0e2ede6d1ea4a08`
uses the same asset manifest below. The snapshot wire now preserves native effect
tags and persistent identities; protocol 1347 rejects the incompatible older layout.
232 applicable native/codec/online contracts and 11 input-driver tests pass. The new
wire regression fails against the defective layout (`10002` becomes `18`). Evidence:
`zig-out/reports/runtime-zig-287/consolidation/`. The checkpoint bridge replay has
passed the former lightning/scorch client crash and collected health/ammunition,
cleared both ford Crox, defeated the boss and verified death/reload; it later failed
in campaign surfacing audio as described above.
Exact identity/inputs/frames: `runtime-zig-287/bridge-wire-repaired/` under the reports root.
Native effects and visual dispatch require revalidation after this shared wire repair.

The prior sequence-287 installation
`8dc7a3d6883645b84dc2b4ca8c52189b4a177ec245aedccafd4330761acf4053`
demonstrates natural four-bot DM movement, weapon collection, combat damage, kill and
respawn (`runtime-zig-287/dm/`). It does not establish complete DM or human networking.
CTF and deathtag fail their contested-capture requirements in separate directories;
deathtag does demonstrate combat/respawn. Read-only navigation diagnostics establish
that weapons and resting objectives need collector body origins, not model origins.
All eight CTF objective route lookups fail at raw positions and succeed with actual
body-bottom alignment (`runtime-zig-287/objective-navigation/`, Debug diagnostic only).
The subsequent `ctf-repaired/` and `deathtag-repaired/` replays on installation
`a501b7e9d11f623625cbe03ba3a63c668c2c393caeb86a56bc6933a8b87adfe7`
still fail natural captures. No carrier is observed. Short read-only route diagnostics
replace further unchanged long matches.

Sequence 286 launcher/save fixture uses installation
`ef7a0c105d1454316b4f6cc9793fb2dfe8be1e48143ede5aad255749ef75e04b`
and regenerated 1.3 asset manifest
`e7dbc2565c3c1f9ce1add690e6d713841d55d9ef740b3be85de7f4a3375df9ff`.
`zig build play` now rebuilds into the isolated `zig-out/native-dev` prefix and reuses
that completed local cache. The guarded launcher fixture opens native menus, admits
e1m1a, saves and restores gameplay, and exits cleanly. It disables cinematics and
selects the map explicitly: **launcher/save coverage, not campaign acceptance**.
Exact module/engine hashes, inputs and frames: `zig-out/reports/runtime-zig-286/play-final/`.
Preserved game/online installation links remain unchanged.

The coherent build and 216 native contracts pass, including map-spawn and telefrag
query regressions, chest/reveal rebasing, and save admission of non-solid world effects.
Three installer checks cover immutable generations, unchanged saves and refusal of
incomplete/corrupt inputs. Previous aggregate results for unaffected roots remain at
285 (138 other Zig tests and 64 earlier Python checks); no duplicate broad run.
Assertions are enabled. Evidence: `zig-out/reports/runtime-zig-286/consolidation/`.

First engine attempts exposed and retained two ECS query assertion failures, missing
non-solid effect save admission, and bot reliable-command overflow. These are repaired;
launcher map/save replay passes. The fresh normal New Game run observes all 115 intro
shots, saves at shots 20/50/80, restores arrival and collects/fires the Ion Blaster.
It fails at a lower marsh ledge with health 100 (`runtime-zig-286/fresh-opening-repaired/`).
Corrected normal-input routing reaches the authored e1m1b exit from a legitimate
checkpoint, then exposes the client wire defect (`runtime-zig-287/marsh-checkpoint/`).
These are distinct results across different builds, not one fresh completed playthrough.
No full connected gate is accepted.
The earlier inventory manifest `ba03d6e56c08eef76e9a79a32b2da6c223d68433293c9e4f3b2aecead0606dc3`
is superseded for new native engine scenarios.

Exact earlier verified segment identities, inputs, setup limits and superseded results
are retained in [the journal](../specs/runs/RUN-dk3-independent-port.md), including the
full historical acceptance ledger preserved at sequence 278. Evidence artifacts remain
under `zig-out/reports/runtime-zig-*/`. Controlled placement, grants and synthetic targets
remain subsystem diagnostics; none closes the continuous campaign gate.

## Revalidation and known limits

- Sequence 287 fixes the native effect snapshot field, bot/companion pickup goals and
  resting objective goals. Revalidate native effect rendering, companion item pursuit,
  multiplayer captures and the complete fresh campaign route on the consolidated build.
  Earlier effect screenshots with truncated tags cannot establish correct dispatch.
- Campaign surfacing audio no longer requires multiplayer Session. Revalidate actual
  swimming/surfacing on the consolidated build; sequence 287 verifies the repaired
  surfacing path before its separate visited-world failure. Character-specific
  multiplayer voice contracts remain covered.
- The marsh input driver now follows the lower west ledge after a fall. Engine/client
  disconnects invalidate the scenario immediately; a menu process is not a live server.
- Sequence 286 turns episode-three wooden/black chests into usable solid containers,
  with one-use opening, class rewards, delayed black-chest reveal and 25-damage trap.
  Contracts pass; authored use/reward/trap/save scenes remain unrun. Trap wood fragments
  and explosion particle presentation remain open; the supplied private `throw_debris`
  helper has no definition, so its launch motion is not claimed as qualified parity.
- Sequence 286 fixes wisp spawn and multiplayer telefrag queries, non-solid effect save
  admission and bot reliable-message acknowledgement. Intro and gameplay saves require
  replay; the repaired launcher fixture is the only completed current engine result.
  A rendered e1m1a fixture also reports out-of-range swamp-decoration animation frames;
  authored animation metadata/dispatch needs inspection.

- Shared changes require affected script/cinematic, damage, perception, companion,
  restoration/travel and multiplayer replay. Cambot now uses authored PHS; merged map
  areas remain an acoustics limitation. Earlier narrower PVS alarm evidence is superseded.
- Sequence 284 connects class-owned weapons-stay/respawn policy, actual-ammo death
  drops, player pain/death voices, saved damage blends, retained multiplayer attributes
  and credited kill rewards. Replay death, respawn, pickups, progression and restores.
- Sequence 283 adds companion injury receipt handling, grip-specific pain poses,
  retaliation and injury/death voices. Replay pain during scripts, combat and restore.
- Sequence 282 adds authored sight/frame sounds and weighted idle selection. Revalidate
  attack audio/timing, companion movement/fire poses and consumed-cue restoration.
- Sequence 281 prevents retained e1m2b editor-portal metadata from becoming a solid
  brush. Authored traversal at that location remains unrun.
- Sequence 280 adds fish/Dopefish/seagull controllers. Aquatic wandering now selects
  reachable water nodes; replay Shark/Crox wandering as well as the new fauna.
- Sequence 278 repairs the attractor query and half-square particle acceleration.
  Replay attractor linking, actor/weapon clouds, gibs, complex emitters and lightning
  sparks. Weather brushes now have no collision; verify physical traversal and visuals.
- Driver progression must synchronize connection, restoration, input processing,
  weapon readiness and save completion. Failed setup invalidates a scenario. Do not
  repeatedly replay unsuitable low-health checkpoints or change rules to assist inputs.
- Private behavior review guides contracts; it is not running reference comparison.
  Explicit compatibility corrections and finer presentation limits are recorded by
  sequence in the journal. Private implementation/assets are not public dependencies.

Debug/ReleaseSafe assertions remain enabled. `build/runtime.zig` explicitly executes
the native root and separate actor, weapon, inventory and item roots. Run one applicable
aggregate suite at the consolidated checkpoint; `make lint`, `make test` and
`zig build test` duplicate that suite. Replay affected regressions after repairs.
