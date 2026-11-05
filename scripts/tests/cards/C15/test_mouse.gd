# C15: both games play through with the mouse alone (InputEventMouseButton / InputEventMouseMotion pushed into
# the viewport at screen coords): fragments = right click to turn, drag each piece into place, click a seam
# to cross it, click the seal call, the glass, "done"; decode = click a group, a number tab or page button, a
# book line, "done". Decode: other keys do nothing; Esc aborts. Fragments is also played whole by keyboard
# (contract 8: keyboard-playable) through the same ops, and its seam hover band stays out of the glass. The
# host's abort spot covers none of the game's buttons.
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const H = preload("res://scripts/tests/cards/C15/harness.gd")
const Layout = preload("res://scripts/cards/minigames/fragments/frag_layout.gd")


func _initialize() -> void:
	var t := T.new(self, "C15_mouse")
	t.run_async(_body.bind(t))


func _body(t) -> void:
	await _fragments(t, "ticket_fake.json")
	await _fragments(t, "letter_missing.json")
	await _decode(t, "chen_code.json")
	await _decode(t, "ledger_key.json")
	await _keys(t)
	await _keyboard(t)
	await _band(t)
	await _abort_spots(t)


func _fragments(t, name: String) -> void:
	var fix := H.params(name)
	var ctx := H.open_game(self, H.FRAG, fix)
	var g = ctx["game"]
	await t.frames(2)
	var box := H.take(g)
	var o: Vector2 = g.panel_origin()
	var board = g.get("_board")
	var order: Array = board.z_order.duplicate()
	order.reverse()
	for p2 in order:
		var p := int(p2)
		var guard := 0
		while g.piece_rot(p) != 0 and guard < 4:
			H.click(self, o + g.piece_center(p), MOUSE_BUTTON_RIGHT)
			guard += 1
		t.eq(g.piece_rot(p), 0, name + " right click turns piece " + str(p))
		t.eq(board.piece_at(g.piece_center(p)), p, name + " piece " + str(p) + " on top where we grab it")
		H.drag(self, o + g.piece_center(p), o + g.slot_center(p) + Vector2(7, -5))
		t.ok(g.is_placed(p), name + " dragged piece " + str(p) + " lies in its place")
	t.eq(g.placed_count(), g.avail_count(), name + " all pieces in place by mouse")
	var L: Dictionary = g.layout()
	var s := 0
	if not (L["odd"] as Array).is_empty():
		var want := int(L["odd"][0])
		for i in range((L["seams"] as Array).size()):
			if int(L["seams"][i]["a"]) == want or int(L["seams"][i]["b"]) == want:
				s = i
				break
	H.click(self, o + board.seam_mid(s) + Vector2(1, 2))
	t.eq(g.crosses(), [s], name + " click on a seam crosses it")
	H.click(self, o + board.seam_mid(s))
	t.eq(g.crosses(), [], name + " click again takes the cross off")
	H.click(self, o + board.seam_mid(s))
	var seal_ok := not (L["seal"] as Dictionary).is_empty()
	if seal_ok:
		H.click(self, g.seal_button_rect(2).get_center())
	H.click(self, g.tool_button("lens").get_global_rect().get_center())
	H.move(self, o + g.slot_center(0))
	t.ok(g.get("_lens").visible, name + " the glass follows the pointer over the board")
	H.click(self, g.tool_button("done").get_global_rect().get_center())
	var r: Dictionary = box["r"]
	t.eq(r.get("aborted", true), false, name + " done by mouse")
	t.eq(r["measures"]["placed"], g.avail_count(), name + " placed measured")
	t.eq((r["measures"]["seams"] as Array).size(), 1, name + " one cross measured")
	if seal_ok:
		t.eq(r["measures"]["seal_call"], 2, name + " seal call measured")
		t.ok((r["observations"] as Array).has("obs.fragments.seal_offset"), name + " seal call reported")
	t.ok((r["observations"] as Array).has("obs.fragments.ink_breaks"), name + " cross reported")
	H.close(ctx)
	await t.frames(1)


