# C01 打烊按钮：要确认就开 end_day，局终开局终面板，抽屉先收回，演出开着也往前走。
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const S = preload("res://scripts/tests/cards/C01/support.gd")
const OWN := "res://scripts/tests/cards/C01/fixtures/"
const BASE: Array[String] = ["month_open", "month_wheel", "morning", "day_full", "day_counter", "night", "settle",
	"month_close", "year_jump", "street_prison"]


func _initialize() -> void:
	var t := T.new(self, "C01_next_day")
	t.run_async(_body.bind(t))


func _body(t) -> void:
	var bus := CardEventBus.new()
	root.add_child(bus)
	for fx in BASE:
		await _button(t, bus, fx, true)
	for f in DirAccess.get_files_at(OWN):
		if f.ends_with(".json"):
			await _button(t, bus, OWN + f, false)
	await _drawer_first(t, bus)
	await _play_still_goes(t, bus)
	await _game_over(t, bus)
	await _night_band(t, bus)
	await _night_band_week(t, bus)
	await _every_panel(t, bus)
	await _abort_button(t, bus)
	await _no_reopen(t, bus)
	await _walk(t, bus)
	bus.queue_free()
	await t.frames(1)


func _button(t, bus: CardEventBus, fixture: String, expect_move: bool) -> void:
	var game := S.boot(self, bus, fixture)
	await t.frames(2)
	await _close_all(game)
	var mock: MockCardEngine = game.engine
	var preview: Dictionary = mock.query(&"day.end_preview")
	var before := _pos(mock.view())
	game._on_close_day()
	await t.frames(1)
	t.eq(mock.sent.back(), ["day.end", {"confirm": false}], "%s asks with confirm false" % fixture)
	if bool(preview.get("needs_confirm", false)):
		t.eq(game.host.top_kind(), &"end_day", "%s opens the confirm panel" % fixture)
		t.eq(_pos(mock.view()), before, "%s stays until confirm" % fixture)
		if game.host.top_kind() == &"end_day":
			game.host.top_panel().autoplay_step()
			await t.frames(1)
			t.eq(mock.sent.back(), ["day.end", {"confirm": true}], "%s confirms" % fixture)
	if expect_move:
		t.ok(_pos(mock.view()) != before, "%s moved from %s" % [fixture, before])
	game.queue_free()
	CardAnchors.clear()
	await t.frames(1)


func _drawer_first(t, bus: CardEventBus) -> void:
	var game := S.boot(self, bus, "day_full")
	await t.frames(2)
	await _close_all(game)
	var mock: MockCardEngine = game.engine
	var n := mock.sent.size()
	game.host.open_panel(&"shelf", {})
	game._on_close_day()
	await t.frames(1)
	t.ok(not game.host.drawer_open(), "the button closes the drawer first")
	# b25（合同 §7.11.11：按下先收回抽屉再走）：同一下就接着打烊，不用再按第二下（旧断言“收抽屉不打烊”就是 b25）。
	t.eq(mock.sent.size(), n + 1, "the same press then ends the day")
	t.eq(mock.sent.back(), ["day.end", {"confirm": false}], "after the drawer it asks day.end with confirm false")
	game.queue_free()
	CardAnchors.clear()
	await t.frames(1)


func _play_still_goes(t, bus: CardEventBus) -> void:
	var game := S.boot(self, bus, "day_full")
	await t.frames(2)
	await _close_all(game)
	var uid := str(game.engine.view()["hand"][0].get("uid", ""))
	game.host.open_panel(&"counter", {"uid": uid})
	var mock: MockCardEngine = game.engine
	game._on_close_day()
	await t.frames(1)
	t.eq(mock.sent.back(), ["day.end", {"confirm": false}], "a play does not block the button")
	t.eq(game.host.top_kind(), &"end_day", "confirm panel covers the play")
	game.queue_free()
	CardAnchors.clear()
	await t.frames(1)


