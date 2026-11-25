-- SPDX-License-Identifier: GPL-2.0-or-later
-- Authored San Francisco progression, informed by the official GameSpot guide.
-- Original route intent and local BSP identities; implementation is not a pass.
include "coop/campaign_steps.lua"
local P = campaign_steps
local ingredients = {15,16,17,18}
local function hold_lab_party()
  -- Follow can settle almost two hundred units away after its offset and
  -- hysteresis. Come owns the closer stand required by this bay's regroup.
  dk3.sidekick("all", "come")
  regroup(128, 45)
  P.stay()
end
-- The guide's early Slugger is above the vent roof. Climb the east pipes,
-- circle the tall pipe, then take the narrow west corner before leaving.
local function pipe_hop(point,pace)
  local x,y,z=dk3.position()
  leap({x,y,z},point,{crouch=true,pace=pace,radius=24,vertical_radius=24})
end
local function pipe_slugger()
  move({1216,864,363},{direct=true,crouch=true,pace=0.4,radius=2,vertical_radius=12})
  pipe_hop({1224,872,388},0.2)
  pipe_hop({1256,888,424},0.6)
  move({1264,896,424},{direct=true,crouch=true,pace=0.5,radius=4,vertical_radius=12})
  pipe_hop({1328,912,424},0.5)
  for _,point in ipairs({
      {1336,904,424},{1344,896,424},{1352,896,424},{1360,888,432},
      {1368,880,432},{1376,872,432},{1384,872,432},{1392,872,432},
      {1400,872,432},{1408,864,432},{1416,856,432},{1416,848,432},
      {1416,840,432},{1416,832,432},{1416,824,432},{1416,816,432},
      {1408,808,432},{1400,800,432},{1392,792,432},{1384,784,432},
      {1376,776,432},{1368,768,432},{1360,768,432},{1352,768,432},
      {1344,768,432},{1336,768,432},{1328,768,432},{1320,768,432},
      {1312,768,432},{1304,768,432},{1296,768,432},{1288,768,432},
      {1280,768,432},{1272,768,432},{1264,768,432},{1256,768,432},
      {1248,768,432},{1240,768,432},{1232,768,432},{1224,768,432},
      {1216,768,432},{1208,768,432},{1200,768,432},{1192,768,432},
      {1184,768,432},{1176,768,432},{1168,768,432},{1160,768,432},
      {1152,768,432},{1144,768,432},{1136,768,432},{1128,768,432},
      {1120,768,432},{1112,768,432},{1104,776,432},{1096,784,432},
      {1088,792,432},{1080,800,432},{1072,808,432},{1064,816,432},
      {1056,824,432},{1048,832,432},{1056,840,432},{1064,848,432}}) do
    move(point,{direct=true,crouch=true,pace=0.5,radius=2,vertical_radius=12})
  end
  P.take(88,nil,{direct=true,crouch=true})
end
local function fan_point(e,center,offset,rate,seconds)
  local angle=math.rad(e.yaw)
  local future=angle+math.rad(rate*(seconds or 0))
  local px=e.x-center[1]*math.cos(angle)+center[2]*math.sin(angle)
  local py=e.y-center[1]*math.sin(angle)-center[2]*math.cos(angle)
  local x,y=center[1]+offset[1],center[2]+offset[2]
  return px+x*math.cos(future)-y*math.sin(future),py+x*math.sin(future)+y*math.cos(future)
end
local function fan_choice(a,b,source,target,inner,takeoffs,landings,axis,delay)
  axis=axis or {1,0}
    for _,out in ipairs(takeoffs) do
      local runup = math.max(0.3,math.sqrt((out[1]-inner[1])^2+(out[2]-inner[2])^2)/320+0.15)
      local ix,iy=fan_point(a,source.center,inner,source.rate,delay+runup)
      local sx,sy=fan_point(a,source.center,out,source.rate,delay+runup)
      for _,onto in ipairs(landings) do
        local tx,ty=fan_point(b,target.center,onto,target.rate,delay+runup+0.7)
        local dx,dy=tx-sx,ty-sy
        local rx,ry=sx-ix,sy-iy
        local aligned=rx*dx+ry*dy
        if (sx-ix)*axis[1]+(sy-iy)*axis[2]>24 and dx*axis[1]+dy*axis[2]>48 and
          dx*dx+dy*dy<220*220 and math.abs(dx*axis[2]-dy*axis[1])<80 and
          aligned>0 and aligned^2>0.8*(rx*rx+ry*ry)*(dx*dx+dy*dy) and
          sy>-880 and sy<-656 and ty>-880 and ty<-656 then
          return out,onto
        end
      end
    end
    return nil
end
local function cross_fan(source,target,inner,takeoffs,landings,axis,low)
  low=low~=false
  if inner then
    move({index=source.index},{around={inner[1],inner[2],0},direct=true,crouch=low,fight=false,radius=8,vertical_radius=24})
  else
    -- Keep a proven landing patch instead of walking toward a hub whose
    -- inner quarter can rotate into its fixed housing.
    local e=dk3.entity{index=source.index}
    local px,py=dk3.position()
    local angle=math.rad(e.yaw)
    local dx,dy=px-e.x,py-e.y
    inner={dx*math.cos(angle)+dy*math.sin(angle),-dx*math.sin(angle)+dy*math.cos(angle)}
  end
  local takeoff,landing
  wait_until(function()
    takeoff,landing=fan_choice(dk3.entity{index=source.index},dk3.entity{index=target.index},
      source,target,inner,takeoffs,landings,axis,0)
    return takeoff~=nil
  end,{timeout=6,stance={index=source.index},around={inner[1],inner[2],0},
    crouch=low,fight=false,reason="a fan quarter admits the next jump before reaching its solid housing"})
  local sx,sy=fan_point(dk3.entity{index=source.index},source.center,takeoff,source.rate,0)
  leap({sx,sy,z()},{index=target.index},{around={landing[1],landing[2],0},fight=false,radius=40,vertical_radius=24})
end
local function board_shuttle(call, inside, index, dock, lip, deck, call_options, clearance)
  local function at_dock()
    local car = dk3.entity {index = index}
    return car and math.abs(car.x-dock[1]) < 4 and math.abs(car.y-dock[2]) < 4
      and math.abs(car.z-dock[3]) < 4
  end
  -- The outside switch summons an absent car, but sends a docked car away.
  if not at_dock() then P.press(call, call_options) end
  local stopped_since
  wait_until(function()
    if not at_dock() then stopped_since = nil return false end
    stopped_since = stopped_since or dk3.time()
    return dk3.time()-stopped_since >= 400
  end, {timeout = 90, reason = "transport is stationary at the boarding dock"})
  if clearance then clearance() end
  move(lip, {direct = true, fight = false, radius = 8, vertical_radius = 16, pace = 0.5})
  move(deck, {direct = true, fight = false,
    radius = 8, vertical_radius = 24, pace = 0.5})
  P.press(inside, {areas = true, hold = true, fight = false})
  ride {index = index}
end

local function leave_central_shuttle(y)
  local x, _, height = dk3.position()
  if height >= -2488 and x >= 352 then
    move({368,y,-2472}, {direct = true, radius = 8, vertical_radius = 16})
    move({368,32,-2472}, {direct = true, radius = 8, vertical_radius = 16})
    return
  end
  -- A rider can finish on the car's left wall, above its deck. Step down
  -- inside first and align with the eastern opening. A diagonal jump from
  -- that wall meets the solid side beside the opening.
  move({288,y,-2512}, {direct = true, fight = false,
    radius = 8, vertical_radius = 16, pace = 0.5})
  move({320,y,-2512}, {direct = true, fight = false, radius = 8, vertical_radius = 16, pace = 0.5})
  point_at({368,y,-2472})
  leap({320,y,-2512}, {368,y,-2472}, {crouch = true, radius = 32, vertical_radius = 16})
  move({368,y,-2472}, {direct = true, radius = 8, vertical_radius = 16})
  move({368,32,-2472}, {direct = true, radius = 8, vertical_radius = 16})
end

level("e4m1a", function(visit, resumed)
  local px, _, pz = dk3.position()
  -- The bottle is acquired before the first yard exit. A restored vent/cell
  -- checkpoint still owes that exit; only the kitchen return starts west of it.
  if dk3.has_key(18) and (visit > 1 or px < -256 or pz > 450) then
    return stages {
      {"kitchen-table-and-ceiling-plank", function()
        nodepath {8,-249,374}
        move({16,-224,374}, {direct = true, radius = 8})
        move({-40,-224,374}, {direct = true, crouch = true, radius = 4})
        leap({-48,-224,374}, {-80,-224,424}, {crouch = true, pace = 1, vertical_radius = 24})
        move({-144,-224,488}, {direct = true, radius = 8, vertical_radius = 16})
        leap({-144,-224,488}, {-176,-224,528}, {crouch = true, pace = 1, vertical_radius = 24})
        move({-200,-100,528}, {direct = true, radius = 12})
      end},
      {"upper-cellblock-to-showers", checkpoint = true, supplies=false, function()
        for _, point in ipairs({{-152,-8,528},{-112,40,528},{16,40,528},{16,160,528},
            {128,204,528},{184,204,528},{202,176,547},{232,136,540},{280,152,530},
            {320,160,488},{320,304,488},{1056,304,488}}) do
          move(point, {direct = true, radius = 12, vertical_radius = 32})
        end
        -- The ammunition in the cells beside this walkway is behind fixed
        -- bars. Keep the gallery route to the showers instead of pursuing it.
        move({1488,304,488}, {direct = true, radius = 12, vertical_radius = 32})
        -- Pass west of the flame before hopping onto the raised pipe.
        move({1520,260,488}, {direct = true, radius = 8})
        move({1520,192,488}, {direct = true, radius = 8})
        leap({1528,192,488}, {1568,192,516}, {pace = 1, vertical_radius = 24})
        move({1568,184,516}, {direct = true, radius = 4})
        leap({1568,176,516}, {1568,144,552}, {crouch = true, pace = 1, vertical_radius = 24})
        save("coop-alcatraz-shower-vent")
        P.breakage(612,{crouch=true})
        wait_until(function() return dk3.mover{index=613}=="open" end,
          {timeout=10,crouch=true,reason="the shot vent hatch clears the shower passage"})
        move({1600,152,552}, {direct = true, crouch = true, radius = 8})
        move({1632,152,488}, {direct = true, settle = false, crouch = true, radius = 8, vertical_radius = 24})
        for _, point in ipairs({{1664,240,488},{1712,212,488},{1800,212,480},{1856,320,480}}) do
          move(point, {direct = true, crouch = true, radius = 8, vertical_radius = 24})
        end
        P.cross(115, {areas = true, crouch = true})
      end},
    }(visit, resumed)
  end
  return stages {
    {"cell-pistol", function()
      P.stay()
      nodepath({1664,704,344},{crouch=true})
      move({1664,800,344},{direct=true,crouch=true,radius=8})
      leap({1664,832,344},{1664,896,344},{crouch=true,pace=1,radius=24,vertical_radius=24})
      leap({1664,896,344},{1620,896,368},{crouch=true,pace=1,radius=16,vertical_radius=16})
      P.take(164,nil,{direct=true,crouch=true})
    end},
    {"bottle-in-vent", checkpoint = true, function()
      P.stay()
      P.breakage(373, {crouch = true})
      move({1560,896,368}, {direct = true, crouch = true, radius = 8})
      P.breakage(139, {crouch = true})
      wait_until(function() return dk3.mover({index = 140}) == "open" end,
        {timeout = 10, reason = "bottle vent hatch opens clear of the sill"})
      move({1520,896,360}, {direct = true, crouch = true, radius = 8})
      -- Keep a running crawl into the takeoff: the low ceiling permits only
      -- the short hop over this eight-unit sill, not a stationary full jump.
      leap({1520,870,360}, {1520,868,368}, {crouch = true, radius = 16, vertical_radius = 16, pace = 1})
      move({1520,808,344}, {direct = true, crouch = true, radius = 8})
      P.take(111, 18, {direct = true, crouch = true})
      leap({1520,824,344}, {1520,840,372}, {crouch = true, radius = 32, vertical_radius = 16, pace = 1})
      move({1520,896,368}, {direct = true, crouch = true, radius = 8})
      P.breakage(375, {crouch = true})
      wait_until(function() return dk3.mover{index=376}=="open" end,
        {timeout=10,crouch=true,reason="the pipe-room hatch clears the entrance"})
      move({1224,800,360},{direct=true,crouch=true,radius=8,vertical_radius=24})
      move({1224,864,352},{direct=true,crouch=true,radius=8,vertical_radius=24})
      save("coop-alcatraz-pipe-room")
      pipe_slugger()
      save("coop-alcatraz-pipe-weapon")
      P.breakage(377, {crouch = true})
      nodepath({968,896,344}, {crouch = true})
      move({968,896,344}, {direct = true, crouch = true, radius = 8})
    end},
    {"pipe-room-exit", checkpoint = true, function()
      P.once(359, {crouch = true})
      wait_until(function() local pipe = dk3.entity {index = 144} return not pipe or pipe.broken end,
        {timeout = 10, reason = "pipe valve releases the sealed passage"})
      move({912,816,344}, {direct = true, crouch = true, radius = 2})
      leap({912,816,344}, {864,816,384}, {crouch = true, pace = 1, radius = 48, vertical_radius = 16})
      move({864,816,384}, {direct = true, crouch = true, radius = 8})
      nodepath({560,1036,296}, {crouch = true})
      move({576,1032,298}, {direct = true, crouch = true, radius = 2})
      leap({576,1032,298}, {616,1032,344}, {crouch = true, pace = 1, radius = 24, vertical_radius = 24})
      move({640,1032,344}, {direct = true, radius = 8})
    end},
    {"free-the-cellblock", checkpoint = true, function()
      move({320,1032,344}, {direct = true, radius = 8})
      move({232,1024,344}, {direct = true, radius = 4})
      -- The two timed strokes require facing the lever. Clear its nearby
      -- attacker before committing to those use commands. The yard guard
      -- is beyond this landing's firing lane and belongs to the next room.
      kill({index=441},{weapon=21,hold=true,
        arena={{200,1008},{264,1056}},timeout=90})
      -- Defensive movement during the clearing fight can leave this upper
      -- landing. Regain the lever's actual approach before its timed strokes.
      nodepath({232,1024,344})
      move({232,1024,344},{direct=true,radius=4})
      P.press(15, {areas = true, fight=false})
      wait_until(function() return dk3.mover({index = 637}) == "open" end,
        {timeout = 10, reason = "first cellblock lever changes the two doors"})
      wait_until(function() return dk3.mover({index = 15}) == "closed" end,
        {timeout = 10, reason = "release the button before the second press"})
      wait_until(function() return dk3.mover({index = 634}) == "open" end,
        {timeout = 10, reason = "first door stroke finishes before reversing the lever"})
      P.press(15, {areas = true, fight=false})
      wait_until(function() return dk3.mover({index = 637}) == "closed" end,
        {timeout = 10, reason = "return lever to reopen the opposite passage"})
      wait_until(function() return dk3.mover({index = 634}) == "closed" end,
        {timeout = 10, reason = "START_OPEN passage finishes returning to its clear pose"})
      move({176,1032,344}, {direct = true, radius = 8})
      move({176,864,344}, {direct = true, radius = 8})
      P.press(187, {areas = true})
      move({320,832,344}, {direct = true, radius = 8})
      P.once(389, {areas = true}) P.follow()
    end},
    {"prison-yard", checkpoint = true, function()
      P.breakage(492) P.once(122)
      nodepath {-104,1024,344}
      move({-104,1024,344}, {direct = true, radius = 4})
      companion_take({index = 662}, "mikiko")
      companion_take({index = 663}, "superfly")
      move({32,1024,344}, {direct = true, radius = 4})
      move({176,1024,344}, {direct = true, radius = 8})
      wait_until(function() return dk3.mover({index = 15}) == "closed" end,
        {timeout = 10, reason = "yard lever button is ready"})
      P.press(15, {areas = true})
      wait_until(function() return dk3.mover({index = 632}) == "open" end,
        {timeout = 10, reason = "yard passage opens after the companions are freed"})
      move({176,1216,344}, {direct = true, radius = 8})
      P.cross(116)
    end},
  }(visit, resumed)
end)

