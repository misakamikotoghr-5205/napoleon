# -*- coding: utf-8 -*-
# Cristo branch world map: maps/med.json (ARCH §2.2 shape). Five sheets, one per chapter.
#   ch1 marseille   -> canvas view marseille_1815 (city of Marseille in 1815: the Old Port, Le Panier, the Catalans)
#   ch2 if_years    -> canvas view if_fortress (left: the Château d'If island; right: the coast from Marseille to Cassis)
#   ch3 montecristo -> geo view med (Tyrrhenian coast, Elba, Corsica, Montecristo)
#   ch4 mediterranean -> geo view med (Pont du Gard, Marseille, Livorno, Rome, Constantinople)
#   ch5 paris_1838  -> canvas view paris_1838 (Paris of the July Monarchy)
# geo = [lon*100, lat*100] (integers); xy = canvas [x, y] on 1920x1080. "offset" (pixels) separates nodes that share a city.
# frames (as in the conquest draft): zoomed sub-views of a geo sheet; the panel fits the first frame whose "when" holds and
# that contains the current position. Rome's six campaign nodes sit within 0.06 degree of each other, so they need rome_city.
import json, os

HERE = os.path.dirname(os.path.abspath(__file__))
GAZ = {p["id"]: p for p in json.load(open(os.path.join(HERE, "..", "..", "geo", "gazetteer.json")))["places"]}


def geo_of(pid=None, lon=None, lat=None):
    if pid:
        p = GAZ[pid]
        lon, lat = p["lon"], p["lat"]
    return [int(round(lon * 100)), int(round(lat * 100))]


SLOT_STD = {"event": 6, "supply": 2, "camp": 2, "shop": 1}
SLOT_FIGHT = {"event": 5, "supply": 2, "camp": 2, "shop": 1, "battle": 2}


def N(id, type, label, pos, **kw):
    n = {"id": id, "type": type, "label": label}
    if isinstance(pos, dict):
        n.update(pos)
    elif len(pos) == 2 and all(isinstance(v, int) for v in pos):
        n["xy"] = list(pos)
    n.update(kw)
    if type == "slot":
        n.setdefault("fog", "type")
        n.setdefault("fixed", False)
    else:
        n.setdefault("fog", "open")
    if type in ("story", "boss", "branch"):
        n["fixed"] = True
    if type in ("supply", "camp", "shop"):
        n.setdefault("once", False)
    return n


def L(a, b, legs=1, **kw):
    d = {"a": a, "b": b, "legs": legs}
    d.update(kw)
    return d


def slot(pool, level=None, fight=False):
    s = {"pool": pool, "kinds": dict(SLOT_FIGHT if fight else SLOT_STD)}
    if fight:
        s["level"] = level
    return s


TOWN = ["visit:town", "trade:fair", "trade:counterfeit", "build_depot"]
CAMP = ["schedule:recruit", "schedule:train", "schedule:bond_story", "activity:rest"]
SHOP = ["activity:merchant", "recruit:troop", "recruit:companion"]

SHEETS = []

