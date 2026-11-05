#!/usr/bin/env python3
# Renders wm/ocean/maps/preview_<chapter>.png for each sheet of maps/world.json, for review only.
# Geo views are drawn over the Natural Earth land polygons in wm/geo/<base>.json; canvas views on a plain sea.
import json, math, os, sys
from PIL import Image, ImageDraw, ImageFont
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
GEO = os.path.join(os.path.dirname(ROOT), "geo")
FONT = ImageFont.truetype("/usr/share/fonts/truetype/wqy/wqy-zenhei.ttc", 18)
SMALL = ImageFont.truetype("/usr/share/fonts/truetype/wqy/wqy-zenhei.ttc", 14)
COL = {"story": (214, 170, 60), "battle": (200, 60, 50), "elite": (160, 40, 160), "boss": (120, 0, 0), "event": (60, 120, 200),
       "camp": (60, 150, 80), "supply": (150, 110, 60), "shop": (230, 130, 30), "slot": (130, 130, 130), "branch": (0, 0, 0)}
W, H = 1920, 1080


def proj_fn(view):
    base = json.load(open(os.path.join(GEO, view["base"] + ".json"), encoding="utf-8"))
    v = base["view"]
    sc, yt, lon0 = v["scale"], v["y_top"], math.radians(v["lon_min"])
    if v["projection"] == "mercator":
        fy = lambda la: sc * (yt - math.log(math.tan(math.pi / 4 + math.radians(la) / 2)))
    else:
        fy = lambda la: sc * (yt - 1.25 * math.log(math.tan(math.pi / 4 + 0.4 * math.radians(la))))
    fx = lambda lo: sc * (math.radians(lo) - lon0)
    lo1, lo2 = view["lon"][0] / 100, view["lon"][1] / 100
    la1, la2 = view["lat"][0] / 100, view["lat"][1] / 100
    x1, x2, y1, y2 = fx(lo1), fx(lo2), fy(la2), fy(la1)
    s = min(W / (x2 - x1), H / (y2 - y1))
    ox, oy = (W - (x2 - x1) * s) / 2, (H - (y2 - y1) * s) / 2
    to_canvas = lambda bx, by: (ox + (bx - x1) * s, oy + (by - y1) * s)
    return base, (lambda lo, la: to_canvas(fx(lo), fy(la))), to_canvas


def main():
    m = json.load(open(os.path.join(ROOT, "maps", "world.json"), encoding="utf-8"))
    for sh in m["sheets"]:
        view = m["views"][sh["view"]]
        img = Image.new("RGB", (W, H), (190, 205, 215))
        d = ImageDraw.Draw(img)
        if view["proj"] == "canvas":
            pos = {n["id"]: tuple(n["xy"]) for n in sh["nodes"]}
        else:
            base, P, C = proj_fn(view)
            for ring in base["land"]:
                pts = [C(ring[i], ring[i + 1]) for i in range(0, len(ring), 2)]
                if len(pts) > 2:
                    d.polygon(pts, fill=(226, 214, 186), outline=(160, 150, 120))
            for r in base.get("rivers", []):
                pts = [C(r["pts"][i], r["pts"][i + 1]) for i in range(0, len(r["pts"]), 2)]
                if len(pts) > 1:
                    d.line(pts, fill=(120, 150, 190), width=2)
            pos = {n["id"]: P(n["geo"][0] / 100, n["geo"][1] / 100) for n in sh["nodes"]}
        nodes = {n["id"]: n for n in sh["nodes"]}
        for l in sh["links"]:
            a, b = pos[l["a"]], pos[l["b"]]
            voy = "voyage_days" in l
            d.line([a, b], fill=(40, 70, 140) if voy else (90, 80, 70), width=3 if voy else 2)
            mx, my = (a[0] + b[0]) / 2, (a[1] + b[1]) / 2
            d.text((mx + 3, my - 9), ("%d天" % l["voyage_days"]) if voy else str(l["legs"]), fill=(20, 20, 20), font=SMALL)
        for nid, (x, y) in pos.items():
            n = nodes[nid]
            r = 14 if n.get("scene") or n["type"] in ("boss",) else 10
            ring = (255, 255, 255) if n.get("phase") != "campaign" else (255, 40, 40)
            d.ellipse([x - r, y - r, x + r, y + r], fill=COL[n["type"]], outline=ring, width=3)
            tag = n["label"] + ("·" + n["scene"] if n.get("scene") else "") + ("·" + n["role"] if n.get("role") else "")
            d.text((x + r + 3, y - 10), tag, fill=(10, 10, 10), font=SMALL)
        d.text((20, 16), "%s  view=%s  days_max=%d  stamps=%d  boss=%s  interlude=%s" % (sh["chapter"], sh["view"], sh["days_max"], sh["stamps_need"], sh["boss"], sh["interlude"]), fill=(0, 0, 0), font=FONT)
        legend = "  ".join("%s" % k for k in COL)
        x = 20
        for k, c in COL.items():
            d.ellipse([x, 50, x + 14, 64], fill=c)
            d.text((x + 18, 48), k, fill=(0, 0, 0), font=SMALL)
            x += 90
        d.text((x + 10, 48), "红圈 = 战役段节点；蓝线 = 航程（天）；灰线 = 陆路/近海（行军点）", fill=(0, 0, 0), font=SMALL)
        out = os.path.join(ROOT, "maps", "preview_%s.png" % sh["chapter"])
        img.save(out)
        print("wrote", out)


if __name__ == "__main__":
    main()
