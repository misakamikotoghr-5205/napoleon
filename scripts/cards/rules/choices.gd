# 普通选项和条子的保留办法；带检定的选择只记录，不提前结算。
# 第一次读消息只执行一次，读完保守留在手牌供留牌或交消息。
class_name CardChoices
extends RefCounted
const H = preload("res://scripts/cards/rules/rules_helpers.gd")
const Scare = preload("res://scripts/cards/weapon/scare.gd")

static func options(ctx: CardCtx, uid: String) -> Array:
	var result: Array = []
	for choice in definitions(ctx, uid):
		var enabled := H.open_error(ctx, uid) == "" and ctx.test(choice.get("conditions", {}))
		var reason := "" if enabled else "g03.reason.condition"
		if not H.afford(ctx, int(choice.get("cost", {}).get("money", 0)) + (CardSlots.reserved_money(ctx) + CardSlots.wheel_money(ctx))):
			enabled = false
			reason = "g03.reason.money"
		result.append({"id": str(choice["id"]), "enabled": enabled, "reason_key": reason, "has_check": choice.has("check")})
	return result

static func choose(ctx: CardCtx, uid: String, choice_id: String) -> Dictionary:
	var err := H.open_error(ctx, uid)
	if err != "": return H.error(err)
	if CardPiles.zone_of(ctx, uid) not in [&"hand", &"demands"]: return H.error("not_allowed")
	var choice := definition(ctx, uid, choice_id)
	if choice.is_empty(): return H.error("no_such_choice")
	if not ctx.test(choice.get("conditions", {})): return H.error("cond_failed")
	var selected := str(H.card_peek(ctx, uid).get("choice", ""))
	if selected == choice_id: return {"ok": true, "err": "", "needs_slots": choice.has("check") or str(CardPiles.def_of(ctx, uid).get("type", "")) == "demand"}
	var cost := int(choice.get("cost", {}).get("money", 0))
	if not H.afford(ctx, cost + (CardSlots.reserved_money(ctx) + CardSlots.wheel_money(ctx))): return H.error("insufficient_money")
	H.pay(ctx, cost, uid + "/choices/" + choice_id + "/cost", "g03.reason.money")
	var row := H.card_state(ctx, uid)
	row["choice"] = choice_id
	row["placed"] = {}
	CardFirsts.mark(ctx, &"choice", {"uid": uid, "def": str(CardPiles.card(ctx, uid).get("def", ""))})
	if str(CardPiles.def_of(ctx, uid).get("type", "")) == "demand":
		CardDemands.select_mode(ctx, uid, choice_id)
		return {"ok": true, "err": "", "needs_slots": true}
	if choice.has("check"):
		CardFirsts.mark(ctx, &"slots", {"uid": uid})
		CardFirsts.mark(ctx, &"coins", {"uid": uid})
		ctx.emit(&"card_updated", [uid])
		return {"ok": true, "err": "", "needs_slots": true}
	ctx.run(choice.get("effects", []), uid + "/choices/" + choice_id + "/effects")
	CardPiles.resolve(ctx, uid, &"resolved", {"almanac": choice.get("almanac", [])})
	H.kept_first(ctx)
	return {"ok": true, "err": "", "needs_slots": false}

static func read(ctx: CardCtx, uid: String) -> Dictionary:
	var err := H.open_error(ctx, uid)
	if err != "": return H.error(err)
	var d := CardPiles.def_of(ctx, uid)
	if str(d.get("type", "")) not in ["news", "pawn_ticket"]: return H.error("not_allowed")
	var row := H.card_state(ctx, uid)
	if not bool(row["read"]):
		row["read"] = true
		ctx.run(d.get("effects", {}).get("on_read", []), uid + "/on_read")
		ctx.emit(&"card_updated", [uid])
	# TODO(design): Read cards stay in hand until an explicit keep/discard action.
	H.kept_first(ctx)
	return {"ok": true, "err": ""}

static func definitions(ctx: CardCtx, uid: String) -> Array:
	if str(CardPiles.def_of(ctx, uid).get("type", "")) == "demand": return CardDemands.modes(ctx, uid)
	return Scare.attach(ctx, uid, CardPiles.def_of(ctx, uid).get("choices", []))

static func definition(ctx: CardCtx, uid: String, choice_id: String) -> Dictionary:
	for choice in definitions(ctx, uid):
		if str(choice.get("id", "")) == choice_id: return choice
	return {}
