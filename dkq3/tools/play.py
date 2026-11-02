#!/usr/bin/env python3
"""Assemble and launch the independent game; never discover or invoke legacy binaries."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import zipfile
from concurrent.futures import ThreadPoolExecutor

from assets import current_generation, digest, write_json
from portable_lock import locked

if os.name == 'nt':
    BINARIES = ('dk3.exe', 'dk3ded.exe', 'renderer_opengl1.dll', 'renderer_opengl2.dll', 'renderer_vulkan.dll', 'SDL2.dll')
    MODULES = ('qagame.dll', 'cgame.dll', 'ui.dll')
else:
    BINARIES = ('dk3', 'dk3ded', 'renderer_opengl1.so', 'renderer_opengl2.so', 'renderer_vulkan.so')
    MODULES = ('qagame.so', 'cgame.so', 'ui.so')
LEGACY_RUNTIME_MEDIA = ('scripts/dk3-projectile-weather.shader',)
ONLINE_METADATA = ('rules.json', 'compatibility.json')
RUNTIME_MEDIA = (*LEGACY_RUNTIME_MEDIA, 'rules.json')
RUNTIME_NOTICES = ('share/licenses/dk3/libdeflate-COPYING', 'share/licenses/dk3/zig-stdlib-MIT')
PACKAGES = ('base', 'textures', 'maps', 'shaders', 'models', 'sprites', 'hud', 'sound', 'music', 'voice', 'data', 'navigation')
REQUIRED_ENTRIES = ('default.cfg', 'fonts/con_font.dkf', 'fonts/con_font.tga', 'maps/e1m1a.bsp',
                    'dk3/navigation/e1m1a.cfg')
_HASH_PARALLEL_MIN_BYTES = 32 << 20
_ADMISSION_PARALLEL_MIN_BYTES = 32 << 20
_GAMEPLAY_PACKAGES = ('base', 'maps', 'data', 'navigation')


def _installation_hashes(files):
    """Hash every product, with bounded independent readers for large builds."""
    sizes = {}
    for name, path in files.items():
        if not path.is_file():
            raise ValueError(f'missing independent build product: {path}; run zig build')
        sizes[name] = path.stat().st_size
    workers = min(4, os.cpu_count() or 1)
    if workers <= 1 or sum(sizes.values()) < _HASH_PARALLEL_MIN_BYTES:
        return {name: digest(path) for name, path in files.items()}
    # Start the largest immutable package first, so it cannot become a long
    # serial tail after the small binaries. Digests and published key order
    # remain exactly the same as the sequential implementation.
    entries = sorted(files.items(), key=lambda item: sizes[item[0]], reverse=True)
    def hash_product(entry):
        name, path = entry
        return name, digest(path)
    executor = ThreadPoolExecutor(max_workers=workers)
    try:
        hashes = dict(executor.map(hash_product, entries))
    finally:
        executor.shutdown(wait=True, cancel_futures=True)
    return {name: hashes[name] for name in files}


def checked_assets(directory):
    """Validate every package and derive compatibility from the same CRC-checked reads."""
    manifest = json.loads((directory / 'manifest.json').read_text())
    if manifest.get('format') != 1:
        raise ValueError(f'{directory}: unsupported asset manifest format')
    entries = set()
    gameplay_entries = {}
    def admit(name):
        filename = f'dk3-{name}.pk3'
        path = directory / 'packages' / filename
        record = manifest['packages'].get(filename)
        if not record or not path.is_file():
            raise ValueError(f'missing converted package: {path}')
        if digest(path) != record['sha256']:
            raise ValueError(f'changed or corrupt package: {path}; regenerate this asset generation')
        with zipfile.ZipFile(path) as archive:
            names = archive.namelist()
            hashes = {}
            for entry in names:
                entry_hash = hashlib.sha256() if name in _GAMEPLAY_PACKAGES and not entry.endswith('/') else None
                try:
                    with archive.open(entry) as stream:
                        while block := stream.read(1 << 20):
                            if entry_hash is not None:
                                entry_hash.update(block)
                except zipfile.BadZipFile as error:
                    raise ValueError(f'{path}: corrupt entry {entry}') from error
                if entry_hash is not None:
                    hashes[entry] = entry_hash.digest()
            # Keep duplicate-name and sorted/case-normalized semantics of
            # the previous ZipFile.read(name) compatibility calculation.
            gameplay = ([(entry, hashes[entry]) for entry in sorted(names)
                         if not entry.endswith('/')] if name in _GAMEPLAY_PACKAGES else [])
            return name, names, gameplay
    # Packages have independent readers and decompression state. Bound workers
    # and streaming buffers; collect in package order and always join on error.
    # Small installations stay serial, avoiding pool overhead for tiny inputs.
    workers = min(4, os.cpu_count() or 1)
    size = sum(path.stat().st_size for name in PACKAGES
               if (path := directory / 'packages' / f'dk3-{name}.pk3').is_file())
    if workers <= 1 or size < _ADMISSION_PARALLEL_MIN_BYTES:
        admitted = map(admit, PACKAGES)
        for name, names, gameplay in admitted:
            entries.update(names)
            gameplay_entries[name] = gameplay
    else:
        executor = ThreadPoolExecutor(max_workers=workers)
        try:
            for name, names, gameplay in executor.map(admit, PACKAGES):
                entries.update(names)
                gameplay_entries[name] = gameplay
        finally:
            executor.shutdown(wait=True, cancel_futures=True)
    missing = set(REQUIRED_ENTRIES) - entries
    if missing:
        raise ValueError('installation lacks required assets: ' + ', '.join(sorted(missing)))
    gameplay = hashlib.sha256()
    for name in _GAMEPLAY_PACKAGES:
        for entry, entry_hash in gameplay_entries[name]:
            gameplay.update(entry.lower().encode() + b'\0')
            gameplay.update(entry_hash)
    return manifest, gameplay.hexdigest()


def converted_surface_counts(maps_package):
    """-> {map name: surface count} of the converted maps."""
    import struct
    import q3bsp
    counts = {}
    index = q3bsp.LUMPS.index('surfaces')
    with zipfile.ZipFile(maps_package) as archive:
        for name in archive.namelist():
            if not (name.startswith('maps/') and name.endswith('.bsp') and name.count('/') == 1):
                continue
            with archive.open(name) as stream:
                head = stream.read(8 + 8 * len(q3bsp.LUMPS))
            _, length = struct.unpack_from('<ii', head, 8 + 8 * index)
            counts[name[5:-4]] = length // q3bsp.DT['surfaces'].itemsize
    return counts


def ensure_surface_lights(package, source):
    """The ray traced lighting's per-map surface lights (surface_lights.py) are derived from the
    original maps and stay local: when any installed map lacks its sidecar, or the sidecar was
    made for different geometry, regenerate them all from this asset generation's input."""
    import surface_lights
    expected = converted_surface_counts(source / 'packages' / 'dk3-maps.pk3')
    with zipfile.ZipFile(package) as archive:
        present = {name: archive.read(name).decode('utf-8', 'replace')
                   for name in archive.namelist() if name.startswith('maps/') and name.endswith('.lights')}
    stale = sorted(name for name, count in expected.items()
                   if surface_lights.recorded_surfaces(present.get(f'maps/{name}.lights', '')) != count)
    if not stale:
        return
    game = source / 'input'
    if not game.is_dir():
        raise ValueError(f'{package}: surface lights missing or stale for {len(stale)} maps ({", ".join(stale[:5])}...) '
                         f'and {game} is not available; run dkq3/tools/surface_lights.py --data <Daikatana data> '
                         f'--package {package}')
    texts = surface_lights.sidecars(str(game))
    still = sorted(name for name in stale
                   if surface_lights.recorded_surfaces(texts.get(f'maps/{name}.lights', '')) != expected[name])
    if still:
        raise ValueError(f'{package}: could not regenerate surface lights matching the converted maps: '
                         + ', '.join(still[:10]))
    surface_lights.write_package(package, texts)
    print(f'play-install: regenerated surface lights for {len(texts)} maps ({len(stale)} missing or stale) '
          f'from {game} into {package}')


