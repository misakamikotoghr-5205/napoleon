#!/usr/bin/env python3
# Post-process a toon render into the final pixel image: optional resize, then colour reduction
# (adaptive palette by default; with --palette game also a despeckle pass, unless --no-despeckle).
#   python3 tools/blender/pix.py <in.png> <out.png> [--colors 24] [--method mediancut|maxcoverage]
#                                [--resize WxH] [--palette game] [--no-despeckle]
# Prints "PIXELS <sha256>" of the decoded pixels: record it in the delivery README (BLENDER_PIPELINE.md 7.1).
# --resize uses a box filter (only for renders made larger than the target; toon renders are made at size).
# --palette game snaps to the 35 colours of tools/cards/art/gen_ai_illus_a.py instead of an adaptive
#   palette; tried on the samples and it looked worse (green walls, noise), kept for experiments.
import argparse
import hashlib
import os
import re

import numpy as np
from PIL import Image

REPO = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
GAME_PAL_SRC = os.path.join(REPO, "tools", "cards", "art", "gen_ai_illus_a.py")


def game_palette():
    text = open(GAME_PAL_SRC, encoding="utf-8").read()
    return [tuple(int(h[i:i + 2], 16) for i in (1, 3, 5))
            for h in re.findall(r'"\w": \("[a-z_]+", "(#[0-9a-f]{6})"\)', text)]


def to_lab(rgb):
    c = rgb / 255.0
    c = np.where(c > 0.04045, ((c + 0.055) / 1.055) ** 2.4, c / 12.92)
    m = np.array([[0.4124, 0.3576, 0.1805], [0.2126, 0.7152, 0.0722], [0.0193, 0.1192, 0.9505]])
    xyz = c @ m.T / np.array([0.9505, 1.0, 1.089])
    f = np.where(xyz > 0.008856, np.cbrt(xyz), 7.787 * xyz + 16 / 116)
    return np.stack([116 * f[..., 1] - 16, 500 * (f[..., 0] - f[..., 1]), 200 * (f[..., 1] - f[..., 2])], -1)


def snap(img, pal):
    a = np.asarray(img).astype(float)
    pl = to_lab(np.array(pal, float))
    d = ((to_lab(a)[:, :, None, :] - pl[None, None]) ** 2).sum(-1)
    return Image.fromarray(np.array(pal, np.uint8)[d.argmin(-1)])


def despeckle(img):
    """A pixel whose colour appears nowhere among its 8 neighbours takes the most common neighbour colour."""
    a = np.asarray(img).copy()
    h, w, _ = a.shape
    key = (a[..., 0].astype(int) << 16) | (a[..., 1].astype(int) << 8) | a[..., 2]
    out = a.copy()
    for y in range(1, h - 1):
        for x in range(1, w - 1):
            nb = [key[y + dy, x + dx] for dy in (-1, 0, 1) for dx in (-1, 0, 1) if dy or dx]
            if key[y, x] not in nb:
                k = max(sorted(set(nb)), key=nb.count)
                out[y, x] = ((k >> 16) & 255, (k >> 8) & 255, k & 255)
    return Image.fromarray(out)


def pixel_hash(im):
    """sha256 of the decoded RGB pixels (PNG bytes differ between zlib/Pillow versions; pixels do not)."""
    im = im.convert("RGB")
    return hashlib.sha256(("%dx%d:" % im.size).encode() + im.tobytes()).hexdigest()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("src")
    ap.add_argument("dst")
    ap.add_argument("--colors", type=int, default=24)
    ap.add_argument("--method", choices=("mediancut", "maxcoverage"), default="mediancut")
    ap.add_argument("--resize", default="")
    ap.add_argument("--palette", choices=("adaptive", "game"), default="adaptive")
    ap.add_argument("--no-despeckle", action="store_true", help="only matters with --palette game")
    a = ap.parse_args()
    im = Image.open(a.src).convert("RGB")
    if a.resize:
        im = im.resize(tuple(int(v) for v in a.resize.split("x")), Image.BOX)
    if a.palette == "game":
        im = snap(im, game_palette())
    else:
        method = Image.Quantize.MEDIANCUT if a.method == "mediancut" else Image.Quantize.MAXCOVERAGE
        im = im.quantize(colors=a.colors, method=method, dither=Image.Dither.NONE).convert("RGB")
    if not a.no_despeckle and a.palette == "game":
        im = despeckle(im)
    im.save(a.dst)
    print("WROTE", a.dst, im.size, len(im.getcolors(1 << 16)), "colours")
    print("PIXELS", pixel_hash(im), os.path.basename(a.dst))


main()
