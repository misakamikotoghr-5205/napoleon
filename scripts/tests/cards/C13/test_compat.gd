# 老参数也能玩完（DESIGN P9、§13）：现在 mock 的 mg.request、改版前的夹具（没有 samples / ghosts / clink）、
# 真引擎现在给的参数，都能 start、用鼠标或自动玩走完，结果引擎收。没有 samples 时：足银样洋 = reference，
# 哑板样洋 = 规格默认坏区间的中值；没有 reference 也有默认；坏数据（空 coins、浮点、一摞超过五枚）不报错。
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const H = preload("res://scripts/tests/cards/C13/harness.gd")


func _initialize() -> void:
	var t := T.new(self, H.arg("name", "C13_compat"))
	t.run_async(_body.bind(t))


func _body(t) -> void:
	await _mock(t)
	for name in ["good", "bad", "one_try", "stack"]:
		await _plays(t, H.fixture(name), name)
	await _defaults(t)
	await _odd(t)
	await _engine(t)


## What MockCardEngine's mg.request gives coin_ring before WP0 updates it (mock_scenario.gd _mg_params, 00e36ef6).
func _mock(t) -> void:
	var params := {"kind": "coin_ring", "seed": 99, "item": "", "art": "item.silver.yuan_a", "minutes_per_step": 1,
		"max_minutes": 30, "coins": [{"id": "a", "ring_ms": 1350, "pitch_cents": -40, "buzz": 12}],
		"reference": {"ring_ms": 1450, "pitch_cents": 0, "buzz": 8}, "tries": 3}
	await _plays(t, params, "mock")


func _plays(t, params: Dictionary, label: String) -> void:
	for skill in [0.2, 0.8]:
		var r: Dictionary = (await H.auto(self, params, skill))["result"]
		t.ok(not r.is_empty() and r.get("aborted", true) == false, "%s %.1f: plays to the end" % [label, skill])
		t.ok(CardAppraisal._valid_result(r), "%s %.1f: the engine accepts the result" % [label, skill])
	# And by mouse: blow every sample and coin there are tries for, then done.
	var bus := CardEventBus.new()
	root.add_child(bus)
	var g := H.open(self, params, bus)
	var box: Array = [null]
	g.finished.connect(func(r: Dictionary) -> void: box[0] = r)
	await t.frames(1)
	for f in g._sample_faces + g._coin_faces:
		H.click(g, H.center(f))
	H.click(g, H.center(g._done_btn))
	t.ok(box[0] != null and CardAppraisal._valid_result(box[0]), "%s: mouse round accepted" % label)
	await H.drop(self, [g, bus])


func _defaults(t) -> void:
	var bus := CardEventBus.new()
	root.add_child(bus)
	var old := H.fixture("good")
	var g := H.open(self, old, bus)
	t.eq(g._good, {"ring_ms": 1450, "pitch_cents": 0, "buzz": 6}, "no samples: the good sample is the reference")
	t.eq(g._dull, CardCoinRingGame.DEFAULT_DULL, "no samples: the dull sample is the spec's bad mid-range")
	t.eq([g._pin, g._rolling, g._wave.cap], [true, 1, 3], "no ghosts param: one ghost, both samples pinned (three rows)")
	t.eq(g._clink_ok, false, "one coin cannot clink")
	await H.drop(self, [g])
	var bare := old.duplicate(true)
	bare.erase("reference")
	g = H.open(self, bare, bus)
	t.eq(g._good, CardCoinRingGame.DEFAULT_GOOD, "no reference either: a default good sample")
	await H.drop(self, [g])
	var unnamed := H.fixture("v2_good")
	unnamed["samples"] = [{"ring_ms": 1300, "pitch_cents": 10, "buzz": 5}, {"ring_ms": 600, "pitch_cents": -150, "buzz": 50}]
	g = H.open(self, unnamed, bus)
	t.eq(g._good["ring_ms"], 1300, "samples without ids: first is the good one")
	t.eq(g._dull["ring_ms"], 600, "samples without ids: second is the dull one")
	await H.drop(self, [g])
	var named := H.fixture("v2_good")
	named["samples"] = [{"id": "dull", "ring_ms": 610, "pitch_cents": -160, "buzz": 55}, {"id": "good", "ring_ms": 1310, "pitch_cents": 0, "buzz": 5}]
	g = H.open(self, named, bus)
	t.eq([g._good["ring_ms"], g._dull["ring_ms"]], [1310, 610], "samples by id in any order")
	var stack_off := H.fixture("v2_stack")
	stack_off["clink"] = false
	await H.drop(self, [g])
	g = H.open(self, stack_off, bus)
	t.ok(not g.apply_op(["clink", 0, 1]), "clink: false turns clinking off")
	await H.drop(self, [g, bus])


func _odd(t) -> void:
	var cases := [
		{"kind": "coin_ring", "seed": 1, "coins": [], "tries": 2},
		{"kind": "coin_ring", "seed": 2},
		{"kind": "coin_ring", "seed": 3.0, "coins": [{"id": "a", "ring_ms": 1400.0, "pitch_cents": -3.0, "buzz": 2.0}], "tries": 3.0},
		{"kind": "coin_ring", "seed": 4, "coins": [{"ring_ms": 1}, {"ring_ms": 2}, {"ring_ms": 3}, {"ring_ms": 4}, {"ring_ms": 5}, {"ring_ms": 6}, {"ring_ms": 7}], "tries": 12},
	]
	for i in range(cases.size()):
		var r: Dictionary = (await H.auto(self, cases[i], 0.8))["result"]
		t.ok(CardAppraisal._valid_result(r), "odd params %d still finish" % i)
	var empty: Dictionary = (await H.auto(self, cases[0], 0.8))["result"]
	t.eq(empty["observations"], ["obs.coin_ring.unsure"], "no coin: unsure")
	var bus := CardEventBus.new()
	root.add_child(bus)
	var g := H.open(self, cases[3], bus)
	t.eq(g._coins.size(), 5, "a roll is at most five coins")
	await H.drop(self, [g, bus])


## 真引擎给的参数（现在的 G04；WP1 合了以后是新参数），开局能玩完。
func _engine(t) -> void:
	var eng := CardEngine.new()
	var started := eng.new_game({"seed": 31, "save_dir": t.user_dir() + "/save"})
	t.ok(bool(started.get("ok", false)), "real engine new game")
	var c: CardCtx = eng.ctx
	for k in range(6):
		var item := str(CardItems.generate(c, ["c", 1, "c13_compat", k], "silver.yuan_b").get("item", ""))
		var p := CardAppraisal.params_for(c, item, &"coin_ring")
		t.ok(not p.is_empty(), "engine params for %s" % item)
		await _plays(t, p, "engine " + item)
