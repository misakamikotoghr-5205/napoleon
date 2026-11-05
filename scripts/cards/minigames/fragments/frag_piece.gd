# Paints the torn pieces once per game into images at board scale: the sheet (the document picture, or a
# drawn ticket / letter / scroll), cut along the shared tear profiles, with the ink strokes that cross each
# seam, the riding seal, a water stain and other paper. Every piece gets the same edge colour.
# Other paper shows only where it meets the sheet (acceptance fix2): its half of every cross-seam stroke sits a
# pixel or two off along the seam and is browner; against the light its grain is the sheet's grain moved, so
# the lines stop running on at its seams. Its paper, characters, frame and seal are the sheet's own, so no
# piece stands out as a patch (the old paper tint named the piece at a glance on pale paper and vanished on
# dark pictures). Strokes sit on light parts of the sheet (Layout.settle_strokes), so each one can be seen.
# The stain is mirrored across its seam: it fades both halves of a stroke alike. The riding seal has a dark
# rim (it keeps its edge on red paper) and a carved frame and jing grid (two bars each way) that run across
# the seam, mirrored half to half. Colours from CardTheme; no class_name, preload it. Owner C15.
extends RefCounted

const Layout = preload("res://scripts/cards/minigames/fragments/frag_layout.gd")

const ODD_INK := 0.5          # other paper: its cross-seam strokes, ink toward ink_soft
const STAIN_ALPHA := 0.6
const FIBER_ALPHA := 0.3
const LAID := 5               # against the light: upright laid lines every LAID sheet px ...
const CHAIN := 15             # ... and chain lines across every CHAIN px, in one phase over the whole sheet
const ODD_LAID := 2           # other paper: the same grain, its laid lines moved this far ...
const ODD_CHAIN := 7          # ... and its chain lines this far, so neither runs on across its seams
const SEAL_RIM := 2           # the seal's dark rim, board px
const SEAL_RIM_INK := 0.5     # rim colour: seal_dark toward ink


## Per piece: {"img": Image (hit tests), "tex": ImageTexture, "fiber": ImageTexture, "hole": bool}.
## Settles L.strokes onto light parts of the sheet first (Layout.settle_strokes).
static func paint(L: Dictionary, params: Dictionary, art_img: Image) -> Array:
	var doc := base_image(L, params, art_img)
	doc.resize(int(L["w"]), int(L["h"]), Image.INTERPOLATE_NEAREST)
	Layout.settle_strokes(L, doc)
	var blob := _blob(L)
	var out: Array = []
	for p in range(int(L["n"])):
		var mask_edges := _mask(L, p)
		var mask: Image = mask_edges[0]
		var edges: PackedInt32Array = mask_edges[1]
		var row := {"hole": p == int(L["missing"])}
		if bool(row["hole"]):
			row["img"] = _hole(mask, edges)
		else:
			row["img"] = _piece(L, p, doc, mask, edges, blob)
			row["fiber"] = ImageTexture.create_from_image(_fiber(L, p, mask))
		row["tex"] = ImageTexture.create_from_image(row["img"])
		out.append(row)
	return out


## The sheet at board scale.
static func doc_image(L: Dictionary, params: Dictionary, art_img: Image) -> Image:
	var img := base_image(L, params, art_img)
	img.resize(int(L["w"]), int(L["h"]), Image.INTERPOLATE_NEAREST)
	return img


## The sheet is the drawn pawn ticket (no document picture): only then do the big "dang" strokes and the
## ticket's number belong to it.
static func drawn_ticket(params: Dictionary, art_img: Image) -> bool:
	return (art_img == null or art_img.is_empty()) and str(params.get("doc", "pawn_ticket")) == "pawn_ticket"


