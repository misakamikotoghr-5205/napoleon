## Standard branch-point opening. It initializes a new run; it never reuses a
## saved army or pretends that skipped battles were fought.
extends RefCounted

const MapRules = preload("res://scripts/cards/campaign/map/map_rules.gd")


static func locate(bundle: Dictionary) -> Dictionary:
	if bool(bundle.get("builtin", true)) or typeof(bundle.get("raw", {}).get("debug_carry", {}).get("branch_point")) != TYPE_DICTIONARY:
		return {}
	var seg := str(bundle.get("start", ""))
	var definition: Dictionary = bundle.get("defs", {}).get(seg, {})
	var found := {}
	for index in definition.get("scenes", []).size():
		var scene: Dictionary = definition["scenes"][index]
		if not (scene.get("choices", []) as Array).any(func(c: Dictionary) -> bool: return str(c.get("branch", "")) != ""):
			continue
		if not found.is_empty():
			return {} # A standard opening must identify one unambiguous fork.
		var chapter := str(scene.get("chapter", ""))
		var stage := -1
		for i in definition.get("chapters", []).size():
			if str(definition["chapters"][i].get("id", "")) == chapter:
				stage = i
		var sheet := MapRules.sheet_of(bundle, seg, chapter)
		var node := ""
		for row in sheet.get("nodes", []):
			if str(row.get("type", "")) == "branch" and str(row.get("scene", "")) == str(scene["id"]):
				node = str(row["id"])
		if stage < 0 or node.is_empty() or int(definition["chapters"][stage].get("volume", 1)) > int(bundle.get("volume", 1)):
			return {}
		found = {"segment": seg, "stage": stage, "scene_index": index, "node": node}
	return found


static func place(campaign, opening: Dictionary) -> void:
	var map: Dictionary = campaign.state["map"]
	var node := str(opening["node"])
	map["pos"] = node
	map["visited"] = [node]
	map["revealed"] = [node]
	map["mustered"] = true
	map["interlude"] = ""
	MapRules.reveal_around(campaign)
	# These are the standard checkpoint's already-earned coins, not new rewards.
	# In particular its ten medals satisfy the same cumulative branch condition.
	var rogue: Dictionary = campaign.state["rogue"]
	for currency in rogue["coins"]:
		rogue["tally"][currency] = int(rogue["coins"][currency])
