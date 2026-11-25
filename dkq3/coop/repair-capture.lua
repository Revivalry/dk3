-- SPDX-License-Identifier: GPL-2.0-or-later
-- Repair runs retain the exact live navigation/puzzle failure as an ordinary save.
if repair_capture then return end
repair_capture=true
local register_level=level
function level(name,body,entry)
  local function capture(fn)
    return function(...)
      local ok,result=pcall(fn,...)
      if ok then return result end
      local saved,problem=pcall(save,"coop-failure")
      if not saved then dk3.log("failure save unavailable: "..tostring(problem)) end
      error(result,0)
    end
  end
  if body==nil then return function(fn) return register_level(name,capture(fn),entry) end end
  return register_level(name,capture(body),entry)
end
