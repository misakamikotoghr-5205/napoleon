# 档案簿：人名索引、每人一页、缺口画成撕痕、一年后年份签、补齐盖章、新碎片红点；规矩栏按 firsts 解锁。
# 主人 C10。Esc 关、左右与滚轮翻页、Tab 切栏目。F1 不在这里处理。文字走 CardText，颜色走 CardTheme。
# 合同：docs/cards/CARDS_INTERFACES.md §3.3 C10、§7.5、§7.8、§7.10.5、§7.11.8。锚点 a.dossier.page / gap / rules_tab。
# 换皮（10-22，原型 33_drawer_dossier；b21）：是左抽屉（drawer_l），就摆在左抽屉框里那块 368x630，不再是满屏居中的大本子。
# 顶上“人物 / 规矩”两栏（当前栏金底深字，b49）；人物栏：一句说明、人名格子（头像上半截 + 名字，选中金边）、
# 下面一张纸片是这个人的那一页（毛笔标题、碎片一条条往下、缺口是撕痕、补齐盖章），页长了能滚。
# 肉鸽 v1 旧墨（RG5，ROGUE_V1.md §7.6）：问完 dossier 再问 legacy.old_ink，以前各本账见过、这一本还没有的碎片
# 并进同一个人的页（state "old"，照 have 的画法、整行压淡、右上一个小印、页底一句说明）；只有旧墨的人另加一页，
# 索引格子名字压暗。淡墨不算数：补齐和条件只认这一本拿到的（引擎本来就只看 have）。查询没有（Mock）就当没有。
class_name CardDossierBook
extends CardPanel

const RulesView = preload("res://scripts/cards/ui/dossier/rules_view.gd")
const TearEdge = preload("res://scripts/cards/ui/dossier/tear_edge.gd")
const SealMark = preload("res://scripts/cards/ui/dossier/seal_mark.gd")
const Kit = preload("res://scripts/cards/ui/slots/drawer_kit.gd")
const SIDE := "l"
const TABS_Y := 8.0
const BODY_Y := 52.0
const TILE := Vector2(84, 74)
const TILE_COLS := 4
const PAGE_PAD := Vector2(14, 12)
const Q_OLD_INK := &"legacy.old_ink"
const OLD := "old"
const OLD_ALPHA := 0.6
## Old-ink rows leave this much room at the right for their stamp.
const OLD_STAMP_W := 52.0

var _args: Dictionary = {}
var _built: bool = false
var _did_auto: bool = false
var _chose: bool = false
var _tab: String = "people"
var _person: String = ""
var _people: Array = []
var _by_id: Dictionary = {}
var _people_box: VBoxContainer
var _index_scroll: ScrollContainer
var _index: GridContainer
var _card: PanelContainer
var _page_scroll: ScrollContainer
var _page: Control
var _empty: Label
var _rules = null
var _tab_people: Button
var _tab_rules: Button


func open(args: Dictionary) -> void:
	_args = args.duplicate(true)
	if str(_args.get("tab", "")) == "rules":
		_tab = "rules"
	_ensure()
	_listen()
	if not _chose:
		_chose = true
		var want := str(_args.get("person", ""))
		if want != "":
			_person = want
	_reload()


func refresh(_view: Dictionary) -> void:
	if not _built:
		return
	_reload()


func autoplay_step() -> bool:
	if _did_auto:
		return false
	_did_auto = true
	close_requested.emit({})
	return true


