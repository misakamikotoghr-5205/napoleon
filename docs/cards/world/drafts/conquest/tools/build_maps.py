#!/usr/bin/env python3
"""Builds the two Europe map drafts (ARCH §2.2 shape) for the conquest package.

Run:  python3 -I tools/build_maps.py        (from the conquest/ folder)
Writes data/campaigns/napoleon/maps/europe.json        (trunk  鹰旗, 8 sheets)
       data/campaigns/napoleon/maps/europe_late.json   (branch 鹰飞, 6 sheets)
       data/campaigns/napoleon/book_conquest_patch.json (scene_battles / battle_pool / branches.conquest …)

Coordinates: `geo` = [lon*100, lat*100] (ARCH §2.2, integers). Real places come from
../geo/gazetteer.json where it has them, the rest are public geographic facts typed in below.
Canvas sheets (Toulon 1793, Elba) also get `xy` on their 1920x1080 painted map; island/harbour
`xy` are computed from the real lon/lat with a local equirectangular fit so the painter can trace them.

`frames` (new, UI-only, see CONQUEST.md §4.2): camera windows per sheet, first whose `when` holds.
A node lists the frames it is drawn in (`frame`); the checker tests marker spacing per frame.
"""
import json, math, os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GEO = os.path.join(os.path.dirname(ROOT), "geo", "gazetteer.json")
OUT = os.path.join(ROOT, "data", "campaigns", "napoleon")

GAZ = {p["id"]: p for p in json.load(open(GEO, encoding="utf-8"))["places"]}

# extra places: id -> (lon, lat, 中文名)
EXTRA = {
    # Toulon 1793
    "vienne": (4.87, 45.52, "维埃纳"), "soissons": (3.32, 49.38, "苏瓦松"), "maastricht": (5.69, 50.85, "马斯特里赫特"),
    "thionville": (6.17, 49.36, "蒂永维尔"), "verdun": (5.38, 49.16, "凡尔登"),
    "wels": (14.03, 48.16, "韦尔斯"), "steyr": (14.42, 48.04, "施泰尔"), "guarda": (-7.27, 40.54, "瓜达"),
    "abbeville": (1.83, 50.10, "阿布维尔"), "saint_omer": (2.25, 50.75, "圣奥梅尔"), "cassel": (2.49, 50.80, "卡塞勒"),
    "lille": (3.06, 50.63, "里尔"), "bruges": (3.22, 51.21, "布鲁日"), "plock": (19.70, 52.55, "普沃茨克"),
    "kaiserslautern": (7.77, 49.44, "凯泽斯劳滕"),
    "ollioules": (5.847, 43.140, "奥利乌勒"), "beausset": (5.802, 43.198, "博塞"), "evenos": (5.882, 43.165, "埃弗诺"),
    "bandol": (5.752, 43.136, "邦多勒"), "sanary": (5.800, 43.119, "萨纳里"), "six_fours": (5.838, 43.094, "六炉村"),
    "sans_peur": (5.873, 43.112, "无畏者炮台"), "la_seyne": (5.883, 43.101, "拉塞讷"), "dugommier_hq": (5.862, 43.128, "围城司令部"),
    "caire_foot": (5.874, 43.088, "凯尔高地脚下"), "petit_gibraltar": (5.889, 43.080, "小直布罗陀"),
    # Italy 1796
    "oneglia": (8.03, 43.89, "奥内利亚"), "loano": (8.26, 44.13, "洛阿诺"), "ceva": (8.03, 44.39, "切瓦"),
    "cherasco": (7.86, 44.65, "切拉斯科"), "alessandria": (8.61, 44.91, "亚历山德里亚"), "tortona": (8.86, 44.90, "托尔托纳"),
    "pavia": (9.16, 45.19, "帕维亚"), "piacenza": (9.69, 45.05, "皮亚琴察"), "cremona": (10.02, 45.13, "克雷莫纳"),
    "brescia": (10.21, 45.54, "布雷西亚"), "modena": (10.93, 44.65, "摩德纳"), "bologna": (11.34, 44.49, "博洛尼亚"),
    "castiglione": (10.49, 45.39, "卡斯蒂廖内"), "legnago": (11.31, 45.19, "莱尼亚戈"), "peschiera": (10.69, 45.44, "佩斯基耶拉"),
    "verona": (10.99, 45.44, "维罗纳"), "villafranca": (10.845, 45.354, "维拉弗兰卡"),
    # Egypt / Syria 1798-99
    "malta": (14.51, 35.90, "马耳他"), "rosetta": (30.42, 31.40, "罗塞塔"), "damanhur": (30.47, 31.04, "达曼胡尔"),
    "cairo_hq": (31.26, 30.06, "开罗"), "pyramids_field": (31.13, 29.97, "金字塔下"), "bilbeis": (31.56, 30.42, "比勒拜斯"),
    "salheyeh": (31.97, 30.80, "萨利希耶"), "el_arish": (33.80, 31.13, "阿里什"), "gaza": (34.45, 31.50, "加沙"),
    "caesarea": (34.89, 32.50, "凯撒利亚"), "haifa": (34.99, 32.82, "海法"),
    # Alps 1800
    "dijon": (5.04, 47.32, "第戎"), "geneva": (6.14, 46.20, "日内瓦"), "lausanne": (6.63, 46.52, "洛桑"),
    "great_st_bernard": (7.17, 45.87, "大圣伯纳德山口"), "aosta": (7.32, 45.74, "奥斯塔"), "ivrea": (7.87, 45.47, "伊夫雷亚"),
    "stradella": (9.30, 45.08, "斯特拉代拉"), "villeneuve": (6.93, 46.40, "维尔讷沃"), "vercelli": (8.42, 45.32, "韦尔切利"), "novara": (8.62, 45.45, "诺瓦拉"), "suez": (32.55, 29.97, "苏伊士"), "katia": (32.77, 31.04, "卡蒂亚"), "voghera": (9.01, 44.99, "沃盖拉"), "san_giuliano": (8.77, 44.90, "圣朱利亚诺"),
    # 1805-07
    "amiens": (2.30, 49.89, "亚眠"), "reims": (4.03, 49.26, "兰斯"), "strasbourg": (7.75, 48.58, "斯特拉斯堡"),
    "stuttgart": (9.18, 48.78, "斯图加特"), "donauworth": (10.78, 48.72, "多瑙沃特"),
    "munich": (11.58, 48.14, "慕尼黑"), "braunau": (13.03, 48.26, "布劳瑙"), "linz": (14.29, 48.31, "林茨"),
    "brunn": (16.61, 49.20, "布吕恩"), "zuran": (16.70, 49.17, "祖兰山"), "mainz": (8.27, 50.00, "美因茨"),
    "wurzburg": (9.93, 49.79, "维尔茨堡"), "bamberg": (10.89, 49.89, "班贝格"), "hof": (11.92, 50.31, "霍夫"),
    "leipzig_1806": (12.37, 51.34, "莱比锡"), "posen": (16.93, 52.41, "波森"), "osterode": (19.95, 53.70, "奥斯特罗德"),
    "landsberg_ep": (20.49, 54.28, "兰茨贝格"), "fulda": (9.68, 50.55, "富尔达"), "kustrin": (14.63, 52.58, "屈斯特林"), "thorn": (18.60, 53.01, "托伦"),
    # 1808-09
    "pamplona": (-1.64, 42.81, "潘普洛纳"), "vitoria": (-2.67, 42.85, "维多利亚"), "burgos": (-3.70, 42.34, "布尔戈斯"),
    "aranda": (-3.69, 41.67, "阿兰达"), "segovia": (-4.12, 40.95, "塞哥维亚"), "calatayud": (-1.64, 41.35, "卡拉塔尤德"),
    "tudela": (-1.61, 42.06, "图德拉"), "alagon": (-1.12, 41.77, "阿拉贡"), "casetas": (-1.03, 41.72, "卡塞塔斯"),
    "bordeaux": (-0.58, 44.84, "波尔多"), "bayonne": (-1.47, 43.49, "巴约讷"), "passau": (13.46, 48.57, "帕绍"), "ebersdorf": (16.47, 48.155, "凯泽埃伯斯多夫"),
    "lobau": (16.53, 48.185, "洛鲍岛"), "toledo": (-4.02, 39.86, "托莱多"), "soria": (-2.47, 41.76, "索里亚"), "chalons": (4.36, 48.96, "沙隆"), "augsburg": (10.90, 48.37, "奥格斯堡"), "melk": (15.33, 48.23, "梅尔克"),
    # 1812
    "minsk": (27.56, 53.90, "明斯克"), "glubokoye": (27.68, 55.14, "格卢博科耶"), "polotsk": (28.78, 55.49, "波洛茨克"),
    "vitebsk": (30.20, 55.19, "维捷布斯克"), "dorogobuzh": (33.29, 54.92, "多罗戈布日"), "vyazma": (34.30, 55.21, "维亚济马"),
    "gzhatsk": (35.00, 55.55, "格扎茨克"), "maloyaroslavets": (36.47, 55.02, "小雅罗斯拉韦茨"), "krasnoi": (31.29, 54.56, "红村"),
    "orsha": (30.42, 54.51, "奥尔沙"),
    # 1813-14
    "naumburg": (11.81, 51.15, "瑙姆堡"), "altenburg": (12.43, 50.99, "阿尔滕堡"), "chemnitz": (12.92, 50.83, "开姆尼茨"),
    "bautzen": (14.42, 51.18, "包岑"), "gorlitz": (14.99, 51.15, "格尔利茨"), "torgau": (13.00, 51.56, "托尔高"),
    "wittenberg": (12.65, 51.87, "维滕贝格"), "duben": (12.59, 51.59, "迪本"), "eilenburg": (12.63, 51.46, "艾伦堡"),
    "wachau": (12.45, 51.27, "瓦豪"), "hanau": (8.92, 50.13, "哈瑙"), "halle": (11.97, 51.48, "哈雷"), "meissen": (13.47, 51.16, "迈森"),
    # Elba 1814-15
    "san_martino": (10.285, 42.784, "圣马蒂诺别墅"), "procchio": (10.247, 42.786, "普罗基奥"), "marciana": (10.17, 42.79, "马尔恰纳"),
    "marina_di_campo": (10.237, 42.746, "坎波海滨"), "capoliveri": (10.379, 42.745, "卡波利韦里"), "porto_longone": (10.40, 42.763, "隆戈内港"),
    "rio_marina": (10.426, 42.814, "里奥铁矿"), "volterraio": (10.37, 42.80, "沃尔泰拉约堡"), "lacona": (10.31, 42.76, "拉科纳"), "cavo": (10.42, 42.86, "卡沃"),
    # 1815 Hundred Days
    "grasse": (6.92, 43.66, "格拉斯"), "castellane": (6.51, 43.85, "卡斯特拉讷"), "digne": (6.24, 44.09, "迪涅"),
    "sisteron": (5.94, 44.20, "锡斯特龙"), "gap": (6.08, 44.56, "加普"), "macon": (4.83, 46.31, "马孔"),
    "chalon": (4.85, 46.78, "索恩河畔沙隆"), "auxerre": (3.57, 47.80, "欧塞尔"), "compiegne": (2.83, 49.42, "贡比涅"),
    "laon": (3.62, 49.56, "拉昂"), "avesnes": (3.93, 50.12, "阿韦讷"), "beaumont": (4.24, 50.24, "博蒙"),
    "charleroi": (4.44, 50.41, "沙勒罗瓦"), "fleurus": (4.55, 50.48, "弗勒吕斯"), "genappe": (4.45, 50.61, "热纳普"),
    "plancenoit": (4.425, 50.663, "普朗斯努瓦"), "waterloo_inn": (4.40, 50.715, "滑铁卢村"),
    # 1815 autumn
    "namur": (4.87, 50.47, "那慕尔"), "liege": (5.57, 50.63, "列日"), "luxembourg": (6.13, 49.61, "卢森堡"),
    "metz": (6.18, 49.12, "梅斯"), "nancy": (6.18, 48.69, "南锡"), "saverne": (7.36, 48.74, "萨韦尔讷"),
    "haguenau": (7.79, 48.82, "阿格诺"), "seltz": (8.10, 48.89, "塞尔茨"), "wissembourg": (7.94, 49.04, "维桑堡"),
    # 1816
    "landshut": (12.15, 48.54, "兰茨胡特"), "salzburg": (13.05, 47.80, "萨尔茨堡"), "kufstein": (12.17, 47.58, "库夫施泰因"),
    "st_polten": (15.63, 48.20, "圣珀尔滕"), "purkersdorf": (16.18, 48.21, "普尔克斯多夫"),
    "laxenburg": (16.36, 48.07, "拉克森堡"), "schoenbrunn": (16.31, 48.185, "美泉宫"),
    # 1817
    "valladolid": (-4.72, 41.65, "巴利亚多利德"), "salamanca": (-5.66, 40.97, "萨拉曼卡"), "ciudad_rodrigo": (-6.53, 40.60, "罗德里戈城"),
    "coimbra": (-8.43, 40.21, "科英布拉"), "santarem": (-8.68, 39.24, "圣塔伦"), "alenquer": (-9.01, 39.05, "阿伦克尔"),
    "sobral": (-9.15, 39.03, "索布拉尔"), "torres_vedras": (-9.26, 39.09, "托雷斯韦德拉什"), "calais": (1.86, 50.95, "加来"),
    "dunkirk": (2.38, 51.03, "敦刻尔克"), "ostend": (2.92, 51.23, "奥斯坦德"), "etaples": (1.64, 50.51, "埃塔普勒"),
    "gris_nez": (1.58, 50.87, "灰鼻角"), "hythe": (1.08, 51.07, "海斯"),
    # 1818
    "danzig": (18.65, 54.35, "但泽"), "konigsberg": (20.51, 54.71, "柯尼斯堡"),
    "grodno": (23.83, 53.68, "格罗德诺"), "ostrolenka": (21.57, 53.08, "奥斯特罗文卡"), "bialystok": (23.16, 53.13, "比亚韦斯托克"),
    "vilkaviskis": (23.03, 54.65, "维尔卡维什基斯"), "mariampol": (23.35, 54.56, "马里扬波尔"), "pilviskiai": (23.21, 54.71, "皮尔维什基艾"),
    # 1819
    "erfurt": (11.03, 50.98, "爱尔福特"), "weimar": (11.33, 50.98, "魏玛"),
    "markkleeberg": (12.37, 51.28, "马克克莱贝格"), "probstheida": (12.42, 51.30, "普罗布斯泰达"), "frankfurt": (8.68, 50.11, "法兰克福"),
}

