# C09 guide: six steps light on their anchors and then complete.
# --name= sets the PASS line. --steps=k16 loads Mock guide_data (K16 steps).
# K16 finishes each step on the done_when it lists, or by ticking that step's seconds.
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const S = preload("res://scripts/tests/cards/C09/c09_support.gd")


func _initialize() -> void:
	var t := T.new(self, _arg("--name=", "C09_guide"))
	var k16 := _arg("--steps=", "") == "k16"
	t.run_async(_body.bind(t, k16))


func _body(t, k16: bool) -> void:
	var data := S.guide_data()
	t.eq((data.get("steps", []) as Array).size(), 6, "six guide steps")
	await _month_open(t, k16)
	await _month_close(t, k16)
	await _year(t, k16)
	await _game_over(t, k16)
	await _year_after_fallback(t, k16)
	await _retry(t, k16)
	t.finish()


func _month_open(t, k16: bool) -> void:
	var pack := S.mount(self, "res://scripts/tests/cards/C09/fixtures/month_open_three.json")
	var host := _host(pack)
	var guide := _guide(pack, k16)
	host.open_panel(&"month_open", {})
	var panel := host.top_panel() as CardMonthOpen
	var guard := 0
	while not S.goals_visible(panel) and guard < 8:
		panel.autoplay_step()
		guard += 1
	await t.frames(1)
	t.ok(t.anchor_ok(&"a.month.goals"), "gd.m.open anchor %s" % CardAnchors.rect(&"a.month.goals"))
	pack["bus"].first_time.emit(&"month_open", {})
	guide.evaluate_now()
	t.eq(guide.active_step(), "gd.m.open", "gd.m.open lights")
	if k16:
		var bus: CardEventBus = pack["bus"]
		await _k16_done(t, guide, bus, "gd.m.open")
	else:
		host.close_top()
		await t.frames(1)
	t.eq(guide.active_step(), "", "gd.m.open completes on panel_closed")
	t.ok(guide.shown_log.has("gd.m.open"), "gd.m.open was shown")
	_drop(host, guide)
	await t.frames(1)


func _month_close(t, k16: bool) -> void:
	var pack := S.mount(self, "res://scripts/tests/cards/C09/fixtures/month_close_goals.json")
	var host := _host(pack)
	var guide := _guide(pack, k16)
	host.open_panel(&"month_close", {})
	await t.frames(1)
	t.ok(t.anchor_ok(&"a.mclose.accounts"), "gd.month_close anchor %s" % CardAnchors.rect(&"a.mclose.accounts"))
	pack["bus"].first_time.emit(&"month_close", {})
	guide.evaluate_now()
	t.eq(guide.active_step(), "gd.month_close", "gd.month_close lights")
	if k16:
		var bus: CardEventBus = pack["bus"]
		await _k16_done(t, guide, bus, "gd.month_close")
	else:
		host.close_top()
		await t.frames(1)
	t.eq(guide.active_step(), "", "gd.month_close completes")
	_drop(host, guide)
	await t.frames(1)


