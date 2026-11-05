# C14: the steady hand levels every fixture, the commit freezes the reading the beam shows (within one step of
# the hidden weight), the call it makes at skill 1.0 is the fixture's category. Reading before the beam is
# level gives a lower clarity. The needle shows one step off as a plain lean (3 px or more), more steps as more,
# toward the pan when the goods are heavier; nothing lights up when level (B9). Frame time stays small.
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const Fix = preload("res://scripts/tests/cards/C14/weigh_fix.gd")


func _initialize() -> void:
	var t := T.new(self, "C14_physics")
	t.run_async(_body.bind(t))


func _body(t) -> void:
	var fix = Fix.new()
	fix.setup_text()
	for name in Fix.FIXTURES:
		var pars: Dictionary = fix.params(name)
		var game = fix.open(self, pars)
		await t.frames(2)
		var result: Dictionary = fix.play(game, 1.0)
		var actual := int(pars["actual_fen"])
		var res := int(pars["resolution_fen"])
		var read := int(result["measures"]["read_fen"])
		t.ok(absi(read - actual) <= res, "%s read %d actual %d res %d" % [name, read, actual, res])
		t.eq(bool(result["aborted"]), false, name + " finished")
		t.eq(int(result["measures"]["commits"]), 1, name + " one commit")
		t.eq(int(result["minutes"]), 2, name + " minutes: one commit costs 2, handling costs nothing")
		t.eq(int(result["quality_permille"]), 1000, name + " level commit is clear")
		t.eq(result["observations"], ["obs.weigh." + str(Fix.EXPECT[name])], name + " call at skill 1.0")
		var panel := game.get_node("Panel") as Control
		t.ok(panel.size.x <= 1100.0 and panel.size.y <= 640.0, name + " panel within 1100x640")
		game.queue_free()
		await t.frames(1)
	# Reading too early: commit straight from the (never level) opening.
	var early = fix.open(self, fix.params("match"))
	await t.frames(1)
	var box := {"r": {}}
	early.finished.connect(func(r: Dictionary) -> void: box["r"] = r)
	t.ok(not early._level(), "the opening is never level")
	t.ok(early.apply_op(["commit"]), "commit from the opening")
	t.ok(early.apply_op(["call", 5]), "call unsure")
	t.ok(early.apply_op(["done"]), "done")
	t.ok(int(box["r"]["quality_permille"]) < 700, "unlevel read is not clear (%d)" % int(box["r"]["quality_permille"]))
	t.eq(box["r"]["observations"], ["obs.weigh.unsure"], "unsure call is recorded as unsure")
	early.queue_free()
	await t.frames(1)
	await _needle(t, fix)
	await _bench(t, fix)


func _needle(t, fix) -> void:
	var pars: Dictionary = fix.params("match")
	pars["actual_fen"] = 300
	pars["resolution_fen"] = 2
	pars["needle_gain"] = 8
	var game = fix.open(self, pars)
	await t.frames(1)
	var beam = game._beam
	beam.set("fast", true)
	# All weights off, then 200 + 100 on and the poise home: indicated = 300 = actual.
	for i in game._on.size():
		if game._on[i]:
			game.apply_op(["weight", i])
	game.apply_op(["poise", 1])
	game.apply_op(["poise", 0])
	game.apply_op(["weight", 0])
	game.apply_op(["weight", 1])
	beam.call("settle")
	t.eq(int(game._delta()), 0, "indicated equals actual")
	t.eq(int(beam.needle_offset_px()), 0, "needle centred when level")
	var offs: Array = []
	for s in [1, 2, 3, 6]:
		game.apply_op(["poise", s])
		beam.call("settle")
		offs.append(int(beam.needle_offset_px()))
	t.ok(absi(int(offs[0])) >= 3 and absi(int(offs[0])) <= 6, "one step off is a plain lean, 3-6 px (%d)" % int(offs[0]))
	t.ok(absi(int(offs[1])) > absi(int(offs[0])) - 1 and absi(int(offs[2])) > absi(int(offs[0])),
		"more steps off, more pixels %s" % str(offs))
	t.ok(absi(int(offs[3])) >= 8, "six steps off is plain to see (%d)" % int(offs[3]))
	t.ok(int(offs[0]) > 0, "poise side heavier: the needle leans away from the pan")
	game.apply_op(["poise", 0])
	game.apply_op(["weight", 1])
	beam.call("settle")
	t.ok(int(beam.needle_offset_px()) < -8, "goods heavier: the needle leans toward the pan")
	var src := FileAccess.get_file_as_string("res://scripts/cards/minigames/weigh/weigh_beam.gd")
	t.ok(not src.contains("gold_glow") and not src.contains("if level"), "no level light on the pivot (B9)")
	game.queue_free()
	await t.frames(1)


func _bench(t, fix) -> void:
	var bench = fix.open(self, fix.params("match"))
	await t.frames(2)
	bench._refresh(false)
	var proc := Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	var wait_t0 := Time.get_ticks_usec()
	while (proc <= 0.0 or proc > 4.0) and Time.get_ticks_usec() - wait_t0 < 2200000:
		await t.frames(1)
		proc = Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	var refresh_samples: Array = []
	for _r in 5:
		var t0 := Time.get_ticks_usec()
		for _i in 40:
			bench._refresh(false)
		refresh_samples.append(float(Time.get_ticks_usec() - t0) / 40.0 / 1000.0)
	refresh_samples.sort()
	var step_ms := float(refresh_samples[refresh_samples.size() / 2])
	bench.queue_free()
	await t.frames(1)
	t.ok(proc <= 4.0, "process frame %.3f ms" % proc)
	t.ok(step_ms <= 4.0, "refresh frame %.3f ms" % step_ms)
	print("C14_FRAME_MS process %.4f refresh %.4f" % [proc, step_ms])
