# Spot the difference: pictures only. Base art, the marks, the legend tiles. Owner C12. No class_name.
# Contract: docs/cards/CARDS_INTERFACES.md 8.2 (spot), appraise DESIGN 4.2-4.3.
#
# Every look has one picture, wherever it lands (on the item, or on its legend tile), and it is drawn the
# same way on any body (no look turns into another look where it finds no stroke or edge):
#   old wear (scuff, shine, watermark, yellow, repair, chip): the body's own colours aged toward a faded
#     khaki or an old brown (_wear_px: part of the old colour always stays), with soft ends; a chip bites a
#     piece out of the body. Never a colour of their own.
#   tampering (speck, base_metal, retrace, stitch, seal, whiten, patch, scrape): crisp pixels of a colour of
#     their own (ink black or bleach white, brass, seal red, a patch's flat square and seam). Where that
#     colour would hide on this picture's ground, the look's pair colour (black <-> white, ...), chosen once
#     per picture (_tone), so the item's marks and the legend tile agree; the shape is the same.
# Old wear moves its pixels at least WEAR_STEP (as far as the body lets it) and every mark changes at least
# MIN_PX pixels, so whether a mark can be seen says nothing; what kind of picture it is does. Nothing is
# drawn outside "at" (the rect the engine judges) or off the body. Colours: palette keys and the art's own.
# A mark without "at" (old params) keeps the old picture: the whole part rect, wear = scuff, differs = speck
# (fine) or notch (drawn as a chip).
extends RefCounted

const FlawRender = preload("res://scripts/core/flaw_render.gd")
const Rng = preload("res://scripts/sim/jev_rng.gd")

const IMG := 64
const FINE_AT := 500
const DOMAIN := "c.mg.spot.layout"
const OLD_AT := 6         # old params: the judged spot is the part centre 6x6
const TILE := 12          # legend tile: a 12x12 swatch of the book's own body, rim along the top
const MIN_PX := 4         # every mark changes at least this many pixels (the engine puts "at" on the body)
const WEAR_STEP := 0.35   # an old-wear pixel moves at least this far (as far as the body lets it)
const SOLID_STEP := 0.3   # a tampering colour that stands out less than this from the ground takes its pair
const SHOW_STEP := 0.22   # a tampering pixel that moves at least this far shows; MIN_PX of them per mark
const WEAR_MAX_K := 0.8   # old wear never covers the body's own colour completely

const WEAR_LOOKS: Array[String] = ["scuff", "shine", "watermark", "yellow", "repair", "chip"]
const DIFFERS_LOOKS: Array[String] = ["speck", "base_metal", "retrace", "stitch", "seal", "whiten", "patch",
	"scrape"]
## Old FlawRender names the engine no longer sends (it maps them, economy.json appraise.spot.look_alias).
const ALIAS := {"thin": "retrace", "erase": "retrace", "notch": "chip", "stain": "watermark"}
const KNOWN_LOOKS: Array[String] = ["scuff", "shine", "watermark", "yellow", "repair", "chip", "speck",
	"base_metal", "retrace", "stitch", "seal", "whiten", "patch", "scrape", "thin", "erase", "notch", "stain"]
## Looks that sit on the body's edge (the engine puts their "at" over the outline).
const EDGE_LOOKS: Array[String] = ["chip", "base_metal"]


## The item picture (64x64 RGBA) from the card art, or FlawRender's drawn stand-in.
static func base_image(art_id: String) -> Image:
	var tex := CardArt.texture(art_id) if art_id != "" else null
	var img: Image = null
	if tex != null:
		img = tex.get_image()
	if img != null:
		if img.is_compressed():
			img.decompress()
		img = img.duplicate()
		img.convert(Image.FORMAT_RGBA8)
		if img.get_width() != IMG or img.get_height() != IMG:
			img.resize(IMG, IMG, Image.INTERPOLATE_NEAREST)
		return img
	var bits := art_id.split(".")
	var leaf := bits[bits.size() - 1] if not bits.is_empty() else "thing"
	var out := FlawRender.proc_base(leaf if leaf != "" else "thing")
	FlawRender.clear_cache()
	return out


