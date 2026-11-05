# 远洋战役的高清“信物”和“档案”（营地顶栏的两个按钮）：原来是像素右 / 左抽屉，远洋战役里换成满屏叠层。
#   relics：这一场的背景压暗，中间一份文书——圆章、小标题“航程信物”、标题（已收存几件 / 共几件）、金线，
#           下面两列物件卡（圆章、名字、说明、第几日收存）；一件没有时写空着的说明和“航海札记”。
#   dossier：左边人物格子（头像圆章 + 名字，四列，可滚动），右边选中那个人的档案：立绘（有 art/hd/chara 用真图，
#           没有画剪影占位）、名字、身份、正文。点格子换人。
# 只读 engine.query(relics / dossier)，不发指令；Esc / “收起”关。字：物件和人物来自 CardText（远洋覆盖层），
# 界面字在 data/hd/hub_ui.json 的 relics.* / dossier.*，计数行沿用 rg4.relics.*。宿主按 modal_host.overrides 换上它，
# kind 仍是 relics / dossier。没有 class_name。
extends CardPanel

const HdTheme = preload("res://scripts/cards/ui/hd/hd_theme.gd")
const HdPlaceholder = preload("res://scripts/cards/ui/hd/hd_placeholder.gd")
const Data = preload("res://scripts/cards/ui/hub/hub_data.gd")
const Kit = preload("res://scripts/cards/ui/hub/hub_kit.gd")
const Deco = preload("res://scripts/cards/ui/vn/vn_deco.gd")
const W = preload("res://scripts/cards/ui/battle/hud/hud_widgets.gd")

const DOC := Rect2(190, 48, 900, 572)
const DOC_EMPTY := Rect2(290, 170, 700, 300)
const ITEM := Vector2(410, 112)
const INDEX := Rect2(40, 48, 520, 600)
const PAGE := Rect2(576, 48, 664, 600)
const TILE := Vector2(112, 128)
const TILE_COLS := 4
const ART := Vector2(268, 402)

## 宿主按登记的 kind 设（relics / dossier）
var kind: StringName = &"relics"
var fast := false

var _closed := false
var _people: Array = []
var _person := ""
var _tiles: Dictionary = {}
var _page: Control = null
var _close_btn: Button = null


func open(_args: Dictionary) -> void:
	_closed = false
	var host := get_parent()
	if host != null and "fast" in host:
		fast = fast or bool(host.get("fast"))
	size = Vector2(1280, 720)
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	HdTheme.apply_hd_filter(self)
	_backdrop()
	if kind == &"dossier":
		_build_dossier()
	else:
		_build_relics()
	if not fast:
		modulate.a = 0.0
		create_tween().tween_property(self, "modulate:a", 1.0, 0.2)


func refresh(_view: Dictionary) -> void:
	pass


func dismiss() -> void:
	_close()


func autoplay_step() -> bool:
	if _closed:
		return false
	_close()
	return true


## 档案：现在选中的人（测试用）
func person() -> String:
	return _person


## 档案：人物格子（person id -> 按钮）
func tiles() -> Dictionary:
	return _tiles


func _close() -> void:
	if _closed:
		return
	_closed = true
	close_requested.emit({})


func _unhandled_input(event: InputEvent) -> void:
	if _closed or not (event is InputEventKey) or not (event as InputEventKey).pressed or (event as InputEventKey).echo:
		return
	var key := (event as InputEventKey).keycode
	if key in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
		_close()
	elif kind == &"dossier" and key in [KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN, KEY_A, KEY_D, KEY_W, KEY_S]:
		_step_person(-1 if key in [KEY_LEFT, KEY_UP, KEY_A, KEY_W] else 1)
	else:
		return
	var vp := get_viewport()
	if vp != null:
		vp.set_input_as_handled()


# ================================================================ 背景

