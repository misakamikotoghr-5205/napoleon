# 远洋战役的高清营地（主画面）：盖在旧的像素柜台和手牌扇上面，远洋战役开着、标题收起时显示。
# 只借策略游戏“营地 / 指挥部”的通用版式：顶栏（部、场次、日期、金库和各项指标）、左栏伙伴名册（头像、等级、兵力）
# 和功能币、中间当前剧情大卡（这一场的背景缩图、标题、地点、鉴定进度、能不能作决定）、本场战事卡（或战败后的大命运红卡）、
# 催逼、航海日志；右栏营地事务（挂牌、街区、后门、资源、行军、周历、名册、账簿，可办的件数）、行军箱、结账按钮。
# 点一张卡等于打出手里那张牌（根场景的 _open_card：剧情开 VN、战场开出征名单 / 战场 / 战果，别的开高清事务面板）；
# 结账按钮等于旧的“打烊 / 下一天”大铜牌（根场景的 _on_close_day，字也由根场景给）。
# 只读 engine.view() / engine.query(campaign | card)，不发指令。字在 data/hd/hub_ui.json，颜色走 hd_* 键。没有 class_name。
# 说明：docs/cards/HD_UI.md「营地」。
extends Control

signal card_pressed(uid: String)
signal end_pressed
signal open_requested(kind: StringName, args: Dictionary)
signal menu_pressed

const HdTheme = preload("res://scripts/cards/ui/hd/hd_theme.gd")
const HdArt = preload("res://scripts/cards/ui/hd/hd_art.gd")
const HdPlaceholder = preload("res://scripts/cards/ui/hd/hd_placeholder.gd")
const D = preload("res://scripts/cards/ui/hd/hd_draw.gd")
const Data = preload("res://scripts/cards/ui/hub/hub_data.gd")
const Kit = preload("res://scripts/cards/ui/hub/hub_kit.gd")
const Portrait = preload("res://scripts/cards/ui/battle/hud/hud_portrait.gd")
const W = preload("res://scripts/cards/ui/battle/hud/hud_widgets.gd")

const SIDES := ["signage", "town", "backdoor", "resources", "march", "calendar", "squad", "status"]
const GAUGES := ["treasury", "morale", "heat", "vitality"]
const COINS := ["gold", "supply", "medal", "intel"]
const APPRAISE := "action:appraise:"
## 航海日志的账目行（ocean_view._ledger_text）：“第 N 日 · 记录”
const LEDGER_DAY := "\u7B2C "
const LEDGER_SEP := " \u00B7 "
const TOP_H := 60.0
const LEFT := Rect2(16, 72, 276, 548)
const COINS_RECT := Rect2(16, 630, 276, 76)
const STORY := Rect2(308, 72, 648, 246)
const BATTLE := Rect2(308, 330, 648, 112)
const DEMANDS_Y := 454.0
const DEMAND_SIZE := Vector2(208, 84)
const RIGHT := Rect2(968, 72, 296, 408)
const KIT := Rect2(968, 492, 296, 124)
const END := Rect2(968, 628, 296, 78)
## 营地事务栏：标题、上下内边距占的高度，行距，行高上下限
const CAMP_CHROME := 70.0
const CAMP_GAP := 4.0
const CAMP_ROW_MIN := 34.0
const CAMP_ROW_MAX := 42.0
const PORTRAIT_HERO := 58.0
const PORTRAIT := 42.0

var engine: CardEngineApi = null
## 快动画（测试、自动试玩）：不淡入、不飘字
var fast := false

var _built := false
var _view: Dictionary = {}
var _campaign: Dictionary = {}
var _bg_key := ""
var _last_values: Dictionary = {}
var _end_tone := "day"
## 盖着时来过新视图，还没重排
var _dirty := false

var _bg_layer: Control
var _bg_node: Control
var _float_layer: Control
var _chapter_label: Label
var _scene_label: Label
var _gauge_row: HBoxContainer
var _gauge_values: Dictionary = {}
var _roster_box: VBoxContainer
var _roster_count: Label
var _coin_values: Dictionary = {}
var _story: Button
var _battle: Button
var _fate: Button
var _demands: HBoxContainer
var _log_panel: PanelContainer
var _log_box: VBoxContainer
var _camp_box: VBoxContainer
var _kit_flow: HFlowContainer
var _kit_empty: Label
var _end: Button
var _end_title: Label
var _end_sub: Label


func _init() -> void:
	name = "Hub"
	size = Vector2(1280, 720)
	mouse_filter = Control.MOUSE_FILTER_STOP
	HdTheme.apply_hd_filter(self)
	visibility_changed.connect(_on_visibility)


func bind(p_engine: CardEngineApi) -> void:
	engine = p_engine


## 根场景每次视图变了都调。covered = 标题或满屏面板盖着：只记下视图，等露出来（再调一次 covered = false）才重排
func refresh(view: Dictionary, covered: bool = false) -> void:
	_view = view
	if engine == null:
		return
	if covered and _built:
		_dirty = true
		return
	_dirty = false
	var c = engine.query(&"campaign")
	_campaign = c if typeof(c) == TYPE_DICTIONARY else {}
	if not _campaign.has("scene_id"):
		return
	_ensure()
	_fill_bg()
	_fill_top()
	_fill_roster()
	_fill_coins()
	_fill_story()
	_fill_battle()
	_fill_demands()
	_fill_log()
	_fill_camp()
	_fill_kit()
	_float_changes()


## 结账按钮的字和样子由根场景给（和旧的大铜牌同一套：开张 / 结账 · 等待明日 / 迎接次日 …）。
## tone：day（还有事可办）ready（都办完了）confirm（再按一下确认）night
func set_end_state(title: String, sub: String, tone: String) -> void:
	_ensure()
	# 白天还有正事没办（剧情没定、本场的仗没打、大命运没处理、营地还有可办的事）：结账按钮不当主角，
	# 副行写清楚还剩什么，金色留给“开始剧情 / 排兵出征”这一步
	var left := pending_parts()
	if tone in ["ready", "day"] and str(_view.get("phase", "")) == "day" and not left.is_empty():
		sub = Data.text("sep_short").join(left)
		tone = "day"
	_end_title.text = title
	_end_sub.text = sub
	_end_sub.visible = sub != ""
	if tone != _end_tone:
		_end_tone = tone
		HdTheme.apply_button(_end, "danger" if tone == "confirm" else ("primary" if tone == "ready" else "secondary"))
		_end.custom_minimum_size = END.size
		_end.text = ""
	var ink := "hd_ink" if tone == "ready" else "hd_gold_hi"
	_end_title.add_theme_color_override(&"font_color", HdTheme.color(ink if tone != "confirm" else "hd_text"))
	_end_sub.add_theme_color_override(&"font_color", HdTheme.alpha(ink if tone != "confirm" else "hd_text", 0.75))


