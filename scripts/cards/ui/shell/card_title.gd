# 卡牌版标题：新局 / 继续（有续玩点才能点）/ 设置 / 退出。背景走 CardArt bg.title，没有就用配色。
# 主人 C16（换皮这一轮归 C01 外框那一路改）。合同：docs/cards/CARDS_INTERFACES.md §3.3 C16、§7.8。信号 chose 冻结。
# 换皮（10-22，网页原型标题）：水乡夜景 + 从左往右的暗色渐变；左边一张标题卡：题签小字（字距拉开）、
# 毛笔 112 号金色“德厚当”（下影 + 外发光）、两三行引子、金色大按钮“开张”、木色“接着做生意”、小按钮设置 / 离开、
# 两行说明。四颗按钮都是本节点的直接子节点（name = new / continue / settings / quit，测试和真点冒烟按名字找）。
# 键盘（b04 / b06）：上下左右在四颗按钮里绕圈（焦点邻居只指自己人，不会跑到背后的牌桌），焦点变了 _index 跟着变；
# 回车 / 空格按的是有焦点的那颗，在 _input 里吃掉，按钮松开时不会再按一次。
# 肉鸽 v1（RG4，ROGUE_V1.md §7.5）：外壳调 set_rogue(data) 才在右下角建 RunBox（第几本账、种子框、开头、旧账书架）；
# 没调时标题和以前一模一样。种子框不进四颗按钮的环；焦点在种子框时只认回车（= 开张）和 Esc（焦点还给“开张”），
# 别的键都交给输入框。RunBox 的“换一个”“换开头”经 chose 发 &"reseed" / &"opening"。
# 验收 2：还有一本账没合上（set_rogue 的 open_no > 0）时，“开张”（按钮、回车、种子框里回车）先在按钮那一行问一句
# “合上它另起一本？”，默认焦点在“再想想”；点“合上它，另起一本”才发 chose(&"new")。Esc / “再想想”回到四颗按钮。
class_name CardTitle
extends Control

## &"new" &"continue" &"settings" &"quit"; rogue v1 adds &"reseed" (another seed) and &"opening" (opening changed)
signal chose(action: StringName)

const CARD_X := 110.0
const CARD_W := 520.0
const TAGLINE_Y := 140.0
const NAME_Y := 156.0
const NAME_SIZE := 112
const BLURB_Y := 314.0
const BUTTONS_Y := 432.0
const HINT_Y := 512.0
const ACTIONS: Array[StringName] = [&"new", &"continue", &"settings", &"quit"]
const RunBox = preload("res://scripts/cards/ui/rogue/title_run_box.gd")
const DEFAULT_OPENING := "og.default"

var _buttons: Array[Button] = []
var _index: int = 0
var _blocked: Callable = Callable()
var _run_box: RunBox = null
## set_rogue() data that arrived before _ready (the root boots before it enters the tree); built in _ready.
var _rogue_early: Dictionary = {}
var _rogue_waiting: bool = false
## The ledger still open (set_rogue open_no, 0 = none) and the one "new" would start: "new" asks first then.
var _open_no: int = 0
var _run_no: int = 1
## The "close it and start another?" row shown in place of the four buttons; null while not asking.
var _confirm: Control = null
var _confirm_buttons: Array[Button] = []
var _confirm_index: int = 1


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	# 外壳在标题进树前就调了 set_rogue（根场景先 boot 再挂进树）：等背景和四颗按钮建好再建盒子，
	# 这样盒子画在背景上面，种子框的焦点邻居也接得到“开张”。
	if _rogue_waiting:
		_rogue_waiting = false
		set_rogue(_rogue_early)
		_rogue_early = {}


## The root passes a check that is true while a panel (settings drawer, help) sits over the title;
## keys then belong to that panel.
func set_blocked(check: Callable) -> void:
	_blocked = check


