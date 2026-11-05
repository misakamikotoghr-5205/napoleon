# C10：规矩栏只按 firsts 解锁，指引关掉时一样；标题正文来自 rule.<id>。
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const S = preload("res://scripts/tests/cards/C10/support.gd")
const SOME := "res://scripts/tests/cards/C10/fixtures/rules_some.json"
const OFF := "res://scripts/tests/cards/C10/fixtures/rules_guide_off.json"
const SCENE := "res://scenes/cards/dossier/DossierBook.tscn"
const FULL: Array = ["rule.day", "rule.person", "rule.slots"]

func _initialize() -> void:
	var t := T.new(self, _arg("--name=", "C10_rules"))
	if _arg("--steps=", "") == "k16":
		t.run_async(_k16.bind(t))
	else:
		t.run_async(_body.bind(t))


func _body(t) -> void:
	S.leaks_fixture(t, SOME)
	S.leaks_fixture(t, OFF)
	var bus := CardEventBus.new()
	root.add_child(bus)
	var mock := MockCardEngine.new(bus)
	mock.load_fixture(SOME)
	t.no_leaks(mock.query(&"firsts", {}), "firsts")
	t.no_leaks(mock.query(&"guide_data", {}), "guide_data")
	var book := await _open(bus, mock)
	var rules = book.find_child("Rules", true, false)
	t.eq(rules.call("rule_ids"), FULL, "unlocked pages follow order")
	_text(t, rules, "rule.day", CardText.person_name("brother"))
	rules.call("step", 1)
	t.eq(str(rules.call("current_id")), "rule.person", "second page is rule.person")
	_text(t, rules, "rule.person", CardText.person_name("brother"))
	rules.call("step", 1)
	t.eq(str(rules.call("current_id")), "rule.slots", "third page is rule.slots")
	_text(t, rules, "rule.slots", CardText.ui("c10.teacher.brother_ledger"))
	t.eq(t.all_text_from_cardtext(book), PackedStringArray(), "rules text from CardText")
	t.ok(not S.has_percent(book), "rules have no percent")
	book.queue_free()
	await t.frames(1)
	await _missing_slots(t, bus)
	bus.queue_free()
	await t.frames(1)
	var off_game := _boot(OFF, "off")
	await t.frames(3)
	off_game.guide.force(false)
	t.ok(not off_game.guide.is_enabled(), "guide is off")
	var off_ids: Array = await _hosted_ids(off_game)
	t.eq(off_ids, FULL, "guide off still unlocks the same pages")
	_drop(off_game)
	await t.frames(2)
	CardAnchors.clear()
	var on_game := _boot(SOME, "on")
	await t.frames(3)
	on_game.guide.force(true)
	t.ok(on_game.guide.is_enabled(), "guide is on")
	var on_ids: Array = await _hosted_ids(on_game)
	t.eq(on_ids, off_ids, "guide on matches guide off")
	_drop(on_game)
	await t.frames(2)


func _text(t, rules: Node, id: String, teacher: String) -> void:
	t.eq(str(rules.call("current_id")), id, "current " + id)
	var title := rules.find_child("RuleTitle", true, false) as Label
	var body := rules.find_child("RuleBody", true, false) as Label
	var line := rules.find_child("RuleTeacher", true, false) as Label
	t.eq(title.text, CardText.card(id, "title"), id + " title")
	t.eq(body.text, CardText.card(id, "body"), id + " body")
	t.eq(line.text, teacher, id + " teacher")


func _open(bus: CardEventBus, mock: CardEngineApi) -> CardDossierBook:
	var p: CardDossierBook = load(SCENE).instantiate()
	p.bind(mock, bus)
	root.add_child(p)
	p.open({})
	await process_frame
	var tab := S.find_meta(p, &"c10_tab", "rules")
	(tab as Button).pressed.emit()
	await process_frame
	return p


func _missing_slots(t, bus: CardEventBus) -> void:
	var data = CardDB.read_json(SOME).duplicate(true)
	(data["queries"]["firsts|{}"]["firsts"] as Dictionary).erase("slots")
	var path: String = t.user_dir() + "/no_slots.json"
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(data))
	f.close()
	var mock := MockCardEngine.new(bus)
	mock.load_fixture(path)
	var book := await _open(bus, mock)
	var ids: Array = book.find_child("Rules", true, false).call("rule_ids")
	t.ok(ids.has("rule.day"), "deal still unlocks rule.day")
	t.ok(not ids.has("rule.slots"), "without slots, rule.slots is absent")
	t.eq(ids, ["rule.day", "rule.person"], "remaining pages stay in order")
	book.queue_free()
	await process_frame


