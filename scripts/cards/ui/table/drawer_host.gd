# 两侧标签和左/右抽屉框。一次只开一个抽屉。主人 C01。合同 §7.11.8。
# preload，不写 class_name。抽屉内容是各主人的面板。
# 左抽屉常驻一块 C05 的条子板（DemandBoard，抽屉合着时藏起来），跟着 view 刷新，好让 C05 登记 a.demand.*；
# 抽屉合着时 a.demand.board/days/tier 退到“条子”标签上（有条子才算），指引照样能指到条子在哪。
# 换皮（10-22，网页原型）：标签是木牌（图标 + 竖排字 + 角标药丸，悬停/打开往里移 4px）；抽屉框深色渐变、
# 3px umber 边（贴屏幕那侧不画）、毛笔金标题、标题行下一道细线、“合上”是小按钮；不是快动画时框滑进来。
# 标题行（标题、细线、合上）在 chrome() 里：宿主把它挪到抽屉面板上面（b23：面板满屏，挡住了框里的“合上”）。
extends Control

const DEMAND_BOARD_SCENE := "res://scenes/cards/demand/DemandBoard.tscn"
const DEMAND_PROXY: Array[StringName] = [&"a.demand.board", &"a.demand.days", &"a.demand.tier"]
## The one drawer title-bar height (prototype .dhead ≈ 52): brush 26 gold title + 合上, a 1px rule under it.
## Drawer panels (C03/C04/C05/C07/C10/C11/C16) lay their rows in content_rect(side), under this bar:
##   const DrawerHost = preload("res://scripts/cards/ui/table/drawer_host.gd")
##   DrawerHost.content_rect("l") = (0, 83, 397, 637); DrawerHost.content_rect("r") = (863, 83, 417, 637).
const HEAD_H := 52.0
## Frame edge on the side away from the screen (left drawer: right edge; right drawer: left edge).
const EDGE := 3.0
const PAD_X := 14.0
const SLIDE_S := 0.26
const TAB_SHIFT := 4.0
const TAB_SHIFT_S := 0.15
const TAB_ICON := 24.0
## Vertical caption: one glyph per line, 14px (contract minimum), tight lines.
const CAPTION_SIZE := 14
const CAPTION_LINE := -5

signal tab_pressed(tab: StringName)
signal close_pressed

## Fast animations: no slide, no tab shift tween.
var fast: bool = false

var _tabs: Dictionary = {}
var _badges: Dictionary = {}
var _tab_home: Dictionary = {}
var _tab_side: Dictionary = {}
var _tab_hover: Dictionary = {}
var _open_tab: StringName = &""
var _scrim: ColorRect
var _frame: Panel
var _chrome: Control
var _title: Label
var _rule: ColorRect
var _close: Button
var _body: Control
var _open: bool = false
var _side: String = ""
var _demand_board: Control = null
var _has_demands: bool = false
var _slide: Tween = null


func _ready() -> void:
	_build()


func lift_tabs(parent: Control) -> void:
	_build()
	var bar := Control.new()
	bar.name = "Tabs"
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.size = Vector2(1280, 720)
	parent.add_child(bar)
	var moved: Array = []
	for id in _tabs:
		moved.append(_tabs[id])
		moved.append(_badges[id])
	for node in moved:
		var ctrl := node as Control
		ctrl.get_parent().remove_child(ctrl)
		bar.add_child(ctrl)


## Screen rect a drawer panel fills: the drawer minus the title bar (and its rule) and minus the inner edge.
static func content_rect(side_name: String) -> Rect2:
	var rect := CardLayout.DRAWER_L if side_name == "l" else CardLayout.DRAWER_R
	var x := rect.position.x + (0.0 if side_name == "l" else EDGE)
	var y := rect.position.y + HEAD_H + 1.0
	return Rect2(x, y, rect.size.x - EDGE, rect.end.y - y)


func is_open() -> bool:
	return _open


func side() -> String:
	return _side


func body() -> Control:
	return _body