## Rogue v1 (frozen interface, ROGUE_V1.md 7.5): the shell's run box data. The box exists only after the first call
## (a call before _ready is kept and the box is built in _ready, over the background, with its focus wired).
##   "run_no": int, "seed": int, "openings": [{"id", "unlocked"}], "opening": String,
##   "shelf": [{"no", "key", "args", "reason", "opening"}] (old -> new), "notice_key": String ("" = none)
func set_rogue(data: Dictionary) -> void:
	if not is_node_ready():
		_rogue_early = data.duplicate(true)
		_rogue_waiting = true
		return
	_open_no = int(data.get("open_no", 0))
	_run_no = int(data.get("run_no", 1))
	if _run_box == null:
		_run_box = RunBox.new()
		add_child(_run_box)
		_run_box.reseed_pressed.connect(func() -> void: chose.emit(&"reseed"))
		_run_box.opening_changed.connect(func(_id: String) -> void: chose.emit(&"opening"))
		var field := _run_box.seed_field()
		if not _buttons.is_empty():
			var home := field.get_path_to(_buttons[0])
			field.focus_next = home
			field.focus_previous = home
			field.focus_neighbor_top = home
			field.focus_neighbor_bottom = home
	_run_box.set_data(data)


## The seed field's text as typed; "" while the run box is not shown.
func seed_text() -> String:
	return _run_box.seed_text() if _run_box != null else ""


## The chosen opening; "og.default" while the run box is not shown.
func opening_id() -> String:
	return _run_box.opening_id() if _run_box != null else DEFAULT_OPENING


func _build() -> void:
	var tex := CardArt.texture("bg.title")
	if tex != null:
		var pic := TextureRect.new()
		pic.name = "Back"
		pic.set_anchors_preset(Control.PRESET_FULL_RECT)
		pic.texture = tex
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_SCALE
		pic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(pic)
	else:
		var bg := ColorRect.new()
		bg.name = "Back"
		bg.color = CardTheme.color(&"wood_dark")
		bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(bg)
	add_child(_shade())
	var tagline := _text("Tagline", CardText.ui("c16.title.tagline"), Vector2(CARD_X, TAGLINE_Y), 14, &"text_2")
	tagline.add_theme_font_override("font", _spaced(CardTheme.font_body(), 4))
	# 大字：下面一层只画外发光（同字、粗描边、半透明金），上面一层是金字 + 0 4 0 的深色下影。
	var glow := _text("NameGlow", CardText.ui("c16.title.name"), Vector2(CARD_X, NAME_Y), NAME_SIZE, &"title_glow")
	glow.add_theme_font_override("font", CardTheme.font_title())
	glow.add_theme_color_override("font_color", CardTheme.with_alpha(&"title_glow", 0.0))
	glow.add_theme_color_override("font_outline_color", CardTheme.color(&"title_glow"))
	glow.add_theme_constant_override("outline_size", 22)
	var title := _text("Name", CardText.ui("c16.title.name"), Vector2(CARD_X, NAME_Y), NAME_SIZE, &"gold_hi")
	title.add_theme_font_override("font", CardTheme.font_title())
	title.add_theme_color_override("font_shadow_color", CardTheme.color(&"title_shadow"))
	title.add_theme_constant_override("shadow_offset_x", 0)
	title.add_theme_constant_override("shadow_offset_y", 4)
	title.add_theme_constant_override("shadow_outline_size", 0)
	var blurb := _text("Blurb", CardText.ui("c16.title.blurb"), Vector2(CARD_X, BLURB_Y), 16, &"hud_ink", CARD_W + 24.0)
	# Prototype .title-card p: 16px at line-height 1.8, a 28.8px pitch; the body font's own line is about 23px.
	blurb.add_theme_constant_override("line_spacing", 6)
	var x := CARD_X
	for action in ACTIONS:
		var btn := Button.new()
		btn.name = str(action)
		btn.text = CardText.ui("c16.title." + str(action))
		btn.focus_mode = Control.FOCUS_ALL
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		match action:
			&"new":
				btn.theme_type_variation = &"PrimaryBigButton"
			&"continue":
				btn.theme_type_variation = &""
			_:
				btn.theme_type_variation = &"SmallButton"
		if action == &"continue":
			btn.disabled = not CardSave.exists(CardSave.suspend_path())
		var act: StringName = action
		if action == &"new":
			btn.pressed.connect(_on_new)
		else:
			btn.pressed.connect(func() -> void: chose.emit(act))
		add_child(btn)
		btn.reset_size()
		var h := 52.0 if action == &"new" else (40.0 if action == &"continue" else 34.0)
		btn.size = Vector2(maxf(btn.size.x, 112.0 if action == &"new" else 0.0), h)
		btn.position = Vector2(x, BUTTONS_Y + floorf((52.0 - h) * 0.5))
		x += btn.size.x + (14.0 if action != &"settings" else 8.0)
		_buttons.append(btn)
	for i in _buttons.size():
		_buttons[i].focus_entered.connect(_on_focus.bind(i))
	_wire_neighbours()
	var hint := _text("Hint", CardText.ui("c16.title.hint"), Vector2(CARD_X, HINT_Y), 14, &"text_2", CARD_W + 80.0)
	hint.add_theme_constant_override("line_spacing", 6)
	_select(0)


