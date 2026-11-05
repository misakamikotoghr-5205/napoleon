# 补齐盖章。正式图走 CardArt 的 icon.seal；清单里还没有这张图时用配色画一枚圆章。
# 主人 C10。合同：docs/cards/CARDS_INTERFACES.md §3.3 C10。缺的美术 id：icon.seal（[content]）。
extends Control


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func _draw() -> void:
	if not CardArt.is_placeholder("icon.seal"):
		var tex := CardArt.texture("icon.seal")
		if tex != null:
			draw_texture_rect(tex, Rect2(Vector2.ZERO, size), false)
			return
	var c := size * 0.5
	var rad := minf(size.x, size.y) * 0.46
	draw_circle(c, rad, CardTheme.color(&"seal"))
	draw_arc(c, rad * 0.62, 0.0, TAU, 28, CardTheme.color(&"gold"), 2.0)
	draw_arc(c, rad * 0.84, 0.0, TAU, 28, CardTheme.color(&"gold_glow"), 1.5)
