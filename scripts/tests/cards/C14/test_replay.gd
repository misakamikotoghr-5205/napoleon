# C14 (DESIGN 3.6, 13 test_replay): autoplay(x) on one instance, its ops_log replayed op by op on a fresh
# instance gives the identical result (observations, measures, minutes, quality). Changing one op changes the
# result. Illegal ops are refused and change nothing (not logged). x in 0.0 / 0.3 / 0.8 / 1.0.
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const Fix = preload("res://scripts/tests/cards/C14/weigh_fix.gd")

var fix


func _initialize() -> void:
	var t := T.new(self, "C14_replay")
	t.run_async(_body.bind(t))


func _body(t) -> void:
	fix = Fix.new()
	fix.setup_text()
	for name in Fix.FIXTURES:
		var pars: Dictionary = fix.params(name)
		for x in [0.0, 0.3, 0.8, 1.0]:
			var game = fix.open(self, pars)
			await t.frames(1)
			var a: Dictionary = fix.play(game, x)
			var ops: Array = game.ops_log()
			game.queue_free()
			var label := "%s x=%.1f" % [name, x]
			t.ok(not a.is_empty(), label + " finished")
			t.ok(not ops.is_empty() and str((ops[ops.size() - 1] as Array)[0]) == "done", label + " log ends with done")
			for op in ops:
				for v in op:
					t.ok(typeof(v) == TYPE_INT or (typeof(v) == TYPE_STRING and str(v).length() <= 8), label + " op is ints and short ascii")
			var b: Dictionary = fix.replay(self, pars, ops)
			t.eq(b, a, label + " replay gives the same result")
			# One op changed: the call (or the commit position) differs, so the result does.
			var changed: Array = ops.duplicate(true)
			var idx := -1
			for i in changed.size():
				if str(changed[i][0]) == "call":
					idx = i
			if idx >= 0:
				var c := int(changed[idx][1])
				changed[idx] = ["call", 5 if c != 5 else 1]
				var d: Dictionary = fix.replay(self, pars, changed)
				t.ok(JSON.stringify(d) != JSON.stringify(a), label + " a changed call changes the result")
			await t.frames(1)
	# Illegal ops change nothing.
	var g = fix.open(self, fix.params("match"))
	await t.frames(1)
	var before: String = fix.signature(g)
	var bad := [[], ["nope"], ["weight"], ["weight", -1], ["weight", 99], ["weight", 0.5], ["poise", -1],
		["poise", 100000], ["call", 1], ["again"], ["commit", 1], ["call"], ["done", 1]]
	for op in bad:
		t.ok(not g.apply_op(op), "refused: " + JSON.stringify(op))
	t.eq(fix.signature(g), before, "refused ops left the scale alone")
	t.eq(g.ops_log(), [], "refused ops are not logged")
	g.apply_op(["commit"])
	t.ok(not g.apply_op(["weight", 0]), "weights are locked while the stars are read")
	t.ok(not g.apply_op(["poise", (int(g._poise_step) + 1) % (int(g._poise_max) + 1)]), "poise locked while read")
	t.ok(not g.apply_op(["commit"]), "no second commit without weighing again")
	t.ok(not g.apply_op(["call", 6]) and not g.apply_op(["call", 0]), "calls are 1..5")
	t.eq(g.ops_log(), [["commit"]], "only the commit was logged")
	g.queue_free()
	await t.frames(1)
