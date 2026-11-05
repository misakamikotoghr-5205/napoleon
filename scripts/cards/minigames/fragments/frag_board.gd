# The fragments work surface: the faint outline of the whole sheet, the gap of a missing piece, the pieces
# (placed ones lie flat in their slots, loose ones lie on the table in quarter turns), the player's crosses
# on seams, and the mouse: drag a loose piece and let go = move, right click = turn it, click on the seam
# between two placed pieces = cross it / take the cross off. The keyboard does the same through the key_*()
# calls (a picked piece, a look point the glass follows). Everything goes through game.apply_op().
# Covers the whole panel (local coords = panel coords); the panel's buttons sit on top of it.
# No class_name; preload it. Owner C15.
extends Control

const Layout = preload("res://scripts/cards/minigames/fragments/frag_layout.gd")
const SEAM_TOL := 9.0
const CROSS := 8.0
const KEY_STEP := 16          # keyboard: a picked piece moves this far per arrow (x4 with Shift)
const LOOK_STEP := 4          # keyboard: the look point moves this far per arrow (x4 with Shift)
const LOOK_MARK := 5.0        # the look point's ticks, clear of the point itself
const BAND_W := 3.0           # the hover band's width

var game = null
var selected: int = -1
var z_order: Array = []

var _drag: int = -1
var _grab: Vector2 = Vector2.ZERO
var _drag_at: Vector2 = Vector2.ZERO
var _hover_seam: int = -1
var _look: Vector2 = Vector2.ZERO    # keyboard look point (panel coords)
var _look_on: bool = false           # the keyboard is pointing; the mouse takes over when it moves


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	focus_mode = Control.FOCUS_NONE
	mouse_exited.connect(_on_exit)


func setup(p_game, order: Array) -> void:
	game = p_game
	z_order = order.duplicate()


## Topmost loose piece under the point (exact torn shape), or -1.
func piece_at(at: Vector2) -> int:
	var i := z_order.size() - 1
	while i >= 0:
		var p := int(z_order[i])
		if not game.is_placed(p) and _hits(p, at):
			return p
		i -= 1
	return -1


## Seam (index) between two placed pieces within SEAM_TOL of the point, nearest first, or -1.
func seam_at(at: Vector2) -> int:
	var L: Dictionary = game.layout()
	var best := -1
	var best_d := SEAM_TOL
	for s in range((L["seams"] as Array).size()):
		if not game.seam_ready(s):
			continue
		var ends: Array = Layout.seam_ends(L, s)
		var q := Geometry2D.get_closest_point_to_segment(at, ends[0], ends[1])
		var d := q.distance_to(at)
		if d <= best_d:
			best_d = d
			best = s
	return best


## Where a seam's cross goes, in panel coords (its middle, or beside the seal).
func seam_mid(s: int) -> Vector2:
	return Layout.cross_point(game.layout(), s)


func raise(p: int) -> void:
	z_order.erase(p)
	z_order.append(p)


func _gui_input(event: InputEvent) -> void:
	if game == null or game.is_done():
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_press(mb.position)
			else:
				_release()
			accept_event()
		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			var p := piece_at(mb.position)
			if p >= 0:
				selected = p
				raise(p)
				game.apply_op(["rotate", p, 1])
			accept_event()
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		game.pointer(mm.position)
		var was_look := _look_on
		_look_on = false
		if _drag >= 0:
			_drag_at = mm.position - _grab
			queue_redraw()
		else:
			var s := seam_at(mm.position)
			# While the glass shows, the band's gap follows it, so redraw on every move along a seam.
			if s != _hover_seam or was_look or (s >= 0 and game.glass_rect().has_area()):
				_hover_seam = s
				queue_redraw()


func _press(at: Vector2) -> void:
	var p := piece_at(at)
	if p >= 0:
		_drag = p
		var pos: Vector2i = game.piece_pos(p)
		_grab = at - Vector2(pos)
		_drag_at = Vector2(pos)
		selected = p
		raise(p)
		game.refresh()
		return
	var s := seam_at(at)
	if s >= 0:
		var row: Dictionary = game.layout()["seams"][s]
		game.apply_op(["seam", int(row["a"]), int(row["b"])])
		return
	selected = -1
	game.refresh()


func _release() -> void:
	if _drag < 0:
		return
	var p := _drag
	_drag = -1
	var to := Vector2i(int(round(_drag_at.x)), int(round(_drag_at.y)))
	if game.apply_op(["move", p, to.x, to.y]):
		if game.is_placed(p) and selected == p:
			selected = -1
	game.refresh()


