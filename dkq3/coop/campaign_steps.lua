-- SPDX-License-Identifier: GPL-2.0-or-later
-- Ordinary-input helpers for authored late-campaign routes.
if campaign_steps then return end
campaign_steps = {}
local P = campaign_steps
local function target(value)
  return type(value) == "number" and {index = value} or value
end
local function approach_options(opts, standoff)
  local result = {standoff = standoff}
  for key, value in pairs(opts or {}) do result[key] = value end
  return result
end

function P.has(keys)
  for _, key in ipairs(keys) do if not dk3.has_key(key) then return false end end
  return true
end

function P.approach(value, opts)
  local options = {standoff = 128, timeout = 90}
  for key, value in pairs(opts or {}) do if key ~= "areas" then options[key] = value end end
  local goal = dk3.entity(target(value))
  local px, py, pz = dk3.position()
  if goal and (goal.x-px)^2 + (goal.y-py)^2 + (goal.z-pz)^2 <= options.standoff^2 then return end
  -- Some solo climbs emerge above the companion ground graph. Use the actual
  -- area graph there instead of walking back down to its nearest ground node.
  if opts and opts.areas then
    options.radius = options.radius or options.standoff
    options.vertical_radius = options.vertical_radius or 48
    move(target(value), options)
  else nodepath(target(value), options) end
end

function P.take(value, key, opts)
  if key and dk3.has_key(key) then return end
  local item = dk3.entity(target(value))
  if item and item.visible and item.wanted ~= false then
    -- A direct collection follows a caller-authored landing or dive. Returning
    -- to the nearest supplied ground node can undo that descent entirely.
    if not opts or not opts.direct then P.approach(value, opts) end
    pickup(target(value), opts)
  end
  if key then expect(dk3.has_key(key), "quest item not collected: " .. tostring(value)) end
end

function P.press(value, opts)
  if opts and opts.areas then
    -- A brush control's origin can be inside a wall or above the floor.
    -- The use driver chooses a reachable standing point with a real use
    -- ray and resolves the doors on the way to it. Routing to the raw
    -- entity centre first prevents that planner from ever running.
    local options = {timeout = 90}
    for key, setting in pairs(opts) do options[key] = setting end
    use(target(value), options)
  else
    P.approach(value, opts)
    use(target(value), opts)
  end
end

-- Persistent one-shot controls only: lift calls and reversible levers must
-- still be pressed after an earlier operation that moved them away.
function P.once(value, opts)
  local item = dk3.entity(target(value))
  if item and (item.uses or 0) > 0 then return end
  P.press(value, opts)
end

function P.breakage(value, opts)
  local item = dk3.entity(target(value))
  if item and not item.broken and not item.hidden and item.visible ~= false and item.health and item.health > 0 then
    if not opts or (not opts.direct and not opts.areas) then P.approach(value, approach_options(opts, 256)) end
    shoot(target(value), opts)
  end
end

-- Overlapping fragments can hide one another's centres. Select the actual
-- visible member of this authored group; never shoot an unrelated occluder.
function P.break_group(indices, opts)
  local members = {}
  for _, index in ipairs(indices) do members[index] = true end
  for _ = 1, #indices do
    local first, selected
    local px, py, pz = dk3.position()
    for _, index in ipairs(indices) do
      local item = dk3.entity {index = index}
      if item and not item.broken and not item.hidden and item.health and item.health > 0 then
        first = first or index
        local hit = dk3.trace({px,py,pz + (opts and opts.crouch and 12 or 22)}, {item.x,item.y,item.z}, "shot")
        if members[hit.index] then
          local front = dk3.entity {index = hit.index}
          if front and not front.broken and front.health and front.health > 0 then selected = hit.index break end
        end
      end
    end
    if not first then return end
    P.breakage(selected or first, opts)
  end
  for _, index in ipairs(indices) do
    local item = dk3.entity {index = index}
    expect(not item or item.broken or item.hidden or not item.health or item.health <= 0,
      "breakable group still obstructed: " .. tostring(index))
  end
end

function P.cross(index, opts)
  -- The exit driver chooses a supported point overlapping the trigger.
  -- A tall strip across stairs can have its brush center inside a step.
  if not opts or not opts.areas then P.approach(index, approach_options(opts, 192)) end
  exit({index = index}, opts or {timeout = 180})
end

function P.follow() dk3.sidekick("all", "follow") end
function P.stay() dk3.sidekick("all", "stay") end

-- Resolve a real provoked party before committing it to a dangerous crossing.
-- Damage, mercy, forgiveness and medicine still use normal game mechanisms.
function P.resolve_retaliation()
  if not dk3.party_hostile() then return end
  local x,y,z = dk3.position()
  wait_until(function() return not dk3.party_hostile() end,
    {timeout = 120, fight = true, stance = {x,y,z}, around = {0,0,0},
      reason = "the provoked party finishes its nonlethal response"})
  recover(0.8, 900)
end

function P.boss(class, opts)
  wait_until(function()
    local actor = dk3.entity {class = class}
    -- A cautious approach can already have defeated an admitted boss.
    -- kill() then observes that outcome rather than waiting for a respawn.
    return actor and actor.health ~= nil
  end, {timeout = 45, reason = "authored boss admission: " .. class})
  kill({class = class}, opts or {timeout = 240})
end
