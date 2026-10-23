# SPDX-License-Identifier: GPL-2.0-or-later
"""Post-processing that makes generated textures usable as game albedo.

band_merge : keep the model's invented micro-detail, but take all low-frequency
             content (tone, colour, and any lighting the model baked in) from the
             original art.  Fixes added lights, colour drift and large-scale drift
             in one step.
make_tileable : force exact wrap continuity by cross-blending the texture with
             its half-rolled self inside a narrow border band.
"""
import numpy as np


def _gauss(img, sigma):
    """separable gaussian blur with wrap-around (textures tile)"""
    r = max(1, int(sigma * 3))
    x = np.arange(-r, r + 1, dtype=np.float32)
    k = np.exp(-(x ** 2) / (2 * sigma ** 2)); k /= k.sum()
    out = img.astype(np.float32)
    for ax in (0, 1):
        pad = [(0, 0)] * out.ndim
        pad[ax] = (r, r)
        p = np.pad(out, pad, mode='wrap')
        acc = np.zeros_like(out)
        for i, w in enumerate(k):
            sl = [slice(None)] * out.ndim
            sl[ax] = slice(i, i + out.shape[ax])
            acc += w * p[tuple(sl)]
        out = acc
    return out


def band_merge(src_up, gen, sigma=6.0, keep_color=True):
    """src_up: source resampled to gen's size. Returns gen's detail on src's tone."""
    s = src_up.astype(np.float32)[..., :3]
    g = gen.astype(np.float32)[..., :3]
    lo_s, lo_g = _gauss(s, sigma), _gauss(g, sigma)
    out = lo_s + (g - lo_g) if keep_color else None
    return np.clip(out, 0, 255).astype(np.uint8)


def make_tileable(img, band=None):
    """Blend the borders with the half-rolled image so opposite edges match."""
    h, w = img.shape[:2]
    band = band or max(4, min(h, w) // 16)
    a = img.astype(np.float32)
    # Average matching borders while preserving interior detail.
    out = a.copy()
    for ax, n in ((0, h), (1, w)):
        for i in range(band):
            wgt = 0.5 * (1 - i / band)
            src_idx = [slice(None)] * 2
            opp_idx = [slice(None)] * 2
            src_idx[ax] = i;         opp_idx[ax] = n - 1 - i
            si, oi = tuple(src_idx), tuple(opp_idx)
            a_i, a_o = out[si].copy(), out[oi].copy()
            out[si] = a_i * (1 - wgt) + a_o * wgt
            out[oi] = a_o * (1 - wgt) + a_i * wgt
    return np.clip(out, 0, 255).astype(np.uint8)


def seam_error(img):
    a = img.astype(np.int16)
    return float((np.abs(a[:, 0] - a[:, -1]).mean() + np.abs(a[0] - a[-1]).mean()) / 2)


def light_spread(img):
    l = (img[..., :3].astype(np.float32) * [0.299, 0.587, 0.114]).sum(-1)
    if l.shape[0] < 8 or l.shape[1] < 8:
        l = np.pad(l, ((0, max(0, 8 - l.shape[0])), (0, max(0, 8 - l.shape[1]))), mode='edge')
    h, w = l.shape; bh, bw = max(1, h // 8), max(1, w // 8)
    return float(l[:bh*8, :bw*8].reshape(8, bh, 8, bw).mean((1, 3)).std())
