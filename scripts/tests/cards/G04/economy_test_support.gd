# G04 独立夹具与验收工具：用 W0 上下文直接驱动生命周期。
# 测试牌只有 ASCII 占位；不依赖其他线完成状态。
extends RefCounted
const E = preload("res://scripts/cards/economy/economy_support.gd")
const TestEngine = preload("res://scripts/tests/cards/G04/economy_engine.gd")
const Ledger = preload("res://scripts/cards/economy/card_ledger.gd")

static func ctx(seed: int = 7) -> CardCtx:
	var eng := TestEngine.new()
	var c := eng.ctx
	c.state = CardState.create(seed, {})
	c.state.ns("loop").merge({"phase": "day", "abs_day": 1, "stage": 0, "mode": "shop"})
	c.db = CardDB.load_all(CardDB.DEFAULT_ROOT, {"only_examples": true})
	var fixture: Dictionary = CardDB.read_json("res://scripts/tests/cards/G04/fixture.json")
	for row in CardState.int_restore(fixture)["cards"]:
		c.db._cards[row["id"]] = row
		c.db._file_of[row["id"]] = "test"
		if not c.db._by_type.has(row["type"]):
			c.db._by_type[row["type"]] = []
		if not c.db._by_type[row["type"]].has(row["id"]):
			c.db._by_type[row["type"]].append(row["id"])
	c.db._obs["spot"] = {"obs.spot.material.wear": {"fidelity": "clear"}, "obs.spot.material.plain": {"fidelity": "partial"}, "obs.spot.material.unclear": {"fidelity": "vague"}}
	CardCurrency.apply_stage(c, c.db.stage(0))
	c.out.clear()
	return c

static func spawn(c: CardCtx, def_id: String = "p.test.pawn") -> String:
	return CardPiles.spawn(c, def_id, &"hand")

static func customer(c: CardCtx, def_id: String = "p.test.pawn") -> String:
	var uid := spawn(c, def_id)
	CardCounter.open(c, uid)
	return uid

static func pawn(c: CardCtx) -> String:
	var uid := customer(c)
	CardCounter.offer(c, uid, &"fair")
	return "t%04d" % (int(c.ledger.next_ticket) - 1)

static func redeem_customer(c: CardCtx, tid: String) -> String:
	var uid := CardPiles.spawn(c, "p.any.redeem", &"hand", {"vars": {"ticket_no": int(c.ledger.contracts[tid]["no"])}})
	CardCounter.open(c, uid)
	return uid

static func assert_clean(t, c: CardCtx) -> void:
	E.sync(c)
	t.eq(c.ledger.check_invariants(), [], "ledger conservation and unique pledges")
	t.eq(t.find_floats(c.state.ns("econ")), PackedStringArray(), "econ contains no floats")
	t.ok(ascii_tree(c.state.ns("econ")), "econ contains ASCII strings only")
	t.no_leaks(CardShelf.view(c), "stock")
	t.no_leaks(CardTickets.view(c), "tickets")
	for ev in c.out:
		if ev[0] == &"minigame_requested":
			t.ok(not forbidden(ev[4]), "minigame event contains physical parameters only")
		else:
			t.no_leaks(ev, "events")

static func ascii_tree(v) -> bool:
	if typeof(v) in [TYPE_STRING, TYPE_STRING_NAME]:
		return str(v) == str(v).to_ascii_buffer().get_string_from_ascii()
	if typeof(v) == TYPE_DICTIONARY:
		for k in v:
			if not ascii_tree(k) or not ascii_tree(v[k]):
				return false
	if typeof(v) == TYPE_ARRAY:
		for x in v:
			if not ascii_tree(x):
				return false
	return true

static func forbidden(v) -> bool:
	if typeof(v) == TYPE_DICTIONARY:
		for key in v:
			if CardAppraisal.FORBIDDEN_PARAM_KEYS.has(str(key)) or forbidden(v[key]):
				return true
	elif typeof(v) == TYPE_ARRAY:
		for child in v:
			if forbidden(child):
				return true
	return false

