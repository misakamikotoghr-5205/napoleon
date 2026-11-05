# 侧边对白气泡（v0.3）：台词贴在说话人旁，不再用底部大对话框。
# 推进：点气泡 / 空格 / 回车 / Esc /「跳过」；选项与行动按钮仍在气泡内。
# （小镇版里 Esc 是暂停菜单，对白用 E / 空格 / 回车 / 点击推进；旧线性版 legacy 仍可用 Esc。）
extends PanelContainer

const Beeper = preload("res://scripts/ui/beeper.gd")

signal advanced
signal option_picked(id)
signal action_picked(kind, id)
signal skipped

const CLICK_GUARD_MS := 180
const BUBBLE_W := 420
const BUBBLE_H_LINE := 140
const BUBBLE_H_OPTS := 220
# 打字时在标点后稍停（秒）；任何补全/跳过都会清掉，不拖慢推进
const PAUSE_STOP := 0.14
const INSTANT_CPS := 1000.0     # 文字速度高于此值视为“瞬间”
const PAUSE_MID := 0.06

var name_lbl: Label
var text_lbl: RichTextLabel
var hint_lbl: Label
var skip_btn: Button
var options_box: VBoxContainer
var actions_box: VBoxContainer
var full_text: String = ""
var full_plain_len: int = 0
var plain_text: String = ""
var _pause_left: float = 0.0
var shown_chars: float = 0.0
var cps: float = 45.0
var waiting_click: bool = false
var typing: bool = false
var instant: bool = false
var beeper = null
var pitch: float = 1.0
var _last_beep_char: int = 0
var _line_done_ms: int = 0
var _guard_armed: bool = false
var _click_hint: String = ""
var side: String = "npc"   # npc | player | narr
var speak_who: String = ""

func _ready() -> void:
	add_theme_stylebox_override("panel", UiStyle.box(Color("#1f1712ee"), Color("#c99a5e"), 3, 2, 12))
	custom_minimum_size = Vector2(BUBBLE_W, BUBBLE_H_LINE)
	var v := UiStyle.vbox(3)
	add_child(v)
	var top := UiStyle.hbox(8)
	v.add_child(top)
	name_lbl = UiStyle.label("", 18, UiStyle.LAMP, false)
	name_lbl.add_theme_font_override("font", UiStyle.title_font())
	name_lbl.add_theme_font_size_override("font_size", 20)
	name_lbl.add_theme_color_override("font_outline_color", Color("#0d0a08"))
	name_lbl.add_theme_constant_override("outline_size", 3)
	top.add_child(name_lbl)
	hint_lbl = UiStyle.label("", 12, UiStyle.MIST, false)
	hint_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	top.add_child(hint_lbl)
	skip_btn = UiStyle.button("跳过 ▶", 12, "wood")
	skip_btn.tooltip_text = "补全这一句并继续（也可按空格 / 回车 / Esc）"
	skip_btn.pressed.connect(skip)
	skip_btn.visible = false
	top.add_child(skip_btn)
	text_lbl = RichTextLabel.new()
	text_lbl.bbcode_enabled = true
	text_lbl.fit_content = false
	text_lbl.scroll_active = false
	text_lbl.custom_minimum_size = Vector2(0, 56)
	text_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	text_lbl.add_theme_font_size_override("normal_font_size", 17)
	text_lbl.add_theme_color_override("default_color", UiStyle.PAPER)
	text_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(text_lbl)
	options_box = UiStyle.vbox(3)
	v.add_child(options_box)
	actions_box = UiStyle.vbox(3)
	v.add_child(actions_box)
	mouse_filter = Control.MOUSE_FILTER_STOP

func set_side(p_side: String, who: String = "") -> void:
	side = p_side
	speak_who = who
	# 气泡描边颜色随说话人侧变化
	var border := Color("#c99a5e") if side == "npc" else (Color("#e8c88a") if side == "player" else Color("#7b8a7b"))
	add_theme_stylebox_override("panel", UiStyle.box(Color("#1f1712ee"), border, 3, 2, 12))

