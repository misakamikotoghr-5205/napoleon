# C04 guide: gd.d1.look, gd.d1.tiers, gd.d1.buyer, gd.redeem light and complete.
# gd.d1.ticket lights on the stage hotspot a.scene.ledger (real CardStage registration),
# falling back to the drawer tab a.tab.tickets. The 1.2 names (a.right.*) are gone since X01-b.
# --steps=k16 loads guide_data and walks each target's after chain. Prerequisite
# steps may use an auxiliary pin so the chain can move; the five C04 targets never do.
# A missing target anchor fails the step. Default steps stay on the bundled fixture.

extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const S = preload("res://scripts/tests/cards/C04/support.gd")
const STEPS := "res://scripts/tests/cards/C04/guide_steps.json"
const GUIDE := "res://scenes/cards/shell/GuideOverlay.tscn"
const TABLE := "res://scenes/cards/table/CardTable.tscn"
const C04_TARGETS := {
	"gd.d1.look": true,
	"gd.d1.tiers": true,
	"gd.d1.buyer": true,
	"gd.redeem": true,
	"gd.d1.ticket": true,
}


func _initialize() -> void:
	var t := T.new(self, _arg("--name=", "C04_guide"))
	t.run_async(_body.bind(t))


func _body(t) -> void:
	var k16 := _arg("--steps=", "") == "k16"
	await _look_tiers(t, k16)
	await _buyer(t, k16)
	await _redeem(t, k16)
	await _ticket(t, k16)
	if k16:
		await _reject_fake_targets(t)


func _look_tiers(t, k16: bool) -> void:
	var ctx: Dictionary = S.boot(self, "pawn")
	await t.frames(1)
	var panel := S.play(ctx, "c0002")
	var guide := _guide(ctx.mock, ctx.bus, k16)
	await t.frames(2)
	if k16:
		_k16_until(t, guide, ctx.bus, ctx.mock, "gd.d1.look", "c0002")
	ctx.bus.first_time.emit(&"counter", {"uid": "c0002"})
	guide.evaluate_now()
	t.eq(guide.active_step(), "gd.d1.look", "look step lights")
	for a in [&"a.counter.look", &"a.counter.tier.harsh", &"a.counter.tier.fair", &"a.counter.tier.kind",
			&"a.counter.item", &"a.counter.reply"]:
		t.ok(t.anchor_ok(a), "pawn anchor %s" % a)
	t.ok(not CardAnchors.has(&"a.counter.stock"), "pawn does not register stock")
	t.ok(not CardAnchors.has(&"a.counter.redeem"), "pawn does not register redeem")
	S.button(panel, "LookButton").pressed.emit()
	await t.frames(1)
	t.ok(S.cmds(ctx.mock).any(func(r: Array) -> bool: return r[0] == "mg.request"), "look sends mg.request")
	if k16:
		_k16_until(t, guide, ctx.bus, ctx.mock, "gd.d1.tiers", "c0002")
	guide.evaluate_now()
	t.eq(guide.active_step(), "gd.d1.tiers", "tiers step lights after look")
	t.ok(t.anchor_ok(&"a.counter.tier.fair"), "fair anchor while tiers step is up")
	S.button(panel, "TierFair").pressed.emit()
	await t.frames(1)
	t.eq(guide.active_step(), "", "offer completes the tiers step")
	S.free_all([guide])
	S.free_ctx(ctx)
	await t.frames(2)


func _buyer(t, k16: bool) -> void:
	var ctx: Dictionary = S.boot(self, "buy")
	await t.frames(1)
	var panel := S.play(ctx, "c0004")
	var guide := _guide(ctx.mock, ctx.bus, k16)
	await t.frames(2)
	S.button(panel, "PickButton").pressed.emit()
	await t.frames(2)
	if k16:
		_k16_until(t, guide, ctx.bus, ctx.mock, "gd.d1.buyer", "c0004")
		_hide_anchor(&"a.btn.close_day")
	ctx.bus.first_time.emit(&"buyer", {"uid": "c0004"})
	guide.evaluate_now()
	t.eq(guide.active_step(), "gd.d1.buyer", "buyer step lights on the shelf")
	t.ok(t.anchor_ok(&"a.counter.stock"), "buyer stock anchor")
	S.button(panel, "Stock_I010").pressed.emit()
	await t.frames(1)
	t.eq(guide.active_step(), "", "pick_stock completes the buyer step")
	S.free_all([guide])
	S.free_ctx(ctx)
	await t.frames(2)


