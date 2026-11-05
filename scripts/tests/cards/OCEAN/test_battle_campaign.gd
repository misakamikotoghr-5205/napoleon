# 战斗规则 v2 接入远洋战役：出征名单、上限、开战 / 指令 / 结算全走战役指令；奖赏换算、伤痕跨场保留、
# 伙伴一条命（阵亡后不能再上）、主角阵亡讣告、战败与被俘转大命运、存档读档后结果一字不差、引擎桥接、招募部队。
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const Campaign = preload("res://scripts/cards/campaign/ocean_campaign.gd")
const View = preload("res://scripts/cards/campaign/ocean_view.gd")
const RogueData = preload("res://scripts/cards/campaign/ocean_rogue_data.gd")
const RogueRules = preload("res://scripts/cards/campaign/ocean_rogue_rules.gd")
const R = preload("res://scripts/cards/campaign/battle/battle_rules.gd")
const B2 = preload("res://scripts/cards/campaign/ocean_battle2.gd")

const CLASS_MAP := {"dantes": "hussar", "gourgaud": "grenadier", "faria": "engineer", "friday": "drummer",
	"nemo": "artillery", "morel": "line", "marie": "medic", "corso": "jager"}
## 序章遭遇战（skirmish_a，第 1 幕）：古尔戈守 C2，猎兵在 C1 朝下打，第 4 回合唐泰斯上 D3
const PLAN_A := {
	1: [["deploy", {"unit": "gourgaud", "col": 2, "row": 1, "facing": "right"}]],
	2: [["deploy", {"unit": "jager_3", "col": 2, "row": 0, "facing": "down"}]],
	4: [["deploy", {"unit": "dantes", "col": 3, "row": 2, "facing": "up"}]],
}
## 带主角（帝国旧部开场军令点 +2）：第 3 回合战列上 B2，第 4 回合主角上 B1
const PLAN_B := {
	1: [["deploy", {"unit": "gourgaud", "col": 2, "row": 1, "facing": "right"}]],
	2: [["deploy", {"unit": "jager_3", "col": 2, "row": 0, "facing": "down"}]],
	3: [["deploy", {"unit": "line_1", "col": 1, "row": 1, "facing": "right"}]],
	4: [["deploy", {"unit": "hero", "col": 1, "row": 0, "facing": "down"}]],
}
## 唐泰斯部署在 D2，冲锋冲到 F2 顶住，第 4 回合倒下；战列在 F1 朝下打（和他相邻，能抬他）
const PLAN_DANTES := {
	1: [["deploy", {"unit": "dantes", "col": 3, "row": 1, "facing": "right"}]],
	2: [["deploy", {"unit": "line_1", "col": 5, "row": 0, "facing": "down"}]],
}
const PLAN_HERO_ALONE := {1: [["deploy", {"unit": "hero", "col": 3, "row": 1, "facing": "right"}]]}

var t: RefCounted


func _initialize() -> void:
	t = T.new(self, "OCEAN_battle_campaign")
	CardSave.set_root(t.user_dir())
	_test_data()
	_test_lineup_and_caps()
	_test_victory_rewards()
	_test_bonds_in_campaign()
	_test_scar_persists()
	_test_permadeath()
	_test_obituary()
	_test_defeat_big_fate()
	_test_wounded_protagonist()
	_test_captured()
	_test_save_load_mid_battle()
	_test_engine_bridge()
	_test_troops()
	print("OCEAN battle_campaign assertions: %d" % t.checks)
	t.finish()


# ---------------------------------------------------------------- 工具

func _new(stage: int = 0, seed_value: int = 1815) -> RefCounted:
	var c := Campaign.new()
	var r: Dictionary = c.new_game({"stage": stage, "seed": seed_value})
	t.ok(r.get("ok", false), "start stage %d seed %d: %s" % [stage, seed_value, r])
	_day(c)
	return c


func _day(c: RefCounted) -> void:
	for _i in range(6):
		if c.state.get("phase") in ["day", "game_over"]:
			return
		c.send(&"campaign.wait", {})
	t.eq(c.state.get("phase"), "day", "reach day phase")


func _send(c: RefCounted, cmd: String, args: Dictionary = {}) -> Dictionary:
	var r: Dictionary = c.send(StringName(cmd), args)
	t.ok(bool(r.get("ok", false)), "%s %s at %s: %s" % [cmd, args, c.scene().get("id", ""), r])
	return r


func _reject(c: RefCounted, cmd: String, args: Dictionary, err: String, label: String) -> void:
	var before: Dictionary = c.snapshot()
	var r: Dictionary = c.send(StringName(cmd), args)
	t.eq(r.get("ok"), false, label + " rejected")
	t.eq(r.get("err"), err, label + " error")
	t.eq(c.snapshot(), before, label + " leaves state unchanged")


