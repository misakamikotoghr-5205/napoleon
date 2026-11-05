# 剧情 VN 面板（kind vn，满屏 1280×720）：远洋战役的金色剧情牌（uid "story:<场次>"）打出来开这里。
# FGO 式的剧情对话（只借版式）：全屏背景（换场景交叉淡化）、开场章节卡（部、场次标题、日期、地点）、
# 左中右站着的人（说话的人亮、其他人压暗缩小，滑入滑出，换表情）、底部玻璃文本框和名字牌、打字机（每秒约 40 字，
# 点一下/空格/回车先出全句、再点下一句）、跳动的“下一句”箭头；右上角 自动 / 快进 / 记录 / 隐藏 / 稍后。
# 读完正文出抉择菜单：鉴定和决定都是选项（灰的写原因），鉴定完把观察结果当成几句话放出来再回菜单，
# 作出决定后放结算（账目变动、行军箱进出、下一场）再关。旧格子面板（slots）给的东西一样不少：标题、正文、
# 已鉴定的线索、每个选项和灰掉的原因、鉴定、决定、“稍后”。
# 只读 engine.query(card / campaign) 和 engine.view()，只发 card.choose；正文、选项字来自 CardText
# （ocean_view 覆盖层的 ocean.scene.<id> 的 paras / title / chapter / location / choices.*），
# 演出表在 data/hd/vn_cast.json，界面字在 data/hd/vn_ui.json。没有 class_name。说明：docs/cards/HD_UI.md。
extends CardPanel

const HdTheme = preload("res://scripts/cards/ui/hd/hd_theme.gd")
const HdArt = preload("res://scripts/cards/ui/hd/hd_art.gd")
const HdPlaceholder = preload("res://scripts/cards/ui/hd/hd_placeholder.gd")
const Data = preload("res://scripts/cards/ui/vn/vn_data.gd")
const VnScript = preload("res://scripts/cards/ui/vn/vn_script.gd")
const Stage = preload("res://scripts/cards/ui/vn/vn_stage.gd")
const Deco = preload("res://scripts/cards/ui/vn/vn_deco.gd")
const HdText = preload("res://scripts/cards/ui/hd/hd_text.gd")

const KIND := &"vn"
const CMD := &"card.choose"
const BOX := Rect2(64, 498, 1152, 202)
const BODY := Rect2(58, 44, 1036, 132)
const PLATE_POS := Vector2(96, 474)
const MENU_W := 760.0
const CLUES := Rect2(20, 70, 214, 560)
## 抉择菜单右边的账面（金库、同盟威望、敌方警戒…）：选项要花这些，选的时候要看得见
const GAUGES := Rect2(1046, 70, 214, 0)
## 菜单上下留的边：顶上让出顶栏（地点牌、右上角按钮），底下留一点
const MENU_TOP := 64.0
const MENU_BOTTOM := 14.0
## 选项行高：常规 / 挤一挤（菜单太高时）；灰的选项下面多一行原因
const ROW_H := [52.0, 44.0]
const ROW_OFF_H := [72.0, 60.0]
const ROW_SEP := [9, 5]
const LOG := Rect2(150, 36, 980, 648)
const CPS := 40.0
const TITLE_HOLD_S := 2.6
const TITLE_FADE_S := 0.5
const BG_FADE_S := 0.7
const SKIP_STEP_S := 0.07
const AUTO_BASE_S := 1.1
const AUTO_PER_CHAR_S := 0.045
const BODY_SIZE := 22
const APPRAISE := "action:appraise:"
const MAP_APPRAISE := "action:map_appraise:"

var kind: StringName = KIND
## 快动画（测试、自动试玩）：没有打字机和补间，开场章节卡直接跳过。宿主的 fast 打开时跟着打开
var fast := false

## 这一局（引擎）里已经看过开场的场次：再打开时直接到抉择菜单（记录里有全文，也能“重看本场”）
static var _seen: Dictionary = {}

var _uid := ""
var _scene_id := ""
var _presentation: Dictionary = {}
var _def := ""
var _location := ""
## title | line | choices | closed
var _state := ""
var _lines: Array = []
var _index := -1
## 台词放完以后：choices（出抉择菜单）| close（关掉）
var _then := "choices"
var _full := ""
var _shown := 0.0
var _wait := 0.0
var _title_t := 0.0
var _auto := false
var _skip := false
var _hidden := false
var _log_open := false
var _busy := false
var _closed := false
var _log: Array = []
var _pending_expr: Dictionary = {}
var _bg_key := ""
## 开场站在台上的人：章节卡放完以后再滑上台
var _opening_cast: Array = []

var _bg_layer: Control
var _bg_node: Control
var _stage: Stage
var _ui_root: Control
## 顶栏（地点牌、右上角按钮）单独一层，画在抉择菜单的压暗层上面：选的时候“记录”“隐藏”照样点得到
var _top_root: Control
var _gauge_panel: PanelContainer
var _gauge_box: VBoxContainer
var _chip: PanelContainer
var _chip_label: Label
var _bar: PanelContainer
var _btn_auto: Button
var _btn_skip: Button
var _btn_log: Button
var _btn_hide: Button
var _btn_close: Button
var _box: Panel
var _body: Label
var _arrow: Control
var _plate: PanelContainer
var _plate_bar: ColorRect
var _plate_label: Label
var _badge: PanelContainer
var _badge_label: Label
var _hint: Label
var _banner: Control
var _banner_label: Label
var _title: Control
var _title_chapter: Label
var _title_main: Label
var _title_sub: Label
var _choice_root: Control
var _menu: VBoxContainer
var _clue_panel: PanelContainer
var _clue_box: VBoxContainer
var _log_root: Control
var _log_scroll: ScrollContainer
var _log_list: VBoxContainer
var _tut_bar: PanelContainer
var _dock: PanelContainer
var _dock_coins: Label
var _dock_status: Label
var _choice_dock: PanelContainer
var _choice_dock_coins: Label
var _choice_dock_status: Label
var _next_open_uid := ""


# ================================================================ 面板合同

func open(args: Dictionary) -> void:
	_closed = false
	_next_open_uid = ""
	_uid = str(args.get("uid", ""))
	_scene_id = _uid.trim_prefix("story:") if _uid.begins_with("story:") else (_uid.trim_prefix("event:") if _uid.begins_with("event:") else "")
	var host := get_parent()
	if host != null and "fast" in host:
		fast = fast or bool(host.get("fast"))
	_ensure()
	_stage.fast = fast
	var cv := _card()
	if cv.is_empty() or _scene_id == "":
		# 牌已经不在了（存档换了、场次过了）：宿主接上关闭信号之后再关
		_close.call_deferred({})
		return
	_def = str(cv.get("def", "ocean.scene." + _scene_id))
	_location = CardText.card(_def, "location")
	_presentation = cv.get("presentation", {}).duplicate(true) if typeof(cv.get("presentation", {})) == TYPE_DICTIONARY else {}
	var art = Data.scene(_scene_id, _presentation).get("art", {})
	_stage.art_overrides = art.duplicate(true) if typeof(art) == TYPE_DICTIONARY else {}
	_lines = VnScript.build(_scene_id, _paras(), _presentation)
	_lines.append_array(_clue_lines(cv))
	var opening := VnScript.opening(_scene_id, _presentation)
	_set_bg(opening.get("bg", {}), false)
	_opening_cast = opening.get("cast", [])
	_fill_title()
	var key := _seen_key()
	var seen := _seen.has(key)
	_seen[key] = true
	if seen:
		_fast_forward()
	else:
		_start_title()


func refresh(_view: Dictionary) -> void:
	if _closed or _busy or _state != "choices":
		return
	_rebuild_choices.call_deferred()


## Esc / 宿主的 close_top：先关记录、再恢复隐藏的界面，最后才是“稍后”（关掉面板）
func dismiss() -> void:
	if _closed:
		return
	if _log_open:
		close_log()
		return
	if _hidden:
		set_hidden(false)
		return
	_close({})


func autoplay_step() -> bool:
	if _closed:
		return false
	if _log_open:
		close_log()
		return true
	if _hidden:
		set_hidden(false)
		return true
	match _state:
		"title":
			_end_title()
			return true
		"line":
			advance()
			return true
		"choices":
			for b in choice_buttons():
				if not b.disabled:
					b.pressed.emit()
					return true
			_close({})
			return true
	return false


# ================================================================ 给测试和宿主的小接口

func state() -> String:
	return _state


func current_line() -> Dictionary:
	return _lines[_index] if _index >= 0 and _index < _lines.size() else {}


func lines() -> Array:
	return _lines.duplicate(true)


func log_entries() -> Array:
	return _log.duplicate(true)


func is_typing() -> bool:
	return _typing()


func is_auto() -> bool:
	return _auto


func is_skipping() -> bool:
	return _skip


