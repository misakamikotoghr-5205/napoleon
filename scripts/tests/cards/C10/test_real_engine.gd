# C10 W2: real engine. Example set stays (--data defaults to examples).
# --data=k: only_examples false. Obtain and miss fragments by playing real K cards.
# Every row from query("dossier") must be drawn (index, have body, gap tear). Not a print-only pass.
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const S = preload("res://scripts/tests/cards/C10/support.gd")
const SCENE := "res://scenes/cards/dossier/DossierBook.tscn"
const HAVE_ID := "df.linsao.1938.hairpin"
const GAP_ID := "df.brother.1938.farewell"


func _initialize() -> void:
	var t := T.new(self, _arg("--name=", "C10_real_engine"))
	t.run_async(_body.bind(t))


func _body(t) -> void:
	if _arg("--data=", "examples") == "k":
		await _body_k(t)
		return
	var bus := CardEventBus.new()
	root.add_child(bus)
	await t.frames(1)
	var engine := CardEngine.new(bus)
	var started: Dictionary = engine.new_game({
		"seed": 7,
		"only_examples": true,
		"save_dir": t.user_dir(),
	})
	t.ok(engine is CardEngine, "boots the real engine")
	t.ok(bool(started.get("ok", false)), "example game starts")
	if not bool(started.get("ok", false)):
		bus.queue_free()
		await t.frames(1)
		return
	var effects: Array = [
		{"op": "dossier", "frag": HAVE_ID},
		{"op": "dossier_gap", "frag": GAP_ID},
	]
	engine.ctx.run(effects, "C10/real_engine")
	var view: Dictionary = engine.query(&"dossier", {})
	t.no_leaks(view, "dossier")
	var pages := _rows(view.get("pages", []))
	t.eq(_count_state(pages, "have"), 1, "one fragment obtained")
	t.eq(_count_state(pages, "gap"), 1, "one gap left")
	t.eq(_frag_state(pages, HAVE_ID), "have", "hairpin is the obtained fragment")
	t.eq(_frag_state(pages, GAP_ID), "gap", "farewell is the gap")
	var book: CardDossierBook = load(SCENE).instantiate()
	book.bind(engine, bus)
	root.add_child(book)
	book.open({})
	await t.frames(2)
	_assert_drawn(t, book, pages)
	t.eq(t.all_text_from_cardtext(book), PackedStringArray(), "drawn text comes from CardText")
	t.ok(not S.has_percent(book), "drawn book has no percent")
	book.queue_free()
	await t.frames(1)
	bus.queue_free()
	await t.frames(1)


# Real K data. Do not write the dossier result. Day loop deals K cards; an ignored
# gold card's on_expire misses a fragment; card.read of a dealt news card obtains one.
func _body_k(t) -> void:
	var bus: CardEventBus = CardEventBus.new()
	root.add_child(bus)
	await t.frames(1)
	var engine: CardEngine = CardEngine.new(bus)
	var started: Dictionary = engine.new_game({
		"seed": 7,
		"only_examples": false,
		"save_dir": t.user_dir(),
	})
	t.ok(engine is CardEngine, "boots the real engine")
	t.ok(bool(started.get("ok", false)), "real K game starts")
	if not bool(started.get("ok", false)):
		bus.queue_free()
		await t.frames(1)
		return
	var played: Dictionary = _play_k_have_and_gap(t, engine)
	var have_id: String = str(played.get("have", ""))
	var gap_id: String = str(played.get("gap", ""))
	t.ok(have_id != "", "obtained a fragment by reading a dealt K card")
	t.ok(gap_id != "", "missed a fragment from a dealt K card on_expire")
	t.ok(_expired_gap(engine, gap_id), "gap frag is the expired K card's dossier_gap")
	if have_id == "" or gap_id == "":
		bus.queue_free()
		await t.frames(1)
		return
	var view: Dictionary = engine.query(&"dossier", {})
	t.no_leaks(view, "dossier")
	var pages: Array = _rows(view.get("pages", []))
	t.ok(not _page_people(pages).is_empty(), "query lists dossier people")
	t.eq(_frag_state(pages, have_id), "have", "read fragment is obtained")
	t.eq(_frag_state(pages, gap_id), "gap", "missed fragment is a gap")
	t.ok(_frag_flag(pages, have_id, "new"), "obtained fragment is marked new")
	t.ok(not _frag_flag(pages, gap_id, "new"), "gap is not marked new")
	var kind: String = _frag_field(pages, have_id, "kind")
	t.eq(kind, str(engine.ctx.db.def(have_id).get("kind", "")), "kind comes from the K fragment")
	t.ok(kind != "", "obtained fragment has a kind")
	t.ok(CardText.card(have_id, "body") != "", "obtained fragment has body text")
	var book: CardDossierBook = load(SCENE).instantiate()
	book.bind(engine, bus)
	root.add_child(book)
	book.open({})
	await t.frames(2)
	_assert_drawn(t, book, pages)
	t.eq(t.all_text_from_cardtext(book), PackedStringArray(), "drawn text comes from CardText")
	t.ok(not S.has_percent(book), "drawn book has no percent")
	book.queue_free()
	await t.frames(1)
	bus.queue_free()
	await t.frames(1)


