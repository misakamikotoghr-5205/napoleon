# v0.4 截图集（说明文档用）：真实渲染，需要 Xvfb。
# xvfb-run -a -s "-screen 0 1280x720x24" $GODOT --rendering-driver opengl3 --audio-driver Dummy --path . -s res://scripts/tests/shot_gallery.gd -- --out=/绝对路径 [--seed=N]
extends SceneTree

const ShopOnly = preload("res://scripts/town/shop_only.gd")      # [shop-only] 这些截图要走到街上去：关掉守铺
const Autoplayer = preload("res://scripts/tests/autoplayer.gd")

var out_dir: String = ""
var seed_v: int = 11
var main
var town
var ap
var counter_seen: bool = false
var n: int = 0

func _initialize() -> void:
	ShopOnly.set_override(0)      # [shop-only]
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out_dir = a.substr(6)
		elif a.begins_with("--seed="):
			seed_v = int(a.substr(7))
	if out_dir == "":
		out_dir = ProjectSettings.globalize_path("res://screenshots/gallery")
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run()

func _shot(label: String) -> void:
	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	n += 1
	var path := out_dir.path_join("g%02d_%s.png" % [n, label])
	root.get_viewport().get_texture().get_image().save_png(path)
	print("SHOT ", path)

func _frames(k: int) -> void:
	for i in k:
		await process_frame

func _idle() -> void:
	var guard := 0
	while not town.is_idle_in_town() and guard < 600:
		guard += 1
		await process_frame

func _closeup(bid: String) -> void:
	# 截图用：不管今天开没开门，直接打开这家店的特写
	town._set_mode("closeup")
	town.shop_view.open(town, bid)
	town.refresh_hud()
	await _frames(20)
	await _shot("shop_" + bid)
	town.shop_view.visible = false
	town._set_mode("town")
	town.refresh_hud()
	await _frames(4)

func _panel(kind: String) -> void:
	town.open_panel(kind)
	await _frames(8)
	await _shot("panel_" + kind)
	town.dismiss_modals()
	if main.book != null and main.book.visible:
		main.book.visible = false
	main.generic_panel.visible = false
	await _frames(4)

func _run() -> void:
	main = load("res://scenes/Main.tscn").instantiate()
	main.autostart = false
	root.add_child(main)
	await process_frame
	main._ensure_town()
	town = main.town
	town.set_fast(true)
	town.autosave = false
	town.save_path = "user://shot_gallery_save.json"
	town.director_ready.connect(_on_director)
	town.new_game(seed_v)
	await town.day_started
	town.seconds_per_minute = 100000.0
	await _frames(6)
	await _shot("morning_notice")
	town.dismiss_modals()
	await _idle()
	await _panel("household")
	# 当铺里：客人进门，站在柜台前
	town.skip_to(545)
	var wait := 0
	while town.visitors.next_ready().is_empty() and wait < 900:
		wait += 1
		await process_frame
	await _frames(30)
	await _shot("pawnshop_customer")
	# 柜台交易
	town.director.beat.connect(_hold_counter)
	var visit: Dictionary = town.visitors.next_ready()
	if not visit.is_empty():
		await town.goto("counter")
		town.start_counter(visit)
		var guard := 0
		while not counter_seen and guard < 1200:
			guard += 1
			await process_frame
		await _frames(8)
		await _shot("counter_trade")
		ap.step_delay = 0.0
		var g2 := 0
		while town.mode == "counter" and g2 < 3000:
			g2 += 1
			await process_frame
		await _idle()
	await _panel("ledger")
	await _panel("notebook")
	await _panel("calendar")
	# 小镇白天
	town.skip_to(640)
	await town.goto("pawnshop")
	town.crowd.rebuild()
	await _frames(30)
	await _shot("town_pawnshop_front")
	for target in ["ricehall", "baogong", "post", "police", "market", "dock"]:
		await town.goto(target)
		town.crowd.rebuild()
		await _frames(30)
		await _shot("town_" + target)
	# 各店特写
	for bid in ["teahouse", "ricehall", "pharmacy", "baogong", "post", "market"]:
		await _closeup(bid)
	# 黄昏与夜
	town.skip_to(1170)
	await town.goto("teahouse")
	town.crowd.rebuild()
	await _frames(30)
	await _shot("town_dusk")
	town.skip_to(1300)
	await town.goto("pawnshop")
	town.crowd.rebuild()
	await _frames(30)
	await _shot("town_night")
	await town.goto("inside")
	await _frames(20)
	await _shot("pawnshop_night")
	# 菜单
	town.skip_to(640)
	await _frames(6)
	town.open_pause()
	await _frames(6)
	await _shot("pause_menu")
	town.dismiss_modals()
	await _frames(3)
	main.settings.path = "user://shot_gallery_settings.json"
	town.open_pause()
	await _frames(3)
	var menu = town.modal_layer.get_child(town.modal_layer.get_child_count() - 1)
	menu.settings_btn.pressed.emit()
	await _frames(6)
	await _shot("settings")
	town.dismiss_modals()
	await _frames(3)
	town.save_game()
	main.args["save"] = town.save_path
	main._return_to_title()
	await _frames(8)
	await _shot("title")
	main.args.erase("save")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://shot_gallery_settings.json"))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://shot_gallery_save.json"))
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
