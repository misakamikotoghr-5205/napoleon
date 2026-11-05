# X01 / #194 K14 acceptance: the formal new-save 1938 three-day guide on the real engine.
# Shipped data/cards (no data_root, no tutorial swap), mock:false, isolated save_dir per instance.
# The G02 fixture walk (K14/test_guide_d1_3.gd) stays as the frozen-firsts regression.
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const Walk = preload("res://scripts/tests/cards/K14/real_guide_walk.gd")

func _initialize() -> void:
	var t := T.new(self, "X01_guide_formal_d1_3")
	t.run_async(_walk.bind(t))

func _walk(t) -> void:
	_formal_data_guard(t)
	var first: Dictionary = await Walk.new(Walk.FORMAL).play(t, self, {"mock": false, "guide": "on",
		"save_dir": t.user_dir().path_join("on")})
	var second: Dictionary = await Walk.new(Walk.FORMAL).play(t, self, {"mock": false, "guide": "off",
		"save_dir": t.user_dir().path_join("off")})
	if first.is_empty() or second.is_empty():
		return # play() has already recorded a failing real-engine assertion.
	var contract := Walk.expected()
	var want := Walk.expected_formal()
	t.eq(contract.size(), 21, "formal guide contract has 21 steps")
	t.eq(first["log"].filter(func(s): return contract.has(s)), contract, "all 21 _test.d1_3 steps shown in contract order")
	# Real behaviour today: the 21 + gd.person_state after gd.d2.keep (open question for Claude, #217).
	t.eq(first["log"], want, "formal shown_log equals contract + gd.person_state")
	t.eq(second["log"], [], "guide off shows no steps")
	t.eq(second["progress"], {}, "guide off writes no progress")
	for step in want:
		var row: Dictionary = first["progress"].get(step, {})
		t.eq(str(row.get("status", "")), "done", "formal guide progress done for " + str(step))
		t.ok(int(row.get("shows", 0)) >= 1, "formal guide progress shows>=1 for " + str(step))
		for kind in [&"guide_shown", &"guide_done"]:
			t.ok(first["events"].any(func(ev): return ev[0] == kind and str(ev[1].get("step", "")) == step), "%s ui_event for %s" % [kind, step])
	t.ok(first["cmds"].size() > 1, "formal walk recorded gameplay commands")
	t.ok(not first["firsts"].is_empty(), "formal walk fired first_time mechanisms")
	print("X01 FORMAL FIRSTS ", JSON.stringify(first["firsts"]))
	t.eq(_commands(second["cmds"]), _commands(first["cmds"]), "command_log matches with guide off")
	t.eq(second["hash"], first["hash"], "state hash matches with guide off")
	t.eq(second["firsts"], first["firsts"], "guide toggle preserves firsts")
	var replay := CardReplay.replay({"seed": 7, "save_dir": t.user_dir().path_join("replay")}, first["cmds"])
	t.ok(replay != "", "formal replay returned a hash")
	t.eq(replay, first["hash"], "formal replay hash")

# The walk must exercise the shipped teaching cards, not a fixture-shaped copy.
func _formal_data_guard(t) -> void:
	var by_id := {}
	for card in CardDB.read_json(Walk.FORMAL_TUTORIAL).get("cards", []):
		by_id[str(card.get("id", ""))] = card
	for key in ["pawn", "sell", "buy", "slots"]:
		t.ok(by_id.has(str(Walk.FORMAL[key])), "formal tutorial defines " + str(Walk.FORMAL[key]))
	var ev: Dictionary = by_id.get(str(Walk.FORMAL["slots"]), {})
	var slot_ids := []
	for slot in ev.get("slots", []):
		slot_ids.append(str(slot.get("id", "")))
	t.eq(slot_ids, ["who", "cash"], "formal slot event keeps who/cash slots")
	t.eq(int(ev.get("check", {}).get("need", -1)), 1, "formal slot event keeps need=1")

func _commands(log: Array) -> Array:
	var result := log.duplicate(true)
	# Only the deliberately isolated filesystem destination differs between runs.
	for row in result:
		if str(row[0]) == "game.new":
			row[1].erase("save_dir")
	return result
