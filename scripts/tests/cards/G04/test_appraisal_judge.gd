# G04 鉴定改版：judge() 表驱动、record() 的 hedge 规则、答案不出私账、同参数同操作同哈希。
# 主创 10-25：“你那个鉴定不能只是点点点，要玩家看出来才算数”。
extends SceneTree
const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const S = preload("res://scripts/tests/cards/G04/economy_test_support.gd")
const A = preload("res://scripts/tests/cards/G04/appraisal_support.gd")
const E = preload("res://scripts/cards/economy/economy_support.gd")

const SPOT := {"marks": [["authenticity", "differs", 10, 10, 4, 4, 800], ["condition", "wear", 30, 30, 6, 6, 300],
	["provenance", "wear", 50, 10, 6, 6, 300]], "tol": [2, 1, 500]}


func _initialize() -> void:
	var t := T.new(self, "G04_appraisal_judge")
	_spot(t)
	_coin(t)
	_weigh(t)
	_fragments(t)
	_decode(t)
	_record(t)
	_private(t)
	_replay(t)
	t.finish()


func _j(kind: String, answer: Dictionary, measures: Dictionary) -> Array:
	var v := CardAppraisal.judge(StringName(kind), answer, A.result([], measures))
	return [int(v["right"]), int(v["wrong"]), int(v["soft"])]


func _spot(t) -> void:
	var rows := [
		[[[11, 11, 2]], [1, 0, 0], "differs named on the fake mark"],
		[[[31, 31, 1]], [0, 0, 1], "honest wear named as wear"],
		[[[31, 31, 2]], [0, 1, 0], "wear called different is a wrong"],
		[[[11, 11, 1]], [0, 0, 0], "fake mark called wear counts nothing"],
		[[[0, 60, 2]], [0, 1, 0], "differs on nothing is a wrong"],
		[[[0, 60, 1]], [0, 0, 0], "wear on nothing counts nothing"],
		[[[9, 10, 2]], [1, 0, 0], "fine mark tolerance 1 px"],
		[[[8, 10, 2]], [0, 1, 0], "outside the fine tolerance"],
		[[[28, 31, 1]], [0, 0, 1], "coarse mark tolerance 2 px"],
		[[[27, 31, 1]], [0, 0, 0], "outside the coarse tolerance"],
		[[[11, 11, 2], [12, 12, 2]], [1, 0, 0], "one mark counts once"],
		[[[11, 11, 2], [31, 31, 2], [52, 12, 2]], [1, 2, 0], "spamming differs: one right, two wrong"],
	]
	for row in rows:
		t.eq(_j("spot", SPOT, {"spots": row[0], "ink_used": 1, "atlas": true, "lens": true}), row[1], "spot: " + str(row[2]))
	t.eq(_j("spot", SPOT, {"strokes": 3, "hits": 2}), [0, 0, 0], "spot: old measures (strokes/hits) judge nothing")
	var aborted := A.result([], {"spots": [[11, 11, 2]]})
	aborted["aborted"] = true
	t.eq(CardAppraisal.judge(&"spot", SPOT, aborted), {"right": 0, "wrong": 0, "soft": 0}, "spot: aborted judges nothing")


func _coin(t) -> void:
	t.eq(_j("coin_ring", {"bad": [0], "n": 1}, {"call": 2}), [1, 0, 0], "coin: dull called on the dull coin")
	t.eq(_j("coin_ring", {"bad": [], "n": 1}, {"call": 2}), [0, 1, 0], "coin: dull called on a good coin")
	t.eq(_j("coin_ring", {"bad": [0], "n": 1}, {"call": 1}), [0, 0, 0], "coin: missed dull counts nothing")
	t.eq(_j("coin_ring", {"bad": [], "n": 1}, {"call": 3}), [0, 0, 0], "coin: unsure counts nothing")
	t.eq(_j("coin_ring", {"bad": [1, 3], "n": 4}, {"marks": [1, 2, 0, 2]}), [2, 0, 0], "coin stack: both dull coins marked")
	t.eq(_j("coin_ring", {"bad": [1], "n": 4}, {"marks": [2, 1, 1, 1]}), [0, 1, 0], "coin stack: a ringing coin marked dull")
	t.eq(_j("coin_ring", {"bad": [0], "n": 1}, {"listened_ms": 900, "compared": true}), [0, 0, 0], "coin: old measures")


