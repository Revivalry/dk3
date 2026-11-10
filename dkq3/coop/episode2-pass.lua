-- SPDX-License-Identifier: GPL-2.0-or-later
-- Isolated Episode 2 campaign pass: normal admission, inventory and inputs.
settings { level_deaths = 4 }
include "coop/repair-capture.lua"
include "coop/episode2.lua"
level("e3m1a", function() finish() end)