func _backdrop() -> void:
	var base := ColorRect.new()
	base.color = HdTheme.color("hd_ink")
	base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	base.size = size
	add_child(base)
	var c: Dictionary = engine.query(&"campaign") if engine != null else {}
	var spec := Data.scene_bg(str(c.get("scene_id", ""))) if typeof(c) == TYPE_DICTIONARY else {}
	var bg_id := "camp_tent" if kind == &"dossier" else str(spec.get("id", "camp_tent"))
	if bg_id == "":
		bg_id = "camp_tent"
	var bg := HdPlaceholder.make_bg(bg_id, "", "", "" if kind == &"dossier" else str(spec.get("variant", "")))
	bg.name = "Bg_" + bg_id
	if HdPlaceholder.is_placeholder(bg):
		bg.set("title_alpha", 0.0)
	add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := Deco.new().setup("dim")
	dim.size = size
	add_child(dim)


func _panel(rect: Rect2, node_name: String) -> PanelContainer:
	var p := PanelContainer.new()
	p.name = node_name
	p.mouse_filter = Control.MOUSE_FILTER_PASS
	var box := HdTheme.panel_box("glass_strong")
	box.content_margin_left = 28
	box.content_margin_right = 24
	box.content_margin_top = 22
	box.content_margin_bottom = 20
	p.add_theme_stylebox_override(&"panel", box)
	p.position = rect.position
	p.size = rect.size
	p.custom_minimum_size = rect.size
	add_child(p)
	return p


## 圆章 + 小标题 + 标题（标题可以换行），下面一道金线
func _head(col: VBoxContainer, medal_id: String, glyph: String, kicker: String, title: String, title_w: float) -> Label:
	var head := HBoxContainer.new()
	head.add_theme_constant_override(&"separation", 16)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(head)
	head.add_child(Kit.medal(medal_id, glyph, 58))
	var titles := VBoxContainer.new()
	titles.add_theme_constant_override(&"separation", 2)
	titles.alignment = BoxContainer.ALIGNMENT_CENTER
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(titles)
	var k := Kit.label(kicker, 13, "sans_bold", "hd_gold")
	k.name = "Kicker"
	k.add_theme_font_override(&"font", HdTheme.font("sans_bold", 3))
	titles.add_child(k)
	var t := Kit.wrap(title, 26, "title", "hd_text")
	t.name = "Title"
	t.custom_minimum_size = Vector2(title_w, 0)
	titles.add_child(t)
	var rule := W.Rule.new()
	rule.custom_minimum_size = Vector2(0, 10)
	col.add_child(rule)
	return t


func _close_button(at: Vector2, w: float, key: String) -> void:
	var row := HBoxContainer.new()
	row.name = "Tail"
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.position = at
	row.size = Vector2(w, 44)
	add_child(row)
	_close_btn = Button.new()
	_close_btn.name = "BtnClose"
	_close_btn.text = Data.text(key)
	HdTheme.apply_button(_close_btn, "secondary")
	_close_btn.custom_minimum_size = Vector2(180, 42)
	_close_btn.focus_mode = Control.FOCUS_NONE
	_close_btn.pressed.connect(_close)
	row.add_child(_close_btn)


# ================================================================ 信物

