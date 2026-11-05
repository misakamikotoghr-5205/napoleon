class_name NpcLife
extends RefCounted

const R = preload("res://scripts/sim/jev_rng.gd")
const Conditions = preload("res://scripts/sim/town_cond.gd")

# Schedules store the same place names as the town map. Later, more specific
# overrides take precedence: weekday, weather, then the exact day.
static func location(pack: Dictionary, s: Dictionary, npc: String, minute: int = -1) -> String:
	var npcs: Dictionary = pack.get("npcs", {})
	if not npcs.has(npc) or not present(pack, s, npc):
		return ""
	var spec: Dictionary = npcs[npc]
	var schedule: Dictionary = spec.get("schedule", {})
	var row: Array = schedule.get("default", [])
	var weekday: int = posmod(int(pack.get("time", {}).get("start_weekday", 0)) + int(s.get("day", 0)), 7)
	for key in ["weekday:%d" % weekday, "weather:" + str(s.get("weather", "")), "day:%d" % int(s.get("day", 0))]:
		if schedule.has(key):
			row = schedule[key]
	if row.is_empty():
		return _place(pack, str(spec.get("home", "家")))
	var current: int = int(s.get("minute", -1)) if minute < 0 else minute
	var slot: int = int(s.get("slot", 0)) if current < 0 else slot_at(pack, current)
	return _place(pack, str(row[clampi(slot, 0, row.size() - 1)]))

static func present(pack: Dictionary, s: Dictionary, npc: String, world = null) -> bool:
	var npcs: Dictionary = pack.get("npcs", {})
	if not npcs.has(npc):
		return false
	var spec: Dictionary = npcs[npc]
	if spec.has("requires_building") and not bool(s.get("unlocked", {}).get(spec["requires_building"], false)):
		return false
	return Conditions.test(spec.get("when", {}), pack, s, world)

# This returns only the visit plan. TownSim attaches generated or authored
# sessions and owns the waiting/finished status of each visit.
static func plan(pack: Dictionary, s: Dictionary, world = null) -> Array:
	var visits: Array = []
	var npcs: Dictionary = pack.get("npcs", {})
	var cfg: Dictionary = pack.get("visit_config", {})
	var day: int = int(s.get("day", 0))
	var heat: float = float(s.get("pressures", {}).get("heat", 0.0))
	var visit_mult: float = _difficulty_multiplier(pack, s)
	for npc in _sorted(npcs.keys()):
		if not present(pack, s, str(npc), world):
			continue
		var spec: Dictionary = npcs[npc]
		var visit: Dictionary = spec.get("visit", {})
		if not Conditions.test(visit.get("when", {}), pack, s, world):
			continue
		var cash: float = float(s.get("npc_cash", {}).get(npc, spec.get("cash", 0)))
		var need_scale: float = float(visit.get("need_scale", 0.0))
		var need: float = clampf((need_scale - cash) / need_scale, 0.0, 1.0) if need_scale > 0.0 else 0.0
		var unknown: int = _unknown_rumors(s, str(npc))
		var probability: float = float(visit.get("base", 0.0))
		probability += float(cfg.get("need_gain", 0.0)) * need
		probability += float(cfg.get("rumor_gain", 0.0)) * mini(unknown, int(cfg.get("rumor_cap", 0)))
		probability += float(visit.get("heat_gain", 0.0)) * heat
		if s.get("tickets", {}).has(npc):
			probability += float(cfg.get("ticket_visit_gain", 0.0))
		if bool(s.get("flags_today", {}).get("market_day", false)):
			probability += float(cfg.get("market_visit_gain", 0.0))
		if str(s.get("weather", "")) == "雨":
			probability -= float(cfg.get("rain_visit_penalty", 0.0))
		probability = clampf(probability * visit_mult, 0.0, float(cfg.get("max_probability", 1.0)))
		if _draw(s, "visit", [day, str(npc)]) >= probability:
			continue
		var rows: Array = _intent_rows(visit.get("intents", {}), need, unknown, heat, s.get("tickets", {}).has(npc), cfg)
		if rows.is_empty():
			continue
		var intent: String = R.weighted_choice(rows, _draw(s, "intent", [day, str(npc)]))
		visits.append({"who": str(npc), "intent": intent, "slot": _visit_slot(pack, s, str(npc)), "storylet": ""})
	var strangers: Dictionary = pack.get("strangers", {})
	var per_day: Dictionary = strangers.get("per_day", {})
	var unrest: float = float(s.get("pressures", {}).get("unrest", 0.0))
	var expected: float = float(per_day.get("base", 0.0)) + float(per_day.get("unrest_gain", 0.0)) * unrest
	if bool(s.get("flags_today", {}).get("market_day", false)):
		expected += float(per_day.get("market_day_bonus", 0.0))
	var count: int = mini(int(per_day.get("max", 0)), maxi(0, int(floor(expected * visit_mult + _draw(s, "stranger_count", [day])))))
	for index in range(count):
		var visitor: Dictionary = _stranger(pack, s, index)
		if not visitor.is_empty():
			visits.append(visitor)
	var keep: Array = []
	var spawn_index: int = 0
	for spawn in s.get("spawns", []):
		if int(spawn.get("due", day)) <= day:
			var visitor: Dictionary = spawn.duplicate(true)
			visitor.erase("due")
			visitor["slot"] = int(visitor.get("slot", _default_spawn_slot(pack)))
			visitor["storylet"] = str(visitor.get("storylet", ""))
			visitor["plan_key"] = "spawn:%d" % spawn_index
			visits.append(visitor)
			spawn_index += 1
		else:
			keep.append(spawn)
	s["spawns"] = keep
	# The floor is a gameplay guarantee, including days on which every named