## Title row of the open drawer (title, rule, close). The modal host re-parents it above the drawer panel.
func chrome() -> Control:
	_build()
	return _chrome


func show_frame(tab: StringName, side_name: String, title_key: String) -> void:
	_build()
	_open = true
	_side = side_name
	var rect := CardLayout.DRAWER_L if side_name == "l" else CardLayout.DRAWER_R
	_scrim.visible = true
	_frame.visible = true
	_chrome.visible = true
	_title.visible = true
	_close.visible = true
	_close.focus_mode = Control.FOCUS_ALL
	_frame.position = rect.position
	_frame.size = rect.size
	_frame.add_theme_stylebox_override("panel", _frame_style(side_name))
	_title.text = CardText.ui(title_key)
	_title.position = Vector2(rect.position.x + PAD_X, rect.position.y + 2.0)
	_title.size = Vector2(rect.size.x - PAD_X * 2.0 - 96.0, HEAD_H - 4.0)
	_rule.position = Vector2(rect.position.x + (0.0 if side_name == "l" else EDGE), rect.position.y + HEAD_H)
	_rule.size = Vector2(rect.size.x - EDGE, 1.0)
	_close.reset_size()
	_close.position = Vector2(rect.end.x - PAD_X - _close.size.x - (EDGE if side_name == "l" else 0.0),
		rect.position.y + floorf((HEAD_H - _close.size.y) * 0.5))
	_body.position = Vector2.ZERO
	_body.size = Vector2(1280, 720)
	_open_tab = tab
	for id in _tabs:
		_style_tab(id)
	move_child(_scrim, 0)
	move_child(_frame, 1)
	_slide_in(side_name, rect)


func hide_frame() -> void:
	_open = false
	_side = ""
	_open_tab = &""
	if _slide != null and _slide.is_valid():
		_slide.kill()
	if _scrim != null:
		_scrim.visible = false
		_frame.visible = false
		_frame.position.x = 0.0
	if _chrome != null:
		_chrome.position = Vector2.ZERO
		_chrome.visible = false
	if _title != null:
		_title.visible = false
	if _close != null:
		if _close.has_focus():
			_close.release_focus()
		_close.visible = false
		_close.focus_mode = Control.FOCUS_NONE
	for id in _tabs:
		_style_tab(id)


func refresh(view: Dictionary) -> void:
	_build()
	_close.text = CardText.ui("c01.btn.drawer_close")
	for id in _tabs:
		(_tabs[id].get_node("Caption") as Label).text = CardText.ui("c01.tab." + str(id))
	var demands: Array = view.get("demands", [])
	_has_demands = not demands.is_empty()
	if _demand_board != null and _demand_board.has_method("refresh"):
		_demand_board.refresh(view)
	var urgent := false
	for row in demands:
		if typeof(row) == TYPE_DICTIONARY and int(row.get("days_left", 9)) <= 1:
			urgent = true
	_badge(&"demands", str(demands.size()) if not demands.is_empty() else "", urgent)
	var tickets: Array = view.get("tickets", [])
	var due := false
	for row in tickets:
		if typeof(row) == TYPE_DICTIONARY and row.has("days_left") and int(row.get("days_left", 9)) <= 0:
			due = true
	_badge(&"tickets", str(tickets.size()) if not tickets.is_empty() else "", due)
	var shelf := int(view.get("shelf_count", 0))
	var cap := int(view.get("caps", {}).get("shelf", 0))
	_badge(&"shelf", "%d/%d" % [shelf, cap] if cap > 0 else "", false)
	var kept: Array = view.get("kept", [])
	_badge(&"contacts", str(kept.size()) if not kept.is_empty() else "", false)


