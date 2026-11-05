# Battle rules, slice 5 (WORLD_MAP_DESIGN section 9 and 10): the 40-terrain table and its derived lists, line of sight,
# top tier, darkness, caves, terrain events under units, kill-triggered events, spawn cells and route windows,
# the 8 weathers, the 15 new enemy tags, the 111-kind roster, sizes up to 12x7, mods, from_turn and the new result
# fields; plus the hard compatibility rule: a setup that only gives act is byte-identical to before, and level = 2a-1
# plays exactly like act = a. No CJK literals here: expected log lines are built from battle_text.json via R._txt.
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const R = preload("res://scripts/cards/campaign/battle/battle_rules.gd")

## WORLD_MAP_DESIGN section 9.1, one row per terrain: char, id, stand, walk, cost, def, rdef, los, tier
const SPEC_TERRAIN := [
	[".", "plain", "ground", 1, 1, 0, 0, 0, 1], ["^", "high", "high", 0, 0, 0, 0, 0, 2],
	["=", "road", "ground", 1, 1, 0, 0, 0, 1], ["v", "village", "ground", 1, 1, 2, 0, 0, 1],
	["w", "woods", "ground", 1, 1, 0, 2, 0, 1], ["~", "river", "none", 0, 0, 0, 0, 0, 0],
	["b", "bridge", "ground", 1, 1, 0, 0, 0, 1], ["f", "ford", "ground", 1, 1, 0, 0, 0, 1],
	["m", "marsh", "none", 0, 0, 0, 0, 0, 0], ["G", "gate", "none", 1, 1, 0, 0, 0, 1],
	["E", "eagle", "none", 0, 1, 0, 0, 0, 1], ["+", "earthwork", "high", 0, 0, 0, 0, 0, 2],
	["_", "void", "none", 0, 0, 0, 0, 0, -1], ["#", "wall", "none", 0, 0, 0, 0, 1, 3],
	[";", "rubble", "ground", 1, 2, 1, 0, 0, 1], ["s", "snow", "ground", 1, 2, 0, 0, 0, 1],
	["u", "mud", "ground", 1, 2, 0, 0, 0, 1], ["i", "ice", "ground", 1, 1, 0, 0, 0, 1],
	["a", "sand", "ground", 1, 1, 0, 0, 0, 1], ["n", "dune", "high", 0, 0, 0, 0, 0, 2],
	["o", "well", "ground", 1, 1, 0, 0, 0, 1], ["d", "deck", "ground", 1, 1, 0, 0, 0, 1],
	["q", "quarterdeck", "high", 0, 0, 0, 0, 0, 2], ["t", "rigging", "top", 0, 0, 0, 0, 0, 3],
	["|", "mast", "none", 0, 0, 0, 0, 1, 3], ["W", "sea", "none", 0, 0, 0, 0, 0, 0],
	["-", "shallows", "none", 1, 2, 0, 0, 0, 0], ["*", "reef", "none", 0, 0, 0, 0, 0, 0],
	[",", "beach", "ground", 1, 1, 0, 0, 0, 1], ["c", "cave", "ground", 1, 1, 0, 2, 1, 1],
	["k", "dock", "ground", 1, 1, 0, 0, 0, 1], ["p", "plank", "ground", 1, 1, 0, 0, 0, 1],
	["H", "hatch", "none", 0, 1, 0, 0, 0, 1], ["S", "street", "ground", 1, 1, 0, 0, 0, 1],
	["B", "building", "ground", 0, 0, 2, 0, 1, 1], ["R", "rooftop", "top", 0, 0, 0, 0, 0, 3],
	["C", "corridor", "ground", 1, 1, 0, 0, 0, 1], ["L", "cell", "ground", 0, 0, 1, 0, 0, 1],
	["D", "door", "none", 1, 1, 0, 0, 0, 1], ["K", "catacomb", "ground", 1, 1, 0, 0, 0, 1],
]
const STARTS := ["gate", "hatch", "door"]
const DARK := ["corridor", "catacomb"]
const SPAWNS := ["village", "woods", "plank", "street", "catacomb"]
## the 7 v1 kinds exactly as battle_rules.gd had them before slice 5
const LEGACY_ENEMIES := {
	"whitecoat": {"hp": 6, "atk": 3, "def": 1, "spd": 1, "type": "infantry", "range": 0, "tags": []},
	"grenz": {"hp": 5, "atk": 3, "def": 0, "spd": 1, "type": "infantry", "range": 2, "tags": []},
	"dragoon": {"hp": 10, "atk": 5, "def": 1, "spd": 2, "type": "cavalry", "range": 0, "tags": ["hunter"]},
	"hungarian": {"hp": 12, "atk": 4, "def": 2, "spd": 1, "type": "elite", "range": 0, "tags": ["heavy"]},
	"leader": {"hp": 10, "atk": 3, "def": 2, "spd": 1, "type": "leader", "range": 0, "tags": ["officer"]},
	"wagon": {"hp": 4, "atk": 0, "def": 0, "spd": 1, "type": "wagon", "range": 0, "tags": []},
	"gun": {"hp": 8, "atk": 6, "def": 1, "spd": 0, "type": "gun", "range": 99, "tags": []},
}
const NEW_KEYS := ["level", "weather", "loot", "ransom", "killed_kinds"]
## 8x3 lane: high ground above and below, road G2 -> A2
const LANE := ["^^^^^^^^", "E======G", "^^^^^^^^"]
const ROUTE := {"r": ["H2", "G2", "F2", "E2", "D2", "C2", "B2", "A2"]}

var t: RefCounted
var _col := 100


func _initialize() -> void:
	t = T.new(self, "OCEAN_battle_terrain")
	_test_terrain_table()
	_test_roster_table()
	_test_legacy_untouched()
	_test_level_equals_act()
	_test_stand_and_deploy()
	_test_step_cost()
	_test_line_of_sight()
	_test_top_tier()
	_test_darkness()
	_test_cave()
	_test_terrain_defence()
	_test_displacement()
	_test_on_kill_door()
	_test_spawns_and_starts()
	_test_at_cells()
	_test_route_until()
	_test_hussar_stops()
	_test_size_and_epic()
	_test_weather()
	_test_tags()
	_test_levels_in_battle()
	_test_mods_and_from_turn()
	_test_result_fields()
	_test_no_floats()
	print("OCEAN battle_terrain assertions: %d" % t.checks)
	t.finish()


# ---------------------------------------------------------------- helpers

func _tpl(map: Array, routes: Dictionary, waves: Array, extra: Dictionary = {}) -> Dictionary:
	var d := {"id": "tt", "name": "tt", "scale": "skirmish", "size": [str(map[0]).length(), map.size()], "level": 1, "turn_limit": 8,
		"enemy_morale": 30, "map": map, "routes": routes, "waves": waves}
	d.merge(extra, true)
	return d


func _u(id: String, cls: String, extra: Dictionary = {}) -> Dictionary:
	var d := {"id": id, "cls": cls, "name": id, "cost": 0}
	d.merge(extra, true)
	return d


func _battle(tpl: Dictionary, roster: Array = [], troops: Array = [], extra: Dictionary = {}) -> Dictionary:
	var setup := {"seed": 11, "level": int(tpl.get("level", 1)), "template": tpl, "roster": roster, "troops": troops,
		"protagonist": {"enabled": false}, "cards": ["requisition", "requisition", "requisition"]}
	setup.merge(extra, true)
	var s: Dictionary = R.new_battle("tt", setup)
	t.ok(not s.has("error"), "battle builds: %s" % str(s.get("errors", "")))
	return s


func _do(s: Dictionary, cmd: String, args: Dictionary = {}) -> bool:
	var r: Dictionary = R.apply(s, cmd, args)
	t.ok(bool(r.get("ok", false)), "%s %s: %s" % [cmd, args, r])
	return bool(r.get("ok", false))


func _err(s: Dictionary, cmd: String, args: Dictionary) -> String:
	var snap := JSON.stringify(s, "", true)
	var r: Dictionary = R.apply(s, cmd, args)
	if not bool(r.get("ok", false)):
		t.ok(JSON.stringify(s, "", true) == snap, "rejected %s leaves the state alone" % cmd)
	return str(r.get("err", "")) if not bool(r.get("ok", false)) else "ok"


func _fights(s: Dictionary, n: int) -> void:
	for i in range(n):
		if s["phase"] != "command":
			return
		_do(s, "fight")


## put an enemy straight onto a cell (no route: it never moves) or onto step i of a route
func _put(s: Dictionary, kind: String, c: int, r: int, tags: Array = []) -> Dictionary:
	_col += 1
	R._spawn_wave(s, {"turn": int(s["turn"]), "route": "", "at": [c, r], "units": [{"kind": kind, "tags": tags}], "column": _col,
		"spawned": false, "first_fire": int(s["turn"]) + 1})
	return s["enemies"][-1]


func _put_on(s: Dictionary, kind: String, rid: String, step: int) -> Dictionary:
	_col += 1
	var cells: Array = s["routes"][rid]
	R._spawn_wave(s, {"turn": int(s["turn"]), "route": rid, "at": [], "units": [{"kind": kind, "tags": []}], "column": _col,
		"spawned": false, "first_fire": -1})
	var e: Dictionary = s["enemies"][-1]
	e["step"] = step
	e["col"] = int(cells[step][0])
	e["row"] = int(cells[step][1])
	return e


func _unit_view(s: Dictionary, uid: String) -> Dictionary:
	for u in R.view(s)["units"]:
		if u["uid"] == uid:
			return u
	return {}


