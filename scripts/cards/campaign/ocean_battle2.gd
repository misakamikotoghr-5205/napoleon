## 远洋战役接入战斗规则 v2：出征名单 → 开战 → 下指令 → 战后结算（奖赏、伤痕、阵亡、被俘、讣告、大命运）。
## 纯逻辑，只有静态函数；没有 class_name，别处 preload。玩家看得到的中文都在 data/campaigns/ocean_battle.json。
## 状态全在 campaign.state.rogue 里（army、battle2、companions 的战斗字段），只放整数 / 字符串 / 布尔 / 数组 / 字典。
## 规则说明：docs/cards/BATTLE_V2.md「接入远洋战役」。
extends RefCounted

const BattleRules = preload("res://scripts/cards/campaign/battle/battle_rules.gd")
const Data = preload("res://scripts/cards/campaign/ocean_rogue_data.gd")
const BattleApi = preload("res://scripts/cards/campaign/run/run_battle_api.gd")
const MapRules = preload("res://scripts/cards/campaign/map/map_rules.gd")
const RunConditions = preload("res://scripts/cards/campaign/run/run_conditions.gd")
const CompanionRules = preload("res://scripts/cards/campaign/companion_rules.gd")
const DATA_PATH := "res://data/campaigns/ocean_battle.json"
const PHASES := ["none", "lineup", "active", "finished"]
const TROOP_CLASSES := ["line", "grenadier", "jager", "hussar", "artillery"]
const HERO := "hero"

static var _data: Dictionary = {}
static var _lib: Dictionary = {}


static func data() -> Dictionary:
	if _data.is_empty() and FileAccess.file_exists(DATA_PATH):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
		if typeof(parsed) == TYPE_DICTIONARY:
			_data = _ints(parsed)
	return _data


## 战场模板库（只读；BattleRules.load_templates 每次都深拷贝一份，查询里频繁用，这里留一份）
static func lib() -> Dictionary:
	if _lib.is_empty():
		_lib = BattleRules.load_templates()
	return _lib


static func profile(c_id: String) -> Dictionary:
	return data().get("companions", {}).get(c_id, {})


## Promotions already update the campaign roster. Volume two uses those earned
## stats in combat; scars are still applied once by the battle kernel.
static func effective_profile(campaign, c_id: String) -> Dictionary:
	var out: Dictionary = (roster_of(campaign)["profiles"].get(c_id, {}) as Dictionary).duplicate(true)
	if CompanionRules.enabled(campaign):
		var comp: Dictionary = campaign.state["rogue"]["companions"].get(c_id, {})
		out["hp"] = int(comp.get("max_hp", out.get("hp", 10)))
		out["atk"] = int(comp.get("atk", out.get("atk", 1)))
	return out


static func sync_growth_display(campaign, comp: Dictionary) -> void:
	if CompanionRules.enabled(campaign):
		var maximum := int(comp["max_hp"])
		comp["b_max_hp"] = maximum - maximum / 4 if bool(comp.get("scarred", false)) else maximum


static func text(key: String) -> String:
	return str(data().get("text", {}).get(key, key))


# ================================================================ 书模式（多段书）还是单段书

## 多段书（napoleon、迷你书）；单段书 ocean_pawn 和只有 state / scene() 的替身（界面测试）都算单段
static func is_book(campaign) -> bool:
	return campaign.has_method("is_builtin") and not campaign.is_builtin()


## 名册：战役模型给的（书的伙伴总表或单段书的 8 人）；替身没有 roster() 时就是单段书的 8 人
static func roster_of(campaign) -> Dictionary:
	if campaign.has_method("roster"):
		return campaign.roster()
	return {"ids": Data.COMPANION_IDS.duplicate(), "specs": Data.COMPANIONS, "profiles": data().get("companions", {})}


# ================================================================ 名册里的战斗字段

static func new_army(chapter_id: String, want = null) -> Dictionary:
	var army := {"troops": [], "next_troop": 1, "trust": {}, "hero_wounded": false, "chapter": chapter_id}
	top_up_troops(army, chapter_id, want)
	return army


static func new_battle2() -> Dictionary:
	return {"phase": "none", "scene": "", "template": "", "scale": "", "act": 1, "revealed": false, "hunters": 0,
		"lineup": {}, "state": {}, "result": {}}


## 伙伴行里的战斗字段：伤痕、被俘、伤痕之后的兵力上限
static func add_companion_fields(c_id: String, row: Dictionary, base_hp: int = -1) -> void:
	var base := int(profile(c_id).get("hp", 10)) if base_hp < 0 else base_hp
	if not row.has("scarred"):
		row["scarred"] = false
	if not row.has("captured"):
		row["captured"] = false
	if not row.has("b_max_hp"):
		row["b_max_hp"] = base - base / 4 if bool(row["scarred"]) else base


## 名册至少要有这一部的起始部队（按兵种数，缺几支补几支）；want 给了就用它（书的 start_troops、调试携带）
static func top_up_troops(army: Dictionary, chapter_id: String, want_in = null) -> void:
	var want: Array = want_in if typeof(want_in) == TYPE_ARRAY else data().get("start_troops", {}).get(chapter_id, [])
	var need := {}
	for cls in want:
		need[str(cls)] = int(need.get(str(cls), 0)) + 1
	for cls in TROOP_CLASSES:
		var have := 0
		for t in army["troops"]:
			if str(t["cls"]) == cls:
				have += 1
		for _i in range(maxi(0, int(need.get(cls, 0)) - have)):
			_add_troop(army, cls)


static func _add_troop(army: Dictionary, cls: String) -> Dictionary:
	var n := int(army.get("next_troop", 1))
	var troop := {"id": "%s_%d" % [cls, n], "cls": cls, "strength": int(data().get("troop_strength", 3))}
	army["troops"].append(troop)
	army["next_troop"] = n + 1
	return troop


## 旧存档（还没有 army / battle2 的）补上默认值；已经有的不动
static func migrate(rogue: Dictionary, chapter_id: String) -> void:
	if not rogue.has("army"):
		rogue["army"] = new_army(chapter_id)
	if not rogue.has("battle2"):
		rogue["battle2"] = new_battle2()
	var comps = rogue.get("companions", {})
	if typeof(comps) == TYPE_DICTIONARY:
		for c_id in Data.COMPANION_IDS:
			if typeof(comps.get(c_id)) == TYPE_DICTIONARY:
				add_companion_fields(c_id, comps[c_id])


