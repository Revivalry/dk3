-- SPDX-License-Identifier: GPL-2.0-or-later
-- Episode 1: Japan, 2455. Coordinates and entity indices are authored map data
-- (dkq3/tools/coop_route_survey.py); waypoints follow the supplied ground nodes.

-- The Marsh, part 2: river, two turret controls, the bridge ambush and the
-- Thunderskeet whose death opens the north gate to part 3.
-- The stone east of the fallen span, clear of the west cliff and of the
-- laser barrier at x=-621: the arena every fight there is held in.
local plateau = { { -1000, 440 }, { -700, 800 } }
level("e1m1b", function(visit, resumed)
  if visit > 1 then return exit "e1m1c" end
  return stages {
    { "river", function()
      path { {-445, -1430, 536}, {-302, -1314, 581}, {-232, -1176, 624} }
      clear { radius = 250, timeout = 20 }   -- close attackers at the firing spot only
      shoot { index = 91 }                 -- first turret's control
    end },
    { "pond", function()
      path { {-232, -968, 648}, {-432, -880, 664}, {-660, -810, 664} }
      try(pickup, { index = 256 })         -- river health
      path { {-624, -648, 664}, {-398, -649, 633}, {-192, -704, 640}, {-112, -624, 640} }
      path { {-192, -704, 640}, {-398, -649, 633}, {-624, -648, 664}, {-720, -580, 664} }
    end },
    { "ford", function()
      path { {-797, -627, 664}, {-944, -616, 637}, {-1158, -624, 572}, {-1328, -688, 520},
             {-1342, -858, 497}, {-1406, -914, 474} }
      -- Continue down the bank into the ford. Holding the high bank to hunt
      -- submerged Crox spends the ion pack against the water surface; these
      -- enemies do not control a gate. Ordinary route combat meets them from
      -- each reachable stance along the crossing.
      path { {-1510, -914, 424}, {-1640, -904, 408}, {-1768, -888, 411} }
      -- Straight across the last of the ford: the area graph splits it into
      -- slivers whose seams lie a few units apart, and routed swimming
      -- circles between them.
      move({ -1904, -808, 408 }, { direct = true, radius = 24, timeout = 20 })
      path { {-2040, -680, 415}, {-2072, -520, 470}, {-2080, -464, 496} }
    end },
    { "tree", function()
      heal { index = 110 }
      path { {-2253, -612, 489}, {-2341, -419, 526}, {-2272, -328, 496}, {-2224, -328, 496} }
      -- West turret's control, from outside the rockgat's 512-unit reach.
      shoot({ index = 86 }, { from = { {-2240, -256, 496}, {-2184, -92, 479}, {-2288, 48, 472}, {-2411, 148, 472} } })
    end },
    { "climb", function()
      path({ {-2487, 360, 472}, {-2640, 463, 490}, {-2687, 607, 532}, {-2679, 743, 528}, {-2608, 944, 528} }, { direct = true })
      kill({ index = 425 }, { hold = true, timeout = 40 })
      path({ {-2384, 864, 472}, {-2272, 836, 472}, {-2120, 784, 472}, {-1972, 712, 472},
             {-1973, 581, 471}, {-1969, 396, 517}, {-1973, 294, 557}, {-1953, 198, 604},
             {-1834, 5, 705}, {-1800, -84, 774}, {-1775, -174, 823}, {-1659, -218, 824},
             {-1591, -51, 863}, {-1568, 159, 899}, {-1705, 306, 961}, {-1798, 463, 980},
             {-1751, 665, 986}, {-1648, 816, 984}, {-1616, 752, 984}, {-1548, 800, 984} }, { direct = true })
      -- The Crox in the pool under the span's west end lives in water, which
      -- ion bolts discharge in: it is only shot when it climbs out onto the
      -- bank in view of the deck. Take it when it does, run on when it does
      -- not (the arena is the bank itself, not the drop into the pool).
      try(kill, { index = 431 }, { hold = true, timeout = 25,
                                   arena = { { -1850, 400 }, { -1500, 900 } } })
    end },
    { "bridge", function()
      -- The span is a trap: the generator at its east end, and the death of
      -- either cambot over it, blows the deck apart a moment later (piece_03
      -- is the deck from x=-1376 to x=-992). Shooting the guards on the way
      -- drops the player into the pool, so run across ignoring them, as the
      -- game teaches, and fight from the stone east of the collapse.
      path({ {-1563, 622, 988}, {-1420, 640, 984}, {-1280, 640, 984}, {-1120, 640, 984},
             {-1010, 640, 984}, {-930, 640, 984} }, { fight = false, timeout = 90 })
      -- Across: the deck behind falls away, and the two guards, still alive,
      -- would shoot through the fight with the skeets. Clear them from the
      -- plateau (the arena is the plateau: the gap and the laser at x=-621
      -- bound the fight on its west and east).
      wait(2)
      move({ -792, 632, 984 }, { fight = false, radius = 48 })
      kill({ index = 481 }, { hold = true, timeout = 45, arena = plateau })
      kill({ index = 96 }, { hold = true, timeout = 45, arena = plateau })
      wait_until(function()
        local boss = dk3.entity { class = "monster_thunderskeet" }
        return boss and boss.health > 0
      end, { timeout = 60, reason = "Thunderskeet arrival" })
      -- Fight from the middle of the open east plateau: clear of the west
      -- cliff, which blocks the firing line, and of the laser at x=-621.
      move({ -792, 632, 984 }, { fight = false, radius = 48 })
      -- The arena keeps knockback clear of the laser barrier at x=-621.
      kill({ class = "monster_thunderskeet" }, { radius = 4000, hold = true, timeout = 300,
                                                 arena = plateau })
    end },
    { "north", checkpoint = true, function()
      save("marsh-boss-arrival")
      wait(3)                              -- sprays still falling after the kill
      -- The swim across the pool is fought with neither weapon: an ion bolt
      -- discharges where it meets water and the glove reaches no further than a
      -- body across. Whatever can follow a swimmer is met on the stone first,
      -- and the health to survive it is taken before the water and not after.
      try(recover, 0.85, 600)
      try(resupply, 20, 600)
      for _ = 1, 3 do
        if not try(function() clear { radius = 700, vertical_radius=128,
          hold=true,arena=plateau,timeout = 45 } end) then break end
      end
      -- The boss drops a Megashield where it dies; fetch it only if it landed on
      -- the plateau (elsewhere it strands the bot beyond the broken span).
      local shield = dk3.entity { class = "item_megashield" }
      if shield and shield.visible and (shield.x + 800) ^ 2 + (shield.y - 632) ^ 2 < 260 ^ 2 and shield.z > 940 then
        try(pickup, { id = shield.id }, { timeout = 15 })
      end
      -- Step off the plateau into the pool below, as the original driver did;
      -- the area graph routes a long climb with repeated fall damage instead.
      -- North-west corner, steered straight: after the collapse the plateau's
      -- area graph routes even short hops over the south cliff.
      -- Optional recovery can already have taken the surviving player down
      -- into the pool. Continue the exit from there instead of asking for
      -- an impossible climb back onto the collapsed plateau.
      local _, _, exit_height = dk3.position()
      if exit_height > 900 then
        move({ -880, 744, 984 }, { direct = true, radius = 48 })
      end
      move({ -1283, 908, 520 }, { direct = true, radius = 192 })
      -- A boss killed beyond the plateau can drop its shield into this
      -- pool. It becomes a useful nearby pickup once Hiro is down here;
      -- the earlier plateau-only check must not discard that recovery.
      shield=dk3.entity{class="item_megashield"}
      if shield and shield.visible and shield.z<700 then
        local px,py,pz=dk3.position()
        if (shield.x-px)^2+(shield.y-py)^2+(shield.z-pz)^2<400^2 then
          try(pickup,{id=shield.id},{direct=true,crouch=true,fight=false,weapon=1,timeout=10})
        end
      end
      -- In the pool, swim the area graph's water route to the north bank; a
      -- straight line loses to the westward current.
      move({ -1322, 1242, 520 }, { radius = 64 })
      move({ -1333, 1347, 509 }, { direct = true, radius = 32 })
      -- Keep the bank's rising footing through the submerged pursuit.
      -- Hunting a Crox from here steps back off the bank into the pool.
      path({ {-1331, 1415, 543},
             {-1314, 1510, 591}, {-1314, 1578, 625}, {-1270, 1700, 661} },
        {direct=true,fight=false})
      try(heal, { index = 106 })           -- north tree, opened by the boss's death
      path({ {-1047, 1676, 664}, {-900, 1600, 664} }, { direct = true, radius = 24 })
      exit "e1m1c"
    end },
  }(visit, resumed)
end)

local function opened(index)
  return function() local state = dk3.mover { index = index } return state == "open" or state == "opening" end
end

-- The Marsh, part 3 (factory): a pipe climb to the gate's overhead control,
-- the yard, the switch whose monitor shows the exit opening, the raised
-- platform, the liftmaster descent and the lower route to the authored cut.
level("e1m1c", function(visit, resumed)
  if visit > 1 then return exit "e1m2a" end
  return stages {
    { "outside", function()
      path { {-814, 1574, 664}, {-566, 1587, 641}, {-502, 1831, 633}, {-413, 2069, 632},
             {-217, 2027, 536}, {-134, 2003, 495}, {-48, 1971, 445} }
      path { {46, 1863, 412}, {128, 1800, 408} }
      heal { index = 195 }
      path { {46, 1863, 412}, {-48, 1971, 445}, {121, 2101, 408}, {194, 2173, 408},
             {414, 2256, 408} }
    end },
    { "pipe", function()
      -- The gate's switch is on the upper pipe; climb the sloping pipe, crouch
      -- under the low joint, then make the running jump to the upper run.
      -- Start from the pipe's southern foot. The northern ground detour
      -- serves no control and can leave Hiro below its raised endpoint.
      path({ {406, 2256, 408}, {406, 2184, 444} },
        {direct=true,fight=false,radius=16})
      path({ {406, 2144, 464}, {480, 2144, 456} }, { crouch = true, radius = 12, direct = true })
      move({ 494, 2136, 456 }, { radius = 12, direct = true })
      path({ {530, 2144, 528}, {530, 2281, 529} }, { radius = 20, direct = true })
      move({ 548, 2330, 528 }, { radius = 8, direct = true })
      leap({ 522, 2353, 536 }, { 424, 2424, 584 })
      path({ {424, 2464, 600}, {424, 2504, 624}, {480, 2544, 648}, {488, 2568, 664} }, { radius = 12, direct = true })
      expect(z() >= 640, "the gate's firing position is on the upper pipe")
    end },
    { "gate", function()
      shoot { index = 130 }                -- overhead breakable starts the delayed gate
      wait_until(function() return dk3.mover {index = 132} == "open" end,
        {timeout = 30, reason = "factory gate fully open before approaching its sweep"})
      path({ {370, 2460, 376}, {425, 2469, 376}, {461, 2510, 403}, {480, 2576, 408} }, { radius = 20 })
      path({ {504, 2656, 408}, {504, 2748, 408}, {555, 2748, 408} }, { radius = 20 })
    end },
    { "yard", function()
      path { {787, 2765, 408}, {969, 2701, 411}, {1139, 2565, 481}, {1260, 2526, 522},
             {1412, 2473, 568}, {1562, 2480, 613}, {1721, 2479, 660}, {1911, 2463, 708},
             {2112, 2373, 744}, {2208, 2178, 777}, {2202, 2037, 792}, {2072, 1976, 792},
             {1944, 1920, 792}, {1888, 1768, 792}, {1855, 1570, 792}, {1794, 1441, 785} }
      shoot { index = 113 }                -- yard control opens the interior door
      wait_until(opened(114), { timeout = 25, reason = "yard door" })
      move({ 1744, 1440, 792 }, { radius = 20 })
      heal { index = 122 }
    end },
    { "interior", function()
      path({ {1794, 1441, 785}, {1855, 1570, 792}, {1888, 1768, 792}, {1944, 1920, 792} }, { radius = 20, direct = true })
      local health = dk3.health()
      if health < 100 then
        path({ {1725.5, 1840.625, 792}, {1712, 1876, 792} }, { radius = 16, direct = true })
        heal { index = 428 }
        path({ {1725.5, 1840.625, 792}, {1944, 1920, 792} }, { radius = 20, direct = true })
      end
      -- The yard door swings slowly (85 degrees at 10 a second) across this
      -- way and shoves whoever is in its sweep: cross once it stands open.
      wait_until(function() return dk3.mover { index = 114 } == "open" end, { timeout = 20, reason = "yard door fully open" })
      path({ {2072, 1976, 792}, {2202, 2037, 792}, {2215, 1900, 824}, {2401, 1737, 806} }, { radius = 20, direct = true })
      move({ 2398, 1698, 816 }, { radius = 12, direct = true })
      use { index = 216 }                  -- the switch; its monitor shows the exit
      cinematic()
      -- The switch opens the catwalk to the lift as well as the exit door
      -- downstairs. Only the catwalk doors are waited for here: the exit door
      -- travels for ten seconds across a bank a Crox patrols, and anything in
      -- its sweep makes it reverse (authentic mover behaviour) -- a monster
      -- crossing it seals the exit, since the switch is a trigger_once. The
      -- door is reopened by hand below once its blocker is dead.
      for _, door in ipairs({ 214, 215 }) do
        wait_until(opened(door), { timeout = 25, reason = "catwalk doors" })
      end
    end },
    { "departure", function()
      path({ {2401, 1737, 806}, {2215, 1900, 824}, {2214, 1696, 849}, {2206, 1560, 849},
             {2208, 1478, 852}, {2208, 1416, 852} }, { radius = 16, direct = true })
      wait_until(function() return z() >= 960 end, { timeout = 10, reason = "platform raises the player" })
      path({ {2177, 1394, 964}, {2096, 1472, 992}, {2032, 1496, 960}, {1984, 1600, 960},
             {1824, 1632, 984}, {1728, 1660, 968} }, { radius = 20, direct = true })
      use { index = 118 }                  -- liftmaster lowers the player
      wait_until(function() return z() <= 690 end, { timeout = 8, reason = "liftmaster descent" })
      move({ 1653, 1596, 680 }, { radius = 20, direct = true })
    end },
    { "lower", checkpoint = true, function()
      -- Down the pocket's only descent -- the ledge at the south end of the
      -- upper bank, from which the area graph drops 128 units onto the low
      -- bank -- and along it to the Crox's ground (the graph's own legs).
      path({ {1649, 1620, 664}, {1600, 1329, 664}, {1707, 1265, 664}, {1711, 1175, 544},
             {1727, 1167, 552}, {1743, 1104, 544}, {1759, 1009, 520}, {1711, 881, 488} }, { radius = 24, direct = true, fight = false })
      -- The bank's Crox fires no gate output. Keep to the narrow bank rather
      -- than provoking it or stopping in its firing lane to hunt in the pool.
      -- Along the bank to the exit door in the area graph's own steps: the
      -- bank is a chain of narrow areas and one long hop across them makes the
      -- route alternate between two first legs, which walks the player in
      -- place. Each short step has a single way to go.
      path({ {1711, 847, 488}, {1681, 783, 488}, {1681, 721, 488}, {1674, 718, 486},
             {1658, 689, 472} }, { radius = 20, direct = true, fight = false })
      -- Sealed by the reversal above: open it by hand, as every door of its
      -- class is opened, and go through while the way stays clear.
      if dk3.mover { index = 313 } ~= "open" then
        dk3.log("exit door reversed; opening it by hand")
        use({ index = 313 }, { timeout = 30 })
        wait_until(opened(313), { timeout = 30, reason = "exit door reopened" })
      end
      wait(11)                                -- let the swing finish
      exit("e1m2a", {fight = false, direct = true})
    end },
  }(visit, resumed)
end)

-- Sewer System: the lift (button 312, train 313), the hatch event (button 109
-- and its monitor) and use-door 316 lead to the flooded drum room. Its east
-- grate is opened from the far side: down the tube, ride the cart (train 123)
-- to the pump rooms, press the C4 room's button 159, ride back up and cross
-- the drum room round its stationary paddles. The upper sewer's use-door 267
-- leads to the pod room button 48, which opens the west double door for ten
-- seconds; beyond it the rockfall tilts a slab into the canal, swum beneath
-- to the alcove where button 160 slides out the ladder rungs to the exit.
-- `coop_route_aas.py e1m2a path …` shows the area graph's view of each leg.
level("e1m2a", function(visit, resumed)
  if visit > 1 then return progress "e1m2b" end
  return stages {
    { "lift", function()
      use { index = 312 }
      ride { index = 313 }
      move({ -1430, -328, -344 }, { direct = true, radius = 24 })
    end },
    { "upper", function()
      path({ {-1360, -460, -344}, {-1232, -468, -328}, {-1104, -468, -312} }, { direct = true, radius = 24 })
      use { index = 109 }                  -- t10: opens the sewer1 hatch, shows its monitor
      cinematic()
      use { index = 316 }                  -- use-operated door to the hatch room
    end },
    { "pool", function()
      -- The hatch opens onto a flooded drum whose stationary west paddle
      -- splits the doorway: swim north of it and west of the north paddle
      -- into the north channel.
      move({ -1112, 30, -220 }, { radius = 40, timeout = 40 })  -- up the sloping channel
      wait_until(opened(234), { timeout = 25, reason = "sewer hatch" })
      path({ {-1072, 40, -224}, {-990, 48, -240}, {-800, 260, -240}, {-770, 400, -240} }, { direct = true, radius = 24 })
    end },
    { "sewer", function()
      -- North over the grate walkway, down the tube and east along the
      -- sewer to the cart's upper stop.
      move({ 560, 640, -504 }, { radius = 32, timeout = 90 })
    end },
    { "cart", function()
      -- The cart (train 123) waits over the drop to the pump room; its own
      -- button sends it round to the lower stop by the pumps.
      -- Press it from inside, close enough to reach past the cart's wall.
      move({ 650, 628, -504 }, { radius = 12, direct = true })
      use { index = 125 }
      ride { index = 123 }
    end },
    { "pumps", checkpoint = true, function()
      -- From the cart's lower stop through the pump rooms and up the stairs
      -- to the C4 room; its button opens the drum room's east grate.
      use { index = 159 }
      pickup { class = "weapon_c4viz" }
    end },
    { "return", function()
      -- The pump rooms are a pocket: back down to the cart and ride it up.
      move({ 898, 172, -648 }, { radius = 32, timeout = 60 })
      move({ 896, 256, -680 }, { radius = 24, direct = true })
      use { index = 385 }
      ride({ index = 123 }, {around = {616,584,-528}})
      -- Well clear of the cart: the area graph has no floor where it stands.
      path({ {560, 640, -504}, {500, 640, -504} }, { radius = 24, direct = true })
    end },
    { "east", checkpoint = true, function()
      -- Back up the tube (its top lip onto the walkway is a hop the area
      -- graph lacks); from the walkway's east end, swim round the north
      -- paddle to the open east grate.
      nodepath({ -620, 740, -312 }, { radius = 24, timeout = 90 })
      path({ {-650, 690, -310}, {-700, 560, -280}, {-712, 430, -236}, {-712, 372, -204} }, { direct = true, radius = 24 })
      path({ {-695, 345, -204}, {-650, 250, -232}, {-560, 200, -232}, {-430, 40, -232}, {-390, 40, -210} }, { direct = true, radius = 24 })
    end },
    { "upper sewer", checkpoint = true, function()
      -- Up the ramp east of the grate; the upper sewer's sludgeminions wait at
      -- its top, and its health pack is close by.
      move({ 113, -81, -72 }, { radius = 48, timeout = 40 })
      -- The lower pipe's creature is within 500 units in three dimensions,
      -- but under the solid ramp. Keep this sweep on the upper landing.
      clear { radius = 220, hold = true, timeout = 60 }
      local health, maximum = dk3.health()
      if health < 0.8 * maximum then try(function() pickup { index = 64 } end) end
      -- Round the upper sewer to its use-door; both leaves are separate.
      nodepath({index = 267}, {standoff = 96})
      move({-704,1088,-40}, {direct = true, radius = 8,
        vertical_radius = 16, fight = false, timeout = 10})
      use({index = 267}, {timeout = 30})
      if dk3.mover { index = 268 } == "closed" then use { index = 268 } end
      -- The sludgeminion by the west ramp would catch the dash: hunt it first.
      kill({ index = 6 }, { radius = 2000, timeout = 90 })
      recover(0.6)
      -- The pod room button opens the far west double door for ten seconds:
      -- run over the walkway above the waterfall shaft and up the ramp.
      for attempt = 1, 3 do
        nodepath({index = 48}, {standoff = 96, settle = false})
        use({index = 48}, {fight = false}) -- its monitor shows the doors open
        if try(function()
          path({ {-760, 1290, -208}, {-865, 1295, -208}, {-900, 1240, -216}, {-960, 1250, -200}, {-1050, 1290, -200},
                 {-1150, 1290, -190}, {-1206, 1260, -168}, {-1225, 1220, -150}, {-1233, 1150, -120}, {-1233, 1073, -89},
                 {-1233, 860, 24}, {-1265, 796, 48}, {-1310, 796, 56}, {-1348, 817, 56}, {-1348, 860, 80},
                 {-1348, 900, 88}, {-1398, 1024, 88}, {-1530, 1024, 88} },
               { direct = true, settle = false, fight = false, radius = 24, timeout = 6 })
        end) then break end
      end
      expect(x() <= -1490, "through the timed double door")
    end },
    { "canal", checkpoint = true, function()
      -- North past the rockfall and east along the ledge; its trigger drops
      -- the floor and tilts the rock slab into the canal. The surface is then
      -- blocked by the slab and, further east, by a barrier just under the
      -- water: slide down the slab and swim the deep passage beneath both to
      -- the basin below the ladder alcove. The swim keeps to the canal floor
      -- (about -230, deeper yet under the slab): the navigation still carries
      -- that passage at the height it had before the rockfall tilted the slab
      -- into it, so a swimmer who trusts the compiled depths ends up pressed
      -- against a rock that moved after the map was compiled.
      -- Leave the timed door's west recess along the outside of its wall.
      -- Starting a generated path in the recess can instead select the
      -- now-closed door as the way back east.
      path({{-1568,1024,88}, {-1568,1328,88}},
        {direct = true, radius = 8, fight = false})
      nodepath({-839,1452,72}, {fight = false})
      move({ -740, 1500, 80 }, { radius = 24, direct = true })
      wait(2)
      move({ -700, 1510, 80 }, { radius = 24, timeout = 20 })
      path({ {-560, 1530, -60}, {-480, 1540, -130}, {-400, 1560, -140}, {-330, 1560, -150},
             {-260, 1530, -150}, {-230, 1530, -200}, {-200, 1525, -228}, {-150, 1518, -232},
             {-100, 1505, -232}, {-55, 1485, -238}, {-48, 1454, -262}, {-20, 1448, -262},
             {60, 1442, -265}, {111, 1448, -262}, {132, 1497, -262}, {146, 1519, -250},
             {180, 1565, -244}, {223, 1583, -240}, {385, 1604, -67}, {422, 1519, 8} },
           { direct = true, radius = 24, vertical_radius = 16, fight = false })
      move({ 470, 1320, 72 }, { radius = 24, direct = true })
    end },
    { "ladder", checkpoint = true, function()
      move({460,1350,72}, {direct = true, radius = 4,
        vertical_radius = 16, fight = false, timeout = 10})
      if not opened(160)() then use({index = 160}, {hold = true, timeout = 8}) end
      wait(5)
      move({ 512, 1322, 72 }, { radius = 12, direct = true })
      move({ 512, 1250, 440 }, { radius = 24, direct = true, timeout = 30 })
      exit "e1m2b"
    end },
  }(visit, resumed)
end)

