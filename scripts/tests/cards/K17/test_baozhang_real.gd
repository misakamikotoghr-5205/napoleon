# K17 真数据回归（合同 1.4，#182 第 5 条）：only_examples=false 的真牌库，1940 关从第 1 天一路过日子。
# 第 14 天自然发到手上且只发一次；公开指令 card.choose 走四个分支（打点钱够/不够）；不理直接打烊
# 走 on_expire、留档案缺口并进入下一天；first office 只发一次，gd.office 有步骤、rule.gold 解锁，存读后 first 不重发；真 CardGuide 的亮/完成/存读不重教见 test_baozhang_guide.gd。
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const H = preload("res://scripts/cards/rules/rules_helpers.gd")
const ID := "p.ma.1940.baozhang"
const NODE := "s1940.baozhang"
const ASK := "df.ma.1940.baozhang_ask"
const DAY := 14
const WANT := {
	"take": {"flags": {"office_post": "baozhang", "office_baozhang_take": true}, "marks": 2},
	"nominal": {"flags": {"office_post": "baozhang", "office_baozhang_nominal": true, "office_shield_neighbors": true}, "marks": 1},
	"buy_off": {"flags": {"office_baozhang_buy_off": true}, "marks": 0},
	"refuse": {"flags": {"office_baozhang_refuse": true, "office_foe_ma": true}, "marks": 0},
}


func _initialize() -> void:
	var t := T.new(self, "K17_baozhang_real")
	_guide_data(t)
	for choice in WANT.keys():
		_choice_run(t, choice, false)
	_choice_run(t, "buy_off", true)
	_ignored_run(t)
	t.finish()


func _guide_data(t) -> void:
	t.ok(CardIds.FIRSTS.has(&"office"), "office in CardIds.FIRSTS")
	var steps = CardDB.read_json("res://data/cards/guide/steps.json")
	var hit := []
	for s in steps.get("cards", []):
		if str(s.get("trigger", {}).get("first", "")) == "office": hit.append(str(s["id"]))
	t.eq(hit, ["gd.office"], "gd.office is the step triggered by first office")
	var pages = CardDB.read_json("res://data/cards/guide/rule_pages.json")
	var unlock := []
	for p in pages.get("cards", []):
		if (p.get("unlock_first", []) as Array).has("office"): unlock.append(str(p["id"]))
	t.eq(unlock, ["rule.gold"], "rule.gold unlocks on first office")


func _boot(t, seed_value: int, tag: String) -> Array:
	var bus := CardEventBus.new()
	var e := CardEngine.new(bus)
	var spy = t.spy(bus)
	var r := e.new_game({"seed": seed_value, "stage": 2, "only_examples": false,
		"save_dir": t.user_dir() + "/k17_" + tag})
	t.ok(bool(r.get("ok", false)), tag + ": real 1940 new game " + str(r.get("err", "")))
	t.eq(str(e.view()["date"]["era"]), "1940", tag + ": stage era 1940")
	_ok(t, e, &"wheel.spin", {"wheel": "wh.month", "uid": ""}, tag)
	_ok(t, e, &"month.begin", {}, tag)
	return [e, spy, bus]


# 返回本关里 ID 在手上出现的次数
func _seen(e: CardEngine) -> int:
	var n := 0
	for c in e.view().get("hand", []):
		if str(c.get("def", "")) == ID: n += 1
	return n


func _uid(e: CardEngine) -> String:
	for c in e.view().get("hand", []):
		if str(c.get("def", "")) == ID: return str(c["uid"])
	return ""


func _ok(t, e: CardEngine, cmd: StringName, args: Dictionary, tag: String) -> Dictionary:
	var res := e.send(cmd, args)
	t.ok(bool(res.get("ok", false)), "%s: %s %s" % [tag, cmd, res.get("err", "")])
	return res


# 打烊 → 夜里 → 结算，回到下一天早上之前
func _close(t, e: CardEngine, tag: String) -> void:
	_ok(t, e, &"day.end", {"confirm": true}, tag)
	var offers: Array = e.view().get("night_offers", [])
	if offers.is_empty():
		t.ok(false, tag + ": night offers present")
		return
	var row: Dictionary = offers[0]
	for o in offers:
		if str(o.get("def", "")) == "nt.tidy": row = o
	var args := {"def": str(row["def"])}
	if not (row.get("choices", []) as Array).is_empty(): args["choice"] = str(row["choices"][0])
	_ok(t, e, &"night.choose", args, tag)
	_ok(t, e, &"settle.next", {}, tag)


func _to_day14(t, e: CardEngine, tag: String) -> void:
	for d in range(1, DAY):
		_ok(t, e, &"day.begin", {}, tag)
		t.eq(int(e.view()["date"]["stage_day"]), d, "%s: day %d" % [tag, d])
		t.eq(_seen(e), 0, "%s: not dealt before day %d (day %d)" % [tag, DAY, d])
		if str(e.view()["phase"]) == "game_over": return
		_close(t, e, tag)
	_ok(t, e, &"day.begin", {}, tag)
	t.eq(int(e.view()["date"]["stage_day"]), DAY, tag + ": reached day 14")


