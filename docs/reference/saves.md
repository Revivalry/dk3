# Save format

Native gameplay snapshots use schema **2**, with schema-1 migration. They are
stored inside a version-**1** portable record stream. These numbers are separate
from the network protocol.

## File header

All numeric header fields are little-endian.

| Offset | Width | Meaning |
| --- | --- | --- |
| 0 | 8 bytes | `DK3SAVE\0` signature |
| 8 | uint32 | Codec version, `1` |
| 12 | uint32 | Total stream length |
| 16 | uint32 | Record count |
| 20 | uint32 | CRC32 of bytes after the header |

The header occupies 24 bytes. Each record contains its length, numeric ID, field
count and name. Each field contains a name, kind, element count and data.

Integer and float elements occupy 32 bits. Text and opaque bytes have explicit
lengths. Field names contain bounded lowercase letters, digits and underscores.

## Gameplay records

The campaign record stores the map, skill, native schema and JSON header state.
Entity records store persistent IDs and named component values as JSON in byte
fields. Header state includes simulation time, ID allocation, episode, namespace,
map checksum, resources, pending actions and journey state.

A campaign save can contain active, resident and visited worlds. World namespaces
and persistent IDs identify objects; engine slots and renderer handles do not.

On load, records decode into a separate world. References, resource bindings and map
checksums are validated before that world replaces the active state. Timers are
rebased from the saved simulation clock to the restored clock.

## Rejected input

The reader rejects invalid signatures, unsupported codec versions, truncated or
trailing bytes, checksum failures, duplicate fields, invalid kinds/counts, embedded
text NULs and non-finite float fields. Gameplay validation also checks the snapshot
schema and object relationships.

Original Daikatana saves cannot be loaded. A dk3 save can also become incompatible
after its converted map geometry changes.

## Slots and recovery copies

```text
save quick
load quick
load quick previous
```

Slots use lowercase letters, digits, underscores and hyphens. The engine writes
staged files and maintains a previous recovery copy. The game reserves internal
checkpoint/travel slots.

The default save directory is `zig-out/native-dev/play/state/dk3/saves/`.
Menu metadata and preview pictures are stored separately from the snapshot data.
See [Files and directories](paths.md).
