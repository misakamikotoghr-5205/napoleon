## Volume-two acceptance uses the authored book and legal public commands only.
## Checkpoints are produced by real travel, never assembled from hidden flags or resources.
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const Book = preload("res://scripts/cards/campaign/run/run_book.gd")
const Replay = preload("res://scripts/cards/campaign/run/run_replay.gd")
const Policy = preload("res://scripts/tests/cards/OCEAN/napoleon_volume2_policy.gd")
const Graph = preload("res://scripts/tests/cards/OCEAN/map_policy.gd")
const BOOK := "res://data/campaigns/napoleon/book_volume2.json"
const FAILURE := ["bankruptcy", "loss", "blockade", "exile", "obituary"]

var t: RefCounted
var _book := {}
var _fork := ""
var _fork_hash := ""
var _fork_log: Array = []
var _began := 0
var _full_run := false
var _visited_scenes := {}
var _promotions := 0
var _artifact_dir := ""


func _initialize() -> void:
	_began = Time.get_ticks_msec()
	t = T.new(self, "OCEAN_napoleon_volume2")
	var loaded := Book.load_bundle(BOOK)
	t.ok(bool(loaded.get("ok", false)), "full authored book loads: " + str(loaded.get("err", loaded.get("path", ""))))
	if not bool(loaded.get("ok", false)):
		t.finish()
		return
	_book = loaded["book"]
	var check := Book.validate(_book)
	t.eq(check.get("errors", []), [], "full authored book validates")
	if not (check.get("errors", []) as Array).is_empty():
		print(JSON.stringify(check))
		t.finish()
		return
	_structure()
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--artifact-dir="):
			_artifact_dir = argument.trim_prefix("--artifact-dir=").trim_suffix("/")
			DirAccess.make_dir_recursive_absolute(_artifact_dir)
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--route="):
			var route := argument.trim_prefix("--route=")
			var engine := _new(route, {"segment": route, "stage": 0})
			if engine != null:
				_route(engine, route)
			_finish()
			return
	_full_run = true
	if _trunk():
		for route in ["conquest", "cristo", "ocean"]:
			var engine := CardEngine.new()
			var result := engine.load_game(_fork)
			t.ok(result.get("ok", false), route + " restores the actual Elba fork")
			if not result.get("ok", false):
				continue
			t.eq(engine.state_hash(), _fork_hash, route + " begins at identical earned trunk state")
			t.eq(engine.command_log(), _fork_log, route + " keeps the actual trunk command history")
			_route(engine, route)
	_finish()


func _finish() -> void:
	if _full_run:
		var expected: Array = []
		for segment in _book.get("defs", {}):
			for scene in _book["defs"][segment]["scenes"]:
				expected.append(str(scene["id"]))
		expected.sort()
		var visited: Array = _visited_scenes.keys()
		visited.sort()
		t.eq(visited, expected, "legal route variants actually visit all 81 authored scenes")
		t.ok(_promotions > 0, "full campaign spends earned medals on actual companion growth")
	print("NAPOLEON VOLUME2 assertions=%d elapsed_ms=%d" % [t.checks, Time.get_ticks_msec() - _began])
	t.finish()


func _structure() -> void:
	t.eq(_book.get("volume"), 2, "full campaign enables volume two")
	t.eq(_book.get("start"), "trunk", "full campaign still begins at Toulon")
	var chapters := 0
	var scenes := 0
	for segment in {"trunk": 8, "conquest": 6, "cristo": 5, "ocean": 4}:
		var def: Dictionary = _book["defs"][segment]
		for chapter in def["chapters"]:
			t.ok(int(chapter.get("volume", 1)) <= 2, str(chapter["id"]) + " is playable in volume two")
		chapters += def["chapters"].size()
		scenes += def["scenes"].size()
		t.eq(_book["maps"][segment]["sheets"].size(), def["chapters"].size(), segment + " has every authored chapter map")
	t.eq(chapters, 23, "all 23 authored chapters are installed")
	t.eq(scenes, 81, "all 81 authored scenes are installed, including alternate theatres")
	t.eq(_book.get("companions", {}).size(), 28, "the complete companion roster remains available")


func _new(label: String, extra: Dictionary = {}) -> CardEngine:
	var engine := CardEngine.new()
	var options := {"book": BOOK, "seed": 30, "save_dir": t.user_dir() + "/" + label}
	options.merge(extra, true)
	var result := engine.new_game(options)
	t.ok(result.get("ok", false), "start " + label + ": " + str(result))
	return engine if result.get("ok", false) else null


