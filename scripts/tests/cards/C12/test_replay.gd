# Ops replay (DESIGN 3.6, P8): game A autoplay(x) -> ops_log() -> game B applies the ops one by one ->
# the two results are equal key by key (quality, observations, minutes, measures). Changing one op
# changes the result. Ops are whole numbers and short ASCII words; a JSON round trip replays the same.
# Ops that do not apply return false and change nothing. Owner C12.
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const Lib = preload("res://scripts/tests/cards/C12/c12_lib.gd")


func _initialize() -> void:
	var t := T.new(self, "C12_replay")
	t.run_async(_body.bind(t))


func _body(t) -> void:
	var bus := CardEventBus.new()
	root.add_child(bus)
	var mock := MockCardEngine.new(bus)
	t.ok(mock.db != null, "text db")
	await t.frames(1)
	for name in Lib.fixture_names():
		var params: Dictionary = Lib.fixture(name)
		for x in [0.0, 0.3, 0.8, 1.0]:
			var label := "%s skill %.1f" % [name, x]
			var logs: Array = []
			var a = Lib.run(self, params, func(g: CardSpotGame) -> void:
				g.autoplay(x)
				logs.append(g.ops_log()))
			var ops: Array = logs[0]
			t.ok(a != null, label + " finished")
			t.eq(str(ops.back()[0]) if not ops.is_empty() else "", "done", label + " log ends with done")
			_ops_shape(t, ops, label)
			var b = Lib.replay(self, params, ops)
			t.eq(b, a, label + " replay gives the same result")
			var json_ops = JSON.parse_string(JSON.stringify(ops))
			t.eq(Lib.replay(self, params, json_ops), a, label + " replay from JSON")
			var changed := _change_one(ops)
			if not changed.is_empty():
				t.ok(Lib.replay(self, params, changed) != a, label + " one op changed -> result changed")
	_invalid(t)
	bus.queue_free()
	await t.frames(3)


func _ops_shape(t, ops: Array, label: String) -> void:
	for op in ops:
		t.ok(typeof(op) == TYPE_ARRAY and not (op as Array).is_empty(), label + " op is an array")
		for v in op:
			var ok: bool = typeof(v) == TYPE_INT or (typeof(v) == TYPE_STRING and str(v).length() <= 8
				and str(v).to_ascii_buffer().get_string_from_ascii() == str(v))
			t.ok(ok, "%s op value %s" % [label, str(v)])


## Flip the first pin's call (or move it); empty when there is no pin to change.
func _change_one(ops: Array) -> Array:
	var out := ops.duplicate(true)
	for op in out:
		if str(op[0]) == "pin":
			op[3] = 1 if int(op[3]) == 2 else 2
			return out
	return []


func _invalid(t) -> void:
	var params: Dictionary = Lib.fixture("hairpin3")
	var game := Lib.open_game(self, params)
	var bad: Array = [["pin", 64, 0, 1], ["pin", 0, -1, 1], ["pin", 1, 1, 3], ["pin", 1.5, 2, 1], ["pin", "1", 2, 1],
		["pin", 1, 2], ["retag", 0, 1], ["unpin", 0], ["tool", "atlas"], ["tool", "eye"], ["tool", "mirror"],
		["blink", 1], ["atlas", 1], ["bogus"], [], ["done", 1]]
	for op in bad:
		t.eq(game.apply_op(op), false, "refused " + str(op))
	t.eq(game.ops_log(), [], "refused ops leave no trace")
	t.eq(game.pins(), [], "refused ops pin nothing")
	t.eq(game.ink_left(), 4, "refused ops spend no ink")
	t.eq(game.minutes_spent(), 0, "refused ops spend no time")
	t.ok(game.apply_op(["tool", "lens"]), "lens")
	t.eq(game.apply_op(["tool", "lens"]), false, "lens twice is no change")
	t.ok(game.apply_op(["atlas"]), "atlas")
	t.eq(game.apply_op(["atlas"]), false, "atlas twice is no change")
	t.ok(game.apply_op(["pin", 10, 10, 1]), "pin")
	t.eq(game.apply_op(["retag", 0, 1]), false, "same call is no change")
	t.eq(game.apply_op(["retag", 1, 2]), false, "retag past the end")
	t.ok(game.apply_op(["pin", 2.0, 3.0, 2.0]), "whole-number floats from JSON are fine")
	for i in 2:
		game.apply_op(["pin", 20 + i, 20, 1])
	t.eq(game.ink_left(), 0, "ink used up")
	t.eq(game.apply_op(["pin", 40, 40, 1]), false, "no ink, no pin")
	var n := game.ops_log().size()
	var result: Array = []
	game.finished.connect(func(r: Dictionary) -> void: result.append(r))
	t.ok(game.apply_op(["done"]), "done")
	t.eq(result.size(), 1, "done finishes once")
	t.eq(game.apply_op(["pin", 1, 1, 1]), false, "after done: nothing applies")
	t.eq(game.apply_op(["done"]), false, "after done: done again refused")
	t.eq(game.ops_log().size(), n + 1, "log closed after done")
	game.autoplay(1.0)
	t.eq(result.size(), 1, "autoplay after done does nothing")
	game.queue_free()
