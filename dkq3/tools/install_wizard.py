#!/usr/bin/env python3
"""Install a release bundle using the owner's Daikatana data.

The bundle carries native binaries and conversion tools, never retail data.
"""
from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys

import assets
import play


def verify_bundle(bundle: Path) -> None:
    manifest = json.loads((bundle / 'bundle.json').read_text())
    if manifest.get('format') != 1 or not isinstance(manifest.get('files'), dict):
        raise ValueError('unsupported release bundle')
    for name in assets.CONVERSION_INPUTS:
        if name not in manifest['files'] or not (bundle / name).is_file():
            raise ValueError(f'missing release conversion input: {name}')
    for name, expected in manifest['files'].items():
        if not isinstance(name, str) or not isinstance(expected, str):
            raise ValueError('invalid release manifest entry')
        path = bundle / name
        if Path(name).is_absolute() or '..' in Path(name).parts or not path.is_file():
            raise ValueError(f'missing release file: {name}')
        actual = assets.digest(path)
        if actual != expected:
            raise ValueError(f'changed release file: {name}')


def game_data(root: Path) -> Path | None:
    """Find data in a selected game directory without searching unrelated files."""
    if not root.is_dir():
        return None
    for candidate in (root, *[child for child in root.iterdir() if child.is_dir() and child.name.lower() == 'data']):
        names = {p.name.lower() for p in candidate.iterdir() if p.is_file()}
        if all(name in names for name in assets.REQUIRED_ARCHIVES):
            return candidate.resolve()
    return None


def steam_libraries() -> list[Path]:
    """Read Steam library folders from standard user locations and the Windows registry."""
    home = Path.home()
    roots = [home / '.steam/steam', home / '.local/share/Steam',
             home / 'Library/Application Support/Steam']
    for env in ('PROGRAMFILES(X86)', 'PROGRAMFILES'):
        if os.environ.get(env):
            roots.append(Path(os.environ[env]) / 'Steam')
    if os.name == 'nt':
        try:
            import winreg
            with winreg.OpenKey(winreg.HKEY_CURRENT_USER, r'Software\Valve\Steam') as key:
                roots.append(Path(winreg.QueryValueEx(key, 'SteamPath')[0]))
        except (OSError, ImportError):
            pass
    libraries = set()
    for root in roots:
        if not root.is_dir():
            continue
        libraries.add(root.resolve())
        vdf = root / 'steamapps/libraryfolders.vdf'
        if not vdf.is_file():
            continue
        for path in re.findall(r'"path"\s+"((?:\\.|[^"\\])*)"', vdf.read_text(errors='replace'), re.I):
            library = Path(path.replace('\\\\', '\\'))
            if library.is_dir():
                libraries.add(library.resolve())
    return sorted(libraries)


def steam_sources() -> list[Path]:
    sources = set()
    for library in steam_libraries():
        common = library / 'steamapps/common'
        if not common.is_dir():
            continue
        for child in common.iterdir():
            if child.is_dir() and child.name.casefold() == 'daikatana':
                if source := game_data(child):
                    sources.add(source)
    return sorted(sources)


def choose(label: str, options: list[str], default: int = 0) -> int:
    print(f'\n{label}')
    for index, option in enumerate(options, 1):
        print(f'  {index}. {option}')
    while True:
        response = input(f'Select [{default + 1}]: ').strip()
        if not response:
            return default
        if response.isdigit() and 1 <= int(response) <= len(options):
            return int(response) - 1
        print('Enter one of the listed numbers.')


def source_selection() -> Path:
    found = steam_sources()
    options = [f'Steam: {path}' for path in found] + ['Choose another directory']
    selected = choose('Original Daikatana data source', options)
    if selected < len(found):
        return found[selected]
    while True:
        path = Path(input('Directory containing Daikatana or its data folder: ').strip().strip('"')).expanduser()
        if source := game_data(path):
            return source
        print('Could not find all three game archives: pak1.pak, pak2.pak, and pak3.pak.\n'
              'Choose the Daikatana folder or its data subfolder. The original game is unchanged.')


def profile_for(source: Path) -> str:
    names = {child.name.lower() for child in source.iterdir() if child.is_file()}
    if 'pak6.pak' in names and ('pak5.pak' in names or 'pak5.zip' in names):
        return '1.3'
    return 'retail'


