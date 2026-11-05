# Ocean-branch battle templates (battle_templates.json shape + ARCH §3/§4 extensions).
# Routes are written as waypoint chains ("J2>C2>C3>A3"); build_battles.py expands them to cell lists.
# Columns A.. from the left (our eagle side), rows 1.. from the top.
U = lambda kind, **kw: dict({"kind": kind}, **kw)

TEMPLATES = {}

# ---------------------------------------------------------------- prologue boss
TEMPLATES["bellerophon_deck"] = {
    "name": "贝勒罗丰号甲板", "date": "1815-08-04", "scale": "grand", "size": [10, 6], "level": 13, "node": "boss",
    "turn_limit": 13, "enemy_morale": 26, "weather": "clear",
    "map": [
        "_WWWWWWWW_",
        "qqdddddddG",
        "Eddt|dt|dq",
        "EddddHdddq",
        "qqdddddddG",
        "_WWpWWWpW_",
    ],
    "routes": {
        "port": "J2>C2>C3>A3",
        "stbd": "J5>C5>C4>A4",
        "hatch": "F4>A4",
        "aft_plank": "D6>D5>C5>C4>A4",
        "fore_plank": "H6>H5>C5>C4>A4",
    },
    "waves": [
        {"turn": 1, "route": "port", "units": ["royalist_bravo", "royalist_bravo", "royalist_marksman"]},
        {"turn": 1, "route": "stbd", "units": ["royalist_bravo", "royalist_bravo"]},
        {"turn": 2, "at": "G1", "units": ["gunboat"], "first_fire": 4},
        {"turn": 3, "route": "fore_plank", "units": ["chouan", "royalist_bravo", "royalist_bravo"]},
        {"turn": 4, "route": "hatch", "units": ["assassin", "royalist_bravo"]},
        {"turn": 5, "route": "port", "units": ["royalist_chief", "royalist_bravo", "royalist_marksman"],
         "alt": [["royalist_chief", "royalist_bravo", "royalist_bravo"]]},
        {"turn": 6, "route": "stbd", "units": ["chouan", "royalist_bravo", U("royalist_bravo", tags=["hunter"])]},
        {"turn": 6, "at": "C1", "units": ["gunboat"], "first_fire": 8, "lv_min": 15},
        {"turn": 7, "route": "aft_plank", "units": ["royalist_bravo", "royalist_bravo", U("chouan", lv_min=15)]},
        {"turn": 8, "route": "port", "units": ["chouan", "royalist_bravo", "royalist_marksman"]},
        {"turn": 9, "route": "hatch", "units": ["assassin", "royalist_bravo"]},
        {"turn": 10, "route": "stbd", "units": ["royalist_chief", "chouan", "royalist_bravo", "royalist_bravo"]},
        {"turn": 11, "route": "fore_plank", "units": ["royalist_bravo", "royalist_bravo", U("chouan", lv_min=16)]},
    ],
    "order": {"type": "no_leak", "desc": "皇帝的命令：没有一个刺客走进艉楼的舱门。"},
    "notes": "普利茅斯湾，1815 年 8 月 4 日黄昏。看热闹的小艇里混着白色恐怖的刺客：左舷（第 2 行）和右舷（第 5 行）两条舷道从船艏梯口 J2、J5 压过来，"
             "第 3、7、11 回合从右舷跳板 H6、D6 接舷，第 4、9 回合有人从主舱口 F4 钻出来（猎官刺客）。G1、C1 是雇来的快艇（炮艇，第 15 级起第二艘）。"
             "两扇舱门 A3、A4 前只有 B3、B4 两格，所有路线最后都挤到这里；艉楼 A2、B2、A5、B5 是高地（炮兵、猎兵），D3（后桅盘）、G3（主桅盘）是桅盘（只有猎兵能上，射程 +1）。"
             "E3、H3 两根桅杆挡视线：G3 朝右打不到船艏，只能朝上下打两条舷道和跳板。",
}

# ---------------------------------------------------------------- st_helena
TEMPLATES["jamestown_streets"] = {
    "name": "詹姆斯敦街巷", "date": "1818-06-01", "scale": "skirmish", "size": [8, 4], "level": 14, "node": "battle",
    "turn_limit": 7, "enemy_morale": 10, "weather": "rain",
    "map": [
        "#BRBBRB#",
        "ESSSSSSG",
        "#BSBBSB#",
        "ESSSSSSG",
    ],
    "routes": {
        "main": "H2>A2",
        "lower": "H4>A4",
        "cross_dn": "H2>F2>F4>A4",
        "cross_up": "H4>C4>C2>A2",
    },
    "waves": [
        {"turn": 1, "route": "main", "units": ["bow_runner", "bow_runner"]},
        {"turn": 1, "route": "lower", "units": ["sailor", "sailor"]},
        {"turn": 2, "route": "cross_dn", "units": ["sailor", "sailor"], "alt": [["sailor", "bow_runner"]]},
        {"turn": 3, "route": "main", "units": ["redcoat", "redcoat", U("redcoat", lv_min=16)]},
        {"turn": 3, "route": "cross_up", "units": ["jack_runner"]},
        {"turn": 4, "route": "lower", "units": ["mounted_orderly", "redcoat"]},
        {"turn": 5, "route": "cross_dn", "units": ["bow_runner", "sailor", U("sailor", lv_min=18)]},
    ],
    "order": {"type": "hold", "cell": "C3", "turn": 7, "desc": "朗伍德的密令：第 7 回合结束时，我方有人守在 C3 小巷口（物证从这里送上梯子山）。"},
    "notes": "詹姆斯敦的两条街（第 2、4 行）从码头 H2、城堡门 H4 往山谷里爬，中间隔着一排房屋，C3、F3 两条小巷把两条街连起来。"
             "房屋 B 我方可以进驻（防 +2，挡视线，敌人不进屋），C1、F1 是屋顶（只有猎兵能上，射程 +1，正好朝下打穿小巷和两条街）。"
             "弓街探员和独眼杰克带“逮捕”：主角在他们的白刃下倒下直接被捕。传令骑兵是猎官。",
}

