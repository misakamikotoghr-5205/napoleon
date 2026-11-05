## The playable slice ends after the first full chapter of each branch.
## Travel, combat, branches and saves use public commands on the authored book.
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const Book = preload("res://scripts/cards/campaign/run/run_book.gd")
const Bridge = preload("res://scripts/cards/campaign/ocean_bridge.gd")
const Replay = preload("res://scripts/cards/campaign/run/run_replay.gd")
const Titles = preload("res://scripts/cards/ui/hub/hub_campaigns.gd")
const Policy = preload("res://scripts/tests/cards/OCEAN/napoleon_volume2_policy.gd")
const DEMO := "res://data/campaigns/napoleon/book_demo.json"
const FULL := "res://data/campaigns/napoleon/book_volume2.json"
const LIMITS := {"trunk": 8, "conquest": 1, "cristo": 1, "ocean": 2}
const FINAL_CHAPTERS := {"conquest": "hundred_days", "cristo": "marseille", "ocean": "st_helena"}
const BRANCH_SCENES := {
	"conquest": ["k_golfe_juan", "k_laffrey", "k_tuileries", "k_charleroi", "k_waterloo", "k_waterloo_night"],
	"cristo": ["c_landfall", "c_reserve", "c_gerard", "c_petition", "c_white_june"],
	"ocean": ["prologue", "scene01", "scene02", "scene03", "scene04", "scene05"],
}
const ENDINGS := {
	"conquest": {"exchange_wounded": "demo_k_mercy", "pursue_tonight": "demo_k_pursuit", "parade_eagles": "demo_k_first_chapter"},
	"cristo": {"stay_in_marseille": "demo_m_first_chapter", "ask_gerard": "demo_m_gerard", "sail_genoa": "demo_m_genoa"},
	"ocean": {"redeem_emperor": "demo_o_first_chapter", "emergency_escape": "demo_o_costly_escape"},
}

var t: RefCounted
var _book := {}
var _artifact_dir := ""
var _began := 0
var _saved_env := {}


func _initialize() -> void:
	_began = Time.get_ticks_msec()
	t = T.new(self, "OCEAN_napoleon_demo")
	CardSave.set_root(t.user_dir())
	for key in ["DEHOUDANG_CAMPAIGN", "DEHOUDANG_START"]:
		_saved_env[key] = [OS.has_environment(key), OS.get_environment(key)]
		OS.unset_environment(key)
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--artifact-dir="):
			_artifact_dir = argument.trim_prefix("--artifact-dir=").trim_suffix("/")
			DirAccess.make_dir_recursive_absolute(_artifact_dir)
	var loaded := Book.load_bundle(DEMO)
	t.ok(loaded.get("ok", false), "demo book loads: " + str(loaded.get("err", "")))
	if loaded.get("ok", false):
		_book = loaded["book"]
		var check := Book.validate(_book)
		t.eq(check.get("errors", []), [], "demo book is valid")
		t.eq(check.get("warnings", []), [], "demo has no unresolved content warnings")
		_contracts()
		if "--contracts-only" not in OS.get_cmdline_user_args():
			_playthrough()
	for key in _saved_env:
		if _saved_env[key][0]:
			OS.set_environment(key, _saved_env[key][1])
		else:
			OS.unset_environment(key)
	print("NAPOLEON DEMO assertions=%d elapsed_ms=%d" % [t.checks, Time.get_ticks_msec() - _began])
	t.finish()


