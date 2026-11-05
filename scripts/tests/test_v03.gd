# v0.3 验收：侧边对白、放大镜返回看货、单件购买、统一定价
extends SceneTree

const DialogueBox = preload("res://scripts/ui/dialogue_box.gd")
const InspectPanel = preload("res://scripts/ui/appraise_panel.gd")
const MainUI = preload("res://scripts/ui/main.gd")
const Session = preload("res://scripts/core/session.gd")
const World = preload("res://scripts/core/world.gd")

var failures: int = 0
var advanced_count: int = 0

func _initialize() -> void:
	await _run()

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("PASS: ", msg)
	else:
		failures += 1
		print("FAIL: ", msg)

func _def(id: String) -> Dictionary:
	var d: Dictionary = DB.get_db().items[id].duplicate(true)
	d["def_id"] = id
	return d

func _run() -> void:
	await _test_side_dialogue()
	await _test_inspect_return()
	_test_inspect_no_verdict()
	_test_pricing_and_single()
	await _test_sidebar_ondemand()
	DB.shutdown()
	print("RESULT: ", "OK" if failures == 0 else "FAILED (%d)" % failures)
	quit(0 if failures == 0 else 1)

func _test_side_dialogue() -> void:
	var box = DialogueBox.new()
	box.size = Vector2(420, 140)
	root.add_child(box)
	await process_frame
	_check(box.has_method("set_side"), "dialogue has set_side")
	box.set_side("npc", "xiaoding")
	_check(box.side == "npc", "side is npc")
	box.set_side("player", "you")
	_check(box.side == "player", "side is player")
	advanced_count = 0
	box.advanced.connect(func(): advanced_count += 1)
	box.instant = true
	box.show_line("你", "三十蚨。", Color("#e8c88a"), false, true, 1.1)
	_check(box.visible == true, "side bubble visible")
	_check(box.custom_minimum_size.x <= 420, "bubble width is side-sized")
	box.click()
	_check(advanced_count == 1, "side dialogue advances on click")
	box.show_options("你", "怎么办？", [{"id": "a", "label": "收"}, {"id": "b", "label": "不收"}])
	_check(box.option_button("a") != null, "options still work in side bubble")
	box.queue_free()
	await process_frame

func _test_inspect_return() -> void:
	var w = World.new()
	w.setup(7)
	var s = Session.new()
	s.setup(w, {
		"id": "probe_inspect", "npc": "xiaoding", "mode": "buy",
		"items": [{"def": "rice_sunji"}],
		"ask": 50, "floor": 25, "suggest": 40, "est": [40, 90],
		"min_inspect": 0
	})
	# 给第一件加一个带 event 的部位，验证验完不自动关
	var iid: String = s.item_ids[0]
	var it: Dictionary = s.item(iid)
	if it.get("parts", []).is_empty():
		it["parts"] = [{"id": "look", "label": "外观", "tool": "magnifier", "text": "成色一般", "event": "probe_evt"}]
	else:
		it["parts"][0]["event"] = "probe_evt"
	var panel = InspectPanel.new()
	root.add_child(panel)
	await process_frame
	panel.open(s, iid, false)
	_check(panel.visible == true, "inspect opens")
	var pid: String = str(it["parts"][0]["id"])
	var res: Dictionary = panel.circle_part(pid)   # 验货改为对着图鉴圈出来：用朱笔圈这一处
	_check(str(res.get("kind", "")) == "hit" and s.inspected[iid].has(pid), "circling the part reveals it")
	_check(panel.visible == true, "after inspect with event, panel stays open (can keep viewing)")
	_check(not s.pending_events.is_empty(), "pending event queued")
	panel._on_close()
	_check(panel.visible == false, "close hides panel → return to counter goods")
	panel.queue_free()
	await process_frame