## Left-to-right dark wash over the night town (prototype .title-ov): scene_void at .88 → .62 → .05.
func _shade() -> TextureRect:
	var grad := Gradient.new()
	grad.set_color(0, CardTheme.with_alpha(&"scene_void", 0.88))
	grad.set_color(1, CardTheme.with_alpha(&"scene_void", 0.05))
	grad.add_point(0.45, CardTheme.with_alpha(&"scene_void", 0.62))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_LINEAR
	tex.fill_from = Vector2(0, 0)
	tex.fill_to = Vector2(1, 0)
	tex.width = 256
	tex.height = 4
	var rect := TextureRect.new()
	rect.name = "Wash"
	rect.texture = tex
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	return rect


func _spaced(base: Font, glyph: int) -> Font:
	var f := FontVariation.new()
	f.base_font = base
	f.spacing_glyph = glyph
	return f


## width > 0: the text wraps at that width (set before the label enters the tree, so it never sizes to one long line).
func _text(node_name: String, text: String, at: Vector2, font_size: int, tone: StringName, width: float = 0.0) -> Label:
	var label := Label.new()
	label.name = node_name
	if width > 0.0:
		label.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
		label.custom_minimum_size = Vector2(width, 0)
	label.text = text
	label.position = at
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", CardTheme.color(tone))
	add_child(label)
	if width > 0.0:
		# The theme font arrives with the tree; size the box after that so it wraps at `width`.
		label.size = Vector2(width, 0)
	return label


## Up / Down / Left / Right / Tab wrap among the enabled title buttons only (b06).
func _wire_neighbours() -> void:
	var live: Array[Button] = []
	for btn in _buttons:
		if not btn.disabled:
			live.append(btn)
	var n := live.size()
	for i in n:
		var prev := live[_wrap(i - 1, n)]
		var nxt := live[_wrap(i + 1, n)]
		var me := live[i]
		me.focus_neighbor_left = me.get_path_to(prev)
		me.focus_neighbor_top = me.get_path_to(prev)
		me.focus_previous = me.get_path_to(prev)
		me.focus_neighbor_right = me.get_path_to(nxt)
		me.focus_neighbor_bottom = me.get_path_to(nxt)
		me.focus_next = me.get_path_to(nxt)


