# G03 内部状态与查询辅助；查询只读，修改入口才建立默认字典。
# 仅写 rules 命名空间，钱和牌堆通过其公开接口处理。
extends RefCounted

static func state(ctx: CardCtx) -> Dictionary:
	var r := ctx.state.ns("rules")
	for key in ["meters", "attrs", "flags", "counters", "story", "persons", "dossier", "cards", "attempts"]:
		if not r.has(key):
			r[key] = {}
	if not r.has("attr_mods"):
		r["attr_mods"] = []
	if not r.has("demand"):
		r["demand"] = {"tier_bias": 0, "issued": {}, "weeks": {}}
	return r

static func peek(ctx: CardCtx) -> Dictionary:
	return ctx.state.data.get("rules", {})

static func card_state(ctx: CardCtx, uid: String) -> Dictionary:
	var cards: Dictionary = state(ctx)["cards"]
	if not cards.has(uid):
		cards[uid] = {"placed": {}, "choice": "", "read": false}
	return cards[uid]

static func card_peek(ctx: CardCtx, uid: String) -> Dictionary:
	return peek(ctx).get("cards", {}).get(uid, {})

static func error(err: String) -> Dictionary:
	return {"ok": false, "err": err}

static func open_error(ctx: CardCtx, uid: String) -> String:
	var c := CardPiles.card(ctx, uid)
	if c.is_empty():
		return "unknown_uid"
	if not ["hand", "demands", "kept", "contacts"].has(str(c.get("zone", ""))):
		return "not_allowed"
	if str(c.get("status", "open")) != "open":
		return "already_resolved"
	return ""

static func person(ctx: CardCtx, source: Dictionary) -> String:
	if str(source.get("kind", "")) == "self":
		return "ruhua"
	return str(CardPiles.def_of(ctx, str(source.get("uid", ""))).get("person", ""))

static func person_row(ctx: CardCtx, person_id: String) -> Dictionary:
	var persons: Dictionary = state(ctx)["persons"]
	if not persons.has(person_id):
		persons[person_id] = {"state": "ok", "until_abs_day": -1, "used_abs_day": -1}
	return persons[person_id]

static func person_peek(ctx: CardCtx, person_id: String) -> Dictionary:
	return peek(ctx).get("persons", {}).get(person_id, {})

static func intersects(a: Array, b: Array) -> bool:
	for x in a:
		if b.has(x):
			return true
	return false

static func afford(ctx: CardCtx, amount: int) -> bool:
	return amount <= 0 or ctx.test({"money_gte": amount})

static func pay(ctx: CardCtx, amount: int, source: String, reason: String = "g03.reason.slot_money") -> void:
	if amount > 0:
		ctx.run([{"op": "pay", "amount": amount, "payee": "levy", "reason": reason, "short": "fail"}], source)

static func kept_first(ctx: CardCtx) -> void:
	for uid in CardPiles.list(ctx, &"kept"):
		var d := CardPiles.def_of(ctx, uid)
		if not (d.get("risk", []) as Array).is_empty():
			CardFirsts.mark(ctx, &"kept_risk", {"uid": uid, "def": str(d.get("id", ""))})
			return

static func contact_uid(ctx: CardCtx, person_id: String) -> String:
	for uid in CardPiles.list(ctx, &"contacts"):
		if str(CardPiles.def_of(ctx, uid).get("person", "")) == person_id:
			return uid
	return ""

static func attrs(ctx: CardCtx, who: String) -> Dictionary:
	var out := {}
	for attr_id in ["eye", "tongue", "pull", "nerve"]:
		out[attr_id] = CardMeters.attr(ctx, who, StringName(attr_id))
	return out
