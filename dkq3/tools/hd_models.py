#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-or-later
"""Fetch only the locally selected HD models, without storing credentials."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import urllib.request

ESRGAN_URL = 'https://github.com/xinntao/Real-ESRGAN/releases/download/v0.1.0/RealESRGAN_x4plus.pth'
ESRGAN_SHA256 = '4fa0d38905f75ac06eb49a7951b426670021be3018265fd191d2125df9d682f1'

# Patterns are the reviewed production inputs. The optional FLUX repository is
# gated; the user's own Hugging Face access and model terms are required.
REPOS = {
    'sdxl': ('stabilityai/stable-diffusion-xl-base-1.0',
             ['model_index.json', 'scheduler/*', 'vae/*', 'text_encoder/*', 'text_encoder_2/*',
              'tokenizer/*', 'tokenizer_2/*', 'unet/config.json', 'unet/*fp16.safetensors']),
    'sdxl-vae': ('madebyollin/sdxl-vae-fp16-fix', ['config.json', 'diffusion_pytorch_model.safetensors']),
    'tile-sdxl': ('xinsir/controlnet-tile-sdxl-1.0', ['config.json', 'diffusion_pytorch_model.safetensors']),
    'flux': ('black-forest-labs/FLUX.1-dev',
             ['model_index.json', 'scheduler/*', 'vae/*', 'text_encoder/*', 'text_encoder_2/*',
              'tokenizer/*', 'tokenizer_2/*', 'transformer/*']),
    'flux-upscale': ('jasperai/Flux.1-dev-Controlnet-Upscaler',
                    ['config.json', 'diffusion_pytorch_model.safetensors']),
}


def digest(path):
    result = hashlib.sha256()
    with path.open('rb') as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b''):
            result.update(chunk)
    return result.hexdigest()


def download_esrgan(root):
    path = root / 'RealESRGAN_x4plus.pth'
    if path.is_file() and digest(path) == ESRGAN_SHA256:
        return path
    partial = path.with_suffix('.partial')
    with urllib.request.urlopen(ESRGAN_URL, timeout=60) as response, partial.open('wb') as output:
        while chunk := response.read(1024 * 1024):
            output.write(chunk)
    if digest(partial) != ESRGAN_SHA256:
        partial.unlink()
        raise ValueError('RealESRGAN model hash mismatch')
    partial.replace(path)
    return path


def download_repo(root, name):
    from huggingface_hub import snapshot_download
    repo, patterns = REPOS[name]
    target = root / name
    snapshot_download(repo_id=repo, local_dir=target, allow_patterns=patterns,
                      token=os.environ.get('HF_TOKEN') or None)
    return target


def fetch(root, stage):
    root.mkdir(parents=True, exist_ok=True)
    index = root / 'models.json'
    models = json.loads(index.read_text()) if index.is_file() else {}
    models['esrgan'] = str(download_esrgan(root).resolve())
    if stage in ('sdxl', 'flux'):
        for name in ('sdxl', 'sdxl-vae', 'tile-sdxl'):
            models[name] = str(download_repo(root, name).resolve())
    if stage == 'flux':
        for name in ('flux', 'flux-upscale'):
            models[name] = str(download_repo(root, name).resolve())
    partial = index.with_suffix('.partial')
    partial.write_text(json.dumps(models, sort_keys=True, indent=2) + '\n')
    partial.replace(index)
    return index


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--stage', choices=('esrgan', 'sdxl', 'flux'), required=True)
    parser.add_argument('--out', type=Path, required=True)
    args = parser.parse_args()
    print(fetch(args.out, args.stage))


if __name__ == '__main__':
    main()