TEMPLATES["sea_cave"] = {
    "name": "南岸海蚀洞", "date": "1821-04-28", "scale": "elite", "size": [9, 5], "level": 15, "node": "elite",
    "turn_limit": 9, "enemy_morale": 14, "weather": "night",
    "map": [
        "###^^^###",
        "Eccck,,-G",
        "Ecckk,--W",
        "#ccc,,*-G",
        "####**WWW",
    ],
    "routes": {
        "north": "I2>A2",
        "south": "I4>H4>H3>A3",
    },
    "waves": [
        {"turn": 1, "route": "north", "units": ["marine", "marine"]},
        {"turn": 1, "route": "south", "units": ["sailor", "sailor"]},
        {"turn": 1, "at": "F1", "units": ["coast_sniper"]},
        {"turn": 2, "route": "north", "units": ["sailor", "sailor"]},
        {"turn": 2, "at": "I3", "units": ["gunboat"], "first_fire": 4},
        {"turn": 3, "route": "north", "units": ["marine", "boatswain"]},
        {"turn": 4, "route": "south", "units": ["sailor", "sailor", U("marine", tags=["hunter"])]},
        {"turn": 5, "route": "north", "units": ["marine", "marine", U("marine", lv_min=17)]},
        {"turn": 6, "route": "south", "units": ["boatswain", "sailor", "sailor"]},
        {"turn": 7, "route": "north", "units": ["sailor", "sailor", U("redcoat_grenadier", lv_min=16)]},
    ],
    "order": {"type": "hold", "cell": "E3", "turn": 9, "desc": "唐泰斯的口令：第 9 回合结束时，我方有人守在 E3 码头石阶（闪电号的小艇在这里靠岸）。"},
    "notes": "子夜，总督的海岸巡逻艇发现了海蚀洞。两条登陆路线：北路 I2 上岸，蹚 H2 浅水（步耗 2）上沙滩；南路 I4 下船，蹚 H4、H3、G3 三格浅水。"
             "浅水不能站人，挡人只能挡在沙滩、码头和洞里。洞穴 c：敌炮不瞄准洞里的单位，洞里挨远程防 +2，但洞穴挡视线——洞深处的横队打不出洞口。"
             "D1–F1 是崖顶高地，F1 第 1 回合就站着一名崖顶狙击手（专打主角和伙伴），D1、E1 留给我方炮兵、猎兵。I3 海面上有一艘巡逻炮艇。",
}

TEMPLATES["deadwood_camp"] = {
    "name": "死木平原营地", "date": "1821-05-04", "scale": "elite", "size": [9, 5], "level": 15, "node": "elite",
    "turn_limit": 9, "enemy_morale": 14, "weather": "night",
    "map": [
        "^w.^v.v.G",
        "E=====..G",
        "E^#.v.v..",
        "Ew..====G",
        "^ww^..^^^",
    ],
    "spawns": ["E3", "G3"],
    "routes": {
        "north": "I1>H1>H2>A2",
        "road": "I2>A2",
        "south": "I4>A4",
        "tent_e": "E3>D3>D2>A2",
        "tent_g": "G3>G4>A4",
    },
    "waves": [
        {"turn": 1, "route": "road", "units": ["redcoat", "redcoat"]},
        {"turn": 1, "route": "south", "units": ["redcoat", "redcoat"]},
        {"turn": 2, "at": "H5", "units": ["british_gun"], "first_fire": 4},
        {"turn": 2, "route": "north", "units": ["mounted_orderly"]},
        {"turn": 3, "route": "tent_e", "units": [U("redcoat", tags=["ambush"]), U("redcoat", tags=["ambush"])]},
        {"turn": 4, "route": "road", "units": ["redcoat_grenadier", "redcoat"]},
        {"turn": 5, "route": "tent_g", "units": [U("redcoat", tags=["ambush"]), U("redcoat", tags=["ambush"]), U("rifleman", tags=["ambush"])]},
        {"turn": 6, "route": "south", "units": ["brigadier", "redcoat", "redcoat"]},
        {"turn": 6, "at": "F1", "units": ["british_gun"], "first_fire": 8, "lv_min": 17},
        {"turn": 7, "route": "north", "units": ["redcoat_grenadier", U("mounted_orderly", lv_min=17)]},
    ],
    "order": {"type": "hold", "cell": "D3", "turn": 9, "desc": "密令：第 9 回合结束时，我方有人守在 D3 火药库门口（引线还在烧）。"},
    "notes": "逃亡前夜摸进死木平原的驻军营地，点了火药库的引线，营地醒了。三条路（北坡 I1、营门大路 I2、南路 I4）从营地另一头压过来，"
             "第 3、5 回合帐篷 E3、G3 里冲出被惊醒的士兵（伏兵，从帐篷出生）。帐篷是村庄格：谁站在里面谁防 +2。"
             "C3 是火药库的石墙（挡视线），B3 是墙后的高地。H5 一门营炮；第 17 级起 F1 再架一门。",
}

