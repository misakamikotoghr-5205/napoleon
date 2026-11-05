# 条子每周确定发一张；按六种办法提交，拖延和到期四档阶梯可存档。
# 派出的人回来时当场可见掷铜钱；经济和家当效果均交给主人。
class_name CardDemands
extends RefCounted
const H = preload("res://scripts/cards/rules/rules_helpers.gd")

static func issue(ctx: CardCtx) -> String:
	var cfg := ctx.rules("demand_rules")
	if int(CardCalendar.today(ctx)["weekday"]) != int(cfg.get("issue_weekday", 0)): return ""
	var loop := ctx.state.ns("loop")
	var stage := int(loop.get("stage", 0))
	var week := CardCalendar.week_of(ctx, int(loop.get("stage_day", 1)))
	var demand: Dictionary = H.state(ctx)["demand"]
	if not demand.has("weeks"): demand["weeks"] = {}
	var week_key := "%d:%d" % [stage, week]
	if (demand["weeks"] as Dictionary).has(week_key): return str(demand["weeks"][week_key])
	CardRulesInstall.contact_hook(ctx, "demand_issue")
	var tiers: Array = cfg.get("tier_by_stage", [0])
	var base := int(tiers[mini(stage, tiers.size() - 1)])
	var heat_step := maxi(1, int(cfg.get("tier_heat_step", 40)))
	var tier := clampi(base + int(demand.get("tier_bias", 0)) + CardMeters.value(ctx, &"heat") / heat_step, 0, int(cfg.get("max_tier", 3)))
	var era := str(ctx.db.stage(stage).get("era", ""))
	var candidates: Dictionary = {}
	for id in ctx.db.pool(&"demand", era):
		var d := ctx.db.def(id)
		if not ctx.test(d.get("conditions", {})): continue
		var kind := str(d.get("kind", ""))
		if not candidates.has(kind): candidates[kind] = []
		(candidates[kind] as Array).append(id)
	var kinds := candidates.keys()
	kinds.sort()
	if kinds.is_empty(): return ""
	var kind := str(kinds[mini(int(ctx.draw("c.demand.kind", [stage, week]) * kinds.size()), kinds.size() - 1)])
	var pool: Array = []
	for id in candidates[kind]:
		if int(ctx.db.def(str(id)).get("tier", 0)) == tier: pool.append(id)
	if pool.is_empty(): pool = candidates[kind]
	pool.sort()
	var rows: Array = []
	for card_id in pool: rows.append([str(card_id), int(ctx.db.def(str(card_id)).get("weight", 10))])
	var id := str(JevRng.weighted_choice(rows, ctx.draw("c.demand.pick", [stage, week, kind])))
	var uid := CardPiles.spawn(ctx, id, &"demands")
	var d := ctx.db.def(id)
	var money: Dictionary = d.get("resolve", {}).get("money", {})
	var jitter := int(money.get("jitter_pct", 0))
	var offset := int(ctx.draw("c.demand.amt", [stage, week]) * (jitter * 2 + 1)) - jitter
	var amount := int(money.get("amount", 0)) * (100 + offset + CardMeters.tier(ctx, &"heat") * int(money.get("heat_tier_pct", 0))) / 100
	(demand["issued"] as Dictionary)[uid] = {"due_abs_day": ctx.abs_day() + int(d.get("deadline_days", cfg.get("deadline_days", 7))), "tier": tier, "kind": kind, "delays": 0, "mode": "", "amount": maxi(0, amount), "closed": false}
	demand["weeks"][week_key] = uid
	demand["tier_bias"] = 0
	CardFirsts.mark(ctx, &"demand", {"uid": uid, "def": id, "kind": kind})
	CardFirsts.mark(ctx, &"demand_delay", {"uid": uid})
	if kind == "info":
		CardFirsts.mark(ctx, &"demand_inform", {"uid": uid})
		CardFirsts.mark(ctx, &"demand_fabricate", {"uid": uid})
	ctx.run(d.get("effects", {}).get("on_deal", []), uid + "/on_deal")
	H.kept_first(ctx)
	return uid

