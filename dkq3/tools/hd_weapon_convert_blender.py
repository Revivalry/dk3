# SPDX-License-Identifier: GPL-2.0-or-later
"""Blender adapter: fit a generated hard-surface GLB to a captured Gold weapon.

This produces a static world-model candidate. It does not approve the geometry or
infer moving parts; first-person weapons require a separate articulated build.
"""
import argparse
import json
from pathlib import Path
import sys

import bpy
import numpy as np
from mathutils import Vector

sys.path.insert(0, str(Path(__file__).resolve().parent))
import iqm


def principal(points):
    center = points.mean(axis=0)
    centered = points-center
    values, axes = np.linalg.eigh((centered.T @ centered) / (len(points)-1))
    order = np.argsort(values)[::-1]
    return center, values[order], axes[:, order]


def align(generated, source, requested=None):
    """PCA with all proper axis signs; use bidirectional point distance to rank."""
    gc, gv, ga = principal(generated)
    sc, sv, sa = principal(source)
    scale = float(np.sqrt(sv[0] / gv[0]))
    sample = generated[np.linspace(0, len(generated)-1, min(2048, len(generated)), dtype=int)]
    best = None
    for sx in (-1, 1):
        for sy in (-1, 1):
            for sz in (-1, 1):
                rotation = sa @ np.diag((sx, sy, sz)) @ ga.T
                if np.linalg.det(rotation) < 0:
                    continue
                if requested is not None and requested != (sx, sy, sz):
                    continue
                test = (sample-gc) @ rotation.T * scale + sc
                # Coarse source points are design/placement evidence only.
                d2 = ((source[:, None, :] - test[None, :, :]) ** 2).sum(axis=2)
                score = float(np.median(d2.min(axis=1)) + np.median(d2.min(axis=0)))
                if best is None or score < best[0]:
                    best = (score, rotation, (sx, sy, sz))
    if best is None:
        raise ValueError('requested principal-axis signs produce a mirrored model')
    return scale, best[1], gc, sc, best[0], best[2]


def base_color(obj, output):
    for material in obj.data.materials:
        if not material or not material.use_nodes:
            continue
        shader = next((node for node in material.node_tree.nodes if node.type == 'BSDF_PRINCIPLED'), None)
        if shader:
            for link in shader.inputs['Base Color'].links:
                if link.from_node.type == 'TEX_IMAGE' and link.from_node.image:
                    image = link.from_node.image
                    image.file_format = 'PNG'
                    output.parent.mkdir(parents=True, exist_ok=True)
                    image.save_render(str(output))
                    return
    raise ValueError('generated GLB has no base-color image')


def model_meshes(obj, scale, rotation, generated_center, source_center, material):
    """Split triangle stream at native IQM surface limits without changing UVs."""
    mesh = obj.data
    vertices = np.array([tuple(obj.matrix_world @ v.co) for v in mesh.vertices], dtype=float)
    positions = (vertices-generated_center) @ rotation.T * scale + source_center
    normals = np.array([tuple(obj.matrix_world.to_3x3() @ v.normal) for v in mesh.vertices], dtype=float) @ rotation.T
    normals /= np.maximum(np.linalg.norm(normals, axis=1, keepdims=True), 1e-9)
    uv_layer = mesh.uv_layers.active
    if uv_layer is None:
        raise ValueError('generated GLB lacks UV coordinates')
    chunks, points, nrm, uv, faces, remap = [], [], [], [], [], {}

    def flush():
        nonlocal points, nrm, uv, faces, remap
        if faces:
            chunks.append(iqm.Mesh(f'part_{len(chunks):03}', material, tuple(points), tuple(nrm), tuple(uv), tuple(faces)))
        points, nrm, uv, faces, remap = [], [], [], [], {}

    for polygon in mesh.polygons:
        if len(polygon.loop_indices) != 3:
            raise ValueError('triangulation did not produce triangles')
        corner = []
        for index in polygon.loop_indices:
            loop = mesh.loops[index]
            coord = tuple(float(x) for x in uv_layer.data[index].uv)
            key = (loop.vertex_index, coord)
            corner.append((key, loop.vertex_index, coord))
        new = sum(key not in remap for key, _, _ in corner)
        if len(points) + new >= 950 or len(faces) + 1 >= 1900:
            flush()
        tri = []
        for key, vertex, coord in corner:
            if key not in remap:
                remap[key] = len(points)
                points.append(tuple(positions[vertex]))
                nrm.append(tuple(normals[vertex]))
                uv.append((coord[0], 1-coord[1]))
            tri.append(remap[key])
        faces.append(tuple(tri))
    flush()
    return chunks


