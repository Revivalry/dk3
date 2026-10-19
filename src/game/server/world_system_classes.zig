// SPDX-License-Identifier: GPL-2.0-or-later
//! Class registry: the world systems classes own, per phase of world_systems.zig, in run order
//! (spawn order fixes slot numbers; keep it). Data only; each class implements the phase hook
//! (system_context.zig).
const movers = @import("../../classes/entities/mover/server/movers.zig");
const trains = @import("../../classes/entities/train/server/trains.zig");
const special_movers = @import("../../classes/entities/special_mover/server/special_movers.zig");
const monitors = @import("../../classes/entities/monitor/server/monitors.zig");
const companion_triggers = @import("../../classes/actors/companions/server/companion_triggers.zig");
const healthtrees = @import("../../classes/entities/healthtree/server/healthtrees.zig");
const fireflies = @import("../../classes/actors/firefly/server/fireflies.zig");
const wisps = @import("../../classes/actors/wisp/server/wisps.zig");
const scenery = @import("../../classes/entities/scenery/server/scenery.zig");
const props = @import("../../mechanics/server/props.zig");
const thunder_spray = @import("../../classes/actors/thunderskeet/server/thunder_spray.zig");
const dwarf_axes = @import("../../classes/actors/dwarf/server/dwarf_axes.zig");
const frog_spit = @import("../../classes/actors/froginator/server/frog_spit.zig");
const cryo_spray = @import("../../classes/actors/cryotech/server/cryo_spray.zig");
const companions = @import("../../classes/actors/companions/server/companions.zig");

/// `worldSpawn`, right after brush models.
pub const spawn_movers = .{ movers, monitors };
/// `worldSpawn`, after map music.
pub const spawn_triggers = .{companion_triggers};
/// `worldSpawn`, after authored world actions.
pub const spawn_paths = .{ trains, special_movers };
/// `worldSpawn`, after items.
pub const spawn_fixtures = .{healthtrees};
/// `worldSpawn`, after actors.
pub const spawn_ambient = .{ fireflies, wisps, scenery };
/// `worldPrepare`, `worldMove` and `worldFinish`, in this order each. Also the brush movers that
/// riders and attachments ask: `publishPart`, `authoredPart` and `nextStop`, all optional.
pub const motion = .{ movers, trains, special_movers };
/// `worldArrive`: whose arrivals fire their targets first.
pub const arrivals = .{ movers, special_movers, trains };
/// `worldStep`, after melee.
pub const missiles = .{ thunder_spray, dwarf_axes, frog_spit, cryo_spray };
/// `worldStep`, after ailments.
pub const observers = .{monitors};
/// `worldStep`, after actor audio, outside cinematics.
pub const party = .{companions};
/// `worldStep`, after persistent actor attacks.
pub const ambient = .{ wisps, fireflies, props, healthtrees };
/// `probe(*World, Entity, u32) !void`: prints the class's state for `dk3_runtime_world`.
pub const probes = .{ @import("../../classes/entities/chest/server/chests.zig"), monitors, healthtrees };
/// `observed(*World, Entity) ?{ name, value }`: a count coop scripts read and bots watch for changes.
pub const observables = .{healthtrees};
