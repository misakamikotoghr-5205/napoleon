# Storeroom card illustration (illus.es.storeroom, 64x48): two wall shelves of jars and book
# bundles over a dark plank wall, a locked chest in the middle.
# Pipeline demo only: arranged by Claude while looking at the current AI card, so it must not ship and is
# not a composition template (BLENDER_PIPELINE.md section 0).
import math

import bl_lib as L

SIZE = (64, 48)
VARIANTS = ("day",)
IDS = {"day": "illus.es.storeroom"}
COLORS = (20, "maxcoverage")


def ramp(variant):
    return ((0.0, 0.40), (0.12, 0.72), (0.45, 1.0))


def build(variant, toon):
    L.plane("floor", (10, 10), (0, 2, 0), (0, 0, 0), (0.09, 0.055, 0.03))
    L.plane("backwall", (10, 5), (0, 3.0, 2.5), (math.radians(90), 0, 0), (0.045, 0.026, 0.016))
    kinds = ("jar_A_large", "book_set", "jar_C_large", "jar_B_large", "book_set", "jar_D_large")
    i = 0
    for x in (-1.75, 1.75):
        for z in (0.55, 1.35, 2.15):
            L.recolor(L.load(L.FURNITURE, "shelf_A_big.gltf", (x, 3.0, z), 0.0, 1.2, tag="shelf"), (0.30, 0.17, 0.08))
            for dx in (-0.7, 0.0, 0.7):
                k = kinds[i % len(kinds)]
                i += 1
                if k == "book_set":
                    j = L.load(L.FURNITURE, k + ".gltf", (x + dx, 2.75, z + 0.3), math.pi / 2, 0.75, tag="book")
                    L.tone(j, sat=1.0, val=0.9)
                    L.noline(j)
                else:
                    L.tone(L.load(L.RESTAURANT, k + ".gltf", (x + dx, 2.75, z + 0.12), 0.0, 0.85, tag="jar"), sat=0.8, val=1.0)
    L.recolor(L.load(L.RESTAURANT, "crate.gltf", (0.0, 1.5, 0), 0.0, 0.5, tag="crate"), (0.35, 0.20, 0.09))
    L.recolor(L.load(L.RESTAURANT, "crate_lid.gltf", (0.0, 1.5, 0.4), 0.0, 0.5, tag="crate"), (0.42, 0.25, 0.11))
    # DEMO PLACEHOLDER: a scripted box standing in for a lock; not allowed in production scenes (red line 1).
    L.box("lock", (0.16, 0.03, 0.18), (0.0, 0.99, 0.3), (0.85, 0.62, 0.15))
    L.camera((0.0, -2.6, 1.4), (0.0, 3.0, 1.22), 33)
    if toon:
        L.world((0.55, 0.50, 0.45), 0.35)
        L.light('SUN', (0, 0, 5), 2.4, (1.0, 0.86, 0.62), rot=(math.radians(45), 0, math.radians(-30)))
    else:
        L.world((0.10, 0.08, 0.06), 0.4)
        L.light('AREA', (-3.5, 0.5, 3.2), 260, (1.0, 0.86, 0.62), rot=(math.radians(55), 0, math.radians(-60)), size=1.2)