-- Sewer System part 2: from the ladder top along the pipe corridor onto the
-- gratings over the pipe room, off their north edge into the water chute,
-- whose trigger raises the sluice at its foot, and over the falls into the
-- flooded tank (a train of water the area graph knows nothing of). Under
-- water to the control room, whose button drains the tank and sinks the
-- hugedoor; back over the spinning drum fan before the water falls; through
-- the hugedoor and the passage behind it into the pit below the pipe room,
-- up to the valve walkway; the valve opens the west doors for ten seconds;
-- the long way west to the lift; through the double door to the end room
-- and its end-of-level button, whose scene takes Larry's elevator up.
-- `flood(goals, box)` (prelude) maps the tank's swim routes in the live game.
level("e1m2b", function(visit, resumed)
  if visit > 1 then return progress "e1m3a" end
  return stages {
    { "pipes", function()
      -- The gratings over the pipe room are sealed; the way on is the water
      -- chute below their north edge, a drop the area graph never links (and
      -- a hard landing in its shallow water). Top up from the packs at the
      -- south end and clear the north end first.
      for _, item in ipairs({ 267, 208, 149 }) do try(function() pickup { index = item } end) end
      -- Already down the chute (a run to the edge can carry on over it):
      -- go on from its floor.
      if z() > 0 then
        try(function() move({ 1560, 1376, 344 }, { radius = 32, timeout = 60 }) end)
        if z() > 0 then
          -- Fight from the ledge's north end: chasing down the catwalk runs
          -- into a rail the area graph does not know and wastes the guards'
          -- whole alarm (the e1m2b run of 25 s pinned at 1519,995).
          try(function()
            clear { radius = 400, timeout = 30, hold = true, arena = { { 1480, 1290 }, { 1690, 1470 } } }
          end)
          -- Step off the ledge's north edge into the chute. A fight may have
          -- moved the bot off the edge; the drop is one way, so come back to
          -- the lip and go over again rather than climb.
          for _ = 1, 3 do
            if try(function() move({ 1560, 1480, -200 }, { radius = 48, direct = true, timeout = 25 }) end) then break end
            if z() < 200 then break end
            try(function() move({ 1560, 1400, 344 }, { radius = 64, timeout = 25, fight = false }) end)
          end
          expect(z() < 200, "down the chute")
        end
      end
      -- Down the chute floor; its trigger (t44) raises the sluice at the foot.
      path({ {1640, 1488, -244}, {1760, 1488, -304}, {1820, 1488, -325} },
           { direct = true, radius = 40, fight = false })
      -- Past x 1800 the sluice's flow sweeps a body east faster than a player
      -- swims west: an upstream swim stalls at x 2150 for as long as it is
      -- asked for. Go with the flow instead, over the lip where the chute
      -- floor ends (x 2210) and down the fall into the tank's water: the
      -- goal is put below the lip, so a bot that stops short of the drop is
      -- still asked to take it.
      -- The last stretch to the lip is therefore asked for as a band rather
      -- than a point: reached, undershot or carried past x 1900 the body is
      -- where the flow is wanted (a run of t2 swam to 1954 with the current
      -- and could not return for its own twenty-unit arrival radius).
      move({ 1930, 1478, -335 }, { radius = 88, direct = true, fight = false, timeout = 45 })
      move({ 2245, 1470, -470 }, { radius = 96, direct = true, fight = false, timeout = 45 })
    end },
    { "tank", checkpoint = true, function()
      -- Over the falls into the flooded tank (the hugewater train). Its drain
      -- is reached under water: dive at the waterfall's foot and swim the
      -- submerged lower level south and east (some eleven seconds without
      -- air) to the air gap west of the control room.
      if x() < 3200 then
        move({ 2272, 1448, -488 }, { radius = 32, vertical_radius = 12, direct = true, fight = false, timeout = 15 })
        path({ {2368, 1376, -488}, {2368, 1376, -584}, {2392, 1352, -584}, {2392, 896, -584}, {2464, 824, -584},
               {3016, 824, -584}, {3016, 656, -596}, {3232, 656, -596}, {3232, 656, -488}, {3448, 640, -488},
               {3448, 560, -488} }, { direct = true, radius = 16, vertical_radius = 12, fight = false })
      end
      -- The control room's west window is the short way back out. Break it
      -- with the glove (an ion bolt would discharge in the water), take the
      -- room's two health packs and come back up for air.
      path({ {3480, 560, -600}, {3510, 560, -636} }, { direct = true, radius = 16, vertical_radius = 12, fight = false })
      shoot({ index = 235 }, { weapon = 1, timeout = 10 })
      path({ {3600, 560, -636} }, { direct = true, radius = 24, vertical_radius = 12, fight = false })
      for _, item in ipairs({ 202, 273 }) do try(function() pickup({ index = item }, { fight = false, timeout = 10 }) end) end
      path({ {3600, 560, -636}, {3500, 560, -636}, {3448, 600, -480} }, { direct = true, radius = 24, vertical_radius = 12, fight = false })
      wait(1)
    end },
    { "drain", function()
      -- The drain empties the tank and sinks the hugedoor (some twenty
      -- seconds). Dry, the control room's side is cut off by the drum fan
      -- spinning in the middle of the tank: press, swim back through the
      -- window and over the drum, under the low gap's ceiling, before the
      -- water falls (about seven seconds), then wait on the floor by the door.
      path({ {3500, 560, -636}, {3600, 560, -636}, {3664, 640, -640} }, { direct = true, radius = 24, vertical_radius = 12, fight = false })
      use({index = dk3.entity {index = 199} and 199 or 402},
        {hold = true, fight = false}) -- one button per skill; use from the control room
      path({ {3600, 560, -636}, {3500, 580, -648}, {3200, 600, -648}, {3130, 600, -616}, {3060, 600, -608},
             {2990, 580, -605}, {2900, 420, -605} }, { direct = true, radius = 24, vertical_radius = 12, fight = false })
      wait_until(function() return dk3.mover { index = 31 } == "open" end, { timeout = 40, reason = "hugedoor" })
      move({ 2880, 400, -712 }, { radius = 24, direct = true })
    end },
    { "passage", checkpoint = true, function()
      -- West up the passage behind the hugedoor; its trigger opens the doors
      -- (t42) into the pit below the pipe room, whose ladder leads up to the
      -- valve ledge.
      move({ 2139, 367, -474 }, { radius = 32, timeout = 60 })
    end },
    { "valve", checkpoint = true, function()
      -- Through the doors (t42) into the pit, up its ladder and over to the
      -- platform above the central machine; the valve stands on the walkway
      -- above that, up a ladder the area graph does not link. The valve opens
      -- the doors (t40) west of the pit for ten seconds.
      -- Sludgeminions wade in the pit and lob sludge: fight them from its
      -- south end before walking up its length.
      move({ 1640, 400, -488 }, { radius = 48, timeout = 60 })
      -- Everything in the pit, before the crossing: a body on the plank has
      -- fourteen units either side, and one hit's knockback spends them.
      try(function() clear { radius = 500, hold = true, timeout = 45,
                             arena = { { 1470, 330 }, { 1900, 1180 } } } end)
      -- Up the pit's west side and along its north end to the ladder: the
      -- spinning column in the middle (absent from the area graph) has a sump
      -- round its foot that traps a player.
      path({ {1600, 520, -488}, {1600, 945, -488}, {1720, 1060, -488}, {1833, 1105, -488} }, { radius = 40, timeout = 60 })
      -- The platform is a frame of narrow beams over the pit: walk the
      -- straight one along y 840 to the ladder, braking at each turn.
      -- The plank over the pit's west edge, walked in the open: the area
      -- graph's way to it keeps re-offering the ladder the bot just climbed,
      -- and a route back east here is a route off the plank into the pit.
      --
      -- What makes the crossing is not the drop but the water. The shelf
      -- stands at -16 between two platforms at 0 (one step either end) and a
      -- liquid brush caps it from -16 to 0: shallow enough that a body on it
      -- only wades, and authored with a current due east. Gold's PM_AddCurrents
      -- carries a wading walker at half the swim speed, two hundred units a
      -- second, and a walker's own step is cut to five sixths in water -- so
      -- the race is beatable (two hundred sixty-six of walk against two
      -- hundred of flow leaves about a hundred and eighty of going forward,
      -- and the length is crossed in a second) but only by a body that aims
      -- upstream and keeps its stroke full. Braking is what kills: a half
      -- stroke has nothing left over the current and the body simply travels
      -- with it, east, off the shelf's end at x 1564 and five hundred units
      -- down. Nothing turns inside the race: it is crossed in one straight
      -- full-length stroke, so no arrival falls in it.
      --
      -- Two walls fence the water. Its west edge (x 1456..1472) is filled
      -- playerclip to the water's own height, so the race is entered from a
      -- platform end and never from the dry ledge west of it; a hull there
      -- must keep its centre east of x 1487. East, the shelf ends at x 1564
      -- and a fan blows down the shaft (a push of 200 east in x 1574..1594,
      -- y 1030..1194): a hull from x 1558 touches it, and a volume that sets
      -- the velocity every frame it is touched cannot be steered out of, so
      -- the run keeps well inside. The line asked for is x 1505 -- nineteen
      -- clear of the clip, fifty clear of the shelf's end, so the drift the
      -- motor cannot cancel still lands on the shelf.
      -- The pit's north wall stands at y 1241 and the ladder is a face on it
      -- between x 1750 and x 1800. A body asked for y 1235 is walked into that
      -- wall: its own hull then starts inside a solid, every trace the motor
      -- makes answers start_solid and the run of b12 stood in one place for a
      -- hundred seconds with nothing in front of it. The base is stood off at
      -- y 1205 and reached along x 1850, where the floor is one unbroken slab
      -- (west of x 1700 a ledge steps down and wedges a body against its side),
      -- and the climb is asked for the standing area at the ladder's head that
      -- the area graph does reach.
      local ladder_base, ladder_head = { 1770, 1205, -480 }, { 1793, 1256, -24 }
      local function plank()
        if z() < -200 then
          -- Back on the pit's floor: the ladder again.
          path({ {1850, 1120, -480}, {1850, 1205, -480}, ladder_base },
               { radius = 40, timeout = 60, fight = false })
          move(ladder_head, { radius = 48, timeout = 90, fight = false })
          if z() < -200 then error("off the pit's ladder", 0) end
        end
        -- Onto the platform and square on to the water. A wall stands on the
        -- platform's west half (x 1408..1520 is solid from its floor to the
        -- head), so the climb up from the ledge below is made at x 1560 --
        -- forty clear of the wall's face, forty clear of the platform's east
        -- end at x 1600, beyond which the pit begins -- and the standing line
        -- afterwards keeps the same twenty units between the two.
        path({ {1650, 1275, -10}, {1585, 1288, -10}, {1556, 1246, 24}, {1544, 1240, 24} },
             { direct = true, radius = 14, timeout = 45, on_floor = true, fight = false })
        if x() < 1525 or x() > 1565 or z() < 12 or z() > 40 then
          error("off the platform's west end", 0)
        end
        -- The race, in one stroke: the far platform is the only place to stop,
        -- so the goal is set beyond the water and the whole length is walked
        -- with the current fought the whole way. Asked short, the bot brakes in
        -- the water and the flow takes it east. The line is the same x the run
        -- stands at: the drift the motor cannot cancel is a few units over the
        -- second and a half of the crossing, and the line stands ten clear of
        -- the block that fills the north landing's west end (x 1408..1520) and
        -- ten clear of the shelf's east edge (x 1553 fully supported, the fan
        -- touching a hull from x 1561).
        move({ 1544, 990, 24 }, { direct = true, radius = 14, timeout = 40, fight = false })
        if z() < 16 or x() > 1560 or x() < 1440 then
          error("in the race", 0)
        end
        -- Stand on the plank short of its north end, then stand still: a hop
        -- takes off at the speed it was running at, and the motor sets that
        -- speed from the drop ahead (see below), so it needs the plank's own
        -- length to settle into it. Arrived at a run, the body jumped from the
        -- tip at twice the speed the drop can use.
        move({ 1544, 992, 24 }, { direct = true, radius = 10, timeout = 25, fight = false })
        wait(0.6)
        if x() < 1525 or x() > 1565 or z() < 16 then error("off the plank", 0) end
        -- The plank's north end (y ~945) hangs over the pit and the beam frame
        -- under the machine catches a body thirty-two units below it, between
        -- y ~900 and y ~835 where its slabs stand; between them nothing holds a
        -- hull. The landing is the frame's middle (y 862, where two slabs
        -- overlap); the take-off is the tip, forty units of dry plank behind
        -- the standing place above. The speed of the hop is the motor's own
        -- arithmetic on that drop: asked for as a run it passed a hundred units
        -- above the frame and fell in the pit on its north side.
        if not try(function() leap({ 1548, 948, 24 }, { 1552, 862, -8 }) end) then
          error("off the plank's north end", 0)
        end
        -- East along the beam. Its north and south edges have gaps where its
        -- cross-members stand; y 840 is the one row traced with continuous
        -- support from x 1530 to the ladder at x 2000.
        path({ {1554, 840, -8}, {1700, 840, -8}, {1860, 840, -8}, {1986, 840, -8} },
             { direct = true, radius = 16, timeout = 90, fight = false })
        -- Up the ladder at x 2000 onto the valve walkway, then east up its ramp.
        move({ 2004, 840, 76 }, { radius = 28, timeout = 30, fight = false })
        move({ 2040, 840, 96 }, { radius = 28, timeout = 20, fight = false })
      end
      -- A step off the plank ends on the pit's floor, and plank() goes back up
      -- the ladder from there by itself; a stop on the plank takes up at the
      -- same step rather than losing the ground already won.
      local function climb()
        for attempt = 1, 4 do
          if try(plank) then return end
        end
        error("never reached the valve walkway", 0)
      end
      climb()
      -- North up the walkway to the shelf that caps the pit's north-west
      -- corner. The walkway is a ramp: a flat strip of some twenty units at
      -- x 2000, its face rising east from there to the upper floor at x 2110,
      -- and the pit falling west from the same line. The area graph walks the
      -- ramp's own face and turns west at the north end, where the shelf
      -- begins: fifty units deep (y 1196..1246), holding the ionpack, four
      -- protopods and the worker who guards the wheel.
      path({{2040,840,96},{2040,1000,96},{2040,1224,96}},
        {direct = true, radius = 8, vertical_radius = 32, fight = false, timeout = 30})
      for _, pod in ipairs({379,380}) do
        try(shoot, {index = pod}, {weapon = 2, hold = true, fight = false, timeout = 8})
      end
      move({ 1980, 1230, 72 }, {direct = true, radius = 8, vertical_radius = 32, timeout = 30, fight = false })
      expect(z() > 40 and z() < 110 and x() < 1996, "on the shelf above the pit")
      -- What stands between here and the wheel is shot from the standing
      -- place, never walked up to. A protopod blocks the lane's mouth (x 1984,
      -- y 1240) and another stands in the lane itself (y 1296); two more lie
      -- along the shelf's middle and west end where the way back goes; each
      -- hatches a slaughterskeet the moment it sees a player. The worker keeps
      -- the wheel, dead centre of the lane. The lane is thirty units wide and
      -- the pit beside it five hundred deep, and a fought body moves further
      -- than the lane: so the shots are taken without a step, from the ground
      -- the bot is already standing on (`shoot` with a `from` spot walks to it
      -- first, and the spot named here is the spot already under the bot).
      for _, guard in ipairs({ 379, 380, 378, 377, 50 }) do
        try(function()
          shoot({ index = guard }, { from = { { 1980, 1230, 72 } }, weapon = 2, timeout = 20, fight = false })
        end)
      end
      -- The pods are spent by the time the bot arrives (each hatches its
      -- slaughterskeet the moment it sees a player), so they are shot at only
      -- if something still stands in their place. The protopod in the pit below
      -- the lane's west end is taken the same way -- from the shelf, never by
      -- going down for it: a body that leaves the shelf for the pit gives up
      -- the crossing with the doors open behind it.
      try(shoot, { index = 85 }, { from = { { 1980, 1230, 72 }, { 1900, 1230, 72 } }, weapon = 2, timeout = 20, fight = false })
      -- Up the lane to the wheel. The navigation's own standing areas trace
      -- the lane from x 1968 to x 2000 for its whole length, so the walked
      -- line is its centre at x 1984: onto the lane first, then the length of
      -- it in one straight stroke, nobody fought and nothing stopped on it. The
      -- ionpack at x 1888 lies on the shelf's middle, not on the way here; it
      -- is taken on the way back, by walking over it.
      move({ 1984, 1260, 72 }, {direct = true, radius = 10, timeout = 30, fight = false })
      expect(x() > 1962 and x() < 2006 and y() > 1250 and z() > 40 and z() < 110,
             "on the lane to the wheel")
      move({ 1984, 1378, 72 }, { direct = true, radius = 14, timeout = 40, fight = false })
      expect(y() > 1330 and z() > 40 and z() < 110, "at the valve wheel")
      -- A turn blocked part-way (a body at the wheel) springs back without
      -- opening the doors: press until the wheel stays open.
      -- The press is taken whatever is shooting from the pit: fighting first
      -- here loses the eleven seconds the doors stay open, and a body at the
      -- wheel is pressed through (the wheel's own retry below).
      local function turn()
        for _ = 1, 4 do
          use({ index = 112 }, { timeout = 30, fight = false })
          if try(function()
            wait_until(function() return dk3.mover { index = 112 } == "open" end, { timeout = 4, reason = "valve open" })
          end) then return end
        end
        error("the valve never stayed open", 0)
      end
      turn()
      -- West, and not back the way the bot came: the shelf's west end is an
      -- edge above the pit's sloping side, a drop of a hundred and forty-four
      -- that costs no damage and saves the whole crossing of the beams and the
      -- race. Down it, west and north-west up the slope to the ledge above the
      -- race's north end, then south down the race's east side and west across
      -- its shallow end and through the doors the wheel has just opened --
      -- which stay open eleven seconds, so nothing on this way stops.
      local function back()
        -- Back down the lane and west along the shelf.
        move({ 1980, 1234, 72 }, { radius = 12, timeout = 30, fight = false })
        -- Off the shelf's west face (x 1824) onto the pit's slope below.
        move({ 1802, 1245, -48 }, { on_floor = true, radius = 44, timeout = 45, fight = false })
        move({ 1772, 1264, -48 }, { on_floor = true, radius = 44, timeout = 40, fight = false })
        move({ 1612, 1300, 0 }, { on_floor = true, radius = 48, timeout = 45, fight = false })
        -- The lip at the race's north-east corner stands twenty-four over the
        -- slope: the area graph asks a jump there and the motor makes one.
        move({ 1560, 1272, 24 }, { on_floor = true, radius = 40, timeout = 40, fight = false })
        move({ 1560, 1200, 24 }, { direct = true, radius = 30, timeout = 30, fight = false })
        -- Across the race without stopping. A liquid brush lies on the shelf
        -- from x 1490 to x 1553, sixteen over a wading body and authored with a
        -- current due east: Gold's PM_AddCurrents takes a wading body at half
        -- the swim speed, two hundred, against two hundred and sixty-six of a
        -- walker's own shortened step. Standing still in it is travelling with
        -- it, east, and the shelf's east end is a fall of five hundred units.
        move({ 1460, 1112, 40 }, { direct = true, radius = 26, timeout = 40, fight = false })
        -- Through the doors. Their own floor is the sill they stand in at feet
        -- sixteen, and the wheel's door slides down into it, so the way west is
        -- walked over the top of the retracted leaf.
        move({ 1368, 1112, 40 }, { on_floor = true, radius = 24, timeout = 45, fight = false })
      end
      for attempt = 1, 3 do
        if try(back) then break end
        -- Already west of the leaf (its box ends at x 1424) the doors no longer
        -- matter: a body standing in the water at the sill has won the crossing
        -- and must not be walked back to the wheel for a second press.
        if x() < 1400 then break end
        -- Not through: at the wheel again, because the doors close on a player
        -- who is too slow. A body driven off the shelf into the pit goes by its
        -- ladder, which climb() knows; a body left on the shelf walks back to
        -- the lane's mouth.
        if z() < -200 then
          climb()
          move({ 1980, 1230, 72 }, { radius = 16, timeout = 60, fight = false })
        else
          try(function()
            move({ 1900, 1230, 72 }, { radius = 24, timeout = 45, fight = false })
          end)
        end
        turn()
      end
      expect(x() < 1400, "through the valve doors")
    end },
    { "west", checkpoint = true, function()
      -- Sludgeminions hold the long way west; their globs are dodged from a
      -- distance but land on a player running past: stand and fight each as
      -- it engages. The first wades by the pool with the health pack and sees
      -- the doors: fight it from inside them (they close behind the player),
      -- then take the pack.
      move({1360,1112,40}, {direct = true, fight = false,
        radius = 12, vertical_radius = 24, timeout = 15})
      local pool_guard = dk3.entity {index = 106}
      if pool_guard and (pool_guard.health or 0) > 0 then
        shoot({index = 106}, {weapon = 2, fight = false, hold = true,
          arena = {{1280,1088},{1416,1136}}, timeout = 12})
      end
      -- The low pool has no AAS link through its overhang. Stay on the west
      -- side of the valve instead of routing back around the eastern pit.
      path({{1360,1112,40},{1100,1112,40}},
        {direct = true, radius = 12,
          vertical_radius = 160, timeout = 15})
      move({960,1112,144}, {direct = true, radius = 12,
        vertical_radius = 160, timeout = 15})
      try(clear, {radius = 260, hold = true, timeout = 20,
        arena = {{900,1088},{1020,1136}}})
      -- Crossing the western trigger retracts the health pool's lid.
      -- Return over the near bank only once the opening is clear.
      if dk3.health() < 100 and not opened(258)() then
        move({864,1075,168}, {direct = true, radius = 8,
          vertical_radius = 32, timeout = 5})
        move({928,1075,168}, {direct = true, radius = 8,
          vertical_radius = 32, timeout = 5})
        wait_until(function() return dk3.mover {index = 258} == "open" end,
          {timeout = 10, fight = true, stance = {928,1075,168}, around = {0,0,0},
            reason = "the health pool lid clears"})
      end
      if opened(258)() then
        move({960,1112,40}, {direct = true, radius = 8, vertical_radius = 24,
          fight = false, timeout = 10})
        try(pickup, {index = 28}, {direct = true, fight = false, timeout = 5})
      end
      -- Out of the pool (if the pack took the bot in) over its north lip,
      -- facing the lip for the water jump.
      if dk3.position() < 1000 and z() < 100 then
        try(function() path({ {930, 1105, 135}, {905, 1098, 150} }, { direct = true, radius = 16, fight = false, timeout = 8 }) end)
      end
      -- West along the wading channel, entered clear of the deep pool under
      -- the overhang east of it.
      path({ {880, 1075, 168}, {875, 1112, 152}, {760, 1112, 152} }, { direct = true, radius = 16, timeout = 15 })
      -- Each sludgeminion along the channels is fought from a chosen spot
      -- before the bend that brings the bot to it (spot, prey, arena).
      local function engage(spot, prey, arena)
        move(spot, { radius = 32, timeout = 90, cautious = true })
        try(function()
          kill({ class = "monster_sludgeminion" }, { around = prey, radius = 220, hold = true, timeout = 40, arena = arena })
        end)
      end
      engage({ 250, 1112, 152 }, { -83, 1034, 152 }, { { 100, 1092 }, { 450, 1132 } })
      engage({ -40, 1120, 152 }, { -152, 832, 152 }, { { -190, 1000 }, { -20, 1150 } })
      engage({ -152, 760, 152 }, { -264, 536, 152 }, { { -172, 640 }, { -132, 900 } })
      engage({ -300, 536, 160 }, { -736, 536, 280 }, { { -460, 516 }, { -280, 556 } })
      move({ -1471, 536, 280 }, { radius = 48, timeout = 300, cautious = true })
    end },
    { "hall", checkpoint = true, function()
      -- Into the hall (a froginator, sludgeminions and protopods), standing to
      -- fight as they come; then its health and ion ammunition.
      move({ -1356, 225, 360 }, { radius = 48, timeout = 180, cautious = true })
      for _, item in ipairs({ 203, 274, 265 }) do try(function() pickup({ index = item }, { timeout = 30 }) end) end
      move({ -1071, -768, 472 }, { radius = 48, timeout = 300, cautious = true })
    end },
    { "lift", function()
      ride { index = 198 }                 -- its trigger raises it to the upper floor
      for _, door in ipairs({ 232, 231 }) do
        if dk3.mover { index = door } == "closed" then use { index = door } end
      end
      move({ -1440, -768, 920 }, { radius = 24, direct = true })
    end },
    { "end", checkpoint = true, function()
      -- The end-of-level button on the end room's south wall (single player;
      -- its co-op twin, 413, opens Larry's elevator instead): the closing
      -- scene takes Hiro up in the elevator and travels on.
      -- Off the lift's landing first: a fight there leaves the player in
      -- the area over the shaft, whose way to the button is down the lift.
      move({ -1440, -800, 920 }, { direct = true, radius = 24, timeout = 10 })
      path({{-1520,-800,920},{-1568,-944,920}},
        {direct = true, radius = 8, vertical_radius = 16, fight = false, timeout = 10})
      use({index = 135}, {hold = true, timeout = 8})
      cinematic()
      wait(30)
    end },
  }(visit, resumed)
end)

