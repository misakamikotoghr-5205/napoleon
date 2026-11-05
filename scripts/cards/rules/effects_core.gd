# G03 的效果分发；所有嵌套效果保留来源路径，不直接写别人的命名空间。
# 随机检定只掷看得见的铜钱，人物和人脉状态全部可存档。
class_name CardEffectsCore
extends RefCounted
const H = preload("res://scripts/cards/rules/rules_helpers.gd")

static func run_op(ctx: CardCtx, eff: Dictionary, source: String, op: StringName) -> void:
	var r := H.state(ctx)
	match op:
		&"rep", &"heat", &"conscience":
			if eff.has("tier"):
				CardMeters.bump_tier(ctx, op, int(eff["tier"]), source)
			else:
				CardMeters.add(ctx, op, int(eff.get("delta", 0)), source)
		&"attr":
			CardMeters.add_attr(ctx, str(eff["who"]), StringName(eff["attr"]), int(eff["delta"]), int(eff.get("days", 0)), source)
		&"flag":
			r["flags"][eff["key"]] = eff.get("value", true)
		&"flag_clear":
			(r["flags"] as Dictionary).erase(eff["key"])
		&"counter":
			r["counters"][eff["key"]] = int(r["counters"].get(eff["key"], 0)) + int(eff["delta"])
		&"story":
			r["story"][eff["node"]] = eff["outcome"]
			r["flags"]["story." + str(eff["node"])] = eff["outcome"]
		&"dossier": CardDossier.add(ctx, str(eff["frag"]))
		&"dossier_gap": CardDossier.gap(ctx, str(eff["frag"]))
		&"notice": ctx.emit(&"notice", [str(eff["key"]), (eff.get("args", {}) as Dictionary).duplicate(true)])
		&"if":
			var branch := "then" if ctx.test(eff["cond"]) else "else"
			ctx.run(eff.get(branch, []), source + "/" + branch)
		&"coin_check": _coin_check(ctx, eff, source)
		&"person_state": set_person(ctx, str(eff["person"]), str(eff["state"]), int(eff.get("days", 0)))
		&"contact_gain": gain_contact(ctx, str(eff["person"]))
		&"contact_lose": lose_contact(ctx, str(eff["person"]))
		&"demand_tier": r["demand"]["tier_bias"] = int(r["demand"].get("tier_bias", 0)) + int(eff["delta"])
		&"kept_risk": CardKeptRules.run_risk(ctx, eff["tags_any"], source)

static func _coin_check(ctx: CardCtx, eff: Dictionary, source: String) -> void:
	var attempts: Dictionary = H.state(ctx)["attempts"]
	var attempt := int(attempts.get(source, 0))
	attempts[source] = attempt + 1
	var faces := CardCoins.toss(ctx, source, attempt, int(eff["coins"]))
	var success := faces.count(true) >= int(eff["need"])
	ctx.emit(&"coins_tossed", [source.get_slice("/", 0), faces, int(eff["need"]), success])
	var branch := "then" if success else "else"
	ctx.run(eff.get(branch, []), source + "/" + branch)

static func set_person(ctx: CardCtx, person: String, status: String, days: int) -> void:
	var row := H.person_row(ctx, person)
	row["state"] = status
	row["until_abs_day"] = ctx.abs_day() + days if days > 0 else -1
	if status in ["hurt", "jailed", "away", "gone"]:
		CardFirsts.mark(ctx, &"person_state", {"person": person})
	ctx.emit(&"view_changed", [PackedStringArray(["persons"])])

static func gain_contact(ctx: CardCtx, person: String) -> void:
	if H.contact_uid(ctx, person) != "" or not ctx.db.has("ct." + person):
		return
	for pending in CardPiles.list(ctx, &"pending"):
		if str(CardPiles.def_of(ctx, pending).get("person", "")) == person:
			return
	var cap := CardPiles.cap(ctx, &"contacts")
	var full := cap >= 0 and CardPiles.list(ctx, &"contacts").size() >= cap
	var uid := CardPiles.spawn(ctx, "ct." + person, &"pending" if full else &"contacts")
	H.person_row(ctx, person)
	CardFirsts.mark(ctx, &"contact", {"uid": uid, "person": person})
	if full:
		H.state(ctx)["contact_pending"] = uid
		CardFirsts.mark(ctx, &"contacts_full", {"uid": uid})
		CardDayLoop.request_panel(ctx, &"contacts_full", {"new_uid": uid})

static func lose_contact(ctx: CardCtx, person: String) -> void:
	var uid := H.contact_uid(ctx, person)
	if uid != "":
		CardPiles.resolve(ctx, uid, &"resolved")

static func release_contact(ctx: CardCtx, uid: String) -> Dictionary:
	if CardPiles.zone_of(ctx, uid) not in [&"contacts", &"pending"]:
		return H.error("not_allowed")
	if str(CardPiles.def_of(ctx, uid).get("type", "")) != "contact":
		return H.error("not_allowed")
	CardPiles.resolve(ctx, uid, &"resolved")
	var r := H.state(ctx)
	var pending := str(r.get("contact_pending", ""))
	if pending != uid and CardPiles.zone_of(ctx, pending) == &"pending":
		CardPiles.move(ctx, pending, &"contacts")
	r.erase("contact_pending")
	return {"ok": true, "err": ""}
