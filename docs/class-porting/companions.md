# Companions (Superfly and Mikiko) — review sheet

The reference files are `dlls/world/Sidekick.cpp`, `Sidekick.h`, `items.cpp` (item permission) and `client.cpp` (carrying across levels). Provenance only.

The native code is `src/classes/actors/companions/` (brain, navigation, items, damage, triggers, pose) driven by the shared bot pilot (`mechanics/server/bot_pilot.zig`); the design is in [bots-zig](../bots-zig.md) and [coop-bot](../coop-bot.md).

| Section | Reference behaviour | Native status |
|---|---|---|
| Identity | Superfly, Mikiko and Superfly carrying Mikiko; single player only, one of each; carried across levels with health, armour and inventory | Implemented |
| Health | The aidata row over the class's 100, skill-scaled: retail Superfly 150, Mikiko 100; the 1.3 profile's rows give 5000 (Superfly carrying Mikiko 10000) | Implemented (sequence 413: was a fixed 100) |
| Talk nodes | Reaching one of its talk nodes (117 across the episodes) with its owner within 800 and in sight, a sidekick says the node's line once a level; full volume within 512 of the owner, fading to a tenth by 1500; Superfly then keeps quiet 1 s, Mikiko 5 s | Implemented (sequence 414: "reaching" is within 128, as native sidekicks route by area) |
| Items | Every authored item is off-limits to both until its spawnflags admit Superfly (1) or Mikiko (2); an ordered pickup ignores that; items that appear later are never sought; needs: health under 95%, better armour, episode weapons and their ammunition | Implemented (sequence 413: the permission was inverted) |
| Orders | Follow, stay, attack the looked-at monster; a hit while staying returns it to following (and fighting) | Implemented (sequence 413: a hit ends stay) |
| Run-from rules | Always keeps away from the column, medusa and cerberus; holding only a close-quarters weapon it refuses sludge minions, inmaters, ragemasters, deathspheres, battleboars, psyclaws, skeeters, lasergats, doombats, dragons, the knights and the bosses (each class's `sidekicks` trait) | Implemented (sequence 413) |
| `trigger_sidekick` | Only toggles a HUD panel (inverted test); never stops the sidekick | Implemented (sequence 413: it used to disable the AI) |
| HUD flaps | `cl_scrn.cpp`: a flap for each sidekick in the player's view, Mikiko bottom left and Superfly bottom right, fading in and out (0.04 a frame to `statusbar_alpha` 0.6). Face by health in fifths (`calc_faceframe_index`), red health and yellow armour bars (3 wide, 100/2.8 tall), and an ammunition gauge (`SIDEKICK_GetAmmoCount`: 75%/35% Mikiko, 75%/40% Superfly; a weapon without ammunition plenty at range, low in close quarters). Server stats from `SetMikikoStats`/`SetSflyStats` | Implemented (sequence 422): the party's `status` session hook packs each member's presence, view (PVS), health %, armour % of the worn armour's capacity and gauge into player-state stats 8–11; `companion_hud.zig` draws them. Invisibility and invulnerability faces are not shown (sidekicks carry neither natively) |
| Command window | `cl_selector.cpp`/`draw_sidekickcommand_info`: the commanded sidekick's portrait over GET, COME, STAY, ATTACK, BACK OFF; selector keys step and apply; `sidekick_swap` changes who is commanded; the window fades in, holds, then fades out | Implemented (sequence 422): `sidekick_next`, `sidekick_prev`, `sidekick_apply`, `sidekick_swap` (default keys Z, X, V); the window holds 5.25 s after the last key and takes the weapon list's column while open |
| Orders | `SIDEKICK_ParseCommand`: get (the item the owner looks at, 800 units), come (a clear spot 64 in front of the owner, then follow), stay, attack (the enemy the owner faces; otherwise only willing to fight), back off (no attacking, keep with the owner); each answered with a voice line in the owner's PVS (`cmd_mi_*`, `cmd_su_*`; a refusal says no, a refused pickup `_n1`) | Implemented (sequence 422): new `come` and `backoff` orders; `sidekick_<order> [who]`, `companion <order> [who]` (the default binds' follow/wait/attack/pickup now work) and `sidekick <who> <order>` |
| Death | Drops its weapon; the game is over, the camera on the sidekick | Implemented |
| Documented deviations | Combat by the shared pilot (strafing, dodging, scored weapons) instead of planting and shooting; side-by-side following instead of the chain; it also engages hostiles it sees (the reference reacts only to attackers); a wider item scan | Recorded in bots-zig |
| Open questions | Stop nodes and teleport-node media; a said line is not saved (a reload can repeat it); the remaining sidekick voice lines (yes/no permission questions); exit refusal feedback (centre print, Hiro's line, the missing sidekick running over); defending the other sidekick; ladder and look/kick idles; the Episode 3 freeze death | Open |

## Animation inventory (converted `.anim`)

`m_superfly`, `m_mikiko`, `m_mikikofly`: grip-specific idles, runs, attacks, pain and deaths (read by `companion_pose`). The look, kick and ladder idles are not used yet.

## Verification (sequences 413, 414)

- Unit tests: item permission by authored spawnflags; talk volume and pauses.
- `--scenario sidekick-talk` (e3m1a): Superfly says his opening line `e3m1_sf_01a` once.
- Other changes: implemented, not yet verified in game.

## Verification (sequence 422)

- Unit tests: the status survives the 16-bit stat transport; window commands, default binds and acknowledgement names; ammunition gauge thresholds; face frames and the commanded sidekick; armour capacity.
- `--scenario sidekick-hud` (e3m1a): both flaps fade in; a 2000-point hit on Mikiko darkens her face and shortens her health bar; the window opens, steps to STAY and orders Mikiko (`why=stay`); after `sidekick_swap` it shows Superfly and his COME order moves him; `companion follow` orders both. Captures in `zig-out/reports/runtime-zig-422/sidekick-hud`.
- Not verified: the voice acknowledgements' audibility, the ammunition gauge in play (both sidekicks were unarmed in the probe), gameplay acceptance.
