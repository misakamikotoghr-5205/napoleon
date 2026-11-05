# Fragments layout as plain data: the cell grid and which cells make each piece, the torn seams between
# pieces (one shared tear profile per grid line), the ink strokes across each seam, the riding seal, the
# water stain, the board slots and where the pieces lie on the table. Built only from params and
# JevRng.draw(params.seed, "c.mg.fragments.layout", [i]); no nodes, no drawing. The painter then settles the
# strokes onto light parts of the sheet (settle_strokes, acceptance fix2), so every stroke can be seen.
# Owner C15.
# Index ranges (DESIGN P8): [0, 999] layout, [5000, 5999] decoration; autoplay uses [9000, 9999] elsewhere.
extends RefCounted

const DOMAIN := "c.mg.fragments.layout"
const STEP := 6          # tear profile step along a grid line (board px)
const JAG := 3           # tear offset range, plus or minus board px
const PAD := 4           # piece image margin past its cells on torn sides
const BOARD := Rect2i(40, 112, 480, 336)    # panel coords: where the paper is put back together
const TRAY := Rect2i(560, 112, 486, 420)    # panel coords: the table the pieces lie on (down to the tool row)
const MAX_AREA := 116000                    # doc px area that still leaves the tray room
const SHEET := Vector2i(128, 96)            # drawn sheets in their own pixels (x3 on the board)
const SHEET_MANY := Vector2i(112, 84)       # the same for 7 pieces or more, so the table holds them
const SEAL_PX := 44                         # riding seal, board px
const STROKE_PX := 3                        # cross-seam brush strokes, board px
const STROKE_GAP := 10                      # strokes on one seam stay this far apart (board px along the seam)
const INK_GAP := 0.3                        # a stroke goes where the sheet is at least this much lighter than ink
const LIGHT_SHARE := 0.85                   # ... over this share of the stroke (all of it near the seam)
const JUNCTION := 5                         # board px either side of the seam that must all be light
const ODD_ROOM := 2                         # how far other paper may move its half of a stroke (the check covers it)
const ODD_SHIFTS := [-2, -1, 1, 2]          # the shifts other paper may take (never 0, never past ODD_ROOM)
const MIN_TELLS := 2                        # strokes each piece keeps on its seams where the sheet allows
const STAIN_REACH := 1.2                    # the stain's edge reaches at most this many times its radius
const STAIN_MIN_R := 6                      # the smallest stain radius (board px)


static func draw(seed_v: int, i: int) -> float:
	return JevRng.draw(seed_v, DOMAIN, [i])


## base: the document picture size in its own pixels (64x48 for sheets, 64x64 for item art).
static func build(params: Dictionary, base_in: Vector2i) -> Dictionary:
	var seed_v := int(params.get("seed", 0))
	var n := clampi(int(params.get("pieces", 0)), 0, 12)
	var base := base_in
	if base.x < 8 or base.y < 8:
		base = Vector2i(64, 48)
	var grid := grid_for(n)
	var cols := grid.x
	var rows := grid.y
	var k := scale_for(base)
	var w := base.x * k
	var h := base.y * k
	var colx: Array = []
	for j in range(cols + 1):
		colx.append(int(round(float(w * j) / float(cols))))
	var rowy: Array = []
	for i in range(rows + 1):
		rowy.append(int(round(float(h * i) / float(rows))))
	var origin := Vector2i(BOARD.position.x + int(float(BOARD.size.x - w) / 2.0),
		BOARD.position.y + int(float(BOARD.size.y - h) / 2.0))
	var cell := _cells(seed_v, n, cols, rows)
	var count := 0
	for r in range(rows):
		for c in range(cols):
			count = maxi(count, int(cell[r][c]) + 1)
	var missing := int(params.get("missing_piece", -1))
	if missing < 0 or missing >= count or count <= 1:
		missing = -1
	var pieces: Array = []
	for p in range(count):
		pieces.append(_piece(p, cell, cols, rows, colx, rowy, w, h))
	var out := {
		"seed": seed_v, "n": count, "base": base, "k": k, "w": w, "h": h, "cols": cols, "rows": rows,
		"colx": colx, "rowy": rowy, "cell": cell, "origin": origin, "pieces": pieces, "missing": missing,
		"vjit": _jitter(seed_v, cols, h, 5000), "hjit": _jitter(seed_v, rows, w, 5400),
	}
	out["seams"] = _seams(out)
	out["odd"] = _odd(params, count, missing)
	out["odd_shift"] = _odd_shift(seed_v, out["odd"], out["seams"])
	out["seal"] = _seal(seed_v, out, clampi(int(params.get("seal_offset_px", 0)), 0, 12))
	out["strokes"] = _strokes(seed_v, out)
	out["stain"] = _stain(seed_v, out, params)
	out["mark"] = _mark_piece(out)
	var slots: Array = []
	for p in range(count):
		var bb: Rect2i = pieces[p]["bbox"]
		slots.append(origin + bb.position)
	out["slots"] = slots
	_scatter(seed_v, out, _rotate_flag(params))
	return out