static func texture(img: Image) -> Texture2D:
	return ImageTexture.create_from_image(img)


## The body mask the engine places marks with (items.json "spot": {"opaque": ...}): 64 rows of 16 hex digits,
## one bit per pixel (most significant first), set where the picture is opaque; rows joined by spaces.
static func body_mask(img: Image) -> String:
	var rows := PackedStringArray()
	for y in IMG:
		var row := ""
		for d in IMG / 4:
			var v := 0
			for b in 4:
				if img.get_pixel(d * 4 + b, y).a > 0.5:
					v |= 8 >> b
			row += "%x" % v
		rows.append(row)
	return " ".join(rows)


static func has_at(mark: Dictionary) -> bool:
	return typeof(mark.get("at")) == TYPE_ARRAY and (mark["at"] as Array).size() == 4


static func part_of(parts: Array, pid: String) -> Dictionary:
	for part in parts:
		if typeof(part) == TYPE_DICTIONARY and str(part.get("id", "")) == pid:
			return part
	return {}


static func rect_of(arr) -> Rect2i:
	if typeof(arr) != TYPE_ARRAY or (arr as Array).size() != 4:
		return Rect2i()
	var a: Array = arr
	return Rect2i(int(a[0]), int(a[1]), int(a[2]), int(a[3])).intersection(Rect2i(0, 0, IMG, IMG))


## Fine marks show only through the lens. Old params also count a part looked at with the lens as fine.
static func is_fine(mark: Dictionary, parts: Array) -> bool:
	if int(mark.get("fine", 0)) >= FINE_AT:
		return true
	if has_at(mark):
		return false
	return str(part_of(parts, str(mark.get("part", ""))).get("tool", "")) == "lens"


## Where the mark is painted: "at", or (old params) the whole part rect.
static func paint_rect(mark: Dictionary, parts: Array) -> Rect2i:
	if has_at(mark):
		return rect_of(mark["at"])
	return rect_of(part_of(parts, str(mark.get("part", ""))).get("rect", []))


## The spot a pin has to hit: "at", or (old params) the part centre 6x6.
static func spot_rect(mark: Dictionary, parts: Array) -> Rect2i:
	if has_at(mark):
		return rect_of(mark["at"])
	var pr := rect_of(part_of(parts, str(mark.get("part", ""))).get("rect", []))
	if pr.size.x <= 0 or pr.size.y <= 0:
		return Rect2i()
	var c := pr.position + pr.size / 2
	return Rect2i(c.x - OLD_AT / 2, c.y - OLD_AT / 2, OLD_AT, OLD_AT).intersection(Rect2i(0, 0, IMG, IMG))


## The look a mark is painted with: its "look", or (old params) wear = scuff, differs = speck / notch.
static func look_of(mark: Dictionary) -> String:
	var mk := str(mark.get("kind", ""))
	var look := str(mark.get("look", ""))
	if look != "" and has_at(mark) and look in KNOWN_LOOKS:
		return look
	if mk == "wear":
		return "scuff"
	if mk == "differs":
		return "speck" if int(mark.get("fine", 0)) >= FINE_AT else "notch"
	return ""


## The picture a look name is drawn as (old names map onto the look that shows the same thing).
static func canon(look: String) -> String:
	return str(ALIAS.get(look, look))


static func is_wear_look(look: String) -> bool:
	return WEAR_LOOKS.has(canon(look))


## Paints every mark (fine_too: the lens picture) onto img. The tampering colours are chosen once for the
## picture, against its ground (_ground), so every mark of a look has the colour its legend tile has.
static func paint(img: Image, marks: Array, parts: Array, fine_too: bool, layout_seed: int) -> void:
	var ground := ground_of(img)
	for mark in marks:
		if typeof(mark) != TYPE_DICTIONARY:
			continue
		if is_fine(mark, parts) and not fine_too:
			continue
		var r := paint_rect(mark, parts)
		if r.size.x <= 0 or r.size.y <= 0:
			continue
		var look := look_of(mark)
		var s := int(mark.get("seed", 0)) & 0x7fffffff
		if look == "":
			_dots(img, r, s, layout_seed)
		else:
			paint_look(img, look, str(mark.get("kind", "")) == "wear", s, r, ground)