func _b2(c: RefCounted) -> Dictionary:
	return c.state["rogue"]["battle2"]


func _st(c: RefCounted) -> Dictionary:
	return c.state["rogue"]["battle2"]["state"]


func _q(c: RefCounted) -> Dictionary:
	return View.query(c, &"campaign")["battle2"]


func _cmd(c: RefCounted, cmd: String, args: Dictionary = {}) -> Dictionary:
	return _send(c, "campaign.battle_cmd", {"cmd": cmd, "args": args})


## 按计划逐回合下指令再交火；until 返回 true 时停在那一回合的指挥阶段
func _play(c: RefCounted, plan: Dictionary, until: Callable = Callable(), max_turns: int = 20) -> void:
	for _i in range(max_turns):
		var st := _st(c)
		if str(st.get("phase", "")) != "command":
			return
		if until.is_valid() and until.call(st):
			return
		for step in plan.get(int(st["turn"]), []):
			_cmd(c, step[0], step[1])
		_cmd(c, "fight")


func _begin(c: RefCounted, comps: Array, troops: Array, hero: bool) -> void:
	_send(c, "campaign.battle_prepare")
	_send(c, "campaign.battle_begin", {"companions": comps, "troops": troops, "protagonist": hero})
	t.eq(_b2(c)["phase"], "active", "battle active after begin")


## 跳到下一场：本场的仗还没了结就空名单出征、立刻撤出（剧情决定要等它），再选一个不需要线索的剧情选项
func _advance(c: RefCounted) -> void:
	var current := str(c.scene()["id"])
	if not B2.resolved(c):
		var phase := str(_b2(c)["phase"])
		if phase != "active" and not (phase == "finished" and str(_b2(c)["scene"]) == current):
			_send(c, "campaign.battle_prepare")
			_send(c, "campaign.battle_begin", {"companions": [], "troops": [], "protagonist": false})
		if str(_b2(c)["phase"]) == "active":
			if str(_st(c)["phase"]) == "command":
				_cmd(c, "retreat")
			_send(c, "campaign.battle_finish")
	t.ok(B2.resolved(c), "battle resolved before leaving " + current)
	for choice in c.available_choices():
		if bool(choice.get("available", false)) and (choice.get("requires_clues", []) as Array).is_empty():
			_send(c, "campaign.choose", {"choice": choice["id"]})
			break
	_day(c)
	t.ok(str(c.scene()["id"]) != current, "advanced past " + current)


func _ledger(c: RefCounted, kind: String) -> Array:
	var out: Array = []
	for row in c.state["ledger"]:
		if str(row.get("type", "")) == kind:
			out.append(row)
	return out


func _fallen(res: Dictionary, uid: String) -> Dictionary:
	for f in res.get("fallen", []):
		if str(f["unit"]) == uid:
			return f
	return {}


## 第一个满足条件的战役种子（战斗种子 = 战役种子 + 场景，命悬一线的铜钱由它定）
func _seed_where(scene_id: String, uid: String, coins: int, want_dead: bool) -> int:
	for s in range(1, 400):
		var faces: Array = R._coin_faces(B2.seed_for(s, scene_id), uid, coins)
		if (not (1 in faces)) == want_dead:
			return s
	return -1


# ---------------------------------------------------------------- 数据

func _test_data() -> void:
	var d := B2.data()
	t.ok(not d.is_empty(), "ocean_battle.json loads")
	var classes := {}
	for c_id in RogueData.COMPANION_IDS:
		var p := B2.profile(c_id)
		t.eq(p.get("cls"), CLASS_MAP[c_id], c_id + " battle class")
		t.ok(R.CLASSES.has(str(p.get("cls"))), c_id + " class known to the engine")
		t.ok(R.SKILLS.has(str(p.get("skill"))) and str(p.get("skill")) != "pay_chest", c_id + " has an engine companion skill")
		for k in ["hp", "atk", "def", "block", "cost"]:
			t.eq(typeof(p.get(k)), TYPE_INT, c_id + " integer " + k)
		classes[str(p.get("cls"))] = true
	t.eq(classes.size(), 8, "eight companions, eight different classes")
	var lib := R.load_templates()
	t.ok(lib.get("ok", false), "templates with bond sets validate: %s" % [lib.get("errors", [])])
	var ocean: Array = lib.get("bond_sets", {}).get("ocean", [])
	t.eq(R.validate_bonds(ocean), [], "ocean bond set validates")
	var tags := {}
	for entry in ocean:
		if typeof(entry) == TYPE_DICTIONARY:
			tags[str(entry["tag"])] = true
	for b_id in RogueData.BOND_IDS:
		t.ok(tags.has(b_id), "engine has a faction bond for tag " + b_id)
	for cls in ["artillery_school", "square", "cavalry_reserve"]:
		t.ok(cls in ocean, "ocean set keeps class bond " + cls)
	t.eq(B2.franc_to_treasury("shilling", 100), 80, "25 francs = 20 shillings")
	t.eq(B2.franc_to_treasury("ration", 101), 50, "rations: francs / 2, floored")
	t.eq(B2.franc_to_treasury("deep_gold", 77), 77, "deep gold: 1 : 1")


