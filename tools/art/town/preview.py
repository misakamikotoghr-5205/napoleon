"""Compose review sheets. python3 tools/art/town/preview.py"""
import json
import os
from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
OUT = os.path.join(ROOT, "docs/town/previews")
TILE = 16


def load_map(name):
    with open(os.path.join(ROOT, "data/town/maps", name), encoding="utf-8") as f:
        return json.load(f)


def load_manifest():
    with open(os.path.join(ROOT, "art/town/manifest.json"), encoding="utf-8") as f:
        return json.load(f)


def blit(dst, src, x, y):
    if src.mode != "RGBA":
        src = src.convert("RGBA")
    dst.alpha_composite(src, (int(x), int(y)))


def crop_tile(sheet, at):
    col, row = at
    x, y = col * TILE, row * TILE
    return sheet.crop((x, y, x + TILE, y + TILE)).convert("RGBA")


def render_map(map_id, tileset_name, out_name):
    man = load_manifest()
    m = load_map(map_id + ".json")
    spec = man["tiles"][tileset_name]
    sheet = Image.open(os.path.join(ROOT, spec["image"])).convert("RGBA")
    ids = spec["ids"]
    w, h = m["size"]
    canvas = Image.new("RGBA", (w * TILE, h * TILE), (20, 16, 12, 255))
    ground = [row.split(" ") for row in m["layers"]["ground"]]
    for y in range(h):
        for x in range(w):
            tid = ground[y][x]
            if tid == "." or tid not in ids:
                continue
            canvas.alpha_composite(crop_tile(sheet, ids[tid]["at"]), (x * TILE, y * TILE))
    # props and buildings, y-sorted by foot
    draws = []
    for obj in m["objects"]:
        kind, oid, at = obj["kind"], obj["id"], obj["at"]
        if kind == "building" and oid in man["buildings"]:
            info = man["buildings"][oid]
            im = Image.open(os.path.join(ROOT, info["image"])).convert("RGBA")
            foot_y = at[1] * TILE + im.height
            draws.append((foot_y, at[0] * TILE, at[1] * TILE, im))
        elif kind == "prop" and oid in man["props"]:
            info = man["props"][oid]
            im = Image.open(os.path.join(ROOT, info["image"])).convert("RGBA")
            ax, ay = info["anchor"]
            px = at[0] * TILE - ax
            py = at[1] * TILE - ay
            draws.append((at[1] * TILE, px, py, im))
    draws.sort(key=lambda t: t[0])
    for _fy, x, y, im in draws:
        blit(canvas, im, x, y)
    # door markers
    for d in m["doors"]:
        x, y = d["at"]
        for i in range(4):
            canvas.putpixel((x * TILE + 6 + i, y * TILE + 6), (208, 48, 42, 255))
    scale = 2
    big = canvas.resize((canvas.width * scale, canvas.height * scale), Image.NEAREST)
    os.makedirs(OUT, exist_ok=True)
    dest = os.path.join(OUT, out_name)
    big.convert("RGB").save(dest)
    print("preview", dest, big.size)


def contact_chars():
    man = load_manifest()
    names = sorted(man["chars"])
    if not names:
        return
    cell_w, cell_h = 64, 128
    cols = 8
    rows = (len(names) + cols - 1) // cols
    sheet = Image.new("RGBA", (cols * cell_w, rows * (cell_h + 8)), (30, 26, 22, 255))
    for i, name in enumerate(names):
        im = Image.open(os.path.join(ROOT, man["chars"][name]["image"])).convert("RGBA")
        x = (i % cols) * cell_w
        y = (i // cols) * (cell_h + 8)
        sheet.alpha_composite(im, (x, y))
    dest = os.path.join(OUT, "chars_sheet.png")
    sheet.convert("RGB").save(dest)
    print("preview", dest)


def contact_shops():
    man = load_manifest()
    names = sorted(man["shops"])
    if not names:
        return
    w, h = 320, 180
    sheet = Image.new("RGB", (w, h * len(names)), (0, 0, 0))
    for i, name in enumerate(names):
        im = Image.open(os.path.join(ROOT, man["shops"][name]["bg"])).convert("RGB")
        im = im.resize((w, h)) if im.size != (w, h) else im
        sheet.paste(im, (0, i * h))
    dest = os.path.join(OUT, "shops_sheet.png")
    sheet.save(dest)
    print("preview", dest)


def main():
    render_map("town", "town", "town_map.png")
    render_map("pawnshop", "interior", "pawnshop_map.png")
    contact_chars()
    contact_shops()
    print("PREVIEW_OK")


if __name__ == "__main__":
    main()
