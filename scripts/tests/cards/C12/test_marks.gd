# Marks on screen (fix2 after the blind acceptance review, 10-25). Every look has one picture wherever it
# lands: painted only inside its "at" and only on the body, changing at least MIN_PX pixels. Old wear only
# ages the body's own colours (part of the old colour always stays) or bites a piece out; tampering lays
# crisp pixels of one colour of its own, chosen once per picture, so the legend tile and the item's marks
# agree. The legend paints each look on a swatch of the book's own ground with the same painter, names it,
# and the board keeps a standing rule line about the lens. A pin on a mark names that mark's part.
# Owner C12.
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const Lib = preload("res://scripts/tests/cards/C12/c12_lib.gd")
const Marks = preload("res://scripts/cards/minigames/spot/spot_marks.gd")
const FlawRender = preload("res://scripts/core/flaw_render.gd")

## One picture per category (light glaze, gold, paper, dark cloth, dark glass, sacking, tan paper, dark jade).
const ARTS: Array[String] = ["item.jewelry.hairpin", "item.utensils.bowl", "item.art.calligraphy", "item.clothing.robe",
	"item.medicine.iodine", "item.rice.jing", "item.documents.field", "item.jewelry.jade", "item.clothing.qipao"]
const SEEDS := 5


func _initialize() -> void:
	var t := T.new(self, "C12_marks")
	t.run_async(_body.bind(t))


func _body(t) -> void:
	var bus := CardEventBus.new()
	root.add_child(bus)
	var mock := MockCardEngine.new(bus)
	t.ok(mock.db != null, "text db")
	await t.frames(1)
	_every_look(t)
	_legend_agrees(t)
	_rows_apart(t)
	await _legend_on_board(t)
	_part_at(t)
	FlawRender.clear_cache()
	bus.queue_free()
	CardAnchors.clear()
	await t.frames(3)


## Body spots of a picture to paint on: 6x6 rects at least 60% body (and two with the outline, for the
## looks that sit on the edge), spread over the picture.
func _spots(base: Image) -> Array:
	var plain: Array = []
	var edge: Array = []
	for y0 in range(2, 56, 7):
		for x0 in range(2, 56, 7):
			var solid := 0
			var rim := 0
			for y in range(y0, y0 + 6):
				for x in range(x0, x0 + 6):
					if base.get_pixel(x, y).a > 0.5:
						solid += 1
						if Marks._rim(base, x, y):
							rim += 1
			if solid >= 22 and rim == 0 and plain.size() < 3:
				plain.append(Rect2i(x0, y0, 6, 6))
			elif solid >= 15 and rim >= 2 and edge.size() < 2:
				edge.append(Rect2i(x0, y0, 6, 6))
	return plain + edge


## Every look, every picture, a few seeds: nothing outside "at" or off the body changes; at least MIN_PX
## pixels change; old wear keeps part of each pixel's own colour (aged toward a warm tone: khaki, old brown or
## yellow) or bites (clear, the ring darker); tampering pixels are one crisp colour from the look's pair.
func _every_look(t) -> void:
	var warm: Array = [CardTheme.color(&"paper_old"), CardTheme.color(&"ink_soft"), CardTheme.color(&"gold")]
	var bad := {}
	for art in ARTS:
		var base := Marks.base_image(art)
		var ground := Marks.ground_of(base)
		var spots := _spots(base)
		t.ok(spots.size() >= 3, "%s: body spots to paint on (%d)" % [art, spots.size()])
		for r: Rect2i in spots:
			for look in Marks.KNOWN_LOOKS:
				for s in SEEDS:
					var img := base.duplicate() as Image
					Marks.paint_look(img, look, Marks.is_wear_look(look), 7919 * s + 13, r, ground)
					var why := _check(base, img, r, Marks.canon(look), warm)
					if why != "":
						var key := "%s %s" % [look, why]
						if not bad.has(key):
							bad[key] = "%s %s seed %d" % [art, str(r), s]
	for key in bad.keys():
		t.ok(false, "%s (first at %s)" % [key, bad[key]])
	t.eq(bad.size(), 0, "every look draws as itself on every body")


func _check(base: Image, img: Image, r: Rect2i, look: String, warm: Array) -> String:
	var changed := 0
	var solid := {}
	for y in Marks.IMG:
		for x in Marks.IMG:
			var a := base.get_pixel(x, y)
			var b := img.get_pixel(x, y)
			if a == b:
				continue
			if not r.has_point(Vector2i(x, y)):
				return "changed a pixel outside at"
			if a.a <= 0.5:
				return "painted off the body"
			changed += 1
			if look == "chip":
				if b.a > 0.5 and not _near(b, a.darkened(0.4)):
					return "a chip pixel is neither bitten out nor darkened"
			elif Marks.WEAR_LOOKS.has(look):
				if not _aged(a, b, warm):
					return "an old-wear pixel is not the old colour aged toward a warm tone"
			else:
				solid[b.to_html()] = true
	if changed < Marks.MIN_PX:
		return "changed fewer than MIN_PX pixels"
	if Marks.DIFFERS_LOOKS.has(look) and solid.size() > (2 if look == "patch" else 1):
		return "tampering in more than one colour"
	return ""