# ---------------------------------------------------------------- 名单与上限

func _test_lineup_and_caps() -> void:
	var c := _new()
	t.eq(_q(c)["phase"], "none", "no battle before prepare")
	_reject(c, "campaign.battle_begin", {"companions": [], "troops": [], "protagonist": false}, "bad_phase", "begin before prepare")
	_reject(c, "campaign.battle_cmd", {"cmd": "fight", "args": {}}, "bad_phase", "cmd before begin")
	_reject(c, "campaign.battle_finish", {}, "bad_phase", "finish before begin")
	_reject(c, "campaign.battle_prepare", {"x": 1}, "bad_args", "prepare takes no args")
	_send(c, "campaign.battle_prepare")
	var q := _q(c)
	t.eq([q["phase"], q["template"], q["scale"], q["act"]], ["lineup", "skirmish_a", "skirmish", 1], "prologue maps to skirmish_a act 1")
	var lu: Dictionary = q["lineup"]
	var ids: Array = []
	for cand in lu["candidates"]:
		ids.append(cand["id"])
		for k in ["id", "name", "cls", "hp", "max_hp", "scarred", "fated", "death_pct", "bonds"]:
			t.ok(cand.has(k), "candidate field " + k)
	t.eq(ids, ["dantes", "gourgaud", "faria"], "starter companions are the candidates")
	t.eq(lu["candidates"][0]["death_pct"], 12, "unscarred companion: 3 coins, 12% if left on the field")
	t.eq(lu["caps"], {"field": 5, "companions": 2}, "skirmish act 1 caps from the difficulty table")
	t.eq([lu["protagonist"]["hp"], lu["protagonist"]["death_pct"], lu["protagonist"]["hunters"]], [12, 25, -1], "protagonist line; hunters unknown")
	t.eq(lu["troops"].size(), 3, "prologue starting troops")
	_send(c, "campaign.battle_prepare")
	t.eq(_b2(c)["phase"], "lineup", "prepare again in lineup is a no-op")
	var intel := int(c.state["rogue"]["coins"]["intel"])
	_send(c, "campaign.battle_reveal")
	t.eq(int(c.state["rogue"]["coins"]["intel"]), intel - 1, "reveal spends an intel coin")
	t.eq(_q(c)["lineup"]["protagonist"]["hunters"], 2, "two dragoons hunt the protagonist in skirmish_a")
	_reject(c, "campaign.battle_reveal", {}, "already_used", "reveal twice")
	_reject(c, "campaign.battle_begin", {"companions": ["dantes", "gourgaud", "faria"], "troops": [], "protagonist": false}, "over_companion_cap", "three companions in a skirmish")
	_reject(c, "campaign.battle_begin", {"companions": ["dantes", "gourgaud"], "troops": ["line_1", "line_2", "jager_3"], "protagonist": true}, "over_field_cap", "six units in a five-unit skirmish")
	_reject(c, "campaign.battle_begin", {"companions": ["dantes", "dantes"], "troops": [], "protagonist": false}, "bad_args", "duplicate companion")
	_reject(c, "campaign.battle_begin", {"companions": ["nobody"], "troops": [], "protagonist": false}, "bad_args", "unknown companion")
	_reject(c, "campaign.battle_begin", {"companions": [], "troops": ["ghost_9"], "protagonist": false}, "bad_args", "unknown troop")
	_reject(c, "campaign.battle_begin", {"companions": [], "troops": []}, "bad_args", "missing protagonist flag")
	_reject(c, "campaign.battle_begin", {"companions": ["friday"], "troops": [], "protagonist": false}, "missing_companion", "unrecruited companion")
	_send(c, "campaign.battle_begin", {"companions": ["gourgaud", "dantes"], "troops": ["line_1", "jager_3"], "protagonist": false})
	q = _q(c)
	t.eq(q["phase"], "active", "battle active")
	t.ok(q["view"].get("ok", false), "battle view exposed")
	t.eq(q["lineup"], {}, "lineup gone once the battle starts")
	t.eq([q["view"]["field_cap"], q["view"]["companion_cap"]], [5, 2], "engine uses the same caps")
	var bar: Array = []
	for row in q["view"]["deploy_bar"]:
		bar.append(row["uid"])
	t.eq(bar, ["hero", "gourgaud", "dantes", "line_1", "jager_3"], "deploy bar = protagonist slot + lineup")
	t.eq(q["view"]["bonds"].size(), 8, "ocean bond set: 3 class + 5 faction bonds")
	t.eq(_st(c)["units"]["gourgaud"]["tags"], ["imperial", "island"], "faction tags from the existing bonds")
	t.eq(_st(c)["units"]["dantes"]["skill"], "bayonet_charge", "companion skill from data")
	_reject(c, "campaign.battle_cmd", {"cmd": "nonsense", "args": {}}, "bad_cmd", "engine rejects unknown command")
	_reject(c, "campaign.battle_cmd", {"cmd": "deploy", "args": {"unit": "gourgaud", "col": "x"}}, "bad_args", "engine rejects bad args")
	_reject(c, "campaign.battle_cmd", {"cmd": "fight", "args": []}, "bad_args", "args must be a dictionary")
	_reject(c, "campaign.battle_finish", {}, "battle_not_over", "finish while fighting")
	_reject(c, "campaign.battle_prepare", {}, "battle_active", "prepare during a battle")
	var prev: Dictionary = View.query(c, &"campaign.battle_preview")
	t.ok(prev.get("ok", false), "battle_preview query answers during a battle")
	t.eq(prev, B2.public(R.preview(_st(c))), "preview query = BattleRules.preview (blacklisted keys prefixed)")
	t.eq(q["view"]["battle_units"], B2.public(R.view(_st(c))["units"]), "view = BattleRules.view, units -> battle_units")
	t.no_leaks(View.query(c, &"campaign"), "campaign query during a battle")
	t.no_leaks(prev, "battle preview query")
	t.eq(View.query(c, &"campaign.battle2"), _q(c), "campaign.battle2 query = campaign query's battle2")


