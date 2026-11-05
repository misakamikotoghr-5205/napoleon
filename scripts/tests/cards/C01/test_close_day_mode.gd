# C01 · #182 条目 1（DESIGN_cards.md §九.7）：“打烊 · 下一天”按处境换字，只换字、按钮照样能按、照样发 day.end。
# ① 选键助手（preload，无 class_name）：铺子 / 街头 / 牢里 / 查封 / 牢里又查封 / 局终 / 开月等非“下一天”键原样；
# ② 三个新键在 C01.json 里登记了、有 brief，且 #42 的打烊键都还在；
# ③ 实际根场景按钮（card_game_root.gd 的 _end/_end_title，#42 的新版）：各处境文字对、没禁用。
#    牢里、street_prison 按下仍发 day.end。街头、查封再按下并确认，阶段要往前走。
#    局终即使处境是街头，根按钮仍是原字，不换成街头那句。打开局终面板由 C01_next_day 覆盖。
# ④ street_prison 夹具（C11 核对：街头 + 牢里）：根场景按钮显示牢里的字，按下发 day.end confirm:false。
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const S = preload("res://scripts/tests/cards/C01/support.gd")
const L = preload("res://scripts/cards/ui/table/close_day_label.gd")
const END := "c01.btn.close_day.end_day"
const NEXT := "c01.btn.close_day.next_day"


func _initialize() -> void:
	var t := T.new(self, "C01_close_day_mode")
	t.run_async(_body.bind(t))


func _v(mode: String, set_name: String, sealed: bool, phase: String = "day") -> Dictionary:
	return {"phase": phase, "mode": mode, "stage": {"set": set_name, "time": "day", "sealed": sealed}}


func _body(t) -> void:
	var db := CardDB.load_all(CardDB.DEFAULT_ROOT, {})
	CardText.setup(db)
	var cases := [
		[_v("shop", "counter", false), END, END],
		[_v("street", "street", false), END, "c01.btn.close_day.mode.street"],
		[_v("shop", "prison", true), END, "c01.btn.close_day.mode.prison"],
		[_v("street", "prison", true), NEXT, "c01.btn.close_day.mode.prison"],
		[_v("shop", "counter", true), END, "c01.btn.close_day.mode.sealed"],
		[{"phase": "day", "mode": "prison"}, END, "c01.btn.close_day.mode.prison"],
		[{"phase": "day", "mode": "sealed"}, NEXT, "c01.btn.close_day.mode.sealed"],
		[{"phase": "day"}, END, END],
		[_v("street", "prison", true, "game_over"), "c01.btn.close_day.game_over", "c01.btn.close_day.game_over"],
		[_v("street", "street", false, "month_open"), "c01.btn.close_day.begin_month", "c01.btn.close_day.begin_month"],
		[_v("shop", "counter", true, "year_jump"), "c01.btn.close_day.year_next", "c01.btn.close_day.year_next"],
	]
	for c in cases:
		t.eq(L.key_for(c[0], c[1]), c[2], "key for %s / %s" % [c[0], c[1]])
	t.ok(not ClassDB.class_exists("CardCloseDayLabel") and not _global("CardCloseDayLabel"), "helper adds no global class")
	var keys := db.ui_keys()
	for s in ["prison", "street", "sealed"]:
		var k: String = "c01.btn.close_day.mode." + s
		t.ok(keys.has(k) and str(keys[k].get("brief", "")) != "", "%s registered with a brief" % k)
		t.ok(CardText.ui(k) != "", "%s renders" % k)
	for k in ["end_day", "next_day", "skip_night", "game_over", "begin_month", "left", "done"]:
		t.ok(keys.has("c01.btn.close_day." + k), "C01 #42 key kept: c01.btn.close_day." + k)
	# ③ 实际根场景按钮
	var bus := CardEventBus.new()
	root.add_child(bus)
	var game := S.boot(self, bus, "day_full")
	await t.frames(2)
	var mock: MockCardEngine = game.engine
	var preview: Dictionary = mock.query(&"day.end_preview")
	var step := str(preview.get("step", ""))
	var base := "c01.btn.close_day." + (step if step != "" else "next_day")
	for c in cases:
		var view: Dictionary = (c[0] as Dictionary).duplicate(true)
		if str(view.get("phase", "")) != "day": continue
		game._refresh_end(view)
		var want := L.key_for(view, base)
		t.eq(game._end_title.text, CardText.ui(want), "root button text for %s" % [view])
		t.ok(not game._end.disabled and game._end.visible, "root button pressable for %s" % [view])
	game._refresh_end(_v("shop", "prison", true))
	t.eq(game._end_title.text, CardText.ui("c01.btn.close_day.mode.prison"), "root shows prison label")
	var n := mock.sent.size()
	game._end.pressed.emit()
	await t.frames(1)
	t.ok(mock.sent.size() > n and mock.sent[n][0] == "day.end", "root press in prison still sends day.end")
	game.queue_free()
	await t.frames(2)
	# ④ street_prison 夹具
	var g2 := S.boot(self, bus, "street_prison")
	await t.frames(2)
	var m2: MockCardEngine = g2.engine
	t.eq(g2._end_title.text, CardText.ui("c01.btn.close_day.mode.prison"), "street_prison fixture shows the prison label on the root button")
	t.ok(not g2._end.disabled, "street_prison: root button enabled")
	var n2 := m2.sent.size()
	g2._end.pressed.emit()
	await t.frames(1)
	t.ok(m2.sent.size() > n2, "street_prison: press sent a command")
	if m2.sent.size() > n2:
		t.eq(m2.sent[n2], ["day.end", {"confirm": false}], "street_prison: still day.end confirm:false")
	g2.queue_free()
	await _root_advance(t, bus, "street", "c01.btn.close_day.mode.street")
	await _root_advance(t, bus, "sealed", "c01.btn.close_day.mode.sealed")
	await _root_game_over_label(t, bus)
	bus.queue_free()
	await t.frames(2)


