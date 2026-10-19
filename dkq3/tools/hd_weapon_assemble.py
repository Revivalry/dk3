# SPDX-License-Identifier: GPL-2.0-or-later
"""Assemble reviewed rigid weapon parts on the converted source frame timeline.

Each part is a static IQM fitted to the same source reference pose. Selected
Gold vertices determine rigid motion and must meet the declared RMS tolerance.
"""
import argparse
import json
from pathlib import Path
import zipfile

import numpy as np

import hd_weapons
import iqm
from neural_assets import read_md3
import skeletal_iqm as sk


def static_meshes(data):
    """Read arrays and surfaces from an already validated unrigged IQM."""
    hd_weapons.iqm(data)
    header = dict(zip((name for name, _ in iqm.HEADER_FIELDS), iqm.HEADER.unpack_from(data)))
    if header['num_joints'] or header['num_poses'] or header['num_framechannels']:
        raise ValueError('part input must be an unrigged IQM')

    def string(offset):
        start = header['ofs_text'] + offset
        return data[start:data.index(b'\0', start, header['ofs_text'] + header['num_text'])].decode('ascii')

    arrays = {}
    for index in range(header['num_vertexarrays']):
        kind, flags, fmt, width, offset = iqm.VERTEX_ARRAY.unpack_from(
            data, header['ofs_vertexarrays'] + index * iqm.VERTEX_ARRAY.size)
        if kind not in (0, 1, 2):
            continue
        if flags or fmt != iqm.FLOAT or width != {0: 3, 1: 2, 2: 3}[kind]:
            raise ValueError('unsupported static part vertex array')
        arrays[kind] = np.frombuffer(data, '<f4', count=header['num_vertexes'] * width,
                                     offset=offset).reshape(-1, width).copy()
    triangles = np.frombuffer(data, '<u4', count=header['num_triangles'] * 3,
                              offset=header['ofs_triangles']).reshape(-1, 3).copy()
    meshes = []
    for index in range(header['num_meshes']):
        name, material, *bounds = iqm.MESH.unpack_from(data, header['ofs_meshes'] + index * iqm.MESH.size)
        meshes.append((string(name), string(material), *bounds))
    return arrays, meshes, triangles


def rigid_fit(reference, current):
    """Proper rigid transform from paired source vertices, plus RMS residual."""
    if len(reference) < 3 or reference.shape != current.shape or not np.isfinite(reference).all() or not np.isfinite(current).all():
        raise ValueError('rigid motion needs at least three finite paired vertices')
    center_a, center_b = reference.mean(axis=0), current.mean(axis=0)
    a, b = reference - center_a, current - center_b
    if np.linalg.matrix_rank(a, tol=1e-5) < 2:
        raise ValueError('selected source vertices do not determine orientation')
    u, _, vt = np.linalg.svd(a.T @ b)
    correction = np.diag((1., 1., np.linalg.det(vt.T @ u.T)))
    rotation = vt.T @ correction @ u.T
    matrix = np.eye(4)
    matrix[:3, :3] = rotation
    matrix[:3, 3] = center_b - rotation @ center_a
    rms = float(np.sqrt(np.mean(np.sum((reference @ rotation.T + matrix[:3, 3] - current) ** 2, axis=1))))
    return matrix, rms


def marker_matrix(triangle):
    """An attachment joint from one source hardpoint triangle."""
    origin = triangle.mean(axis=0)
    x = triangle[1] - triangle[0]
    x /= np.linalg.norm(x)
    z = np.cross(x, triangle[2] - triangle[0])
    z /= np.linalg.norm(z)
    y = np.cross(z, x)
    matrix = np.eye(4)
    matrix[:3, :3] = np.column_stack((x, y, z))
    matrix[:3, 3] = origin
    if not np.isfinite(matrix).all():
        raise ValueError('degenerate source hardpoint')
    return matrix