# ====================================================================== ch1 · Marseille 1815 (L12 / 13 / 14)
P1 = "marseille"
SHEETS.append({
    "chapter": "marseille", "view": "marseille_1815", "start": "quay", "days_max": 18, "stamps_need": 2,
    "muster": "panier", "boss": "warehouse", "interlude": "bond",
    "sets": [{"id": "old_port", "nodes": ["fort_post", "catalans"], "bonus": {"pass_supply": 1}}],
    "rivals": [{"id": "gendarme_patrol", "label": "宪兵巡逻队", "path": ["canebiere", "grand_cours", "belsunce", "grand_cours"], "speed": 1, "start": 0,
                "meet": {"battle": {"template": "alley_ambush", "level": 12}, "toll": {"gold": 1}}, "burns_depots": True}],
    "nodes": [
        N("quay", "story", "旧港码头·圣让堡下", [760, 470], date="1815-02-28", scene="c_landfall"),
        N("fort_post", "supply", "圣让堡哨口", [600, 420], role="post", actions=TOWN, pass_={"stamp": 1, "coins": {"intel": 1}}),
        N("lazaret", "slot", "阿朗克检疫站", [520, 250], slot=slot(P1)),
        N("estaque", "slot", "莱斯塔克的渔村", [360, 150], slot=slot(P1, 12, True)),
        N("saint_nicolas", "slot", "圣尼古拉堡下的渡口", [640, 570], slot=slot(P1)),
        N("rive_neuve", "camp", "新岸的船坞", [880, 610], actions=CAMP),
        N("catalans", "supply", "加泰罗尼亚人村", [560, 700], role="intel", actions=["visit:backdoor", "build_depot"]),
        N("reserve", "story", "雷瑟夫酒家", [430, 790], date="1815-02-28", scene="c_reserve"),
        N("corniche", "slot", "海边的悬崖小路", [620, 920], slot=slot(P1, 12, True)),
        N("garde_post", "supply", "守护圣母山信号站", [1000, 840], role="post", actions=TOWN, pass_={"stamp": 1, "coins": {"supply": 1}}),
        N("arsenal", "slot", "旧军械库", [1060, 650], slot=slot(P1)),
        N("canebiere", "slot", "卡讷比耶尔大街", [1120, 510], slot=slot(P1)),
        N("grand_cours", "story", "大库尔街·杰拉尔的宅子", [1200, 380], date="1815-02-28", scene="c_gerard"),
        N("belsunce", "supply", "贝尔桑斯林荫道的集市", [1330, 280], actions=TOWN),
        N("meilhan", "story", "梅朗林荫道·莫雷尔商行", [1500, 430], date="1815-04-12", scene="c_petition"),
        N("caderousse_shop", "shop", "卡德鲁斯的裁缝铺", [1600, 300], actions=SHOP),
        N("aix_road", "slot", "去艾克斯的大路", [1720, 160], slot=slot(P1, 12, True)),
        N("old_dantes", "slot", "梅朗林荫道的阁楼", [1680, 520], slot=slot(P1)),
        N("panier", "camp", "勒潘尼耶的地窖（集结）", [800, 290], role="muster", date="1815-06-24", actions=CAMP + ["muster"]),
        N("saint_laurent", "event", "圣洛朗教堂", [640, 330], role="council", event="ev_c1_council", fixed=True, phase="campaign", date="1815-06-24"),
        N("catalans_cove", "elite", "加泰罗尼亚人的海湾", [330, 900], template="catalans_cove", level=13, weather=["night"],
          reward={"coins": {"gold": 2}, "props": ["prop_bribe_pouch"]}, phase="campaign", date="1815-06-24"),
        N("cellar", "camp", "圣让堡的暗道", [780, 385], actions=["activity:rest", "schedule:bond_story"], phase="campaign", date="1815-06-24"),
        N("warehouse", "boss", "旧港北岸·莫雷尔的货栈", [920, 420], scene="c_white_june", phase="campaign", weather=["clear"], date="1815-06-25"),
    ],
    "links": [
        L("quay", "fort_post", 1), L("quay", "saint_nicolas", 1, supply=1, _ferry=True), L("quay", "canebiere", 2),
        L("fort_post", "lazaret", 2), L("lazaret", "estaque", 2), L("fort_post", "panier", 2), L("belsunce", "panier", 3),
        L("saint_nicolas", "catalans", 1), L("saint_nicolas", "rive_neuve", 1), L("catalans", "reserve", 1), L("reserve", "corniche", 2),
        L("corniche", "garde_post", 2), L("garde_post", "arsenal", 2), L("arsenal", "rive_neuve", 1), L("arsenal", "canebiere", 2),
        L("canebiere", "grand_cours", 1), L("grand_cours", "belsunce", 2), L("canebiere", "meilhan", 2), L("belsunce", "meilhan", 2),
        L("meilhan", "caderousse_shop", 1), L("caderousse_shop", "aix_road", 2), L("meilhan", "old_dantes", 1), L("belsunce", "aix_road", 3, toll={"gold": 1}),
        L("rive_neuve", "catalans", 2, route="smuggle_route"),
        L("panier", "saint_laurent", 1), L("saint_laurent", "cellar", 1), L("saint_laurent", "catalans_cove", 0, voyage_days=1),
        L("catalans_cove", "cellar", 0, voyage_days=1), L("cellar", "warehouse", 1),
    ],
})

