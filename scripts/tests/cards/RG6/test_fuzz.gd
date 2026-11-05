# RG6_fuzz: the fuzz selector knows stock.pick (ROGUE_V1.md §4.2, §14 RG6). Legal picks come from the stocktake query
# (the pass, every item, every held relic as the replace); three rejected shapes are in invalid_actions. On the example
# set (no rogue data) no pick is ever legal, the rejected shapes fail without touching the state, and select() runs on.
extends SceneTree
const T := preload("res://scripts/tests/cards/lib/card_t.gd")
const Actions := preload("res://scripts/cards/sim/fuzz_actions.gd")
const FX := "res://scripts/tests/cards/RG6/fixtures/"
const INVALID_PICKS: Array = [{"offer": "w9.9", "pick": ""}, {"offer": "w0.0", "pick": "rl.nope"}, {}]


func _initialize() -> void:
	var t: RefCounted = T.new(self, "RG6_fuzz")
	_invalid(t)
	_week(t)
	_full(t)
	_closed_and_dormant(t)
	_real_examples(t)
	t.finish()


func _mock(name: String) -> MockCardEngine:
	var mock := MockCardEngine.new()
	mock.load_fixture(FX + name + ".json")
	return mock


func _picks(actions: Array) -> Array:
	var out: Array = []
	for action in actions:
		if str(action[0]) == "stock.pick":
			out.append(action[1])
	return out


func _invalid(t: RefCounted) -> void:
	var bad: Array = Actions.invalid_actions()
	var picks: Array = _picks(bad)
	t.eq(picks, INVALID_PICKS, "invalid_actions carries the three rejected stock.pick shapes")
	t.ok(bad.size() == 13, "the ten pre-rogue invalid actions are kept")
	for action in bad:
		t.ok(action.size() == 2 and typeof(action[1]) == TYPE_DICTIONARY, "invalid action shape " + str(action[0]))


func _week(t: RefCounted) -> void:
	var mock := _mock("rogue_week")
	var view: Dictionary = mock.view()
	var want: Array = [{"offer": "w0.1", "pick": ""},
		{"offer": "w0.1", "pick": "rl.chen_mortar"},
		{"offer": "w0.1", "pick": "rl.chen_mortar", "replace": "rl.stub_box"},
		{"offer": "w0.1", "pick": "rl.chen_mortar", "replace": "rl.oilpaper_umbrella"},
		{"offer": "w0.1", "pick": "ky.traveling_buyers"},
		{"offer": "w0.1", "pick": "rl.blue_curtain"},
		{"offer": "w0.1", "pick": "rl.blue_curtain", "replace": "rl.stub_box"},
		{"offer": "w0.1", "pick": "rl.blue_curtain", "replace": "rl.oilpaper_umbrella"}]
	t.eq(_picks(Actions.stock_actions(mock)), want, "picks from the stocktake query: pass, items, swaps")
	var legal: Array = Actions.legal_actions(mock, view)
	t.eq(_picks(legal), want, "legal_actions includes the stocktake picks")
	t.ok(legal.has([&"settle.next", {}]), "settle.next stays legal next to the picks")
	for action in legal:
		t.ok(not str(action[0]).begins_with("ui."), "no ui.* in legal actions")
	var seen: Dictionary = {}
	for step in range(400):
		var action: Array = Actions.select(mock, 3, step, view)
		t.ok(action.size() == 2 and typeof(action[1]) == TYPE_DICTIONARY, "select returns [cmd, args]")
		if str(action[0]) == "stock.pick":
			seen[JSON.stringify(action[1], "", true)] = true
	t.ok(seen.size() >= 6, "select reaches legal and rejected stock.pick shapes (%d seen)" % seen.size())


func _full(t: RefCounted) -> void:
	var mock := _mock("rogue_full")
	var picks: Array = _picks(Actions.stock_actions(mock))
	t.eq(picks.size(), 1 + 3 + 2 * 6, "full shelf: pass + three items + six swaps for each relic")
	t.ok(picks.has({"offer": "w0.1", "pick": "rl.chen_mortar"}), "full shelf: the bare relic pick (relic_full) is fuzzed")
	t.ok(picks.has({"offer": "w0.1", "pick": "rl.chen_mortar", "replace": "rl.camphor_chest"}), "any held one swaps")
	t.ok(not picks.has({"offer": "w0.1", "pick": "ky.traveling_buyers", "replace": "rl.stub_box"}),
		"sources never carry a replace")


func _closed_and_dormant(t: RefCounted) -> void:
	t.ok(Actions.stock_actions(_mock("rogue_closed")).is_empty(), "lapsed offer: no picks")
	t.ok(Actions.stock_actions(_mock("rogue_peddler_card")).is_empty(), "no open offer: no picks")
	var base := MockCardEngine.new()
	base.load_fixture("settle")
	t.ok(_picks(Actions.legal_actions(base, base.view())).is_empty(), "W0 settle fixture: no stocktake query, no picks")


## Real engine, example set: rogue modules stay dormant, rejected picks change nothing, selection keeps going.
func _real_examples(t: RefCounted) -> void:
	var engine := CardEngine.new()
	t.ok(bool(engine.new_game({"seed": 7, "only_examples": true, "save_dir": t.user_dir()}).get("ok", false)), "new game")
	var step: int = 0
	var target: int = int(engine.view().get("date", {}).get("abs_day", 0)) + 4
	while step < 600 and int(engine.view().get("date", {}).get("abs_day", 0)) < target:
		var view: Dictionary = engine.view()
		if str(view.get("phase", "")) == "game_over":
			break
		t.ok(_picks(Actions.legal_actions(engine, view)).is_empty(), "examples: no legal stock.pick")
		if step % 20 == 0:
			_rejected_picks(t, engine)
		var action: Array = Actions.select(engine, 7, step, view)
		engine.send(StringName(str(action[0])), action[1])
		step += 1
	t.ok(step > 10, "fuzz steps ran on the example set")
	t.ok(not engine.ctx.state.data.has("stock") and not engine.ctx.state.data.has("relic"),
		"examples: no rogue namespace was created")


func _rejected_picks(t: RefCounted, engine: CardEngine) -> void:
	for args in INVALID_PICKS:
		var before: String = engine.state_hash()
		var result: Dictionary = engine.send(&"stock.pick", args)
		t.ok(not bool(result.get("ok", true)), "rejected pick %s" % JSON.stringify(args))
		t.eq(engine.state_hash(), before, "a rejected pick leaves the state alone")
