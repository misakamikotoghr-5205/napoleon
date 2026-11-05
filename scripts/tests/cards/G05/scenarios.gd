# G05 各验收条目的共享测试体，真实算法在 W0 独立上下文上执行。
# 每个清单入口只选自己的测试场景与固定种子范围。
extends RefCounted
const F = preload("res://scripts/tests/cards/G05/fixture.gd")

static func run(t, name: String, args: Dictionary) -> void:
	var db := F.db()
	match name:
		"G05_weights": weights(t, db)
		"G05_fate_trigger": triggers(t, db)
		"G05_wheel_math": wheel_math(t, db, int(args.get("seeds", 200)))
		"G05_wheel_flow": wheel_flow(t, db)
		"G05_lot_accuracy_a", "G05_lot_accuracy_b", "G05_lot_accuracy_c", "G05_lot_accuracy_d": accuracy(t, db, args)
		"G05_lot_harsh": harsh(t, db, int(args.get("seeds", 500)))
		"G05_cezi": cezi(t, db, int(args.get("seeds", 200)))
		"G05_almanac": almanac(t, db)
		"G05_pressure_weather": pressure(t, db, int(args.get("seeds", 20)))
		"G05_ops_conds": ops(t, db)
		"G05_view_leaks": leaks(t, db)
		"G05_determinism_save": determinism(t, db)
		"G05_firsts": firsts(t, db)

static func weights(t, db: CardDB) -> void:
	var ctx := F.ctx(db)
	var original := CardWeights.rows(ctx, &"event")
	t.ok(original.size() >= 6, "eligible era cards included")
	var keys: Array = original.map(func(row: Array) -> String: return str(row[0]))
	var sorted := keys.duplicate()
	sorted.sort()
	t.eq(keys, sorted, "rows sorted by definition ID")
	ctx.state.ns("fate")["month_mods"] = [{"pool": "event", "def": "ev.test.0", "pct": 131}]
	ctx.state.ns("fate")["deck_mods"] = [{"pool": "event", "def": "ev.test.0", "pct": 55, "until_abs_day": 5}]
	ctx.mods.register(&"pool_pct", func(_c: CardCtx, a: Dictionary) -> int: return 125 if str(a["def"]) == "ev.test.0" else 100, "test")
	t.eq(_weight(CardWeights.rows(ctx, &"event"), "ev.test.0"), 90, "integer percent rounded each step:100*131/100*55/100*125/100")
	F.advance(ctx, 6)
	t.eq(_weight(CardWeights.rows(ctx, &"event"), "ev.test.0"), 163, "temporary modifiers expire")
	CardPins.ban(ctx, 6, ["omen_official"], "test")
	t.eq(_weight(CardWeights.rows(ctx, &"event"), "ev.test.0"), 0, "banned omen excluded")
	t.eq(CardWeights.rows(ctx, &"big_fate"), [], "big fate cards never random")
	ctx.state.ns("fate")["weather"] = "rain"
	var expected := -int(db.rules("deal")["person"]["rain_penalty"]) + (int(db.rules("deal")["person"]["market_bonus"]) if CardCalendar.is_market_day(ctx, 6) else 0)
	t.eq(CardWeights.deal_count(ctx, {"type": "person", "abs_day": 6}), expected, "weather and market count sourced once")

static func _weight(rows: Array, id: String) -> int:
	for row in rows:
		if str(row[0]) == id:
			return int(row[1])
	return 0

static func triggers(t, db: CardDB) -> void:
	for seed in range(50):
		var ctx := F.ctx(db, seed)
		ctx.state.ns("fate")["fate_last_abs_day"] = 4
		var hash := ctx.state.hash()
		t.eq(CardFateTrigger.fate_due(ctx), false, "minimum interval")
		t.eq(ctx.state.hash(), hash, "fate_due pure")
		F.advance(ctx, 8)
		t.ok(CardFateTrigger.fate_due(ctx), "max gap guarantees draw")
		CardFateTrigger.on_crisis(ctx, &"arrested")
		CardFateTrigger.on_crisis(ctx, &"arrested")
		CardFateTrigger.on_crisis(ctx, &"heat_max")
		CardFateTrigger.on_crisis(ctx, &"street_long")
		t.eq(CardPiles.list(ctx, CardIds.ZONE_HAND).size(), 2, "crisis limited per stage and kind")
		for uid in CardPiles.list(ctx, CardIds.ZONE_HAND):
			t.eq(CardPiles.def_of(ctx, uid)["id"], "bf.wheel", "only system wheel emitted")
	var ctx := F.ctx(db)
	ctx.state.ns("ladder")["street"] = {"since_abs_day": 1}
	t.eq(CardFateTrigger.crisis(ctx), &"street_long", "street crisis reads ladder")
	ctx.hooks.fire(ctx, &"stage_start", {"stage": 0})
	t.eq(ctx.state.ns("fate")["big"]["stage_count"], 0, "stage reset")

