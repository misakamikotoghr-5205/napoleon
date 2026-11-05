# [shop-only] 「只守铺子」+ 保护费 的截图：门口吆喝的小窗、哥哥交代、胡二在柜台前等、四个选项、讲价、钱不够拿货抵、日结里的保护费、第二天的告示、规矩页。
# 真实渲染（需要 Xvfb，不能 --headless）：
# xvfb-run -a -s "-screen 0 1280x720x24" $GODOT --rendering-driver opengl3 --audio-driver Dummy --path . -s res://scripts/tests/shot_shop.gd -- --out=/绝对路径 [--seed=N]
# 输出：shop_01_door … shop_11_rules
extends SceneTree

const Common = preload("res://scripts/tests/town_ui_common.gd")
const ShopOnly = preload("res://scripts/town/shop_only.gd")

var out_dir: String = ""
var seed_v: int = 5
var c
var main
var town
var n_shot: int = 0

func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out_dir = a.substr(6)
		elif a.begins_with("--seed="):
			seed_v = int(a.substr(7))
	if out_dir == "":
		out_dir = ProjectSettings.globalize_path("res://screenshots")
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run()

func _shot(name: String) -> void:
	for i in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	n_shot += 1
	var path := out_dir.path_join("shop_%02d_%s.png" % [n_shot, name])
	root.get_viewport().get_texture().get_image().save_png(path)
	print("SHOT ", path)

func _manual(on: bool) -> void:
	var ap = c.ap
	if ap == null:
		return
	var d = town.director
	if on and d.beat.is_connected(ap._on_beat):
		d.beat.disconnect(ap._on_beat)
	elif not on and not d.beat.is_connected(ap._on_beat):
		d.beat.connect(ap._on_beat, CONNECT_DEFERRED)

func _protect_row() -> Dictionary:
	for id in town.visitors.present:
		var row: Dictionary = town.visitors.present[id]
		if str(row["visit"].get("intent", "")) == "protect":
			var w = row.get("walker", null)
			if w != null and is_instance_valid(w) and not w.is_walking():
				return row["visit"]
	return {}

func _panel_up(name: String) -> bool:
	for m in town.modal_layer.get_children():
		if m.get_script() != null and str(m.get_script().resource_path).ends_with(name):
			return true
	return false

# 演一幕：menu 依次选；haggle 是议价怎么回；shots 是事件 → 截图名（first_say / choice / counter / after_counter / goods）
func _scene(visit: Dictionary, menu: Array, haggle: String, shots: Dictionary) -> void:
	_manual(true)
	town.start_counter(visit)
	var last_cur = null
	var says := 0
	var menus := 0
	var after_counter := false
	var counters := 0
	var done := {}
	var guard := 0
	while guard < 6000 and town.mode == "counter":
		guard += 1
		await process_frame
		var t: String = main.cur_type
		if t == "" or main.cur == last_cur:
			continue
		last_cur = main.cur
		match t:
			"say", "narr":
				says += 1
				var txt := str(main.cur.get("text", ""))
				await c.frames(6)
				if says == 1 and shots.has("first_say") and not done.has("first_say"):
					done["first_say"] = true
					await _shot(str(shots["first_say"]))
				elif after_counter and shots.has("after_counter") and not done.has("after_counter"):
					done["after_counter"] = true
					await _shot(str(shots["after_counter"]))
				elif txt.contains("货架上") and shots.has("goods") and not done.has("goods"):
					done["goods"] = true
					await _shot(str(shots["goods"]))
				main._on_dialogue_advanced()
			"choice":
				await c.frames(6)
				if shots.has("choice") and not done.has("choice"):
					done["choice"] = true
					await _shot(str(shots["choice"]))
				var ids: Array = []
				for o in main.cur.get("options", []):
					ids.append(str(o["id"]))
				var pick: String = str(menu[mini(menus, menu.size() - 1)])
				menus += 1
				main._respond({"id": pick if ids.has(pick) else ids[0]})
			"counter":
				await c.frames(8)
				var s = main.cur["session"]
				if shots.has("counter") and not done.has("counter"):
					done["counter"] = true
					await _shot(str(shots["counter"]))
				after_counter = true
				counters += 1
				match haggle:
					"mid":      # 头一回出个中间价；他回了价就接他的回价
						var fl: int = int(town.director.protect().entry().get("floor", s.ask))
						var amt: int = int(town.director.protect().entry().get("amount", s.ask))
						var v: int = fl + int(ceil(float(amt - fl) * 0.5)) if counters == 1 else s.ask
						main._respond({"action": "offer", "value": mini(v, town.world.cash())})
					"floor": main._respond({"action": "offer", "value": mini(int(town.director.protect().entry().get("floor", s.ask)), town.world.cash())})
					"ask": main._respond({"action": "offer", "value": mini(s.ask, town.world.cash())})
					_: main._respond({"action": "refuse"})
			_:
				main._respond({})
	_manual(false)
	await c.until_idle()