# ====================================================================== ch2 · the If years 1816-1829 (L14 / 15 / 16)
P2 = "if_years"
SHEETS.append({
    "chapter": "if_years", "view": "if_fortress", "start": "gov_office", "days_max": 22, "stamps_need": 2,
    "muster": "bread_wharf_1829", "boss": "sea_gate", "interlude": "minigame:decode",
    "years": {"_doc": "这一章一张图跨十三年：锚点上写年份，界面在顶栏显示“1816 → 1829”的刻度。天数照常计（一天=一段日子）。",
              "marks": [["gov_office", 1816], ["if_kitchen", 1817], ["cell_27", 1818], ["morgiou", 1822], ["cell_27_1829", 1829]]},
    "sets": [{"id": "bread_route", "nodes": ["bread_wharf", "if_landing"], "bonus": {"pass_supply": 1}}],
    "rivals": [{"id": "customs_cutter", "label": "海关缉私快艇", "path": ["sormiou", "morgiou", "calanques", "morgiou"], "speed": 1, "start": 1,
                "meet": {"battle": {"template": "coast_road", "level": 14}, "toll": {"gold": 1}}, "burns_depots": False}],
    "nodes": [
        N("gov_office", "story", "伊夫堡·典狱长的办公室", [420, 360], date="1816-03-12", scene="c_if_contract"),
        N("if_landing", "supply", "伊夫堡码头", [600, 520], role="post", actions=["visit:town", "build_depot"], pass_={"stamp": 1, "coins": {"supply": 1}}),
        N("if_kitchen", "story", "地牢的厨房", [330, 560], date="1817-07-20", scene="c_bread_34"),
        N("if_yard", "slot", "要塞的院子", [470, 700], slot=slot(P2)),
        N("cell_27", "story", "27 号牢房", [220, 450], date="1818-12-03", scene="c_faria_27"),
        N("pomegues", "camp", "波梅格岛的检疫站", [640, 210], actions=CAMP),
        N("ratonneau", "slot", "拉托诺岛", [800, 330], slot=slot(P2, 14, True)),
        N("bread_wharf", "supply", "马赛的面包码头", [1140, 430], role="post", actions=TOWN, pass_={"stamp": 1, "coins": {"intel": 1}}),
        N("morrel_house", "supply", "梅朗林荫道·莫雷尔家", [1320, 320], role="intel", actions=["visit:backdoor"]),
        N("bakery", "supply", "面包房的地窖", [1250, 580], role="project", actions=["build"], _doc="build = 地道（工事）：给伊夫堡里的地道送工具"),
        N("old_town", "slot", "老城", [1460, 460], slot=slot(P2)),
        N("cassis", "shop", "卡西斯的走私贩酒馆", [1580, 650], actions=SHOP),
        N("morgiou", "story", "莫尔吉乌小湾", [1400, 780], date="1822-08-14", scene="c_morgiou"),
        N("sormiou", "slot", "索尔米乌", [1240, 860], slot=slot(P2)),
        N("calanques", "slot", "峡湾群", [1700, 820], slot=slot(P2)),
        N("la_ciotat", "slot", "拉西奥塔", [1830, 620], slot=slot(P2, 14, True)),
        N("if_chapel", "slot", "要塞的小教堂", [500, 240], slot=slot(P2)),
        N("pointe_rouge", "slot", "红角的渔村", [1120, 720], slot=slot(P2)),
        N("janina", "event", "远方·约阿尼纳（1822）", [1800, 150], event="ev_janina_1822", fixed=True, date="1822-01-20"),
        N("janina_lake", "elite", "约阿尼纳湖·湖心岛", [1660, 120], template="janina_lake", level=15, weather=["fog"], reward={"coins": {"gold": 2, "medal": 1}},
          date="1822-01-22", _planned=True),
        N("cell_27_1829", "story", "27 号牢房（1829）", [250, 300], date="1829-02-14", scene="c_faria_dies"),
        N("bread_wharf_1829", "camp", "面包码头（1829，集结）", [1060, 300], role="muster", date="1829-02-26", actions=CAMP + ["muster"]),
        N("cassis_backroom", "event", "卡西斯·酒馆后屋", [1500, 560], role="council", event="ev_c2_council", fixed=True, phase="campaign", date="1829-02-27"),
        N("frioul_night", "camp", "弗里乌尔礁石后的小船", [760, 640], actions=["activity:rest", "schedule:bond_story"], phase="campaign", date="1829-02-28"),
        N("sea_gate", "boss", "伊夫堡·海门", [560, 800], scene="c_if_night", phase="campaign", weather=["night"], date="1829-02-28"),
    ],
    "links": [
        L("gov_office", "if_landing", 1), L("gov_office", "cell_27", 2), L("gov_office", "if_kitchen", 2), L("if_kitchen", "cell_27", 1),
        L("if_kitchen", "if_yard", 1), L("if_yard", "if_landing", 1), L("cell_27", "cell_27_1829", 1, requires={"scene_done": "c_morgiou"}),
        L("if_landing", "pomegues", 2, supply=1), L("pomegues", "ratonneau", 1), L("ratonneau", "bread_wharf", 2, supply=1),
        L("if_landing", "bread_wharf", 3, supply=1, _boat="面包船"),
        L("bread_wharf", "morrel_house", 1), L("bread_wharf", "bakery", 1), L("bakery", "old_town", 1), L("morrel_house", "old_town", 1),
        L("old_town", "cassis", 2), L("bakery", "sormiou", 2), L("sormiou", "morgiou", 1), L("morgiou", "cassis", 2), L("morgiou", "calanques", 2),
        L("calanques", "la_ciotat", 1), L("cassis", "la_ciotat", 1),
        L("gov_office", "if_chapel", 1), L("if_chapel", "if_landing", 1), L("bakery", "pointe_rouge", 1), L("pointe_rouge", "sormiou", 1),
        L("bread_wharf", "janina", 0, voyage_days=6), L("janina", "janina_lake", 1),
        L("bread_wharf", "bread_wharf_1829", 1), L("morrel_house", "bread_wharf_1829", 1),
        L("bread_wharf_1829", "cassis_backroom", 3), L("cassis_backroom", "frioul_night", 0, voyage_days=1), L("frioul_night", "sea_gate", 1),
    ],
})

