# 英雄头像和最多三张人脉牌片。主人 C02。合同 §7.11.6。实现 CardHeroApi。
# 头像拖出去是 {"kind": "self"}；人脉牌片拖 {"kind": "card", "uid", "zone": "contacts"}。
# 锚点：a.hero、a.contacts。点头像或人脉发 person_pressed。
# 换皮（10-22，照网页原型 .pcard，换皮 SPEC §9）：
#   英雄框：径向渐变 hero_top→hero_bot、3px hero_edge 边、拱顶（上圆角 = 半宽）、外影；脸是 72×66 的椭圆，
#   头像 ×3 往上提 8 只露脸，2px gold_hi 圈；名字毛笔金字；一行“眼2 口1 门1 胆1”（标签 text_2、数字 hud_ink）；
#   用过了：脸变灰暗，斜贴一条红签“今天用过了”。悬停上浮 4px（点击区往下补 4px，不闪）。
#   人脉：不再用 CardWidget 小牌，改成深色牌片（mate_top→mate_bot、2px line 边、圆角 8）：头像 ×1 贴顶、
#   名字毛笔金字、两行属性（标签 + 数字），悬停提示写全名；用过了 / 不在 N 天同英雄的红签（红签画在牌片外面一层，
#   不跟着“不在”的 42% 透明变淡）。空着的格子补到 3 个：虚线框、45% 透明、“人脉”。
class_name CardHeroBar
extends CardHeroApi

const GradBox = preload("res://scripts/cards/ui/common/grad_box.gd")
const PORTRAIT_ID := "portrait.ruhua"
const ATTRS: Array[String] = ["eye", "tongue", "pull", "nerve"]
const FACE := Rect2(18, 9, 72, 66)
const FACE_K := 3
const LIFT := 4.0
const LIFT_SEC := 0.15
const MATE_FACE_H := 44

var bus: CardEventBus = null

var _hero: HeroFace
var _plate: Control
var _shadow: Panel
var _face: Disc
var _name: Label
var _attr_labels: Dictionary = {}
var _attr_values: Dictionary = {}
var _used: Label
var _uid: String = ""
var _pet: Panel
var _pet_label: Label
var _lift_tween: Tween = null


class HeroFace:
	extends Control
	var bar: CardHeroBar

	func _get_drag_data(at_position: Vector2) -> Variant:
		if bar == null:
			return null
		bar._ghost(self, at_position)
		return bar._hero_drag()

	func _gui_input(event: InputEvent) -> void:
		if bar == null:
			return
		if event is InputEventMouseButton:
			var mb := event as InputEventMouseButton
			if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
				bar.person_pressed.emit(bar._uid)
				accept_event()


## 椭圆：底色、头像（按 UV 贴进椭圆，不用裁切节点）、外圈；空格子用 dashed 画虚线框。
class Disc:
	extends Control
	# @export：拖拽影子 duplicate() 时这些值要跟着复制。
	@export var fill := Color.TRANSPARENT
	@export var ring := Color.TRANSPARENT
	@export var ring_w := 0.0
	@export var tex: Texture2D = null
	@export var tex_rect := Rect2()

	func _draw() -> void:
		var c := size * 0.5
		var pts := PackedVector2Array()
		var uvs := PackedVector2Array()
		for i in 48:
			var a := TAU * float(i) / 48.0
			var p := c + Vector2(cos(a) * (c.x - 0.5), sin(a) * (c.y - 0.5))
			pts.append(p)
			if tex_rect.size.x > 0.0 and tex_rect.size.y > 0.0:
				uvs.append((p - tex_rect.position) / tex_rect.size)
		if fill.a > 0.0:
			draw_colored_polygon(pts, fill)
		if tex != null and uvs.size() == pts.size():
			draw_colored_polygon(pts, Color.WHITE, uvs, tex)
		if ring_w > 0.0:
			var loop := pts.duplicate()
			loop.append(pts[0])
			draw_polyline(loop, ring, ring_w, true)