## 今天还没办的正事（营地上的说法）：剧情未定、本场的仗还没打、大命运待决、还能办 N 件；都办了是空的
func pending_parts() -> PackedStringArray:
	var out := PackedStringArray()
	if _campaign.is_empty() or str(_view.get("phase", "")) != "day":
		return out
	if _story_pending():
		out.append(Data.text("end_pending.story"))
	if _hand_has("big_fate"):
		out.append(Data.text("end_pending.fate"))
	elif _battle_pending():
		out.append(Data.text("end_pending.battle"))
	var n := 0
	for uid in SIDES:
		if _hand_has(uid):
			n += _enabled_count(uid)
	if n > 0:
		out.append(Data.text("end_pending.left", {"n": n}))
	return out


## 这一场的剧情牌还在手里、还没作决定
func _story_pending() -> bool:
	var scene_id := str(_campaign.get("scene_id", ""))
	return scene_id != "" and _hand_has("story:" + scene_id)


## 这一场有仗、还没了结（打赢、撤出或处理完大命运）
func _battle_pending() -> bool:
	var b2: Dictionary = _campaign.get("battle2", {}) if typeof(_campaign.get("battle2", {})) == TYPE_DICTIONARY else {}
	return _hand_has("battle") and bool(b2.get("has_battle", false)) and not bool(b2.get("resolved", false))


## 测试和根场景用：营地上那张牌的按钮（uid：story:<场次> battle big_fate signage … demand:<id> item:<id> prop:<id> companion:<id>）
func card_button(uid: String) -> Button:
	for b in _all_buttons():
		if b.has_meta("uid") and str(b.get_meta("uid")) == uid and b.is_visible_in_tree():
			return b
	return null


func end_button() -> Button:
	_ensure()
	return _end


# ================================================================ 背景

func _fill_bg() -> void:
	var spec := Data.scene_bg(str(_campaign.get("scene_id", "")))
	var id := str(spec.get("id", ""))
	if id == "":
		id = "camp_tent"
	var variant := str(spec.get("variant", ""))
	var key := id + "__" + variant
	if key == _bg_key:
		return
	_bg_key = key
	var node := HdPlaceholder.make_bg(id, "", "", variant)
	node.name = "Bg_" + id
	if HdPlaceholder.is_placeholder(node):
		node.set("title_alpha", 0.0)
	_bg_layer.add_child(node)
	node.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var old := _bg_node
	_bg_node = node
	if old == null or fast or not is_visible_in_tree():
		if old != null:
			old.queue_free()
		return
	node.modulate.a = 0.0
	var tw := node.create_tween()
	tw.tween_property(node, "modulate:a", 1.0, 0.6)
	tw.tween_callback(func() -> void:
		if is_instance_valid(old):
			old.queue_free())


# ================================================================ 顶栏

func _fill_top() -> void:
	var def := "ocean.scene." + str(_campaign.get("scene_id", ""))
	var chapter := CardText.card(def, "chapter")
	var date: Dictionary = _view.get("date", {})
	_chapter_label.text = chapter if chapter != "" else Data.text("brand")
	# 场次、日期在前（短、要紧），这一场的标题放最后，放不下时省略的是标题
	var parts := PackedStringArray()
	parts.append(Data.text("scene_no", {"n": int(date.get("stage_day", 1)), "total": int(date.get("stage_days", 1))}))
	parts.append(Data.text("date", {"y": int(date.get("y", 0)), "m": int(date.get("m", 0)), "d": int(date.get("d", 0))}))
	var title := CardText.card(def, "title")
	if title != "" and not Data.same_title(chapter, title):
		parts.append(title)
	_scene_label.text = Data.text("sep_short").join(parts)
	_scene_label.tooltip_text = _scene_label.text
	var ids: Array = GAUGES.duplicate()
	ids.append("exploration" if str(_campaign.get("chapter_id", "")) == "nautilus" else "construction")
	var amounts := _gauge_amounts()
	if _gauge_row.get_child_count() != ids.size() or not _gauge_values.has(ids.back()):
		Kit.clear(_gauge_row)
		_gauge_values.clear()
		for i in ids.size():
			var id := str(ids[i])
			if i > 0:
				var sep := ColorRect.new()
				sep.color = HdTheme.alpha("hd_gold", 0.22)
				sep.custom_minimum_size = Vector2(1, 30)
				sep.size_flags_vertical = Control.SIZE_SHRINK_CENTER
				sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
				_gauge_row.add_child(sep)
			var col := VBoxContainer.new()
			col.name = "Gauge_" + id
			col.add_theme_constant_override(&"separation", -2)
			col.custom_minimum_size = Vector2(76 if id != "treasury" else 100, 0)
			col.mouse_filter = Control.MOUSE_FILTER_PASS
			col.tooltip_text = Data.text("gauge_tip." + id)
			var cap := Kit.label(Data.text("gauge." + id), 11, "sans", "hd_text_3")
			cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			col.add_child(cap)
			var val := Kit.label("", 19, "num", "hd_text")
			val.name = "Value"
			val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			col.add_child(val)
			_gauge_row.add_child(col)
			_gauge_values[id] = val
	for id in ids:
		var v := int(amounts.get(id, 0))
		var lab: Label = _gauge_values[id]
		var key := "hd_text"
		if id == "heat":
			key = "hd_enemy_hi" if v >= 75 else ("hd_warn" if v >= 50 else "hd_text")
		elif id in ["vitality", "morale"]:
			key = "hd_enemy_hi" if v <= 15 else ("hd_warn" if v <= 30 else "hd_text")
		lab.add_theme_color_override(&"font_color", HdTheme.color(key))
		if id == "treasury":
			var money: Dictionary = _view.get("money", {}) if typeof(_view.get("money", {})) == TYPE_DICTIONARY else {}
			# 货币名只取括号前的那截（“先令（英镑／金几尼账）”写“先令”），全名在悬停提示里
			var unit := CardText.ui("c01.money.unit." + str(money.get("currency", "")))
			var short := unit.get_slice("\uFF08", 0).get_slice("(", 0).get_slice("\uFF0F", 0).strip_edges()
			lab.text = "%d %s" % [v, short] if short != "" else str(v)
			lab.add_theme_font_size_override(&"font_size", 18)
			(lab.get_parent() as Control).tooltip_text = Data.text("gauge_tip.treasury") + ("  " + unit if unit != "" else "")
		else:
			lab.text = str(v)