# ====================================================================== ch3 · Montecristo 1829 (L16 / 17 / 18)
P3 = "montecristo"
SHEETS.append({
    "chapter": "montecristo", "view": "med", "start": "tiboulen", "days_max": 20, "stamps_need": 2,
    "muster": "pianosa", "boss": "montecristo_cave", "interlude": "camp_night",
    "frames": [{"id": "ligurian_coast", "lon": [480, 1000], "lat": [4250, 4470]},
               {"id": "tuscan_isles", "lon": [880, 1200], "lat": [4200, 4370], "when": {"scene_done": "c_livorno"}},
               {"id": "montecristo_isle", "lon": [1018, 1046], "lat": [4226, 4244], "when": {"mustered": True}}],
    "sets": [{"id": "tuscan_ports", "nodes": ["livorno_post", "portoferraio"], "bonus": {"pass_supply": 1}}],
    "rivals": [{"id": "genoese_rivals", "label": "热那亚帮的三桅船", "path": ["capraia", "gorgona", "capraia", "corsica_cape"], "speed": 1, "start": 0,
                "meet": {"battle": {"template": "coast_road", "level": 16}, "toll": {"gold": 1}}, "burns_depots": True}],
    "nodes": [
        N("tiboulen", "story", "蒂布朗岛", {"geo": geo_of(lon=5.287, lat=43.281), "offset": [-30, 26]}, date="1829-03-01", scene="c_tiboulen"),
        N("planier", "slot", "普拉尼耶灯塔", {"geo": geo_of(lon=5.23, lat=43.20)}, slot=slot(P3)),
        N("toulon_post", "supply", "土伦港外的锚地", {"geo": geo_of("toulon")}, role="post", actions=TOWN, pass_={"stamp": 1, "coins": {"supply": 1}}),
        N("hyeres", "slot", "耶尔群岛", {"geo": geo_of(lon=6.40, lat=43.01)}, slot=slot(P3, 16, True)),
        N("nice", "supply", "尼斯", {"geo": geo_of("nice")}, actions=TOWN),
        N("genoa", "shop", "热那亚的船坞与银行", {"geo": geo_of("genoa")}, actions=SHOP),
        N("corsica_cape", "slot", "科西嘉角", {"geo": geo_of(lon=9.40, lat=43.00)}, slot=slot(P3)),
        N("capraia", "slot", "卡普拉亚岛", {"geo": geo_of(lon=9.83, lat=43.05)}, slot=slot(P3)),
        N("gorgona", "slot", "戈尔戈纳岛", {"geo": geo_of(lon=9.90, lat=43.43)}, slot=slot(P3, 16, True)),
        N("livorno", "story", "里窝那·理发店", {"geo": geo_of("livorno")}, date="1829-03-09", scene="c_livorno"),
        N("livorno_post", "supply", "里窝那港务处", {"geo": geo_of("livorno"), "offset": [34, 22]}, role="post", actions=TOWN, pass_={"stamp": 1, "coins": {"intel": 1}}),
        N("bastia", "supply", "巴斯蒂亚的走私贩", {"geo": geo_of(lon=9.45, lat=42.70)}, role="intel", actions=["visit:backdoor", "build_depot"]),
        N("ajaccio", "slot", "阿雅克肖", {"geo": geo_of("ajaccio")}, slot=slot(P3)),
        N("piombino", "slot", "皮翁比诺", {"geo": geo_of(lon=10.53, lat=42.93)}, slot=slot(P3)),
        N("portoferraio", "supply", "费拉约港（厄尔巴）", {"geo": geo_of("portoferraio")}, actions=TOWN),
        N("civitavecchia", "slot", "奇维塔韦基亚", {"geo": geo_of(lon=11.80, lat=42.09)}, slot=slot(P3)),
        N("pianosa", "camp", "皮亚诺萨岛（集结）", {"geo": geo_of(lon=10.08, lat=42.59)}, role="muster", date="1829-05-20", actions=CAMP + ["muster"]),
        N("amelie_deck", "event", "少年阿梅莉号的甲板", {"geo": geo_of(lon=10.18, lat=42.47)}, role="council", event="ev_c3_council", fixed=True, phase="campaign", date="1829-05-22"),
        N("goat_beach", "camp", "基督山岛的山羊滩", {"geo": geo_of(lon=10.290, lat=42.345)}, actions=["activity:rest", "schedule:bond_story"], phase="campaign", date="1829-05-23"),
        N("montecristo_cave", "boss", "基督山岛·第二个小湾往东", {"geo": geo_of(lon=10.322, lat=42.322)}, scene="c_montecristo", phase="campaign", weather=["clear", "storm"], date="1829-05-24"),
    ],
    "links": [
        L("tiboulen", "planier", 1), L("tiboulen", "toulon_post", 2), L("planier", "toulon_post", 2), L("toulon_post", "hyeres", 1),
        L("hyeres", "nice", 3, supply=1), L("nice", "genoa", 3, supply=1), L("genoa", "corsica_cape", 2), L("genoa", "gorgona", 3),
        L("corsica_cape", "capraia", 1), L("capraia", "gorgona", 1), L("gorgona", "livorno", 1), L("capraia", "livorno", 2),
        L("livorno", "livorno_post", 1), L("livorno_post", "piombino", 2), L("livorno", "portoferraio", 0, voyage_days=1),
        L("corsica_cape", "bastia", 1), L("bastia", "ajaccio", 3), L("bastia", "portoferraio", 2, supply=1), L("piombino", "portoferraio", 1),
        L("portoferraio", "civitavecchia", 3), L("ajaccio", "pianosa", 0, voyage_days=2), L("portoferraio", "pianosa", 1), L("civitavecchia", "pianosa", 3),
        L("toulon_post", "ajaccio", 0, voyage_days=3),
        L("pianosa", "amelie_deck", 1), L("amelie_deck", "goat_beach", 1), L("goat_beach", "montecristo_cave", 1),
    ],
})

