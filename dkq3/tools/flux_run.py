# SPDX-License-Identifier: GPL-2.0-or-later
"""FLUX.1-dev + jasperai upscaler ControlNet, fp8-quantised to fit 24 GB.

Model directories come from the models.json index written by fetch_models.py. Arguments are parsed
before torch or diffusers load, so a usage error never touches the GPU.
"""
import argparse, sys, os, time, json
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import numpy as np
import dkimg

DEFAULT_KEYS = ['textures/e3m3/dungbrk1']


def build(models):
    """models: the models.json index (model name -> directory)."""
    import torch
    import dkenv  # noqa: F401  (stubs a broken xformers before diffusers imports it)
    from diffusers import (FluxControlNetModel, FluxControlNetPipeline, FluxTransformer2DModel,
                           BitsAndBytesConfig as DiffusersBnb)
    from transformers import T5EncoderModel, BitsAndBytesConfig as TransformersBnb
    t0 = time.time()
    # NF4: 23.8 GB transformer -> ~6.5 GB, so it fits a 24 GB card
    nf4 = dict(load_in_4bit=True, bnb_4bit_quant_type='nf4',
               bnb_4bit_compute_dtype=torch.bfloat16)
    tr = FluxTransformer2DModel.from_pretrained(
        models['flux'], subfolder='transformer', torch_dtype=torch.bfloat16,
        quantization_config=DiffusersBnb(**nf4))
    te = T5EncoderModel.from_pretrained(
        models['flux'], subfolder='text_encoder_2', torch_dtype=torch.bfloat16,
        quantization_config=TransformersBnb(**nf4))
    cn = FluxControlNetModel.from_pretrained(models['flux-upscale'], torch_dtype=torch.bfloat16)
    pipe = FluxControlNetPipeline.from_pretrained(models['flux'], transformer=tr, text_encoder_2=te,
                                                  controlnet=cn, torch_dtype=torch.bfloat16)
    pipe.enable_model_cpu_offload()
    pipe.set_progress_bar_config(disable=True)
    print(f'pipeline ready in {time.time()-t0:.0f}s', flush=True)
    return pipe


def upscale(pipe, src_dir, key, steps=28, cscale=0.6, prompt=''):
    from PIL import Image
    src = dkimg.read_png(f'{src_dir}/{key}.png')[..., :3]
    h, w = src.shape[:2]
    ctl = Image.fromarray(src).resize((w*4, h*4), Image.LANCZOS)
    t0 = time.time()
    out = pipe(prompt=prompt, control_image=ctl, controlnet_conditioning_scale=cscale,
               num_inference_steps=steps, guidance_scale=3.5,
               height=h*4, width=w*4).images[0]
    return np.array(out), time.time() - t0


def parse_args(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split('\n\n')[0])
    ap.add_argument('keys', nargs='*', default=DEFAULT_KEYS,
                    help='asset keys to upscale (default: %(default)s)')
    ap.add_argument('--models', required=True, help='models.json written by fetch_models.py')
    ap.add_argument('--src', required=True, help='source PNG directory (dk_extract.py --out)')
    ap.add_argument('--out', required=True, help='directory for flux_<key>.png results')
    return ap.parse_args(argv)


def main(argv=None):
    args = parse_args(argv)
    import torch
    pipe = build(json.load(open(args.models)))
    os.makedirs(args.out, exist_ok=True)
    for key in args.keys:
        img, dt = upscale(pipe, args.src, key)
        dkimg.write_png(f'{args.out}/flux_{key.replace("/","_")}.png', img)
        print(f'{key}: {img.shape[1]}x{img.shape[0]} in {dt:.1f}s | '
              f'peak VRAM {torch.cuda.max_memory_allocated()/2**30:.1f} GB', flush=True)


if __name__ == '__main__':
    main()