func _gauge_amounts() -> Dictionary:
	var out := {}
	for g in _campaign.get("gauges", []):
		if typeof(g) == TYPE_DICTIONARY:
			out[str(g.get("id", ""))] = int(g.get("amount", 0))
	return out


# ================================================================ 左栏：伙伴、功能币

func _fill_roster() -> void:
	Kit.clear(_roster_box)
	var hero_name := CardText.person_name("ruhua")
	_roster_box.add_child(_hero_row(hero_name))
	var alive := 0
	var fallen: Array = []
	for c in _campaign.get("companions", []):
		if typeof(c) != TYPE_DICTIONARY or not bool(c.get("recruited", false)):
			continue
		if not bool(c.get("alive", true)):
			fallen.append(c)
			continue
		alive += 1
		_roster_box.add_child(_companion_row(c, true))
	for c in fallen:
		_roster_box.add_child(_companion_row(c, false))
	if alive == 0 and fallen.is_empty():
		var none := Kit.label(Data.text("roster_empty"), 13, "sans", "hd_text_3")
		_roster_box.add_child(none)
	_roster_count.text = str(alive)
	_fill_troops()


## 部队：两列小牌（兵种头像、营号、兵力）
func _fill_troops() -> void:
	var army: Dictionary = _campaign.get("army", {}) if typeof(_campaign.get("army", {})) == TYPE_DICTIONARY else {}
	var troops: Array = army.get("troops", [])
	var head := _head(Data.text("troops_title"))
	(head.find_child("Count", true, false) as Label).text = "%d/%d" % [troops.size(), int(army.get("troop_cap", 8))]
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 4)
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_roster_box.add_child(gap)
	_roster_box.add_child(head)
	if troops.is_empty():
		_roster_box.add_child(Kit.label(Data.text("troops_empty"), 12, "sans", "hd_text_3"))
		return
	var grid := GridContainer.new()
	grid.name = "Troops"
	grid.columns = 1
	grid.add_theme_constant_override(&"h_separation", 6)
	grid.add_theme_constant_override(&"v_separation", 5)
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for t in troops:
		if typeof(t) != TYPE_DICTIONARY:
			continue
		var chip := PanelContainer.new()
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		chip.add_theme_stylebox_override(&"panel", HdTheme.box({"fill": ["hd_ink", 0.55], "edge": ["hd_gold", 0.2], "bw": 1, "r": 5,
			"pad": [4, 3]}))
		var row := HBoxContainer.new()
		row.add_theme_constant_override(&"separation", 6)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chip.add_child(row)
		row.add_child(_portrait("troop_" + str(t.get("cls", "")), str(t.get("name", "")), 24, false))
		var n := Kit.label(str(t.get("name", "")), 12, "sans", "hd_text_2")
		n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		n.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		n.custom_minimum_size = Vector2(40, 0)
		row.add_child(n)
		row.add_child(Kit.label(str(int(t.get("strength", 0))), 12, "num", "hd_gold_hi"))
		grid.add_child(chip)
	_roster_box.add_child(grid)