func is_hidden() -> bool:
	return _hidden


func is_log_open() -> bool:
	return _log_open


func vn_stage() -> Control:
	return _stage


## 点一下 / 空格 / 回车：章节卡 -> 第一句；正在打字 -> 出全句；整句已出 -> 下一句（放完了出抉择或关掉）
func advance() -> void:
	if _closed:
		return
	if _hidden:
		set_hidden(false)
		return
	if _log_open:
		return
	match _state:
		"title":
			_end_title()
		"line":
			if _typing():
				_complete()
			else:
				_next_line()


## 一口气放到底：正文 -> 抉择菜单；结算 -> 停在最后一句（不替玩家关面板）
func skip_all() -> void:
	if _closed:
		return
	if _state == "title":
		_end_title()
	var guard := 0
	while _state == "line" and _index < _lines.size() - 1 and guard < 400:
		guard += 1
		_next_line()
	if _state == "line":
		_complete()
		if _then == "choices":
			_next_line()


func set_auto(on: bool) -> void:
	_auto = on
	if on:
		_skip = false
	_wait = 0.0
	_sync_bar()


func set_skip(on: bool) -> void:
	_skip = on and _state != "choices"
	if _skip:
		_auto = false
	_wait = 0.0
	_sync_bar()


func set_hidden(on: bool) -> void:
	if on and (_state != "line" and _state != "choices"):
		return
	_hidden = on
	_ui_root.visible = not on
	_top_root.visible = not on
	_choice_root.visible = not on and _state == "choices"
	_hint.visible = on
	if on and not fast:
		_hint.modulate.a = 1.0
		var tw := _hint.create_tween()
		tw.tween_interval(1.4)
		tw.tween_property(_hint, "modulate:a", 0.0, 0.8)


func open_log() -> void:
	if _closed or _log_open:
		return
	_log_open = true
	_fill_log()
	_log_root.visible = true
	# 记录盖住全屏：顶栏（地点、自动 / 快进 / 记录）和台上的名字牌都收起，不从记录框后面透出来
	_top_root.visible = false
	_stage.set_chips_visible(false)
	if not fast:
		_log_root.modulate.a = 0.0
		_log_root.create_tween().tween_property(_log_root, "modulate:a", 1.0, 0.18)
	_scroll_log_end.call_deferred()


func close_log() -> void:
	if not _log_open:
		return
	_log_open = false
	_log_root.visible = false
	_top_root.visible = not _hidden
	_stage.set_chips_visible(_state != "choices")


## 抉择菜单上的选项按钮（按显示顺序；“稍后再来”“重看本场”不算）
func choice_buttons() -> Array[Button]:
	var out: Array[Button] = []
	if _menu == null:
		return out
	for b in _walk(_menu):
		if b is Button and b.has_meta("reply_id") and str(b.get_meta("reply_id")) != "later":
			out.append(b)
	return out


# ================================================================ 开场

func _start_title() -> void:
	_state = "title"
	_title_t = 0.0
	_ui_root.visible = false
	_top_root.visible = false
	_title.visible = true
	if fast:
		_end_title()
		return
	_title.modulate.a = 0.0
	_title.create_tween().tween_property(_title, "modulate:a", 1.0, TITLE_FADE_S)


func _end_title() -> void:
	if _state != "title":
		return
	_state = "line"
	_ui_root.visible = not _hidden
	_top_root.visible = not _hidden
	if fast:
		_title.visible = false
	else:
		var tw := _title.create_tween()
		tw.tween_property(_title, "modulate:a", 0.0, TITLE_FADE_S)
		tw.tween_callback(_title.hide)
	_enter_opening_cast()
	_then = "choices"
	_index = -1
	_next_line()


## 开场的人上台（章节卡之后滑进来；快动画时直接站好）
func _enter_opening_cast() -> void:
	for c in _opening_cast:
		_stage.enter(str(c["who"]), str(c["at"]), "")
	if fast:
		_stage.settle()


func _fill_title() -> void:
	var date: Dictionary = _view().get("date", {})
	var date_text := Data.text("date", {"y": int(date.get("y", 0)), "m": int(date.get("m", 0)), "d": int(date.get("d", 0))})
	_title_chapter.text = CardText.card(_def, "chapter")
	_title_main.text = CardText.card(_def, "title")
	# 序曲的“部”和场次标题是同一句话：只写大标题
	_title_chapter.visible = not HdText.same_title(_title_chapter.text, _title_main.text)
	_title_sub.text = Data.text("title_sub", {"date": date_text, "location": _location}) if _location != "" else date_text
	_chip_label.text = _location


## 看过的场次再打开：台子摆成正文最后的样子，记录里放全文，直接出抉择
func _fast_forward() -> void:
	var was := fast
	fast = true
	_stage.fast = true
	_enter_opening_cast()
	for i in _lines.size():
		_index = i
		var line: Dictionary = _lines[i]
		_apply_dir(line.get("dir", {}))
		_cast_for(line)
		_log.append(_log_row(line))
	_stage.focus("")
	fast = was
	_stage.fast = was
	_state = "line"
	_ui_root.visible = true
	_top_root.visible = true
	_title.visible = false
	_open_choices()


# ================================================================ 一句一句

func _process(delta: float) -> void:
	if _closed or _log_open or _hidden:
		return
	var hurry := _skip or (is_visible_in_tree() and Input.is_key_pressed(KEY_CTRL))
	if _state == "title":
		_title_t += delta
		if _title_t >= TITLE_HOLD_S or hurry:
			_end_title()
		return
	if _state != "line":
		return
	if _typing():
		if hurry:
			_complete()
		else:
			_shown = minf(_shown + delta * CPS, float(_full.length()))
			_body.visible_characters = int(_shown)
			if _shown >= float(_full.length()):
				_complete()
		return
	var last := _index >= _lines.size() - 1
	if last and _then == "close":
		return
	if hurry:
		_wait += delta
		if _wait >= SKIP_STEP_S:
			_next_line()
	elif _auto:
		_wait += delta
		if _wait >= AUTO_BASE_S + AUTO_PER_CHAR_S * float(_full.length()):
			_next_line()


func _next_line() -> void:
	_index += 1
	if _index >= _lines.size():
		_index = _lines.size() - 1
		_finish_lines()
		return
	_show_line()


func _finish_lines() -> void:
	if _then == "choices":
		_open_choices()
	else:
		_close({"open_uid": _next_open_uid} if _next_open_uid != "" else {})


func _show_line() -> void:
	var line: Dictionary = _lines[_index]
	_apply_dir(line.get("dir", {}))
	_cast_for(line)
	var kind_s := str(line.get("kind", "narr"))
	var plate := str(line.get("name", ""))
	_set_plate(plate, kind_s, str(line.get("who", "")))
	_full = str(line.get("text", ""))
	_body.text = _full
	_body.add_theme_color_override(&"font_color", HdTheme.color("hd_parchment" if kind_s in ["clue", "result"] else "hd_text"))
	_shown = 0.0
	_wait = 0.0
	_body.visible_characters = 0
	_arrow.visible = false
	_box.visible = true
	if _dock != null:
		_dock.visible = true
	_sync_dock()
	_log.append(_log_row(line))
	if fast or _full == "":
		_complete()


func _complete() -> void:
	_shown = float(_full.length())
	_body.visible_characters = -1
	_wait = 0.0
	_arrow.visible = true


func _typing() -> bool:
	return _state == "line" and _shown < float(_full.length())


## 谁上台、谁亮：台词是说话的人；旁白里带了 focus 的是那个人；抉择是主角（在台上时）
func _cast_for(line: Dictionary) -> void:
	var kind_s := str(line.get("kind", "narr"))
	var who := str(line.get("who", ""))
	if kind_s == "say" and who != "":
		_enter(who, "")
		_stage.focus(who)
	elif str(line.get("focus", "")) != "":
		_enter(str(line["focus"]), "")
		_stage.focus(str(line["focus"]))
	elif kind_s == "pick" and _stage.has_actor(Data.protagonist()):
		_stage.focus(Data.protagonist())
	else:
		_stage.focus("")


func _enter(who: String, at: String) -> void:
	if _stage.has_actor(who):
		return
	_stage.enter(who, at, str(_pending_expr.get(who, "")))
	_pending_expr.erase(who)


## 一段开头的演出：换背景、下场、上场、表情
func _apply_dir(d: Dictionary) -> void:
	if d.is_empty():
		return
	if d.has("bg"):
		_set_bg(d["bg"], true)
	for id in d.get("exit", []):
		_stage.leave(str(id))
	var faces: Dictionary = d.get("expr", {})
	for row in d.get("enter", []):
		var who := str(row.get("who", ""))
		if who != "" and not _stage.has_actor(who):
			_stage.enter(who, str(row.get("at", "")), str(faces.get(who, "")))
	for who in faces:
		if _stage.has_actor(str(who)):
			_stage.set_expr(str(who), str(faces[who]))
		else:
			_pending_expr[str(who)] = str(faces[who])


