# C15: gd.mg.fragments / gd.mg.decode light, then a real move or codebook lookup completes them
# (10-25: through apply_op, the path the mouse uses; the old keyboard shortcuts are gone).
# Five anchors have area. Contract 7.10.5.
# --steps=k16 loads unfiltered data/cards/guide/steps.json (not the stripped guide_data query).
# Both K16 steps require stage_day_gte 4.
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const H = preload("res://scripts/tests/cards/C15/harness.gd")
const GUIDE := "res://scenes/cards/shell/GuideOverlay.tscn"
const STEPS := "res://scripts/tests/cards/C15/guide_steps.json"
const K16_STEPS := "res://data/cards/guide/steps.json"
const K16_RULES := "res://data/cards/rules/guide.json"

var _tools: Array = []
var _k16: Dictionary = {}


func _initialize() -> void:
	var args := _args()
	var name := str(args.get("name", "C15_guide"))
	var t := T.new(self, name)
	t.run_async(_body.bind(t, str(args.get("steps", ""))))


func _body(t, steps_mode: String) -> void:
	var bus := CardEventBus.new()
	root.add_child(bus)
	bus.ui_event.connect(_on_ui)
	var mock := MockCardEngine.new(bus)
	var host := CardMiniGameHost.new()
	host.bus = bus
	root.add_child(host)
	var frag = load(H.FRAG).instantiate()
	var dec = load(H.DEC).instantiate()
	host.add_child(frag)
	host.add_child(dec)
	frag.start(H.params("ticket196.json"))
	dec.start(H.params("telegram.json"))
	var guide = load(GUIDE).instantiate()
	root.add_child(guide)
	guide.bind(mock, bus)
	guide.force(true)
	guide.skip_fades = true
	var k16 := steps_mode == "k16"
	if k16:
		_k16 = _k16_data()
		_require_k16(t, "gd.mg.fragments")
		_require_k16(t, "gd.mg.decode")
		_set_day(mock, 3)
		guide.load_steps(_k16)
	else:
		guide.load_steps(CardDB.read_json(STEPS))
	await t.frames(2)
	t.ok(t.anchor_ok(&"a.mg.fragments.main"), "anchor fragments main")
	t.ok(t.anchor_ok(&"a.mg.fragments.board"), "anchor board")
	t.ok(t.anchor_ok(&"a.mg.fragments.seal"), "anchor seal")
	t.ok(t.anchor_ok(&"a.mg.decode.main"), "anchor decode main")
	t.ok(t.anchor_ok(&"a.mg.decode.book"), "anchor book")
	await _fragments(t, guide, bus, mock, frag, k16)
	await _decode(t, guide, bus, mock, dec, k16)
	t.finish()


func _fragments(t, guide: CardGuide, bus: CardEventBus, mock: MockCardEngine, frag: Node, k16: bool) -> void:
	if k16:
		_set_day(mock, 3)
	bus.first_time.emit(&"mg.fragments", {"uid": "c0015"})
	guide.evaluate_now()
	if k16:
		t.eq(guide.active_step(), "", "fragments stays dark before stage day 4")
		_set_day(mock, _need_day("gd.mg.fragments"))
		guide.evaluate_now()
	t.eq(guide.active_step(), "gd.mg.fragments", "fragments lights")
	_tools.clear()
	var p := int(frag.layout()["tray_order"][0])
	var at: Vector2i = frag.piece_pos(p)
	frag.apply_op(["move", p, at.x - 16, at.y])
	t.ok(_saw("fragments", "move"), "fragment move emits mg_tool")
	t.eq(guide.active_step(), "", "fragments done after move")
	await _shown_done(t, guide, mock, "gd.mg.fragments")


func _decode(t, guide: CardGuide, bus: CardEventBus, mock: MockCardEngine, dec: Node, k16: bool) -> void:
	if k16:
		_set_day(mock, 3)
	bus.first_time.emit(&"mg.decode", {"uid": "c0016"})
	guide.evaluate_now()
	if k16:
		t.eq(guide.active_step(), "", "decode stays dark before stage day 4")
		_set_day(mock, _need_day("gd.mg.decode"))
		guide.evaluate_now()
	t.eq(guide.active_step(), "gd.mg.decode", "decode lights")
	_tools.clear()
	dec.apply_op(["page", 1])
	t.ok(_saw("decode", "lookup"), "codebook lookup emits mg_tool")
	t.eq(guide.active_step(), "", "decode done after lookup")
	await _shown_done(t, guide, mock, "gd.mg.decode")


