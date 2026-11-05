# Campaign title, seed/archive box and chapter selection. Artwork remains a code placeholder.
extends CardTitle

const HdTheme = preload("res://scripts/cards/ui/hd/hd_theme.gd")
const HdPlaceholder = preload("res://scripts/cards/ui/hd/hd_placeholder.gd")
const D = preload("res://scripts/cards/ui/hd/hd_draw.gd")
const Data = preload("res://scripts/cards/ui/hub/hub_data.gd")
const Campaigns = preload("res://scripts/cards/ui/hub/hub_campaigns.gd")

const HD_LEFT_X := 112.0
const HD_COL_W := 600.0
const HD_TAG_Y := 150.0
const HD_NAME_Y := 176.0
const HD_NAME_PX := 104
const HD_BLURB_Y := 324.0
const HD_BTN_Y := 446.0
const HD_HINT_Y := 528.0
const HD_EMBLEM_C := Vector2(972, 236)
const HD_EMBLEM_R := 168.0
const HD_BOX_RECT := Rect2(760, 436, 440, 236)


## Placeholder crest: an eagle above a three-point compass. Collection labels stay data-driven.
class Emblem extends Control:
	var radius := 168.0
	var branches: Array = []
	var tilt := 0.0:
		set(v):
			tilt = v
			queue_redraw()

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c := size * 0.5
		var r := radius
		var gold := HdTheme.color("hd_gold")
		var hi := HdTheme.color("hd_gold_hi")
		D.glow(self, Rect2(c - Vector2(r * 1.3, r * 1.1), Vector2(r * 2.6, r * 2.2)), HdTheme.alpha("hd_gold", 0.16))
		draw_arc(c, r, 0.0, TAU, 160, HdTheme.alpha("hd_gold", 0.42), 1.6, true)
		draw_arc(c, r - 16.0, 0.0, TAU, 160, HdTheme.alpha("hd_gold", 0.22), 1.0, true)
		for i in 60:
			var a := TAU * float(i) / 60.0
			var dir := Vector2(cos(a), sin(a))
			draw_line(c + dir * (r - (12.0 if i % 5 == 0 else 6.0)), c + dir * r,
				HdTheme.alpha("hd_gold", 0.45), 1.0, true)
		for i in 3:
			var a := TAU * float(i) / 3.0 - PI * 0.5 + tilt
			var dir := Vector2(cos(a), sin(a))
			var side := dir.orthogonal() * 14.0
			draw_colored_polygon(PackedVector2Array([c + dir * (r - 22.0), c + side, c - dir * 24.0, c - side]),
				HdTheme.alpha("hd_gold", 0.28))
			var badge := c + dir * (r + 10.0)
			var active: bool = ["conquest", "ocean", "cristo"][i] in branches
			var ink := HdTheme.alpha("hd_gold_hi", 0.95 if active else 0.28)
			draw_circle(badge, 19.0, HdTheme.color("hd_ink"))
			draw_arc(badge, 19.0, 0, TAU, 32, ink, 1.3, true)
			if i == 0:
				draw_polyline(PackedVector2Array([badge + Vector2(-12, -6), badge + Vector2(0, 6), badge + Vector2(12, -6)]), ink, 2.6, true)
				draw_line(badge + Vector2(0, -10), badge + Vector2(0, 10), ink, 2.0, true)
			elif i == 1:
				draw_arc(badge, 11, 0, TAU * 0.85, 24, ink, 2.0, true)
				draw_arc(badge, 5, PI, TAU * 1.85, 24, ink, 1.6, true)
			else:
				draw_polyline(PackedVector2Array([badge + Vector2(-10, 10), badge + Vector2(-10, -9), badge + Vector2(-4, -9), badge + Vector2(-4, -3), badge + Vector2(4, -3), badge + Vector2(4, -9), badge + Vector2(10, -9), badge + Vector2(10, 10)]), ink, 2.0, true)
		# Angular eagle silhouette; art files may replace the entire placeholder later.
		var bird := PackedVector2Array([Vector2(-116, -38), Vector2(-72, -20), Vector2(-26, -30),
			Vector2(-10, -52), Vector2(-8, -78), Vector2(16, -80), Vector2(29, -66), Vector2(8, -62),
			Vector2(24, -30), Vector2(72, -20), Vector2(116, -38), Vector2(92, 4), Vector2(48, 22),
			Vector2(25, 12), Vector2(15, 42), Vector2(36, 72), Vector2(0, 58), Vector2(-36, 72),
			Vector2(-15, 42), Vector2(-25, 12), Vector2(-48, 22), Vector2(-92, 4)])
		for i in bird.size():
			bird[i] += c
		draw_colored_polygon(bird, gold)
		bird.append(bird[0])
		draw_polyline(bird, hi, 1.4, true)


