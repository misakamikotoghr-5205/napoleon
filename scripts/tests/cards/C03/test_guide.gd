# C03: five guide steps light, then ui.guide done. --steps=k16 loads raw guide_data.
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const H = preload("res://scripts/tests/cards/C03/harness.gd")
const GUIDE := "res://scenes/cards/shell/GuideOverlay.tscn"
const STEPS := "res://scripts/tests/cards/C03/guide_steps.json"
const WANT: Array[String] = ["gd.slots", "gd.coins", "gd.choice", "gd.contacts_full", "gd.kept_full"]


func _initialize() -> void:
	var name := "C03_guide"
	var steps := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--name="):
			name = arg.substr("--name=".length())
		elif arg.begins_with("--steps="):
			steps = arg.substr("--steps=".length())
	var t := T.new(self, name)
	if steps == "k16":
		t.run_async(_k16.bind(t))
	else:
		t.run_async(_body.bind(t))


func _body(t) -> void:
	H.leaks_all(t)
	var data = CardDB.read_json(STEPS)
	await _case(t, data, "gd.slots", "event_slots", "res://scenes/cards/slots/SlotPanel.tscn", {"uid": "c0003"}, "slots")
	await _case(t, data, "gd.coins", "event_slots", "res://scenes/cards/slots/SlotPanel.tscn", {"uid": "c0003"}, "coins")
	await _case(t, data, "gd.choice", "fate_choices", "res://scenes/cards/slots/SlotPanel.tscn", {"uid": "c0004"}, "choice")
	await _case(t, data, "gd.contacts_full", "contacts_full", "res://scenes/cards/slots/ContactsFull.tscn", {"new_uid": "c0099"}, "contacts_full")
	await _case(t, data, "gd.kept_full", "kept_full", "res://scenes/cards/slots/KeptFull.tscn", {"new_uid": "c0088"}, "kept_full")


func _k16(t) -> void:
	var pair: Array = H.boot(self, "event_slots")
	var data: Dictionary = (pair[1] as MockCardEngine).query(&"guide_data")
	await H.drop(self, [pair[0]])
	var ids: PackedStringArray = _k16_ids(data)
	t.eq(ids.size(), WANT.size(), "raw k16 has the five C03 steps, got %s" % ",".join(ids))
	await _k16_dark(t, data)
	await _k16_case(t, data, "gd.slots", "event_slots", "res://scenes/cards/slots/SlotPanel.tscn", {"uid": "c0003"})
	await _k16_case(t, data, "gd.coins", "event_slots", "res://scenes/cards/slots/SlotPanel.tscn", {"uid": "c0003"})
	await _k16_case(t, data, "gd.choice", "fate_choices", "res://scenes/cards/slots/SlotPanel.tscn", {"uid": "c0004"})
	await _k16_case(t, data, "gd.contacts_full", "contacts_full", "res://scenes/cards/slots/ContactsFull.tscn", {"new_uid": "c0099"})
	await _k16_case(t, data, "gd.kept_full", "kept_full", "res://scenes/cards/slots/KeptFull.tscn", {"new_uid": "c0088"})


func _k16_dark(t, data: Dictionary) -> void:
	var raw: Dictionary = _raw_step(data, "gd.slots")
	t.ok(not raw.is_empty(), "gd.slots is in the raw steps")
	if raw.is_empty():
		return
	var trig: Dictionary = _dict(raw.get("trigger", {}))
	var pair: Array = H.boot(self, "event_slots")
	var bus: CardEventBus = pair[0]
	var mock: MockCardEngine = pair[1]
	_apply_trigger_view(mock, trig)
	var panel: CardPanel = H.open_panel(self, mock, bus, "res://scenes/cards/slots/SlotPanel.tscn", {"uid": "c0003"})
	await t.frames(2)
	var guide: CardGuide = _mount_guide(mock, bus, data)
	bus.first_time.emit(&"slots", {"uid": "c0003"})
	guide.evaluate_now()
	if (trig.get("after", []) as Array).is_empty():
		# K16 10-22 (prototype): steps no longer chain across days; a missed step must not block gd.slots.
		t.eq(guide.active_step(), "gd.slots", "gd.slots lights without an earlier step (no after chain)")
	else:
		t.ok(guide.active_step() != "gd.slots", "gd.slots stays dark without prior %s" % str(trig.get("after", [])))
	await H.drop(self, [guide, panel, bus])


func _k16_case(t, data: Dictionary, step_id: String, fx: String, scene: String, args: Dictionary) -> void:
	var raw: Dictionary = _raw_step(data, step_id)
	t.ok(not raw.is_empty(), step_id + " is in the raw k16 steps")
	if raw.is_empty():
		return
	var trig: Dictionary = _dict(raw.get("trigger", {}))
	var pair: Array = H.boot(self, fx)
	var bus: CardEventBus = pair[0]
	var mock: MockCardEngine = pair[1]
	_mark_priors(t, mock, data, trig)
	_apply_trigger_view(mock, trig)
	var panel: CardPanel = H.open_panel(self, mock, bus, scene, args)
	await t.frames(2)
	var guide: CardGuide = _mount_guide(mock, bus, data)
	var panel_kind: String = str(trig.get("panel", ""))
	if panel_kind != "":
		bus.ui_event.emit(&"panel_opened", {"kind": panel_kind})
	var uid: String = str(args.get("uid", args.get("new_uid", "")))
	bus.first_time.emit(StringName(str(trig.get("first", ""))), {"uid": uid})
	guide.evaluate_now()
	t.eq(guide.active_step(), step_id, step_id + " lit")
	var anchor: String = str(raw.get("anchor", ""))
	t.ok(anchor != "" and t.anchor_ok(StringName(anchor)), step_id + " anchor " + anchor)
	t.eq(str(guide._anchor_now), anchor, step_id + " guide anchor")
	_act(panel, step_id)
	t.eq(guide.active_step(), "", step_id + " completed")
	t.ok(_done_token(mock, raw), step_id + " completed by its own done_when")
	await t.frames(3)
	t.ok(H.guide_done(mock, step_id), step_id + " ui.guide done")
	H.ui_ok(t, panel)
	await H.drop(self, [guide, panel, bus])


