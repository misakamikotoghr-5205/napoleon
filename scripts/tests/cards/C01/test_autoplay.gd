# C01 情景模式种子 7 走到第 4 天早上；12 张牌加面板时空闲帧对象数不涨。
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const S = preload("res://scripts/tests/cards/C01/support.gd")
const TWELVE := "res://scripts/tests/cards/C01/fixtures/hand_twelve.json"


func _initialize() -> void:
	var t := T.new(self, "C01_autoplay")
	t.run_async(_body.bind(t))


func _body(t) -> void:
	var bus := CardEventBus.new()
	root.add_child(bus)
	var game := S.boot(self, bus, "", {"seed": 7, "settings_path": t.user_dir() + "/settings.json"})
	await t.frames(2)
	var steps := 0
	var stuck := 0
	while steps < 600:
		var v: Dictionary = game.engine.view()
		if str(v.get("phase", "")) == "morning" and int(v.get("date", {}).get("stage_day", 0)) == 4:
			break
		if game.autoplay_step():
			stuck = 0
		else:
			stuck += 1
			if stuck >= 3:
				break
		await t.frames(1)
		steps += 1
	var done: Dictionary = game.engine.view()
	t.eq(str(done.get("phase", "")), "morning", "reached morning (steps=%d)" % steps)
	t.eq(int(done.get("date", {}).get("stage_day", 0)), 4, "morning of day 4")
	game.queue_free()
	CardAnchors.clear()
	await t.frames(2)
	game = S.boot(self, bus, TWELVE)
	game.guide.skip_fades = true
	await t.frames(2)
	t.eq((game.engine.view().get("hand", []) as Array).size(), 12, "twelve cards")
	game.host.open_panel(&"help", {})
	await t.frames(3)
	var before := Performance.get_monitor(Performance.OBJECT_COUNT)
	await t.frames(4)
	var after := Performance.get_monitor(Performance.OBJECT_COUNT)
	print("C01_IDLE_OBJECTS %s %s" % [before, after])
	t.ok(after <= before, "idle object count %s -> %s" % [before, after])
	game.queue_free()
	bus.queue_free()
	await t.frames(1)