func _contracts() -> void:
	t.eq(Bridge.game_opts({}).get("book"), DEMO, "default game resolves to the limited demo")
	t.eq(Bridge.default_save_dir(), "user://cards/napoleon-demo", "demo Continue has a new save directory")
	t.eq(Bridge.default_save_dir({"book": "napoleon_volume2"}), "user://cards/napoleon-volume2", "full second-volume directory is preserved")
	t.eq(Bridge.default_save_dir({"book": "napoleon_volume1"}), "user://cards/napoleon", "first-volume directory is preserved")
	t.eq(_book.get("volume"), 2, "demo keeps current gameplay mechanics")
	t.eq(_book["raw"].get("enforce_chapter_limits"), true, "demo explicitly limits debug starts too")
	var engine := _new({}, "default")
	if engine == null:
		return
	t.eq(engine.query(&"campaign.run").get("title"), _book["raw"].get("title", {}).get("name"), "default public run publishes the demo book title")
	var hash_before := engine.state_hash()
	var history := engine.command_log()
	var path: String = t.user_dir() + "/default-before.json"
	t.ok(engine.save_game(path).get("ok", false), "save the original default run")
	var bytes := FileAccess.get_file_as_bytes(path)
	var open_count := 0
	for segment in LIMITS:
		var chapters: Array = _book["defs"][segment]["chapters"]
		for stage in chapters.size():
			var open := stage < int(LIMITS[segment])
			t.eq(int(chapters[stage].get("volume", 1)) <= 2, open, "%s stage %d has the requested gate" % [segment, stage])
			if open:
				open_count += 1
				continue
			var options := {"book": DEMO, "segment": segment, "stage": stage, "seed": 30, "save_dir": t.user_dir() + "/default"}
			var result := engine.new_game(options)
			t.ok(not result.get("ok", false), "%s stage %d cannot bypass the demo boundary through game.new" % [segment, stage])
			t.eq(engine.state_hash(), hash_before, "rejected chapter start retains current game")
			t.eq(engine.command_log(), history, "rejected chapter start retains command history")
		t.eq(FileAccess.get_file_as_bytes(path), bytes, "rejected starts do not overwrite the original save")
	t.eq(open_count, 12, "eight trunk chapters plus three branch openings and ocean's short prologue")
	for segment in FINAL_CHAPTERS:
		OS.set_environment("DEHOUDANG_START", "%s:%d" % [segment, LIMITS[segment]])
		var rejected := engine.new_game({"seed": 30, "save_dir": t.user_dir() + "/default"})
		t.ok(not rejected.get("ok", false), "environment chapter shortcut cannot bypass " + segment + " limit")
		t.eq(engine.state_hash(), hash_before, "environment shortcut rejection is atomic")
	OS.unset_environment("DEHOUDANG_START")
	var first_later := {"conquest": 1, "cristo": 1, "ocean": 2}
	for segment in first_later:
		var full := _new({"book": "napoleon_volume2", "segment": segment, "stage": first_later[segment]}, "full-" + segment)
		if full == null:
			continue
		t.eq(full.query(&"campaign").get("chapter_id"), _book["defs"][segment]["chapters"][first_later[segment]]["id"], "complete second volume still opens its next " + segment + " chapter")
	t.eq(FileAccess.get_file_as_bytes(path), bytes, "starting complete books preserves the demo save")
	t.ok(engine.load_game(path).get("ok", false), "demo restores after complete-book starts")
	t.eq(engine.state_hash(), hash_before, "demo restore keeps the exact original state")
	_schema_and_menu()


func _schema_and_menu() -> void:
	var invalid: Dictionary = _book.duplicate(true)
	invalid["hash"] = ""
	invalid["raw"]["enforce_chapter_limits"] = "true"
	var checked := Book.validate(invalid)
	t.ok((checked.get("errors", []) as Array).any(func(message): return str(message).contains("enforce_chapter_limits")), "chapter-limit setting rejects a string instead of a boolean")
	invalid = _book.duplicate(true)
	invalid["hash"] = ""
	invalid["raw"]["title"] = "invalid flat title"
	t.ok((Book.validate(invalid).get("errors", []) as Array).any(func(message): return str(message).contains("title")), "book title rejects an incompatible string before run queries")
	# A copied book is deliberately recognized as a debug book by the title model.
	# Its chapter browser must still honor the same content limits.
	var custom: String = t.user_dir() + "/debug-demo.json"
	var file := FileAccess.open(custom, FileAccess.WRITE)
	file.store_string(JSON.stringify(_book["raw"]))
	file.close()
	var menu := Titles.model({"book": custom}, t.user_dir() + "/menu")
	t.ok(menu.get("debug", false), "copied book exposes the full debug chapter list")
	var limited := 0
	for choice in menu.get("choices", []):
		var segment := str(choice.get("segment", ""))
		if not LIMITS.has(segment) or int(choice.get("stage", -1)) < int(LIMITS[segment]):
			continue
		limited += 1
		t.ok(not choice.get("enabled", false), "debug chapter menu disables later " + segment + " chapter")
		t.eq(choice.get("reason"), _book["raw"].get("chapter_locked_message"), "demo gives its own explicit chapter-limit explanation")
	t.eq(limited, 11, "all eleven later chapter entries remain closed")
	for segment in BRANCH_SCENES:
		var collection := Titles.collection(menu, segment)
		t.eq(collection.get("total"), 2 if segment == "ocean" else 3, segment + " collection counts only its available demo endings")
		t.eq(collection.get("n"), 0, segment + " new demo collection has no invented unlocks")
		var earned: Dictionary = menu.duplicate(true)
		var ending: String = _book["raw"]["segments"][segment]["collection_endings"][0]
		earned["info"]["meta"] = {"branches_reached": [segment], "endings": {segment: [ending, "unavailable_future_ending"]}, "volumes": {segment: [ending]}}
		var progress := Titles.collection(earned, segment)
		t.eq(progress.get("n"), 1, segment + " collection ignores unavailable endings and counts duplicates once")
		t.ok(progress.get("visited", false), segment + " collection retains the visited marker")
	for bad_value in ["demo_k_mercy", ["demo_k_mercy", "demo_k_mercy"], ["not_an_ending"]]:
		var bad: Dictionary = _book.duplicate(true)
		bad["hash"] = ""
		bad["raw"]["segments"]["conquest"]["collection_endings"] = bad_value
		t.ok(not Book.validate(bad).get("errors", []).is_empty(), "collection list rejects malformed or unresolvable entries: " + str(bad_value))


