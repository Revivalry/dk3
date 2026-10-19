// SPDX-License-Identifier: GPL-2.0-or-later
//! actor-class: companions. Party identity and explicit orders; shared weapon classes own combat rules.
const class_traits = @import("../../../mechanics/policy/actors/traits.zig");
pub const classes = [_]class_traits.Class{.{ .kind = .companion, .traits = .{ .party = true, .remains = .{ .never = true } } }};
pub const render_tag = 10029;
pub const Identity = enum { mikiko, superfly };
/// `come` walks to a spot in front of the owner, then follows; `backoff` follows without fighting
/// until another order.
pub const Order = enum { follow, stay, attack, collect, move, come, backoff };
pub const Authored = enum { none, stop, teleport };
pub const pain_chance: u8 = 75;
pub const Voice = enum { pain, cold, drowning, burning, death, water_death, extreme_death };
pub fn voice(identity: Identity, kind: Voice, variation: u2) []const u8 {
    return switch (kind) {
        .pain => ([_][]const u8{ "pain1.wav", "pain2.wav", "pain3.wav", "pain4.wav" })[variation],
        .death => ([_][]const u8{ "death1.wav", "death2.wav", "death3.wav", "death4.wav" })[variation],
        .cold => if (variation % 2 == 0) "icehurt1.wav" else "icehurt2.wav",
        .drowning => if (identity == .mikiko) (if (variation % 2 == 0) "waterchoke2.wav" else "waterchoke3.wav") else (if (variation % 2 == 0) "waterchoke3.wav" else "waterchoke4.wav"),
        // Superfly's set ends at death7 (Mikiko has death8).
        .burning => if (identity == .mikiko) ([_][]const u8{ "death6.wav", "death7.wav", "death8.wav" })[@as(usize, variation) % 3] else ([_][]const u8{ "death5.wav", "death6.wav", "death7.wav" })[@as(usize, variation) % 3],
        .water_death => "waterdeath.wav",
        .extreme_death => "udeath.wav",
    };
}

test "companion voices stay within each sidekick's recorded set" {
    const std = @import("std");
    // Superfly recorded death1-death7 and pain1-pain7; Mikiko death1-death8 and pain1-pain8.
    for ([_]Identity{ .mikiko, .superfly }) |identity| {
        const last: u8 = if (identity == .mikiko) '8' else '7';
        for (std.enums.values(Voice)) |kind| for (0..4) |variation| {
            const name = voice(identity, kind, @intCast(variation));
            if (std.mem.startsWith(u8, name, "death") or std.mem.startsWith(u8, name, "pain")) {
                const digit = name[std.mem.indexOfAny(u8, name, "0123456789").?];
                try std.testing.expect(digit <= last);
            }
        };
    }
}
/// The classnames this policy defines (order is the catalog's save order, not this list's).
pub const definitions = [_]@import("../../../mechanics/policy/actors/definition.zig").Definition{
    .{ .classname = "mikiko", .kind = .companion, .idle = "aamba" },
    .{ .classname = "superfly", .kind = .companion, .idle = "aamba" },
    .{ .classname = "mikikofly", .kind = .companion },
};

/// The owner's command window (reference cl_scrn.cpp/cl_selector.cpp): five orders in the window's
/// order, each with its client command and the sidekick's spoken acknowledgement.
pub const Command = enum { get, come, stay, attack, backoff };
pub const command_labels = [_][]const u8{ "GET", "COME", "STAY", "ATTACK", "BACK OFF" };
pub fn commandOrder(command: Command) Order {
    return switch (command) {
        .get => .collect,
        .come => .come,
        .stay => .stay,
        .attack => .attack,
        .backoff => .backoff,
    };
}
/// The command named by a client command: the window's `sidekick_<command>` or a default bind's
/// `companion <word>` (follow, wait, attack, pickup and the window's words).
pub fn parseCommand(word: []const u8) ?Order {
    const std = @import("std");
    if (std.meta.stringToEnum(Command, word)) |command| return commandOrder(command);
    if (std.mem.eql(u8, word, "wait")) return .stay;
    if (std.mem.eql(u8, word, "pickup")) return .collect;
    return std.meta.stringToEnum(Order, word);
}
/// The acknowledgement a sidekick speaks for an accepted order, or for a refused pickup
/// (`sounds/voices/<who>/cmd_<mi|su>_<code>_0<1-3>[_n1].mp3`).
pub fn acknowledgement(identity: Identity, order: Order, refused: bool, variation: u2, buffer: []u8) ?[]const u8 {
    const std = @import("std");
    const code = switch (order) {
        .come => "co",
        .stay => "st",
        .attack => "at",
        .backoff => "ba",
        .collect => "pu",
        .follow, .move => return null,
    };
    const who = if (identity == .mikiko) "mikiko/cmd_mi" else "superfly/cmd_su";
    return std.fmt.bufPrint(buffer, "sounds/voices/{s}_{s}_0{d}{s}.mp3", .{ who, code, @as(u3, variation % 3) + 1, if (refused) "_n1" else "" }) catch null;
}