func show_line(who_name: String, text: String, color: Color, is_narr: bool, click_to_continue: bool, voice: float = 1.0) -> void:
	clear_options()
	clear_actions()
	custom_minimum_size = Vector2(BUBBLE_W, BUBBLE_H_LINE)
	text_lbl.custom_minimum_size = Vector2(0, 56)
	name_lbl.text = who_name
	name_lbl.add_theme_color_override("font_color", _readable(color))
	if is_narr:
		full_text = "[i][color=#c8ccc8]" + _esc(text) + "[/color][/i]"
		set_side("narr")
	else:
		full_text = _esc(text)
	plain_text = _plain(full_text)
	full_plain_len = plain_text.length()
	text_lbl.text = full_text
	_last_beep_char = 0
	_pause_left = 0.0
	pitch = voice
	waiting_click = click_to_continue
	_click_hint = "▼" if click_to_continue else ""
	skip_btn.visible = click_to_continue
	hint_lbl.text = ("…" if typing and click_to_continue else _click_hint)
	visible = true
	if instant or full_plain_len == 0:
		shown_chars = float(full_plain_len)
		typing = false
		text_lbl.visible_characters = -1
		_guard_armed = false
	else:
		shown_chars = 0.0
		typing = true
		text_lbl.visible_characters = 0
		_guard_armed = false

func set_hint(t: String) -> void:
	hint_lbl.text = t

func show_options(prompt_name: String, text: String, opts: Array) -> void:
	skip_btn.visible = false
	custom_minimum_size = Vector2(BUBBLE_W, BUBBLE_H_OPTS)
	name_lbl.text = prompt_name
	name_lbl.add_theme_color_override("font_color", _readable(UiStyle.LAMP))
	full_text = _esc(text)
	plain_text = _plain(full_text)
	full_plain_len = plain_text.length()
	_pause_left = 0.0
	text_lbl.text = full_text
	text_lbl.visible_characters = -1
	shown_chars = float(full_plain_len)
	typing = false
	_guard_armed = false
	waiting_click = false
	hint_lbl.text = "选（1–%d）" % mini(opts.size(), 9)
	clear_options()
	clear_actions()
	text_lbl.custom_minimum_size = Vector2(0, 24 if opts.size() > 0 else 56)
	visible = true
	var per_row := 1 if opts.size() <= 3 else 2
	var fsize := 15 if opts.size() <= 3 else 13
	var row: HBoxContainer = null
	for i in range(opts.size()):
		if i % per_row == 0:
			row = UiStyle.hbox(6)
			options_box.add_child(row)
		var b := UiStyle.button("%d. %s" % [i + 1, str(opts[i]["label"])] if i < 9 else str(opts[i]["label"]), fsize, "paper", true)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var id: String = str(opts[i]["id"])
		b.pressed.connect(func(): emit_signal("option_picked", id))
		b.set_meta("opt_id", id)
		row.add_child(b)

func clear_options() -> void:
	for c in options_box.get_children():
		options_box.remove_child(c)
		c.queue_free()

func option_button(id: String) -> Button:
	for row in options_box.get_children():
		for b in row.get_children():
			if b.get_meta("opt_id", "") == id:
				return b
	return null

func show_actions(actions: Array) -> void:
	clear_actions()
	if actions.is_empty():
		return
	custom_minimum_size = Vector2(BUBBLE_W, maxi(BUBBLE_H_LINE, 100 + actions.size() * 28))
	var per_row := 2 if actions.size() <= 4 else 3
	if actions.size() > 2:
		text_lbl.custom_minimum_size = Vector2(0, 28)
	var row: HBoxContainer = null
	for i in range(actions.size()):
		var a: Dictionary = actions[i]
		if i % per_row == 0:
			row = UiStyle.hbox(6)
			actions_box.add_child(row)
		var kind := str(a.get("kind", "extra"))
		var id := str(a.get("id", ""))
		var b := UiStyle.button(str(a.get("label", id)), 13 if actions.size() <= 4 else 12, "wood" if kind == "deal" else "paper", false)
		b.clip_text = true
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.set_meta("act_kind", kind)
		b.set_meta("act_id", id)
		b.pressed.connect(func(): emit_signal("action_picked", kind, id))
		row.add_child(b)

