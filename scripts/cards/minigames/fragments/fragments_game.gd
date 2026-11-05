# Fragments: a torn pawn ticket, letter or scroll. The player lays the pieces back together (drag; right
# click or the turn button turns a piece; a piece that lands in its own place lies flat there), then judges it
# with their own eyes: crosses the seams where the ink does not run on, and says whether the riding seal's two
# halves line up. The game shows nothing about right or wrong; what the player marks is what is reported.
# Rule lines at the foot of the table say what each mark means (acceptance fix2); they never name the answer.
# Contract: docs/cards/CARDS_INTERFACES.md 3.3 C15, 8.1, 8.2. Random domain c.mg.fragments.layout.
# Every change goes through apply_op(op) (mouse, keyboard, autoplay, tests); ops_log() replays a game exactly.
# Ops: ["move", p, x, y] ["rotate", p, d] ["seam", a, b] ["seal", 1|2] ["light", 0|1] ["lens", 0|1] ["done"].
# Owner C15.
class_name CardFragmentsGame
extends CardMiniGame

const Layout = preload("res://scripts/cards/minigames/fragments/frag_layout.gd")
const Paint = preload("res://scripts/cards/minigames/fragments/frag_piece.gd")
const BoardSc = preload("res://scripts/cards/minigames/fragments/frag_board.gd")
const LensSc = preload("res://scripts/cards/minigames/fragments/frag_lens.gd")
const Chrome = preload("res://scripts/cards/minigames/mg_chrome.gd")
const DOMAIN := "c.mg.fragments.layout"
const PANEL_POS := Vector2(100, 50)
const PANEL_SIZE := Vector2(1080, 620)
const SEAL_AT := Vector2(40, 456)
const SEAL_W := 200.0
const SEAL_GAP := 12.0
const TOOL_Y := 552.0
const TOOL_W := 140.0
const ROTATE_X := 34.0
const LENS_X := 186.0
const LIGHT_X := 338.0
const DONE_X := 690.0
const DONE_W := 180.0
const ABORT_X := 882.0
const SNAP := 28
const MOVE_AREA := Rect2(16, 84, 1048, 460)   # a piece's centre stays in here (panel coords)
const LENS_AREA := Rect2(20, 92, 1040, 452)
const LENS_PX := 72
## The rule lines (acceptance fix2): written at the foot of the table, under the pieces lying there, so they
## show once the table is cleared, which is when the seams are judged. Rules of the game only (what a jog, a
## browner half, a stain, a stepped seal and broken grain mean), never this sheet's answer.
const RULES_RECT := Rect2(566, 436, 474, 92)

var _params: Dictionary = {}
var _built: bool = false
var _done: bool = false
var _L: Dictionary = {}
var _paint: Array = []
var _pos: Array = []
var _rot: Array = []
var _placed: Array = []
var _snapped: Array = []
var _crosses: Array = []
var _seal_call: int = 0
var _lens_on: bool = false
var _lens_used: bool = false
var _light_on: bool = false
var _light_used: bool = false
var _rotations: int = 0
var _units: int = 0
var _ops: Array = []
var _mps: int = 1
var _max_min: int = 30
var _dangzi: int = 0
var _ticket_drawn: bool = false
var _backlight: bool = false
var _lens_px: int = LENS_PX
var _ap: Array = []
var _ap_started: bool = false
var _panel: Panel = null
var _board = null
var _lens = null
var _seal_box: Control = null
var _seal_btns: Array = []
var _rotate_btn: Button = null
var _lens_btn: Button = null
var _light_btn: Button = null
var _done_btn: Button = null
var _rules: VBoxContainer = null


func kind() -> StringName:
	return &"fragments"


