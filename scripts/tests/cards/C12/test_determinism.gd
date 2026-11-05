# Same fixture + same ops -> same result, twice; autoplay(0.6) twice gives the same ops and result.
# Owner C12. Contract: docs/cards/CARDS_INTERFACES.md 8, 12.2. (Strokes became pin ops: DESIGN 4.4.)
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const Lib = preload("res://scripts/tests/cards/C12/c12_lib.gd")


func _initialize() -> void:
	var t := T.new(self, "C12_determinism")
	t.run_async(_body.bind(t))


func _body(t) -> void:
	var bus := CardEventBus.new()
	root.add_child(bus)
	var mock := MockCardEngine.new(bus)
	t.ok(mock.db != null, "text db")
	await t.frames(1)
	for name in Lib.fixture_names():
		var params: Dictionary = Lib.fixture(name)
		var a = Lib.run(self, params, _scripted)
		var b = Lib.run(self, params, _scripted)
		t.ok(a != null, name + " scripted finished")
		t.eq(a, b, name + " scripted ops match")
		var logs: Array = []
		var c = Lib.run(self, params, func(game: CardSpotGame) -> void:
			game.autoplay(0.6)
			logs.append(game.ops_log()))
		var d = Lib.run(self, params, func(game: CardSpotGame) -> void:
			game.autoplay(0.6)
			logs.append(game.ops_log()))
		t.eq(c, d, name + " autoplay 0.6 matches")
		t.eq(logs[0], logs[1], name + " autoplay 0.6 same ops")
	bus.queue_free()
	await t.frames(3)


func _scripted(game: CardSpotGame) -> void:
	game.apply_op(["atlas"])
	game.apply_op(["pin", 48, 14, 2])
	game.apply_op(["tool", "lens"])
	game.apply_op(["pin", 29, 35, 1])
	game.apply_op(["retag", 0, 1])
	game.apply_op(["pin", 12, 50, 2])
	game.apply_op(["unpin", 1])
	game.apply_op(["done"])
