"""Batch B town walkers. 64x128 sheets: 4 dirs x 4 frames (stand, step, stand, step).

Does not edit docs/town/mockup_src. New cast is added to gen_chars.CHARS in memory.
"""
import os
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
sys.path.insert(0, os.path.join(ROOT, "docs/town/mockup_src"))
from pix import Cv, C
import gen_chars as gc


def _patches(grid, d, frame):
    """A few darker cloth swaps so the jacket reads as patched, not just shaded."""
    spots = {
        "down": ((6, 16), (7, 16), (10, 18), (11, 17), (5, 20)),
        "up": ((6, 17), (10, 18), (11, 19)),
        "right": ((8, 17), (9, 18), (10, 19)),
    }
    for x, y in spots.get(d, ()):
        ch = grid.get((x, y))
        if ch == "T":
            grid[(x, y)] = "t"
        elif ch == "L":
            grid[(x, y)] = "t"


gc.CHARS["linsao"] = {
    "name": "林嫂",
    "head": "bun",
    "torso": "jacket",
    "colors": {
        "H": C.hair, "h": C.gray, "S": C.skinm, "s": C.skin, "E": C.dkbrown, "b": C.blush,
        "A": C.gold,
        "T": C.wood2, "t": C.wood1, "L": C.wood3, "C": C.paper,
        "B": C.wood0, "F": C.black, "W": C.white,
    },
    "extras": [gc.bun_back],
}

gc.CHARS["zhao"] = {
    "name": "赵老三",
    "head": "crop",
    "torso": "labor",
    "colors": {
        "H": C.hair, "h": C.gray, "S": C.skin, "s": C.skin_lo, "E": C.dkbrown, "d": C.skin_lo,
        "W": C.ww2, "w": C.ww3,
        "T": C.wood1, "t": C.wood0, "L": C.wood2,
        "P": C.paper_old, "p": C.wood3, "G": C.dkbrown,
        "B": C.wood0, "F": C.wood0,
    },
    "extras": [_patches],
}

gc.CHARS["sunyoung"] = {
    "name": "孙少爷",
    "head": "felthat",
    "torso": "gown",
    "colors": {
        "K": C.hair, "k": C.gray, "A": C.gold, "d": C.rf0,
        "H": C.hair, "S": C.skinm, "s": C.skin, "E": C.dkbrown,
        "P": C.indigo0, "C": C.ww0,
        "T": C.indigo1, "t": C.indigo0, "L": C.indigo2,
        "B": C.indigo0, "F": C.black,
    },
    "extras": [],
}

gc.CHARS["guanjia"] = {
    "name": "管家",
    "head": "felthat",
    "torso": "gown",
    "colors": {
        "K": C.black, "k": C.wall1, "A": C.gray, "d": C.black,
        "H": C.gray, "S": C.skin, "s": C.skin_lo, "E": C.dkbrown,
        "P": C.wood0, "C": C.wall1,
        "T": C.rf1, "t": C.wall0, "L": C.rf2,
        "B": C.black, "F": C.black,
    },
    "extras": [],
}

gc.CHARS["wu"] = {
    "name": "吴掌柜",
    "head": "felthat",
    "torso": "gown",
    "colors": {
        "K": C.hair, "k": C.gray, "A": C.seal_red, "d": C.black,
        "H": C.hair, "S": C.skinm, "s": C.skin, "E": C.dkbrown,
        "T": C.wood2, "t": C.wood1, "L": C.wood3,
        "P": C.paper, "C": C.paper,
        "B": C.wood0, "F": C.black,
    },
    "extras": [],
}

_post = dict(gc.CHARS["police"]["colors"])
_post["T"] = C.postgreen
_post["t"] = C.postgreen_hi
_post["L"] = C.g3
_post["K"] = C.postgreen
_post["k"] = C.postgreen_hi
gc.CHARS["postman"] = {
    "name": "邮电",
    "head": "police",
    "torso": "uniform",
    "colors": _post,
    "extras": [],
}

gc.fix_colors()

OUT = os.path.join(ROOT, "art", "town", "chars")
ORDER = ("linsao", "zhouma", "zhao", "sunyoung", "ma", "guanjia", "wu", "postman")
DIRS = ("down", "left", "right", "up")
FRAMES = (0, 1, 0, 2)


def sheet(char):
    s = Cv(64, 128)
    for r, d in enumerate(DIRS):
        for i, f in enumerate(FRAMES):
            s.blit(gc.compose(char, d, f), i * 16, r * 32)
    return s


def main():
    os.makedirs(OUT, exist_ok=True)
    for k in ORDER:
        path = os.path.join(OUT, k + ".png")
        img = sheet(k)
        assert img.w == 64 and img.h == 128, (k, img.w, img.h)
        img.save(path)
    print("CHARS_B_OK")


if __name__ == "__main__":
    main()
