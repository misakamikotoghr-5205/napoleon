# 一张牌的正面、背面、牌框、金色微光、角标、留着角标和拖拽源。
# 主人 C02。合同 §3.3 C02、§7.8、§1.2、§7.11.6。文字走 CardText，颜色走 CardTheme，图走 CardArt。
# 1.3：悬停不再弹出放大副本；选中放大由手牌扇摆在 PREVIEW_CARD。
# 换皮（10-22，照网页原型 scene_demo.html 的 .card，换皮 SPEC §7）：
#   纸面竖渐变（按牌种 card_*_top/bot）+ 3px 牌种色边 + 圆角 + 内亮边 + 外影；顶上一条牌种条（主线 / 来当 / 事件…）；
#   插图格（人像整数倍贴顶、插图整数倍居中，格子裁掉多的）或毛笔大字（没有图时，取牌名第一个字）；
#   居中粗体牌名（放不下先缩字，再两行，再省略号 + 悬停提示，b43）；一行副行；放大时一段说明；
#   主线牌右上斜挂金绶带；留着的牌左上红“留”章 + 剩几天药丸。
#   九宫格牌框图（frame.*）不再画在牌上：中心透明（人物牌透明，b12）、24px 粗边直角，和原型差太远。FrameNine 留着、永远隐藏。
#   牌上的“留着”小按钮挪到插图格左上（b14：原来在牌底，正好落在屏幕外那 24px，又被右边的牌压住）。
# 锚点：a.card@<uid>、a.card.keep@<uid>、a.card.days@<uid>、a.card.gold@<uid>。
# ui_event：card_drag_started {uid, zone}。不发 first_time。
class_name CardWidget
extends Control

signal pressed(uid: String)
signal action_requested(uid: String, action_id: String)

const GradBox = preload("res://scripts/cards/ui/common/grad_box.gd")
const SIZES := {&"hand": Vector2(144, 200), &"zoom": Vector2(288, 400), &"mini": Vector2(72, 100)}
const ART_K := {&"hand": 2, &"zoom": 4, &"mini": 1}
## 金色微光单段时长（秒）。合同：单段不超过 0.6。
const GLOW_SEC := 0.6
const PORTRAIT_TYPES: Array[String] = ["person", "self", "contact"]
## 各尺寸的版式（像素）：边、圆角、左右内缩、牌种条、插图格、牌名字号（依次试）、副行、毛笔大字、“留”章。
const METRICS := {
	&"hand": {"border": 3, "radius": 9, "inset": 8, "band_y": 7, "band_h": 20, "band_px": 14, "gap": 3,
		"well_h": 88, "title_px": [20, 17, 15], "sub_px": 14, "glyph_px": 56, "seal": 26, "seal_px": 18,
		"glow": 18, "shadow": 14, "shadow_y": 6},
	&"zoom": {"border": 3, "radius": 12, "inset": 10, "band_y": 9, "band_h": 26, "band_px": 16, "gap": 4,
		"well_h": 152, "title_px": [24, 20, 17], "sub_px": 16, "glyph_px": 72, "seal": 30, "seal_px": 20,
		"glow": 24, "shadow": 18, "shadow_y": 8},
	&"mini": {"border": 2, "radius": 6, "inset": 4, "band_y": 4, "band_h": 5, "band_px": 0, "gap": 2,
		"well_h": 40, "title_px": [14], "sub_px": 0, "glyph_px": 30, "seal": 18, "seal_px": 14,
		"glow": 8, "shadow": 6, "shadow_y": 3},
}
## 牌种 → 边色 / 牌种条色（frame_*）。没登记的牌种退回 umber（原型 .card 的默认 --fr）。
const FRAME_KEYS := {"person": &"frame_person", "self": &"frame_self", "contact": &"frame_contact",
	"event": &"frame_event", "fate": &"frame_fate", "big_fate": &"frame_big_fate", "demand": &"frame_demand",
	"life": &"frame_life", "news": &"frame_news", "kept": &"frame_kept", "estate": &"frame_estate",
	"night": &"frame_night", "street": &"frame_street", "prison": &"frame_prison"}
## 牌种 → 纸面上下两色（没列的用 card_face_*）。
const FACE_KEYS := {"big_fate": [&"card_bigfate_top", &"card_bigfate_bot"],
	"prison": [&"card_prison_top", &"card_prison_bot"], "kept": [&"card_kept_top", &"card_kept_bot"],
	"night": [&"card_night_top", &"card_night_bot"], "gold": [&"card_gold_top", &"card_gold_bot"]}
const GRAY_SHADER := "shader_type canvas_item;\nuniform float dim = 1.0;\nvoid fragment() {\n" \
	+ "\tfloat g = dot(COLOR.rgb, vec3(0.299, 0.587, 0.114)) * dim;\n\tCOLOR = vec4(vec3(g), COLOR.a);\n}\n"

static var _gray_shader: Shader = null
static var _band_font: Font = null
static var _italic: Dictionary = {}
static var _glow_tex: Texture2D = null