func _hero_row(hero_name: String) -> Control:
	var row := HBoxContainer.new()
	row.name = "Hero"
	row.add_theme_constant_override(&"separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_portrait("villefort", hero_name, PORTRAIT_HERO, true))
	var col := VBoxContainer.new()
	col.add_theme_constant_override(&"separation", 2)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	var n := Kit.label(hero_name, 17, "title", "hd_gold_hi")
	n.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	n.custom_minimum_size = Vector2(150, 0)
	col.add_child(n)
	col.add_child(Kit.label(Data.text("roster_hero"), 12, "sans", "hd_gold"))
	row.add_child(col)
	return row


func _companion_row(c: Dictionary, alive: bool) -> Control:
	var id := str(c.get("id", ""))
	var b := Kit.card_button("HubCard_companion_" + id, "plain")
	b.set_meta("uid", "companion:" + id)
	b.custom_minimum_size = Vector2(0, 52)
	b.disabled = not alive
	b.tooltip_text = str(c.get("skill_name", ""))
	if alive:
		b.pressed.connect(_press.bind("companion:" + id))
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override(&"separation", 10)
	b.add_child(row)
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 6
	row.offset_right = -10
	row.offset_top = 5
	row.offset_bottom = -5
	var face := _portrait(id, str(c.get("name", id)), PORTRAIT, false)
	row.add_child(face)
	var col := VBoxContainer.new()
	col.add_theme_constant_override(&"separation", 1)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var top := HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var n := Kit.label(str(c.get("name", id)), 15, "title", "hd_text" if alive else "hd_text_3")
	n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	n.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	n.custom_minimum_size = Vector2(60, 0)
	top.add_child(n)
	var hp := int(c.get("hp", 0))
	var cap := maxi(1, int(c.get("max_hp", 1)))
	var hp_l := Kit.label(Data.text("roster_hp", {"hp": maxi(0, hp), "max": cap}) if alive else "", 12, "num", "hd_text_2")
	top.add_child(hp_l)
	col.add_child(top)
	var sub := Kit.label(str(c.get("class_label", "")) + Data.text("sep_short") + Data.text("roster_level", {"n": int(c.get("level", 1))}),
		11, "sans", "hd_text_3")
	sub.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	sub.custom_minimum_size = Vector2(60, 0)
	col.add_child(sub)
	if alive:
		var bar := W.Bar.new()
		bar.fill_key = "bthud_hp"
		bar.hi_key = "bthud_hp_hi"
		bar.custom_minimum_size = Vector2(0, 5)
		bar.set_values(maxi(0, hp), cap)
		col.add_child(bar)
	row.add_child(col)
	if not alive:
		face.modulate = HdTheme.alpha("hd_text_3", 0.8)
	return b


## 方形头像（有 face 图用图、有立绘截头肩、都没有画剪影）加一道细金框
func _portrait(id: String, p_name: String, side: float, hero: bool) -> Control:
	var frame := Panel.new()
	frame.custom_minimum_size = Vector2(side, side)
	frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.anti_aliasing = true
	sb.bg_color = HdTheme.color("hd_ink")
	sb.border_color = HdTheme.alpha("hd_gold_hi" if hero else "hd_gold", 0.9 if hero else 0.55)
	sb.set_border_width_all(2 if hero else 1)
	sb.set_corner_radius_all(6)
	frame.add_theme_stylebox_override(&"panel", sb)
	var p := Portrait.new()
	frame.add_child(p)
	p.position = Vector2(2, 2)
	p.size = Vector2(side - 4, side - 4)
	p.setup(id, p_name)
	return frame


func _fill_coins() -> void:
	var coins: Dictionary = _campaign.get("coins", {}) if typeof(_campaign.get("coins", {})) == TYPE_DICTIONARY else {}
	for id in COINS:
		var lab: Label = _coin_values.get(id)
		if lab != null:
			lab.text = str(int(coins.get(id, 0)))


# ================================================================ 中间：剧情、战事、大命运、催逼、日志

func _fill_story() -> void:
	var scene_id := str(_campaign.get("scene_id", ""))
	var uid := "story:" + scene_id
	var def := "ocean.scene." + scene_id
	Kit.clear(_story)
	_story.set_meta("uid", uid)
	_story.visible = scene_id != "" and _hand_has(uid)
	if not _story.visible:
		return
	var cv := _card(uid)
	# 右边：这一场的背景缩图（左边渐隐进卡面）
	var thumb := Control.new()
	thumb.name = "Thumb"
	thumb.clip_contents = true
	thumb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	thumb.position = Vector2(STORY.size.x - 330, 7)
	thumb.size = Vector2(323, STORY.size.y - 14)
	_story.add_child(thumb)
	var spec := Data.scene_bg(scene_id)
	var bg := HdPlaceholder.make_bg(str(spec.get("id", "camp_tent")), "", "", str(spec.get("variant", "")))
	if HdPlaceholder.is_placeholder(bg):
		bg.set("title_alpha", 0.0)
	bg.set_anchors_preset(Control.PRESET_TOP_LEFT)
	thumb.add_child(bg)
	bg.position = Vector2(-120, -10)
	bg.size = Vector2(thumb.size.x + 160, (thumb.size.x + 160) * 9.0 / 16.0)
	var fade := StoryFade.new()
	fade.size = thumb.size
	thumb.add_child(fade)
	# 左边：部、标题、地点和日期、进度、按钮
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override(&"separation", 6)
	col.position = Vector2(26, 18)
	col.size = Vector2(STORY.size.x - 360, STORY.size.y - 36)
	_story.add_child(col)
	var chapter := CardText.card(def, "chapter")
	var kick := Data.text("story_kicker")
	if chapter != "" and not Data.same_title(chapter, CardText.card(def, "title")):
		kick += Data.text("sep") + chapter
	var kicker := Kit.label(kick, 13, "sans_bold", "hd_gold")
	kicker.add_theme_font_override(&"font", HdTheme.font("sans_bold", 2))
	col.add_child(kicker)
	var title := Kit.wrap(CardText.card(def, "title"), 27, "title", "hd_text")
	title.custom_minimum_size = Vector2(STORY.size.x - 370, 0)
	col.add_child(title)
	var date: Dictionary = _view.get("date", {})
	var loc := CardText.card(def, "location")
	var where := Kit.label(loc, 15, "serif", "hd_text_2")
	where.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	where.custom_minimum_size = Vector2(STORY.size.x - 370, 0)
	col.add_child(where)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(spacer)
	var pills := HBoxContainer.new()
	pills.add_theme_constant_override(&"separation", 8)
	pills.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var obs: Array = cv.get("observations", [])
	var apps := obs.size()
	var waiting := false
	var ready := false
	for c in cv.get("choices", []):
		if typeof(c) != TYPE_DICTIONARY:
			continue
		var id := str(c.get("id", ""))
		if id.begins_with(APPRAISE):
			apps += 1
		elif bool(c.get("enabled", false)):
			ready = true
		elif str(c.get("reason_key", "")) == "ocean.reason.battle" or str(c.get("reason", "")) == "battle_pending":
			waiting = true
	if apps > 0:
		pills.add_child(Kit.pill(Data.text("story_appraise", {"done": obs.size(), "total": apps}), "hd_ink", "hd_gold_hi", 12))
	if ready:
		pills.add_child(Kit.pill(Data.text("story_ready"), "hd_good", "hd_ink", 12, 0.85, "hd_good", 0.9))
	elif waiting:
		pills.add_child(Kit.pill(Data.text("story_battle"), "hd_wax", "hd_text", 12, 0.85, "hd_enemy_hi", 0.7))
	col.add_child(pills)
	# 还有鉴定没做、或者能作决定时，「开始剧情」是金色主按钮；鉴定都做完、只等本场的仗时，金色让给「排兵出征」
	var step := not waiting or ready or obs.size() < apps
	var cta := Kit.pill(Data.text("story_resume" if not obs.is_empty() else "story_open"),
		"hd_gold" if step else "hd_navy_3", "hd_ink" if step else "hd_gold_hi", 18 if step else 16, 1.0,
		"hd_gold_hi", 1.0 if step else 0.6)
	cta.name = "Cta"
	(cta.get_node("Text") as Label).add_theme_font_override(&"font", HdTheme.font("title"))
	_cta_look(cta, step)
	cta.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	col.add_child(cta)
	var date_l := Kit.label(Data.text("date", {"y": int(date.get("y", 0)), "m": int(date.get("m", 0)), "d": int(date.get("d", 0))}),
		12, "sans", "hd_text_2")
	date_l.position = Vector2(STORY.size.x - 322, STORY.size.y - 30)
	_story.add_child(date_l)


func _fill_battle() -> void:
	var fate := _hand_has("big_fate")
	_fate.visible = fate
	_battle.visible = not fate and _hand_has("battle")
	if fate:
		_build_fate()
	if not _battle.visible:
		return
	Kit.clear(_battle)
	var b2: Dictionary = _campaign.get("battle2", {}) if typeof(_campaign.get("battle2", {})) == TYPE_DICTIONARY else {}
	var resolved := bool(b2.get("resolved", false))
	var has := bool(b2.get("has_battle", false))
	var medal := Kit.medal("hub_battle", Data.card_spec("battle").get("icon", ""), 62)
	medal.position = Vector2(18, (BATTLE.size.y - 62) * 0.5)
	_battle.add_child(medal)
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override(&"separation", 3)
	col.position = Vector2(96, 14)
	col.size = Vector2(BATTLE.size.x - 96 - 170, BATTLE.size.y - 28)
	_battle.add_child(col)
	var name_s := str(b2.get("view", {}).get("name", "")) if typeof(b2.get("view", {})) == TYPE_DICTIONARY else ""
	col.add_child(Kit.label(Data.text("battle_kicker") + (Data.text("sep") + name_s if name_s != "" else ""), 13, "sans_bold", "hd_gold"))
	var body := Kit.wrap(CardText.card("ocean.battle", "body"), 14, "sans", "hd_text_2")
	body.custom_minimum_size = Vector2(BATTLE.size.x - 96 - 170, 0)
	body.max_lines_visible = 2
	body.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	col.add_child(body)
	var cta_key := "battle_lineup"
	match str(b2.get("panel", "")):
		"battle_v2":
			cta_key = "battle_active"
		"battle_result":
			cta_key = "battle_result"
	var cta: PanelContainer
	if not has:
		cta = Kit.pill(Data.text("battle_free"), "hd_ink", "hd_text_3", 15)
	elif resolved:
		cta = Kit.pill(Data.text("battle_done"), "hd_good", "hd_ink", 15, 0.85, "hd_good", 0.9)
	else:
		cta = Kit.pill(Data.text(cta_key), "hd_gold", "hd_ink", 18, 1.0, "hd_gold_hi", 1.0)
		(cta.get_node("Text") as Label).add_theme_font_override(&"font", HdTheme.font("title"))
		_cta_look(cta, true)
	cta.name = "Cta"
	_battle.add_child(cta)
	cta.reset_size()
	cta.position = Vector2(BATTLE.size.x - cta.size.x - 22, (BATTLE.size.y - cta.size.y) * 0.5)


## 卡上的行动按钮：当前该走的这一步（step）是金色大按钮，外圈金光；不是这一步时只是圆角深底
func _cta_look(cta: PanelContainer, step: bool) -> void:
	var cbox := cta.get_theme_stylebox(&"panel") as StyleBoxFlat
	if cbox == null:
		return
	cbox.content_margin_left = 24 if step else 18
	cbox.content_margin_right = 24 if step else 18
	cbox.content_margin_top = 7 if step else 5
	cbox.content_margin_bottom = 7 if step else 5
	cbox.set_corner_radius_all(6)
	cbox.shadow_color = HdTheme.alpha("hd_gold", 0.5 if step else 0.0)
	cbox.shadow_size = 14 if step else 0


func _build_fate() -> void:
	Kit.clear(_fate)
	var medal := Kit.medal("hub_fate", Data.card_spec("big_fate").get("icon", ""), 62)
	medal.position = Vector2(18, (BATTLE.size.y - 62) * 0.5)
	_fate.add_child(medal)
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override(&"separation", 3)
	col.position = Vector2(96, 16)
	col.size = Vector2(BATTLE.size.x - 96 - 190, BATTLE.size.y - 30)
	_fate.add_child(col)
	col.add_child(Kit.label(Data.text("fate_kicker"), 14, "sans_bold", "hd_enemy_hi"))
	var fb := Kit.wrap(Data.text("fate_body"), 15, "serif", "hd_text")
	fb.custom_minimum_size = Vector2(BATTLE.size.x - 96 - 190, 0)
	col.add_child(fb)
	var cta := Kit.pill(Data.text("fate_open"), "hd_wax_hi", "hd_text", 17, 1.0, "hd_gold_hi", 0.9)
	(cta.get_node("Text") as Label).add_theme_font_override(&"font", HdTheme.font("title"))
	cta.name = "Cta"
	_fate.add_child(cta)
	cta.reset_size()
	cta.position = Vector2(BATTLE.size.x - cta.size.x - 22, (BATTLE.size.y - cta.size.y) * 0.5)
	if not fast and not _fate.has_meta("pulse"):
		var tw := _fate.create_tween().set_loops()
		tw.tween_property(_fate, "modulate", HdTheme.mix("hd_white", "hd_gold_hi", 0.25), 0.9)
		tw.tween_property(_fate, "modulate", HdTheme.color("hd_white"), 0.9)
		_fate.set_meta("pulse", tw)


func _fill_demands() -> void:
	Kit.clear(_demands)
	var n := 0
	for c in _view.get("demands", []):
		if typeof(c) != TYPE_DICTIONARY or n >= 3:
			continue
		var uid := str(c.get("uid", ""))
		if uid == "":
			continue
		n += 1
		var b := Kit.card_button("HubCard_" + uid.replace(":", "_"), "plain")
		b.set_meta("uid", uid)
		b.custom_minimum_size = DEMAND_SIZE
		b.pressed.connect(_press.bind(uid))
		var def := str(c.get("def", ""))
		var col := VBoxContainer.new()
		col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_theme_constant_override(&"separation", 4)
		b.add_child(col)
		col.position = Vector2(14, 10)
		col.size = DEMAND_SIZE - Vector2(28, 20)
		var head := HBoxContainer.new()
		head.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var k := Kit.label(Data.text("demand_kicker"), 12, "sans_bold", "hd_enemy_hi")
		k.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		head.add_child(k)
		var days := int(c.get("days_left", 0))
		head.add_child(Kit.pill(Data.text("demand_days", {"n": days}), "hd_wax" if days <= 1 else "hd_ink",
			"hd_text", 11, 0.9, "hd_enemy_hi", 0.6))
		col.add_child(head)
		var t := Kit.wrap(CardText.card(def, "title"), 14, "serif", "hd_text")
		t.custom_minimum_size = Vector2(DEMAND_SIZE.x - 28, 0)
		t.max_lines_visible = 2
		col.add_child(t)
		_demands.add_child(b)
	_demands.visible = n > 0
	var top := DEMANDS_Y + (DEMAND_SIZE.y + 12.0 if n > 0 else 0.0)
	_log_panel.position = Vector2(STORY.position.x, top)
	_log_panel.size = Vector2(STORY.size.x, 706.0 - top)


func _fill_log() -> void:
	Kit.clear(_log_box)
	var body := CardText.card("ocean.status", "body")
	var rows: Array = []
	for line in body.split("\n"):
		var s := str(line).strip_edges()
		if s.begins_with(LEDGER_DAY) and s.contains(LEDGER_SEP):
			rows.append(s)
	var max_rows := int(floor((_log_panel.size.y - 52.0) / 22.0))
	if rows.is_empty():
		_log_box.add_child(Kit.label(Data.text("log_empty"), 13, "sans", "hd_text_3"))
		return
	for i in range(maxi(0, rows.size() - max_rows), rows.size()):
		var s: String = rows[i]
		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_theme_constant_override(&"separation", 10)
		var dot := Kit.label(s.get_slice(LEDGER_SEP, 0), 12, "num", "hd_gold")
		dot.custom_minimum_size = Vector2(64, 0)
		row.add_child(dot)
		var rest := s.substr(s.find(LEDGER_SEP) + LEDGER_SEP.length())
		var l := Kit.label(rest, 13, "sans", "hd_text_2" if i < rows.size() - 1 else "hd_text")
		l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.custom_minimum_size = Vector2(100, 0)
		row.add_child(l)
		_log_box.add_child(row)


# ================================================================ 右栏：营地事务、行军箱

func _fill_camp() -> void:
	Kit.clear(_camp_box)
	var shown: Array = []
	for uid in SIDES:
		if _hand_has(uid):
			shown.append(uid)
	# 行高按营地事务栏的空余高度算（八件都在时也不顶出栏底、不压到行军箱）
	var avail := RIGHT.size.y - CAMP_CHROME
	var row_h := clampf(floorf((avail - CAMP_GAP * float(maxi(shown.size() - 1, 0))) / float(maxi(shown.size(), 1))),
		CAMP_ROW_MIN, CAMP_ROW_MAX)
	var medal_side := 34.0 if row_h >= 40.0 else 30.0
	for uid in shown:
		var spec := Data.card_spec(uid)
		var b := Kit.card_button("HubCard_" + uid, "plain")
		b.set_meta("uid", uid)
		b.custom_minimum_size = Vector2(0, row_h)
		b.pressed.connect(_press.bind(uid))
		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_theme_constant_override(&"separation", 10)
		b.add_child(row)
		row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		row.offset_left = 6
		row.offset_right = -10
		row.offset_top = 3
		row.offset_bottom = -3
		var m := Kit.medal("hub_" + uid, str(spec.get("icon", "")), medal_side)
		m.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(m)
		var col := VBoxContainer.new()
		col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_theme_constant_override(&"separation", -1)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.alignment = BoxContainer.ALIGNMENT_CENTER
		col.add_child(Kit.label(str(spec.get("label", uid)), 15, "title", "hd_text"))
		var sub := Kit.label(_side_sub(uid), 11, "sans", "hd_text_3")
		sub.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		sub.custom_minimum_size = Vector2(80, 0)
		col.add_child(sub)
		row.add_child(col)
		var n := _enabled_count(uid)
		if n > 0:
			var badge := Kit.pill(str(n), "hd_gold", "hd_ink", 12, 0.95, "hd_gold_hi", 1.0)
			badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			badge.tooltip_text = Data.text("camp_ready", {"n": n})
			row.add_child(badge)
		_camp_box.add_child(b)


func _side_sub(uid: String) -> String:
	var coins: Dictionary = _campaign.get("coins", {}) if typeof(_campaign.get("coins", {})) == TYPE_DICTIONARY else {}
	match uid:
		"signage":
			return Data.text("sub.signage", {"sign": Data.text("sign." + str(_campaign.get("sign", "white")))})
		"march":
			var m: Dictionary = _campaign.get("march", {}) if typeof(_campaign.get("march", {})) == TYPE_DICTIONARY else {}
			return Data.text("sub.march", {"pos": int(m.get("pos", 0)), "tile": str(m.get("tile_name", ""))})
		"calendar":
			var cal: Dictionary = _campaign.get("calendar", {}) if typeof(_campaign.get("calendar", {})) == TYPE_DICTIONARY else {}
			return Data.text("sub.calendar", {"week": int(cal.get("week", 1)), "countdown": int(cal.get("countdown", 0))})
		"squad":
			return Data.text("sub.squad", {"gold": int(coins.get("gold", 0)), "medal": int(coins.get("medal", 0))})
	return Data.text("sub." + uid)


func _enabled_count(uid: String) -> int:
	if uid == "status":
		return 0
	var n := 0
	for c in _card(uid).get("choices", []):
		if typeof(c) == TYPE_DICTIONARY and bool(c.get("enabled", false)) and str(c.get("id", "")) != "action:wait":
			n += 1
	return n


func _fill_kit() -> void:
	Kit.clear(_kit_flow)
	var n := 0
	for c in _view.get("kept", []):
		if typeof(c) != TYPE_DICTIONARY:
			continue
		var uid := str(c.get("uid", ""))
		if uid == "":
			continue
		n += 1
		var is_prop := uid.begins_with("prop:")
		var b := Button.new()
		b.name = "HubCard_" + uid.replace(":", "_")
		b.set_meta("uid", uid)
		b.text = CardText.card(str(c.get("def", "")), "title")
		HdTheme.apply_button(b, "secondary")
		b.add_theme_font_size_override(&"font_size", 13)
		b.custom_minimum_size = Vector2(0, 28)
		for st in [&"normal", &"hover", &"pressed", &"hover_pressed", &"disabled"]:
			var sb := b.get_theme_stylebox(st)
			if sb != null:
				sb.content_margin_left = 10
				sb.content_margin_right = 10
				sb.content_margin_top = 3
				sb.content_margin_bottom = 3
		if is_prop:
			b.add_theme_color_override(&"font_color", HdTheme.color("hd_ally_hi"))
		b.focus_mode = Control.FOCUS_NONE
		b.tooltip_text = Data.text("kit_prop") if is_prop else ""
		b.pressed.connect(_press.bind(uid))
		_kit_flow.add_child(b)
	_kit_empty.visible = n == 0


# ================================================================ 飘字

func _float_changes() -> void:
	var now := _gauge_amounts()
	var coins: Dictionary = _campaign.get("coins", {}) if typeof(_campaign.get("coins", {})) == TYPE_DICTIONARY else {}
	for id in COINS:
		now["coin_" + id] = int(coins.get(id, 0))
	now["_chapter"] = str(_campaign.get("chapter_id", ""))
	var old := _last_values
	_last_values = now
	if old.is_empty() or str(old.get("_chapter", "")) != str(now["_chapter"]) or fast or not is_visible_in_tree():
		return
	for id in now:
		if str(id).begins_with("_") or not old.has(id):
			continue
		var d := int(now[id]) - int(old[id])
		if d == 0:
			continue
		var anchor: Control = null
		if str(id).begins_with("coin_"):
			anchor = _coin_values.get(str(id).trim_prefix("coin_"))
		else:
			anchor = _gauge_values.get(id)
		if anchor == null or not anchor.is_visible_in_tree():
			continue
		var good := d > 0
		if id == "heat":
			good = d < 0
		var f := Kit.Floater.new()
		f.text = "%+d" % d
		f.add_theme_font_override(&"font", HdTheme.font("num"))
		f.add_theme_font_size_override(&"font_size", 18)
		f.add_theme_color_override(&"font_color", HdTheme.color("hd_good" if good else "hd_enemy_hi"))
		f.add_theme_color_override(&"font_outline_color", HdTheme.alpha("hd_ink", 0.9))
		f.add_theme_constant_override(&"outline_size", 4)
		_float_layer.add_child(f)
		var at := anchor.global_position - global_position + anchor.size * 0.5
		if str(id).begins_with("coin_"):
			f.play(at + Vector2(0, -16), 30.0, fast)
		else:
			# 顶栏指标：从顶栏下沿往下飘，不压在“金库”这些字上
			f.play(Vector2(at.x, TOP_H + 12.0), -18.0, fast)


# ================================================================ 小工具

func _press(uid: String) -> void:
	card_pressed.emit(uid)


func _card(uid: String) -> Dictionary:
	if engine == null:
		return {}
	var r = engine.query(&"card", {"uid": uid})
	return r if typeof(r) == TYPE_DICTIONARY else {}


func _hand_has(uid: String) -> bool:
	for c in _view.get("hand", []):
		if typeof(c) == TYPE_DICTIONARY and str(c.get("uid", "")) == uid:
			return true
	return false


func _all_buttons() -> Array:
	var out: Array = []
	var stack: Array = [self]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is Button:
			out.append(n)
		for c in n.get_children():
			stack.append(c)
	return out


func _on_visibility() -> void:
	if not visible or fast or not _built:
		return
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.25)