func _mount_guide(mock: MockCardEngine, bus: CardEventBus, data: Dictionary) -> CardGuide:
	var guide: CardGuide = (load(GUIDE) as PackedScene).instantiate()
	guide.skip_fades = true
	root.add_child(guide)
	guide.bind(mock, bus)
	guide.force(true)
	guide.load_steps(data)
	return guide


func _mark_priors(t, mock: MockCardEngine, data: Dictionary, trig: Dictionary) -> void:
	var after: Array = _arr(trig.get("after", []))
	for item in after:
		var id: String = str(item)
		t.ok(not _raw_step(data, id).is_empty(), "real prior " + id)
		var sent: Dictionary = mock.send(&"ui.guide", {"step": id, "status": "done"})
		t.ok(bool(sent.get("ok", false)), "prior marked done " + id)


func _apply_trigger_view(mock: MockCardEngine, trig: Dictionary) -> void:
	var view: Dictionary = mock._view
	if trig.has("phase") and typeof(trig.get("phase")) != TYPE_ARRAY:
		view["phase"] = str(trig.get("phase"))
	var date: Dictionary = _dict(view.get("date", {}))
	if trig.has("stage_day_gte") and int(date.get("stage_day", 0)) < int(trig.get("stage_day_gte")):
		date["stage_day"] = int(trig.get("stage_day_gte"))
	if trig.has("stage_gte") and int(date.get("stage", 0)) < int(trig.get("stage_gte")):
		date["stage"] = int(trig.get("stage_gte"))
	view["date"] = date
	mock._view = view


func _done_token(mock: MockCardEngine, raw: Dictionary) -> bool:
	var want: Dictionary = {}
	for tok in _arr(raw.get("done_when", [])):
		want[str(tok)] = true
	for row in mock.sent:
		if typeof(row) != TYPE_ARRAY or (row as Array).is_empty():
			continue
		if bool(want.get("cmd:" + str((row as Array)[0]), false)):
			return true
	return false


func _k16_ids(data: Dictionary) -> PackedStringArray:
	var ids: PackedStringArray = PackedStringArray()
	for step in _arr(data.get("steps", [])):
		if typeof(step) != TYPE_DICTIONARY:
			continue
		var id: String = str((step as Dictionary).get("id", ""))
		if WANT.has(id):
			ids.append(id)
	return ids


func _raw_step(data: Dictionary, id: String) -> Dictionary:
	for step in _arr(data.get("steps", [])):
		if typeof(step) == TYPE_DICTIONARY and str((step as Dictionary).get("id", "")) == id:
			return step
	return {}


func _dict(v) -> Dictionary:
	if typeof(v) == TYPE_DICTIONARY:
		return v
	return {}


func _arr(v) -> Array:
	if typeof(v) == TYPE_ARRAY:
		return v
	return []


func _case(t, data: Dictionary, step: String, fx: String, scene: String, args: Dictionary, mech: String) -> void:
	var pair: Array = H.boot(self, fx)
	var panel := H.open_panel(self, pair[1], pair[0], scene, args)
	await t.frames(2)
	var guide: CardGuide = (load(GUIDE) as PackedScene).instantiate()
	root.add_child(guide)
	guide.bind(pair[1], pair[0])
	guide.force(true)
	guide.skip_fades = true
	guide.load_steps(data)
	pair[0].first_time.emit(StringName(mech), {"uid": str(args.get("uid", args.get("new_uid", "")))})
	guide.evaluate_now()
	t.eq(guide.active_step(), step, step + " lit")
	_act(panel, step)
	await t.frames(3)
	t.ok(H.guide_done(pair[1], step), step + " ui.guide done")
	H.ui_ok(t, panel)
	await H.drop(self, [guide, panel, pair[0]])


func _act(panel: Node, step: String) -> void:
	if step == "gd.slots":
		var widget: CardSlotWidget = panel.find_child("Slot_cash", true, false)
		widget._drop_data(Vector2.ZERO, {"kind": "money", "amount": 10})
	elif step == "gd.coins":
		(panel as CardSlotPanel).on_reply("roll")
	elif step == "gd.choice":
		(panel as CardSlotPanel).on_reply("move_goods")
	elif step == "gd.contacts_full":
		var card: CardWidget = panel.find_child("Rel_c0012", true, false)
		card.pressed.emit(card.get_uid())
	elif step == "gd.kept_full":
		(panel.find_child("CloseBtn", true, false) as Button).pressed.emit()
