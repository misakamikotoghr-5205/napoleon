# Almanac drawer: the HUD almanac hotspot (and the calendar on the wall) open the real right drawer,
# not the W0 stub; it shows today's suitable/avoid words with a mark on the done one, the month's
# fortune segment and the drawn lots' verses, all from CardText, with no hidden numbers; it sends
# nothing; Esc, the frame's close button and autoplay each close it.
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const H = preload("res://scripts/tests/cards/C07/c07_harness.gd")
const SCENE := "res://scenes/cards/fortune/AlmanacDrawer.tscn"


func _initialize() -> void:
	var t := T.new(self, "C07_almanac_drawer")
	t.run_async(_body.bind(t))


func _body(t) -> void:
	t.eq(CardIds.panel_scene(&"almanac"), SCENE, "almanac has its own scene")
	t.eq(CardIds.PANEL_SHOW.get(&"almanac"), CardIds.SHOW_DRAWER_R, "almanac is a right drawer")
	var bus := CardEventBus.new()
	root.add_child(bus)
	var game: CardGameRoot = load(CardIds.ROOT_SCENE).instantiate()
	root.add_child(game)
	game.boot({"mock": true, "bus": bus, "fixture": H.FIX + "almanac_drawer.json", "skip_title": true,
		"guide": "off"})
	await t.frames(3)
	var mock := game.engine as MockCardEngine
	t.no_leaks(mock.view(), "drawer view")
	var spy = t.spy(bus)
	var sent := mock.sent.size()
	var hit := _hud_hotspot(game)
	t.ok(hit != null, "HUD almanac hotspot")
	if hit != null:
		hit.pressed.emit()
	await t.frames(2)
	var drawer := _open_drawer(t, game, "hud")
	if drawer != null:
		_content(t, drawer)
	t.eq(_drawer_events(spy), [["drawer_opened", "r"]], "drawer_opened on the right")
	spy.clear()
	await _tap(KEY_ESCAPE)
	t.ok(not game.host.drawer_open(), "Esc closes the drawer")
	t.ok(not game._drawer.is_open(), "Esc hides the drawer frame")
	t.ok(not game.host.is_open(&"pause"), "Esc closes the drawer before pausing")
	t.eq(_drawer_events(spy), [["drawer_closed", "r"]], "drawer_closed after Esc")
	game.stage.hotspot_pressed.emit(&"calendar")
	await t.frames(2)
	drawer = _open_drawer(t, game, "calendar")
	var close := _frame_close(game)
	t.ok(close != null and close.is_visible_in_tree(), "drawer frame close button")
	if close != null:
		close.pressed.emit()
	await t.frames(2)
	t.ok(not game.host.drawer_open(), "close button closes the drawer")
	t.ok(not game._drawer.is_open(), "close button hides the frame")
	hit.pressed.emit()
	await t.frames(2)
	drawer = _open_drawer(t, game, "autoplay")
	if drawer != null:
		t.ok(drawer.autoplay_step(), "autoplay looks once")
		t.ok(not drawer.autoplay_step(), "autoplay then stops")
	await t.frames(2)
	t.ok(not game.host.drawer_open(), "autoplay closes the drawer")
	t.eq(mock.sent.size(), sent, "drawer sends no command")
	game.queue_free()
	bus.queue_free()
	await t.frames(2)


func _open_drawer(t, game: CardGameRoot, label: String) -> CardAlmanacDrawer:
	t.eq(game.host.top_kind(), &"almanac", label + " opens almanac")
	var drawer := game.host.drawer_panel() as CardAlmanacDrawer
	t.ok(drawer != null, label + " opens the real drawer, not the stub")
	t.ok(game._drawer.is_open() and game._drawer.side() == "r", label + " uses the right drawer frame")
	return drawer


