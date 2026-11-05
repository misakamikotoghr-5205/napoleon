# C15 fragments, acceptance fix2 (blind player-eye test 10-25): the tells are there to be seen, only where the
# rules say to look, and never as a whole-piece patch. Over all twelve fragments item pictures and the drawn
# sheets, several piece counts and seeds:
#  1 other paper changes nothing but its cross-seam strokes: every pixel that differs from the same piece painted
#    as the sheet's own paper lies on one of its strokes (with the room its jog takes); it keeps MIN_TELLS
#    strokes or more, each changing MIN_PX pixels or more, its half 1-2 px off and visibly browner;
#  2 every stroke lies where the sheet is light enough for ink to show (no stroke on a black frame), every piece
#    keeps MIN_TELLS strokes, and where the strokes go does not depend on which piece is other paper;
#  3 the stain is mirrored across its seam, so where it crosses a stroke it fades both halves alike (a stroke
#    on two sound pieces reads the same at the same distance either side of the seam);
#  4 the riding seal: a sound seal is one mirrored pattern (dark rim, carved frame, jing grid), so its halves meet; a
#    seal stamped 2 px off steps at the rim on both sides and changes SEAL_MIN_PX pixels or more;
#  5 against the light every piece has the same grain (spacing, amount); only other paper's phase differs, in
#    both directions, so its lines stop at every one of its seams and nowhere else;
#  6 the glass samples screen-pixel centres (no soft edges);
#  7 the rule lines are on the table, from CardText, the same for a sound and a forged sheet (the light line
#    only with the light), under the pieces and clear of the board; the lens and light buttons have tooltips.
# Acceptance r2 (blind re-check: seals 3-6 px off read at a glance; two odd pieces side by side with one shift
# joined their strokes with no jog):
#  8 painted pixels: every stroke on a seam that touches other paper has its two halves 1 to ODD_ROOM px apart
#    (two odd pieces side by side included), every stroke between two sound pieces meets exactly, and each half
#    is in its own piece's ink (brown on other paper);
#  9 the real engine and data: a forged seal is off by exactly the cut (2 px, needs the glass) or not at all, never
#    more; a forgery with an aligned seal has other paper; most forgeries carry other paper.
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const H = preload("res://scripts/tests/cards/C15/harness.gd")
const Layout = preload("res://scripts/cards/minigames/fragments/frag_layout.gd")
const Paint = preload("res://scripts/cards/minigames/fragments/frag_piece.gd")
const LensSc = preload("res://scripts/cards/minigames/fragments/frag_lens.gd")
const E = preload("res://scripts/cards/economy/economy_support.gd")
const ARTS := ["item.art.calligraphy", "item.art.flowers", "item.art.landscape", "item.art.woodcut",
	"item.documents.field", "item.documents.house", "item.documents.letter", "item.documents.receipt",
	"item.papers.iou", "item.papers.shop_slip", "item.papers.tax_slip", "item.papers.waybill",
	"", "pawn_ticket", "letter"]
const MIN_PX := 12          # pixels one odd stroke half changes, at least
const SEAL_MIN_PX := 60     # pixels a seal stamped 2 px off changes, at least
const BROWN_GAP := 0.1      # odd ink differs from ink by this much in some channel, at least

var _fails: Dictionary = {}


func _initialize() -> void:
	var t := T.new(self, "C15_fragments_eye")
	t.run_async(_body.bind(t))


func _body(t) -> void:
	_sweep(t)
	_seal(t)
	_lens(t)
	_jogs(t)
	_engine_seal(t)
	await _rules(t)


## Records a failed property once per kind (with a count and the first case), so a sweep stays readable.
func _check(cond: bool, kind: String, where: String) -> void:
	if cond:
		return
	if not _fails.has(kind):
		_fails[kind] = [0, where]
	_fails[kind][0] += 1


func _art(art: String) -> Image:
	if not art.begins_with("item."):
		return null
	var tex := CardArt.texture(art)
	return tex.get_image() if tex != null else null


