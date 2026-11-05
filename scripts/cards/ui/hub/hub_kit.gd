## 远洋营地（高清）的小件，用的地方 preload 这个文件：
##   Kit.card_button(name, tone)  能点的卡片：玻璃底、金边，悬停金色外发光；tone = gold | red | plain
##   Kit.pill(text, fill_key, ink_key) 小药丸标签
##   Kit.medal(id, glyph, side)  圆章（有头像图用图，没有画占位圆章，中间一个字）
##   Shade        背景上的压暗：上下暗带、左右压暗、暗角
##   Floater      数值变化时从数字上飘起来的 +N / −N
## 只画，颜色走 hd_* 配色键，字由调用方从 hub_ui.json 取好传进来。没有 class_name。
extends RefCounted

const HdTheme = preload("res://scripts/cards/ui/hd/hd_theme.gd")
const HdPlaceholder = preload("res://scripts/cards/ui/hd/hd_placeholder.gd")
const D = preload("res://scripts/cards/ui/hd/hd_draw.gd")

const CARD_SPECS := {
	"plain": {
		"normal": {"fill": ["hd_navy", 0.84], "edge": ["hd_gold", 0.42], "bw": 1, "r": 8, "inner": ["hd_gold", 0.14],
			"inset": 4, "sheen": 0.035, "shadow": [0.45, 14, 5], "pad": [14, 10]},
		"hover": {"fill": ["hd_navy_3", 0.92], "edge": ["hd_gold_hi", 1.0], "bw": 1, "r": 8, "inner": ["hd_gold_hi", 0.3],
			"inset": 4, "sheen": 0.06, "glow": ["hd_gold", 0.34, 14], "pad": [14, 10]},
		"pressed": {"fill": ["hd_navy_2", 0.95], "edge": ["hd_gold", 0.9], "bw": 1, "r": 8, "inner": ["hd_gold", 0.2],
			"inset": 4, "pad": [14, 10], "down": 1},
		"disabled": {"fill": ["hd_navy", 0.7], "edge": ["hd_gold", 0.16], "bw": 1, "r": 8, "pad": [14, 10]},
	},
	"gold": {
		"normal": {"fill": ["hd_navy_2", 0.9], "edge": ["hd_gold", 0.85], "bw": 1, "r": 10, "inner": ["hd_gold_hi", 0.3],
			"inset": 5, "sheen": 0.05, "shadow": [0.5, 20, 6], "pad": [18, 14]},
		"hover": {"fill": ["hd_navy_3", 0.95], "edge": ["hd_gold_hi", 1.0], "bw": 2, "r": 10, "inner": ["hd_gold_hi", 0.45],
			"inset": 5, "sheen": 0.07, "glow": ["hd_gold", 0.45, 18], "pad": [18, 14]},
		"pressed": {"fill": ["hd_navy_2", 0.96], "edge": ["hd_gold", 1.0], "bw": 1, "r": 10, "inner": ["hd_gold", 0.3],
			"inset": 5, "pad": [18, 14], "down": 1},
		"disabled": {"fill": ["hd_navy", 0.7], "edge": ["hd_gold", 0.25], "bw": 1, "r": 10, "pad": [18, 14]},
	},
	"red": {
		"normal": {"fill": ["hd_wax", 0.55, "hd_ink", 0.55], "edge": ["hd_enemy_hi", 0.85], "bw": 1, "r": 10,
			"inner": ["hd_gold", 0.3], "inset": 5, "sheen": 0.05, "glow": ["hd_enemy", 0.35, 16], "pad": [18, 14]},
		"hover": {"fill": ["hd_wax", 0.7, "hd_ink", 0.4], "edge": ["hd_gold_hi", 1.0], "bw": 2, "r": 10,
			"inner": ["hd_gold_hi", 0.4], "inset": 5, "sheen": 0.07, "glow": ["hd_enemy_hi", 0.5, 20], "pad": [18, 14]},
		"pressed": {"fill": ["hd_wax", 0.8, "hd_ink", 0.4], "edge": ["hd_enemy_hi", 1.0], "bw": 1, "r": 10,
			"pad": [18, 14], "down": 1},
		"disabled": {"fill": ["hd_wax", 0.3, "hd_ink", 0.6], "edge": ["hd_enemy", 0.3], "bw": 1, "r": 10, "pad": [18, 14]},
	},
}