## 新局开不了时，在按钮下面显示一条看得见的提示（不再点了没反应）。details 是数据错误的前几行（文件名），可以为空。
func show_error(message: String, details: String = "") -> void:
	var box := get_node_or_null("Error") as Label
	if box == null:
		box = Label.new()
		box.name = "Error"
		box.position = Vector2(CARD_X, HINT_Y + 64.0)
		box.size = Vector2(CARD_W + 60.0, 120)
		box.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_theme_font_override("font", CardTheme.font_body())
		box.add_theme_font_size_override("font_size", CardTheme.font_size(&"body"))
		box.add_theme_color_override("font_color", CardTheme.color(&"danger"))
		box.add_theme_color_override("font_outline_color", CardTheme.color(&"ink"))
		box.add_theme_constant_override("outline_size", 4)
		add_child(box)
	box.text = message if details == "" else message + "\n" + details
	box.visible = true


## Real key presses: handled before GUI focus navigation, so the highlighted button and the one Enter
## presses are always the same (b04), and the Enter press is consumed (no second press on release).
func _input(event: InputEvent) -> void:
	if not _keys_live():
		return
	if _handle_key(event):
		var vp := get_viewport()
		if vp != null:
			vp.set_input_as_handled()


## Direct callers (C16 shell tests) and anything the GUI left unhandled.
func _unhandled_input(event: InputEvent) -> void:
	if _handle_key(event):
		var vp := get_viewport()
		if vp != null:
			vp.set_input_as_handled()


func _keys_live() -> bool:
	if not is_visible_in_tree() or is_queued_for_deletion():
		return false
	if _blocked.is_valid() and bool(_blocked.call()):
		return false
	var vp := get_viewport()
	if vp == null:
		return false
	var focus := vp.gui_get_focus_owner()
	return focus == null or focus == self or is_ancestor_of(focus)


func _handle_key(event: InputEvent) -> bool:
	if not (event is InputEventKey) or not (event as InputEventKey).pressed or (event as InputEventKey).echo:
		return false
	var key := (event as InputEventKey).keycode
	if _confirm != null:
		return _confirm_key(key)
	if _run_box != null and _run_box.seed_has_focus():
		return _seed_key(key)
	if key == KEY_UP or key == KEY_W or key == KEY_LEFT or key == KEY_A:
		_move(-1)
	elif key == KEY_DOWN or key == KEY_S or key == KEY_RIGHT or key == KEY_D:
		_move(1)
	elif key == KEY_ENTER or key == KEY_KP_ENTER or key == KEY_SPACE:
		_activate()
	else:
		return false
	return true


## Rogue v1: the seed field has focus. Enter opens the shop, Esc hands focus back to "new"; every other key
## (W A S D, Space, digits, arrows) belongs to the field.
func _seed_key(key: Key) -> bool:
	if key == KEY_ENTER or key == KEY_KP_ENTER:
		_on_new()
		return true
	if key == KEY_ESCAPE:
		_select(0)
		return true
	return false


func _move(dir: int) -> void:
	var n := _buttons.size()
	if n == 0:
		return
	var i := _index
	for _hop in n:
		i = _wrap(i + dir, n)
		if not _buttons[i].disabled:
			_select(i)
			return


func _wrap(i: int, n: int) -> int:
	if n <= 0:
		return 0
	var x := i
	while x < 0:
		x += n
	while x >= n:
		x -= n
	return x


func _select(i: int) -> void:
	_index = i
	if i >= 0 and i < _buttons.size() and not _buttons[i].disabled and _buttons[i].is_inside_tree():
		_buttons[i].grab_focus()


func _on_focus(i: int) -> void:
	_index = i


func _activate() -> void:
	var vp := get_viewport()
	var focus := vp.gui_get_focus_owner() if vp != null else null
	var i := _buttons.find(focus as Button) if focus is Button else -1
	if i < 0:
		i = _index
	if i < 0 or i >= _buttons.size():
		return
	var btn := _buttons[i]
	if btn.disabled:
		return
	btn.pressed.emit()


## "new": straight to chose(&"new"), unless a ledger is still open; then ask once (it cannot be undone).
func _on_new() -> void:
	if _confirm != null:
		return
	if _open_no <= 0:
		chose.emit(&"new")
		return
	_ask_new()


