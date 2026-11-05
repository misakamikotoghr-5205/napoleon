# C08: settle lines are spoken in the dialog; dawn sends settle.next.
# Owner C08. Contract 1.3 section 7.11.
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const Support = preload("res://scripts/tests/cards/C08/support.gd")


func _initialize() -> void:
	var t := T.new(self, "C08_settle")
	t.run_async(_body.bind(t))


func _body(t) -> void:
	Support.leaks(t, ["settle_lines"])
	t.ok(CardSettlePanel.LINE_FADE <= 0.6, "each line fade is within 0.6s")
	t.ok(CardSettlePanel.LINE_GAP <= 0.6, "each line step is within 0.6s")
	var mounted: Array = Support.mount(self, "settle_lines")
	var bus: CardEventBus = mounted[0]
	var mock: MockCardEngine = mounted[1]
	var host: CardModalHost = mounted[2]
	var started := Time.get_ticks_usec()
	var panel := host.open_panel(&"settle", {}) as CardSettlePanel
	var open_us := Time.get_ticks_usec() - started
	t.ok(open_us < 2000000, "settle panel opened in %d us" % open_us)
	await _lines(t, mock, panel)
	await _space(t, mock, panel)
	await _enter(t, host, mock)
	await _fast(t, mock, bus)
	await _autoplay(t, host, mock)
	await _moved_on(t, host, mock)
	host.queue_free()
	bus.queue_free()
	await t.frames(2)


func _lines(t, mock: MockCardEngine, panel: CardSettlePanel) -> void:
	var lines: Array = mock.query(&"settle_report", {}).get("lines", [])
	t.eq(lines.size(), 7, "seven settle lines")
	t.ok(not panel._revealed, "lines are still arriving")
	await t.frames(2)
	t.ok(t.anchor_ok(&"a.settle.lines"), "dialog anchor")
	var fan := panel.hand.get_child(0) as Control
	t.ok(fan.position.y >= 760.0, "hand tucks away")
	var refs := _refs(panel.dialog)
	t.ok(refs.has("c08.settle.title"), "title is spoken")
	t.ok(refs.has("g02.settle.ticket"), "first report line is spoken")
	var bad: PackedStringArray = t.all_text_from_cardtext(panel)
	t.ok(bad.is_empty(), "settle text from CardText: %s" % ", ".join(bad))
	Support.no_hidden_numbers(t, panel)
	var shown := Support.blob(panel)
	t.ok(shown.find("%") < 0, "settle text has no percent sign")
	for token in ["rep_points", "heat_points", "conscience", "g03.tier.rep", "g03.tier.heat"]:
		t.ok(shown.find(token) < 0, "settle text hides " + token)


func _space(t, mock: MockCardEngine, panel: CardSettlePanel) -> void:
	# Real C04 DialogBox with non-zero typing speed (GPT #37 regression).
	if panel.dialog != null:
		panel.dialog.chars_per_sec = 40
	mock.sent.clear()
	await Support.tap(self, KEY_SPACE)
	t.ok(panel._revealed, "space finishes the lines")
	_expect_lines(t, panel)
	t.ok(panel.dialog.is_idle(), "first space leaves dialog idle")
	var body := panel.dialog.get("_body") as Label
	t.ok(body != null and body.text != "", "visible settle line is non-empty")
	if body != null and body.visible_characters >= 0:
		t.eq(body.visible_characters, body.text.length(), "last settle line is fully shown")
	var dawn := Support.button_with(panel, CardText.t("c08.reply.dawn"))
	t.ok(dawn != null, "dawn reply is shown")
	t.eq(Support.cmds(mock, "settle.next").size(), 0, "first space does not advance")
	await Support.tap(self, KEY_SPACE)
	t.eq(Support.cmds(mock, "settle.next").size(), 1, "second space settles")
	t.eq(Support.cmds(mock, "settle.next")[0][1], {}, "settle.next takes no args")
	t.eq(str(mock.view().get("phase", "")), "morning", "fixture moves to morning")


