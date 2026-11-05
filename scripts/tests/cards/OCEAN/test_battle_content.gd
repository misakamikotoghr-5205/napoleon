## The authored first-volume battle library: actual rules validation, increasing
## boss power, deterministic outcomes, and no victory from idle / lone-hero play.
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const R = preload("res://scripts/cards/campaign/battle/battle_rules.gd")
const LEGACY := ["arcole", "rivoli", "skirmish_a", "skirmish_b", "skirmish_c", "elite_a", "major_a"]
const TRUNK := [["toulon_night", 1], ["rivoli_plateau", 3], ["acre", 5], ["austerlitz", 7],
	["saragossa", 9], ["berezina", 10], ["leipzig", 11], ["elba_cove", 12]]
const BRANCHES := [ [["waterloo", 14]], [["bellerophon_deck", 13], ["longwood_escape", 16],
	["skull_reef", 20], ["thames_estuary", 24]], [["marseille_arrest", 14], ["if_corridors", 16]] ]

var t: RefCounted
var hero_cases := 0
var _bonds: Array = []


func _initialize() -> void:
	t = T.new(self, "OCEAN_battle_content")
	var started := Time.get_ticks_msec()
	var library := R.load_templates(true)
	t.eq(library.get("errors"), [], "all runtime templates and named bonds validate")
	t.ok(library.get("templates", {}).size() >= 53, "seven original and 46 first-volume templates are installed")
	if not bool(library.get("ok", false)):
		t.finish()
		return
	_test_power_chain()
	_test_reference_wins()
	var bonds: Array = library.get("bond_sets", {}).get("napoleon", [])
	_bonds = bonds
	t.ok(not bonds.is_empty(), "the full book has its own battle bond set")
	t.eq(R.validate_bonds(bonds), [], "Napoleon bonds use supported effects and ranks")
	for key in library["templates"]:
		if str(key) in LEGACY:
			continue
		var template: Dictionary = library["templates"][key]
		_test_battle(str(key), template)
	print("OCEAN battle content assertions: %d; lone hero cases: %d; ms: %d" % [t.checks, hero_cases, Time.get_ticks_msec() - started])
	t.finish()


func _test_reference_wins() -> void:
	var raw = JSON.parse_string(FileAccess.get_file_as_string("res://tools/napoleon/trunk_winning_plans.json"))
	var plans: Dictionary = R._ints(raw).get("plans", {})
	t.eq(plans.size(), 8, "each new trunk map has a recorded playable reference strategy")
	for id in plans:
		var plan: Dictionary = plans[id]
		var setup: Dictionary = plan["setup"]
		t.ok(int(setup.get("cp_bonus", 0)) <= 7, "%s reference preparation uses legal supply/early-march command points" % id)
		var state := R.new_battle(str(id), setup)
		t.ok(not state.has("error"), "%s reference battle starts" % id)
		if state.has("error"):
			continue
		var cap := R.caps(str(state["scale"]), int(setup["level"]))
		t.ok(setup.get("roster", []).size() <= int(cap["companions"]), "%s reference respects companion capacity" % id)
		t.ok(setup.get("roster", []).size() + setup.get("troops", []).size() <= int(cap["field"]), "%s reference respects total campaign lineup capacity" % id)
		for command in plan["commands"]:
			var result := R.apply(state, str(command[0]), command[1])
			t.ok(bool(result.get("ok", false)), "%s reference command succeeds: %s" % [id, command[0]])
		var result := R.result(state)
		t.eq(result.get("outcome"), "victory", "%s reference strategy wins" % id)
		t.eq(result, plan["expected_result"], "%s reference commands reproduce the recorded result" % id)


func _test_power_chain() -> void:
	var previous := 0
	for row in TRUNK:
		var power := R.power(row[0], row[1])
		t.ok(power > 0 and power * 100 >= previous * 112, "%s has at least 12 percent more boss power" % row[0])
		previous = power
	t.ok(previous <= 359, "Elba stays below the first ocean boss power ceiling")
	for chain in BRANCHES:
		var power := previous
		for row in chain:
			var next_power := R.power(row[0], row[1])
			t.ok(next_power * 100 >= power * 112, "%s continues the boss power curve" % row[0])
			power = next_power


func _finish_battle(state: Dictionary) -> Dictionary:
	for _step in 30:
		if str(state.get("phase", "")) != "command":
			break
		R.apply(state, "fight", {})
	return R.result(state)


func _setup(template: Dictionary, level: int, weather: String, hero: bool) -> Dictionary:
	return {"template": template, "seed": 1, "level": level, "weather": weather, "roster": [], "troops": [],
		"bonds": _bonds, "protagonist": {"enabled": hero, "hp": R.hero_hp(level, 24), "max_hp": R.hero_hp(level, 24)}}


func _test_battle(id: String, template: Dictionary) -> void:
	var level := int(template.get("level", template.get("base_level", 1)))
	t.eq(R.validate_template(template), [], "%s validates" % id)
	t.ok(str(template.get("order", {}).get("type", "")) in ["hold", "no_leak"], "%s has a playable first-volume order" % id)
	if template.has("order_next"):
		t.ok(str(template["order_next"]["type"]) in ["extract", "protect", "escape"], "future orders remain explicit proposals")
	for weather in template.get("weather", ["clear"]):
		var setup := _setup(template, level, str(weather), false)
		var idle := R.new_battle(id, setup)
		t.ok(not idle.has("error"), "%s/%s starts in the actual rules engine" % [id, weather])
		if idle.has("error"):
			continue
		var result := _finish_battle(idle)
		t.eq(result.get("outcome"), "defeat", "%s/%s cannot win by only pressing fight" % [id, weather])
		t.eq(t.find_floats(result), PackedStringArray(), "%s result contains only integer numeric state" % id)
		t.eq(_finish_battle(R.new_battle(id, setup)), result, "%s same seed repeats exactly" % id)
		_test_hero_positions(id, template, level, str(weather))


func _test_hero_positions(id: String, template: Dictionary, level: int, weather: String) -> void:
	var setup := _setup(template, level, weather, true)
	var probe := R.new_battle(id, setup)
	var victories: Array = []
	for row in int(probe["rows"]):
		for col in int(probe["cols"]):
			if R._place_err(probe, probe["units"]["hero"], col, row) != "":
				continue
			for facing in ["left", "right", "up", "down"]:
				var state := R.new_battle(id, setup)
				var deployed := R.apply(state, "deploy", {"unit": "hero", "col": col, "row": row, "facing": facing})
				if not bool(deployed.get("ok", false)):
					victories.append("unexpected invalid deployment")
					continue
				hero_cases += 1
				var result := _finish_battle(state)
				if str(result.get("outcome", "")) != "defeat":
					victories.append([R._label(col, row), facing, result.get("outcome")])
	t.eq(victories, [], "%s/%s lone hero loses at every valid cell and facing" % [id, weather])