func _redeem(t, k16: bool) -> void:
	var ctx: Dictionary = S.boot(self, "redeem_by_rule")
	await t.frames(1)
	var panel := S.play(ctx, "c0008")
	var guide := _guide(ctx.mock, ctx.bus, k16)
	await t.frames(2)
	if k16:
		_k16_until(t, guide, ctx.bus, ctx.mock, "gd.redeem", "c0008")
	ctx.bus.first_time.emit(&"redeem", {"uid": "c0008"})
	guide.evaluate_now()
	t.eq(guide.active_step(), "gd.redeem", "redeem step lights")
	t.ok(t.anchor_ok(&"a.counter.redeem"), "redeem anchor")
	S.button(panel, "Redeem_by_rule").pressed.emit()
	await t.frames(1)
	t.eq(guide.active_step(), "", "redeem command completes the step")
	S.free_all([guide])
	S.free_ctx(ctx)
	await t.frames(2)


func _ticket(t, k16: bool) -> void:
	# 真 CardGameRoot：场景层 ledger / 标签 tickets，不用空 Control 假热点。
	var ctx: Dictionary = S.boot(self, "pawn")
	await t.frames(3)
	var game: CardGameRoot = ctx.game
	var bus: CardEventBus = ctx.bus
	var mock: MockCardEngine = ctx.mock
	t.ok(game.stage != null, "root has CardStage")
	t.ok(t.anchor_ok(&"a.scene.ledger"), "real a.scene.ledger from stage hotspot")
	t.ok(not CardIds.is_known_anchor("a.right.tickets") and not CardAnchors.has(&"a.right.tickets"),
		"the 1.2 name a.right.tickets is gone")
	t.ok(t.anchor_ok(&"a.tab.tickets"), "real a.tab.tickets from drawer tab")
	var guide := _guide(mock, bus, k16)
	if k16:
		_k16_until(t, guide, bus, mock, "gd.d1.ticket", "c0002")
	bus.first_time.emit(&"ticket", {"no": 1})
	guide.evaluate_now()
	t.eq(guide.active_step(), "gd.d1.ticket", "gd.d1.ticket lights on real ledger/tab")
	var dwell := 8.0
	if k16:
		dwell = _k16_seconds(mock, "gd.d1.ticket", 20.0)
	if dwell <= 0.0:
		# K16 10-22 (prototype): seconds 0 = no clock; the bubble's "got it" ends the step.
		guide.acknowledge()
	else:
		guide.tick(dwell)
	t.eq(guide.active_step(), "", "ticket step can complete")
	S.free_all([guide])
	S.free_ctx(ctx)
	await t.frames(2)


func _guide(mock: MockCardEngine, bus: CardEventBus, k16: bool) -> CardGuide:
	var guide: CardGuide = load(GUIDE).instantiate()
	root.add_child(guide)
	guide.bind(mock, bus)
	guide.force(true)
	guide.skip_fades = true
	if k16:
		guide.load_steps(mock.query(&"guide_data"))
	else:
		guide.load_steps(CardDB.read_json(STEPS))
	return guide


# Complete every ancestor of target, then arm target (first / panel / anchor) without finishing it.
func _k16_until(t, guide: CardGuide, bus: CardEventBus, mock: MockCardEngine, target: String, uid: String, arm_target: bool = true) -> void:
	var by_id: Dictionary = _k16_index(mock)
	var chain: Array = []
	var seen := {}
	_k16_ancestors(by_id, target, chain, seen)
	for id in chain:
		var sid := str(id)
		if bool(guide._is_done(sid)):
			continue
		var step: Dictionary = by_id.get(sid, {})
		_k16_arm(guide, bus, mock, step, uid, true)
		if guide.active_step() != sid:
			guide.tick(0.0)
		if guide.active_step() != sid:
			if bool(guide._is_done(sid)):
				continue
			t.eq(guide.active_step(), sid, "k16 chain " + sid)
			return
		_k16_finish(guide, bus, step)
		if guide.active_step() == sid:
			t.eq(guide.active_step(), "", "k16 chain done " + sid)
			return
	var target_step: Dictionary = by_id.get(target, {})
	if arm_target and not target_step.is_empty():
		_k16_arm(guide, bus, mock, target_step, uid, not C04_TARGETS.has(target))
	_k16_restore(guide, bus, mock)


