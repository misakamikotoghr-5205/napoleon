# Real engine, seed 7. Default is the example-set regression (only_examples true).
# --data=real loads real card data (only_examples false) and prints --name=.
# Flow: month-open cutscene, this month's fate wheel, month-end ledger, year jump.
# A second game reaches game_over, then game.retry_stage returns to month_open.
# Prison is reached by running the registered arrest effect from the test.
# That call is not a natural event and does not cover a dealt arrest card.
# Economy numbers are not edited.

extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const S = preload("res://scripts/tests/cards/C09/c09_support.gd")
const OPEN := "res://scenes/cards/month/MonthOpen.tscn"
const CLOSE := "res://scenes/cards/month/MonthClose.tscn"
const YEAR := "res://scenes/cards/month/YearJump.tscn"
const OVER := "res://scenes/cards/month/GameOver.tscn"


func _initialize() -> void:
	var t := T.new(self, _arg("--name=", "C09_real_engine"))
	var examples: bool = _arg("--data=", "examples") != "real"
	t.run_async(_body.bind(t, examples))


func _body(t, examples: bool) -> void:
	var bus := CardEventBus.new()
	root.add_child(bus)
	var e := CardEngine.new(bus)
	var started: Dictionary = e.new_game(_game_opts(t, examples))
	t.ok(bool(started.get("ok", false)), "new game " + str(started.get("err", "")))
	t.eq(str(e.view().get("phase", "")), "month_open", "new game phase is month_open")
	t.no_leaks(e.view(), "new game view")
	await _cutscene(t, e, bus)
	await _fate(t, e)
	var pushed := _push_month(e)
	t.eq(pushed, "", "push to month end: " + pushed)
	t.eq(str(e.view().get("phase", "")), "month_close", "month end phase")
	t.eq(int(e.view().get("date", {}).get("stage_day", 0)), 30, "month end is day 30")
	await _ledger(t, e, bus)
	await _year(t, e, bus)
	_free(bus)
	await t.frames(2)
	await _game_over(t, examples)
	t.finish()


func _cutscene(t, e: CardEngine, bus: CardEventBus) -> void:
	var era := str(e.view().get("date", {}).get("era", ""))
	var intro: Dictionary = e.view().get("stage_intro", {})
	var paras := int(intro.get("intro_paras", 0))
	var art := str(intro.get("bg", ""))
	var panel := _mount(OPEN, e, bus) as CardMonthOpen
	panel.open({})
	await t.frames(1)
	var bg := panel.find_child("Bg", true, false) as TextureRect
	t.ok(bg != null, "cutscene background")
	t.eq(str(bg.get_meta("art_id", "")), art, "cutscene art is the stage background")
	t.eq(bg.texture_filter, CanvasItem.TEXTURE_FILTER_NEAREST, "cutscene nearest filter")
	var scale := int(bg.get_meta("scale", 0))
	t.ok(scale >= 1, "cutscene scale is a positive integer")
	var base := CardArt.base_size(art)
	if base.x > 0:
		t.eq(bg.size.x, base.x * float(scale), "cutscene width is an integer multiple")
	var para_root := panel.find_child("Paras", true, false)
	t.eq(para_root.get_child_count(), paras, "cutscene paragraph count")
	var stage_doc = CardDB.read_json("res://data/cards/era/%s/stage.json" % era)
	var brief := ""
	if typeof(stage_doc) == TYPE_DICTIONARY:
		brief = str(stage_doc.get("brief", ""))
	for i in paras:
		var lab := panel.find_child("P%d" % [i + 1], true, false) as Label
		var ref := "stage.%s#intro.p%d" % [era, i + 1]
		t.eq(lab.text, CardText.t(ref), "cutscene paragraph %d" % [i + 1])
		t.ok(lab.text != brief, "stage brief is not shown as a paragraph")
	var guard := 0
	while not S.goals_visible(panel) and guard < 8:
		panel.autoplay_step()
		guard += 1
	t.ok(S.goals_visible(panel), "cutscene reaches the goals")
	await t.frames(1)
	t.ok(t.anchor_ok(&"a.month.goals"), "goals anchor")
	var goals: Array = e.view().get("goals", [])
	var rows: Array = []
	var mains := 0
	var goals_box := panel.find_child("Goals", true, false)
	for c in goals_box.get_children():
		if c.has_meta("goal_id"):
			rows.append(c)
			if bool(c.get_meta("main")):
				mains += 1
	t.eq(rows.size(), goals.size(), "cutscene lists the engine goals")
	var want_main := 0
	for g in goals:
		if typeof(g) == TYPE_DICTIONARY and bool(g.get("main", false)):
			want_main += 1
	t.eq(mains, want_main, "main goals are marked")
	t.ok(t.all_text_from_cardtext(panel).is_empty(), "cutscene text: %s" % ", ".join(t.all_text_from_cardtext(panel)))
	t.ok(not S.has_percent(panel), "cutscene has no percent")
	var before := _cmds(e, "month.begin")
	panel.autoplay_step()
	t.eq(_cmds(e, "month.begin"), before, "cutscene close does not begin the month")
	t.eq(str(e.view().get("phase", "")), "month_open", "phase stays month_open after the cutscene")
	_free(panel)
	await t.frames(1)


