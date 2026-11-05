#!/usr/bin/env python3
"""
Blender 4.0.2 3D Prop Generator for dehoudang (napoleon-branch-demo)
Generates all 12 3D battlefield props (art/hd/prop/*.glb) strictly adhering to:
- docs/cards/art/hd/HD_ART_RULES.md §1, §2, §3.6
- tools/hd_art/check_art.py (check_glb)
"""
import os
import math
import bpy
from mathutils import Vector

OUT_DIR = "/home/magnus51235608/dehoudang_napoleon_art/art/hd/prop"
os.makedirs(OUT_DIR, exist_ok=True)


def clear_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    for col in (bpy.data.objects, bpy.data.meshes, bpy.data.materials, bpy.data.images):
        for item in list(col):
            col.remove(item, do_unlink=True)


def make_palette_image(name, bands):
    w, h = 256, 256
    img = bpy.data.images.new(name=name, width=w, height=h, alpha=False)
    pixels = [1.0] * (w * h * 4)
    n_bands = len(bands)
    for y in range(h):
        band_idx = min(n_bands - 1, int((y / float(h)) * n_bands))
        base_r, base_g, base_b = bands[band_idx]
        sub = ((y % max(1, h // n_bands)) / float(max(1, h // n_bands)))
        shade = 0.86 if sub < 0.45 else (1.0 if sub < 0.85 else 1.08)
        for x in range(w):
            grain = 0.025 * math.sin(x * 0.25 + y * 0.12) + 0.015 * math.cos(x * 0.7 - y * 0.4)
            idx = (y * w + x) * 4
            pixels[idx] = max(0.0, min(1.0, base_r * shade + grain))
            pixels[idx + 1] = max(0.0, min(1.0, base_g * shade + grain))
            pixels[idx + 2] = max(0.0, min(1.0, base_b * shade + grain))
            pixels[idx + 3] = 1.0
    img.pixels[:] = pixels
    img.pack()
    return img


def make_gltf_material(name, bands, roughness=0.85, metallic=0.05):
    mat = bpy.data.materials.new(name=name)
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    links = mat.node_tree.links
    nodes.clear()

    out = nodes.new("ShaderNodeOutputMaterial")
    bsdf = nodes.new("ShaderNodeBsdfPrincipled")
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Base Color"].default_value = (bands[0][0], bands[0][1], bands[0][2], 1.0)

    tex = nodes.new("ShaderNodeTexImage")
    tex.image = make_palette_image(name + "_tex", bands)

    links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
    return mat


def assign_uv_band(obj, band_index, total_bands):
    mesh = obj.data
    if not mesh.uv_layers:
        mesh.uv_layers.new(name="UVMap")
    uv_layer = mesh.uv_layers.active.data
    v_min = (band_index + 0.08) / float(total_bands)
    v_max = (band_index + 0.92) / float(total_bands)
    for poly in mesh.polygons:
        for i, loop_idx in enumerate(poly.loop_indices):
            u = 0.15 + 0.70 * (i % 2)
            v = v_min if (i < 2) else v_max
            uv_layer[loop_idx].uv = (u, v)


def join_and_fit(objs, target_size, out_path, z_bottom=0.004):
    bpy.ops.object.select_all(action='DESELECT')
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    if len(objs) > 1:
        bpy.ops.object.join()
    obj = bpy.context.view_layer.objects.active

    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.mesh.quads_convert_to_tris()
    bpy.ops.object.mode_set(mode='OBJECT')

    verts = [obj.matrix_world @ v.co for v in obj.data.vertices]
    min_x, max_x = min(v.x for v in verts), max(v.x for v in verts)
    min_y, max_y = min(v.y for v in verts), max(v.y for v in verts)
    min_z, max_z = min(v.z for v in verts), max(v.z for v in verts)

    cur_dx = max(1e-4, max_x - min_x)
    cur_dy = max(1e-4, max_y - min_y)
    cur_dz = max(1e-4, max_z - min_z)

    tx, tz_up, ty_depth = target_size[0] * 0.90, target_size[1] * 0.90, target_size[2] * 0.90
    cx = 0.5 * (min_x + max_x)
    cy = 0.5 * (min_y + max_y)

    for v in obj.data.vertices:
        co = obj.matrix_world @ v.co
        nx = (co.x - cx) * (tx / cur_dx)
        ny = (co.y - cy) * (ty_depth / cur_dy)
        nz = (co.z - min_z) * (tz_up / cur_dz) + z_bottom
        v.co = Vector((nx, ny, nz))

    obj.matrix_world.identity()
    obj.data.update()
    for poly in obj.data.polygons:
        poly.use_smooth = False

    bpy.ops.export_scene.gltf(
        filepath=out_path,
        export_format='GLB',
        export_cameras=False,
        export_lights=False,
        export_apply=True,
        export_yup=True,
        export_texcoords=True,
        export_normals=True,
        export_materials='EXPORT',
    )
    print(f"[GLB OK] {os.path.basename(out_path)} ({os.path.getsize(out_path)} B)")


def build_tree_a():
    clear_scene()
    bands = [(0.28, 0.20, 0.14), (0.38, 0.27, 0.18), (0.18, 0.34, 0.18), (0.27, 0.48, 0.23), (0.38, 0.58, 0.28), (0.32, 0.30, 0.26)]
    mat = make_gltf_material("tree_a_mat", bands)
    objs = []
    bpy.ops.mesh.primitive_cone_add(vertices=10, radius1=0.09, radius2=0.045, depth=0.45, location=(0, 0, 0.225))
    t = bpy.context.active_object
    t.data.materials.append(mat)
    assign_uv_band(t, 0, len(bands))
    objs.append(t)
    for cx, cy, cz, sx, sy, sz, b in [(0, 0, 0.52, 0.22, 0.20, 0.16, 2), (-0.10, 0.06, 0.58, 0.16, 0.15, 0.14, 3), (0.11, -0.05, 0.60, 0.16, 0.15, 0.14, 3), (0, 0, 0.72, 0.16, 0.16, 0.14, 4)]:
        bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, radius=1.0, location=(cx, cy, cz))
        c = bpy.context.active_object
        c.scale = (sx, sy, sz)
        c.data.materials.append(mat)
        assign_uv_band(c, b, len(bands))
        objs.append(c)
    join_and_fit(objs, [0.60, 0.90, 0.60], os.path.join(OUT_DIR, "tree_a.glb"))


def build_tree_b():
    """Tall slender Italian cypress: max_size [0.4, 1.0, 0.4]"""
    clear_scene()
    bands = [(0.26, 0.18, 0.12), (0.14, 0.28, 0.16), (0.20, 0.38, 0.20), (0.28, 0.46, 0.24)]
    mat = make_gltf_material("tree_b_mat", bands)
    objs = []
    bpy.ops.mesh.primitive_cylinder_add(vertices=10, radius=0.04, depth=0.25, location=(0, 0, 0.125))
    tr = bpy.context.active_object
    tr.data.materials.append(mat)
    assign_uv_band(tr, 0, len(bands))
    objs.append(tr)
    for i, (cz, r1, r2, h, b) in enumerate([(0.38, 0.14, 0.11, 0.32, 1), (0.60, 0.12, 0.08, 0.28, 2), (0.82, 0.08, 0.015, 0.26, 3)]):
        bpy.ops.mesh.primitive_cone_add(vertices=12, radius1=r1, radius2=r2, depth=h, location=(0, 0, cz))
        c = bpy.context.active_object
        c.data.materials.append(mat)
        assign_uv_band(c, b, len(bands))
        objs.append(c)
    join_and_fit(objs, [0.40, 1.00, 0.40], os.path.join(OUT_DIR, "tree_b.glb"))


def build_tree_c():
    """Low bush cluster: max_size [0.6, 0.4, 0.6]"""
    clear_scene()
    bands = [(0.16, 0.30, 0.15), (0.24, 0.42, 0.20), (0.34, 0.52, 0.25), (0.28, 0.20, 0.14)]
    mat = make_gltf_material("tree_c_mat", bands)
    objs = []
    for cx, cy, cz, sx, sy, sz, b in [(0, 0, 0.14, 0.18, 0.18, 0.13, 0), (-0.11, 0.08, 0.12, 0.14, 0.13, 0.11, 1), (0.12, -0.06, 0.13, 0.15, 0.14, 0.11, 1), (0.04, 0.10, 0.16, 0.13, 0.13, 0.12, 2), (-0.06, -0.09, 0.15, 0.12, 0.12, 0.11, 2)]:
        bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, radius=1.0, location=(cx, cy, cz))
        c = bpy.context.active_object
        c.scale = (sx, sy, sz)
        c.data.materials.append(mat)
        assign_uv_band(c, b, len(bands))
        objs.append(c)
    join_and_fit(objs, [0.60, 0.40, 0.60], os.path.join(OUT_DIR, "tree_c.glb"))


def build_house_a():
    clear_scene()
    bands = [(0.76, 0.71, 0.62), (0.45, 0.41, 0.37), (0.62, 0.27, 0.18), (0.32, 0.21, 0.14), (0.20, 0.28, 0.34), (0.52, 0.22, 0.15)]
    mat = make_gltf_material("house_a_mat", bands)
    objs = []
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0, 0.06))
    f = bpy.context.active_object; f.scale = (0.68, 0.56, 0.12); f.data.materials.append(mat); assign_uv_band(f, 1, len(bands)); objs.append(f)
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0, 0.32))
    b = bpy.context.active_object; b.scale = (0.64, 0.52, 0.42); b.data.materials.append(mat); assign_uv_band(b, 0, len(bands)); objs.append(b)
    for side in [-1, 1]:
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, side * 0.16, 0.64), rotation=(side * 0.62, 0, 0))
        s = bpy.context.active_object; s.scale = (0.72, 0.38, 0.05); s.data.materials.append(mat); assign_uv_band(s, 2, len(bands)); objs.append(s)
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0.20, -0.12, 0.75))
    ch = bpy.context.active_object; ch.scale = (0.10, 0.10, 0.28); ch.data.materials.append(mat); assign_uv_band(ch, 5, len(bands)); objs.append(ch)
    join_and_fit(objs, [0.85, 1.00, 0.85], os.path.join(OUT_DIR, "house_a.glb"))


