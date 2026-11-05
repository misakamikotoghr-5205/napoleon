# C08: the close-day list names each consequence, and only "confirm" sends day.end.
# Owner C08. Contract 1.3 section 7.4.7.
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const Support = preload("res://scripts/tests/cards/C08/support.gd")

const KINDS: Array = ["leave", "leave", "ignore", "gold_leave", "pass", "wait"]
const KEYS: Array = ["g02.end.leave", "ev.1938.police_check#outcomes.ignored", "g02.end.ignore",
	"p.brother.1938.farewell#outcomes.ignored", "g02.end.pass", "g01.end.wait"]


func _initialize() -> void:
	var t := T.new(self, "C08_end_day")
	t.run_async(_body.bind(t))


func _body(t) -> void:
	Support.leaks(t, ["end_day_items", "end_day_gold", "end_day_prison", "end_day_prison_fail"])
	var mounted: Array = Support.mount(self, "end_day_items")
	var bus: CardEventBus = mounted[0]
	var mock: MockCardEngine = mounted[1]
	var host: CardModalHost = mounted[2]
	await _list(t, host, mock)
	await _back_and_esc(t, host, mock)
	await _confirm(t, host, mock)
	await _override_and_junk(t, host, mock)
	await _autoplay_same(t, host, mock)
	mock.load_fixture(Support.fixture("end_day_gold"))
	await _gold(t, bus, host, mock)
	mock.load_fixture(Support.fixture("end_day_prison"))
	await _prison(t, host, mock, "stay", "night")
	mock.load_fixture(Support.fixture("end_day_prison_fail"))
	await _prison(t, host, mock, "fail", "game_over")
	host.queue_free()
	bus.queue_free()
	await t.frames(2)


func _list(t, host: CardModalHost, mock: MockCardEngine) -> void:
	mock.sent.clear()
	var panel := host.open_panel(&"end_day", {})
	await t.frames(2)
	t.eq(Support.cmds(mock, "day.end").size(), 0, "opening the list sends nothing")
	var sheet := Support.child(panel, "Sheet") as Panel
	# Reskin 10-22: the prototype's dark .modal is narrower (760) and only as tall as the list needs;
	# it is centred on the screen, not in the host's overlay box (the old 1040x620 paper sat 90 px right).
	t.eq(sheet.custom_minimum_size.x, CardEndDayConfirm.SHEET.x, "confirm sheet width")
	t.ok(sheet.custom_minimum_size.x <= 1100 and sheet.custom_minimum_size.y <= 640, "sheet within 1100x640")
	var on_screen := sheet.get_global_rect()
	t.ok(absf(on_screen.get_center().x - 640.0) <= 1.0 and absf(on_screen.get_center().y - 360.0) <= 1.0,
		"sheet centred on screen %s" % on_screen)
	t.ok(Rect2(0, 0, 1280, 720).encloses(on_screen), "sheet on screen")
	var buttons := Support.child(panel, "BtnConfirm") as Button
	t.ok(on_screen.encloses(buttons.get_global_rect()), "confirm button inside the sheet")
	t.eq(buttons.theme_type_variation, &"PrimaryButton", "confirm is the gold primary button")
	var rows := panel.find_children("EndRow*", "", true, false)
	t.eq(rows.size(), KINDS.size(), "one row per kind")
	for i in range(rows.size()):
		var row := rows[i]
		t.eq(str(row.get_meta("kind")), str(KINDS[i]), "kind " + str(i))
		var args := {"days": 2} if str(KEYS[i]) == "g01.end.wait" else {}
		var lab := row.find_child("Consequence", true, false) as Label
		t.eq(lab.text, CardText.t(str(KEYS[i]), args), "consequence " + str(i))
		if str(KINDS[i]) == "wait":
			# Dark sheet now (reskin): the "not a loss" row is the dim --text-2 ink instead of ink_soft on paper.
			t.eq(lab.get_theme_color(&"font_color"), CardTheme.color(&"text_2"), "wait is soft")
			t.eq((row.find_child("WaitNote", true, false) as Label).text, CardText.ui("c08.end.wait"), "wait note")
		if str(KINDS[i]) == "gold_leave":
			t.eq((row.find_child("GoldNote", true, false) as Label).text, CardText.ui("c08.gold.reminder"), "gold note")
			var card := row.find_child("Mini*", true, false) as CardWidget
			t.eq(card.custom_minimum_size, Vector2(72, 100), "gold mini")
			t.ok(Support.gold_frame(card), "gold frame")
	t.ok(t.anchor_ok(&"a.endday.blocked"), "list anchor")
	t.ok(t.anchor_ok(&"a.endday.gold_leave"), "gold row anchor")
	var bad: PackedStringArray = t.all_text_from_cardtext(panel)
	t.ok(bad.is_empty(), "list text from CardText: %s" % ", ".join(bad))
	var got: Array = [null]
	panel.close_requested.connect(func(r: Dictionary) -> void: got[0] = r)
	var mini := Support.child(panel, "Mini2") as CardWidget
	mini.pressed.emit(mini.get_uid())
	t.eq(got[0], {"open_uid": "c0102"}, "click opens that card")
	t.eq(Support.cmds(mock, "day.end").size(), 0, "click sends nothing")