# ---------------------------------------------------------------- 胜利与奖赏

func _test_victory_rewards() -> void:
	for with_hero in [false, true]:
		var c := _new()
		var coins: Dictionary = c.state["rogue"]["coins"].duplicate()
		var money := int(c.state["metrics"]["treasury"])
		_begin(c, ["gourgaud", "dantes"], ["line_1", "jager_3"], with_hero)
		if with_hero:
			t.eq(int(_st(c)["cp"]), 8, "imperial bond (Gourgaud + protagonist in the lineup): opening CP 8")
		_play(c, PLAN_B if with_hero else PLAN_A)
		var res := R.result(_st(c))
		t.eq(res["outcome"], "victory", "scripted plan wins (hero %s)" % with_hero)
		t.eq(res["rewards"]["franc"], 93 if with_hero else 62, "francs: 2 stars, x1.5 with the protagonist on the field")
		_send(c, "campaign.battle_finish")
		var gain := int(res["rewards"]["franc"]) * 4 / 5
		t.eq(int(c.state["metrics"]["treasury"]), money + gain, "francs go to the treasury in shillings")
		t.eq(int(c.state["rogue"]["coins"]["medal"]), int(coins["medal"]) + int(res["rewards"]["medal"]), "medals to rogue coins")
		t.eq(int(c.state["rogue"]["coins"]["gold"]), int(coins["gold"]) + int(res["rewards"]["gold"]), "gold to rogue coins")
		t.eq(_b2(c)["phase"], "finished", "battle finished")
		t.eq(_q(c)["result"]["outcome"], "victory", "result kept for the UI")
		t.no_leaks(View.query(c, &"campaign"), "campaign query after a battle")
		var rows := _ledger(c, "battle2")
		t.eq(rows.size(), 1, "one chronicle entry per battle")
		t.eq([rows[0]["outcome"], rows[0]["stars"], rows[0]["treasury"], rows[0]["protagonist"]], ["victory", res["stars"], gain, "field" if with_hero else "absent"], "chronicle entry contents")
		var text := View._record_text(c, rows[0])
		t.ok(text.find("{") < 0 and text.find(str(gain)) >= 0, "chronicle text formatted: " + text)
		_reject(c, "campaign.battle_prepare", {}, "already_complete", "one battle per scene")
		_reject(c, "campaign.battle_finish", {}, "bad_phase", "finish twice")
		if with_hero:
			t.eq(c.state["rogue"]["army"]["trust"].get("hero|gourgaud"), 1, "protagonist on the field at the end: trust +1")
			var line: Dictionary = {}
			for tr in c.state["rogue"]["army"]["troops"]:
				if tr["id"] == "line_1":
					line = tr
			t.eq(line.get("strength"), 2, "routed troop loses one strength")
		t.eq(t.find_floats(c.state), PackedStringArray(), "campaign state has no floats after a battle")


