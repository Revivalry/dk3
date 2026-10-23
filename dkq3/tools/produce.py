#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-or-later
"""Produce the HD (4x) counterpart of every texture of `dkq3-textures.pk3` and package it as `dkq3-textures_hd.pk3`.

Stages, each a separate run (`--stage`); the GPU stages run only under `dkguard --gpu --mem` (build/assets.zig):
  esrgan : RealESRGAN x4 (RRDBNet, circular padding, de-dither for 8-bit sources) for every entry of the hero, mid, tail
           and keep tiers; the floor every packaged entry stands on
  sdxl   : SDXL + tile ControlNet img2img over the esrgan result for hero and mid entries, band-merged against the source
  flux   : FLUX.1-dev + upscaler ControlNet on a 2x2 wrap-safe canvas for hero entries, band-merged and seam-healed
  pack   : no GPU: dkq3-textures_hd.pk3 (the best stage of every entry whose source is unchanged), the report and the
           summary

The work directory holds `<stage>/<entry>.png` beside `<stage>/<entry>.json` (source sha256, sizes, seam error, lighting
spread, seconds) and `<stage>/model.json` (sha256 of every weight file the stage loaded). A run is resumable: an entry whose
sidecar names the current source sha256 is skipped; staleness is never read from a timestamp. `--budget` ends a run cleanly
before its dkguard timeout. Arguments are parsed before torch, PIL or diffusers load, so a usage error never touches the GPU.

Spec: specs/assets/ASSET-textures-hd.md. FRD: specs/frds/FRD-021-upscaled-texture-variant-package.md
"""
import argparse
import collections
import hashlib
import json
import os
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import pk3  # noqa: E402

PREFIX = 'produce:'
SCALE = 4
PNG_SUFFIX = '.png'
STAGES = ('esrgan', 'sdxl', 'flux')
PACK = 'pack'
# The best stage first: pack takes the first of these an entry has with the current source.
STAGE_RANK = ('flux', 'sdxl', 'esrgan')
# Which tiers each stage produces (specs/assets/ASSET-textures-hd.md, "Tier rules").
STAGE_TIERS = {'esrgan': ('hero', 'mid', 'tail', 'keep'), 'sdxl': ('hero', 'mid'), 'flux': ('hero',)}
# Tiers no stage produces, with the reason recorded per entry.
UNPRODUCED = {'skip': 'utility surface (nodraw, clip, hint, trigger, origin): never drawn',
              'sky': 'sky surface: drawn from the env/32bit sides of dkq3-shaders.pk3, not from the texture'}
STALE = 'stale: the source image changed after production'
NOT_YET = 'not produced yet'
WRONG_SIZE = 'wrong size'
PACKAGE_NAME = 'dkq3-textures_hd.pk3'
ORIGINAL_NAME = 'dkq3-textures.pk3'
# The package holds images only. r_picmip defaults to 1 (code/renderergl1/tr_init.c:1030) and halves every upload; the
# play tree sets it to 0 with a loose autoexec.cfg (build/hd_textures.zig), because ioquake3 loads autoexec.cfg and
# q3config.cfg only from directories, never from a pk3 (code/qcommon/files.c:1341-1344).
SIDECAR_KEYS = ('stage', 'source_sha256', 'w', 'h', 'W', 'H', 'seam_source', 'seam', 'spread_source', 'spread', 'seconds')
WAL = '.wal'
DEFAULT_PROMPT = 'weathered surface, flat albedo texture'


def fs_path_cmp(a, b):
    """ioquake3's FS_PathCmp (code/qcommon/files.c:2656-2688): letters upper-cased, `\\` and `:` as `/`, then byte order.
    paksort sorts a directory's pk3s with it and FS_AddGameDirectory adds each to the head of the search path
    (files.c:2915, :2968-2969), so the name that sorts LAST is searched FIRST."""
    for c1, c2 in zip(a.encode() + b'\0', b.encode() + b'\0'):
        c1, c2 = (c - 32 if 97 <= c <= 122 else 47 if c in (92, 58) else c for c in (c1, c2))
        if c1 != c2:
            return -1 if c1 < c2 else 1
        if c1 == 0:
            return 0
    return 0


def overrides(name, other):
    """True when a pk3 called `name` is searched before one called `other` in the same directory."""
    return fs_path_cmp(name, other) > 0


def sha256_file(path):
    """sha256 of a file, read in chunks (the diffusion interpreter is Python 3.10, without hashlib.file_digest)."""
    digest = hashlib.sha256()
    with open(path, 'rb') as f:
        for chunk in iter(lambda: f.read(1 << 20), b''):
            digest.update(chunk)
    return digest.hexdigest()


