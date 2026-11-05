class_name TownPack
extends RefCounted

const ROOT_FIELDS = ["version", "time", "pressures", "influence", "living_costs", "buildings", "npcs", "strangers", "wheels", "building_decks", "communication", "rumors", "norms", "institutions", "difficulty", "spine", "balance", "prices", "default_difficulty", "initial", "places", "visit_config"]
const CONDITION_OPS = ["all", "any", "not", "day_gte", "weekday", "season", "weather", "flag", "stat_gte", "pressure_gte", "building", "npc_rel_gte"]
const EFFECT_FIELDS = {
	"weather": ["value"], "pressure_add": ["key", "value"],
	"news": ["text", "via", "source", "conf"],
	"flag_today": ["key", "value"], "flag_set": ["key", "value"],
	"bill": ["id", "label", "min", "max", "amount", "payee", "building", "due_days", "grace_days", "source", "cost_id"],
	"rumor": ["key", "origin", "conf"],
	"spawn_visit": ["who", "intent", "item", "delay_days", "minute", "companions", "storylet"],
	"npc_feel": ["where", "who", "key", "value"],
	"institution": ["id", "act", "target"], "unlock": ["building"],
	"item_drop": ["item", "category", "count", "owner", "location"],
	"invitation": ["id", "label", "text", "who", "due_day", "delay_days", "lead_days", "amount", "cost_id", "building", "payee"]
}

static func load_pack(path: String = "res://data/town/town_pack.json") -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK or not json.data is Dictionary:
		return {}
	var result: Dictionary = json.data
	return result if validate(result).is_empty() else {}

# Content errors are returned for callers to display, without engine error logs.
static func validate(pack: Dictionary) -> Array:
	var errors: Array = []
	_fields(pack, "pack", ROOT_FIELDS, ["version", "time", "pressures", "buildings", "npcs", "wheels"], errors)
	if pack.has("version") and not pack["version"] is String:
		errors.append("pack.version: expected string")
	var structural_error := false
	for key in ["time", "pressures", "influence", "buildings", "npcs", "strangers", "building_decks", "communication", "rumors", "institutions", "difficulty", "balance", "prices", "initial", "visit_config"]:
		if pack.has(key) and not _dictionary(pack[key], "pack." + key, errors):
			structural_error = true
	for key in ["living_costs", "wheels", "norms", "spine", "places"]:
		if pack.has(key) and not _array(pack[key], "pack." + key, errors):
			structural_error = true
	if structural_error:
		return errors
	var time: Dictionary = pack.get("time", {})
	if not time.get("slots", []) is Array or not time.get("slot_hours", []) is Array:
		errors.append("pack.time: slots and slot_hours must be arrays")
		return errors
	_validate_time(pack.get("time", {}), errors)
	_validate_pressures(pack.get("pressures", {}), errors)
	_validate_buildings(pack.get("buildings", {}), pack, errors)
	_validate_npcs(pack.get("npcs", {}), pack, errors)
	_validate_influence(pack.get("influence", {}), pack, errors)
	_validate_costs(pack.get("living_costs", []), pack, errors)
	var wheels = pack.get("wheels", [])
	if _array(wheels, "pack.wheels", errors):
		var ids: Dictionary = {}
		for index in range(wheels.size()):
			var path: String = "pack.wheels[%d]" % index
			_wheel(wheels[index], path, pack, errors, false)
			if wheels[index] is Dictionary:
				_unique(str(wheels[index].get("id", "")), path + ".id", ids, errors)
	var decks = pack.get("building_decks", {})
	if _dictionary(decks, "pack.building_decks", errors):
		for id in _keys(decks):
			_reference(id, pack.get("buildings", {}), "pack.building_decks." + str(id), errors)
			_wheel(decks[id], "pack.building_decks." + str(id), pack, errors, true)
	_validate_strangers(pack.get("strangers", {}), pack, errors)
	_validate_communication(pack.get("communication", {}), errors)
	_validate_rumors(pack.get("rumors", {}), errors)
	_validate_norms(pack.get("norms", []), pack, errors)
	_validate_institutions(pack.get("institutions", {}), pack, errors)
	_validate_difficulty(pack.get("difficulty", {}), pack, errors)
	_validate_spine(pack.get("spine", []), pack, errors)
	_validate_prices(pack.get("prices", {}), pack, errors)
	_validate_balance(pack.get("balance", {}), errors)
	if pack.has("visit_config"):
		_validate_visit_config(pack["visit_config"], errors)
	if pack.has("initial"):
		var initial = pack["initial"]
		if _dictionary(initial, "pack.initial", errors):
			_fields(initial, "pack.initial", ["weather", "stats", "flags", "cash"], [], errors)
			if initial.has("weather") and not initial["weather"] is String:
				errors.append("pack.initial.weather: expected string")
			for key in ["stats", "flags", "cash"]:
				if initial.has(key):
					_dictionary(initial[key], "pack.initial." + key, errors)
	if pack.has("places") and _array(pack["places"], "pack.places", errors):
		for place in pack["places"]:
			if not place is String or place.is_empty():
				errors.append("pack.places: expected nonempty place names")
	return errors