static func grid_for(n: int) -> Vector2i:
	if n <= 1:
		return Vector2i(1, 1)
	if n == 2:
		return Vector2i(2, 1)
	if n <= 4:
		return Vector2i(2, 2)
	if n <= 6:
		return Vector2i(3, 2)
	if n <= 9:
		return Vector2i(3, 3)
	return Vector2i(4, 3)


## Largest whole-number scale that fits the board and leaves the table room for the pieces.
static func scale_for(base: Vector2i) -> int:
	var k := 1
	for s in range(1, 9):
		var w := base.x * s
		var h := base.y * s
		if w > BOARD.size.x or h > BOARD.size.y or w * h > MAX_AREA:
			break
		k = s
	return k


## Which piece owns pixel (x, y) of the document (board px from the doc's top-left).
static func owner_at(L: Dictionary, x: int, y: int) -> int:
	var colx: Array = L["colx"]
	var rowy: Array = L["rowy"]
	var cols: int = L["cols"]
	var rows: int = L["rows"]
	var vj: Array = L["vjit"]
	var hj: Array = L["hjit"]
	var col := 0
	for j in range(1, cols):
		var prof: PackedInt32Array = vj[j]
		var at := int(colx[j]) + prof[clampi(int(float(y) / float(STEP)), 0, prof.size() - 1)]
		if x >= at:
			col = j
	var row := 0
	for i in range(1, rows):
		var prof2: PackedInt32Array = hj[i]
		var at2 := int(rowy[i]) + prof2[clampi(int(float(x) / float(STEP)), 0, prof2.size() - 1)]
		if y >= at2:
			row = i
	return int(L["cell"][row][col])


## Seam index for the pair (a, b), or -1.
static func seam_of(L: Dictionary, a: int, b: int) -> int:
	var lo := mini(a, b)
	var hi := maxi(a, b)
	var seams: Array = L["seams"]
	for s in range(seams.size()):
		if int(seams[s]["a"]) == lo and int(seams[s]["b"]) == hi:
			return s
	return -1


## Where a seam's cross goes (panel coords): its middle, or beside the seal when the seal sits there.
static func cross_point(L: Dictionary, s: int) -> Vector2:
	var ends: Array = seam_ends(L, s)
	var a: Vector2 = ends[0]
	var b: Vector2 = ends[1]
	var mid := (a + b) * 0.5
	var seal: Dictionary = L["seal"]
	if seal.is_empty() or int(seal["seam"]) != s:
		return mid
	var length := a.distance_to(b)
	var t := float(int(seal["t"]))
	var keep := float(int(seal["size"])) * 0.5 + 14.0
	if absf(length * 0.5 - t) >= keep:
		return mid
	var side := t + keep if t + keep < length - 8.0 else t - keep
	return a.lerp(b, clampf(side / maxf(length, 1.0), 0.0, 1.0))


## Seam endpoints in panel coords.
static func seam_ends(L: Dictionary, s: int) -> Array:
	var row: Dictionary = L["seams"][s]
	var o: Vector2i = L["origin"]
	return [Vector2(o + Vector2i(int(row["x0"]), int(row["y0"]))), Vector2(o + Vector2i(int(row["x1"]), int(row["y1"])))]


