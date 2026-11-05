# C10 截图（不进清单）。1280x720：索引、缺口、盖章、一年后、规矩栏、帮助两页、帮助盖在柜台上。
# xvfb-run -a -s "-screen 0 1280x720x24" $GODOT --rendering-driver opengl3 --audio-driver Dummy --path . \
#     -s res://scripts/tests/cards/C10/shot_dossier.gd -- --out=/tmp/shots/C10
extends SceneTree

const FX := "res://scripts/tests/cards/C10/fixtures/dossier_mixed.json"


func _initialize() -> void:
	_run()


func _run() -> void:
	var out_dir := "/tmp/shots/C10"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out_dir = a.substr(6)
	DirAccess.make_dir_recursive_absolute(out_dir)
	var bus := CardEventBus.new()
	root.add_child(bus)
	var game: CardGameRoot = load(CardIds.ROOT_SCENE).instantiate()
	game.boot({"mock": true, "bus": bus, "fixture": FX, "skip_title": true, "guide": "off"})
	root.add_child(game)
	for i in range(4):
		await process_frame
	game.host.open_panel(&"dossier", {})
	for i in range(3):
		await process_frame
	await _shot(out_dir, "dossier_index")
	await _shot(out_dir, "dossier_gap")
	var book := game.host.top_panel()
	_press(book, "wangshan")
	for i in range(2):
		await process_frame
	await _shot(out_dir, "dossier_seal")
	_press(book, "linsao")
	for i in range(2):
		await process_frame
	await _shot(out_dir, "dossier_year")
	_press_tab(book, "rules")
	for i in range(2):
		await process_frame
	await _shot(out_dir, "dossier_rules")
	game.host.close_top()
	for i in range(2):
		await process_frame
	game.host.open_panel(&"help", {})
	for i in range(2):
		await process_frame
	await _shot(out_dir, "help_controls")
	_press_tab(game.host.top_panel(), "rules")
	for i in range(2):
		await process_frame
	await _shot(out_dir, "help_rules")
	game.host.close_top()
	game.host.open_panel(&"counter", {})
	for i in range(2):
		await process_frame
	game.host.open_panel(&"help", {})
	for i in range(3):
		await process_frame
	await _shot(out_dir, "help_over_counter")
	game.queue_free()
	bus.queue_free()
	await process_frame
	quit(0)


func _press(panel: Node, person: String) -> void:
	var stack: Array = [panel]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is Button and n.has_meta(&"c10_person") and str(n.get_meta(&"c10_person")) == person:
			(n as Button).pressed.emit()
			return
		for c in n.get_children():
			stack.append(c)


func _press_tab(panel: Node, tab: String) -> void:
	var stack: Array = [panel]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is Button and n.has_meta(&"c10_tab") and str(n.get_meta(&"c10_tab")) == tab:
			(n as Button).pressed.emit()
			return
		for c in n.get_children():
			stack.append(c)


func _shot(out_dir: String, name: String) -> void:
	await RenderingServer.frame_post_draw
	var path := out_dir.path_join(name + ".png")
	root.get_viewport().get_texture().get_image().save_png(path)
	print("SHOT " + path)
