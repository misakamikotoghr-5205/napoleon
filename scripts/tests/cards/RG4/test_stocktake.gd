# RG4 stocktake overlay on the Mock table (ROGUE_V1.md 7.2, fixtures section 13): the engine's open_panel opens it;
# week / few / full / peddler / closed render without errors; each button sends the right stock.pick (mock.sent);
# a relic on a full shelf goes through "give one up" and sends replace; later, Esc and the scrim send nothing;
# refresh closes it once the offer is no longer open; keys 1-3 / Enter / Esc; autoplay picks the first card;
# every word comes from CardText, no percent sign, no digits but the week number and the deal count;
# a.stock.offers sits inside CardLayout.OVERLAY_MAX.
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const H = preload("res://scripts/tests/cards/RG4/rg4_harness.gd")
const Ui = preload("res://scripts/cards/ui/rogue/rogue_ui.gd")
const OfferCard = preload("res://scripts/cards/ui/rogue/offer_card.gd")
const OFFER := "w0.1"


func _initialize() -> void:
	var t := T.new(self, "RG4_stocktake")
	t.run_async(_body.bind(t))


func _body(t) -> void:
	var bus := CardEventBus.new()
	root.add_child(bus)
	await _render_cases(t, bus)
	await _buttons(t, bus)
	await _says_pick(t, bus)
	await _keys(t, bus)
	await _full(t, bus)
	await _peddler(t, bus)
	await _closed(t, bus)
	await _autoplay(t, bus)
	await _standalone(t, bus)
	await _tooltips(t)
	print("RG4_stocktake checks %d" % t.checks)
	bus.queue_free()
	await t.frames(2)


## Boot a fixture; the root opens the overlay from view.open_panel.
func _open(t, bus: CardEventBus, fixture: String) -> CardGameRoot:
	var game := H.boot(self, bus, fixture)
	await t.frames(4)
	t.eq(game.host.top_kind(), &"stocktake", fixture + ": open_panel opens the stocktake overlay")
	return game


func _panel(game: CardGameRoot):
	return game.host.top_overlay()


func _done(game: CardGameRoot) -> void:
	game.queue_free()
	CardAnchors.clear()
	await process_frame
	await process_frame


func _render_cases(t, bus: CardEventBus) -> void:
	var cases := [["rogue_week", 3, 176.0, 3, false], ["rogue_few", 2, 336.0, 1, true]]
	for c in cases:
		var game := await _open(t, bus, c[0])
		var panel = _panel(game)
		if panel == null:
			await _done(game)
			continue
		var cards: Array = panel.cards()
		t.eq(cards.size(), c[1], c[0] + ": card count")
		if not cards.is_empty():
			t.eq((cards[0] as Control).get_global_rect().position, Vector2(c[2], 140.0), c[0] + ": first card at x0, y 140")
			t.eq((cards[0] as Control).size, Vector2(288, 400), c[0] + ": card is 288 x 400")
		var title := CardText.ui("rg4.stock.title.week", {"n": 2})
		var deals := CardText.ui("rg4.stock.deals", {"deals": c[3]})
		t.eq(H.count_text(panel, title), 1, c[0] + ": week title (week + 1)")
		t.eq(H.count_text(panel, deals), 1, c[0] + ": this week's deal count")
		t.eq(H.count_text(panel, CardText.ui("rg4.stock.few")) == 1, c[4], c[0] + ": few line only with two items")
		t.eq(H.count_text(panel, CardText.ui("rg4.stock.how")), 1, c[0] + ": one line on what a pick does")
		_card_words(t, panel, c[0])
		t.eq(t.all_text_from_cardtext(panel).size(), 0, c[0] + ": all words from CardText")
		H.numbers_ok(t, panel, [title, deals], c[0])
		t.ok(t.anchor_in(&"a.stock.offers", CardLayout.OVERLAY_MAX), c[0] + ": a.stock.offers inside the overlay")
		t.no_leaks(game.engine.query(&"stocktake", {"offer": OFFER}), c[0] + " stocktake query")
		await _done(game)


