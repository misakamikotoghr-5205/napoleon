class_name OceanRogueRules
extends RefCounted
## Deterministic state & command handlers for the Napoleon Roguelike layer.
## Preserves integer-only serialization and atomic rollback via OceanCampaign.
## 名册（roster）：单段书就是 ocean_rogue_data.gd 的 8 人；多段书读书里的伙伴总表 companions.json（§11）。
## rogue.tally 记一辈子挣到的币（只加不减，_add_coin 在 delta > 0 时同步加），stat.medal_earned 从这里取。

const Data = preload("res://scripts/cards/campaign/ocean_rogue_data.gd")
const Battle2 = preload("res://scripts/cards/campaign/ocean_battle2.gd")
const BattleRules = preload("res://scripts/cards/campaign/battle/battle_rules.gd")
const RunConditions = preload("res://scripts/cards/campaign/run/run_conditions.gd")
const MapRules = preload("res://scripts/cards/campaign/map/map_rules.gd")
const CompanionRules = preload("res://scripts/cards/campaign/companion_rules.gd")

const REQ_KEYS := ["coins", "props", "companions", "fallen_companions", "march", "calendar", "battle", "big_fate", "army", "battle2", "tally"]


## 名册：{ids, specs:{id: 营地数值}, profiles:{id: 战斗数值}}
static func build_roster(campaign) -> Dictionary:
	var rows: Dictionary = campaign.book.get("companions", {})
	if campaign.is_builtin() or rows.is_empty():
		return {"ids": Data.COMPANION_IDS.duplicate(), "specs": Data.COMPANIONS, "profiles": Battle2.data().get("companions", {})}
	var ids: Array = []
	var specs := {}
	var profiles := {}
	var segment := str(campaign.state.get("segment", campaign.book.get("start", "")))
	for id in rows:
		var row: Dictionary = rows[id]
		var b: Dictionary = row.get("battle", {})
		var cls := str(b.get("cls", "line"))
		ids.append(str(id))
		specs[id] = {"id": str(id), "name": str(row.get("name", id)), "class_label": str(b.get("role", "")),
			"place": str(BattleRules.CLASSES.get(cls, {}).get("place", "ground")), "cost": int(b.get("cost", 3)),
			"gold_cost": int(row.get("gold", 2)), "atk": int(b.get("atk", 1)), "max_hp": int(b.get("hp", 10)), "block": int(b.get("block", 0)),
			"bonds": (row.get("bonds_by_segment", {}).get(segment, row.get("bonds", [])) as Array).duplicate(), "skill_name": str(b.get("skill_title", "")), "skill_desc": "", "starter": false,
			"segments": (row.get("segments", []) as Array).duplicate()}
		var prof: Dictionary = b.duplicate(true)
		prof["short"] = str(row.get("short", row.get("name", id)))
		prof["fated_scene"] = ""
		prof["fated"] = (row.get("fated", []) as Array).duplicate(true)
		prof["available_from"] = (row.get("available_from", {}) as Dictionary).duplicate(true)
		prof["fated_coins"] = int(row.get("fated_coins", -2))
		profiles[id] = prof
	return {"ids": ids, "specs": specs, "profiles": profiles}


static func fresh_march_calendar() -> Dictionary:
	return {
		"march": {"pos": 0, "laps": 0, "rolls": 0, "last_roll": 0, "last_tile": "camp", "route": "salon_route", "activities_done": []},
		"calendar": {"week": 1, "slot": 1, "max_slots": 3, "countdown": 3, "scheduled": []},
	}


static func create_initial_rogue(campaign, seed_val: int, chapter_id: String, scene_id: String) -> Dictionary:
	var roster: Dictionary = campaign.roster()
	var start: Dictionary = campaign.book.get("raw", {}).get("start_rogue", {}) if not campaign.is_builtin() else {}
	var starters: Array = start.get("companions", [])
	var companions := {}
	for id in roster["ids"]:
		var spec: Dictionary = roster["specs"][id]
		var recruited: bool = bool(spec.get("starter", false)) or id in starters
		companions[id] = {
			"id": id,
			"recruited": recruited,
			"alive": true,
			"level": 1,
			"hp": int(spec["max_hp"]),
			"max_hp": int(spec["max_hp"]),
			"atk": int(spec["atk"]),
			"block": int(spec["block"]),
			"place": str(spec["place"]),
		}
		Battle2.add_companion_fields(id, companions[id], int(roster["profiles"].get(id, {}).get("hp", 10)))
	var initial_props: Array = (start.get("props", ["prop_loaded_dice", "prop_field_ration", "prop_smoke_bomb"]) as Array).duplicate()
	if abs(seed_val) % 2 == 1:
		initial_props.append(str(start.get("odd_seed_prop", "prop_spyglass")))
	else:
		initial_props.append(str(start.get("even_seed_prop", "prop_barricade")))
	var fresh := fresh_march_calendar()
	var coins: Dictionary = {"gold": 4, "supply": 6, "medal": 2, "intel": 2}
	if typeof(start.get("coins")) == TYPE_DICTIONARY:
		for c in Data.COIN_IDS:
			coins[c] = int(start["coins"].get(c, coins[c]))
	var rogue := {
		"coins": coins,
		"props": initial_props,
		"companions": companions,
		"fallen_companions": [],
		"march": fresh["march"],
		"calendar": fresh["calendar"],
		# 场景记号：只剩 scene_id（Gemini 旧战术网格已拆，战斗都在 battle2；键名留着，旧存档照读）
		"battle": {},
		"big_fate": {
			"pending": false,
			"trigger": "",
			"resolved_count": 0,
			"history": [],
		},
		# 战斗规则 v2：部队名册、与主角的信赖、主角伤势（army）；出征名单与战斗状态（battle2）
		"army": Battle2.new_army(chapter_id, campaign.start_troops(chapter_id)),
		"battle2": Battle2.new_battle2(),
		"tally": {"gold": 0, "supply": 0, "medal": 0, "intel": 0},
	}
	rogue["battle"] = scene_mark(scene_id)
	return rogue