## The sheet in its own pixels: the picture over paper, or a drawn sheet of the params.doc kind.
static func base_image(L: Dictionary, params: Dictionary, art_img: Image) -> Image:
	var base: Vector2i = L["base"]
	var img := Image.create_empty(base.x, base.y, false, Image.FORMAT_RGBA8)
	img.fill(CardTheme.color(&"paper"))
	if art_img != null and not art_img.is_empty():
		var pic := art_img.duplicate() as Image
		if pic.is_compressed():
			pic.decompress()
		pic.convert(Image.FORMAT_RGBA8)
		if pic.get_size() != base:
			pic.resize(base.x, base.y, Image.INTERPOLATE_NEAREST)
		img.blend_rect(pic, Rect2i(Vector2i.ZERO, base), Vector2i.ZERO)
		return img
	var seed_v := int(L["seed"])
	match str(params.get("doc", "pawn_ticket")):
		"pawn_ticket":
			_ticket(img, L, seed_v, maxi(0, int(params.get("dangzi_marks", 0))))
		"scroll":
			_scroll(img, seed_v)
		_:
			_letter(img, seed_v)
	return img


# ---------------- drawn sheets (their own pixels, SHEET size) ----------------
static func _ticket(img: Image, L: Dictionary, seed_v: int, dangzi: int) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var red := CardTheme.color(&"seal")
	var pale := CardTheme.mix(&"paper", &"seal", 0.55)
	var ink := CardTheme.color(&"ink")
	_frame(img, Rect2i(3, 3, w - 6, h - 6), red, 2)
	_frame(img, Rect2i(7, 7, w - 14, h - 14), pale, 1)
	img.fill_rect(Rect2i(10, 10, w - 20, 8), red)
	var x := 16
	var i := 0
	while x + 5 < w - 14:
		_glyph(img, Vector2i(x, 11), seed_v, 5700 + i, CardTheme.color(&"paper"))
		x += 10
		i += 1
	_columns(img, seed_v, w - 18, int(float(w) * 0.6), 23, h - 12, 8, ink, 5720)
	var box_x := int(float(w) * 0.42)
	_frame(img, Rect2i(box_x, 22, 12, h - 34), pale, 1)
	_columns(img, seed_v, box_x + 3, box_x + 3, 26, h - 16, 8, CardTheme.color(&"ink_soft"), 5840)
	if dangzi > 0:
		var k: int = L["k"]
		var pr: Rect2i = L["pieces"][int(L["mark"])]["rect"]
		var cx := int(float(pr.position.x + pr.size.x / 2.0) / float(k))
		var cy := int(float(pr.position.y + pr.size.y / 2.0) / float(k))
		_dang(img, Vector2i(clampi(cx - 9, 10, w - 30), clampi(cy - 9, 22, h - 30)), dangzi)


static func _letter(img: Image, seed_v: int) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var rule := CardTheme.mix(&"paper", &"seal", 0.45)
	var x := 6
	while x < w - 4:
		img.fill_rect(Rect2i(x, 4, 1, h - 8), rule)
		x += 12
	var right := 6 + 12 * int(float(w - 16) / 12.0)
	_columns(img, seed_v, right - 9, 10, 8, h - 8, 12, CardTheme.color(&"ink"), 5720)


static func _scroll(img: Image, seed_v: int) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var mount := CardTheme.color(&"umber")
	var side := CardTheme.mix(&"paper", &"umber", 0.35)
	img.fill_rect(Rect2i(0, 0, w, 6), mount)
	img.fill_rect(Rect2i(0, h - 6, w, 6), mount)
	img.fill_rect(Rect2i(0, 0, 4, h), side)
	img.fill_rect(Rect2i(w - 4, 0, 4, h), side)
	var ink := CardTheme.color(&"ink")
	var chars := 3
	var size_c := mini(22, int(float(h - 20) / float(chars)) - 4)
	for c in range(chars):
		var at := Vector2i(int(float(w - size_c) / 2.0), 10 + c * (size_c + 4))
		for s in range(5):
			var u := Layout.draw(seed_v, 5900 + c * 8 + s)
			var b := int(u * 1073741824.0)
			var off := 2 + posmod(b, maxi(1, size_c - 6))
			var run := 6 + posmod(b >> 6, maxi(1, size_c - 8))
			var from := 1 + posmod(b >> 12, 6)
			if posmod(s, 2) == 0:
				img.fill_rect(Rect2i(at.x + from, at.y + off, mini(run, size_c - from), 3), ink)
			else:
				img.fill_rect(Rect2i(at.x + off, at.y + from, 3, mini(run, size_c - from)), ink)
	img.fill_rect(Rect2i(14, h - 20, 7, 7), CardTheme.color(&"seal"))