static func result(clarity: int = 800, observations: Array = [], minutes: int = 1) -> Dictionary:
	return {"quality_permille": clarity, "observations": observations, "minutes": minutes, "measures": {}, "aborted": false}

static func ledger(t) -> void:
	var c := ctx()
	var tid := pawn(c)
	t.eq(tid, "t0001", "ASCII contract id")
	t.eq(typeof(c.ledger.contracts[tid]["no"]), TYPE_INT, "integer ticket number")
	var principal: int = c.ledger.contracts[tid]["principal"]
	t.eq(c.ledger.redeem_amount(tid, 61), principal + principal * 3 * 2 / 100 + principal * 5 * 2 / 1000, "integer monthly interest and storage")
	var before := CardCurrency.money(c)
	CardCurrency.convert(c, "fabi", 2, 3)
	t.eq(CardCurrency.money(c), before * 2 / 3, "cash conversion")
	assert_clean(t, c)

static func items_test(t) -> void:
	for seed in range(50):
		var c := ctx(seed)
		for template in ["jewelry.hairpin", "utensils.bowl", "silver.yuan_a"]:
			var r := CardItems.generate(c, ["c", 1, "item", template], template)
			t.ok(bool(r.get("ok", false)), "requested template generated")
			t.eq(E.meta(c, str(r.get("item", ""))).get("template"), template, "template selection does not reroll")
			t.eq(CardItems.generate(c, ["c", 1, "item", template], template), r, "semantic generation stable")
		assert_clean(t, c)
	var c := ctx()
	t.eq(CardItems.generate(c, [1], "jewelry").get("err"), "bad_args", "item key must start c")

static func counter(t) -> void:
	var c := ctx()
	c.db._cards["p.test.pawn"]["effects"]["on_accept"] = [{"op":"money","delta":3,"reason":"g04.reason.test"}]
	var uid := customer(c)
	t.no_leaks(CardCounter.view(c, uid), "counter")
	t.ok(CardCounter.close(c, uid)["ok"], "close successful")
	t.eq(CardPiles.zone_of(c, uid), &"hand", "close preserves card")
	var cash_before := CardCurrency.money(c)
	var deal := CardCounter.offer(c, uid, &"fair")
	t.eq(deal["reply"], "accept", "pawn acceptance")
	t.eq(CardCurrency.money(c), cash_before - int(deal["price"]) + 3, "on_accept effects execute")
	var seller := customer(c, "p.test.sell")
	t.eq(CardCounter.offer(c, seller, &"fair")["reply"], "accept", "sale intake")
	var id := str(CardShelf.items(c)[0])
	var buyer := customer(c, "p.test.buy")
	var locations: Array = []
	c.hooks.on(&"card_resolved", func(context: CardCtx, args: Dictionary) -> void:
		if str(args.get("uid", "")) == buyer:
			locations.append(str(context.state.ns("econ")["ledger"]["items"][id]["location"])), 99, "test")
	t.ok(CardCounter.pick_stock(c, buyer, id)["ok"], "buyer selects matching stock")
	t.eq(CardCounter.offer(c, buyer, &"fair")["reply"], "accept", "stock sale")
	t.eq(CardShelf.items(c).size(), 0, "item leaves shelf")
	t.eq(locations, ["npc:test_buyer"], "transaction snapshot synchronized before resolved hooks")
	c.db._cards["p.test.pawn"]["effects"]["on_refuse"] = [{"op":"money","delta":1,"reason":"g04.reason.test"}]
	var refused := customer(c)
	cash_before = CardCurrency.money(c)
	t.ok(CardCounter.refuse(c, refused)["ok"], "refusal resolves")
	t.eq(CardPiles.zone_of(c, refused), &"discard", "refused card discarded")
	t.eq(CardCurrency.money(c), cash_before + 1, "on_refuse effects execute")
	c.db._cards["p.test.pawn"]["effects"]["on_leave"] = [{"op":"money","delta":2,"reason":"g04.reason.test"}]
	var impatient := customer(c)
	E.session(c, impatient)["patience"] = 1
	# 10-25: a price the shop cannot pay is refused before patience is spent (money_short), so keep the purse full
	# here; this check is about the patience running out.
	E.fund(c, "player", CardCurrency.money(c) + 1000)
	cash_before = CardCurrency.money(c)
	t.eq(CardCounter.offer(c, impatient, &"fair")["reply"], "leave", "exhausted guest leaves")
	t.eq(CardCurrency.money(c), cash_before + 2, "on_leave effects execute")
	c.mods.register(&"intake_blocked", func(_ctx: CardCtx, args: Dictionary) -> bool: return str(args.get("cat", "")) == "jewelry", "test")
	var blocked := customer(c)
	t.eq(CardCounter.offer(c, blocked, &"kind").get("err"), "intake_blocked", "mortgaged cabinet blocks jewelry")
	t.eq(CardCounter.view(c, blocked).get("line_key"), "g04.counter.intake_blocked", "blocked response uses key")
	var stale := customer(c)
	CardPiles.resolve(c, stale, &"left")
	var cash := CardCurrency.money(c)
	t.eq(CardCounter.offer(c, stale, &"kind").get("err"), "bad_args", "discarded session cannot trade again")
	t.eq(CardCurrency.money(c), cash, "stale command cannot change cash")
	c.hooks.fire(c, &"day_start", {})
	t.ok(E.session(c, stale).is_empty(), "new day cleans finished sessions")
	assert_clean(t, c)

