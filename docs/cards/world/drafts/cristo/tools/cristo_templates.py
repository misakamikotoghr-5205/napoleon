# Cristo-branch battle templates: battle_templates.json shape + ARCH §3/§4 extensions
# (size, level / base_level + pad, weather, new terrain chars, spawns, on_kill events, lv_min) + this draft's
# objective types (order.type escape / extract / protect, each with an order_fallback in an existing type).
# Routes are waypoint chains ("I2>B2>B3>A3"); build_battles.py expands them.  Columns A.. from the left (our eagle side).
U = lambda kind, **kw: dict({"kind": kind}, **kw)
T = {}

# ================================================================ chapter 1 · Marseille 1815
T["catalans_cove"] = {
    "name": "加泰罗尼亚人的海湾", "date": "1815-06-24", "scale": "elite", "size": [9, 5], "level": 13, "node": "elite",
    "turn_limit": 9, "enemy_morale": 13, "weather": "night",
    "map": [
        "GBRB^w^.G",
        "SSSSSSSSG",
        "^,v,,;,,G",
        "WW-EE-,WW",
        "WWWWWWWWW",
    ],
    "routes": {
        "village": "A1>A2>C2>C3>D3>D4",
        "road": "I2>E2>E3>E4",
        "cliff": "I1>H1>H2>E2>E3>E4",
        "beach": "I3>G3>G4>F4>E4",
    },
    "waves": [
        {"turn": 1, "route": "road", "units": ["customs", "verdet", "verdet"]},
        {"turn": 1, "route": "village", "units": ["verdet", "verdet", "verdet"]},
        {"turn": 2, "at": "H5", "units": ["revenue_cutter"], "first_fire": 4},
        {"turn": 2, "route": "beach", "units": ["customs", "verdet"]},
        {"turn": 2, "route": "village", "units": ["verdet", "gendarme"]},
        {"turn": 3, "route": "road", "units": ["mounted_gendarme", "customs"]},
        {"turn": 3, "route": "village", "units": ["gendarme", "verdet"]},
        {"turn": 4, "route": "cliff", "units": ["customs", "verdet"], "alt": [["customs", "customs"]]},
        {"turn": 5, "route": "road", "units": ["customs_officer", "verdet"]},
        {"turn": 5, "route": "beach", "units": ["verdet", U("customs", lv_min=14)]},
        {"turn": 6, "route": "village", "units": ["verdet", "gendarme", U("mounted_gendarme", lv_min=15)]},
    ],
    "order": {"type": "extract", "cell": "E3", "turns": 4,
              "desc": "百日的军费：四箱金币要从 E3 的沙滩搬上 E4 的渔船。有 4 个回合结束时我方有人站在 E3（每满一回合上船一箱）。"},
    "order_fallback": {"type": "hold", "cell": "E3", "turn": 9, "desc": "（内核没有 extract 时）第 9 回合结束时，我方有人守在 E3。"},
    "notes": "1815 年 6 月 24 日夜里，滑铁卢的消息到了，加泰罗尼亚人村下面的小海湾。百日期间存在马赛的军费要赶在保王党动手以前运走，两条渔船等在湾里（D4、E4 是鹰旗：船被缴就完了），"
             "两头同时有人来：宪兵从村子那头下来（A1 教堂后的小路，经 A2–C2 石板巷、C3 晾网棚、D3 沙滩到 D4），"
             "海关从马赛那头来（I2 大路、I1 崖上小路在 H2 并进来，都经 E2、E3 到 E4；I3 沿沙滩经 G4 蹚 F4 浅水到 E4）。"
             "B1、D1 是渔民的石屋（我方可以进驻，防 +2，挡视线，敌人不进屋），C1 是屋顶（只有猎兵能上，射程 +1），E1、G1、A3 是礁石（高地），F1 是松林。"
             "C3 晾网棚是村庄（双方防 +2），F3 是礁石滩（瓦砾：步耗 2，防 +1），C4、F4 是浅水（能走不能站）。"
             "H5 海面上第 2 回合来一条缉私快艇（第 4 回合起每 2 回合一炮，只打与它列差 ≤4 的格子，也就是 D–I 列）。夜里我方小火器射程 −1。"
             "左右两头要分兵：村子那头的路短、人少，海关那头三条路都压到 E3。",
}