func _year(t, k16: bool) -> void:
	var pack := S.mount(self, "res://scripts/tests/cards/C09/fixtures/year_jump_sections.json")
	var host := _host(pack)
	var guide := _guide(pack, k16)
	host.open_panel(&"year_jump", {})
	var panel := host.top_panel()
	await t.frames(1)
	t.ok(t.anchor_ok(&"a.year.forfeit"), "gd.year_jump anchor %s" % CardAnchors.rect(&"a.year.forfeit"))
	pack["bus"].first_time.emit(&"year_jump", {})
	guide.evaluate_now()
	t.eq(guide.active_step(), "gd.year_jump", "gd.year_jump lights")
	if k16:
		var bus: CardEventBus = pack["bus"]
		await _k16_done(t, guide, bus, "gd.year_jump")
	else:
		guide.tick(4.0)
	t.eq(guide.active_step(), "", "gd.year_jump completes on timeout")
	var guard := 0
	while str(panel.find_child("YearBody", true, false).get_meta("section", "")) != "after" and guard < 8:
		panel.autoplay_step()
		guard += 1
	await t.frames(1)
	t.ok(t.anchor_ok(&"a.year.after"), "gd.year_after anchor %s" % CardAnchors.rect(&"a.year.after"))
	t.ok(not CardAnchors.has(&"a.year.forfeit"), "forfeit anchor is gone on the after page")
	pack["bus"].first_time.emit(&"year_after", {})
	guide.evaluate_now()
	t.eq(guide.active_step(), "gd.year_after", "gd.year_after lights")
	if k16:
		var bus_after: CardEventBus = pack["bus"]
		await _k16_done(t, guide, bus_after, "gd.year_after")
	else:
		guide.tick(4.0)
	t.eq(guide.active_step(), "", "gd.year_after completes")
	t.ok(guide.shown_log.has("gd.year_jump") and guide.shown_log.has("gd.year_after"), "both year steps showed")
	_drop(host, guide)
	await t.frames(1)


func _game_over(t, k16: bool) -> void:
	var pack := S.mount(self, "res://scripts/tests/cards/C09/fixtures/game_over_prison.json")
	var host := _host(pack)
	var guide := _guide(pack, k16)
	var args: Dictionary = CardDB.read_json("res://scripts/tests/cards/C09/fixtures/game_over_prison.json")["view"]["open_panel"]["args"]
	host.open_panel(&"game_over", args)
	await t.frames(1)
	t.ok(t.anchor_ok(&"a.over.retry"), "gd.game_over anchor %s" % CardAnchors.rect(&"a.over.retry"))
	pack["bus"].first_time.emit(&"game_over", {})
	guide.evaluate_now()
	t.eq(guide.active_step(), "gd.game_over", "gd.game_over lights")
	if k16:
		var bus: CardEventBus = pack["bus"]
		await _k16_done(t, guide, bus, "gd.game_over")
	else:
		host.close_top()
		await t.frames(1)
	t.eq(guide.active_step(), "", "gd.game_over completes")
	_drop(host, guide)
	await t.frames(1)


func _year_after_fallback(t, k16: bool) -> void:
	var pack := S.mount(self, "res://scripts/tests/cards/C09/fixtures/year_jump_sections.json")
	var guide := _guide(pack, k16)
	var marker := ColorRect.new()
	marker.color = CardTheme.color(&"paper")
	marker.position = Vector2(200, 200)
	marker.size = Vector2(80, 48)
	root.add_child(marker)
	CardAnchors.register(&"a.dossier.page", marker)
	await t.frames(1)
	t.ok(not CardAnchors.has(&"a.year.after"), "fallback case has no year-after anchor")
	t.ok(t.anchor_ok(&"a.dossier.page"), "dossier fallback anchor")
	pack["bus"].first_time.emit(&"year_after", {})
	guide.evaluate_now()
	t.eq(guide.active_step(), "gd.year_after", "gd.year_after lights on a.dossier.page")
	if k16:
		var bus: CardEventBus = pack["bus"]
		await _k16_done(t, guide, bus, "gd.year_after")
	else:
		guide.tick(4.0)
	t.eq(guide.active_step(), "", "fallback step completes")
	marker.queue_free()
	guide.queue_free()
	await t.frames(1)


