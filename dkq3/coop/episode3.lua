-- SPDX-License-Identifier: GPL-2.0-or-later
-- Authored Norway progression, informed by the official GameSpot guide.
-- Original route intent and local BSP identities; no reference code/text.
-- Implementation is not traversal acceptance: see docs/native-acceptance.md.
include "coop/campaign_steps.lua"
local P = campaign_steps
local function hop_from_here(landing,options)
  local px,py,pz=dk3.position()
  leap({px,py,pz},landing,options)
end
local function rally_carrier(face, defend, vertical_radius, radius, admitted, support_index, aimed_move, alternate_support)
  -- Rallying should still answer an unexpected attacker. Only explicit
  -- false (such as the recoil-sensitive spiral) disables defensive fire.
  -- A weapon number keeps defense on a caller-selected ledge-safe weapon.
  local defense_weapon=type(defend)=="number" and defend or nil
  defend = defend ~= false
  local x,y,z = dk3.position()
  local supported_since
  local next_report = dk3.time() + 5000
  local aim=type(aimed_move)=="table" and aimed_move or face
  if aimed_move==true then
    -- A hull can stand with its centre beyond a ledge's visible edge.
    -- Aim at actual floor on this tread, rather than through that overhang
    -- onto the floor a storey below.
    local dx,dy=face[1]-x,face[2]-y
    local length=math.sqrt(dx*dx+dy*dy)
    local toward=length>1 and {dx/length*48,dy/length*48} or {0,-48}
    local offsets={toward,{0,48},{48,0},{-48,0},{0,-48},
      {32,32},{-32,32},{32,-32},{-32,-32},{0,40},{40,0},{-40,0},{0,-40}}
    -- Narrow rubble landings can support the hull while their visible
    -- floor lies closer than the usual forty-unit order sampling ring.
    for _,radius in ipairs({32,24,16}) do
      for angle=0,11 do
        local heading=angle*math.pi/6
        offsets[#offsets+1]={math.cos(heading)*radius,math.sin(heading)*radius}
      end
    end
    for _, offset in ipairs(offsets) do
      local px,py=x+offset[1],y+offset[2]
      local floor=dk3.trace({px,py,z+4},{px,py,z-48})
      if not floor.start_solid and floor.fraction<1 and floor.normal_z>=0.7
          and math.abs(floor.z+24-z)<=16 then
        local dx,dy,dz=floor.x-x,floor.y-y,floor.z-0.5-(z+22)
        local ray=2000/math.sqrt(dx*dx+dy*dy+dz*dz)
        local seen=dk3.trace({x,y,z+22},{x+dx*ray,y+dy*ray,z+22+dz*ray},"shot")
        if seen.normal_z>=0.7 and math.abs(seen.z-floor.z)<2
            and (seen.x-floor.x)^2+(seen.y-floor.y)^2<8^2 then
          aim={floor.x,floor.y,floor.z-0.5}
          break
        end
      end
    end
    assert(aim~=face,"no floor on the carrier's requested tread")
  end
  point_at(aim, {fight = false})
  dk3.sidekick("superfly", aimed_move and "move" or "come")
  if defend then point_at({2*x-face[1],2*y-face[2],z}, {fight = false}) end
  local arrived=try(wait_until,function()
    local buddy = dk3.entity {class = "mikikofly"}
    if buddy and dk3.time() >= next_report then
      dk3.log(string.format("carrier-rally player %.0f %.0f %.0f companion %.0f %.0f %.0f",
        x,y,z,buddy.x,buddy.y,buddy.z))
      next_report = dk3.time() + 5000
    end
    local close = buddy and math.abs(buddy.z-z) <= (vertical_radius or 24)
      and (buddy.x-x)^2 + (buddy.y-y)^2 < (radius or 96)^2
    if close and admitted then close = admitted(buddy) end
    if buddy and alternate_support then
      local floor=dk3.trace({buddy.x,buddy.y,buddy.z+0.25},
        {buddy.x,buddy.y,buddy.z-4},{class="mikikofly"})
      if not floor.start_solid and floor.fraction<1 and floor.normal_z>=0.7
          and floor.index==alternate_support then close=true end
    end
    if close then
      local floor = dk3.trace({buddy.x,buddy.y,buddy.z}, {buddy.x,buddy.y,buddy.z-4}, {class = "mikikofly"})
      close = floor.fraction < 1 and floor.normal_z >= 0.7 and not floor.start_solid
      if support_index then close = close and floor.index == support_index end
    end
    if not close then supported_since = nil return false end
    supported_since = supported_since or dk3.time()
    return dk3.time() - supported_since >= 400
  end, {timeout = 180, fight = defend == true, weapon = defense_weapon,
    stance = {x,y,z}, around = {0,0,0},
    reason = "carrying companion reaches the cleared ledge"})
  if not arrived then
    save("carrier-rally-failure")
    error("carrying companion failed to reach the cleared ledge")
  end
  P.stay()
end
local function escorted_walk(points, options, defend, before_rally, envelope)
  local x,y,z = dk3.position()
  local previous = {x,y,z}
  P.stay()
  for _, point in ipairs(points) do
    move(point, options)
    if before_rally then before_rally() end
    -- Keep the carrier on the same supported turn before leaving it behind.
    -- Calling toward the previous turn leaves him behind the player's lane.
    -- Match the follower's ordinary settling envelope on a sloping ramp.
    -- Timed gates retain their tighter, separate rally envelope.
    rally_carrier(previous, defend ~= false,
      envelope and envelope.height or 48, envelope and envelope.radius or 128,
      nil, envelope and envelope.support, envelope and envelope.aimed_move)
    previous = point
  end
end
local function carry_through(control, gate, face, crossed, approach, waiting_area, toggle_control, landing, defense_weapon)
  local x,y,z = dk3.position()
  point_at(landing or face, {fight = false})
  dk3.sidekick("superfly", landing and "move" or "come")
  local deadline = dk3.time() + 30000
  while not crossed() and dk3.time() < deadline do
    local state = dk3.mover {index = control}
    if toggle_control and state=="open" and dk3.mover{index=gate}=="closed" then
      if approach then
        move(approach,{direct=true,fight=defense_weapon~=nil,weapon=defense_weapon,radius=8,vertical_radius=16})
      end
      -- These levers stay open after their timed door closes. Close the
      -- lever normally before its next opening can fire that door again.
      P.press(control,{areas=true,hold=approach~=nil,fight=false,weapon=defense_weapon})
      wait_until(function() return dk3.mover{index=control}=="closed" end,
        {timeout=5,fight=defense_weapon~=nil,weapon=defense_weapon,reason="toggle lever resets before reopening its timed door"})
      state="closed"
    end
    if state == "closed" then
      if approach then
        move(approach, {direct = true, fight = defense_weapon~=nil, weapon=defense_weapon, radius = 8, vertical_radius = 16})
      end
      P.press(control, {areas = true, hold = approach ~= nil, fight = false, weapon=defense_weapon})
      move({x,y,z}, {direct = approach ~= nil, fight = defense_weapon~=nil, weapon=defense_weapon, radius = 8, vertical_radius = 24})
      wait_until(function() return dk3.mover({index = gate}) == "open" end,
        {timeout = 10, fight = defense_weapon~=nil, weapon=defense_weapon, stance = {x,y,z}, around = {0,0,0},
          reason = "timed gate opens for the carrying companion"})
      point_at(landing or face, {fight = false})
      dk3.sidekick("superfly", landing and "move" or "come")
    end
    -- An open lever only renews its own hold; it does not fire the gate
    -- again. Let it release before asking for another actual opening.
    try(wait_until, function()
      local phase = dk3.mover {index = control}
      return crossed() or phase == "closed"
    end, {timeout = 5, fight = defense_weapon ~= nil, weapon = defense_weapon,
      stance = {x,y,z}, around = {0,0,0},
      arena = waiting_area})
  end
  expect(crossed(), "carrying companion clears timed gate " .. control)
  P.follow()
end
local function escort_gate(control, opposite, gate, before, after, face, crossed, approach, arrival_face, return_approach, clearance, after_crossing, landing, defense_weapon)
  nodepath(before,{fight=false,vertical_radius=24})
  move(before, {radius = 8, vertical_radius = 24, fight = false})
  rally_carrier(face,true)
  for _, point in ipairs(approach or {}) do
    move(point, {direct = true, fight = false, radius = 4, vertical_radius = 16})
  end
  P.press(control, {areas = true, fight=false})
  wait_until(function() return dk3.mover({index = gate}) == "open" end,
    {timeout = 10, fight=false, reason = "escort gate clears its opening"})
  if clearance then
    clearance()
    -- Combat can outlast a timed opening. Renew the lever before crossing.
    if dk3.mover {index = gate} ~= "open" then
      P.press(control, {areas = true, fight = false})
      wait_until(function() return dk3.mover {index = gate} == "open" end,
        {timeout = 10, fight = false, reason = "renew gate after clearing its far side"})
    end
  end
  local stops = type(after[1]) == "table" and after or {after}
  for _, point in ipairs(stops) do
    move(point, {direct = true, fight=defense_weapon~=nil, weapon=defense_weapon,
      radius = 8, vertical_radius = 24})
  end
  if after_crossing then after_crossing() end
  carry_through(opposite, gate, arrival_face or face, crossed, return_approach, nil, nil, landing, defense_weapon)
end
local stones = {8, 9, 10}
local function cemetery_bolter()
  P.take(35)
  local px, py, pz = dk3.position()
  if px > 0 and px < 256 and py < -1000 and py > -1250 and pz < -380 and pz > -416 then
    for _, point in ipairs({{144,-1012,-392},{208,-976,-392},{272,-976,-392},{320,-976,-360}}) do
      move(point, {direct = true, radius = 8, vertical_radius = 24})
    end
  end
end

level("e3m1a", function(visit, resumed)
  if not P.has(stones) then
    return stages {
      {"village-weapons", function()
        P.take(36) P.follow()
        companion_take({index = 35}, "mikiko")
        companion_take({index = 34}, "superfly")
      end},
      {"dragon-square", checkpoint = true, function() P.cross(119, {areas = true}) end},
    }(visit, resumed)
  end
  return stages {
    {"keystone-workshop", function()
      for _, index in ipairs({42,43}) do P.breakage(index, {areas = true}) end
      -- The static navigation bake still excludes the cart's footprint
      -- after it breaks. Walk its cleared approach to sight the barrel.
      move({-2040,3120,-360}, {direct = true, radius = 8})
      move({-2088,3228,-360}, {direct = true, crouch = true, radius = 8})
      move({-2088,3200,-360}, {direct = true, crouch = true, radius = 2})
      P.breakage(45, {weapon = 15, hold = true, crouch = true})
      move({-2000,3120,-360}, {direct = true, settle = false, fight = false, radius = 8})
      wait(3)
      wait_until(function() local wall = dk3.entity {index = 46} return wall and wall.broken end,
        {timeout = 10, reason = "barrel opens the keystone workshop wall"})
    end},
    {"three-keystone-gate", checkpoint = true, function()
      expect(P.has(stones), "all three village keystones required")
      for _, index in ipairs({69,70,71}) do P.once(index) end
    end},
    {"leave-plague-village", checkpoint = true, function() P.follow() P.cross(60) end},
  }(visit, resumed)
end)

level("e3m1b", function(visit, resumed)
  -- The water-side exit joins the path to the final bridge and workshop.
  -- The town-side exit returns to the opposite bank of the ravine.
  if P.has(stones) then return P.cross(41) end
  return stages {
    {"armory", function() P.take(8) end},
    {"fountain-ice", checkpoint = true, function()
      if not dk3.has_key(9) then
        P.breakage(29)
        P.stay()
        -- Both fountain guards follow to the bank during the long dive.
        -- Clear those pursuits on the street before leaving combat disabled
        -- for the narrow underwater column route.
        for _,index in ipairs({24,443}) do
          -- A guard can remain behind the statue instead of following onto
          -- Hiro's bank. Close along the street when that firing stand has
          -- no sight line; an invisible held duel can never finish.
          local guard=dk3.entity{index=index}
          -- A melted pursuer is nonsolid and withdrawn. Do not hold the
          -- whole dive on its remaining health while it is underground.
          if guard and guard.blocking~=false and (guard.health or 0)>0 then
            try(kill,{index=index},{weapon=16,hold=false,timeout=20,
              arena={{1056,64},{1472,224}}})
          end
        end
        -- The statue's column extends to the bottom. Enter its eastern side;
        -- diving west leaves that solid column between the player and key.
        -- Use the clear eastern street floor before dropping below the
        -- statue's upper column; a diagonal from the guard's bank clips it.
        move({1408,224,-256}, {direct = true, radius = 8, vertical_radius=16, fight = false})
        move({1408,300,-344}, {direct = true, radius = 8, vertical_radius=12, fight = false})
        move({1376,300,-344}, {direct = true, radius = 8, vertical_radius = 12, fight = false})
        move({1376,300,-1120}, {direct = true, radius = 8, vertical_radius = 12, fight = false})
        move({1408,256,-1172}, {direct = true, radius = 8, vertical_radius = 12, fight = false})
        P.take(27, 9, {direct = true, fight = false, timeout = 20})
        -- Clear the submerged cross-brace before rising, then swim onto the
        -- bank. A vertical goal above the surface keeps a swimmer in the pool.
        move({1408,300,-1172}, {direct = true, radius = 8, vertical_radius = 12, fight = false})
        move({1408,300,-304}, {direct = true, radius = 8, vertical_radius = 12, fight = false})
        move({1488,320,-248}, {direct = true, radius = 12, vertical_radius = 16, fight = false})
        nodepath({1408,256,-288}, {fight = false})
        P.follow()
      end
    end},
    {"church-entrance", checkpoint = true, function() P.cross(115) end},
  }(visit, resumed)
end)

level("e3m1c", function(visit, resumed)
  return stages {
    {"musilde", function() P.approach(85) touch {index = 85} cinematic() end},
    {"church-roof-and-organ", checkpoint = true, function()
      P.stay()
      -- The supplied ground graph covers the companions' aisle, not Hiro's
      -- tower/roof detour. First the short rear ladder, then the tower rope.
      nodepath {544,-2464,-328}
      move({600,-2464,-328}, {direct = true, radius = 8, fight = false})
      move({600,-2544,-328}, {direct = true, radius = 8, fight = false})
      -- Climb the south face. The opposite face is under the tower's sloped
      -- floor and its head clearance ends before the ladder does.
      move({551,-2516,-328}, {direct = true, settle = false, radius = 2, fight = false})
      move({551,-2516,-172}, {direct = true, settle = false, radius = 4, vertical_radius = 12, fight = false})
      move({551,-2500,-164}, {direct = true, radius = 4, vertical_radius = 12, fight = false})
      move({576,-2448,-168}, {direct = true, radius = 8, fight = false})
      move({558,-2400,-168}, {direct = true, settle = false, radius = 2, vertical_radius = 12, fight = false})
      -- Leave the rope at its window floor, below the sloping roof above it.
      move({562,-2400,252}, {radius = 8, vertical_radius = 12, fight = false})
      move({480,-2384,136}, {direct = true, radius = 4, vertical_radius = 24, fight = false})
      move({464,-2384,-56}, {direct = true, settle = false, radius = 12, vertical_radius = 32, fight = false})
      move({448,-2352,-40}, {direct = true, crouch = true, radius = 4, vertical_radius = 24, fight = false})
      move({448,-2384,-56}, {direct = true, crouch = true, radius = 8, fight = false})
      move({32,-2384,-56}, {direct = true, crouch = true, radius = 8, fight = false})
      leap({32,-2384,-56}, {32,-2348,-24}, {crouch = true, pace = 1, radius = 24, vertical_radius = 24})
      move({32,-2256,-32}, {direct = true, crouch = true, radius = 12, vertical_radius = 24})
      move({-176,-2256,-40}, {direct = true, radius = 8, fight = false})
      P.take(56, 27, {direct = true}) P.once(113)
    end},
    {"cellar-keystone", checkpoint = true, function()
      wait_until(function() return dk3.mover({index = 216}) == "open" end,
        {timeout = 15, reason = "organ trapdoor finishes opening"})
      for _, index in ipairs({61,427,428}) do P.breakage(index) end
      P.take(83, 10) P.once(388)
    end},
    {"cellar-return-to-companions", checkpoint = true, function()
      wait_until(function() return dk3.mover({index = 182}) == "open" end,
        {timeout = 10, reason = "cellar return ladder rises to the organ"})
      nodepath {-216,-2176,-488}
      -- Ask for a rise while approaching the ladder face. A flat goal is
      -- treated as an obstacle to sidestep before the contact probe attaches.
      move({-196,-2176,-472}, {direct = true, settle = false, fight = false,
        radius = 2, vertical_radius = 24, pace = 0.5})
      move({-196,-2176,-268}, {direct = true, settle = false, fight = false,
        radius = 4, vertical_radius = 12})
      move({-144,-2176,-244}, {direct = true, settle = false, fight = false,
        radius = 8, vertical_radius = 64})
      move({-144,-2176,-296}, {direct = true, fight = false, radius = 8})
      move({544,-2068,-328}, {timeout = 120})
      move({544,-2068,-312}, {direct = true, settle = false, fight = false,
        radius = 2, vertical_radius = 24, pace = 0.5})
      move({544,-2068,-4}, {direct = true, settle = false, fight = false,
        radius = 4, vertical_radius = 12})
      move({496,-2080,20}, {direct = true, settle = false, fight = false,
        radius = 8, vertical_radius = 64})
      move({496,-2080,-32}, {direct = true, fight = false, radius = 8})
      move({496,-2256,-32}, {direct = true, radius = 8})
      move({32,-2256,-32}, {direct = true, radius = 8})
      leap({32,-2280,-32}, {32,-2320,-8}, {crouch = true, pace = 1, vertical_radius = 24})
      move({32,-2384,-56}, {direct = true, crouch = true, radius = 8})
      move({32,-2600,-328}, {direct = true, crouch = true, radius = 12})
      move({1408,-2600,-360}, {direct = true, radius = 12})
      move({1408,-2400,-360}, {direct = true, radius = 12})
    end},
    {"cemetery-gate", checkpoint = true, function()
      P.follow() P.once(153) P.stay()
      move({352,-704,-360}, {direct = true, radius = 12})
      wait_until(function() return dk3.mover({index = 172}) == "open" and dk3.mover({index = 173}) == "open" end,
        {timeout = 10, reason = "cemetery entrance leaves finish opening"})
      -- Keep the party at the broad entrance for the solo cemetery/crypt
      -- search. Releasing Follow here can park a buddy on the first stair
      -- before its later solo descent even begins.
      -- The gravestone and this pair of gates are excluded on Ronin. Higher
      -- skills retain the authored switch; the open easy passage needs no use.
      if dk3.entity {index = 158} then
        P.once(158, {areas = true})
        wait_until(function() return dk3.mover({index = 159}) == "open" and dk3.mover({index = 160}) == "open" end,
          {timeout = 10, reason = "gravestone opens the crypt gate"})
      end
      cemetery_bolter()
      P.break_group({115,383}, {areas = true, weapon = 15})
      recover(0.8, 384)
      P.press(161, {areas = true})
      move({448,-1008,-360}, {direct = true, radius = 12})
      touch {index = 162}
      wait_until(function() return dk3.mover({index = 164}) == "open" end,
        {timeout = 15, reason = "crypt staircase finishes descending"})
    end},
    {"crypt-purifier", checkpoint = true, function()
      -- This descent and the coffin crossings are solo. Following onto the
      -- narrow moving stair lets a companion occupy the next tread ahead.
      P.stay() cemetery_bolter()
      nodepath {-62,-998,-712}
      -- Fight the crowd from the entrance bank before committing to the
      -- single-body turn. Deferring combat until its far end lets a Buboid
      -- block the lane and melee Hiro while he is deliberately not dodging.
      clear {radius = 256, vertical_radius = 96, weapon = 16, hold = true,
        arena = {{-48,-1024},{32,-976}}, timeout = 180}
      -- Settle on the bank after the graph's broad arrival. Combat avoidance
      -- here can jump around a Buboid and carry Hiro sideways into the pit.
      move({-62,-998,-712}, {direct = true, fight = false,
        pace = 0.35, radius = 4, vertical_radius = 16})
      move({-80,-944,-712}, {direct = true, fight = false,
        pace = 0.35, radius = 4, vertical_radius = 16})
      move({-95,-921,-712}, {direct = true, fight = false,
        pace = 0.35, radius = 4, vertical_radius = 16})
      -- The raised coffin bridges this gap. The old western target lay over
      -- the pit and accepted a falling body before its landing was supported.
      point_at({-120,-912,-664}, {fight = false})
      leap({-95,-921,-712}, {-120,-912,-664},
        -- Reach the coffin while the descending hull can step onto its rim.
        -- A slow standing departure reaches its side below that step window.
        {crouch = true, pace = 1, radius = 12, vertical_radius = 16})
      move({-144,-896,-664}, {direct = true, fight = false,
        radius = 4, vertical_radius = 12})
      point_at({-240,-896,-712}, {fight = false})
      leap({-144,-896,-664}, {-240,-896,-712},
        -- The supported west bank admits the full hull at x-232. Preserve
        -- a small arrival margin beyond the eight-unit motor contact skin.
        {pace = 0.6, radius = 16, vertical_radius = 16})
      move({-247,-915,-712}, {direct = true, on_floor = true, fight = false,
        pace = 0.35, radius = 4, vertical_radius = 8})
      move({-304,-888,-712}, {direct = true, radius = 8})
      move({-352,-912,-712}, {direct = true, radius = 8})
      save("coop-crypt-west-coffin")
      leap({-374,-906,-712}, {-432,-896,-664}, {crouch=true,pace = 1, vertical_radius = 32})
      move({-432,-896,-664}, {direct = true, radius = 4})
      move({-456,-912,-664}, {direct = true, radius = 4})
      move({-480,-992,-712}, {direct = true, settle = false, radius = 12})
      move({-512,-1008,-712}, {direct = true, radius = 8})
      P.break_group({114,386,387}, {direct = true, weapon = 15})
      recover(0.8, 192)
      move({-512,-1216,-712}, {direct = true, radius = 8})
      move({-281,-1216,-712}, {direct = true, radius = 8})
      P.take(55, 28) cinematic()
      P.take(82, 8, {weapon = 16})
      clear {radius = 600, weapon = 16, timeout = 120}
    end},
    {"return-to-village", checkpoint = true, function()
      nodepath {-281,-1216,-712}
      move({-512,-1216,-712}, {direct = true, radius = 8})
      move({-512,-1008,-712}, {direct = true, radius = 8})
      leap({-480,-1000,-712}, {-352,-912,-712}, {pace = 1, vertical_radius = 32})
      move({-304,-888,-712}, {direct = true, radius = 8})
      move({-224,-896,-712}, {direct = true, radius = 4})
      leap({-208,-896,-712}, {-144,-896,-664}, {pace = 1, vertical_radius = 24})
      move({-144,-896,-664}, {direct = true, radius = 4})
      leap({-128,-896,-664}, {-80,-944,-712}, {vertical_radius = 32})
      move({-80,-944,-712}, {direct = true, radius = 8})
      P.follow()
      move({448,-1008,-360}, {weapon = 16})
      P.cross(132)
    end},
  }(visit, resumed)
end)

level("e3m2a", function(visit, resumed)
  return stages {
    {"passage-supplies", function() P.take(12) P.take(15) end},
    {"waterwheel-and-caverns", checkpoint = true, function()
      if not dk3.has_key(26) then
        -- The fragment is across most of the Passage. Bring the party along
        -- the broad approach before parking them for its narrow ledge.
        P.follow()
        P.approach(42,{weapon=16,segment_options=function(point)
          if math.abs(point[1]+1504)<2 and math.abs(point[2]-2493)<2
              and math.abs(point[3]+456)<2 then
            -- Round the rock on the supported lower bank. A straight
            -- descent from the upper node presses into its northern face.
            for _,bank in ipairs({{-1496,2448,-456},{-1520,2472,-456},{-1504,2496,-456}}) do
              move(bank,{direct=true,fight=false,weapon=16,pace=0.5,
                on_floor=true,radius=4,vertical_radius=16})
            end
          end
        end})
        local bank_x,bank_y,bank_z=dk3.position()
        wait_until(function()
          for _,class in ipairs({"mikiko","superfly"}) do
            local buddy=dk3.entity{class=class}
            if not buddy or (buddy.x-bank_x)^2+(buddy.y-bank_y)^2>=192^2
                or math.abs(buddy.z-bank_z)>96 then return false end
          end
          return true
        end,{timeout=120,weapon=16,stance={bank_x,bank_y,bank_z},around={0,0,0},
          reason="both companions reach the Passage fragment bank"})
        P.stay()
        -- Follow the bank's turns and settle on the narrow fragment ledge.
        -- A pickup can complete in mid-air; carrying that run into a reverse
        -- nodepath step throws the player off the far side.
        for _, point in ipairs({{-1848,3400,-456},{-1872,3312,-456},{-1944,3368,-424},
            {-1984,3440,-424},{-2048,3472,-408}}) do
          move(point, {direct = true, pace = 0.45, radius = 8, vertical_radius = 24})
        end
        P.take(42, 26, {direct = true})
      end
    end},
    {"dungeon-entrance", checkpoint = true, function()
      P.follow()
      nodepath {-2368,3456,-440}
      move({-2400,3408,-436},{direct=true,fight=false,radius=8,vertical_radius=24})
      leap({-2432,3392,-436},{-2472,3432,-408},{crouch=true,pace=0.5,radius=40,vertical_radius=24})
      -- Gather on the wider bank before settling under the exit lip. The
      -- low ceiling there can leave a standing follower just outside the
      -- same ninety-unit gathering radius.
      move({-2432,3432,-436},{direct=true,crouch=true,fight=false,radius=4,vertical_radius=12})
      point_at({-2504,3456,-400},{fight=false})
      -- Gather the party before entering this one-way raised lip. An exit
      -- retry steps back below it when a follower arrives after Hiro.
      -- Come can finish near the edge of its clear-spot disk, then resume
      -- Follow outside this tighter gather. Aim Move at actual bank floor
      -- and hold each admitted companion before calling the next.
      for _,class in ipairs({"mikiko","superfly"}) do
        local x,y,z=dk3.position()
        local buddy=dk3.entity{class=class}
        if not buddy or (buddy.x-x)^2+(buddy.y-y)^2+(buddy.z-z)^2>=90^2 then
          local ordered=false
          local first=class=="mikiko" and {-2400,3440,-464} or {-2400,3480,-464}
          for _,floor in ipairs({first,{-2416,3472,-464},{-2392,3472,-464},
              {-2392,3440,-464},{-2416,3440,-464}}) do
            point_at(floor,{fight=false})
            local px,py,pz=dk3.position()
            local ray=dk3.trace({px,py,pz+22},floor,"shot")
            if ray.fraction<1 and ray.normal_z>=0.7 and math.abs(ray.z-floor[3])<2
                and (ray.x-floor[1])^2+(ray.y-floor[2])^2<8^2 then
              dk3.sidekick(class,"move")
              ordered=true
              break
            end
          end
          expect(ordered,"a clear floor order for "..class.." on the Passage bank")
        end
        wait_until(function()
          local x,y,z=dk3.position()
          local buddy=dk3.entity{class=class}
          return buddy and (buddy.x-x)^2+(buddy.y-y)^2+(buddy.z-z)^2<90^2
        end,{timeout=90,crouch=true,fight=false,reason=class.." gathers before the Passage exit lip"})
        dk3.sidekick(class,"stay")
      end
      P.stay()
      move({-2464,3424,-428},{direct=true,crouch=true,fight=false,radius=4,vertical_radius=12,allowed_exit={index=56}})
      -- The gather can outlast the view's idle sweep. Align again before
      -- this short jump under the rock's low ceiling.
      point_at({-2504,3456,-400},{fight=false})
      leap({-2464,3424,-428},{-2504,3456,-400},
        {crouch=true,pace=0.4,radius=12,vertical_radius=12,allowed_exit={index=56}})
      P.cross(56,{areas=true,direct=true,crouch=true})
    end},
  }(visit, resumed)
end)

level("e3m3a", function(visit, resumed)
  return stages {
    {"carrying-mikiko", function() cinematic() P.follow() end},
    {"cave-chasms", checkpoint = true, function()
      P.stay()
      nodepath {-971,713,-1224}
      leap({-960,720,-1224}, {-775,785,-1208}, {pace = 1, radius = 80, vertical_radius = 32})
      move({-775,785,-1208}, {direct = true, radius = 12})
      nodepath {-441,1506,-1220}
      leap({-440,1506,-1224}, {-278,1517,-1164}, {pace = 1, radius = 80, vertical_radius = 32})
    end},
    {"cracked-walls-and-ballista", checkpoint = true, function()
      move({-192,1520,-1160}, {direct = true, radius = 8, weapon = 16})
      move({-32,1520,-1208}, {direct = true, radius = 8, weapon = 16})
      move({176,1424,-1224}, {direct = true, radius = 8, weapon = 16})
      P.follow()
      -- Keep the placed bolts before leaving this lower floor. The next
      -- dungeon maps supply explosive ammunition, so these rounds matter
      -- when a close attacker makes those weapons unsafe.
      P.take(52, nil, {areas = true, weapon = 15})
      P.take(240, nil, {areas = true, weapon = 15})
      -- This lower-room guard follows into the narrow stair while precise
      -- stepping suppresses combat. Resolve the pursuit on the open floor.
      kill({index=65},{weapon=16,hold=true,timeout=90})
      -- The ammo pocket is below the upper landing. Return south to the
      -- stair's foot instead of climbing its north-facing wall toward the
      -- nearest supplied node above the pocket.
      move({544,1288,-1176}, {direct = true, fight = false,
        radius = 8, vertical_radius = 16, pace = 0.5})
      path({{528,1280,-1176},{528,1248,-1180},{512,1216,-1184},
          {512,1184,-1184},{512,1152,-1184},{496,1136,-1192},
          {512,1120,-1192},{528,1104,-1192},{544,1088,-1176},
          {544,1120,-1168},{544,1136,-1168},{560,1152,-1160},
          {576,1168,-1144},{576,1200,-1136},{576,1232,-1128}},
        {direct = true, fight = false, weapon = 16,
          radius = 4, vertical_radius = 16, pace = 0.5})
      -- The turning lip rises beyond one motor step. A slow diagonal walk
      -- stalls against it; make the short transfer onto its upper tread.
      leap({576,1232,-1128},{608,1264,-1104},
        {fight=false,pace=0.4,radius=8,vertical_radius=12})
      path({{608,1280,-1096},{608,1296,-1080},{608,1328,-1080}},
        {direct=true,fight=false,weapon=16,radius=4,vertical_radius=16,pace=0.5})
      move({620,1340,-1080}, {radius = 8, vertical_radius = 16})
      rally_carrier {620,1404,-1080}
      move({440,1080,-952}, {timeout = 120})
      rally_carrier {376,1080,-952}
      move({240,820,-920}, {radius = 16, vertical_radius = 32, timeout = 120})
      rally_carrier {208,784,-920}
      move({208,784,-920}, {radius = 12, vertical_radius = 32})
      move({238,736,-936}, {radius = 8, vertical_radius = 24})
      move({240,696,-920}, {direct = true, radius = 8})
      P.once(24)
      wait_until(function() return dk3.mover({index = 173}) == "open" end,
        {timeout = 10, reason = "upper dungeon room door opens"})
      move({320,680,-920}, {direct = true, radius = 8})
      move({560,728,-920}, {direct=true,crouch=true,radius = 16, vertical_radius = 48, timeout = 120})
      move({592,736,-952}, {direct = true, radius = 8, vertical_radius = 24})
      -- Follow the upper ledge. The lower cracked room (32) is the optional
      -- ring secret and its named door opens only from the far side.
      P.break_group({77,78,79,80,81,82}, {direct = true, hold = true, weapon = 15})
      for _, index in ipairs({25,26,27,28}) do P.breakage(index) end
      P.take(43)
    end},
    {"dungeon-levers", checkpoint = true, function()
      -- The cell lever is on the hallway side. Return through the opened
      -- cracks instead of routing into that locked cell gate from within.
      move({584,457,-960}, {radius = 12, vertical_radius = 24, timeout = 120})
      for _, point in ipairs({{680,459,-960},{680,728,-960},{560,728,-952}}) do
        move(point, {direct = true, crouch = true, radius = 8, vertical_radius = 24})
      end
      -- The low return has a raised lip which neither ordinary steps nor
      -- standing area routing can cross. Reach its measured foot crouched,
      -- jump onto the upper rock, then follow its supported floor west.
      local function return_floor(goal)
        local route=walkflood({goal},{288,624,624,800},8,{crouch=true})[1]
        assert(route,"supported cracked-room return floor")
        for _,point in ipairs(route) do
          move(point,{direct=true,crouch=true,fight=false,pace=0.4,
            radius=4,vertical_radius=8})
        end
      end
      return_floor({528,640,-944})
      leap({528,640,z()},{528,672,-904},{crouch=true,pace=0.35,
        radius=12,vertical_radius=12})
      return_floor({320,680,-920})
      move({240,680,-920}, {direct = true, radius = 8})
      -- Rubble on the pillar leaves only its western edge clear. Align the
      -- run before takeoff; lateral momentum cannot be spent in that gap.
      move({226,752,-936}, {direct = true, pace = 0.2, radius = 0.25})
      move({226,736,-936}, {direct = true, pace = 0.2, radius = 0.25})
      rally_carrier({240,820,-920},false)
      move({226,688,-936},{direct=true,fight=false,pace=0.4,radius=4,vertical_radius=16})
      -- Stage him east of the takeoff, leaving the player's return run-up
      -- free. A Come spot behind Hiro would be yielded while Hiro backs up.
      rally_carrier({320,688,-936},false)
      -- Staging stops the player. Restore the original supported run-up
      -- before the full-speed jump rather than launching from rest at its lip.
      move({226,736,-936},{direct=true,fight=false,pace=0.2,radius=0.25})
      leap({226,688,-936}, {226,512,-912}, {crouch = true, pace = 1, vertical_radius = 24})
      -- Give the carrier the same western run-up, then leave the small
      -- intermediate pillar clear while he makes his first qualified jump.
      point_at({208,688,-960},{fight=false})
      dk3.sidekick("superfly","move")
      local runup_since
      wait_until(function()
        local buddy=dk3.entity{class="mikikofly"}
        if not buddy or buddy.x<192 or buddy.x>232 or math.abs(buddy.y-688)>=24
            or math.abs(buddy.z+936)>=4 then runup_since=nil return false end
        local floor=dk3.trace({buddy.x,buddy.y,buddy.z+0.25},
          {buddy.x,buddy.y,buddy.z-2},{class="mikikofly"})
        if floor.start_solid or floor.fraction==1 or floor.normal_z<0.7 then
          runup_since=nil return false
        end
        runup_since=runup_since or dk3.time()
        return dk3.time()-runup_since>=400
      end,{timeout=60,fight=false,reason="carrier stages on the western run-up"})
      P.stay()
      point_at({242,496,-936},{fight=false})
      dk3.sidekick("superfly","move")
      leap({226,481,-912}, {208,352,-944}, {pace = 0.65, radius = 16, vertical_radius = 24})
      -- Clear the sloping landing before the carrier jumps onto it. Waiting
      -- at its lip lets his ordinary body contact push Hiro into the shaft.
      move({208,192,-936}, {direct = true, fight = false, radius = 8})
      kill({index=61},{weapon=16,hold=true,timeout=60,
        arena={{176,160},{240,224}}})
      local pillar_since
      wait_until(function()
        local buddy=dk3.entity{class="mikikofly"}
        if not buddy or (buddy.x-242)^2+(buddy.y-496)^2>=32^2
            or math.abs(buddy.z+912)>8 then pillar_since=nil return false end
        local floor=dk3.trace({buddy.x,buddy.y,buddy.z+0.25},
          {buddy.x,buddy.y,buddy.z-2},{class="mikikofly"})
        if floor.start_solid or floor.fraction==1 or floor.normal_z<0.7 then
          pillar_since=nil return false
        end
        pillar_since=pillar_since or dk3.time()
        return dk3.time()-pillar_since>=400
      end,{timeout=180,fight=true,weapon=16,stance={208,192,-936},around={0,0,0},
        reason="carrier reaches the empty first pillar"})
      -- Come can select the thin western edge beside this landing. Point
      -- Move at the broad floor inside the bank so its final jump continues
      -- onto the room instead of braking above the outside cliff.
      point_at({208,256,-960},{fight=false})
      dk3.sidekick("superfly","move")
      local bank_since
      local bank_report=dk3.time()+5000
      local bank_arrived=try(wait_until,function()
        local buddy=dk3.entity{class="mikikofly"}
        if buddy and dk3.time()>=bank_report then
          dk3.log(string.format("carrier-bank companion %.0f %.0f %.0f",buddy.x,buddy.y,buddy.z))
          bank_report=dk3.time()+5000
        end
        if not buddy or math.abs(buddy.x-208)>96 or buddy.y>=288
            or math.abs(buddy.z+936)>16 then bank_since=nil return false end
        local floor=dk3.trace({buddy.x,buddy.y,buddy.z+0.25},
          {buddy.x,buddy.y,buddy.z-2},{class="mikikofly"})
        if floor.start_solid or floor.fraction==1 or floor.normal_z<0.7 then
          bank_since=nil return false
        end
        bank_since=bank_since or dk3.time()
        return dk3.time()-bank_since>=400
      end,{timeout=180,fight=true,weapon=16,stance={208,192,-936},around={0,0,0},
        reason="carrier lands inside the dungeon bank"})
      if not bank_arrived then
        save("carrier-bank-failure")
        error("carrier failed to reach supported dungeon bank")
      end
      P.stay()
    end},
    {"escort-to-dungeon-gate", checkpoint = true, function()
      -- Opening the right-hand cell door swings its leaf across the jump's
      -- landing. Bring the carrying companion through before operating it.
      P.follow()
      local gate_bank={208,192,-936}
      move(gate_bank,{direct=true,fight=false,radius=8,vertical_radius=24})
      point_at({208,128,-936})
      dk3.sidekick("superfly","come")
      local arrived_at
      wait_until(function()
        local buddy = dk3.entity {class = "mikikofly"}
        local x,y,z = table.unpack(gate_bank)
        if buddy and buddy.y<248 and (buddy.x-x)^2 + (buddy.y-y)^2 + (buddy.z-z)^2 < 96^2 and math.abs(buddy.z-z) < 24 then
          local floor = dk3.trace({buddy.x,buddy.y,buddy.z+0.25}, {buddy.x,buddy.y,buddy.z-2}, {class = "mikikofly"})
          if floor.fraction < 1 and not floor.start_solid and floor.normal_z >= 0.7 then
            arrived_at = arrived_at or dk3.time()
            return dk3.time() - arrived_at >= 600
          end
        end
        arrived_at = nil
        return false
      end, {timeout = 180, fight=true,weapon=16,stance=gate_bank,around={0,0,0},reason = "carrying Superfly settles beside the dungeon gate"})
      P.stay()
      P.once(299, {areas = true,fight=false})
      wait_until(function()
        return dk3.mover({index = 110}) == "open" and dk3.mover({index = 172}) == "open"
      end, {timeout = 15, reason = "cell doors finish opening"})
      move(gate_bank,{direct=true,fight=false,radius=8,vertical_radius=24})
      P.follow()
    end},
    {"dungeon-gates", checkpoint = true, function()
      P.press(210, {areas = true,fight=false})
      wait_until(function() return dk3.mover({index = 85}) == "open" end,
        {timeout = 10, reason = "main dungeon gate clears its opening"})
      move({48,184,-936}, {direct = true, radius = 8})
      move({-144,184,-936}, {direct = true, radius = 4})
      kill({index=276},{weapon=15,timeout=120})
      move({-144,184,-936},{direct=true,fight=false,radius=4,vertical_radius=24})
      carry_through(211, 85, {48,184,-936}, function()
        local buddy = dk3.entity {class = "mikikofly"}
        return buddy and buddy.x < -32 and math.abs(buddy.z + 936) < 24
      end)
      move({-104,56,-936}, {radius = 12, vertical_radius = 24})
      P.press(213, {areas = true})
      wait_until(function() return dk3.mover({index = 86}) == "open" end,
        {timeout = 10, reason = "outer dungeon gate clears its opening"})
      move({-216,16,-936}, {direct = true, radius = 8})
      move({-216,-208,-936}, {direct = true, radius = 4})
      carry_through(247, 86, {-216,16,-936}, function()
        local buddy = dk3.entity {class = "mikikofly"}
        return buddy and buddy.y < -80 and math.abs(buddy.z + 936) < 24
      end)
      move({-216,-112,-936}, {direct = true, radius = 8})
    end},
    {"outer-dungeon-gate", checkpoint = true, function() P.cross(232) end},
  }(visit, resumed)
end)

level("e3m3b", function(visit, resumed)
  return stages {
    {"prison-cells", function()
      -- The arrival side has its own lever. The opposite lever cannot be
      -- reached through the closed gate from the entry corridor.
      P.press(503, {areas = true})
      wait_until(function() return dk3.mover({index = 117}) == "open" end,
        {timeout = 10, reason = "prison entrance gate clears its opening"})
      move({-216,-224,-936}, {direct = true, radius = 8})
      carry_through(452, 117, {-216,0,-936}, function()
        local buddy = dk3.entity {class = "mikikofly"}
        return buddy and buddy.y < -112 and math.abs(buddy.z + 936) < 24
      end)
    end},
    {"purifier-cell", checkpoint = true, function()
      -- Open the permanent shortcut before asking the supply planner for
      -- health or ammunition beyond it; a pickup route can choose its sealed
      -- back face even for the nearby medicine.
      P.once(278, {areas = true})
      if dk3.health() < 90 then P.take(109, nil, {areas = true, weapon = 16}) end
      P.take(110, nil, {areas = true, weapon = 16})
      P.take(506, nil, {areas = true, weapon = 16})
      -- Qualify the actual stair treads from this arrival, rather than
      -- joining a supplied node on the next revolution of the same column.
      -- Follow the measured ascent while rebuilding the transient trail
      -- after a restore; parking on a narrow upper tread blocks Hiro's turn.
      P.follow()
      local function stair_route()
        local route=walkflood({{-208,-304,-680}}, {-448,-736,-64,-192},16,{crouch=true})[1]
        assert(route,"no supported stair corridor to the upper cells")
        return route
      end
      local stairs=stair_route()
      local step=1
      while step<=#stairs do
        local point=stairs[step]
        step=step+1
        move(point,{direct=true,cautious=false,crouch=point.mark=="c",
          radius=4,vertical_radius=20,pace=0.4,weapon=16})
        local pursuer=dk3.entity{index=147}
        if pursuer and (pursuer.health or 0)>0 and dk3.visible{index=147} then
          local x,y,z=dk3.position()
          if (pursuer.x-x)^2+(pursuer.y-y)^2+(pursuer.z-z)^2<192^2 then
            P.stay()
            kill({index=147},{weapon=16,hold=true,timeout=60})
            -- Combat can climb onto the next revolution. Resume from the
            -- actual floor rather than returning across the central void
            -- to a now-obsolete lower tread.
            stairs=stair_route()
            -- The finishing melee can still be airborne. Reach the next
            -- measured tread before sampling an aimed companion order.
            if stairs[2] then
              move(stairs[2],{direct=true,fight=false,crouch=stairs[2].mark=="c",
                radius=4,vertical_radius=8,pace=0.4})
              stairs=stair_route()
            end
            step=1
            P.follow()
          end
        end
      end
      local worm=dk3.entity{index=146}
      if worm and (worm.health or 0)>0 and math.abs(worm.z+680)<96 then
        kill({index=146},{weapon=16,hold=true,arena={{-288,-400},{-176,-288}},timeout=60})
      end
      rally_carrier({-208,-432,-680},true,48,128,nil,nil,true)
      -- Keep the stair route instead of pursuing the Lycanthir across its
      -- central shaft. The upper lever opens the next corridor.
      escort_gate(728, 729, 727, {-216,-160,-680}, {-216,0,-680}, {-216,-400,-680}, function()
        local buddy = dk3.entity {class = "mikikofly"}
        return buddy and buddy.y > -32 and math.abs(buddy.z + 680) < 24
      end, {{-216,-128,-680},{-264,-128,-680}}, {-400,0,-680})
      for _,index in ipairs({80,508}) do
        kill({index=index},{weapon=16,hold=dk3.visible{index=index},timeout=90})
      end
      -- The cells' tunnel opens the permanent main route. The western
      -- save-gem room is a separate lava-platform detour.
      P.once(45, {areas = true})
      if dk3.health() < 75 then P.take(63, nil, {areas = true, weapon = 16}) end
      if dk3.health() < 90 then P.take(64, nil, {areas = true, weapon = 16}) end
      escort_gate(751, 752, 742, {-912,456,-680}, {-1136,456,-680}, {-720,456,-680}, function()
        local buddy = dk3.entity {class = "mikikofly"}
        return buddy and buddy.x < -1104 and math.abs(buddy.z + 680) < 24
      end, nil, {-1300,456,-680}, nil, function()
        -- Fight the guards in this opened corridor, without following a
        -- roaming enemy back through the rest of the prison.
        clear({weapon=15,radius=256,vertical_radius=48,timeout=90})
      end, function()
        -- A burrower can surface after crossing, or chase the carrier back
        -- into the prison. Clear this room without requiring that remote
        -- body to return to a held melee stand behind the timed door.
        clear({weapon=15,radius=256,vertical_radius=48,
          arena={{-1300,328},{-1056,584}},timeout=90})
      end, {-1136,488,-704}, 15)
      P.stay()
      -- Clear the open corridor before committing to the barred cell.
      -- The worm's poison otherwise keeps draining health during the duel.
      kill({index = 140}, {weapon = 16, timeout = 60})
    end},
    {"barred-purifier-shard", checkpoint = true, function()
      -- Refill before opening the Purifier cell. A Lycanthir can absorb
      -- the barred firing lane and require a melee finish at one health;
      -- keeping the bars shut then prevents the necessary contact.
      local function refill_corridor()
        local available=false
        for _,index in ipairs({63,64,71,72}) do
          local medicine=dk3.entity{index=index}
          if medicine and medicine.visible and medicine.wanted~=false then available=true end
        end
        if available and dk3.health()<90 then
          move({-1240,384,-680},{direct=true,weapon=16,radius=8,timeout=120})
          for _,index in ipairs({63,64,71,72}) do
            if dk3.health()<90 then P.take(index,nil,{areas=true,weapon=16,timeout=120}) end
          end
          move({-1200,384,-680},{weapon=16,radius=8,timeout=120})
        end
      end
      refill_corridor()
      -- Bring the carrier from the preceding gate while still outside
      -- the cell's axe lane, before releasing its close-quarters crowd.
      move({-1240,384,-680},{weapon=16,radius=8,vertical_radius=16})
      rally_carrier({-1240,256,-680},16,48,96)
      P.follow()
      move({-1200,-752,-680}, {radius = 8, vertical_radius = 24, weapon = 16})
      P.once(664, {areas = true, weapon = 16})
      clear {radius = 480, vertical_radius = 48, weapon = 16,
        arena = {{-1278,-848},{-784,-560}}, timeout = 120}
      kill({index = 105}, {weapon = 16, timeout = 60})
      kill({index = 104}, {weapon = 16, timeout = 60})
      refill_corridor()
      P.take(35, 29, {areas = true}) P.once(102, {areas = true})
      wait_until(function() return dk3.mover({index = 100}) == "open" end,
        {timeout = 15, reason = "Purifier wheel opens the hall gate"})
      P.follow()
    end},
    {"blade-staircase", checkpoint = true, supplies = false, function()
      move({-1200,-600,-680}, {radius = 8, vertical_radius = 16, weapon=16})
      -- The wheel releases this thrower into the retreat corridor. Clear
      -- him before turning toward the close ambush or its medicine controls.
      kill({index = 98}, {weapon = 16, timeout = 60})
      kill({index = 534}, {weapon = 16, timeout = 90})
      -- The cell fight can leave Hiro badly hurt. The earlier corridor's
      -- unused medicine is safer than climbing toward the next ambush for it.
      local corridor_medicine=dk3.entity{index=63}
      if dk3.health() < 80 and corridor_medicine and corridor_medicine.visible
          and corridor_medicine.wanted~=false then
        P.stay()
        P.press(752, {areas = true, weapon = 16})
        P.take(63, nil, {areas = true, weapon = 16})
        P.press(751, {areas = true, weapon = 16})
      end
      move({-1200,-600,-680}, {radius = 8, vertical_radius = 16, fight = false})
      if dk3.health() < 60 then
        P.take(60, nil, {areas = true, weapon = 16})
        P.take(61, nil, {areas = true, weapon = 16})
      end
      kill({index = 136}, {weapon = 15, timeout = 60})
      kill({index = 134}, {weapon = 16, timeout = 60})
      kill({index = 137}, {weapon = 16, timeout = 60})
      escort_gate(755, 756, 754, {-800,-632,-424}, {-576,-632,-424}, {-1000,-632,-424}, function()
        local buddy = dk3.entity {class = "mikikofly"}
        return buddy and buddy.x > -592 and buddy.y < -672
          and math.abs(buddy.z + 424) < 24
      end, {{-740,-560,-424}}, {-400,-632,-424}, nil, nil, function()
        -- Clear the worm and rats released by this gate before waiting on
        -- its far side for the carrier. A control action holds its focus.
        clear {weapon = 16, radius = 320, vertical_radius = 96, hold = true,
          arena = {{-640,-736},{-512,-480}}, timeout = 90}
      end, {-552,-704,-448})
      P.stay()
      move({-608,-736,-424}, {direct = true, fight = false,
        radius = 4, vertical_radius = 16})
      -- The Lycanthir can already have climbed out of this room. Clear the
      -- enemies actually occupying the landing instead of locking a melee
      -- attack onto him through an upper floor while another guard attacks.
      clear {weapon = 16, radius = 240, vertical_radius = 96, hold = true,
        arena = {{-640,-784},{-560,-704}}, timeout = 90}
      local function clear_upper_shooter()
        local guard = dk3.entity {index = 129}
        if not guard or not guard.health or guard.health <= 0 then return end
        local px,py,pz = dk3.position()
        local sight = dk3.trace({px,py,pz+22}, {guard.x,guard.y,guard.z+24}, "shot")
        if sight.fraction < 1 and sight.index ~= 129 then return end
        -- Stop at the first supported turn with a real firing lane, before
        -- looking away to call the carrier under this guard's grenades.
        kill({index = 129}, {weapon = 16, hold = true,
          arena = {{px-24,py-24},{px+24,py+24}}, timeout = 90})
      end
      -- Clear the upper shooter before the carrier's slow turn at the bend.
      -- He already fires down here; the rally's look actions cannot return
      -- fire while waiting for the companion to settle.
      move({-600,-816,-400}, {direct = true, weapon = 16,
        radius = 8, vertical_radius = 16, pace = 0.5})
      clear_upper_shooter()
      -- That shooter can retreat onto a distant upper floor. Clear threats
      -- occupying this bend without making a roaming guard a progression key.
      clear {weapon = 16, radius = 400, vertical_radius = 256, hold = true,
        arena = {{-632,-840},{-576,-792}}, timeout = 120}
      move({-608,-736,-424}, {direct = true, fight = false,
        radius = 4, vertical_radius = 16, pace = 0.5})
      -- Follow the walkway's southern turns. A direct chord through the
      -- central room drops back into the caves far below.
      escorted_walk({{-624,-784,-416}},
        {direct = true, fight = false, radius = 8, vertical_radius = 16, pace = 0.5},
        nil, clear_upper_shooter)
      move({-600,-816,-400}, {direct = true, fight = false,
        radius = 8, vertical_radius = 16, pace = 0.5})
      clear_upper_shooter()
      rally_carrier({-624,-784,-416}, true, 48, 128)
      escorted_walk({{-552,-864,-384},{-488,-920,-360},{-456,-920,-352},{-8,-920,-232},
          {32,-936,-224}},
        {direct = true, fight = false, radius = 8, vertical_radius = 16, pace = 0.5},
        nil, clear_upper_shooter)
      move({168,-840,-168}, {direct = true, fight = true, weapon = 15,
        radius = 24, vertical_radius = 24, pace = 0.5})
      -- Reach the upper platform before the melee duel. Closing directly
      -- toward a guard above the ramp cuts across its neighbouring shaft.
      -- A wounded Lycanthir can retreat or fall into the lower caves. Fight
      -- the occupants of this floor; following him down the neighbouring
      -- shaft cannot advance the required staircase route.
      clear {radius = 400, vertical_radius = 96, weapon = 16, hold = true,
        arena = {{128,-888},{336,-768}}, timeout = 90}
      rally_carrier({32,-936,-224}, true, 48, 128)
      P.approach(93, {areas = true}) P.take(93, nil, {areas = true})
    end},
    {"moving-blade-staircase", checkpoint = true, supplies = false, function()
      if dk3.health() < 60 then P.take(95, nil, {areas = true}) end
      move({352,-728,-168}, {radius = 8, vertical_radius = 16})
      clear {radius = 400, vertical_radius = 96, weapon = 16, hold = true,
        arena = {{240,-800},{416,-600}}, timeout = 120}
      rally_carrier({168,-840,-168}, true)
      -- The required corridor leaves the tower to the north, then descends
      -- around the east side. An item-goal shortcut enters the blade early.
      -- Return from the fight/rally to the supported corridor before its
      -- northward run. A diagonal from the western fighting stance crosses
      -- the open central shaft.
      move({352,-728,-168}, {direct = true, fight = false,
        radius = 8, vertical_radius = 16})
      escorted_walk({{256,-640,-168},{256,-464,-168},{256,-288,-168},
          {212,-253,-168},{83,-114,-168},{-14,-15,-168},
          {-76,-8,-168},{-224,62,-168}},
        {direct = true, fight = false, radius = 8, vertical_radius = 16})
      escorted_walk({{-223,162,-184},{-142,288,-216}},
        {radius = 8, vertical_radius = 16, weapon = 15})
      kill({index = 128}, {weapon = 15, hold = true,
        arena = {{-256,64},{128,400}}, timeout = 90})
      escorted_walk({{36,326,-264},
          {222,219,-328},{387,128,-344}}, {radius = 8, vertical_radius = 16})
      local medicine = dk3.entity {index = 87}
      if medicine and medicine.visible and medicine.wanted ~= false then
        -- Enter the recess around the foot of the spiral, rather than
        -- jumping to its coarse area boundary above the lower steps.
        local recess = {{361,177,-344},{242,158,-336},{199,77,-336},
          {163,77,-344},{140,75,-344},{116,110,-360}}
        for _, point in ipairs(recess) do
          move(point, {direct = true, radius = 8, vertical_radius = 8})
        end
        P.take(87, nil, {direct = true})
        for i = #recess,1,-1 do
          move(recess[i], {direct = true, radius = 8, vertical_radius = 8})
        end
        move({387,128,-344}, {direct = true, radius = 8, vertical_radius = 8})
      end
      escorted_walk({{676,70,-344},{704,-284,-408},
          {897,-412,-408},{897,-756,-440},{876,-950,-472}},
        {radius = 8, vertical_radius = 16})
      -- Reach the foot of the inner staircase before following its blade.
      clear {radius = 480, vertical_radius = 112, weapon = 16, timeout = 120}
      escorted_walk({{888,-1150,-472},{861,-1248,-488},
          {848,-1303,-504},{796,-1377,-536},{716,-1417,-552}},
        {radius = 8, vertical_radius = 16})
      kill({index = 122}, {weapon = 16, timeout = 60})
      kill({index = 84}, {weapon = 16, timeout = 60})
      escorted_walk({{612,-1430,-584},{481,-1387,-616},
          {379,-1293,-648},{398,-1186,-664},{376,-1108,-680},
          {376,-980,-680},{473,-840,-680}}, {radius = 8, vertical_radius = 16})
      kill({index = 121}, {weapon = 15, timeout = 90,
        arena = {{344,-1120},{492,-792}}})
      clear {radius = 480, vertical_radius = 96, weapon = 16, timeout = 120}
      if dk3.health() < 80 then P.take(82, nil, {areas = true}) end
      move({473,-840,-680}, {radius = 8, vertical_radius = 16})
      local previous = dk3.entity {index = 269}
      local previous_z = previous and previous.z
      wait_until(function()
        local blade = dk3.entity {index = 269}
        if not blade then return false end
        local ascending = previous_z and blade.z > previous_z + 0.1 and blade.z < -420
        previous_z = blade.z
        return ascending
      end, {timeout = 45, fight = false, reason = "blade begins its ascent"})
      for _, point in ipairs({{544,-864,-648},{606,-846,-632},
          {620,-803,-600},{666,-796,-584},{642,-746,-568},
          {666,-722,-552},{679,-690,-536},{722,-653,-520},
          {675,-596,-488},{632,-540,-456},{579,-576,-440},
          {570,-495,-424},{500,-520,-424},{400,-600,-424}}) do
        move(point, {crouch = true, fight = false, radius = 8, vertical_radius = 16})
      end
      P.take(56, nil, {areas = true, crouch = true, fight = false})
    end},
    {"break-floor-and-leave-dungeon", checkpoint = true, function()
      move({400,-520,-424}, {direct = true, crouch = true, fight = false,
        radius = 8, vertical_radius = 16})
      move({400,-288,-424}, {direct = true, crouch = true, fight = false,
        radius = 8, vertical_radius = 16})
      move({360,-256,-424}, {direct = true, crouch = true, fight = false,
        radius = 8, vertical_radius = 16})
      P.once(554, {direct = true, crouch = true, hold = true, fight = false})
      wait_until(function() return dk3.mover({index = 77}) == "open" end,
        {timeout = 15, reason = "upper gate opens beyond the blade"})
      touch({index = 154}, {timeout = 90})
      wait_until(function()
        local floor = dk3.entity {index = 155}
        return not floor or floor.broken
      end, {timeout = 10, reason = "floor breaks into the lower passage"})
      move({384,-88,-680}, {direct = true, radius = 8, vertical_radius = 24})
      P.once(721, {areas = true})
      wait_until(function()
        return dk3.mover({index = 37}) == "open" and dk3.mover({index = 50}) == "open"
      end, {timeout = 15, reason = "lower-passage lever clears the carrier's route"})
      clear {radius = 640, vertical_radius = 96, weapon = 16, timeout = 120}
      escort_gate(689, 690, 55, {448,-96,-680}, {608,-96,-680}, {256,-96,-680}, function()
        local buddy = dk3.entity {class = "mikikofly"}
        return buddy and buddy.x > 548 and math.abs(buddy.z + 680) < 24
      end, {{480,-144,-680}}, {768,-96,-680}, {568,-48,-680})
      -- Walk the supported descending treads into the low exit. The coarse
      -- area route instead jumps across them and can retain its short landing
      -- indefinitely, crouching in place before the exit volume.
      move({832,-240,-680}, {crouch = true, radius = 8, vertical_radius = 16})
      -- The final Buboid can emerge after the earlier, more distant clear.
      -- Finish him from the landing before entering the occupied stair.
      kill({index = 119}, {weapon = 18, hold = true,
        arena = {{800,-288},{880,-192}}, timeout = 90})
      path({{896,-240,-680},{928,-240,-696},{960,-240,-712},
          {992,-240,-728},{1024,-240,-744},{1144,-240,-744}},
        {direct = true, crouch = true, fight = false, radius = 4,
          vertical_radius = 8, timeout = 20, allowed_exit = {index = 671}})
      P.cross(671, {areas = true, crouch = true, timeout = 180})
    end},
  }(visit, resumed)
end)

level("e3m3c", function(visit, resumed)
  return stages {
    {"three-dungeon-cranks", function()
      P.once(50)
      P.take(77, nil, {areas = true, weapon = 15})
      P.once(49, {areas = true, weapon = 15})
      kill({index = 135}, {weapon = 15, timeout = 90,
        arena = {{1456,-880},{1728,-640}}})
      P.once(48)
      kill({index = 122}, {weapon = 18, hold = true,
        arena = {{2208,-544},{2384,-384}}, timeout = 90})
    end},
    {"stavros-arena", checkpoint = true, function()
      P.stay()
      wait_until(function()
        return dk3.mover({index = 1007}) == "open" and dk3.mover({index = 149}) == "open"
      end, {timeout = 30, reason = "third crank retracts the arena entrance spikes"})
      P.follow()
      -- Replan from the actual crank-room floor. The supplied node corridor
      -- can return along the north wall and stop above the arena approach.
      move({1373,19,-744},{radius=12,vertical_radius=24,weapon=16,timeout=120})
      -- The timed wooden entrance closes behind Hiro. Bring the carrier
      -- through it with the inside lever before leaving him for the fight.
      -- Being within rally range on its far side is not arena admission.
      move({1408,0,-744}, {direct = true, fight = false, radius = 8, vertical_radius = 24})
      move({1408,-240,-744}, {direct = true, fight = false, radius = 8, vertical_radius = 24})
      carry_through(1009, 1003, {1408,-176,-744}, function()
        local buddy = dk3.entity {class = "mikikofly"}
        return buddy and buddy.x > 1376
      end, {1376,-304,-744}, nil, true)
      move({1408,0,-744}, {direct = true, fight = false, radius = 8, vertical_radius = 24})
      move({1348,28,-744}, {direct = true, fight = false, radius = 8, vertical_radius = 24})
      -- The guide leaves Superfly at the entrance, outside the arena teeth.
      rally_carrier({1373,128,-744}, true, 48, 192)
      P.stay()
      move({1400,0,-744}, {direct = true, radius = 8, vertical_radius = 16})
      -- Retracted teeth leave both the original floor and raised footing.
      leap({1400,0,-744}, {1480,0,-728}, {pace = 1, radius = 24, vertical_radius = 24})
      wait(0.4, {fight = false})
      local sx,sy,sz = dk3.position()
      if sz < -728 then
        point_at({1504,sy,-712})
        leap({sx,sy,sz}, {1504,sy,-712}, {pace = 1, radius = 40, vertical_radius = 16})
        wait(0.4, {fight = false})
      end
      sx,sy,sz = dk3.position()
      if sz > -752 then
        point_at({1560,sy,-768})
        leap({sx,sy,sz}, {1560,sy,-768}, {pace = 1, radius = 32, vertical_radius = 16})
      end
      move({1920,0,-768}, {direct = true, radius = 8, vertical_radius = 16})
      touch({index = 148}, {direct = true, timeout = 120})
      cinematic()
      P.boss("monster_stavros", {weapon = 16, hold = true,
        arena = {{1504,-704},{2192,64}}, timeout = 240})
      -- Ballista recoil can leave Hiro on the spiral's north lip. Return to
      -- the fixed arena floor before the death sequence rotates that lip.
      move({1920,0,-768}, {direct = true, fight = false,
        radius = 8, vertical_radius = 16})
      wait_until(function() return dk3.mover({index = 25}) == "open" end,
        {timeout = 45, fight = false, stance = {1920,0,-768}, around = {0,0,0},
          reason = "Stavros death platform"})
      wait_until(function() return dk3.mover({index = 37}) == "paused" end,
        {timeout = 30, fight = false, stance = {1920,0,-768}, around = {0,0,0},
          reason = "arena spiral finishes rising and rotating"})
      move({1856,16,-768}, {direct = true, radius = 8, vertical_radius = 16})
      point_at({1840,-228,-744})
      leap({1856,-72,-768}, {1840,-228,-744}, {pace = 1, radius = 32, vertical_radius = 16})
      P.take(24, nil, {direct = true}) P.follow()
    end},
    {"stavros-spiral-walkway", checkpoint = true, function()
      wait_until(function() return dk3.mover({index = 37}) == "paused" end,
        {timeout = 30, reason = "arena spiral finishes rising and rotating"})
      -- The lowest turn meets the staff platform on its west side. The
      -- nearest eastern node is one half-turn above this starting floor.
      move({1840,-228,-744}, {direct = true, radius = 8, vertical_radius = 16})
      local buddy=dk3.entity{class="mikikofly"}
      local support=buddy and dk3.trace({buddy.x,buddy.y,buddy.z+0.25},
        {buddy.x,buddy.y,buddy.z-4},{class="mikikofly"})
      -- A follower already on the spiral should continue to its western
      -- entry, rather than return across the raised staff platform.
      if not support or support.start_solid or support.fraction==1 or support.index~=37 then
        -- He may board the spiral while this call is active. Retain that
        -- supported arrival instead of recalling him onto the staff deck.
        rally_carrier({1856,-72,-768}, true, 32, 96, nil, nil, nil, 37)
      end
      P.follow()
      point_at({1684,-228,-746})
      leap({1776,-228,-744}, {1684,-228,-746}, {pace = 0.6, radius = 48, vertical_radius = 16})
      move({1684,-228,-746}, {direct = true, radius = 8, vertical_radius = 16})
      -- Aim Come along this turn of the spiral, rather than back across the
      -- gap. Proximity alone also accepts a carrier still on the far bank.
      rally_carrier({1684,-356,-746}, true, 24, 96,
        function(buddy)
          if buddy.x >= 1740 then return false end
          local floor=dk3.trace({buddy.x,buddy.y,buddy.z},
            {buddy.x,buddy.y,buddy.z-4},{class="mikikofly"})
          return not floor.start_solid and floor.fraction<1 and floor.index==37
        end)
      P.follow()
      local spiral = {}
      for angle = 195,720,15 do
        local radians = math.rad(angle)
        spiral[#spiral + 1] = {1812+128*math.cos(radians),-228+128*math.sin(radians),
          -746+(angle-180)*192/360}
      end
      -- Keep the carrier on each supported turn. Completing both revolutions
      -- before recalling him lets an ordinary pursuit cut across the centre
      -- or settle on the lower floor beneath the upper walkway.
      -- Adjacent spiral turns overlap in plan view. The ordinary128/48
      -- rally envelope can admit a carrier on the lower revolution and
      -- eventually leave him unable to climb to Hiro's current turn.
      escorted_walk(spiral, {direct = true, fight = false,
        radius = 8, vertical_radius = 16, pace = 0.5}, false, nil,
        -- Use the aimed Move landing while retaining ordinary following
        -- distance. Require support on this spiral turn and exclude other
        -- revolutions by their height.
        {height = 32, radius = 128, support = 37, aimed_move = true})
      for _, point in ipairs({{1936,-96,-464},{1936,64,-464},{1880,152,-488}}) do
        move(point, {direct = true, fight = false, radius = 8, vertical_radius = 16})
      end
    end},
    {"upper-walkways-and-columns", checkpoint = true, function()
      kill({index = 115}, {weapon = 18, hold = true,
        arena = {{1808,128},{1968,256}}, timeout = 90})
      rally_carrier({1936,64,-464}, true, 48, 192)
      P.follow()
      clear {radius = 900, vertical_radius = 96, weapon = 16, timeout = 180}
      P.take(82, nil, {areas = true, weapon = 16})
      P.take(937, nil, {areas = true, weapon = 16})
      P.take(76, nil, {areas = true, weapon = 18})
      nodepath({496,1496,-344}, {weapon = 16})
      clear {radius = 400, vertical_radius = 96, weapon = 15, timeout = 120}
      nodepath({1768,1429,-200}, {fight = false})
      -- These guards roam between floors. Clear the ambush actually on this
      -- landing; a named guard already downstairs cannot be hunted from this
      -- constrained firing stand while the Buboid and worm attack nearby.
      clear {radius = 320, vertical_radius = 112, weapon = 18, hold = true,
        arena = {{1600,1328},{1784,1472}}, timeout = 120}
      -- Return along the cleared floors for medicine. A melee pursuit of
      -- a worm on the northern stair leaves this route on its upper trim.
      P.take(68, nil, {areas = true, weapon = 16, fight = false})
      -- The lower medicine is enough for this crossing. A second optional
      -- medicine tour would cross back through the already-cleared floors.
      nodepath({1768,1429,-200}, {fight = false})
    end},
    {"northern-lava-stair", checkpoint = true, function()
      -- Revisit the real medicine left on the cleared lower walkways. The
      -- encounter at this landing includes both melee attackers and a
      -- shooter throwing over the ledge; trading from low health is unsafe.
      P.take(82, nil, {areas = true, weapon = 16})
      P.take(16, nil, {areas = true, weapon = 16})
      nodepath({1768,1429,-200}, {weapon = 16})
      -- The lower-room shooter still sees this landing, and a second worm
      -- follows from the stair. Clear both before disabling combat for the
      -- narrow approach; killing only108 leaves that ambush alive.
      for _, threat in ipairs({{103,15},{104,15}}) do
        kill({index = threat[1]}, {weapon = threat[2], hold = true,
          arena = {{1700,1300},{1824,1504}}, timeout = 90})
      end
      kill({index = 107}, {weapon = 16, timeout = 90})
      -- A surviving worm follows from the lower room. Finish that pursuit
      -- on the broad landing before the slow, precise steps beside lava.
      kill({index = 108}, {weapon = 16, timeout = 90})
      -- Walk around the northern staircase to the upper storey; a nearest
      -- supplied-node endpoint below this floor is not the stair entrance.
      -- The western strip is the surviving floor around the lava gap.
      -- Clear its shooters before taking that narrow line with the carrier.
      for _, point in ipairs({{1632,1536,-200},{1616,1600,-200},{1616,1728,-213},
          {1632,1744,-215}}) do
        move(point, {direct = true, fight = false,
          radius = 2, vertical_radius = 8, pace = 0.5})
      end
      leap({1632,1744,-215}, {1616,1776,-201},
        {crouch = true, fight = false, pace = 0.25, radius = 16, vertical_radius = 12})
      move({1616,1776,-201}, {direct = true, fight = false,
        radius = 2, vertical_radius = 8, pace = 0.25})
      move({1616,1968,-203}, {direct = true, weapon = 15,
        radius = 2, vertical_radius = 8, pace = 0.5})
      -- A melted Buboid can surface here after the earlier ranged clear.
      -- Finish nearby attackers before the carrier's turn, and retain the
      -- Claw while taking that corner instead of walking blindly into a body.
      clear {radius = 160, vertical_radius = 96, weapon = 15, hold = true,
        arena = {{1584,1904},{1696,2016}}, timeout = 90}
      move({1648,2000,-200}, {direct = true, weapon = 15,
        radius = 2, vertical_radius = 8, pace = 0.5})
      rally_carrier({1616,1968,-203}, true, 48, 128)
      for _, point in ipairs({{1648,2032,-184},{1648,2064,-168},{1648,2096,-152},
          {1648,2128,-136},{1648,2160,-120},{1632,2176,-104},{1616,2208,-88},
          {1584,2240,-56},{1552,2272,-40},{1520,2272,-24},{1488,2288,-8}}) do
        move(point, {direct = true, fight = true, weapon = 15,
          radius = 4, vertical_radius = 8, pace = 0.5})
      end
      rally_carrier({1552,2272,-40}, true, 48, 128)
      for _, point in ipairs({{1456,2272,24},{1424,2272,40},{1408,2272,56},
          {1376,2256,72},{1344,2224,88},{1312,2192,120},{1280,2160,136},{1264,2144,152}}) do
        move(point, {direct = true, fight = true, weapon = 15,
          radius = 4, vertical_radius = 8, pace = 0.5})
      end
      -- The upper-room guards can fire during this rally. Clear them from
      -- their own floor before the slow escort turn and medicine approach.
      clear {radius = 900, vertical_radius = 112, weapon = 16, timeout = 180}
      rally_carrier({1344,2224,88}, true, 48, 128)
      escorted_walk({{1120,2000,152},{1120,1936,152},{1136,1920,152}},
        {direct = true, crouch = true, weapon = 15, radius = 8, vertical_radius = 16, pace = 0.5})
      P.take(991, nil, {areas = true, weapon = 15})
      local ammunition=dk3.entity{index=65}
      if ammunition and ammunition.visible and ammunition.wanted~=false then
        -- The area shortcut crosses the room's long wall. Its supported
        -- corridor goes around the northern end and down the eastern aisle.
        local aisle=walkflood({{1464,1400,144}},{1008,1200,1536,2048},16,{crouch=true})[1]
        if aisle then
          local function walk_aisle(point)
            move(point,{direct=true,crouch=point.mark=="c",fight=false,
              weapon=15,pace=0.5,radius=4,vertical_radius=8})
          end
          for _,point in ipairs(aisle) do walk_aisle(point) end
          P.take(65,nil,{direct=true,crouch=true,fight=false,weapon=15})
          -- Return to the admitted western bank before the column-hall route.
          for index=#aisle,1,-1 do walk_aisle(aisle[index]) end
        else
          dk3.log("optional northern ammunition has no qualified floor corridor")
        end
      end
    end},
    {"collapsing-column-hall", checkpoint = true, function()
      move({1006,1028,152}, {weapon = 15, radius = 8, vertical_radius = 16})
      clear {radius = 512, vertical_radius = 64, weapon = 18, timeout = 120}
      -- Keep under the column overhang instead of letting a partial node
      -- corridor drop into the lower room. The western wall rises to the grate.
      P.follow()
      for _, point in ipairs({
        {960,976,152},{896,976,156},{848,1024,152},
        {720,1024,152},{592,1024,152},{464,1024,152},
        {336,1024,152},{240,1024,156},{176,1024,152},
        {48,1024,152},{-16,1024,152},{-48,992,160},
        {-80,1024,152},{-112,1056,168},{-144,1088,168},
        {-176,1120,184},{-208,1152,200},{-240,1184,216},
        {-240,1216,232},{-272,1248,232},{-304,1280,232},
        {-336,1312,232},{-304,1344,232},
      }) do
        move(point, {direct = true, crouch = true, weapon = 15,
          radius = 4, vertical_radius = 16, pace = 0.5})
      end
      P.breakage(60, {hold = true, crouch = true, weapon = 15})
    end},
    {"broken-stair-path", checkpoint = true, function()
      nodepath({-820,1198,280}, {weapon = 15})
      rally_carrier({-820,1100,280}, true, 48, 192)
      kill({index = 93}, {weapon = 16, hold = true, timeout = 90})
      move({-864,1200,296}, {direct = true, fight = false, radius = 4, vertical_radius = 16})
      point_at({-800,1520,240})
      leap({-864,1264,296}, {-800,1520,240}, {pace = 1, crouch = true, radius = 16, vertical_radius = 16})
      move({-800,1520,240}, {direct = true, fight = false, radius = 4, vertical_radius = 16})
      leap({-800,1520,240}, {-760,1488,268}, {radius = 24, vertical_radius = 16})
      move({-760,1512,272}, {direct = true, radius = 8, vertical_radius = 16})
      leap({-760,1504,272}, {-784,1536,304}, {pace = 0.3, radius = 24, vertical_radius = 16})
      move({-864,1536,304}, {direct = true, radius = 8, vertical_radius = 16})
      P.once(844, {direct = true})
      wait_until(function() return dk3.mover({index = 127}) == "open" end,
        {timeout = 20, reason = "the lever extends the companion bridge"})
      move({-864,1584,312}, {direct = true, radius = 8, vertical_radius = 16})
      P.follow()
      rally_carrier({-864,1464,312}, true, 48, 192)
      P.follow()
    end},
    {"upper-rooms-and-exit", checkpoint = true, function()
      -- The area graph joins a node below the broken stairs. Follow the
      -- actual supported upper staircase before asking it for room routes.
      -- Defensive fire at the rally can leave Hiro airborne. Settle onto
      -- this measured lower tread before capturing a staircase origin.
      P.stay()
      move({-848,1568,304},{direct=true,fight=false,on_floor=true,
        radius=4,vertical_radius=8,pace=0.5})
      local stairs=walkflood({{-600,1720,408}}, {-1008,1488,-464,1904},16,{crouch=true})[1]
      assert(stairs,"no supported staircase to the upper rooms")
      for _,point in ipairs(stairs) do
        move(point,{direct=true,weapon=16,crouch=point.mark=="c",
          radius=4,vertical_radius=8,pace=0.5})
      end
      P.follow()
      P.take(59, nil, {areas = true, weapon = 15})
      P.once(586, {areas = true, weapon = 16})
      wait_until(function() return dk3.mover({index = 152}) == "open" end,
        {timeout = 15, reason = "near-side lever opens the upper passage"})
      -- Get beyond the closing leaf before fighting. The worm beside the
      -- doorway otherwise drives a retreat back through it while Hiro is
      -- answering the distant dwarf, leaving the fight behind a closed gate.
      move({-384,1784,432}, {direct = true, fight = false, on_floor = true,
        radius = 8, vertical_radius = 16})
      clear {radius = 256, vertical_radius = 64, weapon = 16, crouch = true,
        hold = true, timeout = 90}
      kill({index = 90}, {weapon = 16, timeout = 120})
      kill({index = 92}, {weapon = 16, timeout = 120})
    end},
    {"tower-staircase-and-exit", checkpoint = true, supplies = false, function()
      -- The body handles its optional medicine tour with the correct lever
      -- on each side. Automatic checkpoint supplies can leave us outside
      -- the closed timed passage before its far-side lever is operated.
      P.press(765, {areas = true})
      wait_until(function() return dk3.mover({index = 152}) == "open" end,
        {timeout = 15, reason = "far-side lever reopens the timed upper passage"})
      local medicine = dk3.entity {index = 59}
      if medicine and medicine.visible and medicine.wanted ~= false then
        P.take(59, nil, {areas = true, weapon = 17})
        P.press(586, {areas = true, weapon = 17})
        wait_until(function() return dk3.mover({index = 152}) == "open" end,
          {timeout = 15, reason = "reopen the passage after collecting its western medicine"})
        move({-448,1784,432}, {direct = true, weapon = 17, radius = 8, vertical_radius = 16})
      end
      -- Stand far enough inside that Come's clear spot is also beyond the
      -- leaf. From the jamb its forward64-unit spot is still outside.
      move({-384,1784,432}, {direct = true, fight = false, radius = 8, vertical_radius = 16})
      carry_through(765, 152, {-256,1784,432}, function()
        local buddy = dk3.entity {class = "mikikofly"}
        return buddy and buddy.x > -480 and buddy.z > 400
      end, {-396,1680,432}, nil, true)
      rally_carrier({-256,1784,432}, true, 48, 128, function(buddy)
        return buddy.x>-480
      end, nil, true)
      -- Clear the jamb before restoring the trailing formation. From the
      -- rally stand its behind-Hiro spot is back through the timed door.
      move({-256,1784,432},{direct=true,fight=false,radius=8,vertical_radius=16})
      P.follow()
      -- Stay in the admitted eastern corridor; a medicine detour back
      -- through the timed door can leave it closed behind the player.
      nodepath({677,1825,432}, {weapon = 16, cautious = false})
      kill({index = 89}, {weapon = 16, hold = true, timeout = 90})
      nodepath({675,1120,392}, {fight = false, cautious = false})
      kill({index = 87}, {weapon = 16, hold = true, timeout = 90})
      local hx, hy, hz = dk3.position()
      wait_until(function()
        local guard = dk3.entity {index = 88}
        return not guard or not guard.health or guard.health <= 0 or guard.z < hz-128
      end, {timeout = 90, fight = true, weapon = 17, stance = {hx,hy,hz}, around = {0,0,0},
        reason = "clear the upper guard without following a knocked-down enemy off the walkway"})
      -- The lever's southeastern approach borders a deep shaft. Settle on
      -- its supported western strip before recalling the carrier or using it.
      nodepath({568,632,408}, {weapon = 16})
      move({568,632,408}, {direct = true, fight = false,
        radius = 4, vertical_radius = 8, pace = 0.35})
      rally_carrier({675,1120,392}, true, 48, 96)
      P.once(726, {areas = true, hold = true, weapon = 16})
      wait_until(function() return dk3.mover({index = 130}) == "open" end,
        {timeout = 15, reason = "corridor lever opens the tower door"})
      -- The opened lever projects above the return strip by more than a
      -- normal step. Clear it with a short controlled leap onto the western
      -- floor before turning into the door; the next call brings the carrier.
      point_at({496,632,408},{fight=false})
      leap({568,632,408},{496,632,408},{crouch=true,fight=false,
        pace=1,radius=12,vertical_radius=16})
      move({424,632,408}, {direct = true, fight = false,
        crouch = true, radius = 4, vertical_radius = 8, pace = 0.5})
      move({424,480,408}, {direct = true, fight = false,
        radius = 8, vertical_radius = 16})
      carry_through(908, 130, {424,320,408}, function()
        local buddy = dk3.entity {class = "mikikofly"}
        return buddy and buddy.y < 480 and math.abs(buddy.z-408) < 24
      end, {360,488,408}, {{328,384},{520,528}}, true, {424,440,384}, 15)
      -- Keep Come aimed into the admitted room; aiming back at the old
      -- approach can pull the carrier into the closing leaf again.
      rally_carrier({424,320,408}, true, 48, 128)
      -- The upper stair guards are outside this room's melee arena. Meet
      -- them on the ascent instead of pursuing their feet from below.
      clear {radius = 700, vertical_radius = 64, weapon = 15,
        arena = {{328,-32},{520,536}}, timeout = 180}
      -- Leave room for the following formation inside this door. Releasing
      -- Stay at the jamb can send its behind-the-player spot back outside.
      move({424,320,408}, {direct = true, fight = false,
        radius = 8, vertical_radius = 16})
      P.follow()
      -- Clear the next stair landing before climbing through its guards.
      -- A worm that wandered back into the garden is outside this hunt.
      nodepath({108,267,488}, {weapon = 16})
      clear {radius = 320, vertical_radius = 224, weapon = 16, timeout = 90}
      nodepath({124,8,536}, {weapon = 16})
      clear {radius = 384, vertical_radius = 160, weapon = 16, timeout = 90}
      nodepath({400,-184,656}, {weapon = 15})
      clear {radius = 900, vertical_radius = 112, weapon = 15, timeout = 180}
      rally_carrier({400,-184,656}, true, 48, 128)
      P.follow()
      P.press(590)
      wait_until(function()
        return dk3.mover({index = 590}) == "open" and dk3.mover({index = 591}) == "open"
      end, {timeout = 15, reason = "both leaves of the final tower door open"})
      move({640,-928,952}, {direct = true, fight = false, radius = 8, vertical_radius = 24})
      rally_carrier({512,-928,952}, true, 48, 128)
      P.follow() P.cross(56, {areas = true, direct = true, weapon = 18, timeout = 120})
    end},
  }(visit, resumed)
end)

level("e3m4a", function(visit, resumed)
  return stages {
    {"purifier-and-falling-barrel", function()
      P.take(8, nil, {areas = true, weapon = 18})
      P.take(38, nil, {areas = true, weapon = 18})
      P.take(4, 30, {areas = true, weapon = 18}) touch {index = 16}
    end},
    {"ice-water-drawbridge", checkpoint = true, function()
      P.stay()
      -- The released barrel crosses the old waiting spot. Step west of its
      -- swept body before waiting for it to break the ice below.
      move({-3008,608,-168}, {direct = true, fight = false,
        pace = 0.25, radius = 4, vertical_radius = 16})
      wait_until(function()
        local barrel=dk3.entity {index = 56}
        return barrel and barrel.z < -760
      end, {timeout = 20, weapon = 16, stance = {-3008,608,-168}, around = {0,0,0},
        reason = "the barrel breaks the ice and sinks clear of the ledge"})
      move({-2944,472,-688}, {direct = true, fight = false, pace = 0.1, radius = 16, vertical_radius = 24})
      -- The submerged rock blocks a straight southward stroke. Follow its
      -- western channel before returning to the deeper southern corner.
      for _, point in ipairs({{-2976,432,-688},{-2992,400,-680},
          {-2976,336,-688},{-2976,304,-680},{-2976,224,-704}}) do
        move(point, {direct = true, fight = false, radius = 8, vertical_radius = 16})
      end
      move({-2944,224,-712}, {direct = true, fight = false, radius = 8, vertical_radius = 16})
      move({-2944,0,-712}, {direct = true, fight = false, radius = 8, vertical_radius = 16})
      move({-2560,0,-712}, {direct = true, fight = false, radius = 8, vertical_radius = 16})
      move({-2560,0,-632}, {direct = true, fight = false, radius = 4, vertical_radius = 8})
      move({-2624,0,-600}, {direct = true, fight = false, radius = 8, vertical_radius = 16})
      move({-2664,224,-600}, {direct = true, settle = false, fight = false,
        radius = 4, vertical_radius = 16})
      point_at({-2720,224,-200})
      move({-2664,224,-200}, {direct = true, settle = false, weapon = 16, radius = 8, vertical_radius = 16})
      move({-2720,224,-200}, {direct = true, weapon = 16, radius = 8, vertical_radius = 16})
      kill({index = 154}, {weapon = 16, hold = true, timeout = 90})
      P.once(59, {areas = true, weapon = 18}) P.follow()
    end},
    {"tower-lightning", checkpoint = true, function()
      P.stay()
      wait_until(function() return dk3.mover({index = 155}) == "open" end,
        {timeout = 15, reason = "the drawbridge finishes lowering"})
      move({-2784,344,-200}, {direct = true, fight = false, radius = 0.5, vertical_radius = 16})
      wait(0.2)
      point_at({-2784,384,-168})
      leap({-2784,352,-200}, {-2784,384,-168}, {crouch = true, pace = 0.4, radius = 24, vertical_radius = 16})
      move({-2784,480,-598}, {direct = true, fight = false, pace = 0.15, radius = 24, vertical_radius = 24})
      move({-2944,752,-168}, {weapon = 16, radius = 16, vertical_radius = 24})
      rally_carrier({-2944,640,-168}, true, 48, 192)
      P.follow()
      for _, point in ipairs({{-2976,544,-168},{-2976,352,-168},{-2976,256,-168}}) do
        move(point, {direct = true, radius = 12, vertical_radius = 24, weapon = 16})
      end
      P.once(581, {areas = true, weapon = 16})
    end},
    {"crypt-key", checkpoint = true, function()
      -- Bring the carrier along the long tower approach before parking for
      -- the solo lift/vent trip. Leaving him at the lightning control makes
      -- the later exit require an unseen route across the whole courtyard.
      P.follow()
      wait_until(function() return dk3.mover({index = 581}) == "open" end,
        {timeout = 10, reason = "the lightning control finishes its press"})
      wait_until(function() return dk3.mover({index = 583}) == "paused" end,
        {timeout = 30, reason = "the lightning control completes its turn and releases the passage"})
      P.approach(199, {weapon = 16})
      rally_carrier({-2160,-1120,152}, 16, 48, 128)
      P.stay()
      P.press(199, {weapon = 16}) ride {index = 247}
      nodepath({-800,-1120,-424}, {crouch = true, weapon = 16})
      move({-688,-1120,-424}, {direct = true, crouch = true, radius = 8, vertical_radius = 16})
      P.press(564, {direct = true, crouch = true, hold = true})
      move({-560,-1120,-456}, {direct = true, crouch = true, radius = 8, vertical_radius = 24})
      touch({index = 132}, {direct = true, crouch = true})
      kill({index = 120}, {weapon = 16, timeout = 90})
      kill({index = 709}, {weapon = 16, timeout = 90})
      P.take(169, 7, {areas = true, crouch = true, weapon = 16})
      P.press(818, {areas = true, crouch = true, weapon = 16}) ride {index = 247}
      P.follow() P.once(642, {areas = true, weapon = 16})
      rally_carrier({-1664,-1104,344}, 16, 48, 128)
      P.follow()
    end},
    {"inner-tower", checkpoint = true, function() P.cross(786) end},
  }(visit, resumed)
end)

level("e3m4b", function(visit, resumed)
  return stages {
    {"wyndrax-key-and-spellbook", function() P.take(90, 11) P.take(91, 13) end},
    {"lightning-rod", checkpoint = true, function()
      P.once(71)
      -- The spellbook table is upstairs. The nearest ground-node endpoint
      -- lies in Wyndrax's live lightning chamber directly below it.
      move({-16,-1056,344}, {weapon = 16, radius = 8, vertical_radius = 16})
      for _, point in ipairs({{-16,-918,344},{36,-864,344},{-24,-732,344},
          {-672,-732,344},{-672,-1066,344},{-672,-1180,344},
          {-792,-1280,344}}) do
        move(point, {direct = true, weapon = 16, radius = 8, vertical_radius = 16})
      end
      for _, point in ipairs({{-864,-1312,344},{-944,-1504,344},{-864,-1696,344},{-672,-1776,344}}) do
        move(point, {direct = true, radius = 8, vertical_radius = 16, weapon = 16})
      end
      P.once(36, {direct = true, hold = true, weapon = 16})
    end},
    {"wyndrax-pursuit", checkpoint = true, function()
      nodepath {-672,-1504,96}
      P.boss("monster_wyndrax", {timeout = 300})
      P.take {class = "weapon_wyndrax"}
    end},
    {"leave-tower", checkpoint = true, function() P.cross(33) end},
  }(visit, resumed)
end)

level("e3m5a", function(visit, resumed)
  return stages {
    {"torch-purifier", function() P.once(100) P.take(3, 31) end},
    {"crypt-pillars", checkpoint = true, function()
      P.resolve_retaliation()
      -- The pursuing Lycanthir can survive ranged fire at one health and
      -- already reach the torch ledge. Finish him before waiting/escorting.
      kill({index = 80}, {weapon = 15, timeout = 90})
      -- The shard lowers the coffin at 25 units/second; the passage is
      -- obstructed for over ten seconds before its door becomes reachable.
      wait_until(function() return dk3.mover({index = 101}) == "open" end,
        {timeout = 20})
      -- Regroup below the torch before descending. Calling from the pillar
      -- hall leaves the carrier trying to jump back onto the shard stand.
      move({-1664,-1000,568}, {direct = true, fight = false, radius = 8, vertical_radius = 16})
      rally_carrier({-1600,-800,616}, true, 48, 96)
      escorted_walk({{-1536,-960,568},{-1472,-896,520},{-1472,-832,488},
        {-1472,-736,440},{-1472,-608,440}},
        {direct = true, fight = false, pace = 0.5, radius = 8, vertical_radius = 24})
      P.press(235, {areas = true, weapon = 16})
      nodepath({-688,-336,216}, {weapon = 16})
      -- Automatic Ballista defense recoils off this bank and the pillars.
      rally_carrier({-768,-336,216}, 16, 48, 96)
      -- Come selects a clear spot near Hiro, which can occupy the narrow
      -- run-up. Use the ordinary aimed Move order to park on the measured
      -- southern bank before accelerating toward the first pillar.
      -- Clear the carrier's path across the bank first: standing at the
      -- rally spot can block his shoulder-to-shoulder Move to that parking.
      move({-624,-304,216}, {direct = true, on_floor = true, fight = false,
        pace = 0.35, radius = 4, vertical_radius = 8})
      -- The small southern pad remains within lane-yield range of the
      -- running approach. Park on the supported western bank instead.
      local function clear_parking_ray(candidate)
        local px,py,pz=dk3.position()
        local sight=dk3.trace({px,py,pz+22},candidate,"shot")
        return sight.fraction<1 and sight.normal_z>=0.7
          and (sight.x-candidate[1])^2+(sight.y-candidate[2])^2<8^2
          and math.abs(sight.z-candidate[3])<2
      end
      local function parking_ray()
        for _,candidate in ipairs({{-832,-256,208},{-832,-224,208},{-864,-256,208}}) do
          if clear_parking_ray(candidate) then return candidate end
        end
      end
      local park=parking_ray()
      -- A carrier north of the takeoff blocks these rays. The supported
      -- south stand sees past him; retain the original stand when clear.
      if not park then
        move({-640,-352,216}, {direct = true, on_floor = true, fight = false,
          pace = 0.35, radius = 4, vertical_radius = 8})
        park=parking_ray()
      end
      expect(park~=nil,"a clear order ray to the western Crypt parking bank")
      -- Looking takes ordinary frames; the yielding carrier can step into
      -- a ray that was clear before that turn. Check the selected floor
      -- again after aiming before issuing the actual Move command.
      local aimed=false
      local deadline=dk3.time()+15000
      while not aimed and dk3.time()<deadline do
        point_at(park,{fight=false})
        aimed=clear_parking_ray(park)
        if not aimed then
          park=parking_ray()
          if not park then
            move({-640,-352,216},{direct=true,on_floor=true,fight=false,
              pace=0.35,radius=4,vertical_radius=8})
            park=parking_ray()
          end
          expect(park~=nil,"a clear parking ray after the carrier yields")
        end
      end
      expect(aimed,"the western parking floor remains clear after aiming")
      dk3.sidekick("superfly", "move")
      wait_until(function()
        local buddy = dk3.entity {class = "mikikofly"}
        return buddy and math.abs(buddy.x-park[1]) < 20
          and math.abs(buddy.y-park[2]) < 20 and math.abs(buddy.z-232) < 8
      end, {timeout = 30, fight = false,
        reason = "carrier clears the first pillar run-up"})
      P.stay()
      -- Rally leaves the carrier waiting. Keep him outside each takeoff
      -- until Hiro lands; Follow sends his body straight into the run-up.
      -- Parking held Hiro at the lip. Return to the bank before the leap's
      -- approach so this first jump retains its normal running takeoff.
      move({-688,-332,216}, {direct = true, on_floor = true, fight = false,
        pace = 0.35, radius = 4, vertical_radius = 8})
      point_at({-464,-224,216}, {fight = false})
      leap({-624,-304,216}, {-464,-224,216},
        {pace = 1, radius = 64, vertical_radius = 24, fight = false, weapon = 16})
      move({-432,-224,216}, {direct = true, fight = false, pace = 0.25, radius = 8, vertical_radius = 16})
      rally_carrier({-624,-304,216}, 16, 48, 96)
      leap({-384,-240,216}, {-160,-432,160},
        {pace = 1, radius = 48, vertical_radius = 32, fight = false, weapon = 16})
      move({-160,-432,160}, {direct = true, fight = false, radius = 8, vertical_radius = 24})
      rally_carrier({-432,-224,216}, 16, 64, 128)
      P.follow()
      P.approach(62)
    end},
    {"nharre", checkpoint = true, function()
      P.stay()
      P.boss("monster_nharre", {weapon = 19, timeout = 300})
      P.take {class = "weapon_nightmare"}
      P.follow()
    end},
    {"final-purifier-fragment", checkpoint = true, function()
      P.take(4, 32)
      move({1280,2752,-280},{direct=true,fight=false,radius=8,vertical_radius=24})
      P.follow() P.cross(55)
    end},
  }(visit, resumed)
end)

level("e3m6a", function(visit, resumed)
  return stages {
    {"complete-purifier", function()
      expect(P.has({26,27,28,29,30,31,32}), "all seven Purifier fragments required")
    end},
    {"sinking-platforms", checkpoint = true, function()
      P.resolve_retaliation()
      -- The map's authored sidekick transfers stage the carrier through
      -- this solo course and onto his lift. Following onto each tiny bank
      -- instead lets him stand underneath the player's next takeoff.
      P.stay()
      move({1296,-552,-1664},{direct=true,fight=false,radius=8,vertical_radius=24})
      leap({1296,-520,-1664},{index=150},{settle=false,pace=0.45,radius=40,vertical_radius=24})
      hop_from_here({1296,-256,-1688},{pace=0.6,radius=64,vertical_radius=24})
      move({1296,-256,-1688},{direct=true,fight=false,pace=0.35,radius=8,vertical_radius=16})
      leap({1272,-248,-1688},{1120,-232,-1688},{pace=1,radius=64,vertical_radius=24})
      move({1104,-232,-1688},{direct=true,fight=false,pace=0.35,radius=8,vertical_radius=16})
      leap({1056,-232,-1688},{index=147},{settle=false,pace=0.8,radius=40,vertical_radius=24})
      hop_from_here({704,-284,-1688},{pace=0.6,radius=64,vertical_radius=24})
      move({592,-284,-1684},{direct=true,fight=false,radius=12,vertical_radius=24})
      leap({552,-264,-1684},{488,-184,-1704},{pace=0.6,radius=64,vertical_radius=32})
      leap({448,-144,z()},{index=144},{settle=false,pace=0.6,radius=40,vertical_radius=24})
      hop_from_here({376,184,-1688},{pace=0.55,radius=64,vertical_radius=24})
      leap({376,224,z()},{384,344,-1688},{pace=0.55,radius=48,vertical_radius=24})
      move({464,336,-1684},{direct=true,fight=false,radius=12,vertical_radius=24})
      leap({496,352,-1684},{680,384,-1692},{pace=0.8,radius=48,vertical_radius=32})
      move({680,352,-1692},{direct=true,fight=false,radius=8,vertical_radius=32})
      leap({744,352,z()},{index=141},{around={-24,0,0},settle=false,pace=1,radius=40,vertical_radius=24})
      leap({960,328,z()},{1168,280,-1696},{pace=0.8,radius=48,vertical_radius=24})
      move({1568,256,-1696},{direct=true,fight=false,radius=8,vertical_radius=24})
      leap({1584,280,-1696},{1744,320,-1688},{pace=0.9,radius=64,vertical_radius=24})
      move({1816,400,-1684},{direct=true,fight=false,radius=8,vertical_radius=24})
      leap({1816,448,-1684},{1816,572,-1688},{pace=0.6,radius=40,vertical_radius=24})
      move({1816,556,-1688},{direct=true,fight=false,pace=0.35,radius=8,vertical_radius=16})
      leap({1800,592,-1688},{1684,744,-1688},{pace=0.9,radius=48,vertical_radius=24})
      move({1712,748,-1688},{direct=true,fight=false,pace=0.35,radius=4,vertical_radius=16})
      point_at({index=138},{fight=false})
      leap({1668,748,z()},{index=138},{settle=false,pace=0.8,radius=40,vertical_radius=24})
      local _,rock_y=dk3.position()
      leap({1448,rock_y,z()},{index=135},{settle=false,pace=0.8,radius=40,vertical_radius=24})
      local rock_x,exit_y=dk3.position()
      leap({math.min(1240,rock_x-16),exit_y,z()},{1072,720,-1670},{pace=0.8,radius=48,vertical_radius=32})
      -- Clear the bat from this broad bank before the two short western
      -- hops. Its bite can lift Hiro during the next takeoff approach.
      kill({index=435},{hold=true,weapon=16,radius=1000,timeout=45})
      move({832,752,-1672},{direct=true,fight=false,radius=12,vertical_radius=24})
      leap({800,768,z()},{672,784,-1680},{pace=0.7,radius=48,vertical_radius=24})
      move({608,780,-1680},{direct=true,fight=false,radius=12,vertical_radius=24})
      leap({600,768,-1680},{504,744,-1668},{pace=0.6,radius=48,vertical_radius=24})
      move({400,768,-1664},{direct=true,fight=false,radius=12,vertical_radius=24})
      -- The bank winds west around a solid wall before turning north.
      -- Cutting directly to the health island hits that wall in midair.
      for _,point in ipairs({{320,768,-1676},{256,768,-1676},{240,816,-1684},
          {240,880,-1684},{272,928,-1684},{320,960,-1680},
          {368,992,-1676},{432,1024,-1676}}) do
        move(point,{direct=true,weapon=16,radius=8,vertical_radius=24})
      end
      P.take(55,nil,{areas=true,weapon=16})
      P.press(159,{areas=true,weapon=16})
      -- The carrier has his own lift, raised from the upper floor. Following
      -- Hiro onto the rotating lift walks him off this bank into the lava.
      P.stay()
      wait_until(function()
        local lift=dk3.entity{index=172}
        return lift.z < -1708 and dk3.mover{index=172}=="paused"
      end,{timeout=30,weapon=16,reason="the rotating lift lowers to the bank before boarding"})
      move({352,1120,-1676},{direct=true,weapon=16,radius=8,vertical_radius=24})
      leap({304,1120,-1676},{index=172},{pace=0.8,radius=40,vertical_radius=24})
      -- A bat can bite during the long ride. Nightmare's self-punishment
      -- on interruption makes it unsuitable for defending this lift.
      ride({index=172},{weapon=16})
    end},
    {"upper-bridges", checkpoint = true, function()
      weapon(16)
      for _,point in ipairs({{176,1024,-1128},{176,1080,-1128},{176,1176,-1128},
          {176,1248,-1128}}) do
        move(point,{direct=true,fight=false,radius=8,vertical_radius=24})
      end
      kill({index=129},{hold=true,arena={{104,960},{192,1272}},weapon=16,timeout=120})
      move({136,1376,-1128},{direct=true,weapon=16,radius=8,vertical_radius=24})
      if dk3.health()<75 then P.take(111,nil,{areas=true,weapon=16}) end
      P.press(158,{areas=true,weapon=16})
      wait_until(function() return dk3.entity{index=172}.z > -944 and dk3.mover{index=172}=="paused" end,
        {timeout=30,weapon=16,reason="the first lever raises the rotating lift into a bridge"})
      save("coop-throne-first-bridge")
      move({-144,1152,-904},{direct=true,weapon=16,radius=8,vertical_radius=24})
      leap({-64,1152,-904},{index=172},{around={-32,80,0},pace=1,radius=40,vertical_radius=24})
      leap({272,1152,z()},{448,1152,-904},{pace=0.8,radius=48,vertical_radius=24})
      nodepath({index=393},{weapon=16,standoff=64})
      P.press(393,{areas=true,weapon=16})
      wait_until(function() return dk3.entity{index=172}.z > -496 and dk3.mover{index=172}=="paused" end,
        {timeout=30,weapon=16,reason="the second lever raises the next bridge"})
      move({-144,1152,-456},{direct=true,weapon=16,radius=8,vertical_radius=24})
      local bridge=dk3.entity{index=172}
      local angle=math.rad(bridge.yaw)
      local dx,dy=212-bridge.x,1152-bridge.y
      leap({-64,1152,-456},{index=172},{around={dx*math.cos(angle)+dy*math.sin(angle),-dx*math.sin(angle)+dy*math.cos(angle),0},pace=1,radius=40,vertical_radius=24})
      P.press(394,{areas=true,weapon=16}) ride({index=172},{weapon=16})
      for _,point in ipairs({{176,1024,56},{176,1080,56},{176,1176,56},
          {176,1248,56},{136,1376,56}}) do
        move(point,{direct=true,weapon=16,radius=8,vertical_radius=24})
      end
      P.approach(481,{weapon=16})
      move({-96,640,40},{direct=true,on_floor=true,fight=false,
        pace=0.35,radius=2,vertical_radius=8})
      P.press(481,{areas=true,hold=true,fight=false,weapon=16})
      P.follow()
    end},
    {"throne-room", checkpoint = true, function()
      -- The upper doorway starts the audience. Button62 is a remote
      -- cinematic completion control which admits the boss afterwards.
      P.stay()
      clear {radius = 900, vertical_radius = 192, weapon = 16, timeout = 180}
      touch({index=77},{weapon=16,timeout=120})
      -- Touch completes after the audience cutscene; the admitted king is
      -- already attacking. Do not spend another cinematic grace period idle.
      P.boss("monster_garroth", {weapon = 16, timeout = 300})
      -- Boss death owns the ending and timestream travel.
      cinematic()
    end},
  }(visit, resumed)
end)

level("timestream34", function() cinematic() end)