func _test_bonds_in_campaign() -> void:
	var c := _new()
	_begin(c, ["dantes", "faria"], [], false)
	t.eq(int(_st(c)["cp"]), 6, "no imperial pair: opening CP 6")
	_cmd(c, "deploy", {"unit": "faria", "col": 1, "row": 1, "facing": "right"})
	_cmd(c, "fight")
	_cmd(c, "deploy", {"unit": "dantes", "col": 3, "row": 2, "facing": "up"})
	var bonds := {}
	for b in _q(c)["view"]["bonds"]:
		bonds[b["id"]] = b
	t.eq([bonds["shadow"]["tier"], bonds["shadow"]["active"]], [2, true], "Dantes + Faria light 暗影密使")
	_cmd(c, "fight")
	t.eq((_st(c)["hand"] as Array).size(), 4, "暗影密使 2: hand refills to 4 cards")
	t.eq(RogueRules.active_bonds(c.state["rogue"]).has("shadow"), true, "rogue-level bond unchanged by the battle layer")


# ---------------------------------------------------------------- 伤痕跨场

func _test_scar_persists() -> void:
	var c := _new()
	_begin(c, ["dantes"], ["line_1"], false)
	_play(c, PLAN_DANTES, func(st: Dictionary) -> bool: return st["units"]["dantes"]["status"] == "dying")
	t.eq(_st(c)["units"]["dantes"]["status"], "dying", "Dantes falls on the road")
	_cmd(c, "carry", {"unit": "dantes"})
	_play(c, PLAN_DANTES)
	var res := R.result(_st(c))
	t.eq(res["outcome"], "victory", "the line holds after Dantes is carried off")
	var f := _fallen(res, "dantes")
	t.eq([f.get("carried"), f.get("rolled"), f.get("scar"), f.get("died")], [true, false, true, false], "carried before the next enemy phase: scar only")
	_send(c, "campaign.battle_finish")
	var comp: Dictionary = c.state["rogue"]["companions"]["dantes"]
	t.eq([comp["scarred"], comp["b_max_hp"], comp["alive"]], [true, 9, true], "scar persists in rogue: max hp 12 -> 9")
	t.eq(_ledger(c, "battle2")[0]["scarred"], ["dantes"], "chronicle lists the scar")
	_advance(c)
	t.eq(c.scene()["id"], "scene01", "next scene")
	t.eq(c.state["rogue"]["companions"]["dantes"]["scarred"], true, "scar survives the scene change")
	_send(c, "campaign.battle_prepare")
	var cand: Dictionary = {}
	for row in _q(c)["lineup"]["candidates"]:
		if row["id"] == "dantes":
			cand = row
	t.eq([cand.get("scarred"), cand.get("max_hp"), cand.get("death_pct"), cand.get("carried_pct")], [true, 9, 12, 6], "lineup shows the scar and the carried risk")
	_send(c, "campaign.battle_begin", {"companions": ["dantes"], "troops": [], "protagonist": false})
	t.eq([_st(c)["units"]["dantes"]["max_hp"], _st(c)["units"]["dantes"]["scarred"]], [9, true], "engine fields the scarred companion at 9")


# ---------------------------------------------------------------- 一条命

func _test_permadeath() -> void:
	var c := _new()
	t.eq(R._coin_faces(B2.seed_for(1815, "prologue"), "dantes", 3), [0, 0, 0], "seed 1815: Dantes' three coins are all tails")
	_begin(c, ["dantes"], ["line_1"], false)
	_play(c, PLAN_DANTES)
	var res := R.result(_st(c))
	var f := _fallen(res, "dantes")
	t.eq([f.get("rolled"), f.get("coins"), f.get("died")], [true, 3, true], "left on the field: three coins, all tails")
	_send(c, "campaign.battle_finish")
	var rogue: Dictionary = c.state["rogue"]
	t.eq(rogue["companions"]["dantes"]["alive"], false, "permadeath: alive = false")
	t.ok("dantes" in rogue["fallen_companions"], "fallen list")
	t.eq(_ledger(c, "battle2")[0]["died"], ["dantes"], "chronicle lists the dead")
	t.eq(_ledger(c, "companion_fallen").size(), 1, "companion_fallen recorded")
	t.eq(RogueRules.active_bonds(rogue).has("shadow"), false, "his bonds break (暗影密使 needs Dantes + Faria)")
	_advance(c)
	_send(c, "campaign.battle_prepare")
	for row in _q(c)["lineup"]["candidates"]:
		t.ok(row["id"] != "dantes", "dead companion is not a candidate")
	_reject(c, "campaign.battle_begin", {"companions": ["dantes"], "troops": [], "protagonist": false}, "companion_fallen", "dead companion cannot be fielded again")


# ---------------------------------------------------------------- 主角阵亡