def sha256_paths(paths):
    """{path: sha256} of every regular file in `paths` (a directory is walked), sorted."""
    files = []
    for path in paths:
        if os.path.isdir(path):
            files += [os.path.join(root, leaf) for root, _, leaves in os.walk(path) for leaf in leaves]
        else:
            files.append(path)
    return {path: sha256_file(path) for path in sorted(set(files))}


def stem(entry):
    return entry[:-len(PNG_SUFFIX)] if entry.endswith(PNG_SUFFIX) else entry


def read_json(path):
    with open(path, encoding='utf-8') as f:
        return json.load(f)


def write_atomic(path, data):
    """Writes bytes to a temporary file beside `path` and renames it, so a killed run leaves no partial output."""
    os.makedirs(os.path.dirname(os.path.abspath(path)), exist_ok=True)
    tmp = path + '.tmp'
    with open(tmp, 'wb') as f:
        f.write(data)
    os.replace(tmp, path)


def write_json_atomic(path, value):
    write_atomic(path, (json.dumps(value, indent=1, sort_keys=True) + '\n').encode('utf-8'))


def sidecar(work, stage, entry):
    return os.path.join(work, stage, stem(entry) + '.json')


def output(work, stage, entry):
    return os.path.join(work, stage, entry)


def read_sidecar(work, stage, entry):
    """The sidecar of `entry` at `stage`, or None when it or its PNG is absent or it is malformed."""
    path = sidecar(work, stage, entry)
    if not (os.path.exists(path) and os.path.exists(output(work, stage, entry))):
        return None
    try:
        record = read_json(path)
    except ValueError:
        return None
    return record if all(key in record for key in SIDECAR_KEYS) else None


def entries(textures_manifest, plan):
    """[(entry, record)] of every packed entry, sorted by entry name, each record with its tier and prompt from the plan."""
    found = []
    for name, record in sorted(textures_manifest['textures'].items()):
        planned = plan.get(record['key'], {})
        found.append((record['entry'], dict(record, name=name, tier=planned.get('tier', 'tail'),
                                            prompt=planned.get('prompt') or DEFAULT_PROMPT, area=planned.get('area', 0.0))))
    return found


def priority(record, maps):
    """Entries drawn by the first of `maps` first, then the largest drawn area, then the name."""
    drawn = [i for i, name in enumerate(maps) if f'maps/{name}.bsp' in record['maps']]
    return (drawn[0] if drawn else len(maps), -record['area'], record['name'])


def todo(work, stage, items, images, maps, limit):
    """The entries `stage` still has to produce, in priority order: the stage's tiers, restricted to `maps` for the
    diffusion stages, without a sidecar of this or a better stage naming the current source sha256."""
    chosen = []
    better = STAGE_RANK[:STAGE_RANK.index(stage) + 1]
    for entry, record in items:
        if record['tier'] not in STAGE_TIERS[stage]:
            continue
        if stage != 'esrgan' and maps and not any(f'maps/{name}.bsp' in record['maps'] for name in maps):
            continue
        source = sha256_file(os.path.join(images, entry))
        if any((read_sidecar(work, done, entry) or {}).get('source_sha256') == source for done in better):
            continue
        chosen.append((entry, dict(record, source_sha256=source)))
    chosen.sort(key=lambda item: priority(item[1], maps))
    return chosen[:limit] if limit else chosen


def light_spread(img, blocks=8):
    """Standard deviation of the mean luma over a `blocks` x `blocks` grid (postfx.light_spread, with the grid clamped to
    the image so a texture narrower than 8 texels measures too): baked lighting shows as a spread the flat albedo lacks."""
    import numpy as np
    luma = (img[..., :3].astype(np.float32) * [0.299, 0.587, 0.114]).sum(-1)
    h, w = luma.shape
    by, bx = min(blocks, h), min(blocks, w)
    bh, bw = h // by, w // bx
    return float(luma[:bh * by, :bw * bx].reshape(by, bh, bx, bw).mean((1, 3)).std())


def metrics(src, out):
    """Seam error (dkq3/tools/postfx.py) and lighting spread of the source and the output."""
    import postfx
    return dict(seam_source=postfx.seam_error(src[..., :3]), seam=postfx.seam_error(out[..., :3]),
                spread_source=light_spread(src), spread=light_spread(out))