func start(params: Dictionary) -> void:
	if _built:
		return
	_built = true
	_params = CardState.int_restore(params.duplicate(true))
	_mps = maxi(1, int(_params.get("minutes_per_step", 1)))
	_max_min = maxi(0, int(_params.get("max_minutes", 30)))
	_dangzi = maxi(0, int(_params.get("dangzi_marks", 0)))
	_backlight = bool(_params.get("backlight", false))
	_lens_px = clampi(int(_params.get("lens_px", LENS_PX)), 40, 140)
	var art_img := _art_image(str(_params.get("art", "")))
	_ticket_drawn = Paint.drawn_ticket(_params, art_img)
	var base := Layout.SHEET if int(_params.get("pieces", 0)) <= 6 else Layout.SHEET_MANY
	if art_img != null:
		base = art_img.get_size()
	_L = Layout.build(_params, base)
	_paint = Paint.paint(_L, _params, art_img)
	var n := int(_L["n"])
	for p in range(n):
		_pos.append(_L["start_pos"][p] if not is_hole(p) else _L["slots"][p])
		_rot.append(int(_L["start_rot"][p]))
		_placed.append(false)
		_snapped.append(false)
	_mount()
	refresh()


## Skill = the chance that each judgment is the right one (DESIGN P8). Plays through apply_op and finishes.
func autoplay(skill: float) -> void:
	if _done:
		return
	for op in _plan(skill):
		if _done:
			return
		apply_op(op)
	if not _done:
		apply_op(["done"])


func autoplay_step() -> bool:
	if _done:
		return false
	if not _ap_started:
		_ap = _plan(0.9)
		_ap_started = true
	if _ap.is_empty():
		apply_op(["done"])
		return false
	apply_op(_ap.pop_front())
	return not _done


func abort() -> void:
	if _done:
		return
	_done = true
	if _lens != null:
		_lens.visible = false
	super.abort()


## The only way the game changes. Returns false (and changes nothing) when the op does not apply.
func apply_op(op: Array) -> bool:
	if _done or op.is_empty() or typeof(op[0]) != TYPE_STRING:
		return false
	var ok := false
	match str(op[0]):
		"move":
			ok = _op_move(op)
		"rotate":
			ok = _op_rotate(op)
		"seam":
			ok = _op_seam(op)
		"seal":
			ok = _op_seal(op)
		"light":
			ok = _op_light(op)
		"lens":
			ok = _op_lens(op)
		"done":
			if op.size() != 1:
				return false
			_ops.append(["done"])
			_submit()
			return true
	if ok:
		_ops.append(op.duplicate(true))
		_minutes_spent = mini(_units * _mps, _max_min)
		refresh()
	return ok


func ops_log() -> Array:
	return _ops.duplicate(true)


# ---------------- read-outs for the board and tests ----------------
func is_done() -> bool:
	return _done


func layout() -> Dictionary:
	return _L


func paint_row(p: int) -> Dictionary:
	return _paint[p]


func piece_pos(p: int) -> Vector2i:
	return _pos[p]


func piece_rot(p: int) -> int:
	return int(_rot[p])


func is_placed(p: int) -> bool:
	return bool(_placed[p])


func is_hole(p: int) -> bool:
	return p == int(_L.get("missing", -1))


func crosses() -> Array:
	return _crosses.duplicate()


func light_on() -> bool:
	return _light_on


func seam_ready(s: int) -> bool:
	var row: Dictionary = _L["seams"][s]
	return is_placed(int(row["a"])) and is_placed(int(row["b"]))


func placed_count() -> int:
	var n := 0
	for p in range(_placed.size()):
		if bool(_placed[p]):
			n += 1
	return n


func avail_count() -> int:
	return maxi(0, int(_L.get("n", 0)) - (1 if int(_L.get("missing", -1)) >= 0 else 0))


