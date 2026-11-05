# 战斗规则 v2（明日方舟式回合制）的无头测试：模板校验、阻挡与漏怪、回合顺序、猎官、濒死/抬下/伤痕/命悬一线、
# 撤销、预演、羁绊、军心胜负、军令牌、不卡死（每张模板 100 条带种子的随机指令序列）、状态里没有浮点。
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const R = preload("res://scripts/cards/campaign/battle/battle_rules.gd")

## 7×3 单行道：行 1、行 3 全是高地，行 2 是 G2 → A2 的大路
const LANE := ["^^^^^^^", "E=====G", "^^^^^^^"]
const LANE_ROUTE := {"r": ["G2", "F2", "E2", "D2", "C2", "B2", "A2"]}

var t: RefCounted


func _initialize() -> void:
	t = T.new(self, "OCEAN_battle_v2")
	_test_templates()
	_test_blocking()
	_test_heavy_blocking()
	_test_turn_order()
	_test_ranged_miss()
	_test_hunter()
	_test_protagonist()
	_test_protagonist_fall_and_capture()
	_test_dying_carry_scar_fate()
	_test_fate_determinism()
	_test_execute_mark()
	_test_undo()
	_test_preview()
	_test_view_button_flags()
	_test_bonds()
	_test_campaign_bond_sets()
	_test_morale_outcomes()
	_test_cards()
	_test_hussar_and_artillery()
	_test_classes_and_terrain()
	_test_template_variation()
	_test_depth_blocking()
	_test_hussar_no_free_loop()
	_test_barrage_range()
	_test_save_roundtrip()
	_test_dead_cards_and_redraw()
	_test_hunters_by_act()
	_test_bugler_keeps_feint()
	_test_bad_args()
	_test_fate_independence()
	_test_gun_first_fire()
	_test_wave_tags()
	_test_reserved_gun_cell()
	_test_barricade_id()
	_test_command_phase_rout()
	_test_family_coin()
	_test_decapitation()
	_test_passive_loses()
	_test_hero_alone_loses()
	_test_skirmish_variety()
	_test_melee_log()
	_test_preview_cmd()
	_test_carry_reason_and_scar_flag()
	_test_never_stuck()
	_test_no_floats()
	print("OCEAN battle_v2 assertions: %d" % t.checks)
	t.finish()


# ---------------------------------------------------------------- 工具

func _tpl(map: Array, routes: Dictionary, waves: Array, extra: Dictionary = {}) -> Dictionary:
	var scale := "skirmish"
	if map.size() == 4:
		scale = "elite"
	elif map.size() == 5:
		scale = "major"
	var d := {"id": "test", "name": "测试", "scale": scale, "turn_limit": 8, "enemy_morale": 30, "map": map, "routes": routes, "waves": waves}
	d.merge(extra, true)
	return d


func _u(id: String, cls: String, extra: Dictionary = {}) -> Dictionary:
	var d := {"id": id, "cls": cls, "name": id, "cost": 0}
	d.merge(extra, true)
	return d


func _battle(tpl: Dictionary, roster: Array = [], troops: Array = [], hero: bool = false, extra: Dictionary = {}) -> Dictionary:
	var setup := {"seed": 11, "act": 1, "template": tpl, "roster": roster, "troops": troops, "protagonist": {"enabled": hero},
		"cards": ["requisition", "requisition", "requisition"]}
	setup.merge(extra, true)
	var s: Dictionary = R.new_battle("test", setup)
	t.ok(not s.has("error"), "custom battle builds: %s" % str(s.get("errors", "")))
	return s


func _do(s: Dictionary, cmd: String, args: Dictionary = {}) -> bool:
	var r: Dictionary = R.apply(s, cmd, args)
	t.ok(bool(r.get("ok", false)), "%s %s: %s" % [cmd, args, r])
	return bool(r.get("ok", false))


func _no(s: Dictionary, cmd: String, args: Dictionary, err: String, label: String) -> void:
	var before := JSON.stringify(s, "", true)
	var r: Dictionary = R.apply(s, cmd, args)
	t.eq(r.get("ok"), false, label + " rejected")
	t.eq(r.get("err"), err, label + " error")
	t.ok(JSON.stringify(s, "", true) == before, label + " leaves state unchanged")


func _fights(s: Dictionary, n: int) -> void:
	for i in range(n):
		if s["phase"] != "command":
			return
		_do(s, "fight")


func _enemy(s: Dictionary, uid: int) -> Dictionary:
	for e in s["enemies"]:
		if int(e["uid"]) == uid:
			return e
	return {}


func _intent_for(s: Dictionary, uid: int) -> Dictionary:
	for row in R.intents(s):
		if row.get("type") == "enemy" and int(row["enemy"]) == uid:
			return row
	return {}


func _log_index(s: Dictionary, needle: String, from: int = 0) -> int:
	var lg: Array = s["log"]
	for i in range(from, lg.size()):
		if str(lg[i]).find(needle) >= 0:
			return i
	return -1


func _has_log(s: Dictionary, needle: String) -> bool:
	return _log_index(s, needle) >= 0


func _card_index(s: Dictionary, cid: String) -> int:
	for i in range((s["hand"] as Array).size()):
		if s["hand"][i]["id"] == cid and s["hand"][i]["lock"] == "":
			return i
	return -1


func _xs(x: int) -> int:
	x = x & 0xFFFFFFFF
	if x == 0:
		x = 1
	x = (x ^ (x << 13)) & 0xFFFFFFFF
	x = x ^ (x >> 17)
	x = (x ^ (x << 5)) & 0xFFFFFFFF
	return x


# ---------------------------------------------------------------- 模板

func _test_templates() -> void:
	var lib: Dictionary = R.load_templates(true)
	t.ok(lib["ok"], "battle templates load and validate: %s" % str(lib["errors"]))
	var sizes := {"arcole": [8, 4, 8, "elite"], "rivoli": [9, 5, 11, "major"], "skirmish_a": [7, 3, 6, "skirmish"],
		"skirmish_b": [7, 3, 7, "skirmish"], "skirmish_c": [7, 3, 6, "skirmish"],
		"elite_a": [8, 4, 8, "elite"], "major_a": [9, 5, 12, "major"]}
	for tid in sizes.keys():
		t.ok(lib["templates"].has(tid), "template %s exists" % tid)
		var s: Dictionary = R.new_battle(tid, {"seed": 3, "act": 1})
		t.ok(not s.has("error"), "template %s builds a battle" % tid)
		if s.has("error"):
			continue
		t.eq([s["cols"], s["rows"], s["turn_limit"], s["scale"]], sizes[tid], "template %s size, turns and scale" % tid)
	var arcole: Dictionary = lib["templates"]["arcole"]
	t.eq(arcole["order"]["cell"], "E2", "arcole imperial order holds the bridge E2")
	t.eq(arcole["order"]["turn"], 8, "arcole order at turn 8")
	t.eq(arcole["enemy_morale"], 14, "arcole enemy morale 14")
	var rivoli: Dictionary = lib["templates"]["rivoli"]
	t.ok(rivoli["routes"].has("rear"), "rivoli has the rear-gate route")
	var route_waves := 0
	var rear := false
	for w in rivoli["waves"]:
		if w.has("route"):
			route_waves += 1
			if w["route"] == "rear":
				rear = true
	t.eq(route_waves, 6, "rivoli has 6 waves")
	t.ok(rear, "rivoli rear column is a wave")
	t.eq(rivoli["enemy_morale"], 24, "rivoli enemy morale 24")
	# 远洋战役 14 个场景都映射到一张模板和一幕
	var json := JSON.new()
	json.parse(FileAccess.get_file_as_string("res://data/campaigns/ocean_pawn.json"))
	var scenes: Array = json.data["scenes"]
	t.eq(scenes.size(), 14, "ocean campaign has 14 scenes")
	var last_act := 0
	for sc in scenes:
		var row: Dictionary = lib["scene_map"].get(sc["id"], {})
		t.ok(lib["templates"].has(str(row.get("template", ""))), "scene %s maps to a template" % sc["id"])
		t.ok(int(row.get("act", 0)) >= last_act, "scene %s act does not go down" % sc["id"])
		last_act = int(row.get("act", 0))
	t.eq(last_act, 6, "finale is act 6")
	# 难度按幕放大：第 6 幕敌兵力 ×1.8、攻 +2、军心 ×1.67
	var s1: Dictionary = R.new_battle("skirmish_a", {"seed": 3, "act": 1})
	var s6: Dictionary = R.new_battle("skirmish_a", {"seed": 3, "act": 6})
	t.eq(s1["enemies"][0]["hp"], 6, "act 1 whitecoat hp 6")
	t.eq(s6["enemies"][0]["hp"], 10, "act 6 whitecoat hp 6 * 1.8 = 10")
	t.eq(s6["enemies"][0]["atk"], 5, "act 6 enemy attack +2")
	t.eq(s6["enemy_morale"], 13, "act 6 enemy morale 8 * 1.67 = 13")
	# 坏模板都会被校验拒绝
	var good := _tpl(LANE, LANE_ROUTE, [{"turn": 1, "route": "r", "units": ["whitecoat"]}])
	t.eq(R.validate_template(good), [], "hand-written lane template is valid")
	var bad := {
		"route must start at a gate": _tpl(LANE, {"r": ["F2", "E2", "D2", "C2", "B2", "A2"]}, good["waves"]),
		"route must end at the eagle": _tpl(LANE, {"r": ["G2", "F2", "E2", "D2", "C2", "B2"]}, good["waves"]),
		"route cells must be adjacent": _tpl(LANE, {"r": ["G2", "E2", "D2", "C2", "B2", "A2"]}, good["waves"]),
		"route cannot cross a river": _tpl(["^^^^^^^", "E==~==G", "^^^^^^^"], LANE_ROUTE, good["waves"]),
		"route cannot cross marsh": _tpl(["^^^^^^^", "E=m===G", "^^^^^^^"], LANE_ROUTE, good["waves"]),
		"route cannot climb high ground": _tpl(["^^^^^^^", "E=^===G", "^^^^^^^"], LANE_ROUTE, good["waves"]),
		"map size must match the scale": _tpl(["^^^^^^", "E====G", "^^^^^^"], LANE_ROUTE, good["waves"]),
		"unknown enemy": _tpl(LANE, LANE_ROUTE, [{"turn": 1, "route": "r", "units": ["cossack"]}]),
		"guns stand on cells": _tpl(LANE, LANE_ROUTE, [{"turn": 1, "route": "r", "units": ["gun"]}]),
		"unknown route": _tpl(LANE, LANE_ROUTE, [{"turn": 1, "route": "x", "units": ["whitecoat"]}]),
		"wave after the turn limit": _tpl(LANE, LANE_ROUTE, [{"turn": 9, "route": "r", "units": ["whitecoat"]}]),
	}
	for label in bad.keys():
		t.ok(not R.validate_template(bad[label]).is_empty(), "validator: " + label)
	var broken: Dictionary = R.new_battle("test", {"template": bad["route must end at the eagle"]})
	t.eq(broken.get("error"), "bad_template", "new_battle refuses a broken template")
	t.eq(R.new_battle("nope", {}).get("error"), "unknown_template", "unknown template id")
	# 浅滩事件：河格在开门那一回合才能走
	var ford_map := ["^^^^^^^", "E==~==G", "^^^^^^^"]
	var early := _tpl(ford_map, LANE_ROUTE, [{"turn": 4, "route": "r", "units": ["whitecoat"]}], {"events": [{"turn": 5, "cell": "D2", "terrain": "ford"}]})
	var on_time := _tpl(ford_map, LANE_ROUTE, [{"turn": 5, "route": "r", "units": ["whitecoat"]}], {"events": [{"turn": 5, "cell": "D2", "terrain": "ford"}]})
	t.ok(not R.validate_template(early).is_empty(), "validator: a wave cannot use a ford before it opens")
	t.eq(R.validate_template(on_time), [], "validator: a wave may use the ford from the turn it opens")


# ---------------------------------------------------------------- 阻挡

func _test_blocking() -> void:
	var tpl := _tpl(LANE, LANE_ROUTE, [{"turn": 1, "route": "r", "units": ["whitecoat", "whitecoat", "whitecoat", "whitecoat"]}])
	var s := _battle(tpl, [], [_u("g", "grenadier", {"atk": 0, "hp": 60, "max_hp": 60}), _u("g2", "grenadier")])
	_do(s, "deploy", {"unit": "g", "col": 2, "row": 1, "facing": "right"})
	var it := _intent_for(s, 1)
	t.eq(it.get("move_to"), [5, 1], "intent: whitecoat walks one cell to F2")
	_fights(s, 2)
	var it3 := _intent_for(s, 1)
	t.eq(it3.get("move_to"), [3, 1], "intent: whitecoat stops at D2 in front of the blocker")
	t.eq(it3.get("blocked_by"), "g", "intent: blocked by the grenadier")
	t.eq(it3.get("attack", {}).get("target"), "g", "intent: blocked enemy attacks its blocker")
	t.eq(_intent_for(s, 4).get("blocked_by"), "", "intent: the fourth whitecoat is not blocked (block 3 is full)")
	_fights(s, 1)
	var blocked := 0
	for e in s["enemies"]:
		if e["blocked_by"] == "g":
			blocked += 1
			t.eq([e["col"], e["row"]], [3, 1], "blocked whitecoat waits at D2")
	t.eq(blocked, 3, "grenadier blocks exactly 3 enemies")
	t.eq(_enemy(s, 4)["blocked_by"], "", "fourth whitecoat leaks")
	t.eq(R.view(s)["units"][0]["block_used"], 3, "view shows block 3/3 used")
	_no(s, "deploy", {"unit": "g2", "col": 3, "row": 1, "facing": "right"}, "enemy_here", "cannot deploy onto enemies")
	t.eq(_intent_for(s, 4).get("move_to"), [1, 1], "intent: the leaker passes through C2 and lands on B2")
	_fights(s, 1)
	t.eq([_enemy(s, 4)["col"], _enemy(s, 4)["row"]], [1, 1], "leaker never stops on our unit's cell (C2 → B2)")
	t.eq(int(s["leaks"]), 0, "no leak yet")
	t.eq(_intent_for(s, 4).get("attack", {}).get("target"), "eagle", "intent: leaker will reach the eagle")
	_fights(s, 1)
	t.eq(int(s["leaks"]), 1, "leaker reached the eagle")
	t.eq(int(s["morale"]), 8, "an ordinary enemy at the eagle costs 2 morale")
	t.eq(_enemy(s, 4), {}, "enemy that reached the eagle is removed")
	# 撤下阻挡者：被挡住的敌人下回合继续走
	_do(s, "withdraw", {"unit": "g"})
	t.eq(int(s["units"]["g"]["cooldown"]), 2, "withdrawn unit has a 2-turn redeploy cooldown")
	_fights(s, 1)
	for e in s["enemies"]:
		t.eq(e["blocked_by"], "", "blocked enemies are released when the blocker withdraws")
		t.eq(e["col"], 2, "released enemies walk on (D2 → C2)")


func _test_heavy_blocking() -> void:
	# 匈牙利掷弹兵占 2 个阻挡位
	var tpl := _tpl(LANE, LANE_ROUTE, [{"turn": 1, "route": "r", "units": ["hungarian", "whitecoat"]}])
	var s := _battle(tpl, [], [_u("l", "line", {"atk": 0, "hp": 60, "max_hp": 60})])
	_do(s, "deploy", {"unit": "l", "col": 2, "row": 1, "facing": "right"})
	_fights(s, 3)
	t.eq(_enemy(s, 1)["blocked_by"], "l", "heavy enemy takes both block slots of a line (block 2)")
	t.eq(_enemy(s, 2)["blocked_by"], "", "the whitecoat behind it leaks")
	var tpl2 := _tpl(LANE, LANE_ROUTE, [{"turn": 1, "route": "r", "units": ["whitecoat", "hungarian"]}])
	var s2 := _battle(tpl2, [], [_u("l", "line", {"atk": 0, "hp": 60, "max_hp": 60})])
	_do(s2, "deploy", {"unit": "l", "col": 2, "row": 1, "facing": "right"})
	_fights(s2, 3)
	t.eq(_enemy(s2, 1)["blocked_by"], "l", "whitecoat takes one slot")
	t.eq(_enemy(s2, 2)["blocked_by"], "", "heavy enemy leaks when only 1 slot is free")
	_fights(s2, 1)
	t.eq([_enemy(s2, 2)["col"], _enemy(s2, 2)["row"]], [1, 1], "heavy leaker passes the line and lands on B2")
	_fights(s2, 1)
	t.eq(int(s2["morale"]), 7, "an elite at the eagle costs 3 morale")


# ---------------------------------------------------------------- 回合顺序