def finish(entry, out, src, record, stage, seconds, work):
    """Checks the exact SCALE (the shaders' `tcMod scale` comes from the original image size, specs/assets/ASSET-shaders.md
    "Redrawn TGAs", so every packaged image is SCALE times its source on both axes), then writes the PNG and its sidecar."""
    import dkimg
    h, w = src.shape[:2]
    if out.shape[:2] != (h * SCALE, w * SCALE):
        raise RuntimeError(f'{entry}: {stage} produced {out.shape[1]}x{out.shape[0]} for {w}x{h}, not {SCALE}x')
    if (src.shape[2] == 4) != (out.shape[2] == 4):
        raise RuntimeError(f'{entry}: {stage} changed the channel count')
    write_atomic(output(work, stage, entry), dkimg.encode_png(out))
    write_json_atomic(sidecar(work, stage, entry), dict(stage=stage, source_sha256=record['source_sha256'], w=w, h=h,
                                                        W=w * SCALE, H=h * SCALE, seconds=round(seconds, 2),
                                                        **{k: round(v, 3) for k, v in metrics(src, out).items()}))


def alpha4x(src):
    """The alpha channel resampled bilinearly, never fed through an RGB model; None for an RGB source."""
    if src.shape[2] != 4:
        return None
    import numpy as np
    from PIL import Image
    a = src[..., 3]
    return np.array(Image.fromarray(a).resize((a.shape[1] * SCALE, a.shape[0] * SCALE), Image.BILINEAR))


def with_alpha(rgb, src):
    import numpy as np
    a = alpha4x(src)
    return rgb if a is None else np.dstack([rgb, a])


def merge(rgb, src, sigma=6.0):
    """The model's detail on the source's tone and colour, the wrap seam healed (dkq3/tools/postfx.py), alpha restored."""
    import numpy as np
    import postfx
    from PIL import Image
    h, w = src.shape[:2]
    ref = np.array(Image.fromarray(np.ascontiguousarray(src[..., :3])).resize((w * SCALE, h * SCALE), Image.LANCZOS))
    return with_alpha(postfx.make_tileable(postfx.band_merge(ref, rgb, sigma=sigma)), src)


def parse_args(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split('\n\n')[0])
    ap.add_argument('--stage', required=True, choices=STAGES + (PACK,), help='what to run')
    ap.add_argument('--textures-manifest', required=True, help='textures.json written by pack_textures.py: the entries')
    ap.add_argument('--images', required=True, help='images directory written by dk_extract.py: the source PNGs')
    ap.add_argument('--plan', required=True, help='plan.json written by plan.py: tier and prompt per image key')
    ap.add_argument('--work', required=True, help='work directory: <stage>/<entry>.png, .json and model.json')
    ap.add_argument('--models', help='models.json written by fetch_models.py (model directories); GPU stages')
    ap.add_argument('--maps', action='append', default=[], metavar='MAP',
                    help='maps whose textures come first (esrgan) or alone (sdxl, flux); repeatable')
    ap.add_argument('--limit', type=int, default=0, help='at most N entries in this run (0: every one)')
    ap.add_argument('--budget', type=float, default=0.0, help='stop starting entries after this many seconds (0: never)')
    ap.add_argument('--steps-sdxl', type=int, default=20)
    ap.add_argument('--strength-sdxl', type=float, default=0.5)
    ap.add_argument('--steps-flux', type=int, default=16)
    ap.add_argument('--cscale-flux', type=float, default=0.65)
    ap.add_argument('--out', help='pack: the pk3 to write')
    ap.add_argument('--report', help='pack: the report JSON to write')
    ap.add_argument('--summary', help='pack: the summary text to write')
    args = ap.parse_args(argv)
    if args.stage == PACK and not (args.out and args.report and args.summary):
        ap.error('--stage pack needs --out, --report and --summary')
    if args.stage != PACK and not args.models:
        ap.error(f'--stage {args.stage} needs --models')
    return args


class Budget:
    def __init__(self, seconds):
        self.start, self.seconds = time.time(), seconds

    def spent(self):
        return bool(self.seconds) and time.time() - self.start > self.seconds