def place(pid):
    if pid in EXTRA:
        return EXTRA[pid][0], EXTRA[pid][1], EXTRA[pid][2]
    g = GAZ[pid]
    return g["lon"], g["lat"], g["name_zh"]

# ------------------------------------------------------------------ projection helpers
EUROPE = {"lon_min": -12.0, "scale": 2022.203982815, "y_top": 1.42678824664}
def merc(lon, lat):
    s = EUROPE["scale"]
    return s * (math.radians(lon) - math.radians(EUROPE["lon_min"])), s * (EUROPE["y_top"] - math.log(math.tan(math.pi / 4 + math.radians(lat) / 2)))

def local_fit(points, lon_rng, lat_rng, w=1920, h=1080, margin=90):
    lat0 = (lat_rng[0] + lat_rng[1]) / 2
    k = math.cos(math.radians(lat0))
    gw, gh = (lon_rng[1] - lon_rng[0]) * k, lat_rng[1] - lat_rng[0]
    s = min((w - 2 * margin) / gw, (h - 2 * margin) / gh)
    ox = (w - gw * s) / 2
    oy = (h - gh * s) / 2
    out = {}
    for pid, (lon, lat) in points.items():
        out[pid] = [int(round(ox + (lon - lon_rng[0]) * k * s)), int(round(oy + (lat_rng[1] - lat) * s))]
    return out

# ------------------------------------------------------------------ node / link builders
TYPE_ACTIONS = {
    "supply": ["visit:town", "trade:fair", "trade:counterfeit", "build_depot"],
    "camp": ["schedule:recruit", "schedule:train", "schedule:bond_story", "activity:rest"],
    "shop": ["activity:merchant", "recruit:troop", "recruit:companion"],
}
ROLE_ACTIONS = {"intel": ["visit:backdoor", "trade:fair"], "project": ["build", "explore", "visit:town"],
                "port": ["visit:town", "trade:fair", "trade:counterfeit", "build_depot"]}
BATTLE_TYPES = ("battle", "elite", "boss")

def node(nid, typ, pid=None, label=None, **kw):
    lon, lat, zh = place(pid or nid)
    n = {"id": nid, "type": typ}
    if kw.get("role"): n["role"] = kw.pop("role")
    n["label"] = label or zh
    if kw.get("date"): n["date"] = kw.pop("date")
    n["geo"] = [int(round(lon * 100)), int(round(lat * 100))]
    n["_ll"] = (lon, lat)
    for k, v in kw.items():
        n[k] = v
    if "fog" not in n:
        n["fog"] = "type" if typ == "slot" else "open"
    if "actions" not in n:
        if typ == "supply":
            n["actions"] = list(ROLE_ACTIONS.get(n.get("role"), TYPE_ACTIONS["supply"]))
        elif typ == "camp":
            n["actions"] = list(TYPE_ACTIONS["camp"]) + (["muster"] if n.get("role") == "muster" else [])
        elif typ == "shop":
            n["actions"] = list(TYPE_ACTIONS["shop"])
    if typ in ("story", "boss", "branch") or (typ == "event" and n.get("event")) or n.get("role") == "muster":
        n.setdefault("fixed", True)
    if typ in ("supply", "camp", "shop"):
        n.setdefault("once", False)
    if n.get("role") == "post":
        n.setdefault("pass", {"stamp": 1, "coins": {"supply": 1}})
    return n

def slot(nid, pool, level, pid=None, label=None, kinds=None, **kw):
    k = dict(kinds or {"event": 5, "supply": 2, "camp": 2, "shop": 1, "battle": 2})
    if level is None:
        k.pop("battle", None)
    s = {"pool": pool, "kinds": k}
    if level is not None:
        s["level"] = level
    return node(nid, "slot", pid, label, slot=s, **kw)

def link(a, b, legs=1, **kw):
    l = {"a": a, "b": b, "legs": legs}
    l.update(kw)
    return l

def voyage(a, b, days, **kw):
    l = {"a": a, "b": b, "voyage_days": days}
    l.update(kw)
    return l

def camp_phase(nodes_):
    for n in nodes_:
        n["phase"] = "campaign"
    return nodes_

def finish_sheet(sh):
    """Slot battle weights obey R2: a slot adjacent to a fixed battle node, or to a slot that already
    kept its battle weight (id order), loses the battle kind. Strips helper keys."""
    nodes_ = {n["id"]: n for n in sh["nodes"]}
    adj = {k: set() for k in nodes_}
    for l in sh["links"]:
        if l.get("rush"):
            continue
        adj[l["a"]].add(l["b"]); adj[l["b"]].add(l["a"])
    battleish = {k for k, n in nodes_.items() if n["type"] in BATTLE_TYPES or (n["type"] == "story" and n.get("_battle"))}
    for k in sorted(nodes_):
        n = nodes_[k]
        if n["type"] != "slot":
            continue
        kinds = n["slot"]["kinds"]
        if kinds.get("battle", 0) or kinds.get("elite", 0):
            if adj[k] & battleish:
                kinds.pop("battle", None); kinds.pop("elite", None)
            else:
                battleish.add(k)
        if "battle" not in kinds and "elite" not in kinds:
            n["slot"].pop("level", None)
    for n in sh["nodes"]:
        n.pop("_ll", None); n.pop("_battle", None)
    return sh

# ------------------------------------------------------------------ battle levels (absolute L, ARCH §3.1)
SCENE_BATTLES = {
    # trunk
    "toulon_mulgrave": {"template": "toulon_night", "level": 1},
    "italy_rivoli": {"template": "rivoli_plateau", "level": 3},
    "orient_acre": {"template": "acre", "level": 5},
    "alps_marengo": {"template": "marengo", "level": 5},
    "austerlitz_sun": {"template": "austerlitz", "level": 7},
    "eylau_snow": {"template": "eylau", "level": 7},
    "saragossa_siege": {"template": "saragossa", "level": 9},
    "wagram_lobau": {"template": "wagram", "level": 9},
    "russia_borodino": {"template": "borodino", "level": 9},
    "russia_berezina": {"template": "berezina", "level": 10},
    "collapse_leipzig": {"template": "leipzig", "level": 11},
    "elba_night": {"template": "elba_cove", "level": 12},
    # conquest (鹰飞)
    "k_charleroi": {"template": "charleroi_bridge", "level": 12},
    "k_waterloo": {"template": "waterloo", "level": 14},
    "k_brussels": {"template": "brussels", "level": 15},
    "k_rhine": {"template": "rhine_crossing", "level": 16},
    "k_vienna": {"template": "vienna_streets", "level": 18},
    "k_torres_vedras": {"template": "iberia_return", "level": 20},
    "k_dover": {"template": "channel_landing", "level": 20},
    "k_niemen": {"template": "niemen", "level": 22},
    "k_leipzig_1819": {"template": "coalition_final", "level": 24},
}

def story(nid, scene, pid=None, label=None, **kw):
    n = node(nid, "story", pid, label, scene=scene, **kw)
    if scene in SCENE_BATTLES:
        n["_battle"] = True
    return n

def boss(nid, scene, pid=None, label=None, **kw):
    return node(nid, "boss", pid, label, scene=scene, **kw)

def council(nid, event, pid=None, label=None, **kw):
    return node(nid, "event", pid, label, event=event, role="council", **kw)

# ================================================================== TRUNK (europe.json)
def sheet_toulon():
    ids = ["ollioules", "beausset", "evenos", "bandol", "sanary", "six_fours", "sans_peur", "la_seyne",
           "dugommier_hq", "caire_foot", "petit_gibraltar"]
    xy = local_fit({i: place(i)[:2] for i in ids}, (5.735, 5.905), (43.070, 43.205))
    N = [
        story("ollioules", "toulon_arrival", label="奥利乌勒·炮兵库", date="1793-11-20", actions=["visit:town", "trade:fair"]),
        slot("beausset", "toulon", None, kinds={"event": 8, "supply": 1, "camp": 1}),
        slot("evenos", "toulon", None, kinds={"event": 8, "supply": 1, "camp": 1}),
        slot("bandol", "toulon", None, kinds={"event": 8, "supply": 1, "camp": 1}),
        node("sanary", "supply", role="port", label="萨纳里港"),
        slot("six_fours", "toulon", None, kinds={"event": 8, "supply": 1, "camp": 1}),
        node("sans_peur", "supply", role="post", label="无畏者炮台"),
        node("la_seyne", "camp", role="muster", label="拉塞讷营地"),
    ] + camp_phase([
        council("dugommier_hq", "ev_council_toulon", label="杜戈米埃的军议", date="1793-12-11"),
        node("caire_foot", "camp", label="凯尔高地脚下（雨夜）", actions=["activity:rest", "schedule:bond_story"]),
        boss("petit_gibraltar", "toulon_mulgrave", label="小直布罗陀棱堡", date="1793-12-17"),
    ])
    for n in N:
        n["xy"] = xy[n["id"]]
    L = [link("ollioules", "beausset"), link("ollioules", "evenos"), link("ollioules", "sanary", 2, supply=1),
         link("beausset", "bandol"), link("bandol", "sanary"), link("sanary", "six_fours"), link("six_fours", "la_seyne"),
         link("evenos", "sans_peur"), link("ollioules", "sans_peur", 2), link("sans_peur", "la_seyne"),
         link("la_seyne", "dugommier_hq"), link("dugommier_hq", "caire_foot"), link("caire_foot", "petit_gibraltar")]
    return {"chapter": "toulon", "view": "toulon_1793", "start": "ollioules", "days_max": 6, "stamps_need": 1,
            "muster": "la_seyne", "boss": "petit_gibraltar", "interlude": None, "tutorial": True,
            "frames": [{"id": "toulon", "view": "toulon_1793"}],
            "sets": [], "rivals": [], "nodes": N, "links": L}