static func on_enter_scene(campaign) -> void:
	var state: Dictionary = campaign.state
	var current: Dictionary = campaign.scene()
	var scene_id := str(current.get("id", "prologue"))
	var chapter_id := str(current.get("chapter", "prologue"))
	if not state.has("rogue") or typeof(state["rogue"]) != TYPE_DICTIONARY or state["rogue"].is_empty():
		state["rogue"] = create_initial_rogue(campaign, int(state.get("seed", 1)), chapter_id, scene_id)
		return
	var rogue: Dictionary = state["rogue"]
	Battle2.on_enter_scene(rogue, scene_id, chapter_id, campaign.start_troops(chapter_id))
	# Heal living companions between scenes; fallen companions stay dead (permadeath).
	var comps: Dictionary = rogue.get("companions", {})
	for id in comps:
		var comp: Dictionary = comps[id]
		if bool(comp.get("alive", false)):
			comp["hp"] = int(comp.get("max_hp", 80))
	var battle: Dictionary = rogue.get("battle", {})
	if str(battle.get("scene_id", "")) != scene_id:
		rogue["battle"] = scene_mark(scene_id)
		var cal: Dictionary = rogue.get("calendar", {})
		cal["slot"] = 1
		cal["countdown"] = int(cal.get("max_slots", 3))
		cal["scheduled"] = []
		var march: Dictionary = rogue.get("march", {})
		march["activities_done"] = []
		_add_coin(rogue, "supply", 2)


## 每一场的记号：进新的一场时重置周历、行军小活动，补 2 张军需券（看 scene_id 变没变）
static func scene_mark(scene_id: String) -> Dictionary:
	return {"scene_id": scene_id}


static func active_bonds(rogue: Dictionary, campaign = null) -> Dictionary:
	if campaign != null and not campaign.is_builtin():
		var current := {}
		for row in _book_bond_counts(rogue, campaign):
			if bool(row["active"]):
				var active: Dictionary = row.duplicate(true)
				active.erase("active")
				current[str(row["id"])] = active
		return current
	var counts := {}
	for b_id in Data.BOND_IDS:
		counts[b_id] = 0
	var comps: Dictionary = rogue.get("companions", {})
	for c_id in Data.COMPANION_IDS:
		var row: Dictionary = comps.get(c_id, {})
		if bool(row.get("recruited", false)) and bool(row.get("alive", false)):
			var spec: Dictionary = Data.COMPANIONS.get(c_id, {})
			for b_id in spec.get("bonds", []):
				counts[b_id] = int(counts.get(b_id, 0)) + 1
	var active := {}
	for b_id in Data.BOND_IDS:
		var spec: Dictionary = Data.BONDS[b_id]
		if int(counts.get(b_id, 0)) >= int(spec.get("need", 2)):
			active[b_id] = {
				"id": b_id,
				"name": str(spec["name"]),
				"count": int(counts[b_id]),
				"need": int(spec["need"]),
				"desc": str(spec["desc"]),
			}
	return active


static func bond_counts(rogue: Dictionary, campaign = null) -> Array:
	if campaign != null and not campaign.is_builtin():
		return _book_bond_counts(rogue, campaign)
	var counts := {}
	for b_id in Data.BOND_IDS:
		counts[b_id] = 0
	var comps: Dictionary = rogue.get("companions", {})
	for c_id in Data.COMPANION_IDS:
		var row: Dictionary = comps.get(c_id, {})
		if bool(row.get("recruited", false)) and bool(row.get("alive", false)):
			var spec: Dictionary = Data.COMPANIONS.get(c_id, {})
			for b_id in spec.get("bonds", []):
				counts[b_id] = int(counts.get(b_id, 0)) + 1
	var out: Array = []
	for b_id in Data.BOND_IDS:
		var spec: Dictionary = Data.BONDS[b_id]
		var cnt := int(counts.get(b_id, 0))
		var need := int(spec.get("need", 2))
		out.append({
			"id": b_id,
			"name": str(spec["name"]),
			"count": cnt,
			"need": need,
			"active": cnt >= need,
			"desc": str(spec["desc"]),
		})
	return out


