# 设置：音乐、音效、文字速度、新手提示、快动画。旧四键走 town/settings.gd，不往那份文件加新键。
# fast_anim 只写 user://cards/settings.json（或 args.cards_settings_path）。主人 C16（换皮这一轮归 C01 外框那一路改）。
# 换皮（10-22，原型 38_drawer_settings）：排在右抽屉里，深底浅字，每行左边说明、右边小按钮，行间细线。
# 合同：docs/cards/CARDS_INTERFACES.md §3.3 C16、§7.8、§7.10.8。锚点 a.settings.guide_toggle。
class_name CardSettings
extends CardPanel

const SettingsScript = preload("res://scripts/town/settings.gd")
const DrawerHost = preload("res://scripts/cards/ui/table/drawer_host.gd")
const DEFAULT_LEGACY := "user://settings.json"
const DEFAULT_CARDS := "user://cards/settings.json"

var _legacy_path: String = DEFAULT_LEGACY
var _cards_path: String = DEFAULT_CARDS
var _bag = null
var _fast: bool = false
var _closed: bool = false
var _music: HSlider
var _sfx: HSlider
var _guide_btn: Button
var _fast_btn: Button
var _focus: Array[Control] = []
var _index: int = 0

const PAD := 14.0
const ROW_H := 52.0


# TODO(design): not frozen in the contract. [api] C16: confirm CardSettings.fast_anim for animation readers.
static func fast_anim(path: String = "user://cards/settings.json") -> bool:
	if path == "" or not FileAccess.file_exists(path):
		return false
	var parsed = CardDB.read_json(path)
	if typeof(parsed) != TYPE_DICTIONARY:
		return false
	return bool(parsed.get("fast_anim", false))


func open(args: Dictionary) -> void:
	_closed = false
	_legacy_path = _path_of(args, "settings_path", DEFAULT_LEGACY)
	_cards_path = _path_of(args, "cards_settings_path", DEFAULT_CARDS)
	_bag = SettingsScript.new(_legacy_path)
	_bag.load_file()
	_fast = CardSettings.fast_anim(_cards_path)
	# 抽屉面板挂在叠层宿主下、满屏；根不吃鼠标（点抽屉外面落到遮罩上 = 合上），只有身子那块吃。
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for c in get_children():
		c.free()
	_focus = []
	_build()


func refresh(_view: Dictionary) -> void:
	pass


func autoplay_step() -> bool:
	if _closed:
		return false
	_closed = true
	close_requested.emit({})
	return true


func _path_of(args: Dictionary, key: String, fallback: String) -> String:
	var raw := str(args.get(key, ""))
	return raw if raw != "" else fallback


func _build() -> void:
	# b22：设置是右抽屉（PANEL_SHOW drawer_r）。框、标题“设置”、“合上”、遮罩都由抽屉宿主画；
	# 这里只在抽屉身子里排几行（原型 38_drawer_settings：左边说明、右边小按钮，行间一道细线）。
	var body: Rect2 = DrawerHost.content_rect("r")
	var box := Control.new()
	box.name = "Body"
	box.position = Vector2(body.position.x + PAD, body.position.y + 12.0)
	box.size = Vector2(body.size.x - PAD * 2.0, body.size.y - 24.0)
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
	y += ROW_H + 8.0
	var close := Button.new()
	close.name = "Back"
	close.text = CardText.ui("c16.settings.close")
	close.focus_mode = Control.FOCUS_ALL
	close.pressed.connect(func() -> void: autoplay_step())
	box.add_child(close)
	close.reset_size()
	close.position = Vector2(box.size.x - close.size.x, y)
	_focus.append(close)
	_grab_first()


func _grab_first() -> void:
	if _focus.is_empty():
		return
	var c := _focus[0]
	if c.is_inside_tree():
		c.grab_focus()
	else:
		c.tree_entered.connect(c.grab_focus, CONNECT_ONE_SHOT)


## One row: caption on the left, control(s) on the right, a 1px line under it.
func _row(box: Control, key: String, y: float) -> void:
	var lab := Label.new()
	lab.text = CardText.ui(key)
	lab.position = Vector2(0, y)
	lab.size = Vector2(box.size.x * 0.5, ROW_H - 1.0)
	lab.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lab.add_theme_font_size_override("font_size", 16)
	lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(lab)
	var line := ColorRect.new()
	line.color = CardTheme.color(&"line")
	line.position = Vector2(0, y + ROW_H - 1.0)
	line.size = Vector2(box.size.x, 1)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(line)


func _slider_row(box: Control, key: String, y: float, value: int, cb: Callable) -> HSlider:
	_row(box, key, y)
	var num := Label.new()
	num.name = key + ".value"
	num.text = str(value)
	num.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	num.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	num.position = Vector2(box.size.x - 40.0, y)
	num.size = Vector2(40, ROW_H - 1.0)
	num.add_theme_color_override("font_color", CardTheme.color(&"gold_pale"))
	box.add_child(num)
	var slider := HSlider.new()
	slider.min_value = 0
	slider.max_value = 100
	slider.step = 1
	slider.position = Vector2(box.size.x * 0.42, y + floorf((ROW_H - 24.0) * 0.5))
	slider.size = Vector2(box.size.x * 0.58 - 48.0, 24)
	slider.set_value_no_signal(value)
	slider.value_changed.connect(cb)
	box.add_child(slider)
	slider.set_meta("readout", num)
	_focus.append(slider)
	return slider