func _enemy_view(s: Dictionary, uid: int) -> Dictionary:
	for e in R.view(s)["enemies"]:
		if int(e["uid"]) == uid:
			return e
	return {}


func _has_log(s: Dictionary, line: String) -> bool:
	for l in s["log"]:
		if str(l) == line:
			return true
	return false


func _errs_have(errs: Array, needle: String) -> bool:
	for e in errs:
		if str(e).find(needle) >= 0:
			return true
	return false


func _without(d: Dictionary, keys: Array) -> Dictionary:
	var out := d.duplicate(true)
	for k in keys:
		out.erase(k)
	return out


# ---------------------------------------------------------------- tables

func _test_terrain_table() -> void:
	t.eq(R.TERRAIN.size(), 40, "40 terrains")
	t.eq(R.TERRAIN_CHARS.size(), 40, "40 map characters")
	var names: Dictionary = R._read_json("res://data/campaigns/battle_text.json")["terrain_names"]
	for row in SPEC_TERRAIN:
		var id: String = row[1]
		var ti: Dictionary = R.terrain_info(id)
		t.eq(R.TERRAIN_CHARS.get(row[0], ""), id, "%s maps to %s" % [row[0], id])
		t.eq([ti["ch"], ti["stand"], int(bool(ti["walk"])), ti["cost"], ti["def"], ti["rdef"], int(bool(ti["los"])), ti["tier"]],
			[row[0], row[2], row[3], row[4], row[5], row[6], row[7], row[8]], "%s matches the section 9.1 table" % id)
		t.eq(bool(ti.get("start", false)), id in STARTS, "%s route start flag" % id)
		t.eq(bool(ti.get("end", false)), id == "eagle", "%s route end flag" % id)
		t.eq(bool(ti.get("dark", false)), id in DARK, "%s dark flag" % id)
		t.eq(bool(ti.get("spawn", false)), id in SPAWNS, "%s spawn-cell flag" % id)
		t.ok(str(ti["name"]) != id and str(ti["name"]) != "", "%s has a player-facing name" % id)
		if names.has(id):
			t.eq(str(R.TERRAIN_NAMES[id]), str(names[id]), "%s name comes from battle_text.json" % id)
		# walk_cost: the table cost when walkable, eagle 1, otherwise 0; mud weather adds 1 for cavalry only
		var want := 1 if id == "eagle" else (int(row[4]) if int(row[3]) == 1 else 0)
		t.eq(R.walk_cost(id, "whitecoat"), want, "%s walk cost (infantry)" % id)
		t.eq(R.walk_cost(id, "dragoon", "mud"), want + (1 if want > 0 and id != "eagle" else 0), "%s walk cost (cavalry in mud)" % id)
		# can_stand: ground -> place ground/any; high -> place high/any; top -> jager only; none -> nobody
		var st: String = row[2]
		t.eq(R.can_stand("line", id), st == "ground", "line on %s" % id)
		t.eq(R.can_stand("artillery", id), st == "high", "artillery on %s" % id)
		t.eq(R.can_stand("jager", id), st == "high" or st == "top", "jager on %s" % id)
		t.eq(R.can_stand("medic", id), st == "ground" or st == "high", "medic (any) on %s" % id)
		t.eq(R.can_stand("hero", id), st == "ground" or st == "high", "hero (any) on %s" % id)
	t.eq(R.can_stand("line", "nonsense"), false, "unknown terrain: nobody stands")
	t.eq(R.walk_cost("nonsense"), 0, "unknown terrain: nobody walks")
	# derived lists keep the old members first and in the old order
	t.eq(R.GROUND.slice(0, 6), ["plain", "road", "village", "woods", "bridge", "ford"], "GROUND starts with the v1 list")
	t.eq(R.HIGH.slice(0, 2), ["high", "earthwork"], "HIGH starts with the v1 list")
	t.eq(R.ENEMY_WALK.slice(0, 8), ["plain", "road", "village", "woods", "bridge", "ford", "gate", "eagle"], "ENEMY_WALK starts with the v1 list")
	t.eq(R.TOP, ["rigging", "rooftop"], "TOP = rigging, rooftop")
	for id in R.TERRAIN:
		t.eq(id in R.GROUND, R.TERRAIN[id]["stand"] == "ground", "GROUND derived for %s" % id)
		t.eq(id in R.HIGH, R.TERRAIN[id]["stand"] == "high", "HIGH derived for %s" % id)
	t.eq(R.CLASSES["jager"].get("top", false), true, "jagers climb rigging and rooftops")
	var legacy_names := {"plain": "平地", "high": "高地", "eagle": "鹰旗", "earthwork": "胸墙"}
	for id in legacy_names:
		t.eq(R.TERRAIN_NAMES[id], legacy_names[id], "v1 terrain name %s unchanged" % id)


func _test_roster_table() -> void:
	t.eq(R.ENEMIES.size(), 111, "111 enemy kinds")
	for k in LEGACY_ENEMIES:
		t.eq(_without(R.ENEMIES[k], ["name"]), LEGACY_ENEMIES[k], "v1 enemy %s unchanged" % k)
	var json: Dictionary = R._read_json("res://data/campaigns/battle_enemies.json")["enemies"]
	t.eq(json.size(), 111, "battle_enemies.json lists all 111")
	var types := ["infantry", "cavalry", "elite", "leader", "wagon", "gun"]
	var bad: Array = []
	for k in json:
		var e: Dictionary = R.enemy_def(k)
		if e.is_empty() or not str(e["type"]) in types or str(e["name"]) == "":
			bad.append("%s shape" % k)
			continue
		if JSON.stringify(R._ints(json[k])) != JSON.stringify(e):
			bad.append("%s differs from the json" % k)
		for tg in e["tags"]:
			if not tg in R.KNOWN_TAGS:
				bad.append("%s tag %s" % [k, tg])
		for tr in e.get("at_terrain", []):
			if not R.TERRAIN.has(tr):
				bad.append("%s at_terrain %s" % [k, tr])
		if "post" in e["tags"] and int(e["spd"]) != 0:
			bad.append("%s post with speed" % k)
		if "boat" in e["tags"] and (e.get("at_terrain", []) != ["sea"] or str(e.get("move", "")) != "boat"):
			bad.append("%s boat off the sea" % k)
		if "top" in e["tags"] and not (e.get("at_terrain", []) as Array).all(func(x): return x in R.TOP):
			bad.append("%s top off the top tier" % k)
	t.eq(bad, [], "every roster row is well formed")
	t.eq(R.KNOWN_TAGS.size(), 19, "4 old + 15 new tags")
	t.eq(R.enemy_def("nonsense"), {}, "unknown kind gives {}")


# ---------------------------------------------------------------- compatibility

## a setup with act only: no new state keys, no new result keys; the view still reports level 2a-1 and clear weather
func _test_legacy_untouched() -> void:
	for tid in ["skirmish_a", "arcole", "rivoli", "major_a"]:
		var s: Dictionary = R.new_battle(tid, {"seed": 3, "act": 4, "protagonist": {"enabled": true}})
		for k in NEW_KEYS:
			t.ok(not s.has(k), "%s act-only state has no %s" % [tid, k])
		var v: Dictionary = R.view(s)
		t.eq([v["level"], v["weather"]], [7, "clear"], "%s act 4 shows as L7, clear" % tid)
		for c in v["grid"]["cells"]:
			if not c.has("tier") or not c.has("los") or not c.has("stand") or not c.has("dark"):
				t.ok(false, "%s view cells carry tier/los/stand/dark" % tid)
				break
		while s["phase"] == "command":
			R.apply(s, "fight", {})
		var res: Dictionary = R.result(s)
		for k in NEW_KEYS:
			t.ok(not res.has(k), "%s act-only result has no %s" % [tid, k])
		t.ok(not s.has("killed_kinds"), "%s act-only state never gains killed_kinds" % tid)


## LEVELS rows 1/3/5/7/9/11 are the v1 act rows: level 2a-1 plays exactly like act a (state equal except the new keys
## and the opening log line, result equal except the new keys)
func _test_level_equals_act() -> void:
	for i in range(6):
		t.eq([R.LEVELS[2 * i][0], R.LEVELS[2 * i][1], R.LEVELS[2 * i][2]], [R.ACT_HP_PCT[i], R.ACT_MORALE_PCT[i], R.ACT_ATK_BONUS[i]],
			"LEVELS L%d equals act %d" % [2 * i + 1, i + 1])
	var setup0 := {"protagonist": {"enabled": true}, "roster": [_u("m", "line", {"hp": 16, "atk": 5}), _u("c", "jager")],
		"troops": [{"id": "g", "cls": "grenadier"}, {"id": "a", "cls": "artillery"}, {"id": "h", "cls": "hussar"}]}
	for tid in ["skirmish_a", "skirmish_b", "skirmish_c", "elite_a", "major_a", "arcole", "rivoli"]:
		for act in [1, 3, 4, 6]:
			var a: Dictionary = setup0.duplicate(true)
			a["seed"] = 5 + act
			a["act"] = act
			var b: Dictionary = a.duplicate(true)
			b.erase("act")
			b["level"] = 2 * act - 1
			var sa: Dictionary = R.new_battle(tid, a)
			var sb: Dictionary = R.new_battle(tid, b)
			var x: int = 7 * int(act) + 13
			var n := 0
			while sa["phase"] == "command" and n < 60:
				x = (x * 1103515245 + 12345) & 0x7FFFFFFF
				var uid: String = sa["order"][x % (sa["order"] as Array).size()]
				var cmd := ["deploy", {"unit": uid, "col": (x >> 4) % int(sa["cols"]), "row": (x >> 8) % int(sa["rows"]), "facing": "right"}]
				if (x >> 12) % 3 == 0:
					cmd = ["fight", {}]
				R.apply(sa, cmd[0], cmd[1])
				R.apply(sb, cmd[0], cmd[1])
				n += 1
			var la: Array = sa["log"]
			var lb: Array = sb["log"]
			t.eq(JSON.stringify(_without(sa, ["log"])), JSON.stringify(_without(sb, NEW_KEYS + ["log"])), "%s act %d == L%d (state)" % [tid, act, 2 * act - 1])
			t.eq(la.slice(1), lb.slice(1), "%s act %d == L%d (log after the opening line)" % [tid, act, 2 * act - 1])
			if sa["phase"] == "over":
				t.eq(JSON.stringify(R.result(sa)), JSON.stringify(_without(R.result(sb), NEW_KEYS)), "%s act %d == L%d (result)" % [tid, act, 2 * act - 1])


