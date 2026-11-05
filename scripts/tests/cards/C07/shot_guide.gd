# One 1280x720 frame per guide step. Not in the suite.
# xvfb-run -a -s "-screen 0 1280x720x24" $GODOT --rendering-driver opengl3 --audio-driver Dummy --path . \
#     -s res://scripts/tests/cards/C07/shot_guide.gd -- --out=/tmp/shots/C07
extends SceneTree

const H = preload("res://scripts/tests/cards/C07/c07_harness.gd")
const STEPS := "res://scripts/tests/cards/C07/guide_steps.json"


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
	var game := await _boot(bus, "almanac_done")
	bus.first_time.emit(&"almanac", {})
	game.guide.evaluate_now()
	await _shot(out_dir, "guide_gd.almanac")
	game.queue_free()
	CardAnchors.clear()
	await process_frame
	game = await _boot(bus, "teller_both")
	game.host.open_panel(&"fortune", {"uid": H.UID})
	for _i in 2:
		await process_frame
	bus.first_time.emit(&"lot", {"uid": H.UID})
	game.guide.evaluate_now()
	await _shot(out_dir, "guide_gd.lot")
	var panel := game.host.top_panel() as CardFortunePanel
	panel.fast_anim = true
	H.button_by_key(panel, "c07.btn.lot").pressed.emit()
	H.button_by_key(panel, "c07.btn.ok").pressed.emit()
	await process_frame
	game.host.open_panel(&"fortune", {"uid": H.UID})
	await process_frame
	bus.first_time.emit(&"cezi", {"uid": H.UID})
	game.guide.evaluate_now()
	await _shot(out_dir, "guide_gd.cezi")
	game.queue_free()
	bus.queue_free()
	await process_frame
	quit(0)


func _boot(bus: CardEventBus, fixture: String) -> CardGameRoot:
	var game: CardGameRoot = load(CardIds.ROOT_SCENE).instantiate()
	game.boot({"mock": true, "bus": bus, "fixture": H.FIX + fixture + ".json", "skip_title": true})
	root.add_child(game)
	game.guide.force(true)
	game.guide.skip_fades = true
	game.guide.load_steps(CardDB.read_json(STEPS))
	for _i in 6:
		await process_frame
	return game


func _shot(out_dir: String, file_name: String) -> void:
	for _i in 2:
		await process_frame
	await RenderingServer.frame_post_draw
	var path := out_dir.path_join(file_name + ".png")
	root.get_viewport().get_texture().get_image().save_png(path)
	print("SHOT ", path)