func _test_inspect_no_verdict() -> void:
	# 主创 2026-10-11：鉴定只写观察，不写“有破绽 / 多半是假的”，也不替鉴别录下结论。
	var w = World.new()
	w.setup(7)
	w.unlocked["medbook"] = true
	var s = Session.new()
	s.setup(w, {
		"id": "probe_sulfa", "npc": "wangshan", "mode": "buy",
		"items": [{"def": "sulfa_fake"}],
		"ask": 40, "floor": 10, "suggest": 20, "est": [10, 40],
		"min_inspect": 0
	})
	var iid: String = s.item_ids[0]
	var banned: Array = ["有破绽", "多半是假", "来路有问题", "已知假批号", "不对"]
	for p in s.item(iid).get("parts", []):
		var text: String = s.inspect(iid, str(p["id"]))
		_check(text != "", "sulfa part %s inspects" % str(p["id"]))
		for b in banned:
			_check(text.find(str(b)) < 0, "inspect omits '%s'" % str(b))
	_check(s.tells_found("sulfa_fake") >= 1, "tell stays internal for the autoplayer")
	for n in w.notebook:
		var tx: String = str(n.get("text", ""))
		for b in banned:
			_check(tx.find(str(b)) < 0, "notebook omits '%s'" % str(b))

func _test_pricing_and_single() -> void:
	var w = World.new()
	w.setup(11)
	w.ledger.add_item(_def("rice_sunji"), "player", "stock")
	w.ledger.add_item(_def("rice_jing_a"), "player", "stock")
	var s = Session.new()
	s.setup(w, {
		"id": "probe_sell2", "npc": "zhouma", "mode": "sell",
		"stock": ["rice_sunji", "rice_jing_a"],
		"buyer_prices": {
			"rice_sunji": {"offer": 55, "max": 75},
			"rice_jing_a": {"offer": 73, "max": 99}
		}
	})
	_check(s.mode == "sell", "sell session")
	_check(s.item_ids.size() == 2, "two stock items")
	var market_sum := 0
	for iid in s.selected_ids():
		market_sum += w.market_now(s.item(iid))
	_check(market_sum > 0, "market sum > 0")
	_check(s.ask >= int(market_sum * 0.45), "unified pricing: ask near market (ask=%d market=%d)" % [s.ask, market_sum])
	_check(s.floor_v >= s.ask, "max >= offer")
	# 单件
	var keep: String = s.item_ids[0]
	for iid in s.item_ids:
		s.set_selected(iid, iid == keep)
	_check(s.selected_ids().size() == 1, "single-item select")
	var unit_m: int = w.market_now(s.item(keep))
	_check(s.ask >= 1 and s.ask <= unit_m * 2 + 5, "single-item ask sane (ask=%d m=%d)" % [s.ask, unit_m])
	_check(s.has_method("unit_price_of"), "unit_price_of exists")
	var up: Dictionary = s.unit_price_of(keep)
	_check(int(up.get("market", 0)) == unit_m, "unit_price_of market matches")

func _test_sidebar_ondemand() -> void:
	# v0.3b：侧栏默认隐藏，全屏柜台；可弹出再合上
	var main = MainUI.new()
	main.autostart = false
	root.add_child(main)
	await process_frame
	await process_frame
	_check(main.VIEW_SCALE == 4, "view scale is 4 (full-bleed)")
	_check(main.sidebar != null and main.sidebar.visible == false, "sidebar hidden by default")
	_check(main.cash_chip != null and main.cash_chip.visible == true, "cash chip visible when sidebar closed")
	_check(main.scene_holder.size.x >= 1280 and main.scene_holder.size.y >= 720, "counter holder is full screen")
	_check(main.desk_edge != null, "desk edge bar exists")
	main._show_sidebar()
	_check(main.sidebar.visible == true, "sidebar opens on demand")
	_check(main.cash_chip.visible == false, "cash chip hides while panel open")
	main._hide_sidebar(true)
	_check(main.sidebar.visible == false, "sidebar closes")
	_check(main.cash_chip.visible == true, "cash chip returns")
	main._set_bottom_hint("▼ 点气泡或按空格继续")
	_check(main.bottom_hint.visible == true, "bottom hint when dialogue active")
	main._clear_bottom_hint()
	_check(main.bottom_hint.visible == false, "bottom hint clears when idle")
	main.queue_free()
	await process_frame