func _params(art: String, pieces: int, sd: int, odd: Array, stain: int) -> Dictionary:
	var doc := "scroll"
	if art in ["pawn_ticket", "letter"]:
		doc = art
	return {"kind": "fragments", "seed": 3001 + sd * 7919 + pieces * 31, "pieces": pieces, "doc": doc,
		"art": art if art.begins_with("item.") else "", "ink_mismatch": odd, "seal_offset_px": 0,
		"stain": stain, "dangzi_marks": 2 if doc == "pawn_ticket" else 0, "missing_piece": -1, "rotate": false}


func _sweep(t) -> void:
	var cases := 0
	var odd_seen := 0
	var stain_seen := 0
	for art in ARTS:
		var img := _art(art)
		if art.begins_with("item."):
			t.ok(img != null, art + " picture loads")
		for pieces in [3, 4, 5, 6, 8]:
			var base: Vector2i = img.get_size() if img != null else (Layout.SHEET if pieces <= 6 else Layout.SHEET_MANY)
			for sd in range(5):
				var probe := Layout.build(_params(art, pieces, sd, [], -1), base)
				var n := int(probe["n"])
				var odd_p := posmod(sd * 3 + pieces, n)
				var stain_p := posmod(odd_p + 1 + sd, n)
				if stain_p == odd_p:
					stain_p = -1
				var params := _params(art, pieces, sd, [odd_p], stain_p)
				var tag := "%s n%d s%d" % [art, pieces, sd]
				var L := Layout.build(params, base)
				var rows: Array = Paint.paint(L, params, img)
				var doc := Paint.doc_image(L, params, img)
				cases += 1
				_strokes_light(L, doc, tag)
				_same_places(L, params, img, base, tag)
				if not (L["odd"] as Array).is_empty():
					odd_seen += 1
					_odd_only_strokes(L, rows, doc, tag)
				if not (L["stain"] as Dictionary).is_empty():
					stain_seen += 1
					_stain_mirrored(L, rows, tag)
				_grain(L, rows, tag)
	t.ok(cases >= 200, "sweep ran " + str(cases) + " sheets")
	t.ok(odd_seen >= 200, "sweep had other paper on " + str(odd_seen) + " sheets")
	t.ok(stain_seen >= 100, "sweep had a stain on " + str(stain_seen) + " sheets")
	var brown := CardTheme.mix(&"ink", &"ink_soft", Paint.ODD_INK)
	var ink := CardTheme.color(&"ink")
	var gap := maxf(absf(brown.r - ink.r), maxf(absf(brown.g - ink.g), absf(brown.b - ink.b)))
	t.ok(gap >= BROWN_GAP, "other paper's ink visibly browner: " + str(gap))
	for kind in ["strokes light", "tells per piece", "places independent of the answer", "odd changes only strokes",
			"odd tells", "odd stroke pixels", "odd jog", "stain mirrored", "stain fades both halves",
			"grain lines", "grain amount", "grain phase"]:
		var f = _fails.get(kind, [0, ""])
		t.eq(int(f[0]), 0, kind + " (first failing case: " + str(f[1]) + ")")


## 2: every stroke over light sheet; every piece MIN_TELLS strokes on its seams.
func _strokes_light(L: Dictionary, doc: Image, tag: String) -> void:
	var floor_lum := CardTheme.color(&"ink").get_luminance() + Layout.INK_GAP
	for st in L["strokes"]:
		var row: Dictionary = L["seams"][int(st["seam"])]
		_check(Layout.stroke_light(row, int(st["t"]), int(st["th"]), int(st["la"]), int(st["lb"]), doc, floor_lum),
			"strokes light", tag + " seam " + str(st["seam"]) + " t " + str(st["t"]))
	for p in range(int(L["n"])):
		if p == int(L["missing"]):
			continue
		_check(_tells(L, p).size() >= Layout.MIN_TELLS, "tells per piece", tag + " piece " + str(p))


## 2: the strokes sit in the same places whichever piece is other paper (and with none).
func _same_places(L: Dictionary, params: Dictionary, img: Image, base: Vector2i, tag: String) -> void:
	var plain := params.duplicate(true)
	plain["ink_mismatch"] = []
	var L2 := Layout.build(plain, base)
	Paint.paint(L2, plain, img)
	_check(_places(L) == _places(L2), "places independent of the answer", tag)


