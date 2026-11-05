# C03：五种来源的拖拽和选择器、拿出来、没有 coins 键时不显示铜钱。
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const H = preload("res://scripts/tests/cards/C03/harness.gd")
const PANEL := "res://scenes/cards/slots/SlotPanel.tscn"


func _initialize() -> void:
	var t := T.new(self, "C03_sources")
	t.run_async(_body.bind(t))


func _body(t) -> void:
	H.leaks_all(t)
	var pair: Array = H.boot(self, "event_slots")
	var bus: CardEventBus = pair[0]
	var mock: MockCardEngine = pair[1]
	var spy = t.spy(bus)
	var panel := H.open_panel(self, mock, bus, PANEL, {"uid": "c0101"})
	await t.frames(2)
	_drag(t, panel, "Slot_paper", {"kind": "card", "uid": "c0020", "zone": "kept"}, {"kind": "kept", "uid": "c0020"})
	_drag(t, panel, "Slot_man", {"kind": "card", "uid": "c0012", "zone": "contacts"}, {"kind": "contact", "uid": "c0012"})
	_drag(t, panel, "Slot_man", {"kind": "card", "uid": "c0001", "zone": "self"}, {"kind": "self"})
	_drag(t, panel, "Slot_man", {"kind": "self"}, {"kind": "self"})
	_drag(t, panel, "Slot_cash", {"kind": "money", "amount": 30}, {"kind": "money", "amount": 30})
	_drag(t, panel, "Slot_goods", {"kind": "item", "item": "I004"}, {"kind": "item", "item": "I004"})
	_drag(t, panel, "Slot_word", {"kind": "card", "uid": "c0031", "zone": "hand"}, {"kind": "news", "uid": "c0031"})
	_press(t, panel, "paper", "Pick_kept_c0020", {"kind": "kept", "uid": "c0020"})
	_press(t, panel, "man", "Pick_contact_c0012", {"kind": "contact", "uid": "c0012"})
	_press(t, panel, "man", "PickSelf", {"kind": "self"})
	_press(t, panel, "cash", "PickMoney", {"kind": "money", "amount": 20})
	_press(t, panel, "goods", "PickItem_I004", {"kind": "item", "item": "I004"})
	_press(t, panel, "word", "Pick_news_c0031", {"kind": "news", "uid": "c0031"})
	var paper: CardSlotWidget = panel.find_child("Slot_paper", true, false)
	t.ok(not paper._can_drop_data(Vector2.ZERO, {"kind": "money", "amount": 10}), "paper rejects money preview")
	var cash: CardSlotWidget = panel.find_child("Slot_cash", true, false)
	t.ok(cash._can_drop_data(Vector2.ZERO, {"kind": "money", "amount": 10}), "cash accepts money preview")
	t.eq(cash.size.x, CardLayout.slot_rect(1, 5).size.x, "five slots use the narrow width")
	var before := H.cmds(mock, "slot.place").size()
	_checks(panel).open_picker("man")
	(panel.find_child("Pick_contact_c0013", true, false) as Button).pressed.emit()
	_checks(panel).open_picker("man")
	(panel.find_child("Pick_contact_c0016", true, false) as Button).pressed.emit()
	t.eq(H.cmds(mock, "slot.place").size(), before, "used and away contacts do not place")
	(panel.find_child("Remove0", true, false) as Button).pressed.emit()
	await t.frames(1)
	var removed: Array = H.cmds(mock, "slot.remove")
	t.eq(removed[0], {"uid": "c0101", "slot": "paper", "index": 0}, "remove args")
	var drops: Array = spy.ui_events().filter(func(e: Array) -> bool: return e[0] == &"slot_drop")
	t.ok(drops.size() >= 13, "slot_drop for each drop and pick, got %d" % drops.size())
	_no_coins(t)
	await _money_pad(t)
	H.ui_ok(t, panel)
	await H.drop(self, [panel, bus])


