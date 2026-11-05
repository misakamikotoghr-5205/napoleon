# C14: the optional keys still play a round (1-9 weights, arrows poise, Enter read the stars, F hand back);
# Esc aborts; every handling op emits mg_tool; the screen never shows the hidden fen or a percent sign.
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const Fix = preload("res://scripts/tests/cards/C14/weigh_fix.gd")

var fix


func _initialize() -> void:
	var t := T.new(self, "C14_controls")
	t.run_async(_body.bind(t))


func _body(t) -> void:
	fix = Fix.new()
	fix.setup_text()
	var pars: Dictionary = fix.params("heavy")
	var bus := CardEventBus.new()
	root.add_child(bus)
	var spy = t.spy(bus)
	var game = fix.open(self, pars, bus)
	await t.frames(2)
	var bad: PackedStringArray = t.all_text_from_cardtext(game)
	t.ok(bad.is_empty(), "text comes from CardText or digits: %s" % ", ".join(bad))
	var leaked: PackedStringArray = fix.secret_text(game, int(pars["actual_fen"]))
	t.ok(leaked.is_empty(), "ui hides the hidden fen and has no percent sign: %s" % ", ".join(leaked))
	var panel := game.get_node("Panel") as Control
	t.ok(panel.size.x <= 1100.0 and panel.size.y <= 640.0 and panel.size.x > 0.0, "panel size")
	var box := {"r": {}, "n": 0}
	game.finished.connect(func(r: Dictionary) -> void:
		box["r"] = r
		box["n"] = int(box["n"]) + 1
	)
	var poise_before: int = game._poise_step
	await fix.tap(self, KEY_1)
	await fix.tap(self, KEY_RIGHT if poise_before < int(game._poise_max) else KEY_LEFT)
	await fix.tap(self, KEY_ENTER)
	t.ok(bool(game._committed), "Enter reads the stars")
	var leaked_mid: PackedStringArray = fix.secret_text(game, int(pars["actual_fen"]))
	t.ok(leaked_mid.is_empty(), "the star close-up hides the hidden fen: %s" % ", ".join(leaked_mid))
	var bad_mid: PackedStringArray = t.all_text_from_cardtext(game)
	t.ok(bad_mid.is_empty(), "close-up text comes from CardText or digits: %s" % ", ".join(bad_mid))
	game.apply_op(["call", 4])
	await fix.tap(self, KEY_F)
	await t.frames(1)
	t.eq(int(box["n"]), 1, "one finish")
	t.eq(bool(box["r"]["aborted"]), false, "keyboard round was not an abort")
	t.eq(int(box["r"]["measures"]["steps"]), 2, "weight and poise each counted once")
	t.eq(box["r"]["observations"], ["obs.weigh.heavy"], "the call is what is handed back")
	var tools: Array = []
	for e in spy.ui_events():
		if e[0] == &"mg_tool":
			tools.append(e[1])
	var seen := {"weight": false, "poise": false, "commit": false, "call": false}
	for args in tools:
		t.eq(str(args.get("kind", "")), "weigh", "mg_tool kind")
		var tool := str(args.get("tool", ""))
		t.ok(seen.has(tool) or tool == "again", "mg_tool tool is a weigh op: " + tool)
		if seen.has(tool):
			seen[tool] = true
		t.no_leaks(args, "mg_tool args")
	t.ok(seen["weight"] and seen["poise"] and seen["commit"] and seen["call"], "weight, poise, commit, call fired")
	var leaked2: PackedStringArray = fix.secret_text(game, int(pars["actual_fen"]))
	t.ok(leaked2.is_empty(), "after the round the hidden fen is still hidden")
	game.queue_free()
	await t.frames(1)
	var bus2 := CardEventBus.new()
	root.add_child(bus2)
	var quit_game = fix.open(self, pars, bus2)
	await t.frames(1)
	var aborted := {"r": {}, "n": 0}
	quit_game.finished.connect(func(r: Dictionary) -> void:
		aborted["r"] = r
		aborted["n"] = int(aborted["n"]) + 1
	)
	quit_game.apply_op(["commit"])
	await fix.tap(self, KEY_ESCAPE)
	await fix.tap(self, KEY_F)
	await t.frames(1)
	t.eq(int(aborted["n"]), 1, "esc finishes once")
	t.eq(bool(aborted["r"]["aborted"]), true, "esc aborts")
	t.eq(aborted["r"]["observations"], [], "abort has no observations")
	t.eq(int(aborted["r"]["quality_permille"]), 0, "abort quality is zero")
	t.eq(aborted["r"]["measures"], {}, "abort measures are empty")
	t.eq(int(aborted["r"]["minutes"]), 2, "abort keeps the minutes already spent")
	quit_game.queue_free()
	bus.queue_free()
	bus2.queue_free()
	await t.frames(2)