static func _validate_time(value, errors: Array) -> void:
	var path := "pack.time"
	if not _dictionary(value, path, errors): return
	_fields(value, path, ["slots", "slot_hours", "season_days", "start_weekday", "season_count", "wake_minute", "curfew_minute", "sleep_minute", "minute_seconds", "market_period_days", "market_offset"], ["slots", "slot_hours", "season_days", "start_weekday"], errors)
	if not value.has("slots") or not value.has("slot_hours"):
		return
	for key in ["season_days", "season_count", "market_period_days"]:
		if value.has(key): _numeric(value[key], path + "." + key, errors, 1.0, true)
	for key in ["wake_minute", "curfew_minute", "sleep_minute", "market_offset"]:
		if value.has(key): _numeric(value[key], path + "." + key, errors, 0.0, true)
	if value.has("start_weekday"):
		_bounded(value["start_weekday"], path + ".start_weekday", 0, 6, errors, true)
	if value.has("minute_seconds"): _numeric(value["minute_seconds"], path + ".minute_seconds", errors, 0.000001)
	if not value.get("slots", []) is Array or not value.get("slot_hours", []) is Array:
		errors.append(path + ": slots and slot_hours must be arrays")
	elif value["slots"].is_empty() or value["slots"].size() != value["slot_hours"].size():
		errors.append(path + ": matching nonempty slot arrays required")
	else:
		var previous: float = -1.0
		for hour in value["slot_hours"]:
			_bounded(hour, path + ".slot_hours", 0, 23, errors, true)
			if _number(hour) and float(hour) <= previous: errors.append(path + ".slot_hours: must increase")
			if _number(hour): previous = float(hour)

static func _validate_pressures(value, errors: Array) -> void:
	if not _dictionary(value, "pack.pressures", errors): return
	for key in _keys(value):
		var path: String = "pack.pressures." + str(key)
		var row = value[key]
		if not _dictionary(row, path, errors): continue
		_fields(row, path, ["kind", "base", "min", "max", "revert", "noise", "half_life_days"], ["kind", "base", "min", "max"], errors)
		_enum(row.get("kind"), ["exogenous", "endogenous"], path + ".kind", errors)
		for name in ["base", "min", "max", "revert", "noise"]:
			if row.has(name): _numeric(row[name], path + "." + name, errors)
		if str(row.get("kind", "")) == "endogenous":
			if not row.has("half_life_days"): errors.append(path + ": half_life_days required")
			else: _numeric(row["half_life_days"], path + ".half_life_days", errors, 0.000001)
		if _number(row.get("min")) and _number(row.get("max")):
			if float(row["min"]) > float(row["max"]): errors.append(path + ": min exceeds max")
			if _number(row.get("base")) and (float(row["base"]) < float(row["min"]) or float(row["base"]) > float(row["max"])): errors.append(path + ": base outside bounds")

static func _validate_buildings(value, pack: Dictionary, errors: Array) -> void:
	if not _dictionary(value, "pack.buildings", errors): return
	for id in _keys(value):
		var path: String = "pack.buildings." + str(id)
		var row = value[id]
		if not _dictionary(row, path, errors): continue
		_fields(row, path, ["name", "kind", "hours", "keeper", "unlock", "news", "map_object", "unlocked", "tags", "market_only"], ["name", "kind", "hours", "keeper", "unlock", "news", "map_object"], errors)
		_enum(row.get("kind"), ["walkable", "closeup", "locked_visible"], path + ".kind", errors)
		if str(row.get("kind", "")) == "walkable" and id != "pawnshop": errors.append(path + ": only pawnshop is walkable")
		for key in ["name", "keeper", "news", "map_object"]:
			if row.has(key) and not row[key] is String: errors.append(path + "." + key + ": expected string")
		if str(row.get("keeper", "")) != "": _reference(row["keeper"], pack.get("npcs", {}), path + ".keeper", errors)
		if row.has("unlock"): _condition(row["unlock"], path + ".unlock", pack, errors, false)
		var hours = row.get("hours", [])
		if hours is Dictionary:
			for period in _keys(hours):
				if period != "default" and not _schedule_key(str(period), false): errors.append(path + ".hours: unknown key " + str(period))
				_hours(hours[period], path + ".hours." + str(period), errors)
		else: _hours(hours, path + ".hours", errors)
		for key in ["unlocked", "market_only"]:
			if row.has(key) and not row[key] is bool: errors.append(path + "." + key + ": expected bool")
		if row.has("tags"): _array(row["tags"], path + ".tags", errors)