level("e4m1b", function(visit, resumed)
  if not P.has(ingredients) then
    return stages {
      {"yard-pipe-to-kitchen-window", function()
        P.stay()
        nodepath {-912,496,256}
        -- The rungs can lift Hiro before horizontal alignment completes.
        -- Accept that real ladder grab, then continue the upward stroke.
        move({-888,436,256}, {direct = true, settle = false, radius = 4, vertical_radius=48})
        move({-888,436,466}, {direct = true, settle = false, radius = 4, vertical_radius = 12})
        move({-912,408,392}, {direct = true, fight = false, radius = 4, vertical_radius = 16})
        -- Run south along the pipe before jumping at its lip. Stopping and
        -- crouching beside the ladder leaves too little speed for the window.
        leap({-888,376,392}, {-872,304,440}, {pace = 1, crouch = true, vertical_radius = 32})
        move({-832,288,440}, {direct = true, crouch = true, radius = 8})
        P.cross(69, {areas = true, direct = true, crouch = true, fight = false})
      end},
    }(visit, resumed)
  end
  return stages {
    {"sewer-valves", function()
      -- Four numbered wheels and the upper wheel: opposing lower wheels,
      -- upper wheel, remaining lower wheels. Stay out of the spinning drain.
      P.once(79, {fight = false, areas = true})
      P.once(195, {fight = false, areas = true})
      wait_until(function() return dk3.mover({index = 210}) == "open" end,
        {timeout = 15, fight = false, reason = "the first lower pair raises the sewer water"})
      -- The side wheel is below an overhang. Ascend through the open central
      -- water column before approaching the upper wheel.
      move({1144,-736,-252}, {direct = true, fight = false, radius = 8, vertical_radius = 16})
      move({1144,-736,-80}, {direct = true, fight = false, radius = 8, vertical_radius = 16})
      P.once(197, {fight = false, areas = true})
      move({1144,-736,-80}, {direct = true, fight = false, radius = 8, vertical_radius = 16})
      move({1144,-736,-252}, {direct = true, fight = false, radius = 8, vertical_radius = 16})
      P.once(196, {fight = false, areas = true})
      -- Cross the open water column before approaching the opposite wheel.
      -- The floor-route entrance below the central pipe is not a dive lane.
      move({1144,-736,-300}, {direct = true, fight = false, radius = 8, vertical_radius = 16})
      move({1144,-640,-300}, {direct = true, fight = false, radius = 8, vertical_radius = 16})
      P.once(194, {fight = false, areas = true, hold = true})
    end},
    {"upper-sewer-return", checkpoint = true, function()
      wait_until(function() return dk3.mover({index = 196}) == "open" and dk3.mover({index = 194}) == "open" end,
        {timeout = 15, reason = "lower wheels complete their target strokes"})
      -- The wheel's arrival queues its authored two-second target delay.
      -- Its open phase alone does not mean the water stroke has begun.
      wait(2.1)
      wait_until(function() local phase = dk3.mover {index = 210} return phase == "open" or phase == "closed" end,
        {timeout = 10, reason = "sewer water reaches its selected level"})
      -- The delayed lower wheel can drain the room before the swimmer
      -- returns. Its reverse stroke refills it through the same target chain.
      if dk3.mover({index = 210}) == "closed" then P.press(196, {fight = false, areas = true}) end
      wait_until(function() return dk3.mover({index = 210}) == "open" end,
        {timeout = 20, reason = "sewer water holds at the upper passage"})
      for _,point in ipairs({{1144,-736,-80},{1040,-736,-80},{1000,-736,-80},{960,-736,-96}}) do
        move(point, {direct = true, fight = false, radius = 8, vertical_radius = 16})
      end
      -- The pipe ends at a ladder, not a horizontal opening into the yard.
      move({928,-736,272}, {direct = true, fight = false, settle = false, radius = 2, vertical_radius = 8})
      move({924,-736,272}, {direct = true, fight = false, radius = 1, vertical_radius = 8, on_floor = true})
      move({880,-736,272}, {direct = true, fight = false, radius = 8, vertical_radius = 16})
    end},
    {"bomb-at-cracked-wall", checkpoint = true, function()
      expect(P.has(ingredients), "all four bomb ingredients required")
      P.follow()
      -- The guide returns through the sewer current. Ride its actual turns
      -- without stopping against the flow or trying to surface under a pipe.
      path({{-196,-736,48},{-196,93,48},{156,93,48},
        {156,1005,48},{-188,1005,48},{-196,1597,48}},
        {direct = true, settle = false, fight = false, radius = 32, vertical_radius = 16})
      P.approach(57, {areas = true})
      touch {index = 57}
      cinematic()
    end},
    {"escape-alcatraz", checkpoint = true, function()
      -- Follow the outside ledge beyond the bomb opening. The supplied
      -- corridor crosses a missing section as a walking edge; stop before it
      -- and jump from the actual sloping end onto the opposite ledge.
      P.stay()
      nodepath({-249,2665,-8}, {vertical_radius = 32})
      move({-249,2680,-8}, {direct = true, radius = 2, vertical_radius = 16, on_floor = true})
      leap({-249,2640,-8}, {-249,2448,-8}, {pace = 1, radius=32, vertical_radius = 16})
    end},
    {"dangling-metal-and-exit", checkpoint = true, function()
      nodepath({-816,2130,-184}, {vertical_radius = 32})
      move({-864,2184,-184}, {direct = true, radius = 2, vertical_radius = 16})
      leap({-800,2136,-184}, {-737,2082,-152}, {pace = 1, vertical_radius = 32, settle = false})
      move({-737,2082,120}, {direct = true, settle = false, radius = 4, vertical_radius = 12})
      move({-688,2082,120}, {direct = true, radius = 8, vertical_radius = 16})
    end},
    {"upper-metal-ledge", checkpoint = true, function()
      move({-624,2042,120}, {direct = true, radius = 4, vertical_radius = 16})
      leap({-712,2098,122}, {-864,2176,136}, {pace = 1, vertical_radius = 16})
      P.cross(64)
    end},
  }(visit, resumed)
end)