func _play_k_have_and_gap(t, engine: CardEngine) -> Dictionary:
	var guard: int = 0
	while guard < 48:
		guard += 1
		var view: Dictionary = engine.view()
		var phase: String = str(view.get("phase", ""))
		if phase == "game_over":
			t.ok(false, "game over before a K fragment pair")
			return {}
		if phase == "day":
			var news: Dictionary = _hand_news_have(engine)
			var gap_id: String = _first_gap(engine)
			if str(news.get("frag", "")) != "" and gap_id != "":
				var uid: String = str(news.get("uid", ""))
				var read: Dictionary = engine.send(&"card.read", {"uid": uid})
				t.ok(bool(read.get("ok", false)), "card.read of dealt K news")
				return {"have": str(news.get("frag", "")), "gap": gap_id}
		var stepped: Dictionary = engine.send(&"day.end", {"confirm": true})
		t.ok(bool(stepped.get("ok", false)), "advance " + phase + " " + str(stepped.get("err", "")))
		if not bool(stepped.get("ok", false)):
			return {}
	t.ok(false, "no dealt K news and gap within the day loop")
	return {}


func _hand_news_have(engine: CardEngine) -> Dictionary:
	var hand: Array = engine.view().get("hand", [])
	for item in hand:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var card: Dictionary = item
		if str(card.get("type", "")) != "news":
			continue
		var d: Dictionary = engine.ctx.db.def(str(card.get("def", "")))
		var effects: Dictionary = d.get("effects", {})
		var on_read: Array = effects.get("on_read", [])
		for eff in on_read:
			if typeof(eff) != TYPE_DICTIONARY:
				continue
			var row: Dictionary = eff
			if str(row.get("op", "")) != "dossier":
				continue
			var frag: String = str(row.get("frag", ""))
			if str(engine.ctx.db.def(frag).get("type", "")) != "dossier_fragment":
				continue
			return {"uid": str(card.get("uid", "")), "frag": frag}
	return {}


func _first_gap(engine: CardEngine) -> String:
	var view: Dictionary = engine.query(&"dossier", {})
	var pages: Array = _rows(view.get("pages", []))
	for p in pages:
		var frags: Array = _rows((p as Dictionary).get("fragments", []))
		for f in frags:
			if str((f as Dictionary).get("state", "")) == "gap":
				return str((f as Dictionary).get("id", ""))
	return ""


func _expired_gap(engine: CardEngine, frag: String) -> bool:
	if frag == "":
		return false
	for uid in CardPiles.list(engine.ctx, CardIds.ZONE_DISCARD):
		var d: Dictionary = CardPiles.def_of(engine.ctx, uid)
		var effects: Dictionary = d.get("effects", {})
		var exp: Array = effects.get("on_expire", [])
		for eff in exp:
			if typeof(eff) != TYPE_DICTIONARY:
				continue
			var row: Dictionary = eff
			if str(row.get("op", "")) == "dossier_gap" and str(row.get("frag", "")) == frag:
				return true
	return false


