# RG5_dossier: old ink in the dossier book (ROGUE_V1.md §7.6). With the dossier_old_ink fixture: old rows carry
# c10_state "old", are faded and stamped, the page foot has the hint, an id already on the page is not merged, a
# person known only from old ink gets a page (dimmed tile, no dot, no seal), paging walks the extra page. Without the
# query (C10's dossier_mixed, the Mock answers not_implemented) the book is exactly C10's. A real engine with a run
# context feeds legacy.old_ink into the book, and opening it leaves the state hash alone. Owner RG5.
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const S = preload("res://scripts/tests/cards/C10/support.gd")
const FX := "res://scripts/tests/cards/RG5/fixtures/dossier_old_ink.json"
const FX_C10 := "res://scripts/tests/cards/C10/fixtures/dossier_mixed.json"
const SCENE := "res://scenes/cards/dossier/DossierBook.tscn"
const OLD_ALPHA := 0.6


func _initialize() -> void:
	var t := T.new(self, "RG5_dossier")
	t.run_async(_body.bind(t))


func _body(t) -> void:
	S.source_ok(t, "res://scripts/cards/ui/dossier/dossier_book.gd")
	var bus := CardEventBus.new()
	root.add_child(bus)
	await _old_ink(t, bus)
	await _without_query(t, bus)
	await _real_engine(t, bus)
	bus.queue_free()
	await t.frames(2)


func _open(engine: CardEngineApi, bus: CardEventBus) -> CardDossierBook:
	var p: CardDossierBook = load(SCENE).instantiate()
	p.bind(engine, bus)
	root.add_child(p)
	p.open({"uid": "c0002"})
	await _frames(2)
	return p


func _frames(n: int) -> void:
	for i in range(n):
		await process_frame


func _close(p: Node) -> void:
	p.queue_free()
	await _frames(2)


func _people(p: Node) -> Array:
	var out: Array = []
	for c in p.find_child("Index", true, false).get_children():
		if c is Button and c.has_meta(&"c10_person"):
			out.append(str(c.get_meta(&"c10_person")))
	return out


## [[id, state, row], …] for the fragment rows of the page on show, top to bottom.
func _rows(p: Node) -> Array:
	var out: Array = []
	for c in p.find_child("Page", true, false).get_children():
		if c.has_meta(&"c10_frag"):
			out.append([str(c.get_meta(&"c10_frag")), str(c.get_meta(&"c10_state", "")), c])
	return out


func _col(rows: Array, i: int) -> Array:
	return rows.map(func(r: Array): return r[i])


func _shown(p: Node) -> String:
	return str(p.find_child("Page", true, false).get_meta(&"c10_show", ""))


func _has_dot(n: Node) -> bool:
	if n == null:
		return false
	for c in n.get_children():
		if c.has_meta(&"c10_dot"):
			return true
	return false


func _old_ink(t, bus: CardEventBus) -> void:
	var mock := MockCardEngine.new(bus)
	mock.load_fixture(FX)
	S.leaks_fixture(t, FX)
	t.no_leaks(mock.query(&"legacy.old_ink", {}), "old_ink fixture query")
	var p := await _open(mock, bus)
	t.eq(_people(p), ["brother", "wangshan", "linsao", "chen"], "old-only person appended after the dossier pages")
	var chen_tile := S.find_meta(p, &"c10_person", "chen") as Button
	t.ok(chen_tile != null and str(chen_tile.get_meta(&"rg5_old_only", "")) == "1", "old-only tile is marked")
	t.ok(chen_tile != null and chen_tile.get_theme_color("font_color") == CardTheme.color(&"text_3"), "old-only tile name dimmed")
	t.ok(not _has_dot(chen_tile), "old-only tile has no new dot")
	for who in ["brother", "wangshan", "linsao"]:
		t.ok(not (S.find_meta(p, &"c10_person", who) as Node).has_meta(&"rg5_old_only"), who + " tile is a normal tile")
	t.ok(_has_dot(S.find_meta(p, &"c10_person", "linsao")), "linsao keeps its new dot")
	# brother: the old-ink id is already on the page (a gap) -> not merged, no stamp, no hint.
	t.eq(_shown(p), "brother", "brother page first")
	var rows := _rows(p)
	t.eq(_col(rows, 0), ["df.brother.1938.farewell", "df.brother.1938.farewell_cold"], "brother rows unchanged")
	t.eq(_col(rows, 1), ["gap", "have"], "an old-ink id already on the page keeps its own state")
	t.ok(S.find_meta(p, &"rg5_old_ink_hint", "1") == null, "no hint on a page without old ink")
	t.ok(S.find_meta(p, &"rg5_old_ink", "1") == null, "no stamp on a page without old ink")
	await S.tap(self, KEY_RIGHT)
	await S.tap(self, KEY_RIGHT)
	t.eq(_shown(p), "linsao", "right twice opens linsao")
	_check_linsao(t, p)
	await S.tap(self, KEY_RIGHT)
	t.eq(_shown(p), "chen", "right opens the old-only page")
	_check_chen(t, p)
	t.eq(t.all_text_from_cardtext(p), PackedStringArray(), "old ink text from CardText")
	t.ok(not S.has_percent(p), "no percent")
	await S.tap(self, KEY_RIGHT)
	t.eq(_shown(p), "brother", "paging wraps past the old-only page")
	p.refresh(mock.view())
	t.eq(_people(p), ["brother", "wangshan", "linsao", "chen"], "refresh keeps the merged index")
	await _close(p)