func _build() -> void:
	if _scrim != null:
		return
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(1280, 720)
	_scrim = ColorRect.new()
	_scrim.name = "Scrim"
	_scrim.color = CardTheme.color(&"scrim")
	_scrim.size = Vector2(1280, 720)
	_scrim.visible = false
	_scrim.gui_input.connect(_on_scrim)
	add_child(_scrim)
	_frame = Panel.new()
	_frame.name = "Frame"
	_frame.visible = false
	_frame.mouse_filter = Control.MOUSE_FILTER_STOP
	_frame.add_theme_stylebox_override("panel", _frame_style("l"))
	add_child(_frame)
	_chrome = Control.new()
	_chrome.name = "DrawerChrome"
	_chrome.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_chrome.size = Vector2(1280, 720)
	_chrome.visible = false
	add_child(_chrome)
	_title = Label.new()
	_title.name = "Title"
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title.clip_text = true
	_title.add_theme_font_override("font", CardTheme.font_title())
	_title.add_theme_font_size_override("font_size", 26)
	_title.add_theme_color_override("font_color", CardTheme.color(&"gold_hi"))
	_chrome.add_child(_title)
	_rule = ColorRect.new()
	_rule.name = "Rule"
	_rule.color = CardTheme.color(&"line")
	_rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_chrome.add_child(_rule)
	_close = Button.new()
	_close.name = "Close"
	_close.theme_type_variation = &"SmallButton"
	_close.text = CardText.ui("c01.btn.drawer_close")
	_close.focus_mode = Control.FOCUS_ALL
	_close.pressed.connect(_on_close_pressed)
	_chrome.add_child(_close)
	_body = Control.new()
	_body.name = "Body"
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body.position = Vector2.ZERO
	_body.size = Vector2(1280, 720)
	add_child(_body)
	_add_tabs(CardIds.TABS_L, CardLayout.TABS_L, "l")
	_add_tabs(CardIds.TABS_R, CardLayout.TABS_R, "r")
	_mount_demand_board()
	hide_frame()


## Drawer box: tab_bg→drawer_bg (middle colour), 3px umber edge except on the screen side, deep shadow.
func _frame_style(side_name: String) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = CardTheme.mix(&"tab_bg", &"drawer_bg")
	sb.bg_color.a = 1.0
	sb.border_color = CardTheme.color(&"umber")
	sb.set_border_width_all(int(EDGE))
	sb.border_width_top = 0
	if side_name == "l":
		sb.border_width_left = 0
	else:
		sb.border_width_right = 0
	sb.shadow_color = CardTheme.color(&"modal_shadow")
	sb.shadow_size = 40
	return sb


## Slide the frame and its title row in from the screen edge (0.26 s); fast = in place.
func _slide_in(side_name: String, rect: Rect2) -> void:
	if _slide != null and _slide.is_valid():
		_slide.kill()
	_chrome.position = Vector2.ZERO
	if fast or not is_inside_tree():
		return
	var off := -(rect.end.x + 8.0) if side_name == "l" else (1280.0 - rect.position.x + 8.0)
	_frame.position.x = rect.position.x + off
	_chrome.position.x = off
	_slide = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_slide.tween_property(_frame, "position:x", rect.position.x, SLIDE_S)
	_slide.tween_property(_chrome, "position:x", 0.0, SLIDE_S)


## C05 的条子板：常驻、合着时藏；条子标签替它兜底 a.demand.*（有条子时）
func _mount_demand_board() -> void:
	var packed := load(DEMAND_BOARD_SCENE) as PackedScene
	if packed != null:
		_demand_board = packed.instantiate() as Control
		_demand_board.name = "DemandBoard"
		var inner := CardLayout.DRAWER_L.grow(-16)
		_demand_board.position = inner.position + Vector2(0, 44)
		_demand_board.size = Vector2(inner.size.x, inner.size.y - 44)
		_demand_board.visible = false
		_body.add_child(_demand_board)
	var tab: Control = _tabs.get(&"demands")
	if tab == null:
		return
	for id in DEMAND_PROXY:
		CardAnchors.register(id, tab, _demand_tab_rect.bind(tab))


func _demand_tab_rect(tab: Control) -> Rect2:
	if not _has_demands or _open:
		return Rect2()
	return tab.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, tab.size)