func _frag_flag(pages: Array, fid: String, key: String) -> bool:
	for p in pages:
		var frags: Array = _rows((p as Dictionary).get("fragments", []))
		for f in frags:
			var frag: Dictionary = f
			if str(frag.get("id", "")) == fid:
				return bool(frag.get(key, false))
	return false


func _frag_field(pages: Array, fid: String, key: String) -> String:
	for p in pages:
		var frags: Array = _rows((p as Dictionary).get("fragments", []))
		for f in frags:
			var frag: Dictionary = f
			if str(frag.get("id", "")) == fid:
				return str(frag.get(key, ""))
	return ""


func _assert_drawn(t, book: Node, pages: Array) -> void:
	var shown := book.find_child("Page", true, false) as Control
	t.ok(shown != null and shown.size.x > 100.0 and shown.size.y > 100.0, "dossier page has area")
	t.eq(_index_people(book), _page_people(pages), "index draws every dossier person")
	var saw_have := false
	var saw_gap := false
	for p in pages:
		var page: Dictionary = p
		var person := str(page.get("person", ""))
		var btn := S.find_meta(book, &"c10_person", person)
		t.ok(btn is Button, person + " index row drawn")
		if btn is Button:
			t.eq((btn as Button).text, CardText.person_name(person), person + " name drawn")
			var dotted := S.find_meta(btn, &"c10_dot", "1") != null
			t.eq(dotted, _expect_dot(page), person + " index dot matches query new")
			(btn as Button).pressed.emit()
		shown = book.find_child("Page", true, false) as Control
		t.ok(shown != null and shown.visible, person + " page visible")
		if shown == null:
			continue
		t.eq(str(shown.get_meta(&"c10_show", "")), person, person + " page is showing")
		var title := _title(person)
		var title_l := _label_with(shown, title)
		t.ok(title_l != null and title_l.visible and title_l.size.y > 0.0, person + " title drawn")
		t.eq(_drawn_ids(shown), _query_ids(page), person + " fragment rows")
		var seal := S.find_meta(shown, &"c10_seal", "1")
		if bool(page.get("complete", false)):
			t.ok(seal != null, person + " seal drawn")
		else:
			t.ok(seal == null, person + " no seal")
		var frags := _rows(page.get("fragments", []))
		for f in frags:
			var frag: Dictionary = f
			var fid := str(frag.get("id", ""))
			var state := str(frag.get("state", ""))
			var row := S.find_meta(shown, &"c10_frag", fid)
			t.ok(row is Control, fid + " row drawn")
			if not (row is Control):
				continue
			var box := row as Control
			t.ok(box.visible and box.size.y > 8.0, fid + " row has area")
			t.eq(str(box.get_meta(&"c10_state", "")), state, fid + " state drawn")
			var row_dot := S.find_meta(box, &"c10_dot", "1") != null
			t.eq(row_dot, bool(frag.get("new", false)), fid + " new dot")
			if state == "have":
				saw_have = true
				var body := S.find_meta(box, &"c10_body", fid)
				t.ok(body is Label, fid + " body label drawn")
				if body is Label:
					var lab := body as Label
					t.eq(lab.text, CardText.card(fid, "body"), fid + " body text drawn")
					t.ok(lab.text != "" and lab.visible and lab.size.y > 0.0, fid + " body has area")
				var kind := str(frag.get("kind", ""))
				if kind != "":
					var cap := S.find_meta(box, &"c10_kind", kind)
					t.ok(cap is Label, fid + " kind caption drawn")
					if cap is Label:
						t.eq((cap as Label).text, CardText.ui("c10.kind." + kind), fid + " kind text drawn")
				t.ok(_tear(box, fid) == null, fid + " have row is not a tear")
				_year_chip(t, box, frag, fid)
			elif state == "gap":
				saw_gap = true
				t.ok(not S.has_text(box), fid + " gap has no text")
				var tear := _tear(box, fid)
				t.ok(tear != null and tear.visible and tear.size.x > 8.0 and tear.size.y > 8.0, fid + " tear drawn")
	t.ok(saw_have, "a have row was drawn")
	t.ok(saw_gap, "a gap row was drawn")


