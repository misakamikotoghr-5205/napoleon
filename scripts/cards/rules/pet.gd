# 店里的猫（K18，§九.7）。不新增区、命名空间、效果或 class_name。
# 旗标在 rules.flags；计数在 rules.pet。没留过猫时不写状态、不掷随机。
# 眼力是每天多一次鉴定观察，不是永久属性。米货发霉只在猫住过又走丢之后。
extends RefCounted

const ARRIVE := "ev.1938.cat_arrive"
const FIND := "ev.1938.find_cat"
const H = preload("res://scripts/cards/rules/rules_helpers.gd")
const E = preload("res://scripts/cards/economy/economy_support.gd")


static func install(ctx: CardCtx) -> void:
	ctx.mods.register(&"view_section", _view, "G03")
	ctx.hooks.on(&"day_start", _morning, 55, "G03")
	ctx.hooks.on(&"card_resolved", _resolved, 25, "G03")
	ctx.hooks.on(&"settle", on_night, 35, "G03")


static func home(ctx: CardCtx) -> bool:
	var flags: Dictionary = H.peek(ctx).get("flags", {})
	return bool(flags.get("pet_home", false)) and not bool(flags.get("pet_lost", false))


## 鉴定参数在返回前调用。猫在且今天还有一眼时，找不同的墨次或吹银元的次数 +1，并消耗这一眼。
static func apply_look(ctx: CardCtx, params: Dictionary) -> Dictionary:
	if not home(ctx):
		return params
	var bag: Dictionary = H.peek(ctx).get("pet", {})
	if int(bag.get("look_left", 0)) <= 0:
		return params
	var kind := str(params.get("kind", ""))
	var used := false
	if kind == "spot" and typeof(params.get("ink")) == TYPE_INT:
		params["ink"] = int(params["ink"]) + 1
		used = true
	elif kind == "coin_ring" and typeof(params.get("tries")) == TYPE_INT:
		params["tries"] = int(params["tries"]) + 1
		used = true
	if not used:
		return params
	_bag(ctx)["look_left"] = int(bag.get("look_left", 0)) - 1
	return params


## 夜里：在店则陪一晚，住满夜数后可能走丢；走丢之后米货掉成色，找猫牌不在则再排。
static func on_night(ctx: CardCtx, _args: Dictionary = {}) -> void:
	if home(ctx):
		var bag := _bag(ctx)
		bag["nights"] = int(bag.get("nights", 0)) + 1
		var gain := int(ctx.rules("pet").get("conscience_night", 1))
		if gain != 0:
			CardMeters.add(ctx, &"conscience", gain, "K18:settle/pet")
		var need := int(ctx.rules("pet").get("min_nights", 3))
		if int(bag["nights"]) >= need and _wander_roll(ctx):
			_lose(ctx, bag)
		return
	if not bool(H.peek(ctx).get("pet", {}).get("had", false)):
		return
	if not bool(H.peek(ctx).get("flags", {}).get("pet_lost", false)):
		return
	_mold(ctx)
	var lost := _bag(ctx)
	if ctx.abs_day() < int(lost.get("find_due", 1 << 30)):
		return
	if _find_pending(ctx):
		return
	var retry := maxi(1, int(ctx.rules("pet").get("retry_days", 3)))
	_queue_find(ctx, retry)
	lost["find_due"] = ctx.abs_day() + retry


static func _morning(ctx: CardCtx, _args: Dictionary) -> void:
	if not home(ctx):
		return
	var bag := _bag(ctx)
	if int(bag.get("look_day", -1)) == ctx.abs_day():
		return
	bag["look_day"] = ctx.abs_day()
	bag["look_left"] = int(ctx.rules("pet").get("looks_per_day", 1))


static func _resolved(ctx: CardCtx, args: Dictionary) -> void:
	var uid := str(args.get("uid", ""))
	var def_id := str(CardPiles.card(ctx, uid).get("def", ""))
	if def_id != ARRIVE and def_id != FIND:
		return
	if not home(ctx):
		return
	var bag := _bag(ctx)
	bag["had"] = true
	bag["nights"] = 0
	bag["find_due"] = -1
	if int(bag.get("look_day", -1)) != ctx.abs_day():
		bag["look_day"] = ctx.abs_day()
		bag["look_left"] = int(ctx.rules("pet").get("looks_per_day", 1))
	CardFirsts.mark(ctx, &"pet", {"uid": uid, "def": def_id})


static func _view(ctx: CardCtx, _args: Dictionary) -> Dictionary:
	var flags: Dictionary = H.peek(ctx).get("flags", {})
	var had := bool(H.peek(ctx).get("pet", {}).get("had", false))
	var lost := bool(flags.get("pet_lost", false))
	if not had and not home(ctx) and not lost:
		return {}
	return {"pet": {"show": true, "home": home(ctx), "lost": lost}}


static func _bag(ctx: CardCtx) -> Dictionary:
	var rules := H.state(ctx)
	if typeof(rules.get("pet")) != TYPE_DICTIONARY:
		rules["pet"] = {"look_left": 0, "look_day": -1, "had": false, "find_due": -1, "nights": 0}
	return rules["pet"]


static func _wander_roll(ctx: CardCtx) -> bool:
	var den := maxi(1, int(ctx.rules("pet").get("wander_den", 12)))
	var num := int(ctx.rules("pet").get("wander_num", 1))
	return int(ctx.draw("c.pet.wander", [ctx.abs_day()]) * float(den)) < num


static func _lose(ctx: CardCtx, bag: Dictionary) -> void:
	ctx.run([
		{"op": "flag", "key": "pet_lost"},
		{"op": "flag_clear", "key": "pet_home"},
	], "K18:wander")
	_queue_find(ctx, 1)
	bag["find_due"] = ctx.abs_day() + 1


## 找猫牌的入队效果写在进店牌的 on_done 上（只有走丢时才跑）。目标系统不读事件牌。
static func _queue_find(ctx: CardCtx, in_days: int) -> void:
	var fx: Array = ctx.db.def(ARRIVE).get("effects", {}).get("on_done", [])
	fx = fx.duplicate(true)
	if fx.is_empty():
		fx = [{"op": "add_card", "card": FIND, "to": "queue", "in_days": in_days}]
	else:
		for row in fx:
			if typeof(row) == TYPE_DICTIONARY and str(row.get("op", "")) == "add_card":
				row["in_days"] = in_days
	ctx.run(fx, "K18:wander/find")


static func _mold(ctx: CardCtx) -> void:
	var drop := int(ctx.rules("pet").get("mold_permille", 50))
	if drop <= 0:
		return
	for id in CardShelf.items(ctx):
		var meta := E.meta(ctx, id)
		if meta.is_empty() or str(meta.get("cat", "")) != "rice":
			continue
		meta["condition_permille"] = maxi(0, int(meta.get("condition_permille", 1000)) - drop)


static func _find_pending(ctx: CardCtx) -> bool:
	for uid in CardPiles.list(ctx, &"hand"):
		if str(CardPiles.card(ctx, uid).get("def", "")) == FIND:
			return true
	for uid in CardPiles.list(ctx, &"kept"):
		if str(CardPiles.card(ctx, uid).get("def", "")) == FIND:
			return true
	for row in ctx.state.ns("core").get("queue", []):
		if typeof(row) == TYPE_DICTIONARY and str(row.get("def", "")) == FIND:
			return true
	return false