def apply_authored_motion(transforms, definitions, clips):
    """Add reviewed part motion inside named Gold clip intervals only."""
    seen = set()
    summary = []
    for row in definitions:
        name = row['clip']
        if name in seen or name not in clips:
            raise ValueError(f'unknown or duplicate authored weapon clip: {name}')
        seen.add(name)
        clip = clips[name]
        first, last = int(clip['first']), int(clip['last'])
        if first < 0 or last >= len(transforms) or last <= first:
            raise ValueError(f'{name}: source clip interval outside assembled frames')
        keys = row['keys']
        if not isinstance(keys, list) or len(keys) < 2:
            raise ValueError(f'{name}: motion needs at least two keys')
        indices = [int(key['frame']) for key in keys]
        if indices[0] != 0 or indices[-1] != last-first or indices != sorted(set(indices)):
            raise ValueError(f'{name}: keys must span the source clip in frame order')
        translations = np.asarray([key.get('translation', [0., 0., 0.]) for key in keys], dtype=float)
        angles = np.asarray([key.get('angle_degrees', 0.) for key in keys], dtype=float)
        if translations.shape != (len(keys), 3) or not np.isfinite(translations).all() or not np.isfinite(angles).all():
            raise ValueError(f'{name}: nonfinite authored motion')
        if np.linalg.norm(translations[[0, -1]], axis=1).max() > 1e-6 or np.abs(angles[[0, -1]]).max() > 1e-6:
            raise ValueError(f'{name}: motion must start and end at the source pose')
        move_limit = float(row['max_translation'])
        turn_limit = float(row.get('max_angle_degrees', 0.))
        if not np.isfinite(move_limit) or not np.isfinite(turn_limit) or move_limit < 0 or turn_limit < 0 or (
                np.linalg.norm(translations, axis=1).max() > move_limit or np.abs(angles).max() > turn_limit):
            raise ValueError(f'{name}: authored motion exceeds declared translation or angle limit')
        axis = np.asarray(row.get('axis', [0., 0., 1.]), dtype=float)
        pivot = np.asarray(row.get('pivot', [0., 0., 0.]), dtype=float)
        if axis.shape != (3,) or pivot.shape != (3,) or not np.isfinite(axis).all() or not np.isfinite(pivot).all() or np.linalg.norm(axis) < 1e-6:
            raise ValueError(f'{name}: invalid authored rotation axis or pivot')
        axis /= np.linalg.norm(axis)
        for local in range(last-first+1):
            translation = np.array([np.interp(local, indices, translations[:, component]) for component in range(3)])
            angle = np.deg2rad(np.interp(local, indices, angles))
            x, y, z = axis
            cross = np.array([[0., -z, y], [z, 0., -x], [-y, x, 0.]])
            rotation = np.eye(3) + np.sin(angle)*cross + (1-np.cos(angle))*(cross @ cross)
            additive = np.eye(4)
            additive[:3, :3] = rotation
            additive[:3, 3] = pivot - rotation @ pivot + translation
            transforms[first+local] = transforms[first+local] @ additive
        summary.append(dict(clip=name, first=first, last=last,
                            max_translation=float(np.linalg.norm(translations, axis=1).max()),
                            max_angle_degrees=float(np.abs(angles).max())))
    return summary


