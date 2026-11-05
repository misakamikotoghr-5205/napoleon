# 小镇界面（g）：店里的剧情与议价、热键、店铺状态。
#   H2  保公所“跟保长商量”：柜台拍之后的对白拍（保长的回话、我方出价）必须看得见，不能被柜台层翻回特写时收掉
#   M7  议价结果以议价当时的为准：被拒就是被拒，不能被之后的家用刷新改成“议定了”
#   M8  店铺特写的打字机每次打开都从头来，不带上一家店没打完的话
#   L4  店铺特写里 Tab/J/H/C 能开账簿/档案/家用/日历；Esc 先关 HUD 打开的册子，再退子菜单，最后才是暂停菜单
# godot --headless -s res://scripts/tests/town_ui_scene.gd
extends SceneTree

const Common = preload("res://scripts/tests/town_ui_common.gd")
const Costs = preload("res://scripts/sim/living_costs.gd")

var c
var town
var main

func _initialize() -> void:
	_run()

func _key(code: int) -> void:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.physical_keycode = code
	ev.pressed = true
	root.push_input(ev)
	await process_frame

func _add_levy(tag: String, amount: int) -> String:
	var id := "bill:test_%s:d%d" % [tag, town.world.day]
	var spec := {"id": "levy", "label": "维持费", "amount": amount, "min": amount, "max": amount, "payee": "维持会公账",
		"building": "baogong", "due_days": 0}
	var bill: Dictionary = Costs.add(town.world.town.pack, town.world.town.s, spec, "test", id, town.world)
	c.check(not bill.is_empty(), "（测试）加了一笔维持费 %s %d 蚨" % [id, amount])
	return id

# 把气泡里排着的话一句句翻完，返回全部文字（打字机不快，议价一结束结果句还在队里）
func _drain_lines() -> String:
	var sv = town.shop_view
	var out: Array = [sv._full]
	var guard := 0
	while guard < 20:
		guard += 1
		if sv._line_done and sv._queue.is_empty():
			break
		if not sv._advance():
			break
		if out.back() != sv._full:
			out.append(sv._full)
	return "|".join(out)

func _bill_status(id: String) -> String:
	for b in town.world.town.s["bills"]:
		if str(b["id"]) == id:
			return str(b["status"])
	return ""

func _levy_open_here() -> void:
	for b in ["baogong"]:
		town.world.town.s["unlocked"][b] = true
	town.skip_to(600)

# 驱动一次“跟保长商量”：每帧看一眼界面，到对白拍就核对对白框看得见，再往下走；柜台拍按 plan 回应。
# 返回 {say_after_counter, hidden, saw_counter, offers}
func _drive_negotiation(plan: String) -> Dictionary:
	var sv = town.shop_view
	var stats := {"say_after_counter": 0, "hidden": 0, "samples": 0, "saw_counter": 0, "flipped_ok": 0, "texts": []}
	var prev_type := ""
	var last_cur = null
	var started: bool = false
	var guard := 0
	sv._run_action({"id": "negotiate", "label": "跟保长商量", "kind": "negotiate", "topic": "levy"})
	while guard < 2400:
		guard += 1
		await process_frame
		if sv.busy:
			started = true
		if started and not sv.busy:
			break
		var t: String = main.cur_type
		if t == "" or main.cur == last_cur:
			continue
		last_cur = main.cur
		match t:
			"counter":
				stats["saw_counter"] += 1
				var ask: int = main.cur["session"].ask
				if plan == "accept":
					main._respond({"action": "offer", "value": ask})
				else:
					main._respond({"action": "refuse"})
				prev_type = "counter"
			"say", "narr":
				stats["samples"] += 1
				stats["texts"].append(str(main.cur.get("text", "")).substr(0, 14))
				if not main.dialogue.visible:
					stats["hidden"] += 1
				if prev_type == "counter":
					stats["say_after_counter"] += 1
					if main.mode == "closeup" and not main.scene_holder.visible:
						stats["flipped_ok"] += 1
				prev_type = t
				main._on_dialogue_advanced()
			"choice":
				stats["samples"] += 1
				if not main.dialogue.visible:
					stats["hidden"] += 1
				prev_type = t
				var opts: Array = main.cur.get("options", [])
				main._respond({"id": str(opts[0]["id"])})
			_:
				prev_type = t
				main._respond({})
	return stats

