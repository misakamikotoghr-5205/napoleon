# C14 (DESIGN P9, 13 test_compat): params without the new fields (no small_fen, zoom, minor_ticks,
# needle_gain, poise_fen) start and finish: the mock's weigh params, every fixture, and an old engine-default
# round that cannot level (commit + "unsure" hands back cleanly). Missing aids fall back to the eye-2 defaults.
# Ugly params (no weights, zero claim, floats from JSON) do not crash.
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const Fix = preload("res://scripts/tests/cards/C14/weigh_fix.gd")
const R = preload("res://scripts/cards/minigames/weigh/weigh_rules.gd")

var fix


func _initialize() -> void:
	var t := T.new(self, "C14_compat")
	t.run_async(_body.bind(t))


func _body(t) -> void:
	fix = Fix.new()
	fix.setup_text()
	var obs_cat: Dictionary = fix.catalog()
	# The mock engine's weigh request as it stood at 00e36ef6 (mock_scenario.gd _mg_params "weigh").
	var mock_params := {"kind": "weigh", "seed": 77, "item": "I001", "art": "", "minutes_per_step": 1, "max_minutes": 30,
		"tool": "dengzi", "claimed_fen": 300, "actual_fen": 291, "weights_fen": [100, 100, 50, 20, 10, 5], "resolution_fen": 5}
	var cases := {"mock": mock_params}
	for name in Fix.FIXTURES:
		cases[name] = fix.params(name)
	for label in cases.keys():
		var pars: Dictionary = cases[label]
		for k in ["small_fen", "zoom", "minor_ticks", "needle_gain", "poise_fen"]:
			t.ok(not pars.has(k), "%s has no %s (old params)" % [label, k])
		var game = fix.open(self, pars)
		await t.frames(1)
		if not pars.has("zoom"):
			t.eq(int(game._zoom_k), R.DEFAULT_ZOOM, label + " zoom default")
		if not pars.has("minor_ticks"):
			t.eq(bool(game._fine), R.DEFAULT_MINOR_TICKS, label + " small dots default")
		if not pars.has("needle_gain"):
			t.eq(int(game._gain), R.DEFAULT_NEEDLE_GAIN, label + " needle default")
		var r: Dictionary = fix.play(game, 0.8)
		fix.assert_shape(t, r, obs_cat)
		t.eq(bool(r["aborted"]), false, label + " finished")
		game.queue_free()
		await t.frames(1)
	# Floats from JSON and odd params.
	var odd := [
		{"kind": "weigh", "seed": 5.0, "tool": "dengzi", "claimed_fen": 300.0, "actual_fen": 290.0, "weights_fen": [100.0, 50.0],
			"resolution_fen": 2.0},
		{"kind": "weigh", "seed": 6, "tool": "steelyard", "claimed_fen": 0, "actual_fen": 0, "weights_fen": [], "resolution_fen": 0},
		{"kind": "weigh", "seed": 7, "tool": "?", "claimed_fen": 120, "actual_fen": 115},
	]
	for i in odd.size():
		var g = fix.open(self, odd[i])
		await t.frames(1)
		var res: Dictionary = fix.play(g, 1.0)
		t.ok(not res.is_empty(), "odd params %d finish" % i)
		t.ok(t.find_floats(res).is_empty(), "odd params %d result has no floats" % i)
		g.queue_free()
		await t.frames(1)
	# New aids are read when present.
	var aided: Dictionary = fix.params("match")
	aided.merge({"zoom": 3, "minor_ticks": false, "needle_gain": 12, "small_fen": 10, "poise_fen": 150}, true)
	var ga = fix.open(self, aided)
	await t.frames(1)
	t.eq(int(ga._zoom_k), 3, "zoom from params")
	t.eq(bool(ga._fine), false, "small dots off from params")
	t.eq(int(ga._gain), 12, "needle gain from params")
	t.eq(int(ga._poise_max) * int(ga._res), 150, "poise travel from params")
	ga.queue_free()
	await t.frames(2)
