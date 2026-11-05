# C03：演出、回话、格子位置、掷铜钱、拒绝、autoplay。只按归属看自己的牌，不扫全库。
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const H = preload("res://scripts/tests/cards/C03/harness.gd")
const PANEL := "res://scenes/cards/slots/SlotPanel.tscn"


func _initialize() -> void:
	var t := T.new(self, "C03_slot_panel")
	t.run_async(_body.bind(t))


func _body(t) -> void:
	H.leaks_all(t)
	await _screen(t)
	await _stage_cast(t)
	await _event(t)
	await _fate(t)
	await _gold(t)
	await _reject(t)
	await _required_and_auto(t)
	await _junk_and_keys(t)
	await _after_roll(t)


func _screen(t) -> void:
	var bus := CardEventBus.new()
	root.add_child(bus)
	var spy = t.spy(bus)
	var game: CardGameRoot = load(CardIds.ROOT_SCENE).instantiate()
	game.boot({"mock": true, "bus": bus, "fixture": "res://scripts/tests/cards/C03/fixtures/event_slots.json",
		"skip_title": true, "guide": "off"})
	root.add_child(game)
	await t.frames(3)
	game.table._on_card_pressed("c0003")
	await t.frames(2)
	var opened := false
	var showed := false
	for row in spy.ui_events():
		if row[0] != &"panel_opened":
			continue
		var args: Dictionary = row[1]
		if str(args.get("kind", "")) != "slots":
			continue
		opened = true
		if args.has("show"):
			showed = true
			t.eq(str(args.get("show", "")), "stage", "panel_opened show")
	t.ok(opened, "panel_opened slots")
	t.eq(str(CardIds.PANEL_SHOW[&"slots"]), "stage", "slots presentation is stage")
	if not showed:
		print("C03 note: host panel_opened has no show; CardIds.PANEL_SHOW slots=stage")
	var panel := game.host.top_panel() as CardSlotPanel
	t.ok(panel != null, "screen root opened the slot play")
	if panel != null:
		_lines_match(t, panel, "intro")
		H.ui_ok(t, panel)
	await H.drop(self, [game, bus])


func _stage_cast(t) -> void:
	var data = CardDB.read_json("res://scripts/tests/cards/C03/fixtures/stage_police.json")
	var script := CardStageScript.resolve(data["card"], data["view"])
	var cast: Array = script["cast"]
	t.eq(cast.size(), 2, "two patrols")
	t.eq(str(cast[0].get("who", "")), "ex_patrol", "patrol a")
	t.eq(str(cast[0].get("at", "")), "door_l", "door left")
	t.eq(str(cast[1].get("at", "")), "door_r", "door right")
	var pair: Array = H.boot(self, "event_slots")
	var path: String = pair[1].db.file_of("ev.1938.police_check")
	t.ok(path.ends_with("era/1938/events.json"), "police card file " + path)
	t.ok(not pair[1].db.def("ev.1938.police_check").has("stage"), "stage block stays in the C03 fixture")
	await H.drop(self, [pair[0]])


func _event(t) -> void:
	var pair: Array = H.boot(self, "event_slots")
	var panel := H.open_panel(self, pair[1], pair[0], PANEL, {"uid": "c0003"}) as CardSlotPanel
	await t.frames(2)
	_lines_match(t, panel, "intro")
	var info: Dictionary = pair[1].query(&"slots", {"uid": "c0003"})
	var roll := _reply(panel, "roll")
	t.eq(int(roll.get("args", {}).get("n", -1)), int(info["coins"]), "roll reply n")
	t.eq(int(roll.get("args", {}).get("m", -1)), int(info["need"]), "roll reply m")
	# 换皮 10-22（原型 60）：铜钱一排旁边是一句“铜钱 n 枚 · 要 m 个正面”，不再是两个光秃秃的数字。
	var line: Label = panel.find_child("CoinsLine", true, false)
	var want := CardText.ui("c03.coins.line", {"n": int(info["coins"]), "m": int(info["need"])})
	t.ok(line != null and line.text == want, "coin line %s" % (line.text if line != null else "<none>"))
	t.ok(line != null and line.text.contains(str(int(info["coins"]))) and line.text.contains(str(int(info["need"]))),
		"coin line shows coins and need")
	_slots_at_layout(t, panel, info)
	for id in ["a.slots.first", "a.slots.coins", "a.slots.roll", "a.slots.money"]:
		t.ok(t.anchor_ok(StringName(id)), "anchor %s" % id)
	t.ok(_reply(panel, "move_goods").is_empty(), "event has no choices")
	t.ok((panel.find_child("Checks", true, false) as CardChecksApi).is_shown(), "checks shown at once")
	H.ui_ok(t, panel)
	await H.drop(self, [panel, pair[0]])