func _game_over(t, bus: CardEventBus) -> void:
	var game := S.boot(self, bus, "", {"seed": 7, "guide": "off"})
	await t.frames(2)
	await _close_all(game)
	var mock: MockCardEngine = game.engine
	mock._scn.st["phase"] = "game_over"
	game._sync_phase_panel()
	await t.frames(1)
	t.eq(game.host.top_kind(), &"game_over", "game over opens once")
	await _close_all(game)
	var n := mock.sent.size()
	game._on_close_day()
	await t.frames(1)
	t.eq(mock.sent.size(), n, "game over does not send day.end")
	t.eq(game.host.top_kind(), &"game_over", "the button opens game over")
	game.host.close_top()
	await t.frames(1)
	t.ok(game.host.top_panel() == null, "game over closes")
	game.queue_free()
	CardAnchors.clear()
	await t.frames(1)


## 验收 1：夜里按“睡了 · 到天亮”（day.end，night 面板还开着）——夜牌面板要自己收走，日结照开，
## 夜里那句“这一夜没什么能做的”不留到天亮，第二天的手牌照样能打（以前 NightPanel 一直压着，吞掉出牌）。
func _night_band(t, bus: CardEventBus) -> void:
	var game := S.boot(self, bus, "night")
	await t.frames(3)
	t.eq(game.host.top_kind(), &"night", "night fixture opens the night panel")
	var mock: MockCardEngine = game.engine
	game._on_close_day()
	await t.frames(3)
	t.eq(mock.sent.back(), ["day.end", {"confirm": false}], "the night band sends day.end")
	t.eq(str(mock.view().get("phase", "")), "settle", "the band at night moves on to settle")
	t.ok(not game.host.is_open(&"night"), "the night panel closes once the night is over")
	t.eq(game.host.top_kind(), &"settle", "settle opens after the band at night")
	game.queue_free()
	CardAnchors.clear()
	await t.frames(1)


## 同一件事走真引擎到第 7 天夜里：按钮睡觉以后，周末盘账叠层要开出来（以前被夜牌面板挡住，报价悄悄过期）。
func _night_band_week(t, bus: CardEventBus) -> void:
	var game := S.boot(self, bus, "", {"mock": false, "seed": 7, "guide": "off", "save_dir": t.user_dir() + "/band"})
	await t.frames(2)
	var eng = game.engine
	game.host.close_all()
	eng.send(&"wheel.spin", {"wheel": "wh.month", "uid": ""})
	eng.send(&"month.begin", {})
	for _day in range(1, 7):
		eng.send(&"day.begin", {})
		eng.send(&"day.end", {"confirm": true})
		eng.send(&"night.choose", {"def": ""})
		eng.send(&"settle.next", {})
		await t.frames(1)
		game.host.close_all()
	eng.send(&"day.begin", {})
	await t.frames(1)
	game.host.close_all()
	eng.send(&"day.end", {"confirm": true})
	await t.frames(3)
	t.eq(int(eng.view().get("date", {}).get("stage_day", 0)), 7, "real walk reached day 7")
	t.eq(game.host.top_kind(), &"night", "day 7 night panel is up")
	game._on_close_day()
	await t.frames(3)
	t.eq(str(eng.view().get("phase", "")), "settle", "day 7 band moves on to settle")
	t.ok(not game.host.is_open(&"night"), "day 7 night panel closes")
	t.eq(game.host.top_kind(), &"stocktake", "the weekly stocktake opens after the band at night")
	# 第二天：夜里那句“这一夜没什么能做的”不能留在对话框里，也不能有夜牌面板吞掉出牌。
	if game.host.top_kind() == &"stocktake":
		game.host.close_top()
	await t.frames(2)
	eng.send(&"settle.next", {})
	eng.send(&"day.begin", {})
	await t.frames(3)
	t.eq(str(eng.view().get("phase", "")), "day", "day 8 opened")
	t.ok(not game.host.is_open(&"night"), "no night panel on day 8")
	var said := ""
	for line in game.dialog.get("_lines"):
		said += str(line.get("ref", "")) + " "
	t.ok(not said.contains("c08.night.skip"), "day 8: the night skip line does not linger: %s" % said)
	game.queue_free()
	CardAnchors.clear()
	await t.frames(1)