def install(prefix, assets, hd_textures=None, *, hd_textures_fallback=None,
            neural_assets=None, neural_assets_fallback=None, hd_weapons=None, hd_weapons_fallback=None,
            hd_weapons_preview=None,
            materials=None, materials_fallback=None, prepared_gpu=None):
    if not (current_generation(assets) / 'manifest.json').is_file():
        raise ValueError(f'no completed asset generation in {assets}; run zig build assets '
                         '-DDK_DATA=/path/to/data -Dasset-profile=retail first, '
                         'or select an existing cache with -Dassets-dir=/path/to/cache')
    source = current_generation(assets).resolve(strict=True)
    manifest, gameplay = checked_assets(source)
    files = {f'bin/{name}': prefix / 'bin' / name for name in BINARIES}
    files.update({f'share/dk3/{name}': prefix / 'lib' / 'dk3' / name for name in MODULES})
    files.update({f'share/dk3/{name}': prefix / 'share' / 'dk3' / name for name in RUNTIME_MEDIA})
    files.update({name: prefix / name for name in RUNTIME_NOTICES})
    for name in PACKAGES:
        filename = f'dk3-{name}.pk3'
        files[f'share/dk3/{filename}'] = source / 'packages' / filename
    # Previously produced artwork is optional local input. Keep it outside the
    # gameplay asset identity so changing texture resolution preserves saves.
    hd = hd_textures or prefix / 'hd-textures' / 'dkq3-textures_hd.pk3'
    if not hd_textures and not hd.is_file() and hd_textures_fallback:
        hd = hd_textures_fallback
    if hd_textures or hd.is_file():
        with zipfile.ZipFile(hd) as archive:
            names = archive.namelist()
            if not names or any(not name.startswith('textures/') or
                                not name.endswith(('.png', '.tga', '.jpg')) or
                                '..' in name.split('/') for name in names):
                raise ValueError(f'{hd}: HD overlay must contain texture images only')
            invalid = archive.testzip()
            if invalid:
                raise ValueError(f'{hd}: corrupt texture {invalid}')
        files['share/dk3/zz-dk3-textures-hd.pk3'] = hd
    neural = neural_assets or prefix / 'neural-assets' / 'dk3-neural.pk3'
    if not neural_assets and not neural.is_file() and neural_assets_fallback:
        neural = neural_assets_fallback
    if neural_assets or neural.is_file():
        from neural_package import validate_package
        validate_package(neural, source / 'packages/dk3-models.pk3')
        files['share/dk3/zz-dk3-neural.pk3'] = neural
    if hd_weapons and hd_weapons_preview:
        raise ValueError('select either accepted HD weapons or an unverified preview')
    weapons = hd_weapons_preview or hd_weapons or prefix / 'hd-weapons' / 'dk3-hd-weapons.pk3'
    if not hd_weapons and not hd_weapons_preview and not weapons.is_file() and hd_weapons_fallback:
        weapons = hd_weapons_fallback
    if hd_weapons or hd_weapons_preview or weapons.is_file():
        from hd_weapons import validate_package
        validate_package(weapons, source / 'packages/dk3-models.pk3', allow_preview=hd_weapons_preview is not None)
        files['share/dk3/zz-dk3-hd-weapons.pk3'] = weapons
    # Remaster material sidecars, normal maps (materialgen.py) and map surface-light sidecars
    # (surface_lights.py) are read only by renderer_vulkan; like the HD overlay they are cosmetic.
    material_package = materials or prefix / 'materials' / 'dk3-materials.pk3'
    if not materials and not material_package.is_file() and materials_fallback:
        material_package = materials_fallback
    if materials or material_package.is_file():
        with zipfile.ZipFile(material_package) as archive:
            names = archive.namelist()
            def material_entry(name):
                if name.startswith('textures/'):
                    return name.endswith(('.mat', '_n.png'))
                return name.startswith('maps/') and name.count('/') == 1 and name.endswith('.lights')
            if not names or any(not material_entry(name) or '..' in name.split('/') for name in names):
                raise ValueError(f'{material_package}: material package must contain .mat sidecars, _n.png maps and '
                                 'maps/<map>.lights only')
            invalid = archive.testzip()
            if invalid:
                raise ValueError(f'{material_package}: corrupt entry {invalid}')
        ensure_surface_lights(material_package, source)
        files['share/dk3/zz-dk3-materials.pk3'] = material_package
    if prepared_gpu is not None:
        from prepare_gpu_assets import validate_generation
        for package in validate_generation(prepared_gpu):
            files[f'share/dk3/{package.name}'] = package
    # Canonical package entries ignore ZIP timestamps/compression and native ELF
    # bytes. Approved texture-only overlays do not change gameplay compatibility.
    compatibility = json.loads((prefix / 'share/dk3/rules.json').read_text())
    compatibility.update(gameplay=gameplay, cosmetic='hd-textures-v1' if 'share/dk3/zz-dk3-textures-hd.pk3' in files else 'stock-v1')
    if prepared_gpu is not None:
        compatibility['cosmetic'] += '+gpu-prepared-v1'
    if 'share/dk3/zz-dk3-neural.pk3' in files:
        compatibility['cosmetic'] += '+neural-v1'
    if 'share/dk3/zz-dk3-hd-weapons.pk3' in files:
        compatibility['cosmetic'] += '+hd-weapons-preview-v1' if hd_weapons_preview else '+hd-weapons-v1'
    if 'share/dk3/zz-dk3-materials.pk3' in files:
        compatibility['cosmetic'] += '+materials-v1'
    compatibility_file = prefix / 'share/dk3/compatibility.json'
    write_json(compatibility_file, compatibility)
    files['share/dk3/compatibility.json'] = compatibility_file
    # Derived authoring data is local, exact-build content. Never reuse a portal
    # geometry review after either BSP changes.
    import campaign_regions
    region_file = prefix / 'share/dk3/dk3/campaign-regions.cfg'
    campaign_regions.cached_build(source / 'packages/dk3-maps.pk3', region_file,
                                  verified_package_sha256=manifest['packages']['dk3-maps.pk3']['sha256'])
    files['share/dk3/dk3/campaign-regions.cfg'] = region_file
    records = _installation_hashes(files)
    key = hashlib.sha256(json.dumps(records, sort_keys=True).encode()).hexdigest()
    root = prefix / 'play'
    root.mkdir(exist_ok=True)
    with locked(root / '.lock'):
        destination = root / key
        if not (destination / 'installation.json').is_file():
            if destination.exists():
                shutil.rmtree(destination)
            for name, path in files.items():
                target = destination / name
                target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copyfile(path, target)
                target.chmod(0o755 if name.startswith('bin/') else 0o644)
                if digest(target) != records[name]:
                    raise ValueError(f'{path} changed while installing; rerun play-install')
            write_json(destination / 'installation.json', dict(format=2, files=records,
                       asset_profile=manifest['profile'], asset_generation=manifest['key'], gameplay='incomplete'))
        if os.name == 'nt':
            write_json(root / 'current.json', {'key': destination.name})
        else:
            current, temporary = root / 'current', root / 'current.partial'
            temporary.unlink(missing_ok=True)
            temporary.symlink_to(destination.name, target_is_directory=True)
            temporary.replace(current)
        (root / 'home').mkdir(exist_ok=True)
    print(f'play-install: {destination}\nplay-install: independent runtime; campaign gameplay incomplete')
    if 'share/dk3/zz-dk3-textures-hd.pk3' in records:
        print(f'play-install: HD textures enabled from {hd}')
    if 'share/dk3/zz-dk3-neural.pk3' in records:
        print(f'play-install: skeletal neural characters enabled from {neural}')
    if 'share/dk3/zz-dk3-hd-weapons.pk3' in records:
        print(f'play-install: {"unverified HD weapon preview" if hd_weapons_preview else "accepted HD weapons"} enabled from {weapons}')
    if 'share/dk3/zz-dk3-materials.pk3' in records:
        print(f'play-install: remaster materials enabled from {material_package}')


