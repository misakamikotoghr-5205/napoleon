#!/usr/bin/env python3
"""Blender 4.0.2 headless 3D modeling, kitbashing (NVIDIA SimReady + GitHub glTF),
GLB export, and Cycles raytraced sprite/icon generator for the Napoleon Roguelike
& Arknights-style Tactical Battle Grid.

Run via:
    /usr/bin/blender --background --python tools/cards/art/gen_napoleon_blender.py
"""

import math
import os
import sys

import bpy
from mathutils import Euler, Matrix, Vector

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
SRC_DIR = "/tmp/ocean_3d_src"
OUT_MODELS = os.path.join(ROOT, "art", "ocean_3d", "models")
OUT_RENDERS = os.path.join(ROOT, "art", "ocean_3d", "renders")


def ensure_dirs() -> None:
    os.makedirs(OUT_MODELS, exist_ok=True)
    os.makedirs(OUT_RENDERS, exist_ok=True)


def reset_scene() -> None:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.samples = 20
    scene.cycles.use_denoising = False
    scene.render.film_transparent = True
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"

    world = bpy.data.worlds.new("OceanWorld")
    world.use_nodes = True
    bg = world.node_tree.nodes.get("Background")
    if bg:
        bg.inputs[0].default_value = (0.09, 0.08, 0.07, 1.0)
        bg.inputs[1].default_value = 0.85
    scene.world = world


def setup_studio_lights(iso_angle: str = "unit") -> None:
    scene = bpy.context.scene
    cam_data = bpy.data.cameras.new("StudioCam")
    cam = bpy.data.objects.new("StudioCam", cam_data)
    bpy.context.collection.objects.link(cam)
    if iso_angle == "coin":
        cam.location = (0.0, -2.15, 2.35)
        cam.rotation_euler = (math.radians(42.0), 0.0, 0.0)
        cam_data.lens = 55.0
    elif iso_angle == "tile":
        cam.location = (2.1, -2.35, 2.15)
        cam.rotation_euler = (math.radians(54.0), 0.0, math.radians(41.0))
        cam_data.lens = 52.0
    elif iso_angle == "showcase":
        cam.location = (2.55, -2.75, 1.65)
        cam.rotation_euler = (math.radians(66.0), 0.0, math.radians(43.0))
        cam_data.lens = 48.0
    else:
        cam.location = (1.75, -2.45, 1.75)
        cam.rotation_euler = (math.radians(62.0), 0.0, math.radians(35.0))
        cam_data.lens = 54.0
    scene.camera = cam

    key_data = bpy.data.lights.new("KeyLight", type="AREA")
    key_data.energy = 175.0
    key_data.size = 2.8
    key_data.color = (1.0, 0.92, 0.78)
    key = bpy.data.objects.new("KeyLight", key_data)
    key.location = (2.6, -2.4, 3.4)
    key.rotation_euler = (math.radians(42), 0, math.radians(38))
    bpy.context.collection.objects.link(key)

    fill_data = bpy.data.lights.new("FillLight", type="AREA")
    fill_data.energy = 85.0
    fill_data.size = 3.0
    fill_data.color = (0.72, 0.86, 1.0)
    fill = bpy.data.objects.new("FillLight", fill_data)
    fill.location = (-2.8, -1.8, 2.2)
    fill.rotation_euler = (math.radians(52), 0, math.radians(-48))
    bpy.context.collection.objects.link(fill)

    rim_data = bpy.data.lights.new("RimLight", type="POINT")
    rim_data.energy = 120.0
    rim_data.color = (1.0, 0.84, 0.52)
    rim = bpy.data.objects.new("RimLight", rim_data)
    rim.location = (0.0, 2.5, 2.8)
    bpy.context.collection.objects.link(rim)


def make_mat(
    name: str,
    rgba: tuple,
    metallic: float = 0.0,
    roughness: float = 0.4,
    emission: tuple = None,
    emission_strength: float = 0.0,
):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    if bsdf:
        bsdf.inputs["Base Color"].default_value = rgba
        bsdf.inputs["Metallic"].default_value = metallic
        bsdf.inputs["Roughness"].default_value = roughness
        if emission is not None and emission_strength > 0.0:
            if "Emission Color" in bsdf.inputs:
                bsdf.inputs["Emission Color"].default_value = emission
                bsdf.inputs["Emission Strength"].default_value = emission_strength
            elif "Emission" in bsdf.inputs:
                bsdf.inputs["Emission"].default_value = emission
    return mat


def assign_mat(obj, mat) -> None:
    if obj.type != "MESH":
        return
    if obj.data.materials:
        for i in range(len(obj.data.materials)):
            obj.data.materials[i] = mat
    else:
        obj.data.materials.append(mat)


