# 前期引导截图：第一天早晨（告示 + 按键条 + 柜台发光 + 哥哥气泡）、第一位客人、放大镜、米行门口、操作说明、规矩页。
# 真实渲染，需要 Xvfb：
# xvfb-run -a -s "-screen 0 1280x720x24" $GODOT --rendering-driver opengl3 --audio-driver Dummy --path . -s res://scripts/tests/shot_onboard.gd -- --out=/绝对路径
extends SceneTree

const ShopOnly = preload("res://scripts/town/shop_only.gd")      # [shop-only] 这些截图要走到街上去：关掉守铺
const Autoplayer = preload("res://scripts/tests/autoplayer.gd")
const HelpPanel = preload("res://scripts/town/help_panel.gd")

var out_dir: String = ""
var main
var town
var ap
var n: int = 0
var counter_seen: bool = false

func _initialize() -> void:
	ShopOnly.set_override(0)      # [shop-only]
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out_dir = a.substr(6)
	if out_dir == "":
		out_dir = ProjectSettings.globalize_path("res://screenshots/onboarding")
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run()

func _frames(k: int) -> void:
	for i in k:
		await process_frame

func _shot(label: String) -> void:
	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	n += 1
	var path := out_dir.path_join("o%02d_%s.png" % [n, label])
	root.get_viewport().get_texture().get_image().save_png(path)
	print("SHOT ", path)

func _until(cond: Callable, max_frames: int = 900) -> bool:
	var k := 0
	while not cond.call() and k < max_frames:
		k += 1
		await process_frame
	return cond.call()

func _guide_on(id: String) -> bool:
	return str(town.guide.active.get("id", "")) == id and town.guide._alpha > 0.97

func _key(code: int) -> void:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.physical_keycode = code
	ev.pressed = true
	Input.parse_input_event(ev)
	await process_frame
	var up := InputEventKey.new()
	up.keycode = code
	up.physical_keycode = code
	up.pressed = false
	Input.parse_input_event(up)
	await process_frame

func _hold_counter(b: Dictionary) -> void:
	if str(b.get("type", "")) == "counter" and not counter_seen:
		counter_seen = true
		ap.step_delay = 60.0

func _on_director(d) -> void:
	ap = Autoplayer.new(d, "town_fair", 1)
	ap.ui = main
	ap.tree = self
	ap.step_delay = 0.0
	main.autoplayer = ap
	main.dialogue.instant = true

func _mark_done(ids: Array) -> void:
	for id in ids:
		town.guide.mark_done(str(id))

