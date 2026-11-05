# op 回放（DESIGN §3.6、§13）：A 实例 autoplay(x) → ops_log() → B 实例逐个 apply_op → 两次 finished 的结果逐键相等
# （观察、measures、minutes、quality_permille 全一样）；改一个 op 结果就不同；不合法的 op 返回 false、什么都不改。
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const H = preload("res://scripts/tests/cards/C13/harness.gd")
const SKILLS := [0.0, 0.3, 0.8, 1.0]


func _initialize() -> void:
	var t := T.new(self, H.arg("name", "C13_replay"))
	t.run_async(_body.bind(t))


func _body(t) -> void:
	for name in H.ALL:
		var fix := H.fixture(name)
		for skill in SKILLS:
			var a: Dictionary = await H.auto(self, fix, skill)
			var ops: Array = a["ops"]
			t.ok(not ops.is_empty() and ops.back() == ["done"], "%s %.1f: log ends with done" % [name, skill])
			for op in ops:
				t.ok(_plain(op), "%s: op holds only short ASCII and ints %s" % [name, op])
			var b: Dictionary = await H.run_ops(self, fix, ops)
			t.eq(b["result"], a["result"], "%s %.1f: replaying the log gives the same result" % [name, skill])
			t.eq(b["ops"], ops, "%s %.1f: the replay logs the same ops" % [name, skill])
			t.eq(b["accepted"].count(false), 0, "%s %.1f: every logged op replays" % [name, skill])
	await _changed(t)
	await _rejects(t)


## 改一个 op（换一个判断、少吹一枚），结果就不同。
func _changed(t) -> void:
	var fix := H.fixture("v2_wellmade")
	var base: Array = [["blow", -1], ["blow", -2], ["blow", 0], ["call", 2], ["done"]]
	var a: Dictionary = (await H.run_ops(self, fix, base))["result"]
	var other_call := base.duplicate(true)
	other_call[3] = ["call", 1]
	var b: Dictionary = (await H.run_ops(self, fix, other_call))["result"]
	t.ok(JSON.stringify(a) != JSON.stringify(b), "another call gives another result")
	var fewer: Array = [["blow", -1], ["blow", 0], ["call", 2], ["done"]]
	var c: Dictionary = (await H.run_ops(self, fix, fewer))["result"]
	t.ok(c["quality_permille"] != a["quality_permille"] and c["minutes"] != a["minutes"], "one blow less changes clarity and minutes")
	var stack := H.fixture("v2_stack")
	var s1: Dictionary = (await H.run_ops(self, stack, [["clink", 0, 2], ["done"]]))["result"]
	var s2: Dictionary = (await H.run_ops(self, stack, [["clink", 0, 3], ["done"]]))["result"]
	t.eq(s1, s2, "the result does not depend on what the clinked pair sounded like (the ear is the player's)")


## 不合法的 op：返回 false，局面和日志都不变。
func _rejects(t) -> void:
	var bus := CardEventBus.new()
	root.add_child(bus)
	var g := H.open(self, H.fixture("v2_good"), bus)
	var bad: Array = [[], ["blow"], ["blow", 3], ["blow", -3], ["blow", "x"], ["blow", 0.5], ["clink", 0, 0],
		["mark", 0, 1], ["call", 0], ["call", 4], ["call", 1, 2], ["sing"], ["done", 1]]
	for op in bad:
		t.ok(not g.apply_op(op), "rejects %s" % [op])
	t.eq(g.ops_log(), [], "rejected ops are not logged")
	t.eq(g._tries_left, g._tries_total, "rejected ops spend nothing")
	t.ok(g.apply_op(["blow", 0.0]), "a whole float from JSON still counts as an int")
	t.eq(g.ops_log(), [["blow", 0]], "logged as an int")
	for _i in range(g._tries_left):
		g.apply_op(["blow", -1])
	t.eq(g._tries_left, 0, "tries spent")
	t.ok(not g.apply_op(["blow", 0]), "no blow without tries")
	t.ok(g.apply_op(["call", 2]), "judging still works without tries")
	t.ok(g.apply_op(["done"]), "done")
	t.ok(not g.apply_op(["call", 1]), "nothing after done")
	await H.drop(self, [g, bus])


func _plain(op) -> bool:
	if typeof(op) != TYPE_ARRAY or (op as Array).is_empty() or typeof(op[0]) != TYPE_STRING:
		return false
	if str(op[0]).length() > 8 or not str(op[0]).is_valid_ascii_identifier():
		return false
	for k in range(1, (op as Array).size()):
		if typeof(op[k]) != TYPE_INT:
			return false
	return true