## 发 ui_event 用（宿主注入；没注入时用 autoload CardBus）。
var bus: CardEventBus = null
## 快动画：静态金光，不播呼吸。冻结读取是 CardSettings.fast_anim()；这个布尔让测试压住呼吸。
var fast_anim: bool = false:
	set(value):
		fast_anim = value
		if _glow != null:
			_sync_glow()

var _view: Dictionary = {}
var _mode: StringName = &"hand"
var _back_on: bool = false
var _passive: bool = false
var _lifted: bool = false
var _ring_on: bool = false
var _anchors: Array = []
var _glow_tween: Tween = null
var _title_lines: int = 1

var _glow: Panel
var _ring: Panel
var _frame_nine: NinePatchRect
var _frame_flat: Panel
var _paper: Control
var _band: Label
var _dot: Panel
var _well: Panel
var _glyph_glow: TextureRect
var _glyph: Glyph
var _art: TextureRect
var _title: Label
var _sub: Label
var _brief: Label
var _ribbon_mask: Control
var _ribbon: Label
var _kept_badge: Label
var _days: Label
var _keep: Button
var _back: Panel
var _hi: Panel


## 毛笔大字：牌名第一个字画在插图格正中（字来自 CardText 的牌名；用 draw_string，不另起一段界面字）。
class Glyph:
	extends Control
	var glyph: String = ""
	var font: Font = null
	var px: int = 56
	var ink: Color = Color.WHITE

	func _draw() -> void:
		if glyph == "" or font == null:
			return
		var w := font.get_string_size(glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
		var asc := font.get_ascent(px)
		var desc := font.get_descent(px)
		var base := (size.y - (asc + desc)) * 0.5 + asc
		draw_string(font, Vector2((size.x - w) * 0.5, base), glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, px, ink)


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	_glow = _panel("Glow")
	_ring = _panel("Ring")
	_frame_nine = NinePatchRect.new()
	_frame_nine.name = "FrameNine"
	_frame_nine.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame_nine.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_frame_nine)
	_frame_flat = _panel("FrameFlat")
	_paper = GradBox.new()
	_paper.name = "Paper"
	add_child(_paper)
	_band = _label("Band")
	_band.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_band.clip_text = true
	_band.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_dot = _panel("Dot")
	_well = _panel("Well")
	_well.clip_contents = true
	_glyph_glow = TextureRect.new()
	_glyph_glow.name = "GlyphGlow"
	_glyph_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_glyph_glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_glyph_glow.stretch_mode = TextureRect.STRETCH_SCALE
	_well.add_child(_glyph_glow)
	_glyph = Glyph.new()
	_glyph.name = "Glyph"
	_glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_well.add_child(_glyph)
	_art = TextureRect.new()
	_art.name = "Art"
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art.stretch_mode = TextureRect.STRETCH_SCALE
	_well.add_child(_art)
	_title = _label("Title")
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_sub = _label("Sub")
	_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sub.clip_text = true
	_sub.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_brief = _label("Brief")
	_brief.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_brief.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_brief.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	# 绶带只在牌的内框里（原型 overflow:hidden）；斜着穿过上边和右边，不碰圆角，所以方形裁切就够。
	_ribbon_mask = Control.new()
	_ribbon_mask.name = "RibbonMask"
	_ribbon_mask.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ribbon_mask.clip_contents = true
	add_child(_ribbon_mask)
	_ribbon = Label.new()
	_ribbon.name = "Ribbon"
	_ribbon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ribbon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ribbon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_ribbon_mask.add_child(_ribbon)
	_kept_badge = _label("KeptBadge")
	_kept_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_days = _label("Days")
	_days.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_keep = Button.new()
	_keep.name = "Keep"
	_keep.focus_mode = Control.FOCUS_ALL
	_keep.pressed.connect(_on_keep)
	add_child(_keep)
	_back = _panel("BackFill")
	_hi = _panel("Hi")
	for node in [_frame_nine, _glow, _ring, _back, _hi, _dot, _ribbon_mask, _kept_badge, _days, _keep, _brief]:
		(node as CanvasItem).visible = false
	_mode = &"hand"
	size = SIZES[&"hand"]
	custom_minimum_size = size
	# 牌是定尺寸的：放进容器时按最小尺寸摆，不被拉伸（调用方要别的对齐可以再改）。
	size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_layout()


func set_card(card_view: Dictionary) -> void:
	_unregister_anchors()
	_view = card_view.duplicate(true)
	_refresh()


func set_size_mode(mode: StringName) -> void:
	_mode = mode if SIZES.has(mode) else &"hand"
	custom_minimum_size = SIZES[_mode]
	size = SIZES[_mode]
	if _glow != null:
		_refresh()


## 选中：牌外一圈 2px focus 亮边（原型 .sel / :focus-visible）。
func set_highlight(on: bool) -> void:
	if _hi == null:
		return
	_hi.visible = on


## 手牌扇悬停抬起：外影加深（原型 0 18px 34px .72）。
func set_lifted(on: bool) -> void:
	_lifted = on
	if _frame_flat != null:
		_apply_shadow()