def build_house_b():
    """Barn with low stone courtyard wall: max_size [0.85, 0.9, 0.85]"""
    clear_scene()
    bands = [(0.68, 0.62, 0.52), (0.48, 0.44, 0.39), (0.56, 0.28, 0.18), (0.34, 0.23, 0.15)]
    mat = make_gltf_material("house_b_mat", bands)
    objs = []
    # Courtyard stone wall
    for lx, ly, sx, sy in [(0, -0.28, 0.72, 0.06), (-0.34, 0, 0.06, 0.56), (0.34, 0, 0.06, 0.56)]:
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(lx, ly, 0.09))
        w = bpy.context.active_object; w.scale = (sx, sy, 0.18); w.data.materials.append(mat); assign_uv_band(w, 1, len(bands)); objs.append(w)
    # Barn body
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0.08, 0.30))
    b = bpy.context.active_object; b.scale = (0.56, 0.42, 0.44); b.data.materials.append(mat); assign_uv_band(b, 0, len(bands)); objs.append(b)
    for side in [-1, 1]:
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0.08 + side * 0.13, 0.60), rotation=(side * 0.58, 0, 0))
        r = bpy.context.active_object; r.scale = (0.62, 0.32, 0.05); r.data.materials.append(mat); assign_uv_band(r, 2, len(bands)); objs.append(r)
    join_and_fit(objs, [0.85, 0.90, 0.85], os.path.join(OUT_DIR, "house_b.glb"))


