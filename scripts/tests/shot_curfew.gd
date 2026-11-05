# 宵禁截图集（需要 Xvfb，真实渲染）：告示、哥哥的话、夜里的红牌、被拦下的一幕与选项、罚洋、押回、第二天的告示、知识页。
# xvfb-run -a -s "-screen 0 1280x720x24" $GODOT --rendering-driver opengl3 --audio-driver Dummy --path . -s res://scripts/tests/shot_curfew.gd -- --out=/绝对路径 [--seed=N]
extends SceneTree

const Common = preload("res://scripts/tests/town_ui_common.gd")
const R = preload("res://scripts/sim/jev_rng.gd")
const Costs = preload("res://scripts/sim/living_costs.gd")

var out_dir: String = ""
var seed_v: int = 5
var c
var town
var main
var n: int = 0

func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out_dir = a.substr(6)
		elif a.begins_with("--seed="):
			seed_v = int(a.substr(7))
	if out_dir == "":
		out_dir = ProjectSettings.globalize_path("res://screenshots/curfew")
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run()

func _frames(k: int) -> void:
	for i in k:
		await process_frame

func _shot(label: String) -> void:
	town.overlay.clear_toasts()          # 快进时攒下的“某某等不及走了”不要入镜
	await _frames(4)
	await RenderingServer.frame_post_draw
	n += 1
	var path := out_dir.path_join("c%02d_%s.png" % [n, label])
	root.get_viewport().get_texture().get_image().save_png(path)
	print("SHOT ", path)

func _ap_on(on: bool) -> void:
	var cb := Callable(c.ap, "_on_beat")
	var linked: bool = town.director.beat.is_connected(cb)
	if on and not linked:
		town.director.beat.connect(cb, CONNECT_DEFERRED)
	elif not on and linked:
		town.director.beat.disconnect(cb)

# 等到对白框上出现含 fragment 的一拍（或 choice），截图后点掉。返回这一拍
func _beat_shot(label: String, fragment: String, kind: String = "") -> Dictionary:
	var guard := 0
	while guard < 1500:
		guard += 1
		await process_frame
		var cur: Dictionary = main.cur
		if cur.is_empty():
			continue
		var t := str(cur.get("type", ""))
		if kind != "" and t != kind:
			_answer(cur)
			continue
		if fragment == "" or str(cur.get("text", "")).find(fragment) >= 0:
			await _shot(label)
			var keep := cur
			return keep
		_answer(cur)
	print("没等到：", label, " ", fragment)
	return {}

func _answer(cur: Dictionary, pick: String = "honest") -> void:
	match str(cur.get("type", "")):
		"choice":
			var ids: Array = []
			for o in cur.get("options", []):
				ids.append(str(o["id"]))
			main._respond({"id": pick if ids.has(pick) else str(ids[0])})
		"say", "narr":
			main._on_dialogue_advanced()
		_:
			main._respond({})

func _pin() -> void:
	var day: int = town.world.day
	var seed_n: int = int(town.world.town.s["seed"])
	var st: Dictionary = town.curfew.state()
	var cur: int = int(st["trips"].get(str(day), 0))
	for k in range(cur, cur + 600):
		if R.draw(seed_n, "curfew_trip", [day, k]) < 0.04:
			st["trips"][str(day)] = k
			return

func _run() -> void:
	c = Common.new(self)
	await c.boot(seed_v, true, true)
	town = c.town
	main = c.main
	town.seconds_per_minute = 100000.0
	main.dialogue.instant = true
	town.auto_dismiss = false            # 告示、日结留着给截图
	_ap_on(false)
	var st: Dictionary = town.curfew.state()
	await _frames(10)
	# ---- 1 告示墙
	town.skip_to(1000)
	town.show_board()
	await _frames(8)
	await _shot("notice_wall_posting")
	town.dismiss_modals()
	await _frames(4)
	# ---- 2 哥哥傍晚的话
	town.skip_to(1229)
	town.skip_to(1231)
	await _beat_shot("brother_tells_curfew", "九点以后别上街")
	var guard := 0
	while (town.curfew.busy or not main.cur.is_empty()) and guard < 600:
		guard += 1
		await process_frame
		if not main.cur.is_empty():
			_answer(main.cur)
	await _frames(6)
	# ---- 3 夜里的铺子：红牌
	town.skip_to(1262)
	await _frames(8)
	await _shot("night_pawnshop_curfew_badge")
	# ---- 4 被拦下：一次罚洋
	c.ap.choice_queue = []
	_give_pass()
	st["offences"] = 1
	_pin()
	town.curfew.check_trip("德厚当", "米行", 1275)
	await _beat_shot("stop_patrol_speaks", "站住")
	_answer(main.cur)
	await _beat_shot("stop_options", "", "choice")
	_answer(main.cur, "honest")
	await _beat_shot("stop_fine_paid", "罚洋")
	await _beat_shot("stop_fine_paid_narr", "数出")
	guard = 0
	while town.curfew.busy and guard < 800:
		guard += 1
		await process_frame
		if not main.cur.is_empty():
			_answer(main.cur)
	await _frames(6)
	# ---- 5 再被拦：押回
	st["quiet_until"] = 0
	st["offences"] = 2
	_pin()
	town.auto_dismiss = false
	town.curfew.check_trip("德厚当", "码头", 1400)
	await _beat_shot("stop_third_time", "三番两次")
	_answer(main.cur)
	await _beat_shot("stop_options_third", "", "choice")
	_answer(main.cur, "honest")
	await _beat_shot("detained_escorted_home", "押回德厚当门口")
	_ap_on(true)                           # 后面的夜间剧情交给自动试玩器
	_answer(main.cur)
	# ---- 6 第二天的告示
	guard = 0
	var shot_notice := false
	while guard < 4000 and not shot_notice:
		guard += 1
		await process_frame
		if town._open_modals.is_empty():
			continue
		if town.world.day == 1:
			town.dismiss_modals()                      # 日结
			continue
		if town.world.day == 2:
			await _frames(8)
			await _shot("next_morning_notice_after_detention")
			shot_notice = true
	town.dismiss_modals()
	await _frames(6)
	# ---- 7 知识页
	_ap_on(false)
	main.book.open("notebook", town.world)
	main.book._set_tab("知识")
	var idx: int = town.world.pages.find("curfew")
	main.book.page_idx = maxi(0, idx)
	main.book._render()
	await _frames(6)
	await _shot("notebook_knowledge_page")
	print("DONE shots=", n)
	quit(0)

func _give_pass() -> void:
	var spec := {"id": "certificate", "label": "良民证", "amount": 6, "min": 6, "max": 6, "payee": "维持会公账", "building": "baogong", "due_days": 0}
	Costs.add(town.world.town.pack, town.world.town.s, spec, "shot", "bill:certificate:once", town.world)
	town.world.town.pay_bill("bill:certificate:once", 6, "shot|cert")
