# K03 guide support: gold V13, one gold per day, year-end redeems, dangling 1938 outcomes.
# Contract: docs/cards/CARDS_INTERFACES.md V13 / V28 ; task: docs/handoff_cards/K03_data-1939-people.md
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")

const MAJORS: Array[String] = [
	"brother", "chen", "xiaoding", "zhang", "wangshan", "li", "linsao", "zhouma", "zhao",
	"sunyoung", "ma", "hu2", "sunlaoye", "guanjia", "wu", "postman",
]
const K01_FILES: Array[String] = [
	"res://data/cards/era/1938/people.json",
	"res://data/cards/era/1938/story.json",
	"res://data/cards/era/1938/events.json",
	"res://data/cards/era/common/passersby.json",
]


func _initialize() -> void:
	var t := T.new(self, "K03_guide_support")
	var db := CardDB.load_all("res://data/cards", {})
	t.eq(db.errors(), PackedStringArray(), "CardDB load")
	var golds: Array = []
	var redeem := 0
	var story_refs := {}
	for id in db.ids_of(&"person"):
		var rel := db.file_of(id)
		if rel != "era/1939/people.json" and rel != "era/1939/story.json":
			continue
		var c := db.def(id)
		if c.get("gold", false) == true:
			golds.append(c)
			_gold_ok(t, c)
		if str(c.get("intent", "")) == "redeem" and MAJORS.has(str(c.get("person", ""))):
			redeem += 1
		_collect_story_refs(c, story_refs)
	t.ok(golds.size() >= 1, "at least one gold card")
	t.ok(redeem >= 4, "major redeem cards >= 4, got %d" % redeem)
	_days_ok(t, golds)
	var known := _k01_outcomes()
	var keys: Array = story_refs.keys()
	keys.sort()
	for pair in keys:
		if not known.has(str(pair)):
			print("NOTE: dangling story " + str(pair))
	t.finish()


func _gold_ok(t, c: Dictionary) -> void:
	var id := str(c.get("id", ""))
	t.eq(str(c.get("type", "")), "person", id + " gold type")
	var node := str(c.get("story_node", ""))
	t.ok(node != "", id + " story_node")
	t.ok(c.get("keepable", false) != true, id + " keepable")
	t.eq(int(c.get("weight", -1)), 0, id + " weight")
	var sch: Dictionary = c.get("schedule", {})
	t.ok(sch.has("stage_day"), id + " schedule.stage_day")
	var day = sch.get("stage_day")
	if typeof(day) == TYPE_ARRAY:
		t.ok((day as Array).size() == 2, id + " stage_day range")
		t.ok(int(day[1]) <= 30, id + " stage_day past 30")
	else:
		t.ok(CardDslShapes.is_int(day) and int(day) >= 1 and int(day) <= 30, id + " stage_day")
	var ops := {}
	var fx: Dictionary = c.get("effects", {})
	for e in fx.get("on_expire", []):
		if typeof(e) != TYPE_DICTIONARY:
			continue
		ops[str(e.get("op", ""))] = e
	t.ok(ops.has("story") and ops.has("dossier_gap"), id + " on_expire story+dossier_gap")
	if ops.has("story"):
		var st: Dictionary = ops["story"]
		t.ok(str(st.get("outcome", "")) != "", id + " expire outcome")
		t.eq(str(st.get("node", "")), node, id + " expire node")


func _days_ok(t, golds: Array) -> void:
	var used := {}
	for c in golds:
		var day = c.get("schedule", {}).get("stage_day")
		var days: Array = []
		if typeof(day) == TYPE_ARRAY:
			for n in range(int(day[0]), int(day[1]) + 1):
				days.append(n)
		else:
			days.append(int(day))
		for n in days:
			t.ok(not used.has(n), "two gold cards on stage_day %d" % n)
			used[n] = str(c.get("id", ""))


func _collect_story_refs(v, acc: Dictionary) -> void:
	if typeof(v) == TYPE_DICTIONARY:
		if v.size() == 1 and v.has("story") and typeof(v["story"]) == TYPE_ARRAY and (v["story"] as Array).size() == 2:
			var node := str(v["story"][0])
			var outcome := str(v["story"][1])
			if node.begins_with("s1938."):
				acc[node + ":" + outcome] = true
		for k in v.keys():
			_collect_story_refs(v[k], acc)
	elif typeof(v) == TYPE_ARRAY:
		for item in v:
			_collect_story_refs(item, acc)


func _k01_outcomes() -> Dictionary:
	var known := {}
	for path in K01_FILES:
		if not FileAccess.file_exists(path):
			continue
		var data = JSON.parse_string(FileAccess.get_file_as_string(path))
		_harvest_outcomes(data, known)
	return known


func _harvest_outcomes(v, known: Dictionary) -> void:
	if typeof(v) == TYPE_DICTIONARY:
		if str(v.get("op", "")) == "story":
			var node := str(v.get("node", ""))
			var outcome := str(v.get("outcome", ""))
			if node.begins_with("s1938.") and outcome != "":
				known[node + ":" + outcome] = true
		for k in v.keys():
			_harvest_outcomes(v[k], known)
	elif typeof(v) == TYPE_ARRAY:
		for item in v:
			_harvest_outcomes(item, known)