static func submit(ctx: CardCtx, uid: String) -> Dictionary:
	var err := H.open_error(ctx, uid)
	if err != "": return H.error(err)
	if str(CardPiles.def_of(ctx, uid).get("type", "")) != "demand": return H.error("not_allowed")
	var row := _ensure(ctx, uid)
	var mode := str(row.get("mode", ""))
	if mode == "": return H.error("no_such_choice")
	if not bool(CardSlots.preview(ctx, uid)["ready"]): return H.error("slot_required")
	var d := CardPiles.def_of(ctx, uid)
	var resolve: Dictionary = d.get("resolve", {})
	var sources := _sources(ctx, uid)
	var kind := str(d.get("kind", ""))
	var amount := _money_due(ctx, uid, mode)
	if not H.afford(ctx, CardSlots.reserved_money(ctx) + CardSlots.wheel_money(ctx) + maxi(0, amount - CardSlots.placed_money(ctx, uid, true))): return H.error("insufficient_money")
	if mode == "pay":
		if kind == "money" and CardSlots.placed_money(ctx, uid, true) < amount: return H.error("slot_required")
		if kind == "goods" and _count(sources, "item") < int(resolve.get("goods", {}).get("n", 1)): return H.error("slot_required")
	elif mode == "send_person" and _count(sources, "person") < int(resolve.get("people", {}).get("n", 1)): return H.error("slot_required")
	elif mode == "inform" and _count(sources, "news") < int(resolve.get("info", {}).get("n", 1)): return H.error("slot_required")
	if mode in ["haggle", "fabricate"]:
		var rolled := CardSlots.toss_placed(ctx, uid)
		if not bool(rolled.get("ok", false)): return rolled
		var success := bool(rolled["success"])
		if not success:
			ctx.run(resolve.get(mode, {}).get("on_fail", []), uid + "/resolve/" + mode + "/on_fail")
			CardSlots.consume(ctx, uid)
			return {"ok": true, "err": "", "success": false, "faces": rolled["faces"]}
		if mode == "haggle": row["tier"] = maxi(0, int(row["tier"]) - int(resolve.get("haggle", {}).get("tier_down", 1)))
	H.pay(ctx, amount, uid + "/submit", "g03.reason.demand")
	row["paid_amount"] = amount
	if mode == "haggle" and kind == "money": row["amount"] = amount
	_finish_sources(ctx, uid, mode, sources)
	var almanac: Array = []
	CardSlots.consume(ctx, uid, almanac)
	row["closed"] = true
	CardPiles.resolve(ctx, uid, &"resolved", {"almanac": almanac})
	ctx.emit(&"notice", ["g03.demand.done", {"uid": uid, "kind": kind}])
	H.kept_first(ctx)
	return {"ok": true, "err": "", "success": true}

static func delay(ctx: CardCtx, uid: String) -> Dictionary:
	var err := H.open_error(ctx, uid)
	if err != "": return H.error(err)
	if str(CardPiles.def_of(ctx, uid).get("type", "")) != "demand": return H.error("not_allowed")
	var row := _ensure(ctx, uid)
	var cfg := ctx.rules("demand_rules")
	var delay_cfg: Dictionary = cfg.get("delay", {})
	if int(row["delays"]) >= int(delay_cfg.get("max", 1)): return H.error("not_allowed")
	row["delays"] = int(row["delays"]) + 1
	row["due_abs_day"] = int(row["due_abs_day"]) + int(delay_cfg.get("days", 3))
	row["tier"] = mini(int(cfg.get("max_tier", 3)), int(row["tier"]) + int(delay_cfg.get("tier_up", 1)))
	ctx.emit(&"card_updated", [uid])
	H.kept_first(ctx)
	return {"ok": true, "err": "", "days_left": days_left(ctx, uid), "tier": int(row["tier"])}

static func days_left(ctx: CardCtx, uid: String) -> int:
	var row := _peek(ctx, uid)
	if row.is_empty():
		var c := CardPiles.card(ctx, uid)
		if str(CardPiles.def_of(ctx, uid).get("type", "")) != "demand": return -1
		return maxi(0, int(c.get("dealt_abs_day", 0)) + int(CardPiles.def_of(ctx, uid).get("deadline_days", ctx.rules("demand_rules").get("deadline_days", 7))) - ctx.abs_day())
	var settled := int(H.peek(ctx).get("demand", {}).get("settled_abs_day", -1)) == ctx.abs_day()
	return maxi(0, int(row["due_abs_day"]) - ctx.abs_day() - (1 if settled else 0))

