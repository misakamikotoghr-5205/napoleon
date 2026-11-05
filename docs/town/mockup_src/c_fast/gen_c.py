"""Mockup C (2.5D / HD-2D street): generate pixel textures + layout.json for the Godot scene.

Reuses the shared generators in ../ (read-only imports; nothing is written to ../assets).
Outputs into ./proj/tex/ and ./proj/layout.json
"""
import json
import math
import os
import random
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
MOCK = os.path.dirname(HERE)
sys.path.insert(0, MOCK)

from PIL import Image, ImageDraw, ImageFilter  # noqa: E402
from pix import Cv, C, ASSETS, mix, font_mask, scale, ZEN  # noqa: E402
import gen_buildings as gb  # noqa: E402
import gen_tiles_props as gtp  # noqa: E402

TEX = os.path.join(HERE, "proj", "tex")
os.makedirs(TEX, exist_ok=True)
PX = 16.0  # pixels per metre


def save(img, name):
    if isinstance(img, Cv):
        img = img.img
    img.save(os.path.join(TEX, name))
    return name


# ------------------------------------------------------------------ facades without roofs
LANTERNS = []


def _blank_roof(w, h, seed, ridge=True, **kw):
    return Cv(w, h + gb.UP)


def _record_lantern(c, x, y):
    LANTERNS.append((x, y))


gb.roof_layer = _blank_roof
gb.hanging_lantern = _record_lantern


def facade(builder, x0, fw, name):
    LANTERNS.clear()
    c = builder()
    im = c.img
    W, H = im.size
    # top = first row where the facade's middle columns are opaque
    top = None
    for y in range(H):
        row = [im.getpixel((x, y))[3] for x in range(x0 + 2, x0 + fw - 2)]
        if sum(1 for a in row if a > 0) > 0.9 * len(row):
            top = y
            break
    crop = im.crop((x0, top, x0 + fw, H))
    # fill any remaining holes with plaster colour so the box face is solid
    bg = Image.new("RGBA", crop.size, C.ww2)
    bg.alpha_composite(crop)
    save(bg, name)
    lan = [((lx - x0) / PX, (ly - top) / PX) for (lx, ly) in LANTERNS]
    return {"tex": name, "w": fw / PX, "h": (H - top) / PX, "lanterns": lan, "top_px": top}


def pent_rows():
    """Row (from facade top) where the painted pent eave used to be, per 2-storey builder."""
    return {"upper_h": 21, "pent_h": 7}


facades = {}
facades["tea"] = facade(gb.build_teahouse, gb.OV, 74, "f_tea.png")
facades["pawn"] = facade(gb.build_pawnshop, gb.OV, 70, "f_pawn.png")
facades["rice"] = facade(gb.build_rice, gb.OV, 66, "f_rice.png")
facades["pharm"] = facade(gb.build_pharmacy, gb.OV, 62, "f_pharm.png")
facades["police"] = facade(gb.build_police, gb.OV, 66, "f_police.png")
facades["post"] = facade(gb.build_post, gb.OV, 62, "f_post.png")
facades["sun"] = facade(gb.build_sun_gate, gb.OV, 92, "f_sun.png")
# 2-storey: pent eave sits upper_h px below the top
for k in ("tea", "pawn", "pharm", "post"):
    facades[k]["pent_y"] = 21 / PX