## Columns of 5x5 character marks, right to left; later columns may stop short.
static func _columns(img: Image, seed_v: int, x_right: int, x_left: int, y0: int, y1: int, step: int, ink: Color,
		idx0: int) -> void:
	var col := 0
	var x := x_right
	while x >= x_left:
		var u := Layout.draw(seed_v, idx0 + col * 16 + 15)
		var stop := y1 - int(float(y1 - y0) * (0.4 * u if col > 0 else 0.0))
		var y := y0
		var ch := 0
		while y + 5 <= stop and ch < 15:
			_glyph(img, Vector2i(x - 2, y), seed_v, idx0 + col * 16 + ch, ink)
			y += 7
			ch += 1
		x -= step
		col += 1


## One made-up character in a 5x5 box: a cross stroke, an upright stroke, sometimes a second bar and a dot.
static func _glyph(img: Image, at: Vector2i, seed_v: int, idx: int, ink: Color) -> void:
	var b := int(Layout.draw(seed_v, idx) * 1073741824.0)
	var hr := b & 3
	var hx0 := (b >> 2) & 1
	var hx1 := 3 + ((b >> 3) & 1)
	img.fill_rect(Rect2i(at.x + hx0, at.y + hr, hx1 - hx0 + 1, 1), ink)
	var vc := mini(4, ((b >> 4) & 3) + ((b >> 6) & 1))
	var vy0 := (b >> 7) & 1
	var vy1 := 3 + ((b >> 8) & 1)
	img.fill_rect(Rect2i(at.x + vc, at.y + vy0, 1, vy1 - vy0 + 1), ink)
	if (b >> 9) & 1 == 1:
		img.fill_rect(Rect2i(at.x, at.y + 4 - ((b >> 10) & 1), 5, 1), ink)
	if (b >> 11) & 1 == 1:
		img.set_pixel(at.x + ((b >> 12) & 3), at.y + ((b >> 14) & 3), ink)


## The pawn-shop character at twice its size, stroke by stroke (dangzi_marks strokes).
static func _dang(img: Image, at: Vector2i, strokes: int) -> void:
	var ink := CardTheme.color(&"ink")
	var parts := [
		Rect2i(4, 0, 1, 3), Rect2i(1, 1, 2, 1), Rect2i(6, 1, 2, 1), Rect2i(1, 3, 7, 1),
		Rect2i(2, 5, 6, 1), Rect2i(7, 3, 1, 6), Rect2i(1, 8, 7, 1),
	]
	for i in range(mini(strokes, parts.size())):
		var r: Rect2i = parts[i]
		img.fill_rect(Rect2i(at + r.position * 2, r.size * 2), ink)


static func _frame(img: Image, r: Rect2i, c: Color, t: int) -> void:
	img.fill_rect(Rect2i(r.position.x, r.position.y, r.size.x, t), c)
	img.fill_rect(Rect2i(r.position.x, r.end.y - t, r.size.x, t), c)
	img.fill_rect(Rect2i(r.position.x, r.position.y, t, r.size.y), c)
	img.fill_rect(Rect2i(r.end.x - t, r.position.y, t, r.size.y), c)


