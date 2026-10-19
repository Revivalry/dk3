# Host or join a multiplayer game

Each player needs converted game data and a matching dk3 build. The available
modes are deathmatch, capture the flag and deathtag.

## Host from the menu

1. Open **Multiplayer** and choose the host flow.
2. Select a game mode and a map listed for that mode.
3. Set the player slots, bot population and bot skill.
4. Start the game.

Use a LAN game for local hosting. Internet rooms use the coordinator/worker service;
they require a configured service endpoint and are not peer-hosted games.

## Join a server

Open the join flow and enter the server address. A non-default UDP port can be
included as `address:port`.

You can also connect from the console:

```text
connect 192.168.1.10:27960
```

Replace the example address with your server's address. An incompatible build
produces a connection error; install matching client and server builds before retrying.

## Set up an objective game from the console

On a local host, select the mode before loading its map:

```text
g_gametype 4
map e1ctf1
```

Use `g_gametype 0` for deathmatch or `8` for deathtag. `e1dt1` is a deathtag map.

Players join teams with `team red`, `team blue` or `team spectator`. Use `addbot`
to add a bot. `bot_minplayers` maintains the minimum population, and
`dk3_bot_skill` selects a skill from 1 through 10.

## Set match limits

- `fraglimit` sets the deathmatch score limit.
- `capturelimit` sets the capture limit.
- `timelimit` sets the match duration in minutes.

See [Network and multiplayer reference](../reference/network.md) for mode rules and
the difference between LAN servers and managed Internet rooms.