## 每进一场：换了一部就按新一部补部队；上一场没开打的出征名单作废（打到一半的仗留着，结算照常）
static func on_enter_scene(rogue: Dictionary, scene_id: String, chapter_id: String, want = null) -> void:
	var army: Dictionary = rogue["army"]
	if str(army.get("chapter", "")) != chapter_id:
		army["chapter"] = chapter_id
		top_up_troops(army, chapter_id, want)
	var b2: Dictionary = rogue["battle2"]
	if str(b2.get("phase", "none")) == "lineup" and str(b2.get("scene", "")) != scene_id:
		rogue["battle2"] = new_battle2()


## 招募部队（走 campaign.recruit {id: "troop:<兵种>"}）
static func recruit_troop(campaign, cls: String) -> Dictionary:
	if not cls in TROOP_CLASSES:
		return _fail("bad_args")
	var rogue: Dictionary = campaign.state["rogue"]
	var army: Dictionary = rogue["army"]
	if (army["troops"] as Array).size() >= int(data().get("troop_cap", 8)):
		return _fail("roster_full")
	var cost := int(data().get("troops", {}).get(cls, {}).get("gold", 1))
	if MapRules.at_depot(campaign):
		cost = maxi(0, cost - 1)
	cost = maxi(0, cost - CompanionRules.reserve_bonus(campaign, "recruit_discount") - (CompanionRules.reserve_bonus(campaign, "artillery_discount") if cls == "artillery" else 0))
	if int(rogue["coins"].get("gold", 0)) < cost:
		return _fail("insufficient_funds")
	rogue["coins"]["gold"] = int(rogue["coins"]["gold"]) - cost
	var troop := _add_troop(army, cls)
	campaign._record("recruit_troop", {"id": troop["id"], "cls": cls, "cost": cost})
	return _ok()


## 剧情直接给的部队（rogue.troops）：不花钱，满编就不给
static func grant_troop(campaign, cls: String) -> void:
	if not cls in TROOP_CLASSES:
		return
	var army: Dictionary = campaign.state["rogue"]["army"]
	if (army["troops"] as Array).size() < int(data().get("troop_cap", 8)):
		var troop := _add_troop(army, cls)
		campaign._record("recruit_troop", {"id": troop["id"], "cls": cls, "cost": 0})


# ================================================================ 战役指令

static func prepare(campaign, args: Dictionary) -> Dictionary:
	if not args.is_empty():
		return _fail("bad_args")
	var rogue: Dictionary = campaign.state["rogue"]
	if bool(rogue["big_fate"].get("pending", false)):
		return _fail("big_fate_pending")
	if is_book(campaign):
		return _prepare_book(campaign)
	var scene_id := str(campaign.scene().get("id", ""))
	var b2: Dictionary = rogue["battle2"]
	match str(b2["phase"]):
		"active":
			return _fail("battle_active")
		"lineup":
			if str(b2["scene"]) == scene_id:
				return _ok()
		"finished":
			if str(b2["scene"]) == scene_id:
				return _fail("already_complete")
	var lib := BattleRules.load_templates()
	var row = lib.get("scene_map", {}).get(scene_id)
	if typeof(row) != TYPE_DICTIONARY:
		return _fail("no_battle")
	var tpl_id := str(row["template"])
	var act := int(row["act"])
	var probe := BattleRules.new_battle(tpl_id, {"seed": battle_seed(campaign, scene_id), "act": act, "protagonist": {"enabled": true}})
	if probe.has("error"):
		return _fail("battle_error")
	rogue["battle2"] = {"phase": "lineup", "scene": scene_id, "template": tpl_id, "scale": str(probe["scale"]), "act": act,
		"revealed": false, "hunters": _count_hunters(probe), "lineup": {}, "state": {}, "result": {}}
	return _ok()


## 多段书：这一仗是谁（WORLD_MAP_DESIGN §6.6）。地图上：先看没打完的遭遇（节点 / 对手 / 事件抉择），再看脚下的战斗节点，
## 最后是站在当前场景锚点上的场景战斗；没有地图的段就是当前场景的场景战斗。
## {key, kind:"scene"|"node", template, level, weather:[…], node, reward, rival, order_flag, mods_when}；没有仗返回 {}
static func battle_context(campaign) -> Dictionary:
	var scene_id := str(campaign.scene().get("id", ""))
	if MapRules.enabled(campaign):
		var map: Dictionary = campaign.state["map"]
		var enc: Dictionary = map.get("encounter", {})
		var node := MapRules.node_of(MapRules.sheet(campaign), str(map["pos"]))
		if enc.is_empty() and not node.is_empty() and str(node.get("scene", "")) == "" and not str(node["id"]) in map["done"] \
				and MapRules.node_kind(campaign, node) in MapRules.BATTLE_TYPES:
			enc = MapRules.encounter_for_node(campaign, node)
			map["encounter"] = enc
		if not enc.is_empty():
			var out: Dictionary = enc.duplicate(true)
			out["kind"] = "node"
			out["node_kind"] = str(enc.get("kind", "battle"))
			return out
		if str(node.get("scene", "")) != scene_id:
			return {}
	var sb: Dictionary = campaign.scene_battle(scene_id)
	if sb.is_empty():
		return {}
	var anchor := MapRules.anchor_of(campaign, scene_id) if MapRules.enabled(campaign) else ""
	var node_kind := str(MapRules.node_of(MapRules.sheet(campaign), anchor).get("type", "battle")) if anchor != "" else "battle"
	return {"key": scene_id, "kind": "scene", "node_kind": node_kind, "template": str(sb["template"]), "level": int(sb["level"]),
		"weather": (sb.get("weather", []) as Array).duplicate() if typeof(sb.get("weather", [])) == TYPE_ARRAY else [str(sb["weather"])],
		"node": anchor, "reward": {}, "rival": "", "order_flag": str(sb.get("order_flag", "")),
		"mods_when": (sb.get("mods_when", []) as Array).duplicate(true)}


