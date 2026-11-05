"""Half-body portrait (48x64 RGBA) for 孙府管家 孙福 (~52, old-family steward).

Run from project root:  python3 tools/art/gen_portrait_guanjia.py
Outputs: art/portraits/guanjia.png
         art/_preview/guanjia.png (contact sheet with 孙老爷 + 马保长, not shipped)

Look: 瓜皮帽 (black melon skullcap, grey band, red knot), grey 长衫 with a
brown 马褂 vest, thin face, narrow eyes, thin moustache + small goatee, polite
smile, right hand raised at chest holding a short string of dark beads.
Light from the upper right (rim pass), only palette colours.
"""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from pixlib import Canvas, P, preview

OUT = "art/portraits/guanjia.png"
PREVIEW = "art/_preview/guanjia.png"


def rim(c, mp):
    """mp: {base_colour: (lo, hi)}. Left-facing edges -> lo, top/right-facing edges -> hi."""
    src = c.img.copy().load()
    for y in range(c.h):
        for x in range(c.w):
            col = src[x, y]
            if col[3] == 0 or col not in mp:
                continue
            lo, hi = mp[col]
            if c.get(x - 1, y)[3] == 0:
                c.px[x, y] = lo
            elif c.get(x, y - 1)[3] == 0 or c.get(x + 1, y)[3] == 0:
                c.px[x, y] = hi


def dots(c, pts, col):
    for x, y in pts:
        c.pixel(x, y, col)


SKIN_MAP = {P.skin: (P.skin_lo, P.skin_hi), P.skin_lo: (P.dkbrown, P.skin)}


def guanjia():
    c = Canvas(48, 64)

    # --- 长衫: grey gown, shoulders to floor (silver base, fog highlight on lit side)
    c.poly([(5, 64), (7, 42), (12, 33), (18, 30), (30, 30), (36, 33), (41, 42), (43, 64)], P.silver)
    # --- 马褂: short brown vest over the gown, ends at y=52, open centre seam
    c.poly([(10, 36), (15, 31), (33, 31), (38, 36), (39, 52), (9, 52)], P.wood1)
    c.hline(9, 39, 52, P.wood0)                 # vest hem shadow
    c.vline(24, 31, 52, P.wood0)                # centre front seam
    dots(c, [(23, 37), (23, 43)], P.gold)       # small brass frog buttons
    # gown collar (V, fog) visible above the vest opening
    c.poly([(19, 30), (29, 30), (24, 37)], P.fog)
    c.line(19, 31, 24, 37, P.gray)
    c.line(29, 31, 24, 37, P.gray)
    # gown skirt below the vest hem
    c.vline(13, 53, 63, P.gray)                 # gown fold lines below the vest
    c.vline(35, 53, 63, P.gray)
    c.vline(24, 53, 63, P.wall1)

    # --- raised right arm (viewer right, lit side): sleeve + hand at chest
    c.poly([(33, 34), (40, 35), (41, 47), (37, 50), (32, 44)], P.silver)
    c.poly([(36, 41), (41, 40), (41, 46), (36, 47)], P.fog)   # cuff
    c.rect(29, 36, 5, 6, P.skin)                              # hand, fingers curled
    c.hline(29, 33, 41, P.skin_lo)
    c.hline(29, 33, 36, P.skin_hi)
    # short string of black beads hanging from the fingers, with a gold tassel
    dots(c, [(31, 43), (31, 45), (31, 47), (31, 49), (31, 51)], P.black)
    dots(c, [(30, 44), (30, 48)], P.gray)                     # bead glints
    c.pixel(31, 53, P.gold)
    c.pixel(32, 53, P.gold)

    # --- neck + thin face
    c.rect(21, 27, 6, 4, P.skin_lo)
    c.ellipse(24, 20, 6, 9, P.skin)

    # --- 瓜皮帽: black melon skullcap, grey rib band, red knot with gold bead
    c.ellipse(24, 9, 8, 5, P.black)
    c.hline(16, 32, 13, P.dkbrown)              # narrow band (no cage ribs)
    c.vline(21, 6, 12, P.wall1)                 # two faint melon ribs
    c.vline(27, 6, 12, P.wall1)
    c.rect(23, 2, 3, 3, P.seal_red)             # red knot button
    c.pixel(24, 1, P.gold)
    c.pixel(22, 5, P.gray)                      # rim highlight

    # --- features: thin brows, narrow shrewd eyes, lined cheeks
    dots(c, [(19, 17), (20, 17), (27, 17), (28, 17)], P.hair)   # thin brows
    dots(c, [(19, 19), (20, 19), (27, 19), (28, 19)], P.dkbrown)  # narrow eyes
    dots(c, [(18, 21), (29, 21)], P.skin_lo)                    # crow's feet
    dots(c, [(19, 23), (28, 23)], P.skin_lo)                    # cheek lines
    # thin moustache, faint polite smile, small goatee
    c.hline(21, 27, 24, P.hair)
    dots(c, [(21, 25), (27, 25)], P.skin_lo)                    # smile creases
    dots(c, [(23, 25), (24, 25), (25, 25)], P.skin_lo)          # faint closed mouth
    dots(c, [(23, 26), (24, 26), (25, 26), (24, 27)], P.hair)   # small goatee

    rim(c, {**SKIN_MAP,
            P.silver: (P.gray, P.fog),
            P.wood1: (P.wood0, P.wood2),
            P.black: (P.black, P.gray),
            P.gray: (P.dkbrown, P.silver),
            P.hair: (P.black, P.gray)})
    c.outline()
    return c


if __name__ == "__main__":
    img = guanjia()
    img.save(OUT)
    sheet = preview(["art/portraits/guanjia.png", "art/portraits/sunlaoye.png", "art/portraits/ma.png"],
                    PREVIEW, scale=4)
    print("wrote", OUT, "; preview:", sheet)