level("e4m1c", function(visit, resumed)
  return stages {
    {"showers-and-charcoal", function()
      P.take(25, nil, {areas = true}) P.take(41, nil, {areas = true})
      P.once(168)
      wait_until(function() return dk3.mover({index = 40}) == "open" end,
        {timeout = 10, reason = "bathroom windows finish lowering"})
      move({2480,1008,480}, {direct = true, radius = 8})
      move({2368,1008,328}, {direct = true, settle = false, radius = 8, vertical_radius = 24})
      P.take(102, 15, {areas = true})
    end},
    {"underground-waterway", checkpoint = true, function()
      local bullets=dk3.entity{index=94}
      if bullets and bullets.visible and bullets.wanted~=false then
        move({2064,448,344},{direct=true,radius=4,vertical_radius=16})
        leap({2064,448,344},{2016,448,368},{pace=0.5,radius=16,vertical_radius=16})
        P.take(94,nil,{direct=true})
      end
      P.take(181, nil, {areas = true})
      P.take(6, nil, {areas = true})
      nodepath({2406,178,344}, {crouch = true})
      move({2406,178,344}, {direct = true, crouch = true, radius = 8})
      P.breakage(115)
      for _, index in ipairs({96,97,29,316,30}) do P.take(index) end
      P.take(27, 16)
    end},
    {"broken-ladder", checkpoint = true, function()
      -- This surviving explosive barrel blocks the supplied return node.
      -- Clear it from the charcoal room before approaching its blast radius.
      P.breakage(208,{direct=true,hold=true,weapon=21})
      nodepath {920,-816,280}
      move({960,-736,289}, {direct = true, radius = 4})
      jump {duration = 0.2}
      move({968,-736,472}, {direct = true, settle = false, radius = 4, vertical_radius = 12})
      move({1016,-736,488}, {direct = true, radius = 8})
    end},
    {"release-lower-ladder", checkpoint = true, function()
      -- The small lower rod is visible beneath the folded ladder; the long
      -- support's centre is hidden until this foreground piece is broken.
      P.breakage(64, {direct = true, hold = true, weapon = 21, around = {921,-735,696}})
      move({1048,-736,508}, {direct = true, radius = 4, vertical_radius = 8})
      P.breakage(63, {direct = true, hold = true, weapon = 21, around = {1018,-735,830}})
      wait_until(function() return dk3.mover({index = 45}) == "open" end,
        {timeout = 10, reason = "lower ladder falls into climbing position"})
    end},
    {"dangling-grate", checkpoint = true, function()
      move({1072,-752,508}, {direct = true, radius = 4})
      leap({1072,-760,508}, {1080,-800,560}, {crouch = true, pace = 0.65, vertical_radius = 16})
      move({1080,-736,556}, {direct = true, crouch = true, radius = 2, vertical_radius = 12})
      -- This jump catches the hanging ladder beside the grate. Hand control
      -- to the outward crawl on real rung contact before climbing into the
      -- low ceiling above its western face.
      leap({1074,-736,556}, {1008,-780,588}, {settle = false, pace = 1, radius = 48, vertical_radius = 16})
      move({1008,-800,588}, {direct = true, radius = 4})
    end},
    {"upper-ladder", checkpoint = true, function()
      move({1044,-800,588}, {direct = true, crouch = true, radius = 4})
      move({1044,-736,704}, {direct = true, settle = false, radius = 4, vertical_radius = 8})
      move({1024,-736,692}, {direct = true, radius = 4, on_floor = true})
    end},
    {"released-ladder-and-rim", checkpoint = true, function()
      -- Step onto the ledge before jumping: against the old ladder, the
      -- ordinary jump key is still a climb command.
      move({984,-736,696}, {direct = true, radius = 2, on_floor = true})
      leap({1032,-736,692}, {1080,-736,872}, {settle = false, pace = 1, radius = 16, vertical_radius = 8})
      -- Hand off on real rung contact, settle on the ladder cap, then duck
      -- after takeoff to clear the low headroom beside the higher stone rim.
      move({1080,-736,848}, {direct = true, crouch = true, radius = 2, vertical_radius = 8})
      -- Jump outward from the ladder face. An inward jump is still a climb
      -- command and cannot lift the player from the cap onto the higher rim.
      leap({1080,-736,848}, {1040,-736,872}, {crouch = true, pace = 0.5, radius = 8, vertical_radius = 8})
      move({1040,-736,872}, {direct = true, crouch = true, radius = 4, vertical_radius = 12})
      -- The broken barrel raises the view above the trapdoor rim. The
      -- weight falls through the centre, clear of this north-side stand.
      for _,point in ipairs({{1008,-736,872},{1008,-712,872},{1008,-672,872}}) do
        move(point, {direct = true, radius = 6, vertical_radius = 12})
      end
      leap({1008,-672,872}, {1040,-672,906}, {pace = 1, radius = 16, vertical_radius = 16})
      move({1040,-672,906}, {direct = true, radius = 4, on_floor = true})
    end},
    {"cut-upper-support", checkpoint = true, function()
      P.breakage(62, {direct = true, hold = true, weapon = 21})
      P.breakage(61, {direct = true, hold = true, weapon = 21, around = {1072,-736,1077}})
    end},
    {"long-ladder", checkpoint = true, function()
      wait_until(function() return dk3.mover({index = 53}) == "open" end,
        {timeout = 10, fight = false, stance = {1040,-672,906}, around = {0,0,0},
          reason = "released weight lowers the long ladder"})
      -- Align on the barrel's western side, clear of the ladder's angled
      -- brace, before the jump and airborne duck under the pipe.
      move({1032,-672,906},{direct=true,fight=false,pace=0.1,radius=0.25,
        vertical_radius=8})
      leap({1032,-672,906}, {1008,-704,944}, {crouch=true,pace=0.1,
        radius=24,vertical_radius=16})
      move({936,-736,1272}, {direct = true, settle = false, fight = false, radius = 4, vertical_radius = 8})
      -- Keep an upward command until the body clears the rungs. A destination
      -- within eight units of the current climb height emits no up input and
      -- brakes the ascent before the unsupported outward stride completes.
      -- This elevated through-point hands off to the supported north bank.
      move({984,-736,1296}, {direct = true, settle = false, fight = false, radius = 12, vertical_radius = 48})
      move({984,-712,1256}, {direct = true, radius = 12})
    end},
    {"upper-barrel-and-girder", checkpoint = true, function()
      -- Jump past the burning barrel's approach field rather than walking
      -- into it; the next hop immediately leaves its flame for the girder.
      -- Crawl under the crossbeam beside the barrel, then jump from its
      -- west side. Jumping from the south hits the beam before the feet
      -- can clear the barrel's rim.
      move({976,-712,1256}, {direct = true, crouch = true, radius = 2})
      move({976,-656,1256}, {direct = true, crouch = true, radius = 12})
      leap({976,-656,1256}, {1008,-656,1290}, {pace = 0.5, radius = 24, vertical_radius = 8})
      leap({1008,-656,1290}, {1008,-690,1320}, {crouch = true, pace = 1, radius = 48, vertical_radius = 8})
    end},
    {"sulphur", checkpoint = true, function()
      move({1064,-736,1320}, {direct = true, crouch = true, radius = 2, on_floor = true})
      -- The farther x1088 point overlaps the upper beam. Land on the clear
      -- near edge before stepping around it toward the next barrel.
      leap({1064,-736,1320}, {1072,-736,1360}, {pace = 0.3, radius = 4, vertical_radius = 8})
      move({1080,-752,1360}, {direct = true, radius = 1, on_floor = true})
      move({1072,-736,1360}, {direct = true, settle = false, radius = 2})
      leap({1072,-736,1360}, {1032,-688,1400}, {crouch = true, pace = 1, radius = 32, vertical_radius = 8})
      move({1008,-688,1400}, {direct = true, radius = 8})
      leap({1008,-712,1400}, {1008,-784,1400}, {pace = 1, radius = 32, vertical_radius = 8})
      move({1008,-800,1400}, {direct = true, radius = 8})
      move({1008,-812,1596}, {direct = true, fight = false, settle = false, radius = 4, vertical_radius = 4})
      move({1008,-848,1608}, {direct = true, fight = false, radius = 4})
      move({1056,-724,1608},{direct=true,radius=4})
      if dk3.mover{index=73}~="open" then
        P.press(73,{areas=true,hold=true})
        wait_until(function() return dk3.mover{index=73}=="open" end,
          {timeout=10,reason="sulphur room gate clears the pickup approach"})
      end
      -- Keep the ingredient approach on this upper room's floor. Chasing
      -- guards heard below it leads back through the ladder shaft.
      P.take(104, 17, {direct = true, fight = false})
    end},
    {"return-to-sewer", checkpoint = true, function()
      move({1056,-724,1608}, {direct = true, radius = 4})
      if dk3.mover{index=73}~="open" then P.press(73, {areas = true, hold = true}) end
      wait_until(function() return dk3.mover({index = 73}) == "open" end,
        {timeout = 10, stance = {1056,-724,1608}, around = {0,0,0},
          reason = "upper room gate swings clear before entering its sweep"})
      -- The open gate leads into the ladder shaft. Cross its lip with a
      -- running descent instead of trying to settle on an airborne point.
      move({936,-724,1512}, {direct = true, settle = false, radius = 8, vertical_radius = 12})
      move({884,-736,1512}, {direct = true, fight = false, settle = false, radius = 4, vertical_radius = 12})
      -- Cross the bridge, then follow the outside landings. Their floor
      -- openings alternate north/south; the ingredient lies several floors
      -- below and steering straight at it repeatedly walks into the rail.
      for _,point in ipairs({{1120,-736,1512},{1120,-800,1440},{1136,-736,1440},
          {1104,-656,1440},{1040,-608,1448},{1008,-608,1368}}) do
        move(point, {direct = true, radius = 8, vertical_radius = 24, on_floor = true})
      end
      for _,landing in ipairs({{1176,-864},{984,-608},{792,-864},{600,-608},{488,-864}}) do
        local _,_,height = dk3.position()
        local south = landing[2] == -864
        for _,point in ipairs({{1104,south and -656 or -816,height},
            {1136,-736,height},{1104,south and -816 or -656,height},
            {1040,landing[2],height},{1008,landing[2],landing[1]}}) do
          move(point, {direct = true, radius = 8, vertical_radius = 24, on_floor = true})
        end
      end
      -- The east floor opening is the sewer exit. Pass around the west
      -- before collecting the suit, then deliberately enter that opening.
      for _,point in ipairs({{896,-816,488},{884,-736,488},{896,-656,488},{976,-608,488},{1040,-608,488}}) do
        move(point, {direct = true, radius = 8, vertical_radius = 24, on_floor = true})
      end
      P.take(8, nil, {direct = true})
      local suit = dk3.entity {index = 8}
      expect(not suit or not suit.visible, "collect the suit before entering the sewer opening")
      P.cross(37, {areas = true, fight = false, timeout = 180})
    end},
  }(visit, resumed)
end)

level("e4m2a", function(visit, resumed)
  return stages {
    {"cavern-kineticore", function()
      P.stay() P.take(49)
    end},
    {"first-waterfall-ripgun", checkpoint = true, function()
      -- The cave path ends at the cove; the guide's first falls begin across
      -- the attack-boost ledge. Cross to the ammunition bank, then descend
      -- into the water instead of following a partial ground route downhill.
      move({-2920,-1480,-412}, {weapon = 24, timeout = 120, radius = 16, vertical_radius = 24})
      P.take(195, nil, {direct = true, weapon = 24})
      leap({-2992,-1472,-412}, {-3168,-1488,-482}, {crouch = true, fight = false,
        pace = 1, radius = 24, vertical_radius = 24})
      -- Stay on the sloping bank. The area graph's route to its northern
      -- end descends into the lower cavern instead of following this ledge.
      for _,point in ipairs({{-3232,-1488,-472},{-3264,-1440,-472},
          {-3264,-1408,-456},{-3272,-1344,-465}}) do
        move(point, {direct = true, crouch = true, fight = false,
          radius = 8, vertical_radius = 16, pace = 0.5})
      end
      move({-3352,-1376,-944}, {direct = true, fight = false, settle = false, radius = 8, vertical_radius = 32})
      move({-2700,-1536,-900}, {fight = false, timeout = 120, radius = 8,
        vertical_radius = 16, on_floor = true})
      move({-2704,-1536,-900}, {direct = true, fight = false,
        radius = 1, vertical_radius = 8, on_floor = true, pace = 0.2})
      -- Build the diagonal run on the dry bank before takeoff. Starting the
      -- jump from rest cannot gain enough lateral speed before this ledge.
      -- Land on the upper continuation rather than the narrow first corner.
      leap({-2672,-1504,-900}, {-2576,-1432,-874}, {crouch = true,
        fight = false, pace = 1, radius = 40, vertical_radius = 24})
      move({-2469,-1443,-872}, {direct = true, crouch = true, fight = false,
        timeout = 120, radius = 16, vertical_radius = 24})
      move({-2469,-1456,-1376}, {direct = true, fight = false, settle = false, radius = 8, vertical_radius = 32})
      move({-2456,-1560,-1376}, {direct = true, fight = false, timeout = 120, radius = 16, vertical_radius = 32})
      -- Leave the water at the ladder's lower bank. Following the two
      -- adjoining ladder area endpoints sends the swimmer up and down the
      -- same rungs instead of stepping west onto that bank.
      move({-2510,-1499,-1320}, {direct = true, settle = false, radius = 8, vertical_radius = 16})
      move({-2544,-1499,-1316}, {direct = true, crouch = true, settle = false, radius = 8, vertical_radius = 24})
      move({-2560,-1540,-1316}, {direct = true, crouch = true, radius = 8, vertical_radius = 24})
      for _,point in ipairs({{-2700,-1536,-1316},{-2700,-1728,-1316},{-2688,-2048,-1320},
          {-2440,-2048,-1277},{-2400,-2120,-1272},{-2260,-2192,-1264}}) do
        move(point, {direct = true, radius = 12, vertical_radius = 24})
      end
      P.take(722, nil, {direct = true})
    end},
    {"flooded-building-hall", checkpoint = true, function()
      -- The boarded windows and outside medicine are an optional detour.
      -- Continue through the flooded building to its upper hallway instead.
      P.take(715, nil, {areas = true, weapon = 22})
      P.approach(724, {areas = true, standoff = 32, weapon = 22})
      P.take(724, nil, {areas = true, weapon = 22})
    end},
    {"cavern-acro", checkpoint = true, function()
      move({-1264,-604,-1377}, {radius = 8, vertical_radius = 16, weapon = 22, timeout = 90})
      move({-1237,-604,-1375}, {direct = true, radius = 2, vertical_radius = 16, pace = 0.4, weapon = 22})
      move({-1200,-604,-1400}, {direct = true, on_floor = true, radius = 8, vertical_radius = 24, pace = 0.4, weapon = 22})
      move({-764,-832,-1432}, {radius = 12, vertical_radius = 24, weapon = 22, timeout = 90})
      move({-764,-820,-1432}, {direct = true, fight = false, settle = false, radius = 4, vertical_radius = 16})
      move({-764,-764,-1248}, {direct = true, fight = false, settle = false, radius = 4, vertical_radius = 4})
      move({-764,-728,-1256}, {direct = true, radius = 8, vertical_radius = 16})
      -- The upper building opens onto the balcony before the first-floor
      -- cavern becomes reachable. Resolve these obstacles in guide order.
      P.breakage(787, {areas = true, weapon = 22})
      P.breakage(843, {direct = true, hold = true, weapon = 21})
      -- Aim at the window from inside its actual room. An automatic firing
      -- approach from the ladder can circle the solid barrel beside the wall.
      move({-880,-480,-1256}, {radius = 8, vertical_radius = 16, weapon = 22})
      P.break_group({790,791,792}, {direct = true, hold = true, weapon = 22})
      -- The planks cover the west window. Hop its sill before aiming down
      -- the outside balcony; the building wall blocks that shot from inside.
      move({-880,-480,-1256}, {radius = 8, vertical_radius = 16})
      move({-896,-480,-1256}, {direct = true, crouch = true,
        radius = 4, vertical_radius = 16, fight = false})
      leap({-896,-480,-1256}, {-960,-480,-1256},
        {crouch = true, pace = 0.5, radius = 12, vertical_radius = 16})
      -- Finish the exposed guard before proceeding behind the balcony barrels.
      kill({index = 786}, {weapon = 22, hold = true,
        arena = {{-980,-640},{-952,-448}}, timeout = 90})
      P.take(775, nil, {areas = true, weapon = 22})
      -- Return from behind the barrels along the actual balcony before
      -- routing toward the first-floor cavern. The pocket's nearest area
      -- can otherwise send the swimmer down into the outside deep water.
      move({-960,-992,-1256}, {direct = true, fight = false,
        radius = 4, vertical_radius = 8, pace = 0.5})
      -- The southern obstruction rises34 units above the balcony. Climb
      -- its measured top before stepping down onto the northern walkway.
      leap({-960,-992,-1256}, {-960,-960,-1222}, {crouch = true,
        pace = 0.35, radius = 8, vertical_radius = 8})
      move({-960,-912,-1222}, {direct = true, crouch = true, fight = false,
        radius = 4, vertical_radius = 8, pace = 0.35})
      move({-960,-864,-1256}, {direct = true, crouch = true, fight = false,
        radius = 4, vertical_radius = 8, pace = 0.35})
      move({-960,-480,-1256}, {direct = true, fight = false,
        radius = 8, vertical_radius = 16, pace = 0.5})
      P.take(774, nil, {areas = true, weapon = 22})
    end},
    {"return-to-cove", checkpoint = true, function()
      move({-880,2500,-864}, {radius = 16, vertical_radius = 24, timeout = 120})
      move({-680,2448,-864}, {radius = 12, vertical_radius = 24})
      P.once(191, {areas = true}) cinematic()
      wait_until(function() return dk3.mover({index = 118}) == "open" end,
        {timeout = 20, reason = "upper-station lever opens the pedestrian passage"})
      move({-880,2500,-864}, {radius = 16, vertical_radius = 24})
      P.press(695, {areas = true})
      wait_until(function() return dk3.mover({index = 95}) == "open" end,
        {timeout = 20, reason = "called trolley opens the station door"})
      P.press(101, {areas = true})
      wait_until(function() return dk3.mover({index = 101}) == "open" end,
        {timeout = 10, reason = "trolley cage door opens for boarding"})
      ride {index = 98} P.follow()
    end},
    {"cove-return-supplies", checkpoint = true, function()
      P.press(101, {areas = true})
      move({-1560,2504,-1608}, {direct = true, radius = 12, vertical_radius = 24})
      if dk3.health() < 75 then
        P.stay()
        P.take(7, nil, {areas = true, weapon = 22})
        if dk3.health() < 90 then P.take(8, nil, {areas = true, weapon = 22}) end
        P.follow()
      end
    end},
    {"boat-dock", checkpoint = true, function()
      P.cross(45, {areas = true, weapon = 22, timeout = 180})
    end},
  }(visit, resumed)
end)

