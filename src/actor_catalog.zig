// SPDX-License-Identifier: GPL-2.0-or-later
//! Class registry: the actor class policies, the kinds they own, and the frozen save order of
//! actor classnames. Holds no behaviour: classes declare their traits, tuning and definitions.
test "actor presentation owners have distinct render tags" {
    const std = @import("std");
    const declarations = comptime std.meta.declarations(@This());
    inline for (declarations, 0..) |declaration, index| {
        const owner = @field(@This(), declaration.name);
        if (@TypeOf(owner) == type) {
            if (@typeInfo(owner) == .@"struct" and @hasDecl(owner, "render_tag")) {
                inline for (declarations[0..index]) |earlier| {
                    const other = @field(@This(), earlier.name);
                    if (@TypeOf(other) == type) {
                        if (@typeInfo(other) == .@"struct" and @hasDecl(other, "render_tag")) {
                            if (owner.render_tag == other.render_tag) std.debug.print("Duplicate actor render tag: {s} / {s}\n", .{ declaration.name, earlier.name });
                            try std.testing.expect(owner.render_tag != other.render_tag);
                        }
                    }
                }
            }
        }
    }
}
pub const melee_cycle = @import("mechanics/policy/actors/melee_cycle.zig");
pub const ragemaster = @import("classes/actors/ragemaster/ragemaster.zig");
pub const skeleton = @import("classes/actors/skeleton/skeleton.zig");
pub const thief = @import("classes/actors/thief/thief.zig");
pub const prisoners = @import("classes/actors/prisoners/prisoners.zig");
pub const femgang = @import("classes/actors/femgang/femgang.zig");
pub const evasion = @import("mechanics/policy/actors/evasion.zig");
pub const cover = @import("mechanics/policy/actors/cover.zig");
pub const fade = @import("mechanics/policy/actors/fade.zig");
pub const hide_voice = @import("mechanics/policy/actors/hide_voice.zig");
pub const thrown_range = @import("mechanics/policy/actors/thrown_range.zig");
pub const venom_spit = @import("mechanics/policy/actors/venom_spit.zig");
pub const bursts = @import("mechanics/policy/actors/bursts.zig");
pub const glow_particle = @import("mechanics/policy/actors/glow_particle.zig");
pub const energy_swarm = @import("mechanics/policy/actors/energy_swarm.zig");
pub const wisp_lightning = @import("mechanics/policy/actors/wisp_lightning.zig");
pub const spawnflags = @import("mechanics/policy/actors/spawnflags.zig");
pub const difficulty = @import("mechanics/policy/actors/difficulty.zig");
pub const rocketmp = @import("classes/actors/rocketmp/rocketmp.zig");
pub const battleboar = @import("classes/actors/battleboar/battleboar.zig");
pub const rocketgang = @import("classes/actors/rocketgang/rocketgang.zig");
pub const missiles = @import("mechanics/policy/actors/missiles.zig");
pub const shafts = @import("mechanics/policy/actors/shafts.zig");
pub const archers = @import("classes/actors/archers/archers.zig");
pub const doombat = @import("classes/actors/doombat/doombat.zig");
pub const griffon = @import("classes/actors/griffon/griffon.zig");
pub const harpy = @import("classes/actors/harpy/harpy.zig");
pub const dragon = @import("classes/actors/dragon/dragon.zig");
pub const garroth = @import("classes/actors/garroth/garroth.zig");
pub const medusa = @import("classes/actors/medusa/medusa.zig");
pub const nharre = @import("classes/actors/nharre/nharre.zig");
pub const kage = @import("classes/actors/kage/kage.zig");
pub const ghost = @import("classes/actors/ghost/ghost.zig");
pub const summon_effect = @import("mechanics/policy/actors/summon_effect.zig");
pub const mikiko = @import("classes/actors/mikiko/mikiko.zig");
pub const sword_aura_tag = 10023;
pub const stavros = @import("classes/actors/stavros/stavros.zig");
pub const meteors = @import("mechanics/policy/actors/meteors.zig");
pub const wyndrax = @import("classes/actors/wyndrax/wyndrax.zig");
pub const wisp = @import("classes/actors/wisp/wisp.zig");
pub const buboid = @import("classes/actors/buboid/buboid.zig");
pub const chaingang = @import("classes/actors/chaingang/chaingang.zig");
pub const deathsphere = @import("classes/actors/deathsphere/deathsphere.zig");
pub const fireballs = @import("mechanics/policy/actors/fireballs.zig");
pub const psyclaw = @import("classes/actors/psyclaw/psyclaw.zig");
pub const gunners = @import("classes/actors/gunners/gunners.zig");
pub const sludge = @import("classes/actors/sludge/sludge.zig");
pub const rotworm = @import("classes/actors/rotworm/rotworm.zig");
pub const vermin = @import("classes/actors/vermin/vermin.zig");
pub const fish = @import("classes/actors/fish/fish.zig");
pub const seagull = @import("classes/actors/seagull/seagull.zig");
pub const shark = @import("classes/actors/shark/shark.zig");
pub const wander = @import("mechanics/policy/actors/wander.zig");
pub const weapon = @import("mechanics/policy/actors/weapon.zig");
pub const cerberus = @import("classes/actors/cerberus/cerberus.zig");
pub const rats = @import("classes/actors/rats/rats.zig");
pub const knights = @import("classes/actors/knights/knights.zig");
pub const laser = @import("mechanics/policy/actors/laser.zig");
pub const inmater = @import("classes/actors/inmater/inmater.zig");
pub const lasergat = @import("classes/actors/lasergat/lasergat.zig");
pub const labmonkey = @import("classes/actors/labmonkey/labmonkey.zig");
pub const surgeon = @import("classes/actors/surgeon/surgeon.zig");
pub const cryotech = @import("classes/actors/cryotech/cryotech.zig");
pub const spider = @import("classes/actors/spider/spider.zig");
pub const firefly = @import("classes/actors/firefly/firefly.zig");
pub const lycanthir = @import("classes/actors/lycanthir/lycanthir.zig");
pub const dwarf = @import("classes/actors/dwarf/dwarf.zig");
pub const satyr = @import("classes/actors/satyr/satyr.zig");
pub const column = @import("classes/actors/column/column.zig");
pub const companions = @import("classes/actors/companions/companions.zig");
pub const mishima = @import("classes/actors/mishima_guard/mishima_guard.zig");
pub const protopod = @import("classes/actors/protopod/protopod.zig");
pub const perception = @import("mechanics/policy/actors/perception.zig");
pub const fragments = @import("mechanics/policy/actors/fragments.zig");
pub const skeeter = @import("classes/actors/skeeter/skeeter.zig");
pub const froginator = @import("classes/actors/froginator/froginator.zig");
pub const thunderskeet = @import("classes/actors/thunderskeet/thunderskeet.zig");
pub const rockgat = @import("classes/actors/rockgat/rockgat.zig");
pub const crox = @import("classes/actors/crox/crox.zig");
pub const cambot = @import("classes/actors/cambot/cambot.zig");
pub const civilians = @import("classes/actors/civilians/civilians.zig");
pub const saved_time = @import("mechanics/policy/actors/saved_time.zig");
pub const Kind = @import("mechanics/policy/actors/kinds.zig").Kind;
pub const Traits = @import("mechanics/policy/actors/traits.zig").Traits;
/// Policies that own kinds, in no particular order. Every kind has exactly one owner.
pub const policies = owners;
const owners = .{ civilians, mishima, protopod, skeeter, froginator, thunderskeet, cambot, crox, rockgat, companions, ragemaster, skeleton, satyr, column, dwarf, lycanthir, spider, cryotech, surgeon, labmonkey, inmater, lasergat, knights, cerberus, rats, shark, vermin, rotworm, archers, battleboar, rocketgang, rocketmp, thief, prisoners, femgang, sludge, gunners, psyclaw, doombat, griffon, harpy, dragon, deathsphere, chaingang, buboid, wyndrax, garroth, stavros, mikiko, medusa, kage, ghost, nharre, fish, seagull };
/// The traits each kind's owning policy declares, indexed by kind.
pub const traits_of: [@typeInfo(Kind).@"enum".fields.len]Traits = blk: {
    var table: [@typeInfo(Kind).@"enum".fields.len]?Traits = @splat(null);
    for (owners) |policy| for (policy.classes) |class| {
        if (table[@intFromEnum(class.kind)] != null) @compileError("actor kind owned twice: " ++ @tagName(class.kind));
        table[@intFromEnum(class.kind)] = class.traits;
    };
    var result: [table.len]Traits = undefined;
    for (table, 0..) |entry, index| result[index] = entry orelse @compileError("actor kind without an owning policy: " ++ @tagName(@as(Kind, @enumFromInt(index))));
    break :blk result;
};
pub fn traitsOf(kind: Kind) Traits {
    return traits_of[@intFromEnum(kind)];
}
pub fn sequenceAttack(kind: Kind) bool {
    return traitsOf(kind).attack != .none;
}
/// Classes whose pain reaction plays the model's "hita"/"hitb" clips.
pub fn painAnimation(kind: Kind) bool {
    return sequenceAttack(kind) or traitsOf(kind).pain_clips;
}
pub fn ambient(kind: Kind) bool {
    return traitsOf(kind).ambient;
}
pub fn aquatic(kind: Kind) bool {
    return traitsOf(kind).aquatic;
}
pub fn groundAttack(kind: Kind) bool {
    return traitsOf(kind).attack == .ground;
}

