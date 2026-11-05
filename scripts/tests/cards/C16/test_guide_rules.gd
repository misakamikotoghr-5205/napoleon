# 指引规则单测：priority、同优先级文件顺序、interrupt、max_shows、间隔、每天上限、
# 自动完成、备用锚点、锚点消失、timeout、after、hand_clear、panel、cond、{uid}。
# 主人 C16。合同：docs/cards/CARDS_INTERFACES.md §7.10.7。
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const Fake = preload("res://scripts/tests/cards/C16/fake_engine.gd")


func _initialize() -> void:
	var t := T.new(self, "C16_guide_rules")
	t.run_async(_body.bind(t))


func _body(t) -> void:
	await _priority(t)
	await _file_order(t)
	await _interrupt(t)
	await _max_shows(t)
	await _gap(t)
	await _per_day(t)
	await _auto_done(t)
	await _fallback(t)
	await _anchor_gone(t)
	await _timeout_done(t)
	await _timeout_retry(t)
	await _after_chain(t)
	await _hand_clear(t)
	await _panel(t)
	await _cond(t)
	await _uid(t)
	await _phase_array(t)
	await t.frames(2)


func _priority(t) -> void:
	var ctx = await _rig(t, [_step("low", 10), _step("high", 80)], {"gap_ms": 0})
	ctx.guide.evaluate_now()
	t.eq(ctx.guide.active_step(), "high", "higher priority lights first")
	_free(ctx)


func _file_order(t) -> void:
	var ctx = await _rig(t, [_step("first", 50), _step("second", 50)], {"gap_ms": 0})
	ctx.guide.evaluate_now()
	t.eq(ctx.guide.active_step(), "first", "same priority keeps file order")
	_free(ctx)


func _interrupt(t) -> void:
	var low := _step("low", 10)
	var high := _step("high", 90)
	high["interrupt"] = true
	high["trigger"] = {"first": "gold"}
	var ctx = await _rig(t, [low, high], {"gap_ms": 0})
	ctx.guide.evaluate_now()
	t.eq(ctx.guide.active_step(), "low", "quiet step lights before the interrupt")
	ctx.bus.first_time.emit(&"gold", {})
	ctx.guide.evaluate_now()
	t.eq(ctx.guide.active_step(), "high", "interrupt replaces a lower step")
	t.eq(Array(ctx.guide.shown_log), ["high"], "interrupted step is not counted as shown")
	await t.frames(1)
	var done_low := false
	for row in ctx.eng.sent:
		if str(row[0]) == "ui.guide" and str(row[1].get("step", "")) == "low" and str(row[1].get("status", "")) == "done":
			done_low = true
	t.ok(not done_low, "interrupted step does not send done")
	ctx.bus.ui_event.emit(&"hand_selected", {})
	ctx.guide.evaluate_now()
	t.eq(ctx.guide.active_step(), "low", "interrupted step can light again")
	_free(ctx)


func _max_shows(t) -> void:
	var s := _step("again", 50)
	s["seconds"] = 1
	s["max_shows"] = 2
	s["done_when"] = ["ui:never"]
	var ctx = await _rig(t, [s], {"gap_ms": 0, "default_seconds": 1})
	ctx.guide.skip_fades = false
	ctx.guide.set_process(false)
	ctx.guide.evaluate_now()
	ctx.guide.tick(1.0)
	t.eq(ctx.guide.active_step(), "", "timeout without the token hides the step")
	ctx.guide.tick(0.01)
	t.eq(ctx.guide.active_step(), "again", "step lights a second time")
	ctx.guide.tick(1.0)
	ctx.guide.tick(0.01)
	t.eq(ctx.guide.active_step(), "", "max_shows stops a third light")
	t.eq(ctx.guide.shown_log.size(), 2, "two shows were logged")
	_free(ctx)


func _gap(t) -> void:
	var a := _step("a", 80)
	a["done_when"] = ["ui:go"]
	var b := _step("b", 10)
	var ctx = await _rig(t, [a, b], {"gap_ms": 2000})
	ctx.guide.skip_fades = false
	ctx.guide.set_process(false)
	ctx.guide.evaluate_now()
	t.eq(ctx.guide.active_step(), "a", "first step lights")
	ctx.bus.ui_event.emit(&"go", {})
	ctx.guide.tick(1.0)
	t.eq(ctx.guide.active_step(), "", "gap blocks the next step")
	ctx.guide.tick(1.0)
	t.eq(ctx.guide.active_step(), "b", "step lights after gap_ms")
	_free(ctx)


func _per_day(t) -> void:
	var ctx = await _rig(t, [_step("a", 50), _step("b", 40)], {"gap_ms": 0, "max_new_per_day": 1})
	ctx.eng.view_d = _day(1)
	ctx.guide.evaluate_now()
	t.eq(ctx.guide.active_step(), "a", "first new step of the day")
	ctx.bus.ui_event.emit(&"hand_selected", {})
	ctx.guide.evaluate_now()
	t.eq(ctx.guide.active_step(), "", "daily cap holds the next step")
	ctx.eng.view_d = _day(2)
	ctx.bus.view_changed.emit(PackedStringArray())
	ctx.guide.evaluate_now()
	t.eq(ctx.guide.active_step(), "b", "a new day resets the cap")
	_free(ctx)


