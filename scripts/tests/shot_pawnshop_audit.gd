# 当铺内部交互审计截图：在每个可交互点站定，截下提示条与画面；再截柜台碰撞（穿不过去）、客人在前主角在后。
# 真实渲染（需要 Xvfb，不能 --headless）：
# xvfb-run -a -s "-screen 0 1280x720x24" $GODOT --rendering-driver opengl3 --audio-driver Dummy --path . -s res://scripts/tests/shot_pawnshop_audit.gd -- --out=/绝对路径 [--seed=N] [--only=a,b]
# 每张图的文件名里是站的位置；同时在标准输出打印“站在哪、提示是什么、提示条的屏幕位置”。
extends SceneTree

const Common = preload("res://scripts/tests/town_ui_common.gd")

var out_dir: String = ""
var seed_v: int = 13
var only: Array = []
var c
var town

func _initialize() -> void:
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

func _shot(label: String) -> void:
	for i in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	var path := out_dir.path_join("%s.png" % label)
	root.get_viewport().get_texture().get_image().save_png(path)

# 站到 p，等几帧让提示刷新，打印并截图
func _at(label: String, p: Vector2, facing: int = 3) -> void:
	town.player.teleport(p)
	town.player.body.facing = facing
	await c.frames(4)
	var near: Dictionary = town._find_near()
	var rect: Rect2 = town.overlay.prompt_rect()
	print("AT %-26s pos=%s prompt=[%s] id=%s anchor=%s prompt_rect=%s" % [label, str(p), str(near.get("label", "")), str(near.get("id", "")), str(near.get("anchor", "")), str(rect)])
	await _shot(label)

func main_cur_type() -> String:
	return str(town.main.cur_type)