## Paints one look into r, only inside r and only on the body (alpha > 0.5). ground: the picture's ground
## colour (ground_of; found from img when not given). An unknown name is drawn as scuff (wear) or speck.
static func paint_look(img: Image, look: String, wear: bool, s: int, r: Rect2i, ground: Color = Color.TRANSPARENT) -> void:
	r = r.intersection(Rect2i(0, 0, IMG, IMG))
	if r.size.x <= 0 or r.size.y <= 0:
		return
	if ground.a < 0.5:
		ground = ground_of(img)
	var name := canon(look)
	if not WEAR_LOOKS.has(name) and not DIFFERS_LOOKS.has(name):
		name = "scuff" if wear else "speck"
	s = s & 0x7fffffff
	match name:
		"scuff":
			_wear_px(img, _streaks(img, s, r), &"paper_old", &"ink_soft")
		"shine":
			_wear_px(img, _oval(img, r, 0.0, 0.5), &"paper_old", &"ink_soft")
		"watermark":
			_wear_px(img, _oval(img, r, 0.5, 0.0), &"paper_old", &"ink_soft")
		"yellow":
			_wear_px(img, _oval(img, r, 0.0, 0.3), &"gold", &"ink_soft")
		"repair":
			_wear_px(img, _mend(img, s, r), &"paper_old", &"ink_soft")
		"chip":
			_chip(img, s, r)
		"speck":
			var dots := _tone(ground, _ink(), Color.WHITE)
			var pts := _specks(img, s, r, dots[0])
			if pts.size() < MIN_PX:
				dots = [dots[1], dots[0]]
				pts = _specks(img, s, r, dots[0])
			_solid(img, pts, dots, r)
		"base_metal":
			_solid(img, _rim_run(img, s, r), _tone(ground, _brass(), _brass().lightened(0.45)), r)
		"retrace":
			_solid(img, _stroke(img, s, r), _tone(ground, _ink(), Color.WHITE), r)
		"stitch":
			_solid(img, _dashes(img, s, r), _tone(ground, Color.WHITE, _ink()), r)
		"seal":
			_solid(img, _stamp(img, r), _tone(ground, _red(), CardTheme.color(&"seal_paper"), SHOW_STEP), r)
		"whiten":
			_solid(img, _checker(img, s, r), _tone(ground, Color.WHITE, CardTheme.color(&"mist")), r)
		"patch":
			_patch(img, r, _tone(ground, _ink(), CardTheme.color(&"seal_paper")))
		"scrape":
			_solid(img, _cross(img, r), _tone(ground, Color.WHITE, _ink()), r)


# ---------------- colours ----------------

static func _ink() -> Color:
	return CardTheme.color(&"ink")


static func _brass() -> Color:
	return CardTheme.mix(&"gold", &"jade", 0.45)


static func _red() -> Color:
	return CardTheme.color(&"seal_dark")


## How far a pixel moved, as the eye sees it: its change in brightness, or half its largest channel step
## (a change of hue at about the same brightness, brass on grey, shows too).
static func _step(a: Color, b: Color) -> float:
	var hue := maxf(absf(b.r - a.r), maxf(absf(b.g - a.g), absf(b.b - a.b)))
	return maxf(absf(_lum(b) - _lum(a)), 0.5 * hue)


static func _lum(c: Color) -> float:
	return c.r * 0.3 + c.g * 0.59 + c.b * 0.11


# ---------------- drawing ----------------