-- Solitary: from the arrival corridor the guard post's button opens the cell
-- block doors (and calls its guards); in the cell block, breaking the panel
-- by the cells (explosive 16) starts the break-out: every laser goes off,
-- the cells open and the wall at the east laser falls.
level("e1m3a", function(visit, resumed)
  if visit > 1 then return progress "e1m3b" end
  -- Objectives only where navigation and its planner find the way (doors,
  -- lasers, the jammed door, the big lift): moves are spelled out only for
  -- the acro-boost climb and the fan draught, which the area graph cannot
  -- express, and the cell block 2 cage, which generic lift handling does not
  -- yet ride reliably.
  return stages {
    { "breakout", function()
      -- The cell block's control panel, in sight only from the pit below it:
      -- the planner opens the guard room and the hydraulic door on the way.
      shoot { index = 16 }
      wait(3)
      -- The pit's two health packs, before the released inmates arrive.
      for _, item in ipairs({ 263, 301 }) do try(function() pickup({ index = item }, { timeout = 10 }) end) end
    end },
    { "ramp", checkpoint = true, function()
      -- Access Granted at the top of the ramp round the lift shaft (through
      -- the lift room's platdoor), then the shotcycler on the ramp below:
      -- the guards and inmaters ahead fall far faster to it.
      -- Meet the released inmates before starting the long lift/control
      -- approach; otherwise the last one attacks from behind on the stairs.
      for _, foe in ipairs({252}) do
        kill({index = foe}, {hold = true,
          weapon = dk3.ammo(2) > 0 and 2 or 0, timeout = 60})
      end
      -- Open the lift-room slab at its actual entry panel. Waiting for
      -- automatic door routing can leave the bot outside this manual door.
      if not opened(293)() then
        use {index = 757}
        wait_until(opened(293), {timeout = 20, reason = "lift-room slab opens"})
      end
      local lift = dk3.entity {index = 3}
      if lift and lift.z > z() + 128 then use {index = 86} end
      -- Approach outside the slab's sweep, then cross its short opening
      -- directly. A graph detour inside the doorway can outlast its timer
      -- and leave the player waiting in the slab it is trying to close.
      move({508,-484,-872}, {crouch = true, fight = false,
        radius = 4, vertical_radius = 16, timeout = 45})
      if not opened(293)() then
        use {index = 757}
        wait_until(opened(293), {timeout = 20, reason = "lift-room slab reopens"})
      end
      move({608,-484,-872}, {direct = true, crouch = true, fight = false,
        radius = 8, vertical_radius = 16, timeout = 15})
      move({870,-484,-872}, {direct = true, crouch = true, fight = false,
        radius = 8, vertical_radius = 16, timeout = 45})
      ride({index = 3}, {crouch = true, timeout = 90})
      -- Meet the upper ramp's shooter before descending to its console;
      -- aiming at the panel leaves the bot exposed to its first volley.
      try(kill, {index = 257}, {weapon = 2, timeout = 40})
      use { index = 237 }
      try(function() pickup({ index = 164 }, { timeout = 30 }) end)
    end },
    { "broken door", checkpoint = true, function()
      -- The jammed door to Cell Block 2 sparks and shoves back anyone at it:
      -- blast the short-circuiting wires above the big lift's top landing.
      -- Its halves then stop apart, leaving a gap a crouching player fits.
      -- A fresh run can arrive without ranged ammunition. These cells are
      -- on the accessible lift landing, before the wires need to be shot.
      for _, item in ipairs({ 193, 155 }) do try(function() pickup({ index = item }, { timeout = 30 }) end) end
      shoot({index = 122}, {weapon = 2})
      wait(3)
    end },
    { "hidden door", function()
      -- The block's main door is a dummy. The hidden door right of the green
      -- Mishima sign opens on a barrel of explosives against a cracked panel:
      -- blow both, from outside the barrel's blast.
      if not try(function() shoot { index = 214 } end) then shoot { index = 119 } end
      wait(2)
      expect((dk3.entity { index = 119 } or {}).health ~= 1, "the panel behind the barrel is broken")
    end },
    { "pipe room", checkpoint = true, function()
      -- Crawl through the hole into the red-lit pipe room, round its pipes to
      -- the ladder at the back and up onto the upper pipe. The acro boost
      -- lies on the floor in a pocket fenced by low pipes, open from the pipe
      -- tops: drop in for it, then the boosted jump clears the fence onto a
      -- pipe below the hatch and, from there, up through the hatch (the
      -- boost lasts thirty seconds).
      path({ {2400, 230, -168}, {2344, 168, -168}, {2344, 136, -168}, {2312, 104, -168}, {2328, 72, -168}, {2344, 40, -168} },
           { direct = true, crouch = true, radius = 16, timeout = 15 })
      path({ {2280, 56, -168}, {2264, 40, -168}, {2264, -184, -168}, {2296, -216, -168}, {2312, -216, -168}, {2344, -184, -168}, {2344, -136, -168}, {2360, -120, -168}, {2384, -120, -168} },
           { direct = true, crouch = true, radius = 12, timeout = 15 })
      move({ 2382, -150, -80 }, { radius = 16, direct = true, timeout = 10 })
      path({ {2360, -152, -72}, {2328, -136, -80}, {2296, -104, -72}, {2264, -72, -72}, {2264, -40, -72}, {2296, -40, -72} },
           { direct = true, crouch = true, radius = 12, timeout = 15 })
      move({ 2340, -30, -168 }, { radius = 16, vertical_radius = 8, direct = true, timeout = 8 })
      -- Finish the drop and face the landing before the boosted hop. Turning
      -- during this short run-up catches the underside of the surrounding pipe.
      wait(0.25)
      expect(not (dk3.entity { index = 216 } or {}).visible, "acro boost taken")
      local px, py = dk3.position()
      look(math.atan(72-py,2336-px)*180/math.pi,0)
      leap({ 2336, 4, -168 }, { 2336, 72, -72 },
        {pace = 1, fight = false, radius = 64})
      local _, _, z = dk3.position()
      expect(z > -120, "on the pipe below the hatch")
      if z < -30 then
        -- Enter the hatch's headroom completely: the old eight-unit arrival
        -- tolerance stopped at y=65, still underneath its low overhang.
        move({ 2336, 76, z }, { radius = 2, vertical_radius = 24, direct = true, crouch = true, timeout = 5 })
        _, _, z = dk3.position()
        px, py = dk3.position()
        look(math.atan(40-py,2304-px)*180/math.pi,0)
        leap({ 2336, 72, z }, { 2304, 40, -16 }, {pace = 1, fight = false,
          radius = 32, vertical_radius = 24})
        _, _, z = dk3.position()
      end
      expect(z > -30, "through the hatch")
    end },
    { "fans", checkpoint = true, function()
      -- Back along the platform, staying low under the fans, over the
      -- lowest pipe and into the pipe mouth at its end: its draught carries
      -- the player down and out into Cell Block 2.
      path({ {2232, 40, -16}, {2168, -24, -16}, {2088, -104, -16}, {2088, -296, -16}, {2088, -349, -16}, {2120, -376, -16}, {2152, -408, -16}, {2184, -392, -16}, {2216, -360, -16} },
           { direct = true, crouch = true, radius = 12, timeout = 15 })
      leap({ 2216, -360, -16 }, { 2300, -360, -24 })
      path({ {2280, -376, -24}, {2280, -456, -24}, {2340, -480, -24} }, { direct = true, crouch = true, radius = 12, timeout = 15 })
      leap({ 2340, -480, -24 }, { 2400, -480, -104 })
      path({ {2364, -480, -104}, {2330, -480, -168} }, { direct = true, crouch = true, radius = 16, timeout = 10 })
    end },
    { "cell block 2", checkpoint = true, function()
      -- Down the lift (a cage; its button rides on it) to the torture room and
      -- along past the cells to the control room: its computer extends the
      -- platform over the torture chamber and opens the door to it upstairs.
      -- Its health station before the guards upstairs, then back up the lift.
      -- The cage's rides stay explicit: generic lift handling does not yet
      -- ride it reliably (crushes at its landing edge).
      move({ 1864, -424, -168 }, { radius = 24, timeout = 60 })
      use { index = 268 }
      ride { index = 267 }
      -- Leave the cage before meeting the far corridor shooter. Trading
      -- volleys inside its walls gives the dodge controller nowhere to go.
      path({{1864,-328,-488},{1736,-328,-488}},
        {direct = true, radius = 12, fight = false, timeout = 10})
      try(kill, {index = 447}, {weapon = 2, timeout = 40})
      use { index = 357 }
      wait_until(function() return dk3.mover { index = 206 } ~= "closed" or dk3.mover { index = 30 } ~= "closed" end, { timeout = 10, reason = "bridge moving" })
      recharge { index = 146 }
      move({ 1864, -424, -488 }, { radius = 24, timeout = 120 })
      use { index = 268 }
      ride { index = 267 }
    end },
    { "bridge", checkpoint = true, function()
      -- Along to the door the computer opened and over the extended platform
      -- (void to the area graph) to the door at its far end, open ten seconds
      -- from its button: crossed at once, which the planner does not time.
      wait_until(function() return dk3.mover { index = 206 } == "open" end, { timeout = 30, reason = "platform extended" })
      path({ {2088, -296, -168}, {2088, -8, -168}, {2040, 8, -168}, {1900, -8, -170}, {1760, 30, -170} }, { direct = true, radius = 24, timeout = 20 })
      use { index = 419 }
      wait_until(function() return dk3.mover { index = 287 } == "open" end, { timeout = 10, reason = "door 287" })
      path({ {1640, 64, -168}, {1584, 72, -160} }, { direct = true, radius = 24, timeout = 8 })
    end },
    { "out", checkpoint = true, function()
      -- Up the stairs past the guards and through the access door (its blue
      -- button beside it) to the control room: its keyboard unlocks the gates
      -- on the way out. A guard holds the far end of the corridor to the
      -- access door; an inmater waits along the catwalk beyond and follows
      -- (fight it there); a guard on the catwalk above the keyboard fires down
      -- (fight him from the floor west of the lift).
      try(function() kill({ index = 24 }, { timeout = 30 }) end)
      use { index = 27 }
      -- Held: chased, it leads back out through the access door, which then
      -- shuts behind the player.
      try(function() kill({ index = 254 }, {hold = true, radius = 600, timeout = 25,
        weapon = 2}) end)
      try(function()
        kill({ index = 165 }, { hold = true, radius = 700, timeout = 12, arena = { { 1380, 380 }, { 1530, 560 } } })
      end)
      try(function() pickup({ index = 270 }, { timeout = 15 }) end)
      use { index = 101 }
      -- Up the lift beside it (a plat the bot rides) to the catwalk, the
      -- health station by the gates before part 2's guards, then out.
      ride { index = 19 }
      -- The guard can leave the far catwalk and block the lift's exit.
      -- From this height the landing finally has a clear firing line.
      try(shoot, {index = 165}, {hold = true, weapon = 2, fight = false, timeout = 10})
      move({1608,560,88}, {direct = true, radius = 12,
        vertical_radius = 16, weapon = 2, timeout = 20})
      try(function() recharge { index = 154 } end)
      advance({ id = dk3.exit_to("e1m3b") })
      exit "e1m3b"
    end },
  }(visit, resumed)
end)

-- Solitary, part 2: the console behind a typing worker opens the big door;
-- a shot at the lightning box above the laser corridor kills its beams and
-- opens the floor beyond; the cell keycard lets the bot into the torture
-- chamber scenes that free Superfly, who must be near at the exit.
level("e1m3b", function(visit, resumed)
  if visit > 1 then return exit "e1m4a" end
  return stages {
    { "guards", function()
      -- Two guards fire on the arrival ledge; a pack lies in the steam below it.
      -- Fought from the ledge: in the open below they hit twice as often.
      try(function() clear { radius = 450, timeout = 25, hold = true } end)
    end },
    { "console", function()
      -- The arrival floor's ammunition: the shotcycler holds thirty shells and
      -- a box is twenty-four, so a fight fought without the next box in sight is
      -- a fight fought with an empty gun. The box by the steam pool (#310) and
      -- the two by the octagon's stairs (#130, #385) lie below the floor plates
      -- -- no area of the graph holds them -- so only the cells and the pack.
      for _, item in ipairs({ 159, 61 }) do try(pickup, { index = item }, { timeout = 20 }) end
      -- The keyboard sits against the west wall. Use it from the northeast
      -- aisle, clear of the typist and the console's raised solid base.
      path({{240,1040,-168}, {240,1148,-168}, {220,1140,-168}},
        {direct = true, radius = 8, fight = false, timeout = 15})
      use({index = 186}, {hold = true, fight = false})
      wait_until(function() return dk3.mover { index = 255 } == "open" end, { timeout = 20, reason = "big door open" })
    end },
    { "lasers", function()
      -- Inmates come through the big door; the lightning box over the far
      -- end of the laser corridor kills its beams and opens the floor.
      -- The inmate past the beams (250 health, a slow laser of his own)
      -- comes once they die: met from the far side of the console room, at
      -- the range his laser takes long to cross.
      shoot { index = 125 }
      move({ 200, 1100, -168 }, { timeout = 20 })
      try(function()
        kill({ index = 167 }, { hold = true, radius = 1200, timeout = 60, arena = { { 120, 980 }, { 300, 1180 } } })
      end)
    end },
    { "floor drop", checkpoint = true, function()
      -- The opened floor beyond the dead beams drops to the level below
      -- (the area graph has that floor in place); its packs, then the card.
      wait_until(function() return dk3.mover { index = 208 } == "open" end, { timeout = 20, reason = "laser floor open" })
      move({ -144, 1180, -168 }, { radius = 24, timeout = 30 })
      move({ -144, 1250, -270 }, { direct = true, radius = 32, timeout = 10 })
      try(pickup, { index = 263 }, { timeout = 30 })
      try(pickup, { index = 219 }, { timeout = 20 })
      use { index = 33 }                     -- the hatch up the stairs
      -- The panel turns slowly (speed 25) and a strafe under a turning panel
      -- is swept back down the stairs it just climbed: climb once it is flat
      -- out of the way. (Routing says the stairs are shut until then.)
      wait_until(function() return dk3.mover { index = 209 } == "open" end,
                 { timeout = 30, reason = "hatch open" })
    end },
    { "pit room", checkpoint = true, function()
      -- West past the octagon and down the stairs south to the catwalk that
      -- ends short of the round pit room's outer walkway: jumped across
      -- (walked off slowly, the gap takes the player), then over the south
      -- bridge and round the inner ring to the button by the lift that
      -- opens the north door.
      move({ -404, 1328, -152 }, { timeout = 90 })
      try(kill, {index = 166}, {hold = true, weapon = 2, timeout = 20})
      -- Use the authored rim corridor; the generic area route can select
      -- the deep pit below the removed floor as a shortcut.
      nodepath({-960,820,-232}, {timeout = 40})
      move({ -960, 860, -232 }, { direct = true, radius = 16, timeout = 10 })
      try(leap, { -960, 885, -232 }, { -960, 990, -280 })
      local _, _, z = dk3.position()
      expect(z < -270 and z > -300, "on the pit's outer walkway")
      path({ { -960, 1009, -280 }, { -960, 1060, -296 }, { -960, 1150, -296 }, { -1113, 1209, -296 }, { -1158, 1249, -296 } },
           { direct = true, radius = 24, timeout = 20 })
      use { index = 179 }
      -- Two packs on the ring's east side, for the fights at the lift ahead.
      try(pickup, { index = 256 }, { timeout = 20 })
      try(pickup, { index = 226 }, { timeout = 20 })
    end },
    { "card", checkpoint = true, function()
      -- North through the door it opened, west and round to the passage
      -- south to the lift: its switch starts the machinery in the passage
      -- (charges blow the way over the block). The lift (a train: a button
      -- at its foot, another on board) goes up to the cell keycard's floor.
      nodepath({index = 198}, {standoff = 96})
      use { index = 198 }                    -- the console's operate button
      wait(5)
      use { index = 133 }                    -- the lever the broken machinery bared
      -- Guards and inmates hold the lift's top: everything this floor holds
      -- first -- two health packs and a box beside them, and the shells and ion
      -- cells by the west wall, the cycler's last refill before the lift.
      for _, pack in ipairs({ 409, 68, 67, 156, 212, 158 }) do try(pickup, { index = pack }, { timeout = 20 }) end
      wait(2)
      -- The last cells sit above a crate. Step back onto the console landing
      -- before asking the area graph for the lower door; its nearest node
      -- from the pickup lies inside the crate beneath the player's feet.
      move({-1792,2012,-248}, {direct = true, radius = 8,
        vertical_radius = 16, fight = false, timeout = 15})
      -- Under the jammed door it raised part way, crawling.
      move({ -1680, 1824, -296 }, { radius = 24, timeout = 30 })
      move({ -1632, 1824, -296 }, { direct = true, crouch = true, radius = 16, timeout = 15 })
      move({ -1580, 1824, -296 }, { direct = true, crouch = true, radius = 16, timeout = 15 })
    end },
    { "lift", checkpoint = true, function()
      -- An inmate and two guards wait at the top. First the mega shield
      -- behind the low fence here (a shotcycler jump over it, shells there
      -- for the jump back).
      if dk3.ammo(4) > 0 then
        move({ -1462, 1790, -296 }, { timeout = 30 })
        -- The fence top is real footing. Land there first, then step down
        -- behind it; demanding a single landing beyond it abandoned the
        -- shield even after the jump had successfully reached its top.
        if try(blastjump, { -1462, 1858, -296 }, { -1462, 1896, -224 }) then
          move({-1462,1936,-280}, {direct = true, radius = 12, timeout = 10})
          try(pickup, { index = 94 }, { timeout = 10 })
          try(pickup, { index = 132 }, { timeout = 10 })
          try(blastjump, { -1462, 1925, -280 }, { -1462, 1896, -224 })
          move({-1462,1830,-296}, {direct = true, radius = 12, timeout = 10})
          move({ -1462, 1800, -296 }, { timeout = 20 })
        end
      end
      use { index = 357 }
      ride { index = 173 }
      -- Fought on the landing the cage carried the bot up to (its walls are
      -- cover), the inmate by the landing first. The arena keeps the chase on
      -- this floor: the shaft is a fall of two hundred units, and a rider
      -- carried back down has to call the cage down and ride again -- ride
      -- waits clear of a lift above it instead of chasing it, and a cage with
      -- nobody under it does not come back down on its own.
      for _ = 1, 3 do
        try(function() kill({ index = 64 }, { hold = true, timeout = 30 }) end)
        try(function()
          clear { radius = 700, timeout = 45, hold = true, arena = { { -2100, 1300 }, { -1380, 1620 } } }
        end)
        local _, _, z = dk3.position()
        if z >= -100 then break end
        use { index = 357 }
        ride { index = 173 }
      end
      local _, _, z = dk3.position()
      expect(z >= -100, "on the lift's upper landing")
    end },
    { "red room", checkpoint = true, function()
      -- Down the hall to the red room where Superfly hangs: his scene.
      touch { index = 50 }
      wait_until(function() return dk3.mode() == "normal" end, { timeout = 120, reason = "scene over" })
      try(function() clear { radius = 600, timeout = 30 } end)
    end },
    { "keycard", checkpoint = true, function()
      -- The power box near the ceiling, where the wires from the Mishima
      -- logo sign lead: shot, it blows the sign open on the prison keycard.
      shoot { index = 88 }
      pickup { index = 99 }
    end },
    { "superfly", checkpoint = true, function()
      -- Back to Superfly with the card: Hiro frees him, the door on opens.
      touch { index = 412 }
      wait_until(function() return dk3.mode() == "normal" end, { timeout = 120, reason = "scenes over" })
    end },
    { "out", checkpoint = true, function()
      -- Through the door that opened: inmates and guards hold the room
      -- before the exit; its packs (two up the ramp) after the fight.
      -- Superfly (unarmed, and the level is lost with him) waits outside.
      move({ -2150, 1504, -24 }, { timeout = 60 })
      dk3.sidekick("all", "stay")
      weapon(2)
      if not dk3.visible {index = 267} then
        move({-2200,1504,-24}, {direct = true, radius = 8, weapon = 2, timeout = 12})
      end
      kill({index = 267}, {hold = true, weapon = 2, timeout = 45,
        arena = {{-2232,1456},{-2144,1552}}})
      move({ -2240, 1504, -24 }, { timeout = 30 })
      try(function() clear { radius = 900, timeout = 60 } end)
      for _, pack in ipairs({ 211, 276, 201, 202 }) do try(pickup, { index = pack }, { timeout = 20 }) end
      dk3.sidekick("all", "stay")
      exit "e1m4a"
    end },
  }(visit, resumed)
end)

-- Crematorium, part 1: through the hall and the yard outside to the control
-- room's console (past the bar gate Superfly cannot duck under, and the
-- catwalk): its left keypad opens the loading dock, its right one the bar
-- gate for Superfly. Down the dock's ramp to part 2, Superfly along.
level("e1m4a", function(visit, resumed)
  if visit > 1 then return exit "e1m4b" end
  return stages {
    { "hall", function()
      -- Superfly is unarmed: he waits while the guards on the stairs are
      -- dealt with, then takes the ion blaster lying in the room.
      dk3.sidekick("all", "stay")
      try(clear, {radius = 350, hold = true, timeout = 25,
        arena = {{-656,280},{-480,416}}})
      try(companion_take, { index = 32 }, "superfly")
      wait(4)
      dk3.sidekick("all", "follow")
    end },
    { "console", checkpoint = true, function()
      nodepath({index = 285}, {standoff = 64})
      -- Open the security-room entrance explicitly before selecting its
      -- keypad trigger; the trigger's approach can choose the sealed face.
      use({index = 33}, {timeout = 60})
      touch { index = 285 }                  -- the left keypad lights up
      use { index = 283 }                    -- loading dock door
      touch { index = 115 }
      use { index = 119 }                    -- bar gate
      dk3.sidekick("all", "follow")
    end },
    { "dock", checkpoint = true, function()
      -- The way out runs down into a hall under walkways held by guards (and
      -- a cambot): Superfly waits while it is cleared, takes the health by
      -- the stairs, and comes along to the door.
      dk3.sidekick("all", "stay")
      -- Return through the control room's western security door and along
      -- the catwalk. The loading dock is beyond the room's solid east wall.
      move({-1040,-616,24}, {direct = true, radius = 8})
      use({index = 33}, {timeout = 20})
      move({-1160,-636,24}, {direct = true, radius = 8})
      nodepath({ -3, -719, -36 })
      move({ -3, -719, -36 }, { radius = 48, timeout = 40 })
      try(function() clear { radius = 700, timeout = 60 } end)
      move({ 300, -928, -100 }, { timeout = 60 })
      try(function() clear { radius = 700, timeout = 60 } end)
      dk3.sidekick("all", "follow")
      -- The landing is more than128 units below this station, so the
      -- bounded generic recovery helper intentionally leaves it out.
      -- Return by the actual stairs before entering the next firefight.
      if dk3.health() < 80 then try(recharge, {index = 54}, {timeout = 60}) end
      tend(1600, 0.9)
      try(regroup, 250, 90)
      exit "e1m4b"
    end },
  }(visit, resumed)
end)

-- Crematorium, part 2: the keypad by the entrance opens the furnace hall;
-- its console runs the conveyor, and a shot at the smoking weak spot on the
-- pipe in the central recess floods it until the fan shorts out and blows
-- the conveyor door open. Beyond: a lift, a vent under the floor, beams over
-- a pit, and the control box over a keypad that opens the way on.
level("e1m4b", function(visit, resumed)
  local function leave_recess()
    if z() >= -200 then return end
    -- The supplied corridor places the body against the return climb. The
    -- area's approach stops short of it and cannot climb the northern rim.
    dk3.sidekick("all", "stay")
    nodepath({915,-1313,-152}, {fight = false, timeout = 30})
    expect(z() > -200, "out of the central recess before the pipe floods it")
    dk3.sidekick("all", "follow")
  end
  local function east_rim()
    if x() >= 1450 then return end
    path({{1064,-1296,-152},{1400,-1296,-152},{1528,-1296,-134}},
      {direct = true, radius = 8, fight = false, timeout = 20})
  end
  return stages {
    { "hall", function()
      -- Superfly waits at the corridor's far end while the hall beyond the
      -- garage door (guards, a turret on its ceiling) is cleared.
      dk3.sidekick("all", "stay")
      weapon(2, {fight = false})
      use { index = 287 }
      move({700,-930,-152}, {direct = true, radius = 12, fight = false})
      -- The turret first: from its ceiling it sees down the corridor to him.
      try(shoot, { index = 127 }, { timeout = 20, weapon = 2, hold = true,
        arena = {{680,-960},{720,-900}} })
      try(function() clear { radius = 900, timeout = 60 } end)
      -- The garage door may have closed again: open it from this side (its
      -- other button) for Superfly, and wait for him; then the health about
      -- the hall is his.
      -- (It is slow and shuts again soon: go back through to him and come
      -- through together.)
      dk3.sidekick("all", "follow")
      if not try(regroup, 250, 3) then
        try(use, { index = 288 }, { timeout = 15 })
        try(move, { 610, -930, -152 }, { timeout = 30 })
        try(regroup, 120, 20)
        try(use, { index = 287 }, { timeout = 15 })
        try(move, { 780, -930, -152 }, { timeout = 30 })
        try(regroup, 200, 30)
      end
      tend(1200, 0.8)
    end },
    { "stock", function()
      -- Before the fight past the conveyor: the sidewinder and rockets in
      -- the small room by the entrance, its health station, and the
      -- chromatic armor behind the grate in the central recess (before the
      -- pipe floods the recess with charged water).
      try(pickup, { index = 91 }, { timeout = 40 })
      try(pickup, { index = 90 }, { timeout = 20 })
      try(pickup, { index = 500 }, { timeout = 20 })
      try(recharge, { index = 130 })
      local armour = dk3.entity {index = 86}
      if armour and armour.visible and armour.wanted ~= false then
        try(shoot, {index = 63}, {hold = true, weapon = 2, fight = false, timeout = 12})
        dk3.sidekick("all", "stay")
        try(pickup, {index = 86}, {timeout = 40})
      end
      try(pickup, { index = 30 }, { timeout = 30 })
    end },
    { "pipe", checkpoint = true, function()
      leave_recess()
      use({index = 245}, {timeout = 30})
      wait_until(function() return dk3.mode() == "normal" end, { timeout = 60, reason = "conveyor scene over" })
      -- Superfly out of the recess with the player before the water comes.
      dk3.sidekick("all", "follow")
      -- The weak section's exposed face points east. The north and west
      -- views meet the intact pipe or rim; fire from this upper east ledge.
      east_rim()
      move({1400,-1296,-152}, {direct = true, radius = 8, fight = false, timeout = 20})
      try(regroup, 200, 30)
      dk3.sidekick("all", "stay")
      weapon(5, {fight = false})
      move({1400,-992,-152}, {direct = true, radius = 4, weapon = 5, fight = false, timeout = 20})
      shoot({index = 176}, {hold = true, weapon = 5, fight = false})
      wait(8)
      move({1528,-992,-134}, {direct = true, radius = 8, fight = false, timeout = 20})
      move({1528,-700,-134}, {direct = true, radius = 8, fight = false, timeout = 20})
      dk3.sidekick("all", "follow")
    end },
    { "on", checkpoint = true, function()
      -- On past the conveyor, up the casket lift, through the vent and over
      -- the beams to the room with two doors: the box at the ceiling, where
      -- the keypad's wires lead, opens the one on.
      -- Superfly follows to the conveyor's door and waits there out of the
      -- fight below; he rejoins once the keypad's box opens the doors.
      dk3.sidekick("all", "follow")
      leave_recess()
      east_rim()
      move({ 1528, -700, -134 }, {radius = 8, timeout = 90}) -- clear the conveyor jamb
      try(regroup, 200, 30)
      dk3.sidekick("all", "stay")
      -- The conveyor descends below the jamb. Route to its actual lower
      -- landing rather than holding an upper point after stepping off it.
      move({ 1592, 700, -510 }, { timeout = 120 })     -- down the conveyor
      try(function() clear { radius = 300, timeout = 40 } end)
      -- The keypad room is reached the long way: the casket lift, the vent
      -- and the hall under the floor, the beams over the pit.
      -- The casket lift: its button is on board.
      ride { index = 146 }
      -- Off its top straight (the area graph knows only the shaft below).
      move({ 1064, 960, -320 }, { direct = true, radius = 24, timeout = 10 })
      move({ 1036, 1005, -320 }, { direct = true, radius = 24, timeout = 10 })
      -- Up the ladder on the north wall, at its west end, and along the lip
      -- under the west wall to the vent's mouth. (Climbing never settles:
      -- the climb is timed.)
      move({ 1035, 1060, -320 }, { direct = true, radius = 16, timeout = 10 })
      move({ 977, 1060, -320 }, { direct = true, radius = 16, timeout = 10 })
      try(move, { 977, 1072, -172 }, { direct = true, radius = 8, timeout = 5 })
      move({ 976, 1000, -216 }, { direct = true, radius = 16, timeout = 10 })
      path({ { 970, 1000, -200 }, { 888, 1010, -392 }, { 902, 1224, -392 },
             { 1177, 1224, -568 }, { 1300, 1224, -568 } }, { timeout = 60 })
      -- Crouched under the floor past both fans, down the hole and over the
      -- beams: the area graph knows the way (the crawl's trigger, just
      -- passed, lowered the block in it).
      try(pickup, { index = 87 }, { timeout = 60 })      -- the health at the hall's end
      move({ 2014, 999, -256 }, { timeout = 240 })
      -- Down through the hole at once: trading shots with the guards below
      -- from its edge only bleeds health (and a held fight there slides
      -- off it); the room's checkpoint is taken on landing, healthy. The
      -- ion blaster in hand: two guards meet the landing at close range.
      try(weapon, 2)
      move({ 1932, 1002, -528 }, { fight = false, timeout = 30 })
    end },
    { "box", checkpoint = true, function()
      -- The room with two doors: its guards, then the box at the ceiling.
      -- (Not the guards' nest to the north: it waits for the way on.)
      try(function() clear { radius = 300, timeout = 30 } end)
      shoot({ index = 383 }, { timeout = 60 })
      dk3.sidekick("all", "follow")
    end },
    { "nest", checkpoint = true, function()
      -- The second door, north: a guards' nest with a ragemaster beyond.
      -- Health first (the box opened the way to the pack by the conveyor),
      -- then open the door and hold the room while they come through it.
      -- Superfly rejoins through the opened doors, then waits in the keypad
      -- room while the nest is cleared.
      recover(0.9, 900)
      -- (The keypad room cleared first: a guard left in it meets him.)
      try(function() clear { radius = 400, timeout = 30 } end)
      dk3.sidekick("all", "follow")
      try(regroup, 250, 60)
      dk3.sidekick("all", "stay")
      move({ 1940, 1120, -528 }, { timeout = 30 })
      try(use, { index = 418 }, { timeout = 20 })
      move({ 1936, 1040, -528 }, { timeout = 20 })
      try(function() clear { radius = 450, timeout = 60 } end)
    end },
    { "ramp", checkpoint = true, function()
      -- From here on Superfly comes along and fights with the player.
      dk3.sidekick("all", "follow")
      recover(0.8, 700)
      try(pickup, { index = 22 }, { timeout = 30 })      -- the shotcycler
      try(pickup, { index = 80 }, { timeout = 30 })      -- rockets
      advance({ 2440, 1295, -499 })
      move({ 2440, 1295, -499 }, { timeout = 90 })
      try(function() clear { radius = 600, timeout = 45 } end)
    end },
    { "up", checkpoint = true, function()
      recover(0.8, 700)
      advance({ 2397, 640, -150 })
      move({ 2397, 640, -150 }, { timeout = 120 })
    end },
    { "tunnels", checkpoint = true, function()
      -- A ragemaster waits where the corridor turns west (340 health, a
      -- crushing reach): run past it into the tunnels (it is slower than a
      -- running player) rather than trade blows with it.
      recover(0.8, 700)
      move({ 2397, 473, -88 }, { fight = false, timeout = 60 })
      move({ 2031, 229, -8 }, { fight = false, timeout = 60 })
      advance({ 1713, 192, 120 })
      move({ 1713, 192, 120 }, { timeout = 120 })
    end },
    { "loop", checkpoint = true, function()
      -- The way on to the left of the intersection, south through the trash
      -- doors, the hall of guards and ragemasters, the far doors.
      recover(0.8, 700)
      -- Superfly (who has kept his health) takes the ragemasters on while the
      -- player, hurt, keeps back and helps from range.
      dk3.sidekick("all", "follow")
      try(regroup, 250, 60)
      move({ 1312, 95, 120 }, { timeout = 60 })
      kill({index = 111}, {weapon = 2, timeout = 90,
        arena = {{1152,-192},{1392,160}}})
      move({ 1312, -1300, 120 }, { timeout = 180 })
      try(function() clear { radius = 500, timeout = 45 } end)
    end },
    { "coffins", checkpoint = true, function()
      -- Up the steps (the trip there opens the blockers below) to the coffin
      -- room: its grate by the floor, the shaft, the drop and the ladder up.
      recover(0.8, 700)
      move({ 1312, -1440, 120 }, { timeout = 60 })
      move({ 1226, -1616, 192 }, { timeout = 60 })
      -- Enter the actual stair trigger before turning toward the grate.
      -- A broad movement tolerance can turn north before crossing it and
      -- leave both blockers closed in the lower shaft.
      touch({index = 82}, {direct = true, fight = false})
      wait_until(function() return opened(84)() and opened(404)() end,
        {timeout = 10, fight = false, reason = "stair trigger opens the lower shaft blockers"})
      move({ 1092, -1559, 192 }, { timeout = 60 })
      -- This grate is beside the player and the follower. A distant-combat
      -- blast weapon cannot safely fire here; use a direct ion bolt instead.
      shoot({ index = 94 }, { weapon = 2, hold = true, fight = false, timeout = 15 })
      move({ 820, -1500, 192 }, { timeout = 60 })
      move({ 604, -1308, 128 }, { timeout = 90 })
      move({ 604, -543, 288 }, { timeout = 90 })
      try(function() clear { radius = 500, timeout = 45 } end)
    end },
    { "alley", checkpoint = true, function()
      -- Down into the alley: health and the hosportal, the grate at its end,
      -- the guards behind it; the door on the right (the button by it) opens
      -- the short way back for Superfly.
      move({ 783, -452, 128 }, { timeout = 60 })
      try(pickup, { index = 76 }, { timeout = 20 })
      try(pickup, { index = 69 }, { timeout = 20 })
      try(recharge, { index = 410 })
      try(shoot, { index = 95 }, { timeout = 30 })
      try(function() clear { radius = 500, timeout = 45 } end)
      try(use, { index = 358 }, { timeout = 30 })
    end },
    { "out", checkpoint = true, function()
      -- Superfly comes the long way round (the keypad room, the nest, the
      -- ramp, the tunnels); the juncture door shuts a few seconds after
      -- its button: press it again until he is through.
      dk3.sidekick("all", "follow")
      for _ = 1, 40 do
        if try(regroup, 300, 6) then break end
        try(use, { index = 358 }, { timeout = 10 })
      end
      exit("e1m4c")
    end },
  }(visit, resumed)
end)

-- Crematorium, part 3: through the halls to the small study; the vent above
-- its bookcase (reached from the table by the sign and the lamp on the west
-- wall) runs over the room below, and dropping through the grate in its
-- floor opens the doors on the way to the incinerator and the lift down.
level("e1m4c", function(visit, resumed)
  if visit > 1 then return exit "e1m5a" end
  return stages {
    { "halls", function()
      dk3.sidekick("all", "follow")
      advance({ -800, 2000, 24 })
      move({ -800, 2000, 24 }, { timeout = 240 })
      try(function() clear { radius = 500, timeout = 60 } end)
    end },
    { "study", checkpoint = true, function()
      -- Superfly cannot climb after the player: he waits here and comes
      -- round by the doors the drop opens.
      try(function() clear { radius = 500, timeout = 45 } end)
      dk3.sidekick("all", "stay")
      -- Table, sign, lamp, bookcase: the last two are narrow ledges a
      -- running jump carries the player past, so those are short hops.
      -- A fall puts the player back on the floor: climb again.
      for _ = 1, 3 do
        move({ -806, 1775, 24 }, { timeout = 60 })
        try(leap, { -812, 1775, 24 }, { -850, 1775, 54 })
        try(leap, { -852, 1790, 54 }, { -860, 1820, 96 })
        try(leap, { -860, 1840, 96 }, { -860, 1880, 128 }, { pace = 0.25 })
        try(leap, { -862, 1886, 128 }, { -860, 1950, 152 }, { pace = 0.25 })
        local _, _, z = dk3.position()
        if z > 140 then break end
      end
      move({ -858, 2060, 152 }, { direct = true, radius = 24, timeout = 10 })
      -- The grate is now within glove reach. Break it from the bookcase
      -- before entering: an optional shot from below can leave it intact,
      -- and the final walk then stops against its solid face.
      shoot({index = 69}, {weapon = 1, hold = true, fight = false, timeout = 20})
      move({ -915, 2080, 168 }, { direct = true, radius = 24, timeout = 10 })
    end },
    { "vent", function()
      -- Up the vent and round to the grate in its floor over the room
      -- below (no checkpoint up here: healing would go back down).
      move({ -576, 2430, 328 }, { timeout = 90 })
      shoot({ index = 70 }, { timeout = 30, weapon = 2 })
      move({ -576, 2368, 40 }, { direct = true, timeout = 30 })
      try(function() clear { radius = 500, timeout = 60 } end)
    end },
    { "out", checkpoint = true, function()
      dk3.sidekick("all", "follow")
      try(regroup, 250, 120)
      -- The final door is at the bottom of the caged train. Board and use
      -- its carried panel rather than routing to the exit far below it.
      move({-1200,1648,112}, {timeout = 90, weapon = 2})
      move({-1320,1648,112}, {direct = true, radius = 12, timeout = 30, weapon = 2})
      ride({index = 31}, {timeout = 120})
      progress("e1m5a")
    end },
  }(visit, resumed)
end)

-- Processing, part 1: the hall west of the locked door, the windows over
-- the pool, the rocks and the tunnel to the flooded room under the far side
-- of the door; its ladder, the loop round the shaft and the ladder up through
-- the grate behind the door. The control box over it removes the plates that
-- keep the door shut, and Superfly comes through.
level("e1m5a", function(visit, resumed)
  if visit > 1 then return exit "e1m5b" end
  return stages {
    { "hall", function()
      -- (Nothing is cleared here: what is heard beyond the locked door is
      -- out of reach, and chasing it ends in a niche off the floor.)
      dk3.sidekick("all", "follow")
      -- The first room's ammunition (ion packs, shells, rockets in its far
      -- corner) and station: the pool and the shafts after it have little.
      for _, item in ipairs({ 83, 2, 84 }) do try(pickup, { index = item }, { timeout = 30 }) end
      recover(0.9, 900)
      -- The hall up the stairs is held by a deathsphere, a venomvermin and
      -- two laser turrets: stop and fight each as it shows.
      move({ -1192, 2270, -816 }, { timeout = 240, cautious = true, weapon = 2 })
      tend(800, 0.8)
    end },
    { "pool", checkpoint = true, function()
      -- The door will not open from here: Superfly waits in the hall.
      -- Finish visible entrance defenders before turning away to break
      -- the window and swim; arrival alone does not clear their fire lanes.
      for _, index in ipairs({62,95,323}) do
        local foe = dk3.entity {index = index}
        if foe and (foe.health or 0) > 0 and dk3.visible {index = index} then
          kill({index = index}, {hold = true, weapon = dk3.ammo(5) > 0 and 5 or 2, timeout = 45})
        end
      end
      recover(0.9, 900)
      -- The guide's floor-niche secret supplies the armour for the pool and
      -- exposed upper hall. Open its paired panels with the actual control,
      -- collect the shield below, then climb its supplied east-wall ladder.
      local shield = dk3.entity {index = 57}
      local _, _, armour = dk3.health()
      if shield and shield.visible and (armour or 0) < 200 then
        -- Park the escort in the cleared eastern hall, away from the shot
        -- into this tiny panel. Regrouping beside the panel blocks its lane.
        move({-1192,2270,-816},{weapon=2,radius=8,vertical_radius=16})
        point_at({-1000,2270,-816},{fight=false})
        dk3.sidekick("all", "come")
        wait_until(function()
          local buddy=dk3.entity{class="superfly"}
          return not buddy or buddy.x > -1260
        end,{timeout=45,fight=true,stance={-1192,2270,-816},around={0,0,0},
          reason="Superfly clears the secret panel's western firing lane"})
        dk3.sidekick("all", "stay")
        -- Face the narrow niche squarely from the lower hall; a diagonal
        -- from the window corner meets the raised step beside its opening.
        move({-1440,2240,-816}, {direct = true, crouch = true, radius = 1, vertical_radius = 16,
          fight = false, timeout = 15})
        -- A reflected ion bolt from this low panel returns into the shooter.
        shoot({index = 59}, {weapon = 4, crouch = true, hold = true, fight = false,
          around = {-1440,2290,-832}, timeout = 12})
        wait_until(function() return opened(58)() and opened(324)() end,
          {timeout = 10, reason = "both secret floor panels open"})
        move({-1352,2228,-912}, {direct = true, radius = 12,
          vertical_radius = 24, fight = false, timeout = 15})
        pickup({index = 57}, {timeout = 10})
        local clearance = dk3.trace({-1308,2228,-928}, {-1308,2228,-832}, true)
        log("niche climb clearance: " .. clearance.class .. " #" .. clearance.index .. " z=" .. clearance.z)
        move({-1308,2228,-832}, {direct = true, settle = false,
          radius = 4, vertical_radius = 8, fight = false, timeout = 15})
        move({-1256,2228,-816}, {direct = true, radius = 8,
          vertical_radius = 16, fight = false, timeout = 12})
        dk3.sidekick("all", "follow")
      end
      -- Break the window's east end, clear of Superfly.
      dk3.sidekick("all", "stay")
      shoot({ index = 111 }, { timeout = 30, weapon = 2, around = { -990, 2340, -752 } })
      -- The hall's eye height is below the sill. Get onto its forty-unit
      -- step before looking down at the pool's creatures.
      move({-1177,2340,-776}, {direct = true, radius = 8, vertical_radius = 8,
        fight = false, timeout = 20})
      -- The guide clears the airborne cambots from the window, then uses
      -- the glove or Shotcycler in the water. Rockets aimed down past this
      -- sill can strike nearby geometry and blast the shooter.
      for _, foe in ipairs({102,295}) do
        local actor = dk3.entity {index = foe}
        if actor and (actor.health or 0) > 0 and dk3.visible {index = foe} then
          try(kill, {index = foe}, {hold = true,
            arena = {{-1210,2316},{-1144,2360}},
            weapon = 2, timeout = 15})
        end
      end
      weapon(dk3.ammo(4) > 0 and 4 or 1)
      move({ -1177, 2471, -1160 }, { direct = true, fight = false,
        radius = 24, vertical_radius = 24, timeout = 30 })
      for _, foe in ipairs({99,100}) do
        try(kill, {index = foe}, {weapon = dk3.ammo(4) > 0 and 4 or 1, timeout = 25})
      end
    end },
    { "tunnel", checkpoint = true, function()
      -- Out of the water (what swims here is fought from the rocks), up the
      -- rocks to the last before the gap over the waterfall's pool, a
      -- running jump across it, and a short hop from the far rock's south
      -- end into the pipe's mouth across a narrow channel. A miss lands in
      -- the water, whence the only way back is round the rocks again.
      local function across()
        -- Full swimming pace is needed against the pool's current; the
        -- following precise stroke owns braking onto the rock.
        move({ -700, 2930, -1020 }, {radius = 8, vertical_radius = 16,
          timeout = 120, cautious = false, pace = 1, weapon = dk3.ammo(4) > 0 and 4 or 0})
        move({ -700, 2930, -1020 }, {direct = true, radius = 8, vertical_radius = 16,
          timeout = 15, fight = false, pace = 0.35})
        try(clear, {radius = 500, timeout = 10, hold = true,
          weapon = dk3.ammo(2) > 0 and 2 or 0,
          arena = {{-732,2908},{-668,2952}}})
        -- Still, on the jump's line, before the run-up (momentum from the
        -- climb carries the player off the rock's east edge); off the flat
        -- before the rock's lip (running down it leaves the ground before
        -- any jump), to the far rock's tip.
        wait(0.5)
        move({ -622, 2930, -1026 }, { direct = true, radius = 8, timeout = 15, fight = false, pace = 0.35 })
        -- Leave enough supported run-up to accelerate before the lip.
        -- The landing's near shoulder is closer than its summit.
        move({ -618, 2900, -1031 }, { direct = true, radius = 4, vertical_radius = 8,
          timeout = 15, fight = false, pace = 0.3 })
        wait(0.3)
        if not try(leap, { -618, 2858, -1038 }, { -582, 2688, -1043 }, {fight = false, pace = 1}) then return false end
        move({ -566, 2534, -1040 }, { direct = true, radius = 12, timeout = 10, fight = false })
        move({ -600, 2575, -1052 }, { direct = true, radius = 8, timeout = 10, fight = false })
        wait(0.3)
        -- Slowly: a full jump's head meets the pipe's upper lip; at this
        -- pace it tops out over the channel and is below the lip by the
        -- mouth.
        return try(leap, { -600, 2530, -1052 }, { -604, 2436, -1048 }, { pace = 0.4, fight = false })
      end
      local inside = false
      for _ = 1, 4 do
        local reached = false
        if try(function() reached = across() end) and reached then inside = true break end
      end
      if not inside then error(dk3.where() .. ": tunnel: the pipe's mouth was never reached", 0) end
      -- Its mouth lowers the door on the shaft above the flooded room the
      -- pipe leads to.
      move({ -612, 2300, -1048 }, { direct = true, crouch = true, radius = 16, timeout = 20 })
      try(function() clear { radius = 500, timeout = 45 } end)
      -- The room's health and rockets: the hall behind the locked door is
      -- under a turret, a deathsphere and a guard when the player comes up.
      try(pickup, { index = 72 }, { timeout = 20 })
      try(pickup, { index = 73 }, { timeout = 20 })
      -- Up the ladder in its east corner to the ledge by that door (the
      -- area graph has only the way down). Climbing never settles: timed.
      if z() > -1000 then
        -- A guard/pack detour can leave the player on the south wall's
        -- narrow step. Clear that wall westward before returning to the
        -- actual ladder in the north-east corner of the flooded room.
        move({-640,2136,-1064}, {direct = true, radius = 12,
          vertical_radius = 24, fight = false, timeout = 15})
      end
      move({ -544, 2205, -1064 }, { direct = true, radius = 16, timeout = 20 })
      try(move, { -544, 2205, -900 }, { direct = true, radius = 8, timeout = 6, fight = false })
      move({ -530, 2184, -928 }, { direct = true, radius = 24, timeout = 10 })
    end },
    { "shaft", checkpoint = true, function()
      -- Round the loop to the ladder under the grate behind the locked door:
      -- east through the lowered door, south, west and north again (from
      -- the ledge itself the area graph finds no way).
      path({ { -500, 2184, -928 }, { -290, 2184, -928 }, { -290, 1937, -928 },
             { -704, 1937, -928 }, { -699, 2180, -928 } },
        {direct = true, radius = 24, timeout = 40, weapon = 4})
      try(kill, { index = 70 }, { timeout = 20, weapon = 4 }) -- close vermin: no ricocheting bolts
      -- Right under the grate (from the shaft's edge it is out of sight).
      move({ -699, 2228, -928 }, { direct = true, radius = 8, timeout = 10 })
      shoot({ index = 112 }, { timeout = 10, hold = true, weapon = 1 })
      -- The control box is visible through the opened grate. Breaking it
      -- from the shaft removes the plates before the exposed climb; the
      -- deathsphere above the solid hall floor cannot be shot from here.
      try(shoot, {index = 325}, {weapon = 4, hold = true, fight = false, timeout = 8})
      dk3.sidekick("all", "follow")
      try(regroup, 200, 15)
      weapon(2, {fight = false})
      -- Up the ladder on the shaft's west wall without firing: bolts loosed
      -- up the narrow shaft ricochet back down it. Out into the hall above,
      -- then fight.
      try(move, { -716, 2228, -808 }, { direct = true, radius = 12, timeout = 8, fight = false })
      move({ -745, 2228, -816 }, { direct = true, radius = 16, timeout = 10 })
      -- At once (the hall's guard and the turret high on its south wall are
      -- on the way): the control box over the door, whose wires hold its
      -- plates shut, and the door; back through it to Superfly, and the
      -- guard is fought there by both.
      shoot({ index = 325 }, { timeout = 30, fight = false, weapon = 4, hold = true })
      -- Breaking the box removes the blocking plates. The remaining door
      -- is separately operated; direct movement cannot ask navigation to use it.
      use({index = 48}, {hold = true, fight = false, timeout = 8})
      move({-744,2224,-816}, {direct = true, radius = 4, timeout = 5, fight = false})
      move({ -840, 2224, -816 }, { direct = true, radius = 12, timeout = 10, fight = false })
      dk3.sidekick("all", "follow")
      -- Keep evasions on the west hall, away from the open ladder shaft.
      -- Include the far deathsphere before crossing back into its volley.
      try(function() clear { radius = 900, timeout = 45, hold = true,
        arena = {{-1040,2208},{-800,2240}},
        weapon = dk3.ammo(5) > 0 and 5 or 2 } end)
    end },
    { "door", checkpoint = true, function()
      -- East along the hall with Superfly (its choppers, guards, a
      -- venomvermin), fighting as each shows, to the station by its far door.
      dk3.sidekick("all", "follow")
      try(regroup, 250, 90)
      -- These leaves retract along the hall. Their open bodies still cover
      -- y2248; the compiled waypoint at y2234 overlaps one by the player hull.
      -- Cross the clear southern part of each doorway before the station.
      path({{-840,2224,-816},{-744,2224,-816},{-512,2224,-816},
            {-256,2224,-816},{0,2224,-816},{128,2224,-816},{200,2224,-816}},
        {direct = true, radius = 12, timeout = 90, cautious = true})
      try(recharge, { index = 91 })
      tend(800, 0.8)
    end },
    { "out", checkpoint = true, function()
      -- On past the fan and the guards to the Mishima door (the exit), a
      -- leg at a time, back to the station between legs while it has
      -- charge: part 2 opens on a guard, a turret and deathspheres with
      -- no health before the stairs down, so arrive whole.
      dk3.sidekick("all", "follow")
      for _, point in ipairs({ { 240, 1700, -760 }, { 330, 1596, -816 }, { 968, 1560, -816 }, { 968, 1420, -752 } }) do
        move(point, { timeout = 180, cautious = true })
        recover(0.95, 1300)
      end
      progress("e1m5b")
    end },
  }(visit, resumed)
end)