# ---------------- keyboard (the game turns keys into these calls) ----------------
## Picks the next (dir 1) or previous (-1) loose piece in table order; one step past the last picks none.
func key_pick(dir: int) -> void:
	var ring: Array = [-1]
	for p2 in game.layout()["tray_order"]:
		if not game.is_placed(int(p2)):
			ring.append(int(p2))
	selected = int(ring[posmod(maxi(0, ring.find(selected)) + dir, ring.size())])
	if selected >= 0:
		raise(selected)
	queue_redraw()


## Arrows: move the picked loose piece KEY_STEP px (fast: x4); with none picked, the look point LOOK_STEP px.
func key_arrow(d: Vector2i, fast: bool) -> void:
	if selected >= 0 and not game.is_placed(selected):
		var step := KEY_STEP * (4 if fast else 1)
		var at: Vector2i = game.piece_pos(selected)
		game.apply_op(["move", selected, at.x + d.x * step, at.y + d.y * step])
		if game.is_placed(selected):
			selected = -1
		queue_redraw()
		return
	selected = -1
	_look_to(_look_from() + Vector2(d * LOOK_STEP * (4 if fast else 1)))


## Turns the picked loose piece a quarter (1 one way, -1 back).
func key_turn(d: int) -> void:
	if selected >= 0 and not game.is_placed(selected):
		game.apply_op(["rotate", selected, d])


## Takes the look point to the next (dir 1) or previous (-1) seam between placed pieces: onto the seal when
## the seal sits on that seam, else to the seam's middle.
func key_seam(dir: int) -> void:
	var L: Dictionary = game.layout()
	var ready: Array = []
	for s in range((L["seams"] as Array).size()):
		if game.seam_ready(s):
			ready.append(s)
	if ready.is_empty():
		return
	var i := ready.find(_hover_seam)
	var s2 := int(ready[posmod(i + dir, ready.size())]) if i >= 0 else int(ready[0 if dir > 0 else ready.size() - 1])
	selected = -1
	_look_to(_seam_look(L, s2))


## Crosses the seam under the look point (or the mouse), or takes its cross off.
func key_cross() -> void:
	if _hover_seam < 0 or not game.seam_ready(_hover_seam):
		return
	var row: Dictionary = game.layout()["seams"][_hover_seam]
	game.apply_op(["seam", int(row["a"]), int(row["b"])])


## The glass was switched by key: while the keyboard points, it shows at the look point.
func key_glass() -> void:
	if _look_on:
		game.pointer(_look)
	queue_redraw()


func _look_from() -> Vector2:
	if _look_on:
		return _look
	var L: Dictionary = game.layout()
	return Vector2(L["origin"]) + Vector2(int(L["w"]), int(L["h"])) * 0.5


func _look_to(at: Vector2) -> void:
	var area := Rect2(Layout.BOARD).grow(8.0)
	_look = Vector2(clampf(round(at.x), area.position.x, area.end.x), clampf(round(at.y), area.position.y, area.end.y))
	_look_on = true
	_hover_seam = seam_at(_look)
	game.pointer(_look)
	queue_redraw()


func _seam_look(L: Dictionary, s: int) -> Vector2:
	var ends: Array = Layout.seam_ends(L, s)
	var a: Vector2 = ends[0]
	var b: Vector2 = ends[1]
	var seal: Dictionary = L["seal"]
	if not seal.is_empty() and int(seal["seam"]) == s:
		return a + (b - a).normalized() * float(int(seal["t"]))
	return (a + b) * 0.5


func _on_exit() -> void:
	_hover_seam = -1
	if game != null:
		game.pointer_gone()
	queue_redraw()


func _hits(p: int, at: Vector2) -> bool:
	var img: Image = game.paint_row(p)["img"]
	var local := _to_local_piece(p, Vector2(game.piece_pos(p)), at)
	var x := int(floor(local.x))
	var y := int(floor(local.y))
	if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
		return false
	return img.get_pixel(x, y).a > 0.0


func _to_local_piece(p: int, top_left: Vector2, at: Vector2) -> Vector2:
	var img: Image = game.paint_row(p)["img"]
	var half := Vector2(img.get_width(), img.get_height()) * 0.5
	var v := at - (top_left + half)
	return v.rotated(-float(game.piece_rot(p)) * PI * 0.5) + half


