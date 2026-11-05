# C11 prison scene: slots on the counter, try-reply rolls, fail closes without game.*.
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const Support = preload("res://scripts/tests/cards/C11/support.gd")
const SCENE := "res://scenes/cards/ladder/PrisonPanel.tscn"

var t


func _initialize() -> void:
	t = T.new(self, "C11_prison")
	t.run_async(_body)


func _body() -> void:
	t.no_leaks(Support.load_fx("prison"), "prison")
	t.no_leaks(Support.load_fx("prison_fail"), "prison_fail")
	t.no_leaks(Support.load_fx("prison_stay"), "prison_stay")
	t.no_leaks(Support.load_fx("prison_last_night"), "prison_last_night")
	CardTheme.font_title()
	var bus := CardEventBus.new()
	root.add_child(bus)
	var mock := MockCardEngine.new(bus)
	mock.load_fixture(Support.path("prison"))
	var rig := _open(mock, bus)
	var panel: CardPrisonPanel = rig["panel"]
	panel.open({"uid": "missing"})
	panel.refresh({})
	var t0 := Time.get_ticks_usec()
	panel.open({"uid": "c0015"})
	var dt := int((Time.get_ticks_usec() - t0) / 1000)
	print("C11_PERF prison_open_ms=%d" % dt)
	t.ok(dt < 120, "prison open %d ms" % dt)
	await t.frames(2)
	t.ok(Support.dialog_line(rig["dialog"], "pr.cell#body").size() > 0, "body is spoken")
	t.ok(t.anchor_ok(&"a.prison.slots"), "a.prison.slots before the slots")
	panel.on_reply("try")
	await t.frames(2)
	# b39: after 托人疏通 the roll reply reads like the counter's (coins / heads needed), not 托人疏通 again.
	var roll_row: Dictionary = panel.reply_rows[0] if not panel.reply_rows.is_empty() else {}
	var info: Dictionary = rig["checks"].preview()
	t.eq(str(roll_row.get("id", "")), "roll", "b39 first reply rolls")
	t.ok(str(roll_row.get("ref", "")) in ["c03.reply.roll", "c03.coins.auto_pass"], "b39 roll reply ref")
	t.eq(roll_row.get("args", {}), {"n": int(info.get("coins", 0)), "m": int(info.get("need", 0))}, "b39 coins and need")
	var slots := Support.widgets(rig["checks"])
	t.eq(slots.size(), 3, "three slots on the counter")
	t.eq((slots[0] as Control).position, CardLayout.slot_rect(0, 3).position, "first slot rect")
	t.ok(t.anchor_ok(&"a.prison.slots"), "a.prison.slots on the counter")
	var slot_rect := CardAnchors.rect(&"a.prison.slots")
	t.ok(slot_rect.intersects((slots[0] as Control).get_global_rect()), "anchor covers a slot")
	t.ok(Support.no_percent(panel) and Support.no_percent(rig["dialog"]), "no percent sign")
	var bad: PackedStringArray = t.all_text_from_cardtext(rig["dialog"])
	bad.append_array(t.all_text_from_cardtext(rig["checks"]))
	t.ok(bad.is_empty(), "cardtext " + ",".join(bad))
	(slots[0] as CardSlotWidget).remove_requested.emit("bribe", 0)
	t.eq(Support.last_cmd(mock, "slot.remove"), {"uid": "c0015", "slot": "bribe", "index": 0}, "remove")
	(slots[0] as CardSlotWidget).place_requested.emit("bribe", {"kind": "money", "amount": 40})
	t.eq(Support.last_cmd(mock, "slot.place"),
			{"uid": "c0015", "slot": "bribe", "source": {"kind": "money", "amount": 40}}, "place money")
	(slots[1] as CardSlotWidget).place_requested.emit("bail", {"kind": "contact", "uid": "c0013"})
	t.eq(Support.last_cmd(mock, "slot.place"),
			{"uid": "c0015", "slot": "bail", "source": {"kind": "contact", "uid": "c0013"}}, "place contact")
	(slots[2] as CardSlotWidget).place_requested.emit("favor", {"kind": "kept", "uid": "c0012"})
	t.eq(Support.last_cmd(mock, "slot.place"),
			{"uid": "c0015", "slot": "favor", "source": {"kind": "kept", "uid": "c0012"}}, "place kept")
	var closed := [false]
	panel.close_requested.connect(func(_r: Dictionary) -> void: closed[0] = true)
	panel.on_reply("roll")
	t.eq(panel._faces, [true, true, true], "faces passed to the toss")
	t.eq(panel._need, 3, "need")
	t.eq(panel._success, true, "roll success from ladder result")
	# C03 CounterChecks animates; finish the toss so after.success shows (W0 stub was sync).
	if rig["checks"] != null:
		rig["checks"].skip_coins()
	t.ok(not Support.dialog_line(rig["dialog"], "pr.cell#outcomes.success").is_empty(), "success line")
	await t.frames(2)
	t.ok(closed[0], "success closes after the toss")
	t.eq(Support.game_cmds(mock), 0, "no game command on success")
	var skip := _open(mock, bus)
	var skip_panel: CardPrisonPanel = skip["panel"]
	skip_panel.open({"uid": "c0015"})
	await t.frames(1)
	skip_panel.on_reply("try")
	var skip_closed := [false]
	skip_panel.close_requested.connect(func(_r: Dictionary) -> void: skip_closed[0] = true)
	skip_panel.on_reply("roll")
	# Space skips the C03 coin toss; panel then shows after.* and closes.
	skip_panel._unhandled_input(Support.key(KEY_SPACE))
	if not skip_closed[0] and skip["checks"] != null:
		skip["checks"].skip_coins()
	await t.frames(2)
	t.ok(skip_closed[0], "roll closes; space does not send game")
	t.eq(Support.game_cmds(mock), 0, "space sends no game command")
	var auto := _open(mock, bus)
	var auto_panel: CardPrisonPanel = auto["panel"]
	auto_panel.open({"uid": "c0015"})
	await t.frames(1)
	var start := mock.sent.size()
	var steps := 0
	var auto_closed := [false]
	auto_panel.close_requested.connect(func(_r: Dictionary) -> void: auto_closed[0] = true)
	while auto_panel.autoplay_step():
		steps += 1
		await t.frames(1)
		if steps > 8:
			break
	t.ok(steps <= 8 and auto_closed[0], "autoplay finishes")
	t.ok(not auto_panel.autoplay_step(), "autoplay stops")
	var cmds: Array = []
	for i in range(start, mock.sent.size()):
		cmds.append(mock.sent[i])
	t.eq(cmds[0][1], {"uid": "c0015", "slot": "bribe", "source": {"kind": "money", "amount": 40}}, "auto money")
	t.eq(cmds[1][1], {"uid": "c0015", "slot": "bail", "source": {"kind": "contact", "uid": "c0013"}}, "auto contact")
	t.eq(cmds[2][0], "slot.roll", "auto roll")
	t.eq(cmds[2][1], {"uid": "c0015"}, "auto roll args")
	var mock2 := MockCardEngine.new(bus)
	mock2.load_fixture(Support.path("prison_fail"))
	var fail := _open(mock2, bus)
	var fail_panel: CardPrisonPanel = fail["panel"]
	fail_panel.open({"uid": "c0015"})
	await t.frames(1)
	var fail_closed := [false]
	fail_panel.close_requested.connect(func(_r: Dictionary) -> void: fail_closed[0] = true)
	var fsteps := 0
	while fail_panel.autoplay_step():
		fsteps += 1
		await t.frames(1)
		if fsteps > 8:
			break
	t.ok(fail_closed[0], "fail closes after the result")
	t.eq(fail_panel._faces, [false, true], "fail faces")
	t.eq(Support.game_cmds(mock2), 0, "fail sends no game command")
	t.ok(Support.no_percent(fail_panel), "fail no percent")
	var bad2: PackedStringArray = t.all_text_from_cardtext(fail["dialog"])
	t.ok(bad2.is_empty(), "fail cardtext " + ",".join(bad2))
	var esc := _open(mock2, bus)
	var esc_panel: CardPrisonPanel = esc["panel"]
	esc_panel.open({"uid": "c0015"})
	await t.frames(1)
	var before := mock2.sent.size()
	var esc_closed := [false]
	esc_panel.close_requested.connect(func(_r: Dictionary) -> void: esc_closed[0] = true)
	esc_panel._unhandled_input(Support.key(KEY_ESCAPE))
	t.ok(esc_closed[0], "esc closes prison")
	t.eq(mock2.sent.size(), before, "esc sends no command")
	await _days(bus)
	for node in [panel, rig["stage"], rig["dialog"], rig["checks"], rig["hand"],
			skip_panel, skip["stage"], skip["dialog"], skip["checks"], skip["hand"],
			auto_panel, auto["stage"], auto["dialog"], auto["checks"], auto["hand"],
			fail_panel, fail["stage"], fail["dialog"], fail["checks"], fail["hand"],
			esc_panel, esc["stage"], esc["dialog"], esc["checks"], esc["hand"], bus]:
		if is_instance_valid(node):
			node.queue_free()
	await t.frames(3)


