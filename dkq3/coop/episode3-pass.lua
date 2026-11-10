-- SPDX-License-Identifier: GPL-2.0-or-later
-- Normal admission and inventory, with bounded, reported combat recovery.
settings {level_deaths = 4, deaths = 12}
include "coop/repair-capture.lua"
include "coop/episode3.lua"
level("e4m1a", function() finish() end)
