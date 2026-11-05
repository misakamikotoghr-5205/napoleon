## Public view contracts for the authored roster and segment-specific metrics.
## The all-companion case changes only a temporary book's debug carry, then uses
## normal new_game/query/commands; route progression is covered by test_napoleon.
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const Book = preload("res://scripts/cards/campaign/run/run_book.gd")
const BOOK := "res://data/campaigns/napoleon/book.json"

var t: RefCounted
var _serial := 0


func _initialize() -> void:
	t = T.new(self, "OCEAN_napoleon_view")
	CardSave.set_root(t.user_dir())
	_test_formal_view()
	_test_all_companion_cards()
	_test_segment_metrics()
	_test_legacy_view()
	print("OCEAN Napoleon view assertions: %d" % t.checks)
	t.finish()


func _new(options: Dictionary) -> CardEngine:
	_serial += 1
	var engine := CardEngine.new()
	var opts := {"book": BOOK, "seed": 30, "save_dir": t.user_dir() + "/run_" + str(_serial)}
	opts.merge(options, true)
	if str(opts.get("book", "")) == "":
		opts.erase("book")
	var result := engine.new_game(opts)
	t.ok(result.get("ok", false), "start view contract: " + str(result))
	return engine


func _row(rows: Array, id: String) -> Dictionary:
	for row in rows:
		if str(row.get("id", "")) == id:
			return row
	return {}


func _test_formal_view() -> void:
	var engine := _new({"segment": "conquest"})
	var before := engine.state_hash()
	var history := engine.command_log()
	var c := engine.query(&"campaign")
	var view := engine.view()
	t.eq(c.get("companions", []).size(), 28, "campaign query includes all authored companions")
	t.eq(view.get("caps", {}).get("contacts"), 28, "contact capacity follows the book roster")
	var ids: Array = []
	for contact in view.get("contacts", []):
		ids.append(contact.get("uid"))
	for id in ["baptiste", "corso", "marie", "gourgaud", "drouot"]:
		t.ok("companion:" + id in ids, "debug carry companion has a contact: " + id)
		var card := engine.query(&"card", {"uid": "companion:" + id})
		t.eq(card.get("panel"), "read", "companion opens its readable card: " + id)
		t.eq(CardText.card(str(card.get("def", "")), "title"), _row(c["companions"], id).get("name"), "card uses the authored name: " + id)
		t.no_leaks(card, id + " card")
	t.eq(engine.query(&"card", {"uid": "companion:murat"}), {}, "unrecruited companion has no contact card")
	t.eq(c.get("bonds", []).size(), 19, "formal camp exposes the Napoleon bond set")
	t.eq(_row(c["bonds"], "army_of_italy").get("count"), 3, "Italy bond includes hero, Baptiste and Corso")
	t.eq(_row(c["bonds"], "quartermasters_men").get("count"), 4, "quartermaster bond includes hero and three carried companions")
	t.ok(bool(_row(c["bonds"], "quartermasters_men").get("active", false)), "formal faction can be active in camp")
	t.no_leaks(c, "formal campaign query")
	t.no_leaks(view, "formal table view")
	(c["companions"][0] as Dictionary)["name"] = "mutated copy"
	(c["companions"][0]["bonds"] as Array).clear()
	t.ok(engine.query(&"campaign")["companions"][0]["name"] != "mutated copy", "public companion rows are copied")
	t.eq(engine.state_hash(), before, "views and queries do not change campaign state")
	t.eq(engine.command_log(), history, "views and queries do not append commands")


