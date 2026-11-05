# 每日发牌：日程、钉签、队列、随机；只经登记的随机域，抽牌位置和已抽牌一起存档。
# 主人 G01；合同 §6.3、§7.4.6、§7.9、§7.10.11。project 用独立状态计算未来日，不改源状态。
class_name CardComposer
extends RefCounted


static func compose(ctx: CardCtx) -> PackedStringArray:
	var day := ctx.abs_day()
	var scheduled := ctx.mods.collect(ctx, &"scheduled_cards", {"abs_day": day})
	var pins := _pins(ctx, day)
	var defs: Array = scheduled.duplicate()
	defs.append_array(pins)
	defs.append_array(_take_queue(ctx, day))
	defs.append_array(_random_part(ctx, day, true, pins, defs))
	var uids := _spawn_batch(ctx, defs)
	var deals: Dictionary = ctx.state.ns("core").get("deals", {})
	deals[str(day)] = Array(uids)
	ctx.state.ns("core")["deals"] = deals
	_emit_deal(ctx, uids)
	return uids


static func extra_deal(ctx: CardCtx, pool: StringName, n: int) -> PackedStringArray:
	if not CardIds.POOLS.has(pool) or n <= 0:
		return PackedStringArray()
	var uids := _spawn_batch(ctx, _draw_pool(ctx, pool, n, ctx.abs_day(), true))
	_emit_deal(ctx, uids)
	return uids


## 随机部分的预测；提供者和条件读取到目标日，所有读写只作用于独立状态副本。
static func project(ctx: CardCtx, abs_day: int) -> PackedStringArray:
	var projected := CardCtx.new()
	projected.state = CardState.from_dict(ctx.state.to_dict())
	projected.db = ctx.db
	projected.mods = ctx.mods
	projected.conds = ctx.conds
	projected.ledger = ctx.ledger
	var loop := projected.state.ns("loop")
	loop["stage_day"] = int(loop.get("stage_day", 0)) + abs_day - ctx.abs_day()
	loop["abs_day"] = abs_day
	if abs_day > ctx.abs_day():
		loop["phase"] = "morning"
	var pins := _pins(projected, abs_day)
	var fixed := projected.mods.collect(projected, &"scheduled_cards", {"abs_day": abs_day})
	fixed.append_array(pins)
	for row in projected.state.ns("core").get("queue", []):
		if int(row.get("abs_day", -1)) == abs_day and row.has("def") and str(row.get("zone", "hand")) == "hand":
			fixed.append(str(row["def"]))
	return PackedStringArray(_random_part(projected, abs_day, false, pins, fixed))


static func night_offers(ctx: CardCtx) -> PackedStringArray:
	var n := _modified_count(ctx, &"night", int(ctx.rules("deal").get("night_offer", 3)), ctx.abs_day())
	return PackedStringArray(_draw_pool(ctx, &"night", n, ctx.abs_day(), true))


static func street_deal(ctx: CardCtx) -> PackedStringArray:
	var n := _modified_count(ctx, &"street", int(ctx.rules("deal").get("street_per_day", 3)), ctx.abs_day())
	return PackedStringArray(_draw_pool(ctx, &"street", n, ctx.abs_day(), true))


static func _modified_count(ctx: CardCtx, pool: StringName, n: int, day: int) -> int:
	return maxi(0, n + ctx.mods.sum_int(ctx, &"deal_count", {"type": pool, "abs_day": day}))


static func is_scripted_day(ctx: CardCtx) -> bool:
	var loop := ctx.state.ns("loop")
	var days: Array = ctx.rules("deal").get("scripted_days", {}).get(str(int(loop.get("stage", 0))), [])
	if not days.has(int(loop.get("stage_day", 0))):
		return false
	# Rogue v1 (RG5): a veteran opening plays the tutorial days as ordinary days. No provider = unchanged.
	return not ctx.mods.any_true(ctx, &"unscripted_day", {"stage": int(loop.get("stage", 0)),
		"stage_day": int(loop.get("stage_day", 0))})


