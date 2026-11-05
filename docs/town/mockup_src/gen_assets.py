"""Generate every shared pixel asset for the 青溪镇 mockups into ./assets/.

    python3 gen_assets.py          # tiles, props, ui, bridge, buildings, characters + preview sheets

Order matters: buildings blit the lantern prop, so props are generated first.
Sub-generators (importable, each has gen_all()):
    gen_tiles_props.py   16x16 tiles, props, bridge parts, UI icons, slab_field()
    gen_buildings.py     3/4 top-down Jiangnan buildings (signs baked in)
    gen_chars.py         16x32 character sheets (3 frames x 4 dirs)
Shared helpers: pix.py (Cv canvas, palette C, bitmap CJK text).
"""
import glob
import os

from pix import ASSETS, contact
import gen_tiles_props
import gen_buildings
import gen_chars


def previews():
    pv = os.path.join(ASSETS, "_preview")
    os.makedirs(pv, exist_ok=True)
    contact(sorted(glob.glob(os.path.join(ASSETS, "tiles", "*.png"))), os.path.join(pv, "tiles_x4.png"), k=4, cols=8)
    contact(sorted(glob.glob(os.path.join(ASSETS, "props", "*.png"))) + sorted(glob.glob(os.path.join(ASSETS, "ui", "*.png"))),
            os.path.join(pv, "props_ui_x3.png"), k=3, cols=10)
    contact(sorted(glob.glob(os.path.join(ASSETS, "buildings", "*.png"))), os.path.join(pv, "buildings_x2.png"), k=2, cols=4,
            bg=(150, 140, 120, 255))
    contact(sorted(glob.glob(os.path.join(ASSETS, "chars", "*_sheet.png"))), os.path.join(pv, "chars_x3.png"), k=3, cols=7,
            bg=(150, 140, 125, 255))


def main():
    gen_tiles_props.gen_all()
    gen_buildings.gen_all()
    gen_chars.gen_all()
    previews()


if __name__ == "__main__":
    main()