TEMPLATES["longwood_escape"] = {
    "name": "朗伍德突围", "date": "1821-05-05", "scale": "grand", "size": [10, 6], "level": 16, "node": "boss",
    "turn_limit": 13, "enemy_morale": 28, "weather": "rain",
    "map": [
        "^ww..u.==G",
        "E=..w.u..G",
        "E.u^^..#BB",
        "E.w..u...G",
        "Eu=.w..u.G",
        "^^ww^^ww^^",
    ],
    "routes": {
        "deadwood": "J1>H1>H2>A2",
        "lodge": "J2>A2",
        "house": "J4>A4",
        "hutts": "J5>A5",
        "cross": "J4>G4>G2>A2",
        "cross2": "J2>F2>F4>A4",
    },
    "events": [{"turn": 7, "cell": "D4", "terrain": "mud"}, {"turn": 7, "cell": "D2", "terrain": "mud"}],
    "waves": [
        {"turn": 1, "route": "lodge", "units": ["redcoat", "redcoat", "redcoat"]},
        {"turn": 1, "route": "hutts", "units": ["redcoat", "redcoat"]},
        {"turn": 2, "route": "deadwood", "units": ["mounted_orderly", "mounted_orderly"]},
        {"turn": 3, "at": "I6", "units": ["british_gun"], "first_fire": 5},
        {"turn": 3, "route": "house", "units": ["redcoat_grenadier", "redcoat", U("rifleman", tags=["hunter"])]},
        {"turn": 4, "route": "cross", "units": ["redcoat", "redcoat", "rifleman"]},
        {"turn": 5, "route": "hutts", "units": ["brigadier", "redcoat", "redcoat"]},
        {"turn": 6, "route": "deadwood", "units": ["redcoat_grenadier", "redcoat_grenadier"]},
        {"turn": 7, "route": "cross2", "units": ["redcoat", U("rifleman", tags=["hunter"]), "redcoat"]},
        {"turn": 8, "route": "lodge", "units": ["redcoat_grenadier", "redcoat", "redcoat"]},
        {"turn": 8, "at": "J6", "units": ["british_gun"], "first_fire": 10, "lv_min": 18},
        {"turn": 9, "route": "house", "units": ["brigadier", "redcoat_grenadier", "redcoat"]},
        {"turn": 10, "route": "hutts", "units": ["redcoat", "redcoat", U("mounted_orderly", lv_min=17)]},
        {"turn": 11, "route": "deadwood", "units": ["redcoat_grenadier", "redcoat", "redcoat"]},
    ],
    "order": {"type": "no_leak", "desc": "朗伍德的密令：没有一个追兵冲下山谷（A 列是通往海蚀洞的山路）。"},
    "notes": "1821 年 5 月 5 日的暴风雨夜。H3 是朗伍德庄园的围墙、I3/J3 是庄园本身（挡视线，敌人进不去）；追兵从驻军营地（J1）、门房（J2）、"
             "庄园后门大路（J4）和哈茨门大路（J5）四个方向压来，第 4、7 回合有两路斜插（经 G3 小径、F3 花园）。泥地 u 步耗 2（暴雨，第 7 回合 D2、D4 也变泥地）。"
             "D3、E3 是庄园花园里的小土丘（高地），是全场唯一能同时打到三条路的炮位；A1、B1、A6–J6 外圈也是高地，射得到边路。"
             "I6 一门营炮，第 18 级起 J6 再出一门（炮位预留，开战前不能部署）。",
}

# ---------------------------------------------------------------- new_elba
TEMPLATES["shipwreck_beach"] = {
    "name": "信天翁号沉船浅滩", "date": "1822-03-14", "scale": "skirmish", "size": [8, 4], "level": 17, "node": "battle",
    "turn_limit": 7, "enemy_morale": 10, "weather": "clear",
    "map": [
        "Ewa,,,-G",
        "nandd|*W",
        "Ea,;dd-G",
        "Ewa,,,,G",
    ],
    "routes": {
        "north": "H1>A1",
        "wreck": "H3>A3",
        "south": "H4>A4",
        "cross": "H1>E1>E3>A3",
    },
    "waves": [
        {"turn": 1, "route": "north", "units": ["sailor", "sailor"]},
        {"turn": 1, "route": "south", "units": ["pirate", "pirate"]},
        {"turn": 2, "at": "H2", "units": ["gunboat"], "first_fire": 4},
        {"turn": 2, "route": "north", "units": ["sailor", U("sailor", tags=["hunter"])]},
        {"turn": 2, "route": "wreck", "units": ["pirate", "pirate"]},
        {"turn": 3, "route": "cross", "units": ["pirate_brute", "pirate"]},
        {"turn": 4, "route": "south", "units": ["pirate", "pirate", U("pirate", lv_min=19)]},
        {"turn": 5, "route": "wreck", "units": ["pirate_captain", "pirate"]},
    ],
    "order": {"type": "hold", "cell": "E2", "turn": 7, "desc": "配给官的命令：第 7 回合结束时，我方有人站在 E2 沉船甲板上（物资还没搬完）。"},
    "notes": "海难第三夜，挂黑旗的小艇来抢信天翁号的物资（其实是毒蛇号的探子）。三条路：北滩 H1 蹚两格浅水上岸，南滩 H4 直接靠岸，沉船 H3 蹚一格浅水后踩着倾斜的甲板 E3、F3 和瓦砾 D3（步耗 2，防 +1）过来；"
             "第 3 回合有一路从北滩折进沉船（E1→E2→E3）。F2 是断桅（挡视线），G2 是暗礁；A2、C2 两座沙丘是高地（炮兵、猎兵）。海盗带“掠夺”：走进鹰旗的海盗每个让战后法郎 −15%。",
}

