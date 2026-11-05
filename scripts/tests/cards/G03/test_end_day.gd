# 合同 1.2：打烊退回未掷资源、人物当天算用过，人脉溢出选择不留新人。
# 清单纯读取，条子行写的是今晚结算后的剩余天数。
extends SceneTree
const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const S = preload("res://scripts/tests/cards/G03/test_support.gd")
const H = preload("res://scripts/cards/rules/rules_helpers.gd")

func _initialize() -> void:
	var t := T.new(self, "G03_end_day")
	var e := S.engine()
	var ctx := e.ctx
	ctx.state.ns("loop")["phase"] = "day"
	ctx.db._rules["deal"]["caps"]["contacts"] = 1
	CardEffectsCore.gain_contact(ctx, "ma")
	var contact := H.contact_uid(ctx, "ma")
	S.card(ctx, "ct.test", {"type": "contact", "person": "test", "attrs": {"eye": 1}}, &"discard")
	CardEffectsCore.gain_contact(ctx, "test")
	var pending := str(ctx.state.ns("rules")["contact_pending"])
	var event := S.card(ctx, "ev.end_day", {"type": "event", "slots": [
		{"id": "self", "accepts": ["self"], "attr": "eye"},
		{"id": "contact", "accepts": ["contact"], "attr": "pull"},
		{"id": "cash", "accepts": ["money"]},
		{"id": "favor", "accepts": ["kept"], "tags": ["official"]}], "check": {"need": 1}})
	var kept := CardPiles.spawn(ctx, "kp.ma_owes", &"kept")
	t.ok(CardSlots.place(ctx, event, "self", {"kind": "self"})["ok"], "reserve self")
	t.ok(CardSlots.place(ctx, event, "contact", {"kind": "contact", "uid": contact})["ok"], "reserve contact")
	t.ok(CardSlots.place(ctx, event, "cash", {"kind": "money", "amount": 20})["ok"], "reserve cash")
	t.ok(CardSlots.place(ctx, event, "favor", {"kind": "kept", "uid": kept})["ok"], "reserve consumed-on-use kept")
	var demand := CardPiles.spawn(ctx, "dm.1938.money.t1", &"demands")
	CardChoices.choose(ctx, demand, "pay")
	CardSlots.place(ctx, demand, "cash", {"kind": "money", "amount": 60})
	ctx.db._cards["dm.1938.info.t3"]["deadline_days"] = 1
	var due := CardPiles.spawn(ctx, "dm.1938.info.t3", &"demands")
	var hash_before := ctx.state.hash()
	var rows := ctx.mods.collect(ctx, &"end_rows", {})
	t.eq(ctx.state.hash(), hash_before, "end rows are read only")
	t.no_leaks(rows, "end rows")
	t.eq(rows.map(func(row: Dictionary) -> String: return row["kind"]), ["wait", "wait", "release"], "demands precede pending panel")
	t.eq(rows[0]["uid"], due, "soonest demand first")
	t.eq(rows[0]["args"], {"days": 0}, "due tonight row")
	t.eq(rows[1]["args"], {"days": 6}, "seven-day demand after tonight")
	t.eq(rows[2]["uid"], pending, "release row points to new contact")
	var cash_before := int(ctx.state.ns("rules")["test_money"])
	ctx.out = []
	ctx.hooks.fire(ctx, &"day_end", {})
	t.eq(CardPiles.zone_of(ctx, pending), &"discard", "undecided new contact declined")
	t.eq(CardPiles.zone_of(ctx, contact), &"contacts", "old contact stays")
	t.eq(CardPiles.zone_of(ctx, kept), &"kept", "unrolled kept not consumed")
	t.eq(ctx.state.ns("rules")["test_money"], cash_before, "unrolled cash not paid")
	t.eq(CardSlots.reserved_money(ctx), 0, "all slot money released")
	t.eq(H.card_peek(ctx, event)["placed"], {}, "event placement cleared")
	t.eq(H.card_peek(ctx, demand)["placed"], {}, "demand placement cleared")
	t.eq(H.person_peek(ctx, "ruhua")["used_abs_day"], ctx.abs_day(), "unrolled self used today")
	t.eq(H.person_peek(ctx, "ma")["used_abs_day"], ctx.abs_day(), "unrolled contact used today")
	t.ok(not ctx.out.any(func(row: Array) -> bool: return row[0] == &"coins_tossed"), "closing never tosses coins")
	t.eq(CardPiles.zone_of(ctx, demand), &"demands", "closing does not expire demand")
	t.eq(CardDemands.days_left(ctx, demand), 7, "closing does not decrement demand")
	t.eq(ctx.mods.collect(ctx, &"end_rows", {}).size(), 2, "release consequence matches row")
	hash_before = ctx.state.hash()
	ctx.hooks.fire(ctx, &"day_end", {})
	t.eq(ctx.state.hash(), hash_before, "repeat closing cleanup is idempotent")
	CardDemands.on_settle(ctx)
	t.eq(CardDemands.days_left(ctx, demand), rows[1]["args"]["days"], "preview days equal settled deadline")
	t.eq(CardPiles.zone_of(ctx, due), &"discard", "zero-day preview expires tonight")
	t.eq(t.find_floats(ctx.state.data), PackedStringArray(), "closing state has no floats")
	t.finish()
