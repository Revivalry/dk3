#version 460
// SPDX-License-Identifier: GPL-2.0-or-later
// Depth pre-pass (scene.zig `depthPrepass`): stage.vert places the surface; only depth is
// written, so the shading pass runs its lighting once per visible pixel.
void main() {}
