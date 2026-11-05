class_name TownCond
extends RefCounted

# Conditions are data, never evaluated as source code. The pack validator rejects
# unsupported shapes before setup; a malformed runtime condition simply fails.
static func test(c, pack: Dictionary, s: Dictionary, world = null) -> bool:
	if not _valid_shape(c):
		return false
	if c == null:
		return true
	if not c is Dictionary:
		return false
	if c.is_empty():
		return true
	if c.size() != 1:
		return false
	var op: String = str(c.keys()[0])
	var value = c[op]
	match op:
		"all", "any":
			if not value is Array:
				return false
			for child in value:
				var passed: bool = test(child, pack, s, world)
				if op == "all" and not passed:
					return false
				if op == "any" and passed:
					return true
			return op == "all"
		"not":
			return not test(value, pack, s, world)
		"day_gte":
			return _number(value) and int(s.get("day", 0)) >= int(value)
		"weekday":
			if not _number(value):
				return false
			var time: Dictionary = pack.get("time", {})
			return posmod(int(time.get("start_weekday", 0)) + int(s.get("day", 0)), 7) == int(value)
		"season":
			if not _number(value):
				return false
			var time: Dictionary = pack.get("time", {})
			var days: int = int(time.get("season_days", 1))
			if days <= 0:
				return false
			var seasons: int = int(time.get("season_count", 4))
			return posmod(int(floor(float(s.get("day", 0)) / float(days))), maxi(1, seasons)) == int(value)
		"weather":
			return value is String and str(s.get("weather", "")) == value
		"flag":
			if not value is String:
				return false
			var flags: Dictionary = s.get("flags", {})
			if world != null:
				flags = _world_field(world, "flags", {})
			return bool(flags.get(value, false)) or bool(s.get("flags_today", {}).get(value, false))
		"stat_gte":
			if not _pair(value):
				return false
			var current: float = float(s.get("stats", {}).get(value[0], 0.0))
			if world != null:
				var stats: Dictionary = _world_field(world, "stats", {})
				current = float(stats.get(value[0], _world_field(world, str(value[0]), 0.0)))
			return current >= float(value[1])
		"pressure_gte":
			return _pair(value) and float(s.get("pressures", {}).get(value[0], 0.0)) >= float(value[1])
		"building":
			return value is String and bool(s.get("unlocked", {}).get(value, false))
		"npc_rel_gte":
			if not value is Array or value.size() != 3 or not value[0] is String or not value[1] is String or not _number(value[2]):
				return false
			var rel: Dictionary = s.get("npc_rel", {}).get(value[0], {})
			if rel.has("player"):
				rel = rel["player"]
			if world != null:
				var npcs: Dictionary = _world_field(world, "npcs", {})
				rel = npcs.get(value[0], {}).get("rel", {}).get("player", {})
			return float(rel.get(value[1], 0.0)) >= float(value[2])
	return false

static func _world_field(world, name: String, fallback):
	if world is Dictionary:
		return world.get(name, fallback)
	for property in world.get_property_list():
		if str(property["name"]) == name:
			var value = world.get(name)
			return fallback if value == null else value
	return fallback

static func _number(value) -> bool:
	return (value is int or value is float) and is_finite(float(value))

static func _pair(value) -> bool:
	return value is Array and value.size() == 2 and value[0] is String and _number(value[1])

static func _valid_shape(c) -> bool:
	if c == null:
		return true
	if not c is Dictionary:
		return false
	if c.is_empty():
		return true
	if c.size() != 1:
		return false
	var op: String = str(c.keys()[0])
	var value = c[op]
	match op:
		"all", "any":
			if not value is Array:
				return false
			for child in value:
				if not _valid_shape(child):
					return false
			return true
		"not":
			return _valid_shape(value)
		"day_gte", "weekday", "season":
			return _number(value) and float(value) == floor(float(value))
		"weather", "flag", "building":
			return value is String
		"stat_gte", "pressure_gte":
			return _pair(value)
		"npc_rel_gte":
			return value is Array and value.size() == 3 and value[0] is String and value[1] is String and _number(value[2])
	return false