## Cut and scatter, as plain ints (tests compare two games).
func layout_signature() -> Array:
	var out: Array = [int(_L["n"]), int(_L["k"]), int(_L["cols"]), int(_L["rows"]), int(_L["missing"])]
	for p in range(int(_L["n"])):
		var sp: Vector2i = _L["start_pos"][p]
		out.append([p, sp.x, sp.y, int(_L["start_rot"][p])])
	for row in _L["seams"]:
		out.append([int(row["a"]), int(row["b"]), int(row["x0"]), int(row["y0"]), int(row["x1"]), int(row["y1"])])
	var seal: Dictionary = _L["seal"]
	if not seal.is_empty():
		out.append([int(seal["seam"]), int(seal["t"]), int(seal["moved"])])
	for st in _L["strokes"]:
		out.append([int(st["seam"]), int(st["t"]), int(st["la"]), int(st["lb"])])
	return out


## Panel-coord centre of a piece's slot (tests click there).
func slot_center(p: int) -> Vector2:
	var row: Dictionary = _paint[p]
	var tex: Texture2D = row["tex"]
	return Vector2(_L["slots"][p]) + tex.get_size() * 0.5


func piece_center(p: int) -> Vector2:
	var tex: Texture2D = (_paint[p] as Dictionary)["tex"]
	return Vector2(_pos[p]) + tex.get_size() * 0.5


func panel_origin() -> Vector2:
	return PANEL_POS


## The host's abort spot: after "done" in the tool row.
func abort_rect() -> Rect2:
	return Chrome.abort_at(_panel, Vector2(ABORT_X, TOOL_Y))


func seal_button_rect(c: int) -> Rect2:
	var b: Button = _seal_btns[clampi(c - 1, 0, 1)]
	return b.get_global_rect()


func tool_button(name_id: String) -> Button:
	match name_id:
		"rotate":
			return _rotate_btn
		"lens":
			return _lens_btn
		"light":
			return _light_btn
		"done":
			return _done_btn
	return null


# ---------------- board callbacks ----------------
func pointer(at: Vector2) -> void:
	if _lens == null:
		return
	if _lens_on and not _done and LENS_AREA.has_point(at):
		_lens.visible = true
		_lens.follow(at)
	else:
		_lens.visible = false


func pointer_gone() -> void:
	if _lens != null:
		_lens.visible = false


## The glass while it shows, in panel coords (Rect2() when it does not). It magnifies whatever is drawn under
## it, so the board keeps its own hover band out of this circle.
func glass_rect() -> Rect2:
	if _lens == null or not _lens.visible:
		return Rect2()
	return Rect2(_lens.position, _lens.size)


func refresh() -> void:
	if _board != null:
		_board.queue_redraw()
	var seal: Dictionary = _L.get("seal", {})
	var seal_ok := _seal_ready()
	for i in range(_seal_btns.size()):
		var b: Button = _seal_btns[i]
		b.visible = not seal.is_empty()
		b.disabled = not seal_ok or _done
		b.set_pressed_no_signal(_seal_call == i + 1)
	if _lens_btn != null:
		_lens_btn.set_pressed_no_signal(_lens_on)
	if _light_btn != null:
		_light_btn.set_pressed_no_signal(_light_on)
	if _rotate_btn != null:
		var sel := -1 if _board == null else int(_board.selected)
		_rotate_btn.disabled = sel < 0 or is_placed(sel) or _done


# ---------------- ops ----------------
func _op_move(op: Array) -> bool:
	if op.size() != 4:
		return false
	var p := _arg(op, 1)
	if not _loose(p):
		return false
	var x := _arg(op, 2)
	var y := _arg(op, 3)
	if x == ARG_BAD or y == ARG_BAD:
		return false
	var half := (_paint[p]["tex"] as Texture2D).get_size() * 0.5
	var cx := clampf(float(x) + half.x, MOVE_AREA.position.x, MOVE_AREA.end.x)
	var cy := clampf(float(y) + half.y, MOVE_AREA.position.y, MOVE_AREA.end.y)
	var to := Vector2i(int(round(cx - half.x)), int(round(cy - half.y)))
	if to == _pos[p]:
		return false
	_pos[p] = to
	_try_snap(p)
	_emit_tool("move")
	return true


