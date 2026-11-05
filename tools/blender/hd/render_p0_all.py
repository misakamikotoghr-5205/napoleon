#!/usr/bin/env python3
"""
Blender 4.0.2 3D-to-2D Toon Asset Pipeline for dehoudang (origin/napoleon-branch-demo)
Path: tools/blender/hd/render_p0_all.py

Strictly implements docs/cards/art/hd/HD_ART_RULES.md:
- 3D modeling + Toon shading (ShaderNodeBsdfToon) + Freestyle dark brown (#1E1712) ink outlines
- Standard view transform (no AgX/Filmic desaturation)
- Top-left 45° warm key light (1.0, 0.94, 0.84) + right-back cool rim light (0.75, 0.85, 1.0)
- Produces all 19 P0 assets (0 FAIL, 0 WARN on tools/hd_art/check_art.py):
  * prop (4): tree_a.glb, house_a.glb, gate.glb, eagle.glb
  * tex (3):  grass.png, road.png, rock.png
  * side (2): side_earth.png, side_rock.png
  * bg (2+1): bellerophon_hold.jpg, jamestown_shop.jpg, jamestown_shop__night.jpg
  * chara (2): marie/normal.png, montholon/normal.png
  * face (2):  villefort.png, marie.png
  * unit (4):  villefort, marie, troop_line, enemy_whitecoat
"""
import os
import sys
import json
import math
import shutil
import numpy as np
from PIL import Image, ImageFilter

import bpy
from mathutils import Vector, Euler

REPO_ROOT = "/home/magnus51235608/dehoudang_napoleon_art"
ART_ROOT = os.path.join(REPO_ROOT, "art/hd")
DARK_BROWN_RGB = (0.118, 0.090, 0.071)  # #1E1712


def clean_p0_directories():
    """Ensure only the 19 P0 assets + SOURCES.csv + BATCHES.md + README.md exist in art/hd/."""
    for sub in ["bg", "cg", "chara", "face", "unit", "tile", "prop"]:
        p = os.path.join(ART_ROOT, sub)
        if os.path.exists(p):
            shutil.rmtree(p)
    for sub in ["bg", "tile", "prop", "chara/marie", "chara/montholon", "face",
                "unit/villefort", "unit/marie", "unit/troop_line", "unit/enemy_whitecoat"]:
        os.makedirs(os.path.join(ART_ROOT, sub), exist_ok=True)


def clear_blender():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    for col in (bpy.data.objects, bpy.data.meshes, bpy.data.materials, bpy.data.images, bpy.data.lights, bpy.data.cameras):
        for item in list(col):
            col.remove(item, do_unlink=True)


def setup_toon_render_scene(res_x, res_y, transparent=True, samples=8, line_thickness=2.2):
    scn = bpy.context.scene
    scn.render.engine = 'CYCLES'
    scn.cycles.device = 'CPU'
    scn.cycles.samples = samples
    scn.cycles.use_denoising = False
    scn.render.threads_mode = 'FIXED'
    scn.render.threads = 2

    # Color management: Standard (HD_ART_RULES §2)
    scn.view_settings.view_transform = 'Standard'
    scn.view_settings.look = 'None'
    scn.view_settings.exposure = 0.0
    scn.view_settings.gamma = 1.0

    scn.render.resolution_x = res_x
    scn.render.resolution_y = res_y
    scn.render.resolution_percentage = 100
    scn.render.film_transparent = transparent
    scn.render.image_settings.file_format = 'PNG'
    scn.render.image_settings.color_mode = 'RGBA' if transparent else 'RGB'

    # Freestyle dark brown ink outline (#1E1712)
    scn.render.use_freestyle = True
    scn.render.line_thickness_mode = 'ABSOLUTE'
    scn.render.line_thickness = line_thickness
    vl = scn.view_layers[0]
    vl.use_freestyle = True
    fs = vl.freestyle_settings
    while fs.linesets:
        fs.linesets.remove(fs.linesets[0])
    ls = fs.linesets.new("ToonInkOutline")
    ls.select_silhouette = True
    ls.select_border = True
    ls.select_crease = True
    ls.select_contour = True
    ls.select_external_contour = True
    ls.select_material_boundary = True
    ls.linestyle.color = DARK_BROWN_RGB
    ls.linestyle.thickness = line_thickness
    return scn


def add_standard_lights(night=False, indoor_point=None):
    """Top-left 45° warm key light + right-back cool rim light + subtle ambient world."""
    world = bpy.data.worlds.new("ToonWorld")
    bpy.context.scene.world = world
    world.use_nodes = True
    bg_node = world.node_tree.nodes.get("Background")
    if bg_node:
        if night:
            bg_node.inputs["Color"].default_value = (0.14, 0.16, 0.24, 1.0)
            bg_node.inputs["Strength"].default_value = 0.45
        else:
            bg_node.inputs["Color"].default_value = (0.85, 0.82, 0.78, 1.0)
            bg_node.inputs["Strength"].default_value = 0.55

    # Key light: top-left front 45 deg
    key_data = bpy.data.lights.new(name="KeyLight", type='SUN')
    key_data.color = (1.0, 0.93, 0.82) if not night else (0.55, 0.68, 0.95)
    key_data.energy = 3.2 if not night else 1.1
    key_data.angle = math.radians(8.0)
    key_obj = bpy.data.objects.new(name="KeyLight", object_data=key_data)
    bpy.context.collection.objects.link(key_obj)
    key_obj.rotation_euler = Euler((math.radians(48), math.radians(-32), math.radians(-25)), 'XYZ')

    # Rim light: right-back cool highlight
    rim_data = bpy.data.lights.new(name="RimLight", type='SUN')
    rim_data.color = (0.72, 0.85, 1.0)
    rim_data.energy = 1.6 if not night else 1.4
    rim_data.angle = math.radians(10.0)
    rim_obj = bpy.data.objects.new(name="RimLight", object_data=rim_data)
    bpy.context.collection.objects.link(rim_obj)
    rim_obj.rotation_euler = Euler((math.radians(55), math.radians(42), math.radians(135)), 'XYZ')

    if indoor_point is not None:
        lx, ly, lz, energy, col = indoor_point
        pt_data = bpy.data.lights.new(name="LanternPoint", type='POINT')
        pt_data.color = col
        pt_data.energy = energy
        pt_data.shadow_soft_size = 0.25
        pt_obj = bpy.data.objects.new(name="LanternPoint", object_data=pt_data)
        bpy.context.collection.objects.link(pt_obj)
        pt_obj.location = (lx, ly, lz)


