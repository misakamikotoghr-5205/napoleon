# Contract 1.3 fuzz: public legal/invalid actions, both night-offer shapes, randomized closing, save/load and escape.
# Four disjoint seed ranges total 1000 games; every 25th seed crosses the month if alive.
# Rogue v1 (RG6, docs/cards/rogue/ROGUE_V1.md §14): the real relic, source and peddler cards are added to the private
# examples root, so the long games meet the weekly stocktake and the day-8 peddler and the fuzz also sends legal
# stock.pick (each item, each replace, the pass) besides the rejected shapes; each shard must open a stocktake.
extends SceneTree
const T := preload("res://scripts/tests/cards/lib/card_t.gd")
const Scenario := preload("res://scripts/tests/cards/G06/scenario.gd")
const Actions := preload("res://scripts/cards/sim/fuzz_actions.gd")
const Policy := preload("res://scripts/cards/sim/policy.gd")
const Probe := preload("res://scripts/tests/cards/G06/fuzz_helpers.gd")
## Rogue v1 card files copied from the real data into <root>/_examples (rules/relics.json and rules/stock.json come
## with the rules directory that Scenario.build copies).
const ROGUE_FILES: Array = ["era/common/relics.json", "era/common/sources.json", "era/1938/curio_peddler.json"]

## stock.pick sent by the fuzz (accepted / rejected) and stocktake offers met, over the whole shard.
var _stock: Dictionary = {"offers": 0, "picked": 0, "rejected": 0}


func _initialize() -> void:
	var args: Dictionary = _arguments()
	var t: RefCounted = T.new(self, str(args.get("name", "G06_no_deadlock")))
	_contract13_night_offers(t)
	var data_root: String = Scenario.build(t.user_dir() + "/data")
	_add_rogue(data_root)
	var first: int = int(args.get("seed_from", 1))
	var last: int = int(args.get("seed_to", first))
	var shared_engine: CardEngine = CardEngine.new()
	for seed_value in range(first, last + 1):
		var days: int = int(args.get("long_days", 32)) if seed_value % 25 == 0 else int(args.get("days", 6))
		shared_engine = _play(t, seed_value, days, data_root, shared_engine)
		if not t.fails.is_empty():
			break
		if seed_value % 25 == 0:
			print("FUZZ PROGRESS %d/%d" % [seed_value - first + 1, last - first + 1])
	print("FUZZ STOCK offers=%d picked=%d rejected=%d" % [_stock["offers"], _stock["picked"], _stock["rejected"]])
	t.ok(int(_stock["offers"]) > 0, "the shard's long games meet a stocktake offer")
	t.finish()


static func _add_rogue(root: String) -> void:
	for rel in ROGUE_FILES:
		var dst: String = root + "/_examples/" + str(rel)
		DirAccess.make_dir_recursive_absolute(dst.get_base_dir())
		var file: FileAccess = FileAccess.open(dst, FileAccess.WRITE)
		file.store_string(FileAccess.get_file_as_string("res://data/cards/" + str(rel)))
		file.close()


func _contract13_night_offers(t: RefCounted) -> void:
	var legacy: Dictionary = {"phase": "night", "night_offers": ["nt.legacy"],
		"night_offer_cards": [{"def": "nt.legacy", "choices": [{"id": "ignored_old_detail"}]}]}
	var modern: Dictionary = {"phase": "night", "night_offers": [
		{"def": "nt.modern", "art": "card.back", "choices": ["rest", {"id": "work"}]}]}
	var fuzz_legacy: Array = Actions._phase_actions(legacy)
	var fuzz_modern: Array = Actions._phase_actions(modern)
	t.ok(_has_night_action(fuzz_legacy, "nt.legacy"), "fuzz accepts legacy string night offer")
	t.ok(not _has_night_action(fuzz_legacy, "nt.legacy", "ignored_old_detail"),
		"legacy string has no implicit choices")
	t.ok(_has_night_action(fuzz_modern, "nt.modern", "rest")
		and _has_night_action(fuzz_modern, "nt.modern", "work"),
		"fuzz reads choices from dictionary night offer")
	var policy: RefCounted = Policy.new(7)
	var policy_legacy: Array = policy._candidates(null, legacy)
	var policy_modern: Array = policy._candidates(null, modern)
	t.ok(_has_night_action(policy_legacy, "nt.legacy"), "policy accepts legacy string night offer")
	t.ok(_has_night_action(policy_modern, "nt.modern", "rest")
		and _has_night_action(policy_modern, "nt.modern", "work"),
		"policy reads choices from dictionary night offer")


func _has_night_action(actions: Array, def_id: String, choice: Variant = null) -> bool:
	for action in actions:
		if action.size() != 2 or str(action[0]) != "night.choose":
			continue
		var args: Dictionary = action[1]
		if str(args.get("def", "")) != def_id:
			continue
		if choice == null:
			return not args.has("choice")
		if str(args.get("choice", "")) == str(choice):
			return true
	return false