## b46：四档文字速度写成字（慢 / 中 / 快 / 瞬间），当前那档是金色主按钮。
func _speed_row(box: Control, y: float) -> void:
	_row(box, "c16.settings.text_speed", y)
	var x := box.size.x
	var buttons: Array[Button] = []
	for i in range(3, -1, -1):
		var btn := Button.new()
		btn.name = "Speed%d" % i
		btn.text = CardText.ui("c16.settings.speed.%d" % i)
		btn.theme_type_variation = &"SmallButton"
		btn.set_meta("speed", i)
		btn.focus_mode = Control.FOCUS_ALL
		var speed := i
		btn.pressed.connect(func() -> void: _on_speed(speed))
		box.add_child(btn)
		btn.reset_size()
		btn.size = Vector2(maxf(btn.size.x, 40.0), 30)
		x -= btn.size.x
		btn.position = Vector2(x, y + floorf((ROW_H - 30.0) * 0.5))
		x -= 6.0
		buttons.push_front(btn)
	for btn in buttons:
		_focus.append(btn)
	_paint_speed()


func _toggle_row(box: Control, key: String, y: float, on: bool, cb: Callable) -> Button:
	_row(box, key, y)
	var btn := Button.new()
	btn.theme_type_variation = &"SmallButton"
	btn.text = CardText.ui("c16.settings.on" if on else "c16.settings.off")
	btn.focus_mode = Control.FOCUS_ALL
	btn.pressed.connect(cb)
	box.add_child(btn)
	btn.reset_size()
	btn.size = Vector2(maxf(btn.size.x, 72.0), maxf(btn.size.y, 30.0))
	btn.position = Vector2(box.size.x - btn.size.x, y + floorf((ROW_H - btn.size.y) * 0.5))
	_focus.append(btn)
	return btn


func _on_music(v: float) -> void:
	_bag.music = clampi(int(v), 0, 100)
	_readout(_music, _bag.music)
	_bag.save_file()
	_notify_listeners()


func _on_sfx(v: float) -> void:
	_bag.sfx = clampi(int(v), 0, 100)
	_readout(_sfx, _bag.sfx)
	_bag.save_file()
	_notify_listeners()


func _on_speed(speed: int) -> void:
	_bag.text_speed = clampi(speed, 0, 3)
	_paint_speed()
	_bag.save_file()
	_notify_listeners()


func _on_guide() -> void:
	_bag.guide_hints = not bool(_bag.guide_hints)
	_guide_btn.text = CardText.ui("c16.settings.on" if _bag.guide_hints else "c16.settings.off")
	_bag.save_file()
	var tree := get_tree()
	if tree != null:
		tree.call_group("card_guide", "set_enabled", bool(_bag.guide_hints))


func _on_fast() -> void:
	_fast = not _fast
	_fast_btn.text = CardText.ui("c16.settings.on" if _fast else "c16.settings.off")
	_write_fast()
	_notify_listeners()


## 存盘后通知牌桌（card_settings_listeners 组的 on_settings_changed）：音乐音量、文字速度、快动画马上生效。
func _notify_listeners() -> void:
	var tree := get_tree()
	if tree != null:
		tree.call_group("card_settings_listeners", "on_settings_changed")


func _paint_speed() -> void:
	var cur := int(_bag.text_speed)
	for c in _focus:
		if c is Button and c.has_meta("speed"):
			var on := int(c.get_meta("speed")) == cur
			(c as Button).theme_type_variation = &"PrimaryButton" if on else &"SmallButton"
			c.add_theme_font_size_override("font_size", 14)


func _readout(slider: HSlider, value: int) -> void:
	var num = slider.get_meta("readout")
	if num is Label:
		(num as Label).text = str(value)


func _write_fast() -> void:
	DirAccess.make_dir_recursive_absolute(_cards_path.get_base_dir())
	var f := FileAccess.open(_cards_path, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({"fast_anim": _fast}))
	f.close()


func _unhandled_input(event: InputEvent) -> void:
	if _closed or not (event is InputEventKey) or not (event as InputEventKey).pressed:
		return
	if (event as InputEventKey).echo:
		return
	var key := (event as InputEventKey).keycode
	if key == KEY_UP or key == KEY_W:
		_move_focus(-1)
	elif key == KEY_DOWN or key == KEY_S:
		_move_focus(1)
	elif key == KEY_LEFT or key == KEY_A:
		_nudge(-5)
	elif key == KEY_RIGHT or key == KEY_D:
		_nudge(5)
	elif key == KEY_ENTER or key == KEY_KP_ENTER or key == KEY_SPACE:
		_activate_focus()
	else:
		return
	var vp := get_viewport()
	if vp != null:
		vp.set_input_as_handled()


func _move_focus(dir: int) -> void:
	if _focus.is_empty():
		return
	_index = _wrap(_index + dir, _focus.size())
	_focus[_index].grab_focus()


func _wrap(i: int, n: int) -> int:
	var x := i
	while x < 0:
		x += n
	while x >= n:
		x -= n
	return x


func _nudge(delta: int) -> void:
	if _index < 0 or _index >= _focus.size():
		return
	var c := _focus[_index]
	if c == _music:
		_music.value = clampf(_music.value + delta, 0, 100)
	elif c == _sfx:
		_sfx.value = clampf(_sfx.value + delta, 0, 100)


func _activate_focus() -> void:
	if _index < 0 or _index >= _focus.size():
		return
	var c := _focus[_index]
	if c is Button:
		(c as Button).pressed.emit()
