## Second-volume companion duties, departures and named bonds.
## Optional state lives inside the existing companion rows; volume one is unchanged.
extends RefCounted


static func enabled(campaign) -> bool:
	return campaign.has_method("is_builtin") and not campaign.is_builtin() and int(campaign.book.get("volume", 1)) >= 2


static func chapter_key(campaign) -> String:
	return str(campaign.state.get("segment", "")) + ":" + str(campaign.chapter().get("id", ""))


static func present(campaign, id: String) -> bool:
	var row: Dictionary = campaign.state.get("rogue", {}).get("companions", {}).get(id, {})
	return bool(row.get("recruited", false)) and bool(row.get("alive", false)) and not bool(row.get("captured", false)) and not bool(row.get("left", false))


static func at_camp(campaign) -> bool:
	if str(campaign.state.get("phase", "")) != "day" or not campaign.battle_idle():
		return false
	if bool(campaign.state.get("rogue", {}).get("big_fate", {}).get("pending", false)):
		return false
	var map: Dictionary = campaign.state.get("map", {})
	if map.is_empty():
		return true
	if str(map.get("pending_kind", "")) in ["toll", "rival"]:
		return false
	var segment := str(campaign.state.get("segment", ""))
	for sheet in campaign.book.get("maps", {}).get(segment, {}).get("sheets", []):
		if str(sheet.get("id", sheet.get("chapter", ""))) != str(map.get("sheet", "")) and str(sheet.get("chapter", "")) != str(campaign.chapter().get("id", "")):
			continue
		for node in sheet.get("nodes", []):
			if str(node.get("id", "")) == str(map.get("pos", "")):
				var kind := str(node.get("type", ""))
				if kind == "slot":
					kind = str(map.get("slots", {}).get(str(node["id"]), {}).get("kind", ""))
				return kind == "camp" or str(node.get("role", "")) in ["camp", "muster"]
	return false


static func is_reserve(campaign, id: String) -> bool:
	if not enabled(campaign) or not present(campaign, id):
		return false
	var row: Dictionary = campaign.state["rogue"]["companions"][id]
	return str(row.get("duty", "field")) == "reserve" and str(row.get("duty_chapter", "")) == chapter_key(campaign)


static func duty_error(campaign, id: String, reserve: bool) -> String:
	if not enabled(campaign):
		return "bad_args"
	if not present(campaign, id):
		return "missing_companion"
	if not at_camp(campaign):
		return "wrong_node"
	if reserve and campaign.book.get("companions", {}).get(id, {}).get("reserve", {}).is_empty():
		return "no_reserve_duty"
	if is_reserve(campaign, id):
		return "already_used" if reserve else "duty_committed"
	if not reserve:
		return "already_used"
	return ""


static func handle(campaign, args: Dictionary) -> Dictionary:
	if args.size() != 2 or typeof(args.get("id")) != TYPE_STRING or typeof(args.get("duty")) != TYPE_STRING or str(args["duty"]) not in ["reserve", "field"]:
		return {"ok": false, "err": "bad_args"}
	var id: String = args["id"]
	var error := duty_error(campaign, id, str(args["duty"]) == "reserve")
	if error != "":
		return {"ok": false, "err": error}
	var row: Dictionary = campaign.state["rogue"]["companions"][id]
	row["duty"] = "reserve"
	row["duty_chapter"] = chapter_key(campaign)
	var rule: Dictionary = campaign.book["companions"][id].get("reserve", {})
	if not rule.has("chapters") or str(campaign.chapter().get("id", "")) in rule["chapters"]:
		for currency in rule.get("chapter_coins", {}):
			campaign.add_coin(str(currency), int(rule["chapter_coins"][currency]))
		campaign._apply_effects(rule.get("chapter_metrics", {}))
		var heals := int(rule.get("heal_scars", 0))
		for other in campaign.roster()["ids"]:
			if heals <= 0:
				break
			var comp: Dictionary = campaign.state["rogue"]["companions"][other]
			if present(campaign, str(other)) and bool(comp.get("scarred", false)):
				comp["scarred"] = false
				comp["b_max_hp"] = int(comp.get("max_hp", campaign.roster()["profiles"][other].get("hp", 10)))
				heals -= 1
	campaign._record("companion_duty", {"id": id, "duty": "reserve", "chapter": str(campaign.chapter().get("id", ""))})
	return {"ok": true, "err": ""}