func _places(L: Dictionary) -> Array:
	var out: Array = []
	for st in L["strokes"]:
		out.append([int(st["seam"]), int(st["t"]), int(st["la"]), int(st["lb"])])
	return out


func _tells(L: Dictionary, p: int) -> Array:
	var out: Array = []
	for st in L["strokes"]:
		var row: Dictionary = L["seams"][int(st["seam"])]
		if int(row["a"]) == p or int(row["b"]) == p:
			out.append(st)
	return out


## Stroke footprint in sheet px, widened by the room a jog takes along the seam.
func _footprint(L: Dictionary, st: Dictionary) -> Rect2i:
	var row: Dictionary = L["seams"][int(st["seam"])]
	var room := Layout.ODD_ROOM
	var along := int(st["t"]) - room
	var span := int(st["th"]) + 2 * room
	var across := int(st["la"]) + int(st["lb"])
	if bool(row["vertical"]):
		return Rect2i(int(row["x0"]) - int(st["la"]), int(row["y0"]) + along, across, span)
	return Rect2i(int(row["x0"]) + along, int(row["y0"]) - int(st["la"]), span, across)


## 1: the odd piece against itself painted as the sheet's own paper.
func _odd_only_strokes(L: Dictionary, rows: Array, doc: Image, tag: String) -> void:
	var p := int(L["odd"][0])
	var shift := int((L["odd_shift"] as Dictionary).get(p, 0))
	_check(shift in [-2, -1, 1, 2], "odd jog", tag + " shift " + str(shift))
	var plain := L.duplicate()
	plain["odd"] = []
	plain["odd_shift"] = {}
	var me: Array = Paint._mask(L, p)
	var ref: Image = Paint._piece(plain, p, doc, me[0], me[1], Paint._blob(L))
	var got: Image = rows[p]["img"]
	var bb: Rect2i = L["pieces"][p]["bbox"]
	var tells := _tells(L, p)
	_check(tells.size() >= Layout.MIN_TELLS, "odd tells", tag + " has " + str(tells.size()))
	var per: Array = []
	for i in range(tells.size()):
		per.append(0)
	var stray := 0
	for y in range(bb.size.y):
		for x in range(bb.size.x):
			if got.get_pixel(x, y) == ref.get_pixel(x, y):
				continue
			var at := bb.position + Vector2i(x, y)
			var hit := -1
			for i in range(tells.size()):
				if _footprint(L, tells[i]).has_point(at):
					hit = i
			if hit < 0:
				stray += 1
			else:
				per[hit] += 1
	_check(stray == 0, "odd changes only strokes", tag + " stray " + str(stray))
	for i in range(tells.size()):
		_check(int(per[i]) >= MIN_PX, "odd stroke pixels", tag + " stroke " + str(i) + " " + str(per[i]))


## 3: the stain blob mirrors across its seam line; on a sound seam a stroke under it reads the same either side.
func _stain_mirrored(L: Dictionary, rows: Array, tag: String) -> void:
	var st: Dictionary = L["stain"]
	var blob := Paint._blob(L)
	var mask: Image = blob["mask"]
	var src: Image = blob["src"]
	var vertical := bool(st["vertical"])
	var w := mask.get_width()
	var h := mask.get_height()
	var bad := 0
	for y in range(h):
		for x in range(w):
			var mx := w - 1 - x if vertical else x
			var my := y if vertical else h - 1 - y
			if mask.get_pixel(x, y) != mask.get_pixel(mx, my) or src.get_pixel(x, y) != src.get_pixel(mx, my):
				bad += 1
	_check(bad == 0, "stain mirrored", tag + " " + str(bad) + " px")
	var sheet := _composite(L, rows)
	var odd: Array = L["odd"]
	var rect: Rect2i = blob["rect"]
	for stroke in L["strokes"]:
		var row: Dictionary = L["seams"][int(stroke["seam"])]
		if odd.has(int(row["a"])) or odd.has(int(row["b"])) or not rect.intersects(_footprint(L, stroke)):
			continue
		var reach := mini(int(stroke["la"]), int(stroke["lb"]))
		for k in range(int(stroke["th"])):
			for i in range(Layout.JAG + 2, reach):
				var a: Color
				var b: Color
				if bool(row["vertical"]):
					var y2 := int(row["y0"]) + int(stroke["t"]) + k
					a = sheet.get_pixel(int(row["x0"]) - 1 - i, y2)
					b = sheet.get_pixel(int(row["x0"]) + i, y2)
				else:
					var x2 := int(row["x0"]) + int(stroke["t"]) + k
					a = sheet.get_pixel(x2, int(row["y0"]) - 1 - i)
					b = sheet.get_pixel(x2, int(row["y0"]) + i)
				_check(a == b, "stain fades both halves", tag + " seam " + str(stroke["seam"]) + " t " + str(stroke["t"]))