def normalize_objects(objs: list, target_size: float = 1.35, z_floor: float = -0.55) -> None:
    meshes = [o for o in objs if o.type == "MESH"]
    if not meshes:
        return
    bpy.context.view_layer.update()
    min_v = Vector((1e9, 1e9, 1e9))
    max_v = Vector((-1e9, -1e9, -1e9))
    for o in meshes:
        for corner in o.bound_box:
            wc = o.matrix_world @ Vector(corner)
            min_v.x = min(min_v.x, wc.x)
            min_v.y = min(min_v.y, wc.y)
            min_v.z = min(min_v.z, wc.z)
            max_v.x = max(max_v.x, wc.x)
            max_v.y = max(max_v.y, wc.y)
            max_v.z = max(max_v.z, wc.z)
    extent = max(max_v.x - min_v.x, max_v.y - min_v.y, max_v.z - min_v.z, 1e-4)
    scale = target_size / extent
    center_xy = Vector(((min_v.x + max_v.x) * 0.5, (min_v.y + max_v.y) * 0.5, min_v.z))

    root = bpy.data.objects.new("NormRoot", None)
    bpy.context.collection.objects.link(root)
    for o in objs:
        if o.parent is None:
            o.parent = root
    bpy.context.view_layer.update()
    root.scale = (scale, scale, scale)
    root.location = (-center_xy.x * scale, -center_xy.y * scale, z_floor - center_xy.z * scale)
    bpy.context.view_layer.update()


def import_nvidia_obj(name: str, mat, target_size: float = 1.25, z_floor: float = -0.45, decimate_ratio: float = 0.22) -> list:
    obj_path = os.path.join(SRC_DIR, f"{name}.obj")
    if not os.path.exists(obj_path):
        return []
    before = set(bpy.data.objects)
    bpy.ops.wm.obj_import(filepath=obj_path)
    added = [o for o in bpy.data.objects if o not in before]
    for o in added:
        if o.type == "MESH":
            if decimate_ratio < 0.99 and len(o.data.polygons) > 600:
                mod = o.modifiers.new("Decimate", type="DECIMATE")
                mod.ratio = decimate_ratio
            assign_mat(o, mat)
    normalize_objects(added, target_size=target_size, z_floor=z_floor)
    return added


def import_github_glb(name: str, mat, target_size: float = 1.15, z_floor: float = -0.42) -> list:
    glb_path = os.path.join(SRC_DIR, f"{name}.glb")
    if not os.path.exists(glb_path):
        return []
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=glb_path)
    added = [o for o in bpy.data.objects if o not in before]
    for o in list(added):
        if o.type == "ARMATURE" or (o.type == "MESH" and o.name == "Icosphere"):
            bpy.data.objects.remove(o, do_unlink=True)
            added.remove(o)
    for o in added:
        if o.type == "MESH":
            o.modifiers.clear()
            assign_mat(o, mat)
    normalize_objects(added, target_size=target_size, z_floor=z_floor)
    return added


def export_glb(filename: str) -> None:
    # Remove cameras and lights before exporting GLB so Godot loads pure 3D meshes
    to_remove = [o for o in bpy.data.objects if o.type in ("CAMERA", "LIGHT")]
    saved = []
    for o in to_remove:
        saved.append((o.name, o.data, tuple(o.location), tuple(o.rotation_euler)))
        bpy.data.objects.remove(o, do_unlink=True)
    path = os.path.join(OUT_MODELS, filename)
    bpy.ops.export_scene.gltf(
        filepath=path,
        export_format="GLB",
        export_yup=True,
        export_apply=True,
        export_animations=False,
        export_skins=False,
    )
    for name, data, loc, rot in saved:
        obj = bpy.data.objects.new(name, data)
        obj.location = loc
        obj.rotation_euler = rot
        bpy.context.collection.objects.link(obj)
        if data.bl_rna.identifier == "Camera":
            bpy.context.scene.camera = obj


def render_png(filename: str, width: int = 128, height: int = 128) -> None:
    if "--models-only" in sys.argv and os.path.exists(os.path.join(OUT_RENDERS, filename)):
        return
    scene = bpy.context.scene
    scene.render.resolution_x = width
    scene.render.resolution_y = height
    scene.render.filepath = os.path.join(OUT_RENDERS, filename)
    bpy.ops.render.render(write_still=True)


def add_pedestal(ring_rgba: tuple, base_rgba: tuple = (0.16, 0.13, 0.11, 1.0)) -> None:
    mat_base = make_mat("PedestalBase", base_rgba, metallic=0.25, roughness=0.45)
    mat_ring = make_mat("PedestalRing", ring_rgba, metallic=0.85, roughness=0.22, emission=ring_rgba, emission_strength=0.35)
    bpy.ops.mesh.primitive_cylinder_add(vertices=32, radius=0.62, depth=0.14, location=(0, 0, -0.52))
    base = bpy.context.active_object
    assign_mat(base, mat_base)
    bpy.ops.mesh.primitive_torus_add(major_radius=0.62, minor_radius=0.045, location=(0, 0, -0.45))
    ring = bpy.context.active_object
    assign_mat(ring, mat_ring)


