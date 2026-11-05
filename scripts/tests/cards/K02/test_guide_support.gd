# K02 guide-support checks (docs/handoff_cards/K02_data-1938-world.md).
# Data task: no anchors. These asserts are what the first-time steps need to find.
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")

# K02 paths from docs/cards/ownership.json. file_of is relative to the data root.
const OURS: Array[String] = [
	"era/1938/events.json", "era/1938/fate.json", "era/1938/big_fate.json",
	"era/1938/life.json", "era/1938/goals.json", "era/1938/stage.json",
	"era/common/events.json", "era/common/big_fate.json",
]


func _initialize() -> void:
	var t := T.new(self, "K02_guide_support")
	var db := CardDB.load_all()
	t.eq(db.errors(), PackedStringArray(), "db loads")
	_stage_and_wheel(t, db)
	_fortune_and_wheels(t, db)
	_pools(t, db)
	_schedules(t, db)
	t.finish()


func _stage_and_wheel(t, db: CardDB) -> void:
	var intro: Dictionary = db.stage(0).get("intro", {})
	var goal_id := str(intro.get("main_goal", ""))
	var goal := db.def(goal_id)
	t.ok(goal_id != "" and db.has(goal_id), "stage main_goal exists")
	t.ok(bool(goal.get("main", false)), "main_goal is a main goal")
	t.eq(str(intro.get("bg", "")), "bg.stage.1938", "stage bg")
	t.ok(int(intro.get("intro_paras", 0)) >= 1, "intro_paras")
	var wheel := db.def("bf.wheel")
	t.ok(db.has("bf.wheel"), "bf.wheel exists")
	t.eq(int(wheel.get("weight", -1)), 0, "bf.wheel weight")
	t.eq(str(wheel.get("opens_wheel", "")), "wh.big", "bf.wheel opens wh.big")
	var go := db.def("ev.any.wheel_go")
	t.ok(db.has("ev.any.wheel_go"), "ev.any.wheel_go exists")
	t.eq(int(go.get("weight", -1)), 0, "wheel_go weight")


func _fortune_and_wheels(t, db: CardDB) -> void:
	var fort := db.def("ev.any.fortune_teller")
	t.ok(db.has("ev.any.fortune_teller"), "fortune teller exists")
	t.eq(str(fort.get("opens_fortune", "")), "both", "fortune opens both")
	var cost: Dictionary = fort.get("cost", {})
	t.ok(int(cost.get("money", 0)) > 0, "fortune costs money")
	var fair := 0
	var gamble := 0
	var stake := 0
	for id in db.ids_of(&"event"):
		if not _owned(db, id):
			continue
		var c := db.def(id)
		var w := str(c.get("opens_wheel", ""))
		if w == "wh.fair":
			fair += 1
		if w == "wh.gamble":
			gamble += 1
		if w != "" and bool(c.get("cost", {}).get("stake", false)):
			stake += 1
	t.ok(fair >= 1, "an event opens wh.fair")
	t.ok(gamble >= 1, "an event opens wh.gamble")
	t.ok(stake >= 1, "a wheel event stakes a kept card")


func _pools(t, db: CardDB) -> void:
	var slotted := 0
	for id in db.ids_of(&"event"):
		if db.file_of(id) != "era/1938/events.json":
			continue
		var c := db.def(id)
		if int(c.get("weight", 0)) <= 0:
			continue
		var slots = c.get("slots", [])
		if typeof(slots) == TYPE_ARRAY and slots.size() > 0 and typeof(c.get("check")) == TYPE_DICTIONARY:
			slotted += 1
	t.ok(slotted >= 3, "1938 has 3 random slot-check events")
	for id in db.ids_of(&"fate"):
		if db.file_of(id) != "era/1938/fate.json":
			continue
		var valence := str(db.def(id).get("valence", ""))
		t.ok(valence == "good" or valence == "bad" or valence == "mixed", id + " valence")
	for id in db.ids_of(&"life"):
		if db.file_of(id) != "era/1938/life.json":
			continue
		var c2 := db.def(id)
		t.ok(int(c2.get("due_days", 0)) > 0, id + " due_days")
		var season = c2.get("season", [])
		var spring := false
		if typeof(season) == TYPE_ARRAY:
			for s in season:
				if int(s) == 0:
					spring = true
		t.ok(spring, id + " season includes spring")


func _owned(db: CardDB, id: String) -> bool:
	return OURS.has(db.file_of(id))


func _schedules(t, db: CardDB) -> void:
	for id in db.all_ids():
		if not _owned(db, id):
			continue
		var sch = db.def(id).get("schedule", null)
		if typeof(sch) != TYPE_DICTIONARY:
			continue
		t.ok(sch.has("stage_day"), id + " schedule has stage_day")
		var sd = sch.get("stage_day")
		var days: Array = sd if typeof(sd) == TYPE_ARRAY else [sd]
		for d in days:
			t.ok(int(d) >= 4, id + " schedule day >= 4")
