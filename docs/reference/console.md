# Console commands

Commands below are entered in the engine console. To pass a command at launch,
place it after `--` and prefix its name with `+`.

```sh
zig build play -- +set cl_renderer opengl2 +map e1m1a
```

`set` assigns a console variable. Settings marked latched take effect after the
relevant restart, such as `vid_restart` for renderer settings.

## Game and persistence

| Command | Meaning |
| --- | --- |
| `map <name>` | Load a converted map |
| `map_restart 0` | Restart the current map |
| `save <slot>` | Save to a named native slot |
| `load <slot>` | Load the current copy of a slot |
| `load <slot> previous` | Load the previous recovery copy |
| `weapon <id>` | Select a weapon by its registered ID |
| `viewpos` | Print the current view position and angles |
| `dk3_look <yaw> <pitch>` | Set the view orientation used by the next normal input command |
| `quit` | Exit the engine |

Slot names use lowercase letters, digits, underscores and hyphens. See
[Save format](saves.md) for storage and compatibility.

## Graphics and capture

| Command or variable | Meaning |
| --- | --- |
| `cl_renderer vulkan` | Select Vulkan |
| `cl_renderer opengl2` | Select OpenGL2 |
| `cl_renderer opengl1` | Select OpenGL1 |
| `vid_restart` | Restart the renderer |
| `screenshotJPEG <name>` | Write a JPEG capture to the game's screenshot directory |

[Renderer settings](rendering.md) lists resolution, upscaling and lighting variables.

## Multiplayer

| Command or variable | Meaning |
| --- | --- |
| `connect <address[:port]>` | Connect to a server |
| `disconnect` | Leave the current server |
| `g_gametype 0` | Deathmatch |
| `g_gametype 4` | Capture the flag |
| `g_gametype 8` | Deathtag |
| `team red`, `team blue`, `team spectator` | Select a team or spectate |
| `addbot` | Add a bot |
| `bot_minplayers` | Minimum player population maintained with bots |
| `dk3_bot_skill` | Bot skill, from 1 through 10 |
| `bot_pause` | Pause bot commands |
| `fraglimit`, `capturelimit`, `timelimit` | Match limits |

Set the game type before loading the map. See [Host or join a game](../how-to/host-multiplayer.md).

## Runtime workers

`dk3_jobs` selects the runtime worker count, from 0 through 8. The default is one
less than the available CPU count, capped at eight; `0` runs jobs inline. This is
a latched setting.

Commands beginning `dk3_runtime_` are developer diagnostics. Some change world,
player or actor state and are intended for controlled fixtures rather than normal play.
