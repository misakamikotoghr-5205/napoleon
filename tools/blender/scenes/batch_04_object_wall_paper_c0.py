# Wall-paper props, batch 04 (I-205): the tear-off almanac (red header board, hung from an iron nail) on the
# shop's plank wall, and Hu Er's slip (a few brush strokes and a red thumbprint) nailed to a small wooden board.
# Seen almost straight from the front at eye level. The almanac is lit from the upper left; the notice board
# is lit from the upper right and seen a little from the side, so the two framings look different.
# One variant per art id.
# No registered pack (MODELS.csv: KayKit Furniture / Restaurant / City Builder) has either prop; both are on
# PROPS_NEEDED.md (撕页黄历, 红手印条子 "钉在板上的纸条"). Red line 1 forbids scripting props from boxes and
# planes, and a KayKit picture frame is neither an almanac nor a notice board. So every MODELS entry stays
# empty until a human-made model (with its unreadable print-block / red-thumbprint texture) is registered.
# Until then each variant renders only its wall and the beam above it (shell, allowed by red line 1).
# Composition is not from the creator's sketch yet (BLENDER_PIPELINE.md section 1.2/1.3).
# bl_lib has no place()/FURN/REST: models load with L.load(L.FURNITURE / L.RESTAURANT / L.CITY, ...).
# Register in scenes/__init__.py (import + SCENES entry) or render.py rejects --scene.
# SIZE is the almanac size and render.py only reads SIZE, so render prop.notice_wall with --size 18x26
# (SIZES[variant]), or teach render.py to use SIZES.
# NOT YET RENDERED: writing this file and running Blender were not permitted in the session that produced it.
import math

import bl_lib as L

SIZE = (24, 34)
VARIANTS = ('prop.calendar', 'prop.notice_wall',)
IDS = {'prop.calendar': 'prop.calendar', 'prop.notice_wall': 'prop.notice_wall'}
COLORS = (24, "mediancut") if SIZE[0] >= 160 else (20, "maxcoverage")

# variant: ((w, h) pixels, frame extent along the longer image side in units, prop centre height above the
# floor, wall colour). 1 unit ~ 0.75 m: almanac ~15x25 cm (0.33 units tall) plus nail and string; notice
# board ~30x40 cm (0.55 units) with one ~10x20 cm slip.
SPEC = {
    'prop.calendar': ((24, 34), 0.55, 2.1, (0.06, 0.035, 0.02)),      # dark plank wall behind the counter
    'prop.notice_wall': ((18, 26), 0.75, 2.0, (0.30, 0.27, 0.22)),    # grey-washed plaster by the door
}
SIZES = {v: s[0] for v, s in SPEC.items()}

# variant: [(pack constant, model file, (x, y, z), rot_z, scale, rgb or None), ...], placed on the wall
# face at y = 0. Fill in once a pack is registered, e.g. (L.ALMANAC_PACK, "almanac_tearoff.fbx",
# (0, -0.02, 2.1), 0.0, 1.0, None). Thin page stacks or string that render as solid ink also need L.noline(objs).
MODELS = {
    'prop.calendar': [],     # tear-off almanac: red wooden header board over a pad of pages, iron nail + string
    'prop.notice_wall': [],  # small plank board, one paper slip nailed on (unreadable strokes, red thumbprint)
}


def ramp(variant):
    if "night" in variant:
        return ((0, 0.07), (0.08, 0.48), (0.30, 0.78), (0.8, 1.0))
    if "dusk" in variant:
        return ((0, 0.14), (0.08, 0.44), (0.30, 0.74), (0.8, 1.0))
    return ((0, 0.20), (0.08, 0.48), (0.30, 0.78), (0.8, 1.0))


def build(variant, toon=True):
    (w, h), extent, height, wall_rgb = SPEC[variant]
    # Wall and the beam over it: room shell only, sized to the frame.
    L.plane("wall", (extent * 4, extent * 3), (0.0, 0.05, height), (math.radians(90), 0, 0), wall_rgb)
    L.box("beam", (extent * 4, 0.3, 0.12), (0.0, -0.1, height + extent * 0.7), (0.03, 0.018, 0.01))
    for pack, name, loc, rot_z, scale, rgb in MODELS[variant]:
        objs = L.load(pack, name, loc, rot_z, scale, tag=variant)
        if rgb is not None:
            L.recolor(objs, rgb)
    # Eye level with the prop's centre. Blender's sensor (36 mm) fits the longer image side (height for both
    # sizes), so the lens follows from the distance and the extent wanted along it.
    dist = extent * 2.5
    if variant == 'prop.calendar':
        L.camera((0.0, -dist, height), (0.0, 0.0, height), 36.0 * dist / extent)
        if toon:
            L.world((0.55, 0.50, 0.45), 0.3)
            # Points along (+x, +y, -z): from the upper left, in front of the wall.
            L.light('SUN', (0, 0, 6), 2.6, (1.0, 0.88, 0.68), rot=(math.radians(50), 0, math.radians(-40)))
        else:
            L.world((0.10, 0.08, 0.06), 0.4)
            r = extent * 1.8
            L.light('AREA', (-r, -r, height + r), 120 * extent, (1.0, 0.88, 0.68),
                    rot=(math.radians(50), 0, math.radians(-40)), size=extent)
    else:
        # A little from the right so the nail heads and the slip's lifted corner read as depth.
        side = dist * math.sin(math.radians(12))
        L.camera((side, -dist, height + 0.05), (0.0, 0.0, height), 36.0 * dist / extent)
        if toon:
            L.world((0.50, 0.50, 0.50), 0.3)
            # Points along (-x, +y, -z): from the upper right (door side), cooler daylight.
            L.light('SUN', (0, 0, 6), 2.4, (0.96, 0.92, 0.84), rot=(math.radians(55), 0, math.radians(35)))
        else:
            L.world((0.08, 0.08, 0.08), 0.4)
            r = extent * 1.8
            L.light('AREA', (r, -r, height + r), 120 * extent, (0.96, 0.92, 0.84),
                    rot=(math.radians(55), 0, math.radians(35)), size=extent)