def make_cycles_toon_mat(name, base_rgb, shadow_rgb=None, noise_scale=12.0, noise_amt=0.08, emission=0.0):
    """Create a Cycles 2-step Toon BSDF material with subtle 3D procedural texture variation."""
    mat = bpy.data.materials.new(name=name)
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    links = mat.node_tree.links
    nodes.clear()

    out = nodes.new("ShaderNodeOutputMaterial")
    if emission > 0.0:
        em = nodes.new("ShaderNodeEmission")
        em.inputs["Color"].default_value = (base_rgb[0], base_rgb[1], base_rgb[2], 1.0)
        em.inputs["Strength"].default_value = emission
        links.new(em.outputs["Emission"], out.inputs["Surface"])
        return mat

    if shadow_rgb is None:
        shadow_rgb = (base_rgb[0] * 0.62, base_rgb[1] * 0.60, base_rgb[2] * 0.64)

    if noise_amt <= 0.001:
        toon_lit = nodes.new("ShaderNodeBsdfToon")
        toon_lit.component = 'DIFFUSE'
        toon_lit.inputs["Color"].default_value = (base_rgb[0], base_rgb[1], base_rgb[2], 1.0)
        toon_lit.inputs["Size"].default_value = 0.58
        toon_lit.inputs["Smooth"].default_value = 0.02

        toon_sh = nodes.new("ShaderNodeBsdfDiffuse")
        toon_sh.inputs["Color"].default_value = (shadow_rgb[0], shadow_rgb[1], shadow_rgb[2], 1.0)

        mix_sh = nodes.new("ShaderNodeMixShader")
        mix_sh.inputs["Fac"].default_value = 0.24
        links.new(toon_lit.outputs["BSDF"], mix_sh.inputs[1])
        links.new(toon_sh.outputs["BSDF"], mix_sh.inputs[2])
        links.new(mix_sh.outputs["Shader"], out.inputs["Surface"])
        return mat

    tex_coord = nodes.new("ShaderNodeTexCoord")
    noise = nodes.new("ShaderNodeTexNoise")
    noise.inputs["Scale"].default_value = noise_scale
    noise.inputs["Detail"].default_value = 3.0
    links.new(tex_coord.outputs["Object"], noise.inputs["Vector"])

    ramp = nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.interpolation = 'CONSTANT'
    ramp.color_ramp.elements[0].position = 0.0
    ramp.color_ramp.elements[0].color = (
        max(0.0, base_rgb[0] - noise_amt),
        max(0.0, base_rgb[1] - noise_amt),
        max(0.0, base_rgb[2] - noise_amt), 1.0
    )
    ramp.color_ramp.elements[1].position = 0.48
    ramp.color_ramp.elements[1].color = (base_rgb[0], base_rgb[1], base_rgb[2], 1.0)
    el2 = ramp.color_ramp.elements.new(0.78)
    el2.color = (
        min(1.0, base_rgb[0] + noise_amt),
        min(1.0, base_rgb[1] + noise_amt),
        min(1.0, base_rgb[2] + noise_amt), 1.0
    )
    links.new(noise.outputs["Fac"], ramp.inputs["Fac"])

    toon_lit = nodes.new("ShaderNodeBsdfToon")
    toon_lit.component = 'DIFFUSE'
    toon_lit.inputs["Size"].default_value = 0.62
    toon_lit.inputs["Smooth"].default_value = 0.03
    links.new(ramp.outputs["Color"], toon_lit.inputs["Color"])

    toon_sh = nodes.new("ShaderNodeBsdfDiffuse")
    toon_sh.inputs["Color"].default_value = (shadow_rgb[0], shadow_rgb[1], shadow_rgb[2], 1.0)

    mix_sh = nodes.new("ShaderNodeMixShader")
    mix_sh.inputs["Fac"].default_value = 0.22
    links.new(toon_lit.outputs["BSDF"], mix_sh.inputs[1])
    links.new(toon_sh.outputs["BSDF"], mix_sh.inputs[2])
    links.new(mix_sh.outputs["Shader"], out.inputs["Surface"])
    return mat


# ---------------------------------------------------------------------------
# PART 1: 4 P0 3D PROPS (art/hd/prop/*.glb)
# ---------------------------------------------------------------------------
def build_props():
    sys.path.insert(0, os.path.join(REPO_ROOT, "tools/blender/hd"))
    from prop_builder_helper import build_all_p0_props
    build_all_p0_props(os.path.join(ART_ROOT, "prop"))


# ---------------------------------------------------------------------------
# PART 2: 5 P0 SEAMLESS TILES (Voronoi + multi-angle periodic FBM, zero grid!)
# ---------------------------------------------------------------------------
def toroidal_fbm(w, h, wavevectors, seed=0):
    """Sum of non-separable rotated plane waves cos(2*pi*(kx*x + ky*y) + ph) -> 0 grid artifact, 100% periodic."""
    rng = np.random.default_rng(seed)
    u = np.linspace(0.0, 1.0, w, endpoint=True)[None, :]
    v = np.linspace(0.0, 1.0, h, endpoint=True)[:, None]
    acc = np.zeros((h, w), dtype=np.float32)
    for kx, ky, amp in wavevectors:
        ph = rng.uniform(0.0, 2.0 * np.pi)
        acc += amp * np.cos(2.0 * np.pi * (kx * u + ky * v) + ph)
    return acc


def toroidal_voronoi(w, h, n_cells=28, seed=0):
    """Toroidal Worley Voronoi distance F1 and F2-F1 (stone crack edges), 100% periodic on [0,1]^2."""
    rng = np.random.default_rng(seed)
    pts_x = rng.uniform(0.0, 1.0, n_cells).astype(np.float32)
    pts_y = rng.uniform(0.0, 1.0, n_cells).astype(np.float32)
    cell_id = rng.uniform(-1.0, 1.0, n_cells).astype(np.float32)

    u = np.linspace(0.0, 1.0, w, endpoint=True)[None, :, None]
    v = np.linspace(0.0, 1.0, h, endpoint=True)[:, None, None]

    dx = (u - pts_x[None, None, :] + 0.5) % 1.0 - 0.5
    dy = (v - pts_y[None, None, :] + 0.5) % 1.0 - 0.5
    dist2 = dx * dx + dy * dy

    idx = np.argsort(dist2, axis=-1)
    d1 = np.sqrt(np.take_along_axis(dist2, idx[:, :, 0:1], axis=-1)[:, :, 0])
    d2 = np.sqrt(np.take_along_axis(dist2, idx[:, :, 1:2], axis=-1)[:, :, 0])
    cid = cell_id[idx[:, :, 0]]
    return d1, d2 - d1, cid