func _fate(t) -> void:
	var pair: Array = H.boot(self, "fate_choices")
	var panel := H.open_panel(self, pair[1], pair[0], PANEL, {"uid": "c0004"}) as CardSlotPanel
	await t.frames(2)
	t.ok(not (panel.find_child("Checks", true, false) as CardChecksApi).is_shown(), "slots hidden before choose")
	t.ok(t.anchor_ok(&"a.slots.choices"), "choices anchor")
	var shut := _reply(panel, "shut_door")
	t.ok(not bool(shut.get("enabled", true)), "disabled choice")
	t.ok(_has_text(panel, CardText.t("c03.err.person_busy")), "disabled reason")
	var go := _reply(panel, "move_goods")
	t.ok(bool(go.get("enabled", false)), "move goods enabled")
	panel.on_reply("move_goods")
	await t.frames(2)
	t.eq(H.cmds(pair[1], "card.choose"), [{"uid": "c0004", "choice": "move_goods"}], "choose args")
	t.ok((panel.find_child("Checks", true, false) as CardChecksApi).is_shown(), "slots after needs_slots")
	t.ok(t.anchor_ok(&"a.slots.first"), "first slot after choose")
	var info: Dictionary = pair[1].query(&"slots", {"uid": "c0004"})
	_slots_at_layout(t, panel, info)
	H.ui_ok(t, panel)
	await H.drop(self, [panel, pair[0]])


func _gold(t) -> void:
	var pair: Array = H.boot(self, "gold_story")
	var panel := H.open_panel(self, pair[1], pair[0], PANEL, {"uid": "c0002"}) as CardSlotPanel
	await t.frames(2)
	t.ok(not _reply(panel, "listen").is_empty(), "gold listen")
	t.ok(bool(_reply(panel, "argue").get("enabled", false)), "gold argue enabled")
	panel.on_reply("listen")
	await t.frames(1)
	t.eq(H.cmds(pair[1], "card.choose"), [{"uid": "c0002", "choice": "listen"}], "gold choose")
	t.eq(H.cmds(pair[1], "slot.roll").size(), 0, "gold choice does not roll")
	H.ui_ok(t, panel)
	await H.drop(self, [panel, pair[0]])


func _reject(t) -> void:
	var pair: Array = H.boot(self, "slot_reject")
	var panel := H.open_panel(self, pair[1], pair[0], PANEL, {"uid": "c0200"}) as CardSlotPanel
	await t.frames(2)
	var checks := panel.find_child("Checks", true, false) as CardCounterChecks
	checks.open_picker("man")
	(panel.find_child("PickSelf", true, false) as Button).pressed.emit()
	await t.frames(1)
	var reason: Label = panel.find_child("Reason", true, false)
	t.eq(reason.text, CardText.t("c03.err.slot_reject"), "reason_key text")
	checks.open_picker("man")
	(panel.find_child("PickMoney", true, false) as Button).pressed.emit()
	await t.frames(1)
	t.eq(reason.text, CardText.ui("c03.err.person_busy"), "err code text")
	var places: Array = H.cmds(pair[1], "slot.place")
	t.eq(places[0]["source"], {"kind": "self"}, "rejected self source")
	t.eq(places[1]["source"], {"kind": "money", "amount": 20}, "rejected money source")
	H.ui_ok(t, panel)
	await H.drop(self, [panel, pair[0]])