static func _prepare_book(campaign) -> Dictionary:
	var rogue: Dictionary = campaign.state["rogue"]
	var b2: Dictionary = rogue["battle2"]
	if str(b2["phase"]) == "active":
		return _fail("battle_active")
	var ctx := battle_context(campaign)
	if ctx.is_empty():
		return _fail("no_battle")
	var key := str(ctx["key"])
	if str(b2["phase"]) == "lineup" and str(b2.get("key", "")) == key:
		return _ok()
	# A surviving patrol may meet the player again after a loss or withdrawal.
	# Its new encounter is valid even though the previous battle used the same patrol key.
	var completed_node := str(b2["phase"]) == "finished" and str(b2.get("key", "")) == key and str(ctx.get("rival", "")) == ""
	if completed_node or (str(ctx["kind"]) == "scene" and campaign._used("battle:" + key)):
		return _fail("already_complete")
	var tpl_id := str(ctx["template"])
	var level := clampi(int(ctx["level"]), 1, 24)
	var seed_v := seed_for(int(campaign.state.get("seed", 1)), key)
	var options: Array = ctx.get("weather", [])
	if options.is_empty():
		options = BattleApi.weather_options(tpl_id)
	var weather := BattleApi.pick_weather(options, seed_for(int(campaign.state.get("seed", 1)), "weather|" + key))
	var mods := MapRules.battle_mods(campaign, str(ctx.get("node", "")), tpl_id)
	for mw in ctx.get("mods_when", []):
		if RunConditions.eval(campaign, mw.get("when", {})):
			_merge_mods(mods, mw.get("mods", {}))
	var probe := BattleApi.new_battle(tpl_id, {"seed": seed_v, "level": level, "act": BattleApi.act_of_level(level), "weather": weather,
		"protagonist": {"enabled": true}})
	if probe.has("error"):
		return _fail("battle_error")
	rogue["battle2"] = {"phase": "lineup", "scene": str(campaign.scene().get("id", "")), "template": tpl_id, "scale": str(probe["scale"]),
		"act": BattleApi.act_of_level(level), "revealed": false, "hunters": _count_hunters(probe), "lineup": {}, "state": {}, "result": {},
		"key": key, "kind": str(ctx["kind"]), "node_kind": str(ctx.get("node_kind", "battle")), "level": level, "weather": weather, "mods": mods,
		"node": str(ctx.get("node", "")), "order_flag": str(ctx.get("order_flag", ""))}
	return _ok()


static func _merge_mods(into: Dictionary, add: Dictionary) -> void:
	for k in add:
		match str(k):
			"cp_bonus", "enemy_morale", "prep_turn":
				into[k] = int(into.get(k, 0)) + int(add[k])
			"drop_waves", "terrain":
				var arr: Array = (into.get(k, []) as Array).duplicate()
				arr.append_array(add[k])
				into[k] = arr


## 花 1 枚情报币，在出征名单上揭开本场猎官数
static func reveal(campaign, args: Dictionary) -> Dictionary:
	if not args.is_empty():
		return _fail("bad_args")
	var rogue: Dictionary = campaign.state["rogue"]
	var b2: Dictionary = rogue["battle2"]
	if str(b2["phase"]) != "lineup":
		return _fail("bad_phase")
	if bool(b2["revealed"]):
		return _fail("already_used")
	if int(rogue["coins"].get("intel", 0)) < 1:
		return _fail("insufficient_funds")
	rogue["coins"]["intel"] = int(rogue["coins"]["intel"]) - 1
	b2["revealed"] = true
	return _ok()


static func begin(campaign, args: Dictionary) -> Dictionary:
	if args.size() != 3 or typeof(args.get("companions")) != TYPE_ARRAY or typeof(args.get("troops")) != TYPE_ARRAY \
			or typeof(args.get("protagonist")) != TYPE_BOOL:
		return _fail("bad_args")
	var rogue: Dictionary = campaign.state["rogue"]
	var b2: Dictionary = rogue["battle2"]
	var scene_id := str(campaign.scene().get("id", ""))
	if str(b2["phase"]) != "lineup" or str(b2["scene"]) != scene_id:
		return _fail("bad_phase")
	if is_book(campaign) and battle_context(campaign).get("key", "") != b2.get("key", ""):
		return _fail("bad_phase")
	if bool(rogue["big_fate"].get("pending", false)):
		return _fail("big_fate_pending")
	var roster: Dictionary = roster_of(campaign)
	var picked: Array = []
	for c_id in args["companions"]:
		if typeof(c_id) != TYPE_STRING or not str(c_id) in roster["ids"] or str(c_id) in picked:
			return _fail("bad_args")
		picked.append(str(c_id))
	var army: Dictionary = rogue["army"]
	var by_id := {}
	for t in army["troops"]:
		by_id[str(t["id"])] = t
	var troop_ids: Array = []
	for t_id in args["troops"]:
		if typeof(t_id) != TYPE_STRING or not by_id.has(str(t_id)) or str(t_id) in troop_ids:
			return _fail("bad_args")
		troop_ids.append(str(t_id))
	for c_id in picked:
		var comp: Dictionary = rogue["companions"][c_id]
		if not bool(comp.get("alive", false)):
			return _fail("companion_fallen")
		if not bool(comp.get("recruited", false)):
			return _fail("missing_companion")
		if bool(comp.get("captured", false)):
			return _fail("companion_captured")
	var companion_error := CompanionRules.lineup_error(campaign, picked)
	if companion_error != "":
		return _fail(companion_error)
	var hero := bool(args["protagonist"])
	if hero and bool(army.get("hero_wounded", false)):
		return _fail("protagonist_wounded")
	var book: bool = is_book(campaign)
	var level := int(b2.get("level", 2 * int(b2["act"]) - 1))
	var caps := caps_for(str(b2["scale"]), int(b2["act"])) if not book else BattleApi.caps(str(b2["scale"]), level)
	if picked.size() > int(caps["companions"]):
		return _fail("over_companion_cap")
	if picked.size() + troop_ids.size() + (1 if hero else 0) > int(caps["field"]):
		return _fail("over_field_cap")
	var units: Array = []
	for c_id in picked:
		var prof := effective_profile(campaign, str(c_id))
		var spec: Dictionary = roster["specs"][c_id]
		var row := {"id": c_id, "name": str(prof.get("short", spec["name"])), "cls": str(prof["cls"]),
			"max_hp": int(prof["hp"]), "atk": int(prof["atk"]), "def": int(prof["def"]), "block": int(prof["block"]),
			"cost": int(prof["cost"]), "skill": str(prof["skill"]), "tags": (spec["bonds"] as Array).duplicate(),
			"scarred": bool(rogue["companions"][c_id].get("scarred", false)), "fated": is_fated(campaign, prof, b2)}
		var from_turn := available_from(campaign, prof, b2)
		if book and from_turn > 0:
			row["from_turn"] = from_turn
		units.append(row)
	var troops: Array = []
	for t_id in troop_ids:
		var t: Dictionary = by_id[t_id]
		troops.append({"id": t_id, "cls": str(t["cls"]), "name": troop_name(t)})
	var hp := hero_hp(int(b2["act"])) if not book else hero_hp_level(campaign, level)
	var hd := hero_profile(campaign)
	var setup := {
		"seed": battle_seed(campaign, str(b2.get("key", scene_id))), "act": int(b2["act"]), "roster": units, "troops": troops,
		"protagonist": {"enabled": hero, "name": str(hd.get("name", HERO)), "hp": hp, "max_hp": hp, "tags": (hd.get("tags", []) as Array).duplicate()},
		"bond_set": bond_set_id(campaign), "bonds_trust": (army["trust"] as Dictionary).duplicate(true),
		"morale": opening_morale(campaign),
	}
	if book:
		setup["level"] = level
		setup["volume"] = int(campaign.book.get("volume", 1))
		setup["weather"] = str(b2.get("weather", "clear"))
		var mods: Dictionary = (b2.get("mods", {}) as Dictionary).duplicate(true)
		var opening := int(mods.get("_cp_early", 0))
		if opening > 0 and MapRules.enabled(campaign):
			campaign.state["map"]["cp_early"] = 0
		mods.erase("_cp_early")
		# 军需券：每 2 张在出征时折成开场军令点 +1，最多 +4（§7.3）；早到奖励也算开场军令点
		var ration := ration_cp(rogue)
		if ration > 0:
			_add_coin(rogue, "supply", -2 * ration)
		if opening + ration > 0:
			setup["cp_bonus"] = opening + ration
		setup["mods"] = mods
	CompanionRules.apply_battle_setup(campaign, setup, picked, hero)
	var st := BattleApi.new_battle(str(b2["template"]), setup) if book else BattleRules.new_battle(str(b2["template"]), setup)
	if st.has("error"):
		return _fail("battle_error")
	b2["phase"] = "active"
	b2["state"] = st
	b2["lineup"] = {"companions": picked, "troops": troop_ids, "protagonist": hero}
	return _ok()


