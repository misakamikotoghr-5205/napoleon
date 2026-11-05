#!/usr/bin/env python3
"""Acceptance check for the HD art under art/hd/ (rules: docs/cards/art/hd/HD_ART_RULES.md).

    python3 tools/hd_art/check_art.py                 # check everything delivered so far
    python3 tools/hd_art/check_art.py --sheet OUT_DIR # also write contact sheets for review
    python3 tools/hd_art/check_art.py --root PATH     # check a delivery folder laid out like art/hd/

Needs Python 3.8+ and Pillow. Exit code 1 when any FAIL. Messages are Chinese (the operator brief is Chinese).
"""
import argparse
import collections
import csv
import fnmatch
import json
import math
import os
import re
import struct
import sys

from PIL import Image, ImageChops, ImageDraw, ImageFont, ImageStat

REPO = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
LIST = os.path.join(REPO, "data", "hd", "art_list.json")
LICENSE_OK = ("original", "cc0", "cc-by-4.0", "cc-by-3.0", "public-domain", "purchased:", "mixamo", "mpfb-cc0")
LICENSE_BAD = ("nc", "nd", "sa", "editorial", "unknown", "?")
SIDE_FILES = {"README.md", "SOURCES.csv", "BATCHES.md", ".gitkeep"}


class Report:
    def __init__(self):
        self.rows = []

    def add(self, level, path, msg):
        self.rows.append((level, path, msg))

    def count(self, level):
        return sum(1 for r in self.rows if r[0] == level)


def load_list():
    with open(LIST, encoding="utf-8") as f:
        data = json.load(f)
    by_kind = collections.defaultdict(dict)
    for a in data["assets"]:
        by_kind[a["kind"]][a["id"]] = a
    return data, by_kind


# ---------------------------------------------------------------- image helpers
def opaque_mask(im, thr=128):
    return im.getchannel("A").point(lambda v: 255 if v >= thr else 0)


def frac(mask):
    h = mask.histogram()
    return h[255] / float(mask.size[0] * mask.size[1])


def lum_std(im, mask=None):
    return ImageStat.Stat(im.convert("L"), mask).stddev[0]


