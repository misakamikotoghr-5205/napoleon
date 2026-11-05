# C09 year jump: one line per page, year.next once, section anchors.
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const S = preload("res://scripts/tests/cards/C09/c09_support.gd")
const SCENE := "res://scenes/cards/month/YearJump.tscn"
const FX := "res://scripts/tests/cards/C09/fixtures/year_jump_sections.json"


func _initialize() -> void:
	var t := T.new(self, "C09_year_jump")
	t.run_async(_body.bind(t))


func _body(t) -> void:
	var pack := S.mount(self, FX)
	var mock: MockCardEngine = pack["mock"]
	var p := S.open_panel(self, pack, SCENE)
	p.open({"uid": "c0002"})
	await t.frames(1)
	var lines: Array = mock.query(&"year_report", {}).get("lines", [])
	t.no_leaks(mock.view(), "year view")
	t.no_leaks(mock.query(&"year_report", {}), "year report")
	var n := lines.size()
	t.ok(n >= 5, "section fixture has a row for every group")
	var body := p.find_child("YearBody", true, false)
	var page := p.find_child("Page", true, false) as Label
	t.eq(page.text, CardText.ui("c09.year.page", {"i": 1, "n": n}), "first page indicator")
	t.eq(str(body.get_meta("section")), "forfeit", "opens on forfeit")
	t.ok(S.blob(p).contains(CardText.ui(str(lines[0]["key"]), lines[0]["args"])), "first line text")
	t.ok(t.anchor_ok(&"a.year.forfeit"), "forfeit anchor %s" % CardAnchors.rect(&"a.year.forfeit"))
	t.ok(not CardAnchors.has(&"a.year.after"), "after anchor is hidden on the forfeit page")
	S.tap(p, KEY_ENTER)
	t.eq(str(body.get_meta("section")), "forfeit", "second forfeit row")
	t.eq(page.text, CardText.ui("c09.year.page", {"i": 2, "n": n}), "second page indicator")
	S.tap(p, KEY_SPACE)
	t.eq(str(body.get_meta("section")), "after", "after page")
	await t.frames(1)
	t.ok(t.anchor_ok(&"a.year.after"), "after anchor %s" % CardAnchors.rect(&"a.year.after"))
	t.ok(not CardAnchors.has(&"a.year.forfeit"), "forfeit anchor is hidden on the after page")
	t.ok(S.blob(p).contains(CardText.ui(str(lines[2]["key"]), lines[2]["args"])), "after line text")
	for _i in range(n - 1 - 2):
		S.tap(p, KEY_SPACE)
	t.eq(S.count_cmd(mock, "year.next"), 0, "the last page is still waiting")
	t.eq(str(body.get_meta("section")), "faces", "ends on the faces group")
	S.tap(p, KEY_SPACE)
	t.eq(S.count_cmd(mock, "year.next"), 1, "year.next once after the last page")
	S.tap(p, KEY_SPACE)
	t.eq(S.count_cmd(mock, "year.next"), 1, "year.next does not repeat")
	t.ok(t.all_text_from_cardtext(p).is_empty(), "text from CardText: %s" % ", ".join(t.all_text_from_cardtext(p)))
	t.ok(not S.has_percent(p), "no percent sign")
	_autoplay(t)
	await _plain(t)
	_escape(t)
	t.finish()


func _autoplay(t) -> void:
	var a := S.mount(self, FX)
	var b := S.mount(self, FX)
	var pa := S.open_panel(self, a, SCENE)
	var pb := S.open_panel(self, b, SCENE)
	var na := S.drain(pa)
	var nb := S.drain(pb)
	t.eq(na, nb, "autoplay length is stable")
	t.eq(a["mock"].sent, b["mock"].sent, "autoplay commands match")
	t.eq(S.count_cmd(a["mock"], "year.next"), 1, "autoplay sends year.next once")
	t.ok(not pa.autoplay_step(), "autoplay stops")


func _plain(t) -> void:
	var pack := S.mount(self, "year_jump")
	var mock: MockCardEngine = pack["mock"]
	var lines: Array = mock.query(&"year_report", {}).get("lines", [])
	var p := S.open_panel(self, pack, SCENE)
	await t.frames(1)
	t.ok(not CardAnchors.has(&"a.year.forfeit"), "rows without section do not take the forfeit anchor")
	t.ok(not CardAnchors.has(&"a.year.after"), "rows without section do not take the after anchor")
	var guard := 0
	while S.count_cmd(mock, "year.next") == 0 and guard < 12:
		S.tap(p, KEY_SPACE)
		guard += 1
	t.eq(guard, lines.size(), "one key per line when there is no section")
	t.eq(S.count_cmd(mock, "year.next"), 1, "plain year report still sends year.next once")
	t.ok(t.all_text_from_cardtext(p).is_empty(), "plain year text")
	t.ok(not S.has_percent(p), "plain year has no percent")


func _escape(t) -> void:
	var pack := S.mount(self, FX)
	var p := S.open_panel(self, pack, SCENE)
	var result := [{"missing": true}]
	p.close_requested.connect(func(r: Dictionary) -> void: result[0] = r)
	p.dismiss()
	t.eq(result[0], {}, "dismiss closes the year jump")
	t.eq(S.count_cmd(pack["mock"], "year.next"), 0, "dismiss does not send year.next")
	var pack2 := S.mount(self, FX)
	var p2 := S.open_panel(self, pack2, SCENE)
	var escaped := [{"missing": true}]
	p2.close_requested.connect(func(r: Dictionary) -> void: escaped[0] = r)
	S.tap(p2, KEY_ESCAPE)
	t.eq(escaped[0], {}, "escape closes the year jump")
	t.eq(S.count_cmd(pack2["mock"], "year.next"), 0, "escape does not send year.next")
