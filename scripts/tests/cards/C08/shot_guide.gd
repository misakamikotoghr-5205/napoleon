# C08 guide screenshots (not in the suite): one PNG per step, named guide_<step id>.png.
# xvfb-run -a -s "-screen 0 1280x720x24" $GODOT --rendering-driver opengl3 --audio-driver Dummy --path . \
#   -s res://scripts/tests/cards/C08/shot_guide.gd -- --out=res://scripts/tests/cards/C08/shots
# Owner C08.
extends SceneTree

const Support = preload("res://scripts/tests/cards/C08/support.gd")
const STEPS := "res://scripts/tests/cards/C08/guide_steps.json"


func _initialize() -> void:
	_run()


func _run() -> void:
	var out_dir := "res://scripts/tests/cards/C08/shots"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.substr(6)
	var abs := ProjectSettings.globalize_path(out_dir)
	DirAccess.make_dir_recursive_absolute(abs)
	var data: Dictionary = CardDB.read_json(STEPS)
	await _one(abs, data, "end_day_items", &"end_day", {}, &"must_resolve", "gd.must")
	await _one(abs, data, "end_day_gold", &"end_day", {}, &"gold_leave", "gd.gold_leave")
	await _one(abs, data, "night", &"night", {}, &"night", "gd.d1.night")
	await _one(abs, data, "settle_lines", &"settle", {}, &"settle", "gd.d1.settle")
	quit(0)


func _one(abs: String, data: Dictionary, fixture: String, kind: StringName, args: Dictionary,
		mech: StringName, step_id: String) -> void:
	var mounted: Array = Support.mount(self, fixture)
	var bus: CardEventBus = mounted[0]
	var mock: MockCardEngine = mounted[1]
	var host: CardModalHost = mounted[2]
	var layer := CanvasLayer.new()
	layer.layer = 100
	root.add_child(layer)
	var guide: CardGuide = load("res://scenes/cards/shell/GuideOverlay.tscn").instantiate()
	layer.add_child(guide)
	guide.bind(mock, bus)
	guide.force(true)
	guide.skip_fades = true
	guide.load_steps(data)
	host.open_panel(kind, args)
	for _i in range(3):
		await process_frame
	bus.first_time.emit(mech, {})
	guide.evaluate_now()
	for _i in range(4):
		await process_frame
	await RenderingServer.frame_post_draw
	var path := abs.path_join("guide_%s.png" % step_id)
	var image := root.get_viewport().get_texture().get_image()
	image.save_png(path)
	print("SHOT %s %dx%d step=%s" % [path, image.get_width(), image.get_height(), guide.active_step()])
	guide.queue_free()
	layer.queue_free()
	host.queue_free()
	bus.queue_free()
	CardAnchors.clear()
	await process_frame