T["marseille_arrest"] = {
    "name": "旧港·六月的白帽徽", "date": "1815-06-25", "scale": "grand", "size": [10, 6], "level": 14, "node": "boss",
    "turn_limit": 13, "enemy_morale": 24, "weather": "clear",
    "map": [
        "WkBRBB^RBG",
        "EkSSSSSSSS",
        "WkB.v.BRSB",
        "EkSSSSSSSS",
        "WkBB^BRBSG",
        "WWWWWW#W^_",
    ],
    "spawns": ["E3"],
    "routes": {
        "loge": "J1>J2>B2>A2",
        "cross_dn": "J1>J2>I2>I4>B4>A4",
        "quay": "J5>I5>I4>B4>A4",
        "cross_up": "J5>I5>I4>I2>B2>A2",
        "church_n": "E3>E2>B2>A2",
        "church_s": "E3>E4>B4>A4",
    },
    "waves": [
        {"turn": 1, "route": "loge", "units": ["verdet", "verdet", "royalist_marksman"]},
        {"turn": 1, "route": "quay", "units": ["national_guard", "national_guard"]},
        {"turn": 2, "at": "I6", "units": ["fort_gun"], "first_fire": 4},
        {"turn": 3, "route": "church_n", "units": [U("verdet", tags=["ambush"]), U("verdet", tags=["ambush"]), U("royalist_marksman", tags=["ambush"])]},
        {"turn": 3, "route": "cross_up", "units": ["mounted_gendarme"]},
        {"turn": 4, "route": "loge", "units": ["ng_grenadier", "verdet", "verdet"], "alt": [["ng_grenadier", "verdet", "royalist_marksman"]]},
        {"turn": 5, "route": "quay", "units": ["royalist_chief", "national_guard", "national_guard", "royalist_marksman", "royalist_marksman"]},
        {"turn": 6, "route": "church_s", "units": [U("royalist_bravo", tags=["ambush", "hunter"]), U("verdet", tags=["ambush"])]},
        {"turn": 7, "route": "cross_dn", "units": ["mounted_gendarme", "ng_grenadier"]},
        {"turn": 8, "route": "loge", "units": ["royalist_chief", "ng_grenadier", "verdet", U("royalist_marksman", lv_min=15)]},
        {"turn": 9, "route": "quay", "units": ["ng_grenadier", "national_guard", "gendarme", "gendarme"]},
        {"turn": 10, "route": "church_n", "units": [U("verdet", tags=["ambush"]), U("royalist_marksman", tags=["ambush"]), U("verdet", tags=["ambush"], lv_min=16)]},
        {"turn": 11, "route": "cross_dn", "units": ["ng_grenadier", "royalist_marksman", "verdet", "verdet"]},
        {"turn": 12, "route": "church_s", "units": [U("royalist_bravo", tags=["ambush"]), U("royalist_bravo", tags=["ambush"]), U("verdet", tags=["ambush"])]},
    ],
    "order": {"type": "protect", "unit": "morel",
              "desc": "莫雷尔先生的请求：他要亲手守自己的货栈。莫雷尔上场，并且打完都没有倒下。"},
    "order_fallback": {"type": "no_leak", "desc": "（内核没有 protect 时）没有一个暴徒走到码头的小船边。"},
    "notes": "1815 年 6 月 25 日，滑铁卢的消息到了马赛，城里的保王党起事（史实：马赛这几天杀了不少波拿巴分子和埃及难民）。"
             "旧港北岸：左边 B 列是码头石阶，A2、A4 是等着把人送去加泰罗尼亚人村的小船（鹰旗）。"
             "两条大街从勒潘尼耶的坡上冲下来：第 2 行洛日街（J1 红门是刀剪街口，绕进 J2），第 4 行港口大道（J5 红门是大街口，经 I5 拐进来）；"
             "I 列的小巷把两条街连起来，所以每一路都能拐到另一条街上。E3 是圣洛朗教堂前的小广场（村庄），第 3、6、10 回合有暴徒从广场上冒出来（伏兵，出生格 E3），"
             "离小船只有 4 步。房屋 B 我方可以进驻（防 +2，挡视线），C3 是莫雷尔父子商行的货栈；屋顶 D1、H1、H3、G5 只有猎兵能上；"
             "G1 教堂台阶、E5 是高地（炮兵、猎兵）。I6 是圣让堡的炮台（第 2 回合起，第 4 回合开第一炮，打离它最近的我方地面单位），G6 是堡墙。"
             "来敌：绿衫志愿兵、保王党枪手（专打主角和伙伴）、倒向国王的国民自卫军和掷弹兵连（重型），两名骑宪兵（猎官、逮捕：主角在他们刀下倒下就直接被捕），第 6 回合广场上冒出一个盯着“另一个埃德蒙”的保王党刺客（猎官）。",
}