def run_esrgan(args, items, models):
    import numpy as np
    import torch
    import dkimg
    import rrdb
    import upscale
    weights = models['esrgan']
    write_json_atomic(os.path.join(args.work, 'esrgan', 'model.json'), dict(esrgan=sha256_paths([weights])))
    net = rrdb.load_esrgan(weights, 'cuda', circular=True)
    budget = Budget(args.budget)
    done = 0
    for entry, record in items:
        if budget.spent():
            break
        t0 = time.time()
        src = dkimg.read_png(os.path.join(args.images, entry))
        x = torch.from_numpy(np.ascontiguousarray(src[..., :3])).to('cuda').permute(2, 0, 1)[None].float() / 255.
        if record['src'].endswith(WAL):
            x = upscale.dedither(x)
        with torch.no_grad(), torch.autocast('cuda', torch.float16):
            y = net(x)
        rgb = (y[0].float().clamp(0, 1).permute(1, 2, 0) * 255).round().byte().cpu().numpy()
        finish(entry, with_alpha(rgb, src), src, record, 'esrgan', time.time() - t0, args.work)
        done += 1
        if done % 100 == 0:
            print(f'{PREFIX} esrgan {done}/{len(items)}', flush=True)
    return done


def run_sdxl(args, items, models):
    import torch
    import dkimg
    import sdxl_run
    write_json_atomic(os.path.join(args.work, 'sdxl', 'model.json'), {
        'sdxl': sha256_paths([os.path.join(models['sdxl'], part) for part in ('unet', 'text_encoder', 'text_encoder_2')]),
        'sdxl-vae': sha256_paths([models['sdxl-vae']]), 'tile-sdxl': sha256_paths([models['tile-sdxl']])})
    pipe = sdxl_run.build(models, circular=True)
    budget = Budget(args.budget)
    done = 0
    for entry, record in items:
        if budget.spent():
            break
        if read_sidecar(args.work, 'esrgan', entry) is None:
            print(f'{PREFIX} sdxl {entry}: no esrgan scaffold yet, skipped', flush=True)
            continue
        src = dkimg.read_png(os.path.join(args.images, entry))
        rgb, seconds = sdxl_run.upscale(pipe, args.images, os.path.join(args.work, 'esrgan'), stem(entry),
                                        record['prompt'], strength=args.strength_sdxl, steps=args.steps_sdxl)
        finish(entry, merge(rgb, src), src, record, 'sdxl', seconds, args.work)
        done += 1
        print(f'{PREFIX} sdxl {done}/{len(items)} {entry} {seconds:.1f}s', flush=True)
    del pipe
    torch.cuda.empty_cache()
    return done


def run_flux(args, items, models):
    import torch
    import dkimg
    import flux_run
    import flux_seamless
    write_json_atomic(os.path.join(args.work, 'flux', 'model.json'), {
        'flux': sha256_paths([os.path.join(models['flux'], part) for part in ('transformer', 'text_encoder', 'text_encoder_2', 'vae')]),
        'flux-upscale': sha256_paths([models['flux-upscale']])})
    pipe = flux_run.build(models)
    budget = Budget(args.budget)
    done = 0
    for entry, record in items:
        if budget.spent():
            break
        src = dkimg.read_png(os.path.join(args.images, entry))
        rgb, seconds = flux_seamless.upscale_seamless(pipe, args.images, stem(entry), record['prompt'],
                                                      steps=args.steps_flux, cscale=args.cscale_flux)
        finish(entry, merge(rgb, src), src, record, 'flux', seconds, args.work)
        done += 1
        print(f'{PREFIX} flux {done}/{len(items)} {entry} {seconds:.1f}s', flush=True)
    del pipe
    torch.cuda.empty_cache()
    return done


RUNNERS = {'esrgan': run_esrgan, 'sdxl': run_sdxl, 'flux': run_flux}


def produce(args):
    items = todo(args.work, args.stage, entries(read_json(args.textures_manifest), read_json(args.plan)), args.images,
                 args.maps, args.limit)
    print(f'{PREFIX} {args.stage}: {len(items)} entries to produce', flush=True)
    if not items:
        return 0
    import dkenv  # noqa: F401  (stubs a broken xformers before any diffusers import)
    done = RUNNERS[args.stage](args, items, read_json(args.models))
    print(f'{PREFIX} {args.stage}: {done} produced, {len(items) - done} left', flush=True)
    return 0


def png_size(path):
    """(width, height) from the IHDR chunk, which follows the 8-byte signature and the 8-byte chunk header."""
    with open(path, 'rb') as f:
        head = f.read(24)
    return int.from_bytes(head[16:20], 'big'), int.from_bytes(head[20:24], 'big')


