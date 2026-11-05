"""48x64 town portraits from the walker down/stand frame.

    python3 tools/art/town/gen_portraits_town.py

Each portrait is the 16x32 stand cell scaled x2 (nearest) and centered
on a fully transparent 48x64 canvas (alpha 0 everywhere outside the figure,
like the older portraits), so the bust matches the walking sprite. The 1px
black outline of the walker cell is part of the figure and is kept (x2).
"""
import os
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
sys.path.insert(0, os.path.join(ROOT, "docs/town/mockup_src"))
from pix import Cv, C, scale  # noqa: E402
import gen_chars as gc  # noqa: E402

OUT = os.path.join(ROOT, "art", "portraits")
NAMES = (
    "ruhua",
    "wu",
    "postman",
    "stranger_refugee",
    "stranger_peddler",
    "stranger_fence",
    "stranger_collector",
)


def face(rows):
    """14 rows x 16 cols, down-facing head (same contract as gen_chars.HEADS)."""
    if len(rows) != 14:
        raise SystemExit("head rows %d" % len(rows))
    for i, row in enumerate(rows):
        if len(row) != 16:
            raise SystemExit("head row %d len %d %r" % (i, len(row), row))
    return {"down": rows}


def add_heads():
    # Middle-aged: grey temples, top-left hair sheen, slight smile.
    gc.HEADS["smile"] = face([
        "......HHHH......",
        "....hhhHHHHH....",
        "...hhHhhHHHHH...",
        "..hhHHHHHHHHhh..",
        "..hHHSSSSSSSHH..",
        "..HSSSSSSSSSSH..",
        "..HSSEESSSSEEH..",
        "..HSSSSSSSSSSH..",
        "..HSSmSSSSmSSH..",
        "...sSSmmmmSSs...",
        "....sSSSSSSs....",
        ".....sSSSSs.....",
        "......SSSS......",
        "......ssss......",
    ])
    # Small round cap (postal), not the tall police shako.
    gc.HEADS["cap"] = face([
        "................",
        ".....KKKKKK.....",
        "....KkkKKKKK....",
        "...KKKKKKKKKK...",
        "..KKddddddddKK..",
        "...HSSSSSSSSH...",
        "...SSSSSSSSSS...",
        "...SEESSSSEES...",
        "...SSSSSSSSSS...",
        "...SSSSSSSSSS...",
        "...sSSSSSSSSs...",
        "....sSSSSSSs....",
        ".....sSSSSs.....",
        "......ssss......",
    ])
    # Gaunt, messy hair, half-shut eyes, tired mouth.
    gc.HEADS["tired"] = face([
        "......HhHh......",
        "....HHhHHHhH....",
        "...HhHHHHHHHh...",
        "..HhHSSSSSSShH..",
        "..HsSSSSSSSSsH..",
        "..HSsSSSSSSSsH..",
        "..HssEsSSSsEsH..",
        "..HSsSSSSSSSsH..",
        "..HSSbSSSSSbSH..",
        "...sSSmmmmSSs...",
        "....smSSSSms....",
        ".....sSSSSs.....",
        "......SSSS......",
        "......ssss......",
    ])
    # Wide straw hat, simple hair under the brim.
    gc.HEADS["straw"] = face([
        "................",
        "...KKKKKKKKKK...",
        "..KKkkKKKKKKKK..",
        ".KKKKKKKKKKKKKK.",
        "..KKAHHHHHHAKK..",
        "...HHSSSSSSHH...",
        "...HSSSSSSSSH...",
        "...HSESSSSESH...",
        "...HSSSSSSSSH...",
        "...HSbSSSSSbH...",
        "....sSSSSSSs....",
        ".....sSSSSs.....",
        "......SSSS......",
        "......ssss......",
    ])
    # Dark hat, squinting eyes, no moustache.
    gc.HEADS["squint"] = face([
        "......KKKK......",
        "....KKkkKKKK....",
        "....KkKKKKKK....",
        "....AAAAAAAA....",
        "..KKKKKKKKKKKK..",
        "...dddddddddd...",
        "...HSSSSSSSSH...",
        "...SsSSSSSSSs...",
        "...SsESSSSEsS...",
        "...SSSSSSSSSS...",
        "...sSSSSSSSSs...",
        "....sSSSSSSs....",
        ".....sSSSSs.....",
        "......ssss......",
    ])
    # Neat hair, level eyes, straight mouth, no blush.
    gc.HEADS["cold"] = face([
        "......HHHH......",
        "....HHHhHHHH....",
        "...HHHHHHHHHH...",
        "..HHHHHHHHHHHH..",
        "..HHHHHHHHHHHH..",
        "..HHHSSSSSSHHH..",
        "..HHSEESSSSEHH..",
        "..HSSSSSSSSSSH..",
        "..HSSSSSSSSSSH..",
        "..HSSSmmmmSSSH..",
        "...SSSSSSSSSS...",
        "....sSSSSSSs....",
        ".....sSSSSs.....",
        "......SSSS......",
    ])


def dust(grid, d, frame):
    """Pale specks on a worn jacket."""
    if d != "down":
        return
    for x, y in ((4, 17), (6, 19), (11, 18), (9, 21), (13, 20), (5, 22), (8, 18), (12, 22)):
        if grid.get((x, y)) in ("T", "t", "L", "P", "p"):
            grid[(x, y)] = "D"


def badge(grid, d, frame):
    """Tiny gold pip on the lit side of the post jacket."""
    if d == "down":
        grid[(5, 18)] = "A"
        grid[(6, 18)] = "A"