# ---------------- grid ----------------
## cell[r][c] = piece index. Extra grid cells (cols * rows - n) merge with their right neighbour, one per
## row from the bottom, so a torn sheet has pieces of two sizes instead of empty cells.
static func _cells(seed_v: int, n: int, cols: int, rows: int) -> Array:
	var extra := maxi(0, cols * rows - maxi(n, 1))
	var merged: Array = []
	for r in range(rows):
		merged.append(-1)
	var r2 := rows - 1
	while extra > 0 and r2 >= 0 and cols > 1:
		merged[r2] = mini(cols - 2, int(draw(seed_v, r2) * float(cols - 1)))
		extra -= 1
		r2 -= 1
	var cell: Array = []
	var next := 0
	for r in range(rows):
		var line: Array = []
		for c in range(cols):
			if int(merged[r]) >= 0 and c == int(merged[r]) + 1:
				line.append(line[c - 1])
			else:
				line.append(next)
				next += 1
		cell.append(line)
	return cell


static func _piece(p: int, cell: Array, cols: int, rows: int, colx: Array, rowy: Array, w: int, h: int) -> Dictionary:
	var c0 := cols
	var c1 := -1
	var r0 := rows
	var r1 := -1
	var cells: Array = []
	for r in range(rows):
		for c in range(cols):
			if int(cell[r][c]) == p:
				cells.append(Vector2i(c, r))
				c0 = mini(c0, c)
				c1 = maxi(c1, c)
				r0 = mini(r0, r)
				r1 = maxi(r1, r)
	var x0 := int(colx[c0])
	var x1 := int(colx[c1 + 1])
	var y0 := int(rowy[r0])
	var y1 := int(rowy[r1 + 1])
	var rect := Rect2i(x0, y0, x1 - x0, y1 - y0)
	var bx0 := x0 - PAD if x0 > 0 else 0
	var by0 := y0 - PAD if y0 > 0 else 0
	var bx1 := x1 + PAD if x1 < w else w
	var by1 := y1 + PAD if y1 < h else h
	return {"cells": cells, "rect": rect, "bbox": Rect2i(bx0, by0, bx1 - bx0, by1 - by0)}


## One tear profile per inner grid line: a short random walk in [-JAG, JAG], one value per STEP px.
static func _jitter(seed_v: int, lines: int, length: int, at: int) -> Array:
	var out: Array = [PackedInt32Array()]
	var steps := int(float(length) / float(STEP)) + 2
	for j in range(1, lines):
		var prof := PackedInt32Array()
		var v := int(draw(seed_v, at + j * 100) * float(JAG * 2 + 1)) - JAG
		for s in range(steps):
			if s > 0:
				var u := draw(seed_v, at + j * 100 + s)
				v = clampi(v + (1 if u > 0.66 else (-1 if u < 0.33 else 0)), -JAG, JAG)
			prof.append(v)
		out.append(prof)
	return out


static func _seams(L: Dictionary) -> Array:
	var cell: Array = L["cell"]
	var cols: int = L["cols"]
	var rows: int = L["rows"]
	var colx: Array = L["colx"]
	var rowy: Array = L["rowy"]
	var missing: int = L["missing"]
	var found: Dictionary = {}
	for j in range(1, cols):
		for r in range(rows):
			_add_seam(found, int(cell[r][j - 1]), int(cell[r][j]), missing, true,
				int(colx[j]), int(rowy[r]), int(colx[j]), int(rowy[r + 1]))
	for i in range(1, rows):
		for c in range(cols):
			_add_seam(found, int(cell[i - 1][c]), int(cell[i][c]), missing, false,
				int(colx[c]), int(rowy[i]), int(colx[c + 1]), int(rowy[i]))
	var keys: Array = found.keys()
	keys.sort()
	var out: Array = []
	for key in keys:
		out.append(found[key])
	return out