## 人脉牌片。
class MatePlate:
	extends Control
	signal pressed(uid: String)
	var bar: CardHeroBar
	var uid: String = ""

	func _get_drag_data(at_position: Vector2) -> Variant:
		if bar == null or uid == "":
			return null
		bar._ghost(self, at_position)
		return bar._mate_drag(uid)

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton:
			var mb := event as InputEventMouseButton
			if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
				pressed.emit(uid)
				accept_event()


## 空着的人脉格：虚线圆角框。
class EmptySlot:
	extends Control
	var edge := Color.WHITE

	func _draw() -> void:
		var r := Rect2(Vector2(1, 1), size - Vector2(2, 2))
		var lines: Array = [[r.position + Vector2(8, 0), Vector2(r.end.x - 8, r.position.y)],
			[Vector2(r.end.x, r.position.y + 8), Vector2(r.end.x, r.end.y - 8)],
			[Vector2(r.end.x - 8, r.end.y), Vector2(r.position.x + 8, r.end.y)],
			[Vector2(r.position.x, r.end.y - 8), Vector2(r.position.x, r.position.y + 8)]]
		for seg in lines:
			draw_dashed_line(seg[0], seg[1], edge, 2.0, 5.0)
		var corners: Array[Vector2] = [Vector2(r.position.x + 8, r.position.y + 8), Vector2(r.end.x - 8, r.position.y + 8),
			Vector2(r.end.x - 8, r.end.y - 8), Vector2(r.position.x + 8, r.end.y - 8)]
		for k in corners.size():
			var start := PI + float(k) * PI * 0.5
			draw_arc(corners[k], 8.0, start, start + PI * 0.5, 6, edge, 2.0, true)


func _ready() -> void:
	_build()


func refresh(view: Dictionary) -> void:
	_build()
	var self_view: Dictionary = view.get("self", {}) if typeof(view.get("self", {})) == TYPE_DICTIONARY else {}
	_uid = str(self_view.get("uid", ""))
	_name.text = CardText.person_name("ruhua")
	_used.text = CardText.ui("c02.hero.used")
	var attrs: Dictionary = self_view.get("attrs", {}) if typeof(self_view.get("attrs", {})) == TYPE_DICTIONARY else {}
	for attr in ATTRS:
		(_attr_labels[attr] as Label).text = CardText.ui("c02.attr." + attr)
		(_attr_values[attr] as Label).text = str(int(attrs.get(attr, 0)))
	_hero.tooltip_text = _attr_tip(_name.text, attrs)
	_layout_attrs()
	var used := bool(self_view.get("used_today", false))
	_used.visible = used
	_place_tag(_used, Vector2(FACE.get_center().x, FACE.end.y - 6.0))
	_apply_portrait(used)
	_rebuild_contacts(view)
	var pet: Dictionary = view.get("pet", {}) if typeof(view.get("pet", {})) == TYPE_DICTIONARY else {}
	var show_pet := bool(pet.get("show", false))
	_pet.visible = show_pet
	if show_pet:
		var key := "k18.pet.lost" if bool(pet.get("lost", false)) else "k18.pet.home"
		_pet_label.text = CardText.ui(key)
	else:
		_pet_label.text = ""


