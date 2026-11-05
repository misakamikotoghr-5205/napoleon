# C15 fragments (appraisal redesign, DESIGN 7): the player's calls are the observations; clarity comes only
# from what the player visibly did; minutes per judging step; pieces in place stay put; the seal call opens
# only when both halves lie in place; Esc aborts. Contract 8.1, 8.2, 12.2.
# Changed 10-25: the old "look at seal" / "look at ink" buttons that read the answer from params are gone,
# so the assertions about them became assertions about the player's own calls.
# Review fixes 10-25: the dang strokes (and the notes' line about them) only on the drawn ticket; other paper
# changes only its paper and its cross-seam strokes, not its characters, frame or seal; upright fibres keep one
# phase over the whole sheet so they run on across sound seams; Esc arrives through the viewport.
# Acceptance fix2 10-25: other paper keeps the sheet's paper colour (no tinted patch); the grain has chain lines.
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const H = preload("res://scripts/tests/cards/C15/harness.gd")
const Paint = preload("res://scripts/cards/minigames/fragments/frag_piece.gd")


func _initialize() -> void:
	var t := T.new(self, "C15_fragments")
	t.run_async(_body.bind(t))


func _body(t) -> void:
	await _basics(t)
	await _observations(t)
	await _quality(t)
	await _minutes(t)
	await _gates(t)
	await _missing(t)
	await _tools(t)
	await _abort(t)
	await _dangzi(t)
	await _odd_paper(t)
	await _fibres(t)


func _place_all(g, except: Array = []) -> void:
	for p2 in g.layout()["tray_order"]:
		var p := int(p2)
		if except.has(p):
			continue
		while g.piece_rot(p) != 0:
			g.apply_op(["rotate", p, 1])
		var slot: Vector2i = g.layout()["slots"][p]
		g.apply_op(["move", p, slot.x, slot.y])


func _basics(t) -> void:
	var ctx := H.open_game(self, H.FRAG, H.params("ticket196.json"))
	var g = ctx["game"]
	await t.frames(2)
	t.eq(g.placed_count(), 0, "starts unplaced")
	t.eq(int(g.layout()["n"]), 6, "six pieces")
	t.eq(g.avail_count(), 6, "six to place")
	var box := H.take(g)
	g.autoplay(0.9)
	var r: Dictionary = box["r"]
	var keys: Array = r.keys()
	keys.sort()
	t.eq(keys, ["aborted", "measures", "minutes", "observations", "quality_permille"], "five keys")
	var mkeys: Array = (r["measures"] as Dictionary).keys()
	mkeys.sort()
	t.eq(mkeys, ["placed", "rotations", "seal_call", "seal_checked", "seams"], "measures keys (DESIGN 7.5)")
	t.eq(r["measures"]["placed"], 6, "placed 6")
	t.eq(typeof(r["measures"]["rotations"]), TYPE_INT, "rotations int")
	t.eq(typeof(r["quality_permille"]), TYPE_INT, "quality int")
	t.eq(typeof(r["minutes"]), TYPE_INT, "minutes int")
	t.ok(CardAppraisal._valid_result(r), "engine shape check")
	H.close(ctx)
	await t.frames(1)


## What is reported is what the player said, whatever the paper really is.
func _observations(t) -> void:
	var fix := H.params("ticket_real.json")
	var ctx := H.open_game(self, H.FRAG, fix)
	var g = ctx["game"]
	_place_all(g)
	var row: Dictionary = g.layout()["seams"][0]
	g.apply_op(["seam", int(row["a"]), int(row["b"])])
	g.apply_op(["seal", 2])
	var box := H.take(g)
	g.apply_op(["done"])
	var obs: Array = box["r"]["observations"]
	t.ok(obs.has("obs.fragments.seal_offset"), "genuine ticket, player says the seal is off: reported as said")
	t.ok(obs.has("obs.fragments.ink_breaks"), "player crossed a plain seam: reported as a break")
	t.ok(not obs.has("obs.fragments.ink_continuous"), "no 'ink runs on' once a seam is crossed")
	t.ok(obs.has("obs.fragments.dangzi_clear"), "dang character piece in place")
	t.ok(not obs.has("obs.fragments.unsure"), "whole sheet: not unsure")
	H.close(ctx)
	var ctx2 := H.open_game(self, H.FRAG, H.params("ticket196.json"))
	_place_all(ctx2["game"])
	ctx2["game"].apply_op(["seal", 1])
	var box2 := H.take(ctx2["game"])
	ctx2["game"].apply_op(["done"])
	var obs2: Array = box2["r"]["observations"]
	t.ok(obs2.has("obs.fragments.seal_aligned"), "offset seal, player says aligned: reported as said")
	t.ok(obs2.has("obs.fragments.ink_continuous"), "whole sheet and no cross: ink runs on (even on other paper)")
	H.close(ctx2)
	var ctx3 := H.open_game(self, H.FRAG, H.params("ticket196.json"))
	var box3 := H.take(ctx3["game"])
	ctx3["game"].apply_op(["done"])
	t.eq(box3["r"]["observations"], ["obs.fragments.unsure"], "nothing put together: unsure only")
	H.close(ctx3)
	await t.frames(1)