# ---------------- cutting ----------------
## [mask image (white where the piece owns the paper), edge pixels as packed x, y pairs in local coords].
static func _mask(L: Dictionary, p: int) -> Array:
	var piece: Dictionary = L["pieces"][p]
	var bb: Rect2i = piece["bbox"]
	var mask := Image.create_empty(bb.size.x, bb.size.y, false, Image.FORMAT_RGBA8)
	var colx: Array = L["colx"]
	var rowy: Array = L["rowy"]
	for cv in piece["cells"]:
		var c := int(cv.x)
		var r := int(cv.y)
		var cr := Rect2i(int(colx[c]), int(rowy[r]), int(colx[c + 1]) - int(colx[c]), int(rowy[r + 1]) - int(rowy[r]))
		mask.fill_rect(Rect2i(cr.position - bb.position, cr.size), Color.WHITE)
	var band := Layout.JAG + 1
	var vx: Array = []
	for j in range(1, int(L["cols"])):
		vx.append(int(colx[j]))
	var hy: Array = []
	for i in range(1, int(L["rows"])):
		hy.append(int(rowy[i]))
	var band_px: Array = []
	for y in range(bb.position.y, bb.end.y):
		var near_h := false
		for yy in hy:
			if absi(y - int(yy)) <= band:
				near_h = true
		if near_h:
			for x in range(bb.position.x, bb.end.x):
				band_px.append(Vector2i(x, y))
		else:
			for xx in vx:
				for x2 in range(maxi(bb.position.x, int(xx) - band), mini(bb.end.x, int(xx) + band + 1)):
					band_px.append(Vector2i(x2, y))
	for v in band_px:
		var own := Layout.owner_at(L, v.x, v.y)
		mask.set_pixel(v.x - bb.position.x, v.y - bb.position.y, Color.WHITE if own == p else Color.TRANSPARENT)
	var edges := PackedInt32Array()
	var w: int = L["w"]
	var h: int = L["h"]
	for v in band_px:
		var lx: int = v.x - bb.position.x
		var ly: int = v.y - bb.position.y
		if mask.get_pixel(lx, ly).a <= 0.0:
			continue
		if _out(mask, lx - 1, ly) or _out(mask, lx + 1, ly) or _out(mask, lx, ly - 1) or _out(mask, lx, ly + 1):
			edges.append(lx)
			edges.append(ly)
	var r2: Rect2i = piece["rect"]
	if r2.position.x == 0:
		_edge_line(edges, mask, Vector2i(0, 0), Vector2i(0, 1), bb.size.y)
	if r2.end.x == w:
		_edge_line(edges, mask, Vector2i(bb.size.x - 1, 0), Vector2i(0, 1), bb.size.y)
	if r2.position.y == 0:
		_edge_line(edges, mask, Vector2i(0, 0), Vector2i(1, 0), bb.size.x)
	if r2.end.y == h:
		_edge_line(edges, mask, Vector2i(0, bb.size.y - 1), Vector2i(1, 0), bb.size.x)
	return [mask, edges]


static func _out(mask: Image, x: int, y: int) -> bool:
	if x < 0 or y < 0 or x >= mask.get_width() or y >= mask.get_height():
		return true
	return mask.get_pixel(x, y).a <= 0.0


static func _edge_line(edges: PackedInt32Array, mask: Image, from: Vector2i, dir: Vector2i, count: int) -> void:
	for i in range(count):
		var v := from + dir * i
		if mask.get_pixel(v.x, v.y).a > 0.0:
			edges.append(v.x)
			edges.append(v.y)