func _ensure() -> void:
	if _built:
		return
	_built = true
	Kit.place(self, SIDE)
	set_process_input(true)
	var w := size.x
	_tab_people = _tab_button("c10.tab.people", "people", 0.0)
	_tab_rules = _tab_button("c10.tab.rules", "rules", 96.0)
	CardAnchors.register(&"a.dossier.rules_tab", _tab_rules)
	_people_box = Kit.column(8)
	_people_box.name = "People"
	_people_box.position = Vector2(0, BODY_Y)
	_people_box.size = Vector2(w, size.y - BODY_Y)
	add_child(_people_box)
	var note := Kit.note(CardText.ui("c10.drawer.note"))
	note.name = "Intro"
	note.custom_minimum_size = Vector2(w, 22)
	_people_box.add_child(note)
	_index_scroll = Kit.scroll()
	_index_scroll.name = "IndexScroll"
	_index_scroll.custom_minimum_size = Vector2(w, TILE.y)
	_people_box.add_child(_index_scroll)
	_index = GridContainer.new()
	_index.name = "Index"
	_index.columns = TILE_COLS
	_index.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_index.add_theme_constant_override("h_separation", 6)
	_index.add_theme_constant_override("v_separation", 6)
	_index_scroll.add_child(_index)
	_empty = Kit.label(CardText.ui("c10.drawer.empty"), 14, &"text_3", false, true)
	_empty.name = "EmptyNote"
	_empty.visible = false
	_people_box.add_child(_empty)
	_card = Kit.box(CardTheme.paper_card_style())
	_card.name = "PageCard"
	_card.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_people_box.add_child(_card)
	_page_scroll = Kit.scroll()
	_page_scroll.name = "PageScroll"
	_card.add_child(_page_scroll)
	_page = Control.new()
	_page.name = "Page"
	_page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_page_scroll.add_child(_page)
	CardAnchors.register(&"a.dossier.page", _page)
	_rules = RulesView.new()
	_rules.name = "Rules"
	_rules.position = Vector2(0, BODY_Y)
	_rules.size = Vector2(w, size.y - BODY_Y)
	add_child(_rules)
	_rules.setup(engine)
	_rules.visible = false


func _listen() -> void:
	if bus == null:
		return
	if not bus.view_changed.is_connected(_on_view):
		bus.view_changed.connect(_on_view)
	if not bus.dossier_changed.is_connected(_on_dossier):
		bus.dossier_changed.connect(_on_dossier)


func _on_view(_topics: PackedStringArray) -> void:
	if _built:
		_reload()


func _on_dossier(_person: String, _frag_id: String, _kind: StringName) -> void:
	if _built:
		_reload()


func _reload() -> void:
	_read_pages()
	if _people.is_empty():
		_person = ""
	elif not _people.has(_person):
		_person = str(_people[0])
	_fill_index()
	_fill_page()
	_apply_tab()


func _read_pages() -> void:
	_people = []
	_by_id = {}
	if engine == null:
		return
	var d: Dictionary = engine.query(&"dossier", {})
	var raw: Array = d.get("pages", []) if typeof(d.get("pages")) == TYPE_ARRAY else []
	for p in raw:
		if typeof(p) != TYPE_DICTIONARY:
			continue
		var person := str(p.get("person", ""))
		if person == "":
			continue
		_people.append(person)
		_by_id[person] = p
	_merge_old_ink()


## Rogue v1 old ink: earlier ledgers' fragments join the same person's page as state "old" (an id already on the
## page is skipped); a person known only from old ink gets a page of its own (old_only), appended after the rest.
func _merge_old_ink() -> void:
	var ink: Dictionary = engine.query(Q_OLD_INK, {})
	if not bool(ink.get("ok", false)) or typeof(ink.get("pages")) != TYPE_ARRAY:
		return
	for p in ink["pages"]:
		if typeof(p) != TYPE_DICTIONARY or str(p.get("person", "")) == "":
			continue
		var person := str(p.get("person", ""))
		if not _by_id.has(person):
			_people.append(person)
			_by_id[person] = {"person": person, "complete": false, "new": 0, "fragments": [], "old_only": true}
		var page: Dictionary = (_by_id[person] as Dictionary).duplicate(true)
		var frags: Array = page.get("fragments", []) if typeof(page.get("fragments")) == TYPE_ARRAY else []
		var have: Dictionary = {}
		for f in frags:
			if typeof(f) == TYPE_DICTIONARY:
				have[str(f.get("id", ""))] = true
		for f in p.get("fragments", []):
			if typeof(f) != TYPE_DICTIONARY or str(f.get("id", "")) == "" or have.has(str(f.get("id", ""))):
				continue
			have[str(f["id"])] = true
			frags.append({"id": str(f["id"]), "order": int(f.get("order", 0)), "state": OLD, "new": false})
		page["fragments"] = frags
		_by_id[person] = page


