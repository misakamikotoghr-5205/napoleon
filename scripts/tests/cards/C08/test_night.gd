# C08: night cards are played from the fan; choices are replies; sleep sends def "".
# Owner C08. Contract 1.3 section 7.11.
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const Support = preload("res://scripts/tests/cards/C08/support.gd")


func _initialize() -> void:
	var t := T.new(self, "C08_night")
	t.run_async(_body.bind(t))


func _body(t) -> void:
	Support.leaks(t, ["night", "night_choices", "night_empty", "night_candle"])
	var mounted: Array = Support.mount(self, "night")
	var bus: CardEventBus = mounted[0]
	var mock: MockCardEngine = mounted[1]
	var host: CardModalHost = mounted[2]
	await _esc_on_table(t)
	await _bare(t, host, mock)
	await _keys(t, host, mock)
	mock.load_fixture(Support.fixture("night_choices"))
	await _choices(t, host, mock)
	await _autoplay_same(t, host, mock)
	mock.load_fixture(Support.fixture("night_empty"))
	await _empty(t, host, mock)
	mock.load_fixture(Support.fixture("night_candle"))
	await _candle(t, host, mock)
	mock.load_fixture(Support.fixture("night"))
	var started := Time.get_ticks_usec()
	host.open_panel(&"night", {})
	var open_us := Time.get_ticks_usec() - started
	t.ok(open_us < 2000000, "night panel opened in %d us" % open_us)
	host.queue_free()
	bus.queue_free()
	await t.frames(2)


func _bare(t, host: CardModalHost, mock: MockCardEngine) -> void:
	mock.sent.clear()
	var panel := host.open_panel(&"night", {}) as CardNightPanel
	await t.frames(2)
	var cards := Support.offers(panel)
	t.eq(cards.size(), 3, "three night cards")
	var defs := ["nt.tidy", "nt.family_dinner", "nt.early_sleep"]
	for i in range(cards.size()):
		var card := cards[i] as CardWidget
		t.eq(card.custom_minimum_size, Vector2(144, 200), "hand size")
		var title := CardText.card(defs[i], "title")
		var shown := false
		for node in card.get_children():
			if node is Label and (node as Label).text == title:
				shown = true
		t.ok(shown, "title shown for " + defs[i])
	var sleep := Support.sleep_card(panel)
	t.ok(sleep != null, "sleep sits in the fan")
	t.ok(t.anchor_ok(&"a.night.offers"), "fan anchor")
	var bad: PackedStringArray = t.all_text_from_cardtext(panel)
	t.ok(bad.is_empty(), "night text from CardText: %s" % ", ".join(bad))
	Support.no_hidden_numbers(t, panel)
	t.ok(Support.blob(panel).contains(CardText.ui("c08.narr.night_open")), "opening line")
	Support.play_hand(cards[1])
	t.eq(Support.cmds(mock, "night.choose").size(), 1, "bare dinner sends once")
	t.eq(Support.cmds(mock, "night.choose")[0][1], {"def": "nt.family_dinner"}, "bare id has no choice")


func _keys(t, host: CardModalHost, mock: MockCardEngine) -> void:
	mock.load_fixture(Support.fixture("night"))
	mock.sent.clear()
	var panel := host.open_panel(&"night", {}) as CardNightPanel
	await t.frames(2)
	await Support.tap(self, KEY_2)
	t.eq(Support.cmds(mock, "night.choose").size(), 0, "2 only selects")
	var cards := Support.offers(panel)
	t.ok(Support.highlighted(cards[1]), "key select highlights")
	await Support.tap(self, KEY_ENTER)
	t.eq(Support.cmds(mock, "night.choose").size(), 1, "enter plays the selection")
	t.eq(Support.cmds(mock, "night.choose")[0][1], {"def": "nt.family_dinner"}, "enter sends the bare def")


func _esc_on_table(t) -> void:
	var bus := CardEventBus.new()
	root.add_child(bus)
	var game: CardGameRoot = load(CardIds.ROOT_SCENE).instantiate()
	game.boot({"mock": true, "bus": bus, "fixture": Support.fixture("night"), "skip_title": true, "guide": "off"})
	root.add_child(game)
	await t.frames(4)
	t.eq(game.host.top_kind(), &"night", "table opens the night panel")
	var mock := game.engine as MockCardEngine
	mock.sent.clear()
	await Support.tap(self, KEY_ESCAPE)
	await t.frames(2)
	t.eq(Support.cmds(mock, "night.choose").size(), 1, "esc chooses nothing")
	t.eq(Support.cmds(mock, "night.choose")[0][1], {"def": ""}, "esc sends an empty def")
	t.ok(game.host.top_kind() != &"night", "esc dismisses night")
	game.queue_free()
	bus.queue_free()
	await t.frames(2)


