# C10：档案索引、碎片顺序、缺口无字、一年后、补齐章、红点、键盘、autoplay。
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const S = preload("res://scripts/tests/cards/C10/support.gd")
const Kit = preload("res://scripts/cards/ui/slots/drawer_kit.gd")
const FX := "res://scripts/tests/cards/C10/fixtures/dossier_mixed.json"
const SCENE := "res://scenes/cards/dossier/DossierBook.tscn"

func _initialize() -> void:
	var t := T.new(self, "C10_dossier")
	t.run_async(_body.bind(t))


func _body(t) -> void:
	for path in ["res://scripts/cards/ui/dossier/dossier_book.gd", "res://scripts/cards/ui/dossier/help_panel.gd",
			"res://scripts/cards/ui/dossier/rules_view.gd", "res://scripts/cards/ui/dossier/tear_edge.gd",
			"res://scripts/cards/ui/dossier/seal_mark.gd"]:
		S.source_ok(t, path)
	var bus := CardEventBus.new()
	root.add_child(bus)
	var mock := MockCardEngine.new(bus)
	mock.load_fixture(FX)
	S.leaks_fixture(t, FX)
	t.no_leaks(mock.view(), "view")
	t.no_leaks(mock.query(&"dossier", {}), "dossier")
	t.no_leaks(mock.query(&"firsts", {}), "firsts")
	var p: CardDossierBook = load(SCENE).instantiate()
	p.bind(mock, bus)
	root.add_child(p)
	var t0 := Time.get_ticks_usec()
	p.open({"uid": "c0002"})
	var dt := Time.get_ticks_usec() - t0
	print("C10 open_us " + str(dt))
	t.ok(dt < 2000000, "dossier open under 2s")
	p.open({"person": 4, "extra": true})
	p.refresh(mock.view())
	await t.frames(2)
	_pages(t, p)
	# b21: a drawer_l panel, laid out inside the left drawer frame (368x630 under the title row), not a centred book.
	# QA 10-25: under the unified title row (drawer_host.HEAD_H 52), i.e. the shared drawer-kit content rect.
	t.eq(Rect2(p.position, p.size), Kit.rect("l"), "b21 dossier inside DRAWER_L")
	var page_node := p.find_child("Page", true, false) as Control
	t.ok(CardLayout.DRAWER_L.encloses(page_node.get_global_rect()), "b21 page inside the left drawer")
	# b49: the active tab is gold with dark ink, the other one wood with light ink.
	var on_tab := S.find_meta(p, &"c10_tab", "people") as Button
	var off_tab := S.find_meta(p, &"c10_tab", "rules") as Button
	t.ok(on_tab.get_theme_color("font_color") == CardTheme.color(&"btn_primary_ink"), "b49 active tab dark ink")
	t.ok(off_tab.get_theme_color("font_color") == CardTheme.color(&"hud_ink"), "b49 other tab light ink")
	var on_box := on_tab.get_theme_stylebox("normal") as StyleBoxFlat
	t.ok(on_box != null and on_box.bg_color.get_luminance() > 0.45, "b49 active tab has a bright fill")
	t.eq(t.all_text_from_cardtext(p), PackedStringArray(), "dossier text from CardText")
	t.ok(not S.has_percent(p), "dossier has no percent")
	t.ok(t.anchor_ok(&"a.dossier.page"), "anchor page")
	t.ok(t.anchor_ok(&"a.dossier.gap"), "anchor gap")
	t.ok(t.anchor_ok(&"a.dossier.rules_tab"), "anchor rules tab")
	var closed: Array = []
	p.close_requested.connect(func(r: Dictionary) -> void: closed.append(r))
	await S.tap(t.tree, KEY_RIGHT)
	var page := p.find_child("Page", true, false)
	t.eq(str(page.get_meta(&"c10_show")), "wangshan", "right opens complete page")
	t.ok(S.find_meta(p, &"c10_seal", "1") != null, "complete page has a seal")
	await S.tap(t.tree, KEY_RIGHT)
	t.eq(str(page.get_meta(&"c10_show")), "linsao", "right opens year page")
	var year := S.find_meta(p, &"c10_year", "1939")
	t.ok(year != null and (year as Label).text == "1939", "year chip shows 1939")
	var kind := S.find_meta(p, &"c10_kind", "year_after")
	t.eq((kind as Label).text, CardText.ui("c10.kind.year_after"), "year-after kind caption")
	await S.tap(t.tree, KEY_LEFT)
	t.eq(str(page.get_meta(&"c10_show")), "wangshan", "left goes back one page")
	await S.tap(t.tree, KEY_TAB)
	t.ok(p.find_child("Rules", true, false).visible, "tab shows rules")
	t.ok(not page.visible, "people page hides on rules tab")
	await S.tap(t.tree, KEY_ESCAPE)
	t.eq(closed.size(), 1, "esc requests close once")
	t.eq(closed[0], {}, "esc payload is empty")
	t.ok(p.autoplay_step(), "autoplay first call closes")
	t.eq(closed.size(), 2, "autoplay also requests close")
	t.eq(closed[1], {}, "autoplay payload is empty")
	t.ok(not p.autoplay_step(), "autoplay second call is false")
	p.queue_free()
	bus.queue_free()
	await t.frames(2)


func _pages(t, p: Node) -> void:
	var index := p.find_child("Index", true, false)
	var people: Array = []
	for c in index.get_children():
		if c is Button and c.has_meta(&"c10_person"):
			people.append(str(c.get_meta(&"c10_person")))
	t.eq(people, ["brother", "wangshan", "linsao"], "index lists only people in the view")
	var page := p.find_child("Page", true, false)
	var ids: Array = []
	var gap: Node = null
	var have: Node = null
	for c in page.get_children():
		if not c.has_meta(&"c10_frag"):
			continue
		ids.append(str(c.get_meta(&"c10_frag")))
		if str(c.get_meta(&"c10_state", "")) == "gap":
			gap = c
		if str(c.get_meta(&"c10_frag")) == "df.brother.1938.farewell_cold":
			have = c
	t.eq(ids, ["df.brother.1938.farewell", "df.brother.1938.farewell_cold"], "fragments follow order")
	t.ok(gap != null, "gap has a node")
	t.ok(not S.has_text(gap), "gap node has no text")
	t.ok(have != null, "have fragment has a node")
	var body := S.find_meta(have, &"c10_body", "df.brother.1938.farewell_cold")
	t.eq((body as Label).text, CardText.card("df.brother.1938.farewell_cold", "body"), "have shows body")
	var cap := S.find_meta(have, &"c10_kind", "said")
	t.eq((cap as Label).text, CardText.ui("c10.kind.said"), "have shows kind")
	t.ok(S.find_meta(have, &"c10_dot", "1") != null, "new fragment has a dot")
	t.ok(_dot(S.find_meta(p, &"c10_person", "brother")), "index dot on a page with new fragments")
	t.ok(not _dot(S.find_meta(p, &"c10_person", "wangshan")), "complete page index has no dot")
	var frags := S.meta_values(p, &"c10_frag")
	t.ok(frags.find("df.linsao.1938.neighbors") < 0, "unobtained neighbor fragment has no node")
	t.ok(frags.find("df.linsao.1938.hairpin") < 0, "unobtained hairpin fragment has no node")
	t.ok(S.find_meta(p, &"c10_seal", "1") == null, "gap page has no seal")


func _dot(n: Node) -> bool:
	if n == null:
		return false
	for c in n.get_children():
		if c.has_meta(&"c10_dot"):
			return true
	return false