## Camp roster potential; battlefield bonds still use the actual deployment list.
static func _book_bond_counts(rogue: Dictionary, campaign) -> Array:
	var members: Array = []
	var roster: Dictionary = campaign.roster()
	for c_id in roster["ids"]:
		var row: Dictionary = rogue.get("companions", {}).get(c_id, {})
		if bool(row.get("recruited", false)) and bool(row.get("alive", false)) and CompanionRules.deployment_error(campaign, str(c_id)) == "":
			members.append({"tags": roster["specs"][c_id].get("bonds", []), "cls": roster["profiles"][c_id].get("cls", "")})
	var army: Dictionary = rogue.get("army", {})
	if not bool(army.get("hero_wounded", false)):
		var hero := Battle2.hero_profile(campaign)
		members.append({"tags": hero.get("tags", []), "cls": hero.get("cls", "")})
	for troop in army.get("troops", []):
		if int(troop.get("strength", 0)) > 0:
			members.append({"tags": [], "cls": troop.get("cls", "")})
	var out: Array = []
	for bond in Battle2._bond_rows(Battle2.bond_set_id(campaign)):
		var count := 0
		for member in members:
			if str(bond.get("kind", "")) == "class":
				if str(member.get("cls", "")) == str(bond.get("cls", "")):
					count += 1
			elif str(bond.get("tag", "")) in member.get("tags", []):
				count += 1
		var tiers: Array = bond.get("tiers", [])
		var need := int(tiers[0]) if not tiers.is_empty() else 2
		out.append({"id": str(bond["id"]), "name": str(bond["name"]), "count": count,
			"need": need, "active": count >= need, "desc": str(bond.get("desc", ""))})
	return out


static func handle(campaign, cmd: String, args: Dictionary) -> Dictionary:
	if str(campaign.state.get("phase", "")) != "day":
		return _fail("bad_phase")
	match cmd:
		"campaign.roll_dice": return _roll_dice(campaign, args)
		"campaign.pick_route": return _pick_route(campaign, args)
		"campaign.activity": return _activity(campaign, args)
		"campaign.schedule": return _schedule(campaign, args)
		"campaign.recruit": return _recruit(campaign, args)
		"campaign.promote": return _promote(campaign, args)
		"campaign.companion_duty": return CompanionRules.handle(campaign, args)
		"campaign.use_prop": return _use_prop(campaign, args)
		"campaign.big_fate": return _big_fate(campaign, args)
		"campaign.battle_prepare": return Battle2.prepare(campaign, args)
		"campaign.battle_reveal": return Battle2.reveal(campaign, args)
		"campaign.battle_begin": return Battle2.begin(campaign, args)
		"campaign.battle_cmd": return Battle2.command(campaign, args)
		"campaign.battle_finish": return Battle2.finish(campaign, args)
	return _fail("bad_args")


static func _roll_dice(campaign, args: Dictionary) -> Dictionary:
	for k in args:
		if k != "steps" or typeof(args[k]) != TYPE_INT:
			return _fail("bad_args")
	var rogue: Dictionary = campaign.state["rogue"]
	var march: Dictionary = rogue["march"]
	var steps := 0
	if args.has("steps"):
		steps = int(args["steps"])
		if steps < 1 or steps > 6:
			return _fail("bad_args")
		var props: Array = rogue["props"]
		if "prop_loaded_dice" in props:
			props.erase("prop_loaded_dice")
		elif int(rogue["coins"].get("intel", 0)) >= 1:
			_add_coin(rogue, "intel", -1)
		else:
			return _fail("missing_item")
	else:
		var seed_val := int(campaign.state.get("seed", 1))
		var day_val := int(campaign.state.get("day", 1))
		var rolls := int(march.get("rolls", 0))
		steps = 1 + (absi(seed_val * 31 + day_val * 17 + rolls * 13 + int(march.get("pos", 0)) * 7) % 6)
	var old_pos := int(march.get("pos", 0))
	var board_size := Data.MARCH_BOARD.size()
	var next_pos := (old_pos + steps) % board_size
	if old_pos + steps >= board_size:
		march["laps"] = int(march.get("laps", 0)) + 1
		_add_coin(rogue, "gold", 1)
		_add_coin(rogue, "supply", 2)
		campaign._apply_effects({"treasury": 150, "morale": 4})
	march["pos"] = next_pos
	march["rolls"] = int(march.get("rolls", 0)) + 1
	march["last_roll"] = steps
	var tile: Dictionary = Data.MARCH_BOARD[next_pos]
	var tile_id := str(tile["id"])
	march["last_tile"] = tile_id
	_apply_tile_effect(campaign, rogue, tile_id)
	campaign._record("march_roll", {"steps": steps, "tile": tile_id, "pos": next_pos})
	return {"ok": true, "err": "", "steps": steps, "tile": tile_id, "pos": next_pos}


