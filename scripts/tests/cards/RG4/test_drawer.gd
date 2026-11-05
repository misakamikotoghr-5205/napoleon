# RG4 curio shelf drawer (relics, right drawer; ROGUE_V1.md 7.3, fixtures section 13): rogue_drawer shows the count
# line, four relic rows (picture x2, name, depth word, use, flaw when written) and the two sources at the door;
# rogue_street dims every row and says the relics rest; day_full (no relics / stock in the view) shows the quiet
# empty state; rogue_drawer_pending's button hands over to the stocktake overlay (close_requested next) and the
# root opens it; a.relics.list sits in the drawer's content box; the drawer sends no command of its own;
# every word comes from CardText and the only digits are the visible counts; each relic row prints its whole history;
# root autoplay opens a panel the engine asks for a bounded number of times a day (no ping-pong).
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const H = preload("res://scripts/tests/cards/RG4/rg4_harness.gd")
const DrawerHost = preload("res://scripts/cards/ui/table/drawer_host.gd")


func _initialize() -> void:
	var t := T.new(self, "RG4_drawer")
	t.run_async(_body.bind(t))


func _body(t) -> void:
	var bus := CardEventBus.new()
	root.add_child(bus)
	await _plain(t, bus)
	await _street(t, bus)
	await _empty(t, bus)
	await _standalone_empty(t, bus)
	await _pending(t, bus)
	await _refresh(t, bus)
	await _autoplay_once(t, bus)
	print("RG4_drawer checks %d" % t.checks)
	bus.queue_free()
	await t.frames(2)


## Boot a fixture, clear whatever the root opened from the view, then open the drawer like the curio hotspot does.
func _open(t, bus: CardEventBus, fixture: String) -> CardGameRoot:
	var game := H.boot(self, bus, fixture)
	await t.frames(4)
	while game.host.top_panel() != null:
		game.host.close_panel(game.host.top_panel())
	game.dialog.clear()
	await t.frames(1)
	game.host.open_panel(&"relics", {})
	await t.frames(3)
	t.eq(game.host.top_kind(), &"relics", fixture + ": the relics drawer is open")
	return game


func _done(game: CardGameRoot) -> void:
	game.queue_free()
	CardAnchors.clear()
	await process_frame
	await process_frame


func _drawer(game: CardGameRoot):
	return game.host.drawer_panel()


func _rows(drawer) -> Array:
	var out: Array = []
	if drawer.rows() == null:
		return out
	for child in drawer.rows().get_children():
		if child is PanelContainer and child.has_meta("item"):
			out.append(child)
	return out


func _sources(drawer) -> Array:
	var out: Array = []
	for n in H.walk(drawer):
		if n is PanelContainer and str(n.name).begins_with("Source") and n.has_meta("item"):
			out.append(n)
	return out


func _plain(t, bus: CardEventBus) -> void:
	var game := await _open(t, bus, "rogue_drawer")
	var mock := game.engine as MockCardEngine
	var drawer = _drawer(game)
	var from := mock.sent.size()
	var rows := _rows(drawer)
	var ids: Array = []
	for r in rows:
		ids.append(str(r.get_meta("item")))
	t.eq(ids, ["rl.stub_box", "rl.camphor_chest", "rl.oilpaper_umbrella", "rl.rosewood_abacus"], "four relic rows in held order")
	var count := CardText.ui("rg4.relics.count", {"n": 4, "cap": 6})
	t.eq(H.count_text(drawer, count), 1, "count line: n of cap cells")
	t.eq(H.count_text(drawer, CardText.ui("rg4.relics.dormant")), 0, "no resting line while the shop is open")
	t.eq(H.count_text(drawer, CardText.ui("rg4.relics.empty")), 0, "no empty line with relics held")
	for r in rows:
		_row_words(t, r)
	var looks := {"rl.stub_box": "plain", "rl.camphor_chest": "storied", "rl.rosewood_abacus": "treasure"}
	for r in rows:
		var id := str(r.get_meta("item"))
		if looks.has(id):
			t.eq(H.count_text(r, CardText.ui("rg4.depth." + str(looks[id]))), 1, id + ": depth word")
		t.ok(r.size.y >= 96.0 and r.size.x >= 360.0, id + ": row is a full-width line at least 96 high")
		var pic := r.find_child("Picture", true, false) as Control
		t.ok(pic != null and pic.size == Vector2(64, 64), id + ": picture x2 (64 x 64)")
	var sources := _sources(drawer)
	t.eq(sources.size(), 2, "two sources at the door")
	t.eq(H.count_text(drawer, CardText.ui("rg4.relics.sources")), 1, "sources section head")
	t.eq(H.count_text(drawer, CardText.ui("rg4.stock.source_until")), 2, "each source lasts to month end")
	for s in sources:
		var id := str(s.get_meta("item"))
		t.eq(H.count_text(s, CardText.card(id, "title")), 1, id + ": source name")
		t.eq(H.count_text(s, CardText.card(id, "use")), 1, id + ": source use")
	t.eq(H.count_text(drawer, CardText.ui("rg4.relics.sources_empty")), 0, "no empty sources line")
	t.ok(drawer.pending_button() == null, "no pending button without an open offer")
	t.ok(t.anchor_ok(&"a.relics.list"), "a.relics.list is on screen")
	var box := DrawerHost.content_rect("r")
	var list := CardAnchors.rect(&"a.relics.list")
	t.ok(list.position.x >= box.position.x and list.end.x <= box.end.x and list.position.y >= box.position.y,
		"a.relics.list inside the right drawer content (%s in %s)" % [str(list), str(box)])
	t.eq(t.all_text_from_cardtext(drawer).size(), 0, "drawer words from CardText")
	H.numbers_ok(t, drawer, [count], "drawer")
	t.ok(drawer.autoplay_step(), "autoplay looks once")
	await t.frames(2)
	t.ok(not game.host.is_open(&"relics"), "autoplay closes the drawer")
	t.eq(H.sent_since(mock, from), [], "the drawer sends no command")
	await _done(game)