func _check_linsao(t, p: Node) -> void:
	var rows := _rows(p)
	t.eq(_col(rows, 0), ["df.linsao.1938.hairpin", "df.linsao.1938.husband", "df.linsao.1939.after_hairpin"],
		"old ink merged into the page by order")
	t.eq(_col(rows, 1), ["old", "old", "have"], "old rows have c10_state old")
	var faded := CardTheme.with_alpha(&"ink_soft", OLD_ALPHA)
	var bottom := 0.0
	for r in rows:
		var row: Control = r[2]
		bottom = maxf(bottom, row.position.y + row.size.y)
		var stamp := S.find_meta(row, &"rg5_old_ink", "1") as Label
		var body := S.find_meta(row, &"c10_body", str(r[0])) as Label
		t.ok(body != null and body.text == CardText.card(str(r[0]), "body"), str(r[0]) + " shows its body")
		if r[1] == "old":
			t.eq(row.modulate, faded, str(r[0]) + " is faded")
			t.ok(stamp != null and stamp.text == CardText.ui("rg5.dossier.old_ink"), str(r[0]) + " has the old-ink stamp")
			t.ok(not _has_dot(row), str(r[0]) + " has no new dot")
			if stamp != null and body != null:
				t.ok(body.position.x + body.size.x <= stamp.position.x + 0.5, str(r[0]) + " body leaves room for the stamp")
				t.ok(stamp.position.x + stamp.size.x <= row.size.x + 0.5, str(r[0]) + " stamp inside the row")
		else:
			t.eq(row.modulate, Color.WHITE, str(r[0]) + " (held) is not faded")
			t.ok(stamp == null, str(r[0]) + " (held) has no stamp")
	var hint := S.find_meta(p, &"rg5_old_ink_hint", "1") as Label
	t.ok(hint != null and hint.text == CardText.ui("rg5.dossier.old_ink_hint"), "page foot hint")
	t.ok(hint != null and hint.position.y >= bottom, "hint below the last row")
	var page := p.find_child("Page", true, false) as Control
	t.ok(hint != null and page.custom_minimum_size.y >= hint.position.y + hint.size.y, "page tall enough for the hint")
	t.ok(S.find_meta(p, &"c10_seal", "1") == null, "old ink never completes a page")
	var year := S.find_meta(p, &"c10_year", "1939")
	t.ok(year != null, "the held year-after row is drawn as before")


func _check_chen(t, p: Node) -> void:
	var rows := _rows(p)
	t.eq(_col(rows, 0), ["df.chen.1938.clinic"], "old-only page lists its old ink")
	t.eq(_col(rows, 1), ["old"], "old-only page rows are old")
	t.ok(S.find_meta(p, &"rg5_old_ink_hint", "1") != null, "old-only page has the hint")
	t.ok(S.find_meta(p, &"c10_seal", "1") == null, "old-only page has no seal")


## C10's fixture has no legacy.old_ink: the Mock answers not_implemented and the book is C10's book.
func _without_query(t, bus: CardEventBus) -> void:
	var mock := MockCardEngine.new(bus)
	mock.load_fixture(FX_C10)
	t.eq(mock.query(&"legacy.old_ink", {}).get("err"), "not_implemented", "C10 fixture has no old-ink query")
	var p := await _open(mock, bus)
	t.eq(_people(p), ["brother", "wangshan", "linsao"], "without the query: C10's index")
	t.eq(_col(_rows(p), 0), ["df.brother.1938.farewell", "df.brother.1938.farewell_cold"], "without the query: C10's rows")
	await S.tap(self, KEY_RIGHT)
	await S.tap(self, KEY_RIGHT)
	t.eq(_col(_rows(p), 0), ["df.linsao.1939.after_hairpin"], "without the query: linsao has only what was held")
	for key in [&"rg5_old_ink", &"rg5_old_ink_hint", &"rg5_old_only"]:
		t.eq(S.meta_values(p, key), [], "without the query: no " + str(key))
	t.ok(not S.meta_values(p, &"c10_state").has("old"), "without the query: no old rows")
	t.eq(t.all_text_from_cardtext(p), PackedStringArray(), "without the query: text from CardText")
	await _close(p)


## A real engine with a run context: legacy.old_ink reaches the book; opening it changes nothing in the state.
func _real_engine(t, bus: CardEventBus) -> void:
	var e := CardEngine.new(bus)
	var r := e.new_game({"seed": 7, "save_dir": t.user_dir() + "/real",
		"run": {"no": 2, "known": ["df.linsao.1938.husband", "df.linsao.1938.hairpin", "df.chen.1938.clinic"]}})
	t.ok(bool(r.get("ok", false)), "real engine with a run context")
	CardDossier.add(e.ctx, "df.linsao.1938.hairpin")
	var before := e.state_hash()
	var p := await _open(e, bus)
	t.eq(e.state_hash(), before, "opening the book with old ink is read only")
	t.eq(_people(p), ["linsao", "chen"], "real engine: held page, then the old-only page")
	t.eq(_shown(p), "linsao", "real engine: linsao first")
	var rows := _rows(p)
	t.eq([_col(rows, 0), _col(rows, 1)], [["df.linsao.1938.hairpin", "df.linsao.1938.husband"], ["have", "old"]],
		"real engine: the held fragment and the old one")
	t.ok(not e.ctx.test({"dossier_has": "df.linsao.1938.husband"}), "real engine: old ink is not held")
	await S.tap(self, KEY_RIGHT)
	t.eq([_shown(p), _col(_rows(p), 1)], ["chen", ["old"]], "real engine: chen from old ink only")
	t.eq(t.all_text_from_cardtext(p), PackedStringArray(), "real engine: text from CardText")
	await _close(p)