TEMPLATES["viper_boarding"] = {
    "name": "夜袭毒蛇号", "date": "1824-09-14", "scale": "elite", "size": [10, 5], "level": 19, "node": "elite",
    "turn_limit": 9, "enemy_morale": 16, "weather": "night",
    "map": [
        "EddddddddG",
        "_dt|dd|tq_",
        "EdddHddHdq",
        "_dt|dd|tq_",
        "EddddddddG",
    ],
    "routes": {
        "port": "J1>A1",
        "stbd": "J5>A5",
        "fore_hatch": "E3>A3",
        "main_hatch": "H3>F3>F1>A1",
        "main_hatch_s": "H3>F3>F5>A5",
    },
    "waves": [
        {"turn": 1, "at": "H2", "units": ["marine_sharpshooter"]},
        {"turn": 1, "route": "port", "units": ["marine", "sailor", "sailor"]},
        {"turn": 1, "route": "stbd", "units": ["marine", "marine"]},
        {"turn": 1, "at": "I2", "units": ["carronade"], "first_fire": 3},
        {"turn": 2, "route": "main_hatch", "units": ["sailor", "sailor", "boatswain"]},
        {"turn": 3, "route": "fore_hatch", "units": ["marine", "marine"]},
        {"turn": 3, "at": "H4", "units": [U("marine_sharpshooter", tags=["hunter"])]},
        {"turn": 4, "route": "stbd", "units": ["redcoat_grenadier", "marine"]},
        {"turn": 5, "route": "port", "units": ["boatswain", "marine", "sailor"]},
        {"turn": 5, "at": "I4", "units": ["carronade"], "first_fire": 7, "lv_min": 21},
        {"turn": 6, "route": "main_hatch_s", "units": ["marine", "marine", U("redcoat_grenadier", lv_min=21)]},
        {"turn": 7, "route": "stbd", "units": ["sailor", "sailor", U("marine", tags=["hunter"])]},
    ],
    "order": {"type": "hold", "cell": "G3", "turn": 9, "desc": "巴蒂斯特的命令：第 9 回合结束时，我方有人守在 G3 主桅下的锚缆绞盘（砍断锚缆）。"},
    "notes": "前夜摸上毒蛇号的船艏，接舷队守住三处登船口 A1、A3、A5（背后是自己的小艇）。船员从艉楼两道梯口 J1、J5、前舱口 E3、主舱口 H3 冲出来。"
             "没有高地：炮兵上不了船（集中炮火开场就放到一边），只有 C2、C4 前桅盘是我方猎兵的位子；H2、H4 主桅盘被敌方桅顶射手占着（H4 第 3 回合起，猎官）。"
             "I2（第 21 级起还有 I4）艉楼上的卡隆炮只打离它 4 列以内的格子：站在 A–D 列打不着。D2/D4、G2/G4 四根桅杆挡视线。",
}

TEMPLATES["skull_reef"] = {
    "name": "骷髅礁", "date": "1824-09-15", "scale": "grand", "size": [11, 6], "level": 20, "node": "boss",
    "turn_limit": 14, "enemy_morale": 30, "weather": "clear",
    "map": [
        "_,,-*^,,--G",
        "E,a-,,^,pdq",
        "Ea,,,,,;pdG",
        "Ea,,^,,;pdH",
        "E,a-,,^,pdq",
        "_,,-*^,,--G",
    ],
    "routes": {
        "ne_boat": "K1>H1>H3>F3>F2>A2",
        "gangway": "K3>F3>F2>A2",
        "hatch": "K4>F4>F5>A5",
        "se_boat": "K6>H6>H4>F4>F5>A5",
        "mid_n": "K1>H1>H3>A3",
        "mid_s": "K6>H6>H4>F4>F3>A3",
    },
    "events": [{"turn": 8, "cell": "B2", "terrain": "shallows"}, {"turn": 8, "cell": "B5", "terrain": "shallows"}],
    "waves": [
        {"turn": 1, "route": "ne_boat", "units": ["sailor", "sailor", "pirate"]},
        {"turn": 1, "route": "se_boat", "units": ["sailor", "sailor", "pirate"]},
        {"turn": 1, "at": "K2", "units": ["carronade"], "first_fire": 3},
        {"turn": 2, "route": "gangway", "units": ["pirate_brute", "pirate", "pirate"]},
        {"turn": 3, "route": "hatch", "units": ["marine", "marine", U("pirate", tags=["hunter"])]},
        {"turn": 4, "at": "F1", "units": [U("coast_sniper", tags=["hunter"])]},
        {"turn": 4, "route": "mid_n", "units": ["sailor", "sailor", "pirate"]},
        {"turn": 5, "route": "se_boat", "units": ["pirate_brute", "pirate", U("pirate", tags=["hunter"])]},
        {"turn": 5, "at": "K5", "units": ["carronade"], "first_fire": 7},
        {"turn": 6, "route": "gangway", "units": ["pirate_captain", "pirate", "pirate"]},
        {"turn": 7, "route": "hatch", "units": ["pirate_brute", "marine", "marine"]},
        {"turn": 8, "route": "ne_boat", "units": ["sailor", U("sailor", tags=["hunter"]), "pirate"]},
        {"turn": 9, "route": "mid_s", "units": ["pirate_brute", "pirate", "pirate"]},
        {"turn": 9, "at": "F6", "units": ["coast_sniper"], "lv_min": 22},
        {"turn": 10, "route": "gangway", "units": ["raider_captain", "pirate_brute", "pirate"]},
        {"turn": 11, "route": "hatch", "units": ["pirate_brute", "marine", U("marine", lv_min=22)]},
        {"turn": 12, "route": "se_boat", "units": ["pirate", "pirate", "sailor"]},
    ],
    "order": {"type": "no_leak", "desc": "皇帝的命令：没有一个毒蛇号的人冲到我们的小艇边。"},
    "notes": "骷髅礁的交割点。右边两列是靠在礁上的毒蛇号：J2–J5 甲板，K2、K5 艉楼（卡隆炮，只打 4 列以内），K3 跳板梯、K4 舱口；I2–I5 是搭到礁上的跳板。"
             "毒蛇号的小艇从东北 K1、东南 K6 蹚浅水上礁。E4、F1、G2、G5、F6 是黑色的骷髅岩（高地）：G2、G5 紧挨跳板，是全场最好的炮位，也最危险；"
             "F1 第 4 回合起站着一名崖顶狙击手（猎官），第 22 级起 F6 再来一名。H3、H4 是珊瑚碎石（步耗 2，防 +1）。"
             "第 8 回合涨潮：B2、B5 两格沙滩没进浅水——站在上面的我方单位退回部署栏，敌人还能蹚过去。"
             "罗伯茨舰长（猎官、军官）第 10 回合才从跳板梯下来。海盗带“掠夺”。",
}