static func wheel_math(t, db: CardDB, seeds: int) -> void:
	var ctx := F.ctx(db)
	var previous := 0.0
	for units in range(7):
		ctx.state.ns("fate")["wheels"] = {"wh.month:": {"spin_no": 0, "incense": [{"kind": "money", "amount": units * 5}], "stake": "", "result": {}}}
		var view := CardWheel.view(ctx, "wh.month", "")
		var good := float(view["segments"][0]["arc_deg"])
		t.ok(good >= previous, "good arc monotonic with incense")
		previous = good
		t.no_leaks(view, "wheel view")
	for seed in range(seeds):
		ctx = F.ctx(db, seed)
		var view := CardWheel.view(ctx, "wh.month", "")
		var spun := CardWheel.spin(ctx, "wh.month", "")
		t.ok(bool(spun.get("ok")), "monthly wheel spin succeeds")
		var start := 0.0
		for segment in view["segments"]:
			var end := start + float(segment["arc_deg"])
			if str(segment["id"]) == str(spun.get("segment", "")):
				t.ok(float(spun["stop_deg"]) >= start - 0.00001 and float(spun["stop_deg"]) < end + 0.00001, "needle falls in chosen displayed sector")
			start = end
		t.eq(t.find_floats(ctx.state.data), PackedStringArray(), "angles stored integers")
	ctx = F.ctx(db)
	ctx.state.ns("rules")["meters"]["conscience"] = -100
	var uid := CardPiles.spawn(ctx, "bf.wheel", CardIds.ZONE_HAND)
	var bad_view := CardWheel.view(ctx, "wh.big", uid)
	t.ok(not bad_view["segments"].any(func(s: Dictionary) -> bool: return s["id"] == "ws.any.big.fanshen_ship"), "condition excludes segment in view")
	t.ok(not CardWheel.weights(ctx, "wh.big", uid).any(func(r: Array) -> bool: return r[0] == "ws.any.big.fanshen_ship"), "condition excludes spin weight")