# ================================================================ chapter 2 · the If years
T["morgiou_cove"] = {
    "name": "莫尔吉乌的走私湾", "date": "1822-08-14", "scale": "elite", "size": [9, 5], "level": 15, "node": "elite",
    "turn_limit": 9, "enemy_morale": 14, "weather": "night",
    "map": [
        "^^#G^^#G_",
        "Ekc,,;,,G",
        "EkWWpWWWW",
        "_kc,,;,.G",
        "__^^#^^^_",
    ],
    "routes": {
        "west_cliff": "D1>D2>B2>A2",
        "east_cliff": "H1>H2>B2>A2",
        "shore": "I2>B2>A2",
        "south": "I4>B4>B3>A3",
        "rival_n": "E3>E2>B2>A2",
        "rival_s": "E3>E4>B4>B3>A3",
    },
    "waves": [
        {"turn": 1, "route": "west_cliff", "units": ["customs", "customs"]},
        {"turn": 1, "route": "shore", "units": ["gendarme", "customs"]},
        {"turn": 2, "at": "H3", "units": ["revenue_cutter"], "first_fire": 4},
        {"turn": 3, "route": "rival_n", "units": [U("smuggler", tags=["boarder"]), U("smuggler", tags=["boarder"])]},
        {"turn": 3, "route": "south", "units": ["customs", "customs"]},
        {"turn": 4, "route": "east_cliff", "units": ["gendarme", U("customs", tags=["hunter"])]},
        {"turn": 5, "route": "west_cliff", "units": ["customs_officer", "customs"]},
        {"turn": 6, "route": "rival_s", "units": [U("rival_smuggler_boss", tags=["boarder"]), U("smuggler", tags=["boarder"])]},
        {"turn": 6, "route": "south", "units": ["gendarme", "customs", U("customs", lv_min=17)]},
        {"turn": 7, "route": "shore", "units": ["customs", U("gendarme", lv_min=16)]},
    ],
    "order": {"type": "hold", "cell": "C2", "turn": 9,
              "desc": "雅科波的话：“货在洞里。”第 9 回合结束时，我方有人守在 C2 的洞口。"},
    "notes": "1822 年夏天，卡西斯路边的莫尔吉乌小湾（马赛南边的一道石灰岩峡湾）。少年阿梅莉号的长艇（A2、A3 是鹰旗）靠在 B 列的小码头上，"
             "货藏在 C2、C4 两个海蚀洞里。海关从三个方向下来：西崖小路（D1，4 步就到船边，最快）、东崖小路（H1）、北岸小路（I2）、南岸小路（I4）。"
             "第 3、6 回合，热那亚对头帮的船靠上峡湾中间 E3 的跳板（接舷：从跳板出发），往两岸冲。"
             "A1、B1、E1、F1 和 C5、D5、F5–H5 是崖顶（高地）；C1、G1、E5 是崖壁（墙，挡视线）。F2、F4 是碎石滩（步耗 2，防 +1）。"
             "海蚀洞：敌炮不瞄准洞里的人，洞里挨远程防 +2，但洞穴挡视线。H3 海面上是海关的缉私快艇（只打与它列差 ≤4 的格子，B 列打不到）。夜里我方小火器射程 −1。"
             "走私贩带“隐身”：离我方单位 2 格以外时只看得见一个问号。",
}

