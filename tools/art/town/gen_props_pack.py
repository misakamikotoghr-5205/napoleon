"""Generate town prop sprites into art/town/props/ from mockup gen_tiles_props."""
import os
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
sys.path.insert(0, os.path.join(ROOT, "docs/town/mockup_src"))
from pix import Cv, C  # noqa: F401  (palette + canvas used by gen_tiles_props)
import gen_tiles_props as g

OUT = os.path.join(ROOT, "art", "town", "props")


def p(name):
    return os.path.join(OUT, name)


def main():
    os.makedirs(OUT, exist_ok=True)
    g.willow(48, 64, seed=3, out=p("willow.png"))
    g.lantern_post(p("lantern_post.png"))
    g.laundry_pole(p("laundry.png"))
    g.rice_sacks(p("rice_sacks.png"))
    g.barrel(p("barrel.png"))
    g.bench(p("bench.png"))
    g.boat(p("boat.png"), w=48, h=22, boatman=True)
    g.cat(p("cat.png"), p("cat_sleep.png"))
    g.chicken(p("chicken.png"))
    g.duck(p("duck.png"))
    g.notice_board(p("notice_wall.png"))

    names = [
        "willow.png",
        "lantern_post.png",
        "laundry.png",
        "rice_sacks.png",
        "barrel.png",
        "bench.png",
        "boat.png",
        "cat.png",
        "cat_sleep.png",
        "chicken.png",
        "duck.png",
        "notice_wall.png",
    ]
    print("PROPS_OK")
    for name in names:
        im = Cv.load(p(name))
        print("%s %dx%d" % (name, im.w, im.h))
    return 0


if __name__ == "__main__":
    sys.exit(main())