static func _validate_npcs(value, pack: Dictionary, errors: Array) -> void:
	if not _dictionary(value, "pack.npcs", errors): return
	for id in _keys(value):
		var path: String = "pack.npcs." + str(id)
		var row = value[id]
		if not _dictionary(row, path, errors): continue
		_fields(row, path, ["name", "home", "roles", "cash", "links", "schedule", "visit", "requires_building", "portrait"], ["schedule", "visit", "links"], errors)
		if row.has("cash"): _numeric(row["cash"], path + ".cash", errors, 0, true)
		if row.has("roles"): _array(row["roles"], path + ".roles", errors)
		if row.has("requires_building"): _reference(row["requires_building"], pack.get("buildings", {}), path + ".requires_building", errors)
		var links = row.get("links", {})
		if _dictionary(links, path + ".links", errors):
			for other in _keys(links):
				_reference(other, value, path + ".links." + str(other), errors)
				_bounded(links[other], path + ".links." + str(other), 0, 1, errors)
		var schedule = row.get("schedule", {})
		if _dictionary(schedule, path + ".schedule", errors):
			if not schedule.has("default"): errors.append(path + ".schedule: default required")
			for key in _keys(schedule):
				if key != "default" and not _schedule_key(str(key), true): errors.append(path + ".schedule: unknown key " + str(key))
				if _array(schedule[key], path + ".schedule." + str(key), errors):
					if schedule[key].size() != pack.get("time", {}).get("slots", []).size(): errors.append(path + ".schedule." + str(key) + ": one place per slot required")
					for place in schedule[key]:
						if not place is String or (pack.has("places") and place not in pack["places"]): errors.append(path + ".schedule: unknown place " + str(place))
		var visit = row.get("visit", {})
		if _dictionary(visit, path + ".visit", errors):
			_fields(visit, path + ".visit", ["base", "need_scale", "intents", "heat_gain", "when"], ["base", "need_scale", "intents"], errors)
			if visit.has("base"): _bounded(visit["base"], path + ".visit.base", 0, 1, errors)
			if visit.has("need_scale"): _numeric(visit["need_scale"], path + ".visit.need_scale", errors, 0.000001)
			if visit.has("heat_gain"): _numeric(visit["heat_gain"], path + ".visit.heat_gain", errors, 0)
			if visit.has("when"): _condition(visit["when"], path + ".visit.when", pack, errors, false)
			_weights(visit.get("intents", {}), path + ".visit.intents", errors)

static func _validate_influence(value, pack: Dictionary, errors: Array) -> void:
	if not _dictionary(value, "pack.influence", errors): return
	_fields(value, "pack.influence", ["daily_cap", "feeds"], [], errors)
	var caps = value.get("daily_cap", {})
	if _dictionary(caps, "pack.influence.daily_cap", errors):
		for key in _keys(caps):
			_reference(key, pack.get("pressures", {}), "pack.influence.daily_cap." + str(key), errors)
			_numeric(caps[key], "pack.influence.daily_cap." + str(key), errors, 0)
			if _pressure_kind(pack, key) != "endogenous": errors.append("pack.influence.daily_cap: only endogenous pressures may receive influence")
	var feeds = value.get("feeds", [])
	if _array(feeds, "pack.influence.feeds", errors):
		for row in feeds:
			if not _dictionary(row, "pack.influence.feeds", errors): continue
			_fields(row, "pack.influence.feeds", ["from", "above", "to", "gain"], ["from", "above", "to", "gain"], errors)
			for key in ["from", "to"]: _reference(row.get(key), pack.get("pressures", {}), "pack.influence.feeds." + key, errors)
			for key in ["above", "gain"]:
				if row.has(key): _numeric(row[key], "pack.influence.feeds." + key, errors)
			if _pressure_kind(pack, row.get("to")) != "endogenous": errors.append("pack.influence.feeds: target must be endogenous")

static func _validate_costs(value, pack: Dictionary, errors: Array) -> void:
	if not _array(value, "pack.living_costs", errors): return
	var ids: Dictionary = {}
	for index in range(value.size()):
		var path: String = "pack.living_costs[%d]" % index
		var row = value[index]
		if not _dictionary(row, path, errors): continue
		_fields(row, path, ["id", "label", "period", "base", "scale", "jitter", "payee", "building", "when", "weekday", "season_mult", "weather_mult", "min", "max", "due_day", "month_day", "announce_days", "due_days", "grace_days", "late_effects"], ["id", "label", "period", "base", "scale", "jitter", "payee", "building", "when"], errors)
		_unique(str(row.get("id", "")), path + ".id", ids, errors)
		_enum(row.get("period"), ["daily", "weekly", "monthly", "once", "event", "contract"], path + ".period", errors)
		for key in ["base", "min", "max", "jitter", "announce_days", "due_days", "grace_days"]:
			if row.has(key): _numeric(row[key], path + "." + key, errors, 0)
		if row.has("min") and row.has("max") and _number(row["min"]) and _number(row["max"]) and float(row["min"]) > float(row["max"]): errors.append(path + ": min exceeds max")
		if str(row.get("scale", "")) != "": _reference(row["scale"], pack.get("pressures", {}), path + ".scale", errors)
		if row.has("building"): _reference(row["building"], pack.get("buildings", {}), path + ".building", errors)
		if row.has("when"): _condition(row["when"], path + ".when", pack, errors, false)
		if row.has("weekday"): _bounded(row["weekday"], path + ".weekday", 0, 6, errors, true)
		if row.has("season_mult"): _number_array(row["season_mult"], path + ".season_mult", errors, _safe_int(pack.get("time", {}).get("season_count", 4), 4))
		if row.has("weather_mult") and _dictionary(row["weather_mult"], path + ".weather_mult", errors):
			for weather in _keys(row["weather_mult"]): _numeric(row["weather_mult"][weather], path + ".weather_mult." + str(weather), errors, 0)
		if row.has("late_effects") and _array(row["late_effects"], path + ".late_effects", errors):
			for effect in row["late_effects"]:
				if not effect is Dictionary:
					errors.append(path + ".late_effects: expected dictionary")
					continue
				if effect.has("after_days"): _numeric(effect["after_days"], path + ".late_effects.after_days", errors, 0, true)
				var actual: Dictionary = effect.duplicate()
				actual.erase("after_days")
				_effect(actual, path + ".late_effects", pack, errors, "endogenous")