func _test_turn_order() -> void:
	# a 步先手打死的敌人，意图作废：它不会再白刃
	var tpl := _tpl(LANE, LANE_ROUTE, [{"turn": 1, "route": "r", "units": ["whitecoat"]}, {"turn": 8, "route": "r", "units": ["whitecoat"]}])
	var s := _battle(tpl, [], [_u("l", "line", {"atk": 0, "hp": 20, "max_hp": 20}), _u("j", "jager", {"atk": 10})])
	_do(s, "deploy", {"unit": "l", "col": 2, "row": 1, "facing": "right"})
	_do(s, "deploy", {"unit": "j", "col": 3, "row": 0, "facing": "down"})
	_fights(s, 3)
	t.eq(int(s["units"]["l"]["hp"]), 18, "whitecoat blocked on arrival and hit the line 3-1=2")
	var row := _intent_for(s, 1)
	t.eq(row.get("cancelled"), true, "intent of an enemy our jager kills first is cancelled")
	_fights(s, 1)
	t.eq(int(s["units"]["l"]["hp"]), 18, "cancelled enemy dealt no damage")
	t.eq(int(s["kills"]), 1, "jager killed it in step a")
	# 远程顺序：炮兵 → 猎兵 → 横队
	var tpl2 := _tpl(LANE, LANE_ROUTE, [{"turn": 1, "route": "r", "units": ["whitecoat", "whitecoat", "whitecoat"]}, {"turn": 8, "route": "r", "units": ["whitecoat"]}])
	var s2 := _battle(tpl2, [], [_u("line1", "line"), _u("jag1", "jager"), _u("art1", "artillery")])
	_fights(s2, 2)
	_do(s2, "deploy", {"unit": "line1", "col": 2, "row": 1, "facing": "right"})
	_do(s2, "deploy", {"unit": "jag1", "col": 4, "row": 0, "facing": "down"})
	_do(s2, "deploy", {"unit": "art1", "col": 0, "row": 0, "facing": "right"})
	var mark: int = (s2["log"] as Array).size()
	_fights(s2, 1)
	var ia := _log_index(s2, "art1炮击", mark)
	var ij := _log_index(s2, "jag1射击", mark)
	var il := _log_index(s2, "line1射击", mark)
	t.ok(ia >= 0 and ij > ia and il > ij, "ranged order artillery → jager → line (%d, %d, %d)" % [ia, ij, il])
	t.eq(int(s2["kills"]), 2, "artillery softened all three, jager and line each finished one")
	# c 步白刃同时结算：双方都打出伤害
	var tpl3 := _tpl(LANE, LANE_ROUTE, [{"turn": 1, "route": "r", "units": ["whitecoat"]}, {"turn": 8, "route": "r", "units": ["whitecoat"]}])
	var s3 := _battle(tpl3, [], [_u("g", "grenadier", {"hp": 1, "max_hp": 1, "atk": 20, "def": 0})])
	_do(s3, "deploy", {"unit": "g", "col": 2, "row": 1, "facing": "right"})
	_fights(s3, 3)
	t.eq(int(s3["kills"]), 1, "simultaneous melee: grenadier kills the whitecoat")
	t.eq(s3["units"]["g"]["status"], "routed", "simultaneous melee: the grenadier is cut down too and routs")
	t.eq(s3["routed"], ["g"], "routed troop recorded")
	t.eq(int(s3["morale"]), 9, "troop rout costs 1 morale")


func _test_ranged_miss() -> void:
	# 远程按预告的目标打；目标撤走就打空
	var tpl := _tpl(LANE, LANE_ROUTE, [{"turn": 1, "route": "r", "units": ["grenz"]}, {"turn": 8, "route": "r", "units": ["whitecoat"]}])
	var s := _battle(tpl, [], [_u("j", "jager", {"atk": 0, "hp": 30, "max_hp": 30})])
	_do(s, "deploy", {"unit": "j", "col": 4, "row": 0, "facing": "left"})
	_fights(s, 1)
	var row := _intent_for(s, 1)
	t.eq(row.get("attack", {}).get("target"), "j", "grenz locks the jager on the high ground (range 2)")
	t.eq(row.get("attack", {}).get("dmg"), 3, "grenz damage 3-0=3")
	var s_keep := s.duplicate(true)
	_fights(s_keep, 1)
	t.eq(int(s_keep["units"]["j"]["hp"]), 27, "grenz hits the jager if it stays")
	_do(s, "withdraw", {"unit": "j"})
	_fights(s, 1)
	t.ok(_has_log(s, "打空"), "grenz shot misses after the target withdrew")
	t.eq(int(s["units"]["j"]["hp"]), 30, "withdrawn jager took no damage")


# ---------------------------------------------------------------- 猎官

func _test_hunter() -> void:
	var tpl := _tpl(LANE, LANE_ROUTE, [{"turn": 1, "route": "r", "units": ["dragoon"]}, {"turn": 8, "route": "r", "units": ["whitecoat"]}])
	var s := _battle(tpl, [], [_u("l", "line", {"atk": 0, "hp": 30, "max_hp": 30})], true)
	_do(s, "deploy", {"unit": "hero", "col": 2, "row": 0, "facing": "down"})
	_do(s, "deploy", {"unit": "l", "col": 1, "row": 1, "facing": "right"})
	_fights(s, 1)
	var row := _intent_for(s, 1)
	t.eq(row.get("move_to"), [2, 1], "hunter dragoon dashes to C2, next to the protagonist")
	t.eq(row.get("attack", {}).get("target"), "hero", "hunter targets the protagonist")
	t.ok("hunter" in row.get("marks", []), "intent carries the hunter mark (target)")
	t.eq(row.get("blocked_by"), "", "hunter is not blocked by the line behind")
	_fights(s, 1)
	t.eq(int(s["units"]["hero"]["hp"]), 8, "dragoon hits the protagonist 5-1=4")
	t.eq(int(s["units"]["l"]["hp"]), 30, "the line is ignored")
	# 没有主角：同一条龙骑兵被横队挡住，打横队
	var s2 := _battle(tpl, [], [_u("l", "line", {"atk": 0, "hp": 30, "max_hp": 30})], false)
	_do(s2, "deploy", {"unit": "l", "col": 1, "row": 1, "facing": "right"})
	_fights(s2, 2)
	t.eq(_enemy(s2, 1)["blocked_by"], "l", "without the protagonist the dragoon is blocked as usual")
	t.eq(int(s2["units"]["l"]["hp"]), 26, "and hits the line")
	# 带猎官标签的敌炮：准星落在主角身上
	var tpl3 := _tpl(LANE, LANE_ROUTE, [{"turn": 1, "at": "G1", "units": [{"kind": "gun", "tags": ["hunter"]}]}, {"turn": 8, "route": "r", "units": ["whitecoat"]}])
	var s3 := _battle(tpl3, [], [_u("l", "line", {"atk": 0, "hp": 30, "max_hp": 30})], true)
	_do(s3, "deploy", {"unit": "hero", "col": 0, "row": 0, "facing": "right"})
	_do(s3, "deploy", {"unit": "l", "col": 4, "row": 1, "facing": "right"})
	_fights(s3, 1)
	var cross: Array = []
	for r in R.intents(s3):
		if r.get("type") == "crosshair":
			cross.append(r)
	t.eq(cross.size(), 1, "gun crosshair shown a turn early")
	t.eq(cross[0].get("cell") if not cross.is_empty() else [], [0, 0], "hunter gun aims at the protagonist")
	t.eq(cross[0].get("now") if not cross.is_empty() else true, false, "crosshair fires next turn")
	t.ok("hunter" in _intent_for(s3, 1).get("marks", []), "gun intent marked hunter")


# ---------------------------------------------------------------- 主角

func _test_protagonist() -> void:
	var tpl := _tpl(LANE, LANE_ROUTE, [{"turn": 8, "route": "r", "units": ["whitecoat"]}])
	var s := _battle(tpl, [], [], true)
	t.eq(int(s["cp"]), 6, "opening command points 6")
	_do(s, "deploy", {"unit": "hero", "col": 0, "row": 0, "facing": "right"})
	t.eq(int(s["morale"]), 13, "protagonist on the field: morale +3")
	t.eq(R.view(s)["cp_next"], 4, "+3 per turn, +1 with the protagonist")
	_fights(s, 1)
	t.eq(int(s["cp"]), 10, "turn 2 command points 6 + 4")
	_no(s, "skill", {"unit": "hero"}, "not_ready", "pay chest needs 4 charge")
	_fights(s, 3)
	t.eq(int(s["units"]["hero"]["charge"]), 4, "pay chest charged after 4 turns")
	var cp: int = int(s["cp"])
	_do(s, "skill", {"unit": "hero"})
	t.eq(int(s["cp"]), mini(20, cp + 3), "开箱发饷: CP +3")
	t.eq(int(s["morale"]), 14, "开箱发饷: morale +1")
	_do(s, "withdraw", {"unit": "hero"})
	t.eq(int(s["morale"]), 12, "withdrawing the protagonist costs 2 morale")
	_no(s, "deploy", {"unit": "hero", "col": 0, "row": 0, "facing": "right"}, "not_in_bar", "protagonist deploys only once")
	# 后方调度：不上场时每场一次军令点 +3，之后不能再上阵
	var s2 := _battle(tpl, [], [], true)
	_do(s2, "skill", {"unit": "hero"})
	t.eq(int(s2["cp"]), 9, "后方调度: CP +3")
	_no(s2, "deploy", {"unit": "hero", "col": 0, "row": 0, "facing": "right"}, "not_in_bar", "after 后方调度 he stays at headquarters")
	# 站住！：军心第一次掉到 3 以下时拉回 3，主角兵力 −4
	var tpl3 := _tpl(LANE, LANE_ROUTE, [{"turn": 1, "route": "r", "units": ["whitecoat"]}, {"turn": 8, "route": "r", "units": ["whitecoat"]}])
	var s3 := _battle(tpl3, [], [], true, {"morale": 1})
	_do(s3, "deploy", {"unit": "hero", "col": 0, "row": 0, "facing": "right"})
	t.eq(int(s3["morale"]), 4, "morale 1 + 3")
	_fights(s3, 6)
	t.eq(int(s3["leaks"]), 1, "whitecoat reached the eagle")
	t.eq(int(s3["morale"]), 3, "站住！ holds morale at 3")
	t.eq(int(s3["units"]["hero"]["hp"]), 8, "站住！ costs the protagonist 4 hp")
	t.eq(bool(s3["hero"]["rally_used"]), true, "站住！ once per battle")
	# 奖赏：主角打完仍在场，法郎 ×1.5、勋章 +1
	var quick := _tpl(LANE, LANE_ROUTE, [{"turn": 1, "route": "r", "units": ["whitecoat"]}, {"turn": 8, "route": "r", "units": ["whitecoat"]}], {"enemy_morale": 1})
	var with_hero := _battle(quick, [], [_u("j", "jager", {"atk": 10})], true)
	_do(with_hero, "deploy", {"unit": "hero", "col": 0, "row": 0, "facing": "right"})
	_do(with_hero, "deploy", {"unit": "j", "col": 4, "row": 0, "facing": "down"})
	var without := _battle(quick, [], [_u("j", "jager", {"atk": 10})], true)
	_do(without, "deploy", {"unit": "j", "col": 4, "row": 0, "facing": "down"})
	_fights(with_hero, 3)
	_fights(without, 3)
	var rw: Dictionary = R.result(with_hero)
	var ro: Dictionary = R.result(without)
	t.eq([rw["outcome"], rw["victory_kind"]], ["victory", "rout"], "enemy morale 0: rout victory")
	t.eq(ro["rewards"], {"franc": 75, "gold": 0, "medal": 3}, "rout ★★ skirmish: 50 +50% francs, 1+2 medals")
	t.eq(rw["rewards"], {"franc": 112, "gold": 0, "medal": 4}, "protagonist on the field: francs ×1.5, medals +1")
	t.eq(rw["protagonist_on_field_at_end"], true, "result says the protagonist finished on the field")


func _test_protagonist_fall_and_capture() -> void:
	var tpl := _tpl(LANE, LANE_ROUTE, [{"turn": 1, "route": "r", "units": ["whitecoat"]}, {"turn": 5, "route": "r", "units": ["whitecoat"]}], {"turn_limit": 5})
	var s := _battle(tpl, [_u("milon", "line", {"atk": 0, "hp": 30, "max_hp": 30, "tags": ["italy"]})], [], true,
		{"protagonist": {"enabled": true, "hp": 1, "max_hp": 12}, "bonds_trust": {"hero|milon": 2}})
	_do(s, "deploy", {"unit": "hero", "col": 2, "row": 1, "facing": "right"})
	_do(s, "deploy", {"unit": "milon", "col": 1, "row": 1, "facing": "right"})
	_fights(s, 3)
	t.eq(s["units"]["hero"]["status"], "down", "protagonist at 0 hp leaves the field")
	t.eq(int(s["morale"]), 8, "protagonist falls: morale 13 - 5")
	t.eq(bool(s["hero"]["guard"]), true, "trusted companion adjacent: guard")
	_fights(s, 5)
	var res: Dictionary = R.result(s)
	t.eq(res["fallen"][0]["unit"], "hero", "fate roll for the protagonist")
	t.eq(res["fallen"][0]["coins"], 3, "2 coins + 1 guard")
	t.eq(res["fallen"][0]["coin_faces"].size(), 3, "three faces")
	t.eq(R.result(s), res, "result is stable: same state, same coins")
	# 主角在场时输掉：被俘，不掷铜钱
	var tpl2 := _tpl(LANE, LANE_ROUTE, [{"turn": 1, "route": "r", "units": ["whitecoat", "whitecoat", "whitecoat"]}])
	var s2 := _battle(tpl2, [], [], true, {"morale": 1})
	_do(s2, "deploy", {"unit": "hero", "col": 0, "row": 0, "facing": "right"})
	_fights(s2, 6)
	var r2: Dictionary = R.result(s2)
	t.eq(r2["outcome"], "defeat", "three leaks break morale 4 → defeat")
	t.eq(r2["captured"], ["hero"], "protagonist on the field when we lose is captured")
	t.eq(r2["fallen"], [], "no fate roll when captured")
	t.eq(r2["rewards"], {"franc": 0, "gold": 0, "medal": 0}, "no rewards on defeat")
	t.eq(r2["stars"], 0, "no stars on defeat")


# ---------------------------------------------------------------- 濒死、抬下、伤痕、命悬一线

func _fall_battle(seed_value: int, milon: Dictionary, helpers: Array, turn_limit: int = 6) -> Dictionary:
	var tpl := _tpl(LANE, LANE_ROUTE, [{"turn": 1, "route": "r", "units": ["whitecoat"]}, {"turn": turn_limit, "route": "r", "units": ["whitecoat"]}], {"turn_limit": turn_limit})
	var m := {"id": "milon", "cls": "line", "name": "米隆", "cost": 0, "hp": 1, "max_hp": 16, "atk": 0, "tags": ["italy"]}
	m.merge(milon, true)
	var s := _battle(tpl, [m], helpers, false, {"seed": seed_value})
	_do(s, "deploy", {"unit": "milon", "col": 2, "row": 1, "facing": "right"})
	for h in helpers:
		_do(s, "deploy", {"unit": h["id"], "col": int(h.get("at", [2, 0])[0]), "row": int(h.get("at", [2, 0])[1]), "facing": "right"})
	_fights(s, 3)
	return s


## 界面按钮用的视图字段：刚部署的不能撤（can_withdraw），后方调度（can_dispatch）用一次就没了
func _test_view_button_flags() -> void:
	var tpl := _tpl(LANE, LANE_ROUTE, [{"turn": 1, "route": "r", "units": ["whitecoat"]}])
	var s := _battle(tpl, [_u("a", "line")], [], false)
	_do(s, "deploy", {"unit": "a", "col": 2, "row": 1, "facing": "right"})
	t.eq(_unit_view(s, "a").get("can_withdraw"), false, "view: just deployed, withdraw button off")
	var hero_bar: Dictionary = R.view(s)["deploy_bar"].filter(func(b: Dictionary) -> bool: return b["uid"] == "hero")[0]
	t.eq(hero_bar.get("can_dispatch"), true, "view: rear dispatch available")
	_do(s, "fight")
	t.eq(_unit_view(s, "a").get("can_withdraw"), true, "view: next turn, withdraw button on")
	_do(s, "skill", {"unit": "hero"})
	hero_bar = R.view(s)["deploy_bar"].filter(func(b: Dictionary) -> bool: return b["uid"] == "hero")[0]
	t.eq(hero_bar.get("can_dispatch"), false, "view: rear dispatch used once")