# ---------------------------------------------------------------- terrain

func _test_stand_and_deploy() -> void:
	var map := ["R^tqn.vB", "E======G", ".;sLC,dK"]
	var tpl := _tpl(map, ROUTE, [{"turn": 8, "route": "r", "units": ["whitecoat"]}])
	var s := _battle(tpl, [], [_u("j", "jager"), _u("l", "line"), _u("a", "artillery"), _u("m", "medic")])
	t.eq(_err(s, "deploy", {"unit": "l", "col": 0, "row": 0, "facing": "right"}), "terrain", "line cannot climb a rooftop")
	t.eq(_err(s, "deploy", {"unit": "a", "col": 2, "row": 0, "facing": "right"}), "terrain", "artillery cannot go up the rigging")
	t.eq(_err(s, "deploy", {"unit": "m", "col": 0, "row": 0, "facing": "right"}), "terrain", "a medic (any) is not a climber")
	t.eq(_err(s, "deploy", {"unit": "j", "col": 0, "row": 0, "facing": "right"}), "ok", "jager on the rooftop")
	t.eq(_err(s, "deploy", {"unit": "a", "col": 3, "row": 0, "facing": "right"}), "ok", "artillery on the quarterdeck")
	t.eq(_err(s, "deploy", {"unit": "m", "col": 4, "row": 0, "facing": "right"}), "ok", "medic on a dune")
	t.eq(_err(s, "deploy", {"unit": "l", "col": 7, "row": 0, "facing": "right"}), "ok", "line inside a building")
	var cells: Array = R.view(s)["grid"]["cells"]
	t.eq([cells[0]["stand"], cells[0]["tier"], cells[7]["los"], cells[7]["stand"]], ["top", 3, true, "ground"], "view cells: rooftop top/3, building blocks sight")
	for c in range(8):
		t.ok(R._place_err(s, s["units"]["l"], c, 2) == "" or c == 0, "line can stand on %s" % s["terrain"][16 + c])


func _test_step_cost() -> void:
	var map := ["^^^^^^^^", "E=ss===G", "^^^^^^^^"]
	var tpl := _tpl(map, ROUTE, [{"turn": 1, "route": "r", "units": ["whitecoat"]}, {"turn": 12, "route": "r", "units": ["whitecoat"]}], {"turn_limit": 12})
	var s := _battle(tpl)
	var path: Array = []
	for i in range(7):
		_fights(s, 1)
		var e: Dictionary = s["enemies"][0]
		path.append(R._label(int(e["col"]), int(e["row"])))
	# snow costs 2: a speed-1 whitecoat banks a step and needs two turns per snow cell
	t.eq(path, ["G2", "F2", "E2", "E2", "D2", "D2", "C2"], "speed 1 crosses snow at half pace")
	var s2 := _battle(tpl.merged({"waves": [{"turn": 1, "route": "r", "units": ["dragoon"]}, {"turn": 12, "route": "r", "units": ["whitecoat"]}]}, true))
	var p2: Array = []
	for i in range(3):
		_fights(s2, 1)
		var e2: Dictionary = s2["enemies"][0]
		p2.append(R._label(int(e2["col"]), int(e2["row"])))
	t.eq(p2, ["F2", "E2", "D2"], "speed 2 dragoon: 2 road, then banks for snow")
	var s3 := _battle(tpl.merged({"waves": [{"turn": 1, "route": "r", "units": ["dragoon"]}, {"turn": 12, "route": "r", "units": ["whitecoat"]}]}, true), [], [], {"weather": "mud"})
	_fights(s3, 1)
	t.eq(R._label(int(s3["enemies"][0]["col"]), int(s3["enemies"][0]["row"])), "G2", "mud weather: cavalry pays 2 per road cell")
	var s4 := _battle(tpl, [], [], {"weather": "mud"})
	_fights(s4, 1)
	t.eq(R._label(int(s4["enemies"][0]["col"]), int(s4["enemies"][0]["row"])), "G2", "mud weather leaves infantry alone")


func _test_line_of_sight() -> void:
	# a sniper on high ground (E1, range 3) picks the companion over the troop, unless a wall hides her
	var waves := [{"turn": 1, "at": "E1", "units": ["wall_sentry"]}, {"turn": 8, "route": "r", "units": ["whitecoat"]}]
	var targets := {}
	for row0 in ["^.#.^^^^", "^...^^^^", "^._.^^^^", "^.|.^^^^", "^.c.^^^^"]:
		var s := _battle(_tpl([row0, LANE[1], LANE[2]], ROUTE, waves), [_u("c1", "line")], [_u("t1", "line")])
		_do(s, "deploy", {"unit": "c1", "col": 1, "row": 0, "facing": "right"})
		_do(s, "deploy", {"unit": "t1", "col": 3, "row": 1, "facing": "right"})
		var pat: Array = _unit_view(s, "c1")["pattern"]
		_fights(s, 1)
		targets[row0] = [str(s["enemies"][0]["lock_target"]), pat]
	t.eq(targets["^.#.^^^^"], ["t1", [[2, 0]]], "wall: the sniper cannot see c1; c1's own line of fire stops at the wall")
	t.eq(targets["^...^^^^"], ["c1", [[2, 0], [3, 0]]], "open ground: the sniper prefers the companion")
	t.eq(targets["^._.^^^^"], ["c1", [[3, 0]]], "void does not block sight; the fire pattern skips it")
	t.eq(targets["^.|.^^^^"], ["t1", [[2, 0]]], "a mast blocks sight")
	t.eq(targets["^.c.^^^^"], ["t1", [[2, 0]]], "a cave blocks sight beyond it")
	# Bresenham: ties go to the smaller row; endpoints never block
	var s2 := _battle(_tpl(["^^^^^^^^", "E======G", "^^^#^^^^"], ROUTE, waves))
	t.eq(R._los(s2, 1, 1, 5, 1), true, "straight row line of sight")
	t.eq(R._los(s2, 1, 0, 5, 2), true, "the tie at C/D goes to the smaller row, missing the wall on row 3")
	t.eq(R._los(s2, 1, 2, 5, 2), false, "the wall on row 3 blocks its own row")
	t.eq(R._los(s2, 3, 2, 3, 0), true, "a shooter standing on the blocking cell sees out")
	# a unit inside a building fires out; the building itself blocks sight past it
	var s3 := _battle(_tpl(["^B.....^", "E======G", "^^^^^^^^"], ROUTE, waves.slice(1)), [], [_u("l", "line")])
	_do(s3, "deploy", {"unit": "l", "col": 1, "row": 0, "facing": "right"})
	t.eq(_unit_view(s3, "l")["pattern"], [[2, 0], [3, 0]], "a line inside a building shoots out")


func _test_top_tier() -> void:
	var s := _battle(_tpl(["R.......", LANE[1], "^......."], ROUTE, [{"turn": 8, "route": "r", "units": ["whitecoat"]}]), [], [_u("j", "jager"), _u("k", "jager")])
	_do(s, "deploy", {"unit": "j", "col": 0, "row": 0, "facing": "right"})
	_do(s, "deploy", {"unit": "k", "col": 0, "row": 2, "facing": "right"})
	t.eq((_unit_view(s, "j")["pattern"] as Array).size(), 4, "a jager on a rooftop reaches 4 cells")
	t.eq((_unit_view(s, "k")["pattern"] as Array).size(), 3, "on high ground 3")
	var e1 := _put(s, "whitecoat", 2, 0)
	var e2 := _put(s, "whitecoat", 2, 2)
	_fights(s, 1)
	t.eq([6 - int(e1["hp"]), 6 - int(e2["hp"])], [4, 3], "top tier: +1 attack against tier-1 targets (4-1+1 vs 4-1)")
	# enemy marksman in the rigging: range +1; the storm hurts our own men in the rigging only
	var s2 := _battle(_tpl(["t.......", LANE[1], "^^^^^^^^"], ROUTE, [{"turn": 8, "route": "r", "units": ["whitecoat"]}]))
	var ms := _put(s2, "marine_sharpshooter", 0, 0)
	t.eq(R._erange(s2, ms), 4, "rigging marksman: range 3+1")
	var on_road := {"col": 3, "row": 1}
	t.eq(R._top_bonus(s2, ms, on_road), 1, "and +1 attack down on the deck")
	t.eq(R._top_bonus(s2, on_road, ms), 0, "no bonus shooting up")


