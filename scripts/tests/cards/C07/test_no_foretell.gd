# Every fixture state: no percent, no digits except the fee and the unpublished g05.almanac key placeholder.
# Fixtures themselves carry no hidden keys.
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const H = preload("res://scripts/tests/cards/C07/c07_harness.gd")
const NAMES: Array[String] = ["teller_both", "lot_only", "cezi_only", "after_lot", "no_money", "almanac_done"]


func _initialize() -> void:
	var t := T.new(self, "C07_no_foretell")
	t.run_async(_body.bind(t))


func _body(t) -> void:
	var bus := CardEventBus.new()
	root.add_child(bus)
	await t.frames(1)
	for name in NAMES:
		await _one(t, bus, name)
	bus.queue_free()
	await t.frames(1)


func _one(t, bus: CardEventBus, name: String) -> void:
	var path := H.FIX + name + ".json"
	var fx = CardDB.read_json(path)
	t.no_leaks(fx, name + " fixture")
	var m := H.mock(bus, name)
	t.no_leaks(m.view(), name + " view")
	t.no_leaks(m.query(&"fortune", {"uid": H.UID}), name + " fortune")
	t.no_leaks(m.query(&"card", {"uid": H.UID}), name + " card")
	var strip: CardAlmanacStrip = load(H.STRIP).instantiate()
	root.add_child(strip)
	await t.frames(1)
	strip.refresh(m.view())
	_clean(t, strip, name + " strip")
	var tip: Node = strip._make_custom_tooltip(".")
	_clean(t, tip, name + " tooltip")
	tip.free()
	var panel: CardFortunePanel = load(H.PANEL).instantiate()
	panel.bind(m, bus)
	root.add_child(panel)
	panel.open({"uid": H.UID})
	await t.frames(1)
	_clean(t, panel, name + " open")
	var q: Dictionary = m.query(&"fortune", {"uid": H.UID})
	var last = q.get("last", {})
	var has_last := typeof(last) == TYPE_DICTIONARY and str(last.get("lot", "")) != ""
	if bool(q.get("can_cezi", false)) and not has_last:
		H.button_by_key(panel, "c07.btn.cezi").pressed.emit()
		_clean(t, panel, name + " cezi")
		var buttons := H.char_buttons(panel)
		if buttons.size() > 1:
			buttons[1].pressed.emit()
		elif not buttons.is_empty():
			buttons[0].pressed.emit()
		_clean(t, panel, name + " reading")
		panel.open({"uid": H.UID})
		_clean(t, panel, name + " reopen")
	panel.fast_anim = false
	var guard := 0
	while panel.autoplay_step():
		guard += 1
		_clean(t, panel, name + " step " + str(guard))
		if guard > 8:
			t.ok(false, name + " autoplay did not finish")
			break
		await t.frames(1)
	t.ok(guard >= 1, name + " visited a step")
	panel.queue_free()
	strip.queue_free()
	await t.frames(1)


func _clean(t, node: Node, label: String) -> void:
	var bad: PackedStringArray = t.all_text_from_cardtext(node)
	t.eq(bad.size(), 0, label + " text not from CardText: " + str(bad))
	var digits := _digits(node)
	t.eq(digits.size(), 0, label + " digits: " + str(digits))


func _digits(node: Node) -> PackedStringArray:
	var bad := PackedStringArray()
	var num := RegEx.create_from_string("[0-9]")
	for n in H.walk(node):
		var cost := n is CanvasItem and (n as CanvasItem).has_meta("c07_cost")
		for txt in _chunks(n):
			if txt == "" or txt == ".":
				continue
			if txt.contains("%"):
				bad.append(txt)
				continue
			if num.search(txt) == null:
				continue
			if cost or _almanac_placeholder(txt):
				continue
			bad.append(txt)
	return bad


func _chunks(n: Node) -> PackedStringArray:
	var out := PackedStringArray()
	if n is Label:
		out.append((n as Label).text)
		out.append((n as Label).tooltip_text)
	elif n is Button:
		out.append((n as Button).text)
		out.append((n as Button).tooltip_text)
	elif n is RichTextLabel:
		out.append((n as RichTextLabel).get_parsed_text())
	return out


func _almanac_placeholder(txt: String) -> bool:
	var num := RegEx.create_from_string("[0-9]")
	for a in CardIds.ALMANAC_ACTIONS:
		var key := "g05.almanac." + str(a)
		if txt != CardText.ui(key) or not CardText.is_draft(key):
			continue
		if num.search(txt.replace(key, "")) == null:
			return true
	return false