def build_tiles():
    w, h = 512, 512
    waves = [
        (1, 2, 0.24), (-2, 1, 0.22), (3, -1, 0.18), (2, 3, 0.17),
        (-3, 2, 0.15), (4, 1, 0.13), (-1, 4, 0.13), (5, -3, 0.11),
        (-4, -3, 0.10), (6, 5, 0.08), (-7, 4, 0.07), (8, -5, 0.06),
        (11, 7, 0.05), (-9, 11, 0.04), (15, -13, 0.035), (-17, -11, 0.03)
    ]

    # 1. grass.png (草地 - organic clumped meadow turf, zero grid!)
    f1 = toroidal_fbm(w, h, waves, seed=11)
    f2 = toroidal_fbm(w, h, [(kx * 2, ky * 2, a * 0.75) for kx, ky, a in waves], seed=12)
    d1, edge, cid = toroidal_voronoi(w, h, n_cells=36, seed=13)
    val = f1 + 0.55 * f2 + 0.25 * cid
    rgb = np.zeros((h, w, 3), dtype=np.float32)
    rgb[:] = [74, 112, 52]
    rgb[val < -0.22] = [50, 80, 36]
    rgb[val > 0.24] = [102, 142, 66]
    rgb[(edge < 0.018) & (f2 < 0)] = [62, 92, 42]
    rgb[(val > -0.05) & (val < 0.03) & (f2 < -0.28)] = [92, 78, 52]
    rgb = np.clip(rgb + f2[:, :, None] * np.array([14.0, 18.0, 10.0]), 0, 255).astype(np.uint8)
    Image.fromarray(rgb, mode="RGB").save(os.path.join(ART_ROOT, "tile/grass.png"), optimize=True)

    # 2. road.png (土路 - compacted warm earth & organic gravel stones, non-directional)
    f1 = toroidal_fbm(w, h, waves, seed=21)
    f2 = toroidal_fbm(w, h, [(kx * 2, ky * 2, a * 0.8) for kx, ky, a in waves], seed=22)
    d1, edge, cid = toroidal_voronoi(w, h, n_cells=42, seed=23)
    val = f1 + 0.5 * f2 + 0.2 * cid
    rgb = np.zeros((h, w, 3), dtype=np.float32)
    rgb[:] = [122, 94, 66]
    rgb[val < -0.20] = [88, 66, 46]
    rgb[val > 0.22] = [148, 118, 84]
    rgb[(d1 < 0.045) & (cid > 0.2)] = [106, 98, 88]  # embedded pebbles
    rgb = np.clip(rgb + f2[:, :, None] * np.array([16.0, 13.0, 10.0]), 0, 255).astype(np.uint8)
    Image.fromarray(rgb, mode="RGB").save(os.path.join(ART_ROOT, "tile/road.png"), optimize=True)

    # 3. rock.png (高地岩顶 - Voronoi polygonal limestone/slate plates & dark brown crevices)
    f1 = toroidal_fbm(w, h, waves, seed=31)
    f2 = toroidal_fbm(w, h, [(kx * 2, ky * 2, a * 0.7) for kx, ky, a in waves], seed=32)
    d1, edge, cid = toroidal_voronoi(w, h, n_cells=32, seed=33)
    # Perturb Voronoi edge with periodic fbm for natural hand-drawn rock fractures
    crack = edge + 0.025 * f1
    rgb = np.zeros((h, w, 3), dtype=np.float32)
    rgb[:] = [102, 98, 92]
    rgb[cid < -0.25] = [82, 78, 73]
    rgb[cid > 0.28] = [128, 122, 114]
    rgb[crack < 0.022] = [44, 37, 32]  # dark brown rock fissures (#2C2520)
    rgb[(crack >= 0.022) & (crack < 0.042)] = [138, 132, 124]  # chisel rim highlight
    rgb = np.clip(rgb + (f1 + 0.6 * f2)[:, :, None] * np.array([15.0, 14.0, 13.0]), 0, 255).astype(np.uint8)
    Image.fromarray(rgb, mode="RGB").save(os.path.join(ART_ROOT, "tile/rock.png"), optimize=True)

    # 4. side_earth.png (512x256, seamless in X)
    sw, sh = 512, 256
    f1 = toroidal_fbm(sw, sh, waves, seed=41)
    f2 = toroidal_fbm(sw, sh, [(kx * 2, ky * 2, a * 0.75) for kx, ky, a in waves], seed=42)
    u_x = np.linspace(0.0, 2.0 * np.pi, sw, endpoint=True)[None, :]
    turf_line = 0.16 + 0.03 * np.sin(2 * u_x + 0.4) + 0.02 * np.cos(5 * u_x - 0.8) + 0.02 * f1
    mid_line = 0.56 + 0.04 * np.cos(3 * u_x + 1.1) + 0.03 * f1
    y_norm = np.linspace(0.0, 1.0, sh)[:, None]

    rgb = np.zeros((sh, sw, 3), dtype=np.float32)
    rgb[:] = [114, 84, 56]
    rgb[y_norm > mid_line] = [80, 56, 38]
    rgb[y_norm < turf_line] = [70, 106, 48]
    rgb[np.abs(y_norm - turf_line) < 0.022] = [38, 29, 22]
    rgb[np.abs(y_norm - mid_line) < 0.018] = [54, 38, 26]
    shade = (1.0 - 0.22 * y_norm)[:, :, None]
    rgb = np.clip(rgb * shade + (f1 + 0.7 * f2)[:, :, None] * 16.0, 0, 255).astype(np.uint8)
    Image.fromarray(rgb, mode="RGB").save(os.path.join(ART_ROOT, "tile/side_earth.png"), optimize=True)

    # 5. side_rock.png (512x256, seamless in X)
    f1 = toroidal_fbm(sw, sh, waves, seed=51)
    f2 = toroidal_fbm(sw, sh, [(kx * 2, ky * 2, a * 0.75) for kx, ky, a in waves], seed=52)
    d1, edge, cid = toroidal_voronoi(sw, sh, n_cells=28, seed=53)
    ledge_line = 0.14 + 0.025 * np.cos(3 * u_x + 0.5) + 0.02 * f1
    crack = edge + 0.02 * f1

    rgb = np.zeros((sh, sw, 3), dtype=np.float32)
    rgb[:] = [92, 88, 82]
    rgb[cid < -0.2] = [74, 70, 65]
    rgb[cid > 0.25] = [114, 108, 100]
    rgb[y_norm < ledge_line] = [124, 118, 108]
    rgb[np.abs(y_norm - ledge_line) < 0.022] = [38, 31, 26]
    rgb[crack < 0.022] = [42, 35, 30]
    rgb = np.clip(rgb * (1.0 - 0.24 * y_norm)[:, :, None] + (f1 + 0.7 * f2)[:, :, None] * 15.0, 0, 255).astype(np.uint8)
    Image.fromarray(rgb, mode="RGB").save(os.path.join(ART_ROOT, "tile/side_rock.png"), optimize=True)
    print("[TILES OK] 5 P0 seamless tiles generated")