def sheet_italy():
    W, Q = ["italy_wide"], ["italy_quad"]
    N = [
        story("nice", "italy_nice", label="尼斯·军团司令部", date="1796-03-27", actions=["visit:town", "trade:fair"], frame=W),
        slot("oneglia", "italy", 1, frame=W),
        node("loano", "supply", role="post", label="洛阿诺驿站", frame=W, date="1796-04"),
        node("montenotte", "battle", template="montenotte", level=1, date="1796-04-12", weather=["fog", "clear"],
             reward={"coins": {"medal": 1}}, frame=W),
        slot("ceva", "italy", 1, frame=W),
        node("cherasco", "camp", label="切拉斯科（停战）", date="1796-04-28", frame=W),
        node("alessandria", "supply", label="亚历山德里亚仓库", frame=W),
        slot("tortona", "italy", 1, frame=W),
        slot("pavia", "italy", 1, frame=W),
        node("piacenza", "supply", role="post", label="皮亚琴察渡口", frame=W, date="1796-05-07"),
        node("lodi", "elite", template="lodi_bridge", level=2, date="1796-05-10", weather=["clear"],
             reward={"items": ["lodi_colours"], "coins": {"medal": 1}}, frame=W),
        story("milan", "italy_milan", label="米兰·塞尔贝洛尼宫", date="1796-05-15", actions=["visit:town", "trade:fair", "trade:counterfeit"], frame=W),
        node("cremona", "shop", label="克雷莫纳的随军商贩", frame=W),
        slot("brescia", "italy", 1, frame=W),
        slot("modena", "italy", 1, frame=W),
        node("bologna", "event", event="ev_faria_half_letter", label="博洛尼亚·斯帕达府", date="1796-06-24",
             requires={"scene_done": "italy_milan"}, frame=W),
        slot("castiglione", "italy", 1, frame=W),
        slot("legnago", "italy", 1, frame=W),
        node("peschiera", "camp", role="muster", label="佩斯基耶拉（开拔）", frame=W + Q),
    ] + camp_phase([
        council("verona", "ev_council_italy", label="维罗纳军议", date="1796-11-14", frame=Q),
        node("arcole", "elite", template="arcole_dikes", level=2, date="1796-11-15", weather=["fog", "clear"],
             reward={"coins": {"medal": 2}}, frame=Q),
        node("villafranca", "camp", label="维拉弗兰卡营火", actions=["activity:rest", "schedule:bond_story", "schedule:train"], frame=Q),
        boss("rivoli", "italy_rivoli", label="里沃利高原", date="1797-01-14", frame=Q),
        node("la_favorita", "elite", template="la_favorita", level=2, date="1797-01-16", weather=["clear", "fog"],
             requires={"flags": ["t_favorita_pursuit"]}, reward={"coins": {"gold": 1, "medal": 1}}, frame=Q),
        story("campo_formio", "italy_campo_formio", label="坎波福米奥·帕塞里亚诺", date="1797-10-17", frame=Q),
    ])
    L = [link("nice", "oneglia", 2), link("oneglia", "loano"), link("oneglia", "ceva", 2, supply=1), link("loano", "montenotte"),
         link("loano", "ceva"), link("ceva", "cherasco"), link("montenotte", "cherasco", 2), link("montenotte", "alessandria", 2),
         link("cherasco", "alessandria", 2), link("alessandria", "tortona"), link("alessandria", "pavia", 2),
         link("tortona", "piacenza", 2), link("piacenza", "lodi"), link("pavia", "milan"), link("lodi", "milan"),
         link("piacenza", "cremona"), link("lodi", "cremona"), link("milan", "brescia", 2), link("cremona", "brescia", 2),
         link("cremona", "modena", 2, toll={"gold": 1}), link("modena", "bologna"), link("brescia", "castiglione"),
         link("castiglione", "peschiera"), link("modena", "legnago", 2), link("legnago", "peschiera", 2, supply=1),
         link("castiglione", "legnago", 2),
         link("peschiera", "verona"), link("verona", "arcole"), link("arcole", "villafranca", 2), link("verona", "villafranca"),
         link("villafranca", "rivoli", 2), link("rivoli", "la_favorita", 2, rush=True, label="连夜急行军"), link("rivoli", "campo_formio", 4),
         link("la_favorita", "campo_formio", 4)]
    rivals = [
        {"id": "barbets", "label": "巴尔贝山民", "path": ["ceva", "cherasco", "ceva", "loano"], "speed": 1, "start": 0,
         "meet": {"battle": {"template": "skirmish_terraces", "level": 1}, "toll": {"gold": 1}}, "burns_depots": True},
        {"id": "storks_convoy", "label": "白鹳商行车队", "path": ["alessandria", "tortona", "piacenza", "cremona", "piacenza", "tortona"],
         "speed": 1, "start": 2, "meet": {"toll": {"supply": 2}}, "burns_depots": False, "buys_depots": True,
         "extra_if": {"flags": ["t_storks_hostile"]}},
    ]
    return {"chapter": "italy", "view": "europe", "start": "nice", "days_max": 18, "stamps_need": 2,
            "muster": "peschiera", "boss": "rivoli", "interlude": "audience",
            "frames": [{"id": "italy_quad", "lon": [1040, 1340], "lat": [4495, 4615], "when": {"mustered": True}},
                       {"id": "italy_wide", "lon": [690, 1240], "lat": [4345, 4620]}],
            "sets": [{"id": "lombardy", "nodes": ["alessandria", "piacenza", "cremona"], "bonus": {"pass_supply": 1}}],
            "rivals": rivals, "nodes": N, "links": L}

def sheet_orient_alps():
    M, E, S, A, R = ["med_1798"], ["egypt_1798"], ["syria_1799"], ["alps_1800"], ["marengo_1800"]
    ORI, ALP = {"flags": ["t_orient"]}, {"flags": ["t_alps"]}
    K = {"event": 6, "supply": 2, "camp": 1, "shop": 1, "battle": 2}
    N = [
        story("toulon_1798", "orient_orders", pid="toulon", label="土伦港（三百艘船）", date="1798-05-10", frame=M),
        node("malta", "event", label="马耳他·骑士团的银库", event="ev_malta_silver", requires=ORI, date="1798-06-12", frame=M),
        node("alexandria", "supply", role="port", label="亚历山大港", requires=ORI, date="1798-07-02", frame=M + E),
        slot("aboukir", "orient", 3, requires=ORI, kinds=K, frame=E),
        node("rosetta", "supply", role="post", label="罗塞塔驿站", requires=ORI, frame=E),
        slot("damanhur", "orient", 3, requires=ORI, kinds=K, frame=E),
        node("pyramids", "elite", pid="pyramids_field", template="pyramids", level=4, date="1798-07-21", weather=["desert"],
             requires=ORI, reward={"coins": {"medal": 2}}, fallback="elite_a", frame=E),
        node("cairo", "event", pid="cairo_hq", event="ev_mysore_envoy", label="开罗·司令部", requires=ORI, frame=E),
        slot("bilbeis", "orient", 3, requires=ORI, kinds=K, frame=E),
        slot("suez", "orient", 3, pid="suez", requires=ORI, kinds=K, frame=E),
        node("salheyeh", "shop", label="萨利希耶的骆驼市", requires=ORI, frame=E),
        slot("katia", "orient", 3, requires=ORI, kinds=K, weather=["desert"], frame=E),
        slot("el_arish", "orient", 3, requires=ORI, kinds=K, weather=["desert"], frame=E),
        node("gaza", "supply", role="post", label="加沙驿站", requires=ORI, frame=E),
        node("jaffa", "camp", role="muster", label="雅法（开拔）", requires=ORI, date="1799-03-07", frame=E + S),
        node("dijon", "supply", label="第戎·后备军仓库", requires=ALP, date="1800-04", frame=M + A),
        slot("geneva", "alps", 3, requires=ALP, kinds=K, frame=A),
        node("lausanne", "supply", role="post", label="洛桑驿站", requires=ALP, frame=A),
        slot("villeneuve", "alps", 3, requires=ALP, kinds=K, frame=A),
        node("great_st_bernard", "event", event="ev_st_bernard", label="大圣伯纳德山口", requires=ALP, date="1800-05-20", weather=["snow"], frame=A),
        slot("aosta", "alps", 3, requires=ALP, frame=A, kinds={"event": 6, "supply": 2, "camp": 2, "shop": 1}),
        node("fort_bard", "elite", template="fort_bard", level=4, date="1800-05-21", requires=ALP, fallback="elite_a",
             reward={"coins": {"medal": 1, "supply": 2}}, frame=A),
        node("ivrea", "supply", role="post", label="伊夫雷亚驿站", requires=ALP, frame=A),
        slot("vercelli", "alps", 3, requires=ALP, kinds=K, frame=A),
        slot("novara", "alps", 3, requires=ALP, kinds=K, frame=A),
        node("milan_1800", "shop", pid="milan", label="米兰（再入城）", requires=ALP, date="1800-06-02", frame=A),
        node("stradella", "camp", role="muster", label="斯特拉代拉（开拔）", requires=ALP, frame=A + R),
    ] + camp_phase([
        council("caesarea", "ev_council_acre", requires=ORI, label="凯撒利亚军议", frame=S),
        node("haifa", "camp", label="迦密山下的营火", requires=ORI, actions=["activity:rest", "schedule:bond_story"], frame=S),
        boss("acre", "orient_acre", label="阿卡城下", requires=ORI, date="1799-05-10", frame=S),
        council("voghera", "ev_council_marengo", requires=ALP, label="沃盖拉军议", frame=R),
        node("san_giuliano", "camp", label="圣朱利亚诺营火", requires=ALP, actions=["activity:rest", "schedule:bond_story"], frame=R),
        boss("marengo", "alps_marengo", label="马伦哥平原", requires=ALP, date="1800-06-14", frame=R),
    ])
    L = [voyage("toulon_1798", "malta", 3, requires=ORI), voyage("malta", "alexandria", 3), link("alexandria", "aboukir"),
         link("aboukir", "rosetta"), link("alexandria", "damanhur"), link("rosetta", "damanhur"), link("damanhur", "pyramids", 2),
         link("pyramids", "cairo"), link("damanhur", "cairo", 3, supply=1), link("cairo", "bilbeis"), link("bilbeis", "suez", 2, supply=1),
         link("bilbeis", "salheyeh"), link("salheyeh", "katia", 2, supply=1), link("katia", "el_arish", 2, supply=1),
         link("el_arish", "gaza", 2), link("gaza", "jaffa"),
         link("toulon_1798", "dijon", 4, requires=ALP), link("dijon", "geneva", 2), link("dijon", "lausanne", 3), link("geneva", "lausanne"),
         link("lausanne", "villeneuve"), link("geneva", "villeneuve", 2), link("villeneuve", "great_st_bernard", 2, supply=1),
         link("great_st_bernard", "aosta"), link("aosta", "fort_bard"), link("fort_bard", "ivrea"),
         link("aosta", "ivrea", 3, supply=2, route="duel_route", label="阿尔巴雷多骡道"), link("ivrea", "vercelli", 2),
         link("vercelli", "novara"), link("ivrea", "novara", 2), link("novara", "milan_1800", 2), link("milan_1800", "stradella", 2),
         link("jaffa", "caesarea"), link("caesarea", "haifa"), link("haifa", "acre"),
         link("stradella", "voghera"), link("voghera", "san_giuliano"), link("san_giuliano", "marengo")]
    rivals = [{"id": "bedouin_raiders", "label": "贝都因骑手", "path": ["bilbeis", "salheyeh", "katia", "salheyeh"], "speed": 1, "start": 0,
               "requires": ORI, "meet": {"battle": {"template": "skirmish_mill_ford", "level": 3}, "toll": {"supply": 2}}, "burns_depots": True}]
    return {"chapter": "orient_alps", "view": "europe", "start": "toulon_1798", "days_max": 14, "stamps_need": 2,
            "muster": ["jaffa", "stradella"], "boss": ["acre", "marengo"], "interlude": "bond",
            "frames": [{"id": "syria_1799", "lon": [3420, 3560], "lat": [3190, 3320], "when": {"flags": ["t_orient"], "mustered": True}},
                       {"id": "egypt_1798", "lon": [2940, 3540], "lat": [2970, 3260], "when": {"flags": ["t_orient"]}},
                       {"id": "marengo_1800", "lon": [840, 950], "lat": [4475, 4520], "when": {"flags": ["t_alps"], "mustered": True}},
                       {"id": "alps_1800", "lon": [460, 980], "lat": [4480, 4760], "when": {"flags": ["t_alps"]}},
                       {"id": "med_1798", "lon": [400, 3650], "lat": [2900, 4780]}],
            "sets": [{"id": "nile", "nodes": ["alexandria", "rosetta", "gaza"], "bonus": {"pass_supply": 1}}],
            "rivals": rivals, "nodes": N, "links": L}