func _set_plate(text: String, kind_s: String, who: String) -> void:
	_plate.visible = text != ""
	if text == "":
		return
	_plate_label.text = text
	var name_key := "hd_gold_hi" if kind_s == "say" else "hd_parchment"
	_plate_label.add_theme_color_override(&"font_color", HdTheme.color(name_key))
	_plate_bar.color = HdArt.accent(who) if kind_s == "say" and who != "" else HdTheme.color("hd_gold")
	_plate.reset_size()
	_plate.position = PLATE_POS


func _set_bg(spec: Dictionary, animate: bool, banner: bool = true) -> void:
	var id := str(spec.get("id", ""))
	if id == "":
		return
	var variant := str(spec.get("variant", ""))
	var key := id + "__" + variant
	if key == _bg_key:
		return
	_bg_key = key
	var node := HdPlaceholder.make_bg(id, "", "", variant)
	node.name = "Bg_" + id
	# 占位卡中间的大地点名不画（开场有章节卡，换场景有顶上的地点横幅）
	if HdPlaceholder.is_placeholder(node):
		node.set("title_alpha", 0.0)
	_bg_layer.add_child(node)
	node.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var old := _bg_node
	_bg_node = node
	if animate:
		_chip_label.text = HdArt.display_name("bg", id)
		_chip.reset_size()
		if banner:
			_show_banner(_chip_label.text)
	if not animate or fast or old == null:
		if old != null and is_instance_valid(old):
			old.queue_free()
		return
	# 交叉淡化：新背景从透明淡进来，盖住旧的以后释放旧的
	node.modulate.a = 0.0
	var tw := node.create_tween()
	tw.tween_property(node, "modulate:a", 1.0, BG_FADE_S)
	tw.tween_callback(func() -> void:
		if is_instance_valid(old):
			old.queue_free())


func _hide_banner() -> void:
	if _banner == null:
		return
	if _banner.has_meta("tw"):
		var old_tw = _banner.get_meta("tw")
		if old_tw is Tween and (old_tw as Tween).is_valid():
			(old_tw as Tween).kill()
	_banner.visible = false
	if _chip != null:
		_chip.modulate.a = 1.0


## 换场景时顶上亮一下地点名（真图、占位都一样），过一会儿淡掉
func _show_banner(text: String) -> void:
	if _banner == null or text == "":
		return
	_banner_label.text = text
	_banner.reset_size()
	_banner.position = Vector2((1280.0 - _banner.size.x) * 0.5, 14)
	_banner.visible = true
	if fast:
		_banner.visible = false
		return
	# 横幅亮着时左上角的地点签先藏起来（同一个地名不同时出现两次），横幅淡出以后它再淡入
	_chip.modulate.a = 0.0
	if _banner.has_meta("tw"):
		var old_tw = _banner.get_meta("tw")
		if old_tw is Tween and (old_tw as Tween).is_valid():
			(old_tw as Tween).kill()
	_banner.modulate.a = 0.0
	var tw := _banner.create_tween()
	tw.tween_property(_banner, "modulate:a", 1.0, 0.35)
	tw.tween_interval(1.8)
	tw.tween_property(_banner, "modulate:a", 0.0, 0.7)
	tw.tween_callback(_banner.hide)
	tw.tween_property(_chip, "modulate:a", 1.0, 0.35)
	_banner.set_meta("tw", tw)


# ================================================================ 抉择

func _open_choices() -> void:
	_state = "choices"
	_skip = false
	_sync_bar()
	var cbg := VnScript.choices_bg(_scene_id, _presentation)
	if not cbg.is_empty():
		# 不亮地点横幅：横幅会压在“如何处置？”上（左上角的地点牌照样换）
		_set_bg(cbg, true, false)
	_stage.focus("")
	_dim_stage(true)
	# 正文里换场景亮起的地点横幅（快进时还没淡完）在菜单出来时收掉，不压“如何处置？”
	_hide_banner()
	_box.visible = false
	if _dock != null:
		_dock.visible = false
	_plate.visible = false
	_arrow.visible = false
	_sync_dock()
	_rebuild_choices()
	if _closed:
		return
	_choice_root.visible = not _hidden
	if not fast:
		_choice_root.modulate.a = 0.0
		_choice_root.create_tween().tween_property(_choice_root, "modulate:a", 1.0, 0.25)


func _rebuild_choices() -> void:
	if _closed or _state != "choices":
		return
	var cv := _card()
	if cv.is_empty():
		_close({})
		return
	for c in _menu.get_children():
		_menu.remove_child(c)
		c.queue_free()
	var prompt := HdTheme.make_label(Data.text("choice_prompt"), 30, "title", "hd_gold_hi")
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.custom_minimum_size = Vector2(MENU_W, 48)
	_menu.add_child(prompt)
	var appraise: Array = []
	var decide: Array = []
	for c in cv.get("choices", []):
		if typeof(c) != TYPE_DICTIONARY:
			continue
		if _is_appraisal(str(c.get("id", ""))):
			appraise.append(c)
		else:
			decide.append(c)
	# 选项放进一个滚动框：先按常规行高排；整个菜单高过屏幕（顶栏下面到底边）就挤一挤（行矮一点、间距小一点），
	# 还放不下才让中间的选项滚动——“重看本场”“稍后再来”那一行永远在屏幕上
	var scroll := ScrollContainer.new()
	scroll.name = "ChoiceScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(MENU_W + 8, 0)
	_menu.add_child(scroll)
	var tail := HBoxContainer.new()
	tail.alignment = BoxContainer.ALIGNMENT_CENTER
	tail.add_theme_constant_override(&"separation", 18)
	var replay := _ghost(Data.text("choice_replay"), "BtnReplay")
	replay.pressed.connect(_replay)
	tail.add_child(replay)
	var later := _ghost(Data.text("choice_later"), "BtnLater")
	later.set_meta("reply_id", "later")
	later.pressed.connect(_on_choice.bind("later"))
	tail.add_child(later)
	_menu.add_child(tail)
	# 量实际高度（按钮的字和内边距撑出来的才算数）：先常规行高，放不下换挤一挤，还放不下就滚动
	var avail := 720.0 - MENU_TOP - MENU_BOTTOM - _menu.get_combined_minimum_size().y
	var rows_box := _choice_rows(appraise, decide, 0)
	scroll.add_child(rows_box)
	var rows_h := rows_box.get_combined_minimum_size().y
	if rows_h > avail:
		scroll.remove_child(rows_box)
		rows_box.free()
		rows_box = _choice_rows(appraise, decide, 1)
		scroll.add_child(rows_box)
		rows_h = rows_box.get_combined_minimum_size().y
	if rows_h > avail:
		scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
		scroll.custom_minimum_size.y = maxf(avail, 120.0)
	else:
		scroll.custom_minimum_size.y = rows_h
	_menu.reset_size()
	var h := _menu.get_combined_minimum_size().y
	var top := clampf((720.0 - h) * 0.5 + 10.0, MENU_TOP, maxf(MENU_TOP, 720.0 - MENU_BOTTOM - h))
	_menu.position = Vector2((1280.0 - MENU_W) * 0.5, top)
	_fill_clues(cv)
	_fill_gauges()


## 一组选项行（鉴定、抉择两组，各带小标题）；mode 0 常规行高，1 挤一挤
func _choice_rows(appraise: Array, decide: Array, mode: int) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.name = "Rows"
	box.add_theme_constant_override(&"separation", int(ROW_SEP[mode]))
	box.custom_minimum_size = Vector2(MENU_W, 0)
	var b2: Dictionary = engine.query(&"campaign.battle2") if engine != null else {}
	if bool(b2.get("has_battle", false)) and not bool(b2.get("resolved", false)):
		box.add_child(_battle_guide_box(mode))
	var n := 0
	for group in [["group_appraise", appraise], ["group_decide", decide]]:
		var rows: Array = group[1]
		if rows.is_empty():
			continue
		box.add_child(_group_head(Data.text(str(group[0]))))
		for c in rows:
			n += 1
			box.add_child(_choice_button(c, n, mode))
	return box


