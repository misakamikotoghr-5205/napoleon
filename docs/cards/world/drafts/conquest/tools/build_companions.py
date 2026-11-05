#!/usr/bin/env python3
"""Writes data/campaigns/napoleon/companions_conquest.json (trunk + 鹰飞 rows of the book-wide companion table,
ARCH §1.9) and the proposed bond_sets.napoleon for battle_templates.json.
Shared ids (dantes, faria, gourgaud, marie, corso) copy their battle block from data/campaigns/ocean_battle.json
verbatim, so the ocean segment keeps its numbers; only their bond tags are merged (see CONQUEST.md §6).
Run:  python3 -I tools/build_companions.py"""
import json, os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OCEAN = json.load(open("/home/user/dehoudang/data/campaigns/ocean_battle.json", encoding="utf-8"))["companions"]
OUT = os.path.join(ROOT, "data", "campaigns", "napoleon", "companions_conquest.json")

def bat(cls, hp, atk, df, block, cost, skill, title, role, fated=None):
    b = {"cls": cls, "hp": hp, "atk": atk, "def": df, "block": block, "cost": cost, "skill": skill, "skill_title": title,
         "fated_scene": "", "role": role}
    if fated:
        b["fated"] = fated
    return b

def ocean(cid, **kw):
    b = dict(OCEAN[cid])
    b.update(kw)
    return b