-- Retained alternate waterway map: use the tram entrance, not the deep-water
-- entrance that returns below the objective. The main installed BSP also
-- contains the waterfall/building route.
level("e4m2b", function(visit, resumed)
  return stages {
    {"waterway-weapons", function() P.take(27) P.take(48) end},
    {"upper-tram-return", checkpoint = true, function() P.cross(66) end},
  }(visit, resumed)
end)

level("e4m3a", function(visit, resumed)
  return stages {
    {"boat-arrival", function() cinematic() P.follow() end},
    {"fallen-neon-sign", checkpoint = true, function()
      P.breakage(13)
      wait_until(function()
        local floor = dk3.entity {index = 29}
        return not floor or floor.broken or (floor.health and floor.health <= 0)
      end, {timeout = 30, reason = "neon sign opens the asphalt"})
    end},
    {"tower-basement", checkpoint = true, function() P.cross(23, {areas = true, timeout = 180}) end},
  }(visit, resumed)
end)

level("e4m3b", function(visit, resumed)
  return stages {
    {"pipes-and-ventilation", function() P.take(22, nil, {areas = true}) end},
    {"offices-and-elevator-shaft", checkpoint = true, function()
      -- Approach the square support from its open north side. The south
      -- face is solid; jumping there only catches its outside edge.
      move({-320,-248,-440}, {radius = 8, vertical_radius = 16, weapon = 21})
      -- Keep the whole body in the narrow north-side approach. A few units
      -- of lateral error catches the square support's outside bevel.
      for _, point in ipairs({{-328,-256,-440},{-336,-264,-440},
          {-344,-272,-440},{-344,-280,-440},{-352,-288,-438},
          {-360,-288,-422},{-400,-288,-422}}) do
        move(point, {direct = true, crouch = true, radius = 1,
          vertical_radius = 8, pace = 0.5, weapon = 21})
      end
      for _, point in ipairs({{-768,-288,-422},{-802,-288,-400}}) do
        move(point, {direct = true, crouch = true, radius = 4,
          vertical_radius = 8, pace = 0.5, weapon = 21})
      end
      P.breakage(85, {direct = true, hold = true, crouch = true, weapon = 21})
      leap({-802,-288,-400}, {-802,-248,-360}, {radius = 16, vertical_radius = 16})
      -- Clear the grate's floor opening before routing through the offices.
      move({-802,-192,-360}, {direct = true, radius = 8, vertical_radius = 16, weapon = 21})
      P.press(335, {areas = true})
      P.take(73, nil, {areas = true, weapon = 21})
      P.take(72, nil, {areas = true, weapon = 21})
      for _, index in ipairs({79,382,49}) do
        kill({index = index}, {weapon = 21, timeout = 60})
      end
      P.take(23, nil, {areas = true, weapon = 21}) P.follow()
    end},
    {"upper-staircase", checkpoint = true, function()
      -- The shaft's north wall separates it from the office. Approach along
      -- the supported southern corridor and jump to the ladder's open face.
      for _,point in ipairs({{-344,-424,-136},{-336,-432,-136},{-328,-440,-136},
          {-320,-448,-136},{-312,-456,-136},{-304,-448,-136},{-296,-440,-136},
          {-288,-432,-136},{-280,-432,-136},{-272,-432,-136},{-264,-432,-136},
          {-256,-432,-136},{-248,-432,-136},{-240,-432,-136},{-232,-432,-136},
          {-224,-432,-136},{-216,-440,-136},{-208,-448,-136},{-200,-456,-136},
          {-192,-464,-136},{-184,-472,-136},{-176,-480,-136},{-168,-488,-136},
          {-160,-496,-136},{-128,-496,-136},{-96,-496,-136},{-64,-496,-136},
          {-32,-496,-136},{0,-496,-136},{16,-496,-136},{24,-488,-129},{32,-480,-121}}) do
        move(point,{direct=true,weapon=22,pace=0.5,radius=4,vertical_radius=16})
      end
      -- The START_OPEN shaft leaf leaves a narrow northern gap. Cross that
      -- gap straight before turning toward the ladder inside the shaft.
      move({32,-425,-136},{direct=true,weapon=22,radius=2,vertical_radius=16})
      move({78,-425,-136},{direct=true,fight=false,pace=0.25,radius=0.5,vertical_radius=8})
      leap({78,-425,-136}, {152,-304,-256},
        {fight = false, settle = false, pace = 0.8, radius = 24, vertical_radius = 64})
      move({152,-304,160}, {direct = true, fight = false, settle = false, radius = 8, vertical_radius = 8})
      -- Strafe along the rungs onto the west ledge before descending to its
      -- door. Stepping backward from rest falls below the narrow plank.
      move({80,-304,184}, {direct = true, fight = false, settle = false, radius = 4, vertical_radius = 112})
      move({80,-344,88}, {direct = true, weapon = 22, radius = 8, vertical_radius = 16})
      move({80,-384,92},{direct=true,weapon=22,radius=4,vertical_radius=16})
      move({80,-392,92},{direct=true,weapon=22,radius=2,vertical_radius=16})
      -- The adjacent "never" leaf is a fixed set piece. The plank passes
      -- through the real opening immediately south of it.
      move({32,-392,88},{direct=true,weapon=22,radius=8,vertical_radius=16})
      -- Clear the rocket guards from the first upper landing before the
      -- final stair approach. Automatic close-range weapon selection here
      -- trades slow shotgun shots against sustained rocket fire.
      -- The area route can cut across the open elevator shaft from the
      -- lower supply landing. Follow the authored stair corridor first.
      nodepath({-176,-39,88}, {radius = 32, vertical_radius = 32, weapon = 22})
      move({-176,-39,88}, {radius = 8, vertical_radius = 16, weapon = 22})
      for _, index in ipairs({60,377}) do
        kill({index = index}, {weapon = 22,
          arena = {{-304,-80},{32,432}}, timeout = 90})
      end
      -- Take needed medicine while climbing. Full-health detours can route
      -- away from the staircase and back into the lower elevator shaft.
      for _, index in ipairs({65,39,59}) do
        P.take(index, nil, {areas = true, weapon = 22})
      end
      P.cross(53, {areas = true, weapon = 22, timeout = 180})
    end},
  }(visit, resumed)
end)

level("e4m3c", function(visit, resumed)
  return stages {
    {"upper-floors", function()
      -- The guard across the ground-floor atrium can keep shooting through
      -- several stair flights. Answer him from the first landing first.
      move({-36,400,312}, {radius = 8, vertical_radius = 16})
      kill({index = 65}, {weapon = 24, hold = true,
        arena = {{-80,352},{16,432}}, timeout = 90})
      -- Replenish on the occupied floors before the plank crossing. The
      -- seventh-floor Novabeam is an optional elevator-shaft detour.
      for _, index in ipairs({29,49,45,47,364,7,20,2,43,390}) do
        P.take(index, nil, {areas = true, weapon = 22})
      end
    end},
    {"eighth-floor-elevator", checkpoint = true, function()
      move({-8,-408,1432}, {radius = 8, vertical_radius = 16, weapon = 22})
      P.stay()
      P.press(158, {areas = true})
      leap({32,-422,1432}, {116,-422,1432},
        {settle = false, radius = 8, vertical_radius = 48})
      move({116,-422,632}, {direct = true, settle = false,
        radius = 4, vertical_radius = 12})
      move({152,-472,484}, {direct = true, radius = 8, vertical_radius = 16})
      P.breakage(81, {direct = true, hold = true, weapon = 21})
      move({152,-472,344}, {direct = true, radius = 8, vertical_radius = 16})
      P.breakage(87, {areas = true, weapon = 21})
      P.press(135, {areas = true})
      move({16,-408,312}, {radius = 8, vertical_radius = 16})
      P.follow()
    end},
    {"tram-to-laboratories", checkpoint = true, function()
      P.once(14, {areas = true}) P.follow()
      touch({index = 3}, {timeout = 90})
      wait_until(function() return dk3.mover({index = 39}) == "open" end,
        {timeout = 15, reason = "tram approach opens its door"})
      P.cross(10, {areas = true, timeout = 180})
    end},
  }(visit, resumed)
end)

level("e4m4a", function(visit, resumed)
  return stages {
    {"fountain-green-card", function()
      -- The warehouse consumes the second green card. Returning with yellow
      -- must not restart the first arrival's train/fountain approach.
      if dk3.has_key(4) then return end
      if not dk3.has_key(2) then
        -- Leave through the train's east doorway before choosing a station
        -- supply route; its other side is the solid car body.
        move({56,-232,-3416}, {direct = true, radius = 8, vertical_radius = 16})
        P.press(57, {areas = true})
        P.take(52, nil, {areas = true, weapon = 22})
        P.take(30, nil, {areas = true, weapon = 22})
        P.take(54, nil, {areas = true, weapon = 22})
        P.take(747, nil, {areas = true, weapon = 22})
        -- Follow the guide's lobby preparation before entering the fountain
        -- firefight. Arriving with an exhausted Ripgun forced slow fallback
        -- shots against the security guards.
        P.take(28, nil, {areas = true, weapon = 22})
        P.take(18, nil, {areas = true, weapon = 22})
        P.take(750, nil, {areas = true, weapon = 22})
      end
      if not dk3.has_key(2) then
        -- The card is below the fountain rim. Take the eastern stair and
        -- its36-unit hop before dropping inside; the nearest lower area
        -- otherwise holds the route outside the raised bowl.
        P.stay()
        move({1440,192,-3128}, {weapon = 22, radius = 8, vertical_radius = 16})
        move({1376,192,-3128}, {direct = true, fight = false,
          radius = 4, vertical_radius = 8})
        leap({1376,192,-3128}, {1344,192,-3092},
          {fight = false, pace = 0.4, radius = 12, vertical_radius = 12})
        move({1328,96,-3092}, {direct = true, fight = false,
          radius = 8, vertical_radius = 16})
        move({1280,48,-3208}, {direct = true, fight = false, pace = 0.35,
          radius = 8, vertical_radius = 16})
        P.take(637, 2, {direct = true, weapon = 22})
        P.follow()
      end
    end},
    {"security-wing", checkpoint = true, function()
      if not dk3.has_key(4) then
        -- Secure the fountain and upper security approach before focusing
        -- on the reader; a use action keeps its aim on the control.
        clear {radius = 1000, weapon = 22, timeout = 180}
        P.once(634, {areas = true, weapon = 22}) P.cross(518, {areas = true, weapon = 22})
      else
        P.once(38, {areas = true}) P.follow() P.cross(61, {areas = true})
      end
    end},
  }(visit, resumed)
end)