func _content(t, drawer: CardAlmanacDrawer) -> void:
	var box := drawer.find_child("AlmanacBox", true, false) as Control
	t.ok(box != null, "content box")
	if box == null:
		return
	var inner := CardLayout.DRAWER_R.grow(-1.0)
	t.ok(inner.encloses(box.get_global_rect()), "content inside the right drawer")
	t.eq(box.size, Vector2(388, 630), "content is 388x630")
	t.ok(t.anchor_in(&"a.almanac", CardLayout.DRAWER_R), "a.almanac points into the open drawer")
	for key in ["g05.almanac.pawn_in", "g05.almanac.meet", "g05.almanac.travel", "c07.strip.yi", "c07.strip.ji",
			"c07.drawer.title", "c07.drawer.fortune", "c07.drawer.lots"]:
		t.ok(H.count_text(box, CardText.ui(key)) >= 1, "shows " + key)
	t.ok(H.count_text(box, CardText.t("ws.1938.month.caixing#title")) == 1, "month fortune segment name")
	t.ok(H.count_text(box, CardText.card("lot.g1.official", "verse")) == 1, "first lot verse")
	t.ok(H.count_text(box, CardText.card("lot.g3.any", "verse")) == 1, "second lot verse")
	var marked: Array = []
	for n in H.walk(box):
		if n is Control and (n as Control).has_meta("action") and (n as Control).get_node_or_null("DoneMark") != null:
			marked.append(str((n as Control).get_meta("action")))
	t.eq(marked, ["pawn_in"], "only the done action has a mark")
	t.eq(t.all_text_from_cardtext(box).size(), 0, "drawer text is CardText")
	_no_hidden_numbers(t, box)


## Every word on the drawer is one of the refs it is allowed to show; digits only appear inside a
## draft placeholder (the key or brief of text a person has not written yet), never as a value.
func _no_hidden_numbers(t, box: Control) -> void:
	var refs: Array = ["g05.almanac.pawn_in", "g05.almanac.meet", "g05.almanac.travel", "c07.strip.yi",
		"c07.strip.ji", "c07.drawer.title", "c07.drawer.fortune", "c07.drawer.lots", "c07.drawer.none",
		"ws.1938.month.caixing#title", "lot.g1.official#verse", "lot.g3.any#verse"]
	var allowed := {}
	for ref in refs:
		allowed[CardText.t(ref)] = CardText.is_draft(ref)
	var num := RegEx.create_from_string("[0-9]")
	for n in H.walk(box):
		var texts: Array = []
		if n is Label:
			texts = [(n as Label).text, (n as Label).tooltip_text]
		elif n is Button:
			texts = [(n as Button).text, (n as Button).tooltip_text]
		for txt in texts:
			if str(txt) == "":
				continue
			t.ok(allowed.has(txt), "allowed text: " + str(txt))
			t.ok(not str(txt).contains("%"), "no percent: " + str(txt))
			if num.search(str(txt)) != null:
				t.ok(bool(allowed.get(txt, false)), "digits only in a draft placeholder: " + str(txt))


func _hud_hotspot(game: CardGameRoot) -> Button:
	for n in game._hud.get_children():
		if n is Button and Rect2((n as Button).position, (n as Button).size) == CardLayout.HUD_ALMANAC:
			return n
	return null


## The frame's 合上 lives in the drawer title row, which the host lifts above the drawer panel (b23,
## drawer_host.chrome()); older builds kept it as a direct child of the drawer host.
func _frame_close(game: CardGameRoot) -> Button:
	var places: Array = [game._drawer]
	if game._drawer.has_method("chrome") and game._drawer.chrome() != null:
		places.push_front(game._drawer.chrome())
	for place in places:
		for n in (place as Node).get_children():
			if n is Button and (n as Button).text == CardText.ui("c01.btn.drawer_close"):
				return n
	return null


func _drawer_events(spy) -> Array:
	var out: Array = []
	for ev in spy.ui_events():
		var name := str(ev[0])
		if (name == "drawer_opened" or name == "drawer_closed") and str(ev[1].get("kind", "")) == "almanac":
			out.append([name, str(ev[1].get("side", ""))])
	return out


func _tap(key: Key) -> void:
	var down := H.key_event(key)
	root.push_input(down)
	await process_frame
	var up := H.key_event(key)
	up.pressed = false
	root.push_input(up)
	await process_frame
	await process_frame