var _eng_a: CardEngine = null
var _eng_b: CardEngine = null


func _play(t: RefCounted, seed_value: int, days: int, data_root: String, engine: CardEngine = null) -> CardEngine:
	var opts: Dictionary = {"seed": seed_value, "only_examples": true,
		"data_root": data_root, "save_dir": t.user_dir()}
	if _eng_a == null:
		_eng_a = engine if engine != null else CardEngine.new()
	if _eng_b == null:
		_eng_b = CardEngine.new()
	if engine == null:
		engine = _eng_a
	t.ok(bool(engine.new_game(opts).get("ok", false)), "fuzz new game")
	var target: int = int(engine.view().get("date", {}).get("abs_day", 0)) + days
	var step: int = 0
	var terminal: bool = false
	var offers_seen: Dictionary = {}
	while step < days * 100 + 300:
		var view: Dictionary = engine.view()
		var prev: Dictionary = Probe.preview(t, engine)
		t.no_leaks(view, "fuzz view")
		var open_offer: String = str(view.get("stock", {}).get("open", ""))
		if open_offer != "" and not offers_seen.has(open_offer):
			offers_seen[open_offer] = true
			_stock["offers"] = int(_stock["offers"]) + 1
		t.ok(t.find_floats(engine.ctx.state.data).is_empty(), "integer-only state")
		if str(view.get("phase", "")) == "game_over":
			if seed_value % 50 == 0:
				Probe.replay(t, engine, opts)
			Probe.terminal_recovery(t, engine, opts)
			terminal = true
			break
		if int(view.get("date", {}).get("abs_day", 0)) >= target:
			break
		if step > 0 and step % 25 == 0:
			Probe.escape(t, engine, prev, view)
			view = engine.view()
			if str(view.get("phase", "")) == "game_over":
				step += 1
				continue
			prev = {}
		if str(view.get("phase", "")) == "morning" \
				and JevRng.draw(seed_value, "c.ai.fuzz", [seed_value, step, 3]) < 0.3:
			engine = _save_load(t, engine, opts)
			view = engine.view()
			prev = {}
		var action: Array = Actions.select(engine, seed_value, step, view)
		if str(action[0]) == "day.end":
			Probe.end_step(t, engine, bool(action[1].get("confirm", false)), prev, view)
		elif str(action[0]) == "stock.pick":
			_stock_pick(t, engine, action[1])
		else:
			engine.send(StringName(str(action[0])), action[1])
		step += 1
		if not t.fails.is_empty():
			break
	if not terminal and t.fails.is_empty():
		t.ok(int(engine.view().get("date", {}).get("abs_day", 0)) >= target, "fuzz reaches target day or terminal")
		if seed_value % 50 == 0:
			Probe.replay(t, engine, opts)
	if not t.fails.is_empty():
		var log: Array = CardReplay.record(engine)
		print("FUZZ FAILURE seed=%d step=%d phase=%s last20=%s" % [seed_value, step,
			engine.view().get("phase", ""), JSON.stringify(log.slice(maxi(0, log.size() - 20)))])
	return engine


## Rogue v1: a stock.pick never changes the state when it is rejected, and its result passes leaks().
func _stock_pick(t: RefCounted, engine: CardEngine, args: Dictionary) -> void:
	var before: String = engine.state_hash()
	var result: Dictionary = engine.send(&"stock.pick", args)
	t.no_leaks(result, "stock.pick result")
	if bool(result.get("ok", false)):
		_stock["picked"] = int(_stock["picked"]) + 1
	else:
		_stock["rejected"] = int(_stock["rejected"]) + 1
		t.eq(engine.state_hash(), before, "rejected stock.pick (%s) leaves the state alone" % result.get("err", ""))


func _save_load(t: RefCounted, engine: CardEngine, opts: Dictionary) -> CardEngine:
	var path: String = t.user_dir() + "/fuzz_snapshot.json"
	var before: Dictionary = Probe.continuation_state(engine)
	t.ok(bool(engine.send(&"game.save", {"path": path}).get("ok", false)), "random morning save")
	var restored: CardEngine = _eng_b if engine == _eng_a else _eng_a
	t.ok(bool(restored.new_game(opts).get("ok", false)), "fresh facade for load")
	t.ok(bool(restored.send(&"game.load", {"path": path}).get("ok", false)), "random morning load")
	var after: Dictionary = Probe.continuation_state(restored)
	t.eq(after, before, "random fresh load preserves mechanics, resume normalized")
	if not t.fails.is_empty():
		var diffs: Array = Probe.differences(before, after)
		if not diffs.is_empty():
			print("FUZZ SAVE DIFF " + JSON.stringify(diffs.slice(0, 10)))
	return restored


func _arguments() -> Dictionary:
	var args: Dictionary = {}
	for arg in OS.get_cmdline_user_args():
		if str(arg).begins_with("--"):
			var parts: PackedStringArray = str(arg).trim_prefix("--").split("=", true, 1)
			args[parts[0]] = parts[1] if parts.size() == 2 else true
	return args
