-- SPDX-License-Identifier: GPL-2.0-or-later
-- Ordinary campaign inputs and bounded checkpoint restoration. Every death
-- remains in the report; this does not establish a death-free episode pass.
include "coop/episode1-pass.lua"
settings {level_deaths = 2, map_deaths = {}, deaths = 8}
