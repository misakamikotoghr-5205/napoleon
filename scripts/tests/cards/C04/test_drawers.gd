# C04 drawers: shelf is read-only unless pick_for is set; tickets are read-only.
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const S = preload("res://scripts/tests/cards/C04/support.gd")
const SHELF := "res://scenes/cards/counter/ShelfDrawer.tscn"
const TICKETS := "res://scenes/cards/counter/TicketsDrawer.tscn"


func _initialize() -> void:
	var t := T.new(self, "C04_drawers")
	t.run_async(_body.bind(t))


func _body(t) -> void:
	t.no_leaks(S.read("buy"), "buy")
	t.no_leaks(S.read("pawn"), "pawn")
	await _shelf(t)
	await _tickets(t)


func _shelf(t) -> void:
	var ctx: Dictionary = S.boot(self, "buy")
	await t.frames(1)
	var drawer: CardShelfDrawer = load(SHELF).instantiate()
	drawer.bind(ctx.mock, ctx.bus)
	root.add_child(drawer)
	drawer.open({})
	await t.frames(1)
	t.ok(t.anchor_ok(&"a.shelf.list"), "read-only shelf anchor")
	t.ok(not CardAnchors.has(&"a.counter.stock"), "read-only shelf is not the pick anchor")
	t.ok(drawer.find_child("Stock_I010", true, false) == null, "read-only cells are not buttons")
	_close_ok(t, drawer, "shelf")
	var bad: PackedStringArray = t.all_text_from_cardtext(drawer)
	t.ok(bad.is_empty(), "shelf text: " + ", ".join(bad))
	_no_percent(t, drawer, "shelf")
	t.ok(drawer.autoplay_step(), "shelf autoplay looks once")
	t.ok(not drawer.autoplay_step(), "shelf autoplay then stops")
	drawer.queue_free()
	await t.frames(1)
	var pick: CardShelfDrawer = load(SHELF).instantiate()
	pick.bind(ctx.mock, ctx.bus)
	root.add_child(pick)
	var closed: Array = [false]
	pick.close_requested.connect(func(_r: Dictionary) -> void: closed[0] = true)
	pick.open({"pick_for": "c0004"})
	await t.frames(1)
	t.ok(t.anchor_ok(&"a.counter.stock"), "pick shelf anchor")
	t.ok(not CardAnchors.has(&"a.shelf.list"), "pick shelf drops the read-only anchor")
	var cell := pick.find_child("Stock_I010", true, false) as Button
	t.ok(cell != null, "pick cell")
	if cell != null:
		cell.pressed.emit()
	await t.frames(1)
	t.eq(S.cmds(ctx.mock), [["counter.pick_stock", {"uid": "c0004", "item": "I010"}]], "pick sends stock")
	t.ok(closed[0], "pick closes the drawer")
	pick.queue_free()
	S.free_ctx(ctx)
	await t.frames(1)


func _tickets(t) -> void:
	var ctx: Dictionary = S.boot(self, "pawn")
	await t.frames(1)
	var drawer: CardTicketsDrawer = load(TICKETS).instantiate()
	drawer.bind(ctx.mock, ctx.bus)
	root.add_child(drawer)
	drawer.open({})
	await t.frames(1)
	t.ok(t.anchor_ok(&"a.tickets.list"), "tickets anchor")
	_close_ok(t, drawer, "tickets")
	var bad: PackedStringArray = t.all_text_from_cardtext(drawer)
	t.ok(bad.is_empty(), "tickets text: " + ", ".join(bad))
	_no_percent(t, drawer, "tickets")
	var nums := {"1": true, "200": true, "15": true}
	var re := RegEx.create_from_string("-?\\d+")
	for n in _walk(drawer):
		var txt := ""
		if n is Label:
			txt = (n as Label).text
		elif n is Button:
			txt = (n as Button).text
		if txt == "" or CardText.issued_contains(txt):
			continue
		for m in re.search_all(txt):
			t.ok(nums.has(m.get_string()), "ticket number " + m.get_string())
	t.ok(drawer.autoplay_step(), "tickets autoplay looks once")
	t.ok(not drawer.autoplay_step(), "tickets autoplay then stops")
	t.eq(S.cmds(ctx.mock), [], "tickets drawer sends nothing")
	drawer.queue_free()
	S.free_ctx(ctx)
	await t.frames(1)


# b16: a bare drawer (no host frame) closes with "c04.drawer.close", fully inside DRAWER_R and on
# screen, not with the counter's long "come back later" reply cut off at the screen edge.
func _close_ok(t, drawer: CardPanel, label: String) -> void:
	var close := drawer.find_child("CloseButton", true, false) as Button
	t.ok(close != null, label + " bare drawer has its own close")
	if close == null:
		return
	t.eq(close.text, CardText.ui("c04.drawer.close"), label + " close label")
	var r := close.get_global_rect()
	t.ok(CardLayout.DRAWER_R.encloses(r), label + " close inside the drawer %s" % str(r))
	t.ok(CardLayout.SCREEN.encloses(r), label + " close on screen")
	var font := close.get_theme_font("font")
	var need := font.get_string_size(close.text, HORIZONTAL_ALIGNMENT_LEFT, -1, close.get_theme_font_size("font_size")).x
	t.ok(need <= r.size.x, label + " close text fits its button")
	var closed := [false]
	var cb := func(_r: Dictionary) -> void: closed[0] = true
	drawer.close_requested.connect(cb)
	close.pressed.emit()
	t.ok(closed[0], label + " close closes")
	drawer.close_requested.disconnect(cb)


func _no_percent(t, node: Node, label: String) -> void:
	for n in _walk(node):
		var txt := ""
		if n is Label:
			txt = (n as Label).text
		elif n is Button:
			txt = (n as Button).text
		if txt != "":
			t.ok(txt.find("%") < 0, label + " percent in " + txt)


func _walk(n: Node) -> Array:
	var out: Array = [n]
	for c in n.get_children():
		out.append_array(_walk(c))
	return out