TEMPLATES["atlantis"] = {
    "name": "亚特兰蒂斯神庙", "date": "1834-12-01", "scale": "skirmish", "size": [9, 4], "level": 22, "node": "battle",
    "turn_limit": 7, "enemy_morale": 11, "weather": "night",
    "map": [
        "_aa#a^#aG",
        "Eaa;aaaaG",
        "Ea;aaaaaG",
        "_a#a^;aaG",
    ],
    "routes": {
        "north": "I1>H1>H2>A2",
        "mid": "I2>A2",
        "low": "I3>A3",
        "south": "I4>G4>G3>A3",
    },
    "events": [{"turn": 4, "cell": "F1", "terrain": "void"}, {"turn": 5, "cell": "C4", "terrain": "rubble"}],
    "waves": [
        {"turn": 1, "route": "north", "units": ["shark", U("shark", tags=["hunter"])]},
        {"turn": 1, "route": "low", "units": ["shark", "squid_arm"]},
        {"turn": 1, "route": "mid", "units": ["squid_arm", "squid_arm"]},
        {"turn": 2, "route": "south", "units": ["great_shark", "shark"]},
        {"turn": 3, "route": "mid", "units": ["squid", "squid_arm"]},
        {"turn": 4, "route": "north", "units": [U("shark", tags=["hunter"]), U("great_shark", lv_min=23)]},
        {"turn": 5, "route": "low", "units": ["squid_arm", "squid_arm", "squid_arm"]},
    ],
    "order": {"type": "hold", "cell": "E2", "turn": 7, "desc": "尼摩的命令：第 7 回合结束时，我方有人守在 E2 波塞冬祭坛前。"},
    "notes": "海底火山照着亚特兰蒂斯的柱廊。D1、G1、C4 是还立着的石柱（墙，挡视线），F1、E4 是神庙台阶（高地），D2、C3、F4 是坍塌的碎石（步耗 2，防 +1）。"
             "第 4 回合火山震动，北阶 F1 塌进海沟（站在上面的单位退回部署栏）；第 5 回合 C4 的石柱倒成碎石，多出一格能站人的地方。"
             "四条路都是鲨鱼和章鱼：鲨鱼速 2（两条是猎官），大白鲨“穿透”（挡它要多 1 个阻挡位），章鱼重型、处决，触手也带“穿透”。夜里（深海）远程射程 −1。",
}

TEMPLATES["squid_platform"] = {
    "name": "鹦鹉螺号平台", "date": "1835-04-20", "scale": "elite", "size": [10, 5], "level": 23, "node": "elite",
    "turn_limit": 9, "enemy_morale": 16, "weather": "clear",
    "map": [
        "_WWWGWWGW_",
        "Edddddqdd_",
        "EddddddddG",
        "Edddddqdd_",
        "_WWWGWWGW_",
    ],
    "routes": {
        "n_aft": "E1>E2>A2",
        "n_bow": "H1>H3>A3",
        "s_aft": "E5>E4>A4",
        "s_bow": "H5>H3>A3",
        "ram": "J3>A3",
    },
    "waves": [
        {"turn": 1, "route": "n_aft", "units": ["squid_arm", "squid_arm"]},
        {"turn": 1, "route": "s_bow", "units": ["squid_arm", "squid_arm"]},
        {"turn": 2, "route": "s_aft", "units": ["squid_arm", U("squid_arm", tags=["hunter"])]},
        {"turn": 2, "route": "ram", "units": ["squid"]},
        {"turn": 3, "route": "n_bow", "units": ["squid_arm", "squid_arm", "squid"]},
        {"turn": 4, "route": "s_aft", "units": ["squid", "squid_arm"]},
        {"turn": 5, "route": "n_aft", "units": ["squid_arm", "squid_arm", U("squid_arm", tags=["hunter"])]},
        {"turn": 6, "route": "ram", "units": ["squid", "squid_arm", U("squid", lv_min=24)]},
        {"turn": 7, "route": "s_bow", "units": ["squid_arm", "squid_arm", "squid_arm"]},
    ],
    "order": {"type": "no_leak", "desc": "尼摩的命令：不让一条触手伸进舱口。"},
    "notes": "鹦鹉螺号浮出水面换气，成群的巨型章鱼缠上平台（凡尔纳原著第二部第十八章）。平台是一条窄长的甲板：A2、A3、A4 是三个舱口（我方鹰旗），"
             "G2 罗经罩、G4 小艇舱盖是仅有的两格高地。触手从舷边 E1、H1、E5、H5 爬上来，章鱼本体从艇艏 J3 压过来。"
             "触手带“穿透”：挡一条触手要 2 个空阻挡位（战列 1 条、掷弹兵 1 条），重型章鱼也要 2 个——光靠前排一定漏，要纵深。章鱼带“处决”。",
}