func _test_obituary() -> void:
	var c := _new()
	t.eq(R._coin_faces(B2.seed_for(1815, "prologue"), "hero", 2), [0, 0], "seed 1815: the protagonist's two coins are tails")
	_begin(c, [], [], true)
	_play(c, PLAN_HERO_ALONE, func(st: Dictionary) -> bool: return st["units"]["hero"]["status"] == "down")
	t.eq(_st(c)["units"]["hero"]["status"], "down", "protagonist falls")
	_cmd(c, "retreat")
	_send(c, "campaign.battle_finish")
	t.eq([c.state["phase"], c.state["ending"], c.state["end_reason"]], ["game_over", "obituary", "protagonist_killed"], "obituary game over")
	t.ok(not c.state["ending"] in ["alliance", "ghost", "dark", "tragedy"], "the obituary is not one of the four endings")
	t.eq(_ledger(c, "battle2")[0]["protagonist"], "died", "chronicle: protagonist died")
	t.eq(_ledger(c, "ending").size(), 1, "ending recorded")
	t.eq(View.build(c)["game_over_reason"], "obituary", "view reports the obituary")
	t.eq(c.send(&"campaign.battle_prepare", {}).get("err"), "bad_phase", "the run is over")
	var restored := Campaign.new()
	restored.load_definition()
	t.ok(restored.restore(c.snapshot()).get("ok", false), "obituary save restores")
	View.setup_text(c)
	var obit := CardText.ui("g02.ending.obituary")
	t.ok(obit.find(B2.text("obituary_title")) == 0 and obit.find("{") < 0, "obituary text from JSON: " + obit.left(40))
	t.ok(obit.find(str(RogueData.COMPANIONS["gourgaud"]["name"])) >= 0, "memoir signed by the living companions")


# ---------------------------------------------------------------- 战败与大命运

func _test_defeat_big_fate() -> void:
	var c := _new()
	_begin(c, [], [], false)
	_play(c, {})
	t.eq(R.result(_st(c))["outcome"], "defeat", "nobody deployed: defeat")
	_send(c, "campaign.battle_finish")
	var fate: Dictionary = c.state["rogue"]["big_fate"]
	t.eq([fate["pending"], fate["trigger"]], [true, "battle_lost"], "defeat sets the big fate pending")
	t.eq(c.state["phase"], "day", "a lost battle does not end the run")
	_reject(c, "campaign.battle_prepare", {}, "big_fate_pending", "resolve the big fate first")
	# 试玩反馈：大命运对话写出当下的利害——会牺牲谁、储备和生命与动力还剩多少
	View.build(c)
	var body := CardText.card("ocean.big_fate", "body")
	var victim := str(B2.profile("dantes").get("short", "dantes"))
	t.ok(body.contains(victim) and body.contains(str(int(c.state["metrics"]["treasury"]))) and body.contains(str(int(c.state["metrics"]["vitality"]))),
		"big fate body names the rearguard (%s) and the current reserves: %s" % [victim, body.left(80)])
	t.ok(body.find("{") < 0, "big fate body has no unfilled placeholder")
	_send(c, "campaign.big_fate", {"choice": "desperate_breakout"})
	t.eq(c.state["rogue"]["big_fate"]["pending"], false, "big fate resolved with the existing command")


func _test_wounded_protagonist() -> void:
	var s := _seed_where("prologue", "hero", 2, false)
	t.ok(s > 0, "found a seed where the protagonist survives his fall")
	var c := _new(0, s)
	_begin(c, [], [], true)
	_play(c, PLAN_HERO_ALONE)
	var res := R.result(_st(c))
	var f := _fallen(res, "hero")
	t.eq([f.get("rolled"), f.get("died"), f.get("wounded")], [true, false, true], "protagonist falls and survives")
	_send(c, "campaign.battle_finish")
	t.eq(c.state["rogue"]["army"]["hero_wounded"], true, "protagonist wounded")
	t.eq(c.state["phase"], "day", "a wounded protagonist does not end the run")
	t.eq(_ledger(c, "battle2")[0]["protagonist"], "wounded", "chronicle: wounded")
	if res["outcome"] == "defeat":
		t.eq(c.state["rogue"]["big_fate"]["trigger"], "battle_lost", "fell before the end: not captured")
		_send(c, "campaign.big_fate", {"choice": "desperate_breakout"})
	_advance(c)
	_send(c, "campaign.battle_prepare")
	t.eq(_q(c)["lineup"]["protagonist"]["available"], false, "lineup marks him unavailable")
	_reject(c, "campaign.battle_begin", {"companions": [], "troops": [], "protagonist": true}, "protagonist_wounded", "wounded protagonist sits out the next battle")
	_send(c, "campaign.battle_begin", {"companions": [], "troops": ["line_1"], "protagonist": false})
	_cmd(c, "retreat")
	_send(c, "campaign.battle_finish")
	t.eq(c.state["rogue"]["army"]["hero_wounded"], false, "healed after sitting out a battle")