func _test_dying_carry_scar_fate() -> void:
	var s := _fall_battle(5, {}, [_u("helper", "jager", {"atk": 0, "at": [2, 0]})])
	var m: Dictionary = s["units"]["milon"]
	t.eq(m["status"], "dying", "companion at 0 hp is dying")
	t.eq([m["col"], m["row"]], [2, 1], "dying companion stays on his cell")
	t.eq(int(s["morale"]), 8, "companion falls: morale -2")
	var vu: Dictionary = {}
	for u in R.view(s)["units"]:
		if u["uid"] == "milon":
			vu = u
	t.eq([vu.get("state"), vu.get("block")], ["dying", 0], "view: dying, block 0")
	t.eq([vu.get("can_carry"), vu.get("carry_cost"), vu.get("can_withdraw")], [true, 2, false], "view: carry button on (2 CP), withdraw off")
	t.eq(_unit_view(_fall_battle(5, {}, []), "milon").get("can_carry"), false, "view: nobody adjacent, carry button off")
	t.eq(_unit_view(_fall_battle(5, {"max_hp": 1}, [_u("marie", "medic", {"at": [2, 0]})]), "milon").get("carry_cost"), 0, "view: medic adjacent, carry is free")
	t.eq(_enemy(s, 1)["blocked_by"], "", "dying companion blocks nobody")
	_no(s, "withdraw", {"unit": "milon"}, "dying_use_carry", "a dying companion is carried, not withdrawn")
	# 抬下：2 军令点，相邻要有我方单位
	var s_carry := s.duplicate(true)
	var cp: int = int(s_carry["cp"])
	_do(s_carry, "carry", {"unit": "milon"})
	t.eq(int(s_carry["cp"]), cp - 2, "carry costs 2 command points")
	t.eq(s_carry["units"]["milon"]["status"], "carried", "carried off the field")
	_fights(s_carry, 5)
	var rc: Dictionary = R.result(s_carry)
	t.eq(rc["outcome"], "victory", "held to the turn limit")
	t.eq(rc["fallen"][0]["rolled"], false, "unscarred + carried: no fate roll")
	t.eq(rc["scars"], ["milon"], "unscarred + carried: one scar")
	t.eq(rc["stars"], 2, "a companion fell: no third star")
	# 没被抬下，撑过了下一次敌方阶段：伤痕 + 命悬一线（3 枚）
	var s_left := s.duplicate(true)
	_fights(s_left, 5)
	var rl: Dictionary = R.result(s_left)
	t.eq(rl["fallen"][0]["rolled"], true, "unscarred, left on the field through an enemy phase: fate roll")
	t.eq(rl["fallen"][0]["coins"], 3, "base 3 coins")
	t.eq(rl["fallen"][0]["died"], not (1 in rl["fallen"][0]["coin_faces"]), "death only if every coin is tails")
	# 没有相邻单位就抬不下来
	var lone := _fall_battle(5, {}, [])
	_no(lone, "carry", {"unit": "milon"}, "no_adjacent", "carry needs an adjacent ally")
	# 军医相邻：免费抬下
	var with_medic := _fall_battle(5, {"max_hp": 1}, [_u("marie", "medic", {"at": [2, 0]})])
	var cp2: int = int(with_medic["cp"])
	_do(with_medic, "carry", {"unit": "milon"})
	t.eq(int(with_medic["cp"]), cp2, "carry is free with a medic adjacent")
	# 已经带伤的再倒下：掷命悬一线，被抬下 +1 枚
	var scarred := _fall_battle(5, {"scarred": true}, [_u("helper", "jager", {"atk": 0, "at": [2, 0]})])
	t.eq(int(scarred["units"]["milon"]["max_hp"]), 12, "scar: max hp 16 -25% = 12")
	_do(scarred, "carry", {"unit": "milon"})
	_fights(scarred, 5)
	var rs: Dictionary = R.result(scarred)
	t.eq([rs["fallen"][0]["rolled"], rs["fallen"][0]["coins"]], [true, 4], "scarred + carried: roll with 3+1 coins")
	# 宿命之地：按带伤算，−2 枚
	var fated := _fall_battle(5, {"fated": true}, [])
	_fights(fated, 5)
	var rf: Dictionary = R.result(fated)
	t.eq([rf["fallen"][0]["rolled"], rf["fallen"][0]["coins"]], [true, 1], "fated ground: 3-2=1 coin")
	# 输掉这一仗：没被抬下的濒死伙伴被俘
	var lost := _fall_battle(5, {}, [], 8)
	lost["morale"] = 2
	_fights(lost, 3)
	var rlost: Dictionary = R.result(lost)
	t.eq(rlost["outcome"], "defeat", "leak at morale 2 → defeat")
	t.eq(rlost["captured"], ["milon"], "uncarried dying companion is captured on defeat")
	t.eq(rlost["fallen"][0]["rolled"], false, "captured: no fate roll")
	# 撤出：没被抬下 −1 枚
	var fled := _fall_battle(5, {"scarred": true}, [])
	_do(fled, "retreat")
	var rfl: Dictionary = R.result(fled)
	t.eq([rfl["outcome"], rfl["fallen"][0]["coins"]], ["retreat", 2], "retreat without carrying: 3-1=2 coins")
	_no(fled, "fight", {}, "battle_over", "no fight after the battle ended")
	# 军需官的人（主角 + 2 人）：第一个倒下的伙伴视为已经被抬下
	var tpl := _tpl(LANE, LANE_ROUTE, [{"turn": 1, "route": "r", "units": ["whitecoat"]}, {"turn": 6, "route": "r", "units": ["whitecoat"]}], {"turn_limit": 6})
	var qm := _battle(tpl, [
		{"id": "corso", "cls": "line", "name": "科尔索", "cost": 0, "hp": 1, "atk": 0, "tags": ["quartermaster"]},
		{"id": "marie", "cls": "medic", "name": "玛丽", "cost": 0, "tags": ["quartermaster", "family"]}], [], true)
	_do(qm, "deploy", {"unit": "hero", "col": 0, "row": 0, "facing": "right"})
	_do(qm, "deploy", {"unit": "corso", "col": 2, "row": 1, "facing": "right"})
	_do(qm, "deploy", {"unit": "marie", "col": 4, "row": 0, "facing": "right"})
	t.eq(qm["bonds"]["quartermasters_men"]["tier"], 3, "军需官的人 hero + 2")
	_fights(qm, 3)
	t.eq(qm["units"]["corso"]["status"], "carried", "first fallen companion counts as carried")
	t.eq(qm["bonds"]["quartermasters_men"]["tier"], 2, "fallen companion leaves the bond")


func _test_fate_determinism() -> void:
	var faces := {}
	var died := {}
	for seed_value in range(1, 41):
		var a := _fall_battle(seed_value, {"fated": true}, [])
		_fights(a, 5)
		var b := _fall_battle(seed_value, {"fated": true}, [])
		_fights(b, 5)
		var ra: Dictionary = R.result(a)
		var rb: Dictionary = R.result(b)
		t.eq(ra["fallen"], rb["fallen"], "seed %d: same seed, same coins" % seed_value)
		faces[str(ra["fallen"][0]["coin_faces"])] = true
		died[ra["fallen"][0]["died"]] = true
	t.ok(faces.size() >= 2, "different seeds give different coin faces across a sample")
	t.ok(died.has(true) and died.has(false), "across 40 seeds a 1-coin fate roll both kills and spares")
	var three := {}
	for seed_value in range(1, 25):
		var c := _fall_battle(seed_value, {}, [])
		_fights(c, 5)
		three[str(R.result(c)["fallen"][0]["coin_faces"])] = true
	t.ok(three.size() >= 3, "3-coin rolls vary with the seed (%d patterns)" % three.size())


func _test_execute_mark() -> void:
	var tpl := _tpl(LANE, LANE_ROUTE, [{"turn": 1, "at": "G1", "units": [{"kind": "gun", "tags": ["execute"]}]}, {"turn": 8, "route": "r", "units": ["whitecoat"]}])
	var s := _battle(tpl, [{"id": "milon", "cls": "line", "name": "米隆", "cost": 0, "hp": 3, "max_hp": 16, "atk": 0, "scarred": true}], [])
	_do(s, "deploy", {"unit": "milon", "col": 5, "row": 1, "facing": "right"})
	_fights(s, 1)
	var cross: Dictionary = {}
	for r in R.intents(s):
		if r.get("type") == "crosshair":
			cross = r
	t.eq(cross.get("cell"), [5, 1], "gun crosshair on F2 one turn early")
	t.ok("execute" in cross.get("marks", []), "crosshair carries the execute skull")
	_fights(s, 1)
	t.eq(_intent_for(s, 1).get("attack", {}).get("kind"), "gun", "gun fires this turn")
	t.eq(_intent_for(s, 1).get("attack", {}).get("dmg"), 5, "gun damage 6-1=5")
	_fights(s, 2)
	t.eq(s["units"]["milon"]["status"], "dying", "execute shell downs the companion")
	t.eq(s["fallen"][0]["execute"], true, "fall recorded as an execute")
	_do(s, "retreat")
	var res: Dictionary = R.result(s)
	t.eq(res["fallen"][0]["coins"], 1, "execute -1, retreat without carry -1: 3-2=1")
	# 佯动挪开准星：打空
	var s2 := _battle(tpl, [{"id": "milon", "cls": "line", "name": "米隆", "cost": 0, "hp": 3, "max_hp": 16, "atk": 0}], [], false, {"cards": ["feint", "feint", "feint"]})
	_do(s2, "deploy", {"unit": "milon", "col": 5, "row": 1, "facing": "right"})
	_fights(s2, 2)
	_do(s2, "card", {"index": 0, "col": 4, "row": 1})
	_fights(s2, 1)
	t.eq(int(s2["units"]["milon"]["hp"]), 3, "feint moved the crosshair: the shell lands on an empty cell")
	t.ok(_has_log(s2, "打空"), "gun shot logged as a miss")


# ---------------------------------------------------------------- 撤销与预演

func _arcole(seed_value: int, extra: Dictionary = {}) -> Dictionary:
	var setup := {"seed": seed_value, "act": 1, "cp_bonus": 7, "protagonist": {"enabled": true},
		"roster": [
			{"id": "milon", "cls": "line", "name": "米隆", "hp": 16, "max_hp": 16, "atk": 5, "def": 1, "block": 2, "cost": 5, "skill": "raise_flag", "tags": ["italy"], "fated": true},
			{"id": "corso", "cls": "jager", "name": "科尔索", "hp": 8, "max_hp": 8, "atk": 4, "def": 0, "block": 0, "cost": 3, "skill": "mark_target", "tags": ["italy", "quartermaster"]},
			{"id": "baptiste", "cls": "engineer", "name": "巴蒂斯特", "hp": 14, "max_hp": 14, "atk": 3, "def": 2, "block": 1, "cost": 3, "skill": "fortify", "tags": ["italy", "quartermaster"]},
			{"id": "marie", "cls": "medic", "name": "玛丽", "hp": 10, "max_hp": 10, "atk": 0, "def": 1, "block": 0, "cost": 3, "tags": ["quartermaster", "family"]}],
		"troops": [{"id": "battery", "cls": "artillery", "name": "炮兵连"}, {"id": "grenadiers", "cls": "grenadier", "name": "掷弹兵营"},
			{"id": "line2", "cls": "line", "name": "第 32 战列"}, {"id": "hussars", "cls": "hussar", "name": "骠骑兵"}],
		"bonds_trust": {"hero|milon": 2}, "cards": ["requisition", "volley", "fallback", "bugler", "feint", "barrage", "bayonet", "emperor"]}
	setup.merge(extra, true)
	return R.new_battle("arcole", setup)


func _test_undo() -> void:
	var s := _arcole(9, {"cards": ["requisition", "volley", "fallback"]})
	t.eq(int(s["cp"]), 15, "arcole opening CP 6 + Italy 2 + bonus 7")
	var states: Array = [JSON.stringify(s, "", true)]
	_do(s, "deploy", {"unit": "hero", "col": 1, "row": 1, "facing": "right"})
	states.append(JSON.stringify(s, "", true))
	_do(s, "deploy", {"unit": "milon", "col": 3, "row": 1, "facing": "right"})
	states.append(JSON.stringify(s, "", true))
	_do(s, "formation", {"unit": "milon", "square": true})
	states.append(JSON.stringify(s, "", true))
	_do(s, "deploy", {"unit": "battery", "col": 1, "row": 0, "facing": "right"})
	states.append(JSON.stringify(s, "", true))
	_do(s, "aim", {"unit": "battery", "col": 6, "row": 0})
	states.append(JSON.stringify(s, "", true))
	var ri := _card_index(s, "requisition")
	t.ok(ri >= 0, "requisition in the opening hand (or locked)")
	if ri >= 0:
		_do(s, "card", {"index": ri})
		states.append(JSON.stringify(s, "", true))
	t.eq(R.view(s)["can_undo"], true, "view says undo is available")
	_no(s, "aim", {"unit": "battery", "col": 7, "row": 3}, "out_of_pattern", "aim outside the pattern")
	_no(s, "deploy", {"unit": "corso", "col": 2, "row": 1, "facing": "right"}, "terrain", "a jager needs high ground")
	_no(s, "deploy", {"unit": "line2", "col": 3, "row": 1, "facing": "right"}, "occupied", "one unit per cell")
	_no(s, "deploy", {"unit": "line2", "col": 2, "row": 1, "facing": "sideways"}, "bad_facing", "facing must be left/right/up/down")
	_no(s, "nonsense", {}, "bad_cmd", "unknown command")
	for i in range(states.size() - 1, 0, -1):
		_do(s, "undo")
		t.ok(JSON.stringify(s, "", true) == states[i - 1], "undo level %d restores the exact earlier state" % i)
	_no(s, "undo", {}, "nothing_to_undo", "undo stack empty at phase start")
	_do(s, "deploy", {"unit": "hero", "col": 1, "row": 1, "facing": "right"})
	_do(s, "fight")
	_no(s, "undo", {}, "nothing_to_undo", "fight commits the turn: nothing to undo")


func _test_preview() -> void:
	var s := _arcole(4)
	_do(s, "deploy", {"unit": "hero", "col": 1, "row": 1, "facing": "right"})
	_do(s, "deploy", {"unit": "milon", "col": 3, "row": 1, "facing": "right"})
	_do(s, "deploy", {"unit": "corso", "col": 3, "row": 0, "facing": "right"})
	var deployed_more := false
	for turn in range(8):
		if s["phase"] != "command":
			break
		if turn == 1 and not deployed_more:
			deployed_more = true
			R.apply(s, "deploy", {"unit": "battery", "col": 1, "row": 0, "facing": "right"})
			R.apply(s, "deploy", {"unit": "grenadiers", "col": 2, "row": 1, "facing": "right"})
		var before := JSON.stringify(s, "", true)
		var p: Dictionary = R.preview(s)
		R.intents(s)
		R.view(s)
		t.ok(JSON.stringify(s, "", true) == before, "turn %d: preview / intents / view do not mutate state" % s["turn"])
		_do(s, "fight")
		var ok := true
		for uid in s["order"]:
			var u: Dictionary = s["units"][uid]
			var pu: Dictionary = p["units"].get(uid, {})
			if pu.get("hp") != u["hp"] or pu.get("status") != u["status"] or pu.get("col") != u["col"]:
				ok = false
		for key in p["enemies"].keys():
			var e := _enemy(s, int(key))
			if bool(p["enemies"][key]["alive"]) != (not e.is_empty()) or (not e.is_empty() and int(p["enemies"][key]["hp"]) != int(e["hp"])):
				ok = false
		t.ok(ok, "turn %d: preview matched the fight (units and enemies)" % turn)
		t.eq([p["morale"], p["enemy_morale"], p["cp"], p["turn"], p["phase"]], [s["morale"], s["enemy_morale"], s["cp"], s["turn"], s["phase"]],
			"turn %d: preview matched morale / CP / turn" % turn)
	t.eq(R.preview(s).get("ok"), s["phase"] == "command", "preview only while the battle runs")


# ---------------------------------------------------------------- 羁绊

