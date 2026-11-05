# C01 指引截图（不进清单）：每个要证的步骤亮起时一张 guide_<步骤 id>.png。
# xvfb-run -a -s "-screen 0 1280x720x24" $GODOT --rendering-driver opengl3 --audio-driver Dummy --path . \
#     -s res://scripts/tests/cards/C01/shot_guide.gd -- --out=/tmp/shots/C01
extends SceneTree

const STEPS_PATH := "res://scripts/tests/cards/C01/guide_steps.json"
const FIX := "res://scripts/tests/cards/C01/fixtures/guide_day.json"


func _initialize() -> void:
	_run()


func _run() -> void:
	var out_dir := "/tmp/shots/C01"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out_dir = a.substr(6)
	DirAccess.make_dir_recursive_absolute(out_dir)
	var bus := CardEventBus.new()
	root.add_child(bus)
	var game: CardGameRoot = load(CardIds.ROOT_SCENE).instantiate()
	game.boot({"mock": true, "bus": bus, "fixture": FIX, "skip_title": true})
	root.add_child(game)
	for i in range(4):
		await process_frame
	game.guide.force(true)
	game.guide.skip_fades = true
	var data: Dictionary = CardDB.read_json(STEPS_PATH)
	game.guide.load_steps(data)
	var steps: Array = data.get("steps", [])
	steps.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("priority", 0)) > int(b.get("priority", 0)))
	var seen := {}
	for step in steps:
		var first := str(step.get("trigger", {}).get("first", ""))
		if first != "" and not seen.has(first):
			seen[first] = true
			bus.first_time.emit(StringName(first), {})
	for step in steps:
		var id := str(step.get("id", ""))
		game.guide.evaluate_now()
		for i in range(2):
			await process_frame
		await RenderingServer.frame_post_draw
		var path := out_dir.path_join("guide_%s.png" % id)
		root.get_viewport().get_texture().get_image().save_png(path)
		print("SHOT ", path)
		bus.ui_event.emit(&"hand_selected", {"uid": "c0101"})
		await process_frame
	game.queue_free()
	bus.queue_free()
	CardText.setup(null)
	CardAnchors.clear()
	await process_frame
	quit(0)
