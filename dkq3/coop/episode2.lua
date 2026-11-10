-- SPDX-License-Identifier: GPL-2.0-or-later
-- Authored Episode 2 progression. Ordinals are supplied BSP entity identities.
-- Implementation is not campaign acceptance; see docs/native-acceptance.md.
local function take(index, opts)
  local item = dk3.entity { index = index }
  if item and item.visible and item.wanted ~= false then
    local path, collect = {standoff = 96, timeout = 60}, {direct = true, cautious = true}
    for key, value in pairs(opts or {}) do
      if key ~= "collect_direct" then path[key], collect[key] = value, value end
    end
    if opts and opts.areas then
      -- An area approach must bypass the supplied ground-node corridor.
      -- Merely forwarding this option leaves nodepath's control planner
      -- free to operate an unrelated door on the far side of the map.
      path.radius, path.vertical_radius = 96, 48
      move({index = index}, path)
    else
      nodepath({ index = index }, path)
    end
    if opts and opts.collect_direct ~= nil then
      collect.direct = opts.collect_direct
    elseif not opts or opts.direct == nil then
      -- A disconnected supplied graph can stop on the other side of a wall.
      -- Only collect straight ahead when the standing hull has a clear lane.
      local px, py, pz = dk3.position()
      local floor = dk3.trace({item.x,item.y,item.z + 32}, {item.x,item.y,item.z - 96}, true)
      local height = floor.start_solid and item.z or floor.z
      local lane = dk3.trace({px,py,pz + 2}, {item.x,item.y,height + 2}, true)
      collect.direct = not lane.start_solid and lane.fraction >= 1
    end
    pickup({ index = index }, collect)
  end
end

-- Multiple exits to one map lead to different entrances: select the seam,
-- not merely the destination BSP (especially the G and I rune branches).
local function crossing(index, opts)
  local approach = {standoff = 160}
  for key,value in pairs(opts or {}) do approach[key] = value end
  if not opts or not opts.areas then nodepath({ index = index }, approach) end
  exit({ index = index }, { timeout = 180 })
end

local function operate(index, opts)
  local function completed()
    local entity = dk3.entity {index = index}
    return entity and ((entity.uses or 0) > 0 or entity.state == "open" or entity.state == "opening")
  end
  if completed() then return end
  local approach = {standoff = 160}
  for key, value in pairs(opts or {}) do approach[key] = value end
  if opts and opts.areas then
    approach.radius, approach.vertical_radius = 96, 48
    move({index = index}, approach)
  else
    nodepath({ index = index }, approach)
  end
  -- The ordinary pilot may operate this gate while approaching it.
  if not completed() then use({index = index}, opts) end
end

