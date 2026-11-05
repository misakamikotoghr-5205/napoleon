# Screenshots for the fortune stall and the almanac strip. Not in the suite.
# xvfb-run -a -s "-screen 0 1280x720x24" $GODOT --rendering-driver opengl3 --audio-driver Dummy --path . \
#     -s res://scripts/tests/cards/C07/shot_fortune.gd -- --out=/tmp/shots/C07
extends SceneTree

const H = preload("res://scripts/tests/cards/C07/c07_harness.gd")


func _initialize() -> void:
	_run()


func _run() -> void:
	var out_dir := "/tmp/shots/C07"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out_dir = a.substr(6)
	DirAccess.make_dir_recursive_absolute(out_dir)
	var bus := CardEventBus.new()
	root.add_child(bus)
	await _table(bus, out_dir)
	await _panel(bus, out_dir, "teller_both", "panel_both", false)
	await _panel(bus, out_dir, "lot_only", "panel_lot_only", false)
	await _panel(bus, out_dir, "cezi_only", "panel_cezi_only", false)
	await _shake(bus, out_dir)
	await _lot_result(bus, out_dir)
	await _cezi(bus, out_dir)
	bus.queue_free()
	await process_frame
	quit(0)


func _table(bus: CardEventBus, out_dir: String) -> void:
	var game: CardGameRoot = load(CardIds.ROOT_SCENE).instantiate()
	game.boot({"mock": true, "bus": bus, "fixture": H.FIX + "almanac_done.json", "skip_title": true})
	root.add_child(game)
	for _i in 6:
		await process_frame
	await _save(out_dir, "almanac_strip")
	game.queue_free()
	CardAnchors.clear()
	await process_frame


func _panel(bus: CardEventBus, out_dir: String, fixture: String, file_name: String, fast: bool) -> void:
	var m := H.mock(bus, fixture)
	var panel: CardFortunePanel = load(H.PANEL).instantiate()
	panel.bind(m, bus)
	panel.fast_anim = fast
	root.add_child(panel)
	panel.open({"uid": H.UID})
	for _i in 3:
		await process_frame
	await _save(out_dir, file_name)
	panel.queue_free()
	await process_frame


func _shake(bus: CardEventBus, out_dir: String) -> void:
	var m := H.mock(bus, "lot_only")
	var panel: CardFortunePanel = load(H.PANEL).instantiate()
	panel.bind(m, bus)
	panel.fast_anim = false
	root.add_child(panel)
	panel.open({"uid": H.UID})
	await process_frame
	H.button_by_key(panel, "c07.btn.lot").pressed.emit()
	for _i in 4:
		await process_frame
	await _save(out_dir, "lot_shake")
	panel.queue_free()
	await process_frame


func _lot_result(bus: CardEventBus, out_dir: String) -> void:
	var m := H.mock(bus, "after_lot")
	var panel: CardFortunePanel = load(H.PANEL).instantiate()
	panel.bind(m, bus)
	root.add_child(panel)
	panel.open({"uid": H.UID})
	for _i in 3:
		await process_frame
	await _save(out_dir, "lot_result")
	panel.queue_free()
	await process_frame


func _cezi(bus: CardEventBus, out_dir: String) -> void:
	var m := H.mock(bus, "cezi_only")
	var panel: CardFortunePanel = load(H.PANEL).instantiate()
	panel.bind(m, bus)
	root.add_child(panel)
	panel.open({"uid": H.UID})
	await process_frame
	H.button_by_key(panel, "c07.btn.cezi").pressed.emit()
	for _i in 2:
		await process_frame
	await _save(out_dir, "cezi_chars")
	H.char_buttons(panel)[1].pressed.emit()
	for _i in 2:
		await process_frame
	await _save(out_dir, "cezi_result")
	panel.queue_free()
	await process_frame


func _save(out_dir: String, file_name: String) -> void:
	await RenderingServer.frame_post_draw
	var path := out_dir.path_join(file_name + ".png")
	var img := root.get_viewport().get_texture().get_image()
	img.save_png(path)
	print("SHOT ", path)
