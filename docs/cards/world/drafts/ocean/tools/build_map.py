#!/usr/bin/env python3
# Builds wm/ocean/maps/world.json (ARCH §2.2 shape) for the ocean branch and validates it:
# graph sanity, anchor order, level rules (ARCH §3.1), pacing rules R1–R7 (ARCH §2.8),
# fixed-event / pool references against wm/ocean/ocean_events.json (if present).
# Usage: python3 -I build_map.py [--report]      (exit 1 on any error)
import json, math, os, sys, itertools, heapq
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from ocean_uses import SCENE_BATTLES, CHAPTER_BOSS
ROOT = os.path.dirname(HERE)
OUT = os.path.join(ROOT, "maps", "world.json")
EVENTS = os.path.join(ROOT, "ocean_events.json")
REPO = "/home/user/dehoudang"

CHAPTER_SCENES = {
    "prologue": ["prologue"],
    "st_helena": ["scene01", "scene02", "scene03", "scene04", "scene05"],
    "new_elba": ["scene06", "scene07", "scene08", "scene09"],
    "nautilus": ["scene10", "scene11", "scene12", "finale"],
}
MP_PER_DAY = 3          # conservative: a d6 averages 3.5, the march deck averages ~2.3
BATTLE_TYPES = {"battle", "elite", "boss"}

# ------------------------------------------------------------------ node helpers
ACT_TOWN = ["visit:town", "trade:fair", "trade:counterfeit", "build_depot"]
ACT_CAMP = ["activity:rest", "schedule:recruit", "schedule:train", "schedule:bond_story", "schedule:diplomacy", "schedule:festival", "schedule:smuggle"]
ACT_SHOP = ["activity:merchant", "recruit:troop:line", "recruit:troop:grenadier", "recruit:troop:jager", "recruit:troop:hussar", "recruit:troop:artillery"]
S_EVENT = {"event": 6, "supply": 2, "camp": 1, "shop": 1}
S_MIXED = {"event": 5, "supply": 2, "camp": 2, "shop": 1, "battle": 2}


def N(id, type, label, pos, **kw):
    n = {"id": id, "type": type, "label": label}
    ref = kw.pop("geo_ref", None)
    if ref:
        kw["geo"] = [int(round(ref[0] * 100)), int(round(ref[1] * 100))]
    if isinstance(pos, tuple) and len(pos) == 3 and pos[0] == "geo":
        n["geo"] = [int(round(pos[1] * 100)), int(round(pos[2] * 100))]
    else:
        n["xy"] = [int(pos[0]), int(pos[1])]
    n.update(kw)
    return n


def G(lon, lat):
    return ("geo", lon, lat)


def L(a, b, legs=0, **kw):
    l = {"a": a, "b": b}
    if legs:
        l["legs"] = legs
    l.update(kw)
    return l


# ------------------------------------------------------------------ sheet 1: prologue (1815-06-29 .. 08-04)
prologue = {
    "chapter": "prologue", "view": "biscay", "start": "malmaison", "days_max": 9,
    "stamps_need": 2, "muster": "ile_d_aix", "boss": "plymouth", "interlude": "audience",
    "sets": [{"id": "loire_road", "label": "卢瓦尔驿道", "nodes": ["rambouillet", "poitiers"], "bonus": {"pass_supply": 1}}],
    "rivals": [{"id": "vendee_band", "label": "旺代保王军的游击队", "path": ["la_rochelle", "niort", "saintes", "niort"], "speed": 1, "start": 0,
                "meet": {"toll": {"gold": 1}}, "burns_depots": True,
                "note": "本图不能有战斗（L13 的序曲 Boss 之前不能再有更低等级的仗，主干又止于 L12），所以对手只收过路费，或用道具闪开"}],
    "nodes": [
        N("malmaison", "event", "马尔梅松", (1800, 140), geo_ref=(2.17, 48.87), date="1815-06-29", fixed=True, fog="open", event="ev_o_malmaison"),
        N("rambouillet", "supply", "朗布依埃驿站", (1660, 210), geo_ref=(1.83, 48.64), role="post", fog="open", pass_={"stamp": 1, "coins": {"supply": 1}}, actions=["visit:town", "trade:fair", "build_depot"]),
        N("chartres", "slot", "沙特尔", (1560, 300), geo_ref=(1.49, 48.45), fog="type", slot={"pool": "biscay_1815", "kinds": S_EVENT, "level": 13}),
        N("blois", "slot", "布卢瓦", (1440, 400), geo_ref=(1.33, 47.59), fog="type", slot={"pool": "biscay_1815", "kinds": S_EVENT, "level": 13}),
        N("tours", "shop", "图尔", (1290, 460), geo_ref=(0.69, 47.39), fog="type", date="1815-06-30", actions=ACT_SHOP),
        N("poitiers", "supply", "普瓦捷驿站", (1130, 590), geo_ref=(0.34, 46.58), role="post", fog="open", pass_={"stamp": 1, "coins": {"intel": 1}}, actions=["visit:town", "trade:fair", "build_depot"]),
        N("niort", "camp", "尼奥尔", (900, 560), geo_ref=(-0.46, 46.32), date="1815-07-02", fog="type", actions=ACT_CAMP),
        N("saintes", "slot", "桑特", (890, 860), geo_ref=(-0.63, 45.75), fog="type", slot={"pool": "biscay_1815", "kinds": S_EVENT, "level": 13}),
        N("la_rochelle", "slot", "拉罗谢尔", (620, 520), geo_ref=(-1.15, 46.16), fog="type", slot={"pool": "biscay_1815", "kinds": S_EVENT, "level": 13}),
        N("rochefort", "supply", "罗什福尔军港", (770, 730), geo_ref=(-0.959, 45.942), role="port", date="1815-07-03", fog="open",
          actions=["visit:town", "visit:backdoor", "trade:fair", "trade:counterfeit", "recruit:dantes", "recruit:faria"]),
        N("fouras", "shop", "富拉", (660, 700), geo_ref=(-1.09, 45.98), fog="type", actions=ACT_SHOP + ["recruit:gourgaud", "tile:smuggle"]),
        N("royan", "slot", "鲁瓦扬", (660, 940), geo_ref=(-1.03, 45.62), fog="hidden", slot={"pool": "biscay_1815", "kinds": S_EVENT, "level": 13}),
        N("oleron", "slot", "奥莱龙岛", (500, 800), geo_ref=(-1.30, 45.93), fog="hidden", slot={"pool": "biscay_1815", "kinds": S_EVENT, "level": 13}),
        N("ile_d_aix", "camp", "艾克斯岛", (560, 640), geo_ref=(-1.1747, 46.0128), role="muster", date="1815-07-12", fog="open", actions=ACT_CAMP),
        N("basque_roads", "event", "巴斯克锚地", (420, 620), geo_ref=(-1.42, 46.06), phase="campaign", date="1815-07-14", fixed=True, fog="open", event="ev_o_council_basque"),
        N("torbay", "camp", "托贝湾", (430, 150), geo_ref=(-3.52, 50.45), phase="campaign", date="1815-07-24", fog="open", actions=["activity:rest", "schedule:bond_story"]),
        N("plymouth", "boss", "普利茅斯湾·贝勒罗丰号", (250, 180), geo_ref=(-4.14, 50.33), scene="prologue", phase="campaign", date="1815-08-04", fixed=True, fog="open"),
    ],
    "links": [
        L("malmaison", "rambouillet", 2), L("rambouillet", "chartres", 1), L("chartres", "blois", 2), L("blois", "tours", 1),
        L("rambouillet", "tours", 3), L("tours", "poitiers", 2), L("poitiers", "niort", 2),
        L("niort", "la_rochelle", 2), L("niort", "saintes", 2), L("niort", "rochefort", 2),
        L("saintes", "rochefort", 1), L("saintes", "royan", 1), L("royan", "rochefort", 2, toll={"gold": 1}),
        L("la_rochelle", "rochefort", 1, toll={"gold": 1}), L("rochefort", "fouras", 1),
        L("fouras", "ile_d_aix", 1, route="smuggle_route"), L("fouras", "oleron", 1), L("oleron", "ile_d_aix", 1),
        L("la_rochelle", "ile_d_aix", 2, route="salon_route"),
        L("ile_d_aix", "basque_roads", 1), L("basque_roads", "torbay", voyage_days=2), L("torbay", "plymouth", 1),
    ],
}