static func _apply_tile_effect(campaign, rogue: Dictionary, tile_id: String) -> void:
	match tile_id:
		"camp":
			_add_coin(rogue, "supply", 2)
			campaign._apply_effects({"vitality": 4})
		"town":
			campaign._apply_effects({"treasury": 150, "vitality": 5})
		"recruit":
			_add_coin(rogue, "gold", 1)
			_add_coin(rogue, "supply", 1)
		"salon":
			_add_coin(rogue, "medal", 1)
			campaign._apply_effects({"morale": 6})
		"bazaar":
			_add_coin(rogue, "gold", 1)
			_grant_next_prop(rogue)
		"duel":
			_add_coin(rogue, "medal", 1)
			campaign._apply_effects({"morale": 5})
		"smuggle":
			_add_coin(rogue, "gold", 2)
			campaign._apply_effects({"treasury": 250, "heat": 5})
		"shrine":
			campaign._apply_effects({"morale": 8, "vitality": 6})
		"gamble":
			_add_coin(rogue, "gold", 1)
			_add_coin(rogue, "supply", 2)
		"festival":
			campaign._apply_effects({"vitality": 10, "heat": -6})
		"diplomacy":
			_add_coin(rogue, "intel", 2)
			campaign._apply_effects({"heat": -8})
		"skirmish":
			_add_coin(rogue, "supply", 2)
			_add_coin(rogue, "medal", 1)
			_add_coin(rogue, "intel", 1)


static func _pick_route(campaign, args: Dictionary) -> Dictionary:
	if args.size() != 1 or typeof(args.get("route")) != TYPE_STRING:
		return _fail("bad_args")
	var route := str(args["route"])
	if route not in Data.ROUTE_IDS:
		return _fail("bad_args")
	var action_key := "route:" + str(campaign.scene().get("id", ""))
	if campaign._used(action_key):
		return _fail("already_used")
	route_reward(campaign, route)
	campaign._use(action_key)
	campaign._record("pick_route", {"route": route})
	return _ok()


## 三条岔路的奖励（棋盘的 pick_route，地图上第一次踏上标了 route 的连线也给）
static func route_reward(campaign, route: String) -> void:
	var rogue: Dictionary = campaign.state["rogue"]
	rogue["march"]["route"] = route
	match route:
		"salon_route":
			_add_coin(rogue, "intel", 1)
			_add_coin(rogue, "medal", 1)
			campaign._apply_effects({"heat": -5, "morale": 4})
		"duel_route":
			_add_coin(rogue, "supply", 2)
			_add_coin(rogue, "medal", 1)
			campaign._apply_effects({"morale": 5})
		"smuggle_route":
			_add_coin(rogue, "gold", 2)
			_grant_next_prop(rogue)
			campaign._apply_effects({"treasury": 200})


static func _activity(campaign, args: Dictionary) -> Dictionary:
	if args.size() != 1 or typeof(args.get("id")) != TYPE_STRING:
		return _fail("bad_args")
	var act_id := str(args["id"])
	if act_id not in Data.ACTIVITY_IDS:
		return _fail("bad_args")
	var gate := MapRules.gate(campaign, "activity:" + act_id)
	if gate != "":
		return _fail(gate)
	var rogue: Dictionary = campaign.state["rogue"]
	var done: Array = rogue["march"]["activities_done"]
	if act_id in done:
		return _fail("already_used")
	match act_id:
		"salon":
			_add_coin(rogue, "medal", 1)
			_add_coin(rogue, "intel", 1)
			campaign._apply_effects({"morale": 6})
		"duel":
			if int(campaign.state["metrics"]["vitality"]) <= 5:
				return _fail("insufficient_vitality")
			_add_coin(rogue, "medal", 2)
			campaign._apply_effects({"morale": 5, "vitality": -4})
		"gamble":
			_add_coin(rogue, "gold", 2)
			campaign._apply_effects({"treasury": 200})
		"merchant":
			if int(rogue["coins"].get("gold", 0)) < 1:
				return _fail("insufficient_funds")
			_add_coin(rogue, "gold", -1)
			_add_coin(rogue, "supply", 2)
			_grant_next_prop(rogue)
		"rest":
			_add_coin(rogue, "supply", 2)
			campaign._apply_effects({"vitality": 12})
			_heal_all_companions(rogue, 25)
		"smuggle":
			_add_coin(rogue, "gold", 2)
			campaign._apply_effects({"treasury": 350, "heat": 6})
		"festival":
			campaign._apply_effects({"morale": 8, "vitality": 8, "heat": -6})
		"diplomacy":
			_add_coin(rogue, "intel", 2)
			campaign._apply_effects({"heat": -10})
	done.append(act_id)
	campaign._record("activity", {"id": act_id})
	return _ok()


