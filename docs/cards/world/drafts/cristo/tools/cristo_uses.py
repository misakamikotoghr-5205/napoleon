# Where each cristo template is used (scene / map node / pool, absolute level L), the reference rosters
# per chapter, and one reference plan per template (fed to battle_sim.py as evidence of solvability).

# companion battle blocks (shared ids copied verbatim from data/campaigns/ocean_battle.json and the conquest draft)
COMP = {
    "dantes": {"skill": "bayonet_charge", "cls": "hussar", "hp": 12, "atk": 6, "def": 1, "block": 1, "cost": 4},
    "faria": {"skill": "fortify", "cls": "engineer", "hp": 14, "atk": 3, "def": 2, "block": 1, "cost": 3},
    "morel": {"skill": "raise_flag", "cls": "line", "hp": 16, "atk": 5, "def": 1, "block": 2, "cost": 5},
    "marie": {"skill": "mark_target", "cls": "medic", "hp": 10, "atk": 0, "def": 1, "block": 0, "cost": 3},
    "corso": {"skill": "mark_target", "cls": "jager", "hp": 8, "atk": 4, "def": 0, "block": 0, "cost": 3},
    "baptiste": {"skill": "fortify", "cls": "engineer", "hp": 14, "atk": 3, "def": 2, "block": 1, "cost": 3},
    # new in cristo
    "caderousse": {"skill": "raise_flag", "cls": "line", "hp": 14, "atk": 4, "def": 1, "block": 2, "cost": 3},
    "jacopo": {"skill": "mark_target", "cls": "artillery", "hp": 10, "atk": 6, "def": 0, "block": 0, "cost": 6},
    "bertuccio": {"skill": "fortify", "cls": "engineer", "hp": 14, "atk": 4, "def": 2, "block": 1, "cost": 3},
    "ali": {"skill": "bayonet_charge", "cls": "grenadier", "hp": 20, "atk": 5, "def": 3, "block": 3, "cost": 6},
    "haydee": {"skill": "raise_flag", "cls": "medic", "hp": 9, "atk": 0, "def": 1, "block": 0, "cost": 3},
    "maximilien": {"skill": "bayonet_charge", "cls": "hussar", "hp": 12, "atk": 6, "def": 1, "block": 1, "cost": 4},
    "vampa": {"skill": "mark_target", "cls": "jager", "hp": 9, "atk": 5, "def": 0, "block": 0, "cost": 4},
}


