# 回归 golden（A0；WORLD_MAP_DESIGN §6.1、§8.5、§15.1）：
#   1. 远洋单段书五条结局路线逐步的 hash_v1 等于 golden/ocean_routes.json；
#   2. 现有 7 张战斗模板 × 6 幕 × 3 种子的固定 60 步指令序列，result 与去掉 level/weather 的状态哈希等于 golden/battle_templates.json。
# 录制（只在行为没变的基线上）：DEHOUDANG_GOLDEN_WRITE=1 godot --headless --path . -s res://scripts/tests/cards/OCEAN/test_golden.gd
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const G = preload("res://scripts/tests/cards/OCEAN/golden_lib.gd")

var t: RefCounted


func _initialize() -> void:
	t = T.new(self, "OCEAN_golden")
	CardSave.set_root(t.user_dir())
	if OS.get_environment("DEHOUDANG_GOLDEN_WRITE") == "1":
		_write()
	_test_hash_v1()
	_test_routes()
	_test_battles()
	print("OCEAN golden assertions: %d" % t.checks)
	t.finish()


func _write() -> void:
	var routes := G.record_routes()
	for ending in routes["routes"]:
		var row: Dictionary = routes["routes"][ending]
		t.ok(bool(row["ok"]), "record route %s: %s" % [ending, row["err"]])
		t.eq(row["ending"], ending, "recorded route %s reaches its ending" % ending)
	t.ok(G.write_json(G.ROUTES_PATH, routes), "write " + G.ROUTES_PATH)
	var battles := G.record_battles()
	for run in battles["runs"]:
		t.ok(not run.has("error"), "record battle %s act %d seed %d: %s" % [run["template"], run["act"], run["seed"], run.get("error", "")])
	t.ok(G.write_json(G.BATTLES_PATH, battles), "write " + G.BATTLES_PATH)
	print("OCEAN golden written: %s, %s" % [G.ROUTES_PATH, G.BATTLES_PATH])


## hash_v1 只看 v1 的字段：v2 新增的键、ledger 里的文字、definition_hash 都不影响它
func _test_hash_v1() -> void:
	var campaign: RefCounted = G.new_campaign()
	t.ok(campaign != null, "new ocean campaign")
	if campaign == null:
		return
	var base := G.hash_v1(campaign.state)
	t.eq(base, G.hash_v1(campaign.snapshot()), "hash_v1 is stable")
	var v2: Dictionary = campaign.snapshot()
	v2["v"] = 2
	v2["segment"] = "ocean"
	v2["run"] = {"book": "ocean_pawn", "path": ["ocean"]}
	v2["map"] = {}
	v2["archive"] = {}
	v2["definition_hash"] = "changed"
	v2["rogue"]["tally"] = {"gold": 3, "supply": 0, "medal": 0, "intel": 0}
	for row in v2["ledger"]:
		row["observation"] = "text"
		row["battle"] = "text"
	t.eq(G.hash_v1(v2), base, "hash_v1 ignores v2 keys, rogue.tally, definition_hash and ledger text")
	var other: Dictionary = campaign.snapshot()
	other["day"] = int(other["day"]) + 1
	t.ok(G.hash_v1(other) != base, "hash_v1 still sees kernel fields")
	t.ok(G.hash_v1_textless(other) != G.hash_v1_textless(campaign.state), "hash_v1_textless still sees kernel fields")
	var renamed: Dictionary = campaign.snapshot()
	for row in renamed["demands"]:
		row["title"] = row["title"] + "x"
	t.eq(G.hash_v1_textless(renamed), G.hash_v1_textless(campaign.state), "hash_v1_textless ignores player text in the state")


func _test_routes() -> void:
	var doc = G.read_json(G.ROUTES_PATH)
	t.ok(typeof(doc) == TYPE_DICTIONARY, "golden " + G.ROUTES_PATH + " present")
	if typeof(doc) != TYPE_DICTIONARY:
		return
	var routes: Dictionary = doc.get("routes", {})
	t.eq(routes.keys().size(), G.ENDINGS.size(), "golden has every ending route")
	var new_game: Dictionary = G._int_tree(doc.get("new_game", {}))
	t.eq(new_game, G.NEW_GAME, "golden routes start from the test_campaign opening")
	for ending in G.ENDINGS:
		var row: Dictionary = routes.get(ending, {})
		t.ok((row.get("commands", []) as Array).size() > 20, "golden route %s has commands" % ending)
		for series in ["hash_v1", "hash_v1_textless"]:
			var check := G.verify_route(row, new_game, series)
			t.ok(bool(check["ok"]), "route %s %s sequence equals golden (step %d %s: want %s got %s)" % [
				ending, series, int(check["at"]), check["err"], check["want"], check["got"]])
			t.eq(check.get("ending", ""), ending, "route %s replay reaches its ending" % ending)


func _test_battles() -> void:
	var doc = G.read_json(G.BATTLES_PATH)
	t.ok(typeof(doc) == TYPE_DICTIONARY, "golden " + G.BATTLES_PATH + " present")
	if typeof(doc) != TYPE_DICTIONARY:
		return
	var runs: Array = doc.get("runs", [])
	t.eq(runs.size(), G.TEMPLATES.size() * G.ACTS.size() * G.SEEDS.size(), "golden covers 7 templates x 6 acts x 3 seeds")
	var bad: Array = []
	var finished := 0
	for want in runs:
		var got := G.run_battle(str(want["template"]), int(want["act"]), int(want["seed"]))
		if str(JSON.parse_string(str(want["result"])).get("outcome", "ongoing")) != "ongoing":
			finished += 1
		var want_row: Dictionary = G._int_tree(want)
		for key in ["steps", "finish_fights", "hash60", "result", "hash_end", "chain", "result_textless", "hash_end_textless", "chain_textless"]:
			if str(got.get(key, "")) != str(want_row.get(key, "")):
				bad.append("%s act %d seed %d: %s want %s got %s" % [want["template"], int(want["act"]), int(want["seed"]), key,
					str(want.get(key, "")).left(80), str(got.get(key, "")).left(80)])
				break
	t.ok(bad.is_empty(), "battle golden: %d/%d runs equal (%s)" % [runs.size() - bad.size(), runs.size(), bad.slice(0, 5)])
	t.eq(finished, runs.size(), "every golden battle is fought to its end")