func _op_rotate(op: Array) -> bool:
	if op.size() != 3:
		return false
	var p := _arg(op, 1)
	var d := _arg(op, 2)
	if not _loose(p) or (d != 1 and d != -1):
		return false
	_rot[p] = posmod(int(_rot[p]) + d, 4)
	_rotations += 1
	_try_snap(p)
	_emit_tool("rotate")
	return true


func _op_seam(op: Array) -> bool:
	if op.size() != 3:
		return false
	var a := _arg(op, 1)
	var b := _arg(op, 2)
	if a == ARG_BAD or b == ARG_BAD:
		return false
	var s := Layout.seam_of(_L, a, b)
	if s < 0 or not seam_ready(s):
		return false
	if _crosses.has(s):
		_crosses.erase(s)
	else:
		_crosses.append(s)
		_crosses.sort()
	_units += 1
	_emit_tool("seam")
	return true


func _op_seal(op: Array) -> bool:
	if op.size() != 2:
		return false
	var c := _arg(op, 1)
	if (c != 1 and c != 2) or c == _seal_call or not _seal_ready():
		return false
	_seal_call = c
	_units += 1
	_emit_tool("seal")
	return true


func _op_light(op: Array) -> bool:
	if op.size() != 2 or not _backlight:
		return false
	var v := _arg(op, 1)
	if (v != 0 and v != 1) or (v == 1) == _light_on:
		return false
	_light_on = v == 1
	if _light_on and not _light_used:
		_light_used = true
		_units += 1
	_emit_tool("backlight")
	return true


func _op_lens(op: Array) -> bool:
	if op.size() != 2:
		return false
	var v := _arg(op, 1)
	if (v != 0 and v != 1) or (v == 1) == _lens_on:
		return false
	_lens_on = v == 1
	if _lens_on:
		_lens_used = true
	elif _lens != null:
		_lens.visible = false
	_emit_tool("lens")
	return true


const ARG_BAD := -999999


static func _arg(op: Array, i: int) -> int:
	if i >= op.size():
		return ARG_BAD
	var v = op[i]
	if typeof(v) == TYPE_INT:
		return int(v)
	if typeof(v) == TYPE_FLOAT and is_finite(v) and float(v) == floorf(v):
		return int(v)
	return ARG_BAD


func _loose(p: int) -> bool:
	return p >= 0 and p < _placed.size() and not is_hole(p) and not bool(_placed[p])


func _try_snap(p: int) -> void:
	if posmod(int(_rot[p]), 4) != 0:
		return
	var slot: Vector2i = _L["slots"][p]
	var at: Vector2i = _pos[p]
	if absi(at.x - slot.x) <= SNAP and absi(at.y - slot.y) <= SNAP:
		_pos[p] = slot
		_placed[p] = true
		if not bool(_snapped[p]):
			_snapped[p] = true
			_units += 1


func _seal_ready() -> bool:
	var seal: Dictionary = _L.get("seal", {})
	if seal.is_empty():
		return false
	return seam_ready(int(seal["seam"]))


# ---------------- result ----------------
func _submit() -> void:
	if _done:
		return
	_done = true
	if _lens != null:
		_lens.visible = false
	_minutes_spent = mini(_units * _mps, _max_min)
	refresh()
	finished.emit({
		"quality_permille": _quality(),
		"observations": _observations(),
		"minutes": _minutes_spent,
		"measures": _measures(),
		"aborted": false,
	})


func _measures() -> Dictionary:
	var pairs: Array = []
	for s in _crosses:
		var row: Dictionary = _L["seams"][int(s)]
		pairs.append([int(row["a"]), int(row["b"])])
	pairs.sort_custom(func(x, y): return int(x[0]) < int(y[0]) or (int(x[0]) == int(y[0]) and int(x[1]) < int(y[1])))
	return {"placed": placed_count(), "rotations": _rotations, "seal_checked": _seal_call != 0,
		"seams": pairs, "seal_call": _seal_call}