# ------------------------------------------------------------------ giant 当 gable wall
def gable_tex():
    gw, gh = 56, 108
    c = Cv(gw, gh)
    gb.plaster(c, 0, 0, gw, gh, 110, stain=0.55)
    # cap shadow friezes for the three levels (top of outer=26, middle=13, centre=0)
    for ty, x0, x1 in ((26, 0, 12), (26, 44, 56), (13, 12, 22), (13, 34, 44), (0, 22, 34)):
        for xx in range(x0, x1):
            for k, a in ((0, 0.45), (1, 0.25), (2, 0.1)):
                p = c.get(xx, ty + k)
                c.put(xx, ty + k, mix(p, C.black, a))
            if xx % 4 == 1:
                c.put(xx, ty + 5, C.ww3)
        c.hline(x0 + 1, x1 - 2, ty + 4, C.ww3)
    m = font_mask("当", 36, index=0)
    m = m.filter(ImageFilter.MaxFilter(3)).point(lambda v: 255 if v > 100 else 0)
    # scale x1.25 for a bigger brush character
    m = m.resize((int(m.width * 1.2), int(m.height * 1.2)), Image.NEAREST)
    mx = (gw - m.width) // 2
    my = 36
    mp = m.load()
    rnd = random.Random(7)
    for yy in range(m.height):
        for xx in range(m.width):
            if mp[xx, yy]:
                col = C.black if rnd.random() > 0.06 else C.rf1
                c.put(mx + xx, my + yy, col)
    # dry-brush flecks at stroke ends
    for _ in range(18):
        x, y = rnd.randint(mx, mx + m.width), rnd.randint(my, my + m.height)
        if c.get(x, y)[0] > 150:
            if any(mp[min(m.width - 1, max(0, x - mx + dx)), min(m.height - 1, max(0, y - my + dy))] for dx in (-1, 1) for dy in (-1, 1)):
                c.put(x, y, C.rf1)
    gb.plinth(c, 0, gh - 7, gw, 7, seed=3)
    return save(c, "f_gable.png"), gw / PX, gh / PX


gable = gable_tex()


# ------------------------------------------------------------------ tileable materials
def roof_tiles(w=64, h=64, seed=1, moss=0.07, light=0):
    rnd = random.Random(seed)
    c = Cv(w, h)
    pal = [C.rf4, C.rf3, C.rf2, C.rf1, C.rf0]
    for y in range(h):
        for x in range(w):
            k = x % 4
            base = [1, 2, 3, 4][k]
            if y % 4 == 3:
                base = [0, 1, 2, 4][k]
            if k in (1, 2) and (x * 7 + y * 3) % 11 == 0:
                base -= 1
            base = max(0, min(4, base - light))
            col = pal[base]
            if k == 3 and rnd.random() < moss:
                col = rnd.choice([C.g1, C.g1, C.g2, C.g3])
            if rnd.random() < 0.012 and k in (0, 1):
                col = C.rf4
            c.put(x, y, col)
    return c


save(roof_tiles(seed=1), "roof.png")
save(roof_tiles(seed=2, moss=0.02, light=-1), "roof_far.png")


def eave_strip():
    # round tile ends (瓦当) + drip tiles: 16 x 5, tiles horizontally
    c = Cv(16, 5, C.rf0)
    c.hline(0, 15, 0, C.rf2)
    for x in range(16):
        k = x % 4
        c.put(x, 1, [C.rf3, C.rf4, C.rf3, C.rf0][k])
        c.put(x, 2, [C.rf2, C.rf3, C.rf1, C.rf0][k])
        c.put(x, 3, [C.rf1, C.rf2, C.rf0, C.rf0][k])
    return c


save(eave_strip(), "eave.png")


def ridge_tex():
    c = Cv(16, 8, C.rf1)
    c.hline(0, 15, 0, C.rf3)
    c.hline(0, 15, 1, C.rf2)
    for x in range(0, 16, 3):
        c.vline(x, 2, 5, C.rf0)
        c.put(x + 1, 2, C.rf3)
    c.hline(0, 15, 6, C.rf0)
    c.hline(0, 15, 7, C.rf0)
    return c


save(ridge_tex(), "ridge.png")


def plaster_tile(seed=5, w=64, h=64):
    rnd = random.Random(seed)
    c = Cv(w, h, C.ww1)
    for y in range(h):
        for x in range(w):
            r = rnd.random()
            if r < 0.05:
                c.put(x, y, C.ww0)
            elif r < 0.09:
                c.put(x, y, C.ww2)
    for _ in range(10):
        sx = rnd.randint(0, w - 1)
        y0 = rnd.randint(0, h - 1)
        for k in range(rnd.randint(4, 18)):
            if rnd.random() < 0.6:
                c.put(sx, (y0 + k) % h, C.ww2 if rnd.random() < 0.75 else C.ww3)
    return c


