# 渐变圆角块（换皮 SPEC §4.2）：竖向或径向渐变 + 边框 + 可选内亮边，上下角可以不同半径（拱顶）。
# 颜色全由代码从 CardTheme 传进着色器（着色器里没有颜色值）。没有 class_name：
#   const GradBox = preload("res://scripts/cards/ui/common/grad_box.gd")
#   var g = GradBox.new(); g.set_colors(&"card_face_top", &"card_face_bot"); g.set_border(3, &"frame_person")
# 或者直接用 CardTheme.grad_box(...) 拿一个配好的。外影、外圈光仍用 StyleBoxFlat 的 shadow_* 画在下面一层。
# 主人 C01。
extends Control

const SHADER := preload("res://scripts/cards/ui/common/grad_box.gdshader")
const VERTICAL := 0
const RADIAL := 1

var _mat: ShaderMaterial


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	material = _mat
	resized.connect(_on_resized)
	set_radius(6.0)
	set_border(0.0, &"")


## Fill colours by palette key; mid empty = halfway between top and bottom.
func set_colors(top: StringName, bot: StringName, mid: StringName = &"", mid_stop: float = 0.55) -> void:
	var c_top := CardTheme.color(top)
	var c_bot := CardTheme.color(bot)
	var c_mid := CardTheme.color(mid) if mid != &"" else c_top.lerp(c_bot, 0.5)
	set_color_values(c_top, c_mid, c_bot, mid_stop if mid != &"" else 0.5)


## Fill colours as values (already read from CardTheme, e.g. with a changed alpha).
func set_color_values(top: Color, mid: Color, bot: Color, mid_stop: float = 0.55) -> void:
	_mat.set_shader_parameter(&"color_top", top)
	_mat.set_shader_parameter(&"color_mid", mid)
	_mat.set_shader_parameter(&"color_bot", bot)
	_mat.set_shader_parameter(&"mid_stop", mid_stop)


## Border width in screen pixels and its palette key (px 0 or key empty = no border).
func set_border(px: float, key: StringName) -> void:
	if px <= 0.0 or key == &"":
		_mat.set_shader_parameter(&"border_px", 0.0)
		return
	set_border_value(px, CardTheme.color(key))


## Border width and colour value.
func set_border_value(px: float, c: Color) -> void:
	_mat.set_shader_parameter(&"border_px", px)
	_mat.set_shader_parameter(&"border_color", c)


## Corner radii; top/bottom < 0 take `all` (radius_top = width / 2 gives an arch).
func set_radius(all: float, top: float = -1.0, bottom: float = -1.0) -> void:
	_mat.set_shader_parameter(&"radius_top_px", top if top >= 0.0 else all)
	_mat.set_shader_parameter(&"radius_bottom_px", bottom if bottom >= 0.0 else all)


## VERTICAL or RADIAL; center is in 0..1 of the box (radial only).
func set_mode(m: int, center: Vector2 = Vector2(0.5, 0.35)) -> void:
	_mat.set_shader_parameter(&"mode", m)
	_mat.set_shader_parameter(&"center", center)


## Inner bright ring just inside the border (cards: 2 px card_hilite). px 0 = none.
func set_inner(px: float, c: Color) -> void:
	_mat.set_shader_parameter(&"inner_px", px)
	_mat.set_shader_parameter(&"inner_color", c)


## Sides pushed off the box (no border, square corners there): drawers and tabs against the screen edge.
func set_open_sides(left: bool, top: bool, right: bool, bottom: bool) -> void:
	_mat.set_shader_parameter(&"open_sides", Vector4(float(left), float(top), float(right), float(bottom)))


func _ready() -> void:
	_on_resized()


func _on_resized() -> void:
	_mat.set_shader_parameter(&"size_px", size)
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color.WHITE)