func _auto_done(t) -> void:
	var s := _step("late", 50)
	s["trigger"] = {"first": "deal"}
	s["done_when"] = ["first:person"]
	var ctx = await _rig(t, [s], {"gap_ms": 0})
	ctx.bus.first_time.emit(&"person", {})
	ctx.bus.first_time.emit(&"deal", {})
	ctx.guide.evaluate_now()
	t.eq(ctx.guide.active_step(), "", "already-satisfied first does not light")
	t.eq(ctx.guide.shown_log.size(), 0, "auto-done is not logged as shown")
	await t.frames(1)
	var shown := false
	var done := false
	for row in ctx.eng.sent:
		if str(row[0]) != "ui.guide" or str(row[1].get("step", "")) != "late":
			continue
		if str(row[1].get("status", "")) == "shown":
			shown = true
		if str(row[1].get("status", "")) == "done":
			done = true
	t.ok(done and not shown, "auto-done sends done only")
	_free(ctx)


func _fallback(t) -> void:
	var s := _step("fb", 50)
	s["trigger"] = {"first": "person"}
	s["anchor"] = "a.card@{uid}"
	s["anchor_fallback"] = "a.hand"
	var ctx = await _rig(t, [s], {"gap_ms": 0})
	ctx.bus.first_time.emit(&"person", {"uid": "c0007"})
	ctx.guide.evaluate_now()
	t.eq(str(ctx.guide._anchor_id), "a.hand", "missing primary anchor uses the fallback")
	_free(ctx)


func _anchor_gone(t) -> void:
	var ctx = await _rig(t, [_step("gone", 50)], {"gap_ms": 0})
	ctx.guide.evaluate_now()
	t.eq(ctx.guide.active_step(), "gone", "step lights on the anchor")
	ctx.anchor.visible = false
	ctx.guide.tick(0.1)
	t.eq(ctx.guide.active_step(), "", "lost anchor fades the step")
	t.eq(ctx.guide.shown_log.size(), 0, "lost anchor does not count as shown")
	await t.frames(1)
	var done := false
	for row in ctx.eng.sent:
		if str(row[0]) == "ui.guide" and str(row[1].get("status", "")) == "done":
			done = true
	t.ok(not done, "lost anchor does not complete")
	ctx.anchor.visible = true
	ctx.guide.evaluate_now()
	t.eq(ctx.guide.active_step(), "gone", "step can light again when the anchor returns")
	_free(ctx)


func _timeout_done(t) -> void:
	var s := _step("wait", 50)
	s["seconds"] = 1
	s["done_when"] = ["timeout"]
	var ctx = await _rig(t, [s], {"gap_ms": 0})
	ctx.guide.evaluate_now()
	ctx.guide.tick(1.0)
	t.eq(ctx.guide.active_step(), "", "timeout completes the step")
	await t.frames(1)
	var done := false
	for row in ctx.eng.sent:
		if str(row[0]) == "ui.guide" and str(row[1].get("step", "")) == "wait" and str(row[1].get("status", "")) == "done":
			done = true
	t.ok(done, "timeout sends done")
	t.eq(Array(ctx.guide.shown_log), ["wait"], "timeout still counts as shown")
	_free(ctx)


func _timeout_retry(t) -> void:
	var s := _step("soft", 50)
	s["seconds"] = 1
	s["done_when"] = ["ui:never"]
	s["max_shows"] = 3
	var ctx = await _rig(t, [s], {"gap_ms": 0})
	ctx.guide.evaluate_now()
	ctx.guide.tick(1.0)
	t.eq(ctx.guide.active_step(), "", "bare timeout hides without done")
	await t.frames(1)
	var done := false
	for row in ctx.eng.sent:
		if str(row[0]) == "ui.guide" and str(row[1].get("status", "")) == "done":
			done = true
	t.ok(not done, "bare timeout does not send done")
	t.eq(ctx.guide.shown_log.size(), 1, "bare timeout counts as one show")
	_free(ctx)


func _after_chain(t) -> void:
	var a := _step("a", 50)
	var b := _step("b", 50)
	b["trigger"] = {"after": ["a"]}
	var ctx = await _rig(t, [a, b], {"gap_ms": 0})
	ctx.guide.evaluate_now()
	t.eq(ctx.guide.active_step(), "a", "after-chain waits")
	ctx.bus.ui_event.emit(&"hand_selected", {})
	ctx.guide.evaluate_now()
	t.eq(ctx.guide.active_step(), "b", "next step lights after the previous one is done")
	_free(ctx)