static func _schedule(campaign, args: Dictionary) -> Dictionary:
	if args.size() != 1 or typeof(args.get("action")) != TYPE_STRING:
		return _fail("bad_args")
	var action := str(args["action"])
	if action not in Data.CALENDAR_IDS:
		return _fail("bad_args")
	var gate := MapRules.gate(campaign, "schedule:" + action)
	if gate != "":
		return _fail(gate)
	var rogue: Dictionary = campaign.state["rogue"]
	var cal: Dictionary = rogue["calendar"]
	var scheduled: Array = cal["scheduled"]
	if scheduled.size() >= int(cal.get("max_slots", 3)):
		return _fail("already_complete")
	match action:
		"recruit":
			_add_coin(rogue, "gold", 1)
			_add_coin(rogue, "supply", 2)
		"train":
			_add_coin(rogue, "medal", 1)
			_add_coin(rogue, "supply", 2)
			for c_id in rogue["companions"]:
				var comp: Dictionary = rogue["companions"][c_id]
				if bool(comp.get("recruited", false)) and bool(comp.get("alive", false)):
					comp["max_hp"] = int(comp["max_hp"]) + 10
					comp["hp"] = int(comp["max_hp"])
					comp["atk"] = int(comp["atk"]) + 2
					Battle2.sync_growth_display(campaign, comp)
		"bond_story":
			_add_coin(rogue, "medal", 1)
			campaign._apply_effects({"morale": 8, "vitality": 6})
		"diplomacy":
			_add_coin(rogue, "intel", 2)
			campaign._apply_effects({"heat": -8})
		"festival":
			campaign._apply_effects({"vitality": 10, "morale": 6})
			_grant_next_prop(rogue)
		"smuggle":
			_add_coin(rogue, "gold", 2)
			campaign._apply_effects({"treasury": 300, "heat": 5})
	scheduled.append(action)
	cal["slot"] = mini(int(cal.get("max_slots", 3)), scheduled.size() + 1)
	cal["countdown"] = maxi(0, int(cal.get("max_slots", 3)) - scheduled.size())
	if int(cal["countdown"]) == 0:
		cal["week"] = int(cal.get("week", 1)) + 1
		_add_coin(rogue, "supply", 1)
	campaign._record("schedule", {"action": action, "week": int(cal["week"])})
	return _ok()


## Cross-segment favors affect the offer at the current recruitment node.
static func recruit_cost(campaign, id: String) -> int:
	var spec: Dictionary = campaign.roster()["specs"].get(id, {})
	var cost := int(spec.get("gold_cost", 2))
	if not campaign.is_builtin():
		var row: Dictionary = campaign.book.get("companions", {}).get(id, {})
		var segment := str(campaign.state.get("segment", ""))
		var node := str(campaign.state.get("map", {}).get("pos", ""))
		var sheet := str(campaign.state.get("map", {}).get("sheet", ""))
		for offer in row.get("recruit", []):
			if str(offer.get("seg", "")) == segment and str(offer.get("node", "")) in [node, sheet + ":" + node] and offer.has("gold"):
				cost = int(offer["gold"])
		for hook in row.get("hooks", []):
			if str(hook.get("seg", "")) == segment and RunConditions.eval(campaign, hook.get("when", {})):
				cost += int(hook.get("gold", 0))
	if MapRules.at_depot(campaign):
		cost -= 1
	cost -= CompanionRules.reserve_bonus(campaign, "recruit_discount")
	return maxi(0, cost)


## Apply once on entering a segment, including favors for companions recruited later.
static func apply_opening_hooks(campaign) -> void:
	if campaign.is_builtin():
		return
	var segment := str(campaign.state.get("segment", ""))
	if (campaign.state.get("run", {}).get("path", []) as Array).count(segment) > 1:
		return
	var trust: Dictionary = campaign.state["rogue"]["army"]["trust"]
	for id in campaign.book.get("companions", {}):
		var row: Dictionary = campaign.book["companions"][id]
		for hook in row.get("hooks", []):
			if str(hook.get("seg", "")) == segment and RunConditions.eval(campaign, hook.get("when", {})):
				var key := "hero|" + str(id)
				trust[key] = clampi(int(trust.get(key, 0)) + int(hook.get("trust", 0)), 0, 3)


static func _recruit(campaign, args: Dictionary) -> Dictionary:
	if args.size() != 1 or typeof(args.get("id")) != TYPE_STRING:
		return _fail("bad_args")
	var c_id := str(args["id"])
	# 战斗规则 v2 的部队也走招募：{id: "troop:<兵种>"}，花帝国金币
	if c_id.begins_with("troop:"):
		var tgate := MapRules.gate(campaign, "recruit:" + c_id)
		if tgate != "":
			return _fail(tgate)
		return Battle2.recruit_troop(campaign, c_id.trim_prefix("troop:"))
	var roster: Dictionary = campaign.roster()
	if c_id not in roster["ids"]:
		return _fail("bad_args")
	var departed := CompanionRules.recruit_error(campaign, c_id)
	if departed != "":
		return _fail(departed)
	var gate := MapRules.gate(campaign, "recruit:" + c_id)
	if gate != "":
		return _fail(gate)
	var rogue: Dictionary = campaign.state["rogue"]
	var comp: Dictionary = rogue["companions"][c_id]
	if not bool(comp.get("alive", true)):
		return _fail("companion_fallen")
	if bool(comp.get("recruited", false)):
		return _fail("already_used")
	var spec: Dictionary = roster["specs"][c_id]
	var segs: Array = spec.get("segments", [])
	if not segs.is_empty() and not str(campaign.state.get("segment", "")) in segs:
		return _fail("wrong_segment")
	var cost := recruit_cost(campaign, c_id)
	if int(rogue["coins"].get("gold", 0)) < cost:
		return _fail("insufficient_funds")
	_add_coin(rogue, "gold", -cost)
	comp["recruited"] = true
	comp["hp"] = int(comp["max_hp"])
	campaign._record("recruit", {"id": c_id, "cost": cost})
	return _ok()