def sheet_austerlitz_jena():
    W, MO, PO = ["north_1805"], ["moravia_1805"], ["poland_1807"]
    DAN, PRU = {"flags": ["t_austerlitz"]}, {"flags": ["t_prussia"]}
    K = {"event": 6, "supply": 2, "camp": 1, "shop": 1, "battle": 2}
    N = [
        story("boulogne", "boulogne_orders", label="布洛涅营地", date="1805-08-27", frame=W),
        slot("amiens", "north", 5, requires=DAN, kinds=K, frame=W),
        node("reims", "supply", role="post", label="兰斯驿站", requires=DAN, frame=W),
        node("strasbourg", "supply", label="斯特拉斯堡面包站", requires=DAN, frame=W),
        slot("stuttgart", "north", 5, requires=DAN, kinds=K, frame=W),
        node("ulm", "elite", template="ulm", level=6, date="1805-10-20", weather=["rain", "mud"], requires=DAN,
             reward={"coins": {"medal": 2, "gold": 1}}, fallback="elite_a", frame=W),
        slot("donauworth", "north", 5, requires=DAN, kinds=K, frame=W),
        node("augsburg", "event", event="ev_ulm_prisoners", label="奥格斯堡·两万七千个俘虏", requires=DAN, date="1805-10-22", frame=W),
        node("munich", "camp", label="慕尼黑宿营", requires=DAN, frame=W),
        slot("braunau", "north", 5, requires=DAN, kinds=K, frame=W),
        slot("passau_1805", "north", 5, pid="passau", requires=DAN, kinds=K, frame=W),
        node("linz", "supply", role="post", label="林茨驿站", requires=DAN, frame=W),
        node("vienna_1805", "camp", role="muster", pid="vienna", label="维也纳（开拔）", requires=DAN, date="1805-11-13", frame=W + MO),
        node("mainz", "supply", label="美因茨仓库", requires=PRU, frame=W),
        slot("wurzburg", "north", 5, requires=PRU, kinds=K, frame=W),
        slot("fulda_1806", "north", 5, pid="fulda", requires=PRU, kinds=K, frame=W),
        node("bamberg", "supply", role="post", label="班贝格驿站", requires=PRU, frame=W),
        slot("hof", "north", 5, requires=PRU, kinds=K, frame=W),
        node("jena", "elite", template="jena", level=6, date="1806-10-14", weather=["fog"], requires=PRU,
             reward={"coins": {"medal": 2}}, fallback="elite_a", frame=W),
        slot("leipzig_1806", "north", 5, requires=PRU, kinds=K, frame=W),
        node("berlin_1806", "event", pid="berlin", event="ev_frederick_sword", label="柏林·腓特烈的佩剑", requires=PRU, date="1806-10-27", frame=W),
        node("kustrin", "shop", pid="kustrin", label="屈斯特林要塞的军火库", requires=PRU, frame=W),
        node("posen", "supply", role="post", label="波森驿站", requires=PRU, frame=W),
        slot("thorn_1807", "north", 5, pid="thorn", requires=PRU, kinds=K, frame=W),
        node("warsaw_1807", "camp", role="muster", pid="warsaw", label="华沙（开拔）", requires=PRU, frame=W + PO),
    ] + camp_phase([
        council("brunn", "ev_council_austerlitz", requires=DAN, label="布吕恩军议", frame=MO),
        node("zuran", "camp", label="祖兰山的草把火", requires=DAN, actions=["activity:rest", "schedule:bond_story"], date="1805-12-01", frame=MO),
        boss("austerlitz_field", "austerlitz_sun", pid="austerlitz", label="普拉岑高地", requires=DAN, date="1805-12-02", frame=MO),
        council("osterode", "ev_council_eylau", requires=PRU, label="奥斯特罗德军议", frame=PO),
        node("landsberg_ep", "camp", label="兰茨贝格雪夜", requires=PRU, actions=["activity:rest", "schedule:bond_story"], frame=PO),
        boss("eylau_field", "eylau_snow", pid="eylau", label="埃劳墓地", requires=PRU, date="1807-02-08", weather=["snow"], frame=PO),
    ])
    L = [link("boulogne", "amiens", 2, requires=DAN), link("amiens", "reims", 2), link("reims", "strasbourg", 3, supply=1),
         link("strasbourg", "stuttgart", 2), link("stuttgart", "ulm"), link("stuttgart", "donauworth", 2), link("ulm", "augsburg"),
         link("donauworth", "augsburg"), link("augsburg", "munich"), link("munich", "braunau", 2), link("braunau", "passau_1805"),
         link("passau_1805", "linz", 2), link("braunau", "linz", 3, supply=1), link("linz", "vienna_1805", 3, supply=1),
         link("boulogne", "mainz", 4, requires=PRU, supply=1), link("mainz", "wurzburg", 2), link("mainz", "fulda_1806", 2),
         link("wurzburg", "bamberg"), link("fulda_1806", "bamberg", 2), link("bamberg", "hof"), link("hof", "jena"),
         link("hof", "leipzig_1806", 2), link("jena", "berlin_1806", 3), link("leipzig_1806", "berlin_1806", 2),
         link("berlin_1806", "kustrin", 1), link("kustrin", "posen", 3, supply=1), link("berlin_1806", "posen", 4, supply=2),
         link("posen", "thorn_1807", 2), link("thorn_1807", "warsaw_1807", 2, supply=1), link("posen", "warsaw_1807", 4, supply=2),
         link("vienna_1805", "brunn", 2), link("brunn", "zuran"), link("zuran", "austerlitz_field"),
         link("warsaw_1807", "osterode", 3, supply=1), link("osterode", "landsberg_ep", 2, supply=1), link("landsberg_ep", "eylau_field")]
    rivals = [{"id": "kienmayer_hussars", "label": "奥军轻骑巡逻", "path": ["munich", "braunau", "passau_1805", "braunau"], "speed": 1, "start": 1,
               "requires": DAN, "meet": {"battle": {"template": "skirmish_hamlet", "level": 5}, "toll": {"gold": 1}}, "burns_depots": True},
              {"id": "prussian_hussars", "label": "普鲁士骠骑兵", "path": ["hof", "leipzig_1806", "berlin_1806", "leipzig_1806"], "speed": 1,
               "start": 0, "requires": PRU, "meet": {"battle": {"template": "skirmish_mill_ford", "level": 5}, "toll": {"gold": 1}}, "burns_depots": True}]
    return {"chapter": "austerlitz_jena", "view": "europe", "start": "boulogne", "days_max": 15, "stamps_need": 2,
            "muster": ["vienna_1805", "warsaw_1807"], "boss": ["austerlitz_field", "eylau_field"], "interlude": "minigame:decode",
            "frames": [{"id": "moravia_1805", "lon": [1590, 1700], "lat": [4815, 4930], "when": {"flags": ["t_austerlitz"], "mustered": True}},
                       {"id": "poland_1807", "lon": [1880, 2180], "lat": [5200, 5470], "when": {"flags": ["t_prussia"], "mustered": True}},
                       {"id": "north_1805", "lon": [80, 2350], "lat": [4760, 5530]}],
            "sets": [{"id": "danube_bread", "nodes": ["reims", "strasbourg", "linz"], "bonus": {"pass_supply": 1}}],
            "rivals": rivals, "nodes": N, "links": L}