var _emblem: Emblem = null
var _campaign_options: Dictionary = {}
var _campaign: Dictionary = {}
var _selected_options: Dictionary = {}
var _chapter_drawer: PanelContainer
var _chapter_buttons: Array[Button] = []
var _chapter_index := 0


## Called before entering the tree. Merely browsing never changes the default campaign.
func configure_campaign(opts: Dictionary) -> void:
	_campaign_options = opts.duplicate(true)


func selected_game_options() -> Dictionary:
	return _selected_options.duplicate(true)


## Safe before _ready and after chapter selection; no global campaign or text overrides.
func campaign_window_title() -> String:
	var opts := _campaign_options.duplicate(true)
	if _selected_options.has("entry"):
		opts.erase("segment")
		opts.erase("stage")
	opts.merge(_selected_options, true)
	var selected := Campaigns.model(opts, CardSave.root())
	if not bool(selected.get("explicit", false)):
		return Data.text("brand")
	var title_spec = selected.get("raw", {}).get("title", {})
	if typeof(title_spec) == TYPE_DICTIONARY:
		var book_name := str(title_spec.get("name", "")).strip_edges()
		if not book_name.is_empty():
			return book_name
	return Data.text("campaign_title.name")


func chapter_choices() -> Array:
	return _campaign.get("choices", []).duplicate(true)


func chapter_button(segment: String, stage: int = 0) -> Button:
	for button in _chapter_buttons:
		if str(button.get_meta("segment", "")) == segment and int(button.get_meta("stage", -2)) == stage:
			return button
	return null



func _ready() -> void:
	HdTheme.apply_hd_filter(self)
	# 用 .new() 造的（不是 .tscn）：先把自己铺满父节点，父类的 set_anchors_preset 才保得住满屏
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	super._ready()