## Depth word, name, use and the flaw / until line per card; frames by depth without any number.
func _card_words(t, panel, label: String) -> void:
	for card in panel.cards():
		var id: String = card.item_id
		var word := "rg4.kind.source" if card.kind == "source" else "rg4.depth." + str(card.look)
		t.eq(H.count_text(card, CardText.ui(word)), 1, "%s %s: depth word" % [label, id])
		t.eq(H.count_text(card, CardText.card(id, "title")), 1, "%s %s: name" % [label, id])
		t.eq(H.count_text(card, CardText.card(id, "use")), 1, "%s %s: use" % [label, id])
		t.ok(H.count_text(card, CardText.ui("rg4.stock.use")) == 1, "%s %s: use mark" % [label, id])
		if card.kind == "source":
			t.eq(H.count_text(card, CardText.ui("rg4.stock.source_until")), 1, "%s %s: lasts to month end" % [label, id])
		else:
			var flaw := CardText.has_text(id + "#lines.flaw")
			t.eq(H.count_text(card, CardText.ui("rg4.stock.flaw")) == 1, flaw, "%s %s: flaw row only with words" % [label, id])
		var take := "rg4.stock.take_source" if card.kind == "source" else "rg4.stock.take_relic"
		t.eq(card.button().text, CardText.ui(take), "%s %s: take button" % [label, id])
		t.eq(card.tooltip_text, CardText.card(id, "body") if _cut(card) else "",
			"%s %s: hovering shows the whole history only when the card cuts it" % [label, id])
		_layout(t, card, "%s %s" % [label, id])
	var looks: Array = []
	for card in panel.cards():
		looks.append(card.look)
	if label == "rogue_week":
		t.eq(looks, ["storied", "source", "plain"], "week: storied, source, plain")


## Inside the card: what the thing does (and its flaw) is never cut off, the words stay between the name and
## the button, the history starts under the name, nothing overlaps.
func _layout(t, card: Control, label: String) -> void:
	var rows: Array = []
	for n in ["Body", "Use", "Flaw", "Until"]:
		var l := card.get_node_or_null(n) as Label
		if l == null or not l.visible:
			continue
		rows.append(l)
		if n == "Use" or n == "Flaw":
			t.ok(l.get_line_count() <= l.get_visible_line_count(), "%s: %s shows every line" % [label, n])
		t.ok(l.position.y >= 200.0 and l.position.y + l.size.y <= 352.0 + 0.5, "%s: %s between name and button" % [label, n])
	for i in range(1, rows.size()):
		var a: Control = rows[i - 1]
		var b: Control = rows[i]
		t.ok(a.position.y + a.size.y <= b.position.y + 0.5, "%s: %s above %s without overlap" % [label, a.name, b.name])
	var button: Control = card.button()
	t.ok(button.position.y >= 356.0 and button.position.y + button.size.y <= 400.0, label + ": button at the bottom")


func _buttons(t, bus: CardEventBus) -> void:
	var rows := [["take 0", 0, {"offer": OFFER, "pick": "rl.chen_mortar"}],
		["take 1", 1, {"offer": OFFER, "pick": "ky.traveling_buyers"}],
		["pass", -1, {"offer": OFFER, "pick": ""}]]
	for row in rows:
		var game := await _open(t, bus, "rogue_week")
		var mock := game.engine as MockCardEngine
		var panel = _panel(game)
		var from := mock.sent.size()
		var b: Button = panel.pass_button() if int(row[1]) < 0 else panel.cards()[int(row[1])].button()
		await H.click(self, b.get_global_rect().get_center())
		await t.frames(2)
		t.eq(H.sent_since(mock, from), [["stock.pick", row[2]]], "click %s sends stock.pick" % row[0])
		t.ok(not game.host.is_open(&"stocktake"), "click %s closes the overlay" % row[0])
		await _done(game)
	for how in ["later", "esc", "scrim", "dismiss"]:
		var game := await _open(t, bus, "rogue_week")
		var mock := game.engine as MockCardEngine
		var panel = _panel(game)
		var from := mock.sent.size()
		match how:
			"later":
				await H.click(self, panel.later_button().get_global_rect().get_center())
			"esc":
				await H.tap(self, KEY_ESCAPE)
			"scrim":
				await H.click(self, Vector2(40, 700))
			_:
				panel.dismiss()
		await t.frames(2)
		t.eq(H.sent_since(mock, from), [], how + " sends nothing")
		t.ok(not game.host.is_open(&"stocktake"), how + " closes the overlay")
		await _done(game)


