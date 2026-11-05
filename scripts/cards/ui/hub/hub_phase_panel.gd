# 远洋战役的高清过场面板：开部（month_open）、日终结账（settle）、换部（year_jump）、航程终了（game_over）。
# 远洋战役开着时宿主把这四种面板换成它（modal_host.overrides，kind 不变）；旧版战役照旧用像素面板。
# 满屏：背景（开部 / 换部是夜航，结账是营帐，终了有结局插图用插图），中间一条章节卡横带：小字、大标题、金线、
# 几行说明（结账和换部是引擎的报表行），底下一个金色按钮。指令和旧面板一样：
#   month_open：按钮只关面板（开部由营地的“启航 · 开始本部”发）；settle：按钮发 settle.next 再关；
#   year_jump：按钮发 year.next 再关；game_over：按钮和 Esc 都是回到标题（close_requested {"to_title": true}）。
# 别的 Esc / dismiss 只关面板、不发指令（和旧面板一样）。字在 data/hd/hub_ui.json 的 phase.*，没有 class_name。
extends CardPanel

const HdTheme = preload("res://scripts/cards/ui/hd/hd_theme.gd")
const HdArt = preload("res://scripts/cards/ui/hd/hd_art.gd")
const HdPlaceholder = preload("res://scripts/cards/ui/hd/hd_placeholder.gd")
const Data = preload("res://scripts/cards/ui/hub/hub_data.gd")
const Kit = preload("res://scripts/cards/ui/hub/hub_kit.gd")
const Deco = preload("res://scripts/cards/ui/vn/vn_deco.gd")

const ENDING_CG := ["alliance", "ghost", "dark", "tragedy"]

## 宿主按登记的 kind 设（month_open settle year_jump game_over）
var kind: StringName = &"settle"
var fast := false

var _closed := false
var _built := false
var _args: Dictionary = {}
var _kicker: Label
var _title: Label
var _lines: Label
var _btn: Button
var _note: Label


func open(args: Dictionary) -> void:
	_args = args.duplicate(true)
	_closed = false
	var host := get_parent()
	if host != null and "fast" in host:
		fast = fast or bool(host.get("fast"))
	_build()
	_fill()
	if not fast:
		modulate.a = 0.0
		create_tween().tween_property(self, "modulate:a", 1.0, 0.35)


func refresh(_view: Dictionary) -> void:
	if _built and not _closed:
		_fill()


func dismiss() -> void:
	if _closed:
		return
	_close({"to_title": true} if kind == &"game_over" else {})


func autoplay_step() -> bool:
	if _closed:
		return false
	_confirm()
	return true


## 金色按钮：settle 发 settle.next，year_jump 发 year.next，game_over 回标题，month_open 只关
func _confirm() -> void:
	if _closed:
		return
	match kind:
		&"settle":
			var r: Dictionary = engine.send(&"settle.next", {}) if engine != null else {}
			if not bool(r.get("ok", false)):
				return
			_close({})
		&"year_jump":
			if engine != null:
				engine.send(&"year.next", {})
			_close({})
		&"game_over":
			_close({"to_title": true})
		_:
			_close({})


func _close(result: Dictionary) -> void:
	if _closed:
		return
	_closed = true
	close_requested.emit(result)


func _unhandled_input(event: InputEvent) -> void:
	if _closed or not (event is InputEventKey):
		return
	var ke := event as InputEventKey
	if ke.pressed and not ke.echo and ke.keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]:
		_confirm()
		var vp := get_viewport()
		if vp != null:
			vp.set_input_as_handled()


# ================================================================ 内容

func _fill() -> void:
	var v: Dictionary = engine.view() if engine != null else {}
	var c: Dictionary = engine.query(&"campaign") if engine != null else {}
	var def := "ocean.scene." + str(c.get("scene_id", ""))
	match kind:
		&"month_open":
			_kicker.text = Data.text("phase.month_open_kicker")
			_title.text = CardText.card(def, "chapter")
			var money: Dictionary = v.get("money", {}) if typeof(v.get("money", {})) == TYPE_DICTIONARY else {}
			var sub := Data.text("phase.month_open_sub", {"currency": CardText.ui("c01.money.unit." + str(money.get("currency", "")))})
			var scene_title := CardText.card(def, "title")
			if scene_title != "" and not Data.same_title(_title.text, scene_title):
				sub += "\n" + scene_title
			_lines.text = sub
			_btn.text = Data.text("phase.month_open_btn")
		&"settle":
			_kicker.text = Data.text("phase.settle_kicker")
			_title.text = Data.text("phase.settle_title", {"day": int(v.get("date", {}).get("abs_day", 0))})
			_lines.text = _report(&"settle_report")
			_btn.text = Data.text("phase.settle_btn")
		&"year_jump":
			_kicker.text = Data.text("phase.year_kicker")
			_title.text = Data.text("phase.year_title")
			_lines.text = _report(&"year_report")
			_btn.text = Data.text("phase.year_btn")
		&"game_over":
			_kicker.text = Data.text("phase.over_kicker")
			var reason := str(_args.get("reason", ""))
			if reason == "":
				reason = str(v.get("game_over_reason", ""))
			var text := CardText.t("g02.ending." + reason) if reason != "" else ""
			var parts := text.split("\n\n", false, 1)
			_title.text = parts[0] if parts.size() > 0 else ""
			_lines.text = parts[1] if parts.size() > 1 else ""
			_btn.text = Data.text("phase.over_btn")
			_note.text = Data.text("phase.over_note")
	_note.visible = _note.text != ""