## Clarity from the process only (DESIGN 7.5): placed share x 600, +200 glass, +200 light (or whole sheet
## when there is no light to use); half or less put together caps at 340.
func _quality(t) -> void:
	var cases := [
		["ticket196.json", false, false, 800],
		["ticket196.json", true, false, 1000],
		["ticket_fake.json", true, false, 800],
		["ticket_fake.json", true, true, 1000],
		["ticket_fake.json", false, true, 800],
	]
	for c in cases:
		var ctx := H.open_game(self, H.FRAG, H.params(str(c[0])))
		var g = ctx["game"]
		_place_all(g)
		if bool(c[1]):
			g.apply_op(["lens", 1])
		if bool(c[2]):
			g.apply_op(["light", 1])
		var box := H.take(g)
		g.apply_op(["done"])
		t.eq(box["r"]["quality_permille"], int(c[3]), "quality " + str(c))
		H.close(ctx)
	var half := H.open_game(self, H.FRAG, H.params("ticket_fake.json"))
	var order: Array = half["game"].layout()["tray_order"]
	_place_all(half["game"], order.slice(3))
	half["game"].apply_op(["lens", 1])
	half["game"].apply_op(["light", 1])
	var hb := H.take(half["game"])
	half["game"].apply_op(["done"])
	t.eq(hb["r"]["quality_permille"], 340, "half put together caps at 340")
	t.ok((hb["r"]["observations"] as Array).has("obs.fragments.unsure"), "half put together: unsure")
	H.close(half)
	var right := H.open_game(self, H.FRAG, H.params("ticket196.json"))
	var wrong := H.open_game(self, H.FRAG, H.params("ticket196.json"))
	for g2 in [right["game"], wrong["game"]]:
		_place_all(g2)
		g2.apply_op(["lens", 1])
	right["game"].apply_op(["seal", 2])
	wrong["game"].apply_op(["seal", 1])
	var rb := H.take(right["game"])
	var wb := H.take(wrong["game"])
	right["game"].apply_op(["done"])
	wrong["game"].apply_op(["done"])
	t.eq(rb["r"]["quality_permille"], wb["r"]["quality_permille"], "right or wrong call: same clarity")
	H.close(right)
	H.close(wrong)
	await t.frames(1)


## Minutes: first time a piece lies in place 1, a cross 1, a seal call 1, first light 1; turning, moving,
## the glass 0; times minutes_per_step, capped at max_minutes.
func _minutes(t) -> void:
	var fix := H.params("ticket_fake.json")
	var ctx := H.open_game(self, H.FRAG, fix)
	var g = ctx["game"]
	var p := int(g.layout()["tray_order"][0])
	g.apply_op(["move", p, 600, 300])
	g.apply_op(["rotate", p, 1])
	g.apply_op(["lens", 1])
	t.eq(g.minutes_spent(), 0, "moving, turning and the glass take no time")
	_place_all(g)
	t.eq(g.minutes_spent(), 6, "six pieces in place: six minutes")
	var row: Dictionary = g.layout()["seams"][0]
	g.apply_op(["seam", int(row["a"]), int(row["b"])])
	g.apply_op(["seam", int(row["a"]), int(row["b"])])
	g.apply_op(["seal", 1])
	g.apply_op(["seal", 2])
	g.apply_op(["light", 1])
	g.apply_op(["light", 0])
	g.apply_op(["light", 1])
	t.eq(g.minutes_spent(), 11, "two crosses, two seal calls, first light")
	H.close(ctx)
	var slow := fix.duplicate(true)
	slow["minutes_per_step"] = 3
	slow["max_minutes"] = 10
	var ctx2 := H.open_game(self, H.FRAG, slow)
	_place_all(ctx2["game"])
	t.eq(ctx2["game"].minutes_spent(), 10, "capped at max_minutes")
	H.close(ctx2)
	await t.frames(1)