func _back_and_esc(t, host: CardModalHost, mock: MockCardEngine) -> void:
	mock.sent.clear()
	var panel := host.open_panel(&"end_day", {})
	await t.frames(1)
	var got: Array = [null]
	panel.close_requested.connect(func(r: Dictionary) -> void: got[0] = r)
	(Support.child(panel, "BtnBack") as Button).pressed.emit()
	t.eq(got[0], {}, "back just closes")
	t.eq(Support.cmds(mock, "day.end").size(), 0, "back sends nothing")
	var again := host.open_panel(&"end_day", {})
	await t.frames(1)
	var esc_got: Array = [null]
	again.close_requested.connect(func(r: Dictionary) -> void: esc_got[0] = r)
	await Support.tap(self, KEY_ESCAPE)
	t.eq(esc_got[0], {}, "esc just closes")
	t.eq(Support.cmds(mock, "day.end").size(), 0, "esc sends nothing")


func _confirm(t, host: CardModalHost, mock: MockCardEngine) -> void:
	mock.load_fixture(Support.fixture("end_day_items"))
	mock.sent.clear()
	var panel := host.open_panel(&"end_day", {})
	await t.frames(1)
	var got: Array = [null]
	panel.close_requested.connect(func(r: Dictionary) -> void: got[0] = r)
	(Support.child(panel, "BtnConfirm") as Button).pressed.emit()
	(Support.child(panel, "BtnConfirm") as Button).pressed.emit()
	t.eq(Support.cmds(mock, "day.end").size(), 1, "confirm sends one day.end")
	t.eq(Support.cmds(mock, "day.end")[0][1], {"confirm": true}, "confirm flag")
	t.eq(got[0], {}, "panel closes after the day ends")
	t.eq(str(mock.view().get("phase", "")), "night", "engine moved to night")


func _override_and_junk(t, host: CardModalHost, mock: MockCardEngine) -> void:
	mock.sent.clear()
	var one := {"uid": "c0301", "def": "nw.1938.wangshan_dock", "kind": "pass",
		"consequence_key": "g02.end.pass", "args": {}}
	var panel := host.open_panel(&"end_day", {"items": [one]})
	await t.frames(1)
	t.eq(panel.find_children("EndRow*", "", true, false).size(), 1, "args items replace the preview")
	var stray := host.open_panel(&"end_day", {"uid": "c0002"})
	await t.frames(1)
	t.ok(stray.autoplay_step(), "stray uid still confirms")
	t.eq(Support.cmds(mock, "day.end")[-1][1], {"confirm": true}, "stray uid sends confirm")
	mock.sent.clear()
	var blank := host.open_panel(&"end_day", {"items": []})
	t.eq(blank.find_children("EndRow*", "", true, false).size(), 0, "empty items")
	t.ok(blank.autoplay_step(), "empty items still confirm")
	mock.sent.clear()
	var junk := host.open_panel(&"end_day", {"items": "c0101"})
	t.eq(junk.autoplay_step(), true, "bad arg types do not error")
	t.eq(Support.cmds(mock, "day.end").size(), 1, "bad args still confirm once")
	var bad: PackedStringArray = t.all_text_from_cardtext(blank)
	t.ok(bad.is_empty(), "empty confirm text from CardText: %s" % ", ".join(bad))