-- Processing, part 2: the catwalk and its turret, the spiral stairs down,
-- the rooms south and west to the stairs up to the console that unlocks the
-- freezer door; back to the freezer and on to the Mishima logo (the exit).
-- Deathspheres hold most rooms: each leg is fought cautiously, with the
-- stations at the bottom of the stairs and by the south room's stairs.
level("e1m5b", function(visit, resumed)
  if visit > 1 then return exit "e1m6a" end
  return stages {
    { "catwalk", function()
      -- Hold the arrival corridor first: its guard, the catwalk's
      -- deathspheres and a venomvermin come to it one by one (chased, they
      -- are met all at once with the turret at the catwalk's end).
      dk3.sidekick("all", "follow")
      try(function() clear { radius = 900, hold = true, timeout = 15, arena = { { 1220, 1300 }, { 1300, 1445 } } } end)
      -- The corridor's door opens to use only.
      try(use, { index = 30 }, { timeout = 15 })
      for _, item in ipairs({ 91, 92 }) do try(pickup, { index = item }, { timeout = 20, fight = false }) end
      move({ 1460, 1887, -608 }, { timeout = 120, cautious = true })
      try(kill, { index = 45 }, { hold = true, timeout = 30 })   -- the catwalk's turret
      -- The two deathspheres by the catwalk's far door: Superfly's
      -- shotcycler takes them on while the player holds mid-catwalk and
      -- shoots what comes into sight.
      for _, sphere in ipairs({ 361, 78 }) do
        for _ = 1, 3 do
          if try(sic, { index = sphere }, "superfly", 20) then break end
          wait(1)
        end
        -- A blind stand cannot turn into a chase off this upper catwalk.
        try(kill, { index = sphere }, {hold = true, timeout = 20,
          arena = {{1416,1880},{1464,1944}}})
      end
      move({ 1949, 1952, -648 }, { timeout = 120, cautious = true })
    end },
    { "spiral", checkpoint = true, function()
      dk3.sidekick("all", "follow")
      nodepath({2228,1785,-896}, {timeout = 180, cautious = false})
      try(recharge, { index = 104 })
      try(pickup, { index = 103 }, { timeout = 20 })
      tend(800, 0.8)
    end },
    { "south", checkpoint = true, function()
      dk3.sidekick("all", "follow")
      move({ 2304, 1300, -896 }, { timeout = 120, cautious = true })
      try(pickup, { index = 87 }, { timeout = 20 })
      -- The optional ammunition can leave us west of this hall. Follow
      -- the supplied ground corridor rather than its disconnected area.
      nodepath({ 2281, 623, -896 }, { timeout = 180, cautious = true })
      try(recharge, { index = 75 })
      tend(800, 0.8)
    end },
    { "console", checkpoint = true, function()
      -- West through the side door, up the stairs north to the hall over
      -- the console room, down into it.
      dk3.sidekick("all", "follow")
      move({ 1920, 536, -896 }, { timeout = 120, cautious = true })
      move({ 1760, 862, -896 }, { timeout = 120, cautious = true })
      -- Up the steps west (door slabs a button lowers into a secret: on
      -- them the area graph places the player in the vent below).
      -- North along the corridor over the secret vent (above it the area
      -- graph places the player in the vent too) to past its end.
      path({ { 1640, 850, -840 }, { 1563, 945, -826 }, { 1620, 955, -808 }, { 1632, 1185, -808 } },
           { direct = true, radius = 24, timeout = 15 })
      move({ 1644, 1388, -808 }, { timeout = 180, cautious = true })
      -- Two deathspheres and a venomvermin hold the room below the ledge
      -- (two deathspheres' volleys together take a full health in a
      -- second): show at the ledge, fall back down the corridor and fight
      -- them there as they come through it one by one.
      move({ 1640, 1560, -800 }, { direct = true, radius = 16, timeout = 10 })
      for _ = 1, 4 do
        if dk3.hostiles(500, { 1640, 1750, -850 }) == 0 then break end
        try(use, { index = 26 }, { timeout = 8 })
        try(function()
          kill({ class = "monster_deathsphere" }, { around = { 1640, 1750, -850 }, radius = 500, hold = true, timeout = 20,
                 arena = { { 1612, 1530 }, { 1668, 1590 } } })
        end)
        try(function()
          kill({ class = "monster_venomvermin" }, { around = { 1640, 1750, -850 }, radius = 500, hold = true, timeout = 15,
                 arena = { { 1612, 1530 }, { 1668, 1590 } } })
        end)
      end
      -- Down the door-slab steps into the cleared room, the health in the
      -- passage east of it, and across to the console.
      try(use, { index = 26 }, { timeout = 8 })
      path({ { 1640, 1655, -812 }, { 1640, 1730, -848 } }, { direct = true, radius = 24, timeout = 10, fight = false })
      try(pickup, { index = 363 }, { timeout = 40 })
      move({ 1340, 1640, -832 }, { timeout = 60 })
      use({ index = 168 }, { timeout = 60 })
      cinematic()
    end },
    { "soul", checkpoint = true, function()
      -- Back the way the route came (the steps by the vent walked
      -- straight) and east to the stairs short of the freezer: the golden
      -- soul in the secret under their landing, off its edge at a walk
      -- into the slot beneath it.
      dk3.sidekick("all", "follow")
      try(regroup, 300, 60)
      move({ 1632, 1185, -808 }, { timeout = 120, cautious = true })
      path({ { 1620, 955, -808 }, { 1563, 945, -826 }, { 1640, 850, -840 }, { 1760, 862, -896 } },
           { direct = true, radius = 24, timeout = 15 })
      move({ 2342, 336, -808 }, { timeout = 120, cautious = true })
      -- The approach may already descend onto the secret's lower floor.
      -- Continue down to the slot instead of asking it to climb back up.
      move({ 2325, 372, -896 }, { direct = true, radius = 10, timeout = 10, pace = 0.3 })
      path({ { 2327, 330, -896 }, { 2327, 292, -896 }, { 2260, 296, -896 } }, { direct = true, crouch = true, radius = 12, timeout = 10 })
      path({ { 2327, 292, -896 }, { 2331, 360, -896 } }, { direct = true, crouch = true, radius = 12, timeout = 10 })
    end },
    { "freezer", checkpoint = true, function()
      -- The freezer the console unlocked: its inner door opens to use. The
      -- deathsphere over its far side comes to the doorway and is met from
      -- the stair landing (not backed off it: its side drops into a corner
      -- nothing leads out of), where the open door's edge keeps the
      -- lasergat hung mid-room from a clear shot either way; then the
      -- lasergat from just inside, where its lane is clear.
      dk3.sidekick("all", "follow")
      local landing = { { 2645, 380 }, { 2695, 420 } }
      move({2664,416,-736}, {radius = 8, fight = false, timeout = 120})
      dk3.sidekick("all", "stay")
      for _ = 1, 3 do
        try(use, { index = 25 }, { timeout = 8 })
        if try(kill, { index = 364 }, {hold = true, weapon = 2, timeout = 20, arena = landing}) then break end
      end
      tend(800, 0.6)
      for _ = 1, 3 do
        try(use, { index = 25 }, { timeout = 8 })
        move({2736,416,-736}, {direct = true, radius = 4, fight = false, weapon = 2, timeout = 10})
        if try(kill, { index = 44 }, {hold = true, weapon = 2, timeout = 20, arena = { { 2712, 392 }, { 2770, 440 } }}) then break end
      end
      recover(0.9, 600)
      -- Continue inside toward the southern stairs. Returning to the entry
      -- landing can leave the player behind the same door as it closes.
      move({2736,416,-736}, {direct = true, radius = 4, fight = false, timeout = 15})
      dk3.sidekick("all", "follow")
      try(function() clear {radius = 700, hold = true, weapon = 2, timeout = 30,
        arena = {{2720,392},{2784,440}}} end)
      try(pickup, { index = 74 }, { timeout = 30 })   -- the shockwave
    end },
    { "hall", checkpoint = true, function()
      -- South up the freezer's ramp, through the guards' rooms to the use
      -- door into the great hall under the exit. What comes to the doorway
      -- is met there; the rest of the hall (its two deathspheres, the
      -- lasergat on the central pillar, the guard on the floor) mostly
      -- stays put and is hunted one by one, with the health on its floor
      -- between; then up round the walkways to the exit door (the armour
      -- below the exit's corridor is left: the way back up from it is a
      -- ladder).
      dk3.sidekick("all", "follow")
      -- The freezer and guard room have their own use doors. Operate them
      -- in order so the route cannot plan through the closed lower passage.
      use({index = 24}, {weapon = 2, timeout = 90})
      use({index = 23}, {weapon = 2, timeout = 90})
      move({ 2368, -560, -496 }, { timeout = 180, cautious = true })
      use({index = 22}, {hold = true, fight = false, timeout = 8})
      wait_until(opened(22), {timeout = 5, reason = "the hall door fully opens"})
      path({{2360,-560,-496},{2360,-672,-496}},
        {direct = true, fight = false, radius = 8, vertical_radius = 24, timeout = 8})
      local doorway = { { 2320, -740 }, { 2416, -640 } }
      for _ = 1, 2 do
        try(use, { index = 22 }, { timeout = 8 })
        if try(function() clear { radius = 900, hold = true, timeout = 20, arena = doorway } end) then break end
      end
      tend(900, 0.6)
      for _, foe in ipairs({ 113, 366, 46, 114 }) do
        try(kill, { index = foe }, { timeout = 30 })
        recover(0.7, 900)
      end
      for _, item in ipairs({ 70, 69 }) do try(pickup, { index = item }, { timeout = 40 }) end
      progress("e1m6a")
    end },
  }(visit, resumed)
end)

-- Icelab: the decontamination corridor's door opens a while after its
-- button; the sprays along it cycle. The four-way door at its end opens to
-- the blue control card, in the control room past the denied keypads.
-- Through the cryotechs' rooms, down into the lab over the nitrogen pool
-- (across the gap in its walkway): its valve drains the pool, whose floor
-- leads to the lift up to the exit's rooms.
level("e1m6a", function(visit, resumed)
  if visit > 1 then return exit "e1m6b" end
  return stages {
    { "lab", function()
      dk3.sidekick("all", "follow")
      recover(0.8, 900)
      use { index = 64 }
      wait(11)
      for _, foe in ipairs({35,306}) do
        try(kill, {index = foe}, {hold = true, weapon = 2, timeout = 20})
      end
      -- The automatic area path cuts through the freezing trench. The
      -- supplied ground nodes follow the laboratory's upper passage instead.
      nodepath({index = 2}, {standoff = 64, weapon = 2})
      pickup { index = 2 }
      -- The card room's two ion packs supply the plant and the next map's
      -- upper guards. Missing them can leave only the short-range Shotcycler
      -- while those guards fire from beyond its effective range.
      dk3.sidekick("all", "stay")
      for _, pack in ipairs({27,324}) do
        if dk3.ammo(2) < 150 then try(pickup, {index = pack}, {timeout = 15}) end
      end
      dk3.sidekick("all", "follow")
      try(recharge, { index = 29 })   -- the station in the card's room
      use { index = 85 }
    end },
    { "valve", checkpoint = true, function()
      -- The lab's cryotechs spray a freezing fluid at close range. Down the
      -- ladder shaft (the room's way down) to its foot, a floor cut off
      -- from the rest by a gap over the nitrogen: what shows across it is
      -- shot from well back off its edge. Then a running leap over the gap
      -- (the area graph's jump falls short) and the rest held off there.
      dk3.sidekick("all", "follow")
      -- The guide's shells in this upper room supply the fight at the
      -- ladder's foot, where the freezing spray is dangerous at close range.
      if dk3.ammo(4) < 12 then try(pickup, {index = 9}, {timeout = 30}) end
      -- The shells' north alcove exits around its counter. Its westward
      -- area edge runs under the lip and cannot be walked from the pickup.
      if x() > 1520 and x() < 1680 and y() > 400 and y() < 490 then
        move({1640,520,-24}, {direct = true, radius = 8, fight = false, timeout = 12})
      end
      -- The native area route handles the ladder room's north alcove too;
      -- a supplied node immediately south of its wall cannot be approached
      -- by a straight segment from a periodic save on the north side.
      move({1574,305,-24}, {timeout = 90, radius = 16, fight = false})
      -- Leave the party on the upper floor before descending. Waiting until
      -- the run-up lets Superfly enter the shaft and block the departure;
      -- a later injury can also cancel his Stay order there.
      dk3.sidekick("all", "stay")
      move({ 1590, 345, -240 }, { direct = true, radius = 24, timeout = 10 })
      move({ 1600, 300, -240 }, { direct = true, radius = 16, timeout = 10 })
      try(function() kill({ class = "monster_cryotech" }, { around = { 1450, 470, -248 }, radius = 450, hold = true, timeout = 15,
                              weapon = dk3.ammo(4) > 0 and 4 or 2,
                              arena = { { 1580, 230 }, { 1615, 345 } } }) end)
      -- Keep the upper-lab hold until the lower gap is crossed.
      dk3.sidekick("all", "stay")
      -- Let the Shotcycler finish before the run-up; a remaining recoil
      -- impulse in flight can turn this short gap into a fall.
      weapon(2, {fight = false})
      move({1600,220,-240}, {direct = true, radius = 8, weapon = 2, fight = false, timeout = 10})
      for _ = 1, 3 do
        if x() < 1440 then break end
        try(leap, {1548,220,-240}, {1385,220,-240}, {pace = 1, weapon = 2, fight = false})
      end
      -- Keep the party upstairs while the nitrogen gap and lower guards
      -- remain dangerous. They can follow after the valve drains the pool.
      -- North along the west floor, clear of the gap's edge.
      path({ { 1350, 225, -240 }, { 1340, 300, -248 }, { 1340, 407, -248 } }, { direct = true, radius = 20, timeout = 10 })
      -- (Ones not yet roused are not counted hostile: each by name.)
      for _, foe in ipairs({ 7, 104, 6, 8, 351, 352 }) do
        try(kill, { index = foe }, { hold = true, timeout = 15, arena = { { 1320, 380 }, { 1370, 430 } } })
        try(kill, { index = foe }, { timeout = 15 })
      end
      move({ 1380, 560, -248 }, { timeout = 60 })
      try(pickup, { index = 23 }, { timeout = 20 })
      use { index = 97 }
      -- (The rotor seals a shaft of nitrogen: the threshold it was pressed
      --  from fills with gas the moment it turns, two damage a tick. Back
      --  along the way in — the way that was walked — for the lift's run.)
      move({ 1345, 450, -248 }, { direct = true, radius = 40, timeout = 15 })
      wait(15)
      -- The way out is not on this floor: down the ladder shaft at the lab
      -- room's east edge to the plant floor over the nitrogen's water, east
      -- and north round it to the lift, and up in the lift to the rooms the
      -- exit stands in. The area graph reaches every step of that; only the
      -- two door halves closing the exit's corridor (44 seconds to slide,
      -- from the button on their near side) it cannot express, being built
      -- with them shut.
      dk3.sidekick("all", "follow")
      try(regroup, 400, 90)
      move({ 1546, 470, -248 }, { timeout = 45 })
      move({ 1512, 552, -372 }, { timeout = 120 })
      -- Leave this narrow landing along its actual supplied corridor before
      -- fighting the spheres above it. A hunt's sidestep falls into the lower
      -- pocket, which has no way back to this floor.
      nodepath({980,212,-312}, {fight = false})
      -- This sphere meets the next bend at head height. Answer from the
      -- broad landing without a combat strafe toward the lower pocket.
      try(shoot, {index = 345}, {hold = true, weapon = 2,
        fight = false, timeout = 8})
      nodepath({1768,-64,-372}, {fight = false})
      -- The lift stands in a shaft sunk below the plant floor: its deck rests
      -- eight below the lip it travels through, so it is stepped down onto,
      -- not climbed to. (The area graph, compiled without movers, offers the
      -- pit floor under the deck -- hence the ride's own straight step.)
      -- Bolts fired up the confined lift shaft can return to the rider.
      ride({index = 98}, {fight = false})
      move({1852,-176,24}, {direct = true, radius = 8,
        vertical_radius = 16, timeout = 10, fight = false})
      try(kill, {index = 25}, {hold = true, weapon = 2, timeout = 12,
        arena = {{1828,-192},{1876,-152}}})
      recover(0.95, 2000)
      -- The guard has a lane through the doorway. Meet it from the west
      -- jamb before stepping out into its room; reopen if the door shuts.
      for _ = 1, 3 do
        local guard = dk3.entity {index = 59}
        if not guard or guard.health <= 0 then break end
        use({index = 15}, {fight = false, weapon = 2, timeout = 30})
        move({1888,-176,24}, {direct = true, radius = 12,
          vertical_radius = 16, timeout = 8, fight = false})
        try(shoot, {index = 59}, {hold = true, weapon = dk3.ammo(4) > 0 and 4 or 2,
          fight = false, timeout = 4})
      end
      -- The passage is target-operated. Press its west button, then cross
      -- before its short opening expires, without stopping at the near lip.
      if dk3.mover {index = 18} == "closed" or dk3.mover {index = 18} == "closing" then
        use({index = 15}, {fight = false, timeout = 30})
      end
      move({2016,-176,24}, {direct = true, radius = 12,
        vertical_radius = 16, timeout = 10, fight = false})
      move({2035,-228,24}, {direct = true, radius = 8,
        vertical_radius = 16, timeout = 10, weapon = 2})
      -- A mishimaguard and a fatworker hold the landing between the lift and
      -- the button; the mishimaguard by the corridor comes to the noise.
      for _, foe in ipairs({ 308, 307, 167 }) do
        try(shoot, { index = foe }, { hold = true, weapon = 2,
          fight = false, timeout = 12 })
      end
      -- The north guard is behind the west jamb from the first stance.
      -- Step east to the console's own lane and clear him before using it.
      move({2224,-228,24}, {direct = true, radius = 8, weapon = 2, timeout = 15})
      try(kill, {index = 307}, {hold = true, weapon = 2, timeout = 15,
        arena = {{2192,-256},{2260,-208}}})
      recover(0.95, 2400)
      move({ 2035, -228, 24 }, { timeout = 90 })
    end },
    { "departure", checkpoint = true, function()
      -- The short west-button pulse can shut behind Hiro before Superfly
      -- crosses. The return button on this side reopens that same passage.
      local buddy=dk3.entity{class="superfly"}
      if buddy and buddy.x<1990 then
        use({index=338},{fight=false})
        move({2016,-176,24},{direct=true,fight=false,radius=8,vertical_radius=16})
        dk3.sidekick("all","come")
        wait_until(function()
          local follower=dk3.entity{class="superfly"}
          return not follower or follower.x>=1990
        end,{timeout=20,fight=false,stance={2016,-176,24},around={0,0,0},
          reason="Superfly crosses the reopened inner passage"})
      end
      use { index = 75 }
      wait_until(function() return dk3.mover { index = 129 } == "open" and dk3.mover { index = 130 } == "open" end,
                 { timeout = 45, reason = "both corridor leaves finish sliding back" })
      try(regroup, 300, 120)
      move({ 2168, -312, 24 }, { direct = true, radius = 48, timeout = 30 })
      exit "e1m6b"
    end },
  }(visit, resumed)
end)

-- Icelab, part 2: the door on along the walkway opens only from beyond it.
-- The way there is a running drop off the walkway's end onto the round
-- platform standing in the nitrogen, its ladder, and the hatch at the top;
-- the button there opens the door. Superfly waits at the drop (a sidekick
-- following falls short into the nitrogen) and comes through the door.
level("e1m6b", function(visit, resumed)
  if visit > 1 then return exit "e1m6c" end
  return stages {
    { "walkway", function()
      -- Stay on the arrival walkway. The optional megashield is below the
      -- nitrogen pipe; the ordinary return route cuts through the lethal
      -- liquid and is not part of the required departure.
      dk3.sidekick("all", "follow")
      move({ 1650, -1040, 40 }, {timeout = 120, cautious = true})
      dk3.sidekick("all", "stay")
    end },
    { "ramp", checkpoint = true, supplies = false, function()
      -- The guide's locked ramp console releases two deathspheres. The
      -- required route continues along the catwalk to the round platform;
      -- its far-side console later opens the route for Superfly.
      dk3.sidekick("all", "stay")
      -- The guide's second alcove has ammunition and a ladder to the
      -- megashield pipe. Descend its rungs instead of dropping into nitrogen.
      move({1650,-1040,40}, {cautious = true, radius = 12, timeout = 60})
      path({{1650,-1320,104},{1450,-1320,104}},
        {direct = true, radius = 12, weapon = 2, timeout = 20})
      for _, foe in ipairs({16,315}) do
        try(shoot, {index = foe}, {hold = true, weapon = 2, fight = false, timeout = 10})
      end
      -- The packs sit on raised recesses. Reach their edges rather than
      -- driving into the solid lip beneath their centers.
      path({{1360,-1452,104},{1296,-1452,104},{1296,-1532,104},{1360,-1464,104}},
        {direct = true, radius = 4, vertical_radius = 16, fight = false, timeout = 12})
      -- Aim down the shaft from its supported bank. An upper waypoint over
      -- the opening makes the pilot try to stop in midair while descending.
      move({1439,-1500,-208}, {direct = true, settle = false, radius = 1,
        vertical_radius = 8, fight = false, timeout = 15})
      move({1460,-1496,-216}, {direct = true, radius = 8, fight = false, timeout = 10})
      move({2224,-1496,-232}, {direct = true, radius = 8, fight = false, timeout = 15})
      pickup({index = 13}, {direct = true, timeout = 10})
      move({1439,-1500,-216}, {direct = true, radius = 1, fight = false, timeout = 15})
      move({1439,-1500,112}, {direct = true, settle = false, radius = 1,
        vertical_radius = 8, fight = false, timeout = 15})
      move({1360,-1500,120}, {direct = true, settle = false, radius = 8,
        vertical_radius = 24, fight = false, timeout = 10})
      path({{1360,-1320,104},{1650,-1320,104},{1650,-1040,40}},
        {direct = true, radius = 12, fight = false, timeout = 20})
    end },
    { "platform", checkpoint = true, supplies = false, function()
      -- Supply detours leave this narrow catwalk over lethal liquid.
      -- Alone over the platform in the nitrogen: a running drop off the
      -- walkway's end, the ladder, the hatch, the guards in the room above
      -- it, its lift up, and those on the floor at the top; then Superfly
      -- comes round through the ramp door (the door from the walkway to
      -- the hatch room shuts again a moment after its button).
      move({ 1650, -1040, 40 }, {timeout = 120, cautious = true})
      dk3.sidekick("all", "stay")
      move({ 1672, -1060, 40 }, { direct = true, radius = 8, timeout = 10 })
      move({ 1912, -1185, -256 }, { direct = true, radius = 40, timeout = 10, fight = false })
      -- Up the ladder to the hatch over it, opened by hand from the rungs.
      try(move, { 1920, -1149, 38 }, { direct = true, settle = false, radius = 4,
        vertical_radius = 12, timeout = 12, fight = false })
      local function hatch_open()
        return dk3.mover {index = 24} == "open" and dk3.mover {index = 22} == "open"
      end
      for _ = 1, 3 do
        if hatch_open() then break end
        try(move, {1920,-1149,38}, {direct = true, settle = false, radius = 4,
          vertical_radius = 12, fight = false, timeout = 8})
        if not opened(24)() then try(use, {index = 24}, {hold = true, timeout = 6, fight = false}) end
        if not opened(22)() then try(use, {index = 22}, {hold = true, timeout = 6, fight = false}) end
        move({1920,-1149,-16}, {direct = true, settle = false, radius = 1,
          vertical_radius = 16, fight = false, timeout = 8})
        try(wait_until, hatch_open,
          {timeout = 10, fight = false, stance = {1920,-1149,-16}, around = {0,0,0},
            reason = "the hatch leaves clear the ladder"})
        if not hatch_open() then
          log("hatch leaf states: " .. tostring(dk3.mover {index = 24}) .. "," .. tostring(dk3.mover {index = 22}))
        end
      end
      expect(hatch_open(), "both hatch leaves clear the ladder")
      -- The Shotcycler's recoil can throw the player off the rungs when
      -- firing upward. The ion blaster answers the guards without that kick.
      weapon(2)
      -- The rungs end at feet height 64. Step onto the near rim as they
      -- end; waiting for origin 120 here means climbing into empty air.
      move({1920,-1149,88}, {direct = true, settle = false, radius = 1,
        vertical_radius = 1, timeout = 20, weapon = 2})
      -- Keep climbing while moving off the rungs. A held crouch is a
      -- downward ladder command and pulls Hiro back below the open hatch.
      move({1920,-1104,104}, {direct = true, fight = false, radius = 8,
        vertical_radius = 16, timeout = 45, weapon = 2})
      -- Clear the hatch room before turning away to operate its console.
      -- A surviving guard gets a free volley while the player faces it.
      move({1984,-1104,104}, {direct = true, radius = 8, weapon = 2, timeout = 10})
      for _, foe in ipairs({275,274,60}) do
        try(kill, {index = foe}, {hold = true, weapon = dk3.ammo(4) > 0 and 4 or 2,
          timeout = 20, arena = {{1952,-1128},{2008,-1080}}})
      end
      use {index = 61}
      dk3.sidekick("all", "follow")
      try(regroup, 250, 90)
      -- Ride the actual lift before any health pursuit can send the player
      -- off its rising deck. The first guard is close enough for hitscan;
      -- ion bolts can rebound down the confined shaft onto the rider.
      ride({index = 123}, {weapon = dk3.ammo(4) > 0 and 4 or 2, timeout = 60})
      -- Meet the guards at the lift's upper landing by name. A closer sphere
      -- above its roof is not a usable target while they fire down the shaft.
      for _, foe in ipairs({59,276,317}) do
        try(kill, {index = foe}, {weapon = foe == 59 and dk3.ammo(4) > 0 and 4 or 2,
          timeout = 30})
      end
      move({ 1912, -1393, 248 }, { timeout = 60, weapon = 2 })
      for _, foe in ipairs({ 10, 59, 276, 317 }) do try(kill, { index = foe }, { timeout = 25 }) end
      recover(0.8, 600)
      dk3.sidekick("all", "follow")
      try(regroup, 250, 120)
      tend(900, 0.6)
    end },
    -- The long way round to the exit, in legs: east along the gallery and
    -- south, the loop of halls west, the rooms on west to the drop to the
    -- floor below, and north over it to the exit.
    { "east", checkpoint = true, supplies = false, function()
      dk3.sidekick("all", "follow")
      local gallery_defended = false
      nodepath({2383,-1104,344}, {segment_options = function(point)
        if point[1] >= 2350 and point[1] <= 2450 and
            point[2] > -1200 and point[3] >= 328 and point[3] <= 344 then
          if not gallery_defended then
            move({2320,-1104,312}, {direct = true, radius = 8, vertical_radius = 16,
              weapon = dk3.ammo(5) > 0 and 5 or 2, timeout = 20})
            for _, index in ipairs({277,293,294}) do
              local foe = dk3.entity {index = index}
              if foe and (foe.health or 0) > 0 and dk3.visible {index = index} then
                kill({index = index}, {hold = true, timeout = 20,
                  arena = {{2280,-1144},{2340,-1064}},
                  weapon = dk3.ammo(5) > 0 and 5 or 2})
              end
            end
            gallery_defended = true
          end
          return {weapon = dk3.ammo(5) > 0 and 5 or 2}
        end
      end})
      -- The guide's left-hand room supplies armour before the long guard
      -- galleries. Return to the main route after collecting it.
      local armour = dk3.entity {index = 14}
      if armour and armour.visible and armour.wanted ~= false then
        nodepath({index = 14}, {standoff = 64})
        pickup {index = 14}
        nodepath {2383,-1104,344}
      end
      move({ 2383, -1104, 344 }, { timeout = 120, cautious = true })
      move({ 2383, -1900, 344 }, { timeout = 120, cautious = true })
      recover(0.8, 900)
      tend(900, 0.6)
    end },
    { "loop", checkpoint = true, function()
      dk3.sidekick("all", "follow")
      move({ 1504, -1969, 344 }, { timeout = 120, cautious = true })
      -- Fight the stair guards before crawling beneath their fire. Ion
      -- rebounds in this low passage can hit the shooter on the return.
      for _, foe in ipairs({54,62}) do
        try(kill, {index = foe}, {hold = true, timeout = 25,
          weapon = dk3.ammo(4) > 0 and 4 or 2})
      end
      -- Four sixteen-unit treads climb to the 384-unit deck. Stay low
      -- beneath the sloping roof; the old 392 origin put the feet inside it.
      move({1472,-2256,344}, {direct = true, radius = 8, fight = false})
      move({1472,-2440,408}, {direct = true, radius = 8, crouch = true, fight = false})
      move({1472,-2600,408}, {direct = true, radius = 8, crouch = true, fight = false})
      -- Keep the supplied corner above the nitrogen. The area route cuts
      -- across the outer edge when leaving this low stair passage.
      -- Guard291 can stand in this narrow passage. Keep the authored crawl
      -- while answering him, rather than trying to squeeze past his body.
      nodepath({1288,-2936,344}, {crouch = true, weapon = 4, cautious = false})
      -- The next stair has a clear line north, beyond the cryotech's spray.
      -- Keep the fight there: retreating down the stair hides the shot in
      -- its risers and ion rebounds then hit the already wounded shooter.
      move({1288,-2880,376}, {direct = true, radius = 4, vertical_radius = 8,
        crouch = true, fight = false})
      shoot({index = 316}, {hold = true, fight = false, timeout = 30,
        weapon = dk3.ammo(5) > 0 and 5 or 4})
      nodepath({1252,-2111,344}, {timeout = 120})
      recover(0.8, 900)
      tend(900, 0.6)
    end },
    { "west", checkpoint = true, function()
      dk3.sidekick("all", "follow")
      move({ 1121, -2127, 344 }, { timeout = 120, cautious = true })
      move({ -15, -2399, 344 }, { timeout = 120, cautious = true })
      move({ 79, -1747, 344 }, { timeout = 120, cautious = true })
      recover(0.8, 900)
      tend(900, 0.6)
    end },
    { "lower", checkpoint = true, function()
      -- The floor below is held by guards and cryotechs: Superfly waits
      -- while the bot goes down and clears it, then comes after.
      dk3.sidekick("all", "stay")
      for _, foe in ipairs({ 318, 144, 101, 50, 49, 48 }) do
        try(kill, { index = foe }, {weapon = dk3.ammo(5) > 0 and 5 or
          (dk3.ammo(4) > 0 and 4 or 0), timeout = 30})
      end
      local clinic = dk3.entity {index = 77}
      if dk3.health() < 100 and z() < 0 and clinic and
          (clinic.x-x())^2 + (clinic.y-y())^2 < 900^2 then
        try(recharge, {index = 77}, {timeout = 20})
        -- Return around the east side of the central shaft. The direct
        -- diagonal to the exit corridor crosses its open machinery pit.
        path({{688,-2176,-40},{832,-2044,-40},{832,-1888,-48},
          {688,-1792,-48},{468,-1740,-48},{384,-1664,-48}},
          {direct = true, radius = 16, vertical_radius = 24, fight = false, timeout = 20})
      end
      recover(0.8, 900)
      resupply(30, 900)
      -- Clear the closing door before waiting for Superfly; the doorway
      -- itself is a crusher and cannot be a regrouping point.
      path({{352,-1664,-48},{352,-1594,-32},{352,-1567,-16}},
        {direct = true, radius = 8, vertical_radius = 24, fight = false, timeout = 20})
      move({352,-1440,-16}, {direct = true, radius = 12,
        vertical_radius = 24, fight = false, weapon = 2, timeout = 60})
      try(clear, {radius = 900, hold = true, timeout = 20,
        arena = {{256,-1472},{448,-1424}}, weapon = 2})
      move({352,-1183,16}, {direct = true, radius = 12,
        vertical_radius = 24, fight = false, weapon = 2, timeout = 60})
      -- Use the width of the actual landing to strafe the two elevated
      -- shooters; a body-width tether cannot clear their crossing volleys.
      try(clear, {radius = 900, hold = true, timeout = 20,
        arena = {{256,-1215},{448,-1151}}, weapon = 2})
      dk3.sidekick("all", "follow")
      try(regroup, 250, 120)
      recover(0.8, 900)
      progress("e1m6c")
    end },
  }(visit, resumed)
end)

-- Icelab, part 3: the room past the first door holds two inmaters, a
-- ragemaster on the catwalk and a deathsphere overhead. They are
-- held off from the entrance with the guide's ranged finishing weapon while
-- Superfly waits behind.
level("e1m6c", function(visit, resumed)
  if visit > 1 then return exit "e1m7a" end
  return stages {
    { "arena", function()
      dk3.sidekick("all", "stay")
      try(use, { index = 59 }, { timeout = 10 })
      try(use, { index = 61 }, { timeout = 10 })
      -- Clear the entrance lip for a firing lane into the ring. A held
      -- shot from the lower doorway cannot see through the catwalk edge.
      -- The near catwalk lip can detonate a Shockwave before there is time
      -- to retreat, and automatic fire need not find a target after restore.
      -- The guide also names the ion blaster for this encounter. Use its
      -- ranged lane from the entrance, keeping combat evasion on solid floor.
      weapon(2, {fight = false})
      move({352,-176,200}, {direct = true, radius = 16,
        weapon = 2, timeout = 15, fight = false})
      -- Its overhead fire reaches this entrance while the ground guards
      -- advance. Remove that crossfire before holding aim on the catwalk.
      kill({index=31},{hold=true,weapon=2,timeout=60,
        arena={{320,-224},{384,-176}}})
      -- They keep to their beat on the catwalk: hunted one by one, met at
      -- range (the brutes hit hard up close) with Superfly kept back.
      for _ = 1, 2 do
        for _, foe in ipairs({ 172, 21, 32 }) do
          try(kill, { index = foe }, {hold = true,
            weapon = dk3.ammo(2) > 0 and 2 or 0, timeout = 30,
            arena = {{320,-224},{384,-176}}})
        end
      end
      -- The deathsphere over the ring is awaited at the catwalk's near end:
      -- chased, it leads off the catwalk into the nitrogen under the ring.
      move({ 352, -90, 200 }, { timeout = 30, radius = 24 })
      try(kill, { index = 31 }, { hold = true, timeout = 30, arena = { { 320, -110 }, { 400, -60 } } })
      recover(0.8, 900)
    end },
    { "doors", checkpoint = true, function()
      -- Round the ring to the buttons of the doors on (not the chromatic
      -- armour on the catwalk's far side: the way to it drops into the
      -- nitrogen).
      -- Both buttons operate the same three-part gate. Open it from this
      -- side, wait for the floor slab and leaves, then take the supplied
      -- catwalk corridor. The far button is not another prerequisite.
      dk3.sidekick("all", "stay")
      use({index = 125}, {weapon = 2})
      wait_until(function() return opened(22)() and opened(123)() and opened(124)() end,
        {timeout = 10, fight = false, reason = "the catwalk gate clears"})
      nodepath({211,1362,272}, {weapon = 2, fight = false})
      dk3.sidekick("all", "follow")
      tend(900, 0.6)
    end },
    { "west", checkpoint = true, function()
      -- The catwalks and rooms west (a battle boar, an inmater, cryotechs,
      -- guards, deathspheres) over the nitrogen, while Superfly waits. The
      -- battle boar charges and knocks a player off the narrow catwalk: it
      -- and the inmater are let come to the floor by the buttons.
      dk3.sidekick("all", "stay")
      for _, foe in ipairs({ 190, 20 }) do try(kill, { index = foe }, { hold = true, timeout = 30, arena = { { 150, 1330 }, { 260, 1420 } } }) end
      for _, foe in ipairs({ 190, 20, 58, 28 }) do
        try(kill, { index = foe }, { timeout = 40 })
        if dk3.health() < 50 then recover(0.8, 900) end
      end
      recover(0.8, 900)
    end },
    { "far west", checkpoint = true, function()
      dk3.sidekick("all", "follow")
      -- Deathspheres come to the bot; the cryotechs are met from range.
      local arena = {{x()-16,y()-16},{x()+16,y()+16}}
      for _, foe in ipairs({ 14, 187 }) do try(kill, { index = foe }, { hold = true, arena = arena, timeout = 25 }) end
      for _, foe in ipairs({ 54, 57, 29, 14, 187 }) do
        try(kill, { index = foe }, {hold = true, arena = arena,
          weapon = dk3.ammo(2) > 0 and 2 or 0, timeout = 20})
        if dk3.health() < 50 then recover(0.8, 900) end
      end
      recover(0.8, 900)
      dk3.sidekick("all", "follow")
      try(regroup, 250, 120)
    end },
    { "prison", checkpoint = true, function()
      -- Up the platforms to the inmaters by the door to Mikiko's prison.
      dk3.sidekick("all", "stay")
      for _, foe in ipairs({ 192, 173 }) do try(kill, { index = foe }, { timeout = 40 }) end
      -- The area's generic hunt routes beneath these upper platforms.
      -- Follow the supplied upper corridor before meeting the last inmater;
      -- do not first engage it in the low passage at the prison trigger.
      nodepath {-1100,832,544}
      kill({index = 19}, {hold = true,
        weapon = dk3.ammo(5) > 0 and 5 or 2, timeout = 60})
      recover(0.8, 900)
      dk3.sidekick("all", "follow")
      try(regroup, 250, 120)
      -- The doors open to a trigger before them; the exit is the line just
      -- past them (the area graph ends at the grate beyond it).
      try(touch, { index = 25 }, { timeout = 60 })
      move({ -300, 485, 472 }, { timeout = 30 })
      exit "e1m7a"
    end },
  }(visit, resumed)
end)

-- The vault: up the stairs, through the big doors, the halls of the trap
-- and the ladder; the diagonal door below the cage lift opens only from
-- beyond. The cage lift rises to the keypad cage (its lock shot away): the
-- keypad opens the doors to beyond for a while, reached by jumping off the
-- catwalk; there the keypad by the diagonal door lets the sidekicks in.
level("e1m7a", function(visit, resumed)
  if visit > 1 then return exit "e1m7b" end
  return stages {
    { "halls", function()
      dk3.sidekick("all", "follow")
      -- The golden soul and the plasteel armour by the start, past the
      -- start room's door.
      try(use, { index = 568 }, { timeout = 20 })
      for _, item in ipairs({ 80, 609, 88, 83 }) do
        if dk3.reachable({ index = item }) then try(pickup, { index = item }, { timeout = 30 }) end
      end
      advance({ 300, -2300, 338 })
      move({ 300, -2300, 338 }, { timeout = 120, cautious = true })
      -- East along this same walkway: the ion blasters standing on its ledges.
      -- The guards of this map answer from four or five hundred units and the
      -- disruptor's bolt carries eighty, so a body that reaches them with
      -- nothing else loses a fight it was owed; a weapon taken off this floor
      -- is carried into every map after it. (Both stand a short way off the
      -- route's line, on this same floor; the crates past them have no area of
      -- their own in the graph, so they are left.)
      for _, item in ipairs({ 89, 648, 90 }) do
        if dk3.reachable({ index = item }) then try(pickup, { index = item }, { timeout = 40 }) end
      end
      -- The deathsphere hovering over the floor above sees down the trap's
      -- corridor: met from its east end first.
      try(kill, { index = 109 }, { hold = true, timeout = 15 })
      -- Along the walkway and off its end to the floor below (the area
      -- graph waits there for the corner lift, which no one calls).
      move({ 25, -2276, 344 }, { timeout = 60 })
      move({ -60, -2150, 216 }, { direct = true, radius = 24, timeout = 10 })
      -- The guide's next control is the nearby lower-floor ladder keypad.
      -- A westward detour asks navigation for the diagonal door's return
      -- button, which belongs to the later sidekick route.
    end },
    { "ladder", checkpoint = true, function()
      -- The keypad by the far end slides a ladder's rungs out of the wall:
      -- up it alone (the sidekicks have no way up a ladder the area graph
      -- never had), the guards on the floor above, the cage lift down to
      -- the far side of the diagonal door, which its keypad opens for them.
      dk3.sidekick("all", "stay")
      -- (Pressed from a stride back: from right against it a press fails.)
      move({ -20, -2104, 216 }, {direct = true, fight = false,
        weapon = 2, timeout = 60, radius = 8})
      look(0, 0)
      for _ = 1, 3 do
        if opened(122)() then break end
        try(use, { index = 118 }, { timeout = 8 })
        wait(1)
      end
      expect(opened(122)(), "the ladder's rungs did not come out")
      wait(3)
      -- This drone makes the unarmed companion retreat onto the corner
      -- lift, holding it upstairs while Hiro waits below. Resolve that
      -- visible threat from the ladder alcove before asking the party to wait.
      local drone=dk3.entity{index=109}
      if drone and (drone.health or 0)>0 then
        kill({index=109},{weapon=2,hold=true,arena={{-64,-2144},{16,-2064}},timeout=60})
      end
      -- The corner lift up to the narrow walkway along the walls (the area
      -- graph has no way along it), round to the ladder's foot.
      -- This is the solo route to the cage lift. Bringing the party onto
      -- the corner lift obstructs its narrow dismount and pushes the pilot
      -- off the walkway while passing a waiting companion.
      dk3.sidekick("all", "stay")
      -- Let the ride action own boarding from outside the platform's edge.
      -- An earlier walk can briefly touch its top and send it upward before
      -- the ride action has entered the supported centre of the dock.
      move({-224,-2304,216}, {direct = true, radius = 1, pace = 0.4, fight = false})
      ride { index = 7 }
      dk3.sidekick("all", "stay")
      -- Extended rungs block a standing centre before x=-268. Finish the
      -- horizontal approach on the near side, then climb into their probe.
      path({ { -15, -2300, 344 }, { -12, -2040, 344 }, { -150, -2012, 344 } },
           { direct = true, radius = 12, timeout = 10, fight = false })
      -- Finish inside the motor's three-unit attachment probe. A twelve-unit
      -- arrival radius can stop short and let route recovery leave this ledge.
      move({-252,-2012,344}, {direct = true, radius = 1, fight = false, timeout = 15})
      move({ -272, -2012, 480 }, { direct = true, settle = false,
        radius = 16, vertical_radius = 8, pace = 0.35, fight = false, timeout = 15 })
      move({-272,-2072,496}, {direct = true, settle = false, radius = 12,
        vertical_radius = 16, fight = false, timeout = 10})
      move({ -240, -2100, 486 }, { direct = true, radius = 24, fight = false, timeout = 10 })
      -- West along the corridor to the cage lift's top (the area graph has
      -- the shaft's way through the diagonal door below).
      -- (Held: hunted, a guard leads off the floor's edge to the floor below.)
      local block = { { -268, -2255 }, { -222, -2080 } }
      for _, foe in ipairs({ 108, 583 }) do
        try(kill, { index = foe }, {hold = true, timeout = 15,
          weapon = dk3.ammo(2) > 0 and 2 or 0, arena = block})
      end
      move({ -600, -2190, 486 }, {direct = true, fight = false, timeout = 60})
      local corridor = { { -620, -2200 }, { -540, -2165 } }
      for _, foe in ipairs({ 108, 583 }) do
        try(kill, { index = foe }, {hold = true, timeout = 15,
          weapon = dk3.ammo(2) > 0 and 2 or 0, arena = corridor})
      end
      ride { index = 148 }
      use { index = 732 }
      dk3.sidekick("all", "follow")
      try(regroup, 250, 90)
    end },
    { "cage", checkpoint = true, function()
      -- Back up alone: the cage's lock shot away, its keypad opens the
      -- doors below for a while; off the corridor's edge to them, the
      -- ragemaster and guards beyond, and their keypad lets the sidekicks in.
      dk3.sidekick("all", "stay")
      -- Round the north end of the lower partition before fetching the
      -- cage's west-facing panel. The east-to-west diagonal crosses a wall.
      path({{-480,-2120,216},{-600,-2120,216},{-600,-2200,216}},
        {direct = true, radius = 12, fight = false, timeout = 15})
      ride { index = 148 }
      -- The cage's lock is a wire at the corridor's far end, with a worker
      -- sat in front of it.
      -- Leave through the open east side, then round the fixed north wall.
      -- That wall occupies X-704..-528, Y-2240..-2224 from Z320 to640;
      -- a diagonal northward stroke from the deck cannot cross it.
      move({-600,-2280,486}, {direct = true, radius = 12, fight = false})
      path({{-480,-2280,486},{-480,-2180,488}},
        {direct = true, radius = 12, fight = false})
      move({-700,-2180,480}, {direct = true, radius = 16, fight = false})
      try(shoot, { index = 603 }, {hold = true, weapon = 2, timeout = 20})
      try(shoot, { index = 53 }, {hold = true, weapon = 2, timeout = 30})
      path({{-760,-2180,480},{-732,-2100,480}},
        {direct = true, radius = 16, fight = false})
      use { index = 612 }
      -- Out of the cage, off the corridor's north edge to the floor below
      -- (a kerb at the edge too high to step: a hop over it and down) and
      -- through the doors before they shut (10 s — and the keypad below
      -- targets the same wire, so a missed window is opened again).
      for _ = 1, 3 do
        if z() < 300 then break end
        try(move, { -660, -2160, 480 }, { direct = true, radius = 32, timeout = 10, fight = false })
        try(move, { -620, -2080, 216 }, { direct = true, radius = 40, timeout = 10, fight = false })
      end
      expect(z() < 300, "not down off the corridor's north edge")
      -- The shot cycler and its shells first, run for and not fought for. This
      -- map issues no ion-pack ammunition at all, so the blaster lifted off
      -- the walkway is forty bolts and done, while the cycler's shot is
      -- hitscan, carries to the gallery's far end, and is fed again by a shell
      -- box on the decks above the west wall later on. Four hundred units of
      -- open floor, out and back, from the ground the body just dropped to:
      -- asked for from the keypad's corner it is refused outright, because the
      -- graph owns no leg out of that sixty-four-unit pocket (the drop over
      -- the edge is the only way into it) and nothing beyond reads as
      -- reachable from the keypad itself. The guards on this floor stop
      -- anything that stops to trade with them, and six seconds of that is the
      -- whole of the ten the wire doors stand wide — hence `fight = false`,
      -- the same as the hop over the ledge that starts the errand.
      for _, item in ipairs({ 11, 10 }) do
        if dk3.ammo(4)<10 then
          try(pickup, { index = item }, { radius = 96, timeout = 2, fight = false })
        end
      end
      -- Keep the timed crossing ahead of optional ammunition errands. These
      -- named doors require the upper keypad; pressing their surface cannot
      -- reopen them after spending its ten-second window on a pickup.
      try(move, { -605, -1960, 216 }, { direct = true, radius = 40, timeout = 15, fight = false })
      expect(opened(141)(), "the cage keypad's timed wire doors remain open")
      path({ { -605, -1960, 216 }, { -605, -1880, 216 } }, { direct = true, radius = 24, timeout = 10, fight=false })
      -- The keypad next, while the way to it is the one just walked: the
      -- guards here keep retiring south, and a body that spends its time
      -- clearing them out comes back to a corridor closed by the timed door
      -- it came through, with nothing to do but lean on its own control.
      -- Set down beside the keypad first: from the corner just walked the
      -- press is a stride away, and a step that goes looking for its own
      -- standing place has been seen to wander south into the dark behind a
      -- shut door.
      try(move, { -540, -1878, 216 }, { direct = true, radius = 24, timeout = 12 })
      use { index = 610 }
      try(function() clear { radius = 400, timeout = 40 } end)
      -- Back to the keypad's corner, where the next stage takes the party up.
      try(move, { -540, -1880, 216 }, { timeout = 40 })
    end },
    { "pipe", checkpoint = true, function()
      -- The door across the catwalk is dead: down off the catwalk to the
      -- channels below it, the keypad that opens the round hatch in their
      -- floor, and the flooded pipe under it to the grate at its far end
      -- (alone: the sidekicks wait).
      dk3.sidekick("all", "stay")
      move({ -720, -1344, 96 }, {radius = 8, vertical_radius = 24, fight = false, timeout = 60})
      use({index = 208}, {hold = true, fight = false})
      wait_until(function() return dk3.mover({index = 209}) == "open" end,
        {timeout = 12, fight = false, stance = {-720,-1344,96}, around = {0,0,0},
          reason = "the pipe hatch finishes rotating"})
      -- Over the open hatch and down into the pipe (a drop of 130: the pipe's
      -- floor is the floor hereafter). The channel is flooded to its ceiling
      -- and sealed, and the ceiling is a breakable plate (health 10) over the
      -- channel's east end: a shot through its underside is the only way out
      -- of the water, and up through the hole is the way on.
      move({ -640, -1436, -44 }, {direct = true, vertical_radius = 12, radius = 12, fight = false})
      move({ -230, -1440, -40 }, {direct = true, vertical_radius = 12, radius = 12, fight = false})
      -- (Ducked: where the plate's west end meets the channel the ceiling
      -- presses down to the crown of a standing head, and a hull that rises
      -- there is pinned; below the lip the lane to fire up lies open.)
      -- Under the plate and out within one breath (a body holds its air for
      -- about twenty-five seconds here, so the whole errand is asked for in
      -- short sentences). The plate's underside lies ninety over the head and
      -- the channel is a sealed tube: a blast round is rightly refused from
      -- under it (the burst would land on the shooter) and every other lane to
      -- it crosses the water's ceiling. Swim close beneath it before using
      -- the Disruptor; a Shotcycler burst recoils through the whole pipe.
      -- (Arrival forgives fifty-six units of height, so the climb out is asked
      -- for close: the hole is the goal, and the ledge past it, and a body that
      -- only got its head above the plate is not out.)
      for _ = 1, 2 do
        if z() > 90 and x() > -160 then break end
        try(move, { -208, -1436, -44 }, { direct = true, radius = 12, vertical_radius = 12, crouch = true, fight = false, timeout = 12 })
        move({-208,-1436,24}, {direct = true, radius = 8, vertical_radius = 8,
          settle = false, fight = false, timeout = 10})
        try(shoot, { index = 211 }, { timeout = 12, weapon = 1, hold = true })
        try(move, {-120,-1448,104}, {direct = true, radius = 8,
          vertical_radius = 12, fight = false, timeout = 20})
      end
      expect(z() > 90 and x() > -160, "not out of the flooded channel")
      -- Up the ramp past the save gem: the fan's mechanism, shot from in
      -- front of it, stops the fan, and the way drops past it.
      move({ 300, -880, 216 }, { timeout = 60, cautious = true })
      -- The mechanism is the housing the fan's hub sits in, eight units
      -- behind the catwalk's west rail, and the disruptor's bolt is a short
      -- one: its own reach is eighty units, so a bolt loosed from the ramp
      -- falls short of the housing and the fan never stops. The catwalk runs
      -- north past the hub's own column; from there the housing stands
      -- fifty-odd units off and the bolt arrives. The blade swings inside
      -- that housing, so the wall answers to the sight first and the body
      -- has nothing to wait for but its own aim.
      try(move, { 300, -790, 216 }, { radius = 16, timeout = 15 })
      try(shoot, { index = 436 }, { timeout = 15, weapon = 1 })
      -- Into the duct behind it (its floor a hop up, its roof low: ducked)
      -- and down out of its far end into the hallway.
      -- (A hop up into it, timed: the lip is a jump up, the roof low.)
      for _ = 1, 4 do
        if x() < 240 then break end
        try(move, { 300, -800, 216 }, { direct = true, radius = 12, timeout = 5, fight = false })
        try(move, { 270, -800, 250 }, { direct = true, radius = 12, timeout = 5, crouch = true, fight = false })
        jump({fight = false})
        try(move, { 180, -800, 250 }, { direct = true, radius = 16, timeout = 8, crouch = true, fight = false })
      end
      expect(x() < 240, "not into the duct behind the fan")
      if z() > 120 then
        move({ 170, -800, 88 }, { direct = true, radius = 24, timeout = 8, fight = false })
      end
    end },
    { "ledge", checkpoint = true, function()
      -- Up the ladder in the hall's east wall to the ledge that runs above it
      -- and west along that ledge. The niche ladder at the hall's west end is
      -- no way up: its top is shut by a hatch and a wall panel (76, 77 — the
      -- pair t502), and the button of that pair stands on the ledge above, so
      -- the niche is a way down, not a way on.
      --
      -- The graph's own ladder step is asked for from a goal that stands well
      -- back on the ledge. A goal at the ladder's own face is answered by the
      -- top of the ladder's place — that volume is playerclip to its last
      -- unit, so a hull dropped down it stops at its lid and takes the lid for
      -- the floor — and the body is let go and comes back down into the hall.
      -- First a stride to the rungs' own column. The graph's ladder step
      -- stands at the place's east corner; pressed there the body's head finds
      -- a beam at 176 instead of rungs, and the climb hangs on the face
      -- gaining nothing for its whole life. The rungs themselves are at x=100.
      -- Up, and nothing else on the way: a body that stops on the rungs to
      -- answer a guard slides back to the hall's floor and owes the climb
      -- again, so each round walks the column and takes the ladder with the
      -- fight left to the ledge above.
      for _ = 1, 3 do
        if z() > 200 and y() > -790 then break end
        if x() >= 120 then
          try(move, { 160, -920, 88 }, { direct = true, radius = 12, timeout = 12, fight = false })
        end
        try(move, { 100, -920, 88 }, { direct = true, radius = 12, timeout = 12, fight = false })
        try(move, { 100, -860, 88 }, { direct = true, radius = 12, timeout = 12, fight = false })
        try(move, { 100, -806, 216 }, { direct = true, settle = false,
          vertical_radius = 8, timeout = 45, fight = false })
        try(move, {100,-768,216}, {direct = true, radius = 8,
          vertical_radius = 12, timeout = 12, fight = false})
      end
      expect(z() > 200 and y() > -790, "not up the hall's ladder")
      -- West along the ledge. It gives out at the plate's own east face and
      -- comes back only a hundred and seventy units further west, past the
      -- plate's column: between them nothing but the air above the hall,
      -- whose floor is 128 units below. The graph's one leg between the two
      -- is a jump link off the plate's west face - and a hop taken at the
      -- walk's own pace lands in the hall, so the lane is run for it. The
      -- cables that hold the plate hang in pairs above y -968..-820 and
      -- y -716..-568: the line at y -768 goes between them and none has to
      -- be shot, for firing one lets the plate go from under its rider.
      move({ 40, -768, 216 }, { direct = true, radius = 24, timeout = 30, fight = false })
      expect(z() > 180, "not along the ledge above the hall")
      -- The ledge's west end is a guard post - three mishima guards at x
      -- -460..-524 - and the leap comes down among them, which is where a
      -- crossing paid for with a body's health ends in the hall below. Met
      -- from this end first instead: the lane along the hall is open and five
      -- hundred units long, a distance the guards' pistols reach and the
      -- disruptor does not, so it is fought with the ion blaster taken off the
      -- walkway above. (Held: the stand is the ledge's own east end, whose
      -- plank is all the body has under it, and twelve seconds of firing
      -- without a kill sends it in.)
      -- The gun is the one that still carries rounds. The ion blaster is the
      -- only long reach this map hands out, it gives no energy for it at all,
      -- and a body that has thrown its forty shots reaches the ledge with an
      -- empty gun: a kill asked of an empty gun is thirty seconds of standing
      -- in one place while the guard above takes its own time at the aim.
      -- Chosen again for every guard: the forty rounds are spent one fight at
      -- a time, and a body that decides its gun once and then runs dry stands
      -- in one place for the whole of its timeout with the barrel empty.
      for _, foe in ipairs({ 591, 590, 103 }) do
        local gun = (dk3.has_weapon(2) and dk3.ammo(2) >= 3 and 2)
          or (dk3.has_weapon(5) and dk3.ammo(5) >= 2 and 5) or nil
        if gun then
          try(kill, { index = foe }, { hold = true, weapon = gun, timeout = 25,
            arena = { { -75, -795 }, { 110, -695 } } })
        end
      end
      -- The hop is the graph's own: its jump link runs from -199 to -369 at
      -- y -768, and the crossing is asked for on that line and no other. The
      -- stand is set on the line first, so the run-up, the launch and the
      -- flight are one straight run — a body that leaves the ledge already
      -- drifing takes the flight with it and comes down in the hall.
      move({ -60, -768, 216 }, { direct = true, radius = 14, timeout = 20 })
      leap({ -196, -768, 216 }, { -378, -768, 216 }, {fight = false, timeout = 25})
      move({-400,-768,216}, {direct = true, fight = false, radius = 8,
        vertical_radius = 16, timeout = 10})
      expect(x() < -365 and z() > 180, "not across the gap onto the ledge's west end")
      -- Stride west off the landing. Straight at the goal, not by the graph:
      -- the plank's own ground lies in patches too small for the area file to
      -- have marked, and a body stood on one of them is told by the graph that
      -- the only way on is back across the gap it just jumped.
      move({ -450, -786, 216 }, { direct = true, radius = 20, timeout = 25 })
      expect(x() < -425 and z() > 180, "not onto the ledge's west end")
      -- The guard the long fire left standing is met here, where the plank is
      -- widest and there is nowhere behind the body to fall off.
      try(kill, { index = 103 }, { timeout = 30 })
      try(clear, { radius = 300, timeout = 40 })
      -- The button on its post (611, once only) yaws the slab (76) that caps
      -- the niche ladder in the hall's west corner a hundred degrees clear of
      -- its rungs, which takes twenty seconds at its speed of five. Down on
      -- the hall's floor that button's face stands above a body's reach, so
      -- there is no way to work it but here, while the party still walks the
      -- upper floor. The pillar at x -430..-470 fills the line at y -806, so
      -- the ledge's way runs at y -786 and turns in to the button's stand.
      path({ { -500, -786, 216 }, { -580, -816, 216 }, { -700, -816, 216 } },
        { direct = true, radius = 20, timeout = 40 })
      move({ -712, -821, 216 }, { direct = true, radius = 12, timeout = 20 })
      for _ = 1, 4 do
        if dk3.mover { index = 76 } ~= "closed" then break end
        try(use, { index = 611 }, { timeout = 8 })
        wait(1)
      end
      expect(dk3.mover { index = 76 } ~= "closed", "the slab over the rungs stayed shut")
      wait_until(function() return dk3.mover { index = 76 } == "open" end,
        { timeout = 45, reason = "the slab turned aside from the rungs" })
    end },
    { "hall", checkpoint = true, function()
      -- The hall's control is worked from up on the ledge, so all that is
      -- left here is going down: the slab (76) over the niche's rungs and the
      -- wall panel (77) beside it already stand open, and the only graph step
      -- off the ledge's west end is the walk-off at -695,-737, which lands on
      -- the hall's floor west of the plate's own column - the body never comes
      -- under the plate, whose lift is the only thing the graph offers from
      -- down there and which nothing calls here.
      dk3.sidekick("all", "follow")
      -- Down at the graph's own walk-off, at -695,-737. The step reports the
      -- stride come home as soon as the body stands over the place by the
      -- horizontal measure — which it does in mid-air, with the drop still to
      -- pay — so the floor itself is waited for, not the stride's word.
      move({ -695, -737, 88 }, { radius = 40, timeout = 45 })
      wait_until(function() return z() < 130 end,
        { timeout = 15, reason = "not down off the ledge's west end" })
      try(clear, {radius = 260, timeout = 20, hold = true,
        weapon = dk3.ammo(2) > 0 and 2 or 0,
        arena = {{-750,-800},{-640,-680}}})
      move({ -868, -685, 88 }, {direct = true, radius = 16,
        vertical_radius = 24, fight = false, timeout = 30})
      -- Up the ladder in the hall's west corner, whose rungs now stand free.
      -- The way up is flush with the rungs' face, centred on their column, which
      -- is exactly what the movement code probes for a ladder — a hull trace of
      -- 3 units that must find the rungs' own face, whose sides carry the mark.
      for _ = 1, 3 do
        if z() > 180 then break end
        try(move, { -864, -866, 88 }, { direct = true, radius = 14, timeout = 20 })
        try(move, { -864, -872, 206 }, { direct = true, radius = 14, timeout = 35 })
        try(move, { -864, -943, 216 }, { timeout = 45 })
        if z() > 150 and y() > -890 then
          try(move, { -864, -910, 224 }, { direct = true, radius = 16, timeout = 20 })
        end
      end
      expect(z() > 180, "not up the ladder in the hall's west corner")
    end },
    { "gallery", checkpoint = true, function()
      -- Keep the party off the touch-operated platform before the approach;
      -- a member held on its raised deck prevents Hiro boarding from below.
      dk3.sidekick("all", "stay")
      -- West, north and east along the gallery at floor 192 to the pair of
      -- doors the graph names t2 (ctl 180 and 181): neither is named, and each
      -- carries the node's own `nodetargetname`, so both are party doors and
      -- slide aside for a member walked into them. Their panels are four units
      -- thick and travel thirty-six apiece out of the hundred and six they
      -- close, so thirty-four are left open — a body goes through as it were
      -- sideways. Beyond, the gallery runs north again to the platform's foot.
      -- Three guards hold the gallery's south leg at its ladder's head, and
      -- three more its north end. A body walked down the middle of it earns
      -- every bolt they own: the same minute of walking cost thirteen lives
      -- before the run ever reached the platform. They are fought a man at a
      -- time, from the ground the party already stands on.
      for _, foe in ipairs({ 19, 694, 695 }) do
        try(kill, { index = foe }, { hold = true, timeout = 25,
          arena = { { -1010, -960 }, { -820, -640 } } })
      end
      path({ { -940, -943, 216 }, { -964, -823, 216 }, { -1068, -728, 216 },
             { -1208, -604, 216 }, { -1339, -488, 216 }, { -1443, -456, 216 } },
           { timeout = 150 })
      -- Charged before the last fight of the gallery, not after it: this is the
      -- level's only health station (ctl 55, in the gallery's west corner) and
      -- nothing between here and the level's exit heals again. The party came
      -- into this stage at fifty-eight and died at five, forty strides east of
      -- the chasm — the checkpoint's own care only tops a body up to sixty,
      -- which this one had already passed, and the guards here, the decks and
      -- the corridor's garrison were paid for in health that had no way of
      -- coming back (n51a). Asked for after the fight it is asked of a body
      -- already at eight health with a guard's bolts in its back and only five
      -- rounds of anything to answer with (n52a, which walked south to this
      -- station dying on the way).
      local health, maximum = dk3.health()
      if health < 0.9 * maximum and dk3.reachable({ index = 55 }) then
        try(recharge, { index = 55 })
      end
      -- The north leg's own guards, two on the gallery and one above it,
      -- before the turn north to the platform's foot.
      for _, foe in ipairs({ 681, 680, 25 }) do
        try(kill, { index = foe }, { hold = true, timeout = 20 })
      end
      -- The plasteel standing on the ledge east of the platform's column (ctl
      -- 50, -1072,16,226) is the last armour in the level, and it is asked of
      -- here because this is the last point the route stands anywhere near it.
      -- It is never had: every reachability question about it is answered
      -- `no`, and the reason is a door rather than the graph — its ledge
      -- stands behind the hatch the button on the deck's west wall (ctl 150,
      -- -1400,-694) works through its relay (ctl 151), and that button is two
      -- stages further along the route and leaned on by nobody. The offline
      -- graph agrees in its own way: no area of the compiled file meets the
      -- armour from this floor at all, the only two ways into that pocket
      -- being the wall's hatch and the corner train (ctl 175) whose deck no
      -- node of this level calls. Named here so a later pass can weigh the
      -- detour: from the corridor's north run the graph does own a way to it,
      -- thirty-six reachabilities of it, and the first of them is off the
      -- corridor's edge at 32,-647 down two hundred and forty to the low
      -- floor — the whole of it down and back for one plate of armour.
      if not dk3.reachable({ index = 50 }) then
        local gate = dk3.plan { index = 50 }
        dk3.log("gallery: the plasteel is gated — " .. (not gate and "no control named, no route at all"
          or gate.wait and "a gate already moving"
          or tostring(gate.action) .. " control #" .. tostring(gate.index) .. " (gate #" .. tostring(gate.gate)
               .. ") from " .. tostring(gate.x) .. "," .. tostring(gate.y) .. "," .. tostring(gate.z)))
      end
      -- Hold the party at the gallery's foot: the platform's deck stands but
      -- eight units off this floor, and a companion walking over it on the way
      -- to its leader rides it to the top. The lift is the leader's own step
      -- from here.
      dk3.sidekick("all", "stay")
      -- Lifted onto the deck despite the hold above — the graph has no way down
      -- from it, so the foot is not asked for again here: standing on a mover
      -- every question of reachability is answered `no`, and `advance` from here
      -- would tour the level's controls rather than the three strides wanted.
      -- The platform's own stage begins from its deck and is where the ride ends
      -- either way.
      if z() > 280 and math.abs(x() + 1180) < 100 and math.abs(y() - 12) < 120 then
        dk3.log("gallery: lifted on the platform's deck; riding it from here")
      else
        -- Touching this platform raises it immediately. Admit either its
        -- lower floor or raised deck; the next stage owns the actual ride.
        move({-1180,12,216}, {fight = false, radius = 24,
          vertical_radius = 128, timeout = 90})
        if z() > 230 then
          wait_until(function() return z() >= 300 end,
            {timeout = 15, fight = false, stance = {index = 23},
              reason = "the touched gallery platform reaches its landing"})
        end
        expect(y() > -100, "not north of the t2 doors")
      end
    end },
    { "plat", checkpoint = true, function()
      -- The platform (ctl 23) rides the party from the floor at 202 to 278;
      -- west off it along the deck at 280, which steps up to 344 at
      -- -1257,-137 — a rise the graph's own link carries.
      -- The deck is held at the top for as long as a rider touches it (the
      -- reference's plat touch defers its return every frame), so a companion
      -- left standing on a deck that rose earlier freezes the lift for
      -- everybody below: the deck never comes back to the floor and the leader
      -- waits under it out its clock. Called to its leader, the companion
      -- walks off the deck's edge and the deck settles.
      -- The deck's own state says whether anybody is still on it, so that is
      -- what is asked, repeatedly until it answers: the height of the leader
      -- cannot say (it steps down onto the deck's floor only during the ride
      -- that follows, and read here it stood a floor too high — a single guard
      -- on it let the hold pass unnoticed and the ride waited under the deck
      -- out its whole clock, n45a). Several calls because a companion parked
      -- on the deck has to find the deck's edge before it leaves it.
      -- Already riding, the body having been carried up at the gallery's foot:
      -- a deck with a rider on it never comes down, because the reference
      -- defers the return for every frame anybody touches it, so calling the
      -- party off it here would only spend the waits and change nothing. The
      -- walk west off the deck's end is what empties it, and the deck settles
      -- behind the party for the companions to ride in their turn.
      if z() > 280 then
        dk3.log("plat: already riding the deck from the gallery's foot")
      else
        for _ = 1, 3 do
          local settled = not opened(23)()
          if settled then break end
          dk3.log("plat: the deck is held up; calling the party off it")
          dk3.sidekick("all", "come")
          try(wait_until, function() return not opened(23)() end,
              { timeout = 25, reason = "the deck came down" })
        end
        ride { index = 23 }
      end
      expect(z() > 280, "the platform did not lift the party")
      dk3.sidekick("all", "follow")
      -- Pass east of the clipboard worker on the fixed landing. The inner
      -- line meets his body and sidesteps back onto the moving platform.
      move({-1040,8,304}, {direct = true, radius = 12, fight = false})
      -- The clipboard worker occupies the middle of the sloping landing.
      -- Its north edge is a continuous supported ramp to the upper deck.
      for _,point in ipairs({{-1040,-100,304},{-1120,-100,304},
          {-1152,-100,320},{-1184,-100,338},{-1220,-100,356},{-1257,-100,368}}) do
        local guard=dk3.entity{index=25}
        if guard and (guard.health or 0)>0 and dk3.visible{index=25} then
          try(kill,{index=25},{hold=true,weapon=2,timeout=12})
        end
        move(point,{direct=true,fight=false,weapon=2,pace=0.6,
          radius=8,vertical_radius=16,on_floor=true})
      end
      expect(z() > 340, "not up off the platform's deck")
    end },
    { "decks", checkpoint = true, function()
      -- South and west along the decks at 344, then two steps down to the deck
      -- at 320 along the west wall. Gold keeps its workers and a cryotech on
      -- this run (ctl 674 and 675 at -1208,-604; ctl 679 at -1648,-484; ctl
      -- 676, 677, 678 and 607 about -1656,-800), so it is fought as it is
      -- reached rather than run through.
      -- The earlier gallery shot can leave this guard alive; he can occupy
      -- the first narrow deck corner after a save restore.
      kill({index = 25}, {hold = true, weapon = 2, timeout = 45})
      path({ { -1321, -137, 368 }, { -1320, -251, 368 }, { -1322, -334, 368 },
             { -1464, -344, 368 }, { -1470, -482, 368 } },
           {direct = true, radius = 8, fight = false, weapon = 2, timeout = 30})
      -- Fought one at a time from the deck's middle, and not as one call to
      -- everything within seven hundred. The sweep took the party from
      -- seventy-six to twenty-one in three seconds and ten of its twenty-six
      -- rockets (n53a, 445600-448600), because the four authored here answer
      -- together from the deck's ends: a cryotech stands on the next path's
      -- own first point (679, -1648,-480, at the deck's 376), its second two
      -- hundred and forty further down the west wall (678, -1640,-872), and a
      -- pair of workers sits behind the party's own line (605 at -1402,-650,
      -- 675 at -1216,-648). Every one of them is more than a hull's width
      -- from the next, so the lane takes them singly and the health that the
      -- gallery's station just filled stays filled long enough to matter.
      for _, foe in ipairs({ 679 }) do
        try(kill, { index = foe }, { hold = true, timeout = 25 })
      end
      -- Use the ladder-hatch keypad from this eastern ledge before crossing
      -- to the western decks. A gap separates those decks from its alcove.
      try(regroup, 96, 15)
      dk3.sidekick("all", "stay")
      path({{-1256,-496,368}, {-1256,-624,368}, {-1328,-624,352}},
        {direct = true, radius = 8, fight = false, timeout = 15})
      local obstruction = dk3.trace({x(),y(),z()}, {-1360,-672,336}, true)
      if obstruction.index == 675 or obstruction.index == 605 then
        -- A worker can flee into the alcove itself. Clear only the body
        -- actually blocking this sweep, from here, without pursuing it.
        try(shoot, {index = obstruction.index}, {hold = true, weapon = 2,
          fight = false, timeout = 8})
      end
      move({-1360,-672,336}, {direct = true, radius = 8, fight = false, timeout = 15})
      use({index = 150}, {hold = true, fight = false, timeout = 8})
      wait_until(function() return dk3.mover {index = 114} == "open" end,
        {timeout = 10, reason = "descending ladder hatch fully open"})
      path({{-1328,-624,352}, {-1256,-624,368}, {-1256,-496,368}, {-1470,-482,368}},
        {direct = true, radius = 8, fight = false, timeout = 15})
      dk3.sidekick("all", "follow")
      -- Leave the two civilian workers alone: pursuing their flight carries
      -- the body off this deck into the keypad's lower recess.
      path({ { -1648, -484, 368 } },
        {direct = true, radius = 8, fight = false, timeout = 150})
      -- Clear the southern cryotech before turning away toward the keypad;
      -- its spray otherwise holds that precise crossing under continuous fire.
      kill({ index = 678 }, {hold = true, timeout = 25,
        -- An empty ion pack otherwise falls back to a six-shot recoil burst
        -- on the narrow southern corner. Use the stocked rocket launcher
        -- from this wider northern landing before entering that corner.
        weapon = dk3.ammo(2)>0 and 2 or (dk3.ammo(5)>0 and 5 or 2)})
      -- Restore the supported deck corner after combat before taking the
      -- southern leg; a diagonal from an evasion point crosses open floor.
      move({-1655,-592,368}, {direct = true, radius = 8, fight = false, timeout = 20})
      move({-1656,-696,344}, {direct = true, fight = false, radius = 8})
      -- The second cryotech is met from the wall north of it, before the deck
      -- is walked past its feet: the stage's own last point stands fifty
      -- units south of the thing.
      move({ -1656, -824, 344 }, { timeout = 90 })
      expect(x() < -1600 and y() < -750, "not along the west decks")
      -- Whichever of them was not authored where the file says. Bounded to
      -- what can stand on this deck, not to what the corridor can hear.
      try(clear, { radius = 250, timeout = 30 })
    end },
    { "ramp", checkpoint = true, function()
      -- South to the ramp's foot and up to the high walk at floor 464: the
      -- graph's links carry the forty- and fifty-six-unit rises, and a
      -- cryotech (ctl 26) stands on the ramp's shoulder. East along the high
      -- walk to the ladder's head at -1264,-936.
      -- Let the motor choose the continuous ramp approach. Ending an earlier
      -- combat move at the foot leaves lateral momentum toward the open side.
      dk3.sidekick("all", "stay")
      -- Only the cryotech on the ramp's shoulder (ctl 26, -1376,-1032, at the
      -- high walk's 496) is met here, and it is met from the ramp's bend, a
      -- hundred and thirty below it and in the open. What the stage used to
      -- ask instead was everything within seven hundred, and seven hundred
      -- from the ramp's top reaches the vermin four hundred units down in the
      -- corridor (594 at -1213,-1408, 595 at -1045,-1408): the body went down
      -- the ladder after them twice in n53a — once to its fourth death at the
      -- ladder's own head (t=577200, source 595), once to one hundred and
      -- fifty seconds of standing against the stone panel at the shaft deck's
      -- south end with the stage's whole clock spent (t=861400, the run's own
      -- last line). The shell box on the ramp's foot is left alone for the
      -- same reason of the way back: the compiled graph's only leg from its
      -- floor runs north through the low level toward the gallery, thirty-odd
      -- reachabilities and no stair up to this ramp from anywhere near it.
      -- Reach the ramp's supported bend before opening the firing lane.
      -- Shooting from its foot sends the area planner down to the lower
      -- gallery when the cryotech is hidden behind the shoulder.
      -- The first supported stop is below its muzzle. Ready the ion gun
      -- before climbing; closing slowly to a second precise point lets the
      -- cryotech empty a full burst before we can fire.
      weapon(dk3.ammo(2) > 0 and 2 or 4)
      move({-1504,-1036,440}, {fight = false, timeout = 30})
      kill({ index = 26 }, {hold = true, timeout = 90,
        arena = {{-1648,-1064},{-1408,-1000}},
        weapon = dk3.ammo(2) > 0 and 2 or 4})
      move({ -1396, -1036, 488 }, { timeout = 90 })
      dk3.sidekick("all", "follow")
      -- East to the ladder's head without stopping to trade: what is left of
      -- the run's ammunition is the corridor garrison's, and the walk is
      -- theirs rather than a fight's.
      path({ { -1372, -1008, 488 }, { -1380, -936, 488 }, { -1300, -936, 496 } }, { timeout = 150, fight = false })
      -- A chase that carries the body off the high walk and down the ladder
      -- is the one way this stage can end in nothing at all: from the deck at
      -- 376 the graph's next waypoint runs south, into the fence the stone
      -- panel stands, and the move stands there until its clock runs out.
      -- Back along the deck away from that fence, and up the rungs again.
      if z() < 440 then
        dk3.log("ramp: carried down off the high walk; back along the deck and up the rungs")
        try(move, { -1256, -1000, 376 }, { timeout = 45 })
        try(move, { -1264, -936, 496 }, { timeout = 90 })
      end
      expect(z() > 460, "not along the high walk")
    end },
    { "shaft", checkpoint = true, function()
      -- Down the ladder at -1264,-936 to the deck at 376 (the area graph has
      -- both ways of it), south along that deck to its end, and off that end
      -- down thirty-two into the long corridor at floor 320. The vermin in that
      -- corridor (ctl 594, 595 and 225) are met as it is entered.
      --
      -- The deck's end is fenced. A stone panel (ctl 149, health ten) stands
      -- from the deck's floor past a head across the whole of its width, and
      -- the graph offers its way down on the far side of that panel. Gold
      -- shoots it — the panel's own target is nothing but the spray of its
      -- breaking, so all it opens is the drop — and the shot is had from the
      -- ladder's foot, before the deck is walked rather than at its end. The
      -- deck is sixty-four wide, a hull and a change of step less than the
      -- panel's own width, so a party walked at that fence files into a queue
      -- one body deep in front of it: the head of the queue presses the panel,
      -- the body behind has nothing to pass it by, and the two of them stand
      -- out of the stage's whole clock with the companion named as what is in
      -- the way (n52a, whose leader was still at the deck's middle two minutes
      -- after coming down the ladder). The panel stands three hundred units
      -- down a deck with nothing across its floor, so breaking it first costs
      -- a shot and opens the way before anybody is standing on it.
      -- Centre the hull over the opening before descending. At the compiled
      -- ladder's west face its feet can remain supported by the upper rim.
      move({-1256,-936,496}, {direct = true, settle = false, radius = 4,
        vertical_radius = 16, fight = false, timeout = 10})
      move({-1256,-936,376}, {direct = true, radius = 8,
        vertical_radius = 16, fight = false, timeout = 20})
      expect(z() < 420, "not down the ladder at -1264,-936")
      dk3.sidekick("all", "stay")
      path({ { -1256, -976, 376 }, { -1256, -1064, 376 }, { -1256, -1216, 376 } },
        {direct = true, radius = 12, fight = false, timeout = 120})
      local panel = dk3.entity {index = 149}
      if panel and (panel.health or 0) > 0 then
        shoot({index = 149}, {weapon = 2, hold = true, fight = false, timeout = 20})
      end
      move({ -1240, -1395, 344 }, {direct = true, timeout = 60})
      expect(z() < 360, "not down into the corridor")
      dk3.sidekick("all", "follow")
      -- Three vermin own this corridor's west end (594 and 595 at its foot,
      -- 225 a hundred and forty east) and the drop lands within thirty of the
      -- nearest. Eight hundred of sweep called the corridor's east garrison
      -- into the same minute, and the chase after the vermin is what the ramp
      -- stage now refuses to start; so the two nearest by name, a sweep
      -- bounded to the deck they stand on, then the run east.
      for _, foe in ipairs({ 594, 595 }) do
        try(kill, { index = foe }, { hold = true, timeout = 25 })
      end
      try(clear, { radius = 250, timeout = 30 })
      move({ -1045, -1404, 344 }, { timeout = 90 })
      try(kill, { index = 225 }, { hold = true, timeout = 25 })
    end },
    { "bridge", checkpoint = true, function()
      -- East along the corridor: the graph's door node at -829,-1404 is t3
      -- (ctl 344, a party door across the corridor) and the chasm begins at
      -- x -752. Its span (ctl 210) stands above the void with its deck's top at
      -- 444; its `angle` is -2 — down — and it travels a hundred and eighteen,
      -- bringing that deck to six above the corridor's floor. What brings it
      -- down is the charge high on the chasm's south wall at -508,-1520 (ctl
      -- 97, health ten): its event fires the span itself after two tenths of a
      -- second. The area graph has no floor across this void at all — movers
      -- are absent from it — so the crossing is driven straight over the deck.
      advance({ -790, -1409, 344 })
      local down = opened(210)()
      for _, spot in ipairs({ { -790, -1409, 344 }, { -950, -1404, 344 }, { -1120, -1404, 344 } }) do
        if down then break end
        try(move, spot, { timeout = 40 })
        if dk3.visible({ index = 97 }) and try(shoot, { index = 97 }, { timeout = 30 }) then
          wait(3)
          down = opened(210)()
        end
      end
      if not down then
        try(use, { index = 210 }, { timeout = 30 })
        wait(3)
      end
      expect(opened(210)(), "the chasm's span never came down")
      -- Crossed as two asked steps, the first to the chasm's own lip. The
      -- charge's blast is no small thing: it threw the body a hundred units
      -- west and north and forty of its health away while the shot's own wait
      -- ran, and the crossing asked for straight from that spot began against
      -- a clock that wait had already spent — its first stall was answered by
      -- the graph, which marks no ground over this void and led the body back
      -- the way it came until its minute ran out (n47a). Stepping to the lip
      -- first costs nothing even when its own stride stalls, because the lip
      -- is a place the graph has; and the deck's leg that follows is a change
      -- of step more than a hull beyond the last, which is what begins a
      -- stride's own measure.
      -- Ended on the corridor's own ground east of the deck, not on the span:
      -- the area file was compiled with this span up, so the deck is a place
      -- the graph has no way off, and standing on it every later question of
      -- reachability is answered `no` — asked to plan from there the body went
      -- twelve rounds over the level's controls, from the cage's keypads to the
      -- starting door of the level itself, and failed with its health spent on
      -- a walk home (n50a, which crossed the chasm in 1.1 s and then lost two
      -- and a half minutes to that tour).
      path({ { -780, -1404, 344 }, { -430, -1409, 344 } },
           { direct = true, radius = 24, timeout = 90 })
      -- Its own measure again: this stride asked for twenty-four, and the span's
      -- brush ends at x -472, so the worst stop the stride can report is x -454
      -- — five units west of the frame this stage used to expect. The hull is
      -- twelve wide, so x -460 is the first line whose standing is wholly east
      -- of the span, and the stride's guarantee is six units past it (n54a came
      -- through at x -446 and would have failed by four units on a stride that
      -- stopped level with the brush instead of past it).
      expect(x() > -460, "not across the chasm and off its span")
      -- East on: t4 (ctl 260) at the graph's node at -391,-1415, then the
      -- corridor's long run east to x 14.
      -- That run's east end is held: a worker at its foot (696) and three
      -- guards up it (697, 698, 699), and the charge's blast has already taken
      -- what health the body carried to the chasm — it lands at the door with
      -- the deck's fall still ringing. The run was walked past them at five
      -- health with nine rounds, and ended on a guard's bolt forty strides in
      -- with the whole stage to restore for it (n51a). The door is opened
      -- first, and the garrison met from the door's west side, where the body
      -- stands behind a frame rather than in the corridor's mouth.
      try(use, { index = 260 }, { timeout = 20 })
      wait(1)
      -- The garrison is met by name rather than by eight hundred of sweep:
      -- the sweep from the door's west side reaches the three guards up the
      -- corridor (697 at 32,-1160, 698 and 699 beyond) as well as the worker
      -- at its foot (696) and the pair along its length (17 at -160,-1384, 16
      -- at 32,-1280), and that is the whole corridor's ammunition in one
      -- minute. The body took the sweep standing in the corridor's mouth at
      -- twenty-one health and died forty strides east of the door (death
      -- three, t=505800, source 697). The two this stage walks past first,
      -- the sweep to the door's own mouth, and the three up the corridor left
      -- to the stage that walks up it.
      for _, foe in ipairs({ 17, 696 }) do
        try(kill, { index = foe }, { hold = true, timeout = 25 })
      end
      try(clear, { radius = 250, timeout = 30 })
      advance({ 14, -1396, 344 })
      move({ 14, -1396, 344 }, { timeout = 150 })
      expect(x() > -100, "not east out of the corridor")
    end },
    { "north", checkpoint = true, function()
      -- North up the corridor at x 32: t5 (ctl 354) stands at the graph's door
      -- node of 32,-986. Then the second void, from y -897 to y -639: its span
      -- (ctl 416) is the same make as the first — deck at 444, `angle` -2,
      -- travelling a hundred and eighteen — and its button (ctl 207) is flush
      -- in the corridor's west wall at y -944, a few strides this side of the
      -- edge. Past it t6 (ctl 357) at y -548 and the corridor's east turn.
      -- The run north up x 32 is the garrison's own ground and it is in sight
      -- of itself: a guard at the run's foot (16, 32,-1280) and three up it
      -- (697 at 32,-1160, 698 at 24,-1104, 699 at 48,-1040). Seven hundred
      -- from anywhere on that line is all four at once; the corridor's own
      -- axis takes them one at a time from the run's south end, before the
      -- walk begins rather than in the middle of it.
      for _, foe in ipairs({ 16, 697, 698, 699 }) do
        try(kill, { index = foe }, { hold = true, timeout = 25 })
      end
      try(clear, { radius = 250, timeout = 30 })
      path({ { 32, -1167, 344 }, { 32, -1015, 344 } }, { timeout = 150, fight = false })
      advance({ 33, -928, 344 })
      -- How far a stride counts as its own: a move with no `radius` is content
      -- at forty units of its mark, and forty is a wider bed than this door's
      -- frame. The t5 brush stands across y -1000..-976, so asking the stride
      -- for twenty-four and expecting the frame's north face asks one question
      -- twice; asking the stride for nothing while expecting y -945 asked two
      -- questions and lost the run on the second — the body came through the
      -- open door, stopped at y -967 with thirty-nine units left to its mark,
      -- and the stage read its own arrival as the door still shut (n54a).
      move({ 33, -928, 344 }, { timeout = 120, radius = 24 })
      expect(y() > -960, "not through the t5 door")
      -- The span is called from the corridor's west wall (ctl 207) and asked of
      -- it twice over: a held press first, which aims from wherever the walk left
      -- the body, and only if that misses the walking press that goes to the
      -- button's own face. On the round taken again after the yard's deaths the
      -- walking press alone found no stand and spent its whole twenty seconds
      -- without touching the button, and the stage read its span as never come
      -- down (n59a). A held press costs eight seconds and no ground at all.
      for _ = 1, 2 do
        if opened(416)() then break end
        try(use, { index = 207 }, { hold = true, timeout = 8 })
        if not opened(416)() then try(use, { index = 207 }, { timeout = 20 }) end
        wait(3)
      end
      expect(opened(416)(), "the second span never came down")
      -- The span comes down level with the corridor's floor, so it is walked,
      -- and walked *off* in one stride: nothing may stop on the deck. The area
      -- file was compiled with this span up like its sibling over the first
      -- chasm — the deck is not ground the graph has at all, and the one area it
      -- carves over the void's north end (the slab over y -801..-639) is
      -- compiled with no reachability of any kind. Three runs went into that
      -- void from three different stopping places: `advance` from seven units
      -- inside the deck's north lip had nowhere to go and left the body at the
      -- bottom of the hole, -283,-770,96 (n55a); a press of the t6 panel from
      -- the bank's middle at y -607 went off to a stand the graph believed in,
      -- waypoint 32,-647,104, and the body to -175,-649,100 (n56a); and a press
      -- asked eighteen units short of the panel's face — the body stood at
      -- 31,-588, the panel opened, and two seconds later it was at
      -- 131,-838,144, two hundred units down the hole, wedged on a ladder there
      -- for the rest of the stage (n57a).
      --
      -- What carried it off the deck in two of those cases was the walk's own
      -- steering. Asked for one stride from the corridor to the panel's face, the
      -- body began it from x 3 — a press against the west wall leaves the body
      -- beside its button — and the first half-second of straight steering put it
      -- on the deck at x 55, more east than north. It came off the deck's east
      -- edge at x 90 and went down into the hole at 100,-857,92, where a ladder
      -- carried it up to 32,-649,133 (n58a). A decked crossing therefore starts on
      -- the deck's own centre line and takes the two marks every crossed run has
      -- used: x 37 at y -762, then the bank's middle at y -596, where the graph
      -- has ground, and only then the panel's face.
      --
      -- The party is told to hold on the corridor's own ground before the deck
      -- is stepped on, and is not called again until the leader stands on the
      -- bank. Following a leader who is himself two hundred units out over a
      -- hole is how the party was lost here: in the round that came through,
      -- one of them was found standing on the deck's middle at 33,-763,436 with
      -- the way off it gone (`stranded=350`, `routeless=1`) and the other at
      -- 87,-635,122 at the bottom of the hole, both of them past any help the
      -- route can give and neither of them able to answer what waits in the
      -- yard. Two bodies on the deck at once is also how the deck gets leaned
      -- on and rides away with somebody on it (n57a).
      dk3.sidekick("all", "stay")
      move({ 32, -915, 344 }, { direct = true, radius = 12, timeout = 30 })
      path({ { 37, -762, 346 }, { 29, -596, 344 } },
           { direct = true, radius = 16, timeout = 150 })
      expect(y() > -620, "not across the second void and off its span")
      move({ 32, -578, 344 }, { direct = true, radius = 12, timeout = 30 })
      expect(y() > -620, "not on the t6 panel's face")
      -- Called over now, with the leader standing still on ground the graph has
      -- and the deck flat under them: the crossing is a straight line up x 32
      -- from the span's south lip to this face, which is the line the leader's
      -- own stride just walked. The yard's garrison is the level's last brawler
      -- and the level's own answer to it is the two bodies at five thousand
      -- health apiece, so whatever can be brought across is worth the wait —
      -- and `sic` below asks for them only if they came.
      dk3.sidekick("all", "follow")
      local together = try(regroup, 200, 30)
      dk3.log(string.format("t6: the party %s across the span",
                            together and "came" or "did not come"))
      -- Where that press's own eye stands and what it meets, asked once from the
      -- face: the same press at the t5 door landed in fifty milliseconds from
      -- fifty-nine units, and this one walked away without ever pressing — the
      -- two panels are the same brush of the same size across the same corridor.
      local function probe(index)
        local found = dk3.entity({ index = index })
        dk3.log(string.format("t6 probe: index %d is %s at %.0f,%.0f,%.0f state=%s",
                              index, found and (found.classname or "?") or "nothing",
                              found and found.x or 0, found and found.y or 0,
                              found and found.z or 0, found and (found.state or "-") or "-"))
      end
      for _, index in ipairs({ 354, 357, 416, 418 }) do probe(index) end
      local line = dk3.trace({ x(), y(), z() + 24 }, { 32, -548, 368 }, "shot")
      dk3.log(string.format("t6 probe: the eye at %.0f,%.0f,%.0f meets %s (%d) at fraction %.3f",
                            x(), y(), z() + 24, line.class or "?", line.index or 0,
                            line.fraction or 0))
      -- Ready the close-range answer before the brawler can enter the lane;
      -- an automatic rocket-to-ion switch gives him time to close and hit.
      local corridor_gun = dk3.ammo(4) > 0 and 4 or 2
      weapon(corridor_gun)
      try(use, { index = 357 }, { hold = true, timeout = 8, weapon = corridor_gun })
      if opened(357)() then
        -- The ragemaster that owns the corridor's north end (102, authored back
        -- and west at -112,-208) walked down it and took the body as it came
        -- through the panel: 39,-461, then 61,-490, then 43,-459, three deaths on
        -- the same stride (n59a). Asked of by name from this face it was worse
        -- than left alone, and `hold` does not prevent it: a held fight still
        -- shifts two hundred units toward its prey every five seconds of blind,
        -- and the panel's face has nothing but the deck on its east side. The
        -- body left the bank at 31,-588, was found on the deck at 67,-699, came
        -- off that deck's east edge and finished the action at 118,-800,216 at
        -- the bottom of its own hole (n60a). What is asked here is therefore
        -- bounded to the ground a fight cannot walk off — the frame at the
        -- panel's back, the corridor's walls on both hands, none of it within
        -- reach of the void — and the level's own answer to a brawler is asked
        -- first: the sidekicks, if they came across.
        if together then try(sic, { index = 102 }, "all", 25) end
        try(kill, { index = 102 }, {hold = true, weapon = corridor_gun, timeout = 15,
          arena = { { -24, -536 }, { 84, -448 } } })
        if not opened(357)() then try(use, { index = 357 }, { hold = true, timeout = 8 }) end
        -- Straight through its frame: the corridor north is a run of floor at x
        -- 32, and a routed walk here is a walk past the void again.
        move({ 29, -446, 344 }, { direct = true, timeout = 60, radius = 24 })
      else
        -- The pilot's own way through, then: a walk *routed* through the panel's
        -- frame makes the closed gate its business, and the gate machinery stands
        -- the body in front of the door and works it there — the same way t5 came
        -- open (the plan named control 354 and the press landed in fifty ms). The
        -- graph compiled this bank with six walk links running north through the
        -- t6 line, so a route exists with the panel shut.
        dk3.log("t6 probe: the held press did not open it; walking the route through it")
        move({ 29, -446, 344 }, { timeout = 90, radius = 24, fight = false })
      end
      expect(y() > -500, "not through the t6 door")
    end },
    { "sidekick", checkpoint = true, function()
      -- East and north to the wall along y -64..-48 whose only opening is the
      -- doorway at x -24..64 (its lintel at 412..440). Its panel (ctl 647) is
      -- a func_door named sidekick_door. Nothing on this side of the wall opens
      -- it, and the reference says so twice: the player cannot use a func_door
      -- that has a targetname at all (base/dlls/world/client.cpp builds the test
      -- as `bUseFuncDoor = !stricmp(className, "func_door") && !bHasTarget`), and
      -- a sidekick walking its node route uses a door it is blocked by only when
      -- `!(pDoor->targetname) && !(pDoor->keyname)` (ai_func.cpp, the NODETYPE_DOOR
      -- branch); a named door instead wants a NODETYPE_DOORBUTTON node naming the
      -- switch, and this level has no node for either 647 or its panel -- 647
      -- carries no `nodetargetname`, which is also what movers.openForParty needs
      -- to walk a companion through a named door. src/mechanics/server/
      -- interactions.zig refuses the press for exactly gold's reason, so the
      -- presses this stage used to make here were never a gold action.
      -- The yard's garrison is met before the walk into it rather than in the
      -- middle of it: the run that reached the yard's south-east corner at
      -- 232,-436 with the yard unset came back down at 263,-436 under the
      -- ragemaster standing in the yard's own middle (596 at 200,-216,384), the
      -- eighth death of the level (n59a). Seven hundred from anywhere along that
      -- path is 596, the lasergat on the ledge above the yard's north end (13 at
      -- 76,-400,543) and the worker on the far side of the wall (600 at
      -- -4,120,352) all at once, and the party reaches this yard with no armour
      -- since the chasm and its shells counted in single digits. The two on this
      -- side of the wall are met in the order the path walks them, from the
      -- corridor's north end; the worker is beyond the panel and waits until the
      -- panel is up.
      -- Not marched into the yard for any of them: the graph's only lane north
      -- runs along x 203 within fifty units of 596's own ground, and the round
      -- that walked this stage's old opener came down at 263,-436 under it with
      -- twelve health left (n59a, death eight). The hold is bounded to the
      -- corridor's mouth — the same box the panel's fight is bounded to — and
      -- what cannot be shot from there is walked past on the way to the panel,
      -- which is the only thing here that lets the level out.
      try(sic, { index = 596 }, "all", 25)
      try(kill, { index = 596 }, { hold = true, timeout = 20,
        arena = { { -24, -536 }, { 84, -448 } } })
      path({ { 232, -436, 344 }, { 192, -268, 344 }, { 188, -132, 344 }, { 52, -132, 344 } },
           { timeout = 150 })
    end },
    { "crate vent", checkpoint = true, function()
      -- The guide sends Hiro through the vent above the crates. The panel
      -- behind the sidekick door is a return control, not the entrance.
      dk3.sidekick("all", "stay")
      nodepath {-448,-312,344}
      move({-472,-280,376}, {direct = true, radius = 12})
      -- A ragemaster surviving the corridor's blind firing position follows
      -- into this room. Finish him from the crate base before turning away
      -- to climb; his melee hits can leave too little health for the chute.
      kill({index = 102}, {hold = true, weapon = dk3.ammo(4) > 0 and 4 or 2,
        arena = {{-496,-312},{-448,-248}}, timeout = 30})
      weapon(2)
      leap({-472,-280,376}, {-524,-260,416}, {timeout = 20})
      move({-524,-200,448}, {direct = true, radius = 8})
      -- Shotcycler recoil throws the player back off these stacked crates.
      shoot({index = 176}, {weapon = 2, hold = true, fight = false})
      path({{-600,-200,460}, {-792,-200,460}, {-792,-96,460}},
        {direct = true, crouch = true, fight = false, radius = 8, vertical_radius = 12})
      move({-792,-40,-76}, {direct = true, crouch = true, fight = false,
        radius = 12, vertical_radius = 32, timeout = 30})
    end },
    { "moving platforms", checkpoint = true, function()
      -- The supplied nodes do not connect the moving decks. Board them at
      -- their real height, and leave at the upper ledge rather than routing
      -- through the closed return door in the compiled area graph.
      local function climb_from_pool()
        move({-688,-92,-76}, {direct = true, radius = 4, fight = false})
        move({-688,-108,400}, {direct = true, settle = false, radius = 16, vertical_radius = 12, fight = false, timeout = 90})
        move({-736,-80,344}, {direct = true, radius = 12, vertical_radius = 16, fight = false})
      end
      climb_from_pool()
      -- The platform frame hides the sphere from the ladder landing. The
      -- supported takeoff lip has a clear lane before boarding any deck.
      -- Keep the muzzle clear of the frame as well as the crosshair. The
      -- edge at y=-19 admits a sight ray but clips the offset Ion round.
      move({-752,0,344}, {direct = true, radius = 2, fight = false})
      weapon(2, {fight = false})
      try(shoot, {index = 99}, {hold = true, weapon = 2, fight = false, timeout = 8})
      -- The frame clips low shots. A short stationary hop clears it without
      -- switching to a recoil weapon on this narrow ledge.
      for _ = 1, 8 do
        local sphere = dk3.entity {index = 99}
        if not sphere or sphere.health <= 0 then break end
        -- Hand the shot to the pilot during ascent, rather than after the
        -- default 450ms jump action has already passed its clear apex.
        jump({duration = 0.1, fight = false, weapon = 2})
        try(shoot, {index = 99}, {hold = true, weapon = 2,
          fight = false, timeout = 0.6})
      end
      local sphere = dk3.entity {index = 99}
      expect(not sphere or sphere.health <= 0, "the platform sphere is cleared before boarding")
      for _, foe in ipairs({99,100}) do
        try(kill, {index = foe}, {hold = true, weapon = 2, timeout = 15,
          arena = {{-752,-100},{-720,-64}}})
      end
      -- The first observed pairing leaves the second deck over300 units
      -- below the takeoff. Wait one initial boarding window on fixed floor.
      local defer_first_boarding = true
      local function board(index, from, takeoff, current, offset, launch_below, descending_landing)
        -- XY belongs to the moving deck; its height keeps changing during
        -- the run-up. Ground support, not the old sampled height, settles it.
        if from then move(from, {direct = true, radius = 8, fight = false}) end
        if current and index ~= 172 then
          move({index = current}, {around = offset, direct = true, radius = 8,
            vertical_radius = 16, fight = false})
        end
        local previous_height = z()
        local previous_target_height = (dk3.entity {index = index}).z + 320
        local next_phase_log = 0
        local unsafe_wait = false
        local saw_boarding_window, skipped_boarding_window = false, false
        wait_until(function()
          local deck = dk3.entity {index = index}
          local height = z()
          local source_rising = height > previous_height
          previous_height = height
          local target_descending = deck and deck.z + 320 < previous_target_height
          local target_rising = deck and deck.z + 320 > previous_target_height
          if deck then previous_target_height = deck.z + 320 end
          if (index == 170 or index == 173) and dk3.time() >= next_phase_log then
            next_phase_log = dk3.time() + 500
            log(string.format("deck %d phase: source %.0f target %.0f descending %s",
              index, height, deck.z + 320, tostring(target_descending)))
          end
          local rising_allowance = target_descending and (current and 96 or 16) or -120
          if index == 173 then rising_allowance = target_descending and 32 or -80 end
          if index == 170 then rising_allowance = target_descending and 32 or -80 end
          if index == 171 then rising_allowance = -32 end
          if index == 172 and not target_descending then rising_allowance = -8 end
          local drop = index == 173 and 120 or index == 170 and 320 or 160
          local ready = deck and deck.z + 320 >= height - drop and deck.z + 320 < height + rising_allowance
            and (not launch_below or height <= launch_below)
            and (not descending_landing or target_descending)
            -- Ground contact adds a fractional-unit separation. Admit the
            -- nominal 400-height sample before the train reaches the roof.
            and (index ~= 173 or (height >= 380 and height <= 401))
            and (index ~= 175 or target_descending)
            and (index ~= 170 or (height >= 120 and height <= 351))
            -- Board the fourth deck while it rises toward the fixed ledge.
            -- Walking onto a descending deck adds a long, damaging fall.
            and (index ~= 171 or (target_rising and deck.z + 320 >= 280
              and deck.z + 320 <= 320))
          if index == 175 and defer_first_boarding then
            -- A pool/ladder retry can return to the same unsafe pairing of
            -- the two deck cycles. Let this boarding window pass once.
            if saw_boarding_window and not ready then skipped_boarding_window = true end
            if ready and not skipped_boarding_window then
              saw_boarding_window, ready = true, false
            end
          end
          if ready then return true end
          -- These two decks rise into a low fixed frame. A missed phase is
          -- retried from the pool, rather than waiting to be crushed above it.
          unsafe_wait = source_rising and ((current == 175 and height > 401)
            or (current == 173 and height > 351))
          return unsafe_wait
        end, {timeout = 60, fight = dk3.ammo(2) > 0, weapon = 2, crouch = true,
          stance = current and {index = current} or from,
          around = offset or {0,0,0}, reason = "the next moving deck reaches jumping height"})
        if unsafe_wait then
          if current == 175 then defer_first_boarding = true end
          log(string.format("deck %d has no safe departure phase; returning to the pool", index))
          return false
        end
        if index == 175 then defer_first_boarding = false end
        if current then takeoff = {takeoff[1],takeoff[2],z()} end
        local deck = dk3.entity {index = index}
        log(string.format("jump to deck %d: player %.0f,%.0f,%.0f; deck %.0f,%.0f,%.0f",
          index,x(),y(),z(),deck.x,deck.y,deck.z + 320))
        local landed
        if index == 171 then
          -- Aim past the fixed ledge's overlap, then settle onto the offset.
          -- The offset itself is still above the ledge during the jump.
          landed = try(leap, takeoff, {index = index}, {around = {0,0,0},
            pace = 1, weapon = 2, fight = false, timeout = 10})
        else
          landed = try(leap, takeoff, {index = index}, {pace = 1, fight = false, timeout = 30,
            around = index == 173 and {0,40,0} or {0,0,0}})
        end
        if not landed then
          local current = dk3.entity {index = index}
          log(string.format("missed deck %d: now %.0f,%.0f,%.0f; surface %.0f,%.0f,%.0f",
            index,x(),y(),z(),current.x,current.y,current.z + 320))
          return false
        end
        local settled_at = dk3.time() + (index == 173 and 0 or 150)
        wait_until(function() return dk3.time() >= settled_at end,
          {timeout = 1, fight = false, crouch = true, stance = {index = index},
            around = index == 171 and {-40,40,0}
              or index == 173 and {0,40,0} or {0,0,0},
            reason = "the moving landing settles"})
        return true
      end
      local function cross_decks()
        if not board(175, {-736,-88,344}, {-736,-16,344}) then return false end
        -- Wait at the centre: its eastern edge rises underneath the fixed
        -- frame and can pin a rider before the train reverses. The run-up to
        -- the edge happens only after the lower launch phase is qualified.
        if not board(173, nil, {-656,256,z()}, 175, {0,0,0}) then return false end
        -- Depart on the low part of this cycle to clear the fixed overhead
        -- frame, using the south edge for a short run-up.
        if not board(170, nil, {-512,208,z()}, 173, {0,40,0}) then return false end
        -- The fixed acro ledge separates these two decks. Crossing below its
        -- top hits its west wall; ride up first and take the authored boost.
        move({index = 170}, {around = {40,0,0}, direct = true, radius = 8,
          vertical_radius = 16, fight = false})
        wait_until(function() return z() >= 344 end,
          {timeout = 60, fight = false, stance = {index = 170}, around = {40,0,0},
            reason = "the deck reaches the acro ledge"})
        -- The whole 76-unit ledge is a valid landing; a rising source deck
        -- can carry the body past its centre while still landing on its floor.
        leap({-448,-48,z()}, {-418,-48,376}, {pace = 0.45, radius = 40,
          vertical_radius = 16, fight = false})
        pickup({index = 75}, {direct = true, fight = false})
        move({-432,-48,376}, {direct = true, radius = 4, fight = false})
        -- Its orbit brings the sphere out from behind the platform frame.
        -- Keep watching and finish it from this fixed ledge before waiting
        -- for the next deck; a single visibility sample can miss that window.
        kill({index = 99}, {hold = true, weapon = 2,
          arena = {{-432,-60},{-384,-36}}, timeout = 30})
        if not board(171, {-432,-48,376}, {-380,-48,376}) then return false end
        if not board(172, nil, {-340,32,z()}, 171, {-40,40,0}, 320) then return false end
        shoot({index = 161}, {weapon = 2, hold = true})
        move({index = 172}, {around = {40,-24,0}, direct = true, radius = 8,
          vertical_radius = 16, fight = false})
        local previous_vent_height = (dk3.entity {index = 172}).z + 320
        wait_until(function()
            local height = (dk3.entity {index = 172}).z + 320
            local rising = height > previous_vent_height
            previous_vent_height = height
            return rising and height >= 436
          end,
          {timeout = 60, fight = false, stance = {index = 172}, around = {40,-24,0},
            reason = "the final platform reaches the vent"})
        -- The opened front grate leads straight onto the vent floor. The
        -- roof secret needs the acro boost; campaign travel must also work
        -- after waiting out a slow platform phase has exhausted that boost.
        move({-280,176,460}, {direct = true, radius = 8,
          vertical_radius = 16, fight = false, timeout = 10})
        move({-280,176,456}, {direct = true, radius = 8, vertical_radius = 16, fight = false})
        return true
      end
      for attempt = 1, 4 do
        if cross_decks() then return end
        if attempt < 4 then
          log(string.format("platform phase retry %d: use the pool and its ladder", attempt))
          move({-600,128,-104}, {direct = true, radius = 16,
            vertical_radius = 32, fight = false, weapon = 2, timeout = 20})
          climb_from_pool()
        end
      end
      error("no safe platform crossing after four ordinary attempts", 0)
    end },
    { "vent return", checkpoint = true, function()
      move({-200,176,460}, {direct = true, radius = 16, fight = false})
      shoot({index = 505}, {weapon = 2, hold = true})
      -- Walk around the console's solid body after dropping from the vent.
      -- The supplied diagonal node crosses its top, 58 units above the floor.
      path({{-124,203,344},{-124,64,344},{88,64,344},{88,-20,344}},
        {direct = true, radius = 12, fight = false, timeout = 20})
      use {index = 646}
      wait_until(opened(647), {timeout = 20, reason = "the return panel admits the companions"})
      -- Mikiko only has her close weapon here and deliberately keeps away
      -- from the ceiling laser turret. Clear it before waiting for her to
      -- cross its firing lane through the opened return passage.
      -- The opening is west of the console. A direct hunt from x88 tries
      -- to climb the solid wall. The west lane stays on the floor; the
      -- raised console edge at x20 blocks the approach farther south.
      path({{0,-20,344},{0,-96,344},{0,-224,344}},
        {direct = true, radius = 8, fight = false, timeout = 20})
      kill({index = 13}, {weapon = 2, timeout = 90})
      move({20,-96,344}, {direct = true, radius = 12, fight = false, timeout = 30})
      dk3.sidekick("all", "follow")
      regroup(250, 120)
      -- Past the panel at last, and the wall's opening is the only way through:
      -- met before walking into it, since the corridor's mouth is where that
      -- worker has its own ground.
      try(kill, { index = 600 }, { hold = true, timeout = 20 })
      path({ { 20, -60, 344 }, { 13, 4, 344 }, { 93, 204, 343 }, { 93, 364, 343 } }, { timeout = 150 })
      expect(y() > 300, "not north through the doorway")
      -- The changelevel (ctl 98) stands in the passage east at x 240..336.
      exit "e1m7b"
    end },
  }(visit, resumed)