static func _piece(L: Dictionary, p: int, doc: Image, mask: Image, edges: PackedInt32Array,
		blob: Dictionary) -> Image:
	var bb: Rect2i = L["pieces"][p]["bbox"]
	var work := doc.get_region(bb)
	var is_odd := (L["odd"] as Array).has(p)
	var ink := CardTheme.mix(&"ink", &"ink_soft", ODD_INK) if is_odd else CardTheme.color(&"ink")
	var shift := int((L["odd_shift"] as Dictionary).get(p, 0))
	var seams: Array = L["seams"]
	for st in L["strokes"]:
		var row: Dictionary = seams[int(st["seam"])]
		if int(row["a"]) != p and int(row["b"]) != p:
			continue
		var th := int(st["th"])
		var t := int(st["t"]) + shift
		if bool(row["vertical"]):
			var r := Rect2i(int(row["x0"]) - int(st["la"]), int(row["y0"]) + t, int(st["la"]) + int(st["lb"]), th)
			work.fill_rect(Rect2i(r.position - bb.position, r.size), ink)
		else:
			var r2 := Rect2i(int(row["x0"]) + t, int(row["y0"]) - int(st["la"]), th, int(st["la"]) + int(st["lb"]))
			work.fill_rect(Rect2i(r2.position - bb.position, r2.size), ink)
	var seal: Dictionary = L["seal"]
	if not seal.is_empty():
		var srow: Dictionary = seams[int(seal["seam"])]
		if int(srow["a"]) == p or int(srow["b"]) == p:
			var move := int(seal["shift"]) if int(seal["moved"]) == p else 0
			_seal(work, srow, int(seal["t"]) + move, int(seal["size"]), bb.position, int(L["k"]))
	if not blob.is_empty():
		_stain(work, blob, bb)
	var out := Image.create_empty(bb.size.x, bb.size.y, false, Image.FORMAT_RGBA8)
	out.blit_rect_mask(work, mask, Rect2i(Vector2i.ZERO, bb.size), Vector2i.ZERO)
	var edge := CardTheme.color(&"ink_3")
	var i := 0
	while i + 1 < edges.size():
		out.set_pixel(edges[i], edges[i + 1], edge)
		i += 2
	return out


## The riding seal: a red square across the seam with a dark rim, a carved frame and a carved jing grid (two
## bars each way). Every carved line is mirrored about the square's middle (where the seam runs), so a sound
## seal shows the same pattern on both halves with every line meeting its other half; a seal stamped twice
## steps at the rim, the frame and the bars alike.
static func _seal(work: Image, row: Dictionary, t: int, size_px: int, off: Vector2i, k: int) -> void:
	var half := int(float(size_px) / 2.0)
	var c := Vector2i(int(row["x0"]), int(row["y0"]) + t) if bool(row["vertical"]) else Vector2i(int(row["x0"]) + t, int(row["y0"]))
	var at := c - Vector2i(half, half) - off
	var cut := CardTheme.color(&"seal_paper")
	var u := clampi(k + 1, 3, 5)
	var line := 2
	var box := Rect2i(at, Vector2i(size_px, size_px))
	work.fill_rect(box, CardTheme.color(&"seal"))
	_frame(work, box, CardTheme.mix(&"seal_dark", &"ink", SEAL_RIM_INK), SEAL_RIM)
	_frame(work, box.grow(-u), cut, line)
	var inner0 := 2 * u + line
	var inner := size_px - 2 * inner0
	var near := inner0 + int(float(inner) * 0.3) - 1
	for o in [near, size_px - near - line]:
		work.fill_rect(Rect2i(at + Vector2i(inner0, o), Vector2i(inner, line)), cut)
		work.fill_rect(Rect2i(at + Vector2i(o, inner0), Vector2i(line, inner)), cut)


## The stain as a mask in doc coords: {"rect": Rect2i, "mask": Image, "src": Image} or {}. Blocky, and
## mirrored across its seam line (between sheet px cx - 1 and cx on a vertical seam, cy - 1 and cy on a
## horizontal one): its blocks are counted outward from that line on both sides.
static func _blob(L: Dictionary) -> Dictionary:
	var st: Dictionary = L["stain"]
	if st.is_empty():
		return {}
	var r := int(st["r"])
	var cx := int(st["cx"])
	var cy := int(st["cy"])
	var vertical := bool(st.get("vertical", true))
	var reach := int(float(r) * 1.3) + 2
	var rect := Rect2i(cx - reach, cy - reach, 2 * reach, 2 * reach)
	var mask := Image.create_empty(rect.size.x, rect.size.y, false, Image.FORMAT_RGBA8)
	var src := Image.create_empty(rect.size.x, rect.size.y, false, Image.FORMAT_RGBA8)
	var blk := clampi(int(L["k"]), 2, 4)
	var fill := CardTheme.with_alpha(&"paper_old", STAIN_ALPHA)
	var rim := CardTheme.mix(&"paper_old", &"umber", 0.35)
	rim.a = 0.75
	var ph1 := float(st["ph1"])
	var ph2 := float(st["ph2"])
	for ly in range(rect.size.y):
		for lx in range(rect.size.x):
			var a := lx if vertical else ly
			var b := ly if vertical else lx
			var out_i := a - reach if a >= reach else reach - 1 - a
			var across := float(out_i - posmod(out_i, blk)) + float(blk) / 2.0
			var along := float(b - posmod(b, blk)) + float(blk) / 2.0 - float(reach)
			var ang := atan2(along, across)
			var edge := float(r) * (1.0 + 0.12 * sin(2.0 * ang + ph1) + 0.07 * sin(4.0 * ang + ph2))
			var d := sqrt(across * across + along * along)
			if d < edge:
				mask.set_pixel(lx, ly, Color.WHITE)
				src.set_pixel(lx, ly, rim if d > edge - float(blk) else fill)
	return {"rect": rect, "mask": mask, "src": src}