T["if_corridors"] = {
    "name": "伊夫堡的那一夜", "date": "1829-02-28", "scale": "grand", "size": [10, 6], "level": 16, "node": "boss",
    "turn_limit": 13, "enemy_morale": 24, "weather": "night",
    "map": [
        "__^^#^^#__",
        "_kCCCCCCD_",
        "EkL#D#L##_",
        "EkCCCCCCCD",
        "_,;..v..G_",
        "_WWW^^WW__",
    ],
    "routes": {
        "guard": "I2>C2>B2>B3>A3",
        "dungeon": "J4>B4>A4",
        "yard": "I5>C5>B5>B4>A4",
        "stair_up": "E3>E2>B2>B3>A3",
        "stair_dn": "E3>E4>B4>A4",
    },
    "events": [
        {"on_kill": "turnkey_chief", "cell": "E3", "terrain": "wall"},
    ],
    "waves": [
        {"turn": 1, "route": "guard", "units": ["prison_guard", "prison_guard"]},
        {"turn": 1, "route": "dungeon", "units": ["if_soldier", "if_soldier", U("prison_guard", tags=["hunter"])]},
        {"turn": 1, "at": "F1", "units": ["wall_sentry"]},
        {"turn": 2, "route": "stair_up", "units": ["prison_guard", U("prison_guard", tags=["hunter"])]},
        {"turn": 2, "at": "F6", "units": ["fort_gun"], "first_fire": 4},
        {"turn": 3, "route": "guard", "units": ["turnkey_chief", "prison_guard", "if_soldier"]},
        {"turn": 3, "route": "yard", "units": ["if_soldier", "if_veteran"]},
        {"turn": 4, "route": "stair_dn", "units": ["if_veteran", "prison_guard"]},
        {"turn": 5, "route": "dungeon", "units": ["if_soldier", "if_soldier", U("if_veteran", tags=["hunter"])]},
        {"turn": 6, "route": "stair_up", "units": ["if_veteran", "prison_guard", "prison_guard"]},
        {"turn": 6, "at": "D1", "units": [U("wall_sentry", lv_min=17)]},
        {"turn": 7, "route": "yard", "units": ["if_soldier", "if_soldier", "if_veteran"]},
        {"turn": 8, "route": "guard", "units": ["if_soldier", "prison_guard", U("if_soldier", lv_min=18)]},
        {"turn": 9, "route": "stair_dn", "units": ["if_veteran", "prison_guard", U("prison_guard", tags=["hunter"])]},
        {"turn": 10, "route": "dungeon", "units": ["if_soldier", "if_soldier", "if_soldier"]},
    ],
    "order": {"type": "escape", "unit": "dantes", "cells": ["B2", "B3", "B4"], "turn": 13,
              "desc": "法利亚的遗愿：第 13 回合结束时，唐泰斯站在 B 列的海门石阶上（B2、B3、B4 任一格）。"},
    "order_fallback": {"type": "hold", "cell": "B3", "turn": 13, "desc": "（内核没有 escape 时）第 13 回合结束时，我方有人守在 B3 海门。"},
    "notes": "1829 年 2 月的夜里，伊夫堡。法利亚神甫死了（或者，你的药让他撑过了第三次发作），唐泰斯缝进了运尸的麻袋——今夜的运尸工是你的人。"
             "可是警钟还是响了。左边 B 列是通往海门的石阶（码头），A3、A4 是靠在礁石下的小艇（鹰旗）。"
             "三条路从要塞里面压过来：第 2 行是卫兵室走廊（I2 门），第 4 行是地牢走廊（J4 是从下层牢房上来的楼梯门），第 5 行是院子（I5 是要塞正门，C5 是瓦砾，步耗 2）。"
             "E3 是正中间的地牢楼梯门：第 2、4、6、9 回合有人从这里钻出来，往上下两条走廊分头冲（离小艇只有 5–6 步）。"
             "**打死典狱长（第 3 回合从卫兵室出来），就拿到了他的钥匙：E3 那扇门立刻锁死（变成墙），之后从 E3 出发的波次不再出现。**"
             "走廊（C）是暗的：站在走廊里的射手射程 −1；今夜又是夜战，射程再 −1。C3、G3 是牢房（34 号和 27 号）：我方可以进去（防 +1），敌人不走；"
             "牢房夹在两条走廊之间，横队朝上能打卫兵室走廊、朝下能打地牢走廊。D3、F3、H3、I3 和 E1、H1 是墙（挡视线）。"
             "C1、D1、F1、G1 是城墙（高地）：F1 一开场就站着一名墙头哨兵（射程 3，先打主角和伙伴），第 17 级起 D1 也会来一名；打死以后那一格可以换我方的人上去。"
             "E6、F6 是海边礁岩：F6 第 2 回合起是要塞的报警炮（第 4 回合起每 2 回合一炮），E6 留给我方。B5 是石阶下的小滩。"
             "来敌：狱卒、守军、老军士（重型精英）、典狱长；第 1、2、5、9 回合各有一名认得你的人（猎官）。",
}

