# C11 short: three paths, and closing or Esc resolves by default.
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const Support = preload("res://scripts/tests/cards/C11/support.gd")
const SCENE := "res://scenes/cards/ladder/ShortPanel.tscn"

var t


func _initialize() -> void:
	t = T.new(self, "C11_short")
	t.run_async(_body)


func _body() -> void:
	t.no_leaks(Support.load_fx("short_all"), "short_all")
	t.no_leaks(Support.load_fx("short_default_only"), "short_default_only")
	CardTheme.font_body()
	var bus := CardEventBus.new()
	root.add_child(bus)
	var mock := MockCardEngine.new(bus)
	mock.load_fixture(Support.path("short_all"))
	var panel := _open(mock, bus)
	panel.open({"uid": "nope"})
	panel.refresh({})
	var t0 := Time.get_ticks_usec()
	panel.open({})
	var dt := int((Time.get_ticks_usec() - t0) / 1000)
	print("C11_PERF short_open_ms=%d" % dt)
	t.ok(dt < 120, "short open %d ms" % dt)
	await t.frames(2)
	t.eq((Support.find(panel, "amount_n") as Label).text, "36", "amount")
	t.eq((Support.find(panel, "payee") as Label).text, CardText.ui("w0.mock.payee"), "payee")
	t.ok(Support.find(panel, "hdr_goods") != null, "goods path")
	t.ok(Support.find(panel, "hdr_estate") != null, "estate path")
	t.ok(Support.find(panel, "default") != null, "default path")
	t.ok(Support.find(panel, "goods_I001") != null and Support.find(panel, "goods_I002") != null, "both goods")
	t.ok(Support.find(panel, "estate_es_jewel_cabinet") != null, "held estate offered")
	t.ok(Support.find(panel, "estate_es_storeroom") == null, "mortgaged estate hidden")
	t.eq((Support.find(panel, "default_note") as Label).text, CardText.ui("c11.short.default_note"), "default note")
	t.ok(Support.find(panel, "close") != null, "close button")
	await _all_estates(mock, bus)
	var esc_closed := [false]
	panel.close_requested.connect(func(_r: Dictionary) -> void: esc_closed[0] = true)
	t.ok(Support.no_percent(panel), "no percent sign")
	var bad: PackedStringArray = t.all_text_from_cardtext(panel)
	t.ok(bad.is_empty(), "cardtext " + ",".join(bad))
	t.ok(t.anchor_ok(&"a.short.options"), "a.short.options")
	(Support.find(panel, "goods_I001") as Button).pressed.emit()
	t.eq(Support.last_cmd(mock, "short.resolve"),
			{"source": "src.coal", "by": "goods", "item": "I001"}, "goods resolve")
	t.ok(esc_closed[0], "goods path closes")
	panel.open({})
	await t.frames(1)
	(Support.find(panel, "estate_es_jewel_cabinet") as Button).pressed.emit()
	t.eq(Support.last_cmd(mock, "short.resolve"),
			{"source": "src.coal", "by": "estate", "estate": "es.jewel_cabinet"}, "estate resolve")
	panel.open({})
	await t.frames(1)
	(Support.find(panel, "default") as Button).pressed.emit()
	t.eq(Support.last_cmd(mock, "short.resolve"), {"source": "src.coal", "by": "default"}, "default resolve")
	var auto := _open(mock, bus)
	auto.open({})
	await t.frames(1)
	var n := mock.sent.size()
	t.ok(auto.autoplay_step(), "autoplay takes goods")
	t.eq(Support.last_cmd(mock, "short.resolve"),
			{"source": "src.coal", "by": "goods", "item": "I001"}, "autoplay first good")
	t.ok(mock.sent.size() == n + 1, "autoplay one command")
	t.ok(not auto.autoplay_step(), "autoplay stops")
	var mock2 := MockCardEngine.new(bus)
	mock2.load_fixture(Support.path("short_default_only"))
	var only := _open(mock2, bus)
	only.open({})
	await t.frames(2)
	t.ok(Support.find(only, "hdr_goods") == null and Support.find(only, "hdr_estate") == null, "only default")
	t.ok(Support.find(only, "default") != null, "default remains")
	t.eq((Support.find(only, "amount_n") as Label).text, "8", "default amount")
	var hit := [false]
	only.close_requested.connect(func(_r: Dictionary) -> void: hit[0] = true)
	only._unhandled_input(Support.key(KEY_ESCAPE))
	t.ok(hit[0], "esc accepts the default")
	t.eq(Support.last_cmd(mock2, "short.resolve"), {"source": "src.rent", "by": "default"}, "esc default")
	var typed := _open(mock2, bus)
	typed.open({})
	await t.frames(1)
	var typed_closed := [false]
	typed.close_requested.connect(func(_r: Dictionary) -> void: typed_closed[0] = true)
	typed._unhandled_input(Support.key(KEY_ENTER))
	t.ok(typed_closed[0], "enter confirms default")
	t.eq(Support.last_cmd(mock2, "short.resolve"), {"source": "src.rent", "by": "default"}, "enter default")
	var bad2: PackedStringArray = t.all_text_from_cardtext(only)
	t.ok(bad2.is_empty(), "default cardtext " + ",".join(bad2))
	t.ok(Support.no_percent(only), "default no percent")
	var auto2 := _open(mock2, bus)
	auto2.open({})
	await t.frames(1)
	t.ok(auto2.autoplay_step(), "autoplay default")
	t.eq(Support.last_cmd(mock2, "short.resolve"), {"source": "src.rent", "by": "default"}, "autoplay default args")
	t.ok(not auto2.autoplay_step(), "default autoplay stops")
	for n2 in [panel, auto, only, typed, auto2, bus]:
		n2.queue_free()
	await t.frames(3)


## b26: with all five estates held the choices wrap; every button and 关上 stay inside OVERLAY_MAX.
func _all_estates(mock: MockCardEngine, bus: CardEventBus) -> void:
	var five: Array = []
	for id in ["es.jewel_cabinet", "es.storeroom", "es.counter", "es.old_house", "es.shopfront"]:
		five.append({"id": id, "status": "held", "money": 100, "interest_money": 5})
	var wide := _open(mock, bus)
	wide.open({"amount": 120, "source": "src.coal", "payee": "", "options": ["estate", "default"], "goods": [],
		"estates": five})
	await t.frames(3)
	var lim := CardLayout.OVERLAY_MAX
	for id in ["es_jewel_cabinet", "es_storeroom", "es_counter", "es_old_house", "es_shopfront"]:
		var b := Support.find(wide, "estate_" + id) as Control
		t.ok(b != null and lim.encloses(b.get_global_rect()), "b26 estate_%s on screen %s" % [id,
			b.get_global_rect() if b != null else Rect2()])
	var close := Support.find(wide, "close") as Control
	t.ok(lim.encloses(close.get_global_rect()), "b26 close inside OVERLAY_MAX %s" % close.get_global_rect())
	wide.free()


func _open(mock: MockCardEngine, bus: CardEventBus) -> CardShortPanel:
	var panel := (load(SCENE) as PackedScene).instantiate() as CardShortPanel
	panel.bind(mock, bus)
	root.add_child(panel)
	return panel
