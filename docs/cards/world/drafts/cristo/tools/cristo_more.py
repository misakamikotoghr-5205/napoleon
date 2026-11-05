# -*- coding: utf-8 -*-
# More cristo content: councils for chapters 3-5, chapter interludes, companions, pairs, bond factions.
from cristo_story import E, EC

COUNCILS = [
    E("ev_c3_council", "fixed", "少年阿梅莉号的甲板", "皮亚诺萨岛外·少年阿梅莉号", "jacopo", [
        "1829 年 5 月 22 日。基督山岛就在前面，光秃秃的一块石头，只有野山羊。",
        "雅科波：“船老大说要在岛上停两天修船。热那亚帮的船昨天在卡普拉亚露过面。”",
        "唐泰斯：“我要一个人上岛。你们在海湾里等我。”",
    ], [
        EC("powder_ashore", "先把两桶火药悄悄搬上岸（开场军令点 +2）", {}, [], rogue={"coins": {"supply": -1}}, boss_mod={"cp_bonus": 2}),
        EC("false_course", "让船老大在卡普拉亚放话：我们去撒丁岛（敌军心 −2）", {"heat": 5}, [], boss_mod={"enemy_morale": -2}),
        EC("night_landing", "天黑以前就靠岸（多一回合布阵）", {"vitality": -3}, [], boss_mod={"prep_turn": 1}),
    ], weight=0, council=True, date="1829-05-22"),
    E("ev_c4_council", "fixed", "万帕的信使", "罗马·伦敦饭店的走廊", "vampa", [
        "1838 年 2 月 21 日夜。一个牧羊人打扮的少年把纸条塞进伯爵的门缝：阿尔贝·德·莫尔塞夫在我们手里。",
        "少年叫佩皮诺。三年前，伯爵在人民广场的断头台下救过他一命。",
        "佩皮诺：“头领不知道他是伯爵的朋友。你们现在去，也许还来得及。”",
    ], [
        EC("peppino_guide", "让佩皮诺带路，走墓窟的后门（开场军令点 +2）", {}, [], boss_mod={"cp_bonus": 2}),
        EC("count_card", "把伯爵的名片交给佩皮诺先送进去（敌军心 −2）", {"heat": 5}, [], boss_mod={"enemy_morale": -2}),
        EC("go_now", "不等天亮，现在就走（多一回合布阵）", {"vitality": -3}, [], boss_mod={"prep_turn": 1}),
    ], weight=0, council=True, date="1838-02-21"),
    E("ev_c5_council", "fixed", "圣母院的钟楼", "西岱岛·圣母院北钟楼", "dantes", [
        "1838 年 10 月 14 日夜，圣母院的钟楼。河对岸就是司法宫的屋顶。",
        "伯爵：“贝内代托关在附属监狱。明天上午开庭。今天夜里有三拨人想让他闭嘴。”",
        "伯爵：“你是维尔福家的人。你说，这个人该不该活到明天？”",
    ], [
        EC("bribe_turnkeys", "买通附属监狱的两个看守（开场军令点 +2）", {"treasury": -800}, [], boss_mod={"cp_bonus": 2}),
        EC("tip_the_press", "把开庭的消息透给报馆：明早全巴黎都会在门口（敌军心 −2）", {"heat": 10}, [], boss_mod={"enemy_morale": -2}),
        EC("move_at_dusk", "天一黑就把人调过钟楼码头（多一回合布阵）", {"vitality": -3}, [], boss_mod={"prep_turn": 1}),
    ], weight=0, council=True, date="1838-10-14"),
]