func _root_advance(t, bus: CardEventBus, mode_name: String, label_key: String) -> void:
	var game := S.boot(self, bus, "", {"seed": 7, "guide": "off"})
	await t.frames(2)
	var mock: MockCardEngine = game.engine
	t.ok(mock._scn != null, mode_name + " live scenario")
	mock._scn.setup_day_full()
	mock._scn.st["mode"] = mode_name
	await _close_all(game)
	var view: Dictionary = game.engine.view()
	game._refresh_end(view)
	var step := str(mock.query(&"day.end_preview").get("step", "next_day"))
	var base := "c01.btn.close_day." + step
	t.eq(game._end_title.text, CardText.ui(label_key), mode_name + " root label")
	t.eq(game._end_title.text, CardText.ui(L.key_for(view, base)), mode_name + " root matches the live view")
	t.ok(not game._end.disabled and game._end.visible, mode_name + " root pressable")
	var before := _pos(view)
	var n := mock.sent.size()
	game._end.pressed.emit()
	await t.frames(1)
	t.ok(mock.sent.size() > n and str(mock.sent[n][0]) == "day.end", mode_name + " click sends day.end")
	if game.host.top_kind() == &"end_day":
		game.host.top_panel().autoplay_step()
		await t.frames(1)
		t.eq(mock.sent.back(), ["day.end", {"confirm": true}], mode_name + " confirms")
	t.ok(_pos(game.engine.view()) != before, mode_name + " advanced from " + before)
	game.queue_free()
	CardAnchors.clear()
	await t.frames(1)


func _root_game_over_label(t, bus: CardEventBus) -> void:
	var game := S.boot(self, bus, "", {"seed": 7, "guide": "off"})
	await t.frames(2)
	var mock: MockCardEngine = game.engine
	t.ok(mock._scn != null, "game_over live scenario")
	mock._scn.setup_day_full()
	mock._scn.st["phase"] = "game_over"
	mock._scn.st["mode"] = "street"
	await _close_all(game)
	var view: Dictionary = game.engine.view()
	game._refresh_end(view)
	var original := CardText.ui("c01.btn.close_day.game_over")
	t.eq(game._end_title.text, original, "game_over root keeps the original label")
	t.ok(game._end_title.text != CardText.ui("c01.btn.close_day.mode.street"), "game_over root is not the street label")
	t.ok(not game._end.disabled and game._end.visible, "game_over root still pressable")
	game.queue_free()
	CardAnchors.clear()
	await t.frames(1)


func _close_all(game: CardGameRoot) -> void:
	var guard := 0
	while game.host.top_panel() != null and guard < 8:
		guard += 1
		game.host.close_panel(game.host.top_panel())
		await process_frame


func _pos(v: Dictionary) -> String:
	return "%s/%d/%d" % [str(v.get("phase", "")), int(v.get("date", {}).get("stage", 0)), int(v.get("date", {}).get("abs_day", 0))]


func _global(name: String) -> bool:
	for row in ProjectSettings.get_global_class_list():
		if str(row.get("class", "")) == name: return true
	return false