def add_chars():
    # 吴掌柜 — brown gown, grey temples, slight smile.
    gc.CHARS["wu"] = {
        "name": "吴掌柜",
        "head": "smile",
        "torso": "gown",
        "colors": {
            "H": C.hair, "h": C.silver, "S": C.skinm, "s": C.skin,
            "E": C.dkbrown, "b": C.blush, "m": C.dkred,
            "P": C.wood2, "C": C.paper_hi, "A": C.gold,
            "T": C.wood3, "t": C.wood0, "L": C.tan,
            "B": C.wood1, "R": C.wood0, "F": C.black,
        },
        "extras": [],
    }
    # 邮电代办 — green jacket, small cap.
    gc.CHARS["postman"] = {
        "name": "邮差",
        "head": "cap",
        "torso": "jacket",
        "colors": {
            "K": C.postgreen, "k": C.postgreen_hi, "d": C.g0,
            "H": C.hair, "S": C.skinm, "s": C.skin, "E": C.dkbrown,
            "T": C.postgreen, "t": C.g0, "L": C.postgreen_hi, "C": C.paper_hi,
            "A": C.gold, "B": C.rf1, "R": C.wall0, "F": C.black,
        },
        "extras": [badge],
    }
    # Thin refugee — dusty open jacket, bare forearms, tired face.
    gc.CHARS["stranger_refugee"] = {
        "name": "流民",
        "head": "tired",
        "torso": "labor",
        "colors": {
            "H": C.hair, "h": C.gray, "S": C.skin, "s": C.skin_lo,
            "E": C.dkbrown, "b": C.skin_lo, "m": C.dkbrown,
            "T": C.dirt2, "t": C.dirt0, "L": C.dirt3, "P": C.paper_old, "p": C.dirt1,
            "G": C.wood0, "D": C.fog, "W": C.dirt2,
            "B": C.dirt1, "R": C.dirt0, "F": C.wood0,
        },
        "extras": [dust],
    }
    # Peddler — straw hat, tan jacket.
    gc.CHARS["stranger_peddler"] = {
        "name": "货郎",
        "head": "straw",
        "torso": "jacket",
        "colors": {
            "K": C.gold, "k": C.lamp_pale, "A": C.wood2,
            "H": C.hair, "S": C.skinm, "s": C.skin, "E": C.dkbrown, "b": C.blush,
            "T": C.tan, "t": C.wood3, "L": C.lamp_pale, "C": C.wood1,
            "B": C.wood2, "R": C.wood1, "F": C.wood0,
        },
        "extras": [],
    }
    # Fence — dark hat, narrow eyes, dark robe.
    gc.CHARS["stranger_fence"] = {
        "name": "销赃人",
        "head": "squint",
        "torso": "gown",
        "colors": {
            "K": C.black, "k": C.gray, "A": C.rf2, "d": C.rf0,
            "H": C.hair, "S": C.skinm, "s": C.skin_lo, "E": C.black,
            "P": C.rf0, "C": C.rf2, "T": C.black, "t": C.black, "L": C.rf3,
            "B": C.black, "R": C.rf0, "F": C.black,
        },
        "extras": [],
    }
    # Collector — neat dark gown, cold straight mouth.
    gc.CHARS["stranger_collector"] = {
        "name": "收账人",
        "head": "cold",
        "torso": "gown",
        "colors": {
            "H": C.hair, "h": C.silver, "S": C.skin, "s": C.skin_lo,
            "E": C.black, "m": C.dkbrown,
            "P": C.indigo0, "C": C.silver, "A": C.silver,
            "T": C.wall0, "t": C.black, "L": C.indigo1,
            "B": C.indigo0, "R": C.black, "F": C.black,
        },
        "extras": [],
    }


def portrait(name):
    """Down/stand frame, x2 nearest, centered on a transparent canvas."""
    cell = gc.compose(name, "down", 0)
    if cell.w != 16 or cell.h != 32:
        raise SystemExit("%s cell %sx%s" % (name, cell.w, cell.h))
    big = scale(cell.img, 2)
    if big.size != (32, 64):
        raise SystemExit("%s scaled %s" % (name, big.size))
    c = Cv(48, 64)  # CLEAR (0, 0, 0, 0): no background box
    c.blit(big, 8, 0)
    return c


def main():
    add_heads()
    add_chars()
    gc.fix_colors()
    os.makedirs(OUT, exist_ok=True)
    for name in NAMES:
        c = portrait(name)
        path = os.path.join(OUT, name + ".png")
        c.save(path)
        im = c.img
        if im.size != (48, 64) or im.mode != "RGBA":
            raise SystemExit("%s %s %s" % (name, im.size, im.mode))
        # Transparent background: all four corners alpha 0, figure still present.
        for corner in ((0, 0), (47, 0), (0, 63), (47, 63)):
            if im.getpixel(corner)[3] != 0:
                raise SystemExit("%s corner %s is not transparent" % (name, corner))
        opaque = sum(1 for a in im.getchannel("A").tobytes() if a == 255)
        if opaque < 300 or opaque > 48 * 64 * 0.6:
            raise SystemExit("%s figure covers %d px" % (name, opaque))
        # The outline survives: every opaque pixel that touches the transparent
        # ground (the figure's edge) still carries the walker's outline colour.
        want = gc.CHARS[name].get("outline", C.dkbrown)
        edge = good = 0
        for y in range(64):
            for x in range(48):
                if im.getpixel((x, y))[3] == 0:
                    continue
                touches = any(
                    nx < 0 or ny < 0 or nx >= 48 or ny >= 64 or im.getpixel((nx, ny))[3] == 0
                    for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1))
                )
                if touches:
                    edge += 1
                    good += im.getpixel((x, y)) == want
        if edge == 0 or good < edge * 0.6:
            raise SystemExit("%s lost its outline (%d of %d edge px)" % (name, good, edge))
    print("PORTRAITS_OK")


if __name__ == "__main__":
    main()
