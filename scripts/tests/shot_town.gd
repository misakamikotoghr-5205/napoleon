# v0.4 小镇截图：真实渲染（需要 Xvfb，不能 --headless）。
# xvfb-run -a -s "-screen 0 1280x720x24" $GODOT --rendering-driver opengl3 --audio-driver Dummy --path . -s res://scripts/tests/shot_town.gd -- --out=/绝对路径 [--seed=N] [--only=a,b]
# 输出：v04_morning_notice / v04_town_day / v04_shop_ricehall / v04_town_dusk / v04_pawnshop_customer / v04_counter
#       v04_pause_menu / v04_settings / v04_title
extends SceneTree

const ShopOnly = preload("res://scripts/town/shop_only.gd")      # [shop-only] 这些截图要走到街上去：关掉守铺
const Autoplayer = preload("res://scripts/tests/autoplayer.gd")

var out_dir: String = ""
var seed_v: int = 11
var only: Array = []
var main
var town
var ap
var counter_seen: bool = false

func _initialize() -> void:
	ShopOnly.set_override(0)      # [shop-only]
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out_dir = a.substr(6)
		elif a.begins_with("--seed="):
			seed_v = int(a.substr(7))
		elif a.begins_with("--only="):
			only = a.substr(7).split(",")
	if out_dir == "":
		out_dir = ProjectSettings.globalize_path("res://screenshots")
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run()

func _want(key: String) -> bool:
	return only.is_empty() or only.has(key)

func _shot(name: String) -> void:
	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_viewport().get_texture().get_image()
	var path := out_dir.path_join("v04_%s.png" % name)
	img.save_png(path)
	print("SHOT ", path)

func _frames(n: int) -> void:
	for i in n:
		await process_frame

func _idle() -> void:
	var guard := 0
	while not town.is_idle_in_town() and guard < 600:
		guard += 1
		await process_frame

func _run() -> void:
	main = load("res://scenes/Main.tscn").instantiate()
	main.autostart = false
	root.add_child(main)
	await process_frame
	main._ensure_town()
	town = main.town
	town.set_fast(true)
	town.autosave = false
	town.save_path = "user://shot_town_save.json"
	town.director_ready.connect(_on_director)
	town.new_game(seed_v)            # 不等：序章要由 autoplayer 推完
	await town.day_started
	town.seconds_per_minute = 100000.0   # 冻住自然走钟，时间由 skip_to 控制
	await _frames(6)
	if _want("morning_notice"):
		await _shot("morning_notice")
	town.dismiss_modals()
	await _idle()
	# 当铺里：小丁九点来当（客人走进来，站在柜台前等）
	if _want("pawnshop_customer") or _want("counter"):
		town.skip_to(545)
		var waited := 0
		while waited < 600 and not town.visitors.next_ready().is_empty() == false:
			waited += 1
			await process_frame
		await _frames(30)
		if _want("pawnshop_customer"):
			await _shot("pawnshop_customer")
	# 柜台：主角站到柜台后接待，停在议价这一拍
	if _want("counter"):
		town.director.beat.connect(_hold_counter)
		var visit: Dictionary = town.visitors.next_ready()
		await town.goto("counter")
		town.start_counter(visit)
		var guard := 0
		while not counter_seen and guard < 1200:
			guard += 1
			await process_frame
		await _frames(8)
		await _shot("counter")
		ap.step_delay = 0.0
		var g2 := 0
		while town.mode == "counter" and g2 < 3000:
			g2 += 1
			await process_frame
		await _idle()
	if _want("town_day"):
		town.skip_to(630)
		await town.goto("teahouse")
		await town.goto("ricehall")
		await _frames(30)
		await _shot("town_day")
	if _want("shop_ricehall"):
		await town.goto("ricehall")
		await town.enter_door("ricehall")
		await _frames(12)
		await _shot("shop_ricehall")
		town.shop_view.close_shop()
		await _idle()
	if _want("town_dusk"):
		town.skip_to(1165)
		await town.goto("pawnshop")
		town.crowd.rebuild()
		await _frames(30)
		await _shot("town_dusk")
	if _want("pause_menu") or _want("settings") or _want("title"):
		await town.goto("ricehall")
		town.skip_to(630)
		await _frames(10)
		town.open_pause()
		await _frames(6)
		if _want("pause_menu"):
			await _shot("pause_menu")
		if _want("settings"):
			town.dismiss_modals()
			await _frames(3)
			main.settings.path = "user://shot_town_settings.json"
			town.open_pause()
			await _frames(3)
			var menu = town.modal_layer.get_child(town.modal_layer.get_child_count() - 1)
			menu.settings_btn.pressed.emit()
			await _frames(6)
			await _shot("settings")
		town.dismiss_modals()
		await _frames(3)
		if _want("title"):
			town.save_game()
			main.args["save"] = town.save_path
			main._return_to_title()
			await _frames(8)
			await _shot("title")
			main.args.erase("save")
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://shot_town_settings.json"))
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://shot_town_save.json"))
	if main.town != null:
		town.dismiss_modals()
	main.queue_free()
	await _frames(3)
	DB.shutdown()
	quit(0)

func _hold_counter(b: Dictionary) -> void:
	if str(b.get("type", "")) == "counter" and not counter_seen:
		counter_seen = true
		ap.step_delay = 6.0

func _on_director(d) -> void:
	ap = Autoplayer.new(d, "town_fair", 1)
	ap.ui = main
	ap.tree = self
	ap.step_delay = 0.0
	main.autoplayer = ap
	main.dialogue.instant = true