# ------------------------------------------------------------------ sheet 2: st_helena (1817-11 .. 1821-05), local canvas
st_helena = {
    "chapter": "st_helena", "view": "longwood", "start": "jamestown", "days_max": 12,
    "stamps_need": 2, "muster": "muster_longwood", "boss": "longwood", "interlude": "camp_night",
    "sets": [{"id": "south_coast", "label": "南岸接应线", "nodes": ["rupert_bay", "lots_wife"], "bonus": {"pass_supply": 1}}],
    "rivals": [{"id": "lowe_patrol", "label": "总督巡逻队", "path": ["briars", "alarm_house", "hutts_gate", "alarm_house"], "speed": 1, "start": 0,
                "meet": {"battle": {"template": "signal_hill", "level": 14}, "toll": {"gold": 1}}, "burns_depots": True}],
    "nodes": [
        N("jamestown", "story", "詹姆斯敦·海鸥号补给栈", (430, 300), scene="scene01", date="1817-11-01", fixed=True, fog="open", actions=["visit:town", "trade:fair", "trade:counterfeit"]),
        N("wharf", "battle", "詹姆斯敦码头", (300, 220), scene="scene02", date="1818-06-01", fixed=True, fog="open"),
        N("royal_oak", "story", "皇家橡树酒馆", (520, 215), scene="scene03", date="1819-09-01", fixed=True, fog="open"),
        N("company_store", "shop", "东印度公司货栈", (600, 330), fog="open", actions=ACT_SHOP + ["recruit:marie", "recruit:morel", "recruit:dantes", "recruit:faria"]),
        N("mundens_point", "slot", "芒登炮台", (650, 140), fog="type", slot={"pool": "st_helena", "kinds": S_EVENT, "level": 14}),
        N("rupert_bay", "supply", "鲁珀特湾", (800, 170), role="depot", fog="type", actions=["build_depot", "trade:fair", "tile:smuggle"]),
        N("ladder_hill", "supply", "梯子山信号站", (330, 400), role="post", fog="open", pass_={"stamp": 1, "coins": {"intel": 1}}, actions=["visit:town"]),
        N("high_knoll", "slot", "高丘堡", (400, 540), fog="type", slot={"pool": "st_helena", "kinds": S_MIXED, "level": 14}),
        N("lemon_valley", "slot", "柠檬谷", (190, 500), fog="type", slot={"pool": "st_helena", "kinds": S_EVENT, "level": 14}),
        N("thompson_valley", "slot", "汤普森谷", (240, 720), fog="hidden", slot={"pool": "st_helena", "kinds": S_EVENT, "level": 14}),
        N("plantation", "supply", "种植园宅邸（总督府）", (500, 690), role="intel", fog="open", demands=["bond"], actions=["visit:backdoor"]),
        N("briars", "camp", "荆棘园", (600, 430), fog="open", actions=ACT_CAMP),
        N("alarm_house", "supply", "警报屋信号站", (760, 460), role="post", fog="open", pass_={"stamp": 1, "coins": {"supply": 1}}, actions=["visit:town"]),
        N("hutts_gate", "supply", "哈茨门·贝特朗小屋", (900, 500), role="intel", fog="open", demands=["medicine"], actions=["visit:backdoor", "trade:fair"]),
        N("diana_peak", "slot", "戴安娜峰", (780, 640), fog="type", slot={"pool": "st_helena", "kinds": S_EVENT, "level": 14}),
        N("sandy_bay", "slot", "桑迪湾", (720, 880), fog="type", slot={"pool": "st_helena", "kinds": S_MIXED, "level": 14}),
        N("lots_wife", "supply", "罗得之妻岩下的小码头", (560, 960), role="depot", fog="type", actions=["build_depot", "trade:fair", "tile:smuggle"]),
        N("sea_cave", "elite", "南岸海蚀洞", (900, 990), scene="scene04", date="1821-04-28", fixed=True, fog="type"),
        N("flagstaff", "supply", "旗杆山信号站", (1010, 230), role="post", fog="type", pass_={"stamp": 1, "coins": {"gold": 1}}, actions=["visit:town"]),
        N("the_barn", "slot", "巴恩岩", (1250, 270), fog="hidden", slot={"pool": "st_helena", "kinds": S_EVENT, "level": 14}),
        N("turks_cap", "slot", "土耳其帽峰", (1480, 470), fog="hidden", slot={"pool": "st_helena", "kinds": S_MIXED, "level": 14}),
        N("prosperous_bay", "slot", "繁荣湾", (1400, 720), fog="hidden", slot={"pool": "st_helena", "kinds": S_EVENT, "level": 14}),
        N("muster_longwood", "camp", "朗伍德外的桉树林", (1060, 560), role="muster", fog="open", requires={"scene_done": "scene04"}, actions=ACT_CAMP),
        N("longwood_council", "event", "朗伍德·台球室（军议）", (1180, 600), phase="campaign", date="1821-05-03", fixed=True, fog="open", event="ev_o_council_billiard"),
        N("deadwood_raid", "elite", "死木平原驻军营地", (1150, 400), phase="campaign", template="deadwood_camp", level=15, weather=["night"], date="1821-05-04", fog="open",
          reward={"props": ["prop_smoke_bomb"], "coins": {"medal": 1}}),
        N("geranium_spring", "camp", "天竺葵谷泉边", (1300, 660), phase="campaign", date="1821-05-04", fog="open", actions=["activity:rest", "schedule:bond_story"]),
        N("longwood", "boss", "朗伍德庄园", (1320, 510), scene="scene05", phase="campaign", date="1821-05-05", fixed=True, fog="open"),
    ],
    "links": [
        L("jamestown", "wharf", 1), L("jamestown", "royal_oak", 1), L("jamestown", "company_store", 1), L("royal_oak", "mundens_point", 1),
        L("mundens_point", "rupert_bay", 1), L("company_store", "briars", 1), L("jamestown", "ladder_hill", 1), L("wharf", "ladder_hill", 1),
        L("ladder_hill", "lemon_valley", 2), L("ladder_hill", "high_knoll", 1), L("lemon_valley", "thompson_valley", 1),
        L("high_knoll", "plantation", 1), L("thompson_valley", "plantation", 1), L("briars", "alarm_house", 1), L("briars", "plantation", 2),
        L("alarm_house", "hutts_gate", 1), L("hutts_gate", "diana_peak", 1), L("diana_peak", "plantation", 2), L("diana_peak", "sandy_bay", 2),
        L("sandy_bay", "lots_wife", 1), L("lots_wife", "sea_cave", 1, route="smuggle_route"), L("thompson_valley", "lots_wife", 2, supply=1),
        L("rupert_bay", "flagstaff", 2), L("alarm_house", "flagstaff", 2), L("flagstaff", "the_barn", 1), L("the_barn", "turks_cap", 1),
        L("turks_cap", "prosperous_bay", 1), L("prosperous_bay", "sea_cave", 2, supply=1, route="duel_route"),
        L("hutts_gate", "muster_longwood", 1), L("prosperous_bay", "muster_longwood", 2), L("sea_cave", "muster_longwood", 2, requires={"scene_done": "scene04"}),
        L("muster_longwood", "longwood_council", 1), L("longwood_council", "deadwood_raid", 1), L("deadwood_raid", "geranium_spring", 2),
        L("longwood_council", "geranium_spring", 1), L("geranium_spring", "longwood", 1),
    ],
}