static func _counts(ctx: CardCtx, day: int) -> Dictionary:
	if is_scripted_day(ctx):
		return {}
	var deal := ctx.rules("deal")
	var p: Dictionary = deal.get("person", {})
	var lo := int(p.get("min", 3))
	var hi := maxi(lo, int(p.get("max", 4)))
	var n := lo + int(ctx.draw("c.deal.n.person", [day]) * float(hi - lo + 1))
	var bonus: Array = p.get("rep_tier_bonus", [0, 0, 0, 0, 0])
	var tier := clampi(CardMeters.tier(ctx, &"rep"), 0, maxi(0, bonus.size() - 1))
	n += int(bonus[tier]) if not bonus.is_empty() else 0
	var counts := {"person": _modified_count(ctx, &"person", n, day),
		"event": _modified_count(ctx, &"event", int(deal.get("event", {}).get("per_day", 1)), day)}
	var news: Dictionary = deal.get("news", {"num": 1, "den": 2})
	var news_n := 1 if ctx.draw("c.deal.n.news", [day]) * maxi(1, int(news.get("den", 2))) < int(news.get("num", 1)) else 0
	counts["news"] = _modified_count(ctx, &"news", news_n, day)
	counts["fate"] = _modified_count(ctx, &"fate", 1 if ctx.mods.any_true(ctx, &"fate_due", {"abs_day": day}) else 0, day)
	if str(ctx.state.ns("loop").get("mode", "shop")) == "street":
		counts["person"] = 0
		counts["event"] = 0
		counts["news"] = 0
		counts["street"] = _modified_count(ctx, &"street", int(deal.get("street_per_day", 3)), day)
	# 未处理的牢房牌表示仍被关着；无需读取或改写 G06 私有状态。
	for uid in CardPiles.list(ctx, CardIds.ZONE_HAND):
		if str(CardPiles.def_of(ctx, uid).get("type", "")) == "prison":
			counts["person"] = 0
	return counts


static func _random_part(ctx: CardCtx, day: int, mutate: bool, pins: Array = [], fixed: Array = []) -> Array:
	var counts := _counts(ctx, day)
	for id in pins:
		var pool := str(ctx.db.def(str(id)).get("type", ""))
		if counts.has(pool):
			counts[pool] = maxi(0, int(counts[pool]) - 1)
	var out: Array = []
	var soft := CardPiles.cap(ctx, CardIds.ZONE_HAND)
	# 软上限只限制随机部分；日程、队列、钉签照发，名额先扣掉它们（合同 §7.4.6）。
	var available := soft - CardPiles.list(ctx, CardIds.ZONE_HAND).size() - fixed.size() if soft >= 0 else 2147483647
	for pool in [&"person", &"event", &"news", &"fate", &"street"]:
		var n := mini(maxi(0, available), int(counts.get(str(pool), 0)))
		var excluded := fixed.duplicate()
		excluded.append_array(out)
		var drawn := _draw_pool(ctx, pool, n, day, mutate, excluded)
		out.append_array(drawn)
		available -= drawn.size()
	return out


static func _pool_rows(ctx: CardCtx, pool: StringName, day: int) -> Array:
	var banned := CardPins.banned(ctx, day)
	if not ctx.mods.has_providers(&"pool_rows"):
		var base: Array = []
		for row in ctx.db.deal_rows(pool, _era(ctx)):
			if ctx.test(row[2]) and not _overlap(row[3], banned):
				base.append([row[0], row[1]])
		return base
	var rows := ctx.mods.collect(ctx, &"pool_rows", {"pool": pool, "abs_day": day})
	var clean: Array = []
	var seen: Dictionary = {}
	for row in rows:
		if typeof(row) != TYPE_ARRAY or row.size() < 2 or int(row[1]) <= 0:
			continue
		var id := str(row[0])
		if seen.has(id) or not ctx.db.has(id) or (not banned.is_empty() and _overlap(ctx.db.def(id).get("tags", []), banned)):
			continue
		seen[id] = true
		clean.append([id, int(row[1])])
	clean.sort_custom(func(a: Array, b: Array) -> bool: return str(a[0]) < str(b[0]))
	return clean