static func companion_status(campaign, id: String) -> Dictionary:
	if not enabled(campaign):
		return {}
	var spec: Dictionary = campaign.book.get("companions", {}).get(id, {})
	if spec.is_empty():
		return {}
	var reserve_error := duty_error(campaign, id, true)
	var recall_error := duty_error(campaign, id, false)
	return {"duty": "reserve" if is_reserve(campaign, id) else "field", "keep": str(spec.get("keep", "")),
		"can_reserve": reserve_error == "", "reserve_reason": reserve_error,
		"can_recall": recall_error == "", "recall_reason": recall_error,
		"deployment_reason": deployment_error(campaign, id),
		"left": bool(campaign.state["rogue"]["companions"].get(id, {}).get("left", false))}


## Chapter effects are paid once, when the player commits to that entire chapter.
## At the next chapter all survivors return to the field roster and can be reassigned.
static func on_scene(campaign) -> void:
	if not enabled(campaign):
		return
	var key := chapter_key(campaign)
	for id in campaign.state["rogue"]["companions"]:
		var row: Dictionary = campaign.state["rogue"]["companions"][id]
		if str(row.get("duty", "field")) == "reserve" and str(row.get("duty_chapter", "")) != key:
			row["duty"] = "field"
			row.erase("duty_chapter")
		if bool(row.get("left", false)):
			row["recruited"] = false
			continue
		var rule: Dictionary = campaign.book.get("companions", {}).get(id, {}).get("leave_rule", {})
		if rule.has("chapter") and _departure_matches(campaign, str(id), rule) and str(campaign.chapter().get("id", "")) == str(rule["chapter"]):
			_depart(campaign, str(id), rule)
	_story_bonds(campaign)


static func after_choice(campaign, scene_id: String) -> void:
	if not enabled(campaign):
		return
	for id in campaign.state["rogue"]["companions"]:
		var rule: Dictionary = campaign.book.get("companions", {}).get(id, {}).get("leave_rule", {})
		if str(rule.get("scene", "")) == scene_id and _departure_matches(campaign, str(id), rule):
			_depart(campaign, str(id), rule)
		if bool(campaign.state["rogue"]["companions"][id].get("left", false)):
			campaign.state["rogue"]["companions"][id]["recruited"] = false
	_story_bonds(campaign)


static func _departure_matches(campaign, id: String, rule: Dictionary) -> bool:
	return present(campaign, id) and str(rule.get("segment", "")) == str(campaign.state.get("segment", "")) and (not rule.has("trust_below") or trust(campaign, "hero", id) < int(rule["trust_below"]))


static func _depart(campaign, id: String, rule: Dictionary) -> void:
	var row: Dictionary = campaign.state["rogue"]["companions"][id]
	row["left"] = true
	row["recruited"] = false
	row["duty"] = "field"
	row.erase("duty_chapter")
	campaign._apply_effects(rule.get("metrics", {}))
	campaign._record("companion_departed", {"id": id})


static func recruit_error(campaign, id: String) -> String:
	return "companion_departed" if enabled(campaign) and bool(campaign.state["rogue"]["companions"].get(id, {}).get("left", false)) else ""


