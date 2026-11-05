# 阶梯验收断言分组；测试只使用 ASCII 假内容。
# G06；合同 §12 与任务卡 A-D、first-time、存读确定性。
extends RefCounted
const F := preload("res://scripts/tests/cards/G06/fixture.gd")


static func mortgage(t: RefCounted) -> void:
	var e: CardEngine = F.engine()
	t.eq(e.query(&"estates")["estates"].size(), 5, "five initial estates")
	var result: Dictionary = e.send(&"estate.mortgage", {"estate": "es.jewel_cabinet"})
	t.ok(result["ok"], "mortgage succeeds")
	t.eq(result["money"], 80, "mortgage price")
	t.eq(e.ctx.state.ns("econ")["test_money"], 1080, "money op credited")
	t.ok(not e.send(&"estate.mortgage", {"estate": "es.jewel_cabinet"})["ok"], "no repeated mortgage")
	t.ok(e.send(&"estate.redeem", {"estate": "es.jewel_cabinet"})["ok"], "redeem")
	t.eq(e.ctx.state.ns("econ")["test_money"], 996, "principal and monthly interest")
	e.ctx.state.ns("econ")["price_index"] = 150
	t.eq(e.send(&"estate.mortgage", {"estate": "es.counter"})["money"], 225, "inflation")
	CardDayLoop.begin_stage(e.ctx, 1)
	t.eq(CardMortgage._entry(e.ctx, "es.counter")["status"], "mortgaged", "retained across stages")
	t.no_leaks(e.query(&"estates"), "estate query")


static func short_ladder(t: RefCounted) -> void:
	var e: CardEngine = F.engine()
	e.ctx.state.ns("econ")["test_money"] = 0
	e.ctx.hooks.fire(e.ctx, &"money_short", {"amount": 100, "payee": "P", "source": "SRC"})
	var panel: Dictionary = e.query(&"short")
	t.eq(panel.keys().size(), 6, "six panel keys")
	t.eq(panel["options"], ["estate", "default"], "available routes in order")
	t.no_leaks(panel)
	t.ok(e.send(&"short.resolve", {"source": "SRC", "by": "estate", "estate": "es.jewel_cabinet"})["pending"], "partial mortgage continues")
	t.ok(e.send(&"short.resolve", {"source": "SRC", "by": "estate", "estate": "es.counter"})["ok"], "enough money pays")
	t.ok(e.query(&"short").is_empty(), "cleared pending payment")
	t.eq(e.ctx.state.ns("econ")["test_money"], 130, "original total paid once")
	e.ctx.state.ns("econ")["test_money"] = 0
	CardShortLadder.on_short(e.ctx, {"amount": 90, "payee": "P", "source": "DEFAULT"})
	t.ok(e.send(&"short.resolve", {"source": "DEFAULT", "by": "default"})["ok"], "default succeeds")
	t.eq(str(e.ctx.state.ns("econ")["default_source"]).split("/")[0], "DEFAULT", "original fail source")
	t.eq(e.ctx.state.ns("loop")["mode"], "shop", "default does not enter street")
	CardShortLadder.on_short(e.ctx, {"amount": 50, "payee": "P", "source": "DAY_END"})
	t.eq(CardLadderInstall._end_rows(e.ctx, {})[-1], {"uid": "", "def": "", "kind": "short",
		"consequence_key": "g06.end.short", "args": {}}, "short preview matches default consequence")
	e.ctx.hooks.fire(e.ctx, &"day_end")
	t.ok(e.query(&"short").is_empty(), "closing day discards pending payment by default")
	t.eq(str(e.ctx.state.ns("econ")["default_source"]).split("/")[0], "DAY_END", "day-end fail source")


