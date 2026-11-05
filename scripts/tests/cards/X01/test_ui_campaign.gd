extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const U = preload("res://scripts/tests/cards/K14/qa_util.gd")

func _initialize() -> void:
	var t := T.new(self, "X01_ui_campaign")
	t.run_async(_body.bind(t))

func _body(t) -> void:
	var bus := CardEventBus.new()
	root.add_child(bus)
	var game: CardGameRoot = load(CardIds.ROOT_SCENE).instantiate()
	game.boot({"mock": false, "bus": bus, "seed": 7, "guide": "off", "save_dir": t.user_dir()})
	root.add_child(game)
	await t.frames(2)
	var days := {}
	var phases := {}
	var panels := {}
	var foreign_text := {}
	var idle := 0
	var steps := 0
	while steps < U.STEP_CAP:
		for text in t.all_text_from_cardtext(game):
			foreign_text[text] = true
		var view := game.engine.view()
		var date: Dictionary = view.get("date", {})
		phases[str(view.get("phase", ""))] = true
		panels[str(game.host.top_kind())] = true
		if str(view.get("phase", "")) == "day":
			if not days.has(int(date.get("stage_day", 0))):
				print("X01 UI DAY %s step=%d" % [date.get("stage_day"), steps])
			days[int(date.get("stage_day", 0))] = true
		if int(date.get("stage", 0)) == 1 or str(view.get("phase", "")) == "game_over":
			break
		var before := _fingerprint(game)
		t.ok(game.autoplay_step(), "table step %d handled" % steps)
		await t.frames(1)
		idle = idle + 1 if _fingerprint(game) == before else 0
		steps += 1
		if idle >= U.STUCK_LIMIT:
			var panel = game.host.play_panel()
			print("X01 STUCK view=%s panel=%s phase=%s uid=%s replies=%s checks=%s" % [before, panel, panel.get("_phase") if panel else "", panel.get("_uid") if panel else "", panel.get("reply_rows") if panel else [], game.checks.preview()])
			t.ok(false, "stuck %d steps at %s" % [idle, before])
			break
	var date: Dictionary = game.engine.view().get("date", {})
	print("X01 UI CAMPAIGN days=%d steps=%d phases=%s panels=%s final=%s" % [days.size(), steps, phases.keys(), panels.keys(), date])
	t.ok(foreign_text.is_empty(), "table text comes from CardText: %s" % [foreign_text.keys()])
	t.eq(days.size(), 30, "table played all thirty days")
	t.ok(phases.has("month_close") and phases.has("year_jump"), "settlement and year transition visited")
	t.ok(panels.has("slots"), "real slot panel exercised")
	t.eq(date.get("stage"), 1, "table completed 1938")
	t.eq(date.get("era"), "1939", "table reached next era")
	t.eq([date.get("y"), date.get("m"), date.get("d")], [1940, 1, 9], "next lunar month date")
	game.queue_free()
	await t.frames(2)
	bus.queue_free()
	await t.frames(2)

func _fingerprint(game: CardGameRoot) -> String:
	var result := U.fingerprint(game)
	var panel := game.host.top_overlay()
	if panel is CardYearJumpPanel:
		# Reading a report page is UI progress without an engine command.
		result += "|" + (panel.get_node("Page") as Label).text
	return result