func clear_actions() -> void:
	for c in actions_box.get_children():
		actions_box.remove_child(c)
		c.queue_free()

func action_button(kind: String, id: String) -> Button:
	for row in actions_box.get_children():
		for b in row.get_children():
			if b.get_meta("act_kind", "") == kind and b.get_meta("act_id", "") == id:
				return b
	return null

func _esc(s: String) -> String:
	return s.replace("[", "[lb]")

func _readable(c: Color) -> Color:
	var out := c
	var guard := 0
	while 0.2126 * out.r + 0.7152 * out.g + 0.0722 * out.b < 0.6 and guard < 100:
		out = out.lerp(Color.WHITE, 0.08)
		guard += 1
	return out

func _plain_length(bb: String) -> int:
	return _plain(bb).length()

func _plain(bb: String) -> String:
	var protected := bb.replace("[lb]", "\u0001")
	var rx := RegEx.new()
	rx.compile("\\[[^\\]]*\\]")
	var plain := rx.sub(protected, "", true)
	plain = plain.replace("\u0001", "[")
	return plain

func _process(delta: float) -> void:
	if not typing:
		if _click_hint != "" and hint_lbl.text == "…":
			hint_lbl.text = _click_hint
		return
	if _click_hint != "":
		hint_lbl.text = "…"
	if cps >= INSTANT_CPS:       # 设置里的“瞬间”：第一帧出全句，不按标点停顿
		_finish_now(true)
		return
	if _pause_left > 0.0:
		_pause_left -= delta
		if _pause_left > 0.0:
			return
		delta = -_pause_left
		_pause_left = 0.0
	shown_chars += delta * cps
	_advance_to(mini(int(shown_chars), full_plain_len))
	if _last_beep_char >= full_plain_len:
		_finish_now(true)

# 逐字：每出一个新字嘀一声；碰到标点就停在标点后，稍等再打下一个字
func _advance_to(n: int) -> void:
	if n <= _last_beep_char:
		return
	var stop := n
	var level := 0
	for i in range(_last_beep_char, n):
		level = Beeper.punct_level(plain_text.substr(i, 1))
		if level > 0:
			stop = i + 1
			break
	_last_beep_char = stop
	if level > 0:
		shown_chars = float(stop)
	text_lbl.visible_characters = stop
	if beeper != null:
		beeper.tick(plain_text.substr(stop - 1, 1), pitch)
	if level > 0 and stop < full_plain_len:
		_pause_left = PAUSE_STOP if level == 2 else PAUSE_MID

func _finish_now(arm_guard: bool) -> void:
	shown_chars = float(full_plain_len)
	_last_beep_char = full_plain_len
	_pause_left = 0.0
	text_lbl.visible_characters = -1
	if typing:
		typing = false
		_line_done_ms = Time.get_ticks_msec()
		_guard_armed = arm_guard

func is_typing() -> bool:
	return typing

func finish_typing() -> void:
	_finish_now(false)

func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		click()
		accept_event()

func skip() -> void:
	if not waiting_click:
		return
	finish_typing()
	waiting_click = false
	skip_btn.visible = false
	emit_signal("advanced")
	emit_signal("skipped")

func click() -> void:
	if typing:
		finish_typing()
		_guard_armed = true
		_line_done_ms = Time.get_ticks_msec()
		return
	if not waiting_click:
		return
	if not instant and _guard_armed and Time.get_ticks_msec() - _line_done_ms < CLICK_GUARD_MS:
		return
	waiting_click = false
	emit_signal("advanced")
