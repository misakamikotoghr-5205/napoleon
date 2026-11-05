# K16 screenshots (not in the suite): days 1-3 on the real table, one 1280x720 PNG per lit step.
# xvfb-run -a -s "-screen 0 1280x720x24" $GODOT --rendering-driver opengl3 --audio-driver Dummy --path . \
#     -s res://scripts/tests/cards/K16/shot_d1_3.gd -- --out=scripts/tests/cards/K16/shots/d1_3
extends SceneTree


func _initialize() -> void:
	_run()


func _run() -> void:
	var out_dir := ProjectSettings.globalize_path("user://shots/K16_d1_3")
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out_dir = a.substr(6)
	DirAccess.make_dir_recursive_absolute(out_dir)
	var raw: Dictionary = CardDB.read_json("res://data/cards/guide/steps.json")
	var want: Array = raw.get("_test", {}).get("d1_3", [])
	var bus := CardEventBus.new()
	root.add_child(bus)
	var game: CardGameRoot = load(CardIds.ROOT_SCENE).instantiate()
	game.boot({"mock": true, "bus": bus, "seed": 7, "skip_title": true, "guide": "on"})
	root.add_child(game)
	game.guide.force(true)
	game.guide.skip_fades = true
	var settings: Dictionary = game.engine.query(&"guide_data").get("settings", {})
	game.guide.load_steps({"steps": raw.get("cards", []), "pages": [], "settings": settings})
	game.guide.shown_log = PackedStringArray()
	for _i in 2:
		await process_frame
	var got: Array = []
	var n := 0
	while n < 600:
		await _cap(game, out_dir, got)
		var v: Dictionary = game.engine.view()
		if str(v.get("phase", "")) == "morning" and int(v.get("date", {}).get("stage_day", 0)) == 4:
			break
		game.autoplay_step()
		await process_frame
		game.guide.tick(0.5)
		game.guide.evaluate_now()
		n += 1
	await _cap(game, out_dir, got)
	print("SHOT_COUNT %d" % got.size())
	for id in want:
		if not got.has(id):
			print("MISSED %s" % id)
	game.queue_free()
	bus.queue_free()
	await process_frame
	quit(0)


func _cap(game: CardGameRoot, out_dir: String, got: Array) -> void:
	var id := game.guide.active_step()
	if id == "" or got.has(id):
		return
	await RenderingServer.frame_post_draw
	var img := root.get_viewport().get_texture().get_image()
	if img == null or img.get_width() < 2:
		print("MISSED %s empty viewport" % id)
		return
	var path := out_dir.path_join("%s.png" % id)
	img.save_png(path)
	got.append(id)
	print("SHOT %s" % id)