def build_gate():
    clear_scene()
    bands = [(0.68, 0.18, 0.15), (0.55, 0.50, 0.44), (0.36, 0.33, 0.30), (0.78, 0.62, 0.24), (0.24, 0.16, 0.12)]
    mat = make_gltf_material("gate_mat", bands)
    objs = []
    for sx in [-0.30, 0.30]:
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(sx, 0, 0.48))
        col = bpy.context.active_object; col.scale = (0.16, 0.20, 0.84); col.data.materials.append(mat); assign_uv_band(col, 1, len(bands)); objs.append(col)
    for gx in [-0.11, 0.11]:
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(gx, 0, 0.40))
        lf = bpy.context.active_object; lf.scale = (0.20, 0.06, 0.68); lf.data.materials.append(mat); assign_uv_band(lf, 0, len(bands)); objs.append(lf)
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0, 0.88))
    ln = bpy.context.active_object; ln.scale = (0.82, 0.24, 0.12); ln.data.materials.append(mat); assign_uv_band(ln, 4, len(bands)); objs.append(ln)
    join_and_fit(objs, [0.95, 1.20, 0.95], os.path.join(OUT_DIR, "gate.glb"))


def build_eagle():
    clear_scene()
    bands = [(0.84, 0.68, 0.22), (0.42, 0.39, 0.35), (0.16, 0.25, 0.48), (0.88, 0.85, 0.78), (0.72, 0.18, 0.16)]
    mat = make_gltf_material("eagle_mat", bands, roughness=0.55, metallic=0.35)
    objs = []
    bpy.ops.mesh.primitive_cylinder_add(vertices=12, radius=0.18, depth=0.14, location=(0, 0, 0.07))
    b1 = bpy.context.active_object; b1.data.materials.append(mat); assign_uv_band(b1, 1, len(bands)); objs.append(b1)
    bpy.ops.mesh.primitive_cylinder_add(vertices=10, radius=0.022, depth=0.92, location=(0, 0, 0.58))
    p = bpy.context.active_object; p.data.materials.append(mat); assign_uv_band(p, 0, len(bands)); objs.append(p)
    for bx, b_idx in [(-0.09, 2), (0.0, 3), (0.09, 4)]:
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(bx, 0.025, 0.66))
        pn = bpy.context.active_object; pn.scale = (0.09, 0.018, 0.40); pn.data.materials.append(mat); assign_uv_band(pn, b_idx, len(bands)); objs.append(pn)
    bpy.ops.mesh.primitive_uv_sphere_add(segments=10, ring_count=8, radius=0.06, location=(0, 0, 1.12))
    eg = bpy.context.active_object; eg.scale = (1.8, 0.6, 1.2); eg.data.materials.append(mat); assign_uv_band(eg, 0, len(bands)); objs.append(eg)
    join_and_fit(objs, [0.60, 1.30, 0.60], os.path.join(OUT_DIR, "eagle.glb"))


