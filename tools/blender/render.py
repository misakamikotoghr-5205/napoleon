# Render one scene variant. Run with Blender 4.0.x / 4.1.x (see BLENDER_PIPELINE.md section 2):
#   blender -b --factory-startup -noaudio --python-exit-code 1 --python tools/blender/render.py -- \
#       --scene counter --variant day --out tools/blender/out/bg.counter.day.raw.png [--mode toon|soft]
#       [--size 320x180] [--line 1] [--aa] [--allow-new-blender]
# toon (default): cel-shaded EEVEE at the scene's pixel size, 1px outlines -> then run pix.py.
# soft: plain Cycles render, for checking layout and light only.
# Before rendering, every model and image in the scene is checked against the packs registered in
# docs/cards/art/blender/MODELS.csv; anything else stops the render (red line 1).
import argparse
import csv
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import bpy  # noqa: E402

import bl_lib as L  # noqa: E402
from scenes import SCENES  # noqa: E402

REGISTRY = os.path.join(HERE, "..", "..", "docs", "cards", "art", "blender", "MODELS.csv")


def registered_packs():
    if not os.path.isfile(REGISTRY):
        raise RuntimeError("model registry missing: %s" % os.path.normpath(REGISTRY))
    with open(REGISTRY, encoding="utf-8") as f:
        return {r["model_pack_or_file"] for r in csv.DictReader(f)}


def check_sources():
    """Every loaded model must come from a registered pack, and every image from such a model."""
    packs = registered_packs()
    roots = [os.path.realpath(os.path.join(root, p)) for root in L.MODEL_ROOTS for p in packs]

    def inside(path):
        path = os.path.realpath(path)
        return any(path.startswith(r + os.sep) for r in roots)

    bad = ["model %s (pack %s)" % (path, pack) for pack, path in L.LOADED if pack not in packs or not inside(path)]
    for im in bpy.data.images:
        if im.source in ("GENERATED", "VIEWER") or im.type in ("RENDER_RESULT", "COMPOSITING"):
            continue
        src = im.get("source_model", "")
        path = bpy.path.abspath(im.filepath) if im.filepath else ""
        if not ((src and inside(src)) or (path and inside(path))):
            bad.append("image %s (%s)" % (im.name, path or "embedded, not from a registered model"))
    if bad:
        raise RuntimeError("not from a pack registered in MODELS.csv: " + "; ".join(bad))


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    ap = argparse.ArgumentParser(prog="render.py")
    ap.add_argument("--scene", required=True, choices=sorted(SCENES))
    ap.add_argument("--variant", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--mode", choices=("toon", "soft"), default="toon")
    ap.add_argument("--size", default="", help="WxH, default: the scene's SIZE")
    ap.add_argument("--line", type=float, default=1.0, help="outline width in pixels, 0 = none")
    ap.add_argument("--aa", action="store_true", help="anti-aliased toon render (default: hard pixels)")
    ap.add_argument("--allow-new-blender", action="store_true",
                    help="render toon on Blender 4.2+ (EEVEE Next) although it does not match the samples")
    try:
        a = ap.parse_args(argv)
    except SystemExit:
        raise RuntimeError("bad arguments: %s" % " ".join(argv))
    if a.mode == "toon" and bpy.app.version >= (4, 2, 0) and not a.allow_new_blender:
        raise RuntimeError("Blender %s uses EEVEE Next: cel bands get grainy and outlines thin out, so output will "
                           "not match the samples (made with 4.0.2). Use Blender 4.0.x/4.1.x, or pass "
                           "--allow-new-blender to experiment." % bpy.app.version_string)
    mod = SCENES[a.scene]
    if a.variant not in mod.VARIANTS:
        raise RuntimeError("variant must be one of %s" % ", ".join(mod.VARIANTS))
    w, h = (int(v) for v in a.size.split("x")) if a.size else mod.SIZE
    out = os.path.abspath(a.out)
    os.makedirs(os.path.dirname(out), exist_ok=True)
    L.reset()
    mod.build(a.variant, a.mode == "toon")
    check_sources()
    if a.mode == "toon":
        L.render_toon(out, w, h, mod.ramp(a.variant), a.line, a.aa)
    else:
        L.render_soft(out, w, h)
    print("RENDERED", out)


main()