func _test_bonds() -> void:
	var open := ["^^^^^^^^^", "E=======G", "^^^^^^^^^", ".........", "........."]
	var route := {"r": ["I2", "H2", "G2", "F2", "E2", "D2", "C2", "B2", "A2"]}
	var tpl := _tpl(open, route, [{"turn": 9, "route": "r", "units": ["whitecoat"]}], {"turn_limit": 10})
	var s := _battle(tpl,
		[_u("c1", "line", {"tags": ["italy"]}), _u("c2", "jager", {"tags": ["italy"]}), _u("c3", "medic", {"tags": ["quartermaster"]})],
		[_u("a1", "artillery"), _u("a2", "artillery"), _u("a3", "artillery"), _u("g1", "grenadier"), _u("g2", "grenadier")], true, {"act": 5})
	_do(s, "deploy", {"unit": "a1", "col": 0, "row": 0, "facing": "right"})
	t.eq(s["bonds"]["artillery_school"]["tier"], 0, "one gun: no bond")
	_do(s, "deploy", {"unit": "a2", "col": 1, "row": 0, "facing": "right"})
	t.eq([s["bonds"]["artillery_school"]["tier"], s["bonds"]["artillery_school"]["active"]], [2, true], "two guns: 炮兵学派 tier 2")
	_do(s, "deploy", {"unit": "a3", "col": 2, "row": 0, "facing": "right"})
	t.eq(s["bonds"]["artillery_school"]["tier"], 3, "three guns: tier 3")
	t.eq(R.view(s)["units"][2]["atk"], 7, "tier 3: artillery attack +1")
	_no(s, "withdraw", {"unit": "a3"}, "just_deployed", "a unit deployed this turn cannot be withdrawn (undo instead)")
	_do(s, "fight")
	_do(s, "withdraw", {"unit": "a3"})
	t.eq(s["bonds"]["artillery_school"]["tier"], 2, "withdraw recomputes live: back to tier 2")
	_do(s, "deploy", {"unit": "g1", "col": 0, "row": 3, "facing": "right"})
	_do(s, "deploy", {"unit": "g2", "col": 2, "row": 3, "facing": "right"})
	t.eq(s["bonds"]["square"]["tier"], 0, "方阵 needs grenadiers adjacent")
	_do(s, "fight")
	_do(s, "withdraw", {"unit": "g2"})
	s["units"]["g2"]["cooldown"] = 0
	_do(s, "deploy", {"unit": "g2", "col": 1, "row": 3, "facing": "right"})
	t.eq(s["bonds"]["square"]["tier"], 2, "adjacent grenadiers: 方阵 tier 2")
	var g_view: Dictionary = {}
	for u in R.view(s)["units"]:
		if u["uid"] == "g1":
			g_view = u
	t.eq(g_view.get("def"), 4, "方阵 2: def 3 + 1")
	# 阵营羁绊只数伙伴和主角
	_do(s, "deploy", {"unit": "hero", "col": 3, "row": 3, "facing": "right"})
	_do(s, "deploy", {"unit": "c1", "col": 4, "row": 3, "facing": "right"})
	t.eq(s["bonds"]["army_of_italy"]["tier"], 2, "hero + 1: 意大利军团 2")
	_do(s, "deploy", {"unit": "c2", "col": 4, "row": 0, "facing": "right"})
	t.eq(s["bonds"]["army_of_italy"]["tier"], 3, "hero + 2: 意大利军团 3")
	t.eq(R.view(s)["cp_next"], 5, "CP per turn 3 + hero 1 + Italy 1")
	# 同时最多 3 条
	var active := 0
	for bid in s["bonds"].keys():
		if bool(s["bonds"][bid]["active"]):
			active += 1
	t.eq(active, 3, "artillery 2, square 2, Italy 3 all active")
	_do(s, "deploy", {"unit": "c3", "col": 5, "row": 3, "facing": "right"})
	t.eq(s["bonds"]["quartermasters_men"]["tier"], 2, "军需官的人 qualifies at hero + 1")
	active = 0
	for bid in s["bonds"].keys():
		if bool(s["bonds"][bid]["active"]):
			active += 1
	t.eq(active, 3, "at most 3 class + faction bonds at once")
	t.eq(s["bonds"]["army_of_italy"]["active"], true, "highest tier bond stays active")
	_do(s, "fight")
	_do(s, "withdraw", {"unit": "hero"})
	t.eq([s["bonds"]["quartermasters_men"]["tier"], s["bonds"]["army_of_italy"]["tier"]], [0, 2], "protagonist leaves: 军需官的人 off, Italy down to 2")
	t.ok("artillery_school" in s["bonds_seen"] and "army_of_italy" in s["bonds_seen"], "bonds used are recorded")
	# 意大利军团 2 档的开场 +2 按出征名单算
	t.eq(int(_battle(tpl, [_u("c1", "line", {"tags": ["italy"]})], [], true)["cp"]), 8, "Italy 2 in the roster: opening CP 8")
	t.eq(int(_battle(tpl, [_u("c1", "line", {"tags": ["italy"]})], [], false)["cp"]), 6, "protagonist not brought: opening CP 6")
	# 场上人数上限（会战第 1 幕 7 人，伙伴 4 人）
	var cap := _battle(tpl, [], [_u("l1", "line"), _u("l2", "line"), _u("l3", "line"), _u("l4", "line"), _u("l5", "line"), _u("l6", "line"), _u("l7", "line"), _u("l8", "line")])
	for i in range(7):
		_do(cap, "deploy", {"unit": "l%d" % (i + 1), "col": i, "row": 3, "facing": "right"})
	_no(cap, "deploy", {"unit": "l8", "col": 7, "row": 3, "facing": "right"}, "field_full", "field cap 7")


# ---------------------------------------------------------------- 战役自配的羁绊（bond_set / bonds）

func _test_campaign_bond_sets() -> void:
	var lib := R.load_templates()
	t.ok(lib["ok"], "templates + bond sets validate: %s" % [lib["errors"]])
	t.eq(R.validate_bonds(lib["bond_sets"].get("ocean", [])), [], "ocean bond set validates")
	t.eq((lib["bond_sets"]["ocean"] as Array).size(), 8, "ocean: 3 class bonds + 5 faction bonds")
	for bad in [[], ["nope"], ["square", "square"],
			[{"id": "x", "name": "x", "kind": "faction", "tag": "t", "tiers": [2], "effect": "square"}],
			[{"id": "x", "name": "x", "kind": "class", "cls": "line", "tiers": [2], "effect": "square"}],
			[{"id": "x", "name": "x", "kind": "faction", "tag": "t", "tiers": [3, 2], "effect": "spoils"}],
			[{"id": "x", "name": "x", "kind": "faction", "tag": "t", "tiers": [2], "effect": "magic"}],
			[{"id": "x", "name": "x", "kind": "faction", "tiers": [2], "effect": "spoils"}]]:
		t.ok(not R.validate_bonds(bad).is_empty(), "bad bond set rejected: %s" % [bad])
	t.eq(R.new_battle("skirmish_a", {"bonds": [{"id": "x"}]}).get("error"), "bad_bonds", "new_battle rejects a bad bond set")
	t.eq(R.new_battle("skirmish_a", {"bond_set": "nope"}).get("error"), "bad_bonds", "new_battle rejects an unknown bond set")
	var lane4 := ["^^^^^^^^", "E======G", "^^^^^^^^", "^^^^^^^^"]
	var route4 := {"r": ["H2", "G2", "F2", "E2", "D2", "C2", "B2", "A2"]}
	var one := _tpl(lane4, route4, [{"turn": 1, "route": "r", "units": ["whitecoat"]}, {"turn": 5, "route": "r", "units": ["whitecoat"]}])
	t.ok(not _battle(one).has("bond_defs"), "builtin bonds are not copied into the state")
	var ocean := {"bond_set": "ocean", "cards": ["requisition", "requisition", "requisition", "requisition", "fallback", "feint"]}
	# 帝国旧部（效果同意大利军团）：名单里 2 人开场军令点 +2；ocean 套里 italy 标签什么都不点亮
	var imp_extra := ocean.duplicate(true)
	imp_extra["protagonist"] = {"enabled": true, "tags": ["imperial"]}
	t.eq(int(_battle(one, [_u("a", "line", {"tags": ["imperial"]})], [], true, imp_extra)["cp"]), 8, "帝国旧部 2 in the roster: opening CP 8")
	t.eq(int(_battle(one, [_u("a", "line", {"tags": ["italy"]})], [], true, ocean)["cp"]), 6, "ocean set: the italy tag counts for nothing")
	var sv := _battle(one, [], [], false, ocean)
	t.eq(sv["bond_defs"].size(), 8, "state carries the campaign's bond definitions")
	t.eq(R.view(sv)["bonds"].size(), 8, "view lists the campaign's bonds")
	# 远洋同盟（spoils）：2 档法郎 +20%，3 档再 +1 金币
	var rewards: Array = []
	for n in [0, 2, 3]:
		var roster: Array = []
		for i in range(3):
			roster.append(_u("c%d" % i, "jager", {"atk": 10, "tags": ["far_sea"] if i < n else []}))
		var s := _battle(one, roster, [], false, ocean)
		for i in range(3):
			_do(s, "deploy", {"unit": "c%d" % i, "col": 2 + i, "row": 0, "facing": "down"})
		_fights(s, 8)
		t.eq(s["outcome"], "victory", "far_sea %d: jagers win" % n)
		rewards.append(R.result(s)["rewards"])
	t.eq(rewards[1]["franc"], int(rewards[0]["franc"]) * 120 / 100, "远洋同盟 2: francs +20%")
	t.eq([rewards[1]["gold"], rewards[2]["gold"]], [rewards[0]["gold"], int(rewards[0]["gold"]) + 1], "远洋同盟 3: +1 gold")
	# 暗影密使（intel）：2 档手牌补到 4 张；3 档来敌提前 3 回合公开
	var sh := _battle(one, [_u("s1", "jager", {"tags": ["shadow"]}), _u("s2", "jager", {"tags": ["shadow"]}), _u("s3", "jager", {"tags": ["shadow"]})], [], false, ocean)
	t.eq(R.view(sh)["waves"][0]["known"], false, "turn-5 wave unknown at turn 1 (2-turn horizon)")
	_do(sh, "deploy", {"unit": "s1", "col": 0, "row": 0, "facing": "right"})
	_do(sh, "deploy", {"unit": "s2", "col": 1, "row": 0, "facing": "right"})
	t.eq(sh["bonds"]["shadow"]["tier"], 2, "two shadow members")
	_do(sh, "fight")
	t.eq((sh["hand"] as Array).size(), 4, "暗影密使 2: hand of 4")
	_do(sh, "deploy", {"unit": "s3", "col": 2, "row": 0, "facing": "right"})
	t.eq(sh["bonds"]["shadow"]["tier"], 3, "three shadow members")
	var known := false
	for row in R.intents(sh):
		if row.get("type") == "wave" and int(row["turn"]) == 5:
			known = true
	t.ok(known and R.view(sh)["waves"][0]["known"], "暗影密使 3: at turn 2 the turn-5 wave already shows (3-turn horizon)")
	_do(sh, "undo")
	t.eq(R.view(sh)["waves"][0]["known"], false, "back to tier 2: turn 5 is out of the 2-turn horizon again")
	_do(sh, "deploy", {"unit": "s3", "col": 2, "row": 0, "facing": "right"})
	# 博学工坊（workshop）：2 档成员技能每回合多充能 1；3 档获胜勋章 +1
	var ws := _battle(one, [_u("w1", "jager", {"atk": 10, "skill": "mark_target", "tags": ["scholar"]}), _u("w2", "jager", {"atk": 10, "skill": "mark_target", "tags": ["scholar"]}),
		_u("w3", "jager", {"atk": 10, "skill": "mark_target"})], [], false, ocean)
	for i in range(3):
		_do(ws, "deploy", {"unit": "w%d" % (i + 1), "col": 2 + i, "row": 0, "facing": "down"})
	_do(ws, "fight")
	t.eq([ws["units"]["w1"]["charge"], ws["units"]["w3"]["charge"]], [2, 1], "博学工坊 2: members charge twice as fast")
	var medals: Array = []
	for n in [2, 3]:
		var roster2: Array = []
		for i in range(3):
			roster2.append(_u("m%d" % i, "jager", {"atk": 10, "tags": ["scholar"] if i < n else []}))
		var s2 := _battle(one, roster2, [], false, ocean)
		for i in range(3):
			_do(s2, "deploy", {"unit": "m%d" % i, "col": 2 + i, "row": 0, "facing": "down"})
		_fights(s2, 8)
		medals.append(int(R.result(s2)["rewards"]["medal"]))
	t.eq(medals[1], medals[0] + 1, "博学工坊 3: +1 medal")
	# 荒岛求生（效果同随军家眷）：2 档成员 2 格内每回合回 1
	for n in [1, 2]:
		var roster3: Array = [_u("i1", "jager", {"hp": 5, "max_hp": 8, "tags": ["island"]})]
		if n == 2:
			roster3.append(_u("i2", "jager", {"tags": ["island"]}))
		var s3 := _battle(one, roster3, [], false, ocean)
		_do(s3, "deploy", {"unit": "i1", "col": 0, "row": 3, "facing": "right"})
		if n == 2:
			_do(s3, "deploy", {"unit": "i2", "col": 1, "row": 3, "facing": "right"})
		_do(s3, "fight")
		t.eq(int(s3["units"]["i1"]["hp"]), 5 + (1 if n == 2 else 0), "荒岛求生 %d member(s): heal %d" % [n, 1 if n == 2 else 0])
	# 存档往返：战役羁绊跟着状态走
	var rt := R.load_state(JSON.parse_string(JSON.stringify(sh)))
	t.eq(R.view(rt)["bonds"], R.view(sh)["bonds"], "bond definitions survive a JSON round trip")


# ---------------------------------------------------------------- 军心与胜负

func _test_morale_outcomes() -> void:
	var tpl := _tpl(LANE, LANE_ROUTE, [{"turn": 1, "route": "r", "units": ["whitecoat"]}, {"turn": 8, "route": "r", "units": ["whitecoat"]}])
	var s := _battle(tpl, [], [], false, {"morale": 2})
	_fights(s, 6)
	t.eq([s["phase"], s["outcome"]], ["over", "defeat"], "our morale 0: defeat")
	t.eq(int(s["morale"]), 0, "morale clamps at 0")
	_no(s, "retreat", {}, "battle_over", "nothing is legal after the battle")
	t.eq(R.view(s)["hand"].filter(func(h): return h["playable"]).size(), 0, "no playable cards after the battle")
	# 敌军心归零：溃逃，提前结束
	var rout := _tpl(LANE, LANE_ROUTE, [{"turn": 1, "route": "r", "units": ["whitecoat", "whitecoat"]}, {"turn": 6, "route": "r", "units": ["whitecoat"]}], {"enemy_morale": 1})
	var s2 := _battle(rout, [], [_u("j", "jager", {"atk": 10})])
	_do(s2, "deploy", {"unit": "j", "col": 4, "row": 0, "facing": "down"})
	_fights(s2, 3)
	t.eq([s2["outcome"], s2["victory_kind"], s2["turn"]], ["victory", "rout", 3], "enemy morale 0 at turn 3: rout victory")
	# 全歼：所有波次出完并清空
	var clear := _tpl(LANE, LANE_ROUTE, [{"turn": 1, "route": "r", "units": ["whitecoat"]}])
	var s3 := _battle(clear, [], [_u("j", "jager", {"atk": 10})])
	_do(s3, "deploy", {"unit": "j", "col": 4, "row": 0, "facing": "down"})
	_fights(s3, 3)
	t.eq([s3["outcome"], s3["victory_kind"]], ["victory", "cleared"], "all waves spawned and cleared: victory")
	# 坚守：撑满回合上限、军心 > 0
	var hold := _tpl(LANE, LANE_ROUTE, [{"turn": 1, "route": "r", "units": ["whitecoat"]}], {"turn_limit": 3})
	var s4 := _battle(hold, [], [])
	_fights(s4, 3)
	t.eq([s4["outcome"], s4["victory_kind"], s4["turn"]], ["victory", "hold", 3], "turn limit reached with morale > 0: hold victory")
	t.eq(R.result(s4)["stars"], 2, "morale above half the start: ★★")
	# 击杀精英提振军心；纵队长阵亡，该纵队后退、攻 −1
	var lead := _tpl(LANE, LANE_ROUTE, [{"turn": 1, "route": "r", "units": ["leader", "whitecoat"]}, {"turn": 8, "route": "r", "units": ["whitecoat"]}])
	var s5 := _battle(lead, [], [_u("j", "jager", {"atk": 12})])
	_do(s5, "deploy", {"unit": "j", "col": 4, "row": 0, "facing": "down"})
	t.eq(_enemy(s5, 2)["atk"], 3, "whitecoat base attack 3")
	t.eq(R.view(s5)["enemies"][1]["atk"], 4, "column leader aura: +1")
	_fights(s5, 3)
	t.eq(_enemy(s5, 1), {}, "jager prefers the officer")
	t.eq(int(s5["enemy_morale"]), 26, "column leader killed: enemy morale -4")
	t.eq(int(s5["morale"]), 12, "column routed: our morale +2")
	var wc := _enemy(s5, 2)
	t.eq(R.view(s5)["enemies"][0]["atk"], 2, "leaderless column: attack -1")
	var col_before: int = int(wc["col"])
	_fights(s5, 1)
	t.eq(int(_enemy(s5, 2).get("col", -1)), col_before + 1, "leaderless column falls back 1 cell next turn")


