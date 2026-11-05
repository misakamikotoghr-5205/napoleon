# Notice strip near the top of the counter and the money float under the HUD (reskin SPEC 10.8).
# Owner C01. No class_name: const ToastScript = preload("res://scripts/cards/ui/table/toast.gd").
# Never takes the mouse. The strip stays HOLD_S seconds and then fades; the wait is a Timer child
# (freed with this node) and only hides a message, it never moves the game on (contract red line 9).
extends Control

const STRIP_Y := 130.0
const HOLD_S := 2.2
const FADE_S := 0.3
const FLOAT_S := 0.6
const FLOAT_DY := 40.0

## Fast animations: the strip shows and hides without fading, and the money float is skipped.
var fast: bool = false

var _strip: PanelContainer = null
var _label: Label = null
var _timer: Timer = null
var _fade: Tween = null
var _box_ok: StyleBoxFlat = null
var _box_bad: StyleBoxFlat = null


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(1280, 720)


## Show one line in the strip; bad = red edge and pale red ink (heat up, money short, nothing done).
func show_text(text: String, bad: bool = false) -> void:
	_build()
	_label.text = text
	_label.add_theme_color_override("font_color", CardTheme.color(&"flash_bad_ink" if bad else &"gold_pale"))
	_strip.add_theme_stylebox_override("panel", _box_bad if bad else _box_ok)
	_strip.visible = true
	_strip.reset_size()
	_strip.position = Vector2(floorf((size.x - _strip.size.x) * 0.5), STRIP_Y)
	if _fade != null and _fade.is_valid():
		_fade.kill()
	_strip.modulate.a = 1.0
	_timer.start(HOLD_S)


func is_showing() -> bool:
	return _strip != null and _strip.visible


func text() -> String:
	return _label.text if _label != null and _strip.visible else ""


## "+N" / "-N" under the HUD money (rect = the money slot on screen). Skipped with fast animations.
func money(delta: int, unit: String, at: Rect2) -> void:
	if delta == 0 or fast or not is_inside_tree():
		return
	var key := "c01.toast.money.up" if delta > 0 else "c01.toast.money.down"
	var label := Label.new()
	label.name = "MoneyFloat"
	label.text = CardText.ui(key, {"n": absi(delta), "unit": unit})
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", CardTheme.font_body_bold())
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", CardTheme.color(&"money_up" if delta > 0 else &"money_down"))
	label.add_theme_color_override("font_shadow_color", CardTheme.color(&"scene_void"))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	add_child(label)
	label.position = Vector2(at.position.x + 20.0, at.end.y)
	var tw := label.create_tween().set_parallel(true)
	tw.tween_property(label, "position:y", label.position.y + FLOAT_DY, FLOAT_S)
	tw.tween_property(label, "modulate:a", 0.0, FLOAT_S).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(label.queue_free)


func _build() -> void:
	if _strip != null:
		return
	_box_ok = _strip_box(&"flash_edge")
	_box_bad = _strip_box(&"flash_bad_edge")
	_strip = PanelContainer.new()
	_strip.name = "Strip"
	_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_strip.visible = false
	add_child(_strip)
	_label = Label.new()
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.add_theme_font_override("font", CardTheme.font_body())
	_label.add_theme_font_size_override("font_size", 16)
	_strip.add_child(_label)
	_timer = Timer.new()
	_timer.one_shot = true
	_timer.timeout.connect(_on_hold_done)
	add_child(_timer)


func _strip_box(edge: StringName) -> StyleBoxFlat:
	var sb := CardTheme.flat_style(&"flash_bg", edge, 2, 6, 16.0, 8.0)
	sb.shadow_color = CardTheme.with_alpha(&"scene_void", 0.6)
	sb.shadow_size = 20
	sb.shadow_offset = Vector2(0, 8)
	return sb


func _on_hold_done() -> void:
	if _strip == null or not _strip.visible:
		return
	if fast or not is_inside_tree():
		_strip.visible = false
		return
	_fade = create_tween()
	_fade.tween_property(_strip, "modulate:a", 0.0, FADE_S)
	_fade.tween_callback(_strip.hide)
