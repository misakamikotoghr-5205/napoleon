# 真六模块的合同1.2验收；私有补全年份夹具只用于覆盖全部循环边界。
extends SceneTree
const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const H = preload("res://scripts/tests/cards/G02/helpers.gd")
const Scenario = preload("res://scripts/tests/cards/G02/real_scenario.gd")
var _data_root: String

func _initialize() -> void:
	var t := T.new(self, "G02_next_day_real")
	_data_root = Scenario.build(t.user_dir() + "/data")
	var economy: Dictionary = CardState.int_restore(CardDB.read_json(_data_root + "/rules/economy.json"))
	economy["start_money"] = 100000
	H._write(_data_root + "/rules/economy.json", JSON.stringify(economy))
	var meters: Dictionary = CardState.int_restore(CardDB.read_json(_data_root + "/rules/meters.json"))
	meters["heat"]["arrest_at"] = 1000000
	H._write(_data_root + "/rules/meters.json", JSON.stringify(meters))
	_rows_and_prison(t)
	_month_short(t)
	_three_stages(t)
	t.finish()

func _engine(t: RefCounted, name: String) -> CardEngine:
	var e := CardEngine.new()
	t.ok(bool(e.new_game({"seed": 7, "data_root": _data_root, "only_examples": true,
		"save_dir": t.user_dir() + "/" + name}).get("ok")), "real engine starts")
	return e

func _advance(t: RefCounted, e: CardEngine) -> Dictionary:
	var phase: String = e.view()["phase"]
	var day := e.ctx.abs_day()
	var preview := e.query(&"day.end_preview")
	var hash_before := e.state_hash()
	t.eq(e.query(&"day.end_preview"), preview, "real stable preview")
	t.eq(e.state_hash(), hash_before, "real preview read only")
	t.no_leaks(preview)
	var result := e.send(&"day.end", {"confirm": true})
	t.ok(bool(result.get("ok", false)), "real advance " + phase + ": " + str(result.get("err")))
	t.eq(result.get("items"), preview["items"], "real preview equals performed items")
	t.ok(e.ctx.abs_day() > day or phase != e.view()["phase"], "real state advances")
	return result

func _rows_and_prison(t: RefCounted) -> void:
	var e := _engine(t, "rows")
	t.ok(bool(e.send(&"wheel.offer", {"wheel": "wh.month", "uid": "", "source": {"kind": "money", "amount": 1}}).get("ok")), "auto-spin uses existing incense")
	var first := e.query(&"day.end_preview")
	t.eq(first["items"][0]["kind"], "auto_spin", "month_open previews automatic wheel")
	var before := e.view()
	t.eq(e.send(&"day.end", {"confirm": false}).get("err"), "must_resolve_pending", "automatic month spin requests confirmation")
	t.eq(e.view(), before, "unconfirmed auto-spin doesn't consume incense")
	_advance(t, e)
	t.ok(str(e.ctx.state.ns("fate").get("month_segment", "")) != "", "automatic month spin completes")
	_advance(t, e)
	var wait := CardPiles.spawn(e.ctx, "lf.any.coal_out", &"hand")
	var kept := CardPiles.spawn(e.ctx, "nw.1938.wangshan_dock", &"hand")
	var gold := CardPiles.spawn(e.ctx, "p.brother.1938.farewell", &"hand")
	var wheel := CardPiles.spawn(e.ctx, "bf.wheel", &"hand")
	var demand := CardPiles.spawn(e.ctx, "dm.1938.money.t1", &"demands")
	for _n in range(CardPiles.cap(e.ctx, &"kept")):
		CardPiles.spawn(e.ctx, "kp.brother_note", &"kept")
	var overflow := CardPiles.spawn(e.ctx, "kp.brother_note", &"hand")
	t.eq(e.send(&"card.keep", {"uid": overflow}).get("err"), "kept_full", "real overflow created")
	var rows: Array = e.query(&"day.end_preview")["items"]
	t.eq(rows[-1]["kind"], "discard", "real overflow panel ordered after demands")
	t.eq(rows[-2]["uid"], demand, "demand board follows hand")
	t.eq(rows.filter(func(row: Dictionary) -> bool: return row["uid"] == wheel)[0]["kind"], "void", "crisis wheel belongs G05")
	var before_view := e.view()
	e.send(&"day.end", {"confirm": false})
	t.eq(e.view(), before_view, "real confirm false same view with all pending")
	_advance(t, e)
	for uid in [wait, kept]: t.eq(CardPiles.zone_of(e.ctx, uid), &"hand", "real wait stays in hand")
	for uid in [gold, wheel, overflow]: t.eq(CardPiles.zone_of(e.ctx, uid), &"discard", "real departures discarded")
	t.eq(CardPiles.zone_of(e.ctx, demand), &"demands", "undue demand remains on board")
	_advance(t, e)
	var lines: Array = e.query(&"settle_report")["lines"]
	for row in rows:
		if row["kind"] not in ["wait", "pass"]:
			t.ok(lines.has({"key": row["consequence_key"], "args": row["args"]}), "real ignored row in report")
	_advance(t, e)
	_advance(t, e)
	CardPrison.arrest(e.ctx, "probe")
	var prison_uid := str(e.ctx.state.ns("ladder")["prison"]["uid"])
	for night in range(1, 4):
		var expected := "fail" if night == 3 else "stay"
		var preview: Array = e.query(&"day.end_preview")["items"]
		var prison: Dictionary = preview.filter(func(row: Dictionary) -> bool: return row["uid"] == prison_uid)[0]
		t.eq(prison["kind"], expected, "prison next-night kind")
		t.eq(prison["args"], {"nights": night, "max": 3}, "prison visible nights")
		_advance(t, e)
		if night < 3:
			t.eq(e.view()["night_offers"], [], "in prison night has only skip")
			_advance(t, e)
			_advance(t, e)
			_advance(t, e)
			t.eq(CardPiles.zone_of(e.ctx, prison_uid), &"hand", "prison retained next morning")
	t.eq(e.view()["phase"], "game_over", "third unresolved prison night ends game")
	t.eq(e.view()["game_over_reason"], "prison", "prison failure reason visible")

