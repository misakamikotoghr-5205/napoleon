"""B2 portraits (48x64, same construction as tools/art/gen_portraits_a.py):
  assets/portraits/B2_wu_merchant.png  米行 吴掌柜: middle-aged, round gold spectacles,
                                       black 瓜皮帽 with red knot + jade 帽正, indigo apron
  assets/portraits/B2_ruhua.png        沈如花: 16, blue 大襟 short jacket, fringe, single braid (red tie)
Light: daylight from the shop window at upper-LEFT (left side lit, right side in shadow).
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from pix import Cv, C, ASSETS, scale, contact  # noqa: E402

W, H = 48, 64
OUT = os.path.join(ASSETS, "portraits")


def in_ell(x, y, cx, cy, rx, ry):
    return ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 <= 1.0


def paint(c, fn, col):
    for y in range(c.h):
        for x in range(c.w):
            if fn(x, y):
                c.put(x, y, col)


def robe(c, pts, base, lo, hi, hi_x=13, lo_x=35):
    """Flat garment + window shading: left of hi_x lit, right of lo_x shadow."""
    c.poly(pts, base)
    for y in range(c.h):
        for x in range(c.w):
            if c.get(x, y) == base:
                if x <= hi_x:
                    c.put(x, y, hi)
                elif x >= lo_x:
                    c.put(x, y, lo)


def head(c, cx, cy, rx, ry, jaw=0.0):
    """Shaded head; jaw>0 widens the lower half (plump cheeks)."""
    for y in range(c.h):
        for x in range(c.w):
            rxx = rx + (jaw * max(0, (y - cy)) / ry if y > cy else 0)
            if in_ell(x, y, cx, cy, rxx, ry):
                nx, ny = (x - cx) / rxx, (y - cy) / ry
                s = -0.6 * nx - 0.4 * ny          # light from upper-left
                col = C.skin_lo if s < -0.42 else (C.skin_hi if s > 0.62 else C.skin)
                c.put(x, y, col)


# ------------------------------------------------------------------ 吴掌柜
def merchant():
    c = Cv(W, H)
    # stocky shoulders, brown 对襟 jacket
    robe(c, [(2, 63), (3, 50), (8, 43), (16, 39), (32, 39), (40, 43), (45, 50), (46, 63)],
         C.wood2, C.wood1, C.wood3)
    # sleeve fold lines
    c.line(9, 47, 7, 63, C.wood1)
    c.line(39, 47, 41, 63, C.wood0)
    # neck
    c.rect(20, 33, 9, 7, C.skin)
    c.vline(28, 33, 39, C.skin_lo)
    c.hline(20, 28, 38, C.skin_lo)
    # jacket stand collar (open, white undershirt edge)
    c.hline(18, 30, 39, C.wood1)
    c.hline(21, 27, 40, C.paper_hi)
    # indigo apron: bib + neck straps
    robe(c, [(14, 45), (34, 45), (36, 63), (12, 63)], C.indigo1, C.indigo0, C.indigo2, hi_x=17, lo_x=32)
    c.hline(14, 34, 45, C.indigo0)
    c.hline(15, 33, 46, C.indigo2)
    c.line(15, 45, 19, 39, C.indigo0)
    c.line(16, 45, 20, 39, C.indigo2)
    c.line(33, 45, 29, 39, C.indigo0)
    c.line(32, 45, 28, 39, C.indigo0)
    # apron pocket with a writing brush + a folded slip
    c.rect(26, 52, 8, 6, C.indigo0)
    c.hline(26, 33, 52, C.indigo2)
    c.vline(28, 47, 52, C.wood3)
    c.put(28, 46, C.black)
    c.rect(30, 49, 3, 4, C.paper_hi)
    c.put(32, 49, C.seal_red)
    # rice dust on the apron
    for (x, y) in [(17, 50), (20, 55), (16, 58), (22, 61), (19, 48), (24, 57), (29, 60), (14, 61), (21, 51)]:
        c.put(x, y, C.mist)
    c.put(18, 53, C.fog); c.put(23, 59, C.fog)
    # 对襟 knot buttons visible above the apron bib
    c.put(24, 41, C.gold); c.put(24, 43, C.gold)
    # ---- head (plump)
    head(c, 24, 24, 10.0, 11.5, jaw=1.6)
    # ears
    c.put(13, 23, C.skin_hi); c.put(13, 24, C.skin); c.put(13, 25, C.skin)
    c.put(35, 23, C.skin_lo); c.put(35, 24, C.skin_lo); c.put(35, 25, C.skin_lo)
    # greying sideburns
    paint(c, lambda x, y: in_ell(x, y, 24, 24, 10, 11.5) and 16 <= y <= 21 and (x <= 15 or x >= 33), C.hair)
    c.put(15, 20, C.gray); c.put(33, 20, C.gray); c.put(14, 19, C.gray)
    # 瓜皮帽 skullcap: dome + rim band
    paint(c, lambda x, y: in_ell(x, y, 24, 17, 11.2, 8.5) and y <= 17, C.hair)
    c.hline(13, 35, 17, C.black)
    c.hline(14, 34, 16, C.black)
    for (x0, x1) in ((24, 18), (24, 30)):
        c.line(x0, 9, x1, 15, C.black)
    c.vline(24, 9, 15, C.black)
    # sheen on the lit side
    c.put(18, 11, C.wall2); c.put(17, 12, C.wall1); c.put(19, 11, C.wall1); c.put(16, 13, C.wall1)
    c.put(20, 10, C.wall1)
    # knot on top + jade 帽正 at the front
    c.put(24, 8, C.seal_red); c.put(23, 8, C.dkred); c.put(25, 8, C.dkred); c.put(24, 7, C.dkred)
    c.put(24, 15, C.jade_hi); c.put(25, 15, C.jade); c.put(24, 16, C.jade)
    # apologetic brows (inner ends raised)
    for (x, y) in [(16, 21), (17, 20), (18, 20), (19, 19), (20, 19)]:
        c.put(x, y, C.hair)
    for (x, y) in [(28, 19), (29, 19), (30, 20), (31, 20), (32, 21)]:
        c.put(x, y, C.hair)
    # round gold spectacles
    c.ellipse(19.5, 24, 3.4, 3.2, C.gold, filled=False)
    c.ellipse(28.5, 24, 3.4, 3.2, C.gold, filled=False)
    c.put(24, 23, C.gold)
    c.hline(14, 15, 23, C.gold); c.hline(33, 34, 23, C.wood2)
    # narrowed smiling eyes (arcs) + lens glint
    for ex in (19, 28):
        c.put(ex - 1, 25, C.black); c.put(ex, 24, C.black); c.put(ex + 1, 24, C.black); c.put(ex + 2, 25, C.black)
    c.put(18, 22, C.white); c.put(27, 22, C.white)
    # nose (broad), lit on the left
    c.put(23, 26, C.skin_hi)
    c.put(24, 27, C.skin_lo); c.put(25, 28, C.skin_lo); c.put(22, 28, C.skin_lo); c.put(23, 29, C.skin_lo)
    # cheeks
    c.put(16, 28, C.blush); c.put(17, 29, C.blush); c.put(31, 28, C.blush); c.put(32, 29, C.blush)
    # thin 八字 moustache
    for (x, y) in [(20, 31), (21, 30), (22, 30), (23, 30), (25, 30), (26, 30), (27, 30), (28, 31)]:
        c.put(x, y, C.hair)
    # sheepish merchant smile + double chin
    c.put(21, 32, C.dkbrown); c.hline(22, 26, 33, C.dkred); c.put(27, 32, C.dkbrown)
    c.hline(23, 25, 34, C.skin_lo)
    c.hline(20, 28, 36, C.skin_lo)
    c.outline(C.dkbrown)
    return c


# ------------------------------------------------------------------ 沈如花
def ruhua():
    c = Cv(W, H)
    # braid hangs behind the right shoulder first (drawn under the jacket edge later)
    robe(c, [(7, 63), (8, 51), (12, 44), (18, 40), (30, 40), (36, 44), (40, 51), (41, 63)],
         C.indigo2, C.indigo1, C.blue_hi, hi_x=12, lo_x=36)
    # 大襟: curved flap edge from the collar to the wearer's right armpit (viewer's left)
    flap = [(24, 41), (23, 41), (22, 42), (21, 42), (20, 43), (19, 43), (18, 44), (17, 45), (16, 46), (15, 47), (14, 48), (13, 49), (13, 50)]
    for (x, y) in flap:
        c.put(x, y + 1, C.blue_hi)
        c.put(x, y, C.indigo0)
    c.vline(13, 50, 63, C.indigo0)
    c.vline(14, 51, 63, C.blue_hi)
    # 盘扣 knot buttons (2px loops) on the flap and side seam
    for (x, y) in [(22, 43), (17, 46), (13, 54), (13, 59)]:
        c.put(x, y, C.paper_hi)
        c.put(x + 1, y, C.paper)
        c.put(x, y - 1, C.paper)
    # stand collar
    c.rect(19, 37, 11, 3, C.indigo1)
    c.hline(19, 29, 37, C.blue_hi)
    c.put(24, 39, C.paper_hi)
    # neck
    c.rect(21, 32, 7, 5, C.skin)
    c.vline(27, 32, 36, C.skin_lo)
    # head (slim oval)
    head(c, 24, 23, 9.0, 10.0)
    c.put(14, 23, C.skin_hi); c.put(14, 24, C.skin)
    c.put(34, 23, C.skin_lo); c.put(34, 24, C.skin_lo)
    # hair: crown, straight fringe, side locks framing the face
    paint(c, lambda x, y: in_ell(x, y, 24, 19, 10.6, 9.6) and y <= 18, C.hair)
    paint(c, lambda x, y: 15 <= x <= 33 and 16 <= y <= 18, C.hair)
    for x in range(16, 33):
        if x % 3 != 1:
            c.put(x, 19, C.hair)
    paint(c, lambda x, y: in_ell(x, y, 24, 22, 10.4, 10.8) and 16 <= y <= 27 and (x <= 15 or x >= 33), C.hair)
    # glossy highlight on the lit side
    for (x, y) in [(18, 12), (19, 12), (20, 11), (21, 11), (17, 13), (22, 11)]:
        c.put(x, y, C.gray)
    c.put(19, 11, C.silver)
    # single braid over the left shoulder (viewer's right)
    for i, y in enumerate(range(26, 58)):
        x = 34 + (1 if y > 40 else 0) - (1 if y > 50 else 0)
        w = 4 if y < 50 else 3
        for dx in range(w):
            col = C.hair if ((y + dx) % 3) else C.gray
            c.put(x + dx, y, col)
    c.rect(34, 53, 4, 3, C.seal_red)          # red tie
    c.put(34, 53, C.lantern_hi)
    for (x, y) in [(34, 56), (35, 57), (36, 56), (35, 58), (34, 59), (36, 58)]:
        c.put(x, y, C.hair)                   # tuft
    # eyes: lash line, tall dark iris with a bright catch-light, whites at the sides
    for ex in (18, 27):
        c.hline(ex, ex + 3, 21, C.black)
        c.put(ex - 1, 22, C.dkbrown) if ex == 18 else c.put(ex + 4, 22, C.dkbrown)
        c.put(ex, 22, C.white); c.put(ex + 1, 22, C.paper_hi); c.put(ex + 2, 22, C.black); c.put(ex + 3, 22, C.white)
        c.put(ex, 23, C.white); c.put(ex + 1, 23, C.black); c.put(ex + 2, 23, C.black); c.put(ex + 3, 23, C.white)
        c.put(ex + 1, 24, C.skin_lo); c.put(ex + 2, 24, C.skin_lo)
    # level, slightly knitted brows (concern)
    c.hline(18, 21, 18, C.hair); c.put(21, 19, C.hair)
    c.hline(27, 30, 18, C.hair); c.put(27, 19, C.hair)
    # nose, blush, mouth
    c.put(23, 26, C.skin_lo); c.put(24, 27, C.skin_lo)
    c.put(18, 27, C.blush); c.put(30, 27, C.blush)
    c.hline(23, 24, 29, C.dkred)
    c.put(24, 29, C.seal_red)
    c.outline(C.dkbrown)
    return c


def main():
    os.makedirs(OUT, exist_ok=True)
    m = merchant(); m.save(os.path.join(OUT, "B2_wu_merchant.png"))
    r = ruhua(); r.save(os.path.join(OUT, "B2_ruhua.png"))
    # preview next to two existing repo portraits for style matching
    ref = [os.path.join("/home/user/dehoudang/art/portraits", n + ".png") for n in ("chen", "zhouma", "guanjia")]
    contact(ref + [m.img, r.img], os.path.join(os.path.dirname(OUT), "_preview", "B2_portraits.png"), k=6, cols=5)


if __name__ == "__main__":
    main()