## 人名格子：头像上半截（原大）+ 名字；选中那格金边深底；有新碎片右上一个红点。
func _fill_index() -> void:
	_wipe(_index)
	for person in _people:
		var who := str(person)
		var b := Button.new()
		b.custom_minimum_size = TILE
		b.focus_mode = Control.FOCUS_NONE
		b.clip_text = true
		b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		b.text = CardText.person_name(who)
		b.icon = _face(who)
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		b.mouse_filter = Control.MOUSE_FILTER_PASS
		b.add_theme_font_override("font", CardTheme.font_body())
		b.add_theme_font_size_override("font_size", 14)
		b.set_meta(&"c10_person", who)
		_paint_tile(b, who == _person)
		if bool((_by_id[person] as Dictionary).get("old_only", false)):
			b.set_meta(&"rg5_old_only", "1")
			for c in [&"font_color", &"font_focus_color", &"font_hover_color", &"font_pressed_color", &"font_hover_pressed_color"]:
				b.add_theme_color_override(c, CardTheme.color(&"text_3"))
		b.pressed.connect(_choose_person.bind(who))
		_index.add_child(b)
		if _page_has_new(_by_id[person]):
			var dot := _dot()
			dot.position = Vector2(TILE.x - 14.0, 4)
			b.add_child(dot)
	var rows := ceili(float(_people.size()) / float(TILE_COLS))
	var shown := clampi(rows, 1, 2)
	var tile_h := TILE.y
	if _index.get_child_count() > 0:
		tile_h = maxf(tile_h, (_index.get_child(0) as Control).get_combined_minimum_size().y)
	_index_scroll.custom_minimum_size = Vector2(size.x, shown * tile_h + (shown - 1) * 6.0)
	_index_scroll.visible = not _people.is_empty()
	_empty.visible = _people.is_empty()
	_card.visible = not _people.is_empty()


func _paint_tile(b: Button, on: bool) -> void:
	var normal := CardTheme.flat_style(&"wood_1", &"gold_hi" if on else &"line", 2 if on else 1, 4, 4.0, 6.0)
	if on:
		normal.bg_color = CardTheme.color(&"wood_2")
	var hover := CardTheme.flat_style(&"wood_2", &"gold_deep", 1, 4, 4.0, 6.0)
	if on:
		hover = normal
	for s in [&"normal", &"focus", &"disabled"]:
		b.add_theme_stylebox_override(s, normal)
	for s in [&"hover", &"pressed", &"hover_pressed"]:
		b.add_theme_stylebox_override(s, hover)
	var ink := CardTheme.color(&"gold_pale" if on else &"hud_ink")
	for c in [&"font_color", &"font_focus_color", &"font_hover_color", &"font_pressed_color", &"font_hover_pressed_color"]:
		b.add_theme_color_override(c, ink)


func _face(person: String) -> Texture2D:
	var art := "portrait." + person
	var tex := CardArt.texture(art)
	if tex == null or CardArt.is_missing(art):
		return null
	var base := CardArt.base_size(art)
	if base == Vector2i.ZERO:
		base = Vector2i(tex.get_width(), tex.get_height())
	var at := AtlasTexture.new()
	at.atlas = tex
	var side := mini(36, mini(base.x, base.y))
	at.region = Rect2(float(base.x - side) * 0.5, 0.0, side, side)
	return at


func _choose_person(person: String) -> void:
	_person = person
	_tab = "people"
	_fill_index()
	_fill_page()
	_apply_tab()