# ====================================================================== ch4 · Mediterranean 1829-1838 (L19 / 20 / 21)
P4 = "mediterranean"
SHEETS.append({
    "chapter": "mediterranean", "view": "med", "start": "caderousse_inn", "days_max": 22, "stamps_need": 2,
    "muster": "hotel_londres", "boss": "san_sebastiano", "interlude": "audience",
    "frames": [{"id": "provence", "lon": [400, 620], "lat": [4290, 4420]},
               {"id": "tyrrhenian", "lon": [850, 1450], "lat": [4050, 4460], "when": {"scene_done": "c_morrel_rescue"}},
               {"id": "levant", "lon": [900, 3000], "lat": [3600, 4500], "when": {"scene_done": "c_morrel_rescue"}},
               {"id": "rome_city", "lon": [1238, 1262], "lat": [4180, 4196], "when": {"scene_done": "c_carnival"}}],
    "sets": [{"id": "count_houses", "nodes": ["genoa_1830", "civitavecchia_post"], "bonus": {"pass_supply": 1}}],
    "rivals": [{"id": "papal_patrol", "label": "教皇宪兵的巡逻队", "path": ["civitavecchia_post", "tivoli", "frascati", "tivoli"], "speed": 1, "start": 1,
                "meet": {"battle": {"template": "coast_road", "level": 19}, "toll": {"gold": 1}}, "burns_depots": True}],
    "nodes": [
        N("caderousse_inn", "story", "加尔桥客栈", {"geo": geo_of("caderousse_inn")}, date="1829-06-03", scene="c_caderousse"),
        N("pont_du_gard", "slot", "加尔桥", {"geo": geo_of("pont_du_gard")}, slot=slot(P4)),
        N("nimes", "supply", "尼姆", {"geo": geo_of("nimes")}, actions=TOWN),
        N("arles", "slot", "阿尔勒", {"geo": geo_of(lon=4.63, lat=43.68)}, slot=slot(P4, 19, True)),
        N("marseille_1829", "story", "马赛·梅朗林荫道", {"geo": geo_of("marseille")}, date="1829-09-05", scene="c_morrel_rescue"),
        N("toulon_bagne", "slot", "土伦苦役场", {"geo": geo_of("toulon")}, slot=slot(P4)),
        N("genoa_1830", "supply", "热那亚", {"geo": geo_of("genoa")}, role="post", actions=TOWN, pass_={"stamp": 1, "coins": {"supply": 1}}),
        N("livorno_1830", "supply", "里窝那的账房", {"geo": geo_of("livorno")}, role="project", actions=["explore"], _doc="explore = 卷宗（测绘）：收集莫尔塞夫、唐格拉尔、维尔福的证据"),
        N("florence", "slot", "佛罗伦萨", {"geo": geo_of(lon=11.26, lat=43.77)}, slot=slot(P4)),
        N("montecristo_grotto", "camp", "基督山岛·伯爵的地下宫殿", {"geo": geo_of("montecristo")}, actions=CAMP),
        N("civitavecchia_post", "supply", "奇维塔韦基亚港", {"geo": geo_of(lon=11.80, lat=42.09)}, role="post", actions=TOWN, pass_={"stamp": 1, "coins": {"intel": 1}}),
        N("rome", "story", "罗马·人民广场", {"geo": geo_of(lon=12.4763, lat=41.9109), "offset": [-40, -24]}, date="1838-02-20", scene="c_carnival"),
        N("thomson_french", "shop", "罗马·汤姆森与弗伦奇银行", {"geo": geo_of(lon=12.4808, lat=41.8985)}, actions=SHOP),
        N("tivoli", "slot", "蒂沃利", {"geo": geo_of(lon=12.80, lat=41.96)}, slot=slot(P4)),
        N("frascati", "slot", "弗拉斯卡蒂", {"geo": geo_of(lon=12.68, lat=41.81)}, slot=slot(P4, 19, True)),
        N("naples", "slot", "那不勒斯", {"geo": geo_of("naples")}, slot=slot(P4)),
        N("tunis", "slot", "突尼斯", {"geo": geo_of("tunis")}, slot=slot(P4)),
        N("constantinople", "event", "君士坦丁堡·奴隶市场", {"geo": geo_of("constantinople")}, event="ev_haydee_constantinople", fixed=True, date="1834-04-01"),
        N("hotel_londres", "camp", "伦敦饭店（集结）", {"geo": geo_of(lon=12.4823, lat=41.9059), "offset": [64, 28]}, role="muster", date="1838-02-21", actions=CAMP + ["muster"]),
        N("vampa_note", "event", "万帕的信使", {"geo": geo_of(lon=12.4950, lat=41.8930)}, role="council", event="ev_c4_council", fixed=True, phase="campaign", date="1838-02-21"),
        N("appian_way", "elite", "亚壁古道", {"geo": geo_of(lon=12.5300, lat=41.8420)}, template="appian_way", level=20, weather=["night"],
          reward={"coins": {"gold": 2}, "props": ["prop_spyglass"]}, phase="campaign", date="1838-02-21", _planned=True),
        N("caracalla", "camp", "卡拉卡拉浴场的废墟", {"geo": geo_of(lon=12.4924, lat=41.8790)}, actions=["activity:rest", "schedule:bond_story"], phase="campaign", date="1838-02-22"),
        N("san_sebastiano", "boss", "圣塞巴斯蒂安墓窟", {"geo": geo_of(lon=12.5157, lat=41.8556)}, scene="c_san_sebastiano", phase="campaign", weather=["night"], date="1838-02-22"),
    ],
    "links": [
        L("caderousse_inn", "pont_du_gard", 1), L("caderousse_inn", "nimes", 1), L("caderousse_inn", "arles", 1), L("pont_du_gard", "nimes", 1),
        L("arles", "marseille_1829", 2), L("nimes", "marseille_1829", 3, supply=1), L("marseille_1829", "toulon_bagne", 1),
        L("marseille_1829", "genoa_1830", 0, voyage_days=2), L("toulon_bagne", "genoa_1830", 3, supply=1),
        L("genoa_1830", "livorno_1830", 2), L("livorno_1830", "florence", 2), L("livorno_1830", "montecristo_grotto", 0, voyage_days=1),
        L("livorno_1830", "civitavecchia_post", 3, supply=1), L("montecristo_grotto", "civitavecchia_post", 0, voyage_days=1),
        L("florence", "rome", 4, supply=1), L("civitavecchia_post", "rome", 2), L("rome", "thomson_french", 1), L("rome", "tivoli", 2),
        L("tivoli", "frascati", 1), L("rome", "naples", 0, voyage_days=2), L("montecristo_grotto", "tunis", 0, voyage_days=3), L("naples", "constantinople", 0, voyage_days=7),
        L("thomson_french", "hotel_londres", 1), L("rome", "hotel_londres", 1), L("frascati", "hotel_londres", 2),
        L("hotel_londres", "vampa_note", 1), L("vampa_note", "appian_way", 2), L("vampa_note", "caracalla", 1), L("appian_way", "caracalla", 1),
        L("caracalla", "san_sebastiano", 1),
    ],
})