level("e4m4b", function(visit, resumed)
  return stages {
    {"barracks-transport", function()
      -- The guide secures the bay before exploring its supplies. In
      -- particular the upper medicine route is exposed to the SEALs below.
      clear {radius = 900, weapon = 22, timeout = 240}
      for _, index in ipairs({36,63,496}) do P.take(index, nil, {weapon = 22}) end
      P.approach(485)
      clear {radius = 900, weapon = 22, timeout = 240}
      -- The guide allows leaving Mikiko in the secured transport bay.
      P.stay()
      board_shuttle(485, 621, 10, {288,-144,-2516}, {336,-144,-2472}, {288,-144,-2512})
    end},
    {"blue-card-behind-door", checkpoint = true, function()
      leap({-1760,-768,-3200}, {-1760,-800,-3160},
        {radius = 12, vertical_radius = 16})
      P.press(57, {areas = true})
      wait_until(function() return dk3.mover({index = 199}) == "open" end,
        {timeout = 10, reason = "glass room door opens"})
      -- The open leaf covers the card's alcove. The guide requires entering
      -- the room and closing it with the far switch before collecting it.
      P.press(498, {areas = true})
      wait_until(function() return dk3.mover({index = 199}) == "closed" end,
        {timeout = 10, reason = "closed door exposes the blue card"})
      P.take(56, 1, {areas = true})
      P.press(498, {areas = true})
      wait_until(function() return dk3.mover({index = 199}) == "open" end,
        {timeout = 10, reason = "reopen glass room for the return transport"})
      -- Return along the raised hall before approaching the shuttle edge.
      -- A diagonal shortcut clips its side and drops onto the floor below.
      move({-1840,-864,-3160}, {radius = 8, vertical_radius = 16})
      move({-1760,-864,-3160}, {direct = true, radius = 8, vertical_radius = 16})
      move({-1760,-816,-3160}, {direct = true, radius = 4, vertical_radius = 16})
    end},
    {"firing-range-transport", checkpoint = true, function()
      move({-1760,-752,-3200}, {direct = true, radius = 8,
        vertical_radius = 24, pace = 0.5})
      P.press(621, {areas = true}) ride {index = 10}
      leap({288,-128,-2512}, {288,-96,-2472},
        {radius = 12, vertical_radius = 16})
      move({288,-48,-2456}, {radius = 8, vertical_radius = 16})
      kill({index = 415}, {weapon = 22, timeout = 60})
      clear {radius = 800, weapon = 22, timeout = 180}
      board_shuttle(487, 624, 623, {288,208,-2516}, {336,208,-2472}, {288,208,-2512}, {areas = true})
      leap({288,1472,-3200}, {288,1504,-3160}, {radius = 12, vertical_radius = 16})
      move({288,1568,-3160}, {direct = true, radius = 8, vertical_radius = 24})
      P.once(476, {areas = true})
    end},
    {"five-firing-targets", checkpoint = true, function()
      -- The range requires shooting from its stand; walking onto the target
      -- triggers is not a valid completion of the marksmanship puzzle.
      move({288,2528,-3200}, {radius = 8, vertical_radius = 16})
      for _, index in ipairs({115,288}) do P.take(index, nil, {areas = true}) end
      kill({index = 55}, {weapon = 22, timeout = 60})
      local medicine = dk3.entity {index = 106}
      if medicine and medicine.visible and medicine.wanted ~= false then
        move({400,2664,-3200}, {direct = true, fight = false,
          radius = 4, vertical_radius = 16, pace = 0.5})
        point_at({400,2536,-3176})
        leap({400,2600,-3200}, {400,2536,-3176},
          {crouch = true, fight = false, radius = 16, vertical_radius = 16})
        P.take(106, nil, {direct = true, crouch = true})
        move({400,2600,-3200}, {direct = true, crouch = true,
          fight = false, radius = 8, vertical_radius = 16})
      end
      for lane, index in ipairs({113,271,273,275,277}) do
        for _, ammo in ipairs({607+lane*2,608+lane*2}) do
          P.take(ammo, nil, {areas = true, weapon = 21})
        end
        move({528-lane*80,2840,-3200}, {direct = true, radius = 8, vertical_radius = 16})
        shoot({index = index}, {hold = true, weapon = 21, timeout = 90})
      end
      wait_until(function()
        local card = dk3.entity {index = 3}
        return dk3.has_key(2) or (card and card.visible)
      end, {timeout = 15, reason = "five targets expose the control card"})
      P.take(3, 2, {areas = true})
    end},
    {"warehouse-transport-and-green-door", checkpoint = true, function()
      P.press(270, {areas = true})
      move({288,1568,-3160}, {radius = 8, vertical_radius = 16})
      move({288,1504,-3160}, {direct = true, radius = 8, vertical_radius = 16})
      move({288,1456,-3200}, {direct = true, radius = 8, vertical_radius = 24, pace = 0.5})
      P.press(624, {areas = true}) ride {index = 623}
      move({320,208,-2512}, {direct = true, fight = false,
        radius = 4, vertical_radius = 8, pace = 0.5})
      point_at({368,208,-2472})
      leap({320,208,-2512}, {368,208,-2472},
        {crouch = true, fight = false, radius = 32, vertical_radius = 16})
      move({368,208,-2472}, {direct = true, radius = 8, vertical_radius = 16})
      move({368,96,-2472}, {direct = true, radius = 8, vertical_radius = 16})
      -- Recall the party before returning to the narrow upper control step;
      -- Mikiko was left waiting there during the first shuttle departure.
      hold_lab_party()
      move({880,144,-2408}, {radius = 8, vertical_radius = 16})
      point_at({880,64,-2376})
      leap({880,112,-2408}, {880,64,-2376}, {radius = 24, vertical_radius = 16})
      move({880,32,-2376}, {direct = true, radius = 8, vertical_radius = 16})
      P.press(486, {direct = true, hold = true})
      move({880,144,-2408}, {radius = 8, vertical_radius = 16})
      move({640,144,-2464}, {radius = 8, vertical_radius = 16})
      -- Descend the station steps before boarding; a jump lands on the
      -- side rail and leaves the driver above the lower platform.
      for _, stair in ipairs({{528,32,-2472},{560,32,-2488},
          {592,32,-2504},{624,32,-2520},{656,32,-2536},
          {704,32,-2552}}) do
        move(stair, {direct = true, fight = false,
          radius = 4, vertical_radius = 8, pace = 0.5})
      end
      board_shuttle(486, 630, 629, {800,32,-2596}, {736,32,-2552},
        {800,32,-2592}, {areas = true})
      move({-904,32,-2880}, {direct = true, radius = 4, vertical_radius = 8, pace = 0.5})
      point_at({-944,32,-2840})
      leap({-904,32,-2880}, {-944,32,-2840},
        {crouch = true, fight = false, radius = 32, vertical_radius = 16})
      move({-1000,32,-2840}, {direct = true, radius = 8, vertical_radius = 16})
      P.once(479, {areas = true})
      wait_until(function() return dk3.mover({index = 318}) == "open" end,
        {timeout = 10, reason = "second green card opens the warehouse"})
    end},
    {"warehouse-storage-and-first-lift", checkpoint = true, function()
      -- Cross the opened warehouse entrance before turning toward storage;
      -- the station's upper floor does not continue around its outer wall.
      move({-1256,32,-2880}, {direct = true, radius = 8, vertical_radius = 16})
      move({-1328,32,-2888}, {direct = true, radius = 16, vertical_radius = 16})
      move({-1360,192,-2888}, {direct = true, radius = 16, vertical_radius = 16})
      clear {radius = 800, vertical_radius = 48, weapon = 22, timeout = 180}
      P.press(383, {areas = true})
      move({-1360,352,-2888}, {radius = 16, vertical_radius = 16})
      move({-1792,576,-2888}, {radius = 8, vertical_radius = 16})
      -- Drop down the clear eastern end of the storage ledge. The western
      -- diagonal crosses the raised crates instead of the lower aisle.
      move({-1792,736,-2984}, {direct = true, fight = false,
        radius = 8, vertical_radius = 16, pace = 0.5})
      move({index = 100}, {radius = 32, vertical_radius = 24, weapon = 22})
      for _, index in ipairs({100,394}) do P.take(index, nil, {areas = true, weapon = 22}) end
      clear {radius = 800, vertical_radius = 96, weapon = 22, timeout = 180}
      ride({index = 343}, {timeout = 120})
    end},
    {"warehouse-control-room", checkpoint = true, function()
      P.press(97, {areas = true})
      P.press(397, {areas = true})
      -- Trains are admitted at their first path corner, not the editor's
      -- brush origin. This lift starts at vatora in the western corridor.
      move({-2432,544,-2784}, {radius = 16, vertical_radius = 16})
      move({-2432,480,-2796}, {direct = true, radius = 8, vertical_radius = 16})
      move({-2432,400,-2796}, {direct = true, radius = 8, vertical_radius = 16})
      P.press(379, {areas = true, hold = true}) ride({index = 323}, {timeout = 120})
      clear {radius = 480, vertical_radius = 96, weapon = 22, timeout = 120}
    end},
    {"warehouse-vent-to-lockers", checkpoint = true, function()
      -- Floor hatch, lower grate, connecting vent and the second floor
      -- hatch/ladder. Each barrier must break before routing through it.
      P.breakage(89, {areas = true, crouch = true, weapon = 21})
      P.breakage(88, {areas = true, crouch = true, weapon = 21})
      P.take(320, nil, {areas = true, crouch = true})
      P.breakage(102, {areas = true, crouch = true, weapon = 21})
      -- Use the authored corridor nodes through the multi-level barracks;
      -- a straight chord crosses the transport shaft below its upper room.
      nodepath({-1832,-1000,-3385}, {crouch = true, weapon = 21})
      for _, point in ipairs({{-1832,-1104,-3384},{-1760,-1152,-3368},
          {-1760,-1232,-3368}}) do
        move(point, {direct = true, crouch = true, radius = 8, vertical_radius = 16})
      end
      P.breakage(474, {direct = true, crouch = true, hold = true, weapon = 21})
      P.breakage(72, {crouch = true, weapon = 21})
    end},
    {"sauna-and-yellow-card", checkpoint = true, function()
      local medicine = dk3.entity {index = 27}
      if medicine and medicine.visible and medicine.wanted ~= false then
        -- Approach the narrow locker from its open front, rather than
        -- routing around the rotated leaf into its right-hand side.
        move({-1136,-2192,-3184}, {radius = 4, vertical_radius = 16, weapon = 22})
        P.press(227, {direct = true, hold = true, weapon = 22})
        wait_until(function()
          return dk3.mover{index=226}=="open" and dk3.mover{index=227}=="open"
        end,{timeout=10,fight=false,reason="both locker leaves clear the opening"})
        P.take(27, nil, {direct = true, crouch=true, weapon = 22})
      end
      for _, index in ipairs({25,24}) do P.take(index, nil, {areas = true, weapon = 22}) end
      P.once(67, {areas = true})
      move({-1988,-1664,-3184}, {direct = true, radius = 8, vertical_radius = 16})
      kill({index = 118}, {weapon = 22, hold = true,
        arena = {{-2048,-1704},{-1920,-1632}}, timeout = 90})
      P.take(70, 4, {direct = true, weapon = 22})
    end},
    {"return-to-yellow-door", checkpoint = true, function()
      -- The lockers return directly to the blue-card barracks station.
      -- Its car is still parked in the main bay, so summon it before entry.
      move({-1988,-1664,-3184}, {direct = true,
        radius = 8, vertical_radius = 16, weapon = 22})
      P.once(483, {areas = true})
      move({-1760,-1200,-3200}, {radius = 4, vertical_radius = 16, weapon = 22})
      -- The return stair lies beyond the removed barracks door. Leave
      -- its uncompiled threshold directly before resuming area routing.
      for _, stair in ipairs({{-1760,-1040,-3200},{-1760,-1008,-3184},
          {-1760,-976,-3176},{-1760,-944,-3168},{-1760,-912,-3160},
          {-1760,-864,-3160}}) do
        move(stair, {direct = true, radius = 4, vertical_radius = 8, pace = 0.5})
      end
      board_shuttle(622, 621, 10, {-1760,-752,-3204},
        {-1760,-800,-3160}, {-1760,-752,-3200}, {areas = true})
      leap({288,-128,-2512}, {288,-96,-2472}, {radius = 12, vertical_radius = 16})
      -- Climb the main-bay ramp on its measured floor corridor before the
      -- exit's door planner takes over. Its coarse approach oscillates at
      -- the ramp's lower corner instead of reaching the upper hallway.
      move({640,-224,-2464},{direct=true,fight=false,pace=0.5,radius=8,vertical_radius=16})
      local ramp=walkflood({{832,-192,-2408}},{624,-256,896,-128},8,{crouch=true})[1]
      assert(ramp,"no supported main-bay return ramp")
      for _,point in ipairs(ramp) do
        move(point,{direct=true,crouch=point.mark=="c",fight=false,
          pace=0.5,radius=4,vertical_radius=8})
      end
      P.cross(413, {areas = true})
    end},
  }(visit, resumed)
end)

