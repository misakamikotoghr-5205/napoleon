# C10 指引截图（不进清单）。每个步骤一张 guide_<步骤 id>.png。
# xvfb-run -a -s "-screen 0 1280x720x24" $GODOT --rendering-driver opengl3 --audio-driver Dummy --path . \
#     -s res://scripts/tests/cards/C10/shot_guide.gd -- --out=/tmp/shots/C10
extends SceneTree

const FX := "res://scripts/tests/cards/C10/fixtures/guide_play.json"
const STEPS := "res://scripts/tests/cards/C10/guide_steps.json"


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
	game.guide.force(true)
	game.guide.skip_fades = true
	game.guide.load_steps(CardDB.read_json(STEPS))
	for i in range(4):
		await process_frame
	game.guide.evaluate_now()
	await _shot(game, out_dir, "gd.d2.rules")
	game.host.open_panel(&"help", {})
	for i in range(2):
		await process_frame
	game.host.close_top()
	for i in range(1):
		await process_frame
	game.engine.send(&"day.begin", {})
	for i in range(2):
		await process_frame
	bus.first_time.emit(&"news", {"uid": "c0010"})
	game.guide.evaluate_now()
	await _shot(game, out_dir, "gd.news")
	bus.ui_event.emit(&"hand_selected", {"uid": "c0010"})
	bus.first_time.emit(&"dossier", {"person": "brother"})
	game.guide.evaluate_now()
	await _shot(game, out_dir, "gd.dossier")
	game.host.open_panel(&"dossier", {})
	for i in range(2):
		await process_frame
	bus.first_time.emit(&"dossier_gap", {"person": "brother"})
	game.guide.evaluate_now()
	await _shot(game, out_dir, "gd.dossier_gap")
	game.guide.tick(4.0)
	_press(game.host.top_panel(), "linsao")
	for i in range(2):
		await process_frame
	bus.first_time.emit(&"year_after", {"person": "linsao"})
	game.guide.evaluate_now()
	await _shot(game, out_dir, "gd.year_after")
	game.queue_free()
	bus.queue_free()
	await process_frame
	quit(0)


func _press(panel: Node, person: String) -> void:
	if panel == null:
		return
	var stack: Array = [panel]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is Button and n.has_meta(&"c10_person") and str(n.get_meta(&"c10_person")) == person:
			(n as Button).pressed.emit()
			return
		for c in n.get_children():
			stack.append(c)


func _shot(game: CardGameRoot, out_dir: String, id: String) -> void:
	for i in range(2):
		await process_frame
	await RenderingServer.frame_post_draw
	var path := out_dir.path_join("guide_" + id + ".png")
	root.get_viewport().get_texture().get_image().save_png(path)
	print("SHOT " + path + " " + game.guide.active_step())
