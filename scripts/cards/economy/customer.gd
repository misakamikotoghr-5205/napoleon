# 客人报价回应和耐心只存隐藏会话，界面仅收到回话及钱数。
# G04；最多五轮，无剩余分钟数泄漏。
class_name CardCustomer
extends RefCounted
const E = preload("res://scripts/cards/economy/economy_support.gd")

static func reply(ctx: CardCtx, uid: String, price: int) -> Dictionary:
	var s := E.session(ctx, uid)
	if s.is_empty():
		return {"reply": "leave", "price": 0}
	var buying: bool = str(s["intent"]) == "buy"
	var enough: bool = price <= int(s["floor"]) if buying else price >= int(s["floor"])
	var draw: float = ctx.draw("c.cust.reply", [ctx.abs_day(), uid, int(s["round"])])
	if enough:
		return {"reply": "accept", "price": price}
	if int(s["round"]) >= int(ctx.rules("economy").get("max_rounds", 5)) or int(s["patience"]) <= 0:
		return {"reply": "leave", "price": 0}
	var target: int = int(s["floor"])
	var counter: int = (target + price) / 2
	if buying:
		counter = mini(target, counter)
	else:
		counter = maxi(target, counter)
	# A refusal can terminate a harsh negotiation without exposing the hidden limit.
	return {"reply": "leave", "price": 0} if draw < 0.1 else {"reply": "counter", "price": maxi(1, counter)}

static func spend_patience(ctx: CardCtx, uid: String, minutes: int) -> StringName:
	var s := E.session(ctx, uid)
	if s.is_empty():
		return &""
	var pct: int = maxi(1, ctx.mods.pct(ctx, &"patience_pct", {"uid": uid}))
	var spent: int = (maxi(0, minutes) * 100 + pct - 1) / pct
	s["patience"] = maxi(0, int(s["patience"]) - spent)
	if int(s["patience"]) > 0:
		return &""
	if str(s.get("impatience", "leave")) == "raise":
		# TODO(design): a single raise uses ten percent, then renews one offer's patience.
		if not bool(s.get("raised", false)):
			s["raised"] = true
			s["asking"] = maxi(1, int(s["asking"]) * (90 if str(s["intent"]) == "buy" else 110) / 100)
			s["floor"] = maxi(1, int(s["floor"]) * (90 if str(s["intent"]) == "buy" else 110) / 100)
			s["patience"] = int(ctx.rules("economy").get("patience", {}).get("offer_min", 10)) + 1
			return &"raise"
	return &"leave"