def sheet_iberia_danube():
    W, AR, LO = ["west_1808"], ["aragon_1809"], ["lobau_1809"]
    SPA, DAN = {"flags": ["t_spain"]}, {"flags": ["t_danube"]}
    K = {"event": 6, "supply": 2, "camp": 1, "shop": 1, "battle": 2}
    N = [
        story("bayonne", "bayonne_orders", pid="bayonne", label="巴约讷·马拉克城堡", date="1808-05-10", frame=W),
        node("pamplona", "supply", role="post", label="潘普洛纳驿站", requires=SPA, frame=W),
        slot("vitoria", "iberia", 7, requires=SPA, kinds=K, frame=W),
        slot("burgos", "iberia", 7, requires=SPA, kinds=K, frame=W),
        slot("aranda", "iberia", 7, requires=SPA, kinds=K, frame=W),
        node("somosierra", "elite", template="somosierra", level=8, date="1808-11-30", weather=["fog"], requires=SPA,
             reward={"coins": {"medal": 2}}, fallback="elite_a", frame=W),
        slot("segovia", "iberia", 7, requires=SPA, kinds=K, frame=W),
        node("madrid_1808", "event", pid="madrid", event="ev_dos_de_mayo", label="马德里·五月三日", requires=SPA, date="1808-12-04", frame=W),
        node("toledo", "shop", pid="toledo", label="托莱多的刀匠街", requires=SPA, frame=W),
        slot("soria", "iberia", 7, pid="soria", requires=SPA, kinds=K, frame=W),
        node("calatayud", "supply", role="post", label="卡拉塔尤德驿站", requires=SPA, frame=W),
        node("tudela", "camp", role="muster", label="图德拉（开拔）", requires=SPA, frame=W + AR),
        slot("bordeaux", "danube", 7, requires=DAN, kinds=K, frame=W),
        node("paris_1809", "shop", pid="paris", label="巴黎·战争部的仓库", requires=DAN, frame=W),
        slot("chalons", "danube", 7, pid="chalons", requires=DAN, kinds=K, frame=W),
        node("strasbourg_1809", "supply", role="post", pid="strasbourg", label="斯特拉斯堡驿站", requires=DAN, frame=W),
        slot("augsburg_1809", "danube", 7, pid="augsburg", requires=DAN, kinds=K, frame=W),
        node("ratisbon", "event", pid="eckmuhl", event="ev_ratisbon_wound", label="雷根斯堡·皇帝的脚踝", requires=DAN, date="1809-04-23", frame=W),
        node("passau_1809", "supply", role="post", pid="passau", label="帕绍驿站", requires=DAN, frame=W),
        slot("linz_1809", "danube", 7, pid="linz", requires=DAN, kinds=K, frame=W),
        slot("melk_1809", "danube", 7, pid="melk", requires=DAN, kinds=K, frame=W),
        node("vienna_1809", "camp", role="muster", pid="vienna", label="维也纳（开拔）", requires=DAN, date="1809-05-13", frame=W + LO),
    ] + camp_phase([
        council("alagon", "ev_council_saragossa", requires=SPA, label="阿拉贡军议", frame=AR),
        node("casetas", "camp", label="卡塞塔斯的废磨坊", requires=SPA, actions=["activity:rest", "schedule:bond_story"], frame=AR),
        boss("saragossa_city", "saragossa_siege", pid="saragossa", label="萨拉戈萨", requires=SPA, date="1809-02-10", frame=AR),
        council("ebersdorf", "ev_council_wagram", requires=DAN, label="埃伯斯多夫军议", frame=LO),
        node("aspern", "elite", pid="aspern_essling", template="aspern", level=8, date="1809-05-21", requires=DAN, weather=["clear"],
             reward={"coins": {"medal": 2}}, fallback="elite_a", frame=LO),
        node("lobau", "camp", label="洛鲍岛营地", requires=DAN, actions=["activity:rest", "schedule:bond_story", "build"], frame=LO),
        boss("wagram_field", "wagram_lobau", pid="wagram", label="瓦格拉姆", requires=DAN, date="1809-07-05", weather=["rain", "clear"], frame=LO),
    ])
    L = [link("bayonne", "pamplona", 2, requires=SPA), link("pamplona", "vitoria", 2), link("vitoria", "burgos", 2),
         link("burgos", "aranda", 2), link("aranda", "somosierra"), link("somosierra", "madrid_1808", 2), link("aranda", "segovia", 2),
         link("segovia", "madrid_1808", 2, toll={"gold": 1}), link("madrid_1808", "toledo", 2), link("madrid_1808", "calatayud", 4, supply=1),
         link("aranda", "soria", 2), link("soria", "calatayud", 2), link("soria", "tudela", 2), link("calatayud", "tudela", 2),
         link("bayonne", "bordeaux", 2, requires=DAN), link("bordeaux", "paris_1809", 4, supply=1), link("paris_1809", "chalons", 2),
         link("chalons", "strasbourg_1809", 3), link("strasbourg_1809", "augsburg_1809", 3, supply=1), link("augsburg_1809", "ratisbon", 2),
         link("ratisbon", "passau_1809", 2), link("augsburg_1809", "passau_1809", 3, supply=1), link("passau_1809", "linz_1809"),
         link("linz_1809", "melk_1809", 2), link("melk_1809", "vienna_1809", 2), link("linz_1809", "vienna_1809", 4, supply=1),
         link("tudela", "alagon", 2), link("alagon", "casetas"), link("casetas", "saragossa_city"),
         link("vienna_1809", "ebersdorf"), link("ebersdorf", "aspern"), link("aspern", "lobau"), link("ebersdorf", "lobau"),
         link("lobau", "wagram_field", 2)]
    rivals = [{"id": "guerrilla_band", "label": "游击队", "path": ["vitoria", "burgos", "aranda", "burgos"], "speed": 1, "start": 0,
               "requires": SPA, "meet": {"battle": {"template": "skirmish_terraces", "level": 7}, "toll": {"gold": 1}}, "burns_depots": True}]
    return {"chapter": "iberia_danube", "view": "europe", "start": "bayonne", "days_max": 12, "stamps_need": 2,
            "muster": ["tudela", "vienna_1809"], "boss": ["saragossa_city", "wagram_field"], "interlude": "audience",
            "frames": [{"id": "aragon_1809", "lon": [-200, -40], "lat": [4130, 4230], "when": {"flags": ["t_spain"], "mustered": True}},
                       {"id": "lobau_1809", "lon": [1625, 1675], "lat": [4812, 4832], "when": {"flags": ["t_danube"], "mustered": True}},
                       {"id": "west_1808", "lon": [-520, 1720], "lat": [3950, 5000]}],
            "sets": [{"id": "camino", "nodes": ["pamplona", "calatayud"], "bonus": {"pass_supply": 1}}],
            "rivals": rivals, "nodes": N, "links": L}

def sheet_russia():
    W, R = ["russia_1812"], ["retreat_1812"]
    K = {"event": 6, "supply": 2, "camp": 1, "shop": 1, "battle": 2}
    N = [
        story("kovno_1812", "russia_niemen", pid="kovno", label="科夫诺·涅曼河浮桥", date="1812-06-24", frame=W),
        node("vilna_1812", "supply", pid="vilna", label="维尔纳仓库", frame=W, date="1812-06-28"),
        slot("minsk", "russia", 8, kinds=K, frame=W),
        slot("glubokoye", "russia", 8, kinds=K, frame=W),
        slot("polotsk", "russia", 8, kinds=K, frame=W),
        node("vitebsk", "supply", role="post", label="维捷布斯克驿站", frame=W),
        node("smolensk", "event", event="ev_smolensk_granary", label="斯摩棱斯克（还在烧）", date="1812-08-18", frame=W),
        slot("dorogobuzh", "russia", 8, kinds=K, frame=W),
        node("vyazma", "supply", role="post", label="维亚济马驿站", frame=W),
        slot("gzhatsk", "russia", 8, kinds=K, frame=W),
        story("borodino_field", "russia_borodino", pid="borodino", label="博罗季诺", date="1812-09-07", frame=W),
        node("moscow", "camp", role="muster", label="莫斯科（大火之后）", date="1812-10-19", frame=W + R),
    ] + camp_phase([
        council("maloyaroslavets", "ev_council_retreat", label="小雅罗斯拉韦茨军议", date="1812-10-25", frame=R),
        node("krasnoi", "elite", template="krasnoi", level=9, date="1812-11-17", weather=["snow"],
             reward={"coins": {"medal": 2}}, fallback="elite_a", frame=R),
        node("orsha", "camp", label="奥尔沙（埃布莱留下的工具车）", actions=["activity:rest", "schedule:bond_story", "build"], date="1812-11-20", frame=R),
        boss("studianka", "russia_berezina", pid="berezina", label="斯图江卡·别列津纳河", date="1812-11-27", weather=["snow"], frame=R),
    ])
    L = [link("kovno_1812", "vilna_1812", 2), link("vilna_1812", "glubokoye", 3, supply=1), link("vilna_1812", "minsk", 3, supply=1),
         link("glubokoye", "polotsk", 2), link("glubokoye", "vitebsk", 3), link("polotsk", "vitebsk", 2), link("minsk", "vitebsk", 4, supply=2),
         link("vitebsk", "smolensk", 3, supply=1), link("smolensk", "dorogobuzh", 2), link("dorogobuzh", "vyazma"),
         link("smolensk", "vyazma", 3, supply=2), link("vyazma", "gzhatsk"), link("gzhatsk", "borodino_field"),
         link("vyazma", "borodino_field", 2, supply=1), link("borodino_field", "moscow", 2),
         link("moscow", "maloyaroslavets", 2), link("maloyaroslavets", "krasnoi", 4, supply=2), link("krasnoi", "orsha", 2),
         link("maloyaroslavets", "orsha", 4, supply=3, label="老路（来时烧光的）"), link("orsha", "studianka", 2, supply=1)]
    rivals = [{"id": "cossacks", "label": "哥萨克", "path": ["dorogobuzh", "vyazma", "gzhatsk", "vyazma"], "speed": 1, "start": 0,
               "meet": {"battle": {"template": "skirmish_hamlet", "level": 8}, "toll": {"supply": 2}}, "burns_depots": True},
              {"id": "partisans", "label": "达维多夫的游击队", "path": ["polotsk", "glubokoye", "vilna_1812", "minsk", "vilna_1812", "glubokoye"],
               "speed": 1, "start": 1, "meet": {"battle": {"template": "skirmish_mill_ford", "level": 8}, "toll": {"gold": 1}}, "burns_depots": True}]
    return {"chapter": "russia", "view": "europe", "start": "kovno_1812", "days_max": 17, "stamps_need": 2,
            "muster": "moscow", "boss": "studianka", "interlude": "camp_night",
            "frames": [{"id": "retreat_1812", "lon": [2750, 3820], "lat": [5380, 5620], "when": {"mustered": True}},
                       {"id": "russia_1812", "lon": [2250, 3900], "lat": [5300, 5700]}],
            "sets": [{"id": "magazines", "nodes": ["vilna_1812", "vitebsk", "vyazma"], "bonus": {"pass_supply": 1}}],
            "rivals": rivals, "nodes": N, "links": L}

def sheet_collapse():
    W, LZ, FR = ["saxony_1813"], ["leipzig_1813"], ["france_1814"]
    K = {"event": 6, "supply": 2, "camp": 1, "shop": 1, "battle": 2}
    N = [
        story("lutzen", "collapse_lutzen", label="吕岑", date="1813-05-02", frame=W),
        slot("halle", "collapse", 9, pid="halle", kinds=K, frame=W),
        slot("naumburg", "collapse", 9, kinds=K, frame=W),
        slot("altenburg", "collapse", 9, kinds=K, frame=W),
        node("chemnitz", "supply", role="post", label="开姆尼茨驿站", frame=W),
        node("dresden_1813", "elite", pid="dresden", template="dresden", level=10, date="1813-08-26", weather=["rain"],
             reward={"coins": {"medal": 2, "gold": 1}}, fallback="elite_a", frame=W),
        slot("meissen", "collapse", 9, pid="meissen", kinds=K, frame=W),
        slot("bautzen", "collapse", 9, kinds=K, frame=W),
        slot("gorlitz", "collapse", 9, kinds=K, frame=W),
        node("torgau", "shop", label="托尔高要塞的军需库", frame=W),
        node("wittenberg", "supply", role="post", label="维滕贝格驿站", frame=W),
        node("duben", "camp", role="muster", label="迪本（开拔）", date="1813-10-10", frame=W + LZ),
    ] + camp_phase([
        council("eilenburg", "ev_council_leipzig", label="艾伦堡军议", frame=LZ),
        node("wachau", "camp", label="瓦豪的营火", actions=["activity:rest", "schedule:bond_story"], frame=LZ),
        boss("leipzig_field", "collapse_leipzig", pid="leipzig", label="莱比锡·普罗布斯泰达", date="1813-10-18", frame=LZ + FR),
        node("erfurt_1813", "camp", pid="erfurt", label="爱尔福特（收拢残部）", actions=["activity:rest", "schedule:recruit"], date="1813-10-24", frame=FR),
        node("hanau", "elite", template="hanau", level=10, date="1813-10-30", reward={"coins": {"medal": 1, "supply": 3}},
             fallback="elite_a", frame=FR),
        node("mainz_1813", "camp", pid="mainz", label="美因茨（伤寒营）", actions=["activity:rest", "schedule:bond_story"], frame=FR),
        node("montmirail", "event", event="ev_six_days", label="蒙米赖·六日战役", date="1814-02-11", frame=FR),
        story("fontainebleau_1814", "collapse_fontainebleau", pid="fontainebleau", label="枫丹白露·白马庭院", date="1814-04-20", frame=FR),
    ])
    L = [link("lutzen", "naumburg"), link("lutzen", "altenburg"), link("lutzen", "halle"), link("halle", "wittenberg", 3),
         link("naumburg", "altenburg", 2), link("altenburg", "chemnitz"), link("chemnitz", "dresden_1813", 2),
         link("altenburg", "torgau", 3), link("dresden_1813", "meissen"), link("meissen", "torgau", 2), link("dresden_1813", "bautzen", 2),
         link("bautzen", "gorlitz"), link("gorlitz", "torgau", 4, supply=1), link("chemnitz", "meissen", 2),
         link("torgau", "wittenberg"), link("torgau", "duben"), link("wittenberg", "duben"),
         link("duben", "eilenburg"), link("eilenburg", "wachau", 2), link("wachau", "leipzig_field"),
         link("leipzig_field", "erfurt_1813", 3, supply=1), link("erfurt_1813", "hanau", 3), link("hanau", "mainz_1813"),
         link("erfurt_1813", "mainz_1813", 4, supply=2), link("mainz_1813", "montmirail", 4), link("montmirail", "fontainebleau_1814", 2)]
    rivals = [{"id": "cossacks_1813", "label": "哥萨克", "path": ["bautzen", "gorlitz", "bautzen", "dresden_1813"], "speed": 1, "start": 0,
               "meet": {"battle": {"template": "skirmish_hamlet", "level": 9}, "toll": {"supply": 2}}, "burns_depots": True}]
    return {"chapter": "collapse", "view": "europe", "start": "lutzen", "days_max": 10, "stamps_need": 2,
            "muster": "duben", "boss": "leipzig_field", "interlude": "bond",
            "frames": [{"id": "france_1814", "lon": [180, 1300], "lat": [4800, 5170], "when": {"scene_done": "collapse_leipzig"}},
                       {"id": "leipzig_1813", "lon": [1190, 1300], "lat": [5115, 5170], "when": {"mustered": True}},
                       {"id": "saxony_1813", "lon": [1080, 1560], "lat": [5040, 5220]}],
            "sets": [{"id": "elbe", "nodes": ["chemnitz", "wittenberg"], "bonus": {"pass_supply": 1}}],
            "rivals": rivals, "nodes": N, "links": L}

