# #212 台词两层查找、来源、缓存和机制哈希隔离；夹具只用 ASCII 假字。
# 主人 G01；W2_HANDOFF 10-18 增补。运行回执由 Grok 提供。
extends SceneTree
const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const H = preload("res://scripts/tests/cards/G01/helper.gd")
const SOURCE := "ai:fixture:fixture:2026-10-18:212-test"


func _initialize() -> void:
	var t := T.new(self, "G01_text_ai")
	var data_root := t.user_dir() + "/cards"
	_check_lookup(t, data_root)
	_check_reload(t, data_root)
	_check_invalid(t, t.user_dir() + "/invalid")
	CardText.setup(null)
	t.ok(not CardText.issued_contains("AI_NEW"), "setup clears old issued values")
	t.ok(CardText.is_draft("test.ui"), "null setup cannot resolve previous layers")
	t.ok(CardText.ui("test.ui").ends_with("test.ui"), "null setup falls back to key with configured draft mark")
	t.finish()


func _check_lookup(t, data_root: String) -> void:
	var before := CardDB.load_all(data_root).hash()
	H.write(data_root + "/text/era/1938/people.text.json", {
		"test.card": {"title": "HUMAN", "lines": {"greet": "", "wrong": 7}},
		"test.ui": {"t": "HUMAN_{n}", "_provenance": "human:A"}})
	H.write(data_root + "/text_ai/era/1938/people.text.json", {
		"_meta": {"_provenance": SOURCE},
		"test.card": {"title": "AI_TITLE", "lines": {"greet": "AI_{person}", "wrong": "AI_VALID"},
			"choices": {"yes": "AI_CHOICE"}},
		"test.ui": {"t": "AI_UI"}, "test.only_ai": {"t": "AI_ONLY"},
		"test.person": {"name": "AI_PERSON"}, "item.test.item": {"name": "AI_ITEM"},
		"obs.test": {"t": "AI_OBS"}, "test.empty": {"t": ""}})
	var db := CardDB.load_all(data_root)
	CardText.setup(db)
	t.ok(db.errors().is_empty(), "valid AI source accepted")
	t.eq(db.hash(), before, "text layers excluded from mechanism hash")
	t.eq(CardText.card("test.card", "title"), "HUMAN", "human wins per field")
	t.eq(CardText.t("test.card#lines.greet", {"person": "P"}), "AI_P", "empty human field falls back with params")
	t.eq(CardText.card("test.card", "lines.wrong"), "AI_VALID", "nonstring human field falls back")
	t.eq(CardText.card("test.card", "choices.yes"), "AI_CHOICE", "partial human object keeps AI siblings")
	t.eq(CardText.ui("test.ui", {"n": 3}), "HUMAN_3", "human ui params")
	t.eq(CardText.ui("test.only_ai"), "AI_ONLY", "AI ui")
	t.eq(CardText.person_name("test.person"), "AI_PERSON", "AI person name")
	t.eq(CardText.item_text("test.item", "name"), "AI_ITEM", "AI item")
	t.eq(CardText.obs("obs.test"), "AI_OBS", "AI observation")
	t.ok(not CardText.is_draft("test.card#lines.greet"), "AI field is not draft")
	t.ok(not CardText.is_draft("test.person"), "AI person is not draft")
	t.ok(CardText.is_draft("test.empty"), "empty AI value remains draft")
	t.ok(CardText.is_draft("test.card#body"), "both layers missing remains draft")
	t.ok(CardText.card("test.card", "body") != "", "development missing text falls back")
	t.ok(CardText.issued_contains("AI_P"), "AI formatted text enters issued registry")
	t.ok(db.text_entry("test.only_ai").is_empty(), "AI never appears in raw human lookup")
	t.eq(db.text_entry("test.ui").get("_provenance"), "human:A", "human provenance preserved")
	var entry := db.ai_text_entry("test.card")
	entry["lines"]["greet"] = "MUTATED"
	t.eq(db.ai_text_entry("test.card")["lines"]["greet"], "AI_{person}", "AI accessor deep copies")
	t.eq(db.ai_text_entry("test.card")["_provenance"], SOURCE, "file source retained")
	CardText.setup(CardDB.load_all(data_root, {"ship": true}))
	t.eq(CardText.ui("test.only_ai"), "AI_ONLY", "declared AI runtime works in ship")
	t.eq(CardText.card("test.card", "body"), "", "ship missing text never draft")
	t.ok(not CardText.issued_contains("AI_ONLY"), "ship registry stays empty")


func _check_reload(t, data_root: String) -> void:
	var first := CardDB.load_all(data_root)
	t.ok(CardDB.load_all(data_root) == first, "unchanged data root reuses cache")
	var path := data_root + "/text_ai/era/1938/people.text.json"
	var edited: Dictionary = CardDB.read_json(path)
	edited["test.only_ai"]["t"] = "AI_NEW"
	H.write(path, edited)
	var changed := CardDB.load_all(data_root)
	t.ok(changed != first, "AI content edit invalidates cache")
	CardText.setup(changed)
	t.eq(CardText.ui("test.only_ai"), "AI_NEW", "edited AI text visible")
	t.eq(changed.hash(), first.hash(), "AI edit leaves mechanism hash unchanged")
	var extra := data_root + "/text_ai/ui/new.text.json"
	H.write(extra, {"_meta": {"_provenance": SOURCE}, "test.added": {"t": "AI_ADDED"}})
	var added := CardDB.load_all(data_root)
	t.eq(added.ai_text_entry("test.added").get("t"), "AI_ADDED", "new AI file invalidates cache")
	t.eq(DirAccess.remove_absolute(extra), OK, "remove own test file")
	var removed := CardDB.load_all(data_root)
	t.ok(removed.ai_text_entry("test.added").is_empty(), "removed AI file invalidates cache")
	t.eq(removed.hash(), first.hash(), "add/remove text leaves mechanism hash unchanged")


func _check_invalid(t, data_root: String) -> void:
	for index in range(4):
		var sources: Array = ["", "human:A", "ai:incomplete", 7]
		H.write(data_root + "/text_ai/bad_%d.json" % index, {
			"_meta": {"_provenance": sources[index]}, "bad.%d" % index: {"t": "BAD"}})
	H.write(data_root + "/text_ai/a.json", {
		"_meta": {"_provenance": SOURCE}, "dup": {"t": "FIRST"}, "bad.entry": 7})
	H.write(data_root + "/text_ai/z.json", {
		"_meta": {"_provenance": SOURCE}, "dup": {"t": "SECOND"}})
	H.write(data_root + "/text_ai/not_object.json", [])
	var db := CardDB.load_all(data_root)
	# 2026-10-22：正文层的问题记进 warnings()，不进 errors()（errors 非空会让新局失败）；validate_main 仍报 V26。
	t.eq(db.warnings().size(), 7, "invalid sources, entry, duplicate, document all recorded")
	t.eq(db.errors(), PackedStringArray(), "AI text problems never block a new game")
	for index in range(4):
		t.ok(db.ai_text_entry("bad.%d" % index).is_empty(), "invalid source not loaded")
	t.ok(db.ai_text_entry("bad.entry").is_empty(), "non-object entry not loaded")
	t.eq(db.ai_text_entry("dup").get("t"), "FIRST", "duplicate cannot silently overwrite first")
