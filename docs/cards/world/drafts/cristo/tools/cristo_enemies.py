# Enemy roster for the cristo branch, in battle_rules.gd ENEMIES shape (L1 base values; the level table scales them).
# src: arch = ARCH §5 cristo table verbatim; ocean = same id/values as the ocean draft (wm/ocean/ocean_battles.json);
#      trunk = ARCH §5 trunk table verbatim; new = added by this draft.
E = {}


def add(id, name, hp, atk, df, spd, typ, rng, tags, src, note="", **kw):
    E[id] = dict({"name": name, "hp": hp, "atk": atk, "def": df, "spd": spd, "type": typ, "range": rng, "tags": tags, "src": src, "note": note}, **kw)


# ---------------------------------------------------------------- ARCH §5 (cristo), verbatim
add("gendarme", "宪兵", 7, 3, 2, 1, "infantry", 0, ["arrest"], "arch", "王家宪兵。主角在他的白刃下倒下就直接被捕（不掷铜钱），战役层转入大命运「被捕」。")
add("mounted_gendarme", "骑宪兵", 9, 4, 1, 2, "cavalry", 0, ["arrest", "hunter"], "arch", "骑马的宪兵：猎官，冲着主角来，而且会把他带走。")
add("prison_guard", "狱卒", 8, 3, 1, 1, "infantry", 0, [], "arch")
add("turnkey_chief", "典狱长", 11, 3, 2, 1, "leader", 0, ["officer"], "arch", "伊夫堡的看守长，腰上挂着整串钥匙。模板用 on_kill 锁门（if_corridors）。")
add("customs", "海关缉私兵", 6, 3, 1, 1, "infantry", 2, [], "arch")
add("smuggler", "走私贩", 6, 3, 0, 2, "infantry", 0, ["stealth"], "arch", "对手帮派的走私贩：离我方单位 2 格以外时看不清是谁。")
add("bandit", "罗马强盗", 6, 4, 0, 1, "infantry", 0, ["ambush", "ransom"], "arch")
add("bandit_marksman", "强盗枪手", 4, 4, 0, 0, "infantry", 3, ["post", "stealth"], "arch", at_terrain=["high", "rooftop", "woods"])
add("vampa", "路易吉·万帕", 14, 5, 2, 1, "leader", 0, ["officer", "ransom"], "arch", "第四章之前是敌人（亚壁古道伏击）；打退他以后可以招为伙伴（companions_cristo.json）。")
add("assassin", "刺客", 8, 7, 1, 2, "elite", 0, ["hunter", "execute", "stealth"], "arch")
add("benedetto", "贝内代托", 13, 6, 1, 2, "elite", 0, ["hunter", "execute"], "arch", "杰拉尔·德·维尔福的私生子，土伦苦役犯，后来的“安德烈亚·卡瓦尔康蒂子爵”。")
add("national_guard", "国民自卫军", 7, 3, 1, 1, "infantry", 0, [], "arch")

# ---------------------------------------------------------------- shared with the ocean draft (same ids, same values)
add("royalist_bravo", "保王党刺客", 6, 4, 0, 1, "infantry", 0, ["boarder"], "ocean", "1815 年的白色恐怖。远洋稿定义；这里用在马赛六月。")
add("royalist_marksman", "保王党枪手", 5, 4, 0, 1, "infantry", 2, ["sniper", "boarder"], "ocean")
add("royalist_chief", "保王党头目", 10, 4, 1, 1, "leader", 0, ["officer", "boarder"], "ocean")
add("gunboat", "炮艇", 10, 6, 2, 0, "gun", 99, ["boat"], "ocean", at_terrain=["sea"], move="boat")

# ---------------------------------------------------------------- trunk (ARCH §5), verbatim — Janina chapter (outline)
add("nizam", "奥斯曼步兵", 6, 3, 0, 1, "infantry", 0, [], "trunk")
add("bey", "贝伊", 11, 4, 2, 1, "leader", 0, ["officer"], "trunk")
add("ottoman_gun", "奥斯曼炮", 8, 6, 0, 0, "gun", 99, [], "trunk")