def build_unit(
    unit_id: str,
    coat_rgba: tuple,
    trim_rgba: tuple,
    hat_kind: str,
    weapon_kind: str,
    ring_rgba: tuple,
    extra_kind: str = "",
    export_model: bool = True,
) -> None:
    reset_scene()
    setup_studio_lights("unit")
    add_pedestal(ring_rgba)

    mat_coat = make_mat(f"Coat_{unit_id}", coat_rgba, metallic=0.15, roughness=0.38)
    mat_trim = make_mat(f"Trim_{unit_id}", trim_rgba, metallic=0.82, roughness=0.22)
    mat_skin = make_mat(f"Skin_{unit_id}", (0.88, 0.73, 0.58, 1.0), metallic=0.0, roughness=0.55)
    mat_steel = make_mat(f"Steel_{unit_id}", (0.82, 0.85, 0.90, 1.0), metallic=0.92, roughness=0.18)
    mat_dark = make_mat(f"Dark_{unit_id}", (0.12, 0.11, 0.13, 1.0), metallic=0.15, roughness=0.48)

    # Import GitHub RiggedFigure humanoid base mesh and kitbash Napoleonic silhouette
    import_github_glb("github_rigged_figure", mat_coat, target_size=1.05, z_floor=-0.44)

    # Torso armored coat overlay & gold sash
    bpy.ops.mesh.primitive_cone_add(vertices=24, radius1=0.34, radius2=0.22, depth=0.62, location=(0, 0, -0.05))
    assign_mat(bpy.context.active_object, mat_coat)
    bpy.ops.mesh.primitive_torus_add(major_radius=0.25, minor_radius=0.04, location=(0, 0, -0.08), rotation=(0.35, 0, 0))
    assign_mat(bpy.context.active_object, mat_trim)

    # Epaulets
    for sx in (-0.26, 0.26):
        bpy.ops.mesh.primitive_uv_sphere_add(radius=0.09, location=(sx, 0, 0.22))
        ep = bpy.context.active_object
        ep.scale = (1.2, 0.8, 0.55)
        assign_mat(ep, mat_trim)

    # Sculpted head
    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.17, location=(0, 0, 0.43))
    assign_mat(bpy.context.active_object, mat_skin)

    # Hat styles
    if hat_kind == "bicorne":
        bpy.ops.mesh.primitive_cylinder_add(vertices=24, radius=0.32, depth=0.18, location=(0, 0, 0.58))
        hat = bpy.context.active_object
        hat.scale = (1.15, 0.42, 1.0)
        assign_mat(hat, mat_dark)
        bpy.ops.mesh.primitive_uv_sphere_add(radius=0.055, location=(0, -0.13, 0.59))
        assign_mat(bpy.context.active_object, mat_trim)
    elif hat_kind == "bearskin":
        bpy.ops.mesh.primitive_cylinder_add(vertices=24, radius=0.19, depth=0.38, location=(0, 0, 0.68))
        assign_mat(bpy.context.active_object, mat_dark)
        bpy.ops.mesh.primitive_cylinder_add(vertices=16, radius=0.04, depth=0.24, location=(0.18, -0.05, 0.74))
        assign_mat(bpy.context.active_object, make_mat("PlumeRed", (0.88, 0.18, 0.16, 1.0), roughness=0.4))
    elif hat_kind == "shako":
        bpy.ops.mesh.primitive_cone_add(vertices=24, radius1=0.17, radius2=0.21, depth=0.26, location=(0, 0, 0.62))
        assign_mat(bpy.context.active_object, mat_coat)
        bpy.ops.mesh.primitive_uv_sphere_add(radius=0.05, location=(0, -0.17, 0.63))
        assign_mat(bpy.context.active_object, mat_trim)
    elif hat_kind == "tricorn":
        bpy.ops.mesh.primitive_cone_add(vertices=3, radius1=0.34, radius2=0.12, depth=0.16, location=(0, 0, 0.58))
        assign_mat(bpy.context.active_object, mat_dark)
    elif hat_kind == "captain":
        bpy.ops.mesh.primitive_cylinder_add(vertices=24, radius=0.21, depth=0.10, location=(0, 0, 0.58))
        assign_mat(bpy.context.active_object, mat_coat)
        bpy.ops.mesh.primitive_torus_add(major_radius=0.20, minor_radius=0.025, location=(0, 0, 0.55))
        assign_mat(bpy.context.active_object, mat_trim)
    elif hat_kind == "crown_veil":
        bpy.ops.mesh.primitive_torus_add(major_radius=0.16, minor_radius=0.035, location=(0, 0, 0.57))
        assign_mat(bpy.context.active_object, mat_trim)
    elif hat_kind == "dragoon":
        bpy.ops.mesh.primitive_uv_sphere_add(radius=0.19, location=(0, 0, 0.54))
        assign_mat(bpy.context.active_object, mat_trim)
        bpy.ops.mesh.primitive_cube_add(size=0.18, location=(0, 0.02, 0.69))
        crest = bpy.context.active_object
        crest.scale = (0.35, 1.4, 0.9)
        assign_mat(crest, make_mat("DragoonPlume", (0.85, 0.14, 0.14, 1.0)))
    else:
        bpy.ops.mesh.primitive_torus_add(major_radius=0.17, minor_radius=0.03, location=(0, 0, 0.54))
        assign_mat(bpy.context.active_object, mat_trim)

    # Weapons / Signature props
    if weapon_kind == "saber":
        bpy.ops.mesh.primitive_cylinder_add(vertices=12, radius=0.022, depth=0.82, location=(0.38, -0.18, 0.18), rotation=(0.35, 0.2, 0))
        assign_mat(bpy.context.active_object, mat_steel)
        bpy.ops.mesh.primitive_torus_add(major_radius=0.065, minor_radius=0.018, location=(0.32, -0.10, -0.12))
        assign_mat(bpy.context.active_object, mat_trim)
    elif weapon_kind == "rapier_cape":
        bpy.ops.mesh.primitive_cylinder_add(vertices=12, radius=0.016, depth=0.92, location=(0.40, -0.22, 0.16), rotation=(0.45, -0.15, 0))
        assign_mat(bpy.context.active_object, mat_steel)
        bpy.ops.mesh.primitive_cone_add(vertices=16, radius1=0.42, radius2=0.18, depth=0.72, location=(0, 0.16, -0.05))
        assign_mat(bpy.context.active_object, mat_dark)
    elif weapon_kind == "halberd_shield":
        bpy.ops.mesh.primitive_cylinder_add(vertices=12, radius=0.026, depth=1.15, location=(0.40, -0.12, 0.14))
        assign_mat(bpy.context.active_object, mat_trim)
        bpy.ops.mesh.primitive_cube_add(size=0.28, location=(-0.36, -0.18, 0.0))
        sh = bpy.context.active_object
        sh.scale = (0.25, 0.95, 1.35)
        assign_mat(sh, mat_trim)
    elif weapon_kind == "tome_lantern":
        # Kitbash NVIDIA SimReady open book next to Scholar Faria!
        book_objs = import_nvidia_obj("nvidia_book_open", mat_trim, target_size=0.45, z_floor=0.05, decimate_ratio=0.35)
        for o in book_objs:
            if o.parent is None:
                o.location.x -= 0.42
                o.location.y -= 0.22
        bpy.ops.mesh.primitive_uv_sphere_add(radius=0.11, location=(0.42, -0.20, 0.30))
        assign_mat(
            bpy.context.active_object,
            make_mat("LanternGlow", (1.0, 0.88, 0.42, 1.0), emission=(1.0, 0.85, 0.35, 1.0), emission_strength=3.5),
        )
    elif weapon_kind == "spear_fox":
        bpy.ops.mesh.primitive_cylinder_add(vertices=12, radius=0.022, depth=1.18, location=(0.38, -0.15, 0.15), rotation=(0.15, -0.2, 0))
        assign_mat(bpy.context.active_object, mat_trim)
        # Kitbash GitHub Fox companion beside Friday!
        fox_objs = import_github_glb("github_fox", mat_trim, target_size=0.42, z_floor=-0.44)
        for o in fox_objs:
            if o.parent is None:
                o.location.x -= 0.36
                o.location.y -= 0.18
    elif weapon_kind == "sextant_orb":
        bpy.ops.mesh.primitive_uv_sphere_add(radius=0.14, location=(0.38, -0.22, 0.18))
        assign_mat(
            bpy.context.active_object,
            make_mat("NautilusOrb", (0.25, 0.88, 1.0, 1.0), emission=(0.2, 0.82, 1.0, 1.0), emission_strength=3.2),
        )
        bpy.ops.mesh.primitive_torus_add(major_radius=0.18, minor_radius=0.02, location=(0.38, -0.22, 0.18), rotation=(0.6, 0.4, 0))
        assign_mat(bpy.context.active_object, mat_trim)
    elif weapon_kind == "spyglass":
        bpy.ops.mesh.primitive_cylinder_add(vertices=16, radius=0.045, depth=0.48, location=(0.36, -0.24, 0.18), rotation=(1.1, 0, -0.4))
        assign_mat(bpy.context.active_object, mat_trim)
    elif weapon_kind == "candle_fan":
        candle_objs = import_nvidia_obj("nvidia_candle", mat_trim, target_size=0.42, z_floor=-0.10, decimate_ratio=0.5)
        for o in candle_objs:
            if o.parent is None:
                o.location.x += 0.38
                o.location.y -= 0.20
    elif weapon_kind == "cannon_barrel":
        bpy.ops.mesh.primitive_cone_add(vertices=20, radius1=0.11, radius2=0.075, depth=0.55, location=(0.38, -0.20, -0.05), rotation=(1.2, 0, -0.3))
        assign_mat(bpy.context.active_object, mat_trim)
    elif weapon_kind == "musket":
        bpy.ops.mesh.primitive_cylinder_add(vertices=12, radius=0.025, depth=1.05, location=(0.36, -0.18, 0.12), rotation=(0.25, 0.15, 0))
        assign_mat(bpy.context.active_object, mat_steel)

    if export_model:
        export_glb(f"{unit_id}.glb")
    render_png(f"{unit_id}.png", 128, 128)


