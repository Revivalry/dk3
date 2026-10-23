#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-or-later
"""Package built native products with reviewed installer tools and supplied redistributables.

The resulting archive contains no Daikatana game data. The packager supplies a
portable Python 3.11+ distribution with venv/pip, a static FFmpeg 7 binary, and a NumPy wheel
for the selected platform. The optional HD stage downloads its own dependencies.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import tempfile
import zipfile

import assets


PRODUCTS = {
    'linux-x64': ('dk3', 'dk3ded', 'dkguard', 'bspc', 'renderer_vulkan.so',
                  'renderer_opengl1.so', 'renderer_opengl2.so'),
    'windows-x64': ('dk3.exe', 'dk3ded.exe', 'dkguard.exe', 'bspc.exe', 'SDL2.dll',
                    'renderer_vulkan.dll', 'renderer_opengl1.dll', 'renderer_opengl2.dll'),
}
MODULES = {
    'linux-x64': ('qagame.so', 'cgame.so', 'ui.so'),
    'windows-x64': ('qagame.dll', 'cgame.dll', 'ui.dll'),
}


def copy_file(source: Path, destination: Path) -> None:
    if not source.is_file():
        raise ValueError(f'missing release input: {source}')
    destination.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(source, destination)


def digest(path: Path) -> str:
    sha = hashlib.sha256()
    with path.open('rb') as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b''):
            sha.update(chunk)
    return sha.hexdigest()


def fill(bundle: Path, repository: Path, prefix: Path, platform: str,
         python_runtime: Path, ffmpeg: Path, ffmpeg_license: Path, wheelhouse: Path) -> None:
    for name in PRODUCTS[platform]:
        copy_file(prefix / 'bin' / name, bundle / 'bin' / name)
    for name in MODULES[platform]:
        copy_file(prefix / 'lib/dk3' / name, bundle / 'lib/dk3' / name)
    for name in ('rules.json', 'scripts/dk3-projectile-weather.shader'):
        copy_file(prefix / 'share/dk3' / name, bundle / 'share/dk3' / name)
    if not python_runtime.is_dir() or not wheelhouse.is_dir():
        raise ValueError('portable Python runtime and wheelhouse must be directories')
    python_name = 'python.exe' if platform == 'windows-x64' else 'bin/python3'
    if not (python_runtime / python_name).is_file():
        raise ValueError(f'portable Python lacks {python_name}')
    requirement = (repository / 'dkq3/tools/requirements.txt').read_text().strip()
    if not requirement.startswith('numpy=='):
        raise ValueError('release packager cannot identify the pinned NumPy wheel')
    version = requirement.partition('==')[2]
    if not any(p.name.lower().startswith(f'numpy-{version}-') and p.suffix == '.whl' for p in wheelhouse.iterdir()):
        raise ValueError(f'wheelhouse lacks the pinned NumPy {version} wheel')
    shutil.copytree(python_runtime, bundle / 'runtime/python', symlinks=False)
    shutil.copytree(wheelhouse, bundle / 'runtime/wheels')
    copy_file(ffmpeg, bundle / 'runtime/ffmpeg' / ('ffmpeg.exe' if platform == 'windows-x64' else 'ffmpeg'))
    copy_file(ffmpeg_license, bundle / 'licenses/ffmpeg.txt')
    for name in ('LICENSE', 'COPYRIGHT.md', 'engine/ioquake3/COPYING.txt', 'engine/bspc/LICENSE',
                 'engine/fidelityfx/LICENSE.txt', 'engine/ioquake3/code/thirdparty/SDL2-2.32.8/include/SDL_copying.h'):
        copy_file(repository / name, bundle / 'licenses' / name)
    tools = repository / 'dkq3/tools'
    for script in tools.glob('*.py'):
        copy_file(script, bundle / 'dkq3/tools' / script.name)
    for name in ('requirements.txt', 'requirements-hd.txt'):
        copy_file(tools / name, bundle / 'dkq3/tools' / name)
    for name in assets.CONVERSION_INPUTS:
        copy_file(repository / name, bundle / name)
    if platform == 'windows-x64':
        (bundle / 'install.cmd').write_bytes(b'@echo off\r\n"%~dp0runtime\\python\\python.exe" -B "%~dp0dkq3\\tools\\install_wizard.py" --bundle "%~dp0." %*\r\n')
    else:
        launcher = bundle / 'install.sh'
        launcher.write_text('#!/bin/sh\nset -eu\nroot=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)\n'
                            'exec "$root/runtime/python/bin/python3" -B "$root/dkq3/tools/install_wizard.py" '
                            '--bundle "$root" "$@"\n')
        launcher.chmod(0o755)
    (bundle / 'README.txt').write_text(
        'dk3 installer\n\nExtract this archive, then run install.cmd on Windows or install.sh on Linux.\n'
        'Choose a Steam or custom Daikatana data directory. Retail game data stays on your machine.\n'
        'The optional HD stage downloads models and Python packages after you confirm it.\n'
        'After installation, run play.cmd or play.sh from your chosen install directory.\n')
    hashes = {str(p.relative_to(bundle)): digest(p)
              for p in bundle.rglob('*') if p.is_file()}
    (bundle / 'bundle.json').write_text(json.dumps({'format': 1, 'platform': platform, 'files': hashes},
                                                 sort_keys=True, indent=2) + '\n')


def main(argv=None) -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--platform', choices=PRODUCTS, required=True)
    parser.add_argument('--prefix', type=Path, required=True, help='zig build installation prefix for this target')
    parser.add_argument('--python-runtime', type=Path, required=True)
    parser.add_argument('--ffmpeg', type=Path, required=True)
    parser.add_argument('--ffmpeg-license', type=Path, required=True)
    parser.add_argument('--wheelhouse', type=Path, required=True)
    parser.add_argument('--out', type=Path, required=True, help='new output ZIP archive')
    args = parser.parse_args(argv)
    if args.out.exists():
        parser.error(f'output already exists: {args.out}')
    repository = Path(__file__).resolve().parents[2]
    args.out.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='dk3-release-', dir=args.out.parent) as temporary:
        bundle = Path(temporary) / f'dk3-installer-{args.platform}'
        bundle.mkdir()
        fill(bundle, repository, args.prefix, args.platform, args.python_runtime,
             args.ffmpeg, args.ffmpeg_license, args.wheelhouse)
        partial = args.out.with_suffix(args.out.suffix + '.partial')
        try:
            with zipfile.ZipFile(partial, 'w', compression=zipfile.ZIP_DEFLATED, compresslevel=6) as archive:
                for path in sorted(bundle.rglob('*')):
                    if path.is_file():
                        archive.write(path, path.relative_to(bundle.parent))
            os.replace(partial, args.out)
        finally:
            partial.unlink(missing_ok=True)
    print(args.out)


if __name__ == '__main__':
    main()
