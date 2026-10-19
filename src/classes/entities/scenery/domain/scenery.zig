// SPDX-License-Identifier: GPL-2.0-or-later
//! entity-class: scenery. Episode decoration authoring: the decoinfo tables and their classnames.
//! The physical prop they become is props.zig.
const std = @import("std");
const v = @import("../../../../core/domain/vector.zig");
const tables = @import("../../../../core/domain/tables.zig");
const animation = @import("../../../../core/domain/animation.zig");
const props = @import("../../../../mechanics/domain/props.zig");
const Movement = props.Movement;
const Material = props.Material;
pub const Definition = struct {
    model: []const u8,
    movement: Movement,
    material: Material,
    solid: bool,
    mass: f32,
    health: i32,
    exploding: bool,
    mins: v.Vec3,
    maxs: v.Vec3,
    sequences: [5]struct { frames: animation.Sequence, looping: bool } = @splat(.{ .frames = .{}, .looping = false }),
    count: u3,
};
pub fn owns(classname: []const u8) bool {
    return classname.len == 7 and std.mem.startsWith(u8, classname, "deco_e") and classname[6] >= '1' and classname[6] <= '4';
}
pub fn material(name: []const u8) Material {
    const names = .{ .{ "WOOD", Material.wood }, .{ "METAL", Material.metal }, .{ "GLASS", Material.glass }, .{ "GIBS", Material.flesh } };
    inline for (names) |entry| if (std.ascii.eqlIgnoreCase(name, entry[0])) return entry[1];
    // STONE is not a breakable material in the decoration authoring contract.
    return .unbreakable;
}
pub fn find(bytes: []const u8, name: []const u8) !Definition {
    var reader = try tables.Reader.init(bytes);
    while (try reader.next()) |row| {
        if (!std.ascii.eqlIgnoreCase(row.field("modelname") orelse "", name)) continue;
        const move = row.field("movetype") orelse return error.MissingDecorationMovement;
        const solid = row.field("solidtype") orelse return error.MissingDecorationSolidity;
        var result: Definition = .{
            .model = row.field("pathname") orelse return error.MissingDecorationModel,
            .movement = if (std.ascii.eqlIgnoreCase(move, "none")) .stationary else if (std.ascii.eqlIgnoreCase(move, "toss")) .toss else if (std.ascii.eqlIgnoreCase(move, "bounce")) .bounce else return error.UnknownDecorationMovement,
            .material = material(row.field("gibtype") orelse ""),
            .solid = if (std.ascii.eqlIgnoreCase(solid, "bbox")) true else if (std.ascii.eqlIgnoreCase(solid, "not")) false else return error.UnknownDecorationSolidity,
            .mass = try row.number("mass", 1),
            .health = 20,
            .exploding = try row.number("exploding", 0) != 0,
            .mins = undefined,
            .maxs = undefined,
            .count = @intFromFloat(std.math.clamp(try row.number("animseq", 0), 0, 5)),
        };
        const health = try row.number("hitpoints", 20);
        result.health = @intFromFloat(if (health < 1) 20 else health);
        inline for (.{ "x", "y", "z" }, 0..) |axis, i| {
            result.mins[i] = try row.number("min" ++ axis, -16);
            result.maxs[i] = try row.number("max" ++ axis, 16);
            if (result.mins[i] > result.maxs[i]) return error.InvalidDecorationBounds;
        }
        for (0..result.count) |index| {
            var key: [8]u8 = undefined;
            const text = row.field(try std.fmt.bufPrint(&key, "seq{d}", .{index})) orelse return error.MissingDecorationSequence;
            var words = std.mem.tokenizeAny(u8, text, "-~; \t\r\n");
            const first = try std.fmt.parseInt(u16, words.next() orelse return error.InvalidDecorationSequence, 10);
            const last = if (words.next()) |word| try std.fmt.parseInt(u16, word, 10) else first;
            if (last < first or words.next() != null) return error.InvalidDecorationSequence;
            result.sequences[index] = .{ .frames = .{ .first = first, .last = last }, .looping = std.mem.indexOfScalar(u8, text, '~') != null };
        }
        if (!std.mem.startsWith(u8, result.model, "models/") or std.mem.indexOf(u8, result.model, "..") != null or result.model.len >= 64 or result.mass < 0) return error.InvalidDecorationDefinition;
        return result;
    }
    return error.UnknownDecorationModel;
}