save(plaster_tile(), "plaster.png")


def wood_side():
    c = Cv(32, 32, C.wood1)
    rnd = random.Random(3)
    for x in range(32):
        if x % 6 == 0:
            c.vline(x, 0, 31, C.wood0)
        elif rnd.random() < 0.2:
            c.vline(x, 0, 31, C.wood2)
    return c


save(wood_side(), "wood.png")


# street pavement: one big non-repeating field covering x -24..24 (768px) and z -4..8 (192px)
def street():
    w, h = 768, 192
    def moss(x, y):
        # mossy near building line (z~0 -> y=64) and near canal (z~6.5 -> y=168)
        d = min(abs(y - 64), abs(y - 168))
        return 0.25 if d < 4 else 0.05
    c = gtp.slab_field(w, h, 77, wear_band=(90, 130), moss_fn=moss)
    # warm the stones a touch
    return c


save(street(), "street.png")


def canal_wall(w=128, h=24, seed=9):
    """Embankment face: coping (3 rows) -> block courses -> damp algae band. Tiles horizontally."""
    rnd = random.Random(seed)
    c = Cv(w, h, C.st1)
    c.rect(0, 0, w, 3, C.st3)
    c.hline(0, w - 1, 0, C.st4)
    c.hline(0, w - 1, 2, C.st2)
    for x in range(0, w, 13):
        c.vline(x, 0, 2, C.st1)
    c.hline(0, w - 1, 3, C.st0)
    y = 4
    row = 0
    while y < h:
        bh = 5
        x = -(row % 2) * 6
        while x < w:
            bw = rnd.randint(9, 15)
            base = rnd.choice([C.st1, C.st2, mix(C.st1, C.st2, 0.5), mix(C.st2, C.st3, 0.3)])
            c.rect(max(0, x + 1), y, min(w, x + bw) - max(0, x + 1), bh - 1, base)
            c.hline(max(0, x + 1), min(w - 1, x + bw - 1), y, mix(base, C.st3, 0.5))
            x += bw
        c.hline(0, w - 1, y + bh - 1, C.st0)
        y += bh
        row += 1
    c.noise(0, 4, w, h - 4, [C.g1, C.g2], 0.06, rnd)
    for x in range(w):
        for yy in range(h - 6, h):
            t = (yy - (h - 6)) / 6
            if rnd.random() < 0.3 + 0.6 * t:
                c.put(x, yy, mix(c.get(x, yy), C.g0 if rnd.random() < 0.5 else C.wa0, 0.35 + 0.4 * t))
    for _ in range(14):
        x = rnd.randint(0, w - 1)
        for yy in range(6, h):
            if rnd.random() < 0.6:
                c.put(x, yy, mix(c.get(x, yy), C.wa0, 0.3))
    return c


save(canal_wall(), "canal_wall.png")