static func _add_seam(found: Dictionary, p: int, q: int, missing: int, vertical: bool,
		x0: int, y0: int, x1: int, y1: int) -> void:
	if p == q or p == missing or q == missing:
		return
	var a := mini(p, q)
	var b := maxi(p, q)
	var key := a * 100 + b
	if not found.has(key):
		found[key] = {"a": a, "b": b, "vertical": vertical, "x0": x0, "y0": y0, "x1": x1, "y1": y1}
		return
	var row: Dictionary = found[key]
	row["x0"] = mini(int(row["x0"]), x0)
	row["y0"] = mini(int(row["y0"]), y0)
	row["x1"] = maxi(int(row["x1"]), x1)
	row["y1"] = maxi(int(row["y1"]), y1)


static func seam_len(row: Dictionary) -> int:
	return maxi(int(row["x1"]) - int(row["x0"]), int(row["y1"]) - int(row["y0"]))


# ---------------- evidence and decoys ----------------
static func _odd(params: Dictionary, n: int, missing: int) -> Array:
	var out: Array = []
	var raw = params.get("ink_mismatch", [])
	if typeof(raw) != TYPE_ARRAY:
		return out
	for x in raw:
		var p := int(x)
		if p >= 0 and p < n and p != missing and not out.has(p):
			out.append(p)
	out.sort()
	return out


## A piece of other paper: its half of every cross-seam stroke sits 1-2 px off along the seam. Two pieces of other
## paper side by side never share a shift (acceptance r2: the same shift joined their strokes with no jog, brown on
## both halves, which the seam rule does not describe): a later one takes a shift 1 to ODD_ROOM px from every
## odd neighbour's, so the strokes on their seam jog like those on any other seam of theirs, and no more.
static func _odd_shift(seed_v: int, odd: Array, seams: Array) -> Dictionary:
	var out: Dictionary = {}
	for p in odd:
		var near: Array = []
		for row in seams:
			var q := int(row["b"]) if int(row["a"]) == int(p) else (int(row["a"]) if int(row["b"]) == int(p) else -1)
			if out.has(q):
				near.append(int(out[q]))
		var pick: Array = []
		for s in ODD_SHIFTS:
			var fits := true
			for v in near:
				var d := absi(int(s) - int(v))
				fits = fits and d >= 1 and d <= ODD_ROOM
			if fits:
				pick.append(int(s))
		if pick.is_empty():
			pick = ODD_SHIFTS.filter(func(s: int) -> bool: return not near.has(s))
		if pick.is_empty():
			pick = ODD_SHIFTS.duplicate()
		out[int(p)] = int(pick[mini(pick.size() - 1, int(draw(seed_v, 600 + int(p)) * float(pick.size())))])
	return out


## The riding seal sits across one seam; the half on `moved` slides `shift` px along the seam.
static func _seal(seed_v: int, L: Dictionary, shift: int) -> Dictionary:
	var size := SEAL_PX
	var seams: Array = L["seams"]
	var fit: Array = []
	for s in range(seams.size()):
		if seam_len(seams[s]) >= size + 24:
			fit.append(s)
	if fit.is_empty():
		return {}
	var s2 := int(fit[mini(fit.size() - 1, int(draw(seed_v, 10) * float(fit.size())))])
	var row: Dictionary = seams[s2]
	var span := seam_len(row) - size - 24
	var t := int(float(seam_len(row)) / 2.0 + float(span) * 0.5 * (draw(seed_v, 11) * 2.0 - 1.0) * 0.6)
	var moved := int(row["b"]) if draw(seed_v, 12) < 0.5 else int(row["a"])
	return {"seam": s2, "t": t, "size": size, "moved": moved, "shift": shift}