func _days(bus: CardEventBus) -> void:
	var stay_mock := MockCardEngine.new(bus)
	stay_mock.load_fixture(Support.path("prison_stay"))
	var stay := _open(stay_mock, bus)
	var stay_panel: CardPrisonPanel = stay["panel"]
	stay_panel.open({"uid": "c0015"})
	await t.frames(1)
	var line := Support.dialog_line(stay["dialog"], "c11.prison.days")
	t.eq(int(line.get("args", {}).get("n", -1)), 2, "days come from days_left")
	var before := stay_mock.sent.size()
	stay_panel.dismiss()
	t.eq(stay_mock.sent.size(), before, "closing a stay sends nothing")
	var listed := stay_mock.send(&"day.end", {"confirm": false})
	t.eq(str(listed.get("err", "")), CardIds.ERR_MUST_RESOLVE, "stay list blocks the day")
	var items: Array = listed.get("items", [])
	t.eq(str(items[0].get("kind", "")), "stay", "stay row")
	t.eq(items[0].get("args", {}), {"nights": 1, "max": 3}, "stay nights")
	var last_mock := MockCardEngine.new(bus)
	last_mock.load_fixture(Support.path("prison_last_night"))
	var last := _open(last_mock, bus)
	var last_panel: CardPrisonPanel = last["panel"]
	last_panel.open({"uid": "c0015"})
	await t.frames(1)
	var last_line := Support.dialog_line(last["dialog"], "c11.prison.days")
	t.eq(int(last_line.get("args", {}).get("n", -1)), 0, "last night still shows days_left")
	var last_before := last_mock.sent.size()
	last_panel.dismiss()
	t.eq(last_mock.sent.size(), last_before, "closing the last night sends nothing")
	t.eq(Support.game_cmds(last_mock), 0, "the panel does not send game over")
	var confirmed := last_mock.send(&"day.end", {"confirm": true})
	t.ok(bool(confirmed.get("ok", false)), "confirmed last night resolves in the fixture")
	for node in [stay_panel, stay["stage"], stay["dialog"], stay["checks"], stay["hand"],
			last_panel, last["stage"], last["dialog"], last["checks"], last["hand"]]:
		node.queue_free()


func _open(mock: MockCardEngine, bus: CardEventBus) -> Dictionary:
	var panel := (load(SCENE) as PackedScene).instantiate() as CardPrisonPanel
	return Support.mount_stage(root, panel, mock, bus)
