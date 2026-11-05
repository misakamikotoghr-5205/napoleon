"""Half-body portraits (48x64 RGBA) for 林嫂 / 周妈 / 赵老三 / 孙富贵 / 马万利 / 孙德昌.

Run from project root:  python3 tools/art/gen_portraits_b.py
Outputs: art/portraits/{linsao,zhouma,zhao,sunyoung,ma,sunlaoye}.png
         art/_preview/portraits_b.png (contact sheet, not shipped)

Light comes from the upper right: a 1px rim pass lightens edges facing up/right
and darkens edges facing left. Only palette colours are used.
"""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from pixlib import Canvas, P, preview

OUT_DIR = "art/portraits"


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


def face(c, cx, cy, rx, ry, skin=None):
    """Neck first (caller draws head after), then face oval."""
    c.rect(cx - 3, cy + ry - 3, 6, 6, P.skin_lo)
    c.ellipse(cx, cy, rx, ry, skin or P.skin)


SKIN_MAP = {P.skin: (P.skin_lo, P.skin_hi), P.skin_lo: (P.dkbrown, P.skin)}


# ------------------------------------------------------------ 林嫂 (24, pregnant)
def linsao():
    c = Canvas(48, 64)
    # bun + hair volume (behind face)
    c.ellipse(24, 15, 9, 9, P.hair)
    c.ellipse(24, 4, 4, 3, P.hair)
    c.pixel(26, 2, P.silver)  # hairpin
    # torso: plain paper-toned side-fastened jacket
    c.poly([(6, 64), (8, 42), (12, 33), (18, 30), (30, 30), (36, 33), (40, 42), (42, 64)], P.paper)
    # belly: round bump with a soft contour
    c.ellipse(30, 51, 14, 9, P.paper_hi)       # belly bulges ~4px past the torso side
    c.ellipse(30, 51, 14, 9, P.paper_old, filled=False)
    # side-fastening seam (大襟 crossing to the right side) + buttons
    c.line(18, 31, 31, 45, P.paper_old)
    dots(c, [(33, 42), (35, 46)], P.dkbrown)
    # waist sash
    c.hline(8, 40, 58, P.paper_old)
    # hand on waist (viewer left), sleeve bent outward
    c.poly([(7, 38), (12, 37), (13, 50), (9, 57), (3, 53), (5, 45)], P.paper_old)
    c.rect(9, 50, 5, 5, P.skin)                 # hand pressed to the waist / lower back
    c.hline(9, 13, 51, P.skin_lo)
    c.pixel(9, 54, P.skin_lo)
    # neck + face
    face(c, 24, 19, 7, 9)
    # fringe + bun pin
    c.hline(18, 30, 11, P.hair)
    c.hline(19, 29, 12, P.hair)
    c.pixel(17, 14, P.hair)
    c.pixel(31, 14, P.hair)
    # features: gentle brows, warm eyes, smile
    dots(c, [(19, 17), (20, 17), (27, 17), (28, 17)], P.hair)
    dots(c, [(20, 19), (27, 19)], P.dkbrown)
    dots(c, [(18, 22), (30, 22)], P.skin_lo)  # soft smile creases
    dots(c, [(21, 23), (22, 24), (23, 25), (24, 25), (25, 25), (26, 24), (27, 23)], P.dkred)
    rim(c, {**SKIN_MAP, P.paper: (P.paper_old, P.paper_hi), P.hair: (P.black, P.gray)})
    c.outline()
    return c