# ====================================================================== ch5 · Paris 1838 (L22 / 23 / 24)
P5 = "paris_1838"
SHEETS.append({
    "chapter": "paris_1838", "view": "paris_1838", "start": "champs", "days_max": 22, "stamps_need": 2,
    "muster": "ile_saint_louis", "boss": "palais_justice", "interlude": "minigame:weigh",
    "sets": [{"id": "right_bank", "nodes": ["tuileries_post", "palais_royal_post"], "bonus": {"pass_supply": 1}}],
    "rivals": [{"id": "police_watch", "label": "警察厅的便衣", "path": ["saint_germain", "latin_quarter", "marais", "latin_quarter"], "speed": 1, "start": 0,
                "meet": {"battle": {"template": "alley_ambush", "level": 22}, "toll": {"gold": 1}}, "burns_depots": True}],
    "nodes": [
        N("champs", "story", "香榭丽舍大街 30 号", [620, 380], date="1838-05-21", scene="c_champs_elysees"),
        N("bois", "slot", "布洛涅树林", [270, 470], slot=slot(P5)),
        N("auteuil", "story", "奥特伊·方丹街 28 号", [150, 660], date="1838-06-20", scene="c_auteuil"),
        N("passy", "slot", "帕西", [360, 740], slot=slot(P5)),
        N("st_honore", "supply", "圣奥诺雷区·维尔福府后门", [860, 320], role="intel", actions=["visit:backdoor"]),
        N("helder", "supply", "赫尔德街·莫尔塞夫府", [1040, 250], actions=TOWN),
        N("montmartre", "slot", "蒙马特", [1020, 80], slot=slot(P5)),
        N("telegraph", "event", "蒙莫朗西的电报站", [1320, 60], event="ev_telegraph", fixed=True, date="1838-08-29"),
        N("tuileries_post", "supply", "杜伊勒里宫的驿站", [880, 470], role="post", actions=TOWN, pass_={"stamp": 1, "coins": {"intel": 1}}),
        N("palais_royal_post", "supply", "王宫的拱廊", [1040, 420], role="post", actions=TOWN, pass_={"stamp": 1, "coins": {"supply": 1}}),
        N("palais_royal_shop", "shop", "王宫市场", [1100, 340], actions=SHOP),
        N("saint_germain", "slot", "圣日耳曼区", [820, 690], slot=slot(P5)),
        N("luxembourg", "story", "卢森堡宫·贵族院", [960, 850], date="1838-07-10", scene="c_peers"),
        N("antin", "story", "昂坦街·唐格拉尔银行", [1180, 210], date="1838-08-30", scene="c_danglars"),
        N("latin_quarter", "slot", "拉丁区", [1160, 780], slot=slot(P5, 22, True)),
        N("marais", "slot", "马莱区", [1460, 470], slot=slot(P5, 22, True)),
        N("pere_lachaise", "camp", "拉雪兹神父公墓", [1720, 520], actions=CAMP),
        N("bastille", "slot", "巴士底广场", [1600, 650], slot=slot(P5)),
        N("ile_saint_louis", "camp", "圣路易岛（集结）", [1420, 690], role="muster", date="1838-10-14", actions=CAMP + ["muster"]),
        N("notre_dame", "event", "圣母院的钟楼", [1320, 640], role="council", event="ev_c5_council", fixed=True, phase="campaign", date="1838-10-14"),
        N("rooftops", "elite", "西岱岛的屋顶", [1260, 540], template="paris_rooftops", level=23, weather=["rain"], reward={"coins": {"gold": 2, "intel": 2}},
          phase="campaign", date="1838-10-14", _planned=True),
        N("quai_horloge", "camp", "钟楼码头的小酒馆", [1180, 640], actions=["activity:rest", "schedule:bond_story"], phase="campaign", date="1838-10-15"),
        N("palais_justice", "boss", "西岱岛·司法宫", [1080, 620], scene="c_trial", phase="campaign", weather=["night"], date="1838-10-15"),
    ],
    "links": [
        L("champs", "bois", 2), L("bois", "auteuil", 2), L("auteuil", "passy", 1), L("passy", "champs", 2), L("champs", "st_honore", 2),
        L("champs", "tuileries_post", 2), L("st_honore", "helder", 1), L("helder", "antin", 1), L("helder", "montmartre", 2), L("montmartre", "telegraph", 2, supply=1),
        L("telegraph", "antin", 2), L("tuileries_post", "palais_royal_post", 1), L("palais_royal_post", "palais_royal_shop", 1), L("palais_royal_shop", "antin", 1),
        L("tuileries_post", "saint_germain", 2), L("saint_germain", "luxembourg", 1), L("luxembourg", "latin_quarter", 1),
        L("latin_quarter", "bastille", 3), L("palais_royal_post", "marais", 3), L("marais", "pere_lachaise", 2), L("marais", "bastille", 1),
        L("bastille", "pere_lachaise", 1), L("bastille", "ile_saint_louis", 1), L("latin_quarter", "ile_saint_louis", 2), L("marais", "ile_saint_louis", 2),
        L("ile_saint_louis", "notre_dame", 1), L("notre_dame", "rooftops", 1), L("notre_dame", "quai_horloge", 1), L("rooftops", "quai_horloge", 1, rush=False),
        L("quai_horloge", "palais_justice", 1),
    ],
})


def finish():
    """rename pass_ -> pass (python keyword), drop private keys starting with _ except _doc/_planned kept as notes"""
    for sh in SHEETS:
        for n in sh["nodes"]:
            if "pass_" in n:
                n["pass"] = n.pop("pass_")
        for l in sh["links"]:
            for k in [k for k in l if k.startswith("_")]:
                l.pop(k)
            if l.get("legs") == 0:
                l.pop("legs")
    return SHEETS


VIEWS = {
    "med": {"proj": "mercator", "base": "res://data/campaigns/napoleon/maps/geo/med.json", "lon": [-600, 3000], "lat": [3400, 5150], "bg": "map_med"},
    "marseille_1815": {"proj": "canvas", "bg": "map_marseille_1815"},
    "if_fortress": {"proj": "canvas", "bg": "map_if_fortress"},
    "paris_1838": {"proj": "canvas", "bg": "map_paris"},
}
