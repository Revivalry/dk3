# SPDX-License-Identifier: GPL-2.0-or-later
"""RRDBNet (ESRGAN / Real-ESRGAN) in plain torch, with loaders for both the
BasicSR key layout and the original ESRGAN layout, and optional circular
padding so tiling textures stay seamless."""
import torch, torch.nn as nn, torch.nn.functional as F


class ResidualDenseBlock(nn.Module):
    def __init__(self, nf=64, gc=32):
        super().__init__()
        self.conv1 = nn.Conv2d(nf, gc, 3, 1, 1)
        self.conv2 = nn.Conv2d(nf + gc, gc, 3, 1, 1)
        self.conv3 = nn.Conv2d(nf + 2*gc, gc, 3, 1, 1)
        self.conv4 = nn.Conv2d(nf + 3*gc, gc, 3, 1, 1)
        self.conv5 = nn.Conv2d(nf + 4*gc, nf, 3, 1, 1)
        self.lrelu = nn.LeakyReLU(0.2, inplace=True)

    def forward(self, x):
        x1 = self.lrelu(self.conv1(x))
        x2 = self.lrelu(self.conv2(torch.cat((x, x1), 1)))
        x3 = self.lrelu(self.conv3(torch.cat((x, x1, x2), 1)))
        x4 = self.lrelu(self.conv4(torch.cat((x, x1, x2, x3), 1)))
        x5 = self.conv5(torch.cat((x, x1, x2, x3, x4), 1))
        return x5 * 0.2 + x


class RRDB(nn.Module):
    def __init__(self, nf, gc=32):
        super().__init__()
        self.rdb1, self.rdb2, self.rdb3 = (ResidualDenseBlock(nf, gc) for _ in range(3))

    def forward(self, x):
        return self.rdb3(self.rdb2(self.rdb1(x))) * 0.2 + x


class RRDBNet(nn.Module):
    def __init__(self, nf=64, nb=23, gc=32, scale=4):
        super().__init__()
        self.scale = scale
        self.conv_first = nn.Conv2d(3, nf, 3, 1, 1)
        self.body = nn.Sequential(*[RRDB(nf, gc) for _ in range(nb)])
        self.conv_body = nn.Conv2d(nf, nf, 3, 1, 1)
        self.conv_up1 = nn.Conv2d(nf, nf, 3, 1, 1)
        self.conv_up2 = nn.Conv2d(nf, nf, 3, 1, 1)
        self.conv_hr = nn.Conv2d(nf, nf, 3, 1, 1)
        self.conv_last = nn.Conv2d(nf, 3, 3, 1, 1)
        self.lrelu = nn.LeakyReLU(0.2, inplace=True)

    def forward(self, x):
        feat = self.conv_first(x)
        feat = feat + self.conv_body(self.body(feat))
        feat = self.lrelu(self.conv_up1(F.interpolate(feat, scale_factor=2, mode='nearest')))
        feat = self.lrelu(self.conv_up2(F.interpolate(feat, scale_factor=2, mode='nearest')))
        return self.conv_last(self.lrelu(self.conv_hr(feat)))


def _convert_old_keys(sd):
    """original ESRGAN 'model.N' layout -> BasicSR layout"""
    out, nb = {}, 0
    for k, v in sd.items():
        if k.startswith('model.1.sub.'):
            parts = k.split('.')
            idx = parts[3]
            if idx.isdigit() and len(parts) > 5:
                nb = max(nb, int(idx) + 1)
                rdb = parts[4].lower()                    # RDB1 -> rdb1
                conv = parts[5].lower()                   # conv1
                out[f'body.{idx}.{rdb}.{conv}.{parts[-1]}'] = v
                continue
            out['conv_body.' + parts[-1]] = v             # model.1.sub.23
            continue
        m = {'model.0': 'conv_first', 'model.3': 'conv_up1', 'model.6': 'conv_up2',
             'model.8': 'conv_hr', 'model.10': 'conv_last'}
        pre = k.rsplit('.', 1)[0]
        if pre in m:
            out[m[pre] + '.' + k.rsplit('.', 1)[1]] = v
        else:
            out[k] = v
    return out, nb


def load_esrgan(path, device='cuda', circular=False):
    sd = torch.load(path, map_location='cpu', weights_only=True)
    sd = sd.get('params_ema', sd.get('params', sd))
    if any(k.startswith('model.') for k in sd):
        sd, nb = _convert_old_keys(sd)
    else:
        nb = len({k.split('.')[1] for k in sd if k.startswith('body.')})
    net = RRDBNet(nb=nb)
    net.load_state_dict(sd, strict=True)
    if circular:
        for m in net.modules():
            if isinstance(m, nn.Conv2d):
                m.padding_mode = 'circular'
    return net.eval().to(device)