# ---------------------------------------------------------------- 军令牌

func _test_cards() -> void:
	var tpl := _tpl(LANE, LANE_ROUTE, [{"turn": 1, "route": "r", "units": ["whitecoat", "whitecoat"]}, {"turn": 8, "route": "r", "units": ["whitecoat"]}])
	# 齐射：该行远程攻 +2
	var s := _battle(tpl, [], [_u("j", "jager")], false, {"cards": ["volley", "volley", "volley"]})
	_do(s, "deploy", {"unit": "j", "col": 4, "row": 0, "facing": "down"})
	_fights(s, 2)
	_do(s, "card", {"index": 0, "row": 0})
	t.eq(int(s["cp"]), 10, "volley costs 2 (6+3+3-2)")
	_fights(s, 1)
	t.eq(int(_enemy(s, 1)["hp"]), 1, "volley: jager 4+2-1 = 5 damage")
	t.eq((s["hand"] as Array).size(), 3, "hand refilled to 3")
	t.eq((s["discard"] as Array).size(), 0, "empty deck reshuffles the discard back in a fixed order")
	# 刺刀冲锋：攻击两次，阻挡 −1
	var s2 := _battle(tpl, [], [_u("g", "grenadier", {"hp": 40, "max_hp": 40})], false, {"cards": ["bayonet", "bayonet", "bayonet"]})
	_do(s2, "deploy", {"unit": "g", "col": 2, "row": 1, "facing": "right"})
	_fights(s2, 2)
	_do(s2, "card", {"index": 0, "unit": "g"})
	t.eq(R.view(s2)["units"][0]["block"], 2, "bayonet card: block 3-1")
	_fights(s2, 1)
	t.eq(int(s2["kills"]), 1, "bayonet card: two blows 2×(4-1) kill a whitecoat")
	# 号手：该行敌人本回合速度 −1，两回合攻 −2
	var s3 := _battle(tpl, [], [_u("l", "line", {"atk": 0, "hp": 40, "max_hp": 40})], false, {"cards": ["bugler", "bugler", "bugler"]})
	_do(s3, "deploy", {"unit": "l", "col": 3, "row": 1, "facing": "right"})
	_fights(s3, 1)
	_do(s3, "card", {"index": 0, "row": 1})
	t.eq(_intent_for(s3, 1).get("move_to"), [5, 1], "bugler: the row stands still this turn (intent recomputed)")
	_fights(s3, 1)
	t.eq(int(_enemy(s3, 1)["col"]), 5, "bugler: speed -1")
	_fights(s3, 1)
	t.eq(int(s3["units"]["l"]["hp"]), 40 - 2, "bugler next turn: attack 3-2 → 1 per blow, 2 blows")
	# 集中炮火：无视装填
	var s4 := _battle(tpl, [], [_u("a", "artillery", {"atk": 3})], false, {"cards": ["barrage", "barrage", "barrage"]})
	_do(s4, "deploy", {"unit": "a", "col": 0, "row": 0, "facing": "right"})
	_fights(s4, 2)
	t.eq(int(s4["units"]["a"]["reload"]), 1, "artillery fired and is reloading")
	_do(s4, "card", {"index": 0, "col": 3, "row": 1})
	var hp_before: int = int(_enemy(s4, 1)["hp"])
	_fights(s4, 1)
	t.ok(_enemy(s4, 1).is_empty() or int(_enemy(s4, 1)["hp"]) < hp_before, "barrage fires while reloading")
	# 后撤：全额返还，没有冷却；征发：+2 军令点
	var s5 := _battle(tpl, [], [_u("l", "line", {"cost": 4})], false, {"cards": ["fallback", "requisition", "fallback"]})
	_do(s5, "deploy", {"unit": "l", "col": 2, "row": 1, "facing": "right"})
	t.eq(int(s5["cp"]), 2, "deploy costs 4")
	t.eq(R.view(s5)["hand"].filter(func(h): return h["id"] == "fallback" and h["playable"]).size(), 0, "后撤 shows unplayable while the only unit was just deployed")
	_no(s5, "card", {"index": _card_index(s5, "fallback"), "unit": "l"}, "just_deployed", "后撤 cannot take back a unit deployed this turn")
	_do(s5, "fight")
	_do(s5, "card", {"index": _card_index(s5, "fallback"), "unit": "l"})
	t.eq([int(s5["cp"]), int(s5["units"]["l"]["cooldown"])], [9, 0], "后撤: full refund, no cooldown (2+3+4)")
	_do(s5, "deploy", {"unit": "l", "col": 2, "row": 1, "facing": "right"})
	_no(s5, "withdraw", {"unit": "l"}, "just_deployed", "redeployed this turn: no withdraw until next turn")
	_do(s5, "fight")
	_do(s5, "withdraw", {"unit": "l"})
	t.eq(int(s5["cp"]), 10, "ordinary withdraw refunds half (5+3+4/2)")
	_do(s5, "card", {"index": _card_index(s5, "requisition")})
	t.eq(int(s5["cp"]), 12, "征发: CP +2")
	_do(s5, "retreat")
	t.eq(R.result(s5)["requisitions"], 1, "征发 recorded for the campaign (unrest)")
	# 皇帝的命令：会战限定，用后消耗
	var s6 := _battle(tpl, [], [], false, {"cards": ["emperor", "emperor", "emperor", "requisition"]})
	t.eq(s6["set_aside"], ["emperor", "emperor", "emperor"], "皇帝的命令 is set aside outside a major battle")
	t.eq((s6["hand"] as Array).map(func(h): return h["id"]), ["requisition"], "set-aside cards never clog the hand")
	t.eq(R.view(s6)["set_aside"], ["emperor", "emperor", "emperor"], "view lists the set-aside cards")
	var big := _tpl(["^^^^^^^^^", "E=======G", "^^^^^^^^^", ".........", "........."], {"r": ["I2", "H2", "G2", "F2", "E2", "D2", "C2", "B2", "A2"]},
		[{"turn": 1, "route": "r", "units": ["whitecoat"]}])
	var s7 := _battle(big, [], [_u("g", "grenadier")], false, {"cards": ["emperor", "volley", "volley"]})
	_do(s7, "deploy", {"unit": "g", "col": 1, "row": 3, "facing": "right"})
	_do(s7, "card", {"index": _card_index(s7, "emperor")})
	t.eq([int(s7["morale"]), int(s7["units"]["g"]["charge"])], [13, 1], "皇帝的命令: morale +3, charge +1")
	t.eq(s7["exhausted"], ["emperor"], "皇帝的命令 is exhausted, not discarded")
	# 方阵：扣一张手牌；阻挡 +1，防 +2；不射击；扣住的牌不能打
	var s8 := _battle(tpl, [], [_u("l", "line")], false, {"cards": ["volley", "requisition", "volley"]})
	_do(s8, "deploy", {"unit": "l", "col": 2, "row": 1, "facing": "right"})
	_do(s8, "formation", {"unit": "l", "square": true, "index": _card_index(s8, "requisition")})
	var lv: Dictionary = R.view(s8)["units"][0]
	t.eq([lv["block"], lv["def"], lv["square"]], [3, 3, true], "square: block 2+1, def 1+2")
	var locked := -1
	for h in R.view(s8)["hand"]:
		if h["locked"]:
			locked = int(h["index"])
	t.ok(locked >= 0, "square locks a hand card")
	_no(s8, "card", {"index": locked}, "card_locked", "a locked card cannot be played")
	_fights(s8, 2)
	t.eq((s8["hand"] as Array).size(), 3, "locked card still takes a hand slot")
	t.eq(int(_enemy(s8, 1)["hp"]), 6, "a line in square does not shoot")
	_do(s8, "formation", {"unit": "l", "square": false})
	t.eq(R.view(s8)["units"][0]["square"], false, "square released for free")
	t.ok(_card_index(s8, "requisition") >= 0, "the locked card comes back to hand")


func _test_hussar_and_artillery() -> void:
	var tpl := _tpl(LANE, LANE_ROUTE, [{"turn": 1, "route": "r", "units": ["hungarian"]}, {"turn": 8, "route": "r", "units": ["whitecoat"]}])
	var s := _battle(tpl, [], [_u("h", "hussar")])
	_fights(s, 2)
	t.eq(int(_enemy(s, 1)["col"]), 4, "hungarian at E2")
	_do(s, "deploy", {"unit": "h", "col": 1, "row": 1, "facing": "right"})
	t.eq([s["units"]["h"]["col"], s["units"]["h"]["row"]], [3, 1], "hussar charges down the road and stops in front (D2)")
	t.eq(int(_enemy(s, 1)["hp"]), 12 - (10 - 2), "charge deals attack ×2 minus defence")
	t.eq(int(_enemy(s, 1)["col"]), 5, "charge knocks the enemy back 1 cell")
	t.eq(bool(s["units"]["h"]["charged"]), true, "the charge is the hussar's attack this turn")
	_do(s, "undo")
	t.eq(int(_enemy(s, 1)["hp"]), 12, "undo reverses the charge")
	# 炮兵：手动瞄准，穿透后一格减半，开火后下回合装填
	var tpl2 := _tpl(LANE, LANE_ROUTE, [{"turn": 1, "route": "r", "units": ["whitecoat"]}, {"turn": 2, "route": "r", "units": ["whitecoat"]}, {"turn": 8, "route": "r", "units": ["whitecoat"]}])
	var s2 := _battle(tpl2, [], [_u("a", "artillery", {"atk": 5})])
	_do(s2, "deploy", {"unit": "a", "col": 0, "row": 0, "facing": "right"})
	_fights(s2, 1)
	_do(s2, "aim", {"unit": "a", "col": 5, "row": 1})
	_fights(s2, 1)
	t.eq([int(_enemy(s2, 1)["hp"]), int(_enemy(s2, 2)["hp"])], [2, 4], "aimed shot F2 5-1=4, pierce G2 half = 2")
	t.eq(int(s2["units"]["a"]["reload"]), 1, "reloading next turn")
	var hp1: int = int(_enemy(s2, 1)["hp"])
	_fights(s2, 1)
	t.eq(int(_enemy(s2, 1)["hp"]), hp1, "no shot while reloading")
	_fights(s2, 1)
	t.ok(_enemy(s2, 1).is_empty(), "fires again the turn after")


func _unit_view(s: Dictionary, uid: String) -> Dictionary:
	for u in R.view(s)["units"]:
		if u["uid"] == uid:
			return u
	return {}


func _test_classes_and_terrain() -> void:
	# 弹药车被摧毁：本格和相邻格的敌人各受 6 伤
	var tpl := _tpl(LANE, LANE_ROUTE, [{"turn": 1, "route": "r", "units": ["wagon", "whitecoat"]}, {"turn": 8, "route": "r", "units": ["whitecoat"]}])
	var s := _battle(tpl, [], [_u("j", "jager", {"atk": 10})])
	_do(s, "deploy", {"unit": "j", "col": 4, "row": 0, "facing": "down"})
	_fights(s, 3)
	t.eq(int(s["kills"]), 2, "jager blows up the ammo wagon, the blast kills the whitecoat")
	t.ok(_has_log(s, "弹药车爆炸"), "wagon explosion logged")
	# 掷弹兵技能“刺刀冲锋”：挡住的敌人全部击退 1 格，各受 5 伤
	var tpl2 := _tpl(LANE, LANE_ROUTE, [{"turn": 1, "route": "r", "units": ["whitecoat", "whitecoat"]}, {"turn": 8, "route": "r", "units": ["whitecoat"]}])
	var s2 := _battle(tpl2, [], [_u("g", "grenadier", {"atk": 0, "hp": 60, "max_hp": 60})])
	_do(s2, "deploy", {"unit": "g", "col": 2, "row": 1, "facing": "right"})
	_no(s2, "skill", {"unit": "g"}, "not_ready", "bayonet charge needs 3 charge")
	_fights(s2, 3)
	_do(s2, "skill", {"unit": "g"})
	for e in s2["enemies"]:
		t.eq([int(e["hp"]), int(e["col"]), e["blocked_by"]], [1, 4, ""], "bayonet charge: 5 damage, knocked back to E2, released")
	t.eq(int(s2["units"]["g"]["charge"]), 0, "skill spends its charge")
	# 工兵“筑垒”：相邻放拒马，或把相邻平地筑成胸墙（高地）
	var field := ["^^^^^^^", "E=====G", "......."]
	var tpl3 := _tpl(field, LANE_ROUTE, [{"turn": 8, "route": "r", "units": ["whitecoat"]}])
	var s3 := _battle(tpl3, [], [_u("e", "engineer"), _u("j", "jager"), _u("l", "line", {"hp": 5, "max_hp": 14}), _u("d", "drummer"), _u("m", "medic")])
	_do(s3, "deploy", {"unit": "e", "col": 1, "row": 1, "facing": "right"})
	_fights(s3, 2)
	_do(s3, "skill", {"unit": "e", "col": 2, "row": 1})
	var bar: Dictionary = _unit_view(s3, "barricade_1")
	t.eq([bar.get("cls"), bar.get("block"), bar.get("hp")], ["barricade", 2, 8], "barricade: block 2, hp 8")
	_no(s3, "deploy", {"unit": "j", "col": 1, "row": 2, "facing": "right"}, "terrain", "a jager cannot stand on plain")
	s3["units"]["e"]["charge"] = 2
	_no(s3, "skill", {"unit": "e", "col": 1, "row": 1, "mode": "earthwork"}, "bad_cell", "fortify needs an adjacent cell")
	_do(s3, "skill", {"unit": "e", "col": 1, "row": 2, "mode": "earthwork"})
	t.eq(s3["terrain"][2 * 7 + 1], "earthwork", "earthwork turns plain into high ground")
	_do(s3, "deploy", {"unit": "j", "col": 1, "row": 2, "facing": "right"})
	# 鼓手：相邻友军攻 +1；军医：2 格内兵力最低的友军回 3
	_do(s3, "deploy", {"unit": "l", "col": 3, "row": 1, "facing": "right"})
	_do(s3, "deploy", {"unit": "d", "col": 3, "row": 2, "facing": "right"})
	_do(s3, "deploy", {"unit": "m", "col": 4, "row": 2, "facing": "right"})
	t.eq(_unit_view(s3, "l").get("atk"), 5, "drummer adjacent: line attack 4+1")
	_fights(s3, 1)
	t.eq(int(s3["units"]["l"]["hp"]), 8, "medic heals the weakest ally within 2 by 3")
	# 村庄防 +2；树林里挨远程按防 +2 算
	var tpl4 := _tpl(["^^^^^^^", "E==v==G", "^^^^^^^"], LANE_ROUTE, [{"turn": 8, "route": "r", "units": ["whitecoat"]}])
	var s4 := _battle(tpl4, [], [_u("l", "line")])
	_do(s4, "deploy", {"unit": "l", "col": 3, "row": 1, "facing": "right"})
	t.eq(_unit_view(s4, "l").get("def"), 3, "village: def 1+2")
	var tpl5 := _tpl(["^^^^^^^", "E==w==G", "^^^^^^^"], LANE_ROUTE, [{"turn": 1, "route": "r", "units": ["grenz", "whitecoat"]}, {"turn": 8, "route": "r", "units": ["whitecoat"]}])
	var s5 := _battle(tpl5, [], [_u("l", "line", {"atk": 0, "hp": 40, "max_hp": 40})])
	_do(s5, "deploy", {"unit": "l", "col": 3, "row": 1, "facing": "right"})
	_fights(s5, 1)
	t.eq(_intent_for(s5, 1).get("attack", {}).get("dmg"), 1, "woods: ranged 3-(1+2) → minimum 1")
	t.eq(_intent_for(s5, 2).get("attack", {}).get("dmg"), 2, "woods does not soften melee: 3-1=2")
	# 骠骑兵撤下后只冷却 1 回合
	var s6 := _battle(tpl3, [], [_u("h", "hussar")])
	_do(s6, "deploy", {"unit": "h", "col": 1, "row": 1, "facing": "right"})
	_fights(s6, 1)
	_do(s6, "withdraw", {"unit": "h"})
	t.eq(int(s6["units"]["h"]["cooldown"]), 1, "hussar redeploy cooldown 1")
	_no(s6, "deploy", {"unit": "h", "col": 1, "row": 1, "facing": "right"}, "cooldown", "cannot redeploy during cooldown")
	_fights(s6, 1)
	_do(s6, "deploy", {"unit": "h", "col": 1, "row": 1, "facing": "right"})


