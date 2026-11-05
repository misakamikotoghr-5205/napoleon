# Shared helpers for the Blender -> pixel-art scenes (run inside Blender 4.x, `import bpy`).
# A scene module only places models, sets camera and lights; this file does model loading, material
# tweaks, the cel-shading conversion, outlines and rendering.
# Docs: docs/cards/art/blender/BLENDER_PIPELINE.md
import math
import os

import bpy
import mathutils

HERE = os.path.dirname(os.path.abspath(__file__))
MODELS_DIR = os.environ.get("KAYKIT_DIR", os.path.join(HERE, "models"))
# Folders that hold model packs (one sub-folder per pack): KAYKIT_DIR first, then MODEL_PATH
# (os.pathsep-separated, e.g. bought packs kept outside the repo).
MODEL_ROOTS = [MODELS_DIR] + [p for p in os.environ.get("MODEL_PATH", "").split(os.pathsep) if p]

# Pack folder names (see fetch_models.sh). Every pack used must be registered in
# docs/cards/art/blender/MODELS.csv; render.py refuses anything else.
FURNITURE = "KayKit-Furniture-Bits-1.0"
RESTAURANT = "KayKit-Restaurant-Bits-1.0"
CITY = "KayKit-City-Builder-Bits-1.0"

INK = (0.013, 0.008, 0.006)  # outline colour, linear (= #1f1712 in sRGB)

LOADED = []  # (pack, model file path) of every model loaded, checked by render.py
_index = {}


def pack_dir(pack):
    for root in MODEL_ROOTS:
        d = os.path.join(root, pack)
        if os.path.isdir(d):
            return d
    raise FileNotFoundError("model pack missing: %s (looked in %s; run tools/blender/fetch_models.sh)"
                            % (pack, os.pathsep.join(MODEL_ROOTS)))


def find(pack, name):
    """Path of model file `name` (e.g. "door_A.gltf", "abacus.fbx") inside a pack folder."""
    key = (pack, name)
    if key not in _index:
        root_dir = pack_dir(pack)
        hits = sorted(os.path.join(r, name) for r, _, files in os.walk(root_dir) if name in files)
        if not hits:
            raise FileNotFoundError("%s not found in %s" % (name, root_dir))
        _index[key] = hits[0]
    return _index[key]


def _import(path):
    ext = os.path.splitext(path)[1].lower()
    if ext in (".gltf", ".glb"):
        bpy.ops.import_scene.gltf(filepath=path)
    elif ext == ".fbx":
        bpy.ops.import_scene.fbx(filepath=path)
    elif ext == ".obj":
        bpy.ops.wm.obj_import(filepath=path)
    elif ext == ".blend":
        with bpy.data.libraries.load(path, link=False) as (src, dst):
            dst.objects = list(src.objects)
        for o in dst.objects:
            if o is not None:
                bpy.context.scene.collection.objects.link(o)
    else:
        raise ValueError("unsupported model format: %s" % path)


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def load(pack, name, loc=(0, 0, 0), rot_z=0.0, scale=1.0, hide=(), tag=""):
    """Import a model (glTF/GLB/FBX/OBJ/.blend) from a pack; place its root objects.

    Meshes whose name contains a `hide` string are hidden. Images the import brings in are tagged with the
    model file so render.py can tell pack textures from anything else.
    """
    path = find(pack, name)
    before, before_img = set(bpy.data.objects), set(bpy.data.images)
    _import(path)
    LOADED.append((pack, path))
    for im in bpy.data.images:
        if im not in before_img:
            im["source_model"] = path
    new = [o for o in bpy.data.objects if o not in before]
    roots = [o for o in new if o.parent is None or o.parent not in new]
    for o in new:
        if o.type == 'MESH' and (o.name.startswith("Icosphere") or any(h in o.name for h in hide)):
            o.hide_render = True
        o["tag"] = tag or name
    for r in roots:
        r.location = mathutils.Vector(loc)
        r.rotation_mode = 'XYZ'
        r.rotation_euler = (r.rotation_euler.x, r.rotation_euler.y, rot_z)
        r.scale = (scale, scale, scale)
    return new