## The seal call waits for both halves; a cross waits for both pieces; pieces in place are fixed.
func _gates(t) -> void:
	var ctx := H.open_game(self, H.FRAG, H.params("ticket_fake.json"))
	var g = ctx["game"]
	await t.frames(1)
	var seal: Dictionary = g.layout()["seal"]
	var srow: Dictionary = g.layout()["seams"][int(seal["seam"])]
	var a := int(srow["a"])
	var b := int(srow["b"])
	var btn: Button = g.get("_seal_btns")[0]
	t.ok(btn.disabled, "seal call shut before the halves lie in place")
	for p in [a, b]:
		while g.piece_rot(p) != 0:
			g.apply_op(["rotate", p, 1])
		var slot: Vector2i = g.layout()["slots"][p]
		g.apply_op(["move", p, slot.x, slot.y])
		if p == a:
			t.ok(btn.disabled, "one half is not enough")
	t.ok(not btn.disabled, "seal call open with both halves in place")
	t.ok(g.apply_op(["seam", a, b]), "cross between the two placed pieces")
	t.eq(g.apply_op(["rotate", a, 1]), false, "a piece in place does not turn")
	H.close(ctx)
	await t.frames(1)


func _missing(t) -> void:
	var ctx := H.open_game(self, H.FRAG, H.params("letter_missing.json"))
	var g = ctx["game"]
	t.ok(g.is_hole(3), "piece 3 is the gap")
	t.eq(g.avail_count(), 5, "five given pieces")
	t.eq(g.apply_op(["move", 3, 600, 300]), false, "the gap cannot be moved")
	var box := H.take(g)
	g.autoplay(1.0)
	t.eq(box["r"]["measures"]["placed"], 5, "placed 5")
	t.ok((box["r"]["observations"] as Array).has("obs.fragments.piece_missing"), "gap framed: piece_missing")
	H.close(ctx)
	await t.frames(1)


func _tools(t) -> void:
	var ctx := H.open_game(self, H.FRAG, H.params("ticket_fake.json"))
	var spy = t.spy(ctx["bus"])
	await t.frames(1)
	ctx["game"].autoplay(1.0)
	var tools: Array = []
	for row in spy.ui_events():
		if row[0] == &"mg_tool":
			t.eq(str(row[1].get("kind", "")), "fragments", "mg_tool kind")
			tools.append(str(row[1].get("tool", "")))
	for want in ["move", "rotate", "seam", "seal", "lens", "backlight"]:
		t.ok(tools.has(want), "mg_tool " + want)
	H.close(ctx)
	await t.frames(1)


func _abort(t) -> void:
	var ctx := H.open_game(self, H.FRAG, H.params("ticket196.json"))
	var g = ctx["game"]
	var p := int(g.layout()["tray_order"][0])
	while g.piece_rot(p) != 0:
		g.apply_op(["rotate", p, 1])
	var slot: Vector2i = g.layout()["slots"][p]
	g.apply_op(["move", p, slot.x, slot.y])
	var box := H.take(g)
	for down in [true, false]:
		var ev := InputEventKey.new()
		ev.keycode = KEY_ESCAPE
		ev.physical_keycode = KEY_ESCAPE
		ev.pressed = down
		root.push_input(ev)
	var r: Dictionary = box["r"]
	t.eq(r["aborted"], true, "esc aborts")
	t.eq(r["observations"], [], "esc empty obs")
	t.eq(r["minutes"], 1, "abort keeps the minutes spent")
	t.eq(g.apply_op(["done"]), false, "nothing after abort")
	H.close(ctx)
	await t.frames(1)


## The big "dang" strokes are drawn only on the drawn ticket. A ticket shown as its item picture has none, so
## the notes do not say they are clear, and the ticket's number is not captioned over the picture.
func _dangzi(t) -> void:
	var cap := CardText.ui("g04.ticket.number")
	for art in ["", "item.documents.receipt"]:
		var fix := H.params("ticket_real.json")
		fix["art"] = art
		var ctx := H.open_game(self, H.FRAG, fix)
		var g = ctx["game"]
		await t.frames(1)
		var drawn: bool = art == ""
		t.eq(g.call("_art_image", art) != null, not drawn, "'" + art + "' shows as a picture: " + str(not drawn))
		t.eq(_shows(g, cap), drawn, "'" + art + "' ticket number caption shown: " + str(drawn))
		_place_all(g)
		var box := H.take(g)
		g.apply_op(["done"])
		var obs: Array = box["r"]["observations"]
		t.eq(obs.has("obs.fragments.dangzi_clear"), drawn, "'" + art + "' dang strokes reported: " + str(drawn))
		H.close(ctx)
		await t.frames(1)