func _year_chip(t, row: Node, frag: Dictionary, fid: String) -> void:
	if str(frag.get("kind", "")) != "year_after":
		return
	var era_s := str(frag.get("era", ""))
	if not _digits(era_s):
		return
	var chip := S.find_meta(row, &"c10_year", era_s)
	t.ok(chip is Label, fid + " year chip drawn")
	if chip is Label:
		t.eq((chip as Label).text, era_s, fid + " year text drawn")


func _count_state(pages: Array, state: String) -> int:
	var n := 0
	for p in pages:
		var frags := _rows((p as Dictionary).get("fragments", []))
		for f in frags:
			if str((f as Dictionary).get("state", "")) == state:
				n += 1
	return n


func _frag_state(pages: Array, fid: String) -> String:
	for p in pages:
		var frags := _rows((p as Dictionary).get("fragments", []))
		for f in frags:
			if str((f as Dictionary).get("id", "")) == fid:
				return str((f as Dictionary).get("state", ""))
	return ""


func _index_people(book: Node) -> Array:
	var out: Array = []
	var index := book.find_child("Index", true, false)
	if index == null:
		return out
	for c in index.get_children():
		if c is Button and (c as Node).has_meta(&"c10_person"):
			out.append(str((c as Node).get_meta(&"c10_person")))
	return out


func _page_people(pages: Array) -> Array:
	var out: Array = []
	for p in pages:
		out.append(str((p as Dictionary).get("person", "")))
	return out


func _query_ids(page: Dictionary) -> Array:
	var out: Array = []
	var frags := _rows(page.get("fragments", []))
	for f in frags:
		out.append(str((f as Dictionary).get("id", "")))
	return out


func _drawn_ids(page: Node) -> Array:
	var out: Array = []
	if page == null:
		return out
	for c in page.get_children():
		if c.has_meta(&"c10_frag"):
			out.append(str(c.get_meta(&"c10_frag")))
	return out


func _expect_dot(page: Dictionary) -> bool:
	if int(page.get("new", 0)) > 0:
		return true
	var frags := _rows(page.get("fragments", []))
	for f in frags:
		if bool((f as Dictionary).get("new", false)):
			return true
	return false


func _title(person: String) -> String:
	var ref := "dp." + person + "#title"
	if CardText.is_draft(ref):
		return CardText.person_name(person)
	return CardText.card("dp." + person, "title")


func _label_with(root: Node, text: String) -> Label:
	if root == null:
		return null
	var stack: Array = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is Label and (n as Label).text == text:
			return n as Label
		var kids: Array = n.get_children()
		for i in range(kids.size() - 1, -1, -1):
			stack.append(kids[i])
	return null


func _tear(row: Node, fid: String) -> Control:
	for c in row.get_children():
		var scr = c.get_script()
		if scr == null:
			continue
		if str(scr.resource_path).ends_with("tear_edge.gd") and str(c.get("frag_id")) == fid:
			return c as Control
	return null


func _digits(s: String) -> bool:
	if s == "":
		return false
	for i in range(s.length()):
		var ch := s.unicode_at(i)
		if ch < 48 or ch > 57:
			return false
	return true


func _rows(v) -> Array:
	if typeof(v) != TYPE_ARRAY:
		return []
	var out: Array = []
	for item in v:
		if typeof(item) == TYPE_DICTIONARY:
			out.append(item)
	return out


func _arg(prefix: String, fallback: String) -> String:
	for a in OS.get_cmdline_user_args():
		if str(a).begins_with(prefix):
			return str(a).substr(prefix.length())
	return fallback
