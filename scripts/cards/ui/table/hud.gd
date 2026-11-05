# 顶上一条 HUD。日期、时辰天气、黄历条、状态、钱、口碑、风声。主人 C01。合同 §7.11.10。
# preload，不写 class_name。
# 换皮（10-22，网页原型 .hud）：深色两段底 + 1px 金线；最左毛笔金字店名，日期粗体；时辰天气 14 号 text_2；
# 状态是红药丸；钱前面一枚铜钱、数字粗体 gold_pale；风声 2 档 warn、3 档以上 bad。
extends Control

signal money_pressed
signal almanac_pressed

var _brand: Label
var _date: Label
var _weather: Control
var _status: Control
var _money: Button
var _money_unit: Label
var _rep: Label
var _heat: Label
var _almanac: Control

const MONEY_GAP := 3.0
## Coin icon (icon.coin.head 16×16 ×1) sits left of the digits inside the Money button.
const COIN_W := 16.0
const COIN_PAD := 20.0
const MONEY_SIZE := 16
const SMALL := 14
const BRAND_W := 70.0
const PART_GAP := 6.0
const ELLIPSIS := "…"


func _ready() -> void:
	_build()


func refresh(view: Dictionary) -> void:
	_build()
	var date: Dictionary = view.get("date", {})
	_brand.text = CardText.ui("c01.hud.brand")
	_date.text = CardText.ui("c01.hud.date", {
		"y": date.get("y", 0), "m": date.get("m", 0), "d": date.get("d", 0),
		"weekday": date.get("weekday", 0), "day": date.get("stage_day", 0),
		"days": date.get("stage_days", 0),
	})
	_fill_weather(_weather_parts(view))
	_fill_status(view)
	var money: Dictionary = view.get("money", {})
	var unit := "c01.money.unit." + str(money.get("currency", "fabi"))
	_money_unit.text = CardText.ui(unit)
	_layout_money(int(money.get("amount", 0)))
	var rep := clampi(int(view.get("rep_tier", 0)), 0, 4)
	var heat := clampi(int(view.get("heat_tier", 0)), 0, 4)
	_rep.text = CardText.ui("g03.tier.rep.%d" % rep)
	_heat.text = CardText.ui("g03.tier.heat.%d" % heat)
	_heat.add_theme_color_override("font_color", CardTheme.color(&"bad" if heat >= 3 else (&"warn" if heat >= 2 else &"hud_ink")))
	if _almanac != null and _almanac.has_method("refresh"):
		_almanac.call("refresh", view)


func _build() -> void:
	if _date != null:
		return
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	position = CardLayout.HUD.position
	size = CardLayout.HUD.size
	var bg = CardTheme.grad_box(&"hud_bg", &"hud_bg_low", &"", 0.0, 0.0)
	bg.name = "Back"
	bg.size = CardLayout.HUD.size
	add_child(bg)
	var rule := ColorRect.new()
	rule.name = "Rule"
	rule.color = CardTheme.color(&"hud_rule")
	rule.position = Vector2(0, CardLayout.HUD.size.y - 1.0)
	rule.size = Vector2(CardLayout.HUD.size.x, 1)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rule)
	var date_box := CardLayout.HUD_DATE
	_brand = _label(Rect2(date_box.position.x + 2.0, 0, BRAND_W, CardLayout.HUD.size.y), &"")
	_brand.name = "Brand"
	_brand.clip_text = false
	_brand.add_theme_font_override("font", _brand_font())
	_brand.add_theme_font_size_override("font_size", 20)
	_brand.add_theme_color_override("font_color", CardTheme.color(&"gold_hi"))
	_date = _label(Rect2(date_box.position.x + BRAND_W + 4.0, date_box.position.y,
		date_box.size.x - BRAND_W - 4.0, date_box.size.y), &"a.top.date")
	_date.name = "Date"
	_date.add_theme_font_override("font", CardTheme.font_body_bold())
	_weather = _box(CardLayout.HUD_WEATHER, &"a.top.weather")
	_weather.name = "Weather"
	_status = _box(CardLayout.HUD_STATUS, &"")
	_status.name = "Status"
	_money = Button.new()
	_money.focus_mode = Control.FOCUS_ALL
	_money.clip_text = true
	_money.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_money.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_flat(_money, 68.0)
	_money.add_theme_font_override("font", CardTheme.font_body_bold())
	_money.add_theme_font_size_override("font_size", MONEY_SIZE)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		_money.add_theme_color_override(state, CardTheme.color(&"gold_pale"))
	_money.name = "Money"
	_money.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_place(_money, CardLayout.HUD_MONEY)
	_money.pressed.connect(func() -> void: money_pressed.emit())
	add_child(_money)
	var coin_tex := CardArt.texture("icon.coin.head")
	if coin_tex != null:
		var coin := TextureRect.new()
		coin.name = "Coin"
		coin.texture = coin_tex
		coin.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		coin.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		coin.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		coin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		coin.position = Vector2(0, floorf((CardLayout.HUD_MONEY.size.y - COIN_W) * 0.5))
		coin.size = Vector2(COIN_W, COIN_W)
		_money.add_child(coin)
	_money_unit = Label.new()
	_money_unit.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_money_unit.clip_text = true
	_money_unit.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_money_unit.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_money_unit.add_theme_font_override("font", CardTheme.font_body())
	_money_unit.add_theme_font_size_override("font_size", SMALL)
	_money_unit.add_theme_color_override("font_color", CardTheme.color(&"text_2"))
	_money_unit.position = Vector2(56, 0)
	_money_unit.size = Vector2(64, CardLayout.HUD_MONEY.size.y)
	_money_unit.name = "MoneyUnit"
	_money.add_child(_money_unit)
	CardAnchors.register(&"a.top.money", _money)
	_rep = _label(CardLayout.HUD_REP, &"a.top.rep")
	_rep.name = "Rep"
	_rep.add_theme_font_override("font", CardTheme.font_body_bold())
	_heat = _label(CardLayout.HUD_HEAT, &"a.top.heat")
	_heat.name = "Heat"
	_heat.add_theme_font_override("font", CardTheme.font_body_bold())
	var path := CardIds.widget_scene(&"almanac_strip")
	if path != "":
		_almanac = load(path).instantiate()
		_place(_almanac, CardLayout.HUD_ALMANAC)
		_almanac.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_almanac)
	var hit := Button.new()
	hit.name = "AlmanacHit"
	_place(hit, CardLayout.HUD_ALMANAC)
	hit.focus_mode = Control.FOCUS_ALL
	hit.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	# 原型 .alm：悬停底 rgba(232,195,90,.12)、圆角 4。
	var idle := StyleBoxEmpty.new()
	var lit := CardTheme.flat_style(&"reply_hover", &"", 0, 4)
	for state in ["normal", "disabled"]:
		hit.add_theme_stylebox_override(state, idle)
	for state in ["hover", "pressed", "hover_pressed", "focus"]:
		hit.add_theme_stylebox_override(state, lit)
	hit.pressed.connect(func() -> void: almanac_pressed.emit())
	add_child(hit)
	# 悬停底画在黄历字下面：字的 z 高一格（按钮在树里仍在后面，点击照样落到它身上）。
	if _almanac != null:
		_almanac.z_index = 1


