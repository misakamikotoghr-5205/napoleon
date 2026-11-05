# 新存档第 1–3 天：shown_log 按顺序等于 _test.d1_3，每一步都有 ui.guide shown 和 done。
# 默认读本目录的 21 步；--steps=examples 读例子集；--steps=k16 读 K16（合入后再进清单）。
# k16 replays guide_k16_d1..d3 (real after / done_when / anchor ids). Default fixtures stay on the other modes.
# 主人 C16。合同：docs/cards/CARDS_INTERFACES.md §7.10.9、§7.10.10。
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const Drive = preload("res://scripts/tests/cards/C16/guide_drive.gd")
const Fake = preload("res://scripts/tests/cards/C16/fake_engine.gd")
const FIXTURES: Array[String] = [
	"res://scripts/tests/cards/C16/fixtures/guide_d1.json",
	"res://scripts/tests/cards/C16/fixtures/guide_d2.json",
	"res://scripts/tests/cards/C16/fixtures/guide_d3.json",
]
const K16_FIXTURES: Array[String] = [
	"res://scripts/tests/cards/C16/fixtures/guide_k16_d1.json",
	"res://scripts/tests/cards/C16/fixtures/guide_k16_d2.json",
	"res://scripts/tests/cards/C16/fixtures/guide_k16_d3.json",
]


func _initialize() -> void:
	var test_name := "C16_guide_d1_3"
	var mode := "full"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--name="):
			test_name = a.substr(7)
		elif a.begins_with("--steps="):
			mode = a.substr(8)
	var t := T.new(self, test_name)
	t.run_async(_body.bind(t, mode))


func _body(t, mode: String) -> void:
	var path := _steps_path(mode)
	t.ok(FileAccess.file_exists(path), "steps file exists: " + path)
	if not FileAccess.file_exists(path):
		return
	var doc = CardDB.read_json(path)
	t.ok(typeof(doc) == TYPE_DICTIONARY, "steps json")
	if typeof(doc) != TYPE_DICTIONARY:
		return
	var want: Array = doc.get("_test", {}).get("d1_3", [])
	t.ok(not want.is_empty(), "_test.d1_3 is present")
	var packed := _pack(doc)
	var bus := CardEventBus.new()
	root.add_child(bus)
	var eng = Fake.new()
	eng.data = packed
	eng.view_d = {"phase": "boot", "mode": "shop", "date": {"stage": 0, "stage_day": 0, "abs_day": 0}, "hand": []}
	var holder := Control.new()
	holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(holder)
	var paths: Array[String] = _fixture_paths(mode)
	_anchors(holder, paths)
	var guide: CardGuide = load("res://scenes/cards/shell/GuideOverlay.tscn").instantiate()
	guide.skip_fades = true
	guide.set_process(false)
	holder.add_child(guide)
	guide.bind(eng, bus)
	guide.load_steps(packed)
	guide.force(true)
	for fx in paths:
		var day = CardDB.read_json(fx)
		await Drive.play(self, guide, bus, eng, day.get("ops", []))
	await t.frames(2)
	t.eq(Array(guide.shown_log), want, "shown_log matches _test.d1_3")
	for step in want:
		var shown := false
		var done := false
		for row in eng.sent:
			if str(row[0]) != "ui.guide":
				continue
			if str(row[1].get("step", "")) != str(step):
				continue
			if str(row[1].get("status", "")) == "shown":
				shown = true
			if str(row[1].get("status", "")) == "done":
				done = true
		t.ok(shown, "ui.guide shown for " + str(step))
		t.ok(done, "ui.guide done for " + str(step))
	holder.queue_free()
	bus.queue_free()
	await t.frames(2)


func _fixture_paths(mode: String) -> Array[String]:
	if mode == "k16":
		return K16_FIXTURES
	return FIXTURES


func _steps_path(mode: String) -> String:
	if mode == "examples":
		return "res://data/cards/_examples/guide/steps.json"
	if mode == "k16":
		return "res://data/cards/guide/steps.json"
	return "res://scripts/tests/cards/C16/fixtures/guide_steps_full.json"


func _pack(doc: Dictionary) -> Dictionary:
	var steps: Array = []
	for c in doc.get("cards", []):
		if typeof(c) != TYPE_DICTIONARY:
			continue
		var d: Dictionary = c.duplicate(true)
		for k in ["brief", "_provenance", "_test", "weight", "era"]:
			d.erase(k)
		steps.append(d)
	var rules = CardDB.read_json("res://data/cards/rules/guide.json")
	var settings: Dictionary = rules.duplicate(true) if typeof(rules) == TYPE_DICTIONARY else {}
	return {"steps": steps, "settings": settings}


func _anchors(holder: Control, paths: Array[String]) -> void:
	var seen: Dictionary = {}
	for fx in paths:
		var day = CardDB.read_json(fx)
		if typeof(day) != TYPE_DICTIONARY:
			continue
		for a in day.get("anchors", []):
			var id := str(a.get("id", ""))
			if id == "" or seen.has(id):
				continue
			seen[id] = true
			var rect := ColorRect.new()
			rect.color = CardTheme.color(&"paper")
			rect.position = Vector2(float(a.get("x", 0)), float(a.get("y", 0)))
			rect.size = Vector2(float(a.get("w", 10)), float(a.get("h", 10)))
			rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			holder.add_child(rect)
			CardAnchors.register(StringName(id), rect)
