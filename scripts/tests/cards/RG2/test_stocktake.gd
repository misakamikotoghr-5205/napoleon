# RG2_stocktake: the weekly stocktake end to end on fixture data (ROGUE_V1.md §4.2, §4.3, §5.1, §5.3, §5.5, §15.1).
# Day 7: sources only, 0 deals -> 2 things, the overlay is requested and closing the day needs no confirmation;
# two deals before day 14 -> 3 things, relics and sources mixed; picking a source makes its customers more common;
# "" passes; a second pick is already_resolved; the next morning an unanswered offer lapses; the next stage drops
# the sources with a notice. Same seed + same commands = same offers, also after reloading a morning save.
# Nothing hidden reaches the view, the query or the bus (events are leak-checked before every spy.clear()). Owner RG2.
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const H = preload("res://scripts/tests/cards/RG2/helper.gd")
const Offers = preload("res://scripts/cards/stock/stock_offers.gd")
const Mods = preload("res://scripts/cards/stock/stock_mods.gd")
const Pick = preload("res://scripts/cards/stock/stock_pick.gd")
const RelicApi = preload("res://scripts/cards/relic/relic_api.gd")
const BUYERS := "ky.traveling_buyers"


func _initialize() -> void:
	var t := T.new(self, "RG2_stocktake")
	var root := H.data_root(t)
	var bus := CardEventBus.new()
	var spy = t.spy(bus)
	var a := H.engine(t, root, 7, "main", bus)
	_week0(t, a)
	_week1(t, a)
	_skips(t, a)
	_errors(t, a)
	_pick_source(t, a, spy)
	_pass_and_relic(t, a, spy)
	_next_stage(t, a, spy)
	H.events_clean(t, spy, "stage 1")
	t.eq(t.find_floats(a.ctx.state.data), PackedStringArray(), "integer-only state")
	_same_seed(t, root)
	_resume(t, root)
	_full_shelf(t, root)
	bus.free()
	t.finish()


func _week0(t, a: CardEngine) -> void:
	t.ok(H.walk_to(a, 7, "settle"), "day 7 settle reached")
	var view := a.view()
	t.eq(view.get("open_panel"), {"kind": "stocktake", "args": {"offer": "w0.0"}}, "day 7: the stocktake overlay is requested")
	var q: Dictionary = a.query(&"stocktake", {"offer": "w0.0"})
	t.ok(bool(q.get("ok", false)), "query w0.0")
	t.eq(q.get("from"), "week", "from week")
	t.eq(q.get("week"), 0, "week 0")
	t.eq(q.get("deals"), 0, "no deals in week 0")
	t.eq(q.get("status"), "open", "open")
	t.eq((q.get("items", []) as Array).size(), 2, "0 deals -> 2 things")
	for row in q.get("items", []):
		t.eq(row.get("kind"), "source", "1938 week 0 offers sources only (%s)" % row.get("id"))
		t.eq(row.get("depth"), "", "sources have no depth word")
		t.ok(str(row.get("art", "")).begins_with("illus.ky."), "source art id")
	t.eq(q.get("cap"), 6, "shelf cap from RelicApi")
	t.eq(q.get("full"), false, "shelf not full")
	t.eq(a.query(&"stocktake", {}), q, "no offer id = the latest open one")
	t.eq(view.get("stock"), {"open": "w0.0", "week_deals": 0, "sources": []}, "view.stock on day 7")
	t.ok(_report_has(a, "rg2.notice.stocktake_few", {"deals": 0}), "the few-deals notice is in the day's report")
	t.no_leaks(view, "day 7 view")
	t.no_leaks(q, "stocktake query")
	var r: Dictionary = a.send(&"day.end", {"confirm": false})
	t.ok(bool(r.get("ok", false)), "day.end {confirm:false} with the offer open: " + str(r.get("err", "")))
	t.eq(r.get("needs_confirm"), false, "closing the night needs no confirmation")
	t.eq(H.phase(a), "morning", "straight to the next morning")
	t.eq(H.stage_day(a), 8, "day 8")
	t.eq(H.offer(a, "w0.0").get("status"), "lapsed", "an unanswered offer lapses the next morning")
	var keys: Array = []
	for row in a.view().get("notice", {}).get("news", []):
		keys.append(str(row.get("key", "")))
	t.ok(keys.has("rg2.notice.lapsed"), "the morning board says the unanswered offer went back: " + str(keys))
	t.eq(a.view().get("open_panel", {}).get("kind"), "", "no panel in the morning")
	t.eq(a.view().get("stock", {}).get("open"), "", "nothing open")
	var first := str((q.get("items", [{}]) as Array)[0].get("id", ""))
	t.eq(a.send(&"stock.pick", {"offer": "w0.0", "pick": first}).get("err"), "already_resolved", "a lapsed offer cannot be picked")
	t.eq(a.query(&"stocktake", {}).get("err"), "not_allowed", "no open offer -> not_allowed")
	t.eq(a.query(&"stocktake", {"offer": "w0.0"}).get("status"), "lapsed", "the lapsed offer is still readable")