C = {
    "baptiste": {"name": "巴蒂斯特中士", "short": "巴蒂斯特", "segments": ["trunk", "conquest", "ocean", "cristo"],
                 "recruit": {"scene": "toulon_arrival"}, "bonds": ["italy", "quartermaster"],
                 "battle": bat("engineer", 14, 3, 2, 1, 3, "fortify", "筑垒（相邻一格放拒马，或把平地筑成胸墙）", "工兵 · 土伦起的老搭档"),
                 "keep": "留守：兵站不会被对手分遣队烧掉。", "relic": "巴蒂斯特的工兵斧（阵亡后：拒马兵力 +4）",
                 "personal": ["ib_baptiste_marie"]},
    "corso": {"name": "科尔索", "short": "科尔索", "segments": ["trunk", "conquest", "ocean", "cristo"], "shared_with_ocean": True,
              "recruit": {"scene": "toulon_arrival"}, "bonds": ["italy", "quartermaster", "imperial"],
              "battle": ocean("corso"), "keep": "留守：走私，每章金币 +1、民愤 +1。", "relic": "科西嘉的老枪（阵亡后：猎兵射程 +1）"},
    "marie": {"name": "玛丽·朗热", "short": "玛丽", "segments": ["trunk", "conquest", "ocean", "cristo"], "shared_with_ocean": True,
              "recruit": {"scene": "italy_nice"}, "bonds": ["quartermaster", "family", "shadow"],
              "battle": ocean("marie"), "keep": "留守：每场战斗 +30 法郎。", "relic": "玛丽的酒桶车铃铛（阵亡后：营地休整多回 5 体力）",
              "personal": ["ev_marie_cantine", "ib_baptiste_marie"],
              "note": "远洋段里她是朗伍德的洗衣妇“玛丽·朗热夫人”：同一个人，1815 年以后跟去了圣赫勒拿。"},
    "muiron": {"name": "米隆", "short": "米隆", "segments": ["trunk"], "recruit": {"scene": "italy_nice"}, "bonds": ["italy", "staff"],
               "battle": bat("line", 16, 5, 1, 2, 5, "raise_flag", "举旗（本行友军攻 +2，2 回合）", "战列步兵 · 波拿巴的副官",
                             fated={"templates": ["arcole_dikes"], "coins": -2}),
               "keep": "留守：行军手牌上限 +1。", "relic": "米隆的肩章（阵亡后：主角命悬一线 +1 枚）", "personal": ["ev_muiron_letter"],
               "pair": "替你挡枪"},
    "lannes": {"name": "拉纳", "short": "拉纳", "segments": ["trunk", "conquest"], "recruit": {"scene": "italy_milan", "choice": "pay_soldiers_first"},
               "bonds": ["italy", "marshal"],
               "battle": bat("grenadier", 20, 5, 3, 3, 6, "bayonet_charge", "刺刀冲锋（挡住的敌人各受 5 伤并被击退）", "掷弹兵 · 勇将",
                             fated={"templates": ["aspern"], "coins": -2}),
               "keep": "留守：征兵减 1 金。", "relic": "拉纳被打穿的帽子（阵亡后：掷弹兵阻挡 +1）",
               "note": "史实里拉纳 1809 年死于阿斯佩恩。活着打完阿斯佩恩就算改写宿命：架空度 +1，勋章 +3。"},
    "murat": {"name": "缪拉", "short": "缪拉", "segments": ["trunk"], "recruit": {"scene": "italy_milan", "choice": "pocket_the_floor"},
              "bonds": ["marshal", "italy"],
              "battle": bat("hussar", 12, 6, 1, 1, 4, "bayonet_charge", "骑兵冲锋（刺刀冲锋：挡住的敌人各受 5 伤并被击退）", "骠骑兵 · 骑兵统领"),
              "risk": {"leaves_at_chapter": "collapse", "unless": {"trust_hero": [">=", 3]}, "text": "1814 年回那不勒斯，倒向联军。"},
              "keep": "留守：每章金币 +1。", "relic": "缪拉的金鼻烟壶"},
    "desaix": {"name": "德塞", "short": "德塞", "segments": ["trunk"], "recruit": {"shop": "orient_alps", "gold": 3, "requires": {"flags": ["t_alps"]}},
               "bonds": ["marshal"],
               "battle": bat("line", 16, 5, 2, 2, 5, "raise_flag", "号令（举旗：本行友军攻 +2，2 回合）", "战列步兵 · 正直的将军",
                             fated={"scenes": ["alps_marengo"], "coins": -2}),
               "keep": "留守：民愤每章 −3。", "relic": "德塞的怀表",
               "note": "沃盖拉军议选“替德塞备好回程的马”会写 t_desaix_close：他能在马伦哥上场。活过马伦哥 = 改写宿命，转为常驻。"},
    "larrey": {"name": "拉雷", "short": "拉雷", "segments": ["trunk", "conquest"], "recruit": {"scene": "orient_acre", "choice": "sort_the_sick"},
               "bonds": ["guard", "family"],
               "battle": bat("medic", 10, 0, 1, 0, 3, "", "（被动）他在场时，所有伙伴的命悬一线 +1 枚", "军医 · 飞行救护车"),
               "keep": "留守：每章治好一道伤痕。", "relic": "拉雷的锯子"},
    "rustam": {"name": "鲁斯塔姆", "short": "鲁斯塔姆", "segments": ["trunk"], "recruit": {"shop": "orient_alps", "gold": 2, "requires": {"flags": ["t_orient"]}},
               "bonds": ["guard", "staff"],
               "battle": bat("hussar", 11, 5, 1, 1, 3, "", "（被动）与主角相邻时，猎官的攻击先打他", "骠骑兵 · 马穆鲁克护卫"),
               "risk": {"leaves_at_chapter": "elba", "text": "1814 年没跟去厄尔巴。"}, "keep": "留守：主角命悬一线 +1 枚。", "relic": "马穆鲁克弯刀"},
    "eble": {"name": "埃布莱", "short": "埃布莱", "segments": ["trunk", "conquest"], "recruit": {"scene": "russia_niemen"},
             "bonds": ["scholar"],
             "battle": bat("engineer", 14, 3, 2, 1, 4, "fortify", "舟桥（筑垒：放拒马或筑胸墙）", "工兵 · 舟桥兵将军",
                           fated={"scenes": ["russia_berezina"], "coins": -2}),
             "keep": "留守：航程与渡河的连线少用 1 天。", "relic": "埃布莱的锚号本子（鹰飞第五章用得上）",
             "note": "史实里埃布莱 1812 年 12 月死于柯尼斯堡。活过别列津纳就算改写宿命。"},
    "gourgaud": {"name": "古尔戈", "short": "古尔戈", "segments": ["trunk", "conquest", "ocean"], "shared_with_ocean": True,
                 "recruit": {"scene": "russia_niemen"}, "bonds": ["staff", "imperial", "island"],
                 "battle": ocean("gourgaud"), "keep": "留守：来敌提前 1 回合公开。", "relic": "古尔戈的望远镜"},
    "pierre": {"name": "小皮埃尔", "short": "皮埃尔", "segments": ["trunk", "conquest", "ocean"], "recruit": {"scene": "russia_berezina"},
               "bonds": ["quartermaster", "family"],
               "battle": bat("drummer", 8, 1, 0, 1, 3, "raise_flag", "鼓点（举旗：本行友军攻 +2，2 回合）", "鼓手 · 别列津纳的孩子"),
               "deploy": {"from_chapter": {"conquest": "last_coalition", "ocean": "nautilus"}, "text": "太小了。1819 年以前只能留守。"},
               "keep": "留守：守营，民愤每章 −2。", "relic": "皮埃尔的鼓"},
    "drouot": {"name": "德鲁奥将军", "short": "德鲁奥", "segments": ["trunk", "conquest"], "recruit": {"scene": "k_golfe_juan"},
               "bonds": ["guard", "scholar"],
               "battle": bat("artillery", 9, 7, 1, 0, 7, "mark_target", "近卫炮兵直瞄（点名：射程内一个敌人 8 伤）", "炮兵 · 大军团的贤者"),
               "keep": "留守：炮兵招募减 1 金。", "relic": "德鲁奥的《圣经》"},
    "cambronne": {"name": "康布罗纳将军", "short": "康布罗纳", "segments": ["trunk", "conquest"], "recruit": {"scene": "k_golfe_juan"},
                  "bonds": ["guard"],
                  "battle": bat("grenadier", 22, 5, 3, 3, 6, "bayonet_charge", "最后的方阵（刺刀冲锋：挡住的敌人各受 5 伤并被击退）", "掷弹兵 · 老近卫军",
                                fated={"templates": ["waterloo"], "coins": -2}),
                  "keep": "留守：士气每章 +3。", "relic": "康布罗纳的军刀"},
    "ney": {"name": "内伊元帅", "short": "内伊", "segments": ["conquest"], "recruit": {"event": "ev_ney_auxerre"}, "bonds": ["marshal"],
            "battle": bat("hussar", 13, 6, 1, 1, 4, "bayonet_charge", "勇士中的勇士（刺刀冲锋：挡住的敌人各受 5 伤并被击退）", "骠骑兵 · 元帅"),
            "risk": {"reckless": True, "text": "上场时攻 +1，可他倒下的命悬一线 −1 枚：他不肯退。"},
            "keep": "留守：无（他不肯留在后方，留守时士气 −2）。", "relic": "内伊的红头发……一缕"},
    "dantes": {"name": "埃德蒙·唐泰斯", "short": "唐泰斯", "segments": ["conquest", "ocean", "cristo"], "shared_with_ocean": True,
               "recruit": {"event": "ev_morrel_petition", "choice": ["free_34", "free_34_and_27"]}, "bonds": ["far_sea", "shadow"],
               "battle": ocean("dantes"), "keep": "留守：每章金币 +1（法老号跑船）。", "relic": "法老号的号旗"},
    "faria": {"name": "法利亚神甫", "short": "法利亚", "segments": ["conquest", "ocean", "cristo"], "shared_with_ocean": True,
              "recruit": {"event": "ev_morrel_petition", "choice": ["free_34_and_27"]}, "bonds": ["scholar", "shadow"],
              "battle": ocean("faria"), "keep": "留守：每章情报 +1。", "relic": "法利亚的另一半信"},
}