## The pieces in their slots, as one sheet (sheet px).
func _composite(L: Dictionary, rows: Array) -> Image:
	var out := Image.create_empty(int(L["w"]), int(L["h"]), false, Image.FORMAT_RGBA8)
	for p in range(int(L["n"])):
		if p == int(L["missing"]):
			continue
		var img: Image = rows[p]["img"]
		var bb: Rect2i = L["pieces"][p]["bbox"]
		out.blend_rect(img, Rect2i(Vector2i.ZERO, bb.size), bb.position)
	return out


## 5: the same grain on every piece; other paper's phase moved in both directions.
func _grain(L: Dictionary, rows: Array, tag: String) -> void:
	for p in range(int(L["n"])):
		if p == int(L["missing"]):
			continue
		var phase := Paint.fiber_phase(L, p)
		var odd := (L["odd"] as Array).has(p)
		_check((phase != Vector2i.ZERO) == odd, "grain phase", tag + " piece " + str(p))
		if odd:
			_check(posmod(phase.x, Paint.LAID) != 0 and posmod(phase.y, Paint.CHAIN) != 0, "grain phase",
				tag + " other paper phase " + str(phase))
		var fib: Image = (rows[p]["fiber"] as Texture2D).get_image()
		var img: Image = rows[p]["img"]
		var bb: Rect2i = L["pieces"][p]["bbox"]
		var lit := 0
		var area := 0
		var off := 0
		for y in range(bb.size.y):
			for x in range(bb.size.x):
				if img.get_pixel(x, y).a <= 0.0:
					continue
				area += 1
				if fib.get_pixel(x, y).a > 0.0:
					lit += 1
					var sx := posmod(bb.position.x + x - phase.x, Paint.LAID)
					var sy := posmod(bb.position.y + y - phase.y, Paint.CHAIN)
					if sx != 0 and sy != 0:
						off += 1
		_check(off == 0, "grain lines", tag + " piece " + str(p) + " off " + str(off))
		var share := float(lit) / float(maxi(1, area))
		var want := 1.0 / float(Paint.LAID) + 1.0 / float(Paint.CHAIN) - 1.0 / float(Paint.LAID * Paint.CHAIN)
		_check(absf(share - want) <= 0.04, "grain amount", tag + " piece " + str(p) + " share " + str(share))


