# gd.d1.spot lights, then mg_tool (a mouse click on a tool) completes it. Three anchors stay on screen.
# --name= sets the PASS line. --steps=k16 loads Mock guide_data (K16 steps.json).
# K16 gd.d1.spot.trigger.after is [gd.d1.look]. Earlier steps are legal ui.guide
# progress (shown, then done). Look itself completes on the real cmd:mg.request.
# Owner C12. Contract: docs/cards/CARDS_INTERFACES.md 7.10.5, 3.3 C12.
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const Lib = preload("res://scripts/tests/cards/C12/c12_lib.gd")

const PRIOR: Array[String] = [
	"gd.m.open",
	"gd.m.wheel",
	"gd.m.incense",
	"gd.d1.notice",
	"gd.d1.deal",
	"gd.d1.person",
]


func _initialize() -> void:
	var test_name := "C12_guide"
	var steps := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--name="):
			test_name = a.substr(7)
		elif a.begins_with("--steps="):
			steps = a.substr(8)
	var t := T.new(self, test_name)
	t.run_async(_body.bind(t, steps))


func _body(t, steps: String) -> void:
	var k16 := steps == "k16"
	var bus := CardEventBus.new()
	root.add_child(bus)
	var mock := MockCardEngine.new(bus)
	t.ok(mock.db != null, "text db")
	var held: Array[Node] = []
	if k16:
		_seed_prior(t, mock)
		_assert_spot_after(t, mock)
	await t.frames(1)
	var game := Lib.open_game(self, Lib.fixture("hairpin"))
	game.bind_bus(bus)
	if k16:
		held.append(_look_anchor())
	await t.frames(2)
	t.ok(t.anchor_ok(&"a.mg.spot.main"), "anchor main")
	t.ok(t.anchor_ok(&"a.mg.spot.atlas"), "anchor atlas")
	t.ok(t.anchor_ok(&"a.mg.spot.lens"), "anchor lens")
	var guide: CardGuide = load("res://scenes/cards/shell/GuideOverlay.tscn").instantiate()
	root.add_child(guide)
	guide.bind(mock, bus)
	guide.force(true)
	guide.skip_fades = true
	if k16:
		guide.load_steps(mock.query(&"guide_data"))
		bus.ui_event.emit(&"panel_opened", {"kind": "counter"})
		guide.evaluate_now()
		t.eq(guide.active_step(), "gd.d1.look", "look step lights")
		bus.command_done.emit(&"mg.request", {}, true)
		t.eq(guide.active_step(), "", "mg.request completes look")
	else:
		guide.load_steps(_fixture_steps())
	bus.first_time.emit(&"mg.spot", {"uid": "c0002"})
	guide.evaluate_now()
	t.eq(guide.active_step(), "gd.d1.spot", "step lights")
	# Mouse only now (was the A key): a real click on the lens button, the top control under the mouse.
	var lens := game.get_node("Board/LensButton") as Control
	var at := lens.get_global_rect().get_center()
	Lib.move(self, at)
	await t.frames(1)
	var hit := root.gui_get_hovered_control()
	t.ok(hit == lens or (hit != null and lens.is_ancestor_of(hit)), "lens button is on top under the guide")
	Lib.button_event(self, at, true)
	Lib.button_event(self, at, false)
	await t.frames(1)
	t.eq(game.current_tool(), "lens", "clicked to the lens")
	t.eq(guide.active_step(), "", "tool use completes the step")
	for node in held:
		node.queue_free()
	guide.queue_free()
	game.queue_free()
	bus.queue_free()
	await t.frames(3)


func _seed_prior(t, mock: MockCardEngine) -> void:
	for id in PRIOR:
		var shown: Dictionary = mock.send(&"ui.guide", {"step": id, "status": "shown"})
		var done: Dictionary = mock.send(&"ui.guide", {"step": id, "status": "done"})
		t.ok(bool(shown.get("ok", false)) and bool(done.get("ok", false)), "prior " + id)
	var prog_q: Dictionary = mock.query(&"guide_progress")
	var prog: Dictionary = {}
	var raw_prog: Variant = prog_q.get("progress", {})
	if typeof(raw_prog) == TYPE_DICTIONARY:
		prog = raw_prog
	var person: Dictionary = {}
	var raw_person: Variant = prog.get("gd.d1.person", {})
	if typeof(raw_person) == TYPE_DICTIONARY:
		person = raw_person
	t.eq(str(person.get("status", "")), "done", "prior person is done")
	t.ok(int(person.get("shows", 0)) >= 1, "prior person was shown")


func _assert_spot_after(t, mock: MockCardEngine) -> void:
	var packed: Dictionary = mock.query(&"guide_data")
	var after: Array = []
	var raw_steps: Variant = packed.get("steps", [])
	var steps: Array = raw_steps if typeof(raw_steps) == TYPE_ARRAY else []
	for step in steps:
		if typeof(step) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = step
		if str(row.get("id", "")) != "gd.d1.spot":
			continue
		var trig: Variant = row.get("trigger", {})
		if typeof(trig) != TYPE_DICTIONARY:
			continue
		var trig_d: Dictionary = trig
		var raw_after: Variant = trig_d.get("after", [])
		if typeof(raw_after) == TYPE_ARRAY:
			after = raw_after
	# K16 10-22 (prototype): steps chain only inside one panel (look -> tiers); the minigame's own
	# spot step no longer waits for look, so a player who skips the look lesson still gets it.
	t.eq(after, [], "k16 spot is not chained to look")


func _fixture_steps() -> Dictionary:
	var raw: Variant = CardDB.read_json("res://scripts/tests/cards/C12/guide_steps.json")
	if typeof(raw) != TYPE_DICTIONARY:
		return {}
	return raw


func _look_anchor() -> ColorRect:
	var rect := ColorRect.new()
	rect.name = "LookAnchor"
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.color = Color(0, 0, 0, 0)
	rect.position = Vector2(440, 240)
	rect.size = Vector2(180, 48)
	rect.custom_minimum_size = Vector2(180, 48)
	root.add_child(rect)
	CardAnchors.register(&"a.counter.look", rect)
	return rect