func _k16_ancestors(by_id: Dictionary, id: String, out: Array, seen: Dictionary) -> void:
	var step: Dictionary = by_id.get(id, {})
	var after: Array = []
	var raw: Variant = step.get("trigger", {})
	if typeof(raw) == TYPE_DICTIONARY:
		var trig: Dictionary = raw
		if typeof(trig.get("after", [])) == TYPE_ARRAY:
			after = trig.get("after", [])
	for item in after:
		var aid := str(item)
		if seen.has(aid):
			continue
		_k16_ancestors(by_id, aid, out, seen)
		if seen.has(aid):
			continue
		seen[aid] = true
		out.append(aid)


func _k16_arm(guide: CardGuide, bus: CardEventBus, mock: MockCardEngine, step: Dictionary, uid: String, pin_aux: bool) -> void:
	var trig: Dictionary = {}
	if typeof(step.get("trigger", {})) == TYPE_DICTIONARY:
		trig = step["trigger"]
	var phase := _k16_phase(trig, str(mock.view().get("phase", "day")))
	bus.phase_changed.emit(&"", StringName(phase))
	var mode := str(mock.view().get("mode", "shop"))
	if trig.has("mode"):
		mode = str(trig["mode"])
	guide._view["mode"] = mode
	_k16_anchor(guide, step, uid, pin_aux)
	if trig.has("first") and str(trig["first"]) != "":
		bus.first_time.emit(StringName(str(trig["first"])), {"uid": uid})
	if trig.has("panel") and str(trig["panel"]) != "" and guide.active_step() == "":
		bus.ui_event.emit(&"panel_opened", {"kind": str(trig["panel"])})


func _k16_finish(guide: CardGuide, bus: CardEventBus, step: Dictionary) -> void:
	var id := str(step.get("id", ""))
	var done: Array = []
	if typeof(step.get("done_when", [])) == TYPE_ARRAY:
		done = step["done_when"]
	for tok in done:
		var token := str(tok)
		if token == "" or token == "timeout":
			continue
		if guide.active_step() != id:
			return
		_k16_emit(bus, token)
		if guide.active_step() != id:
			return
	if guide.active_step() == id:
		guide.tick(_k16_step_seconds(step, 16.0))


func _k16_emit(bus: CardEventBus, token: String) -> void:
	if token.begins_with("cmd:"):
		bus.command_done.emit(StringName(token.substr(4)), {}, true)
	elif token.begins_with("ui:"):
		bus.ui_event.emit(StringName(token.substr(3)), {})
	elif token.begins_with("panel:"):
		bus.ui_event.emit(&"panel_opened", {"kind": token.substr(6)})
	elif token.begins_with("first:"):
		bus.first_time.emit(StringName(token.substr(6)), {})


func _k16_anchor(guide: CardGuide, step: Dictionary, uid: String, pin_aux: bool) -> void:
	# pin_aux is false for the five C04 targets. Earlier steps may still pin.
	if not pin_aux:
		return
	var primary := _k16_fill(str(step.get("anchor", "")), uid)
	var spare := _k16_fill(str(step.get("anchor_fallback", "")), uid)
	if _k16_alive(primary) or _k16_alive(spare):
		return
	var id := primary if primary != "" else spare
	_k16_pin(guide, id)


func _k16_pin(guide: CardGuide, id: String) -> void:
	if id == "" or id.find("{") >= 0 or _k16_alive(id):
		return
	var pin := _k16_chip(guide)
	CardAnchors.register(StringName(id), pin)


func _k16_chip(guide: CardGuide) -> ColorRect:
	var pin := ColorRect.new()
	pin.color = Color(0, 0, 0, 0)
	pin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pin.position = Vector2(20, 20)
	guide.add_child(pin)
	pin.size = Vector2(36, 36)
	return pin


func _k16_alive(id: String) -> bool:
	if id == "":
		return false
	return CardAnchors.has(StringName(id))


func _k16_fill(pat: String, uid: String) -> String:
	if pat.find("{uid}") < 0:
		return pat
	if uid == "":
		return ""
	return pat.replace("{uid}", uid)


