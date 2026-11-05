# RG2_sources: the customer sources' standing modifiers (ROGUE_V1.md §4.5, §5.5) on fixture data. Without a live
# source both providers are neutral and never create state.stock; each pool_weight row of each of the six sources
# moves exactly the cards it names (pool, intents, tags_any) and nothing else; a source of another stage does nothing;
# the deal_count row follows its "when" (market days only); two sources multiply and the product is clamped by
# rules/stock.json, as is a single row when the clamp is tightened. Owner RG2.
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const H = preload("res://scripts/tests/cards/RG2/helper.gd")
const S = preload("res://scripts/cards/stock/stock_state.gd")
const Mods = preload("res://scripts/cards/stock/stock_mods.gd")
const POOLS: Array[String] = ["person", "event", "news"]


func _initialize() -> void:
	var t := T.new(self, "RG2_sources")
	var e := H.engine(t, H.data_root(t), 7, "src")
	t.ok(H.walk_to(e, 1, "day"), "day 1")
	_neutral(t, e)
	_each_row(t, e)
	_other_stage(t, e)
	_deal_count(t, e)
	_stacking(t, e)
	_clamp(t)
	t.eq(t.find_floats(e.ctx.state.data), PackedStringArray(), "integer-only state")
	t.finish()


## No source picked yet: 100 / 0 for every card, and asking never creates the namespace.
func _neutral(t, e: CardEngine) -> void:
	var ctx := e.ctx
	var off := 0
	for pool in POOLS:
		for id in ctx.db.ids_of(StringName(pool)):
			if Mods.pool_pct(ctx, {"pool": pool, "def": id}) != 100:
				off += 1
	t.eq(off, 0, "no source: pool_pct is 100 for every card")
	t.eq(Mods.deal_count(ctx, {"type": "person", "abs_day": ctx.abs_day()}), 0, "no source: deal_count 0")
	t.ok(not ctx.state.data.has("stock"), "asking the providers writes nothing")


## One source at a time: every pool_weight row reaches a matching card with exactly its pct (rows of one source
## never overlap), and a card of the same pool that matches no row stays at 100.
func _each_row(t, e: CardEngine) -> void:
	var c := _copy(e)
	for src in c.db.ids_of(&"source"):
		_set_sources(c, [{"id": src, "stage": 0, "since": 1}])
		var rows: Array = c.db.def(src).get("mods", []).filter(func(m: Dictionary) -> bool:
			return str(m.get("mod", "")) == "pool_weight")
		t.ok(not rows.is_empty(), "%s has pool_weight rows" % src)
		for m in rows:
			var hit := _matching(c, str(m["pool"]), [m])
			t.ok(hit != "", "%s: some %s card matches %s" % [src, m["pool"], JSON.stringify(m)])
			t.eq(Mods.pool_pct(c, {"pool": str(m["pool"]), "def": hit}), int(m["pct"]), "%s on %s" % [src, hit])
			t.eq(Mods.pool_pct(c, {"pool": _other_pool(str(m["pool"])), "def": hit}), 100, "%s: other pool untouched" % src)
			var miss := _not_matching(c, str(m["pool"]), rows)
			t.ok(miss != "", "%s: some %s card matches no row" % [src, m["pool"]])
			t.eq(Mods.pool_pct(c, {"pool": str(m["pool"]), "def": miss}), 100, "%s leaves %s alone" % [src, miss])


## A row picked in another stage is not live (stage_start removes it; until then it is ignored).
func _other_stage(t, e: CardEngine) -> void:
	var c := _copy(e)
	_set_sources(c, [{"id": "ky.traveling_buyers", "stage": 1, "since": 40}])
	var buy := _matching(c, "person", [{"pool": "person", "intents": ["buy"]}])
	t.eq(Mods.pool_pct(c, {"pool": "person", "def": buy}), 100, "another stage's source does nothing")
	t.eq(S.live_source_ids(c), PackedStringArray(), "no live source")


## ky.old_customers: one more customer on market days only ("when": market_day), only for type person.
func _deal_count(t, e: CardEngine) -> void:
	var c := _copy(e)
	_set_sources(c, [{"id": "ky.old_customers", "stage": 0, "since": 1}])
	var loop := c.state.ns("loop")
	var start_day := int(loop["stage_day"])
	var start_abs := int(loop["abs_day"])
	var markets := 0
	var wrong := 0
	for d in range(1, 31):
		loop["stage_day"] = d
		loop["abs_day"] = start_abs + d - start_day
		var market := CardCalendar.is_market_day(c, d)
		markets += 1 if market else 0
		if Mods.deal_count(c, {"type": "person", "abs_day": c.abs_day()}) != (1 if market else 0):
			wrong += 1
		if Mods.deal_count(c, {"type": "event", "abs_day": c.abs_day()}) != 0:
			wrong += 1
	t.ok(markets > 0 and markets < 30, "the stage has market days and ordinary days (%d)" % markets)
	t.eq(wrong, 0, "deal_count +1 on market days only, person only")
	t.eq(Mods.pool_pct(c, {"pool": "person", "def": _matching(c, "person", [{"pool": "person", "intents": ["redeem"]}])}),
		170, "its pool row still applies")