INTERLUDES = [
    E("ev_i_marseille", "interlude:bond", "加泰罗尼亚人的小船上", "马赛湾", "morrel", [
        "1815 年 6 月 26 日凌晨。小船在海湾里漂了一夜。伊夫堡的灯一直亮着。",
        "挑两个人坐在你身边，把这一夜说完。",
    ], [
        EC("bond_two", "挑两位伙伴，信赖各 +1", {}, [], bond_pick=2),
    ], weight=0, chapter="marseille"),
    E("ev_i_if_years", "interlude:minigame:decode", "法利亚的衬衫书", "伊夫堡·34 号", "faria", [
        "法利亚用鱼骨做笔、用煤灰和酒做墨，把一部书写在两件衬衫上。",
        "最后一页是一张密码表。他说：“学会它，你就能读我留下的每一封信。”",
    ], [
        EC("decode", "破译密码表（查验小游戏·破译）", {"exploration": 10}, ["m_faria_cipher"], minigame="decode"),
        EC("skip", "收好衬衫，以后再看", {}, []),
    ], weight=0, chapter="if_years"),
    E("ev_i_montecristo", "interlude:camp_night", "基督山岛的第一夜", "基督山岛·山洞外", "dantes", [
        "唐泰斯坐在洞口，把一枚金币翻过来，又翻过去。",
        "唐泰斯：“法利亚说过，财富是一件武器。我还没想好，先对准谁。”",
    ], [
        EC("rest", "让大家睡一整夜（体力 +8）", {"vitality": 8}, []),
        EC("count_gold", "连夜清点箱子（经费 +400）", {"treasury": 400}, []),
        EC("talk", "陪他坐到天亮（人心 +4）", {"morale": 4}, ["m_cave_night_talk"]),
    ], weight=0, chapter="montecristo"),
    E("ev_i_mediterranean", "interlude:audience", "伯爵召见", "基督山岛·地下宫殿", "dantes", [
        "伯爵在地下宫殿里摆了一张长桌。桌上只有三样东西：一本账簿、一份名单、一瓶绿色的药膏。",
        "伯爵：“去巴黎以前，我要听你说几句真话。”",
    ], [
        EC("q_family", "“维尔福这个姓，你打算怎么办？”——“它不是我选的。”", {"morale": 2}, []),
        EC("q_mercy", "“如果有人求你放过他？”——“看他求的是什么。”", {}, ["m_mercy_seed"]),
        EC("q_ledger", "“账要算到哪一笔为止？”——“算到最后一笔。”", {"exploration": 10}, ["m_ledger_seed"]),
    ], weight=0, chapter="mediterranean"),
    E("ev_i_paris", "interlude:minigame:weigh", "唐格拉尔的金库", "昂坦街·银行地下室", "danglars", [
        "唐格拉尔银行的地下室。九只箱子，账上写着九百万。",
        "过一过秤，就知道里面还剩多少。",
    ], [
        EC("weigh", "逐只过秤（查验小游戏·过秤）", {"exploration": 10}, ["m_vault_weighed"], minigame="weigh"),
        EC("skip", "不必了，账簿上已经写着", {}, []),
    ], weight=0, chapter="paris_1838"),
]

# ------------------------------------------------------------------ companions (companions.json rows)
# battle blocks of shared ids are copied verbatim from data/campaigns/ocean_battle.json (dantes, faria, morel) or the
# conquest draft (baptiste, corso, marie); this file only ADDS the cristo recruit point and cristo-only bond tags.
SHARED_PATCH = {
    "dantes": {"segments_add": ["cristo"], "recruit_by_segment": {"cristo": {"scene": "c_faria_dies", "choice": ["sack_plan", "medicine_last", "knife_in_sack"]}},
               "bonds_by_segment": {"cristo": ["marseille", "count", "shadow"]}, "fated_by_segment": {"cristo": "if_corridors"},
               "note": "第二章出狱前一直在伊夫堡里：只能在 if_corridors 上阵（第 9 回合起）。远洋数值不动。"},
    "faria": {"segments_add": ["cristo"], "recruit_by_segment": {"cristo": {"scene": "c_faria_dies", "choice": ["medicine_last"]}},
              "bonds_by_segment": {"cristo": ["scholar", "count"]}, "fated_by_segment": {"cristo": "monte_cristo_cave"},
              "note": "原著里死于第三次发作。只有带着药（m_faria_medicine）才能招到；宿命之地是基督山岛的藏宝洞。"},
    "morel": {"segments_add": ["cristo"], "recruit_by_segment": {"cristo": {"scene": "c_landfall"}},
              "bonds_by_segment": {"cristo": ["marseille", "far_sea"]}, "fated_by_segment": {"cristo": "marseille_arrest"},
              "note": "伙伴 id 用远洋的 morel；人物表里是 morrel（莫雷尔先生，法老号船东）。"},
    "baptiste": {"note": "主干携带而来；伊夫堡段无专属情节。"},
    "corso": {"note": "主干携带而来；第二章卡西斯酒馆有他的个人事件（规划）。"},
    "marie": {"note": "主干携带而来。"},
}