## A pick that went through: the notices it added (gain / released / passed) are said in the dialog at once; a night
## pick's notice board would be wiped at dawn before anyone read it.
func _says_pick(t, bus: CardEventBus) -> void:
	var game := await _open(t, bus, "rogue_week")
	var mock := game.engine as MockCardEngine
	var gain := "ky.traveling_buyers#lines.gain"
	mock._fx["responses"].push_front({"cmd": "stock.pick", "match": {"pick": "ky.traveling_buyers"},
		"patch": [{"op": "append", "path": "notice.news", "value": {"key": gain, "args": {}}}],
		"result": {"ok": true, "err": ""}})
	# Like the real engine: by the time the pick's view_changed reaches the overlay, the offer reads as picked.
	var answer: Dictionary = mock._fx["queries"][MockCardEngine.query_key(&"stocktake", {"offer": OFFER})]
	var picked := func(cmd: StringName, _a: Dictionary, _ok: bool) -> void:
		if cmd == &"stock.pick":
			answer["status"] = "picked"
	bus.command_done.connect(picked)
	_panel(game).cards()[1].button().pressed.emit()
	await t.frames(3)
	bus.command_done.disconnect(picked)
	# Acceptance 3: at settle the settle stage opens next and says its report line by line; the gain line comes after
	# the report, last before "dawn", so the report lines never push it out of sight.
	t.eq(game.host.top_kind(), &"settle", "the settle stage opens after the pick")
	await create_timer(1.6).timeout
	var refs: Array = []
	for row in game.dialog.get("_lines"):
		refs.append(str(row.get("ref", "")))
	t.ok(CardText.has_text(gain) and refs.has(gain), "the pick's gain line is said in the dialog: " + str(refs))
	t.eq(refs.back() if not refs.is_empty() else "", gain, "the gain line is the last line, after the report: " + str(refs))
	t.ok(refs.size() > 2, "the settle report is said too: " + str(refs))
	t.ok(game.dialog.has_replies(), "dawn is offered under the gain line")
	t.ok(not refs.has("w0.mock.notice"), "only what the pick added, not the whole board")
	await _done(game)


func _keys(t, bus: CardEventBus) -> void:
	var game := await _open(t, bus, "rogue_week")
	var mock := game.engine as MockCardEngine
	var panel = _panel(game)
	var from := mock.sent.size()
	await H.tap(self, KEY_3)
	t.eq(panel.selected(), 2, "key 3 picks the third card")
	t.ok(panel.cards()[2].is_selected() and not panel.cards()[0].is_selected(), "only the picked card has the gold edge")
	await H.tap(self, KEY_2)
	t.eq(panel.selected(), 1, "key 2 picks the second card")
	t.eq(H.sent_since(mock, from), [], "picking a card sends nothing")
	await H.tap(self, KEY_ENTER)
	await t.frames(1)
	t.eq(H.sent_since(mock, from), [["stock.pick", {"offer": OFFER, "pick": "ky.traveling_buyers"}]],
		"Enter presses the picked card's button")
	t.ok(not game.host.is_open(&"stocktake"), "Enter's pick closes the overlay")
	await _done(game)
	game = await _open(t, bus, "rogue_week")
	mock = game.engine as MockCardEngine
	from = mock.sent.size()
	await H.tap(self, KEY_ENTER)
	await t.frames(1)
	t.eq(H.sent_since(mock, from), [], "Enter with no card picked does not pick (focus rests on later)")
	await _done(game)


