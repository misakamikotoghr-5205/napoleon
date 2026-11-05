# K01 guide anchors: brother farewell, suanming, schedule days, p.any.redeem.
# Reads real data only. No player-facing strings.
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")

const MY := [
	"era/1938/people.json",
	"era/1938/story.json",
	"era/common/passersby.json",
]


func _initialize() -> void:
	var t := T.new(self, "K01_guide_support")
	var db := CardDB.load_all("res://data/cards", {})
	_farewell(t, db)
	_suanming(t)
	_schedules_and_gold(t, db)
	var redeem := db.def("p.any.redeem")
	t.ok(not redeem.is_empty(), "p.any.redeem exists")
	t.eq(int(redeem.get("weight", -1)), 0, "p.any.redeem weight")
	t.eq(str(redeem.get("intent", "")), "redeem", "p.any.redeem intent")
	t.finish()


func _farewell(t, db: CardDB) -> void:
	var c := db.def("p.brother.1938.farewell")
	t.ok(not c.is_empty(), "farewell exists")
	t.eq(bool(c.get("gold", false)), true, "gold")
	t.eq(str(c.get("story_node", "")), "s1938.brother_farewell", "story_node")
	t.eq(int(c.get("schedule", {}).get("stage_day", -1)), 2, "stage_day")
	t.eq(int(c.get("weight", -1)), 0, "weight")
	var choices: Array = c.get("choices", [])
	t.ok(not choices.is_empty() and str(choices[0].get("id", "")) == "listen", "first choice listen")
	var found := false
	if not choices.is_empty():
		for e in choices[0].get("effects", []):
			if typeof(e) == TYPE_DICTIONARY and str(e.get("op", "")) == "add_card" \
					and str(e.get("card", "")) == "kp.brother_note" and str(e.get("to", "")) == "kept":
				found = true
	t.ok(found, "listen adds kp.brother_note to kept")
	var has_story := false
	var has_gap := false
	var expire: Array = c.get("effects", {}).get("on_expire", [])
	for e in expire:
		if typeof(e) != TYPE_DICTIONARY:
			continue
		if str(e.get("op", "")) == "story" and str(e.get("outcome", "")) != "":
			has_story = true
		if str(e.get("op", "")) == "dossier_gap":
			has_gap = true
	t.ok(has_story, "on_expire story outcome")
	t.ok(has_gap, "on_expire dossier_gap")


func _suanming(t) -> void:
	var doc = CardDB.read_json("res://data/cards/era/common/passersby.json")
	var persons: Dictionary = doc.get("persons", {})
	t.ok(persons.has("suanming"), "suanming registered")
	var row: Dictionary = persons.get("suanming", {})
	t.eq(str(row.get("portrait", "")), "portrait.suanming", "suanming portrait")


func _schedules_and_gold(t, db: CardDB) -> void:
	for id in db.all_ids():
		var rel := db.file_of(id)
		if not MY.has(rel):
			continue
		var c := db.def(id)
		if c.has("schedule"):
			if id != "p.brother.1938.farewell":
				var sd = c["schedule"].get("stage_day", null)
				t.ok(sd != null, "%s schedule needs stage_day" % id)
				if typeof(sd) == TYPE_ARRAY:
					for x in sd:
						t.ok(int(x) >= 4 and int(x) <= 30, "%s stage_day %s" % [id, str(x)])
				elif sd != null:
					t.ok(int(sd) >= 4 and int(sd) <= 30, "%s stage_day %s" % [id, str(sd)])
		if bool(c.get("gold", false)):
			t.ok(_v13(c), "%s fails V13" % id)


func _v13(c: Dictionary) -> bool:
	if str(c.get("type", "")) != "person":
		return false
	if str(c.get("story_node", "")) == "":
		return false
	if bool(c.get("keepable", false)):
		return false
	var ops := {}
	for e in c.get("effects", {}).get("on_expire", []):
		if typeof(e) == TYPE_DICTIONARY:
			ops[str(e.get("op", ""))] = true
	return ops.has("story") and ops.has("dossier_gap")
