# 英雄头像与人脉小牌：矩形、拖拽、用过了、不在、点了 person_pressed。
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const S = preload("res://scripts/tests/cards/C02/support.gd")


func _initialize() -> void:
	var t := T.new(self, "C02_hero")
	t.run_async(_body.bind(t))


func _body(t) -> void:
	S.setup_db()
	var bus := CardEventBus.new()
	root.add_child(bus)
	var spy = t.spy(bus)
	var bar: CardHeroBar = load("res://scenes/cards/card/HeroBar.tscn").instantiate()
	bar.bus = bus
	root.add_child(bar)
	var pressed: Array = []
	bar.person_pressed.connect(func(uid: String) -> void: pressed.append(uid))
	await t.frames(1)
	var doc := S.read_json("res://scripts/tests/cards/C02/fixtures/hero_states.json")
	t.no_leaks(doc, "hero fixture")
	bar.refresh(doc)
	await t.frames(1)
	var hero := bar.get_node("Hero") as Control
	t.eq(hero.get_global_rect(), CardLayout.HERO, "hero rect")
	# 换皮（照网页原型 .pcard.hero）：拱顶金边框、椭圆脸（头像 ×3 往上提 8 只露脸）、一行属性、用过了是脸变灰 + 红签。
	# 原来是直角九宫格框、头像上半截 ×2、四行属性、整块 42% 透明。
	var plate := hero.get_node("Plate") as Control
	t.eq(plate.size, CardLayout.HERO.size, "hero plate fills the hero rect")
	var portrait := hero.get_node("Portrait") as Control
	t.eq(portrait.texture_filter, CanvasItem.TEXTURE_FILTER_NEAREST, "portrait nearest")
	var tex_rect: Rect2 = portrait.get("tex_rect")
	t.eq(tex_rect.size, Vector2(144, 192), "portrait x3 (integer scale)")
	t.ok(tex_rect.position.y < 0.0, "portrait lifted so only the face shows")
	t.ok((hero.get_node("Used") as Label).visible, "used stamp")
	t.eq((hero.get_node("Used") as Label).text, CardText.ui("c02.hero.used"), "used text")
	t.ok(portrait.material != null, "used greys the face")
	t.ok(is_equal_approx((hero.get_node("FaceRing") as CanvasItem).modulate.a, 1.0), "gold ring stays")
	t.eq((hero.get_node("Val_eye") as Label).text, "3", "eye points")
	t.eq((hero.get_node("Val_nerve") as Label).text, "1", "nerve points")
	t.eq((hero.get_node("Attr_eye") as Label).text, CardText.ui("c02.attr.eye"), "short attr label")
	var row_y := (hero.get_node("Attr_eye") as Label).position.y
	for attr in ["tongue", "pull", "nerve"]:
		t.ok(is_equal_approx((hero.get_node("Attr_" + attr) as Label).position.y, row_y), "attrs in one row " + attr)
	var last := hero.get_node("Val_nerve") as Label
	t.ok(last.position.x + last.size.x <= CardLayout.HERO.size.x - 3.0, "attr row fits inside the frame")
	for i in 3:
		var plate_i := bar.get_node("Contact%d" % i) as Control
		t.eq(plate_i.get_global_rect(), CardLayout.CONTACT_MINIS[i], "contact rect %d" % i)
		t.ok(plate_i.tooltip_text != "", "contact %d tooltip names the attrs" % i)
	var away := bar.get_node("Contact2") as Control
	var tag := bar.get_node("ContactState2") as Label
	t.ok(tag.visible, "away tag")
	t.eq(tag.text, CardText.ui("c02.contact.away", {"n": 3}), "away days")
	t.ok(away.modulate.a < 0.95, "away is dim")
	t.ok(is_equal_approx(tag.modulate.a, 1.0), "away tag is not dimmed")
	t.ok((bar.get_node("Contact0") as Control).modulate.is_equal_approx(Color.WHITE), "present contact")
	t.ok(not (bar.get_node("ContactState0") as Label).visible, "present contact has no tag")
	var two: Dictionary = doc.duplicate(true)
	(two["contacts"] as Array).resize(1)
	bar.refresh(two)
	await t.frames(1)
	t.ok(bar.get_node_or_null("Contact1") == null, "one contact")
	for i in [1, 2]:
		var empty := bar.get_node_or_null("ContactEmpty%d" % i) as Control
		t.ok(empty != null and empty.get_global_rect() == CardLayout.CONTACT_MINIS[i], "empty slot %d" % i)
		t.eq((empty.get_node("Text") as Label).text, CardText.ui("c02.contact.empty"), "empty slot text %d" % i)
	bar.refresh(doc)
	await t.frames(1)
	t.ok(t.anchor_ok(&"a.hero"), "a.hero")
	t.ok(t.anchor_ok(&"a.contacts"), "a.contacts")
	var bad: PackedStringArray = t.all_text_from_cardtext(bar)
	t.ok(bad.is_empty(), "hero text " + " ".join(bad))
	t.ok(not S.has_pct(bar), "no pct")
	var data: Dictionary = hero._get_drag_data(Vector2(8, 8))
	t.eq(data, {"kind": "self"}, "self drag")
	t.eq(_ui(spy, &"card_drag_started"), {"uid": "self1", "zone": "self"}, "self drag event")
	var contact := bar.get_node("Contact1") as Control
	spy.clear()
	var card_drag: Dictionary = contact._get_drag_data(Vector2(4, 4))
	t.eq(card_drag, {"kind": "card", "uid": "c2", "zone": "contacts"}, "contact drag")
	t.eq(_ui(spy, &"card_drag_started"), {"uid": "c2", "zone": "contacts"}, "contact drag event")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	hero._gui_input(click)
	contact._gui_input(click)
	t.eq(pressed, ["self1", "c2"], "person_pressed")
	bar.queue_free()
	bus.free()
	await t.frames(1)


func _ui(spy, ev_name: StringName) -> Dictionary:
	for row in spy.ui_events():
		if row[0] == ev_name:
			return row[1]
	return {}
