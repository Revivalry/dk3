// SPDX-License-Identifier: GPL-2.0-or-later
//! Shared mechanism: maps render tags to the client render-class adapters that draw them.
//! Never names a concrete class: classes plug in through checked contracts (docs/runtime-zig.md "Class contract").
//!
//! A general entity carries two tags: its body tag (`generic1`), naming what it is, and an
//! overlay tag (`time2`), naming a class's decoration on an actor. An adapter declares
//! `body_tag` and/or `overlay_tags`; every tag has one adapter. Hooks, all optional:
//!
//! | Hook | Default |
//! |---|---|
//! | `drawEffect(*Draw) !bool` (body tag) | nothing: true skips the model |
//! | `decorate(*Model) !void` (body or overlay tag) | the shared model look |
//! | `overlay(*Model) !void` (body or overlay tag) | nothing after the model |
//! | `inline_model: bool` (body tag) | false: a mover with this tag draws its brush model |
const std = @import("std");
const context = @import("context.zig");
pub const Draw = context.Draw;
pub const Model = context.Model;
pub const Counters = context.Counters;

const adapters = @import("../../../game/client/render_classes/classes.zig").adapters;
comptime {
    @setEvalBranchQuota(100_000);
    for (adapters, 0..) |A, i| for (0..i) |j| {
        const B = adapters[j];
        if (@hasDecl(A, "body_tag") and @hasDecl(B, "body_tag") and A.body_tag == B.body_tag) @compileError("render body tag drawn twice: " ++ @typeName(A));
        if (@hasDecl(A, "overlay_tags") and @hasDecl(B, "overlay_tags")) for (A.overlay_tags) |a| for (B.overlay_tags) |b| if (a == b) @compileError("render overlay tag drawn twice: " ++ @typeName(A));
    };
}
fn bodyOf(tag: i32) ?usize {
    inline for (adapters, 0..) |A, i| if (@hasDecl(A, "body_tag") and A.body_tag == tag) return i;
    return null;
}
fn overlayOf(tag: i32) ?usize {
    inline for (adapters, 0..) |A, i| if (@hasDecl(A, "overlay_tags")) for (A.overlay_tags) |owned| if (owned == tag) return i;
    return null;
}
/// Draws a general entity's effect; true when it has no model to draw.
pub fn drawEffect(draw: *Draw) !bool {
    switch (bodyOf(draw.entity.generic1) orelse return false) {
        inline 0...adapters.len - 1 => |i| return if (@hasDecl(adapters[i], "drawEffect")) adapters[i].drawEffect(draw) else false,
        else => unreachable,
    }
}
fn call(index: ?usize, comptime hook: []const u8, model: *Model) !void {
    switch (index orelse return) {
        inline 0...adapters.len - 1 => |i| if (@hasDecl(adapters[i], hook)) try @field(adapters[i], hook)(model),
        else => unreachable,
    }
}
/// The class looks of a general entity's model: its body's, then its overlay's.
pub fn decorate(model: *Model) !void {
    try call(bodyOf(model.draw.entity.generic1), "decorate", model);
    try call(overlayOf(model.draw.entity.time2), "decorate", model);
}
/// What classes draw after a general entity's model is in the scene.
pub fn overlay(model: *Model) !void {
    try call(overlayOf(model.draw.entity.time2), "overlay", model);
    try call(bodyOf(model.draw.entity.generic1), "overlay", model);
}
/// A mover whose body tag says it draws its brush model.
pub fn inlineModel(tag: i32) bool {
    switch (bodyOf(tag) orelse return false) {
        inline 0...adapters.len - 1 => |i| return @hasDecl(adapters[i], "inline_model") and adapters[i].inline_model,
        else => unreachable,
    }
}