static func wheel_flow(t, db: CardDB) -> void:
	var ctx := F.ctx(db)
	ctx.state.ns("econ")["ledger"]["accounts"]["player"] = 0
	ctx.state.ns("fate")["wheels"] = {"wh.fair:reserved": {"spin_no": 0, "incense": [{"kind": "money", "amount": 100}], "stake": "", "result": {}}}
	t.ok(bool(CardWheel.spin(ctx, "wh.month", "").get("ok")), "zero-cost monthly spin accepts negative unreserved cash")
	var paid_uid := F.wheel_uid(ctx, "wh.fair")
	var hash_before := ctx.state.hash()
	t.eq(CardWheel.spin(ctx, "wh.fair", paid_uid).get("err"), "insufficient_money", "positive wheel fee still rejects exhausted reserved cash")
	t.eq(ctx.state.hash(), hash_before, "positive fee refusal leaves state unchanged")
	var fortune_uid := F.fortune_uid(ctx)
	t.ok(bool(CardFortune.draw_lot(ctx, fortune_uid).get("ok")), "free fortune accepts negative unreserved cash")
	ctx.db._cards["ev.test.fortune"]["cost"] = {"money": 1}
	hash_before = ctx.state.hash()
	t.eq(CardFortune.draw_lot(ctx, fortune_uid).get("err"), "insufficient_money", "positive fortune fee still respects reservations")
	t.eq(ctx.state.hash(), hash_before, "positive fortune refusal leaves state unchanged")
	ctx.db._cards["ev.test.fortune"]["cost"] = {"money": 0}
	ctx = F.ctx(db)
	var first := F.wheel_uid(ctx, "wh.fair")
	var second := F.wheel_uid(ctx, "wh.fair")
	t.ok(bool(CardWheel.offer(ctx, "wh.fair", first, {"kind": "money", "amount": 700}).get("ok")), "first wheel reserves funds")
	t.eq(CardWheel.offer(ctx, "wh.fair", second, {"kind": "money", "amount": 500}).get("err"), "insufficient_money", "second wheel cannot reuse reserved funds")
	t.ok(bool(CardWheel.withdraw(ctx, "wh.fair", first, 0).get("ok")), "withdraw releases funds")
	t.ok(bool(CardWheel.offer(ctx, "wh.fair", second, {"kind": "money", "amount": 500}).get("ok")), "released funds available")
	ctx = F.ctx(db)
	var reserved_kept := CardPiles.spawn(ctx, "kp.ma_owes", CardIds.ZONE_KEPT)
	var demand := CardPiles.spawn(ctx, "ev.test.fortune", CardIds.ZONE_DEMANDS)
	ctx.state.ns("rules")["cards"] = {demand: {"placed": {"test": [{"kind": "kept", "uid": reserved_kept}]}}}
	t.eq(CardWheel.offer(ctx, "wh.month", "", {"kind": "kept", "uid": reserved_kept}).get("err"), "slot_reject", "demand zone reservation prevents reuse on incense")
	ctx = F.ctx(db)
	var day_uid := F.wheel_uid(ctx, "wh.fair")
	t.ok(bool(CardFateInstall._command(ctx, {"wheel": "wh.fair", "uid": day_uid}, &"wheel.spin").get("ok")), "day card wheel opens through UI without engine panel state")
	ctx = F.ctx(db)
	var gate_hash := ctx.state.hash()
	t.eq(CardFateInstall._command(ctx, {"wheel": "wh.month", "uid": ""}, &"wheel.spin").get("err"), "bad_phase", "monthly command requires monthly phase and panel")
	t.eq(ctx.state.hash(), gate_hash, "closed monthly panel command does not mutate")
	ctx.state.ns("loop")["phase"] = "month_open"
	CardDayLoop.request_panel(ctx, &"wheel", {"wheel": "wh.month", "uid": "", "required": true})
	t.ok(bool(CardFateInstall._command(ctx, {"wheel": "wh.month", "uid": ""}, &"wheel.spin").get("ok")), "required monthly panel command succeeds")
	ctx = F.ctx(db)
	var uid := F.wheel_uid(ctx, "wh.fair")
	CardWheel.offer(ctx, "wh.fair", uid, {"kind": "money", "amount": 5})
	ctx.state.ns("econ")["ledger"]["accounts"]["player"] = 6
	var hash := ctx.state.hash()
	t.eq(CardWheel.spin(ctx, "wh.fair", uid).get("err"), "insufficient_money", "cost and incense checked together")
	t.eq(ctx.state.hash(), hash, "failed spin unchanged")
	ctx.state.ns("econ")["ledger"]["accounts"]["player"] = 100
	t.ok(bool(CardWheel.spin(ctx, "wh.fair", uid).get("ok")), "funded fair wheel")
	t.eq(ctx.state.ns("econ")["ledger"]["accounts"]["player"], 93, "cost plus incense paid")
	t.eq(CardPiles.zone_of(ctx, uid), CardIds.ZONE_DISCARD, "wheel card resolved")
	var uid2 := F.wheel_uid(ctx, "wh.fair")
	t.ok(bool(CardWheel.spin(ctx, "wh.fair", uid2).get("ok")), "second identical wheel independent")
	t.eq(ctx.state.ns("fate")["wheels"].size(), 2, "two UID scoped states")
	for seed in range(60):
		ctx = F.ctx(db, seed)
		uid = F.wheel_uid(ctx, "wh.gamble")
		t.eq(CardWheel.spin(ctx, "wh.gamble", uid).get("err"), "stake_required", "gamble requires stake")
		var kept := CardPiles.spawn(ctx, "kp.ma_owes", CardIds.ZONE_KEPT)
		t.ok(bool(CardWheel.stake(ctx, "wh.gamble", uid, kept).get("ok")), "stake accepted")
		var spun := CardWheel.spin(ctx, "wh.gamble", uid)
		var bad := str(db.def(str(spun["segment"]))["valence"]) == "bad"
		t.eq(CardPiles.zone_of(ctx, kept), CardIds.ZONE_DISCARD if bad else CardIds.ZONE_KEPT, "bad loses stake others return")