func _decode(t, name: String) -> void:
	var fix := H.params(name)
	var ctx := H.open_game(self, H.DEC, fix)
	var g = ctx["game"]
	await t.frames(2)
	var box := H.take(g)
	var codes: Array = fix["codes"]
	if g.key_in_use():
		var k := int(fix["key_shift"])
		var guard := 0
		while int(g.get("_key")) != k and guard < 10:
			H.click(self, _key_plus(g))
			guard += 1
		t.eq(int(g.get("_key")), k, name + " key dialled by mouse")
	for i in range(codes.size()):
		var j := codes.size() - 1 - i
		H.click(self, g.group_rect(j).position + Vector2(20, 20))
		t.eq(g.selected_group(), j, name + " click selects group " + str(j))
		var code := str(codes[j])
		var want_page: int = g.page_of(code)
		for tab in g.tab_rects():
			if int(tab[1]) <= want_page and int(tab[1]) > g.current_page():
				H.click(self, (tab[0] as Rect2).get_center())
		var guard2 := 0
		while g.current_page() != want_page and guard2 < 20:
			H.click(self, g.nav_rect(g.current_page() < want_page).get_center())
			guard2 += 1
		t.eq(g.current_page(), want_page, name + " page " + str(want_page) + " opened by mouse")
		var line: int = g.page_codes().find(code)
		H.click(self, g.row_rect(line).get_center())
		t.eq(g.picked(j), code, name + " book line copied into group " + str(j))
	var first: Rect2 = g.group_rect(0)
	H.click(self, first.position + Vector2(first.size.x - 14, first.size.y - 19))
	t.eq(g.picked(0), "", name + " the small cross rubs a word out")
	var code0 := str(codes[0])
	H.click(self, first.position + Vector2(20, 20))
	var p0: int = g.page_of(code0)
	var guard3 := 0
	while g.current_page() != p0 and guard3 < 20:
		H.click(self, g.nav_rect(g.current_page() < p0).get_center())
		guard3 += 1
	var line0: int = g.page_codes().find(code0)
	var other := line0 + 1 if line0 + 1 < g.page_codes().size() else line0 - 1
	H.click(self, g.row_rect(other).get_center())
	t.eq(g.picked(0), g.page_codes()[other], name + " a wrong line is copied as the player's reading")
	H.click(self, g.done_rect().get_center())
	var r: Dictionary = box["r"]
	t.eq(r.get("aborted", true), false, name + " done by mouse")
	var j2 := H.judge_decode(codes, r)
	t.eq(int(j2["right"]), codes.size() - 1, name + " the other groups read right")
	t.eq(int(j2["wrong"]), 1, name + " the wrong reading is recorded, not refused")
	t.ok((r["observations"] as Array).has("obs.decode." + str(g.page_codes()[other])), name + " wrong word reported")
	H.close(ctx)
	await t.frames(1)


func _key_plus(g) -> Vector2:
	var panel: Control = g.get("_panel")
	for c in panel.get_children():
		if c is Button and (c as Button).text == "+":
			return (c as Button).get_global_rect().get_center()
	return Vector2.ZERO


## Decode: only Esc does anything from the keyboard. Fragments: keys it does not use change nothing, Esc aborts.
func _keys(t) -> void:
	for scene in [H.FRAG, H.DEC]:
		var fix := H.params("ticket_fake.json" if scene == H.FRAG else "chen_code.json")
		var ctx := H.open_game(self, scene, fix)
		var g = ctx["game"]
		await t.frames(1)
		var box := H.take(g)
		var keys := [KEY_RIGHT, KEY_LEFT, KEY_Q, KEY_E, KEY_S, KEY_F, KEY_B, KEY_ENTER, KEY_TAB]
		if scene == H.FRAG:
			keys = [KEY_Z, KEY_M, KEY_3, KEY_0, KEY_A, KEY_D, KEY_W]
		for key in keys:
			_key(key)
		t.eq(g.ops_log(), [], scene.get_file() + " keys change nothing")
		t.eq(box["r"], {}, scene.get_file() + " keys do not finish")
		_key(KEY_ESCAPE)
		t.eq(box["r"].get("aborted", false), true, scene.get_file() + " Esc aborts")
		t.eq(box["r"].get("observations", ["x"]), [], scene.get_file() + " abort reports nothing")
		H.close(ctx)
		await t.frames(1)