def sheet_elba():
    isl = ["portoferraio", "san_martino", "procchio", "marciana", "marina_di_campo", "capoliveri", "porto_longone", "rio_marina",
           "volterraio", "lacona", "cavo"]
    xy = local_fit({i: place(i)[:2] for i in isl}, (10.10, 10.46), (42.71, 42.88))
    I, T = ["elba_island"], ["portoferraio_1815"]
    K = {"event": 6, "supply": 2, "camp": 1, "shop": 1, "battle": 2}
    N = [
        story("portoferraio", "elba_arrival", label="费拉约港", date="1814-05-04", actions=["visit:town", "trade:fair"], frame=I),
        node("san_martino", "camp", role="muster", label="圣马蒂诺别墅（开拔）", frame=I + T),
        node("procchio", "supply", role="intel", label="普罗基奥的盐仓（密探联络）", frame=I),
        slot("marciana", "elba", 10, frame=I, kinds={"event": 6, "camp": 2, "shop": 1}),
        slot("marina_di_campo", "elba", 10, kinds=K, frame=I),
        slot("lacona", "elba", 10, kinds=K, frame=I),
        slot("capoliveri", "elba", 10, frame=I, kinds={"event": 6, "supply": 2, "camp": 1}),
        node("porto_longone", "supply", role="post", label="隆戈内港要塞", frame=I),
        node("rio_marina", "supply", role="project", label="里奥铁矿", frame=I),
        node("volterraio", "supply", role="post", label="沃尔泰拉约古堡（信号塔）", frame=I),
        slot("cavo", "elba", 10, kinds=K, frame=I),
    ] + camp_phase([
        council("forte_falcone", "ev_council_elba", pid="portoferraio", label="法尔科内堡军议", frame=T),
        node("molo", "event", pid="portoferraio", event="ev_pharaon_elba", label="码头·法老号靠岸", date="1815-02-20", frame=T),
        node("forte_stella", "camp", pid="portoferraio", label="星堡的夜", actions=["activity:rest", "schedule:bond_story"], frame=T),
        boss("darsena", "elba_night", pid="portoferraio", label="码头仓库", date="1815-02-24", frame=T),
        node("mulini", "branch", pid="portoferraio", scene="elba_1815", label="穆利尼宫", date="1815-02-25", frame=T),
    ])
    town = {"san_martino": [210, 860], "forte_falcone": [560, 300], "molo": [1430, 760], "forte_stella": [1010, 230],
            "darsena": [1180, 620], "mulini": [800, 170]}
    for n in N:
        n["xy"] = xy[n["id"]] if n["id"] in xy else town[n["id"]]
        if n["id"] == "san_martino":
            n["xy_frames"] = {"portoferraio_1815": town["san_martino"]}
    L = [link("portoferraio", "volterraio"), link("portoferraio", "procchio", 2), link("procchio", "san_martino"),
         link("procchio", "marciana", 2, supply=1), link("procchio", "marina_di_campo"), link("marciana", "marina_di_campo", 2),
         link("marina_di_campo", "lacona"), link("lacona", "san_martino"), link("lacona", "capoliveri"),
         link("capoliveri", "porto_longone"), link("porto_longone", "rio_marina", 2), link("volterraio", "rio_marina"),
         link("volterraio", "porto_longone", 2), link("rio_marina", "cavo"), link("volterraio", "cavo", 2),
         link("san_martino", "forte_falcone"), link("forte_falcone", "forte_stella"), link("forte_falcone", "molo"),
         link("molo", "forte_stella"), link("forte_stella", "darsena"), link("darsena", "mulini")]
    rivals = [{"id": "campbell_cutter", "label": "坎贝尔上校的快艇", "path": ["porto_longone", "rio_marina", "cavo", "volterraio", "porto_longone"],
               "speed": 1, "start": 0, "meet": {"toll": {"intel": 1}, "effects": {"heat": 4}}, "burns_depots": False}]
    return {"chapter": "elba", "view": "elba_1814", "start": "portoferraio", "days_max": 9, "stamps_need": 2,
            "muster": "san_martino", "boss": "darsena", "interlude": "minigame:weigh",
            "frames": [{"id": "portoferraio_1815", "view": "portoferraio_1815", "when": {"mustered": True}},
                       {"id": "elba_island", "view": "elba_1814"}],
            "sets": [], "rivals": rivals, "nodes": N, "links": L}

def sheet_hundred_days():
    RN, FR, BE = ["route_napoleon"], ["france_1815"], ["belgium_1815"]
    K = {"event": 5, "supply": 2, "camp": 2, "shop": 1, "battle": 2}
    N = [
        story("golfe_juan", "k_golfe_juan", label="儒安湾", date="1815-03-01", frame=RN),
        slot("grasse", "hundred_days", 12, frame=RN, kinds={"event": 5, "supply": 2, "camp": 2, "shop": 1}),
        slot("castellane", "hundred_days", 12, kinds=K, frame=RN),
        node("digne", "supply", role="post", label="迪涅驿站", frame=RN),
        slot("sisteron", "hundred_days", 12, kinds=K, frame=RN),
        slot("gap", "hundred_days", 12, kinds=K, frame=RN),
        story("laffrey", "k_laffrey", label="拉弗雷·相遇的草地", date="1815-03-07", frame=RN),
        node("grenoble", "supply", label="格勒诺布尔兵工厂", date="1815-03-07", frame=RN),
        slot("vienne", "hundred_days", 12, pid="vienne", kinds=K, frame=RN),
        node("lyon_1815", "shop", pid="lyon", label="里昂（丝绸商与新兵）", date="1815-03-10", frame=RN + FR),
        slot("macon", "hundred_days", 12, kinds=K, frame=FR),
        node("chalon", "supply", role="post", label="沙隆驿站", frame=FR),
        node("auxerre", "event", event="ev_ney_auxerre", label="欧塞尔·内伊的铁笼", date="1815-03-17", frame=FR),
        slot("fontainebleau_1815", "hundred_days", 12, pid="fontainebleau", kinds=K, frame=FR),
        story("paris_1815", "k_tuileries", pid="paris", label="巴黎·杜伊勒里宫", date="1815-03-20",
              actions=["visit:town", "visit:backdoor", "trade:fair", "trade:counterfeit"], frame=FR),
        node("war_ministry", "event", pid="paris", event="ev_morrel_petition", label="战争部·档案室", requires={"scene_done": "k_tuileries"},
             offset=[64, -56], frame=FR),
        slot("soissons", "hundred_days", 12, pid="soissons", kinds=K, frame=FR),
        slot("laon", "hundred_days", 12, kinds=K, frame=FR),
        node("avesnes", "supply", role="post", label="阿韦讷驿站", frame=FR),
        node("beaumont", "camp", role="muster", label="博蒙（北方军团集结）", date="1815-06-14", frame=FR + BE),
    ] + camp_phase([
        story("charleroi", "k_charleroi", label="沙勒罗瓦桥", date="1815-06-15", frame=BE),
        council("fleurus", "ev_council_fleurus", label="弗勒吕斯军议", date="1815-06-16", frame=BE),
        node("ligny", "elite", label="利尼", template="ligny", level=13, date="1815-06-16", weather=["clear", "rain"],
             reward={"coins": {"medal": 2}}, frame=BE),
        node("quatre_bras", "elite", template="quatre_bras", level=13, date="1815-06-16", weather=["clear"],
             reward={"coins": {"medal": 2}}, frame=BE),
        node("genappe", "camp", label="热纳普的雨夜", actions=["activity:rest", "schedule:bond_story"], date="1815-06-17", frame=BE),
        boss("waterloo_field", "k_waterloo", pid="plancenoit", label="滑铁卢·普朗斯努瓦", date="1815-06-18", weather=["mud"], frame=BE),
        story("waterloo_inn", "k_waterloo_night", label="滑铁卢村·客栈", date="1815-06-18", frame=BE),
    ])
    L = [link("golfe_juan", "grasse"), link("grasse", "castellane", 2), link("golfe_juan", "castellane", 2, supply=1),
         link("castellane", "digne"), link("digne", "sisteron"), link("sisteron", "gap"), link("digne", "gap", 2, supply=1),
         link("gap", "laffrey", 2), link("sisteron", "laffrey", 3, supply=1), link("laffrey", "grenoble"), link("grenoble", "vienne", 2),
         link("vienne", "lyon_1815"), link("grenoble", "lyon_1815", 3, supply=1), link("lyon_1815", "macon", 2),
         link("macon", "chalon"), link("chalon", "auxerre", 3), link("lyon_1815", "auxerre", 4, supply=2),
         link("auxerre", "fontainebleau_1815", 2), link("fontainebleau_1815", "paris_1815"), link("auxerre", "paris_1815", 3, supply=1),
         link("paris_1815", "war_ministry"), link("paris_1815", "soissons", 2), link("war_ministry", "soissons", 2),
         link("soissons", "laon"), link("laon", "avesnes", 2), link("avesnes", "beaumont"), link("soissons", "avesnes", 3, supply=1),
         link("beaumont", "charleroi"), link("charleroi", "fleurus"), link("fleurus", "ligny"), link("fleurus", "quatre_bras"),
         link("ligny", "genappe", 2), link("quatre_bras", "genappe"), link("fleurus", "genappe", 2),
         link("genappe", "waterloo_field"), link("waterloo_field", "waterloo_inn")]
    rivals = [{"id": "royalist_volunteers", "label": "王党志愿军", "path": ["macon", "chalon", "macon", "lyon_1815"], "speed": 1, "start": 0,
               "meet": {"battle": {"template": "skirmish_brabant_farm", "level": 12}, "toll": {"gold": 1}}, "burns_depots": True},
              {"id": "rival_contractor", "label": "对手承包商（白鹳商行）", "path": ["laon", "avesnes", "laon", "soissons"], "speed": 1,
               "start": 1, "requires": {"flags": ["t_storks_hostile"]}, "meet": {"toll": {"supply": 3}}, "buys_depots": True}]
    return {"chapter": "hundred_days", "view": "europe", "start": "golfe_juan", "days_max": 16, "stamps_need": 2,
            "muster": "beaumont", "boss": "waterloo_field", "interlude": "audience",
            "frames": [{"id": "belgium_1815", "lon": [390, 490], "lat": [5015, 5095], "when": {"mustered": True}},
                       {"id": "france_1815", "lon": [180, 560], "lat": [4540, 5040], "when": {"scene_done": "k_laffrey"}},
                       {"id": "route_napoleon", "lon": [430, 760], "lat": [4340, 4590]}],
            "sets": [{"id": "route_napoleon", "nodes": ["digne", "grenoble"], "bonus": {"pass_supply": 1}}],
            "rivals": rivals, "nodes": N, "links": L}