## Name, use, and the flaw line exactly when the relic has one written.
func _row_words(t, row: Control) -> void:
	var id := str(row.get_meta("item"))
	t.eq(H.count_text(row, CardText.card(id, "title")), 1, id + ": name")
	t.eq(H.count_text(row, CardText.card(id, "use")), 1, id + ": use")
	t.eq(H.count_text(row, CardText.card(id, "body")), 1, id + ": the whole history")
	# Probe the row itself (its mark and node), not the flaw words: a stray flaw row for a relic without one shows
	# the mark and a draft line, never the words looked for.
	var flaw := CardText.has_text(id + "#lines.flaw")
	t.eq(H.count_text(row, CardText.ui("rg4.stock.flaw")) == 1, flaw, id + ": flaw mark only when a flaw is written")
	t.eq(row.find_child("FlawRow", true, false) != null, flaw, id + ": flaw row only when a flaw is written")
	if flaw:
		t.eq(H.count_text(row, CardText.card(id, "lines.flaw")), 1, id + ": flaw words")


func _street(t, bus: CardEventBus) -> void:
	var game := await _open(t, bus, "rogue_street")
	var drawer = _drawer(game)
	var rows := _rows(drawer)
	t.eq(rows.size(), 3, "street: the three held relics are still listed")
	t.eq(H.count_text(drawer, CardText.ui("rg4.relics.dormant")), 1, "street: the relics rest")
	for r in rows:
		t.ok(r.modulate.is_equal_approx(CardTheme.color(&"ink_soft")), "street: row dimmed " + str(r.get_meta("item")))
	var count := CardText.ui("rg4.relics.count", {"n": 3, "cap": 6})
	t.eq(H.count_text(drawer, count), 1, "street: count line")
	t.eq(t.all_text_from_cardtext(drawer).size(), 0, "street words from CardText")
	H.numbers_ok(t, drawer, [count], "street drawer")
	await _done(game)


## Mock day_full has no relics / stock keys: the quiet empty state, nothing else.
func _empty(t, bus: CardEventBus) -> void:
	var game := await _open(t, bus, "day_full")
	var drawer = _drawer(game)
	t.eq(_rows(drawer).size(), 0, "day_full: no relic rows")
	t.eq(H.count_text(drawer, CardText.ui("rg4.relics.empty")), 1, "day_full: empty line")
	t.eq(H.count_text(drawer, CardText.ui("rg4.relics.sources_empty")), 1, "day_full: no sources yet")
	t.ok(drawer.pending_button() == null, "day_full: no pending button")
	t.ok(t.anchor_ok(&"a.relics.list"), "day_full: a.relics.list still on screen")
	t.eq(t.all_text_from_cardtext(drawer).size(), 0, "day_full words from CardText")
	H.numbers_ok(t, drawer, [], "empty drawer")
	await _done(game)