static func command(campaign, args: Dictionary) -> Dictionary:
	for k in args:
		if not str(k) in ["cmd", "args"]:
			return _fail("bad_args")
	if typeof(args.get("cmd")) != TYPE_STRING or typeof(args.get("args", {})) != TYPE_DICTIONARY:
		return _fail("bad_args")
	var b2: Dictionary = campaign.state["rogue"]["battle2"]
	if str(b2["phase"]) != "active":
		return _fail("bad_phase")
	var res: Dictionary = BattleRules.apply(b2["state"], str(args["cmd"]), (args.get("args", {}) as Dictionary).duplicate(true))
	if not bool(res.get("ok", false)):
		return _fail(str(res.get("err", "bad_cmd")))
	return {"ok": true, "err": "", "over": str(b2["state"].get("phase", "")) == "over"}


static func finish(campaign, args: Dictionary) -> Dictionary:
	if not args.is_empty():
		return _fail("bad_args")
	var rogue: Dictionary = campaign.state["rogue"]
	var b2: Dictionary = rogue["battle2"]
	if str(b2["phase"]) != "active":
		return _fail("bad_phase")
	var st: Dictionary = b2["state"]
	if str(st.get("phase", "")) != "over":
		return _fail("battle_not_over")
	var res := BattleRules.result(st)
	var army: Dictionary = rogue["army"]
	var comps: Dictionary = rogue["companions"]
	var outcome := str(res["outcome"])
	# 奖赏：法郎按本部币制换进金库，金币和勋章进功能币
	var currency := str(campaign.chapter().get("currency", ""))
	var book: bool = is_book(campaign)
	var francs := int(res["rewards"]["franc"])
	var medal := int(res["rewards"]["medal"])
	if book:
		# 奖赏只在战役层按等级缩放（§8.1）：法郎 × (100 + 4·(L−1))/100；分支段 L ≥ 13 的 Boss 勋章 +1
		var level := int(b2.get("level", 1))
		francs = francs * (100 + int(campaign.book.get("raw", {}).get("reward_pct_per_level", 4)) * (level - 1)) / 100
		var seg_kind := str(campaign.book.get("raw", {}).get("segments", {}).get(str(campaign.state.get("segment", "")), {}).get("kind", ""))
		if outcome == "victory" and level >= 13 and str(b2.get("node_kind", "")) == "boss" and seg_kind == "branch":
			medal += 1
		if outcome in ["victory", "defeat"]:
			francs += CompanionRules.reserve_bonus(campaign, "battle_franc")
	var treasury := franc_to_treasury(currency, francs)
	if treasury > 0:
		campaign._apply_effects({"treasury": treasury})
	var gold := int(res["rewards"]["gold"])
	_add_coin(rogue, "gold", gold)
	_add_coin(rogue, "medal", medal)
	# 伙伴：伤痕、阵亡（一条命）、被俘
	var died: Array = []
	var scarred: Array = []
	var captured: Array = []
	var hero_state := "field" if bool(res["protagonist_on_field_at_end"]) else ("withdrew" if bool(res["protagonist_withdrew"]) else "absent")
	if not bool(b2["lineup"].get("protagonist", false)):
		hero_state = "absent"
	var hero_died := false
	var hero_wounded := false
	for f in res["fallen"]:
		var uid := str(f["unit"])
		if uid == HERO:
			if bool(f["died"]):
				hero_died = true
				hero_state = "died"
			else:
				hero_wounded = true
				hero_state = "wounded"
			continue
		if not comps.has(uid):
			continue
		var comp: Dictionary = comps[uid]
		if bool(f["died"]):
			comp["alive"] = false
			comp["hp"] = 0
			if not uid in rogue["fallen_companions"]:
				rogue["fallen_companions"].append(uid)
			_break_trust(army, uid)
			died.append(uid)
			campaign._record("companion_fallen", {"id": uid, "reason": "battle"})
		elif bool(f["captured"]):
			comp["captured"] = true
			captured.append(uid)
		elif bool(f["scar"]):
			var base := int((effective_profile(campaign, uid) if CompanionRules.enabled(campaign) else profile(uid)).get("hp", 10))
			comp["scarred"] = true
			comp["b_max_hp"] = base - base / 4
			scarred.append(uid)
	if HERO in res["captured"]:
		hero_state = "captured"
	army["hero_wounded"] = hero_wounded
	# 信赖：主角打完仍在场、打赢了，同场活下来的伙伴和他的信赖 +1（最多 3）
	for uid in res["trust_up"]:
		var key := "%s|%s" % [HERO, str(uid)]
		army["trust"][key] = mini(3, int(army["trust"].get(key, 0)) + 1)
	CompanionRules.after_battle(campaign, st, res)
	# 部队：本场溃散过 −1 格编制，到 0 解散
	var kept: Array = []
	for t in army["troops"]:
		if str(t["id"]) in res["routed"]:
			t["strength"] = int(t["strength"]) - 1
		if int(t["strength"]) > 0:
			kept.append(t)
		else:
			campaign._record("troop_disbanded", {"id": str(t["id"]), "cls": str(t["cls"])})
	army["troops"] = kept
	campaign._record("battle2", {"template": str(b2["template"]), "battle": str(st.get("name", "")), "outcome": outcome,
		"kind": str(res["victory_kind"]), "stars": int(res["stars"]), "francs": francs, "treasury": treasury, "currency": currency,
		"gold": gold, "medal": medal, "died": died, "scarred": scarred, "captured": captured, "protagonist": hero_state})
	b2["phase"] = "finished"
	b2["result"] = res
	var stats: Dictionary = campaign.state.get("run", {}).get("stats", {})
	if not stats.is_empty():
		stats["battles"] = int(stats.get("battles", 0)) + 1
		if outcome == "victory":
			stats["wins"] = int(stats.get("wins", 0)) + 1
			if str(b2.get("node_kind", "")) == "boss":
				stats["boss_wins"] = int(stats.get("boss_wins", 0)) + 1
	if book:
		_battle_flags(campaign, b2, res)
	if hero_died:
		campaign._finish("obituary", "protagonist_killed")
		return _ok()
	if outcome == "defeat":
		rogue["big_fate"]["pending"] = true
		rogue["big_fate"]["trigger"] = "protagonist_captured" if hero_state == "captured" else "battle_lost"
	elif book:
		_settle(campaign, b2, outcome)
	return _ok()