COMPANIONS = {
    "caderousse": {"name": "卡德鲁斯", "short": "卡德鲁斯", "segments": ["cristo"], "recruit": {"scene": "c_reserve", "choice": "caderousse_home", "or_event": "ev_caderousse_wine"},
                   "bonds": ["marseille"], "battle": {"short": "卡德鲁斯", "cls": "line", "hp": 14, "atk": 4, "def": 1, "block": 2, "cost": 3, "skill": "raise_flag",
                   "skill_title": "酒馆里的大嗓门（举旗：本行友军攻 +2，2 回合）", "fated_scene": "", "role": "战列步兵 · 胆小的老邻居"},
                   "fated": "auteuil_garden", "keep": "留守：每章情报 +1（他什么闲话都听得到）。", "relic": "卡德鲁斯的裁缝剪（阵亡后：本章第一次过路费免掉）",
                   "personal": ["ev_caderousse_wine"], "risk": "信赖 0 时，第四章的钻石事件里他会出卖你（追缉 +20，离队）。原著里他死在贝内代托手里（1838）。"},
    "jacopo": {"name": "雅科波", "short": "雅科波", "segments": ["cristo"], "recruit": {"scene": "c_morgiou", "choice": ["share_fair", "buy_the_boat"]},
               "bonds": ["smugglers", "far_sea"], "battle": {"short": "雅科波", "cls": "artillery", "hp": 10, "atk": 6, "def": 0, "block": 0, "cost": 6, "skill": "mark_target",
               "skill_title": "船头回旋炮（标记：对射程内一个敌人 8 伤）", "fated_scene": "", "role": "炮兵 · 走私船的炮手"},
               "fated": "tiboulen_swim", "keep": "留守：航程连线少 1 天（最少 1 天）。", "relic": "少年阿梅莉号的缆绳（阵亡后：浅水格我方单位防 +1）"},
    "bertuccio": {"name": "贝尔图乔", "short": "贝尔图乔", "segments": ["cristo"], "recruit": {"event": "ev_bertuccio_name", "choice": ["tell_truth", "lie"]},
                  "bonds": ["smugglers", "count"], "battle": {"short": "贝尔图乔", "cls": "engineer", "hp": 14, "atk": 4, "def": 2, "block": 1, "cost": 3, "skill": "fortify",
                  "skill_title": "科西嘉人的门闩（筑垒：放拒马或筑胸墙）", "fated_scene": "", "role": "工兵 · 发过誓的科西嘉人"},
                  "fated": "auteuil_garden", "keep": "留守：兵站不会被对手烧掉。", "relic": "缠黑布的刀（阵亡后：本场猎官对主角的攻击 −2）"},
    "haydee": {"name": "海黛", "short": "海黛", "segments": ["cristo"], "recruit": {"event": "ev_haydee_constantinople"},
               "bonds": ["orient", "count"], "battle": {"short": "海黛", "cls": "medic", "hp": 9, "atk": 0, "def": 1, "block": 0, "cost": 3, "skill": "raise_flag",
               "skill_title": "约阿尼纳的证词（举旗：本行友军攻 +2，2 回合）", "fated_scene": "", "role": "军医 · 总督的女儿"},
               "fated": "cristo_final", "keep": "留守：每章卷宗 +10。", "relic": "阿里总督的念珠（阵亡后：贵族院一场的证据自动齐全）"},
    "ali": {"name": "阿里", "short": "阿里", "segments": ["cristo"], "recruit": {"scene": "c_carnival", "auto": True},
            "bonds": ["orient", "count"], "battle": {"short": "阿里", "cls": "grenadier", "hp": 20, "atk": 5, "def": 3, "block": 3, "cost": 6, "skill": "bayonet_charge",
            "skill_title": "马索（刺刀冲锋：挡住的敌人各受 5 伤并被击退）", "fated_scene": "", "role": "掷弹兵 · 不说话的努比亚人"},
            "fated": "san_sebastiano", "keep": "留守：每章体力 +4。", "relic": "阿里的马索（阵亡后：骠骑兵冲锋距离 +1）"},
    "maximilien": {"name": "马克西米利安·莫雷尔", "short": "马克西米利安", "segments": ["cristo"], "recruit": {"scene": "c_morrel_rescue", "choice": "recruit_maximilien", "or_shop": "paris_1838"},
                   "bonds": ["marseille", "paris"], "battle": {"short": "马克西米利安", "cls": "hussar", "hp": 12, "atk": 6, "def": 1, "block": 1, "cost": 4, "skill": "bayonet_charge",
                   "skill_title": "北非骑兵的冲锋（刺刀冲锋：挡住的敌人各受 5 伤并被击退）", "fated_scene": "", "role": "骠骑兵 · 北非骑兵上尉"},
                   "fated": "cristo_final", "keep": "留守：每章人心 +2。", "relic": "法老号的模型（阵亡后：莫雷尔攻 +2）"},
    "vampa": {"name": "路易吉·万帕", "short": "万帕", "segments": ["cristo"], "recruit": {"scene": "c_san_sebastiano", "choice": "vampa_debt"},
              "bonds": ["smugglers", "bandit"], "battle": {"short": "万帕", "cls": "jager", "hp": 9, "atk": 5, "def": 0, "block": 0, "cost": 4, "skill": "mark_target",
              "skill_title": "牧羊人的子弹（标记：对射程内一个敌人 8 伤）", "fated_scene": "", "role": "猎兵 · 罗马城外的强盗头子"},
              "fated": "paris_rooftops", "keep": "留守：过路费一律免掉。", "relic": "万帕的《凯撒战记》（阵亡后：伏兵波次提前 1 回合公开）"},
    "albert": {"name": "阿尔贝·德·莫尔塞夫", "short": "阿尔贝", "segments": ["cristo"], "recruit": {"scene": "c_san_sebastiano", "choice": "albert_oath"},
               "bonds": ["paris"], "battle": {"short": "阿尔贝", "cls": "line", "hp": 13, "atk": 4, "def": 1, "block": 2, "cost": 4, "skill": "raise_flag",
               "skill_title": "子爵的决斗手套（举旗：本行友军攻 +2，2 回合）", "fated_scene": "", "role": "战列步兵 · 议员的儿子"},
               "fated": "cristo_final", "keep": "留守：巴黎每章经费 +300。", "relic": "莫尔塞夫家的纹章（阵亡后：梅尔塞苔丝的请求自动成立）",
               "risk": "第五章贵族院（c_peers）以后，如果海黛也在名册里，两人不能同场（discord）。"},
}