func _test_captured() -> void:
	# 鹦鹉螺号第十场（elite_a，第 5 幕）：唐泰斯一个人顶在 F2 倒下，主角第 7 回合才上 B1，第 8 回合军心归零
	var c := _new(3)
	t.eq(c.scene()["id"], "scene10", "nautilus opens at scene10")
	_begin(c, ["dantes"], [], true)
	t.eq(int(_st(c)["units"]["hero"]["max_hp"]), 20, "protagonist hp grows with the act (act 5: 12 + 8)")
	_play(c, {1: [["deploy", {"unit": "dantes", "col": 5, "row": 1, "facing": "right"}]],
		7: [["deploy", {"unit": "hero", "col": 1, "row": 0, "facing": "right"}]]})
	var res := R.result(_st(c))
	t.eq([res["outcome"], res["captured"]], ["defeat", ["hero", "dantes"]], "defeat with the protagonist on the field: both captured")
	_send(c, "campaign.battle_finish")
	var rogue: Dictionary = c.state["rogue"]
	t.eq([rogue["big_fate"]["pending"], rogue["big_fate"]["trigger"]], [true, "protagonist_captured"], "captured protagonist: big fate pending")
	t.eq([rogue["companions"]["dantes"]["captured"], rogue["companions"]["dantes"]["alive"]], [true, true], "captured companion is alive but held")
	t.eq(_ledger(c, "battle2")[0]["protagonist"], "captured", "chronicle: captured")
	t.eq(c.state["phase"], "day", "capture is not game over")
	_send(c, "campaign.big_fate", {"choice": "ransom_supply"})
	t.eq(c.state["rogue"]["companions"]["dantes"]["captured"], false, "ransom frees the captives")


# ---------------------------------------------------------------- 存档

func _test_save_load_mid_battle() -> void:
	var a := _new()
	_begin(a, ["gourgaud", "dantes"], ["line_1", "jager_3"], true)
	_play(a, PLAN_B, func(st: Dictionary) -> bool: return int(st["turn"]) >= 4)
	_cmd(a, "deploy", PLAN_B[4][0][1])
	var saved: Variant = JSON.parse_string(JSON.stringify(a.snapshot()))
	t.ok(t.find_floats(saved).size() > 0, "JSON round trip turns integers into floats")
	var b := Campaign.new()
	b.load_definition()
	t.ok(b.restore(saved).get("ok", false), "mid-battle save restores")
	t.eq(b.hash(), a.hash(), "restored hash identical")
	t.eq(t.find_floats(b.state), PackedStringArray(), "no floats after load (BattleRules.load_state)")
	t.eq(View.query(b, &"campaign.battle_preview"), View.query(a, &"campaign.battle_preview"), "same preview after load")
	var rest: Dictionary = PLAN_B.duplicate(true)
	rest.erase(4)
	for c in [a, b]:
		_play(c, rest)
		_send(c, "campaign.battle_finish")
	t.eq(b.hash(), a.hash(), "same outcome after load")
	t.eq(_b2(b)["result"], _b2(a)["result"], "same battle result after load")
	var corrupt: Dictionary = a.snapshot()
	corrupt["rogue"]["battle2"]["phase"] = "bogus"
	t.eq(b.restore(corrupt).get("ok"), false, "bad battle phase rejected")
	var mid: Dictionary = (saved as Dictionary).duplicate(true)
	mid["rogue"]["battle2"]["state"]["v"] = 1
	t.eq(_restore_fails(mid), true, "bad battle state rejected")
	var old: Dictionary = a.snapshot()
	old["rogue"].erase("army")
	old["rogue"].erase("battle2")
	for c_id in RogueData.COMPANION_IDS:
		for k in ["scarred", "captured", "b_max_hp"]:
			old["rogue"]["companions"][c_id].erase(k)
	var migrated := Campaign.new()
	migrated.load_definition()
	t.ok(migrated.restore(old).get("ok", false), "pre-battle-v2 save migrates")
	t.eq(migrated.state["rogue"]["battle2"]["phase"], "none", "migrated save has no battle")


func _restore_fails(saved: Dictionary) -> bool:
	var c := Campaign.new()
	c.load_definition()
	return not bool(c.restore(saved).get("ok", false))