def build_earthwork():
    """Gabion basket earthwork wall along X: max_size [1.0, 0.4, 0.5]"""
    clear_scene()
    bands = [(0.52, 0.38, 0.22), (0.38, 0.27, 0.16), (0.44, 0.34, 0.22)]
    mat = make_gltf_material("earthwork_mat", bands)
    objs = []
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0, 0.08))
    mound = bpy.context.active_object; mound.scale = (0.88, 0.38, 0.16); mound.data.materials.append(mat); assign_uv_band(mound, 2, len(bands)); objs.append(mound)
    for gx in [-0.30, -0.10, 0.10, 0.30]:
        bpy.ops.mesh.primitive_cylinder_add(vertices=12, radius=0.09, depth=0.32, location=(gx, 0, 0.18))
        gb = bpy.context.active_object; gb.data.materials.append(mat); assign_uv_band(gb, 0, len(bands)); objs.append(gb)
    join_and_fit(objs, [1.00, 0.40, 0.50], os.path.join(OUT_DIR, "earthwork.glb"))


def build_bridge():
    """Stone arch bridge along X: max_size [1.0, 0.5, 0.7], min_y -0.4 (z_bottom = -0.30)"""
    clear_scene()
    bands = [(0.58, 0.54, 0.48), (0.44, 0.41, 0.37), (0.68, 0.64, 0.58)]
    mat = make_gltf_material("bridge_mat", bands)
    objs = []
    # Piers extending down
    for px in [-0.36, 0.36]:
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(px, 0, 0.14))
        pr = bpy.context.active_object; pr.scale = (0.18, 0.58, 0.28); pr.data.materials.append(mat); assign_uv_band(pr, 1, len(bands)); objs.append(pr)
    # Deck & parapets
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0, 0.32))
    dk = bpy.context.active_object; dk.scale = (0.92, 0.58, 0.08); dk.data.materials.append(mat); assign_uv_band(dk, 0, len(bands)); objs.append(dk)
    for py in [-0.26, 0.26]:
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, py, 0.40))
        wl = bpy.context.active_object; wl.scale = (0.92, 0.06, 0.09); wl.data.materials.append(mat); assign_uv_band(wl, 2, len(bands)); objs.append(wl)
    join_and_fit(objs, [1.00, 0.50, 0.70], os.path.join(OUT_DIR, "bridge.glb"), z_bottom=-0.30)