static func _promote(campaign, args: Dictionary) -> Dictionary:
	if args.size() != 1 or typeof(args.get("id")) != TYPE_STRING:
		return _fail("bad_args")
	var c_id := str(args["id"])
	if c_id not in campaign.roster()["ids"]:
		return _fail("bad_args")
	var rogue: Dictionary = campaign.state["rogue"]
	var comp: Dictionary = rogue["companions"][c_id]
	if not bool(comp.get("alive", true)):
		return _fail("companion_fallen")
	if not bool(comp.get("recruited", false)):
		return _fail("missing_companion")
	if int(comp.get("level", 1)) >= 3:
		return _fail("already_complete")
	if int(rogue["coins"].get("medal", 0)) < 1:
		return _fail("insufficient_funds")
	_add_coin(rogue, "medal", -1)
	comp["level"] = int(comp.get("level", 1)) + 1
	comp["max_hp"] = int(comp["max_hp"]) + 25
	comp["hp"] = int(comp["max_hp"])
	comp["atk"] = int(comp["atk"]) + 6
	Battle2.sync_growth_display(campaign, comp)
	campaign._record("promote", {"id": c_id, "level": int(comp["level"])})
	return _ok()


static func _use_prop(campaign, args: Dictionary) -> Dictionary:
	if not args.has("id") or typeof(args.get("id")) != TYPE_STRING:
		return _fail("bad_args")
	for k in args:
		if k not in ["id", "steps"]:
			return _fail("bad_args")
	var prop_id := str(args["id"])
	if prop_id not in Data.PROP_IDS:
		return _fail("bad_args")
	var rogue: Dictionary = campaign.state["rogue"]
	var props: Array = rogue["props"]
	if prop_id not in props:
		return _fail("missing_item")
	props.erase(prop_id)
	match prop_id:
		"prop_loaded_dice":
			_add_coin(rogue, "supply", 3)
			_add_coin(rogue, "intel", 1)
			var march: Dictionary = rogue["march"]
			var steps := clampi(int(args.get("steps", 4)), 1, 6)
			march["pos"] = (int(march.get("pos", 0)) + steps) % Data.MARCH_BOARD.size()
			march["last_roll"] = steps
			var tile_id := str(Data.MARCH_BOARD[int(march["pos"])]["id"])
			march["last_tile"] = tile_id
			_apply_tile_effect(campaign, rogue, tile_id)
		"prop_barricade":
			_add_coin(rogue, "supply", 2)
			campaign._apply_effects({"heat": -5})
		"prop_forced_march":
			_add_coin(rogue, "supply", 2)
			var march: Dictionary = rogue["march"]
			march["pos"] = (int(march.get("pos", 0)) + 2) % Data.MARCH_BOARD.size()
			var tile_id := str(Data.MARCH_BOARD[int(march["pos"])]["id"])
			march["last_tile"] = tile_id
			_apply_tile_effect(campaign, rogue, tile_id)
		"prop_spyglass":
			_add_coin(rogue, "intel", 2)
			campaign._apply_effects({"morale": 5})
		"prop_smoke_bomb":
			campaign._apply_effects({"heat": -8})
			_heal_all_companions(rogue, 30)
		"prop_field_ration":
			_add_coin(rogue, "supply", 3)
			campaign._apply_effects({"vitality": 15})
			_heal_all_companions(rogue, 35)
		"prop_bribe_pouch":
			_add_coin(rogue, "gold", 2)
			campaign._apply_effects({"treasury": 300, "heat": -6})
		"prop_imperial_decree":
			_add_coin(rogue, "medal", 2)
			campaign._apply_effects({"morale": 8})
	# 开地图时在原效果之外再加地图效果（§7.3；单段书没有地图，什么都不做）
	MapRules.prop_effect(campaign, prop_id)
	campaign._record("use_prop", {"id": prop_id})
	return _ok()


## 大命运的选项：三项通用 + 本段 big_fate_extra 里此刻能选的（scenes 列出的场战败、when 成立、once_per_run 没用过）
static func big_fate_options(campaign) -> Array:
	var out: Array = Data.BIG_FATE_IDS.duplicate()
	if campaign.is_builtin():
		return out
	var b2: Dictionary = campaign.state.get("rogue", {}).get("battle2", {})
	var scene_key := str(b2.get("scene", "")) if str(b2.get("key", b2.get("scene", ""))) == str(b2.get("scene", "")) else ""
	for fate in campaign.definition.get("big_fate_extra", []):
		var scenes: Array = fate.get("scenes", [])
		if not scenes.is_empty() and not scene_key in scenes:
			continue
		if bool(fate.get("once_per_run", false)) and str(fate.get("id", "")) in campaign.state["run"]["fate_once"]:
			continue
		if RunConditions.eval(campaign, fate.get("when", {})):
			out.append(str(fate["id"]))
	return out