func _run() -> void:
	main = load("res://scenes/Main.tscn").instantiate()
	main.autostart = false
	root.add_child(main)
	await process_frame
	main.settings.path = "user://shot_onboard_settings.json"
	main._ensure_town()
	town = main.town
	town.set_fast(true)
	town.autosave = false
	town.save_path = "user://shot_onboard_save.json"
	town.director_ready.connect(_on_director)
	town.new_game(11, "常年", true)
	await town.day_started
	town.seconds_per_minute = 100000.0
	# 1. 晨间告示：按 E 收起
	await _until(func(): return _guide_on("notice_close"), 200)
	await _shot("notice_press_e")
	await _key(KEY_E)
	await _frames(10)
	print("notice closed by E: ", town._modal_depth == 0)
	# 2. 第一天早晨：玩家离开柜台，哥哥进来等着 → 柜台发光 + 哥哥的气泡 + 底部按键条
	var map = town.world_view.map
	town.player.teleport(map.nearest_free(Vector2(240, 140)))
	await _until(func(): return _guide_on("brother_calls"), 600)
	await _frames(10)
	await _shot("day1_morning_brother_calls")
	# 3. 站回柜台，接哥哥的话（开场戏）
	town.player.teleport(map.counter_spot)
	await _until(func(): return town.mode == "counter", 600)
	await _until(func(): return town.mode == "town" and town.is_idle_in_town(), 3000)
	await _frames(20)
	# 4. 开场戏之后：走起来、按 E 看货架
	town.player.teleport(map.nearest_free(Vector2(150, 120)))
	await _frames(60)
	await _shot("day1_after_scene_strip")
	# 5. 九点，第一位客人到，玩家不在柜台
	town.skip_to(545)
	await _until(func(): return not town.visitors.next_ready().is_empty(), 900)
	await _frames(30)
	_mark_done(["move_keys", "interact_e", "esc_menu", "hud_buttons", "rule_pawn", "rule_sell_brother", "go_counter"])
	await _until(func(): return _guide_on("customer_arrives"), 900)
	await _shot("first_customer_prompt")
	# 6. 柜台里：点放大镜
	town.director.beat.connect(_hold_counter)
	var visit: Dictionary = town.visitors.next_ready()
	town.player.teleport(map.counter_spot)
	town.start_counter(visit)
	await _until(func(): return counter_seen, 1200)
	await _until(func(): return _guide_on("appraise"), 600)
	await _frames(10)
	await _shot("counter_appraise")
	ap.step_delay = 0.0
	await _until(func(): return town.mode == "town", 3000)
	await _until(func(): return town.is_idle_in_town(), 600)
	# 7. 店铺特写：第一次进米行，一行字说这里能办什么
	_mark_done(["customer_arrives"])
	town.overlay.clear_toasts()
	town.open_shop("pharmacy")                       # 第一天济生堂还没开门：门缝里夹着字条
	await _frames(6)
	await _shot("locked_pharmacy_text")
	town.overlay.clear_toasts()
	await town.open_shop("ricehall")
	await _until(func(): return _guide_on("shop_ricehall"), 600)
	await _frames(10)
	await _shot("ricehall_closeup_first_visit")
	town.shop_view.close_shop()
	await _until(func(): return town.mode == "town", 600)
	await _frames(10)
	# 8. 米缸快空了：当铺里指向出门
	town.guide.mark_done("shop_ricehall")
	town.guide.state()["seen"].erase("left_shop")
	town.day_number = 2          # 截图用：米缸提示从第二天起
	town.director.vars["town"]["household"]["rice"] = 2
	town._refresh_home()
	await town.goto("inside")
	await _until(func(): return _guide_on("rice_low_exit"), 900)
	await _frames(10)
	await _shot("rice_low_exit")
	# 8b. “去哪儿”地图（示意：真正的地图由别处做，这里只是一块板子，演示 travel_map 锚点的发光）
	town.guide.on_travel_opened()
	await _until(func(): return town.guide.active.is_empty(), 600)
	var mock := PanelContainer.new()
	mock.add_theme_stylebox_override("panel", UiStyle.box(Color("#ecd9a6"), Color("#3a2a1e"), 4, 3, 14))
	mock.position = Vector2(300, 150)
	mock.custom_minimum_size = Vector2(680, 420)
	mock.size = Vector2(680, 420)
	town.add_child(mock)
	var title := UiStyle.title_label("去哪儿（示意）", 34, UiStyle.INK)
	mock.add_child(title)
	var icon := ColorRect.new()
	icon.color = Color("#b0262a")
	icon.position = Vector2(300, 150)
	var rice_icon := Panel.new()
	rice_icon.position = Vector2(560, 330)
	rice_icon.size = Vector2(110, 80)
	rice_icon.add_theme_stylebox_override("panel", UiStyle.box(Color("#d9c49a"), Color("#7b5a3a"), 3, 3, 4))
	town.add_child(rice_icon)
	var rl := UiStyle.label("米行", 22, UiStyle.INK, false)
	rl.position = Vector2(590, 355)
	town.add_child(rl)
	town.guide.register_travel_anchor("_map", func() -> Rect2: return mock.get_global_rect())
	town.guide.register_travel_anchor("ricehall", func() -> Rect2: return rice_icon.get_global_rect())
	town.guide.set_ui_override("travel")
	town.guide.state()["seen"].erase("travel_chosen")
	town.guide.state()["done"].erase("travel_pick")
	town.guide._gap = 0.0
	await _until(func(): return _guide_on("travel_pick"), 600)
	await _frames(10)
	await _shot("travel_map_pick_mock")
	town.guide.on_travel_chosen("pharmacy")
	await _until(func(): return town.guide.active.is_empty(), 900)
	town.guide._gap = 0.0
	await _until(func(): return _guide_on("rice_low_travel"), 900)
	await _frames(10)
	await _shot("travel_map_rice_mock")
	town.guide.set_ui_override("")
	town.guide.unregister_travel_anchors()
	mock.queue_free()
	rice_icon.queue_free()
	rl.queue_free()
	town.guide.mark_done("rice_low_exit")
	# 9. 菜单、设置、操作说明、规矩
	town.guide.mark_done("rice_low_exit")
	town.open_pause()
	await _frames(8)
	await _shot("pause_menu_with_help")
	var menu = town.modal_layer.get_child(town.modal_layer.get_child_count() - 1)
	menu.help_btn.pressed.emit()
	await _frames(8)
	await _shot("help_panel_keys")
	var hp = HelpPanel.current
	hp._pick(1)
	await _frames(4)
	await _shot("help_panel_rules")
	town.dismiss_modals()
	await _frames(4)
	town.open_pause()
	await _frames(4)
	menu = town.modal_layer.get_child(town.modal_layer.get_child_count() - 1)
	menu.settings_btn.pressed.emit()
	await _frames(8)
	await _shot("settings_guide_toggle")
	town.dismiss_modals()
	await _frames(4)
	town.open_panel("notebook")
	await _frames(4)
	main.book._set_tab("规矩")
	await _frames(4)
	await _shot("notebook_rules_tab")
	main.book._close()
	await _frames(4)
	# 10. 关着的店
	town.skip_to(1300)
	town.overlay.clear_toasts()
	town.open_shop("teahouse")
	await _frames(6)
	await _shot("closed_teahouse_text")
	# 11. 标题
	town.save_game()
	main.args["save"] = town.save_path
	main._return_to_title()
	await _frames(8)
	await _shot("title_help_button")
	main.args.erase("save")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://shot_onboard_settings.json"))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://shot_onboard_save.json"))
	main.queue_free()
	await _frames(3)
	DB.shutdown()
	quit(0)