func _required_and_auto(t) -> void:
	var pair: Array = H.boot(self, "event_slots")
	var blocked := H.open_panel(self, pair[1], pair[0], PANEL, {"uid": "c0100"}) as CardSlotPanel
	await t.frames(1)
	t.ok(not bool(_reply(blocked, "roll").get("enabled", true)), "required slot disables roll")
	var passed := H.open_panel(self, pair[1], pair[0], PANEL, {"uid": "c0102"}) as CardSlotPanel
	await t.frames(1)
	t.eq(str(_reply(passed, "roll").get("ref", "")), "c03.coins.auto_pass", "auto pass reply")
	var counts: Label = passed.find_child("CoinsLine", true, false)
	t.ok(counts == null or not counts.visible, "auto pass hides counts")
	await H.drop(self, [blocked, passed, pair[0]])
	await _auto_one(t, "event_slots", "c0003", false)
	await _auto_one(t, "fate_choices", "c0004", true)
	await _auto_one(t, "gold_story", "c0002", true)


func _auto_one(t, fx: String, uid: String, chooses: bool) -> void:
	var pair: Array = H.boot(self, fx)
	var panel := H.open_panel(self, pair[1], pair[0], PANEL, {"uid": uid})
	var steps: int = await H.drive(self, panel)
	t.ok(steps > 0 and steps < 8, "%s autoplay steps %d" % [uid, steps])
	t.ok(not panel.autoplay_step(), "%s autoplay finished" % uid)
	if chooses:
		t.ok(H.cmds(pair[1], "card.choose").size() >= 1, "%s chose" % uid)
	if uid == "c0003":
		var kinds: Array = []
		var amount := -1
		for row in H.cmds(pair[1], "slot.place"):
			kinds.append(str(row["source"]["kind"]))
			if str(row["source"]["kind"]) == "money":
				amount = int(row["source"]["amount"])
		t.ok(kinds.has("self") and kinds.has("money"), "event places self and money")
		t.eq(amount, 20, "autoplay money is 20")
		t.ok(H.cmds(pair[1], "slot.roll").size() >= 1, "event rolls")
	if uid == "c0004":
		t.eq(str(H.cmds(pair[1], "card.choose")[0]["choice"]), "move_goods", "first enabled choice")
		t.ok(H.cmds(pair[1], "slot.roll").size() >= 1, "fate rolls")
	if uid == "c0002":
		t.eq(str(H.cmds(pair[1], "card.choose")[0]["choice"]), "listen", "gold first choice")
		t.eq(H.cmds(pair[1], "slot.roll").size(), 0, "gold does not roll")
	await H.drop(self, [panel, pair[0]])


func _junk_and_keys(t) -> void:
	var pair: Array = H.boot(self, "event_slots")
	var panel := H.open_panel(self, pair[1], pair[0], PANEL, {"uid": "no-such", "mode": "nope", "extra": 1})
	panel.refresh({})
	panel.open({})
	panel.open({"uid": "c0003"})
	# Warm-up above; median of 5 samples so one slow frame under load does not fail.
	var samples: Array = []
	for _i in 5:
		var t0 := Time.get_ticks_usec()
		panel.open({"uid": "c0003"})
		samples.append(Time.get_ticks_usec() - t0)
	samples.sort()
	var ms := float(samples[samples.size() / 2]) / 1000.0
	print("C03 open_ms %.2f" % ms)
	t.ok(ms <= 50.0, "open panel ms %.2f" % ms)
	await t.frames(1)
	var closes := [0]
	panel.close_requested.connect(func(_r: Dictionary) -> void: closes[0] += 1)
	var ev := InputEventKey.new()
	ev.pressed = true
	ev.keycode = KEY_ESCAPE
	panel._unhandled_input(ev)
	t.eq(closes[0], 1, "esc closes")
	var space := InputEventKey.new()
	space.pressed = true
	space.keycode = KEY_SPACE
	panel.open({"uid": "c0003"})
	panel._unhandled_input(space)
	H.ui_ok(t, panel)
	await H.drop(self, [panel, pair[0]])