def top_color_share(im, mask=None):
    rgb = im.convert("RGB")
    if mask is not None:
        bg = Image.new("RGB", rgb.size, (255, 0, 255))
        bg.paste(rgb, (0, 0), mask)
        rgb = bg
    small = rgb.resize((max(1, rgb.size[0] // 4), max(1, rgb.size[1] // 4)), Image.NEAREST)
    q = small.quantize(colors=32, method=Image.MEDIANCUT)
    counts = sorted(q.getcolors(), reverse=True)
    pal = q.getpalette()
    total = 0
    best = 0
    for n, idx in counts:
        c = tuple(pal[idx * 3: idx * 3 + 3])
        if mask is not None and c == (255, 0, 255):
            continue
        total += n
        best = max(best, n)
    return best / float(total) if total else 1.0


def semi_share(im):
    a = im.getchannel("A").histogram()
    semi = sum(a[9:248])
    opaque = sum(a[128:])
    return semi / float(opaque) if opaque else 0.0


def center_x(mask):
    w, h = mask.size
    px = mask.load()
    sx = n = 0
    for y in range(0, h, 2):
        for x in range(0, w, 2):
            if px[x, y]:
                sx += x
                n += 1
    return sx / float(n) if n else -1


def bottom_center_x(mask, bbox, rows=12):
    px = mask.load()
    xs = [x for y in range(max(bbox[1], bbox[3] - rows), bbox[3]) for x in range(bbox[0], bbox[2]) if px[x, y]]
    return sum(xs) / float(len(xs)) if xs else -1


def seam_ratio(im, axis):
    """Mean abs difference across the wrap edge, relative to the difference between two interior neighbours."""
    g = im.convert("L")
    w, h = g.size
    px = g.load()
    if axis == "x":
        edge = sum(abs(px[0, y] - px[w - 1, y]) for y in range(h)) / float(h)
        mid = sum(abs(px[w // 2, y] - px[w // 2 - 1, y]) for y in range(h)) / float(h)
    else:
        edge = sum(abs(px[x, 0] - px[x, h - 1]) for x in range(w)) / float(w)
        mid = sum(abs(px[x, h // 2] - px[x, h // 2 - 1]) for x in range(w)) / float(w)
    return edge, mid


def open_image(path, rep, rel, kind_cfg):
    try:
        im = Image.open(path)
        im.load()
    except Exception as e:  # noqa: BLE001
        rep.add("FAIL", rel, "打不开：%s" % e)
        return None
    ext = os.path.splitext(path)[1].lower()
    if ext == ".png" and im.format != "PNG":
        rep.add("FAIL", rel, "扩展名是 .png，实际格式是 %s" % im.format)
    if ext in (".jpg", ".jpeg") and im.format != "JPEG":
        rep.add("FAIL", rel, "扩展名是 .jpg，实际格式是 %s" % im.format)
    want = tuple(kind_cfg["size"])
    if im.size != want:
        rep.add("FAIL", rel, "尺寸 %dx%d，应为 %dx%d" % (im.size + want))
        return None
    has_alpha = im.mode in ("RGBA", "LA") or (im.mode == "P" and "transparency" in im.info)
    if kind_cfg.get("alpha"):
        if not has_alpha:
            rep.add("FAIL", rel, "没有透明通道（应为 RGBA 透明底）")
            return None
        im = im.convert("RGBA")
    else:
        if has_alpha:
            a = im.convert("RGBA").getchannel("A")
            if a.getextrema()[0] < 255:
                rep.add("FAIL", rel, "有透明像素（这一类必须完全不透明）")
        im = im.convert("RGB")
    return im


def check_size_kb(path, rel, cfg, rep):
    kb = os.path.getsize(path) / 1024.0
    cap = cfg.get("max_kb")
    if cap and kb > cap * 2:
        rep.add("FAIL", rel, "文件 %.0f KB，超过上限 %d KB 的两倍" % (kb, cap))
    elif cap and kb > cap:
        rep.add("WARN", rel, "文件 %.0f KB，超过建议上限 %d KB（PNG 可以用 oxipng/pngquant 压一下）" % (kb, cap))


# ---------------------------------------------------------------- per-kind checks
def check_bg(im, rel, rep):
    s = lum_std(im)
    share = top_color_share(im)
    if s < 10 or share > 0.6:
        rep.add("FAIL", rel, "画面近乎纯色（亮度标准差 %.1f，主色占 %.0f%%）" % (s, share * 100))
    elif s < 18:
        rep.add("WARN", rel, "画面很暗或很平（亮度标准差 %.1f），确认不是空图" % s)


def check_chara(im, rel, rep):
    w, h = im.size
    m = opaque_mask(im)
    cov = frac(m)
    bbox = m.getbbox()
    if not bbox or cov < 0.12:
        rep.add("FAIL", rel, "人物太小或是空图（不透明面积 %.0f%%，应 18%%–75%%）" % (cov * 100))
        return
    if cov > 0.78:
        rep.add("FAIL", rel, "不透明面积 %.0f%%，背景没有抠掉？" % (cov * 100))
    if bbox[1] < 40:
        rep.add("FAIL", rel, "头顶（或帽子）离上边缘只有 %d 像素，至少留 40" % bbox[1])
    elif bbox[1] > 320:
        rep.add("FAIL", rel, "头顶在第 %d 行，人物太小（建议 120–200）" % bbox[1])
    elif not 100 <= bbox[1] <= 220:
        rep.add("WARN", rel, "头顶在第 %d 行，建议 120–200（同一批人物要一致）" % bbox[1])
    if bbox[3] < h:
        rep.add("FAIL", rel, "身体没有切到下边缘（应切在大腿中部，最下一行要有像素）")
    else:
        row = m.crop((0, h - 1, w, h))
        if frac(row) < 0.10:
            rep.add("WARN", rel, "最下一行只有 %.0f%% 宽有像素，确认切在大腿而不是脚下" % (frac(row) * 100))
    if bbox[0] < 2 or bbox[2] > w - 2:
        rep.add("WARN", rel, "人物碰到了左右边缘")
    cx = center_x(m)
    if not 450 <= cx <= 750:
        rep.add("WARN", rel, "人物重心在 x=%d，应在画面中央（450–750）" % cx)
    if semi_share(im) > 0.25:
        rep.add("WARN", rel, "半透明像素占 %.0f%%：是不是带了阴影、雾或背景残留？" % (semi_share(im) * 100))
    s = lum_std(im, m)
    if s < 16:
        rep.add("FAIL", rel, "人物几乎一个颜色（亮度标准差 %.1f），看不出脸和衣服" % s)


def check_expr_pair(normal, other, rel, rep):
    diff = ImageChops.difference(normal, other).convert("L").point(lambda v: 255 if v > 24 else 0)
    bb = diff.getbbox()
    if not bb:
        rep.add("WARN", rel, "和 normal 一模一样")
        return
    area = (bb[2] - bb[0]) * (bb[3] - bb[1]) / float(normal.size[0] * normal.size[1])
    if area > 0.2:
        rep.add("FAIL", rel, "和 normal 的差异区域占 %.0f%%：除脸以外应逐像素一致（姿势、机位、灯光不能变）" % (area * 100))
    elif (bb[1] + bb[3]) / 2 > normal.size[1] * 0.5:
        rep.add("WARN", rel, "差异集中在下半身，表情应该只改脸")


def check_face(im, rel, rep):
    m = opaque_mask(im)
    cov = frac(m)
    bbox = m.getbbox()
    if not bbox or cov < 0.2:
        rep.add("FAIL", rel, "头像太小或是空图（不透明面积 %.0f%%）" % (cov * 100))
        return
    if cov > 0.94:
        rep.add("FAIL", rel, "不透明面积 %.0f%%，背景没有抠掉？" % (cov * 100))
    if bbox[3] < im.size[1]:
        rep.add("WARN", rel, "肩膀没有切到下边缘")
    cx = center_x(m)
    if not 170 <= cx <= 342:
        rep.add("WARN", rel, "脸不在中央（重心 x=%d）" % cx)
    if lum_std(im, m) < 16:
        rep.add("FAIL", rel, "头像几乎一个颜色")


def check_unit_frame(im, rel, rep, anchor, state):
    w, h = im.size
    m = opaque_mask(im)
    cov = frac(m)
    bbox = m.getbbox()
    if not bbox or cov < 0.015:
        rep.add("FAIL", rel, "空帧或小人太小（不透明面积 %.1f%%）" % (cov * 100))
        return None
    if cov > 0.6:
        rep.add("FAIL", rel, "不透明面积 %.0f%%，背景没有抠掉？" % (cov * 100))
    if bbox[1] < 4 or bbox[0] < 2 or bbox[2] > w - 2:
        rep.add("FAIL", rel, "小人出界（碰到上、左或右边缘），bbox=%s" % (bbox,))
    foot = bbox[3] - 1
    if abs(foot - anchor[1]) > 10:
        rep.add("FAIL", rel, "最低点在第 %d 行，应在 %d±10（锚点 y）" % (foot, anchor[1]))
    bx = bottom_center_x(m, bbox)
    if abs(bx - anchor[0]) > 60:
        rep.add("FAIL", rel, "脚下中心在 x=%d，应在 %d±60（锚点 x）" % (bx, anchor[0]))
    height = bbox[3] - bbox[1]
    if state == "idle" and not 140 <= height <= 330:
        rep.add("WARN", rel, "待机帧高 %d 像素，单人建议 200–260，骑兵和炮最多 320" % height)
    if semi_share(im) > 0.3:
        rep.add("WARN", rel, "半透明像素占 %.0f%%：不要带地面阴影（阴影由游戏画）" % (semi_share(im) * 100))
    if lum_std(im, m) < 14:
        rep.add("FAIL", rel, "小人几乎一个颜色（亮度标准差 %.1f）" % lum_std(im, m))
    return height


def check_tex(im, rel, rep, axes):
    s = lum_std(im)
    if s < 5:
        rep.add("FAIL", rel, "贴图几乎纯色（亮度标准差 %.1f），要有材质细节" % s)
    for ax in axes:
        edge, mid = seam_ratio(im, ax)
        if edge > 10 and edge > mid * 2.5:
            rep.add("FAIL", rel, "%s方向接缝明显（边缘差 %.1f，内部相邻差 %.1f），平铺会看到缝" % (
                "左右" if ax == "x" else "上下", edge, mid))


# ---------------------------------------------------------------- glb
def _mat_mul(a, b):
    return [sum(a[r * 4 + k] * b[k * 4 + c] for k in range(4)) for r in range(4) for c in range(4)]


def _node_matrix(n):
    if "matrix" in n:
        m = n["matrix"]  # column-major
        return [m[c * 4 + r] for r in range(4) for c in range(4)]
    t = n.get("translation", [0, 0, 0])
    q = n.get("rotation", [0, 0, 0, 1])
    s = n.get("scale", [1, 1, 1])
    x, y, z, w = q
    rot = [1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w),
           2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w),
           2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)]
    return [rot[0] * s[0], rot[1] * s[1], rot[2] * s[2], t[0],
            rot[3] * s[0], rot[4] * s[1], rot[5] * s[2], t[1],
            rot[6] * s[0], rot[7] * s[1], rot[8] * s[2], t[2],
            0, 0, 0, 1]


def _img_size(b):
    if b[:8] == b"\x89PNG\r\n\x1a\n":
        return struct.unpack(">II", b[16:24])
    if b[:2] == b"\xff\xd8":
        i = 2
        while i < len(b) - 9:
            if b[i] != 0xFF:
                i += 1
                continue
            mk = b[i + 1]
            ln = struct.unpack(">H", b[i + 2:i + 4])[0]
            if mk in (0xC0, 0xC1, 0xC2):
                hgt, wid = struct.unpack(">HH", b[i + 5:i + 9])
                return wid, hgt
            i += 2 + ln
    return None


def check_glb(path, rel, asset, cfg, rep):
    with open(path, "rb") as f:
        data = f.read()
    if len(data) < 20 or data[:4] != b"glTF":
        rep.add("FAIL", rel, "不是 GLB 文件（文件头不是 glTF）")
        return
    ver = struct.unpack("<I", data[4:8])[0]
    if ver != 2:
        rep.add("FAIL", rel, "glTF 版本 %d，应为 2" % ver)
        return
    jlen, jtype = struct.unpack("<II", data[12:20])
    gl = json.loads(data[20:20 + jlen].decode("utf-8"))
    binchunk = b""
    off = 20 + jlen
    if off + 8 <= len(data):
        blen, _btype = struct.unpack("<II", data[off:off + 8])
        binchunk = data[off + 8:off + 8 + blen]
    if gl.get("cameras"):
        rep.add("FAIL", rel, "文件里带了相机，导出时去掉")
    if "KHR_lights_punctual" in gl.get("extensionsUsed", []):
        rep.add("FAIL", rel, "文件里带了灯光，导出时去掉")
    views = gl.get("bufferViews", [])
    for i, img in enumerate(gl.get("images", [])):
        if "uri" in img:
            rep.add("FAIL", rel, "贴图 %d 是外部文件（%s），要内嵌进 GLB" % (i, img["uri"][:40]))
            continue
        bv = views[img["bufferView"]]
        b = binchunk[bv.get("byteOffset", 0): bv.get("byteOffset", 0) + bv["byteLength"]]
        sz = _img_size(b)
        if sz and max(sz) > cfg["max_tex"]:
            rep.add("FAIL", rel, "贴图 %d 是 %dx%d，最大 %d" % (i, sz[0], sz[1], cfg["max_tex"]))
    acc = gl.get("accessors", [])
    meshes = gl.get("meshes", [])
    nodes = gl.get("nodes", [])
    tris = 0
    lo = [1e9] * 3
    hi = [-1e9] * 3
    ident = [1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1]

    def visit(ni, parent):
        nonlocal tris
        n = nodes[ni]
        m = _mat_mul(parent, _node_matrix(n))
        if "mesh" in n:
            for p in meshes[n["mesh"]].get("primitives", []):
                if p.get("mode", 4) == 4:
                    if "indices" in p:
                        tris += acc[p["indices"]]["count"] // 3
                    else:
                        tris += acc[p["attributes"]["POSITION"]]["count"] // 3
                pa = acc[p["attributes"]["POSITION"]]
                mn, mx = pa.get("min"), pa.get("max")
                if not mn or not mx:
                    continue
                for cx in (mn[0], mx[0]):
                    for cy in (mn[1], mx[1]):
                        for cz in (mn[2], mx[2]):
                            v = [m[r * 4] * cx + m[r * 4 + 1] * cy + m[r * 4 + 2] * cz + m[r * 4 + 3] for r in range(3)]
                            for k in range(3):
                                lo[k] = min(lo[k], v[k])
                                hi[k] = max(hi[k], v[k])
        for c in n.get("children", []):
            visit(c, m)

    scenes = gl.get("scenes", [])
    roots = scenes[gl.get("scene", 0)]["nodes"] if scenes else list(range(len(nodes)))
    for r in roots:
        visit(r, ident)
    if tris == 0 or lo[0] > hi[0]:
        rep.add("FAIL", rel, "没有网格（空模型）")
        return
    if tris > cfg["max_tris"] * 2:
        rep.add("FAIL", rel, "%d 个三角面，上限 %d" % (tris, cfg["max_tris"]))
    elif tris > cfg["max_tris"]:
        rep.add("WARN", rel, "%d 个三角面，建议不超过 %d" % (tris, cfg["max_tris"]))
    size = [hi[k] - lo[k] for k in range(3)]
    mx = asset.get("max_size", [1, 1.5, 1])
    names = ("X 宽", "高", "Z 深")
    order = (0, 1, 2)
    for k, name in zip(order, names):
        if size[k] > mx[k] + 0.05:
            rep.add("FAIL", rel, "%s %.2f 格，超过 %.2f（1 个 Blender 单位 = 1 格）" % (name, size[k], mx[k]))
    if size[1] < 0.05:
        rep.add("FAIL", rel, "模型高度只有 %.2f，几乎是平的" % size[1])
    min_y = asset.get("min_y", -0.05)
    if lo[1] < min_y - 0.01:
        rep.add("FAIL", rel, "最低点 y=%.2f，原点应在底面（最低点约为 0）" % lo[1])
    elif lo[1] > 0.05:
        rep.add("WARN", rel, "最低点 y=%.2f，模型浮在空中" % lo[1])
    if abs((hi[0] + lo[0]) / 2) > 0.1 or abs((hi[2] + lo[2]) / 2) > 0.1:
        rep.add("WARN", rel, "模型中心偏离原点（x=%.2f, z=%.2f），原点应在底面中心" % ((hi[0] + lo[0]) / 2, (hi[2] + lo[2]) / 2))
    return {"tris": tris, "size": size}


# ---------------------------------------------------------------- sources
def load_sources(root, rep):
    p = os.path.join(root, "SOURCES.csv")
    if not os.path.exists(p):
        return None
    rows = []
    with open(p, encoding="utf-8", newline="") as f:
        rd = csv.DictReader(f)
        need = ["asset_ids", "source", "author", "url", "license", "license_url", "notes"]
        if rd.fieldnames is None or [c.strip() for c in rd.fieldnames] != need:
            rep.add("FAIL", "SOURCES.csv", "表头应为：%s" % ",".join(need))
            return []
        for i, r in enumerate(rd, start=2):
            lic = (r.get("license") or "").strip().lower()
            if not lic:
                rep.add("FAIL", "SOURCES.csv", "第 %d 行没写许可" % i)
            elif not lic.startswith(LICENSE_OK) or any(re.search(r"(^|[^a-z])%s([^a-z]|$)" % re.escape(b), lic) for b in LICENSE_BAD):
                rep.add("FAIL", "SOURCES.csv", "第 %d 行许可“%s”不在白名单（original / CC0 / CC-BY-4.0 / CC-BY-3.0 / public-domain / purchased:<商店> / mixamo / mpfb-cc0）" % (i, r.get("license")))
            if lic.startswith("cc-by") and not (r.get("author") or "").strip():
                rep.add("FAIL", "SOURCES.csv", "第 %d 行是 CC-BY，必须写作者（署名要用）" % i)
            if not lic.startswith("original") and not (r.get("url") or "").strip():
                rep.add("FAIL", "SOURCES.csv", "第 %d 行不是自制，必须写来源网址" % i)
            rows.append([pat.strip() for pat in (r.get("asset_ids") or "").split() if pat.strip()])
    return rows


# ---------------------------------------------------------------- main walk
def classify(rel, by_kind):
    parts = rel.split("/")
    if parts[0] == "bg" and len(parts) == 2:
        stem, ext = os.path.splitext(parts[1])
        base = stem.split("__")[0]
        if ext.lower() in (".jpg", ".jpeg", ".png") and base in by_kind["bg"]:
            return "bg", base, {"variant": stem[len(base) + 2:] if "__" in stem else ""}
    if parts[0] == "cg" and len(parts) == 2:
        stem, ext = os.path.splitext(parts[1])
        if ext.lower() in (".jpg", ".jpeg", ".png") and stem in by_kind["cg"]:
            return "cg", stem, {}
    if parts[0] == "chara" and len(parts) == 3 and parts[2].endswith(".png"):
        return "chara", parts[1], {"expr": parts[2][:-4]}
    if parts[0] == "face" and len(parts) == 2 and parts[1].endswith(".png"):
        return "face", parts[1][:-4], {}
    if parts[0] == "unit" and len(parts) == 3:
        if parts[2] == "meta.json":
            return "unit_meta", parts[1], {}
        mm = re.match(r"^([a-z]+)_(\d\d)\.png$", parts[2])
        if mm:
            return "unit", parts[1], {"state": mm.group(1), "nn": int(mm.group(2))}
    if parts[0] == "tile" and len(parts) == 2 and parts[1].endswith(".png"):
        tid = parts[1][:-4]
        if tid in by_kind["side"]:
            return "side", tid, {}
        return "tex", tid, {}
    if parts[0] == "prop" and len(parts) == 2 and parts[1].endswith(".glb"):
        return "prop", parts[1][:-4], {}
    return None, None, None


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--root", default=os.path.join(REPO, "art", "hd"))
    ap.add_argument("--sheet", default="")
    args = ap.parse_args()
    data, by_kind = load_list()
    kinds = data["kinds"]
    rep = Report()
    root = os.path.abspath(args.root)
    files = []
    for dp, dn, fn in os.walk(root):
        dn[:] = [d for d in dn if not d.startswith("_") and not d.startswith(".")]
        for f in fn:
            if f.endswith(".import") or f.endswith(".uid"):
                continue
            files.append(os.path.relpath(os.path.join(dp, f), root).replace(os.sep, "/"))
    files.sort()
    delivered = collections.defaultdict(lambda: collections.defaultdict(set))
    images = {}
    unit_frames = collections.defaultdict(lambda: collections.defaultdict(list))
    stats = {}
    for rel in files:
        if rel in SIDE_FILES:
            continue
        path = os.path.join(root, rel)
        kind, aid, extra = classify(rel, by_kind)
        if kind is None:
            rep.add("FAIL", rel, "不认识的文件：路径或命名不符合规则（见 HD_ART_RULES.md 第 3 节）")
            continue
        if kind == "unit_meta":
            try:
                meta = json.load(open(path, encoding="utf-8"))
                if not isinstance(meta, dict) or any(k not in ("fps", "attack_hit_frame") for k in meta):
                    rep.add("FAIL", rel, "meta.json 只允许 fps 和 attack_hit_frame 两个键")
            except Exception as e:  # noqa: BLE001
                rep.add("FAIL", rel, "meta.json 读不了：%s" % e)
            continue
        if aid not in by_kind[kind]:
            rep.add("FAIL", rel, "清单里没有 %s “%s”" % (kind, aid))
            continue
        asset = by_kind[kind][aid]
        cfg = kinds[kind]
        check_size_kb(path, rel, cfg, rep)
        n_before = rep.count("FAIL")
        if kind == "prop":
            st = check_glb(path, rel, asset, cfg, rep)
            if st:
                stats[rel] = st
        else:
            im = open_image(path, rep, rel, cfg)
            if im is None:
                continue
            if kind in ("bg", "cg"):
                check_bg(im, rel, rep)
            elif kind == "chara":
                if extra["expr"] not in cfg["exprs"]:
                    rep.add("FAIL", rel, "表情名“%s”不在 %s 里" % (extra["expr"], "/".join(cfg["exprs"])))
                    continue
                check_chara(im, rel, rep)
                images[rel] = im
            elif kind == "face":
                check_face(im, rel, rep)
                images[rel] = im
            elif kind == "unit":
                states = cfg["states"]
                if extra["state"] not in states:
                    rep.add("FAIL", rel, "状态名“%s”不在 %s 里" % (extra["state"], "/".join(states)))
                    continue
                hgt = check_unit_frame(im, rel, rep, cfg["anchor"], extra["state"])
                unit_frames[aid][extra["state"]].append(extra["nn"])
                if extra["nn"] == 1:
                    images[rel] = im
                if hgt:
                    stats[rel] = {"height": hgt}
            elif kind == "tex":
                check_tex(im, rel, rep, "xy")
                images[rel] = im
            elif kind == "side":
                check_tex(im, rel, rep, "x")
                images[rel] = im
        if rep.count("FAIL") == n_before:
            rep.add("PASS", rel, "")
        delivered[kind][aid].add(rel)
    # expressions must match normal except the face
    for aid in by_kind["chara"]:
        n = images.get("chara/%s/normal.png" % aid)
        for ex in kinds["chara"]["exprs"][1:]:
            rel = "chara/%s/%s.png" % (aid, ex)
            if rel in images:
                if n is None:
                    rep.add("FAIL", rel, "有 %s 但没有 normal" % ex)
                else:
                    check_expr_pair(n, images[rel], rel, rep)
    # unit frames: contiguous numbering, required states
    for aid, sts in unit_frames.items():
        asset = by_kind["unit"][aid]
        req = asset.get("required_states", kinds["unit"]["required_states"])
        for s in req:
            if s not in sts:
                rep.add("FAIL", "unit/%s/" % aid, "缺少状态 %s（每个状态至少 1 帧：%s_01.png）" % (s, s))
        for s, nums in sts.items():
            nums = sorted(nums)
            if nums != list(range(1, len(nums) + 1)):
                rep.add("FAIL", "unit/%s/" % aid, "%s 的帧号不连续：%s（应从 01 开始连续）" % (s, nums))
    # sources
    src = load_sources(root, rep)
    real = [f for f in files if f not in SIDE_FILES and classify(f, by_kind)[0] not in (None, "unit_meta")]
    if real and src is None:
        rep.add("FAIL", "SOURCES.csv", "没有 SOURCES.csv：交了图就必须登记模型和素材来源（规则第 6 节）")
    elif src is not None:
        for f in real:
            if not any(fnmatch.fnmatch(f, pat) for pats in src for pat in pats):
                rep.add("FAIL", f, "SOURCES.csv 里没有哪一行的 asset_ids 覆盖这个文件")
    # coverage
    cov = collections.defaultdict(lambda: [0, 0, []])
    for a in data["assets"]:
        k, aid = a["kind"], a["id"]
        if k == "chara":
            done = "chara/%s/normal.png" % aid in delivered[k].get(aid, set())
        elif k == "unit":
            req = a.get("required_states", kinds["unit"]["required_states"])
            done = all(s in unit_frames.get(aid, {}) for s in req)
        else:
            done = bool(delivered[k].get(aid))
        c = cov[a["priority"]]
        c[1] += 1
        if done:
            c[0] += 1
        else:
            c[2].append("%s/%s" % (k, aid))
    # print
    order = {"FAIL": 0, "WARN": 1, "PASS": 2}
    for lvl, path, msg in sorted(rep.rows, key=lambda r: (order[r[0]], r[1])):
        if lvl == "PASS":
            continue
        print("[%s] %s  %s" % (lvl, path, msg))
    print()
    print("== 交付进度 ==")
    for p in sorted(cov):
        done, total, missing = cov[p]
        line = "%s：%d/%d 项已交" % (p, done, total)
        if missing and p == "P0":
            line += "（还缺：%s）" % "、".join(missing)
        print(line)
    print()
    print("结果：FAIL %d · WARN %d · PASS %d（按文件）" % (rep.count("FAIL"), rep.count("WARN"), rep.count("PASS")))
    if args.sheet:
        write_sheets(args.sheet, data, by_kind, images, root, unit_frames)
        print("对照表写到了 %s" % args.sheet)
    return 1 if rep.count("FAIL") else 0


# ---------------------------------------------------------------- contact sheets
def _font(size):
    try:
        return ImageFont.load_default(size=size)
    except TypeError:
        return ImageFont.load_default()


def _checker(w, h, s=16):
    im = Image.new("RGBA", (w, h), (200, 200, 200, 255))
    d = ImageDraw.Draw(im)
    for y in range(0, h, s):
        for x in range(0, w, s):
            if (x // s + y // s) % 2:
                d.rectangle([x, y, x + s - 1, y + s - 1], fill=(160, 160, 160, 255))
    return im


def _grid(cells, cols, cw, ch, title):
    rows = max(1, int(math.ceil(len(cells) / float(cols))))
    sheet = Image.new("RGBA", (cols * cw, rows * ch + 40), (32, 34, 40, 255))
    d = ImageDraw.Draw(sheet)
    d.text((10, 10), title, fill=(240, 240, 240, 255), font=_font(20))
    for i, (label, im) in enumerate(cells):
        x, y = (i % cols) * cw, 40 + (i // cols) * ch
        sheet.alpha_composite(im, (x, y))
        d.text((x + 6, y + ch - 22), label, fill=(255, 230, 120, 255), font=_font(16))
    return sheet


def write_sheets(out, data, by_kind, images, root, unit_frames):
    os.makedirs(out, exist_ok=True)
    # characters: normal + head-line band
    cells = []
    for aid in by_kind["chara"]:
        for ex in data["kinds"]["chara"]["exprs"]:
            im = images.get("chara/%s/%s.png" % (aid, ex))
            if im is None:
                continue
            bg = _checker(1200, 1800, 48)
            bg.alpha_composite(im)
            d = ImageDraw.Draw(bg)
            d.rectangle([0, 120, 1199, 200], outline=(0, 160, 255, 255), width=4)
            cells.append(("%s/%s" % (aid, ex), bg.resize((300, 450), Image.LANCZOS)))
    if cells:
        _grid(cells, 6, 300, 480, "chara (blue band = head line 120-200)").convert("RGB").save(os.path.join(out, "sheet_chara.png"))
    cells = []
    for aid in by_kind["face"]:
        im = images.get("face/%s.png" % aid)
        if im is not None:
            bg = _checker(512, 512, 32)
            bg.alpha_composite(im)
            cells.append((aid, bg.resize((200, 200), Image.LANCZOS)))
    if cells:
        _grid(cells, 8, 200, 230, "face").convert("RGB").save(os.path.join(out, "sheet_face.png"))
    # units: first frame of each state + mirrored idle, anchor cross
    cells = []
    ax, ay = data["kinds"]["unit"]["anchor"]
    for aid in by_kind["unit"]:
        sts = unit_frames.get(aid)
        if not sts:
            continue
        for s in data["kinds"]["unit"]["states"] + ["idle_mirror"]:
            src = s if s != "idle_mirror" else "idle"
            p = os.path.join(root, "unit", aid, "%s_01.png" % src)
            if not os.path.exists(p):
                continue
            im = Image.open(p).convert("RGBA")
            if s == "idle_mirror":
                im = im.transpose(Image.FLIP_LEFT_RIGHT)
            bg = _checker(384, 384, 24)
            d = ImageDraw.Draw(bg)
            d.ellipse([ax - 70, ay - 22, ax + 70, ay + 22], outline=(0, 140, 255, 255), width=3)
            bg.alpha_composite(im)
            d = ImageDraw.Draw(bg)
            d.line([ax - 14, ay, ax + 14, ay], fill=(255, 0, 0, 255), width=3)
            d.line([ax, ay - 14, ax, ay + 14], fill=(255, 0, 0, 255), width=3)
            cells.append(("%s %s x%d" % (aid, s, len(sts.get(src, []))), bg.resize((192, 192), Image.LANCZOS)))
    if cells:
        _grid(cells, 6, 192, 222, "unit (red cross = anchor; feet must sit on it)").convert("RGB").save(os.path.join(out, "sheet_unit.png"))
    # tiles: 2x2 to show seams
    cells = []
    for k in ("tex", "side"):
        for aid in by_kind[k]:
            im = images.get("tile/%s.png" % aid)
            if im is None:
                continue
            w, h = im.size
            t = Image.new("RGBA", (w * 2, h * 2))
            for yy in range(2):
                for xx in range(2):
                    t.paste(im.convert("RGBA"), (xx * w, yy * h))
            cells.append((aid, t.resize((256, int(256 * h / w)), Image.LANCZOS)))
    if cells:
        _grid(cells, 6, 256, 290, "tiles (2x2 tiled: no visible seams)").convert("RGB").save(os.path.join(out, "sheet_tile.png"))
    # backgrounds with the dialogue-box zone shaded
    cells = []
    for k in ("bg", "cg"):
        for f in sorted(os.listdir(os.path.join(root, k))) if os.path.isdir(os.path.join(root, k)) else []:
            if f.endswith(".import"):
                continue
            try:
                im = Image.open(os.path.join(root, k, f)).convert("RGBA").resize((480, 270), Image.LANCZOS)
            except Exception:  # noqa: BLE001
                continue
            ov = Image.new("RGBA", im.size, (0, 0, 0, 0))
            ImageDraw.Draw(ov).rectangle([0, 190, 479, 269], fill=(0, 0, 0, 120))
            im.alpha_composite(ov)
            cells.append((f, im))
    if cells:
        _grid(cells, 4, 480, 300, "bg / cg (shaded = dialogue box)").convert("RGB").save(os.path.join(out, "sheet_bg.png"))


if __name__ == "__main__":
    sys.exit(main())