## Two to four brush strokes across every seam, kept clear of the seam ends and the seal.
static func _strokes(seed_v: int, L: Dictionary) -> Array:
	var out: Array = []
	var seams: Array = L["seams"]
	var seal: Dictionary = L["seal"]
	var thick := STROKE_PX
	for s in range(seams.size()):
		var length := seam_len(seams[s])
		var lo := 18
		var hi := length - 18
		if hi <= lo:
			continue
		var count := 2 + mini(2, int(draw(seed_v, 400 + s) * 3.0))
		for m in range(count):
			var u := draw(seed_v, 500 + s * 8 + m)
			var t := lo + int(float(hi - lo) * (float(m) + 0.2 + u * 0.6) / float(count))
			if not seal.is_empty() and int(seal["seam"]) == s and absi(t - int(seal["t"])) < int(float(seal["size"]) / 2.0) + 8:
				continue
			var la := 8 + int(draw(seed_v, 700 + s * 8 + m) * 8.0)
			var lb := 8 + int(draw(seed_v, 800 + s * 8 + m) * 8.0)
			# from / to: this stroke's share of the seam; settle_strokes keeps it inside, so strokes stay spread.
			out.append({"seam": s, "t": t, "la": la, "lb": lb, "th": thick,
				"from": lo + int(float(hi - lo) * float(m) / float(count)),
				"to": lo + int(float(hi - lo) * float(m + 1) / float(count))})
	return out


## Moves every cross-seam stroke along its seam to the nearest place where the sheet under it is light enough
## for ink to show (acceptance fix2: on dark parts of a picture a stroke, and its jog, was invisible). Checked
## over the whole stroke plus the room other paper may move its half (ODD_ROOM px each way): the few pixels
## either side of the seam must all be light, the rest mostly. A stroke stays inside its own share of the seam
## (from / to), STROKE_GAP px from the others and clear of the seal; one with no such place is left out.
## doc: the sheet at board scale. Same doc, same result (the layout stays a function of params and picture).
static func settle_strokes(L: Dictionary, doc: Image) -> void:
	var seams: Array = L["seams"]
	var seal: Dictionary = L["seal"]
	var floor_lum := CardTheme.color(&"ink").get_luminance() + INK_GAP
	var out: Array = []
	var taken: Dictionary = {}
	for st in L["strokes"]:
		var s := int(st["seam"])
		var row: Dictionary = seams[s]
		var length := seam_len(row)
		var th := int(st["th"])
		var lo := maxi(18, int(st.get("from", 18)))
		var hi := mini(length - 18 - th, int(st.get("to", length)) - th)
		var want := int(st["t"])
		var used: Array = taken.get(s, [])
		var found := -1
		for d in range(0, length):
			for t in ([want] if d == 0 else [want - d, want + d]):
				if t < lo or t > hi or _crowded(t, used, seal, s):
					continue
				if stroke_light(row, t, th, int(st["la"]), int(st["lb"]), doc, floor_lum):
					found = t
					break
			if found >= 0 or (want - d < lo and want + d > hi):
				break
		if found < 0:
			continue
		var kept: Dictionary = st.duplicate()
		kept["t"] = found
		out.append(kept)
		used.append(found)
		taken[s] = used
	_top_up(L, doc, out, taken, floor_lum)
	L["strokes"] = out


## Every piece keeps MIN_TELLS strokes on its seams where the sheet allows: a piece left short (its shares of
## the seams fell on dark parts of the picture) gets strokes at the light places nearest the middle of its
## seams, 2 x STROKE_GAP from the others. Lengths come from the place (no draws), so it stays deterministic.
static func _top_up(L: Dictionary, doc: Image, out: Array, taken: Dictionary, floor_lum: float) -> void:
	var seams: Array = L["seams"]
	var seal: Dictionary = L["seal"]
	for p in range(int(L["n"])):
		if p == int(L["missing"]):
			continue
		var have := 0
		for st in out:
			var r0: Dictionary = seams[int(st["seam"])]
			if int(r0["a"]) == p or int(r0["b"]) == p:
				have += 1
		for s in range(seams.size()):
			var row: Dictionary = seams[s]
			if have >= MIN_TELLS or (int(row["a"]) != p and int(row["b"]) != p):
				continue
			var length := seam_len(row)
			var lo := 18
			var hi := length - 18 - STROKE_PX
			var mid := int(float(lo + hi) / 2.0)
			var used: Array = taken.get(s, [])
			for d in range(0, length):
				if have >= MIN_TELLS or (mid - d < lo and mid + d > hi):
					break
				for t in ([mid] if d == 0 else [mid - d, mid + d]):
					if have >= MIN_TELLS or t < lo or t > hi:
						continue
					var far := true
					for u in used:
						if absi(t - int(u)) < 2 * STROKE_GAP:
							far = false
					if not far or _crowded(t, [], seal, s):
						continue
					var la := 9 + posmod(t, 5)
					var lb := 9 + posmod(t + s, 5)
					if stroke_light(row, t, STROKE_PX, la, lb, doc, floor_lum):
						out.append({"seam": s, "t": t, "la": la, "lb": lb, "th": STROKE_PX, "from": t, "to": t + STROKE_PX})
						used.append(t)
						taken[s] = used
						have += 1