# ------------------------------------------------------------------ sheet 3: new_elba (1822-03 .. 1824-09), invented island, local canvas
new_elba = {
    "chapter": "new_elba", "view": "new_elba", "start": "wreck_shoal", "days_max": 12,
    "stamps_need": 2, "muster": "muster_east", "boss": "skull_reef", "interlude": "bond",
    "sets": [{"id": "west_works", "label": "西岸工场", "nodes": ["salt_flats", "tide_pools"], "bonus": {"pass_supply": 1}}],
    "rivals": [{"id": "viper_longboat", "label": "毒蛇号的小艇", "path": ["lookout_n", "whale_bay", "salt_flats", "whale_bay"], "speed": 1, "start": 0,
                "meet": {"battle": {"template": "beach_landing", "level": 17}, "toll": {"gold": 1}}, "burns_depots": True}],
    "nodes": [
        N("wreck_shoal", "battle", "信天翁号沉船浅滩", (380, 770), scene="scene06", date="1822-03-14", fixed=True, fog="open"),
        N("landing_camp", "camp", "登陆海滩营地", (540, 860), fog="open", actions=ACT_CAMP),
        N("tide_pools", "supply", "潮池", (250, 600), role="depot", fog="type", actions=["build_depot", "trade:fair"]),
        N("west_cliffs", "slot", "西岸断崖", (230, 400), fog="type", slot={"pool": "new_elba", "kinds": S_EVENT, "level": 18}),
        N("freshwater_spring", "supply", "泉眼", (690, 620), fog="open", actions=["visit:town", "trade:fair", "trade:counterfeit"]),
        N("brick_kiln", "supply", "砖窑", (600, 470), role="project", fog="open", actions=["build"]),
        N("granite_exchange", "story", "花岗岩宫·鲸骨交易所", (470, 340), scene="scene07", date="1824-09-13", fixed=True, fog="open"),
        N("granite_workshop", "elite", "花岗岩宫·后堂工坊", (420, 210), scene="scene08", date="1824-09-14", fixed=True, fog="open"),
        N("water_forge", "supply", "水力锻炉", (830, 640), role="project", fog="type", actions=["build", "recruit:baptiste"]),
        N("friday_village", "shop", "星期五的村子", (780, 900), fog="type", actions=ACT_SHOP + ["recruit:friday", "recruit:corso", "tile:festival"]),
        N("palm_grove", "slot", "棕榈林", (1080, 760), fog="type", slot={"pool": "new_elba", "kinds": S_EVENT, "level": 18}),
        N("volcano", "slot", "火山口", (980, 450), fog="type", slot={"pool": "new_elba", "kinds": S_MIXED, "level": 18}),
        N("bat_cave", "slot", "蝙蝠洞", (760, 300), fog="hidden", slot={"pool": "new_elba", "kinds": S_EVENT, "level": 18}),
        N("lookout_n", "supply", "北岬瞭望火堆", (990, 150), role="post", fog="open", pass_={"stamp": 1, "coins": {"intel": 1}}, actions=["visit:town"]),
        N("lookout_s", "supply", "南岬瞭望火堆", (930, 990), role="post", fog="open", pass_={"stamp": 1, "coins": {"supply": 1}}, actions=["visit:town"]),
        N("whale_bay", "slot", "鲸湾", (1330, 210), fog="type", slot={"pool": "new_elba", "kinds": S_MIXED, "level": 18}),
        N("salt_flats", "supply", "盐滩", (1300, 380), role="depot", fog="type", actions=["build_depot", "trade:fair"]),
        N("lagoon", "slot", "礁湖", (1250, 860), fog="type", slot={"pool": "new_elba", "kinds": S_EVENT, "level": 18}),
        N("reef_pass", "slot", "礁口水道", (1500, 780), fog="hidden", slot={"pool": "new_elba", "kinds": S_EVENT, "level": 18}),
        N("muster_east", "camp", "东岸营地", (1450, 540), role="muster", fog="open", requires={"scene_done": "scene08"}, actions=ACT_CAMP),
        N("east_rocks", "event", "东岸礁石（军议）", (1560, 420), phase="campaign", date="1824-09-15", fixed=True, fog="open", event="ev_o_council_reef"),
        N("reef_fire", "camp", "骷髅礁前的篝火", (1580, 640), phase="campaign", date="1824-09-15", fog="open", actions=["activity:rest", "schedule:bond_story"]),
        N("skull_reef", "boss", "东岸·骷髅礁", (1720, 520), scene="scene09", phase="campaign", date="1824-09-15", fixed=True, fog="open"),
    ],
    "links": [
        L("wreck_shoal", "landing_camp", 1), L("wreck_shoal", "tide_pools", 2), L("landing_camp", "freshwater_spring", 1),
        L("landing_camp", "friday_village", 2), L("tide_pools", "granite_exchange", 2), L("tide_pools", "west_cliffs", 1), L("west_cliffs", "granite_exchange", 1), L("freshwater_spring", "brick_kiln", 1),
        L("brick_kiln", "granite_exchange", 1), L("granite_exchange", "granite_workshop", 1, rush=False), L("freshwater_spring", "water_forge", 1),
        L("granite_exchange", "bat_cave", 2), L("bat_cave", "lookout_n", 2), L("bat_cave", "volcano", 1), L("water_forge", "volcano", 2),
        L("water_forge", "palm_grove", 2), L("friday_village", "lookout_s", 1), L("lookout_s", "lagoon", 2), L("palm_grove", "lagoon", 1),
        L("lookout_n", "whale_bay", 2), L("whale_bay", "salt_flats", 1), L("volcano", "salt_flats", 2), L("lagoon", "reef_pass", 1),
        L("salt_flats", "muster_east", 1), L("reef_pass", "muster_east", 2), L("palm_grove", "muster_east", 3, supply=1),
        L("muster_east", "east_rocks", 1), L("east_rocks", "reef_fire", 1), L("reef_fire", "skull_reef", 1),
    ],
}

