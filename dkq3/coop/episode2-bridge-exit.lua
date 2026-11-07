-- SPDX-License-Identifier: GPL-2.0-or-later
-- Scoped ordinary-input replay from the legitimate far-railing checkpoint.
settings {level_deaths = 0}
level("e2m2b", function()
  nodepath({index = 45}, {standoff = 160})
  exit({index = 45}, {timeout = 180})
end)
level("e2m2c", function() finish() end)