func _test_darkness() -> void:
	var map := ["C.......", LANE[1], "K^......"]
	var s := _battle(_tpl(map, ROUTE, [{"turn": 8, "route": "r", "units": ["whitecoat"]}]), [], [_u("l", "line"), _u("l2", "line"), _u("j", "jager")])
	_do(s, "deploy", {"unit": "l", "col": 0, "row": 0, "facing": "right"})
	_do(s, "deploy", {"unit": "l2", "col": 0, "row": 2, "facing": "right"})
	_do(s, "deploy", {"unit": "j", "col": 1, "row": 2, "facing": "right"})
	t.eq((_unit_view(s, "l")["pattern"] as Array).size(), 1, "corridor is dark: line range 2-1")
	t.eq((_unit_view(s, "l2")["pattern"] as Array).size(), 1, "catacomb is dark too")
	t.eq((_unit_view(s, "j")["pattern"] as Array).size(), 3, "next door on high ground: full range")
	var g := _put(s, "grenz", 0, 0)
	g["col"] = 0
	t.eq(R._erange(s, g), 1, "an enemy rifle in the dark: range 2-1")
	var cells: Array = R.view(s)["grid"]["cells"]
	t.eq([cells[0]["dark"], cells[1]["dark"], cells[16]["dark"]], [true, false, true], "view marks dark cells")


func _test_cave() -> void:
	var s := _battle(_tpl(["c^^^^^^^", LANE[1], "......^^"], ROUTE, [{"turn": 1, "at": "H1", "units": ["gun"], "first_fire": 2},
		{"turn": 8, "route": "r", "units": ["whitecoat"]}]), [], [_u("l", "line", {"hp": 60, "max_hp": 60}), _u("l2", "line", {"hp": 60, "max_hp": 60})])
	_do(s, "deploy", {"unit": "l", "col": 0, "row": 0, "facing": "right"})
	_fights(s, 1)
	t.eq(s["enemies"][0]["aim"], [], "the gun will not aim at a man in the cave")
	_do(s, "deploy", {"unit": "l2", "col": 0, "row": 2, "facing": "right"})
	_fights(s, 1)
	t.eq(s["enemies"][0]["aim"], [0, 2], "it aims at the one in the open")
	var gz := _put(s, "grenz", 1, 0)
	t.eq(R._dmg_to_unit(s, gz, s["units"]["l"], "ranged"), 1, "in a cave: ranged def +2 (3-(1+2) -> 1)")
	t.eq(R._dmg_to_unit(s, gz, s["units"]["l2"], "ranged"), 2, "in the open: 3-1")
	var inside := _put(s, "whitecoat", 0, 0)
	t.eq(R._enemy_def(s, inside, true), 3, "an enemy in a cave: ranged def 1+2")
	t.eq(R._enemy_def(s, inside, false), 1, "melee def unchanged")


func _test_terrain_defence() -> void:
	var s := _battle(_tpl(["vB;L....", LANE[1], "^^^^^^^^"], ROUTE, [{"turn": 8, "route": "r", "units": ["whitecoat"]}]),
		[], [_u("a", "line"), _u("b", "line"), _u("c", "line"), _u("d", "line"), _u("e", "line")])
	var want := [3, 3, 2, 2, 1]
	for i in range(5):
		var uid: String = ["a", "b", "c", "d", "e"][i]
		_do(s, "deploy", {"unit": uid, "col": i, "row": 0, "facing": "down"})
		t.eq(_unit_view(s, uid)["def"], want[i], "def on %s" % s["terrain"][i])


func _test_displacement() -> void:
	var map := ["^iiii^^^", LANE[1], ",^^^^^^^"]
	var events := [{"turn": 2, "cell": "B1", "terrain": "river"}, {"turn": 2, "cell": "C1", "terrain": "river"},
		{"turn": 2, "cell": "D1", "terrain": "river"}, {"turn": 2, "cell": "A3", "terrain": "shallows"}, {"turn": 2, "cell": "E1", "terrain": "void"}]
	var s := _battle(_tpl(map, ROUTE, [{"turn": 8, "route": "r", "units": ["whitecoat"]}], {"events": events}),
		[_u("c1", "line")], [_u("t1", "line"), _u("t2", "line")])
	_do(s, "deploy", {"unit": "c1", "col": 1, "row": 0, "facing": "down"})
	_do(s, "deploy", {"unit": "t2", "col": 0, "row": 2, "facing": "right"})
	var bar: Dictionary = R._mk_unit({"name": "x", "cls": "barricade"}, "barricade", "bar_x")
	bar["status"] = "ok"
	bar["col"] = 2
	bar["row"] = 0
	s["units"]["bar_x"] = bar
	s["order"].append("bar_x")
	var drown := _put(s, "whitecoat", 3, 0)
	var fall := _put(s, "whitecoat", 4, 0)
	var em: int = int(s["enemy_morale"])
	var morale: int = int(s["morale"])
	_fights(s, 1)
	var c1: Dictionary = s["units"]["c1"]
	t.eq([c1["status"], c1["cooldown"], c1["col"]], ["bar", 2, -1], "ice cracks under c1: back to the bar, cooldown 2")
	t.eq(s["units"]["t2"]["status"], "bar", "the tide floods the beach under t2")
	t.eq(s["units"]["bar_x"]["status"], "routed", "the barricade on the ice is gone")
	t.eq(int(s["morale"]), morale, "no morale lost for units pushed off")
	t.eq((s["fallen"] as Array).size(), 0, "nobody counts as fallen")
	t.eq(R._enemy_by_uid(s, int(drown["uid"])).is_empty() and R._enemy_by_uid(s, int(fall["uid"])).is_empty(), true, "both enemies removed")
	t.eq(int(s["enemy_morale"]), em - 2, "each counts as a kill (-1 enemy morale)")
	t.eq(s["killed_kinds"].get("whitecoat", 0), 2, "killed_kinds counts them")
	t.ok(_has_log(s, R._txt("drowned", {"name": drown["name"], "loss": 1, "em": em - 1})), "drowned logged")
	t.ok(_has_log(s, R._txt("fell", {"name": fall["name"], "loss": 1, "em": em - 2})), "fell logged")
	t.ok(_has_log(s, R._txt("pushed_off", {"cell": "B1", "terrain": R.TERRAIN_NAMES["river"], "name": "c1", "n": 2})), "pushed off logged")
	t.eq(_err(s, "deploy", {"unit": "c1", "col": 0, "row": 2, "facing": "right"}), "cooldown", "c1 waits out the cooldown")


func _test_on_kill_door() -> void:
	var tpl := _tpl(["^^^^^^^^", "E======D", "^^^^^^^^"], ROUTE, [{"turn": 1, "route": "r", "units": ["turnkey_chief"]}, {"turn": 4, "route": "r", "units": ["whitecoat"]}],
		{"events": [{"on_kill": "turnkey_chief", "cell": "H2", "terrain": "wall"}], "kill_flags": {"turnkey_chief": "if_turnkey_down"}})
	t.eq(R.validate_template(tpl), [], "door start + on_kill event + kill_flags validate")
	var s := _battle(tpl)
	var tk: Dictionary = s["enemies"][0]
	tk["hp"] = 0
	R._sweep(s)
	t.eq(s["terrain"][15], "door", "the door changes only at the e step")
	_fights(s, 1)
	t.eq(s["terrain"][15], "wall", "turnkey down: the door is locked into a wall")
	t.ok(_has_log(s, R._txt("on_kill", {"who": tk["name"], "cell": "H2", "terrain": R.TERRAIN_NAMES["wall"]})), "on_kill logged")
	_fights(s, 3)
	t.ok(_has_log(s, R._txt("wave_sealed", {"cell": "H2"})), "the turn-4 wave cannot come through the wall")
	t.eq([s["phase"], s["outcome"], s["victory_kind"]], ["over", "victory", "cleared"], "and the field is clear")
	var bad := tpl.duplicate(true)
	bad["events"] = [{"on_kill": "nonsense", "cell": "H2", "terrain": "wall"}]
	t.ok(_errs_have(R.validate_template(bad), "on_kill needs a known enemy"), "on_kill names a real kind")


