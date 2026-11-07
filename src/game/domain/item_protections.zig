// SPDX-License-Identifier: GPL-2.0-or-later
//! Class registry: saved item protection states and their checked validation policies.
const catalog = @import("item_catalog");
pub const classes = .{catalog.antidote};
pub const State = struct {
    antidote: catalog.antidote.State = .{},
};