## 出征时军需券折成的开场军令点（每 2 张 +1，最多 +4）
static func ration_cp(rogue: Dictionary) -> int:
	return mini(4, int(rogue.get("coins", {}).get("supply", 0)) / 2)


## 多段书：命令完成 → order_flag；打死某种敌人 → 模板的 kill_flags（§6.6；result.killed_kinds 由 B1 提供）
static func _battle_flags(campaign, b2: Dictionary, res: Dictionary) -> void:
	var flag := str(b2.get("order_flag", ""))
	if flag != "" and bool(res.get("order_done", false)):
		campaign.state["flags"][flag] = true
	var kf: Dictionary = lib().get("templates", {}).get(str(b2.get("template", "")), {}).get("kill_flags", {})
	var killed: Dictionary = res.get("killed_kinds", {}) if typeof(res.get("killed_kinds")) == TYPE_DICTIONARY else {}
	for kind in kf:
		if int(killed.get(kind, 0)) > 0:
			campaign.state["flags"][str(kf[kind])] = true


## 一仗了结（打赢、撤出；打输则等大命运处理完）：场景战斗记进本场的使用记录，地图战斗交给 MapRules
static func _settle(campaign, b2: Dictionary, outcome: String) -> void:
	if str(b2.get("kind", "")) == "scene":
		if not campaign._used("battle:" + str(b2.get("key", ""))):
			campaign._use("battle:" + str(b2.get("key", "")))
	elif MapRules.enabled(campaign):
		var enc: Dictionary = (campaign.state["map"].get("encounter", {}) as Dictionary).duplicate(true)
		if enc.is_empty():
			enc = {"key": str(b2.get("key", "")), "node": str(b2.get("node", "")), "rival": ""}
		MapRules.battle_settled(campaign, enc, outcome)


## 大命运处理完以后（ocean_rogue_rules._big_fate 调用）：打输的那一仗也算了结
static func fate_settled(campaign) -> void:
	if not is_book(campaign):
		return
	var b2: Dictionary = campaign.state["rogue"]["battle2"]
	if str(b2.get("phase", "")) == "finished":
		_settle(campaign, b2, str(b2.get("result", {}).get("outcome", "defeat")))


## 功能币：和 ocean_rogue_rules._add_coin 一样（挣到的同时记进 rogue.tally）
static func _add_coin(rogue: Dictionary, coin_id: String, delta: int) -> void:
	rogue["coins"][coin_id] = clampi(int(rogue["coins"].get(coin_id, 0)) + delta, 0, 999)
	if delta > 0 and typeof(rogue.get("tally")) == TYPE_DICTIONARY:
		rogue["tally"][coin_id] = int(rogue["tally"].get(coin_id, 0)) + delta


# ================================================================ 查询

## campaign 查询里的 battle2：阶段、出征名单（备战时）、战场视图（开战后）、战果（打完就有；结算前后一样，
## 铜钱由种子定，打完之后谁也改不了）、本场的仗算不算已了结（剧情决定看它，见 resolved）
static func query(campaign) -> Dictionary:
	var rogue: Dictionary = campaign.state.get("rogue", {})
	var b2: Dictionary = rogue.get("battle2", new_battle2())
	var phase := str(b2.get("phase", "none"))
	var st: Dictionary = b2.get("state", {})
	var over := str(st.get("phase", "")) == "over"
	var out := {"phase": phase, "scene": str(b2.get("scene", "")), "template": str(b2.get("template", "")),
		"scale": str(b2.get("scale", "")), "act": int(b2.get("act", 1)), "over": over,
		"lineup": {}, "view": {}, "result": {}, "payout": {},
		"resolved": resolved(campaign), "has_battle": has_battle(campaign), "panel": card_panel(campaign)}
	if phase == "lineup":
		out["lineup"] = lineup(campaign)
	if not st.is_empty():
		out["view"] = public(BattleRules.view(st))
	if phase == "finished" or (phase == "active" and over):
		var res: Dictionary = b2.get("result", {}) if phase == "finished" else BattleRules.result(st)
		out["result"] = public(res)
		var currency := str(campaign.chapter().get("currency", ""))
		out["payout"] = {"treasury": franc_to_treasury(currency, int(res.get("rewards", {}).get("franc", 0))),
			"currency_name": str(campaign.chapter().get("currency_name", currency)), "finished": phase == "finished"}
	return out


## 当前这一场有没有仗（单段书：scene_map 里有它；多段书：书的 scene_battles，空模板 = 没有）
static func has_battle(campaign) -> bool:
	if not is_book(campaign):
		return lib().get("scene_map", {}).has(str(campaign.scene().get("id", "")))
	return not campaign.scene_battle(str(campaign.scene().get("id", ""))).is_empty()


## 本场的仗了结了没有：没有仗；或者结算过了（打赢、撤出、打输）并且大命运也处理完了。
## 推进剧情的决定（ocean_campaign._choice_error）要等它。撤出随时可以按，大命运总有一项选得了，所以卡不死。
static func resolved(campaign) -> bool:
	if not has_battle(campaign):
		return true
	var rogue: Dictionary = campaign.state.get("rogue", {})
	if bool(rogue.get("big_fate", {}).get("pending", false)):
		return false
	var b2: Dictionary = rogue.get("battle2", {})
	if is_book(campaign):
		var scene_id := str(campaign.scene().get("id", ""))
		return campaign._used("battle:" + scene_id) or (str(b2.get("phase", "")) == "finished" and str(b2.get("key", "")) == scene_id)
	return str(b2.get("phase", "")) == "finished" and str(b2.get("scene", "")) == str(campaign.scene().get("id", ""))