# ================================================================ 搭界面

func _ensure() -> void:
	if _built:
		return
	_built = true
	var base := ColorRect.new()
	base.color = HdTheme.color("hd_ink")
	base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	base.size = size
	add_child(base)
	_bg_layer = Control.new()
	_bg_layer.name = "Bg"
	_bg_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bg_layer.size = size
	add_child(_bg_layer)
	var shade := Kit.Shade.new()
	shade.size = size
	add_child(shade)
	_build_top()
	_build_left()
	_build_center()
	_build_right()
	_float_layer = Control.new()
	_float_layer.name = "Floats"
	_float_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_float_layer.size = size
	add_child(_float_layer)


func _build_top() -> void:
	var bar := PanelContainer.new()
	bar.name = "TopBar"
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := HdTheme.panel_box("hud")
	box.content_margin_left = 16
	box.content_margin_right = 12
	box.content_margin_top = 6
	box.content_margin_bottom = 6
	bar.add_theme_stylebox_override(&"panel", box)
	bar.position = Vector2.ZERO
	bar.size = Vector2(1280, TOP_H)
	bar.custom_minimum_size = Vector2(1280, TOP_H)
	add_child(bar)
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(row)
	var mark := Kit.medal("hub_brand", Data.text("brand_mark"), 42)
	mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(mark)
	var titles := VBoxContainer.new()
	titles.add_theme_constant_override(&"separation", 0)
	titles.alignment = BoxContainer.ALIGNMENT_CENTER
	titles.mouse_filter = Control.MOUSE_FILTER_IGNORE
	titles.custom_minimum_size = Vector2(300, 0)
	_chapter_label = Kit.label("", 19, "title", "hd_gold_hi")
	_chapter_label.name = "Chapter"
	titles.add_child(_chapter_label)
	_scene_label = Kit.label("", 13, "sans", "hd_text_2")
	_scene_label.name = "Scene"
	_scene_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_scene_label.custom_minimum_size = Vector2(300, 0)
	titles.add_child(_scene_label)
	row.add_child(titles)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(spacer)
	_gauge_row = HBoxContainer.new()
	_gauge_row.name = "Gauges"
	_gauge_row.add_theme_constant_override(&"separation", 6)
	_gauge_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_gauge_row)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(8, 0)
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(gap)
	var tools := HBoxContainer.new()
	tools.add_theme_constant_override(&"separation", 4)
	tools.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(tools)
	_tool(tools, "BtnHubRules", "btn_rules", "tip_rules").pressed.connect(func() -> void:
		open_requested.emit(&"read", {"def": "ocean.rules"}))
	_tool(tools, "BtnHubRelics", "btn_relics", "tip_relics").pressed.connect(func() -> void:
		open_requested.emit(&"relics", {}))
	_tool(tools, "BtnHubDossier", "btn_dossier", "tip_dossier").pressed.connect(func() -> void:
		open_requested.emit(&"dossier", {}))
	_tool(tools, "BtnHubSettings", "btn_settings", "tip_settings").pressed.connect(func() -> void:
		open_requested.emit(&"settings", {"_tab": "settings"}))
	_tool(tools, "BtnHubMenu", "btn_menu", "tip_menu").pressed.connect(func() -> void: menu_pressed.emit())