func _hosted_ids(game: CardGameRoot) -> Array:
	game.host.open_panel(&"dossier", {})
	await process_frame
	var panel := game.host.top_panel()
	var tab := S.find_meta(panel, &"c10_tab", "rules")
	(tab as Button).pressed.emit()
	await process_frame
	return panel.find_child("Rules", true, false).call("rule_ids")


func _boot(fixture: String, guide_mode: String) -> CardGameRoot:
	var bus := CardEventBus.new()
	root.add_child(bus)
	var game: CardGameRoot = load(CardIds.ROOT_SCENE).instantiate()
	game.boot({"mock": true, "bus": bus, "fixture": fixture, "skip_title": true, "guide": guide_mode})
	root.add_child(game)
	return game


func _drop(game: CardGameRoot) -> void:
	var bus := game.bus
	game.queue_free()
	if bus != null:
		bus.queue_free()


# --steps=k16: live guide_data (not the example set). All firsts present unlocks every page, ordered by order.
func _k16(t) -> void:
	var bus := CardEventBus.new()
	root.add_child(bus)
	await t.frames(1)
	var engine := CardEngine.new(bus)
	var started: Dictionary = engine.new_game({
		"seed": 7,
		"only_examples": false,
		"save_dir": t.user_dir(),
	})
	t.ok(bool(started.get("ok", false)), "k16 real game starts")
	if not bool(started.get("ok", false)):
		bus.queue_free()
		await t.frames(1)
		return
	for mech in CardIds.FIRSTS.keys():
		CardFirsts.mark(engine.ctx, StringName(str(mech)), {})
	var data: Dictionary = engine.query(&"guide_data", {})
	var pages := _rows(data.get("pages", []))
	t.eq(pages.size(), 26, "guide_data.pages has 26 pages")
	var ordered: Array = pages.duplicate()
	ordered.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ao := int(a.get("order", 0))
		var bo := int(b.get("order", 0))
		if ao != bo:
			return ao < bo
		return str(a.get("id", "")) < str(b.get("id", ""))
	)
	var expect: Array = []
	for p in ordered:
		expect.append(str((p as Dictionary).get("id", "")))
	var book := await _open(bus, engine)
	var rules: Node = book.find_child("Rules", true, false)
	t.ok(rules != null and rules.visible, "rules column is open")
	if rules == null:
		book.queue_free()
		await t.frames(1)
		bus.queue_free()
		await t.frames(1)
		return
	var ids: Array = rules.call("rule_ids")
	t.eq(ids, expect, "all pages unlock ordered by order")
	t.eq(ids.size(), 26, "all 26 pages unlock")
	t.eq(_rule_button_ids(rules), ids, "rule buttons draw the unlocked pages")
	_rule_labels(t, rules, expect)
	var first := ""
	if expect.size() > 0:
		first = str(expect[0])
	t.eq(str(rules.call("current_id")), first, "current page is the first by order")
	var title := rules.find_child("RuleTitle", true, false) as Label
	var body := rules.find_child("RuleBody", true, false) as Label
	t.ok(title != null and body != null, "title and body labels exist")
	if title != null and body != null and first != "":
		t.eq(title.text, CardText.card(first, "title"), "first rule title drawn")
		t.eq(body.text, CardText.card(first, "body"), "first rule body drawn")
		t.ok(title.visible and title.size.y > 0.0, "first title has area")
		t.ok(body.visible and body.size.y > 0.0, "first body has area")
	t.eq(t.all_text_from_cardtext(book), PackedStringArray(), "rules text from CardText")
	book.queue_free()
	await t.frames(1)
	bus.queue_free()
	await t.frames(1)


func _rows(v) -> Array:
	if typeof(v) != TYPE_ARRAY:
		return []
	var out: Array = []
	for item in v:
		if typeof(item) == TYPE_DICTIONARY:
			out.append(item)
	return out


func _rule_button_ids(rules: Node) -> Array:
	var out: Array = []
	_collect_rule_ids(rules, out)
	return out


func _collect_rule_ids(n: Node, out: Array) -> void:
	for c in n.get_children():
		if c.has_meta(&"c10_rule"):
			out.append(str(c.get_meta(&"c10_rule")))
		else:
			_collect_rule_ids(c, out)


func _rule_labels(t, rules: Node, expect: Array) -> void:
	for id in expect:
		var sid := str(id)
		var n := S.find_meta(rules, &"c10_rule", sid)
		t.ok(n is Button, sid + " button drawn")
		if n is Button:
			var b := n as Button
			t.eq(b.text, CardText.card(sid, "title"), sid + " title drawn")
			t.ok(b.visible and b.size.y >= 30.0, sid + " button has area")


func _arg(prefix: String, fallback: String) -> String:
	for a in OS.get_cmdline_user_args():
		if str(a).begins_with(prefix):
			return str(a).substr(prefix.length())
	return fallback

