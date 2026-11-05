# 小镇前端修补后的截图：睡觉换天后的晨间告示（不能黑屏）、日结、保公所议价（对白可见）。真实渲染（需要 Xvfb，不能 --headless）。
# xvfb-run -a -s "-screen 0 1280x720x24" $GODOT --rendering-driver opengl3 --audio-driver Dummy --path . -s res://scripts/tests/shot_town_flow.gd -- --out=/绝对路径 [--seed=N] [--only=a,b]
# 输出：v04f_day1_summary / v04f_day2_notice / v04f_baogong_offer / v04f_baogong_reply / v04f_baogong_done
extends SceneTree

const Common = preload("res://scripts/tests/town_ui_common.gd")
const TownGame = preload("res://scripts/town/town_game.gd")
const Costs = preload("res://scripts/sim/living_costs.gd")

var out_dir: String = ""
var seed_v: int = 12
var only: Array = []
var c
var main
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

func _shot(name: String) -> void:
	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_viewport().get_texture().get_image()
	var path := out_dir.path_join("v04f_%s.png" % name)
	img.save_png(path)
	# 顺手量一下画面是不是黑的：四个角和中间取样
	var lum := 0.0
	for p in [Vector2i(40, 40), Vector2i(640, 360), Vector2i(1200, 100), Vector2i(300, 600), Vector2i(900, 500)]:
		var col := img.get_pixelv(p)
		lum += (col.r + col.g + col.b) / 3.0
	print("SHOT ", path, "  mean luminance of 5 samples = %.3f" % (lum / 5.0))

func _summary_up() -> bool:
	for m in town.modal_layer.get_children():
		if m.get_script() != null and str(m.get_script().resource_path).ends_with("summary_panel.gd"):
			return true
	return false

func _notice_up() -> bool:
	for m in town.modal_layer.get_children():
		if m.get_script() != null and str(m.get_script().resource_path).ends_with("notice_panel.gd"):
			return true
	return false

func _run() -> void:
	c = Common.new(self)
	await c.boot(seed_v, false, true)          # 非快钟：真实的淡入淡出
	main = c.main
	town = c.town
	town.seconds_per_minute = 100000.0
	town.auto_dismiss = false
	await c.frames(10)
	town.dismiss_modals()
	await c.until_idle()
	if _want("day2_notice") or _want("day1_summary"):
		town.skip_to(1100)
		await town.goto("bed")
		town.sleep()
		await c.until(func(): return _summary_up(), 1800)
		await c.frames(20)
		if _want("day1_summary"):
			await _shot("day1_summary")
		town.dismiss_modals()
		await c.until(func(): return _notice_up() and town.world.day == 2, 1800)
		await c.frames(40)
		await _shot("day2_notice")
		town.dismiss_modals()
		await c.until_idle()
	if _want("baogong_offer") or _want("baogong_reply") or _want("baogong_done"):
		main.dialogue.instant = true
		if c.ap != null and town.director.beat.is_connected(c.ap._on_beat):
			town.director.beat.disconnect(c.ap._on_beat)      # 议价由本脚本自己回应，autoplayer 退场
		main.autoplayer = null
		town.world.town.s["unlocked"]["baogong"] = true
		var spec := {"id": "levy", "label": "维持费", "amount": 40, "min": 40, "max": 40, "payee": "维持会公账", "building": "baogong", "due_days": 0}
		Costs.add(town.world.town.pack, town.world.town.s, spec, "shot", "bill:shot_levy:d%d" % town.world.day, town.world)
		town.skip_to(600)
		await town.goto("baogong")
		await town.open_shop("baogong")
		await c.until(func(): return town.shop_view.is_open, 200)
		await c.frames(30)
		var sv = town.shop_view
		sv._run_action({"id": "negotiate", "label": "跟保长商量", "kind": "negotiate", "topic": "levy"})
		var prev := ""
		var last = null
		var says_after_counter := 0
		var guard := 0
		while guard < 3000:
			guard += 1
			await process_frame
			if not sv.busy and guard > 5:
				break
			var t: String = main.cur_type
			if t == "" or main.cur == last:
				continue
			last = main.cur
			match t:
				"counter":
					main._respond({"action": "offer", "value": main.cur["session"].ask})
					prev = "counter"
				"say", "narr":
					if prev == "counter" or prev == "say_after":
						says_after_counter += 1
						await c.frames(12)
						if says_after_counter == 1 and _want("baogong_offer"):
							await _shot("baogong_offer")
						elif says_after_counter == 2 and _want("baogong_reply"):
							await _shot("baogong_reply")
					prev = "say_after" if (prev == "counter" or prev == "say_after") else t
					main._on_dialogue_advanced()
				_:
					prev = t
					main._respond({})
		await c.frames(40)
		if _want("baogong_done"):
			await _shot("baogong_done")
		sv.close_shop()
		await c.until_idle()
	var code: int = 0
	await c.shutdown()
	quit(code)