func _observations() -> Array:
	var out: Array = []
	var avail := avail_count()
	var placed := placed_count()
	var full := avail > 0 and placed >= avail
	var sparse := avail <= 0 or placed * 2 <= avail
	if _seal_call == 1:
		out.append("obs.fragments.seal_aligned")
	elif _seal_call == 2:
		out.append("obs.fragments.seal_offset")
	if not _crosses.is_empty():
		out.append("obs.fragments.ink_breaks")
	elif full:
		out.append("obs.fragments.ink_continuous")
	var mark := int(_L.get("mark", -1))
	if _dangzi > 0 and _ticket_drawn and mark >= 0 and is_placed(mark):
		out.append("obs.fragments.dangzi_clear")
	if _missing_framed():
		out.append("obs.fragments.piece_missing")
	if sparse or out.is_empty():
		out.append("obs.fragments.unsure")
	return out


## Every piece around the gap is in place.
func _missing_framed() -> bool:
	var m := int(_L.get("missing", -1))
	if m < 0:
		return false
	var cell: Array = _L["cell"]
	var rows := int(_L["rows"])
	var cols := int(_L["cols"])
	var near: Array = []
	for r in range(rows):
		for c in range(cols):
			if int(cell[r][c]) != m:
				continue
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var rr: int = r + d.y
				var cc: int = c + d.x
				if rr < 0 or cc < 0 or rr >= rows or cc >= cols:
					continue
				var q := int(cell[rr][cc])
				if q != m and not near.has(q):
					near.append(q)
	if near.is_empty():
		return false
	for q2 in near:
		if not is_placed(int(q2)):
			return false
	return true


## Clarity from what the player visibly did (DESIGN P3): how much is put together, the glass, the light.
func _quality() -> int:
	var avail := avail_count()
	var placed := placed_count()
	var q := 0
	if avail > 0:
		q = int(float(placed * 600) / float(avail))
	if _lens_used:
		q += 200
	if _light_used or (not _backlight and avail > 0 and placed >= avail):
		q += 200
	q = mini(q, 1000)
	if avail <= 0 or placed * 2 <= avail:
		q = mini(q, 340)
	return q


# ---------------- autoplay ----------------
## Puts every piece in place (half of them under skill 0.3), then for each judgment draws
## JevRng [9000 + i]: under skill = the right call. Other paper: cross one of its seams. Stain: cross it
## (wrongly) when [9200] >= skill. Seal: the right call when [9300] < skill.
func _plan(skill: float) -> Array:
	var ops: Array = [["lens", 1]]
	if _backlight:
		ops.append(["light", 1])
	var seed_v := int(_L["seed"])
	var order: Array = _L["tray_order"]
	var want := order.size() if skill >= 0.3 else int(float(order.size()) / 2.0)
	var placed: Dictionary = {}
	for i in range(mini(want, order.size())):
		var p := int(order[i])
		var r := int(_rot[p])
		if r == 1:
			ops.append(["rotate", p, -1])
		elif r == 2:
			ops.append(["rotate", p, 1])
			ops.append(["rotate", p, 1])
		elif r == 3:
			ops.append(["rotate", p, 1])
		var slot: Vector2i = _L["slots"][p]
		ops.append(["move", p, slot.x, slot.y])
		placed[p] = true
	var odd: Array = _L["odd"]
	var crossed: Dictionary = {}
	for p2 in odd:
		var q := int(p2)
		if not placed.has(q):
			continue
		if JevRng.draw(seed_v, DOMAIN, [9000 + q]) < skill:
			var s := _seam_for(q, placed, crossed, odd, true)
			if s >= 0:
				crossed[s] = true
				var row: Dictionary = _L["seams"][s]
				ops.append(["seam", int(row["a"]), int(row["b"])])
	var st: Dictionary = _L["stain"]
	if not st.is_empty():
		var sp := int(st["piece"])
		if placed.has(sp) and not odd.has(sp) and JevRng.draw(seed_v, DOMAIN, [9200]) >= skill:
			var s2 := _seam_for(sp, placed, crossed, odd, false)
			if s2 >= 0:
				crossed[s2] = true
				var row2: Dictionary = _L["seams"][s2]
				ops.append(["seam", int(row2["a"]), int(row2["b"])])
	var seal: Dictionary = _L["seal"]
	if not seal.is_empty():
		var srow: Dictionary = _L["seams"][int(seal["seam"])]
		if placed.has(int(srow["a"])) and placed.has(int(srow["b"])):
			var right := 2 if int(seal["shift"]) >= 2 else 1
			ops.append(["seal", right if JevRng.draw(seed_v, DOMAIN, [9300]) < skill else 3 - right])
	ops.append(["done"])
	return ops