level("e4m4c", function(visit, resumed)
  return stages {
    {"power-wing-green-card", function()
      P.stay()
      P.take(20, nil, {areas = true})
      P.take(39, nil, {areas = true})
      P.take(768, nil, {areas = true})
      board_shuttle(658, 874, 873, {288,-144,-2516},
        {368,-144,-2472}, {288,-144,-2512}, {areas = true}, function()
          -- Guards can arrive aboard the summoned car. Clear its deck
          -- before committing to the narrow, non-strafing boarding walk.
          kill({index = 50}, {hold = true, weapon = 21,
            arena = {{352,-256},{512,0}}, timeout = 120})
        end)
      leap({320,-1392,-3200}, {368,-1392,-3160}, {radius = 48, vertical_radius = 16})
      move({368,-1392,-3160}, {direct = true, radius = 8, vertical_radius = 16})
      kill({index = 622}, {weapon = 21, timeout = 120})
      P.take(6, 2, {areas = true})
      P.take(36, nil, {areas = true})
      P.take(37, nil, {areas = true})
      for _, index in ipairs({38,769,770}) do P.take(index, nil, {areas = true}) end
      P.press(874, {areas = true}) ride {index = 873}
      leave_central_shuttle(-144)
    end},
    {"atrium-blue-card", checkpoint = true, function()
      board_shuttle(648, 871, 870, {288,208,-2516},
        {368,208,-2472}, {288,208,-2512}, {areas = true})
      leap({256,1456,-3200}, {208,1456,-3160}, {radius = 48, vertical_radius = 16})
      move({208,1456,-3160}, {direct = true, radius = 8, vertical_radius = 16})
      kill({index = 636}, {weapon = 21, timeout = 90})
      P.take(772, nil, {areas = true})
      P.once(679, {areas = true})
      wait_until(function() return dk3.mover({index = 260}) == "open" end,
        {timeout = 15, reason = "green-card laboratory doors open"})
      P.press(258, {areas = true})
      P.press(551, {areas = true})
      clear {radius = 640, vertical_radius = 128, timeout = 180}
      P.take(35, nil, {areas = true})
      if not dk3.has_key(1) then
        -- Reach the card from the low side of its computer terminal.
        -- Climbing onto the terminal's high back puts the player's feet
        -- above the thin card's touch volume.
        move({864,2512,-3104}, {radius = 4, vertical_radius = 16, weapon = 24})
        move({864,2512,-3104}, {direct = true, fight = false,
          radius = 2, vertical_radius = 8, pace = 0.5, weapon = 24})
        leap({864,2512,-3104}, {888,2512,-3070},
          {crouch = true, fight = false, pace = 0.2, radius = 16, vertical_radius = 8})
        move({888,2512,-3070}, {direct = true, crouch = true, fight = false,
          radius = 2, vertical_radius = 8, pace = 0.2})
        local tx,ty,tz = dk3.position()
        leap({tx,ty,tz}, {912,2536,-3045},
          {crouch = true, fight = false, pace = 0.15, radius = 16, vertical_radius = 8})
        move({912,2536,-3045}, {direct = true, fight = false,
          radius = 1, vertical_radius = 4, pace = 0.25})
        P.take(49, 1, {direct = true, weapon = 24})
      end
      P.take(28, nil, {weapon = 24})
      P.press(871) ride {index = 870}
      leave_central_shuttle(208)
    end},
    {"generator-wing", checkpoint = true, function()
      leave_central_shuttle(208)
      board_shuttle(658, 874, 873, {288,-144,-2516},
        {368,-144,-2472}, {288,-144,-2512}, {areas = true})
      leap({320,-1392,-3200}, {368,-1392,-3160}, {radius = 48, vertical_radius = 16})
      move({368,-1392,-3160}, {direct = true, radius = 8, vertical_radius = 16})
      for _, point in ipairs({{368,-1544,-3160},{288,-1546,-3160}}) do
        move(point, {direct = true, radius = 8, vertical_radius = 16, weapon = 24})
      end
      P.once(682)
      wait_until(function() return dk3.mover({index = 255}) == "open" end,
        {timeout = 15, reason = "blue-card generator doors open"})
      P.once(18)
      wait_until(function() return dk3.mover({index = 109}) == "open" end,
        {timeout = 20, reason = "generator control room raises the lift gate"})
      P.once(119)
    end},
    {"two-generator-weak-points", checkpoint = true, function()
      wait_until(function() return dk3.mover({index = 120}) == "open" end,
        {timeout = 20, reason = "generator lift reaches the lower floor"})
      for _, point in ipairs({{488,-2560,-3296},{488,-2960,-3296},{288,-2960,-3296}}) do
        move(point, {direct = true, radius = 8, vertical_radius = 16, weapon = 21})
      end
      P.breakage(92, {direct = true, hold = true, weapon = 21})
      move({488,-2960,-3296}, {direct = true, radius = 8, vertical_radius = 16})
      move({488,-2560,-3296}, {direct = true, radius = 8, vertical_radius = 16})
      move({88,-2560,-3296}, {direct = true, crouch = true, radius = 8, vertical_radius = 16})
      move({88,-2160,-3296}, {direct = true, crouch = true, radius = 8, vertical_radius = 16})
      move({288,-2160,-3296}, {direct = true, crouch = true, radius = 8, vertical_radius = 16})
      P.breakage(664, {direct = true, crouch = true, hold = true, weapon = 21})
      move({88,-2160,-3296}, {direct = true, crouch = true, radius = 8, vertical_radius = 16})
      move({88,-2560,-3296}, {direct = true, crouch = true, radius = 8, vertical_radius = 16})
      move({336,-2560,-3296}, {direct = true, crouch = true, radius = 8, vertical_radius = 16})
      P.press(119, {direct = true, hold = true, fight = false})
      ride {index = 120}
      move({536,-2560,-3224}, {direct = true, radius = 8, vertical_radius = 16})
    end},
    {"broken-transport-and-vents", checkpoint = true, function()
      P.press(874) ride {index = 873}
      leave_central_shuttle(-144)
      P.follow()
      local function control_approach()
        local _,_,height = dk3.position()
        if height < -2490 then
          move({704,32,-2552}, {radius = 8, vertical_radius = 16})
          for _, stair in ipairs({{656,32,-2536},{624,32,-2520},
              {592,32,-2504},{560,32,-2488},{528,32,-2472}}) do
            move(stair, {direct = true, fight = false,
              radius = 4, vertical_radius = 8, pace = 0.5})
          end
        end
        -- Regroup on the wide lower bay before climbing the narrow control
        -- ramp. Recalling from halfway up leaves two bodies facing each other.
        move({368,96,-2472}, {radius = 8, vertical_radius = 16})
        hold_lab_party()
        move({640,144,-2464}, {radius = 8, vertical_radius = 16})
        move({880,144,-2408}, {radius = 8, vertical_radius = 16})
      end
      control_approach()
      kill({index = 171}, {weapon = 21, timeout = 90})
      kill({index = 234}, {weapon = 21, timeout = 90})
      control_approach()
      -- The console's west face is solid machinery. Its eastern stairs rise
      -- twelve units per tread; a jump against the west face cannot climb it.
      for _, point in ipairs({{880,120,-2408},{880,96,-2400},{880,64,-2388},{912,32,-2376}}) do
        move(point, {direct = true, fight = false, radius = 4, vertical_radius = 16})
      end
      P.press(122, {areas = true, hold = true})
      wait_until(function()
        local lift=dk3.entity {index = 879}
        return lift and math.abs(lift.x-800)<4 and math.abs(lift.z+2596)<4
      end, {timeout = 30, reason = "damaged transport arrives below the control room"})
      nodepath {576,32,-2472}
      move({624,32,-2472}, {direct = true, fight = false, radius = 8})
      move({800,32,-2592}, {direct = true, fight = false, radius = 12, vertical_radius = 16})
      P.press(880, {direct = true, hold = true, fight = false})
      ride {index = 879}
      -- Step onto the raised rim, then down to the corridor. The corridor
      -- stands forty-eight units below the rim, rather than at its height.
      leap({128,32,-3208}, {80,32,-3168}, {crouch = true, pace = 0.5, radius = 32, vertical_radius = 16})
      move({32,32,-3216}, {direct = true, fight = false, radius = 8, vertical_radius = 16})
      P.breakage(141)
      -- Attach inside the motor's three-unit ladder probe before jumping.
      -- A four-unit arrival can stop just short and miss the ladder entirely.
      move({-928,-14,-3240}, {direct = true, fight = false, radius = 1, vertical_radius = 16})
      point_at({-928,-80,-3136})
      jump {duration = 0.2, pace = 0, fight = false}
      -- The ladder head has no standing floor until the body enters the
      -- northern duct. Hand off during the climb instead of settling on rungs.
      move({-928,-14,-3136}, {direct = true, settle = false, fight = false, radius = 8, vertical_radius = 16})
      move({-928,-512,-3136}, {direct = true, crouch = true, fight = false, radius = 8, vertical_radius = 16})
      P.breakage(142, {direct = true, crouch = true, hold = true, weapon = 21})
      move({-915,-512,-3136}, {direct = true, crouch = true, fight = false, radius = 4, vertical_radius = 16})
      point_at({-880,-512,-3048})
      move({-915,-512,-3048}, {direct = true, fight = false, radius = 8, vertical_radius = 16})
      P.once(143)
    end},
    {"four-monkey-cages", checkpoint = true, supplies = false, function()
      for _, index in ipairs({155,363,366,369}) do P.once(index, {areas = true}) end
      P.follow()
      -- The cage train's centre is hundreds of units below its walkable
      -- deck, so centre height cannot establish that boarding is possible.
      -- Use the guide's pen ladder after opening the cages. A checkpoint
      -- supply detour here can ride the train away before this stage starts.
      do
        for _, point in ipairs({{-1472,-48,-3248},{-1760,-48,-3248},
            {-1920,-48,-3248},{-2008,-48,-3248},{-2008,-88,-3248}}) do
          move(point, {direct = true, crouch = true, fight = false,
            radius = 8, vertical_radius = 32, pace = 0.5})
        end
        point_at({-2032,-88,-3240}, {fight = false})
        dk3.sidekick("mikiko", "come")
        wait_until(function()
          local buddy = dk3.entity {class = "mikiko"}
          local px,py,pz = dk3.position()
          return buddy and math.abs(buddy.z-pz) < 48
            and (buddy.x-px)^2+(buddy.y-py)^2 < 128^2
        end, {timeout = 120, reason = "Mikiko reaches the pen ladder"})
        dk3.sidekick("mikiko", "stay")
        -- The ladder faces west: its usable player centre is x=-2028,
        -- looking east. The old x=-2032 lies beyond the three-unit probe;
        -- its lowest rung also starts above the pen floor.
        move({-2028,-88,-3240}, {direct = true, fight = false,
          radius = 1, vertical_radius = 8, pace = 0.25})
        point_at({-1964,-88,-3100}, {fight = false})
        jump {duration = 0.2, pace = 0, fight = false}
        move({-2028,-88,-2720}, {direct = true, settle = false, fight = false,
          radius = 8, vertical_radius = 8})
        move({-1984,-88,-2720}, {direct = true,
          radius = 8, vertical_radius = 16})
        P.follow()
      end
    end},
    {"escape-laboratories", checkpoint = true, function() P.cross(14, {areas = true}) end},
  }(visit, resumed)
end)