func _run() -> void:
	c = Common.new(self)
	await c.boot(seed_v, false, false)
	town = c.town
	town.seconds_per_minute = 100000.0
	town.auto_dismiss = false
	town.dismiss_modals()
	town.world.unlocked["telegraph"] = true          # 序章里陈叔叔教过了（测试跳过了序章）
	var map = town.world_view.map
	print("MAP ", map.id, " counter=", map.counter_spot, " customers=", map.customer_spots, " interacts=", map.interacts.keys())
	# ---------- 白天，没客人 ----------
	town.skip_to(420)
	await c.frames(3)
	town.visitors.clear_walkers()
	town.visitors.present.clear()
	if _want("aisle"):
		await _at("a01_bed_day", Vector2(58, 72))
		await _at("a02_shelf_mid", Vector2(110, 72))
		await _at("a03_counter_spot_empty", map.counter_spot)
		await _at("a04_lamp", Vector2(191, 72))
		await _at("a05_telegraph_day", Vector2(275, 72))
		await _at("a06_backdoor", Vector2(297, 72))
		await _at("a07_gate_lane", Vector2(248, 120), 0)
		await _at("a08_exit_door", Vector2(168, 176), 0)
		# 柜台后面的走道有好几行：贴着柜台那一行也有提示
		await _at("a09_lamp_row_front", Vector2(191, 83))
		await _at("a10_telegraph_row_front", Vector2(275, 83))
	# ---------- 站在两个交互点中间：没有来回跳 ----------
	if _want("jitter"):
		var names: Array = []
		for x in range(150, 214, 2):
			town.player.teleport(Vector2(x, 72))
			await c.frames(1)
			names.append("%d:%s" % [x, str(town._find_near().get("id", "-"))])
		print("SWEEP lamp/counter region ", names)
	# ---------- 有客人 ----------
	if _want("customers"):
		town.skip_to(560)
		await c.until(func(): return not town.visitors.next_ready().is_empty(), 1800)
		await c.until(func(): return town.visitors.count() >= 2, 1800)
		await c.frames(30)
		await _at("b01_counter_with_customers", map.counter_spot)
		var first_visit: Dictionary = town.visitors.next_ready()
		var wk = town.visitors.walker_of(str(first_visit.get("id", "")))
		if wk != null:
			await _at("b02_front_of_customer", map.nearest_free(wk.position + Vector2(0, 16)), 3)
		await _at("b03_gate_lane_with_customers", Vector2(248, 140), 3)
		await _at("b05_exit_cell_with_customers", Vector2(168, 176), 0)
	# ---------- 出门再进门、进店铺特写再回来：客人还站在那儿，招呼得到 ----------
	if _want("revisit"):
		town.player.teleport(Vector2(110, 72))
		await c.frames(3)
		for round_no in [1, 2]:
			await town.enter_door("town")
			town.skip_to(town.minute + 3)
			await c.frames(6)
			await _shot("e%d0_street_between" % round_no)
			await town.enter_door("pawnshop")
			await c.frames(40)
			var near_r: Dictionary = town._find_near()
			print("REVISIT round %d via street door: map=%s customers=%d prompt=[%s] id=%s" % [round_no, town.map_id, town.visitors.count(), str(near_r.get("label", "")), str(near_r.get("id", ""))])
			await _shot("e%d1_back_through_door" % round_no)
			await town.open_shop("ricehall")
			town.skip_to(town.minute + 20)
			await c.frames(20)
			await _shot("e%d2_closeup_while_customers_wait" % round_no)
			town.shop_view.close_shop()
			await c.until(func(): return town.mode == "town" and not town._transitioning, 600)
			await c.frames(40)
			var near_c: Dictionary = town._find_near()
			print("REVISIT round %d back from closeup: map=%s customers=%d prompt=[%s] id=%s" % [round_no, town.map_id, town.visitors.count(), str(near_c.get("label", "")), str(near_c.get("id", ""))])
			await _shot("e%d3_back_from_closeup" % round_no)
		# 站到每一位客人身边都招呼得到
		var n_ok := 0
		var n_all := 0
		for id in town.visitors.present:
			n_all += 1
			var wk2 = town.visitors.walker_of(str(id))
			if wk2 == null:
				continue
			town.player.teleport(map.nearest_free(wk2.position + Vector2(0, 14)))
			await c.frames(3)
			var nr: Dictionary = town._find_near()
			if str(nr.get("id", "")) == "customer":
				n_ok += 1
				if n_ok == 1:
					await _shot("e40_greet_first_customer_after_revisits")
		print("REVISIT every waiting customer greetable: %d/%d" % [n_ok, n_all])
		town.player.teleport(map.counter_spot)
		await c.frames(3)
		await _shot("e50_counter_spot_after_revisits")
	# ---------- 穿模：往柜台里走 ----------
	if _want("block"):
		town.player.teleport(Vector2(70, 150))
		town.player.use_external = true
		town.player.external_input = Vector2(0, -1)
		await c.frames(90)
		var stuck: Vector2 = town.player.position
		print("WALK_INTO_COUNTER from (70,150) pushing up for 90 frames -> ", stuck, " (counter body starts at y=100, foot box must stay >= 146)")
		await _shot("c01_blocked_by_counter")
		town.player.teleport(Vector2(200, 150))
		await c.frames(90)
		print("WALK_INTO_COUNTER from (200,150) -> ", town.player.position)
		town.player.teleport(Vector2(248, 150))
		town.player.external_input = Vector2(0, -1)
		await c.frames(120)
		print("WALK_THROUGH_GATE from (248,150) pushing up -> ", town.player.position, " (should end behind the counter, y<=80)")
		await _shot("c02_through_the_gate")
		town.player.use_external = false
		town.player.external_input = Vector2.ZERO
	# ---------- 夜里 ----------
	if _want("night"):
		town.skip_to(1300)
		await c.frames(3)
		await _at("d01_telegraph_night_day1", Vector2(275, 72))
		await _at("d02_bed_night", Vector2(58, 72))
		town.world.day = 3
		await _at("d03_telegraph_night_day3", Vector2(275, 72))
	# ---------- 真窗口里点客人（无头测试没有真窗口，点击路由在这里验） ----------
	if _want("click"):
		var click_visit: Dictionary = town.visitors.next_ready()
		var cw = town.visitors.walker_of(str(click_visit.get("id", "")))
		if cw != null:
			town.player.teleport(Vector2(130, 160))
			await c.frames(4)
			var click_pos: Vector2 = town.world_view.world_to_screen(cw.position + Vector2(0, -14))
			var started_before: int = town.counter_started
			var evd := InputEventMouseButton.new()
			evd.button_index = MOUSE_BUTTON_LEFT
			evd.pressed = true
			evd.position = click_pos
			evd.global_position = click_pos
			root.push_input(evd)
			for i in 6:
				await process_frame
			print("CLICK on customer at screen ", click_pos, " -> counter_started ", started_before, " -> ", town.counter_started, " mode=", town.mode)
			await _shot("b04_after_click_customer")
	await c.shutdown()
	quit(0)