func _k16_phase(trig: Dictionary, fallback: String) -> String:
	if not trig.has("phase"):
		return fallback
	var ph = trig["phase"]
	if typeof(ph) == TYPE_ARRAY:
		if (ph as Array).is_empty():
			return fallback
		return str((ph as Array)[0])
	return str(ph)


func _k16_restore(guide: CardGuide, bus: CardEventBus, mock: MockCardEngine) -> void:
	var phase := str(mock.view().get("phase", "day"))
	bus.phase_changed.emit(&"", StringName(phase))
	guide._view["mode"] = str(mock.view().get("mode", "shop"))


func _k16_index(mock: MockCardEngine) -> Dictionary:
	var data: Dictionary = mock.query(&"guide_data")
	var out := {}
	var steps: Array = data.get("steps", [])
	for step in steps:
		if typeof(step) != TYPE_DICTIONARY:
			continue
		out[str(step.get("id", ""))] = step
	return out


func _k16_seconds(mock: MockCardEngine, id: String, fallback: float) -> float:
	var step: Dictionary = _k16_index(mock).get(id, {})
	return _k16_step_seconds(step, fallback)


func _k16_step_seconds(step: Dictionary, fallback: float) -> float:
	if not step.has("seconds"):
		return fallback
	return float(step["seconds"])


func _mount_ledger_stage(bus: CardEventBus) -> Control:
	var stage: Control = load(CardIds.widget_scene(&"stage")).instantiate()
	stage.set("bus", bus)
	root.add_child(stage)
	if stage.has_method("refresh"):
		stage.refresh({
			"phase": "day",
			"mode": "shop",
			"date": {"y": 1938, "m": 3, "d": 2, "abs_day": 1},
			"stage": {"set": "counter", "time": "day"},
		})
	return stage


# Hide each target's real anchor after its prerequisites are done.
# Arming the target must not invent a pin, so the step stays dark.
func _reject_fake_targets(t) -> void:
	await _reject_fake_look(t)
	await _reject_fake_tiers(t)
	await _reject_fake_buyer(t)
	await _reject_fake_redeem(t)
	await _reject_fake_ticket(t)


func _reject_fake_look(t) -> void:
	var ctx: Dictionary = S.boot(self, "pawn")
	await t.frames(1)
	S.play(ctx, "c0002")
	var guide := _guide(ctx.mock, ctx.bus, true)
	await t.frames(2)
	t.ok(t.anchor_ok(&"a.counter.look"), "real look anchor before hide")
	_k16_until(t, guide, ctx.bus, ctx.mock, "gd.d1.look", "c0002", false)
	_hide_anchor(&"a.counter.look")
	_arm_target(guide, ctx.bus, ctx.mock, "gd.d1.look", "c0002")
	ctx.bus.first_time.emit(&"counter", {"uid": "c0002"})
	guide.evaluate_now()
	_expect_dark(t, guide, "gd.d1.look", [&"a.counter.look"])
	S.free_all([guide])
	S.free_ctx(ctx)
	await t.frames(2)


func _reject_fake_tiers(t) -> void:
	var ctx: Dictionary = S.boot(self, "pawn")
	await t.frames(1)
	var panel := S.play(ctx, "c0002")
	var guide := _guide(ctx.mock, ctx.bus, true)
	await t.frames(2)
	_k16_until(t, guide, ctx.bus, ctx.mock, "gd.d1.look", "c0002")
	ctx.bus.first_time.emit(&"counter", {"uid": "c0002"})
	guide.evaluate_now()
	S.button(panel, "LookButton").pressed.emit()
	await t.frames(1)
	t.ok(t.anchor_ok(&"a.counter.tier.fair"), "real fair anchor before hide")
	_k16_until(t, guide, ctx.bus, ctx.mock, "gd.d1.tiers", "c0002", false)
	_hide_anchor(&"a.counter.tier.fair")
	_arm_target(guide, ctx.bus, ctx.mock, "gd.d1.tiers", "c0002")
	guide.evaluate_now()
	_expect_dark(t, guide, "gd.d1.tiers", [&"a.counter.tier.fair"])
	S.free_all([guide])
	S.free_ctx(ctx)
	await t.frames(2)