## 4: the seal on its own: mirrored when sound, stepped at the rim and changed enough when 2 px off.
func _seal(t) -> void:
	var paper := CardTheme.color(&"paper")
	for vertical in [true, false]:
		for k in [3, 4, 5]:
			var row := {"vertical": vertical, "x0": 50, "y0": 0} if vertical else {"vertical": vertical, "x0": 0, "y0": 50}
			var whole := Image.create_empty(100, 100, false, Image.FORMAT_RGBA8)
			whole.fill(paper)
			Paint._seal(whole, row, 50, Layout.SEAL_PX, Vector2i.ZERO, k)
			var asym := 0
			for y in range(100):
				for x in range(100):
					if whole.get_pixel(x, y) != whole.get_pixel(99 - x, y) or whole.get_pixel(x, y) != whole.get_pixel(x, 99 - y):
						asym += 1
			var tag := "seal " + ("vertical" if vertical else "across") + " k" + str(k)
			t.eq(asym, 0, tag + ": a sound seal is one mirrored pattern")
			var rim := whole.get_pixel(28, 50)
			t.ok(rim.get_luminance() < CardTheme.color(&"seal").get_luminance() - 0.05, tag + ": rim darker than seal red")
			var moved := Image.create_empty(100, 100, false, Image.FORMAT_RGBA8)
			moved.fill(paper)
			Paint._seal(moved, row, 52, Layout.SEAL_PX, Vector2i.ZERO, k)
			var stamped := whole.duplicate() as Image
			var changed := 0
			for y in range(100):
				for x in range(100):
					var far_half := x >= 50 if vertical else y >= 50
					if far_half:
						stamped.set_pixel(x, y, moved.get_pixel(x, y))
					if stamped.get_pixel(x, y) != whole.get_pixel(x, y):
						changed += 1
			t.ok(changed >= SEAL_MIN_PX, tag + ": 2 px off changes " + str(changed) + " px")
			# the rim's top (or left) edge: on the near half at 28, on the far half at 30
			var near_px := stamped.get_pixel(40, 28) if vertical else stamped.get_pixel(28, 40)
			var far_px := stamped.get_pixel(60, 28) if vertical else stamped.get_pixel(28, 60)
			t.ok(near_px == rim and far_px == paper, tag + ": the rim steps at the seam")


## 8: on the painted sheet (no stain), where each half of every stroke lies along its seam, read just past the
## tear on either side (JAG + 2 px from the seam line, inside the light junction every stroke sits on).
func _jogs(t) -> void:
	var seen := {"both": 0, "one": 0, "none": 0}
	var bad := {"both": 0, "one": 0, "none": 0, "colour": 0, "run": 0}
	var first := {}
	var brown := _stored(CardTheme.mix(&"ink", &"ink_soft", Paint.ODD_INK))
	var ink := _stored(CardTheme.color(&"ink"))
	for art in ARTS:
		var img := _art(art)
		for pieces in [3, 4, 5, 6]:
			var base: Vector2i = img.get_size() if img != null else Layout.SHEET
			for sd in range(4):
				var probe := Layout.build(_params(art, pieces, sd, [], -1), base)
				var seams: Array = probe["seams"]
				if seams.is_empty():
					continue
				var pair: Dictionary = seams[posmod(sd * 5 + pieces, seams.size())]
				for odd in [[int(pair["a"]), int(pair["b"])], [int(pair["a"])]]:
					var params := _params(art, pieces, sd, odd, -1)
					var L := Layout.build(params, base)
					var rows: Array = Paint.paint(L, params, img)
					var sheet := _composite(L, rows)
					var tag := "%s n%d s%d odd %s" % [art, pieces, sd, str(odd)]
					for st in L["strokes"]:
						var row: Dictionary = L["seams"][int(st["seam"])]
						var oa: bool = odd.has(int(row["a"]))
						var ob: bool = odd.has(int(row["b"]))
						var kind := "both" if oa and ob else ("one" if oa or ob else "none")
						seen[kind] += 1
						var h := _halves(L, sheet, st, brown, ink)
						var where := tag + " seam " + str(st["seam"]) + " t " + str(st["t"]) + " " + str(h)
						if h.size() != 2 or int(h[0][1]) != int(st["th"]) or int(h[1][1]) != int(st["th"]):
							bad["run"] += 1
							first["run"] = first.get("run", where)
							continue
						var jog := absi(int(h[0][0]) - int(h[1][0]))
						var fine := jog == 0 if kind == "none" else (jog >= 1 and jog <= Layout.ODD_ROOM)
						if not fine:
							bad[kind] += 1
							first[kind] = first.get(kind, where)
	t.ok(int(seen["both"]) >= 40 and int(seen["one"]) >= 200 and int(seen["none"]) >= 200,
		"jog sweep covered seams between two odd pieces, odd and sound, two sound: " + str(seen))
	t.eq(int(bad["run"]), 0, "every stroke half reads as one run of its piece's ink, th px wide (first: %s)" % str(first.get("run", "")))
	t.eq(int(bad["both"]), 0, "two odd pieces side by side: their strokes jog 1-%d px (first: %s)" % [Layout.ODD_ROOM, str(first.get("both", ""))])
	t.eq(int(bad["one"]), 0, "odd beside sound: the strokes jog 1-%d px (first: %s)" % [Layout.ODD_ROOM, str(first.get("one", ""))])
	t.eq(int(bad["none"]), 0, "two sound pieces: every stroke meets exactly (first: %s)" % str(first.get("none", "")))
	# The shift rule on its own: neighbours of other paper never share a shift, never more than ODD_ROOM apart.
	var wide := 0
	var same := 0
	for sd in range(200):
		for pieces in [3, 4, 5, 6, 8]:
			var probe2 := Layout.build(_params("", pieces, sd, [], -1), Layout.SHEET)
			for row2 in probe2["seams"]:
				var L2 := Layout.build(_params("", pieces, sd, [int(row2["a"]), int(row2["b"])], -1), Layout.SHEET)
				var sh: Dictionary = L2["odd_shift"]
				var d := absi(int(sh[int(row2["a"])]) - int(sh[int(row2["b"])]))
				same += int(d == 0)
				wide += int(d > Layout.ODD_ROOM)
				for p in sh:
					wide += int(not Layout.ODD_SHIFTS.has(int(sh[p])))
	t.eq([same, wide], [0, 0], "odd neighbours: no shared shift, none past ODD_ROOM, every shift one of ODD_SHIFTS")