func _week1(t, a: CardEngine) -> void:
	t.ok(H.walk_to(a, 8, "day"), "day 8")
	H.trade(a)
	H.trade(a)
	# Sent away, refused or a story card: no "trade" in the almanac, not a deal (§5.1).
	a.ctx.hooks.fire(a.ctx, &"card_resolved", {"uid": "", "outcome": &"resolved", "almanac": ["pawn_in"]})
	a.ctx.hooks.fire(a.ctx, &"card_resolved", {"uid": "", "outcome": &"expired", "almanac": []})
	a.ctx.hooks.fire(a.ctx, &"card_resolved", {"uid": "", "outcome": &"resolved"})
	t.eq(a.view().get("stock", {}).get("week_deals"), 2, "two deals this week")
	t.eq(H.stock(a).get("deals", {}).get("0:1"), 2, "deals keyed stage:week")
	t.ok(H.walk_to(a, 14, "settle"), "day 14 settle reached")
	var q: Dictionary = a.query(&"stocktake", {})
	t.eq(q.get("offer"), "w0.1", "week 1 offer")
	t.eq(q.get("deals"), 2, "the offer records the week's deals")
	var kinds: Dictionary = {}
	for row in q.get("items", []):
		kinds[str(row.get("kind"))] = true
		if str(row.get("kind")) == "relic":
			t.ok(str(row.get("depth", "")) in ["plain", "storied", "treasure"], "relic depth word")
			t.ok(str(row.get("art", "")).begins_with("prop.relic."), "relic art id")
	t.eq((q.get("items", []) as Array).size(), 3, "2 deals -> 3 things")
	t.ok(kinds.has("relic") and kinds.has("source"), "relics and sources mixed: %s" % str(kinds.keys()))
	t.ok(_report_has(a, "rg2.notice.stocktake", {"deals": 2}), "the stocktake notice carries the deals")
	t.eq(a.view().get("open_panel"), {"kind": "stocktake", "args": {"offer": "w0.1"}}, "overlay requested for w0.1")
	t.eq(q.get("stage"), 0, "stage 0")
	t.eq(q.get("week"), 1, "week 1")
	t.eq(a.query(&"stocktake", {"offer": "w0.1", "uid": "c0002"}), q, "the read-only query ignores other keys")
	t.no_leaks(q, "w0.1 query")
	t.no_leaks(a.view(), "day 14 view")


