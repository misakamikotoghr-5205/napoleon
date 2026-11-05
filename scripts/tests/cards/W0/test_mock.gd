# W0 骨架自测④：MockCardEngine 能回放十个基础夹具（视图、查询键的唯一写法、按序匹配回应、补丁、自动补 command_done 与
# view_changed、sent 记录、ui.guide 更新进度、guide_data 退回例子集）；每个夹具带 firsts、无隐藏键；day_counter 的找不同参数
# 只有布局（没有 §8.2 的禁用键）。最后演示 C16 / 各界面任务的指引测试做法：不建牌桌，自己摆占位锚点，Mock 情景驱动第 1 天，
# CardGuide.force(true) + evaluate_now() 看 active_step()。合同：docs/cards/CARDS_INTERFACES.md §7.7、§7.10.9、§8.2。
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const FIXTURES: Array[String] = ["month_open", "month_wheel", "morning", "day_full", "day_counter", "night", "settle",
	"month_close", "year_jump", "street_prison"]


func _initialize() -> void:
	var t := T.new(self, "W0_mock")
	t.run_async(_body.bind(t))


func _body(t) -> void:
	Engine.set_meta(MockCardEngine.EXAMPLE_GUIDE_META, true)   # W0 只测例子集的 3 步，不跟着 K16 的真步骤变
	var bus := CardEventBus.new()
	root.add_child(bus)
	await t.frames(1)   # _initialize 里场景树还没开始跑：先等一帧，节点才算进树（锚点要用）
	var spy = t.spy(bus)
	for name in FIXTURES:
		var m := MockCardEngine.new(bus)
		m.load_fixture(name)
		t.eq(m.fixture_path, "res://scripts/cards/mock/fixtures/%s.json" % name, "fixture path for " + name)
		var v := m.view()
		t.ok(v.has("phase") and v.has("hand") and v.has("date"), name + ": view has phase/hand/date")
		t.no_leaks(v, name + " view")
		t.ok(m.query(&"firsts").has("firsts"), name + ": firsts query present")
		var fx = CardDB.read_json(m.fixture_path)
		t.eq(str(fx["_meta"]["_provenance"]), "ai_placeholder", name + ": fixture marked ai_placeholder")
		for k in fx["queries"].keys():
			t.no_leaks(fx["queries"][k], name + " query " + k)
		# 每条录下的回应都能按原样回放
		for resp in fx["responses"]:
			if str(resp["cmd"]) == "*":
				continue
			var m2 := MockCardEngine.new(bus)
			m2.load_fixture(name)
			spy.clear()
			var r := m2.send(StringName(resp["cmd"]), resp["match"])
			t.eq(r, resp["result"], "%s: %s replays its result" % [name, resp["cmd"]])
			var names: Array = spy.names()
			t.eq(names.slice(-2), [&"command_done", &"view_changed"], "%s: %s ends with command_done, view_changed" % [name, resp["cmd"]])
			t.eq(m2.sent.back(), [str(resp["cmd"]), resp["match"]], name + ": sent records the command")
			for p in resp["patch"]:
				t.eq(m2.view().get(p["path"]), p["value"], "%s: %s patched %s" % [name, resp["cmd"], p["path"]])
		var fallback := m.send(&"some.command", {"x": 1})
		t.eq(fallback, {"ok": true, "err": ""}, name + ": '*' fallback")
	# 查询键的唯一写法
	t.eq(MockCardEngine.query_key(&"counter", {"uid": "c0007"}), "counter|{\"uid\":\"c0007\"}", "query key")
	t.eq(MockCardEngine.query_key(&"firsts", {}), "firsts|{}", "query key without args")
	t.eq(MockCardEngine.query_key(&"wheel", {"wheel": "wh.month", "uid": ""}), "wheel|{\"uid\":\"\",\"wheel\":\"wh.month\"}",
		"query key sorts keys")
	# 找不同的参数只有布局
	var mc := MockCardEngine.new(bus)
	mc.load_fixture("day_counter")
	var req := mc.send(&"mg.request", {"uid": "c0002", "item": "I001"})
	t.eq(req.get("kind"), "spot", "day_counter: hairpin -> spot")
	var bad := _keys_in(req.get("params", {}), CardAppraisal.FORBIDDEN_PARAM_KEYS)
	t.ok(bad.is_empty(), "spot params have no forbidden keys: %s" % ", ".join(bad))
	t.ok(not (req["params"].get("marks", []) as Array).is_empty(), "spot layout has marks from real ItemGen")
	# guide_data 退回例子集；ui.guide 更新进度，不发事件
	var gd := mc.query(&"guide_data")
	t.eq((gd["steps"] as Array).size(), 3, "guide_data falls back to the example steps")
	spy.clear()
	t.eq(mc.send(&"ui.guide", {"step": "gd.d1.deal", "status": "shown"}), {"ok": true, "err": ""}, "ui.guide ok")
	t.eq(spy.log.size(), 0, "ui.guide emits nothing")
	t.eq(mc.query(&"guide_progress")["progress"]["gd.d1.deal"]["shows"], 1, "progress updated")
	# 指引测试的做法（不建牌桌）：占位锚点 + 情景模式第 1 天 + CardGuide
	var holder := Control.new()
	root.add_child(holder)
	var hand := ColorRect.new()
	hand.position = Vector2(232, 380)
	hand.size = Vector2(816, 332)
	holder.add_child(hand)
	CardAnchors.register(&"a.hand", hand)
	var scn := MockCardEngine.new(bus)
	var guide: CardGuide = load("res://scenes/cards/shell/GuideOverlay.tscn").instantiate()
	holder.add_child(guide)
	guide.bind(scn, bus)
	guide.skip_fades = true
	guide.force(false)
	scn.new_game({"seed": 7})
	scn.send(&"wheel.spin", {"wheel": "wh.month", "uid": ""})
	scn.send(&"month.begin")
	scn.send(&"day.begin")
	guide.evaluate_now()
	t.eq(guide.active_step(), "", "guide off: nothing lights")
	guide.force(true)
	guide.evaluate_now()
	t.eq(guide.active_step(), "gd.d1.deal", "day 1 deal step lights on a.hand")
	bus.ui_event.emit(&"hand_selected", {"uid": "c0002"})
	t.eq(guide.active_step(), "", "hand_selected completes gd.d1.deal")
	var card := ColorRect.new()
	card.position = Vector2(240, 400)
	card.size = Vector2(144, 200)
	holder.add_child(card)
	CardAnchors.register(&"a.card@c0002", card)
	guide.evaluate_now()
	t.eq(guide.active_step(), "gd.d1.person", "person step lights on a.card@<uid of the first person>")
	scn.send(&"counter.open", {"uid": "c0002"})
	t.eq(guide.active_step(), "", "cmd:counter.open completes gd.d1.person")
	t.eq(Array(guide.shown_log), ["gd.d1.deal", "gd.d1.person"], "shown_log")
	holder.queue_free()
	bus.queue_free()
	await t.frames(2)


func _keys_in(v, forbidden: Array) -> PackedStringArray:
	var out := PackedStringArray()
	if typeof(v) == TYPE_DICTIONARY:
		for k in v.keys():
			if forbidden.has(str(k)):
				out.append(str(k))
			out.append_array(_keys_in(v[k], forbidden))
	elif typeof(v) == TYPE_ARRAY:
		for x in v:
			out.append_array(_keys_in(x, forbidden))
	return out
