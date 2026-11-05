# 数据集隔离、只读副本、覆盖合法性、人物唯一、机制哈希独立于说明与正文。
# 主人 G01；合同 §4.5–§4.10。
extends SceneTree
const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const H = preload("res://scripts/tests/cards/G01/helper.gd")

func _initialize() -> void:
	var t := T.new(self, "G01_db")
	var root := t.user_dir() + "/cards"
	H.copy_tree("res://data/cards", root)
	var db := CardDB.load_all(root, {"only_examples": true})
	t.eq(db.errors(), PackedStringArray(), "examples load clean")
	t.ok(db.all_ids().size() > 60, "example set present")
	var id := "p.linsao.1938.pawn_hairpin"
	var example_files := 0
	for card_id in db.all_ids():
		var rel := db.file_of(card_id)
		example_files += 1 if rel.begins_with("_examples/") else 0
		t.ok(rel.begins_with("_examples/"), "example file stays in set: %s -> %s" % [card_id, rel])
	t.eq(example_files, db.all_ids().size(), "every example id comes from _examples")
	var true_db := CardDB.load_all(root)
	var leaked := 0
	for card_id in true_db.all_ids():
		var rel := true_db.file_of(card_id)
		if rel.begins_with("_examples/") or rel == "":
			leaked += 1
		t.ok(not rel.begins_with("_examples/") and rel != "", "true file stays out of examples: %s -> %s" % [card_id, rel])
	t.eq(leaked, 0, "true set separate")
	t.ok(db.file_of(id).begins_with("_examples/"), "sentinel read from examples")
	var mutable := db.def(id)
	mutable["weight"] = 999
	t.ok(int(db.def(id)["weight"]) != 999, "def returns copy")
	var hash := db.hash()
	var path := root + "/" + db.file_of(id)
	var data: Dictionary = CardDB.read_json(path)
	for card in data["cards"]:
		if card["id"] == id:
			card["brief"] = "CHANGED_NOTE"
	H.write(path, data)
	H.write(root + "/text/test.text.json", {id: {"title": "TXT_1", "_provenance": "human:A:2026-10-13"}})
	db = CardDB.load_all(root, {"only_examples": true})
	t.eq(db.hash(), hash, "notes text do not change mechanism hash")
	t.eq(db.text_entry(id)["title"], "TXT_1", "text loaded separately")
	H.write(root + "/rules/balance_overrides.json", {"_meta": {"owner": "G06", "schema": 1}, "deal": {"person": {"min": 2}}})
	db = CardDB.load_all(root, {"only_examples": true})
	t.eq(db.rules("deal")["person"]["min"], 2, "deep override existing key")
	t.eq(db.rules("deal")["person"]["max"], 4, "deep override retains sibling")
	t.ok(db.hash() != hash, "mechanics change hash")
	H.write(root + "/rules/balance_overrides.json", {"_meta": {"owner": "G06", "schema": 1}, "deal": {"bogus": 3}})
	db = CardDB.load_all(root, {"only_examples": true})
	t.ok(not db.errors().is_empty(), "unknown override recorded")
	t.ok(not db.rules("deal").has("bogus"), "invalid override not applied")
	data = CardDB.read_json(path)
	data["persons"] = {"linsao": {"brief": "TEST"}}
	H.write(path, data)
	db = CardDB.load_all(root, {"only_examples": true})
	t.ok(db.errors().size() >= 2, "duplicate cast person recorded")
	var pool := db.pool(&"person", "1938")
	var sorted := pool.duplicate()
	sorted.sort()
	t.eq(pool, sorted, "pool sorted")
	for card_id in pool:
		t.ok(int(db.def(card_id).get("weight", 10)) > 0, "positive pool weight")
	H.write(root + "/rules/balance_overrides.json", {"_meta": {"owner": "G06", "schema": 1}, "deal": 3})
	t.ok(not CardDB.load_all(root, {"only_examples": true}).errors().is_empty(), "malformed override does not crash")
	var bad_json := FileAccess.open(root + "/bad.json", FileAccess.WRITE)
	bad_json.store_string('{"n": 001}')
	bad_json.close()
	t.eq(CardDB.read_json(root + "/bad.json"), null, "integer protection preserves invalid JSON rejection")
	t.finish()

