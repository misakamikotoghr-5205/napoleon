"""64x128 walk sheets for the first town cast.

Columns: stand, step (frame 1), stand, step (frame 2).
Rows: down, left, right, up. Each cell is 16x32; feet sit at y=30.
"""
import os
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
sys.path.insert(0, os.path.join(ROOT, "docs/town/mockup_src"))
from pix import Cv, C
import gen_chars as gc

OUT = os.path.join(ROOT, "art", "town", "chars")
NAMES = ("ruhua", "brother", "chen", "xiaoding", "zhang", "wangshan", "li")


def add_chars():
    # 沈如松 — short hair, navy changshan. Crop's towel band is recolored as hair.
    gc.CHARS["brother"] = {
        "name": "沈如松",
        "head": "crop",
        "torso": "gown",
        "colors": {
            "K": C.hair, "k": C.gray, "A": C.gold, "d": C.skin_lo,
            "H": C.hair, "h": C.gray, "S": C.skinm, "s": C.skin,
            "E": C.dkbrown, "P": C.indigo1, "C": C.ww0,
            "T": C.indigo0, "t": C.indigo1, "L": C.indigo2,
            "B": C.indigo0, "F": C.black,
            "W": C.hair, "w": C.gray,
        },
        "extras": [],
    }
    # 陈文庭 — grey hair under a felt hat, dark-brown changshan.
    gc.CHARS["chen"] = {
        "name": "陈文庭",
        "head": "felthat",
        "torso": "gown",
        "colors": {
            "K": C.hair, "k": C.gray, "A": C.wood3, "d": C.rf0,
            "H": C.silver, "h": C.fog, "S": C.skinm, "s": C.skin,
            "E": C.dkbrown, "b": C.blush,
            "P": C.wood0, "C": C.paper, "T": C.wood1, "t": C.wood0,
            "L": C.wood2, "B": C.wood0, "F": C.black,
            "W": C.white, "w": C.ww2,
        },
        "extras": [],
    }
    # 李敬之 — student, adult height (not child).
    gc.CHARS["li"] = {
        "name": "李敬之",
        "head": "boy",
        "torso": "jacket",
        "colors": {
            "H": C.hair, "h": C.hair, "S": C.skinm, "s": C.skin,
            "E": C.dkbrown, "b": C.blush,
            "T": C.indigo2, "t": C.indigo1, "L": C.blue_hi, "C": C.indigo1,
            "B": C.indigo0, "F": C.black, "W": C.white,
        },
        "extras": [],
    }


def sheet(name):
    s = Cv(64, 128)
    for r, d in enumerate(("down", "left", "right", "up")):
        frames = [
            gc.compose(name, d, 0),
            gc.compose(name, d, 1),
            gc.compose(name, d, 0),
            gc.compose(name, d, 2),
        ]
        for f, cell in enumerate(frames):
            s.blit(cell, f * 16, r * 32)
    return s


def main():
    add_chars()
    gc.fix_colors()
    os.makedirs(OUT, exist_ok=True)
    for name in NAMES:
        sheet(name).save(os.path.join(OUT, "%s.png" % name))
    print("CHARS_A_OK")


if __name__ == "__main__":
    main()