## 柜台上有格子、手牌下沉时，留着的牌加一圈金光（原型 #hand.low .k-kept）。
func set_ring(on: bool) -> void:
	_ring_on = on
	if _ring != null:
		_ring.visible = on and not _back_on


func set_back(on: bool) -> void:
	_back_on = on
	if _glow != null:
		_refresh()


func get_uid() -> String:
	return str(_view.get("uid", ""))


## 能留就发 action_requested(keep)；否则没得做。同一视图永远做同一件事。
func autoplay_step() -> bool:
	if _passive or _back_on or get_uid() == "" or not _can_keep():
		return false
	action_requested.emit(get_uid(), "keep")
	return true


## 拖起来的影子（原型 .card.ghost）：同尺寸、转 -4 度、放大 1.06、94% 不透明、深外影 + focus 圈。
## 返回一个外壳，牌按 grab（鼠标在牌上的点）摆，跟着鼠标走的是抓住的那一点。
func make_ghost(grab: Vector2) -> Control:
	var holder := Control.new()
	holder.name = "DragGhost"
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var copy := _make_copy(_mode)
	copy.set_lifted(true)
	copy.set_highlight(true)
	copy.pivot_offset = grab
	copy.position = -grab
	copy.rotation_degrees = -4.0
	copy.scale = Vector2(1.06, 1.06)
	copy.modulate.a = 0.94
	holder.add_child(copy)
	return holder


## 灰度材质（留着的人情牌头像、用过了的人脸）：着色器里没有颜色值，dim 调暗。
static func gray_material(dim: float = 1.0) -> ShaderMaterial:
	if _gray_shader == null:
		_gray_shader = Shader.new()
		_gray_shader.code = GRAY_SHADER
	var m := ShaderMaterial.new()
	m.shader = _gray_shader
	m.set_shader_parameter(&"dim", dim)
	return m


func _gui_input(event: InputEvent) -> void:
	if _passive:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			pressed.emit(get_uid())
			accept_event()
	elif event.is_action_pressed(&"ui_accept"):
		pressed.emit(get_uid())
		accept_event()


func _get_drag_data(at_position: Vector2) -> Variant:
	if _passive or get_uid() == "":
		return null
	var uid := get_uid()
	var zone := str(_view.get("zone", ""))
	_ui(&"card_drag_started", {"uid": uid, "zone": zone})
	var preview := make_ghost(at_position)
	if is_inside_tree() and get_viewport().gui_is_dragging() and preview.get_parent() == null:
		set_drag_preview(preview)
	if preview.get_parent() == null:
		preview.free()
	return {"kind": "card", "uid": uid, "zone": zone}


func _enter_tree() -> void:
	if _glow != null and _is_gold():
		_sync_glow()


func _exit_tree() -> void:
	_kill_glow()


# ---------------- 刷新 ----------------
func _refresh() -> void:
	_apply_face()
	_apply_art()
	_apply_text()
	_apply_marks()
	_apply_back()
	_apply_hi()
	_layout()
	_sync_gray()
	_sync_glow()
	_sync_anchors()


func _apply_face() -> void:
	var m := _metrics()
	var border := int(m["border"])
	var radius := int(m["radius"])
	var faces: Array = _face_keys()
	var edge := _frame_key()
	_frame_nine.visible = false
	var sb := StyleBoxFlat.new()
	sb.bg_color = CardTheme.mix(faces[0], faces[1])
	sb.border_color = CardTheme.color(edge)
	sb.set_border_width_all(border)
	sb.set_corner_radius_all(radius)
	sb.corner_detail = 6
	_frame_flat.add_theme_stylebox_override("panel", sb)
	_frame_flat.visible = not _back_on
	_apply_shadow()
	_paper.set_colors(faces[0], faces[1])
	_paper.set_border(float(border), edge)
	_paper.set_radius(float(radius))
	_paper.set_inner(2.0 if _mode != &"mini" else 1.0, CardTheme.color(&"card_hilite"))
	_paper.visible = not _back_on
	var band := StyleBoxFlat.new()
	band.bg_color = CardTheme.color(&"card_band_gold" if _is_gold() else edge)
	band.set_corner_radius_all(4 if _mode != &"mini" else 2)
	if _is_kept_zone() and _mode != &"mini":
		# 左上的“留”章压在牌种条左端，字往右让出章的宽度（原型的章同样压着条）。
		band.content_margin_left = float(_metrics()["seal"]) - 2.0
	_band.add_theme_stylebox_override("normal", band)
	var well := StyleBoxFlat.new()
	well.bg_color = CardTheme.color(&"card_well")
	well.border_color = CardTheme.color(&"card_well_line")
	well.set_border_width_all(1)
	well.set_corner_radius_all(3)
	_well.add_theme_stylebox_override("panel", well)
	_well.visible = not _back_on


