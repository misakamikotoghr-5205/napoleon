## 段切换时带什么走（WORLD_MAP_DESIGN §4.4，book.carry），以及调试入口的标准携带（book.debug_carry，§6.2）。
## 没有 class_name，别处 preload。只改 campaign.state（在 send() 的候选副本里，失败整体回滚）。
extends RefCounted

const RogueRules = preload("res://scripts/cards/campaign/ocean_rogue_rules.gd")
const Battle2 = preload("res://scripts/cards/campaign/ocean_battle2.gd")

const DEFAULT_CARRY := {"metrics": {"treasury": "chapter_start", "morale": "keep", "heat": "initial", "vitality": ["keep_min", 40],
	"construction": "initial", "exploration": "initial"}, "treasury_bonus": [1, 4], "flags": "all", "items": [], "rogue": "all", "coin_cap": 20}


## 军费折算：旧币 → 法郎 → 目标币（ocean_battle.json 的 franc_rate：账本单位 = 法郎 × num / den），整数、向下取整
static func convert_treasury(amount: int, from_currency: String, to_currency: String) -> int:
	if from_currency == to_currency:
		return amount
	var rates: Dictionary = Battle2.data().get("franc_rate", {})
	var a: Array = rates.get(from_currency, [1, 1])
	var b: Array = rates.get(to_currency, [1, 1])
	var francs := amount * maxi(1, int(a[1])) / maxi(1, int(a[0]))
	return francs * int(b[0]) / maxi(1, int(b[1]))


## 段切换：state 已经换上目标段的 definition / segment / scene_index 之前调用；old_chapter 是离开时的那一章
static func apply(campaign, target_def: Dictionary, target_chapter: Dictionary, old_chapter: Dictionary) -> void:
	var state: Dictionary = campaign.state
	var carry: Dictionary = DEFAULT_CARRY.duplicate(true)
	carry.merge(campaign.book.get("raw", {}).get("carry", {}), true)
	var old_metrics: Dictionary = state["metrics"].duplicate()
	var initial: Dictionary = target_def.get("initial", {})
	var rules: Dictionary = carry.get("metrics", {})
	for m in old_metrics:
		var rule = rules.get(m, "keep")
		var v := int(old_metrics[m])
		if typeof(rule) == TYPE_ARRAY and (rule as Array).size() == 2 and str(rule[0]) == "keep_min":
			v = maxi(v, int(rule[1]))
		elif str(rule) == "initial":
			v = int(initial.get(m, v))
		elif str(rule) == "chapter_start":
			var bonus: Array = carry.get("treasury_bonus", [1, 4])
			var moved := convert_treasury(v, str(old_chapter.get("currency", "")), str(target_chapter.get("currency", "")))
			v = int(target_chapter.get("treasury_start", 1)) + moved * int(bonus[0]) / maxi(1, int(bonus[1]))
		state["metrics"][m] = clampi(v, 0, 1000000000000 if m == "treasury" else 100)
	if str(carry.get("flags", "all")) != "all":
		state["flags"] = {}
	var keep_items: Array = carry.get("items", [])
	var items: Array = []
	for item in state["inventory"]:
		if str(item) in keep_items:
			items.append(item)
	state["inventory"] = items
	var rogue: Dictionary = state["rogue"]
	var cap := int(carry.get("coin_cap", 20))
	for c in rogue["coins"]:
		rogue["coins"][c] = mini(int(rogue["coins"][c]), cap)
	rogue["battle2"] = Battle2.new_battle2()
	var fresh := RogueRules.fresh_march_calendar()
	rogue["march"] = fresh["march"]
	rogue["calendar"] = fresh["calendar"]
	rogue["big_fate"]["pending"] = false
	rogue["big_fate"]["trigger"] = ""
	var army: Dictionary = rogue["army"]
	army["chapter"] = str(target_chapter.get("id", ""))
	Battle2.top_up_troops(army, str(target_chapter.get("id", "")), campaign.start_troops(str(target_chapter.get("id", ""))))


## 调试 / 篇章入口的标准携带：debug_carry.<段>（stages 里的一档是完整的绝对值，叠在 from 上，不逐档累加）
static func debug(campaign, seg: String, stage: int) -> Dictionary:
	var dc: Dictionary = campaign.book.get("raw", {}).get("debug_carry", {})
	var own: Dictionary = dc.get(seg, {})
	var base: Dictionary = dc.get(str(own.get("from", "")), {}).duplicate(true) if own.has("from") else {}
	for key in own:
		if key != "stages" and key != "from":
			base[key] = own[key]
	var st = own.get("stages", {}).get(str(stage))
	if typeof(st) == TYPE_DICTIONARY:
		for key in st:
			base[key] = st[key]
	var state: Dictionary = campaign.state
	var rogue: Dictionary = state["rogue"]
	if typeof(base.get("coins")) == TYPE_DICTIONARY:
		for c in base["coins"]:
			if rogue["coins"].has(c):
				rogue["coins"][c] = clampi(int(base["coins"][c]), 0, 999)
	for key in ["flags", "flags_add"]:
		for f in base.get(key, []):
			state["flags"][str(f)] = true
	for item in base.get("items", []):
		if not str(item) in state["inventory"]:
			state["inventory"].append(str(item))
	var comps = base.get("companions", {})
	if typeof(comps) == TYPE_DICTIONARY:
		for c_id in comps:
			var row: Dictionary = rogue["companions"].get(c_id, {})
			if row.is_empty():
				continue
			row["recruited"] = true
			row["alive"] = true
			row["level"] = clampi(int(comps[c_id]), 1, 3)
			if int(campaign.book.get("volume", 1)) >= 2:
				# Presets describe absolute levels, with the same stats as earned
				# promotions. V1 retains its original carry and replay behavior.
				var profile: Dictionary = campaign.roster()["profiles"][c_id]
				var promotions := int(row["level"]) - 1
				row["max_hp"] = int(profile.get("hp", 10)) + 25 * promotions
				row["hp"] = int(row["max_hp"])
				row["atk"] = int(profile.get("atk", 1)) + 6 * promotions
				var maximum := int(row["max_hp"])
				row["b_max_hp"] = maximum - maximum / 4 if bool(row.get("scarred", false)) else maximum
	if typeof(base.get("troops")) == TYPE_ARRAY:
		var army: Dictionary = rogue["army"]
		army["troops"] = []
		army["next_troop"] = 1
		Battle2.top_up_troops(army, str(army.get("chapter", "")), base["troops"])
	return base