static func _body(img: Image, x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height() and img.get_pixel(x, y).a > 0.5


## A body pixel next to the background (or the picture's border): the outline.
static func _rim(img: Image, x: int, y: int) -> bool:
	if not _body(img, x, y):
		return false
	for d in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
		if not _body(img, x + d.x, y + d.y):
			return true
	return false


static func _h(s: int, a: int, b: int = 0, c: int = 0) -> float:
	return FlawRender.h01(s, a, b, c)


## Old wear: each [pixel, weight] is aged toward a warm tone, the light one (`light`, a faded khaki) or the
## dark one (`dark`, an old brown), whichever it is further from, until it has moved WEAR_STEP (weight 1; a
## soft end less), never more than WEAR_MAX_K of the way: the body's own colour stays in it.
static func _wear_px(img: Image, pts: Array, light: StringName, dark: StringName) -> void:
	var to_a := CardTheme.color(light)
	var to_b := CardTheme.color(dark)
	for row in pts:
		var p: Vector2i = row[0]
		var c := img.get_pixel(p.x, p.y)
		var to := to_a if _step(c, to_a) >= _step(c, to_b) else to_b
		var k := clampf(WEAR_STEP / maxf(_step(c, to), 0.001), 0.3, WEAR_MAX_K) * float(row[1])
		var out := c.lerp(to, k)
		out.a = c.a
		img.set_pixel(p.x, p.y, out)


## A tampering look's colours on this picture, [its colour, the other one]: `main`, unless it hardly stands
## out from the picture's ground (less than SOLID_STEP) and `pair` stands out more (ink black <-> bleach
## white, seal red <-> pale, ...). Chosen once per picture, so a look has the colour of its legend tile;
## only a mark that lands where that colour is already (a black stroke over black) takes the other one.
static func _tone(ground: Color, main: Color, pair: Color, bar: float = SOLID_STEP) -> Array:
	main.a = 1.0
	pair.a = 1.0
	var a := _step(ground, main)
	return [main, pair] if a >= bar or a >= _step(ground, pair) else [pair, main]


## The picture's ground: its commonest colour inside the outline (what the legend swatch is made of).
static func ground_of(img: Image) -> Color:
	var bag := {}
	for y in img.get_height():
		for x in img.get_width():
			if _body(img, x, y) and not _rim(img, x, y):
				var c := img.get_pixel(x, y)
				var key := c.to_rgba32()
				if not bag.has(key):
					bag[key] = [0, c]
				bag[key][0] += 1
	return _commonest(bag, CardTheme.color(&"paper"))


## Tampering: every pixel of pts in the look's colour (tones from _tone). A pixel that already has about that
## colour (a black stroke over black text) does not show; when fewer than MIN_PX of the shape's pixels would
## show (move SHOW_STEP), the other tone is used if more would show with it, and if still too few the body
## pixels of r nearest the shape that would show are added.
static func _solid(img: Image, pts: Array, tones: Array, r: Rect2i) -> void:
	if pts.is_empty():
		return
	var col: Color = tones[0]
	var shown := _showing(img, pts, col)
	if shown.size() < MIN_PX:
		var other := _showing(img, pts, tones[1])
		if other.size() > shown.size():
			col = tones[1]
			shown = other
	var extra: Array = []
	if shown.size() < MIN_PX:
		var from := Vector2(pts[0])
		var more: Array = []
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				var q := Vector2i(x, y)
				if _body(img, x, y) and not pts.has(q) and _step(img.get_pixel(x, y), col) >= SHOW_STEP:
					more.append([Vector2(q).distance_to(from), y, x])
		more.sort()
		for row in more.slice(0, MIN_PX - shown.size()):
			extra.append(Vector2i(int(row[2]), int(row[1])))
	for p: Vector2i in pts + extra:
		img.set_pixel(p.x, p.y, col)


static func _showing(img: Image, pts: Array, col: Color) -> Array:
	var out: Array = []
	for p: Vector2i in pts:
		if _step(img.get_pixel(p.x, p.y), col) >= SHOW_STEP:
			out.append(p)
	return out


## How plainly colour col would stand out at pts: per pixel, half its step from the pixel it covers and half
## its mean step from the body pixels round it that it does not cover (a dark dot beside a dark outline
## hides); the mean over pts.
static func _contrast(img: Image, pts: Array, col: Color) -> float:
	if pts.is_empty():
		return 0.0
	var total := 0.0
	for p: Vector2i in pts:
		var round_step := 0.0
		var n := 0
		for d in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, -1), Vector2i(1, 1),
				Vector2i(-1, 1), Vector2i(1, -1)]:
			var q: Vector2i = p + d
			if _body(img, q.x, q.y) and not pts.has(q):
				round_step += _step(img.get_pixel(q.x, q.y), col)
				n += 1
		var own := _step(img.get_pixel(p.x, p.y), col)
		total += 0.5 * own + 0.5 * (round_step / float(n) if n > 0 else own)
	return total / float(pts.size())