func _save(engine: CardEngine, label: String) -> String:
	var path: String = t.user_dir() + "/" + label + ".json"
	var hash_before := engine.state_hash()
	var commands := engine.command_log()
	var map_before := engine.query(&"campaign.map")
	var result := engine.save_game(path)
	t.ok(result.get("ok", false), label + " saves a legal run")
	if not result.get("ok", false):
		return ""
	result = engine.load_game(path)
	t.ok(result.get("ok", false), label + " restores: " + str(result))
	t.eq(engine.state_hash(), hash_before, label + " restores exact state")
	t.eq(engine.command_log(), commands, label + " restores exact command history")
	t.eq(engine.query(&"campaign.map"), map_before, label + " restores exact public map")
	if _artifact_dir != "":
		var retained := _artifact_dir + "/" + label + "/" + label + ".json"
		var copied := engine.save_game(retained)
		t.ok(copied.get("ok", false), label + " retains the real checkpoint outside the test cleanup directory")
		t.ok(_retain_replay_chain(path, retained.get_base_dir()), label + " retains its matching replay checkpoint chain")
	return path


func _retain_replay_chain(source: String, destination: String) -> bool:
	var envelope := CardSave.read(source)
	for _depth in 16:
		if not bool(envelope.get("ok", false)):
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


func _reach(engine: CardEngine, policy: RefCounted, scene: String, label: String) -> bool:
	var good: bool = policy.finish(engine, 9000, scene)
	t.ok(good, label + " legal traversal: " + policy.last_error)
	t.eq(engine.query(&"campaign").get("scene_id"), scene, label + " reaches the authored scene")
	if not good or str(engine.query(&"campaign").get("scene_id", "")) != scene:
		_dump(policy, engine)
		return false
	return true


func _trunk() -> bool:
	var engine := _new("trunk")
	if engine == null:
		return false
	var policy := Policy.new()
	policy.branch = "trunk"
	if not _reach(engine, policy, "orient_orders", "Toulon and Italy"):
		return false
	var theatre_checkpoint := _save(engine, "theatre-choice")
	if not _reach(engine, policy, "elba_1815", "canonical trunk"):
		return false
	t.eq(policy.chapters.size(), 8, "canonical route crosses all eight trunk maps")
	for scene in ["orient_acre", "austerlitz_sun", "saragossa_siege"]:
		t.ok(scene in policy.scenes, "canonical route visits " + scene)
	_fork = _save(engine, "elba-fork")
	_fork_hash = engine.state_hash()
	_fork_log = engine.command_log()
	var available: Array = []
	for offer in engine.query(&"campaign.run").get("branch_offers", []):
		if bool(offer.get("ok", false)):
			available.append(str(offer.get("segment", "")))
	available.sort()
	t.eq(available, ["conquest", "cristo", "ocean"], "earned trunk history opens all three branches")
	_combat(policy, "canonical trunk")
	print("VOLUME2 TRUNK scenes=%d maps=%d commands=%d" % [policy.scenes.size(), policy.chapters.size(), policy.commands.size()])
	if theatre_checkpoint != "":
		var alternate := CardEngine.new()
		t.ok(alternate.load_game(theatre_checkpoint).get("ok", false), "alternate theatres restore the same earned Italy history")
		var alt := Policy.new()
		alt.branch = "trunk"
		alt.preferred.merge({"orient_orders": "stay_europe", "boulogne_orders": "watch_prussia", "bayonne_orders": "back_to_danube"}, true)
		if _reach(alternate, alt, "elba_1815", "three alternate theatres"):
			for scene in ["alps_marengo", "eylau_snow", "wagram_lobau"]:
				t.ok(scene in alt.scenes, "alternate path really visits " + scene)
			for template in ["marengo", "eylau", "wagram"]:
				t.ok(alt.battles.any(func(b: Dictionary) -> bool: return str(b.get("template", "")) == template), "alternate route fights " + template)
			_combat(alt, "alternate trunk")
			_save(alternate, "alternate-elba")
		print("VOLUME2 THEATRES scenes=%d maps=%d commands=%d" % [alt.scenes.size(), alt.chapters.size(), alt.commands.size()])
	return _fork != ""


func _route(engine: CardEngine, route: String) -> void:
	var policy := Policy.new()
	policy.branch = route
	if route == "ocean":
		var good: bool = policy.finish(engine, 9000)
		t.ok(good, "full ocean route remains playable: " + policy.last_error)
		t.eq(engine.query(&"campaign").get("ending_id"), "alliance", "ocean retains its authored alliance ending")
		if not good:
			_dump(policy, engine)
		else:
			_save(engine, "ocean-alliance")
	else:
		var fork := "k_choice_1817" if route == "conquest" else "c_trial"
		if not _reach(engine, policy, fork, route + " newly opened chapters"):
			return
		var channel_checkpoint := ""
		if route == "conquest":
			channel_checkpoint = _save(engine, "iberia-or-channel")
			if not _reach(engine, policy, "k_final", "conquest through the final coalition"):
				return
		if not _settle_battle(engine, policy):
			return
		t.eq(policy.chapters.filter(func(id: String) -> bool: return id.begins_with(route + ":")).size(), 6 if route == "conquest" else 5, route + " traverses every authored chapter")
		var ending_checkpoint := _save(engine, route + "-final-choice")
		if route == "conquest":
			t.ok("ev_morrel_petition" in policy.events, "conquest really resolves the optional Dantes petition")
			_endings(ending_checkpoint, route, "k_final", {"final_peace": "k_pax", "final_crown": "k_iron", "final_resign": "k_return"})
			_channel(channel_checkpoint)
		else:
			t.ok("ev_haydee_constantinople" in policy.events, "Cristo really recruits its witness through Constantinople")
			t.ok("ev_noirtier_eyes" in policy.events, "Cristo really visits the optional Valentine rescue")
			_endings(ending_checkpoint, route, "c_trial", {"let_him_speak": "m_full_ledger", "shield_gerard": "m_name", "mercy": "m_wait_hope"})
	_combat(policy, route)
	print("VOLUME2 ROUTE %s scenes=%d maps=%d battles=%d commands=%d" % [route, policy.scenes.size(), policy.chapters.size(), policy.battles.size(), policy.commands.size()])