def troops_for(L):
    n = min(8, 4 + L // 4)
    base = ["line", "line", "grenadier", "jager", "artillery", "line", "hussar", "jager"]
    return base[:n]


def pick(ids):
    return {i: COMP[i] for i in ids}


# reference rosters: which companions the player plausibly has in that chapter (ARCH §3.6 caps decide how many may deploy)
ROSTERS = {
    "ch1": lambda L: (pick(["morel", "caderousse", "baptiste", "corso", "marie"]), troops_for(L)),
    "ch2": lambda L: (pick(["morel", "caderousse", "jacopo", "bertuccio", "marie"]), troops_for(L)),
    "ch2_boss": lambda L: (pick(["dantes", "faria", "jacopo", "bertuccio", "morel", "marie"]), troops_for(L)),
    "generic": lambda L: (pick(["morel", "caderousse"]), troops_for(L)),
}

CHAPTER_BOSS = {"marseille": 14, "if_years": 16, "montecristo": 18, "mediterranean": 21, "paris_1838": 24}

SCENE_BATTLES = {
    "c_white_june": {"template": "marseille_arrest", "level": 14, "order_flag": "m_morrel_kept"},
    "c_morgiou": {"template": "morgiou_cove", "level": 15, "order_flag": "m_cargo_saved"},
    "c_if_night": {"template": "if_corridors", "level": 16, "order_flag": "m_escape_clean"},
}
SCENE_CHAPTER = {"c_white_june": "marseille", "c_morgiou": "if_years", "c_if_night": "if_years"}
MAP_BATTLES = {
    "catalans_cove": {"sheet": "marseille", "node": "m_catalans_cove", "level": 13, "order_flag": "m_gold_landed"},
}
BATTLE_POOL = {"cristo": {"12-17": ["alley_ambush", "coast_road"], "18-23": ["alley_ambush", "coast_road"]}}
# random battle slots and rival meetings per chapter use L = chapter boss - 2 (ARCH 3.1; ch1 floor = trunk's last L12)
GENERIC_LEVELS = {"marseille": 12, "if_years": 14, "montecristo": 16, "mediterranean": 19, "paris_1838": 22}
RIVAL_BATTLES = {"alley_ambush": [{"sheet": "marseille", "rival": "gendarme_patrol", "level": 12}, {"sheet": "paris_1838", "rival": "police_watch", "level": 22}],
                 "coast_road": [{"sheet": "if_years", "rival": "customs_cutter", "level": 14}, {"sheet": "montecristo", "rival": "genoese_rivals", "level": 16}]}


def levels_of(tid):
    out = set()
    for sid, sb in SCENE_BATTLES.items():
        if sb["template"] == tid:
            out.add(sb["level"])
    if tid in MAP_BATTLES:
        out.add(MAP_BATTLES[tid]["level"])
    for band, lst in BATTLE_POOL["cristo"].items():
        if tid in lst:
            lo, hi = [int(x) for x in band.split("-")]
            out |= {L for L in GENERIC_LEVELS.values() if lo <= L <= hi}
    for r in RIVAL_BATTLES.get(tid, []):
        out.add(r["level"])
    return sorted(out)


P = lambda t, u, at, f: {"t": t, "deploy": u, "at": at, "face": f}

# Reference plans (evidence of solvability, fed to battle_sim.py). Fixed deployments first, then "slots": a priority list
# of [cell, facing, [unit ids / classes], from_turn] that a sensible player keeps manned while CP allows.
PLANS = {
    "catalans_cove": {"roster": "ch1", "cp_bonus": 4, "plan": [
        P(1, "caderousse", "C3", "up"), P(1, "morel", "E3", "up"), P(2, "hero", "D1", "down"), P(2, "corso", "C1", "down"),
        P(3, "line_1", "D2", "right"), P(4, "line_6", "D3", "up"), P(5, "jager_4", "E1", "down"),
        {"slots": [["E3", "up", ["grenadier", "line"]], ["C3", "up", ["line", "grenadier"]], ["G1", "down", ["artillery", "jager"]]]}],
        "text": "两头分兵：卡德鲁斯守 C3 晾网棚（村庄防 +2），科尔索上 C1 屋顶朝下打石板巷；莫雷尔守 E3（海关三条路的汇合口，也是搬箱子的格子），"
                "第 2 回合主角进 D1 石屋（不挨任何一条路，猎官够不着），横队进 D2 朝右打 E2–F2，D3 再放一队横队兼当抬人的。"
                "第 5 回合起 E1 上猎兵，G1 上炮朝下：同时打得到沙滩和 H5 的缉私快艇。"},
    "marseille_arrest": {"roster": "ch1", "cp_bonus": 4, "plan": [
        P(1, "hero", "C1", "down"), P(1, "morel", "C3", "up"), P(1, "corso", "D1", "down"),
        {"slots": [["C2", "right", ["caderousse", "grenadier", "line"]], ["E5", "up", ["artillery"]], ["C4", "right", ["line", "grenadier"]], ["D3", "right", ["marie"]],
                   ["B4", "right", ["grenadier", "line"]], ["B2", "right", ["line", "grenadier"]], ["H3", "down", ["jager"]], ["B3", "right", ["baptiste", "line"]],
                   ["G1", "down", ["artillery", "jager"]], ["D4", "right", ["hussar"], 9]]}],
        "text": "莫雷尔守自己的货栈 C3（房屋，防 +2，敌人进不来），朝上打洛日街；玛丽在 D3 广场边给他回血。主角在 C1 石屋里（C2 有人挡着，猎官就停在 D2 够不着他）。"
                "C2、C4 两个街口各一道阻挡，B2、B4 码头再一道。E5 高台上的炮朝上，同时打洛日街和教堂广场冒出来的伏兵；G1 教堂台阶再上一门炮朝下打港口大道。"
                "H3 屋顶的猎兵专打头目。圣让堡的炮只打离它最近的地面单位，所以别让人站在 G4–I4 太久。"},
    "morgiou_cove": {"roster": "ch2", "cp_bonus": 4, "plan": [
        P(1, "caderousse", "C2", "right"), P(1, "hero", "A1", "right"),
        {"slots": [["C2", "right", ["caderousse", "grenadier", "line"]], ["F1", "down", ["jacopo", "artillery"]], ["C4", "right", ["bertuccio", "line", "grenadier"]],
                   ["B2", "right", ["grenadier", "line"]], ["E1", "down", ["jager"]], ["B4", "right", ["line", "grenadier"]], ["B1", "right", ["artillery", "jager"]],
                   ["B3", "right", ["marie", "line"]]]}],
        "text": "两个海蚀洞是天然的堡垒：C2、C4 各放一道阻挡（洞里挨远程防 +2，缉私快艇也不瞄洞里的人）。雅科波的回旋炮上 F1 崖顶朝下，"
                "一炮同时罩住 E3 跳板（对头帮上岸的地方）和南岸；E1 再放猎兵朝下打跳板。主角在 A1 崖角（谁的路都不挨着）。"
                "西崖小路最短（4 步），第一回合就要有人在 C2。"},
    "if_corridors": {"roster": "ch2_boss", "cp_bonus": 4, "plan": [
        P(1, "hero", "C1", "down"),
        {"slots": [["C2", "right", ["morel", "grenadier", "line"]], ["C4", "right", ["grenadier", "line"]], ["D1", "down", ["jacopo", "artillery"]],
                   ["C5", "right", ["bertuccio", "faria", "line"]], ["E6", "up", ["artillery"]], ["B3", "right", ["marie"]], ["G3", "down", ["line"]],
                   ["B4", "right", ["line", "grenadier"]], ["B2", "right", ["dantes"], 9], ["G1", "down", ["jager"]]]}],
        "text": "两条走廊在 C 列各放一道阻挡（C2、C4），院子那一路在 C5 瓦砾上挡（贝尔图乔的筑垒顺手在 B5、D5 放拒马）。"
                "D1 城墙上的炮朝下，正好罩住 E3 地牢门和两条走廊；E6 礁岩上再一门朝上。G3 是 27 号牢房：横队进去朝下打地牢走廊和院子。"
                "主角在 C1 城墙上：C2 守住，猎官就停在 D2 打不着他。唐泰斯留到最后几回合再上 B2 海门（骠骑兵一上场就冲锋），撑到第 13 回合结束就完成法利亚的遗愿。"
                "更好的打法是第 4–6 回合集中火力打死典狱长：E3 的门一锁，第 6、9 回合那两波就不会来了。"},
    "alley_ambush": {"roster": "generic", "cp_bonus": 2, "plan": [
        P(1, "morel", "B3", "right"), P(1, "caderousse", "B2", "right"), P(2, "hero", "B4", "up"),
        {"slots": [["C4", "up", ["jager"]], ["C1", "down", ["line"]], ["D4", "up", ["line"]], ["B2", "right", ["grenadier", "line"]], ["B3", "right", ["line", "grenadier"]]]}],
        "text": "巷尾 B2、B3 各一道阻挡；房子 C1、D4 里各放一队横队（C1 朝下、D4 朝上都能同时打两条巷子），C4 屋顶上猎兵朝上。主角进 B4 房子（猎官打不进屋，只会被黑枪惦记）。"},
    "coast_road": {"roster": "generic", "cp_bonus": 2, "plan": [
        P(1, "hero", "A1", "right"),
        {"slots": [["C2", "right", ["morel", "grenadier", "line"]], ["B2", "right", ["caderousse", "line", "grenadier"]], ["C1", "down", ["line"]], ["B1", "down", ["line"]],
                   ["D3", "up", ["line", "grenadier"]], ["E1", "down", ["jager", "artillery"]], ["F1", "down", ["line"]]]}],
        "text": "三条路最后都并到海岸路上：C2 拐弯和 B2 各一道阻挡，D3 小沙滩再挡一道（走私贩从这里爬上来）。灌木林 B1、C1、F1 里的横队朝下打路面（林子里挨远程防 +2），"
                "E1 岩石上放猎兵或炮。主角在 A1 岩石上。"},
}