func _apply_shadow() -> void:
	var sb := _frame_flat.get_theme_stylebox("panel") as StyleBoxFlat
	if sb == null:
		return
	var m := _metrics()
	if _lifted:
		sb.shadow_color = CardTheme.with_alpha(&"card_shadow", 0.72)
		sb.shadow_size = int(m["shadow"]) * 2 + 6
		sb.shadow_offset = Vector2(0, int(m["shadow_y"]) * 3)
	else:
		sb.shadow_color = CardTheme.color(&"card_shadow")
		sb.shadow_size = int(m["shadow"])
		sb.shadow_offset = Vector2(0, int(m["shadow_y"]))


func _apply_art() -> void:
	var id := str(_view.get("art", ""))
	var tex: Texture2D = null
	if id != "" and not CardArt.is_missing(id):
		tex = CardArt.texture(id)
	_art.texture = tex
	_art.visible = not _back_on and tex != null
	_art.material = gray_material(0.95) if tex != null and _is_kept_zone() and _is_portrait() else null
	var show_glyph := not _back_on and tex == null
	_glyph.visible = show_glyph
	_glyph_glow.visible = show_glyph
	if show_glyph:
		_glyph.font = CardTheme.font_title()
		_glyph.px = int(_metrics()["glyph_px"])
		_glyph.ink = CardTheme.color(&"card_night_ink" if _is_night() else _frame_key())
		_glyph_glow.texture = _glow_texture()
	_glyph.queue_redraw()


func _apply_text() -> void:
	var def_id := str(_view.get("def", ""))
	var override_key := str(_view.get("_title_ui", ""))
	var title := ""
	var draft := false
	if override_key != "":
		title = CardText.ui(override_key)
		draft = CardText.is_draft(override_key)
	elif def_id != "":
		title = CardText.card(def_id, "title")
		draft = CardText.is_draft(def_id + "#title")
	else:
		draft = true
	var ink := &"card_night_ink" if _is_night() else &"ink"
	_title.add_theme_font_override("font", _font(CardTheme.font_body_bold(), draft))
	_title.add_theme_color_override("font_color", CardTheme.color(&"ink_soft" if draft and not _is_night() else ink))
	_title.text = title
	_title.visible = not _back_on
	_glyph.glyph = title.substr(0, 1) if title != "" else ""
	var band_px := int(_metrics()["band_px"])
	_band.visible = not _back_on
	_band.text = _band_text() if band_px > 0 else ""
	if band_px > 0:
		_band.add_theme_font_override("font", _band_face())
		_band.add_theme_font_size_override("font_size", band_px)
		_band.add_theme_color_override("font_color", CardTheme.color(&"card_band_ink"))
	var sub_px := int(_metrics()["sub_px"])
	_sub.visible = sub_px > 0 and not _back_on
	_sub.text = _sub_text() if sub_px > 0 else ""
	if sub_px > 0:
		_sub.add_theme_font_override("font", CardTheme.font_body())
		_sub.add_theme_font_size_override("font_size", sub_px)
		_sub.add_theme_color_override("font_color", CardTheme.color(&"card_night_sub" if _is_night() else &"card_sub_ink"))
	var brief := _brief_text() if _mode == &"zoom" else ""
	_brief.visible = brief != "" and not _back_on
	_brief.text = brief
	if brief != "":
		_brief.add_theme_font_override("font", CardTheme.font_body())
		_brief.add_theme_font_size_override("font_size", 15)
		_brief.add_theme_constant_override("line_spacing", 4)
		_brief.add_theme_color_override("font_color", CardTheme.color(&"card_night_sub" if _is_night() else &"card_sub_ink"))
	var gold := _is_gold() and _mode != &"mini" and not _back_on
	_ribbon_mask.visible = gold
	_ribbon.text = CardText.ui("c02.ribbon.gold") if gold else ""
	if gold:
		_ribbon.add_theme_font_override("font", CardTheme.font_body_bold())
		_ribbon.add_theme_font_size_override("font_size", 14 if _mode == &"hand" else 16)
		_ribbon.add_theme_color_override("font_color", CardTheme.color(&"ribbon_ink"))
		var rb := StyleBoxFlat.new()
		rb.bg_color = CardTheme.mix(&"gold_pale", &"gold_hi", 0.55)
		rb.border_color = CardTheme.color(&"gold_pale")
		rb.border_width_top = 1
		rb.shadow_color = CardTheme.with_alpha(&"card_shadow", 0.4)
		rb.shadow_size = 2
		rb.shadow_offset = Vector2(0, 1)
		_ribbon.add_theme_stylebox_override("normal", rb)


