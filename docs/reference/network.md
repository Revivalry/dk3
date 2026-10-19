# Network and multiplayer reference

dk3 clients, dedicated servers and native modules must use matching builds.
The wire protocol is **1351**, the renderer export ABI is **13**, and the online
control API is version **1**. These interfaces have separate version numbers.

## Game modes

| Mode | `g_gametype` | Rules |
| --- | --- | --- |
| Deathmatch | `0` | Individual frag scoring |
| Capture the flag | `4` | Capture the opposing flag while your home flag is at base |
| Deathtag | `8` | Carry your team's backpack through its switch/door course to the capture zone |

In CTF, touching a dropped home flag returns it. An abandoned dropped flag returns
after 30 seconds. Death and disconnect drop a carried objective.

In deathtag, backpack pickup starts a 90-second fuse. Reaching the matching capture
zone awards its points and places the bomb with at most five seconds remaining.
An opponent touching a dropped bomb detonates it. Detonation damages players within
400 units, and the backpack returns after ten seconds. Carrying the backpack
protects against falling, drowning, lava and slime.

## Local servers and Internet rooms

LAN clients connect directly to a server address. Managed Internet rooms use an
HTTPS coordinator, approved worker hosts and separate dedicated-server processes.
The coordinator stores room state in SQLite and provides allocation and admission.
It is a service deployment, not a peer-hosting or relay feature.

Guest identity challenges and room tickets establish directional
ChaCha20-Poly1305 packet keys. Datagram authentication precedes replay, fragment
and peer-mapping updates. Compatibility hashes identify matching rules and data;
they do not attest that a client is unmodified.

## Wire representation

The Zig message codec encodes explicit entity/player fields rather than sending
native memory. Upstream Huffman compression is used by the engine. Snapshot state
is a projection of gameplay objects and does not contain ECS chunks or pointers.

| Resource | Limit |
| --- | --- |
| Model bindings | 512 |
| Sound bindings | 1,024 |
| Configstrings | 4,096 |
| Configstring text | 128 KiB |

Stock Quake III clients and incompatible dk3 protocols cannot join as matching peers.
See [Host or join a multiplayer game](../how-to/host-multiplayer.md) for commands.
