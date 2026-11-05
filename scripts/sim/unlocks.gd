class_name Unlocks
extends RefCounted

const C = preload("res://scripts/sim/town_cond.gd")

static func check(pack: Dictionary, s: Dictionary, world = null) -> Array:
	if not s.has("unlocked"):
		s["unlocked"] = {}
	var out: Array = []
	var buildings: Dictionary = pack.get("buildings", {})
	var ids: Array = buildings.keys()
	ids.sort()
	for id in ids:
		if bool(s["unlocked"].get(id, false)):
			continue
		var spec: Dictionary = buildings[id]
		if not bool(spec.get("unlocked", false)) and (not spec.has("unlock") or not C.test(spec["unlock"], pack, s, world)):
			continue
		s["unlocked"][id] = true
		out.append(id)
		if not str(spec.get("news", "")).is_empty():
			if not s.has("day_report"):
				s["day_report"] = {}
			if not s["day_report"].has("news"):
				s["day_report"]["news"] = []
			s["day_report"]["news"].append({"day": int(s.get("day", 0)), "minute": int(s.get("minute", 0)),
				"text": str(spec["news"]), "via": str(spec.get("name", id)), "source": "seen", "conf": 1.0})
	return out