# ------------------------------------------------------------ 周妈 (45, teahouse cook)
def zhouma():
    c = Canvas(48, 64)
    # broad jacket (brown cotton) + forearms with rolled sleeves
    c.poly([(2, 64), (5, 40), (11, 32), (18, 30), (30, 30), (37, 32), (43, 40), (46, 64)], P.wood1)
    # white apron over the front
    c.poly([(14, 40), (34, 40), (36, 64), (12, 64)], P.white)
    c.vline(17, 40, 44, P.silver)  # apron tie shadow
    c.vline(31, 40, 44, P.silver)
    c.hline(14, 34, 47, P.silver)
    # rolled sleeves: sleeve cuff band, then bare forearms
    c.rect(2, 39, 8, 7, P.wood1)
    c.rect(38, 39, 8, 7, P.wood1)
    c.rect(2, 46, 8, 18, P.skin)
    c.rect(38, 46, 8, 18, P.skin)
    c.hline(2, 9, 46, P.wood0)
    c.hline(38, 45, 46, P.wood0)
    c.hline(2, 9, 47, P.skin_lo)
    c.hline(38, 45, 47, P.skin_lo)
    # neck + scarf-wrapped head
    face(c, 24, 20, 7, 9)
    c.ellipse(24, 15, 9, 8, P.white)           # white headscarf
    c.ellipse(24, 20, 7, 9, P.skin)            # face over scarf
    c.line(20, 7, 16, 13, P.paper_old)         # cloth fold running down the side
    c.line(29, 7, 32, 12, P.paper_old)
    # scarf knot tails at the side
    c.poly([(31, 17), (36, 19), (35, 25), (31, 22)], P.white)
    c.hline(18, 30, 11, P.silver)              # scarf edge over forehead
    c.hline(19, 29, 12, P.hair)                # hairline showing under the scarf
    # features
    dots(c, [(20, 18), (27, 18)], P.dkbrown)   # eyes
    dots(c, [(19, 17), (20, 16), (27, 16), (28, 17)], P.gray)  # brows
    dots(c, [(18, 21), (29, 21)], P.skin_lo)   # crow's-feet wrinkles
    dots(c, [(21, 23), (27, 23)], P.skin_lo)   # cheek lines
    c.hline(22, 26, 25, P.skin_lo)             # single muted mouth line
    # warm cheeks: small 2px patches only
    dots(c, [(18, 22), (19, 22), (29, 22), (30, 22)], P.tan)
    rim(c, {**SKIN_MAP, P.wood1: (P.wood0, P.wood2), P.white: (P.silver, P.paper_hi)})
    c.outline()
    return c


# ------------------------------------------------------------ 赵老三 (40, tenant farmer)
def zhao():
    c = Canvas(48, 64)
    # short faded jacket (wall1 = worn blue-grey)
    c.poly([(8, 64), (10, 40), (14, 32), (20, 30), (28, 30), (34, 32), (38, 40), (40, 64)], P.wall1)
    # open collar showing chest (skin_lo)
    c.poly([(19, 30), (29, 30), (24, 39)], P.skin_lo)
    c.line(19, 31, 23, 38, P.dkbrown)
    c.line(29, 31, 25, 38, P.dkbrown)
    # patches of different tones with stitching
    c.rect(13, 44, 6, 5, P.tan)
    dots(c, [(13, 44), (18, 44), (13, 48), (18, 48)], P.dkbrown)
    c.rect(28, 40, 4, 4, P.paper_old)
    dots(c, [(28, 40), (31, 43)], P.dkbrown)
    c.rect(23, 53, 5, 4, P.indigo2)
    dots(c, [(23, 53), (27, 56)], P.dkbrown)
    # rope belt
    c.hline(9, 39, 57, P.wood2)
    c.hline(9, 39, 58, P.dkbrown)
    # long pipe tucked at the waist (viewer right)
    c.rect(36, 50, 3, 3, P.wood0)
    c.pixel(37, 51, P.wood3)
    c.line(38, 53, 47, 63, P.wood2)
    c.line(39, 53, 47, 62, P.wood3)
    # neck + gaunt face
    face(c, 24, 20, 6, 9)
    c.ellipse(24, 14, 7, 6, P.hair)            # cropped hair
    c.ellipse(24, 20, 6, 9, P.skin)            # sun-tanned weathered face (rim adds shade)
    c.hline(18, 30, 11, P.hair)
    # cheek hollows, grim brows, narrowed eyes, flat set mouth
    dots(c, [(19, 23), (19, 24), (29, 23), (29, 24)], P.skin_lo)
    dots(c, [(20, 22), (28, 22)], P.skin_lo)   # weathered crow's-feet
    dots(c, [(18, 16), (19, 16), (20, 17), (21, 18), (30, 16), (29, 16), (28, 17), (27, 18)], P.hair)
    dots(c, [(19, 19), (20, 19), (27, 19), (28, 19)], P.dkbrown)
    c.hline(21, 27, 26, P.dkbrown)
    dots(c, [(21, 27), (27, 27)], P.dkbrown)
    rim(c, {**SKIN_MAP, P.wall1: (P.wall0, P.wall2), P.wood2: (P.dkbrown, P.wood3),
            P.hair: (P.black, P.gray)})
    c.outline()
    return c


