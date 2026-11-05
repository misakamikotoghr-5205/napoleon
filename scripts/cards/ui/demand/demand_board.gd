# 条子板：抽屉里每张条子一行（类别、档位字、剩几天），到期前一天用 danger 色，多了就滚动。
# 主人 C05。合同：docs/cards/CARDS_INTERFACES.md §3.3 C05、§7.5、§7.8、§7.10.5、§7.11。
# 类别和档位读 CardView 的 demand {kind, tier}。锚点：a.demand.board；第一张的 a.demand.days、a.demand.tier
# （演出时由面板用柜台中间那张条子的矩形后登记，盖住这一行）。
# 换皮（10-22，原型 32_drawer_notes）：板子本身透明（放在深色抽屉里）；每张条子是一张纸片（paper_card_style），
# 左边类别小图 ×2，墨字类别 + 档位小红牌，下面一行要交多少，右边“还剩 n 天”（b44：给足宽度，不再截成“还剩 7”）。
class_name CardDemandBoard
extends Control

const Fmt = preload("res://scripts/cards/ui/demand/demand_format.gd")
const BOARD := Vector2(216, 220)
const ROW_H := 56.0
const WIDE := 300.0

signal demand_pressed(uid: String)

var _list: VBoxContainer
var _scroll: ScrollContainer
var _title: Label
var _built: bool = false
var _show_title: bool = true
var _last_view: Dictionary = {}
var _row_w: float = 0.0


func _ready() -> void:
	_build()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and _built:
		_layout()


## 抽屉里不显示板子自己的标题（抽屉框已经写着“条子”）。
func show_title(on: bool) -> void:
	_show_title = on
	if _title != null:
		_title.visible = on
	_layout()


func _build() -> void:
	if _built:
		return
	_built = true
	custom_minimum_size = BOARD
	if size.x < BOARD.x or size.y < BOARD.y:
		size = BOARD
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	var title_key := "c05.board.title"
	_title = _label("Title", CardText.ui(title_key), false, CardText.is_draft(title_key), Vector2(4, 2), Vector2(200, 22))
	_title.add_theme_font_override("font", CardTheme.font_body_bold())
	_title.add_theme_font_size_override("font_size", 15)
	_title.add_theme_color_override("font_color", CardTheme.color(&"gold_hi"))
	_title.visible = _show_title
	add_child(_title)
	_scroll = ScrollContainer.new()
	_scroll.name = "Scroll"
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_scroll)
	_list = VBoxContainer.new()
	_list.name = "List"
	_list.add_theme_constant_override("separation", 6)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_list)
	_layout()
	CardAnchors.register(&"a.demand.board", self)


func _layout() -> void:
	if _scroll == null:
		return
	var w := maxf(size.x, BOARD.x)
	var h := maxf(size.y, BOARD.y)
	var top := 28.0 if _show_title else 0.0
	if _title != null:
		_title.size = Vector2(w - 8.0, 22)
	_scroll.position = Vector2(0, top)
	_scroll.size = Vector2(w, h - top)
	_list.custom_minimum_size = Vector2(w - 12.0, 0)
	# 行是按宽度排的（窄板子两行字、宽抽屉一行）：宽度变了就按上次的 view 重排一遍。
	if _row_w > 0.0 and absf(_row_w - _want_row_w()) > 1.0 and not _last_view.is_empty():
		refresh.call_deferred(_last_view)


func _want_row_w() -> float:
	return maxf(196.0, maxf(size.x, BOARD.x) - 12.0)


func refresh(view: Dictionary) -> void:
	_build()
	_last_view = view
	_row_w = _want_row_w()
	_title.text = CardText.ui("c05.board.title")
	for c in _list.get_children():
		_list.remove_child(c)
		c.queue_free()
	var demands = view.get("demands", [])
	if typeof(demands) != TYPE_ARRAY:
		return
	var first := true
	for d in demands:
		if typeof(d) != TYPE_DICTIONARY:
			continue
		_add_row(d, first)
		first = false


func _add_row(d: Dictionary, first: bool) -> void:
	var uid := str(d.get("uid", ""))
	var days_n := int(d.get("days_left", -1))
	var danger := Fmt.days_danger(days_n)
	var row := Button.new()
	row.name = "Row_" + uid
	row.focus_mode = Control.FOCUS_NONE
	row.alignment = HORIZONTAL_ALIGNMENT_LEFT
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	row.custom_minimum_size = Vector2(_row_w, ROW_H)
	_paper(row, danger)
	row.pressed.connect(_press.bind(uid))
	_fill_row(row, d, danger, days_n, first)
	_list.add_child(row)


