# C05 指引截图（不进清单）：每个还归本任务的步骤一张 guide_<步骤 id>.png。
# gd.demand 归 C01（a.scene.notewall），这里不再拍。
# xvfb-run -a -s "-screen 0 1280x720x24" $GODOT --rendering-driver opengl3 --audio-driver Dummy --path . \
#   -s res://scripts/tests/cards/C05/shot_guide.gd -- --out=/tmp/shots/C05
extends SceneTree

const S = preload("res://scripts/tests/cards/C05/support.gd")


func _initialize() -> void:
	_run()


func _run() -> void:
	var out_dir := ProjectSettings.globalize_path("res://scripts/tests/cards/C05/shots")
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out_dir = a.substr(6)
	DirAccess.make_dir_recursive_absolute(out_dir)
	await _step(out_dir, "delay.json", "gd.demand_delay", &"demand_delay", "d1", true, "d1")
	await _step(out_dir, "people_return.json", "gd.demand_people", &"demand_people_return", "r1", false, "")
	await _step(out_dir, "info.json", "gd.demand_inform", &"demand_inform", "i_inform", true, "i_inform")
	await _step(out_dir, "fail.json", "gd.demand_fail", &"demand_fail", "f1", false, "")
	CardAnchors.clear()
	CardText.setup(null)
	await process_frame
	quit(0)


func _step(out_dir: String, fixture: String, step_id: String, mech: StringName, uid: String,
		open_first: bool, panel_uid: String) -> void:
	var bus := CardEventBus.new()
	root.add_child(bus)
	var game := S.boot(self, bus, fixture)
	S.guide(game)
	for i in 6:
		await process_frame
	if open_first:
		game.host.open_panel(&"demand", {"uid": panel_uid})
		for i in 2:
			await process_frame
		S.skip_dialog(game.host.top_panel() as CardDemandPanel)
		await process_frame
	bus.first_time.emit(mech, {"uid": uid})
	game.guide.evaluate_now()
	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	var path := out_dir.path_join("guide_%s.png" % step_id)
	var img := root.get_viewport().get_texture().get_image()
	img.save_png(path)
	print("SHOT ", path, " ", img.get_width(), "x", img.get_height(), " ", game.guide.active_step())
	game.queue_free()
	bus.queue_free()
	CardAnchors.clear()
	await process_frame