func _new(extra: Dictionary, label: String) -> CardEngine:
	var options := {"seed": 30, "save_dir": t.user_dir() + "/" + label}
	options.merge(extra, true)
	var engine := CardEngine.new()
	var result := engine.new_game(options)
	t.ok(result.get("ok", false), "start " + label + ": " + str(result))
	return engine if result.get("ok", false) else null


func _playthrough() -> void:
	var engine := _new({}, "trunk")
	if engine == null:
		return
	var policy := Policy.new()
	policy.branch = "trunk"
	var reached: bool = policy.finish(engine, 5000, "elba_1815")
	t.ok(reached, "default demo reaches Elba by legal travel and combat: " + policy.last_error)
	t.eq(engine.query(&"campaign").get("scene_id"), "elba_1815", "trunk reaches the actual fork")
	if not reached or engine.view().get("phase") == "game_over":
		return
	t.eq(policy.chapters.size(), 8, "all eight trunk maps precede the fork")
	t.eq(policy.scenes.size(), 21, "canonical trunk visits every scene on its chosen route")
	_combat(policy, "trunk")
	var fork := _save(engine, "elba-fork")
	var fork_hash := engine.state_hash()
	var fork_history := engine.command_log()
	var offers: Array = engine.query(&"campaign.run").get("branch_offers", [])
	t.eq(offers.size(), 3, "fork offers all three authored branches")
	t.ok(offers.all(func(row): return row.get("ok", false)), "earned history makes all three routes available")
	print("DEMO TRUNK scenes=%d maps=%d commands=%d" % [policy.scenes.size(), policy.chapters.size(), policy.commands.size()])
	for route in BRANCH_SCENES:
		var branch := CardEngine.new()
		var restored := branch.load_game(fork)
		t.ok(restored.get("ok", false), route + " restores the same real Elba fork")
		if not restored.get("ok", false):
			continue
		t.eq(branch.state_hash(), fork_hash, route + " starts with exactly the earned trunk state")
		t.eq(branch.command_log(), fork_history, route + " retains the original trunk command history")
		var driver := Policy.new()
		driver.branch = route
		var done: bool = driver.finish(branch, 3000, BRANCH_SCENES[route][-1])
		t.ok(done, route + " reaches its first chapter's final scene legally: " + driver.last_error)
		if not done or not _settle_battle(branch, driver):
			continue
		var campaign := branch.query(&"campaign")
		t.eq(campaign.get("chapter_id"), FINAL_CHAPTERS[route], route + " finishes combat in its first full chapter")
		var scenes: Array = driver.scenes.filter(func(id): return id != "elba_1815")
		t.eq(scenes, BRANCH_SCENES[route], route + " actually visits exactly the allowed branch scenes")
		var chapters: Array = driver.chapters.filter(func(id): return str(id).begins_with(route + ":"))
		t.eq(chapters.size(), int(LIMITS[route]), route + " visits only the requested branch chapter maps")
		_combat(driver, route)
		var checkpoint := _save(branch, route + "-final-choice")
		for choice in ENDINGS[route]:
			_ending_variant(checkpoint, route, choice, ENDINGS[route][choice])
		print("DEMO ROUTE %s scenes=%d maps=%d battles=%d commands=%d" % [route, scenes.size(), chapters.size(), driver.battles.size(), driver.commands.size()])