static func _wheel(value, path: String, pack: Dictionary, errors: Array, deck: bool) -> void:
	if not _dictionary(value, path, errors): return
	_fields(value, path, ["id", "period", "mode", "outcomes", "building", "when", "requires_building"], ["period", "outcomes"] if deck else ["id", "period", "mode", "outcomes"], errors)
	_enum(value.get("period"), ["day", "slot"], path + ".period", errors)
	var mode: String = str(value.get("mode", "endogenous" if deck else "exogenous"))
	_enum(mode, ["exogenous", "endogenous"], path + ".mode", errors)
	if deck and mode != "endogenous": errors.append(path + ": building decks must be endogenous")
	if value.has("when"): _condition(value["when"], path + ".when", pack, errors, mode == "exogenous")
	if value.has("requires_building") or value.has("building"):
		if mode == "exogenous": errors.append(path + ": exogenous wheel cannot read building state")
		for key in ["requires_building", "building"]:
			if value.has(key): _reference(value[key], pack.get("buildings", {}), path + "." + key, errors)
	var outcomes = value.get("outcomes", [])
	if not _array(outcomes, path + ".outcomes", errors): return
	var has_quiet := false
	var ids: Dictionary = {}
	for index in range(outcomes.size()):
		var where: String = "%s.outcomes[%d]" % [path, index]
		var row = outcomes[index]
		if not _dictionary(row, where, errors): continue
		_fields(row, where, ["id", "weight", "cooldown_days", "effects", "pressure", "when", "requires_building", "season_weights"], ["id", "weight", "cooldown_days", "effects"], errors)
		_unique(str(row.get("id", "")), where + ".id", ids, errors)
		if row.has("weight"): _numeric(row["weight"], where + ".weight", errors, 0)
		if row.has("cooldown_days"): _numeric(row["cooldown_days"], where + ".cooldown_days", errors, 0, true)
		if row.has("when"): _condition(row["when"], where + ".when", pack, errors, mode == "exogenous")
		if row.has("requires_building"):
			_reference(row["requires_building"], pack.get("buildings", {}), where + ".requires_building", errors)
			if mode == "exogenous": errors.append(where + ": exogenous outcome cannot read building state")
		if row.has("pressure") and _dictionary(row["pressure"], where + ".pressure", errors):
			for key in _keys(row["pressure"]):
				_reference(key, pack.get("pressures", {}), where + ".pressure." + str(key), errors)
				if mode == "exogenous" and _pressure_kind(pack, key) == "endogenous": errors.append(where + ": exogenous outcome cannot read endogenous pressure " + str(key))
				var spec = row["pressure"][key]
				if _dictionary(spec, where + ".pressure." + str(key), errors):
					_fields(spec, where + ".pressure." + str(key), ["bias", "min", "max"], [], errors)
					for field in _keys(spec): _numeric(spec[field], where + ".pressure." + str(key) + "." + str(field), errors)
		if row.has("season_weights"): _number_array(row["season_weights"], where + ".season_weights", errors, _safe_int(pack.get("time", {}).get("season_count", 4), 4))
		var effects = row.get("effects", [])
		if _array(effects, where + ".effects", errors):
			for effect in effects: _effect(effect, where + ".effects", pack, errors, mode)
		if str(row.get("id", "")) == "quiet":
			has_quiet = _number(row.get("weight")) and float(row["weight"]) > 0 and _safe_int(row.get("cooldown_days", -1), -1) == 0 and effects is Array and effects.is_empty() and not row.has("pressure") and not row.has("when") and not row.has("requires_building")
			if has_quiet and row.has("season_weights"):
				if not row["season_weights"] is Array: has_quiet = false
				else:
					for weight in row["season_weights"]:
						if not _number(weight) or float(weight) <= 0: has_quiet = false
	if not has_quiet: errors.append(path + ": requires positive, ungated, cooldown-free, effect-free quiet outcome")