level("e4m5a", function(visit, resumed)
  return stages {
    {"garden-water-route", function()
      for _, index in ipairs({61,1036,36,54,1042}) do
        P.take(index, nil, {weapon = 21})
      end
      -- These close grates need a small-arms shot. The carried Slugger's
      -- explosive round cannot safely discharge against the nearby wall.
      P.stay()
      P.breakage(176, {weapon = 21})
      P.breakage(177, {weapon = 21})
      P.once(57) P.follow()
    end},
    {"four-rock-buttons", checkpoint = true, function()
      nodepath({1984,384,-248}, {weapon = 22})
      move({1984,384,-248}, {direct = true, radius = 8, vertical_radius = 16, weapon = 22})
      -- Answer the elevated courtyard shooters from the rock garden. Chasing
      -- them can carry the player into the museum above its entrance stairs.
      clear {radius = 700, vertical_radius = 96, weapon = 22, hold = true,
        arena = {{1760,256},{2464,768}}, timeout = 180}
      -- Continue from the cleared rock garden. The entrance supplies were
      -- collected before the pond; do not send the party back through it.
      for _, index in ipairs({265,562,563,564}) do
        P.once(index, {areas = true, weapon = 22})
      end
    end},
    {"relic-museum", checkpoint = true, function()
      -- The rock switches are below these guards. Fight them from the broad
      -- upper stair landing before crossing their gallery to the display trap.
      nodepath({994,666,-24}, {weapon = 22})
      for _, index in ipairs({50,86}) do
        kill({index = index}, {weapon = 22,
          arena = {{800,336},{1088,800}}, timeout = 120})
      end
      nodepath({832,416,-24}, {weapon = 22})
      P.stay()
      move({800,416,-24}, {direct = true, fight = false, radius = 8, vertical_radius = 16})
      move({432,416,-24}, {direct = true, fight = false, radius = 8, vertical_radius = 16})
      wait_until(function() return dk3.mover({index = 281}) == "open" and dk3.mover({index = 282}) == "open" end,
        {timeout = 20, reason = "the display trap opens the machinery-room shutters"})
      move({432,592,-24}, {direct = true, radius = 8, vertical_radius = 16, weapon = 21})
      move({192,624,-24}, {direct = true, radius = 8, vertical_radius = 16, weapon = 21})
      P.breakage(286, {direct = true, hold = true, weapon = 21})
      wait_until(function() return dk3.mover({index = 284}) == "open" and dk3.mover({index = 285}) == "open" end,
        {timeout = 20, reason = "the disabled display trap releases both gates"})
      P.once(169, {areas = true, weapon = 21}) P.follow()
    end},
    {"chambers-lift", checkpoint = true, function()
      -- The switch approach can finish against this shootable crate. Clear
      -- it before returning west so the room's floor corridor is accessible.
      P.breakage(212,{direct=true,hold=true,weapon=21})
      -- Rejoin the floor used to enter the machinery room. The switch's
      -- recessed approach has no outgoing connection to the garden route.
      path({{192,416,-24},{192,624,-24},{432,592,-24},
          {432,416,-24},{832,416,-24}},
        {direct=true,weapon=22,radius=8,vertical_radius=16})
      -- Board both riders before starting the one-way descent. A distant
      -- Follow order can leave Mikiko in the museum when the lift goes down.
      move({-864,128,-256}, {fight = false, radius = 8,
        vertical_radius = 16, on_floor = true, timeout=120})
      point_at({-928,128,-256}, {fight = false})
      dk3.sidekick("mikiko","come")
      wait_until(function()
        local buddy=dk3.entity{class="mikiko"}
        if not buddy or buddy.x < -944 or buddy.x > -848 or
            buddy.y < 80 or buddy.y > 176 or math.abs(buddy.z+256)>24 then return false end
        local floor=dk3.trace({buddy.x,buddy.y,buddy.z},
          {buddy.x,buddy.y,buddy.z-4},{class="mikiko"})
        -- The closed chamber doors form the boarding deck above the lift.
        -- The switch retracts them before both riders drop onto platform264.
        return not floor.start_solid and floor.fraction<1 and
          (floor.index==262 or floor.index==263 or floor.index==264)
      end,{timeout=120,fight=false,reason="Mikiko boards the chambers lift"})
      dk3.sidekick("mikiko","stay")
      P.press(721, {areas = true}) ride {index = 264}
      -- The eastern bank begins with a17-unit step. Walk onto it under the
      -- low ceiling instead of treating the first supported tread as a jump.
      move({-864,240,-520}, {direct = true, crouch = true, fight = false,
        pace = 0.5, radius = 8, vertical_radius = 24})
      move({-864,256,-520}, {direct = true, crouch = true, radius = 8, vertical_radius = 16})
      -- Clear the eastern landing without pursuing a monkey behind the
      -- western machinery wall. The party leaves the lift on this bank.
      clear {radius = 160, vertical_radius = 64, hold = true, crouch = true,
        weapon = 21, arena = {{-928,208},{-784,288}}, timeout = 90}
      point_at({-896,336,-520})
      dk3.sidekick("mikiko", "come")
      local supported_since
      wait_until(function()
        local buddy=dk3.entity {class = "mikiko"}
        if not buddy or buddy.y < 208 or math.abs(buddy.z+520)>24 then supported_since=nil return false end
        local floor=dk3.trace({buddy.x,buddy.y,buddy.z}, {buddy.x,buddy.y,buddy.z-4}, {class="mikiko"})
        if floor.start_solid or floor.fraction==1 or floor.normal_z<0.7 or floor.index==264 then supported_since=nil return false end
        supported_since=supported_since or dk3.time()
        return dk3.time()-supported_since>=400
      end, {timeout = 90, reason = "Mikiko leaves the lift onto the lower landing"})
      P.stay()
      move({-848,200,-520}, {direct = true, crouch = true, radius = 2, vertical_radius = 16})
      P.once(208, {areas = true, crouch = true, hold = true})
      -- Keep Mikiko on the cleared landing while the lift and upper switch
      -- cycle. Rejoining inside the moving shaft can trap her under its deck.
    end},
    {"upper-red-button", checkpoint = true, function() P.once(173) end},
    {"reunite-with-superfly", checkpoint = true, function()
      P.follow()
      wait_until(function() return dk3.mover {index=215}=="open" end,
        {timeout=15,reason="the red button opens the return doorway"})
      move({-1088,864,-8},{direct=true,radius=8,vertical_radius=16})
      move({-976,864,-24},{direct=true,radius=8,vertical_radius=24})
      P.take(37, nil, {areas = true})
      for _, index in ipairs({63,1032,1033,1034,53,85}) do P.take(index, nil, {areas = true}) end
      nodepath {-448,400,-24}
      nodepath {-160,-336,-248}
      move({index = 149}, {around = {0,0,0}, direct = true, radius = 8, vertical_radius = 24})
      ride {index = 149}
      move({-160,-176,160}, {direct = true, radius = 8, vertical_radius = 24})
      P.once(458, {areas = true})
      nodepath {-160,552,152}
      point_at({-160,608,336})
      move({-160,560,336}, {direct = true, fight = false,
        radius = 8, vertical_radius = 8})
      leap({-160,552,336}, {-112,544,344},
        {crouch = true, pace = 0.5, fight = false, radius = 8, vertical_radius = 8})
      nodepath {-8,320,344}
      point_at({-8,384,440})
      move({-8,332,344}, {direct = true, radius = 8, vertical_radius = 16})
      move({-8,340,440}, {direct = true, radius = 8, vertical_radius = 16})
      -- The upper walkway runs around the north of the central wall; its
      -- nearest supplied node is behind the ladder on the lower floor.
      move({-64,400,440}, {direct = true, crouch = true, fight = false,
        radius = 4, vertical_radius = 8, pace = 0.5})
      path({{-64,528,440},{-112,528,440}},
        {direct = true, crouch = true, fight = false,
          radius = 4, vertical_radius = 8, pace = 0.5})
      kill({index = 75}, {weapon = 22, hold = true,
        arena = {{-128,512},{-96,544}}, timeout = 90})
      path({{-128,512,440},{-192,512,440},
        {-208,528,440},{-256,528,440},{-320,464,440},
        {-336,448,440},{-336,440,440},{-320,424,440}},
        {direct = true, crouch = true, fight = false,
          radius = 4, vertical_radius = 8, pace = 0.5})
      move({-324,424,440}, {direct = true, radius = 8, vertical_radius = 16})
      point_at({-324,480,568})
      move({-324,432,568}, {direct = true, radius = 8, vertical_radius = 16})
      move({-324,480,568}, {direct = true, radius = 8, vertical_radius = 16})
      nodepath {-8,400,568}
      point_at({-8,336,696})
      move({-8,388,568}, {direct = true, radius = 8, vertical_radius = 16})
      move({-8,380,696}, {direct = true, radius = 8, vertical_radius = 16})
      move({-8,336,696}, {direct = true, radius = 8, vertical_radius = 16})
      P.cross(94)
    end},
  }(visit, resumed)
end)

level("e4m6a", function(visit, resumed)
  -- Re-entry is at the course's lower exit; the submarine route only becomes
  -- available after finishing the training rooms and recalling the party.
  local first = dk3.entity {index = 29}
  local second = dk3.entity {index = 249}
  local course_complete = visit > 1 or z() < -500 or
    (first and (first.uses or 0) > 0) or (second and (second.uses or 0) > 0)
  if not course_complete then
    return stages {
      {"training-center-arrival", function() cinematic() end},
      {"leave-companions-at-course", checkpoint = true, function()
        if z() > 40 then ride {index = 87} end
        nodepath {1744,800,16}
        move({1772,800,16}, {direct = true, settle = false, radius = 2, vertical_radius = 16})
        point_at({1824,800,400})
        move({1780,800,400}, {direct = true, settle = false, radius = 8, vertical_radius = 16})
        move({1772,744,344}, {direct = true, radius = 8, vertical_radius = 16})
        move({1728,744,344}, {direct = true, radius = 8, vertical_radius = 16})
        nodepath({index=95},{standoff=64,weapon=21})
        -- The last authored node is beside the car, outside use reach.
        -- Cross its open west lip and stand on the deck before sending it.
        path({{2770,-80,280},{2824,-80,280},{2896,-80,264}},
          {direct=true,fight=false,radius=8,vertical_radius=16,pace=0.5})
        P.press(95,{direct=true,hold=true}) ride {index = 23} P.cross(50)
      end},
    }(visit, resumed)
  end
  return stages {
    {"support-column-buttons", function() P.once(29) P.once(249) end},
    {"rejoin-companions", checkpoint = true, function()
      P.press(92) ride {index = 93} P.follow()
    end},
    {"submarine-vault", checkpoint = true, function()
      nodepath {1885,-768,216}
      P.press(33,{areas=true})
      -- This slow leaf swings into the east approach. Wait beyond its full
      -- swept reach, then cross the clear doorway while it is held open.
      move({1952,-768,216},{direct=true,fight=false,radius=8,vertical_radius=16})
      wait_until(function() return dk3.mover{index=33}=="open" end,
        {timeout=15,fight=false,reason="the vault door finishes its slow swing"})
      move({1800,-768,216},{direct=true,fight=false,radius=8,vertical_radius=16})
      move({1648,-768,216},{direct=true,fight=false,radius=8,vertical_radius=24})
      P.follow() P.cross(48)
    end},
  }(visit, resumed)
end)