## Street, prison, already made, and a pending money-short panel (on a copy of the state; the engine is untouched).
func _skips(t, a: CardEngine) -> void:
	var before := a.ctx.state.hash()
	var c := _copy(a)
	var again := c.state.hash()
	Offers.on_settle(c, {})
	t.eq(c.state.hash(), again, "a second settle the same day makes nothing")
	c.state.ns("loop")["stage_day"] = 21
	c.state.ns("loop")["mode"] = "street"
	Offers.on_settle(c, {})
	t.ok(not H.stock_of(c).get("offers", {}).has("w0.2"), "no stocktake while on the street")
	c.state.ns("loop")["mode"] = "shop"
	c.state.ns("ladder")["prison"] = {"uid": "c9999"}
	Offers.on_settle(c, {})
	t.ok(not H.stock_of(c).get("offers", {}).has("w0.2"), "no stocktake in prison")
	c.state.ns("ladder")["prison"] = {"uid": ""}
	c.state.ns("loop")["open_panel"] = {"kind": "short", "args": {"amount": 1}}
	Offers.on_settle(c, {})
	t.ok(H.stock_of(c).get("offers", {}).has("w0.2"), "the shop day 21 makes w0.2")
	t.eq(c.state.ns("loop")["open_panel"].get("kind"), "short", "a pending money-short panel is not covered")
	c.state.ns("loop")["stage_day"] = 22
	c.state.ns("loop")["open_panel"] = {"kind": "", "args": {}}
	Offers.on_settle(c, {})
	t.ok(not H.stock_of(c).get("offers", {}).has("w0.3"), "day 22 is not a stocktake day")
	t.eq(a.ctx.state.hash(), before, "the engine's state was not touched")


func _errors(t, a: CardEngine) -> void:
	var q: Dictionary = a.query(&"stocktake", {"offer": "w0.1"})
	var src := _first_of(q, "source")
	var before := a.ctx.state.hash()
	var cases := [
		[{}, "bad_args"], [{"offer": "w0.1"}, "bad_args"], [{"pick": ""}, "bad_args"],
		[{"offer": "w9.9", "pick": ""}, "bad_args"], [{"offer": "", "pick": ""}, "bad_args"],
		[{"offer": 1, "pick": ""}, "bad_args"], [{"offer": "w0.1", "pick": 3}, "bad_args"],
		[{"offer": "w0.1", "pick": "", "extra": true}, "bad_args"], [{"offer": "w0.1", "pick": "", "replace": 1}, "bad_args"],
		[{"offer": "w0.1", "pick": "", "replace": "rl.stub_box"}, "bad_args"],
		[{"offer": "w0.1", "pick": src, "replace": "rl.stub_box"}, "bad_args"],
		[{"offer": "w0.1", "pick": "rl.nope"}, "not_allowed"], [{"offer": "w0.1", "pick": "ky.nobody"}, "not_allowed"],
	]
	for row in cases:
		var r: Dictionary = a.send(&"stock.pick", row[0])
		t.eq(r.get("err"), row[1], "stock.pick %s" % JSON.stringify(row[0]))
		t.eq(r.get("ok"), false, "failed pick is not ok")
	t.eq(a.ctx.state.hash(), before, "failed picks change nothing")
	# On a detached copy: game over -> bad_phase; an offered id whose card is gone from the data -> unknown_def.
	var c := _copy(a)
	c.state.ns("loop")["phase"] = "game_over"
	t.eq(Pick.pick(c, {"offer": "w0.1", "pick": src}).get("err"), "bad_phase", "game over -> bad_phase")
	c.state.ns("loop")["phase"] = "settle"
	(H.stock_of(c)["offers"]["w0.1"]["items"] as Array).append({"id": "ky.retired", "kind": "source"})
	t.eq(Pick.pick(c, {"offer": "w0.1", "pick": "ky.retired"}).get("err"), "unknown_def", "offered id without a card")
	t.eq(H.stock_of(c)["offers"]["w0.1"].get("status"), "open", "still open on the copy")
	t.eq(a.ctx.state.hash(), before, "the engine's state was not touched")
	t.eq(a.query(&"stocktake", {"offer": "w9.9"}).get("err"), "bad_args", "unknown offer id -> bad_args")
	t.eq(a.query(&"stocktake", {"offer": 5}).get("err"), "bad_args", "mistyped offer id -> bad_args")
	t.eq(H.offer(a, "w0.1").get("status"), "open", "w0.1 still open")