func _fate(t, e: CardEngine) -> void:
	var op: Dictionary = e.view().get("open_panel", {})
	t.eq(str(op.get("kind", "")), "wheel", "this month's fate is requested")
	var args: Dictionary = op.get("args", {})
	t.eq(str(args.get("wheel", "")), "wh.month", "fate wheel id")
	t.eq(bool(args.get("required", false)), true, "fate wheel is required")
	t.eq(str(e.view().get("notice", {}).get("fortune", "")), "", "fortune is empty before the spin")
	var spun: Dictionary = e.send(&"wheel.spin", {"wheel": "wh.month", "uid": ""})
	t.ok(bool(spun.get("ok", false)), "spin this month's fate " + str(spun.get("err", "")))
	var segment := str(spun.get("segment", ""))
	t.ok(segment != "", "fate segment")
	t.eq(str(e.view().get("notice", {}).get("fortune", "")), segment, "view shows this month's fate")
	t.eq(str(e.view().get("phase", "")), "month_open", "spin stays in month_open")
	var began: Dictionary = e.send(&"month.begin")
	t.ok(bool(began.get("ok", false)), "month.begin after the fate " + str(began.get("err", "")))
	t.eq(str(e.view().get("phase", "")), "morning", "month has begun")


func _ledger(t, e: CardEngine, bus: CardEventBus) -> void:
	var rep: Dictionary = e.query(&"month_report", {})
	t.no_leaks(e.view(), "month close view")
	t.no_leaks(rep, "month report")
	var lines: Array = rep.get("lines", [])
	t.ok(not lines.is_empty(), "month ledger has lines")
	var panel := _mount(CLOSE, e, bus)
	panel.open({})
	await t.frames(1)
	t.ok(t.anchor_ok(&"a.mclose.accounts"), "ledger anchor")
	var shown := S.blob(panel)
	for line in lines:
		if typeof(line) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = line
		var key := str(row.get("key", ""))
		var raw = row.get("args", {})
		var args: Dictionary = {}
		if typeof(raw) == TYPE_DICTIONARY:
			args = raw
		t.ok(shown.contains(CardText.ui(key, args)), "ledger line " + key)
	var goals: Array = e.view().get("goals", [])
	for g in goals:
		if typeof(g) != TYPE_DICTIONARY:
			continue
		var goal: Dictionary = g
		var id := str(goal.get("id", ""))
		var node := _goal_row(panel, id)
		t.ok(node != null, "ledger lists goal " + id)
		if node == null:
			continue
		var chip := S.blob(node)
		var st := str(goal.get("status", ""))
		if st == "done":
			t.ok(chip.contains(CardText.ui("c09.goals.done")), "goal done " + id)
		elif st == "failed":
			t.ok(chip.contains(CardText.ui("c09.goals.failed")), "goal failed " + id)
		if bool(goal.get("main", false)):
			t.ok(chip.contains(CardText.ui("c09.goals.main")), "goal main " + id)
	t.ok(t.all_text_from_cardtext(panel).is_empty(), "ledger text: %s" % ", ".join(t.all_text_from_cardtext(panel)))
	t.ok(not S.has_percent(panel), "ledger has no percent")
	var before := _cmds(e, "month.next")
	panel.autoplay_step()
	t.eq(_cmds(e, "month.next"), before + 1, "ledger sends month.next once")
	t.eq(str(e.view().get("phase", "")), "year_jump", "month.next enters the year jump")
	_free(panel)
	await t.frames(1)


