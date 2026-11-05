# C14: gd.mg.weigh lights on a.mg.weigh.weights and completes on one weight (mg_tool).
# Three anchors stay inside 1280x720. --steps=k16 loads production steps (stage_day_gte 4)
# against fixtures/guide_day4.json. The day rule is not weakened.
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const Fix = preload("res://scripts/tests/cards/C14/weigh_fix.gd")

var fix
const GUIDE := "res://scenes/cards/shell/GuideOverlay.tscn"
const STEPS := "res://scripts/tests/cards/C14/guide_steps.json"
const DAY4 := "res://scripts/tests/cards/C14/fixtures/guide_day4.json"


func _initialize() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--"):
			var kv := a.substr(2).split("=", true, 1)
			args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	var t := T.new(self, str(args.get("name", "C14_guide")))
	t.run_async(_body.bind(t, args))


func _body(t, args: Dictionary) -> void:
	fix = Fix.new()
	fix.setup_text()
	var bus := CardEventBus.new()
	root.add_child(bus)
	var mock := MockCardEngine.new(bus)
	var k16: bool = str(args.get("steps", "")) == "k16"
	if k16:
		mock.load_fixture(DAY4)
		var date: Dictionary = mock.view().get("date", {})
		t.ok(int(date.get("stage_day", 0)) >= 4, "fixture stage_day is at least 4")
		t.eq(int(date.get("abs_day", 0)), 4, "fixture abs_day is the fourth day")
		t.eq(str(mock.view().get("phase", "")), "day", "fixture phase is day")
	var game = fix.open(self, fix.params("match"), bus)
	var guide: CardGuide = load(GUIDE).instantiate()
	root.add_child(guide)
	guide.bind(mock, bus)
	guide.force(true)
	guide.skip_fades = true
	if k16:
		var data: Dictionary = mock.query(&"guide_data")
		t.eq(_stage_day_rule(data), 4, "production gd.mg.weigh keeps stage_day_gte 4")
		guide.load_steps(data)
	else:
		guide.load_steps(CardDB.read_json(STEPS))
	await t.frames(2)
	for id in [&"a.mg.weigh.main", &"a.mg.weigh.weights", &"a.mg.weigh.beam"]:
		t.ok(t.anchor_ok(id), "anchor %s inside 1280x720" % id)
	bus.first_time.emit(&"mg.weigh", {"uid": "c0014"})
	guide.evaluate_now()
	t.eq(guide.active_step(), "gd.mg.weigh", "gd.mg.weigh lights on the weights")
	game.apply_op(["weight", 0])
	await t.frames(2)
	t.eq(guide.active_step(), "", "weight tool completes the step")
	t.eq(Array(guide.shown_log), ["gd.mg.weigh"], "the step was shown")
	game.queue_free()
	guide.queue_free()
	bus.queue_free()
	await t.frames(2)


func _stage_day_rule(data: Dictionary) -> int:
	var steps: Array = data.get("steps", [])
	for step in steps:
		if typeof(step) != TYPE_DICTIONARY:
			continue
		if str((step as Dictionary).get("id", "")) != "gd.mg.weigh":
			continue
		var trig: Variant = (step as Dictionary).get("trigger", {})
		if typeof(trig) != TYPE_DICTIONARY:
			return 0
		return int((trig as Dictionary).get("stage_day_gte", 0))
	return -1