## 纸片底：平时 paper_card，悬停/按下边变 gold_deep；快到期的左边一道印泥红。
func _paper(row: Button, danger: bool) -> void:
	var normal := CardTheme.paper_card_style()
	if danger:
		normal.border_color = CardTheme.color(&"seal")
		normal.border_width_left = 4
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = CardTheme.color(&"card_face_top")
	hover.border_color = CardTheme.color(&"gold_deep")
	hover.set_border_width_all(2)
	if danger:
		hover.border_width_left = 4
		hover.border_color = CardTheme.color(&"seal")
	for s in [&"normal", &"focus", &"disabled"]:
		row.add_theme_stylebox_override(s, normal)
	for s in [&"hover", &"pressed", &"hover_pressed"]:
		row.add_theme_stylebox_override(s, hover)


func _fill_row(row: Button, d: Dictionary, danger: bool, days_n: int, first: bool) -> void:
	var w := row.custom_minimum_size.x
	var wide := w >= WIDE
	var meta := _meta(d)
	var kind := str(meta.get("kind", ""))
	var x := 10.0
	if kind != "":
		x = _add_kind(row, kind, danger)
	if meta.has("tier"):
		var tier := int(meta["tier"])
		var tier_l := _label("Tier", Fmt.tier_line(tier), danger, CardText.is_draft("c05.tier.%d" % tier),
				Vector2(x, 7), Vector2(64 if wide else 56, 22))
		tier_l.clip_text = false
		row.add_child(tier_l)
		if first:
			CardAnchors.register(&"a.demand.tier", tier_l)
	var amount := int(d.get("amount", 0))
	if wide and amount > 0:
		var amount_l := _label("RowAmount", Fmt.amount_line(amount), false, CardText.is_draft("c05.amount"),
				Vector2(50, 30), Vector2(w - 170.0, 22))
		amount_l.add_theme_color_override("font_color", CardTheme.color(&"card_sub_ink"))
		row.add_child(amount_l)
	var days_pos := Vector2(w - 112.0, 17) if wide else Vector2(50, 30)
	var days_l := _label("Days", Fmt.days_line(days_n), danger, false, days_pos, Vector2(102, 22))
	days_l.clip_text = false
	days_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if wide else HORIZONTAL_ALIGNMENT_LEFT
	if danger:
		days_l.add_theme_font_override("font", CardTheme.font_body_bold())
	row.add_child(days_l)
	if first:
		CardAnchors.register(&"a.demand.days", days_l)


func _meta(d: Dictionary) -> Dictionary:
	var block = d.get("demand", {})
	if typeof(block) == TYPE_DICTIONARY:
		return block
	return {}


## 类别：小图 ×2（16x16 → 32x32）+ 墨字类别名；返回档位字该摆的 x。
func _add_kind(row: Button, kind: String, danger: bool) -> float:
	var art_id := "icon.demand." + kind
	var base := CardArt.base_size(art_id)
	if base != Vector2i.ZERO:
		var icon := TextureRect.new()
		icon.name = "KindIcon"
		icon.texture = CardArt.texture(art_id)
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_SCALE
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var k := 2 if base.x <= 16 else 1
		icon.size = Vector2(base) * float(k)
		icon.position = Vector2(10, (ROW_H - icon.size.y) * 0.5)
		row.add_child(icon)
	var kind_l := _label("Kind", Fmt.kind_line(kind), danger, CardText.is_draft("c05.kind." + kind),
			Vector2(50, 5), Vector2(64, 24))
	kind_l.add_theme_font_override("font", CardTheme.font_body_bold())
	kind_l.add_theme_font_size_override("font_size", 16)
	kind_l.clip_text = false
	row.add_child(kind_l)
	var font := CardTheme.font_body_bold()
	var kw := font.get_string_size(kind_l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	return 50.0 + ceilf(kw) + 8.0


func _label(node_name: String, text: String, danger: bool, draft: bool, pos: Vector2, box: Vector2) -> Label:
	var lab := Label.new()
	lab.name = node_name
	lab.text = text
	lab.clip_text = true
	lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lab.position = pos
	lab.size = box
	lab.custom_minimum_size = box
	lab.add_theme_font_override("font", CardTheme.font_body())
	lab.add_theme_font_size_override("font_size", 14)
	var key := &"danger" if danger else (&"ink_soft" if draft else &"ink")
	lab.add_theme_color_override("font_color", CardTheme.color(key))
	return lab


func _press(uid: String) -> void:
	demand_pressed.emit(uid)