def build_cheval():
    """Cheval de frise (spiked wooden barrier): max_size [0.9, 0.5, 0.4]"""
    clear_scene()
    bands = [(0.46, 0.30, 0.18), (0.32, 0.20, 0.12), (0.62, 0.46, 0.28)]
    mat = make_gltf_material("cheval_mat", bands)
    objs = []
    bpy.ops.mesh.primitive_cylinder_add(vertices=10, radius=0.04, depth=0.78, location=(0, 0, 0.20), rotation=(0, math.pi / 2, 0))
    bar = bpy.context.active_object; bar.data.materials.append(mat); assign_uv_band(bar, 1, len(bands)); objs.append(bar)
    for sx in [-0.28, -0.09, 0.09, 0.28]:
        for side in [-1, 1]:
            bpy.ops.mesh.primitive_cone_add(vertices=8, radius1=0.028, radius2=0.005, depth=0.42, location=(sx, 0, 0.20), rotation=(side * 0.68, 0, 0))
            sp = bpy.context.active_object; sp.data.materials.append(mat); assign_uv_band(sp, 0, len(bands)); objs.append(sp)
    join_and_fit(objs, [0.90, 0.50, 0.40], os.path.join(OUT_DIR, "cheval.glb"))


def build_reeds():
    """Marsh reeds clump: max_size [0.5, 0.6, 0.5]"""
    clear_scene()
    bands = [(0.34, 0.46, 0.24), (0.48, 0.54, 0.28), (0.38, 0.24, 0.14)]
    mat = make_gltf_material("reeds_mat", bands)
    objs = []
    for rx, ry, rot_x, rot_y in [(0, 0, 0.05, 0.0), (-0.08, 0.06, -0.12, 0.10), (0.09, -0.05, 0.10, -0.12), (-0.05, -0.08, 0.08, 0.08), (0.06, 0.08, -0.08, -0.08)]:
        bpy.ops.mesh.primitive_cone_add(vertices=8, radius1=0.018, radius2=0.006, depth=0.48, location=(rx, ry, 0.24), rotation=(rot_x, rot_y, 0))
        st = bpy.context.active_object; st.data.materials.append(mat); assign_uv_band(st, 0, len(bands)); objs.append(st)
        bpy.ops.mesh.primitive_cylinder_add(vertices=8, radius=0.016, depth=0.10, location=(rx, ry, 0.42), rotation=(rot_x, rot_y, 0))
        ct = bpy.context.active_object; ct.data.materials.append(mat); assign_uv_band(ct, 2, len(bands)); objs.append(ct)
    join_and_fit(objs, [0.50, 0.60, 0.50], os.path.join(OUT_DIR, "reeds.glb"))


def build_rocks():
    """Highland boulders: max_size [0.6, 0.3, 0.6]"""
    clear_scene()
    bands = [(0.48, 0.45, 0.41), (0.36, 0.34, 0.31), (0.60, 0.57, 0.52)]
    mat = make_gltf_material("rocks_mat", bands)
    objs = []
    for rx, ry, rz, sx, sy, sz, b in [(0, 0, 0.10, 0.18, 0.15, 0.11, 0), (-0.12, 0.08, 0.07, 0.12, 0.11, 0.08, 1), (0.11, -0.09, 0.08, 0.13, 0.12, 0.09, 2)]:
        bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=1.0, location=(rx, ry, rz))
        rk = bpy.context.active_object; rk.scale = (sx, sy, sz); rk.data.materials.append(mat); assign_uv_band(rk, b, len(bands)); objs.append(rk)
    join_and_fit(objs, [0.60, 0.30, 0.60], os.path.join(OUT_DIR, "rocks.glb"))


def build_all_props(out_dir=None):
    global OUT_DIR
    if out_dir:
        OUT_DIR = out_dir
    build_tree_a()
    build_tree_b()
    build_tree_c()
    build_house_a()
    build_house_b()
    build_gate()
    build_eagle()
    build_earthwork()
    build_bridge()
    build_cheval()
    build_reeds()
    build_rocks()


def build_all_p0_props(out_dir=None):
    build_all_props(out_dir)


if __name__ == "__main__":
    build_all_props()
    print("ALL_12_GLB_PROPS_DONE")