level("e4m6b", function(visit, resumed)
  return stages {
    {"rotating-step-platforms", function()
      nodepath {2240,-80,-448}
      P.press(248, {areas = true})
      move({2080,-80,-424}, {direct = true, fight = false, radius = 8, vertical_radius = 16})
      local previous, previous_second, previous_at
      wait_until(function()
        local angle = dk3.entity({index=78}).pitch % 180
        local second = dk3.entity({index=83}).pitch % 180
        local now = dk3.time()
        local ready = false
        if previous_at and now > previous_at then
          local seconds = (now-previous_at)/1000
          local rate = ((angle-previous+90)%180-90)/seconds
          local second_rate = ((second-previous_second+90)%180-90)/seconds
          local first_landing = (angle+rate*1.35)%180
          local second_landing = (second+second_rate*2.25)%180
          ready = math.abs(rate)>1 and math.abs(second_rate)>1
            and math.min(first_landing,180-first_landing)<10
            and math.min(second_landing,180-second_landing)<30
        end
        previous,previous_second,previous_at = angle,second,now
        return ready
      end, {timeout=30,reason="both rotating decks remain walkable through the continuous jump chain"})
      leap({2016,-80,-424}, {index=78}, {around={40,0,0},pace=1,radius=48,vertical_radius=32,timeout=30})
      leap({1744,-80,z()}, {index=83}, {around={40,0,0},pace=1,radius=48,vertical_radius=32,timeout=30})
      leap({1456,-80,z()}, {1360,-80,-422}, {pace=1,radius=96,vertical_radius=24,timeout=30})
      move({1200,-80,-448}, {direct = true, fight = false})
    end},
    {"rotating-cage", checkpoint = true, function()
      nodepath {880,-80,-424}
      move({880,-80,-424}, {direct = true, fight = false, radius = 8, vertical_radius = 16})
      wait_until(function() return dk3.mover {index = 183} == "open" end,
        {timeout = 15, reason = "the cage entry countdown opens its doors"})
      move({528,-84,-424}, {direct = true, fight = false, radius = 8, vertical_radius = 16})
      wait_until(function()
        local angle=dk3.entity({index=95}).roll % 360
        return angle>=260 and angle<=265
      end, {timeout = 15, reason = "the continuous lower cage rail turns toward a walkable face"})
      -- Continue running on first contact. Waiting to settle here spends
      -- the cage's walkable angular window before the crossing even starts.
      leap({480,-84,-424}, {304,-84,-420},
        {pace=1,radius=32,vertical_radius=24,settle=false})
      for _, along in ipairs({256,192,128,64,0,-64,-128,-192,-256,-320,-352}) do
        move({index=95}, {around={along,52,-313},direct=true,settle=false,fight=false,radius=16,vertical_radius=32})
      end
      local _, py, pz=dk3.position()
      leap({-432,py,pz}, {-560,-48,-424}, {pace=1,radius=64,vertical_radius=32})
      move({-560,-80,-424}, {direct=true,fight=false,radius=8,vertical_radius=16})
      wait_until(function() return dk3.mover {index=203}=="open" end,
        {timeout=15,reason="the completed cage course opens its exit"})
      move({-704,-80,-424}, {direct = true, fight = false, radius=16,vertical_radius=32})
    end},
    {"piston-corridor", checkpoint = true, function()
      nodepath {-1024,-80,-424}
      move({-1024,-80,-424}, {direct=true,fight=false,radius=8,vertical_radius=16})
      wait_until(function() return dk3.mover {index=185}=="open" end,
        {timeout=15,reason="the piston start countdown opens its doors"})
      -- Waiting on an island lets its piston eject the player. Observe the
      -- running machines from the entry bank, then launch a continuous chain
      -- whose occupancy of every island fits its measured retracted phase.
      local phases={
        {index=85,enter=250,leave=1100,grace=150},
        {index=84,enter=1250,leave=2200,grace=100},
        {index=96,enter=2150,leave=3000,grace=150},
        {index=100,enter=3000,leave=3850,grace=100},
        {index=98,enter=3850,leave=4700,grace=150},
      }
      wait_until(function()
        local now=dk3.time()
        local ready=true
        for _, phase in ipairs(phases) do
          local closed=dk3.mover{index=phase.index}=="closed"
          if closed and phase.closed==false then
            if phase.start then phase.period=now-phase.start end
            phase.start=now
          elseif not closed and phase.closed and phase.start then
            phase.hold=now-phase.start
          end
          phase.closed=closed
          ready=ready and phase.period~=nil and phase.hold~=nil
        end
        return ready
      end,{timeout=30,fight=false,reason="observe complete piston retraction cycles from the safe bank"})
      for _,phase in ipairs(phases) do
        dk3.log(string.format("piston %d closed=%d period=%d hold=%d",phase.index,phase.start,phase.period,phase.hold))
      end
      wait_until(function()
        local now=dk3.time()
        for _, phase in ipairs(phases) do
          local elapsed=(now+phase.enter-phase.start+phase.grace)%phase.period
          if elapsed+phase.leave-phase.enter>phase.hold+2*phase.grace then return false end
        end
        return true
      end,{timeout=300,fight=false,reason="all five piston clearances admit one continuous crossing"})
      dk3.log("piston continuous crossing launch "..dk3.time())
      move({-1200,-80,-440},{direct=true,fight=false,radius=8,vertical_radius=24})
      leap({-1232,-80,-440},{-1408,-80,-440},{crouch=true,pace=1,radius=48,vertical_radius=24})
      for _, crossing in ipairs({{-1488,-1664,-440},{-1744,-1920,-440},{-2000,-2176,-440},{-2256,-2432,-424}}) do
        local _,py,pz=dk3.position()
        leap({crossing[1],py,pz},{crossing[2],py,crossing[3]},
          {crouch=true,pace=1,radius=48,vertical_radius=24})
      end
      move({-2464,-80,-424},{direct=true,fight=false,radius=8,vertical_radius=16})
      wait_until(function() return dk3.mover {index=205}=="open" end,
        {timeout=15,reason="the piston completion trigger opens its exit"})
      move({-2592,-80,-424},{direct=true,crouch=true,fight=false,radius=8,vertical_radius=24})
    end},
    {"shark-tank", checkpoint = true, function()
      P.take(16)
      move({-3200,-80,-768},{direct=true,weapon=21,radius=24,vertical_radius=24,timeout=60})
      for _,index in ipairs({216,217,218,36}) do kill({index=index},{weapon=21,timeout=120}) end
      move({-3024,176,-976},{direct=true,weapon=21,radius=16,vertical_radius=24})
      move({-3024,176,-1536},{direct=true,weapon=21,radius=16,vertical_radius=24})
      save("coop-training-drain")
      for _,point in ipairs({{-3056,144,-1536},{-3056,144,-1632},{-3056,-544,-1632},
          {-3200,-544,-1632},{-3200,-1008,-1632},{-3200,-1008,-1152},
          {-3200,-1400,-1152},{-3200,-1400,-992}}) do
        move(point,{direct=true,weapon=21,radius=16,vertical_radius=24})
      end
      move({-3200,-1400,-744},{direct=true,weapon=21,radius=16,vertical_radius=24})
      move({-3120,-1400,-744},{direct=true,weapon=21,radius=8,vertical_radius=24})
      kill({index=32},{weapon=21}) kill({index=33},{weapon=21})
      P.take(211,nil,{areas=true})
      move({-3056,-1392,-744},{direct=true,weapon=21,radius=8,vertical_radius=24})
      wait_until(function() return dk3.mover{index=189}=="open" end,
        {timeout=15,reason="the tank exit countdown opens the moving-platform room"})
      move({-2928,-1392,-744},{direct=true,weapon=21,radius=8,vertical_radius=24})
    end},
    {"moving-training-decks", checkpoint = true, function()
      -- The entry bank is192 units below the tank exit. Take the drop at a
      -- walk: running diagonally from the nearest upper node carries the
      -- body beyond the bank before it reaches the lower floor.
      move({-2880,-1392,-744},{direct=true,fight=false,radius=4,vertical_radius=16})
      move({-2784,-1392,-936},{direct=true,fight=false,pace=0.25,radius=4,vertical_radius=16})
      clear({weapon=21,hold=true,radius=1200,vertical_radius=256,
        arena={{-2824,-1472},{-2768,-1216}}})
      move({-2784,-1392,-936},{direct=true,fight=false,pace=0.35,radius=4,vertical_radius=16})
      move({-2752,-1392,-936},{direct=true,fight=false,pace=0.35,radius=4,vertical_radius=16})
      local previous_y
      wait_until(function()
        local y=dk3.entity{index=68}.y
        local ready=previous_y and y>previous_y and y < -1424
        previous_y=y
        return ready
      end,{timeout=15,fight=false,stance={-2752,-1392,-936},around={0,0,0},
        reason="the first moving deck returns toward the entry bank"})
      leap({-2752,-1392,-936},{-2656,-1392,-936},{fight=false,radius=40,vertical_radius=24})
      for _,pair in ipairs({{68,69},{69,70},{70,71}}) do
        move({index=pair[1]},{around={-32,0,0},direct=true,fight=false,radius=8,vertical_radius=24})
        local previous_a,previous_b,previous_time
        local function future_y(y,velocity,seconds)
          local projected=y+velocity*seconds
          if projected < -1472 then projected=-2944-projected end
          if projected > -704 then projected=-1408-projected end
          return projected
        end
        wait_until(function()
          local a,b=dk3.entity{index=pair[1]}.y,dk3.entity{index=pair[2]}.y
          local now=dk3.time()
          local ready=false
          if previous_time and now>previous_time then
            local av,bv=(a-previous_a)*1000/(now-previous_time),(b-previous_b)*1000/(now-previous_time)
            ready=math.abs(av)>20 and math.abs(bv)>20 and math.abs(future_y(a,av,0.35)-future_y(b,bv,1))<24
          end
          previous_a,previous_b,previous_time=a,b,now
          return ready
        end,{timeout=30,fight=false,reason="adjacent decks align for the next gap"})
        local car=dk3.entity{index=pair[1]}
        leap({car.x+40,car.y,-936},{index=pair[2]},
          {around={-32,0,0},pace=0.6,fight=false,radius=40,vertical_radius=24,timeout=30})
        save("coop-training-deck-"..pair[2])
      end
      nodepath {-1744,-1104,-656}
    end},
    {"lower-platform-course", checkpoint = true, function()
      move({-1792,-768,-632},{direct=true,fight=false,radius=8,vertical_radius=16})
      wait_until(function() return dk3.mover{index=191}=="open" end,
        {timeout=15,reason="the completed moving decks open their exit"})
      move({-1632,-768,-632},{direct=true,fight=false,radius=8,vertical_radius=16})
      move({-1344,-768,-632},{direct=true,fight=false,radius=8,vertical_radius=16})
      wait_until(function() return dk3.mover{index=187}=="open" end,
        {timeout=15,reason="the final course start countdown opens its door"})
      move({-1200,-704,-632},{direct=true,fight=false,radius=8,vertical_radius=16})
      wait_until(function()
        local a,b=dk3.entity{index=91},dk3.entity{index=90}
        local yaw=a.yaw%360
        if yaw<175 or yaw>180 then return false end
        return fan_choice(a,b,{index=91,center={0,0},rate=35},
          {index=90,center={-64,0},rate=30},{104,24},
          {{80,80},{104,24},{24,104}},{{0,0},{-32,32},{-32,-32},{16,48},{16,-48}},nil,1.5)~=nil
      end,{timeout=90,fight=false,reason="the entry and first transfer fans share a safe landing window"})
      -- Land on the western arm first. A jump directly toward the hub's
      -- diagonal quarter meets the separate overhead rotor87.
      leap({-1120,-704,-632},{index=91},{around={104,24,0},pace=1,fight=false,radius=40,vertical_radius=24})
    end},
    {"first-fan-transfer", checkpoint=true, function()
      cross_fan({index=91,center={0,0},rate=35},{index=90,center={-64,0},rate=30},
        {104,24},{{80,80},{104,24},{24,104}},{{0,0},{-32,32},{-32,-32},{16,48},{16,-48}})
    end},
    {"second-fan-transfer", checkpoint=true, function()
      cross_fan({index=90,center={-64,0},rate=30},{index=93,center={64,0},rate=20},
        {40,0},{{-40,0},{-32,48},{-32,-48},{-8,72},{-8,-72},{12,90},{12,-90},{37,100},{37,-100}},
        {{0,0},{32,32},{32,-32},{-16,48},{-16,-48}},{0,-1})
    end},
    {"third-fan-transfer", checkpoint=true, function()
      cross_fan({index=93,center={64,0},rate=20},{index=94,center={0,0},rate=40},
        {32,-32},{{40,0},{32,48},{32,-48},{8,72},{8,-72},{-12,90},{-12,-90},{-37,100},{-37,-100}},
        {{56,56},{80,32},{32,80},{24,24},{-56,-56},{-80,-32},{-32,-80},{-24,-24}},nil,false)
    end},
    {"fan-quarter-handoff", checkpoint=true, function()
      local px,py=dk3.position()
      local fan=dk3.entity{index=94}
      local angle=math.rad(fan.yaw)
      local local_x=(px-fan.x)*math.cos(angle)+(py-fan.y)*math.sin(angle)
      local local_y=-(px-fan.x)*math.sin(angle)+(py-fan.y)*math.cos(angle)
      local sign=local_x+local_y>=0 and 1 or -1
      local sx,sy=fan_point(fan,{0,0},{48*sign,0},40,0)
      leap({sx,sy,z()},{index=94},{around={-80*sign,-32*sign,0},fight=false,radius=40,vertical_radius=24})
      fan=dk3.entity{index=94}
      px,py=dk3.position()
      angle=math.rad(fan.yaw)
      local_x=(px-fan.x)*math.cos(angle)+(py-fan.y)*math.sin(angle)
      local_y=-(px-fan.x)*math.sin(angle)+(py-fan.y)*math.cos(angle)
      expect((local_x+local_y)*sign<0,"the final fan jump must reach its opposite quarter")
    end},
    {"final-fan-exit", checkpoint=true, function()
      wait_until(function()
        local px,py=dk3.position()
        return px>-215 and py>-880 and py<-720
      end,{timeout=6,crouch=true,fight=false,reason="the outer quarter faces the exit bank"})
      local px,py=dk3.position()
      leap({px,py,z()},{-48,-864,-632},{pace=1,fight=false,radius=40,vertical_radius=24})
      move({0,-768,-632},{direct=true,fight=false,radius=8,vertical_radius=16})
      wait_until(function() return dk3.mover{index=194}=="open" end,
        {timeout=15,reason="the final course completion opens its exit"})
      move({160,-768,-616},{direct=true,fight=false,radius=8,vertical_radius=24})
      P.cross(24)
    end},
  }(visit, resumed)
end)

level("e4m6c", function(visit, resumed)
  return stages {
    {"mishima-at-submarine", function()
      local arrival=dk3.entity{index=48}
      if arrival and (arrival.uses or 0)>0 then return end
      nodepath {-728,-1536,208}
      move({-688,-1584,208},{direct=true,radius=8,vertical_radius=16})
      move({-660,-1656,208},{direct=true,settle=false,fight=false,radius=8,vertical_radius=16})
      point_at({-600,-1656,208})
      move({-660,-1656,32},{direct=true,settle=false,fight=false,radius=8,vertical_radius=16})
      touch({index=48},{direct=true,fight=false,timeout=20})
      -- Touch resumes after this synchronous cinematic has already ended.
      -- A second cinematic wait leaves Hiro exposed to Kage's opening swing.
    end},
    {"kage-arena",checkpoint=true,supplies=false,function(_,resumed)
      -- Leave the starting corner along the east bank before crossing the
      -- north bank to its medicine. The generic route to the southern cache
      -- cuts into the bobbing submarine's solid hull during the opening duel.
      local medicine=false
      for _,index in ipairs({71,96}) do
        local item=dk3.entity{index=index}
        if item and item.visible and item.wanted~=false then medicine=true end
      end
      if medicine then
        move({-704,-1160,-24}, {direct = true, weapon = 23, cautious = false,
          radius = 16, vertical_radius = 24})
        P.take(71, nil, {direct = true, weapon = 23, cautious = false})
        P.take(96, nil, {direct = true, weapon = 23, cautious = false})
      end
      -- Save the completed arrival and real medicine collection in this
      -- combat stage. Retrying its older stage1 save replays the balcony
      -- approach from below while Kage is already attacking.
      if not resumed then save "coop-kage-arena" end
      -- Keep the duel on the supported northern bank. The submarine moves
      -- through the middle of the arena; a held shot must not board its hull.
      P.boss("monster_kage", {weapon=23,hold=false,
        arena={{-1728,-1344},{-688,-1088}},timeout = 300})
      cinematic()
    end},
    {"reactor-betrayal", checkpoint = true, supplies = false, function()
      if dk3.cinematic() then cinematic() end
    end},
    {"final-opponent", checkpoint = true, supplies = false, function(_,resumed)
      local initial_health=dk3.health()
      local duel_arena={{-2496,3104},{-2320,3280}}
      local duel_weapon=25
      local px,py=dk3.position()
      local southern=initial_health<90 or px < -2700 or py > 3328
      -- A wounded arrival cannot trade the opening volleys. The southern
      -- medicine is away from the opponent's opening firing lane; collect
      -- it while moving before committing to a stationary beam duel.
      if initial_health < 90 then
        P.take(36, nil, {direct = true, cautious = false, weapon = 23})
        P.take(220, nil, {direct = true, cautious = false, weapon = 23})
        P.take(4, nil, {weapon = 23})
      end
      if southern then
        duel_arena={{-2960,3328},{-2736,3600}}
        duel_weapon=23
      end
      if not resumed or dk3.health()>initial_health then save "coop-reactor-combat" end
      -- The opponent is already attacking after the betrayal. A medicine
      -- tour exposes even a 96HP arrival to several unanswered volleys.
      -- The long reactor lane favors the continuous beam over a shotgun's
      -- scattered pellets while she fires her own ranged volleys.
      P.boss("monster_mikiko", {weapon = duel_weapon, hold = true,
        arena = duel_arena, timeout = 300})
      cinematic()
    end},
  }(visit, resumed)
end)

level("end", function() cinematic() finish() end, {arrival = false})
level("credits", function() cinematic() finish() end, {arrival = false})
