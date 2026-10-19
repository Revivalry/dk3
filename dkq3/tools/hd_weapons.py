#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-or-later
"""Inventory and admit locally authored HD weapon IQMs into a cosmetic PK3.

An admission JSON contains {"format": 1, "models": [{"source": ...,
"target": ..., "review": "accepted", "evidence": "reviews/...png"}]}.
The target and its material PNGs live at their package paths below --art.
Review evidence remains local; its hash is recorded in the package receipt.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re
import struct
import subprocess
import zipfile

from neural_package import classic_archive, require_classic_directory

ROOT = Path(__file__).resolve().parents[2]
MAPPING = 'dk3/hd-weapon-models.cfg'
RECEIPT = 'dk3/hd-weapons.json'
MODEL_PREFIX = 'models/hd-weapons/'
HEADER = struct.Struct('<16s27I')
MESH = struct.Struct('<6I')
JOINT = struct.Struct('<Ii10f')
VERTEX_ARRAY = struct.Struct('<5I')


def digest(data):
    return hashlib.sha256(data).hexdigest()


def roster(root=ROOT):
    """Read class-owned source paths in registry order; no second weapon table."""
    registry = (root / 'src/game/weapons/classes.zig').read_text()
    rows = []
    for name, relative in re.findall(r'pub const (\w+) = @import\("(../../classes/weapons/[^\"]+\.zig)"\);', registry):
        source = (root / 'src/game/weapons' / relative).resolve().read_text()
        view = re.search(r'\.view_model\s*=\s*"([^"]+)"', source)
        world = re.search(r'\.world_model\s*=\s*"([^"]+)"', source)
        if not view:
            raise ValueError(f'{name}: missing view_model')
        rows.append(dict(class_name=name, view=view.group(1), world=world.group(1) if world else None))
    if len(rows) != 28:
        raise ValueError(f'expected 28 registered weapons, found {len(rows)}')
    return rows


def source_paths(root=ROOT):
    return {path for row in roster(root) for path in (row['view'], row['world']) if path}


def animation_count(data):
    lines = data.decode('ascii').splitlines()
    if len(lines) < 2 or lines[0] != 'dk3_animation 1':
        raise ValueError('invalid source weapon animation sidecar')
    count = int(lines[1])
    if count <= 0:
        raise ValueError('empty source weapon animation')
    return count


def iqm(data):
    if len(data) < HEADER.size or len(data) > 16 << 20:
        raise ValueError('IQM exceeds renderer file bounds')
    values = HEADER.unpack_from(data)
    fields = ('version filesize flags num_text ofs_text num_meshes ofs_meshes num_vertexarrays '
              'num_vertexes ofs_vertexarrays num_triangles ofs_triangles ofs_adjacency num_joints '
              'ofs_joints num_poses ofs_poses num_anims ofs_anims num_frames num_framechannels '
              'ofs_frames ofs_bounds num_comment ofs_comment num_extensions ofs_extensions').split()
    h = dict(zip(fields, values[1:]))
    if values[0] != b'INTERQUAKEMODEL\0' or h['version'] != 2 or h['filesize'] != len(data):
        raise ValueError('invalid IQM header')
    if not 1 <= h['num_meshes'] <= 256 or not 1 <= h['num_frames'] <= 65535 or h['num_joints'] > 128:
        raise ValueError('IQM model exceeds renderer frame, mesh or joint bounds')
    if h['num_poses'] != h['num_joints'] or (h['num_joints'] == 0 and h['num_framechannels'] != 0):
        raise ValueError('IQM joint and pose tables disagree')
    if h['ofs_text'] + h['num_text'] > len(data) or h['ofs_meshes'] + h['num_meshes'] * MESH.size > len(data):
        raise ValueError('IQM text or mesh table outside file')
    if h['ofs_vertexarrays'] + h['num_vertexarrays'] * VERTEX_ARRAY.size > len(data):
        raise ValueError('IQM vertex-array table outside file')
    arrays = {kind: (flags, fmt, width, offset) for kind, flags, fmt, width, offset in
              (VERTEX_ARRAY.unpack_from(data, h['ofs_vertexarrays'] + i * VERTEX_ARRAY.size)
               for i in range(h['num_vertexarrays']))}
    for kind, width in ((0, 3), (1, 2), (2, 3), (3, 4)):
        entry = arrays.get(kind)
        if not entry or entry[:3] != (0, 7, width) or entry[3] + h['num_vertexes'] * width * 4 > len(data):
            raise ValueError('IQM needs valid position, UV, normal and tangent arrays')
    if h['num_joints'] and h['ofs_joints'] + h['num_joints'] * JOINT.size > len(data):
        raise ValueError('IQM joint table outside file')
    def string(offset):
        start = h['ofs_text'] + offset
        end = data.find(b'\0', start, h['ofs_text'] + h['num_text'])
        if offset >= h['num_text'] or end < 0:
            raise ValueError('IQM string outside text table')
        return data[start:end].decode('ascii')
    joints = {string(JOINT.unpack_from(data, h['ofs_joints'] + i * JOINT.size)[0]).rstrip('_')
              for i in range(h['num_joints'])}
    materials = set()
    for i in range(h['num_meshes']):
        _, material, _, vertices, _, triangles = MESH.unpack_from(data, h['ofs_meshes'] + i * MESH.size)
        if not 0 < vertices < 1000 or not 0 < triangles < 2000:
            raise ValueError('IQM surface exceeds bundled renderer limits')
        name = string(material)
        if not name.startswith(MODEL_PREFIX) or '..' in name.split('/'):
            raise ValueError('IQM material outside HD weapon namespace')
        materials.add(name)
    if h['num_joints']:
        import skeletal_iqm
        skeletal_iqm.read(data)
    return h['num_frames'], materials, joints


def required_hardpoints(archive, source, root=ROOT):
    if source not in {row['view'] for row in roster(root)}:
        return set()
    sidecar = source + '.json'
    if sidecar not in archive.namelist():
        return set()
    metadata = json.loads(archive.read(sidecar))
    return {row['surface'] for row in metadata.get('hardpoint_tags', [])
            if row['surface'] in ('hr_muzzle', 'fire')}


def safe_path(name, prefix):
    return (name.startswith(prefix) and '..' not in name.split('/') and
            not name.startswith('/') and '\\' not in name and len(name) < 128)


def admitted(art, admission, base, root=ROOT, *, preview=False):
    manifest = json.loads(admission.read_text())
    if manifest.get('format') != 1 or not isinstance(manifest.get('models'), list):
        raise ValueError('invalid HD weapon admission manifest')
    allowed = source_paths(root)
    files = {}
    mapping = []
    reviews = []
    seen = set()
    with zipfile.ZipFile(base) as original:
        for row in manifest['models']:
            source, target = row['source'], row['target']
            if source not in allowed or source in seen or not safe_path(target, MODEL_PREFIX) or not target.endswith('.iqm'):
                raise ValueError('unknown, duplicate or invalid HD weapon mapping')
            if row.get('review') not in (('accepted', 'unverified') if preview else ('accepted',)):
                raise ValueError(f'{source}: only visually accepted models enter the default package')
            evidence = row.get('evidence', '')
            if not safe_path(evidence, 'reviews/') or not (art / evidence).is_file():
                raise ValueError(f'{source}: missing local visual review evidence')
            source_model = source + '.md3'
            if source_model not in original.namelist():
                raise ValueError(f'{source}: absent from the converted model package')
            data = (art / target).read_bytes()
            frames, materials, joints = iqm(data)
            sidecar = source + '.anim'
            if sidecar in original.namelist() and frames != animation_count(original.read(sidecar)):
                raise ValueError(f'{source}: IQM frame count must match the authoritative .anim sidecar')
            if not required_hardpoints(original, source, root) <= joints:
                raise ValueError(f'{source}: IQM lacks source muzzle hardpoint')
            for material in materials:
                image = material + '.png'
                if not (art / image).is_file():
                    raise ValueError(f'{target}: missing material {image}')
                image_data = (art / image).read_bytes()
                if not image_data.startswith(b'\x89PNG\r\n\x1a\n'):
                    raise ValueError(f'{image}: invalid PNG')
                files[image] = image_data
                for suffix in ('_n.png', '.mat'):
                    extra = art / (material + suffix)
                    if extra.is_file():
                        files[material + suffix] = extra.read_bytes()
            files[target] = data
            mapping.append((source, target))
            reviews.append(dict(source=source, target=target, review=row['review'], source_sha256=digest(original.read(source_model)),
                                evidence=evidence, evidence_sha256=digest((art / evidence).read_bytes())))
            seen.add(source)
    if not mapping:
        raise ValueError('no accepted HD weapon models')
    files[MAPPING] = ''.join(f'{source} {target}\n' for source, target in sorted(mapping)).encode()
    return files, reviews


def build(art, admission, base, output, root=ROOT, *, preview=False):
    files, reviews = admitted(art, admission, base, root, preview=preview)
    report = dict(format=1, preview=preview, source_models_sha256=digest(base.read_bytes()),
                  models=reviews, files={name: digest(data) for name, data in files.items()})
    files[RECEIPT] = (json.dumps(report, indent=2, sort_keys=True) + '\n').encode()
    output.parent.mkdir(parents=True, exist_ok=True)
    temporary = output.with_suffix('.partial')
    with classic_archive(temporary) as archive:
        for name, data in sorted(files.items()):
            info = zipfile.ZipInfo(name, (1980, 1, 1, 0, 0, 0))
            info.compress_type = zipfile.ZIP_DEFLATED
            archive.writestr(info, data)
    validate_package(temporary, base, root, allow_preview=preview)
    temporary.replace(output)
    return report


def validate_package(path, base, root=ROOT, *, allow_preview=False):
    with zipfile.ZipFile(path) as archive, zipfile.ZipFile(base) as original:
        require_classic_directory(path, archive)
        names = archive.namelist()
        if len(names) != len(set(names)) or archive.testzip():
            raise ValueError('corrupt HD weapon package')
        report = json.loads(archive.read(RECEIPT))
        if report.get('format') != 1 or report.get('source_models_sha256') != digest(base.read_bytes()):
            raise ValueError('HD weapon package targets another model generation')
        if report.get('preview', False) and not allow_preview:
            raise ValueError('unverified HD weapon preview cannot be installed as a default package')
        if set(names) != set(report['files']) | {RECEIPT} or MAPPING not in names:
            raise ValueError('HD weapon package entry manifest mismatch')
        for name, sha in report['files'].items():
            if not (name == MAPPING or safe_path(name, MODEL_PREFIX) and name.endswith(('.iqm', '.png', '.mat'))):
                raise ValueError(f'invalid HD weapon package path: {name}')
            if digest(archive.read(name)) != sha:
                raise ValueError(f'changed HD weapon package entry: {name}')
        entries = [line.split() for line in archive.read(MAPPING).decode().splitlines()]
        if not entries or any(len(row) != 2 for row in entries):
            raise ValueError('invalid HD weapon mapping')
        allowed = source_paths(root)
        seen = set()
        reviews = {row['source']: row for row in report['models']}
        for source, target in entries:
            if source not in allowed or source in seen or target not in names or not target.endswith('.iqm'):
                raise ValueError('unknown or duplicate HD weapon mapping')
            review = reviews.get(source)
            review_states = ('accepted', 'unverified') if allow_preview and report.get('preview') else ('accepted',)
            if not review or review.get('review') not in review_states or review['target'] != target or review['source_sha256'] != digest(original.read(source + '.md3')):
                raise ValueError(f'{source}: HD weapon review targets another source')
            frames, materials, joints = iqm(archive.read(target))
            if source + '.anim' in original.namelist() and frames != animation_count(original.read(source + '.anim')):
                raise ValueError(f'{source}: IQM frames do not match source animation')
            if not required_hardpoints(original, source, root) <= joints:
                raise ValueError(f'{source}: IQM lacks source muzzle hardpoint')
            if any(material + '.png' not in names for material in materials):
                raise ValueError(f'{target}: missing material texture')
            seen.add(source)
        if len(reviews) != len(seen):
            raise ValueError('HD weapon review and model mapping differ')
        return report


def capture(base, class_name, output, *, representation='view', surfaces=None, blender='blender'):
    """Capture one Gold weapon or a declared subset for independent concept review."""
    row = next((item for item in roster() if item['class_name'] == class_name), None)
    if row is None or row[representation] is None:
        raise ValueError(f'{class_name}: no {representation} source')
    import numpy as np
    from neural_assets import read_md3
    source = row[representation]
    with zipfile.ZipFile(base) as archive:
        metadata = json.loads(archive.read(source + '.json'))
        meshes, _ = read_md3(archive.read(source + '.md3'))
        chosen = [mesh for mesh in meshes if mesh['name'] not in ('unused',) and
                  not mesh['name'].startswith(('hr_', 'hp_')) and
                  mesh['material'] != 'models/dkq3/nodraw' and
                  (surfaces is None or mesh['name'] in surfaces)]
        if not chosen or (surfaces is not None and set(surfaces) != {mesh['name'] for mesh in chosen}):
            raise ValueError(f'{class_name}: requested surfaces unavailable')
        frame_data = metadata['sequences']['frame_data']
        ready = next((clip for clip in frame_data if clip['animation_name'] in ('ready', 'readya')), None)
        idle = next((clip for clip in frame_data if clip['animation_name'].startswith('amb')), None)
        frame = (ready or idle or {'first': 0})['first']
        output.mkdir(parents=True, exist_ok=True)
        arrays, descriptors = {}, []
        for index, mesh in enumerate(chosen):
            skin = next((item for item in metadata['skins'] if item['shader'] == mesh['material']), None)
            if skin is None:
                raise ValueError(f'{source}: no texture for {mesh["material"]}')
            texture = f'source-texture-{index}.png'
            (output / texture).write_bytes(archive.read(skin['image']))
            descriptors.append(dict(name=mesh['name'], texture=texture))
            for field in ('points', 'uv', 'tri', 'normals'):
                arrays[f'{index}_{field}'] = mesh[field]
        np.savez_compressed(output / 'source.npz', **arrays)
        document = dict(actor=dict(class_name=class_name, source=source, reference_frame=frame),
                        surfaces=descriptors, metadata=metadata)
        (output / 'source.json').write_text(json.dumps(document, indent=2) + '\n')
    command = [blender, '-b', '--threads', '4', '--python-exit-code', '1', '--python',
               str(ROOT / 'dkq3/tools/neural_monster_blender.py'), '--', '--stage', 'capture', '--actor', str(output)]
    subprocess.run(command, check=True)
    return document


def parts_inventory(base):
    """Measure source surfaces for part authoring across the registered roster."""
    import numpy as np
    from hd_weapon_assemble import rigid_fit
    from neural_assets import read_md3

    classes = roster()
    measured = {}
    with zipfile.ZipFile(base) as archive:
        for source in sorted(source_paths()):
            metadata = json.loads(archive.read(source + '.json'))
            source_meshes, _ = read_md3(archive.read(source + '.md3'))
            clips = metadata['sequences']['frame_data']
            ready = next((clip for clip in clips if clip['animation_name'] in ('ready', 'readya')), None)
            idle = next((clip for clip in clips if clip['animation_name'].startswith('amb')), None)
            reference = (ready or idle or {'first': 0})['first']
            surfaces = []
            for mesh in source_meshes:
                if (mesh['name'] == 'unused' or mesh['name'].startswith(('hr_', 'hp_')) or
                        mesh['material'] == 'models/dkq3/nodraw'):
                    continue
                points = mesh['points']
                errors = [rigid_fit(points[reference], frame)[1] for frame in points]
                motion = np.linalg.norm(points.mean(axis=1) - points[reference].mean(axis=0), axis=1)
                surfaces.append(dict(name=mesh['name'], material=mesh['material'], vertices=len(points[0]),
                                     triangles=len(mesh['tri']), max_rigid_rms=float(max(errors)),
                                     max_center_displacement=float(max(motion))))
            measured[source] = dict(source=source, frames=len(source_meshes[0]['points']),
                                    reference_frame=reference, clips=[dict(name=clip['animation_name'],
                                    first=clip['first'], last=clip['last']) for clip in clips],
                                    surfaces=surfaces, hardpoints=[mesh['name'] for mesh in source_meshes
                                    if mesh['name'] in ('hr_muzzle', 'fire')])
    return dict(format=1, classes=classes, models=measured)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest='command', required=True)
    inventory = sub.add_parser('inventory', help='Show all registered weapon art sources and source clips')
    inventory.add_argument('--base-models', type=Path)
    photo = sub.add_parser('capture', help='Render source views for one weapon or selected mesh parts')
    photo.add_argument('--base-models', type=Path, required=True)
    photo.add_argument('--class-name', required=True)
    photo.add_argument('--representation', choices=('view', 'world'), default='view')
    photo.add_argument('--surface', action='append', help='include one named source surface; repeat for several')
    photo.add_argument('--out', type=Path, required=True)
    photo.add_argument('--blender', default='blender')
    package = sub.add_parser('package', help='Build an accepted HD weapon overlay')
    package.add_argument('--art', type=Path, required=True)
    package.add_argument('--admission', type=Path, required=True)
    package.add_argument('--base-models', type=Path, required=True)
    package.add_argument('--out', type=Path, required=True)
    package.add_argument('--preview', action='store_true', help='explicit isolated engine review package; never selected by default')
    check = sub.add_parser('validate', help='Check a package against the converted model generation')
    check.add_argument('--package', type=Path, required=True)
    check.add_argument('--base-models', type=Path, required=True)
    check.add_argument('--allow-preview', action='store_true')
    parts = sub.add_parser('parts-inventory', help='Measure source surfaces and rigid motion for all registered weapons')
    parts.add_argument('--base-models', type=Path, required=True)
    parts.add_argument('--out', type=Path, required=True)
    args = parser.parse_args()
    if args.command == 'inventory':
        rows = roster()
        if args.base_models:
            with zipfile.ZipFile(args.base_models) as archive:
                for row in rows:
                    path = row['view'] + '.anim'
                    row['view_frames'] = animation_count(archive.read(path)) if path in archive.namelist() else None
        print(json.dumps(rows, indent=2))
    elif args.command == 'package':
        print(json.dumps(build(args.art, args.admission, args.base_models, args.out, preview=args.preview), indent=2))
    elif args.command == 'capture':
        print(json.dumps(capture(args.base_models, args.class_name, args.out,
                                 representation=args.representation, surfaces=args.surface, blender=args.blender)['actor'], indent=2))
    elif args.command == 'parts-inventory':
        if args.out.exists():
            raise ValueError('parts inventory exists; use a new versioned path')
        document = parts_inventory(args.base_models)
        args.out.parent.mkdir(parents=True, exist_ok=True)
        args.out.write_text(json.dumps(document, indent=2) + '\n')
        print(json.dumps(dict(classes=len(document['classes']), models=len(document['models']),
                              output=str(args.out)), indent=2))
    else:
        print(json.dumps(validate_package(args.package, args.base_models, allow_preview=args.allow_preview), indent=2))


if __name__ == '__main__':
    main()