static func _condition(value, path: String, pack: Dictionary, errors: Array, exogenous: bool) -> void:
	if value == null: return
	if not _dictionary(value, path, errors): return
	if value.is_empty(): return
	_fields(value, path, CONDITION_OPS, [], errors)
	if value.size() != 1:
		errors.append(path + ": condition needs exactly one operator")
		return
	var op: String = str(value.keys()[0])
	var arg = value[op]
	if exogenous and op in ["flag", "stat_gte", "building", "npc_rel_gte"]: errors.append(path + ": exogenous condition cannot read " + op)
	match op:
		"all", "any":
			if _array(arg, path + "." + op, errors):
				for index in range(arg.size()): _condition(arg[index], "%s.%s[%d]" % [path, op, index], pack, errors, exogenous)
		"not": _condition(arg, path + ".not", pack, errors, exogenous)
		"day_gte": _numeric(arg, path + ".day_gte", errors, 0, true)
		"weekday": _bounded(arg, path + ".weekday", 0, 6, errors, true)
		"season": _bounded(arg, path + ".season", 0, _safe_int(pack.get("time", {}).get("season_count", 4), 4) - 1, errors, true)
		"weather", "flag":
			if not arg is String or arg.is_empty(): errors.append(path + "." + op + ": expected nonempty string")
		"building": _reference(arg, pack.get("buildings", {}), path + ".building", errors)
		"stat_gte", "pressure_gte":
			if not arg is Array or arg.size() != 2 or not arg[0] is String or not _number(arg[1]):
				errors.append(path + "." + op + ": expected [key, number]")
			elif op == "pressure_gte":
				_reference(arg[0], pack.get("pressures", {}), path + ".pressure_gte", errors)
				if exogenous and _pressure_kind(pack, arg[0]) == "endogenous": errors.append(path + ": exogenous condition cannot read endogenous pressure " + str(arg[0]))
		"npc_rel_gte":
			if not arg is Array or arg.size() != 3 or not arg[0] is String or not arg[1] is String or not _number(arg[2]): errors.append(path + ".npc_rel_gte: expected [npc, relationship, number]")
			else: _reference(arg[0], pack.get("npcs", {}), path + ".npc_rel_gte", errors)

static func _effect(value, path: String, pack: Dictionary, errors: Array, mode: String) -> void:
	if not _dictionary(value, path, errors): return
	var op: String = str(value.get("op", ""))
	if not EFFECT_FIELDS.has(op):
		errors.append(path + ": unknown effect op " + op)
		return
	var allowed: Array = ["op", "when"] + EFFECT_FIELDS[op]
	_fields(value, path, allowed, ["op"], errors)
	if value.has("when"): _condition(value["when"], path + ".when", pack, errors, mode == "exogenous")
	match op:
		"weather":
			if not value.get("value") is String: errors.append(path + ": weather value must be a string")
			if mode == "endogenous": errors.append(path + ": endogenous effects cannot rewrite weather")
		"pressure_add":
			_reference(value.get("key"), pack.get("pressures", {}), path + ".key", errors)
			_numeric(value.get("value"), path + ".value", errors)
			if mode == "endogenous" and _pressure_kind(pack, value.get("key")) == "exogenous": errors.append(path + ": endogenous effects cannot rewrite exogenous pressure")
		"flag_today", "flag_set":
			if not value.get("key") is String: errors.append(path + ": flag key must be a string")
		"news":
			if not value.get("text") is String: errors.append(path + ": news text must be a string")
		"bill":
			for key in ["label", "payee"]:
				if not value.get(key) is String: errors.append(path + ": bill " + key + " required")
			if value.has("amount"): _numeric(value["amount"], path + ".amount", errors, 0)
			elif value.has("min") and value.has("max"):
				_numeric(value["min"], path + ".min", errors, 0)
				_numeric(value["max"], path + ".max", errors, 0)
				if _number(value["min"]) and _number(value["max"]) and float(value["min"]) > float(value["max"]): errors.append(path + ": bill min exceeds max")
			else: errors.append(path + ": bill amount or min/max required")
		"rumor":
			_reference(value.get("key"), pack.get("rumors", {}), path + ".key", errors)
			_reference(value.get("origin"), pack.get("npcs", {}), path + ".origin", errors)
		"unlock": _reference(value.get("building"), pack.get("buildings", {}), path + ".building", errors)
		"institution":
			_reference(value.get("id"), pack.get("institutions", {}), path + ".id", errors)
			_reference(value.get("act"), pack.get("institutions", {}).get(value.get("id"), {}).get("acts", {}), path + ".act", errors)
		"spawn_visit":
			if not value.get("who") is String or not value.get("intent") is String: errors.append(path + ": visit who and intent required")
		"npc_feel":
			if not value.get("key") is String: errors.append(path + ": feeling key required")
			_numeric(value.get("value"), path + ".value", errors)
		"invitation":
			if value.has("lead_days"): _number_array(value["lead_days"], path + ".lead_days", errors, 2)
	for key in ["due_days", "grace_days", "delay_days", "count"]:
		if value.has(key): _numeric(value[key], path + "." + key, errors, 0, true)

