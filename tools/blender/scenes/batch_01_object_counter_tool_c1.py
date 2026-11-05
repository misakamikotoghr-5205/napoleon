# Counter-tool props, batch 01, open-lid telegraph (I-287): the same telegraph as prop.telegraph in
# batch_01_object_counter_tool_c0, lid opened to show the brass key, on the counter top, seen from the front
# and a little above, light from the upper left.
# NOT RENDER-READY: no registered pack (MODELS.csv: KayKit Furniture / Restaurant / City Builder) has a
# telegraph or a key. Both are on PROPS_NEEDED.md (电报机和铜电键), and red line 1 forbids building props from
# scripted boxes, so MODELS stays empty until someone registers a human-made model. Until then this renders only
# the counter top and back wall, which is the same as prop.telegraph. The composition is not from the creator's
# sketch yet (BLENDER_PIPELINE.md section 1.2/1.3).
# Pixel alignment with prop.telegraph: c0's own build('prop.telegraph') makes the counter-top slab, back wall,
# camera and lights, so both renders share them exactly. This module only adds the open-lid models.
# bl_lib has no place()/FURN/REST: load models with L.load(L.FURNITURE / L.RESTAURANT / L.CITY, ...).
# Register this module in scenes/__init__.py (import + SCENES entry), or render.py rejects --scene.
import bl_lib as L

from . import batch_01_object_counter_tool_c0 as C0

SIZE = (38, 28)
VARIANTS = ('prop.telegraph_open',)
IDS = {'prop.telegraph_open': 'prop.telegraph_open'}
COLORS = (24, "mediancut") if SIZE[0] >= 160 else (20, "maxcoverage")

# Must stay equal to c0's prop.telegraph size, or the two renders stop lining up.
assert C0.SPEC['prop.telegraph'][0] == SIZE

# variant: [(pack constant, model file, (x, y, z), rot_z, scale, rgb or None), ...]
# Fill in with the same case model as c0's MODELS['prop.telegraph'] (same loc/rot/scale), opened, plus the key,
# e.g. (L.TELEGRAPH_PACK, "telegraph_open.fbx", (0, 0, 0), 0.0, 1.0, (0.20, 0.11, 0.05)).
MODELS = {
    'prop.telegraph_open': [],  # telegraph case with the lid up + brass key on its base
}


def ramp(variant):
    return C0.ramp(variant)


def build(variant, toon=True):
    # c0 also loads MODELS['prop.telegraph'] (the closed case). Once that has models, the open-lid case must
    # replace it, not sit on top of it.
    assert not C0.MODELS['prop.telegraph'], "split c0's closed case out before adding the open-lid model"
    C0.build('prop.telegraph', toon)
    for pack, name, loc, rot_z, scale, rgb in MODELS[variant]:
        objs = L.load(pack, name, loc, rot_z, scale, tag=variant)
        if rgb is not None:
            L.recolor(objs, rgb)