static func _draw_pool(ctx: CardCtx, pool: StringName, n: int, day: int, mutate: bool, excluded: Array = []) -> Array:
	if n <= 0:
		return []
	var rows := _pool_rows(ctx, pool, day)
	var draw_k: Dictionary = ctx.state.ns("core").get("draw_k", {})
	var slot: Dictionary = draw_k.get(str(pool), {})
	var same_day := int(slot.get("abs_day", -1)) == day
	var k := int(slot.get("k", 0)) if same_day else 0
	var used: Array = (slot.get("ids", []) as Array).duplicate() if same_day else []
	var out: Array = []
	rows = rows.filter(func(row: Array) -> bool: return not used.has(str(row[0])) and not excluded.has(str(row[0])))
	for _i in range(maxi(0, n)):
		if rows.is_empty():
			break
		var pick := JevRng.weighted_choice(rows, ctx.draw("c.deal." + str(pool), [day, k]))
		k += 1
		out.append(pick)
		used.append(pick)
		rows = rows.filter(func(row: Array) -> bool: return str(row[0]) != pick)
	if mutate:
		draw_k[str(pool)] = {"abs_day": day, "k": k, "ids": used}
		ctx.state.ns("core")["draw_k"] = draw_k
	return out


static func _pins(ctx: CardCtx, day: int) -> Array:
	var out: Array = []
	for pinned in ctx.mods.collect(ctx, &"pinned_cards", {"abs_day": day}):
		var id := str(pinned)
		var d := ctx.db.def(id)
		if d.is_empty():
			continue
		if not ctx.test(d.get("conditions", {})):
			var omens: Array = []
			for tag in d.get("tags", []):
				if str(tag).begins_with("omen_"):
					omens.append(tag)
			var rows := _pool_rows(ctx, StringName(str(d.get("type", ""))), day)
			rows = rows.filter(func(row: Array) -> bool: return _overlap(ctx.db.def(str(row[0])).get("tags", []), omens))
			if rows.is_empty():
				# 找不到合法的同征兆替身就照发原钉牌，签不落空（合同 §9.3 第 6 步）。
				id = str(pinned)
			else:
				id = JevRng.weighted_choice(rows, ctx.draw("c.deal.sub", [day, str(pinned)]))
		if not out.has(id):
			out.append(id)
	return out


static func _take_queue(ctx: CardCtx, day: int) -> Array:
	var core := ctx.state.ns("core")
	var remaining: Array = []
	var out: Array = []
	for row in core.get("queue", []):
		if int(row.get("abs_day", -1)) != day:
			remaining.append(row)
			continue
		if row.has("pool"):
			out.append_array(_draw_pool(ctx, StringName(str(row["pool"])), int(row.get("n", 1)), day, true))
		elif str(row.get("zone", "hand")) == "hand":
			out.append(str(row.get("def", "")))
		else:
			var zone := StringName(str(row.get("zone", "pending")))
			var uid := CardPiles.spawn(ctx, str(row.get("def", "")), CardIds.ZONE_HAND if zone == &"kept" else zone)
			if uid != "" and zone == &"kept":
				CardPiles.keep(ctx, uid)
	core["queue"] = remaining
	return out


static func _spawn_batch(ctx: CardCtx, defs: Array) -> PackedStringArray:
	var uids := PackedStringArray()
	if not defs.is_empty():
		CardFirsts.mark(ctx, &"deal", {})
	for def_id in defs:
		var uid := CardPiles.spawn(ctx, str(def_id), CardIds.ZONE_HAND)
		if uid != "":
			uids.append(uid)
	CardPiles.order_hand(ctx)
	return uids


static func _emit_deal(ctx: CardCtx, uids: PackedStringArray) -> void:
	ctx.emit(&"cards_dealt", [uids])
	ctx.hooks.fire(ctx, CardIds.HOOK_DEAL_COMPOSED, {"uids": uids})


static func _overlap(tags, wanted) -> bool:
	for tag in wanted:
		if tags.has(tag):
			return true
	return false


static func _era(ctx: CardCtx) -> String:
	return str(ctx.db.stage(int(ctx.state.ns("loop").get("stage", 0))).get("era", "1938"))