func _pick_source(t, a: CardEngine, spy) -> void:
	var ctx := a.ctx
	var q: Dictionary = a.query(&"stocktake", {"offer": "w0.1"})
	t.ok(_has_item(q, BUYERS), "seed 7 offers the travelling buyers in week 1 (fixture data)")
	var src := BUYERS if _has_item(q, BUYERS) else _first_of(q, "source")
	var def: Dictionary = ctx.db.def(src)
	var checks: Array = []
	for m in def.get("mods", []):
		if str(m.get("mod", "")) != "pool_weight":
			continue
		var id := _match_def(ctx, m)
		t.ok(id != "", "a %s card matches %s" % [m.get("pool"), JSON.stringify(m)])
		checks.append([m, id, ctx.mods.pct(ctx, &"pool_pct", {"pool": str(m["pool"]), "def": id})])
	var buy := _intent_def(ctx, "buy")
	var pawn := _intent_def(ctx, "pawn")
	var buy_before := ctx.mods.pct(ctx, &"pool_pct", {"pool": "person", "def": buy})
	var pawn_before := ctx.mods.pct(ctx, &"pool_pct", {"pool": "person", "def": pawn})
	var deals_before := ctx.mods.sum_int(ctx, &"deal_count", {"type": "person", "abs_day": ctx.abs_day()})
	H.events_clean(t, spy, "weeks 0-1")
	spy.clear()
	var r: Dictionary = a.send(&"stock.pick", {"offer": "w0.1", "pick": src})
	t.eq(r, {"ok": true, "err": "", "offer": "w0.1", "picked": src, "kind": "source", "released": ""}, "pick a source")
	t.eq(H.offer(a, "w0.1").get("status"), "picked", "status picked")
	t.eq(H.offer(a, "w0.1").get("picked"), src, "picked id recorded")
	t.eq(H.stock(a).get("sources"), [{"id": src, "stage": 0, "since": 14}], "state.stock.sources")
	t.eq(a.view().get("stock", {}).get("sources"), [{"id": src, "art": str(def.get("art", ""))}], "view.stock.sources")
	t.eq(a.view().get("open_panel", {}).get("kind"), "", "the overlay is closed after the pick")
	t.ok(_spied_notice(spy, src + "#lines.gain"), "the source's gain line is a notice")
	var topics := PackedStringArray()
	for row in spy.log:
		if row[0] == &"view_changed":
			topics.append_array(PackedStringArray(row[1]))
	t.ok(topics.has("stock") and topics.has("relics"), "view_changed carries stock and relics: %s" % str(topics))
	for row in checks:
		var after := ctx.mods.pct(ctx, &"pool_pct", {"pool": str(row[0]["pool"]), "def": str(row[1])})
		var pct := int(row[0].get("pct", 100))
		t.ok(after > int(row[2]) if pct > 100 else after < int(row[2]), "%s on %s: %d -> %d" % [pct, row[1], row[2], after])
	if src == BUYERS:
		t.ok(ctx.mods.pct(ctx, &"pool_pct", {"pool": "person", "def": buy}) > buy_before, "buy customers come more often")
		t.eq(Mods.pool_pct(ctx, {"pool": "person", "def": buy}), 180, "the source alone: buy x180")
		t.eq(ctx.mods.pct(ctx, &"pool_pct", {"pool": "person", "def": pawn}), pawn_before, "pawn customers unchanged")
		t.eq(Mods.pool_pct(ctx, {"pool": "event", "def": buy}), 100, "other pools unchanged")
	t.eq(ctx.mods.sum_int(ctx, &"deal_count", {"type": "person", "abs_day": ctx.abs_day()}), deals_before, "no deal_count row")
	t.eq(a.send(&"stock.pick", {"offer": "w0.1", "pick": src}).get("err"), "already_resolved", "picking twice")
	t.eq(a.query(&"stocktake", {}).get("err"), "not_allowed", "nothing left open")