TEMPLATES["thames_estuary"] = {
    "name": "泰晤士河口", "date": "1835-11-09", "scale": "epic", "size": [12, 7], "level": 24, "node": "boss",
    "turn_limit": 14, "enemy_morale": 34, "weather": "fog",
    "map": [
        "_qWWWWWWWkRR",
        "Edddddp--k=G",
        "EdddddWWW,,G",
        "Eddqddpuuu=G",
        "EdddddWWW,,G",
        "Edddddp--k=G",
        "_qWWWWWWWk^^",
    ],
    "routes": {
        "pier2": "L2>A2",
        "pier6": "L6>A6",
        "mud3": "L4>E4>E3>A3",
        "mud5": "L4>E4>E5>A5",
        "plank2": "G2>A2",
        "plank6": "G6>A6",
        "plank4": "G4>E4>E5>A5",
    },
    "waves": [
        {"turn": 1, "route": "plank2", "units": ["marine", "marine"]},
        {"turn": 1, "route": "pier6", "units": ["sailor", "sailor", "marine"]},
        {"turn": 1, "at": "K1", "units": [U("coast_sniper", tags=["hunter"])]},
        {"turn": 2, "at": "H3", "units": ["gunboat"], "first_fire": 4},
        {"turn": 2, "route": "mud3", "units": ["sailor", "sailor"]},
        {"turn": 3, "route": "plank6", "units": ["marine", "marine", "boatswain"]},
        {"turn": 4, "route": "pier2", "units": ["redcoat_grenadier", "marine", U("rifleman", tags=["hunter"])]},
        {"turn": 4, "at": "L7", "units": ["coast_gun"], "first_fire": 6},
        {"turn": 5, "route": "plank4", "units": [U("redcoat_grenadier", tags=["boarder"]), "marine"]},
        {"turn": 6, "at": "H5", "units": ["rocket_boat"], "first_fire": 7},
        {"turn": 6, "route": "mud5", "units": ["marine", U("marine", tags=["hunter"]), "sailor"]},
        {"turn": 7, "route": "pier6", "units": ["navy_captain", "redcoat_grenadier", "marine"]},
        {"turn": 8, "route": "plank2", "units": [U("redcoat_grenadier", tags=["boarder"]), "marine", U("marine", tags=["hunter"])]},
        {"turn": 8, "at": "L1", "units": [U("coast_sniper", tags=["hunter"])]},
        {"turn": 9, "route": "mud3", "units": ["redcoat_grenadier", "sailor", U("rifleman", tags=["hunter"])]},
        {"turn": 10, "route": "plank6", "units": ["marine", "marine", "marine"]},
        {"turn": 11, "at": "I3", "units": ["steam_sloop"], "first_fire": 12},
        {"turn": 11, "route": "pier2", "units": ["navy_captain", "redcoat_grenadier", "redcoat_grenadier"]},
        {"turn": 12, "route": "plank4", "units": ["marine", "marine", U("redcoat_grenadier", tags=["boarder"])]},
    ],
    "order": {"type": "no_leak", "desc": "皇帝的命令：鹦鹉螺号的舱口一个都不许丢。"},
    "notes": "1835 年 11 月 9 日清晨，起雾（来敌少公开 1 回合）。左边 A–F 列是浮出水面的鹦鹉螺号（A2–A6 五个舱口是鹰旗），D4 是探照灯罩、B1/B7 是艉舵塔（三格高地）；"
             "G–I 列是泰晤士河：G2/G4/G6 是靠上来的小艇搭的跳板（陆战队直接从跳板上船），H2/I2、H6/I6 是浅水，H4–J4 是退潮后的泥滩（步耗 2，能站人：可以在船和岸之间放前哨）；"
             "J–L 列是格林威治岸：码头 J1/J2/J6/J7、河岸大道、K1/L1 皇家医院的屋顶（崖顶狙击手，猎官），K7/L7 是河岸炮台（L7 岸防炮）。"
             "H3 炮艇、H5 火箭艇、第 11 回合 I3 来一艘明轮炮舰。从岸上走过来的路线很长（12–13 格，蹚浅水和泥滩），真正的压力是跳板上船的陆战队和跑得快的水兵。",
}

# ---------------------------------------------------------------- random-slot pool (ARCH §3.3 base_level + pad)
TEMPLATES["signal_hill"] = {
    "name": "信号站高地", "date": "", "scale": "skirmish", "size": [8, 4], "level": 13, "base_level": 13, "node": "battle",
    "pad": {"kind": "redcoat", "every": 4},
    "turn_limit": 7, "enemy_morale": 10, "weather": "clear",
    "map": [
        "__^.|B.G",
        "E==.=..G",
        "E.w...wG",
        "__^^__^_",
    ],
    "routes": {
        "top": "H1>G1>G2>A2",
        "road": "H2>A2",
        "low": "H3>A3",
    },
    "waves": [
        {"turn": 1, "route": "road", "units": ["redcoat", "redcoat"]},
        {"turn": 1, "route": "low", "units": ["redcoat", "rifleman"]},
        {"turn": 2, "route": "top", "units": ["mounted_orderly"]},
        {"turn": 2, "route": "low", "units": ["redcoat"]},
        {"turn": 3, "route": "road", "units": ["redcoat", "redcoat"]},
        {"turn": 4, "route": "low", "units": ["brigadier", "redcoat"]},
        {"turn": 5, "route": "top", "units": ["redcoat", U("mounted_orderly", lv_min=17)]},
    ],
    "order": {"type": "hold", "cell": "D1", "turn": 7, "desc": "密令：第 7 回合结束时，我方有人守在 D1 信号杆下（抄完这一页旗语码）。"},
    "notes": "圣赫勒拿岛上的信号站：E1 是信号杆（挡视线），F1 是信号小屋（我方可进驻），C1、C4、D4、G4 是岩头（高地）。A1、B1、E4、F4、H4 是悬崖（虚空）。"
             "巡逻队沿山脊大路（第 2 行）、坡下小路（第 3 行）上来，传令骑兵从山顶 H1 绕过来（猎官）。第 17 级起每一波多一名英军步兵（每 4 级一名）。",
}

