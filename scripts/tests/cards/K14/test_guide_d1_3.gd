# K14 (G02 fixture profile): real engine + G02 private tutorial fixture — the frozen-firsts regression.
# Virtual clock (tick 0.5 + evaluate_now per frame): checks data and order, not real-time lighting
# (that is C16/test_guide_realtime.gd). The walk presses "got it" like a reader (10-22 prototype flow).
# The formal new-save 1938 guide walk (shipped data/cards) is X01/test_guide_formal_d1_3.gd.
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const Walk = preload("res://scripts/tests/cards/K14/real_guide_walk.gd")

func _initialize() -> void:
	var t := T.new(self, "K14_guide_d1_3")
	t.run_async(_walk_real.bind(t))

func _walk_real(t) -> void:
	var data_root := Walk.prepare_data(t)
	var first: Dictionary = await Walk.new(Walk.G02).play(t, self, {"mock": false, "guide": "on",
		"data_root": data_root, "save_dir": t.user_dir().path_join("on")})
	var second: Dictionary = await Walk.new(Walk.G02).play(t, self, {"mock": false, "guide": "off",
		"data_root": data_root, "save_dir": t.user_dir().path_join("off")})
	if first.is_empty() or second.is_empty():
		return # play() has already recorded a failing real-engine assertion.
	var want := Walk.expected_g02()
	t.ok(not want.is_empty(), "guide contract is nonempty")
	t.eq(first["log"], want, "shown_log equals _test.d1_3 in the G02 order (gold on day 2)")
	t.eq(second["log"], [], "guide off shows no steps")
	t.eq(second["progress"], {}, "guide off writes no progress")
	for step in want:
		var row: Dictionary = first["progress"].get(step, {})
		t.eq(str(row.get("status", "")), "done", "guide progress done for " + str(step))
		t.ok(int(row.get("shows", 0)) >= 1, "guide progress shows>=1 for " + str(step))
		for kind in [&"guide_shown", &"guide_done"]:
			t.ok(first["events"].any(func(ev): return ev[0] == kind and str(ev[1].get("step", "")) == step), "%s ui_event for %s" % [kind, step])
	t.ok(first["cmds"].size() > 1, "real walk recorded gameplay commands")
	t.eq(_commands(second["cmds"]), _commands(first["cmds"]), "command_log matches with guide off")
	t.eq(second["hash"], first["hash"], "state hash matches with guide off")
	t.eq(first["firsts"], CardDB.read_json(Walk.GOLDEN), "full G02 firsts d1-3 golden")
	t.eq(second["firsts"], first["firsts"], "guide toggle preserves full firsts")
	var replay := CardReplay.replay({"seed": 7, "data_root": data_root,
		"save_dir": t.user_dir().path_join("replay")}, first["cmds"])
	t.ok(replay != "", "real replay returned a hash")
	t.eq(replay, first["hash"], "replay hash")

func _commands(log: Array) -> Array:
	var result := log.duplicate(true)
	# Only the deliberately isolated filesystem destination differs between runs.
	for row in result:
		if str(row[0]) == "game.new":
			row[1].erase("save_dir")
	return result
