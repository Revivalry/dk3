# Development status

dk3 is a development build of Daikatana for Linux x86-64. Campaign systems, the
weapon set, actor classes, companions, saves and multiplayer modes are present.
Campaign completion and broader multiplayer behavior are still being worked on.

## Supported setup

| Component | Support |
| --- | --- |
| Operating system | Linux x86-64 GNU |
| Compiler | Zig 0.16.x |
| Renderers | Vulkan 1.3, OpenGL2, OpenGL1 |
| Game data | Locally converted retail or 1.3 data |
| Multiplayer modes | Deathmatch, capture the flag, deathtag |
| Co-op multiplayer | Not supported |

## Limitations to keep in mind

- **Loading:** connected regions prepare several maps before releasing control.
  Save/load is refused while region admission is in progress.
- **Saves:** original Daikatana saves are incompatible. Converted map changes can
  also invalidate a native save. Back up the profile before changing installations.
- **Networking:** clients and servers need matching builds and content identities.
- **Rendering:** ray-traced features need compatible hardware. Character shadows
  are supported in ray queries; complete character reflected-hit shading is not.
- **Optional art:** skeletal character and HD weapon packages are separate from
  the source build and may have visual or animation limitations.

Use [Troubleshooting](../how-to/troubleshoot.md) for common failures. Report other
reproducible problems through the [issue tracker](https://github.com/dmytrogajewski/dk3/issues).

## Development records

The repository keeps the [detailed state assessment](https://github.com/dmytrogajewski/dk3/blob/main/docs/status.md),
[scenario records](https://github.com/dmytrogajewski/dk3/blob/main/docs/native-acceptance.md)
and [roadmap](https://github.com/dmytrogajewski/dk3/blob/main/docs/rewrite-roadmap.md)
for contributors following implementation work.
