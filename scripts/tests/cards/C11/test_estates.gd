# C11 estates: five rows, mortgage / redeem commands, money is a number, no percent sign.
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const Support = preload("res://scripts/tests/cards/C11/support.gd")
const Kit = preload("res://scripts/cards/ui/slots/drawer_kit.gd")
const SCENE := "res://scenes/cards/ladder/EstatePanel.tscn"

var t


func _initialize() -> void:
	t = T.new(self, "C11_estates")
	t.run_async(_body)


func _body() -> void:
	var fx = Support.load_fx("estates")
	t.no_leaks(fx, "estates fixture")
	CardTheme.font_title()
	CardTheme.font_body()
	var bus := CardEventBus.new()
	root.add_child(bus)
	var mock := MockCardEngine.new(bus)
	mock.load_fixture(Support.path("estates"))
	t.no_leaks(mock.view(), "estates view")
	t.no_leaks(mock.query(&"estates", {}), "estates query")
	for row in mock.query(&"estates", {}).get("estates", []):
		CardArt.texture("illus." + str(row.get("id", "")))
	var panel := _open(mock, bus)
	var t0 := Time.get_ticks_usec()
	panel.open({})
	var dt := int((Time.get_ticks_usec() - t0) / 1000)
	print("C11_PERF estate_open_ms=%d" % dt)
	t.ok(dt < 120, "estate open %d ms" % dt)
	await t.frames(2)
	var rows := 0
	for c in Support.find(panel, "list").get_children():
		if str(c.name).begins_with("row_"):
			rows += 1
	t.eq(rows, 5, "five estates")
	# b19: the estates drawer sits inside the right drawer frame (388x630 under its title row), not top-left.
	# QA 10-25: under the unified title row (drawer_host.HEAD_H 52), i.e. the shared drawer-kit content rect.
	t.eq(Rect2(panel.position, panel.size), Kit.rect("r"), "b19 estates inside DRAWER_R")
	# QA 10-25: the rows scroll above the close-day plate that the host draws over the drawer's lower right.
	var box := panel.find_child("box", true, false) as Control
	t.ok(box != null and box.get_global_rect().end.y <= CardLayout.END_DAY.position.y, "estate rows stop above the close-day plate")
	for c in Support.find(panel, "list").get_children():
		var r := (c as Control).get_global_rect()
		t.ok(r.position.x >= CardLayout.DRAWER_R.position.x and r.end.x <= CardLayout.DRAWER_R.end.x,
			"b19 %s inside the right drawer" % c.name)
	_expect_row("row_es_jewel_cabinet", "held", "80", "4")
	_expect_row("row_es_storeroom", "mortgaged", "120", "6")
	_expect_row("row_es_counter", "held", "150", "7")
	_expect_row("row_es_old_house", "held", "260", "10")
	_expect_row("row_es_shopfront", "lost", "400", "16")
	var lost := Support.find(panel, "row_es_shopfront")
	t.ok(Support.find(lost, "mortgage") == null and Support.find(lost, "redeem") == null, "lost has no action")
	t.ok(Support.no_percent(panel), "no percent sign")
	var bad: PackedStringArray = t.all_text_from_cardtext(panel)
	t.ok(bad.is_empty(), "cardtext " + ",".join(bad))
	t.ok(t.anchor_ok(&"a.estate.list"), "a.estate.list")
	t.ok(t.anchor_ok(&"a.estate.mortgage"), "a.estate.mortgage")
	panel._unhandled_input(Support.key(KEY_ENTER))
	t.eq(Support.last_cmd(mock, "estate.mortgage"), {"estate": "es.jewel_cabinet"}, "enter mortgages first held")
	var before := panel.get_viewport().gui_get_focus_owner()
	panel._unhandled_input(Support.key(KEY_TAB))
	var after := panel.get_viewport().gui_get_focus_owner()
	t.ok(after is Button, "tab focuses a button")
	t.ok(after != before or before == null, "tab moves focus")
	(Support.find(Support.find(panel, "row_es_counter"), "mortgage") as Button).pressed.emit()
	t.eq((Support.find(panel, "reason") as Label).text, CardText.t("w0.mock.estate"), "reason key")
	(Support.find(Support.find(panel, "row_es_storeroom"), "redeem") as Button).pressed.emit()
	t.eq(Support.last_cmd(mock, "estate.redeem"), {"estate": "es.storeroom"}, "redeem")
	var closed := [false]
	panel.close_requested.connect(func(_r: Dictionary) -> void: closed[0] = true)
	var sent_before_esc := mock.sent.size()
	panel._unhandled_input(Support.key(KEY_ESCAPE))
	t.ok(closed[0], "esc closes the drawer")
	t.eq(mock.sent.size(), sent_before_esc, "closing the drawer sends nothing")
	panel.open({"uid": "c0002", "nope": true})
	panel.refresh({"mode": "street"})
	var p2 := _open(mock, bus)
	var sent_n := mock.sent.size()
	var looked := [false]
	p2.close_requested.connect(func(_r: Dictionary) -> void: looked[0] = true)
	p2.open({})
	await t.frames(1)
	t.ok(p2.autoplay_step(), "autoplay looks then closes")
	t.ok(looked[0], "autoplay requested close")
	t.eq(mock.sent.size(), sent_n, "autoplay does not mortgage")
	t.ok(not p2.autoplay_step(), "autoplay stops")
	panel.queue_free()
	p2.queue_free()
	bus.queue_free()
	await t.frames(3)


func _open(mock: MockCardEngine, bus: CardEventBus) -> CardEstatePanel:
	var panel := (load(SCENE) as PackedScene).instantiate() as CardEstatePanel
	panel.bind(mock, bus)
	root.add_child(panel)
	return panel


func _expect_row(node_name: String, status: String, money: String, interest: String) -> void:
	var row := Support.find(root, node_name)
	t.ok(row != null, node_name)
	if row == null:
		return
	t.eq((Support.find(row, "status") as Label).text, CardText.ui("c11.status." + status), status)
	t.eq((Support.find(row, "money_n") as Label).text, money, node_name + " money")
	t.eq((Support.find(row, "interest_n") as Label).text, interest, node_name + " interest")
