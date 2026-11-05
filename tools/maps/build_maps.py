#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""build_maps.py - world-map geometry for the Napoleon line (trunk / conquest / ocean / Monte Cristo).

Reads Natural Earth GeoJSON (public domain, https://www.naturalearthdata.com) from SRC
(default: ./src next to this script) and writes, to OUT (default: this script's folder):

    europe.json   Napoleonic theatre (trunk + continue-conquest branch)    Mercator
    world.json    whole world (Twenty Thousand Leagues branch)             Miller cylindrical
    med.json      France / Italy / W. Mediterranean / Ionian / Aegean     Mercator (10m detail)
    gazetteer.json  named places, lon/lat + canvas x,y in every view that contains them
    preview_europe.png, preview_world.png, preview_med.png

Run:   python3 -I build_maps.py [SRC] [OUT]

Needs only python3 (+ Pillow for the previews).  No shapely: rectangle clipping (with proper
splitting into several rings), Douglas-Peucker and integer ring repair are implemented here.

Output conventions (all three views):
  * canvas pixels, origin top-left, y down, integers.
  * "land", "lakes", "ice": list of closed rings, each a flat array [x0,y0,x1,y1,...]; the closing
    point is NOT repeated.  Rings are simple (no self-intersection / no touching after rounding),
    have no duplicate or collinear consecutive vertices, and all share one orientation: positive
    shoelace sum  sum(x_i*y_(i+1) - x_(i+1)*y_i) > 0  in the y-down canvas (i.e. clockwise on screen).
    Holes are never used: the Caspian (a hole in the Eurasia polygon) is emitted as a lake.
  * "rivers": list of {"id","name","name_zh","minor","pts":[flat polyline]}; a river may have
    several entries (branches / pieces cut by the frame) sharing one id.
  * "islets": named small islands that matter to the story but would vanish at this scale;
    drawn exaggerated around their own centre ("scale" > 1), or hand-placed ("approx": true),
    or invented ("fictional": true).  Draw them on top of "land".
"""
import json
import math
import os
import sys
from collections import defaultdict

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.abspath(sys.argv[1]) if len(sys.argv) > 1 else os.path.join(HERE, 'src')
OUT = os.path.abspath(sys.argv[2]) if len(sys.argv) > 2 else HERE
SOURCE = 'Natural Earth (public domain)'

# ----------------------------------------------------------------------------------------------
# data loading
# ----------------------------------------------------------------------------------------------
_cache = {}


def load(name):
    if name not in _cache:
        with open(os.path.join(SRC, name + '.geojson'), encoding='utf-8') as fh:
            _cache[name] = json.load(fh)
    return _cache[name]


def _open_ring(r):
    r = [(float(c[0]), float(c[1])) for c in r]
    if len(r) > 1 and r[0] == r[-1]:
        r = r[:-1]
    return r


def iter_polygons(name):
    """yield (props, exterior, [holes]); rings are lists of (lon, lat) without closing duplicate."""
    for f in load(name)['features']:
        g = f.get('geometry')
        if not g:
            continue
        if g['type'] == 'Polygon':
            polys = [g['coordinates']]
        elif g['type'] == 'MultiPolygon':
            polys = g['coordinates']
        else:
            continue
        for p in polys:
            rings = [_open_ring(r) for r in p]
            yield f.get('properties') or {}, rings[0], rings[1:]


def iter_lines(name):
    for f in load(name)['features']:
        g = f.get('geometry')
        if not g:
            continue
        if g['type'] == 'LineString':
            ls = [g['coordinates']]
        elif g['type'] == 'MultiLineString':
            ls = g['coordinates']
        else:
            continue
        for l in ls:
            if len(l) >= 2:
                yield f.get('properties') or {}, [(float(c[0]), float(c[1])) for c in l]


def lonlat_bbox(r):
    xs = [p[0] for p in r]
    ys = [p[1] for p in r]
    return min(xs), max(xs), min(ys), max(ys)


# ----------------------------------------------------------------------------------------------
# projections
# ----------------------------------------------------------------------------------------------
class View:
    """Cylindrical projection onto an integer canvas.  x = s*(lon_rad - lon_min_rad),
    y = s*(Y(lat_max) - Y(lat)); s = width / (lon_max_rad - lon_min_rad)  [px per radian].
    mercator: Y = ln(tan(pi/4 + lat/2));   miller: Y = 1.25 * ln(tan(pi/4 + 0.4*lat)).
    height = round(s * (Y(lat_max) - Y(lat_min_nominal))); lat_min is then re-derived from it."""

    def __init__(self, key, kind, lon_min, lon_max, lat_min, lat_max, width, **opt):
        self.key, self.kind = key, kind
        self.lon_min, self.lon_max, self.lat_max = lon_min, lon_max, lat_max
        self.lat_min_nominal = lat_min
        self.width = width
        self.lam0 = math.radians(lon_min)
        self.s = width / (math.radians(lon_max) - self.lam0)
        self.ytop = self.Y(lat_max)
        self.height = int(round(self.s * (self.ytop - self.Y(lat_min))))
        self.lat_min = self.inv(0.0, float(self.height))[1]
        self.opt = opt

    def Y(self, lat):
        if self.kind == 'mercator':
            lat = max(-89.5, min(89.5, lat))
            return math.log(math.tan(math.pi / 4 + math.radians(lat) / 2))
        lat = max(-90.0, min(90.0, lat))
        return 1.25 * math.log(math.tan(math.pi / 4 + 0.4 * math.radians(lat)))

    def fwd(self, lon, lat):
        return (self.s * (math.radians(lon) - self.lam0), self.s * (self.ytop - self.Y(lat)))

    def inv(self, x, y):
        lon = math.degrees(x / self.s + self.lam0)
        Yv = self.ytop - y / self.s
        if self.kind == 'mercator':
            lat = math.degrees(2 * math.atan(math.exp(Yv)) - math.pi / 2)
        else:
            lat = math.degrees(2.5 * (math.atan(math.exp(0.8 * Yv)) - math.pi / 4))
        return lon, lat

    def inside_ll(self, lon, lat, margin=0.0):
        return (self.lon_min - margin <= lon <= self.lon_max + margin and
                self.lat_min - margin <= lat <= self.lat_max + margin)

    def bbox_hits(self, bb, margin=1.0):
        return not (bb[1] < self.lon_min - margin or bb[0] > self.lon_max + margin or
                    bb[3] < self.lat_min - margin or bb[2] > self.lat_max + margin)

    def params(self):
        if self.kind == 'mercator':
            yf = 'scale * (y_top - ln(tan(pi/4 + radians(lat)/2)))'
            yi = 'lat = degrees(2*atan(exp(y_top - y/scale)) - pi/2)'
        else:
            yf = 'scale * (y_top - 1.25*ln(tan(pi/4 + 0.4*radians(lat))))'
            yi = 'lat = degrees(2.5*(atan(exp(0.8*(y_top - y/scale))) - pi/4))'
        d = {
            'projection': self.kind,
            'lon_min': self.lon_min, 'lon_max': self.lon_max,
            'lat_min': round(self.lat_min, 6), 'lat_max': self.lat_max,
            'width': self.width, 'height': self.height,
            'scale': round(self.s, 9),
            'y_top': round(self.ytop, 12),
            'x_formula': 'scale * (radians(lon) - radians(lon_min))',
            'y_formula': yf,
            'inverse': 'lon = degrees(x/scale + radians(lon_min)); ' + yi,
            'units': 'canvas px, origin top-left, y down; integers',
            'orientation': 'rings clockwise on screen: sum(x_i*y_(i+1) - x_(i+1)*y_i) > 0',
            'x_wraps': bool(self.opt.get('wraps', False)),
        }
        if self.opt.get('wraps'):
            d['x_wrap_note'] = 'x + width is the same meridian; draw routes that cross the 180th meridian twice (at x and x +/- width)'
        d['px_per_degree_lon'] = round(self.width / (self.lon_max - self.lon_min), 4)
        return d


# ----------------------------------------------------------------------------------------------
# geometry helpers (float)
# ----------------------------------------------------------------------------------------------
def ring_area2(r):
    a = 0.0
    n = len(r)
    for i in range(n):
        x0, y0 = r[i]
        x1, y1 = r[(i + 1) % n]
        a += x0 * y1 - x1 * y0
    return a


def point_in_ring(x, y, r):
    inside = False
    n = len(r)
    j = n - 1
    for i in range(n):
        xi, yi = r[i]
        xj, yj = r[j]
        if (yi > y) != (yj > y):
            xc = xi + (y - yi) * (xj - xi) / (yj - yi)
            if x < xc:
                inside = not inside
        j = i
    return inside


def _sh_halfplane(ring, axis, val, keep_ge):
    """Sutherland-Hodgman single half-plane (fallback for degenerate split cases)."""
    def s(p):
        return (p[axis] - val) if keep_ge else (val - p[axis])
    out = []
    n = len(ring)
    for i in range(n):
        a = ring[i]
        b = ring[(i + 1) % n]
        sa, sb = s(a), s(b)
        if sa >= 0:
            out.append(a)
        if (sa >= 0) != (sb >= 0):
            t = sa / (sa - sb)
            p = [a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t]
            p[axis] = val
            out.append(tuple(p))
    return [out] if len(out) >= 3 else []


STATS = defaultdict(int)


def clip_halfplane(ring, axis, val, keep_ge):
    """Clip a simple ring by one half-plane; returns a LIST of rings (the inside part may be split
    into several pieces).  Inside chains are re-joined along the cut line by pairing the sorted
    crossing points (Weiler-Atherton specialised to a straight line)."""
    n = len(ring)
    if n < 3:
        return []
    sv = [((p[axis] - val) if keep_ge else (val - p[axis])) for p in ring]
    if min(sv) >= 0:
        return [ring]
    if max(sv) < 0:
        return []
    k = next(i for i in range(n) if sv[i] < 0)
    ring = ring[k:] + ring[:k]
    sv = sv[k:] + sv[:k]

    def cut(a, b, sa, sb):
        t = sa / (sa - sb)
        p = [a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t]
        p[axis] = val
        return tuple(p)

    chains = []
    cur = None
    for i in range(n):
        a = ring[i]
        b = ring[(i + 1) % n]
        sa = sv[i]
        sb = sv[(i + 1) % n]
        if sa < 0:
            if sb >= 0:
                cur = [cut(a, b, sa, sb)]
                if sb > 0:
                    cur.append(b)
        else:
            if sb >= 0:
                cur.append(b)
            else:
                if sa > 0:
                    cur.append(cut(a, b, sa, sb))
                chains.append(cur)
                cur = None
    chains = [c for c in chains if len(c) >= 2]
    if not chains:
        return []
    u = 1 - axis
    ev = []
    for ci, c in enumerate(chains):
        ev.append((c[0][u], 0, ci))    # entry
        ev.append((c[-1][u], 1, ci))   # exit
    ev.sort()
    nxt = {}
    ok = len(ev) % 2 == 0
    if ok:
        for i in range(0, len(ev), 2):
            e1, e2 = ev[i], ev[i + 1]
            if e1[1] == e2[1]:
                ok = False
                break
            ex, en = (e1, e2) if e1[1] == 1 else (e2, e1)
            nxt[ex[2]] = en[2]
    if not ok or len(nxt) != len(chains):
        STATS['clip_fallback'] += 1
        return _sh_halfplane(ring, axis, val, keep_ge)
    out = []
    seen = set()
    for start in range(len(chains)):
        if start in seen:
            continue
        r = []
        j = start
        while j not in seen:
            seen.add(j)
            r.extend(chains[j])
            j = nxt[j]
        if len(r) >= 3:
            out.append(r)
    return out


def clip_rect(ring, W, H):
    rings = [ring]
    for axis, val, ge in ((0, 0.0, True), (0, float(W), False), (1, 0.0, True), (1, float(H), False)):
        nr = []
        for r in rings:
            nr.extend(clip_halfplane(r, axis, val, ge))
        rings = nr
        if not rings:
            break
    return rings


def clip_polyline(pts, W, H):
    """Liang-Barsky per segment; returns list of polylines inside [0,W]x[0,H]."""
    pieces = []
    cur = []
    for i in range(len(pts) - 1):
        (x0, y0), (x1, y1) = pts[i], pts[i + 1]
        dx, dy = x1 - x0, y1 - y0
        t0, t1 = 0.0, 1.0
        okseg = True
        for p, q in ((-dx, x0), (dx, W - x0), (-dy, y0), (dy, H - y0)):
            if p == 0:
                if q < 0:
                    okseg = False
                    break
            else:
                r = q / p
                if p < 0:
                    if r > t1:
                        okseg = False
                        break
                    t0 = max(t0, r)
                else:
                    if r < t0:
                        okseg = False
                        break
                    t1 = min(t1, r)
        if not okseg:
            if cur:
                pieces.append(cur)
                cur = []
            continue
        a = (x0 + dx * t0, y0 + dy * t0)
        b = (x0 + dx * t1, y0 + dy * t1)
        if not cur or t0 > 0:
            if cur:
                pieces.append(cur)
            cur = [a]
        cur.append(b)
        if t1 < 1:
            pieces.append(cur)
            cur = []
    if cur:
        pieces.append(cur)
    return [p for p in pieces if len(p) >= 2]


def dp_open(pts, eps):
    n = len(pts)
    if n <= 2:
        return pts[:]
    keep = [False] * n
    keep[0] = keep[-1] = True
    eps2 = eps * eps
    stack = [(0, n - 1)]
    while stack:
        i, j = stack.pop()
        if j <= i + 1:
            continue
        ax, ay = pts[i]
        bx, by = pts[j]
        dx, dy = bx - ax, by - ay
        L2 = dx * dx + dy * dy
        best, bi = -1.0, -1
        for k in range(i + 1, j):
            px, py = pts[k]
            if L2 == 0:
                d = (px - ax) ** 2 + (py - ay) ** 2
            else:
                t = ((px - ax) * dx + (py - ay) * dy) / L2
                t = 0.0 if t < 0 else (1.0 if t > 1 else t)
                qx, qy = ax + t * dx, ay + t * dy
                d = (px - qx) ** 2 + (py - qy) ** 2
            if d > best:
                best, bi = d, k
        if best > eps2:
            keep[bi] = True
            stack.append((i, bi))
            stack.append((bi, j))
    return [pts[k] for k in range(n) if keep[k]]


def dp_ring(ring, eps):
    n = len(ring)
    if n <= 4 or eps <= 0:
        return ring[:]
    x0, y0 = ring[0]
    far = max(range(n), key=lambda i: (ring[i][0] - x0) ** 2 + (ring[i][1] - y0) ** 2)
    if far == 0:
        return ring[:]
    a = dp_open(ring[:far + 1], eps)
    b = dp_open(ring[far:] + [ring[0]], eps)
    return a[:-1] + b[:-1]


# ----------------------------------------------------------------------------------------------
# integer ring cleaning + repair
# ----------------------------------------------------------------------------------------------
def _cross(a, b, c):
    return (b[0] - a[0]) * (c[1] - b[1]) - (b[1] - a[1]) * (c[0] - b[0])


def clean_ring(pts):
    out = []
    for p in pts:
        out.append(p)
        while True:
            if len(out) >= 2 and out[-1] == out[-2]:
                out.pop()
                continue
            if len(out) >= 3 and _cross(out[-3], out[-2], out[-1]) == 0:
                del out[-2]
                continue
            break
    changed = True
    while changed and len(out) >= 3:
        changed = False
        if out[-1] == out[0]:
            out.pop()
            changed = True
        elif _cross(out[-2], out[-1], out[0]) == 0:
            out.pop()
            changed = True
        elif _cross(out[-1], out[0], out[1]) == 0:
            out.pop(0)
            changed = True
    return out if len(out) >= 3 else []


def _orient(a, b, c):
    v = (b[0] - a[0]) * (c[1] - a[1]) - (b[1] - a[1]) * (c[0] - a[0])
    return (v > 0) - (v < 0)


def _on_seg(a, b, p):
    return min(a[0], b[0]) <= p[0] <= max(a[0], b[0]) and min(a[1], b[1]) <= p[1] <= max(a[1], b[1])


def seg_hit(p1, p2, p3, p4):
    d1 = _orient(p3, p4, p1)
    d2 = _orient(p3, p4, p2)
    d3 = _orient(p1, p2, p3)
    d4 = _orient(p1, p2, p4)
    if d1 * d2 < 0 and d3 * d4 < 0:
        return True
    if d1 == 0 and _on_seg(p3, p4, p1):
        return True
    if d2 == 0 and _on_seg(p3, p4, p2):
        return True
    if d3 == 0 and _on_seg(p1, p2, p3):
        return True
    if d4 == 0 and _on_seg(p1, p2, p4):
        return True
    return False


def find_bad(ring, cell=12):
    n = len(ring)
    grid = defaultdict(list)
    for i in range(n):
        a = ring[i]
        b = ring[(i + 1) % n]
        for cx in range(min(a[0], b[0]) // cell, max(a[0], b[0]) // cell + 1):
            for cy in range(min(a[1], b[1]) // cell, max(a[1], b[1]) // cell + 1):
                grid[(cx, cy)].append(i)
    bad = set()
    checked = set()
    for lst in grid.values():
        m = len(lst)
        if m < 2:
            continue
        for x in range(m):
            i = lst[x]
            a1 = ring[i]
            a2 = ring[(i + 1) % n]
            for y in range(x + 1, m):
                j = lst[y]
                dij = abs(i - j)
                if dij == 1 or dij == n - 1:
                    continue
                key = (i, j) if i < j else (j, i)
                if key in checked:
                    continue
                checked.add(key)
                if seg_hit(a1, a2, ring[j], ring[(j + 1) % n]):
                    bad.add(key)
    return bad


def repair_ring(ring, max_iter=80):
    ring = clean_ring(ring)
    for _ in range(max_iter):
        if len(ring) < 3:
            return []
        bad = find_bad(ring)
        if not bad:
            return ring
        n = len(ring)
        rm = set()
        for (i, j) in sorted(bad):
            cands = [i, (i + 1) % n, j, (j + 1) % n]
            if any(c in rm for c in cands):
                continue
            best = min(cands, key=lambda c: abs(_cross(ring[c - 1], ring[c], ring[(c + 1) % n])))
            rm.add(best)
        STATS['repair_removed'] += len(rm)
        ring = clean_ring([p for k, p in enumerate(ring) if k not in rm])
    STATS['repair_gave_up'] += 1
    return []


def iarea2(r):
    a = 0
    n = len(r)
    for i in range(n):
        a += r[i][0] * r[(i + 1) % n][1] - r[(i + 1) % n][0] * r[i][1]
    return a


def finalize_ring(fr, eps):
    """float ring (canvas) -> simplified, rounded, repaired integer ring (clockwise on screen)."""
    s = dp_ring(fr, eps)
    ir = [(int(round(x)), int(round(y))) for x, y in s]
    ir = repair_ring(ir)
    if len(ir) < 3:
        return []
    if iarea2(ir) < 0:
        ir.reverse()
    if iarea2(ir) == 0:
        return []
    return ir


def flat(ir):
    out = []
    for x, y in ir:
        out.append(x)
        out.append(y)
    return out


# ----------------------------------------------------------------------------------------------
# view configuration
# ----------------------------------------------------------------------------------------------
VIEWS = {
    'europe': View('europe', 'mercator', -12.0, 56.0, 24.0, 63.0, 2400),
    'world': View('world', 'miller', -180.0, 180.0, -78.0, 82.0, 2400, wraps=True),
    'med': View('med', 'mercator', -6.0, 30.0, 34.0, 51.5, 2400),
}

CFG = {
    'europe': dict(land='ne_50m_land', eps=0.55, min_area=3.0, islet_min=5.0,
                   lake_src=[('ne_50m_lakes', None)], lake_min=5.0, lake_eps=0.5, river_eps=0.6),
    'world': dict(land='ne_50m_land', eps=0.6, min_area=4.0, islet_min=4.0,
                  lake_src=[('ne_50m_lakes', None)], lake_min=14.0, lake_eps=0.6, river_eps=0.7,
                  ice='ne_50m_antarctic_ice_shelves_polys'),
    'med': dict(land='ne_10m_land', eps=0.5, min_area=2.5, islet_min=6.0,
                lake_src=[('ne_10m_lakes', None), ('ne_10m_lakes_europe', None)], lake_min=2.0,
                lake_eps=0.45, river_eps=0.5),
}

# islands to keep (never dropped as specks; exaggerated into "islets" when smaller than islet_min px)
KEEP = {
    'europe': [
        ('Corsica', 9.1, 42.15), ('Sardinia', 9.0, 40.1), ('Sicily', 14.1, 37.6), ('Malta', 14.43, 35.89),
        ('Gozo', 14.25, 36.04), ('Elba', 10.25, 42.78), ('Crete', 24.9, 35.25), ('Cyprus', 33.2, 35.0),
        ('Mallorca', 2.95, 39.6), ('Menorca', 4.1, 39.95), ('Ibiza', 1.42, 38.98), ('Corfu', 19.85, 39.6),
        ('Cephalonia', 20.55, 38.22), ('Zakynthos', 20.85, 37.78), ('Rhodes', 28.0, 36.2),
        ('Euboea', 23.8, 38.6), ('Ireland', -8.0, 53.3), ('Great Britain', -1.5, 53.0),
        ('Isle of Wight', -1.3, 50.67), ('Zealand', 11.8, 55.5), ('Gotland', 18.5, 57.5),
        ('Ile de Re', -1.4, 46.2), ('Ile d\'Oleron', -1.3, 45.93), ('Bornholm', 14.9, 55.12),
        ('Rugen', 13.4, 54.45), ('Heligoland', 7.88, 54.18),
    ],
    'world': [
        ('St Helena', -5.71, -15.96), ('Ascension', -14.36, -7.94), ('Robinson Crusoe I. (Juan Fernandez)', -78.83, -33.62),
        ('Tahiti', -149.42, -17.67), ('Moorea', -149.83, -17.54), ('Moskenesoya (Lofoten)', 13.0, 67.95),
        ('Flakstadoya (Lofoten)', 13.25, 68.1), ('Vestvagoya (Lofoten)', 13.8, 68.2), ('Austvagoya (Lofoten)', 14.5, 68.35),
        ('Malta', 14.43, 35.89), ('Elba', 10.25, 42.78), ('Corsica', 9.1, 42.15), ('Crete', 24.9, 35.25),
        ('Cyprus', 33.2, 35.0), ('Madeira', -16.95, 32.75), ('Tenerife', -16.6, 28.27),
        ('Gran Canaria', -15.6, 27.95), ('Sao Miguel (Azores)', -25.5, 37.78), ('Pico (Azores)', -28.3, 38.45),
        ('Terceira (Azores)', -27.22, 38.71), ('Santiago (Cape Verde)', -23.6, 15.05),
        ('Tristan da Cunha', -12.29, -37.11), ('Bermuda', -64.75, 32.31), ('Easter Island', -109.35, -27.12),
        ('Pitcairn', -130.1, -25.07), ('Vanikoro', 166.85, -11.65), ('Mauritius', 57.55, -20.25),
        ('Reunion', 55.53, -21.12), ('Zanzibar', 39.3, -6.1), ('Socotra', 53.8, 12.47), ('Oahu', -158.0, 21.47),
        ('Hawaii', -155.5, 19.6), ('Guam', 144.78, 13.45), ('Kerguelen', 69.5, -49.35), ('South Georgia', -36.6, -54.3),
        ('Viti Levu', 178.0, -17.8), ('Upolu (Samoa)', -171.75, -13.9), ('Tongatapu', -175.2, -21.17),
        ('Galapagos (Isabela)', -91.1, -0.8), ('Sri Lanka (Ceylon)', 80.7, 7.8), ('Iceland', -19.0, 64.9),
        ('Faroe', -6.9, 62.0), ('Svalbard', 16.0, 78.6),
    ],
    'med': [
        ('Montecristo', 10.305, 42.338), ('Elba', 10.25, 42.78), ('Pianosa', 10.075, 42.59), ('Giglio', 10.9, 42.355),
        ('Giannutri', 11.1, 42.255), ('Capraia', 9.82, 43.04), ('Gorgona', 9.905, 43.435), ('Malta', 14.43, 35.89),
        ('Gozo', 14.25, 36.04), ('Comino', 14.335, 36.01), ('Lampedusa', 12.58, 35.51), ('Pantelleria', 11.98, 36.78),
        ('Corsica', 9.1, 42.15), ('Sardinia', 9.0, 40.1), ('Sicily', 14.1, 37.6), ('Capri', 14.23, 40.55),
        ('Ischia', 13.9, 40.73), ('Ponza', 12.96, 40.9), ('Lipari', 14.95, 38.48), ('Stromboli', 15.21, 38.79),
        ('Ustica', 13.18, 38.71), ('Porquerolles', 6.2, 43.0), ('Port-Cros', 6.39, 43.005), ('Levant', 6.47, 43.03),
        ('Sainte-Marguerite (Lerins)', 7.05, 43.52), ('Mallorca', 2.95, 39.6), ('Menorca', 4.1, 39.95),
        ('Ibiza', 1.42, 38.98), ('Formentera', 1.47, 38.7), ('Cabrera', 2.93, 39.14), ('Corfu', 19.85, 39.6),
        ('Paxos', 20.18, 39.2), ('Lefkada', 20.65, 38.72), ('Ithaca', 20.7, 38.38), ('Cephalonia', 20.55, 38.22),
        ('Zakynthos', 20.85, 37.78), ('Crete', 24.9, 35.25), ('Chios', 26.0, 38.38), ('Lesbos', 26.25, 39.2),
        ('Samos', 26.8, 37.73), ('Tenedos', 26.04, 39.82), ('Djerba', 10.9, 33.8), ('Asinara', 8.27, 41.07),
        ('La Maddalena', 9.4, 41.22), ('Caprera', 9.47, 41.21), ('San Pietro', 8.27, 39.14),
        ('Ile de Re', -1.4, 46.2), ('Ile d\'Oleron', -1.3, 45.93), ('Belle-Ile', -3.18, 47.33),
        ('Ile d\'Yeu', -2.35, 46.71), ('Noirmoutier', -2.25, 46.98), ('Jersey', -2.13, 49.21),
        ('Guernsey', -2.58, 49.45), ('Isle of Wight', -1.3, 50.67), ('Ile d\'Aix', -1.174, 46.012),
    ],
}

# hand-placed islets that Natural Earth does not contain (approximate outlines, lon/lat)
HAND_ISLETS = {
    'med': [
        # Frioul archipelago off Marseille: drawn 2.5x larger, anchored on the Chateau d'If so the
        # castle keeps its true position and the exaggeration grows out to sea (west / south-west).
        dict(name='Ratonneau (Frioul)', id='ratonneau', anchor=(5.3254, 43.2799), scale=2.5, pts=[
            (5.2968, 43.2852), (5.3005, 43.2886), (5.3062, 43.2902), (5.3125, 43.2896), (5.3172, 43.2868),
            (5.3188, 43.2838), (5.3150, 43.2817), (5.3082, 43.2813), (5.3030, 43.2822), (5.2990, 43.2830)]),
        dict(name='Pomegues (Frioul)', id='pomegues', anchor=(5.3254, 43.2799), scale=2.5, pts=[
            (5.3045, 43.2785), (5.3078, 43.2772), (5.3040, 43.2722), (5.2975, 43.2648), (5.2915, 43.2598),
            (5.2876, 43.2612), (5.2918, 43.2680), (5.2980, 43.2745)]),
        dict(name="Chateau d'If", id='if', anchor=None, scale=None, min_px=4.5, pts=[
            (5.3241, 43.2806), (5.3262, 43.2808), (5.3271, 43.2799), (5.3262, 43.2789), (5.3243, 43.2791)]),
    ],
}

# invented islands for the ocean storyline (fictional; generated blobs, deterministic)
FICTIONAL_ISLETS = {
    'world': [
        dict(name='New Elba (fictional)', id='new_elba', lon=-118.5, lat=-39.5, r_px=5.0, seed=7),
        dict(name='Lincoln Island (fictional, Verne)', id='lincoln_island', lon=-150.5, lat=-34.95, r_px=4.0, seed=11),
    ],
}

# rivers: id -> (name, name_zh, minor, [(source, NE name), ...])
B10 = 'ne_10m_rivers_lake_centerlines'
B50 = 'ne_50m_rivers_lake_centerlines'
EU10 = 'ne_10m_rivers_europe'
RIVERS = {
    'europe': [
        ('rhine', 'Rhine', '莱茵河', False, [(B10, 'Rhein'), (B10, 'Rhin'), (B10, 'Rhine'), (B10, 'Waal'), (B10, 'Lek'), (B10, 'IJssel')]),
        ('danube', 'Danube', '多瑙河', False, [(B10, 'Donau'), (B10, 'Danube'), (B10, 'Bratul Chillia'), (B10, 'Bratul Sulina'), (B10, 'Bratul Sfintu Gheorghe')]),
        ('po', 'Po', '波河', False, [(B10, 'Po')]),
        ('elbe', 'Elbe', '易北河', False, [(B10, 'Elbe')]),
        ('oder', 'Oder', '奥得河', False, [(B10, 'Oder')]),
        ('vistula', 'Vistula', '维斯瓦河', False, [(B10, 'Vistula')]),
        ('neman', 'Neman (Niemen)', '涅曼河', False, [(B10, 'Neman')]),
        ('dnieper', 'Dnieper', '第聂伯河', False, [(B10, 'Dnipro'), (B10, 'Dnepre'), (EU10, 'Dnepr')]),
        ('berezina', 'Berezina', '别列津纳河', False, [(EU10, 'Byarezina')]),
        ('seine', 'Seine', '塞纳河', False, [(B10, 'Seine')]),
        ('loire', 'Loire', '卢瓦尔河', False, [(B10, 'Loire')]),
        ('rhone', 'Rhône', '罗讷河', False, [(B10, 'Rhône'), (B10, 'Rhne')]),
        ('ebro', 'Ebro', '埃布罗河', False, [(B10, 'Ebro')]),
        ('tagus', 'Tagus', '塔霍河', False, [(B10, 'Tejo'), (B10, 'Tajo')]),
        ('nile', 'Nile', '尼罗河', False, [(B10, 'Nile'), (B10, 'Rosetta Branch'), (B10, 'Damietta Branch')]),
        ('volga', 'Volga', '伏尔加河', False, [(B10, 'Volga')]),
        ('thames', 'Thames', '泰晤士河', False, [(B10, 'Thames')]),
        ('douro', 'Douro', '杜罗河', True, [(B10, 'Duero')]),
        ('garonne', 'Garonne', '加龙河', True, [(B10, 'Garonne')]),
        ('adige', 'Adige', '阿迪杰河', True, [(B10, 'Adige')]),
        ('mincio', 'Mincio', '明乔河', True, [(B10, 'Mincio')]),
        ('adda', 'Adda', '阿达河', True, [(EU10, 'Adda')]),
        ('saale', 'Saale', '萨勒河', True, [(EU10, 'Saale')]),
        ('weisse_elster', 'Weisse Elster', '白埃尔斯特河', True, [(EU10, 'Weisse Elster')]),
        ('jordan', 'Jordan', '约旦河', True, [(B10, 'Jordan')]),
    ],
    'med': [
        ('rhone', 'Rhône', '罗讷河', False, [(B10, 'Rhône'), (B10, 'Rhne')]),
        ('seine', 'Seine', '塞纳河', False, [(B10, 'Seine')]),
        ('loire', 'Loire', '卢瓦尔河', False, [(B10, 'Loire')]),
        ('po', 'Po', '波河', False, [(B10, 'Po')]),
        ('tiber', 'Tiber', '台伯河', False, [(B10, 'Tevere')]),
        ('arno', 'Arno', '阿诺河', False, [(EU10, 'Arno')]),
        ('durance', 'Durance', '迪朗斯河', True, [(B10, 'Durance')]),
        ('garonne', 'Garonne', '加龙河', True, [(B10, 'Garonne')]),
        ('marne', 'Marne', '马恩河', True, [(B10, 'Marne')]),
        ('adige', 'Adige', '阿迪杰河', True, [(B10, 'Adige')]),
        ('ticino', 'Ticino', '提契诺河', True, [(B10, 'Ticino')]),
        ('tanaro', 'Tanaro', '塔纳罗河', True, [(EU10, 'Tanaro')]),
        ('rhine', 'Rhine', '莱茵河', True, [(B10, 'Rhein'), (B10, 'Rhin'), (B10, 'Rhine')]),
        ('danube', 'Danube', '多瑙河', True, [(B10, 'Donau'), (B10, 'Danube')]),
        ('ebro', 'Ebro', '埃布罗河', True, [(B10, 'Ebro')]),
    ],
    'world': [],
}

# lakes: anachronisms (20th-century reservoirs / shrunken modern shorelines) are dropped.
LAKE_DROP_WORDS = ('reservoir', 'vodokhran', 'embalse', 'barrage', 'nasser', 'tharthar', 'razzaza',
                   'sarygamysh', 'aral', 'kremaston', 'tisza', 'mandra', 'volta', 'kariba', 'kainji',
                   'cahora', 'smallwood', 'bratsk', 'krasnoyarsk', 'sayano', 'ust-ilim', 'zeya',
                   'bukhtarma', 'kapchagay', 'nurek', 'toktogul', 'qadisiyah', 'assad', 'keban', 'ataturk',
                   'kakhovka', 'kremenchuk', 'kyiv', 'kaniv', 'dnipro', 'rybinsk', 'gorky', 'cheboksary',
                   'kuybyshev', 'samara', 'saratov', 'volgograd', 'tsimlyansk', 'kama', 'votkinsk',
                   'guri', 'sobradinho', 'tucurui', 'itaipu', 'furnas', 'serra da mesa', 'balbina',
                   'mead', 'powell', 'sakakawea', 'oahe', 'fort peck', 'williston', 'kinbasket',
                   'caniapiscau', 'robert-bourassa', 'la grande', 'manicouagan', 'gouin', 'nipigon reservoir')
# med view: only historical natural lakes / lagoons, matched by centroid (lon, lat) and named here
MED_LAKES = [
    ('Lac Léman (Lake Geneva)', 6.55, 46.43), ('Lac de Neuchâtel', 6.85, 46.9), ('Bodensee (Lake Constance)', 9.35, 47.62),
    ('Untersee', 9.0, 47.7), ('Lago Maggiore', 8.62, 45.95), ('Lago di Como', 9.26, 46.0), ('Lago di Garda', 10.68, 45.65),
    ("Lago d'Iseo", 10.07, 45.73), ('Lago di Lugano', 8.97, 45.97), ('Lago Trasimeno', 12.1, 43.13),
    ('Lago di Bolsena', 11.93, 42.6), ('Lago di Bracciano', 12.23, 42.12), ('Lac du Bourget', 5.86, 45.73),
    ('Lac d\'Annecy', 6.17, 45.85), ('Vierwaldstättersee', 8.45, 47.0), ('Zürichsee', 8.7, 47.25), ('Thunersee', 7.72, 46.69),
    ('Brienzersee', 7.95, 46.73), ('Bielersee', 7.17, 47.08), ('Zugersee', 8.48, 47.13), ('Chiemsee', 12.45, 47.88),
    ('Starnberger See', 11.32, 47.9), ('Ammersee', 11.12, 48.0), ('Attersee', 13.55, 47.87), ('Neusiedler See', 16.75, 47.8),
    ('Lake Balaton', 17.75, 46.85), ('Lake Scutari (Skadar)', 19.3, 42.2), ('Lake Ohrid', 20.75, 41.0),
    ('Lake Prespa', 21.05, 40.88), ('Small Prespa', 21.1, 40.75), ('Lake of Janina (Pamvotis)', 20.88, 39.67),
    ('Lake Trichonida', 21.55, 38.57), ('Lake Vegoritida', 21.78, 40.75), ('Lake Volvi', 23.45, 40.68),
    ('Lake Koroneia', 23.15, 40.68), ('Étang de Berre', 5.15, 43.47), ('Étang de Thau', 3.6, 43.4),
    ('Étang de Vaccarès', 4.6, 43.53), ('Étang de Carcans-Hourtin', -1.13, 45.15), ('Étang de Cazaux', -1.17, 44.5),
    ('Étang de Biscarrosse', -1.17, 44.37), ('Lake Iznik', 29.5, 40.43), ('Lake Ulubat', 28.6, 40.18),
    ('Lake Manyas (Kuş)', 28.0, 40.2), ('Lake Bafa', 27.45, 37.5), ('Lake Köyceğiz', 28.65, 36.95),
    ('Valli di Comacchio', 12.15, 44.62), ('Lago di Lesina', 15.42, 41.88), ('Lago di Varano', 15.73, 41.88),
    ('Lake Sapanca', 30.25, 40.72), ('Lake Doiran', 22.75, 41.21), ('Lake Vistonida', 25.1, 41.05),
]

# approximate early-19th-century Aral Sea (NE only has the shrunken modern remnants)
ARAL_HISTORIC = [(58.30, 45.60), (58.40, 46.10), (58.70, 46.40), (59.40, 46.30), (59.80, 46.65), (60.30, 46.85),
                 (61.00, 46.80), (61.60, 46.55), (61.90, 46.20), (61.30, 45.95), (61.00, 45.40), (60.70, 44.80),
                 (60.20, 44.20), (59.60, 43.70), (59.00, 43.50), (58.50, 43.60), (58.20, 44.10), (58.20, 44.90)]


# ----------------------------------------------------------------------------------------------
# builders
# ----------------------------------------------------------------------------------------------
def project_ring(v, r):
    return [v.fwd(lon, lat) for lon, lat in r]


def build_polys(v, src_rings, eps, min_area, keep=None, islet_min=0.0, name_for=None):
    """src_rings: list of lon/lat rings.  Returns (rings, islets, protected_names)."""
    W, H = v.width, v.height
    pieces = []
    for r in src_rings:
        if not v.bbox_hits(lonlat_bbox(r)):
            continue
        pr = project_ring(v, r)
        for c in clip_rect(pr, W, H):
            pieces.append(c)
    # match keep points to pieces
    prot = {}
    if keep:
        pbb = []
        for c in pieces:
            xs = [p[0] for p in c]
            ys = [p[1] for p in c]
            pbb.append((min(xs), max(xs), min(ys), max(ys)))
        for name, lon, lat in keep:
            if not v.inside_ll(lon, lat):
                continue
            x, y = v.fwd(lon, lat)
            best, bd = None, 1e18
            for i, c in enumerate(pieces):
                b = pbb[i]
                if not (b[0] - 3 <= x <= b[1] + 3 and b[2] - 3 <= y <= b[3] + 3):
                    continue
                if point_in_ring(x, y, c):
                    d = -abs(ring_area2(c))  # prefer the smallest containing piece? no: the containing one
                    d = 0.0
                else:
                    d = min((p[0] - x) ** 2 + (p[1] - y) ** 2 for p in c)
                    if d > 2.5 ** 2:
                        continue
                if best is None or d < bd:
                    best, bd = i, d
            if best is not None and best not in prot:
                prot[best] = name
            elif best is None:
                STATS['keep_missing:%s:%s' % (v.key, name)] += 1
    rings, islets = [], []
    for i, c in enumerate(pieces):
        area = abs(ring_area2(c)) / 2.0
        if i in prot:
            xs = [p[0] for p in c]
            ys = [p[1] for p in c]
            size = max(max(xs) - min(xs), max(ys) - min(ys))
            if size < islet_min:
                f = min(40.0, islet_min / max(size, 0.25))
                cx = sum(xs) / len(xs)
                cy = sum(ys) / len(ys)
                sc = [(cx + (p[0] - cx) * f, cy + (p[1] - cy) * f) for p in c]
                ir = finalize_ring(sc, 0.35)
                if ir:
                    islets.append({'name': prot[i], 'scale': round(f, 2), 'center': [int(round(cx)), int(round(cy))],
                                   'pts': flat(ir)})
                continue
            ir = finalize_ring(c, min(eps, max(0.2, size / 12.0)))
            if ir:
                rings.append(ir)
            continue
        if area < min_area:
            STATS['specks_dropped:%s' % v.key] += 1
            continue
        ir = finalize_ring(c, eps)
        if ir and abs(iarea2(ir)) / 2.0 >= min_area * 0.5:
            rings.append(ir)
        else:
            STATS['collapsed:%s' % v.key] += 1
    return rings, islets


def blob(v, lon, lat, r_px, seed, n=11):
    cx, cy = v.fwd(lon, lat)
    pts = []
    rnd = seed * 9301 + 49297
    for k in range(n):
        rnd = (rnd * 9301 + 49297) % 233280
        jitter = 0.65 + 0.55 * (rnd / 233280.0)
        a = 2 * math.pi * k / n
        pts.append((cx + math.cos(a) * r_px * jitter * 1.25, cy + math.sin(a) * r_px * jitter))
    return pts, (cx, cy)


def build_rivers(v, spec, eps):
    out = []
    W, H = v.width, v.height
    by_src = defaultdict(list)
    for src, nm in [(s, n) for _, _, _, _, lst in spec for s, n in lst]:
        by_src[src].append(nm)
    lines = defaultdict(list)  # (src,name) -> list of polylines
    for src, names in by_src.items():
        ns = set(names)
        for props, pts in iter_lines(src):
            nm = props.get('name')
            if nm in ns:
                lines[(src, nm)].append(pts)
    for rid, name, name_zh, minor, lst in spec:
        polys = []
        for key in lst:
            if not lines.get(key):
                STATS['river_missing:%s:%s' % (v.key, key[1])] += 1
            polys.extend(lines.get(key, []))
        polys = chain_lines(polys, tol=0.02)
        parts = []
        for pl in polys:
            if not v.bbox_hits(lonlat_bbox(pl), margin=0.5):
                continue
            pp = [v.fwd(lon, lat) for lon, lat in pl]
            for piece in clip_polyline(pp, W, H):
                s = dp_open(piece, eps)
                ip = []
                for x, y in s:
                    q = (int(round(x)), int(round(y)))
                    if not ip or ip[-1] != q:
                        ip.append(q)
                if len(ip) >= 2:
                    L = sum(math.hypot(ip[k + 1][0] - ip[k][0], ip[k + 1][1] - ip[k][1]) for k in range(len(ip) - 1))
                    if L >= 4:
                        parts.append((L, ip))
        parts.sort(key=lambda t: -t[0])
        for L, ip in parts:
            out.append({'id': rid, 'name': name, 'name_zh': name_zh, 'minor': minor, 'pts': flat(ip)})
    return out


def chain_lines(polys, tol):
    polys = [list(p) for p in polys if len(p) >= 2]

    def close(a, b):
        return abs(a[0] - b[0]) <= tol and abs(a[1] - b[1]) <= tol
    merged = True
    while merged:
        merged = False
        for i in range(len(polys)):
            if merged:
                break
            for j in range(len(polys)):
                if i == j:
                    continue
                a, b = polys[i], polys[j]
                if close(a[-1], b[0]):
                    polys[i] = a + b[1:]
                elif close(a[-1], b[-1]):
                    polys[i] = a + b[::-1][1:]
                elif close(a[0], b[-1]):
                    polys[i] = b + a[1:]
                elif close(a[0], b[0]):
                    polys[i] = b[::-1] + a[1:]
                else:
                    continue
                del polys[j]
                merged = True
                break
    return polys


def lake_ok_world_eu(props):
    nm = (props.get('name') or '').lower()
    if (props.get('featurecla') or '').lower() == 'reservoir':
        return False
    return not any(w in nm for w in LAKE_DROP_WORDS)


def build_lakes(v, cfg, caspian_rings):
    rings = []
    names = []
    srcs = []
    if v.key == 'med':
        cand = []
        for src, _ in cfg['lake_src']:
            for props, ext, holes in iter_polygons(src):
                if not v.bbox_hits(lonlat_bbox(ext), margin=0.2):
                    continue
                if (props.get('featurecla') or '').lower() == 'reservoir':
                    continue
                cand.append(ext)
        used = {}
        for ext in cand:
            cx = sum(p[0] for p in ext) / len(ext)
            cy = sum(p[1] for p in ext) / len(ext)
            best, bd = None, 0.35 ** 2
            for nm, lx, ly in MED_LAKES:
                d = (cx - lx) ** 2 + ((cy - ly) * 1.3) ** 2
                if d < bd:
                    best, bd = nm, d
            if best is None:
                continue
            # the same lake may exist in two sources: keep the one with more vertices
            if best in used and len(used[best]) >= len(ext):
                continue
            used[best] = ext
        for nm, ext in used.items():
            srcs.append((nm, ext))
    else:
        for src, _ in cfg['lake_src']:
            for props, ext, holes in iter_polygons(src):
                if not lake_ok_world_eu(props):
                    continue
                srcs.append((props.get('name') or '', ext))
        if v.key == 'world':
            srcs.append(('Aral Sea (approx. 19th-century shoreline, hand-drawn)', ARAL_HISTORIC))
    for nm, r in caspian_rings:
        srcs.append((nm, r))
    for nm, ext in srcs:
        rs, _ = build_polys(v, [ext], cfg['lake_eps'], cfg['lake_min'])
        for r in rs:
            rings.append(flat(r))
            names.append(nm)
    return rings, names


def build_view(key):
    v = VIEWS[key]
    cfg = CFG[key]
    land_src = []
    caspian = []
    for props, ext, holes in iter_polygons(cfg['land']):
        land_src.append(ext)
        for h in holes:
            bb = lonlat_bbox(h)
            if 46 < (bb[0] + bb[1]) / 2 < 55 and 36 < (bb[2] + bb[3]) / 2 < 48:
                caspian.append(('Caspian Sea', h))
            else:
                caspian.append(('', h))
    land, islets = build_polys(v, land_src, cfg['eps'], cfg['min_area'], keep=KEEP.get(key), islet_min=cfg['islet_min'])
    for hi in HAND_ISLETS.get(key, []):
        pr = [v.fwd(lon, lat) for lon, lat in hi['pts']]
        cx = sum(p[0] for p in pr) / len(pr)
        cy = sum(p[1] for p in pr) / len(pr)
        if hi.get('anchor'):
            ax, ay = v.fwd(*hi['anchor'])
            f = hi['scale']
        else:
            xs = [p[0] for p in pr]
            ys = [p[1] for p in pr]
            size = max(max(xs) - min(xs), max(ys) - min(ys))
            f = hi['min_px'] / max(size, 0.05)
            ax, ay = cx, cy
        sc = [(ax + (p[0] - ax) * f, ay + (p[1] - ay) * f) for p in pr]
        ir = finalize_ring(sc, 0.3)
        if ir:
            islets.append({'name': hi['name'], 'id': hi['id'], 'approx': True, 'scale': round(f, 2),
                           'center': [int(round(cx)), int(round(cy))], 'pts': flat(ir),
                           'note': 'not in Natural Earth; hand-placed approximate outline, exaggerated'})
    for fi in FICTIONAL_ISLETS.get(key, []):
        pts, (cx, cy) = blob(v, fi['lon'], fi['lat'], fi['r_px'], fi['seed'])
        ir = finalize_ring(pts, 0.3)
        if ir:
            islets.append({'name': fi['name'], 'id': fi['id'], 'fictional': True, 'scale': 1.0,
                           'center': [int(round(cx)), int(round(cy))], 'pts': flat(ir)})
    lakes, lake_names = build_lakes(v, cfg, [c for c in caspian if c[0]])
    rivers = build_rivers(v, RIVERS.get(key, []), cfg['river_eps'])
    data = {
        'view': dict(v.params(), id=key),
        'land': [flat(r) for r in land],
        'lakes': lakes,
        'lake_names': lake_names,
        'rivers': rivers,
        'islets': islets,
        'source': SOURCE,
    }
    if cfg.get('ice'):
        ice, _ = build_polys(v, [ext for _, ext, _ in iter_polygons(cfg['ice'])], cfg['eps'], cfg['min_area'])
        data['ice'] = [flat(r) for r in ice]
        data['ice_note'] = 'Antarctic ice shelves (Natural Earth ice-shelf polygons); draw under land'
    data['source_files'] = sorted(set([cfg['land']] + [s for s, _ in cfg['lake_src']] +
                                      [s for _, _, _, _, lst in RIVERS.get(key, []) for s, _ in lst] +
                                      ([cfg['ice']] if cfg.get('ice') else [])))
    data['notes'] = VIEW_NOTES[key]
    return v, data


VIEW_NOTES = {
    'europe': ['Napoleonic theatre, trunk + continue-conquest branch. Mercator (conformal).',
               'Modern coastline: Zuiderzee polders and IJsselmeer reflect the 20th century; '
               '20th-century reservoirs are removed from lakes.',
               'Caspian Sea is a lake entry (it is a hole in the Natural Earth Eurasia polygon).'],
    'world': ['Twenty Thousand Leagues branch. Miller cylindrical, centred on Greenwich; x wraps at the 180th meridian.',
              'Antarctica land = grounding line; ice shelves are in "ice". The Aral Sea is a hand-drawn historical '
              'approximation; modern reservoirs removed.',
              'Small story islands are exaggerated in "islets" (scale > 1); New Elba and Lincoln Island are fictional blobs.'],
    'med': ['Monte Cristo branch. Mercator, Natural Earth 1:10m coast.',
            "Frioul islands and the Chateau d'If are not in Natural Earth: hand-placed approximate outlines in islets, "
            "exaggerated (If kept at its true position, Frioul grown 2.5x out to sea).",
            'Lakes restricted to natural lakes / lagoons that existed c. 1815-1840 (allow-list).'],
}


# ----------------------------------------------------------------------------------------------
# gazetteer
# ----------------------------------------------------------------------------------------------
T, C, O, M = 'trunk', 'conquest', 'ocean', 'cristo'
# id, name (with diacritics), ascii label, name_zh, lon, lat, branches, kind, extra
PLACES = [
    # --- trunk / conquest ---
    ('marseille', 'Marseille', 'Marseille', '马赛', 5.3698, 43.2965, [T, M], 'city', {}),
    ('toulon', 'Toulon', 'Toulon', '土伦', 5.9280, 43.1242, [T, M], 'city', {'note': 'Siege of Toulon 1793; bagne (Caderousse, Andrea)'}),
    ('paris', 'Paris', 'Paris', '巴黎', 2.3522, 48.8566, [T, C, M], 'capital', {}),
    ('nice', 'Nice', 'Nice', '尼斯', 7.2620, 43.7102, [T], 'city', {}),
    ('ajaccio', 'Ajaccio', 'Ajaccio', '阿雅克肖', 8.7386, 41.9192, [T, M], 'city', {'note': 'Corsica; Napoleon born 1769'}),
    ('montenotte', 'Montenotte', 'Montenotte', '蒙特诺特', 8.383, 44.400, [T], 'battle', {'date': '1796-04-12'}),
    ('lodi', 'Lodi', 'Lodi', '洛迪', 9.5035, 45.3138, [T], 'battle', {'date': '1796-05-10', 'note': 'bridge over the Adda'}),
    ('milan', 'Milan', 'Milan', '米兰', 9.1900, 45.4642, [T, C], 'city', {}),
    ('mantua', 'Mantua', 'Mantua', '曼托瓦', 10.7914, 45.1564, [T], 'fortress', {'date': '1796-07..1797-02'}),
    ('arcole', 'Arcole', 'Arcole', '阿尔科莱', 11.2786, 45.3567, [T], 'battle', {'date': '1796-11-15..17'}),
    ('rivoli', 'Rivoli', 'Rivoli', '里沃利', 10.8125, 45.5714, [T], 'battle', {'date': '1797-01-14'}),
    ('la_favorita', 'La Favorita', 'La Favorita', '拉法沃里塔', 10.800, 45.183, [T], 'battle', {'date': '1797-01-16', 'note': 'Favorita palace north of Mantua'}),
    ('campo_formio', 'Campo Formio', 'Campo Formio', '坎波福尔米奥', 13.1600, 46.0200, [T], 'treaty', {'date': '1797-10-17'}),
    ('alexandria', 'Alexandria', 'Alexandria', '亚历山大港', 29.9187, 31.2001, [T], 'city', {'date': '1798-07-02'}),
    ('cairo', 'Cairo', 'Cairo', '开罗', 31.2357, 30.0444, [T], 'city', {}),
    ('pyramids', 'Pyramids (Giza)', 'Pyramids', '金字塔（吉萨）', 31.1342, 29.9792, [T], 'battle', {'date': '1798-07-21'}),
    ('aboukir', 'Aboukir', 'Aboukir', '阿布基尔', 30.0640, 31.3220, [T], 'battle', {'date': '1798-08-01 (Nile) / 1799-07-25'}),
    ('jaffa', 'Jaffa', 'Jaffa', '雅法', 34.7522, 32.0504, [T], 'battle', {'date': '1799-03-07'}),
    ('acre', 'Acre', 'Acre', '阿卡', 35.069, 32.923, [T], 'siege', {'date': '1799-03..05'}),
    ('mount_tabor', 'Mount Tabor', 'Mount Tabor', '他泊山', 35.3906, 32.6869, [T], 'battle', {'date': '1799-04-16'}),
    ('fort_bard', 'Fort Bard', 'Fort Bard', '巴德堡', 7.7448, 45.6069, [T], 'fortress', {'date': '1800-05'}),
    ('montebello', 'Montebello', 'Montebello', '蒙特贝洛', 9.103, 44.999, [T], 'battle', {'date': '1800-06-09'}),
    ('marengo', 'Marengo', 'Marengo', '马伦戈', 8.680, 44.890, [T], 'battle', {'date': '1800-06-14'}),
    ('boulogne', 'Boulogne', 'Boulogne', '布洛涅', 1.6147, 50.7264, [T, C], 'camp', {'note': 'Armée d\'Angleterre camp 1803-05'}),
    ('trafalgar', 'Cape Trafalgar', 'Trafalgar', '特拉法尔加角', -6.0350, 36.1830, [T, C], 'naval battle', {'date': '1805-10-21'}),
    ('ulm', 'Ulm', 'Ulm', '乌尔姆', 9.9876, 48.4011, [T], 'battle', {'date': '1805-10'}),
    ('hollabrunn', 'Hollabrunn', 'Hollabrunn', '霍拉布伦', 16.0794, 48.5627, [T], 'battle', {'date': '1805-11-16'}),
    ('vienna', 'Vienna', 'Vienna', '维也纳', 16.3738, 48.2082, [T, C], 'capital', {}),
    ('austerlitz', 'Austerlitz', 'Austerlitz', '奥斯特利茨', 16.762, 49.128, [T], 'battle', {'date': '1805-12-02', 'note': 'Pratzen heights'}),
    ('jena', 'Jena', 'Jena', '耶拿', 11.5892, 50.9271, [T], 'battle', {'date': '1806-10-14'}),
    ('auerstedt', 'Auerstedt', 'Auerstedt', '奥尔施泰特', 11.583, 51.100, [T], 'battle', {'date': '1806-10-14'}),
    ('berlin', 'Berlin', 'Berlin', '柏林', 13.4050, 52.5200, [T, C], 'capital', {}),
    ('warsaw', 'Warsaw', 'Warsaw', '华沙', 21.0122, 52.2297, [T, C], 'capital', {}),
    ('eylau', 'Eylau', 'Eylau', '埃劳', 20.6403, 54.3858, [T], 'battle', {'date': '1807-02-08'}),
    ('friedland', 'Friedland', 'Friedland', '弗里德兰', 21.0164, 54.4428, [T], 'battle', {'date': '1807-06-14'}),
    ('tilsit', 'Tilsit', 'Tilsit', '提尔西特', 21.8864, 55.0814, [T], 'treaty', {'date': '1807-07-07', 'note': 'raft on the Niemen'}),
    ('copenhagen', 'Copenhagen', 'Copenhagen', '哥本哈根', 12.5683, 55.6761, [T, C], 'capital', {}),
    ('stockholm', 'Stockholm', 'Stockholm', '斯德哥尔摩', 18.0686, 59.3293, [C], 'capital', {}),
    ('st_petersburg', 'St Petersburg', 'St Petersburg', '圣彼得堡', 30.3351, 59.9343, [C], 'capital', {}),
    ('lisbon', 'Lisbon', 'Lisbon', '里斯本', -9.1393, 38.7223, [T, C], 'capital', {}),
    ('madrid', 'Madrid', 'Madrid', '马德里', -3.7038, 40.4168, [T, C], 'capital', {}),
    ('somosierra', 'Somosierra', 'Somosierra', '索莫谢拉', -3.581, 41.133, [T], 'battle', {'date': '1808-11-30'}),
    ('saragossa', 'Saragossa', 'Saragossa', '萨拉戈萨', -0.8891, 41.6488, [T], 'siege', {'date': '1808-1809'}),
    ('eckmuhl', 'Eckmühl', 'Eckmuhl', '埃克米尔', 12.183, 48.833, [T], 'battle', {'date': '1809-04-22'}),
    ('aspern_essling', 'Aspern-Essling', 'Aspern-Essling', '阿斯佩恩-埃斯灵', 16.505, 48.218, [T], 'battle', {'date': '1809-05-21..22'}),
    ('wagram', 'Wagram', 'Wagram', '瓦格拉姆', 16.5644, 48.2994, [T], 'battle', {'date': '1809-07-05..06'}),
    ('kovno', 'Kovno (Niemen crossing)', 'Kovno', '考纳斯（涅曼河渡口）', 23.9036, 54.8985, [T], 'crossing', {'date': '1812-06-24'}),
    ('vilna', 'Vilna', 'Vilna', '维尔纳', 25.2797, 54.6872, [T], 'city', {}),
    ('smolensk', 'Smolensk', 'Smolensk', '斯摩棱斯克', 32.0401, 54.7818, [T], 'battle', {'date': '1812-08-16..18'}),
    ('borodino', 'Borodino', 'Borodino', '博罗季诺', 35.824, 55.523, [T], 'battle', {'date': '1812-09-07'}),
    ('moscow', 'Moscow', 'Moscow', '莫斯科', 37.6173, 55.7558, [T, C], 'city', {'date': '1812-09-14'}),
    ('berezina', 'Studianka (Berezina crossing)', 'Berezina', '斯图江卡（别列津纳河渡口）', 28.350, 54.333, [T], 'crossing', {'date': '1812-11-26..29'}),
    ('lutzen', 'Lützen', 'Lutzen', '吕岑', 12.1415, 51.2588, [T], 'battle', {'date': '1813-05-02'}),
    ('dresden', 'Dresden', 'Dresden', '德累斯顿', 13.7373, 51.0504, [T], 'battle', {'date': '1813-08-26..27'}),
    ('leipzig', 'Leipzig', 'Leipzig', '莱比锡', 12.3731, 51.3397, [T], 'battle', {'date': '1813-10-16..19'}),
    ('montmirail', 'Montmirail', 'Montmirail', '蒙米赖', 3.5389, 48.8708, [T], 'battle', {'date': '1814-02-11'}),
    ('fontainebleau', 'Fontainebleau', 'Fontainebleau', '枫丹白露', 2.7016, 48.4047, [T, M], 'palace', {'date': '1814-04-06 abdication'}),
    ('portoferraio', 'Portoferraio (Elba)', 'Portoferraio', '费拉约港（厄尔巴岛）', 10.3270, 42.8130, [T, M], 'island', {'date': '1814-05..1815-02-26'}),
    ('golfe_juan', 'Golfe-Juan', 'Golfe-Juan', '儒安湾', 7.0740, 43.5680, [T], 'landing', {'date': '1815-03-01'}),
    ('laffrey', 'Laffrey', 'Laffrey', '拉弗雷', 5.767, 45.006, [T], 'event', {'date': '1815-03-07', 'note': 'Prairie de la Rencontre: "Soldiers, here is your Emperor"'}),
    ('grenoble', 'Grenoble', 'Grenoble', '格勒诺布尔', 5.7245, 45.1885, [T], 'city', {'date': '1815-03-07'}),
    ('lyon', 'Lyon', 'Lyon', '里昂', 4.8357, 45.7640, [T], 'city', {'date': '1815-03-10'}),
    ('quatre_bras', 'Quatre Bras', 'Quatre Bras', '四臂村', 4.4540, 50.5714, [T], 'battle', {'date': '1815-06-16'}),
    ('ligny', 'Ligny', 'Ligny', '林尼', 4.578, 50.512, [T], 'battle', {'date': '1815-06-16'}),
    ('waterloo', 'Waterloo', 'Waterloo', '滑铁卢', 4.4044, 50.6787, [T, C], 'battle', {'date': '1815-06-18', 'note': 'battlefield (Mont-Saint-Jean); branch point'}),
    ('brussels', 'Brussels', 'Brussels', '布鲁塞尔', 4.3517, 50.8503, [T, C], 'city', {}),
    ('antwerp', 'Antwerp', 'Antwerp', '安特卫普', 4.4025, 51.2194, [C], 'port', {}),
    ('amsterdam', 'Amsterdam', 'Amsterdam', '阿姆斯特丹', 4.9041, 52.3676, [C], 'capital', {}),
    ('london', 'London', 'London', '伦敦', -0.1278, 51.5074, [C, O], 'capital', {}),
    ('dover', 'Dover', 'Dover', '多佛尔', 1.3134, 51.1279, [C], 'port', {}),
    ('naples', 'Naples', 'Naples', '那不勒斯', 14.2681, 40.8518, [T, C, M], 'capital', {}),
    ('constantinople', 'Constantinople', 'Constantinople', '君士坦丁堡', 28.9784, 41.0082, [C, M], 'capital', {}),
    ('rochefort', 'Rochefort', 'Rochefort', '罗什福尔', -0.9590, 45.9420, [T, O], 'port', {'date': '1815-07'}),
    ('ile_d_aix', "Île d'Aix", 'Ile d\'Aix', '艾克斯岛', -1.1747, 46.0128, [T, O], 'island', {'date': '1815-07-15', 'note': 'Napoleon boards HMS Bellerophon off the island (Basque Roads)'}),
    # --- ocean (Twenty Thousand Leagues branch) ---
    ('plymouth', 'Plymouth', 'Plymouth', '普利茅斯', -4.1427, 50.3755, [O], 'port', {'date': '1815-07-26..08-04', 'note': 'Bellerophon at anchor'}),
    ('st_helena', 'St Helena', 'St Helena', '圣赫勒拿岛', -5.708, -15.965, [O], 'island', {}),
    ('jamestown', 'Jamestown (St Helena)', 'Jamestown', '詹姆斯敦（圣赫勒拿）', -5.7181, -15.9244, [O], 'port', {'date': '1815-10-15'}),
    ('longwood', 'Longwood (St Helena)', 'Longwood', '朗伍德', -5.6836, -15.9450, [O], 'house', {}),
    ('ascension', 'Ascension', 'Ascension', '阿森松岛', -14.4132, -7.9267, [O], 'island', {}),
    ('cape_town', 'Cape Town', 'Cape Town', '开普敦', 18.4241, -33.9249, [O], 'port', {}),
    ('rio', 'Rio de Janeiro', 'Rio de Janeiro', '里约热内卢', -43.1729, -22.9068, [O], 'port', {}),
    ('cape_horn', 'Cape Horn', 'Cape Horn', '合恩角', -67.2667, -55.9833, [O], 'cape', {}),
    ('juan_fernandez', 'Juan Fernández (Robinson Crusoe I.)', 'Juan Fernandez', '胡安·费尔南德斯群岛', -78.830, -33.640, [O], 'island', {}),
    ('tahiti', 'Tahiti (Papeete)', 'Tahiti', '塔希提', -149.5696, -17.5350, [O], 'island', {}),
    ('new_elba', 'New Elba', 'New Elba (fict.)', '新厄尔巴岛', -118.5, -39.5, [O], 'island', {'fictional': True, 'note': 'invented; empty South Pacific in the westerlies, ~1500 km from Easter Island'}),
    ('vigo_bay', 'Vigo Bay (Rande)', 'Vigo Bay', '维哥湾', -8.72, 42.26, [O], 'bay', {'note': '1702 treasure galleons (Verne II.8)'}),
    ('atlantis', 'Atlantis', 'Atlantis (fict.)', '亚特兰蒂斯', -20.0, 35.0, [O], 'ruin', {'fictional': True, 'note': 'Verne II.9; seabed SW of Portugal'}),
    ('greenwich', 'Thames / Greenwich', 'Greenwich', '泰晤士河·格林尼治', -0.0077, 51.4826, [O], 'river', {}),
    ('maelstrom', 'Lofoten / Maelstrom (Moskstraumen)', 'Maelstrom', '罗弗敦·大漩涡', 12.80, 67.80, [O], 'sea', {'note': 'Verne II.22'}),
    ('antarctic_ice', 'Antarctic ice barrier (Larsen shelf)', 'Antarctic ice', '南极冰障', -60.0, -67.6, [O], 'ice', {'note': 'Verne II.13-16 ice bank; the pole itself is off the map (lat -78 bottom edge)'}),
    ('torres_strait', 'Torres Strait', 'Torres Strait', '托雷斯海峡', 142.30, -10.20, [O], 'strait', {'note': 'Verne I.20-22 (Gueboroar)'}),
    ('suez', 'Suez', 'Suez', '苏伊士', 32.5498, 29.9668, [O], 'port', {}),
    ('arabian_tunnel', 'Arabian Tunnel', 'Arabian Tunnel (fict.)', '阿拉伯隧道', 32.45, 30.50, [O], 'tunnel', {'fictional': True, 'note': 'Verne II.4-5: under the isthmus, Gulf of Suez to Pelusium'}),
    ('crete', 'Crete', 'Crete', '克里特岛', 24.90, 35.25, [O], 'island', {'note': 'Verne II.6 (Nicolas of Cape Matapan)'}),
    ('ceylon', 'Ceylon (Manaar pearl banks)', 'Ceylon', '锡兰（马纳尔珍珠场）', 79.80, 8.70, [O], 'sea', {'note': 'Verne II.2-3'}),
    ('sea_of_japan', 'Sea of Japan', 'Sea of Japan', '日本海', 135.0, 40.0, [O], 'sea', {}),
    ('crespo_island', 'Crespo Island', 'Crespo I. (fict.)', '克雷斯波岛', -167.83, 32.67, [O], 'island', {'fictional': True, 'note': 'Verne I.14 submarine forest'}),
    ('vanikoro', 'Vanikoro', 'Vanikoro', '瓦尼科罗岛', 166.85, -11.65, [O], 'island', {'note': 'La Perouse wreck (Verne I.19)'}),
    ('sargasso', 'Sargasso Sea', 'Sargasso Sea', '马尾藻海', -55.0, 29.0, [O], 'sea', {}),
    ('lincoln_island', 'Lincoln Island', 'Lincoln I. (fict.)', '林肯岛', -150.5, -34.95, [O], 'island', {'fictional': True, 'note': "Verne, The Mysterious Island: 34°57'S 150°30'W"}),
    # --- Monte Cristo branch ---
    ('marseille_old_port', 'Marseille, Old Port', 'Old Port', '马赛旧港', 5.3700, 43.2950, [M], 'port', {'date': '1815-02-24 Pharaon arrives'}),
    ('catalans', 'Les Catalans (Marseille)', 'Catalans', '加泰罗尼亚人村', 5.3532, 43.2906, [M], 'quarter', {'note': "Mercédès' village"}),
    ('chateau_d_if', "Château d'If", "Chateau d'If", '伊夫堡', 5.3254, 43.2799, [M], 'prison', {'date': '1815-03 .. 1829-02'}),
    ('montecristo', 'Île de Montecristo', 'Montecristo', '基督山岛', 10.3100, 42.3333, [M], 'island', {'note': "Spada treasure (Faria's half-letter)"}),
    ('livorno', 'Livorno', 'Livorno', '里窝那', 10.3106, 43.5485, [M], 'port', {}),
    ('genoa', 'Genoa', 'Genoa', '热那亚', 8.9463, 44.4056, [M], 'port', {}),
    ('rome', 'Rome', 'Rome', '罗马', 12.4964, 41.9028, [M], 'city', {'note': 'Carnival, Luigi Vampa'}),
    ('champs_elysees', 'Paris, 30 avenue des Champs-Élysées', 'Champs-Elysees', '香榭丽舍大街30号', 2.3075, 48.8698, [M], 'house', {}),
    ('auteuil', 'Auteuil (rue de la Fontaine)', 'Auteuil', '奥特伊', 2.2700, 48.8490, [M], 'house', {}),
    ('janina', 'Janina (Ioannina)', 'Janina', '约阿尼纳', 20.8537, 39.6650, [M], 'city', {'note': 'Ali Pasha, Haydée'}),
    ('smyrna', 'Smyrna', 'Smyrna', '士麦那', 27.1428, 38.4237, [M], 'port', {}),
    ('tunis', 'Tunis', 'Tunis', '突尼斯', 10.1815, 36.8065, [M], 'city', {}),
    ('nimes', 'Nîmes', 'Nimes', '尼姆', 4.3601, 43.8367, [M], 'city', {}),
    ('pont_du_gard', 'Pont du Gard', 'Pont du Gard', '加尔桥', 4.5354, 43.9475, [M], 'landmark', {}),
    ('caderousse_inn', "Caderousse's inn (Auberge du Pont du Gard)", 'Caderousse inn', '卡德鲁斯客栈', 4.58, 43.78, [M], 'inn', {'approx': True, 'note': 'Dumas places it on the Beaucaire-Bellegarde road; position approximate'}),
]


def build_gazetteer(views):
    out = []
    for pid, name, ascii_name, zh, lon, lat, br, kind, extra in PLACES:
        e = {'id': pid, 'name': name, 'label': ascii_name, 'name_zh': zh, 'lon': lon, 'lat': lat,
             'branches': br, 'kind': kind, 'views': {}}
        for k, v in views.items():
            x, y = v.fwd(lon, lat)
            if 0 <= x <= v.width and 0 <= y <= v.height:
                e['views'][k] = [int(round(x)), int(round(y))]
        for kk, vv in extra.items():
            e[kk] = vv
        e.setdefault('fictional', False)
        out.append(e)
    return out


# ----------------------------------------------------------------------------------------------
# previews
# ----------------------------------------------------------------------------------------------
def pairs(a):
    return [(a[i], a[i + 1]) for i in range(0, len(a), 2)]


def preview(key, v, data, gaz, path):
    from PIL import Image, ImageDraw, ImageFont
    W, H = v.width, v.height
    SEA = (27, 42, 65)
    GRAT = (48, 70, 102)
    LAND = (233, 220, 184)
    COAST = (122, 96, 60)
    LAKE = (44, 72, 108)
    RIVER = (70, 120, 175)
    ICE = (236, 242, 248)
    img = Image.new('RGB', (W, H), SEA)
    d = ImageDraw.Draw(img)
    step = {'europe': 5, 'world': 15, 'med': 2}[key]
    lon = math.ceil(v.lon_min / step) * step
    while lon <= v.lon_max:
        x, _ = v.fwd(lon, 0)
        d.line([(x, 0), (x, H)], fill=GRAT, width=1)
        lon += step
    lat = math.ceil(v.lat_min / step) * step
    while lat <= v.lat_max:
        _, y = v.fwd(0, lat)
        d.line([(0, y), (W, y)], fill=GRAT, width=1)
        lat += step
    for r in data.get('ice', []):
        d.polygon(pairs(r), fill=ICE, outline=(180, 196, 214))
    for r in data['land']:
        d.polygon(pairs(r), fill=LAND, outline=COAST)
    for it in data['islets']:
        col = (200, 120, 200) if it.get('fictional') else ((214, 120, 60) if it.get('approx') else (190, 90, 50))
        d.polygon(pairs(it['pts']), fill=LAND, outline=col)
    for r in data['lakes']:
        d.polygon(pairs(r), fill=LAKE, outline=COAST)
    for rv in data['rivers']:
        d.line(pairs(rv['pts']), fill=RIVER, width=1 if rv['minor'] else 2)
    try:
        font = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf', 13 if key != 'world' else 12)
        big = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf', 18)
    except Exception:
        font = big = ImageFont.load_default()
    for e in gaz:
        if key not in e['views']:
            continue
        rel = {'europe': (T, C), 'world': (O,), 'med': (M,)}[key]
        if not any(b in rel for b in e['branches']) and not (key == 'europe' and M in e['branches'] and T in e['branches']):
            continue
        x, y = e['views'][key]
        fic = e.get('fictional')
        col = (150, 60, 170) if fic else (192, 40, 40)
        if fic:
            d.polygon([(x, y - 5), (x + 5, y), (x, y + 5), (x - 5, y)], fill=col, outline=(255, 255, 255))
        else:
            d.ellipse([x - 3, y - 3, x + 3, y + 3], fill=col, outline=(255, 255, 255))
        d.text((x + 5, y - 8), e['label'], font=font, fill=(20, 20, 20), stroke_width=2, stroke_fill=(250, 244, 226))
    vp = data['view']
    title = '%s  %s  lon %g..%g  lat %.2f..%g  %dx%d  %s' % (key.upper(), vp['projection'], vp['lon_min'], vp['lon_max'],
                                                          vp['lat_min'], vp['lat_max'], W, H, SOURCE)
    d.rectangle([8, 8, 16 + 10 * len(title), 36], fill=(250, 244, 226))
    d.text((14, 12), title, font=big, fill=(27, 42, 65))
    img.save(path, optimize=True)


# ----------------------------------------------------------------------------------------------
def main():
    os.makedirs(OUT, exist_ok=True)
    built = {}
    for key in ('europe', 'world', 'med'):
        v, data = build_view(key)
        built[key] = (v, data)
    gaz = build_gazetteer({k: b[0] for k, b in built.items()})
    gz = {'source': 'coordinates compiled for the game (public geographic facts); canvas x,y per view',
          'views': {k: b[1]['view'] for k, b in built.items()},
          'places': gaz}
    with open(os.path.join(OUT, 'gazetteer.json'), 'w', encoding='utf-8') as fh:
        json.dump(gz, fh, ensure_ascii=False, indent=1)
    report = {}
    for key, (v, data) in built.items():
        p = os.path.join(OUT, key + '.json')
        with open(p, 'w', encoding='utf-8') as fh:
            json.dump(data, fh, ensure_ascii=False, separators=(',', ':'))
        npts = sum(len(r) // 2 for r in data['land'])
        report[key] = dict(bytes=os.path.getsize(p), land=len(data['land']), land_pts=npts,
                           lakes=len(data['lakes']), rivers=len(data['rivers']), islets=len(data['islets']),
                           ice=len(data.get('ice', [])), size='%dx%d' % (v.width, v.height))
        preview(key, v, data, gaz, os.path.join(OUT, 'preview_%s.png' % key))
    print(json.dumps(report, indent=1))
    print(json.dumps(dict(STATS), indent=1, ensure_ascii=False))


if __name__ == '__main__':
    main()
