# C01 截图（不进清单）：基础夹具 + 自己的夹具，以及帮助、暂停。1280×720。
# xvfb-run -a -s "-screen 0 1280x720x24" $GODOT --rendering-driver opengl3 --audio-driver Dummy --path . \
#     -s res://scripts/tests/cards/C01/shot_table.gd -- --out=/tmp/shots/C01
extends SceneTree

const BASE: Array[String] = ["month_open", "month_wheel", "morning", "day_full", "day_counter", "night", "settle",
	"month_close", "year_jump", "street_prison"]
const OWN := "res://scripts/tests/cards/C01/fixtures/"


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
	for name in BASE:
		await _shot(bus, name, out_dir, "C01_%s.png" % name)
	for f in DirAccess.get_files_at(OWN):
		if f.ends_with(".json"):
			await _shot(bus, OWN + f, out_dir, "C01_%s.png" % f.get_basename())
	var game: CardGameRoot = load(CardIds.ROOT_SCENE).instantiate()
	game.boot({"mock": true, "bus": bus, "fixture": "day_full", "skip_title": true, "guide": "off"})
	root.add_child(game)
	for i in range(4):
		await process_frame
	game.host.open_panel(&"help", {})
	await _save(game, out_dir.path_join("C01_help.png"))
	game.host.close_top()
	game.host.open_panel(&"pause", {})
	await _save(game, out_dir.path_join("C01_pause.png"))
	game.host.close_top()
	for tab in ["contacts", "demands", "dossier", "rules", "shelf", "tickets", "estates", "settings"]:
		var spec: Array = CardIds.TAB_PANELS[StringName(tab)]
		var args: Dictionary = (spec[1] as Dictionary).duplicate()
		args["_tab"] = tab
		game.host.open_panel(spec[0], args)
		await _save(game, out_dir.path_join("C01_drawer_%s.png" % tab))
		game.host.close_top()
		await process_frame
	game.queue_free()
	bus.queue_free()
	CardText.setup(null)
	CardAnchors.clear()
	await process_frame
	quit(0)


func _shot(bus: CardEventBus, fixture: String, out_dir: String, file_name: String) -> void:
	var game: CardGameRoot = load(CardIds.ROOT_SCENE).instantiate()
	game.boot({"mock": true, "bus": bus, "fixture": fixture, "skip_title": true, "guide": "off"})
	root.add_child(game)
	for i in range(4):
		await process_frame
	await _save(game, out_dir.path_join(file_name))
	game.queue_free()
	CardAnchors.clear()
	await process_frame


func _save(game: Node, path: String) -> void:
	for i in range(2):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(path)
	print("SHOT ", path)