static func on_settle(ctx: CardCtx) -> void:
	var demand: Dictionary = H.state(ctx)["demand"]
	if int(demand.get("settled_abs_day", -1)) == ctx.abs_day(): return
	demand["settled_abs_day"] = ctx.abs_day()
	var uids := CardPiles.list(ctx, &"demands")
	uids.sort()
	for uid in uids:
		var row := _ensure(ctx, uid)
		if bool(row.get("closed", false)) or int(row["due_abs_day"]) > ctx.abs_day() + 1: continue
		var d := CardPiles.def_of(ctx, uid)
		var fail: Array = d.get("on_fail", ctx.rules("demand_rules").get("fail", {}).get("t%d" % int(row["tier"]), []))
		ctx.run(fail, uid + "/on_fail")
		row["closed"] = true
		CardFirsts.mark(ctx, &"demand_fail", {"uid": uid, "kind": str(row["kind"])})
		H.card_state(ctx, uid)["placed"] = {}
		CardPiles.resolve(ctx, uid, &"expired")
		ctx.emit(&"notice", ["g03.demand.failed", {"uid": uid, "kind": str(row["kind"]), "tier": int(row["tier"])}])
	CardRulesInstall.contact_hook(ctx, "settle")
	CardDossier.clear_new(ctx)
	H.kept_first(ctx)

static func modes(ctx: CardCtx, uid: String) -> Array:
	var d := CardPiles.def_of(ctx, uid)
	var kind := str(d.get("kind", ""))
	var resolve: Dictionary = d.get("resolve", {})
	var result: Array = []
	if kind in ["money", "goods"]: result.append({"id": "pay"})
	if resolve.has("haggle"): result.append({"id": "haggle", "check": resolve["haggle"]})
	if resolve.has("substitute"): result.append({"id": "substitute"})
	if resolve.has("fabricate"): result.append({"id": "fabricate", "check": resolve["fabricate"]})
	if kind == "people": result.append({"id": "send_person"})
	if kind == "info": result.append({"id": "inform"})
	return result

static func slots_for(ctx: CardCtx, uid: String) -> Array:
	var d := CardPiles.def_of(ctx, uid)
	var mode := str(_peek(ctx, uid).get("mode", H.card_peek(ctx, uid).get("choice", "")))
	if mode == "substitute": return []
	var resolve: Dictionary = d.get("resolve", {})
	if mode == "haggle": return resolve.get("haggle", {}).get("slots", [])
	if mode == "fabricate":
		var cfg: Dictionary = resolve.get("fabricate", {})
		return cfg.get("slots", [{"id": "fabricator", "accepts": ["self", "contact"], "attr": str(cfg.get("attr", "nerve")), "required": true}])
	var result: Array = (d.get("slots", []) as Array).duplicate(true)
	for slot in result:
		if mode == "pay" and str(d.get("kind", "")) == "money" and (slot.get("accepts", []) as Array).has("money"): slot["pay"] = true
	return result

static func check_for(ctx: CardCtx, uid: String) -> Dictionary:
	var mode := str(_peek(ctx, uid).get("mode", ""))
	return CardPiles.def_of(ctx, uid).get("resolve", {}).get(mode, {}) if mode in ["haggle", "fabricate"] else {}

static func select_mode(ctx: CardCtx, uid: String, mode: String) -> void:
	_ensure(ctx, uid)["mode"] = mode

static func tier_of(ctx: CardCtx, uid: String) -> int:
	return int(_peek(ctx, uid).get("tier", CardPiles.def_of(ctx, uid).get("tier", 0)))

static func _peek(ctx: CardCtx, uid: String) -> Dictionary:
	return H.peek(ctx).get("demand", {}).get("issued", {}).get(uid, {})

static func _ensure(ctx: CardCtx, uid: String) -> Dictionary:
	var issued: Dictionary = H.state(ctx)["demand"]["issued"]
	if not issued.has(uid):
		var d := CardPiles.def_of(ctx, uid)
		issued[uid] = {"due_abs_day": int(CardPiles.card(ctx, uid).get("dealt_abs_day", ctx.abs_day())) + int(d.get("deadline_days", ctx.rules("demand_rules").get("deadline_days", 7))), "tier": int(d.get("tier", 0)), "kind": str(d.get("kind", "")), "delays": 0, "mode": "", "amount": int(d.get("resolve", {}).get("money", {}).get("amount", 0)), "closed": false}
	return issued[uid]

static func amount(ctx: CardCtx, uid: String) -> int:
	var row := _peek(ctx, uid)
	var mode := str(row.get("mode", H.card_peek(ctx, uid).get("choice", "")))
	return _money_due(ctx, uid, mode)

