# C08: gd.must, gd.gold_leave, gd.d1.night, gd.d1.settle light on their anchors and complete.
# Owner C08. Contract 1.3.
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const Support = preload("res://scripts/tests/cards/C08/support.gd")
const STEPS := "res://scripts/tests/cards/C08/guide_steps.json"


func _initialize() -> void:
	var t := T.new(self, _arg("--name=", "C08_guide"))
	var k16 := _arg("--steps=", "") == "k16"
	t.run_async(_body.bind(t, k16))


func _body(t, k16: bool) -> void:
	var data: Dictionary = {}
	if not k16:
		var raw = CardDB.read_json(STEPS)
		t.ok(typeof(raw) == TYPE_DICTIONARY, "guide steps read")
		data = raw
	await _case(t, data, k16, "end_day_items", &"end_day", {},
		&"must_resolve", "gd.must", &"a.endday.blocked", Callable(self, "_finish_must"))
	await _case(t, data, k16, "end_day_gold", &"end_day", {},
		&"gold_leave", "gd.gold_leave", &"a.endday.gold_leave", Callable(self, "_finish_gold"))
	await _case(t, data, k16, "night", &"night", {},
		&"night", "gd.d1.night", &"a.night.offers", Callable(self, "_finish_night"))
	await _case(t, data, k16, "settle_lines", &"settle", {},
		&"settle", "gd.d1.settle", &"a.settle.lines", Callable(self, "_finish_settle"))


func _case(t, data: Dictionary, k16: bool, fixture: String, kind: StringName, args: Dictionary, mech: StringName,
		step_id: String, anchor: StringName, finish: Callable) -> void:
	var mounted: Array = Support.mount(self, fixture)
	var bus: CardEventBus = mounted[0]
	var mock: MockCardEngine = mounted[1]
	var host: CardModalHost = mounted[2]
	var layer := CanvasLayer.new()
	layer.layer = 100
	root.add_child(layer)
	var guide: CardGuide = load("res://scenes/cards/shell/GuideOverlay.tscn").instantiate()
	layer.add_child(guide)
	guide.bind(mock, bus)
	guide.force(true)
	guide.skip_fades = true
	var steps_data: Dictionary = mock.query(&"guide_data") if k16 else data
	guide.load_steps(steps_data)
	if k16:
		_mark_after_done(guide, steps_data, step_id)
	var panel := host.open_panel(kind, args)
	await t.frames(3)
	var rect := CardAnchors.rect(anchor)
	t.ok(t.anchor_ok(anchor), "anchor %s rect %s" % [anchor, rect])
	bus.first_time.emit(mech, {})
	guide.evaluate_now()
	t.eq(guide.active_step(), step_id, "lit " + step_id)
	t.ok(guide.shown_log.has(step_id), "shown log " + step_id)
	finish.call(panel, guide)
	await t.frames(2)
	t.eq(guide.active_step(), "", step_id + " completed")
	var done := false
	for row in mock.sent:
		if str(row[0]) == "ui.guide" and str(row[1].get("step", "")) == step_id and str(row[1].get("status", "")) == "done":
			done = true
	t.ok(done, "ui.guide done for " + step_id)
	guide.queue_free()
	layer.queue_free()
	host.queue_free()
	bus.queue_free()
	await t.frames(2)


func _mark_after_done(guide: CardGuide, data: Dictionary, step_id: String) -> void:
	for row in data.get("steps", []):
		if typeof(row) != TYPE_DICTIONARY or str(row.get("id", "")) != step_id:
			continue
		var trig: Dictionary = row.get("trigger", {}) if typeof(row.get("trigger", {})) == TYPE_DICTIONARY else {}
		for dep in trig.get("after", []):
			guide._progress[str(dep)] = {"status": "done", "shows": 1}


func _finish_must(_panel: CardPanel, guide: CardGuide) -> void:
	guide.tick(12.0)
	if guide.active_step() == "gd.must":
		# K16 10-22 (prototype): seconds 0 = no clock; the player's "got it" ends the bubble.
		guide.acknowledge()


func _finish_gold(panel: CardPanel, _guide: CardGuide) -> void:
	(Support.child(panel, "BtnConfirm") as Button).pressed.emit()


func _finish_night(panel: CardPanel, _guide: CardGuide) -> void:
	Support.play_hand(Support.offers(panel)[0])


func _finish_settle(panel: CardPanel, _guide: CardGuide) -> void:
	(panel as CardSettlePanel)._reveal_all()
	var dawn := Support.button_with(panel, CardText.t("c08.reply.dawn"))
	dawn.pressed.emit()


func _arg(prefix: String, fallback: String) -> String:
	for a in OS.get_cmdline_user_args():
		if str(a).begins_with(prefix):
			return str(a).substr(prefix.length())
	return fallback
