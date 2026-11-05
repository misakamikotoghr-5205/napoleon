#!/usr/bin/env python3
# Review sheet for a delivered candidate batch: for each art id, the image the game uses now (left)
# next to the candidate (right), labelled, enlarged with nearest-neighbour.
#   python3 tools/blender/review_sheet.py <candidate_dir> <out.png> <scale> <cols> <art id> [<art id> ...]
# Owner-side tool: it shows the current (AI) art, so do not hand its output to an AI operator.
import json
import os
import sys

from PIL import Image, ImageDraw, ImageFont

REPO = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
FONT = "/usr/share/fonts/truetype/wqy/wqy-zenhei.ttc"


def current(man, art_id):
    e = man[art_id]
    for k in ("human", "ai", "placeholder"):
        p = e.get(k)
        if p and os.path.exists(os.path.join(REPO, p)):
            return Image.open(os.path.join(REPO, p)).convert("RGBA")
    return Image.new("RGBA", tuple(e["base"]), (255, 0, 255, 255))


def flat(im):
    bg = Image.new("RGBA", im.size, (200, 190, 170, 255))
    bg.alpha_composite(im)
    return bg.convert("RGB")


def main():
    cand, out, scale, cols, ids = sys.argv[1], sys.argv[2], int(sys.argv[3]), int(sys.argv[4]), sys.argv[5:]
    man = json.load(open(os.path.join(REPO, "data", "cards", "art", "manifest.json"), encoding="utf-8"))["art"]
    font = ImageFont.truetype(FONT, 13) if os.path.exists(FONT) else ImageFont.load_default()
    cells = []
    for i in ids:
        a = flat(current(man, i))
        b = Image.open(os.path.join(cand, i + ".png")).convert("RGB")
        w, h = a.size[0] * scale, a.size[1] * scale
        c = Image.new("RGB", (2 * w + 12, h + 18), (246, 240, 228))
        c.paste(a.resize((w, h), Image.NEAREST), (0, 18))
        c.paste(b.resize((w, h), Image.NEAREST), (w + 12, 18))
        ImageDraw.Draw(c).text((0, 1), i, fill=(40, 30, 22), font=font)
        cells.append(c)
    cw = max(c.size[0] for c in cells)
    ch = max(c.size[1] for c in cells)
    rows = (len(cells) + cols - 1) // cols
    sheet = Image.new("RGB", (cols * (cw + 10), rows * (ch + 10)), (246, 240, 228))
    for n, c in enumerate(cells):
        sheet.paste(c, ((n % cols) * (cw + 10), (n // cols) * (ch + 10)))
    sheet.save(out)
    print("WROTE", out, sheet.size)


main()