def sheet_rhine():
    W, LA = ["lowlands_rhine"], ["lauter_1815"]
    K = {"event": 5, "supply": 2, "camp": 2, "shop": 1, "battle": 2}
    N = [
        story("brussels_1815", "k_brussels", pid="brussels", label="布鲁塞尔", date="1815-06-20", frame=W),
        slot("antwerp_1815", "rhine", 14, pid="antwerp", kinds=K, frame=W),
        node("namur", "supply", role="post", label="那慕尔驿站", frame=W),
        slot("liege", "rhine", 14, kinds=K, frame=W),
        slot("maastricht", "rhine", 14, pid="maastricht", kinds=K, frame=W),
        node("luxembourg", "supply", role="post", label="卢森堡要塞", frame=W),
        slot("thionville", "rhine", 14, pid="thionville", kinds=K, frame=W),
        story("metz_1815", "k_ultimatum", pid="metz", label="梅斯·会议厅", date="1815-07-20", frame=W),
        slot("verdun", "rhine", 14, pid="verdun", kinds=K, frame=W),
        node("nancy", "event", event="ev_marie_louise_letter", label="南锡·维也纳来的信", frame=W),
        node("saverne", "shop", label="萨韦尔讷山口的骡马市", frame=W),
        node("strasbourg_1815", "camp", role="muster", pid="strasbourg", label="斯特拉斯堡（开拔）", frame=W + LA),
    ] + camp_phase([
        council("haguenau", "ev_council_rhine", label="阿格诺军议", frame=LA),
        node("seltz", "camp", label="塞尔茨渡口的营火", actions=["activity:rest", "schedule:bond_story"], frame=LA),
        boss("wissembourg", "k_rhine", label="维桑堡防线·劳特河", date="1815-09-02", weather=["rain", "clear"], frame=LA),
    ])
    L = [link("brussels_1815", "antwerp_1815", 2), link("brussels_1815", "namur", 2), link("antwerp_1815", "maastricht", 3),
         link("namur", "liege", 2), link("liege", "maastricht"), link("namur", "luxembourg", 3, supply=1), link("liege", "luxembourg", 3),
         link("maastricht", "luxembourg", 4, supply=1), link("luxembourg", "thionville"), link("thionville", "metz_1815"),
         link("luxembourg", "metz_1815", 2), link("metz_1815", "verdun", 2), link("metz_1815", "nancy", 2), link("nancy", "saverne", 2),
         link("metz_1815", "saverne", 3, supply=1), link("saverne", "strasbourg_1815"), link("strasbourg_1815", "haguenau"),
         link("haguenau", "seltz"), link("seltz", "wissembourg")]
    return {"chapter": "rhine", "view": "europe", "start": "brussels_1815", "days_max": 12, "stamps_need": 2,
            "muster": "strasbourg_1815", "boss": "wissembourg", "interlude": "camp_night",
            "frames": [{"id": "lauter_1815", "lon": [740, 850], "lat": [4850, 4915], "when": {"mustered": True}},
                       {"id": "lowlands_rhine", "lon": [350, 900], "lat": [4820, 5140]}],
            "sets": [], "rivals": [{"id": "prussian_rearguard", "label": "普军后卫", "path": ["liege", "namur", "liege", "maastricht"], "speed": 1, "start": 0,
                                    "meet": {"battle": {"template": "skirmish_brabant_farm", "level": 14}, "toll": {"gold": 1}}, "burns_depots": True}],
            "nodes": N, "links": L}

def sheet_vienna():
    W, V = ["danube_1816"], ["vienna_1816"]
    K = {"event": 5, "supply": 2, "camp": 2, "shop": 1, "battle": 2}
    N = [
        story("munich_1816", "k_bavaria", pid="munich", label="慕尼黑·宁芬堡宫", date="1816-04-10", frame=W),
        slot("landshut", "vienna", 16, kinds=K, frame=W),
        slot("kufstein", "vienna", 16, frame=W, kinds={"event": 4, "camp": 1, "battle": 3}, label="库夫施泰因（蒂罗尔山口）"),
        node("salzburg", "supply", role="post", label="萨尔茨堡驿站", frame=W),
        node("passau_1816", "supply", role="post", pid="passau", label="帕绍驿站", frame=W),
        slot("braunau_1816", "vienna", 16, pid="braunau", kinds=K, frame=W),
        node("linz_1816", "shop", pid="linz", label="林茨的多瑙河船坞", frame=W),
        slot("wels", "vienna", 16, pid="wels", kinds=K, frame=W),
        slot("steyr", "vienna", 16, pid="steyr", kinds=K, frame=W),
        node("melk", "event", event="ev_melk_library", label="梅尔克修道院的图书馆", frame=W),
        node("st_polten", "camp", role="muster", label="圣珀尔滕（开拔）", frame=W + V),
    ] + camp_phase([
        council("purkersdorf", "ev_council_vienna", label="普尔克斯多夫军议", frame=V),
        node("laxenburg", "camp", label="拉克森堡的林苑", actions=["activity:rest", "schedule:bond_story"], frame=V),
        boss("vienna_1816", "k_vienna", pid="vienna", label="维也纳城墙", date="1816-06-12", frame=V),
        story("schoenbrunn", "k_schoenbrunn", label="美泉宫", date="1816-06-14", frame=V),
    ])
    L = [link("munich_1816", "landshut", 2), link("munich_1816", "kufstein", 2), link("kufstein", "salzburg", 2),
         link("landshut", "passau_1816", 2), link("landshut", "braunau_1816", 2), link("braunau_1816", "passau_1816"),
         link("braunau_1816", "salzburg", 2), link("salzburg", "steyr", 3, supply=1), link("passau_1816", "linz_1816", 2),
         link("linz_1816", "wels"), link("wels", "steyr"), link("linz_1816", "melk", 2), link("steyr", "melk", 2),
         link("melk", "st_polten"), link("linz_1816", "st_polten", 3, supply=1),
         link("st_polten", "purkersdorf", 2), link("purkersdorf", "laxenburg", 2), link("laxenburg", "vienna_1816"),
         link("vienna_1816", "schoenbrunn")]
    return {"chapter": "vienna", "view": "europe", "start": "munich_1816", "days_max": 12, "stamps_need": 2,
            "muster": "st_polten", "boss": "vienna_1816", "interlude": "bond",
            "frames": [{"id": "vienna_1816", "lon": [1550, 1660], "lat": [4800, 4835], "when": {"mustered": True}},
                       {"id": "danube_1816", "lon": [1080, 1680], "lat": [4720, 4890]}],
            "sets": [], "rivals": [{"id": "tyrolean_riflemen", "label": "蒂罗尔射手", "path": ["kufstein", "salzburg", "kufstein"], "speed": 1,
                                    "start": 0, "meet": {"battle": {"template": "skirmish_brabant_farm", "level": 16}, "toll": {"gold": 1}},
                                    "burns_depots": True}],
            "nodes": N, "links": L}

def sheet_iberia_channel():
    W, IB, TV, CH, KE = ["west_1817"], ["iberia_1817"], ["torres_1817"], ["channel_1817"], ["kent_1817"]
    IBR, CHN = {"flags": ["k_iberia"]}, {"flags": ["k_channel"]}
    K = {"event": 5, "supply": 2, "camp": 2, "shop": 1, "battle": 2}
    N = [
        story("boulogne_1817", "k_choice_1817", pid="boulogne", label="布洛涅·皇帝的木屋", date="1817-03-01", frame=W + CH),
        node("bayonne_1817", "supply", role="post", pid="bayonne", label="巴约讷驿站", requires=IBR, frame=W + IB),
        slot("vitoria_1817", "iberia_channel", 18, pid="vitoria", requires=IBR, kinds=K, frame=IB),
        slot("burgos_1817", "iberia_channel", 18, pid="burgos", requires=IBR, kinds=K, frame=IB),
        slot("valladolid", "iberia_channel", 18, requires=IBR, kinds=K, frame=IB),
        node("salamanca", "event", event="ev_arapiles_bones", label="萨拉曼卡·阿拉皮莱斯的白骨", requires=IBR, frame=IB),
        slot("ciudad_rodrigo", "iberia_channel", 18, requires=IBR, kinds=K, frame=IB),
        slot("guarda", "iberia_channel", 18, pid="guarda", requires=IBR, kinds=K, frame=IB),
        node("coimbra", "supply", role="post", label="科英布拉驿站", requires=IBR, frame=IB),
        node("santarem", "camp", role="muster", label="圣塔伦（开拔）", requires=IBR, frame=IB + TV),
        node("etaples", "supply", role="post", label="埃塔普勒的平底船", requires=CHN, frame=CH),
        slot("abbeville", "iberia_channel", 18, pid="abbeville", requires=CHN, kinds=K, frame=CH),
        node("saint_omer", "supply", role="post", pid="saint_omer", label="圣奥梅尔驿站", requires=CHN, frame=CH),
        slot("cassel", "iberia_channel", 18, pid="cassel", requires=CHN, kinds=K, frame=CH),
        slot("lille", "iberia_channel", 18, pid="lille", requires=CHN, kinds=K, frame=CH),
        node("dunkirk", "event", event="ev_fulton_nautilus", label="敦刻尔克·美国人的潜水船", requires=CHN, frame=CH),
        slot("ostend", "iberia_channel", 18, requires=CHN, kinds=K, frame=CH),
        slot("bruges", "iberia_channel", 18, pid="bruges", requires=CHN, kinds=K, frame=CH),
        node("antwerp_1817", "shop", pid="antwerp", label="安特卫普造船厂", requires=CHN, frame=CH),
        node("calais", "camp", role="muster", label="加来（开拔）", requires=CHN, frame=CH + KE),
    ] + camp_phase([
        council("alenquer", "ev_council_torres", requires=IBR, label="阿伦克尔军议", frame=TV),
        node("sobral", "camp", label="索布拉尔的雨夜", requires=IBR, actions=["activity:rest", "schedule:bond_story"], frame=TV),
        boss("torres_vedras", "k_torres_vedras", label="托雷斯韦德拉什防线", requires=IBR, date="1817-10-14", frame=TV),
        council("gris_nez", "ev_council_channel", requires=CHN, label="灰鼻角军议", frame=KE),
        node("hythe", "camp", label="海斯海滩的夜", requires=CHN, actions=["activity:rest", "schedule:bond_story"], frame=KE),
        boss("dover", "k_dover", label="多佛尔的白崖", requires=CHN, date="1817-08-19", frame=KE),
    ])
    L = [link("boulogne_1817", "bayonne_1817", 4, requires=IBR, supply=1), link("bayonne_1817", "vitoria_1817", 2),
         link("vitoria_1817", "burgos_1817", 2), link("burgos_1817", "valladolid", 2), link("valladolid", "salamanca", 2),
         link("salamanca", "ciudad_rodrigo", 2), link("ciudad_rodrigo", "guarda", 2), link("guarda", "coimbra", 2, supply=1),
         link("salamanca", "coimbra", 4, supply=2), link("coimbra", "santarem", 2),
         link("boulogne_1817", "etaples", 1, requires=CHN), link("etaples", "abbeville", 2), link("boulogne_1817", "saint_omer", 2, requires=CHN),
         link("abbeville", "saint_omer", 3), link("saint_omer", "cassel"), link("cassel", "lille", 2), link("cassel", "dunkirk", 2),
         link("lille", "bruges", 2), link("dunkirk", "ostend", 2), link("ostend", "bruges"), link("bruges", "antwerp_1817", 2),
         link("dunkirk", "calais", 2), link("saint_omer", "calais", 2), link("etaples", "calais", 3, supply=1),
         link("santarem", "alenquer", 2), link("alenquer", "sobral"), link("sobral", "torres_vedras"),
         link("calais", "gris_nez"), voyage("gris_nez", "hythe", 1), link("hythe", "dover")]
    return {"chapter": "iberia_channel", "view": "europe", "start": "boulogne_1817", "days_max": 11, "stamps_need": 2,
            "muster": ["santarem", "calais"], "boss": ["torres_vedras", "dover"], "interlude": "audience",
            "frames": [{"id": "torres_1817", "lon": [-960, -840], "lat": [3870, 3960], "when": {"flags": ["k_iberia"], "mustered": True}},
                       {"id": "kent_1817", "lon": [80, 210], "lat": [5075, 5125], "when": {"flags": ["k_channel"], "mustered": True}},
                       {"id": "iberia_1817", "lon": [-1000, -80], "lat": [3850, 4370], "when": {"flags": ["k_iberia"]}},
                       {"id": "channel_1817", "lon": [-50, 500], "lat": [4980, 5220], "when": {"flags": ["k_channel"]}},
                       {"id": "west_1817", "lon": [-600, 500], "lat": [4250, 5200]}],
            "sets": [], "rivals": [], "nodes": N, "links": L}