func _tool(parent: Control, node_name: String, text_key: String, tip_key: String) -> Button:
	var b := Button.new()
	b.name = node_name
	b.text = Data.text(text_key)
	b.tooltip_text = Data.text(tip_key)
	HdTheme.apply_button(b, "ghost")
	var normal := HdTheme.box({"fill": ["hd_ink", 0.45], "edge": ["hd_gold", 0.32], "bw": 1, "r": 6, "pad": [10, 4]})
	b.add_theme_stylebox_override(&"normal", normal)
	b.add_theme_font_size_override(&"font_size", 14)
	b.custom_minimum_size = Vector2(46, 32)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.focus_mode = Control.FOCUS_NONE
	parent.add_child(b)
	return b


func _build_left() -> void:
	var panel := PanelContainer.new()
	panel.name = "Roster"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := HdTheme.panel_box("glass")
	box.content_margin_left = 12
	box.content_margin_right = 12
	panel.add_theme_stylebox_override(&"panel", box)
	panel.position = LEFT.position
	panel.size = LEFT.size
	panel.custom_minimum_size = LEFT.size
	panel.clip_contents = true
	add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override(&"separation", 6)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(col)
	var rhead := _head(Data.text("roster_title"))
	col.add_child(rhead)
	_roster_count = rhead.find_child("Count", true, false) as Label
	var scroll := ScrollContainer.new()
	scroll.name = "RosterScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	col.add_child(scroll)
	_roster_box = VBoxContainer.new()
	_roster_box.name = "RosterList"
	_roster_box.add_theme_constant_override(&"separation", 5)
	_roster_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_roster_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scroll.add_child(_roster_box)
	var coins := PanelContainer.new()
	coins.name = "Coins"
	coins.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cbox := HdTheme.panel_box("glass")
	cbox.content_margin_left = 10
	cbox.content_margin_right = 10
	cbox.content_margin_top = 8
	cbox.content_margin_bottom = 8
	coins.add_theme_stylebox_override(&"panel", cbox)
	coins.position = COINS_RECT.position
	coins.size = COINS_RECT.size
	coins.custom_minimum_size = COINS_RECT.size
	add_child(coins)
	var crow := HBoxContainer.new()
	crow.add_theme_constant_override(&"separation", 0)
	crow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	coins.add_child(crow)
	for id in COINS:
		var c := VBoxContainer.new()
		c.name = "Coin_" + id
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		c.alignment = BoxContainer.ALIGNMENT_CENTER
		c.add_theme_constant_override(&"separation", 0)
		c.mouse_filter = Control.MOUSE_FILTER_PASS
		c.tooltip_text = Data.text("coin_tip." + id)
		var v := Kit.label("0", 21, "num", "hd_gold_hi")
		v.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		c.add_child(v)
		var cap := Kit.label(Data.text("coin." + id), 11, "sans", "hd_text_3")
		cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		c.add_child(cap)
		crow.add_child(c)
		_coin_values[id] = v