## Wooden tab (prototype .tab): icon on top, caption written top to bottom, both centred as a group.
func _add_tabs(names: Array, rects: Array, side_name: String) -> void:
	for i in range(names.size()):
		var id: StringName = names[i]
		var rect: Rect2 = rects[i]
		var button := Button.new()
		button.name = "Tab_" + str(id)
		button.theme_type_variation = &"TabButton" if side_name == "l" else &"TabButtonR"
		button.focus_mode = Control.FOCUS_ALL
		button.position = rect.position
		button.size = rect.size
		var caption := Label.new()
		caption.name = "Caption"
		caption.text = CardText.ui("c01.tab." + str(id))
		caption.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
		caption.add_theme_font_size_override("font_size", CAPTION_SIZE)
		caption.add_theme_constant_override("line_spacing", CAPTION_LINE)
		caption.add_theme_color_override("font_color", CardTheme.color(&"hud_ink"))
		var icon := CardArt.texture("icon.tab." + str(id))
		var mark: TextureRect = null
		if icon != null:
			mark = TextureRect.new()
			mark.name = "Icon"
			mark.texture = icon
			mark.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			mark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			mark.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
			button.add_child(mark)
		button.add_child(caption)
		_lay_tab(button, mark, caption, rect.size)
		button.pressed.connect(_on_tab.bind(id))
		button.mouse_entered.connect(_on_tab_hover.bind(id, true))
		button.mouse_exited.connect(_on_tab_hover.bind(id, false))
		add_child(button)
		button.size = rect.size
		_tabs[id] = button
		_tab_home[id] = rect.position
		_tab_side[id] = side_name
		_anchor(StringName("a.tab." + str(id)), button)
		var badge := _make_badge(id)
		add_child(badge)
		_badges[id] = badge
		_place_badge(id)


## Icon (24×24 ×1) and the vertical caption, centred together; the caption is one glyph wide.
func _lay_tab(button: Button, mark: TextureRect, caption: Label, box: Vector2) -> void:
	var font := CardTheme.font_body()
	var line_h := font.get_height(CAPTION_SIZE)
	var glyphs := maxi(1, caption.text.length())
	var cap_w := float(CAPTION_SIZE + 2)
	var icon_h := TAB_ICON if mark != null else 0.0
	var gap := 2.0 if mark != null else 0.0
	# Three-glyph captions (档案簿) tighten the lines so icon + caption still fit the 78px tab (b40).
	var spacing := CAPTION_LINE
	if glyphs > 1:
		var room := box.y - 4.0 - icon_h - gap
		spacing = mini(CAPTION_LINE, floori((room - line_h * glyphs) / float(glyphs - 1)))
	caption.add_theme_constant_override("line_spacing", spacing)
	var cap_h := ceilf(line_h * glyphs + spacing * (glyphs - 1))
	var total := icon_h + gap + cap_h
	var top := maxf(2.0, floorf((box.y - total) * 0.5))
	if mark != null:
		mark.position = Vector2(floorf((box.x - TAB_ICON) * 0.5), top)
		mark.size = Vector2(TAB_ICON, TAB_ICON)
	caption.position = Vector2(floorf((box.x - cap_w) * 0.5), top + icon_h + gap)
	caption.size = Vector2(cap_w, minf(cap_h, box.y - (top + icon_h + gap)))
	button.set_meta("caption_glyphs", glyphs)


## Badge pill (prototype .tab .badge): wood_3 with a 1px line edge, 14px; red when something is due.
func _make_badge(id: StringName) -> PanelContainer:
	var pill := PanelContainer.new()
	pill.name = "Badge_" + str(id)
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill.add_theme_stylebox_override("panel", CardTheme.pill_style(&"wood_3", &"line", 8, 5.0, 0.0))
	pill.visible = false
	var label := Label.new()
	label.name = "Text"
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", CardTheme.font_size(&"min"))
	label.add_theme_constant_override("line_spacing", -4)
	label.add_theme_color_override("font_color", CardTheme.color(&"hud_ink"))
	pill.add_child(label)
	return pill