func _weigh(t) -> void:
	var calls := {"match": 1, "light_small": 2, "light_much": 3, "heavy": 4, "unsure": 5}
	var rows := [["light_much", "light_much", [1, 0, 0]], ["heavy", "heavy", [1, 0, 0]], ["light_much", "match", [0, 1, 0]],
		["light_much", "light_small", [0, 1, 0]], ["heavy", "match", [0, 1, 0]], ["heavy", "light_much", [0, 0, 0]],
		["light_small", "light_small", [0, 0, 1]], ["light_small", "light_much", [0, 0, 0]], ["match", "light_much", [0, 0, 0]],
		["unsure", "heavy", [0, 0, 0]]]
	for row in rows:
		t.eq(_j("weigh", {"cat": row[1]}, {"call": calls[row[0]], "read_fen": 1, "steps": 1, "commits": 1}), row[2],
			"weigh: said %s, truth %s" % [row[0], row[1]])
	t.eq(_j("weigh", {"cat": "light_much"}, {"read_fen": 290, "steps": 4}), [0, 0, 0], "weigh: old measures")
	t.eq(CardAppraisal.weigh_cat(0, 1, 10), "match", "weigh_cat match")
	t.eq(CardAppraisal.weigh_cat(-10, 1, 10), "light_small", "weigh_cat light_small edge")
	t.eq(CardAppraisal.weigh_cat(-11, 1, 10), "light_much", "weigh_cat light_much")
	t.eq(CardAppraisal.weigh_cat(11, 10, 160), "heavy", "weigh_cat heavy beyond resolution")
	t.eq(CardAppraisal.weigh_cat(10, 10, 160), "match", "weigh_cat within resolution")


func _fragments(t) -> void:
	var odd := {"seal_off": true, "odd": [2], "pieces": 6, "present": 6}
	var sound := {"seal_off": false, "odd": [], "pieces": 6, "present": 6}
	t.eq(_j("fragments", odd, {"seams": [[1, 2]], "seal_call": 0}), [1, 0, 0], "fragments: seam next to the odd piece")
	t.eq(_j("fragments", odd, {"seams": [[1, 2], [2, 3]]}), [1, 0, 0], "fragments: one odd piece counts once")
	t.eq(_j("fragments", odd, {"seams": [[0, 1]]}), [0, 1, 0], "fragments: seam between sound pieces is a wrong")
	t.eq(_j("fragments", odd, {"seal_call": 2}), [1, 0, 0], "fragments: offset seal named")
	t.eq(_j("fragments", sound, {"seal_call": 2}), [0, 1, 0], "fragments: aligned seal called offset")
	t.eq(_j("fragments", odd, {"seal_call": 1}), [0, 0, 0], "fragments: offset seal missed counts nothing")
	t.eq(_j("fragments", odd, {"placed": 6, "rotations": 1, "seal_checked": true}), [0, 0, 0], "fragments: old measures")


func _decode(t) -> void:
	var ans := {"codes": ["5120", "5121", "0417"]}
	t.eq(_j("decode", ans, {"picked": [5120, 5127, -1]}), [1, 1, 0], "decode: one right, one wrong, one empty")
	t.eq(_j("decode", ans, {"picked": [5120, 5121, 417]}), [3, 0, 0], "decode: leading zero codes compare as integers")
	t.eq(_j("decode", ans, {"decoded": 2, "lookups": 5}), [0, 0, 0], "decode: old measures")


func _record(t) -> void:
	var cat := {
		"obs.weigh.light_small": {"fidelity": "clear", "hedge": {"partial": "obs.weigh.light_vague", "vague": "obs.weigh.unsure"}},
		"obs.weigh.light_much": {"fidelity": "clear", "hedge": {"partial": "obs.weigh.light_vague", "vague": ""}},
		"obs.weigh.light_vague": {"fidelity": "partial"},
		"obs.weigh.unsure": {"fidelity": "any"},
		"obs.weigh.match": {"fidelity": "clear"},
	}
	t.eq(CardAppraisal.record(cat, "clear", ["obs.weigh.light_small"]), ["obs.weigh.light_small"], "hedge: clear keeps the claim")
	t.eq(CardAppraisal.record(cat, "partial", ["obs.weigh.light_small"]), ["obs.weigh.light_vague"], "hedge: partial softens")
	t.eq(CardAppraisal.record(cat, "vague", ["obs.weigh.light_small"]), ["obs.weigh.unsure"], "hedge: vague softens more")
	t.eq(CardAppraisal.record(cat, "vague", ["obs.weigh.light_much"]), [], "hedge: empty string records nothing")
	for band in ["clear", "partial", "vague"]:
		t.eq(CardAppraisal.record(cat, band, ["obs.weigh.unsure"]), ["obs.weigh.unsure"], "any is kept at " + band)
	t.eq(CardAppraisal.record(cat, "partial", ["obs.weigh.match"]), [], "old entry without hedge is dropped at another band")
	t.eq(CardAppraisal.record(cat, "clear", ["obs.weigh.match", "obs.missing", 5, "obs.weigh.unsure"]),
		["obs.weigh.match", "obs.weigh.unsure"], "unknown keys skipped, mixed bands kept (B1)")
	t.eq(CardAppraisal.record(cat, "partial", ["obs.weigh.light_small", "obs.weigh.light_much"]), ["obs.weigh.light_vague"],
		"two claims hedging to one key record it once")


