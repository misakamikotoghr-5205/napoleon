## Second-volume authored maps, power chains, active orders and recorded legal strategies.
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const R = preload("res://scripts/cards/campaign/battle/battle_rules.gd")
const NEW := ["marengo", "eylau", "wagram", "fort_bard", "ulm", "jena", "somosierra", "aspern", "krasnoi", "dresden", "hanau",
	"brussels", "rhine_crossing", "vienna_streets", "iberia_return", "channel_landing", "niemen", "coalition_final",
	"janina_lake", "tiboulen_swim", "monte_cristo_cave", "appian_way", "san_sebastiano", "auteuil_garden", "paris_rooftops", "cristo_final",
	"skirmish_desert_well", "skirmish_sierra_village", "skirmish_snow_village", "skirmish_rhine_ferry", "skirmish_danube_mill"]

var t: RefCounted
var cases := 0


func _initialize() -> void:
	t = T.new(self, "OCEAN_battle_volume2")
	var began := Time.get_ticks_msec()
	var library := R.load_templates(true)
	t.eq(library.get("errors", []), [], "complete volume-two battle library validates")
	if not bool(library.get("ok", false)):
		t.finish()
		return
	t.eq(NEW.size(), 31, "26 authored fixed battlefields and five regional encounters")
	_power_chains()
	_references()
	for id in NEW:
		t.ok(library["templates"].has(id), "authored battle exists: " + id)
		if not library["templates"].has(id):
			continue
		var tpl: Dictionary = library["templates"][id]
		var level := int(tpl.get("level", tpl.get("base_level", 1)))
		t.eq(tpl.get("volume"), 2, id + " records its content generation")
		t.eq(R.validate_template(tpl), [], id + " has legal geometry, waves and order")
		for weather in tpl.get("weather", ["clear"]):
			var setup := {"seed": 1, "level": level, "volume": 2, "weather": str(weather), "roster": [], "troops": [],
				"protagonist": {"enabled": false}}
			var empty := R.new_battle(id, setup)
			t.ok(not empty.has("error"), id + " starts with second-volume rules")
			if empty.has("error"):
				continue
			if tpl.has("order_next"):
				t.eq(empty.get("order_goal", {}).get("type"), tpl["order_next"]["type"], id + " runs its authored objective")
			var result := _finish(empty)
			t.eq(result.get("outcome"), "defeat", id + " idle play loses")
			t.eq(t.find_floats(result), PackedStringArray(), id + " results contain no floats")
			t.eq(_finish(R.new_battle(id, setup)), result, id + " same seed repeats exactly")
			_hero_positions(id, tpl, setup, level)
	print("OCEAN battle volume2 assertions: %d; hero cases: %d; ms: %d" % [t.checks, cases, Time.get_ticks_msec() - began])
	t.finish()


func _power_chains() -> void:
	var chains := [
		[["rivoli_plateau",3],["marengo",5],["eylau",7],["wagram",9],["berezina",10],["leipzig",11]],
		[["waterloo",14],["rhine_crossing",16],["vienna_streets",18],["iberia_return",20],["niemen",22],["coalition_final",24]],
		[["waterloo",14],["rhine_crossing",16],["vienna_streets",18],["channel_landing",20],["niemen",22],["coalition_final",24]],
		[["marseille_arrest",14],["if_corridors",16],["monte_cristo_cave",18],["san_sebastiano",21],["cristo_final",24]],
	]
	for chain in chains:
		var previous := 0
		for battle in chain:
			var current := R.power(battle[0], battle[1])
			t.ok(current > 0 and current * 100 >= previous * 112, str(battle[0]) + " keeps the 12-percent boss progression")
			previous = current


func _references() -> void:
	# These recordings check combat and preparation limits with compatibility orders.
	# Active V2 orders are checked below and in the dedicated objective/route suites.
	var raw = JSON.parse_string(FileAccess.get_file_as_string("res://tools/napoleon/volume2_winning_plans.json"))
	var plans: Dictionary = R._ints(raw).get("plans", {})
	var people: Dictionary = R._ints(JSON.parse_string(FileAccess.get_file_as_string("res://data/campaigns/napoleon/companions.json")))["companions"]
	t.eq(plans.size(), NEW.size(), "every new battlefield has a recorded reference victory")
	for id in plans:
		t.ok(id in NEW, "reference belongs to a new authored template")
		var plan: Dictionary = plans[id]
		var setup: Dictionary = plan["setup"]
		var state := R.new_battle(id, setup)
		t.ok(not state.has("error"), id + " reference starts")
		if state.has("error"):
			continue
		var caps := R.caps(str(state["scale"]), int(setup["level"]))
		t.ok(setup.get("roster", []).size() <= int(caps["companions"]), id + " reference respects companion capacity")
		t.ok(setup.get("roster", []).size() + setup.get("troops", []).size() <= int(caps["field"]), id + " reference respects total lineup capacity")
		t.ok(int(setup.get("cp_bonus", 0)) <= 7 and int(setup.get("morale", 10)) <= 11, id + " preparation uses campaign limits")
		for companion in setup.get("roster", []):
			var profile: Dictionary = people.get(str(companion["id"]), {}).get("battle", {})
			t.ok(not profile.is_empty(), id + " reference uses a formal companion")
			if profile.is_empty():
				continue
			for stat in ["hp", "atk", "def", "block", "cost"]:
				var expected := int(profile[stat])
				if int(setup["level"]) >= 13:
					expected += 50 if stat == "hp" else (12 if stat == "atk" else 0)
				elif stat in ["hp", "atk", "def"]:
					expected = expected * (100 + 5 * (int(setup["level"]) - 1)) / 100
				t.eq(companion[stat], expected, id + " reference follows documented R(L) / existing promotion: " + stat)
		for command in plan["commands"]:
			var applied := R.apply(state, command[0], command[1])
			t.ok(bool(applied.get("ok", false)), id + " legal reference command: " + str(command[0]))
		t.eq(R.result(state).get("outcome"), "victory", id + " reference wins")
		t.eq(R.result(state), plan["expected_result"], id + " recorded strategy is reproducible")


func _finish(state: Dictionary) -> Dictionary:
	for _i in 24:
		if state.get("phase") != "command":
			break
		R.apply(state, "fight", {})
	return R.result(state)


func _hero_positions(id: String, _tpl: Dictionary, base: Dictionary, level: int) -> void:
	var setup := base.duplicate(true)
	setup["protagonist"] = {"enabled": true, "hp": R.hero_hp(level, 24), "max_hp": R.hero_hp(level, 24)}
	var probe := R.new_battle(id, setup)
	var winners: Array = []
	for row in int(probe["rows"]):
		for col in int(probe["cols"]):
			if R._place_err(probe, probe["units"]["hero"], col, row) != "":
				continue
			for direction in ["up", "right", "down", "left"]:
				var state := R.new_battle(id, setup)
				var deployed := R.apply(state, "deploy", {"unit": "hero", "col": col, "row": row, "facing": direction})
				if not bool(deployed.get("ok", false)):
					winners.append("unexpected invalid deployment")
					continue
				cases += 1
				if _finish(state).get("outcome") != "defeat":
					winners.append([R._label(col, row), direction])
	t.eq(winners, [], id + " hero alone loses at every legal tile and facing")