## Two short parallel streaks (scuff): [pixel, weight], the ends softer.
static func _streaks(img: Image, s: int, r: Rect2i) -> Array:
	var out: Array = []
	var w := r.size.x
	var h := r.size.y
	var length := clampi(w - 1, 3, 6)
	var down := _h(s, 1) < 0.5
	var y0 := r.position.y + int(_h(s, 2) * float(maxi(1, h - 3)))
	var x0 := r.position.x + int(_h(s, 3) * float(maxi(1, w - length + 1)))
	for i in 2:
		for j in length:
			var x := x0 + j + i
			var y := y0 + 2 * i + (j / 2 if down else (length - 1 - j) / 2)
			if r.has_point(Vector2i(x, y)) and _body(img, x, y):
				out.append([Vector2i(x, y), 0.6 if j == 0 or j == length - 1 else 1.0])
	return _at_least(img, out, r, s)


## Pixels of the ellipse inside r with inner < d < 1 (inner 0: filled); weight 1 - fall * d (softer rim).
static func _oval(img: Image, r: Rect2i, inner: float, fall: float) -> Array:
	var out: Array = []
	var c := Vector2(r.position) + Vector2(r.size) / 2.0
	var rx := float(r.size.x) / 2.0
	var ry := float(r.size.y) / 2.0
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			var d := Vector2((x + 0.5 - c.x) / rx, (y + 0.5 - c.y) / ry).length()
			if d < 1.0 and d >= inner and _body(img, x, y):
				out.append([Vector2i(x, y), 1.0 - fall * d])
	return out


## An old mend: a row of short stitches with a tick above and below each (repair), on the row of r (not its
## top or bottom one) that crosses the most body, the seed's row first among equals.
static func _mend(img: Image, s: int, r: Rect2i) -> Array:
	var out: Array = []
	var y := _row(img, s, r, 4)
	for x in range(r.position.x, r.end.x):
		var k := (x - r.position.x) % 3
		if k != 2 and _body(img, x, y):
			out.append([Vector2i(x, y), 1.0])
		if k == 0:
			for dy in [-1, 1]:
				if r.has_point(Vector2i(x, y + dy)) and _body(img, x, y + dy):
					out.append([Vector2i(x, y + dy), 0.75])
	return _at_least(img, out, r, s)


## The inner row of r crossing the most body pixels (rows nearest the seed's own row win ties).
static func _row(img: Image, s: int, r: Rect2i, salt: int) -> int:
	var lo := r.position.y + (1 if r.size.y >= 3 else 0)
	var hi := r.end.y - (1 if r.size.y >= 3 else 0)
	var want := lo + int(_h(s, salt) * float(maxi(1, hi - lo)))
	var best := want
	var best_key := Vector2i(-1, 0)
	for y in range(lo, hi):
		var n := 0
		for x in range(r.position.x, r.end.x):
			if _body(img, x, y):
				n += 1
		var key := Vector2i(n, -absi(y - want))
		if key > best_key:
			best_key = key
			best = y
	return best


## A bite out of the body: the rim pixel nearest the middle of r (else the body pixel nearest it) and its
## neighbours go clear, the ring round them darker.
static func _chip(img: Image, s: int, r: Rect2i) -> void:
	var mid := Vector2(r.position) + Vector2(r.size) / 2.0
	var best := Vector2i(-1, -1)
	var best_d := INF
	for rim in [true, false]:
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				if not _body(img, x, y) or (rim and not _rim(img, x, y)):
					continue
				var d := (Vector2(x, y) + Vector2(0.5, 0.5)).distance_to(mid) + _h(s, x, y) * 1.5
				if d < best_d:
					best_d = d
					best = Vector2i(x, y)
		if best.x >= 0:
			break
	if best.x < 0:
		return
	var src := img.duplicate() as Image
	var hole := 1.0
	while hole < 1.6 and _bite(src, r, best, hole) < 3:
		hole += 0.5
	for y in range(best.y - 3, best.y + 4):
		for x in range(best.x - 3, best.x + 4):
			if not r.has_point(Vector2i(x, y)) or not _body(src, x, y):
				continue
			var d := Vector2(x - best.x, y - best.y).length()
			if d <= hole:
				img.set_pixel(x, y, Color.TRANSPARENT)
			elif d <= hole + 1.3:
				img.set_pixel(x, y, src.get_pixel(x, y).darkened(0.4))