func _hand_clear(t) -> void:
	var s := _step("close", 50)
	s["trigger"] = {"hand_clear": true, "phase": "day"}
	var ctx = await _rig(t, [s], {"gap_ms": 0})
	ctx.eng.view_d = _day(1)
	ctx.eng.view_d["hand"] = [{"uid": "c0002", "must_resolve": true, "gold": false}]
	ctx.bus.view_changed.emit(PackedStringArray())
	ctx.guide.evaluate_now()
	t.eq(ctx.guide.active_step(), "", "must-resolve card blocks hand_clear")
	ctx.eng.view_d["hand"] = []
	ctx.bus.view_changed.emit(PackedStringArray())
	ctx.guide.evaluate_now()
	t.eq(ctx.guide.active_step(), "close", "empty must-resolve hand lets the step light")
	_free(ctx)


func _panel(t) -> void:
	var s := _step("look", 50)
	s["trigger"] = {"panel": "counter"}
	s["done_when"] = ["ui:later"]
	var ctx = await _rig(t, [s], {"gap_ms": 0})
	ctx.guide.evaluate_now()
	t.eq(ctx.guide.active_step(), "", "closed panel blocks the step")
	ctx.bus.ui_event.emit(&"panel_opened", {"kind": "counter"})
	ctx.guide.evaluate_now()
	t.eq(ctx.guide.active_step(), "look", "open panel lets the step light")
	_free(ctx)


func _cond(t) -> void:
	var s := _step("flagged", 50)
	s["trigger"] = {"cond": {"flag": "x"}}
	var ctx = await _rig(t, [s], {"gap_ms": 0})
	ctx.eng.conds["flagged"] = false
	ctx.guide.evaluate_now()
	t.eq(ctx.guide.active_step(), "", "false guide_cond blocks the step")
	ctx.eng.conds["flagged"] = true
	ctx.guide.evaluate_now()
	t.eq(ctx.guide.active_step(), "flagged", "true guide_cond lets the step light")
	_free(ctx)


func _uid(t) -> void:
	var s := _step("who", 50)
	s["trigger"] = {"first": "person"}
	s["anchor"] = "a.card@{uid}"
	s["anchor_fallback"] = ""
	var ctx = await _rig(t, [s], {"gap_ms": 0}, "a.card@c0007")
	ctx.bus.first_time.emit(&"person", {"uid": "c0007"})
	ctx.guide.evaluate_now()
	t.eq(str(ctx.guide._anchor_id), "a.card@c0007", "{uid} is filled from first_time args")
	_free(ctx)


func _phase_array(t) -> void:
	var s := _step("eve", 50)
	s["trigger"] = {"phase": ["night", "settle"]}
	var ctx = await _rig(t, [s], {"gap_ms": 0})
	ctx.eng.view_d = _day(1)
	ctx.eng.view_d["phase"] = "day"
	ctx.bus.view_changed.emit(PackedStringArray())
	ctx.guide.evaluate_now()
	t.eq(ctx.guide.active_step(), "", "phase outside the array stays dark")
	ctx.eng.view_d["phase"] = "night"
	ctx.bus.view_changed.emit(PackedStringArray())
	ctx.guide.evaluate_now()
	t.eq(ctx.guide.active_step(), "eve", "phase array matches")
	_free(ctx)


func _step(id: String, priority: int) -> Dictionary:
	return {
		"id": id, "teacher": "", "anchor": "a.hand", "anchor_fallback": "",
		"trigger": {}, "done_when": ["ui:hand_selected", "timeout"],
		"priority": priority, "max_shows": 2, "seconds": 30, "interrupt": false,
	}


func _day(n: int) -> Dictionary:
	return {"phase": "day", "mode": "shop", "date": {"stage": 0, "stage_day": n, "abs_day": n}, "hand": []}


func _rig(t, steps: Array, settings: Dictionary, anchor_id: String = "a.hand"):
	var bus := CardEventBus.new()
	root.add_child(bus)
	var eng = Fake.new()
	var rules = CardDB.read_json("res://data/cards/rules/guide.json")
	var merged: Dictionary = rules.duplicate(true) if typeof(rules) == TYPE_DICTIONARY else {}
	merged.merge(settings, true)
	eng.data = {"steps": steps, "settings": merged}
	eng.view_d = _day(1)
	var holder := Control.new()
	holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(holder)
	var anchor := ColorRect.new()
	anchor.color = CardTheme.color(&"paper")
	anchor.position = Vector2(800, 80)
	anchor.size = Vector2(160, 80)
	anchor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(anchor)
	CardAnchors.register(StringName(anchor_id), anchor)
	var guide: CardGuide = load("res://scenes/cards/shell/GuideOverlay.tscn").instantiate()
	guide.skip_fades = true
	guide.set_process(false)
	holder.add_child(guide)
	guide.bind(eng, bus)
	guide.load_steps(eng.data)
	guide.force(true)
	await t.frames(1)
	return {"guide": guide, "bus": bus, "eng": eng, "holder": holder, "anchor": anchor}


func _free(ctx) -> void:
	ctx.holder.queue_free()
	ctx.bus.queue_free()
	CardAnchors.clear()