def choose(work, entry, record, images):
    """(stage, sidecar) of the best current output of `entry`, or (None, reason)."""
    if record['tier'] in UNPRODUCED:
        return None, UNPRODUCED[record['tier']]
    source = sha256_file(os.path.join(images, entry))
    found = [(stage, read_sidecar(work, stage, entry)) for stage in STAGE_RANK]
    for stage, produced in found:
        if produced and produced['source_sha256'] == source:
            if png_size(output(work, stage, entry)) != (record['w'] * SCALE, record['h'] * SCALE):
                return None, f'{WRONG_SIZE}: {stage} output is not {SCALE}x {record["w"]}x{record["h"]}'
            return stage, produced
    return None, STALE if any(produced for _, produced in found) else NOT_YET


def tier_metrics(packed):
    """Per tier and stage: count, mean and max seam error, mean absolute lighting-spread change against the source."""
    groups = collections.defaultdict(list)
    for record in packed.values():
        groups[(record['tier'], record['stage'])].append(record)
    return {f'{tier}/{stage}': dict(
        count=len(records),
        seam_mean=round(sum(r['seam'] for r in records) / len(records), 3),
        seam_max=round(max(r['seam'] for r in records), 3),
        seam_source_mean=round(sum(r['seam_source'] for r in records) / len(records), 3),
        spread_delta_mean=round(sum(abs(r['spread'] - r['spread_source']) for r in records) / len(records), 3),
        spread_delta_max=round(max(abs(r['spread'] - r['spread_source']) for r in records), 3),
        seconds=round(sum(r['seconds'] for r in records), 1)) for (tier, stage), records in sorted(groups.items())}


def _read(path):
    with open(path, 'rb') as f:
        return f.read()


def pack(args):
    items = entries(read_json(args.textures_manifest), read_json(args.plan))
    packed, missing, files = {}, {}, []
    for entry, record in items:
        stage, chosen = choose(args.work, entry, record, args.images)
        if stage is None:
            missing[entry] = dict(tier=record['tier'], maps=record['maps'], reason=chosen)
            continue
        packed[entry] = dict(chosen, tier=record['tier'], maps=record['maps'])
        files.append((entry, output(args.work, stage, entry)))
    models = {stage: read_json(os.path.join(args.work, stage, 'model.json')) for stage in STAGES
              if os.path.exists(os.path.join(args.work, stage, 'model.json'))}
    for path in (args.out, args.report, args.summary):
        os.makedirs(os.path.dirname(os.path.abspath(path)), exist_ok=True)
    archive = sorted((name, _read(source)) for name, source in files)
    pk3.write(args.out, archive)
    tiers = collections.Counter(record['tier'] for _, record in items)
    produced = collections.Counter(record['tier'] for record in packed.values())
    coverage = {tier: dict(total=tiers[tier], produced=produced[tier]) for tier in sorted(tiers)}
    report = dict(package=os.path.basename(args.out), overrides=ORIGINAL_NAME, scale=SCALE,
                  textures_manifest_sha256=sha256_file(args.textures_manifest), models=models, coverage=coverage,
                  metrics=tier_metrics(packed), packed=packed, missing=missing)
    write_json_atomic(args.report, report)
    reasons = collections.Counter(record['reason'].split(':')[0] for record in missing.values())
    lines = [f'{PREFIX} {len(items)} entries, {len(packed)} packed at {SCALE}x, {len(missing)} without an HD counterpart'
             + ''.join(f', {n} {reason}' for reason, n in sorted(reasons.items())),
             f'{PREFIX} tiers ' + ', '.join(f'{tier} {c["produced"]}/{c["total"]}' for tier, c in coverage.items()),
             f'{PREFIX} {len(archive)} entries, {os.path.getsize(args.out)} bytes; {os.path.basename(args.out)} is searched '
             f'before {ORIGINAL_NAME}: {overrides(os.path.basename(args.out), ORIGINAL_NAME)}']
    lines += [f'{PREFIX} {key}: {m["count"]} seam {m["seam_mean"]} (max {m["seam_max"]}, source {m["seam_source_mean"]}) '
              f'spread delta {m["spread_delta_mean"]} (max {m["spread_delta_max"]})' for key, m in report['metrics'].items()]
    write_atomic(args.summary, ''.join(line + '\n' for line in lines).encode('utf-8'))
    print('\n'.join(lines))
    return 0


def main(argv=None):
    args = parse_args(argv)
    if args.stage == PACK and not overrides(os.path.basename(args.out), ORIGINAL_NAME):
        print(f'{PREFIX} FAIL {os.path.basename(args.out)} would be searched after {ORIGINAL_NAME} (FS_PathCmp)',
              file=sys.stderr)
        return 1
    return pack(args) if args.stage == PACK else produce(args)


if __name__ == '__main__':
    sys.exit(main())