## b = a moved toward one of the warm tones by k <= WEAR_MAX_K (the same k on every channel, within the
## rounding of 8-bit pixels): the old colour is still in it.
func _aged(a: Color, b: Color, warm: Array) -> bool:
	for tone: Color in warm:
		var ks: Array = []
		var ok := true
		for ch in 3:
			var d: float = tone[ch] - a[ch]
			var moved: float = b[ch] - a[ch]
			if absf(d) > 0.15:
				ks.append(moved / d)
			elif absf(moved) > absf(d) * Marks.WEAR_MAX_K + 0.012 or (absf(moved) > 0.012 and signf(moved) != signf(d)):
				ok = false
		if not ok:
			continue
		if ks.is_empty():
			return true   # a tone close to the pixel on every channel: it moved toward it, no further
		var lo: float = ks.min()
		var hi: float = ks.max()
		if lo > 0.0 and hi <= Marks.WEAR_MAX_K + 0.03 and hi - lo < 0.06:
			return true
	return false


func _near(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) < 0.006 and absf(a.g - b.g) < 0.006 and absf(a.b - b.b) < 0.006


## A tampering look has the colour of its legend tile on the item: the tile's one colour is the colour of
## the item's marks on most body spots (only a mark that lands where that colour would not show, a black
## stroke over black writing, takes the pair), so what the book teaches is what the item shows.
func _legend_agrees(t) -> void:
	for art in ARTS:
		var base := Marks.base_image(art)
		var sw := Marks.swatch(base)
		t.eq(Marks.ground_of(sw), Marks.ground_of(base), art + ": the legend swatch is the picture's ground")
		var spots := _spots(base)
		for look in Marks.DIFFERS_LOOKS:
			if look == "patch":
				continue
			var tile := Marks.legend_tile(sw, look, 4242, 1)
			var tile_col := _solid_colour(sw, tile)
			t.ok(tile_col.a > 0.0, "%s %s: the tile shows its look in one colour" % [art, look])
			var same := 0
			for r: Rect2i in spots:
				var img := base.duplicate() as Image
				Marks.paint(img, [{"part": "p", "kind": "differs", "look": look, "at": [r.position.x, r.position.y,
					r.size.x, r.size.y], "fine": 300, "seed": 99}], [], true, 1)
				if _solid_colour(base, img) == tile_col:
					same += 1
			t.ok(same * 2 > spots.size(), "%s %s: the item's marks have the tile's colour (%d of %d)" % [art, look,
				same, spots.size()])


func _solid_colour(before: Image, after: Image) -> Color:
	var seen := Color.TRANSPARENT
	for y in after.get_height():
		for x in after.get_width():
			var b := after.get_pixel(x, y)
			if b != before.get_pixel(x, y):
				if seen.a > 0.0 and seen != b:
					return Color.TRANSPARENT
				seen = b
	return seen


## The two legend rows never share a kind of picture: every category's old-wear looks are drawn as aged body
## colours and its tampering looks as crisp colours of their own (the engine's legend, after its look_alias),
## and on the category's own swatch no colour a tampering tile writes is one an old-wear tile writes.
func _rows_apart(t) -> void:
	var cats: Dictionary = CardItems.templates().get("appraise", {}).get("categories", {})
	var alias: Dictionary = CardDB.read_json("res://data/cards/rules/economy.json")["appraise"]["spot"]["look_alias"]
	var art_of := {"rice": "item.rice.jing", "clothing": "item.clothing.qipao", "jewelry": "item.jewelry.hairpin",
		"utensils": "item.utensils.bowl", "art": "item.art.landscape", "medicine": "item.medicine.aspirin",
		"documents": "item.documents.field"}
	for cat in art_of.keys():
		var rules: Dictionary = cats.get(cat, {})
		t.ok(not rules.is_empty(), cat + ": category rules")
		var wear: Array = []
		for k in rules.get("worn", []) + rules.get("wear", []):
			wear.append(str(alias.get(str(k), str(k))))
		var differs: Array = []
		for k in rules.get("fake", []) + [rules.get("stolen", "scrape")]:
			differs.append(str(alias.get(str(k), str(k))))
		for look in wear:
			t.ok(Marks.WEAR_LOOKS.has(look), "%s: old-wear look %s is drawn as aged body colour" % [cat, look])
		for look in differs:
			t.ok(Marks.DIFFERS_LOOKS.has(look), "%s: tampering look %s is drawn in a colour of its own" % [cat, look])
		var sw := Marks.swatch(Marks.base_image(str(art_of[cat])))
		var wear_cols := {}
		for look in wear:
			_written(sw, Marks.legend_tile(sw, look, 77, 1), wear_cols)
		for look in differs:
			var mine := {}
			_written(sw, Marks.legend_tile(sw, look, 77, 2), mine)
			for c in mine.keys():
				t.ok(not wear_cols.has(c), "%s: %s writes colour %s, which an old-wear tile writes too" % [cat, look, c])