static func accuracy(t, db: CardDB, args: Dictionary) -> void:
	var from_seed := int(args.get("seed_from", 0))
	var to_seed := int(args.get("seed_to", 250))
	var total := 0
	var hit := 0
	for seed in range(from_seed, to_seed):
		var ctx := F.ctx(db, seed)
		var uid := F.fortune_uid(ctx)
		for lot in range(int(args.get("lots", 3))):
			var result := CardFortune.draw_lot(ctx, uid)
			t.ok(bool(result.get("ok")), "lot succeeds seed %d lot %d" % [seed, lot])
		var promises: Dictionary = ctx.state.ns("fate").get("pins", {}).duplicate(true)
		for day in range(6, 9):
			F.advance(ctx, day)
			ctx.state.ns("fate")["weather"] = "rain" if seed % 2 else "clear"
			var dealt := CardComposer.compose(ctx)
			var ids: Array = Array(dealt).map(func(card_uid: String) -> String: return str(CardPiles.card(ctx, card_uid)["def"]))
			for def in promises.get(str(day), []):
				total += 1
				if ids.has(str(def)):
					hit += 1
				t.ok(ids.has(str(def)), "promised card delivered seed %d day %d" % [seed, day])
		t.eq(t.find_floats(ctx.state.data), PackedStringArray(), "fortune state all integers")
	print("G05 ACCURACY seeds=%d..%d lots=%d promised=%d hit=%d rate=100%%" % [from_seed, to_seed - 1, (to_seed - from_seed) * int(args.get("lots", 3)), total, hit])
	t.ok(total > 0 and total == hit, "all foretold cards delivered")

static func harsh(t, db: CardDB, seeds: int) -> void:
	var counts := [0, 0]
	var samples := [0, 0]
	for seed in range(seeds):
		for mode in range(2):
			var ctx := F.ctx(db, seed)
			ctx.state.ns("rules")["meters"]["conscience"] = -100 if mode else 100
			var chosen := CardFortune._pick(ctx, CardFortune.future(ctx), db.rules("fortune")["lot"], 0)
			for row in chosen:
				samples[mode] += 1
				if CardFortune.bad(db.def(str(row["def"]))):
					counts[mode] += 1
	var high: float = float(counts[0]) / int(samples[0])
	var low: float = float(counts[1]) / int(samples[1])
	print("G05 HARSH high=%.4f low=%.4f delta=%.4f" % [high, low, low - high])
	t.ok(low - high >= 0.10, "low conscience significantly increases bad picks")

static func cezi(t, db: CardDB, seeds: int) -> void:
	var has := 0
	var none := 0
	for seed in range(seeds):
		var ctx := F.ctx(db, seed)
		var uid := F.fortune_uid(ctx)
		for char_id in CardFortune.offered(ctx, uid):
			var result := CardFortune.cezi(ctx, uid, char_id)
			t.ok(bool(result.get("ok")), "offered character accepted")
			if str(result.get("reading", "")) == "none":
				none += 1
				for day in range(6, 9):
					var temporal := CardFortune.temporal(ctx, day)
					for def in CardComposer.project(temporal, day):
						t.ok(not _overlap(db.def(def).get("tags", []), db.def(char_id)["tags"]), "none remains true for random future")
			else:
				has += 1
				var found := false
				for day in range(6, 9):
					for def in CardPins.pinned(ctx, day):
						if _overlap(db.def(def).get("tags", []), db.def(char_id)["tags"]):
							found = true
				t.ok(found, "has omen pinned")
		var promises: Dictionary = ctx.state.ns("fate").get("pins", {}).duplicate(true)
		for day in range(6, 9):
			F.advance(ctx, day)
			var cards := CardComposer.compose(ctx)
			var defs: Array = Array(cards).map(func(card_uid: String) -> String: return str(CardPiles.card(ctx, card_uid)["def"]))
			for promised in promises.get(str(day), []):
				t.ok(defs.has(str(promised)), "cezi has prediction actually dealt")
			for def in defs:
				t.ok(not _overlap(db.def(str(def)).get("tags", []), Array(CardPins.banned(ctx, day))), "cezi none holds in actual random deal")
		t.no_leaks(CardFortune.query(ctx, uid))
	t.ok(has > 0 and none > 0, "both readings covered")
	print("G05 CEZI has=%d none=%d" % [has, none])