static func pricing_customer(t) -> void:
	for seed in range(50):
		var c := ctx(seed)
		var uid := customer(c)
		var s := E.session(c, uid)
		var tiers := CardPricing.tiers(c, uid)
		t.ok(tiers["harsh"] <= tiers["fair"] and tiers["fair"] <= tiers["kind"], "ordered pay tiers")
		E.meta(c, str(s["item"]))["market"] = 900000
		E.meta(c, str(s["item"]))["fake"] = true
		t.eq(CardPricing.tiers(c, uid), tiers, "hidden values cannot change tiers")
		s["floor"] = 99999
		var r := CardCounter.offer(c, uid, &"harsh")
		t.ok(r["reply"] in ["counter", "leave"], "hidden threshold produces counter or departure")
		if not E.session(c, uid).is_empty():
			s["round"] = 4
			t.eq(CardCounter.offer(c, uid, &"harsh")["reply"], "leave", "fifth unsuccessful offer leaves")
	var c := ctx()
	var uid := customer(c)
	E.session(c, uid)["patience"] = 1
	t.eq(CardCustomer.spend_patience(c, uid, 10), &"leave", "patience exhaustion leaves")
	E.session(c, uid)["impatience"] = "raise"
	t.eq(CardCustomer.spend_patience(c, uid, 10), &"raise", "raise policy changes opening quote")

	var buyer_ctx := ctx()
	buyer_ctx.db._cards["p.test.buy"]["want"]["budget_pct"] = [130,130]
	buyer_ctx.state.ns("econ")["price_index"] = 200
	var seller := customer(buyer_ctx, "p.test.sell")
	CardCounter.offer(buyer_ctx, seller, &"fair")
	var item := str(CardShelf.items(buyer_ctx)[0])
	E.meta(buyer_ctx, item)["market"] = 7
	var buyer := customer(buyer_ctx, "p.test.buy")
	CardCounter.pick_stock(buyer_ctx, buyer, item)
	t.eq(E.session(buyer_ctx, buyer)["floor"], 7 * 200 * 130 / 10000, "buyer budget uses true item amount and current price index")
	var visible := CardPricing.tiers(buyer_ctx, buyer)
	E.meta(buyer_ctx, item)["market"] = 9999
	t.eq(CardPricing.tiers(buyer_ctx, buyer), visible, "buyer tiers remain independent of hidden true amount")
	t.no_leaks(CardCounter.view(buyer_ctx, buyer), "buyer view")
	price_mod_sign(t, buyer_ctx, buyer, item)
	assert_clean(t, buyer_ctx)

