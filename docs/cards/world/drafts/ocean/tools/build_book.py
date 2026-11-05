#!/usr/bin/env python3
# Writes wm/ocean/book_ocean.json: everything the napoleon book.json needs for the ocean branch
# (segment entry, branch entry, battle pool, companion rows, soft hooks, segment big fates, debug starts).
# Values come from ocean_uses.py so book, battles and map cannot drift apart.
import json, os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from ocean_uses import SCENE_BATTLES, BATTLE_POOL, CHAPTER_BOSS, MAP_BATTLES
ROOT = os.path.dirname(HERE)
OUT = os.path.join(ROOT, "book_ocean.json")

scene_battles = {k: {kk: vv for kk, vv in v.items()} for k, v in SCENE_BATTLES.items()}

doc = {
    "_doc": "远洋分支要合进 data/campaigns/napoleon/book.json 的部分（ARCH §1.4 形状，A 管结构字段、C 管文字）。等级一律写全局绝对等级 L（13–24）：scene_battles、地图节点和随机槽里的 level 不再加 level_offset；level_offset = 12 只给没有写等级、按 scene_map 的幕换算（2a−1）的场景战斗兜底。",
    "segments": {
        "ocean": {
            "file": "res://data/campaigns/ocean_pawn.json",
            "map": "res://data/campaigns/napoleon/maps/world.json",
            "events": "res://data/campaigns/napoleon/ocean_events.json",
            "kind": "branch", "brand": "远洋", "badge": "nautilus",
            "subtitle": "海底两万里：流亡、圣赫勒拿、新厄尔巴、鹦鹉螺号",
            "gauges": {"treasury": "军费", "morale": "同盟威望", "heat": "敌方警戒", "vitality": "体力与士气", "construction": "岛屿建设", "exploration": "深海探索"},
            "scene_battles": scene_battles,
            "big_fate_extra": [
                {"id": "o_count_ransom", "label": "基督山伯爵出钱赎人", "when": {"alive": ["dantes"], "not_flags": ["o_count_ransom_used"]},
                 "effects": {"heat": 8, "morale": -3}, "rogue": {"coins": {"gold": -2}}, "flags": ["o_count_ransom_used"], "frees_captured": True,
                 "desc": "唐泰斯动用基督山的金子把被俘的人赎回来，全员免于阵亡；金币 −2，警戒 +8，威望 −3。每局只能用一次，唐泰斯要活着。"},
                {"id": "o_crash_dive", "label": "鹦鹉螺号紧急下潜", "when": {"scene_done": "scene10"},
                 "effects": {"exploration": -10, "vitality": -6, "heat": -10}, "frees_captured": False,
                 "desc": "所有人撤回舱里，鹦鹉螺号丢下阵地沉入深海：被俘的人留在敌人手里，警戒 −10，深海探索 −10，体力与士气 −6。第十场以后才有。"},
            ],
            "entry_bonus": [
                {"when": {"flags": ["t_guard_oath"]}, "effects": {"morale": 5}, "why": "枫丹白露立过近卫誓言的人，这一次又跟着皇帝走了"},
                {"when": {"flags": ["faria_half_letter"]}, "items": ["faria_half"], "why": "法利亚的半封信随身带着（book.carry.items 已列）"},
            ],
        }
    },
    "branches": {
        "ocean": {"from": "trunk", "scene": "elba_1815", "level_offset": 12, "entry": "prologue", "requires": {},
                  "label": "以司库身份随驾，管钱袋与船",
                  "offer": "百日王朝里你留在后方管钱袋。滑铁卢之后，你跟着皇帝去罗什福尔、去普利茅斯、去圣赫勒拿——再从那里去海底。",
                  "always_open": True}
    },
    "battle_pool": BATTLE_POOL,
    "chapter_boss_levels": {"ocean": CHAPTER_BOSS},
    "map_battles": MAP_BATTLES,
    "march_cards": {
        "fair_wind": {"mp": 0, "voyage_minus": 1, "segments": ["ocean"], "_note": "ARCH 已有；远洋四张图里航程连线集中在序曲（比斯开 → 托贝湾）和鹦鹉螺号一章"},
        "dive_3": {"mp": 3, "ignore_forced": True, "segments": ["ocean"], "chapters": ["nautilus"], "label": "潜航",
                   "_note": "提议：鹦鹉螺号一章专用，潜在水下走 3 格、不理会强制节点（对手分遣队）。只在 nautilus 一章洗进牌组"}
    },
    "march_deck_extra": {"ocean": {"nautilus": ["dive_3", "dive_3", "fair_wind"], "prologue": ["fair_wind"]}},
    "companions": {
        "_doc": "companions.json 里和远洋段有关的行：segments = 能招募的段；recruit = 拿破仑书里在哪几个地图节点能招（节点写成 章:节点）；battle 数值沿用 ocean_battle.json 的 companions（主干出身的人用主干表）。主干里活着的伙伴原样带进远洋，阵亡的仍是阵亡。",
        "dantes": {"segments": ["ocean", "cristo"], "recruit": {"ocean": {"nodes": ["prologue:rochefort", "st_helena:company_store"], "gold": 2}}, "battle": "ocean_battle.json companions.dantes", "bonds": ["far_sea", "shadow"],
                   "hooks": [{"when": {"flags": ["t_pharaon_known"]}, "trust": 1}, {"when": {"flags": ["t_dantes_letter"]}, "trust": 1}],
                   "note": "远洋分支的前提：百日王朝里你签了释放令，他和法利亚同一天走出伊夫堡（ev_o_malmaison）。伊夫堡分支里他走的是大仲马原著的十四年。"},
        "faria": {"segments": ["ocean", "cristo"], "recruit": {"ocean": {"nodes": ["prologue:rochefort", "st_helena:company_store"], "gold": 2}}, "battle": "ocean_battle.json companions.faria", "bonds": ["scholar", "shadow"],
                  "fated": {"ocean": "scene04"}, "hooks": [{"when": {"flags": ["faria_half_letter"]}, "trust": 1}]},
        "gourgaud": {"segments": ["trunk", "ocean"], "recruit": {"ocean": {"nodes": ["prologue:fouras"], "gold": 2}}, "battle": "ocean_battle.json companions.gourgaud", "bonds": ["imperial", "island"],
                     "note": "主干 1812 年起跟随；史实上他是随皇帝去圣赫勒拿的四人之一。"},
        "marie": {"segments": ["trunk", "ocean"], "recruit": {"ocean": {"nodes": ["st_helena:company_store"], "gold": 2}}, "battle": "ocean_battle.json companions.marie", "bonds": ["shadow", "imperial"],
                  "note": "玛丽·朗热：主干的随军女商贩兼军医，远洋第一部在朗伍德做洗衣妇。ocean_rogue_data.gd 里的名字“玛丽·瓦伦丁”改成“玛丽·朗热”。"},
        "corso": {"segments": ["trunk", "ocean"], "recruit": {"ocean": {"nodes": ["new_elba:friday_village"], "gold": 2}}, "battle": "ocean_battle.json companions.corso", "bonds": ["imperial", "scholar"],
                  "note": "科西嘉水手、神枪手；第七至九场他是毒蛇号的人质。阵亡以后剧情里仍写“科尔索”是已知矛盾，见 OCEAN_REDESIGN.md §9。"},
        "baptiste": {"segments": ["trunk", "ocean"], "recruit": {"ocean": {"nodes": ["new_elba:water_forge"], "gold": 2}}, "battle": "主干表（工兵）", "bonds": ["imperial", "scholar"]},
        "friday": {"segments": ["ocean"], "recruit": {"ocean": {"nodes": ["new_elba:friday_village"], "gold": 2}}, "battle": "ocean_battle.json companions.friday", "bonds": ["island", "far_sea"], "fated": {"ocean": "scene09"}},
        "nemo": {"segments": ["ocean"], "recruit": {"ocean": {"nodes": ["nautilus:new_elba_port", "nautilus:rio"], "gold": 3}}, "battle": "ocean_battle.json companions.nemo", "bonds": ["far_sea", "scholar"], "fated": {"ocean": "scene12"},
                 "hooks": [{"when": {"flags": ["t_mysore_envoy"]}, "gold": -1, "trust": 1, "why": "开罗那个挂虎纹短刀的少年（ARCH §1.2）"}]},
        "morel": {"segments": ["ocean", "cristo"], "recruit": {"ocean": {"nodes": ["st_helena:company_store", "nautilus:rio"], "gold": 2}}, "battle": "ocean_battle.json companions.morel", "bonds": ["far_sea", "imperial"],
                  "hooks": [{"when": {"flags": ["t_pharaon_known"]}, "trust": 1}]},
    },
    "debug_carry": {
        "ocean": {"from": "branch_point"},
        "ocean_stages": {
            "_doc": "game.new {campaign: napoleon, segment: ocean, stage: n} 在 branch_point 标准携带上再加这些（按 ARCH §3.6 参考名册的进度：部队 min(8, 4+L/4)，伙伴数 = 当时的名额）。",
            "1": {"chapter": "st_helena", "companions": {"dantes": 1, "faria": 1, "gourgaud": 1, "marie": 1}, "troops": ["line", "line", "grenadier", "jager", "hussar", "artillery", "line"], "coins": {"gold": 4, "supply": 6, "medal": 4, "intel": 2}},
            "2": {"chapter": "new_elba", "companions": {"dantes": 2, "faria": 1, "gourgaud": 2, "marie": 1, "corso": 1, "friday": 1}, "troops": ["line", "line", "grenadier", "grenadier", "jager", "hussar", "artillery", "artillery"], "coins": {"gold": 5, "supply": 6, "medal": 6, "intel": 3}},
            "3": {"chapter": "nautilus", "companions": {"dantes": 3, "faria": 2, "gourgaud": 2, "marie": 2, "corso": 2, "friday": 2, "nemo": 1, "morel": 1}, "troops": ["line", "line", "grenadier", "grenadier", "jager", "jager", "hussar", "artillery"], "coins": {"gold": 6, "supply": 8, "medal": 8, "intel": 4}},
        },
    },
    "carry_notes": [
        "军费换算：主干是法郎，远洋序曲是先令。按 ARCH §1.6 的“军费结余折成经费”，结余先按 ocean_battle.json 的 franc_rate.shilling = 4/5 换成先令，再乘 treasury_bonus 1/4，加到序曲的 treasury_start 6000 上。",
        "物品：elba_watch（主干最后一场给）和 faria_half（主干第一幕可得）都在 book.carry.items 里；远洋序曲的 secure_passage / buy_passage 本来就会把 elba_watch 写进物品栏，重复写入不出错（_choose 对 items 是去重的，A 要确认）。",
        "伙伴：主干活着的伙伴原样带进远洋。远洋的单段书（ocean_pawn）仍按 ocean_rogue_data.gd 的 starter 开局（唐泰斯、古尔戈、法利亚），这本书里改由地图招募。",
    ],
    "meta": {"branch_badge": "鹦鹉螺", "endings": ["alliance", "ghost", "dark", "tragedy", "bittersweet"],
             "chapter_drawer": [{"label": "远洋 · 序曲 · 贝勒罗丰号的双面怀表（1815）", "segment": "ocean", "stage": 0, "unlock": "打出远洋任一结局"}]},
}

with open(OUT, "w", encoding="utf-8") as f:
    json.dump(doc, f, ensure_ascii=False, indent=1)
print("wrote", OUT)