func _pass_and_relic(t, a: CardEngine, spy) -> void:
	t.ok(H.walk_to(a, 21, "settle"), "day 21 settle")
	t.eq(a.view().get("stock", {}).get("open"), "w0.2", "w0.2 open")
	var live := str((H.stock(a).get("sources", [{}]) as Array)[0].get("id", ""))
	t.ok(live != "" and not _has_item(a.query(&"stocktake", {"offer": "w0.2"}), live),
		"a source already working this stage is not set out again (%s)" % live)
	H.events_clean(t, spy, "source pick")
	spy.clear()
	var r: Dictionary = a.send(&"stock.pick", {"offer": "w0.2", "pick": ""})
	t.eq(r, {"ok": true, "err": "", "offer": "w0.2", "picked": "", "kind": "", "released": ""}, "pick nothing")
	t.eq(H.offer(a, "w0.2").get("status"), "passed", "status passed")
	t.ok(_spied_notice(spy, "rg2.notice.passed"), "passed notice")
	t.eq(a.view().get("open_panel", {}).get("kind"), "", "overlay closed after passing")
	t.eq(a.send(&"stock.pick", {"offer": "w0.2", "pick": ""}).get("err"), "already_resolved", "passing twice")
	t.ok(H.walk_to(a, 28, "settle"), "day 28 settle")
	var q: Dictionary = a.query(&"stocktake", {"offer": "w0.3"})
	var relic := _first_of(q, "relic")
	t.ok(relic != "", "w0.3 has a relic")
	t.ok(not _has_item(q, live), "w0.3 does not offer the live source either")
	var took: Dictionary = a.send(&"stock.pick", {"offer": "w0.3", "pick": relic})
	if bool(took.get("ok", false)):
		# RG1 merged: RelicApi.take worked.
		t.eq(took.get("kind"), "relic", "relic picked through RelicApi")
		t.eq(H.offer(a, "w0.3").get("status"), "picked", "relic offer picked")
	else:
		# Before RG1: the step-0 stub answers not_implemented and the offer stays open (§14 RG2 "dependencies").
		t.eq(took.get("err"), "not_implemented", "RelicApi stub error passed through")
		t.eq(H.offer(a, "w0.3").get("status"), "open", "a failed relic take leaves the offer open")
		t.eq(a.view().get("open_panel"), {"kind": "stocktake", "args": {"offer": "w0.3"}}, "overlay still requested")
	var r2: Dictionary = a.send(&"day.end", {"confirm": false})
	t.ok(bool(r2.get("ok", false)) and H.stage_day(a) == 29 and H.phase(a) == "morning", "day 28 closes without confirmation")
	if not bool(took.get("ok", false)):
		t.eq(H.offer(a, "w0.3").get("status"), "lapsed", "w0.3 lapsed on day 29")


func _next_stage(t, a: CardEngine, spy) -> void:
	var guard := 0
	while H.phase(a) != "year_jump" and H.phase(a) != "game_over" and guard < 40:
		guard += 1
		a.send(&"day.end", {"confirm": true})
	t.eq(H.phase(a), "year_jump", "end of stage 0")
	t.eq((H.stock(a).get("sources", []) as Array).size(), 1, "the source lasts to the end of the stage")
	H.events_clean(t, spy, "pass and relic")
	spy.clear()
	var r: Dictionary = a.send(&"year.next", {})
	t.ok(bool(r.get("ok", false)), "year.next: " + str(r.get("err", "")))
	t.eq(int(a.ctx.state.ns("loop").get("stage", 0)), 1, "stage 1")
	t.eq(H.stock(a).get("sources"), [], "the new stage drops last stage's sources")
	t.ok(_spied_notice(spy, "rg2.notice.sources_lapsed"), "sources-lapsed notice")
	t.eq(a.view().get("stock", {}).get("sources"), [], "view.stock.sources empty")
	var buy := _intent_def(a.ctx, "buy")
	t.eq(Mods.pool_pct(a.ctx, {"pool": "person", "def": buy}), 100, "no source effect in the new stage")
	t.no_leaks(a.view(), "stage 1 view")
	# Only "0:0" is sources-only: stage 1's first stocktake mixes kinds (slot_kinds relic, source with 0 deals).
	t.ok(H.walk_to(a, 7, "settle"), "stage 1 day 7 settle")
	var q: Dictionary = a.query(&"stocktake", {})
	t.eq(q.get("offer"), "w1.0", "stage 1 week 0 offer id")
	t.eq(q.get("stage"), 1, "stage 1")
	t.eq((q.get("items", []) as Array).map(func(row: Dictionary) -> String: return str(row.get("kind"))),
		["relic", "source"], "0 deals -> 2 things, a relic then a source")
	t.ok(_relic_has_depth(q), "stage 1 relic row has a depth word")
	t.no_leaks(q, "stage 1 query")


