# SPDX-License-Identifier: GPL-2.0-or-later
"""FLUX upscale that respects tiling: generate on a 2x2 tiled canvas and take the
centre window, so every edge of the result was generated with real context on
both sides instead of at a canvas border.

Arguments are parsed before torch or diffusers load, so a usage error never touches the GPU.
"""
import argparse, sys, os, json, time
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import numpy as np
import dkimg, postfx

SCALE = 4
JOBS = [('textures/e1m2/sefill2', 'rusty riveted iron plate, corroded metal, flat albedo texture'),
        ('textures/e3m3/dungbrk1', 'medieval dungeon brick wall, cracked damp stone, deep mortar, flat albedo texture')]


def upscale_seamless(pipe, src_dir, key, prompt, steps=24, cscale=0.35, sigma=6.0):
    from PIL import Image
    src = dkimg.read_png(f'{src_dir}/{key}.png')[..., :3]
    h, w = src.shape[:2]
    canvas = np.concatenate([np.concatenate([src, src], 1)] * 2, 0)      # 2x2, seamless by construction
    ctl = Image.fromarray(canvas).resize((w*2*SCALE, h*2*SCALE), Image.LANCZOS)
    t0 = time.time()
    out = pipe(prompt=prompt, control_image=ctl, controlnet_conditioning_scale=cscale,
               num_inference_steps=steps, guidance_scale=3.5,
               height=h*2*SCALE, width=w*2*SCALE).images[0]
    gen = np.array(out)
    H, W = h*SCALE, w*SCALE
    # centre window of one tile, offset by half a tile in both axes
    y0, x0 = H // 2, W // 2
    win = gen[y0:y0+H, x0:x0+W]
    # the matching source reference is the source rolled by half a tile
    s4 = np.array(Image.fromarray(src).resize((W, H), Image.LANCZOS))
    ref = np.roll(np.roll(s4, -H//2, 0), -W//2, 1)
    if sigma:
        win = postfx.band_merge(ref, win, sigma=sigma)
    # roll back so the texture keeps its original alignment
    win = np.roll(np.roll(win, H//2, 0), W//2, 1)
    return win, time.time() - t0


def parse_args(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split('\n\n')[0])
    ap.add_argument('--models', required=True, help='models.json written by fetch_models.py')
    ap.add_argument('--src', required=True, help='source PNG directory (dk_extract.py --out)')
    ap.add_argument('--out', required=True,
                    help='directory for seam_<key>.png and seamheal_<key>.png results')
    return ap.parse_args(argv)


def main(argv=None):
    args = parse_args(argv)
    import flux_run as R
    pipe = R.build(json.load(open(args.models)))
    os.makedirs(args.out, exist_ok=True)
    for k, p in JOBS:
        img, dt = upscale_seamless(pipe, args.src, k, p)
        u = k.replace('/', '_')
        dkimg.write_png(f'{args.out}/seam_{u}.png', img)
        healed = postfx.make_tileable(img)
        dkimg.write_png(f'{args.out}/seamheal_{u}.png', healed)
        print(f'{k}: {dt:.0f}s  seam before heal {postfx.seam_error(img):5.1f} '
              f'(flat-canvas FLUX was ~{"28" if "sefill" in k else "57"}), '
              f'light {postfx.light_spread(img):4.1f}', flush=True)


if __name__ == '__main__':
    main()