def sheet_niemen():
    W, NI = ["poland_1818"], ["niemen_1818"]
    K = {"event": 5, "supply": 2, "camp": 2, "shop": 1, "battle": 2}
    N = [
        story("warsaw_1818", "k_warsaw", pid="warsaw", label="华沙·王宫", date="1818-05-03", frame=W),
        node("posen_1818", "supply", role="post", pid="posen", label="波森驿站", frame=W),
        slot("plock", "niemen", 20, pid="plock", kinds=K, frame=W),
        slot("thorn", "niemen", 20, kinds=K, frame=W),
        node("danzig", "shop", label="但泽的粮商", frame=W),
        slot("konigsberg", "niemen", 20, kinds=K, frame=W),
        node("tilsit_1818", "event", pid="tilsit", event="ev_tilsit_raft", label="提尔西特·河心的木筏", frame=W),
        slot("ostrolenka", "niemen", 20, kinds=K, frame=W),
        slot("bialystok", "niemen", 20, kinds=K, frame=W),
        node("grodno", "supply", role="post", label="格罗德诺仓库", frame=W),
        node("vilkaviskis", "camp", role="muster", label="维尔卡维什基斯（开拔）", frame=W + NI),
    ] + camp_phase([
        council("mariampol", "ev_council_niemen", label="马里扬波尔军议", frame=NI),
        node("pilviskiai", "camp", label="皮尔维什基艾的营火", actions=["activity:rest", "schedule:bond_story"], frame=NI),
        boss("kovno_1818", "k_niemen", pid="kovno", label="科夫诺·涅曼河", date="1818-06-24", frame=NI),
    ])
    L = [link("warsaw_1818", "plock", 2), link("plock", "posen_1818", 3), link("warsaw_1818", "ostrolenka", 2), link("plock", "thorn", 2),
         link("posen_1818", "thorn", 2), link("thorn", "danzig", 3), link("danzig", "konigsberg", 3, supply=1), link("konigsberg", "tilsit_1818", 2),
         link("tilsit_1818", "vilkaviskis", 2), link("ostrolenka", "bialystok", 2), link("bialystok", "grodno"),
         link("grodno", "vilkaviskis", 3, supply=1), link("ostrolenka", "thorn", 3), link("konigsberg", "grodno", 4, supply=1),
         link("vilkaviskis", "mariampol"), link("mariampol", "pilviskiai"), link("pilviskiai", "kovno_1818", 2)]
    return {"chapter": "niemen", "view": "europe", "start": "warsaw_1818", "days_max": 12, "stamps_need": 2,
            "muster": "vilkaviskis", "boss": "kovno_1818", "interlude": "minigame:decode",
            "frames": [{"id": "niemen_1818", "lon": [2260, 2440], "lat": [5435, 5515], "when": {"mustered": True}},
                       {"id": "poland_1818", "lon": [1400, 2500], "lat": [5150, 5560]}],
            "sets": [{"id": "vistula", "nodes": ["posen_1818", "grodno"], "bonus": {"pass_supply": 1}}],
            "rivals": [{"id": "cossacks_1818", "label": "普拉托夫的哥萨克", "path": ["bialystok", "grodno", "bialystok", "ostrolenka"], "speed": 1,
                        "start": 0, "meet": {"battle": {"template": "skirmish_brabant_farm", "level": 20}, "toll": {"supply": 2}}, "burns_depots": True}],
            "nodes": N, "links": L}

def sheet_last_coalition():
    W, LP = ["germany_1819"], ["leipzig_1819"]
    K = {"event": 5, "supply": 2, "camp": 2, "shop": 1, "battle": 2}
    N = [
        story("paris_1819", "k_paris_1819", pid="paris", label="巴黎·杜伊勒里宫", date="1819-08-15", frame=W),
        slot("reims_1819", "last_coalition", 22, pid="reims", kinds=K, frame=W),
        slot("chalons_1819", "last_coalition", 22, pid="chalons", kinds=K, frame=W),
        node("metz_1819", "supply", role="post", pid="metz", label="梅斯驿站", frame=W),
        slot("kaiserslautern", "last_coalition", 22, pid="kaiserslautern", kinds=K, frame=W),
        node("mainz_1819", "shop", pid="mainz", label="美因茨的军火库", frame=W),
        slot("frankfurt", "last_coalition", 22, kinds=K, frame=W),
        slot("fulda", "last_coalition", 22, kinds=K, frame=W),
        node("erfurt", "supply", role="post", label="爱尔福特驿站", frame=W),
        node("weimar", "event", event="ev_goethe_tea", label="魏玛·歌德的花园小屋", frame=W),
        node("naumburg_1819", "camp", role="muster", pid="naumburg", label="瑙姆堡（开拔）", frame=W + LP),
    ] + camp_phase([
        council("lutzen_1819", "ev_council_final", pid="lutzen", label="吕岑军议", frame=LP),
        node("markkleeberg", "camp", label="马克克莱贝格的最后一夜", actions=["activity:rest", "schedule:bond_story"], frame=LP),
        boss("leipzig_1819", "k_leipzig_1819", pid="leipzig", label="莱比锡·第二次民族之战", date="1819-10-18", frame=LP),
        story("probstheida", "k_final", label="普罗布斯泰达·皇帝的帐篷", date="1819-10-19", frame=LP),
    ])
    L = [link("paris_1819", "reims_1819", 3), link("paris_1819", "chalons_1819", 4, supply=1), link("reims_1819", "chalons_1819"),
         link("reims_1819", "metz_1819", 3), link("chalons_1819", "metz_1819", 3), link("metz_1819", "kaiserslautern", 2),
         link("kaiserslautern", "mainz_1819", 2), link("metz_1819", "mainz_1819", 4, supply=1), link("mainz_1819", "frankfurt"),
         link("frankfurt", "fulda", 2), link("mainz_1819", "fulda", 3, supply=1), link("fulda", "erfurt", 2), link("erfurt", "weimar"),
         link("weimar", "naumburg_1819"), link("erfurt", "naumburg_1819", 2),
         link("naumburg_1819", "lutzen_1819"), link("lutzen_1819", "markkleeberg"), link("markkleeberg", "leipzig_1819"),
         link("leipzig_1819", "probstheida")]
    return {"chapter": "last_coalition", "view": "europe", "start": "paris_1819", "days_max": 12, "stamps_need": 2,
            "muster": "naumburg_1819", "boss": "leipzig_1819", "interlude": "camp_night",
            "frames": [{"id": "leipzig_1819", "lon": [1170, 1270], "lat": [5110, 5150], "when": {"mustered": True}},
                       {"id": "germany_1819", "lon": [200, 1320], "lat": [4850, 5200]}],
            "sets": [], "rivals": [{"id": "british_hussars", "label": "英军骠骑兵", "path": ["fulda", "frankfurt", "fulda", "erfurt"], "speed": 1,
                                    "start": 0, "meet": {"battle": {"template": "skirmish_brabant_farm", "level": 22}, "toll": {"gold": 1}},
                                    "burns_depots": True}],
            "nodes": N, "links": L}


# ================================================================== write
def clean(sheets):
    out = []
    for s in sheets:
        s = finish_sheet(s)
        for n in s["nodes"]:
            n.pop("role_hint", None)
        out.append(s)
    return out

VIEW_EUROPE = {"proj": "mercator", "base": "res://data/campaigns/napoleon/maps/geo/europe.json", "lon": [-1200, 5600], "lat": [2400, 6300], "bg": "map_europe"}

def main():
    trunk = {
        "id": "europe", "version": 1, "segment": "trunk",
        "_doc": "草稿（标签 conquest，2026-11-02）：主干「鹰旗」八张图（ARCH §2.2 形状）。geo=[经度×100, 纬度×100]；土伦和厄尔巴是手绘局部图，用 xy（1920×1080，按真实经纬度局部等距拟合，画师照着描）。frames 是本稿提议的镜头窗（只给界面用，见 CONQUEST.md §4.2）。由 tools/build_maps.py 生成，别手改。",
        "views": {"europe": VIEW_EUROPE,
                  "toulon_1793": {"proj": "canvas", "bg": "map_toulon_1793"},
                  "elba_1814": {"proj": "canvas", "bg": "map_elba"},
                  "portoferraio_1815": {"proj": "canvas", "bg": "map_portoferraio"}},
        "sheets": clean([sheet_toulon(), sheet_italy(), sheet_orient_alps(), sheet_austerlitz_jena(),
                         sheet_iberia_danube(), sheet_russia(), sheet_collapse(), sheet_elba()]),
    }
    late = {
        "id": "europe_late", "version": 1, "segment": "conquest",
        "_doc": "草稿（标签 conquest，2026-11-02）：鹰飞分支六张图（1815—1819 架空）。形状同 europe.json。由 tools/build_maps.py 生成。",
        "views": {"europe": VIEW_EUROPE},
        "sheets": clean([sheet_hundred_days(), sheet_rhine(), sheet_vienna(), sheet_iberia_channel(), sheet_niemen(), sheet_last_coalition()]),
    }
    os.makedirs(os.path.join(OUT, "maps"), exist_ok=True)
    for name, data in (("europe.json", trunk), ("europe_late.json", late)):
        with open(os.path.join(OUT, "maps", name), "w", encoding="utf-8") as f:
            json.dump(data, f, ensure_ascii=False, indent=1)
            f.write("\n")
    patch = json.load(open(os.path.join(ROOT, "tools", "book_patch_static.json"), encoding="utf-8"))
    patch["scene_battles"] = {"trunk": {k: v for k, v in SCENE_BATTLES.items() if not k.startswith("k_")},
                              "conquest": {k: v for k, v in SCENE_BATTLES.items() if k.startswith("k_")}}
    with open(os.path.join(OUT, "book_conquest_patch.json"), "w", encoding="utf-8") as f:
        json.dump(patch, f, ensure_ascii=False, indent=1)
        f.write("\n")
    print("wrote", sum(len(s["nodes"]) for s in trunk["sheets"]), "trunk nodes,", sum(len(s["nodes"]) for s in late["sheets"]), "conquest nodes")

if __name__ == "__main__":
    main()