# character stays away. The pack supplies eligible stranger archetypes.
	var minimum: int = maxi(1, int(cfg.get("min_per_day", 1)))
	while visits.size() < minimum:
		var visitor: Dictionary = _stranger(pack, s, count)
		if visitor.is_empty():
			break
		visits.append(visitor)
		count += 1
	for index in range(visits.size()):
		_complete_visit(pack, s, visits[index], index, world)
	visits.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a["minute"]) != int(b["minute"]):
			return int(a["minute"]) < int(b["minute"])
		if str(a["who"]) != str(b["who"]):
			return str(a["who"]) < str(b["who"])
		return str(a["plan_key"]) < str(b["plan_key"]))
	for index in range(visits.size()):
		if str(visits[index].get("id", "")).is_empty():
			visits[index]["id"] = "visit_d%d_%d" % [day, index]
		visits[index].erase("plan_key")
	return visits

static func slot_at(pack: Dictionary, minute: int) -> int:
	var hours: Array = pack.get("time", {}).get("slot_hours", [])
	var slot: int = 0
	for index in range(hours.size()):
		if minute >= int(hours[index]) * 60:
			slot = index
	return slot

static func _place(pack: Dictionary, name: String) -> String:
	var buildings: Dictionary = pack.get("buildings", {})
	if buildings.has(name):
		return str(buildings[name].get("name", name))
	if name == "铺子":
		return str(buildings.get("pawnshop", {}).get("name", "德厚当"))
	return name

static func _difficulty_multiplier(pack: Dictionary, s: Dictionary) -> float:
	var difficulty: Dictionary = pack.get("difficulty", {})
	return float(difficulty.get(str(s.get("difficulty", "")), {}).get("visit_mult", 1.0))

static func _unknown_rumors(s: Dictionary, npc: String) -> int:
	var count: int = 0
	for key in s.get("known", {}).get(npc, {}):
		if not s.get("player_rumors", {}).has(key):
			count += 1
	return count

static func _intent_rows(intents: Dictionary, need: float, unknown: int, heat: float, ticket: bool, cfg: Dictionary) -> Array:
	var rows: Array = []
	for intent in _sorted(intents.keys()):
		var weight: float = float(intents[intent])
		match str(intent):
			"redeem", "renew":
				if not ticket:
					weight = 0.0
			"pawn":
				weight *= float(cfg.get("pawn_need_base", 0.0)) + need
			"gossip":
				if unknown == 0:
					weight = 0.0
			"buy":
				weight *= 1.0 - need
			"inspect":
				weight *= 1.0 + float(cfg.get("inspect_heat_gain", 0.0)) * heat
		if weight > 0.0:
			rows.append([str(intent), weight])
	return rows

static func _slots(pack: Dictionary) -> Array:
	var slots: Array = pack.get("visit_config", {}).get("slots", [])
	if not slots.is_empty():
		return slots
	var result: Array = []
	var hours: Array = pack.get("time", {}).get("slot_hours", [])
	for index in range(1, maxi(1, hours.size() - 1)):
		result.append(index)
	return result if not result.is_empty() else [0]

static func _visit_slot(pack: Dictionary, s: Dictionary, npc: String) -> int:
	var cfg: Dictionary = pack.get("visit_config", {})
	var rows: Array = []
	var hours: Array = pack.get("time", {}).get("slot_hours", [])
	var pawnshop: String = _place(pack, "pawnshop")
	for slot in _slots(pack):
		var slot_index: int = clampi(int(slot), 0, maxi(0, hours.size() - 1))
		var minute: int = int(hours[slot_index]) * 60 if not hours.is_empty() else 0
		var weight: float = float(cfg.get("slot_at_pawnshop_weight", 1.0)) if location(pack, s, npc, minute) == pawnshop else float(cfg.get("slot_other_weight", 1.0))
		if weight > 0.0:
			rows.append([str(slot_index), weight])
	if rows.is_empty():
		return int(_slots(pack)[0])
	return int(R.weighted_choice(rows, _draw(s, "visit_slot", [int(s.get("day", 0)), npc])))

