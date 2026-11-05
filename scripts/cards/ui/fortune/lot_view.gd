# Lot draw: shake the tube, then show the slip. No class_name (not in the frozen class list).
# The panel sends fortune.lot; this view only animates and displays CardText.
# Shake offsets come from a fixed-seed generator and never change the result.
# Owner C07.
extends Control

const Style = preload("res://scripts/cards/ui/fortune/fortune_style.gd")

var _playing := false
var _settled := true
var _done := Callable()
var _tw: Tween
var _tube := Vector2(8, 48)
var _slip := false
var _dx: Array[float] = []
var _verse: Label
var _gloss: Label
var _grade: Label


func _init() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(730, 280)
	custom_minimum_size = size
	_build_shake()
	_verse = Style.label("", 18, true)
	_gloss = Style.label("", 16, true)
	_grade = Style.label("", 18, true)
	_verse.position = Vector2(120, 16)
	_verse.size = Vector2(590, 96)
	_gloss.position = Vector2(120, 116)
	_gloss.size = Vector2(590, 96)
	_grade.position = Vector2(120, 220)
	_grade.size = Vector2(590, 36)
	add_child(_verse)
	add_child(_gloss)
	add_child(_grade)


func play(done: Callable) -> void:
	_done = done
	_settled = false
	_playing = true
	_slip = false
	_clear_poem()
	_tube = Vector2(8, 48)
	queue_redraw()
	if not is_inside_tree():
		_finish()
		return
	_tw = create_tween()
	_tw.tween_method(_step, 0.0, 1.0, 0.55)
	_tw.finished.connect(_finish, CONNECT_ONE_SHOT)


func skip() -> void:
	if _settled:
		return
	_kill()
	_finish()


func halt() -> void:
	_settled = true
	_playing = false
	_done = Callable()
	_kill()


func show_poem(lot: String, grade: int) -> void:
	_slip = true
	_tube = Vector2(8, 48)
	var verse := CardText.card(lot, "verse")
	var gloss := CardText.card(lot, "gloss")
	Style.set_label(_verse, verse, 18, CardText.is_draft(lot + "#verse"))
	Style.set_label(_gloss, gloss, 16, CardText.is_draft(lot + "#gloss"))
	var gtxt := ""
	if grade >= 0 and grade <= 4:
		var key := "c07.grade.%d" % grade
		gtxt = CardText.ui(key)
		Style.set_label(_grade, gtxt, 18, CardText.is_draft(key))
	else:
		Style.set_label(_grade, "", 18, true)
	_grade.visible = gtxt != ""
	queue_redraw()


func _build_shake() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 707
	_dx.clear()
	for _i in 8:
		_dx.append(rng.randf_range(-6.0, 6.0))


func _step(t: float) -> void:
	if _dx.is_empty():
		return
	var i := mini(_dx.size() - 1, int(t * float(_dx.size())))
	_tube = Vector2(8.0 + _dx[i], 48.0)
	queue_redraw()


func _finish() -> void:
	if _settled:
		return
	_settled = true
	_playing = false
	_tube = Vector2(8, 48)
	queue_redraw()
	var cb := _done
	_done = Callable()
	if cb.is_valid():
		cb.call()


func _kill() -> void:
	if _tw != null and is_instance_valid(_tw):
		_tw.kill()
	_tw = null


func _clear_poem() -> void:
	Style.set_label(_verse, "", 18, true)
	Style.set_label(_gloss, "", 16, true)
	Style.set_label(_grade, "", 18, true)
	_grade.visible = false


func _draw() -> void:
	var tube := Rect2(_tube, Vector2(72, 120))
	_paint(Style.ART_TUBE, tube, &"wood", &"paper_old")
	if _slip:
		var slip := Rect2(_tube + Vector2(16, -28), Vector2(40, 96))
		_paint(Style.ART_SLIP, slip, &"paper", &"paper")


func _paint(art_id: String, rect: Rect2, outer: StringName, inner: StringName) -> void:
	var tex := CardArt.texture(art_id)
	if tex != null:
		draw_texture_rect(tex, rect, false)
		return
	draw_rect(rect, CardTheme.color(outer))
	draw_rect(rect.grow(-6.0), CardTheme.color(inner))