static func _crowded(t: int, used: Array, seal: Dictionary, s: int) -> bool:
	for u in used:
		if absi(t - int(u)) < STROKE_GAP:
			return true
	return not seal.is_empty() and int(seal["seam"]) == s and absi(t - int(seal["t"])) < int(float(seal["size"]) / 2.0) + 8


## The sheet under a stroke at t (and ODD_ROOM px either way along the seam) is light enough for ink: every
## pixel within JUNCTION px of the seam line, and at least LIGHT_SHARE of the rest.
static func stroke_light(row: Dictionary, t: int, th: int, la: int, lb: int, doc: Image, floor_lum: float) -> bool:
	var vertical := bool(row["vertical"])
	var n := 0
	var lit := 0
	for along in range(t - ODD_ROOM, t + th + ODD_ROOM):
		for across in range(-la, lb):
			var x := int(row["x0"]) + across if vertical else int(row["x0"]) + along
			var y := int(row["y0"]) + along if vertical else int(row["y0"]) + across
			if x < 0 or y < 0 or x >= doc.get_width() or y >= doc.get_height():
				return false
			var ok := doc.get_pixel(x, y).get_luminance() >= floor_lum
			if absi(across) <= JUNCTION and not ok:
				return false
			n += 1
			lit += int(ok)
	return n > 0 and float(lit) >= float(n) * LIGHT_SHARE


## A water stain across one seam of the stain piece: both sides fade together (the decoy for other paper).
static func _stain(seed_v: int, L: Dictionary, params: Dictionary) -> Dictionary:
	var raw = params.get("stain", -1)
	if typeof(raw) == TYPE_ARRAY:
		raw = (raw as Array)[0] if not (raw as Array).is_empty() else -1
	var p := int(raw) if typeof(raw) in [TYPE_INT, TYPE_FLOAT] else -1
	if p < 0 or p >= int(L["n"]) or p == int(L["missing"]):
		return {}
	var seams: Array = L["seams"]
	var mine: Array = []
	var seal: Dictionary = L["seal"]
	for s in range(seams.size()):
		if int(seams[s]["a"]) == p or int(seams[s]["b"]) == p:
			if seal.is_empty() or int(seal["seam"]) != s:
				mine.append(s)
	if mine.is_empty():
		for s in range(seams.size()):
			if int(seams[s]["a"]) == p or int(seams[s]["b"]) == p:
				mine.append(s)
	if mine.is_empty():
		return {}
	var s2 := int(mine[mini(mine.size() - 1, int(draw(seed_v, 20) * float(mine.size())))])
	var row: Dictionary = seams[s2]
	var pr: Rect2i = L["pieces"][p]["rect"]
	var t := 0.3 + draw(seed_v, 21) * 0.4
	# Small enough to stay off the strokes of the seams that meet this one at its ends (they reach up to 16 px
	# into the sheet past the tear): the stain is mirrored across its own seam only. On a short seam it sits
	# at the middle, where there is the most room.
	var room := minf(t, 1.0 - t) * float(seam_len(row)) - 16.0 - float(JAG) - 2.0
	if room < float(STAIN_MIN_R) * STAIN_REACH:
		t = 0.5
		room = 0.5 * float(seam_len(row)) - 16.0 - float(JAG) - 2.0
	var r := mini(int(float(mini(pr.size.x, pr.size.y)) * 0.3), int(room / STAIN_REACH))
	# Centred on the seam line and mirrored across it (acceptance fix2): whatever it fades on one side of the
	# seam it fades the same on the other, so a stain never makes half a stroke look different.
	var cx := int(lerpf(float(row["x0"]), float(row["x1"]), t))
	var cy := int(lerpf(float(row["y0"]), float(row["y1"]), t))
	return {"piece": p, "seam": s2, "cx": cx, "cy": cy, "r": maxi(STAIN_MIN_R, r), "vertical": bool(row["vertical"]),
		"ph1": draw(seed_v, 23) * TAU, "ph2": draw(seed_v, 24) * TAU}


