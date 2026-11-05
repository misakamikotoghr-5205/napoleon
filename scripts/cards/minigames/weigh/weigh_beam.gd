# Weigh (C14): beam, pan, hook weights, poise, stars and the balance needle. Draw only; it never knows the
# hidden weight (the game hands it a tilt). Colors from CardTheme. Owner C14. No class_name (preload).
# The needle (ding pan zhen) stands on the pivot inside a fixed gate hung from the lifting cord; its tip moves
# tilt * NEEDLE_LEN * needle_gain pixels, but never less than NEEDLE_MIN_PX once the beam leans at all: one step
# off is a plain lean, not a one-pixel kink. The cord runs a short way into the gate as the fixed mark the tip
# lines up under when the beam is level. Nothing lights up when the beam is level (B9): the player watches the needle.
# While the star close-up is open (cover), star numbers that would sit under it are not drawn.
extends Control

const ARM_Y := 144.0
const NEEDLE_LEN := 46.0
const NEEDLE_MAX := 26.0
## Fewest pixels the needle tip leans when the beam is off level at all (one step off on any eye).
const NEEDLE_MIN_PX := 3
## Below this the beam counts as level (only the step nearest the weight has tilt 0).
const TILT_EPS := 0.001
## The cord's fixed mark inside the gate (pixels below the gate's top bar).
const INDEX_LEN := 6.0
const GATE_HALF := 7.0
const TWEEN_S := 0.45
const LABEL_MIN_PX := 30.0
const FACE_SIZE := 14

var tool: String = "dengzi"
var poise_step: int = 0
var poise_max: int = 1
var resolution: int = 1
var major: int = 10
var minor: int = 1
var needle_gain: int = 8
var frozen: bool = false
var fast: bool = false
var hook_faces: PackedStringArray = PackedStringArray()
## Beam-local rect the star close-up covers (empty when it is closed).
var cover: Rect2 = Rect2()
var tilt: float = 0.0:
	set(v):
		tilt = v
		_place_art()
		queue_redraw()

var art: TextureRect = null
var _tween: Tween = null
var _target: float = 0.0


func sync(state: Dictionary) -> void:
	tool = str(state.get("tool", "dengzi"))
	poise_step = int(state.get("poise_step", 0))
	poise_max = maxi(1, int(state.get("poise_max", 1)))
	resolution = maxi(1, int(state.get("resolution", 1)))
	major = maxi(1, int(state.get("major", 10)))
	minor = maxi(1, int(state.get("minor", 1)))
	needle_gain = maxi(1, int(state.get("needle_gain", 8)))
	frozen = bool(state.get("frozen", false))
	var faces: Variant = state.get("hook", PackedStringArray())
	hook_faces = PackedStringArray(faces) if (faces is PackedStringArray or faces is Array) else PackedStringArray()
	var cv: Variant = state.get("cover", Rect2())
	cover = cv if cv is Rect2 else Rect2()
	_animate_to(float(state.get("tilt", 0.0)), bool(state.get("animate", true)) and not fast)
	queue_redraw()


func halt() -> void:
	if _tween != null:
		_tween.kill()
		_tween = null


## Jump to the resting tilt (the commit freezes the beam where the physics puts it, not mid-swing).
func settle() -> void:
	halt()
	tilt = _target


func set_art(node: TextureRect) -> void:
	art = node
	_place_art()


## Integer pixels the needle tip sits off the gate centre (minus = toward the pan). 0 only when level; any lean
## shows at least NEEDLE_MIN_PX, more steps off show more (eye: needle_gain), up to the stop at NEEDLE_MAX.
func needle_offset_px() -> int:
	if absf(tilt) < TILT_EPS:
		return 0
	var px := maxi(NEEDLE_MIN_PX, int(round(absf(tilt) * NEEDLE_LEN * float(needle_gain))))
	return int(signf(tilt)) * mini(px, int(NEEDLE_MAX))