static func _validate_strangers(value, pack: Dictionary, errors: Array) -> void:
	if not _dictionary(value, "pack.strangers", errors): return
	_fields(value, "pack.strangers", ["per_day", "archetypes"], [], errors)
	var per_day = value.get("per_day", {})
	if _dictionary(per_day, "pack.strangers.per_day", errors):
		_fields(per_day, "pack.strangers.per_day", ["base", "unrest_gain", "market_day_bonus", "min", "max"], [], errors)
		for key in _keys(per_day): _numeric(per_day[key], "pack.strangers.per_day." + str(key), errors, 0)
	var rows = value.get("archetypes", [])
	if _array(rows, "pack.strangers.archetypes", errors):
		var ids: Dictionary = {}
		for row in rows:
			if not _dictionary(row, "pack.strangers.archetypes", errors): continue
			_fields(row, "pack.strangers.archetypes", ["id", "name", "cash", "weight", "unrest_bias", "intents", "norm", "requires_building"], ["id", "weight", "intents"], errors)
			if row.has("cash"): _numeric(row["cash"], "pack.strangers.archetypes.cash", errors, 0, true)
			_unique(str(row.get("id", "")), "pack.strangers.archetypes.id", ids, errors)
			if row.has("weight"): _numeric(row["weight"], "pack.strangers.archetypes.weight", errors, 0)
			if row.has("unrest_bias"): _numeric(row["unrest_bias"], "pack.strangers.archetypes.unrest_bias", errors)
			if row.has("requires_building"): _reference(row["requires_building"], pack.get("buildings", {}), "pack.strangers.archetypes.requires_building", errors)
			_weights(row.get("intents", {}), "pack.strangers.archetypes.intents", errors)

static func _validate_communication(value, errors: Array) -> void:
	if not _dictionary(value, "pack.communication", errors): return
	_fields(value, "pack.communication", ["delay_slots", "confidence_decay", "relay_probability", "max_hops", "ttl_slots", "min_confidence"], [], errors)
	for key in ["delay_slots", "max_hops", "ttl_slots"]:
		if value.has(key): _numeric(value[key], "pack.communication." + key, errors, 0, true)
	for key in ["confidence_decay", "relay_probability", "min_confidence"]:
		if value.has(key): _bounded(value[key], "pack.communication." + key, 0, 1, errors)

static func _validate_rumors(value, errors: Array) -> void:
	if not _dictionary(value, "pack.rumors", errors): return
	for key in _keys(value):
		if _array(value[key], "pack.rumors." + str(key), errors):
			if value[key].is_empty(): errors.append("pack.rumors." + str(key) + ": at least one wording required")
			for wording in value[key]:
				if not wording is String: errors.append("pack.rumors." + str(key) + ": wording must be a string")

static func _validate_norms(value, pack: Dictionary, errors: Array) -> void:
	if not _array(value, "pack.norms", errors): return
	var ids: Dictionary = {}
	for row in value:
		if not _dictionary(row, "pack.norms", errors): continue
		_fields(row, "pack.norms", ["id", "act", "building", "detect_probability", "forgiveness", "heat", "rumor", "authority_building", "when"], ["id", "act", "building"], errors)
		_unique(str(row.get("id", "")), "pack.norms.id", ids, errors)
		for key in ["detect_probability", "forgiveness"]:
			if row.has(key): _bounded(row[key], "pack.norms." + key, 0, 1, errors)
		if row.has("heat"): _numeric(row["heat"], "pack.norms.heat", errors, 0)
		if row.has("rumor"): _reference(row["rumor"], pack.get("rumors", {}), "pack.norms.rumor", errors)
		if row.has("authority_building"): _reference(row["authority_building"], pack.get("buildings", {}), "pack.norms.authority_building", errors)
		if row.has("when"): _condition(row["when"], "pack.norms.when", pack, errors, false)

static func _validate_institutions(value, pack: Dictionary, errors: Array) -> void:
	if not _dictionary(value, "pack.institutions", errors): return
	for id in _keys(value):
		var path: String = "pack.institutions." + str(id)
		var row = value[id]
		if not _dictionary(row, path, errors): continue
		_fields(row, path, ["building", "acts"], ["building", "acts"], errors)
		_reference(row.get("building"), pack.get("buildings", {}), path + ".building", errors)
		var acts = row.get("acts", {})
		if _dictionary(acts, path + ".acts", errors):
			for act in _keys(acts):
				var spec = acts[act]
				if not _dictionary(spec, path + ".acts." + str(act), errors): continue
				_fields(spec, path + ".acts." + str(act), ["fine_min", "fine_max", "confiscate", "news", "building", "grace_days", "effects"], [], errors)
				for key in ["fine_min", "fine_max", "grace_days"]:
					if spec.has(key): _numeric(spec[key], path + ".acts." + str(act) + "." + key, errors, 0, true)
				if spec.has("effects") and _array(spec["effects"], path + ".acts.effects", errors):
					for effect in spec["effects"]: _effect(effect, path + ".acts.effects", pack, errors, "endogenous")