static func street(t: RefCounted) -> void:
	var e: CardEngine = F.engine()
	e.send(&"estate.mortgage", {"estate": "es.shopfront"})
	CardMortgage.on_month_close(e.ctx)
	t.eq(e.ctx.state.ns("loop")["mode"], "street", "month-end shop loss")
	t.eq(CardMortgage._entry(e.ctx, "es.shopfront")["status"], "lost", "shop estate lost")
	var street_since: int = int(e.ctx.state.ns("ladder")["street"]["since_abs_day"])
	e.ctx.state.ns("loop")["abs_day"] = 40
	CardMortgage._stage_start(e.ctx, {"stage": 1})
	t.eq(e.ctx.state.ns("ladder")["street"]["since_abs_day"], street_since, "street duration survives stages")
	var money: int = int(e.ctx.state.ns("econ")["test_money"])
	CardMortgage.on_month_close(e.ctx)
	t.eq(e.ctx.state.ns("econ")["test_money"], money, "month-end idempotent")
	e.ctx.state.ns("econ")["test_money"] = 399
	var before: String = e.ctx.state.hash()
	t.eq(e.send(&"street.redeem_shop")["err"], "insufficient_money", "cannot afford shop")
	t.eq(e.ctx.state.hash(), before, "failed redeem does not mutate")
	e.ctx.state.ns("econ")["test_money"] = 400
	t.ok(e.send(&"street.redeem_shop")["ok"], "redeem shop")
	t.eq(e.ctx.state.ns("loop")["mode"], "shop", "back in shop")
	t.eq(e.ctx.state.ns("econ")["test_money"], 0, "shop paid")
	t.eq(e.ctx.state.ns("ladder")["street"]["since_abs_day"], 0, "redeem clears active street timer")


static func prison(t: RefCounted) -> void:
	var e: CardEngine = F.engine()
	var gold_uid: String = ""
	for id in e.ctx.db.ids_of(&"person"):
		if bool(e.ctx.db.def(id).get("gold", false)):
			gold_uid = CardPiles.spawn(e.ctx, id, &"hand")
			break
	var ordinary: PackedStringArray = e.ctx.db.ids_of(&"fate")
	if not ordinary.is_empty():
		CardPiles.spawn(e.ctx, ordinary[0], &"hand")
	var hand_before: int = CardPiles.list(e.ctx, &"hand").size()
	CardPrison.arrest(e.ctx, "R")
	var uid: String = str(e.ctx.state.ns("ladder")["prison"]["uid"])
	t.eq(CardPiles.def_of(e.ctx, uid)["id"], "pr.cell", "prison card spawned")
	t.eq(e.ctx.state.ns("loop")["open_panel"], {"kind": "prison", "args": {"uid": uid}}, "prison panel")
	CardPrison.arrest(e.ctx, "R")
	t.eq(CardPiles.list(e.ctx, &"hand").size(), hand_before + 1, "no duplicate prison card")
	var hand: PackedStringArray = CardPiles.list(e.ctx, &"hand")
	t.eq(hand.find(uid), 1 if gold_uid != "" else 0, "prison follows golden and precedes ordinary cards")
	for kind in ["person", "night", "street"]:
		t.eq(e.ctx.mods.sum_int(e.ctx, &"deal_count", {"type": kind, "abs_day": 2}), -100000, "no " + kind + " while jailed")
	t.eq(CardPrison._card_view_part(e.ctx, {"uid": uid}), {"days_left": 3}, "visible remaining nights")
	for day in range(1, 4):
		e.ctx.state.ns("loop")["abs_day"] = day
		var row: Dictionary = CardPrison.end_row(e.ctx)
		t.eq(row["kind"], "fail" if day == 3 else "stay", "preview distinguishes final night")
		t.eq(row["args"], {"nights": day, "max": 3}, "preview gives visible upcoming night")
		e.ctx.hooks.fire(e.ctx, &"day_end")
		t.eq(e.ctx.state.ns("ladder")["prison"], {"uid": uid, "nights": day}, "prison retains only uid and nights")
		t.eq(e.ctx.state.ns("econ")["shop_closed_until"], day + 1, "shop closes through tomorrow")
	t.eq(e.ctx.state.ns("loop")["phase"], "game_over", "three skipped days execute data failure")
	t.eq(CardPiles.zone_of(e.ctx, uid), &"hand", "failure leaves prison card for final state")
	var released: CardEngine = F.engine()
	CardPrison.arrest(released.ctx, "R")
	var released_uid: String = str(released.ctx.state.ns("ladder")["prison"]["uid"])
	CardPiles.resolve(released.ctx, released_uid, &"success")
	t.ok(released.ctx.state.ns("ladder")["prison"].is_empty(), "successful resolve clears imprisonment")
	t.eq(CardPrison._card_view_part(released.ctx, {"uid": released_uid}), {}, "released card has no prison timer")
	var configured: CardEngine = F.engine()
	configured.ctx.db._rules["ladder"]["prison"]["max_days"] = 2
	CardPrison.arrest(configured.ctx, "R")
	CardPrison._day_end(configured.ctx, {})
	t.eq(configured.ctx.state.ns("loop")["phase"], "day", "configured limit has not elapsed")
	configured.ctx.state.ns("loop")["abs_day"] = 2
	CardPrison._day_end(configured.ctx, {})
	t.eq(configured.ctx.state.ns("loop")["phase"], "game_over", "configured second night fails")


