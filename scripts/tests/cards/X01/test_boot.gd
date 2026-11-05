extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")

func _initialize() -> void:
	var t := T.new(self, "X01_boot")
	t.run_async(_body.bind(t))

func _body(t) -> void:
	var bus := CardEventBus.new()
	root.add_child(bus)
	for options in [{"cli": true}, {}, {"mock": false}, {"mock": true}, {"mock": true, "fixture": "day_full"}]:
		var game: CardGameRoot = load(CardIds.ROOT_SCENE).instantiate()
		var cli := game._cmdline_opts()
		t.eq(cli.get("mock"), false, "formal --cards launch selects real engine")
		if options.has("cli"):
			options = cli
		options.merge({"bus": bus, "guide": "off", "save_dir": t.user_dir()})
		game.boot(options)
		root.add_child(game)
		await t.frames(2)
		var mock: bool = bool(options.get("mock", false))
		t.eq(game.engine is MockCardEngine, mock, "boot is the real engine unless mock: true is explicit")
		if options.has("fixture"):
			t.eq(game.engine.view().get("phase"), "day", "explicit day fixture is retained")
			game.queue_free()
			await t.frames(2)
			continue
		game.title.chose.emit(&"new")
		await t.frames(2)
		t.eq(game.engine.view().get("phase"), "month_open", "title starts month")
		t.ok(not game._end.disabled, "close day remains enabled")
		game._on_close_day()
		await t.frames(2)
		t.eq(game.host.top_kind(), &"end_day", "unspun month asks for confirmation")
		game.host.top_panel().autoplay_step()
		await t.frames(2)
		if bool(options.get("auto_day", false)):
			# 玩家路径（命令行启动）：早上不空等，停一下自动开张（10-22 能玩版）。
			t.ok(str(game.engine.view().get("phase")) in ["morning", "day"], "confirm advances to first morning")
			# 本测试越过开月面板直接按了打烊；玩家得先点“开始”收起它，这里照样收起。
			if game.host.top_kind() == &"month_open":
				game.host.close_top()
			for _i in range(600):
				if str(game.engine.view().get("phase")) == "day" or game.host.top_panel() != null:
					break
				await t.frames(1)
			t.eq(game.engine.view().get("phase"), "day", "player launch opens day one by itself (top panel '%s')" % game.host.top_kind())
		else:
			t.eq(game.engine.view().get("phase"), "morning", "confirm advances to first morning")
		t.eq(game.engine.view().get("date", {}).get("stage_day"), 1, "first morning is day one")
		game.queue_free()
		await t.frames(2)
	bus.queue_free()
	await t.frames(2)
