// SPDX-License-Identifier: GPL-2.0-or-later
//! Shared mechanism: Authored positional sound parameters shared by server transport and client mixer.
const std = @import("std");
pub const parameter_tag = 10030;
pub const Parameters = struct {
    volume: f32 = 1,
    minimum: f32 = 256,
    maximum: f32 = 648,
    nondirectional: bool = false,
    pub fn valid(self: Parameters) bool {
        return std.math.isFinite(self.volume) and std.math.isFinite(self.minimum) and std.math.isFinite(self.maximum) and self.volume >= 0 and self.volume <= 1 and self.minimum >= 0 and self.maximum > self.minimum and self.maximum <= 65536;
    }
};

/// Original one-shot and looping transports encode gain as an unsigned byte.
/// Supplied maps include gain 2; retain the observable 254/255 wire gain.
pub fn wireVolume(value: f32) !f32 {
    if (!std.math.isFinite(value) or value < 0 or value > 1000000) return error.InvalidSoundVolume;
    const encoded: u32 = @intFromFloat(value * 255);
    return @as(f32, @floatFromInt(encoded & 255)) / 255;
}
test "authored gains retain original byte quantization including supplied gain two" {
    try std.testing.expectEqual(@as(f32, 254.0 / 255.0), try wireVolume(2));
    try std.testing.expectEqual(@as(f32, 127.0 / 255.0), try wireVolume(0.5));
    try std.testing.expectError(error.InvalidSoundVolume, wireVolume(-1));
}

pub fn soundPath(path: []const u8, normalized: []u8) ![]const u8 {
    var length: usize = 0;
    for (path) |char| {
        const next = if (char == '\\') '/' else std.ascii.toLower(char);
        // Map keys also spell paths as "/doors/...". Resource paths are
        // relative to sounds; retaining that slash creates sounds//doors/...
        // and fails resident-world media admission after restoring old saves.
        if (next == '/' and (length == 0 or normalized[length - 1] == '/')) continue;
        if (length == normalized.len) return error.InvalidResourcePath;
        normalized[length] = next;
        length += 1;
    }
    const name = normalized[0..length];
    return if (std.mem.startsWith(u8, name, "sounds/")) name[7..] else name;
}

test "authored sound separators normalize without replacing the named asset" {
    var buffer: [64]u8 = undefined;
    try std.testing.expectEqualStrings("global/e_forcefield.wav", try soundPath("Sounds\\GLOBAL\\\\e_forcefield.wav", &buffer));
    try std.testing.expectEqualStrings("global/e_forcefield.wav", try soundPath("global//e_forcefield.wav", &buffer));
    try std.testing.expectEqualStrings("weapons/ion/fire.wav", try soundPath("weapons/ion/fire.wav", &buffer));
    try std.testing.expectEqualStrings("doors/e1/hydrolic2loop.wav", try soundPath("/doors/e1/hydrolic2loop.wav", &buffer));
    try std.testing.expectEqualStrings("doors/e1/hydrolic2loop.wav", try soundPath("\\Sounds\\doors\\e1\\hydrolic2loop.wav", &buffer));
}