func _firsts_office(spy) -> int:
	var n := 0
	for row in spy.log:
		if row[0] == &"first_time" and str(row[1][0] if typeof(row[1]) == TYPE_ARRAY else row[1]) == "office": n += 1
	return n


func _choice_run(t, choice: String, short_money: bool) -> void:
	var tag: String = choice + ("_short" if short_money else "")
	var b := _boot(t, 11, tag)
	var e: CardEngine = b[0]
	var spy = b[1]
	_to_day14(t, e, tag)
	t.eq(_seen(e), 1, tag + ": dealt naturally exactly once on day 14")
	t.eq(_firsts_office(spy), 1, tag + ": first office emitted once on deal")
	t.ok(CardFirsts.all(e.ctx).has("office"), tag + ": firsts has office")
	var uid := _uid(e)
	if short_money:
		var m := CardCurrency.money(e.ctx)
		e.ctx.run([{"op": "money", "delta": -(m - 25), "reason": "test"}], "K17:test_drain")
		t.eq(CardCurrency.money(e.ctx), 25, tag + ": drained to 25")
	var before := CardCurrency.money(e.ctx)
	var marks0 := int(H.peek(e.ctx).get("counters", {}).get("sujian_marks", 0))
	_ok(t, e, &"card.choose", {"uid": uid, "choice": choice}, tag)
	var r := H.peek(e.ctx)
	var flags: Dictionary = r.get("flags", {})
	t.eq(str(flags.get("story." + NODE, "")), choice, tag + ": story flag")
	for k in WANT[choice]["flags"].keys():
		t.eq(flags.get(k), WANT[choice]["flags"][k], tag + ": flag " + k)
	t.eq(int(r.get("counters", {}).get("sujian_marks", 0)) - marks0, int(WANT[choice]["marks"]), tag + ": sujian_marks delta")
	var paid := before - CardCurrency.money(e.ctx)
	if choice == "buy_off":
		t.eq(paid, 25 if short_money else 60, tag + ": buy_off paid " + ("all it had" if short_money else "60"))
		t.eq(CardCurrency.money(e.ctx), 0 if short_money else before - 60, tag + ": money after buy_off")
	else:
		t.eq(paid, 0, tag + ": no money moved")
	t.eq(_seen(e), 0, tag + ": card leaves hand after choosing")
	t.ok(CardDossier.has_fragment(e.ctx, ASK), tag + ": ask fragment added")
	# 打烊进下一天早上，再存→读：first 不再发，指引不重教
	_close(t, e, tag)
	t.eq(str(e.view()["phase"]), "morning", tag + ": morning after close")
	var path: String = t.user_dir() + "/k17_" + tag + "/mid.json"
	_ok(t, e, &"game.save", {"path": path}, tag)
	var b2 := CardEventBus.new()
	var e2 := CardEngine.new(b2)
	var spy2 = t.spy(b2)
	var lr := e2.load_game(path)
	t.ok(bool(lr.get("ok", false)), tag + ": load " + str(lr.get("err", "")))
	t.ok(CardFirsts.all(e2.ctx).has("office"), tag + ": firsts.office survives load")
	t.eq(str(H.peek(e2.ctx).get("flags", {}).get("story." + NODE, "")), choice, tag + ": flag survives load")
	for d in range(DAY + 1, DAY + 4):
		_ok(t, e2, &"day.begin", {}, tag + "/loaded")
		t.eq(_seen(e2), 0, "%s: never re-dealt (day %d)" % [tag, d])
		_close(t, e2, tag + "/loaded")
	t.eq(_firsts_office(spy2), 0, tag + ": no first office after load (guide re-teach checked by K17_baozhang_guide)")
	b[2].free()
	b2.free()


func _ignored_run(t) -> void:
	var tag := "ignored"
	var b := _boot(t, 11, tag)
	var e: CardEngine = b[0]
	_to_day14(t, e, tag)
	t.eq(_seen(e), 1, tag + ": dealt on day 14")
	_close(t, e, tag)
	var flags: Dictionary = H.peek(e.ctx).get("flags", {})
	t.eq(str(flags.get("story." + NODE, "")), "ignored", tag + ": story flag ignored via real day.end")
	t.ok(bool(flags.get("office_baozhang_ignored", false)), tag + ": ignored flag")
	t.ok(not flags.has("office_post"), tag + ": no post")
	t.ok(_gap(e, ASK), tag + ": dossier gap " + ASK)
	_ok(t, e, &"day.begin", {}, tag)
	t.eq(int(e.view()["date"]["stage_day"]), DAY + 1, tag + ": next day reached")
	t.eq(_seen(e), 0, tag + ": not re-dealt next day")
	b[2].free()


func _gap(e: CardEngine, frag: String) -> bool:
	var person := str(e.ctx.db.def(frag).get("person", ""))
	return (H.peek(e.ctx).get("dossier", {}).get(person, {}).get("gaps", []) as Array).has(frag)
