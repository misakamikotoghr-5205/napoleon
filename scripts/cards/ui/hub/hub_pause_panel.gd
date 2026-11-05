# 远洋战役的高清暂停菜单（营地上的“菜单”、Esc）：营地压暗，中间一块玻璃面板——圆章、小标题、标题、金线，
# 金色主按钮“回到营地”，存档说明，设置 / 经营须知 / 回到标题 / 离开游戏；离开和回标题先问一句。
# 只换样子：继承 CardPause（close_requested 的 next / to_title / quit、键盘绕圈、先问一句都不变），
# “帮助”开的 help 在远洋战役里是高清的经营须知。字在 data/hd/hub_ui.json 的 pause.*，没写的退回 c16.pause.*。
# 宿主按 modal_host.overrides 换上它（kind 仍是 pause）。没有 class_name。
extends CardPause

const HdTheme = preload("res://scripts/cards/ui/hd/hd_theme.gd")
const Data = preload("res://scripts/cards/ui/hub/hub_data.gd")
const Kit = preload("res://scripts/cards/ui/hub/hub_kit.gd")
const W = preload("res://scripts/cards/ui/battle/hud/hud_widgets.gd")

const HD_BOX_W := 460.0
const HD_BUTTON := Vector2(320, 46)

## 宿主按登记的 kind 设
var kind: StringName = KIND


func open(args: Dictionary) -> void:
	HdTheme.apply_hd_filter(self)
	super.open(args)


func _build() -> void:
	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.color = HdTheme.alpha("hd_ink", 0.55)
	dim.size = Vector2(1280, 720)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	_box = PanelContainer.new()
	_box.name = "Box"
	var sb := HdTheme.panel_box("glass_strong")
	sb.content_margin_left = 34
	sb.content_margin_right = 34
	sb.content_margin_top = 26
	sb.content_margin_bottom = 28
	_box.add_theme_stylebox_override(&"panel", sb)
	add_child(_box)
	_fill_menu()


## 一列：圆章 + 小标题 + 标题，金线；按钮和说明由父类往里排
func _column() -> VBoxContainer:
	for c in _box.get_children():
		_box.remove_child(c)
		c.queue_free()
	_buttons = []
	var col := VBoxContainer.new()
	col.name = "Column"
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override(&"separation", 10)
	_box.add_child(col)
	var head := HBoxContainer.new()
	head.add_theme_constant_override(&"separation", 14)
	head.alignment = BoxContainer.ALIGNMENT_CENTER
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(head)
	head.add_child(Kit.medal("hub_pause", Data.text("pause.icon"), 50))
	var titles := VBoxContainer.new()
	titles.add_theme_constant_override(&"separation", 0)
	titles.alignment = BoxContainer.ALIGNMENT_CENTER
	titles.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(titles)
	var kicker := Kit.label(Data.text("pause.kicker"), 13, "sans_bold", "hd_gold")
	kicker.add_theme_font_override(&"font", HdTheme.font("sans_bold", 3))
	titles.add_child(kicker)
	var heading := Kit.label(_text("heading"), 28, "title", "hd_text")
	heading.name = "Heading"
	titles.add_child(heading)
	var rule := W.Rule.new()
	rule.custom_minimum_size = Vector2(HD_BOX_W - 68.0, 12)
	col.add_child(rule)
	return col


func _make_button(key: String, variation: StringName) -> Button:
	var btn := Button.new()
	btn.name = key
	btn.text = _text(key)
	btn.focus_mode = Control.FOCUS_ALL
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var look := "primary" if variation == &"PrimaryButton" else ("danger" if variation == &"WarnButton" else "secondary")
	HdTheme.apply_button(btn, look)
	btn.custom_minimum_size = Vector2(HD_BUTTON.x, 52.0 if look == "primary" else HD_BUTTON.y)
	if look == "primary":
		btn.add_theme_font_size_override(&"font_size", 21)
	_buttons.append(btn)
	return btn


## 父类排好以后：说明字换成高清字，再按父类的办法摆到正中
func _finish() -> void:
	for name_key in ["SaveNote", "Confirm"]:
		var note := _box.find_child(name_key, true, false) as Label
		if note == null:
			continue
		note.theme_type_variation = &""
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		note.add_theme_font_override(&"font", HdTheme.font("serif" if name_key == "Confirm" else "sans"))
		note.add_theme_font_size_override(&"font_size", 17 if name_key == "Confirm" else 13)
		note.add_theme_color_override(&"font_color", HdTheme.color("hd_gold_hi" if name_key == "Confirm" else "hd_text_3"))
		note.add_theme_constant_override(&"line_spacing", 5)
		note.custom_minimum_size = Vector2(HD_BOX_W - 68.0, 0)
	super._finish()
	_box.custom_minimum_size = Vector2(HD_BOX_W, 0)
	_box.reset_size()
	_box.position = ((Vector2(1280, 720) - _box.size) * 0.5).floor()


## hub_ui.json 的 pause.<key>；没写的退回旧的 c16.pause.<key>（远洋覆盖层里的存档说明、确认话）
func _text(key: String) -> String:
	var t := Data.text("pause." + key)
	return t if t != "" else CardText.ui("c16.pause." + key)