def stretch(objs, sx, sy, sz):
    """Non-uniform scale of the root objects of an imported model."""
    for o in objs:
        if o.parent is None:
            o.scale = (sx, sy, sz)


def flat_mat(name, rgb, rough=1.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes.get("Principled BSDF")
    b.inputs["Base Color"].default_value = (*rgb, 1)
    b.inputs["Roughness"].default_value = rough
    if "Specular IOR Level" in b.inputs:
        b.inputs["Specular IOR Level"].default_value = 0.0
    return m


def set_mat(objs, names, mat):
    """Replace the material of meshes whose name contains any of `names`."""
    for o in objs:
        if o.type == 'MESH' and any(n in o.name for n in names):
            o.data.materials.clear()
            o.data.materials.append(mat)


def recolor(objs, rgb, names=None):
    """Give meshes one flat colour (all meshes, or those whose name contains any of `names`)."""
    m = flat_mat("rc_%d_%d_%d" % tuple(int(c * 255) for c in rgb), rgb)
    for o in objs:
        if o.type == 'MESH' and (names is None or any(n in o.name for n in names)):
            o.data.materials.clear()
            o.data.materials.append(m)


def tone(objs, sat=1.0, hue=0.5, val=1.0, names=None):
    """Hue/saturation/value tweak on the texture colour of these meshes (KayKit colours are loud)."""
    copies = {}
    for o in objs:
        if o.type != 'MESH' or (names and not any(n in o.name for n in names)):
            continue
        for idx, src in enumerate(o.data.materials):
            if src is None or not src.use_nodes:
                continue
            if src.name in copies:
                o.data.materials[idx] = copies[src.name]
                continue
            m = copies[src.name] = src.copy()
            o.data.materials[idx] = m
            nt = m.node_tree
            tex = [n for n in nt.nodes if n.type == 'TEX_IMAGE']
            bsdf = nt.nodes.get("Principled BSDF")
            if not tex or bsdf is None:
                continue
            hs = nt.nodes.new("ShaderNodeHueSaturation")
            hs.inputs["Hue"].default_value = hue
            hs.inputs["Saturation"].default_value = sat
            hs.inputs["Value"].default_value = val
            nt.links.new(tex[0].outputs["Color"], hs.inputs["Color"])
            nt.links.new(hs.outputs["Color"], bsdf.inputs["Base Color"])
            bsdf.inputs["Roughness"].default_value = 1.0
            if "Specular IOR Level" in bsdf.inputs:
                bsdf.inputs["Specular IOR Level"].default_value = 0.0


def plane(name, size, loc, rot, rgb):
    bpy.ops.mesh.primitive_plane_add(size=1, location=loc, rotation=rot)
    p = bpy.context.active_object
    p.name = name
    p.scale = (size[0], size[1], 1)
    p.data.materials.append(flat_mat(name + "_m", rgb))
    p["tag"] = name
    return p


def box(name, dims, loc, rgb, rot_z=0.0):
    """Plain box for the room shell only (floor, walls, ceiling, beams, posts, counter-top slab).

    Anything recognisable as an object (furniture, couplets, signs, locks...) must be a registered
    human-made model, not a scripted box: see BLENDER_PIPELINE.md, red line 1.
    """
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc, rotation=(0, 0, rot_z))
    b = bpy.context.active_object
    b.name = name
    b.scale = dims
    b.data.materials.append(flat_mat(name + "_m", rgb))
    b["tag"] = name
    return b


def emit_plane(name, size, loc, rot, rgb, strength):
    """Self-lit plane (sky behind a doorway). Cel shading leaves emissive materials alone."""
    p = plane(name, size, loc, rot, rgb)
    b = p.data.materials[0].node_tree.nodes.get("Principled BSDF")
    b.inputs["Emission Color"].default_value = (*rgb, 1)
    b.inputs["Emission Strength"].default_value = strength
    return p


def noline(objs):
    """Exclude these meshes from outlines (dense geometry such as book pages turns into solid ink)."""
    c = bpy.data.collections.get("noline") or bpy.data.collections.new("noline")
    if c.name not in bpy.context.scene.collection.children:
        bpy.context.scene.collection.children.link(c)
    for o in objs:
        if o.type == 'MESH' and o.name not in c.objects:
            c.objects.link(o)


