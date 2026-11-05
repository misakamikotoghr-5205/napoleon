class_name PressureModel
extends RefCounted

const R = preload("res://scripts/sim/jev_rng.gd")


# All pressure state belongs to the caller. Updating a pressure never advances a
# shared random stream: only its own day-keyed exogenous draw can add noise.
static func step(pack: Dictionary, s: Dictionary) -> void:
	var keys: Array = pack["pressures"].keys()
	keys.sort()
	var difficulty: Dictionary = pack.get("difficulty", {}).get(s.get("difficulty", "常年"), {})
	var noise_mult: float = float(difficulty.get("pressure_noise_mult", 1.0))
	for key in keys:
		var spec: Dictionary = pack["pressures"][key]
		var base: float = float(spec["base"])
		var value: float = float(s["pressures"][key])
		if spec["kind"] == "endogenous":
			value = base + (value - base) * pow(2.0, -1.0 / float(spec["half_life_days"]))
		else:
			value += float(spec.get("revert", 0.0)) * (base - value)
			var draw: float = R.draw(int(s["seed"]), "pressure:" + String(key), [int(s["day"])])
			value += float(spec.get("noise", 0.0)) * noise_mult * (2.0 * draw - 1.0)
		s["pressures"][key] = clampf(value, float(spec["min"]), float(spec["max"]))


static func add_influence(pack: Dictionary, s: Dictionary, key: String, amount: float, source: String) -> float:
	if not pack["pressures"].has(key):
		push_error("PressureModel: unknown pressure " + key)
		return 0.0
	var spec: Dictionary = pack["pressures"][key]
	if spec["kind"] != "endogenous":
		push_error("PressureModel: influence cannot alter exogenous pressure " + key)
		return 0.0
	var cap: float = float(pack["influence"]["daily_cap"].get(key, 0.0))
	var bucket: String = "%d:%s" % [int(s["day"]), key]
	var spent: float = float(s["influence_spent"].get(bucket, 0.0))
	var accepted: float = signf(amount) * minf(absf(amount), maxf(0.0, cap - spent))
	# Charge both signs against the same cap, including influence absorbed by a
	# bound. Repeating an action cannot bypass the world's daily limit.
	s["influence_spent"][bucket] = spent + absf(accepted)
	s["pressures"][key] = clampf(float(s["pressures"][key]) + accepted, float(spec["min"]), float(spec["max"]))
	_report(s, "influence", "%s %+.3f (%s)" % [key, accepted, source])
	return accepted


static func feeds(pack: Dictionary, s: Dictionary) -> void:
	var gain_scale: float = float(pack["balance"]["pressure"]["feed_gain_scale"])
	for feed in pack["influence"].get("feeds", []):
		var value: float = float(s["pressures"][feed["from"]])
		if value > float(feed["above"]):
			var amount: float = (value - float(feed["above"])) * float(feed["gain"]) * gain_scale
			add_influence(pack, s, String(feed["to"]), amount, "feed:" + String(feed["from"]))


static func _report(s: Dictionary, kind: String, entry: Variant) -> void:
	var report: Dictionary = s["day_report"]
	if not report.has(kind):
		report[kind] = []
	report[kind].append(entry)
