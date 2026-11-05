# The player's call is what is recorded (DESIGN 3.1, 4.5, P2, P8). autoplay(skill): skill = chance each
# call is right: 1.0 pins every mark with the right call, 0.0 gets every one wrong, 0.5 lands in between
# over many seeds. A wrong call is handed back as said (no filtering, no correction). The test judges with
# its own copy of the G04 rules (c12_lib.judge); when CardAppraisal.judge exists it must agree.
# Owner C12.
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const Lib = preload("res://scripts/tests/cards/C12/c12_lib.gd")
const Marks = preload("res://scripts/cards/minigames/spot/spot_marks.gd")

var _engine_judge: Script = null


func _initialize() -> void:
	var t := T.new(self, "C12_judgment")
	t.run_async(_body.bind(t))


func _body(t) -> void:
	var bus := CardEventBus.new()
	root.add_child(bus)
	var mock := MockCardEngine.new(bus)
	t.ok(mock.db != null, "text db")
	await t.frames(1)
	var scr: Script = load("res://scripts/cards/economy/appraisal.gd")
	for m in scr.get_script_method_list():
		if str(m.get("name", "")) == "judge":
			_engine_judge = scr
	print("engine judge present: ", _engine_judge != null)
	for name in Lib.fixture_names():
		var params: Dictionary = Lib.fixture(name)
		var n_marks := (params.get("marks", []) as Array).size()
		var best := _play(params, 1.0)
		var worst := _play(params, 0.0)
		var jb: Dictionary = Lib.judge(params, best.get("measures", {}).get("spots", []))
		var jw: Dictionary = Lib.judge(params, worst.get("measures", {}).get("spots", []))
		var want := mini(n_marks, int(params.get("ink", 3)))
		t.eq(int(jb["right"]) + int(jb["soft"]), want, name + " skill 1.0: every call right")
		t.eq(int(jb["wrong"]) + int(jb["missed"]) + int(jb["idle"]), 0, name + " skill 1.0: nothing wrong")
		t.eq(int(jw["right"]) + int(jw["soft"]), 0, name + " skill 0.0: no call right")
		t.eq(int(jw["wrong"]) + int(jw["missed"]) + int(jw["idle"]), want, name + " skill 0.0: every call wrong")
		_cross_check(t, name, params, best)
		_cross_check(t, name, params, worst)
	_middle(t)
	_wrong_calls_kept(t)
	bus.queue_free()
	await t.frames(3)


func _play(params: Dictionary, skill: float) -> Dictionary:
	var r = Lib.run(self, params, func(g: CardSpotGame) -> void: g.autoplay(skill))
	return r if typeof(r) == TYPE_DICTIONARY else {}


## autoplay(0.5) over 40 seeds: some calls right, some wrong.
func _middle(t) -> void:
	var right := 0
	var total := 0
	for s in 40:
		var params: Dictionary = Lib.fixture("hairpin3" if s % 2 == 0 else "scroll3")
		params["seed"] = 7000 + s * 13
		var r := _play(params, 0.5)
		var j: Dictionary = Lib.judge(params, r.get("measures", {}).get("spots", []))
		right += int(j["right"]) + int(j["soft"])
		total += (params["marks"] as Array).size()
	print("skill 0.5: %d of %d right" % [right, total])
	t.ok(right > total * 3 / 10 and right < total * 7 / 10, "skill 0.5 is in between (%d of %d)" % [right, total])
	var hi := 0
	for s in 40:
		var params2: Dictionary = Lib.fixture("hairpin3")
		params2["seed"] = 9100 + s * 7
		var r2 := _play(params2, 0.8)
		var j2: Dictionary = Lib.judge(params2, r2.get("measures", {}).get("spots", []))
		hi += int(j2["right"]) + int(j2["soft"])
	t.ok(hi > 120 * 65 / 100 and hi < 120 * 95 / 100, "skill 0.8 is about eight in ten (%d of 120)" % hi)


## Wrong calls come back as said: the tampered spot called old wear is "wear"; an old-wear spot called
## "not like the book" is "differs"; a pin off every part says nothing.
func _wrong_calls_kept(t) -> void:
	var params: Dictionary = Lib.fixture("hairpin3")
	var r = Lib.replay(self, params, [["atlas"], ["tool", "lens"], ["pin", 28, 35, 1], ["pin", 38, 24, 2],
		["pin", 2, 2, 2], ["done"]])
	t.ok(r != null, "scripted wrong calls finish")
	if r == null:
		return
	t.eq(r.get("observations"), ["obs.spot.authenticity.wear", "obs.spot.provenance.differs"], "wrong calls kept as said")
	var j: Dictionary = Lib.judge(params, r["measures"]["spots"])
	t.eq([int(j["right"]), int(j["soft"]), int(j["wrong"]), int(j["missed"])], [0, 0, 2, 1], "and they are wrong")
	t.eq(int(r.get("quality_permille", 0)), 1000, "quality does not care that they are wrong")
	var clean: Dictionary = Lib.fixture("hairpin3_clean")
	var r2 = Lib.replay(self, clean, [["atlas"], ["tool", "lens"], ["pin", 28, 35, 2], ["done"]])
	t.eq(r2.get("observations"), ["obs.spot.authenticity.differs"], "calling a clean spot different is kept")
	var j2: Dictionary = Lib.judge(clean, r2["measures"]["spots"])
	t.eq(int(j2["wrong"]), 1, "and is a wrong call (the engine's offended)")
	var near = Lib.replay(self, params, [["pin", 28, 37, 2], ["pin", 31, 39, 2], ["done"]])
	var jn: Dictionary = Lib.judge(params, near["measures"]["spots"])
	t.eq([int(jn["right"]), int(jn["wrong"])], [1, 1], "fine spot: 1 px tolerance, 2 px off is a miss")


## Same rules as CardAppraisal.judge (WP1) once it exists.
func _cross_check(t, name: String, params: Dictionary, result: Dictionary) -> void:
	if _engine_judge == null or result.is_empty():
		return
	var rows: Array = []
	for mark in params.get("marks", []):
		var r := Marks.spot_rect(mark, params.get("parts", []))
		rows.append([str(mark.get("part", "")), str(mark.get("kind", "")), r.position.x, r.position.y, r.size.x,
			r.size.y, int(mark.get("fine", 0))])
	var got = _engine_judge.call("judge", &"spot", {"marks": rows}, result)
	if typeof(got) != TYPE_DICTIONARY:
		t.ok(false, name + " engine judge returns a dictionary")
		return
	var mine: Dictionary = Lib.judge(params, result.get("measures", {}).get("spots", []))
	for k in ["right", "wrong", "soft"]:
		t.eq(int((got as Dictionary).get(k, -1)), int(mine[k]), "%s engine judge agrees on %s" % [name, k])