func _brother() -> void:
	await c.until(func(): return not town.visitors.next_ready().is_empty(), 1800)
	var v: Dictionary = town.visitors.next_ready()
	_manual(true)
	town.start_counter(v)
	var last_cur = null
	var says := 0
	var guard := 0
	while guard < 4000 and town.mode == "counter":
		guard += 1
		await process_frame
		var t: String = main.cur_type
		if t == "" or main.cur == last_cur:
			continue
		last_cur = main.cur
		if t in ["say", "narr"]:
			says += 1
			if str(main.cur.get("text", "")).contains("保护费") and says > 3:
				await c.frames(6)
				await _shot("brother_explains")
			main._on_dialogue_advanced()
		else:
			main._respond({})
	_manual(false)
	await c.until_idle()

func _sleep_to_next() -> void:
	town.skip_to(1100)
	await town.goto("bed")
	town.sleep()

func _run() -> void:
	c = Common.new(self)
	c.shop_only = true
	await c.boot(seed_v, false, true)          # 非快钟：真实的淡入淡出和走路
	main = c.main
	town = c.town
	town.seconds_per_minute = 100000.0
	town.auto_dismiss = false
	await c.frames(10)
	town.dismiss_modals()
	await c.until_idle()
	town.auto_dismiss = true
	# 1. 门口（v0.4.2：按 E 是门口吆喝的小窗）
	var door: Dictionary = town.world_view.map.door_to_map("town")
	town.player.teleport(door["front"])
	await c.frames(4)
	town.interact()
	await c.frames(8)
	await _shot("door")
	town.dismiss_modals()
	town.overlay.end_speech()
	await town.goto("counter")
	# 2. 哥哥交代
	await _brother()
	# 3. 胡二来了，站在柜台前
	var pr = town.director.protect()
	town.skip_to(int(pr.entry()["minute"]))
	await c.until(func(): return not _protect_row().is_empty(), 3000)
	# 主角本来就站在柜台后；站定超过半秒游戏会自己开始接待，所以马上拍、马上演
	await _shot("collector_waiting")
	# 4. 四个选项 + 讲价
	await _scene(_protect_row(), ["haggle"], "mid", {"first_say": "collector_says", "choice": "choice", "counter": "haggle", "after_counter": "haggle_reply"})
	await c.frames(10)
	# 5. 睡觉：日结（带保护费一行）→ 第二天的告示（提了维持会的人今天要来）
	town.auto_dismiss = false
	_sleep_to_next()
	await c.until(func(): return _panel_up("summary_panel.gd"), 3000)
	await c.frames(30)
	await _shot("summary")
	town.dismiss_modals()
	await c.until(func(): return _panel_up("notice_panel.gd") and town.world.day == 2, 3000)
	await c.frames(40)
	await _shot("notice_day2")
	town.dismiss_modals()
	await c.until_idle()
	town.auto_dismiss = true
	# 6. 第二天：钱不够，拿货抵
	var drain: int = town.world.cash() - 3
	town.world.ledger.transfer("player", "市场", drain, "（截图）花光")
	town.skip_to(int(pr.entry()["minute"]))
	await c.until(func(): return not _protect_row().is_empty(), 3000)
	await _scene(_protect_row(), ["pay"], "back", {"goods": "goods_taken"})
	# 7. 规矩页
	town.open_panel("notebook")
	await c.frames(4)
	main.book._set_tab("规矩")
	var ids: Array = main.book.Rules.page_ids(town.world, true) if main.book.get("Rules") != null else []
	var all_ids: Array = []
	for id in town.world.pages:
		if id == "rule_protect" or id in ["rule_pawn", "rule_counter", "rule_inspect", "rule_sell", "rule_save", "rule_leave", "rule_levy", "rule_home", "rule_stamina", "rule_shops"]:
			all_ids.append(id)
	var idx := all_ids.find("rule_protect")
	main.book.page_idx = maxi(0, idx)
	main.book._render()
	await c.frames(6)
	await _shot("rules_page")
	main.book._close()
	print("DONE shots=", n_shot)
	await c.shutdown()
	quit(0)