## 店名：毛笔 20，字距 .08em。
func _brand_font() -> Font:
	var f := FontVariation.new()
	f.base_font = CardTheme.font_title()
	f.spacing_glyph = 2
	return f


## 金额槽（#216 P2）：七位及以上改用“万”（1234567 → 123万，只舍不入）；量过字形宽度仍放不下就以 … 收尾，
## 绝不把截短的数字当完整余额显示。单位标签的 x 跟着数字实际宽度走；Money 外框 HUD_MONEY 不动。
## 换皮：数字前面留出铜钱的位置（框的左内边距 COIN_PAD）。
func _layout_money(amount: int) -> void:
	var font := CardTheme.font_body_bold()
	var fsize := MONEY_SIZE
	var unit_font := CardTheme.font_body()
	var total := CardLayout.HUD_MONEY.size.x
	var unit_w := minf(ceilf(unit_font.get_string_size(_money_unit.text, HORIZONTAL_ALIGNMENT_LEFT, -1, SMALL).x),
		floorf(total * 0.4))
	var avail := maxf(8.0, total - COIN_PAD - MONEY_GAP - unit_w)
	var text := money_text(amount)
	var text_w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize).x
	if text_w > avail:
		text = _fit_ellipsis(text, avail, font, fsize)
		text_w = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize).x
	text_w = ceilf(text_w)
	_money.text = text
	var digits_w := minf(avail, text_w)
	_flat(_money, total - COIN_PAD - digits_w, COIN_PAD)
	_money_unit.position = Vector2(COIN_PAD + digits_w + MONEY_GAP, 0)
	_money_unit.size = Vector2(maxf(0.0, total - COIN_PAD - digits_w - MONEY_GAP), CardLayout.HUD_MONEY.size.y)


## 金额文字：不足七位原样；七位及以上去掉末四位加“万”。
static func money_text(amount: int) -> String:
	var digits := str(absi(amount))
	var neg := "-" if amount < 0 else ""
	if digits.length() >= 7:
		return neg + digits.left(digits.length() - 4) + CardText.ui("c01.money.wan")
	return neg + digits


func _fit_ellipsis(text: String, avail: float, font: Font, fsize: int) -> String:
	var keep := text.length()
	while keep > 0:
		keep -= 1
		var cand := text.left(keep) + ELLIPSIS
		if font.get_string_size(cand, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize).x <= avail:
			return cand
	return ELLIPSIS


func _label(rect: Rect2, anchor: StringName) -> Label:
	var label := Label.new()
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", CardTheme.font_body())
	label.add_theme_font_size_override("font_size", CardTheme.font_size(&"hud"))
	label.add_theme_color_override("font_color", CardTheme.color(&"hud_ink"))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(label, rect)
	add_child(label)
	if anchor != &"":
		CardAnchors.register(anchor, label)
	return label