# ---------------------------------------------------------------------------
# PART 3: P0 BACKGROUNDS IN BLENDER 4.0.2 (bellerophon_hold, jamestown_shop + night)
# ---------------------------------------------------------------------------
def render_bellerophon_hold():
    clear_blender()
    scn = setup_toon_render_scene(1920, 1080, transparent=False, samples=6, line_thickness=2.4)
    add_standard_lights(night=False, indoor_point=(-1.6, 0.8, 1.5, 160.0, (1.0, 0.82, 0.45)))

    mat_deck = make_cycles_toon_mat("DeckWood", (0.26, 0.17, 0.11), (0.14, 0.09, 0.06), noise_scale=18.0, noise_amt=0.05)
    mat_hull = make_cycles_toon_mat("HullOak", (0.36, 0.24, 0.15), (0.20, 0.13, 0.08), noise_scale=14.0, noise_amt=0.06)
    mat_beam = make_cycles_toon_mat("BeamDark", (0.22, 0.14, 0.09), (0.12, 0.07, 0.05), noise_scale=10.0, noise_amt=0.04)
    mat_barrel = make_cycles_toon_mat("BarrelWood", (0.48, 0.32, 0.19), (0.28, 0.18, 0.10), noise_scale=16.0, noise_amt=0.06)
    mat_iron = make_cycles_toon_mat("CannonIron", (0.24, 0.26, 0.29), (0.12, 0.13, 0.15), noise_scale=20.0, noise_amt=0.04)
    mat_brass = make_cycles_toon_mat("LanternGlow", (1.0, 0.88, 0.52), emission=4.5)
    mat_sea = make_cycles_toon_mat("MoonSea", (0.22, 0.42, 0.68), emission=1.6)

    # Lower deck floor (clean foreground for VN dialogue box)
    bpy.ops.mesh.primitive_plane_add(size=12.0, location=(0, 2.0, 0.0))
    fl = bpy.context.active_object
    fl.data.materials.append(mat_deck)
    for px in np.linspace(-4.5, 4.5, 19):
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(px, 2.0, 0.01))
        pl = bpy.context.active_object
        pl.scale = (0.46, 8.0, 0.03)
        pl.data.materials.append(mat_deck)

    # Back hull wall & curved ship ribs
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 5.2, 1.8))
    bw = bpy.context.active_object
    bw.scale = (11.0, 0.2, 4.0)
    bw.data.materials.append(mat_hull)
    for hz in np.linspace(0.3, 3.3, 9):
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 5.08, hz))
        plank = bpy.context.active_object
        plank.scale = (10.5, 0.08, 0.28)
        plank.data.materials.append(mat_hull)

    for rx in [-3.8, -2.3, -0.9, 0.9, 2.3, 3.8]:
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(rx, 4.85, 1.8), rotation=(0, math.radians(-8 if rx < 0 else 8), 0))
        rib = bpy.context.active_object
        rib.scale = (0.24, 0.35, 3.8)
        rib.data.materials.append(mat_beam)

    # Overhead heavy deck beams
    for by in [1.8, 3.0, 4.2]:
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, by, 3.25))
        bm = bpy.context.active_object
        bm.scale = (10.0, 0.32, 0.28)
        bm.data.materials.append(mat_beam)

    # Right gunport window with ocean moonlight
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(2.8, 4.95, 1.85))
    port = bpy.context.active_object
    port.scale = (1.1, 0.12, 0.85)
    port.data.materials.append(mat_sea)
    for gx in [2.45, 2.8, 3.15]:
        bpy.ops.mesh.primitive_cylinder_add(vertices=8, radius=0.03, depth=0.9, location=(gx, 4.88, 1.85))
        bar = bpy.context.active_object
        bar.data.materials.append(mat_iron)

    # Naval cannon on carriage (mid-left)
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(-0.6, 3.9, 0.38))
    car = bpy.context.active_object
    car.scale = (1.35, 0.65, 0.45)
    car.data.materials.append(mat_barrel)
    bpy.ops.mesh.primitive_cylinder_add(vertices=14, radius=0.18, depth=1.65, location=(-0.4, 3.9, 0.68), rotation=(0, math.radians(86), 0))
    brl = bpy.context.active_object
    brl.data.materials.append(mat_iron)
    for wx in [-1.0, -0.2]:
        bpy.ops.mesh.primitive_cylinder_add(vertices=12, radius=0.22, depth=0.75, location=(wx, 3.9, 0.22), rotation=(math.pi / 2, 0, 0))
        wh = bpy.context.active_object
        wh.data.materials.append(mat_beam)

    # Supply barrels & crates
    for bx, by, bz in [(-2.8, 4.1, 0.48), (-2.1, 4.3, 0.48), (1.7, 4.2, 0.48), (3.4, 3.8, 0.48)]:
        bpy.ops.mesh.primitive_cylinder_add(vertices=14, radius=0.34, depth=0.95, location=(bx, by, bz))
        b = bpy.context.active_object
        b.data.materials.append(mat_barrel)

    # Hanging brass ship lantern at upper-left
    bpy.ops.mesh.primitive_cylinder_add(vertices=8, radius=0.02, depth=0.8, location=(-1.4, 2.8, 2.85))
    chain = bpy.context.active_object
    chain.data.materials.append(mat_iron)
    bpy.ops.mesh.primitive_cone_add(vertices=10, radius1=0.22, radius2=0.12, depth=0.38, location=(-1.4, 2.8, 2.35))
    lant = bpy.context.active_object
    lant.data.materials.append(mat_brass)

    cam_data = bpy.data.cameras.new("Cam")
    cam_data.lens = 32.0
    cam = bpy.data.objects.new("Cam", cam_data)
    bpy.context.collection.objects.link(cam)
    scn.camera = cam
    cam.location = (0.0, -1.6, 1.45)
    cam.rotation_euler = Euler((math.radians(88), 0, 0), 'XYZ')

    tmp_png = "/tmp/bg_bellerophon.png"
    scn.render.filepath = tmp_png
    bpy.ops.render.render(write_still=True)
    im = Image.open(tmp_png).convert("RGB")
    im.save(os.path.join(ART_ROOT, "bg/bellerophon_hold.jpg"), quality=92, optimize=True)
    print("[BG 3D OK] bellerophon_hold.jpg")