def build_vehicles_and_landmarks() -> None:
    # 1. Imperial 12-Pounder Cannon (imperial_cannon.glb + showcase_cannon.png)
    reset_scene()
    setup_studio_lights("showcase")
    mat_brass = make_mat("CannonBrass", (0.90, 0.72, 0.26, 1.0), metallic=0.88, roughness=0.22)
    mat_wood = make_mat("CannonWood", (0.42, 0.24, 0.12, 1.0), metallic=0.05, roughness=0.52)
    mat_iron = make_mat("CannonIron", (0.18, 0.19, 0.22, 1.0), metallic=0.82, roughness=0.32)

    add_pedestal((0.90, 0.72, 0.26, 1.0))
    # Carriage cheeks
    for sx in (-0.18, 0.18):
        bpy.ops.mesh.primitive_cube_add(size=0.25, location=(sx, 0.05, -0.18))
        cheek = bpy.context.active_object
        cheek.scale = (0.28, 2.2, 0.65)
        assign_mat(cheek, mat_wood)
    # Spoked wheels
    for sx in (-0.32, 0.32):
        bpy.ops.mesh.primitive_torus_add(
            major_radius=0.28, minor_radius=0.045, location=(sx, -0.08, -0.18), rotation=(0, math.radians(90), 0)
        )
        assign_mat(bpy.context.active_object, mat_wood)
        bpy.ops.mesh.primitive_cylinder_add(
            vertices=16, radius=0.07, depth=0.14, location=(sx, -0.08, -0.18), rotation=(0, math.radians(90), 0)
        )
        assign_mat(bpy.context.active_object, mat_brass)
    # Tapered brass barrel + cascabel knob + muzzle flare
    bpy.ops.mesh.primitive_cone_add(
        vertices=28, radius1=0.16, radius2=0.105, depth=1.18, location=(0, -0.10, 0.06), rotation=(math.radians(78), 0, 0)
    )
    assign_mat(bpy.context.active_object, mat_brass)
    bpy.ops.mesh.primitive_torus_add(
        major_radius=0.12, minor_radius=0.03, location=(0, -0.64, 0.18), rotation=(math.radians(78), 0, 0)
    )
    assign_mat(bpy.context.active_object, mat_brass)
    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.09, location=(0, 0.48, -0.06))
    assign_mat(bpy.context.active_object, mat_brass)
    # Stacked cannonballs
    for pos in [(-0.32, -0.35, -0.36), (-0.16, -0.38, -0.36), (-0.24, -0.36, -0.22)]:
        bpy.ops.mesh.primitive_uv_sphere_add(radius=0.085, location=pos)
        assign_mat(bpy.context.active_object, mat_iron)
    export_glb("imperial_cannon.glb")
    render_png("showcase_cannon.png", 256, 144)

    # 2. Bellerophon / Pharaon Warship (bellerophon_ship.glb + showcase_bellerophon.png)
    reset_scene()
    setup_studio_lights("showcase")
    mat_hull = make_mat("ShipHull", (0.36, 0.21, 0.11, 1.0), metallic=0.1, roughness=0.45)
    mat_sail = make_mat("ShipSail", (0.95, 0.90, 0.78, 1.0), metallic=0.0, roughness=0.55)
    mat_gold = make_mat("ShipGold", (0.92, 0.74, 0.28, 1.0), metallic=0.85, roughness=0.22)
    mat_sea = make_mat("SeaBase", (0.12, 0.34, 0.52, 1.0), metallic=0.35, roughness=0.18)

    add_pedestal((0.28, 0.66, 0.92, 1.0), base_rgba=(0.10, 0.24, 0.38, 1.0))
    bpy.ops.mesh.primitive_cube_add(size=0.5, location=(0, 0, -0.22))
    hull = bpy.context.active_object
    hull.scale = (0.72, 2.15, 0.52)
    assign_mat(hull, mat_hull)
    bpy.ops.mesh.primitive_Cube_add if False else bpy.ops.mesh.primitive_cube_add(size=0.4, location=(0, 0.38, -0.02))
    poop = bpy.context.active_object
    poop.scale = (0.68, 0.75, 0.38)
    assign_mat(poop, mat_gold)
    for my, mh in [(-0.36, 0.85), (0.04, 1.02), (0.40, 0.78)]:
        bpy.ops.mesh.primitive_cylinder_add(vertices=16, radius=0.032, depth=mh, location=(0, my, 0.22))
        assign_mat(bpy.context.active_object, mat_hull)
        bpy.ops.mesh.primitive_cube_add(size=0.35, location=(0, my - 0.04, 0.30))
        sail = bpy.context.active_object
        sail.scale = (1.35, 0.12, 1.15)
        assign_mat(sail, mat_sail)
    export_glb("bellerophon_ship.glb")
    render_png("showcase_bellerophon.png", 256, 144)

    # 3. Captain Nemo's Nautilus Submarine (nautilus_sub.glb + showcase_nautilus.png)
    reset_scene()
    setup_studio_lights("showcase")
    mat_sub = make_mat("NautilusSteel", (0.22, 0.30, 0.38, 1.0), metallic=0.86, roughness=0.26)
    mat_rib = make_mat("NautilusBrass", (0.86, 0.68, 0.26, 1.0), metallic=0.88, roughness=0.22)
    mat_eye = make_mat("NautilusEye", (0.28, 0.92, 1.0, 1.0), emission=(0.25, 0.90, 1.0, 1.0), emission_strength=4.0)

    add_pedestal((0.25, 0.88, 1.0, 1.0), base_rgba=(0.08, 0.18, 0.26, 1.0))
    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.34, location=(0, 0, -0.06))
    body = bpy.context.active_object
    body.scale = (0.72, 2.45, 0.72)
    assign_mat(body, mat_sub)
    bpy.ops.mesh.primitive_cylinder_add(vertices=20, radius=0.16, depth=0.28, location=(0, -0.10, 0.18))
    tower = bpy.context.active_object
    tower.scale = (0.75, 1.35, 0.85)
    assign_mat(tower, mat_rib)
    for sx in (-0.18, 0.18):
        bpy.ops.mesh.primitive_uv_sphere_add(radius=0.09, location=(sx, -0.46, 0.02))
        assign_mat(bpy.context.active_object, mat_eye)
    for ry in (-0.38, -0.12, 0.14, 0.38):
        bpy.ops.mesh.primitive_torus_add(
            major_radius=0.24, minor_radius=0.022, location=(0, ry, -0.06), rotation=(math.radians(90), 0, 0)
        )
        assign_mat(bpy.context.active_object, mat_rib)
    export_glb("nautilus_sub.glb")
    render_png("showcase_nautilus.png", 256, 144)