func _test_spawns_and_starts() -> void:
	var amb := {"amb": ["C1", "C2", "B2", "A2"], "r": ROUTE["r"]}
	var map := ["^^S^^^^^", LANE[1], LANE[2]]
	var base_w := [{"turn": 8, "route": "r", "units": ["whitecoat"]}]
	var ok := _tpl(map, amb, [{"turn": 3, "route": "amb", "units": ["guerrillero", "partisan_chief"]}] + base_w, {"spawns": ["C1"]})
	t.eq(R.validate_template(ok), [], "ambush route from a street listed in spawns")
	t.ok(_errs_have(R.validate_template(_tpl(map, amb, [{"turn": 3, "route": "amb", "units": ["guerrillero", "whitecoat"]}] + base_w, {"spawns": ["C1"]})),
		"must start at a gate"), "a non-ambush unit cannot use the ambush cell")
	t.ok(_errs_have(R.validate_template(_tpl(map, amb, [{"turn": 3, "route": "amb", "units": ["guerrillero"]}] + base_w)), "must start at a gate"),
		"the cell has to be listed in spawns")
	t.ok(_errs_have(R.validate_template(_tpl(map, amb, base_w, {"spawns": ["A1"]})), "spawns: A1 is high"), "spawns only on spawn terrain")
	var tagged := _tpl(map, amb, [{"turn": 3, "route": "amb", "units": [{"kind": "whitecoat", "tags": ["ambush"]}]}] + base_w, {"spawns": ["C1"]})
	t.eq(R.validate_template(tagged), [], "a template tag makes any kind an ambusher")
	var s := _battle(ok, [], [_u("l", "line")])
	t.eq(_err(s, "deploy", {"unit": "l", "col": 2, "row": 0, "facing": "down"}), "reserved", "the ambush cell is reserved until the wave comes")
	_fights(s, 2)
	t.eq([int(s["enemies"][0]["col"]), int(s["enemies"][0]["row"])], [2, 0], "the ambush wave appears on the street")
	# boarders from a plank; anyone from a hatch; nobody through void or a building
	var plank := ["^^p^^^^^", LANE[1], LANE[2]]
	t.eq(R.validate_template(_tpl(plank, amb, [{"turn": 3, "route": "amb", "units": ["marine", "boatswain"]}] + base_w)), [], "boarders start on a plank")
	t.ok(_errs_have(R.validate_template(_tpl(plank, amb, [{"turn": 3, "route": "amb", "units": ["redcoat"]}] + base_w)), "must start at a gate"),
		"a line infantryman does not board")
	t.eq(R.validate_template(_tpl(["^^^^^^^^", "E======H", LANE[2]], ROUTE, base_w)), [], "a hatch is a gate")
	t.eq(R.validate_template(_tpl(["^^^^^^^^", "E==D===G", LANE[2]], ROUTE, base_w)), [], "a door can be passed through")
	t.ok(_errs_have(R.validate_template(_tpl(["^^^^^^^^", "E==_===G", LANE[2]], ROUTE, base_w)), "is void"), "no route through void")
	t.ok(_errs_have(R.validate_template(_tpl(["^^^^^^^^", "E==B===G", LANE[2]], ROUTE, base_w)), "not walkable"), "enemies do not walk through buildings")
	t.eq(R.validate_template(_tpl(["^^^^^^^^", "E=-;su=G", LANE[2]], ROUTE, base_w)), [], "shallows, rubble, snow, mud are walkable")
	t.ok(_errs_have(R.validate_template(_tpl(["^^^^^^^^", "E==*===G", LANE[2]], ROUTE, base_w)), "not walkable"), "reefs are not")
	t.ok(_errs_have(R.validate_template(_tpl(["^^^^^^^^", "E==W===G", LANE[2]], ROUTE, base_w)), "not walkable"), "the sea is not (boats only)")
	t.ok(_errs_have(R.validate_template(_tpl(["E^^^^^^^", "^======G", LANE[2]], ROUTE, base_w)), "must end at the eagle"), "routes end at an eagle")


func _test_at_cells() -> void:
	var base_w := [{"turn": 8, "route": "r", "units": ["whitecoat"]}]
	var map := ["W^t,dq.n", LANE[1], "R^^^^^^^"]
	var cases := [["A1", "gunboat", true], ["B1", "gunboat", false], ["C1", "marine_sharpshooter", true], ["B1", "marine_sharpshooter", false],
		["D1", "coast_gun", true], ["E1", "coast_gun", false], ["E1", "carronade", true], ["F1", "carronade", true], ["G1", "carronade", false],
		["B1", "gun", true], ["G1", "gun", true], ["H1", "gun", false], ["H1", "coast_sniper", true], ["A3", "coast_sniper", true],
		["B1", "wall_sentry", true], ["A3", "thug_marksman", true], ["A1", "steam_sloop", true], ["A1", "rocket_boat", true]]
	for cs in cases:
		var errs := R.validate_template(_tpl(map, ROUTE, [{"turn": 1, "at": cs[0], "units": [cs[1]]}] + base_w))
		t.eq(errs.is_empty(), cs[2], "%s at %s (%s): %s" % [cs[1], cs[0], R.TERRAIN_CHARS[str(map[R._parse_label(cs[0])[1]])[R._parse_label(cs[0])[0]]], errs])
	t.ok(_errs_have(R.validate_template(_tpl(map, ROUTE, [{"turn": 1, "route": "r", "units": ["bandolero"]}] + base_w)), "guns stand on 'at' cells"),
		"a post marksman cannot walk a route")
	t.ok(_errs_have(R.validate_template(_tpl(map, ROUTE, [{"turn": 1, "at": "B1", "units": ["whitecoat"]}] + base_w)), "guns stand on 'at' cells"),
		"a walker cannot stand on an at cell")


func _test_route_until() -> void:
	var waves := [{"turn": 1, "route": "r", "units": ["whitecoat"]}, {"turn": 2, "route": "r", "units": ["whitecoat"]}, {"turn": 8, "route": "q", "units": ["whitecoat"]}]
	var ev := [{"turn": 6, "cell": "C2", "terrain": "wall"}]
	var map2 := ["^^^^^", "E=D^^", "E===G"]
	var routes := {"r": ["C2", "B2", "A2"], "q": ["E3", "D3", "C3", "B3", "A3"]}
	t.ok(_errs_have(R.validate_template(_tpl(map2, routes, waves, {"events": ev})), "must start at a gate"), "without until the locked door breaks the route")
	var timed := routes.duplicate(true)
	timed["r"] = {"cells": ["C2", "B2", "A2"], "until": 2}
	t.eq(R.validate_template(_tpl(map2, timed, waves, {"events": ev})), [], "until 2: the door may lock after turn 2 + 3 cells")
	var late := waves.duplicate(true)
	late[1]["turn"] = 3
	t.ok(_errs_have(R.validate_template(_tpl(map2, timed, late, {"events": ev})), "only used until turn 2"), "a wave after until is refused")
	var s := _battle(_tpl(map2, timed, waves, {"events": ev}))
	t.eq((s["routes"]["r"] as Array).size(), 3, "timed route cells load")


func _test_hussar_stops() -> void:
	var res := {}
	for row2 in ["..u.....", "........", ".._.....", "..#.....", "..~....."]:
		var s := _battle(_tpl([LANE[0], LANE[1], row2], ROUTE, [{"turn": 8, "route": "r", "units": ["whitecoat"]}]), [], [_u("h", "hussar")])
		var e := _put(s, "whitecoat", 3, 2)
		_do(s, "deploy", {"unit": "h", "col": 0, "row": 2, "facing": "right"})
		res[row2] = [int(s["units"]["h"]["col"]), int(e["hp"]) < 6]
	t.eq(res["........"], [2, true], "open ground: charges 2 cells and hits D3")
	t.eq(res["..u....."], [0, false], "the charge bogs down in mud before reaching D3")
	t.eq(res[".._....."], [0, false], "stops at the void")
	t.eq(res["..#....."], [0, false], "stops at a wall")
	t.eq(res["..~....."], [0, false], "stops at a river")
	var s2 := _battle(_tpl([LANE[0], LANE[1], "........"], ROUTE, [{"turn": 8, "route": "r", "units": ["whitecoat"]}]), [], [_u("h", "hussar")], {"weather": "mud"})
	var e2 := _put(s2, "whitecoat", 3, 2)
	_do(s2, "deploy", {"unit": "h", "col": 0, "row": 2, "facing": "right"})
	t.eq([int(s2["units"]["h"]["col"]), int(e2["hp"])], [0, 6], "mud weather: charge range 3-1, D3 out of reach")


func _test_size_and_epic() -> void:
	t.ok(_errs_have(R.validate_template(_tpl(["^^^^^^^^^^^^^", "E===========G", "^^^^^^^^^^^^^"], {"r": ["M2", "A2"]}, [])), "size must be"), "13 columns is too wide")
	t.ok(_errs_have(R.validate_template(_tpl(["^^^^", "E==G", "^^^^"], {"r": ["D2", "A2"]}, [])), "size must be"), "4 columns is too narrow")
	var bad := _tpl(LANE, ROUTE, [{"turn": 8, "route": "r", "units": ["whitecoat"]}])
	bad["size"] = [8, 4]
	t.ok(_errs_have(R.validate_template(bad), "map must have 4 rows"), "size and map must agree")
	t.eq(R.SCALES["grand"]["cols"], 10, "grand default 10x6")
	t.eq([R.SCALES["epic"]["cols"], R.SCALES["epic"]["rows"], R.SCALES["epic"]["franc"], R.SCALES["epic"]["medal"], R.SCALES["epic"]["gold"]], [12, 7, 320, 5, 2], "epic 12x7, 320/5/2")
	t.eq([R.SCALES["grand"]["franc"], R.SCALES["grand"]["medal"], R.SCALES["grand"]["gold"]], [260, 4, 1], "grand 260/4/1")
	# an irregular 12x7 epic battlefield with void corners, two gates, a ford and a gun, fought to the end
	var map := ["__^^^^^^^^__", "_^E=====b==G", "^^^..w...^^^", "E===v=====G_", "^^^.....^^^^", "_E===f====G_", "__^^^^^^^^__"]
	var routes := {"a": ["L2", "K2", "J2", "I2", "H2", "G2", "F2", "E2", "D2", "C2"], "b": ["K4", "J4", "I4", "H4", "G4", "F4", "E4", "D4", "C4", "B4", "A4"],
		"c": ["K6", "J6", "I6", "H6", "G6", "F6", "E6", "D6", "C6", "B6"]}
	var waves := [{"turn": 1, "route": "a", "units": ["redcoat", "redcoat"]}, {"turn": 2, "route": "b", "units": ["highlander", "brigadier"]},
		{"turn": 3, "at": "L5", "units": ["british_gun"]}, {"turn": 4, "route": "c", "units": ["scots_grey", "rifleman"]},
		{"turn": 7, "route": "b", "units": ["foot_guards", "redcoat"]}]
	var tpl := {"id": "epic12", "name": "e", "scale": "epic", "level": 14, "turn_limit": 13, "enemy_morale": 40, "map": map, "routes": routes, "waves": waves}
	t.eq(R.validate_template(tpl), [], "12x7 epic with void corners validates without a size key")
	for seed_value in [1, 2, 3]:
		var s: Dictionary = R.new_battle("epic12", {"seed": seed_value, "level": 14, "template": tpl, "protagonist": {"enabled": true},
			"roster": [_u("c", "jager", {"cost": 3}), _u("m", "line", {"cost": 4, "hp": 18, "atk": 6})],
			"troops": [{"id": "g", "cls": "grenadier"}, {"id": "a", "cls": "artillery"}, {"id": "l", "cls": "line"}, {"id": "l2", "cls": "line"}]})
		t.eq([int(s["cols"]), int(s["rows"]), (R.view(s)["grid"]["cells"] as Array).size()], [12, 7, 84], "12x7 grid")
		t.eq([int(s["field_cap"]), int(s["companion_cap"])], [11, 6], "epic caps at L14: 11 on the field, 6 companions")
		R.apply(s, "deploy", {"unit": "g", "col": 4, "row": 3, "facing": "right"})
		R.apply(s, "deploy", {"unit": "a", "col": 2, "row": 2, "facing": "right"})
		var guard := 0
		while s["phase"] == "command" and guard < 40:
			R.apply(s, "fight", {})
			guard += 1
		t.eq(s["phase"], "over", "the 12x7 battle ends (seed %d: %s)" % [seed_value, s["outcome"]])
		t.ok(R.result(s)["outcome"] in ["victory", "defeat"], "and settles")
	t.eq(R.view(R.new_battle("epic12", {"seed": 1, "level": 14, "template": tpl}))["grid"]["cells"][0]["tier"], -1, "void cells report tier -1")


