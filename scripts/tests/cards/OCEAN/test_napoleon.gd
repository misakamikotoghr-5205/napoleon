## Authored first-volume acceptance. No fixture book or state mutation is used.
## A single real trunk run is checkpointed at Elba, then its three routes are played with legal commands.
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const Book = preload("res://scripts/cards/campaign/run/run_book.gd")
const Policy = preload("res://scripts/tests/cards/OCEAN/napoleon_policy.gd")
const BOOK := "res://data/campaigns/napoleon/book.json"
const FAILURE := ["bankruptcy", "loss", "blockade", "exile", "obituary"]

var t: RefCounted
var _book: Dictionary = {}
var _checkpoint := ""
var _checkpoint_hash := ""
var _checkpoint_log: Array = []
var _trunk_scenes: Array = []
var _trunk_battles := 0
var _began_ms := 0


func _initialize() -> void:
	_began_ms = Time.get_ticks_msec()
	t = T.new(self, "OCEAN_napoleon")
	var loaded := Book.load_bundle(BOOK)
	t.ok(bool(loaded.get("ok", false)), "formal Napoleon content loads: " + str(loaded.get("err", loaded.get("path", ""))))
	if not bool(loaded.get("ok", false)):
		t.finish()
		return
	_book = loaded["book"]
	var checked := Book.validate(_book)
	t.eq(checked.get("errors", []), [], "formal book validates")
	if not (checked.get("errors", []) as Array).is_empty():
		print(JSON.stringify(checked))
		t.finish()
		return
	_structure()
	for argument in OS.get_cmdline_user_args():
		if argument == "--availability-only":
			_availability()
			t.finish()
			return
		if argument.begins_with("--route="):
			var route := argument.trim_prefix("--route=")
			_variant(route, {}, str({"conquest": "k_vol1_mercy", "cristo": "m_vol1_two", "ocean": "alliance"}.get(route, "")))
			print("OCEAN Napoleon assertions: %d; elapsed_ms=%d" % [t.checks, Time.get_ticks_msec() - _began_ms])
			t.finish()
			return
	if _trunk():
		for route in ["conquest", "ocean", "cristo"]:
			_branch(route)
		_variant("conquest", {"k_waterloo_night": "pursue_tonight"}, "k_vol1_pursuit")
		_variant("cristo", {"c_faria_dies": "sack_plan", "c_if_night": "to_tiboulen"}, "m_vol1")
		_variant("ocean", {"scene12": "choose_autonomy"}, "ghost")
		_availability()
	print("OCEAN Napoleon assertions: %d; elapsed_ms=%d" % [t.checks, Time.get_ticks_msec() - _began_ms])
	t.finish()


func _structure() -> void:
	t.eq(_book.get("id"), "napoleon", "authored book identity")
	t.eq(_book.get("volume"), 1, "first volume is selected")
	t.eq(_book.get("start"), "trunk", "new book starts at Toulon trunk")
	var segments: Array = _book.get("defs", {}).keys()
	segments.sort()
	t.eq(segments, ["conquest", "cristo", "ocean", "trunk"], "all three authored branches are installed")
	var counts := {"trunk": 8, "conquest": 6, "ocean": 4, "cristo": 5}
	var live := {"trunk": 8, "conquest": 1, "ocean": 4, "cristo": 2}
	var total := 0
	for seg in counts:
		var def: Dictionary = _book["defs"][seg]
		t.eq(def.get("chapters", []).size(), counts[seg], seg + " keeps the authored chapter plan")
		var active := 0
		for chapter in def.get("chapters", []):
			if int(chapter.get("volume", 1)) <= 1:
				active += 1
		t.eq(active, live[seg], seg + " exposes only the first-volume chapters")
		total += active
		t.eq(_book.get("maps", {}).get(seg, {}).get("sheets", []).size(), counts[seg], seg + " has all planned map sheets")
		t.ok(not _book.get("events", {}).get(seg, []).is_empty(), seg + " has authored events")
	var companions: Dictionary = _book.get("companions", {})
	t.eq(companions.size(), 28, "merged roster contains the authored 28 companions")
	t.eq(total, 15, "first volume has 15 playable map sheets")
	for seg in ["conquest", "cristo"]:
		var volume_endings: Array = _book["defs"][seg].get("endings", []).filter(func(e: Dictionary) -> bool: return str(e.get("kind", "fixed")) == "volume")
		t.ok(volume_endings.size() >= 2, seg + " has multiple authored first-volume conclusions")


