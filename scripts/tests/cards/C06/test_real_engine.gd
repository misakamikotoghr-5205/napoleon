# Real engine: open the month, offer incense, spin, month.begin.
# The wheel under the fixed needle matches fate.wheels["wh.month:"].result.
# Default is the example set. --examples=0 uses K data (only_examples false).
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const S = preload("res://scripts/tests/cards/C06/support.gd")
const PANEL := "res://scenes/cards/wheel/WheelPanel.tscn"


func _initialize() -> void:
	var examples: bool = _arg("--examples=", "1") != "0"
	var t := T.new(self, _arg("--name=", "C06_real_engine"))
	t.run_async(_body.bind(t, examples))


func _body(t, examples: bool) -> void:
	var bus := CardEventBus.new()
	root.add_child(bus)
	await t.frames(1)
	var engine := CardEngine.new(bus)
	var started: Dictionary = engine.new_game({
		"seed": 7,
		"only_examples": examples,
		"save_dir": t.user_dir(),
	})
	var started_msg := "new game on the example set"
	if not examples:
		started_msg = "new game on K data"
	t.ok(bool(started.get("ok", false)), started_msg)
	var view: Dictionary = engine.view()
	t.eq(str(view.get("phase", "")), "month_open", "new game opens the month")
	var open_panel := _dict(view.get("open_panel", {}))
	var args := _dict(open_panel.get("args", {}))
	t.eq(str(open_panel.get("kind", "")), "wheel", "month asks for the wheel")
	t.eq(str(args.get("wheel", "")), "wh.month", "wheel is this month's fate")
	t.eq(str(args.get("uid", "missing")), "", "month fate uid is empty")
	var panel: CardWheelPanel = load(PANEL).instantiate()
	panel.bind(engine, bus)
	root.add_child(panel)
	panel.fast_anim = true
	panel.open(args)
	await t.frames(2)
	var title := panel.find_child("Title", true, false) as Label
	t.eq(title.text, CardText.ui("c06.title.month"), "month wheel is the open panel")
	S.press(panel, "Offer")
	await t.frames(1)
	var offered := _month_wheel(engine)
	var incense := _array(offered.get("incense", []))
	t.eq(incense.size(), 1, "one incense offering")
	var source: Dictionary = {}
	if incense.size() == 1:
		source = _dict(incense[0])
	t.eq(str(source.get("kind", "")), "money", "incense is money")
	t.eq(int(source.get("amount", 0)), 10, "offered ten coins of incense")
	t.eq(_cmd_args(engine, "wheel.offer"), [{
		"wheel": "wh.month",
		"uid": "",
		"source": {"kind": "money", "amount": 10},
	}], "offer command")
	S.press(panel, "Spin")
	await t.frames(1)
	var spun := _month_wheel(engine)
	var result := _dict(spun.get("result", {}))
	var segment := str(result.get("segment", ""))
	var stop := float(int(result.get("stop_mdeg", -1000))) / 1000.0
	var needle := panel.find_child("Needle", true, false) as Control
	var face := S.face(panel)
	var angle := S.from_twelve(face)
	t.ok(needle != null and face != null, "needle and face exist")
	t.ok(absf(needle.rotation) <= 0.001, "needle stays fixed at twelve")
	t.ok(segment != "", "engine recorded a segment")
	t.ok(absf(_wrap(angle - stop)) <= 0.5, "needle %.4f matches fate.wheels stop %.4f" % [angle, stop])
	var queried: Dictionary = engine.query(&"wheel", {"wheel": "wh.month", "uid": ""})
	t.no_leaks(queried, "wheel query")
	var segs := _array(queried.get("segments", []))
	t.ok(S.stop_inside(segs, segment, angle), "needle sits in %s" % segment)
	t.eq(str(_dict(queried.get("result", {})).get("segment", "")), segment, "query segment matches fate.wheels")
	var disc := panel.find_child("Disc", true, false) as Control
	t.eq(int(disc.get("selected")), _index_of(segs, segment), "highlighted wedge is the engine segment")
	var reveal := panel.find_child("RevealTitle", true, false) as Label
	t.ok(reveal != null and reveal.visible, "reveal is showing")
	S.press(panel, "Continue")
	await t.frames(1)
	t.eq(str(engine.view().get("phase", "")), "morning", "continue sends month.begin")
	t.eq(_cmd_count(engine, "month.begin"), 1, "month.begin once")
	t.eq(_cmd_count(engine, "wheel.spin"), 1, "one spin")
	var after := _dict(_month_wheel(engine).get("result", {}))
	t.eq(str(after.get("segment", "")), segment, "month.begin keeps the spun segment")
	t.eq(int(after.get("stop_mdeg", -1)), int(result.get("stop_mdeg", -2)), "month.begin keeps stop_mdeg")
	t.ok(absf(_wrap(S.from_twelve(face) - stop)) <= 0.5, "needle still matches after month.begin")
	panel.queue_free()
	bus.queue_free()
	await t.frames(2)


func _month_wheel(engine: CardEngine) -> Dictionary:
	var fate: Dictionary = engine.ctx.state.ns("fate")
	var wheels := _dict(fate.get("wheels", {}))
	return _dict(wheels.get("wh.month:", {}))


func _cmd_args(engine: CardEngine, cmd: String) -> Array:
	var out: Array = []
	for row in engine.command_log():
		if typeof(row) == TYPE_ARRAY and (row as Array).size() >= 2 and str((row as Array)[0]) == cmd:
			out.append((row as Array)[1])
	return out


func _cmd_count(engine: CardEngine, cmd: String) -> int:
	return _cmd_args(engine, cmd).size()


func _index_of(segs: Array, id: String) -> int:
	for i in segs.size():
		if str(_dict(segs[i]).get("id", "")) == id:
			return i
	return -1


func _wrap(delta: float) -> float:
	return fposmod(delta + 180.0, 360.0) - 180.0


func _dict(v) -> Dictionary:
	return v if typeof(v) == TYPE_DICTIONARY else {}


func _array(v) -> Array:
	return v if typeof(v) == TYPE_ARRAY else []


func _arg(prefix: String, fallback: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with(prefix):
			return a.substr(prefix.length())
	return fallback