func _build_relics() -> void:
	var r: Dictionary = engine.query(&"relics") if engine != null else {}
	if typeof(r) != TYPE_DICTIONARY:
		r = {}
	var held: Array = r.get("held", []) if typeof(r.get("held")) == TYPE_ARRAY else []
	# 一件都没有时文书收小一点、放在正中（不留一大片空框）
	var rect := DOC if not held.is_empty() else DOC_EMPTY
	var doc := _panel(rect, "Doc")
	var col := VBoxContainer.new()
	col.add_theme_constant_override(&"separation", 10)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	doc.add_child(col)
	_head(col, "hub_relics", Data.text("relics.icon"), Data.text("relics.kicker"),
		CardText.ui("rg4.relics.count", {"n": held.size(), "cap": int(r.get("cap", held.size()))}), rect.size.x - 160)
	var scroll := ScrollContainer.new()
	scroll.name = "Items"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	col.add_child(scroll)
	if held.is_empty():
		var box := VBoxContainer.new()
		box.add_theme_constant_override(&"separation", 14)
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.add_child(box)
		var empty_text := Data.text("relics.empty")
		var empty := Kit.wrap(empty_text if empty_text != "" else CardText.ui("rg4.relics.empty"), 18, "serif", "hd_text")
		empty.name = "Empty"
		empty.custom_minimum_size = Vector2(rect.size.x - 80, 0)
		empty.add_theme_constant_override(&"line_spacing", 6)
		box.add_child(empty)
		var notes := Kit.label(Data.text("relics.notes"), 17, "title", "hd_gold_hi")
		box.add_child(notes)
		var line := Kit.wrap(CardText.ui("rg4.relics.sources_empty"), 16, "serif", "hd_text_2")
		line.custom_minimum_size = Vector2(rect.size.x - 80, 0)
		box.add_child(line)
	else:
		var grid := GridContainer.new()
		grid.name = "Grid"
		grid.columns = 2
		grid.add_theme_constant_override(&"h_separation", 14)
		grid.add_theme_constant_override(&"v_separation", 12)
		grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
		scroll.add_child(grid)
		for row in held:
			if typeof(row) == TYPE_DICTIONARY:
				grid.add_child(_item_card(row))
	_close_button(Vector2(rect.position.x, rect.end.y + 14), rect.size.x, "relics.close")


func _item_card(row: Dictionary) -> Control:
	var def := str(row.get("id", ""))
	var title := CardText.card(def, "title")
	var card := PanelContainer.new()
	card.name = "Item_" + def.get_slice(".", def.get_slice_count(".") - 1)
	card.custom_minimum_size = ITEM
	card.mouse_filter = Control.MOUSE_FILTER_PASS
	card.tooltip_text = Data.unpage(CardText.card(def, "body"))
	var sb := HdTheme.panel_box("card")
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 12
	sb.content_margin_bottom = 10
	card.add_theme_stylebox_override(&"panel", sb)
	var h := HBoxContainer.new()
	h.add_theme_constant_override(&"separation", 14)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(h)
	var m := Kit.medal("item_" + def, title.left(1), 50)
	m.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	h.add_child(m)
	var v := VBoxContainer.new()
	v.add_theme_constant_override(&"separation", 3)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(v)
	var name_l := Kit.label(title, 18, "title", "hd_gold_hi")
	name_l.name = "Name"
	name_l.clip_text = true
	name_l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_l.custom_minimum_size = Vector2(ITEM.x - 110, 0)
	v.add_child(name_l)
	var body := Kit.wrap(Data.unpage(CardText.card(def, "body")), 14, "serif", "hd_text_2")
	body.name = "Body"
	body.max_lines_visible = 2
	body.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	body.custom_minimum_size = Vector2(ITEM.x - 110, 0)
	v.add_child(body)
	var since := int(row.get("since", 0))
	if since > 0:
		v.add_child(Kit.label(Data.text("relics.since", {"d": since}), 12, "sans", "hd_text_3"))
	return card


# ================================================================ 档案