end)

-- The Vault's second half: guard posts, hatch/shaft, companion return,
-- ceiling tubes, three subsidiary brains, the central brain and two psyclaws.
level("e1m7b", function(visit, resumed)
  local function take(index)
    local item = dk3.entity {index = index}
    if item and item.visible and item.wanted ~= false then
      nodepath({index = index}, {standoff = 64})
      pickup {index = index}
    end
  end
  local function operate(index)
    local control = dk3.entity {index = index}
    if control and ((control.uses or 0) > 0 or control.state == "open" or control.state == "opening") then return end
    nodepath({index = index}, {standoff = 96})
    use {index = index}
  end
  local function breakable(index)
    local object = dk3.entity {index = index}
    if object and (object.health or 0) > 0 then shoot({index = index}, {timeout = 90}) end
  end
  return stages {
    { "guard room", function()
      -- The arrival corridor (areas 2411/2405, x 401..495) opens south into a
      -- room (2397) holding a battle boar and two mishimaguards and north into
      -- another (2391) holding two more. All of them shoot the corridor the
      -- spawn stands in: the run before this one died thirteen times without
      -- leaving the room. Nothing is walked past. The south room is taken on
      -- its own floor, where the health station in its alcove (ctl 79, at
      -- 576,-240,328) stands behind the fight rather than across the map.
      -- (The room's third guard, ctl 335, is authored 12288 — the Ronin and
      -- Samurai bits — and the Samurai skill these runs play at drops it, so
      -- it is named nowhere below and would only be hunted if it spawned.)
      dk3.sidekick("all", "stay")
      move({ 576, -160, 328 }, { timeout = 40 })
      local south = { { 500, -200 }, { 715, -25 } }
      for _, foe in ipairs({ 26, 103, 102 }) do
        try(kill, { index = foe }, { hold = true, timeout = 40, arena = south })
      end
      recover(0.8, 900)
    end },
    { "north post", checkpoint = true, function()
      -- Back to the corridor's mouth and into the room north, fought from its
      -- middle: the two guards stand on its far wall (522,226 and 658,226) with
      -- near two hundred units of floor between them and the doorway, and the
      -- doorway is where a party met at range gives ground away.
      move({ 592, 150, 328 }, { timeout = 40 })
      local north = { { 500, 5 }, { 683, 235 } }
      for _, foe in ipairs({ 336, 337 }) do
        try(kill, { index = foe }, { hold = true, timeout = 40, arena = north })
      end
      recover(0.8, 900)
      dk3.sidekick("all", "follow")
      try(regroup, 250, 90)
      expect(y() > 0, "not north into the room above the arrival corridor")
    end },
    { "the hall", checkpoint = true, function()
      nodepath {index = 173}
      for _, index in ipairs({3,173,174,175,176,172,181}) do take(index) end
      operate(139)
      dk3.sidekick("all", "stay")
      nodepath {512,1520,224}
      take(71)
      nodepath {520,1824,1240}
      take(72)
    end },
    { "shaft descent", checkpoint = true, function()
      weapon(2, {fight = false})
      shoot({index = 141}, {weapon = 2, hold = true})
      -- The three rotations turn the beam toward the health ledge. The
      -- initial upward leg is separated from it by the diagonal shaft wall.
      move({620,1824,1100}, {direct = true, settle = false, radius = 32,
        vertical_radius = 24, fight = false})
      move({index = 162}, {around = {0,0,0}, direct = true, radius = 8, vertical_radius = 16,
        fight = false, timeout = 30})
      wait_until(function()
        local deck = dk3.entity {index = 162}
        local heading = deck.yaw % 360
        return heading >= 280 and heading <= 290 and deck.z + 28 >= 328 and deck.z + 28 <= 360
      end, {timeout = 180, stance = {index = 162}, around = {0,0,0},
        reason = "the shaft lift passes the health ledge"})
      leap({400,1956,z()}, {288,1920,328}, {pace = 0.6, radius = 40,
        vertical_radius = 24, fight = false})
      take(146)
      move({288,1984,328}, {direct = true, radius = 12, fight = false})
      take(239)
      move({368,1900,168}, {direct = true, radius = 16, vertical_radius = 24, fight = false})
      move({368,1984,200}, {direct = true, radius = 12, fight = false})
      -- Use the close-range glove in this flooded mouth. The Ion cannot
      -- discharge safely in water and a ranged firing-position search keeps
      -- bobbing below the vent until the player runs out of air.
      shoot({index = 145}, {weapon = 1, hold = true, fight = false, timeout = 20})
      move({288,1984,216}, {direct = true, crouch = true, fight = false, radius = 8})
      move({160,1984,208}, {direct = true, crouch = true, fight = false, radius = 8})
      move({160,1852,144}, {direct = true, crouch = true, fight = false, radius = 8})
      move({64,1852,144}, {direct = true, crouch = true, fight = false, radius = 8})
      -- The fan at the vent's west end lifts the player through its ceiling;
      -- its upper trigger breaks that ceiling. Stay in the upward draft.
      move({-112,1852,328}, {direct = true, fight = false, radius = 8,
        vertical_radius = 16, timeout = 30})
      leap({-120,1852,328}, {-112,1800,344}, {fight = false, pace = 0.8,
        radius = 64, vertical_radius = 24})
      nodepath {index = 86}
      operate(86)
      dk3.sidekick("all", "follow")
      for _, index in ipairs({67,68,69,70}) do take(index) end
    end },
    { "vault entrance", checkpoint = true, function()
      nodepath {index = 113}
      operate(113)
      nodepath {208,2720,248}
      dk3.sidekick("all", "stay")
      for _, index in ipairs({74,75,369,76,367,368}) do take(index) end
    end },
    { "ceiling tubes", checkpoint = true, function()
      -- Keep to the perimeter's raised ammunition ledges, above the electric
      -- floor. The tubes' real destruction opens their respective brain covers.
      nodepath {208,2720,248}
      breakable(454)
      breakable(457)
      -- Stay on the west ammunition ledge. The node graph cuts across the
      -- still-closed central dais (125), which is released by later events.
      path({{208,2832,248},{208,3088,248},{208,3232,248}},
        {direct = true, radius = 16, fight = false})
      breakable(17)
    end },
    { "three brains", checkpoint = true, function()
      for _, index in ipairs({98,340,341}) do breakable(index) end
      wait_until(opened(37), {timeout = 30, reason = "all three brains release the main forcefield"})
    end },
    { "central brain", checkpoint = true, function()
      local ranged = dk3.ammo(5) >= 2 and 5 or 2
      -- The closed dais blocks the west ledge's view. Reach the northern
      -- perimeter before firing; the generic approach points across that
      -- dais, whose release depends on destroying this very brain.
      if x() < 800 then
        path({{208,3232,248},{560,3256,248}},
          {direct = true, radius = 12, weapon = ranged, timeout = 30})
      end
      -- Retain combat evasion on the clear northern ledge. Standing still
      -- under these tracking turrets loses even a well-armored arrival.
      shoot({index = 92}, {weapon = ranged,
        arena = {{480,3240},{704,3280}}, timeout = 90})
      wait(5)
      dk3.sidekick("all", "follow")
      for _, index in ipairs({27,28}) do
        local turret = dk3.entity {index = index}
        if turret and (turret.health or 0) > 0 and dk3.visible {index = index} then
          try(kill, {index = index}, {hold = true, weapon = 2, timeout = 8})
        end
      end
      -- The north-east ledge's health is reachable once the brain is gone.
      -- Use the real box before exposing a weak arrival to both guardians.
      local health_box = dk3.entity {index = 73}
      if dk3.health() < 80 and health_box and health_box.visible and health_box.wanted ~= false then
        -- Leave the ammunition alcove southward before heading east. Its
        -- north edge ends at a pillar, so a diagonal exit meets solid wall.
        path({{x(),3232,248},{880,3232,248},{1048,3232,248}},
          {direct = true, radius = 12, weapon = 2, timeout = 20})
        pickup({index = 73}, {direct = true, weapon = 2, timeout = 15})
      end
      for _, foe in ipairs(dk3.threats(3000)) do
        if foe.class == "psyclaw" then
          -- The dais hides its occupants from a player directly beneath it.
          -- Meet each guardian from its nearest end, outside that shadow,
          -- rather than hunting up through the platform's closed side.
          local guardian = dk3.entity {id = foe.id}
          local north = guardian and guardian.y > 2976
          local stand_y = north and 3232 or 2736
          -- Circle the east arm on the real floor. The area's route points
          -- sit above the dais and cannot qualify this lower approach.
          path({{880,y(),248},{880,stand_y,248},{560,stand_y,248}},
            {direct = true, radius = 12, weapon = 2, timeout = 30})
          local arena = north and {{512,3200},{608,3248}} or {{512,2720},{608,2768}}
          local defeated, failure = pcall(kill, {id = foe.id}, {timeout = 120,
            hold = true, arena = arena, weapon = dk3.ammo(5) > 0 and 5 or 0})
          if not defeated then
            save("vault-guardian-failure")
            error(failure, 0)
          end
        end
      end
      wait_until(function()
        local counter = dk3.entity {index = 82}
        return counter and (counter.uses or 0) >= 1
      end, {timeout = 30, reason = "both psychic guardians complete the vault ending"})
      cinematic()
      exit "e2m1a"
    end },
  }(visit, resumed)
end)

local chain = {
  "e1m2a", "e1m2b", "e1m3a", "e1m3b", "e1m4a", "e1m4b", "e1m4c",
  "e1m5a", "e1m5b", "e1m6a", "e1m6b", "e1m6c", "e1m7a", "e1m7b", "e2m1a",
}
-- Maps without an authored route yet: head for the forward exit, operating
-- reachable controls when the area graph has no route (see advance()).
for index = 15, #chain - 1 do
  local map, destination = chain[index], chain[index + 1]
  level(map, function() progress(destination) end)
end
