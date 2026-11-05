## Deterministic test driver for the new maps. Reads public battle view/preview only.
## Counter-battery fire matters on the coastal and coalition maps: deploy an artillery
## unit before spending every opening command point on blockers, then use command cards.
extends RefCounted

const Base = preload("res://scripts/tests/cards/OCEAN/battle_policy.gd")


static func lineup(lu: Dictionary) -> Dictionary:
	var chosen := Base.lineup(lu)
	for row in lu.get("candidates", []):
		if str(row.get("id", "")) in chosen["companions"] and str(row.get("cls", "")) == "artillery":
			return chosen
	var artillery := ""
	for troop in lu.get("troops", []):
		if str(troop.get("cls", "")) != "artillery":
			continue
		var id := str(troop.get("id", ""))
		if id in chosen["troops"]:
			return chosen
		if artillery == "":
			artillery = id
	if artillery == "":
		return chosen
	var count: int = chosen["companions"].size() + chosen["troops"].size()
	if count >= int(lu.get("caps", {}).get("field", 0)):
		if not chosen["troops"].is_empty():
			chosen["troops"].pop_back()
		elif not chosen["companions"].is_empty():
			chosen["companions"].pop_back()
	chosen["troops"].append(artillery)
	return chosen


static func next_action(v: Dictionary, pv: Dictionary) -> Array:
	for card in v.get("hand", []):
		if str(card["id"]) == "emperor" and bool(card["playable"]):
			return ["card", {"index": card["index"]}]
	var artillery := 0
	for unit in v.get("battle_units", []):
		if str(unit["cls"]) == "artillery":
			artillery += 1
	if artillery == 0:
		for unit in v.get("deploy_bar", []):
			if not bool(unit.get("deployable", false)) or str(unit["cls"]) != "artillery":
				continue
			var spot := Base._ranged_spot(v, "artillery")
			if not spot.is_empty():
				return ["deploy", {"unit": unit["uid"], "col": spot[0], "row": spot[1], "facing": spot[2]}]
	var usual := Base.next_action(v, pv)
	if not usual.is_empty():
		return usual
	for card in v.get("hand", []):
		if not bool(card["playable"]):
			continue
		if str(card["id"]) == "bugler":
			for enemy in v.get("enemies", []):
				if str(enemy["type"]) != "gun":
					return ["card", {"index": card["index"], "row": enemy["row"]}]
		if str(card["id"]) == "barrage":
			for unit in v.get("battle_units", []):
				if str(unit["cls"]) != "artillery":
					continue
				for enemy in v.get("enemies", []):
					if [enemy["col"], enemy["row"]] in unit["pattern"]:
						return ["card", {"index": card["index"], "col": enemy["col"], "row": enemy["row"]}]
	return []