## 一页：毛笔标题（印泥暗红），补齐了右上角盖章；碎片按 order 往下排，拿到的写正文和来路，缺的画撕痕。
func _fill_page() -> void:
	_wipe(_page)
	CardAnchors.register(&"a.dossier.page", _page)
	_page.set_meta(&"c10_show", _person)
	var w := maxf(200.0, size.x - PAGE_PAD.x * 2.0 - 12.0)
	if _person == "" or not _by_id.has(_person):
		_page.custom_minimum_size = Vector2(w, 120)
		return
	var page: Dictionary = _by_id[_person]
	var title := _page_title(_person)
	var title_l := _label(title, 24, CardText.is_draft("dp." + _person + "#title"))
	title_l.position = Vector2(0, 0)
	title_l.size = Vector2(w - 48.0, 34)
	_page.add_child(title_l)
	if bool(page.get("complete", false)):
		var seal = SealMark.new()
		seal.position = Vector2(w - 44.0, 0)
		seal.size = Vector2(40, 40)
		seal.set_meta(&"c10_seal", "1")
		_page.add_child(seal)
	var y := 44.0
	var first_gap: Control = null
	var old_ink := false
	for frag in _sorted_frags(page):
		var row := _add_frag(frag, y, w)
		if row != null:
			_page.add_child(row)
			if first_gap == null and str(row.get_meta(&"c10_state", "")) == "gap":
				first_gap = row
			old_ink = old_ink or str(row.get_meta(&"c10_state", "")) == OLD
			y += row.size.y + 10.0
	if old_ink:
		y = _old_ink_hint(y, w)
	_page.custom_minimum_size = Vector2(w, y)
	_fit_card(y)
	if first_gap != null:
		CardAnchors.register(&"a.dossier.gap", first_gap)


## 纸片跟着这一页的长短走（原型：短页就是一小张纸），太长才在抽屉底下截住、滚动。
func _fit_card(page_h: float) -> void:
	var used := 22.0 + _index_scroll.custom_minimum_size.y + 8.0 * 2.0
	var sb := _card.get_theme_stylebox("panel")
	var pad := sb.get_margin(SIDE_TOP) + sb.get_margin(SIDE_BOTTOM) if sb != null else 16.0
	var avail := size.y - BODY_Y - used - pad - 4.0
	_page_scroll.custom_minimum_size = Vector2(0, clampf(page_h, 120.0, maxf(120.0, avail)))


func _add_frag(frag: Dictionary, y: float, w: float) -> Control:
	var state := str(frag.get("state", ""))
	if state != "have" and state != "gap" and state != OLD:
		return null
	var row := Control.new()
	row.position = Vector2(0, y)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.set_meta(&"c10_frag", str(frag.get("id", "")))
	row.set_meta(&"c10_state", state)
	if state == "gap":
		row.size = Vector2(w, 44)
		row.custom_minimum_size = row.size
		_fill_gap(row, str(frag.get("id", "")))
	else:
		_fill_have(row, frag, w - OLD_STAMP_W if state == OLD else w)
	if state == OLD:
		_mark_old(row, w)
	if bool(frag.get("new", false)):
		var dot := _dot()
		dot.position = Vector2(0, 6)
		row.add_child(dot)
	return row


## Old ink: the have drawing (its text column narrowed by the stamp), the row back to the full page width with a
## full-width rule, the whole row faded, a small stamp at the top right.
func _mark_old(row: Control, w: float) -> void:
	row.size = Vector2(w, row.size.y)
	row.custom_minimum_size = row.size
	for c in row.get_children():
		if c is ColorRect:
			(c as ColorRect).size.x = w - 16.0
	row.modulate = CardTheme.with_alpha(&"ink_soft", OLD_ALPHA)
	var stamp := _label(CardText.ui("rg5.dossier.old_ink"), 12, CardText.is_draft("rg5.dossier.old_ink"))
	stamp.add_theme_color_override("font_color", CardTheme.color(&"seal_dark"))
	stamp.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	stamp.position = Vector2(w - OLD_STAMP_W, 0.0)
	stamp.size = Vector2(OLD_STAMP_W, 18)
	stamp.set_meta(&"rg5_old_ink", "1")
	row.add_child(stamp)


## One line at the foot of a page that has old ink.
func _old_ink_hint(y: float, w: float) -> float:
	var text := CardText.ui("rg5.dossier.old_ink_hint")
	var hint := _label(text, 14, CardText.is_draft("rg5.dossier.old_ink_hint"))
	hint.add_theme_color_override("font_color", CardTheme.color(&"ink_3"))
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var h := ceilf(CardTheme.font_body().get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, w - 16.0, 14).y) + 6.0
	hint.position = Vector2(16, y)
	hint.size = Vector2(w - 16.0, h)
	hint.set_meta(&"rg5_old_ink_hint", "1")
	_page.add_child(hint)
	return y + h + 6.0