func _new(label: String, extra: Dictionary = {}) -> CardEngine:
	var engine := CardEngine.new()
	var opts := {"book": BOOK, "seed": 30, "save_dir": t.user_dir() + "/" + label}
	opts.merge(extra, true)
	var result := engine.new_game(opts)
	t.ok(bool(result.get("ok", false)), "start formal " + label + ": " + str(result))
	return engine if bool(result.get("ok", false)) else null


func _round_trip(engine: CardEngine, label: String) -> bool:
	var path: String = t.user_dir() + "/" + label + ".json"
	var hash_before := engine.state_hash()
	var history := engine.command_log()
	var map_before := engine.query(&"campaign.map")
	var save := engine.save_game(path)
	t.ok(bool(save.get("ok", false)), label + " saves a real authored run")
	if not bool(save.get("ok", false)):
		return false
	var result := engine.load_game(path)
	t.ok(bool(result.get("ok", false)), label + " reloads: " + str(result))
	t.eq(engine.state_hash(), hash_before, label + " save/Continue state hash")
	t.eq(engine.command_log(), history, label + " save/Continue command history")
	t.eq(engine.query(&"campaign.map"), map_before, label + " save/Continue map")
	return bool(result.get("ok", false))


func _trunk() -> bool:
	var engine := _new("trunk")
	if engine == null:
		return false
	var policy := Policy.new()
	policy.branch = "trunk"
	t.eq(engine.query(&"campaign").get("scene_id"), "toulon_arrival", "formal new game begins in Toulon")
	if not _round_trip(engine, "toulon-start"):
		return false
	var good: bool = policy.finish(engine, 6000, "elba_1815")
	t.ok(good, "legal trunk traversal: " + policy.last_error)
	var c := engine.query(&"campaign")
	t.eq(c.get("scene_id"), "elba_1815", "eight-chapter trunk reaches the authored Elba fork")
	t.ok(c.get("ending_id", "") not in FAILURE, "white-sign trunk does not fail: " + str(c.get("ending_id", "")))
	if not good or str(c.get("scene_id", "")) != "elba_1815":
		_dump(policy, engine)
		return false
	t.eq(policy.chapters.size(), 8, "trunk policy traverses eight maps")
	t.ok(policy.battles.size() >= 8, "trunk fights its authored battle chain")
	t.ok(policy.battles.all(func(b: Dictionary) -> bool: return b.get("outcome") != "retreat"), "trunk battles are fought rather than automatically retreated")
	t.ok(policy.battles.any(func(b: Dictionary) -> bool: return b.get("outcome") == "victory"), "legal strategy wins authored battles")
	var offers: Array = engine.query(&"campaign.run").get("branch_offers", [])
	t.eq(offers.size(), 3, "fork exposes three named choices")
	for offer in offers:
		t.ok(bool(offer.get("ok", false)), "prepared trunk unlocks " + str(offer.get("segment", "")) + ": " + str(offer))
	_checkpoint = t.user_dir() + "/elba-fork.json"
	_checkpoint_hash = engine.state_hash()
	_checkpoint_log = engine.command_log()
	t.ok(engine.save_game(_checkpoint).get("ok", false), "save authored fork before choosing a branch")
	_trunk_scenes = policy.scenes.duplicate()
	_trunk_battles = policy.battles.size()
	print("NAPOLEON TRUNK COMPLETE scenes=%d chapters=%d battles=%d commands=%d" % [policy.scenes.size(), policy.chapters.size(), policy.battles.size(), policy.commands.size()])
	return true


