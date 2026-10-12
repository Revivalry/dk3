// SPDX-License-Identifier: GPL-2.0-or-later
//! Shared mechanism: the fading overlay (an actor drawn translucent as it appears or vanishes).
//! Classes set `fade_tag` as their overlay tag; the client's fade render class draws it.
pub const fade_tag = 10026;
