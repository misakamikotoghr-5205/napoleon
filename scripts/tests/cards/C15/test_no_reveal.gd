# C15: the games never show the answer. From opening to "done": every visible text comes from CardText or is
# plain numbers; no observation text and no percent sign appear; the only numbers are the ones the player
# works with (code digits, book codes, number tabs, the page, the key). A right play and a wrong play leave
# the same set of node colours (nothing is coloured by right or wrong), and every fragment piece has the same
# edge colour (other paper is not outlined).
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const H = preload("res://scripts/tests/cards/C15/harness.gd")


func _initialize() -> void:
	var t := T.new(self, "C15_no_reveal")
	t.run_async(_body.bind(t))


func _body(t) -> void:
	var obs_text := _obs_texts()
	t.ok(obs_text.size() > 10, "observation texts loaded")
	for name in H.FRAG_FIXTURES:
		await _frag_text(t, str(name), obs_text)
		await _edges(t, str(name))
	for name2 in H.DEC_FIXTURES:
		await _dec_text(t, str(name2), obs_text)
	await _frag_colors(t, "ticket_fake.json")
	await _frag_colors(t, "scroll8.json")
	await _dec_colors(t, "chen_code.json")
	await _dec_colors(t, "ledger_key.json")


func _obs_texts() -> PackedStringArray:
	var out := PackedStringArray()
	for kind in ["fragments", "decode"]:
		var cat = CardDB.read_json("res://data/cards/minigames/obs/" + kind + ".json")
		for key in (cat["obs"] as Dictionary).keys():
			var s := CardText.obs(str(key))
			if s != "" and not out.has(s):
				out.append(s)
	return out


func _texts(root_node: Node) -> PackedStringArray:
	var out := PackedStringArray()
	for n in _walk(root_node):
		if n is Label and (n as Control).is_visible_in_tree():
			out.append((n as Label).text)
		elif n is Button and (n as Control).is_visible_in_tree():
			out.append((n as Button).text)
	return out


func _check_texts(t, g, label: String, obs_text: PackedStringArray, allowed: Dictionary) -> void:
	t.eq(t.all_text_from_cardtext(g), PackedStringArray(), label + " all text from CardText or numbers")
	var pct := String.chr(37)
	var digits := RegEx.create_from_string("[0-9]+")
	for s in _texts(g):
		t.ok(s.find(pct) < 0, label + " no percent sign: " + s)
		for o in obs_text:
			t.ok(s.find(o) < 0, label + " no observation text: " + s)
		for m in digits.search_all(s):
			t.ok(allowed.has(m.get_string()), label + " number allowed: " + m.get_string() + " in " + s)


func _frag_text(t, name: String, obs_text: PackedStringArray) -> void:
	var fix := H.params(name)
	var ctx := H.open_game(self, H.FRAG, fix)
	var g = ctx["game"]
	await t.frames(1)
	_check_texts(t, g, name + " open", obs_text, {})
	var ops := _autoplay_ops(H.FRAG, fix, 1.0)
	for op in ops:
		if str(op[0]) != "done":
			g.apply_op(op)
	_check_texts(t, g, name + " judged", obs_text, {})
	H.close(ctx)
	await t.frames(1)


func _dec_text(t, name: String, obs_text: PackedStringArray) -> void:
	var fix := H.params(name)
	var ctx := H.open_game(self, H.DEC, fix)
	var g = ctx["game"]
	await t.frames(1)
	var allowed := {}
	for c in g.book_codes():
		allowed[c] = true
		allowed[c.substr(0, 3)] = true
	for k in range(10):
		allowed[str(k)] = true
	for p in range(1, g.page_count() + 1):
		allowed[str(p)] = true
	if str(fix.get("crib", "")) != "":
		allowed[str(fix["crib"])] = true
	_check_texts(t, g, name + " open", obs_text, allowed)
	for op in _autoplay_ops(H.DEC, fix, 0.0):
		if str(op[0]) != "done":
			g.apply_op(op)
	_check_texts(t, g, name + " misread", obs_text, allowed)
	H.close(ctx)
	await t.frames(1)


## Every piece's outline pixels (opaque next to clear or at the image edge) are one colour, the same for all.
func _edges(t, name: String) -> void:
	var ctx := H.open_game(self, H.FRAG, H.params(name))
	var g = ctx["game"]
	var want := CardTheme.color(&"ink_3").to_html()
	var seen := {}
	for p in range(int(g.layout()["n"])):
		if g.is_hole(p):
			continue
		var img: Image = g.paint_row(p)["img"]
		for c in _edge_colors(img).keys():
			seen[c] = true
	t.eq(seen.keys(), [want], name + " every piece has the same edge colour " + str(seen.keys()))
	H.close(ctx)
	await t.frames(1)


