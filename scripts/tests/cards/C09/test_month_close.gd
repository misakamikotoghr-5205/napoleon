# C09 month close: report lines, goal results, month.next.
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const S = preload("res://scripts/tests/cards/C09/c09_support.gd")
const SCENE := "res://scenes/cards/month/MonthClose.tscn"
const FX := "res://scripts/tests/cards/C09/fixtures/month_close_goals.json"


func _initialize() -> void:
	var t := T.new(self, "C09_month_close")
	t.run_async(_body.bind(t))


func _body(t) -> void:
	var pack := S.mount(self, FX)
	var mock: MockCardEngine = pack["mock"]
	var p := S.open_panel(self, pack, SCENE)
	p.open({"uid": "c0002", "extra": 1})
	p.refresh(mock.view())
	await t.frames(1)
	var rep: Dictionary = mock.query(&"month_report", {})
	t.no_leaks(mock.view(), "month close view")
	t.no_leaks(rep, "month report")
	var shown := S.blob(p)
	for line in rep.get("lines", []):
		var key := str(line.get("key", ""))
		var args = line.get("args", {})
		if typeof(args) != TYPE_DICTIONARY:
			args = {}
		var expect := CardText.ui(key, args)
		t.ok(shown.contains(expect), "report line shown: " + key)
	var main := _row(p, "gl.1938.keep_shop")
	var opt := _row(p, "gl.fx.one")
	t.ok(main != null and opt != null, "both goals are listed")
	var main_txt := S.blob(main)
	var opt_txt := S.blob(opt)
	t.ok(main_txt.contains(CardText.ui("c09.goals.done")), "main goal reads done")
	t.ok(not main_txt.contains(CardText.ui("c09.goals.failed")), "main goal does not read failed")
	t.ok(main_txt.contains(CardText.ui("c09.goals.main")), "main goal is marked")
	t.ok(main_txt.contains(CardText.t("gl.1938.keep_shop#title")), "main title from CardText")
	t.ok(main_txt.contains(CardText.t("gl.1938.keep_shop#done")), "main result copy")
	t.ok(opt_txt.contains(CardText.ui("c09.goals.failed")), "optional goal reads failed")
	t.ok(not opt_txt.contains(CardText.ui("c09.goals.done")), "optional goal does not read done")
	t.ok(not opt_txt.contains(CardText.ui("c09.goals.main")), "optional goal is not marked main")
	t.ok(opt_txt.contains(CardText.t("gl.fx.one#failed")), "optional failed copy")
	t.ok(not opt_txt.contains(CardText.t("gl.fx.one#done")), "optional done copy stays off")
	t.ok(t.anchor_ok(&"a.mclose.accounts"), "accounts anchor %s" % CardAnchors.rect(&"a.mclose.accounts"))
	t.ok(t.all_text_from_cardtext(p).is_empty(), "text from CardText: %s" % ", ".join(t.all_text_from_cardtext(p)))
	t.ok(not S.has_percent(p), "no percent sign")
	var got := [{"missing": true}]
	p.close_requested.connect(func(r: Dictionary) -> void: got[0] = r)
	(p.find_child("NextMonth", true, false) as Button).pressed.emit()
	t.eq(S.count_cmd(mock, "month.next"), 1, "next month sends month.next")
	t.eq(mock.sent.filter(func(row: Array) -> bool: return row[0] == "month.next")[0][1], {}, "month.next args")
	t.eq(got[0], {}, "panel closes after month.next")
	(p.find_child("NextMonth", true, false) as Button).pressed.emit()
	t.eq(S.count_cmd(mock, "month.next"), 1, "month.next is sent once")
	var pack2 := S.mount(self, FX)
	var p2 := S.open_panel(self, pack2, SCENE)
	t.eq(S.drain(p2), 1, "autoplay finishes in one step")
	t.eq(S.count_cmd(pack2["mock"], "month.next"), 1, "autoplay sends month.next once")
	t.ok(not p2.autoplay_step(), "autoplay stops")
	var pack3 := S.mount(self, FX)
	var p3 := S.open_panel(self, pack3, SCENE)
	var dismissed := [false]
	p3.close_requested.connect(func(_r: Dictionary) -> void: dismissed[0] = true)
	S.tap(p3, KEY_ESCAPE)
	t.ok(dismissed[0], "escape closes the ledger")
	t.eq(S.count_cmd(pack3["mock"], "month.next"), 0, "escape does not send month.next")
	await _w0(t)
	await _long_month(t)


