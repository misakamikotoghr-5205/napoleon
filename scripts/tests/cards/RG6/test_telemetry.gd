# RG6_telemetry: the balance observer's per-stage "stock" block (ROGUE_V1.md §14 RG6): offers counted once per offer
# id (week vs peddler, items per offer), what was offered, what was picked (relic / source / pass / replace), rejected
# picks, and the deals of each stocktake week from view.stock.week_deals. Mock bus first, then the real engine on the
# example set, where every stock counter stays zero and the G06 report keys are still there.
extends SceneTree
const T := preload("res://scripts/tests/cards/lib/card_t.gd")
const Telemetry := preload("res://scripts/cards/sim/telemetry.gd")
const Fair := preload("res://scripts/cards/sim/policies/fair.gd")
const FX := "res://scripts/tests/cards/RG6/fixtures/rogue_tele.json"
const STOCK_KEYS: Array = ["offers", "week_offers", "peddler_offers", "week_sizes", "peddler_sizes", "offered", "picked",
	"picked_kinds", "passed", "replaced", "rejected", "week_deals", "list"]


func _initialize() -> void:
	var t: RefCounted = T.new(self, "RG6_telemetry")
	_mock_flow(t)
	_real_examples(t)
	t.finish()


func _mock_flow(t: RefCounted) -> void:
	var bus := CardEventBus.new()
	var mock := MockCardEngine.new(bus)
	mock.load_fixture(FX)
	var tele: RefCounted = Telemetry.new()
	tele.attach(mock, mock.db)
	mock.new_game({})
	var stock: Dictionary = tele.stages["0"]["stock"]
	for key in STOCK_KEYS:
		t.ok(stock.has(key), "stock metric present " + key)
	t.eq(stock["offers"], 0, "no offer before the stocktake")
	t.ok(bool(mock.send(&"day.end", {"confirm": true}).get("ok", false)), "mock day.end into settle")
	t.eq(stock["offers"], 1, "the week offer is counted")
	t.eq(stock["week_offers"], 1, "it is a week offer")
	t.eq(stock["week_sizes"], {"3": 1}, "three items in it")
	t.eq(stock["offered"], {"rl.chen_mortar": 1, "ky.traveling_buyers": 1, "rl.blue_curtain": 1}, "offered ids")
	t.eq(stock["week_deals"], {"1": 3}, "day 14 settle records week 1 deals from view.stock.week_deals")
	t.ok(mock.send(&"card.choose", {"uid": "c0100", "choice": "look"}).get("ok", false), "mock look")
	t.eq(stock["offers"], 2, "the peddler offer is new; the re-requested week offer is not counted again")
	t.eq(stock["peddler_offers"], 1, "one peddler offer")
	t.eq(stock["peddler_sizes"], {"2": 1}, "two items from the peddler")
	t.eq(stock["offered"].get("rl.stub_box", 0), 1, "peddler items counted as offered")
	t.ok(not bool(mock.send(&"stock.pick", {"offer": "w0.1", "pick": "rl.nope"}).get("ok", true)), "mock rejects")
	t.eq(stock["rejected"], 1, "rejected pick counted")
	t.eq(stock["picked"], {}, "a rejected pick picks nothing")
	mock.send(&"stock.pick", {"offer": "w0.1", "pick": "rl.chen_mortar", "replace": "rl.stub_box"})
	mock.send(&"stock.pick", {"offer": "p8", "pick": ""})
	t.eq(stock["picked"], {"rl.chen_mortar": 1}, "picked ids")
	t.eq(stock["picked_kinds"], {"relic": 1, "source": 0}, "picked kinds come from the offer's items")
	t.eq(stock["replaced"], 1, "a replace is counted")
	t.eq(stock["passed"], 1, "the pass is counted")
	t.eq(stock["list"], [
		{"offer": "w0.1", "from": "week", "week": 1, "items": 3, "deals": 3, "picked": "rl.chen_mortar",
			"kind": "relic", "replaced": true},
		{"offer": "p8", "from": "peddler", "week": -1, "items": 2, "deals": 0, "picked": "", "kind": "",
			"replaced": false}], "per-offer rows")
	t.ok(t.find_floats(tele.stages).is_empty(), "integer-only report")
	mock.new_game({})
	mock.send(&"day.end", {"confirm": true})
	t.eq(stock["week_offers"], 2, "after game.new the same offer id is a new offer")
	bus.free()


func _real_examples(t: RefCounted) -> void:
	var bus := CardEventBus.new()
	var engine := CardEngine.new(bus)
	var tele: RefCounted = Telemetry.new()
	tele.attach(engine, CardDB.load_all("res://data/cards", {"only_examples": true}))
	t.ok(engine.new_game({"seed": 7, "only_examples": true, "save_dir": t.user_dir()}).get("ok", false), "real new game")
	var result: Dictionary = CardAutoplay.play(engine, Fair.new(7), {"days": 15, "max_steps": 6000})
	t.ok(bool(result.get("ok", false)), "fair plays 15 example days")
	t.ok(not tele.stages.is_empty(), "stage rows exist")
	for stage in tele.stages.values():
		var stock: Dictionary = stage.get("stock", {})
		for key in STOCK_KEYS:
			t.ok(stock.has(key), "real stock metric present " + key)
		t.eq([stock.get("offers"), stock.get("picked"), stock.get("week_deals"), stock.get("list")], [0, {}, {}, []],
			"examples: no rogue offers, picks or week deals")
		for key in ["stage", "cleared", "money_samples", "almanac", "steps"]:
			t.ok(stage.has(key), "G06 metric still present " + key)
	bus.free()
