"""Strangers, patrol, and passerby walk cycles. 64x128 sheets.

Rows: down, left, right, up.
Frames: compose(d, 0), compose(d, 1), compose(d, 0), compose(d, 2).
Does not write the named cast (ruhua, brother, chen, ...).
"""
import copy
import inspect
import os
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
sys.path.insert(0, os.path.join(ROOT, "docs/town/mockup_src"))
from pix import Cv, C, mix
import gen_chars as gc

OUT = os.path.join(ROOT, "art", "town", "chars")
DIRS = ("down", "left", "right", "up")
FRAMES = (0, 1, 0, 2)

# Jacket ASCII (down/up/right): T t L C S s. Gown also needs P A.
# Labor also needs P p G. Crop head needs W w d. Bun needs b A.


def _takes_grid_d_frame(fn):
    if not callable(fn):
        return False
    try:
        params = list(inspect.signature(fn).parameters)
    except (TypeError, ValueError):
        return False
    return len(params) == 3


def _need(spec):
    """Letters compose() will look up for this head, torso, legs, and extras."""
    need = set()
    for d in ("down", "up", "right"):
        for row in gc.HEADS[spec["head"]][d]:
            need.update(ch for ch in row if ch != ".")
        for row in gc.TORSO[spec["torso"]][d]:
            need.update(ch for ch in row if ch != ".")
    style = gc.LEGSTYLE["child" if spec.get("child") else spec["torso"]]
    need.add("F")
    if style in ("gown", "dress"):
        need.update(("T", "t", "L"))
        if style == "dress":
            need.add("W")
    else:
        # legs() writes the trouser shade as "R", not "b" (blush).
        need.update(("B", "R"))
        if style in ("rolled", "shorts"):
            need.add("S")
        if style == "rolled":
            need.add("W")
    for fn in spec.get("extras") or []:
        if fn is gc.baton:
            need.update(("G", "q"))
        elif fn is gc.bun_back:
            need.update(("H", "A"))
        elif fn is gc.braid:
            need.update(("H", "h", "A"))
        elif fn is gc.bag:
            need.update(("G", "A"))
        elif fn is gc.pole:
            need.add("Q")
    return need


def _put(key, spec):
    gc.CHARS[key] = spec


def _passerby(i):
    # crop, girl, boy, bun, then repeat
    head = ("crop", "girl", "boy", "bun")[i % 4]
    # T, t (shade), L (light), C (collar). T cycles as specified.
    shirt = (
        (C.indigo2, C.indigo1, C.blue_hi, C.ww0),
        (C.seal_red, C.dkred, mix(C.seal_red, C.paper_hi, 0.42), C.ww0),
        (C.moss, C.g1, C.g3, C.ww1),
        (C.wood3, C.wood2, C.tan, C.paper),
        (C.wall1, C.wall0, C.wall2, C.ww0),
        (C.paper, C.paper_old, C.paper_hi, C.wood2),
    )[i]
    T, t, L, collar = shirt
    colors = {
        # every jacket letter
        "T": T, "t": t, "L": L, "C": collar, "S": C.skin, "s": C.skin_lo,
        "E": C.dkbrown, "F": C.black,
        "B": C.wood0 if i % 2 == 0 else C.indigo0,
        "H": C.hair, "h": C.gray,
    }
    extras = []
    if head == "crop":
        # second crop (passerby_4) wears a duller towel so the pair is not a clone
        if i == 0:
            colors["W"], colors["w"] = C.ww1, C.ww2
        else:
            colors["W"], colors["w"] = C.paper, C.paper_old
        colors["d"] = C.skin_lo
    elif head == "girl":
        colors["S"], colors["s"] = C.skinm, C.skin
        colors["b"] = C.blush
    elif head == "boy":
        # shaved scalp reads as short hair, same fix the child sprite uses
        colors["h"] = C.rf2
        colors["b"] = C.blush
    elif head == "bun":
        colors["S"], colors["s"] = C.skinm, C.skin
        colors["H"], colors["h"] = C.silver, C.fog
        colors["A"] = C.gray
        colors["b"] = C.blush
        if _takes_grid_d_frame(gc.bun_back):
            extras.append(gc.bun_back)
    return {
        "name": "路人",
        "head": head,
        "torso": "jacket",
        "colors": colors,
        "extras": extras,
    }