def build_tiles() -> None:
    tiles = [
        ("tile_spawn", (0.78, 0.16, 0.16, 1.0), (1.0, 0.32, 0.20, 1.0), "spawn"),
        ("tile_goal", (0.16, 0.44, 0.78, 1.0), (0.28, 0.82, 1.0, 1.0), "goal"),
        ("tile_ground", (0.44, 0.36, 0.26, 1.0), (0.76, 0.64, 0.42, 1.0), "ground"),
        ("tile_high", (0.34, 0.48, 0.38, 1.0), (0.88, 0.74, 0.32, 1.0), "high"),
        ("tile_obstacle", (0.24, 0.25, 0.28, 1.0), (0.85, 0.35, 0.22, 1.0), "obstacle"),
    ]
    for name, base_col, accent_col, kind in tiles:
        reset_scene()
        setup_studio_lights("tile")
        mat_base = make_mat(f"Base_{name}", base_col, metallic=0.25, roughness=0.45)
        mat_acc = make_mat(f"Acc_{name}", accent_col, metallic=0.75, roughness=0.25, emission=accent_col, emission_strength=1.2 if kind in ("spawn", "goal") else 0.15)
        bpy.ops.mesh.primitive_cube_add(size=1.15, location=(0, 0, -0.38))
        slab = bpy.context.active_object
        slab.scale = (1.0, 1.0, 0.22)
        assign_mat(slab, mat_base)

        if kind == "spawn":
            for sx in (-0.38, 0.38):
                bpy.ops.mesh.primitive_cylinder_add(vertices=16, radius=0.09, depth=0.75, location=(sx, 0, 0.08))
                assign_mat(bpy.context.active_object, mat_base)
            bpy.ops.mesh.primitive_torus_add(major_radius=0.38, minor_radius=0.08, location=(0, 0, 0.35), rotation=(math.radians(90), 0, 0))
            assign_mat(bpy.context.active_object, mat_acc)
        elif kind == "goal":
            bpy.ops.mesh.primitive_octahedron_add if False else bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=0.28, location=(0, 0, 0.22))
            assign_mat(bpy.context.active_object, mat_acc)
            bpy.ops.mesh.primitive_torus_add(major_radius=0.42, minor_radius=0.05, location=(0, 0, -0.18))
            assign_mat(bpy.context.active_object, mat_acc)
        elif kind == "high":
            bpy.ops.mesh.primitive_cylinder_add(vertices=8, radius=0.46, depth=0.52, location=(0, 0, -0.02))
            assign_mat(bpy.context.active_object, mat_base)
            bpy.ops.mesh.primitive_torus_add(major_radius=0.46, minor_radius=0.045, location=(0, 0, 0.24))
            assign_mat(bpy.context.active_object, mat_acc)
        elif kind == "obstacle":
            for pos, rad in [((-0.18, -0.1, 0.02), 0.28), ((0.22, 0.12, -0.06), 0.24), ((0.0, 0.18, 0.12), 0.22)]:
                bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=rad, location=pos)
                assign_mat(bpy.context.active_object, mat_base)
        else:
            bpy.ops.mesh.primitive_torus_add(major_radius=0.38, minor_radius=0.035, location=(0, 0, -0.24))
            assign_mat(bpy.context.active_object, mat_acc)

        render_png(f"{name}.png", 128, 128)