PAIRS = [
    {"id": "old_friends", "name": "老相识", "a": "baptiste", "b": "marie",
     "tiers": {"1": "巴蒂斯特筑的拒马和胸墙旁边，友军每回合回 2。", "2": "一方倒下，另一方攻 +3 直到战斗结束，但不能撤退。",
               "3": "解锁“莱比锡之后两人成婚”（ib_baptiste_marie 第二段）；两人同场时各自命悬一线 +1 枚。"}},
    {"id": "shield", "name": "替你挡枪", "a": "muiron", "b": "hero", "adjacent": True,
     "tiers": {"1": "猎官对主角的攻击转给米隆。", "2": "主角第一次倒下时，改为米隆替他倒下，米隆的命悬一线 −1 枚。"}},
    {"id": "rivals", "name": "老对头", "a": "lannes", "b": "murat", "discord": True,
     "tiers": {"1": "两人同场时都攻 +2；相邻时每回合军心 −1。"}},
    {"id": "last_square", "name": "最后的方阵", "a": "cambronne", "b": "ney",
     "tiers": {"1": "两人同场：主角军心第一次掉到 3 以下时，军心回到 5。", "2": "宿命之地（滑铁卢）对两人不再减铜钱。"}},
    {"id": "two_numbers", "name": "34 号和 27 号", "a": "dantes", "b": "faria",
     "tiers": {"1": "两人同场：法利亚的筑垒每次多放一格。", "2": "唐泰斯的冲锋打死敌人时，返还 1 军令点。",
               "3": "解锁“斯帕达的另一半信”（伊夫堡段的宝藏线在鹰飞里的回声）。"}},
]