func _apply_marks() -> void:
	var m := _metrics()
	var info := _days_info()
	var show_days := not info.is_empty() and not _back_on
	_days.visible = show_days
	if show_days:
		_days.text = CardText.ui(str(info["key"]), {"n": int(info["n"])})
		_days.tooltip_text = CardText.ui("c02.days.badge", {"n": int(info["n"])})
		_days.add_theme_stylebox_override("normal", CardTheme.pill_style(StringName(str(info["plate"])), &"", 3, 4.0, 0.0))
		_days.add_theme_color_override("font_color", CardTheme.color(&"days_ink"))
		_days.add_theme_font_size_override("font_size", 14)
		_days.add_theme_font_override("font", CardTheme.font_body())
	else:
		_days.text = ""
		_days.tooltip_text = ""
	var dot := _flag(_view.get("must_resolve", false)) and str(_view.get("zone", "")) == "hand" and not _back_on
	_dot.visible = dot
	if dot:
		var ds := StyleBoxFlat.new()
		ds.bg_color = CardTheme.color(&"seal")
		ds.border_color = CardTheme.color(&"seal_rim")
		ds.set_border_width_all(1)
		ds.set_corner_radius_all(6)
		_dot.add_theme_stylebox_override("panel", ds)
	var kept := _is_kept_zone() and not _back_on
	_kept_badge.visible = kept
	_kept_badge.text = CardText.ui("c02.kept.badge") if kept else ""
	if kept:
		var seal := int(m["seal"])
		var ks := StyleBoxFlat.new()
		ks.bg_color = CardTheme.color(&"seal")
		ks.border_color = CardTheme.color(&"seal_rim")
		ks.set_border_width_all(2)
		ks.set_corner_radius_all(seal / 2)
		ks.corner_detail = 10
		ks.shadow_color = CardTheme.with_alpha(&"card_shadow", 0.35)
		ks.shadow_size = 2
		ks.shadow_offset = Vector2(0, 1)
		_kept_badge.add_theme_stylebox_override("normal", ks)
		_kept_badge.add_theme_color_override("font_color", CardTheme.color(&"seal_paper"))
		_kept_badge.add_theme_font_size_override("font_size", int(m["seal_px"]))
		_kept_badge.add_theme_font_override("font", CardTheme.font_title())
	# 小牌（打烊清单、抽屉里）不放留着按钮：太挤；能留的牌在手牌扇里留。
	_keep.visible = _can_keep() and not _back_on and _mode != &"mini"
	_keep.text = CardText.ui("c02.btn.keep") if _keep.visible else ""
	if _keep.visible:
		var keep_draft := CardText.is_draft("c02.btn.keep")
		var pad := 7.0 if _mode != &"mini" else 4.0
		var normal := CardTheme.button_style(&"btn_top", &"btn_bot", &"btn_edge", pad, 0.0, 5)
		normal.set_border_width_all(1)
		var hover := CardTheme.button_style(&"btn_hover_top", &"btn_top", &"gold_deep", pad, 0.0, 5)
		hover.set_border_width_all(1)
		var press := hover.duplicate() as StyleBoxFlat
		press.shadow_size = 0
		press.content_margin_top = 1.0
		_keep.add_theme_stylebox_override("normal", normal)
		_keep.add_theme_stylebox_override("hover", hover)
		_keep.add_theme_stylebox_override("pressed", press)
		_keep.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		_keep.add_theme_color_override("font_color", CardTheme.color(&"text_2" if keep_draft else &"hud_ink"))
		_keep.add_theme_color_override("font_hover_color", CardTheme.color(&"gold_pale"))
		_keep.add_theme_color_override("font_pressed_color", CardTheme.color(&"gold_pale"))
		_keep.add_theme_font_size_override("font_size", 14)
		_keep.add_theme_font_override("font", _font(CardTheme.font_body(), keep_draft))


func _apply_back() -> void:
	_back.visible = _back_on
	if not _back_on:
		return
	var m := _metrics()
	var sb := StyleBoxFlat.new()
	sb.bg_color = CardTheme.mix(&"wood_2", &"wood_0")
	sb.border_color = CardTheme.color(&"gold_hi" if _is_gold() else _frame_key())
	sb.set_border_width_all(int(m["border"]))
	sb.set_corner_radius_all(int(m["radius"]))
	_back.add_theme_stylebox_override("panel", sb)
	for node in [_band, _well, _dot, _ribbon_mask, _sub, _brief, _kept_badge, _days, _keep]:
		(node as CanvasItem).visible = false


func _apply_hi() -> void:
	var r := int(_metrics()["radius"])
	_hi.add_theme_stylebox_override("panel", _ring_style(&"focus", 2 if _mode != &"mini" else 1, 3, r))
	var ring := _ring_style(&"gold_hi", 2, 2, r)
	ring.shadow_color = CardTheme.with_alpha(&"gold_glow", 0.6)
	ring.shadow_size = 14
	_ring.add_theme_stylebox_override("panel", ring)
	_ring.visible = _ring_on and not _back_on
	var m := _metrics()
	var glow := _ring_style(&"gold_pale", 2 if _mode != &"mini" else 1, 2, r)
	glow.shadow_color = CardTheme.with_alpha(&"gold_glow", 0.75)
	glow.shadow_size = int(m["glow"])
	_glow.add_theme_stylebox_override("panel", glow)