func _shown_done(t, guide: CardGuide, mock: MockCardEngine, id: String) -> void:
	t.ok(guide.shown_log.has(id), id + " shown")
	await t.frames(1)
	t.ok(_sent(mock, id, "shown"), id + " ui.guide shown")
	t.ok(_sent(mock, id, "done"), id + " ui.guide done")
	var status := _progress_status(mock, id)
	t.eq(status, "done", id + " progress done")


func _require_k16(t, id: String) -> void:
	var step := _step(id)
	t.ok(not step.is_empty(), "unfiltered k16 has " + id)
	t.ok(step.has("brief"), id + " keeps brief")
	t.ok(step.has("_provenance"), id + " keeps provenance")
	t.eq(_need_day(id), 4, id + " stage_day_gte 4")
	var done = step.get("done_when", [])
	var has_tool := false
	if typeof(done) == TYPE_ARRAY:
		has_tool = (done as Array).has("ui:mg_tool")
	t.ok(has_tool, id + " done_when includes ui:mg_tool")


func _k16_data() -> Dictionary:
	var raw = CardDB.read_json(K16_STEPS)
	var doc: Dictionary = raw if typeof(raw) == TYPE_DICTIONARY else {}
	var cards: Array = []
	var got = doc.get("cards", [])
	if typeof(got) == TYPE_ARRAY:
		cards = (got as Array).duplicate(true)
	var rules_raw = CardDB.read_json(K16_RULES)
	var settings: Dictionary = {}
	if typeof(rules_raw) == TYPE_DICTIONARY:
		settings = (rules_raw as Dictionary).duplicate(true)
	return {"steps": cards, "settings": settings}


func _step(id: String) -> Dictionary:
	var steps: Array = _k16.get("steps", [])
	for row in steps:
		if typeof(row) != TYPE_DICTIONARY:
			continue
		var one: Dictionary = row
		if str(one.get("id", "")) == id:
			return one
	return {}


func _need_day(id: String) -> int:
	var trig = _step(id).get("trigger", {})
	if typeof(trig) != TYPE_DICTIONARY:
		return 0
	return int((trig as Dictionary).get("stage_day_gte", 0))


func _set_day(mock: MockCardEngine, day: int) -> void:
	var date: Dictionary = {"stage": 0, "stage_day": day, "abs_day": day}
	mock._view = {"phase": "day", "mode": "shop", "date": date, "hand": []}


func _on_ui(ev: StringName, args: Dictionary) -> void:
	if ev != &"mg_tool":
		return
	_tools.append(str(args.get("kind", "")) + ":" + str(args.get("tool", "")))


func _saw(kind: String, tool: String) -> bool:
	return _tools.has(kind + ":" + tool)


func _sent(mock: MockCardEngine, id: String, status: String) -> bool:
	for row in mock.sent:
		if typeof(row) != TYPE_ARRAY:
			continue
		var pair: Array = row
		if pair.size() < 2 or str(pair[0]) != "ui.guide":
			continue
		if typeof(pair[1]) != TYPE_DICTIONARY:
			continue
		var args: Dictionary = pair[1]
		if str(args.get("step", "")) == id and str(args.get("status", "")) == status:
			return true
	return false


func _progress_status(mock: MockCardEngine, id: String) -> String:
	var q: Dictionary = mock.query(&"guide_progress")
	var raw = q.get("progress", {})
	if typeof(raw) != TYPE_DICTIONARY:
		return ""
	var row = (raw as Dictionary).get(id, {})
	if typeof(row) != TYPE_DICTIONARY:
		return ""
	return str((row as Dictionary).get("status", ""))


func _args() -> Dictionary:
	var out := {}
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--"):
			var kv := a.substr(2).split("=", true, 1)
			out[kv[0]] = kv[1] if kv.size() > 1 else "1"
	return out
