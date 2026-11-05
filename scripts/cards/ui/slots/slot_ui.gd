# 格子界面的小工具：标签、按钮、居中面板、焦点链。主人 C03。不写 class_name。
# 合同：docs/cards/CARDS_INTERFACES.md §1.2、§7.8、§11.2。文字走 CardText，颜色走 CardTheme。
extends RefCounted


static func label(text: String, size: int, draft: bool) -> Label:
	var node := Label.new()
	node.text = text
	node.clip_text = true
	node.autowrap_mode = TextServer.AUTOWRAP_OFF
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	node.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	node.add_theme_font_override("font", CardTheme.font_title() if size >= 28 else CardTheme.font_body())
	node.add_theme_font_size_override("font_size", size)
	# 换皮 10-22：格子界面的面板都是深底，字是浅的（标题毛笔金字，草稿灰一点）。
	var tone := &"gold_hi" if size >= 28 else &"hud_ink"
	node.add_theme_color_override("font_color", CardTheme.color(&"text_2" if draft else tone))
	return node


static func num_label(n: int) -> Label:
	var node := Label.new()
	node.text = str(n)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.add_theme_font_override("font", CardTheme.font_body())
	node.add_theme_font_size_override("font_size", 16)
	node.add_theme_color_override("font_color", CardTheme.color(&"hud_ink"))
	return node


static func button(text: String) -> Button:
	var node := Button.new()
	node.text = text
	node.clip_text = true
	node.focus_mode = Control.FOCUS_ALL
	node.mouse_filter = Control.MOUSE_FILTER_STOP
	node.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	node.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	node.custom_minimum_size = Vector2(96, 32)
	node.add_theme_font_override("font", CardTheme.font_body())
	node.add_theme_font_size_override("font_size", 16)
	node.add_theme_color_override("font_color", CardTheme.color(&"hud_ink"))
	node.add_theme_color_override("font_hover_color", CardTheme.color(&"gold_pale"))
	node.add_theme_color_override("font_pressed_color", CardTheme.color(&"gold_pale"))
	node.add_theme_color_override("font_disabled_color", CardTheme.color(&"text_3"))
	return node


static func pin(node: Control, sz: Vector2) -> void:
	node.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	node.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	node.custom_minimum_size = sz
	node.size = sz


static func clear(node: Node) -> void:
	if node == null:
		return
	for child in node.get_children():
		node.remove_child(child)
		child.free()


## 居中面板（换皮 10-22：深色叠层面板 modal_style + 外影；遮罩由宿主的叠层给）。返回面板，调用方往里面放内容。
static func mount(host: Control, box_size: Vector2) -> Panel:
	host.mouse_filter = Control.MOUSE_FILTER_STOP
	var at := (Vector2(1280, 720) - box_size) / 2.0
	var shadow := Panel.new()
	shadow.name = "BoxShadow"
	shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shadow.set_anchors_preset(Control.PRESET_TOP_LEFT)
	shadow.size = box_size
	shadow.position = at
	shadow.add_theme_stylebox_override("panel", CardTheme.modal_shadow_style())
	host.add_child(shadow)
	var box := Panel.new()
	box.set_anchors_preset(Control.PRESET_TOP_LEFT)
	box.size = box_size
	box.position = at
	box.add_theme_stylebox_override("panel", CardTheme.modal_style())
	host.add_child(box)
	return box


static func wire_focus(root: Node) -> void:
	var buttons: Array[Button] = []
	_collect(root, buttons)
	for i in buttons.size():
		var here := buttons[i]
		if not here.visible:
			continue
		if i > 0:
			here.focus_neighbor_left = here.get_path_to(buttons[i - 1])
			here.focus_previous = here.focus_neighbor_left
		if i + 1 < buttons.size():
			here.focus_neighbor_right = here.get_path_to(buttons[i + 1])
			here.focus_next = here.focus_neighbor_right


static func _collect(node: Node, out: Array[Button]) -> void:
	if node is Button and (node as Button).visible:
		out.append(node as Button)
	for child in node.get_children():
		_collect(child, out)
