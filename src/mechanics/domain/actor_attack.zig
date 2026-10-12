// SPDX-License-Identifier: GPL-2.0-or-later
//! Shared mechanism: Persistent actor attacks share entity ownership, not gameplay rules.
const catalog = @import("actor_catalog");
/// Every payload any actor-layer module declares in `attack_payloads`, as
/// `.{ .tag, .Payload, .modelless }`: the saved tag, its state type, and whether its entity
/// draws without a model.
const payloads = blk: {
    @setEvalBranchQuota(100_000);
    var list: []const Entry = &.{};
    for (@typeInfo(catalog).@"struct".decls) |declaration| {
        const owner = @field(catalog, declaration.name);
        if (@TypeOf(owner) != type or @typeInfo(owner) != .@"struct" or !@hasDecl(owner, "attack_payloads")) continue;
        for (owner.attack_payloads) |payload| {
            for (list) |earlier| if (std.mem.eql(u8, earlier.tag, payload.tag)) @compileError("attack payload declared twice: " ++ payload.tag);
            list = list ++ [_]Entry{.{ .tag = payload.tag, .Payload = payload.Payload, .modelless = @hasField(@TypeOf(payload), "modelless") and payload.modelless }};
        }
    }
    break :blk list;
};
const Entry = struct { tag: []const u8, Payload: type, modelless: bool };
const std = @import("std");
pub const Payload = blk: {
    var names: [payloads.len][]const u8 = undefined;
    var types: [payloads.len]type = undefined;
    var values: [payloads.len]u8 = undefined;
    for (payloads, 0..) |payload, index| {
        names[index] = payload.tag;
        types[index] = payload.Payload;
        values[index] = index;
    }
    break :blk @Union(.auto, @Enum(u8, .exhaustive, &names, &values), &names, &types, &@splat(.{}));
};
pub const State = struct {
    owner: u32,
    born_ms: i64,
    stepped_ms: i64,
    attack: Payload,
    /// Each payload owns its save contract, all optional:
    ///   `rebase(self: *P, delta_ms) !void`, `remapIds(self: *P, map) !void`,
    ///   `validSaved(self: P, born_ms, stepped_ms) bool` (its own bounds),
    ///   `saved_components` (component names its entity carries beside the attack body).
    /// Checks across entities (held victims, parent bolts) belong to the class adapter
    /// (actor_classes `validateSavedAttack`).
    pub fn rebase(self: *State, delta: i64) !void {
        try saved.shift(&self.born_ms, delta);
        try saved.shift(&self.stepped_ms, delta);
        switch (self.attack) {
            inline else => |*payload| if (comptime has(@TypeOf(payload.*), "rebase")) try payload.rebase(delta),
        }
    }
    pub fn remapIds(self: *State, map: anytype) !void {
        try map.one(&self.owner);
        switch (self.attack) {
            inline else => |*payload| if (comptime has(@TypeOf(payload.*), "remapIds")) try payload.remapIds(map),
        }
    }
    pub fn validSaved(self: State) bool {
        if (self.owner == 0 or self.stepped_ms < self.born_ms) return false;
        return switch (self.attack) {
            inline else => |payload| if (comptime has(@TypeOf(payload), "validSaved")) payload.validSaved(self.born_ms, self.stepped_ms) else true,
        };
    }
    /// Whether the attack's entity draws without a model (its payload's `modelless`).
    pub fn modelless(self: State) bool {
        return switch (self.attack) {
            inline else => |_, tag| comptime for (payloads) |payload| {
                if (std.mem.eql(u8, payload.tag, @tagName(tag))) break payload.modelless;
            } else unreachable,
        };
    }
    /// The payload's `saved_components`, or none.
    pub fn savedComponents(comptime P: type) []const []const u8 {
        return if (comptime has(P, "saved_components")) &P.saved_components else &.{};
    }
};
const saved = @import("actor_catalog").saved_time;
fn has(comptime T: type, comptime name: []const u8) bool {
    return @typeInfo(T) == .@"struct" and @hasDecl(T, name);
}
