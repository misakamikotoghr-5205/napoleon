# Global level L1-24 (WORLD_MAP_DESIGN section 8): the LEVELS table, caps, hero hp, power, lint, and a smoke run of
# the section 8.5 metrics with the deterministic weak policy (battle_policy.gd, which asks Rules.can_stand):
#   A1 monotonic (pad template at b, b+3, b+6, b+9: W never rises; with R(b) S falls >= 5 a step, with R1 S never rises),
#   A4 passive play loses (only 'fight', and protagonist alone on every standable cell x 4 facings),
#   A6 same seed -> same result, integers only.
# A2 / A3 (not trivial / winnable) are printed as a table for B2's calibration of the new templates; the v1 templates
# were tuned for the ocean acts, not for L bands, so they are reported, not asserted.
# Seeds: 3 by default; DEHOUDANG_SWEEP=1 runs 8 (the full sweep with 30 seeds is tools/battle_sweep.gd, B2).
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const R = preload("res://scripts/cards/campaign/battle/battle_rules.gd")
const Policy = preload("res://scripts/tests/cards/OCEAN/battle_policy.gd")

## ocean_battle.json companions (the v1 cast), strongest blockers first
const CAST := [
	{"id": "gourgaud", "cls": "grenadier", "hp": 22, "atk": 4, "def": 3, "block": 3, "cost": 6, "skill": "bayonet_charge"},
	{"id": "morel", "cls": "line", "hp": 16, "atk": 5, "def": 1, "block": 2, "cost": 5, "skill": "raise_flag"},
	{"id": "nemo", "cls": "artillery", "hp": 9, "atk": 7, "def": 0, "block": 0, "cost": 7, "skill": "mark_target"},
	{"id": "dantes", "cls": "hussar", "hp": 12, "atk": 6, "def": 1, "block": 1, "cost": 4, "skill": "bayonet_charge"},
	{"id": "corso", "cls": "jager", "hp": 8, "atk": 4, "def": 0, "block": 0, "cost": 3, "skill": "mark_target"},
	{"id": "faria", "cls": "engineer", "hp": 14, "atk": 3, "def": 2, "block": 1, "cost": 3, "skill": "fortify"},
	{"id": "friday", "cls": "drummer", "hp": 10, "atk": 2, "def": 0, "block": 1, "cost": 3, "skill": "raise_flag"},
	{"id": "marie", "cls": "medic", "hp": 10, "atk": 0, "def": 1, "block": 0, "cost": 3, "skill": "mark_target"},
]
const TROOP_CYCLE := ["grenadier", "line", "artillery", "line", "jager", "hussar", "grenadier", "line"]
## where the v1 templates are used (scene_map acts -> L = 2a - 1): lowest and highest use
const USE := {"skirmish_a": [1, 1], "skirmish_b": [1, 5], "skirmish_c": [3, 7], "elite_a": [1, 11], "major_a": [3, 11], "arcole": [1, 3], "rivoli": [3, 5]}
const LANE8 := ["^^^^^^^^", "E======G", "^^^^^^^^", "E======G"]

var t: RefCounted
var seeds: Array = [1, 2, 3]


func _initialize() -> void:
	t = T.new(self, "OCEAN_battle_levels")
	if OS.get_environment("DEHOUDANG_SWEEP") == "1":
		seeds = [1, 2, 3, 4, 5, 6, 7, 8]
	var started := Time.get_ticks_msec()
	_test_table()
	_test_caps_and_hero()
	_test_power()
	_test_lint()
	_test_determinism()
	_test_passive_loses()
	_test_hero_alone_loses()
	_test_monotonic()
	_report_reference()
	print("OCEAN battle_levels ms: %d" % (Time.get_ticks_msec() - started))
	print("OCEAN battle_levels assertions: %d" % t.checks)
	t.finish()


# ---------------------------------------------------------------- rosters and the policy loop

## reference roster R(L): troops min(8, 4 + L/4); companions = the companion cap, stats x (100 + 5(L-1))/100; no protagonist
func _ref_roster(scale: String, lv: int, scaled: bool = true) -> Dictionary:
	var cap := R.caps(scale, lv)
	var comps: Array = []
	for i in range(mini(int(cap["companions"]), CAST.size())):
		var c: Dictionary = (CAST[i] as Dictionary).duplicate(true)
		if scaled:
			for k in ["hp", "atk", "def"]:
				c[k] = int(c[k]) * (100 + 5 * (lv - 1)) / 100
		c["name"] = c["id"]
		comps.append(c)
	var troops: Array = []
	for i in range(mini(8, 4 + lv / 4)):
		troops.append({"id": "t%d" % i, "cls": TROOP_CYCLE[i]})
	return {"roster": comps, "troops": troops}