func _enter(t, host: CardModalHost, mock: MockCardEngine) -> void:
	mock.load_fixture(Support.fixture("settle_lines"))
	mock.sent.clear()
	var panel := host.open_panel(&"settle", {}) as CardSettlePanel
	t.ok(not panel._revealed, "enter test starts with lines hidden")
	await Support.tap(self, KEY_ENTER)
	t.eq(Support.cmds(mock, "settle.next").size(), 0, "first enter only reveals")
	t.ok(panel._revealed, "enter reveals")
	await Support.tap(self, KEY_KP_ENTER)
	t.eq(Support.cmds(mock, "settle.next").size(), 1, "keypad enter settles")


func _fast(t, mock: MockCardEngine, bus: CardEventBus) -> void:
	mock.load_fixture(Support.fixture("settle_lines"))
	mock.sent.clear()
	var panel := load("res://scenes/cards/night/SettlePanel.tscn").instantiate() as CardSettlePanel
	panel.fast_anim = true
	panel.bind(mock, bus)
	root.add_child(panel)
	panel.open({})
	await t.frames(1)
	t.ok(panel._revealed, "fast_anim shows every line at once")
	_expect_lines(t, panel)
	t.ok(panel.dialog.is_idle(), "fast_anim leaves dialog idle")
	var body := panel.dialog.get("_body") as Label
	t.ok(body != null and body.text != "", "fast_anim visible line is non-empty")
	t.ok(Support.button_with(panel, CardText.t("c08.reply.dawn")) != null, "fast dawn reply")
	await Support.tap(self, KEY_SPACE)
	t.eq(Support.cmds(mock, "settle.next").size(), 1, "fast_anim space settles immediately")
	panel.queue_free()
	await t.frames(1)


func _autoplay(t, host: CardModalHost, mock: MockCardEngine) -> void:
	mock.load_fixture(Support.fixture("settle_lines"))
	var first := _play(host, mock)
	mock.load_fixture(Support.fixture("settle_lines"))
	var second := _play(host, mock)
	t.eq(first, second, "settle autoplay repeats")
	t.eq(first, [true], "autoplay sends settle.next")


func _play(host: CardModalHost, mock: MockCardEngine) -> Array:
	mock.sent.clear()
	var panel := host.open_panel(&"settle", {})
	var stepped := panel.autoplay_step()
	var sent := Support.cmds(mock, "settle.next").size() == 1
	return [stepped and sent]


func _expect_lines(t, panel: CardSettlePanel) -> void:
	var refs := _refs(panel.dialog)
	var lines: Array = panel.engine.query(&"settle_report", {}).get("lines", [])
	var saw_gold := false
	for row in lines:
		var key := str(row.get("key", ""))
		t.ok(refs.has(key), "dialog says " + key)
		if key == "g02.settle.gold_left":
			saw_gold = true
	t.ok(saw_gold, "gold-left line is present")
	var body := panel.dialog.get("_body") as Label
	t.ok(CardText.issued_contains(body.text), "visible line comes from CardText")


func _refs(dialog: CardDialogApi) -> Array:
	var out: Array = []
	for line in dialog.get("_lines"):
		out.append(str(line.get("ref", "")))
	return out


## Bot run 10-25: the corner end-day button (day.end during settle) took the engine to the next morning,
## but the report stayed on top over the whole next day. A view past settle must close the panel.
func _moved_on(t, host: CardModalHost, mock: MockCardEngine) -> void:
	mock.load_fixture(Support.fixture("settle_lines"))
	mock.sent.clear()
	var panel := host.open_panel(&"settle", {}) as CardSettlePanel
	await t.frames(1)
	var same: Dictionary = mock.view().duplicate(true)
	host.refresh(same)
	await t.frames(1)
	t.eq(host.top_kind(), &"settle", "settle stays open while the engine is still in settle")
	var moved: Dictionary = mock.view().duplicate(true)
	moved["phase"] = "morning"
	host.refresh(moved)
	await t.frames(2)
	t.ok(not is_instance_valid(panel) or panel._torn, "settle closes once the engine is past settle")
	t.ok(host.top_kind() != &"settle", "no stale settle report on top")
	t.eq(Support.cmds(mock, "settle.next").size(), 0, "closing on a phase change sends nothing")