## How many body pixels of r a bite of this radius round at takes.
static func _bite(img: Image, r: Rect2i, at: Vector2i, radius: float) -> int:
	var n := 0
	for y in range(at.y - 2, at.y + 3):
		for x in range(at.x - 2, at.x + 3):
			if r.has_point(Vector2i(x, y)) and _body(img, x, y) and Vector2(x - at.x, y - at.y).length() <= radius:
				n += 1
	return n


## Isolated single dots of colour col (no two touching, corners included): the body pixels of r where col
## stands out most, against the pixel itself and against its neighbours (the smaller of the two: a dot never
## hides in a dark outline when a plain spot is there), seed order among equals.
static func _specks(img: Image, s: int, r: Rect2i, col: Color) -> Array:
	var cands: Array = []
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			var own := _step(img.get_pixel(x, y), col) if _body(img, x, y) else 0.0
			if own >= SHOW_STEP:
				var score := snappedf(minf(own, 2.0 * _contrast(img, [Vector2i(x, y)], col) - own), 0.1)
				cands.append([-score, _h(s, x, y, 3), Vector2i(x, y)])
	cands.sort()
	var want := clampi(r.get_area() / 6, MIN_PX, 8)
	var out: Array = []
	for c in cands:
		var p: Vector2i = c[2]
		var free := true
		for q in out:
			if absi(q.x - p.x) <= 1 and absi(q.y - p.y) <= 1:
				free = false
				break
		if free:
			out.append(p)
			if out.size() >= want:
				break
	return out


## Base metal showing: the outline nearest the middle of r (up to 6 pixels) and the body pixels just inside
## it, a band two pixels deep; with no outline in r, the top body rows of r.
static func _rim_run(img: Image, s: int, r: Rect2i) -> Array:
	var mid := Vector2(r.position) + Vector2(r.size) / 2.0
	var rims: Array = []
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			if _rim(img, x, y):
				rims.append([(Vector2(x, y) + Vector2(0.5, 0.5)).distance_to(mid) + _h(s, x, y) * 0.5, Vector2i(x, y)])
	rims.sort()
	var out: Array = []
	for row in rims.slice(0, 6):
		out.append(row[1])
	if out.is_empty():
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				if _body(img, x, y) and out.size() < 5:
					out.append(Vector2i(x, y))
			if not out.is_empty():
				break
	for p: Vector2i in out.duplicate():
		for d in [Vector2i(0, 1), Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, 0)]:
			var q: Vector2i = p + d
			if r.has_point(q) and _body(img, q.x, q.y) and not _rim(img, q.x, q.y) and not out.has(q):
				out.append(q)
	return _at_least_px(img, out, r, s)


## A new ink stroke: two pixels thick, corner to corner across r.
static func _stroke(img: Image, s: int, r: Rect2i) -> Array:
	var rising := _h(s, 5) < 0.5
	var a := Vector2i(r.position.x, r.end.y - 1 if rising else r.position.y)
	var b := Vector2i(r.end.x - 1, r.position.y if rising else r.end.y - 1)
	var out: Array = []
	for p in _line(a, b):
		for q in [p, p + Vector2i(1, 0)]:
			if r.has_point(q) and _body(img, q.x, q.y) and not out.has(q):
				out.append(q)
	return _at_least_px(img, out, r, s)


## New thread: a straight row of dashes (two on, one off), no ticks; a second row when one is too short.
static func _dashes(img: Image, s: int, r: Rect2i) -> Array:
	var out: Array = []
	var y := _row(img, s, r, 6)
	for row in [y, y + 2 if y + 2 < r.end.y else y - 2]:
		for x in range(r.position.x, r.end.x):
			if (x - r.position.x) % 3 != 2 and r.has_point(Vector2i(x, row)) and _body(img, x, row):
				out.append(Vector2i(x, row))
		if out.size() >= MIN_PX + 1:
			break
	return out