func _draw() -> void:
	if game == null:
		return
	var L: Dictionary = game.layout()
	var o := Vector2(L["origin"])
	var sheet := Rect2(o, Vector2(int(L["w"]), int(L["h"])))
	var dash := CardTheme.color(&"ink_3")
	draw_dashed_line(sheet.position, Vector2(sheet.end.x, sheet.position.y), dash, 1.0, 6.0)
	draw_dashed_line(Vector2(sheet.end.x, sheet.position.y), sheet.end, dash, 1.0, 6.0)
	draw_dashed_line(sheet.end, Vector2(sheet.position.x, sheet.end.y), dash, 1.0, 6.0)
	draw_dashed_line(Vector2(sheet.position.x, sheet.end.y), sheet.position, dash, 1.0, 6.0)
	var n := int(L["n"])
	for p in range(n):
		if game.is_hole(p) or game.is_placed(p):
			_draw_piece(p, Vector2(game.piece_pos(p)))
	for s in game.crosses():
		_draw_cross(seam_mid(int(s)))
	if _hover_seam >= 0 and _drag < 0:
		var ends: Array = Layout.seam_ends(L, _hover_seam)
		_draw_hover(ends[0], ends[1])
	for p2 in z_order:
		var q := int(p2)
		if game.is_placed(q) or q == _drag:
			continue
		_draw_piece(q, Vector2(game.piece_pos(q)))
		if q == selected:
			_draw_outline(q, Vector2(game.piece_pos(q)))
	if _drag >= 0:
		_draw_piece(_drag, _drag_at)
		_draw_outline(_drag, _drag_at)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if _look_on and not game.glass_rect().has_area():
		_draw_look(_look)


func _draw_hover(a: Vector2, b: Vector2) -> void:
	var col := CardTheme.with_alpha(&"gold_hi", 0.8)
	for part in band_parts(a, b, game.glass_rect()):
		draw_line(part[0], part[1], col, BAND_W)


## The hover band along the seam a-b, as [[from, to], ...]: the whole seam, or what lies outside the glass
## (Rect2() = no glass). The glass magnifies what is drawn under it, and the band must not lie over the
## junction the player is looking at.
static func band_parts(a: Vector2, b: Vector2, glass: Rect2) -> Array:
	var length := a.distance_to(b)
	if not glass.has_area() or length <= 0.0:
		return [[a, b]]
	var dir := (b - a) / length
	var c := glass.get_center()
	var t0 := (c - a).dot(dir)
	var off := (c - a - dir * t0).length()
	var r := glass.size.x * 0.5 + BAND_W
	if off >= r:
		return [[a, b]]
	var h := sqrt(r * r - off * off)
	var out: Array = []
	if t0 - h > 0.0:
		out.append([a, a + dir * minf(t0 - h, length)])
	if t0 + h < length:
		out.append([a + dir * maxf(t0 + h, 0.0), b])
	return out


## Where the keyboard points while the glass is off: four short ticks around the point, clear of it.
func _draw_look(at: Vector2) -> void:
	var c := CardTheme.color(&"lamp")
	for d in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
		draw_line(at + d * 3.0, at + d * (3.0 + LOOK_MARK), c, 1.0)


func _draw_piece(p: int, top_left: Vector2) -> void:
	var row: Dictionary = game.paint_row(p)
	var tex: Texture2D = row["tex"]
	var half := tex.get_size() * 0.5
	draw_set_transform(top_left + half, float(game.piece_rot(p)) * PI * 0.5, Vector2.ONE)
	draw_texture(tex, -half)
	if game.light_on() and row.has("fiber"):
		draw_texture(row["fiber"], -half)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_outline(p: int, top_left: Vector2) -> void:
	var tex: Texture2D = game.paint_row(p)["tex"]
	var half := tex.get_size() * 0.5
	draw_set_transform(top_left + half, float(game.piece_rot(p)) * PI * 0.5, Vector2.ONE)
	draw_rect(Rect2(-half - Vector2(2, 2), tex.get_size() + Vector2(4, 4)), CardTheme.color(&"lamp"), false, 2.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## The player's own mark: a gold cross on the seam.
func _draw_cross(at: Vector2) -> void:
	var a := Vector2(CROSS, CROSS)
	var b := Vector2(CROSS, -CROSS)
	var under := CardTheme.color(&"ink")
	var mark := CardTheme.color(&"gold_hi")
	draw_line(at - a, at + a, under, 5.0)
	draw_line(at - b, at + b, under, 5.0)
	draw_line(at - a, at + a, mark, 3.0)
	draw_line(at - b, at + b, mark, 3.0)