## price_mod 的 pct 是带符号的增量（§5.2）：+5 涨、-8 落，几条相加，合计不低于 price_mod_min_pct。
static func price_mod_sign(t, c: CardCtx, buyer: String, item: String) -> void:
	E.meta(c, item)["base_price"] = 1000
	var base := E.visible_amount(c, item)
	var fair := int(c.rules("economy")["tiers"]["receive"]["fair"])
	var mods: Array = c.state.ns("econ")["price_mods"]
	t.eq(CardPricing.tiers(c, buyer)["fair"], base * fair / 100, "no price_mod keeps shelf price")
	c.run([{"op":"price_mod","scope":"shelf","pct":5,"days":1}], "test")
	t.eq(c.mods.pct(c, &"price_pct", {"direction":"receive"}), 105, "+5 is a five percent raise")
	t.eq(CardPricing.tiers(c, buyer)["fair"], base * fair * 105 / 10000, "+5 raises shelf price")
	t.eq(c.mods.pct(c, &"price_pct", {"direction":"pay"}), 100, "price_mod leaves what you pay alone")
	mods.clear()
	c.run([{"op":"price_mod","scope":"shelf","pct":-8,"days":1}], "test")
	t.eq(c.mods.pct(c, &"price_pct", {"direction":"receive"}), 92, "-8 is an eight percent cut")
	t.eq(CardPricing.tiers(c, buyer)["fair"], base * fair * 92 / 10000, "-8 lowers shelf price")
	c.run([{"op":"price_mod","scope":"shelf","pct":5,"days":1}], "test")
	t.eq(c.mods.pct(c, &"price_pct", {"direction":"receive"}), 97, "active deltas add up")
	mods.clear()
	var cat := str(E.meta(c, item)["cat"])
	c.run([{"op":"price_mod","scope":"cat","cat":cat + "_other","pct":40,"days":1}], "test")
	t.eq(c.mods.pct(c, &"price_pct", {"direction":"receive", "cat":cat}), 100, "cat price_mod skips other categories")
	c.run([{"op":"price_mod","scope":"cat","cat":cat,"pct":20,"days":1}], "test")
	t.eq(c.mods.pct(c, &"price_pct", {"direction":"receive", "cat":cat}), 120, "cat price_mod hits its category")
	mods.clear()
	c.run([{"op":"price_mod","scope":"shelf","pct":-500,"days":1}], "test")
	var floor_pct := int(c.rules("economy").get("price_mod_min_pct", 10))
	t.eq(c.mods.pct(c, &"price_pct", {"direction":"receive"}), floor_pct, "price_mod total clamps at the floor")
	t.ok(CardPricing.tiers(c, buyer)["harsh"] >= 1, "clamped shelf price stays positive")
	mods.clear()

