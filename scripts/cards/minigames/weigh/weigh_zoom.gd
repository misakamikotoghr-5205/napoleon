# Weigh (C14): the star close-up that opens after "level, read the stars". Draws the stretch of the beam around
# the poise cord, 30 / zoom steps each side, big numbered stars and small dots. It never writes a reading: the
# player counts the stars. Draw only; colors from CardTheme. Owner C14. No class_name (preload).
extends Control

const ARM_Y := 74.0
const MARGIN := 10.0
const LABEL_SIZE := 18

var tool: String = "dengzi"
var poise_fen: int = 0
var cap_fen: int = 100
var resolution: int = 1
var major: int = 10
var minor: int = 1
var zoom: int = 2


func sync(state: Dictionary) -> void:
	tool = str(state.get("tool", "dengzi"))
	poise_fen = int(state.get("poise_fen", 0))
	cap_fen = maxi(1, int(state.get("cap_fen", 100)))
	resolution = maxi(1, int(state.get("resolution", 1)))
	major = maxi(1, int(state.get("major", 10)))
	minor = maxi(1, int(state.get("minor", 1)))
	zoom = clampi(int(state.get("zoom", 2)), 1, 4)
	queue_redraw()


## Pixels per fen: the half width shows 30 / zoom resolution steps (zoom 2 = 15 steps each side).
func px_per_fen() -> float:
	var half := size.x * 0.5 - MARGIN - 14.0
	return half * float(zoom) / (30.0 * float(resolution))


## Every number this box can draw now (tests scan them; they are star numbers, never the reading).
func tick_texts() -> PackedStringArray:
	var out := PackedStringArray()
	if not visible:
		return out
	for v in _visible_values(major):
		if _label_fits(_x(v)):
			out.append(str(v / major))
	return out


## A star's number is drawn only when it fits inside the frame (the dot is drawn either way).
func _label_fits(x: float) -> bool:
	return x - 14.0 >= 4.0 and x + 14.0 <= size.x - 4.0


func _visible_values(step: int) -> Array:
	var out: Array = []
	var ppf := px_per_fen()
	if ppf <= 0.0:
		return out
	var half_fen := int(ceil((size.x * 0.5) / ppf))
	var lo := maxi(0, poise_fen - half_fen)
	var hi := mini(cap_fen, poise_fen + half_fen)
	var v := ((lo + step - 1) / step) * step
	while v <= hi:
		out.append(v)
		v += step
	return out


func _x(v: int) -> float:
	return roundf(size.x * 0.5 + float(v - poise_fen) * px_per_fen())


func _draw() -> void:
	var ink := CardTheme.color(&"text_2")
	var pale := CardTheme.color(&"gold_pale")
	var wood := CardTheme.color(&"gold_deep")
	var gold := CardTheme.color(&"gold_hi")
	var dark := CardTheme.color(&"wood_0")
	draw_rect(Rect2(Vector2.ZERO, size), dark, true)
	draw_rect(Rect2(Vector2(1, 1), size - Vector2(2, 2)), wood, false, 2.0)
	var x0 := maxf(MARGIN, _x(0))
	var x1 := minf(size.x - MARGIN, _x(cap_fen))
	if x1 > x0:
		draw_rect(Rect2(x0, ARM_Y - 5.0, x1 - x0, 10.0), wood, true)
		draw_line(Vector2(x0, ARM_Y - 5.0), Vector2(x1, ARM_Y - 5.0), gold, 1.0)
	for v in _visible_values(minor):
		var x := _x(v)
		if x < MARGIN or x > size.x - MARGIN or v % major == 0:
			continue
		draw_rect(Rect2(x - 1.0, ARM_Y - 1.0, 2.0, 2.0), pale, true)
	var font := CardTheme.font_body()
	for v in _visible_values(major):
		var x := _x(v)
		if x < MARGIN or x > size.x - MARGIN:
			continue
		draw_rect(Rect2(x - 2.0, ARM_Y - 2.0, 4.0, 4.0), pale, true)
		draw_line(Vector2(x, ARM_Y - 6.0), Vector2(x, ARM_Y - 14.0), ink, 1.0)
		if font != null and _label_fits(x):
			var txt := str(v / major)
			draw_string(font, Vector2(x - 24.0, ARM_Y - 20.0), txt, HORIZONTAL_ALIGNMENT_CENTER, 48.0, LABEL_SIZE, pale)
	# The poise cord: a loop round the beam at the centre, the poise hanging below it.
	var cx := size.x * 0.5
	draw_line(Vector2(cx, ARM_Y - 9.0), Vector2(cx, ARM_Y + 26.0), ink, 1.0)
	draw_arc(Vector2(cx, ARM_Y), 7.0, -PI * 0.5, PI * 1.5, 20, ink, 1.0)
	var body := Rect2(cx - 11.0, ARM_Y + 26.0, 22.0, 16.0)
	draw_rect(body, gold, true)
	draw_rect(body, ink, false, 1.0)