func _full(t, bus: CardEventBus) -> void:
	var game := await _open(t, bus, "rogue_full")
	var mock := game.engine as MockCardEngine
	var panel = _panel(game)
	var from := mock.sent.size()
	panel.cards()[0].button().pressed.emit()
	await t.frames(1)
	t.ok(panel.in_release_step(), "full shelf: taking a relic opens the release step")
	t.eq(H.sent_since(mock, from), [], "the release step sends nothing yet")
	var row: Control = panel.release_row()
	t.ok(row != null and row.held.size() == 6, "release step lists the six held relics")
	t.eq(H.count_text(panel, CardText.ui("rg4.stock.full")), 1, "release step says the shelf is full")
	t.ok(row != null and row.ok_button().disabled, "confirm waits for a held relic")
	t.ok(panel.cards()[0].button().disabled and panel.cards()[0].is_selected(), "the new relic stays marked, buttons rest")
	if row != null:
		var r := row.get_global_rect()
		t.ok(CardLayout.OVERLAY_MAX.encloses(r), "release step inside the overlay")
		t.eq(row.cell(0).get_global_rect(), Rect2(418, 580, 64, 64), "first held cell at (418, 580) 64 x 64")
		t.eq(row.cell(1).get_global_rect().position.x, 494.0, "held cells 12 px apart")
		var cancel: Rect2 = row.cancel_button().get_global_rect()
		t.ok(cancel.end.y <= CardLayout.OVERLAY_MAX.end.y - 14.0, "never mind ends above the sheet's inner frame " + str(cancel))
		t.ok(not cancel.intersects(row.ok_button().get_global_rect()), "the two buttons do not overlap")
		var tip: String = row.cell(0).tooltip_text
		t.ok(tip.contains(CardText.card("rl.stub_box", "title")) and tip.contains(CardText.card("rl.stub_box", "use")),
			"hovering a held relic shows its name and what it does")
	t.eq(t.all_text_from_cardtext(panel).size(), 0, "release step words from CardText")
	await H.tap(self, KEY_ESCAPE)
	t.ok(game.host.is_open(&"stocktake") and not panel.in_release_step(), "Esc steps back to the cards")
	panel.cards()[0].button().pressed.emit()
	await t.frames(1)
	await H.click(self, panel.release_row().cancel_button().get_global_rect().get_center())
	await t.frames(1)
	t.ok(not panel.in_release_step(), "never mind goes back to the cards")
	panel.cards()[0].button().pressed.emit()
	await t.frames(1)
	await H.tap(self, KEY_1)
	t.eq(panel.release_row().picked_id(), "rl.stub_box", "key 1 marks the first held relic")
	t.ok(not panel.release_row().ok_button().disabled, "confirm opens once a relic is marked")
	await H.tap(self, KEY_ENTER)
	await t.frames(1)
	t.eq(H.sent_since(mock, from), [["stock.pick", {"offer": OFFER, "pick": "rl.chen_mortar", "replace": "rl.stub_box"}]],
		"Enter sends the pick with replace")
	t.ok(not game.host.is_open(&"stocktake"), "the swap closes the overlay")
	await _done(game)
	game = await _open(t, bus, "rogue_full")
	mock = game.engine as MockCardEngine
	panel = _panel(game)
	from = mock.sent.size()
	await H.click(self, panel.cards()[1].button().get_global_rect().get_center())
	await t.frames(1)
	t.eq(H.sent_since(mock, from), [["stock.pick", {"offer": OFFER, "pick": "ky.traveling_buyers"}]],
		"full shelf: a source needs no release step")
	await _done(game)
	await _full_refused(t, bus)


## The engine says relic_full although the overlay thought there was room: it asks again and lands on the
## release step instead of failing.
func _full_refused(t, bus: CardEventBus) -> void:
	var m := H.mock(bus, "rogue_full")
	var key := MockCardEngine.query_key(&"stocktake", {"offer": OFFER})
	var stale: Dictionary = m._fx["queries"][key].duplicate(true)
	stale["full"] = false
	m._fx["queries"][key] = stale
	var panel = load(H.STOCKTAKE_SCENE).instantiate()
	panel.bind(m, bus)
	root.add_child(panel)
	panel.open({"offer": OFFER})
	await t.frames(1)
	stale = stale.duplicate(true)
	stale["full"] = true
	m._fx["queries"][key] = stale
	panel.cards()[0].button().pressed.emit()
	await t.frames(1)
	t.eq(m.sent.back(), ["stock.pick", {"offer": OFFER, "pick": "rl.chen_mortar"}], "stale view sends the plain pick")
	t.ok(panel.in_release_step(), "relic_full turns into the release step")
	panel.queue_free()
	await t.frames(1)