## 手里那张「战场」牌打出去开哪块面板：出征名单 / 战场 / 战果
static func card_panel(campaign) -> String:
	var b2: Dictionary = campaign.state.get("rogue", {}).get("battle2", {})
	var scene_id := str(campaign.scene().get("id", ""))
	var phase := str(b2.get("phase", "none"))
	if phase == "active":
		return "battle_result" if str(b2.get("state", {}).get("phase", "")) == "over" else "battle_v2"
	if phase == "finished" and str(b2.get("scene", "")) == scene_id:
		return "battle_result"
	return "battle_lineup"


## 悬停预演（本回合交火后）；args 带 {cmd, args} 时是指令预演（先下这条指令、不交火，界面选骠骑兵朝向时画冲锋）
static func preview(campaign, args: Dictionary = {}) -> Dictionary:
	var b2: Dictionary = campaign.state.get("rogue", {}).get("battle2", {})
	if str(b2.get("phase", "")) != "active":
		return {"ok": false, "err": "no_battle"}
	if args.has("cmd"):
		if typeof(args.get("cmd")) != TYPE_STRING or typeof(args.get("args", {})) != TYPE_DICTIONARY:
			return {"ok": false, "err": "bad_args"}
		return public(BattleRules.preview_cmd(b2["state"], str(args["cmd"]), args.get("args", {})))
	return public(BattleRules.preview(b2["state"]))


## 合同 §7.5：查询结果里递归都不许出现隐藏键黑名单（CardViewModel.FORBIDDEN_KEYS）。
## 规则内核的视图和预演里有 units、tags 这两个键，交出去之前统一加前缀 battle_
## （units → battle_units，tags → battle_tags），其余原样；内容和 BattleRules.view / preview 一模一样。
static func public(v):
	match typeof(v):
		TYPE_DICTIONARY:
			var out: Dictionary = {}
			for k in v.keys():
				out[("battle_" + str(k)) if CardViewModel.FORBIDDEN_KEYS.has(str(k)) else k] = public(v[k])
			return out
		TYPE_ARRAY:
			var arr: Array = []
			for x in v:
				arr.append(public(x))
			return arr
	return v


static func lineup(campaign) -> Dictionary:
	var rogue: Dictionary = campaign.state["rogue"]
	var b2: Dictionary = rogue["battle2"]
	var roster: Dictionary = roster_of(campaign)
	var book: bool = is_book(campaign)
	var cands: Array = []
	for c_id in roster["ids"]:
		var comp: Dictionary = rogue["companions"].get(c_id, {})
		if not bool(comp.get("recruited", false)) or not bool(comp.get("alive", false)) or bool(comp.get("captured", false)):
			continue
		if CompanionRules.deployment_error(campaign, str(c_id)) != "":
			continue
		var prof := effective_profile(campaign, str(c_id))
		var fated := is_fated(campaign, prof, b2)
		var scar := bool(comp.get("scarred", false))
		var base := int(prof.get("hp", 10))
		var hp := base - base / 4 if (scar or fated) else base
		# 倒下没被抬下（撑过下一次敌方阶段）、仗打赢时的阵亡率；被抬下时的阵亡率（没伤痕又不在宿命之地 = 只留伤痕）
		var coins := 3 - (2 if fated else 0)
		var cand := {"id": c_id, "name": str(roster["specs"][c_id]["name"]), "short": str(prof.get("short", c_id)),
			"role": str(prof.get("role", "")), "cls": str(prof.get("cls", "")), "hp": hp, "max_hp": hp,
			"atk": int(prof.get("atk", 0)), "def": int(prof.get("def", 0)), "block": int(prof.get("block", 0)), "cost": int(prof.get("cost", 0)),
			"skill": str(prof.get("skill", "")), "skill_title": str(prof.get("skill_title", "")),
			"scarred": scar, "fated": fated, "death_pct": 100 >> coins,
			"carried_pct": (100 >> (coins + 1)) if (scar or fated) else 0,
			"bonds": (roster["specs"][c_id]["bonds"] as Array).duplicate()}
		if book:
			cand["from_turn"] = available_from(campaign, prof, b2)
		cands.append(cand)
	var troops: Array = []
	for t in rogue["army"]["troops"]:
		troops.append({"id": str(t["id"]), "cls": str(t["cls"]), "name": troop_name(t), "strength": int(t["strength"])})
	var hd := hero_profile(campaign)
	var coins_h := int(hd.get("coins", 2))
	var tpl: Dictionary = lib().get("templates", {}).get(str(b2.get("template", "")), {})
	var act := clampi(int(b2.get("act", 1)), 1, 6)
	var sc: Dictionary = BattleRules.SCALES.get(str(b2.get("scale", "")), BattleRules.SCALES["skirmish"])
	if book:
		return _lineup_book(campaign, b2, tpl, sc, cands, troops, hd, coins_h)
	return {
		"battle_name": str(tpl.get("name", b2.get("template", ""))), "scale_name": str(sc["name"]), "act": act,
		"turn_limit": int(tpl.get("turn_limit", 0)),
		"enemy_morale": maxi(1, int(tpl.get("enemy_morale", 1)) * int(BattleRules.ACT_MORALE_PCT[act - 1]) / 100),
		"order": str(tpl.get("order", {}).get("desc", "")),
		"candidates": cands,
		"troops": troops,
		"protagonist": {"hp": hero_hp(int(b2.get("act", 1))), "death_pct": 100 >> coins_h,
			"hunters": int(b2.get("hunters", 0)) if bool(b2.get("revealed", false)) else -1,
			"available": not bool(rogue["army"].get("hero_wounded", false)), "bonds": (hd.get("tags", []) as Array).duplicate()},
		"caps": caps_for(str(b2.get("scale", "")), int(b2.get("act", 1))),
		"bond_set": _bond_rows(),
		"revealed": bool(b2.get("revealed", false)),
		"intel": int(rogue.get("coins", {}).get("intel", 0)),
		"map": _lineup_map(campaign, str(b2.get("template", "")), act),
	}