def jars_on(x0, x1, y, z, seed, sat=0.35):
    """Fill a shelf from x0 to x1 with small jars and book bundles (deterministic from `seed`)."""
    kinds = ("jar_A_small", "jar_B_small", "jar_C_small", "jar_D_small", "jar_A_medium", "jar_C_medium", "book_set")
    x, i = x0, seed
    while x < x1:
        k = kinds[(i * 5 + 3) % len(kinds)]
        if k == "book_set":
            j = load(FURNITURE, k + ".gltf", (x + 0.12, y, z + 0.2), 0.0, 0.55, tag="jar")
            noline(j)
            x += 0.2
        else:
            j = load(RESTAURANT, k + ".gltf", (x, y, z), 0.0, 0.9, tag="jar")
        tone(j, sat=sat, val=0.9)
        x += 0.42 + ((i * 5) % 3) * 0.05
        i += 1


def camera(loc, look, lens):
    bpy.ops.object.camera_add(location=loc)
    c = bpy.context.active_object
    d = mathutils.Vector(look) - mathutils.Vector(loc)
    c.rotation_euler = d.to_track_quat('-Z', 'Y').to_euler()
    c.data.lens = lens
    bpy.context.scene.camera = c
    return c


def light(kind, loc, energy, rgb, rot=(0, 0, 0), size=1.0):
    """kind: 'SUN' (energy in W/m2), 'AREA' or 'POINT' (energy in W). A light points along its local -Z."""
    bpy.ops.object.light_add(type=kind, location=loc, rotation=rot)
    lt = bpy.context.active_object
    lt.data.energy = energy
    lt.data.color = rgb
    if kind == 'SUN':
        lt.data.angle = math.radians(3)
    elif kind == 'AREA':
        lt.data.size = size
    elif kind == 'POINT':
        lt.data.shadow_soft_size = size
    return lt


def world(rgb, strength):
    w = bpy.data.worlds.new("w")
    w.use_nodes = True
    bg = w.node_tree.nodes["Background"]
    bg.inputs["Color"].default_value = (*rgb, 1)
    bg.inputs["Strength"].default_value = strength
    bpy.context.scene.world = w


def toonify(steps):
    """Cel shading for every non-emissive material.

    Light intensity (white diffuse -> Shader to RGB -> brightness) goes through a constant colour ramp
    `steps` = ((position, value), ...), is multiplied by the material's base colour and by the light's
    hue, and is output as emission. EEVEE only (Shader to RGB does not exist in Cycles).
    """
    for m in bpy.data.materials:
        if not m.use_nodes:
            continue
        nt = m.node_tree
        bsdf = nt.nodes.get("Principled BSDF")
        out = next((n for n in nt.nodes if n.type == 'OUTPUT_MATERIAL'), None)
        if bsdf is None or out is None or bsdf.inputs["Emission Strength"].default_value > 0:
            continue
        col_in = bsdf.inputs["Base Color"]
        src = col_in.links[0].from_socket if col_in.links else None
        diff = nt.nodes.new("ShaderNodeBsdfDiffuse")
        s2r = nt.nodes.new("ShaderNodeShaderToRGB")
        bw = nt.nodes.new("ShaderNodeRGBToBW")
        ramp = nt.nodes.new("ShaderNodeValToRGB")
        ramp.color_ramp.interpolation = 'CONSTANT'
        els = ramp.color_ramp.elements
        els[0].position, els[0].color = 0.0, (steps[0][1],) * 3 + (1,)
        els[1].position, els[1].color = steps[1][0], (steps[1][1],) * 3 + (1,)
        for pos, val in steps[2:]:
            els.new(pos).color = (val,) * 3 + (1,)
        nt.links.new(diff.outputs["BSDF"], s2r.inputs["Shader"])
        nt.links.new(s2r.outputs["Color"], bw.inputs["Color"])
        nt.links.new(bw.outputs["Val"], ramp.inputs["Fac"])
        # base colour x banded brightness
        mul = nt.nodes.new("ShaderNodeMix")
        mul.data_type, mul.blend_type = 'RGBA', 'MULTIPLY'
        mul.inputs["Factor"].default_value = 1.0
        if src is not None:
            nt.links.new(src, mul.inputs[6])
        else:
            mul.inputs[6].default_value = col_in.default_value
        nt.links.new(ramp.outputs["Color"], mul.inputs[7])
        # x light hue (light colour divided by its brightness), clamped
        lum = nt.nodes.new("ShaderNodeMath")
        lum.operation = 'MAXIMUM'
        lum.inputs[1].default_value = 0.001
        nt.links.new(bw.outputs["Val"], lum.inputs[0])
        hue = nt.nodes.new("ShaderNodeVectorMath")
        hue.operation = 'DIVIDE'
        nt.links.new(s2r.outputs["Color"], hue.inputs[0])
        nt.links.new(lum.outputs["Value"], hue.inputs[1])
        tint = nt.nodes.new("ShaderNodeMix")
        tint.data_type, tint.blend_type = 'RGBA', 'MULTIPLY'
        tint.inputs["Factor"].default_value = 1.0
        tint.clamp_result = True
        nt.links.new(mul.outputs[2], tint.inputs[6])
        nt.links.new(hue.outputs["Vector"], tint.inputs[7])
        em = nt.nodes.new("ShaderNodeEmission")
        em.inputs["Strength"].default_value = 1.0
        nt.links.new(tint.outputs[2], em.inputs["Color"])
        nt.links.new(em.outputs["Emission"], out.inputs["Surface"])