func _peddler(t, bus: CardEventBus) -> void:
	var game := await _open(t, bus, "rogue_peddler")
	var mock := game.engine as MockCardEngine
	var panel = _panel(game)
	if panel == null:
		await _done(game)
		return
	t.eq(H.count_text(panel, CardText.ui("rg4.stock.title.peddler")), 1, "peddler title")
	t.eq(H.count_text(panel, CardText.ui("rg4.stock.peddler_sub")), 1, "peddler sub line")
	t.eq(H.count_text(panel, CardText.ui("rg4.stock.deals", {"deals": 0})), 0, "no deal count for the peddler")
	t.eq(panel.cards().size(), 2, "peddler: two cards")
	for card in panel.cards():
		t.eq(card.look, "plain", "peddler card is plain")
	H.numbers_ok(t, panel, [], "peddler")
	t.eq(t.all_text_from_cardtext(panel).size(), 0, "peddler words from CardText")
	t.ok(t.anchor_in(&"a.stock.offers", CardLayout.OVERLAY_MAX), "peddler: anchor inside the overlay")
	var from := mock.sent.size()
	await H.click(self, panel.cards()[0].button().get_global_rect().get_center())
	await t.frames(2)
	t.eq(H.sent_since(mock, from), [["stock.pick", {"offer": "p8", "pick": "rl.blue_curtain"}]], "peddler pick")
	t.ok(not game.host.is_open(&"stocktake"), "peddler pick closes")
	await _done(game)


func _closed(t, bus: CardEventBus) -> void:
	var game := await _open(t, bus, "rogue_closed")
	var mock := game.engine as MockCardEngine
	var panel = _panel(game)
	if panel != null:
		t.eq(panel.cards().size(), 0, "a lapsed offer shows no cards")
		t.eq(H.count_text(panel, CardText.ui("rg2.reason.offer_closed")), 1, "a lapsed offer says so")
		var from := mock.sent.size()
		panel.refresh(mock.view())
		await t.frames(2)
		t.ok(not game.host.is_open(&"stocktake"), "refresh closes an overlay whose offer is not open")
		t.eq(H.sent_since(mock, from), [], "closing on refresh sends nothing")
	await _done(game)
	game = await _open(t, bus, "rogue_week")
	mock = game.engine as MockCardEngine
	panel = _panel(game)
	var key := MockCardEngine.query_key(&"stocktake", {"offer": OFFER})
	panel.refresh(mock.view())
	await t.frames(1)
	t.ok(game.host.is_open(&"stocktake"), "refresh keeps an open offer")
	mock._fx["queries"][key]["status"] = "picked"
	panel.refresh(mock.view())
	await t.frames(2)
	t.ok(not game.host.is_open(&"stocktake"), "refresh closes once the offer was picked elsewhere")
	await _done(game)


func _autoplay(t, bus: CardEventBus) -> void:
	for c in [["rogue_week", {"offer": OFFER, "pick": "rl.chen_mortar"}],
			["rogue_full", {"offer": OFFER, "pick": "rl.chen_mortar", "replace": "rl.stub_box"}],
			["rogue_peddler", {"offer": "p8", "pick": "rl.blue_curtain"}]]:
		var game := await _open(t, bus, c[0])
		var mock := game.engine as MockCardEngine
		var panel = _panel(game)
		var from := mock.sent.size()
		t.ok(panel.autoplay_step(), c[0] + ": autoplay takes a step")
		t.eq(H.sent_since(mock, from), [["stock.pick", c[1]]], c[0] + ": autoplay picks the first card")
		t.ok(not panel.autoplay_step(), c[0] + ": then nothing left to do")
		await _done(game)
	var game := await _open(t, bus, "rogue_closed")
	t.ok(not _panel(game).autoplay_step(), "autoplay does nothing on a lapsed offer")
	await _done(game)