func _branch(route: String) -> void:
	var engine := CardEngine.new()
	var loaded := engine.load_game(_checkpoint)
	t.ok(bool(loaded.get("ok", false)), route + " restores legal trunk checkpoint")
	if not bool(loaded.get("ok", false)):
		return
	t.eq(engine.state_hash(), _checkpoint_hash, route + " starts from identical trunk state")
	t.eq(engine.command_log(), _checkpoint_log, route + " retains the actual trunk history")
	var policy := Policy.new()
	policy.branch = route
	var good: bool = policy.finish(engine)
	t.ok(good, route + " legal authored route: " + policy.last_error)
	var c := engine.query(&"campaign")
	var ending := str(c.get("ending_id", ""))
	t.eq(engine.view().get("phase"), "game_over", route + " reaches a final first-volume screen")
	t.ok(ending not in FAILURE and ending != "", route + " reaches authored conclusion, not resource failure: " + ending)
	t.eq(engine.query(&"campaign.run").get("path"), ["trunk", route], route + " carries the trunk history into the selected segment")
	var expected := {"conquest": "k_vol1_mercy", "cristo": "m_vol1_two", "ocean": "alliance"}
	if expected.has(route):
		t.eq(ending, expected[route], route + " decisions choose the intended first-volume conclusion")
	t.ok(policy.battles.all(func(b: Dictionary) -> bool: return b.get("outcome") != "retreat"), route + " fights rather than bypasses its battles")
	if not good or ending in FAILURE:
		_dump(policy, engine)
	else:
		_round_trip(engine, route + "-ending")
	print("NAPOLEON ROUTE %s scenes=%d battles=%d commands=%d ending=%s" % [route, policy.scenes.size(), policy.battles.size(), policy.commands.size(), ending])


func _variant(route: String, choices: Dictionary, ending: String) -> void:
	var engine := _new(route + "-variant", {"segment": route, "stage": 0})
	if engine == null:
		return
	var policy := Policy.new()
	policy.branch = route
	policy.preferred.merge(choices, true)
	var good: bool = policy.finish(engine)
	t.ok(good, route + " alternative conclusion route: " + policy.last_error)
	if ending != "":
		t.eq(engine.query(&"campaign").get("ending_id"), ending, route + " alternative decisions reach another authored conclusion")
	else:
		t.ok(str(engine.query(&"campaign").get("ending_id", "")) not in FAILURE + [""], route + " reaches a non-failure conclusion")
	if not good or str(engine.query(&"campaign").get("ending_id", "")) != ending:
		_dump(policy, engine)
	print("NAPOLEON VARIANT %s ending=%s commands=%d" % [route, engine.query(&"campaign").get("ending_id", ""), policy.commands.size()])


func _availability() -> void:
	# Documented chapter starts use ordinary initial resources, then legal choices build the different histories.
	# Skipping optional training here makes a late-arriving officer distinct from the fully decorated trunk run.
	for stage in [7, 6]:
		var engine := _new("availability-" + str(stage), {"segment": "trunk", "stage": stage})
		if engine == null:
			continue
		var policy := Policy.new()
		policy.branch = "trunk"
		policy.train_for_campaign = false
		var good: bool = policy.finish(engine, 2500, "elba_1815")
		t.ok(good, "late trunk entry reaches branch choices: " + policy.last_error)
		var available: Array = []
		for offer in engine.query(&"campaign.run").get("branch_offers", []):
			if bool(offer.get("ok", false)):
				available.append(str(offer["segment"]))
			else:
				t.ok(str(offer.get("reason", "")) != "", "locked authored branch explains its condition")
		available.sort()
		t.eq(available, ["ocean"] if stage == 7 else ["cristo", "ocean"], "authored branch availability from legal stage " + str(stage))
		if not good:
			_dump(policy, engine)
		print("NAPOLEON OFFERS stage=%d segments=%s commands=%d" % [stage, available, policy.commands.size()])


func _dump(policy: RefCounted, engine: CardEngine) -> void:
	var c := engine.query(&"campaign")
	var m := engine.query(&"campaign.map")
	print("NAPOLEON STOP ", policy.last_error, " campaign=", JSON.stringify({"scene": c.get("scene_id"), "phase": c.get("phase"), "ending": c.get("ending_id"), "gauges": c.get("gauges"), "coins": c.get("coins")}), " map=", JSON.stringify(m))
	print("NAPOLEON LAST COMMANDS ", policy.commands.slice(maxi(0, policy.commands.size() - 12)))
	engine.save_game("/tmp/napoleon-failure-" + str(policy.branch) + ".json")
	var file := FileAccess.open("/tmp/napoleon-failure-" + str(policy.branch) + "-commands.json", FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(policy.commands))