TEMPLATES["beach_landing"] = {
    "name": "滩头登陆", "date": "", "scale": "skirmish", "size": [8, 4], "level": 13, "base_level": 13, "node": "battle",
    "pad": {"kind": "marine", "every": 4},
    "turn_limit": 7, "enemy_morale": 10, "weather": "clear",
    "map": [
        "E,,,,--G",
        "E,,,n-WW",
        "E,,,,--G",
        "Enw,,--G",
    ],
    "routes": {
        "north": "H1>A1",
        "mid": "H3>A3",
        "south": "H4>C4>C3>A3",
    },
    "waves": [
        {"turn": 1, "route": "north", "units": ["sailor", "sailor"]},
        {"turn": 1, "route": "mid", "units": ["sailor", "marine"]},
        {"turn": 1, "route": "south", "units": ["marine", "marine"]},
        {"turn": 2, "at": "G2", "units": ["gunboat"], "first_fire": 4},
        {"turn": 2, "route": "mid", "units": ["sailor", "sailor"]},
        {"turn": 3, "route": "north", "units": ["boatswain", "marine"]},
        {"turn": 4, "route": "south", "units": ["sailor", U("sailor", tags=["hunter"])]},
        {"turn": 5, "route": "north", "units": ["marine", "marine", U("redcoat_grenadier", lv_min=18)]},
        {"turn": 5, "route": "mid", "units": [U("sailor", tags=["hunter"], lv_min=21)]},
    ],
    "order": {"type": "no_leak", "desc": "密令：没有一个登陆的人摸到我们的营地。"},
    "notes": "通用滩头战：三条登陆线都要先蹚两格浅水（步耗 2，不能站人），上了沙滩才挡得住。E2 是沙丘、B4 也是沙丘（高地），C4 是棕榈林。"
             "G2 海面上一艘炮艇。水兵速 2，蹚水也快；陆战队慢，但人多。第 17 级起每一波多一名陆战队（每 4 级一名）。",
}

TEMPLATES["reef_crossing"] = {
    "name": "退潮礁湖", "date": "", "scale": "skirmish", "size": [8, 4], "level": 17, "base_level": 17, "node": "battle",
    "pad": {"kind": "pirate", "every": 4},
    "turn_limit": 7, "enemy_morale": 10, "weather": "clear",
    "map": [
        "Ea,-*-,G",
        "na,,--*W",
        "Ew,*-,,G",
        "Ea,,,,,G",
    ],
    "routes": {
        "north": "H1>F1>F2>D2>C2>C1>A1",
        "mid": "H3>F3>F2>D2>C2>C3>A3",
        "south": "H4>A4",
    },
    "events": [{"turn": 4, "cell": "E4", "terrain": "shallows"}],
    "waves": [
        {"turn": 1, "route": "south", "units": ["pirate", "pirate", "sailor"]},
        {"turn": 1, "route": "north", "units": ["sailor", "sailor"]},
        {"turn": 2, "route": "mid", "units": ["sailor", U("pirate", tags=["hunter"])]},
        {"turn": 2, "at": "H2", "units": ["gunboat"], "first_fire": 4},
        {"turn": 3, "route": "south", "units": ["pirate_brute", "pirate"]},
        {"turn": 4, "route": "north", "units": ["pirate_captain", "pirate"]},
        {"turn": 5, "route": "mid", "units": ["sailor", "sailor", U("pirate_brute", lv_min=20)]},
        {"turn": 5, "route": "south", "units": [U("pirate", tags=["hunter"], lv_min=21)]},
    ],
    "order": {"type": "hold", "cell": "C2", "turn": 7, "desc": "配给官的命令：第 7 回合结束时，我方有人守在 C2 礁湖口。"},
    "notes": "新厄尔巴的礁湖退潮：E1、D3、G2 是露出的珊瑚礁（挡路），D1、F1、E2、F2、E3 是浅水（步耗 2，不能站）。北路、中路都要绕礁蹚水，最后在 D2、C2 合流；"
             "南滩直接靠岸，最快，第 4 回合涨潮 E4 也没进浅水。A2 是沙丘（高地）。第 21 级起每一波多一名海盗（每 4 级一名）。",
}

TEMPLATES["ice_shelf"] = {
    "name": "南极冰架", "date": "", "scale": "skirmish", "size": [8, 4], "level": 20, "base_level": 20, "node": "battle",
    "pad": {"kind": "sealer", "every": 3},
    "turn_limit": 7, "enemy_morale": 10, "weather": "snow",
    "map": [
        "_s^ii#iG",
        "EiiiiiiG",
        "EiiiiiiG",
        "_^i-iis_",
    ],
    "routes": {
        "top": "H1>G1>G2>A2",
        "mid": "H2>A2",
        "low": "H3>A3",
    },
    "events": [{"turn": 3, "cell": "E1", "terrain": "sea"}, {"turn": 5, "cell": "E4", "terrain": "sea"}],
    "waves": [
        {"turn": 1, "route": "mid", "units": ["sealer", "sealer", "sealer"]},
        {"turn": 1, "route": "low", "units": ["sealer", "harpooner"]},
        {"turn": 2, "route": "top", "units": ["sealer", "sealer"]},
        {"turn": 3, "route": "mid", "units": ["sealer_boss", "sealer"]},
        {"turn": 3, "route": "low", "units": [U("harpooner", tags=["hunter"]), "sealer"]},
        {"turn": 5, "route": "top", "units": ["sealer", U("harpooner", tags=["hunter"], lv_min=21)]},
    ],
    "order": {"type": "hold", "cell": "C3", "turn": 7, "desc": "尼摩的命令：第 7 回合结束时，我方有人守在 C3（舱口前的冰面）。"},
    "notes": "鹦鹉螺号在冰间水道里浮出（左边 A2、A3 是舱口），困在冰里的捕海豹船的人从右边的冰原过来抢船。雪天：我方每回合军令点 −1、军医回复 −1。"
             "C1、B4 是冰塔（高地），F1 是压力冰脊（墙，挡视线），B1、G4 是积雪（步耗 2），D4 是碎冰（能走不能站）。"
             "第 3 回合 E1、第 5 回合 E4 的冰面裂开变成海——站在上面的我方单位退回部署栏（不算倒下）。第 23 级起每一波多一名海豹猎人（每 3 级一名）。",
}