## Two live sources multiply; the product is clamped (default pool_max 250 from the fixture rules).
func _stacking(t, e: CardEngine) -> void:
	var c := _copy(e)
	_set_sources(c, [{"id": "ky.traveling_buyers", "stage": 0, "since": 7}, {"id": "ky.dockhands", "stage": 0, "since": 14}])
	var rows := [{"pool": "person", "intents": ["buy"]}, {"pool": "person", "tags_any": ["dock", "boat", "merchant"]}]
	var both := _matching(c, "person", rows)
	if both == "":
		t.ok(true, "no person card is both a buyer and a dock/boat/merchant: stacking not exercised")
		return
	t.eq(Mods.pool_pct(c, {"pool": "person", "def": both}), 250, "180 x 200 clamped to pool_max 250 on " + both)
	var buy_only := _matching(c, "person", [rows[0]], [rows[1]])
	t.eq(Mods.pool_pct(c, {"pool": "person", "def": buy_only}), 180, "a buyer alone: 180")


## Tightened clamp (pool 90..150, deal_count 0..0): single rows are clamped too.
func _clamp(t) -> void:
	var tight := {"clamp": {"pool_min": 90, "pool_max": 150, "deal_count_min": 0, "deal_count_max": 0}}
	var e := H.engine(t, H.data_root(t, "clamp", tight), 7, "clamp")
	t.ok(H.walk_to(e, 1, "day"), "clamp: day 1")
	var c := _copy(e)
	_set_sources(c, [{"id": "ky.traveling_buyers", "stage": 0, "since": 1}, {"id": "ky.old_customers", "stage": 0, "since": 1}])
	var buy := _matching(c, "person", [{"pool": "person", "intents": ["buy"]}])
	var ask := _matching(c, "person", [{"pool": "person", "intents": ["ask"]}])
	t.eq(Mods.pool_pct(c, {"pool": "person", "def": buy}), 150, "180 clamped down to 150")
	t.eq(Mods.pool_pct(c, {"pool": "person", "def": ask}), 90, "80 clamped up to 90")
	var loop := c.state.ns("loop")
	for d in range(1, 31):
		if CardCalendar.is_market_day(c, d):
			loop["stage_day"] = d
			break
	t.ok(CardCalendar.is_market_day(c, int(loop["stage_day"])), "clamp: a market day")
	t.eq(Mods.deal_count(c, {"type": "person", "abs_day": c.abs_day()}), 0, "deal_count +1 clamped to 0")


# ---------------- helpers ----------------
## A detached copy of the engine's context (same registries and data, own state) so the engine stays untouched.
func _copy(e: CardEngine) -> CardCtx:
	var c := CardCtx.new()
	c.db = e.ctx.db
	c.ops = e.ctx.ops
	c.conds = e.ctx.conds
	c.mods = e.ctx.mods
	c.hooks = e.ctx.hooks
	c.actions = e.ctx.actions
	c.state = CardState.from_dict(e.ctx.state.to_dict())
	return c


func _set_sources(c: CardCtx, rows: Array) -> void:
	S.ns(c)["sources"] = rows.duplicate(true)


## First card of the pool (sorted ids) that matches every row in want and none in avoid.
func _matching(c: CardCtx, pool: String, want: Array, avoid: Array = []) -> String:
	for id in c.db.ids_of(StringName(pool)):
		var d: Dictionary = c.db._cards[id]
		if want.all(func(m: Dictionary) -> bool: return Mods._card_matches(m, d)) \
				and not avoid.any(func(m: Dictionary) -> bool: return Mods._card_matches(m, d)):
			return id
	return ""


func _not_matching(c: CardCtx, pool: String, rows: Array) -> String:
	var same_pool: Array = rows.filter(func(m: Dictionary) -> bool: return str(m.get("pool", "")) == pool)
	for id in c.db.ids_of(StringName(pool)):
		var d: Dictionary = c.db._cards[id]
		if not same_pool.any(func(m: Dictionary) -> bool: return Mods._card_matches(m, d)):
			return id
	return ""


func _other_pool(pool: String) -> String:
	return "news" if pool != "news" else "event"