def convert(args):
    if args.out_iqm.exists() or args.out_texture.exists() or args.report.exists() or (args.preview and args.preview.exists()):
        raise ValueError('candidate output exists; use a new versioned path')
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(args.glb.resolve()))
    objects = [obj for obj in bpy.context.scene.objects if obj.type == 'MESH']
    if len(objects) != 1:
        raise ValueError('candidate GLB needs one reviewed mesh before part assembly')
    obj = objects[0]
    def reference_points(path, frame):
        source = np.load(path)
        references = [source[key][frame] for key in source.files if key.endswith('_points')]
        if not references:
            raise ValueError(f'{path}: no source points')
        return np.concatenate(references)
    reference = reference_points(args.source_npz, args.frame)
    generated = np.array([tuple(obj.matrix_world @ vertex.co) for vertex in obj.data.vertices])
    requested = None if args.signs == 'auto' else tuple(int(value) for value in args.signs.split(','))
    if requested is not None and (len(requested) != 3 or any(value not in (-1, 1) for value in requested)):
        raise ValueError('signs must be auto or three comma-separated +1/-1 values')
    scale, rotation, generated_center, source_center, score, signs = align(generated, reference, requested)
    if args.placement_source_npz:
        placement = reference_points(args.placement_source_npz, args.placement_frame)
        _, placement_values, _ = principal(placement)
        _, reference_values, _ = principal(reference)
        scale *= float(np.sqrt(placement_values[0] / reference_values[0]))
        source_center = placement.mean(axis=0)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.select_all(action='DESELECT')
    obj.select_set(True)
    triangulate = obj.modifiers.new('weapon triangles', 'TRIANGULATE')
    bpy.ops.object.modifier_apply(modifier=triangulate.name)
    if len(obj.data.polygons) > args.triangles:
        decimate = obj.modifiers.new('weapon runtime detail', 'DECIMATE')
        decimate.ratio = args.triangles / len(obj.data.polygons)
        bpy.ops.object.modifier_apply(modifier=decimate.name)
    meshes = model_meshes(obj, scale, rotation, generated_center, source_center, args.material)
    encoded = iqm.encode(meshes, args.frames)
    base_color(obj, args.out_texture)
    args.out_iqm.parent.mkdir(parents=True, exist_ok=True)
    args.out_iqm.write_bytes(encoded)
    if args.preview:
        from neural_monster_blender import studio
        original = np.array([tuple(obj.matrix_world @ vertex.co) for vertex in obj.data.vertices])
        fitted = (original-generated_center) @ rotation.T * scale + source_center
        obj.matrix_world.identity()
        obj.data.vertices.foreach_set('co', fitted.astype(np.float32).ravel())
        obj.data.update()
        scene, camera, center, extent = studio(fitted, 1024)
        camera.location = Vector(center) + Vector((3, -1.25, .65)) * extent
        camera.rotation_euler = (Vector(center)-camera.location).to_track_quat('-Z', 'Y').to_euler()
        args.preview.parent.mkdir(parents=True, exist_ok=True)
        scene.render.filepath = str(args.preview)
        bpy.ops.render.render(write_still=True)
    report = dict(format=1, glb=str(args.glb), source=str(args.source_npz),
                  placement_source=str(args.placement_source_npz) if args.placement_source_npz else None,
                  scale=scale, rotation=rotation.tolist(), source_center=source_center.tolist(),
                  generated_center=generated_center.tolist(), registration_score=score, principal_signs=signs,
                  triangles=sum(len(mesh.triangles) for mesh in meshes), surfaces=len(meshes),
                  acceptance='implemented; unverified')
    args.report.parent.mkdir(parents=True, exist_ok=True)
    args.report.write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps(report, indent=2))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--glb', type=Path, required=True)
    parser.add_argument('--source-npz', type=Path, required=True)
    parser.add_argument('--frame', type=int, required=True)
    parser.add_argument('--placement-source-npz', type=Path, help='separate world-model scale/center reference')
    parser.add_argument('--placement-frame', type=int, default=0)
    parser.add_argument('--out-iqm', type=Path, required=True)
    parser.add_argument('--out-texture', type=Path, required=True)
    parser.add_argument('--material', required=True)
    parser.add_argument('--report', type=Path, required=True)
    parser.add_argument('--preview', type=Path)
    parser.add_argument('--triangles', type=int, default=16000)
    parser.add_argument('--frames', type=int, default=1, help='repeat the static pose for the source .anim frame count')
    parser.add_argument('--signs', default='auto', help='PCA axis signs, e.g. 1,-1,-1, after visual review')
    args = parser.parse_args(sys.argv[sys.argv.index('--')+1:])
    if args.triangles < 500 or args.triangles > 36000:
        raise ValueError('runtime triangle target outside 500..36000')
    if not args.material.startswith('models/hd-weapons/'):
        raise ValueError('material outside HD weapon namespace')
    convert(args)


if __name__ == '__main__':
    main()
