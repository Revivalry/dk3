// SPDX-License-Identifier: GPL-2.0-or-later
//! Shared mechanism: capabilities a class policy declares for each kind it owns. Shared systems
//! read these instead of listing kinds; catalog.zig derives the capability predicates from them.
pub const Kind = @import("kinds.zig").Kind;
pub const Remains = @import("fragments.zig").Policy;
pub const Attack = enum {
    /// No sequenced attack: scripted, civilian, turret or class-specific combat.
    none,
    /// Ground combat through the shared ground-attack adapter.
    ground,
    /// Animation-sequenced attacks (fliers, bosses).
    sequence,
};
pub const Traits = struct {
    attack: Attack = .none,
    /// Plays the model's "hita"/"hitb" pain clips without sequenced attacks.
    pain_clips: bool = false,
    /// A harmless ambient creature (no threat or combat).
    ambient: bool = false,
    /// Lives in water and follows water routes.
    aquatic: bool = false,
    /// Walks on land and swims once submerged (the reference's DFL_AMPHIBIOUS creatures switch to
    /// MOVETYPE_SWIM in water): it never drowns, and dry land does not suffocate it.
    amphibious: bool = false,
    /// Flees rather than fights: bots treat it as an obstacle, never an enemy, and it gives no
    /// sight cry.
    bystander: bool = false,
    /// A party member: the player's environment rules apply, and it voices instead of crying out.
    party: bool = false,
    /// Hits draw no blood.
    bloodless: bool = false,
    /// How it notices threats.
    senses: Senses = .{},
    /// What its body breaks into, and when.
    remains: Remains = .{},
    /// How the player's sidekicks treat it (the reference's monster-type check): they fight it,
    /// always keep away from it, or refuse it while holding only a close-quarters weapon.
    sidekicks: enum { fight, avoid, refuse_melee } = .fight,
};
/// How a class notices threats (perception.zig).
pub const Senses = struct {
    /// Notice distance replacing the aidata sight range.
    range: ?f32 = null,
    /// Distances ignore height.
    level: bool = false,
    /// No view cone: it notices in every direction.
    all_round: bool = false,
};
pub const Class = struct { kind: Kind, traits: Traits = .{} };