def build_coins_and_props() -> None:
    coins = [
        ("coin_gold", (0.95, 0.76, 0.22, 1.0), (1.0, 0.90, 0.48, 1.0), "sphere"),
        ("coin_supply", (0.78, 0.54, 0.26, 1.0), (0.92, 0.76, 0.45, 1.0), "cube"),
        ("coin_medal", (0.82, 0.18, 0.22, 1.0), (0.96, 0.80, 0.28, 1.0), "star"),
        ("coin_intel", (0.20, 0.46, 0.76, 1.0), (0.48, 0.88, 1.0, 1.0), "torus"),
    ]
    for name, rim_col, emblem_col, emblem in coins:
        reset_scene()
        setup_studio_lights("coin")
        mat_rim = make_mat(f"Rim_{name}", rim_col, metallic=0.88, roughness=0.20)
        mat_emb = make_mat(f"Emb_{name}", emblem_col, metallic=0.92, roughness=0.16, emission=emblem_col, emission_strength=0.35)
        bpy.ops.mesh.primitive_cylinder_add(vertices=32, radius=0.68, depth=0.16, location=(0, 0, 0))
        assign_mat(bpy.context.active_object, mat_rim)
        bpy.ops.mesh.primitive_torus_add(major_radius=0.66, minor_radius=0.06, location=(0, 0, 0.06))
        assign_mat(bpy.context.active_object, mat_emb)
        if emblem == "sphere":
            bpy.ops.mesh.primitive_uv_sphere_add(radius=0.28, location=(0, 0, 0.08))
            assign_mat(bpy.context.active_object, mat_emb)
        elif emblem == "cube":
            bpy.ops.mesh.primitive_cube_add(size=0.42, location=(0, 0, 0.09))
            assign_mat(bpy.context.active_object, mat_emb)
        elif emblem == "star":
            for angle in (0, 60, 120):
                bpy.ops.mesh.primitive_cube_add(size=0.46, location=(0, 0, 0.09), rotation=(0, 0, math.radians(angle)))
                st = bpy.context.active_object
                st.scale = (1.15, 0.32, 0.32)
                assign_mat(st, mat_emb)
        else:
            bpy.ops.mesh.primitive_torus_add(major_radius=0.30, minor_radius=0.07, location=(0, 0, 0.10))
            assign_mat(bpy.context.active_object, mat_emb)
        render_png(f"{name}.png", 64, 64)

    # 8 Monopoly Tactical Props (using NVIDIA SimReady 3D assets + Blender modeling)
    # 1. prop_barricade -> NVIDIA crate_plywood + barrier_fence
    reset_scene()
    setup_studio_lights("unit")
    mat_wood = make_mat("NV_CrateWood", (0.58, 0.38, 0.20, 1.0), metallic=0.1, roughness=0.45)
    import_nvidia_obj("nvidia_crate_plywood", mat_wood, target_size=1.25, z_floor=-0.45)
    export_glb("nvidia_crate_barricade.glb")
    render_png("prop_barricade.png", 64, 64)

    # 2. prop_imperial_decree -> NVIDIA book_open
    reset_scene()
    setup_studio_lights("unit")
    mat_book = make_mat("NV_BookGold", (0.92, 0.82, 0.56, 1.0), metallic=0.35, roughness=0.32)
    import_nvidia_obj("nvidia_book_open", mat_book, target_size=1.30, z_floor=-0.35, decimate_ratio=0.35)
    export_glb("nvidia_book_decree.glb")
    render_png("prop_imperial_decree.png", 64, 64)

    # 3. prop_bribe_pouch -> NVIDIA container_jar_glass_gold
    reset_scene()
    setup_studio_lights("unit")
    mat_jar = make_mat("NV_JarGold", (0.95, 0.74, 0.22, 1.0), metallic=0.90, roughness=0.18)
    import_nvidia_obj("nvidia_gold_jar", mat_jar, target_size=1.28, z_floor=-0.45, decimate_ratio=0.35)
    export_glb("nvidia_gold_vessel.glb")
    render_png("prop_bribe_pouch.png", 64, 64)

    # 4. prop_field_ration -> NVIDIA decor_candle + ration barrel
    reset_scene()
    setup_studio_lights("unit")
    mat_candle = make_mat("NV_Candle", (0.92, 0.64, 0.28, 1.0), metallic=0.35, roughness=0.32)
    import_nvidia_obj("nvidia_candle", mat_candle, target_size=1.22, z_floor=-0.45, decimate_ratio=0.5)
    export_glb("nvidia_salon_candle.glb")
    render_png("prop_field_ration.png", 64, 64)

    # 5. prop_loaded_dice -> Monopoly Brass & Ivory Die
    reset_scene()
    setup_studio_lights("unit")
    mat_die = make_mat("DieIvory", (0.96, 0.92, 0.80, 1.0), metallic=0.15, roughness=0.25)
    mat_pip = make_mat("DiePipGold", (0.92, 0.70, 0.18, 1.0), metallic=0.90, roughness=0.18)
    bpy.ops.mesh.primitive_cube_add(size=0.88, location=(0, 0, 0), rotation=(0.25, 0.35, 0.15))
    assign_mat(bpy.context.active_object, mat_die)
    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.13, location=(0.12, -0.42, 0.18))
    assign_mat(bpy.context.active_object, mat_pip)
    export_glb("monopoly_dice.glb")
    render_png("prop_loaded_dice.png", 64, 64)

    # 6. prop_forced_march -> Golden Cavalry Bugle
    reset_scene()
    setup_studio_lights("unit")
    mat_bugle = make_mat("BugleBrass", (0.95, 0.76, 0.24, 1.0), metallic=0.92, roughness=0.18)
    bpy.ops.mesh.primitive_cone_add(vertices=24, radius1=0.36, radius2=0.08, depth=0.95, location=(0, 0, 0), rotation=(0.8, 0.3, -0.4))
    assign_mat(bpy.context.active_object, mat_bugle)
    bpy.ops.mesh.primitive_torus_add(major_radius=0.24, minor_radius=0.05, location=(0.12, -0.1, 0.05), rotation=(0.8, 0.3, -0.4))
    assign_mat(bpy.context.active_object, mat_bugle)
    render_png("prop_forced_march.png", 64, 64)

    # 7. prop_spyglass -> Extending Naval Brass Spyglass
    reset_scene()
    setup_studio_lights("unit")
    mat_scope = make_mat("ScopeBrass", (0.88, 0.68, 0.26, 1.0), metallic=0.88, roughness=0.20)
    mat_lens = make_mat("ScopeLens", (0.28, 0.90, 1.0, 1.0), emission=(0.28, 0.90, 1.0, 1.0), emission_strength=2.5)
    bpy.ops.mesh.primitive_cylinder_add(vertices=24, radius=0.18, depth=1.05, location=(0, 0, 0), rotation=(0.95, 0.2, -0.45))
    assign_mat(bpy.context.active_object, mat_scope)
    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.17, location=(0.22, -0.35, 0.22))
    assign_mat(bpy.context.active_object, mat_lens)
    render_png("prop_spyglass.png", 64, 64)

    # 8. prop_smoke_bomb -> Alchemical Iron Smoke Bomb
    reset_scene()
    setup_studio_lights("unit")
    mat_bomb = make_mat("BombIron", (0.24, 0.26, 0.32, 1.0), metallic=0.78, roughness=0.32)
    mat_fuse = make_mat("BombGlow", (0.96, 0.42, 0.18, 1.0), emission=(1.0, 0.45, 0.15, 1.0), emission_strength=3.5)
    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.42, location=(0, 0, -0.08))
    assign_mat(bpy.context.active_object, mat_bomb)
    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.14, location=(0.12, -0.10, 0.36))
    assign_mat(bpy.context.active_object, mat_fuse)
    render_png("prop_smoke_bomb.png", 64, 64)