func _edge_colors(img: Image) -> Dictionary:
	var out := {}
	var w := img.get_width()
	var h := img.get_height()
	for y in range(h):
		for x in range(w):
			if img.get_pixel(x, y).a <= 0.0:
				continue
			var edge := x == 0 or y == 0 or x == w - 1 or y == h - 1
			if not edge:
				edge = img.get_pixel(x - 1, y).a <= 0.0 or img.get_pixel(x + 1, y).a <= 0.0 \
					or img.get_pixel(x, y - 1).a <= 0.0 or img.get_pixel(x, y + 1).a <= 0.0
			if edge:
				out[img.get_pixel(x, y).to_html()] = true
	return out


func _autoplay_ops(scene: String, fix: Dictionary, skill: float) -> Array:
	var ctx := H.open_game(self, scene, fix)
	ctx["game"].autoplay(skill)
	var ops: Array = ctx["game"].ops_log()
	H.close(ctx)
	return ops


## Same pieces in place; one game makes the right calls, the other the wrong ones.
func _frag_colors(t, name: String) -> void:
	var fix := H.params(name)
	var base: Array = []
	for op in _autoplay_ops(H.FRAG, fix, 1.0):
		if str(op[0]) in ["move", "rotate", "lens", "light"]:
			base.append(op)
	var right := H.open_game(self, H.FRAG, fix)
	var wrong := H.open_game(self, H.FRAG, fix)
	for op in base:
		right["game"].apply_op(op)
		wrong["game"].apply_op(op)
	var L: Dictionary = right["game"].layout()
	var odd: Array = L["odd"]
	var plain := -1
	var odd_seam := -1
	for s in range((L["seams"] as Array).size()):
		var row: Dictionary = L["seams"][s]
		var touches := odd.has(int(row["a"])) or odd.has(int(row["b"]))
		if touches and odd_seam < 0:
			odd_seam = s
		if not touches and plain < 0:
			plain = s
	t.ok(odd_seam >= 0 and plain >= 0, name + " has a seam on other paper and a plain one")
	right["game"].apply_op(["seam", int(L["seams"][odd_seam]["a"]), int(L["seams"][odd_seam]["b"])])
	wrong["game"].apply_op(["seam", int(L["seams"][plain]["a"]), int(L["seams"][plain]["b"])])
	var off := int(L["seal"]["shift"]) >= 2
	right["game"].apply_op(["seal", 2 if off else 1])
	wrong["game"].apply_op(["seal", 1 if off else 2])
	await t.frames(1)
	t.eq(_colors(right["game"]), _colors(wrong["game"]), name + " right and wrong calls look alike")
	var jr := H.judge_frag(right["game"], {"measures": {"seams": [[int(L["seams"][odd_seam]["a"]), int(L["seams"][odd_seam]["b"])]], "seal_call": 2 if off else 1}})
	t.ok(int(jr["right"]) >= 1 and int(jr["wrong"]) == 0, name + " the right game really is right")
	H.close(right)
	H.close(wrong)
	await t.frames(1)


func _dec_colors(t, name: String) -> void:
	var fix := H.params(name)
	var right := H.open_game(self, H.DEC, fix)
	var wrong := H.open_game(self, H.DEC, fix)
	for op in _autoplay_ops(H.DEC, fix, 1.0):
		if str(op[0]) != "done":
			right["game"].apply_op(op)
	for op2 in _autoplay_ops(H.DEC, fix, 0.0):
		if str(op2[0]) != "done":
			wrong["game"].apply_op(op2)
	for g in [right["game"], wrong["game"]]:
		g.apply_op(["select", 0])
		g.apply_op(["page", 0])
	await t.frames(1)
	t.eq(_colors(right["game"]), _colors(wrong["game"]), name + " right and wrong readings look alike")
	H.close(right)
	H.close(wrong)
	await t.frames(1)


## The colours a node tree shows: label inks, rect fills, style boxes in use, and which buttons are down.
func _colors(root_node: Node) -> Array:
	var seen := {}
	for n in _walk(root_node):
		if n is CanvasItem and not (n as CanvasItem).is_visible_in_tree():
			continue
		if n is Label:
			seen["label " + (n as Label).get_theme_color("font_color").to_html()] = true
		elif n is ColorRect:
			seen["rect " + (n as ColorRect).color.to_html()] = true
		if n is Button:
			var b := n as Button
			var state := "pressed" if b.button_pressed else ("disabled" if b.disabled else "normal")
			var sb := b.get_theme_stylebox(state)
			if sb is StyleBoxFlat:
				seen["button " + state + " " + (sb as StyleBoxFlat).bg_color.to_html() + " " + (sb as StyleBoxFlat).border_color.to_html()] = true
			else:
				seen["button " + state] = true
		if n is CanvasItem:
			seen["modulate " + (n as CanvasItem).modulate.to_html() + " " + (n as CanvasItem).self_modulate.to_html()] = true
	var keys: Array = seen.keys()
	keys.sort()
	return keys


func _walk(n: Node) -> Array:
	var out: Array = [n]
	for c in n.get_children():
		out.append_array(_walk(c))
	return out