static func _overlap(a: Array, b: Array) -> bool:
	for value in a:
		if b.has(value):
			return true
	return false

static func almanac(t, db: CardDB) -> void:
	var old_weight := int(db._cards["alm.shoudang"]["weight"])
	db._cards["alm.shoudang"]["weight"] = 0
	F.add(db, {"id": "alm.test.spring", "type": "almanac_day", "era": ["*"], "weight": 100, "season": [0], "yi": [], "ji": [], "reward": []})
	F.add(db, {"id": "alm.test.winter", "type": "almanac_day", "era": ["*"], "weight": 100, "season": [3], "yi": [], "ji": [], "reward": []})
	var seasonal := F.ctx(db)
	seasonal.state.ns("loop")["stage"] = 1
	CardAlmanac.start_day(seasonal)
	t.eq(CardAlmanac.today(seasonal)["id"], "alm.test.winter", "January is winter season3")
	seasonal.state.ns("loop")["stage"] = 0
	seasonal.state.ns("loop")["stage_day"] = 32
	CardAlmanac.start_day(seasonal)
	t.eq(CardAlmanac.today(seasonal)["id"], "alm.test.spring", "April remains spring season0")
	db._cards["alm.shoudang"]["weight"] = old_weight
	db._cards["alm.test.spring"]["weight"] = 0
	db._cards["alm.test.winter"]["weight"] = 0
	for actions in [["pawn_in"], ["pawn_in", "travel"], ["rest"], []]:
		var ctx := F.ctx(db)
		CardAlmanac.start_day(ctx)
		var before := int(ctx.state.ns("rules")["meters"]["rep"])
		CardAlmanac.note(ctx, actions + ["not_an_action"])
		CardAlmanac.settle(ctx)
		var expected := 1 if actions == ["pawn_in"] else 0
		t.eq(ctx.state.ns("rules")["meters"]["rep"], before + expected, "reward only yi and no ji")
		CardAlmanac.settle(ctx)
		t.eq(ctx.state.ns("rules")["meters"]["rep"], before + expected, "reward once")
		t.ok(not CardAlmanac.today(ctx)["done"].has("not_an_action"), "enum enforced")
		t.no_leaks(CardAlmanac.today(ctx))

static func pressure(t, db: CardDB, seeds: int) -> void:
	var days: Array = []
	for seed in range(seeds):
		var ctx := F.ctx(db, seed)
		var markets: Array = []
		for day in range(1, 16):
			F.advance(ctx, day)
			CardPressure.step_day(ctx)
			t.eq(t.find_floats(ctx.state.data), PackedStringArray(), "legacy pressure floats isolated")
			t.ok(str(ctx.state.ns("fate")["weather"]) in ["clear", "rain", "fog", "wind", "snow"], "valid weather")
			if CardCalendar.is_market_day(ctx, day):
				markets.append(day)
		if seed == 0:
			days = markets
		t.eq(markets, days, "markets deterministic calendar independent of seed")
		var before := CardPressure.value_milli(ctx, "c_support")
		CardPressure.influence(ctx, "c_support", 100, "test")
		CardPressure.influence(ctx, "c_support", 1000, "test")
		t.eq(CardPressure.value_milli(ctx, "c_support"), before + 200, "daily influence cap")
		CardPressure.influence(ctx, "c_support", -100, "test")
		t.eq(CardPressure.value_milli(ctx, "c_support"), before + 200, "both signs spend same cap")