func _reject_fake_buyer(t) -> void:
	var ctx: Dictionary = S.boot(self, "buy")
	await t.frames(1)
	var panel := S.play(ctx, "c0004")
	var guide := _guide(ctx.mock, ctx.bus, true)
	await t.frames(2)
	S.button(panel, "PickButton").pressed.emit()
	await t.frames(2)
	t.ok(t.anchor_ok(&"a.counter.stock"), "real stock anchor before hide")
	_k16_until(t, guide, ctx.bus, ctx.mock, "gd.d1.buyer", "c0004", false)
	_hide_anchor(&"a.counter.stock")
	_hide_anchor(&"a.tab.shelf")
	_arm_target(guide, ctx.bus, ctx.mock, "gd.d1.buyer", "c0004")
	ctx.bus.first_time.emit(&"buyer", {"uid": "c0004"})
	guide.evaluate_now()
	_expect_dark(t, guide, "gd.d1.buyer", [&"a.counter.stock", &"a.tab.shelf"])
	S.free_all([guide])
	S.free_ctx(ctx)
	await t.frames(2)


func _reject_fake_redeem(t) -> void:
	var ctx: Dictionary = S.boot(self, "redeem_by_rule")
	await t.frames(1)
	S.play(ctx, "c0008")
	var guide := _guide(ctx.mock, ctx.bus, true)
	await t.frames(2)
	t.ok(t.anchor_ok(&"a.counter.redeem"), "real redeem anchor before hide")
	_k16_until(t, guide, ctx.bus, ctx.mock, "gd.redeem", "c0008", false)
	_hide_anchor(&"a.counter.redeem")
	_arm_target(guide, ctx.bus, ctx.mock, "gd.redeem", "c0008")
	ctx.bus.first_time.emit(&"redeem", {"uid": "c0008"})
	guide.evaluate_now()
	_expect_dark(t, guide, "gd.redeem", [&"a.counter.redeem"])
	S.free_all([guide])
	S.free_ctx(ctx)
	await t.frames(2)


func _reject_fake_ticket(t) -> void:
	var bus := CardEventBus.new()
	root.add_child(bus)
	var mock := MockCardEngine.new(bus)
	mock.load_fixture(S.path("pawn"))
	var table: Control = load(TABLE).instantiate()
	table.bus = bus
	root.add_child(table)
	await t.frames(2)
	table.refresh({
		"phase": "day", "mode": "shop",
		"date": {"y": 1938, "m": 3, "d": 2, "abs_day": 1},
		"notice": {"weather": "clear", "news": [], "almanac": {}},
		"money": {"amount": 340}, "rep_tier": 0, "heat_tier": 0,
		"tickets": [{"no": 1}], "hand": [], "contacts": [], "kept": [], "demands": [],
	})
	var stage := _mount_ledger_stage(bus)
	var guide := _guide(mock, bus, true)
	await t.frames(1)
	t.ok(t.anchor_ok(&"a.scene.ledger"), "real ledger anchor before hide")
	_k16_until(t, guide, bus, mock, "gd.d1.ticket", "c0002", false)
	_hide_anchor(&"a.scene.ledger")
	_hide_anchor(&"a.tab.tickets")
	_arm_target(guide, bus, mock, "gd.d1.ticket", "c0002")
	bus.first_time.emit(&"ticket", {"no": 1})
	guide.evaluate_now()
	_expect_dark(t, guide, "gd.d1.ticket", [&"a.scene.ledger", &"a.tab.tickets"])
	S.free_all([guide, table, stage, bus])
	await t.frames(2)


func _arm_target(guide: CardGuide, bus: CardEventBus, mock: MockCardEngine, target: String, uid: String) -> void:
	var step: Dictionary = _k16_index(mock).get(target, {})
	if step.is_empty():
		return
	_k16_arm(guide, bus, mock, step, uid, false)


func _expect_dark(t, guide: CardGuide, step_id: String, anchors: Array) -> void:
	t.ok(guide.active_step() != step_id, step_id + " stays dark without its real anchor")
	for id in anchors:
		var anchor := StringName(str(id))
		t.ok(not CardAnchors.has(anchor), "no fake pin for " + str(anchor))
		t.ok(not t.anchor_ok(anchor), "no fake rect for " + str(anchor))


func _hide_anchor(id: StringName) -> void:
	var rows: Array = CardAnchors._table.get(id, [])
	for row in rows:
		var obj: Object = instance_from_id(int((row as Dictionary).get("node", 0)))
		if obj is CanvasItem:
			(obj as CanvasItem).visible = false


func _arg(prefix: String, fallback: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with(prefix):
			return a.substr(prefix.length())
	return fallback
