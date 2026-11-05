## Fresh branch openings use a standard preset and new seed; Continue retains
## the original earned army. All live actions go through public CardEngine API.
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const Bridge = preload("res://scripts/cards/campaign/ocean_bridge.gd")
const Book = preload("res://scripts/cards/campaign/run/run_book.gd")
const Replay = preload("res://scripts/cards/campaign/run/run_replay.gd")
const Titles = preload("res://scripts/cards/ui/hub/hub_campaigns.gd")
const Policy = preload("res://scripts/tests/cards/OCEAN/map_policy.gd")
const MINI := "res://data/campaigns/napoleon/fixtures/mini_book.json"
const V1 := "res://data/campaigns/napoleon/book.json"
const V2 := "res://data/campaigns/napoleon/book_volume2.json"

var t: RefCounted
var _saved_env := {}
var _formal_saves := {}


func _initialize() -> void:
	t = T.new(self, "OCEAN_napoleon_branch_start")
	root.size = Vector2i(1280, 720)
	for key in ["DEHOUDANG_CAMPAIGN", "DEHOUDANG_START"]:
		_saved_env[key] = [OS.has_environment(key), OS.get_environment(key)]
		OS.unset_environment(key)
	t.run_async(_run)


func _run() -> void:
	_test_locked_and_bad_args()
	_test_earned_unlock_and_snapshot()
	for path in [V1, V2]:
		if "--mini-only" not in OS.get_cmdline_user_args():
			if path != V2 or "--volume1-only" not in OS.get_cmdline_user_args():
				_test_formal_book(path)
	for path in _formal_saves:
		var saved: Dictionary = _formal_saves[path]
		t.eq(FileAccess.get_file_as_bytes(saved["file"]), saved["bytes"], "other volume runs do not replace " + path)
		var engine := CardEngine.new()
		t.ok(engine.load_game(saved["file"]).get("ok", false), "Continue reopens the requested volume after other starts")
		t.eq(engine.state_hash(), saved["hash"], "Continue retains that volume's original state")
	await _test_title_controls()
	for key in _saved_env:
		if bool(_saved_env[key][0]):
			OS.set_environment(key, str(_saved_env[key][1]))
		else:
			OS.unset_environment(key)
	print("OCEAN Napoleon branch start assertions: %d" % t.checks)


func _write_meta(dir: String) -> void:
	# Isolated title-unlock fixture. Campaign inventories and flags are never edited.
	DirAccess.make_dir_recursive_absolute(dir)
	var meta := Bridge.read_meta(dir)
	meta["trunk_cleared"] = true
	var file := FileAccess.open(dir + "/" + Bridge.META_FILE, FileAccess.WRITE)
	file.store_string(JSON.stringify(meta))
	file.close()


func _opts(book: String, dir: String, seed_value: int = 117) -> Dictionary:
	return {"book": book, "save_dir": dir, "entry": "branch_point", "seed": seed_value}


func _new(opts: Dictionary, label: String) -> CardEngine:
	var engine := CardEngine.new()
	var result := engine.new_game(opts)
	t.ok(bool(result.get("ok", false)), label + ": " + str(result))
	return engine if bool(result.get("ok", false)) else null


func _day(engine: CardEngine) -> void:
	for _i in 6:
		if str(engine.view().get("phase", "")) == "day":
			return
		t.ok(engine.send(&"campaign.wait", {}).get("ok", false), "opening reaches day through legal waits")


func _ocean_snapshot(engine: CardEngine, path: String) -> Dictionary:
	t.ok(engine.save_game(path).get("ok", false), "save branch opening")
	var read := CardSave.read(path)
	t.ok(read.get("ok", false), "read saved branch envelope")
	return read["state"].data.get("ocean", {}) if read.get("ok", false) else {}