static func deployment_error(campaign, id: String) -> String:
	if not enabled(campaign):
		return ""
	if is_reserve(campaign, id):
		return "companion_on_duty"
	if bool(campaign.state["rogue"]["companions"].get(id, {}).get("left", false)):
		return "companion_departed"
	var deploy: Dictionary = campaign.book.get("companions", {}).get(id, {}).get("deploy", {})
	if not deploy.is_empty():
		var segment := str(campaign.state.get("segment", ""))
		var earliest := str(deploy.get("from_chapter", {}).get(segment, ""))
		if earliest != "":
			var chapters: Array = campaign.definition.get("chapters", [])
			var current := -1
			var first := chapters.size()
			for i in range(chapters.size()):
				if str(chapters[i].get("id", "")) == str(campaign.chapter().get("id", "")):
					current = i
				if str(chapters[i].get("id", "")) == earliest:
					first = i
			if current < first:
				return "companion_too_young"
		elif int(str(campaign.scene().get("date", "0")).substr(0, 4)) < 1819:
			return "companion_too_young"
	return ""


static func lineup_error(campaign, ids: Array) -> String:
	if not enabled(campaign):
		return ""
	for id in ids:
		var error := deployment_error(campaign, str(id))
		if error != "":
			return error
	if "albert" in ids and "haydee" in ids and _peers_passed(campaign) and not bool(campaign.state["flags"].get("m_mercedes_spared", false)):
		return "companion_discord"
	return ""


static func _peers_passed(campaign) -> bool:
	return _choice_passed(campaign, "c_peers")


static func _choice_passed(campaign, scene_id: String) -> bool:
	var actions: Dictionary = campaign.state.get("used_actions", {})
	for action in actions.get(scene_id, []):
		if str(action).begins_with("choice:"):
			return true
	return false


static func reserve_bonus(campaign, key: String) -> int:
	if not enabled(campaign):
		return 0
	var total := 0
	for id in campaign.book.get("companions", {}):
		if is_reserve(campaign, str(id)):
			total += int(campaign.book["companions"][id].get("reserve", {}).get(key, 0))
	return mini(1, total) if key in ["depot_guard", "voyage_days", "toll_free", "forecast"] else total


static func trust(campaign, a: String, b: String) -> int:
	var values: Dictionary = campaign.state.get("rogue", {}).get("army", {}).get("trust", {})
	return clampi(int(values.get(a + "|" + b, values.get(b + "|" + a, 0))), 0, 3)


static func pairs(campaign) -> Array:
	if not enabled(campaign):
		return []
	var out: Array = []
	var seen := {}
	for companion in campaign.book.get("companions", {}).values():
		for pair in companion.get("named_pairs", []):
			if seen.has(pair["id"]) or str(campaign.state.get("segment", "")) not in pair.get("segments", []):
				continue
			seen[pair["id"]] = true
			out.append(pair.duplicate(true))
	return out


static func public_pairs(campaign) -> Array:
	var out: Array = []
	for pair in pairs(campaign):
		var a := str(pair["a"])
		var b := str(pair["b"])
		if (a != "hero" and not bool(campaign.state["rogue"]["companions"].get(a, {}).get("recruited", false))) or (b != "hero" and not bool(campaign.state["rogue"]["companions"].get(b, {}).get("recruited", false))):
			continue
		var level := trust(campaign, a, b)
		var hero_ok := not bool(campaign.state.get("rogue", {}).get("army", {}).get("hero_wounded", false))
		var desc := PackedStringArray()
		for tier in pair["tiers"]:
			if int(tier) <= level:
				desc.append(str(pair["tiers"][tier]))
		out.append({"id": pair["id"], "name": pair["name"], "a": a, "b": b, "tier": level,
			"active": level > 0 and (hero_ok if a == "hero" else present(campaign, a)) and (hero_ok if b == "hero" else present(campaign, b)) and not is_reserve(campaign, a) and not is_reserve(campaign, b), "desc": "\n".join(desc)})
	return out