def stone_tile(seed=11, w=32, h=32):
    rnd = random.Random(seed)
    c = Cv(w, h, C.st2)
    for by in range(0, h, 8):
        off = 0 if (by // 8) % 2 == 0 else 8
        for bx in range(-16 + off, w, 16):
            base = rnd.choice([C.st2, C.st3, mix(C.st2, C.st3, 0.5)])
            for yy in range(by, by + 7):
                for xx in range(bx + 1, bx + 16):
                    c.put(xx % w, yy, base)
            for xx in range(bx + 1, bx + 16):
                c.put(xx % w, by, mix(base, C.st4, 0.5))
        c.hline(0, w - 1, by + 7, C.st1)
    c.noise(0, 0, w, h, [C.st1, C.st4], 0.04, rnd)
    return c


save(stone_tile(), "stone.png")


def water():
    rnd = random.Random(4)
    tiles = [Image.open(os.path.join(ASSETS, "tiles", "water_%d.png" % i)).convert("RGBA") for i in (1, 2, 3)]
    im = Image.new("RGBA", (64, 64))
    for ty in range(4):
        for tx in range(4):
            im.paste(rnd.choice(tiles), (tx * 16, ty * 16))
    return im


save(water(), "water.png")

# copy sprites we use (unchanged) so the Godot project is self-contained
for sub, names in {
    "chars": ["ruhua_sheet", "zhouma_sheet", "zhang_sheet", "wangshan_sheet", "ma_sheet", "police_sheet", "xiaoding_sheet"],
    "props": ["willow_48x64", "willow_32x48", "lantern_red", "lantern_post", "rice_sacks", "barrel", "water_vat", "baskets",
              "cat_sit", "boat_48x22", "boat_32x16", "bench", "tea_table", "herb_rack", "notice_board", "flowerpot",
              "bush_1", "bush_flower", "crates", "duck", "bollard", "grass_tuft_1", "grass_tuft_2", "mailbox", "chicken",
              "laundry_pole", "rickshaw"],
    "buildings": ["back_roofs_strip"],
}.items():
    for n in names:
        Image.open(os.path.join(ASSETS, sub, n + ".png")).convert("RGBA").save(os.path.join(TEX, n + ".png"))


# blob shadow + soft glow sprites
def radial(name, size, col, power=1.6, amax=1.0):
    im = Image.new("RGBA", (size, size))
    px = im.load()
    c = (size - 1) / 2
    for y in range(size):
        for x in range(size):
            d = math.hypot(x - c, y - c) / c
            a = max(0.0, 1 - d) ** power * amax
            px[x, y] = (col[0], col[1], col[2], int(255 * a))
    im.save(os.path.join(TEX, name))


radial("blob.png", 64, (20, 14, 10), 1.2, 0.85)
radial("glow.png", 64, (255, 190, 120), 2.2, 1.0)

layout = {"facades": facades, "gable": {"tex": gable[0], "w": gable[1], "h": gable[2]}}
with open(os.path.join(HERE, "proj", "layout.json"), "w") as f:
    json.dump(layout, f, indent=1, ensure_ascii=False)
print(json.dumps(layout, ensure_ascii=False))


# ------------------------------------------------------------------ UI (full-res overlays, pixel text x2)
import compose_A1 as ca  # noqa: E402


def hud():
    W, H = 1280, 720
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    ink = C.dkbrown
    K = 3
    pnl = scale(ca.panel_native(92, 42).img, K)
    px0, py0 = W - pnl.width - 10, 8
    img.alpha_composite(pnl, (px0, py0))
    t = "二月初五 · 星期六"
    tw = font_mask(t, 12, spacing=1).width * 2
    ca.pixel_text(img, px0 + (pnl.width - tw) // 2, py0 + 16, t, ink, 12, 2)
    d.rectangle((px0 + 18, py0 + 48, px0 + pnl.width - 18, py0 + 50), fill=C.wood3)
    sun = Image.open(os.path.join(ASSETS, "ui", "sun.png")).convert("RGBA")
    # late-afternoon sun: push it toward orange
    sp = sun.load()
    for y in range(sun.height):
        for x in range(sun.width):
            r, g, b, a = sp[x, y]
            if a:
                sp[x, y] = (min(255, r + 10), int(g * 0.78), int(b * 0.6), a)
    img.alpha_composite(scale(sun, K), (px0 + 24, py0 + 54))
    ca.pixel_text(img, px0 + 92, py0 + 60, "下午 4:40", ink, 12, 2)
    mx0, my0, mx1 = px0 + 20, py0 + 90, px0 + pnl.width - 20
    d.rectangle((mx0, my0, mx1, my0 + 26), fill=C.wood1, outline=C.dkbrown, width=3)
    d.rectangle((mx0 + 3, my0 + 3, mx1 - 3, my0 + 5), fill=C.wood0)
    coin = scale(Image.open(os.path.join(ASSETS, "ui", "coin.png")).convert("RGBA"), 2)
    img.alpha_composite(coin, (mx0 + 8, my0 + 3))
    money = "600 蚨"
    mw = font_mask(money, 12, spacing=1).width * 2
    ca.pixel_text(img, mx1 - 10 - mw, my0 + 2, money, C.lamp, 12, 2, shadow=C.dkbrown)
    # mockup label (bottom-left)
    label = "示意图 C：2.5D 景深"
    lw = font_mask(label, 16, spacing=0).width
    ov = Image.new("RGBA", img.size, (0, 0, 0, 0))
    od = ImageDraw.Draw(ov)
    od.rectangle((8, H - 36, 8 + lw + 18, H - 8), fill=(15, 10, 8, 175))
    img.alpha_composite(ov)
    ca.pixel_text(img, 17, H - 31, label, C.paper_hi, 16, 1)
    img.save(os.path.join(TEX, "hud.png"))


def bubble():
    lines = ["如花，今儿", "开门早啊。"]
    ms = [font_mask(t, 12, spacing=1) for t in lines]
    lh = 14
    w = max(m.width for m in ms) + 16
    h = lh * len(lines) + 14
    oy = 7  # room for the name tab
    c = Cv(w + 2, h + oy + 10)
    c.rect(1, oy + 1, w - 2, h - 2, C.paper_hi)
    c.rect(0, oy + 2, w, h - 4, C.paper_hi)
    c.rect(2, oy, w - 4, h, C.paper_hi)
    c.dither(3, oy + h - 4, w - 6, 2, C.paper_hi, C.paper, 0.4)
    # tail at bottom-right, pointing down-right toward the speaker's head
    tx = w - 16
    for i in range(8):
        c.hline(tx + i, tx + 8, oy + h - 1 + i, C.paper_hi)
    c.outline(C.dkbrown)
    for i, t in enumerate(lines):
        c.text(8, oy + 9 + i * lh, t, C.dkbrown, 12, spacing=1)
    nb = font_mask("周妈", 12, spacing=1)
    tw = nb.width + 8
    t = Cv(tw, 13, C.seal_red)
    t.hline(0, tw - 1, 0, C.lantern_hi)
    t.text(4, 1, "周妈", C.paper_hi, 12, spacing=1)
    big = Cv(c.w + 2, c.h + 2)
    big.blit(c, 1, 1)
    tab = Cv(tw + 2, 15)
    tab.blit(t, 1, 1)
    tab.outline(C.dkbrown)
    big.blit(tab, 5, 0)
    out = scale(big.img, 2)
    out.save(os.path.join(TEX, "bubble.png"))
    return (tx + 8 + 2) * 2, (oy + h + 7 + 2) * 2  # tail tip in bubble px


tip = bubble()
hud()
layout["bubble_tip"] = tip
with open(os.path.join(HERE, "proj", "layout.json"), "w") as f:
    json.dump(layout, f, indent=1, ensure_ascii=False)


def lock_tag():
    w, h = 150, 40
    img = Image.new("RGBA", (w + 4, h + 20), (0, 0, 0, 0))
    ca.tag_box(img, 2, 2, w - 4, h - 4, pointer=(w // 2, h + 12))
    lock = scale(Image.open(os.path.join(ASSETS, "ui", "padlock.png")).convert("RGBA"), 2)
    img.alpha_composite(lock, (12, 8))
    ca.pixel_text(img, 44, 8, "尚未开放", C.paper_hi, 12, 2)
    img.save(os.path.join(TEX, "locktag.png"))
    return (w // 2, h + 12)


layout["lock_tip"] = lock_tag()
with open(os.path.join(HERE, "proj", "layout.json"), "w") as f:
    json.dump(layout, f, indent=1, ensure_ascii=False)