# ================================================================ generic random encounters (base 12 + pad: L12..23)
T["alley_ambush"] = {
    "name": "小巷伏击", "scale": "skirmish", "size": [8, 4], "base_level": 12, "pad": {"kind": "thug", "every": 5}, "node": "battle",
    "turn_limit": 7, "enemy_morale": 10, "weather": "clear",
    "map": [
        "BRBB#BRB",
        "ESSSSSSG",
        "ESvSSSSG",
        "BBRBB#BB",
    ],
    "spawns": ["E2", "F3"],
    "routes": {
        "upper": "H2>A2",
        "lower": "H3>A3",
        "door_n": "E2>A2",
        "door_s": "F3>A3",
    },
    "waves": [
        {"turn": 1, "route": "upper", "units": ["thug", "thug"]},
        {"turn": 1, "route": "lower", "units": ["thug", "thug_boss"], "alt": [["thug", "thug", "thug"]]},
        {"turn": 1, "at": "G1", "units": ["thug_marksman"]},
        {"turn": 2, "route": "door_n", "units": [U("thug", tags=["ambush"]), U("thug", tags=["ambush", "hunter"])]},
        {"turn": 3, "route": "door_s", "units": [U("thug", tags=["ambush"]), U("thug", tags=["ambush"])]},
        {"turn": 3, "route": "upper", "units": ["gendarme", U("thug", lv_min=17)]},
        {"turn": 4, "route": "lower", "units": ["thug", U("gendarme", lv_min=17), U("thug", tags=["hunter"], lv_min=21)]},
    ],
    "order": {"type": "no_leak", "desc": "没有一个打手摸到马车边（A2、A3）。"},
    "notes": "通用遭遇战（马赛、罗马、巴黎的老城都用它）：一条两边是房子的窄巷，马车（A2、A3 鹰旗）停在巷尾。"
             "上下两条路：第 2 行从 H2 的侧巷口来，第 3 行从 H3 正面来；C3 是小喷泉广场（村庄，双方防 +2）。"
             "第 2、4 回合有人从 E2、F3 的门洞里冲出来（伏兵），离马车只有 3–4 步。G1 窗后有一个黑枪（定点、射程 3、隐身）。"
             "屋顶 B1、G1……C4 只有猎兵能上；E1、F4 是拱门（墙，挡视线）。打手头子打死以后，他那一队后退一格、攻 −1。"
             "补兵：每一波按 (L−12)/5 补码头打手（L17 起每波 +1，L22 起 +2）；L17 起上路多一名宪兵，L21 起第 4 回合多一名猎官。",
}
T["coast_road"] = {
    "name": "海岸小路", "scale": "skirmish", "size": [8, 4], "base_level": 12, "pad": {"kind": "customs", "every": 5}, "node": "battle",
    "turn_limit": 7, "enemy_morale": 10, "weather": "clear",
    "map": [
        "^ww.^wwG",
        "E======G",
        "_,,,_,..",
        "__WpWWW_",
    ],
    "routes": {
        "road": "H2>A2",
        "hill": "H1>G1>G2>A2",
        "cove": "D4>D3>D2>A2",
    },
    "waves": [
        {"turn": 1, "route": "road", "units": ["customs", "customs", "gendarme"]},
        {"turn": 2, "route": "hill", "units": ["mounted_gendarme"]},
        {"turn": 2, "route": "cove", "units": [U("smuggler", tags=["boarder"]), U("smuggler", tags=["boarder"]), U("smuggler", tags=["boarder"])]},
        {"turn": 3, "route": "road", "units": ["customs", "customs_officer"], "alt": [["customs", "gendarme"]]},
        {"turn": 4, "route": "cove", "units": [U("smuggler", tags=["boarder"]), U("smuggler", tags=["boarder"], lv_min=16)]},
        {"turn": 4, "route": "hill", "units": ["gendarme", U("mounted_gendarme", lv_min=21)]},
    ],
    "order": {"type": "hold", "cell": "C2", "turn": 7, "desc": "第 7 回合结束时，我方有人守在 C2 的拐弯（骡队要从这里过）。"},
    "notes": "通用遭遇战（普罗旺斯、托斯卡纳、科西嘉的海岸都用它）：一条贴着悬崖的海岸小路（第 2 行），骡队（A2 鹰旗）在左边。"
             "海关和宪兵从 H2 大路、H1 山上的小路来；走私贩从 D4 的跳板上岸（接舷），经 D3 沙滩爬上大路，离骡队只有 4 步。"
             "A1、E1 是岩石（高地），B1、C1、F1、G1 是灌木林（挨远程防 +2）；E3 是塌掉的路基（虚空：不属于战场，射程跳过），"
             "B3–D3 是下面的小沙滩。骑宪兵是猎官，也会逮捕主角。补兵：每一波按 (L−12)/5 补海关缉私兵（L17 起每波 +1，L22 起 +2）。",
}