static func _stain(work: Image, blob: Dictionary, bb: Rect2i) -> void:
	var rect: Rect2i = blob["rect"]
	var hit := rect.intersection(bb)
	if not hit.has_area():
		return
	var src_rect := Rect2i(hit.position - rect.position, hit.size)
	work.blend_rect_mask(blob["src"], blob["mask"], src_rect, hit.position - bb.position)


## Paper grain seen against the light, the same on every piece: upright laid lines on sheet x = 0 mod LAID and
## chain lines across on sheet y = 0 mod CHAIN, so on the sheet's own paper they run on across every seam.
## Other paper has the same grain moved by (ODD_LAID, ODD_CHAIN): nothing to see inside the piece, but its
## lines stop short and start again beside the line at each of its seams (acceptance fix2; the old slanted
## grain picked the piece out at a glance).
static func _fiber(L: Dictionary, p: int, mask: Image) -> Image:
	var bb: Rect2i = L["pieces"][p]["bbox"]
	var pat := Image.create_empty(bb.size.x, bb.size.y, false, Image.FORMAT_RGBA8)
	var c := CardTheme.with_alpha(&"ink_3", FIBER_ALPHA)
	var phase := fiber_phase(L, p)
	var x := posmod(phase.x - bb.position.x, LAID)
	while x < bb.size.x:
		pat.fill_rect(Rect2i(x, 0, 1, bb.size.y), c)
		x += LAID
	var y := posmod(phase.y - bb.position.y, CHAIN)
	while y < bb.size.y:
		pat.fill_rect(Rect2i(0, y, bb.size.x, 1), c)
		y += CHAIN
	var out := Image.create_empty(bb.size.x, bb.size.y, false, Image.FORMAT_RGBA8)
	out.blit_rect_mask(pat, mask, Rect2i(Vector2i.ZERO, bb.size), Vector2i.ZERO)
	return out


## Where piece p's grain lines sit on the sheet (x mod LAID, y mod CHAIN): (0, 0) for the sheet's own paper.
static func fiber_phase(L: Dictionary, p: int) -> Vector2i:
	return Vector2i(ODD_LAID, ODD_CHAIN) if (L["odd"] as Array).has(p) else Vector2i.ZERO


## Where the missing piece should be: a dark gap in the sheet's shape.
static func _hole(mask: Image, edges: PackedInt32Array) -> Image:
	var fill := Image.create_empty(mask.get_width(), mask.get_height(), false, Image.FORMAT_RGBA8)
	fill.fill(CardTheme.color(&"wood_0"))
	var out := Image.create_empty(mask.get_width(), mask.get_height(), false, Image.FORMAT_RGBA8)
	out.blit_rect_mask(fill, mask, Rect2i(Vector2i.ZERO, mask.get_size()), Vector2i.ZERO)
	var edge := CardTheme.color(&"line")
	var i := 0
	while i + 1 < edges.size():
		out.set_pixel(edges[i], edges[i + 1], edge)
		i += 2
	return out
