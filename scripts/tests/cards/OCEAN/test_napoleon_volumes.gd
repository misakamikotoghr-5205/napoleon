## Save compatibility across the first-volume release and the new default book.
## The fixture is an actual untouched 70d7df27 initial save, with implicit game.new book.
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const Book = preload("res://scripts/cards/campaign/run/run_book.gd")
const Bridge = preload("res://scripts/cards/campaign/ocean_bridge.gd")
const Replay = preload("res://scripts/cards/campaign/run/run_replay.gd")
const FIXTURE := "res://scripts/tests/cards/OCEAN/fixtures/volume1-toulon-70d7df27.json"
const V2_FIXTURE := "res://scripts/tests/cards/OCEAN/fixtures/volume2-toulon-fe8df030.json"

var t: RefCounted


func _initialize() -> void:
	t = T.new(self, "OCEAN_napoleon_volumes")
	var had_env := OS.has_environment("DEHOUDANG_CAMPAIGN")
	var old_env := OS.get_environment("DEHOUDANG_CAMPAIGN")
	OS.unset_environment("DEHOUDANG_CAMPAIGN")
	_defaults()
	_restore_first_volume()
	_restore_second_volume()
	if had_env:
		OS.set_environment("DEHOUDANG_CAMPAIGN", old_env)
	else:
		OS.unset_environment("DEHOUDANG_CAMPAIGN")
	print("OCEAN volume compatibility assertions: %d" % t.checks)
	t.finish()


func _defaults() -> void:
	t.eq(Bridge.default_save_dir(), "user://cards/napoleon-demo", "new demo has a separate save root")
	t.eq(Bridge.default_save_dir({"book": "napoleon_volume2"}), "user://cards/napoleon-volume2", "complete second-volume save root is preserved")
	t.eq(Bridge.default_save_dir({"book": "napoleon_volume1"}), "user://cards/napoleon", "first-volume save root is preserved")
	t.eq(Bridge.default_save_dir({"campaign": "ocean_pawn"}), "user://cards/ocean_pawn", "original ocean save root is preserved")
	var second := CardEngine.new()
	var opened := second.new_game({"book": "napoleon_volume2", "seed": 30, "save_dir": t.user_dir() + "/v2"})
	t.ok(opened.get("ok", false), "explicit second volume starts: " + str(opened))
	if not opened.get("ok", false):
		return
	t.eq(second.query(&"campaign.run").get("volume"), 2, "full second volume keeps its mechanics")
	var first := CardEngine.new()
	opened = first.new_game({"book": "napoleon_volume1", "seed": 30, "save_dir": t.user_dir() + "/v1"})
	t.ok(opened.get("ok", false), "explicit volume one still starts")
	if not opened.get("ok", false):
		return
	t.eq(first.query(&"campaign.run").get("volume"), 1, "explicit first-volume mode remains gated")
	var first_hash := first.state_hash()
	var path: String = t.user_dir() + "/v1/suspend.json"
	t.ok(first.save_game(path).get("ok", false), "save first-volume mode")
	var bytes := FileAccess.get_file_as_bytes(path)
	t.ok(second.save_game(t.user_dir() + "/v2/suspend.json").get("ok", false), "save second-volume mode")
	t.eq(FileAccess.get_file_as_bytes(path), bytes, "saving volume two does not overwrite volume one")
	t.ok(first.load_game(path).get("ok", false), "first-volume mode restores with current data")
	t.eq(first.state_hash(), first_hash, "current first-volume save round trip is exact")


func _restore_first_volume() -> void:
	var bytes := FileAccess.get_file_as_bytes(FIXTURE)
	var path: String = t.user_dir() + "/old-toulon.json"
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(bytes)
	file.close()
	var envelope := CardSave.read(path)
	t.ok(envelope.get("ok", false), "real released first-volume save is valid")
	if not envelope.get("ok", false):
		return
	t.ok(not envelope.get("cmd_log", [])[0][1].has("book"), "fixture actually exercised the old implicit default")
	# Always replay too: a compatible definition hash must not hide this regression.
	var replay := Replay.rebuild(envelope, t.user_dir(), Bridge.new_model, Bridge.dispatch_model)
	t.ok(replay.get("ok", false), "old implicit book replays after the default changes: " + str(replay.get("err", "")))
	if replay.get("ok", false):
		t.eq(replay["model"].book.get("path"), Book.VOLUME1, "replay pins the original book path")
		t.eq(replay["model"].state["run"]["volume"], 1, "replay does not silently upgrade old saves")
	var engine := CardEngine.new()
	var restored := engine.load_game(path)
	t.ok(restored.get("ok", false), "released save restores through the public engine: " + str(restored))
	if not restored.get("ok", false):
		return
	t.eq(engine.query(&"campaign.run").get("volume"), 1, "restored old save stays in volume one")
	t.eq(engine.query(&"campaign").get("scene_id"), "toulon_arrival", "old narrative progress is retained")
	t.eq(FileAccess.get_file_as_bytes(path), bytes, "restore never overwrites the original snapshot")
	var hash := engine.state_hash()
	var upgraded: String = t.user_dir() + "/resaved.json"
	t.ok(engine.save_game(upgraded).get("ok", false), "resave migrated data to a separate file")
	t.ok(engine.load_game(upgraded).get("ok", false), "resaved first-volume run restores")
	t.eq(engine.state_hash(), hash, "resaved first-volume state hash is exact")


func _restore_second_volume() -> void:
	var bytes := FileAccess.get_file_as_bytes(V2_FIXTURE)
	var path: String = t.user_dir() + "/old-v2-toulon.json"
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(bytes)
	file.close()
	var envelope := CardSave.read(path)
	t.ok(envelope.get("ok", false), "released full second-volume save is valid")
	if not envelope.get("ok", false):
		return
	t.ok(not envelope.get("cmd_log", [])[0][1].has("book"), "second-volume fixture uses the old implicit default")
	var replay := Replay.rebuild(envelope, t.user_dir(), Bridge.new_model, Bridge.dispatch_model)
	t.ok(replay.get("ok", false), "full second-volume log replays after switching default to demo")
	if replay.get("ok", false):
		t.eq(replay["model"].book.get("path"), Book.NAPOLEON, "replay retains full V2 instead of narrowing to demo")
		t.eq(replay["model"].hash(), Replay.saved_hash(envelope), "old full V2 command replay restores its exact state")
	var engine := CardEngine.new()
	t.ok(engine.load_game(path).get("ok", false), "full V2 restores through the public engine")
	var after := engine.state_hash()
	var saved: String = t.user_dir() + "/v2-resaved.json"
	t.ok(engine.save_game(saved).get("ok", false), "full V2 can be resaved separately")
	t.ok(engine.load_game(saved).get("ok", false), "resaved full V2 loads")
	t.eq(engine.state_hash(), after, "full V2 state survives the save round trip")
	t.eq(FileAccess.get_file_as_bytes(path), bytes, "original full V2 snapshot remains untouched")