func _test_all_companion_cards() -> void:
	var raw: Dictionary = Book.read_json(BOOK)["data"]
	var companions: Dictionary = Book.read_json(str(raw["companions"]))["data"]["companions"]
	var all := {}
	for id in companions:
		all[id] = 1
	raw["debug_carry"]["conquest"]["stages"]["0"]["companions"] = all
	var path: String = t.user_dir() + "/all-companions-book.json"
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(raw))
	file.close()
	var loaded := Book.load_bundle(path)
	t.ok(loaded.get("ok", false), "isolated view book uses the real content loader")
	t.eq(Book.validate(loaded["book"])["errors"], [], "isolated debug carry obeys formal validation")
	var engine := _new({"book": path, "segment": "conquest"})
	var view := engine.view()
	t.eq(view.get("contacts", []).size(), 28, "every recruited authored companion can appear as a contact")
	for id in companions:
		var card := engine.query(&"card", {"uid": "companion:" + str(id)})
		t.eq(CardText.card(str(card.get("def", "")), "title"), companions[id]["name"], "complete authored card title: " + str(id))
		t.eq(CardText.person_name(str(id)), companions[id]["name"], "complete authored contact name: " + str(id))
		t.ok(not CardText.card(str(card.get("def", "")), "body").is_empty(), "companion card has class, faction and skill: " + str(id))
		t.no_leaks(card, str(id) + " card")
	for _i in range(4):
		if str(engine.view().get("phase", "")) == "day":
			break
		t.ok(engine.send(&"campaign.wait", {}).get("ok", false), "enter active day through public command")
	var squad := engine.query(&"card", {"uid": "squad"})
	t.eq(squad.get("choices", []).size(), 28, "all living recruited companions receive a promotion action")
	var promote := _row(squad.get("choices", []), "action:promote:murat")
	t.ok(promote.get("enabled", false), "Murat can be promoted through the normal squad card")
	t.ok(CardText.ui("c05.mode.action:promote:murat").contains("缪拉"), "new squad action has the authored display name")
	t.ok(engine.send(&"campaign.promote", {"id": "murat"}).get("ok", false), "public command promotes Murat")
	engine.query(&"card", {"uid": "status"})
	t.ok(CardText.card("ocean.status", "body").contains("缪拉"), "promotion ledger resolves new companion names")
	t.no_leaks(engine.query(&"campaign"), "all-companion query")
	t.no_leaks(engine.view(), "all-companion view")


func _test_segment_metrics() -> void:
	for spec in [
		{"segment": "trunk", "stage": 5, "labels": ["军费", "士气", "民愤", "体力", "工事", "测绘"]},
		{"segment": "conquest", "stage": 0, "labels": ["军费", "士气", "民愤", "体力", "工事", "测绘"]},
		{"segment": "cristo", "stage": 0, "labels": ["经费", "人心", "追缉", "体力", "地道", "卷宗"]},
		{"segment": "ocean", "stage": 0, "labels": ["军费", "同盟威望", "敌方警戒", "体力与士气", "岛屿建设", "深海探索"]},
	]:
		var engine := _new({"segment": spec["segment"], "stage": spec["stage"]})
		var labels: Array = []
		for gauge in engine.query(&"campaign").get("gauges", []):
			labels.append(gauge.get("label"))
		t.eq(labels, spec["labels"], str(spec["segment"]) + " public gauges use its authored vocabulary")
		engine.query(&"card", {"uid": "status"})
		var body := CardText.card("ocean.status", "body")
		for label in spec["labels"]:
			t.ok(body.contains(label), str(spec["segment"]) + " status includes " + str(label))
		t.eq(CardText.ui("c02.hero.nerve"), spec["labels"][4], "hero metric uses the active segment name")
		if str(spec["segment"]) != "ocean":
			t.ok(not body.contains("岛屿建设") and not body.contains("深海探索"), "land campaign status omits obsolete ocean metric labels")


func _test_legacy_view() -> void:
	var engine := _new({"book": "", "campaign": "ocean_pawn"})
	var c := engine.query(&"campaign")
	t.eq(c.get("companions", []).size(), 8, "explicit legacy campaign retains its eight-person roster")
	t.eq(c.get("bonds", []).size(), 5, "legacy campaign retains its original camp bonds")
	t.eq(engine.view().get("caps", {}).get("contacts"), 8, "legacy contact capacity is unchanged")
	t.eq(engine.query(&"card", {"uid": "companion:baptiste"}), {}, "formal-only companions are absent from legacy contacts")
	t.no_leaks(c, "legacy query")