func _month_short(t: RefCounted) -> void:
	var e := _engine(t, "month")
	_advance(t, e)
	var estates: Array = e.query(&"estates").get("estates", [])
	t.eq(estates.size(), 5, "all five mortgage sources present")
	for estate in estates:
		t.ok(bool(CardMortgage.mortgage(e.ctx, str(estate["id"])).get("ok")), "multiple mortgages before close")
	ctx_money_zero(e.ctx)
	# Controlled boundary snapshot: normal hooks still perform expenses, debt and stage progression.
	e.ctx.state.ns("loop")["stage_day"] = 30
	CardDayLoop.set_phase(e.ctx, &"settle")
	_advance(t, e)
	t.eq(e.view()["phase"], "month_close", "month boundary opens report")
	t.eq(e.view()["open_panel"]["kind"], "short", "monthly interest shortage is reachable")
	t.eq(e.query(&"day.end_preview")["items"][0]["kind"], "short", "month close previews unpaid amount consequence")
	var before := e.view()
	t.eq(e.send(&"day.end", {"confirm": false}).get("err"), "must_resolve_pending", "monthly short requires confirmation")
	t.eq(e.view(), before, "monthly short unconfirmed view stable")
	_advance(t, e)
	t.eq(e.view()["phase"], "year_jump", "all successive monthly shortages finish in same next-day command")
	t.eq(CardShortLadder.view(e.ctx), {}, "no stale monthly short")
	t.eq(e.query(&"month_report")["lines"].filter(func(row: Dictionary) -> bool:
		return row["key"] == "g06.end.short").size(), estates.size(), "every mortgage interest default reported")
	t.eq(e.ctx.state.ns("econ").get("pending_payment", {}), {}, "no stale economic pending payment")

func ctx_money_zero(ctx: CardCtx) -> void:
	ctx.run([{"op": "money", "delta": -CardCurrency.money(ctx), "reason": "g02.test.boundary"}], "test")

func _three_stages(t: RefCounted) -> void:
	var e := _engine(t, "three")
	var previous_day := e.ctx.abs_day()
	var consecutive := 0
	var commands := 0
	while e.view()["phase"] != "game_over" and commands < 400:
		_advance(t, e)
		commands += 1
		consecutive += 1
		if e.ctx.abs_day() > previous_day:
			t.ok(consecutive <= CardIds.END_MAX_STEPS_TO_NEXT_DAY, "real bounded next day across all three stages")
			previous_day = e.ctx.abs_day()
			consecutive = 0
	t.eq(e.ctx.abs_day(), 90, "real generic end reaches all ninety days")
	t.eq(e.view()["game_over_reason"], "ending", "real generic end reaches release ending")
	t.ok(not CardFirsts.all(e.ctx).has("branch_pick"), "real branch reserved")