func _choices(t, host: CardModalHost, mock: MockCardEngine) -> void:
	mock.sent.clear()
	var panel := host.open_panel(&"night", {})
	await t.frames(2)
	var cards := Support.offers(panel)
	t.eq(cards.size(), 3, "choice fixture still shows three cards")
	Support.play_hand(cards[1])
	t.eq(Support.cmds(mock, "night.choose").size(), 1, "bare tidy sends immediately")
	t.eq(Support.cmds(mock, "night.choose")[0][1], {"def": "nt.tidy"}, "tidy has no choice key")
	mock.sent.clear()
	var dinner := host.open_panel(&"night", {})
	await t.frames(1)
	var offered := Support.offers(dinner)
	Support.play_hand(offered[0])
	t.eq(Support.cmds(mock, "night.choose").size(), 0, "dinner waits for a reply")
	var first_text := CardText.card("nt.family_dinner", "choices.waive_life")
	var second_text := CardText.card("nt.family_dinner", "choices.family_word")
	var first := Support.button_with(dinner, first_text)
	var second := Support.button_with(dinner, second_text)
	t.ok(first != null and second != null, "two replies")
	var bad: PackedStringArray = t.all_text_from_cardtext(dinner)
	t.ok(bad.is_empty(), "choice text from CardText: %s" % ", ".join(bad))
	second.pressed.emit()
	t.eq(Support.cmds(mock, "night.choose").size(), 1, "one night.choose")
	t.eq(Support.cmds(mock, "night.choose")[0][1],
		{"choice": "family_word", "def": "nt.family_dinner"}, "choice is sent with the def")
	mock.load_fixture(Support.fixture("night_choices"))
	mock.sent.clear()
	var early := host.open_panel(&"night", {})
	await t.frames(1)
	mock.sent.clear()
	Support.play_hand(Support.offers(early)[2])
	t.eq(Support.cmds(mock, "night.choose")[0][1], {"def": "nt.early_sleep"}, "empty choices send only the def")


func _empty(t, host: CardModalHost, mock: MockCardEngine) -> void:
	mock.sent.clear()
	var panel := host.open_panel(&"night", {})
	await t.frames(2)
	t.eq(Support.offers(panel).size(), 0, "no night cards")
	t.ok(Support.blob(panel).contains(CardText.ui("c08.night.skip")), "skip line")
	var sleep := Support.sleep_card(panel)
	t.ok(sleep != null, "sleep remains")
	Support.play_sleep(panel)
	t.eq(Support.cmds(mock, "night.choose").size(), 1, "sleep sends once")
	t.eq(Support.cmds(mock, "night.choose")[0][1], {"def": ""}, "sleep chooses nothing")
	mock.load_fixture(Support.fixture("night_empty"))
	mock.sent.clear()
	var again := host.open_panel(&"night", {})
	await t.frames(1)
	await Support.tap(self, KEY_ESCAPE)
	t.eq(Support.cmds(mock, "night.choose").size(), 1, "esc on an empty night sends once")
	t.eq(Support.cmds(mock, "night.choose")[0][1], {"def": ""}, "empty esc chooses nothing")


func _candle(t, host: CardModalHost, mock: MockCardEngine) -> void:
	mock.sent.clear()
	var panel := host.open_panel(&"night", {}) as CardNightPanel
	await t.frames(2)
	Support.play_hand(Support.offers(panel)[0])
	t.eq(Support.cmds(mock, "night.choose").size(), 0, "candle card waits for the reply")
	var script: Dictionary = panel.stage.get("_script")
	t.eq(str(script.get("set", "")), "candle", "back door uses the candle set")
	Support.button_with(panel, CardText.card("nt.backdoor", "choices.look")).pressed.emit()
	t.eq(Support.cmds(mock, "night.choose")[0][1],
		{"choice": "look", "def": "nt.backdoor"}, "candle reply is sent")


func _autoplay_same(t, host: CardModalHost, mock: MockCardEngine) -> void:
	mock.load_fixture(Support.fixture("night_choices"))
	var first := _play(host, mock)
	mock.load_fixture(Support.fixture("night_choices"))
	var second := _play(host, mock)
	t.eq(first, second, "night autoplay repeats")
	t.eq(first, [{"choice": "waive_life", "def": "nt.family_dinner"}], "autoplay takes the first choice")
	mock.load_fixture(Support.fixture("night"))
	var bare := _play(host, mock)
	t.eq(bare, [{"def": "nt.tidy"}], "bare autoplay sends only the first def")


func _play(host: CardModalHost, mock: MockCardEngine) -> Array:
	mock.sent.clear()
	var panel := host.open_panel(&"night", {})
	panel.autoplay_step()
	if Support.cmds(mock, "night.choose").is_empty():
		return []
	return [Support.cmds(mock, "night.choose")[0][1]]
