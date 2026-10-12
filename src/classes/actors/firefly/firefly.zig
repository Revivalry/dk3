// SPDX-License-Identifier: GPL-2.0-or-later
//! actor-class: firefly. Ambient fireflies are a swarm emitter, not a hostile monster.
pub const classname = "monster_firefly";

pub const models = [_][]const u8{ "models/global/e_flare.sp2", "models/global/e_flare4+.sp2", "models/global/e_flare4+o.sp2", "models/global/e_flare4x.sp2", "models/global/e_flare4x.sp2", "models/global/e_flare8+.sp2", "models/global/e_flare8+o.sp2", "models/global/e_flareo.sp2" };
pub fn shape(flags: u32) u3 {
    for (0..7) |i| if (flags & (@as(u32, 1) << @intCast(i)) != 0) return @intCast(i + 1);
    return 0;
}
