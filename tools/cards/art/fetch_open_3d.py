#!/usr/bin/env python3
"""Fetch free open-source 3D models from NVIDIA SimReady Assets (HuggingFace)
and KhronosGroup/glTF-Sample-Assets (GitHub), converting NVIDIA USD meshes to OBJ
so local Blender 4.0.2 can kitbash, shade, export GLBs, and raytrace sprites.
"""

import os
import urllib.request

from pxr import Usd, UsdGeom

CACHE_DIR = "/tmp/ocean_3d_src"

NVIDIA_USD_MODELS = {
    "nvidia_crate_plywood": "crate_plywood_a04/simready_usd/payloads/geometries.usd",
    "nvidia_book_open": "book_open_a01/simready_usd/payloads/geometries.usd",
    "nvidia_candle": "decor_candle_a01/simready_usd/payloads/geometries.usd",
    "nvidia_barrier_fence": "barrier_fence_metal_a02/simready_usd/payloads/geometries.usd",
    "nvidia_gold_jar": "container_jar_glass_gold_a01/simready_usd/payloads/geometries.usd",
}

GITHUB_GLB_MODELS = {
    "github_rigged_figure": "RiggedFigure",
    "github_fox": "Fox",
    "github_duck": "Duck",
}


def usd_to_obj(usd_path: str, obj_path: str) -> None:
    stage = Usd.Stage.Open(usd_path)
    vert_offset = 1
    with open(obj_path, "w", encoding="utf-8") as out:
        out.write("# Converted from NVIDIA SimReady OpenUSD asset\n")
        for prim in stage.Traverse():
            if not prim.IsA(UsdGeom.Mesh):
                continue
            mesh = UsdGeom.Mesh(prim)
            xform = UsdGeom.XformCache().GetLocalToWorldTransform(prim)
            pts = mesh.GetPointsAttr().Get() or []
            counts = mesh.GetFaceVertexCountsAttr().Get() or []
            indices = mesh.GetFaceVertexIndicesAttr().Get() or []
            if not pts or not counts:
                continue
            out.write(f"o {prim.GetName()}\n")
            for p in pts:
                wp = xform.Transform(p)
                out.write(f"v {wp[0]:.6f} {wp[1]:.6f} {wp[2]:.6f}\n")
            idx_pos = 0
            for c in counts:
                face_verts = [str(indices[idx_pos + k] + vert_offset) for k in range(c)]
                out.write("f " + " ".join(face_verts) + "\n")
                idx_pos += c
            vert_offset += len(pts)


def main() -> None:
    os.makedirs(CACHE_DIR, exist_ok=True)
    for name, rel in NVIDIA_USD_MODELS.items():
        usd_path = os.path.join(CACHE_DIR, f"{name}.usd")
        obj_path = os.path.join(CACHE_DIR, f"{name}.obj")
        if not os.path.exists(usd_path):
            url = f"https://huggingface.co/datasets/nvidia/simready-assets/resolve/main/{rel}"
            urllib.request.urlretrieve(url, usd_path)
        usd_to_obj(usd_path, obj_path)
        print(f"[NVIDIA SimReady] {name}: USD -> OBJ ({os.path.getsize(obj_path)} bytes)")

    for name, model in GITHUB_GLB_MODELS.items():
        glb_path = os.path.join(CACHE_DIR, f"{name}.glb")
        if not os.path.exists(glb_path):
            url = f"https://raw.githubusercontent.com/KhronosGroup/glTF-Sample-Assets/main/Models/{model}/glTF-Binary/{model}.glb"
            urllib.request.urlretrieve(url, glb_path)
        print(f"[GitHub glTF] {name}: GLB ({os.path.getsize(glb_path)} bytes)")


if __name__ == "__main__":
    main()