## A colour as an RGBA8 image stores it (what the painter's fill_rect leaves on a piece).
func _stored(c: Color) -> Color:
	var one := Image.create_empty(1, 1, false, Image.FORMAT_RGBA8)
	one.fill(c)
	return one.get_pixel(0, 0)


## Both halves of a stroke: [[first along px, run length], ...] for the side of the lower and the higher seam
## coordinate, each in its owner's ink (brown on other paper); [] when a half is missing or the wrong colour.
func _halves(L: Dictionary, sheet: Image, st: Dictionary, brown: Color, ink: Color) -> Array:
	var row: Dictionary = L["seams"][int(st["seam"])]
	var vertical := bool(row["vertical"])
	var t0 := int(st["t"])
	var out: Array = []
	for across in [-(Layout.JAG + 2), Layout.JAG + 2]:
		var at := -1
		var run := 0
		for along in range(t0 - Layout.ODD_ROOM, t0 + int(st["th"]) + Layout.ODD_ROOM):
			var x := int(row["x0"]) + int(across) if vertical else int(row["x0"]) + along
			var y := int(row["y0"]) + along if vertical else int(row["y0"]) + int(across)
			var want := brown if (L["odd"] as Array).has(Layout.owner_at(L, x, y)) else ink
			if sheet.get_pixel(x, y) == want:
				if at < 0:
					at = along
				run += 1
		if at < 0:
			return []
		out.append([at, run])
	return out