## R1: the fixed starting roster
func _r1() -> Dictionary:
	return {"roster": [(CAST[1] as Dictionary).merged({"name": "morel"}), (CAST[4] as Dictionary).merged({"name": "corso"})],
		"troops": [{"id": "t0", "cls": "line"}, {"id": "t1", "cls": "line"}, {"id": "t2", "cls": "artillery"}, {"id": "t3", "cls": "grenadier"}]}


## the campaign view renames units / tags (contract section 7.5); the policy reads that shape
func _pub(v):
	match typeof(v):
		TYPE_DICTIONARY:
			var out: Dictionary = {}
			for k in v.keys():
				out[("battle_" + str(k)) if CardViewModel.FORBIDDEN_KEYS.has(str(k)) else k] = _pub(v[k])
			return out
		TYPE_ARRAY:
			var arr: Array = []
			for x in v:
				arr.append(_pub(x))
			return arr
	return v


func _play(tpl, lv: int, seed_value: int, ros: Dictionary, weather: String = "") -> Dictionary:
	var setup := {"seed": seed_value, "level": lv, "roster": ros["roster"], "troops": ros["troops"], "protagonist": {"enabled": false}}
	if weather != "":
		setup["weather"] = weather
	var tid := "x"
	if typeof(tpl) == TYPE_DICTIONARY:
		setup["template"] = tpl
	else:
		tid = str(tpl)
	var s: Dictionary = R.new_battle(tid, setup)
	if s.has("error"):
		t.ok(false, "battle %s L%d builds: %s" % [tid, lv, s])
		return {"win": false, "s": 0, "result": {}}
	var per_turn := 0
	var turn := 0
	var guard := 0
	while s["phase"] == "command" and guard < 600:
		guard += 1
		if int(s["turn"]) != turn:
			turn = int(s["turn"])
			per_turn = 0
		var act: Array = [] if per_turn >= 24 else Policy.next_action(_pub(R.view(s)), _pub(R.preview(s)))
		per_turn += 1
		if act.is_empty() or not bool(R.apply(s, act[0], act[1]).get("ok", false)):
			R.apply(s, "fight", {})
	var res: Dictionary = R.result(s)
	var win: bool = res.get("outcome", "") == "victory"
	return {"win": win, "s": 100 * int(res.get("morale", 0)) / maxi(1, int(s["morale_start"])) if win else 0, "result": res}


## W (win %), S (mean safety margin) over the seeds
func _ws(tpl, lv: int, ros: Dictionary) -> Array:
	var w := 0
	var sm := 0
	for sd in seeds:
		var r := _play(tpl, lv, int(sd), ros)
		w += 1 if bool(r["win"]) else 0
		sm += int(r["s"])
	return [100 * w / seeds.size(), sm / seeds.size()]


# ---------------------------------------------------------------- tables

func _test_table() -> void:
	t.eq(R.LEVELS.size(), 24, "24 levels")
	for lv in range(1, 25):
		var r := R.row(lv)
		t.eq(r["level"], lv, "row(%d).level" % lv)
		# the ARCH section 3.2 closed forms (the table is authoritative; these are the documented shapes)
		t.eq(r["atk"], (lv + 3) / 4 - 1, "L%d enemy attack bonus (L+3)/4-1" % lv)
		t.eq(r["def"], maxi(0, (lv - 9) / 6), "L%d enemy defence bonus max(0,(L-9)/6)" % lv)
		t.eq(r["boss_hunters"], (lv + 1) / 4, "L%d boss hunters" % lv)
		t.eq(r["elite_hunters"], (lv - 1) / 8, "L%d elite hunters" % lv)
		t.eq(r["skirmish_hunters"], maxi(0, (lv - 5) / 8), "L%d skirmish hunters" % lv)
		t.eq(r["boss_elites"], mini(6, 1 + (lv + 1) / 4), "L%d boss elites" % lv)
		t.eq([r["boss_turns"], r["elite_turns"], r["skirmish_turns"]], [11 + (lv - 1) / 6, 8 + (lv - 1) / 12, 6 + (lv - 1) / 12], "L%d turn targets" % lv)
		t.eq(r["stars"], 1 + (lv - 1) / 5, "L%d stars" % lv)
		if lv >= 11:
			t.eq(r["morale_pct"], 167 + 5 * (lv - 11), "L%d morale %%" % lv)
			t.eq(r["hp_pct"], 180 + 8 * (lv - 11) + (2 * (lv - 21) if lv >= 22 else 0), "L%d hp %%" % lv)
		if lv > 1:
			var p := R.row(lv - 1)
			t.ok(int(r["hp_pct"]) > int(p["hp_pct"]) and int(r["morale_pct"]) > int(p["morale_pct"]), "L%d strictly harder than L%d" % [lv, lv - 1])
	t.eq([R.row(0)["level"], R.row(99)["level"]], [1, 24], "row() clamps")
	t.eq([R.level_of_act(1), R.level_of_act(4), R.level_of_act(6)], [1, 7, 11], "level_of_act = 2a-1")


