# RG2_zero: with nothing to offer the module is invisible (ROGUE_V1.md §1, §3, §4.8). The examples set plays ten
# days without a "stock" namespace, without a "stock" view block and without ever requesting the stocktake overlay;
# adding rules/stock.json + rules/relics.json to a data set with no relic / source cards changes nothing but the
# data hash; with relic / source data, enabled = false or a missing rules/stock.json also keeps it all off, even
# when deals are made. Owner RG2.
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const H = preload("res://scripts/tests/cards/RG2/helper.gd")
const DAYS := 10


func _initialize() -> void:
	var t := T.new(self, "RG2_zero")
	_examples(t)
	_examples_with_rules(t)
	_off(t, "disabled", H.data_root(t, "disabled", {"enabled": false}))
	_off(t, "no_rules", H.data_root(t, "no_rules", {}, ["rules_stock.json"]))
	t.finish()


func _examples(t) -> void:
	var bus := CardEventBus.new()
	var spy = t.spy(bus)
	var e := H.engine(t, CardDB.DEFAULT_ROOT, 7, "ex", bus, {"only_examples": true})
	_walk_clean(t, e, "examples", true)
	t.eq(_stocktake_requests(spy), 0, "examples: the stocktake overlay is never requested")
	t.eq(e.query(&"stocktake", {}).get("err"), "not_allowed", "examples: nothing to query")
	t.eq(e.send(&"stock.pick", {"offer": "w0.0", "pick": ""}).get("err"), "not_allowed", "examples: stock.pick refused")
	t.ok(not e.ctx.state.data.has("stock"), "examples: a refused pick writes nothing")
	bus.free()


## Rules files present, no relic / source cards: the same game step for step (state equal apart from db_hash).
## Both sides are copies, so the baseline has no rules files whether or not the real data ships them (RG3).
func _examples_with_rules(t) -> void:
	var bare := H.data_root(t, "examples_plain", {}, H.FILES.keys())
	var plain := H.engine(t, bare, 7, "ex_plain", null, {"only_examples": true})
	var root := H.examples_root(t)
	var ruled := H.engine(t, root, 7, "ex_rules", null, {"only_examples": true})
	t.ok(plain.ctx.rules("stock").is_empty() and plain.ctx.rules("relics").is_empty(),
		"the baseline copy has neither rules/stock.json nor rules/relics.json")
	t.ok(not ruled.ctx.rules("stock").is_empty(), "the copy has rules/stock.json")
	t.ok(plain.ctx.db.hash() != ruled.ctx.db.hash(), "rules files are part of the data hash")
	var same := true
	for _i in range(DAYS * 4):
		plain.send(&"day.end", {"confirm": true})
		ruled.send(&"day.end", {"confirm": true})
		if _strip(plain) != _strip(ruled):
			same = false
			break
	t.ok(same, "with rules but no cards the state matches the plain examples run at every step")
	t.ok(not ruled.ctx.state.data.has("stock"), "still no stock namespace")
	t.ok(not ruled.view().has("stock"), "still no stock view")


## Real-shaped data with relics, sources and the peddler, but the module off: deals and settles write nothing.
func _off(t, tag: String, root: String) -> void:
	var bus := CardEventBus.new()
	var spy = t.spy(bus)
	var e := H.engine(t, root, 7, tag, bus)
	t.ok(H.walk_to(e, 2, "day"), tag + ": day 2")
	H.trade(e)
	H.trade(e)
	_walk_clean(t, e, tag, false)
	t.eq(_stocktake_requests(spy), 0, tag + ": the stocktake overlay is never requested")
	t.ok(e.ctx.db.ids_of(&"source").size() == 6, tag + ": the source data is there")
	bus.free()


func _walk_clean(t, e: CardEngine, label: String, from_start: bool) -> void:
	var start := H.stage_day(e) if not from_start else 0
	var leaked := false
	var has_stock := false
	var guard := 0
	while H.stage_day(e) < start + DAYS and H.phase(e) != "game_over" and guard < DAYS * 8:
		guard += 1
		var r: Dictionary = e.send(&"day.end", {"confirm": true})
		t.ok(bool(r.get("ok", false)), "%s: day.end %d" % [label, guard])
		var v := e.view()
		has_stock = has_stock or v.has("stock") or e.ctx.state.data.has("stock")
		leaked = leaked or not CardViewModel.leaks(v).is_empty()
		if str(v.get("open_panel", {}).get("kind", "")) == "stocktake":
			has_stock = true
	t.ok(H.stage_day(e) >= start + DAYS, "%s: walked %d days (now day %d)" % [label, DAYS, H.stage_day(e)])
	t.ok(not has_stock, label + ": no stock namespace, no stock view, no stocktake panel")
	t.ok(not leaked, label + ": views clean")


func _stocktake_requests(spy) -> int:
	var n := 0
	for row in spy.log:
		if row[0] == &"request_panel" and str(row[1]) == "stocktake":
			n += 1
	return n


func _strip(e: CardEngine) -> String:
	var d: Dictionary = e.ctx.state.to_dict()
	d.erase("db_hash")
	d.erase("ui")
	return JSON.stringify(d, "", true, true)
