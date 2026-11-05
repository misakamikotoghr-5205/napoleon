extends SceneTree
const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const S = preload("res://scripts/tests/cards/G03/test_support.gd")
func _initialize() -> void:
	var t := T.new(self, "G03_demands")
	for seed in range(20):
		var e := S.engine(seed)
		var ctx := e.ctx
		ctx.state.ns("loop").merge({"stage_day": 7, "abs_day": 7}, true)
		var uid := CardDemands.issue(ctx)
		t.ok(uid != "", "Monday issue " + str(seed))
		t.eq(CardDemands.issue(ctx), uid, "one demand per week")
		t.eq(CardDemands.days_left(ctx, uid), 7, "seven-day deadline")
		var old := CardDemands.tier_of(ctx, uid)
		t.eq(CardDemands.delay(ctx, uid)["days_left"], 10, "delay adds three")
		t.eq(CardDemands.tier_of(ctx, uid), mini(old + 1, 3), "delay tier bump")
		t.eq(CardDemands.delay(ctx, uid)["err"], "not_allowed", "delay once")
		var clone := S.clone(e)
		t.eq(ctx.state.hash(), clone.ctx.state.hash(), "issue clone hash")
	_test_modes(t)
	_test_expiry(t)
	_test_returns(t)
	t.finish()

func _test_modes(t) -> void:
	var e := S.engine()
	var ctx := e.ctx
	var money := CardPiles.spawn(ctx, "dm.1938.money.t1", &"demands")
	t.ok(e.send(&"card.choose", {"uid": money, "choice": "pay"})["ok"], "pay choose")
	CardSlots.place(ctx, money, "cash", {"kind": "money", "amount": 60})
	t.eq(CardSlots.preview(ctx, money)["coins"], 0, "pay slot money no coins")
	t.ok(e.send(&"demand.submit", {"uid": money})["success"], "pay submit")
	t.eq(ctx.state.ns("rules")["test_money"], 440, "pay pays at submission")
	var goods := CardPiles.spawn(ctx, "dm.1938.goods.t0", &"demands")
	e.send(&"card.choose", {"uid": goods, "choice": "substitute"})
	t.ok(e.send(&"demand.submit", {"uid": goods})["success"], "substitute submits")
	t.eq(ctx.state.ns("rules")["test_money"], 390, "substitute amount")
	var haggle := CardPiles.spawn(ctx, "dm.1938.money.t1", &"demands")
	e.send(&"card.choose", {"uid": haggle, "choice": "haggle"})
	var favor := CardPiles.spawn(ctx, "kp.ma_owes", &"kept")
	# Fixture tags make the advertised favor supply its three heads.
	ctx.db._cards["dm.1938.money.t1"]["resolve"]["haggle"]["slots"][0]["tags"] = ["official"]
	CardSlots.place(ctx, haggle, "favor", {"kind": "kept", "uid": favor})
	t.ok(e.send(&"demand.submit", {"uid": haggle})["success"], "haggle submits")
	t.eq(CardDemands.tier_of(ctx, haggle), 0, "haggle lowers tier")
	var info := CardPiles.spawn(ctx, "dm.1938.info.t3", &"demands")
	e.send(&"card.choose", {"uid": info, "choice": "fabricate"})
	ctx.db._cards["dm.1938.info.t3"]["resolve"]["fabricate"]["need"] = 0
	CardSlots.place(ctx, info, "fabricator", {"kind": "self"})
	t.ok(e.send(&"demand.submit", {"uid": info})["success"], "fabricate submits")
	var info2 := CardPiles.spawn(ctx, "dm.1938.info.t3", &"demands")
	var news := S.card(ctx, "nw.inform", {"type": "news", "keepable": true, "effects": {"on_inform": [{"op": "flag", "key": "informed"}, {"op": "conscience", "delta": -2}]}}, &"kept")
	e.send(&"card.choose", {"uid": info2, "choice": "inform"})
	CardSlots.place(ctx, info2, "news", {"kind": "news", "uid": news})
	t.ok(e.send(&"demand.submit", {"uid": info2})["success"], "inform submits")
	t.ok(ctx.test({"flag": "informed"}), "news on_inform")
	t.eq(CardPiles.zone_of(ctx, news), &"discard", "news consumed")
	var people := CardPiles.spawn(ctx, "dm.1938.people.t2", &"demands")
	ctx.state.ns("loop")["abs_day"] = 2
	e.send(&"card.choose", {"uid": people, "choice": "send_person"})
	CardSlots.place(ctx, people, "man", {"kind": "self"})
	t.ok(e.send(&"demand.submit", {"uid": people})["success"], "send person submits")
	t.ok(ctx.test({"person_state": ["ruhua", "away"]}), "person away")
	t.no_leaks(e.query(&"card", {"uid": people}))
	# Failed fabrication remains open and executes its visible failure effect.
	ctx.state.ns("loop")["abs_day"] = 3
	CardEffectsCore.set_person(ctx, "ruhua", "ok", 0)
	ctx.state.ns("rules")["attrs"]["ruhua"]["nerve"] = 0
	ctx.db._cards["dm.1938.info.t3"]["resolve"]["fabricate"]["need"] = 2
	var fail := CardPiles.spawn(ctx, "dm.1938.info.t3", &"demands")
	CardChoices.choose(ctx, fail, "fabricate")
	CardSlots.place(ctx, fail, "fabricator", {"kind": "self"})
	t.ok(not CardDemands.submit(ctx, fail)["success"], "fabricate failure")
	t.eq(CardMeters.tier(ctx, &"heat"), 1, "fabricate on_fail")
	t.eq(CardPiles.zone_of(ctx, fail), &"demands", "failed method leaves demand open")