TEMPLATES["nautilus_deck_raid"] = {
    "name": "鹦鹉螺号夜袭", "date": "", "scale": "skirmish", "size": [9, 4], "level": 20, "base_level": 20, "node": "battle",
    "pad": {"kind": "marine", "every": 3},
    "turn_limit": 7, "enemy_morale": 10, "weather": "fog",
    "map": [
        "_WWWWpWpW",
        "EdqdddddG",
        "EddddqddG",
        "_WWWpWWpW",
    ],
    "routes": {
        "plank_f": "F1>F2>D2>D3>A3",
        "plank_h": "H1>H2>D2>D3>A3",
        "bow2": "I2>D2>D3>A3",
        "plank_e": "E4>E3>A3",
        "plank_h4": "H4>H3>G3>G2>D2>D3>A3",
        "bow3": "I3>G3>G2>D2>D3>A3",
    },
    "waves": [
        {"turn": 1, "route": "plank_f", "units": ["marine", "marine"]},
        {"turn": 1, "route": "bow2", "units": ["sailor", "sailor"]},
        {"turn": 2, "at": "I4", "units": ["gunboat"], "first_fire": 4},
        {"turn": 2, "route": "plank_e", "units": ["marine", U("sailor", tags=["hunter"])]},
        {"turn": 3, "route": "plank_h", "units": ["sailor", "sailor", "boatswain"]},
        {"turn": 4, "route": "bow3", "units": ["marine", "marine"]},
        {"turn": 5, "route": "plank_h4", "units": ["sailor", U("marine", tags=["hunter"], lv_min=21), "marine"]},
    ],
    "order": {"type": "no_leak", "desc": "尼摩的命令：没有一个人摸进舱口。"},
    "notes": "海军部的猎潜小艇趁雾靠上浮在水面的鹦鹉螺号：F1、H1、E4、H4 是小艇搭上来的跳板（陆战队从跳板上船），I2、I3 是艇艏。"
             "C2 是探照灯罩、F3 是客厅舷窗的罩子（高地），两格把甲板截成几段：从艇艏和前半截上来的人都要在 D2、D3 拐弯才进得了舱口 A3。"
             "A2 舱口只有从 B2 进。I4 海面上有一艘炮艇。第 23 级起每一波多一名陆战队（每 3 级一名）。",
}

# ---------------------------------------------------------------- nautilus: scene11 elite (ARCH §5: vigo_seabed, void + shallows)
TEMPLATES["vigo_seabed"] = {
    "name": "维哥湾沉船海床", "date": "1831-04-01", "scale": "elite", "size": [10, 5], "level": 22, "node": "elite",
    "turn_limit": 9, "enemy_morale": 16, "weather": "fog",
    "map": [
        "__,,|,,^-G",
        "E,,dddd,,G",
        "E,qdHdd-,_",
        "E,,dddd,,G",
        "__,,|,,^-G",
    ],
    "routes": {
        "line_n": "J1>I1>I2>A2",
        "bell_n": "J2>A2",
        "bell_s": "J4>A4",
        "line_s": "J5>I5>I4>A4",
        "hold_n": "E3>D3>D2>A2",
        "hold_s": "E3>D3>D4>A4",
    },
    "events": [{"turn": 5, "cell": "H2", "terrain": "shallows"}, {"turn": 5, "cell": "H4", "terrain": "shallows"}],
    "waves": [
        {"turn": 1, "route": "bell_n", "units": ["diver", "diver"]},
        {"turn": 1, "route": "bell_s", "units": ["diver", "harpoon_diver"]},
        {"turn": 2, "route": "line_n", "units": ["shark"]},
        {"turn": 2, "route": "line_s", "units": ["shark"]},
        {"turn": 3, "route": "hold_n", "units": ["smith_agent", "diver"]},
        {"turn": 4, "route": "bell_n", "units": ["diver", "diver", "harpoon_diver"]},
        {"turn": 5, "route": "bell_s", "units": ["great_shark", "diver"]},
        {"turn": 6, "route": "line_n", "units": ["diver", U("diver", lv_min=23)]},
        {"turn": 6, "route": "line_s", "units": [U("shark", tags=["hunter"])]},
        {"turn": 7, "route": "hold_s", "units": ["diver", "harpoon_diver", U("great_shark", lv_min=24)]},
        {"turn": 8, "route": "bell_s", "units": ["diver", "diver"]},
    ],
    "order": {"type": "hold", "cell": "D3", "turn": 9, "desc": "潜水长的命令：第 9 回合结束时，我方有人守在 D3（货舱口前那一堆银元）。"},
    "notes": "1702 年沉没的西班牙运宝船躺在维哥湾的淤泥里（凡尔纳原著第二部第八章）。中间 D–G 列是两段船身（甲板 d，能站人），C3 是倒扣的艉楼（高地），E1、E5 是倒在海床上的桅杆（挡视线），H1、H5 是两块礁岩（高地，离敌人入口只隔一格）。"
             "I1、I5、H3 是淤泥（步耗 2，能走不能站）；A1、B1、A5、B5、J3 是海沟（虚空，不属于战场）。英国潜水员顺着潜水钟的缆绳从 J1、J2、J4、J5 下来；第 3、7 回合有人从 E3 货舱口钻出来，先踩 D3 再分上下两路——第 3 回合那个是史密斯（军官、隐身，离我方超过 2 格时只显示“?”）。"
             "第 5 回合英国人的抽沙泵把 H2、H4 冲成淤泥：站在那里的前哨退回部署栏。起雾（浑水）：来敌少公开 1 回合。鲨鱼速 2、猎官，大白鲨穿透。",
}