def bundle_tool(bundle: Path, name: str) -> Path:
    suffix = '.exe' if os.name == 'nt' else ''
    path = bundle / 'bin' / (name + suffix)
    if not path.is_file():
        raise ValueError(f'release bundle is missing {path}')
    return path


def python_environment(bundle: Path, destination: Path) -> Path:
    """Use the bundled interpreter and offline wheelhouse in a private environment."""
    runtime = destination / '.installer/runtime-python'
    marker = runtime / '.copied'
    if not marker.is_file():
        shutil.copytree(bundle / 'runtime/python', runtime, dirs_exist_ok=True)
        marker.write_text('complete\n')
    bundled = runtime / ('python.exe' if os.name == 'nt' else 'bin/python3')
    if not bundled.is_file():
        raise ValueError(f'release bundle is missing its Python runtime: {bundled}')
    environment = destination / '.installer/python'
    python = environment / ('Scripts/python.exe' if os.name == 'nt' else 'bin/python')
    if not python.is_file():
        subprocess.run([str(bundled), '-m', 'venv', '--copies', str(environment)], check=True)
    wheelhouse = bundle / 'runtime/wheels'
    if not wheelhouse.is_dir():
        raise ValueError(f'release bundle is missing its Python wheelhouse: {wheelhouse}')
    requirements = bundle / 'dkq3/tools/requirements.txt'
    subprocess.run([str(python), '-m', 'pip', 'install', '--disable-pip-version-check', '--no-index',
                    '--find-links', str(wheelhouse), '-r', str(requirements)], check=True)
    return python


def copy_products(bundle: Path, destination: Path) -> None:
    for directory in ('bin', 'lib', 'share'):
        source = bundle / directory
        if not source.is_dir():
            raise ValueError(f'release bundle is missing {source}')
        shutil.copytree(source, destination / directory, dirs_exist_ok=True)
    shutil.copytree(bundle / 'dkq3/tools', destination / 'tools', dirs_exist_ok=True)


def write_launcher(destination: Path) -> None:
    if os.name == 'nt':
        launcher = destination / 'play.cmd'
        launcher.write_text('@echo off\r\n"%~dp0.installer\\python\\Scripts\\python.exe" '
                            '"%~dp0tools\\play.py" launch --prefix "%~dp0." '
                            '--dkguard "%~dp0bin\\dkguard.exe" %*\r\n')
    else:
        launcher = destination / 'play.sh'
        launcher.write_text('#!/bin/sh\nset -eu\nroot=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)\n'
                            'exec "$root/.installer/python/bin/python" "$root/tools/play.py" launch '
                            '--prefix "$root" --dkguard "$root/bin/dkguard" "$@"\n')
        launcher.chmod(0o755)


def generate_hd(bundle: Path, python: Path, destination: Path, assets_dir: Path, stages: list[str]) -> Path:
    producer = bundle / 'dkq3/tools/produce.py'
    if not producer.is_file():
        raise ValueError('this release bundle has no reviewed HD texture producer')
    root = assets.current_generation(assets_dir).resolve(strict=True)
    work = destination / '.installer/hd-textures/work'
    output = destination / '.installer/hd-textures/dkq3-textures_hd.pk3'
    models = destination / '.installer/models/models.json'
    plan = root / 'textures/hd-plan.json'
    guard = bundle_tool(bundle, 'dkguard')
    subprocess.run([str(python), '-m', 'pip', 'install', '--disable-pip-version-check', '-r',
                    str(bundle / 'dkq3/tools/requirements-hd.txt')], check=True)
    subprocess.run([str(python), '-c',
                    'import torch; assert torch.cuda.is_available(), "HD generation needs a CUDA-capable GPU and CUDA-enabled PyTorch"'],
                   check=True)
    subprocess.run([str(python), str(bundle / 'dkq3/tools/hd_models.py'), '--stage', stages[-1],
                    '--out', str(models.parent)], check=True)
    subprocess.run([str(python), str(bundle / 'dkq3/tools/hd_plan.py'), '--textures-manifest',
                    str(root / 'textures/textures.json'), '--out', str(plan)], check=True)
    common = [str(producer), '--textures-manifest', str(root / 'textures/textures.json'),
              '--images', str(root / 'images/png'), '--plan', str(plan), '--work', str(work)]
    for stage in stages:
        print(f'Generating {stage} textures. This can take hours; completed entries resume on the next run.', flush=True)
        subprocess.run([str(guard), '--gpu', '--mem', '64G', '--timeout', '86400', '--', str(python),
                        *common, '--stage', stage, '--models', str(models)], check=True)
    subprocess.run([str(guard), '--mem', '4G', '--timeout', '600', '--', str(python), *common,
                    '--stage', 'pack', '--out', str(output), '--report', str(output.with_suffix('.json')),
                    '--summary', str(output.with_suffix('.txt'))], check=True)
    return output