def build_chars():
    _put("stranger_refugee", {
        "name": "难民",
        "head": "crop",
        "torso": "labor",
        # dusty open jacket, tired: sunken eye-shade, dull towel, no rosiness
        "colors": {
            "H": C.hair, "h": C.gray,
            "S": C.skin, "s": C.skin_lo, "E": C.dkbrown,
            "d": mix(C.skin_lo, C.wood0, 0.5),
            "W": C.paper, "w": C.paper_old,
            "T": C.paper_old, "t": C.wood1, "L": C.paper,
            "P": C.ww2, "p": C.ww3, "G": C.wood0,
            "B": C.wood0, "F": C.black,
        },
        "extras": [],
    })
    _put("stranger_peddler", {
        "name": "货郎",
        "head": "crop",
        "torso": "jacket",
        # head cloth, closed jacket, hands empty
        "colors": {
            "H": C.hair, "h": C.gray,
            "W": C.ww0, "w": C.ww2, "d": C.skin_lo,
            "S": C.skinm, "s": C.skin, "E": C.dkbrown,
            "T": C.wood3, "t": C.wood2, "L": C.tan, "C": C.paper,
            "B": C.indigo0, "F": C.black,
        },
        "extras": [],
    })
    _put("stranger_fence", {
        "name": "销赃的",
        "head": "felthat",
        "torso": "gown",
        # same gown body as the collector; darker, no gold — shifty
        "colors": {
            "K": C.black, "k": C.rf2, "A": C.wood1, "d": C.black,
            "H": C.hair, "S": C.skin, "s": C.skin_lo, "E": C.dkbrown,
            "P": C.rf0, "C": C.rf2,
            "T": C.rf1, "t": C.rf0, "L": C.rf3,
            "F": C.black,
        },
        "extras": [],
    })
    _put("stranger_collector", {
        "name": "收账的",
        "head": "felthat",
        "torso": "gown",
        # official dark: indigo robe, black magua, gold trim
        "colors": {
            "K": C.black, "k": C.rf3, "A": C.gold, "d": C.rf0,
            "H": C.hair, "S": C.skinm, "s": C.skin, "E": C.dkbrown,
            "P": C.black, "C": C.gold,
            "T": C.indigo0, "t": C.black, "L": C.indigo1,
            "F": C.black,
        },
        "extras": [],
    })
    patrol = copy.deepcopy(gc.CHARS["police"])
    patrol["name"] = "patrol"
    patrol["extras"] = [gc.baton] if _takes_grid_d_frame(gc.baton) else []
    _put("patrol", patrol)
    for i in range(6):
        _put("passerby_%d" % i, _passerby(i))


def sheet(char):
    s = Cv(64, 128)
    for r, d in enumerate(DIRS):
        for f, fr in enumerate(FRAMES):
            s.blit(gc.compose(char, d, fr), f * 16, r * 32)
    return s


def _check(key):
    spec = gc.CHARS[key]
    missing = sorted(ch for ch in _need(spec) if spec["colors"].get(ch) is None)
    if missing:
        raise SystemExit("%s missing colors %s" % (key, "".join(missing)))
    if spec["torso"] == "jacket":
        jacket = set("TtLCS") | set("s")
        gap = sorted(ch for ch in jacket if spec["colors"].get(ch) is None)
        if gap:
            raise SystemExit("%s jacket missing %s" % (key, "".join(gap)))
    img = sheet(key)
    if (img.w, img.h) != (64, 128):
        raise SystemExit("%s size %sx%s" % (key, img.w, img.h))
    # stand frames are the same cell (down row)
    def grab(x0):
        return [img.px[x, y] for y in range(32) for x in range(x0, x0 + 16)]
    if grab(0) != grab(32):
        raise SystemExit("%s stand frames differ" % key)
    opaque = sum(1 for y in range(img.h) for x in range(img.w) if img.px[x, y][3] > 0)
    if opaque < 800:
        raise SystemExit("%s too empty (%d)" % (key, opaque))
    return img


def main():
    build_chars()
    gc.fix_colors()
    os.makedirs(OUT, exist_ok=True)
    keys = (
        "stranger_refugee", "stranger_peddler", "stranger_fence", "stranger_collector",
        "patrol",
        "passerby_0", "passerby_1", "passerby_2", "passerby_3", "passerby_4", "passerby_5",
    )
    for key in keys:
        img = _check(key)
        img.save(os.path.join(OUT, key + ".png"))
    print("CHARS_C_OK")


if __name__ == "__main__":
    main()
