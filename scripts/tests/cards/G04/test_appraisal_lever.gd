# G04 鉴定改版 Level B“说破”（编排 10-25 拍板：做；冤枉人不扣口碑）：识破让价、只说中旧痕稍让、冤枉了耐心掉一截底价抬高；
# 每位客人每次上门只结算一次；放弃的不结算；乱点不占便宜；说破只改会话的 asking / floor / patience。
# 替掉旧断言“鉴定不影响价格”（B13）：没说中、老小游戏不交新 measures 时仍然不影响价格。
extends SceneTree
const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const S = preload("res://scripts/tests/cards/G04/economy_test_support.gd")
const A = preload("res://scripts/tests/cards/G04/appraisal_support.gd")
const E = preload("res://scripts/cards/economy/economy_support.gd")


func _initialize() -> void:
	var t := T.new(self, "G04_appraisal_lever")
	_caught(t)
	_soft(t)
	_offended(t)
	_spam(t)
	_once(t)
	_aborted(t)
	_old_minigame(t)
	_offended_leaves(t)
	_not_for_buyers_or_documents(t)
	t.finish()


## Opens a fresh pawn customer whose hairpin has the given truth and requests a spot appraisal.
func _setup(fake: bool, seed: int = 5) -> Dictionary:
	var c := A.real_ctx(seed)
	var pair := A.pawn_with(c)
	var uid := str(pair[0])
	var item := str(pair[1])
	A.set_truth(c, item, fake)
	var req := CardAppraisal.request(c, uid, item)
	var ans: Dictionary = c.state.ns("econ")["appraisals"][uid]["answer"]
	return {"c": c, "uid": uid, "item": item, "kind": str(req.get("kind", "")), "answer": ans,
		"before": E.session(c, uid).duplicate(true), "tiers": CardPricing.tiers(c, uid), "money": CardCurrency.money(c)}


func _report(x: Dictionary, how: String, minutes: int = 1, aborted: bool = false) -> Dictionary:
	var r := A.result([], {"spots": A.spot_pins(x["answer"], how), "ink_used": 3, "atlas": true, "lens": true}, 1000, minutes)
	r["aborted"] = aborted
	return CardAppraisal.report(x["c"], x["uid"], x["item"], r)


func _session(x: Dictionary) -> Dictionary:
	return E.session(x["c"], x["uid"])


## Only asking / floor / patience (and the lever bookkeeping) may differ from the session before the report.
func _only_lever_fields(t, x: Dictionary, label: String) -> void:
	var now := _session(x)
	for k in (x["before"] as Dictionary).keys():
		if str(k) in ["asking", "floor", "patience"]:
			continue
		t.eq(now.get(k), x["before"][k], "%s: session field %s untouched" % [label, k])
	for k in now.keys():
		if not (x["before"] as Dictionary).has(k):
			t.ok(str(k) in ["lever_done", "lever_line"], "%s: only lever bookkeeping added (%s)" % [label, k])
	t.eq(CardCurrency.money(x["c"]), int(x["money"]), "%s: money untouched" % label)


func _caught(t) -> void:
	var x := _setup(true)
	t.eq(x["kind"], "spot", "fixture pawn uses spot")
	var v := CardAppraisal.judge(&"spot", x["answer"], A.result([], {"spots": A.spot_pins(x["answer"], "right")}))
	t.eq(int(v["right"]), 1, "the fake mark is named")
	_report(x, "right")
	var s := _session(x)
	var b: Dictionary = x["before"]
	t.eq(int(s["asking"]), maxi(1, int(b["asking"]) * 70 / 100), "caught: asking x70")
	t.eq(int(s["floor"]), maxi(1, int(b["floor"]) * 55 / 100), "caught: floor x55")
	t.eq(int(s["patience"]), int(b["patience"]) - 1, "caught: only the minutes spent")
	t.eq(str(CardCounter.view(x["c"], x["uid"])["line_key"]), "g04.counter.lever.caught", "caught: the customer's line")
	t.ok(int(CardPricing.tiers(x["c"], x["uid"])["fair"]) < int(x["tiers"]["fair"]), "caught: the three prices follow the new asking")
	t.no_leaks(CardCounter.view(x["c"], x["uid"]), "counter view after the lever")
	_only_lever_fields(t, x, "caught")
	CardEconomyInstall._command(x["c"], {"uid": x["uid"], "tier": "fair"}, &"counter.offer")
	t.ok(not _session(x).has("lever_line") or _session(x).is_empty(), "the next command clears the lever line")
	S.assert_clean(t, x["c"])


func _soft(t) -> void:
	var x := _setup(false)
	_report(x, "right")
	var s := _session(x)
	var b: Dictionary = x["before"]
	t.eq(int(s["asking"]), maxi(1, int(b["asking"]) * 95 / 100), "soft: asking x95")
	t.eq(int(s["floor"]), maxi(1, int(b["floor"]) * 95 / 100), "soft: floor x95")
	t.eq(str(CardCounter.view(x["c"], x["uid"])["line_key"]), "g04.counter.lever.soft", "soft: the customer's line")
	_only_lever_fields(t, x, "soft")


