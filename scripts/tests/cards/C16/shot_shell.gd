# 标题、暂停、设置各一张 1280x720。不进清单。
# xvfb-run -a -s "-screen 0 1280x720x24" godot --rendering-driver opengl3 --audio-driver Dummy --path . \
#     -s res://scripts/tests/cards/C16/shot_shell.gd -- --out=<目录>
extends SceneTree

var _out := ""


func _initialize() -> void:
	_out = ProjectSettings.globalize_path("user://shots/C16")
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.substr(6)
	DirAccess.make_dir_recursive_absolute(_out)
	CardText.setup(CardDB.load_all(CardDB.DEFAULT_ROOT, {}))
	_run()


func _run() -> void:
	var root_dir := "user://test/c16_shot"
	CardSave.set_root(root_dir)
	var legacy := root_dir + "/legacy.json"
	var cards := root_dir + "/cards.json"
	await _shot("title", load("res://scenes/cards/shell/CardTitle.tscn").instantiate(), false, {})
	var pause: CardPause = load("res://scenes/cards/shell/CardPause.tscn").instantiate()
	await _shot("pause", pause, true, {})
	var settings: CardSettings = load("res://scenes/cards/shell/CardSettings.tscn").instantiate()
	await _shot("settings", settings, true, {"settings_path": legacy, "cards_settings_path": cards})
	_rm(root_dir)
	quit(0)


func _shot(name: String, node: Control, is_panel: bool, args: Dictionary) -> void:
	var holder := Control.new()
	holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(holder)
	var bg := ColorRect.new()
	bg.color = CardTheme.color(&"wood_dark")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.add_child(bg)
	holder.add_child(node)
	if is_panel and node is CardPanel:
		(node as CardPanel).open(args)
	for _i in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	var path := _out.path_join("shell_" + name + ".png")
	root.get_viewport().get_texture().get_image().save_png(path)
	print("SHOT " + path)
	holder.queue_free()
	CardAnchors.clear()
	await process_frame


func _rm(dir: String) -> void:
	if not DirAccess.dir_exists_absolute(dir):
		return
	for f in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + "/" + f)
	DirAccess.remove_absolute(dir)
