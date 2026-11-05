# Screenshots of the rogue v1 UI on the Mock table. Not in the suite (needs a display).
# xvfb-run -a -s "-screen 0 1280x720x24" $GODOT --path . --rendering-driver opengl3 --audio-driver Dummy \
#     --resolution 1280x720 -s res://scripts/tests/cards/RG4/shot_rogue.gd -- --out=/tmp/shots/RG4
# Shots: overlay with three / two cards, full shelf release step, the peddler, the curio drawer (plain, pending,
# resting in prison), the scene's curio shelf by day and by night, the title run box (with a spine hovered).
# --real-text: after boot, CardText reads the whole data set (not only the Mock's examples), so the shots show the
# relic / source / opening words once RG3 and RG5 have them; the open panel is reopened with that text.
extends SceneTree

const H = preload("res://scripts/tests/cards/RG4/rg4_harness.gd")

var _out := "/tmp/shots/RG4"
var _real := false


func _initialize() -> void:
	_run()


func _run() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.substr(6)
		elif a == "--real-text":
			_real = true
	DirAccess.make_dir_recursive_absolute(_out)
	var bus := CardEventBus.new()
	root.add_child(bus)
	await _overlay(bus, "rogue_week", "stock_three", -1)
	await _overlay(bus, "rogue_few", "stock_two", 1)
	await _full(bus)
	await _overlay(bus, "rogue_peddler", "stock_peddler", -1)
	await _drawer(bus, "rogue_drawer", "drawer")
	await _drawer(bus, "rogue_drawer_pending", "drawer_pending")
	await _drawer(bus, "rogue_street", "drawer_street")
	await _scene(bus, "rogue_drawer", "shelf_day")
	await _scene(bus, "rogue_week", "shelf_night")
	await _title(bus)
	bus.queue_free()
	await process_frame
	quit(0)


func _overlay(bus: CardEventBus, fixture: String, file_name: String, key_pick: int) -> void:
	var game := H.boot(self, bus, fixture)
	await _settle()
	await _reopen(game)
	if key_pick >= 0:
		await H.tap(self, KEY_1 + key_pick)
	await _save(file_name)
	await _drop(game)


func _full(bus: CardEventBus) -> void:
	var game := H.boot(self, bus, "rogue_full")
	await _settle()
	await _reopen(game)
	var panel = game.host.top_overlay()
	if panel != null:
		panel.cards()[0].button().pressed.emit()
		await process_frame
		await H.tap(self, KEY_2)
	await _save("stock_full_release")
	await _drop(game)


func _drawer(bus: CardEventBus, fixture: String, file_name: String) -> void:
	var game := H.boot(self, bus, fixture)
	await _settle()
	while game.host.top_panel() != null:
		game.host.close_panel(game.host.top_panel())
	game.dialog.clear()
	await process_frame
	_real_text()
	game.host.open_panel(&"relics", {})
	await _settle()
	await _save(file_name)
	await _drop(game)


func _scene(bus: CardEventBus, fixture: String, file_name: String) -> void:
	var game := H.boot(self, bus, fixture)
	await _settle()
	while game.host.top_panel() != null:
		game.host.close_panel(game.host.top_panel())
	game.dialog.clear()
	await _settle()
	await _save(file_name)
	await _drop(game)


func _title(bus: CardEventBus) -> void:
	var game: CardGameRoot = load(CardIds.ROOT_SCENE).instantiate()
	game.boot({"mock": true, "bus": bus, "fixture": "morning", "settings_path": "", "guide": "off"})
	root.add_child(game)
	await _settle()
	_real_text()
	if game.title != null:
		game.title.set_rogue({"run_no": 4, "seed": 1844671223, "opening": "og.shanghai",
			"openings": [{"id": "og.default", "unlocked": true}, {"id": "og.shanghai", "unlocked": true}],
			"shelf": [
				{"no": 1, "key": "rg5.chronicle.prison.1939", "args": {"d": 17}, "reason": "prison", "opening": "og.default"},
				{"no": 2, "key": "rg5.chronicle.abandoned.1938", "args": {"d": 9}, "reason": "abandoned", "opening": "og.default"},
				{"no": 3, "key": "rg5.chronicle.ending.kind", "args": {}, "reason": "ending", "opening": "og.default"}],
			"notice_key": "rg5.toast.profile_reset"})
		await _settle()
		await _save("title_box")
		var spines: Array = game.title.get_node("RunBox").spines()
		if spines.size() > 0:
			await H.hover(self, (spines[0] as Control).get_global_rect().get_center())
			await _settle()
			await _save("title_box_hover")
	await _drop(game)


## --real-text: read the whole data set's words; the stocktake overlay the root opened is opened again with them.
func _reopen(game: CardGameRoot) -> void:
	if not _real:
		return
	_real_text()
	var open: Dictionary = game.engine.view().get("open_panel", {})
	game.host.close_all()
	game.host.open_panel(&"stocktake", open.get("args", {}))
	await _settle()


func _real_text() -> void:
	if _real:
		CardText.setup(CardDB.load_all(CardDB.DEFAULT_ROOT, {}))


func _settle() -> void:
	for _i in 30:
		await process_frame


func _save(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.save_png("%s/%s.png" % [_out, file_name])
	print("shot " + file_name)


func _drop(game: Node) -> void:
	game.queue_free()
	CardAnchors.clear()
	await process_frame
	await process_frame
