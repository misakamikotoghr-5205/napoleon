# 命运模块只读辅助：年代、征兆、跨模块数值与香案资源预留。
# 不写其他命名空间；真实 G03/G04 合入后以公共接口为准。
extends RefCounted

static func era(ctx: CardCtx) -> String:
	return str(ctx.db.stage(int(ctx.state.ns("loop").get("stage", 0))).get("era", "1938"))

static func current(ctx: CardCtx, def: Dictionary) -> bool:
	var eras: Array = def.get("era", [])
	return eras.has(era(ctx)) or eras.has("*")

static func intersects(a: Array, b: Array) -> bool:
	for key in a:
		if b.has(key):
			return true
	return false

static func omens(def: Dictionary) -> Array:
	var out: Array = []
	for tag in def.get("tags", []):
		if str(tag).begins_with("omen_"):
			out.append(str(tag))
	return out

static func money(ctx: CardCtx) -> int:
	if ctx.ledger != null:
		return CardCurrency.money(ctx)
	return int(ctx.state.ns("econ").get("ledger", {}).get("accounts", {}).get("player", 0))

static func meter(ctx: CardCtx, key: StringName) -> int:
	return int(ctx.state.ns("rules").get("meters", {}).get(str(key), CardMeters.value(ctx, key)))

static func tier(ctx: CardCtx, key: StringName) -> int:
	var points := meter(ctx, key)
	var result := 0
	var tiers: Array = ctx.rules("meters").get(str(key), {}).get("tiers", [0, 20, 40, 60, 80])
	for i in range(tiers.size()):
		if points >= int(tiers[i]):
			result = i
	return clampi(result, 0, 4)

static func pay(ctx: CardCtx, amount: int, reason: String, source: String) -> void:
	if amount > 0:
		ctx.run([{"op": "pay", "amount": amount, "payee": reason, "reason": reason, "short": "fail"}], source)

static func reserved(ctx: CardCtx, resource_uid: String) -> bool:
	var wheels: Dictionary = ctx.state.ns("fate").get("wheels", {})
	var keys := wheels.keys()
	keys.sort()
	for key in keys:
		var row: Dictionary = wheels[key]
		if not row.get("result", {}).is_empty():
			continue
		if str(row.get("stake", "")) == resource_uid:
			return true
		for entry in row.get("incense", []):
			if str(entry.get("uid", "")) == resource_uid:
				return true
	var cards: Dictionary = ctx.state.ns("rules").get("cards", {})
	var core_cards: Dictionary = ctx.state.ns("core").get("cards", {})
	for uid in cards.keys():
		var c: Dictionary = core_cards.get(uid, {})
		if str(c.get("zone", "")) == "discard":
			continue
		var placements: Dictionary = cards[uid].get("placed", {})
		for slot in placements.keys():
			for entry in placements[slot]:
				if str(entry.get("uid", "")) == resource_uid:
					return true
	for zone in [&"hand", &"demands"]:
		for uid in CardPiles.list(ctx, zone):
			var placements: Dictionary = core_cards.get(uid, {}).get("placed", {})
			for slot in placements.keys():
				for entry in placements[slot]:
					if str(entry.get("uid", "")) == resource_uid:
						return true
	return false

static func person_ready(ctx: CardCtx, uid: String) -> bool:
	var person := str(CardPiles.def_of(ctx, uid).get("person", ""))
	var state: Dictionary = ctx.state.ns("rules").get("persons", {}).get(person, {})
	return person != "" and str(state.get("state", "ok")) == "ok" and int(state.get("used_abs_day", -1)) != ctx.abs_day()

static func reserved_money(ctx: CardCtx, exclude_wheel: String = "") -> int:
	var amount := 0
	var wheels: Dictionary = ctx.state.ns("fate").get("wheels", {})
	var keys := wheels.keys()
	keys.sort()
	for key in keys:
		var row: Dictionary = wheels[key]
		if str(key) == exclude_wheel or not row.get("result", {}).is_empty():
			continue
		for entry in row.get("incense", []):
			if str(entry.get("kind", "")) == "money":
				amount += int(entry.get("amount", 0))
	return amount

static func slot_money(ctx: CardCtx) -> int:
	var slots_script: Script = preload("res://scripts/cards/rules/slots.gd")
	return int(slots_script.call("reserved_money", ctx)) if slots_script.has_method("reserved_money") else 0

static func available_money(ctx: CardCtx, exclude_wheel: String = "") -> int:
	return maxi(0, money(ctx) - reserved_money(ctx, exclude_wheel) - slot_money(ctx))