func _row(panel: Node, id: String) -> Node:
	var box := panel.find_child("Goals", true, false)
	for c in box.get_children():
		if str(c.get_meta("goal_id", "")) == id:
			return c
	return null


func _w0(t) -> void:
	var pack := S.mount(self, "month_close")
	var p := S.open_panel(self, pack, SCENE)
	p.refresh(pack["mock"].view())
	await t.frames(1)
	t.ok(t.all_text_from_cardtext(p).is_empty(), "W0 month_close text")
	t.ok(not S.has_percent(p), "W0 month_close has no percent")
	t.eq(S.drain(p), 1, "W0 fixture autoplay")
	t.eq(S.count_cmd(pack["mock"], "month.next"), 1, "W0 fixture month.next")


## b01: at a real month end (9 report lines, several goals) the ledger used to grow past y 720 and push
## "next month" off screen. The rows now scroll inside a fixed box; the button stays on screen and clickable.
func _long_month(t) -> void:
	var bus := CardEventBus.new()
	root.add_child(bus)
	var mock := LongMonth.new(bus)
	mock.load_fixture(FX)
	var p: CardPanel = load(SCENE).instantiate()
	p.bind(mock, bus)
	root.add_child(p)
	p.open({})
	await t.frames(3)
	var btn := p.find_child("NextMonth", true, false) as Button
	var r := btn.get_global_rect()
	t.ok(Rect2(0, 0, 1280, 720).encloses(r), "next month on screen with a long report %s" % r)
	var box := (p.find_child("Box", true, false) as Control).get_global_rect()
	t.ok(box.size.y <= 640.0 and Rect2(0, 0, 1280, 720).encloses(box), "ledger box clamped %s" % box)
	t.ok(box.encloses(r), "next month inside the ledger")
	var scroll := p.find_child("Scroll", true, false) as ScrollContainer
	t.ok(scroll != null and scroll.get_v_scroll_bar().max_value > scroll.size.y, "long report scrolls")
	var shown := S.blob(p)
	for line in mock.lines:
		t.ok(shown.contains(CardText.ui(str(line["key"]), line["args"])), "line listed " + str(line["key"]))
	t.ok(t.anchor_ok(&"a.mclose.accounts"), "accounts anchor on screen %s" % CardAnchors.rect(&"a.mclose.accounts"))
	var ev := InputEventMouseMotion.new()
	ev.position = r.get_center()
	root.push_input(ev, true)
	await t.frames(1)
	t.eq(root.gui_get_hovered_control(), btn, "the mouse reaches next month")
	btn.pressed.emit()
	t.eq(S.count_cmd(mock, "month.next"), 1, "next month works")
	p.queue_free()
	bus.queue_free()
	await t.frames(2)


class LongMonth extends MockCardEngine:
	var lines: Array = [
		{"key": "g04.month.expenses", "args": {"money": 30}},
		{"key": "g04.month.tickets", "args": {"n": 1}},
		{"key": "g06.month.interest", "args": {"money": 4}},
		{"key": "g06.month.interest", "args": {"money": 6}},
		{"key": "g06.month.interest", "args": {"money": 7}},
		{"key": "g02.month.goal.done", "args": {}},
		{"key": "g02.month.goal.failed", "args": {}},
		{"key": "g02.month.goal.failed", "args": {}},
		{"key": "g02.month.verdict.1", "args": {}},
	]

	func query(q: StringName, args: Dictionary = {}) -> Dictionary:
		if q == &"month_report":
			return {"lines": lines.duplicate(true)}
		return super.query(q, args)

	func view() -> Dictionary:
		var v := super.view()
		var goals: Array = (v.get("goals", []) as Array).duplicate(true)
		goals.append({"id": "gl.fx.one", "main": false, "status": "failed"})
		goals.append({"id": "gl.1938.keep_shop", "main": false, "status": "done"})
		v["goals"] = goals
		return v