## 9: the real engine over forced forgeries of every fragments template, and the data behind it.
func _engine_seal(t) -> void:
	var eng := CardEngine.new()
	var boot: Dictionary = eng.new_game({"seed": 11, "only_examples": false, "save_dir": t.user_dir()})
	t.ok(bool(boot.get("ok", false)), "engine for the seal check")
	if not bool(boot.get("ok", false)):
		return
	var c: CardCtx = eng.ctx
	var cut := int(CardDB.read_json("res://data/cards/rules/economy.json").get("appraise", {}).get("fragments", {}).get("seal_off_px", 2))
	t.eq(cut, 2, "the seal cut is 2 px")
	var templates: Array = []
	for id in c.db.ids_of(&"item"):
		var spec: Dictionary = c.db.def(id).get("fragments", {})
		if spec.is_empty():
			continue
		templates.append(str(c.db.def(id)["template"]))
		var bad_range: Array = spec.get("seal_offset_px_bad", [])
		t.ok(bad_range.size() == 2 and int(bad_range[1]) <= cut, "%s: a forged seal is off by %d px at most (%s)" % [id, cut, str(bad_range)])
		t.eq(spec.get("seal_offset_px_good", []), [0, 0], id + ": a sound seal is not off")
	t.ok(templates.size() >= 12, "fragments templates: " + str(templates.size()))
	var offs := {}
	var with_odd := 0
	var n := 0
	var bare := 0
	for tpl in templates:
		for k in range(30):
			var r := CardItems.generate(c, ["c", 1, "frag_r2", tpl, k], tpl)
			if not bool(r.get("ok", false)):
				continue
			var id2 := str(r["item"])
			E.meta(c, id2)["fake"] = true
			var b := CardAppraisal._build(c, id2, &"fragments", {})
			var off := int(b["params"]["seal_offset_px"])
			var odd: Array = b["params"]["ink_mismatch"]
			offs[off] = int(offs.get(off, 0)) + 1
			n += 1
			with_odd += int(not odd.is_empty())
			bare += int(off < cut and odd.is_empty())
	var keys: Array = offs.keys()
	keys.sort()
	t.ok(n >= 300, "forgeries built: " + str(n))
	t.eq(keys, [0, cut], "a forged seal is off by the cut or not at all: " + str(offs))
	t.eq(bare, 0, "a forgery with its seal aligned has other paper")
	t.ok(with_odd * 4 >= n * 3, "most forgeries carry other paper (the glass at the seams): %d of %d" % [with_odd, n])
	t.ok(int(offs.get(cut, 0)) * 5 >= n, "some forgeries carry the offset seal: %d of %d" % [int(offs.get(cut, 0)), n])


## 6
func _lens(t) -> void:
	t.ok(LensSc.SHADER.contains("SCREEN_PIXEL_SIZE") and LensSc.SHADER.contains("floor(suv / SCREEN_PIXEL_SIZE)"),
		"the glass samples screen-pixel centres")


## 7
func _rules(t) -> void:
	var forged := H.params("ticket_fake.json")
	var sound := forged.duplicate(true)
	sound["ink_mismatch"] = []
	sound["seal_offset_px"] = 0
	sound["stain"] = -1
	var dark := forged.duplicate(true)
	dark["backlight"] = false
	var lines: Dictionary = {}
	for pair in [["forged", forged], ["sound", sound], ["dark", dark]]:
		var ctx := H.open_game(self, H.FRAG, pair[1])
		var g = ctx["game"]
		await t.frames(1)
		lines[pair[0]] = g.rule_lines()
		t.eq(t.all_text_from_cardtext(g), PackedStringArray(), str(pair[0]) + ": all text from CardText")
		var panel: Control = g.get("_panel")
		var rules: Control = panel.get_node("Rules")
		var board: Control = g.get("_board")
		t.ok(rules.get_index() < board.get_index(), str(pair[0]) + ": rules drawn under the pieces")
		var r := Rect2(rules.position, rules.size)
		t.ok(Rect2(Layout.TRAY).encloses(r), str(pair[0]) + ": rules on the table " + str(r))
		t.ok(not r.intersects(Rect2(Layout.BOARD)), str(pair[0]) + ": rules clear of the board")
		var lens_btn: Button = g.tool_button("lens")
		t.eq(lens_btn.tooltip_text, CardText.ui("c15.tool.lens.tip"), str(pair[0]) + ": lens tooltip")
		if bool(pair[1]["backlight"]):
			var light_btn: Button = g.tool_button("light")
			t.eq(light_btn.tooltip_text, CardText.ui("c15.tool.backlight.tip"), str(pair[0]) + ": light tooltip")
		H.close(ctx)
		await t.frames(1)
	var want := PackedStringArray([CardText.ui("c15.frag.rule.seam"), CardText.ui("c15.frag.rule.stain"),
		CardText.ui("c15.frag.rule.seal"), CardText.ui("c15.frag.rule.light")])
	t.eq(lines["forged"], want, "rule lines on a forged sheet")
	t.eq(lines["sound"], lines["forged"], "a sound sheet shows the same rule lines")
	t.eq(lines["dark"], want.slice(0, 3), "no light line without the light")
	for s in want:
		t.ok(s.strip_edges() != "", "rule text present: " + s)