func _same_seed(t, root: String) -> void:
	var b := H.engine(t, root, 7, "same_b")
	var c := H.engine(t, root, 7, "same_c")
	t.ok(H.walk_to(b, 21, "settle") and H.walk_to(c, 21, "settle"), "both at day 21 settle")
	t.eq(H.stock(b), H.stock(c), "same seed, same commands: same offers")
	t.eq(b.query(&"stocktake", {}), c.query(&"stocktake", {}), "same query")
	t.eq(b.ctx.state.hash(), c.ctx.state.hash(), "same state hash")


func _resume(t, root: String) -> void:
	var d := H.engine(t, root, 7, "resume")
	t.ok(H.walk_to(d, 14, "morning"), "day 14 morning")
	var path := CardSave.suspend_path()
	t.ok(FileAccess.file_exists(path), "morning resume point written")
	t.ok(H.walk_to(d, 14, "settle"), "day 14 settle")
	var q1: Dictionary = d.query(&"stocktake", {})
	var s1: Dictionary = H.stock(d).duplicate(true)
	t.eq(q1.get("offer"), "w0.1", "w0.1 made")
	var r: Dictionary = d.load_game(path)
	t.ok(bool(r.get("ok", false)), "load the morning save: " + str(r.get("err", "")))
	t.ok(H.phase(d) == "morning" and H.stage_day(d) == 14, "back at day 14 morning")
	t.ok(not H.stock(d).get("offers", {}).has("w0.1"), "the save predates w0.1")
	t.ok(H.walk_to(d, 14, "settle"), "day 14 settle again")
	t.eq(d.query(&"stocktake", {}), q1, "same offer after resuming")
	t.eq(H.stock(d), s1, "same stock state after resuming")


## The relic branch of stock.pick through RelicApi (§4.2, §4.7, §5.1, §5.3). Before RG1 lands the step-0 stub answers
## not_implemented for every take and only that contract is checked here. Once RelicApi is real: a full shelf refuses
## a pick without replace (relic_full, offer still open), a replace that is not held is not_held, a held replace
## swaps (released, gone), and held or given-up relics are never set out again.
func _full_shelf(t, root: String) -> void:
	var e := H.engine(t, root, 7, "full")
	var ctx := e.ctx
	var era := str(ctx.db.stage(0).get("era", ""))
	var free: Array = Array(ctx.db.pool(&"relic", era)).filter(func(id: String) -> bool:
		return ctx.test(ctx.db.def(id).get("conditions", {})))
	t.ok(free.size() > RelicApi.cap(ctx) + 1, "enough stage 0 relics to fill the shelf and still offer some")
	var first := RelicApi.take(ctx, str(free[0]), "", "test")
	if first == CardIds.ERR_NOT_IMPLEMENTED:
		t.eq(RelicApi.held_ids(ctx), PackedStringArray(), "RelicApi stub: nothing held")
		t.ok(not ctx.state.data.has("relic"), "RelicApi stub: no relic namespace")
		return
	t.eq(first, "", "RelicApi.take works (RG1 merged)")
	for i in range(1, RelicApi.cap(ctx)):
		t.eq(RelicApi.take(ctx, str(free[i]), "", "test"), "", "fill the shelf: " + str(free[i]))
	t.ok(RelicApi.is_full(ctx), "shelf full")
	t.ok(H.walk_to(e, 8, "day"), "full: day 8")
	H.trade(e)
	H.trade(e)
	t.ok(H.walk_to(e, 14, "settle"), "full: day 14 settle")
	var q: Dictionary = e.query(&"stocktake", {})
	t.eq(q.get("full"), true, "the query says full")
	t.eq((q.get("held", []) as Array).map(func(row: Dictionary) -> String: return str(row["id"])),
		Array(RelicApi.held_ids(ctx)), "the query lists the shelf in holding order")
	var relic := _first_of(q, "relic")
	t.ok(relic != "", "a relic is still offered")
	_none_of(t, q, RelicApi.held_ids(ctx), "held")
	var before := ctx.state.hash()
	t.eq(e.send(&"stock.pick", {"offer": "w0.1", "pick": relic}).get("err"), "relic_full", "full shelf, no replace")
	t.eq(e.send(&"stock.pick", {"offer": "w0.1", "pick": relic, "replace": "rl.nope"}).get("err"), "not_held",
		"replace something not on the shelf")
	t.eq(ctx.state.hash(), before, "refused picks change nothing")
	t.eq(H.offer(e, "w0.1").get("status"), "open", "the offer stays open")
	var out := str(RelicApi.held_ids(ctx)[0])
	var r: Dictionary = e.send(&"stock.pick", {"offer": "w0.1", "pick": relic, "replace": out})
	t.eq(r, {"ok": true, "err": "", "offer": "w0.1", "picked": relic, "kind": "relic", "released": out}, "swap")
	t.ok(RelicApi.held_ids(ctx).has(relic) and not RelicApi.held_ids(ctx).has(out), "the new one is on the shelf")
	t.ok(RelicApi.gone_ids(ctx).has(out), "the old one is given up")
	t.eq(str(e.view().get("open_panel", {}).get("kind", "")), "", "overlay closed")
	H.trade(e)
	H.trade(e)
	t.ok(H.walk_to(e, 15, "day"), "full: day 15")
	H.trade(e)
	H.trade(e)
	t.ok(H.walk_to(e, 21, "settle"), "full: day 21 settle")
	var q2: Dictionary = e.query(&"stocktake", {"offer": "w0.2"})
	_none_of(t, q2, RelicApi.held_ids(ctx), "held")
	_none_of(t, q2, RelicApi.gone_ids(ctx), "given up")
	t.no_leaks(q2, "full shelf query")