def launch(prefix, guard, extra, headless=False):
    directory = current_generation(prefix / 'play').resolve(strict=True)
    manifest = json.loads((directory / 'installation.json').read_text())
    if manifest.get('format') not in (1, 2):
        raise ValueError('unsupported installation manifest')
    # The launcher also serves preserved installations made before online rooms.
    # Those format-1 runtimes never contained the new compatibility metadata.
    # Early online installations used format 1 too; either metadata entry opts
    # them into checking the complete pair, including missing or corrupt files.
    media = list(LEGACY_RUNTIME_MEDIA)
    if manifest['format'] == 2 or any(f'share/dk3/{n}' in manifest['files'] for n in ONLINE_METADATA):
        media.extend(ONLINE_METADATA)
    for name in [*[f'bin/{n}' for n in BINARIES], *[f'share/dk3/{n}' for n in MODULES],
                 *[f'share/dk3/{n}' for n in media]]:
        if name not in manifest['files'] or not (directory / name).is_file():
            raise ValueError(f'installed product missing: {name}; rerun play-install')
        if digest(directory / name) != manifest['files'][name]:
            raise ValueError(f'installed product changed: {name}; rerun play-install')
    print('play: independent dk3 development runtime; campaign implementation and verification incomplete', flush=True)
    print(f'play: build {directory.name}; assets {manifest.get("asset_generation", "unrecorded")}', flush=True)
    print(f'play: development profile {prefix / "play"}', flush=True)
    command = [str(Path(guard).resolve(strict=True)), *(['--headless'] if headless else []),
               '--mem', '8G', '--timeout', '43200', '--',
               str(directory / 'bin' / BINARIES[0]), '+set', 'fs_basepath', str(directory / 'share'),
               '+set', 'fs_homepath', str(prefix / 'play' / 'home'), '+set', 'com_basegame', 'dk3',
               '+set', 'fs_homedatapath', str(prefix / 'play' / 'home'),
               '+set', 'fs_homestatepath', str(prefix / 'play' / 'state'),
               '+set', 'vm_game', '0', '+set', 'vm_cgame', '0', '+set', 'vm_ui', '0',
               '+set', 'dk3_runtime_probe', '2',
               '+set', 'g_gametype', '2', '+set', 'cl_renderer', 'vulkan',
               *(['+set', 'r_picmip', '0'] if any(name in manifest['files'] for name in
                 ('share/dk3/zz-dk3-textures-hd.pk3', 'share/dk3/zz-dk3-neural.pk3',
                  'share/dk3/zz-dk3-hd-weapons.pk3')) else []), *extra]
    if os.name == 'nt':
        return subprocess.run(command, check=False).returncode
    os.execv(command[0], command)


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest='command', required=True)
    prepare = sub.add_parser('install')
    prepare.add_argument('--prefix', type=Path, required=True)
    prepare.add_argument('--assets', type=Path, required=True)
    prepare.add_argument('--hd-textures', type=Path, help='optional image-only HD texture package')
    prepare.add_argument('--hd-textures-fallback', type=Path, help='shared local HD package used when the build prefix has none')
    prepare.add_argument('--neural-assets', type=Path, help='optional validated skeletal character package')
    prepare.add_argument('--neural-assets-fallback', type=Path, help='shared locally converted skeletal package')
    prepare.add_argument('--hd-weapons', type=Path, help='accepted local HD weapon package')
    prepare.add_argument('--hd-weapons-fallback', type=Path, help='shared local HD weapon package')
    prepare.add_argument('--hd-weapons-preview', type=Path, help='explicit unverified HD weapon package for guarded visual review')
    prepare.add_argument('--materials', type=Path, help='optional materialgen.py remaster material package')
    prepare.add_argument('--prepared-gpu', type=Path, help='completed prepare_gpu_assets.py package generation')
    prepare.add_argument('--materials-fallback', type=Path, help='shared locally generated material package')
    run = sub.add_parser('launch')
    run.add_argument('--prefix', type=Path, required=True)
    run.add_argument('--dkguard', required=True)
    run.add_argument('--headless', action='store_true', help='software rendering on a virtual display')
    arguments, extra = parser.parse_known_args(argv)
    try:
        prefix = arguments.prefix.resolve(strict=True)
        if arguments.command == 'install':
            if extra: parser.error('unexpected installation arguments: ' + ' '.join(extra))
            install(prefix, arguments.assets.resolve(), arguments.hd_textures,
                    hd_textures_fallback=arguments.hd_textures_fallback,
                    neural_assets=arguments.neural_assets, neural_assets_fallback=arguments.neural_assets_fallback,
                    hd_weapons=arguments.hd_weapons, hd_weapons_fallback=arguments.hd_weapons_fallback,
                    hd_weapons_preview=arguments.hd_weapons_preview,
                    materials=arguments.materials, materials_fallback=arguments.materials_fallback,
                    prepared_gpu=arguments.prepared_gpu)
        else:
            return launch(prefix, arguments.dkguard, extra[1:] if extra[:1] == ['--'] else extra, arguments.headless)
        return 0
    except (OSError, ValueError, KeyError, zipfile.BadZipFile) as error:
        print(f'play: {error}', file=sys.stderr)
        return 1


if __name__ == '__main__':
    sys.exit(main())