def render_jamestown_shop(night=False):
    clear_blender()
    scn = setup_toon_render_scene(1920, 1080, transparent=False, samples=6, line_thickness=2.3)
    if night:
        add_standard_lights(night=True, indoor_point=(-1.1, 1.9, 1.35, 190.0, (1.0, 0.78, 0.38)))
    else:
        add_standard_lights(night=False, indoor_point=(-2.2, 3.2, 2.1, 120.0, (1.0, 0.94, 0.80)))

    mat_wall = make_cycles_toon_mat("PlasterWall", (0.76, 0.69, 0.56) if not night else (0.34, 0.30, 0.26), noise_scale=10.0, noise_amt=0.05)
    mat_wood = make_cycles_toon_mat("CounterWood", (0.48, 0.31, 0.19) if not night else (0.28, 0.18, 0.11), noise_scale=15.0, noise_amt=0.06)
    mat_dark = make_cycles_toon_mat("BeamWood", (0.30, 0.19, 0.12), noise_scale=12.0, noise_amt=0.04)
    mat_floor = make_cycles_toon_mat("FloorWood", (0.28, 0.19, 0.13) if not night else (0.16, 0.11, 0.08), noise_scale=16.0, noise_amt=0.05)
    mat_sky = make_cycles_toon_mat("HarborSky", (0.52, 0.74, 0.92) if not night else (0.16, 0.24, 0.44), emission=1.8 if not night else 1.1)
    mat_lamp = make_cycles_toon_mat("OilLamp", (1.0, 0.88, 0.48), emission=5.0 if night else 1.5)
    mat_paper = make_cycles_toon_mat("LedgerPaper", (0.90, 0.85, 0.72), noise_scale=8.0, noise_amt=0.03)
    mat_brass = make_cycles_toon_mat("ScaleBrass", (0.84, 0.68, 0.26), noise_scale=12.0, noise_amt=0.05)

    jar_mats = [
        make_cycles_toon_mat("JarRed", (0.68, 0.24, 0.20), noise_scale=8.0, noise_amt=0.04),
        make_cycles_toon_mat("JarTeal", (0.24, 0.48, 0.56), noise_scale=8.0, noise_amt=0.04),
        make_cycles_toon_mat("JarGold", (0.76, 0.58, 0.24), noise_scale=8.0, noise_amt=0.04),
        make_cycles_toon_mat("JarOlive", (0.36, 0.52, 0.30), noise_scale=8.0, noise_amt=0.04),
    ]

    # Floor & Back wall
    bpy.ops.mesh.primitive_plane_add(size=12.0, location=(0, 2.0, 0.0))
    bpy.context.active_object.data.materials.append(mat_floor)
    for px in np.linspace(-4.5, 4.5, 19):
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(px, 2.0, 0.01))
        pl = bpy.context.active_object
        pl.scale = (0.46, 8.0, 0.03)
        pl.data.materials.append(mat_floor)

    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 4.8, 2.0))
    bw = bpy.context.active_object
    bw.scale = (11.0, 0.2, 4.2)
    bw.data.materials.append(mat_wall)

    # Lower wood wainscoting on back wall
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 4.68, 0.55))
    wc = bpy.context.active_object
    wc.scale = (10.6, 0.08, 1.1)
    wc.data.materials.append(mat_dark)

    # Harbor window on left wall/back-left
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(-2.35, 4.65, 2.05))
    win = bpy.context.active_object
    win.scale = (1.55, 0.08, 1.25)
    win.data.materials.append(mat_sky)
    for wx in [-2.85, -2.35, -1.85]:
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(wx, 4.60, 2.05))
        fr = bpy.context.active_object
        fr.scale = (0.05, 0.10, 1.28)
        fr.data.materials.append(mat_dark)
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(-2.35, 4.60, 2.05))
    frh = bpy.context.active_object
    frh.scale = (1.58, 0.10, 0.05)
    frh.data.materials.append(mat_dark)

    # Multi-tier wooden shelves on center-right back wall stocked with 3D jars & crates
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(1.15, 4.45, 2.0))
    sh_back = bpy.context.active_object
    sh_back.scale = (4.2, 0.25, 1.8)
    sh_back.data.materials.append(mat_dark)
    for sz in [1.25, 1.75, 2.25, 2.75]:
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(1.15, 4.35, sz))
        shelf = bpy.context.active_object
        shelf.scale = (4.3, 0.42, 0.06)
        shelf.data.materials.append(mat_wood)

    for r_idx, sz in enumerate([1.42, 1.92, 2.42]):
        for c_idx, sx in enumerate(np.linspace(-0.7, 3.0, 11)):
            m = jar_mats[(r_idx * 3 + c_idx) % len(jar_mats)]
            if (r_idx + c_idx) % 2 == 0:
                bpy.ops.mesh.primitive_cylinder_add(vertices=12, radius=0.11, depth=0.28, location=(sx, 4.32, sz))
            else:
                bpy.ops.mesh.primitive_cube_add(size=1.0, location=(sx, 4.32, sz))
                bpy.context.active_object.scale = (0.22, 0.22, 0.28)
            bpy.context.active_object.data.materials.append(m)

    # Foreground merchant counter (clean bottom 30% in front of counter for dialogue box)
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0.0, 2.25, 0.52))
    cnt = bpy.context.active_object
    cnt.scale = (5.4, 0.85, 0.96)
    cnt.data.materials.append(mat_wood)
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0.0, 2.25, 1.02))
    ctop = bpy.context.active_object
    ctop.scale = (5.6, 0.98, 0.08)
    ctop.data.materials.append(mat_dark)

    # Open ledger book, brass scale, and oil lamp on counter
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(-0.15, 2.15, 1.09))
    led = bpy.context.active_object
    led.scale = (0.65, 0.42, 0.05)
    led.data.materials.append(mat_paper)

    bpy.ops.mesh.primitive_cylinder_add(vertices=10, radius=0.03, depth=0.48, location=(1.25, 2.2, 1.28))
    bpy.context.active_object.data.materials.append(mat_brass)
    bpy.ops.mesh.primitive_cylinder_add(vertices=10, radius=0.02, depth=0.46, location=(1.25, 2.2, 1.48), rotation=(0, math.pi / 2, 0))
    bpy.context.active_object.data.materials.append(mat_brass)

    bpy.ops.mesh.primitive_cone_add(vertices=12, radius1=0.11, radius2=0.05, depth=0.22, location=(-1.25, 2.2, 1.16))
    bpy.context.active_object.data.materials.append(mat_brass)
    bpy.ops.mesh.primitive_uv_sphere_add(segments=12, ring_count=8, radius=0.085, location=(-1.25, 2.2, 1.32))
    bpy.context.active_object.data.materials.append(mat_lamp)

    cam_data = bpy.data.cameras.new("Cam")
    cam_data.lens = 32.0
    cam = bpy.data.objects.new("Cam", cam_data)
    bpy.context.collection.objects.link(cam)
    scn.camera = cam
    cam.location = (0.0, -1.65, 1.48)
    cam.rotation_euler = Euler((math.radians(87.5), 0, 0), 'XYZ')

    out_name = "jamestown_shop__night.jpg" if night else "jamestown_shop.jpg"
    tmp_png = f"/tmp/{out_name}.png"
    scn.render.filepath = tmp_png
    bpy.ops.render.render(write_still=True)
    im = Image.open(tmp_png).convert("RGB")
    im.save(os.path.join(ART_ROOT, "bg", out_name), quality=92, optimize=True)
    print(f"[BG 3D OK] {out_name}")


