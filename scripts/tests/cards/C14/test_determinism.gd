# C14: same params and the same ops give the same result twice; autoplay(0.5) twice is the same; the opening
# (weights on the hook, poise) follows the c.mg.weigh.layout seed.
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const Fix = preload("res://scripts/tests/cards/C14/weigh_fix.gd")

var fix


func _initialize() -> void:
	var t := T.new(self, "C14_determinism")
	t.run_async(_body.bind(t))


func _body(t) -> void:
	fix = Fix.new()
	fix.setup_text()
	var pars: Dictionary = fix.params("light_small")
	var ops := [["weight", 0], ["poise", 3], ["poise", 5], ["commit"], ["call", 2], ["again"], ["poise", 4],
		["commit"], ["call", 3], ["done"]]
	var a := await _ops(pars, ops)
	var b := await _ops(pars, ops)
	t.ok(not a.is_empty(), "the op round finished")
	t.eq(a, b, "same params and the same ops")
	t.eq(int(a["measures"]["commits"]), 2, "two commits counted")
	t.eq(int(a["minutes"]), 2 * 2 + 1, "two commits and one weigh-again")
	t.eq(a["observations"], ["obs.weigh.light_much"], "the last call stands")
	var s1 := await _skill(pars, 0.5)
	var s2 := await _skill(pars, 0.5)
	t.eq(s1, s2, "autoplay 0.5 twice")
	var g0 = await _spawn(pars)
	var open_a: String = fix.signature(g0)
	g0.queue_free()
	await t.frames(1)
	var g1 = await _spawn(pars)
	t.eq(fix.signature(g1), open_a, "same seed, same opening")
	g1.queue_free()
	await t.frames(1)
	var differ := false
	for extra in [1, 3, 9, 17, 41, 88]:
		var q: Dictionary = pars.duplicate(true)
		q["seed"] = int(pars["seed"]) + extra
		var g = await _spawn(q)
		if fix.signature(g) != open_a:
			differ = true
		g.queue_free()
		await t.frames(1)
		if differ:
			break
	t.ok(differ, "layout domain changes the opening with the seed")


func _spawn(pars: Dictionary):
	var game = fix.open(self, pars)
	await process_frame
	return game


func _ops(pars: Dictionary, ops: Array) -> Dictionary:
	var game = await _spawn(pars)
	var box := {"r": {}}
	game.finished.connect(func(r: Dictionary) -> void: box["r"] = r)
	for op in ops:
		game.apply_op(op)
	game.queue_free()
	await process_frame
	return box["r"]


func _skill(pars: Dictionary, skill: float) -> Dictionary:
	var game = await _spawn(pars)
	var result: Dictionary = fix.play(game, skill)
	game.queue_free()
	await process_frame
	return result
