extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const Fair = preload("res://scripts/cards/sim/policies/fair.gd")

func _initialize() -> void:
	var t := T.new(self, "X01_campaign")
	t.run_async(_body.bind(t))

func _body(t) -> void:
	var bus := CardEventBus.new()
	root.add_child(bus)
	var game: CardGameRoot = load(CardIds.ROOT_SCENE).instantiate()
	game.boot({"mock": false, "bus": bus, "seed": 7, "guide": "off", "save_dir": t.user_dir()})
	root.add_child(game)
	await t.frames(2)
	t.ok(game.engine is CardEngine, "explicit real table uses real engine")
	t.ok(game.title != null, "new game starts at title")
	game.title.chose.emit(&"new")
	await t.frames(2)
	var engine := game.engine
	var date: Dictionary = engine.view().get("date", {})
	t.eq(date.get("y"), 1938, "title starts 1938")
	t.eq(date.get("m"), 3, "title starts March")
	t.ok(bool(engine.send(&"day.end", {"confirm": true}).get("ok")), "begin month")
	date = engine.view().get("date", {})
	t.eq(date.get("stage_day"), 1, "first morning is day one")
	# Keep the engine started from the title; release UI for the headless campaign.
	game.queue_free()
	await t.frames(2)
	var days := {}
	var phases := {}
	bus.view_changed.connect(func(_topics):
		var v := engine.view()
		var phase := str(v.get("phase", ""))
		phases[phase] = true
		if phase == "day":
			days[int(v.get("date", {}).get("stage_day", 0))] = true)
	var report := CardAutoplay.play(engine, Fair.new(7), {"stages": 1})
	t.ok(bool(report.get("ok", false)), "headless autoplay completes: %s" % report)
	t.eq(report.get("stages_cleared"), 1, "1938 stage cleared")
	t.ok(bool(engine.send(&"year.next").get("ok", false)), "year transition continues")
	date = engine.view().get("date", {})
	print("X01 CAMPAIGN days=%d phases=%s final=%s" % [days.size(), phases.keys(), date])
	t.eq(days.size(), 30, "all thirty days played")
	t.ok(phases.has("month_close"), "month settlement reached")
	t.ok(phases.has("year_jump"), "year transition reached")
	t.eq(date.get("era"), "1939", "1939 lunar twelfth month reached")
	t.eq([date.get("y"), date.get("m"), date.get("d")], [1940, 1, 9],
		"lunar month starts on the configured Gregorian date")
	t.eq(date.get("stage"), 1, "second stage reached")
	bus.queue_free()
	await t.frames(2)