func _test_locked_and_bad_args() -> void:
	var dir: String = t.user_dir() + "/locked"
	var engine := _new({"book": MINI, "seed": 7, "save_dir": dir}, "normal start remains available")
	if engine == null:
		return
	var before := engine.state_hash()
	var history := engine.command_log()
	var saved := FileAccess.get_file_as_bytes(dir + "/suspend.json")
	t.eq(engine.new_game(_opts(MINI, dir)).get("err"), "entry_locked", "fresh fork requires an earned unlock")
	for patch in [{"entry": "other"}, {"entry": true}, {"stage": 0}, {"segment": "trunk"}, {"seed": "7"}, {"book": "ocean_pawn"}]:
		var args := _opts(MINI, dir)
		args.merge(patch, true)
		t.eq(engine.new_game(args).get("err"), "bad_args", "invalid fresh-entry options rejected: " + str(patch))
	var no_seed := _opts(MINI, dir)
	no_seed.erase("seed")
	t.eq(engine.new_game(no_seed).get("err"), "bad_args", "public fresh-entry API requires its resolved seed")
	t.eq(engine.state_hash(), before, "rejected openings do not reset the live run")
	t.eq(engine.command_log(), history, "rejected openings do not alter the command history")
	t.eq(FileAccess.get_file_as_bytes(dir + "/suspend.json"), saved, "rejected openings do not replace the old save")
	var model := Titles.model({"book": MINI}, dir)
	var fresh: Array = model["choices"].filter(func(row: Dictionary) -> bool: return row["segment"] == "branch_point")
	t.ok(fresh.size() == 1 and not bool(fresh[0]["enabled"]), "even a debug-book title respects the fork unlock")


func _test_earned_unlock_and_snapshot() -> void:
	var dir: String = t.user_dir() + "/earned"
	var engine := _new({"book": MINI, "seed": 30, "save_dir": dir}, "begin actual mini trunk")
	if engine == null:
		return
	var policy := Policy.new()
	for _i in 300:
		if engine.query(&"campaign").get("scene_id") == "mt_fork":
			break
		if not bool(policy.step(engine).get("ok", false)):
			t.ok(false, "actual trunk traversal: " + policy.last_error)
			return
	t.eq(engine.query(&"campaign").get("scene_id"), "mt_fork", "actual trunk reaches the fork")
	t.ok(Bridge.read_meta(dir)["trunk_cleared"], "reaching the fork persists the unlock before choosing a branch")
	var branch := dir + "/branch.json"
	t.ok(FileAccess.file_exists(branch), "actual trunk writes the earned branch snapshot")
	var previous := FileAccess.get_file_as_bytes(branch)
	var previous_hash := engine.state_hash()
	var fresh := _new(_opts(MINI, dir, 117), "new standard fork beside the old snapshot")
	if fresh == null:
		return
	t.eq(FileAccess.get_file_as_bytes(branch), previous, "fresh opening preserves the original branch snapshot byte-for-byte")
	t.eq(fresh.command_log().size(), 1, "fresh opening does not manufacture earlier battle commands")
	t.eq(fresh.query(&"campaign.map").get("pos"), "b_fork", "fresh opening is already at the fork anchor")
	t.ok(fresh.query(&"campaign.map").get("mustered", false), "fresh opening can choose campaign-phase branches")
	_day(fresh)
	var state := _ocean_snapshot(fresh, dir + "/fresh.json")
	t.eq(state.get("run", {}).get("start", {}).get("carry"), "branch_point", "snapshot records the standard-opening origin")
	t.eq(state.get("run", {}).get("stats"), {"battles": 0, "wins": 0, "boss_wins": 0}, "skipped battles award no fictitious wins")
	var preset: Dictionary = Book.read_json(MINI)["data"]["debug_carry"]["branch_point"]
	t.eq(state["rogue"]["coins"], preset["coins"], "standard fork uses exactly the authored coins")
	t.eq(state["rogue"]["tally"], preset["coins"], "standard checkpoint coins count as its already-earned coins")
	var verified := Bridge.verify(CardSave.read(dir + "/fresh.json"), dir)
	t.ok(verified.get("ok", false), "fresh opening replays from its public game.new: " + str(verified))
	var meta_only := CardSave.read(dir + "/fresh.json")
	meta_only["cmd_log"] = []
	# Verify pure start reconstruction from meta.start independently of command history.
	var start := Replay.start_args(meta_only["meta"]["start"])
	t.eq(start.get("entry"), "branch_point", "meta-only replay preserves the branch-opening mode")
	t.ok(not start.has("stage") and not start.has("segment"), "meta-only start does not conflict with chapter arguments")
	var recreated := Bridge.new_model(start)
	t.ok(recreated.get("ok", false), "meta-only branch start is reconstructible without profile IO")
	var continued := CardEngine.new()
	t.ok(continued.load_game(branch).get("ok", false), "Continue still restores the earned branch snapshot")
	t.eq(continued.state_hash(), previous_hash, "Continue retains the original earned run, not the fresh preset")
	t.ok(continued.state_hash() != fresh.state_hash(), "fresh standard run and original Continue are distinct")
	DirAccess.remove_absolute(branch)
	t.ok(Bridge.branch_unlocked(dir), "permanent unlock survives removal of the optional branch file")
	var rows: Array = Titles.model({"book": MINI}, dir)["choices"]
	t.ok(rows.any(func(row: Dictionary) -> bool: return row["segment"] == "branch_point" and row["enabled"]), "fresh start remains available without branch.json")
	t.ok(rows.any(func(row: Dictionary) -> bool: return row["segment"] == "branch_resume" and not row["enabled"]), "missing snapshot disables only Continue")