static func _big_fate(campaign, args: Dictionary) -> Dictionary:
	if args.size() != 1 or typeof(args.get("choice")) != TYPE_STRING:
		return _fail("bad_args")
	var choice := str(args["choice"])
	if choice not in big_fate_options(campaign):
		return _fail("bad_args")
	var rogue: Dictionary = campaign.state["rogue"]
	var fate: Dictionary = rogue["big_fate"]
	if not bool(fate.get("pending", false)):
		return _fail("bad_phase")
	var roster_ids: Array = campaign.roster()["ids"]
	var jump := ""
	match choice:
		"sacrifice_rearguard":
			var victim_id := ""
			for c_id in roster_ids:
				var comp: Dictionary = rogue["companions"][c_id]
				if bool(comp.get("recruited", false)) and bool(comp.get("alive", false)) and not bool(comp.get("captured", false)):
					victim_id = c_id
					break
			if victim_id == "":
				return _fail("no_living_companion")
			rogue["companions"][victim_id]["alive"] = false
			rogue["companions"][victim_id]["hp"] = 0
			if victim_id not in rogue["fallen_companions"]:
				rogue["fallen_companions"].append(victim_id)
			_add_coin(rogue, "medal", 2)
			_add_coin(rogue, "supply", 2)
			campaign._apply_effects({"morale": 6})
			campaign._record("companion_fallen", {"id": victim_id, "reason": "sacrifice_rearguard"})
		"ransom_supply":
			if int(campaign.state["metrics"]["treasury"]) <= 300:
				return _fail("insufficient_funds")
			if int(rogue["coins"].get("gold", 0)) > 0:
				_add_coin(rogue, "gold", -1)
			_add_coin(rogue, "supply", 2)
			campaign._apply_effects({"treasury": -300, "vitality": 8, "heat": -10})
			# 割让军需也赎回战斗 v2 里被俘的伙伴
			for c_id in roster_ids:
				rogue["companions"][c_id]["captured"] = false
		"desperate_breakout":
			# 永远选得了（大命运不能卡死）：生命与动力不够 12 时，这一下就耗尽了，走“最后的灯火”结局
			var heat_add := mini(10, maxi(0, 95 - int(campaign.state["metrics"]["heat"])))
			_add_coin(rogue, "supply", 3)
			_add_coin(rogue, "intel", 2)
			campaign._apply_effects({"vitality": -12, "heat": heat_add})
		_:
			for row in campaign.definition.get("big_fate_extra", []):
				if str(row.get("id", "")) != choice:
					continue
				campaign.apply_choice(row)
				if bool(row.get("once_per_run", false)):
					campaign.state["run"]["fate_once"].append(choice)
				jump = str(row.get("jump", ""))
	fate["pending"] = false
	fate["trigger"] = ""
	fate["resolved_count"] = int(fate.get("resolved_count", 0)) + 1
	fate["history"].append(choice)
	campaign._record("big_fate", {"choice": choice})
	Battle2.fate_settled(campaign)
	if jump != "" and str(campaign.state["phase"]) == "day":
		campaign._switch_segment(jump, "fate:" + choice)
	return _ok()


## 剧情 / 事件抉择上的 rogue：{coins, props, recruit: id 或 [id…], troops, heal, trust:{pick:n,gain:g} 或 {pair:[a,b],gain:g}}
static func apply_rogue(campaign, spec: Dictionary, pick: Array = []) -> String:
	var rogue: Dictionary = campaign.state["rogue"]
	for c in spec.get("coins", {}):
		_add_coin(rogue, str(c), int(spec["coins"][c]))
	for p in spec.get("props", []):
		if str(p) in Data.PROP_IDS and not str(p) in rogue["props"]:
			rogue["props"].append(str(p))
	var recruits = spec.get("recruit", [])
	if typeof(recruits) == TYPE_STRING:
		recruits = [recruits]
	for c_id in recruits:
		var row: Dictionary = rogue["companions"].get(str(c_id), {})
		if not row.is_empty() and bool(row.get("alive", true)) and not bool(row.get("recruited", false)) and CompanionRules.recruit_error(campaign, str(c_id)) == "":
			row["recruited"] = true
			row["hp"] = int(row["max_hp"])
			campaign._record("recruit", {"id": str(c_id), "cost": 0})
	for cls in spec.get("troops", []):
		Battle2.grant_troop(campaign, str(cls))
	if int(spec.get("heal", 0)) > 0:
		_heal_all_companions(rogue, int(spec["heal"]))
	var trust = spec.get("trust", {})
	if typeof(trust) == TYPE_DICTIONARY and not (trust as Dictionary).is_empty():
		var who: Array = []
		if trust.has("pair"):
			who = trust["pair"]
		else:
			var want := int(trust.get("pick", 0))
			for c_id in pick:
				var row: Dictionary = rogue["companions"].get(str(c_id), {})
				if row.is_empty() or not bool(row.get("recruited", false)) or not bool(row.get("alive", false)):
					return "bad_args"
				if not str(c_id) in who:
					who.append(str(c_id))
			if who.is_empty():
				for c_id in campaign.roster()["ids"]:
					var row: Dictionary = rogue["companions"][c_id]
					if who.size() < want and bool(row.get("recruited", false)) and bool(row.get("alive", false)):
						who.append(c_id)
			who = who.slice(0, want)
		var army: Dictionary = rogue["army"]
		for c_id in who:
			var key := "hero|" + str(c_id)
			army["trust"][key] = mini(3, int(army["trust"].get(key, 0)) + int(trust.get("gain", 1)))
	return ""