func _battle_guide_box(mode: int) -> Control:
	var panel := PanelContainer.new()
	panel.name = "BattleGuideBox"
	var pbox := HdTheme.panel_box("glass_strong")
	pbox.content_margin_left = 14
	pbox.content_margin_right = 14
	pbox.content_margin_top = 8 if mode == 0 else 6
	pbox.content_margin_bottom = 8 if mode == 0 else 6
	panel.add_theme_stylebox_override(&"panel", pbox)
	panel.custom_minimum_size = Vector2(MENU_W, 104.0 if mode == 0 else 92.0)
	var col := VBoxContainer.new()
	col.add_theme_constant_override(&"separation", 4)
	panel.add_child(col)
	var head := HdTheme.make_label(Data.text("battle_guide_head"), 15 if mode == 0 else 14, "sans_bold", "hd_gold_hi")
	head.clip_text = true
	head.custom_minimum_size = Vector2(MENU_W - 28.0, 20.0)
	col.add_child(head)
	var body := HdTheme.make_label(Data.text("battle_guide_body"), 12, "sans", "hd_parchment")
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.clip_text = true
	body.custom_minimum_size = Vector2(MENU_W - 28.0, 34.0 if mode == 0 else 30.0)
	col.add_child(body)
	var btn := Button.new()
	btn.name = "BtnEnterBattle"
	btn.text = Data.text("battle_guide_btn")
	HdTheme.apply_button(btn, "primary")
	btn.custom_minimum_size = Vector2(MENU_W - 28.0, 34.0 if mode == 0 else 30.0)
	btn.focus_mode = Control.FOCUS_NONE
	btn.pressed.connect(func() -> void: _close({"open_uid": "battle"}))
	col.add_child(btn)
	return panel


## 抉择时右边的账面：金库、同盟威望、敌方警戒、生命与动力、建设 / 探索（engine.query(campaign).gauges）
func _fill_gauges() -> void:
	if _gauge_box == null:
		return
	for c in _gauge_box.get_children():
		_gauge_box.remove_child(c)
		c.queue_free()
	var head := HdTheme.make_label(Data.text("gauges_title"), 16, "title", "hd_gold_hi")
	_gauge_box.add_child(head)
	var rule := Deco.new().setup("line")
	rule.custom_minimum_size = Vector2(0, 8)
	_gauge_box.add_child(rule)
	var c: Dictionary = engine.query(&"campaign") if engine != null else {}
	var chapter := str(c.get("chapter_id", ""))
	var money: Dictionary = _view().get("money", {}) if typeof(_view().get("money", {})) == TYPE_DICTIONARY else {}
	var unit := CardText.ui("c01.money.unit." + str(money.get("currency", ""))).strip_edges()
	for g in c.get("gauges", []):
		if typeof(g) != TYPE_DICTIONARY:
			continue
		var gid := str(g.get("id", ""))
		if gid == "construction" and chapter == "nautilus" or gid == "exploration" and chapter != "nautilus":
			continue
		var row := HBoxContainer.new()
		row.name = "Gauge_" + gid
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var l := HdTheme.make_label(str(g.get("label", gid)), 13, "sans", "hd_text_2")
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		l.custom_minimum_size = Vector2(60, 0)
		row.add_child(l)
		var v := int(g.get("amount", 0))
		var val := HdTheme.make_label(str(v), 15, "num", "hd_text")
		val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		if gid == "heat" and v >= 50 or gid in ["vitality", "morale"] and v <= 30:
			val.add_theme_color_override(&"font_color", HdTheme.color("hd_warn"))
		row.add_child(val)
		_gauge_box.add_child(row)
		if gid == "treasury" and unit != "":
			# 币名可能很长（“双N深海金砖／山铜储备”）：单独一行小字，放不下省略，全名在悬停提示里
			var ul := HdTheme.make_label(unit, 11, "sans", "hd_text_3")
			ul.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			ul.custom_minimum_size = Vector2(GAUGES.size.x - 28, 0)
			ul.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			ul.tooltip_text = unit
			ul.mouse_filter = Control.MOUSE_FILTER_PASS
			_gauge_box.add_child(ul)
	_gauge_panel.visible = true
	_gauge_panel.reset_size()
	_gauge_panel.size = Vector2(GAUGES.size.x, 0)


## 抉择菜单开着时台上的人淡一点（灰的选项后面不再透出外套和扣子）
func _dim_stage(on: bool) -> void:
	_stage.set_chips_visible(not on)
	var to := 0.45 if on else 1.0
	if fast or not is_inside_tree():
		_stage.modulate.a = to
		return
	_stage.create_tween().tween_property(_stage, "modulate:a", to, 0.25)


func _group_head(text: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 14)
	row.custom_minimum_size = Vector2(MENU_W, 26)
	var l1 := Deco.new().setup("line")
	l1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l1)
	var lab := HdTheme.make_label(text, 15, "sans_bold", "hd_gold")
	lab.add_theme_font_override(&"font", HdTheme.font("sans_bold", 4))
	row.add_child(lab)
	var l2 := Deco.new().setup("line")
	l2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l2)
	return row


func _choice_button(c: Dictionary, n: int, mode: int = 0) -> Button:
	var id := str(c.get("id", ""))
	var enabled := bool(c.get("enabled", true))
	var b := Button.new()
	b.name = "Choice_" + id.replace(":", "_")
	b.text = CardText.card(_def, "choices." + id)
	if b.text == "":
		b.text = id
	HdTheme.apply_button(b, "choice")
	b.custom_minimum_size = Vector2(MENU_W, ROW_H[mode])
	if mode == 1:
		b.add_theme_font_size_override(&"font_size", 18)
		var seen: Array = []
		for st in [&"normal", &"hover", &"pressed", &"hover_pressed", &"disabled"]:
			var sbx := b.get_theme_stylebox(st)
			if sbx != null and not seen.has(sbx):
				seen.append(sbx)
				sbx.content_margin_top = 7.0
				sbx.content_margin_bottom = 7.0
	b.disabled = not enabled
	b.focus_mode = Control.FOCUS_ALL if enabled else Control.FOCUS_NONE
	b.set_meta("reply_id", id)
	b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	b.pressed.connect(_on_choice.bind(id))
	var key := HdTheme.make_label(str(n) if n <= 9 else "", 13, "num", "hd_gold")
	key.name = "Key"
	key.modulate.a = 0.75 if enabled else 0.35
	b.add_child(key)
	key.position = Vector2(20, 17 if mode == 0 else 13)
	if not enabled:
		var why := _reason_text(c)
		if why != "":
			# 原因写在按钮下半截：每种状态的框（hover_pressed 和 pressed 是同一个）下边距加高一次
			var done: Array = []
			for st in [&"normal", &"hover", &"pressed", &"hover_pressed", &"disabled"]:
				var sb := b.get_theme_stylebox(st)
				if sb != null and not done.has(sb):
					done.append(sb)
					sb.content_margin_bottom = sb.content_margin_bottom + (22.0 if mode == 0 else 18.0)
			b.custom_minimum_size.y = ROW_OFF_H[mode]
			var rl := HdTheme.make_label(why, 14, "sans", "hd_warn")
			rl.name = "Reason"
			rl.modulate.a = 0.85
			rl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			rl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			b.add_child(rl)
			rl.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
			rl.offset_left = 40
			rl.offset_right = -40
			rl.offset_top = -32 if mode == 0 else -27
			rl.offset_bottom = -12 if mode == 0 else -9
	return b


## 灰掉的原因：引擎给的原因码（reason）有对应的字就用它（缺鉴定时列出还缺哪几项），否则用牌上的 reason_key
func _reason_text(c: Dictionary) -> String:
	var code := str(c.get("reason", ""))
	if code == "missing_clue":
		var names := PackedStringArray()
		for need in c.get("needs", []):
			var label := CardText.card(_def, "choices." + str(need))
			if label != "":
				names.append(label)
		if not names.is_empty():
			return Data.reason(code, {"needs": Data.text("list_sep").join(names)})
	elif code != "" and code != "battle_pending":
		var t := Data.reason(code)
		if t != "":
			return t
	var ref := str(c.get("reason_key", ""))
	return CardText.t(ref) if ref != "" else ""


func _fill_clues(cv: Dictionary) -> void:
	for c in _clue_box.get_children():
		_clue_box.remove_child(c)
		c.queue_free()
	var head := HdTheme.make_label(Data.text("clues_title"), 16, "title", "hd_gold_hi")
	_clue_box.add_child(head)
	var rule := Deco.new().setup("line")
	rule.custom_minimum_size = Vector2(0, 8)
	_clue_box.add_child(rule)
	var obs: Array = cv.get("observations", [])
	if obs.is_empty():
		var none := _wrap_label(Data.text("clues_empty"), 13, "hd_text_3")
		_clue_box.add_child(none)
	for key in obs:
		var aid := str(key).get_slice(".", 3)
		var label := _wrap_label(CardText.card(_def, "choices." + _appraise_prefix() + aid), 14, "hd_gold")
		_clue_box.add_child(label)
		var body := _wrap_label(CardText.ui(str(key)), 13, "hd_text_2")
		_clue_box.add_child(body)
	_clue_panel.visible = true
	_clue_panel.reset_size()
	_clue_box.custom_minimum_size = Vector2(CLUES.size.x - 28, 0)
	_clue_panel.size = Vector2(CLUES.size.x, 0)
	_fit_clues.call_deferred()