func _test_caps_and_hero() -> void:
	for sc in ["skirmish", "elite", "major"]:
		for a in range(1, 7):
			t.eq(R.caps(sc, 2 * a - 1), {"field": R.SCALES[sc]["field"][a - 1], "companions": R.SCALES[sc]["companions"][a - 1]}, "%s act %d caps unchanged" % [sc, a])
	var want := {"skirmish": [[12, 5, 2], [13, 6, 2], [24, 6, 2]], "elite": [[12, 6, 3], [13, 7, 3], [24, 7, 3]], "major": [[12, 9, 5], [24, 9, 5]],
		"grand": [[12, 10, 5], [18, 10, 5], [19, 11, 6], [24, 11, 6]], "epic": [[12, 11, 6], [18, 11, 6], [19, 12, 6], [24, 12, 6]]}
	for sc in want:
		for row in want[sc]:
			t.eq(R.caps(sc, int(row[0])), {"field": row[1], "companions": row[2]}, "%s L%d caps" % [sc, row[0]])
	for lv in range(2, 25):
		for sc in R.SCALES:
			var a := R.caps(sc, lv)
			var b := R.caps(sc, lv - 1)
			t.ok(int(a["field"]) >= int(b["field"]) and int(a["companions"]) >= int(b["companions"]), "%s caps never shrink at L%d" % [sc, lv])
	for a in range(1, 7):
		t.eq(R.hero_hp(2 * a - 1), mini(20, 12 + 2 * (a - 1)), "hero hp at act %d unchanged (12 + 2 per act, cap 20)" % a)


func _test_power() -> void:
	var tpl := {"id": "p", "name": "p", "scale": "skirmish", "size": [8, 4], "level": 13, "base_level": 13, "turn_limit": 7, "enemy_morale": 10,
		"pad": {"kind": "redcoat", "every": 3}, "map": LANE8, "routes": {"a": ["H2", "G2", "F2", "E2", "D2", "C2", "B2", "A2"], "b": ["H4", "G4", "F4", "E4", "D4", "C4", "B4", "A4"]},
		"waves": [{"turn": 1, "route": "a", "units": ["redcoat", "rifleman"]}, {"turn": 3, "route": "b", "units": ["scots_grey", {"kind": "highlander", "lv_min": 16}]},
			{"turn": 4, "at": "D1", "units": ["british_gun"]}]}
	t.eq(R.validate_template(tpl), [], "power template validates")
	# hand computation at L13 (hp 196%, atk +3, def +0): redcoat 13*(7+1+2)/10=13; rifleman 9*(7+0+2+2)/10=9;
	# scots grey 21*(9+1+4)/10=29; british gun 17*(9+4)/10=22; pads (13-13)/3=0
	t.eq(R.power(tpl, 13), 13 + 9 + 29 + 22, "power at L13 by hand")
	# L16: hp 220%, atk +3, def +1; highlander joins; 1 pad per walking wave
	var p16 := 15 * (7 + 2 + 2) / 10 + 11 * (7 + 0 + 2 + 2) / 10 + 24 * (9 + 2 + 4) / 10 + 26 * (8 + 3 + 2) / 10 + 19 * (9 + 4) / 10 + 2 * (15 * (7 + 2 + 2) / 10)
	t.eq(R.power(tpl, 16), p16, "power at L16 counts lv_min units and pads")
	t.eq(R.recommended_power(tpl, 16), p16 * 110 / 100, "recommended = power x 1.10")
	t.eq(R.power(tpl, 16, {"mods": {"drop_waves": [2]}}), p16 - 19 * 13 / 10, "dropped waves do not count")
	t.eq(R.power("nonsense", 5), 0, "unknown template: 0")
	var party := [{"cls": "grenadier", "max_hp": 22, "atk": 4, "def": 3, "block": 3}, {"cls": "jager"}]
	t.eq(R.party_power(party), 22 * 10 / 10 + 8 * 4 / 10, "party power: max_hp x (atk+def+block)/10, class defaults")
	for tid in USE:
		var last := 0
		for lv in range(1, 25):
			var pw := R.power(tid, lv)
			t.ok(pw >= last, "%s power never drops with L (L%d %d < %d)" % [tid, lv, pw, last])
			last = pw
	# the v1 rivoli at act 1 vs the drafts' anchors are B2's; here only that power grows strictly between used levels
	t.ok(R.power("rivoli", 5) > R.power("rivoli", 3), "rivoli harder at L5 than L3")