static func shelf_tickets(t) -> void:
	var c := ctx()
	c.mods.register(&"cap", func(_ctx: CardCtx, args: Dictionary) -> int: return -11 if str(args.get("zone", "")) == "shelf" else 0, "test")
	t.eq(CardShelf.cap(c), 1, "mortgage shelf capacity adjustment")
	var tid := pawn(c)
	var due: int = c.ledger.contracts[tid]["due_day"]
	c.state.ns("loop")["abs_day"] = due + 1
	CardTickets.tick(c)
	t.eq(c.ledger.contracts[tid]["status"], "overdue", "ticket overdue")
	c.state.ns("loop")["abs_day"] = due + 4
	CardTickets.tick(c)
	t.eq(c.ledger.contracts[tid]["status"], "forfeited", "configured grace expires")
	t.eq(CardShelf.items(c).size(), 1, "original item goes onto shelf")
	var r := CardItems.generate(c, ["c", 1, "overflow"], "utensils.bowl")
	t.eq(CardShelf.add(c, r, "test"), "", "shelf overflow declined")
	var tid2 := pawn(c)
	CardTickets.forfeit_all(c)
	t.eq(c.ledger.contracts[tid2]["status"], "forfeited", "year jump forfeits active contracts")
	var money := CardCurrency.money(c)
	CardTickets.foreign(c, spawn(c, "tk.test.foreign"))
	t.eq(CardCurrency.money(c), money, "foreign ticket no cash movement")
	t.ok(CardTickets.view(c)[-1]["foreign"], "foreign view records origin of ticket")
	assert_clean(t, c)

static func redeem(t) -> void:
	for mode in [&"by_rule", &"squeeze", &"compensate", &"buy_back"]:
		var c := ctx()
		c.run([{ "op":"money", "delta":1000, "reason":"g04.reason.test"}], "test")
		var tid := pawn(c)
		var uid := redeem_customer(c, tid)
		var id := str(c.ledger.contracts[tid]["item_ids"][0])
		if mode in [&"compensate", &"buy_back"]:
			E.account(c, "test_past_buyer")
			c.ledger.move_item(id, "npc:test_past_buyer", "test_past_buyer", "sold")
		else:
			t.eq(CardCounter.redeem(c, uid, &"compensate").get("err"), "original_present", "compensation requires disposed original")
		t.ok(bool(CardCounter.redeem(c, uid, mode).get("ok", false)), "redemption mode succeeds")
		t.eq(c.ledger.contracts[tid]["status"], "compensated" if mode == &"compensate" else "redeemed", "redemption closes contract")
		assert_clean(t, c)

static func appraisal_params(t) -> void:
	for seed in range(20):
		var c := ctx(seed)
		for item_def in c.db.ids_of(&"item"):
			var d := c.db.def(item_def)
			var r := CardItems.generate(c, ["c", 1, item_def], str(d["template"]))
			var id := str(r["item"])
			for kind in d.get("minigames", []):
				var p := CardAppraisal.params_for(c, id, StringName(str(kind)))
				t.ok(not forbidden(p), "every item and supported game has safe parameter keys")
				t.eq(CardAppraisal.params_for(c, id, StringName(str(kind))), p, "physical parameters deterministic")
		c.db._cards["tk.test.foreign"]["fragments"]["pieces"] = [4,8]
		c.db._cards["tk.test.foreign"]["fragments"]["seal_offset_px"] = [0,3]
		var uid := spawn(c, "tk.test.foreign")
		var r := CardAppraisal.request(c, uid, "")
		t.ok(r.get("ok", false) and not forbidden(r.get("params", {})), "itemless fragments allowed")
		t.ok(typeof(r["params"]["pieces"]) == TYPE_INT and int(r["params"]["pieces"]) >= 4 and int(r["params"]["pieces"]) <= 8, "K11 fragment interval is sampled to an integer")
		var news := spawn(c, "nw.test.decode")
		var decode := CardAppraisal.request(c, news, "")
		t.ok(decode.get("ok", false) and not forbidden(decode.get("params", {})), "decode parameter safety")

