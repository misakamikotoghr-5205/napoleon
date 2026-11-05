# 远洋战役的高清设置（标题、营地顶栏、暂停里的“设置”）：画面压暗，中间一块玻璃面板——圆章、小标题、标题、金线，
# 下面五行（音乐、音效、文字速度、新手提示、快动画），每行左边说明、右边金色滑条或按钮，底下“收起”。
# 只换样子：继承 CardSettings（读写 user://settings.json 和 cards/settings.json、通知 card_settings_listeners、
# 键盘上下 / 左右微调都不变）。宿主按 modal_host.overrides 换上它，按满屏叠层摆（不再进像素右抽屉）。
# 字：行名来自 CardText c16.settings.*；面板标题在 data/hd/hub_ui.json 的 settings.*。没有 class_name。
extends CardSettings

const HdTheme = preload("res://scripts/cards/ui/hd/hd_theme.gd")
const Data = preload("res://scripts/cards/ui/hub/hub_data.gd")
const Kit = preload("res://scripts/cards/ui/hub/hub_kit.gd")
const W = preload("res://scripts/cards/ui/battle/hud/hud_widgets.gd")

const BOX := Rect2(340, 104, 600, 512)
const BODY_PAD := 36.0
const HEAD_H := 96.0

## 宿主按登记的 kind 设
var kind: StringName = &"settings"


func open(args: Dictionary) -> void:
	HdTheme.apply_hd_filter(self)
	super.open(args)
	# 叠层：根吃鼠标（点外面不落到背后的营地上）
	mouse_filter = Control.MOUSE_FILTER_STOP


func _build() -> void:
	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.color = HdTheme.alpha("hd_ink", 0.6)
	dim.size = Vector2(1280, 720)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	var frame := Panel.new()
	frame.name = "Frame"
	frame.position = BOX.position
	frame.size = BOX.size
	frame.mouse_filter = Control.MOUSE_FILTER_STOP
	frame.add_theme_stylebox_override(&"panel", HdTheme.panel_box("glass_strong"))
	add_child(frame)
	var head := HBoxContainer.new()
	head.position = Vector2(BOX.position.x + BODY_PAD, BOX.position.y + 24.0)
	head.add_theme_constant_override(&"separation", 14)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(head)
	head.add_child(Kit.medal("hub_settings", Data.text("settings.icon"), 50))
	var titles := VBoxContainer.new()
	titles.add_theme_constant_override(&"separation", 0)
	titles.alignment = BoxContainer.ALIGNMENT_CENTER
	titles.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(titles)
	var kicker := Kit.label(Data.text("settings.kicker"), 13, "sans_bold", "hd_gold")
	kicker.add_theme_font_override(&"font", HdTheme.font("sans_bold", 3))
	titles.add_child(kicker)
	titles.add_child(Kit.label(Data.text("settings.heading"), 27, "title", "hd_text"))
	var rule := W.Rule.new()
	rule.position = Vector2(BOX.position.x + BODY_PAD, BOX.position.y + HEAD_H - 6.0)
	rule.size = Vector2(BOX.size.x - BODY_PAD * 2.0, 12)
	add_child(rule)
	var box := Control.new()
	box.name = "Body"
	box.position = Vector2(BOX.position.x + BODY_PAD, BOX.position.y + HEAD_H + 14.0)
	box.size = Vector2(BOX.size.x - BODY_PAD * 2.0, BOX.size.y - HEAD_H - 40.0)
	box.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(box)
	var y := 0.0
	_music = _slider_row(box, "c16.settings.music", y, int(_bag.music), _on_music)
	y += ROW_H
	_sfx = _slider_row(box, "c16.settings.sfx", y, int(_bag.sfx), _on_sfx)
	y += ROW_H
	_speed_row(box, y)
	y += ROW_H
	_guide_btn = _toggle_row(box, "c16.settings.guide_hints", y, bool(_bag.guide_hints), _on_guide)
	CardAnchors.register(&"a.settings.guide_toggle", _guide_btn)
	y += ROW_H
	_fast_btn = _toggle_row(box, "c16.settings.fast_anim", y, _fast, _on_fast)
	y += ROW_H + 18.0
	var close := Button.new()
	close.name = "Back"
	close.text = Data.text("settings.close")
	close.focus_mode = Control.FOCUS_ALL
	HdTheme.apply_button(close, "secondary")
	close.custom_minimum_size = Vector2(160, 42)
	close.pressed.connect(func() -> void: autoplay_step())
	box.add_child(close)
	close.reset_size()
	close.position = Vector2(floorf((box.size.x - close.size.x) * 0.5), y)
	_focus.append(close)
	_dress(box)
	_paint_speed()
	_grab_first()