func _test_lint() -> void:
	var tpl := {"id": "l", "name": "l", "scale": "major", "size": [8, 4], "level": 9, "turn_limit": 10, "enemy_morale": 10, "map": LANE8,
		"routes": {"a": ["H2", "G2", "F2", "E2", "D2", "C2", "B2", "A2"]}, "waves": [{"turn": 1, "route": "a", "units": ["redcoat"]}]}
	var lint := R.lint_template(tpl)
	t.eq(lint.size(), 3, "boss at L9 with one redcoat: hunters, elites and turns all below target (%s)" % [lint])
	t.eq(R.validate_template(tpl), [], "lint is advice only: the template still validates")
	t.eq(R.lint_template(tpl.merged({"tutorial": true}, true)), [], "tutorials are exempt")


# ---------------------------------------------------------------- A6, A4

func _test_determinism() -> void:
	for tid in ["skirmish_b", "elite_a", "major_a"]:
		for lv in [2, 13, 24]:
			var ros := _ref_roster(R.load_templates()["templates"][tid]["scale"], lv)
			var a := _play(tid, lv, 7, ros, "rain")
			var b := _play(tid, lv, 7, ros, "rain")
			t.eq(JSON.stringify(a["result"]), JSON.stringify(b["result"]), "A6 %s L%d: same seed, same result" % [tid, lv])
			t.eq(t.find_floats(a["result"]), PackedStringArray(), "A6 %s L%d: no floats in the result" % [tid, lv])


func _test_passive_loses() -> void:
	var wins: Array = []
	for tid in USE:
		for lv in [2, 8, 12, 16, 20, 24]:
			for sd in [1, 2]:
				for mode in ["off", "dispatch"]:
					var s: Dictionary = R.new_battle(tid, {"seed": sd, "level": lv, "protagonist": {"enabled": mode == "dispatch"}})
					if mode == "dispatch":
						R.apply(s, "skill", {"unit": "hero"})
					var guard := 0
					while s["phase"] == "command" and guard < 30:
						R.apply(s, "fight", {})
						guard += 1
					if s["outcome"] != "defeat":
						wins.append("%s L%d s%d %s -> %s" % [tid, lv, sd, mode, s["outcome"]])
	t.eq(wins, [], "A4: pressing fight every turn never wins, at any level")


## the templates the campaign uses (scene_map) plus rivoli, as in test_battle_v2; arcole is a v1 demo map on no scene
## (its west route lets a lone protagonist hold G3 at L2) and is reported, not asserted
func _test_hero_alone_loses() -> void:
	var wins: Array = []
	var demo: Array = []
	for tid in USE:
		for lv in [2, 12, 24]:
			var probe: Dictionary = R.new_battle(tid, {"seed": 1, "level": lv, "protagonist": {"enabled": true, "hp": R.hero_hp(lv, 24), "max_hp": R.hero_hp(lv, 24)}})
			for r in range(int(probe["rows"])):
				for c in range(int(probe["cols"])):
					if R._place_err(probe, probe["units"]["hero"], c, r) != "":
						continue
					for facing in ["right", "left", "up", "down"]:
						var s: Dictionary = R.new_battle(tid, {"seed": 1, "level": lv, "protagonist": {"enabled": true, "hp": R.hero_hp(lv, 24), "max_hp": R.hero_hp(lv, 24)}})
						if not bool(R.apply(s, "deploy", {"unit": "hero", "col": c, "row": r, "facing": facing})["ok"]):
							continue
						var guard := 0
						while s["phase"] == "command" and guard < 30:
							R.apply(s, "fight", {})
							guard += 1
						if s["outcome"] == "victory":
							(demo if tid == "arcole" else wins).append("%s L%d %s %s" % [tid, lv, R._label(c, r), facing])
	t.eq(wins, [], "A4: the protagonist alone never wins, on any cell, any facing, any level")
	print("A4 arcole (demo map, not asserted): %s" % [demo])