## 线索框按内容高（自动换行的字要排过一次才知道多高），最高 CLUES.size.y
func _fit_clues() -> void:
	if _clue_panel == null or not is_instance_valid(_clue_panel):
		return
	_clue_panel.reset_size()
	_clue_panel.size = Vector2(CLUES.size.x, minf(_clue_panel.get_combined_minimum_size().y, CLUES.size.y))


func _on_choice(id: String) -> void:
	if _busy or _closed or _state != "choices":
		return
	if id == "later":
		_close({})
		return
	var label := CardText.card(_def, "choices." + id)
	var before := _snapshot()
	_busy = true
	var res: Dictionary = engine.send(CMD, {"uid": _uid, "choice": id}) if engine != null else {"ok": false, "err": "no_engine"}
	_busy = false
	if _closed:
		return
	_choice_root.visible = false
	if not bool(res.get("ok", false)):
		_queue([VnScript.extra("sys", "", Data.text("error", {"err": str(res.get("err", ""))}))], "choices")
		return
	if _is_appraisal(id):
		var obs := str(res.get("observation", ""))
		if obs == "":
			obs = CardText.ui("ocean.%s.%s.%s" % ["event_obs" if _uid.begins_with("event:") else "obs", _scene_id, id.trim_prefix(_appraise_prefix())])
		_queue([VnScript.extra("clue", Data.text("plate_appraise", {"label": label}), obs)], "choices")
		return
	var after := _snapshot()
	var out: Array = [VnScript.extra("pick", Data.text("plate_decision"), label)]
	out.append_array(_result_lines(before, after))
	# 推进剧情的决定（场次变了、到了结局）放完结算就关；不推进的（一次性的暗账、自主航路）放完回菜单
	var moved := str(after["scene"]) != str(before["scene"]) or str(after["phase"]) != "day" or _card().is_empty()
	if str(after["scene"]) != str(before["scene"]) and str(after["phase"]) == "day" and OS.get_environment("DEHOUDANG_NO_MAP") == "1":
		_next_open_uid = "story:" + str(after["scene"])
	_queue(out, "close" if moved else "choices")


func _queue(rows: Array, then: String) -> void:
	_dim_stage(false)
	var start := _lines.size()
	_lines.append_array(rows)
	_index = start - 1
	_then = then
	_state = "line"
	_box.visible = true
	_next_line()


func _replay() -> void:
	if _busy or _closed or _state != "choices":
		return
	_choice_root.visible = false
	_dim_stage(false)
	_stage.clear()
	_bg_key = ""
	var opening := VnScript.opening(_scene_id, _presentation)
	_set_bg(opening.get("bg", {}), false)
	_opening_cast = opening.get("cast", [])
	_enter_opening_cast()
	var cv := _card()
	_lines = VnScript.build(_scene_id, _paras(), _presentation)
	_lines.append_array(_clue_lines(cv))
	_then = "choices"
	_index = -1
	_state = "line"
	_box.visible = true
	_next_line()


# ================================================================ 结算

func _snapshot() -> Dictionary:
	var c: Dictionary = engine.query(&"campaign") if engine != null else {}
	var kept := {}
	for row in _view().get("kept", []):
		if typeof(row) == TYPE_DICTIONARY:
			kept[str(row.get("uid", ""))] = str(row.get("def", ""))
	return {"gauges": c.get("gauges", []), "chapter": str(c.get("chapter_id", "")), "scene": str(c.get("scene_id", "")),
		"phase": str(c.get("phase", "")), "kept": kept}


## 作出决定以后：账目怎么变了、行军箱进出了什么、下一场是什么（结局就说航程合上账簿；还在这一场就不说）
func _result_lines(before: Dictionary, after: Dictionary) -> Array:
	var new_chapter := str(after["chapter"]) != str(before["chapter"])
	var old := {}
	for g in before["gauges"]:
		old[str(g.get("id", ""))] = int(g.get("amount", 0))
	var changes := PackedStringArray()
	for g in after["gauges"]:
		var gid := str(g.get("id", ""))
		if new_chapter and gid == "treasury":
			continue
		var d := int(g.get("amount", 0)) - int(old.get(gid, int(g.get("amount", 0))))
		if d != 0:
			changes.append(Data.text("change", {"label": str(g.get("label", gid)), "delta": "%+d" % d}))
	var text := Data.text("change_sep").join(changes) if not changes.is_empty() else Data.text("result_none")
	var got := PackedStringArray()
	var lost := PackedStringArray()
	var kb: Dictionary = before["kept"]
	var ka: Dictionary = after["kept"]
	for uid in ka:
		if not kb.has(uid):
			got.append(CardText.card(str(ka[uid]), "title"))
	for uid in kb:
		if not ka.has(uid):
			lost.append(CardText.card(str(kb[uid]), "title"))
	if not got.is_empty():
		text += "\n" + Data.text("result_items_in", {"names": Data.text("list_sep").join(got)})
	if not lost.is_empty():
		text += "\n" + Data.text("result_items_out", {"names": Data.text("list_sep").join(lost)})
	var out: Array = [VnScript.extra("result", Data.text("plate_result"), text)]
	if str(after["phase"]) == "game_over":
		out.append(VnScript.extra("narr", "", Data.text("ending")))
		return out
	var next_def := "ocean.scene." + str(after["scene"])
	if new_chapter:
		out.append(VnScript.extra("narr", "", Data.text("result_chapter", {"chapter": CardText.card(next_def, "chapter")})))
	if str(after["scene"]) != str(before["scene"]):
		out.append(VnScript.extra("narr", "", Data.text("next_scene", {"title": CardText.card(next_def, "title")})))
	return out


# ================================================================ 记录、隐藏、按钮

func _fill_log() -> void:
	for c in _log_list.get_children():
		_log_list.remove_child(c)
		c.queue_free()
	if _log.is_empty():
		_log_list.add_child(_wrap_label(Data.text("log_empty"), 16, "hd_text_3"))
		return
	for row in _log:
		var line := HBoxContainer.new()
		line.add_theme_constant_override(&"separation", 18)
		var who := HdTheme.make_label(str(row.get("name", "")), 16, "title",
			"hd_gold_hi" if str(row.get("kind", "")) == "say" else "hd_parchment_2")
		who.custom_minimum_size = Vector2(190, 0)
		who.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		who.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		line.add_child(who)
		var said := _wrap_label(str(row.get("text", "")), 18, "hd_text" if str(row.get("kind", "")) != "narr" else "hd_text_2")
		said.add_theme_font_override(&"font", HdTheme.font("serif"))
		said.custom_minimum_size = Vector2(700, 0)
		said.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(said)
		_log_list.add_child(line)


func _scroll_log_end() -> void:
	if _log_scroll == null or not is_instance_valid(_log_scroll):
		return
	_log_scroll.scroll_vertical = int(_log_scroll.get_v_scroll_bar().max_value)


func _log_row(line: Dictionary) -> Dictionary:
	return {"name": str(line.get("name", "")), "text": str(line.get("text", "")), "kind": str(line.get("kind", "narr")),
		"who": str(line.get("who", ""))}


func _sync_bar() -> void:
	if _btn_auto == null:
		return
	_btn_auto.set_pressed_no_signal(_auto)
	_btn_skip.set_pressed_no_signal(_skip)
	_btn_skip.disabled = _state == "choices"
	_btn_hide.disabled = false
	_badge.visible = _auto or _skip
	_badge_label.text = Data.text("badge_skip" if _skip else "badge_auto")
	_badge.reset_size()
	_badge.position = Vector2(BOX.end.x - _badge.size.x - 22, BOX.position.y - _badge.size.y * 0.5)


func _gui_input(event: InputEvent) -> void:
	if _closed or not (event is InputEventMouseButton):
		return
	var mb := event as InputEventMouseButton
	if not mb.pressed:
		return
	match mb.button_index:
		MOUSE_BUTTON_LEFT:
			advance()
			accept_event()
		MOUSE_BUTTON_RIGHT:
			set_hidden(not _hidden)
			accept_event()
		MOUSE_BUTTON_WHEEL_UP:
			if not _hidden and _state in ["line", "choices"]:
				open_log()
			accept_event()


## 空格 / 回车 = 点一下；抉择菜单上 1–9 选第几个选项。Esc 归宿主（close_top -> dismiss）。
func _unhandled_input(event: InputEvent) -> void:
	if _closed or not (event is InputEventKey):
		return
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return
	var code := key.keycode if key.keycode != KEY_NONE else key.physical_keycode
	if code in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]:
		if _log_open:
			close_log()
		elif _state != "choices":
			advance()
		_handled()
	elif code >= KEY_1 and code <= KEY_9 and _state == "choices" and not _log_open:
		var buttons := choice_buttons()
		var i := code - KEY_1
		if i < buttons.size() and not buttons[i].disabled:
			buttons[i].pressed.emit()
		_handled()


