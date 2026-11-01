# libdeflate 1.26 admission

Pinned upstream: https://github.com/ebiggers/libdeflate/tree/v1.26
Archive: https://codeload.github.com/ebiggers/libdeflate/tar.gz/refs/tags/v1.26
Archive SHA-256: `bba03fffc5538576213675ce6968fcff6ce2e67d82e4d5febea2d05f9f13cf85`.
All 21 copied upstream files are unmodified. COPYING and individual source notices
retain the MIT terms. Per-file hashes and experiment evidence are recorded under
`zig-out/reports/perf-inflate-465/`. This review file is dk3 documentation.

Scope: PNG's bounded, contiguous full-buffer zlib decompression. No compressors,
gzip, CRC implementation, programs, build scripts or tests are admitted. The six
C translation units match upstream's decompression/zlib CMake selection (utils,
raw decoder, zlib wrapper, Adler and x86/ARM CPU feature detection); required
generic and architecture headers are retained. The existing bundled streaming
zlib remains the ZIP reader and independent contract reference.

Reviewed public API, zlib header/footer validation, exact consumed/written lengths,
decompressor allocation/free, bounded decode template and architecture dispatch.
Each PNG call owns its decompressor; no allocator customization/global mutation
is performed by dk3. Upstream documents separate decompressors for concurrent
threads. CPU implementations select supported instructions, including OS feature
checks. Build flags hide internal symbols; there is no system library dependency.
Only the engine codec uses this C component; game/client/UI remain Zig 0.16.
Zig 0.16 rejects upstream's 512-bit Adler target attributes with generic x86
(`evex512` missing). The build uses the upstream opt-out macro
`LIBDEFLATE_ASSEMBLER_DOES_NOT_SUPPORT_AVX512VNNI`, retaining AVX2/SSE2;
no vendor source is changed. COPYING installs under `share/licenses/dk3/`.

The caller retains its exact PNG filtered-size/output limit and input/chunk checks,
requires full consumption and exact output, and rejects checksum/header/capacity
errors without a fallback decoder. Worker input ownership/cancellation and image
registration order remain unchanged. Full build passes 86/86; the shared aggregate
passes 405 tests plus C contracts. Valid-PNG-CRC malformed streams reach zlib
header/footer, bounds, truncation and trailing-input rejection. An independent
fixed match stream verifies output CRC, unaligned guards and insufficient space.
Seven paired actual loader trials retain pixel CRCs with lower CPU time. Nine
four-fixture headless runs pass ordinary validation, complete image admission and
copied-save restoration across cache/default/archive/backend qualifications and
paired comparison. See acceptance sequence 465 for variation and scope; physical
GPU, Windows execution and cold storage remain unverified.