def install(bundle: Path, source: Path, destination: Path, profile: str, stages: list[str]) -> None:
    if source == destination or source in destination.parents or destination in source.parents:
        raise ValueError('install destination must be separate from original game data')
    destination.mkdir(parents=True, exist_ok=True)
    python = python_environment(bundle, destination)
    ffmpeg = bundle / 'runtime/ffmpeg' / ('ffmpeg.exe' if os.name == 'nt' else 'ffmpeg')
    if not ffmpeg.is_file():
        raise ValueError(f'release bundle is missing FFmpeg: {ffmpeg}')
    assets_dir = destination / '.installer/assets'
    subprocess.run([str(bundle_tool(bundle, 'dkguard')), '--mem', '8G', '--timeout', '14400', '--',
                    str(python), str(bundle / 'dkq3/tools/assets.py'), '--data', str(source), '--profile', profile,
                    '--out', str(assets_dir), '--ffmpeg', str(ffmpeg), '--dkguard', str(bundle_tool(bundle, 'dkguard')),
                    '--bspc', str(bundle_tool(bundle, 'bspc'))], check=True)
    hd = generate_hd(bundle, python, destination, assets_dir, stages) if stages else None
    copy_products(bundle, destination)
    play.install(destination, assets_dir, hd_textures=hd)
    write_launcher(destination)
    print(f'Installed dk3 at {assets.current_generation(destination / "play")}')
    print('Original Daikatana files were read only. Settings and saves use this dk3 installation.')


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--bundle', type=Path, default=Path(__file__).resolve().parents[2])
    parser.add_argument('--source', type=Path)
    parser.add_argument('--destination', type=Path)
    parser.add_argument('--profile', choices=('retail', '1.3'))
    parser.add_argument('--hd-stages', choices=('none', 'esrgan', 'sdxl', 'flux'))
    args = parser.parse_args(argv)
    try:
        verify_bundle(args.bundle.resolve(strict=True))
        source = game_data(args.source) if args.source else source_selection()
        if source is None:
            raise ValueError('source has no Daikatana data')
        destination = (args.destination or Path.home() / 'Games/dk3').expanduser().resolve()
        if args.destination is None:
            entered = input(f'Install destination [{destination}]: ').strip()
            if entered:
                destination = Path(entered).expanduser().resolve()
        profile = args.profile or profile_for(source)
        if args.profile is None:
            print(f'Using detected {profile} asset profile.')
        stage = args.hd_stages or ('none', 'esrgan', 'sdxl', 'flux')[choose(
            'Optional locally generated HD textures (can need hours, large downloads, and a powerful GPU)',
            ['Original textures (default)', 'RealESRGAN 4×', 'RealESRGAN + SDXL', 'RealESRGAN + SDXL + FLUX'])]
        stages = {'none': [], 'esrgan': ['esrgan'], 'sdxl': ['esrgan', 'sdxl'],
                  'flux': ['esrgan', 'sdxl', 'flux']}[stage]
        if stages:
            print('HD generation requires a CUDA-capable GPU, substantial free disk space, and may take many hours.')
            print('HD models and dependencies are downloaded for local use only. Review their terms before continuing.')
            if input('Download models and start generation? [y/N]: ').strip().lower() != 'y':
                raise ValueError('HD generation declined')
        install(args.bundle.resolve(strict=True), source, destination, profile, stages)
        return 0
    except (OSError, ValueError, subprocess.CalledProcessError) as error:
        print(f'install wizard: {error}', file=sys.stderr)
        return 1


if __name__ == '__main__':
    sys.exit(main())