func _handled() -> void:
	var vp := get_viewport()
	if vp != null:
		vp.set_input_as_handled()


func _close(result: Dictionary) -> void:
	if _closed:
		return
	_closed = true
	_state = "closed"
	close_requested.emit(result)


# ================================================================ 引擎和文字

func _card() -> Dictionary:
	if engine == null or _uid == "":
		return {}
	var result = engine.query(&"card", {"uid": _uid})
	return result if typeof(result) == TYPE_DICTIONARY else {}


func _view() -> Dictionary:
	if engine == null:
		return {}
	var raw = engine.view()
	return raw if typeof(raw) == TYPE_DICTIONARY else {}


## 正文段落（覆盖层 paras：剧情牌 body 原样的段落；没有时退回分好页的 body）
func _paras() -> PackedStringArray:
	var raw := CardText.card(_def, "paras")
	if raw == "":
		raw = CardText.card(_def, "body")
	return raw.split("\n\n", false)


## 已经鉴定过的线索（旧格子面板把它们写在正文后面）：一条一句
func _clue_lines(cv: Dictionary) -> Array:
	var out: Array = []
	for key in cv.get("observations", []):
		var aid := str(key).get_slice(".", 3)
		var label := CardText.card(_def, "choices." + _appraise_prefix() + aid)
		out.append(VnScript.extra("clue", Data.text("plate_clue", {"label": label}), CardText.ui(str(key))))
	return out


func _seen_key() -> String:
	var date: Dictionary = _view().get("date", {})
	return "%d:%s:%d" % [engine.get_instance_id() if engine != null else 0, _uid, int(date.get("abs_day", 0))]


func _walk(node: Node) -> Array:
	var out: Array = [node]
	for c in node.get_children():
		out.append_array(_walk(c))
	return out


# ================================================================ 搭界面

func _ensure() -> void:
	if _bg_layer != null:
		return
	size = Vector2(1280, 720)
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	HdTheme.apply_hd_filter(self)
	var base := ColorRect.new()
	base.color = HdTheme.color("hd_ink")
	base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	base.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(base)
	_bg_layer = _layer("Bg")
	_stage = Stage.new()
	_stage.name = "Stage"
	add_child(_stage)
	_stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ui_root = _layer("Ui")
	_build_ui()
	_choice_root = _layer("Choices")
	_build_choices()
	_top_root = _layer("Top")
	_chip.reparent(_top_root)
	_tut_bar.reparent(_top_root)
	_bar.reparent(_top_root)
	_banner.reparent(_top_root)
	_title = _layer("Title")
	_build_title()
	_log_root = _layer("Log")
	_build_log()
	_hint = HdTheme.make_label(Data.text("hidden_hint"), 14, "sans", "hd_text_2")
	_hint.name = "HiddenHint"
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.position = Vector2(0, 684)
	_hint.size = Vector2(1280, 24)
	_hint.visible = false
	add_child(_hint)


func _layer(node_name: String) -> Control:
	var c := Control.new()
	c.name = node_name
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(c)
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return c


func _build_ui() -> void:
	var top := Deco.new().setup("shade_top")
	top.position = Vector2.ZERO
	top.size = Vector2(1280, 96)
	_ui_root.add_child(top)
	var bottom := Deco.new().setup("shade_bottom")
	bottom.position = Vector2(0, 380)
	bottom.size = Vector2(1280, 340)
	_ui_root.add_child(bottom)
	# 左上：地点
	_chip = PanelContainer.new()
	_chip.name = "Location"
	_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_chip.add_theme_stylebox_override(&"panel", HdTheme.panel_box("chip"))
	_chip_label = HdTheme.make_label("", 15, "serif", "hd_text_2")
	_chip.add_child(_chip_label)
	_chip.position = Vector2(18, 16)
	_ui_root.add_child(_chip)
	# 右上：自动 快进 记录 隐藏 | 稍后
	_bar = PanelContainer.new()
	_bar.name = "Bar"
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bar_box := HdTheme.panel_box("glass_soft")
	if bar_box is StyleBoxFlat:
		(bar_box as StyleBoxFlat).bg_color = HdTheme.alpha("hd_ink", 0.88)
		(bar_box as StyleBoxFlat).border_color = HdTheme.alpha("hd_gold", 0.3)
		(bar_box as StyleBoxFlat).set_border_width_all(1)
	bar_box.content_margin_left = 6
	bar_box.content_margin_right = 6
	bar_box.content_margin_top = 4
	bar_box.content_margin_bottom = 4
	_bar.add_theme_stylebox_override(&"panel", bar_box)
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 4)
	_bar.add_child(row)
	_btn_auto = _bar_button(row, "btn_auto", "tip_auto", "BtnAuto", true)
	_btn_auto.toggled.connect(func(on: bool) -> void: set_auto(on))
	_btn_skip = _bar_button(row, "btn_skip", "tip_skip", "BtnSkip", true)
	_btn_skip.toggled.connect(func(on: bool) -> void: set_skip(on))
	_btn_log = _bar_button(row, "btn_log", "tip_log", "BtnLog", false)
	_btn_log.pressed.connect(open_log)
	_btn_hide = _bar_button(row, "btn_hide", "tip_hide", "BtnHide", false)
	_btn_hide.pressed.connect(func() -> void: set_hidden(true))
	var sep := VSeparator.new()
	sep.add_theme_stylebox_override(&"separator", _sep_box())
	row.add_child(sep)
	_btn_close = _bar_button(row, "btn_close", "tip_close", "BtnClose", false)
	_btn_close.pressed.connect(func() -> void: _close({}))
	_ui_root.add_child(_bar)
	_bar.reset_size()
	_bar.position = Vector2(1280 - 18 - _bar.size.x, 14)
	# 文本框
	_box = Panel.new()
	_box.name = "TextBox"
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_theme_stylebox_override(&"panel", HdTheme.panel_box("textbox"))
	_box.position = BOX.position
	_box.size = BOX.size
	_ui_root.add_child(_box)
	_body = Label.new()
	_body.name = "Line"
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_body.add_theme_font_override(&"font", HdTheme.font("serif", 1))
	_body.add_theme_font_size_override(&"font_size", BODY_SIZE)
	_body.add_theme_constant_override(&"line_spacing", 9)
	_body.add_theme_color_override(&"font_color", HdTheme.color("hd_text"))
	_body.add_theme_color_override(&"font_shadow_color", HdTheme.alpha("hd_shadow", 0.6))
	_body.add_theme_constant_override(&"shadow_offset_y", 1)
	_body.add_theme_constant_override(&"shadow_outline_size", 3)
	_body.position = BODY.position
	_body.size = BODY.size
	_body.clip_text = true
	_box.add_child(_body)
	_arrow = Deco.new().setup("arrow")
	_arrow.name = "Next"
	_arrow.position = Vector2(BOX.size.x - 62, BOX.size.y - 48)
	_arrow.size = Vector2(30, 30)
	_arrow.visible = false
	_box.add_child(_arrow)
	# 名字牌压在文本框左上角
	_plate = PanelContainer.new()
	_plate.name = "NamePlate"
	_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_plate.add_theme_stylebox_override(&"panel", HdTheme.panel_box("nameplate"))
	var prow := HBoxContainer.new()
	prow.add_theme_constant_override(&"separation", 12)
	_plate_bar = ColorRect.new()
	_plate_bar.custom_minimum_size = Vector2(3, 22)
	_plate_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_plate_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	prow.add_child(_plate_bar)
	_plate_label = HdTheme.make_label("", 22, "title", "hd_gold_hi")
	_plate_label.name = "Name"
	prow.add_child(_plate_label)
	_plate.add_child(prow)
	_plate.custom_minimum_size = Vector2(170, 0)
	_plate.position = PLATE_POS
	_plate.visible = false
	_ui_root.add_child(_plate)
	# 自动 / 快进 进行中的小牌
	_badge = PanelContainer.new()
	_badge.name = "Badge"
	_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_badge.add_theme_stylebox_override(&"panel", HdTheme.panel_box("chip"))
	_badge_label = HdTheme.make_label("", 13, "sans", "hd_gold_hi")
	_badge.add_child(_badge_label)
	_badge.visible = false
	_ui_root.add_child(_badge)
	# 换场景的地点横幅
	var banner := PanelContainer.new()
	banner.name = "Banner"
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.add_theme_stylebox_override(&"panel", HdTheme.panel_box("tooltip"))
	var brow := HBoxContainer.new()
	brow.add_theme_constant_override(&"separation", 14)
	brow.alignment = BoxContainer.ALIGNMENT_CENTER
	var bl := Deco.new().setup("rule")
	bl.custom_minimum_size = Vector2(46, 20)
	brow.add_child(bl)
	_banner_label = HdTheme.make_label("", 21, "title", "hd_gold_hi")
	brow.add_child(_banner_label)
	var br := Deco.new().setup("rule")
	br.custom_minimum_size = Vector2(46, 20)
	brow.add_child(br)
	banner.add_child(brow)
	banner.visible = false
	_banner = banner
	_ui_root.add_child(banner)
	# 顶部新手教程长条
	_tut_bar = PanelContainer.new()
	_tut_bar.name = "TutorialBar"
	_tut_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tbox := HdTheme.panel_box("glass_soft")
	tbox.content_margin_left = 10
	tbox.content_margin_right = 10
	tbox.content_margin_top = 4
	tbox.content_margin_bottom = 4
	_tut_bar.add_theme_stylebox_override(&"panel", tbox)
	var tlab := HdTheme.make_label(Data.text("tutorial_banner"), 12, "sans", "hd_gold_hi")
	tlab.clip_text = true
	tlab.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_tut_bar.add_child(tlab)
	_tut_bar.position = Vector2(228, 14)
	_tut_bar.size = Vector2(688, 30)
	_tut_bar.custom_minimum_size = Vector2(688, 30)
	_tut_bar.clip_contents = true
	_ui_root.add_child(_tut_bar)
	# 剧情内卡牌与骰子收集栏
	_dock = PanelContainer.new()
	_dock.name = "CollectionDock"
	_dock.mouse_filter = Control.MOUSE_FILTER_STOP
	var dbox := HdTheme.panel_box("glass_strong")
	dbox.content_margin_left = 14
	dbox.content_margin_right = 14
	dbox.content_margin_top = 5
	dbox.content_margin_bottom = 5
	_dock.add_theme_stylebox_override(&"panel", dbox)
	_dock.position = Vector2(64, 412)
	_dock.size = Vector2(1152, 56)
	_dock.custom_minimum_size = Vector2(1152, 56)
	var dcol := VBoxContainer.new()
	dcol.add_theme_constant_override(&"separation", 2)
	_dock.add_child(dcol)
	var drow1 := HBoxContainer.new()
	drow1.add_theme_constant_override(&"separation", 6)
	var dtitle := HdTheme.make_label(Data.text("dock_title"), 12, "sans_bold", "hd_gold_hi")
	dtitle.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	drow1.add_child(dtitle)
	for spec in [
		["dock_dice", "dice", "BtnDockDice"],
		["dock_town", "town", "BtnDockTown"],
		["dock_spy", "spy", "BtnDockSpy"],
		["dock_salon", "salon", "BtnDockSalon"],
		["dock_train", "train", "BtnDockTrain"],
		["dock_recruit", "recruit", "BtnDockRecruit"],
		["dock_prop", "prop", "BtnDockProp"],
	]:
		_make_dock_btn(drow1, str(spec[0]), str(spec[1]), str(spec[2]))
	dcol.add_child(drow1)
	var drow2 := HBoxContainer.new()
	drow2.add_theme_constant_override(&"separation", 12)
	_dock_coins = HdTheme.make_label("", 12, "sans", "hd_parchment")
	drow2.add_child(_dock_coins)
	_dock_status = HdTheme.make_label("", 12, "sans", "hd_gold_hi")
	_dock_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_dock_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_dock_status.clip_text = true
	drow2.add_child(_dock_status)
	dcol.add_child(drow2)
	_ui_root.add_child(_dock)