func _autoplay_same(t, host: CardModalHost, mock: MockCardEngine) -> void:
	mock.load_fixture(Support.fixture("end_day_items"))
	var first := _play(host, mock)
	mock.load_fixture(Support.fixture("end_day_items"))
	var second := _play(host, mock)
	t.eq(first, second, "end-day autoplay repeats")
	t.eq(first, [{"confirm": true}], "autoplay confirms the day")


func _play(host: CardModalHost, mock: MockCardEngine) -> Array:
	mock.sent.clear()
	var panel := host.open_panel(&"end_day", {})
	var stepped := panel.autoplay_step()
	if not stepped or Support.cmds(mock, "day.end").is_empty():
		return []
	return [Support.cmds(mock, "day.end")[0][1]]


func _gold(t, bus: CardEventBus, host: CardModalHost, mock: MockCardEngine) -> void:
	mock.sent.clear()
	var spy = t.spy(bus)
	var panel := host.open_panel(&"end_day", {})
	await t.frames(2)
	t.eq(Support.cmds(mock, "day.end").size(), 0, "opening gold confirm does not send day.end")
	var card := Support.child(panel, "Mini0") as CardWidget
	t.eq(card.custom_minimum_size, Vector2(72, 100), "gold card is mini")
	t.ok(Support.gold_frame(card), "gold-only frame")
	t.ok(t.anchor_ok(&"a.endday.gold_leave"), "gold-only anchor")
	var bad: PackedStringArray = t.all_text_from_cardtext(panel)
	t.ok(bad.is_empty(), "gold text from CardText: %s" % ", ".join(bad))
	var got: Array = [null]
	panel.close_requested.connect(func(r: Dictionary) -> void: got[0] = r)
	card.pressed.emit(card.get_uid())
	t.eq(got[0], {"open_uid": "c0201"}, "gold row opens the card")
	t.eq(Support.cmds(mock, "day.end").size(), 0, "opening the gold card sends nothing")
	var again := host.open_panel(&"end_day", {})
	await t.frames(1)
	(Support.child(again, "BtnConfirm") as Button).pressed.emit()
	t.eq(Support.cmds(mock, "day.end").size(), 1, "gold confirm sends one day.end")
	t.eq(Support.cmds(mock, "day.end")[0][1], {"confirm": true}, "gold confirm flag")
	t.eq(str(mock.view().get("phase", "")), "night", "gold confirm moves to night")
	var left := false
	for row in spy.log:
		if row[0] == &"card_left" and str(row[1]) == "c0201" and str(row[2]) == "gold_left":
			left = true
	t.ok(left, "card_left gold_left")


func _prison(t, host: CardModalHost, mock: MockCardEngine, kind: String, phase: String) -> void:
	mock.sent.clear()
	var panel := host.open_panel(&"end_day", {})
	await t.frames(1)
	var row := Support.child(panel, "EndRow0")
	t.eq(str(row.get_meta("kind")), kind, kind + " row")
	var key := "g06.end." + kind
	var args: Dictionary = {"max": 3, "nights": 1 if kind == "stay" else 3}
	t.eq((row.find_child("Consequence", true, false) as Label).text, CardText.t(key, args), kind + " text")
	(Support.child(panel, "BtnConfirm") as Button).pressed.emit()
	t.eq(Support.cmds(mock, "day.end").size(), 1, kind + " confirms once")
	t.eq(Support.cmds(mock, "day.end")[0][1], {"confirm": true}, kind + " flag")
	t.eq(str(mock.view().get("phase", "")), phase, kind + " phase")