static func ops_conds_mods(t: RefCounted) -> void:
	var e: CardEngine = F.engine()
	for id in ["es.jewel_cabinet", "es.storeroom", "es.counter", "es.old_house"]:
		e.send(&"estate.mortgage", {"estate": id})
	t.ok(e.ctx.mods.any_true(e.ctx, &"intake_blocked", {"cat": "jewelry"}), "jewelry blocked")
	t.eq(e.ctx.mods.sum_int(e.ctx, &"cap", {"zone": "shelf"}), -4, "shelf capacity")
	t.eq(e.ctx.mods.sum_int(e.ctx, &"deal_count", {"type": "person"}), -1, "person count")
	t.eq(e.ctx.mods.pct(e.ctx, &"pool_pct", {"pool": "life", "def": ""}), 150, "life weight")
	t.eq(e.ctx.mods.pct(e.ctx, &"pool_pct", {"pool": "fate", "def": ""}), 100, "other pool unchanged")
	t.ok(e.ctx.test({"estate_status": ["es.counter", "mortgaged"]}), "estate condition")
	e.ctx.run([{"op": "estate_seize", "pick": "worst"}], "T")
	t.eq(CardMortgage._entry(e.ctx, "es.jewel_cabinet")["status"], "lost", "seize worst")
	t.ok(not e.ctx.mods.any_true(e.ctx, &"intake_blocked", {"cat": "jewelry"}), "lost estate not mortgaged")


static func firsts(t: RefCounted) -> void:
	var e: CardEngine = F.engine()
	for repeat in range(2):
		CardShortLadder.on_short(e.ctx, {"amount": 2000, "payee": "P", "source": "S"})
		CardStreet.enter(e.ctx)
		CardPrison.arrest(e.ctx, "R")
	for mech in ["money_short", "mortgage", "street", "prison"]:
		t.eq(F.count_first(e.ctx, mech), 1, "first emitted once " + mech)
	for event in e.ctx.out:
		if str(event[0]) == "first_time":
			for key in event[2].keys():
				t.ok(str(key) in ["uid", "def", "kind", "person", "no"], "first whitelist")
	e.ctx.state = CardState.from_dict(e.ctx.state.to_dict())
	e.ctx.out = []
	CardShortLadder.on_short(e.ctx, {"amount": 2000, "payee": "P", "source": "S"})
	CardStreet.enter(e.ctx)
	CardPrison.arrest(e.ctx, "R")
	for mech in ["money_short", "mortgage", "street", "prison"]:
		t.eq(F.count_first(e.ctx, mech), 0, "first remains known after load " + mech)


static func determinism_save(t: RefCounted) -> void:
	var a: CardEngine = F.engine()
	var b: CardEngine = F.engine()
	for e in [a, b]:
		e.send(&"estate.mortgage", {"estate": "es.counter"})
		CardShortLadder.on_short(e.ctx, {"amount": 1200, "payee": "P", "source": "S"})
	var panel: Dictionary = b.query(&"short")
	b.ctx.state = CardState.from_dict(b.ctx.state.to_dict())
	t.eq(b.query(&"short"), panel, "pending panel restored")
	for e in [a, b]:
		e.send(&"short.resolve", {"source": "S", "by": "estate", "estate": "es.shopfront"})
	t.eq(a.ctx.state.hash(), b.ctx.state.hash(), "save continuation deterministic")
	t.eq(t.find_floats(a.ctx.state.data), PackedStringArray(), "integer-only state")
