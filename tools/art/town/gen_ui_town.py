"""Town HUD pixel UI: dialog 9-slice, clock, notice, key hint, stamina, coin.

Colors come from the mockup palette (C). Light is top-left. Borders are 1px.
"""
import os
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
sys.path.insert(0, os.path.join(ROOT, "docs/town/mockup_src"))
from pix import Cv, C

OUT = os.path.join(ROOT, "art", "town", "ui")
CLEAR = (0, 0, 0, 0)


def dialog_frame():
    """48x48 9-slice. 6px wood band, center 36x36 fully transparent."""
    c = Cv(48, 48)
    for y in range(48):
        for x in range(48):
            top, left = y, x
            bot, right = 47 - y, 47 - x
            d = min(left, top, right, bot)
            if d >= 6:
                continue
            if d == 0:
                col = C.dkbrown
            elif d == 5:
                col = C.paper_hi
            elif d == 1 and (top == 1 or left == 1) and not (bot == 1 or right == 1):
                col = C.wood3  # lit edge
            elif d == 1 and (bot == 1 or right == 1):
                col = C.wood0  # shadowed edge
            else:
                col = C.wood1
            c.put(x, y, col)

    # Notched outer corners (chamfer stays inside the 6px margin) + a rivet.
    for ox, oy, sx, sy in (
        (0, 0, 1, 1),
        (47, 0, -1, 1),
        (0, 47, 1, -1),
        (47, 47, -1, -1),
    ):
        c.put(ox, oy, CLEAR)
        c.put(ox + sx, oy, CLEAR)
        c.put(ox, oy + sy, CLEAR)
        c.put(ox + sx, oy + sy, C.dkbrown)
        c.put(ox + 2 * sx, oy, C.dkbrown)
        c.put(ox, oy + 2 * sy, C.dkbrown)

    for x, y in ((2, 2), (43, 2), (2, 43), (43, 43)):
        c.put(x, y, C.gold)
        c.put(x + 1, y, C.wood3)
        c.put(x, y + 1, C.wood2)
        c.put(x + 1, y + 1, C.dkbrown)

    c.clear_rect(6, 6, 36, 36)
    return c


def clock_panel():
    """64x24 dark wood bar: sun on the left, empty paper inset for the time."""
    c = Cv(64, 24, C.wood0)
    c.frame(0, 0, 64, 24, C.dkbrown)
    c.hline(1, 62, 1, C.wood2)
    c.vline(1, 2, 21, C.wood2)
    c.hline(2, 61, 22, C.dkbrown)
    c.vline(62, 2, 21, C.dkbrown)

    cx, cy = 11, 12
    c.ellipse(cx, cy, 5.4, 5.4, C.wood1)
    c.ellipse(cx, cy, 4.3, 4.3, C.lamp)
    c.ellipse(cx - 1.4, cy - 1.5, 1.6, 1.2, C.lamp_pale)
    c.put(cx - 2, cy - 2, C.paper_hi)
    for dx, dy in ((0, -6), (0, 6), (-6, 0), (6, 0), (-4, -4), (4, -4), (-4, 4), (4, 4)):
        c.put(cx + dx, cy + dy, C.lamp)

    c.rect(22, 4, 38, 16, C.paper)
    c.frame(22, 4, 38, 16, C.wood1)
    c.hline(23, 58, 5, C.paper_hi)
    c.vline(23, 6, 17, C.paper_hi)
    c.hline(23, 58, 18, C.paper_old)
    c.vline(58, 6, 17, C.paper_old)
    return c


def notice_paper():
    """48x36 aged notice: wood border, red seal dot, three rule lines."""
    c = Cv(48, 36, C.paper_old)
    c.frame(0, 0, 48, 36, C.wood1)
    c.hline(1, 46, 1, C.paper_hi)
    c.vline(1, 2, 33, C.paper_hi)
    c.hline(2, 45, 34, C.wood3)
    c.vline(46, 2, 33, C.wood3)
    for y in (16, 22, 28):
        c.hline(4, 43, y, C.paper)
    # Round seal dot, highlight on the upper-left.
    for x, y in (
        (38, 6), (39, 6), (40, 6),
        (37, 7), (38, 7), (39, 7), (40, 7), (41, 7),
        (37, 8), (38, 8), (39, 8), (40, 8), (41, 8),
        (37, 9), (38, 9), (39, 9), (40, 9), (41, 9),
        (38, 10), (39, 10), (40, 10),
    ):
        c.put(x, y, C.seal_red)
    c.put(38, 7, C.paper_hi)
    c.put(41, 9, C.dkred)
    return c


def key_hint():
    """32x16 opaque keycap. ww1 face, wood1 edge, a letter-sized mark."""
    c = Cv(32, 16, C.ww1)
    c.frame(0, 0, 32, 16, C.wood1)
    # Opaque rounded corners, plus a darker bottom/right lip (pressable key).
    for x, y in (
        (0, 0), (1, 0), (0, 1),
        (31, 0), (30, 0), (31, 1),
        (0, 15), (1, 15), (0, 14),
        (31, 15), (30, 15), (31, 14),
    ):
        c.put(x, y, C.dkbrown)
    c.put(1, 1, C.wood1)
    c.put(30, 1, C.wood1)
    c.put(1, 14, C.wood1)
    c.put(30, 14, C.wood1)
    c.hline(2, 29, 14, C.wood0)
    c.hline(2, 29, 15, C.dkbrown)
    c.vline(30, 2, 13, C.wood0)
    c.vline(31, 2, 14, C.dkbrown)
    c.hline(2, 28, 1, C.ww0)
    c.vline(1, 2, 12, C.wood1)
    c.hline(2, 28, 12, C.ww2)
    # 5x7 "A", flat apex so it still reads as a key legend at 1x.
    glyph = (
        ".###.",
        "#...#",
        "#...#",
        "#####",
        "#...#",
        "#...#",
        "#...#",
    )
    for yy, row in enumerate(glyph):
        for xx, ch in enumerate(row):
            if ch == "#":
                c.put(13 + xx, 3 + yy, C.dkbrown)
    return c


