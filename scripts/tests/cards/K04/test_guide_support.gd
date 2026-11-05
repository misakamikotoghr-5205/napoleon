# K04 guide support: common fate can be drawn in stage 1, valences and choices
# exist, and the 1939 stage points at the main goal.
# Contract: docs/handoff_cards/K04_data-1939-world.md (guide checklist).
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")


func _initialize() -> void:
	var t := T.new(self, "K04_guide_support")
	var db := CardDB.load_all()
	t.eq(db.errors(), PackedStringArray(), "card db loads")
	var pool := 0
	var seen := {}
	var with_choices := 0
	var with_slots := 0
	for id in db.ids_of(&"fate"):
		if db.file_of(id) != "era/common/fate.json":
			continue
		var c := db.def(id)
		var eras: Array = c.get("era", [])
		if int(c.get("weight", 0)) > 0 and (eras.has("*") or eras.has("1938")):
			pool += 1
		var valence := str(c.get("valence", ""))
		t.ok(valence == "good" or valence == "bad" or valence == "mixed", "%s valence" % id)
		seen[valence] = true
		var choices: Array = c.get("choices", [])
		if not choices.is_empty():
			with_choices += 1
		if _choice_has_slots(choices):
			with_slots += 1
	t.ok(pool >= 10, "stage-1 fate pool %d" % pool)
	t.ok(seen.has("good") and seen.has("bad") and seen.has("mixed"), "good bad mixed all present")
	t.ok(with_choices >= 4, "fates with choices %d" % with_choices)
	t.ok(with_slots >= 2, "fates with check slots %d" % with_slots)
	var intro: Dictionary = db.stage(1).get("intro", {})
	var gid := str(intro.get("main_goal", ""))
	var goal := db.def(gid)
	t.eq(str(goal.get("id", "")), gid, "main goal id")
	t.ok(bool(goal.get("main", false)), "main goal flag")
	t.eq(str(intro.get("bg", "")), "bg.stage.1939", "stage bg")
	t.finish()


func _choice_has_slots(choices: Array) -> bool:
	for ch in choices:
		if typeof(ch) != TYPE_DICTIONARY:
			continue
		var chk = ch.get("check", null)
		if typeof(chk) != TYPE_DICTIONARY:
			continue
		var slots = chk.get("slots", [])
		if typeof(slots) == TYPE_ARRAY and not (slots as Array).is_empty():
			return true
	return false
