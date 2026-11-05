# K05 guide support: gold cards, launch hook, cross-year story names.
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")

const FILES := [
	"res://data/cards/era/1940/people.json",
	"res://data/cards/era/1940/story.json",
]
const PRIOR := [
	"res://data/cards/era/1938/people.json",
	"res://data/cards/era/1938/story.json",
	"res://data/cards/era/1939/people.json",
	"res://data/cards/era/1939/story.json",
]


func _initialize() -> void:
	var t := T.new(self, "K05_guide_support")
	var cards: Array = []
	for path in FILES:
		var doc = CardState.int_restore(CardDB.read_json(path))
		t.ok(typeof(doc) == TYPE_DICTIONARY, "parse " + path)
		for c in doc.get("cards", []):
			cards.append(c)
	var days := {}
	var nodes := {}
	var saw_changed := false
	var saw_gone := false
	for c in cards:
		if _has_state(c, "changed"):
			saw_changed = true
		if _has_state(c, "gone"):
			saw_gone = true
		if not bool(c.get("gold", false)):
			continue
		var id := str(c.get("id", ""))
		t.eq(str(c.get("type", "")), "person", id + " gold type")
		var node := str(c.get("story_node", ""))
		t.ok(node != "", id + " story_node")
		t.ok(not bool(c.get("keepable", false)), id + " not keepable")
		t.eq(int(c.get("weight", -1)), 0, id + " weight")
		var day := int(c.get("schedule", {}).get("stage_day", 0))
		t.ok(day >= 1 and day <= 30, id + " stage_day")
		days[day] = int(days.get(day, 0)) + 1
		var expire: Array = c.get("effects", {}).get("on_expire", [])
		var ops: Array = []
		var expire_node := ""
		var expire_outcome := ""
		var has_gap := false
		for e in expire:
			var op := str(e.get("op", ""))
			ops.append(op)
			if op == "story":
				expire_node = str(e.get("node", ""))
				expire_outcome = str(e.get("outcome", ""))
			if op == "dossier_gap" and str(e.get("frag", "")) != "":
				has_gap = true
		t.ok(ops.has("story") and ops.has("dossier_gap"), id + " V13 ops")
		t.eq(expire_node, node, id + " expire node")
		t.ok(expire_outcome != "", id + " expire outcome")
		t.ok(has_gap, id + " dossier_gap")
		t.ok(not _has_op(c, "game_over"), id + " no game_over")
		nodes[node] = c
	for day in days.keys():
		t.eq(int(days[day]), 1, "one gold card on stage_day %s" % str(day))
	for node in ["s1940.sunfu_stance", "s1940.dossier_link", "s1940.hook"]:
		t.ok(nodes.has(node), "gold node " + node)
	for node in ["s1940.wang_regime", "s1940.new_official"]:
		t.ok(not nodes.has(node), "event node not a person card " + node)
	t.ok(saw_changed, "person_state changed is used")
	t.ok(saw_gone, "person_state gone is used")
	var hook = nodes.get("s1940.hook", {})
	t.ok(bool(hook.get("gold", false)), "hook is gold")
	t.eq(str(hook.get("person", "")), "postman", "hook person")
	t.ok(int(hook.get("schedule", {}).get("stage_day", 0)) >= 25, "hook is late in the stage")
	t.ok(not _has_op(hook, "game_over"), "hook does not end the game")
	var choices: Array = hook.get("choices", [])
	t.ok(choices.size() >= 2, "hook has choices")
	for ch in choices:
		var marked := false
		for e in ch.get("effects", []):
			var op := str(e.get("op", ""))
			if op == "story" or op == "flag":
				marked = true
			t.ok(op != "game_over", "hook choice op")
		t.ok(marked, "hook choice sets story or flag")
	for flag_key in ["k05_hook_follow", "k05_hook_seal", "k05_hook_ignored"]:
		t.ok(_has_flag(hook, flag_key), "hook flag " + flag_key)
	for outcome in ["follow", "seal", "ignored"]:
		t.ok(_has_outcome(hook, "s1940.hook", outcome), "hook outcome " + outcome)
	var refs := {}
	_story_conds(cards, refs)
	t.ok(not refs.is_empty(), "cross-year story conditions exist")
	var known := {}
	for path in PRIOR:
		var raw = CardDB.read_json(path)
		if typeof(raw) == TYPE_DICTIONARY:
			_story_ops(CardState.int_restore(raw), known)
	var ref_names: Array = refs.keys()
	ref_names.sort()
	for name in ref_names:
		if not known.has(name):
			print("NOTE: dangling story " + str(name))
	t.finish()


func _has_op(v, op: String) -> bool:
	match typeof(v):
		TYPE_DICTIONARY:
			if str(v.get("op", "")) == op:
				return true
			for k in v.keys():
				if _has_op(v[k], op):
					return true
		TYPE_ARRAY:
			for x in v:
				if _has_op(x, op):
					return true
	return false


func _has_flag(v, key: String) -> bool:
	match typeof(v):
		TYPE_DICTIONARY:
			if str(v.get("op", "")) == "flag" and str(v.get("key", "")) == key:
				return true
			for k in v.keys():
				if _has_flag(v[k], key):
					return true
		TYPE_ARRAY:
			for x in v:
				if _has_flag(x, key):
					return true
	return false


func _has_outcome(v, node: String, outcome: String) -> bool:
	match typeof(v):
		TYPE_DICTIONARY:
			if str(v.get("op", "")) == "story" and str(v.get("node", "")) == node and str(v.get("outcome", "")) == outcome:
				return true
			for k in v.keys():
				if _has_outcome(v[k], node, outcome):
					return true
		TYPE_ARRAY:
			for x in v:
				if _has_outcome(x, node, outcome):
					return true
	return false


func _has_state(v, state: String) -> bool:
	match typeof(v):
		TYPE_DICTIONARY:
			if str(v.get("op", "")) == "person_state" and str(v.get("state", "")) == state:
				return true
			for k in v.keys():
				if _has_state(v[k], state):
					return true
		TYPE_ARRAY:
			for x in v:
				if _has_state(x, state):
					return true
	return false


func _story_conds(v, acc: Dictionary) -> void:
	match typeof(v):
		TYPE_DICTIONARY:
			if v.size() == 1 and v.has("story") and typeof(v["story"]) == TYPE_ARRAY and (v["story"] as Array).size() == 2:
				var node := str(v["story"][0])
				var outcome := str(v["story"][1])
				if node.begins_with("s1938.") or node.begins_with("s1939."):
					acc["%s:%s" % [node, outcome]] = true
			for k in v.keys():
				_story_conds(v[k], acc)
		TYPE_ARRAY:
			for x in v:
				_story_conds(x, acc)


func _story_ops(v, acc: Dictionary) -> void:
	match typeof(v):
		TYPE_DICTIONARY:
			if str(v.get("op", "")) == "story":
				acc["%s:%s" % [str(v.get("node", "")), str(v.get("outcome", ""))]] = true
			for k in v.keys():
				_story_ops(v[k], acc)
		TYPE_ARRAY:
			for x in v:
				_story_ops(x, acc)
