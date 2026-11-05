# C11 guide: four steps light and complete; five anchors have area inside 1280x720.
# --name= sets the PASS line. --steps=k16 loads Mock guide_data (K16 steps.json).
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const Support = preload("res://scripts/tests/cards/C11/support.gd")

var t
var _steps: Dictionary = {}


func _initialize() -> void:
	t = T.new(self, _arg("--name=", "C11_guide"))
	t.run_async(_body)


func _body() -> void:
	var k16: bool = _arg("--steps=", "") == "k16"
	if not k16:
		_steps = CardDB.read_json(Support.STEPS)
	await _mortgage(k16)
	await _short(k16)
	await _street(k16)
	await _prison(k16)


func _mortgage(k16: bool) -> void:
	var bus := CardEventBus.new()
	root.add_child(bus)
	var mock := MockCardEngine.new(bus)
	mock.load_fixture(Support.path("estates"))
	var guide := _guide(mock, bus, k16)
	var host := CardModalHost.new()
	host.bind(mock, bus)
	root.add_child(host)
	var panel := host.open_panel(&"estates", {})
	await t.frames(2)
	t.ok(t.anchor_ok(&"a.estate.list"), "a.estate.list")
	t.ok(t.anchor_ok(&"a.estate.mortgage"), "a.estate.mortgage")
	bus.first_time.emit(&"mortgage", {})
	guide.evaluate_now()
	t.eq(guide.active_step(), "gd.mortgage", "gd.mortgage lights")
	(Support.find(panel, "mortgage") as Button).pressed.emit()
	await t.frames(1)
	t.eq(guide.active_step(), "", "gd.mortgage completes")
	t.ok(guide.shown_log.has("gd.mortgage"), "mortgage was shown")
	await _free([host, guide, bus])


func _short(k16: bool) -> void:
	var bus := CardEventBus.new()
	root.add_child(bus)
	var mock := MockCardEngine.new(bus)
	mock.load_fixture(Support.path("short_all"))
	var guide := _guide(mock, bus, k16)
	var host := CardModalHost.new()
	host.bind(mock, bus)
	root.add_child(host)
	host.open_panel(&"short", {})
	await t.frames(2)
	t.ok(t.anchor_ok(&"a.short.options"), "a.short.options")
	bus.first_time.emit(&"money_short", {})
	guide.evaluate_now()
	t.eq(guide.active_step(), "gd.money_short", "gd.money_short lights")
	(Support.find(host, "goods_I001") as Button).pressed.emit()
	await t.frames(1)
	t.eq(guide.active_step(), "", "gd.money_short completes")
	await _free([host, guide, bus])


func _street(k16: bool) -> void:
	var bus := CardEventBus.new()
	root.add_child(bus)
	var mock := MockCardEngine.new(bus)
	mock.load_fixture(Support.path("street"))
	var game := (load(CardIds.ROOT_SCENE) as PackedScene).instantiate() as CardGameRoot
	game.boot({"mock": true, "bus": bus, "fixture": Support.path("street"), "skip_title": true, "guide": "off"})
	root.add_child(game)
	game.guide.force(true)
	game.guide.skip_fades = true
	var data: Dictionary = {}
	if k16:
		data = mock.query(&"guide_data")
		game.guide.load_steps(data)
	else:
		game.guide.load_steps(_steps)
	await t.frames(4)
	t.ok(t.anchor_ok(&"a.street.redeem"), "a.street.redeem")
	if k16:
		# Full K16: stage_day 9 and phase day light gd.tiers (no first, same priority,
		# earlier than gd.street). Finish whatever is already active by its own done_when.
		_clear_already_active(game.guide, bus, data)
		t.ok(game.guide.shown_log.has("gd.tiers"), "gd.tiers lit on the day-9 table")
		t.eq(game.guide.active_step(), "", "earlier steps are done before street")
	bus.first_time.emit(&"street", {})
	game.guide.evaluate_now()
	t.eq(game.guide.active_step(), "gd.street", "gd.street lights")
	var overlay := _overlay(game)
	var hits := [0]
	overlay.redeem_shop_pressed.connect(func() -> void: hits[0] += 1)
	(Support.find(overlay, "redeem") as Button).pressed.emit()
	t.eq(hits[0], 1, "street button")
	t.eq(Support.count_cmd(mock, "street.redeem_shop"), 0, "button does not send")
	mock.send(&"street.redeem_shop", {})
	await t.frames(1)
	t.eq(game.guide.active_step(), "", "gd.street completes")
	await _free([game, bus])