## W0 smoke shape: no stocktake answer at all (Mock day_full) -> quiet empty state; a failed pick shows one line.
func _standalone(t, bus: CardEventBus) -> void:
	var m := H.mock(bus, "day_full")
	var panel = load(H.STOCKTAKE_SCENE).instantiate()
	panel.bind(m, bus)
	root.add_child(panel)
	panel.open({"uid": "c0002"})
	await t.frames(1)
	t.eq(panel.cards().size(), 0, "no stocktake answer: no cards")
	t.eq(H.count_text(panel, CardText.ui("rg2.reason.offer_closed")), 1, "no stocktake answer: one quiet line")
	var got: Array = []
	panel.close_requested.connect(func(r: Dictionary) -> void: got.append(r))
	panel.refresh(m.view())
	t.eq(got, [{}], "refresh closes the empty overlay")
	panel.queue_free()
	await t.frames(1)
	m = H.mock(bus, "rogue_week")
	m._fx["responses"].push_front({"cmd": "stock.pick", "match": {}, "result": {"ok": false, "err": "already_resolved"}})
	panel = load(H.STOCKTAKE_SCENE).instantiate()
	panel.bind(m, bus)
	root.add_child(panel)
	panel.open({"offer": OFFER})
	await t.frames(1)
	got = []
	panel.close_requested.connect(func(r: Dictionary) -> void: got.append(r))
	panel.cards()[1].button().pressed.emit()
	await t.frames(1)
	t.eq(H.count_text(panel, CardText.ui("rg2.reason.offer_closed")), 1, "a refused pick shows the closed line")
	t.eq(panel.cards().size(), 0, "a refused pick takes the cards away")
	panel.refresh(m.view())
	t.eq(got, [], "the refusal line waits for the player")
	await H.tap(self, KEY_ENTER)
	t.eq(got, [{}], "Enter closes the refusal line")
	panel.queue_free()
	await t.frames(1)


## True when the card could not print the whole history (ellipsis, or no room at all).
func _cut(card) -> bool:
	var body := card.find_child("Body", true, false) as Label
	if body == null:
		return false
	return not body.visible or Ui.lines_of(body.text, body.size.x, 14) > body.max_lines_visible


## Acceptance 6: every relic and source in the data. A history printed whole has no tooltip (it only covered the
## next card); a cut one keeps it, and the tooltip wraps to the card's width instead of one long line.
func _tooltips(t) -> void:
	var counts := {"whole": 0, "cut": 0}
	for pair in [["res://data/cards/era/common/relics.json", "relic"], ["res://data/cards/era/common/sources.json", "source"]]:
		var data = CardDB.read_json(pair[0])
		for row in data.get("cards", []):
			var card = OfferCard.new()
			card.setup({"id": str(row.get("id", "")), "kind": pair[1], "art": "", "depth": str(row.get("depth", ""))}, 0)
			root.add_child(card)
			var full := CardText.card(str(row["id"]), "body")
			if _cut(card):
				counts["cut"] += 1
				t.eq(card.tooltip_text, full, "%s: cut history shows on hover" % row["id"])
				var tip = card._make_custom_tooltip(card.tooltip_text)
				t.ok(tip is Label and (tip as Label).autowrap_mode != TextServer.AUTOWRAP_OFF
					and (tip as Label).custom_minimum_size.x <= OfferCard.SIZE.x, "%s: the tooltip wraps at the card width" % row["id"])
				if tip is Node:
					(tip as Node).free()
			else:
				counts["whole"] += 1
				t.eq(card.tooltip_text, "", "%s: a history printed whole has no tooltip" % row["id"])
			card.free()
	print("RG4_stocktake tooltips %s" % str(counts))
	t.ok(counts["whole"] > 0, "some histories fit on the card")
	await t.frames(1)