func _build_center() -> void:
	_story = Kit.card_button("HubCard_story", "gold")
	_story.position = STORY.position
	_story.size = STORY.size
	_story.custom_minimum_size = STORY.size
	_story.pressed.connect(func() -> void: _press(str(_story.get_meta("uid", ""))))
	add_child(_story)
	_battle = Kit.card_button("HubCard_battle", "plain")
	_battle.set_meta("uid", "battle")
	_battle.position = BATTLE.position
	_battle.size = BATTLE.size
	_battle.custom_minimum_size = BATTLE.size
	_battle.pressed.connect(_press.bind("battle"))
	add_child(_battle)
	_fate = Kit.card_button("HubCard_big_fate", "red")
	_fate.set_meta("uid", "big_fate")
	_fate.position = BATTLE.position
	_fate.size = BATTLE.size
	_fate.custom_minimum_size = BATTLE.size
	_fate.pressed.connect(_press.bind("big_fate"))
	_fate.visible = false
	add_child(_fate)
	_demands = HBoxContainer.new()
	_demands.name = "Demands"
	_demands.add_theme_constant_override(&"separation", 12)
	_demands.position = Vector2(STORY.position.x, DEMANDS_Y)
	_demands.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_demands)
	_log_panel = PanelContainer.new()
	_log_panel.name = "Log"
	_log_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_log_panel.clip_contents = true
	var box := HdTheme.panel_box("glass")
	box.content_margin_top = 10
	box.content_margin_bottom = 8
	_log_panel.add_theme_stylebox_override(&"panel", box)
	_log_panel.position = Vector2(STORY.position.x, DEMANDS_Y)
	_log_panel.size = Vector2(STORY.size.x, 706.0 - DEMANDS_Y)
	add_child(_log_panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override(&"separation", 6)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_log_panel.add_child(col)
	var head := _head(Data.text("log_title"))
	(head.find_child("Count", true, false) as Label).visible = false
	col.add_child(head)
	_log_box = VBoxContainer.new()
	_log_box.add_theme_constant_override(&"separation", 4)
	_log_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_log_box)