func _year(t, e: CardEngine, bus: CardEventBus) -> void:
	var before_rep: Dictionary = e.query(&"year_report", {})
	t.no_leaks(before_rep, "year report before the jump")
	var before_lines: Array = before_rep.get("lines", [])
	var panel := _mount(YEAR, e, bus)
	panel.open({})
	await t.frames(1)
	var n := maxi(before_lines.size(), 1)
	var page := panel.find_child("Page", true, false) as Label
	t.eq(page.text, CardText.ui("c09.year.page", {"i": 1, "n": n}), "year page indicator")
	t.ok(t.all_text_from_cardtext(panel).is_empty(), "year text: %s" % ", ".join(t.all_text_from_cardtext(panel)))
	t.ok(not S.has_percent(panel), "year panel has no percent")
	var before := _cmds(e, "year.next")
	var guard := 0
	while _cmds(e, "year.next") == before and guard < 12:
		if not panel.autoplay_step():
			break
		guard += 1
	t.eq(_cmds(e, "year.next"), before + 1, "year panel sends year.next once")
	t.eq(str(e.view().get("phase", "")), "month_open", "year.next returns to month_open")
	t.eq(int(e.view().get("date", {}).get("stage", -1)), 1, "year.next advances the stage")
	var after: Dictionary = e.query(&"year_report", {})
	t.no_leaks(after, "year report after the jump")
	var found := false
	for line in after.get("lines", []):
		if typeof(line) == TYPE_DICTIONARY and str(line.get("key", "")) == "g02.year.advance":
			found = true
	t.ok(found, "year report records the year advance")
	_free(panel)
	await t.frames(1)


func _game_over(t, examples: bool) -> void:
	var bus := CardEventBus.new()
	root.add_child(bus)
	var e := CardEngine.new(bus)
	var started: Dictionary = e.new_game(_game_opts(t, examples, "/over"))
	t.ok(bool(started.get("ok", false)), "game-over run starts")
	var spun: Dictionary = e.send(&"wheel.spin", {"wheel": "wh.month", "uid": ""})
	t.ok(bool(spun.get("ok", false)), "game-over run spins the fate")
	t.ok(bool(e.send(&"month.begin").get("ok", false)), "game-over run begins the month")
	t.ok(bool(e.send(&"day.begin").get("ok", false)), "game-over run opens the day")
	# Registered arrest effect, not a natural event: no dealt card triggers it.
	e.ctx.run([{"op": "arrest", "reason": "k09.arrest.contraband"}], "c09.real.arrest")
	var err := _push_over(e)
	t.eq(err, "", "reach game over: " + err)
	t.eq(str(e.view().get("phase", "")), "game_over", "phase is game_over")
	var reason := str(e.view().get("game_over_reason", ""))
	t.eq(reason, "prison", "game over reason")
	t.no_leaks(e.view(), "game over view")
	var panel := _mount(OVER, e, bus) as CardGameOver
	panel.open({"reason": reason})
	await t.frames(1)
	var ending := panel.find_child("Ending", true, false) as Label
	t.eq(ending.text, CardText.t("g02.ending." + reason), "ending copy")
	t.ok(t.anchor_ok(&"a.over.retry"), "retry anchor")
	t.ok(t.all_text_from_cardtext(panel).is_empty(), "game over text: %s" % ", ".join(t.all_text_from_cardtext(panel)))
	t.ok(not S.has_percent(panel), "game over has no percent")
	var before := _cmds(e, "game.retry_stage")
	panel.autoplay_step()
	t.eq(_cmds(e, "game.retry_stage"), before + 1, "retry button sends game.retry_stage")
	t.eq(str(e.view().get("phase", "")), "month_open", "retry returns to month_open")
	var again: Dictionary = e.view().get("open_panel", {})
	t.eq(str(again.get("kind", "")), "wheel", "restart asks for this month's fate again")
	t.no_leaks(e.view(), "retry view")
	_free(panel)
	_free(bus)
	await t.frames(1)