## 引擎报表（settle_report / year_report 的 lines，键是 CardText 引用），一行一段
func _report(q: StringName) -> String:
	var out := PackedStringArray()
	if engine == null:
		return ""
	var r = engine.query(q, {})
	if typeof(r) != TYPE_DICTIONARY:
		return ""
	for row in r.get("lines", []):
		if typeof(row) != TYPE_DICTIONARY:
			continue
		var key := str(row.get("key", ""))
		if key == "":
			continue
		var args = row.get("args", {})
		var t := Data.unpage(CardText.ui(key, args if typeof(args) == TYPE_DICTIONARY else {}))
		if t != "":
			out.append(t.strip_edges())
	return "\n".join(out)


# ================================================================ 搭界面

func _build() -> void:
	if _built:
		return
	_built = true
	size = Vector2(1280, 720)
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	HdTheme.apply_hd_filter(self)
	var base := ColorRect.new()
	base.color = HdTheme.color("hd_ink")
	base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	base.size = size
	add_child(base)
	add_child(_backdrop())
	var dim := Deco.new().setup("dim")
	dim.size = size
	add_child(dim)
	var band := Deco.new().setup("band")
	band.position = Vector2(0, 60)
	band.size = Vector2(1280, 560)
	add_child(band)
	var col := VBoxContainer.new()
	col.name = "Column"
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override(&"separation", 10)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.position = Vector2(200, 180)
	col.size = Vector2(880, 300)
	add_child(col)
	_kicker = Kit.label("", 16, "sans_bold", "hd_gold")
	_kicker.name = "Kicker"
	_kicker.add_theme_font_override(&"font", HdTheme.font("sans_bold", 4))
	_kicker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_kicker)
	_title = Kit.label("", 40, "title", "hd_text")
	_title.name = "Heading"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_title.custom_minimum_size = Vector2(880, 0)
	col.add_child(_title)
	var rule := Deco.new().setup("rule")
	rule.custom_minimum_size = Vector2(880, 16)
	col.add_child(rule)
	var scroll := ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(880, 196)
	scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	col.add_child(scroll)
	_lines = Kit.wrap("", 16, "serif", "hd_text_2")
	_lines.name = "Lines"
	_lines.custom_minimum_size = Vector2(860, 0)
	_lines.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lines.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lines.add_theme_constant_override(&"line_spacing", 4)
	scroll.add_child(_lines)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.position = Vector2(0, 528)
	row.size = Vector2(1280, 52)
	add_child(row)
	_btn = Button.new()
	_btn.name = "BtnPhase"
	HdTheme.apply_button(_btn, "primary")
	_btn.custom_minimum_size = Vector2(240, 50)
	_btn.focus_mode = Control.FOCUS_ALL
	_btn.pressed.connect(_confirm)
	row.add_child(_btn)
	_note = Kit.label("", 13, "sans", "hd_text_3")
	_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_note.position = Vector2(0, 586)
	_note.size = Vector2(1280, 22)
	add_child(_note)


func _backdrop() -> Control:
	var node: Control
	if kind == &"game_over":
		var reason := str(_args.get("reason", ""))
		if reason == "" and engine != null:
			reason = str(engine.view().get("game_over_reason", ""))
		node = HdPlaceholder.make_cg("ending_" + reason if reason in ENDING_CG else "ending_tragedy", "", "")
	elif kind == &"settle":
		node = HdPlaceholder.make_bg("camp_tent")
	else:
		node = HdPlaceholder.make_bg("title")
	if HdPlaceholder.is_placeholder(node):
		node.set("title_alpha", 0.0)
	node.set_anchors_preset(Control.PRESET_TOP_LEFT)
	node.position = Vector2.ZERO
	node.size = Vector2(1280, 720)
	return node