func _test_formal_book(path: String) -> void:
	var dir: String = t.user_dir() + "/" + path.get_file().get_basename()
	_write_meta(dir)
	var engine := _new(_opts(path, dir), "formal standard opening " + path)
	if engine == null:
		return
	_day(engine)
	t.eq(engine.query(&"campaign").get("scene_id"), "elba_1815", "formal fresh run begins at the authored Elba fork")
	t.eq(engine.query(&"campaign.map").get("pos"), "mulini", "formal fork begins at Mulini Palace")
	var offers: Array = engine.query(&"campaign.run").get("branch_offers", [])
	t.eq(offers.size(), 3, "standard formal fork exposes all three routes")
	t.ok(offers.all(func(row: Dictionary) -> bool: return bool(row.get("ok", false))), "standard ten earned medals and letter unlock all three routes")
	var snapshot := _ocean_snapshot(engine, dir + "/start.json")
	var raw: Dictionary = Book.read_json(path)["data"]
	_assert_carry_profiles(snapshot, raw, raw["debug_carry"]["branch_point"]["companions"])
	var first_hash := engine.state_hash()
	_formal_saves[path] = {"file": dir + "/start.json", "bytes": FileAccess.get_file_as_bytes(dir + "/start.json"), "hash": first_hash}
	var first_map := engine.query(&"campaign.map")
	var log := engine.command_log()
	t.ok(engine.load_game(dir + "/start.json").get("ok", false), "formal fresh start reloads")
	t.eq(engine.state_hash(), first_hash, "formal fresh save preserves exact state")
	t.eq(engine.command_log(), log, "formal fresh save preserves command history")
	var same := _new(_opts(path, dir), "same-seed standard restart")
	if same == null:
		return
	_day(same)
	t.eq(same.state_hash(), first_hash, "same seed reproduces the full standard opening")
	t.eq(same.query(&"campaign.map"), first_map, "same seed reproduces the drawn hand and public map")
	var other := _new(_opts(path, dir, 118), "rerolled standard restart")
	if other == null:
		return
	_day(other)
	t.ok(other.state_hash() != first_hash, "new seed produces a distinct run")
	t.ok(other.query(&"campaign.map").get("hand") != first_map.get("hand"), "reroll changes the actual initial marching hand")
	t.eq(other.query(&"campaign").get("coins"), engine.query(&"campaign").get("coins"), "reroll keeps standard resources")
	for offer in offers:
		var branch := CardEngine.new()
		t.ok(branch.load_game(dir + "/start.json").get("ok", false), "restore standard opening for " + str(offer["segment"]))
		t.ok(branch.send(&"campaign.choose", {"choice": str(offer["choice"])}).get("ok", false), "choose formal route " + str(offer["segment"]))
		t.eq(branch.query(&"campaign.run").get("segment"), offer["segment"], "formal route actually switches segment")
	var verified := Bridge.verify(CardSave.read(dir + "/start.json"), dir)
	t.ok(verified.get("ok", false), "formal standard opening verifies after other runs: " + str(verified))
	t.eq(snapshot["run"]["volume"], 1 if path == V1 else 2, "fresh start retains the requested volume")
	if path == V2:
		_test_earned_promotion_equivalence(snapshot, dir)
		_test_late_carry(raw, dir)


func _assert_carry_profiles(snapshot: Dictionary, raw: Dictionary, levels: Dictionary) -> void:
	var profiles: Dictionary = Book.read_json(raw["companions"])["data"]["companions"]
	for id in levels:
		var row: Dictionary = snapshot["rogue"]["companions"][id]
		var profile: Dictionary = profiles[id]["battle"]
		var promotions := maxi(0, int(levels[id]) - 1) if int(raw["volume"]) >= 2 else 0
		var maximum := int(profile["hp"]) + 25 * promotions
		t.eq(row["level"], int(levels[id]), "carry retains authored level: " + str(id))
		t.eq(row["max_hp"], maximum, "carry HP matches its volume's promotion rules: " + str(id))
		t.eq(row["hp"], maximum, "standard carry starts at full HP: " + str(id))
		t.eq(row["atk"], int(profile["atk"]) + 6 * promotions, "carry attack matches its volume's promotion rules: " + str(id))
		t.eq(row["b_max_hp"], maximum, "standard carry's displayed battle HP matches actual HP: " + str(id))
		t.ok(not row["scarred"], "standard carry starts without an invented scar: " + str(id))


