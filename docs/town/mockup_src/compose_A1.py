"""Compose MOCKUP A1: top-down 青溪镇 street (native 427x240, x3 -> 1280x720)."""
import math
import os
import random
from PIL import Image, ImageDraw, ImageFilter

from pix import Cv, C, ASSETS, HERE, mix, alpha, font, font_mask, scale, ZEN, UNIFONT
import gen_tiles_props as gtp
import gen_chars as gch

NW, NH, K = 427, 240, 3
STREET_Y = 112          # first street row (building ground line + 1)
EDGE_Y = 190            # canal coping starts
WATER_Y = 204           # waterline of the main canal
LANE_X0, LANE_X1 = 308, 348   # side canal (水巷) between 药铺 and 警察所


def A(*p):
    return os.path.join(ASSETS, *p)


def load(*p):
    return Image.open(A(*p)).convert("RGBA")


def char_frame(name, d, f):
    sheet = Image.open(A("chars", "%s_sheet.png" % name)).convert("RGBA")
    r = {"down": 0, "left": 1, "right": 2, "up": 3}[d]
    return sheet.crop((f * 16, r * 32, f * 16 + 16, r * 32 + 32))


class Scene:
    def __init__(self):
        self.c = Cv(NW, NH, C.st1)
        self.sprites = []   # (sort_y, x, y, img, shadow)

    def add(self, img, x, y_base, shadow=None, sort=None):
        """img bottom row sits on y_base."""
        y = y_base - img.height + 1
        self.sprites.append((sort if sort is not None else y_base, x, y, img, shadow))

    def shadow(self, cx, cy, rx, ry, a=80):
        ov = Image.new("RGBA", (NW, NH), (0, 0, 0, 0))
        d = ImageDraw.Draw(ov)
        d.ellipse((cx - rx, cy - ry, cx + rx, cy + ry), fill=(20, 14, 10, a))
        self.c.img.alpha_composite(ov)
        self.c.px = self.c.img.load()

    def flush(self):
        for (sy, x, y, img, sh) in sorted(self.sprites, key=lambda s: s[0]):
            if sh:
                self.shadow(*sh)
            self.c.blit(img, x, y)
        self.sprites = []