/// Index into `owners` of each kind's policy.
const owner_of: [@typeInfo(Kind).@"enum".fields.len]u8 = blk: {
    var table: [@typeInfo(Kind).@"enum".fields.len]u8 = undefined;
    for (owners, 0..) |policy, index| for (policy.classes) |class| {
        table[@intFromEnum(class.kind)] = index;
    };
    break :blk table;
};

/// Class aidata tuning beyond the shared columns, one variant per policy that declares a
/// `ClassTuning` type. A definition holds its own class's variant; read it with `tuningOf`.
pub const ClassTuning = blk: {
    var count: usize = 1;
    for (owners) |policy| {
        if (@hasDecl(policy, "ClassTuning")) count += 1;
    }
    var names: [count][]const u8 = undefined;
    var types: [count]type = undefined;
    var values: [count]u8 = undefined;
    names[0] = "none";
    types[0] = void;
    values[0] = 0;
    var index: usize = 1;
    for (owners) |policy| if (@hasDecl(policy, "ClassTuning")) {
        names[index] = @typeName(policy);
        types[index] = policy.ClassTuning;
        values[index] = index;
        index += 1;
    };
    break :blk @Union(.auto, @Enum(u8, .exhaustive, &names, &values), &names, &types, &@splat(.{}));
};
pub fn tuningOf(comptime Policy: type, tuning: *const ClassTuning) *const Policy.ClassTuning {
    return &@field(tuning, @typeName(Policy));
}
/// False for a class that reads only its model from aidata (`shared_tuning = false`); its
/// `parseTuning` then supplies every value.
pub fn sharedTuning(kind: Kind) bool {
    switch (owner_of[@intFromEnum(kind)]) {
        inline 0...owners.len - 1 => |index| {
            const policy = owners[index];
            return if (@hasDecl(policy, "shared_tuning")) policy.shared_tuning else true;
        },
        else => unreachable,
    }
}
/// Runs the owning policy's `parseTuning(row, kind, definition)` over one aidata row after the
/// shared columns. It may override shared values; a policy with `ClassTuning` returns its
/// variant, stored in `definition.class`.
pub fn parseTuning(kind: Kind, row: anytype, definition: anytype) !void {
    switch (owner_of[@intFromEnum(kind)]) {
        inline 0...owners.len - 1 => |index| {
            const policy = owners[index];
            if (!@hasDecl(policy, "parseTuning")) {
                if (@hasDecl(policy, "ClassTuning")) definition.class = @unionInit(ClassTuning, @typeName(policy), .{});
                return;
            }
            if (@hasDecl(policy, "ClassTuning")) {
                definition.class = @unionInit(ClassTuning, @typeName(policy), try policy.parseTuning(row, kind, definition));
            } else try policy.parseTuning(row, kind, definition);
        },
        else => unreachable,
    }
}
pub const Definition = @import("mechanics/policy/actors/definition.zig").Definition;
/// Save ABI: a saved actor stores its index in `entries`, which follows this order. Append only;
/// never reorder or remove.
const save_order = [_][]const u8{
    "monster_skinnyworker",
    "monster_fatworker",
    "monster_prisoner",
    "monster_prisonerb",
    "monster_mishimaguard",
    "monster_protopod",
    "monster_slaughterskeet",
    "monster_froginator",
    "monster_thunderskeet",
    "monster_cambot",
    "monster_crox",
    "monster_rockgat",
    "mikiko",
    "superfly",
    "mikikofly",
    "monster_ragemaster",
    "monster_skeleton",
    "monster_satyr",
    "monster_column",
    "monster_dwarf",
    "monster_lycanthir",
    "monster_spider",
    "monster_smallspider",
    "monster_cryotech",
    "monster_surgeon",
    "monster_labmonkey",
    "monster_inmater",
    "monster_lasergat",
    "monster_knight1",
    "monster_knight2",
    "monster_cerberus",
    "monster_piperat",
    "monster_plague_rat",
    "monster_shark",
    "monster_venomvermin",
    "monster_rotworm",
    "monster_centurion",
    "monster_fletcher",
    "monster_battleboar",
    "monster_rocketdude",
    "monster_rocketmp",
    "monster_thief",
    "monster_blackprisoner",
    "monster_whiteprisoner",
    "monster_femgang",
    "monster_sludgeminion",
    "monster_sealcaptain",
    "monster_sealcommando",
    "monster_sealgirl",
    "monster_uzigang",
    "monster_psyclaw",
    "monster_doombat",
    "monster_griffon",
    "monster_harpy",
    "monster_dragon",
    "monster_deathsphere",
    "monster_chaingang",
    "monster_buboid",
    "monster_wyndrax",
    "monster_garroth",
    "monster_stavros",
    "monster_mikiko",
    "monster_medusa",
    "monster_kage",
    "monster_ghost",
    "monster_nharre",
    "e_goldfish",
    "e_greyfish",
    "e_guppy",
    "e_guppy2",
    "e_dopefish",
    "e_seagull",
};
/// Every actor classname's definition, in save order, gathered from the owning policies.
pub const entries = blk: {
    @setEvalBranchQuota(200_000);
    var result: [save_order.len]Definition = undefined;
    for (save_order, 0..) |classname, index| {
        var found: ?Definition = null;
        for (owners) |policy| if (@hasDecl(policy, "definitions")) for (policy.definitions) |definition| {
            if (!eql(definition.classname, classname)) continue;
            if (found != null) @compileError("actor classname defined twice: " ++ classname);
            found = definition;
        };
        result[index] = found orelse @compileError("actor classname without a definition: " ++ classname);
    }
    for (owners) |policy| if (@hasDecl(policy, "definitions")) for (policy.definitions) |definition| {
        for (save_order) |classname| {
            if (eql(definition.classname, classname)) break;
        } else @compileError("actor classname missing from the save order: " ++ definition.classname);
    };
    break :blk result;
};
fn eql(a: []const u8, b: []const u8) bool {
    if (a.len != b.len) return false;
    for (a, b) |x, y| if (x != y) return false;
    return true;
}