static func _validate_difficulty(value, pack: Dictionary, errors: Array) -> void:
	if not _dictionary(value, "pack.difficulty", errors): return
	for name in _keys(value):
		var path: String = "pack.difficulty." + str(name)
		var row = value[name]
		if not _dictionary(row, path, errors): continue
		_fields(row, path, ["cost_mult", "wheel_tempo", "pressure_noise_mult", "initial_cash", "visit_mult"], ["cost_mult", "wheel_tempo", "pressure_noise_mult", "initial_cash", "visit_mult"], errors)
		for key in _keys(row): _numeric(row[key], path + "." + str(key), errors, 0)
	if pack.has("default_difficulty"): _reference(pack["default_difficulty"], value, "pack.default_difficulty", errors)

static func _validate_spine(value, pack: Dictionary, errors: Array) -> void:
	if not _array(value, "pack.spine", errors): return
	var ids: Dictionary = {}
	for row in value:
		if not _dictionary(row, "pack.spine", errors): continue
		_fields(row, "pack.spine", ["day", "id", "effects"], ["day", "id", "effects"], errors)
		_unique(str(row.get("id", "")), "pack.spine.id", ids, errors)
		if row.has("day"): _numeric(row["day"], "pack.spine.day", errors, 0, true)
		if _array(row.get("effects", []), "pack.spine.effects", errors):
			for effect in row.get("effects", []): _effect(effect, "pack.spine.effects", pack, errors, "endogenous")

static func _validate_prices(value, pack: Dictionary, errors: Array) -> void:
	if not _dictionary(value, "pack.prices", errors): return
	for category in _keys(value):
		var path: String = "pack.prices." + str(category)
		var row = value[category]
		if not _dictionary(row, path, errors): continue
		_fields(row, path, ["base", "scale"], ["base", "scale"], errors)
		if row.has("base"): _numeric(row["base"], path + ".base", errors, 0)
		if str(row.get("scale", "")) != "": _reference(row["scale"], pack.get("pressures", {}), path + ".scale", errors)

static func _validate_balance(value, errors: Array) -> void:
	if not _dictionary(value, "pack.balance", errors): return
	_fields(value, "pack.balance", ["pressure", "costs", "institutions", "items", "contract_grace_days", "initial_stats"], [], errors)
	if value.has("contract_grace_days"): _numeric(value["contract_grace_days"], "pack.balance.contract_grace_days", errors, 0, true)
	if value.has("initial_stats") and _dictionary(value["initial_stats"], "pack.balance.initial_stats", errors):
		for key in _keys(value["initial_stats"]): _numeric(value["initial_stats"][key], "pack.balance.initial_stats." + str(key), errors)
	var groups: Dictionary = {
		"pressure": ["feed_gain_scale"],
		"costs": ["month_days", "overdue_heat", "sickness_after_unpaid_days", "default_grace_days", "hunger_per_unpaid_day", "fatigue_per_unpaid_day", "medicine_worsening_after_days", "rent_warning_after_days"],
		"institutions": ["report_heat_relief", "curfew_heat", "gift_relation_gain", "default_norm_confidence", "forgiveness_relation_scale"]
	}
	for group in _keys(groups):
		if not value.has(group): continue
		if not _dictionary(value[group], "pack.balance." + str(group), errors): continue
		_fields(value[group], "pack.balance." + str(group), groups[group], [], errors)
		for key in _keys(value[group]): _numeric(value[group][key], "pack.balance." + str(group) + "." + str(key), errors, 0)
	if value.has("items"):
		var items = value["items"]
		if not _dictionary(items, "pack.balance.items", errors): return
		var arrays: Array = ["condition", "estimate", "inspect_estimate", "buy_ask", "buy_floor", "pawn_ask", "pawn_floor", "sell_offer", "sell_max"]
		var numbers: Array = ["condition_floor", "fake_rate", "fake_value_mult", "stolen_rate", "rare_rate", "rare_gain_per_day", "rare_rate_max", "rare_mult", "rare_pity_after", "rare_pity_gain", "buy_suggest", "pawn_suggest", "pawn_days", "pawn_rate", "buyer_item_limit"]
		_fields(items, "pack.balance.items", arrays + numbers + ["quality"], [], errors)
		for key in arrays:
			if items.has(key):
				_number_array(items[key], "pack.balance.items." + str(key), errors, 2)
				if items[key] is Array and items[key].size() == 2 and _number(items[key][0]) and _number(items[key][1]) and float(items[key][0]) > float(items[key][1]): errors.append("pack.balance.items." + str(key) + ": range must increase")
		for key in numbers:
			if items.has(key): _numeric(items[key], "pack.balance.items." + str(key), errors, 0)
		if items.has("quality") and _array(items["quality"], "pack.balance.items.quality", errors):
			for quality in items["quality"]:
				if not _dictionary(quality, "pack.balance.items.quality", errors): continue
				_fields(quality, "pack.balance.items.quality", ["id", "weight", "mult"], ["id", "weight", "mult"], errors)
				for key in ["weight", "mult"]:
					if quality.has(key): _numeric(quality[key], "pack.balance.items.quality." + key, errors, 0)