func _retry(t, k16: bool) -> void:
	var bus := CardEventBus.new()
	root.add_child(bus)
	var game: CardGameRoot = load(CardIds.ROOT_SCENE).instantiate()
	game.boot({"mock": true,
		"bus": bus,
		"fixture": "month_open",
		"skip_title": true,
		"guide": "off",
		"settings_path": t.user_dir() + "/settings.json",
	})
	root.add_child(game)
	await t.frames(3)
	game.guide.force(true)
	game.guide.skip_fades = true
	if k16:
		game.guide.load_steps(game.engine.query(&"guide_data"))
	else:
		game.guide.load_steps(S.guide_data())
	t.ok(t.anchor_ok(&"a.top.date"), "table date anchor %s" % CardAnchors.rect(&"a.top.date"))
	bus.first_time.emit(&"retry", {})
	await t.frames(1)
	if game.host.top_overlay() != null:
		# Contract 7.10.7 (10-22 note, button audit b47): a step on the table waits while an overlay
		# (here the month-open interlude of the retried stage) covers it, then lights on the table.
		# The month-open lessons are not this case: count them as taught (K16 has no after chain now).
		for id in ["gd.m.open", "gd.m.wheel", "gd.m.incense"]:
			game.guide._progress[id] = {"status": "done", "shows": 1}
		game.guide.evaluate_now()
		t.ok(game.guide.active_step() != "gd.retry", "gd.retry waits behind the %s overlay" % game.host.top_kind())
		game.host.close_all()
	game.guide.evaluate_now()
	t.eq(game.guide.active_step(), "gd.retry", "gd.retry lights on the table date")
	if k16:
		await _k16_done(t, game.guide, bus, "gd.retry")
	else:
		game.guide.tick(4.0)
	t.eq(game.guide.active_step(), "", "gd.retry completes")
	t.eq(Array(game.guide.shown_log), ["gd.retry"], "only the retry step lit on the table")


func _k16_done(t, guide: CardGuide, bus: CardEventBus, step_id: String) -> void:
	var data: Dictionary = {}
	if guide.engine != null:
		data = guide.engine.query(&"guide_data")
	var row: Dictionary = _step_row(data, step_id)
	var seconds: float = float(row.get("seconds", 4))
	var done: Array = []
	var raw = row.get("done_when", [])
	if typeof(raw) == TYPE_ARRAY:
		done = raw
	var saw_retry := false
	for tok in done:
		var token := str(tok)
		if token == "timeout":
			continue
		if token == "cmd:game.retry_stage":
			saw_retry = true
			continue
		_emit_token(bus, token)
		if guide.active_step() == "":
			break
	# Timeout uses this step's own seconds (K16 uses 12 or 20, not the fixture's 4).
	if guide.active_step() != "":
		guide.tick(seconds)
	if guide.active_step() != "":
		guide.tick(seconds)
	# game.retry_stage rebuilds the guide before the cmd token is seen, so emit it
	# only after ui.guide done has flushed and the step is already finished.
	if saw_retry:
		await t.frames(1)
		bus.command_done.emit(&"game.retry_stage", {}, true)
		if guide.active_step() != "":
			guide.tick(seconds)
		if guide.active_step() != "":
			guide.tick(seconds)


func _emit_token(bus: CardEventBus, token: String) -> void:
	if token.begins_with("cmd:"):
		bus.command_done.emit(StringName(token.substr(4)), {}, true)
	elif token.begins_with("first:"):
		bus.first_time.emit(StringName(token.substr(6)), {})
	elif token.begins_with("panel:"):
		bus.ui_event.emit(&"panel_opened", {"kind": token.substr(6)})
	elif token.begins_with("ui:"):
		bus.ui_event.emit(StringName(token.substr(3)), {})


func _step_row(data: Dictionary, step_id: String) -> Dictionary:
	var steps: Array = data.get("steps", [])
	for step in steps:
		if typeof(step) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = step
		if str(row.get("id", "")) == step_id:
			return row
	return {}


func _host(pack: Dictionary) -> CardModalHost:
	var host := CardModalHost.new()
	host.bind(pack["mock"], pack["bus"])
	root.add_child(host)
	return host


func _guide(pack: Dictionary, k16: bool) -> CardGuide:
	var guide := S.attach_guide(self, pack)
	if k16:
		guide.load_steps(pack["mock"].query(&"guide_data"))
	return guide


func _drop(host: Node, guide: Node) -> void:
	host.queue_free()
	guide.queue_free()


func _arg(prefix: String, fallback: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with(prefix):
			return a.substr(prefix.length())
	return fallback