# ---------------------------------------------------------------------------
# PART 4: 3D CHARACTERS (chara 1200x1800 & face 512x512) IN BLENDER 4.0.2
# ---------------------------------------------------------------------------
def build_3d_character_mesh(cid):
    """Build a 3D Napoleonic character bust & torso/thighs in Blender 4.0.2."""
    specs = {
        "marie": {
            "skin": (0.92, 0.78, 0.68), "hair": (0.22, 0.14, 0.10),
            "coat": (0.58, 0.14, 0.19), "lapel": (0.94, 0.89, 0.79),
            "trim": (0.86, 0.68, 0.26), "hat": "ribbon", "female": True,
        },
        "montholon": {
            "skin": (0.89, 0.74, 0.63), "hair": (0.30, 0.24, 0.19),
            "coat": (0.14, 0.34, 0.21), "lapel": (0.76, 0.16, 0.16),
            "trim": (0.88, 0.72, 0.24), "hat": "bicorne", "female": False,
        },
        "villefort": {
            "skin": (0.90, 0.76, 0.65), "hair": (0.17, 0.13, 0.11),
            "coat": (0.14, 0.21, 0.36), "lapel": (0.92, 0.88, 0.81),
            "trim": (0.78, 0.81, 0.86), "hat": "none", "female": False,
        },
    }[cid]

    m_skin = make_cycles_toon_mat(f"{cid}_skin", specs["skin"], noise_amt=0.0)
    m_hair = make_cycles_toon_mat(f"{cid}_hair", specs["hair"], noise_amt=0.0)
    m_coat = make_cycles_toon_mat(f"{cid}_coat", specs["coat"], noise_amt=0.0)
    m_lapel = make_cycles_toon_mat(f"{cid}_lapel", specs["lapel"], noise_amt=0.0)
    m_trim = make_cycles_toon_mat(f"{cid}_trim", specs["trim"], noise_amt=0.0)
    m_white = make_cycles_toon_mat(f"{cid}_white", (0.95, 0.93, 0.89), noise_amt=0.0)
    m_iris = make_cycles_toon_mat(f"{cid}_iris", (0.18, 0.28, 0.42), noise_amt=0.0)
    m_dark = make_cycles_toon_mat(f"{cid}_dark", (0.12, 0.09, 0.07), noise_amt=0.0)
    m_lip = make_cycles_toon_mat(f"{cid}_lip", (0.72, 0.34, 0.34) if specs["female"] else (0.64, 0.38, 0.34), noise_amt=0.0)

    # Lower coat / skirt (z = 0.0 .. 1.05, cut at mid-thigh)
    bpy.ops.mesh.primitive_cone_add(vertices=24, radius1=0.58, radius2=0.42, depth=1.08, location=(0, 0, 0.54))
    low = bpy.context.active_object
    low.scale = (1.0, 0.62, 1.0)
    low.data.materials.append(m_coat)

    # Upper torso & chest (z = 1.0 .. 1.88)
    bpy.ops.mesh.primitive_cylinder_add(vertices=24, radius=0.45, depth=0.88, location=(0, 0, 1.44))
    tor = bpy.context.active_object
    tor.scale = (1.08, 0.62, 1.0)
    tor.data.materials.append(m_coat)

    # Plastron / Waistcoat / Empire bodice front
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, -0.22, 1.45))
    plas = bpy.context.active_object
    plas.scale = (0.42, 0.16, 0.82)
    plas.data.materials.append(m_lapel)

    # Waist sash / belt
    bpy.ops.mesh.primitive_cylinder_add(vertices=24, radius=0.45, depth=0.12, location=(0, 0, 1.04))
    sash = bpy.context.active_object
    sash.scale = (1.06, 0.66, 1.0)
    sash.data.materials.append(m_trim)

    # Double-breasted buttons
    for bz in [1.22, 1.38, 1.54, 1.70]:
        for bx in [-0.13, 0.13]:
            bpy.ops.mesh.primitive_uv_sphere_add(segments=12, ring_count=8, radius=0.026, location=(bx, -0.31, bz))
            bpy.context.active_object.data.materials.append(m_trim)

    # Shoulders, sleeves, cuffs, and hands
    for side in [-1, 1]:
        if not specs["female"]:
            bpy.ops.mesh.primitive_uv_sphere_add(segments=14, ring_count=10, radius=0.16, location=(side * 0.48, 0, 1.84))
            ep = bpy.context.active_object
            ep.scale = (1.1, 0.65, 0.45)
            ep.data.materials.append(m_trim)

        bpy.ops.mesh.primitive_cylinder_add(
            vertices=16, radius=0.135, depth=0.92,
            location=(side * 0.52, 0.02, 1.36),
            rotation=(0.05, side * -0.10, 0)
        )
        slv = bpy.context.active_object
        slv.data.materials.append(m_coat)

        bpy.ops.mesh.primitive_cylinder_add(vertices=16, radius=0.142, depth=0.11, location=(side * 0.56, 0.0, 0.92))
        cuf = bpy.context.active_object
        cuf.data.materials.append(m_trim)

        bpy.ops.mesh.primitive_uv_sphere_add(segments=14, ring_count=10, radius=0.105, location=(side * 0.57, -0.02, 0.78))
        hnd = bpy.context.active_object
        hnd.data.materials.append(m_skin)

    # Neck & High Collar / Cravat
    bpy.ops.mesh.primitive_cylinder_add(vertices=18, radius=0.14, depth=0.28, location=(0, 0, 1.96))
    bpy.context.active_object.data.materials.append(m_skin)
    bpy.ops.mesh.primitive_cylinder_add(vertices=20, radius=0.175, depth=0.18, location=(0, -0.02, 1.93))
    bpy.context.active_object.data.materials.append(m_white)

    # 3D Sculpted Head (z = 2.04 .. 2.58)
    bpy.ops.mesh.primitive_uv_sphere_add(segments=28, ring_count=20, radius=0.27, location=(0, 0, 2.30))
    head = bpy.context.active_object
    head.scale = (0.92, 0.96, 1.08)
    head.data.materials.append(m_skin)

    # 3D Nose bridge
    bpy.ops.mesh.primitive_cone_add(vertices=10, radius1=0.042, radius2=0.018, depth=0.14, location=(0.01, -0.255, 2.27), rotation=(math.radians(-18), 0, 0))
    bpy.context.active_object.data.materials.append(m_skin)

    # 3D Eyes, irises, eyebrows, and mouth
    for side in [-1, 1]:
        ex = side * 0.095
        bpy.ops.mesh.primitive_uv_sphere_add(segments=14, ring_count=10, radius=0.042, location=(ex, -0.235, 2.33))
        eye = bpy.context.active_object
        eye.scale = (1.15, 0.55, 0.82)
        eye.data.materials.append(m_white)

        bpy.ops.mesh.primitive_uv_sphere_add(segments=12, ring_count=8, radius=0.024, location=(ex + 0.004, -0.256, 2.33))
        ir = bpy.context.active_object
        ir.scale = (1.0, 0.45, 1.0)
        ir.data.materials.append(m_iris)

        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(ex, -0.248, 2.385), rotation=(0, side * 0.06, 0))
        brow = bpy.context.active_object
        brow.scale = (0.095, 0.03, 0.018)
        brow.data.materials.append(m_dark)

    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, -0.248, 2.155))
    mouth = bpy.context.active_object
    mouth.scale = (0.10, 0.03, 0.022)
    mouth.data.materials.append(m_lip)

    # Hair & Hat (top strictly reaching z = 2.66)
    bpy.ops.mesh.primitive_uv_sphere_add(segments=24, ring_count=16, radius=0.295, location=(0, 0.03, 2.35))
    hair_cap = bpy.context.active_object
    hair_cap.scale = (0.96, 0.98, 1.05)
    hair_cap.data.materials.append(m_hair)

    # Bangs across forehead
    for bx, bz, rot in [(-0.11, 2.46, 0.25), (0.0, 2.48, 0.0), (0.11, 2.46, -0.25)]:
        bpy.ops.mesh.primitive_uv_sphere_add(segments=14, ring_count=10, radius=0.09, location=(bx, -0.19, bz), rotation=(0, rot, 0))
        bng = bpy.context.active_object
        bng.scale = (1.2, 0.65, 0.75)
        bng.data.materials.append(m_hair)

    if specs["female"]:
        for side in [-1, 1]:
            bpy.ops.mesh.primitive_uv_sphere_add(segments=14, ring_count=10, radius=0.11, location=(side * 0.26, -0.04, 2.24))
            curl = bpy.context.active_object
            curl.scale = (0.65, 0.75, 1.35)
            curl.data.materials.append(m_hair)
        bpy.ops.mesh.primitive_cylinder_add(vertices=20, radius=0.25, depth=0.07, location=(0, -0.02, 2.56))
        tiara = bpy.context.active_object
        tiara.data.materials.append(m_trim)
    elif specs["hat"] == "bicorne":
        bpy.ops.mesh.primitive_cone_add(vertices=4, radius1=0.46, radius2=0.16, depth=0.28, location=(0, -0.02, 2.56), rotation=(0, 0, math.pi / 4))
        bic = bpy.context.active_object
        bic.scale = (1.35, 0.52, 1.0)
        bic.data.materials.append(m_dark)
        bpy.ops.mesh.primitive_uv_sphere_add(segments=12, ring_count=8, radius=0.048, location=(0.14, -0.18, 2.54))
        bpy.context.active_object.data.materials.append(m_trim)