func _test_expiry(t) -> void:
	for tier in range(4):
		var e := S.engine()
		var ctx := e.ctx
		var uid := S.card(ctx, "dm.expire", {"type": "demand", "kind": "money", "tier": tier, "resolve": {"money": {"amount": 60}}, "slots": [{"id": "cash", "accepts": ["money"], "pay": true}]}, &"demands")
		for day in range(1, 7):
			ctx.state.ns("loop")["abs_day"] = day
			CardDemands.on_settle(ctx)
			t.eq(CardPiles.zone_of(ctx, uid), &"demands", "not expired before seven days")
			t.eq(CardDemands.days_left(ctx, uid), 7 - day, "settle decrements deadline")
		ctx.state.ns("loop")["abs_day"] = 7
		CardDemands.on_settle(ctx)
		t.eq(CardPiles.zone_of(ctx, uid), &"discard", "expired day seven")
		if tier == 0: t.eq(ctx.state.ns("rules")["test_money"], 470, "tier zero fine")
		else: t.eq(ctx.state.ns("rules")["test_effects"][0]["op"], ["", "shop_closed", "estate_seize", "arrest"][tier], "failure tier")
		t.ok(CardFirsts.all(ctx).has("demand_fail"), "failure first")

func _test_returns(t) -> void:
	for need in [0, 12]:
		var e := S.engine()
		var ctx := e.ctx
		var uid := CardPiles.spawn(ctx, "dm.1938.people.t2", &"demands")
		ctx.db._cards["dm.1938.people.t2"]["resolve"]["people"]["return_check"]["need"] = need
		CardChoices.choose(ctx, uid, "send_person")
		CardSlots.place(ctx, uid, "man", {"kind": "self"})
		CardDemands.submit(ctx, uid)
		ctx.state.ns("loop")["abs_day"] = 8
		CardDemands.return_people(ctx)
		t.ok(ctx.test({"person_state": ["ruhua", "ok" if need == 0 else "gone"]}), "return check success/failure")
		t.ok(CardFirsts.all(ctx).has("demand_people_return"), "return first")
		var before := ctx.state.hash()
		CardDemands.return_people(ctx)
		t.eq(ctx.state.hash(), before, "return once")
		t.no_leaks(ctx.out)