func _run() -> void:
	c = Common.new(self)
	await c.boot(12, false, false)       # 不接 autoplayer：对白和柜台由本测试自己回应
	town = c.town
	main = c.main
	main.dialogue.instant = true
	town.seconds_per_minute = 100000.0
	_levy_open_here()
	# 小镇里（不在店里）：Tab 开账簿，Esc 要能关掉它（以前 Esc 被小镇吃掉，册子关不上）
	await _key(KEY_TAB)
	c.check(main.book.visible, "街上按 Tab：账簿开了")
	await _key(KEY_ESCAPE)
	c.check(not main.book.visible and town._modal_depth == 0, "街上 Esc 先关账簿，没弹暂停菜单")
	await _key(KEY_C)
	await _key(KEY_ESCAPE)
	c.check(not main.generic_panel.visible and town._modal_depth == 0, "街上 Esc 关日历")
	await town.goto("baogong")
	await town.open_shop("baogong")
	await c.until(func(): return town.shop_view.is_open, 200)
	var sv = town.shop_view
	c.check(sv.is_open and town.mode == "closeup", "进了保公所特写")

	# ---------- H2 + M7：议价谈成 ----------
	var bill1 := _add_levy("accept", 40)
	var cash0: int = town.world.cash()
	var st: Dictionary = await _drive_negotiation("accept")
	c.check(int(st["saw_counter"]) >= 1, "议价进了柜台拍（%d 次）" % st["saw_counter"])
	c.check(int(st["say_after_counter"]) >= 1, "柜台拍之后有对白拍（%d 句：%s）" % [st["say_after_counter"], str(st["texts"])])
	c.check(int(st["hidden"]) == 0, "议价里每一句对白拍对白框都看得见（%d 句里藏了 %d 句）" % [st["samples"], st["hidden"]])
	c.check(int(st["flipped_ok"]) == int(st["say_after_counter"]), "柜台拍之后的对白拍已经翻回特写（%d/%d）" % [st["flipped_ok"], st["say_after_counter"]])
	c.check(_bill_status(bill1) == "paid", "谈成：账付清了（%s）" % _bill_status(bill1))
	c.check(town.world.cash() < cash0, "谈成：钱匣少了 %d → %d" % [cash0, town.world.cash()])
	c.check(bool(sv.last_result.get("ok", false)), "last_result 记的是谈成")
	var said1 := _drain_lines()
	c.check(said1.find("议定了") >= 0, "掌柜气泡：议定了（%s）" % said1)
	c.check(not main.dialogue.visible and not main.scene_holder.visible and main.mode == "closeup", "议价结束：对白框收起，柜台层不在，回到特写")
	c.check(sv.menu_panel.visible and sv.menu_box.get_child_count() >= 3, "议价结束：菜单回来了")
	c.check(town.world.ledger.check_invariants().is_empty(), "账本不变量没破")

	# ---------- M7：议价被拒 ----------
	var bill2 := _add_levy("refuse", 36)
	var cash1: int = town.world.cash()
	var st2: Dictionary = await _drive_negotiation("refuse")
	c.check(int(st2["say_after_counter"]) >= 1 and int(st2["hidden"]) == 0, "拒收那一拍的对白也看得见（%d 句，藏 %d）" % [st2["say_after_counter"], st2["hidden"]])
	c.check(_bill_status(bill2) == "due" and town.world.cash() == cash1, "被拒：账还欠着、钱没动（%s）" % _bill_status(bill2))
	c.check(not bool(sv.last_result.get("ok", true)), "被拒：last_result 不是成功 %s" % str(sv.last_result))
	var said2 := _drain_lines()
	c.check(said2.find("议定了") < 0 and said2.find("没谈拢") >= 0, "被拒：气泡不说“议定了”，说“没谈拢”（%s）" % said2)

	# ---------- 店里的剧情对白：Esc 是暂停菜单（不推进对白）；E / 空格 / 回车 / 点击才推进 ----------
	sv._run_action({"id": "notice", "label": "问告示", "kind": "script", "script": "town_shop_bao_notice"})
	var got_say: bool = await c.until(func(): return main.cur_type in ["say", "narr"], 600)
	c.check(got_say and main.dialogue.visible, "店里的剧情：对白出来了（%s）" % main.cur_type)
	var first_beat = main.cur
	await _key(KEY_ESCAPE)
	c.check(main.cur == first_beat and town.is_pause_open(), "剧情对白里按 Esc：开暂停菜单，对白没被推进")
	await _key(KEY_ESCAPE)
	c.check(not town.is_pause_open() and main.cur == first_beat and town._modal_depth == 0, "再按 Esc 回到对白，还是那一句")
	await _key(KEY_E)
	c.check(main.cur != first_beat, "E 推进剧情对白")
	var guard_s := 0
	while sv.busy and guard_s < 600:
		guard_s += 1
		if main.cur_type in ["say", "narr"]:
			main._on_dialogue_advanced()
		elif main.cur_type == "choice":
			main._respond({"id": str(main.cur["options"][0]["id"])})
		await process_frame
	c.check(not sv.busy and sv.menu_panel.visible, "剧情走完，回到店铺菜单")

	# ---------- M8：打字机状态不串店 ----------
	sv.say("（买了很长很长的一段话，还没打完就走。）", true)
	c.check(not sv._line_done or sv._full != "", "刚说了一句话")
	sv.close_shop()
	await c.until_idle()
	c.check(sv._line_done and sv._full == "" and sv.pending_lines() == 0 and sv.bubble_text.text == "", "出店：打字机归零（队列空、字清空）")
	await town.goto("ricehall")
	await town.open_shop("ricehall")
	await c.until(func(): return sv.is_open, 200)
	var greeting_ok: bool = sv._full != "" and sv.bubble_text.text == sv._full and sv.bubble_name.text == sv.keeper_label
	c.check(greeting_ok and sv._full.find("买了很长") < 0, "进下一家：气泡是这家掌柜的招呼语，不是上一句（%s / %s）" % [sv.keeper_label, sv._full])
	# 没打完时直接换店也一样
	sv.say("（又一句没打完的话。）", true)
	sv.close_shop()
	await c.until_idle()
	await town.open_shop("ricehall")
	await c.until(func(): return sv.is_open, 200)
	c.check(sv._full.find("又一句") < 0 and sv.bubble_text.text.find("又一句") < 0, "打字中退出再进：不残留旧句子")

	# ---------- L4：特写里的热键与 Esc ----------
	await c.frames(2)
	await _key(KEY_TAB)
	c.check(main.book.visible, "店里按 Tab：账簿开了")
	await _key(KEY_ESCAPE)
	c.check(not main.book.visible and sv.is_open and town._modal_depth == 0, "Esc 先关账簿（没弹暂停菜单，店也没关）")
	await _key(KEY_J)
	c.check(main.book.visible, "店里按 J：档案开了")
	# 子菜单开着、账簿压在上面：Esc 先关账簿，子菜单还在
	main.book.visible = false
	sv._run_action({"kind": "buy", "category": "rice", "units": [1, 2], "label": "买米"})
	c.check(sv.menu_title.visible, "进了买米子菜单")
	await _key(KEY_TAB)
	c.check(main.book.visible, "子菜单里按 Tab：账簿开了")
	await _key(KEY_ESCAPE)
	c.check(not main.book.visible and sv.menu_title.visible, "Esc 先关账簿，子菜单还在")
	await _key(KEY_ESCAPE)
	c.check(not sv.menu_title.visible and sv.is_open, "再 Esc 才退子菜单")
	await _key(KEY_C)
	c.check(main.generic_panel.visible, "店里按 C：日历开了")
	await _key(KEY_ESCAPE)
	c.check(not main.generic_panel.visible and town._modal_depth == 0, "Esc 关日历")
	await _key(KEY_H)
	c.check(town._modal_depth == 1, "店里按 H：家用簿开了")
	town.dismiss_modals()
	await c.frames(2)
	c.check(town._modal_depth == 0, "家用簿关了")
	# 账簿开着时数字键不漏给后面的菜单
	await _key(KEY_TAB)
	var stock_before: int = int(town.household().get("rice", 0))
	await _key(KEY_1)
	c.check(main.book.visible and sv.menu_title.visible == false and int(town.household().get("rice", 0)) == stock_before and not sv.menu_title.visible, "账簿开着时按 1：不会点进下面的菜单")
	main.book._close()
	sv.close_shop()
	await c.until_idle()

	print("RESULT: ", "OK" if c.failures == 0 else "FAILED (%d)" % c.failures)
	var code: int = 0 if c.failures == 0 else 1
	await c.shutdown()
	quit(code)
