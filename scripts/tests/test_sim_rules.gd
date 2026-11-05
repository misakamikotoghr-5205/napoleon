extends SceneTree

const R = preload("res://scripts/sim/jev_rng.gd")
const Cond = preload("res://scripts/sim/town_cond.gd")
const Wheel = preload("res://scripts/sim/world_wheel.gd")
const Pack = preload("res://scripts/sim/town_pack.gd")

class ConditionWorld extends RefCounted:
	var flags: Dictionary = {"world_only": true, "shared": false}
	var stats: Dictionary = {"koubei": 70.0}
	var npcs: Dictionary = {"chen": {"rel": {"player": {"trust": 0.8}}}}

var failures: Array[String] = []
var checks: int = 0
var captured_effects: Array = []


func _init() -> void:
	_rng()
	_conditions()
	_wheels()
	_pack()
	for failure in failures:
		print("FAIL: ", failure)
	print("SIM RULES: ", "PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)


func _rng() -> void:
	# Independent Python hashlib/json vectors, compared exactly rather than with a tolerance.
	var vectors: Array = [
		[42, "wheel:climate", [1], 0.06858027750188644],
		[42, "wheel:logistics", [3], 0.16148672144953713],
		[19380306, "wheel:town_weather", [12], 0.2881390520385281],
		[19380306, "message_relay", ["event:7", "zhouma", "linsao", 1], 0.232507020285863],
		[19380306, "visit", [3, "xiaoding"], 0.9976656631889068],
		[19380306, "轮盘:米价", [5, "德厚当"], 0.953220035114062],
		[42, "转义\"\\\n\t", [0, -1, "德厚当\b\f\r", true, false, [17, "桥头街"]], 0.8012126729556828],
		[-3, "中文🌾", [9223372036854775807, "药价", false], 0.8103730093674074],
	]
	for vector in vectors:
		var actual: float = R.draw(int(vector[0]), str(vector[1]), vector[2])
		check(actual == float(vector[3]), "Python draw vector: " + str(vector[1]))
		check(actual >= 0.0 and actual < 1.0, "draw lies in [0, 1)")
	check(R.replay_draw(42, "A", 0) == 0.6700750373336426, "Python persona replay vector")
	check(R.replay_draw(19380306, "德厚当", 9) == 0.7366040063636254, "Python Chinese persona replay vector")
	check(R.replay_draw(-5, "陈文庭", 100) == 0.6972409092202583, "Python negative-seed persona replay vector")
	check(R.canon([1, "米", true, false, [2, "街"]]) == "[1,\"米\",true,false,[2,\"街\"]]", "canonical JSON preserves Chinese and nesting")
	var saved_key: Array = JSON.parse_string(JSON.stringify([1, "米", [2, "街"]]))
	check(R.draw(42, "save", saved_key) == R.draw(42, "save", [1, "米", [2, "街"]]), "JSON integer coercion preserves semantic draws")
	var weighted: Array = [["quiet", 8.0], ["clear", 3.0], ["rain", 2.0], ["gale", 0.5]]
	check(R.weighted_choice(weighted, 0.9) == "rain", "Python weighted-choice vector")
	check(R.weighted_choice([["zero", 0.0], ["first", 1.0], ["second", 1.0]], 0.0) == "first", "zero-weight leading row never selected")
	check(R.weighted_choice([["first", 1.0], ["second", 1.0], ["zero", 0.0]], 0.5) == "second", "weighted boundary belongs to the next row")
	check(R.weighted_choice([["first", 1.0], ["second", 1.0], ["zero", 0.0]], 1.0 - 1.0 / R.TWO_53) == "second", "zero-weight tail never selected")


func _conditions() -> void:
	var pack: Dictionary = {"time": {"start_weekday": 2, "season_days": 7, "season_count": 4}}
	var state: Dictionary = {
		"day": 8, "weather": "雨", "flags": {"local": true, "shared": true},
		"flags_today": {"today": true}, "stats": {"koubei": 50.0},
		"pressures": {"heat": 0.3}, "unlocked": {"police": true, "sunfu": false},
		"npc_rel": {"chen": {"trust": 0.6}},
	}
	var cases: Array = [
		[null, true], [{}, true], [{"all": []}, true], [{"any": []}, false],
		[{"all": [{"day_gte": 8}, {"weather": "雨"}]}, true],
		[{"all": [{"day_gte": 9}, {"weather": "雨"}]}, false],
		[{"any": [{"weather": "晴"}, {"not": {"day_gte": 9}}]}, true],
		[{"not": {"weather": "雨"}}, false], [{"day_gte": 8}, true], [{"day_gte": 9}, false],
		[{"weekday": 3}, true], [{"weekday": 2}, false], [{"season": 1}, true], [{"season": 0}, false],
		[{"weather": "雨"}, true], [{"weather": "晴"}, false],
		[{"flag": "local"}, true], [{"flag": "today"}, true], [{"flag": "absent"}, false],
		[{"stat_gte": ["koubei", 50]}, true], [{"stat_gte": ["koubei", 51]}, false],
		[{"pressure_gte": ["heat", 0.3]}, true], [{"pressure_gte": ["heat", 0.31]}, false],
		[{"building": "police"}, true], [{"building": "sunfu"}, false], [{"building": "missing"}, false],
		[{"npc_rel_gte": ["chen", "trust", 0.6]}, true], [{"npc_rel_gte": ["chen", "trust", 0.61]}, false],
		[{"npc_rel_gte": ["missing", "trust", 0.1]}, false],
		[{"unknown": true}, false], [{"all": true}, false], [[], false],
		[{"weather": "雨", "day_gte": 1}, false], [{"stat_gte": ["koubei"]}, false],
		[{"npc_rel_gte": ["chen", "trust"]}, false], [{"day_gte": "8"}, false],
	]
	for entry in cases:
		check(Cond.test(entry[0], pack, state) == bool(entry[1]), "condition: " + JSON.stringify(entry[0]))
	state["day"] = 28
	check(Cond.test({"season": 0}, pack, state), "season wraps after season_count")
	state["npc_rel"]["chen"] = {"player": {"trust": 0.7}}
	check(Cond.test({"npc_rel_gte": ["chen", "trust", 0.7]}, pack, state), "nested state player relation")
	var world = ConditionWorld.new()
	for source in [world, {"flags": world.flags, "stats": world.stats, "npcs": world.npcs}]:
		check(Cond.test({"flag": "world_only"}, pack, state, source), "world flag is authoritative")
		check(not Cond.test({"flag": "shared"}, pack, state, source), "world false flag overrides state true flag")
		check(not Cond.test({"flag": "local"}, pack, state, source), "world flags do not fall back to stale simulation flags")
		check(Cond.test({"flag": "today"}, pack, state, source), "today flag remains visible with a world")
		check(Cond.test({"stat_gte": ["koubei", 70]}, pack, state, source), "world stat overrides state stat")
		check(not Cond.test({"stat_gte": ["koubei", 71]}, pack, state, source), "world stat threshold")
		check(Cond.test({"npc_rel_gte": ["chen", "trust", 0.8]}, pack, state, source), "world player relation overrides state relation")
		check(not Cond.test({"npc_rel_gte": ["chen", "trust", 0.81]}, pack, state, source), "world relation threshold")


func _wheels() -> void:
	var pack: Dictionary = {"time": {"season_days": 7}, "difficulty": {"常年": {"wheel_tempo": 1.0}}}
	var state: Dictionary = {
		"day": 7, "seed": 42, "difficulty": "常年", "wheel_last": {}, "unlocked": {}, "pressures": {},
		"day_report": {"wheels": [], "events": []},
	}
	var wheel: Dictionary = {"id": "forced", "mode": "endogenous", "outcomes": [
		{"id": "quiet", "weight": 1.0, "cooldown_days": 0, "effects": []},
		{"id": "event", "weight": 10000.0, "cooldown_days": 3, "effects": [{"op": "news", "text": "test"}]},
	]}
	var before: String = JSON.stringify(state)
	var first: Array = Wheel.rows(pack, state, wheel)
	check(JSON.stringify(state) == before, "wheel preview does not mutate state")
	check(first == Wheel.rows(pack, state, wheel), "wheel previews are repeatable")
	_check_rows(first, "synthetic preview")
	check(Wheel.spin(pack, state, wheel, _capture_effect) == "event", "forced nonquiet event exercises cooldown")
	check(state["wheel_last"].get("forced:event", -1) == 7, "spin records event day")
	check(captured_effects == [{"effect": {"op": "news", "text": "test"}, "source": "forced/event"}], "spin applies selected effects once with source")
	check(state["day_report"]["wheels"].size() == 1 and state["day_report"]["events"] == ["forced/event"], "spin reports probability and event receipt")
	state["day"] = 8
	var cooled: Array = Wheel.rows(pack, state, wheel)
	check(_probability(cooled, "event") == 0.0 and _probability(cooled, "quiet") == 1.0, "cooldown suppresses a recently selected event")
	check(Wheel.spin(pack, state, wheel, _capture_effect) == "quiet", "cooldown forces quiet")
	check(captured_effects.size() == 1, "quiet cannot apply a suppressed event effect")
	check(_probability(Wheel.rows(pack, state, wheel), "quiet") == 1.0, "quiet remains eligible after its own selection")
	state["day"] = 9
	check(_probability(Wheel.rows(pack, state, wheel), "event") == 0.0, "cooldown lasts until full day interval")
	state["day"] = 10
	check(_probability(Wheel.rows(pack, state, wheel), "event") > 0.0, "event becomes eligible exactly at cooldown boundary")
	check(state["day_report"]["events"].size() == 1, "quiet is omitted from event receipts")
	var gated: Dictionary = wheel.duplicate(true)
	gated["outcomes"][1]["requires_building"] = "police"
	state["unlocked"] = {"police": false}
	check(_probability(Wheel.rows(pack, state, gated), "event") == 0.0, "a false building entry cannot unlock a wheel outcome")
	state["unlocked"]["police"] = true
	check(_probability(Wheel.rows(pack, state, gated), "event") > 0.0, "an unlocked building admits its outcome")
	gated = wheel.duplicate(true)
	gated["outcomes"][1]["when"] = {"day_gte": 11}
	check(_probability(Wheel.rows(pack, state, gated), "event") == 0.0, "false outcome condition suppresses its probability")
	state["day"] = 11
	check(_probability(Wheel.rows(pack, state, gated), "event") > 0.0, "true outcome condition admits its probability")
	gated = wheel.duplicate(true)
	gated["outcomes"][1]["pressure"] = {"heat": {"min": 0.3, "bias": 2.0}}
	state["pressures"]["heat"] = 0.2
	check(_probability(Wheel.rows(pack, state, gated), "event") == 0.0, "pressure minimum suppresses an outcome")
	state["pressures"]["heat"] = 0.3
	check(_probability(Wheel.rows(pack, state, gated), "event") > 0.0, "pressure minimum is inclusive")
	gated = wheel.duplicate(true)
	gated["outcomes"][1]["season_weights"] = [0.0, 1.0, 2.0, 3.0]
	state["wheel_last"] = {}
	state["day"] = 0
	check(_probability(Wheel.rows(pack, state, gated), "event") == 0.0, "seasonal zero weight suppresses an event")
	state["day"] = 7
	check(_probability(Wheel.rows(pack, state, gated), "event") > 0.0, "next season admits its event")
	pack["difficulty"]["乱世"] = {"wheel_tempo": 2.0}
	var normal: float = _probability(Wheel.rows(pack, state, wheel), "event")
	state["difficulty"] = "乱世"
	check(_probability(Wheel.rows(pack, state, wheel), "event") > normal, "difficulty tempo increases nonquiet probability")


func _capture_effect(effect: Dictionary, source: String) -> void:
	captured_effects.append({"effect": effect.duplicate(true), "source": source})


func _probability(rows: Array, outcome: String) -> float:
	for row in rows:
		if str(row[0]) == outcome:
			return float(row[1])
	return -1.0


func _check_rows(rows: Array, label: String) -> void:
	var total: float = 0.0
	var valid: bool = not rows.is_empty()
	for row in rows:
		var probability: float = float(row[1])
		valid = valid and is_finite(probability) and probability >= 0.0 and probability <= 1.0
		total += probability
	check(valid and absf(total - 1.0) < 0.000000000001, label + ": nonnegative probabilities sum to one")
	check(_probability(rows, "quiet") > 0.0, label + ": quiet remains positive")


func _pack() -> void:
	var pack: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/town/town_pack.json"))
	var errors: Array = Pack.validate(pack)
	check(errors.is_empty(), "shipped pack validates: " + str(errors))
	check(not Pack.load_pack().is_empty(), "default pack loads")
	var cast: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/cast.json"))
	for npc_id in cast["npcs"]:
		check(pack["npcs"].has(npc_id), "all existing cast has a town schedule: " + str(npc_id))
	for npc_id in pack["npcs"]:
		var npc: Dictionary = pack["npcs"][npc_id]
		check(npc["schedule"].has("default"), "NPC has a default schedule: " + str(npc_id))
		for override in npc["schedule"]:
			var schedule: Array = npc["schedule"][override]
			var aligned: bool = schedule.size() == pack["time"]["slots"].size()
			for place in schedule:
				aligned = aligned and pack["places"].has(place)
			check(aligned, "NPC schedule uses map places for every slot: " + str(npc_id) + "/" + str(override))
	for edge in cast["edges"]:
		var left: Dictionary = pack["npcs"][edge[0]]["links"]
		var right: Dictionary = pack["npcs"][edge[1]]["links"]
		check(float(left.get(edge[1], -1.0)) == float(edge[2]) and float(right.get(edge[0], -1.0)) == float(edge[2]), "cast social edge is retained: " + str(edge[0]) + "/" + str(edge[1]))
	for building_id in ["pawnshop", "teahouse", "ricehall", "pharmacy", "baogong", "post", "market", "police", "dock", "sunfu"]:
		check(pack["buildings"].has(building_id), "contract building exists: " + building_id)
		var building: Dictionary = pack["buildings"][building_id]
		for field in ["name", "kind", "hours", "keeper", "unlock", "news", "map_object"]:
			check(building.has(field), "building includes contract field: " + building_id + "/" + field)
		check(str(building["map_object"]) == building_id, "building aligns with map object: " + building_id)
	var costs: Array = []
	for cost in pack["living_costs"]:
		costs.append(str(cost["id"]))
	for category in ["food", "fuel", "medicine", "social", "levy", "rent", "certificate", "emergency", "turnover"]:
		check(costs.count(category) == 1, "exactly one of each living-cost category: " + category)
	check(pack["strangers"]["archetypes"].size() >= 4, "at least four stranger archetypes")
	for archetype in pack["strangers"]["archetypes"]:
		check(int(archetype.get("cash", -1)) >= 0, "stranger has a declared opening budget: " + str(archetype["id"]))
		if float(archetype["intents"].get("buy", 0)) > 0:
			check(int(archetype["cash"]) > 0, "incoming buyer has funds to purchase stock: " + str(archetype["id"]))
	for difficulty in ["太平年", "常年", "乱世"]:
		check(pack["difficulty"].has(difficulty), "difficulty exists: " + difficulty)
		for day in [0, 1, 7, 28, 112]:
			var state: Dictionary = {"seed": 42, "day": day, "difficulty": difficulty, "wheel_last": {}, "unlocked": {}, "pressures": {}, "flags": {}, "flags_today": {}}
			for pressure in pack["pressures"]:
				state["pressures"][pressure] = float(pack["pressures"][pressure]["max"])
			for building in pack["buildings"]:
				state["unlocked"][building] = true
			var wheels: Array = pack["wheels"].duplicate(true)
			wheels.append_array(Wheel.decks(pack))
			for wheel in wheels:
				var label: String = str(wheel["id"]) + "/" + difficulty + "/day" + str(day)
				var before: String = JSON.stringify(state)
				_check_rows(Wheel.rows(pack, state, wheel), label)
				check(JSON.stringify(state) == before, label + ": preview is pure")
	_strict_validation(pack)


func _reject(pack: Dictionary, message: String) -> void:
	check(not Pack.validate(pack).is_empty(), "validator rejects " + message)


func _strict_validation(pack: Dictionary) -> void:
	# Each mutation starts from a valid pack, so rejection cannot be masked by another defect.
	var paths: Array = [
		[], ["time"], ["pressures", "rice_price"], ["influence"],
		["wheels", 0], ["wheels", 0, "outcomes", 1], ["wheels", 0, "outcomes", 1, "effects", 0],
		["buildings", "pawnshop"], ["npcs", "chen"], ["npcs", "chen", "visit"], ["living_costs", 0],
	]
	for path in paths:
		var altered: Dictionary = pack.duplicate(true)
		var scope: Variant = altered
		for part in path:
			scope = scope[part]
		scope["unexpected_field"] = true
		_reject(altered, "unknown field at " + str(path))
	var altered: Dictionary = pack.duplicate(true)
	altered["wheels"][0]["outcomes"][1]["effects"] = [{"op": "arbitrary_code"}]
	_reject(altered, "unknown effect op")
	altered = pack.duplicate(true)
	altered["wheels"][0]["outcomes"][1]["when"] = {"not": {"all": [{"unknown_cond": true}]}}
	_reject(altered, "nested unknown condition op")
	altered = pack.duplicate(true)
	altered["wheels"][0]["outcomes"].remove_at(0)
	_reject(altered, "missing quiet outcome")
	for weight in [0.0, -1.0]:
		altered = pack.duplicate(true)
		altered["wheels"][0]["outcomes"][0]["weight"] = weight
		_reject(altered, "nonpositive quiet weight " + str(weight))
	for gate in [
		{"cooldown_days": 1}, {"when": {"day_gte": 100}}, {"requires_building": "police"},
		{"pressure": {"rice_price": {"min": 2.0}}}, {"season_weights": [1.0, 0.0, 1.0, 1.0]},
	]:
		altered = pack.duplicate(true)
		altered["wheels"][0]["outcomes"][0].merge(gate, true)
		_reject(altered, "quiet gate " + str(gate))
	var endogenous_conditions: Array = [
		{"pressure_gte": ["heat", 0.2]}, {"flag": "met_chen"}, {"stat_gte": ["koubei", 60]},
		{"building": "police"}, {"npc_rel_gte": ["chen", "trust", 0.5]},
	]
	for condition in endogenous_conditions:
		altered = pack.duplicate(true)
		altered["wheels"][0]["outcomes"][1]["when"] = {"all": [{"day_gte": 1}, {"not": {"any": [condition]}}]}
		_reject(altered, "nested endogenous exogenous-wheel condition " + str(condition))
	altered = pack.duplicate(true)
	altered["wheels"][0]["outcomes"][1]["pressure"] = {"heat": {"bias": 1.0}}
	_reject(altered, "exogenous wheel reads endogenous pressure bias")
	altered = pack.duplicate(true)
	altered["wheels"][0]["outcomes"][1]["requires_building"] = "police"
	_reject(altered, "exogenous wheel requires a player-sensitive building")
	altered = pack.duplicate(true)
	altered["wheels"][0]["outcomes"][1]["when"] = {"all": [{"day_gte": 1}, {"weekday": 2}, {"season": 0}, {"weather": "雨"}, {"pressure_gte": ["rice_price", 1.1]}]}
	check(Pack.validate(altered).is_empty(), "validator accepts purely exogenous nested conditions")