BOND_SET = ["artillery_school", "square", "cavalry_reserve",
    {"id": "army_of_italy", "name": "意大利军团", "kind": "faction", "tag": "italy", "tiers": [2, 3, 4], "effect": "army_of_italy",
     "desc": "1796 年就在意大利的人（主角也算）。2：开场军令点 +2；3：每回合军令点 +1；4：军心上限 +2，每击溃一个纵队全体充能 +1。老兵一个个凋零，越往后越难凑齐。"},
    {"id": "quartermasters_men", "name": "军需官的人", "kind": "faction", "tag": "quartermaster", "hero": True, "tiers": [2, 3], "effect": "quartermasters_men",
     "desc": "主角必须在场。主角 +1 人：战后法郎 +20%；主角 +2 人：本场第一个倒下的伙伴视为已被抬下。"},
    {"id": "camp_family", "name": "随军家眷", "kind": "faction", "tag": "family", "tiers": [2], "effect": "camp_family",
     "desc": "2：所有伙伴的命悬一线 +1 枚；成员周围 2 格内的单位每回合回 1 兵力。"},
    {"id": "old_guard", "name": "老近卫军", "kind": "faction", "tag": "guard", "tiers": [2, 3], "effect": "workshop",
     "desc": "“老家伙们”。2：成员技能每回合多充能 1；3：获胜勋章 +1。"},
    {"id": "marshalate", "name": "将星", "kind": "faction", "tag": "marshal", "tiers": [2, 3], "effect": "spoils",
     "desc": "元帅和名将都会算自己的账。2：战后法郎 +20%；3：战后再 +1 金币。"},
    {"id": "staff", "name": "参谋部", "kind": "faction", "tag": "staff", "tiers": [2, 3], "effect": "intel",
     "desc": "传令官和副官。2：军令手牌补到 4 张；3：来敌提前 3 回合公开。"},
    {"id": "imperial", "name": "帝国旧部", "kind": "faction", "tag": "imperial", "tiers": [2, 3, 4], "effect": "army_of_italy", "from": "ocean",
     "desc": "远洋段原样（主角也算）。与意大利军团同一效果，同时生效时取高档。"},
    {"id": "far_sea", "name": "远洋同盟", "kind": "faction", "tag": "far_sea", "tiers": [2, 3], "effect": "spoils", "from": "ocean", "desc": "远洋段原样。"},
    {"id": "shadow", "name": "暗影密使", "kind": "faction", "tag": "shadow", "tiers": [2, 3], "effect": "intel", "from": "ocean", "desc": "远洋段原样。"},
    {"id": "scholar", "name": "博学工坊", "kind": "faction", "tag": "scholar", "tiers": [2, 3], "effect": "workshop", "from": "ocean", "desc": "远洋段原样。"},
    {"id": "island", "name": "荒岛求生", "kind": "faction", "tag": "island", "tiers": [2], "effect": "camp_family", "from": "ocean", "desc": "远洋段原样。"},
]

def main():
    d = {"version": 1,
         "_doc": "草稿（标签 conquest）：全书伙伴总表里主干与鹰飞的那些行（ARCH §1.9 的 companions.json，远洋另外 3 人 friday/nemo/morel 由远洋包补）。battle 块形状同 ocean_battle.json.companions，另加 fated（宿命之地：模板或场景，命悬一线减铜钱）。五个跨段的人（dantes/faria/gourgaud/marie/corso）的 battle 块逐字照抄 ocean_battle.json，不改远洋数值；只合并了阵营标签（最多 3 个）。hero 是主角的标签。pairs 是名羁绊（成对，信赖 1–3），内核现在还没有，先当数据写着。",
         "hero": {"bonds": ["italy", "quartermaster", "imperial"]},
         "companions": C, "pairs": PAIRS,
         "bond_set_napoleon": BOND_SET}
    with open(OUT, "w", encoding="utf-8") as f:
        json.dump(d, f, ensure_ascii=False, indent=1)
        f.write("\n")
    print("companions:", len(C))

if __name__ == "__main__":
    main()