func step_at(local: Vector2) -> int:
	var f := _fulcrum()
	var d := local - f
	var c := cos(tilt)
	var s := sin(tilt)
	var x := f.x + d.x * c + d.y * s
	var a := _scale_x0()
	var b := _scale_x1()
	if b <= a + 1.0:
		return 0
	var u := clampf((x - a) / (b - a), 0.0, 1.0)
	return clampi(int(round(u * float(poise_max))), 0, poise_max)


## Where on screen the poise cord sits for a step (mouse tests click here).
func global_point_for_step(step: int) -> Vector2:
	return get_global_transform() * _xform(Vector2(_tick_x(step), ARM_Y))


func tick_texts() -> PackedStringArray:
	var out := PackedStringArray()
	var every := _label_every()
	var cap := poise_max * resolution
	var v := 0
	while v <= cap:
		if (v / major) % every == 0 and not _label_covered(v):
			out.append(str(v / major))
		v += major
	for f in hook_faces:
		out.append(f)
	return out


func _exit_tree() -> void:
	halt()


func _animate_to(target: float, animate: bool) -> void:
	_target = target
	halt()
	if frozen or not animate or not is_inside_tree() or absf(target - tilt) < 0.0005:
		tilt = target
		return
	_tween = create_tween()
	_tween.tween_property(self, "tilt", target, TWEEN_S).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _draw() -> void:
	var ink := CardTheme.color(&"text_2")
	var wood := CardTheme.color(&"gold_deep")
	var mid := CardTheme.color(&"gold_hi")
	var dark := CardTheme.color(&"text_3")
	var paper := CardTheme.color(&"paper")
	var brass := CardTheme.color(&"paper_old")
	var pale := CardTheme.color(&"gold_pale")
	var f := _fulcrum()
	_draw_cord_and_gate(dark, ink, f)
	draw_set_transform(f, tilt, Vector2.ONE)
	_draw_arm(wood, mid, f)
	_draw_pan(paper, wood, f)
	_draw_stars(ink, pale, f)
	_draw_poise(mid, ink, f)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_draw_hook(brass, wood, ink)
	_draw_needle(pale, f)


## The lifting cord from the top of the frame to the gate; the gate's two posts come down to the pivot pin.
func _draw_cord_and_gate(dark: Color, ink: Color, f: Vector2) -> void:
	var top := f.y - NEEDLE_LEN - 12.0
	draw_line(Vector2(f.x, 0.0), Vector2(f.x, top), dark, 2.0)
	draw_line(Vector2(f.x - GATE_HALF - 1.0, top), Vector2(f.x + GATE_HALF + 1.0, top), ink, 2.0)
	draw_line(Vector2(f.x, top), Vector2(f.x, top + INDEX_LEN), ink, 2.0)
	draw_line(Vector2(f.x - GATE_HALF, top), Vector2(f.x - GATE_HALF, f.y - 6.0), ink, 2.0)
	draw_line(Vector2(f.x + GATE_HALF, top), Vector2(f.x + GATE_HALF, f.y - 6.0), ink, 2.0)
	draw_line(Vector2(f.x - GATE_HALF, f.y - 6.0), Vector2(f.x - 2.0, f.y), ink, 1.0)
	draw_line(Vector2(f.x + GATE_HALF, f.y - 6.0), Vector2(f.x + 2.0, f.y), ink, 1.0)


func _draw_needle(pale: Color, f: Vector2) -> void:
	var off := float(needle_offset_px())
	var base := Vector2(f.x, f.y - 4.0)
	var tip := Vector2(f.x + off, f.y - NEEDLE_LEN)
	draw_line(base, tip, pale, 2.0)
	draw_circle(f, 3.0, pale)


func _draw_arm(wood: Color, mid: Color, f: Vector2) -> void:
	var left := _left_end() - f
	var right := _right_end() - f
	var thick := 6.0 if tool != "steelyard" else 10.0
	draw_line(left, right, wood, thick, true)
	draw_line(left + Vector2(0, -thick * 0.5 + 1.0), right + Vector2(0, -thick * 0.5 + 1.0), mid, 1.0, true)