## A seam of piece p whose other piece is placed and not yet crossed; prefer (or require) a plain neighbour.
func _seam_for(p: int, placed: Dictionary, crossed: Dictionary, odd: Array, allow_odd: bool) -> int:
	var seams: Array = _L["seams"]
	var fallback := -1
	for s in range(seams.size()):
		var row: Dictionary = seams[s]
		var a := int(row["a"])
		var b := int(row["b"])
		if (a != p and b != p) or crossed.has(s):
			continue
		var other := b if a == p else a
		if not placed.has(other):
			continue
		if not odd.has(other):
			return s
		if allow_odd and fallback < 0:
			fallback = s
	return fallback


# ---------------- building ----------------
func _art_image(art: String) -> Image:
	if not art.begins_with("item."):
		return null
	var tex := CardArt.texture(art)
	if tex == null:
		return null
	var img := tex.get_image()
	if img == null or img.is_empty() or img.get_width() < 8 or img.get_height() < 8:
		return null
	return img


func _mount() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var shade := ColorRect.new()
	shade.color = CardTheme.color(&"shade")
	shade.position = Vector2.ZERO
	shade.size = Vector2(1280, 720)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shade)
	_panel = Panel.new()
	_panel.position = PANEL_POS
	_panel.size = PANEL_SIZE
	_panel.custom_minimum_size = PANEL_SIZE
	_panel.clip_contents = true
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.add_theme_stylebox_override("panel", Chrome.frame())
	add_child(_panel)
	_panel.add_child(Chrome.title(CardText.ui("c15.fragments.title"), CardText.is_draft("c15.fragments.title"),
		PANEL_SIZE.x))
	if _ticket_drawn:
		var num := Chrome.note(CardText.ui("g04.ticket.number"), CardText.is_draft("g04.ticket.number"))
		num.position = Vector2(Layout.BOARD.position.x, 84)
		num.size = Vector2(Layout.BOARD.size.x, 22)
		_panel.add_child(num)
	var tray_cap := Chrome.note(CardText.ui("c15.cap.tray"), CardText.is_draft("c15.cap.tray"))
	tray_cap.position = Vector2(Layout.TRAY.position.x, 84)
	tray_cap.size = Vector2(Layout.TRAY.size.x, 22)
	_panel.add_child(tray_cap)
	var board_plate := Chrome.plate(Chrome.inset(), Vector2(Layout.BOARD.position) - Vector2(6, 6),
		Vector2(Layout.BOARD.size) + Vector2(12, 12))
	_panel.add_child(board_plate)
	_panel.add_child(Chrome.plate(Chrome.inset(), Vector2(Layout.TRAY.position) - Vector2(6, 6),
		Vector2(Layout.TRAY.size) + Vector2(12, 12)))
	_build_rules()
	_board = BoardSc.new()
	_board.position = Vector2.ZERO
	_board.size = PANEL_SIZE
	_panel.add_child(_board)
	_board.setup(self, _L["tray_order"])
	_build_seal_row()
	_build_tools()
	_lens = LensSc.new()
	_lens.setup(_lens_px)
	_panel.add_child(_lens)
	CardAnchors.register(&"a.mg.fragments.main", _panel)
	CardAnchors.register(&"a.mg.fragments.board", board_plate)
	CardAnchors.register(&"a.mg.fragments.seal", _seal_box)
	if CardIds.is_known_anchor("a.mg.fragments.seam"):
		CardAnchors.register(&"a.mg.fragments.seam", board_plate)


