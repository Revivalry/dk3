// SPDX-License-Identifier: GPL-2.0-or-later
// Shared mechanism: per-draw weather style, matching weather.zig Style.
// Main-draw variant 3 reads prepared splashes; preparation itself uses splash variant 2.
layout(constant_id = 0) const uint WEATHER_STYLE = 0u;
const bool WEATHER_IS_SNOW = WEATHER_STYLE == 1u;
const bool WEATHER_IS_SPLASH = WEATHER_STYLE == 2u;