func _every_panel(t, bus: CardEventBus) -> void:
	var game := S.boot(self, bus, "day_full")
	await t.frames(2)
	await _close_all(game)
	var mock: MockCardEngine = game.engine
	var want := {&"counter": "counter.close", &"kept_full": "card.discard", &"contacts_full": "contact.release",
		&"short": "short.resolve"}
	for kind in CardIds.PANELS:
		if kind == &"minigame":
			continue
		var n := mock.sent.size()
		game.host.open_panel(kind, {"uid": "c0005", "new_uid": "c0010", "source": "c0005"})
		await t.frames(1)
		game.host.close_top()
		await t.frames(1)
		t.ok(game.host.top_panel() == null, "%s Esc returns to the table" % kind)
		if want.has(kind):
			t.eq(str(mock.sent.back()[0]) if mock.sent.size() > n else "", want[kind], "%s sends its default" % kind)
		else:
			t.eq(mock.sent.size(), n, "%s sends nothing" % kind)
		await _close_all(game)
	game.queue_free()
	CardAnchors.clear()
	await t.frames(1)


func _abort_button(t, bus: CardEventBus) -> void:
	var game := S.boot(self, bus, "day_counter")
	await t.frames(2)
	(game.engine as MockCardEngine).send(&"mg.request", {"uid": "c0002", "item": "I001"})
	await t.frames(1)
	var button := game.mg_host.get_node("Abort") as Button
	t.ok(button.visible, "abort button is visible")
	button.pressed.emit()
	await t.frames(2)
	var report := {}
	var mock: MockCardEngine = game.engine
	for i in range(mock.sent.size() - 1, -1, -1):
		if str(mock.sent[i][0]) == "mg.report":
			report = mock.sent[i][1]
			break
	t.eq(bool(report.get("result", {}).get("aborted", false)), true, "abort button reports aborted")
	t.ok(not game.mg_host.is_active(), "abort clears the minigame")
	game.queue_free()
	CardAnchors.clear()
	await t.frames(1)


func _no_reopen(t, bus: CardEventBus) -> void:
	var game := S.boot(self, bus, "month_open")
	await t.frames(2)
	t.eq(game.host.top_kind(), &"month_open", "month open appears once")
	game.host.close_panel(game.host.top_panel())
	await t.frames(2)
	var after := game.host.top_kind()
	game._sync_phase_panel()
	await t.frames(1)
	t.ok(game.host.top_kind() != &"month_open", "month open does not come back")
	t.eq(game.host.top_kind(), after, "a second sync adds nothing")
	game.queue_free()
	CardAnchors.clear()
	await t.frames(1)


func _walk(t, bus: CardEventBus) -> void:
	var game := S.boot(self, bus, "", {"seed": 7, "guide": "off"})
	await t.frames(2)
	var guard := 0
	while guard < 500:
		guard += 1
		var view: Dictionary = game.engine.view()
		if int(view.get("date", {}).get("stage", 0)) >= 1 and str(view.get("phase", "")) == "morning":
			break
		if game.host.top_kind() == &"end_day":
			game.host.top_panel().autoplay_step()
		else:
			game._on_close_day()
		await t.frames(1)
	var done: Dictionary = game.engine.view()
	t.eq(str(done.get("phase", "")), "morning", "button walk reached morning (%d)" % guard)
	t.ok(int(done.get("date", {}).get("stage", 0)) >= 1, "button walk reached the next stage")
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
	return "%s/%d/%d" % [v.get("phase", ""), int(v.get("date", {}).get("stage", 0)), int(v.get("date", {}).get("abs_day", 0))]