pub fn find(name: []const u8) ?u8 {
    for (entries, 0..) |entry, i| if (@import("std").mem.eql(u8, name, entry.classname)) return @intCast(i);
    const aliases = .{
        .{ "fish_goldfish", "e_goldfish" }, .{ "goldfish", "e_goldfish" },
        .{ "fish_grayfish", "e_greyfish" }, .{ "e_grayfish", "e_greyfish" },
        .{ "fish_guppy1", "e_guppy" },      .{ "fish_guppy2", "e_guppy2" },
        .{ "fish_dopefish", "e_dopefish" },
    };
    inline for (aliases) |alias| if (@import("std").mem.eql(u8, name, alias[0])) return find(alias[1]);
    return null;
}

test "map fish aliases resolve to the supplied class tuning without becoming hostile wildlife" {
    const t = @import("std").testing;
    try t.expectEqual(find("e_greyfish").?, find("fish_grayfish").?);
    try t.expectEqual(find("e_guppy").?, find("fish_guppy1").?);
    try t.expect(ambient(entries[find("fish_goldfish").?].kind));
    try t.expect(ambient(entries[find("e_seagull").?].kind));
    try t.expect(!ambient(entries[find("fish_dopefish").?].kind));
    try t.expect(groundAttack(entries[find("fish_dopefish").?].kind));
}