func _ring_style(edge: StringName, width: int, out: int, radius: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color.TRANSPARENT
	sb.border_color = CardTheme.color(edge)
	sb.set_border_width_all(width)
	sb.set_expand_margin_all(float(out))
	sb.set_corner_radius_all(radius + out)
	sb.corner_detail = 6
	return sb


## 牌面按尺寸档（SIZES）排，不按控件当时的 size：从场景实例化时 size 还是手牌大小，放进容器又可能被拉高；
## 小牌在 kept_full / contacts_full 的横排里原来就画成了手牌大，叠在一起。
func _layout() -> void:
	var card: Vector2 = SIZES[_mode]
	var w := int(card.x)
	var h := int(card.y)
	var m := _metrics()
	for node in [_glow, _ring, _frame_nine, _frame_flat, _paper, _back, _hi]:
		_fill(node as Control, w, h)
	var border := int(m["border"])
	_place(_ribbon_mask, border, border, w - border * 2, h - border * 2)
	var inset := int(m["inset"])
	var cw := w - inset * 2
	var gap := int(m["gap"])
	var band_y := int(m["band_y"])
	var band_h := int(m["band_h"])
	_place(_band, inset, band_y, cw, band_h)
	var dot := 10 if _mode == &"zoom" else (8 if _mode == &"hand" else 6)
	_dot.position = Vector2(inset + 5, band_y + (band_h - dot) / 2) if _mode != &"mini" else Vector2(inset, band_y + band_h + 1)
	_dot.size = Vector2(dot, dot)
	var well_y := band_y + band_h + gap
	var well_h := int(m["well_h"])
	_place(_well, inset, well_y, cw, well_h)
	_glyph.position = Vector2.ZERO
	_glyph.size = Vector2(cw, well_h)
	var glow_d := mini(cw, int(well_h * 1.6))
	_glyph_glow.size = Vector2(glow_d, well_h)
	_glyph_glow.position = Vector2((cw - glow_d) / 2, 0)
	var base := _art_base()
	var k := int(ART_K[_mode])
	var aw := base.x * k
	var ah := base.y * k
	_art.size = Vector2(aw, ah)
	var art_y := 0 if _is_portrait() else (well_h - ah) / 2
	_art.position = Vector2((cw - aw) / 2, art_y)
	var y := well_y + well_h + gap
	var title_h := _fit_title(cw)
	_place(_title, inset, y, cw, title_h)
	y += title_h
	var sub_px := int(m["sub_px"])
	if sub_px > 0:
		var sub_h := int(ceil(CardTheme.font_body().get_height(sub_px)))
		_place(_sub, inset, y, cw, sub_h)
		y += sub_h
	if _mode == &"zoom":
		_place(_brief, inset + 2, y + 6, cw - 4, h - int(m["border"]) - 8 - (y + 6))
		_brief.max_lines_visible = maxi(1, int((_brief.size.y + 4.0) / (CardTheme.font_body().get_height(15) + 4.0)))
	var seal := int(m["seal"])
	var seal_at := 6 if _mode == &"hand" else (8 if _mode == &"zoom" else 3)
	_place(_kept_badge, seal_at, seal_at, seal, seal)
	var days_y := well_y + 3 if not _kept_badge.visible else seal_at + seal + 3
	if _mode == &"mini":
		days_y = well_y + well_h - 20
	var days_w := int(_days.get_minimum_size().x) if _days.visible else 0
	_place(_days, inset - 2, days_y, days_w, 20)
	var keep_y := well_y + 3
	if _days.visible:
		keep_y = days_y + 22
	var keep_w := int(_keep.get_minimum_size().x) if _keep.visible else 40
	var keep_h := 24 if _mode != &"mini" else 20
	_place(_keep, inset + 2, keep_y, keep_w, keep_h)
	var ribbon_w := 92 if _mode == &"hand" else 124
	var ribbon_h := 20 if _mode == &"hand" else 24
	_ribbon.size = Vector2(ribbon_w, ribbon_h)
	_ribbon.pivot_offset = _ribbon.size * 0.5
	_ribbon.rotation_degrees = 40.0
	var rc := Vector2(w - (17 if _mode == &"hand" else 24), 20 if _mode == &"hand" else 27)
	_ribbon.position = rc - _ribbon.size * 0.5 - Vector2(border, border)


## 牌名放进 width：试一行的几个字号，都放不下就用最小号两行，再放不下省略号 + 牌上悬停提示（b43）。返回高度。
func _fit_title(width: int) -> int:
	var sizes: Array = _metrics()["title_px"]
	var font := _title.get_theme_font("font")
	var text := _title.text
	var px := int(sizes[sizes.size() - 1])
	var lines := 2
	for s in sizes:
		if font == null or font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, int(s)).x <= float(width):
			px = int(s)
			lines = 1
			break
	_title_lines = lines
	_title.add_theme_font_size_override("font_size", px)
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if lines > 1 else TextServer.AUTOWRAP_OFF
	_title.max_lines_visible = lines
	_title.clip_text = false
	var line_h := int(ceil(font.get_height(px))) if font != null else px + 6
	var fits := lines == 1
	if not fits and font != null:
		fits = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x <= float(width * 2 - px)
	tooltip_text = "" if fits else text
	return line_h * lines if lines == 1 else line_h * lines - 2


func _sync_gray() -> void:
	modulate = Color(1, 1, 1, 0.42) if _flag(_view.get("used_today", false)) else Color.WHITE