## Top −6, on the tab's inner corner, 8px past the tab edge (never cut by the screen edge, b40).
func _place_badge(id: StringName) -> void:
	var pill: PanelContainer = _badges.get(id)
	var tab: Button = _tabs.get(id)
	if pill == null or tab == null:
		return
	pill.reset_size()
	var home: Vector2 = _tab_home[id]
	var w := pill.size.x
	if str(_tab_side[id]) == "l":
		pill.position = Vector2(home.x + tab.size.x + 8.0 - w, home.y - 6.0)
	else:
		pill.position = Vector2(home.x - 8.0, home.y - 6.0)
	pill.position.x += tab.position.x - home.x


func _anchor(id: StringName, node: Control) -> void:
	CardAnchors.register(id, node)


## Open tab: lit wood and gold edge (the hover look), shifted 4px in from the screen edge.
func _style_tab(id: StringName) -> void:
	var button: Button = _tabs.get(id)
	if button == null:
		return
	var on: bool = _open and id == _open_tab
	var side_name := str(_tab_side.get(id, "l"))
	if on:
		button.add_theme_stylebox_override("normal", CardTheme.tab_style(side_name, true))
		button.add_theme_color_override("font_color", CardTheme.color(&"gold_pale"))
	else:
		button.remove_theme_stylebox_override("normal")
		button.remove_theme_color_override("font_color")
	var caption := button.get_node_or_null("Caption") as Label
	if caption != null:
		caption.add_theme_color_override("font_color", CardTheme.color(&"gold_pale" if on else &"hud_ink"))
	_shift_tab(id)


func _shift_tab(id: StringName) -> void:
	var button: Button = _tabs.get(id)
	if button == null:
		return
	var lifted: bool = (_open and id == _open_tab) or bool(_tab_hover.get(id, false))
	var home: Vector2 = _tab_home[id]
	var dir := 1.0 if str(_tab_side[id]) == "l" else -1.0
	var x := home.x + (TAB_SHIFT * dir if lifted else 0.0)
	var pill: Control = _badges.get(id)
	var pill_x := 0.0
	if pill != null:
		pill_x = pill.position.x + (x - button.position.x)
	if fast or not is_inside_tree() or not button.is_inside_tree():
		button.position.x = x
		if pill != null:
			pill.position.x = pill_x
		return
	var tw := button.create_tween().set_parallel(true)
	tw.tween_property(button, "position:x", x, TAB_SHIFT_S)
	if pill != null:
		tw.tween_property(pill, "position:x", pill_x, TAB_SHIFT_S)


func _on_tab_hover(id: StringName, on: bool) -> void:
	_tab_hover[id] = on
	var button: Button = _tabs.get(id)
	if button != null:
		var caption := button.get_node_or_null("Caption") as Label
		var lit: bool = on or (_open and id == _open_tab)
		if caption != null:
			caption.add_theme_color_override("font_color", CardTheme.color(&"gold_pale" if lit else &"hud_ink"))
	_shift_tab(id)


func _badge(id: StringName, text: String, danger: bool) -> void:
	var pill: PanelContainer = _badges.get(id)
	if pill == null:
		return
	var label := pill.get_node("Text") as Label
	label.text = text
	pill.visible = text != ""
	if danger:
		pill.add_theme_stylebox_override("panel", CardTheme.pill_style(&"seal", &"seal_dark", 8, 5.0, 0.0))
		label.add_theme_color_override("font_color", CardTheme.color(&"btn_warn_ink"))
	else:
		pill.add_theme_stylebox_override("panel", CardTheme.pill_style(&"wood_3", &"line", 8, 5.0, 0.0))
		label.add_theme_color_override("font_color", CardTheme.color(&"hud_ink"))
	_place_badge(id)


func _on_tab(id: StringName) -> void:
	tab_pressed.emit(id)


func _on_scrim(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_on_close_pressed()


func _on_close_pressed() -> void:
	if _open:
		close_pressed.emit()
