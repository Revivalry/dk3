# Loading and rendering architecture

Owner-approved scope: all six directions from the 2 November performance proposal.
Development continues in the isolated performance checkout; the playable installation,
original assets and owner saves remain untouched. No publication is part of this pass.

| Direction | Connected implementation | Acceptance |
|---|---|---|
| Bounded parallel loading | Persistent bounded pools, immutable inputs, owner-thread publication and drained cancellation | Contract and native scenarios passed; final aggregate plus affected renderer repair passed |
| GPU-ready packages | Source/settings-bound RGBA8 mip chains, geometry and HDR pages; additive local package generation | Conversion/installer/pixel/geometry contracts and native admission passed |
| On-demand restoration | UI validates complete graph; restore current region and retain original dormant snapshots | Greece: 3 decoded worlds, 29 cold; save/load and controlled crossing passed |
| GPU preparation/uploads | Integer mip/color compute, bounded frame scratch and deferred uploads with CPU fallback | 40 exact output cases on software and physical Vulkan; native software admission/restart passed |
| Bulk save reconstruction | Plan component masks, populate final columns, preserve identities/query order; copied validation handoff | ECS/codec/malformed/canonical contracts passed; full handoff component gain measured |
| GPU-driven rendering | GPU surface culling, stable index compaction and indirect submission after CPU PVS/material sorting | 14 exact output cases on both Vulkan devices; native software scenarios passed; hardware FPS unverified |

Implement connected mechanisms before systematic scenarios. Gregg's scientific method,
USE and workload/observer characterization guide experiments. Measure completed world
readiness, transitions, CPU and frame time, peak RSS/VRAM and cancellation cleanup.
Preserve every failed experiment. A component gain is not an end-to-end gain.
Software headless timings establish no physical-GPU speedup. Hardware-only acceptance
remains separate and must not interfere with the desktop.

Baseline: published sequence 563, commit 65415bb. The six directions are not accepted
merely because supporting code exists; record implemented versus verified separately.
The class-owned Greece exit retry repair from sequence 507 is integrated. It retains
the authored party radius, summons the required companions and retries sustained
contact after a refusal. A refused attempt no longer permanently latches the exit.
Old saves already carrying the defective latch require leaving and re-entering
the brush; that state cannot safely be distinguished from arrival protection.

## Ownership and bounds

`core/ecs/jobs.zig` publishes one owner-owned batch and drains all jobs before
returning an indexed error. Snapshot decoding uses at most four independent worlds
per batch, private allocators and deterministic publication. No gameplay/class
adapter or engine callback runs on these workers. Renderer world preparation uses
two workers; captured geometry settings and pinned input views remain valid until
the owner drains cancellation. GPU object creation/publication stays on the owner.

Texture preparation uses four persistent workers and batches at most four images
and 64 MiB of source pixels, admitting one oversized image alone. Deferred source
and cache reads have explicit input budgets (64/96 MiB, at most two pairs and a
320 MiB encoded-input ceiling). Existing upload budgets remain eight images or
4 MiB plus one oversized item. Failed/stale sidecars fall back to the source PNG.
Restart/shutdown drains workers before releasing their streams and memory.
Deferred chains up to 2 MiB keep the existing background PNG/small-skin admission
path. Metadata-only cache length checks avoid serializing cheap skins behind the
two large-cache read slots. Synchronous registration can use valid caches of any
size. The first all-sizes-deferred-cache experiment regressed complete loading and
is retained in the evidence; it is superseded by this measured routing repair.

GPU texture scratch is lazy, capped at 96 MiB per in-flight frame (three frames;
allocation blocks may round upward). It resets only after timeline reuse. The
full uncolored mip chain is built before applying the existing color tables;
odd/thin dimensions and alpha match CPU integer truncation. Exhausted scratch or
unsupported inputs use the CPU path. No original texture resolution is reduced.