PAIRS = [
    {"id": "master_pupil", "name": "师徒", "a": "dantes", "b": "faria", "tiers": {
        "1": "同场时法利亚的筑垒每次多放 1 个拒马。", "2": "法利亚相邻时唐泰斯攻 +2。", "3": "法利亚命悬一线 +1 枚；唐泰斯的冲锋不会停在泥地和瓦砾上。"}},
    {"id": "wait_and_hope", "name": "等待与希望", "a": "dantes", "b": "haydee", "tiers": {
        "1": "海黛在场时唐泰斯每回合回 2。", "2": "唐泰斯倒下时，海黛的举旗立刻充满。", "3": "解锁结局“等待与希望”的最后一段。"}},
    {"id": "enemy_name", "name": "仇人的姓", "a": "bertuccio", "b": "hero", "discord": True, "tiers": {
        "1": "两人同场时贝尔图乔攻 +2；相邻时每回合军心 −1。", "2": "（说过实话 m_bertuccio_knows）不再扣军心。", "3": "（奥特伊之夜后）贝尔图乔替主角挡下第一次猎官攻击。"}},
    {"id": "old_neighbours", "name": "老邻居", "a": "caderousse", "b": "dantes", "discord": True, "tiers": {
        "1": "两人同场时卡德鲁斯防 −1。", "2": "（m_caderousse_sworn）卡德鲁斯攻 +2，直到战斗结束。"}},
    {"id": "father_son", "name": "莫雷尔父子", "a": "morel", "b": "maximilien", "tiers": {
        "1": "同一行时举旗持续 3 回合。", "2": "一方倒下，另一方本场命悬一线 +1 枚。"}},
    {"id": "two_children", "name": "两个孩子", "a": "albert", "b": "haydee", "discord": True, "tiers": {
        "1": "第五章贵族院以后两人不能同场。", "2": "（m_mercedes_spared）discord 解除，同场时两人各攻 +1。"}},
]

BOND_FACTIONS = [
    {"id": "marseille_folk", "name": "马赛老街坊", "kind": "faction", "tag": "marseille", "tiers": [2, 3], "effect": "camp_family",
     "desc": "1815 年就在马赛的人。2：所有伙伴命悬一线 +1 枚；成员周围 2 格内的单位每回合回 1 兵力。3：街巷类地形（街道、房屋）开场军令点 +1。"},
    {"id": "smugglers", "name": "走私帮", "kind": "faction", "tag": "smugglers", "tiers": [2, 3], "effect": "spoils",
     "desc": "地中海的走私船和山里的强盗。2：战后法郎 +20%；3：再 +1 金币。"},
    {"id": "counts_house", "name": "伯爵府", "kind": "faction", "tag": "count", "tiers": [2, 3], "effect": "intel",
     "desc": "基督山伯爵的人。2：军令手牌补到 4 张；3：来敌提前 3 回合公开（包括隐身的敌人）。"},
    {"id": "orient", "name": "东方", "kind": "faction", "tag": "orient", "tiers": [2], "effect": "workshop",
     "desc": "从约阿尼纳和君士坦丁堡来的人。2：成员技能每回合多充能 1。"},
    {"id": "bandits", "name": "强盗的信义", "kind": "faction", "tag": "bandit", "tiers": [1], "effect": "spoils",
     "desc": "1：赎金（ransom）类敌人走进鹰旗时不扣金币。"},
    {"id": "paris_society", "name": "巴黎社交界", "kind": "faction", "tag": "paris", "tiers": [2], "effect": "spoils",
     "desc": "2：战后法郎 +20%。"},
]