def stamina_icon():
    """16x16 rice bowl. Transparent outside the 1px outline."""
    c = Cv(16, 16)
    # Heaped rice.
    c.hline(6, 9, 3, C.tan)
    c.put(7, 3, C.paper_hi)
    c.hline(5, 10, 4, C.tan)
    c.put(6, 4, C.paper_hi)
    c.put(7, 4, C.paper_hi)
    # Rim, with rice showing in the mouth of the bowl.
    c.hline(2, 13, 5, C.tan)
    c.hline(2, 13, 6, C.tan)
    c.hline(5, 10, 6, C.lamp_pale)
    c.put(5, 6, C.paper_hi)
    # Bowl wall, lit on the left.
    c.hline(3, 12, 7, C.wood2)
    c.hline(3, 12, 8, C.wood2)
    c.hline(4, 11, 9, C.wood2)
    c.hline(4, 11, 10, C.wood2)
    c.hline(5, 10, 11, C.wood2)
    for y, x in ((7, 3), (8, 3), (9, 4), (10, 4), (11, 5)):
        c.put(x, y, C.tan)
    for y, x in ((7, 12), (8, 12), (9, 11), (10, 11), (11, 10)):
        c.put(x, y, C.wood1)
    c.outline(C.dkbrown)
    return c


def coin_icon():
    """16x16 cash coin, gold/lamp, square hole, transparent corners."""
    c = Cv(16, 16)
    c.ellipse(7.5, 7.5, 6.2, 6.2, C.gold)
    c.ellipse(7.5, 7.5, 4.6, 4.6, C.lamp)
    c.put(5, 4, C.lamp_pale)
    c.put(6, 4, C.paper_hi)
    c.put(5, 5, C.lamp_pale)
    # 4x4 square hole, 1px dark rim, corners of the sprite stay clear.
    c.clear_rect(6, 6, 4, 4)
    c.outline(C.dkbrown)
    c.clear_rect(6, 6, 4, 4)
    c.frame(5, 5, 6, 6, C.dkbrown)
    return c


def _opaque(im, name):
    for y in range(im.h):
        for x in range(im.w):
            if im.get(x, y)[3] != 255:
                raise SystemExit("%s not opaque at %d,%d" % (name, x, y))


def main():
    os.makedirs(OUT, exist_ok=True)
    sprites = (
        ("dialog_frame.png", dialog_frame, (48, 48)),
        ("clock_panel.png", clock_panel, (64, 24)),
        ("notice_paper.png", notice_paper, (48, 36)),
        ("key_hint.png", key_hint, (32, 16)),
        ("stamina_icon.png", stamina_icon, (16, 16)),
        ("coin_icon.png", coin_icon, (16, 16)),
    )
    for name, fn, size in sprites:
        c = fn()
        if (c.w, c.h) != size:
            raise SystemExit("%s is %dx%d" % (name, c.w, c.h))
        c.save(os.path.join(OUT, name))

    frame = Cv.load(os.path.join(OUT, "dialog_frame.png"))
    if (frame.w, frame.h) != (48, 48):
        raise SystemExit("dialog frame size")
    for y in range(6, 42):
        for x in range(6, 42):
            if frame.get(x, y)[3] != 0:
                raise SystemExit("dialog center opaque at %d,%d" % (x, y))
    # Mid-edge recipe: outer dkbrown, inner paper_hi, wood between.
    if frame.get(24, 0)[:3] != C.dkbrown[:3] or frame.get(24, 5)[:3] != C.paper_hi[:3]:
        raise SystemExit("dialog top edge colors")
    if frame.get(24, 3)[:3] != C.wood1[:3] or frame.get(3, 24)[:3] != C.wood1[:3]:
        raise SystemExit("dialog wood band")
    if frame.get(0, 24)[:3] != C.dkbrown[:3] or frame.get(5, 24)[:3] != C.paper_hi[:3]:
        raise SystemExit("dialog left edge colors")
    if frame.get(47, 24)[:3] != C.dkbrown[:3] or frame.get(42, 24)[:3] != C.paper_hi[:3]:
        raise SystemExit("dialog right edge colors")
    if frame.get(24, 47)[:3] != C.dkbrown[:3] or frame.get(24, 42)[:3] != C.paper_hi[:3]:
        raise SystemExit("dialog bottom edge colors")
    if frame.get(0, 0)[3] != 0:
        raise SystemExit("dialog corner notch missing")

    for name in ("clock_panel.png", "notice_paper.png", "key_hint.png"):
        _opaque(Cv.load(os.path.join(OUT, name)), name)

    coin = Cv.load(os.path.join(OUT, "coin_icon.png"))
    for x, y in ((0, 0), (15, 0), (0, 15), (15, 15), (7, 7), (8, 8)):
        if coin.get(x, y)[3] != 0:
            raise SystemExit("coin should be clear at %d,%d" % (x, y))

    stam = Cv.load(os.path.join(OUT, "stamina_icon.png"))
    if stam.get(0, 0)[3] != 0:
        raise SystemExit("stamina corner should be clear")

    print("UI_OK")
    for name, _fn, _size in sprites:
        im = Cv.load(os.path.join(OUT, name))
        print("%s %dx%d" % (name, im.w, im.h))
    return 0


if __name__ == "__main__":
    sys.exit(main())