/// Each party member's status for the owner's HUD flaps, carried in otherwise unused player-state
/// stats, two each (`statIndex`), within the 16-bit signed range.
pub const Status = struct {
    /// It exists on this map (dead or alive).
    exists: bool = false,
    /// It is in the owner's potentially visible set: its flap fades in.
    visible: bool = false,
    health_pct: u7 = 0,
    armor_pct: u7 = 0,
    /// Its weapon's ammunition: none shown, empty, low, good, plenty (reference SIDEKICK_GetAmmoCount).
    ammo: Ammo = .none,
    pub const Ammo = enum(u3) { none, empty, low, good, plenty };
    pub fn pack(self: Status) [2]i32 {
        const a: u16 = @as(u16, self.health_pct) | @as(u16, self.armor_pct) << 7 | @as(u16, @intFromBool(self.exists)) << 14;
        const b: u16 = @intFromEnum(self.ammo) | @as(u16, @intFromBool(self.visible)) << 3;
        return .{ a, b };
    }
    pub fn unpack(words: [2]i32) Status {
        const a: u16 = @truncate(@as(u32, @bitCast(words[0])));
        const b: u16 = @truncate(@as(u32, @bitCast(words[1])));
        return .{ .exists = a & (1 << 14) != 0, .visible = b & 8 != 0, .health_pct = @intCast(@min(100, a & 0x7f)), .armor_pct = @intCast(@min(100, (a >> 7) & 0x7f)), .ammo = if (b & 7 <= @intFromEnum(Ammo.plenty)) @enumFromInt(b & 7) else .none };
    }
    const std = @import("std");
};
/// Player-state stats 7..15 are unused by the engine; the party uses 8..11.
pub const stat_first = 8;
pub fn statIndex(identity: Identity) usize {
    return stat_first + @as(usize, @intFromEnum(identity)) * 2;
}
/// The ammunition gauge (reference SIDEKICK_GetAmmoCount): a weapon without ammunition shows plenty
/// when it fights at range and low when it only strikes; otherwise by the share of its maximum
/// (Mikiko 75%/35%, Superfly 75%/40%).
pub fn ammoLevel(identity: Identity, armed: bool, uses_ammo: bool, ranged: bool, count: i32, maximum: i32) Status.Ammo {
    if (!armed) return .none;
    if (!uses_ammo) return if (ranged) .plenty else .low;
    if (count <= 0) return .empty;
    const share = @as(f32, @floatFromInt(count)) / @as(f32, @floatFromInt(@max(maximum, 1)));
    if (share >= 0.75) return .plenty;
    if (share >= (if (identity == .mikiko) @as(f32, 0.35) else 0.40)) return .good;
    return .low;
}

test "the HUD status survives the 16-bit stat transport" {
    const std = @import("std");
    const status: Status = .{ .exists = true, .visible = true, .health_pct = 100, .armor_pct = 87, .ammo = .good };
    const words = status.pack();
    for (words) |word| try std.testing.expect(word >= 0 and word <= std.math.maxInt(i16));
    try std.testing.expectEqual(status, Status.unpack(words));
    try std.testing.expectEqual(Status{}, Status.unpack(.{ 0, 0 }));
    try std.testing.expect(statIndex(.superfly) + 1 < 16);
}

test "window commands, default binds and spoken acknowledgements" {
    const std = @import("std");
    try std.testing.expectEqual(Order.collect, parseCommand("get").?);
    try std.testing.expectEqual(Order.stay, parseCommand("wait").?);
    try std.testing.expectEqual(Order.collect, parseCommand("pickup").?);
    try std.testing.expectEqual(Order.backoff, parseCommand("backoff").?);
    try std.testing.expectEqual(Order.follow, parseCommand("follow").?);
    try std.testing.expect(parseCommand("dance") == null);
    var buffer: [80]u8 = undefined;
    try std.testing.expectEqualStrings("sounds/voices/superfly/cmd_su_co_02.mp3", acknowledgement(.superfly, .come, false, 1, &buffer).?);
    try std.testing.expectEqualStrings("sounds/voices/mikiko/cmd_mi_pu_03_n1.mp3", acknowledgement(.mikiko, .collect, true, 2, &buffer).?);
    try std.testing.expect(acknowledgement(.mikiko, .follow, false, 0, &buffer) == null);
    try std.testing.expectEqual(Status.Ammo.good, ammoLevel(.mikiko, true, true, true, 40, 100));
    try std.testing.expectEqual(Status.Ammo.low, ammoLevel(.superfly, true, true, true, 38, 100));
    try std.testing.expectEqual(Status.Ammo.plenty, ammoLevel(.superfly, true, false, true, 0, 0));
    try std.testing.expectEqual(Status.Ammo.low, ammoLevel(.superfly, true, false, false, 0, 0));
}