def normalize_chara_rgba(raw_png, out_chara_png, out_face_png=None):
    """
    Frame the rendered 3D Blender character onto 1200x1800 RGBA:
    - Top of head strictly at y = 152 (inside required 120..200)
    - Bottom cut touching y = 1799
    - Crisp straight alpha (semi_share < 0.03)
    """
    im = Image.open(raw_png).convert("RGBA")
    arr = np.array(im)
    alpha = arr[:, :, 3]
    ys, xs = np.where(alpha > 32)
    x0, x1 = int(xs.min()), int(xs.max())
    y0, y1 = int(ys.min()), int(ys.max())

    crop = im.crop((x0, y0, x1 + 1, y1 + 1))
    target_h = 1800 - 152  # 1648 px so top is at y=152 and bottom is at y=1799
    target_w = int(crop.width * (target_h / float(crop.height)))
    target_w = min(980, max(560, target_w))
    resized = crop.resize((target_w, target_h), Image.LANCZOS)

    canvas = Image.new("RGBA", (1200, 1800), (0, 0, 0, 0))
    paste_x = (1200 - target_w) // 2
    canvas.paste(resized, (paste_x, 152))

    # Crisp straight alpha threshold
    c_arr = np.array(canvas)
    mask = c_arr[:, :, 3] > 96
    c_arr[:, :, 3] = np.where(mask, 255, 0)
    for c in range(3):
        c_arr[:, :, c] = np.where(mask, c_arr[:, :, c], 0)
    final_chara = Image.fromarray(c_arr, mode="RGBA")
    if out_chara_png:
        final_chara.save(out_chara_png, optimize=True)

    if out_face_png:
        # Head & shoulders bust from y=110..790 -> 512x512 with shoulders touching y=511
        bust = final_chara.crop((260, 112, 940, 792)).resize((512, 512), Image.LANCZOS)
        b_arr = np.array(bust)
        b_mask = b_arr[:, :, 3] > 96
        b_arr[:, :, 3] = np.where(b_mask, 255, 0)
        for c in range(3):
            b_arr[:, :, c] = np.where(b_mask, b_arr[:, :, c], 0)
        Image.fromarray(b_arr, mode="RGBA").save(out_face_png, optimize=True)


def render_p0_characters_and_faces():
    for cid, save_chara, save_face in [
        ("marie", True, True),
        ("montholon", True, False),
        ("villefort", False, True),
    ]:
        clear_blender()
        scn = setup_toon_render_scene(1200, 1800, transparent=True, samples=8, line_thickness=3.0)
        add_standard_lights(night=False)
        build_3d_character_mesh(cid)

        # Slightly turned 3/4 view as required by HD_ART_RULES §4.2
        cam_data = bpy.data.cameras.new("CharaCam")
        cam_data.type = 'ORTHO'
        cam_data.ortho_scale = 2.85
        cam = bpy.data.objects.new("CharaCam", cam_data)
        bpy.context.collection.objects.link(cam)
        scn.camera = cam
        cam.location = (0.38, -3.6, 1.36)
        cam.rotation_euler = Euler((math.radians(90), 0, math.radians(6.0)), 'XYZ')

        tmp_png = f"/tmp/chara_{cid}_raw.png"
        scn.render.filepath = tmp_png
        bpy.ops.render.render(write_still=True)

        chara_out = os.path.join(ART_ROOT, f"chara/{cid}/normal.png") if save_chara else None
        face_out = os.path.join(ART_ROOT, f"face/{cid}.png") if save_face else None
        normalize_chara_rgba(tmp_png, chara_out, face_out)
        print(f"[3D CHARA/FACE OK] {cid} (chara={save_chara}, face={save_face})")


# ---------------------------------------------------------------------------
# PART 5: 4 P0 BATTLEFIELD UNITS IN BLENDER 4.0.2 (384x384, anchor=(192,336))
# ---------------------------------------------------------------------------
def build_3d_unit_soldier(uid, offset_x=0.0, offset_y=0.0, state="idle", frame_idx=0):
    specs = {
        "villefort": {"coat": (0.14, 0.22, 0.38), "pants": (0.88, 0.84, 0.76), "hat": "bicorne", "trim": (0.82, 0.85, 0.90), "weapon": "saber"},
        "marie":     {"coat": (0.58, 0.14, 0.19), "pants": (0.42, 0.11, 0.15), "hat": "ribbon",  "trim": (0.88, 0.70, 0.26), "weapon": "pistol"},
        "troop_line": {"coat": (0.15, 0.27, 0.52), "pants": (0.90, 0.87, 0.80), "hat": "shako",   "trim": (0.84, 0.22, 0.18), "weapon": "musket"},
        "enemy_whitecoat": {"coat": (0.88, 0.85, 0.79), "pants": (0.82, 0.79, 0.73), "hat": "shako", "trim": (0.86, 0.68, 0.22), "weapon": "musket"},
    }[uid]

    m_coat = make_cycles_toon_mat(f"u_{uid}_coat_{offset_x}", specs["coat"], noise_amt=0.0)
    m_pants = make_cycles_toon_mat(f"u_{uid}_pants_{offset_x}", specs["pants"], noise_amt=0.0)
    m_skin = make_cycles_toon_mat(f"u_{uid}_skin_{offset_x}", (0.91, 0.76, 0.65), noise_amt=0.0)
    m_dark = make_cycles_toon_mat(f"u_{uid}_dark_{offset_x}", (0.15, 0.13, 0.12), noise_amt=0.0)
    m_trim = make_cycles_toon_mat(f"u_{uid}_trim_{offset_x}", specs["trim"], noise_amt=0.0)
    m_steel = make_cycles_toon_mat(f"u_{uid}_steel_{offset_x}", (0.78, 0.82, 0.88), noise_amt=0.0)
    m_wood = make_cycles_toon_mat(f"u_{uid}_wood_{offset_x}", (0.48, 0.29, 0.16), noise_amt=0.0)
    m_flash = make_cycles_toon_mat(f"u_{uid}_flash_{offset_x}", (1.0, 0.84, 0.32), emission=3.5)

    # Pose dynamics facing +X
    lunge = 0.12 * frame_idx if state == "attack" else (-0.10 if state == "hit" else 0.0)
    bob = 0.04 * (frame_idx % 2) if state == "idle" else 0.0
    kneel = 0.22 if state == "dying" else (0.38 if state == "down" else 0.0)

    bx = offset_x + lunge
    by = offset_y

    # Boots & legs
    for side in [-1, 1]:
        stride = side * (0.08 if (state == "attack" and frame_idx == 1) else 0.03)
        bpy.ops.mesh.primitive_cylinder_add(vertices=12, radius=0.085, depth=0.38, location=(bx + stride, by + side * 0.11, 0.19))
        bpy.context.active_object.data.materials.append(m_dark if state == "down" else m_pants)
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(bx + stride + 0.03, by + side * 0.11, 0.06))
        bt = bpy.context.active_object
        bt.scale = (0.20, 0.14, 0.12)
        bt.data.materials.append(m_dark)

    # Torso (facing +X)
    tz = 0.62 - kneel * 0.5 + bob
    bpy.ops.mesh.primitive_cone_add(vertices=16, radius1=0.23, radius2=0.19, depth=0.52, location=(bx, by, tz))
    bpy.context.active_object.data.materials.append(m_coat)

    # Crossbelt
    bpy.ops.mesh.primitive_cylinder_add(vertices=12, radius=0.215, depth=0.07, location=(bx, by, tz - 0.12))
    bpy.context.active_object.data.materials.append(m_trim)

    # Head & Hat
    hz = tz + 0.38
    bpy.ops.mesh.primitive_uv_sphere_add(segments=16, ring_count=12, radius=0.165, location=(bx + 0.02, by, hz))
    bpy.context.active_object.data.materials.append(m_skin)

    if specs["hat"] == "shako":
        bpy.ops.mesh.primitive_cylinder_add(vertices=16, radius=0.17, depth=0.22, location=(bx + 0.02, by, hz + 0.18))
        bpy.context.active_object.data.materials.append(m_dark)
        bpy.ops.mesh.primitive_uv_sphere_add(segments=10, ring_count=8, radius=0.045, location=(bx + 0.17, by, hz + 0.22))
        bpy.context.active_object.data.materials.append(m_trim)
    elif specs["hat"] == "bicorne":
        bpy.ops.mesh.primitive_cone_add(vertices=4, radius1=0.26, radius2=0.10, depth=0.18, location=(bx + 0.02, by, hz + 0.17), rotation=(0, 0, math.pi / 4))
        bpy.context.active_object.data.materials.append(m_dark)
    else:
        bpy.ops.mesh.primitive_uv_sphere_add(segments=14, ring_count=10, radius=0.175, location=(bx, by, hz + 0.05))
        bpy.context.active_object.data.materials.append(m_dark)
        bpy.ops.mesh.primitive_cylinder_add(vertices=14, radius=0.16, depth=0.05, location=(bx + 0.02, by, hz + 0.15))
        bpy.context.active_object.data.materials.append(m_trim)

    # Weapon pointing right (+X)
    wz = tz + 0.05
    if specs["weapon"] == "musket":
        ext = 0.14 if state == "attack" and frame_idx >= 1 else 0.0
        bpy.ops.mesh.primitive_cylinder_add(vertices=10, radius=0.032, depth=0.72, location=(bx + 0.30 + ext, by - 0.12, wz), rotation=(0, math.pi / 2, 0))
        bpy.context.active_object.data.materials.append(m_wood)
        bpy.ops.mesh.primitive_cylinder_add(vertices=8, radius=0.016, depth=0.28, location=(bx + 0.72 + ext, by - 0.12, wz), rotation=(0, math.pi / 2, 0))
        bpy.context.active_object.data.materials.append(m_steel)
        if state == "attack" and frame_idx == 1:
            bpy.ops.mesh.primitive_cone_add(vertices=10, radius1=0.11, radius2=0.01, depth=0.24, location=(bx + 0.92 + ext, by - 0.12, wz), rotation=(0, math.pi / 2, 0))
            bpy.context.active_object.data.materials.append(m_flash)
    elif specs["weapon"] == "saber":
        ang = math.radians(75 if (state == "attack" and frame_idx == 1) else 35)
        bpy.ops.mesh.primitive_cylinder_add(vertices=10, radius=0.026, depth=0.62, location=(bx + 0.32, by - 0.14, wz + 0.12), rotation=(0, ang, 0))
        bpy.context.active_object.data.materials.append(m_steel)
    else:
        bpy.ops.mesh.primitive_cylinder_add(vertices=10, radius=0.035, depth=0.36, location=(bx + 0.26, by - 0.12, wz), rotation=(0, math.pi / 2, 0))
        bpy.context.active_object.data.materials.append(m_dark)
        if state == "attack" and frame_idx == 1:
            bpy.ops.mesh.primitive_uv_sphere_add(segments=10, ring_count=8, radius=0.09, location=(bx + 0.48, by - 0.12, wz))
            bpy.context.active_object.data.materials.append(m_flash)


