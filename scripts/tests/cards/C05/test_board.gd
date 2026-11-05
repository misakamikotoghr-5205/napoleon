# C05：三张条子、到期变色、点行、天数、锚点、夹具不漏隐藏键。
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const S = preload("res://scripts/tests/cards/C05/support.gd")

const FIXTURES: Array[String] = ["board_three.json", "money.json", "goods.json", "people.json", "info.json",
	"delay.json", "fail.json", "people_return.json"]


func _initialize() -> void:
	var t := T.new(self, "C05_board")
	t.run_async(_body.bind(t))


func _body(t) -> void:
	for name in FIXTURES:
		var bad := S.leak_paths(S.load_doc(name))
		t.ok(bad.is_empty(), "%s leaks %s" % [name, ", ".join(bad)])
	var bus := CardEventBus.new()
	root.add_child(bus)
	var eng := S.engine(bus, "board_three.json")
	var board := S.mount_board(self)
	board.refresh(eng.view())
	await t.frames(2)
	var list := board.get_node("Scroll/List")
	t.eq(list.get_child_count(), 3, "three rows")
	var expect := {"b1": 6, "b2": 1, "b3": 4}
	for uid in expect.keys():
		var row := list.get_node("Row_" + uid) as Button
		var lab := row.get_node("Days") as Label
		var n := int(expect[uid])
		t.ok(lab.text == str(n) or lab.text.contains(str(n)), "days %s = %s" % [uid, lab.text])
		var want := CardTheme.color(&"danger" if uid == "b2" else &"ink")
		t.ok(lab.get_theme_color("font_color") == want, "color %s" % uid)
	# b44: "还剩 n 天" is never cut to "还剩 n": the label is at least as wide as its text.
	for uid in expect.keys():
		var dl := list.get_node("Row_" + uid + "/Days") as Label
		var f := dl.get_theme_font("font")
		var need := f.get_string_size(dl.text, HORIZONTAL_ALIGNMENT_LEFT, -1, dl.get_theme_font_size("font_size")).x
		t.ok(dl.size.x >= need, "b44 days %s fits (%d >= %d)" % [uid, dl.size.x, need])
	var tier := list.get_node("Row_b1/Tier") as Label
	t.eq(tier.text, CardText.ui("c05.tier.0"), "tier 0")
	var hit := {"uid": ""}
	board.demand_pressed.connect(func(u: String) -> void: hit["uid"] = u)
	(list.get_node("Row_b2") as Button).pressed.emit()
	t.eq(str(hit["uid"]), "b2", "pressed b2")
	t.ok(t.anchor_ok(&"a.demand.board"), "board %s" % CardAnchors.rect(&"a.demand.board"))
	t.ok(t.anchor_ok(&"a.demand.days"), "days %s" % CardAnchors.rect(&"a.demand.days"))
	t.ok(t.anchor_ok(&"a.demand.tier"), "tier %s" % CardAnchors.rect(&"a.demand.tier"))
	var shown: PackedStringArray = t.all_text_from_cardtext(board)
	t.ok(shown.is_empty(), "text " + " | ".join(shown))
	var pct := S.percent_text(board)
	t.ok(pct.is_empty(), "percent " + " | ".join(pct))
	var scroll := board.get_node("Scroll") as ScrollContainer
	t.ok(not _overflow(scroll), "three rows fit")
	var view := eng.view()
	var extra: Array = (view["demands"] as Array).duplicate(true)
	var fourth: Dictionary = (extra[0] as Dictionary).duplicate(true)
	fourth["uid"] = "b4"
	fourth["days_left"] = 3
	extra.append(fourth)
	view["demands"] = extra
	board.refresh(view)
	await t.frames(2)
	t.eq(list.get_child_count(), 4, "four rows")
	t.ok(_overflow(scroll), "fourth row scrolls")
	var src := FileAccess.get_file_as_string("res://scripts/cards/ui/demand/demand_panel.gd")
	t.ok(not src.contains("w0_stub"), "panel does not preload w0 stub")
	var board_src := FileAccess.get_file_as_string("res://scripts/cards/ui/demand/demand_board.gd")
	t.ok(not board_src.contains("w0_stub"), "board does not preload w0 stub")
	board.queue_free()
	bus.queue_free()
	await t.frames(1)
	var bus_d := CardEventBus.new()
	root.add_child(bus_d)
	var game := S.boot(self, bus_d, "board_three.json")
	await t.frames(2)
	game.host.open_panel(&"demands", {})
	await t.frames(1)
	t.ok(game.host.is_open(&"demands"), "drawer open")
	var drawer := game.host.top_panel()
	t.eq(drawer.find_child("List", true, false).get_child_count(), 3, "drawer rows")
	var row := drawer.find_child("Row_b2", true, false) as Button
	t.ok(row != null, "drawer row b2")
	row.pressed.emit()
	await t.frames(1)
	t.ok(not game.host.is_open(&"demands"), "drawer closed")
	t.ok(game.host.top_kind() == &"demand", "demand play opened")
	var played := game.host.top_panel() as CardDemandPanel
	t.eq(played._uid, "b2", "opened b2")
	game.queue_free()
	bus_d.queue_free()
	await t.frames(1)


func _overflow(scroll: ScrollContainer) -> bool:
	var bar := scroll.get_v_scroll_bar()
	return bar.max_value > bar.page + 0.5