level("e2m1a", function(visit, resumed)
  return stages {
    { "discus", function() take(38) end },
    { "statue-tiles", checkpoint = true, function()
      nodepath { index = 44 }
      use { index = 44 }
      use { index = 45 }
    end },
    { "underwater-passage", checkpoint = true, function()
      wait_until(function()
        local state = dk3.mover { index = 47 }
        return state == "open" or state == "opening"
      end, { timeout = 25, reason = "statue drain and delayed underwater door" })
      nodepath {-2872,-608,776}
      move({-2872,-608,776}, {direct = true, radius = 8, vertical_radius = 12, crouch = true, fight = false})
      move({-2872,-512,208}, {direct = true, radius = 8, vertical_radius = 12, crouch = true, fight = false})
      take(27, {direct = true})
    end },
    { "lower-pool-tunnel", checkpoint = true, function()
      nodepath({index = 28}, {crouch = true, fight = false, timeout = 90})
      pickup({index = 28}, {cautious = true})
      take(29)
      -- Clear the west jamb before turning toward the upper exit. Its
      -- compiled entrance hugs the wall too closely for the standing hull.
      move({-552,48,552}, {radius = 8, vertical_radius = 16, timeout = 90})
      crossing(25)
    end },
  }(visit, resumed)
end)
level("e2m1b", function(visit, resumed)
  return stages {
    { "pool-ledge", function()
      nodepath { index = 28 }
      recharge { index = 28 }
      nodepath { -796, -2835, 1016 }
      move({ -692, -2835, 704 }, { direct = true, radius = 56 })
    end },
    { "ruins", checkpoint = true, function()
      -- Fight the entrance ambush from the open doorway before crossing the
      -- room for supplies. The guide calls for backing away with the discus;
      -- a loot waypoint alone lets the crowd surround the player.
      nodepath {20, -3079, 704}
      -- The upper-room spiders are almost 500 units above this floor and
      -- cannot be hunted from this doorway. Deal with the ground ambush;
      -- a spherical room-wide clear also chased those upper spiders.
      for _, foe in ipairs({64, 63, 206, 420}) do
        kill({index = foe}, {hold = true, timeout = 90})
      end
      take(4)
      take(3)
      -- Enter the moat from the room, then follow its low tunnel north and
      -- east into the waterway. The western spur ends at solid masonry.
      nodepath {3730, -3432, 736}
      move({3730, -3432, 656}, {direct = true, radius = 8})
      move({3400, -3432, 656}, {direct = true, radius = 8, crouch = true, fight = false})
      pickup({index = 31}, {direct = true})
      move({2728, -3432, 656}, {direct = true, radius = 8, crouch = true, fight = false})
      move({2728, -2728, 656}, {direct = true, radius = 8, crouch = true, fight = false})
      move({3000, -2728, 600}, {direct = true, radius = 8, crouch = true, fight = false})
      move({3150, -2728, 528}, {direct = true, radius = 8, crouch = true, fight = false})
      move({3272, -2728, 528}, {direct = true, radius = 8, crouch = true, fight = false})
      move({3272, -2360, 528}, {direct = true, fight = false})
    end },
    { "statue-pool", checkpoint = true, function()
      move({ 3272, -2200, 270 }, { direct = true, radius = 48 })
      move({ 2937, -2230, 320 }, { direct = true, radius = 28 })
      move({ 2937, -2048, 320 }, { direct = true, radius = 28 })
      crossing(39)
    end },
  }(visit, resumed)
end)
level("e2m1c", function(visit, resumed)
  return stages {
    { "horn", function()
      nodepath {index = 25}
      recharge {index = 25}
      take(58)
    end },
    { "summon-charon", checkpoint = true, function()
      local button = dk3.entity {index=56}
      if button and (button.uses or 0) > 0 then return end
      local px = dk3.position()
      if px > 2860 then
        -- Cross the paired leaves through the centre aisle before descending
        -- toward the horn. The lower node's chord clips the threshold while
        -- a guard is fought in the opening; this supported approach avoids it.
        nodepath({3100,-1323,352})
        move({2980,-1323,352},{direct=true,radius=8,fight=false})
        for _,index in ipairs {139,140} do
          if dk3.mover {index=index}=="closed" then use {index=index} end
        end
        move({2980,-1323,352},{direct=true,radius=8,fight=false})
        wait_until(function()
          return dk3.mover {index=139}=="open" and dk3.mover {index=140}=="open"
        end,{timeout=8,fight=false,reason="paired leaf clearance"})
        move({2820,-1323,341},{direct=true,radius=12,vertical_radius=24,fight=false,timeout=10})
      end
      operate(56)
    end },
    { "cracked-wall", checkpoint = true, function()
      local spider = dk3.entity {index = 27}
      if spider and spider.health and spider.health > 0 then
        nodepath({index = 27}, {standoff = 450})
        kill({index = 27}, {timeout = 180})
      end
      -- This wall is absent on Ronin and may already have been broken.
      if dk3.entity {index = 158} then
        nodepath({index = 158}, {standoff = 200})
        shoot({index = 158}, {weapon = 9})
      end
      -- The two statue tiles open the nearby weapon niche. Stock up before
      -- entering the crypt's successive skeleton ambushes.
      if not dk3.has_weapon(11) then
        operate(35)
        operate(36)
        take(31)
      end
    end },
    { "crypt-entrance", checkpoint = true, function()
      -- Keep the finite venomous rounds for the four-statue ambush. The
      -- discus handles these individual encounters and the breakable planks.
      if y() < 1570 then
      if y() < 700 then
        local health, maximum = dk3.health()
        if health < maximum * 0.6 then
          nodepath {index=25}
          recharge({index=25},{timeout=25})
        end
        nodepath({2116,596,421}, {weapon = 9})
        move({2100, 650, 408}, {direct = true, radius = 8, crouch = true, weapon = 9})
        move({2100, 740, 408}, {direct = true, radius = 8, crouch = true, weapon = 9})
        move({2070, 820, 400}, {direct = true, radius = 16, crouch = true, weapon = 9})
      end
      nodepath({2363,1469,304}, {weapon = 9})
      move({2367, 1503, 316}, {direct = true, radius = 2, fight = false})
      local plank = dk3.entity {index = 177}
      if plank and plank.health and plank.health > 0 then shoot({index = 177}, {weapon = 9}) end
      move({2360, 1616, 304}, {direct = true, radius = 24, crouch = true, weapon = 9})
      end
      -- This named checkpoint resumes inside the entry stage. Do not walk
      -- backwards to the planks, and retain the previous healthy checkpoint
      -- when the player is too hurt to make this one useful.
      local health, maximum = dk3.health()
      if health >= maximum * 0.5 then save("crypt-planks") end
      local skeleton = dk3.entity {index = 165}
      if skeleton and skeleton.health and skeleton.health > 0 then kill({index = 165}, {weapon = 9}) end
    end },
    { "pit-crossing", checkpoint = true, function()
      move({2464, 1616, 304}, {direct = true, radius = 8})
      leap({2492, 1616, 304}, {2704, 1616, 304}, {fight = false, timeout = 15})
    end },
    { "drachma", checkpoint = true, function()
      nodepath({2787,1607,305},{weapon=9})
      -- Both stacked boards fill this doorway. Breaking only the upper
      -- board leaves the lower one across the standing and crouched hull.
      for _,index in ipairs({172,173}) do
        local plank=dk3.entity{index=index}
        if plank and (plank.health or 0)>0 then shoot({index=index},{weapon=9}) end
      end
      take(57, {weapon = 9})
    end },
    { "statue-ambush", checkpoint = true, function()
      -- Taking the coin wakes these four statue occupants. Clear the room
      -- before following the fallen-column exit back toward Charon.
      clear({class = "monster_skeleton", around = {2592,2056,696}, radius = 450, timeout = 180,
        weapon = dk3.ammo(11) > 0 and 11 or 0})
      expect(dk3.hostiles(450, {2592,2056,696}) == 0, "the drachma room ambush is clear")
    end },
    { "ferry", checkpoint = true, function()
      wait_until(function() return dk3.mover {index = 181} == "open" end,
        {timeout = 30, reason = "coin sequence opens the fallen-column shortcut"})
      nodepath {2418,1586,528}
      -- The supplied nodes omit this short upper-corridor connection.
      move({2164,1624,528}, {direct = true, radius = 24})
      nodepath {index = 181}
      crossing(54)
    end },
  }(visit, resumed)
end)
level("e2m2a", function(visit, resumed)
  return stages {
    { "canyon", function()
  take(92)
  take(20)
  -- The guide's sunflare alcove supplies the ranged weapon needed for the
  -- creatures above the canyon. Do not hunt a high griffon with only a sword.
  take(62)
  -- Use the supplies beside the canyon approach before drawing its entrance
  -- pack onto the narrow rocks. These are placed pickups, not retry grants.
  take(63, {areas=true,weapon=dk3.ammo(11)>0 and 11 or 9})
  take(109, {areas=true,weapon=dk3.ammo(11)>0 and 11 or 9})
  take(217, {areas=true,weapon=dk3.ammo(11)>0 and 11 or 9})
  -- Follow the canyon's bend, fighting the creatures actually met on it.
  -- The skeleton behind the southern rock and the high griffon cannot be
  -- cleared from the western bank. Use venomous rounds on this moving leg;
  -- advancing into a freshly thrown sunflare burns its owner.
  nodepath({2792,328,216}, {weapon = dk3.ammo(11) > 0 and 11 or 0})
  move({2816,336,229}, {direct = true, radius = 4, crouch = true})
    end },
    { "black-rocks", checkpoint = true, function()
  -- Clear the entrance pack before committing to the narrow rock crown. Dodging
  -- a griffon or a spider while crawling here walks off the supporting lip.
  -- When the canyon has exhausted the Venomous, answer the attackers already
  -- in striking range with the sword before aiming the returning discus at
  -- a flying target. Otherwise several close enemies attack during its flight.
  if dk3.ammo(11) == 0 then
    clear {radius=240,vertical_radius=80,weapon=8,timeout=60}
  end
  for _, foe in ipairs {142, 83, 97, 99, 66} do
    local enemy = dk3.entity {index = foe}
    if enemy and (enemy.health or 0) > 0 then
      kill({index = foe}, {weapon = dk3.ammo(11) > 0 and 11 or 9, timeout = 45})
    end
  end
  move({2880,272,289}, {direct = true, radius = 6, vertical_radius = 6, fight = false})
  save("cave-first-rock")
  -- Settle on the first rock, then keep the crouched hull in the middle of
  -- its crown. The old western points start inside the adjacent rock wall.
  local settled = dk3.time() + 350
  wait_until(function() return dk3.time() >= settled end, {crouch = true, fight = false})
  for _, p in ipairs {{2880,256,289},{2880,240,289},{2880,224,289},
    {2880,208,289},{2896,192,285},{2912,176,282},{2928,160,281},
    {2912,144,272},{2896,128,264}} do
    move(p, {direct = true, radius = 6, vertical_radius = 20, crouch = true, fight = false})
  end
  for _, p in ipairs {{2832,64,241},{2768,0,226},{2768,-64,211},
    {2768,-128,196},{2768,-192,181},{2768,-256,203},{2704,-256,254},
    {2704,-192,293},{2704,-128,332},{2736,-96,351}} do
    move(p, {direct = true, radius = 6, vertical_radius = 20})
  end
  save("black-rocks-jump")
  leap({2736,-96,351}, {2760,-80,376}, {fight = false, timeout = 15})
  move({2760,-80,376}, {direct = true, radius = 6, vertical_radius = 8})
  leap({2760,-80,376}, {2736,-144,409}, {fight = false, timeout = 15})
  for _, p in ipairs {{2736,-208,424},{2736,-272,424},{2736,-304,456}} do
    move(p, {direct = true, radius = 6, vertical_radius = 20})
  end
  save("black-rocks-top")
    end },
    { "summit", checkpoint = true, function()
  for _, p in ipairs {{2720,-320,456},{2656,-256,485}} do
    move(p, {direct = true, radius = 6, vertical_radius = 20})
  end
  -- The next rock has a rising north face. Follow that face around to its
  -- top instead of jumping straight at its taller southern edge.
  for _, p in ipairs {{2640,-240,491},{2640,-224,497},{2640,-208,504},
    {2624,-192,510},{2624,-176,517},{2624,-160,523},{2608,-144,529},
    {2592,-160,541},{2576,-176,550},{2560,-192,559},{2544,-208,567},
    {2528,-224,568},{2512,-240,568},{2496,-224,568},
    {2448,-224,545},{2424,-224,527},{2400,-224,509}} do
    -- This exposed face needs normal step-recovery hops; unlike the first
    -- crown it has headroom. A held crouch keeps the body below its next lip.
    move(p, {direct = true, radius = 6, vertical_radius = 12, fight = false})
  end
  save("black-rocks-summit")
  move({2280,-224,144}, {direct = true, radius = 12, vertical_radius = 24, fight = false})
  save("cave-pool")
    end },
    { "pool-tunnel", checkpoint = true, supplies = false, function()
  -- The explicit far-rim save belongs to this stage. A restored player
  -- already outside the tunnel continues onward rather than swimming back.
  if x() < 2000 and z() > 180 then return end
  -- The underwater opening bends under a low rock shelf. Keep the body
  -- crouched through the narrow section, then stand to climb the west rim.
  if x() >= 2100 then
  for _, p in ipairs {{2280,-224,144},{2256,-224,144},{2256,-224,136},
    {2232,-224,136},{2232,-232,136},{2232,-232,128},{2224,-232,128},
    {2224,-232,112},{2216,-232,112},{2216,-264,112},{2192,-264,112},
    {2192,-280,112},{2184,-280,112},{2184,-280,104},{2048,-280,104}} do
    move(p, {direct = true, radius = 4, vertical_radius = 3, crouch = true, fight = false})
  end
  end
  for _, p in ipairs {{2048,-280,112},{2032,-280,112},{2032,-280,160},{1984,-280,160},
    {1984,-280,168},{1976,-280,168}} do
    move(p, {direct = true, radius = 4, vertical_radius = 3, crouch = true, fight = false})
  end
  local guard_weapon = dk3.ammo(11) > 0 and 11 or 8
  move({1928,-280,208}, {direct = true, radius = 8, vertical_radius = 12, weapon = guard_weapon})
  local spider = dk3.entity {index = 82}
  if spider and (spider.health or 0) > 0 then
    kill({index = 82}, {weapon = guard_weapon, hold = true, timeout = 20})
  end
  move({1928,-280,208}, {direct = true, radius = 8, vertical_radius = 12, weapon = guard_weapon})
  save("cave-waterway")
    end },
    { "waterway", checkpoint = true, supplies = false, function()
  -- The last dry approach is above the lower waterfall alcove. Dropping
  -- into that alcove ends at a health pickup, below the actual exit hole.
  -- Follow the upper bank even when medicine is not wanted. The lower
  -- waterfall corridor reconnects below the exit and cannot replace it.
  path({{1928,-280,208},{1896,-448,208},{1893,-500,232},{1883,-705,184},
      {1886,-817,240},{1880,-944,256},{1992,-1032,320},{2024,-960,362}},
    {direct=true,cautious=false,radius=16,vertical_radius=24,weapon=dk3.ammo(11)>0 and 11 or 8})
  -- Keep this bank's medicine for the return fight when arriving healthy.
  -- Spending25 points to heal two leaves no reserve after the shelf pack.
  if dk3.health()<=75 then take(53, {standoff = 0}) end
  -- Keep defending on the long return through the occupied cave. Only
  -- the low exit approach needs the smaller hull.
  local function low_exit(point)
    if point[2] > 650 and point[1] > 1900 and point[1] < 2300 then
      return {crouch = true}
    end
  end
  -- Resolve the griffon/spider ambush from the dry high shelf before the
  -- route descends into their narrow waterway. A melee walk through that
  -- descent gives both attackers repeated free hits.
  nodepath({3064,-413,483},{cautious=false,weapon=9,
    segment_options=function()
      local x,y,z=dk3.position()
      for _,index in ipairs({81}) do
        local foe=dk3.entity{index=index}
        if foe and (foe.health or 0)>0 and
            (foe.x-x)^2+(foe.y-y)^2+(foe.z-z)^2<400^2 and dk3.visible{index=index} then
          kill({index=index},{hold=true,weapon=9,timeout=30,
            arena={{x-24,y-24},{x+24,y+24}}})
        end
      end
    end})
  -- Two griffons can reach this shelf together. Keep the fought-through
  -- approach open behind Hiro instead of trading every swoop from one spot.
  for _=1,8 do
    local pursuing=false
    for _,index in ipairs({96,103,143,79}) do
      local foe=dk3.entity{index=index}
      if foe and (foe.health or 0)>0 then pursuing=true break end
    end
    if not pursuing then break end
    local pack_alive=false
    for _,index in ipairs({81,143,103,80,79}) do
      local foe=dk3.entity{index=index}
      if foe and (foe.health or 0)>0 then pack_alive=true break end
    end
    path({{3024,-664,483},{2944,-824,454},{3024,-664,483}},
      {direct=true,cautious=false,weapon=pack_alive and 9 or 8,radius=16,vertical_radius=24})
  end
  save("canyon-shelf-fight")
  local medicine=dk3.entity{index=53}
  if dk3.health()<75 and medicine and medicine.visible and medicine.wanted~=false then
    take(53,{standoff=0,weapon=9,cautious=false})
    nodepath({3064,-413,483},{cautious=false,weapon=9})
  end
  local hx,hy=dk3.position()
  for _,index in ipairs({81,143,103,96,80}) do
    local enemy=dk3.entity{index=index}
    if enemy and (enemy.health or 0)>0 and dk3.visible{index=index} then
      local px,py,pz=dk3.position()
      local close=(enemy.x-px)^2+(enemy.y-py)^2+(enemy.z-pz)^2<128^2
      kill({index=index},{weapon=(index==96 or index==103) and close and 8 or 9,
        hold=true,arena={{hx-48,hy-48},{hx+48,hy+48}},timeout=90})
    end
  end
  -- Retain a real ranged reserve for the next map's first skeleton when
  -- both ordinary stocks were spent on the canyon's flying pack.
  if dk3.ammo(9)==0 and dk3.ammo(11)==0 and dk3.ammo(10)==0 then
    take(59, {areas = true, weapon = 8, cautious = false})
  end
  nodepath({2024,720,416}, {segment_options = low_exit, cautious=false, weapon=dk3.ammo(11)>0 and 11 or 8})
  nodepath({index = 75}, {standoff = 160, segment_options = low_exit, cautious=false, weapon=dk3.ammo(11)>0 and 11 or 8})
  exit({index = 75}, {crouch = true, fight = false, timeout = 180})
    end },
  }(visit, resumed)
end)
level("e2m2b", function(visit, resumed)
  return stages {
    { "ruins-supplies", function()
      -- Entering the first chamber breaks the rear alcove wall. Only then
      -- turn back for the silver armor described by the guide.
      local entry_weapon=dk3.ammo(11)>0 and 11 or
        (dk3.ammo(9)>0 and 9 or (dk3.ammo(10)>0 and 10 or 8))
      nodepath({index = 139}, {weapon = entry_weapon})
      touch {index = 139}
      take(372)
      take(128)
      take(33)
      take(17)
    end },
    { "bridge-approach", checkpoint = true, function()
      nodepath {index = 16}
      recharge {index = 16}
      nodepath {712,2405,424}
    end },
    { "broken-bridge", function()
      local _, bridge_y = dk3.position()
      -- A death after the crossing restores the far-railing save in this
      -- stage. Do not walk back onto the already collapsed bridge.
      if bridge_y < 2800 then
      save("bridge-entry")
      -- The middle deck falls. The surviving right railing has a short
      -- gap; walking the old recorded centreline drops into the river.
      move({816,2405,424}, {direct = true, radius = 8, fight = false})
      move({816,2464,408}, {direct = true, radius = 8, fight = false})
      move({816,2544,392}, {direct = true, radius = 8, vertical_radius = 20})
      move({816,2688,408}, {direct = true, radius = 8, vertical_radius = 12})
      -- The standing jump hits the low beam above the broken span. Duck
      -- across to the far shoulder, then climb its last step to the deck.
      -- At full speed the next frame beyond2719 has already lost support.
      -- Launch before that edge rather than waiting for a point over the gap.
      local function bank_support()
        local px,py,pz=dk3.position()
        local floor=dk3.trace({px,py,pz+0.25},{px,py,pz-2},"floor")
        return py>=2816 and math.abs(px-816)<=32 and math.abs(pz-408)<=16
          and not floor.start_solid and floor.fraction<1 and floor.normal_z>=0.7
          and floor.class=="world" and floor.index==0
      end
      try(leap,{816,2712,408}, {816,2840,408}, {fight = false, crouch = true,
        pace = 1, radius = 40, vertical_radius = 16})
      if not bank_support() then
        local px,py,pz=dk3.position()
        local floor=dk3.trace({px,py,pz+0.25},{px,py,pz-2},"floor")
        -- The breaking piece can catch the first jump before its far end.
        -- Continue from that actual support with one more normal hop.
        expect(py>2719 and py<2816 and not floor.start_solid
          and floor.fraction<1 and floor.normal_z>=0.7 and floor.index==116,
          "supported bridge piece before the final bank hop")
        try(leap,{px,py,pz},{816,2880,408},{fight=false,crouch=true,
          pace=0.8,radius=24,vertical_radius=16})
      end
      expect(bank_support(),"supported stone bank beyond the broken bridge")
      move({816,2880,408}, {direct = true, radius = 8, vertical_radius = 12, fight = false})
      save("bridge-railing")
      end
      crossing(45)
    end },
  }(visit, resumed)
end)
level("e2m2c", function(visit, resumed)
  return stages {
    { "gate", function()
      if z() > 320 then
      operate(129)
      wait_until(function() return dk3.mover {index = 129} == "open" end,
        {timeout = 10, reason = "hammer chamber door fully open"})
      -- Pass the partition's west end before taking the supplied south
      -- turn. The diagonal from the entry trigger catches its north face.
      move({1280,3836,440}, {direct = true, radius = 8, vertical_radius = 16, fight = false})
      -- The opened chamber is directly west along this corridor. Its supplied
      -- graph detours south through the partition before returning to Hammer.
      pickup({index = 61}, {direct = true, timeout = 30})
      move({1208,3389,440}, {timeout = 90})
      for _, index in ipairs {125,123,124} do
        local plank = dk3.entity {index = index}
        if plank and plank.health and plank.health > 0 then shoot {index = index} end
      end
      move({1224,3458,280}, {direct = true, radius = 12, vertical_radius = 20})
      save("ladder-bottom")
      end
      -- The lower hall's supplied graph omits its doorway connection.
      -- Keep this leg downstairs instead of accepting its upper-floor
      -- partial endpoint above the dial.
      nodepath {1407,3782,232}
      move({1644,3791,226}, {direct = true, radius = 16})
      save("lower-hall")
      operate(209)
    end },
    { "mikiko-rescue", checkpoint = true, function()
      nodepath {index = 65}
      touch {index = 65}
      cinematic()
      local mikiko = dk3.entity {class = "mikiko"}
      expect(mikiko and (mikiko.health or 0) > 0, "Mikiko joined after the rescue")
      dk3.sidekick("mikiko", "follow")
    end },
    { "athens", checkpoint = true, function()
      save("mikiko-rescued")
      -- Refill an empty ranged loadout from the nearby lower-hall supplies
      -- before climbing into the skeletons and spiders above the rescue.
      if dk3.ammo(9)==0 and dk3.ammo(11)==0 then
        -- Regroup in the cleared rescue hall before entering the one-body
        -- supply alcove. Following into it parks Mikiko across its approach.
        move({1664,3712,216},{fight=false,weapon=8,radius=8,vertical_radius=24})
        wait_until(function()
          local buddy=dk3.entity{class="mikiko"}
          return buddy and (buddy.x-1664)^2+(buddy.y-3712)^2<128^2
        end,{timeout=30,fight=false,reason="Mikiko leaves the supply alcove approach"})
        dk3.sidekick("mikiko","stay")
        take(47,{areas=true,weapon=8})
        -- Keep the smaller hull through this low supply recess.
        take(53,{areas=true,weapon=8,crouch=true,fight=false})
        dk3.sidekick("mikiko","follow")
        take(59,{areas=true,weapon=10})
      end
      -- Full Hammer quakes cost health and launch their user. Keep a normal
      -- attack while supplies and the exit cross these ledges.
      local weapon=dk3.ammo(9)>0 and 9 or dk3.ammo(11)>0 and 11 or 8
      if dk3.health() < 100 then try(take, 47, {weapon=weapon}) end
      take(61, {weapon=weapon})
      if dk3.health() < 100 then try(take, 48, {weapon=weapon}) end
      nodepath({index = 68}, {standoff = 160, weapon=weapon})
      if dk3.health() < 100 then try(take, 235, {weapon=weapon}) end
      exit({index = 68}, {timeout = 180, weapon=weapon})
    end },
  }(visit, resumed)
end)
level("e2m3a", function(visit, resumed)
  return stages {
    { "discus", function()
      local item = dk3.entity {index = 69}
      if item and item.visible and item.wanted ~= false then
        -- The narrow rim has a low ceiling. Reach its corner before turning,
        -- and let Mikiko wait below rather than push past on the water side.
        dk3.sidekick("mikiko", "stay")
        nodepath({-1478,396,-24}, {radius = 2, vertical_radius = 8, fight = false})
        move({-1656,396,-24}, {direct = true, crouch = true,
          radius = 2, vertical_radius = 8, fight = false})
        pickup({index = 69}, {direct = true,crouch=true})
        dk3.sidekick("mikiko", "follow")
      end
    end },
    { "river-lever", checkpoint = true, function()
      -- The approach can outlast the last venom rounds. Its empty-hand bite
      -- cannot answer spiders across the river steps; keep the returning
      -- Discus ready throughout this corridor instead.
      operate(123, {cautious = false, weapon = 9})
    end },
    { "upper-exit", checkpoint = true, function()
      nodepath {-2805,3895,152}
      operate(82)
      wait_until(function() return dk3.mover {index = 82} == "open" end,
        {timeout = 20, reason = "the upper door finishes swinging"})
      move({-2824,3824,152}, {direct = true, radius = 8})
      move({-2824,3704,152}, {direct = true, radius = 8})
      -- Its open leaf lies along the doorway centreline. Stay west until
      -- past its southern tip before returning to the compiled centre route.
      path({{-2824,3640,152}, {-2824,3584,152}},
        {direct = true, radius = 8, fight = false})
      nodepath {index = 7}
      recharge {index = 7}
      nodepath {-1814,2101,152}
      move({-1664,2104,184}, {direct = true, radius = 12})
      use {index = 299}
      wait_until(function()
        return dk3.mover {index = 299} == "open"
      end, {timeout = 20, reason = "the bridge's left door opens"})
      move({-1504,2104,184}, {direct = true, radius = 12, fight = false})
      dk3.sidekick("mikiko", "come")
      wait_until(function()
        local ally = dk3.entity {class = "mikiko"}
        return ally and ally.x > -1600 and math.abs(ally.z - 184) < 64
      end, {timeout = 40, reason = "Mikiko crosses the bridge door before the final corridor"})
      dk3.sidekick("mikiko", "follow")
      crossing(16)
    end },
  }(visit, resumed)
end)
level("e2m3b", function(visit, resumed)
  return stages {
    { "casket", function()
      -- Meet the two stair guards before collecting the casket's ammunition.
      -- They otherwise follow the loot route down and surround the player
      -- while the hammer-only guardian is waking.
      nodepath {-866,2920,-104}
      for _, foe in ipairs({27, 507}) do
        kill({index = foe}, {hold = true, weapon = 9, timeout = 60})
      end
      -- The stair guards leave two health packs on the upper landing and
      -- two beside the lower aisle. Use those before waking the guardian;
      -- reaching the distant fountain first also wakes its room's enemies.
      take(18, {weapon = 9})
      take(523, {weapon = 9})
      take(26, {weapon = 9})
      take(504, {weapon = 9})
      take(85, {standoff = 0})
      local guardian = dk3.entity {index = 501}
      if guardian and (guardian.health or 0) > 0 and dk3.has_weapon(12) then
        kill({index = 501}, {weapon = 12, timeout = 90})
      end
      nodepath({index = 17}, {weapon = 9})
      -- Clear the station's close attackers before waiting for its charge;
      -- repeated hits otherwise consume its healing as quickly as it gives.
      try(clear, {radius = 350, hold = true, timeout = 20,
        weapon = 9})
      recharge {index = 17}
      operate(67)
    end },
    { "casket-tunnel", checkpoint = true, function()
      nodepath {352,3819,-119}
      dk3.sidekick("mikiko", "stay")
      move({352,3896,-144}, {direct = true, radius = 8, vertical_radius = 12, fight = false})
      move({352,3896,-240}, {direct = true, radius = 8, vertical_radius = 4, fight = false})
      move({352,4000,-240}, {direct = true, radius = 8, vertical_radius = 4, fight = false})
      move({392,4000,-240}, {direct = true, radius = 6, vertical_radius = 4, fight = false})
      move({392,4000,136}, {direct = true, radius = 8, vertical_radius = 8, settle = false, fight = false})
      move({448,4000,136}, {direct = true, radius = 8, vertical_radius = 8, fight = false})
      save("casket-ladder")
    end },
    { "gate", checkpoint = true, function()
      local vase = dk3.entity {index = 77}
      if vase and vase.visible and vase.wanted ~= false then
        -- The guide's vase is across the open ladder shaft. Its ledges end
        -- at X288/416; running over the hole drops back into the tunnel.
        -- Jump from each lip at full pace beneath the low ceiling.
        move({464,4008,136}, {direct = true, radius = 8, fight = false})
        leap({408,4008,136}, {256,4008,136}, {pace = 1, fight = false})
        pickup({index = 77}, {direct = true, fight = false})
        move({240,4008,136}, {direct = true, radius = 8, fight = false})
        leap({296,4008,136}, {448,4008,136}, {pace = 1, fight = false})
        move({448,4000,136}, {direct = true, radius = 8, fight = false})
      end
      -- The ladder ends before this courtyard. Defend the approach: a living
      -- skeleton can occupy the exact firing stand and must be fought first.
      nodepath({1093,3381,8})
      move({1093,3381,8}, {direct = true, radius = 8, vertical_radius = 16})
      local skeleton = dk3.entity {index = 74}
      if skeleton and (skeleton.health or 0) > 0 then
        kill({index = 74}, {hold = true, timeout = 20,
          weapon = 12,
          arena = {{1040,3264},{1136,3416}}})
      end
      local thief = dk3.entity {index = 499}
      if thief and (thief.health or 0) > 0 then
        kill({index = 499}, {timeout = 90,
          weapon = dk3.ammo(11) > 0 and 11 or 9})
      end
      operate(10)
      dk3.sidekick("mikiko", "follow")
      try(regroup, 250, 60)
      take(35)
    end },
    { "upper-courtyard", checkpoint = true, function()
      nodepath({index = 494}, {standoff = 160, fight = false})
      regroup(128, 90)
      exit({index = 494}, {timeout = 180})
    end },
  }(visit, resumed)
end)
level("e2m3c", function(visit, resumed)
  return stages {
    { "pool-tile", function() operate(48) end },
    { "tower-levers", checkpoint = true, function()
      take(32) -- gold armor in the room beyond the lowered columns
      local trident = dk3.entity {index = 19}
      if trident and trident.visible and trident.wanted ~= false then
        nodepath {-288,224,344}
        dk3.sidekick("mikiko", "stay")
        use {index = 81}
        wait_until(function() return dk3.mover {index = 81} == "open" end,
          {timeout = 10, reason = "the pool column reveals the submerged tunnel"})
        for _, point in ipairs {
          {-288,224,232}, {-288,224,248}, {-432,224,248}, {-432,-16,248},
          {-464,-16,248}, {-464,-48,248}, {-496,-48,248}, {-496,-64,248},
          {-512,-64,248}, {-512,-96,248}, {-544,-96,248}, {-544,-112,248},
          {-544,-64,264}, {-552,-72,255}, {-560,-64,263}, {-568,-56,271},
          {-576,-48,279}, {-584,-40,288}, {-592,-32,288}, {-600,-24,288},
          {-608,-16,288}, {-616,-8,288}, {-624,0,288}, {-632,8,288},
          {-632,16,184}, {-600,64,184}, {-600,144,168},
        } do
          move(point, {direct = true, radius = 4, vertical_radius = 6,
            crouch = true, fight = false, timeout = 30})
        end
        pickup({index = 19}, {direct = true})
        save("trident-acquired")
        dk3.sidekick("mikiko", "follow")
      end
      take(21)
      operate(50)
      -- The lever's use stance can finish against the northern wall. Start
      -- the next live route on the walkway's measured interior floor.
      move({512,-2240,536}, {direct = true, on_floor = true, fight = false,
        pace = 0.35, radius = 4, vertical_radius = 8, timeout = 20})
      -- Stay on the measured narrow bridge through the two low crosspieces.
      -- Combat pursuit beside it can step off into the courtyard below.
      path({{512,-2304,552},{512,-2336,544},{512,-2784,544},
          {512,-2816,552},{512,-2848,536},{512,-2880,536}},
        {direct = true, on_floor = true, fight = false, pace = 0.5,
          radius = 4, vertical_radius = 8, timeout = 30})
      operate(301, {areas = true, hold = true, fight = false})
    end },
    { "acropolis", checkpoint = true, function()
      nodepath({index = 31}, {standoff = 160, weapon = 9})
      exit({index = 31}, {timeout = 240})
    end },
  }(visit, resumed)
end)
level("e2m4a", function(visit, resumed)
  return stages {
    { "bridge-supplies", function()
      take(58)
      nodepath {index = 77}
      recharge {index = 77}
    end },
    { "upper-canyon", checkpoint = true, function()
      take(47)
      take(49)
      take(440)
      take(40)
      take(42)
      take(505)
      nodepath {index = 7}
      recharge {index = 7}
      take(51)
      take(52)
    end },
    { "temple", checkpoint = true, function() crossing(90) end },
  }(visit, resumed)
end)
level("e2m4b", function(visit, resumed)
  local function a_rune()
    if dk3.has_key(21) then return end
    local collected=dk3.entity{index=129}
    if collected and not collected.visible and (collected.uses or 0)>0 then return end
    -- Keep Mikiko off the narrow door stance and the pool's descent. Her
    -- following body can become the player's apparent raised footing.
    dk3.sidekick("mikiko","stay")
    -- Operate the narrow swinging door from its east side, clear of the
    -- westward sweep chosen by its away-from-player opening.
    if x() > 3456 or z() > 360 then
      nodepath({3572,-3256,280}, {standoff = 96})
      -- Clear the solid spider before asking for the precise lower stance;
      -- otherwise its back holds the player51 units above that target.
      kill({index=100},{hold=true,weapon=dk3.ammo(11)>0 and 11 or 9,timeout=60})
      -- Land beyond the full leaf sweep before approaching its handle.
      -- An already-open eastward leaf otherwise catches the descending
      -- body above the lower floor and prevents the precise approach.
      move({3572,-3279,280}, {direct = true, radius = 8,
        vertical_radius = 16, fight = false, timeout = 15})
      wait_until(function() return dk3.mover {index = 59} == "closed" end,
        {timeout = 15, reason = "lower swinging door closes before the east-side approach"})
      move({3504,-3279,280}, {direct = true, radius = 8,
        vertical_radius = 16, fight = false, timeout = 10})
      use({index = 59}, {hold = true, fight = false, timeout = 8})
      wait_until(function() return dk3.mover {index = 59} == "open" end,
        {timeout = 10, reason = "lower swinging door fully open"})
      path({{3504,-3279,280}, {3408,-3279,280}},
        {direct = true, radius = 8, fight = false, timeout = 15})
    elseif dk3.mover {index = 59} == "closed" then
      move({3408,-3279,280}, {radius = 8, fight = false, timeout = 30})
      use({index = 59}, {hold = true, fight = false, timeout = 8})
    end
    take(39)
    local stair_weapon=dk3.ammo(11)>0 and 11 or 9
    nodepath({1700,-2140,300},{radius=24,vertical_radius=96,weapon=stair_weapon})
    move({1700,-2140,300}, {radius = 24, vertical_radius = 96, weapon=stair_weapon,timeout = 90})
    -- The tablet is below the spider pool's rim. A surface approach can
    -- enter the horizontal pickup radius while remaining above the tablet.
    move({1700,-2140,224}, {direct = true, crouch = true, fight = false,
      radius = 4, vertical_radius = 8, timeout = 30})
    pickup({index = 129}, {direct = true, crouch = true, fight = false})
    assert(dk3.has_key(21), "the spider pool A rune was not collected")
    dk3.sidekick("mikiko","follow")
  end
  if dk3.has_key(25) then
    a_rune()
    if dk3.has_key(22) and dk3.has_key(23) and dk3.has_key(24) then return crossing(152) end
    return crossing(132) -- lower tunnel after S
  end
  return stages {
    { "a-rune", function()
      a_rune()
      -- The destination is the health station itself. A second health
      -- detour can pin its return inside the pool after climbing its rim.
      move({index = 86}, {radius = 64, vertical_radius = 32,
        cautious = false, weapon = 13, timeout = 90})
      recharge({index = 86}, {hold = true, weapon = 13})
    end },
    { "pressure-plate", checkpoint = true, function()
      nodepath { 520, -3488, 304 }
      -- Stay in the main room west of the switch alcove. Its north/south
      -- walls put a closer-looking node on the wrong side of solid stone.
      move({ 400, -3488, 280 }, { direct = true, radius = 16 })
      local held, failure = pcall(wait_until, function()
        local state = dk3.mover { index = 136 }
        return state == "open" or state == "opening"
      end, { timeout = 60, reason = "Mikiko holds the floor plate and opens the pool door" })
      if not held then
        save("aegis-plate-failure")
        error(failure, 0)
      end
    end },
    { "hold-door", checkpoint = true, function()
      operate(128)
      wait_until(function() return dk3.entity {index = 430} == nil end,
        {timeout = 40, reason = "the exterior dial disables the plate before Mikiko leaves it"})
      dk3.sidekick("mikiko", "follow")
    end },
    { "s-temple", checkpoint = true, function()
      -- The supplied straight link clips the stone overhang at y=-1747.
      -- Use the clear southern edge instead of relying on an unstick jump.
      nodepath {1692,-1750,464}
      move({1768,-1776,464}, {direct = true, radius = 8})
      move({1904,-1776,464}, {direct = true, radius = 8, fight = false})
      nodepath {index = 86}
      recharge {index = 86}
      take(17)
      take(644)
      save("aegis-supplied-exit")
      crossing(152)
    end },
  }(visit, resumed)
end)
level("e2m4c", function(visit, resumed)
  local lower_exit = dk3.entity {index = 64}
  if dk3.has_key(23) or (lower_exit and (lower_exit.uses or 0) > 0) then
    -- Follow each bend of the thin waterfall ledge before turning toward
    -- the next node; the usual 28-unit arrival cuts its inside edge.
    nodepath({index = 61}, {standoff = 160, radius = 8})
    return exit({index = 61}, {timeout = 180})
  end
  return stages {
    { "e-rune", function() take(38) end },
    { "boulder", checkpoint = true, function() operate(241) end },
    { "g-temple", checkpoint = true, function() crossing(64) end },
  }(visit, resumed)
end)
level("e2m4d", function(visit, resumed)
  local return_exit = dk3.entity {index = 561}
  if not dk3.has_key(23) and return_exit and (return_exit.uses or 0) == 0 then
    return stages {
      { "lower-temple", function()
        take(599)
        take(136)
        take(103)
        take(102)
        operate(262)
        wait_until(function()
          return dk3.mover({index = 836}) == "open" and dk3.mover({index = 550}) == "open"
        end, {timeout = 40, reason = "the lower dial opens the mountain path"})
      end },
      { "mountain-temple", checkpoint = true, function()
        nodepath {index = 119}
        recharge {index = 119}
        operate(358)
        wait_until(function()
          return dk3.mover({index = 57}) == "open" and dk3.mover({index = 58}) == "open"
        end, {timeout = 40, reason = "the high temple dial reveals its armor"})
        take(60)
      end },
      { "return-to-cave", checkpoint = true, function() crossing(561) end },
    }(visit, resumed)
  end
  operate(262)
  wait_until(function()
    return dk3.mover({index = 836}) == "open" and dk3.mover({index = 550}) == "open"
  end, { timeout = 40, reason = "mountain boulder and bridge finish moving" })
  return stages {
    { "g-rune", function()
      if not dk3.has_key(23) then
        nodepath {index = 129}
        recharge {index = 129}
        -- Centre the body through the narrow single door. Its supplied node
        -- hugs the west jamb, where the full player hull cannot pass cleanly.
        path({{-1782,893,-680}, {-1880,884,-680}, {-1880,848,-680}},
          {direct = true, radius = 8, fight = false})
        if dk3.mover {index = 633} == "closed" then use {index = 633} end
        wait_until(function() return dk3.mover {index = 633} == "open" end,
          {timeout = 15, reason = "G temple doorway fully open"})
        -- Hold the upper doorway while clearing what can be reached from
        -- it. Pursuing a lower-floor target drops off this temple ledge.
        try(clear, {around = {-1840,600,-680}, radius = 600, hold = true,
          timeout = 30, arena = {{-2016,864},{-1760,928}},
          weapon = dk3.ammo(11) > 0 and 11 or 9})
        -- Dodging can finish back on the stairs. Re-enter the centred
        -- approach before crossing, instead of cutting across the west jamb.
        path({{-1782,893,-680}, {-1880,884,-680}, {-1880,848,-680}},
          {direct = true, radius = 8, fight = false})
        path({{-1880,784,-680}, {-1880,736,-680}},
          {direct = true, radius = 8, cautious = true})
        take(130)
      end
    end },
    { "i-rune", checkpoint = true, function()
      -- The forward route climbs the G temple's stairs and mountain path.
      -- The garden below the gallery is a different, barred side branch.
      -- Keep the objective's supplied corridor. Use the stocked ranged
      -- weapon before the narrow gallery's skeletons reach contact range.
      local gallery_cleared = false
      nodepath({index = 73}, {segment_options = function(point)
        if point[1]>=400 and point[1]<=850 and point[2]>=1200 and
            point[2]<=1800 and point[3]>=600 then
          -- Clear the two shelf pursuers from each supported bend before
          -- disabling sidesteps for its narrow outgoing leg.
          local x,y,z=dk3.position()
          for _,index in ipairs({82,579,657}) do
            local foe=dk3.entity{index=index}
            if foe and (foe.health or 0)>0 and dk3.visible{index=index} and
                (foe.x-x)^2+(foe.y-y)^2+(foe.z-z)^2<512^2 then
              kill({index=index},{hold=true,timeout=60,
                arena={{x-24,y-24},{x+24,y+24}},
                weapon=dk3.ammo(13)>0 and 13 or (dk3.ammo(11)>0 and 11 or 9)})
            end
          end
          -- Answer pursuers that emerge during the leg, keeping defensive
          -- movement inside the supplied bend's narrow strip.
          return {direct=true,cautious=false,radius=4,vertical_radius=16,pace=0.5,
            weapon=dk3.ammo(13)>0 and 13 or (dk3.ammo(11)>0 and 11 or 9),
            arena={{math.min(x,point[1])-8,math.min(y,point[2])-8},
              {math.max(x,point[1])+8,math.max(y,point[2])+8}}}
        end
        if point[1] >= 1550 and point[1] <= 1700 and
            point[2] >= -300 and point[2] <= 300 and point[3] >= 600 then
          if not gallery_cleared and point[2] < 100 then
            -- Meet the gallery's melee guards on the flat landing before
            -- their bodies force a sidestep off the descending narrow span.
            for _, index in ipairs({76,614}) do
              local foe = dk3.entity {index = index}
              if foe and (foe.health or 0) > 0 and dk3.visible {index = index} then
                kill({index = index}, {hold = true, timeout = 10,
                  arena = {{1584,-112},{1648,128}},
                  weapon = dk3.ammo(11) > 0 and 11 or 9})
              end
            end
            gallery_cleared = true
          end
          return {fight=false,cautious=false,radius=4,vertical_radius=16}
        end
      end})
      take(73)
    end },
    { "aegis-hall", checkpoint = true, function() crossing(151) end },
  }(visit, resumed)
end)
level("e2m4e", function(visit, resumed)
  save("aegis-hall-arrival")
  local function clear_landing()
    local x,y,z=dk3.position()
    for _,index in ipairs({15,31,32,33,34,35,36,37,38,41,42,43,44,45,46,47,48,49,50,51,55,56,57,58,59,60,61,62,63,64,65,66,69,552,553,574,575,576}) do
      local foe=dk3.entity{index=index}
      if foe and (foe.health or 0)>0 and
          (foe.x-x)^2+(foe.y-y)^2+(foe.z-z)^2<512^2 and dk3.visible{index=index} then
        kill({index=index},{hold=true,weapon=13,timeout=30})
      end
    end
  end
  local rune_slots={79,532,533,534,535}
  local function inserted(index)
    local slot=dk3.entity{index=rune_slots[index]}
    return slot and (slot.uses or 0)>0
  end
  -- Inserting a rune consumes its inventory key. Restored progress comes
  -- from the sockets and revealed wheel, not from requiring those keys again.
  local runes_placed=dk3.mover{index=17}=="open"
  if not runes_placed then
    -- The upper arrival from I reaches the gate's hall before the fountain.
    -- Open its remote dial before following the graph through the gate.
    local hall_dial = dk3.entity { index = 106 }
    if dk3.has_key(24) and hall_dial and (hall_dial.uses or 0) == 0 and hall_dial.state == "closed" then
      -- The fountain is on the lower storey behind this gate. Open the
      -- upper dial before attempting that resupply route.
      nodepath({976,-700,1928}, {weapon=13})
      clear_landing()
      operate(106)
    end
    if not dk3.has_key(25) then
      take(7)
      take(737)
      nodepath {index = 10}
      recharge {index = 10}
      take(68)
    end
    local fountain_dial = dk3.entity { index = 110 }
    if fountain_dial and (fountain_dial.uses or 0) == 0 and fountain_dial.state == "closed" then
      nodepath({index = 110}, {standoff = 96, cautious = false})
      use {index = 110}
    end
    wait_until(function() return dk3.mover({index = 101}) == "open" end,
      { timeout = 40, reason = "fountain dial clears the boulder" })
    for rune = 1, 5 do
      if not dk3.has_key(20+rune) and not inserted(rune) then
        -- The lower return is open after the fountain dial. Use its live
        -- corridor instead of the supplied chain through the upper door.
        move({416,800,1560}, {radius = 8, vertical_radius = 16,
          fight = false, timeout = 90})
        use({index = 637}, {hold = true, fight = false})
        wait_until(function() return dk3.mover{index=637}=="open" end,
          {timeout = 10, fight = false, reason = "gold return door clears its centre"})
        move({416,960,1560}, {direct = true, radius = 8,
          vertical_radius = 16, fight = false, timeout = 15})
        return crossing(192, {areas = true})
      end
    end
  end
  return stages {
    { "gate-dial", function()
      if runes_placed then return end
      operate(106)
      -- Plan to the fountain's actual landing. The supplied upper node
      -- chain can retain a point368 above Hiro after combat at its edge.
      move({416,-899,1632}, {weapon=13,cautious=false,radius=8,
        vertical_radius=16,timeout=120})
      -- Clear the guards from the fountain's actual landing before its
      -- drinking action takes over the view. Pursuing a named remote guard
      -- from the arrival instead runs through the occupied upper hall.
      clear_landing()
      -- The fountain is beyond the upper-hall stair loop, not through the
      -- low wall beside the supplied graph's endpoint. Allow that walk and
      -- its guards, using the available ranged ammunition along the way.
      recharge({index = 92}, {timeout = 120, cautious = false,
        weapon = 13,hold=true})
    end },
    { "aegis", checkpoint = true, function()
      if runes_placed then return end
      nodepath({index = 79}, {standoff = 160, cautious = false,
        weapon = dk3.ammo(11) > 0 and 11 or 9,
        segment_options = function(point)
          if point[1] >= 400 and point[1] <= 650 and
              point[2] >= -1250 and point[2] <= -1100 then
            -- Route around the opened leaf instead of steering the supplied
            -- diagonal through its live hull while a spider closes in.
            return {direct = false}
          end
        end})
      try(clear, {class = "monster_spider", radius = 450, hold = true,
        timeout = 10, weapon = dk3.ammo(11) > 0 and 11 or 9})
      for rune,index in ipairs(rune_slots) do
        if not inserted(rune) then operate(index) end
      end
    end },
    { "gate-wheel", checkpoint = true, function()
      wait_until(function() return dk3.mover({index = 17}) == "open" end,
        {timeout = 20, reason = "all five runes uncover the gate wheel"})
      local gate=dk3.mover{index=102}
      if gate~="open" and gate~="opening" then operate(662) end
      wait_until(function() return dk3.mover({index = 102}) == "open" end,
        {timeout = 25, reason = "wheel opens the large temple gate"})
    end },
    { "cerberus", checkpoint = true, function()
      -- The temple's optional soul is still available after the rune circuit.
      -- Collect its real health reserve before committing to the boss court.
      take(40, {areas = true, weapon = 13})
      local court_x=dk3.position()
      if court_x<592 then
        -- Leave the recessed soul court through its southern entrance; its
        -- nearest supplied graph node is across the courtyard's north wall.
        move({251,-1407,1584}, {weapon = 13, timeout = 120, radius = 32})
        -- Cerberus only admits the Trident. Ready it before rounding the
        -- courtyard: changing guns within the pounce's reach loses the lane.
        local health,maximum=dk3.health()
        if health<maximum then
          move({416,-899,1632}, {weapon=13,cautious=false,radius=8,
            vertical_radius=16,timeout=120})
          recharge({index = 92}, {timeout = 120, cautious = false,
            weapon = 13, hold = true})
        end
        -- The large gate is already open. Its actual court route avoids the
        -- supplied node chain's detour to upper wooden door717.
        -- Walk its low centre and the southern slope around the open hinge;
        -- the area route cannot join from the raised rock beside that hinge.
        path({{512,-1536,1584},{512,-1728,1590},{512,-1824,1603},
            {768,-1824,1633}},
          {direct = true, on_floor = true, fight = false, radius = 4,
            vertical_radius = 8, pace = 0.5, timeout = 30})
      end
      -- From this side of the hinge the supplied court chain follows the
      -- long southern ramp and eastern rock, with no remote door detour.
      nodepath({2200,-1200,1740}, {weapon = 13})
      move({2200,-1128,1716}, {direct = true, cautious = false,
        weapon = 13, radius = 4, vertical_radius = 48})
      -- Draw him out through the actual path around the inner rock. A
      -- straight retreat meets its diagonal face and leaves Hiro cornered.
      move({2600,-1128,1664}, {fight = false,
        weapon = 13, radius = 16, vertical_radius = 48})
      kill({index = 76}, {weapon = 13, timeout = 240})
    end },
    { "medusa-lair", checkpoint = true, function()
      if dk3.mover({index = 102}) == "closed" then operate(662) end
      crossing(71)
    end },
  }(visit, resumed)
end)
level("e2m5a", function(visit, resumed)
  return stages {
    { "zeus", function() take(65) end },
    { "river", checkpoint = true, function()
      if z() > 400 then
        -- This descending ledge has no return from the lower river floor.
        -- Keep the authored footing through incoming fire; combat sidesteps
        -- can otherwise drop below the next upper waypoint.
        nodepath({284, -1436, 488}, {radius = 48, fight = false, cautious = false})
        move({0, -1320, 488}, {direct = true, radius = 64, fight = false})
        move({0, -1088, 488}, {direct = true, radius = 80, fight = false})
        move({0, -760, 152}, {direct = true, radius = 48, fight = false})
      end
    end },
    { "ladder-room", checkpoint = true, function()
      take(13)
      crossing(63) -- main doorway; 62 is the optional upper-ladder return
    end },
  }(visit, resumed)
end)
level("e2m5b", function(visit, resumed)
  local function swim(point)
    move(point, {direct = true, radius = 6, vertical_radius = 10, fight = false, timeout = 30})
  end
  return stages {
    { "upper-eye", function() take(41) end },
    { "east-stairs", function()
      nodepath {index = 39}
      recharge {index = 39}
    end },
    { "submerged-passage", checkpoint = true, function()
      dk3.sidekick("mikiko", "stay")
      nodepath {989, -514, -261}
      -- The fallen column blocks a straight dive. Walk its south side,
      -- descend beyond it, then turn north to the submerged opening.
      for _, point in ipairs {
        {976,-488,-220}, {976,-512,-220}, {976,-512,-244},
        {976,-560,-244}, {928,-560,-244}, {928,-608,-244},
        {904,-608,-244}, {904,-656,-244}, {856,-656,-244},
        {856,-680,-244}, {664,-680,-244}, {664,-680,-340},
        {664,-344,-340}, {616,-344,-340}, {616,-320,-340},
        {496,-320,-340}, {288,-320,-320}, {288,-400,-276},
      } do swim(point) end
      -- The collapsed column rises south from the tunnel to the upper ring.
      -- The western pool belongs to the next room, beyond the dry passage.
      move({288,-480,-224}, {direct = true, radius = 8})
      move({288,-560,-176}, {direct = true, radius = 8})
      move({288,-640,-136}, {direct = true, radius = 8})
    end },
    { "upper-ledge", checkpoint = true, function()
      -- This is a broad upper ring: accept a supported landing on its near
      -- edge, then walk across it. Ten units required an unnecessary bullseye.
      leap({288,-640,-136}, {352,-672,-104}, {pace = 1, radius = 24, vertical_radius = 16, fight = false})
      nodepath {-584,-928,-104}
      -- The crouched hull rests on the near lip at -120. The old point was
      -- below that floor and too far into the southern jamb to stand on.
      move({-600,-920,-120}, {direct = true, radius = 8, vertical_radius = 12,
        crouch = true, fight = false})
      move({-720,-928,-300}, {direct = true, radius = 16, vertical_radius = 20, fight = false})
      move({-1152,-928,-224}, {direct = true, radius = 12, fight = false})
      move({-1152,-1360,-216}, {direct = true, radius = 12, fight = false})
      move({-1152,-1424,-192}, {direct = true, radius = 12})
    end },
    { "antidote", checkpoint = true, function()
      take(25, {direct = true})
      take(27, {direct = true})
    end },
    { "poison-river", checkpoint = true, function()
      -- Fight the thieves on the dry banks before committing to the poison
      -- dive. Ignoring them here can restore a checkpoint into the same
      -- unopposed melee ambush on every attempt.
      local function clear_bank()
        local x,y,z=dk3.position()
        for _,index in ipairs({20,21,22,63,65,317,318,319}) do
          local foe=dk3.entity{index=index}
          if foe and (foe.health or 0)>0 and
              (foe.x-x)^2+(foe.y-y)^2+(foe.z-z)^2<512^2 and dk3.visible{index=index} then
            kill({index=index},{hold=true,weapon=13,timeout=30,
              arena={{x-24,y-24},{x+24,y+24}}})
          end
        end
      end
      take(11, {collect_direct=false,weapon=13,fight=false,cautious=false,
        segment_options=function() clear_bank() end})
      nodepath({index = 172}, {standoff = 160})
      -- Dive through the bottom of the poison pool, south of the dry
      -- ledge. Its lower tunnel runs north underneath that ledge.
      move({-32,-1664,-680}, {direct = true, radius = 12, fight = false})
      move({-32,-1664,-916}, {direct = true, radius = 8, vertical_radius = 3, fight = false})
      move({-32,-1088,-916}, {direct = true, radius = 8, vertical_radius = 3, fight = false})
      exit({index = 172}, {timeout = 60, direct = true, fight = false})
    end },
  }(visit, resumed)
end)
level("e2m5c", function(visit, resumed)
  return stages {
    { "poison-tunnel", function()
  -- Keep the companion on her dry arrival floor while the player swims
  -- below it and comes up the narrow ladder.
  dk3.sidekick("mikiko", "stay")
  -- These bottles are in the lower flooded tunnel, directly below an
  -- unrelated dry corridor in the supplied ground graph.
  move({-8,-864,-928}, {direct = true, radius = 12, fight = false})
  pickup({index = 12}, {direct = true, fight = false})
  pickup({index = 55}, {direct = true, fight = false})
  pickup({index = 660}, {direct = true, fight = false})
  move({968,-864,-928}, {direct = true, radius = 12, fight = false})
  pickup({index = 661}, {direct = true, fight = false})
  move({968,-1408,-928}, {direct = true, radius = 12, fight = false})
  move({1152,-1408,-928}, {direct = true, radius = 12, fight = false})
  move({1152,-1560,-928}, {direct = true, radius = 12, fight = false})
  move({1172,-1560,-688}, {direct = true, radius = 8, vertical_radius = 8, settle = false, fight = false})
  move({1176,-1536,-696}, {direct = true, radius = 4, settle = false, fight = false})
  move({1192,-1520,-680}, {direct = true, radius = 4, fight = false})
  move({1192,-1504,-680}, {direct = true, radius = 4, fight = false})
  move({1160,-1472,-680}, {direct = true, radius = 6, fight = false})
  move({1144,-1456,-680}, {direct = true, radius = 6, fight = false})
  move({1152,-1440,-680}, {direct = true, radius = 20, fight = false})
  save("lair-ladder")
    end },
    { "upper-courtyard", checkpoint = true, function()
  -- The guide calls for a Zeus discharge against the crowd above the
  -- ladder. Fight from the dry landing before crossing the narrow banks.
  clear({around = {1280,-1400,-680}, radius = 700, weapon = 14, count = 1, hold = true, timeout = 90})
  clear({around = {1280,-1400,-680}, radius = 700, timeout = 180})
  -- Stay on the upper bank around the three flooded shafts. The straight
  -- line to this bottle cuts across their open tops.
  local bottle = dk3.entity {index = 11}
  if bottle and bottle.wanted ~= false then
  nodepath {1152,-1440,-680}
  local bank = {{1208,-1392,-680}, {1296,-1392,-680}, {1296,-1488,-680}, {1304,-1504,-680}, {1304,-1584,-680}}
  for _, point in ipairs(bank) do move(point, {direct = true, radius = 6, fight = false}) end
  pickup({index = 11}, {direct = true, fight = false})
  for index = #bank, 1, -1 do move(bank[index], {direct = true, radius = 6, fight = false}) end
  end
  nodepath {index = 56}
  dk3.sidekick("mikiko", "follow")
  operate(56)
  crossing(28)
    end },
  }(visit, resumed)
end)
level("e2m5d", function()
  -- Replan the final descent through the actual areas. The supplied node
  -- corridor can leave the traveller below an unreachable upper waypoint.
  exit({index=2},{timeout=180})
end)
level("e2m5e", function(visit, resumed)
  return stages {
    { "medusa", function()
  for _, index in ipairs { 5, 251, 252, 253 } do take(index) end
  local medusa = dk3.entity {index = 32}
  if medusa and medusa.health and medusa.health > 0 then
    -- Resume a short ranged burst between gaze warnings. Repeated warnings
    -- can interrupt the Eye's long wind-up while the pilot averts its view.
    kill({index = 32}, {weapon = dk3.ammo(13) > 0 and 13 or 14})
  end
  cinematic()
    end },
    { "awakened-monsters", checkpoint = true, function()
      -- The generator wakes the statues in delayed waves. An empty arena
      -- between waves does not complete the ten-monster ending counter.
      local deadline = dk3.time() + 900000
      local posts = {{2600,-152,-1928},{2584,-32,-1928},{2656,-32,-1928},
        {2640,-152,-1928},{2712,-160,-1928},
        {2544,-128,-1928},{2544,-208,-1928}}
      local round = 0
      while dk3.map() == "e2m5e" do
        local counter = dk3.entity {index = 43}
        if counter and (counter.uses or 0) > 0 then
          cinematic()
          wait_until(function() return dk3.map() ~= "e2m5e" end,
            {timeout = 180, reason = "awakened-monster counter starts the timestream"})
          return
        end
        expect(dk3.time() < deadline, "the ten awakened monsters complete the ending counter")
        round = round + 1
        local post = (round-1) % #posts + 1
        move(posts[post],
          -- These are combat viewpoints, not narrow puzzle landings. Accept
          -- the supported dry shoulder beside an altar lip instead of
          -- demanding its exact top while newly awakened enemies approach.
          {direct = true, radius = post > 5 and 8 or 24, vertical_radius = 24, fight = false, timeout = 15})
        -- Fight from the altar and its dry approaches. The statue basins
        -- around it are poisonous, and the upper statues can be shot from
        -- here without following them into those basins.
        for _, foe in ipairs(dk3.threats(1800)) do
          local target = dk3.entity {id = foe.id}
          dk3.log("awakened target " .. foe.class .. " id=" .. foe.id ..
            (target and string.format(" hp=%d at=%.0f,%.0f,%.0f", target.health or 0, target.x, target.y, target.z) or ""))
          if target and (target.health or 0) > 0 then
            -- Standing object-aim checks several parts of the live body.
            -- Crouched combat aim is hidden by the altar rim for foes below
            -- it; chasing/dodging those foes walks into their poison basins.
            -- The western dry viewpoints expose heads above the basin rim.
            -- Request that visible part instead of the lower body centre.
            local head = post > 5 and {target.x,target.y,target.z+28} or nil
            try(shoot, {id = foe.id}, {hold = true, fight = false, weapon = 13, around = head, timeout = 8})
          end
        end
        cinematic()
        wait(1)
      end
    end },
  }(visit, resumed)
end)
level("timestream23", function() cinematic() end)