func _build_seal_row() -> void:
	_seal_box = Control.new()
	_seal_box.position = SEAL_AT
	_seal_box.size = Vector2(SEAL_W * 2.0 + SEAL_GAP, Chrome.BUTTON_H - 4.0)
	_seal_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_seal_box)
	var keys := ["c15.seal.aligned", "c15.seal.offset"]
	for i in range(2):
		var b := _toggle(str(keys[i]), Vector2((SEAL_W + SEAL_GAP) * float(i), 0), Vector2(SEAL_W, Chrome.BUTTON_H - 4.0))
		b.pressed.connect(_on_seal.bind(i + 1))
		_seal_box.add_child(b)
		_seal_btns.append(b)


## The rule lines at the foot of the table (added before the board, so pieces lying there cover them). The seal
## line only when the sheet carries a riding seal, the light line only when the light is at hand.
func _build_rules() -> void:
	_rules = VBoxContainer.new()
	_rules.name = "Rules"
	_rules.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rules.alignment = BoxContainer.ALIGNMENT_END
	_rules.position = RULES_RECT.position
	_rules.size = RULES_RECT.size
	_rules.add_theme_constant_override("separation", 2)
	_panel.add_child(_rules)
	_rule_line("RuleSeam", "c15.frag.rule.seam")
	_rule_line("RuleStain", "c15.frag.rule.stain")
	if not (_L.get("seal", {}) as Dictionary).is_empty():
		_rule_line("RuleSeal", "c15.frag.rule.seal")
	if _backlight:
		_rule_line("RuleLight", "c15.frag.rule.light")


func _rule_line(node_name: String, key: String) -> void:
	var l := Chrome.note(CardText.ui(key), CardText.is_draft(key))
	l.name = node_name
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(RULES_RECT.size.x, 0)
	_rules.add_child(l)


## The rule lines shown, top to bottom (tests).
func rule_lines() -> PackedStringArray:
	var out := PackedStringArray()
	if _rules != null:
		for c in _rules.get_children():
			if c is Label:
				out.append((c as Label).text)
	return out


func _build_tools() -> void:
	_rotate_btn = _button("c15.tool.rotate", Vector2(ROTATE_X, TOOL_Y), Vector2(TOOL_W, Chrome.BUTTON_H))
	_rotate_btn.pressed.connect(_on_rotate)
	_panel.add_child(_rotate_btn)
	_lens_btn = _toggle("c15.tool.lens", Vector2(LENS_X, TOOL_Y), Vector2(TOOL_W, Chrome.BUTTON_H))
	_lens_btn.tooltip_text = CardText.ui("c15.tool.lens.tip")
	_lens_btn.pressed.connect(_on_lens)
	_panel.add_child(_lens_btn)
	if _backlight:
		_light_btn = _toggle("c15.tool.backlight", Vector2(LIGHT_X, TOOL_Y), Vector2(TOOL_W, Chrome.BUTTON_H))
		_light_btn.tooltip_text = CardText.ui("c15.tool.backlight.tip")
		_light_btn.pressed.connect(_on_light)
		_panel.add_child(_light_btn)
	_done_btn = _button("c15.btn.done_frag", Vector2(DONE_X, TOOL_Y), Vector2(DONE_W, Chrome.BUTTON_H))
	_done_btn.theme_type_variation = &"PrimaryButton"
	_done_btn.pressed.connect(_on_done)
	_panel.add_child(_done_btn)


func _on_seal(c: int) -> void:
	apply_op(["seal", c])
	refresh()


func _on_rotate() -> void:
	if _board == null:
		return
	var p := int(_board.selected)
	if _loose(p):
		apply_op(["rotate", p, 1])
	refresh()


func _on_lens() -> void:
	apply_op(["lens", 0 if _lens_on else 1])
	refresh()