static func ops(t, db: CardDB) -> void:
	var ctx := F.ctx(db)
	var effects: Array = [{"op": "deck_mod", "pool": "event", "pct": 120, "days": 2}, {"op": "fate_now", "day": "tomorrow"},
		{"op": "big_wheel", "crisis": "arrested"}, {"op": "wheel_offer", "wheel": "wh.fair"}, {"op": "pressure", "key": "c_support", "delta_milli": 100},
		{"op": "weather", "value": "rain"}, {"op": "peek", "pool": "event", "n": 1}]
	for effect in effects:
		t.eq(ctx.ops.validate(effect), "", "op valid shape")
		var bad: Dictionary = effect.duplicate()
		bad["unknown"] = true
		t.ok(ctx.ops.validate(bad) != "", "op rejects invalid shape")
		ctx.run([effect], "test")
	t.eq(ctx.state.ns("fate")["weather"], "rain", "weather op")
	t.eq(ctx.state.ns("core").get("test_extra_deal", {}).get("type"), "fate", "fate_now delegates extra_deal")
	t.ok(ctx.test({"weather": "rain"}), "weather condition")
	t.ok(ctx.test({"pressure_gte": ["c_support", 300]}), "pressure condition")
	ctx.state.ns("fate")["month_segment"] = "ws.test"
	t.ok(ctx.test({"fortune": "ws.test"}), "fortune condition")
	CardAlmanac.start_day(ctx)
	t.ok(ctx.test({"almanac_yi": "pawn_in"}), "almanac condition")
	t.eq(ctx.test({"market_day": true}), CardCalendar.is_market_day(ctx, 5), "market condition")
	for cond in [{"weather": 5}, {"pressure_gte": ["c_support", "x"]}, {"fortune": 5}, {"market_day": "yes"}, {"almanac_yi": "unknown"}]:
		t.ok(ctx.conds.validate(cond) != "", "condition rejects bad shape")

static func leaks(t, db: CardDB) -> void:
	var ctx := F.ctx(db)
	var uid := F.fortune_uid(ctx)
	var big_uid := F.card_uid(ctx, "bf.wheel")
	var offered_uid := F.wheel_uid(ctx, "wh.gamble")
	var wheel_uid := F.card_uid(ctx, "ev.test.wheel")
	var lot_uid := F.card_uid(ctx, "ev.test.fortune_lot")
	var cezi_uid := F.card_uid(ctx, "ev.test.fortune_cezi")
	var plain_uid := F.card_uid(ctx, "ev.test.0")
	var views := {
		"big": CardViewModel.card_view(ctx, big_uid, false),
		"offered": CardViewModel.card_view(ctx, offered_uid, false),
		"wheel": CardViewModel.card_view(ctx, wheel_uid, false),
		"both": CardViewModel.card_view(ctx, uid, false),
		"lot": CardViewModel.card_view(ctx, lot_uid, false),
		"cezi": CardViewModel.card_view(ctx, cezi_uid, false),
		"plain": CardViewModel.card_view(ctx, plain_uid, false),
	}
	t.eq(views["big"].get("wheel"), "wh.big", "big fate card exposes big wheel")
	t.eq(views["offered"].get("wheel"), "wh.gamble", "wheel offer exposes vars wheel")
	t.eq(views["wheel"].get("wheel"), "wh.fair", "opens_wheel exposes definition wheel")
	t.eq(views["plain"].get("wheel"), "", "plain card exposes empty wheel")
	t.eq(views["both"].get("fortune"), "both", "fortune card exposes both")
	t.eq(views["lot"].get("fortune"), "lot", "fortune card exposes lot")
	t.eq(views["cezi"].get("fortune"), "cezi", "fortune card exposes cezi")
	t.eq(views["plain"].get("fortune"), "", "plain card exposes empty fortune")
	for key in views:
		t.no_leaks(views[key], "card view " + str(key))
	CardFortune.draw_lot(ctx, uid)
	CardFortune.cezi(ctx, uid, "cz.test.empty")
	CardWheel.offer(ctx, "wh.month", "", {"kind": "money", "amount": 5})
	CardWheel.spin(ctx, "wh.month", "")
	CardAlmanac.start_day(ctx)
	CardAlmanac.note(ctx, ["pawn_in"])
	CardAlmanac.settle(ctx)
	var hash := ctx.state.hash()
	t.eq(CardFortune.cezi(ctx, uid, "cz.nonexistent").get("err"), "not_allowed", "unoffered cezi rejected")
	t.eq(ctx.state.hash(), hash, "unoffered cezi does not mutate")
	ctx.db._cards["ev.test.fortune"]["cost"] = {"money": 2000}
	hash = ctx.state.hash()
	t.eq(CardFortune.draw_lot(ctx, uid).get("err"), "insufficient_money", "fortune cost preflight")
	t.eq(ctx.state.hash(), hash, "unfunded fortune does not mutate")
	t.no_leaks(CardFortune.query(ctx, uid), "fortune")
	t.no_leaks(CardWheel.view(ctx, "wh.month", ""), "wheel")
	t.no_leaks(CardAlmanac.today(ctx), "almanac")
	t.no_leaks(CardViewModel.build(ctx), "full view")
	for event in ctx.out:
		t.no_leaks(event, "event")