func _fill_gap(row: Control, fid: String) -> void:
	var tear = TearEdge.new()
	tear.position = Vector2.ZERO
	tear.size = row.size
	row.add_child(tear)
	tear.setup(fid)


func _fill_have(row: Control, frag: Dictionary, w: float) -> void:
	var fid := str(frag.get("id", ""))
	var text := CardText.card(fid, "body")
	var body := _label(text, 15, CardText.is_draft(fid + "#body"))
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_constant_override("line_spacing", 3)
	var bw := w - 16.0
	var bh := ceilf(CardTheme.font_body().get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, bw, 15).y) + 8.0
	body.position = Vector2(16, 0)
	body.size = Vector2(bw, bh)
	body.set_meta(&"c10_body", fid)
	row.add_child(body)
	var h := bh
	var kind := str(frag.get("kind", ""))
	if kind != "":
		var cap := _label(CardText.ui("c10.kind." + kind), 14, CardText.is_draft("c10.kind." + kind))
		cap.add_theme_color_override("font_color", CardTheme.color(&"ink_3"))
		cap.position = Vector2(16, h)
		cap.size = Vector2(bw - 80.0, 22)
		cap.set_meta(&"c10_kind", kind)
		row.add_child(cap)
		if kind == "year_after":
			_year_chip(row, str(frag.get("era", "")), Vector2(w - 72.0, h))
		h += 24.0
	var rule := ColorRect.new()
	rule.color = CardTheme.color(&"card_well_line")
	rule.position = Vector2(16, h + 4.0)
	rule.size = Vector2(bw, 1)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(rule)
	row.size = Vector2(w, h + 6.0)
	row.custom_minimum_size = row.size


func _year_chip(row: Control, era: String, at: Vector2) -> void:
	if not _digits(era):
		return
	var lab := _label(era, 14, false)
	lab.add_theme_color_override("font_color", CardTheme.color(&"ribbon_ink"))
	lab.add_theme_stylebox_override("normal", CardTheme.pill_style(&"card_band_gold", &"gold_deep", 4, 8.0, 0.0))
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lab.position = at
	lab.size = Vector2(64, 22)
	lab.set_meta(&"c10_year", era)
	row.add_child(lab)


func _page_title(person: String) -> String:
	var ref := "dp." + person + "#title"
	if CardText.is_draft(ref):
		return CardText.person_name(person)
	return CardText.card("dp." + person, "title")


func _sorted_frags(page: Dictionary) -> Array:
	var raw: Array = page.get("fragments", []) if typeof(page.get("fragments")) == TYPE_ARRAY else []
	var out: Array = []
	for f in raw:
		if typeof(f) == TYPE_DICTIONARY:
			out.append(f)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ao := int(a.get("order", 0))
		var bo := int(b.get("order", 0))
		if ao != bo:
			return ao < bo
		return str(a.get("id", "")) < str(b.get("id", ""))
	)
	return out


func _page_has_new(page: Dictionary) -> bool:
	if int(page.get("new", 0)) > 0:
		return true
	for f in _sorted_frags(page):
		if bool((f as Dictionary).get("new", false)):
			return true
	return false


func _apply_tab() -> void:
	var people := _tab == "people"
	_people_box.visible = people
	_page.visible = people
	_index.visible = people
	if _rules != null:
		if not people:
			_rules.reload()
		_rules.visible = not people
	Kit.paint_tab(_tab_people, people)
	Kit.paint_tab(_tab_rules, not people)


func _step(delta: int) -> void:
	if _tab == "rules":
		if _rules != null:
			_rules.step(delta)
		return
	if _people.is_empty():
		return
	var i := _people.find(_person)
	if i < 0:
		i = 0
	var n := _people.size()
	i = _wrap(i + delta, n)
	_choose_person(str(_people[i]))