func _build_right() -> void:
	var panel := PanelContainer.new()
	panel.name = "Camp"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := HdTheme.panel_box("glass")
	box.content_margin_left = 10
	box.content_margin_right = 10
	panel.add_theme_stylebox_override(&"panel", box)
	panel.position = RIGHT.position
	panel.size = RIGHT.size
	panel.custom_minimum_size = RIGHT.size
	add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override(&"separation", 6)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(col)
	var head := _head(Data.text("camp_title"))
	(head.find_child("Count", true, false) as Label).visible = false
	col.add_child(head)
	_camp_box = VBoxContainer.new()
	_camp_box.name = "CampList"
	_camp_box.add_theme_constant_override(&"separation", int(CAMP_GAP))
	_camp_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_camp_box)
	var kit := PanelContainer.new()
	kit.name = "Kit"
	kit.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var kbox := HdTheme.panel_box("glass")
	kbox.content_margin_left = 12
	kbox.content_margin_right = 12
	kbox.content_margin_top = 10
	kbox.content_margin_bottom = 8
	kit.add_theme_stylebox_override(&"panel", kbox)
	kit.position = KIT.position
	kit.size = KIT.size
	kit.custom_minimum_size = KIT.size
	add_child(kit)
	var kcol := VBoxContainer.new()
	kcol.add_theme_constant_override(&"separation", 6)
	kcol.mouse_filter = Control.MOUSE_FILTER_IGNORE
	kit.add_child(kcol)
	var khead := _head(Data.text("kit_title"))
	(khead.find_child("Count", true, false) as Label).visible = false
	kcol.add_child(khead)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	kcol.add_child(scroll)
	var inner := VBoxContainer.new()
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scroll.add_child(inner)
	_kit_flow = HFlowContainer.new()
	_kit_flow.name = "KitList"
	_kit_flow.add_theme_constant_override(&"h_separation", 6)
	_kit_flow.add_theme_constant_override(&"v_separation", 6)
	_kit_flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_kit_flow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(_kit_flow)
	_kit_empty = Kit.label(Data.text("kit_empty"), 13, "sans", "hd_text_3")
	inner.add_child(_kit_empty)
	_end = Button.new()
	_end.name = "HubEnd"
	HdTheme.apply_button(_end, "secondary")
	_end.position = END.position
	_end.size = END.size
	_end.custom_minimum_size = END.size
	_end.focus_mode = Control.FOCUS_NONE
	_end.tooltip_text = Data.text("end_hint")
	_end.pressed.connect(func() -> void: end_pressed.emit())
	add_child(_end)
	var ecol := VBoxContainer.new()
	ecol.alignment = BoxContainer.ALIGNMENT_CENTER
	ecol.add_theme_constant_override(&"separation", 0)
	ecol.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_end.add_child(ecol)
	ecol.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_end_title = Kit.label("", 22, "title", "hd_gold_hi")
	_end_title.name = "Title"
	_end_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ecol.add_child(_end_title)
	_end_sub = Kit.label("", 12, "sans", "hd_gold_hi")
	_end_sub.name = "Sub"
	_end_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ecol.add_child(_end_sub)


## 栏位标题：金色衬线字、右边一个小数字、下面一道渐隐金线
func _head(text: String) -> Control:
	var col := VBoxContainer.new()
	col.add_theme_constant_override(&"separation", 3)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var t := Kit.label(text, 17, "title", "hd_gold_hi")
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(t)
	var n := Kit.label("", 14, "num", "hd_text_2")
	n.name = "Count"
	row.add_child(n)
	col.add_child(row)
	var rule := W.Rule.new()
	rule.custom_minimum_size = Vector2(0, 6)
	col.add_child(rule)
	return col


## 剧情大卡缩图左边的渐隐（融进卡面）
class StoryFade extends Control:
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var w := size.x * 0.55
		var c0 := HdTheme.alpha("hd_navy_2", 0.96)
		var c1 := HdTheme.alpha("hd_navy_2", 0.0)
		draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, size.y), Vector2(0, size.y)]),
			PackedColorArray([c0, c1, c1, c0]))
		var b0 := HdTheme.alpha("hd_ink", 0.0)
		var b1 := HdTheme.alpha("hd_ink", 0.7)
		var y0 := size.y * 0.6
		draw_polygon(PackedVector2Array([Vector2(0, y0), Vector2(size.x, y0), Vector2(size.x, size.y), Vector2(0, size.y)]),
			PackedColorArray([b0, b0, b1, b1]))