func _settle_battle(engine: CardEngine, policy: RefCounted) -> bool:
	for _i in 600:
		var c := engine.query(&"campaign")
		var battle: Dictionary = c.get("battle2", {})
		if str(engine.view().get("phase", "")) == "game_over":
			break
		if str(engine.view().get("phase", "")) == "day" and not bool(c.get("big_fate", {}).get("pending", false)) and (not bool(battle.get("has_battle", false)) or bool(battle.get("resolved", false))):
			return true
		if not bool(policy.step(engine).get("ok", false)):
			break
	t.ok(false, "final anchor battle can be resolved legally: " + policy.last_error)
	_dump(policy, engine)
	return false


func _endings(checkpoint: String, route: String, scene: String, endings: Dictionary) -> void:
	if checkpoint == "":
		return
	for choice in endings:
		var engine := CardEngine.new()
		t.ok(engine.load_game(checkpoint).get("ok", false), route + " final choice restores the earned route")
		var policy := Policy.new()
		policy.branch = route
		policy.preferred[scene] = choice
		var available := false
		for option in engine.query(&"card", {"uid": "story:" + scene}).get("choices", []):
			if str(option.get("id", "")) == choice or str(option.get("id", "")).ends_with(":" + str(choice)):
				available = bool(option.get("enabled", false))
		t.ok(available, "earned route makes ending choice available: " + str(choice))
		var good: bool = policy.finish(engine, 200)
		t.ok(good, route + " final decision resolves: " + policy.last_error)
		t.eq(engine.view().get("phase"), "game_over", route + " reaches final outcome screen")
		t.eq(engine.query(&"campaign").get("ending_id"), endings[choice], "actual choices reach " + str(endings[choice]))
		if not good or str(engine.query(&"campaign").get("ending_id", "")) != str(endings[choice]):
			_dump(policy, engine)
		else:
			_save(engine, str(endings[choice]))
		print("VOLUME2 ENDING %s commands=%d" % [engine.query(&"campaign").get("ending_id", ""), policy.commands.size()])
		_remember(policy)


func _channel(checkpoint: String) -> void:
	if checkpoint == "":
		return
	var engine := CardEngine.new()
	t.ok(engine.load_game(checkpoint).get("ok", false), "channel route restores the same earned 1817 state")
	var policy := Policy.new()
	policy.branch = "conquest"
	policy.preferred["k_choice_1817"] = "to_channel"
	if _reach(engine, policy, "k_warsaw", "alternate Channel invasion"):
		t.ok("k_dover" in policy.scenes and "k_torres_vedras" not in policy.scenes, "Channel decision selects Dover instead of Torres Vedras")
		t.ok(policy.battles.any(func(b: Dictionary) -> bool: return str(b.get("template", "")) == "channel_landing"), "Channel route really fights its naval landing")
		_save(engine, "channel-to-niemen")
	_remember(policy)


func _combat(policy: RefCounted, label: String) -> void:
	_remember(policy)
	t.ok(not policy.battles.is_empty(), label + " contains actual combat")
	t.ok(policy.battles.all(func(b: Dictionary) -> bool: return str(b.get("outcome", "")) in ["victory", "defeat"]), label + " fights each battle without automatic retreat")
	t.ok(policy.battles.all(func(b: Dictionary) -> bool: return int(b.get("commands", 0)) > 0), label + " sends real deployment/combat commands")


func _remember(policy: RefCounted) -> void:
	_promotions += int(policy.promotions)
	for scene in policy.scenes:
		_visited_scenes[str(scene)] = true


func _dump(policy: RefCounted, engine: CardEngine) -> void:
	var campaign := engine.query(&"campaign")
	var brief := {"segment": campaign.get("segment"), "scene": campaign.get("scene_id"), "phase": campaign.get("phase"),
		"ending": campaign.get("ending_id"), "coins": campaign.get("coins"), "gauges": campaign.get("gauges")}
	print("VOLUME2 STOP ", policy.last_error, " campaign=", JSON.stringify(brief), " map=", JSON.stringify(engine.query(&"campaign.map")))
	print("VOLUME2 LAST COMMANDS ", policy.commands.slice(maxi(0, policy.commands.size() - 12)))
	engine.save_game("/tmp/napoleon-volume2-failure-" + str(policy.branch) + ".json")