static func _default_spawn_slot(pack: Dictionary) -> int:
	var slots: Array = _slots(pack)
	return int(slots[int(floor(float(slots.size() - 1) / 2.0))])

static func _stranger(pack: Dictionary, s: Dictionary, index: int) -> Dictionary:
	var rows: Array = []
	var specs: Dictionary = {}
	var unrest: float = float(s.get("pressures", {}).get("unrest", 0.0))
	for spec in pack.get("strangers", {}).get("archetypes", []):
		if spec.has("requires_building") and not bool(s.get("unlocked", {}).get(spec["requires_building"], false)):
			continue
		var intents: Dictionary = spec.get("intents", {})
		var has_intent: bool = false
		for intent in intents:
			if float(intents[intent]) > 0.0:
				has_intent = true
		var weight: float = float(spec.get("weight", 0.0)) * maxf(0.0, 1.0 + float(spec.get("unrest_bias", 0.0)) * unrest)
		if weight > 0.0 and has_intent:
			specs[str(spec["id"])] = spec
	for id in _sorted(specs.keys()):
		var spec: Dictionary = specs[id]
		rows.append([str(id), float(spec["weight"]) * maxf(0.0, 1.0 + float(spec.get("unrest_bias", 0.0)) * unrest)])
	if rows.is_empty():
		return {}
	var day: int = int(s.get("day", 0))
	var archetype: String = R.weighted_choice(rows, _draw(s, "stranger", [day, index]))
	var intents: Dictionary = specs[archetype]["intents"]
	var intent_rows: Array = []
	for intent in _sorted(intents.keys()):
		if float(intents[intent]) > 0.0:
			intent_rows.append([str(intent), float(intents[intent])])
	var intent: String = R.weighted_choice(intent_rows, _draw(s, "stranger_intent", [day, index]))
	var slots: Array = _slots(pack)
	var slot: int = int(slots[int(floor(_draw(s, "stranger_slot", [day, index]) * float(slots.size())))])
	return {"who": "stranger:%s#d%d_%d" % [archetype, int(s.get("day", 0)), index], "intent": intent, "slot": slot, "archetype": archetype, "storylet": ""}

static func _complete_visit(pack: Dictionary, s: Dictionary, visit: Dictionary, index: int, world) -> void:
	var cfg: Dictionary = pack.get("visit_config", {})
	var hours: Array = pack.get("time", {}).get("slot_hours", [])
	var slot: int = clampi(int(visit.get("slot", 0)), 0, maxi(0, hours.size() - 1))
	visit["slot"] = slot
	var key: String = str(visit.get("plan_key", "%s:%d" % [str(visit.get("who", "")), index]))
	visit["plan_key"] = key
	var day: int = int(s.get("day", 0))
	var start: int = int(hours[slot]) * 60 if not hours.is_empty() else 0
	var stop: int = int(hours[slot + 1]) * 60 if slot + 1 < hours.size() else 24 * 60
	var jitter: int = mini(maxi(0, int(cfg.get("minute_jitter", 0))), maxi(0, stop - start - 1))
	visit["minute"] = int(visit.get("minute", start + int(floor(_draw(s, "visit_minute", [day, key]) * float(jitter + 1)))))
	var patience = cfg.get("patience_min", [0, 0])
	var low: int = int(patience[0]) if patience is Array else int(patience)
	var high: int = int(patience[1]) if patience is Array and patience.size() > 1 else low
	high = maxi(low, high)
	visit["patience_min"] = int(visit.get("patience_min", low + int(floor(_draw(s, "visit_patience", [day, key]) * float(high - low + 1)))))
	if visit.has("companions"):
		var companions: Array = visit["companions"]
		companions.sort()
		return
	var companions: Array = []
	var maximum: int = maxi(0, int(cfg.get("companion_max", 0)))
	var npcs: Dictionary = pack.get("npcs", {})
	var who: String = str(visit.get("who", ""))
	var links: Dictionary = npcs.get(who, {}).get("links", {})
	for other in _sorted(links.keys()):
		if companions.size() >= maximum:
			break
		if str(other) == who or not present(pack, s, str(other), world):
			continue
		var probability: float = clampf(float(cfg.get("companion_probability", 0.0)) * float(links[other]), 0.0, 1.0)
		if _draw(s, "visit_companion", [day, key, str(other)]) < probability:
			companions.append(str(other))
	visit["companions"] = companions

static func _draw(s: Dictionary, domain: String, key: Array) -> float:
	return R.draw(int(s.get("seed", 0)), domain, key)

static func _sorted(values: Array) -> Array:
	var result: Array = values.duplicate()
	result.sort()
	return result