## 父类搭好的行：说明字、读数、细线、滑条、开关按钮换成高清样子
func _dress(box: Control) -> void:
	for c in box.get_children():
		if c is Label:
			var l := c as Label
			var is_value := str(l.name).ends_with(".value")
			l.add_theme_font_override(&"font", HdTheme.font("num" if is_value else "serif"))
			l.add_theme_font_size_override(&"font_size", 16 if is_value else 18)
			l.add_theme_color_override(&"font_color", HdTheme.color("hd_gold_hi" if is_value else "hd_text"))
		elif c is ColorRect:
			(c as ColorRect).color = HdTheme.alpha("hd_gold", 0.18)
		elif c is HSlider:
			_dress_slider(c as HSlider)
		elif c is Button and c != _focus.back() and not c.has_meta("speed"):
			_dress_toggle(c as Button)


func _dress_slider(s: HSlider) -> void:
	var track := StyleBoxFlat.new()
	track.anti_aliasing = true
	track.bg_color = HdTheme.alpha("hd_ink", 0.9)
	track.border_color = HdTheme.alpha("hd_gold", 0.35)
	track.set_border_width_all(1)
	track.set_corner_radius_all(4)
	track.content_margin_top = 3
	track.content_margin_bottom = 3
	var fill := StyleBoxFlat.new()
	fill.anti_aliasing = true
	fill.bg_color = HdTheme.color("hd_gold")
	fill.set_corner_radius_all(4)
	fill.content_margin_top = 3
	fill.content_margin_bottom = 3
	var fill_hi := fill.duplicate() as StyleBoxFlat
	fill_hi.bg_color = HdTheme.color("hd_gold_hi")
	s.add_theme_stylebox_override(&"slider", track)
	s.add_theme_stylebox_override(&"grabber_area", fill)
	s.add_theme_stylebox_override(&"grabber_area_highlight", fill_hi)
	s.add_theme_icon_override(&"grabber", _knob(false))
	s.add_theme_icon_override(&"grabber_highlight", _knob(true))
	s.add_theme_stylebox_override(&"focus", _focus_ring())
	s.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


func _dress_toggle(b: Button) -> void:
	var on := b.text == CardText.ui("c16.settings.on")
	HdTheme.apply_button(b, "primary" if on else "secondary")
	b.add_theme_font_size_override(&"font_size", 15)
	b.add_theme_font_override(&"font", HdTheme.font("sans_bold" if on else "sans"))
	b.custom_minimum_size = Vector2(84, 34)
	b.reset_size()
	b.size = Vector2(maxf(b.size.x, 84.0), 34)
	b.position.x = (b.get_parent() as Control).size.x - b.size.x
	b.position.y = floorf(b.position.y / ROW_H) * ROW_H + floorf((ROW_H - 34.0) * 0.5)


## 文字速度四档：当前那档金色
func _paint_speed() -> void:
	var cur := int(_bag.text_speed)
	for c in _focus:
		if c is Button and c.has_meta("speed"):
			var b := c as Button
			var on := int(b.get_meta("speed")) == cur
			HdTheme.apply_button(b, "primary" if on else "secondary")
			b.add_theme_font_size_override(&"font_size", 14)
			b.add_theme_font_override(&"font", HdTheme.font("sans_bold" if on else "sans"))
			b.custom_minimum_size = Vector2(48, 32)
	_layout_speed()


## 四档按钮换了样子以后宽度会变：从右往左重新排一遍
func _layout_speed() -> void:
	var row: Array[Button] = []
	for c in _focus:
		if c is Button and c.has_meta("speed"):
			row.append(c as Button)
	if row.is_empty():
		return
	var parent := row[0].get_parent() as Control
	if parent == null:
		return
	var x := parent.size.x
	for i in range(row.size() - 1, -1, -1):
		var b := row[i]
		b.reset_size()
		b.size = Vector2(maxf(b.size.x, 48.0), 32)
		x -= b.size.x
		b.position = Vector2(x, floorf(b.position.y / ROW_H) * ROW_H + floorf((ROW_H - 32.0) * 0.5))
		x -= 6.0


func _on_guide() -> void:
	super._on_guide()
	_dress_toggle(_guide_btn)


func _on_fast() -> void:
	super._on_fast()
	_dress_toggle(_fast_btn)


func _knob(hi: bool) -> Texture2D:
	var img := Image.create(20, 20, false, Image.FORMAT_RGBA8)
	var c := HdTheme.color("hd_gold_hi" if hi else "hd_gold")
	var rim := HdTheme.color("hd_ink")
	for y in 20:
		for x in 20:
			var d := Vector2(x + 0.5 - 10.0, y + 0.5 - 10.0).length()
			var a := clampf(9.5 - d, 0.0, 1.0)
			var col := c if d < 7.5 else rim.lerp(c, clampf(8.5 - d, 0.0, 1.0))
			col.a = a
			img.set_pixel(x, y, col)
	return ImageTexture.create_from_image(img)


func _focus_ring() -> StyleBoxFlat:
	var f := StyleBoxFlat.new()
	f.draw_center = false
	f.anti_aliasing = true
	f.border_color = HdTheme.alpha("hd_gold_hi", 0.7)
	f.set_border_width_all(1)
	f.set_corner_radius_all(6)
	f.set_expand_margin_all(4.0)
	return f