# ---------------------------------------------------------------- weather

func _test_weather() -> void:
	var waves := [{"turn": 8, "route": "r", "units": ["whitecoat"]}]
	var tpl := _tpl(LANE, ROUTE, waves, {"weather": ["fog", "rain"]})
	t.eq(R.validate_template(tpl), [], "template weather list validates")
	t.ok(_errs_have(R.validate_template(_tpl(LANE, ROUTE, waves, {"weather": ["hail"]})), "unknown weather"), "unknown weather refused")
	t.eq(_battle(tpl)["weather"], "fog", "no setup weather: the template's first candidate")
	t.eq(_battle(_tpl(LANE, ROUTE, waves))["weather"], "clear", "no candidates: clear")
	t.eq(R.new_battle("tt", {"level": 1, "template": tpl, "weather": "hail"}).get("error"), "bad_setup", "setup weather must be one of the 8")
	t.eq(R.WEATHERS.size(), 8, "8 weathers")
	for w in R.WEATHERS:
		t.ok(R.weather_name(w) != w, "%s has a name" % w)
		t.ok(w == "clear" or R.weather_desc(w) != "", "%s has a description" % w)
	var picks := {}
	for k in range(40):
		var p := R.pick_weather(["rain", "fog", "snow"], k * 7919)
		picks[p] = true
		t.eq(R.pick_weather(["rain", "fog", "snow"], k * 7919), p, "pick_weather is deterministic")
	t.eq(picks.size(), 3, "pick_weather reaches every candidate")
	t.eq([R.pick_weather([], 5), R.pick_weather("storm", 5)], ["clear", "storm"], "pick_weather: empty -> clear, string -> itself")
	# rain: small arms -1 both ways (at least 1); guns and artillery unaffected
	var dm := {}
	for w in ["clear", "rain"]:
		var s := _battle(_tpl(LANE, ROUTE, waves), [], [_u("j", "jager"), _u("a", "artillery"), _u("l", "line")], {"weather": w})
		_do(s, "deploy", {"unit": "j", "col": 0, "row": 0, "facing": "right"})
		_do(s, "deploy", {"unit": "a", "col": 0, "row": 2, "facing": "right"})
		_do(s, "deploy", {"unit": "l", "col": 5, "row": 1, "facing": "left"})
		var e1 := _put(s, "whitecoat", 2, 0)
		var e2 := _put(s, "whitecoat", 3, 2)
		var gz := _put(s, "grenz", 6, 0)
		var gun := _put(s, "gun", 7, 0)
		dm[w] = [R._dmg_to_unit(s, gz, s["units"]["l"], "ranged"), R._dmg_to_unit(s, gun, s["units"]["l"], "gun")]
		R._step_a(s)
		dm[w].append_array([6 - int(e1["hp"]), 6 - int(e2["hp"])])
	t.eq(dm["clear"], [2, 5, 3, 5], "clear: grenz 3-1, gun 6-1, jager 4-1, artillery 6-1")
	t.eq(dm["rain"], [1, 5, 2, 5], "rain: small arms -1, guns and artillery unchanged")
	# snow: 1 command point less per turn; medics heal 2
	for w in ["clear", "snow"]:
		var s2 := _battle(_tpl(LANE, ROUTE, waves), [], [_u("m", "medic"), _u("l", "line", {"hp": 4, "max_hp": 14})], {"weather": w})
		_do(s2, "deploy", {"unit": "m", "col": 0, "row": 0, "facing": "right"})
		_do(s2, "deploy", {"unit": "l", "col": 1, "row": 1, "facing": "right"})
		var cp0: int = int(s2["cp"])
		t.eq(int(R.view(s2)["cp_next"]), 3 if w == "clear" else 2, "%s: command points per turn" % w)
		_fights(s2, 1)
		t.eq([int(s2["cp"]) - cp0, int(s2["units"]["l"]["hp"])], [3, 7] if w == "clear" else [2, 6], "%s: cp gain and medic heal" % w)
	# fog and night: incoming waves show one turn later
	for w in ["clear", "fog", "night"]:
		var s3 := _battle(_tpl(LANE, ROUTE, [{"turn": 3, "route": "r", "units": ["whitecoat"]}] + waves), [], [], {"weather": w})
		t.eq(R.view(s3)["waves"][0]["known"], w == "clear", "%s: the turn-3 wave is %s on turn 1" % [w, "known" if w == "clear" else "hidden"])
		t.eq(R._horizon(s3), 2 if w == "clear" else 1, "%s horizon" % w)
	# night: every cell dark, ranged reach -1
	var s4 := _battle(_tpl(LANE, ROUTE, waves), [], [_u("l", "line"), _u("j", "jager"), _u("a", "artillery")], {"weather": "night"})
	_do(s4, "deploy", {"unit": "l", "col": 2, "row": 1, "facing": "right"})
	_do(s4, "deploy", {"unit": "j", "col": 0, "row": 0, "facing": "right"})
	_do(s4, "deploy", {"unit": "a", "col": 0, "row": 2, "facing": "right"})
	t.eq([(_unit_view(s4, "l")["pattern"] as Array).size(), (_unit_view(s4, "j")["pattern"] as Array).size(), (_unit_view(s4, "a")["pattern"] as Array).size()],
		[1, 2, 6], "night: line 1, jager 2, artillery columns 2-4")
	t.ok((R.view(s4)["grid"]["cells"] as Array).all(func(c): return bool(c["dark"])), "night: every cell dark")
	var gz4 := _put(s4, "grenz", 6, 1)
	t.eq(R._erange(s4, gz4), 1, "night: enemy rifles reach 1")
	t.eq(R._erange(s4, _put(s4, "gun", 7, 0)), 99, "guns are not shortened")
	# desert: turns 3, 6, 9 cost 1 hp away from a well (never below 1)
	var s5 := _battle(_tpl(["o.^^^^^^", LANE[1], "^^^^^^^^"], ROUTE, [{"turn": 12, "route": "r", "units": ["whitecoat"]}], {"turn_limit": 12}),
		[], [_u("near", "line"), _u("far", "jager"), _u("weak", "jager", {"hp": 1, "max_hp": 8})], {"weather": "desert"})
	_do(s5, "deploy", {"unit": "near", "col": 1, "row": 0, "facing": "right"})
	_do(s5, "deploy", {"unit": "far", "col": 3, "row": 0, "facing": "right"})
	_do(s5, "deploy", {"unit": "weak", "col": 4, "row": 0, "facing": "right"})
	var hp_seq: Array = []
	for i in range(6):
		_fights(s5, 1)
		hp_seq.append([int(s5["units"]["near"]["hp"]), int(s5["units"]["far"]["hp"]), int(s5["units"]["weak"]["hp"])])
	t.eq(hp_seq, [[14, 8, 1], [14, 8, 1], [14, 7, 1], [14, 7, 1], [14, 7, 1], [14, 6, 1]], "desert thirst on turns 3 and 6; the well spares its neighbour")
	# storm: our men in the rigging lose 1 per turn (min 1); enemy boats fire every 3 turns instead of 2
	var s6 := _battle(_tpl(["t^^^^^WW", LANE[1], "^^^^^^^^"], ROUTE, [{"turn": 1, "at": "H1", "units": ["gunboat"], "first_fire": 3},
		{"turn": 12, "route": "r", "units": ["whitecoat"]}], {"turn_limit": 12}), [], [_u("j", "jager", {"hp": 3, "max_hp": 8}), _u("l", "line", {"hp": 99, "max_hp": 99})],
		{"weather": "storm"})
	_do(s6, "deploy", {"unit": "j", "col": 0, "row": 0, "facing": "down"})
	_do(s6, "deploy", {"unit": "l", "col": 2, "row": 1, "facing": "right"})
	var fires: Array = []
	var jhp: Array = []
	for i in range(8):
		var hp0: int = int(s6["units"]["l"]["hp"])
		_fights(s6, 1)
		if int(s6["units"]["l"]["hp"]) < hp0:
			fires.append(i + 1)
		jhp.append(int(s6["units"]["j"]["hp"]))
	t.eq(jhp.slice(0, 3), [2, 1, 1], "storm: the jager in the rigging drops to 1 and stays")
	t.eq(fires, [3, 6], "storm: the gunboat fires on turns 3 and 6")