static func appraisal_report(t) -> void:
	var c := ctx()
	var uid := customer(c)
	var item := str(E.session(c, uid)["item"])
	var tiers := CardPricing.tiers(c, uid)
	CardAppraisal.request(c, uid, item)
	var invalid := result()
	invalid["verdict"] = "unused"
	t.eq(CardAppraisal.report(c, uid, item, invalid).get("err"), "bad_args", "report rejects extra conclusion fields")
	invalid = result()
	invalid["measures"] = {"read_fen": 1.5}
	t.eq(CardAppraisal.report(c, uid, item, invalid).get("err"), "bad_args", "report rejects float measures")
	for row in [[800,"obs.spot.material.wear"],[500,"obs.spot.material.plain"],[100,"obs.spot.material.unclear"]]:
		CardAppraisal.request(c, uid, item)
		var r := CardAppraisal.report(c, uid, item, result(int(row[0]), [row[1], "obs.missing", "obs.weigh.match"], 2))
		t.eq(r["observations"], [row[1]], "catalog and fidelity filter")
		t.eq(CardPricing.tiers(c, uid), tiers, "appraisal has no pricing effect")
		t.no_leaks(r, "report")
	t.eq(E.session(c, uid)["patience"], 114, "minutes deducted")
	c.mods.register(&"appraise_pct", func(_ctx: CardCtx, _args: Dictionary) -> int: return 200, "test")
	CardAppraisal.request(c, uid, item)
	t.eq(CardAppraisal.report(c, uid, item, result(400,["obs.spot.material.wear"]))["observations"], ["obs.spot.material.wear"], "appraisal modifier improves clarity")
	assert_clean(t, c)

static func ops_conds(t) -> void:
	var c := ctx()
	var before := CardCurrency.money(c)
	c.run([{"op":"money","delta":50,"reason":"g04.reason.test"}], "test")
	t.eq(CardCurrency.money(c), before + 50, "positive money op transfers reserve")
	c.run([{"op":"pay","amount":10,"payee":"fees","reason":"g04.reason.fee","short":"fail"}], "test")
	t.eq(CardCurrency.money(c), before + 40, "pay op succeeds")
	var fired: Array = []
	c.hooks.on(&"money_short", func(_ctx: CardCtx, args: Dictionary) -> void: fired.append(args.duplicate()), 99, "test")
	c.run([{"op":"pay","amount":10000,"payee":"fees","reason":"g04.reason.fee","short":"ladder"}], "test")
	t.eq(fired, [{"amount":10000,"payee":"fees","source":"test/0"}], "ladder fires complete hook arguments")
	c.run([{"op":"pay","amount":10000,"payee":"fees","reason":"g04.reason.fee","short":"fail"}], "test")
	t.eq(CardCurrency.money(c), before + 40, "fail pays nothing")
	t.eq(fired.size(), 1, "fail does not fire money_short")
	c.db._cards["p.test.pawn"]["effects"]["on_short"] = [{"op":"money","delta":7,"reason":"g04.reason.test"}]
	var source_uid := spawn(c)
	var cash_before := CardCurrency.money(c)
	c.run([{ "op":"pay", "amount":10000, "payee":"fees", "reason":"g04.reason.fee", "short":"fail"}], source_uid + "/choices/cost")
	t.eq(CardCurrency.money(c), cash_before + 7, "pay fail runs source card on_short")
	c.run([{"op":"item_gain","template":"utensils.bowl","n":2}], "test")
	t.ok(c.test({"stock_has":"utensils.bowl"}), "stock_has condition")
	t.ok(c.test({"stock_cat_gte":["utensils",2]}), "stock_cat_gte condition")
	c.run([{"op":"item_lose","match":{"cat":"utensils","pick":"worst"},"n":1,"reason":"g04.reason.test"}], "test")
	t.eq(CardShelf.items(c).size(), 1, "item_lose selects one")
	c.run([{"op":"shop_closed","days":3},{"op":"price_mod","scope":"shelf","pct":50,"days":2}], "test")
	t.eq(c.mods.sum_int(c,&"deal_count",{"type":"person","abs_day":2}), -100000, "closure prevents random person draws")
	t.eq(c.mods.sum_int(c,&"deal_count",{"type":"person","abs_day":10}), 0, "projection checks future closure expiry")
	t.eq(c.mods.pct(c,&"price_pct",{"direction":"receive"}), 150, "price modification applied")
	t.ok(c.test({"money_gte":0}) and c.test({"money_lt":10000}) and c.test({"currency":"fabi"}), "money and currency conditions")
	pawn(c)
	t.ok(c.test({"ticket_open":"test_pawner"}), "open ticket condition")
	c.run([{"op":"currency_convert","to":"fabi","num":2,"den":1}], "test")
	c.state.ns("loop")["abs_day"] = 6
	c.hooks.fire(c,&"day_start",{})
	t.eq(c.mods.pct(c,&"price_pct",{"direction":"receive"}), 100, "expired price modifier removed")
	c.run([{"op":"pay","amount":10000,"payee":"fees","reason":"g04.reason.fee","short":"partial"}], "test")
	t.eq(CardCurrency.money(c), 0, "partial pays available cash only")
	var valid_effects := [{"op":"money","delta":1,"reason":"g04.reason.test"},{"op":"pay","amount":1,"payee":"fees","reason":"g04.reason.fee","short":"fail"},
		{"op":"item_gain","cat":"utensils"},{"op":"item_lose","match":{"cat":"utensils"},"reason":"g04.reason.test"},{"op":"shop_closed","days":1},
		{"op":"price_mod","scope":"shelf","pct":100,"days":1},{"op":"currency_convert","to":"fabi","num":1,"den":1}]
	for eff in valid_effects:
		t.eq(CardDslShapes.check_effect(eff), "", "positive effect shape")
		var bad: Dictionary = eff.duplicate(true)
		bad["unexpected"] = 1
		t.ok(CardDslShapes.check_effect(bad) != "", "malformed effect rejected")
	for cond in [{"money_gte":0},{"money_lt":1},{"stock_cat_gte":["utensils",1]},{"stock_has":"utensils.bowl"},{"ticket_open":"test_pawner"},{"currency":"fabi"}]:
		t.eq(c.conds.validate(cond), "", "positive condition shape")
		var key = cond.keys()[0]
		t.ok(c.conds.validate({key:{"bad":true}}) != "", "malformed condition rejected")
	assert_clean(t, c)