func _on_light() -> void:
	apply_op(["light", 0 if _light_on else 1])
	refresh()


func _on_done() -> void:
	apply_op(["done"])


func _button(key: String, at: Vector2, sz: Vector2) -> Button:
	var b := Chrome.button(CardText.ui(key))
	b.position = at
	b.size = sz
	b.custom_minimum_size = sz
	return b


## A button that stays down while its choice holds; the player's choice shows a gold edge.
func _toggle(key: String, at: Vector2, sz: Vector2) -> Button:
	var b := _button(key, at, sz)
	b.toggle_mode = true
	var chosen := CardTheme.button_style(&"btn_hover_top", &"btn_top", &"gold_hi")
	b.add_theme_stylebox_override("pressed", chosen)
	b.add_theme_stylebox_override("hover_pressed", chosen)
	return b


func _emit_tool(tool: String) -> void:
	var bus := _bus()
	if bus == null:
		return
	bus.ui_event.emit(&"mg_tool", {"kind": "fragments", "tool": tool})


func _bus() -> CardEventBus:
	var n: Node = self
	while n != null:
		var found = n.get("bus")
		if found is CardEventBus:
			return found as CardEventBus
		n = n.get_parent()
	return null


## Keyboard (contract 8: playable by keyboard; Esc = abort). The same ops as the mouse: Tab / Shift+Tab pick
## the next / previous loose piece (past the last: none), arrows move it 16 px (Shift: 64), Q / E turn it.
## With no piece picked the arrows move the look point 4 px (Shift: 16), the glass follows it; S / Shift+S
## take it to the next / previous seam between placed pieces; X, Enter or Space cross the seam it is on (or
## take the cross off). 1 / 2 call the seal, L the glass, B the light, F hands it back.
## These are read in _input, ahead of the GUI: Tab (and arrows) would otherwise move keyboard focus to the
## table under the panel. Esc stays in _unhandled_input, so an overlay above (help) closes itself first.
func _input(event: InputEvent) -> void:
	if not _built or _done or _board == null or not (event is InputEventKey):
		return
	var key := event as InputEventKey
	if not key.pressed or key.ctrl_pressed or key.alt_pressed or key.meta_pressed:
		return
	var code := _code(key)
	if code == KEY_ESCAPE or (key.echo and not _is_arrow(code)):
		return
	if not _on_key(key, code):
		return
	var vp := get_viewport()
	if vp != null:
		vp.set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if not _built or _done or not (event is InputEventKey):
		return
	var key := event as InputEventKey
	if not key.pressed or key.echo or _code(key) != KEY_ESCAPE:
		return
	abort()
	var vp := get_viewport()
	if vp != null:
		vp.set_input_as_handled()


func _on_key(key: InputEventKey, code: Key) -> bool:
	var fast := key.shift_pressed
	match code:
		KEY_TAB:
			_board.key_pick(-1 if fast else 1)
		KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN:
			var d := Vector2i(int(code == KEY_RIGHT) - int(code == KEY_LEFT), int(code == KEY_DOWN) - int(code == KEY_UP))
			_board.key_arrow(d, fast)
		KEY_Q, KEY_E:
			_board.key_turn(1 if code == KEY_E else -1)
		KEY_S:
			_board.key_seam(-1 if fast else 1)
		KEY_X, KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			_board.key_cross()
		KEY_1, KEY_KP_1, KEY_2, KEY_KP_2:
			apply_op(["seal", 1 if code in [KEY_1, KEY_KP_1] else 2])
		KEY_L:
			apply_op(["lens", 0 if _lens_on else 1])
			_board.key_glass()
		KEY_B:
			if not _backlight:
				return false
			apply_op(["light", 0 if _light_on else 1])
		KEY_F:
			apply_op(["done"])
		_:
			return false
	refresh()
	return true


static func _code(key: InputEventKey) -> Key:
	return key.keycode if key.keycode != KEY_NONE else key.physical_keycode


static func _is_arrow(code: Key) -> bool:
	return code in [KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN]