func _test_earned_promotion_equivalence(fresh: Dictionary, dir: String) -> void:
	var earned := _new({"book": V2, "seed": 117, "save_dir": dir + "/earned-promotion"}, "begin real promotion comparison")
	if earned == null:
		return
	_day(earned)
	t.ok(earned.send(&"campaign.choose", {"choice": "buy_in_marseille"}).get("ok", false), "recruit the standard companions through Toulon's public story choice")
	_day(earned)
	for id in ["baptiste", "corso"]:
		t.ok(earned.send(&"campaign.promote", {"id": id}).get("ok", false), "earn level two through the real promotion command: " + id)
	var snapshot := _ocean_snapshot(earned, dir + "/earned-promotion/compare.json")
	for id in ["baptiste", "corso"]:
		for field in ["level", "max_hp", "hp", "atk"]:
			t.eq(fresh["rogue"]["companions"][id][field], snapshot["rogue"]["companions"][id][field], "standard carry equals an earned promotion: " + id + "." + field)


func _test_late_carry(raw: Dictionary, dir: String) -> void:
	var later := _new({"book": V2, "segment": "conquest", "stage": 1, "seed": 117, "save_dir": dir + "/late"}, "open authored level-three chapter carry")
	if later == null:
		return
	var path := dir + "/late/carry.json"
	var snapshot := _ocean_snapshot(later, path)
	_assert_carry_profiles(snapshot, raw, raw["debug_carry"]["conquest"]["stages"]["1"]["companions"])
	var original := later.state_hash()
	t.ok(later.load_game(path).get("ok", false), "late standard carry reloads")
	t.eq(later.state_hash(), original, "late carry stats survive exact restoration")
	t.ok(Bridge.verify(CardSave.read(path), path.get_base_dir()).get("ok", false), "late carry stats also reproduce from command replay")


func _click(button: Button, label: String) -> void:
	t.ok(button != null and not button.disabled and button.is_visible_in_tree(), "clickable title control: " + label)
	if button == null or button.disabled or not button.is_visible_in_tree():
		return
	var parent := button.get_parent()
	while parent != null:
		if parent is ScrollContainer:
			parent.ensure_control_visible(button)
		parent = parent.get_parent()
	await t.frames(2)
	var point := button.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion, true)
	for down in [true, false]:
		var click := InputEventMouseButton.new()
		click.position = point
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = down
		root.push_input(click, true)
	await t.frames(3)


func _test_title_controls() -> void:
	var dir: String = t.user_dir() + "/ui"
	_write_meta(dir)
	var game := load(CardIds.ROOT_SCENE).instantiate() as CardGameRoot
	root.add_child(game)
	await t.frames(2)
	game.boot({"mock": false, "bus": root.get_node("CardBus"), "book": MINI,
		"segment": "ocean", "stage": 1, "guide": "off", "save_dir": dir, "settings_path": dir + "/settings.json"})
	game.allow_quit = false
	game.stage.fast = true
	game.host.fast = true
	await t.frames(3)
	t.ok(game.title != null, "actual title loads the chapter drawer")
	if game.title != null:
		var seed_before: String = game.title.seed_text()
		await _click(game.title.get_node("Chapters"), "open chapters")
		await _click(game.title.chapter_button("branch_point", -1), "select fresh branch opening")
		t.eq(game.title.selected_game_options().get("entry"), "branch_point", "title selects the fresh-entry API")
		t.ok(game.title.seed_text() != seed_before, "selecting a fresh fork rerolls the normal seed suggestion")
		await _click(game.title.get_node("new"), "start the selected fork")
		t.eq(game.engine.query(&"campaign").get("scene_id"), "mt_fork", "real title opens the fork rather than its prior chapter")
		t.eq(game.engine.query(&"campaign.map").get("pos"), "b_fork", "real title lands at the branch node")
	game.queue_free()
	await t.frames(4)
