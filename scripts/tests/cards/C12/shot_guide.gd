# C12 指引截图（不进清单）：guide_gd.d1.spot.png。
# xvfb-run -a -s "-screen 0 1280x720x24" $GODOT --rendering-driver opengl3 --audio-driver Dummy --path . \
#     -s res://scripts/tests/cards/C12/shot_guide.gd -- --out=<目录>
extends SceneTree

const Lib = preload("res://scripts/tests/cards/C12/c12_lib.gd")


func _initialize() -> void:
	_run()


func _run() -> void:
	var out_dir := "/tmp/shots/C12"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out_dir = a.substr(6)
	DirAccess.make_dir_recursive_absolute(out_dir)
	var bus := CardEventBus.new()
	root.add_child(bus)
	var mock := MockCardEngine.new(bus)
	if mock.db == null:
		push_error("shot: no card db")
	await process_frame
	var game := Lib.open_game(self, Lib.fixture("hairpin"))
	game.bind_bus(bus)
	var guide: CardGuide = load("res://scenes/cards/shell/GuideOverlay.tscn").instantiate()
	root.add_child(guide)
	guide.bind(mock, bus)
	guide.force(true)
	guide.skip_fades = true
	guide.load_steps(CardDB.read_json("res://scripts/tests/cards/C12/guide_steps.json"))
	for _i in 4:
		await process_frame
	bus.first_time.emit(&"mg.spot", {"uid": "c0002"})
	guide.evaluate_now()
	for _i in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	var path := out_dir.path_join("guide_gd.d1.spot.png")
	root.get_viewport().get_texture().get_image().save_png(path)
	print("SHOT ", path)
	guide.queue_free()
	game.queue_free()
	bus.queue_free()
	CardText.setup(null)
	CardAnchors.clear()
	await process_frame
	quit(0)