func _build() -> void:
	if _hero != null:
		return
	size = Vector2(1280, 720)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hero = HeroFace.new()
	_hero.name = "Hero"
	_hero.bar = self
	_hero.position = CardLayout.HERO.position
	_hero.size = CardLayout.HERO.size
	_hero.mouse_filter = Control.MOUSE_FILTER_STOP
	_hero.mouse_entered.connect(_lift.bind(true))
	_hero.mouse_exited.connect(_lift.bind(false))
	add_child(_hero)
	var w := CardLayout.HERO.size.x
	var h := CardLayout.HERO.size.y
	_shadow = Panel.new()
	_shadow.name = "Shadow"
	_shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shadow.size = Vector2(w, h)
	var sh := StyleBoxFlat.new()
	sh.bg_color = Color.TRANSPARENT
	sh.corner_radius_top_left = int(w / 2.0)
	sh.corner_radius_top_right = int(w / 2.0)
	sh.corner_radius_bottom_left = 12
	sh.corner_radius_bottom_right = 12
	sh.corner_detail = 12
	sh.shadow_color = CardTheme.color(&"card_shadow")
	sh.shadow_size = 14
	sh.shadow_offset = Vector2(0, 6)
	_shadow.add_theme_stylebox_override("panel", sh)
	_hero.add_child(_shadow)
	_plate = GradBox.new()
	_plate.name = "Plate"
	_plate.size = Vector2(w, h)
	_plate.set_colors(&"hero_top", &"hero_bot")
	_plate.set_mode(GradBox.RADIAL, Vector2(0.5, 0.3))
	_plate.set_border(3.0, &"hero_edge")
	_plate.set_radius(12.0, w / 2.0, 12.0)
	_hero.add_child(_plate)
	_face = Disc.new()
	_face.name = "Portrait"
	_face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_face.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_face.position = FACE.position
	_face.size = FACE.size
	_face.fill = CardTheme.color(&"wood_1")
	_hero.add_child(_face)
	# 金圈另画一层：用过了时只有脸变灰，圈不变。
	var ring := Disc.new()
	ring.name = "FaceRing"
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ring.position = FACE.position
	ring.size = FACE.size
	ring.ring = CardTheme.color(&"gold_hi")
	ring.ring_w = 2.0
	_hero.add_child(ring)
	_name = _label(_hero, "Name", Vector2(4, FACE.end.y + 2), Vector2(w - 8, 26), 18)
	_name.add_theme_font_override("font", CardTheme.font_title())
	_name.add_theme_color_override("font_color", CardTheme.color(&"gold_hi"))
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	for attr in ATTRS:
		var lab := _label(_hero, "Attr_" + attr, Vector2.ZERO, Vector2(16, 22), 14)
		lab.add_theme_color_override("font_color", CardTheme.color(&"text_2"))
		_attr_labels[attr] = lab
		_attr_values[attr] = _label(_hero, "Val_" + attr, Vector2.ZERO, Vector2(12, 22), 14)
	_used = _tag(_hero, "Used")
	var contacts := Control.new()
	contacts.name = "ContactRow"
	contacts.position = CardLayout.CONTACT_MINIS[0].position
	var last: Rect2 = CardLayout.CONTACT_MINIS[CardLayout.CONTACT_MINIS.size() - 1]
	contacts.size = last.end - contacts.position
	contacts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(contacts)
	_pet = Panel.new()
	_pet.name = "PetPlaque"
	_pet.position = CardLayout.PET.position
	_pet.size = CardLayout.PET.size
	_pet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pet.visible = false
	var pet_box := StyleBoxFlat.new()
	pet_box.bg_color = CardTheme.mix(&"mate_top", &"mate_bot")
	pet_box.border_color = CardTheme.color(&"line")
	pet_box.set_border_width_all(2)
	pet_box.set_corner_radius_all(8)
	pet_box.shadow_color = CardTheme.color(&"card_shadow")
	pet_box.shadow_size = 8
	pet_box.shadow_offset = Vector2(0, 3)
	_pet.add_theme_stylebox_override("panel", pet_box)
	add_child(_pet)
	_pet_label = _label(_pet, "PetText", Vector2(10, 8), Vector2(200, 24), 14)
	_pet_label.text = ""
	CardAnchors.register(&"a.hero", _hero, _hero_rect)
	CardAnchors.register(&"a.contacts", contacts)
	CardAnchors.register(&"a.pet", _pet)