func _shows(root_node: Node, text: String) -> bool:
	if root_node is Label and (root_node as Label).is_visible_in_tree() and (root_node as Label).text == text:
		return true
	for c in root_node.get_children():
		if _shows(c, text):
			return true
	return false


## Other paper differs at its cross-seam strokes only (acceptance fix2; was: its paper too): on every piece the
## characters stay plain ink, the paper stays plain paper and the frame and seal stay seal red; only other
## paper has the browner strokes. (test_fragments_eye pins that nothing else on it changes.)
func _odd_paper(t) -> void:
	for name in ["ticket_fake.json", "scroll8.json"]:
		var fix := H.params(name)
		var ctx := H.open_game(self, H.FRAG, fix)
		var g = ctx["game"]
		var L: Dictionary = g.layout()
		var sheet: Image = Paint.base_image(L, fix, null)
		sheet.resize(int(L["w"]), int(L["h"]), Image.INTERPOLATE_NEAREST)
		var odd: Array = L["odd"]
		t.ok(not odd.is_empty(), name + " has other paper")
		var ink := _px(CardTheme.color(&"ink"))
		var paper := _px(CardTheme.color(&"paper"))
		var brown := _px(CardTheme.mix(&"ink", &"ink_soft", Paint.ODD_INK))
		var red := _px(CardTheme.color(&"seal"))
		var srow: Dictionary = L["seams"][int(L["seal"]["seam"])]
		for p in range(int(L["n"])):
			var n := _counts(g.paint_row(p)["img"])
			var tag: String = name + " piece " + str(p) + (" (other paper)" if odd.has(p) else "")
			var bb: Rect2i = L["pieces"][p]["bbox"]
			var written := int(_counts(sheet.get_region(bb), g.paint_row(p)["img"]).get(ink, 0))
			if written > 10:
				t.ok(int(n.get(ink, 0)) > 10, tag + ": characters in plain ink " + str(n.get(ink, 0)))
			t.ok(int(n.get(paper, 0)) > 100, tag + ": plain paper " + str(n.get(paper, 0)))
			if odd.has(p):
				t.ok(int(n.get(brown, 0)) > 0, tag + ": its strokes are browner")
			else:
				t.eq(int(n.get(brown, 0)), 0, tag + ": plain strokes")
			if int(srow["a"]) == p or int(srow["b"]) == p:
				t.ok(int(n.get(red, 0)) > 100, tag + ": its seal half stays seal red " + str(n.get(red, 0)))
		H.close(ctx)
		await t.frames(1)


## A colour as an RGBA8 image stores it (what get_pixel reads back from a painted piece).
func _px(c: Color) -> String:
	var img := Image.create_empty(1, 1, false, Image.FORMAT_RGBA8)
	img.set_pixel(0, 0, c)
	return img.get_pixel(0, 0).to_html()


## Colour counts over img's opaque pixels (or over the pixels where mask is opaque).
func _counts(img: Image, mask: Image = null) -> Dictionary:
	var out := {}
	for y in range(img.get_height()):
		for x in range(img.get_width()):
			var c := img.get_pixel(x, y)
			if (mask.get_pixel(x, y).a if mask != null else c.a) > 0.0:
				var k := c.to_html()
				out[k] = int(out.get(k, 0)) + 1
	return out


## Seen against the light, the sheet's own paper has upright laid lines on sheet x = 0 mod LAID and chain lines
## on sheet y = 0 mod CHAIN on every piece, so they run on across a sound seam (merged pieces start at other
## columns than the piece across from them). Fix2: chain lines added, so vertical seams show it too.
func _fibres(t) -> void:
	for name in H.FRAG_FIXTURES:
		var ctx := H.open_game(self, H.FRAG, H.params(str(name)))
		var g = ctx["game"]
		var L: Dictionary = g.layout()
		var off := 0
		var lines := 0
		for p in range(int(L["n"])):
			if g.is_hole(p) or (L["odd"] as Array).has(p):
				continue
			var bb: Rect2i = L["pieces"][p]["bbox"]
			var img: Image = (g.paint_row(p)["fiber"] as Texture2D).get_image()
			for y in range(img.get_height()):
				for x in range(img.get_width()):
					if img.get_pixel(x, y).a > 0.0:
						lines += 1
						if posmod(bb.position.x + x, Paint.LAID) != 0 and posmod(bb.position.y + y, Paint.CHAIN) != 0:
							off += 1
		t.ok(lines > 0, str(name) + " plain pieces have fibres")
		t.eq(off, 0, str(name) + " every fibre on sheet x = 0 mod LAID or y = 0 mod CHAIN")
		H.close(ctx)
		await t.frames(1)