static func determinism(t, db: CardDB) -> void:
	var a := F.ctx(db, 314)
	var b := F.ctx(db, 314)
	var uid_a := F.fortune_uid(a)
	var uid_b := F.fortune_uid(b)
	CardFortune.draw_lot(a, uid_a)
	CardFortune.draw_lot(b, uid_b)
	t.eq(a.state.hash(), b.state.hash(), "same seed same fortune")
	var saved: Dictionary = JSON.parse_string(JSON.stringify(a.state.to_dict()))
	b.state = CardState.from_dict(saved)
	for day in range(6, 9):
		for ctx in [a, b]:
			F.advance(ctx, day)
			ctx.hooks.fire(ctx, &"day_start", {"abs_day": day})
			CardComposer.compose(ctx)
			CardAlmanac.note(ctx, ["pawn_in"])
			ctx.hooks.fire(ctx, &"settle", {})
		t.eq(a.state.hash(), b.state.hash(), "save load continue identical")
		t.eq(t.find_floats(b.state.data), PackedStringArray(), "save state all integers")
	CardPins.clear_past(a)
	t.ok(not a.state.ns("fate")["pins"].has("6"), "past pin cleanup")

static func firsts(t, db: CardDB) -> void:
	var ctx := F.ctx(db)
	ctx.hooks.fire(ctx, &"month_open", {})
	CardWheel.offer(ctx, "wh.month", "", {"kind": "money", "amount": 5})
	CardAlmanac.start_day(ctx)
	ctx.state.ns("fate")["weather_next"] = "rain"
	F.advance(ctx, 1)
	CardAlmanac.start_day(ctx)
	F.advance(ctx, 3)
	CardPressure.step_day(ctx)
	var fortune := F.fortune_uid(ctx)
	var fair := F.wheel_uid(ctx, "wh.fair")
	var gamble := F.wheel_uid(ctx, "wh.gamble")
	var fate := CardPiles.spawn(ctx, "fa.any.fire_next_door", CardIds.ZONE_HAND)
	CardFateTrigger.on_crisis(ctx, &"arrested")
	for uid in [fortune, fair, gamble, fate]:
		CardFateInstall.card_firsts(ctx, uid)
	var counts: Dictionary = {}
	for event in ctx.out:
		if event[0] != &"first_time":
			continue
		var mech := str(event[1])
		counts[mech] = int(counts.get(mech, 0)) + 1
		for key in event[2].keys():
			t.ok(str(key) in ["uid", "def", "kind", "person", "no"], "first_time args whitelist")
		t.no_leaks(event, "first_time")
	for count in counts.values():
		t.eq(count, 1, "each first_time emitted once")
	var before := CardFirsts.all(ctx)
	ctx.state = CardState.from_dict(ctx.state.to_dict())
	ctx.out = []
	ctx.hooks.fire(ctx, &"month_open", {})
	CardAlmanac.start_day(ctx)
	CardPressure.step_day(ctx)
	for uid in [fortune, fair, gamble, fate]:
		CardFateInstall.card_firsts(ctx, uid)
	t.eq(CardFirsts.all(ctx), before, "mechanism firsts exactly once after save load")
	var events := 0
	for event in ctx.out:
		if event[0] == &"first_time":
			events += 1
	t.eq(events, 0, "repeated encounters emit no first_time")
	for mech in ["month_wheel", "incense", "almanac", "weather", "market_day", "fate", "big_wheel", "lot", "cezi", "fair_wheel", "gamble_wheel", "wheel_stake"]:
		t.ok(before.has(mech), "first mechanism %s" % mech)