## 整个画面（父类在 _ready 里调）：背景、压暗、纹章、字、四颗按钮、说明
func _build() -> void:
	_campaign = Campaigns.model(_campaign_options, CardSave.root())
	_selected_options = _campaign.get("selected", {}).duplicate(true)
	var bg := HdPlaceholder.make_bg("title")
	bg.name = "Back"
	var placeholder := HdPlaceholder.is_placeholder(bg)
	if placeholder:
		bg.set("title_alpha", 0.0)
	add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_wash())
	if placeholder:
		_emblem = Emblem.new()
		_emblem.name = "Emblem"
		_emblem.radius = HD_EMBLEM_R
		_emblem.branches = _campaign.get("info", {}).get("meta", {}).get("branches_reached", []).duplicate()
		_emblem.size = Vector2(HD_EMBLEM_R * 2.8, HD_EMBLEM_R * 2.6)
		_emblem.position = HD_EMBLEM_C - _emblem.size * 0.5
		_emblem.tilt = -0.05
		add_child(_emblem)
		var tw := _emblem.create_tween().set_loops()
		tw.tween_property(_emblem, "tilt", 0.05, 3.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.tween_property(_emblem, "tilt", -0.05, 3.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var tag := _hd_label("Tagline", _title_text("tagline"), HdTheme.font("sans", 5), 15, "hd_gold")
	tag.position = Vector2(HD_LEFT_X, HD_TAG_Y)
	var rule := Rule.new()
	rule.name = "Rule"
	rule.position = Vector2(HD_LEFT_X, HD_TAG_Y + 30.0)
	rule.size = Vector2(HD_COL_W * 0.72, 8)
	add_child(rule)
	var title := _hd_label("Name", _title_text("name"), HdTheme.font("title", 10), HD_NAME_PX, "hd_gold_hi")
	title.position = Vector2(HD_LEFT_X - 6.0, HD_NAME_Y)
	title.add_theme_color_override(&"font_shadow_color", HdTheme.alpha("hd_shadow", 0.55))
	title.add_theme_constant_override(&"shadow_offset_x", 0)
	title.add_theme_constant_override(&"shadow_offset_y", 4)
	title.add_theme_constant_override(&"shadow_outline_size", 6)
	title.add_theme_color_override(&"font_outline_color", HdTheme.alpha("hd_gold_deep", 0.55))
	title.add_theme_constant_override(&"outline_size", 2)
	var blurb := _hd_label("Blurb", _title_text("blurb"), HdTheme.font("serif"), 19, "hd_text", HD_COL_W - 40.0)
	blurb.position = Vector2(HD_LEFT_X, HD_BLURB_Y)
	blurb.add_theme_constant_override(&"line_spacing", 8)
	var x := HD_LEFT_X
	for action in ACTIONS:
		var btn := Button.new()
		btn.name = str(action)
		btn.text = _title_text(str(action))
		btn.focus_mode = Control.FOCUS_ALL
		var kind := "primary" if action == &"new" else ("secondary" if action == &"continue" else "ghost")
		HdTheme.apply_button(btn, kind)
		match action:
			&"new":
				btn.custom_minimum_size = Vector2(176, 58)
				btn.add_theme_font_size_override(&"font_size", 26)
				btn.add_theme_font_override(&"font", HdTheme.font("title", 8))
			&"continue":
				btn.custom_minimum_size = Vector2(150, 48)
				btn.add_theme_font_size_override(&"font_size", 18)
			_:
				btn.custom_minimum_size = Vector2(76, 40)
		if action == &"new":
			btn.disabled = not bool(_campaign.get("available", true))
			btn.tooltip_text = str(_campaign.get("reason", ""))
		if action == &"continue":
			btn.disabled = not CardSave.exists(CardSave.suspend_path())
		var act: StringName = action
		if action == &"new":
			btn.pressed.connect(_on_new)
		else:
			btn.pressed.connect(func() -> void: chose.emit(act))
		add_child(btn)
		btn.reset_size()
		btn.position = Vector2(x, HD_BTN_Y + floorf((58.0 - btn.size.y) * 0.5))
		x += btn.size.x + (18.0 if action == &"new" else 10.0)
		_buttons.append(btn)
	if bool(_campaign.get("show_chapters", false)):
		var chapters := Button.new()
		chapters.name = "Chapters"
		chapters.text = Data.text("campaign_title.chapters")
		HdTheme.apply_button(chapters, "secondary")
		chapters.position = Vector2(HD_LEFT_X, 606)
		chapters.custom_minimum_size = Vector2(136, 40)
		chapters.pressed.connect(_open_chapters)
		add_child(chapters)
		_buttons.append(chapters)
	for i in _buttons.size():
		_buttons[i].focus_entered.connect(_on_focus.bind(i))
	_wire_neighbours()
	var hint := _hd_label("Hint", _title_text("hint"), HdTheme.font("sans"), 15, "hd_text_2", HD_COL_W)
	hint.position = Vector2(HD_LEFT_X, HD_HINT_Y)
	hint.add_theme_constant_override(&"line_spacing", 6)
	_build_campaign_details()
	_build_chapters()
	if not bool(_campaign.get("available", true)):
		show_error(str(_campaign.get("reason", "")))
	_select(0)


## 旧账盒换上玻璃面板、高清字和按钮（每次 set_rogue 父类重建盒子里的内容，这里跟着重新上样子）
func set_rogue(data: Dictionary) -> void:
	super.set_rogue(data)
	if is_node_ready():
		_dress_run_box()


func show_error(message: String, details: String = "") -> void:
	super.show_error(message, details)
	var box := get_node_or_null("Error") as Label
	if box == null:
		return
	box.position = Vector2(HD_LEFT_X, 656.0 if bool(_campaign.get("show_chapters", false)) else HD_HINT_Y + 60.0)
	box.size = Vector2(HD_COL_W, 110)
	box.add_theme_font_override(&"font", HdTheme.font("sans"))
	box.add_theme_font_size_override(&"font_size", 15)
	box.add_theme_color_override(&"font_color", HdTheme.color("hd_enemy_hi"))
	box.add_theme_color_override(&"font_outline_color", HdTheme.alpha("hd_ink", 0.9))


## “合上旧账另起一本？”那一行也换成高清样子，摆在按钮那一行
func _ask_new() -> void:
	super._ask_new()
	if _confirm == null:
		return
	_confirm.position = Vector2(HD_LEFT_X, HD_BTN_Y - 14.0)
	_confirm.add_theme_constant_override(&"separation", 14)
	var note := _confirm.get_node_or_null("Note") as Label
	if note != null:
		note.add_theme_font_override(&"font", HdTheme.font("serif"))
		note.add_theme_font_size_override(&"font_size", 17)
		note.add_theme_color_override(&"font_color", HdTheme.color("hd_gold_hi"))
		note.custom_minimum_size = Vector2(HD_COL_W - 40.0, 0)
	for b in _confirm_buttons:
		HdTheme.apply_button(b, "danger" if str(b.name) == "ConfirmYes" else "secondary")
		b.custom_minimum_size = Vector2(0, 46)


# ---------------- 旧账盒 ----------------

func _dress_run_box() -> void:
	var box := get_node_or_null("RunBox") as Control
	if box == null:
		return
	box.position = HD_BOX_RECT.position
	box.size = HD_BOX_RECT.size
	var back := box.get_node_or_null("Back") as Panel
	if back != null:
		back.size = HD_BOX_RECT.size
		back.add_theme_stylebox_override(&"panel", HdTheme.panel_box("glass"))
	var content := box.get_node_or_null("Content") as Control
	if content != null:
		content.size = HD_BOX_RECT.size
	_dress_tree(box)
	if bool(_campaign.get("explicit", false)):
		var heading := box.get_node_or_null("Content/RunNo") as Label
		if heading != null:
			heading.text = Data.text("campaign_title.archive_open" if _open_no > 0 else "campaign_title.archive", {"n": _open_no if _open_no > 0 else _run_no})
		var shelf := box.get_node_or_null("Content/ShelfLabel") as Label
		if shelf != null:
			shelf.text = Data.text("campaign_title.shelf")
	if _chapter_drawer != null:
		move_child(_chapter_drawer, -1)
	var field := box.get_node_or_null("Seed") as LineEdit
	if field != null:
		_dress_field(field)
	if box.has_method("spines"):
		for spine in box.call("spines"):
			_dress_spine(spine as Panel)


func _dress_tree(node: Node) -> void:
	for child in node.get_children():
		if child is Button:
			var b := child as Button
			var on := bool(b.get_meta("on", false))
			HdTheme.apply_button(b, "primary" if on else "secondary")
			b.add_theme_font_override(&"font", HdTheme.font("sans_bold" if on else "sans"))
			b.add_theme_font_size_override(&"font_size", 14)
			b.custom_minimum_size = Vector2(0, 32)
			b.size.y = 32
		elif child is Label:
			var l := child as Label
			var nm := str(l.name)
			var gold := nm in ["RunNo", "BookNo"]
			var size_px := 17 if nm == "RunNo" else 14
			l.add_theme_font_override(&"font", HdTheme.font("title" if nm == "RunNo" else "sans"))
			l.add_theme_font_size_override(&"font_size", size_px)
			if l.get_parent() != null and str(l.get_parent().name).begins_with("Spine"):
				continue
			l.add_theme_color_override(&"font_color", HdTheme.color("hd_gold_hi" if gold else
				("hd_gold" if nm.ends_with("Label") else "hd_text_2")))
		if not (child is LineEdit):
			_dress_tree(child)


func _dress_field(field: LineEdit) -> void:
	var normal := StyleBoxFlat.new()
	normal.anti_aliasing = true
	normal.bg_color = HdTheme.alpha("hd_ink", 0.85)
	normal.border_color = HdTheme.alpha("hd_gold", 0.55)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(6)
	normal.content_margin_left = 10
	normal.content_margin_right = 10
	var focus := normal.duplicate() as StyleBoxFlat
	focus.border_color = HdTheme.color("hd_gold_hi")
	focus.shadow_color = HdTheme.alpha("hd_gold", 0.3)
	focus.shadow_size = 8
	field.add_theme_stylebox_override(&"normal", normal)
	field.add_theme_stylebox_override(&"focus", focus)
	field.add_theme_stylebox_override(&"read_only", normal)
	field.add_theme_font_override(&"font", HdTheme.font("num"))
	field.add_theme_font_size_override(&"font_size", 16)
	field.add_theme_color_override(&"font_color", HdTheme.color("hd_text"))
	field.add_theme_color_override(&"caret_color", HdTheme.color("hd_gold_hi"))
	field.add_theme_color_override(&"selection_color", HdTheme.alpha("hd_gold", 0.35))


## 书脊：结局金、牢狱红、其余深蓝金边
func _dress_spine(p: Panel) -> void:
	if p == null:
		return
	var reason := str(p.get_meta("reason", ""))
	var fill := "hd_gold" if reason == "ending" else ("hd_wax" if reason == "prison" else "hd_navy_3")
	var sb := StyleBoxFlat.new()
	sb.anti_aliasing = true
	sb.bg_color = HdTheme.color(fill)
	sb.border_color = HdTheme.alpha("hd_gold_hi", 0.6)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(3)
	p.add_theme_stylebox_override(&"panel", sb)
	for child in p.get_children():
		if child is ColorRect:
			(child as ColorRect).color = HdTheme.alpha("hd_gold_hi" if reason != "ending" else "hd_ink", 0.35)
		elif child is Label:
			(child as Label).add_theme_color_override(&"font_color", HdTheme.color("hd_ink" if reason == "ending" else "hd_text"))
			(child as Label).add_theme_font_override(&"font", HdTheme.font("sans"))
			(child as Label).add_theme_font_size_override(&"font_size", 13)


# ---------------- Campaign identity and chapter drawer ----------------

func _title_text(key: String) -> String:
	if not bool(_campaign.get("explicit", false)):
		return Data.text("title_hint") if key == "hint" else CardText.ui("c16.title." + key)
	if key == "name":
		return str(_campaign.get("raw", {}).get("title", {}).get("name", Data.text("campaign_title.name")))
	if key == "tagline":
		return str(_campaign.get("raw", {}).get("title", {}).get("sub", Data.text("campaign_title.tagline")))
	return Data.text("campaign_title." + key)


func _build_campaign_details() -> void:
	if bool(_campaign.get("debug", false)):
		var debug := _hd_label("DebugBook", Data.text("campaign_title.debug", {"name": _title_text("name")}), HdTheme.font("sans"), 14, "hd_gold")
		debug.position = Vector2(HD_LEFT_X, 116)
	var saved: Dictionary = _campaign.get("info", {}).get("suspend", {})
	if not saved.is_empty():
		var line := _hd_label("ContinueInfo", Data.text("campaign_title.continue_line", {
			"segment": Data.text("campaign_title.branch_name." + str(saved.get("segment", "ocean"))),
			"chapter": int(saved.get("stage", 0)) + 1, "day": int(saved.get("abs_day", 0))}), HdTheme.font("sans"), 13, "hd_text_2", HD_COL_W)
		line.position = Vector2(HD_LEFT_X, 508)
	for i in 3:
		var seg: String = ["conquest", "ocean", "cristo"][i]
		var progress := Campaigns.collection(_campaign, seg)
		var key := "campaign_title.collection" if int(progress["total"]) > 0 else "campaign_title.collection_pending"
		var label := _hd_label("Branch_" + seg, Data.text(key, {"name": Data.text("campaign_title.branch_name." + seg),
			"n": progress["n"], "total": progress["total"]}), HdTheme.font("sans"), 15,
			"hd_gold_hi" if bool(progress["visited"]) else "hd_text_2")
		label.modulate.a = 1.0 if bool(progress["visited"]) else 0.45
		label.position = Vector2(790 + i * 126, 402)
		label.set_meta("visited", progress["visited"])


func _build_chapters() -> void:
	if not bool(_campaign.get("show_chapters", false)):
		return
	_chapter_drawer = PanelContainer.new()
	_chapter_drawer.name = "ChapterDrawer"
	_chapter_drawer.position = Vector2(576, 72)
	_chapter_drawer.size = Vector2(632, 576)
	_chapter_drawer.add_theme_stylebox_override(&"panel", HdTheme.panel_box("glass"))
	_chapter_drawer.visible = false
	add_child(_chapter_drawer)
	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 12)
	_chapter_drawer.add_child(column)
	column.add_child(HdTheme.make_label(Data.text("campaign_title.drawer_title"), 28, "title", "hd_gold_hi"))
	var hint := HdTheme.make_label(Data.text("campaign_title.drawer_debug" if bool(_campaign.get("debug", false)) else "campaign_title.drawer_hint"), 15, "sans", "hd_text_2")
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(hint)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(584, 398)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	var rows := VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override(&"separation", 8)
	scroll.add_child(rows)
	for choice in chapter_choices():
		var button := Button.new()
		button.name = "Chapter_" + str(choice["segment"]) + "_" + str(choice["stage"])
		button.text = str(choice["title"])
		button.disabled = not bool(choice["enabled"])
		button.tooltip_text = str(choice["reason"]) if not str(choice["reason"]).is_empty() else (Data.text("campaign_title.branch_tip") if str(choice.get("action", "")) == "branch" else "")
		button.set_meta("segment", choice["segment"])
		button.set_meta("stage", choice["stage"])
		HdTheme.apply_button(button, "secondary")
		button.custom_minimum_size.y = 44
		button.pressed.connect(_select_chapter.bind(choice))
		rows.add_child(button)
		_chapter_buttons.append(button)
		if not str(choice["reason"]).is_empty():
			var reason := HdTheme.make_label(str(choice["reason"]), 13, "sans", "hd_text_2")
			reason.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			rows.add_child(reason)
	var close := Button.new()
	close.name = "CloseChapters"
	close.text = Data.text("campaign_title.close")
	HdTheme.apply_button(close, "ghost")
	close.pressed.connect(_close_chapters)
	column.add_child(close)
	_chapter_buttons.append(close)


func _open_chapters() -> void:
	if _chapter_drawer == null or _confirm != null:
		return
	move_child(_chapter_drawer, -1)
	_chapter_drawer.show()
	_chapter_index = -1
	_move_chapter(1)


func _close_chapters() -> void:
	if _chapter_drawer != null:
		_chapter_drawer.hide()
	_select(_buttons.size() - 1)


func _select_chapter(choice: Dictionary) -> void:
	if not bool(choice.get("enabled", false)):
		return
	_close_chapters()
	if str(choice.get("action", "")) == "branch":
		chose.emit(&"branch")
		return
	_selected_options = choice.get("options", {}).duplicate(true)
	if bool(choice.get("reseed", false)):
		chose.emit(&"reseed")
	var new_button := get_node_or_null("new") as Button
	if new_button != null:
		new_button.disabled = false
		new_button.tooltip_text = ""
	var hint := get_node_or_null("Hint") as Label
	if hint != null:
		hint.text = Data.text("campaign_title.selected", {"name": choice["title"]})
	var error := get_node_or_null("Error") as Label
	if error != null:
		error.hide()
	_wire_neighbours()
	_select(0)


func _move_chapter(direction: int) -> void:
	var focused := _chapter_buttons.find(get_viewport().gui_get_focus_owner())
	if focused >= 0:
		_chapter_index = focused
	for _hop in _chapter_buttons.size():
		_chapter_index = wrapi(_chapter_index + direction, 0, _chapter_buttons.size())
		if not _chapter_buttons[_chapter_index].disabled:
			_chapter_buttons[_chapter_index].grab_focus()
			return


func _handle_key(event: InputEvent) -> bool:
	if _chapter_drawer == null or not _chapter_drawer.visible:
		return super._handle_key(event)
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return false
	match event.keycode:
		KEY_ESCAPE:
			_close_chapters()
		KEY_UP, KEY_W, KEY_LEFT, KEY_A:
			_move_chapter(-1)
		KEY_DOWN, KEY_S, KEY_RIGHT, KEY_D, KEY_TAB:
			_move_chapter(1)
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			var focused := get_viewport().gui_get_focus_owner() as Button
			if focused in _chapter_buttons and not focused.disabled:
				focused.pressed.emit()
		_:
			return false
	return true


func _on_new() -> void:
	var button := get_node_or_null("new") as Button
	if button != null and button.disabled:
		return
	_close_chapters()
	super._on_new()


# ---------------- 小件 ----------------

## width > 0：按这个宽度换行（进树前设好，免得先排成一长行）
func _hd_label(node_name: String, text: String, font: Font, font_size: int, color_key: String, width: float = 0.0) -> Label:
	var l := HdTheme.make_label(text, font_size, "sans", color_key)
	l.name = node_name
	l.add_theme_font_override(&"font", font)
	if width > 0.0:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(width, 0)
	add_child(l)
	if width > 0.0:
		l.size = Vector2(width, 0)
	return l


## 左边的深蓝压暗（从左往右渐隐），字压在背景上也清楚
func _wash() -> TextureRect:
	var grad := Gradient.new()
	grad.set_color(0, HdTheme.alpha("hd_ink", 0.9))
	grad.set_color(1, HdTheme.alpha("hd_ink", 0.0))
	grad.add_point(0.42, HdTheme.alpha("hd_ink", 0.66))
	grad.add_point(0.62, HdTheme.alpha("hd_ink", 0.22))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill_from = Vector2(0, 0)
	tex.fill_to = Vector2(1, 0)
	tex.width = 512
	tex.height = 4
	var rect := TextureRect.new()
	rect.name = "Wash"
	rect.texture = tex
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return rect


## 题签下的一道金线：左端一个菱形，向右渐隐
class Rule extends Control:
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var y := size.y * 0.5
		var c := HdTheme.alpha("hd_gold", 0.8)
		var clear := c
		clear.a = 0.0
		draw_polyline_colors(PackedVector2Array([Vector2(14, y), Vector2(size.x, y)]), PackedColorArray([c, clear]), 1.0, true)
		D.diamond(self, Vector2(5, y), 4.0, HdTheme.color("hd_gold_hi"))