static func _add_coin(rogue: Dictionary, coin_id: String, delta: int) -> void:
	var coins: Dictionary = rogue["coins"]
	coins[coin_id] = clampi(int(coins.get(coin_id, 0)) + delta, 0, 999)
	if delta > 0 and typeof(rogue.get("tally")) == TYPE_DICTIONARY:
		rogue["tally"][coin_id] = int(rogue["tally"].get(coin_id, 0)) + delta


static func _grant_next_prop(rogue: Dictionary) -> String:
	var props: Array = rogue["props"]
	for p_id in Data.PROP_IDS:
		if p_id not in props:
			props.append(p_id)
			return p_id
	_add_coin(rogue, "gold", 1)
	return "prop_loaded_dice"


static func _heal_all_companions(rogue: Dictionary, amount: int) -> void:
	var comps: Dictionary = rogue.get("companions", {})
	for c_id in comps:
		var comp: Dictionary = comps[c_id]
		if bool(comp.get("alive", false)):
			comp["hp"] = mini(int(comp.get("max_hp", 80)), int(comp.get("hp", 80)) + amount)


static func valid_rogue(rogue: Variant, roster_ids: Array = Data.COMPANION_IDS) -> bool:
	if typeof(rogue) != TYPE_DICTIONARY:
		return false
	if rogue.size() != REQ_KEYS.size():
		return false
	for k in REQ_KEYS:
		if not rogue.has(k):
			return false
	var coins: Variant = rogue.get("coins")
	if typeof(coins) != TYPE_DICTIONARY or coins.size() != Data.COIN_IDS.size():
		return false
	var tally: Variant = rogue.get("tally")
	if typeof(tally) != TYPE_DICTIONARY or tally.size() != Data.COIN_IDS.size():
		return false
	for c_id in Data.COIN_IDS:
		if typeof(coins.get(c_id)) != TYPE_INT or int(coins[c_id]) < 0 or int(coins[c_id]) > 999:
			return false
		if typeof(tally.get(c_id)) != TYPE_INT or int(tally[c_id]) < 0:
			return false
	var props: Variant = rogue.get("props")
	if typeof(props) != TYPE_ARRAY:
		return false
	for p_id in props:
		if typeof(p_id) != TYPE_STRING or p_id not in Data.PROP_IDS:
			return false
	var comps: Variant = rogue.get("companions")
	if typeof(comps) != TYPE_DICTIONARY or comps.size() != roster_ids.size():
		return false
	for c_id in roster_ids:
		var comp: Variant = comps.get(c_id)
		if typeof(comp) != TYPE_DICTIONARY:
			return false
		if typeof(comp.get("recruited")) != TYPE_BOOL or typeof(comp.get("alive")) != TYPE_BOOL:
			return false
		for stat_k in ["level", "hp", "max_hp", "atk", "block"]:
			if typeof(comp.get(stat_k)) != TYPE_INT:
				return false
	if typeof(rogue.get("fallen_companions")) != TYPE_ARRAY:
		return false
	for f_id in rogue["fallen_companions"]:
		if typeof(f_id) != TYPE_STRING or f_id not in roster_ids:
			return false
	var march: Variant = rogue.get("march")
	if typeof(march) != TYPE_DICTIONARY or typeof(march.get("pos")) != TYPE_INT or int(march["pos"]) < 0 or int(march["pos"]) >= Data.MARCH_BOARD.size():
		return false
	if str(march.get("route", "")) not in Data.ROUTE_IDS:
		return false
	var cal: Variant = rogue.get("calendar")
	if typeof(cal) != TYPE_DICTIONARY or typeof(cal.get("week")) != TYPE_INT or typeof(cal.get("scheduled")) != TYPE_ARRAY:
		return false
	var battle: Variant = rogue.get("battle")
	if typeof(battle) != TYPE_DICTIONARY or typeof(battle.get("scene_id")) != TYPE_STRING:
		return false
	var fate: Variant = rogue.get("big_fate")
	if typeof(fate) != TYPE_DICTIONARY or typeof(fate.get("pending")) != TYPE_BOOL or typeof(fate.get("history")) != TYPE_ARRAY:
		return false
	return CompanionRules.valid_optional(rogue) and Battle2.valid(rogue, roster_ids)


static func _ok() -> Dictionary:
	return {"ok": true, "err": ""}


static func _fail(err: String) -> Dictionary:
	return {"ok": false, "err": err}