func _test_template_variation() -> void:
	var comps := {}
	var decks := {}
	for seed_value in range(1, 21):
		var a: Dictionary = R.new_battle("rivoli", {"seed": seed_value})
		var b: Dictionary = R.new_battle("rivoli", {"seed": seed_value})
		t.eq(a["waves"], b["waves"], "seed %d: same waves for the same seed" % seed_value)
		t.eq(a["deck"], b["deck"], "seed %d: same deck order for the same seed" % seed_value)
		var kinds: Array = []
		for spec in a["waves"][2]["units"]:
			kinds.append(spec["kind"])
		comps[str(kinds)] = true
		decks[str(a["deck"])] = true
	t.eq(comps.size(), 2, "rivoli wave 2 varies between its two compositions by seed")
	t.ok(decks.size() >= 5, "command deck order varies by seed")


# ---------------------------------------------------------------- 不卡死

func _random_cmd(s: Dictionary, x: int) -> Array:
	var order: Array = s["order"]
	var uid: String = order[x % order.size()]
	var c: int = (x >> 5) % int(s["cols"])
	var r: int = (x >> 9) % int(s["rows"])
	var facing: String = ["right", "left", "up", "down"][(x >> 12) % 4]
	match (x >> 15) % 14:
		0, 1, 2:
			return ["deploy", {"unit": uid, "col": c, "row": r, "facing": facing}]
		3:
			return ["withdraw", {"unit": uid}]
		4:
			return ["skill", {"unit": uid, "col": c, "row": r, "mode": "earthwork" if (x & 1) == 1 else "barricade"}]
		5:
			return ["card", {"index": (x >> 18) % 4, "unit": uid, "col": c, "row": r}]
		6:
			return ["aim", {"unit": uid, "col": c, "row": r}]
		7:
			return ["formation", {"unit": uid, "square": (x & 2) == 2}]
		8:
			return ["carry", {"unit": uid}]
		9:
			return ["undo", {}]
		10:
			return ["redraw", {"index": (x >> 18) % 4}]
		11:
			var garbage := [["deploy", {"unit": uid, "col": [c], "row": r}], ["card", {"index": str(x % 3)}], ["formation", {"unit": uid, "square": "yes"}],
				["aim", {"unit": uid, "col": c, "row": null}], ["skill", {"unit": x % 7, "col": c, "row": r}]]
			return garbage[(x >> 20) % garbage.size()]
	return ["fight", {}]


func _test_never_stuck() -> void:
	var lib: Dictionary = R.load_templates()
	var started := Time.get_ticks_msec()
	for tid in lib["templates"].keys():
		var bad: Array = []
		var outcomes := {}
		for k in range(100):
			var setup := {"seed": 1000 + k * 7919, "act": 1 + k % 6, "cp_bonus": k % 5, "protagonist": {"enabled": k % 3 != 0},
				"roster": [
					{"id": "milon", "cls": "line", "name": "米隆", "hp": 16, "atk": 5, "cost": 5, "skill": "raise_flag", "tags": ["italy"], "fated": k % 4 == 0},
					{"id": "corso", "cls": "jager", "name": "科尔索", "cost": 3, "skill": "mark_target", "tags": ["italy", "quartermaster"], "scarred": k % 5 == 0},
					{"id": "baptiste", "cls": "engineer", "name": "巴蒂斯特", "cost": 3, "skill": "fortify", "tags": ["italy", "quartermaster"]},
					{"id": "marie", "cls": "medic", "name": "玛丽", "cost": 3, "tags": ["quartermaster", "family"]}],
				"troops": [{"id": "bat", "cls": "artillery"}, {"id": "gren", "cls": "grenadier"}, {"id": "gren2", "cls": "grenadier"},
					{"id": "hus", "cls": "hussar"}, {"id": "drum", "cls": "drummer"}, {"id": "line", "cls": "line"}],
				"bonds_trust": {"hero|milon": k % 4}}
			var s: Dictionary = R.new_battle(tid, setup)
			var x: int = (k + 1) * 2654435761 & 0xFFFFFFFF
			var fights := 0
			var cmds := 0
			var since_fight := 0
			while s["phase"] == "command" and cmds < 600:
				x = _xs(x ^ (cmds * 40503))
				var pick: Array = _random_cmd(s, x)
				if since_fight >= 10:
					pick = ["fight", {}]
				if (x >> 22) % 300 == 0:
					pick = ["retreat", {}]
				var check := cmds % 97 == 0
				var before := JSON.stringify(s, "", true) if check else ""
				var res: Dictionary = R.apply(s, pick[0], pick[1])
				cmds += 1
				if typeof(res.get("ok")) != TYPE_BOOL or typeof(res.get("err")) != TYPE_STRING:
					bad.append("bad result shape %s" % res)
				if check and not bool(res["ok"]) and JSON.stringify(s, "", true) != before:
					bad.append("rejected %s changed state" % pick[0])
				if (x >> 15) % 14 == 11 and pick[0] != "fight" and pick[0] != "retreat" and res.get("err") != "bad_args" and s["phase"] == "command":
					bad.append("garbage %s %s → %s" % [pick[0], pick[1], res])
				if pick[0] == "fight":
					fights += 1
					since_fight = 0
					if not _no_enemy_on_units(s):
						bad.append("seed %d turn %d: an enemy stopped on our unit's cell" % [k, s["turn"]])
				else:
					since_fight += 1
			outcomes[s["outcome"]] = int(outcomes.get(s["outcome"], 0)) + 1
			if s["phase"] != "over":
				bad.append("seed %d did not finish" % k)
			if fights > int(s["turn_limit"]):
				bad.append("seed %d needed %d fights > %d turns" % [k, fights, s["turn_limit"]])
			var res2: Dictionary = R.result(s)
			if not res2["outcome"] in ["victory", "defeat", "retreat"]:
				bad.append("seed %d result outcome %s" % [k, res2["outcome"]])
			if k % 20 == 0 and not t.find_floats(s).is_empty():
				bad.append("seed %d floats %s" % [k, t.find_floats(s)])
		t.ok(bad.is_empty(), "never stuck on %s: 100 seeded random command sequences all end (%s): %s" % [tid, outcomes, bad.slice(0, 5)])
	print("OCEAN battle_v2 fuzz ms: %d" % (Time.get_ticks_msec() - started))


func _test_no_floats() -> void:
	var s := _arcole(21)
	t.eq(t.find_floats(s), PackedStringArray(), "new battle state has no floats")
	_do(s, "deploy", {"unit": "hero", "col": 1, "row": 1, "facing": "right"})
	_do(s, "deploy", {"unit": "milon", "col": 3, "row": 1, "facing": "right"})
	_do(s, "deploy", {"unit": "battery", "col": 1, "row": 0, "facing": "right"})
	for i in range(8):
		if s["phase"] != "command":
			break
		t.eq(t.find_floats(R.view(s)), PackedStringArray(), "turn %d view has no floats" % i)
		t.eq(t.find_floats(R.preview(s)), PackedStringArray(), "turn %d preview has no floats" % i)
		t.eq(t.find_floats(R.intents(s)), PackedStringArray(), "turn %d intents have no floats" % i)
		_do(s, "fight")
		t.eq(t.find_floats(s), PackedStringArray(), "turn %d state has no floats" % i)
	t.eq(t.find_floats(R.result(s)), PackedStringArray(), "result has no floats")
	# JSON 往返（存档）不会混进浮点：读回来再转整数后结算一样
	var lines: Array = R.view(s)["log"]
	t.ok(not lines.is_empty() and str(lines[-1]).find("战斗结束") >= 0, "Chinese log ends with the outcome")


# ---------------------------------------------------------------- 复审修正（2026-11-01）

const LANE8 := ["^^^^^^^^", "E======G", "^^^^^^^^", "^^^^^^^^"]
const LANE8_ROUTE := {"r": ["H2", "G2", "F2", "E2", "D2", "C2", "B2", "A2"]}


func _wall(id: String, cls: String = "drummer") -> Dictionary:
	return _u(id, cls, {"atk": 0, "hp": 99, "max_hp": 99})


func _no_enemy_on_units(s: Dictionary) -> bool:
	for e in s["enemies"]:
		if R._unit_at(s, int(e["col"]), int(e["row"]), false) != null:
			return false
	return true


## 复审 2：前排满员时，紧挨在后面、还有阻挡位的单位要挡住敌人（纵深阻挡），不会被一路顺延跳过去
func _test_depth_blocking() -> void:
	var five := ["whitecoat", "whitecoat", "whitecoat", "whitecoat", "whitecoat"]
	var tpl := _tpl(LANE8, LANE8_ROUTE, [{"turn": 1, "route": "r", "units": five}])
	var s := _battle(tpl, [], [_wall("a"), _wall("b"), _wall("c")])
	_do(s, "deploy", {"unit": "a", "col": 5, "row": 1, "facing": "right"})
	_do(s, "deploy", {"unit": "b", "col": 4, "row": 1, "facing": "right"})
	_do(s, "deploy", {"unit": "c", "col": 3, "row": 1, "facing": "right"})
	t.eq(_intent_for(s, 2).get("blocked_by"), "b", "intent: the second whitecoat will be held by b behind the full a")
	_fights(s, 1)
	t.eq([_enemy(s, 1)["blocked_by"], _enemy(s, 2)["blocked_by"], _enemy(s, 3)["blocked_by"]], ["a", "b", "c"],
		"a (F2) full: b (E2) and c (D2) each block one more instead of being skipped")
	for uid in [1, 2, 3]:
		t.eq([_enemy(s, uid)["col"], _enemy(s, uid)["row"]], [6, 1], "depth-blocked whitecoat #%d waits at G2 in front of the line" % uid)
	t.eq(_enemy(s, 4)["blocked_by"], "", "the fourth finds the whole line full")
	t.eq(int(s["units"]["c"]["hp"]), 99 - 3, "c fights the whitecoat it holds from behind a and b (3-0=3)")
	t.eq(_intent_for(s, 4).get("move_to"), [2, 1], "intent: a full line is passed as a whole: G2 → C2, first empty cell behind it")
	_fights(s, 1)
	t.eq([_enemy(s, 4)["col"], _enemy(s, 4)["row"]], [2, 1], "leaker landed on C2, behind the full line")
	t.ok(_no_enemy_on_units(s), "no enemy ever stops on our unit's cell")
	# 撤掉前排：被后排纵深挡住的敌人往前一格，改成正面被挡；后排的阻挡数不会被超用
	_do(s, "withdraw", {"unit": "a"})
	_fights(s, 1)
	t.eq(_blocked_count(s, "b") <= 1 and _blocked_count(s, "c") <= 1, true, "after a leaves, b and c still hold at most their block 1")
	t.ok(_no_enemy_on_units(s), "still nobody on our cells after the front withdrew")
	# 前排战列（阻挡 2）满员，后面紧挨的掷弹兵（阻挡 3）接住第 3、4、5 个
	var s2 := _battle(tpl, [], [_wall("l", "line"), _wall("g", "grenadier")])
	_do(s2, "deploy", {"unit": "l", "col": 3, "row": 1, "facing": "right"})
	_do(s2, "deploy", {"unit": "g", "col": 2, "row": 1, "facing": "right"})
	_fights(s2, 3)
	t.eq([_blocked_count(s2, "l"), _blocked_count(s2, "g")], [2, 3], "line holds 2, the grenadier right behind it holds the other 3")
	_fights(s2, 4)
	t.eq(int(s2["leaks"]), 0, "defence in depth without a gap: nothing leaks")
	# 匈牙利掷弹兵（重型）也会被后排有 2 个空位的单位接住
	var tpl3 := _tpl(LANE8, LANE8_ROUTE, [{"turn": 1, "route": "r", "units": ["whitecoat", "whitecoat", "hungarian"]}])
	var s3 := _battle(tpl3, [], [_wall("l", "line"), _wall("g", "grenadier")])
	_do(s3, "deploy", {"unit": "l", "col": 3, "row": 1, "facing": "right"})
	_do(s3, "deploy", {"unit": "g", "col": 2, "row": 1, "facing": "right"})
	_fights(s3, 3)
	t.eq(_enemy(s3, 3)["blocked_by"], "g", "heavy enemy behind a full line is held by the grenadier's 2 free slots")


func _blocked_count(s: Dictionary, uid: String) -> int:
	var n := 0
	for e in s["enemies"]:
		if e["blocked_by"] == uid:
			n += 1
	return n


## 复审 3：骠骑兵不能“部署冲锋 → 同回合撤下”白打一次
func _test_hussar_no_free_loop() -> void:
	var tpl := _tpl(LANE, LANE_ROUTE, [{"turn": 1, "route": "r", "units": ["whitecoat", "whitecoat"]}, {"turn": 8, "route": "r", "units": ["whitecoat"]}])
	var s := _battle(tpl, [], [_u("h", "hussar")], false, {"cards": ["fallback", "fallback", "fallback"], "act": 6})
	_fights(s, 1)
	_do(s, "deploy", {"unit": "h", "col": 2, "row": 1, "facing": "right"})
	t.eq(bool(s["units"]["h"]["charged"]), true, "hussar charged on deploy")
	_no(s, "withdraw", {"unit": "h"}, "just_deployed", "a hussar that just charged cannot be withdrawn this turn")
	_no(s, "card", {"index": 0, "unit": "h"}, "just_deployed", "nor pulled out with 后撤")
	_do(s, "undo")
	t.eq(s["units"]["h"]["status"], "bar", "a misplaced deployment is still taken back with undo")
	_do(s, "deploy", {"unit": "h", "col": 2, "row": 1, "facing": "right"})
	var hp: int = int(s["units"]["h"]["hp"])
	_fights(s, 1)
	t.ok(int(s["units"]["h"]["hp"]) < hp, "the hussar stands through the enemy phase and takes the blow")
	_do(s, "withdraw", {"unit": "h"})
	t.eq(int(s["units"]["h"]["cooldown"]), 1, "next turn it can withdraw (cooldown 1)")


## 复审 4：集中炮火只能打炮兵射程图样里的格子，只调动够得着的炮
func _test_barrage_range() -> void:
	var tpl := _tpl(LANE, LANE_ROUTE, [{"turn": 1, "route": "r", "units": ["whitecoat", "whitecoat", "whitecoat"]}, {"turn": 8, "route": "r", "units": ["whitecoat"]}])
	var s := _battle(tpl, [], [_u("a1", "artillery", {"atk": 1}), _u("a2", "artillery", {"atk": 1})], false, {"cards": ["barrage", "barrage", "barrage"]})
	_do(s, "deploy", {"unit": "a1", "col": 0, "row": 0, "facing": "right"})
	_do(s, "deploy", {"unit": "a2", "col": 0, "row": 2, "facing": "right"})
	_no(s, "card", {"index": 0, "col": 6, "row": 1}, "out_of_range", "barrage outside every pattern (G2 is 6 columns ahead)")
	_no(s, "card", {"index": 0, "col": 0, "row": 1}, "out_of_range", "barrage behind the guns")
	_fights(s, 2)
	var mark: int = (s["log"] as Array).size()
	_do(s, "card", {"index": 0, "col": 3, "row": 0})
	t.ok(_log_index(s, "够得着 D1 的 1 门炮", mark) >= 0, "only a1 reaches D1")
	_fights(s, 1)
	t.ok(_log_index(s, "a1炮击 D1", mark) >= 0, "a1 fires at the barrage cell D1")
	t.eq(_log_index(s, "a2炮击 D1", mark), -1, "a2 cannot reach D1: it is not dragged into the barrage")
	t.ok(_log_index(s, "a2炮击 E2", mark) >= 0, "a2 fires at its own target instead")
	# 单炮：射程内的集中炮火照样无视装填（_test_cards 也测过），射程外的格子打不了
	var s0 := _battle(tpl, [], [_u("a", "artillery", {"atk": 1})], false, {"cards": ["barrage", "barrage", "barrage"]})
	_do(s0, "deploy", {"unit": "a", "col": 0, "row": 0, "facing": "right"})
	_fights(s0, 2)
	t.eq(int(s0["units"]["a"]["reload"]), 1, "single gun fired at F2 and is reloading")
	var mark0: int = (s0["log"] as Array).size()
	_do(s0, "card", {"index": 0, "col": 4, "row": 1})
	_fights(s0, 1)
	t.ok(_log_index(s0, "a炮击 E2", mark0) >= 0, "barrage inside the pattern ignores the reload")
	var s1 := _battle(tpl, [], [_u("a", "artillery")], false, {"cards": ["barrage", "barrage", "barrage"]})
	_do(s1, "deploy", {"unit": "a", "col": 6, "row": 0, "facing": "right"})
	_no(s1, "card", {"index": 0, "col": 0, "row": 1}, "out_of_range", "a gun facing off the map cannot barrage A2 behind it")