# ------------------------------------------------------------------ sheet 4: nautilus (1829-11 .. 1835-11), world view
nautilus = {
    "chapter": "nautilus", "view": "world", "start": "new_elba_port", "days_max": 16,
    "stamps_need": 2, "muster": "sargasso", "boss": "thames", "interlude": "minigame:ring",
    "sets": [{"id": "south_atlantic", "label": "南大西洋补给链", "nodes": ["juan_fernandez", "tristan"], "bonus": {"pass_supply": 1}}],
    "rivals": [{"id": "admiralty_squadron", "label": "海军部猎潜分舰队", "path": ["madeira", "gibraltar", "madeira", "canaries"], "speed": 1, "start": 0,
                "meet": {"battle": {"template": "nautilus_deck_raid", "level": 21}, "toll": {"gold": 2}}, "burns_depots": True}],
    "nodes": [
        N("new_elba_port", "story", "新厄尔巴自由港外海", G(-118.5, -39.5), scene="scene10", date="1829-11-02", fixed=True, fog="open",
          actions=["recruit:nemo", "trade:fair"]),
        N("lincoln_island", "slot", "林肯岛", G(-150.5, -34.95), fog="hidden", slot={"pool": "nautilus", "kinds": S_EVENT, "level": 22}),
        N("easter_island", "slot", "复活节岛", G(-109.35, -27.11), fog="type", slot={"pool": "nautilus", "kinds": S_EVENT, "level": 22}),
        N("juan_fernandez", "supply", "胡安·费尔南德斯群岛", G(-78.83, -33.64), role="depot", fog="type", actions=["build_depot", "trade:fair"]),
        N("cape_horn", "slot", "合恩角", G(-67.27, -55.98), fog="type", slot={"pool": "nautilus", "kinds": S_EVENT, "level": 22}),
        N("ice_barrier", "battle", "南极冰障", G(-60.0, -67.6), template="ice_shelf", level=21, weather=["snow", "storm"], fog="hidden",
          reward={"coins": {"medal": 1, "intel": 1}, "metrics": {"exploration": 10}}),
        N("rio", "shop", "里约热内卢", G(-43.17, -22.91), fog="type", actions=ACT_SHOP + ["recruit:nemo", "recruit:morel", "tile:festival", "tile:gamble"]),
        N("tristan", "supply", "特里斯坦-达库尼亚", G(-12.28, -37.11), role="depot", fog="hidden", actions=["build_depot"]),
        N("cape_town", "supply", "开普敦", G(18.42, -33.92), role="post", fog="type", pass_={"stamp": 1, "coins": {"gold": 1}}, actions=["visit:town", "trade:fair", "trade:counterfeit"]),
        N("st_helena_view", "event", "圣赫勒拿（远望）", G(-5.70, -15.97), fixed=True, fog="open", event="ev_o_st_helena_view"),
        N("ascension", "supply", "阿森松岛", G(-14.41, -7.93), role="post", fog="open", pass_={"stamp": 1, "coins": {"supply": 1}}, actions=["visit:town"]),
        N("ceylon", "event", "锡兰·马纳尔珍珠场", G(79.8, 8.7), fixed=True, fog="hidden", event="ev_o_pearl_bank"),
        N("falklands", "slot", "福克兰群岛", G(-59.5, -51.7), fog="type", slot={"pool": "nautilus", "kinds": S_EVENT, "level": 22}),
        N("arabian_tunnel", "slot", "阿拉伯隧道", G(32.45, 30.5), fog="hidden", slot={"pool": "nautilus", "kinds": S_EVENT, "level": 22}),
        N("crete", "supply", "克里特岛", G(24.9, 35.25), role="project", fog="type", actions=["fund", "visit:backdoor", "tile:diplomacy"]),
        N("gibraltar", "slot", "直布罗陀海峡", G(-5.35, 36.14), fog="type", slot={"pool": "nautilus", "kinds": S_EVENT, "level": 22}),
        N("noronha", "slot", "费尔南多-迪诺罗尼亚", G(-32.4, -3.85), fog="hidden", slot={"pool": "nautilus", "kinds": S_EVENT, "level": 22}),
        N("trindade", "slot", "特林达德岛", G(-29.3, -20.5), fog="hidden", slot={"pool": "nautilus", "kinds": S_MIXED, "level": 22}),
        N("canaries", "slot", "加那利群岛", G(-15.6, 28.3), fog="type", slot={"pool": "nautilus", "kinds": S_EVENT, "level": 22}),
        N("madeira", "supply", "马德拉岛", G(-16.9, 32.65), role="post", fog="open", pass_={"stamp": 1, "coins": {"intel": 1}}, actions=["visit:town", "trade:fair"]),
        N("vigo", "elite", "维哥湾", G(-8.72, 42.26), scene="scene11", date="1831-04-01", fixed=True, fog="open"),
        N("lofoten", "supply", "罗弗敦·大漩涡", G(12.8, 67.8), role="project", fog="hidden", actions=["explore"]),
        N("atlantis", "battle", "亚特兰蒂斯", G(-20.0, 35.0), scene="scene12", date="1834-12-01", fixed=True, fog="type"),
        N("deep_trench", "supply", "大西洋海沟", G(-36.0, 31.0), role="project", fog="type", actions=["explore"]),
        N("sargasso", "camp", "马尾藻海（藏船）", G(-55.0, 29.0), role="muster", fog="type", requires={"scene_done": "scene12"}, actions=ACT_CAMP),
        N("bermuda", "event", "百慕大外海（军议）", G(-64.7, 32.3), phase="campaign", fixed=True, fog="open", event="ev_o_council_bermuda"),
        N("bahamas_squid", "elite", "巴哈马浅海", G(-77.0, 26.0), phase="campaign", template="squid_platform", level=23, weather=["clear"], date="1835-04-20", fog="open",
          reward={"coins": {"medal": 2}, "props": ["prop_imperial_decree"]}),
        N("azores", "camp", "亚速尔群岛", G(-25.67, 37.74), phase="campaign", fog="open", actions=["activity:rest", "schedule:bond_story"]),
        N("thames", "boss", "泰晤士河口·格林威治", G(-0.0077, 51.4826), scene="finale", phase="campaign", date="1835-11-09", fixed=True, fog="open"),
    ],
    "links": [
        L("new_elba_port", "lincoln_island", 2), L("new_elba_port", "easter_island", 2), L("easter_island", "juan_fernandez", 3),
        L("lincoln_island", "cape_horn", voyage_days=2), L("juan_fernandez", "cape_horn", 3), L("cape_horn", "ice_barrier", voyage_days=2),
        L("ice_barrier", "tristan", voyage_days=2), L("cape_horn", "rio", voyage_days=2), L("cape_horn", "falklands", 1), L("falklands", "tristan", voyage_days=2), L("falklands", "rio", 4),
        L("tristan", "cape_town", 3), L("rio", "trindade", 2), L("trindade", "st_helena_view", 2), L("tristan", "st_helena_view", 3), L("cape_town", "st_helena_view", 3),
        L("st_helena_view", "ascension", 2), L("cape_town", "ceylon", voyage_days=3), L("ceylon", "arabian_tunnel", voyage_days=2),
        L("arabian_tunnel", "crete", 2), L("crete", "gibraltar", voyage_days=2), L("ascension", "canaries", 4),
        L("ascension", "madeira", voyage_days=2), L("canaries", "madeira", 1), L("madeira", "gibraltar", 2), L("madeira", "vigo", 3),
        L("gibraltar", "vigo", 2), L("vigo", "lofoten", voyage_days=2), L("rio", "noronha", 3), L("noronha", "ascension", 3), L("madeira", "atlantis", 2),
        L("canaries", "atlantis", 3), L("atlantis", "deep_trench", 2), L("deep_trench", "sargasso", 3), L("atlantis", "sargasso", voyage_days=2),
        L("sargasso", "bermuda", 2), L("bermuda", "bahamas_squid", 2), L("bahamas_squid", "azores", voyage_days=2),
        L("bermuda", "azores", voyage_days=2), L("azores", "thames", voyage_days=2),
    ],
}