# ---------------------------------------------------------------- tags

func _test_tags() -> void:
	var waves := [{"turn": 8, "route": "r", "units": ["whitecoat"]}]
	# pierce: needs one more free block to be stopped
	var s := _battle(_tpl(LANE, ROUTE, waves), [], [_u("l", "line"), _u("g", "grenadier")])
	_do(s, "deploy", {"unit": "l", "col": 3, "row": 1, "facing": "right"})
	var cells: Array = s["routes"]["r"]
	var w1 := _put_on(s, "whitecoat", "r", 3)
	w1["blocked_by"] = "l"
	var mam := _put_on(s, "mamluk", "r", 3)
	t.eq(R._gate(s, mam, cells), ["pass", ""], "pierce: a line with 1 free block cannot stop a mamluk")
	w1["blocked_by"] = ""
	t.eq(R._gate(s, mam, cells), ["block", "l"], "with 2 free it can")
	var plain := _put_on(s, "nizam", "r", 3)
	w1["blocked_by"] = "l"
	t.eq(R._gate(s, plain, cells), ["block", "l"], "an ordinary infantryman needs only 1")
	# skirmisher: hit in melee, steps back the next turn and breaks contact; at most every 2 turns
	var s2 := _battle(_tpl(LANE, ROUTE, waves), [], [_u("w", "line", {"atk": 1, "hp": 99, "max_hp": 99, "block": 3})])
	_do(s2, "deploy", {"unit": "w", "col": 1, "row": 1, "facing": "right"})
	var bed := _put_on(s2, "bedouin", "r", 5)
	bed["hp"] = 50
	_fights(s2, 1)
	t.eq([R._label(int(bed["col"]), int(bed["row"])), bed["blocked_by"], int(bed["retreat_turn"])], ["C2", "w", 2], "turn 1: blocked, fights, will fall back")
	t.ok(_has_log(s2, R._txt("skirmish", {"name": bed["name"]})), "skirmish logged")
	_fights(s2, 1)
	t.eq([R._label(int(bed["col"]), int(bed["row"])), bed["blocked_by"]], ["D2", ""], "turn 2: one cell back, contact broken")
	_fights(s2, 1)
	t.eq(R._label(int(bed["col"]), int(bed["row"])), "C2", "turn 3: comes again")
	# post: a fixed marksman never moves and keeps shooting
	var s3 := _battle(_tpl(["^^^^^^^^", LANE[1], LANE[2]], ROUTE, [{"turn": 1, "at": "F1", "units": ["bandolero"]}] + waves), [], [_u("l", "line", {"hp": 40, "max_hp": 40})])
	_do(s3, "deploy", {"unit": "l", "col": 4, "row": 1, "facing": "left"})
	_fights(s3, 3)
	t.eq([R._label(int(s3["enemies"][0]["col"]), int(s3["enemies"][0]["row"])), int(s3["units"]["l"]["hp"]) < 40], ["F1", true], "post: stays on F1 and fires")
	# stealth: more than 2 cells from all our men -> unknown in view, intents, waves and preview
	var s4 := _battle(_tpl(LANE, ROUTE, [{"turn": 3, "route": "r", "units": ["smuggler"]}] + waves), [], [_u("a", "artillery")])
	_do(s4, "deploy", {"unit": "a", "col": 0, "row": 0, "facing": "right"})
	var wv: Dictionary = R.view(s4)["waves"][0]
	t.eq([wv["detail"][0]["kind"], wv["units"][0]], ["unknown", R._unknown_name()], "a coming stealth wave is unknown")
	var sm := _put_on(s4, "smuggler", "r", 2)
	var ev: Dictionary = _enemy_view(s4, int(sm["uid"]))
	t.eq([ev["kind"], ev["name"], ev["hp"], ev["tags"], ev["hidden"]], ["unknown", R._unknown_name(), 0, [], true], "far smuggler shows as ?")
	var pv: Dictionary = R.preview(s4)["enemies"][str(int(sm["uid"]))]
	t.eq([pv.get("hidden"), pv.has("hp"), int(pv.get("dmg", -1)), pv.get("alive")], [true, false, 6, false], "preview gives only the damage")
	sm["step"] = 6
	sm["col"] = 1
	t.eq(_enemy_view(s4, int(sm["uid"]))["hidden"], false, "within 2 cells it is revealed")
	# loot / ransom: counted when they reach the eagle
	var s5 := _battle(_tpl(LANE, ROUTE, waves))
	_put_on(s5, "pirate", "r", 6)
	_put_on(s5, "bandit", "r", 6)
	_put_on(s5, "convict", "r", 6)
	_fights(s5, 1)
	t.eq([int(s5["loot"]), int(s5["ransom"]), int(s5["leaks"])], [2, 1, 3], "loot x2 (pirate, convict), ransom x1 (bandit)")
	# arrest: the protagonist cut down by a gendarme is taken, no coins
	for kind in ["gendarme", "whitecoat"]:
		var s6 := _battle(_tpl(LANE, ROUTE, waves), [], [], {"protagonist": {"enabled": true}})
		_do(s6, "deploy", {"unit": "hero", "col": 1, "row": 1, "facing": "right"})
		s6["units"]["hero"]["hp"] = 1
		_put_on(s6, kind, "r", 5)
		_fights(s6, 1)
		_do(s6, "retreat")
		var res: Dictionary = R.result(s6)
		var hero_row: Dictionary = res["fallen"][0] if not (res["fallen"] as Array).is_empty() else {}
		if kind == "gendarme":
			t.eq(["hero" in res["captured"], hero_row.get("arrested"), hero_row.get("rolled"), hero_row.get("coins")], [true, true, false, 0], "arrest: taken prisoner, no coin toss")
		else:
			t.eq(["hero" in res["captured"], hero_row.get("arrested", false), hero_row.get("rolled")], [false, false, true], "an ordinary blow: coins as usual")
	# rally: the column gets +2 instead of the leader's +1
	var s7 := _battle(_tpl(LANE, ROUTE, waves))
	for lead in ["leader", "navy_captain", "pr_general"]:
		_col += 1
		R._spawn_wave(s7, {"turn": 1, "route": "r", "at": [], "units": [{"kind": lead, "tags": []}, {"kind": "whitecoat", "tags": []}], "column": _col, "spawned": false, "first_fire": -1})
		t.eq(R._enemy_atk(s7, s7["enemies"][-1]), 3 + (1 if lead == "leader" else 2), "%s gives its column +%d" % [lead, 1 if lead == "leader" else 2])
	# short: carronades only aim within 4 columns
	var s8 := _battle(_tpl(["^^^^^^^^^^", "E========G", "^^^^^^^^^d"], {"r": ["J2", "I2", "H2", "G2", "F2", "E2", "D2", "C2", "B2", "A2"]}, [{"turn": 8, "route": "r", "units": ["whitecoat"]}]),
		[], [_u("far", "line"), _u("near", "line")])
	var car := _put(s8, "carronade", 9, 2)
	_do(s8, "deploy", {"unit": "far", "col": 4, "row": 1, "facing": "right"})
	_do(s8, "deploy", {"unit": "near", "col": 5, "row": 1, "facing": "right"})
	t.eq([R._gun_can_aim(s8, car, s8["units"]["far"]), R._gun_can_aim(s8, car, s8["units"]["near"])], [false, true], "short: 5 columns too far, 4 fine")
	t.eq(R._gun_pick(s8, car), [5, 1], "the carronade aims at the near one")
	# rocket: full damage on the crosshair, half on the cell towards our eagle
	var s9 := _battle(_tpl(LANE, ROUTE, waves), [], [_u("a", "line", {"hp": 30, "max_hp": 30}), _u("b", "line", {"hp": 30, "max_hp": 30})])
	_do(s9, "deploy", {"unit": "a", "col": 4, "row": 1, "facing": "right"})
	_do(s9, "deploy", {"unit": "b", "col": 3, "row": 1, "facing": "right"})
	var rk := _put(s9, "rocket", 7, 0)
	rk["aim"] = [4, 1]
	rk["fire_turn"] = int(s9["turn"])
	t.eq(R.intents(s9).filter(func(r): return r.get("type") == "crosshair")[0].get("splash"), [3, 1], "the crosshair intent shows the splash cell")
	R._step_d(s9)
	t.eq([30 - int(s9["units"]["a"]["hp"]), 30 - int(s9["units"]["b"]["hp"])], [4, 2], "rocket 5-1 on the crosshair, half on the splash")
	# boat / top / ambush / boarder / post are placement rules: covered by _test_at_cells and _test_spawns_and_starts
	t.ok("boat" in R.ENEMIES["gunboat"]["tags"] and "top" in R.ENEMIES["marine_sharpshooter"]["tags"], "boat and top kinds exist")


# ---------------------------------------------------------------- levels in battle