## An added stamp: a square outline (3-5 px) in the middle of r, with its centre dot.
static func _stamp(img: Image, r: Rect2i) -> Array:
	var side := clampi(mini(r.size.x, r.size.y), 3, 5)
	var o := r.position + (r.size - Vector2i(side, side)) / 2
	var out: Array = []
	for y in range(o.y, o.y + side):
		for x in range(o.x, o.x + side):
			var edge := x == o.x or y == o.y or x == o.x + side - 1 or y == o.y + side - 1
			var centre := side % 2 == 1 and x == o.x + side / 2 and y == o.y + side / 2
			if (edge or centre) and _body(img, x, y):
				out.append(Vector2i(x, y))
	return out


## Bleach: every other pixel of a small filled oval.
static func _checker(img: Image, s: int, r: Rect2i) -> Array:
	var out: Array = []
	var par := int(_h(s, 7) < 0.5)
	for row in _oval(img, r, 0.0, 0.0):
		var p: Vector2i = row[0]
		if (p.x + p.y + par) % 2 == 0:
			out.append(p)
	return _at_least_px(img, out, r, s)


## Scraped off: two thin crossing scratches, corner to corner.
static func _cross(img: Image, r: Rect2i) -> Array:
	var out: Array = []
	for pair in [[r.position, r.end - Vector2i(1, 1)], [Vector2i(r.position.x, r.end.y - 1), Vector2i(r.end.x - 1, r.position.y)]]:
		for p in _line(pair[0], pair[1]):
			if _body(img, p.x, p.y) and not out.has(p):
				out.append(p)
	return out


## A patch: a flat square of the body's average colour a shade off (the weave, grain or brushwork under it
## gone), all of r, with a seam of dashes round its edge (two on, one off) in the seam tones (_tone).
static func _patch(img: Image, r: Rect2i, seam_tones: Array) -> void:
	var sum := Color.TRANSPARENT
	var n := 0
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			if _body(img, x, y):
				sum += img.get_pixel(x, y)
				n += 1
	if n == 0:
		return
	var mean := sum / float(n)
	mean.a = 1.0
	var fill := mean.lightened(0.3) if _lum(mean) < 0.5 else mean.darkened(0.25)
	var ring: Array = []
	for x in range(r.position.x, r.end.x):
		ring.append(Vector2i(x, r.position.y))
	for y in range(r.position.y + 1, r.end.y):
		ring.append(Vector2i(r.end.x - 1, y))
	for x in range(r.end.x - 2, r.position.x - 1, -1):
		ring.append(Vector2i(x, r.end.y - 1))
	for y in range(r.end.y - 2, r.position.y, -1):
		ring.append(Vector2i(r.position.x, y))
	var seam: Array = []
	for i in ring.size():
		var p: Vector2i = ring[i]
		if i % 3 != 2 and _body(img, p.x, p.y) and not seam.has(p):
			seam.append(p)
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			if _body(img, x, y) and not seam.has(Vector2i(x, y)):
				img.set_pixel(x, y, fill)
	_solid(img, seam, seam_tones, r)


static func _line(a: Vector2i, b: Vector2i) -> Array:
	var out: Array = []
	var n := maxi(absi(b.x - a.x), absi(b.y - a.y))
	for i in n + 1:
		var t := float(i) / maxf(1.0, float(n))
		out.append(Vector2i(roundi(lerpf(a.x, b.x, t)), roundi(lerpf(a.y, b.y, t))))
	return out


## Weighted pixel list grown to MIN_PX from the body pixels of r nearest its first pixel (a thin body that
## clips a shape still shows MIN_PX pixels).
static func _at_least(img: Image, pts: Array, r: Rect2i, s: int) -> Array:
	if pts.size() >= MIN_PX:
		return pts
	var plain: Array = []
	for row in pts:
		plain.append(row[0])
	var out := pts.duplicate()
	for p in _at_least_px(img, plain, r, s).slice(plain.size()):
		out.append([p, 1.0])
	return out


