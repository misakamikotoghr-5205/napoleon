# W0（Claude）：小游戏测试小工具 scripts/tests/cards/lib/mg_ops.gd 自测（鉴定改版 10-25，合同 §8.1、§12.2）。
extends SceneTree
const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const MgOps = preload("res://scripts/tests/cards/lib/mg_ops.gd")
const FAKE := "res://scripts/tests/cards/W0/fake_op_minigame.gd"


func _initialize() -> void:
	var t := T.new(self, "W0_mg_ops")
	t.run_async(_body.bind(t))


func _body(t) -> void:
	var holder := Control.new()
	root.add_child(holder)
	var params := {"kind": "weigh", "seed": 12345, "item": "", "art": "", "minutes_per_step": 1, "max_minutes": 30}
	t.eq(MgOps.replay_check(holder, FAKE, params), PackedStringArray(), "a convention-following minigame replays identically")
	var g := MgOps.open(holder, FAKE, params)
	var played := MgOps.autoplay(g, 1.0)
	t.eq((played["ops"] as Array).back(), ["done"], "ops_log ends with done")
	t.eq(int(played["result"]["measures"]["call"]), 3, "skill 1.0 takes the right call")
	g.queue_free()
	var g2 := MgOps.open(holder, FAKE, params)
	var r := MgOps.replay(g2, [["poise", 0], ["bogus"], ["call", 9], ["done"]])
	t.eq(r["rejected"], [1, 2], "illegal ops are rejected and reported")
	g2.queue_free()
	t.eq(MgOps.diff({"a": 1, "b": [1, 2]}, {"a": 1.0, "b": [1, 3]}), PackedStringArray(["b[1]"]), "diff finds the changed path")
	t.eq(MgOps.diff({"a": 1}, {"a": 1, "c": 2}), PackedStringArray(["c"]), "diff finds a missing key")
	var screen := VBoxContainer.new()
	holder.add_child(screen)
	for s in ["4", "50%", "7"]:
		var l := Label.new()
		l.text = s
		screen.add_child(l)
	var probs := MgOps.text_problems(screen, &"weigh", [4])
	t.eq(probs.size(), 3, "the percent sign, its number 50 and the stray 7 are flagged; the allowed 4 is not")
	t.ok(MgOps.colors(screen).size() >= 1, "colour set collected")
	for kind in [&"spot", &"coin_ring", &"weigh", &"fragments", &"decode"]:
		var cases := MgOps.engine_cases(kind, kind != &"decode", 2)
		t.ok(not cases.is_empty(), "engine cases for %s" % kind)
		for c in cases:
			t.ok(not (c["params"] as Dictionary).is_empty() and not (c["answer"] as Dictionary).is_empty(), "%s case has params and answer" % kind)
			t.eq(MgOps.judge(kind, c["answer"], {"quality_permille": 0, "observations": [], "minutes": 0, "measures": {}, "aborted": false}),
				{"right": 0, "wrong": 0, "soft": 0}, "%s: nothing claimed judges nothing" % kind)
	var spot: Array = MgOps.engine_cases(&"spot", true, 1)
	t.eq((spot[0]["answer"]["marks"] as Array).size(), 3, "spot engine case has three marks")
	holder.queue_free()
	await t.frames(2)