## Acceptance 4: after the coins land the spent roll reply is gone; one "go on" reply closes the stage.
func _after_roll(t) -> void:
	var pair: Array = H.boot(self, "event_slots")
	var panel := H.open_panel(self, pair[1], pair[0], PANEL, {"uid": "c0003"}) as CardSlotPanel
	await t.frames(2)
	t.ok(not _reply(panel, "roll").is_empty(), "before the roll: the roll reply is there")
	var closes := [0]
	panel.close_requested.connect(func(_r: Dictionary) -> void: closes[0] += 1)
	panel.on_reply("roll")
	await t.frames(1)
	if panel.checks != null:
		panel.checks.skip_coins()
	await t.frames(2)
	t.eq(H.cmds(pair[1], "slot.roll").size(), 1, "the roll was sent once")
	t.ok(_reply(panel, "roll").is_empty(), "after the coins: no dead roll reply: %s" % str(panel.reply_rows))
	var go := _reply(panel, "continue")
	t.eq(str(go.get("ref", "")), "c03.btn.continue", "after the coins: one go-on reply")
	t.eq(panel.reply_rows.size(), 1, "go on is the only reply")
	t.eq(closes[0], 0, "nothing closed yet")
	panel.on_reply("continue")
	t.eq(closes[0], 1, "go on closes the stage")
	await H.drop(self, [panel, pair[0]])


func _lines_match(t, panel: CardSlotPanel, key: String) -> void:
	var lines: Array = CardStageScript.lines(panel.stage_script, key)
	var shown: Array = []
	for line in lines:
		if typeof(line) != TYPE_DICTIONARY:
			continue
		var ref := str(line.get("ref", ""))
		if bool(line.get("opt", false)) and CardText.is_draft(ref):
			continue
		shown.append(line)
	t.ok(not shown.is_empty(), key + " has a line")
	if shown.is_empty():
		return
	var last: Dictionary = shown[shown.size() - 1]
	var want := CardText.t(str(last.get("ref", "")), last.get("args", {}))
	# Shared root dialog (C01 1.3) holds the line; require bound, tree-visible dialog.
	var dlg = panel.get("dialog")
	t.ok(dlg != null and is_instance_valid(dlg), key + " panel.dialog bound")
	t.ok(dlg != null and (dlg as CanvasItem).is_visible_in_tree(), key + " dialog visible in tree")
	var found := false
	if dlg != null and is_instance_valid(dlg):
		found = _has_text_visible(dlg, want)
	t.ok(found, key + " line is on the visible dialog")


func _slots_at_layout(t, panel: Node, info: Dictionary) -> void:
	var slots: Array = info.get("slots", [])
	for i in slots.size():
		var id := str(slots[i].get("id", ""))
		var widget := panel.find_child("Slot_%s" % id, true, false) as Control
		var rect := CardLayout.slot_rect(i, slots.size())
		t.ok(widget != null, "slot " + id)
		if widget == null:
			continue
		t.eq(widget.position, rect.position, id + " position")
		t.eq(widget.size, rect.size, id + " size")


func _reply(panel: CardSlotPanel, id: String) -> Dictionary:
	for row in panel.reply_rows:
		if str(row.get("id", "")) == id:
			return row
	return {}


func _has_text(node: Node, want: String) -> bool:
	return _has_text_visible(node, want)


func _has_text_visible(node: Node, want: String) -> bool:
	if node is CanvasItem and not (node as CanvasItem).is_visible_in_tree():
		return false
	if node is Label and (node as Label).text == want:
		return true
	if node is Button and (node as Button).text == want:
		return true
	for child in node.get_children():
		if _has_text_visible(child, want):
			return true
	return false