# ------------------------------------------------------------ 孙富贵 (22, young master)
def sunyoung():
    c = Canvas(48, 64)
    # grey western suit
    c.poly([(4, 64), (7, 41), (12, 32), (18, 30), (30, 30), (36, 32), (41, 41), (44, 64)], P.gray)
    # white shirt + lapels + black tie
    c.poly([(20, 30), (28, 30), (24, 40)], P.white)
    c.line(18, 31, 22, 40, P.silver)
    c.line(30, 31, 26, 40, P.silver)
    c.line(24, 34, 24, 38, P.black)
    # long paper-coloured scarf hanging down the front
    c.ellipse(24, 31, 8, 2, P.paper)
    c.poly([(17, 31), (24, 31), (21, 63), (15, 63)], P.paper)
    c.poly([(25, 31), (31, 31), (33, 63), (27, 63)], P.paper_hi)   # tail hangs past the lapel
    c.vline(19, 36, 62, P.paper_old)
    c.hline(16, 23, 50, P.paper_old)
    c.vline(30, 36, 62, P.paper_old)
    # right arm, white cuff, hand with chain + gold pocket watch
    c.rect(36, 38, 5, 16, P.gray)
    c.hline(36, 40, 53, P.white)
    c.rect(35, 54, 5, 4, P.skin)
    c.line(35, 45, 36, 57, P.silver)
    c.ellipse(37, 60, 3, 3, P.dkbrown)
    c.ellipse(37, 60, 2, 2, P.gold)
    c.pixel(38, 58, P.lamp_pale)
    # neck, then short slicked men's cut (hair only above the ears)
    c.rect(21, 27, 6, 5, P.skin_lo)
    c.poly([(16, 17), (16, 11), (19, 6), (28, 5), (32, 8), (32, 17), (30, 12), (18, 12)], P.black)
    # ears (outside the face oval, visible below the hair)
    c.ellipse(16, 20, 2, 3, P.skin)
    c.ellipse(32, 20, 2, 3, P.skin)
    # squarer jaw face
    c.poly([(17, 11), (31, 11), (32, 18), (31, 25), (28, 29), (20, 29), (17, 25), (16, 18)], P.skin)
    # side part + bright swept-back highlight streak
    c.line(27, 6, 22, 11, P.dkbrown)
    dots(c, [(18, 13), (19, 12), (20, 11), (21, 10), (22, 9), (23, 8), (24, 7), (25, 7), (26, 6), (27, 6), (28, 6)], P.silver)
    dots(c, [(19, 14), (20, 13), (21, 12), (22, 11), (23, 10), (24, 9), (25, 8), (26, 7)], P.gray)
    # thin arched brows (arrogant), half-lidded eyes, slight smirk
    dots(c, [(19, 16), (20, 15), (21, 15), (27, 15), (28, 15), (29, 16)], P.black)
    dots(c, [(19, 19), (20, 19), (27, 19), (28, 19)], P.dkbrown)
    dots(c, [(22, 25), (23, 25), (24, 25), (25, 24)], P.dkred)
    rim(c, {**SKIN_MAP, P.gray: (P.black, P.wall2), P.paper: (P.paper_old, P.paper_hi),
            P.hair: (P.black, P.wall2)})
    c.outline()
    return c