func _sync_glow() -> void:
	_kill_glow()
	var on := _is_gold() and not _back_on
	_glow.visible = on
	if not on:
		return
	if _wants_fast() or not is_inside_tree():
		_glow.modulate = Color(1, 1, 1, 1)
		return
	_glow.modulate = Color(1, 1, 1, 0.35)
	_glow_tween = create_tween()
	_glow_tween.set_loops()
	_glow_tween.tween_property(_glow, "modulate:a", 1.0, GLOW_SEC)
	_glow_tween.tween_property(_glow, "modulate:a", 0.35, GLOW_SEC)


func _sync_anchors() -> void:
	_unregister_anchors()
	if _passive:
		return
	var uid := get_uid()
	if uid == "":
		return
	_reg(StringName("a.card@" + uid), self)
	if _is_gold():
		_reg(StringName("a.card.gold@" + uid), self)
	if _keep.visible:
		_reg(StringName("a.card.keep@" + uid), _keep)
	if _days.visible:
		_reg(StringName("a.card.days@" + uid), _days)


func _wants_fast() -> bool:
	return fast_anim or CardSettings.fast_anim()


func _make_copy(mode: StringName) -> CardWidget:
	var copy := CardWidget.new()
	copy._passive = true
	copy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	copy.set_size_mode(mode)
	copy.set_card(_view)
	copy.set_back(_back_on)
	_mute(copy)
	return copy


# ---------------- 牌面的字 ----------------
## 牌种条：主线；人物按来意（来当 / 来卖…）；留着的牌“留着的牌 · 消息”；其余牌种名。
func _band_text() -> String:
	if _is_gold():
		return CardText.ui("c02.band.gold")
	var typ := str(_view.get("type", ""))
	if _is_kept_zone():
		if typ != "" and typ != "kept" and CardText.has_text("c02.type." + typ):
			return CardText.ui("c02.band.kept_kind", {"kind": CardText.ui("c02.type." + typ)})
		return CardText.ui("c02.type.kept")
	var intent := str(_view.get("intent", ""))
	if typ == "person" and intent != "" and CardText.has_text("c02.intent." + intent):
		return CardText.ui("c02.intent." + intent)
	if typ != "" and CardText.has_text("c02.type." + typ):
		return CardText.ui("c02.type." + typ)
	return ""


## 副行（原型 .cs）：人物写是谁（柜上有物件时“谁 · 物件”）；消息写谁说的；夜牌“今晚的事”；其余写牌种。
func _sub_text() -> String:
	var typ := str(_view.get("type", ""))
	var person := str(_view.get("person", ""))
	if typ in PORTRAIT_TYPES and person != "":
		var who := CardText.person_name(person)
		var item := _item_name()
		if who != "" and item != "":
			return CardText.ui("c02.sub.who_item", {"who": who, "item": item})
		return who
	if typ == "news":
		var src := str(_view.get("source", ""))
		if src != "" and CardText.has_text(src):
			return CardText.ui("c02.sub.news_from", {"who": CardText.person_name(src)})
	if typ == "night" or _is_night():
		return CardText.ui("c02.sub.night")
	if typ != "" and CardText.has_text("c02.type." + typ):
		return CardText.ui("c02.type." + typ)
	return ""


func _item_name() -> String:
	var item: Variant = _view.get("item", null)
	if typeof(item) != TYPE_DICTIONARY:
		return ""
	var tpl := str((item as Dictionary).get("template", ""))
	if tpl == "" or not CardText.has_text("item." + tpl + "#name"):
		return ""
	return CardText.item_text(tpl, "name")


## 放大时的说明：牌正文的第一段（CardText 给的整段；放不下 Label 自己打省略号）。没有正文就不写。
func _brief_text() -> String:
	var def_id := str(_view.get("def", ""))
	if def_id == "" or not CardText.has_text(def_id + "#body"):
		return ""
	var body := CardText.card(def_id, "body")
	var first := body.split("\n\n", false)
	return str(first[0]) if first.size() > 0 else ""


# ---------------- 小工具 ----------------
func _on_keep() -> void:
	if _passive or not _can_keep():
		return
	action_requested.emit(get_uid(), "keep")


func _can_keep() -> bool:
	if _is_gold():
		return false
	var actions: Variant = _view.get("actions", [])
	if typeof(actions) != TYPE_ARRAY:
		return false
	for a in actions:
		if typeof(a) != TYPE_DICTIONARY:
			continue
		if str(a.get("id", "")) == "keep" and _flag(a.get("enabled", false)):
			return true
	return false


## 剩几天药丸（原型 .kdays）：留着的牌 / 能留的牌按 expires_in，今晚到期换印泥红；生活牌、牢房牌按 days_left；
## 人脉不在按 away_days。
func _days_info() -> Dictionary:
	var zone := str(_view.get("zone", ""))
	var exp := _num(_view.get("expires_in", -1), -1)
	var left := _num(_view.get("days_left", -1), -1)
	var away := _num(_view.get("away_days", 0), 0)
	var typ := str(_view.get("type", ""))
	if typ in ["life", "prison"] and zone == "hand" and left >= 0:
		return {"n": left, "key": "c02.days.left", "plate": "seal" if left <= 1 else "days_plate"}
	if exp >= 0:
		if exp <= 0:
			return {"n": exp, "key": "c02.days.tonight", "plate": "seal"}
		return {"n": exp, "key": "c02.days.left", "plate": "days_plate"}
	if away > 0:
		return {"n": away, "key": "c02.days.away", "plate": "indigo"}
	return {}