func _none_of(t, q: Dictionary, ids: PackedStringArray, label: String) -> void:
	for row in q.get("items", []):
		t.ok(not ids.has(str(row.get("id", ""))), "%s %s not offered again" % [label, row.get("id")])


# ---------------- helpers ----------------
func _report_has(a: CardEngine, key: String, args: Dictionary) -> bool:
	for row in a.query(&"settle_report").get("lines", []):
		if str(row.get("key", "")) == key and JSON.stringify(row.get("args", {}), "", true) == JSON.stringify(args, "", true):
			return true
	return false


func _spied_notice(spy, key: String) -> bool:
	for row in spy.log:
		if row[0] == &"notice" and str(row[1]) == key:
			return true
	return false


func _copy(a: CardEngine) -> CardCtx:
	var c := CardCtx.new()
	c.db = a.ctx.db
	c.ops = a.ctx.ops
	c.conds = a.ctx.conds
	c.mods = a.ctx.mods
	c.hooks = a.ctx.hooks
	c.actions = a.ctx.actions
	c.state = CardState.from_dict(a.ctx.state.to_dict())
	return c


func _has_item(q: Dictionary, id: String) -> bool:
	for row in q.get("items", []):
		if str(row.get("id", "")) == id:
			return true
	return false


func _relic_has_depth(q: Dictionary) -> bool:
	for row in q.get("items", []):
		if str(row.get("kind", "")) == "relic":
			return str(row.get("depth", "")) in ["plain", "storied", "treasure"]
	return false


func _first_of(q: Dictionary, kind: String) -> String:
	for row in q.get("items", []):
		if str(row.get("kind", "")) == kind:
			return str(row.get("id", ""))
	return ""


func _match_def(ctx: CardCtx, m: Dictionary) -> String:
	var era := str(ctx.db.stage(int(ctx.state.ns("loop").get("stage", 0))).get("era", ""))
	for id in ctx.db.pool(StringName(str(m.get("pool", ""))), era):
		if Mods._card_matches(m, ctx.db._cards[id]):
			return id
	return ""


func _intent_def(ctx: CardCtx, intent: String) -> String:
	return _match_def(ctx, {"pool": "person", "intents": [intent]})