func _written(before: Image, after: Image, into: Dictionary) -> void:
	for y in after.get_height():
		for x in after.get_width():
			var b := after.get_pixel(x, y)
			if b != before.get_pixel(x, y) and b.a > 0.5:
				into[b.to_html()] = true


## The board: one tile per look the params' legend names, each the painter's tile on the book's swatch, its
## name under it (CardText); the rule line about the lens stands under the ink, book open or shut.
func _legend_on_board(t) -> void:
	var params: Dictionary = Lib.fixture("hairpin3")
	params.merge({"art": "item.utensils.tinpot", "atlas_art": "item.utensils.tinpot",
		"legend": {"wear": ["scuff", "chip", "shine"], "differs": ["base_metal", "retrace", "scrape"]}}, true)
	var game := Lib.open_game(self, params)
	await t.frames(1)
	var board := Lib.board(game)
	var rule := board.get_node_or_null("Rule") as Label
	t.ok(rule != null and rule.visible and rule.text == CardText.ui("c12.rule.lens"), "the lens rule stands with the book shut")
	t.ok(not (board.get_node("Legend") as Control).visible, "legend waits for the book")
	game.apply_op(["atlas"])
	await t.frames(1)
	t.ok((board.get_node("Legend") as Control).visible, "legend shows once the book is open")
	var sw := Marks.swatch(Marks.base_image("item.utensils.tinpot"))
	var layout_seed := int(params["seed"])
	var index := 0
	for r in 2:
		var row: Array = params["legend"]["wear" if r == 0 else "differs"]
		for look in row:
			index += 1
			var holder := board.get_node_or_null("Legend/Tile%d_%d" % [r, index])
			t.ok(holder != null, "legend tile for %s" % look)
			if holder == null:
				continue
			var tex := (holder.get_child(0) as TextureRect).texture
			var want := Marks.legend_tile(sw, str(look), layout_seed, index)
			t.ok(tex.get_image().get_data() == want.get_data(), "board tile %d is %s on the book's swatch" % [index, look])
			t.ok(holder.size.x >= 60.0, "legend tile %s is at least 60 px" % look)
			var cap := board.get_node_or_null("Legend/Name%d_%d" % [r, index]) as Label
			t.ok(cap != null and cap.text == CardText.ui("c12.look." + str(look)), "legend tile %s has its name" % look)
	game.queue_free()
	CardAnchors.clear()
	await t.frames(1)


## Overlapping part rects (a newspaper: authenticity 8,18,20,14 and provenance 22,26,18,12): a pin on the
## authenticity mark names authenticity; a pin in the overlap off every mark keeps the smallest rect.
func _part_at(t) -> void:
	var params: Dictionary = Lib.fixture("hairpin3")
	params["parts"] = [{"id": "authenticity", "rect": [8, 18, 20, 14], "tool": "lens"},
		{"id": "provenance", "rect": [22, 26, 18, 12], "tool": "eye"},
		{"id": "material", "rect": [42, 4, 16, 10], "tool": "eye"}]
	params["marks"] = [{"part": "authenticity", "kind": "differs", "look": "retrace", "at": [21, 25, 6, 6],
		"fine": 300, "seed": 11}, {"part": "provenance", "kind": "wear", "look": "scuff", "at": [32, 30, 6, 6],
		"fine": 300, "seed": 12}, {"part": "material", "kind": "wear", "look": "shine", "at": [44, 6, 6, 6],
		"fine": 300, "seed": 13}]
	var game := Lib.open_game(self, params)
	t.eq(game.part_at(24, 28), "authenticity", "pin on the authenticity mark in the overlap")
	t.eq(game.part_at(27, 29), "provenance", "overlap off every mark: the smaller rect")
	t.eq(game.part_at(34, 32), "provenance", "pin on the provenance mark")
	game.queue_free()
	CardAnchors.clear()
	var r = Lib.replay(self, params, [["pin", 24, 28, 2], ["done"]])
	t.ok(r != null, "pin and hand back")
	if r != null:
		t.eq(r.get("observations"), ["obs.spot.authenticity.differs"], "the call names the pinned mark's part")