## 复审 5：存档 = JSON 往返；读回来（或直接传回）结果一模一样，状态里也不留浮点
func _test_save_roundtrip() -> void:
	var s := _arcole(9, {"cards": ["volley", "barrage", "feint"]})
	_do(s, "deploy", {"unit": "battery", "col": 1, "row": 0, "facing": "right"})
	_do(s, "deploy", {"unit": "milon", "col": 3, "row": 1, "facing": "right"})
	_do(s, "fight")
	var cross := {}
	for r in R.intents(s):
		if r.get("type") == "crosshair":
			cross = r
	t.eq(cross.get("cell"), [3, 1], "turn 2: the gun's crosshair is on Milon at D2")
	_do(s, "card", {"index": _card_index(s, "volley"), "row": 0})
	_do(s, "card", {"index": _card_index(s, "barrage"), "col": 6, "row": 1})
	_do(s, "card", {"index": _card_index(s, "feint"), "col": 3, "row": 2})
	_do(s, "aim", {"unit": "battery", "col": 6, "row": 1})
	var saved := JSON.stringify(s)
	var raw: Dictionary = JSON.parse_string(saved)
	t.ok(not t.find_floats(raw).is_empty(), "a JSON round-trip really turns ints into floats")
	var loaded: Dictionary = R.load_state(JSON.parse_string(saved))
	t.eq(t.find_floats(loaded), PackedStringArray(), "load_state: no floats left")
	t.eq(R.load_state([1, 2]).get("error"), "bad_save", "load_state rejects garbage")
	t.eq(R.view(raw), R.view(s), "view of the raw round-tripped save matches")
	t.eq(R.preview(raw), R.preview(s), "preview of the raw round-tripped save matches (volley +2 kept)")
	t.eq(R.intents(loaded), R.intents(s), "intents after load_state match")
	var runs := [s, raw, loaded]
	for st in runs:
		_fights(st, 10)
	t.eq(R.result(raw), R.result(s), "raw round-trip: same result")
	t.eq(R.result(loaded), R.result(s), "load_state: same result")
	t.eq(raw["log"], s["log"], "raw round-trip: identical battle log")
	t.eq(t.find_floats(raw), PackedStringArray(), "apply normalised the raw save: no floats in the state")


## 复审 6：整场打不出的牌开场就放到一边；每回合可以免费换一张牌
func _test_dead_cards_and_redraw() -> void:
	var a: Dictionary = _arcole(5)
	t.ok("emperor" in a["set_aside"], "皇帝的命令 is set aside in an elite battle")
	var in_play: Array = (a["deck"] as Array).duplicate()
	for h in a["hand"]:
		in_play.append(h["id"])
	t.ok(not "emperor" in in_play, "it is not in the deck or the hand")
	var r: Dictionary = R.new_battle("rivoli", {"seed": 5})
	t.ok(not "emperor" in r["set_aside"], "a major battle keeps 皇帝的命令")
	var tpl := _tpl(LANE, LANE_ROUTE, [{"turn": 1, "route": "r", "units": ["whitecoat"]}, {"turn": 8, "route": "r", "units": ["whitecoat"]}])
	var s := _battle(tpl, [], [_u("l", "line")], false, {"cards": ["volley", "requisition", "bugler", "barrage", "feint", "bayonet"]})
	t.eq(s["set_aside"], ["barrage"], "no artillery in the roster: 集中炮火 set aside")
	var s2 := _battle(tpl, [], [_u("m", "medic")], false, {"cards": ["volley", "bayonet", "requisition"]})
	t.eq(s2["set_aside"], ["volley", "bayonet"], "no ranged and no melee unit: 齐射 and 刺刀冲锋 set aside")
	var hand_before: Array = (s["hand"] as Array).map(func(h): return h["id"])
	var deck_top: String = s["deck"][0]
	t.eq(R.view(s)["can_redraw"], true, "view: redraw available")
	var before := JSON.stringify(s, "", true)
	_do(s, "redraw", {"index": 0})
	var hand_after: Array = (s["hand"] as Array).map(func(h): return h["id"])
	t.eq(hand_after, hand_before.slice(1) + [deck_top], "redraw: the card goes to the discard pile, the top of the deck comes in")
	t.eq(s["discard"], [hand_before[0]], "redrawn card discarded")
	_no(s, "redraw", {"index": 0}, "redraw_used", "one redraw per turn")
	t.eq(R.view(s)["can_redraw"], false, "view: redraw used up")
	_do(s, "undo")
	t.ok(JSON.stringify(s, "", true) == before, "redraw is undoable like any command")
	_do(s, "redraw", {"index": 1})
	_fights(s, 1)
	t.eq(R.view(s)["can_redraw"], true, "a new turn, a new redraw")


func _all_tags(spec: Dictionary) -> Array:
	return (R.ENEMIES[spec["kind"]]["tags"] as Array) + (spec["tags"] as Array)


## 复审 6（主角）：会战按幕带猎官（0/1/1/2/2/3），而且后排高地也躲不掉
func _test_hunters_by_act() -> void:
	var want := [0, 1, 1, 2, 2, 3]
	for tid in ["rivoli", "major_a"]:
		for act in range(1, 7):
			var s: Dictionary = R.new_battle(tid, {"seed": 4, "act": act})
			var n := 0
			for w in s["waves"]:
				for spec in w["units"]:
					if "hunter" in _all_tags(spec):
						n += 1
			t.eq(n, want[act - 1], "%s act %d: %d hunters (design doc table)" % [tid, act, want[act - 1]])
	for tid in ["skirmish_a", "skirmish_b", "skirmish_c", "elite_a", "arcole"]:
		var s2: Dictionary = R.new_battle(tid, {"seed": 4, "act": 2})
		var n2 := 0
		for w in s2["waves"]:
			for spec in w["units"]:
				if "hunter" in _all_tags(spec):
					n2 += 1
		t.ok(n2 >= 1, "%s act 2 has at least one hunter" % tid)


## 复审 7：号手只重算它那一行的远程目标，不会把别的行刚佯动过的目标改回去
func _test_bugler_keeps_feint() -> void:
	var map := ["E=====G", "^^^^^^^", "E=====G"]
	var routes := {"n": ["G1", "F1", "E1", "D1", "C1", "B1", "A1"], "s": ["G3", "F3", "E3", "D3", "C3", "B3", "A3"]}
	var tpl := _tpl(map, routes, [{"turn": 1, "route": "n", "units": ["grenz"]}, {"turn": 1, "route": "s", "units": ["whitecoat"]}, {"turn": 8, "route": "n", "units": ["whitecoat"]}])
	var s := _battle(tpl, [], [_u("j", "jager", {"atk": 0, "hp": 30, "max_hp": 30})], false, {"cards": ["feint", "bugler", "requisition"]})
	_do(s, "deploy", {"unit": "j", "col": 4, "row": 1, "facing": "left"})
	_fights(s, 1)
	t.eq(_enemy(s, 1)["lock_target"], "j", "grenz locks the jager")
	_do(s, "card", {"index": _card_index(s, "feint"), "col": 5, "row": 1})
	t.eq(_enemy(s, 1)["lock_target"], "", "feint moved the shot onto an empty cell")
	_do(s, "card", {"index": _card_index(s, "bugler"), "row": 2})
	t.eq(_enemy(s, 1)["lock_target"], "", "bugler on row 3 leaves the feinted grenz on row 1 alone")
	_fights(s, 1)
	t.eq(int(s["units"]["j"]["hp"]), 30, "the feinted shot missed")


## 复审 8：参数类型不对一律 bad_args，不报脚本错误、不改状态
func _test_bad_args() -> void:
	var tpl := _tpl(LANE, LANE_ROUTE, [{"turn": 1, "route": "r", "units": ["whitecoat"]}, {"turn": 8, "route": "r", "units": ["whitecoat"]}])
	var s := _battle(tpl, [], [_u("l", "line")], false, {"cards": ["requisition", "requisition", "requisition"]})
	_do(s, "deploy", {"unit": "l", "col": 2, "row": 1, "facing": "right"})
	var cases := [
		["deploy", {"unit": "l", "col": [1], "row": 1, "facing": "right"}],
		["deploy", {"unit": 5, "col": 1, "row": 1}],
		["deploy", {"unit": "l", "col": 1, "row": 1, "facing": 3}],
		["card", {"index": null}],
		["card", {"index": [0]}],
		["card", {"index": "abc"}],
		["formation", {"unit": "l", "square": "yes"}],
		["aim", {"unit": "l", "col": "x", "row": 0}],
		["skill", {"unit": "l", "mode": 1}],
		["redraw", {"index": {}}],
	]
	for c in cases:
		_no(s, c[0], c[1], "bad_args", "%s %s" % [c[0], c[1]])
	_do(s, "card", {"index": 0.0})


## 复审 9：每个人的铜钱是独立的：主角多一枚少一枚、谁先倒下，都不改别人的正反
func _test_fate_independence() -> void:
	var same := 0
	var n := 0
	for seed_value in range(1, 41):
		var s := _fall_battle(seed_value, {"fated": true}, [])
		_fights(s, 5)
		var base: Dictionary = R.result(s)
		for variant in [[3, false], [3, true], [1, true]]:
			var s2: Dictionary = s.duplicate(true)
			s2["hero"]["fell_turn"] = variant[0]
			s2["hero"]["guard"] = variant[1]
			var r2: Dictionary = R.result(s2)
			n += 1
			if r2["fallen"][1]["coin_faces"] == base["fallen"][0]["coin_faces"]:
				same += 1
	t.eq(same, n, "the protagonist's own roll never changes a companion's coins (%d/%d)" % [same, n])
	var longer := 0
	for seed_value in range(1, 21):
		var a := _fall_battle(seed_value, {"fated": true}, [])
		_fights(a, 5)
		var b := _fall_battle(seed_value, {"fated": true}, [_u("helper", "jager", {"atk": 0, "at": [2, 0]})])
		_do(b, "carry", {"unit": "milon"})
		_fights(b, 5)
		var fa: Array = R.result(a)["fallen"][0]["coin_faces"]
		var fb: Array = R.result(b)["fallen"][0]["coin_faces"]
		if fb.size() == fa.size() + 1 and fb.slice(0, fa.size()) == fa:
			longer += 1
	t.eq(longer, 20, "an extra coin is added on top: the earlier faces stay the same")


## 复审 10：阿尔科莱的奥军炮第 2 回合定准星、第 3 回合开第一炮（设计稿实例），之后每 2 回合一炮
func _test_gun_first_fire() -> void:
	var s := _arcole(3)
	_do(s, "deploy", {"unit": "milon", "col": 3, "row": 1, "facing": "right"})
	var cross_t1 := 0
	for r in R.intents(s):
		if r.get("type") == "crosshair":
			cross_t1 += 1
	t.eq(cross_t1, 0, "turn 1: no crosshair yet")
	_do(s, "fight")
	var gun := {}
	for e in s["enemies"]:
		if e["kind"] == "gun":
			gun = e
	t.eq([gun.get("aim"), gun.get("fire_turn")], [[3, 1], 3], "turn 2: crosshair on D2, first shot on turn 3")
	_do(s, "fight")
	t.eq(_intent_for(s, int(gun["uid"])).get("attack", {}).get("kind"), "gun", "turn 3: the gun fires this turn")
	t.eq(_intent_for(s, int(gun["uid"])).get("attack", {}).get("dmg"), 5, "6 - 1 = 5, as in the design doc")
	_do(s, "fight")
	var g4 := _enemy(s, int(gun["uid"]))
	t.eq(g4.get("fire_turn"), 5, "turn 4: next shot on turn 5")
	# 模板可以把第一炮往后推：first_fire 4 → 第 3 回合才亮准星
	var tpl := _tpl(LANE, LANE_ROUTE, [{"turn": 1, "at": "G1", "units": ["gun"], "first_fire": 4}, {"turn": 8, "route": "r", "units": ["whitecoat"]}])
	var s2 := _battle(tpl, [], [_u("l", "line", {"hp": 40, "max_hp": 40})])
	_do(s2, "deploy", {"unit": "l", "col": 2, "row": 1, "facing": "right"})
	_fights(s2, 1)
	t.eq(_enemy(s2, 1)["aim"], [], "first_fire 4: no crosshair on turn 2")
	_fights(s2, 1)
	t.eq([_enemy(s2, 1)["aim"], _enemy(s2, 1)["fire_turn"]], [[2, 1], 4], "turn 3: crosshair on the line, fires on turn 4")
	_fights(s2, 2)
	t.eq(int(s2["units"]["l"]["hp"]), 40 - 5, "turn 4: first shot lands (6-1=5)")


## 复审 11：波次条和敌情里的来敌带上兵种自带的标签（龙骑兵的猎官）
func _test_wave_tags() -> void:
	var s := _arcole(3)
	_fights(s, 2)
	var found := false
	for r in R.intents(s):
		if r.get("type") == "wave":
			for u in r["units"]:
				if u["kind"] == "dragoon":
					found = "hunter" in u["tags"]
	t.ok(found, "turn 3: the coming dragoon shows its hunter tag")
	var vfound := false
	for w in R.view(s)["waves"]:
		for d in w["detail"]:
			if d["kind"] == "dragoon" and "hunter" in d["tags"]:
				vfound = true
	t.ok(vfound, "view waves carry the built-in tags too")


## 复审 12：之后会出现敌炮的炮位不能部署；炮位必须是高地或平地、不在路线上
func _test_reserved_gun_cell() -> void:
	var tpl := _tpl(LANE, LANE_ROUTE, [{"turn": 1, "route": "r", "units": ["whitecoat"]}, {"turn": 3, "at": "E1", "units": ["gun"]}, {"turn": 8, "route": "r", "units": ["whitecoat"]}])
	var s := _battle(tpl, [], [_u("j", "jager")])
	_no(s, "deploy", {"unit": "j", "col": 4, "row": 0, "facing": "down"}, "reserved", "the future gun cell E1 is reserved")
	var cell: Dictionary = R.view(s)["grid"]["cells"][4]
	t.eq([cell["label"], cell["reserved"]], ["E1", true], "view marks E1 reserved")
	_fights(s, 2)
	t.eq(R.apply(s, "deploy", {"unit": "j", "col": 4, "row": 0, "facing": "down"}).get("err"), "enemy_here", "once the gun stands there it is an enemy cell")
	var on_route := _tpl(LANE, LANE_ROUTE, [{"turn": 1, "at": "D2", "units": ["gun"]}, {"turn": 2, "route": "r", "units": ["whitecoat"]}])
	t.ok(not R.validate_template(on_route).is_empty(), "validator: a gun cannot stand on a route")
	var in_marsh := _tpl(["^^m^^^^", "E=====G", "^^^^^^^"], LANE_ROUTE, [{"turn": 1, "at": "C1", "units": ["gun"]}, {"turn": 2, "route": "r", "units": ["whitecoat"]}])
	t.ok(not R.validate_template(in_marsh).is_empty(), "validator: a gun needs high or plain ground")
	var bad_ff := _tpl(LANE, LANE_ROUTE, [{"turn": 2, "at": "E1", "units": ["gun"], "first_fire": 2}, {"turn": 2, "route": "r", "units": ["whitecoat"]}])
	t.ok(not R.validate_template(bad_ff).is_empty(), "validator: first_fire must come after the gun appears")


## 复审 13：拒马的编号不会撞上名册里的单位
func _test_barricade_id() -> void:
	var tpl := _tpl(["^^^^^^^", "E=====G", "......."], LANE_ROUTE, [{"turn": 8, "route": "r", "units": ["whitecoat"]}])
	var s := _battle(tpl, [_u("barricade_1", "line", {"name": "某伙伴"})], [_u("e", "engineer")])
	_do(s, "deploy", {"unit": "e", "col": 1, "row": 1, "facing": "right"})
	_fights(s, 2)
	_do(s, "skill", {"unit": "e", "col": 2, "row": 1})
	t.eq([s["units"]["barricade_1"]["kind"], s["units"]["barricade_1"]["name"]], ["companion", "某伙伴"], "the companion called barricade_1 is untouched")
	t.eq((s["order"] as Array).count("barricade_1"), 1, "no duplicate in the order")
	t.eq(s["units"]["barricade_2"]["kind"], "barricade", "the new barricade took the next free id")