func _wrap(i: int, n: int) -> int:
	var m := i
	while m < 0:
		m += n
	while m >= n:
		m -= n
	return m


func _input(event: InputEvent) -> void:
	if not is_inside_tree() or not _topmost():
		return
	var wheel := _wheel(event)
	if wheel != 0:
		# 滚轮在页子或格子上时让它滚；在别处（顶栏、空白）才翻页。
		if _over_scroll():
			return
		_take()
		_step(wheel)
		return
	var key := _key(event)
	if key == KEY_LEFT or key == KEY_RIGHT:
		_take()
		_step(-1 if key == KEY_LEFT else 1)
	elif key == KEY_TAB:
		_take()
		_tab = "rules" if _tab == "people" else "people"
		_apply_tab()
	elif key == KEY_ESCAPE:
		_take()
		close_requested.emit({})


func _over_scroll() -> bool:
	if not is_inside_tree():
		return false
	var at := get_global_mouse_position()
	for s in [_page_scroll, _index_scroll]:
		var sc := s as ScrollContainer
		if sc != null and sc.is_visible_in_tree() and sc.get_global_rect().has_point(at):
			var bar := sc.get_v_scroll_bar()
			if bar != null and bar.max_value > bar.page + 0.5:
				return true
	if _rules != null and _rules.is_visible_in_tree() and (_rules as Control).get_global_rect().has_point(at):
		return true
	return false


func _topmost() -> bool:
	var parent := get_parent()
	if parent == null:
		return false
	var top: Node = null
	for c in parent.get_children():
		if c is CardPanel and (c as CanvasItem).is_visible_in_tree():
			top = c
	return top == self


func _tab_button(key: String, tab_id: String, x: float) -> Button:
	var b := Button.new()
	b.position = Vector2(x, TABS_Y)
	b.size = Vector2(88, 34)
	b.focus_mode = Control.FOCUS_NONE
	b.clip_text = true
	b.text = CardText.ui(key)
	b.set_meta(&"c10_tab", tab_id)
	if tab_id == "people":
		b.pressed.connect(func() -> void:
			_tab = "people"
			_apply_tab()
		)
	elif tab_id == "rules":
		b.pressed.connect(func() -> void:
			_tab = "rules"
			_apply_tab()
		)
	add_child(b)
	return b


## 纸上的字：墨色（草稿灰一点）；24 号以上用毛笔、印泥暗红。
func _label(text: String, sz: int, draft: bool) -> Label:
	var l := Label.new()
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.clip_text = sz >= 24
	l.add_theme_font_size_override("font_size", sz)
	var tone := &"seal_dark" if sz >= 24 else &"ink"
	l.add_theme_color_override("font_color", CardTheme.color(&"ink_soft" if draft else tone))
	l.add_theme_font_override("font", CardTheme.font_title() if sz >= 24 else CardTheme.font_body())
	return l


func _dot() -> ColorRect:
	var d := ColorRect.new()
	d.color = CardTheme.color(&"seal")
	d.custom_minimum_size = Vector2(10, 10)
	d.size = Vector2(10, 10)
	d.mouse_filter = Control.MOUSE_FILTER_IGNORE
	d.set_meta(&"c10_dot", "1")
	return d


func _digits(s: String) -> bool:
	if s == "":
		return false
	for i in range(s.length()):
		var ch := s.unicode_at(i)
		if ch < 48 or ch > 57:
			return false
	return true


func _wipe(n: Node) -> void:
	var kids: Array = n.get_children()
	for c in kids:
		n.remove_child(c)
		(c as Node).queue_free()


func _take() -> void:
	if get_viewport() != null:
		get_viewport().set_input_as_handled()


func _key(event: InputEvent) -> Key:
	if event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo:
		return (event as InputEventKey).keycode
	return KEY_NONE


func _wheel(event: InputEvent) -> int:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		var b := (event as InputEventMouseButton).button_index
		if b == MOUSE_BUTTON_WHEEL_UP:
			return -1
		if b == MOUSE_BUTTON_WHEEL_DOWN:
			return 1
	return 0