func _key(code: Key, shift: bool = false) -> void:
	for down in [true, false]:
		var ev := InputEventKey.new()
		ev.keycode = code
		ev.physical_keycode = code
		ev.pressed = down
		ev.shift_pressed = shift
		root.push_input(ev)


## Fragments by keyboard alone: Tab picks each loose piece, E turns it, arrows (Shift: farther) bring it home;
## S walks the look point over the seams, X / Space / Enter cross and uncross, 2 calls the seal, L shows the
## glass at the look point, B the light, F hands it back. The ops replay to the same result. A focusable button
## under the panel (the table) must not take Tab or the arrows away from the game.
func _keyboard(t) -> void:
	var table := Button.new()
	table.focus_mode = Control.FOCUS_ALL
	root.add_child(table)
	var fix := H.params("ticket_fake.json")
	var ctx := H.open_game(self, H.FRAG, fix)
	var g = ctx["game"]
	await t.frames(1)
	var box := H.take(g)
	var board = g.get("_board")
	var L: Dictionary = g.layout()
	for p2 in L["tray_order"]:
		var p := int(p2)
		_key(KEY_TAB)
		t.eq(board.selected, p, "Tab picks loose piece " + str(p))
		var guard := 0
		while g.piece_rot(p) != 0 and guard < 4:
			_key(KEY_E)
			guard += 1
		t.eq(g.piece_rot(p), 0, "E turns piece " + str(p))
		guard = 0
		while not g.is_placed(p) and guard < 80:
			var d: Vector2i = Vector2i(L["slots"][p]) - g.piece_pos(p)
			var along_x := absi(d.x) >= absi(d.y)
			var k := (KEY_RIGHT if d.x > 0 else KEY_LEFT) if along_x else (KEY_DOWN if d.y > 0 else KEY_UP)
			_key(k, absi(d.x if along_x else d.y) >= 64)
			guard += 1
		t.ok(g.is_placed(p), "arrows bring piece " + str(p) + " home")
	t.eq(g.placed_count(), g.avail_count(), "every piece in place by keyboard")
	t.eq(root.gui_get_focus_owner(), null, "keyboard focus never went to the table under the panel")
	_key(KEY_TAB)
	t.eq(board.selected, -1, "Tab with nothing loose picks none")
	_key(KEY_S)
	var s := int(board.get("_hover_seam"))
	t.ok(s >= 0 and g.seam_ready(s), "S puts the look point on a seam")
	_key(KEY_X)
	t.eq(g.crosses(), [s], "X crosses that seam")
	_key(KEY_SPACE)
	t.eq(g.crosses(), [], "Space takes the cross off")
	_key(KEY_ENTER)
	t.eq(g.crosses(), [s], "Enter crosses it again")
	var seal_seam := int(L["seal"]["seam"])
	var guard2 := 0
	while int(board.get("_hover_seam")) != seal_seam and guard2 < 20:
		_key(KEY_S)
		guard2 += 1
	t.eq(int(board.get("_hover_seam")), seal_seam, "S reaches the seal's seam")
	_key(KEY_2)
	_key(KEY_L)
	var glass: Rect2 = g.glass_rect()
	t.ok(glass.has_area(), "L shows the glass at the look point")
	var look: Vector2 = board.get("_look")
	t.eq(glass.get_center(), look, "the glass sits on the look point")
	_key(KEY_RIGHT)
	t.eq(g.glass_rect().get_center(), look + Vector2(4, 0), "an arrow moves the look point and the glass with it")
	_key(KEY_B)
	t.ok(g.light_on(), "B turns the light on")
	_key(KEY_F)
	var r: Dictionary = box["r"]
	t.eq(r.get("aborted", true), false, "F hands it back")
	t.eq(r["measures"]["placed"], g.avail_count(), "keyboard: placed measured")
	var row: Dictionary = L["seams"][s]
	t.eq(r["measures"]["seams"], [[int(row["a"]), int(row["b"])]], "keyboard: the cross measured")
	t.eq(r["measures"]["seal_call"], 2, "keyboard: seal call measured")
	t.eq(H.replay(self, H.FRAG, fix, g.ops_log()), r, "keyboard ops replay to the same result")
	var n: int = g.ops_log().size()
	_key(KEY_TAB)
	_key(KEY_X)
	t.eq(g.ops_log().size(), n, "nothing after done")
	H.close(ctx)
	table.queue_free()
	await t.frames(1)


