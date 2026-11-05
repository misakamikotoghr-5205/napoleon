"""Rebuild every town art asset, quantize to the contract palette, write manifest + previews.

    python3 tools/art/town/build_all.py
"""
import glob
import json
import os
import subprocess
import sys

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
sys.path.insert(0, HERE)

GENERATORS = [
    "gen_tiles_town.py",
    "gen_tiles_interior.py",
    "gen_buildings_pack.py",
    "gen_props_pack.py",
    "gen_chars_a.py",
    "gen_chars_b.py",
    "gen_chars_c.py",
    "gen_portraits_town.py",
    "gen_shop_bgs.py",
    "gen_ui_town.py",
]

# 32 palette colors + 16 registered extras (contract §2).
EXTRA = {
    "g2": "#4f7238",
    "g4": "#97b85c",
    "wa1": "#21485a",
    "wa3": "#4a8597",
    "wa5": "#c4e0dc",
    "st2": "#726d62",
    "st4": "#aaa392",
    "ww1": "#e3ddcc",
    "ww2": "#cdc6b2",
    "rf1": "#2c3138",
    "rf3": "#58616b",
    "lantern": "#d8432f",
    "dirt1": "#7a5f43",
    "postgreen": "#2f5e3c",
    "skinm": "#dcae86",
    "flower": "#e8607a",
}


def hex_rgb(h):
    h = h.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16))


def load_allowed():
    with open(os.path.join(ROOT, "data", "palette.json"), encoding="utf-8") as f:
        pal = json.load(f)
    cols = [hex_rgb(c) for c in pal["colors"]]
    extra = [hex_rgb(v) for v in EXTRA.values()]
    return cols + extra


ALLOWED = None


def nearest(rgb):
    best = ALLOWED[0]
    best_d = 1e18
    for c in ALLOWED:
        d = (rgb[0] - c[0]) ** 2 + (rgb[1] - c[1]) ** 2 + (rgb[2] - c[2]) ** 2
        if d < best_d:
            best_d = d
            best = c
    return best


def quantize(path):
    im = Image.open(path).convert("RGBA")
    px = im.load()
    changed = 0
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = px[x, y]
            if a < 16:
                if a != 0:
                    px[x, y] = (0, 0, 0, 0)
                    changed += 1
                continue
            n = nearest((r, g, b))
            if (r, g, b, 255) != n + (255,):
                changed += 1
            px[x, y] = n + (255,)
    im.save(path)
    return changed


TOWN_ROW0 = (
    ["road_%d" % i for i in range(5)]
    + ["dirt_0", "dirt_1", "grass_0", "grass_1", "grass_2"]
    + ["road_%d" % i for i in range(5, 11)]
)
TOWN_ROW1 = [
    "water_0", "water_1", "bank_n", "bank_n2", "bank_s", "bank_w", "bank_e",
    "dock_0", "dock_1", "bridge_deck", "bridge_rail", "bridge_arch",
    "water_2", "water_3", "water_4", "water_5",
]
TOWN_ROW2 = (
    ["road_b%d" % i for i in range(4)]
    + ["grass_b%d" % i for i in range(4)]
    + ["dirt_b%d" % i for i in range(4)]
    + ["water_b%d" % i for i in range(4)]
)
INTERIOR_ROW0 = [
    "floor_0", "floor_1", "floor_2", "floor_rug", "wall_0", "wall_1", "wall_wood",
    "counter_top", "counter_face", "block_0", "wall_2", "wall_3", "floor_6", "floor_7", "wall_4", "floor_8",
]
INTERIOR_ROW1 = ["floor_c%d" % i for i in range(16)]


def walk_of(tid):
    if tid.startswith("water") or tid == "bridge_arch":
        return False
    if tid.startswith("wall") or tid.startswith("counter") or tid.startswith("block"):
        return False
    return True


def water_of(tid):
    return tid.startswith("water") or tid == "bridge_arch"


def tile_ids(names_rows):
    ids = {}
    for row, names in enumerate(names_rows):
        for col, name in enumerate(names):
            ids[name] = {"at": [col, row], "walk": walk_of(name), "water": water_of(name)}
            if not ids[name]["water"]:
                del ids[name]["water"]
    return ids


def rel(path):
    return os.path.relpath(path, ROOT).replace(os.sep, "/")


def png_size(path):
    im = Image.open(path)
    return [im.width, im.height]