func _test_levels_in_battle() -> void:
	var tpl := _tpl(LANE, ROUTE, [{"turn": 1, "route": "r", "units": ["redcoat", {"kind": "highlander", "lv_min": 5}, {"kind": "redcoat", "act_min": 3}]},
		{"turn": 2, "route": "r", "units": ["whitecoat"], "lv_min": 10}, {"turn": 8, "route": "r", "units": ["whitecoat"]}],
		{"base_level": 1, "pad": {"kind": "landwehr", "every": 6}})
	t.eq(R.validate_template(tpl), [], "pad/base_level/lv_min/act_min validate")
	var counts := {}
	for lv in [1, 4, 5, 7, 10, 13]:
		var s := _battle(tpl.merged({"level": lv}, true))
		var n := 0
		for w in s["waves"]:
			n += (w["units"] as Array).size()
		counts[lv] = n
	# L1: 1 redcoat + whitecoat; L5: +highlander, +redcoat (act_min 3 = lv 5); L7: +1 pad per wave; L10: +whitecoat wave; L13: +2 pads per wave
	t.eq(counts, {1: 2, 4: 2, 5: 4, 7: 6, 10: 8, 13: 11}, "units per level: lv_min, act_min and pad")
	var lr: Dictionary = R.row(15)
	var s2 := _battle(_tpl(LANE, ROUTE, [{"turn": 1, "route": "r", "units": ["redcoat", "nizam", "wagon"]}, {"turn": 8, "route": "r", "units": ["whitecoat"]}], {"level": 15}))
	var ens: Array = s2["enemies"]
	t.eq([ens[0]["hp"], ens[0]["atk"], ens[0]["def"]], [7 * 212 / 100, 4 + 3, 1 + 1], "L15 redcoat: hp x2.12, atk +3, def +1")
	t.eq([ens[1]["def"], ens[2]["atk"]], [0, 0], "bonuses only for stats above 0")
	t.eq(int(s2["enemy_morale"]), 30 * int(lr["morale_pct"]) / 100, "enemy morale x1.87")
	# decapitation: L >= 7, never in a skirmish
	for cs in [["elite", 7, true], ["elite", 6, false], ["skirmish", 9, false], ["grand", 13, true]]:
		var d := _battle(_tpl(["^^^^^^^^", LANE[1], LANE[2]], ROUTE, [{"turn": 9, "route": "r", "units": ["whitecoat"]}],
			{"scale": cs[0], "level": cs[1], "turn_limit": 9}), [], [], {"protagonist": {"enabled": true}})
		_do(d, "deploy", {"unit": "hero", "col": 0, "row": 0, "facing": "right"})
		_fights(d, 3)
		t.eq(int(d["decap_turn"]) > 0, cs[2], "decapitation %s L%d: %s" % [cs[0], cs[1], cs[2]])
	# field caps follow caps(scale, L)
	for lv in [12, 13, 19, 24]:
		for sc in ["skirmish", "elite", "major", "grand", "epic"]:
			var cap := R.caps(sc, lv)
			var sz: Array = [R.SCALES[sc]["cols"], R.SCALES[sc]["rows"]]
			var map: Array = []
			for r in range(int(sz[1])):
				map.append("E" + "=".repeat(int(sz[0]) - 2) + "G" if r == 0 else "^".repeat(int(sz[0])))
			var lbls: Array = []
			for c in range(int(sz[0]) - 1, -1, -1):
				lbls.append(R._label(c, 0))
			var sb := _battle({"id": "tt", "name": "t", "scale": sc, "level": lv, "turn_limit": 8, "enemy_morale": 9, "map": map, "routes": {"r": lbls},
				"waves": [{"turn": 8, "route": "r", "units": ["whitecoat"]}]})
			t.eq([int(sb["field_cap"]), int(sb["companion_cap"])], [cap["field"], cap["companions"]], "%s L%d caps" % [sc, lv])


func _test_mods_and_from_turn() -> void:
	var tpl := _tpl(LANE, ROUTE, [{"turn": 1, "route": "r", "units": ["whitecoat"]}, {"turn": 2, "route": "r", "units": ["redcoat"]},
		{"turn": 3, "at": "F1", "units": ["gun"], "first_fire": 5}, {"turn": 8, "route": "r", "units": ["whitecoat"]}], {"events": [{"turn": 4, "cell": "D3", "terrain": "earthwork"}],
		"order": {"type": "hold", "cell": "B2", "turn": 6}})
	var base := _battle(tpl)
	var m := _battle(tpl, [], [], {"mods": {"cp_bonus": 2, "enemy_morale": -3, "prep_turn": 1, "drop_waves": [1], "terrain": [{"cell": "C3", "terrain": "woods"}]}})
	t.eq(int(m["cp"]) - int(base["cp"]), 2, "mods.cp_bonus")
	t.eq(int(base["enemy_morale"]) - int(m["enemy_morale"]), 3, "mods.enemy_morale")
	t.eq(int(m["turn_limit"]), 9, "prep_turn: one more turn")
	var turns: Array = []
	for w in m["waves"]:
		turns.append(int(w["turn"]))
	t.eq(turns, [2, 4, 9], "prep_turn shifts the waves; drop_waves removed the turn-2 redcoats")
	t.eq([int(m["waves"][1]["first_fire"]), int(m["events"][0]["turn"]), int(m["order_goal"]["turn"])], [6, 5, 7], "first fire, events and the hold order shift too")
	t.eq(m["terrain"][2 * 8 + 2], "woods", "mods.terrain rewrites a cell")
	t.eq((m["enemies"] as Array).size(), 0, "nobody on turn 1 of the prep turn")
	t.eq(R.power(tpl, 1, {"mods": {"drop_waves": [1]}}), R.power(tpl, 1) - 7 * (4 + 1 + 2) / 10, "power ignores dropped waves")
	for bad in [{"cp_bonus": 5}, {"enemy_morale": 1}, {"prep_turn": 2}, {"drop_waves": "x"}, {"terrain": [{"cell": "C3", "terrain": "lava"}]}, {"luck": 1}]:
		t.eq(R.new_battle("tt", {"level": 1, "template": tpl, "mods": bad}).get("error"), "bad_setup", "bad mods %s refused" % str(bad))
	# from_turn: in the lineup, deployable only from that turn
	var s := _battle(_tpl(LANE, ROUTE, [{"turn": 8, "route": "r", "units": ["whitecoat"]}]), [_u("dantes", "line", {"from_turn": 3}), _u("faria", "medic")])
	t.eq(_err(s, "deploy", {"unit": "dantes", "col": 1, "row": 1, "facing": "right"}), "not_yet", "turn 1: not yet")
	var bar: Array = R.view(s)["deploy_bar"]
	var row: Dictionary = bar.filter(func(b): return b["uid"] == "dantes")[0]
	t.eq([row["deployable"], row["reason"], row["from_turn"]], [false, "not_yet", 3], "the deploy bar says why and when")
	_fights(s, 2)
	t.eq(_err(s, "deploy", {"unit": "dantes", "col": 1, "row": 1, "facing": "right"}), "ok", "turn 3: in")
	t.ok(not s["units"]["faria"].has("from_turn"), "no from_turn key unless given")
	t.eq(R.new_battle("tt", {"level": 1, "template": tpl, "roster": [{"id": "x", "cls": "line", "from_turn": "3"}]}).get("error"), "bad_setup", "from_turn must be an integer")


func _test_result_fields() -> void:
	var s := _battle(_tpl(LANE, ROUTE, [{"turn": 1, "route": "r", "units": ["whitecoat", "redcoat"]}, {"turn": 2, "route": "r", "units": ["pirate"]}], {"level": 3}),
		[], [_u("a", "artillery", {"atk": 30}), _u("g", "grenadier", {"hp": 99, "max_hp": 99, "atk": 20})], {"weather": "rain"})
	_do(s, "deploy", {"unit": "a", "col": 0, "row": 0, "facing": "right"})
	_do(s, "deploy", {"unit": "g", "col": 2, "row": 1, "facing": "right"})
	var guard := 0
	while s["phase"] == "command" and guard < 12:
		_do(s, "fight")
		guard += 1
	var res: Dictionary = R.result(s)
	t.eq([res.get("level"), res.get("weather"), res.get("loot"), res.get("ransom")], [3, "rain", 0, 0], "result: level, weather, loot, ransom")
	t.eq(res.get("killed_kinds"), {"whitecoat": 1, "redcoat": 1, "pirate": 1}, "result: killed_kinds counts every kill by kind")
	t.eq(R.hero_hp(1), 12, "hero hp L1")
	t.eq([R.hero_hp(11), R.hero_hp(13), R.hero_hp(24), R.hero_hp(24, 24), R.hero_hp(30, 24)], [20, 20, 20, 24, 24], "hero hp: min(cap, 12 + L - 1)")


func _test_no_floats() -> void:
	var tpl := _tpl(["^R^t^c^^", "E=s;u=-G", "^^^^^^^^"], ROUTE, [{"turn": 1, "route": "r", "units": ["cossack", "smuggler"]}, {"turn": 2, "at": "D1", "units": ["marine_sharpshooter"]},
		{"turn": 4, "route": "r", "units": ["mamluk", "navy_captain"]}], {"level": 17, "weather": ["night"]})
	t.eq(R.validate_template(tpl), [], "mixed-terrain template validates")
	var s := _battle(tpl, [_u("c", "jager")], [_u("a", "artillery"), _u("l", "line")], {"protagonist": {"enabled": true}})
	_do(s, "deploy", {"unit": "c", "col": 1, "row": 0, "facing": "down"})
	_do(s, "deploy", {"unit": "a", "col": 0, "row": 0, "facing": "right"})
	for i in range(10):
		if s["phase"] != "command":
			break
		for v in [R.view(s), R.preview(s), R.intents(s), s]:
			if not t.find_floats(v).is_empty():
				t.ok(false, "turn %d floats %s" % [i, t.find_floats(v)])
		R.apply(s, "fight", {})
	t.eq(t.find_floats(R.result(s)), PackedStringArray(), "result has no floats")
	var loaded: Dictionary = R.load_state(JSON.parse_string(JSON.stringify(s)))
	t.eq(JSON.stringify(R.result(loaded)), JSON.stringify(R.result(s)), "save round trip keeps the result")