## The piece that carries the big "dang" character (the cell at the sheet's middle).
static func _mark_piece(L: Dictionary) -> int:
	var cols: int = L["cols"]
	var rows: int = L["rows"]
	var p := int(L["cell"][int(float(rows) / 2.0)][int(float(cols) / 2.0)])
	if p == int(L["missing"]):
		for q in range(int(L["n"])):
			if q != p:
				return q
	return p


static func _rotate_flag(params: Dictionary) -> bool:
	if not params.has("rotate"):
		return true
	return bool(params["rotate"])


## Pieces lie on the table, some turned when params.rotate allows: shelf by shelf, tallest first (seeded
## order among equals), with a little seeded jitter; a piece that would fall off the table lies over others.
static func _scatter(seed_v: int, L: Dictionary, turn: bool) -> void:
	var n: int = L["n"]
	var missing: int = L["missing"]
	var pieces: Array = L["pieces"]
	var ranks: Array = []
	var order: Array = []
	var rots: Array = []
	var pos: Array = []
	var dims: Array = []
	for p in range(n):
		ranks.append(draw(seed_v, 200 + p))
		if p != missing:
			order.append(p)
		var rot := 0
		if turn and p != missing:
			rot = mini(3, int(draw(seed_v, 100 + p) * 4.0))
		rots.append(rot)
		pos.append(Vector2i.ZERO)
		var bb: Rect2i = pieces[p]["bbox"]
		dims.append(Vector2i(bb.size.y, bb.size.x) if posmod(rot, 2) == 1 else bb.size)
	order.sort_custom(func(a, b): return float(ranks[a]) < float(ranks[b]) or (float(ranks[a]) == float(ranks[b]) and int(a) < int(b)))
	var pack: Array = order.duplicate()
	pack.sort_custom(func(a, b): return int(dims[a].y) > int(dims[b].y) or (int(dims[a].y) == int(dims[b].y) and order.find(a) < order.find(b)))
	var gap := 8
	var x := TRAY.position.x + gap
	var y := TRAY.position.y + gap
	var row_h := 0
	for p2 in pack:
		var p := int(p2)
		var d: Vector2i = dims[p]
		if x + d.x > TRAY.end.x - 4 and x > TRAY.position.x + gap:
			x = TRAY.position.x + gap
			y += row_h + gap
			row_h = 0
		var jx := int((draw(seed_v, 300 + p) - 0.5) * 8.0)
		var jy := int((draw(seed_v, 320 + p) - 0.5) * 8.0)
		var px := clampi(x + jx, TRAY.position.x + 2, maxi(TRAY.position.x + 2, TRAY.end.x - 2 - d.x))
		var py := clampi(y + jy, TRAY.position.y + 2, maxi(TRAY.position.y + 2, TRAY.end.y - 2 - d.y))
		var bb: Rect2i = pieces[p]["bbox"]
		var cx := float(px) + float(d.x) / 2.0
		var cy := float(py) + float(d.y) / 2.0
		pos[p] = Vector2i(int(round(cx - float(bb.size.x) / 2.0)), int(round(cy - float(bb.size.y) / 2.0)))
		x += d.x + gap
		row_h = maxi(row_h, d.y)
	L["start_pos"] = pos
	L["start_rot"] = rots
	L["tray_order"] = order