## W0 smoke shape: the scene alone, bound to the Mock, opened with a card uid.
func _standalone_empty(t, bus: CardEventBus) -> void:
	var m := H.mock(bus, "day_full")
	var drawer = load(H.DRAWER_SCENE).instantiate()
	drawer.bind(m, bus)
	root.add_child(drawer)
	drawer.open({"uid": "c0002"})
	drawer.refresh(m.view())
	await t.frames(1)
	t.eq(H.count_text(drawer, CardText.ui("rg4.relics.empty")), 1, "standalone: empty line")
	var got: Array = []
	drawer.close_requested.connect(func(r: Dictionary) -> void: got.append(r))
	drawer.dismiss()
	t.eq(got, [{}], "dismiss closes with an empty result")
	drawer.queue_free()
	await t.frames(1)


func _pending(t, bus: CardEventBus) -> void:
	var game := await _open(t, bus, "rogue_drawer_pending")
	var mock := game.engine as MockCardEngine
	var drawer = _drawer(game)
	var b: Button = drawer.pending_button()
	t.ok(b != null and b.text == CardText.ui("rg4.relics.pending"), "pending: one left to pick")
	if b == null:
		await _done(game)
		return
	t.ok(b.get_global_rect().position.y < CardAnchors.rect(&"a.relics.list").position.y, "pending button sits on top")
	var got: Array = []
	drawer.close_requested.connect(func(r: Dictionary) -> void: got.append(r))
	var from := mock.sent.size()
	await H.click(self, b.get_global_rect().get_center())
	await t.frames(3)
	t.eq(got, [{"next": {"kind": "stocktake", "args": {"offer": "w0.1"}}}], "pending hands over to the stocktake overlay")
	t.eq(H.sent_since(mock, from), [], "handing over sends no command")
	t.ok(not game.host.is_open(&"relics"), "the drawer closes")
	t.eq(game.host.top_kind(), &"stocktake", "the root opens the stocktake overlay from next")
	var panel = game.host.top_overlay()
	t.ok(panel != null and panel.offer_id() == "w0.1", "the overlay shows the pending offer")
	await _done(game)


## Root autoplay opens a panel the engine asks for at most twice a day: one that closes without settling the ask
## (the prison cell after its try; here the relics drawer, which only looks) does not ping-pong; the day goes on.
func _autoplay_once(t, bus: CardEventBus) -> void:
	var game := H.boot(self, bus, "rogue_drawer")
	await t.frames(4)
	var mock := game.engine as MockCardEngine
	mock._view["open_panel"] = {"kind": "relics", "args": {}}
	mock._view["hand"] = []
	var opened := [0]
	var count := func(n: StringName, a: Dictionary) -> void:
		if n == &"panel_opened" and str(a.get("kind", "")) == "relics":
			opened[0] += 1
	bus.ui_event.connect(count)
	var from := mock.sent.size()
	for i in 16:
		game.autoplay_step()
		await t.frames(1)
	bus.ui_event.disconnect(count)
	var cmds: Array = []
	for row in H.sent_since(mock, from):
		cmds.append(str(row[0]))
	# Once by the table itself (_sync_phase_panel, once a day), then at most twice by autoplay.
	t.ok(opened[0] >= 1 and opened[0] <= 3, "the asked drawer opened at most three times (%d)" % opened[0])
	t.ok(cmds.has("day.end"), "then autoplay ends the day: " + str(cmds))
	await _done(game)


## The drawer follows view changes (a relic arrives, the offer gets picked) without reopening.
func _refresh(t, bus: CardEventBus) -> void:
	var game := await _open(t, bus, "rogue_drawer_pending")
	var mock := game.engine as MockCardEngine
	var drawer = _drawer(game)
	var view := mock.view()
	view["relics"]["held"].append({"id": "rl.chen_mortar", "art": "prop.relic.chen_mortar", "depth": "storied", "since": 50})
	view["relics"]["count"] = 5
	view["stock"]["open"] = ""
	drawer.refresh(view)
	await t.frames(1)
	t.eq(_rows(drawer).size(), 5, "refresh: the new relic gets a row")
	t.ok(drawer.pending_button() == null, "refresh: the pending button goes once the offer is picked")
	t.eq(H.count_text(drawer, CardText.ui("rg4.relics.count", {"n": 5, "cap": 6})), 1, "refresh: count line follows")
	t.ok(t.anchor_ok(&"a.relics.list"), "refresh: anchor re-registered")
	await _done(game)