func _build_dossier() -> void:
	_people = []
	var d: Dictionary = engine.query(&"dossier") if engine != null else {}
	if typeof(d) == TYPE_DICTIONARY:
		for p in d.get("pages", []):
			if typeof(p) == TYPE_DICTIONARY and str(p.get("person", "")) != "":
				_people.append(str(p["person"]))
	var index := _panel(INDEX, "Index")
	var col := VBoxContainer.new()
	col.add_theme_constant_override(&"separation", 10)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	index.add_child(col)
	_head(col, "hub_dossier", Data.text("dossier.icon"), Data.text("dossier.kicker"),
		Data.text("dossier.count", {"n": _people.size()}), INDEX.size.x - 150)
	var scroll := ScrollContainer.new()
	scroll.name = "People"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	col.add_child(scroll)
	var grid := GridContainer.new()
	grid.name = "Grid"
	grid.columns = TILE_COLS
	grid.add_theme_constant_override(&"h_separation", 8)
	grid.add_theme_constant_override(&"v_separation", 8)
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scroll.add_child(grid)
	_tiles = {}
	for who in _people:
		var b := _tile(str(who))
		grid.add_child(b)
		_tiles[str(who)] = b
	if _people.is_empty():
		var empty := Kit.wrap(Data.text("dossier.empty"), 17, "serif", "hd_text_2")
		empty.custom_minimum_size = Vector2(INDEX.size.x - 60, 0)
		grid.add_child(empty)
	_page = _panel(PAGE, "Page")
	_close_button(Vector2(PAGE.end.x - 200, PAGE.end.y + 14), 200, "dossier.close")
	_show_person(str(_people[0]) if not _people.is_empty() else "")


func _tile(who: String) -> Button:
	var b := Kit.card_button("Tile_" + who, "plain")
	b.custom_minimum_size = TILE
	b.focus_mode = Control.FOCUS_NONE
	b.tooltip_text = CardText.person_name(who)
	var v := VBoxContainer.new()
	v.add_theme_constant_override(&"separation", 6)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	b.add_child(v)
	var face := HdPlaceholder.make_face(who, CardText.person_name(who))
	face.custom_minimum_size = Vector2(68, 68)
	face.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(face)
	var n := Kit.label(CardText.person_name(who), 14, "sans", "hd_text")
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	n.clip_text = true
	n.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	n.custom_minimum_size = Vector2(TILE.x - 12, 0)
	v.add_child(n)
	b.pressed.connect(_show_person.bind(who))
	return b


func _show_person(who: String) -> void:
	_person = who
	for id in _tiles:
		var on := str(id) == who
		var tile: Button = _tiles[id]
		var spec: Dictionary = Kit.CARD_SPECS["gold" if on else "plain"]
		tile.add_theme_stylebox_override(&"normal", HdTheme.box(spec["normal"] if not on else spec["hover"]))
	Kit.clear(_page)
	if who == "":
		return
	var h := HBoxContainer.new()
	h.add_theme_constant_override(&"separation", 22)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_page.add_child(h)
	var art_slot := Control.new()
	art_slot.custom_minimum_size = ART
	art_slot.clip_contents = true
	art_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(art_slot)
	var art := HdPlaceholder.make_chara(who, CardText.person_name(who))
	art_slot.add_child(art)
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var v := VBoxContainer.new()
	v.add_theme_constant_override(&"separation", 8)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(v)
	var k := Kit.label(Data.text("dossier.kicker"), 13, "sans_bold", "hd_gold")
	k.add_theme_font_override(&"font", HdTheme.font("sans_bold", 3))
	v.add_child(k)
	var name_l := Kit.wrap(CardText.person_name(who), 30, "title", "hd_gold_hi")
	name_l.name = "Name"
	v.add_child(name_l)
	var rule := W.Rule.new()
	rule.custom_minimum_size = Vector2(0, 10)
	v.add_child(rule)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(PAGE.size.x - ART.x - 96, 0)
	scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	v.add_child(scroll)
	var body := Kit.wrap(Data.unpage(CardText.card("ocean.person." + who, "body")), 17, "serif", "hd_text")
	body.name = "Body"
	body.custom_minimum_size = Vector2(PAGE.size.x - ART.x - 110, 0)
	body.add_theme_constant_override(&"line_spacing", 7)
	scroll.add_child(body)


func _step_person(dir: int) -> void:
	if _people.is_empty():
		return
	var i := _people.find(_person)
	i = (i + dir + _people.size()) % _people.size()
	_show_person(str(_people[i]))