## 头像 ×3（144×192）往上提 8，椭圆只露脸；用过了变灰变暗（灰度着色器，不写颜色）。
func _apply_portrait(used: bool) -> void:
	var base := CardArt.base_size(PORTRAIT_ID)
	if base == Vector2i.ZERO:
		base = Vector2i(48, 64)
	var tex: Texture2D = null
	if not CardArt.is_missing(PORTRAIT_ID):
		tex = CardArt.texture(PORTRAIT_ID)
	var aw := float(base.x * FACE_K)
	var ah := float(base.y * FACE_K)
	_face.tex = tex
	_face.tex_rect = Rect2(Vector2((FACE.size.x - aw) * 0.5, -8.0), Vector2(aw, ah))
	_face.material = CardWidget.gray_material(0.7) if used else null
	_face.queue_redraw()


## 一行“眼2 口1 门1 胆1”：按字宽排、整行居中。
func _layout_attrs() -> void:
	var font := CardTheme.font_body()
	var widths: Array = []
	var total := 0.0
	for attr in ATTRS:
		var lw := font.get_string_size((_attr_labels[attr] as Label).text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
		var vw := font.get_string_size((_attr_values[attr] as Label).text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
		widths.append([lw, vw])
		total += lw + vw
	var gap := 3.0
	total += gap * float(ATTRS.size() - 1)
	var x := (CardLayout.HERO.size.x - total) * 0.5
	var y := FACE.end.y + 30.0
	for i in ATTRS.size():
		var lab := _attr_labels[ATTRS[i]] as Label
		var val := _attr_values[ATTRS[i]] as Label
		lab.position = Vector2(roundf(x), y)
		lab.size = Vector2(ceilf(widths[i][0]), 22)
		x += float(widths[i][0])
		val.position = Vector2(roundf(x), y)
		val.size = Vector2(ceilf(widths[i][1]), 22)
		x += float(widths[i][1]) + gap


func _rebuild_contacts(view: Dictionary) -> void:
	var old: Array = []
	for child in get_children():
		var child_name := str(child.name)
		for prefix in ["Contact", "ContactState", "ContactEmpty"]:
			if child_name.begins_with(prefix) and child_name.trim_prefix(prefix).is_valid_int():
				old.append(child)
	for child in old:
		remove_child(child)
		child.queue_free()
	var rows: Array = view.get("contacts", []) if typeof(view.get("contacts", [])) == TYPE_ARRAY else []
	var used_slots := 0
	for i in mini(CardLayout.CONTACT_MINIS.size(), rows.size()):
		if typeof(rows[i]) != TYPE_DICTIONARY:
			continue
		var card: Dictionary = (rows[i] as Dictionary).duplicate(true)
		_add_mate(i, card)
		used_slots = i + 1
	for i in range(used_slots, CardLayout.CONTACT_MINIS.size()):
		_add_empty(i)


func _add_mate(i: int, card: Dictionary) -> void:
	var r: Rect2 = CardLayout.CONTACT_MINIS[i]
	var plate := MatePlate.new()
	plate.name = "Contact%d" % i
	plate.bar = self
	plate.uid = str(card.get("uid", ""))
	plate.position = r.position
	plate.size = r.size
	plate.mouse_filter = Control.MOUSE_FILTER_STOP
	var shadow := Panel.new()
	shadow.name = "Shadow"
	shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shadow.size = r.size
	var sh := StyleBoxFlat.new()
	sh.bg_color = Color.TRANSPARENT
	sh.set_corner_radius_all(8)
	sh.shadow_color = CardTheme.color(&"card_shadow")
	sh.shadow_size = 12
	sh.shadow_offset = Vector2(0, 5)
	shadow.add_theme_stylebox_override("panel", sh)
	plate.add_child(shadow)
	var bg = GradBox.new()
	bg.name = "Plate"
	bg.size = r.size
	bg.set_colors(&"mate_top", &"mate_bot")
	bg.set_border(2.0, &"line")
	bg.set_radius(8.0)
	plate.add_child(bg)
	var box := Control.new()
	box.name = "FaceBox"
	box.clip_contents = true
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.position = Vector2(2, 2)
	box.size = Vector2(r.size.x - 4, MATE_FACE_H)
	plate.add_child(box)
	var art := str(card.get("art", ""))
	if art == "":
		art = "portrait." + str(card.get("person", ""))
	var base := CardArt.base_size(art)
	if base == Vector2i.ZERO:
		base = Vector2i(48, 64)
	var face := TextureRect.new()
	face.name = "Portrait"
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	face.stretch_mode = TextureRect.STRETCH_SCALE
	face.texture = CardArt.texture(art) if not CardArt.is_missing(art) else null
	face.size = Vector2(base)
	face.position = Vector2((box.size.x - float(base.x)) * 0.5, 0)
	var away := int(card.get("away_days", 0))
	var used := bool(card.get("used_today", false))
	if away > 0 or used:
		face.material = CardWidget.gray_material(0.7)
	box.add_child(face)
	var rule := ColorRect.new()
	rule.name = "Rule"
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rule.color = CardTheme.color(&"line")
	rule.position = Vector2(2, 2 + MATE_FACE_H)
	rule.size = Vector2(r.size.x - 4, 1)
	plate.add_child(rule)
	var person := str(card.get("person", ""))
	var who := CardText.person_name(person) if person != "" else ""
	var name_l := _label(plate, "Name", Vector2(2, MATE_FACE_H + 2), Vector2(r.size.x - 4, 20), 15)
	name_l.add_theme_font_override("font", CardTheme.font_title())
	name_l.add_theme_color_override("font_color", CardTheme.color(&"gold_hi"))
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_l.clip_text = true
	name_l.text = who
	var attrs: Dictionary = card.get("attrs", {}) if typeof(card.get("attrs", {})) == TYPE_DICTIONARY else {}
	var col := (r.size.x - 8.0) / float(ATTRS.size())
	for k in ATTRS.size():
		var attr := ATTRS[k]
		var lab := _label(plate, "Attr_" + attr, Vector2(4.0 + col * k, MATE_FACE_H + 20), Vector2(col, 18), 14)
		lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lab.add_theme_color_override("font_color", CardTheme.color(&"text_2"))
		lab.text = CardText.ui("c02.attr." + attr)
		var val := _label(plate, "Val_" + attr, Vector2(4.0 + col * k, MATE_FACE_H + 36), Vector2(col, 18), 14)
		val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		val.text = str(int(attrs.get(attr, 0)))
	plate.tooltip_text = _attr_tip(who, attrs)
	var tint := Color.WHITE
	if bool(card.get("apprentice", false)):
		tint = CardTheme.color(&"jade")
	if away > 0:
		tint.a = 0.42
	plate.modulate = tint
	plate.pressed.connect(func(uid: String) -> void: person_pressed.emit(uid))
	add_child(plate)
	var tag := _tag(self, "ContactState%d" % i)
	tag.visible = away > 0 or used
	if away > 0:
		tag.text = CardText.ui("c02.contact.away", {"n": away})
	elif used:
		tag.text = CardText.ui("c02.hero.used")
	_place_tag(tag, r.position + Vector2(r.size.x * 0.5, MATE_FACE_H - 4.0))


func _add_empty(i: int) -> void:
	var r: Rect2 = CardLayout.CONTACT_MINIS[i]
	var slot := EmptySlot.new()
	slot.name = "ContactEmpty%d" % i
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.position = r.position
	slot.size = r.size
	slot.edge = CardTheme.color(&"line")
	slot.modulate.a = 0.45
	var lab := _label(slot, "Text", Vector2.ZERO, r.size, 14)
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lab.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lab.add_theme_color_override("font_color", CardTheme.color(&"text_3"))
	lab.text = CardText.ui("c02.contact.empty")
	add_child(slot)


## 红签（原型 .pstate）：印泥红底、白字、斜 -8 度。
func _tag(parent: Control, node_name: String) -> Label:
	var tag := Label.new()
	tag.name = node_name
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tag.add_theme_stylebox_override("normal", CardTheme.pill_style(&"pstate_bg", &"", 3, 6.0, 1.0))
	tag.add_theme_font_override("font", CardTheme.font_body())
	tag.add_theme_font_size_override("font_size", 14)
	tag.add_theme_color_override("font_color", CardTheme.color(&"btn_warn_ink"))
	tag.rotation_degrees = -8.0
	tag.visible = false
	parent.add_child(tag)
	return tag


func _place_tag(tag: Label, center: Vector2) -> void:
	var s := tag.get_minimum_size()
	tag.size = s
	tag.pivot_offset = s * 0.5
	tag.position = center - s * 0.5


func _attr_tip(who: String, attrs: Dictionary) -> String:
	var args := {}
	for attr in ATTRS:
		args[attr] = int(attrs.get(attr, 0))
	var line := CardText.ui("c02.hero.attr_tip", args)
	return line if who == "" else who + "\n" + line


## 悬停上浮 4px：整块往上挪，点击区往下补 4px，底边不动，鼠标停在底边也不会来回闪。
func _lift(on: bool) -> void:
	var base := CardLayout.HERO
	var pos := base.position - Vector2(0, LIFT if on else 0.0)
	var sz := base.size + Vector2(0, LIFT if on else 0.0)
	if _lift_tween != null and _lift_tween.is_valid():
		_lift_tween.kill()
	if CardSettings.fast_anim() or not is_inside_tree():
		_hero.position = pos
		_hero.size = sz
		return
	_lift_tween = create_tween().set_parallel(true)
	_lift_tween.tween_property(_hero, "position", pos, LIFT_SEC)
	_lift_tween.tween_property(_hero, "size", sz, LIFT_SEC)


func _hero_rect() -> Rect2:
	if _hero == null or not _hero.is_inside_tree():
		return Rect2()
	return Rect2(_hero.get_global_transform_with_canvas().origin, CardLayout.HERO.size)


## 拖起来的影子（原型 .pcard.ghost）：同样的牌片放大 1.08，跟着鼠标抓住的那一点走。
func _ghost(source: Control, grab: Vector2) -> void:
	if not source.is_inside_tree() or not source.get_viewport().gui_is_dragging():
		return
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var copy := source.duplicate(Node.DUPLICATE_USE_INSTANTIATION) as Control
	copy.set_script(null)
	copy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	copy.position = -grab
	copy.pivot_offset = grab
	copy.scale = Vector2(1.08, 1.08)
	copy.modulate.a = 0.94
	holder.add_child(copy)
	source.set_drag_preview(holder)


func _hero_drag() -> Dictionary:
	_emit_drag(_uid, "self")
	return {"kind": "self"}


func _mate_drag(uid: String) -> Dictionary:
	_emit_drag(uid, "contacts")
	return {"kind": "card", "uid": uid, "zone": "contacts"}


func _emit_drag(uid: String, zone: String) -> void:
	var event_bus := bus
	if event_bus == null and is_inside_tree():
		event_bus = get_node_or_null("/root/CardBus") as CardEventBus
	if event_bus != null:
		event_bus.ui_event.emit(&"card_drag_started", {"uid": uid, "zone": zone})


func _label(parent: Control, node_name: String, at: Vector2, sz: Vector2, px: int) -> Label:
	var lab := Label.new()
	lab.name = node_name
	lab.position = at
	lab.size = sz
	lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lab.add_theme_font_override("font", CardTheme.font_body())
	lab.add_theme_font_size_override("font_size", px)
	lab.add_theme_color_override("font_color", CardTheme.color(&"hud_ink"))
	parent.add_child(lab)
	return lab