func _settle_battle(engine: CardEngine, driver: RefCounted) -> bool:
	for _i in 600:
		var campaign := engine.query(&"campaign")
		var battle: Dictionary = campaign.get("battle2", {})
		if engine.view().get("phase") == "game_over":
			break
		if engine.view().get("phase") == "day" and not campaign.get("big_fate", {}).get("pending", false) and (not battle.get("has_battle", false) or battle.get("resolved", false)):
			return true
		if not driver.step(engine).get("ok", false):
			break
	t.ok(false, "first-chapter final battle settles legally: " + driver.last_error)
	return false


func _ending_variant(checkpoint: String, route: String, choice: String, expected: String) -> void:
	var engine := CardEngine.new()
	var restored := engine.load_game(checkpoint)
	t.ok(restored.get("ok", false), expected + " restores the same earned first-chapter decision")
	if not restored.get("ok", false):
		return
	var policy := Policy.new()
	policy.branch = route
	policy.preferred[BRANCH_SCENES[route][-1]] = choice
	var good: bool = policy.finish(engine, 200)
	t.ok(good, expected + " completes its public appraisals and final choice: " + policy.last_error)
	var campaign := engine.query(&"campaign")
	t.eq(campaign.get("phase"), "game_over", expected + " reaches the demo closing screen")
	t.eq(campaign.get("ending_id"), expected, expected + " is the actual chosen demo ending")
	t.ok(expected in _book["raw"]["segments"][route]["collection_endings"], expected + " is a published first-chapter ending")
	t.eq(campaign.get("chapter_id"), FINAL_CHAPTERS[route], expected + " stops in the first full chapter")
	t.eq(campaign.get("scene_id"), BRANCH_SCENES[route][-1], expected + " never advances into the next chapter")
	var saved := _save(engine, expected)
	var envelope := CardSave.read(saved)
	t.eq(envelope["state"].data["ocean"].get("end_reason"), "volume", expected + " ends at the scope boundary, not a final-campaign or failure ending")
	print("DEMO ENDING %s commands=%d" % [campaign.get("ending_id"), policy.commands.size()])


func _combat(driver: RefCounted, label: String) -> void:
	t.ok(not driver.battles.is_empty(), label + " actually fights")
	t.ok(driver.battles.all(func(b): return str(b.get("outcome", "")) in ["victory", "defeat"]), label + " uses no automatic retreat bypass")
	t.ok(driver.battles.all(func(b): return int(b.get("commands", 0)) > 0), label + " sends real combat commands")


func _save(engine: CardEngine, label: String) -> String:
	var path: String = t.user_dir() + "/" + label + ".json"
	var before := engine.state_hash()
	var history := engine.command_log()
	var map := engine.query(&"campaign.map")
	t.ok(engine.save_game(path).get("ok", false), label + " saves")
	t.ok(engine.load_game(path).get("ok", false), label + " restores")
	t.eq(engine.state_hash(), before, label + " save round trip is exact")
	t.eq(engine.command_log(), history, label + " save retains the command history")
	t.eq(engine.query(&"campaign.map"), map, label + " save retains the public map")
	if _artifact_dir != "":
		var retained := _artifact_dir + "/" + label + "/" + label + ".json"
		t.ok(engine.save_game(retained).get("ok", false), label + " retains a separate archive")
		t.ok(_retain_replay_chain(path, retained.get_base_dir()), label + " archives the matching replay checkpoints")
		var reopened := CardEngine.new()
		t.ok(reopened.load_game(retained).get("ok", false), label + " archived snapshot actually opens")
		t.eq(reopened.state_hash(), before, label + " archived snapshot keeps its exact state")
	return path


func _retain_replay_chain(source: String, destination: String) -> bool:
	var envelope := CardSave.read(source)
	for _depth in 16:
		if not envelope.get("ok", false):
			return false
		var base: Dictionary = envelope.get("meta", {}).get("replay_base", {})
		if base.is_empty():
			return true
		var file := str(base.get("file", ""))
		if file == "" or file.contains("/") or file.contains(".."):
			return false
		var dependency := source.get_base_dir().path_join(file)
		envelope = CardSave.read(dependency)
		if Replay.saved_hash(envelope) != str(base.get("hash", "")):
			return false
		if DirAccess.copy_absolute(dependency, destination.path_join(file)) != OK:
			return false
	return false