test {
    _ = civilians.workers;
    _ = hide_voice;
    _ = thrown_range;
    _ = venom_spit;
    _ = bursts;
    _ = glow_particle;
    _ = energy_swarm;
    _ = wisp_lightning;
    _ = fish;
    _ = seagull;
    _ = nharre;
    _ = kage;
    _ = ghost;
    _ = summon_effect;
    _ = mishima;
    _ = protopod;
    _ = skeeter;
    _ = froginator;
    _ = thunderskeet;
    _ = cambot;
    _ = crox;
    _ = rockgat;
    _ = melee_cycle;
    _ = ragemaster;
    _ = skeleton;
    _ = satyr;
    _ = dwarf;
    _ = lycanthir;
    _ = spider;
    _ = cryotech;
    _ = surgeon;
    _ = labmonkey;
    _ = inmater;
    _ = lasergat;
    _ = laser;
    _ = knights;
    _ = cerberus;
    _ = rats;
    _ = shark;
    _ = vermin;
    _ = rotworm;
    _ = sludge;
    _ = gunners;
    _ = psyclaw;
    _ = fireballs;
    _ = doombat;
    _ = griffon;
    _ = harpy;
    _ = dragon;
    _ = deathsphere;
    _ = chaingang;
    _ = buboid;
    _ = wisp;
    _ = wyndrax;
    _ = garroth;
    _ = stavros;
    _ = mikiko;
    _ = medusa;
    _ = meteors;
    _ = archers;
    _ = missiles;
    _ = battleboar;
    _ = rocketgang;
    _ = rocketmp;
    _ = evasion;
    _ = thief;
    _ = prisoners;
    _ = femgang;
    _ = wander;
    _ = firefly;
    _ = column;
    _ = companions;
}