func _draw_pan(paper: Color, wood: Color, f: Vector2) -> void:
	var c := _pan_center() - f
	var sz := _pan_size()
	var rect := Rect2(c - sz * 0.5, sz)
	var lip := _left_end() - f
	draw_line(lip, rect.position + Vector2(18, 0), wood, 2.0, true)
	draw_line(lip, Vector2(rect.end.x - 18, rect.position.y), wood, 2.0, true)
	draw_rect(rect, paper, true)
	draw_rect(rect, wood, false, 2.0)


## Stars sit on the arm: a big star with its number every major unit, small dots every minor unit when they are
## at least 4 px apart. Numbers stand above the arm; they are star counts, never a reading.
func _draw_stars(ink: Color, pale: Color, f: Vector2) -> void:
	var cap := poise_max * resolution
	var y := ARM_Y - f.y
	var span := _scale_x1() - _scale_x0()
	var minor_px := span * float(minor) / float(maxi(1, cap))
	if minor_px >= 4.0:
		var v := 0
		while v <= cap:
			if v % major != 0:
				var p := Vector2(_x_of_fen(v) - f.x, y)
				draw_rect(Rect2(p.x - 1.0, p.y - 1.0, 2.0, 2.0), pale, true)
			v += minor
	var every := _label_every()
	var font := CardTheme.font_body()
	var m := 0
	while m <= cap:
		var p2 := Vector2(_x_of_fen(m) - f.x, y)
		draw_rect(Rect2(p2.x - 1.5, p2.y - 1.5, 3.0, 3.0), pale, true)
		draw_line(p2 + Vector2(0, -5), p2 + Vector2(0, -10), ink, 1.0, true)
		if font != null and (m / major) % every == 0 and not _label_covered(m):
			draw_string(font, p2 + Vector2(-20, -14), str(m / major), HORIZONTAL_ALIGNMENT_CENTER, 40, 14, ink)
		m += major


## The poise hangs on a cord loop round the arm; the loop is the reading point.
func _draw_poise(gold: Color, ink: Color, f: Vector2) -> void:
	var p := Vector2(_tick_x(poise_step), ARM_Y) - f
	var big := tool == "steelyard"
	var w := 26.0 if big else 20.0
	var h := 20.0 if big else 15.0
	draw_arc(p, 6.0, 0.0, TAU, 18, ink, 1.0, true)
	draw_line(p, p + Vector2(0, 18), ink, 1.0, true)
	var body := Rect2(p + Vector2(-w * 0.5, 18), Vector2(w, h))
	draw_rect(body, gold, true)
	draw_rect(body, ink, false, 1.0)


## Weights on the hook hang straight down from the hook point, each block with its face (physical, allowed).
func _draw_hook(brass: Color, wood: Color, ink: Color) -> void:
	var hp := _xform(_hook_point())
	draw_line(_xform(Vector2(_hook_point().x, ARM_Y)), hp, wood, 2.0, true)
	if hook_faces.is_empty():
		draw_arc(hp + Vector2(0, 5), 5.0, 0.0, PI, 10, wood, 2.0, true)
		return
	var font := CardTheme.font_body()
	var rows: Array = _hook_rows(font)
	var y := hp.y + 8.0
	for row in rows:
		var x := hp.x - 14.0
		for item in row:
			var w := float(item[1])
			var r := Rect2(roundf(x), roundf(y), w, 20.0)
			draw_rect(r, brass, true)
			draw_rect(r, wood, false, 1.0)
			if font != null:
				draw_string(font, Vector2(r.position.x, r.position.y + 15.0), str(item[0]), HORIZONTAL_ALIGNMENT_CENTER,
					w, FACE_SIZE, CardTheme.color(&"ink"))
			x += w + 4.0
		y += 24.0
	draw_line(hp, Vector2(hp.x, hp.y + 8.0), ink, 1.0, true)


