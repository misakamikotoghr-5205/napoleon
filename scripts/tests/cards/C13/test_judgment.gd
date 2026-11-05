# 判断 = 玩家自己说的（DESIGN §5.5、P2、P8）：autoplay(skill) 的 skill 是每个判断判对的概率。
# 每个夹具：autoplay(1.0) 全对、autoplay(0.0) 全错、0.5 介于两者之间；判错的照样交（观察键跟着判断走，不按对错过滤）；
# 判分用测试自己写的 G04 规则（标哑的坏枚 = right，标哑的好枚 = wrong）。另用真引擎的参数跑：autoplay(1.0) 不冤枉、不漏。
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const H = preload("res://scripts/tests/cards/C13/harness.gd")
const E = preload("res://scripts/cards/economy/economy_support.gd")


func _initialize() -> void:
	var t := T.new(self, H.arg("name", "C13_judgment"))
	t.run_async(_body.bind(t))


func _body(t) -> void:
	for name in H.ALL:
		var fix := H.fixture(name)
		var hi: Dictionary = (await H.auto(self, fix, 1.0))["result"]
		var lo: Dictionary = (await H.auto(self, fix, 0.0))["result"]
		t.ok(H.all_right(name, hi), "%s: autoplay 1.0 judges every coin right %s" % [name, H.judged(hi)])
		t.ok(H.all_wrong(name, lo), "%s: autoplay 0.0 judges every coin wrong %s" % [name, H.judged(lo)])
		var bad: Array = H.ANSWERS[name]
		t.eq(H.judge(name, hi), {"right": bad.size(), "wrong": 0}, "%s: skill 1.0 catches every dull coin, wrongs none" % name)
		var n := (fix["coins"] as Array).size()
		t.eq(H.judge(name, lo), {"right": 0, "wrong": n - bad.size()}, "%s: skill 0.0 misses every dull coin, wrongs every good one" % name)
		t.eq(hi["quality_permille"], lo["quality_permille"], "%s: clarity does not depend on being right" % name)
	await _middle(t)
	await _calls(t)
	await _stack_keys(t)
	await _real_engine(t)


## 0.5：一摞五枚，几个种子里有对有错；同种子两遍一样。
func _middle(t) -> void:
	var mixed := 0
	var right_total := 0
	var coins_total := 0
	for k in range(8):
		var fix := H.fixture("v2_stack")
		fix["seed"] = 4000 + k
		var r: Dictionary = (await H.auto(self, fix, 0.5))["result"]
		var again: Dictionary = (await H.auto(self, fix, 0.5))["result"]
		t.eq(r, again, "skill 0.5 is deterministic for seed %d" % fix["seed"])
		var marks := H.judged(r)
		var right := 0
		for i in range(marks.size()):
			if int(marks[i]) == (2 if [2, 4].has(i) else 1):
				right += 1
		right_total += right
		coins_total += marks.size()
		if right > 0 and right < marks.size():
			mixed += 1
	t.ok(mixed >= 4, "skill 0.5 mixes right and wrong in most rounds (%d of 8)" % mixed)
	t.ok(right_total > coins_total / 5 and right_total < coins_total * 4 / 5, "skill 0.5 is right about half the time (%d of %d)" % [right_total, coins_total])


## 单枚：三个选项各换成一个观察键；没选 = 说不好；说错了照样交。
func _calls(t) -> void:
	var cases := [[1, ["obs.coin_ring.like_reference"]], [2, ["obs.coin_ring.like_dull_sample"]],
		[3, ["obs.coin_ring.unsure"]], [0, ["obs.coin_ring.unsure"]]]
	for name in ["v2_good", "v2_dull"]:
		for row in cases:
			var ops: Array = [["blow", -1], ["blow", -2], ["blow", 0]]
			if int(row[0]) > 0:
				ops.append(["call", row[0]])
			ops.append(["done"])
			var out: Dictionary = await H.run_ops(self, H.fixture(name), ops)
			var r: Dictionary = out["result"]
			t.eq(r["observations"], row[1], "%s call %d -> %s" % [name, row[0], row[1]])
			t.eq(r["measures"]["call"], row[0], "%s call recorded as said" % name)
	# Changing your mind: the last call counts.
	var flip: Dictionary = await H.run_ops(self, H.fixture("v2_dull"), [["call", 2], ["call", 1], ["done"]])
	t.eq(flip["result"]["observations"], ["obs.coin_ring.like_reference"], "last call counts, even when wrong")
	t.eq(flip["result"]["measures"]["marks"], [1], "single coin marks mirror the call")