static func soak(t) -> void:
	for seed in range(10):
		var c := ctx(seed)
		for stage in range(3):
			c.state.ns("loop")["stage"] = stage
			c.hooks.fire(c, &"stage_start", {"stage": c.db.stage(stage)})
			for day in range(30):
				c.state.ns("loop")["abs_day"] = stage * 30 + day + 1
				c.hooks.fire(c, &"day_start", {})
				var uid := customer(c)
				var r := CardCounter.offer(c, uid, &"fair")
				if not bool(r.get("ok", false)):
					CardCounter.refuse(c, uid)
				if day % 3 == 0:
					for ticket in CardTickets.view(c):
						if str(ticket["status"]) == "active" and not bool(ticket["foreign"]):
							CardCounter.redeem(c, redeem_customer(c, "t%04d" % int(ticket["no"])), &"by_rule")
							break
				c.hooks.fire(c, &"settle", {})
				assert_clean(t, c)
			c.hooks.fire(c, &"month_close", {})
			var cash := CardCurrency.money(c)
			c.hooks.fire(c, &"month_close", {})
			t.eq(CardCurrency.money(c), cash, "monthly expense replay idempotent")
			c.hooks.fire(c, &"year_jump", {"to": c.db.stage(mini(stage+1,2))})
			t.ok(JSON.stringify(c.state.ns("econ")).length() < 512*1024, "economic state within save budget")

static func sequence(c: CardCtx) -> void:
	c.run([{ "op":"money", "delta":1000, "reason":"g04.reason.test"}], "test")
	var uid := customer(c)
	var item := str(E.session(c, uid)["item"])
	CardAppraisal.request(c, uid, item)
	CardAppraisal.report(c, uid, item, result(800,["obs.spot.material.wear"],3))
	CardCounter.offer(c, uid, &"fair")
	var seller := customer(c, "p.test.sell")
	CardCounter.offer(c, seller, &"fair")
	var buyer := customer(c, "p.test.buy")
	CardCounter.pick_stock(c, buyer, str(CardShelf.items(c)[0]))
	CardCounter.offer(c, buyer, &"fair")
	c.hooks.fire(c, &"settle", {})

