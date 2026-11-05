# 拍 v0.3b 干净柜台 / 侧栏打开 两张截图（需要有显示：DISPLAY 或 xvfb）
extends SceneTree

const MainUI = preload("res://scripts/ui/main.gd")
const World = preload("res://scripts/core/world.gd")

func _initialize() -> void:
	await _run()

func _snap(path: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_viewport().get_texture().get_image()
	img.save_png(path)
	print("SHOT ", path)

func _run() -> void:
	print("shot_v03b start")
	var main = MainUI.new()
	main.autostart = false
	main.set_anchors_preset(Control.PRESET_FULL_RECT)
	main.custom_minimum_size = Vector2(1280, 720)
	main.size = Vector2(1280, 720)
	root.add_child(main)
	await process_frame
	var w = World.new()
	w.setup(19380306)
	main.world = w
	main.view.world = w
	main.db = DB.get_db()
	w.unlocked["ledger"] = true
	w.unlocked["notebook"] = true
	w.unlocked["door_flag"] = true
	main.view.set_scene({"bg": "day", "customer": "xiaoding", "brother": true, "lamp": true})
	main.sidebar.refresh(w)
	main._refresh_cash_chip()
	main._hide_sidebar(true)
	main._clear_bottom_hint()
	main.dialogue.visible = false
	var dir := ProjectSettings.globalize_path("res://screenshots")
	DirAccess.make_dir_recursive_absolute(dir)
	await _snap(dir.path_join("v03b_clean_counter.png"))
	main._show_sidebar()
	main.sidebar.refresh(w)
	main._place_dialogue("xiaoding", false)
	main.dialogue.instant = true
	main.dialogue.show_line("小丁", "掌柜的，这袋米……能当几个钱？", Color("#d9c49a"), false, true, 1.0)
	await _snap(dir.path_join("v03b_panel_open.png"))
	DB.shutdown()
	quit(0)