# ---------------------------------------------------------------- new in this draft
add("verdet", "绿衫志愿兵", 6, 3, 0, 1, "infantry", 0, [], "new",
    "1815 年夏天南方白色恐怖里的保王党志愿兵，穿阿图瓦伯爵的绿色（史实 verdets）。比保王党刺客弱一档，是马赛六月的大多数。")
add("ng_grenadier", "国民自卫军掷弹兵", 12, 4, 2, 1, "elite", 0, ["heavy"], "new",
    "1815 年 6 月倒向国王的马赛国民自卫军掷弹兵连：重型，挡住他要 2 点阻挡。")
add("customs_officer", "海关稽查官", 10, 3, 2, 1, "leader", 0, ["officer"], "new", "缉私队的头目。打死他，这一队后退一格、攻 −1。")
add("revenue_cutter", "缉私快艇", 9, 5, 1, 0, "gun", 99, ["boat", "short"], "new",
    "海关的小快艇，船头一门回旋炮：只能停在海格，只打与自己列差 ≤4 的格子。比远洋的炮艇弱一档。", at_terrain=["sea"], move="boat")
add("if_soldier", "伊夫堡守军", 7, 3, 1, 1, "infantry", 0, [], "new", "要塞的驻军，大多是上了年纪的老兵。")
add("if_veteran", "守军老军士", 12, 4, 2, 1, "elite", 0, ["heavy"], "new", "要塞驻军里的老军士：重型，挡住他要 2 点阻挡。")
add("wall_sentry", "墙头哨兵", 4, 4, 0, 0, "infantry", 3, ["post", "sniper"], "new",
    "站在城墙上的哨兵：定点不动，射程 3，先打主角和伙伴。打死以后那一格空出来，我方炮兵、猎兵可以接手。", at_terrain=["high"])
add("fort_gun", "伊夫堡炮台", 10, 6, 1, 0, "gun", 99, [], "new", "要塞的报警炮。逃狱那一夜它会开火。", at_terrain=["high"])
add("thug", "码头打手", 7, 4, 0, 1, "infantry", 0, [], "new", "通用遭遇战的街头打手：马赛的、罗马的、巴黎的都一样。补兵（pad）用它。")
add("thug_marksman", "黑枪手", 4, 4, 0, 0, "infantry", 3, ["post", "stealth", "sniper"], "new", "躲在屋顶或窗后的黑枪：定点、射程 3、先打主角和伙伴。", at_terrain=["rooftop", "high"])
add("thug_boss", "打手头子", 11, 4, 1, 1, "leader", 0, ["officer"], "new")
add("rival_smuggler_boss", "对头帮的船老大", 12, 5, 1, 1, "leader", 0, ["officer", "stealth"], "new", "热那亚帮的船老大，和雅科波的人抢同一条水道。")
# outline chapters (templates only planned; values are proposals)
add("papal_carabinier", "教皇宪兵", 8, 4, 2, 1, "infantry", 0, ["arrest"], "new", "罗马的教皇宪兵（第四章）。")
add("papal_dragoon", "教皇龙骑兵", 10, 5, 1, 2, "cavalry", 0, ["hunter"], "new")
add("sbirro", "教廷密探", 6, 3, 1, 1, "infantry", 0, ["stealth", "arrest"], "new")
add("arnaut", "阿尔瑙特枪手", 6, 4, 0, 1, "infantry", 2, ["skirmisher"], "new", "约阿尼纳的阿尔巴尼亚雇佣兵（第四章）。")
add("municipal_guard", "巴黎市政卫队", 12, 4, 3, 1, "elite", 0, ["heavy"], "new", "七月王朝的巴黎市政卫队（第五章）。")
add("convict", "土伦苦役犯", 7, 4, 0, 1, "infantry", 0, ["loot"], "new", "贝内代托从土伦苦役场带出来的人（第五章）。")
add("police_agent", "治安密探", 6, 3, 1, 1, "infantry", 0, ["stealth", "arrest"], "new", "巴黎警察厅的便衣（第五章）。")
