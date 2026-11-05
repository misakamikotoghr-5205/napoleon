# C14: clarity comes from the process only (DESIGN P3, 6.5): the needle at the last commit. Level -> 1000 (clear);
# within three steps -> 600 (half); further -> 250; never read -> 100. The same commit with a right and a wrong
# call gives the same clarity (the call never moves it). Result keys stay the five of 8.1.
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const Fix = preload("res://scripts/tests/cards/C14/weigh_fix.gd")

var fix


func _initialize() -> void:
	var t := T.new(self, "C14_fidelity")
	t.run_async(_body.bind(t))


func _body(t) -> void:
	fix = Fix.new()
	fix.setup_text()
	var obs_cat: Dictionary = fix.catalog()
	t.ok(obs_cat.size() >= 8, "catalog has the weigh keys (%d)" % obs_cat.size())
	for name in Fix.FIXTURES:
		var pars: Dictionary = fix.params(name)
		var res := int(pars["resolution_fen"])
		var right := Fix.CALLS.find(str(Fix.EXPECT[name]))
		var wrong := 5 if right != 5 else 1
		var level_r := await _round(pars, 0, right)
		var level_w := await _round(pars, 0, wrong)
		var near := await _round(pars, 2, right)
		var off := await _round(pars, 6, right)
		var none := await _no_commit(t, pars)
		for r in [level_r, level_w, near, off, none]:
			fix.assert_shape(t, r, obs_cat)
		t.eq(int(level_r["quality_permille"]), 1000, name + " level commit")
		t.eq(int(level_w["quality_permille"]), 1000, name + " the call does not change clarity")
		t.eq(int(near["quality_permille"]), 600, name + " two steps off")
		t.eq(int(off["quality_permille"]), 250, name + " six steps off")
		t.eq(int(none["quality_permille"]), 100, name + " never read")
		t.eq(none["observations"], ["obs.weigh.unsure"], name + " never read is unsure")
		t.eq(fix.fidelity(obs_cat, level_r), "clear", name + " clear call key")
		t.ok(absi(int(near["measures"]["read_fen"]) - int(pars["actual_fen"])) >= 2 * res - res,
			name + " near read is off the hidden weight")
		await t.frames(1)


## Level with the slow ops, then push the poise `off_steps` past level (toward heavier on the hook), commit, call.
func _round(pars: Dictionary, off_steps: int, call: int) -> Dictionary:
	var game = fix.open(self, pars)
	await process_frame
	var box := {"r": {}}
	game.finished.connect(func(r: Dictionary) -> void: box["r"] = r)
	fix.level_ops(game)
	if off_steps > 0:
		# Centre on the hidden weight first, then step away by exactly off_steps (error lands at off_steps +- 0.5).
		var res := int(pars["resolution_fen"])
		var base := int(round(float(int(pars["actual_fen"]) - int(game._weight_sum())) / float(res)))
		var to := base + off_steps
		if to > int(game._poise_max):
			to = base - off_steps
		game.apply_op(["poise", to])
	game.apply_op(["commit"])
	game.apply_op(["call", call])
	game.apply_op(["done"])
	game.queue_free()
	await process_frame
	return box["r"]


## Levelled but never read: a call is refused before the stars are read (the buttons are grey until then).
func _no_commit(t, pars: Dictionary) -> Dictionary:
	var game = fix.open(self, pars)
	await process_frame
	var box := {"r": {}}
	game.finished.connect(func(r: Dictionary) -> void: box["r"] = r)
	fix.level_ops(game)
	t.ok(not game.apply_op(["call", 1]), "call refused before the commit")
	t.ok(not game.apply_op(["again"]), "weigh-again refused before the commit")
	game.apply_op(["done"])
	game.queue_free()
	await process_frame
	return box["r"]