# ---------------------------------------------------------------- A1, and the A2/A3 report

## an encounter-type pad template (base level 13, one redcoat more per 3 levels), the shape the content packs use
func _pad_template() -> Dictionary:
	return {"id": "pad13", "name": "pad13", "scale": "skirmish", "size": [8, 4], "level": 13, "base_level": 13, "turn_limit": 7, "enemy_morale": 9,
		"pad": {"kind": "redcoat", "every": 3}, "map": ["^^^^^^^^", "E===v==G", "^^w^^^^^", "E======G"],
		"routes": {"a": ["H2", "G2", "F2", "E2", "D2", "C2", "B2", "A2"], "b": ["H4", "G4", "F4", "E4", "D4", "C4", "B4", "A4"]},
		"waves": [{"turn": 1, "route": "a", "units": ["redcoat", "redcoat"]}, {"turn": 2, "route": "b", "units": ["rifleman", "redcoat"]},
			{"turn": 4, "route": "a", "units": ["scots_grey", "redcoat"]}, {"turn": 5, "route": "b", "units": ["redcoat", "redcoat"]}]}


func _test_monotonic() -> void:
	var tpl := _pad_template()
	t.eq(R.validate_template(tpl), [], "pad template validates")
	var rows: Array = []
	for b_ros in ["R(b)", "R1"]:
		var ros := _ref_roster("skirmish", 13) if b_ros == "R(b)" else _r1()
		var prev: Array = []
		for lv in [13, 16, 19, 22]:
			var ws := _ws(tpl, lv, ros)
			rows.append("%s L%d W %d S %d" % [b_ros, lv, ws[0], ws[1]])
			if not prev.is_empty():
				t.ok(int(ws[0]) <= int(prev[0]), "A1 %s: W does not rise from L%d to L%d (%s)" % [b_ros, lv - 3, lv, rows])
				# section 8.5 A1 is stated for R(b): S strictly down, at least 5 points a step; R1 only must not rise
				var drop: int = 5 if b_ros == "R(b)" else 0
				t.ok(int(ws[1]) <= int(prev[1]) - drop, "A1 %s: S falls by >= %d from L%d to L%d (%s)" % [b_ros, drop, lv - 3, lv, rows])
			prev = ws
	print("A1 pad13: " + " | ".join(PackedStringArray(rows)))
	# the v1 templates have no pad, so section 8.5 only tests them at their use level; their act range is printed for B2
	for tid in ["skirmish_b", "elite_a", "major_a"]:
		var sc: String = R.load_templates()["templates"][tid]["scale"]
		var ros1 := _ref_roster(sc, 1, false)
		var line: Array = []
		for lv in [1, 5, 9]:
			var ws1 := _ws(tid, lv, ros1)
			line.append("L%d W %d S %d" % [lv, ws1[0], ws1[1]])
		print("A1 %s R(1): %s" % [tid, " | ".join(PackedStringArray(line))])


func _report_reference() -> void:
	var out: Array = []
	var any_win := false
	for tid in USE:
		var sc: String = R.load_templates()["templates"][tid]["scale"]
		for lv in USE[tid]:
			var ws := _ws(tid, int(lv), _ref_roster(sc, int(lv)))
			any_win = any_win or int(ws[0]) > 0
			out.append("%s L%d R(L): W %d S %d" % [tid, lv, ws[0], ws[1]])
	var pad := _pad_template()
	for lv in [13, 19]:
		var ws2 := _ws(pad, lv, _ref_roster("skirmish", lv))
		any_win = any_win or int(ws2[0]) > 0
		out.append("pad13 L%d R(L): W %d S %d" % [lv, ws2[0], ws2[1]])
	for line in out:
		print("A2/A3 " + str(line))
	t.ok(any_win, "the weak policy with the reference roster wins somewhere (the policy loop works)")
