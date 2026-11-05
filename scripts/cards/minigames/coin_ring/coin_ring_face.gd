# 吹银元面板上的一枚银元：纸垫底、整数倍的银元图、鼠标移上去或键盘的“手”在它上面时一圈金线（玩家的笔）、
# 哑板样洋拴一道红线（铺子的记号，不是对错色）、一摞里的第几枚用小圆点标。点它 = 捏住吹一下（由游戏接 gui_input）。
# 吹的时候捏一下、颤一下（Tween，单段 ≤ 0.6 秒，快动画跳过）。只用配色键，不写字。主人 C13。
extends Control

const PAD := 6.0

var thread: bool = false
var pips: int = 0
var hover: bool = false
## 键盘的“手”在这枚上（和鼠标停住一样画金线，稍粗一点；吹次用完也画，好标响 / 哑）。
var cursor: bool = false
var live: bool = true

var _art: TextureRect
var _over: Control
var _art_px := Vector2.ZERO
var _tween: Tween


func setup(tex: Texture2D, art_px: Vector2i, p_thread: bool, p_pips: int) -> void:
	thread = p_thread
	pips = p_pips
	_art_px = Vector2(art_px)
	size = _art_px + Vector2(PAD, PAD) * 2.0
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_art = TextureRect.new()
	_art.name = "Art"
	_art.texture = tex
	_art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art.stretch_mode = TextureRect.STRETCH_SCALE
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_art.position = Vector2(PAD, PAD)
	_art.size = _art_px
	add_child(_art)
	_over = Control.new()
	_over.name = "Over"
	_over.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_over.size = size
	_over.draw.connect(_draw_over)
	add_child(_over)
	mouse_entered.connect(set_hover.bind(true))
	mouse_exited.connect(set_hover.bind(false))


func art() -> TextureRect:
	return _art


func set_live(on: bool) -> void:
	live = on
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if on else Control.CURSOR_ARROW
	modulate = Color.WHITE if on else Color(1, 1, 1, 0.6)
	if _over != null:
		_over.queue_redraw()


## 捏一下（往下按一点再回来）、颤几下。fast 时什么都不动。
func pinch(fast: bool) -> void:
	if _art == null or fast or not is_inside_tree():
		return
	if _tween != null and is_instance_valid(_tween):
		_tween.kill()
	_art.position = Vector2(PAD, PAD)
	_art.size = _art_px
	# Pressed down a few pixels and back (the pinch), then a small shake; position only, so the art keeps its
	# integer scale the whole time.
	_tween = create_tween()
	_tween.tween_property(_art, "position", Vector2(PAD, PAD + 4.0), 0.12)
	_tween.tween_property(_art, "position", Vector2(PAD, PAD), 0.13)
	for k in range(4):
		var dx := 2.0 if k % 2 == 0 else -2.0
		_tween.tween_property(_art, "position", Vector2(PAD + dx, PAD), 0.05)
	_tween.tween_property(_art, "position", Vector2(PAD, PAD), 0.05)


func set_hover(on: bool) -> void:
	hover = on
	if _over != null:
		_over.queue_redraw()


func set_cursor(on: bool) -> void:
	if cursor == on:
		return
	cursor = on
	if _over != null:
		_over.queue_redraw()


func _draw() -> void:
	draw_style_box(_well(), Rect2(Vector2.ZERO, size))


func _well() -> StyleBox:
	var sb := CardTheme.flat_style(&"paper", &"umber", 3, 4)
	sb.shadow_color = CardTheme.with_alpha(&"card_shadow", 0.35)
	sb.shadow_size = 4
	sb.shadow_offset = Vector2(0, 2)
	return sb


func _draw_over() -> void:
	var c := size * 0.5
	var r := _art_px.x * 0.5
	if thread:
		var red := CardTheme.color(&"seal")
		_over.draw_arc(c, r * 0.86, -0.25, PI * 1.75, 40, red, 3.0)
		var knot := c + Vector2(cos(-0.25), sin(-0.25)) * r * 0.86
		_over.draw_line(knot, knot + Vector2(10, -12), red, 3.0)
		_over.draw_line(knot, knot + Vector2(14, -2), red, 3.0)
	if pips > 0:
		for k in range(pips):
			_over.draw_circle(Vector2(PAD + 8.0 + float(k) * 9.0, PAD + 8.0), 3.0, CardTheme.color(&"umber"))
	if (hover and live) or cursor:
		_over.draw_arc(c, r * 0.98, 0.0, TAU, 56, CardTheme.color(&"gold_hi"), 3.0 if cursor else 2.0)