func _metrics() -> Dictionary:
	return METRICS[_mode] if METRICS.has(_mode) else METRICS[&"hand"]


func _is_gold() -> bool:
	return _flag(_view.get("gold", false))


func _is_night() -> bool:
	return str(_view.get("type", "")) == "night"


func _is_kept_zone() -> bool:
	return str(_view.get("zone", "")) == "kept"


func _is_portrait() -> bool:
	var art := str(_view.get("art", ""))
	if art.begins_with("portrait."):
		return true
	return art == "" and str(_view.get("type", "")) in PORTRAIT_TYPES


func _type_name() -> StringName:
	var typ := str(_view.get("type", ""))
	return StringName(typ) if typ != "" else &"event"


func _frame_key() -> StringName:
	if _is_gold():
		return &"frame_gold"
	if _is_kept_zone():
		return &"frame_kept"
	var key: StringName = FRAME_KEYS.get(str(_view.get("type", "")), &"umber")
	return key


func _face_keys() -> Array:
	if _is_gold():
		return FACE_KEYS["gold"]
	if _is_kept_zone():
		return FACE_KEYS["kept"]
	return FACE_KEYS.get(str(_view.get("type", "")), [&"card_face_top", &"card_face_bot"])


func _art_base() -> Vector2i:
	var base := CardArt.base_size(str(_view.get("art", "")))
	if base != Vector2i.ZERO:
		return base
	if str(_view.get("type", "")) in PORTRAIT_TYPES:
		return Vector2i(48, 64)
	return Vector2i(64, 48)


static func _band_face() -> Font:
	if _band_font == null:
		var fv := FontVariation.new()
		fv.base_font = CardTheme.font_body()
		fv.spacing_glyph = 1
		_band_font = fv
	return _band_font


static func _glow_texture() -> Texture2D:
	if _glow_tex == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 0.35))
		g.set_color(1, Color(1, 1, 1, 0.0))
		g.set_offset(1, 0.7)
		var tex := GradientTexture2D.new()
		tex.gradient = g
		tex.fill = GradientTexture2D.FILL_RADIAL
		tex.fill_from = Vector2(0.5, 0.5)
		tex.fill_to = Vector2(1.0, 0.5)
		tex.width = 64
		tex.height = 64
		_glow_tex = tex
	return _glow_tex


func _font(base: Font, italic: bool) -> Font:
	if not italic or base == null:
		return base
	if _italic.has(base):
		return _italic[base]
	var fv := FontVariation.new()
	fv.base_font = base
	fv.variation_transform = Transform2D(Vector2(1, 0), Vector2(0.28, 1), Vector2.ZERO)
	_italic[base] = fv
	return fv


func _panel(node_name: String) -> Panel:
	var p := Panel.new()
	p.name = node_name
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(p)
	return p


func _label(node_name: String) -> Label:
	var l := Label.new()
	l.name = node_name
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(l)
	return l


func _fill(node: Control, w: int, h: int) -> void:
	node.position = Vector2.ZERO
	node.size = Vector2(w, h)


func _place(node: Control, x: int, y: int, w: int, h: int) -> void:
	node.position = Vector2(x, y)
	node.size = Vector2(maxi(w, 0), maxi(h, 0))


func _mute(node: Node) -> void:
	if node is Control:
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for c in node.get_children():
		_mute(c)


func _kill_glow() -> void:
	if _glow_tween != null and is_instance_valid(_glow_tween):
		_glow_tween.kill()
	_glow_tween = null


func _reg(id: StringName, node: Control) -> void:
	CardAnchors.register(id, node)
	_anchors.append([id, node])


func _unregister_anchors() -> void:
	for row in _anchors:
		if is_instance_valid(row[1]):
			CardAnchors.unregister(row[0], row[1])
	_anchors = []


func _ui(ev_name: StringName, args: Dictionary) -> void:
	if _passive:
		return
	var b := bus
	if b == null and is_inside_tree():
		var found := get_node_or_null("/root/CardBus")
		if found is CardEventBus:
			b = found
	if b != null:
		b.ui_event.emit(ev_name, args)


func _flag(v: Variant) -> bool:
	match typeof(v):
		TYPE_BOOL:
			return v
		TYPE_INT, TYPE_FLOAT:
			return int(v) != 0
		TYPE_STRING:
			return str(v) == "true" or str(v) == "1"
		_:
			return false


func _num(v: Variant, fallback: int) -> int:
	match typeof(v):
		TYPE_INT:
			return v
		TYPE_FLOAT:
			return int(v)
		TYPE_BOOL:
			return 1 if v else 0
		TYPE_STRING:
			return int(str(v)) if str(v).is_valid_int() else fallback
		_:
			return fallback
