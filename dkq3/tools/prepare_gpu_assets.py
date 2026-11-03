#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-or-later
"""Build an additive, deterministic GPU preparation package; never modify inputs."""
import argparse
import concurrent.futures
from contextlib import ExitStack
import hashlib
import io
import json
import re
from pathlib import Path
import struct
import subprocess
import tempfile
import shutil
import zipfile
import zlib

import numpy as np
from PIL import Image


def texture_path(name):
    normalized = name.replace('\\', '/').lower().encode()
    return 'dk3/prepared/' + hashlib.sha256(normalized).hexdigest()[:32] + '.dkt'


def prepare_texture(source):
    """Uncolored box mip chain, including clamped one-dimensional/odd images."""
    with Image.open(io.BytesIO(source)) as image:
        # The runtime PNG loader admits these 8-bit inputs. Other formats keep
        # their normal decoder until independently qualified.
        if source[:8] != b'\x89PNG\r\n\x1a\n' or source[24] != 8 or source[25] not in (2, 6):
            raise ValueError('prepared textures require 8-bit RGB/RGBA PNG')
        w, h = image.size
        estimated = 64
        while True:
            estimated += w*h*4 + 16
            if w == h == 1:
                break
            w, h = max(w//2, 1), max(h//2, 1)
        if estimated > 256*1024*1024:
            raise ValueError('prepared texture exceeds runtime byte budget')
        rgba = np.array(image.convert('RGBA'), dtype=np.uint8)
    height, width, _ = rgba.shape
    if not (0 < width <= 16384 and 0 < height <= 16384):
        raise ValueError('texture dimensions exceed runtime limits')
    levels = []
    while True:
        h, w, _ = rgba.shape
        levels.append((w, h, rgba.tobytes()))
        if w == h == 1:
            break
        y0 = np.arange(max(h // 2, 1)) * 2
        x0 = np.arange(max(w // 2, 1)) * 2
        y1, x1 = np.minimum(y0 + 1, h - 1), np.minimum(x0 + 1, w - 1)
        wide = rgba.astype(np.uint16)
        rgba = ((wide[y0[:, None], x0] + wide[y0[:, None], x1] +
                 wide[y1[:, None], x0] + wide[y1[:, None], x1]) >> 2).astype(np.uint8)
    cursor = 64 + 16 * len(levels)
    table = bytearray()
    for w, h, pixels in levels:
        table += struct.pack('<4I', cursor, len(pixels), w, h)
        cursor += len(pixels)
    payload = bytes(table) + b''.join(pixels for _, _, pixels in levels)
    if len(payload) + 64 > 256 * 1024 * 1024:
        raise ValueError('prepared texture exceeds runtime byte budget')
    header = (b'DK3TEX1\0' + struct.pack('<4I', width, height, len(levels), 0) +
              hashlib.sha256(source).digest() + struct.pack('<2I', zlib.crc32(payload), 0))
    return header + payload


def build_package(inputs, output, workers=4, world_baker=None, overbright=2, subdivisions=4, *, _entries=None):
    output = Path(output)
    sources = [Path(path) for path in inputs]
    if output.exists():
        raise ValueError('output already exists; select a new generation path')
    if workers < 1 or workers > 8:
        raise ValueError('workers must be in 1..8')
    # Later input packages have override priority, matching an explicitly
    # supplied asset generation. Runtime source checks also protect loose overrides.
    entries = _entries if _entries is not None else source_entries(sources, world_baker)

    def prepare(name):
        path, member = entries[name]
        source = archives[path].read(member)  # ZIP CRC verified by the complete read.
        if name.endswith('.bsp'):
            with tempfile.TemporaryDirectory(prefix='dk3-world-preparation-') as temporary:
                bsp = Path(temporary)/'source.bsp'
                baked = Path(temporary)/'prepared.dkw'
                bsp.write_bytes(source)
                subprocess.run([str(Path(world_baker).resolve()), str(bsp), str(baked), str(overbright), str(subdivisions)], check=True)
                prepared = baked.read_bytes()
        else:
            try:
                prepared = prepare_texture(source)
            except ValueError as error:
                return name, None, {'skipped': str(error)}
        return name, prepared, {'source_sha256': hashlib.sha256(source).hexdigest(),
                                'prepared_sha256': hashlib.sha256(prepared).hexdigest(),
                                'bytes': len(prepared)}

    manifest = {'version': 1, 'textures': {}, 'worlds': {}, 'world_settings': {'overbright': overbright, 'subdivisions': subdivisions}}
    temporary = output.with_name(output.name + '.tmp')
    if temporary.exists():
        raise ValueError('temporary output already exists')
    try:
        # Bound queued results: each wave contains at most workers images. map
        # over the entire corpus would retain completed oversized mip chains.
        names = sorted(entries)
        with ExitStack() as stack, concurrent.futures.ThreadPoolExecutor(max_workers=workers) as executor, \
                zipfile.ZipFile(temporary, 'x', compression=zipfile.ZIP_STORED, allowZip64=False) as archive:
            archives = {path: stack.enter_context(zipfile.ZipFile(path)) for path in {entry[0] for entry in entries.values()}}
            for start in range(0, len(names), workers):
                for name, prepared, record in executor.map(prepare, names[start:start + workers]):
                    manifest['worlds' if name.endswith('.bsp') else 'textures'][name] = record
                    if prepared is not None:
                        prepared_name = texture_path(name)[:-1]+'w' if name.endswith('.bsp') else texture_path(name)
                        archive.writestr(zipfile.ZipInfo(prepared_name, (1980, 1, 1, 0, 0, 0)), prepared)
            archive.writestr(zipfile.ZipInfo('dk3/prepared/manifest.json', (1980, 1, 1, 0, 0, 0)),
                             json.dumps(manifest, sort_keys=True, separators=(',', ':')).encode())
        # Hard link publishes without replacing a concurrently created output.
        import os
        os.link(temporary, output)
    finally:
        temporary.unlink(missing_ok=True)
    return manifest


def source_entries(sources, world_baker):
    entries = {}
    for path in sources:
        path = Path(path)
        with zipfile.ZipFile(path) as archive:
            for info in archive.infolist():
                if ((info.filename.lower().endswith('.png') and info.file_size <= 64 * 1024 * 1024) or
                    (world_baker is not None and info.filename.lower().endswith('.bsp') and info.file_size <= 128 * 1024 * 1024)):
                    entries[info.filename.lower()] = (path, info.filename)
    return entries


def build_generation(inputs, output, workers=4, world_baker=None, overbright=2, subdivisions=4, *, package_limit=1024*1024*1024):
    """Bound each ZIP below native offsets/ZIP64 limits; manifest is published last."""
    output = Path(output)
    if not (1024 <= package_limit <= 1024*1024*1024):
        raise ValueError('package limit must be between 1 KiB and 1 GiB')
    entries = source_entries(inputs, world_baker)
    groups, group, charge = [], {}, 4096
    with ExitStack() as stack:
        archives = {path: stack.enter_context(zipfile.ZipFile(path)) for path in {entry[0] for entry in entries.values()}}
        for name in sorted(entries):
            path, member = entries[name]
            if name.endswith('.bsp'):
                size = 256*1024*1024  # Converter's strict output cap.
            else:
                with archives[path].open(member) as source:
                    header = source.read(33)
                if len(header) < 33 or header[:8] != b'\x89PNG\r\n\x1a\n':
                    raise ValueError('invalid PNG header: ' + name)
                w, h = struct.unpack_from('>2I', header, 16)
                size, levels = 64, 0
                if not (0 < w <= 16384 and 0 < h <= 16384):
                    raise ValueError('invalid texture dimensions: ' + name)
                while True:
                    size += w*h*4 + 16
                    levels += 1
                    if w == h == 1:
                        break
                    w, h = max(w//2, 1), max(h//2, 1)
            size += 1024  # ZIP headers, source metadata and generation index.
            if group and charge + size > package_limit:
                groups.append(group)
                group, charge = {}, 4096
            if charge + size > package_limit:
                raise ValueError('one prepared asset exceeds package budget: ' + name)
            group[name] = entries[name]
            charge += size
        if group:
            groups.append(group)
    output.mkdir()  # Reserve a new generation; existing directories are untouched.
    result = {'version': 1, 'packages': [], 'textures': {}, 'worlds': {}}
    try:
        for index, selected in enumerate(groups):
            path = output/f'zz-dk3-gpu-{index:03d}.pk3'
            manifest = build_package(inputs, path, workers, world_baker, overbright, subdivisions, _entries=selected)
            if path.stat().st_size > package_limit:
                raise ValueError('prepared package exceeded admitted byte budget')
            with path.open('rb') as source:
                digest = hashlib.file_digest(source, 'sha256').hexdigest()
            result['packages'].append({'name': path.name, 'bytes': path.stat().st_size, 'sha256': digest})
            for kind in ('textures', 'worlds'):
                result[kind].update(manifest[kind])
            result['world_settings'] = manifest['world_settings']
        with (output/'manifest.json').open('x') as manifest:
            json.dump(result, manifest, sort_keys=True, indent=2)
            manifest.write('\n')
    except BaseException:
        shutil.rmtree(output)
        raise
    return result


def validate_generation(directory):
    """Admit only bounded, complete preparation packages; no runtime/assets override."""
    directory = Path(directory).resolve(strict=True)
    manifest_path = directory/'manifest.json'
    if manifest_path.stat().st_size > 16*1024*1024:
        raise ValueError('prepared generation manifest exceeds byte budget')
    manifest = json.loads(manifest_path.read_text())
    records = manifest.get('packages', [])
    if manifest.get('version') != 1 or not (0 < len(records) <= 512):
        raise ValueError('invalid prepared generation manifest')
    result, seen = [], set()
    for record in records:
        name = record['name']
        if not re.fullmatch(r'zz-dk3-gpu-[0-9]{3,}.pk3', name) or name in seen:
            raise ValueError('invalid prepared package name')
        seen.add(name)
        path = directory/name
        if not (0 < path.stat().st_size <= 1024*1024*1024) or path.stat().st_size != record['bytes']:
            raise ValueError('prepared package byte size changed: ' + name)
        with path.open('rb') as source:
            if hashlib.file_digest(source, 'sha256').hexdigest() != record['sha256']:
                raise ValueError('prepared package hash changed: ' + name)
        with zipfile.ZipFile(path) as archive:
            names = set()
            for info in archive.infolist():
                if info.filename in names or info.compress_type != zipfile.ZIP_STORED or info.file_size > 256*1024*1024:
                    raise ValueError('invalid prepared entry')
                names.add(info.filename)
                if info.filename != 'dk3/prepared/manifest.json' and not re.fullmatch(r'dk3/prepared/[0-9a-f]{32}\.dk[tw]', info.filename):
                    raise ValueError('prepared package contains a runtime/asset override')
                # Streaming the complete entry checks its CRC without retaining
                # an entire 256 MiB prepared asset during installation.
                with archive.open(info) as entry:
                    while entry.read(1024*1024):
                        pass
        result.append(path)
    return result


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--input', type=Path, action='append', required=True)
    destination = parser.add_mutually_exclusive_group(required=True)
    destination.add_argument('--output', type=Path, help='one small package')
    destination.add_argument('--output-directory', type=Path, help='new generation of packages bounded to 1 GiB each')
    parser.add_argument('--workers', type=int, default=4)
    parser.add_argument('--world-baker', type=Path, help='prepare-world-assets executable from zig build prepare-world-assets')
    parser.add_argument('--overbright', type=int, choices=range(9), default=2)
    parser.add_argument('--subdivisions', type=int, default=4)
    args = parser.parse_args()
    build = build_generation if args.output_directory else build_package
    target = args.output_directory or args.output
    result = build(args.input, target, args.workers, args.world_baker, args.overbright, args.subdivisions)
    print(json.dumps({'textures': len(result['textures']), 'worlds': len(result['worlds']), 'output': str(target)}))