static func _validate_visit_config(value, errors: Array) -> void:
	if not _dictionary(value, "pack.visit_config", errors): return
	var fields: Array = ["need_gain", "rumor_gain", "rumor_cap", "max_probability", "slot_at_pawnshop_weight", "slot_other_weight", "slots", "patience_min", "companion_probability", "min_per_day", "ticket_visit_gain", "market_visit_gain", "rain_visit_penalty", "pawn_need_base", "inspect_heat_gain", "companion_max", "minute_jitter"]
	_fields(value, "pack.visit_config", fields, [], errors)
	for key in _keys(value):
		if key == "slots": _number_array(value[key], "pack.visit_config.slots", errors)
		elif key == "patience_min": _number_array(value[key], "pack.visit_config.patience_min", errors, 2)
		else: _numeric(value[key], "pack.visit_config." + str(key), errors, 0)

static func _dictionary(value, path: String, errors: Array) -> bool:
	if value is Dictionary: return true
	errors.append(path + ": expected dictionary")
	return false

static func _array(value, path: String, errors: Array) -> bool:
	if value is Array: return true
	errors.append(path + ": expected array")
	return false

static func _fields(value: Dictionary, path: String, allowed: Array, required: Array, errors: Array) -> void:
	for key in _keys(value):
		if key not in allowed: errors.append(path + ": unknown field " + str(key))
	for key in required:
		if not value.has(key): errors.append(path + ": missing field " + str(key))

static func _number(value) -> bool:
	return (value is int or value is float) and is_finite(float(value))

static func _numeric(value, path: String, errors: Array, minimum: float = -INF, integral: bool = false) -> void:
	if not _number(value):
		errors.append(path + ": expected finite number")
	elif float(value) < minimum or (integral and float(value) != floor(float(value))):
		errors.append(path + ": invalid numeric value")

static func _bounded(value, path: String, minimum: float, maximum: float, errors: Array, integral: bool = false) -> void:
	_numeric(value, path, errors, minimum, integral)
	if _number(value) and float(value) > maximum: errors.append(path + ": exceeds maximum")

static func _number_array(value, path: String, errors: Array, length: int = -1) -> void:
	if not _array(value, path, errors): return
	if length >= 0 and value.size() != length: errors.append(path + ": invalid array length")
	for number in value: _numeric(number, path, errors, 0)

static func _hours(value, path: String, errors: Array) -> void:
	if not _array(value, path, errors): return
	if value.size() != 2:
		errors.append(path + ": expected [open minute, close minute]")
		return
	for minute in value: _bounded(minute, path, 0, 1440, errors, true)
	if _number(value[0]) and _number(value[1]) and float(value[0]) > float(value[1]): errors.append(path + ": opening exceeds closing")

static func _enum(value, choices: Array, path: String, errors: Array) -> void:
	if value not in choices: errors.append(path + ": unsupported value " + str(value))

static func _reference(value, dictionary, path: String, errors: Array) -> void:
	if not value is String or not dictionary is Dictionary or not dictionary.has(value):
		errors.append(path + ": unknown reference " + str(value))

static func _unique(value: String, path: String, ids: Dictionary, errors: Array) -> void:
	if value.is_empty() or ids.has(value): errors.append(path + ": duplicate or empty id")
	ids[value] = true

static func _weights(value, path: String, errors: Array) -> void:
	if not _dictionary(value, path, errors): return
	var total := 0.0
	for key in _keys(value):
		_numeric(value[key], path + "." + str(key), errors, 0)
		if _number(value[key]): total += float(value[key])
	if total <= 0: errors.append(path + ": positive total weight required")

static func _keys(value: Dictionary) -> Array:
	var keys: Array = value.keys()
	keys.sort()
	return keys

static func _schedule_key(key: String, allow_day_weather: bool) -> bool:
	if key.begins_with("weekday:"):
		var number: String = key.trim_prefix("weekday:")
		return number.is_valid_int() and int(number) >= 0 and int(number) <= 6
	if allow_day_weather and key.begins_with("day:"):
		var number: String = key.trim_prefix("day:")
		return number.is_valid_int() and int(number) >= 0
	return allow_day_weather and key.begins_with("weather:") and key.length() > "weather:".length()

static func _pressure_kind(pack: Dictionary, key):
	var spec = pack.get("pressures", {}).get(key, {})
	return str(spec.get("kind", "")) if spec is Dictionary else ""

static func _safe_int(value, fallback: int) -> int:
	return int(value) if _number(value) else fallback
