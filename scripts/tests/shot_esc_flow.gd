# Esc 全局暂停与弹窗 E 关闭的截图：序章里的暂停菜单、柜台交易里的暂停菜单、夜里的暂停菜单、告示（按钮标 E）。真实渲染（需要 Xvfb）。
# xvfb-run -a -s "-screen 0 1280x720x24" $GODOT --rendering-driver opengl3 --audio-driver Dummy --path . -s res://scripts/tests/shot_esc_flow.gd -- --out=/绝对路径
# 输出：esc_01_prologue … esc_06_notice
extends SceneTree

const Common = preload("res://scripts/tests/town_ui_common.gd")
const TownGame = preload("res://scripts/town/town_game.gd")

var out_dir: String = ""
var main
var town

func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out_dir = a.substr(6)
	if out_dir == "":
		out_dir = ProjectSettings.globalize_path("res://screenshots")
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run()

func _shot(label: String) -> void:
	for i in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	var path := out_dir.path_join("%s.png" % label)
	root.get_viewport().get_texture().get_image().save_png(path)
	print("SHOT ", path)

func _key(code: int) -> void:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.physical_keycode = code
	ev.pressed = true
	root.push_input(ev)
	await process_frame

func _until(cond: Callable, max_frames: int = 1800) -> bool:
	var n := 0
	while not cond.call() and n < max_frames:
		n += 1
		await process_frame
	return cond.call()

func _run() -> void:
	# --- 序章 ---
	main = load("res://scenes/Main.tscn").instantiate()
	main.autostart = false
	root.add_child(main)
	await process_frame
	main._ensure_town()
	town = main.town
	town.autosave = false
	town.save_path = TownGame.scratch_save_path("shot_esc")
	town.new_game(5, "常年", false)
	await _until(func(): return main.cur_type != "", 600)
	var guard := 0
	while main.cur_type == "caption" and guard < 12:
		guard += 1
		await _key(KEY_SPACE)
		await process_frame
	await _until(func(): return main.cur_type in ["say", "narr"], 600)
	main.dialogue.finish_typing()
	for i in 20:
		await process_frame
	await _shot("esc_01_prologue_before")
	await _key(KEY_ESCAPE)
	await _shot("esc_02_prologue_pause")
	await _key(KEY_ESCAPE)
	await get_root().get_tree().process_frame
	# 退回标题，换一局（跳过序章）看柜台交易和夜里
	await _key(KEY_ESCAPE)
	var menu = null
	for m in town.modal_layer.get_children():
		if m.get_script() != null and str(m.get_script().resource_path).ends_with("pause_menu.gd"):
			menu = m
	menu.title_btn.pressed.emit()
	var buttons: Array = []
	_collect(menu, buttons)
	for b in buttons:
		if (b as Button).text == "确定":
			(b as Button).pressed.emit()
	for i in 6:
		await process_frame
	main.queue_free()
	await process_frame
	var c = Common.new(self)
	await c.boot(13, false, false)
	main = c.main
	town = c.town
	town.seconds_per_minute = 100000.0
	town.skip_to(1090)
	await c.until(func(): return not town.visitors.present.is_empty(), 900)
	var visit: Dictionary = {}
	for id in town.visitors.present:
		if str(id).begins_with("visit_d1"):
			visit = town.visitors.present[id]["visit"]
	town.start_counter(visit)
	await _until(func(): return main.cur_type != "" and town.mode == "counter", 600)
	var n := 0
	main.dialogue.instant = true
	while main.cur_type != "counter" and n < 60 and main.cur_type != "":
		n += 1
		await _key(KEY_SPACE)
		await process_frame
	await _shot("esc_03_counter_before")
	await _key(KEY_ESCAPE)
	await _shot("esc_04_counter_pause")
	await _key(KEY_ESCAPE)
	# 议价里翻开账簿，Esc 先关册子
	main.book.open("ledger", town.world)
	await process_frame
	await _shot("esc_05_counter_book")
	await _key(KEY_ESCAPE)
	await _shot("esc_05b_counter_book_closed_by_esc")
	await _key(KEY_ESCAPE)
	await _key(KEY_ESCAPE)
	await c.shutdown()
	# --- 晨间告示：按钮标着 E，按 E 关 ---
	var c3 = Common.new(self)
	await c3.make_main()
	main = c3.main
	town = c3.town
	town.set_fast(false)
	town.new_game(21, "常年", true)
	await _until(func(): return town._modal_depth > 0, 900)
	for i in 20:
		await process_frame
	await _shot("esc_06_notice_with_E_button")
	await _key(KEY_E)
	for i in 10:
		await process_frame
	print("NOTICE closed by E: modal_depth=", town._modal_depth, " mode=", town.mode)
	await _shot("esc_07_notice_closed_by_E")
	# 暂停菜单（街上）
	await _until(func(): return town.is_idle_in_town(), 600)
	await _key(KEY_ESCAPE)
	await _shot("esc_08_town_pause")
	await _key(KEY_ESCAPE)
	await c3.shutdown()
	quit(0)

func _collect(node: Node, out: Array) -> void:
	for ch in node.get_children():
		if ch is Button:
			out.append(ch)
		_collect(ch, out)
