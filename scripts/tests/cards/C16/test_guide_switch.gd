# 指引开关：force 高于命令行，命令行高于设置。关着不亮、不记 shown_log、不发 ui.guide。
# 亮着时关掉会收起。game.load 之后按 guide_progress 重建，完成过的不再亮。
# 主人 C16。合同：docs/cards/CARDS_INTERFACES.md §7.10.7、§7.10.8。
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const Fake = preload("res://scripts/tests/cards/C16/fake_engine.gd")


func _initialize() -> void:
	var t := T.new(self, "C16_guide_switch")
	t.run_async(_body.bind(t))


func _body(t) -> void:
	await _off(t, "setting")
	await _off(t, "cmdline")
	await _off(t, "force")
	await _priority(t)
	await _hide_now(t)
	await _reload(t)
	await t.frames(2)


func _off(t, how: String) -> void:
	var ctx = await _rig()
	if how == "setting":
		ctx.guide.set_enabled(false)
	elif how == "cmdline":
		ctx.guide.set_cmdline("off")
		ctx.guide.set_enabled(true)
	else:
		ctx.guide.force(false)
		ctx.guide.set_cmdline("on")
		ctx.guide.set_enabled(true)
	_fire(ctx)
	ctx.guide.evaluate_now()
	t.eq(ctx.guide.active_step(), "", how + " off lights nothing")
	t.eq(ctx.guide.shown_log.size(), 0, how + " off keeps shown_log empty")
	await t.frames(1)
	t.ok(not _sent_guide(ctx.eng), how + " off sends no ui.guide")
	_free(ctx)


func _priority(t) -> void:
	var forced = await _rig()
	forced.guide.set_enabled(false)
	forced.guide.set_cmdline("off")
	forced.guide.force(true)
	_fire(forced)
	forced.guide.evaluate_now()
	t.eq(forced.guide.active_step(), "deal", "force on beats cmdline and the setting")
	_free(forced)
	var cmd = await _rig()
	cmd.guide.set_enabled(false)
	cmd.guide.set_cmdline("on")
	_fire(cmd)
	cmd.guide.evaluate_now()
	t.eq(cmd.guide.active_step(), "deal", "cmdline on beats the setting")
	_free(cmd)


func _hide_now(t) -> void:
	var ctx = await _rig()
	ctx.guide.set_enabled(true)
	_fire(ctx)
	ctx.guide.evaluate_now()
	t.eq(ctx.guide.active_step(), "deal", "step is showing")
	ctx.guide.set_enabled(false)
	t.eq(ctx.guide.active_step(), "", "set_enabled false hides at once")
	t.eq(ctx.guide.is_enabled(), false, "guide is off")
	_free(ctx)


func _reload(t) -> void:
	var ctx = await _rig()
	ctx.eng.progress = {"deal": {"shows": 1, "status": "done", "abs_day": 1}}
	ctx.eng.firsts = {"deal": 1}
	ctx.bus.command_done.emit(&"game.load", {}, true)
	_fire(ctx)
	ctx.guide.evaluate_now()
	t.eq(ctx.guide.active_step(), "", "a done step stays dark after game.load")
	t.eq(ctx.guide.shown_log.size(), 0, "reload does not replay a finished step")
	_free(ctx)


func _fire(ctx) -> void:
	ctx.bus.first_time.emit(&"deal", {})
	ctx.bus.view_changed.emit(PackedStringArray())


func _sent_guide(eng) -> bool:
	for row in eng.sent:
		if str(row[0]) == "ui.guide":
			return true
	return false


func _rig():
	var bus := CardEventBus.new()
	root.add_child(bus)
	var eng = Fake.new()
	var rules = CardDB.read_json("res://data/cards/rules/guide.json")
	eng.data = {"steps": [{
		"id": "deal", "teacher": "brother", "anchor": "a.hand", "anchor_fallback": "",
		"trigger": {"first": "deal", "phase": "day"}, "done_when": ["ui:hand_selected", "timeout"],
		"priority": 70, "max_shows": 2, "seconds": 30, "interrupt": false,
	}], "settings": rules if typeof(rules) == TYPE_DICTIONARY else {}}
	eng.view_d = {"phase": "day", "mode": "shop", "date": {"stage": 0, "stage_day": 1, "abs_day": 1}, "hand": []}
	var holder := Control.new()
	root.add_child(holder)
	var hand := ColorRect.new()
	hand.position = Vector2(200, 400)
	hand.size = Vector2(400, 120)
	hand.color = CardTheme.color(&"paper")
	holder.add_child(hand)
	CardAnchors.register(&"a.hand", hand)
	var guide: CardGuide = load("res://scenes/cards/shell/GuideOverlay.tscn").instantiate()
	guide.skip_fades = true
	guide.set_process(false)
	holder.add_child(guide)
	guide.bind(eng, bus)
	return {"guide": guide, "bus": bus, "eng": eng, "holder": holder}


func _free(ctx) -> void:
	ctx.holder.queue_free()
	ctx.bus.queue_free()
	CardAnchors.clear()