## b37: the money pad reads "-n / +n" in full (not clipped to 少一/多一), minus is off while no money is in,
## and the slot's name (官面) has a real width.
func _money_pad(t) -> void:
	var widget := CardSlotWidget.new()
	root.add_child(widget)
	widget.set_slot("c0003", {"id": "m", "accepts": ["money"], "wants": ["official"], "placed": []})
	widget.set_money_unit(5)
	await process_frame
	await process_frame
	var minus := widget.find_child("MoneyMinus", true, false) as Button
	var plus := widget.find_child("MoneyPlus", true, false) as Button
	t.eq(minus.text, CardText.ui("c03.money.minus", {"n": 5}), "b37 minus text")
	t.eq(plus.text, CardText.ui("c03.money.plus", {"n": 5}), "b37 plus text")
	t.ok(minus.disabled and not plus.disabled, "b37 minus is off with no money placed")
	for b: Button in [minus, plus]:
		var font: Font = b.get_theme_font("font")
		var need: float = font.get_string_size(b.text, HORIZONTAL_ALIGNMENT_LEFT, -1, b.get_theme_font_size("font_size")).x
		t.ok(b.is_visible_in_tree() and b.size.x >= need, "b37 %s fits (%d >= %d)" % [b.name, b.size.x, need])
		t.ok(widget.get_global_rect().grow(1.0).encloses(b.get_global_rect()), "b37 %s inside the slot" % b.name)
	var wants := widget.find_child("Wants", true, false) as Label
	var wfont := wants.get_theme_font("font")
	var wneed := wfont.get_string_size(wants.text, HORIZONTAL_ALIGNMENT_LEFT, -1, wants.get_theme_font_size("font_size")).x
	t.ok(wants.size.x >= wneed - 0.5, "b37 slot name has its width (%d >= %d)" % [wants.size.x, wneed])
	widget.set_slot("c0003", {"id": "m", "accepts": ["money"], "wants": ["official"],
		"placed": [{"kind": "money", "amount": 5, "coins": 1, "heads": 0, "auto_pass": false}], "coins": 1})
	t.ok(not minus.disabled, "b37 minus works once money is in")
	widget.queue_free()
	await process_frame


func _drag(t, panel: Node, slot_name: String, data: Dictionary, source: Dictionary) -> void:
	var widget: CardSlotWidget = panel.find_child(slot_name, true, false)
	var before := H.cmds(_mock(panel), "slot.place").size()
	widget._drop_data(Vector2.ZERO, data)
	var places: Array = H.cmds(_mock(panel), "slot.place")
	t.eq(places[places.size() - 1]["source"], source, "drag " + slot_name)
	t.eq(places.size(), before + 1, "drag sent place")


func _press(t, panel: Node, slot_id: String, button_name: String, source: Dictionary) -> void:
	_checks(panel).open_picker(slot_id)
	(panel.find_child(button_name, true, false) as Button).pressed.emit()
	var places: Array = H.cmds(_mock(panel), "slot.place")
	t.eq(places[places.size() - 1]["source"], source, "pick " + button_name)


func _checks(panel: Node) -> CardCounterChecks:
	return panel.find_child("Checks", true, false) as CardCounterChecks


func _mock(panel: Node) -> MockCardEngine:
	return (panel as CardSlotPanel).engine as MockCardEngine


func _no_coins(t) -> void:
	var widget := CardSlotWidget.new()
	root.add_child(widget)
	widget.set_slot("c0003", {"id": "s", "accepts": ["money"], "wants": ["official"],
		"placed": [{"kind": "money", "amount": 5, "coins": 3, "heads": 1, "auto_pass": true}]})
	t.ok(not widget.shows_coins(), "missing coins key hides counts")
	t.ok(widget.find_child("PlacedCoins", true, false) == null, "no per-item coins")
	t.ok(not (widget.find_child("SlotTotal", true, false) as Label).visible, "total hidden")
	t.ok(widget.find_child("PlacedHeads", true, false) != null, "heads still shown")
	t.ok(widget.find_child("AutoPass", true, false) != null, "auto_pass still shown")
	widget.set_slot("c0003", {"id": "s", "accepts": ["money"], "coins": 3,
		"placed": [{"kind": "money", "amount": 5, "coins": 3, "heads": 0, "auto_pass": false}]})
	t.ok(widget.shows_coins(), "coins key shows counts")
	t.eq((widget.find_child("PlacedCoins", true, false) as Label).text, "3", "placed coins")
	t.eq((widget.find_child("SlotTotal", true, false) as Label).text, "3", "slot total")
	widget.queue_free()
