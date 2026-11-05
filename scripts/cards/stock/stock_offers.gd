# Rogue v1: makes offers (weekly stocktake at settle 80, the stock_offer op used by the peddler), counts the week's
# deals (card_resolved 35), lapses stale offers (day_start 3) and drops last stage's sources (stage_start 60).
# Every draw goes through ctx.draw("c.stock.offer", key) and is recorded in the offer when it is made.
# Owner RG2 (docs/cards/rogue/ROGUE_V1.md §4.4, §4.6, §5.1, §5.2, §5.5). No class_name; preload it.
extends RefCounted

const Ids = preload("res://scripts/cards/stock/stock_ids.gd")
const S = preload("res://scripts/cards/stock/stock_state.gd")
const RelicApi = preload("res://scripts/cards/relic/relic_api.gd")


## settle priority 80: on the stock week days, set out 2 or 3 things to pick from (§5.1).
static func on_settle(ctx: CardCtx, _args: Dictionary) -> void:
	if not S.active(ctx):
		return
	var day := S.stage_day(ctx)
	if not _has_int(S.rule_list(ctx, "week_days"), day):
		return
	if str(S.loop_of(ctx).get("mode", CardIds.MODE_SHOP)) != str(CardIds.MODE_SHOP) or S.in_prison(ctx):
		return
	var stage := S.stage(ctx)
	var week := day / 7 - 1
	var id := "w%d.%d" % [stage, week]
	if S.offers(ctx).has(id):
		return
	var deals := S.deals(ctx, stage, week)
	var full := deals >= S.rule_int(ctx, "deals_needed")
	var n := maxi(0, S.rule_int(ctx, "offers_full" if full else "offers_few"))
	var allowed: Array = Array(Ids.KINDS)
	var wants: Array = []
	if _has_str(S.rule_list(ctx, "source_only_weeks"), S.deal_key(stage, week)):
		allowed = [Ids.KIND_SOURCE]
		for _k in range(n):
			wants.append(Ids.KIND_SOURCE)
	else:
		wants = _cycle(S.rule_list(ctx, "slot_kinds"), n)
	var items := build_items(ctx, wants, allowed, [], [stage, week])
	if items.is_empty():
		return
	_record(ctx, id, {"from": Ids.FROM_WEEK, "stage": stage, "week": week, "abs_day": ctx.abs_day(),
		"deals": deals, "items": items})
	ctx.emit(&"notice", [Ids.N_STOCKTAKE if full else Ids.N_FEW, {"deals": deals}])
	open_panel(ctx, id)


## Effect op stock_offer {n, kinds, depths?, from} (§4.4, §5.2): an offer right now, id p<abs_day>.
static func op_offer(ctx: CardCtx, eff: Dictionary, _source: String) -> void:
	if not S.active(ctx) or S.phase(ctx) == str(CardIds.PH_GAME_OVER):
		return
	var day := ctx.abs_day()
	var id := "p%d" % day
	var old := S.offer(ctx, id)
	if not old.is_empty():
		# Same offer asked again today: only reopen it while it is still open (never re-roll or re-open a pick).
		if str(old.get("status", "")) == Ids.ST_OPEN:
			open_panel(ctx, id)
		return
	var allowed: Array = []
	for kind in eff.get("kinds", []):
		if Ids.KINDS.has(str(kind)) and not allowed.has(str(kind)):
			allowed.append(str(kind))
	var depths: Array = []
	for depth in eff.get("depths", []):
		depths.append(str(depth))
	var stage := S.stage(ctx)
	var items := build_items(ctx, _cycle(allowed, maxi(0, int(eff.get("n", 0)))), allowed, depths, [stage, "p", day])
	if items.is_empty():
		ctx.emit(&"notice", [Ids.N_PEDDLER_EMPTY, {}])
		return
	_record(ctx, id, {"from": str(eff.get("from", Ids.FROM_PEDDLER)), "stage": stage, "week": -1, "abs_day": day,
		"deals": S.week_deals(ctx), "items": items})
	open_panel(ctx, id)


## One pick per slot k (draw key = key_prefix + [k]). An empty pool falls back to the other allowed kind;
## when every allowed pool is empty the offer stops short. Returns [{id, kind}].
static func build_items(ctx: CardCtx, wants: Array, allowed: Array, depths: Array, key_prefix: Array) -> Array:
	var pools := {Ids.KIND_RELIC: relic_pool(ctx, depths) if allowed.has(Ids.KIND_RELIC) else [],
		Ids.KIND_SOURCE: source_pool(ctx) if allowed.has(Ids.KIND_SOURCE) else []}
	var items: Array = []
	for k in range(wants.size()):
		var kind := _kind_with_stock(pools, str(wants[k]), allowed)
		if kind == "":
			break
		var rows: Array = pools[kind]
		var key := key_prefix.duplicate()
		key.append(k)
		var picked := JevRng.weighted_choice(rows, ctx.draw(Ids.DOMAIN, key))
		items.append({"id": picked, "kind": kind})
		pools[kind] = rows.filter(func(row: Array) -> bool: return str(row[0]) != picked)
	return items