## 多段书的出征名单：多了等级、星级、天时、推荐战力（§8.4），名额和主角兵力按等级
static func _lineup_book(campaign, b2: Dictionary, tpl: Dictionary, sc: Dictionary, cands: Array, troops: Array, hd: Dictionary, coins_h: int) -> Dictionary:
	var rogue: Dictionary = campaign.state["rogue"]
	var level := int(b2.get("level", 1))
	var r := BattleApi.row(level)
	var mods: Dictionary = b2.get("mods", {})
	var enemy_power := BattleApi.power(str(b2.get("template", "")), level, {"mods": mods})
	return {
		"battle_name": str(tpl.get("name", b2.get("template", ""))), "scale_name": str(sc["name"]), "act": int(b2.get("act", 1)),
		"level": level, "stars": BattleApi.stars(level), "weather": str(b2.get("weather", "clear")), "key": str(b2.get("key", "")),
		"turn_limit": int(tpl.get("turn_limit", 0)) + int(mods.get("prep_turn", 0)),
		"enemy_morale": maxi(1, int(tpl.get("enemy_morale", 1)) * int(r["morale_pct"]) / 100 + int(mods.get("enemy_morale", 0))),
		"power": enemy_power, "recommended": BattleApi.recommended_power(str(b2.get("template", "")), level, {"mods": mods}),
		"cp_opening": int(mods.get("_cp_early", 0)) + ration_cp(rogue), "cp_council": int(mods.get("cp_bonus", 0)),
		"order": str(BattleRules.selected_order(tpl, int(campaign.book.get("volume", 1))).get("desc", "")),
		"candidates": cands,
		"troops": troops,
		"protagonist": {"hp": hero_hp_level(campaign, level), "death_pct": 100 >> coins_h,
			"hunters": int(b2.get("hunters", 0)) if bool(b2.get("revealed", false)) else -1,
			"available": not bool(rogue["army"].get("hero_wounded", false)), "bonds": (hd.get("tags", []) as Array).duplicate()},
		"caps": BattleApi.caps(str(b2.get("scale", "")), level),
		"bond_set": _bond_rows(bond_set_id(campaign)),
		"revealed": bool(b2.get("revealed", false)),
		"intel": int(rogue.get("coins", {}).get("intel", 0)),
		"map": _lineup_map(campaign, str(b2.get("template", "")), int(b2.get("act", 1))),
	}


## 伙伴在不在宿命之地：单段书看 fated_scene；多段书看 fated:[{seg, scene|template}]
static func is_fated(campaign, prof: Dictionary, b2: Dictionary) -> bool:
	if str(prof.get("fated_scene", "")) != "" and str(prof["fated_scene"]) == str(b2.get("scene", "")) and str(b2.get("kind", "scene")) == "scene":
		return true
	var seg := str(campaign.state.get("segment", ""))
	for f in prof.get("fated", []):
		if typeof(f) != TYPE_DICTIONARY or str(f.get("seg", seg)) != seg:
			continue
		if str(f.get("scene", "")) != "" and str(f["scene"]) == str(b2.get("key", "")):
			return true
		if str(f.get("template", "")) != "" and str(f["template"]) == str(b2.get("template", "")):
			return true
	return false


## available_from（C28）：{seg, template, turn} 对上本场时，最早第 turn 回合能部署；否则 0
static func available_from(campaign, prof: Dictionary, b2: Dictionary) -> int:
	var af = prof.get("available_from", {})
	if typeof(af) != TYPE_DICTIONARY or (af as Dictionary).is_empty():
		return 0
	if str(af.get("seg", "")) == str(campaign.state.get("segment", "")) and str(af.get("template", "")) == str(b2.get("template", "")):
		return int(af.get("turn", 0))
	return 0


## 出征名单上的战场预览：地形、敌人的路线、开场就在格子上的敌人（只给兵种，不给标签，揭开猎官另算）
static func _lineup_map(campaign, tpl_id: String, act: int) -> Dictionary:
	var b2: Dictionary = campaign.state["rogue"]["battle2"]
	var st := BattleRules.new_battle(tpl_id, {"seed": battle_seed(campaign, str(b2.get("scene", ""))), "act": act}) if not is_book(campaign) \
		else BattleApi.new_battle(tpl_id, {"seed": battle_seed(campaign, str(b2.get("key", ""))), "act": act, "level": int(b2.get("level", 1)),
			"weather": str(b2.get("weather", "clear"))})
	if st.has("error"):
		return {}
	var routes: Array = []
	for rid in st["route_ids"]:
		routes.append((st["routes"][rid] as Array).duplicate(true))
	var foes: Array = []
	for e in st["enemies"]:
		foes.append({"col": int(e["col"]), "row": int(e["row"]), "kind": str(e["kind"])})
	return {"cols": int(st["cols"]), "rows": int(st["rows"]), "terrain": (st["terrain"] as Array).duplicate(), "routes": routes, "foes": foes}


static func army_query(rogue: Dictionary, roster_ids: Array = Data.COMPANION_IDS, profiles: Dictionary = {}) -> Dictionary:
	var army: Dictionary = rogue.get("army", {})
	var troops: Array = []
	for t in army.get("troops", []):
		troops.append({"id": str(t["id"]), "cls": str(t["cls"]), "name": troop_name(t), "strength": int(t["strength"])})
	var comps: Array = []
	for c_id in roster_ids:
		var comp: Dictionary = rogue.get("companions", {}).get(c_id, {})
		var prof: Dictionary = profiles.get(c_id, profile(c_id))
		comps.append({"id": c_id, "cls": str(prof.get("cls", "")), "alive": bool(comp.get("alive", true)),
			"recruited": bool(comp.get("recruited", false)), "scarred": bool(comp.get("scarred", false)),
			"captured": bool(comp.get("captured", false)), "max_hp": int(comp.get("b_max_hp", prof.get("hp", 0)))})
	return {"troops": troops, "troop_cap": int(data().get("troop_cap", 8)), "companions": comps,
		"trust": (army.get("trust", {}) as Dictionary).duplicate(true), "hero_wounded": bool(army.get("hero_wounded", false))}


# ================================================================ 规则细节

## 战斗种子：战役种子 + 场景 id 的 FNV-1a（32 位），同一局同一场永远是同一场仗
static func battle_seed(campaign, scene_id: String) -> int:
	return seed_for(int(campaign.state.get("seed", 1)), scene_id)


static func seed_for(campaign_seed: int, scene_id: String) -> int:
	var key := "%d|%s" % [campaign_seed, scene_id]
	var h := 2166136261
	for i in range(key.length()):
		h = ((h ^ key.unicode_at(i)) * 16777619) & 0xFFFFFFFF
	return h


static func caps_for(scale: String, act: int) -> Dictionary:
	var sc: Dictionary = BattleRules.SCALES.get(scale, BattleRules.SCALES["skirmish"])
	var i := clampi(act, 1, 6) - 1
	return {"field": int(sc["field"][i]), "companions": int(sc["companions"][i])}