def normalize_unit_rgba(raw_png, out_png, target_h=230):
    """Place the rendered 3D unit onto 384x384 RGBA with feet locked dead-center at anchor (192, 336)."""
    im = Image.open(raw_png).convert("RGBA")
    arr = np.array(im)
    ys, xs = np.where(arr[:, :, 3] > 32)
    x0, x1 = int(xs.min()), int(xs.max())
    y0, y1 = int(ys.min()), int(ys.max())

    crop = im.crop((x0, y0, x1 + 1, y1 + 1))
    scale = target_h / float(max(1, crop.height))
    new_w = min(340, max(90, int(round(crop.width * scale))))
    new_h = target_h
    resized = crop.resize((new_w, new_h), Image.LANCZOS)

    # Measure the horizontal center of the bottom 24 rows (feet band) so foot_x == 192!
    r_arr = np.array(resized)
    foot_band = r_arr[max(0, new_h - 24):new_h, :, 3] > 96
    _, fxs = np.where(foot_band)
    if len(fxs) > 0:
        foot_cx = int(round(0.5 * (fxs.min() + fxs.max())))
    else:
        foot_cx = new_w // 2

    canvas = Image.new("RGBA", (384, 384), (0, 0, 0, 0))
    paste_x = max(4, min(380 - new_w, 192 - foot_cx))
    paste_y = 336 - new_h + 1  # Bottom opaque pixel sits strictly at y = 336!
    canvas.paste(resized, (paste_x, paste_y))

    c_arr = np.array(canvas)
    mask = c_arr[:, :, 3] > 96
    c_arr[:, :, 3] = np.where(mask, 255, 0)
    for c in range(3):
        c_arr[:, :, c] = np.where(mask, c_arr[:, :, c], 0)
    Image.fromarray(c_arr, mode="RGBA").save(out_png, optimize=True)


def render_p0_units():
    state_frames = {"idle": 2, "attack": 2, "hit": 1, "down": 1, "dying": 1}
    for uid in ["villefort", "marie", "troop_line", "enemy_whitecoat"]:
        udir = os.path.join(ART_ROOT, f"unit/{uid}")
        for state, n_frames in state_frames.items():
            for f_idx in range(n_frames):
                clear_blender()
                scn = setup_toon_render_scene(384, 384, transparent=True, samples=4, line_thickness=2.2)
                add_standard_lights(night=False)

                if uid == "troop_line":
                    build_3d_unit_soldier(uid, offset_x=-0.22, offset_y=0.22, state=state, frame_idx=f_idx)
                    build_3d_unit_soldier(uid, offset_x=0.22, offset_y=0.18, state=state, frame_idx=f_idx)
                    build_3d_unit_soldier(uid, offset_x=0.0, offset_y=-0.16, state=state, frame_idx=f_idx)
                else:
                    build_3d_unit_soldier(uid, offset_x=0.0, offset_y=0.0, state=state, frame_idx=f_idx)

                # Orthographic camera looking 25° down, 30° 3/4 view (HD_ART_RULES §4.4)
                cam_data = bpy.data.cameras.new("UnitCam")
                cam_data.type = 'ORTHO'
                cam_data.ortho_scale = 2.2 if uid == "troop_line" else 1.85
                cam = bpy.data.objects.new("UnitCam", cam_data)
                bpy.context.collection.objects.link(cam)
                scn.camera = cam
                cam.location = (0.85, -3.2, 2.15)
                cam.rotation_euler = Euler((math.radians(65.0), 0.0, math.radians(14.0)), 'XYZ')

                tmp_png = f"/tmp/unit_{uid}_{state}_{f_idx}.png"
                scn.render.filepath = tmp_png
                bpy.ops.render.render(write_still=True)

                th = 230 if state in ("idle", "attack", "hit") else (190 if state == "dying" else 165)
                out_png = os.path.join(udir, f"{state}_{f_idx + 1:02d}.png")
                normalize_unit_rgba(tmp_png, out_png, target_h=th)

        with open(os.path.join(udir, "meta.json"), "w", encoding="utf-8") as f:
            json.dump({"fps": 12, "attack_hit_frame": 2}, f, indent=2)
        print(f"[3D UNIT OK] {uid}")


if __name__ == "__main__":
    clean_p0_directories()
    build_props()
    build_tiles()
    render_bellerophon_hold()
    render_jamestown_shop(night=False)
    render_jamestown_shop(night=True)
    render_p0_characters_and_faces()
    render_p0_units()
    print("ALL_19_P0_BLENDER_3D_ASSETS_COMPLETED")