## Relics that may be offered now: weight > 0 and era (CardDB.pool), conditions true, not held, not given up,
## depth in depths (empty = any). Empty while the relic module is off. Rows [id, weight] sorted by id.
static func relic_pool(ctx: CardCtx, depths: Array) -> Array:
	var rows: Array = []
	if not RelicApi.active(ctx):
		return rows
	var held := RelicApi.held_ids(ctx)
	var gone := RelicApi.gone_ids(ctx)
	for id in ctx.db.pool(&"relic", S.era(ctx)):
		if held.has(id) or gone.has(id):
			continue
		var d := S.def_of(ctx, id)
		if not depths.is_empty() and not depths.has(str(d.get("depth", ""))):
			continue
		if ctx.test(d.get("conditions", {})):
			rows.append([id, int(d.get("weight", 10))])
	return rows


## Sources that may be offered now: weight > 0, era, conditions true, not already working this stage (§5.5).
static func source_pool(ctx: CardCtx) -> Array:
	var rows: Array = []
	var have := S.live_source_ids(ctx)
	for id in ctx.db.pool(&"source", S.era(ctx)):
		if have.has(id):
			continue
		var d := S.def_of(ctx, id)
		if ctx.test(d.get("conditions", {})):
			rows.append([id, int(d.get("weight", 10))])
	return rows


## Ask the table to show the offer. A pending money-short panel is never covered (the drawer still reaches the
## offer through view.stock.open).
static func open_panel(ctx: CardCtx, id: String) -> void:
	var panel = S.loop_of(ctx).get("open_panel", {})
	if typeof(panel) == TYPE_DICTIONARY and str(panel.get("kind", "")) == "short":
		return
	CardDayLoop.request_panel(ctx, Ids.PANEL, {"offer": id})


## day_start priority 3: offers from an earlier day that were never answered are void; the morning board says so.
static func on_day_start(ctx: CardCtx, _args: Dictionary) -> void:
	var all := S.offers(ctx)
	if all.is_empty():
		return
	var today := ctx.abs_day()
	var ids: Array = all.keys()
	ids.sort()
	var any := false
	for id in ids:
		var o = all[id]
		if typeof(o) == TYPE_DICTIONARY and str(o.get("status", "")) == Ids.ST_OPEN and int(o.get("abs_day", 0)) < today:
			o["status"] = Ids.ST_LAPSED
			any = true
	if any:
		ctx.emit(&"notice", [Ids.N_LAPSED, {}])
		S.changed(ctx)


## card_resolved priority 35: an almanac with "trade" (pawn in, buy, sell, redeem at the counter) is one deal.
static func on_resolved(ctx: CardCtx, args: Dictionary) -> void:
	var almanac = args.get("almanac", [])
	if typeof(almanac) != TYPE_ARRAY and typeof(almanac) != TYPE_PACKED_STRING_ARRAY:
		return
	if not _has_str(Array(almanac), Ids.TRADE) or not S.active(ctx):
		return
	var deals: Dictionary = S.ns(ctx)["deals"]
	var key := S.deal_key(S.stage(ctx), S.week_of(S.stage_day(ctx)))
	deals[key] = int(deals.get(key, 0)) + 1
	S.changed(ctx)


## stage_start priority 60: sources last until the end of their stage (§5.5).
static func on_stage_start(ctx: CardCtx, _args: Dictionary) -> void:
	var st := S.peek(ctx)
	var rows = st.get("sources", [])
	if typeof(rows) != TYPE_ARRAY or (rows as Array).is_empty():
		return
	var kept := S.live_sources(ctx)
	if kept.size() == (rows as Array).size():
		return
	st["sources"] = kept
	ctx.emit(&"notice", [Ids.N_SOURCES_LAPSED, {}])
	S.changed(ctx)


static func _record(ctx: CardCtx, id: String, rec: Dictionary) -> void:
	rec["status"] = Ids.ST_OPEN
	rec["picked"] = ""
	(S.ns(ctx)["offers"] as Dictionary)[id] = rec
	S.changed(ctx)


static func _kind_with_stock(pools: Dictionary, want: String, allowed: Array) -> String:
	if allowed.has(want) and not (pools.get(want, []) as Array).is_empty():
		return want
	for kind in Ids.KINDS:
		if allowed.has(kind) and not (pools.get(kind, []) as Array).is_empty():
			return kind
	return ""


## n entries taken round-robin from kinds (slot k wants kinds[k % size]); [] when kinds is empty.
static func _cycle(kinds: Array, n: int) -> Array:
	var out: Array = []
	if kinds.is_empty():
		return out
	for k in range(n):
		out.append(str(kinds[k % kinds.size()]))
	return out


static func _has_int(values: Array, v: int) -> bool:
	for x in values:
		if typeof(x) in [TYPE_INT, TYPE_FLOAT] and int(x) == v:
			return true
	return false


static func _has_str(values: Array, v: String) -> bool:
	for x in values:
		if str(x) == v:
			return true
	return false