func _bar_button(row: HBoxContainer, text_key: String, tip_key: String, node_name: String, toggle: bool) -> Button:
	var b := Button.new()
	b.name = node_name
	b.text = Data.text(text_key)
	b.tooltip_text = Data.text(tip_key)
	HdTheme.apply_button(b, "ghost")
	b.add_theme_font_size_override(&"font_size", 15)
	b.custom_minimum_size = Vector2(58, 30)
	b.toggle_mode = toggle
	b.focus_mode = Control.FOCUS_NONE
	row.add_child(b)
	return b


func _sep_box() -> StyleBoxLine:
	var s := StyleBoxLine.new()
	s.color = HdTheme.alpha("hd_gold", 0.4)
	s.thickness = 1
	s.vertical = true
	s.grow_begin = -6
	s.grow_end = -6
	return s


func _ghost(text: String, node_name: String) -> Button:
	var b := Button.new()
	b.name = node_name
	b.text = text
	HdTheme.apply_button(b, "ghost")
	b.custom_minimum_size = Vector2(150, 38)
	return b


func _build_choices() -> void:
	var dim := Deco.new().setup("dim")
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_choice_root.add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_menu = VBoxContainer.new()
	_menu.name = "Menu"
	_menu.add_theme_constant_override(&"separation", 9)
	_menu.custom_minimum_size = Vector2(MENU_W, 0)
	_choice_root.add_child(_menu)
	_clue_panel = PanelContainer.new()
	_clue_panel.name = "Clues"
	_clue_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := HdTheme.panel_box("glass")
	box.content_margin_left = 14
	box.content_margin_right = 12
	_clue_panel.add_theme_stylebox_override(&"panel", box)
	_clue_panel.position = CLUES.position
	_clue_panel.custom_minimum_size = Vector2(CLUES.size.x, 0)
	_clue_panel.clip_contents = true
	_clue_box = VBoxContainer.new()
	_clue_box.add_theme_constant_override(&"separation", 5)
	_clue_panel.add_child(_clue_box)
	_choice_root.add_child(_clue_panel)
	_gauge_panel = PanelContainer.new()
	_gauge_panel.name = "Gauges"
	_gauge_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var gbox := HdTheme.panel_box("glass")
	gbox.content_margin_left = 14
	gbox.content_margin_right = 14
	_gauge_panel.add_theme_stylebox_override(&"panel", gbox)
	_gauge_panel.position = GAUGES.position
	_gauge_panel.custom_minimum_size = Vector2(GAUGES.size.x, 0)
	_gauge_panel.clip_contents = true
	_gauge_box = VBoxContainer.new()
	_gauge_box.add_theme_constant_override(&"separation", 6)
	_gauge_panel.add_child(_gauge_box)
	_choice_root.add_child(_gauge_panel)
	_choice_dock = PanelContainer.new()
	_choice_dock.name = "ChoiceCollectionDock"
	_choice_dock.mouse_filter = Control.MOUSE_FILTER_STOP
	var cdbox := HdTheme.panel_box("glass")
	cdbox.content_margin_left = 8
	cdbox.content_margin_right = 8
	cdbox.content_margin_top = 8
	cdbox.content_margin_bottom = 8
	_choice_dock.add_theme_stylebox_override(&"panel", cdbox)
	_choice_dock.position = Vector2(GAUGES.position.x, 304)
	_choice_dock.custom_minimum_size = Vector2(GAUGES.size.x, 0)
	_choice_dock.size = Vector2(GAUGES.size.x, 360)
	var cdcol := VBoxContainer.new()
	cdcol.add_theme_constant_override(&"separation", 5)
	_choice_dock.add_child(cdcol)
	var cdhead := _wrap_label(Data.text("dock_title"), 12, "hd_gold_hi")
	cdcol.add_child(cdhead)
	_choice_dock_coins = _wrap_label("", 11, "hd_parchment")
	cdcol.add_child(_choice_dock_coins)
	var cdgrid := GridContainer.new()
	cdgrid.columns = 2
	cdgrid.add_theme_constant_override(&"h_separation", 4)
	cdgrid.add_theme_constant_override(&"v_separation", 4)
	for spec in [
		["dock_dice", "dice", "BtnChoiceDice"],
		["dock_town", "town", "BtnChoiceTown"],
		["dock_spy", "spy", "BtnChoiceSpy"],
		["dock_salon", "salon", "BtnChoiceSalon"],
		["dock_train", "train", "BtnChoiceTrain"],
		["dock_recruit", "recruit", "BtnChoiceRecruit"],
		["dock_prop", "prop", "BtnChoiceProp"],
	]:
		_make_dock_btn(cdgrid, str(spec[0]), str(spec[1]), str(spec[2]), 86)
	cdcol.add_child(cdgrid)
	_choice_dock_status = _wrap_label("", 11, "hd_gold_hi")
	cdcol.add_child(_choice_dock_status)
	_choice_root.add_child(_choice_dock)
	_choice_root.visible = false


