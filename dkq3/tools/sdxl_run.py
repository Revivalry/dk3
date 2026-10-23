# SPDX-License-Identifier: GPL-2.0-or-later
"""SDXL + xinsir tile ControlNet, img2img over the ESRGAN scaffold.

Model directories come from the models.json index written by fetch_models.py; torch and diffusers
load only when a pipeline is built.
"""
import sys, os, time
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import numpy as np
import dkimg

NEG = 'blurry, smooth, plastic, cartoon, painting, text, watermark, jpeg artifacts'


def build(models, circular=True):
    """models: the models.json index (model name -> directory)."""
    import torch
    import dkenv  # noqa: F401  (stubs a broken xformers before diffusers imports it)
    from diffusers import (StableDiffusionXLControlNetImg2ImgPipeline, ControlNetModel,
                           AutoencoderKL, DPMSolverMultistepScheduler)
    t0 = time.time()
    cn = ControlNetModel.from_pretrained(models['tile-sdxl'], torch_dtype=torch.float16)
    vae = AutoencoderKL.from_pretrained(models['sdxl-vae'], torch_dtype=torch.float16)
    pipe = StableDiffusionXLControlNetImg2ImgPipeline.from_pretrained(
        models['sdxl'], controlnet=cn, vae=vae, torch_dtype=torch.float16,
        variant='fp16', use_safetensors=True)
    pipe.scheduler = DPMSolverMultistepScheduler.from_config(pipe.scheduler.config)
    pipe.enable_model_cpu_offload()
    pipe.set_progress_bar_config(disable=True)
    if circular:
        import torch.nn as nn
        for mod in list(pipe.unet.modules()) + list(pipe.vae.modules()) + list(pipe.controlnet.modules()):
            if isinstance(mod, nn.Conv2d):
                mod.padding_mode = 'circular'
    print(f'sdxl pipeline ready in {time.time()-t0:.0f}s', flush=True)
    return pipe


def upscale(pipe, src_dir, up4x_dir, key, prompt, strength=0.5, steps=28, seed=1234):
    import torch
    from PIL import Image
    src = dkimg.read_png(f'{src_dir}/{key}.png')[..., :3]
    esr = dkimg.read_png(f'{up4x_dir}/{key}.png')[..., :3]
    h, w = src.shape[:2]
    gw, gh = min(1536, max(768, w*4)), min(1536, max(768, h*4))
    gw, gh = gw - gw % 8, gh - gh % 8
    init = Image.fromarray(esr).resize((gw, gh), Image.LANCZOS)
    g = torch.Generator('cuda').manual_seed(seed)
    t0 = time.time()
    out = pipe(prompt=prompt + ', seamless tileable texture, sharp material detail, photo',
               negative_prompt=NEG, image=init, control_image=init, strength=strength,
               num_inference_steps=steps, guidance_scale=6.0,
               controlnet_conditioning_scale=0.8, generator=g).images[0]
    return np.array(out.resize((w*4, h*4), Image.LANCZOS)), time.time() - t0