func _hook_rows(font: Font) -> Array:
	var rows: Array = []
	var row: Array = []
	var used := 0.0
	for face in hook_faces:
		var tw := 30.0
		if font != null:
			tw = font.get_string_size(face, HORIZONTAL_ALIGNMENT_LEFT, -1, FACE_SIZE).x
		var w := ceilf(tw) + 10.0
		if not row.is_empty() and used + w > 168.0:
			rows.append(row)
			row = []
			used = 0.0
		row.append([face, w])
		used += w + 4.0
	if not row.is_empty():
		rows.append(row)
	return rows


func _place_art() -> void:
	if art == null or not is_instance_valid(art):
		return
	var c := _xform(_pan_center())
	var s := art.size
	art.position = Vector2(roundi(c.x - s.x * 0.5), roundi(c.y - s.y * 0.5))
	art.pivot_offset = s * 0.5
	art.rotation = tilt


## A star number's box (beam-local, after the tilt) touches the close-up: it is left out, never cut in half.
func _label_covered(v: int) -> bool:
	if cover.size.x <= 0.0 or cover.size.y <= 0.0:
		return false
	var x := _x_of_fen(v)
	var half := 9.0
	var top := ARM_Y - 30.0
	var high := 20.0
	var font := CardTheme.font_body()
	if font != null:
		half = font.get_string_size(str(v / major), HORIZONTAL_ALIGNMENT_CENTER, 40, 14).x * 0.5 + 1.0
		top = ARM_Y - 14.0 - font.get_ascent(14) - 1.0
		high = font.get_height(14) + 2.0
	var box := Rect2(_xform(Vector2(x - half, top)), Vector2.ZERO)
	for corner in [Vector2(x + half, top), Vector2(x - half, top + high), Vector2(x + half, top + high)]:
		box = box.expand(_xform(corner))
	return box.intersects(cover.grow(1.0))


func _label_every() -> int:
	var cap := maxi(1, poise_max * resolution)
	var px := (_scale_x1() - _scale_x0()) * float(major) / float(cap)
	for k in [1, 2, 5, 10, 20, 50]:
		if px * float(k) >= LABEL_MIN_PX:
			return k
	return 100


func _x_of_fen(v: int) -> float:
	var cap := maxi(1, poise_max * resolution)
	var span := _scale_x1() - _scale_x0()
	return roundf(_scale_x0() + span * float(clampi(v, 0, cap)) / float(cap))


func _tick_x(step: int) -> float:
	return _x_of_fen(clampi(step, 0, poise_max) * resolution)


func _fulcrum() -> Vector2:
	if tool == "steelyard":
		return Vector2(210, ARM_Y)
	return Vector2(270, ARM_Y)


func _left_end() -> Vector2:
	if tool == "steelyard":
		return Vector2(96, ARM_Y)
	return Vector2(150, ARM_Y)


## The far end follows the drawing width.
func _right_end() -> Vector2:
	var w := size.x if size.x > 400.0 else 932.0
	if tool == "steelyard":
		return Vector2(w - 28.0, ARM_Y)
	return Vector2(w - 68.0, ARM_Y)


func _scale_x0() -> float:
	return _fulcrum().x + 56.0


func _scale_x1() -> float:
	return _right_end().x - 18.0


func _pan_size() -> Vector2:
	return Vector2(168, 104) if tool == "steelyard" else Vector2(150, 100)


func _pan_center() -> Vector2:
	var left := _left_end()
	return Vector2(left.x, left.y + 76)


func _hook_point() -> Vector2:
	return Vector2(_fulcrum().x + 22.0, _fulcrum().y + 40.0)


func _xform(p: Vector2) -> Vector2:
	var f := _fulcrum()
	var d := p - f
	var c := cos(tilt)
	var s := sin(tilt)
	return f + Vector2(d.x * c - d.y * s, d.x * s + d.y * c)
