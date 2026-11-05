# C09 guide screenshots (not in the suite). One 1280x720 PNG per step: guide_<step id>.png
# xvfb-run -a -s "-screen 0 1280x720x24" godot --rendering-driver opengl3 --audio-driver Dummy --path . \
#   -s res://scripts/tests/cards/C09/shot_guide.gd -- --out=/tmp/shots/C09
extends SceneTree

const S = preload("res://scripts/tests/cards/C09/c09_support.gd")


func _initialize() -> void:
	_run()


func _run() -> void:
	var out_dir := "/tmp/shots/C09"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out_dir = a.substr(6)
	DirAccess.make_dir_recursive_absolute(out_dir)
	S.fast_anim_file(true)
	await _one(out_dir, "month_open", "res://scripts/tests/cards/C09/fixtures/month_open_three.json", "gd.m.open", true)
	await _one(out_dir, "month_close", "res://scripts/tests/cards/C09/fixtures/month_close_goals.json", "gd.month_close", false)
	await _year(out_dir, "gd.year_jump", "forfeit")
	await _year(out_dir, "gd.year_after", "after")
	await _one(out_dir, "game_over", "res://scripts/tests/cards/C09/fixtures/game_over_prison.json", "gd.game_over", false)
	await _retry(out_dir)
	S.fast_anim_file(false)
	print("SHOTS DONE")
	quit(0)


func _shot(out_dir: String, name: String) -> void:
	for _i in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	var path := out_dir.path_join(name + ".png")
	var img := root.get_viewport().get_texture().get_image()
	img.save_png(path)
	print("SHOT ", path, " ", img.get_width(), "x", img.get_height())


func _one(out_dir: String, kind: String, fixture: String, step: String, to_goals: bool) -> void:
	var pack := S.mount(self, fixture)
	S.mount_stage(self, pack["mock"].view(), kind != "month_open")
	var host := CardModalHost.new()
	host.bind(pack["mock"], pack["bus"])
	root.add_child(host)
	var guide := S.attach_guide(self, pack)
	var args := {}
	if kind == "game_over":
		args = CardDB.read_json(fixture)["view"]["open_panel"]["args"]
	host.open_panel(StringName(kind), args)
	var panel := host.top_panel()
	if panel is CardMonthOpen and to_goals:
		var guard := 0
		while not S.goals_visible(panel) and guard < 8:
			panel.autoplay_step()
			guard += 1
	await process_frame
	var mech := step.trim_prefix("gd.").trim_prefix("m.")
	if step == "gd.m.open":
		mech = "month_open"
	elif step == "gd.month_close":
		mech = "month_close"
	elif step == "gd.game_over":
		mech = "game_over"
	pack["bus"].first_time.emit(StringName(mech), {})
	guide.evaluate_now()
	await _shot(out_dir, "guide_" + step)
	host.queue_free()
	guide.queue_free()
	await process_frame
	CardAnchors.clear()


func _year(out_dir: String, step: String, section: String) -> void:
	var pack := S.mount(self, "res://scripts/tests/cards/C09/fixtures/year_jump_sections.json")
	S.mount_stage(self, pack["mock"].view(), true)
	var host := CardModalHost.new()
	host.bind(pack["mock"], pack["bus"])
	root.add_child(host)
	var guide := S.attach_guide(self, pack)
	host.open_panel(&"year_jump", {})
	var panel := host.top_panel()
	var guard := 0
	while str(panel.find_child("YearBody", true, false).get_meta("section", "")) != section and guard < 8:
		panel.autoplay_step()
		guard += 1
	await process_frame
	var mech := "year_jump" if step == "gd.year_jump" else "year_after"
	pack["bus"].first_time.emit(StringName(mech), {})
	guide.evaluate_now()
	await _shot(out_dir, "guide_" + step)
	host.queue_free()
	guide.queue_free()
	await process_frame
	CardAnchors.clear()


func _retry(out_dir: String) -> void:
	var bus := CardEventBus.new()
	root.add_child(bus)
	var game: CardGameRoot = load(CardIds.ROOT_SCENE).instantiate()
	game.boot({"mock": true,
		"bus": bus,
		"fixture": "month_open",
		"skip_title": true,
		"guide": "off",
		"settings_path": "user://shots_c09_settings.json",
	})
	root.add_child(game)
	await process_frame
	await process_frame
	game.guide.force(true)
	game.guide.skip_fades = true
	game.guide.load_steps(S.guide_data())
	bus.first_time.emit(&"retry", {})
	game.guide.evaluate_now()
	await _shot(out_dir, "guide_gd.retry")
	game.queue_free()
	bus.queue_free()
	await process_frame
	CardAnchors.clear()