SHEETS = [prologue, st_helena, new_elba, nautilus]

VIEWS = {
    "biscay": {"proj": "canvas", "bg": "map_biscay", "size": [1920, 1080],
               "_note": "示意图，不是严格投影：巴黎在右上、英格兰西南角在左上、夏朗德海岸放大到左下半幅（罗什福尔、富拉、艾克斯岛真实相距只有十几公里，按比例画会挤成一团）。节点同时写了 geo 供参考，xy 优先（ARCH §2.2）。"},
    "longwood": {"proj": "canvas", "bg": "map_st_helena", "size": [1920, 1080],
                 "_note": "圣赫勒拿全岛局部图，北在上；节点按实测位置摆开、为了好点而放大了间距"},
    "new_elba": {"proj": "canvas", "bg": "map_new_elba", "size": [1920, 1080], "_note": "虚构火山岛（南纬 39.5°、西经 118.5°），北在上"},
    "world": {"proj": "miller", "base": "world", "lon": [-18000, 18000], "lat": [-7803, 8200], "bg": "map_world",
              "_note": "沿用 wm/geo/world.json 的米勒投影全图（ARCH 原写 −180…60；锡兰和阿拉伯隧道在东经 30–80°，所以用全图）"},
}

COND_KEYS = {"flags", "any_flags", "not_flags", "metric", "stat", "coins", "alive", "items", "count_flags", "scene_done", "hero_ok", "any", "not"}