static func hero_hp(act: int) -> int:
	var hd: Dictionary = data().get("protagonist", {})
	return mini(int(hd.get("hp_max", 20)), int(hd.get("hp", 12)) + int(hd.get("hp_per_act", 2)) * (clampi(act, 1, 6) - 1))


## 主角兵力按等级（§8.1）：min(hero_hp_max, 12 + (L−1))；napoleon 书上限取 book.hero_hp_max（24），否则 ocean_battle.json 的 20
static func hero_hp_level(campaign, level: int) -> int:
	var hd: Dictionary = data().get("protagonist", {})
	var cap := int(campaign.book.get("raw", {}).get("hero_hp_max", hd.get("hp_max", 20)))
	return mini(cap, int(hd.get("hp", 12)) + (clampi(level, 1, 24) - 1))


## 开场军心：10；同盟威望（0–100）≥70 时 +1，≤30 时 −2（设计稿“棋盘军心 ≥7 +1、≤3 −2”按十分之一折算）
static func opening_morale(campaign) -> int:
	var m := int(campaign.state.get("metrics", {}).get("morale", 50)) / 10
	return 10 + (1 if m >= 7 else 0) - (2 if m <= 3 else 0)


## 法郎换成本部账本单位：法郎 × num / den，向下取整（data franc_rate）
static func franc_to_treasury(currency: String, francs: int) -> int:
	var rate: Array = data().get("franc_rate", {}).get(currency, [1, 1])
	return francs * int(rate[0]) / maxi(1, int(rate[1]))


static func troop_name(t: Dictionary) -> String:
	var spec: Dictionary = data().get("troops", {}).get(str(t["cls"]), {})
	var n := str(t["id"]).get_slice("_", str(t["id"]).get_slice_count("_") - 1)
	return text("troop_name").format({"name": str(spec.get("name", t["cls"])), "n": n})


static func _count_hunters(st: Dictionary) -> int:
	var n := 0
	for w in st.get("waves", []):
		for spec in w["units"]:
			var tags: Array = (BattleRules.ENEMIES[spec["kind"]]["tags"] as Array) + (spec["tags"] as Array)
			if "hunter" in tags:
				n += 1
	return n


static func bond_set_id(campaign) -> String:
	var fallback := str(data().get("bond_set", "ocean"))
	return str(campaign.book.get("raw", {}).get("bond_set", fallback)) if is_book(campaign) else fallback


static func hero_profile(campaign) -> Dictionary:
	var out: Dictionary = (data().get("protagonist", {}) as Dictionary).duplicate(true)
	if is_book(campaign):
		var spec: Dictionary = campaign.book.get("raw", {}).get("hero", {})
		var segment := str(campaign.state.get("segment", ""))
		out["tags"] = (spec.get("bonds_by_segment", {}).get(segment, spec.get("bonds", out.get("tags", []))) as Array).duplicate()
	return out


static func _bond_rows(set_id: String = "") -> Array:
	var out: Array = []
	var sets: Dictionary = lib().get("bond_sets", {})
	for entry in sets.get(set_id if set_id != "" else str(data().get("bond_set", "ocean")), []):
		if typeof(entry) == TYPE_STRING:
			var bd: Dictionary = BattleRules.BONDS.get(entry, {})
			out.append({"id": str(entry), "name": str(bd.get("name", entry)), "kind": str(bd.get("kind", "")),
				"cls": str(bd.get("cls", "")), "tag": str(bd.get("tag", "")), "tiers": (bd.get("tiers", []) as Array).duplicate(), "desc": str(bd.get("desc", ""))})
		elif typeof(entry) == TYPE_DICTIONARY:
			out.append({"id": str(entry["id"]), "name": str(entry.get("name", "")), "kind": str(entry.get("kind", "")),
				"cls": str(entry.get("cls", "")), "tag": str(entry.get("tag", "")), "tiers": (entry.get("tiers", []) as Array).duplicate(), "desc": str(entry.get("desc", ""))})
	return out


static func _break_trust(army: Dictionary, uid: String) -> void:
	var trust: Dictionary = army["trust"]
	for key in trust.keys():
		var parts := str(key).split("|")
		if uid in parts:
			trust.erase(key)


static func valid(rogue: Dictionary, roster_ids: Array = Data.COMPANION_IDS) -> bool:
	var army = rogue.get("army")
	if typeof(army) != TYPE_DICTIONARY or typeof(army.get("troops")) != TYPE_ARRAY or typeof(army.get("next_troop")) != TYPE_INT \
			or typeof(army.get("trust")) != TYPE_DICTIONARY or typeof(army.get("hero_wounded")) != TYPE_BOOL or typeof(army.get("chapter")) != TYPE_STRING:
		return false
	var ids := {}
	for t in army["troops"]:
		if typeof(t) != TYPE_DICTIONARY or typeof(t.get("id")) != TYPE_STRING or ids.has(t["id"]) or not str(t.get("cls", "")) in TROOP_CLASSES \
				or typeof(t.get("strength")) != TYPE_INT or int(t["strength"]) < 1:
			return false
		ids[t["id"]] = true
	for key in army["trust"]:
		if typeof(key) != TYPE_STRING or typeof(army["trust"][key]) != TYPE_INT:
			return false
	var b2 = rogue.get("battle2")
	if typeof(b2) != TYPE_DICTIONARY or not str(b2.get("phase", "")) in PHASES or typeof(b2.get("state")) != TYPE_DICTIONARY \
			or typeof(b2.get("result")) != TYPE_DICTIONARY or typeof(b2.get("lineup")) != TYPE_DICTIONARY or typeof(b2.get("revealed")) != TYPE_BOOL:
		return false
	if str(b2["phase"]) == "active" and BattleRules.load_state(b2["state"]).has("error"):
		return false
	for c_id in roster_ids:
		var comp = rogue.get("companions", {}).get(c_id)
		if typeof(comp) != TYPE_DICTIONARY or typeof(comp.get("scarred")) != TYPE_BOOL or typeof(comp.get("captured")) != TYPE_BOOL \
				or typeof(comp.get("b_max_hp")) != TYPE_INT:
			return false
	return true


static func _ints(v):
	match typeof(v):
		TYPE_FLOAT:
			return int(v)
		TYPE_ARRAY:
			var arr: Array = []
			for x in v:
				arr.append(_ints(x))
			return arr
		TYPE_DICTIONARY:
			var out: Dictionary = {}
			for k in v.keys():
				out[k] = _ints(v[k])
			return out
	return v


static func _ok() -> Dictionary:
	return {"ok": true, "err": ""}


static func _fail(err: String) -> Dictionary:
	return {"ok": false, "err": err}