func _offended(t) -> void:
	var x := _setup(false)
	_report(x, "differs")
	var s := _session(x)
	var b: Dictionary = x["before"]
	t.eq(int(s["patience"]), int(b["patience"]) - 1 - 20, "offended: patience drops by offend_min")
	t.eq(int(s["floor"]), int(b["floor"]) * 110 / 100, "offended: floor raised x110")
	t.ok(int(s["asking"]) >= int(b["asking"]), "offended: asking never drops")
	t.eq(str(CardCounter.view(x["c"], x["uid"])["line_key"]), "g04.counter.lever.offended", "offended: the customer's line")
	_only_lever_fields(t, x, "offended")


## Calling everything "different" on a fake: one right, two wrongs -> not caught (net <= 0), the customer is offended.
func _spam(t) -> void:
	var x := _setup(true)
	_report(x, "differs")
	var s := _session(x)
	t.ok(int(s["asking"]) >= int(x["before"]["asking"]), "spam on a fake does not lower the asking price")
	t.eq(str(CardCounter.view(x["c"], x["uid"])["line_key"]), "g04.counter.lever.offended", "spam on a fake offends")


func _once(t) -> void:
	var x := _setup(true)
	_report(x, "right")
	var after := _session(x).duplicate(true)
	CardAppraisal.request(x["c"], x["uid"], x["item"])
	x["answer"] = x["c"].state.ns("econ")["appraisals"][x["uid"]]["answer"]
	_report(x, "right", 0)
	var s := _session(x)
	t.eq(int(s["asking"]), int(after["asking"]), "second report in the same visit settles nothing (asking)")
	t.eq(int(s["floor"]), int(after["floor"]), "second report in the same visit settles nothing (floor)")


func _aborted(t) -> void:
	var x := _setup(true)
	_report(x, "right", 1, true)
	t.eq(int(_session(x)["asking"]), int(x["before"]["asking"]), "aborted report settles nothing")
	t.ok(not bool(_session(x).get("lever_done", false)), "aborted report keeps the lever for later")
	CardAppraisal.request(x["c"], x["uid"], x["item"])
	x["answer"] = x["c"].state.ns("econ")["appraisals"][x["uid"]]["answer"]
	_report(x, "right")
	t.eq(int(_session(x)["asking"]), maxi(1, int(x["before"]["asking"]) * 70 / 100), "the next real look still settles")


## B13 replaced: an old minigame (no new measures) and a claim that names nothing leave the prices alone.
func _old_minigame(t) -> void:
	for fake in [false, true]:
		var x := _setup(fake)
		CardAppraisal.report(x["c"], x["uid"], x["item"], A.result(["obs.spot.authenticity.differs"], {"strokes": 3, "hits": 3}, 900, 2))
		t.eq(CardPricing.tiers(x["c"], x["uid"]), x["tiers"], "old measures: no pricing effect (fake=%s)" % fake)
		t.ok(str(CardCounter.view(x["c"], x["uid"])["line_key"]).ends_with("#lines.greet"), "old measures: no lever line")
		var y := _setup(fake, 9)
		CardAppraisal.report(y["c"], y["uid"], y["item"], A.result([], {"spots": [], "ink_used": 0, "atlas": true, "lens": false}))
		t.eq(CardPricing.tiers(y["c"], y["uid"]), y["tiers"], "nothing named: no pricing effect (fake=%s)" % fake)


func _offended_leaves(t) -> void:
	var x := _setup(false)
	_session(x)["patience"] = 15
	_report(x, "differs")
	t.ok(_session(x).is_empty(), "an offended customer with no patience left walks out")
	t.ok(CardPiles.zone_of(x["c"], x["uid"]) != &"hand", "the customer card left the hand")


func _not_for_buyers_or_documents(t) -> void:
	var c := A.real_ctx(4)
	var uid := S.spawn(c, "tk.test.foreign")
	CardAppraisal.request(c, uid, "")
	var ans: Dictionary = c.state.ns("econ")["appraisals"][uid]["answer"]
	var r := CardAppraisal.report(c, uid, "", A.result([], {"placed": int(ans["present"]), "seams": [[0, 1]], "seal_call": 2}))
	t.ok(bool(r.get("ok", false)), "document report ok")
	t.ok(E.session(c, uid).is_empty(), "documents have no session to settle")
	c.run([{"op": "item_gain", "template": "utensils.bowl", "n": 1}], "test")
	var buyer := S.customer(c, "p.test.buy")
	CardCounter.pick_stock(c, buyer, str(CardShelf.items(c)[0]))
	var before := E.session(c, buyer).duplicate(true)
	var req := CardAppraisal.request(c, buyer, str(before["item"]))
	if bool(req.get("ok", false)):
		var bans: Dictionary = c.state.ns("econ")["appraisals"][buyer]["answer"]
		CardAppraisal.report(c, buyer, str(before["item"]), A.result([], {"spots": A.spot_pins(bans, "differs")}))
		t.eq(int(E.session(c, buyer)["asking"]), int(before["asking"]), "a buyer is never talked down by the lever")
		t.ok(not E.session(c, buyer).has("lever_line"), "no lever line for a buyer")
	else:
		t.ok(true, "buyer item has no minigame")