## The seam hover band stays out of the glass: the glass magnifies what is drawn under it, so a band there
## would lie over the junction being judged. Without the glass the band runs the whole seam.
func _band(t) -> void:
	var ctx := H.open_game(self, H.FRAG, H.params("ticket_fake.json"))
	var g = ctx["game"]
	await t.frames(1)
	var board = g.get("_board")
	var L: Dictionary = g.layout()
	for p2 in L["tray_order"]:
		var p := int(p2)
		while g.piece_rot(p) != 0:
			g.apply_op(["rotate", p, 1])
		var slot: Vector2i = L["slots"][p]
		g.apply_op(["move", p, slot.x, slot.y])
	var s := int(L["seal"]["seam"])
	var ends: Array = Layout.seam_ends(L, s)
	var at: Vector2 = board.call("_seam_look", L, s)
	var o: Vector2 = g.panel_origin()
	H.move(self, o + at)
	t.eq(int(board.get("_hover_seam")), s, "pointer on the seal's seam")
	t.eq(board.band_parts(ends[0], ends[1], g.glass_rect()), [[ends[0], ends[1]]], "no glass: the band runs the whole seam")
	g.apply_op(["lens", 1])
	H.move(self, o + at + Vector2(0, 1))
	var glass: Rect2 = g.glass_rect()
	t.ok(glass.has_area(), "glass shows on the seam")
	var parts: Array = board.band_parts(ends[0], ends[1], glass)
	t.ok(parts.size() >= 1, "the band still shows outside the glass")
	for part in parts:
		var q := Geometry2D.get_closest_point_to_segment(glass.get_center(), part[0], part[1])
		t.ok(q.distance_to(glass.get_center()) >= glass.size.x * 0.5, "band part " + str(part) + " outside the glass")
	H.close(ctx)
	await t.frames(1)


func _abort_spots(t) -> void:
	for pair in [[H.FRAG, "ticket_fake.json"], [H.DEC, "ledger_key.json"]]:
		var ctx := H.open_game(self, str(pair[0]), H.params(str(pair[1])))
		var g = ctx["game"]
		await t.frames(1)
		var spot: Rect2 = g.abort_rect()
		t.ok(Rect2(0, 0, 1280, 720).encloses(spot), str(pair[1]) + " abort spot on screen")
		var hits := 0
		for n in _walk(g):
			if n is BaseButton and (n as Control).is_visible_in_tree() and (n as Control).get_global_rect().intersects(spot):
				hits += 1
		t.eq(hits, 0, str(pair[1]) + " no game button under the abort spot")
		H.close(ctx)
		await t.frames(1)


func _walk(n: Node) -> Array:
	var out: Array = [n]
	for c in n.get_children():
		out.append_array(_walk(c))
	return out