func _build_title() -> void:
	_title.mouse_filter = Control.MOUSE_FILTER_STOP
	_title.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed:
			_end_title())
	var band := Deco.new().setup("band")
	band.position = Vector2(0, 196)
	band.size = Vector2(1280, 330)
	_title.add_child(band)
	_title_chapter = HdTheme.make_label("", 17, "sans_bold", "hd_gold")
	_title_chapter.add_theme_font_override(&"font", HdTheme.font("sans_bold", 4))
	_title_chapter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_chapter.position = Vector2(0, 280)
	_title_chapter.size = Vector2(1280, 26)
	_title.add_child(_title_chapter)
	_title_main = HdTheme.make_label("", 42, "title", "hd_text")
	_title_main.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_main.position = Vector2(60, 312)
	_title_main.size = Vector2(1160, 60)
	_title.add_child(_title_main)
	var rule := Deco.new().setup("rule")
	rule.position = Vector2(440, 384)
	rule.size = Vector2(400, 14)
	_title.add_child(rule)
	_title_sub = HdTheme.make_label("", 19, "serif", "hd_text_2")
	_title_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_sub.position = Vector2(0, 406)
	_title_sub.size = Vector2(1280, 30)
	_title.add_child(_title_sub)
	_title.visible = false


func _build_log() -> void:
	_log_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_log_root.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed \
				and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_RIGHT:
			close_log())
	var dim := ColorRect.new()
	dim.color = HdTheme.alpha("hd_ink", 0.72)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_log_root.add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	panel.name = "LogPanel"
	panel.add_theme_stylebox_override(&"panel", HdTheme.panel_box("glass_strong"))
	panel.position = LOG.position
	panel.size = LOG.size
	panel.custom_minimum_size = LOG.size
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	_log_root.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override(&"separation", 10)
	panel.add_child(col)
	var head := HBoxContainer.new()
	var title := HdTheme.make_label(Data.text("log_title"), 26, "title", "hd_gold_hi")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var back := Button.new()
	back.name = "BtnLogBack"
	back.text = Data.text("log_back")
	HdTheme.apply_button(back, "secondary")
	back.focus_mode = Control.FOCUS_NONE
	back.pressed.connect(close_log)
	head.add_child(back)
	col.add_child(head)
	var rule := Deco.new().setup("line")
	rule.custom_minimum_size = Vector2(0, 8)
	col.add_child(rule)
	_log_scroll = ScrollContainer.new()
	_log_scroll.name = "LogScroll"
	_log_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_log_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(_log_scroll)
	_log_list = VBoxContainer.new()
	_log_list.name = "LogList"
	_log_list.add_theme_constant_override(&"separation", 14)
	_log_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_log_scroll.add_child(_log_list)
	_log_root.visible = false


func _wrap_label(text: String, font_size: int, color_key: String) -> Label:
	var l := HdTheme.make_label(text, font_size, "sans", color_key)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(1, 0)
	return l


func _appraise_prefix() -> String:
	return MAP_APPRAISE if _uid.begins_with("event:") else APPRAISE


static func _is_appraisal(id: String) -> bool:
	return id.begins_with(APPRAISE) or id.begins_with(MAP_APPRAISE)


func _make_dock_btn(parent: Control, text_key: String, act: String, node_name: String, min_w: int = 92) -> Button:
	var b := Button.new()
	b.name = node_name
	b.text = Data.text(text_key)
	HdTheme.apply_button(b, "secondary")
	b.add_theme_font_size_override(&"font_size", 12)
	b.custom_minimum_size = Vector2(min_w, 26)
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(_on_dock_action.bind(act))
	parent.add_child(b)
	return b


func _sync_dock() -> void:
	if engine == null or _dock_coins == null:
		return
	var c: Dictionary = engine.query(&"campaign")
	var t_val := 0
	for g in c.get("gauges", []):
		if typeof(g) == TYPE_DICTIONARY and str(g.get("id", "")) == "treasury":
			t_val = int(g.get("amount", 0))
	var coins: Dictionary = c.get("coins", {}) if typeof(c.get("coins", {})) == TYPE_DICTIONARY else {}
	var txt := Data.text("dock_coins", {
		"treasury": str(t_val),
		"gold": str(int(coins.get("gold", 0))),
		"supply": str(int(coins.get("supply", 0))),
		"medal": str(int(coins.get("medal", 0))),
		"intel": str(int(coins.get("intel", 0))),
	})
	_dock_coins.text = txt
	if _choice_dock_coins != null:
		_choice_dock_coins.text = txt


func _on_dock_action(act: String) -> void:
	if _busy or _closed or engine == null:
		return
	var msg := ""
	if act == "dice":
		var r: Dictionary = engine.send(&"campaign.roll_dice", {})
		if not bool(r.get("ok", false)):
			_try_card_any(["march"], ["action:pick_route:"])
			r = engine.send(&"campaign.roll_dice", {})
		if not bool(r.get("ok", false)) and _can_refresh_collection_turn():
			_refresh_collection_turn()
			r = engine.send(&"campaign.roll_dice", {})
		if bool(r.get("ok", false)):
			msg = Data.text("dock_feedback_dice", {"steps": str(r.get("steps", 3))})
	elif act == "town":
		if _try_card_any(["town"], ["action:trade:fair", "action:visit:town", "action:trade:counterfeit"]) or _try_demands():
			msg = Data.text("dock_feedback_card", {"card": Data.text("dock_town")})
	elif act == "spy":
		if _try_card_any(["backdoor"], ["action:visit:backdoor", "action:activity:"]):
			msg = Data.text("dock_feedback_card", {"card": Data.text("dock_spy")})
	elif act == "salon":
		if _try_card_any(["calendar", "signage"], ["action:schedule:salon", "action:schedule:rest", "action:sign:red", "action:sign:white"]):
			msg = Data.text("dock_feedback_card", {"card": Data.text("dock_salon")})
	elif act == "train":
		if _try_card_any(["calendar", "resources"], ["action:schedule:train", "action:build", "action:explore", "action:fund:yes"]):
			msg = Data.text("dock_feedback_card", {"card": Data.text("dock_train")})
	elif act == "recruit":
		if _try_card_any(["squad"], ["action:recruit:", "action:promote:"]) or _try_companions():
			msg = Data.text("dock_feedback_card", {"card": Data.text("dock_recruit")})
	elif act == "prop":
		if _try_props() or _try_card_any(["resources", "signage"], ["action:build", "action:explore", "action:sign:black"]):
			msg = Data.text("dock_feedback_card", {"card": Data.text("dock_prop")})
	if msg == "":
		msg = Data.text("dock_feedback_done")
	if _dock_status != null:
		_dock_status.text = msg
	if _choice_dock_status != null:
		_choice_dock_status.text = msg
	_sync_dock()
	if _state == "choices":
		_rebuild_choices()


func _try_card_any(uids: Array, prefixes: Array) -> bool:
	for u in uids:
		var cv = engine.query(&"card", {"uid": str(u)})
		if typeof(cv) != TYPE_DICTIONARY:
			continue
		for p in prefixes:
			for ch in cv.get("choices", []):
				if typeof(ch) == TYPE_DICTIONARY and bool(ch.get("enabled", false)) and str(ch.get("id", "")).begins_with(str(p)):
					var res: Dictionary = engine.send(CMD, {"uid": str(u), "choice": str(ch.get("id", ""))})
					if bool(res.get("ok", false)):
						return true
	return false


func _try_demands() -> bool:
	for row in _view().get("hand", []):
		if typeof(row) != TYPE_DICTIONARY:
			continue
		var u := str(row.get("uid", ""))
		if u.begins_with("demand:") and _try_card_any([u], ["action:demand:"]):
			return true
	return false


func _try_companions() -> bool:
	for row in _view().get("kept", []) + _view().get("hand", []):
		if typeof(row) != TYPE_DICTIONARY:
			continue
		var u := str(row.get("uid", ""))
		if u.begins_with("companion:") and _try_card_any([u], ["action:promote:", "action:reserve:", "action:recall:"]):
			return true
	return false


func _try_props() -> bool:
	for row in _view().get("kept", []) + _view().get("hand", []):
		if typeof(row) != TYPE_DICTIONARY:
			continue
		var u := str(row.get("uid", ""))
		if u.begins_with("prop:") and _try_card_any([u], ["action:use_prop:"]):
			return true
	return false


func _can_refresh_collection_turn() -> bool:
	if engine == null or OS.get_environment("DEHOUDANG_NO_MAP") != "1":
		return false
	if str(_view().get("phase", "")) != "day":
		return false
	var c: Dictionary = engine.query(&"campaign")
	var t_val := 0
	var v_val := 0
	for g in c.get("gauges", []):
		if typeof(g) != TYPE_DICTIONARY:
			continue
		if str(g.get("id", "")) == "treasury":
			t_val = int(g.get("amount", 0))
		elif str(g.get("id", "")) == "vitality":
			v_val = int(g.get("amount", 0))
	return t_val >= 180 and v_val >= 35


func _refresh_collection_turn() -> void:
	for step in [&"day.end", &"settle.next", &"day.begin"]:
		var r: Dictionary = engine.send(step, {})
		if not bool(r.get("ok", false)):
			break
