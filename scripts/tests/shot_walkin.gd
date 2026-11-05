# [shop-only] v0.4.2 截图：门口吆喝卖货 → 买主进门站定 → 柜台上他说要哪件、问两句、拨算盘谈价 → 成交提示 → 货架只看。
# 走 town_ui_walkin 的同一条路（种子 7，第三天），在要紧的地方截图。
# xvfb-run -a -s "-screen 0 1280x720x24" godot --rendering-driver opengl3 --audio-driver Dummy --path . -s res://scripts/tests/shot_walkin.gd -- --out=<dir>
extends "res://scripts/tests/town_ui_walkin.gd"

var out_dir := ""
var n_shot := 0

func _shot(name: String) -> void:
	for i in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	n_shot += 1
	var path := out_dir.path_join("walkin_%02d_%s.png" % [n_shot, name])
	root.get_viewport().get_texture().get_image().save_png(path)
	print("SHOT ", path)

func _run() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out_dir = a.substr(6)
	if out_dir == "":
		out_dir = ProjectSettings.globalize_path("res://screenshots")
	DirAccess.make_dir_recursive_absolute(out_dir)
	cfg = Walkin.config()
	c = Common.new(self)
	c.shop_only = true
	await c.boot(7, true, true)
	town = c.town
	main = c.main
	main.dialogue.instant = true
	town.seconds_per_minute = 100000.0
	await _part_day1()
	await _next_day()
	await _next_day()
	await _part_call_and_buy()
	var shelf = load("res://scripts/town/shelf_panel.gd").new()
	shelf.build(town)
	town._open_modal(shelf, false)      # 测试模式下弹窗会自动收起：这张不让它收
	await _shot("shelf_read_only")
	if not town._open_modals.is_empty():
		town._open_modals.back().close()
	print("SHOTS DONE ", n_shot, " failures=", c.failures)
	await c.shutdown()
	quit(0)

# 同 town_ui_walkin 的买主驱动，多了截图：他开口、问过一句、头一回拨算盘、他还价
func _drive_buyer(visit: Dictionary) -> Dictionary:
	var wk = town.visitors.walker_of(str(visit.get("id", "")))
	if wk != null:
		await _shot("buyer_waiting")
	var out := {"lines": [], "counters": 0, "extras": [], "labels": [], "used": [], "offers": [], "mode": "", "items": 0}
	_manual(true)
	town.start_counter(visit)
	var last_cur = null
	var guard := 0
	var said_shot := 0
	while guard < 6000:
		guard += 1
		await process_frame
		if town.mode != "counter":
			break
		var t: String = main.cur_type
		if t == "" or main.cur == last_cur:
			continue
		last_cur = main.cur
		match t:
			"say", "narr":
				out["lines"].append(str(main.cur.get("text", "")))
				if said_shot < 4:
					said_shot += 1
					await _shot("counter_say_%d" % said_shot)
				main._on_dialogue_advanced()
			"counter":
				out["counters"] = int(out["counters"]) + 1
				var s = main.cur["session"]
				if int(out["counters"]) == 1:
					out["mode"] = str(s.mode)
					out["items"] = s.item_ids.size()
					out["ask0"] = int(s.ask)
					out["abacus"] = int(main.sidebar.abacus_value) if main.sidebar != null else -1
					for e in main.cur.get("extras", []):
						out["extras"].append(str(e["id"]))
						out["labels"].append(str(e["label"]))
					_counter_names(out)
					await _shot("counter_haggle")
				var left := ""
				for e in main.cur.get("extras", []):
					if not out["used"].has(str(e["id"])):
						left = str(e["id"])
						break
				if left != "":
					out["used"].append(left)
					main._respond({"action": "extra", "id": left})
					continue
				var v: int = s.ask + int(float(s.floor_v - s.ask) * 0.5) if out["offers"].is_empty() else s.ask
				out["offers"].append(v)
				if out["offers"].size() == 2:
					await _shot("counter_after_counteroffer")
				main._respond({"action": "offer", "value": v})
			"choice":
				var opts: Array = main.cur.get("options", [])
				main._respond({"id": str(opts[0]["id"])} if not opts.is_empty() else {})
			_:
				main._respond({})
	_manual(false)
	await c.until_idle()
	await _shot("sold_toast")
	return out
