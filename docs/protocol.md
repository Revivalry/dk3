# Protocol and native interfaces

**Current wire protocol: 1351.** The authoritative declarations are
`engine/ioquake3/code/qcommon/qcommon.h` and `src/online/api.zig`. Clients, dedicated
servers and native modules need matching compatibility identities. Stock Quake III,
older dk3 protocols and incompatible demos cannot be treated as matching peers.

## Distinct versioned boundaries

| Boundary | Current identity | Definition |
| --- | --- | --- |
| Client/server wire | 1351 | Engine `qcommon.h`; online `api.zig` |
| Renderer exports | 13 | `engine/ioquake3/code/renderercommon/tr_public.h` |
| Online control API | 1 | `src/online/api.zig` |
| Native gameplay save schema | 2 | `src/mechanics/domain/snapshot.zig` |
| Portable save codec | 1 | `src/core/domain/save_stream.zig` |

These identities describe different contracts. In particular, compatibility labels
produced by `build/compatibility.zig` do not replace the native save schema declaration.
[Save format](save-format.md) documents persistent records.

## Snapshot and message ownership

The Zig network layer owns bounded message fields, channel state and packet security.
The engine projects native authoritative state into transport structs; it never sends
ECS chunks, pointers or native structure padding. `src/network_engine.zig` connects
engine calls to the Zig message codec. Reviewed upstream Huffman compression remains
C. The upstream C message codec is retained for differential tests rather than as a
second active wire implementation.

Entity/player field schemas state their widths explicitly. Local ABI offsets locate
fields for encoding, not memory blocks to serialize. The component suite checks
bounds, signed timers, extensions, command changes and truncated input against the
licensed reference. `zig build test-codec` runs the focused codec comparison.

The extended engine supports 512 model bindings, 1,024 sound bindings, 4,096
configstrings and 128 KiB of configstring text. Model indices, event parameters,
region identities and native effects extend the stock protocol. Matching native
modules are required. Source changes affecting these contracts must update both
sides and the compatibility identity, with rejection paths tested.

## Native engine services

Game, client and UI modules are native Zig shared libraries loaded through ioquake3's
module boundary. `src/engine` owns imported engine types and gateways. Gameplay
objects remain ECS state; engine entities/player states are projections.

The renderer export boundary includes resident-world handles and native model/bone,
fog, weather and capture services. Renderer handles, network world identities and
persistent save namespaces have separate lifetimes and cannot be substituted for
each other. See [architecture](engine.md) and [resident worlds](seamless-worlds.md).

Storage services move bounded buffers between the game and private engine filesystem.
The engine supplies durability/slot operations; the game validates snapshot records,
resource bindings, map checksums and references. Original saves and asset packages
are not accepted as native executable state.

## Managed-room packet protection

The online API separates coordinator allocation/admission from game datagrams.
Workers advertise compatible builds/maps and launch isolated dedicated servers.
Guest challenges and signed identities authorize room admission; tickets provide
separate directional ChaCha20-Poly1305 keys.

Protected datagrams authenticate channel metadata and a monotonic nonce counter
before changing replay, fragment or peer-mapping state. The security implementation
admits bounded reordering and rejects replay/tampering. Offline local channels are
a separate admission path. A reported content/rules hash is a compatibility claim,
not trusted client or anti-cheat attestation.

See [online architecture](multiplayer-zig.md) for room lifecycle, compatibility,
worker reconciliation and outage behavior. Historical operator records describe
specific earlier deployments and do not establish current public availability.

## Verification scope

Codec/security unit and differential tests pass in component CI. Historical focused
runs cover separate-process connection, snapshots, respawn, reconnect and some
managed-room lifecycle failures. The complete current native Internet/mode/map,
team/objective, error and disconnect matrix remains open. Check [current state](status.md)
and [native acceptance](native-acceptance.md) before treating an older protocol run as
current acceptance.