def build_ground(s):
    c = s.c
    rnd = random.Random(5)
    # street pavement (procedural slabs, worn centre band, moss near walls & water)
    def moss(x, y):
        yy = y + STREET_Y - 4
        if yy < STREET_Y + 6:
            return 0.35
        if yy > EDGE_Y - 8:
            return 0.25
        return 0.04
    field = gtp.slab_field(NW, EDGE_Y - STREET_Y + 8, 2024, wear_band=(26, 56), moss_fn=moss)
    c.blit(field, 0, STREET_Y - 4)
    # puddles (left by last night's rain) + fallen willow leaves
    for (px_, py_, rx, ry) in ((198, STREET_Y + 52, 7, 2.2), (58, STREET_Y + 60, 5, 1.8), (372, STREET_Y + 40, 6, 2)):
        for y in range(int(py_ - ry - 1), int(py_ + ry + 2)):
            for x in range(int(px_ - rx - 1), int(px_ + rx + 2)):
                d = ((x - px_) / rx) ** 2 + ((y - py_) / ry) ** 2
                if d < 1:
                    q = c.get(x, y)
                    c.put(x, y, mix(q, C.wa3 if d > 0.5 else C.wa4, 0.6))
        c.hline(int(px_ - rx * 0.5), int(px_ - rx * 0.1), int(py_ - ry * 0.4), C.wa5)
    for _ in range(40):
        lx = rnd.choice([rnd.randint(0, 60), rnd.randint(255, 310)])
        ly = rnd.randint(EDGE_Y - 30, EDGE_Y - 2)
        c.put(lx, ly, rnd.choice([C.g3, C.g4, C.gold]))
    # canal coping + embankment wall + water
    e1, e2 = Cv.load(A("tiles", "embank_1.png")), Cv.load(A("tiles", "embank_2.png"))
    for tx in range(0, NW, 16):
        c.blit(e1 if (tx // 16) % 3 else e2, tx, EDGE_Y)
    w1, w2, w3 = (Cv.load(A("tiles", "water_%d.png" % i)) for i in (1, 2, 3))
    for ty in range(EDGE_Y + 16, NH, 16):
        for tx in range(0, NW, 16):
            c.blit(rnd.choice([w1, w2, w3]), tx, ty)
    # soften: darker water near the wall (its shadow), lighter far
    for y in range(EDGE_Y + 14, NH):
        t = (y - (EDGE_Y + 14)) / (NH - EDGE_Y - 14)
        for x in range(NW):
            p = c.get(x, y)
            c.put(x, y, mix(p, C.wa0, 0.18 * (1 - t)))
    # back band: distant roofs
    br = Cv.load(A("buildings", "back_roofs_strip.png"))
    for tx in range(-20, NW, br.w):
        c.blit(br, tx, -6)
    # gap fill above street behind buildings (courtyard shade)
    for y in range(30, STREET_Y - 4):
        for x in range(NW):
            if c.get(x, y)[:3] == C.st1[:3]:
                c.put(x, y, C.rf1)


def build_lane(s):
    """Side canal running north between 药铺 and 警察所, under the bridge, into the main canal."""
    c = s.c
    rnd = random.Random(9)
    x0, x1 = LANE_X0, LANE_X1
    for y in range(0, STREET_Y):
        for x in range(x0, x1):
            t = y / STREET_Y
            base = C.wa1 if (x + y * 3) % 7 else C.wa2
            col = mix(base, C.wa0, 0.35 * (1 - t))
            c.put(x, y, col)
        # coping strips
        c.put(x0, y, C.st3); c.put(x0 + 1, y, C.st2); c.put(x0 + 2, y, C.wa0)
        c.put(x1 - 1, y, C.st3); c.put(x1 - 2, y, C.st2)
        c.put(x0 + 3, y, mix(C.wa1, C.wa0, 0.6))
    for _ in range(26):
        x, y = rnd.randint(x0 + 4, x1 - 6), rnd.randint(4, STREET_Y - 4)
        c.hline(x, x + rnd.randint(1, 4), y, C.wa3)
    # a little boat moored far up the lane
    # bridge deck across the street over the lane
    deck = Image.open(A("props", "bridge_deck_48x72.png")).convert("RGBA")
    c.blit(deck, x0 - 4, STREET_Y)
    rest = EDGE_Y + 2 - (STREET_Y + 70)
    c.blit(deck.crop((0, 0, deck.width, rest)), x0 - 4, STREET_Y + 70)
    # shallow steps up onto the hump of the bridge (perpendicular to travel)
    for i in range(3):
        lx = x0 - 1 + 4 * i
        rx = x1 + 1 - 4 * i
        for y in range(STREET_Y + 7, EDGE_Y - 1):
            c.put(lx, y, mix(c.get(lx, y), C.st0, 0.45))
            c.put(lx + 1, y, mix(c.get(lx + 1, y), C.st5, 0.35))
            c.put(rx, y, mix(c.get(rx, y), C.st0, 0.45))
            c.put(rx - 1, y, mix(c.get(rx - 1, y), C.st5, 0.25))
    # crown highlight down the middle of the deck
    mxc = (x0 + x1) // 2
    for y in range(STREET_Y + 7, EDGE_Y - 1):
        for x in range(mxc - 6, mxc + 6):
            if (x + y) % 3 == 0:
                c.put(x, y, mix(c.get(x, y), C.st5, 0.18))
    # curbs where the deck meets the street
    for y in range(STREET_Y, EDGE_Y):
        c.put(x0 - 5, y, C.st4); c.put(x1 + 4, y, C.st1)
    # arch face at the lane mouth on the main canal
    face = Cv.load(A("props", "bridge_arch_face_56x24.png"))
    fx = (x0 + x1) // 2 - face.w // 2
    c.blit(face, fx, WATER_Y - face.h + 1 + 2)
    # reflection of the arch in the canal: dark opening + faint light ring -> "full moon"
    import math as _m
    rcx = fx + face.w / 2 - 0.5
    for y in range(0, 20):
        fade = 1 - y / 20
        wob = int(round(1.2 * _m.sin(y * 1.7)))
        for x in range(face.w):
            X, Y = fx + x + wob, WATER_Y + 3 + y
            d = _m.hypot(x - (face.w / 2 - 0.5), y + 2)
            q = s.c.get(X, Y)
            if d < 15:
                col = mix(q, C.wa0, 0.55 * fade)
            elif d < 18:
                col = mix(q, C.st3, 0.32 * fade) if (y % 2 == 0) else mix(q, C.wa1, 0.2)
            else:
                col = mix(q, C.st1, 0.22 * fade)
            s.c.put(X, Y, col)
    return fx, face


def place_buildings(s):
    blds = [
        ("teahouse_chaguan", -20),
        ("pawnshop_dehoudang", 54),
        ("rice_mihang", 176),
        ("pharmacy_yaopu", 242),
        ("police_jingchasuo_locked", LANE_X1 - 2),
        ("post_youdianju", 414),
    ]
    out = {}
    for name, x in blds:
        im = load("buildings", name + ".png")
        y = STREET_Y - im.height
        out[name] = (x, y, im.width, im.height)
        s.c.blit(im, x, y)
    # ambient occlusion along building bases
    for y in range(STREET_Y, STREET_Y + 5):
        a = [0.38, 0.26, 0.16, 0.08, 0.03][y - STREET_Y]
        for x in range(NW):
            if LANE_X0 - 5 <= x <= LANE_X1 + 4:
                continue
            s.c.put(x, y, mix(s.c.get(x, y), C.black, a))
    return out


def railings(s):
    rail = Image.open(A("props", "bridge_rail_48.png")).convert("RGBA")
    s.add(rail, LANE_X0 - 4, STREET_Y + 4, sort=STREET_Y + 4)
    s.add(rail, LANE_X0 - 4, EDGE_Y + 2, sort=EDGE_Y + 2)


def props(s):
    P = lambda n: load("props", n)
    Y = STREET_Y
    sh = lambda cx, cy, rx, ry=2, a=70: (cx, cy, rx, ry, a)
    # teahouse front: table, rickshaw waiting for customers
    s.add(P("tea_table.png"), 4, Y + 18, shadow=sh(17, Y + 17, 13, 3))
    s.add(P("rickshaw.png"), 30, Y + 31, shadow=sh(44, Y + 29, 14, 3))
    # pawnshop: bench + cat on the step, water vat by the gable
    s.add(P("bench.png"), 60, Y + 9, shadow=sh(73, Y + 8, 13, 2, 60))
    s.add(P("cat_sit.png"), 116, Y + 2, shadow=sh(122, Y + 1, 6))
    s.add(P("water_vat.png"), 160, Y + 6, shadow=sh(168, Y + 5, 8, 3))
    s.add(P("flowerpot.png"), 146, Y + 4, shadow=sh(151, Y + 3, 5))
    # rice shop: sacks, baskets, chickens pecking spilt rice
    s.add(P("rice_sacks.png"), 224, Y + 13, shadow=sh(234, Y + 12, 11, 3))
    s.add(P("rice_sacks.png").transpose(Image.FLIP_LEFT_RIGHT), 208, Y + 8, shadow=sh(218, Y + 7, 10, 3, 60))
    s.add(P("baskets.png"), 180, Y + 9, shadow=sh(188, Y + 8, 8, 2, 60))
    s.add(P("chicken.png"), 236, Y + 26, shadow=sh(240, Y + 25, 3, 1))
    s.add(P("chicken.png").transpose(Image.FLIP_LEFT_RIGHT), 247, Y + 30, shadow=sh(251, Y + 29, 3, 1))
    for (x, y) in ((233, Y + 27), (241, Y + 28), (244, Y + 31), (238, Y + 30)):
        s.c.put(x, y, C.ww0)
    # pharmacy
    s.add(P("herb_rack.png"), 252, Y + 12, shadow=sh(264, Y + 11, 12, 3, 60))
    # police (locked): overgrown bush, notice board
    s.add(P("bush_1.png"), 351, Y + 6, shadow=sh(359, Y + 5, 8, 2, 60))
    s.add(P("notice_board.png"), 398, Y + 16, shadow=sh(407, Y + 15, 8, 2))
    # post office
    s.add(P("mailbox.png"), 417, Y + 12, shadow=sh(422, Y + 11, 5))
    # street centre: well
    s.add(P("well.png"), 92, Y + 50, shadow=sh(101, Y + 48, 10, 3))
    # canal edge: lantern posts, willows, bollards, laundry, barrels
    for lx in (124, 244, 384):
        s.add(P("lantern_post.png"), lx, EDGE_Y + 2, shadow=sh(lx + 10, EDGE_Y + 1, 6, 2, 80))
    s.add(P("willow_48x64.png"), -8, EDGE_Y + 8, shadow=sh(17, EDGE_Y + 5, 16, 4))
    s.add(P("willow_32x48.png"), 270, EDGE_Y + 6, shadow=sh(286, EDGE_Y + 3, 11, 3))
    s.add(P("laundry_pole.png"), 160, EDGE_Y - 2, shadow=sh(184, EDGE_Y - 3, 22, 3, 50))
    s.add(P("bollard.png"), 88, EDGE_Y + 3, shadow=sh(92, EDGE_Y + 2, 3, 1))
    s.add(P("bollard.png"), 134, EDGE_Y + 3, shadow=sh(138, EDGE_Y + 2, 3, 1))
    s.add(P("barrel.png"), 404, EDGE_Y - 2, shadow=sh(411, EDGE_Y - 3, 6, 2))
    s.add(P("crates.png"), 388, EDGE_Y - 18, shadow=sh(396, EDGE_Y - 19, 8, 2, 60))
    # grass tufts along wall bases and the coping
    t1, t2 = P("grass_tuft_1.png"), P("grass_tuft_2.png")
    rnd = random.Random(4)
    for x in list(range(4, NW, 23)):
        if LANE_X0 - 8 < x < LANE_X1 + 6:
            continue
        s.c.blit(t1 if rnd.random() < 0.5 else t2, x + rnd.randint(-3, 3), EDGE_Y - 5)
    for x in (178, 300, 352, 372, 418):
        s.c.blit(t2, x, Y - 2)


def water_life(s):
    c = s.c
    st = load("tiles", "river_steps_32x20.png")
    c.blit(st, 98, EDGE_Y)
    boat = load("props", "boat_48x22.png")
    s.add(boat, 178, 232, shadow=None, sort=232)
    small = load("props", "boat_32x16.png")
    s.add(small, 100, 220, sort=220)
    duck = load("props", "duck.png")
    s.add(duck, 372, 222, sort=222)
    s.add(duck.transpose(Image.FLIP_LEFT_RIGHT), 384, 227, sort=227)
    s.add(duck, 262, 234, sort=234)
    # wakes
    for (x, y) in ((370, 224), (382, 229), (260, 236), (226, 233), (236, 235)):
        c.hline(x - 3, x - 1, y, C.wa4)
        c.hline(x - 6, x - 4, y + 1, C.wa3)
    # reflections of the willow + lanterns (soft streaks)
    for x0 in range(0, 40):
        for y in range(WATER_Y + 1, WATER_Y + 14):
            if (x0 + y) % 3 == 0:
                c.put(x0, y, mix(c.get(x0, y), C.g1, 0.45))
    for lx in (124, 244, 384):
        for y in range(WATER_Y + 2, WATER_Y + 12, 2):
            c.put(lx + 8, y, mix(c.get(lx + 8, y), C.lamp, 0.35))


def people(s):
    def add_char(name, d, f, x, y):
        im = char_frame(name, d, f)
        s.add(im, x, y + 1, shadow=(x + 8.5, y + 0.5, 6, 2, 95))
        return (x, y)
    pos = {}
    Y = STREET_Y
    pos["ruhua"] = add_char("ruhua", "down", 0, 85, Y + 30)
    pos["zhouma"] = add_char("zhouma", "right", 0, 190, Y + 24)
    pos["wangshan"] = add_char("wangshan", "left", 0, 207, Y + 26)
    pos["zhang"] = add_char("zhang", "left", 1, 262, Y + 50)
    pos["ma"] = add_char("ma", "left", 0, 320, Y + 32)
    pos["police"] = add_char("police", "right", 1, 352, Y + 56)
    pos["xiaoding"] = add_char("xiaoding", "down", 0, 119, Y + 72)
    return pos


def markers(s, pos):
    c = s.c
    dots = Cv.load(A("ui", "bubble_dots.png"))
    x, y = pos["zhouma"]
    c.blit(dots, x + 4, y - 40)
    ex = Cv.load(A("ui", "exclaim.png"))
    x, y = pos["ma"]
    c.blit(ex, x + 4, y - 44)


def grade(img):
    """Warm morning light + gentle vignette (keeps pixels crisp: per-pixel ops only)."""
    im = img.convert("RGB")
    px = im.load()
    W, H = im.size
    for y in range(H):
        for x in range(W):
            r, g, b = px[x, y]
            # saturation boost
            l = (r + g + b) / 3
            r, g, b = (l + (r - l) * 1.18, l + (g - l) * 1.18, l + (b - l) * 1.18)
            r, g, b = max(0, min(255, r)), max(0, min(255, g)), max(0, min(255, b))
            # warm lift
            r = min(255, int(r * 1.04 + 6))
            g = min(255, int(g * 1.01 + 3))
            b = int(b * 0.94)
            # top-left sunlight, bottom-right falloff
            d = ((x / W - 0.25) ** 2 * 0.8 + (y / H - 0.3) ** 2)
            f = 1.0 - min(0.22, d * 0.42)
            px[x, y] = (int(r * f), int(g * f), int(b * f))
    return im


# ------------------------------------------------------------------ HUD (full res)
def pixel_text(draw_img, x, y, text, col, size=12, k=2, shadow=None, index=1, path=ZEN):
    """Render bitmap CJK text at `size`, upscale by k with NEAREST, paste at full res."""
    m = font_mask(text, size, path=path, index=index, spacing=1 if size <= 12 else 0)
    m = m.resize((m.width * k, m.height * k), Image.NEAREST)
    if shadow:
        sh = Image.new("RGBA", m.size, shadow)
        draw_img.paste(sh, (x + k, y + k), m)
    fg = Image.new("RGBA", m.size, col)
    draw_img.paste(fg, (x, y), m)
    return m.width, m.height


def panel_native(w, h, style="wood"):
    """Stardew-ish wooden frame with parchment inside (native px)."""
    c = Cv(w, h)
    c.rect(1, 1, w - 2, h - 2, C.wood2)
    c.rect(0, 2, w, h - 4, C.wood2)
    c.rect(2, 0, w - 4, h, C.wood2)
    c.hline(2, w - 3, 1, C.tan)
    c.vline(1, 2, h - 3, C.tan)
    c.hline(2, w - 3, h - 2, C.wood1)
    c.vline(w - 2, 2, h - 3, C.wood1)
    c.rect(3, 3, w - 6, h - 6, C.paper_hi if style == "wood" else C.paper)
    c.hline(3, w - 4, 3, C.wood1)
    c.vline(3, 3, h - 4, C.wood1)
    c.dither(4, h - 7, w - 8, 3, C.paper_hi, C.paper, 0.35)
    # corner studs
    for (x, y) in ((2, 2), (w - 3, 2), (2, h - 3), (w - 3, h - 3)):
        c.put(x, y, C.gold)
    c.outline(C.dkbrown)
    return c


def tag_box(img, x, y, w, h, fill=(31, 23, 18, 235), border=None, pointer=None):
    ov = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(ov)
    border = border or C.wood2
    d.rectangle((x, y, x + w, y + h), fill=fill)
    d.rectangle((x, y, x + w, y + h), outline=C.dkbrown, width=3)
    d.rectangle((x + 3, y + 3, x + w - 3, y + h - 3), outline=border, width=3)
    if pointer:
        px, py = pointer
        d.polygon([(px - 9, y + h), (px + 9, y + h), (px, py)], fill=C.dkbrown)
        d.polygon([(px - 5, y + h - 1), (px + 5, y + h - 1), (px, py - 5)], fill=fill)
    img.alpha_composite(ov)


def hud(img, pos):
    W, H = img.size
    d = ImageDraw.Draw(img)
    ink = C.dkbrown
    # ---------------- top-right clock panel (date / weather+time / money)
    pw, ph = 92, 42
    pnl = scale(panel_native(pw, ph).img, K)
    px0, py0 = W - pnl.width - 10, 8
    img.alpha_composite(pnl, (px0, py0))
    t = "二月初五 · 星期六"
    tw = font_mask(t, 12, spacing=1).width * 2
    pixel_text(img, px0 + (pnl.width - tw) // 2, py0 + 16, t, ink, 12, 2)
    d.rectangle((px0 + 18, py0 + 48, px0 + pnl.width - 18, py0 + 50), fill=C.wood3)
    sun = scale(load("ui", "sun_cloud.png"), K)
    img.alpha_composite(sun, (px0 + 20, py0 + 54))
    pixel_text(img, px0 + 92, py0 + 60, "上午 9:20", ink, 12, 2)
    mx0, my0, mx1 = px0 + 20, py0 + 90, px0 + pnl.width - 20
    d.rectangle((mx0, my0, mx1, my0 + 26), fill=C.wood1, outline=C.dkbrown, width=3)
    d.rectangle((mx0 + 3, my0 + 3, mx1 - 3, my0 + 5), fill=C.wood0)
    coin = scale(load("ui", "coin.png"), 2)
    img.alpha_composite(coin, (mx0 + 8, my0 + 3))
    money = "600 蚨"
    mw = font_mask(money, 12, spacing=1).width * 2
    pixel_text(img, mx1 - 10 - mw, my0 + 2, money, C.lamp, 12, 2, shadow=C.dkbrown)
    # ---------------- top-left pressure ticker
    tk = panel_native(108, 15, style="paper")
    img.alpha_composite(scale(tk.img, K), (10, 8))
    d.rectangle((22, 17, 22 + 56, 17 + 28), fill=C.seal_red, outline=C.dkred, width=2)
    pixel_text(img, 26, 19, "今日", C.paper_hi, 12, 2)
    x = 90
    w_, _ = pixel_text(img, x, 19, "米价 73", ink, 12, 2)
    x += w_ + 12
    ax, ay = x, 20
    d.polygon([(ax, ay), (ax + 9, ay + 10), (ax + 3, ay + 10), (ax + 3, ay + 22), (ax - 3, ay + 22), (ax - 3, ay + 10), (ax - 9, ay + 10)], fill=C.seal_red)
    x += 18
    d.rectangle((x, 21, x + 2, 41), fill=C.paper_old)
    x += 12
    w_, _ = pixel_text(img, x, 19, "灯油", ink, 12, 2)
    x += w_ + 10
    kw = font_mask("紧缺", 12, spacing=1).width * 2
    d.rectangle((x - 4, 16, x + kw + 4, 46), fill=C.flame, outline=C.dkbrown, width=2)
    pixel_text(img, x, 19, "紧缺", C.dkbrown, 12, 2)
    # ---------------- locked police post marker
    cx = (LANE_X1 - 2 + 4 + 33) * K
    lock = scale(load("ui", "padlock.png"), K)
    tw = 190
    tx, ty = cx - tw // 2, 152
    tag_box(img, tx, ty, tw, 44, pointer=(cx, ty + 56))
    img.alpha_composite(lock, (tx + 12, ty + 3))
    pixel_text(img, tx + 56, ty + 9, "尚未开放", C.paper_hi, 12, 2)
    # ---------------- interaction prompt next to 沈如花
    rx, ry = pos["ruhua"]
    bx, by = (rx + 17) * K, (ry - 27) * K
    tag_box(img, bx, by, 176, 40, border=C.gold, pointer=None)
    d = ImageDraw.Draw(img)
    d.rectangle((bx + 10, by + 8, bx + 34, by + 32), fill=C.paper_hi, outline=C.wood1, width=2)
    pixel_text(img, bx + 14, by + 4, "E", C.dkbrown, 16, 2, path=UNIFONT, index=0)
    pixel_text(img, bx + 46, by + 8, "进入德厚当", C.paper_hi, 12, 2)
    # ---------------- mockup label (bottom-left)
    label = "示意图 A/B：俯视小镇（A、B 两方案共用）"
    lw = font_mask(label, 16, spacing=0).width
    ov = Image.new("RGBA", img.size, (0, 0, 0, 0))
    od = ImageDraw.Draw(ov)
    od.rectangle((8, H - 36, 8 + lw + 18, H - 8), fill=(15, 10, 8, 175))
    img.alpha_composite(ov)
    pixel_text(img, 17, H - 31, label, C.paper_hi, 16, 1)
    return img


def main():
    s = Scene()
    build_ground(s)
    build_lane(s)
    place_buildings(s)
    water_life(s)
    railings(s)
    props(s)
    pos = people(s)
    s.flush()
    markers(s, pos)
    native = grade(s.c.img).convert("RGBA")
    native.save(os.path.join(HERE, "A1_town_native.png"))
    big = scale(native, K).crop((0, 0, 1280, 720))
    big = hud(big, pos)
    big.convert("RGB").save(os.path.join(HERE, "A1_town.png"))


if __name__ == "__main__":
    main()
