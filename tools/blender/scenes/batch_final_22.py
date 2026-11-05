# Final 22 eligible art slots for Dehoudang Blender pipeline
import math
import bl_lib as L

SIZE = (64, 48)
VARIANTS = (
    "bg.pharmacy",
    "bg.ricehall",
    "illus.bf.1939.gate_passage",
    "illus.ky.big_households",
    "illus.nw.price",
    "illus.ev.1938.police_open",
    "illus.ev.1938.puppet_roll",
    "illus.ev.1939.wu_price",
    "illus.ev.any.fair",
    "illus.fa.1938.rice_ease",
    "illus.fa.1939.gate_wink",
    "illus.fa.1940.rice_spike",
    "illus.st.odd_job",
    "illus.st.watch",
    "illus.gl.1939.cabinet_free",
    "illus.kp.leverage.xiaoding",
    "illus.lf.1940.school_rename",
    "illus.lf.any.coal_out",
    "illus.lf.any.school_fee",
    "prop.back_door",
    "prop.cat",
    "prop.storeroom_door",
)
IDS = {v: v for v in VARIANTS}
COLORS = (20, "maxcoverage")


def ramp(variant):
    if variant in ("illus.bf.1939.gate_passage", "illus.st.watch", "prop.back_door"):
        return ((0.0, 0.08), (0.10, 0.38), (0.35, 0.72), (0.80, 1.0))
    return ((0.0, 0.22), (0.10, 0.52), (0.35, 0.80), (0.82, 1.0))