## 能点的卡片：Button 本身不写字（字是放在上面的标签，都不接鼠标），五态框按 tone
static func card_button(node_name: String, tone: String = "plain") -> Button:
	var b := Button.new()
	b.name = node_name
	var spec: Dictionary = CARD_SPECS.get(tone, CARD_SPECS["plain"])
	b.add_theme_stylebox_override(&"normal", HdTheme.box(spec["normal"]))
	b.add_theme_stylebox_override(&"hover", HdTheme.box(spec["hover"]))
	b.add_theme_stylebox_override(&"pressed", HdTheme.box(spec["pressed"]))
	b.add_theme_stylebox_override(&"hover_pressed", HdTheme.box(spec["pressed"]))
	b.add_theme_stylebox_override(&"disabled", HdTheme.box(spec["disabled"]))
	var focus := StyleBoxFlat.new()
	focus.draw_center = false
	focus.anti_aliasing = true
	focus.border_color = HdTheme.alpha("hd_gold_hi", 0.7)
	focus.set_border_width_all(1)
	focus.set_corner_radius_all(12)
	focus.set_expand_margin_all(3.0)
	b.add_theme_stylebox_override(&"focus", focus)
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.clip_contents = false
	return b


## 小药丸标签
static func pill(text: String, fill_key: String, ink_key: String = "hd_text", font_size: int = 12, fill_a: float = 0.9,
		edge_key: String = "hd_gold", edge_a: float = 0.4) -> PanelContainer:
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.anti_aliasing = true
	sb.bg_color = HdTheme.alpha(fill_key, fill_a)
	sb.border_color = HdTheme.alpha(edge_key, edge_a)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 9
	sb.content_margin_right = 9
	sb.content_margin_top = 2
	sb.content_margin_bottom = 2
	p.add_theme_stylebox_override(&"panel", sb)
	var l := HdTheme.make_label(text, font_size, "sans_bold", ink_key)
	l.name = "Text"
	p.add_child(l)
	return p


## 圆章：art/hd/face/<id>.png 有图用图，没有画占位圆章（中间是 glyph 的第一个字）
static func medal(id: String, glyph: String, side: float) -> Control:
	var m := HdPlaceholder.make_face(id, glyph)
	m.custom_minimum_size = Vector2(side, side)
	m.size = Vector2(side, side)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return m


static func label(text: String, font_size: int, kind: String = "sans", color_key: String = "hd_text") -> Label:
	return HdTheme.make_label(text, font_size, kind, color_key)


static func wrap(text: String, font_size: int, kind: String = "sans", color_key: String = "hd_text_2") -> Label:
	var l := HdTheme.make_label(text, font_size, kind, color_key)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(1, 0)
	return l


static func clear(node: Node) -> void:
	for c in node.get_children():
		node.remove_child(c)
		c.queue_free()


# ================================================================ 背景压暗

class Shade extends Control:
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		if r.size.x < 2.0:
			return
		D.vgrad(self, r, [[0.0, HdTheme.alpha("hd_ink", 0.78)], [0.16, HdTheme.alpha("hd_ink", 0.38)],
			[0.6, HdTheme.alpha("hd_ink", 0.32)], [1.0, HdTheme.alpha("hd_ink", 0.82)]])
		# 左右两侧再压一点，栏位下面的图不抢眼
		var w := r.size.x * 0.3
		var left := PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, r.size.y), Vector2(0, r.size.y)])
		var lc := PackedColorArray([HdTheme.alpha("hd_ink", 0.55), HdTheme.alpha("hd_ink", 0.0),
			HdTheme.alpha("hd_ink", 0.0), HdTheme.alpha("hd_ink", 0.55)])
		draw_polygon(left, lc)
		var x1 := r.size.x - w
		var right := PackedVector2Array([Vector2(x1, 0), Vector2(r.size.x, 0), Vector2(r.size.x, r.size.y), Vector2(x1, r.size.y)])
		var rc := PackedColorArray([HdTheme.alpha("hd_ink", 0.0), HdTheme.alpha("hd_ink", 0.55),
			HdTheme.alpha("hd_ink", 0.55), HdTheme.alpha("hd_ink", 0.0)])
		draw_polygon(right, rc)
		D.vignette(self, r, 0.5)


# ================================================================ 飘字

class Floater extends Label:
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	## at：数字中心；up：往上飘多少
	func play(at: Vector2, up: float = 26.0, fast: bool = false) -> void:
		reset_size()
		position = at - Vector2(size.x * 0.5, size.y * 0.5)
		if fast:
			queue_free()
			return
		modulate.a = 0.0
		var tw := create_tween()
		tw.set_parallel(true)
		tw.tween_property(self, "modulate:a", 1.0, 0.18)
		tw.tween_property(self, "position:y", position.y - up, 1.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.chain().tween_property(self, "modulate:a", 0.0, 0.45)
		tw.chain().tween_callback(queue_free)