# ------------------------------------------------------------ 马万利 (38, 保长)
def ma():
    c = Canvas(48, 64)
    # dark overcoat
    c.poly([(3, 64), (6, 41), (11, 32), (18, 30), (30, 30), (37, 32), (42, 41), (45, 64)], P.wall0)
    # lapels, shirt V, tie
    c.line(18, 31, 22, 40, P.wall1)
    c.line(30, 31, 26, 40, P.wall1)
    c.poly([(20, 30), (28, 30), (24, 39)], P.white)
    c.line(24, 33, 24, 39, P.dkred)
    dots(c, [(24, 46), (24, 52)], P.silver)   # coat buttons
    # white armband on his LEFT arm (viewer right)
    c.poly([(36, 41), (42, 40), (43, 46), (37, 47)], P.white)
    c.hline(37, 43, 47, P.silver)
    # neck + face
    face(c, 24, 20, 7, 9)
    # fedora: crown + brim, hat band
    c.rect(17, 3, 14, 2, P.black)
    c.rect(16, 5, 16, 6, P.black)
    c.rect(9, 11, 30, 2, P.black)
    c.hline(16, 31, 10, P.gray)
    c.hline(9, 38, 12, P.wall1)
    c.hline(18, 30, 13, P.skin_lo)            # brim shadow on forehead
    # lower brow/face features
    dots(c, [(19, 17), (20, 17)], P.dkbrown)       # lowered left brow
    dots(c, [(27, 16), (28, 16)], P.dkbrown)       # raised right brow
    dots(c, [(19, 19), (20, 19)], P.dkbrown)       # narrowed sly eye
    dots(c, [(27, 18)], P.dkbrown)                 # open eye
    c.hline(22, 26, 23, P.black)                   # 5px moustache bar under the nose
    dots(c, [(22, 25), (23, 25), (24, 25), (25, 25), (26, 24)], P.dkred)  # sly half-smile
    rim(c, {**SKIN_MAP, P.wall0: (P.black, P.wall1), P.black: (P.black, P.dkbrown),
            P.white: (P.silver, P.paper_hi)})
    c.outline()
    return c


# ------------------------------------------------------------ 孙德昌 (old landlord)
def sunlaoye():
    c = Canvas(48, 64)
    # dark silk jacket with mandarin collar and frog buttons
    c.poly([(4, 64), (7, 40), (12, 32), (18, 30), (30, 30), (36, 32), (41, 40), (44, 64)], P.indigo1)
    c.rect(19, 29, 10, 3, P.indigo0)           # high collar band
    dots(c, [(24, 36), (24, 42), (24, 48)], P.gold)
    c.line(24, 33, 24, 62, P.indigo0)          # front seam
    c.line(13, 44, 16, 60, P.indigo2)          # silk sheen streaks
    c.line(34, 44, 37, 60, P.indigo2)
    # neck + stern, lined face with grey goatee
    face(c, 24, 21, 7, 9)
    c.rect(22, 28, 4, 2, P.gray)               # goatee
    # melon skullcap (瓜皮帽) with ribs and button
    c.ellipse(24, 11, 10, 6, P.black)
    c.rect(13, 15, 22, 2, P.wall0)
    c.vline(20, 6, 14, P.wall1)
    c.vline(24, 5, 14, P.wall1)
    c.vline(28, 6, 14, P.wall1)
    c.pixel(24, 5, P.gold)
    c.hline(14, 34, 16, P.black)
    # heavy grey brows, hard eyes, crease lines, tight mouth
    dots(c, [(18, 18), (19, 18), (20, 18), (21, 17)], P.gray)
    dots(c, [(30, 18), (29, 18), (28, 18), (27, 17)], P.gray)
    dots(c, [(20, 20), (27, 20)], P.dkbrown)
    dots(c, [(19, 23), (28, 23), (21, 26), (26, 26)], P.skin_lo)
    c.hline(22, 26, 25, P.dkbrown)
    rim(c, {**SKIN_MAP, P.indigo1: (P.indigo0, P.indigo2), P.black: (P.black, P.wall1),
            P.gray: (P.dkbrown, P.silver)})
    c.outline()
    return c


if __name__ == "__main__":
    out = {
        "linsao": linsao(),
        "zhouma": zhouma(),
        "zhao": zhao(),
        "sunyoung": sunyoung(),
        "ma": ma(),
        "sunlaoye": sunlaoye(),
    }
    for name, img in out.items():
        img.save(os.path.join(OUT_DIR, name + ".png"))
    sheet = preview(
        [os.path.join(OUT_DIR, n + ".png") for n in ["linsao", "zhouma", "zhao", "sunyoung", "ma", "sunlaoye"]],
        "art/_preview/portraits_b.png", scale=4)
    print("wrote", len(out), "portraits; preview:", sheet)
