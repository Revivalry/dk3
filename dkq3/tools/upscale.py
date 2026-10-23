#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-or-later
"""4x upscale every extracted Daikatana asset.

 - tiling world textures use circular conv padding, so the result stays seamless
 - 8-bit (WAL-sourced) art gets a de-dither pass first, or ESRGAN amplifies the
   palette dithering into permanent speckle
 - alpha is upscaled separately and never fed through the RGB model

Arguments are parsed before torch loads, so a usage error never touches the GPU.
"""
import sys, os, json, time, argparse
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import numpy as np
import dkimg

TILING = ('textures',)          # categories that wrap; env/pics/skins/fonts do not


def median3(x):
    """3x3 median, circular or replicate padded. x: (1,3,H,W)"""
    import torch
    import torch.nn.functional as F
    p = F.pad(x, (1, 1, 1, 1), mode='replicate')
    st = torch.stack([p[..., i:i+x.shape[-2], j:j+x.shape[-1]]
                      for i in range(3) for j in range(3)], dim=0)
    return st.median(dim=0).values


def dedither(x, strength=0.6):
    """Blend toward a 3x3 median only where local variance says 'dither', so
    real edges survive."""
    med = median3(x)
    diff = (x - med).abs().mean(1, keepdim=True)
    w = (diff * 6.0).clamp(0, 1) * strength
    return x * (1 - w) + med * w


def seam_error(img):
    """mean abs difference across the wrap seam (0 = perfectly tileable)"""
    a = img.astype(np.int16)
    return float((np.abs(a[:, 0] - a[:, -1]).mean() + np.abs(a[0] - a[-1]).mean()) / 2)


def parse_args(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split('\n\n')[0])
    ap.add_argument('--weights', required=True,
                    help='ESRGAN 4x weights (.pth), e.g. 4x-UltraSharp.pth or RealESRGAN_x4plus.pth')
    ap.add_argument('--manifest', required=True, help='manifest.json written by dk_extract.py')
    ap.add_argument('--src', required=True, help='source PNG directory (dk_extract.py --out)')
    ap.add_argument('--out', required=True,
                    help='output PNG directory; progress is appended to <out>.log beside it')
    ap.add_argument('--category', default=None)
    ap.add_argument('--limit', type=int, default=0)
    ap.add_argument('--only', default=None, help='substring filter on asset key')
    ap.add_argument('--no-dedither', action='store_true')
    return ap.parse_args(argv)


def main(argv=None):
    args = parse_args(argv)
    import torch
    import torch.nn.functional as F
    import rrdb

    man = json.load(open(args.manifest))
    items = [(k, v) for k, v in man.items() if 'error' not in v]
    if args.category: items = [(k, v) for k, v in items if v['category'] == args.category]
    if args.only:     items = [(k, v) for k, v in items if args.only in k]
    items.sort(key=lambda kv: -kv[1].get('faces', 0))
    if args.limit: items = items[:args.limit]

    dev = 'cuda'
    nets = {t: rrdb.load_esrgan(args.weights, dev, circular=t) for t in (True, False)}
    outdir = args.out
    t0 = time.time(); done = 0; skipped = 0; px = 0; seams = []
    log = open(os.path.normpath(args.out) + '.log', 'a')

    for k, v in items:
        dst = os.path.join(outdir, k + '.png')
        if os.path.exists(dst):
            skipped += 1; continue
        img = dkimg.read_png(os.path.join(args.src, k + '.png'))
        rgb, alpha = img[..., :3], (img[..., 3] if img.shape[2] == 4 else None)
        tile = v['category'] in TILING
        net = nets[tile]

        x = torch.from_numpy(rgb).to(dev).permute(2, 0, 1)[None].float() / 255.
        if v.get('bits') == 8 and not args.no_dedither:
            x = dedither(x)
        with torch.no_grad(), torch.autocast('cuda', torch.float16):
            y = net(x)
        out = (y[0].float().clamp(0, 1).permute(1, 2, 0) * 255).round().byte().cpu().numpy()

        if alpha is not None:
            a = torch.from_numpy(alpha).to(dev)[None, None].float()
            a = F.interpolate(a, scale_factor=4, mode='bilinear', align_corners=False)
            out = np.dstack([out, a[0, 0].clamp(0, 255).round().byte().cpu().numpy()])

        os.makedirs(os.path.dirname(dst), exist_ok=True)
        dkimg.write_png(dst, out)
        if tile:
            seams.append((seam_error(out), seam_error(img), k))
        done += 1; px += out.shape[0] * out.shape[1]
        if done % 100 == 0:
            el = time.time() - t0
            print(f'{done}/{len(items)-skipped}  {el:.0f}s  {done/el:.1f} img/s  '
                  f'{px/1e6/el:.1f} MPix/s', flush=True)
            log.write(f'{done} {el:.0f}\n'); log.flush()

    el = time.time() - t0
    print(f'done {done} (skipped {skipped}) in {el:.0f}s -> {outdir}')
    if seams:
        after = np.mean([s[0] for s in seams]); before = np.mean([s[1] for s in seams])
        print(f'wrap-seam error: source {before:.2f} -> upscaled {after:.2f} (lower = more tileable)')


if __name__ == '__main__':
    main()