def build_manifest():
    tiles_town = os.path.join(ROOT, "art/town/tiles/town.png")
    tiles_in = os.path.join(ROOT, "art/town/tiles/interior.png")
    manifest = {
        "version": 1,
        "tile": 16,
        "palette_extra": list(EXTRA.values()),
        "tiles": {
            "town": {"image": "art/town/tiles/town.png", "ids": tile_ids([TOWN_ROW0, TOWN_ROW1, TOWN_ROW2])},
            "interior": {"image": "art/town/tiles/interior.png", "ids": tile_ids([INTERIOR_ROW0, INTERIOR_ROW1])},
        },
        "buildings": {},
        "props": {},
        "chars": {},
        "shops": {},
        "ui": {},
    }
    meta_path = os.path.join(HERE, "building_meta.json")
    meta = {}
    if os.path.exists(meta_path):
        with open(meta_path, encoding="utf-8") as f:
            meta = json.load(f)
    for path in sorted(glob.glob(os.path.join(ROOT, "art/town/buildings/*.png"))):
        name = os.path.splitext(os.path.basename(path))[0]
        if name.endswith("_night") or name.endswith("_locked"):
            continue
        w, h = png_size(path)
        info = meta.get(name, {})
        door = info.get("door") or [max(0, w // 2 - 8), max(0, h - 24), 16, min(24, h)]
        roof = info.get("roof_split_y", int(h * 0.42))
        foot = info.get("footprint") or [0, roof, w, max(1, h - roof)]
        entry = {
            "image": rel(path),
            "size": [w, h],
            "door": door,
            "footprint": foot,
            "roof_split_y": roof,
            "variants": {},
        }
        night = path.replace(".png", "_night.png")
        locked = path.replace(".png", "_locked.png")
        if os.path.exists(night):
            entry["variants"]["night"] = rel(night)
        if os.path.exists(locked):
            entry["variants"]["locked"] = rel(locked)
        # police.png may be absent and only police_locked exists — handled below
        manifest["buildings"][name] = entry
    if "police" not in manifest["buildings"] and os.path.exists(os.path.join(ROOT, "art/town/buildings/police_locked.png")):
        p = os.path.join(ROOT, "art/town/buildings/police_locked.png")
        w, h = png_size(p)
        manifest["buildings"]["police"] = {
            "image": "art/town/buildings/police_locked.png",
            "size": [w, h],
            "door": [max(0, w // 2 - 8), max(0, h - 24), 16, min(24, h)],
            "footprint": [0, int(h * 0.42), w, max(1, h - int(h * 0.42))],
            "roof_split_y": int(h * 0.42),
            "variants": {"locked": "art/town/buildings/police_locked.png"},
        }
    prop_meta = {}
    pm = os.path.join(HERE, "prop_meta.json")
    if os.path.exists(pm):
        with open(pm, encoding="utf-8") as f:
            prop_meta = json.load(f)
    for path in sorted(glob.glob(os.path.join(ROOT, "art/town/props/*.png"))):
        name = os.path.splitext(os.path.basename(path))[0]
        w, h = png_size(path)
        info = prop_meta.get(name, {})
        anchor = info.get("anchor") or [w // 2, max(0, h - 2)]
        foot = info.get("footprint") or [max(0, w // 2 - 4), max(0, h - 6), min(8, w), min(6, h)]
        manifest["props"][name] = {
            "image": rel(path),
            "anchor": anchor,
            "footprint": foot,
        }
    for path in sorted(glob.glob(os.path.join(ROOT, "art/town/chars/*.png"))):
        name = os.path.splitext(os.path.basename(path))[0]
        manifest["chars"][name] = {
            "image": rel(path),
            "frame": [16, 32],
            "foot": [8, 30],
        }
    shop_meta = {}
    sm = os.path.join(HERE, "shop_meta.json")
    if os.path.exists(sm):
        with open(sm, encoding="utf-8") as f:
            shop_meta = json.load(f)
    keepers = {
        "teahouse": "zhouma", "ricehall": "wu", "pharmacy": "chen",
        "baogong": "ma", "post": "postman", "market": "stranger_peddler",
    }
    for path in sorted(glob.glob(os.path.join(ROOT, "art/town/shops/*_bg.png"))):
        base = os.path.basename(path)
        sid = base[: -len("_bg.png")]
        info = shop_meta.get(sid, {})
        manifest["shops"][sid] = {
            "bg": rel(path),
            "keeper": info.get("keeper", keepers.get(sid, "")),
            "keeper_at": info.get("keeper_at", [160, 40]),
        }
    ui_nine = {"dialog_frame": [6, 6, 6, 6]}
    for path in sorted(glob.glob(os.path.join(ROOT, "art/town/ui/*.png"))):
        name = os.path.splitext(os.path.basename(path))[0]
        entry = {"image": rel(path)}
        if name in ui_nine:
            entry["nine"] = ui_nine[name]
        manifest["ui"][name] = entry
    out = os.path.join(ROOT, "art/town/manifest.json")
    with open(out, "w", encoding="utf-8") as f:
        json.dump(manifest, f, ensure_ascii=False, indent=2)
        f.write("\n")
    print("manifest", out)
    # size assertions for the atlases
    tw, th = png_size(tiles_town)
    iw, ih = png_size(tiles_in)
    if (tw, th) != (256, 48):
        raise SystemExit("town.png is %sx%s, want 256x48" % (tw, th))
    if (iw, ih) != (256, 32):
        raise SystemExit("interior.png is %sx%s, want 256x32" % (iw, ih))
    return manifest


def quantize_tree():
    global ALLOWED
    ALLOWED = load_allowed()
    paths = []
    for folder in ("art/town",):
        for dirpath, _dirs, files in os.walk(os.path.join(ROOT, folder)):
            for fn in files:
                if fn.endswith(".png"):
                    paths.append(os.path.join(dirpath, fn))
    for fn in (
        "ruhua.png", "wu.png", "postman.png",
        "stranger_refugee.png", "stranger_peddler.png", "stranger_fence.png", "stranger_collector.png",
    ):
        p = os.path.join(ROOT, "art/portraits", fn)
        if os.path.exists(p):
            paths.append(p)
    total = 0
    for p in paths:
        total += quantize(p)
    print("quantized", len(paths), "pngs,", total, "pixels snapped")


def run_generators():
    for name in GENERATORS:
        path = os.path.join(HERE, name)
        if not os.path.exists(path):
            print("skip missing", name)
            continue
        print("==", name)
        subprocess.check_call([sys.executable, path], cwd=ROOT)


def main():
    run_generators()
    quantize_tree()
    build_manifest()
    subprocess.check_call([sys.executable, os.path.join(HERE, "gen_maps.py")], cwd=ROOT)
    subprocess.check_call([sys.executable, os.path.join(HERE, "preview.py")], cwd=ROOT)
    print("BUILD_ALL_OK")


if __name__ == "__main__":
    main()