GPU world drawing retains CPU PVS/BSP traversal and material ordering. Each
eligible batch has at most 256 surfaces, compacts indices in deterministic order
and writes one indirect command. Portals, shadows and unsupported/oversized batches
keep their existing CPU path. Static GPU index storage is lazy when enabled.

## Save compatibility and cache trust

Durable saves remain schema 2, with schema 1 migration unchanged. UI loading runs
the same pure class and cross-world validators as the server. A volatile prepared
stream uses compact typed values with no padding or pointers; its schema 4 and
runtime rules identity are independent of the durable format. Exact-size planning
avoids touching a 64 MiB temporary for each load. The engine owns one bounded byte
copy; UI/server module pointers and allocator ownership never cross the DLL ABI.

The server checks the original source SHA-256 and runtime identity before reusing
that validation. Selected-region decode then rebinds cold worlds to their exact
original durable bytes. Cold snapshots remain dormant until needed and can be
saved without reconstructing them. Console/disk loads and every cache miss retain
full validation. Runtime-qualified SHA/AVX2 is isolated in a separate stdlib object;
the baseline caller checks CPU and OS vector support and retains portable SHA.

## Preparing optional local assets

Build the converter with `zig build prepare-world-assets`. Generate a new additive
cache directory from the actual source package precedence:

```sh
python3 dkq3/tools/prepare_gpu_assets.py \
  --input /path/to/base.pk3 --input /path/to/overrides.pk3 \
  --output-directory /path/to/new-gpu-cache --workers 4 \
  --world-baker zig-out/native-dev/bin/prepare-world-assets \
  --overbright 2 --subdivisions 4
```

Packages are ZIP_STORED shards capped at 1 GiB. The final generation manifest pins
every package. Installer admission checks complete payload CRCs, sizes, hashes and
the cache-only namespace; no module or authored asset override is permitted.
`zig build play-install -Dprepared-gpu=/path/to/new-gpu-cache` selects them for an
explicit installation. This development pass does not refresh the owner's install.

`r_vkPreparedAssets` defaults to 1 and transparently falls back when packages are
absent or stale. By owner direction in sequence 568, `r_vkGpuTexturePrep` and
`r_vkGpuWorldDraws` also default to 1. Setting either to 0 retains the CPU path.
Correctness on the physical GPU is demonstrated with a
standalone offscreen harness. No physical-GPU engine/FPS improvement is claimed.

## Measurements

Sequence 567 evidence is in `zig-out/reports/perf-pipeline-567/`. Three interleaved
CPU trials, each with one warmup and five samples, used the same four fast physical
cores and SMT siblings. On the immutable Greece B/A saves, complete prepared
handoff wall medians are 120.126/125.824 ms versus 157.555/168.338 ms for two full
decodes (23.8%/25.3%). This includes UI decode, encoding, exact scratch allocation,
two source hashes, two cache byte copies, selected decode and original-byte rebinding.
It excludes dormant-store publication, rendering and asset admission.

The initial handoff implementation took 173.264/179.400 ms even though its scratch
allocation was outside the timer. It is superseded, not reported as a gain. Peak
component-process RSS falls from 131780/131280 to 69128/67864 KiB. That comparison
is against the first handoff, not the smaller two-decode control. Full decode stays
approximately flat; canonical output hashes remain identical to the original saves.
Fresh-engine results use three interleaved trials per arm, fresh settled-menu
processes, private empty Mesa caches and four software-driver threads. With
prepared packages, B/A readiness is 4.177/4.129 s versus published 4.129/4.578 s:
B is approximately flat (+1.2%); A improves 9.8%. Process CPU decreases
14.0%/24.7% and peak RSS decreases 7.9%/8.3%. Without packages, readiness is
4.026/4.528 s; these smaller differences overlap observed variation. The four
prepared shards cost 1.446 GB versus 434.5 MB for the source fixture package.
These are software/headless current-map results, not physical-GPU FPS or all
future-region readiness. Samples, ranges and final verification are in the
acceptance ledger.
