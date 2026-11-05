class_name WorldWheel
extends RefCounted

const R = preload("res://scripts/sim/jev_rng.gd")
const Cond = preload("res://scripts/sim/town_cond.gd")


# Pure previews expose normalized probabilities to developer tools and tests;
# they neither draw randomness nor update cooldowns.
static func rows(pack: Dictionary, s: Dictionary, wheel: Dictionary, world = null) -> Array:
	return _normalize(_weights(pack, s, wheel, world))


static func spin(pack: Dictionary, s: Dictionary, wheel: Dictionary, effect: Callable, world = null) -> String:
	var weights: Array = _weights(pack, s, wheel, world)
	var day: int = int(s["day"])
	var wheel_id: String = String(wheel["id"])
	var draw: float = R.draw(int(s["seed"]), "wheel:" + wheel_id, [day])
	# Select using the original weights to preserve prototype floating-point
	# behavior. Normalization is only for the developer log and the preview API.
	var choice: String = R.weighted_choice(weights, draw)
	s["wheel_last"][wheel_id + ":" + choice] = day
	_report(s, "wheels", {
		"day": day,
		"id": wheel_id,
		"mode": String(wheel.get("mode", "exogenous")),
		"choice": choice,
		"draw": draw,
		"probabilities": _normalize(weights),
	})
	var source: String = wheel_id + "/" + choice
	if choice != "quiet":
		_report(s, "events", source)
	for outcome in wheel["outcomes"]:
		if String(outcome["id"]) == choice:
			for entry in outcome["effects"]:
				effect.call(entry, source)
			break
	return choice


static func decks(pack: Dictionary) -> Array:
	var result: Array = []
	var keys: Array = pack.get("building_decks", {}).keys()
	keys.sort()
	for building in keys:
		var deck: Dictionary = pack["building_decks"][building].duplicate(true)
		deck["id"] = "deck:" + String(building)
		deck["building"] = String(building)
		deck["mode"] = "endogenous"
		result.append(deck)
	return result


static func _weights(pack: Dictionary, s: Dictionary, wheel: Dictionary, world) -> Array:
	var result: Array = []
	var wheel_id: String = String(wheel["id"])
	var difficulty: Dictionary = pack.get("difficulty", {}).get(s.get("difficulty", "常年"), {})
	var tempo: float = float(difficulty.get("wheel_tempo", 1.0))
	for outcome in wheel["outcomes"]:
		var outcome_id: String = String(outcome["id"])
		var weight: float = float(outcome["weight"])
		var cooldown_key: String = wheel_id + ":" + outcome_id
		if s["wheel_last"].has(cooldown_key):
			var elapsed: int = int(s["day"]) - int(s["wheel_last"][cooldown_key])
			if elapsed < int(outcome["cooldown_days"]):
				weight = 0.0
		if outcome.has("requires_building") and not bool(s["unlocked"].get(outcome["requires_building"], false)):
			weight = 0.0
		if outcome.has("when") and not Cond.test(outcome["when"], pack, s, world):
			weight = 0.0
		var pressure_keys: Array = outcome.get("pressure", {}).keys()
		pressure_keys.sort()
		for key in pressure_keys:
			var pressure: float = float(s["pressures"][key])
			var bias: Dictionary = outcome["pressure"][key]
			if pressure < float(bias.get("min", 0.0)):
				weight = 0.0
			weight *= maxf(0.0, 1.0 + float(bias.get("bias", 0.0)) * pressure)
		if outcome.has("season_weights"):
			var seasonal: Array = outcome["season_weights"]
			var season: int = int(floor(float(s["day"]) / float(pack["time"]["season_days"]))) % seasonal.size()
			weight *= float(seasonal[season])
		if outcome_id != "quiet":
			weight *= tempo
		result.append([outcome_id, weight])
	return result


static func _normalize(weights: Array) -> Array:
	var total: float = 0.0
	for row in weights:
		total += float(row[1])
	assert(total > 0.0, "WorldWheel: a validated wheel must retain a positive quiet weight")
	var result: Array = []
	for row in weights:
		result.append([String(row[0]), float(row[1]) / total])
	return result


static func _report(s: Dictionary, kind: String, entry: Variant) -> void:
	var report: Dictionary = s["day_report"]
	if not report.has(kind):
		report[kind] = []
	report[kind].append(entry)
