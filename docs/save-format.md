# Native save format

The current native gameplay snapshot schema is **2**, declared in
`src/mechanics/domain/snapshot.zig`. It admits schema-1 migration. This is independent
of the portable record codec, which is version **1**, and of network protocol 1351.
The old runtime's gameplay schema 5 is not the current snapshot format.

Original Daikatana saves are not imported. Development-save compatibility is checked
against the supported schema, map identities and references; arbitrary old saves
are not guaranteed to load. Preserve existing saves before changing installations.
See [current acceptance](status.md).

## Portable record stream

`src/core/domain/save_stream.zig` implements a bounded little-endian named-record codec.
No native structure memory, pointers, archetype rows, callbacks or executable instructions
are serialized.

| Header offset | Width | Meaning |
| --- | --- | --- |
| 0 | 8 bytes | `DK3SAVE\0` signature |
| 8 | uint32 | Codec version, currently 1 |
| 12 | uint32 | Total stream length |
| 16 | uint32 | Record count |
| 20 | uint32 | CRC32 of bytes after the header |

The header is 24 bytes. Each record has a byte length, stable numeric ID, field count
and bounded name. Fields have a name, kind, count and data. Integer and float fields
use 32-bit elements; text and opaque bytes use explicit byte lengths. Names use bounded
lowercase ASCII letters, digits and underscores.

Readers reject malformed/truncated/trailing data, incompatible codec versions,
checksum failures, duplicate fields, invalid types/counts, embedded text NULs and
non-finite float fields. Codec-level limits and gameplay-level limits are separate.
Validation requires consuming every record and field.

## Gameplay schema 2

The campaign record contains the map, skill, `native_schema` and JSON header state.
Entity records preserve persistent IDs and named component values as typed JSON
inside opaque byte fields. They are data descriptions, not executable instructions.
The header carries simulation time, the next/player IDs, episode, optional namespace,
map checksum, resource bindings, pending target actions and journey state.

Campaign snapshots can contain visited-world archives and resident-region members.
Loaded state owns an isolated ECS world and arena until admission succeeds. Resource
and persistent-reference validation happens before live-world replacement. Explicit
namespaces distinguish region owners; engine entity slots and renderer handles are
not persistent identity.

`Loaded.rebase` computes the difference between saved and restored simulation clocks,
rebases component timers and pending target deadlines, and checks resulting bounds.
Class-owned state participates through the snapshot contracts rather than pointers.
See the [runtime class contract](runtime-zig.md#class-contract) and
[resident worlds](seamless-worlds.md).

## Storage and recovery

The engine storage ABI transports bounded bytes; native game code owns their schema.
Slots are validated names beneath the private home-state game directory. Writes use
staging and current/previous recovery paths. Loads validate and stage the destination
before replacing active state. Map checksums prevent applying state to incompatible
converted geometry.

```text
save quick
load quick
load quick previous
```

Settings and saves for the default native installation live separately:

```text
zig-out/native-dev/play/home/
zig-out/native-dev/play/state/dk3/saves/
```

Menu saves include sidecar metadata and preview pictures. Their presentation is a
separate contract from snapshot validity. Internal travel/checkpoint files belong to
the runtime, not to an asset package. Immutable scripts come from the admitted asset
generation rather than executable save content.

## Acceptance limits

Focused scenarios cover mover/weapon restoration, visited/resident worlds, staged
admission, copied development saves and corruption/recovery. Whole-campaign party,
cinematic, cross-episode and mid-action coverage remains open. Earlier schema-5 and
pre-native test evidence remains historical. See [status](status.md) and the
[native acceptance ledger](native-acceptance.md) for the scope of each result.