static func _at_least_px(img: Image, pts: Array, r: Rect2i, s: int) -> Array:
	if pts.size() >= MIN_PX:
		return pts
	var from := Vector2(pts[0]) if not pts.is_empty() else Vector2(r.position) + Vector2(r.size) / 2.0
	var cands: Array = []
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			if _body(img, x, y) and not pts.has(Vector2i(x, y)):
				cands.append([Vector2(x, y).distance_to(from) + _h(s, x, y, 9) * 0.1, Vector2i(x, y)])
	cands.sort()
	var out := pts.duplicate()
	for c in cands:
		if out.size() >= MIN_PX:
			break
		out.append(c[1])
	return out


static func _dots(img: Image, r: Rect2i, mark_seed: int, layout_seed: int) -> void:
	var col := CardTheme.color(&"ink_soft")
	for i in 5:
		var u := Rng.draw(layout_seed, DOMAIN, [800 + i])
		var v := Rng.draw(layout_seed, DOMAIN, [900 + i + mark_seed % 50])
		var x := r.position.x + int(u * float(maxi(r.size.x, 1)))
		var y := r.position.y + int(v * float(maxi(r.size.y, 1)))
		if x >= 0 and y >= 0 and x < IMG and y < IMG:
			img.set_pixel(x, y, col)


# ---------------- legend ----------------

## The swatch every legend tile is drawn on (DESIGN 4.3: drawn by the book itself): 12x12 of the book's
## ground (ground_of: the colour the item's tampering colours are chosen against too), with the book's own
## outline colour along row 2 and clear rows above, so a look that sits on the edge (chip, base_metal) has
## an edge there and every other look plain body.
static func swatch(book: Image) -> Image:
	var rims := {}
	for y in book.get_height():
		for x in book.get_width():
			if _rim(book, x, y):
				var c := book.get_pixel(x, y)
				var key := c.to_rgba32()
				if not rims.has(key):
					rims[key] = [0, c]
				rims[key][0] += 1
	var body := ground_of(book)
	var rim := _commonest(rims, CardTheme.color(&"ink"))
	var img := Image.create(TILE, TILE, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	for y in range(2, TILE):
		for x in TILE:
			img.set_pixel(x, y, rim if y == 2 else body)
	return img


static func _commonest(bag: Dictionary, none: Color) -> Color:
	var best := -1
	var best_key := 0
	var out := none
	for key in bag.keys():
		var n := int(bag[key][0])
		if n > best or (n == best and int(key) < best_key):
			best = n
			best_key = int(key)
			out = bag[key][1]
	out.a = 1.0
	return out


## Where a look is drawn on its tile: over the outline for edge looks, on plain body for the rest.
static func tile_rect(look: String) -> Rect2i:
	return Rect2i(3, 1, 6, 5) if EDGE_LOOKS.has(canon(look)) else Rect2i(3, 4, 6, 6)


static func _tile_seed(layout_seed: int, index: int) -> int:
	return int(Rng.draw(layout_seed, DOMAIN, [5000 + index]) * 2147483647.0)


## One legend tile: the swatch with look painted on it (look "" gives the bare swatch). Seeds come from the
## layout seed, never from this item's marks.
static func legend_tile(sw: Image, look: String, layout_seed: int, index: int) -> Image:
	var tile := sw.duplicate() as Image
	if look != "":
		paint_look(tile, look, is_wear_look(look), _tile_seed(layout_seed, index), tile_rect(look))
	return tile


## Looks named in params.legend for one row ("wear" or "differs"); only names this painter knows, each once
## (an old name counts as the look it is drawn as).
static func legend_looks(legend, row: String) -> Array:
	var out: Array = []
	if typeof(legend) != TYPE_DICTIONARY:
		return out
	var raw = (legend as Dictionary).get(row, [])
	if typeof(raw) != TYPE_ARRAY:
		return out
	for look in raw:
		var name := canon(str(look))
		if name in KNOWN_LOOKS and not out.has(name):
			out.append(name)
	return out