test "declared class traits reproduce the reviewed capability lists" {
    const std = @import("std");
    const ground = [_]Kind{ .ragemaster, .skeleton, .satyr, .column, .dwarf, .lycanthir, .spider, .smallspider, .cryotech, .labmonkey, .inmater, .lasergat, .knight1, .knight2, .cerberus, .piperat, .plague_rat, .shark, .dopefish, .venomvermin, .rotworm, .centurion, .fletcher, .battleboar, .rocketdude, .rocketmp, .thief, .blackprisoner, .whiteprisoner, .femgang, .sludgeminion, .sealcaptain, .sealcommando, .sealgirl, .uzigang, .psyclaw };
    const sequence = [_]Kind{ .doombat, .griffon, .harpy, .dragon, .deathsphere, .chaingang, .buboid, .wyndrax, .garroth, .stavros, .mikiko, .medusa, .kage, .ghost, .nharre };
    for (std.enums.values(Kind)) |kind| {
        const is_ground = std.mem.indexOfScalar(Kind, &ground, kind) != null;
        const is_sequence = is_ground or std.mem.indexOfScalar(Kind, &sequence, kind) != null;
        try std.testing.expectEqual(is_ground, groundAttack(kind));
        try std.testing.expectEqual(is_sequence, sequenceAttack(kind));
        const own_pain = [_]Kind{ .mishima_guard, .froginator, .skeeter, .thunderskeet, .crox };
        try std.testing.expectEqual(is_sequence or std.mem.indexOfScalar(Kind, &own_pain, kind) != null, painAnimation(kind));
        try std.testing.expectEqual(kind == .fish or kind == .seagull, ambient(kind));
        try std.testing.expectEqual(kind == .shark or kind == .fish or kind == .dopefish, aquatic(kind));
        try std.testing.expectEqual(kind == .crox or kind == .froginator or kind == .piperat or kind == .plague_rat, traitsOf(kind).amphibious);
    }
}