func _place(node: Control, rect: Rect2) -> void:
	node.position = rect.position - CardLayout.HUD.position
	node.size = rect.size
	node.custom_minimum_size = rect.size


func _weather_parts(view: Dictionary) -> PackedStringArray:
	var stage: Dictionary = view.get("stage", {})
	var notice: Dictionary = view.get("notice", {})
	var time := str(stage.get("time", "day"))
	if time not in ["day", "dusk", "night"]:
		time = "day"
	var parts := PackedStringArray()
	parts.append(CardText.ui("c01.hud.time." + time))
	var weather := str(notice.get("weather", ""))
	if weather != "":
		parts.append(CardText.ui("g05.weather." + weather))
	return parts


func _box(rect: Rect2, anchor: StringName) -> Control:
	var box := Control.new()
	_place(box, rect)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.clip_contents = true
	add_child(box)
	if anchor != &"":
		CardAnchors.register(anchor, box)
	return box


func _clear(box: Control) -> void:
	for child in box.get_children():
		box.remove_child(child)
		child.free()


## 时辰 · 天气：14 号 text_2，一段接一段，中间是间隔号；放不下的最后一段以 … 收尾。
func _fill_weather(parts: PackedStringArray) -> void:
	_clear(_weather)
	var font := CardTheme.font_body()
	var x := 0.0
	var sep := CardText.ui("c01.hud.sep")
	for i in range(parts.size()):
		if parts[i] == "":
			continue
		if x > 0.0:
			x = _flow_label(_weather, sep, x, font, &"text_3")
		x = _flow_label(_weather, parts[i], x, font, &"text_2")
		if x >= _weather.size.x:
			break


func _flow_label(box: Control, text: String, x: float, font: Font, tone: StringName) -> float:
	if x >= box.size.x:
		return x
	var w := ceilf(font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, SMALL).x)
	var label := Label.new()
	label.text = text
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", SMALL)
	label.add_theme_color_override("font_color", CardTheme.color(tone))
	label.position = Vector2(x, 0)
	label.size = Vector2(minf(w, box.size.x - x), box.size.y)
	box.add_child(label)
	return x + w


## 状态：在街上 / 在牢里 / 查封是红药丸（白字 14）；集市日是金边木色药丸（时辰天气那格 100px 放不下它）；
## 本月运势 14 号金字。
func _fill_status(view: Dictionary) -> void:
	_clear(_status)
	var stage: Dictionary = view.get("stage", {})
	var notice: Dictionary = view.get("notice", {})
	var pills: Array = []
	var mode := str(view.get("mode", ""))
	var set_name := str(stage.get("set", ""))
	if mode == "street":
		pills.append([CardText.ui("c01.hud.status.street"), false])
	if mode == "prison" or set_name == "prison":
		pills.append([CardText.ui("c01.hud.status.prison"), false])
	if bool(stage.get("sealed", false)):
		pills.append([CardText.ui("c01.hud.status.sealed"), false])
	if bool(notice.get("market_day", false)):
		pills.append([CardText.ui("c01.hud.market"), true])
	var x := 0.0
	for entry in pills:
		if x >= _status.size.x:
			break
		var text: String = entry[0]
		var market: bool = entry[1]
		var pill := PanelContainer.new()
		pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if market:
			pill.add_theme_stylebox_override("panel", CardTheme.pill_style(&"wood_2", &"gold_deep", 3, 8.0, 0.0))
		else:
			pill.add_theme_stylebox_override("panel", CardTheme.pill_style(&"seal_dark", &"", 3, 8.0, 0.0))
		pill.clip_contents = true
		var label := Label.new()
		label.text = text
		label.clip_text = true
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.add_theme_font_size_override("font_size", SMALL)
		label.add_theme_constant_override("line_spacing", -4)
		label.add_theme_color_override("font_color", CardTheme.color(&"gold_pale" if market else &"btn_warn_ink"))
		# clip_text 的 Label 最小宽是 0，药丸会缩成一个空框；按字形量出宽度撑住，放不下再由外面截。
		var text_w := ceilf(CardTheme.font_body().get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, SMALL).x)
		label.custom_minimum_size = Vector2(minf(text_w, _status.size.x - x - 16.0), 0.0)
		pill.add_child(label)
		_status.add_child(pill)
		pill.reset_size()
		var w := minf(pill.size.x, _status.size.x - x)
		pill.position = Vector2(x, floorf((_status.size.y - pill.size.y) * 0.5))
		pill.size = Vector2(w, pill.size.y)
		x += w + PART_GAP
	var seg := str(notice.get("fortune", ""))
	if seg != "" and x < _status.size.x:
		var fortune := CardText.ui("c01.hud.fortune", {"seg": CardText.t(seg + "#title")})
		var font := CardTheme.font_body()
		_flow_label(_status, fortune, x, font, &"gold_hi")


func _flat(button: Button, right_margin: float = 0.0, left_margin: float = 0.0) -> void:
	var empty := StyleBoxEmpty.new()
	empty.content_margin_right = right_margin
	empty.content_margin_left = left_margin
	for state in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
		button.add_theme_stylebox_override(state, empty)