func _prison(k16: bool) -> void:
	var bus := CardEventBus.new()
	root.add_child(bus)
	var mock := MockCardEngine.new(bus)
	mock.load_fixture(Support.path("prison"))
	var guide := _guide(mock, bus, k16)
	var host := CardModalHost.new()
	host.bind(mock, bus)
	root.add_child(host)
	var panel := host.open_panel(&"prison", {"uid": "c0015"})
	var rig := Support.mount_stage(root, panel, mock, bus)
	panel.open({"uid": "c0015"})
	await t.frames(2)
	(panel as CardPrisonPanel).on_reply("try")
	await t.frames(2)
	t.ok(t.anchor_ok(&"a.prison.slots"), "a.prison.slots")
	bus.first_time.emit(&"prison", {"uid": "c0015"})
	guide.evaluate_now()
	t.eq(guide.active_step(), "gd.prison", "gd.prison lights")
	var slot := Support.widgets(rig["checks"])[0] as CardSlotWidget
	slot._drop_data(Vector2.ZERO, {"kind": "money", "amount": 40})
	if k16:
		# K16 done_when is cmd:slot.roll or timeout. A cash drop is not that command.
		var rolled: Dictionary = mock.send(&"slot.roll", {"uid": "c0015"})
		t.ok(bool(rolled.get("ok", false)), "slot.roll ok")
	await t.frames(1)
	var done_msg := "gd.prison completes on slot_drop"
	if k16:
		done_msg = "gd.prison completes on slot.roll"
	t.eq(guide.active_step(), "", done_msg)
	var saw := false
	for row in guide.shown_log:
		if str(row) == "gd.prison":
			saw = true
	t.ok(saw, "prison was shown")
	await _free([host, guide, rig["stage"], rig["dialog"], rig["checks"], rig["hand"], bus])


func _guide(mock: MockCardEngine, bus: CardEventBus, k16: bool) -> CardGuide:
	var g := CardGuide.new()
	root.add_child(g)
	g.bind(mock, bus)
	g.force(true)
	g.skip_fades = true
	if k16:
		g.load_steps(mock.query(&"guide_data"))
	else:
		g.load_steps(_steps)
	return g


func _clear_already_active(guide: CardGuide, bus: CardEventBus, data: Dictionary) -> void:
	var steps := _step_rows(data)
	var guard := 0
	while guard < 8:
		guide.evaluate_now()
		var id := guide.active_step()
		if id == "":
			return
		if not _finish_lit(guide, bus, id, steps):
			return
		guard += 1


func _finish_lit(guide: CardGuide, bus: CardEventBus, id: String, steps: Array) -> bool:
	var raw := _step_by_id(steps, id)
	var done := _done_list(raw)
	var seconds := float(raw.get("seconds", 12))
	var has_timeout := false
	for tok in done:
		if str(tok) == "timeout":
			has_timeout = true
	if has_timeout and seconds <= 0.0:
		# K16 10-22 (prototype): seconds 0 = no clock; the player's "got it" ends the bubble.
		guide.acknowledge()
		return guide.active_step() != id
	if has_timeout:
		guide.tick(seconds)
		return guide.active_step() != id
	for tok in done:
		var token := str(tok)
		if token.begins_with("cmd:"):
			bus.command_done.emit(StringName(token.substr(4)), {}, true)
			return guide.active_step() != id
		if token.begins_with("ui:"):
			bus.ui_event.emit(StringName(token.substr(3)), {})
			return guide.active_step() != id
		if token.begins_with("panel:"):
			bus.ui_event.emit(&"panel_opened", {"kind": token.substr(6)})
			return guide.active_step() != id
	return false


func _step_rows(data: Dictionary) -> Array:
	var raw: Variant = data.get("steps", [])
	if typeof(raw) == TYPE_ARRAY:
		return raw
	return []


func _step_by_id(steps: Array, id: String) -> Dictionary:
	for row in steps:
		if typeof(row) != TYPE_DICTIONARY:
			continue
		var d: Dictionary = row as Dictionary
		if str(d.get("id", "")) == id:
			return d
	return {}


func _done_list(raw: Dictionary) -> Array:
	var v: Variant = raw.get("done_when", [])
	if typeof(v) == TYPE_ARRAY:
		return v
	return []


func _overlay(n: Node) -> CardStreetOverlay:
	if n is CardStreetOverlay:
		return n as CardStreetOverlay
	for c in n.get_children():
		var f := _overlay(c)
		if f != null:
			return f
	return null


func _free(nodes: Array) -> void:
	for n in nodes:
		if is_instance_valid(n) and n is Node:
			(n as Node).queue_free()
	await t.frames(3)


func _arg(prefix: String, fallback: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with(prefix):
			return a.substr(prefix.length())
	return fallback
