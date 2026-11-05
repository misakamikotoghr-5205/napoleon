# Guide: gd.almanac, gd.lot, and gd.cezi light and complete. Four anchors have area inside the screen.
# --name= sets the PASS line. --steps=k16 loads data/cards/guide/steps.json through guide_data.
# gd.almanac there is stage_day_gte 4, seconds 12, anchor a.almanac, done cmd:day.end or timeout.
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const H = preload("res://scripts/tests/cards/C07/c07_harness.gd")
const STEPS := "res://scripts/tests/cards/C07/guide_steps.json"


func _initialize() -> void:
	var test_name := _arg("--name=", "C07_guide")
	var k16 := _arg("--steps=", "") == "k16"
	var t := T.new(self, test_name)
	t.run_async(_body.bind(t, k16))


func _body(t, k16: bool) -> void:
	var bus := CardEventBus.new()
	root.add_child(bus)
	await t.frames(1)
	await _almanac(t, bus, k16)
	await _lot_and_cezi(t, bus, k16)
	bus.queue_free()
	await t.frames(1)


func _boot(t, bus: CardEventBus, fixture: String, k16: bool) -> CardGameRoot:
	var game: CardGameRoot = load(CardIds.ROOT_SCENE).instantiate()
	game.boot({"mock": true, "bus": bus, "fixture": H.FIX + fixture + ".json", "skip_title": true})
	root.add_child(game)
	game.guide.force(true)
	game.guide.skip_fades = true
	if k16:
		game.guide.load_steps(game.engine.query(&"guide_data"))
	else:
		game.guide.load_steps(CardDB.read_json(STEPS))
	for _i in 6:
		await t.frames(1)
	return game


func _almanac(t, bus: CardEventBus, k16: bool) -> void:
	var game := await _boot(t, bus, "almanac_done", k16)
	var date: Dictionary = game.engine.view().get("date", {})
	if k16:
		t.ok(int(date.get("stage_day", 0)) >= 4, "k16 almanac stage_day_gte 4")
	bus.first_time.emit(&"almanac", {})
	game.guide.evaluate_now()
	t.eq(game.guide.active_step(), "gd.almanac", "almanac step lights")
	t.ok(t.anchor_ok(&"a.almanac"), "a.almanac")
	var wait := 4.0
	if k16:
		wait = _step_seconds(game.engine.query(&"guide_data"), "gd.almanac")
		# K16 10-22 (prototype): seconds 0 = no clock; day.end below is what ends the bubble.
		t.ok(wait == 0.0 or wait >= 12.0, "k16 almanac waits its own seconds, not 4")
		# Real done_when is cmd:day.end or timeout. Do not close a 12s step at 4s.
		bus.command_done.emit(&"day.end", {}, true)
		if game.guide.active_step() != "":
			game.guide.tick(wait)
	else:
		game.guide.tick(wait)
	t.eq(game.guide.active_step(), "", "almanac step completes")
	game.queue_free()
	await t.frames(2)


func _lot_and_cezi(t, bus: CardEventBus, k16: bool) -> void:
	var game := await _boot(t, bus, "teller_both", k16)
	var date: Dictionary = game.engine.view().get("date", {})
	if k16:
		t.ok(int(date.get("stage_day", 0)) >= 5, "k16 lot stage_day_gte 5")
	game.host.open_panel(&"fortune", {"uid": H.UID})
	await t.frames(1)
	bus.first_time.emit(&"lot", {"uid": H.UID})
	game.guide.evaluate_now()
	t.eq(game.guide.active_step(), "gd.lot", "lot step lights")
	t.ok(t.anchor_ok(&"a.fortune.lot"), "a.fortune.lot")
	var panel := game.host.top_panel() as CardFortunePanel
	panel.fast_anim = true
	H.button_by_key(panel, "c07.btn.lot").pressed.emit()
	t.eq(game.guide.active_step(), "", "lot step completes on fortune.lot")
	H.button_by_key(panel, "c07.btn.ok").pressed.emit()
	await t.frames(2)
	game.host.open_panel(&"fortune", {"uid": H.UID})
	await t.frames(1)
	bus.first_time.emit(&"cezi", {"uid": H.UID})
	game.guide.evaluate_now()
	t.eq(game.guide.active_step(), "gd.cezi", "cezi step lights")
	t.ok(t.anchor_ok(&"a.fortune.cezi"), "a.fortune.cezi")
	panel = game.host.top_panel() as CardFortunePanel
	H.button_by_key(panel, "c07.btn.cezi").pressed.emit()
	t.ok(t.anchor_ok(&"a.fortune.chars"), "a.fortune.chars")
	var buttons := H.char_buttons(panel)
	t.ok(buttons.size() >= 2, "characters are on the mat")
	buttons[1].pressed.emit()
	t.eq(game.guide.active_step(), "", "cezi step completes on fortune.cezi")
	game.queue_free()
	await t.frames(2)


func _step_seconds(data: Dictionary, id: String) -> float:
	var steps: Array = data.get("steps", [])
	for step in steps:
		if typeof(step) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = step
		if str(row.get("id", "")) == id:
			return float(row.get("seconds", 0))
	return 0.0


func _arg(prefix: String, fallback: String) -> String:
	for a in OS.get_cmdline_user_args():
		if str(a).begins_with(prefix):
			return str(a).substr(prefix.length())
	return fallback