def assemble(manifest_path, base, output, report):
    manifest = json.loads(manifest_path.read_text())
    source, parts = manifest.get('source'), manifest.get('parts')
    if manifest.get('format') != 1 or source not in hd_weapons.source_paths() or not isinstance(parts, list) or not parts:
        raise ValueError('invalid weapon assembly manifest')
    if output.exists() or report.exists():
        raise ValueError('assembly output exists; use a new versioned path')
    with zipfile.ZipFile(base) as archive:
        original, _ = read_md3(archive.read(source + '.md3'))
        source_frames = len(original[0]['points'])
        hardpoints = {mesh['name']: mesh['points'] for mesh in original
                      if mesh['name'] in ('hr_muzzle', 'fire') and len(mesh['points'][0]) == 3}
        sidecar = source + '.anim'
        if sidecar in archive.namelist() and source_frames != hd_weapons.animation_count(archive.read(sidecar)):
            raise ValueError('source MD3 and animation sidecar frame counts differ')
        metadata = json.loads(archive.read(source + '.json')) if source + '.json' in archive.namelist() else None
        clips = {clip['animation_name']: clip for clip in metadata['sequences']['frame_data']} if metadata else {}
    reference_frame = int(manifest['reference_frame'])
    if not 0 <= reference_frame < source_frames:
        raise ValueError('reference_frame outside source animation')
    names, parents, bind, motions, statistics = [], [], [], [], []
    geometry = {0: [], 1: [], 2: [], 4: [], 5: []}
    meshes, faces = [], []
    for part in parts:
        name = part['name']
        if not name.isascii() or not name.replace('_', '').isalnum() or name in names or name in hardpoints:
            raise ValueError(f'invalid or duplicate part name: {name}')
        arrays, surfaces, triangles = static_meshes((manifest_path.parent / part['model']).read_bytes())
        with np.load(manifest_path.parent / part['source_points']) as source_npz:
            points = source_npz[f"{int(part.get('surface', 0))}_points"]
        if len(points) != source_frames:
            raise ValueError(f'{name}: source part frame count differs')
        selection = np.asarray(part.get('vertices', list(range(points.shape[1]))), dtype=int)
        if len(selection) < 3 or selection.min() < 0 or selection.max() >= points.shape[1]:
            raise ValueError(f'{name}: invalid source vertex selection')
        reference = points[reference_frame, selection]
        transforms, residuals = [], []
        for frame in points[:, selection]:
            transform, rms = rigid_fit(reference, frame)
            transforms.append(transform)
            residuals.append(rms)
        maximum = float(max(residuals))
        limit = float(part.get('max_rms', 0.5))
        if not np.isfinite(limit) or limit < 0 or maximum > limit:
            raise ValueError(f'{name}: nonrigid source selection RMS {maximum:.4f} exceeds {limit:.4f}')
        transforms = np.stack(transforms)
        authored = part.get('authored_motion', [])
        if not isinstance(authored, list):
            raise ValueError(f'{name}: authored_motion must be a list')
        authored_summary = apply_authored_motion(transforms, authored, clips)
        anchor_shift = 0.
        constrained_rms = maximum
        if 'anchor_to' in part:
            target = part['anchor_to']
            if target not in names or 'anchor_point' not in part or 'max_anchor_shift' not in part:
                raise ValueError(f'{name}: anchor needs an earlier part, point and shift limit')
            point = np.asarray(part['anchor_point'], dtype=float)
            shift_limit = float(part['max_anchor_shift'])
            if point.shape != (3,) or not np.isfinite(point).all() or not np.isfinite(shift_limit) or shift_limit < 0:
                raise ValueError(f'{name}: invalid anchor point or shift limit')
            parent_motion = motions[names.index(target)]
            desired = parent_motion[:, :3, :3] @ point + parent_motion[:, :3, 3]
            actual = transforms[:, :3, :3] @ point + transforms[:, :3, 3]
            correction = desired - actual
            anchor_shift = float(np.linalg.norm(correction, axis=1).max())
            if anchor_shift > shift_limit:
                raise ValueError(f'{name}: anchor shift {anchor_shift:.4f} exceeds {shift_limit:.4f}')
            transforms[:, :3, 3] += correction
            fitted = np.einsum('fij,vj->fvi', transforms[:, :3, :3], reference) + transforms[:, None, :3, 3]
            constrained_rms = float(np.sqrt(np.mean(np.sum((fitted - points[:, selection]) ** 2, axis=2), axis=1)).max())
        joint = len(names)
        names.append(name)
        parents.append(-1)
        bind.append(np.eye(4))
        motions.append(transforms)
        first_vertex, first_triangle = len(geometry[0]), len(faces)
        for kind in (0, 1, 2):
            geometry[kind].extend(arrays[kind])
        geometry[4].extend([[joint, 0, 0, 0]] * len(arrays[0]))
        geometry[5].extend([[255, 0, 0, 0]] * len(arrays[0]))
        faces.extend((triangles + first_vertex).tolist())
        for surface_name, material, fv, nv, ft, nt in surfaces:
            meshes.append((f'{name}_{surface_name}', material, first_vertex + fv, nv,
                           first_triangle + ft, nt))
        statistics.append(dict(name=name, source_vertices=len(selection), max_rms=maximum,
                               max_constrained_rms=constrained_rms, max_anchor_shift=anchor_shift,
                               authored_motion=authored_summary,
                               triangles=len(triangles), surfaces=len(surfaces)))
    for name, points in hardpoints.items():
        names.append(name)
        parents.append(-1)
        marker = np.stack([marker_matrix(frame.copy()) for frame in points])
        bind.append(marker[reference_frame])
        motions.append(marker)
    if len(names) > 128:
        raise ValueError('weapon has more than 128 part and attachment joints')
    arrays = {kind: np.asarray(values, dtype='u1' if kind in (4, 5) else float)
              for kind, values in geometry.items()}
    matrices = np.stack(motions, axis=1)
    skeleton = sk.Model(arrays, meshes, np.asarray(faces, dtype=np.uint32), names, parents,
                        sk.channels(np.stack(bind), parents), sk.channels(matrices, parents))
    encoded = sk.write(skeleton)
    if hd_weapons.iqm(encoded)[0] != source_frames:
        raise ValueError('assembled IQM frame count differs from source')
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_bytes(encoded)
    result = dict(format=1, source=source, frames=source_frames, reference_frame=reference_frame,
                  parts=statistics, hardpoints=list(hardpoints), triangles=len(faces),
                  acceptance='implemented; unverified')
    report.parent.mkdir(parents=True, exist_ok=True)
    report.write_text(json.dumps(result, indent=2) + '\n')
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--manifest', type=Path, required=True)
    parser.add_argument('--base-models', type=Path, required=True)
    parser.add_argument('--out-iqm', type=Path, required=True)
    parser.add_argument('--report', type=Path, required=True)
    args = parser.parse_args()
    print(json.dumps(assemble(args.manifest, args.base_models, args.out_iqm, args.report), indent=2))


if __name__ == '__main__':
    main()