def build(variant, toon):
    idx = VARIANTS.index(variant)
    angle = (idx * 0.37) % (math.pi * 2)
    L.plane("floor", (12, 12), (0, 2, 0), (0, 0, 0), (0.11 + (idx % 3) * 0.02, 0.07, 0.04))
    L.plane("backwall", (12, 6), (0, 3.2, 2.5), (math.radians(90), 0, 0), (0.06, 0.04 + (idx % 4) * 0.01, 0.025))

    if variant == "bg.pharmacy":
        for x in (-2.0, 0.0, 2.0):
            L.recolor(L.load(L.FURNITURE, "cabinet_medium_decorated.gltf", (x, 2.8, 0.0), 0.0, 1.15), (0.28, 0.14, 0.06))
            L.jars_on(x - 0.7, x + 0.7, 2.6, 1.45, seed=idx + int(x * 3))
        L.recolor(L.load(L.FURNITURE, "pictureframe_large_A.gltf", (0.0, 3.0, 2.35), 0.0, 1.1), (0.55, 0.38, 0.12))
        L.box("counter", (4.6, 0.7, 0.95), (0.0, 1.2, 0.48), (0.22, 0.11, 0.05))
        L.camera((0.0, -3.2, 1.65), (0.0, 2.5, 1.25), 32)
    elif variant == "bg.ricehall":
        for i, x in enumerate((-1.8, -0.6, 0.6, 1.8)):
            L.recolor(L.load(L.RESTAURANT, "crate_potatoes.gltf", (x, 1.8 + (i % 2) * 0.4, 0.0), 0.15 * i, 1.2), (0.48, 0.34, 0.16))
            L.recolor(L.load(L.RESTAURANT, "crate.gltf", (x, 2.5, 0.55), -0.1 * i, 1.1), (0.36, 0.22, 0.10))
        L.recolor(L.load(L.FURNITURE, "lamp_standing.gltf", (-2.4, 2.2, 0.0), 0.0, 1.1), (0.75, 0.16, 0.10))
        L.camera((0.2, -3.0, 1.75), (0.0, 2.2, 0.95), 34)
    elif variant in ("prop.back_door", "prop.storeroom_door"):
        door_m = "door_A.gltf" if variant == "prop.back_door" else "door_B.gltf"
        L.recolor(L.load(L.RESTAURANT, door_m, (0.0, 2.2, 0.0), 0.08 * idx, 1.35), (0.25, 0.15, 0.08))
        L.recolor(L.load(L.FURNITURE, "pictureframe_small_A.gltf", (0.45, 2.1, 1.65), 0.0, 0.9), (0.15, 0.25, 0.42))
        L.camera((0.15 * (idx % 3 - 1), -1.8, 1.2), (0.0, 2.2, 1.05), 38)
    elif variant == "prop.cat":
        L.recolor(L.load(L.FURNITURE, "pillow_A.gltf", (0.0, 1.8, 0.15), 0.3, 1.2), (0.45, 0.32, 0.18))
        L.recolor(L.load(L.RESTAURANT, "bowl_small.gltf", (0.55, 1.6, 0.0), 0.0, 1.1), (0.62, 0.48, 0.25))
        L.recolor(L.load(L.FURNITURE, "chair_stool_wood.gltf", (-0.45, 2.1, 0.0), 0.4, 0.95), (0.28, 0.16, 0.08))
        L.camera((0.0, -1.2, 0.95), (0.05, 1.8, 0.28), 42)
    elif "exterior" in variant or "gate" in variant or "fair" in variant or "school" in variant:
        b_models = ("building_A.gltf", "building_B.gltf", "building_C.gltf", "building_D.gltf", "building_E.gltf")
        bm = b_models[idx % len(b_models)]
        L.tone(L.load(L.CITY, bm, (-0.8 + (idx % 3) * 0.4, 2.6, 0.0), 0.12 * (idx % 5), 1.25), sat=0.55, val=0.85)
        L.recolor(L.load(L.CITY, "streetlight.gltf", (1.2 - (idx % 2) * 2.2, 1.6, 0.0), 0.0, 1.1), (0.22, 0.18, 0.14))
        L.recolor(L.load(L.CITY, "bench.gltf", (0.3, 1.4, 0.0), 0.2 * (idx % 4), 1.0), (0.34, 0.20, 0.10))
        if idx % 2 == 0:
            L.recolor(L.load(L.RESTAURANT, "crate.gltf", (-0.9, 1.3, 0.0), angle, 0.85), (0.40, 0.26, 0.12))
        L.camera((-0.6 + (idx % 5) * 0.3, -2.5, 1.35 + (idx % 3) * 0.2), (0.0, 2.4, 1.0), 33 + (idx % 4) * 2)
    else:
        c_models = ("cabinet_small_decorated.gltf", "cabinet_medium.gltf", "armchair.gltf", "chair_A_wood.gltf")
        cm = c_models[idx % len(c_models)]
        L.recolor(L.load(L.FURNITURE, cm, (-0.6 + (idx % 3) * 0.5, 2.3, 0.0), 0.18 * (idx % 6), 1.15), (0.32, 0.18, 0.09))
        L.recolor(L.load(L.RESTAURANT, "crate_buns.gltf", (0.7 - (idx % 2) * 1.3, 1.7, 0.0), angle, 0.95), (0.46, 0.32, 0.15))
        L.recolor(L.load(L.RESTAURANT, "bowl.gltf", (0.15 * (idx % 4), 1.4, 0.45), 0.0, 1.1), (0.58, 0.44, 0.22))
        L.box("table_slab", (1.8, 0.8, 0.44), (0.0, 1.45, 0.22), (0.24, 0.13, 0.06), rot_z=0.05 * (idx % 5))
        L.camera((-0.5 + (idx % 4) * 0.35, -2.2, 1.3 + (idx % 3) * 0.18), (0.0, 2.1, 0.75), 35 + (idx % 5))

    L.world((0.48, 0.42, 0.36), 0.32)
    L.light(
        'SUN',
        (1.5 - (idx % 4) * 0.8, -1.2, 4.8),
        2.2 + (idx % 3) * 0.3,
        (1.0, 0.85 - (idx % 3) * 0.05, 0.62),
        rot=(math.radians(42 + (idx % 5) * 4), 0, math.radians(-25 + idx * 7)),
    )
