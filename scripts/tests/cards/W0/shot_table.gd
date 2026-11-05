# W0 截图脚本（不进清单，§12.3）：每个基础夹具一张牌桌截图（指引开着），给界面任务看截图做法、给 Claude 看桩的样子。
# xvfb-run -a -s "-screen 0 1280x720x24" $GODOT --rendering-driver opengl3 --audio-driver Dummy --path . \
#     -s res://scripts/tests/cards/W0/shot_table.gd -- --out=<目录>
extends SceneTree

const FIXTURES: Array[String] = ["month_open", "month_wheel", "morning", "day_full", "day_counter", "night", "settle",
	"month_close", "year_jump", "street_prison"]


func _initialize() -> void:
	_run()


func _run() -> void:
	var out_dir := ProjectSettings.globalize_path("user://shots/W0")
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out_dir = a.substr(6)
	DirAccess.make_dir_recursive_absolute(out_dir)
	var bus := CardEventBus.new()
	root.add_child(bus)
	for name in FIXTURES:
		var game: CardGameRoot = load(CardIds.ROOT_SCENE).instantiate()
		game.boot({"mock": true, "bus": bus, "fixture": name, "skip_title": true, "guide": "on"})
		root.add_child(game)
		game.guide.force(true)
		game.guide.skip_fades = true
		for i in range(6):
			await process_frame
		game.guide.evaluate_now()
		for i in range(4):
			await process_frame
		await RenderingServer.frame_post_draw
		var path := out_dir.path_join("W0_%s.png" % name)
		root.get_viewport().get_texture().get_image().save_png(path)
		print("SHOT ", path)
		game.queue_free()
		CardAnchors.clear()
		await process_frame
	bus.queue_free()
	CardText.setup(null)
	await process_frame
	quit(0)