## 一摞：全响 / 恰好一枚哑 / 两枚以上哑；有没定的加“说不好”。
func _stack_keys(t) -> void:
	var fix := H.fixture("v2_stack")
	var cases := [
		[[1, 1, 1, 1, 1], ["obs.coin_ring.all_ring"]],
		[[1, 1, 2, 1, 1], ["obs.coin_ring.one_dull"]],
		[[1, 1, 2, 1, 2], ["obs.coin_ring.some_dull"]],
		[[1, 1, 2, 0, 0], ["obs.coin_ring.one_dull", "obs.coin_ring.unsure"]],
		[[1, 1, 0, 1, 1], ["obs.coin_ring.unsure"]],
		[[0, 0, 0, 0, 0], ["obs.coin_ring.unsure"]],
	]
	for row in cases:
		var ops: Array = []
		var marks: Array = row[0]
		for i in range(marks.size()):
			if int(marks[i]) != 0:
				ops.append(["mark", i, marks[i]])
		ops.append(["done"])
		var r: Dictionary = (await H.run_ops(self, fix, ops))["result"]
		t.eq(r["observations"], row[1], "stack marks %s -> %s" % [marks, row[1]])
		t.eq(r["measures"]["marks"], marks, "stack marks recorded as said")
		t.eq(r["measures"]["call"], 0, "stack has no single call")
	var bad_ops: Dictionary = await H.run_ops(self, fix, [["call", 1], ["mark", 9, 1], ["mark", 0, 3], ["done"]])
	t.eq(bad_ops["accepted"], [false, false, false, true], "stack refuses a single call and bad marks")


## 真引擎（现在的 G04，WP1 合了以后是新参数）给的参数：autoplay(1.0) 不冤枉好的，也不放过哑的。
func _real_engine(t) -> void:
	var eng := CardEngine.new()
	var started := eng.new_game({"seed": 23, "save_dir": t.user_dir() + "/save"})
	t.ok(bool(started.get("ok", false)), "real engine new game")
	var c: CardCtx = eng.ctx
	var seen := {"bad": 0, "good": 0}
	for template in ["silver.yuan_a", "silver.yuan_b", "silver.yuan_c"]:
		for k in range(14):
			var item := str(CardItems.generate(c, ["c", 1, "c13_judgment", template, k], template).get("item", ""))
			var p := CardAppraisal.params_for(c, item, &"coin_ring")
			var dull := bool(E.meta(c, item).get("fake", false))
			seen["bad" if dull else "good"] += 1
			var r: Dictionary = (await H.auto(self, p, 1.0))["result"]
			var marks := H.judged(r)
			var n := (p.get("coins", []) as Array).size()
			t.eq(marks.size(), n, "%s %s: one judgment per coin" % [template, item])
			var wrong := 0
			var dull_marks := 0
			for m in marks:
				if int(m) == 2:
					dull_marks += 1
			if not dull:
				wrong = dull_marks
			t.eq(wrong, 0, "%s %s: skill 1.0 never calls a good coin dull" % [template, item])
			if dull:
				t.ok(dull_marks >= 1, "%s %s: skill 1.0 hears the dull coin" % [template, item])
			t.ok(CardAppraisal._valid_result(r), "%s %s: the engine accepts the result" % [template, item])
	t.ok(int(seen["bad"]) > 0 and int(seen["good"]) > 0, "real engine gave both kinds %s" % seen)