func _game_opts(t, examples: bool, sub: String = "") -> Dictionary:
	return {
		"seed": 7,
		"only_examples": examples,
		"save_dir": t.user_dir() + sub,
	}


func _push_month(e: CardEngine) -> String:
	var guard := 0
	while str(e.view().get("phase", "")) not in ["month_close", "year_jump", "game_over"] and guard < 200:
		guard += 1
		var phase := str(e.view().get("phase", ""))
		var r: Dictionary = {}
		if phase == "morning":
			r = e.send(&"day.begin")
		elif phase == "day":
			r = e.send(&"day.end", {"confirm": true})
		elif phase == "night":
			r = e.send(&"night.choose", _night_args(e))
		elif phase == "settle":
			r = e.send(&"settle.next")
		else:
			return "stuck " + phase
		if not bool(r.get("ok", false)):
			return phase + " " + str(r.get("err", ""))
	if str(e.view().get("phase", "")) != "month_close":
		return "phase " + str(e.view().get("phase", ""))
	return ""


func _push_over(e: CardEngine) -> String:
	var guard := 0
	while str(e.view().get("phase", "")) != "game_over" and guard < 40:
		guard += 1
		var phase := str(e.view().get("phase", ""))
		var r: Dictionary = {}
		if phase == "morning":
			r = e.send(&"day.begin")
		elif phase == "day":
			r = e.send(&"day.end", {"confirm": true})
		elif phase == "night":
			r = e.send(&"night.choose", {"def": ""})
		elif phase == "settle":
			r = e.send(&"settle.next")
		else:
			return "stuck " + phase
		if not bool(r.get("ok", false)):
			return phase + " " + str(r.get("err", ""))
	if str(e.view().get("phase", "")) != "game_over":
		return "not over"
	return ""


func _night_args(e: CardEngine) -> Dictionary:
	var offers: Array = e.view().get("night_offers", [])
	var args := {"def": ""}
	for offer in offers:
		if typeof(offer) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = offer
		var id := str(row.get("def", ""))
		if id == "":
			continue
		if str(args.get("def", "")) != "" and id != "nt.tidy":
			continue
		args = {"def": id}
		var choices: Array = row.get("choices", [])
		if not choices.is_empty():
			var first = choices[0]
			if typeof(first) == TYPE_DICTIONARY:
				args["choice"] = str((first as Dictionary).get("id", ""))
			else:
				args["choice"] = str(first)
		if id == "nt.tidy":
			break
	return args


func _mount(scene: String, e: CardEngine, bus: CardEventBus) -> CardPanel:
	var panel: CardPanel = load(scene).instantiate()
	panel.bind(e, bus)
	root.add_child(panel)
	return panel


func _goal_row(panel: Node, id: String) -> Node:
	var box := panel.find_child("Goals", true, false)
	if box == null:
		return null
	for c in box.get_children():
		if str(c.get_meta("goal_id", "")) == id:
			return c
	return null


func _cmds(e: CardEngine, cmd: String) -> int:
	var n := 0
	for row in e.command_log():
		if typeof(row) == TYPE_ARRAY and not (row as Array).is_empty() and str((row as Array)[0]) == cmd:
			n += 1
	return n


func _free(n: Node) -> void:
	if n != null and is_instance_valid(n):
		n.queue_free()


func _arg(prefix: String, fallback: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with(prefix):
			return a.substr(prefix.length())
	return fallback