def outlines(line_px):
    """Freestyle outlines: silhouettes and open borders only, ink colour, `line_px` pixels wide."""
    s = bpy.context.scene
    s.render.use_freestyle = True
    s.render.line_thickness_mode = 'ABSOLUTE'
    s.render.line_thickness = line_px
    vl = bpy.context.view_layer
    vl.use_freestyle = True
    fs = vl.freestyle_settings
    ls = fs.linesets[0] if fs.linesets else fs.linesets.new("ink")
    ls.select_by_visibility = True
    ls.select_silhouette = True
    ls.select_border = True
    ls.select_crease = False
    ls.select_contour = False
    nl = bpy.data.collections.get("noline")
    if nl is not None:
        ls.select_by_collection = True
        ls.collection = nl
        ls.collection_negation = 'EXCLUSIVE'
    if ls.linestyle is None:
        ls.linestyle = bpy.data.linestyles.new("ink")
    ls.linestyle.color = INK
    ls.linestyle.thickness = line_px


def _output(path, w, h):
    s = bpy.context.scene
    s.render.resolution_x, s.render.resolution_y = w, h
    s.render.resolution_percentage = 100
    s.render.image_settings.file_format = 'PNG'
    s.render.image_settings.color_mode = 'RGB'
    s.view_settings.view_transform = 'Standard'
    s.render.filepath = path


def render_toon(path, w, h, steps, line_px=1.0, aa=False):
    """Cel-shaded EEVEE render straight at the game's pixel size. aa=False gives hard pixel edges."""
    s = bpy.context.scene
    _output(path, w, h)
    try:
        s.render.engine = 'BLENDER_EEVEE_NEXT'  # Blender 4.2-4.x
    except TypeError:
        s.render.engine = 'BLENDER_EEVEE'  # 4.0/4.1 and 5.x
    s.eevee.taa_render_samples = 16 if aa else 1
    s.render.filter_size = 1.0 if aa else 0.01
    # Legacy EEVEE shadow settings (gone in EEVEE Next; the samples were made with them).
    for attr, val in (("use_soft_shadows", False), ("shadow_cube_size", '1024'), ("shadow_cascade_size", '2048')):
        if hasattr(s.eevee, attr):
            setattr(s.eevee, attr, val)
    toonify(steps)
    if line_px > 0:
        outlines(line_px)
    bpy.ops.render.render(write_still=True)


def render_soft(path, w, h, samples=256):
    """Plain Cycles render (CPU), for reference and lighting checks; not the deliverable."""
    s = bpy.context.scene
    _output(path, w, h)
    s.render.engine = 'CYCLES'
    s.cycles.device = 'CPU'
    s.cycles.samples = samples
    s.cycles.use_denoising = False
    s.cycles.sample_clamp_indirect = 1.5
    s.render.filter_size = 1.2
    bpy.ops.render.render(write_still=True)
