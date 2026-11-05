# C05：四个指引步骤会亮、会完成（gd.demand 归 C01）。锚点在 1280x720 里。
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const S = preload("res://scripts/tests/cards/C05/support.gd")


func _initialize() -> void:
	var t := T.new(self, _arg("--name=", "C05_guide"))
	t.run_async(_body.bind(t))


func _body(t) -> void:
	var k16 := _arg("--steps=", "") == "k16"
	await _step_delay(t, k16)
	await _step_people(t, k16)
	await _step_inform(t, k16)
	await _step_fail(t, k16)
	await _step_fail_fallback(t, k16)


func _boot(t, fixture: String, k16: bool) -> Array:
	var bus := CardEventBus.new()
	root.add_child(bus)
	var game := S.boot(self, bus, fixture)
	game.guide.force(true)
	game.guide.skip_fades = true
	if k16:
		game.guide.load_steps(game.engine.query(&"guide_data"))
	else:
		game.guide.load_steps(S.steps())
	await t.frames(2)
	return [game, bus]


func _ready_panel(t, game: CardGameRoot) -> CardDemandPanel:
	var panel := game.host.top_panel() as CardDemandPanel
	S.skip_dialog(panel)
	await t.frames(1)
	return panel


func _step_delay(t, k16: bool) -> void:
	var pair: Array = await _boot(t, "delay.json", k16)
	var game: CardGameRoot = pair[0]
	var bus: CardEventBus = pair[1]
	if k16:
		_finish_tiers(t, game)
	game.host.open_panel(&"demand", {"uid": "d1"})
	await t.frames(1)
	var panel := await _ready_panel(t, game)
	bus.first_time.emit(&"demand_delay", {"uid": "d1"})
	game.guide.evaluate_now()
	t.eq(game.guide.active_step(), "gd.demand_delay", "gd.demand_delay lights")
	t.ok(t.anchor_ok(&"a.demand.delay"), "delay rect")
	var delay := S.reply_button(panel, "c05.reply.delay")
	t.ok(delay != null, "delay reply")
	delay.pressed.emit()
	t.eq(game.guide.active_step(), "", "gd.demand_delay done")
	await _free(t, game, bus)


func _step_people(t, k16: bool) -> void:
	var pair: Array = await _boot(t, "people_return.json", k16)
	var game: CardGameRoot = pair[0]
	var bus: CardEventBus = pair[1]
	if k16:
		_finish_tiers(t, game)
	t.ok(t.anchor_ok(&"a.card@r1"), "a.card@r1 %s" % CardAnchors.rect(&"a.card@r1"))
	bus.first_time.emit(&"demand_people_return", {"uid": "r1"})
	game.guide.evaluate_now()
	t.eq(game.guide.active_step(), "gd.demand_people", "gd.demand_people lights")
	if k16:
		game.table._on_card_pressed("r1")
	else:
		game.host.open_panel(&"slots", {"uid": "r1"})
	await t.frames(1)
	t.eq(game.guide.active_step(), "", "gd.demand_people done")
	await _free(t, game, bus)


func _step_inform(t, k16: bool) -> void:
	var pair: Array = await _boot(t, "info.json", k16)
	var game: CardGameRoot = pair[0]
	var bus: CardEventBus = pair[1]
	if k16:
		_finish_tiers(t, game)
	game.host.open_panel(&"demand", {"uid": "i_inform"})
	await t.frames(1)
	var panel := await _ready_panel(t, game)
	bus.first_time.emit(&"demand_inform", {"uid": "i_inform"})
	game.guide.evaluate_now()
	t.eq(game.guide.active_step(), "gd.demand_inform", "gd.demand_inform lights")
	t.ok(t.anchor_ok(&"a.demand.modes"), "inform modes")
	var inform := S.reply_button(panel, "c05.mode.inform")
	t.ok(inform != null, "inform reply")
	inform.pressed.emit()
	if k16:
		var submit: Button = S.reply_button(panel, "c05.reply.submit")
		t.ok(submit != null, "submit reply")
		if submit != null:
			submit.pressed.emit()
	t.eq(game.guide.active_step(), "", "gd.demand_inform done")
	await _free(t, game, bus)


func _step_fail(t, k16: bool) -> void:
	var pair: Array = await _boot(t, "fail.json", k16)
	var game: CardGameRoot = pair[0]
	var bus: CardEventBus = pair[1]
	if k16:
		_finish_tiers(t, game)
	t.ok(t.anchor_ok(&"a.demand.tier"), "fail tier")
	bus.first_time.emit(&"demand_fail", {"uid": "f1"})
	game.guide.evaluate_now()
	t.eq(game.guide.active_step(), "gd.demand_fail", "gd.demand_fail lights")
	t.eq(str(game.guide._anchor_now), "a.demand.tier", "fail uses tier")
	_end_step(game, k16)
	t.eq(game.guide.active_step(), "", "gd.demand_fail done")
	await _free(t, game, bus)


func _step_fail_fallback(t, k16: bool) -> void:
	var pair: Array = await _boot(t, "people_return.json", k16)
	var game: CardGameRoot = pair[0]
	var bus: CardEventBus = pair[1]
	if k16:
		_finish_tiers(t, game)
	S.mount_stage(game, game.engine.view())
	await t.frames(1)
	t.ok(not CardAnchors.has(&"a.demand.tier"), "no tier when the slip is gone")
	t.ok(t.anchor_ok(&"a.scene.notice"), "notice fallback rect")
	bus.first_time.emit(&"demand_fail", {"uid": "r1"})
	game.guide.evaluate_now()
	t.eq(game.guide.active_step(), "gd.demand_fail", "fallback lights")
	t.eq(str(game.guide._anchor_now), "a.scene.notice", "fallback anchor")
	_end_step(game, k16)
	t.eq(game.guide.active_step(), "", "fallback done")
	await _free(t, game, bus)


# Day 7 lights gd.tiers (phase day, stage_day_gte 7) before any demand step.
# Its done_when is cmd:day.end. The fixture answers that command with ok.
func _finish_tiers(t, game: CardGameRoot) -> void:
	game.guide.evaluate_now()
	t.eq(game.guide.active_step(), "gd.tiers", "gd.tiers lights")
	var ended: Dictionary = game.engine.send(&"day.end", {"confirm": true})
	t.ok(bool(ended.get("ok", false)), "day.end finishes gd.tiers")
	if game.guide.active_step() == "gd.tiers":
		_end_step(game, true)
	t.eq(game.guide.active_step(), "", "gd.tiers done")



## The test steps time out after 12 s; the K16 steps have no clock since 10-22 (prototype: a bubble stays
## until the player does the thing or presses "got it"), so they end with got it.
func _end_step(game: CardGameRoot, k16: bool) -> void:
	if k16:
		game.guide.acknowledge()
	else:
		game.guide.tick(12.0)


func _free(t, game: Node, bus: Node) -> void:
	game.queue_free()
	bus.queue_free()
	await t.frames(2)
	CardAnchors.clear()


func _arg(prefix: String, fallback: String) -> String:
	for a in OS.get_cmdline_user_args():
		if str(a).begins_with(prefix):
			return str(a).substr(prefix.length())
	return fallback