# ------------------------------------------------------------------ validation
def adj(sheet, nodes, skip=frozenset()):
    g = {n: [] for n in nodes if n not in skip}
    for l in sheet["links"]:
        a, b = l["a"], l["b"]
        if a in skip or b in skip:
            continue
        g[a].append((b, l))
        if not l.get("oneway"):
            g[b].append((a, l))
    return g


def reachable(g, s, t):
    if s not in g or t not in g:
        return False
    seen, st = {s}, [s]
    while st:
        u = st.pop()
        if u == t:
            return True
        for v, _ in g[u]:
            if v not in seen:
                seen.add(v)
                st.append(v)
    return False


def cost(l):
    """(mp, voyage days) of one link"""
    return (int(l.get("legs", 0)), int(l.get("voyage_days", 0)))


def dist_all(g):
    """all-pairs shortest (mp, days) where a link costs legs MP, voyage days in days; compare by days-equivalent"""
    def key(c):
        return c[0] / MP_PER_DAY + c[1]
    res = {}
    for s in g:
        d = {s: (0, 0)}
        pq = [(0.0, s)]
        while pq:
            k, u = heapq.heappop(pq)
            if k > key(d[u]) + 1e-9:
                continue
            for v, l in g[u]:
                m, dd = cost(l)
                c = (d[u][0] + m, d[u][1] + dd)
                if v not in d or key(c) < key(d[v]) - 1e-9:
                    d[v] = c
                    heapq.heappush(pq, (key(c), v))
        res[s] = d
    return res


def check_cond(c, where, errs):
    if not isinstance(c, dict):
        errs.append("%s: condition is not an object" % where)
        return
    for k, v in c.items():
        if k not in COND_KEYS:
            errs.append("%s: unknown condition key %s" % (where, k))
        if k in ("any",):
            for i, cc in enumerate(v):
                check_cond(cc, where + ".any[%d]" % i, errs)
        if k == "not":
            check_cond(v, where + ".not", errs)