def main() -> None:
    ensure_dirs()
    # 9 Friendly Operators
    build_unit("unit_villefort", (0.14, 0.24, 0.48, 1.0), (0.95, 0.78, 0.26, 1.0), "bicorne", "saber", (0.95, 0.78, 0.26, 1.0))
    build_unit("unit_dantes", (0.16, 0.18, 0.26, 1.0), (0.82, 0.68, 0.32, 1.0), "tricorn", "rapier_cape", (0.38, 0.74, 0.96, 1.0))
    build_unit("unit_gourgaud", (0.18, 0.28, 0.52, 1.0), (0.92, 0.74, 0.24, 1.0), "bearskin", "halberd_shield", (0.92, 0.74, 0.24, 1.0))
    build_unit("unit_faria", (0.34, 0.24, 0.18, 1.0), (0.90, 0.78, 0.42, 1.0), "band", "tome_lantern", (0.96, 0.84, 0.38, 1.0))
    build_unit("unit_friday", (0.24, 0.46, 0.28, 1.0), (0.86, 0.68, 0.30, 1.0), "band", "spear_fox", (0.38, 0.86, 0.52, 1.0))
    build_unit("unit_nemo", (0.14, 0.34, 0.46, 1.0), (0.32, 0.88, 0.96, 1.0), "captain", "sextant_orb", (0.28, 0.88, 1.0, 1.0))
    build_unit("unit_morel", (0.22, 0.36, 0.54, 1.0), (0.88, 0.72, 0.32, 1.0), "tricorn", "spyglass", (0.48, 0.78, 0.96, 1.0))
    build_unit("unit_marie", (0.64, 0.18, 0.26, 1.0), (0.95, 0.80, 0.36, 1.0), "crown_veil", "candle_fan", (0.96, 0.52, 0.68, 1.0))
    build_unit("unit_corso", (0.26, 0.32, 0.24, 1.0), (0.90, 0.66, 0.22, 1.0), "shako", "cannon_barrel", (0.94, 0.62, 0.24, 1.0))

    # 3 Enemy Archetypes
    build_unit("enemy_vanguard", (0.76, 0.16, 0.16, 1.0), (0.90, 0.88, 0.84, 1.0), "shako", "musket", (0.92, 0.24, 0.20, 1.0))
    build_unit("enemy_guard", (0.58, 0.14, 0.16, 1.0), (0.86, 0.66, 0.24, 1.0), "dragoon", "halberd_shield", (0.92, 0.24, 0.20, 1.0))
    build_unit("enemy_commander", (0.48, 0.10, 0.18, 1.0), (0.96, 0.78, 0.26, 1.0), "bicorne", "saber", (1.0, 0.28, 0.22, 1.0))

    build_vehicles_and_landmarks()
    build_tiles()
    build_coins_and_props()
    print("NAPOLEON BLENDER 3D PIPELINE COMPLETE!")


if __name__ == "__main__":
    main()
