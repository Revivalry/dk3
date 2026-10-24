#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-or-later
"""Fetch reviewed, digest-checked redistributables for a release bundle.

Only CI uses this tool. Retail Daikatana data and NVIDIA libraries are excluded.
"""
import argparse
import gzip
import hashlib
from http.client import IncompleteRead
import io
import json
from pathlib import Path
import re
import subprocess
import tarfile
import time
from urllib.request import Request, urlopen
from urllib.error import URLError
import zipfile


PYTHON_BUILD = '20261021'
PYTHON_VERSION = '3.12.15'
FFMPEG_WHEEL = '0.6.0'  # embeds FFmpeg 7.0.2 (Linux) and 7.1 (Windows)
PLATFORMS = {
    'linux-x64': ('x86_64-unknown-linux-gnu', 'manylinux', 'ffmpeg-linux-x86_64', '7.0.2',
                  '6d7521138fd33afddc1ccd08abb007d9a2829e38117c2576f9efdc0ec73ce772'),
    'windows-x64': ('x86_64-pc-windows-msvc', 'win_amd64', 'ffmpeg-win-x86_64', '7.1',
                    'aac5d331fc3307343f95928fdbea4583f0d53973d08c7e1d081884fbd229a0e1'),
}


def fetch(url: str) -> bytes:
    headers = {'User-Agent': 'dk3-release-inputs/1', 'Accept': 'application/vnd.github+json',
               'Accept-Encoding': 'gzip'}
    for attempt in range(3):
        try:
            with urlopen(Request(url, headers=headers), timeout=120) as response:
                content = response.read()
                return gzip.decompress(content) if response.headers.get('Content-Encoding') == 'gzip' else content
        except (IncompleteRead, URLError, TimeoutError):
            if attempt == 2:
                raise
            time.sleep(attempt + 1)
    raise AssertionError('unreachable')


def checked(url: str, expected: str) -> bytes:
    content = fetch(url)
    actual = hashlib.sha256(content).hexdigest()
    if actual != expected.removeprefix('sha256:'):
        raise ValueError(f'digest mismatch for {url}: {actual}')
    return content


def python_runtime(platform: str, root: Path) -> None:
    target, _, _, _, digest = PLATFORMS[platform]
    name = f'cpython-{PYTHON_VERSION}%2B{PYTHON_BUILD}-{target}-install_only_stripped.tar.gz'
    archive = checked(f'https://github.com/astral-sh/python-build-standalone/releases/download/{PYTHON_BUILD}/{name}', digest)
    with tarfile.open(fileobj=io.BytesIO(archive), mode='r:gz') as tar:
        if any(member.name != 'python' and not member.name.startswith('python/')
               for member in tar.getmembers()):
            raise ValueError('unexpected portable Python archive layout')
        tar.extractall(root, filter='data')
    binary = root / 'python' / ('python.exe' if platform == 'windows-x64' else 'bin/python3')
    if not binary.is_file():
        raise ValueError(f'portable Python lacks {binary}')


def pypi_wheel(package: str, version: str, platform: str) -> tuple[str, bytes]:
    metadata = json.loads(fetch(f'https://pypi.org/pypi/{package}/{version}/json'))
    tag = PLATFORMS[platform][1]
    candidates = [item for item in metadata['urls']
                  if item['filename'].endswith('.whl')
                  and (item['filename'].endswith('-none-any.whl') or
                       (tag in item['filename'] and
                        (platform != 'linux-x64' or item['filename'].endswith('x86_64.whl'))))
                  and (package != 'numpy' or '-cp312-cp312-' in item['filename'])]
    if len(candidates) != 1:
        raise ValueError(f'expected one {package} {version} wheel for {platform}, found {len(candidates)}')
    item = candidates[0]
    return item['filename'], checked(item['url'], item['digests']['sha256'])


def ffmpeg(platform: str, root: Path) -> None:
    _, wheel = pypi_wheel('imageio-ffmpeg', FFMPEG_WHEEL, platform)
    ffmpeg_version = PLATFORMS[platform][3]
    with zipfile.ZipFile(io.BytesIO(wheel)) as archive:
        binary_paths = [name for name in archive.namelist()
                        if name.startswith('imageio_ffmpeg/binaries/')
                        and Path(name).name.startswith(PLATFORMS[platform][2])
                        and f'v{ffmpeg_version}' in name]
        if len(binary_paths) != 1:
            raise ValueError(f'expected one FFmpeg 7 binary for {platform}')
        target = root / ('ffmpeg.exe' if platform == 'windows-x64' else 'ffmpeg')
        target.write_bytes(archive.read(binary_paths[0]))
        target.chmod(0o755)
        license_paths = [name for name in archive.namelist()
                         if name.lower().endswith(('/license', '/license.txt'))
                         and '.dist-info/' in name]
        if len(license_paths) != 1:
            raise ValueError('imageio-ffmpeg wheel lacks its license')
        wrapper_license = archive.read(license_paths[0]).decode()
    # Preserve both the wrapper notice and the FFmpeg license text. FFmpeg's
    # exact configured license can also be inspected with `ffmpeg -L`.
    licenses = [
        f'imageio-ffmpeg {FFMPEG_WHEEL} binary wheel: https://pypi.org/project/imageio-ffmpeg/{FFMPEG_WHEEL}/\n',
        'Packaged binary source: https://github.com/imageio/imageio-binaries/tree/master/ffmpeg\n',
        f'FFmpeg {ffmpeg_version} source: https://github.com/FFmpeg/FFmpeg/tree/n{ffmpeg_version}\n',
        '\nimageio-ffmpeg license:\n', wrapper_license,
    ]
    if platform == 'linux-x64':
        licenses.extend(('\nFFmpeg build and license report:\n',
                         subprocess.check_output([str(target), '-L'], text=True,
                                                 stderr=subprocess.STDOUT)))
    for name in ('COPYING.GPLv2', 'COPYING.GPLv3', 'COPYING.LGPLv2.1', 'COPYING.LGPLv3'):
        licenses.extend((f'\nFFmpeg {name}:\n',
                         fetch(f'https://raw.githubusercontent.com/FFmpeg/FFmpeg/n{ffmpeg_version}/{name}').decode()))
    (root / 'ffmpeg-license.txt').write_text(''.join(licenses))


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--platform', choices=PLATFORMS, required=True)
    parser.add_argument('--out', type=Path, required=True)
    args = parser.parse_args()
    if args.out.exists():
        parser.error(f'output already exists: {args.out}')
    args.out.mkdir(parents=True)
    python_runtime(args.platform, args.out)
    requirement = (Path(__file__).parent / 'requirements.txt').read_text().strip()
    if not re.fullmatch(r'numpy==[0-9]+\.[0-9]+\.[0-9]+', requirement):
        raise ValueError('expected one pinned NumPy dependency')
    filename, content = pypi_wheel('numpy', requirement.split('==')[1], args.platform)
    wheels = args.out / 'wheels'
    wheels.mkdir()
    (wheels / filename).write_bytes(content)
    for requirement in (Path(__file__).parent / 'requirements-tui.txt').read_text().splitlines():
        package, version = requirement.split('==')
        filename, content = pypi_wheel(package, version, args.platform)
        (wheels / filename).write_bytes(content)
    ffmpeg(args.platform, args.out)
    print(args.out)


if __name__ == '__main__':
    main()
