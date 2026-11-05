# 家当抵押、赎回、月底利息与能力修正；只写 ladder 命名空间。
# G06；合同 §4.7.11、§7.3、§7.9。钱款统一交给 economy 的 op。
class_name CardMortgage
extends RefCounted


static func mortgage(ctx: CardCtx, estate_id: String) -> Dictionary:
	var entry: Dictionary = _entry(ctx, estate_id)
	if entry.is_empty() or str(entry.get("status", "")) != "held":
		return {"ok": false, "err": CardIds.ERR_ESTATE_STATE}
	var amount: int = _value(ctx, estate_id)
	entry.merge({"status": "mortgaged", "since_abs_day": ctx.abs_day(), "principal": amount}, true)
	ctx.run([{"op": "money", "delta": amount, "reason": "g06.reason.mortgage"}], estate_id)
	CardFirsts.mark(ctx, &"mortgage", {})
	return {"ok": true, "err": "", "money": amount}


static func redeem(ctx: CardCtx, estate_id: String) -> Dictionary:
	var entry: Dictionary = _entry(ctx, estate_id)
	if entry.is_empty() or str(entry.get("status", "")) != "mortgaged":
		return {"ok": false, "err": CardIds.ERR_ESTATE_STATE}
	var stage: int = int(ctx.state.ns("loop").get("stage", 0))
	var interest: int = 0 if int(entry.get("interest_paid_stage", -1)) == stage else _interest(ctx, estate_id)
	var amount: int = int(entry.get("principal", 0)) + interest
	if not ctx.test({"money_gte": amount}):
		return {"ok": false, "err": CardIds.ERR_INSUFFICIENT_MONEY}
	ctx.run([{"op": "pay", "amount": amount, "payee": estate_id,
		"reason": "g06.reason.redeem_estate", "short": "fail"}], estate_id)
	entry.merge({"status": "held", "since_abs_day": ctx.abs_day(), "principal": 0}, true)
	entry.erase("interest_paid_stage")
	CardFirsts.mark(ctx, &"mortgage", {})
	return {"ok": true, "err": "", "money": amount}


static func on_month_close(ctx: CardCtx) -> void:
	var ladder: Dictionary = ctx.state.ns("ladder")
	var stage: int = int(ctx.state.ns("loop").get("stage", 0))
	if not CardShortLadder.view(ctx).is_empty():
		return
	for id in _ids(ctx):
		var entry: Dictionary = _entry(ctx, id)
		if str(entry.get("status", "")) != "mortgaged":
			continue
		if int(entry.get("interest_paid_stage", -1)) != stage:
			var interest: int = _interest(ctx, id)
			# 标记在 pay 之前，面板恢复或重复结账不会重复索取。
			entry["interest_paid_stage"] = stage
			ctx.run([{"op": "pay", "amount": interest, "payee": id,
				"reason": "g06.reason.interest", "short": "ladder"}], id + "/interest")
			ctx.emit(&"notice", ["g06.month.interest", {"estate": id, "money": interest}])
			if not CardShortLadder.view(ctx).is_empty():
				return
		if bool(ctx.db.def(id).get("lose_if_unredeemed", false)):
			entry["status"] = "lost"
			ctx.emit(&"notice", ["g06.month.shop_lost", {"estate": id}])
			CardStreet.enter(ctx)
	ladder["month_closed_stage"] = stage


static func view(ctx: CardCtx) -> Array:
	var out: Array = []
	for id in _ids(ctx):
		var entry: Dictionary = _entry(ctx, id)
		var status: String = str(entry.get("status", "held"))
		out.append({"id": id, "status": status,
			"money": int(entry.get("principal", 0)) if status == "mortgaged" else _value(ctx, id),
			"interest_money": _interest(ctx, id) if status == "mortgaged" else _value(ctx, id)
				* int(ctx.db.def(id).get("interest_pct_month", 0)) / 100})
	return out


static func _stage_start(ctx: CardCtx, _args: Dictionary) -> void:
	var ladder: Dictionary = ctx.state.ns("ladder")
	if not ladder.has("estates"):
		ladder["estates"] = {}
	for id in _ids(ctx):
		if not (ladder["estates"] as Dictionary).has(id):
			ladder["estates"][id] = {"status": "held", "since_abs_day": ctx.abs_day(), "principal": 0}
	if not ladder.has("street"):
		ladder["street"] = {"since_abs_day": 0}
	if not ladder.has("short"):
		ladder["short"] = {}
	if str(_entry(ctx, "es.shopfront").get("status", "")) == "lost" \
			and int(ladder.get("street", {}).get("since_abs_day", 0)) > 0:
		# 跨关恢复模式，不重新进入或重置街头起算日；没收铺面不会触发街头。
		CardDayLoop.set_mode(ctx, &"street")


static func _entry(ctx: CardCtx, id: String) -> Dictionary:
	return ctx.state.ns("ladder").get("estates", {}).get(id, {})


static func _ids(ctx: CardCtx) -> Array[String]:
	var ids: Array[String] = []
	ids.assign(Array(ctx.db.ids_of(&"estate")))
	ids.sort_custom(func(a: String, b: String) -> bool:
		var ao: int = int(ctx.db.def(a).get("order", 0))
		var bo: int = int(ctx.db.def(b).get("order", 0))
		return ao < bo if ao != bo else a < b)
	return ids


static func _value(ctx: CardCtx, id: String) -> int:
	return int(ctx.db.def(id).get("mortgage_value", 0)) * int(ctx.state.ns("econ").get("price_index", 100)) / 100


static func _interest(ctx: CardCtx, id: String) -> int:
	return int(_entry(ctx, id).get("principal", 0)) * int(ctx.db.def(id).get("interest_pct_month", 0)) / 100


static func _modifiers(ctx: CardCtx) -> Array:
	var out: Array = []
	for id in _ids(ctx):
		if str(_entry(ctx, id).get("status", "")) == "mortgaged":
			out.append_array(ctx.db.def(id).get("while_mortgaged", []))
	return out


static func _seize(ctx: CardCtx, pick: String) -> void:
	var candidates: Array[String] = []
	for id in _ids(ctx):
		if str(_entry(ctx, id).get("status", "")) != "lost":
			candidates.append(id)
	if candidates.is_empty():
		return
	var chosen: String = pick
	if pick in ["best", "worst"]:
		candidates.sort_custom(func(a: String, b: String) -> bool:
			return _value(ctx, a) < _value(ctx, b) if _value(ctx, a) != _value(ctx, b) else a < b)
		chosen = candidates.back() if pick == "best" else candidates.front()
	if candidates.has(chosen):
		_entry(ctx, chosen)["status"] = "lost"
		ctx.emit(&"notice", ["g06.reason.seize", {"estate": chosen}])