## 复审 14：指挥阶段把敌军心打到 0，交火时敌人当场溃逃，不再走、不再开炮；全漏过去不算“来敌全歼”
func _test_command_phase_rout() -> void:
	var tpl := _tpl(LANE, LANE_ROUTE, [{"turn": 1, "route": "r", "units": ["whitecoat", "grenz"]}, {"turn": 1, "at": "G1", "units": ["gun"]},
		{"turn": 8, "route": "r", "units": ["whitecoat"]}], {"enemy_morale": 2})
	var s := _battle(tpl, [], [_u("j", "jager", {"atk": 0, "hp": 30, "max_hp": 30}), _u("h", "hussar")])
	_do(s, "deploy", {"unit": "j", "col": 4, "row": 0, "facing": "left"})
	_fights(s, 2)
	t.eq(int(s["units"]["j"]["hp"]), 27, "turn 2: grenz shot the jager once")
	_do(s, "deploy", {"unit": "h", "col": 1, "row": 1, "facing": "right"})
	t.eq(int(s["enemy_morale"]), 0, "the charge killed both: enemy morale 0 in the command phase")
	var cancelled := true
	for r in R.intents(s):
		if r.get("type") == "enemy" and not bool(r.get("cancelled", false)):
			cancelled = false
	t.ok(cancelled, "intents: a routed enemy does nothing")
	t.eq(R.intents(s).filter(func(r): return r.get("type") == "crosshair").size(), 0, "intents: a routed gun shows no crosshair")
	_do(s, "fight")
	t.eq([s["outcome"], s["victory_kind"], s["turn"]], ["victory", "rout", 3], "rout victory on this turn")
	t.eq(int(s["units"]["j"]["hp"]), 27, "the gun aimed at the jager never fired")
	t.ok(_has_log(s, "敌人溃逃"), "log: the enemy flees")
	var lone := _tpl(LANE, LANE_ROUTE, [{"turn": 1, "route": "r", "units": ["whitecoat"]}])
	var s2 := _battle(lone, [], [])
	_fights(s2, 8)
	t.eq([s2["outcome"], s2["victory_kind"]], ["victory", "spent"], "the last enemy walked into the eagle: 敌军攻势耗尽, not 来敌全歼")
	t.ok(_has_log(s2, "敌军攻势耗尽"), "log names it")


## 复审 15：倒下的随军家眷不再算进随军家眷羁绊，所以她自己拿不到那 +1 枚
func _test_family_coin() -> void:
	var tpl := _tpl(LANE, LANE_ROUTE, [{"turn": 1, "route": "r", "units": ["whitecoat"]}, {"turn": 6, "route": "r", "units": ["whitecoat"]}], {"turn_limit": 6})
	var m := {"id": "milon", "cls": "line", "name": "米隆", "cost": 0, "hp": 1, "max_hp": 1, "atk": 0, "tags": ["family"]}
	var larrey := {"id": "larrey", "cls": "medic", "name": "拉雷", "cost": 0, "tags": ["family"]}
	var s := _battle(tpl, [m, larrey], [])
	_do(s, "deploy", {"unit": "milon", "col": 2, "row": 1, "facing": "right"})
	_do(s, "deploy", {"unit": "larrey", "col": 2, "row": 0, "facing": "right"})
	t.eq(s["bonds"]["camp_family"]["tier"], 2, "milon + larrey light 随军家眷")
	_fights(s, 3)
	t.eq(s["units"]["milon"]["status"], "dying", "milon is down")
	t.eq(s["bonds"]["camp_family"]["count"], 1, "随军家眷 drops to 1 when she falls")
	t.eq([s["fallen"][0]["family"], s["fallen"][0]["larrey"]], [false, true], "no family coin for the fallen member, Larrey still counts")
	var s2 := _battle(tpl, [m, larrey], [], true, {"protagonist": {"enabled": true, "tags": ["family"]}})
	_do(s2, "deploy", {"unit": "milon", "col": 2, "row": 1, "facing": "right"})
	_do(s2, "deploy", {"unit": "larrey", "col": 2, "row": 0, "facing": "right"})
	_do(s2, "deploy", {"unit": "hero", "col": 3, "row": 0, "facing": "right"})
	_fights(s2, 3)
	t.eq([s2["units"]["milon"]["status"], s2["bonds"]["camp_family"]["tier"]], ["dying", 2], "with larrey and a family protagonist the bond holds")
	t.eq(s2["fallen"][0]["family"], true, "so the fallen member does get the family coin")


## 复审 1（卡关）：什么都不做（不部署，或只用后方调度）在任何模板、任何一幕都赢不了
func _test_passive_loses() -> void:
	var lib: Dictionary = R.load_templates()
	var wins: Array = []
	for tid in lib["templates"].keys():
		for act in range(1, 7):
			for seed_value in [1, 2, 3]:
				for mode in ["off", "dispatch"]:
					var s: Dictionary = R.new_battle(tid, {"seed": seed_value, "act": act, "protagonist": {"enabled": mode == "dispatch"}})
					if mode == "dispatch":
						R.apply(s, "skill", {"unit": "hero"})
					var guard := 0
					while s["phase"] == "command" and guard < 30:
						R.apply(s, "fight", {})
						guard += 1
					if s["outcome"] != "defeat":
						wins.append("%s a%d s%d %s → %s" % [tid, act, seed_value, mode, s["outcome"]])
	t.eq(wins, [], "pressing 交火 every turn never wins on any template at any act")


## 复审 1（卡关）+ 6（主角）：通用模板和里沃利上，只放主角（站在任何一格）然后连按交火，也赢不了
func _test_hero_alone_loses() -> void:
	var wins: Array = []
	for tid in ["skirmish_a", "skirmish_b", "skirmish_c", "elite_a", "major_a", "rivoli"]:
		var probe: Dictionary = R.new_battle(tid, {"seed": 1, "act": 1, "protagonist": {"enabled": true}})
		var cells: Array = []
		for r in range(int(probe["rows"])):
			for c in range(int(probe["cols"])):
				if R._place_err(probe, probe["units"]["hero"], c, r) == "":
					cells.append([c, r])
		for act in [1, 3, 6]:
			for cell in cells:
				var s: Dictionary = R.new_battle(tid, {"seed": 1, "act": act, "protagonist": {"enabled": true}})
				if not bool(R.apply(s, "deploy", {"unit": "hero", "col": cell[0], "row": cell[1], "facing": "right"})["ok"]):
					continue
				var guard := 0
				while s["phase"] == "command" and guard < 30:
					R.apply(s, "fight", {})
					guard += 1
				if s["outcome"] == "victory":
					wins.append("%s a%d %s" % [tid, act, R._label(int(cell[0]), int(cell[1]))])
	t.eq(wins, [], "protagonist alone + 交火 never wins on the generic maps or Rivoli")


## 试玩反馈：遭遇战不能被开场一下冲锋解决，也不能三场都是同一张图。
## 序章之外的遭遇战换成 skirmish_b / skirmish_c：开场两路各 2 人，不挤在一格；骠骑兵第 1 回合部署冲锋最多打掉 2 个，
## 敌军心 8 → 6（skirmish_a 一下 4 个，8 → 4）。scene_map 里第 1 幕起就有两张不同的遭遇战图，序章以后不再用 skirmish_a。
func _test_skirmish_variety() -> void:
	var lib: Dictionary = R.load_templates()
	var hussar := [{"id": "dantes", "cls": "hussar", "name": "唐泰斯", "max_hp": 12, "atk": 6, "def": 1, "block": 1, "cost": 4}]
	for tid in ["skirmish_a", "skirmish_b", "skirmish_c"]:
		var probe: Dictionary = R.new_battle(tid, {"seed": 1, "act": 1})
		var stack := 0
		var cells := {}
		for e in probe["enemies"]:
			var k := "%d,%d" % [int(e["col"]), int(e["row"])]
			cells[k] = int(cells.get(k, 0)) + 1
			stack = maxi(stack, int(cells[k]))
		var best := 0
		for r in range(int(probe["rows"])):
			for c in range(int(probe["cols"])):
				for f in ["right", "left", "up", "down"]:
					var s: Dictionary = R.new_battle(tid, {"seed": 1, "act": 1, "roster": hussar})
					if bool(R.apply(s, "deploy", {"unit": "dantes", "col": c, "row": r, "facing": f})["ok"]):
						best = maxi(best, int(s["kills"]))
		if tid == "skirmish_a":
			t.eq([stack, best], [4, 4], "skirmish_a (prologue only): the opening 4-stack still falls to one charge")
		else:
			t.eq(stack, 2, "%s: the opening enemies are split, at most 2 per cell" % tid)
			t.ok(best <= 2, "%s: a turn-1 hussar charge kills at most 2 (%d)" % [tid, best])
	var used := {}
	var first_act := {}
	for sid in lib["scene_map"].keys():
		var row: Dictionary = lib["scene_map"][sid]
		var tid2 := str(row["template"])
		used[tid2] = int(used.get(tid2, 0)) + 1
		if tid2.begins_with("skirmish") and int(row["act"]) == 1:
			first_act[tid2] = true
	t.eq(int(used.get("skirmish_a", 0)), 1, "skirmish_a is only the prologue")
	t.ok(int(used.get("skirmish_b", 0)) >= 1 and int(used.get("skirmish_c", 0)) >= 1, "both new skirmish maps are used")
	t.eq(first_act.size(), 2, "act 1 already has two different skirmish maps")


## 试玩反馈：我方白刃落下的伤害也写进交火日志，和敌方「X打Y：N 伤（剩 M）」同一个格式
func _test_melee_log() -> void:
	var tpl := _tpl(LANE, LANE_ROUTE, [{"turn": 1, "route": "r", "units": ["whitecoat"]}, {"turn": 8, "route": "r", "units": ["whitecoat"]}])
	var s := _battle(tpl, [], [_u("g", "grenadier", {"name": "古尔戈", "hp": 30, "max_hp": 30, "atk": 4, "def": 0})])
	_do(s, "deploy", {"unit": "g", "col": 2, "row": 1, "facing": "right"})
	_fights(s, 2)
	var mark: int = (s["log"] as Array).size()
	_fights(s, 1)
	t.ok(_log_index(s, "古尔戈打白衣步兵：3 伤（剩 3）。", mark) >= 0, "our melee hit is logged: 4-1=3, 6-3=3 left")
	t.ok(_log_index(s, "白衣步兵打古尔戈：3 伤（剩 27）。", mark) >= 0, "the enemy hit uses the same format")
	_fights(s, 1)
	t.ok(_log_index(s, "古尔戈打白衣步兵：3 伤（剩 0）。") >= 0, "the killing blow shows 0 left")
	t.ok(_has_log(s, "击毙白衣步兵"), "then the kill line")
	# 预演的日志里也有这一行（悬停预演和交火一致）
	var s2 := _battle(tpl, [], [_u("g", "grenadier", {"name": "古尔戈", "hp": 30, "max_hp": 30, "atk": 4, "def": 0})])
	_do(s2, "deploy", {"unit": "g", "col": 2, "row": 1, "facing": "right"})
	_fights(s2, 2)
	var pv: Dictionary = R.preview(s2)
	t.ok((pv["log"] as Array).has("古尔戈打白衣步兵：3 伤（剩 3）。"), "preview log carries the melee line too")


## 试玩反馈：选骠骑兵朝向时先看冲锋结果——指令预演在深拷贝上下这条部署，不交火、不改状态，和真的下一模一样
func _test_preview_cmd() -> void:
	var s: Dictionary = R.new_battle("skirmish_a", {"seed": 1, "act": 1,
		"roster": [{"id": "dantes", "cls": "hussar", "name": "唐泰斯", "max_hp": 12, "atk": 6, "def": 1, "block": 1, "cost": 4}]})
	var before := JSON.stringify(s)
	var args := {"unit": "dantes", "col": 3, "row": 1, "facing": "right"}
	var pv: Dictionary = R.preview_cmd(s, "deploy", args)
	t.eq(JSON.stringify(s), before, "command preview does not touch the state")
	t.eq([pv["ok"], pv["unit"]["col"], pv["unit"]["row"], pv["hit_cells"], pv["kills"]], [true, 5, 1, [[6, 1]], 4], "charge lands on F2, hits G2, kills 4")
	var real := s.duplicate(true)
	_do(real, "deploy", args)
	t.eq([pv["enemy_morale"], pv["cp"], pv["log"]], [real["enemy_morale"], real["cp"], (real["log"] as Array).slice((s["log"] as Array).size())], "preview equals the real command")
	var none: Dictionary = R.preview_cmd(s, "deploy", {"unit": "dantes", "col": 3, "row": 1, "facing": "left"})
	t.eq([none["ok"], none["kills"], none["hit_cells"]], [true, 0, []], "facing away: no charge, nothing hit")
	t.eq(R.preview_cmd(s, "deploy", {"unit": "dantes", "col": 0, "row": 0, "facing": "right"}).get("err"), "terrain", "refused command: error code")
	t.eq(R.preview_cmd(s, "fight", {}).get("err"), "bad_cmd", "only command-phase orders can be previewed")
	t.eq(t.find_floats(pv), [], "command preview has no floats")


## 试玩反馈：抬不下时视图也给真实费用和原因；战果里标出进场前就带伤的伙伴（活下来伤痕不加重）
func _test_carry_reason_and_scar_flag() -> void:
	var lone := _fall_battle(5, {}, [])
	var lv := _unit_view(lone, "milon")
	t.eq([lv.get("can_carry"), lv.get("carry_cost"), lv.get("carry_reason")], [false, 2, "no_adjacent"], "nobody adjacent: cost still 2, reason no_adjacent")
	var helped := _fall_battle(5, {}, [_u("helper", "jager", {"atk": 0, "at": [2, 0]})])
	t.eq(_unit_view(helped, "milon").get("carry_reason"), "", "an ally adjacent: no reason, the button is on")
	helped["cp"] = 1
	t.eq([_unit_view(helped, "milon").get("can_carry"), _unit_view(helped, "milon").get("carry_reason")], [false, "no_cp"], "1 CP: reason no_cp")
	var scarred := _fall_battle(5, {"scarred": true}, [_u("helper", "jager", {"atk": 0, "at": [2, 0]})])
	_fights(scarred, 5)
	var row: Dictionary = R.result(scarred)["fallen"][0]
	t.eq([row.get("was_scarred"), row.get("fated")], [true, false], "result marks a companion who was already scarred")
	var fresh := _fall_battle(5, {}, [_u("helper", "jager", {"atk": 0, "at": [2, 0]})])
	_fights(fresh, 5)
	t.eq(R.result(fresh)["fallen"][0].get("was_scarred"), false, "a fresh companion is not marked")


## 复审 6（主角）：斩首令——第 4 幕起的精英战和会战，主角在场时敌将发一次，提前一回合亮出来，下回合远程和开炮的敌炮都打主角
func _decap_battle(act: int) -> Dictionary:
	var tpl := _tpl(LANE8, LANE8_ROUTE, [{"turn": 1, "route": "r", "units": ["grenz"]}, {"turn": 1, "at": "H4", "units": ["gun"], "first_fire": 4},
		{"turn": 8, "route": "r", "units": ["whitecoat"]}])
	var s := _battle(tpl, [], [_u("j", "jager", {"atk": 0, "hp": 40, "max_hp": 40})], true, {"act": act})
	_do(s, "deploy", {"unit": "hero", "col": 2, "row": 0, "facing": "right"})
	_do(s, "deploy", {"unit": "j", "col": 3, "row": 2, "facing": "right"})
	_fights(s, 2)
	return s


func _test_decapitation() -> void:
	var calm := _decap_battle(3)
	t.eq(int(calm["decap_turn"]), -1, "act 3: no decapitation order")
	var gun3: Dictionary = calm["enemies"][1]
	t.eq(gun3["aim"], [3, 2], "act 3: the gun aims at the nearest unit (the jager)")
	_fights(calm, 1)
	t.eq(_intent_for(calm, 1).get("attack", {}).get("target"), "j", "act 3: the grenz shoots the nearer jager")
	var s := _decap_battle(4)
	t.eq(int(s["decap_turn"]), 4, "act 4, turn 3, protagonist on the field: order issued for turn 4")
	t.ok(_has_log(s, "斩首令"), "log announces it")
	var rows := R.intents(s)
	var dec := rows.filter(func(r): return r.get("type") == "decap")
	t.eq(dec.size(), 1, "intents show the order a turn early")
	var cross := rows.filter(func(r): return r.get("type") == "crosshair")
	t.eq([cross[0].get("cell"), "decap" in cross[0].get("marks", [])] if not cross.is_empty() else [], [[2, 0], true], "the gun firing on turn 4 aims at the protagonist")
	_fights(s, 1)
	var row := _intent_for(s, 1)
	t.eq([row.get("attack", {}).get("target"), "decap" in row.get("marks", [])], ["hero", true], "turn 4: the grenz in range shoots the protagonist")
	var hp: int = int(s["units"]["hero"]["hp"])
	_fights(s, 1)
	t.eq(int(s["units"]["hero"]["hp"]), hp - 3 - 6, "grenz 4-1 and gun 7-1 both hit him")
	_fights(s, 3)
	t.eq(int(s["decap_turn"]), 4, "once per battle")
	var sk := R.new_battle("skirmish_a", {"seed": 2, "act": 6, "protagonist": {"enabled": true}})
	_do(sk, "deploy", {"unit": "hero", "col": 2, "row": 1, "facing": "right"})
	_fights(sk, 3)
	t.eq(int(sk.get("decap_turn", -1)), -1, "skirmishes have no enemy general: no order")