def validate(events_doc):
    errs, warns, info = [], [], {}
    ev_ids, ev_pools = set(), {}
    if events_doc:
        for e in events_doc.get("events", []):
            ev_ids.add(e["id"])
            ev_pools.setdefault(e.get("pool", ""), []).append(e["id"])
    prev_interlude = None
    all_ids = set()
    for sh in SHEETS:
        ch = sh["chapter"]
        boss_L = CHAPTER_BOSS[ch]
        nodes = {n["id"]: n for n in sh["nodes"]}
        if len(nodes) != len(sh["nodes"]):
            errs.append("%s: duplicate node id" % ch)
        for nid in nodes:
            key = "ocean:" + nid
            if key in all_ids:
                errs.append("%s: node id %s reused in another sheet" % (ch, nid))
            all_ids.add(key)
        for k in ("start", "muster", "boss"):
            if sh[k] not in nodes:
                errs.append("%s: %s %s is not a node" % (ch, k, sh[k]))
        for l in sh["links"]:
            for e in ("a", "b"):
                if l[e] not in nodes:
                    errs.append("%s: link to unknown node %s" % (ch, l[e]))
            m, d = cost(l)
            if (m == 0) == (d == 0):
                errs.append("%s: link %s-%s needs exactly one of legs / voyage_days" % (ch, l["a"], l["b"]))
            if m and not 1 <= m <= 4:
                errs.append("%s: link %s-%s legs %d not in 1..4" % (ch, l["a"], l["b"], m))
            if "requires" in l:
                check_cond(l["requires"], "%s link %s-%s" % (ch, l["a"], l["b"]), errs)
        if errs:
            return errs, warns, info
        # view coordinates
        v = VIEWS[sh["view"]]
        for n in sh["nodes"]:
            if v["proj"] == "canvas":
                if "xy" not in n or not (0 <= n["xy"][0] <= 1920 and 0 <= n["xy"][1] <= 1080):
                    errs.append("%s: node %s needs xy inside 1920x1080" % (ch, n["id"]))
            else:
                if "geo" not in n or not (v["lon"][0] <= n["geo"][0] <= v["lon"][1] and v["lat"][0] <= n["geo"][1] <= v["lat"][1]):
                    errs.append("%s: node %s geo %s outside view %s" % (ch, n["id"], n.get("geo"), sh["view"]))
            if "requires" in n:
                check_cond(n["requires"], "%s node %s" % (ch, n["id"]), errs)
        # anchors
        anchors = [n for n in sh["nodes"] if n.get("scene")]
        scenes = [n["scene"] for n in anchors]
        if sorted(scenes, key=CHAPTER_SCENES[ch].index) != scenes or sorted(scenes) != sorted(CHAPTER_SCENES[ch]):
            errs.append("%s: anchors %s do not cover scene_ids %s in order" % (ch, scenes, CHAPTER_SCENES[ch]))
        if nodes[sh["boss"]].get("scene") != CHAPTER_SCENES[ch][-1]:
            errs.append("%s: boss node must carry the last scene" % ch)
        for n in anchors:
            if not n.get("fixed"):
                errs.append("%s: anchor %s must be fixed" % (ch, n["id"]))
            sb = SCENE_BATTLES[n["scene"]]
            want = "story"
            if sb["template"]:
                want = {"bellerophon_deck": "boss", "longwood_escape": "boss", "skull_reef": "boss", "thames_estuary": "boss",
                        "sea_cave": "elite", "viper_boarding": "elite", "vigo_seabed": "elite"}.get(sb["template"], "battle")
            if n["type"] != want:
                errs.append("%s: anchor %s for %s should be type %s (scene battle %s)" % (ch, n["id"], n["scene"], want, sb["template"] or "none"))
        # muster gate: last accumulate anchor must be done before mustering
        acc_anchors = [n for n in anchors if n.get("phase", "accumulate") == "accumulate"]
        if acc_anchors:
            last = acc_anchors[-1]["scene"]
            if nodes[sh["muster"]].get("requires") != {"scene_done": last}:
                errs.append("%s: muster must require scene_done %s (else mustering locks that anchor)" % (ch, last))
        if nodes[sh["muster"]].get("role") != "muster" or nodes[sh["muster"]]["type"] != "camp":
            errs.append("%s: muster node must be a camp with role muster" % ch)
        # battle-class nodes and levels
        def battle_class(n):
            if n["type"] in BATTLE_TYPES:
                return True
            if n.get("scene") and SCENE_BATTLES[n["scene"]]["template"]:
                return True
            if n["type"] == "slot" and n["slot"]["kinds"].get("battle", 0) > 0:
                return True
            return False
        for n in sh["nodes"]:
            lv = None
            kind = n["type"]
            if n["type"] in ("battle", "elite") and not n.get("scene"):
                lv = n["level"]
                if "template" not in n:
                    errs.append("%s: %s needs a template" % (ch, n["id"]))
            if n["type"] == "slot" and n["slot"]["kinds"].get("battle", 0) > 0:
                lv, kind = n["slot"]["level"], "battle"
            if lv is not None:
                if lv < 13:
                    errs.append("%s: %s level %d < 13" % (ch, n["id"], lv))
                if kind == "battle" and lv > boss_L - 2:
                    errs.append("%s: %s battle L%d > boss-2 (%d)" % (ch, n["id"], lv, boss_L - 2))
                if kind == "elite" and lv > boss_L - 1:
                    errs.append("%s: %s elite L%d > boss-1" % (ch, n["id"], lv))
            if n["type"] == "slot":
                pools = n["slot"]["pool"]
                if events_doc and not (ev_pools.get(pools) or ev_pools.get("ocean")):
                    errs.append("%s: slot %s pool %s has no events" % (ch, n["id"], pools))
            if n["type"] == "event" and n.get("fixed"):
                if events_doc and n.get("event") not in ev_ids:
                    errs.append("%s: fixed event node %s references unknown event %s" % (ch, n["id"], n.get("event")))
            for a in n.get("actions", []):
                if a == "build" and ch != "new_elba":
                    errs.append("%s: build only works in new_elba (kernel _project)" % ch)
                if a in ("explore", "fund") and ch != "nautilus":
                    errs.append("%s: %s only works in nautilus" % (ch, a))
        for r in sh.get("rivals", []):
            prev = None
            g0 = adj(sh, nodes)
            for p in r["path"]:
                if p not in nodes:
                    errs.append("%s: rival %s path node %s unknown" % (ch, r["id"], p))
                elif prev and p not in [x for x, _ in g0[prev]]:
                    errs.append("%s: rival %s path %s-%s not linked" % (ch, r["id"], prev, p))
                prev = p
            b = r["meet"].get("battle")
            if b and not (13 <= b["level"] <= boss_L - 2):
                errs.append("%s: rival %s battle L%d outside 13..%d" % (ch, r["id"], b["level"], boss_L - 2))
        g = adj(sh, nodes)
        s, t = sh["start"], sh["boss"]
        if not reachable(g, s, t):
            errs.append("%s: boss unreachable" % ch)
        # R1
        camps = {n["id"] for n in sh["nodes"] if n["type"] == "camp"}
        sups = {n["id"] for n in sh["nodes"] if n["type"] in ("supply", "shop")}
        if reachable(adj(sh, nodes, frozenset(camps)), s, t):
            errs.append("%s R1: a path to the boss avoids every camp" % ch)
        if reachable(adj(sh, nodes, frozenset(sups)), s, t):
            errs.append("%s R1: a path to the boss avoids every supply/shop" % ch)
        # R2
        for l in sh["links"]:
            if battle_class(nodes[l["a"]]) and battle_class(nodes[l["b"]]) and not l.get("rush"):
                errs.append("%s R2: battle nodes %s and %s are adjacent" % (ch, l["a"], l["b"]))
        # R3
        slots = [n for n in sh["nodes"] if n["type"] == "slot"]
        share = len(slots) * 100 // len(nodes)
        exp_ev = sum(n["slot"]["kinds"].get("event", 0) / sum(n["slot"]["kinds"].values()) for n in slots)
        if share < 30:
            errs.append("%s R3: slots are %d%% of nodes (< 30%%)" % (ch, share))
        if exp_ev < 3:
            errs.append("%s R3: expected events %.2f < 3" % (ch, exp_ev))
        # R4
        for n in sh["nodes"]:
            if n["type"] == "elite" and not n.get("scene"):
                if not reachable(adj(sh, nodes, frozenset([n["id"]])), s, t):
                    errs.append("%s R4: elite %s is on every path" % (ch, n["id"]))
        # R5: campaign-phase chain
        camp_nodes = [n for n in sh["nodes"] if n.get("phase") == "campaign"]
        council = [n for n in camp_nodes if n["type"] == "event"]
        cnight = [n for n in camp_nodes if n["type"] == "camp"]
        if len(council) != 1 or len(cnight) != 1:
            errs.append("%s R5: campaign phase needs exactly one council event and one camp night" % ch)
        else:
            c, k = council[0]["id"], cnight[0]["id"]
            nb = lambda x: {y for y, _ in g[x]}
            if c not in nb(sh["muster"]):
                errs.append("%s R5: council %s must follow the muster" % (ch, c))
            if t not in nb(k):
                errs.append("%s R5: camp night %s must lead into the boss" % (ch, k))
            if reachable(adj(sh, nodes, frozenset([k])), sh["muster"], t):
                errs.append("%s R5: the boss is reachable without the camp night" % ch)
            if reachable(adj(sh, nodes, frozenset([c])), sh["muster"], t):
                errs.append("%s R5: the boss is reachable without the council" % ch)
            for n in camp_nodes:
                if n["type"] == "elite" and not ({c} & nb(n["id"]) and {k} & nb(n["id"])):
                    errs.append("%s R5: elite %s must sit between council and camp night" % (ch, n["id"]))
        for n in sh["nodes"]:
            if n.get("phase") == "campaign":
                for y, _ in g[n["id"]]:
                    if nodes[y].get("phase", "accumulate") != "campaign" and y != sh["muster"]:
                        errs.append("%s: campaign node %s links back into the accumulate phase (%s)" % (ch, n["id"], y))
        # R6
        if prev_interlude and prev_interlude == sh["interlude"]:
            errs.append("%s R6: interlude %s repeats the previous chapter's" % (ch, sh["interlude"]))
        prev_interlude = sh["interlude"]
        # R7: start -> anchors in order -> muster with >= stamps_need posts on the way (posts may be visited anywhere)
        acc = {n for n, x in nodes.items() if x.get("phase", "accumulate") == "accumulate"}
        ga = adj(sh, nodes, frozenset(set(nodes) - acc))
        D = dist_all(ga)
        posts = [n["id"] for n in sh["nodes"] if n.get("role") == "post"]
        seq = [s] + [n["id"] for n in acc_anchors if n["id"] != s]
        best = None
        for k in range(sh["stamps_need"], len(posts) + 1):
            for chosen in itertools.combinations(posts, k):
                for perm in itertools.permutations(chosen):
                    # posts are inserted after the anchors (the cheapest common case) — also try before the last anchor
                    for cut in range(1, len(seq) + 1):
                        route = seq[:cut] + list(perm) + seq[cut:] + [sh["muster"]]
                        mp = dd = 0
                        ok = True
                        for a, b in zip(route, route[1:]):
                            if b not in D[a]:
                                ok = False
                                break
                            mp += D[a][b][0]
                            dd += D[a][b][1]
                        if ok:
                            days = math.ceil(mp / MP_PER_DAY) + dd
                            if best is None or days < best[0]:
                                best = (days, route, mp, dd)
            if best:
                break
        if not best:
            errs.append("%s R7: no route reaches the muster with enough stamps" % ch)
        else:
            if sh["days_max"] < best[0] + 3:
                errs.append("%s R7: days_max %d < shortest %d + 3" % (ch, sh["days_max"], best[0]))
            info[ch] = {"shortest_accumulate_days": best[0], "route": best[1], "mp": best[2], "voyage_days": best[3],
                        "nodes": len(nodes), "slots": len(slots), "slot_share_pct": share, "expected_events_x100": int(exp_ev * 100),
                        "battle_nodes": sorted(n["id"] for n in sh["nodes"] if battle_class(n))}
        if len(posts) < sh["stamps_need"]:
            errs.append("%s: only %d posts for stamps_need %d" % (ch, len(posts), sh["stamps_need"]))
    return errs, warns, info