func _test_engine_bridge() -> void:
	var engine := CardEngine.new()
	t.ok(engine.new_game({"campaign": "ocean_pawn", "seed": 1815, "save_dir": t.user_dir() + "/battle2"}).get("ok", false), "engine starts ocean")
	for cmd in [&"month.begin", &"day.begin"]:
		t.ok(engine.send(cmd).get("ok", false), "engine " + str(cmd))
	for cmd in [&"campaign.battle_prepare", &"campaign.battle_reveal", &"campaign.battle_begin", &"campaign.battle_cmd", &"campaign.battle_finish"]:
		t.ok(engine.has_command(cmd), "engine advertises " + str(cmd))
	t.ok(engine.has_query(&"campaign.battle_preview") and engine.has_query(&"campaign.battle2"), "engine advertises battle queries")
	t.ok(engine.send(&"campaign.battle_prepare").get("ok", false), "prepare through the engine")
	t.eq(engine.query(&"campaign")["battle2"]["phase"], "lineup", "campaign query exposes battle2")
	t.no_leaks(engine.query(&"campaign")["battle2"]["lineup"], "lineup")
	t.ok(engine.send(&"campaign.battle_begin", {"companions": ["gourgaud", "dantes"], "troops": ["line_1", "jager_3"], "protagonist": true}).get("ok", false), "begin through the engine")
	# 指令预演（界面选骠骑兵朝向时用）：先下这条部署、不交火，返回冲锋落点和战果；状态不变
	var hash0 := engine.state_hash()
	var charge: Dictionary = engine.query(&"campaign.battle_preview", {"cmd": "deploy", "args": {"unit": "dantes", "col": 3, "row": 1, "facing": "right"}})
	t.eq([charge.get("ok"), charge.get("unit", {}).get("col"), charge.get("kills")], [true, 5, 4], "command preview: Dantes charges to F2 and kills the G2 stack")
	t.no_leaks(charge, "command preview")
	t.eq(engine.state_hash(), hash0, "command preview leaves the state alone")
	t.eq(engine.query(&"campaign.battle_preview", {"cmd": "deploy", "args": {"unit": "dantes", "col": 0, "row": 0, "facing": "right"}}).get("err"), "terrain", "command preview reports a refused command")
	t.eq(engine.query(&"campaign.battle_preview", {"cmd": 3}).get("err"), "bad_args", "command preview checks its arguments")
	t.ok(engine.send(&"campaign.battle_cmd", {"cmd": "deploy", "args": PLAN_B[1][0][1]}).get("ok", false), "deploy through the engine")
	var path: String = t.user_dir() + "/battle2/mid_battle.json"
	t.ok(engine.save_game(path).get("ok", false), "save mid battle")
	var loaded := CardEngine.new()
	t.ok(loaded.load_game(path).get("ok", false), "load mid battle")
	t.eq(loaded.state_hash(), engine.state_hash(), "engine load hash")
	t.eq(loaded.query(&"campaign.battle_preview"), engine.query(&"campaign.battle_preview"), "engine preview after load")
	for e in [engine, loaded]:
		for _i in range(12):
			var st: Dictionary = e.query(&"campaign")["battle2"]["view"]
			if st.get("phase", "") != "command":
				break
			for step in PLAN_B.get(int(st["turn"]), []):
				if int(st["turn"]) > 1:
					e.send(&"campaign.battle_cmd", {"cmd": step[0], "args": step[1]})
			e.send(&"campaign.battle_cmd", {"cmd": "fight", "args": {}})
		t.ok(e.send(&"campaign.battle_finish").get("ok", false), "finish through the engine")
	t.eq(loaded.state_hash(), engine.state_hash(), "engine continuation after load is deterministic")
	t.eq(engine.query(&"campaign")["battle2"]["result"]["outcome"], "victory", "engine battle won")


# ---------------------------------------------------------------- 部队

func _test_troops() -> void:
	var c := _new()
	var gold := int(c.state["rogue"]["coins"]["gold"])
	_send(c, "campaign.recruit", {"id": "troop:grenadier"})
	t.eq(int(c.state["rogue"]["coins"]["gold"]), gold - 2, "grenadier costs 2 gold")
	var last: Dictionary = c.state["rogue"]["army"]["troops"][-1]
	t.eq([last["id"], last["cls"], last["strength"]], ["grenadier_4", "grenadier", 3], "new troop joins the roster")
	t.ok(View._record_text(c, _ledger(c, "recruit_troop")[0]).find("{") < 0, "recruit text formatted")
	_reject(c, "campaign.recruit", {"id": "troop:dragoon"}, "bad_args", "unknown troop class")
	_send(c, "campaign.recruit", {"id": "troop:line"})
	_send(c, "campaign.recruit", {"id": "troop:jager"})
	_reject(c, "campaign.recruit", {"id": "troop:hussar"}, "insufficient_funds", "no gold left")
	for _i in range(3):
		c.state["rogue"]["army"]["troops"].append({"id": "pad_%d" % _i, "cls": "line", "strength": 3})
	c.state["rogue"]["coins"]["gold"] = 9
	_reject(c, "campaign.recruit", {"id": "troop:line"}, "roster_full", "troop cap")
	var d := _new()
	_advance(d)
	var classes: Array = []
	for tr in d.state["rogue"]["army"]["troops"]:
		classes.append(tr["cls"])
	classes.sort()
	t.eq(classes, ["artillery", "jager", "line", "line"], "entering Saint Helena tops up the chapter's starting troops")
	var e := _new(2)
	var e_classes: Array = []
	for tr in e.state["rogue"]["army"]["troops"]:
		e_classes.append(tr["cls"])
	t.eq(e_classes, ["line", "grenadier", "jager", "hussar", "artillery"], "starting at New Elba: that chapter's troops")