static func _money_due(ctx: CardCtx, uid: String, mode: String) -> int:
	var d := CardPiles.def_of(ctx, uid)
	if str(d.get("type", "")) != "demand": return 0
	var row := _peek(ctx, uid)
	if bool(row.get("closed", false)) and row.has("paid_amount"): return int(row["paid_amount"])
	var issued_amount := int(row.get("amount", d.get("resolve", {}).get("money", {}).get("amount", 0)))
	if mode == "substitute": return int(d.get("resolve", {}).get("substitute", {}).get("money", 0))
	if mode in ["", "pay"] and str(d.get("kind", "")) == "money": return issued_amount
	if mode == "haggle" and str(d.get("kind", "")) == "money":
		var target := maxi(0, tier_of(ctx, uid) - int(d.get("resolve", {}).get("haggle", {}).get("tier_down", 1)))
		for id in ctx.db.ids_of(&"demand"):
			var candidate := ctx.db.def(id)
			if str(candidate.get("kind", "")) == "money" and int(candidate.get("tier", 0)) == target and candidate.get("era", []) == d.get("era", []):
				return int(candidate.get("resolve", {}).get("money", {}).get("amount", issued_amount))
		# TODO(design): With no lower-tier definition, retain the original visible amount.
		return issued_amount
	return 0

static func _sources(ctx: CardCtx, uid: String) -> Array:
	var sources: Array = []
	for slot in CardSlots.slots_of(ctx, uid):
		sources.append_array(H.card_peek(ctx, uid).get("placed", {}).get(str(slot["id"]), []))
	return sources

static func _count(sources: Array, kind: String) -> int:
	var n := 0
	for source in sources:
		var source_kind := str(source.get("kind", ""))
		if source_kind == kind or (kind == "person" and source_kind in ["self", "contact"]): n += 1
	return n

static func _finish_sources(ctx: CardCtx, uid: String, mode: String, sources: Array) -> void:
	var resolve: Dictionary = CardPiles.def_of(ctx, uid).get("resolve", {})
	for source in sources:
		var kind := str(source.get("kind", ""))
		if mode == "pay" and kind == "item": CardShelf.remove(ctx, str(source["item"]), "g03.reason.demand")
		if mode == "inform" and kind == "news":
			var news_uid := str(source["uid"])
			ctx.run(CardPiles.def_of(ctx, news_uid).get("effects", {}).get("on_inform", []), news_uid + "/on_inform")
			CardPiles.resolve(ctx, news_uid, &"informed")
		if mode == "send_person" and kind in ["self", "contact"]:
			var person := H.person(ctx, source)
			var cfg: Dictionary = resolve.get("people", {})
			ctx.run([{"op": "person_state", "person": person, "state": "away", "days": int(cfg.get("away_days", 7))}], uid + "/send_person")
			H.person_row(ctx, person)["demand_return"] = cfg.get("return_check", {"attr": "nerve", "need": 1}).duplicate(true)

static func return_people(ctx: CardCtx) -> void:
	var persons: Dictionary = H.state(ctx)["persons"]
	var ids := persons.keys()
	ids.sort()
	for person in ids:
		var row: Dictionary = persons[person]
		if int(row.get("until_abs_day", -1)) < 0 or int(row["until_abs_day"]) > ctx.abs_day(): continue
		row["state"] = "ok"
		row["until_abs_day"] = -1
		if not row.has("demand_return"): continue
		var cfg: Dictionary = row["demand_return"]
		row.erase("demand_return")
		if not ctx.db.has("ev.any.demand_return"): continue
		var uid := CardPiles.spawn(ctx, "ev.any.demand_return", &"hand", {"vars": {"person": str(person)}})
		ctx.run(CardPiles.def_of(ctx, uid).get("effects", {}).get("on_deal", []), uid + "/on_deal")
		CardFirsts.mark(ctx, &"demand_people_return", {"uid": uid, "person": str(person)})
		var faces := CardCoins.toss(ctx, uid, 0, CardMeters.attr(ctx, str(person), StringName(str(cfg.get("attr", "nerve")))))
		H.state(ctx)["attempts"][uid] = 1
		var success := faces.count(true) >= int(cfg.get("need", 1))
		ctx.emit(&"coins_tossed", [uid, faces, int(cfg.get("need", 1)), success])
		var branch := "on_success" if success else "on_fail"
		ctx.run(CardPiles.def_of(ctx, uid).get("check", {}).get(branch, []), uid + "/check/" + branch)
		if not success: ctx.run([{"op": "person_state", "person": str(person), "state": "gone"}], uid + "/not_back")
		CardPiles.resolve(ctx, uid, &"resolved")