## The answer is the engine's private record: never in params, views, queries, events or the report reply.
func _private(t) -> void:
	var c := A.real_ctx(3)
	var private_keys := ["answer", "bad", "odd", "seal_off", "tol"]
	for tpl in ["jewelry.hairpin", "silver.yuan_b", "goldbar.bar_ten", "art.landscape"]:
		for fake in [false, true]:
			for id in A.items_of(c, tpl, fake, 2, "private"):
				var d := CardAppraisal._spec(c, id)
				for kind in d.get("minigames", []):
					var p := CardAppraisal.params_for(c, id, StringName(str(kind)))
					t.ok(not S.forbidden(p), "%s %s params have no forbidden keys" % [tpl, kind])
					t.ok(not A.has_key(p, private_keys), "%s %s params carry no answer" % [tpl, kind])
					var leaks := CardViewModel.leaks([p])
					var bad: Array = []
					for path in leaks:
						if not RegEx.create_from_string("^\\[0\\]\\.(marks\\[\\d+\\]\\.)?seed$").search(path):
							bad.append(path)
					t.eq(bad, [], "%s %s params avoid the view blacklist (only layout seeds)" % [tpl, kind])
	var pair := A.pawn_with(c)
	var uid := str(pair[0])
	var item := str(pair[1])
	c.out.clear()
	var req := CardAppraisal.request(c, uid, item)
	t.ok(bool(req.get("ok", false)), "request ok")
	var active: Dictionary = c.state.ns("econ")["appraisals"][uid]
	t.ok(active.has("answer") and not (active["answer"] as Dictionary).is_empty(), "answer kept in econ.appraisals")
	t.ok(not A.has_key(req, private_keys), "request reply carries no answer")
	for q in [CardCounter.view(c, uid), {"items": CardShelf.view(c)}, {"tickets": CardTickets.view(c)}]:
		t.ok(not A.has_key(q, private_keys), "views and queries carry no answer")
		t.no_leaks(q, "counter / stock / tickets")
	var marks: Array = active["answer"]["marks"]
	var rep := CardAppraisal.report(c, uid, item, A.result(["obs.spot.authenticity.differs"], {"spots": A.spot_pins(active["answer"], "right")}))
	t.eq(rep.keys().size(), 3, "report reply is only ok / err / observations")
	t.ok(rep.has("ok") and rep.has("err") and rep.has("observations"), "report reply keys")
	t.ok(marks.size() == 3, "three marks in the private answer")
	for ev in c.out:
		t.ok(not A.has_key(ev.slice(1), private_keys), "event %s carries no answer" % ev[0])
	t.ok(not c.state.ns("econ")["appraisals"].has(uid), "private record cleared after the report")
	S.assert_clean(t, c)


## Same seed, same commands (request + report with the same player ops) -> same state hash.
func _replay(t) -> void:
	var hashes: Array = []
	for run in range(2):
		var c := A.real_ctx(11)
		var pair := A.pawn_with(c)
		var uid := str(pair[0])
		var item := str(pair[1])
		CardAppraisal.request(c, uid, item)
		var ans: Dictionary = c.state.ns("econ")["appraisals"][uid]["answer"]
		CardAppraisal.report(c, uid, item, A.result(["obs.spot.condition.wear"], {"spots": A.spot_pins(ans, "differs"), "ink_used": 3, "atlas": true, "lens": false}, 800, 6))
		CardCounter.offer(c, uid, &"fair")
		E.sync(c)
		hashes.append(c.state.hash())
	t.eq(hashes[0], hashes[1], "appraisal replay is deterministic")