## True while the "close it and start another?" row is up (tests).
func is_asking_new() -> bool:
	return _confirm != null


## The row that replaces the four buttons: one line saying what "new" does to the open ledger, then
## [close it, start another] (warn) and [think again] (focused, so a stray Enter does nothing for good).
func _ask_new() -> void:
	for btn in _buttons:
		btn.visible = false
	var hint := get_node_or_null("Hint") as CanvasItem
	if hint != null:
		hint.visible = false
	_confirm = VBoxContainer.new()
	_confirm.name = "ConfirmNew"
	_confirm.position = Vector2(CARD_X, BUTTONS_Y - 8.0)
	_confirm.add_theme_constant_override("separation", 10)
	add_child(_confirm)
	var note := Label.new()
	note.name = "Note"
	note.text = CardText.ui("rg4.title.confirm_new", {"open": _open_no, "n": _run_no})
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART   # line-break rules: no closing quote at a line start
	note.custom_minimum_size = Vector2(CARD_W + 24.0, 0)
	note.add_theme_font_size_override("font_size", 16)
	note.add_theme_color_override("font_color", CardTheme.color(&"gold_hi"))
	note.add_theme_constant_override("line_spacing", 6)
	_confirm.add_child(note)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	_confirm.add_child(row)
	_confirm_buttons = []
	for pair in [["ConfirmYes", "rg4.title.confirm_yes", &"WarnButton"], ["ConfirmNo", "rg4.title.confirm_no", &""]]:
		var b := Button.new()
		b.name = pair[0]
		b.text = CardText.ui(pair[1])
		b.theme_type_variation = pair[2]
		b.focus_mode = Control.FOCUS_ALL
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		b.custom_minimum_size = Vector2(0, 44)
		row.add_child(b)
		_confirm_buttons.append(b)
	_confirm_buttons[0].pressed.connect(_confirm_new)
	_confirm_buttons[1].pressed.connect(_cancel_new)
	for i in _confirm_buttons.size():
		var me := _confirm_buttons[i]
		var other := me.get_path_to(_confirm_buttons[1 - i])
		for side in ["focus_neighbor_left", "focus_neighbor_right", "focus_neighbor_top", "focus_neighbor_bottom",
				"focus_next", "focus_previous"]:
			me.set(side, other)
	_confirm_pick(1)


func _confirm_pick(i: int) -> void:
	_confirm_index = clampi(i, 0, _confirm_buttons.size() - 1)
	if _confirm_index < _confirm_buttons.size() and _confirm_buttons[_confirm_index].is_inside_tree():
		_confirm_buttons[_confirm_index].grab_focus()


## Keys while asking: arrows / W A S D switch, Enter / Space press the focused one, Esc is "think again".
func _confirm_key(key: Key) -> bool:
	if key in [KEY_UP, KEY_W, KEY_LEFT, KEY_A, KEY_DOWN, KEY_S, KEY_RIGHT, KEY_D]:
		_confirm_pick(1 - _confirm_index)
	elif key == KEY_ENTER or key == KEY_KP_ENTER or key == KEY_SPACE:
		var vp := get_viewport()
		var focus := vp.gui_get_focus_owner() if vp != null else null
		var i := _confirm_buttons.find(focus as Button) if focus is Button else -1
		_confirm_buttons[i if i >= 0 else _confirm_index].pressed.emit()
	elif key == KEY_ESCAPE:
		_cancel_new()
	else:
		return false
	return true


func _confirm_new() -> void:
	_close_confirm()
	chose.emit(&"new")


func _cancel_new() -> void:
	_close_confirm()
	_select(0)


func _close_confirm() -> void:
	if _confirm == null:
		return
	remove_child(_confirm)
	_confirm.queue_free()
	_confirm = null
	_confirm_buttons = []
	for btn in _buttons:
		btn.visible = true
	var hint := get_node_or_null("Hint") as CanvasItem
	if hint != null:
		hint.visible = true