static func apply_battle_setup(campaign, setup: Dictionary, ids: Array, hero: bool) -> void:
	if not enabled(campaign):
		return
	var selected := ids.duplicate()
	if hero:
		selected.append("hero")
	var chosen: Array = []
	for pair in pairs(campaign):
		if str(pair["a"]) in selected and str(pair["b"]) in selected:
			var tier := trust(campaign, str(pair["a"]), str(pair["b"]))
			if tier > 0:
				var descriptions := PackedStringArray()
				for step in pair["tiers"]:
					if int(step) <= tier:
						descriptions.append(str(pair["tiers"][step]))
				chosen.append({"id": pair["id"], "name": pair["name"], "a": pair["a"], "b": pair["b"], "tier": tier, "desc": "\n".join(descriptions)})
	setup["pairs"] = chosen
	setup["pair_flags"] = {"truth": bool(campaign.state["flags"].get("m_bertuccio_knows", false)),
		"auteuil": _choice_passed(campaign, "c_auteuil"),
		"caderousse_sworn": bool(campaign.state["flags"].get("m_caderousse_sworn", false)),
		"mercedes": bool(campaign.state["flags"].get("m_mercedes_spared", false))}
	setup["reserve_support"] = {"hero_fate": reserve_bonus(campaign, "hero_fate"), "forecast": reserve_bonus(campaign, "forecast")}
	for unit in setup.get("roster", []):
		var reckless: Dictionary = campaign.book["companions"].get(str(unit.get("id", "")), {}).get("reckless", {})
		if not reckless.is_empty():
			unit["atk"] = int(unit.get("atk", 0)) + int(reckless.get("attack", 0))
			unit["fate_bonus"] = int(reckless.get("fate_coins", 0))


## Called once by battle settlement, after permanent deaths and captures.
## Hero trust already grows in Battle2.finish; named companion pairs need their own path.
static func after_battle(campaign, battle: Dictionary, result: Dictionary) -> void:
	if not enabled(campaign) or str(result.get("outcome", "")) != "victory":
		return
	var grown := {}
	var values: Dictionary = campaign.state["rogue"]["army"]["trust"]
	for pair in pairs(campaign):
		var a := str(pair["a"])
		var b := str(pair["b"])
		if "hero" in [a, b] or not present(campaign, a) or not present(campaign, b):
			continue
		if a not in battle.get("deployed_ever", []) or b not in battle.get("deployed_ever", []):
			continue
		var ids: Array = [a, b]
		ids.sort()
		var key := str(ids[0]) + "|" + str(ids[1])
		if grown.has(key):
			continue
		grown[key] = true
		var old := trust(campaign, a, b)
		values.erase(a + "|" + b)
		values.erase(b + "|" + a)
		values[key] = mini(3, old + 1)
	_story_bonds(campaign)


static func _story_bonds(campaign) -> void:
	for pair in public_pairs(campaign):
		if int(pair["tier"]) < 3 or not bool(pair["active"]):
			continue
		var id := str(pair["id"])
		if id == "old_friends" and str(campaign.chapter().get("id", "")) == "collapse":
			campaign.state["flags"]["t_baptiste_marie_married"] = true
		elif id == "two_numbers":
			campaign.state["flags"]["k_spada_letter"] = true
		elif id == "wait_and_hope":
			campaign.state["flags"]["m_wait_hope_bond"] = true


static func valid_optional(rogue: Dictionary) -> bool:
	for row in rogue.get("companions", {}).values():
		if row.has("duty") and (typeof(row["duty"]) != TYPE_STRING or str(row["duty"]) not in ["field", "reserve"]):
			return false
		if row.has("duty_chapter") and typeof(row["duty_chapter"]) != TYPE_STRING:
			return false
		if row.has("duty_chapter") and str(row.get("duty", "field")) != "reserve":
			return false
		if str(row.get("duty", "field")) == "reserve" and (not row.has("duty_chapter") or str(row["duty_chapter"]) == ""):
			return false
		if row.has("left") and typeof(row["left"]) != TYPE_BOOL:
			return false
		if bool(row.get("left", false)) and (bool(row.get("recruited", false)) or str(row.get("duty", "field")) != "field"):
			return false
	return true
