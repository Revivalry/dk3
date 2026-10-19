# SPDX-License-Identifier: GPL-2.0-or-later
"""Render assembled IQM frames with their actual per-part materials for review."""
import argparse
from pathlib import Path
import sys

import bpy
import numpy as np
from mathutils import Vector

sys.path.insert(0, str(Path(__file__).resolve().parent))
import skeletal_iqm as sk
from neural_monster_blender import studio, surface


def render(model_path, art, frames, output):
    model = sk.read(model_path.read_bytes())
    for frame in frames:
        if not 0 <= frame < len(model.frames):
            raise ValueError(f'frame {frame} is outside the assembled weapon')
        if (output / f'frame-{frame:03}.png').exists():
            raise ValueError('review render already exists; use a new versioned path')
    bpy.ops.wm.read_factory_settings(use_empty=True)
    parts = []
    for name, material, first_vertex, vertex_count, first_triangle, triangle_count in model.meshes:
        points = model.arrays[0][first_vertex:first_vertex + vertex_count]
        triangles = model.triangles[first_triangle:first_triangle + triangle_count] - first_vertex
        uv = model.arrays[1][first_vertex:first_vertex + vertex_count]
        obj = surface(name, points, triangles[:, [0, 2, 1]], uv, art / (material + '.png'))
        for polygon in obj.data.polygons:
            polygon.use_smooth = True
        parts.append((obj, first_vertex, vertex_count))
    scene, camera, center, extent = studio(model.arrays[0], resolution=1024)
    camera.location = Vector(center) + Vector((3, -1.25, .65)) * extent
    camera.rotation_euler = (Vector(center) - camera.location).to_track_quat('-Z', 'Y').to_euler()
    output.mkdir(parents=True, exist_ok=True)
    for frame in frames:
        positions = sk.skin(model, model.frames[frame:frame + 1])[0]
        for obj, first, count in parts:
            obj.data.vertices.foreach_set('co', positions[first:first + count].astype(np.float32).ravel())
            obj.data.update()
        scene.render.filepath = str(output / f'frame-{frame:03}.png')
        bpy.ops.render.render(write_still=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--iqm', type=Path, required=True)
    parser.add_argument('--art', type=Path, required=True)
    parser.add_argument('--frames', required=True, help='comma-separated source frame indices')
    parser.add_argument('--out', type=Path, required=True)
    args = parser.parse_args(sys.argv[sys.argv.index('--') + 1:])
    render(args.iqm.resolve(), args.art.resolve(), [int(value) for value in args.frames.split(',')], args.out.resolve())


if __name__ == '__main__':
    main()
