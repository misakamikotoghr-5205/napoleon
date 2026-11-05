# C11 street skin on the table host: visible in street mode, click-through except the button.
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const Support = preload("res://scripts/tests/cards/C11/support.gd")

var t


func _initialize() -> void:
	t = T.new(self, "C11_street")
	t.run_async(_body)


func _body() -> void:
	t.no_leaks(Support.load_fx("street"), "street fixture")
	var bus := CardEventBus.new()
	root.add_child(bus)
	var mock := MockCardEngine.new(bus)
	mock.load_fixture(Support.path("street"))
	t.no_leaks(mock.view(), "street view")
	var game := (load(CardIds.ROOT_SCENE) as PackedScene).instantiate() as CardGameRoot
	game.boot({"mock": true, "bus": bus, "fixture": Support.path("street"), "skip_title": true, "guide": "off"})
	root.add_child(game)
	await t.frames(4)
	var overlay := _overlay(game)
	t.ok(overlay != null, "table hosts the street skin")
	t.ok(overlay.visible, "visible while mode is street")
	t.ok(Support.find(overlay, "street_bg") == null, "no street backdrop")
	t.ok(_has_card(game), "hand card stays on the table")
	var btn := Support.find(overlay, "redeem") as Button
	t.ok(btn != null, "redeem button")
	t.eq(btn.position, CardLayout.STREET_REDEEM.position, "button on STREET_REDEEM")
	t.eq(btn.size, CardLayout.STREET_REDEEM.size, "button size")
	var hint := Support.find(overlay, "hint") as Label
	t.ok(hint != null and hint.position.y + hint.size.y <= btn.position.y, "hint sits above the button")
	t.ok(t.anchor_ok(&"a.street.redeem"), "a.street.redeem")
	var hits := [0]
	overlay.redeem_shop_pressed.connect(func() -> void: hits[0] += 1)
	var before := Support.count_cmd(mock, "street.redeem_shop")
	btn.pressed.emit()
	t.eq(hits[0], 1, "redeem_shop_pressed")
	t.eq(Support.count_cmd(mock, "street.redeem_shop"), before, "C01 sends street.redeem_shop")
	var blocked := PackedStringArray()
	_filters(overlay, btn, blocked)
	t.ok(blocked.is_empty(), "mouse pass-through " + ",".join(blocked))
	t.eq(int(btn.mouse_filter), int(Control.MOUSE_FILTER_STOP), "button takes the click")
	t.ok(Support.no_percent(overlay), "no percent sign")
	var bad: PackedStringArray = t.all_text_from_cardtext(overlay)
	t.ok(bad.is_empty(), "cardtext " + ",".join(bad))
	overlay.refresh({"mode": "shop"})
	t.ok(not overlay.visible, "hidden in the shop")
	t.ok(not CardAnchors.has(&"a.street.redeem"), "anchor hides with the skin")
	overlay.refresh({})
	t.ok(not overlay.visible, "missing mode counts as shop")
	overlay.refresh({"mode": "street"})
	t.ok(overlay.visible, "street again")
	t.ok(t.anchor_ok(&"a.street.redeem"), "anchor returns")
	game.queue_free()
	bus.queue_free()
	await t.frames(3)


func _overlay(n: Node) -> CardStreetOverlay:
	if n is CardStreetOverlay:
		return n as CardStreetOverlay
	for c in n.get_children():
		var f := _overlay(c)
		if f != null:
			return f
	return null


func _has_card(n: Node) -> bool:
	# `is CardWidget` keeps that class alive until exit and the headless checker
	# then reports the table's fonts and pictures as leaks. Match the script path.
	var scr: Script = n.get_script()
	if scr != null and str(scr.resource_path).ends_with("card_widget.gd"):
		return true
	for c in n.get_children():
		if _has_card(c):
			return true
	return false


func _filters(n: Node, button: Button, bad: PackedStringArray) -> void:
	if n is Control and n != button:
		if (n as Control).mouse_filter != Control.MOUSE_FILTER_IGNORE:
			bad.append(str(n.name))
	for c in n.get_children():
		_filters(c, button, bad)