static func determinism(t) -> void:
	var partial := ctx()
	partial.state.data["econ"] = {}
	partial.ledger = null
	var h := partial.state.hash()
	CardCurrency.money(partial)
	CardShelf.view(partial)
	CardTickets.view(partial)
	CardCounter.view(partial, "missing")
	t.eq(partial.state.hash(), h, "queries preserve even partial economy state")
	for phase in ["morning", "month_open"]:
		var a := ctx(77)
		var b := ctx(77)
		sequence(a)
		sequence(b)
		t.eq(a.state.hash(), b.state.hash(), "same seed and actions produce same hash")
		a.state.ns("loop")["phase"] = phase
		b.state.ns("loop")["phase"] = phase
		b.state = CardState.from_dict(JSON.parse_string(JSON.stringify(b.state.to_dict())))
		b.ledger = null
		E.ensure(b)
		a.state.ns("loop")["abs_day"] = 2
		b.state.ns("loop")["abs_day"] = 2
		sequence(a)
		sequence(b)
		t.eq(a.state.hash(), b.state.hash(), "save restore continuation from allowed phase")
		assert_clean(t, b)

static func firsts(t) -> void:
	var c := ctx()
	var uid := customer(c)
	var item := str(E.session(c, uid)["item"])
	CardAppraisal.request(c, uid, item)
	CardCounter.offer(c, uid, &"fair")
	var seller := customer(c, "p.test.sell")
	CardCounter.offer(c, seller, &"fair")
	customer(c, "p.test.buy")
	var order: Array = []
	for ev in c.out:
		if ev[0] == &"first_time" and str(ev[1]) in ["counter","mg.spot","ticket","shelf","buyer"]:
			order.append(str(ev[1]))
	t.eq(order, ["counter","mg.spot","ticket","shelf","buyer"], "tutorial first day order")
	for kind in ["coin_ring","weigh","fragments","decode"]:
		c.db._cards["p.test.pawn"]["minigame"] = kind
		var next := customer(c)
		CardAppraisal.request(c,next,str(E.session(c,next)["item"]))
	CardCounter.redeem(c,redeem_customer(c,"t0001"),&"by_rule")
	c.run([{"op":"shop_closed","days":1},{"op":"currency_convert","to":"fabi","num":1,"den":1}], "test")
	var counts: Dictionary = {}
	for ev in c.out:
		if ev[0] == &"first_time":
			counts[str(ev[1])] = int(counts.get(str(ev[1]),0)) + 1
			for key in ev[2].keys():
				t.ok(str(key) in ["uid","def","kind","person","no"], "first args whitelist")
	for mechanism in ["counter","mg.spot","mg.coin_ring","mg.weigh","mg.fragments","mg.decode","ticket","shelf","buyer","redeem","shop_closed","currency"]:
		t.eq(counts.get(mechanism,0), 1, "mechanism exactly once")
	var prior: Dictionary = c.state.ns("core")["firsts"].duplicate(true)
	c.state = CardState.from_dict(JSON.parse_string(JSON.stringify(c.state.to_dict())))
	E.ensure(c)
	c.out.clear()
	sequence(c)
	for ev in c.out:
		if ev[0] == &"first_time":
			t.ok(not prior.has(str(ev[1])), "restored first never repeats")
	for seed in range(50):
		var seeded := ctx(seed)
		var tutorial := customer(seeded)
		t.eq(CardAppraisal.request(seeded,tutorial,str(E.session(seeded,tutorial)["item"]))["kind"], "spot", "tutorial always picks spot across seeds")
