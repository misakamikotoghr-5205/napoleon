# C09 screenshots (not in the suite). 1280x720.
# xvfb-run -a -s "-screen 0 1280x720x24" godot --rendering-driver opengl3 --audio-driver Dummy --path . \
#   -s res://scripts/tests/cards/C09/shot_month.gd -- --out=/tmp/shots/C09
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
	await _month_open(out_dir)
	await _month_close(out_dir)
	await _year(out_dir)
	await _game_over(out_dir)
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


func _mount(scene: String, fixture: String, night: bool) -> CardPanel:
	var pack := S.mount(self, fixture)
	S.mount_stage(self, pack["mock"].view(), night)
	return S.open_panel(self, pack, scene)


func _month_open(out_dir: String) -> void:
	var p := _mount("res://scenes/cards/month/MonthOpen.tscn", "res://scripts/tests/cards/C09/fixtures/month_open_three.json", false)
	await _shot(out_dir, "month_open_para")
	var guard := 0
	while not S.goals_visible(p) and guard < 8:
		S.tap(p, KEY_SPACE)
		guard += 1
	await _shot(out_dir, "month_open_goals")
	p.queue_free()
	await process_frame


func _month_close(out_dir: String) -> void:
	var p := _mount("res://scenes/cards/month/MonthClose.tscn", "res://scripts/tests/cards/C09/fixtures/month_close_goals.json", true)
	await _shot(out_dir, "month_close")
	p.queue_free()
	await process_frame


func _year(out_dir: String) -> void:
	var p := _mount("res://scenes/cards/month/YearJump.tscn", "res://scripts/tests/cards/C09/fixtures/year_jump_sections.json", true)
	var seen := {}
	var guard := 0
	while guard < 12:
		var sec := str(p.find_child("YearBody", true, false).get_meta("section", ""))
		if sec != "" and not seen.has(sec):
			seen[sec] = true
			await _shot(out_dir, "year_" + sec)
		var nxt := p.find_child("NextYear", true, false) as Button
		if nxt != null and nxt.visible:
			break
		S.tap(p, KEY_SPACE)
		guard += 1
	p.queue_free()
	await process_frame


func _game_over(out_dir: String) -> void:
	var p := _mount("res://scenes/cards/month/GameOver.tscn", "res://scripts/tests/cards/C09/fixtures/game_over_prison.json", true)
	var args: Dictionary = CardDB.read_json("res://scripts/tests/cards/C09/fixtures/game_over_prison.json")["view"]["open_panel"]["args"]
	p.open(args)
	await _shot(out_dir, "game_over")
	p.queue_free()
	await process_frame