def main():
    events_doc = None
    if os.path.exists(EVENTS):
        with open(EVENTS, encoding="utf-8") as f:
            events_doc = json.load(f)
    for sh in SHEETS:
        for n in sh["nodes"]:
            if "pass_" in n:
                n["pass"] = n.pop("pass_")
    errs, warns, info = validate(events_doc)
    doc = {
        "_doc": "远洋分支的世界地图（ARCH §2.2 形状）。一章一张图：序曲（比斯开，1815）、圣赫勒拿（全岛局部图）、新厄尔巴（虚构火山岛局部图）、鹦鹉螺号（世界全图）。"
                "geo = [经度×100, 纬度×100]；xy = 1920×1080 画布坐标。锚点按章节 scene_ids 的顺序；带 scene 的 battle/elite/boss 节点打这一场的战斗（模板和等级见 ocean_battles.json 的 scene_battles），"
                "type 为 story 的锚点在拿破仑书里不打仗。event 是固定事件的 id（ocean_events.json），demands 是在这里交付的催逼。由 tools/build_map.py 生成并按 R1–R7 校验。",
        "id": "world", "version": 1, "segment": "ocean",
        "views": VIEWS,
        "sheets": SHEETS,
        "_validation": info,
    }
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "w", encoding="utf-8") as f:
        json.dump(doc, f, ensure_ascii=False, indent=1)
    if "--report" in sys.argv or errs:
        for ch, i in info.items():
            print(ch, json.dumps(i, ensure_ascii=False))
        for e in errs:
            print("ERR", e)
        if not events_doc:
            print("note: ocean_events.json not found, event references not checked")
    print("wrote", OUT, "errors" if errs else "ok")
    return 1 if errs else 0


if __name__ == "__main__":
    sys.exit(main())
