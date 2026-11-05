# W0 骨架自测③：真的牌桌场景 CardGame.tscn 接 Mock 情景模式，无头用 autoplay_step() 走开局 + 第 1–3 天，
# 新手指引（例子集的 3 步）按顺序亮：shown_log == _examples/guide/steps.json 的 _test.d1_3。
# 同时查：每条指令以 command_done、view_changed 收尾；视图无隐藏键；牌桌锚点都在 1280×720 里；界面上的字都来自 CardText；
# 规定的 ui_event（panel_opened/closed、hand_selected、guide_shown/done）都发了；指引只发 ui.guide。
# 合同：docs/cards/CARDS_INTERFACES.md §7.7、§7.10.7、§7.10.9、§12.1。
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const C01_ANCHORS: Array = [["a.top.date"], ["a.top.weather"], ["a.top.money"], ["a.top.rep"], ["a.top.heat"],
	["a.btn.close_day"], ["a.hand"], ["a.scene.notice"], ["a.scene.ledger"], ["a.scene.notebook"], ["a.tab.shelf"],
	["a.hero"], ["a.contacts"]]


func _initialize() -> void:
	var t := T.new(self, "W0_table_3days")
	t.run_async(_body.bind(t))


func _body(t) -> void:
	Engine.set_meta(MockCardEngine.EXAMPLE_GUIDE_META, true)   # W0 只测例子集的 3 步，不跟着 K16 的真步骤变
	var bus := CardEventBus.new()
	root.add_child(bus)
	var spy = t.spy(bus)
	var game: CardGameRoot = load(CardIds.ROOT_SCENE).instantiate()
	game.boot({"mock": true, "bus": bus, "seed": 7, "skip_title": true, "guide": "on"})
	root.add_child(game)
	game.guide.force(true)
	game.guide.skip_fades = true
	await t.frames(2)
	var mock: MockCardEngine = game.engine
	t.eq(game.engine.view().get("phase"), "month_open", "new game starts at month_open")
	var steps := 0
	var anchors_checked := false
	var leaks := PackedStringArray()
	while steps < 600:
		var v := game.engine.view()
		leaks.append_array(CardViewModel.leaks(v))
		if str(v.get("phase", "")) == "day" and not anchors_checked and game.host.top_panel() == null:
			anchors_checked = true
			for a in C01_ANCHORS:
				t.ok(t.anchor_ok_any(a), "table anchor %s inside 1280x720" % str(a))
			var bad: PackedStringArray = t.all_text_from_cardtext(game.table)
			t.ok(bad.is_empty(), "table text all from CardText: %s" % ", ".join(bad))
		if str(v.get("phase", "")) == "morning" and int(v.get("date", {}).get("stage_day", 0)) == 4:
			break
		game.autoplay_step()
		await t.frames(1)
		game.guide.tick(0.5)
		game.guide.evaluate_now()
		steps += 1
	var v2 := game.engine.view()
	t.eq(v2.get("phase"), "morning", "reached a morning (steps=%d)" % steps)
	t.eq(int(v2.get("date", {}).get("stage_day", 0)), 4, "reached the morning of day 4")
	t.ok(leaks.is_empty(), "views have no hidden keys: %s" % ", ".join(leaks))
	var want: Array = mock.db.guide_test().get("d1_3", [])
	t.ok(not want.is_empty(), "examples guide has _test.d1_3")
	t.eq(Array(game.guide.shown_log), want, "guide steps lit in order on days 1-3")
	await _check_guide(t, mock, game, want)
	_check_signals(t, spy)
	# 指引覆盖层不挡鼠标
	for n in [game.guide] + game.guide.get_children():
		t.ok((n as Control).mouse_filter == Control.MOUSE_FILTER_IGNORE, "guide overlay node ignores the mouse")
	game.queue_free()
	bus.queue_free()
	await t.frames(2)


func _check_guide(t, mock: MockCardEngine, game: CardGameRoot, want: Array) -> void:
	# 指引只发 ui.guide；每一步都记了 shown 和 done
	await t.frames(2)
	var ui_guide: Array = mock.sent.filter(func(r: Array) -> bool: return r[0] == "ui.guide")
	for step in want:
		t.ok(ui_guide.any(func(r: Array) -> bool: return r[1]["step"] == step and r[1]["status"] == "shown"),
			"ui.guide shown sent for " + str(step))
		t.ok(ui_guide.any(func(r: Array) -> bool: return r[1]["step"] == step and r[1]["status"] == "done"),
			"ui.guide done sent for " + str(step))
	var prog: Dictionary = game.engine.query(&"guide_progress").get("progress", {})
	for step in want:
		t.eq(prog.get(step, {}).get("status", ""), "done", "progress done for " + str(step))


func _check_signals(t, spy) -> void:
	# 每条指令以 command_done、view_changed 收尾（中间夹着的 ui_event 是界面对 command_done 的反应，不算引擎事件）
	var names: Array = spy.names().filter(func(n: StringName) -> bool: return n != &"ui_event")
	var cmd_count := 0
	for i in range(names.size()):
		if names[i] == &"command_done":
			cmd_count += 1
			t.ok(i + 1 < names.size() and names[i + 1] == &"view_changed", "command_done #%d is followed by view_changed" % cmd_count)
	t.ok(cmd_count > 30, "many commands ran (%d)" % cmd_count)
	var ui_names: Array = spy.ui_events().map(func(e: Array) -> StringName: return e[0])
	t.ok(ui_names.has(&"hand_selected") or ui_names.has(&"hand_played"), "hand selection or play was emitted")
	for n in [&"panel_opened", &"panel_closed", &"guide_shown", &"guide_done"]:
		t.ok(ui_names.has(n), "ui_event %s was emitted" % n)
	for e in spy.ui_events():
		t.ok(CardIds.UI_EVENTS.has(e[0]), "ui_event %s is in CardIds.UI_EVENTS" % e[0])
	var firsts: Array = spy.log.filter(func(r: Array) -> bool: return r[0] == &"first_time").map(
		func(r: Array) -> StringName: return r[1])
	for m in [&"month_open", &"month_wheel", &"incense", &"notice", &"deal", &"person", &"counter", &"mg.spot", &"ticket",
			&"shelf", &"buyer", &"night", &"settle", &"gold", &"choice", &"keep", &"slots", &"coins"]:
		t.ok(firsts.has(m), "first_time %s fired in days 1-3" % m)
	for m in firsts:
		t.eq(firsts.count(m), 1, "first_time %s fired exactly once" % m)
