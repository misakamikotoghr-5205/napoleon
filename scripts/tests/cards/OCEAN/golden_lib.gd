# 回归 golden 的录制与核对（A0；WORLD_MAP_DESIGN §6.1、§8.5、§15.1）。没有 class_name，用 preload。
#
# 两份 golden（scripts/tests/cards/OCEAN/golden/）：
#   ocean_routes.json      远洋单段书：test_campaign.gd 的五条结局路线（alliance / ghost / dark / tragedy / bittersweet），
#                          每条有效指令之后记一次 hash_v1(state)；开局（new_game 之后）记第 0 个。
#                          核对时按文件里录下的指令原样重放，不依赖路线生成逻辑。
#   battle_templates.json  战斗内核：现有 7 张模板 × 第 1–6 幕 × 种子 1–3，各跑一条固定的 60 步指令序列
#                          （test_battle_v2 的随机指令生成器），记 hash60（60 步之后）、result（之后一直交火到打完）、
#                          hash_end 和每步状态哈希串起来的 chain。状态哈希都先去掉 level、weather 两个键。
#
# 录制：DEHOUDANG_GOLDEN_WRITE=1 跑 test_golden.gd。只在基线（行为没变的提交）上录；改了行为就是回归，不是重录。
extends RefCounted

const Campaign = preload("res://scripts/cards/campaign/ocean_campaign.gd")
const R = preload("res://scripts/cards/campaign/battle/battle_rules.gd")

const ROUTES_PATH := "res://scripts/tests/cards/OCEAN/golden/ocean_routes.json"
const BATTLES_PATH := "res://scripts/tests/cards/OCEAN/golden/battle_templates.json"

## hash_v1 不看的 B1 新键（战斗状态、战果里）
const B1_KEYS := ["level", "weather", "loot", "ransom", "killed_kinds"]

## 录制时所在的提交（只作记录）
const BASELINE := "e331990f (behaviour = 0bf260eb)"

# ---------------------------------------------------------------- 远洋路线（与 test_campaign.gd 的 _route 相同）

const ENDINGS := ["alliance", "ghost", "dark", "tragedy", "bittersweet"]
const NEW_GAME := {"stage": 0, "seed": 1815}
const SUCCESS_ROUTE := [
	["prologue", "secure_passage"], ["scene01", "seal_evidence"],
	["scene02", "expose_sabre"], ["scene03", "audit_accounts"],
	["scene04", "prepare_escape"], ["scene05", "redeem_emperor"],
	["scene06", "establish_rations"], ["scene07", "expose_viper"],
	["scene08", "prepare_operation"], ["scene09", "capture_viper"],
	["scene10", "audit_alliance"], ["scene11", "expose_vigo"],
	["scene12", "cut_orichalcum"], ["finale", "close_ledger"],
]
const FALLBACK_CHOICES := [
	"buy_passage", "aid_longwood", "decline_sabre", "buy_supplies", "reserve_escape",
	"emergency_escape", "ration_cautiously", "secure_hostage", "prepare_withdrawal",
	"rescue_only", "accept_custody", "quarantine_vigo", "hold_orichalcum", "close_without_review",
]
const SKIP_BATTLE := [
	["campaign.battle_prepare", {}],
	["campaign.battle_begin", {"companions": [], "troops": [], "protagonist": false}],
	["campaign.battle_cmd", {"cmd": "retreat", "args": {}}],
	["campaign.battle_finish", {}],
]


## §6.1：单段书的回归哈希。去掉 v2 新增的段/局/地图/归档、rogue.tally 和 definition_hash；
## 每条 ledger 去掉 observation、battle（两者都是定义里的文字）；v 记成 1。
static func hash_v1(state: Dictionary) -> String:
	return JSON.stringify(v1_view(state), "", true).sha256_text()


## hash_v1 再把状态里所有带非 ASCII 字符的字符串（玩家看得见的字：催逼标题、战场名、战报、敌兵名、羁绊说明……）
## 换成 "*"。只改字、不改机制的提交（C 的去当铺）应当让它保持不变；hash_v1 本身按 §6.1 仍会看到这些字。
static func hash_v1_textless(state: Dictionary) -> String:
	return JSON.stringify(textless(v1_view(state)), "", true).sha256_text()


static func series_hash(series: String, state: Dictionary) -> String:
	return hash_v1_textless(state) if series == "hash_v1_textless" else hash_v1(state)


## hash_v1 求哈希之前的那份状态（深拷贝）
static func v1_view(state: Dictionary) -> Dictionary:
	var s: Dictionary = state.duplicate(true)
	for key in ["segment", "run", "map", "archive", "definition_hash"]:
		s.erase(key)
	if typeof(s.get("rogue")) == TYPE_DICTIONARY:
		(s["rogue"] as Dictionary).erase("tally")
		# B1 给战斗状态和战果加的新键（§9.4：state 的 level/weather/loot/ransom，result 的 killed_kinds/loot/ransom）不算 v1
		var b2 = s["rogue"].get("battle2", {})
		if typeof(b2) == TYPE_DICTIONARY:
			for part in ["state", "result"]:
				if typeof(b2.get(part)) == TYPE_DICTIONARY:
					for key in B1_KEYS:
						(b2[part] as Dictionary).erase(key)
	if typeof(s.get("ledger")) == TYPE_ARRAY:
		for row in s["ledger"]:
			if typeof(row) == TYPE_DICTIONARY:
				(row as Dictionary).erase("observation")
				(row as Dictionary).erase("battle")
	s["v"] = 1
	return s


## 深拷贝；带非 ASCII 字符的字符串值换成 "*"（键不动）
static func textless(v: Variant) -> Variant:
	match typeof(v):
		TYPE_STRING, TYPE_STRING_NAME:
			var text := str(v)
			return "*" if text.to_utf8_buffer().size() != text.length() else text
		TYPE_DICTIONARY:
			var d := {}
			for k in v:
				d[k] = textless(v[k])
			return d
		TYPE_ARRAY:
			var a: Array = []
			for item in v:
				a.append(textless(item))
			return a
	return v


static func new_campaign() -> RefCounted:
	var campaign := Campaign.new()
	var res: Dictionary = campaign.new_game(NEW_GAME.duplicate(true))
	if not bool(res.get("ok", false)):
		return null
	return campaign


## 按 test_campaign.gd 的路线逻辑跑一条结局路线：{ok, err, commands:[[cmd,args]…], hash_v1:[开局, 每条有效指令后…], ending}
static func record_route(ending: String) -> Dictionary:
	var out := {"ok": true, "err": "", "commands": [], "hash_v1": [], "hash_v1_textless": [], "ending": "", "scenes": []}
	var campaign := new_campaign()
	if campaign == null:
		return {"ok": false, "err": "new_game failed"}
	out["hash_v1"].append(hash_v1(campaign.state))
	out["hash_v1_textless"].append(hash_v1_textless(campaign.state))
	for step in SUCCESS_ROUTE:
		for _phase in range(4):
			if campaign.state["phase"] in ["day", "game_over"]:
				break
			_route_send(out, campaign, "campaign.wait", {})
		if campaign.state["phase"] == "game_over":
			break
		var scene: Dictionary = campaign.scene()
		out["scenes"].append(str(scene["id"]))
		for command in SKIP_BATTLE:
			_route_send(out, campaign, command[0], command[1])
		if ending != "bittersweet":
			for appraisal in scene["appraisals"]:
				_route_send(out, campaign, "campaign.appraise", {"id": appraisal["id"]})
		if scene["id"] == "scene01":
			_route_send(out, campaign, "campaign.visit", {"place": "town"})
			_route_send(out, campaign, "campaign.demand", {"id": "medicine", "action": "fulfill"})
			_route_send(out, campaign, "campaign.demand", {"id": "bond", "action": "fulfill"})
		if ending == "dark" and scene["id"] in ["scene10", "scene11"]:
			_route_send(out, campaign, "campaign.choose", {"choice": "theft_treasure" if scene["id"] == "scene10" else "counterfeit_trade"})
		if ending == "ghost" and scene["id"] == "scene12":
			_route_send(out, campaign, "campaign.choose", {"choice": "choose_autonomy"})
		if ending == "alliance" and scene["id"] == "scene12":
			_route_send(out, campaign, "campaign.fund", {"support": true})
		var choice: String = "accept_vigo_decoy" if ending == "tragedy" and scene["id"] == "scene11" else step[1]
		if ending == "bittersweet":
			choice = FALLBACK_CHOICES[(out["scenes"] as Array).size() - 1]
		_route_send(out, campaign, "campaign.choose", {"choice": choice})
	out["ending"] = str(campaign.state.get("ending", ""))
	return out


static func _route_send(out: Dictionary, campaign: RefCounted, cmd: String, args: Dictionary) -> void:
	var res: Dictionary = campaign.send(StringName(cmd), args)
	if not bool(res.get("ok", false)):
		if bool(out["ok"]):
			out["ok"] = false
			out["err"] = "%s %s at %s: %s" % [cmd, args, campaign.scene().get("id", ""), res]
		return
	out["commands"].append([cmd, args.duplicate(true)])
	out["hash_v1"].append(hash_v1(campaign.state))
	out["hash_v1_textless"].append(hash_v1_textless(campaign.state))


static func record_routes() -> Dictionary:
	var routes := {}
	for ending in ENDINGS:
		var row := record_route(ending)
		routes[ending] = {"ok": row["ok"], "err": row["err"], "ending": row.get("ending", ""),
			"commands": row.get("commands", []), "hash_v1": row.get("hash_v1", []),
			"hash_v1_textless": row.get("hash_v1_textless", [])}
	return {
		"_doc": ["Golden for the single-segment ocean book (WORLD_MAP_DESIGN 6.1 / 15.1). Recorded by scripts/tests/cards/OCEAN/test_golden.gd with DEHOUDANG_GOLDEN_WRITE=1.",
			"Each route replays commands[i] on new_game(new_game) and must give hash_v1[i + 1]; hash_v1[0] is the state right after new_game.",
			"hash_v1: drop segment/run/map/archive/definition_hash and rogue.tally, drop observation/battle from every ledger row, set v = 1, JSON.stringify(state, '', true).sha256_text().",
			"hash_v1_textless: hash_v1 with every string value that has a non-ASCII character replaced by '*' (player-visible text still inside the state: demand titles, battle name/log/enemy and unit names, bond texts). A text-only change keeps it equal."],
		"baseline": BASELINE, "new_game": NEW_GAME, "routes": routes,
	}


## 重放一条录下的路线，逐步比较 series（"hash_v1" 或 "hash_v1_textless"）：{ok, at, want, got, err, ending}；
## at = 第几个哈希不符（0 是开局）
static func verify_route(row: Dictionary, new_game: Dictionary, series: String = "hash_v1") -> Dictionary:
	var campaign := Campaign.new()
	var res: Dictionary = campaign.new_game(new_game.duplicate(true))
	if not bool(res.get("ok", false)):
		return {"ok": false, "at": 0, "err": "new_game: %s" % res, "want": "", "got": ""}
	var hashes: Array = row.get(series, [])
	var commands: Array = row.get("commands", [])
	if hashes.size() != commands.size() + 1:
		return {"ok": false, "at": -1, "err": "golden has %d %s for %d commands" % [hashes.size(), series, commands.size()], "want": "", "got": ""}
	var got := series_hash(series, campaign.state)
	if got != str(hashes[0]):
		return {"ok": false, "at": 0, "err": "hash after new_game", "want": str(hashes[0]), "got": got}
	for i in commands.size():
		var command: Array = commands[i]
		res = campaign.send(StringName(str(command[0])), _int_tree(command[1]))
		if not bool(res.get("ok", false)):
			return {"ok": false, "at": i + 1, "err": "%s %s rejected: %s" % [command[0], command[1], res], "want": str(hashes[i + 1]), "got": ""}
		got = series_hash(series, campaign.state)
		if got != str(hashes[i + 1]):
			return {"ok": false, "at": i + 1, "err": "%s %s" % [command[0], command[1]], "want": str(hashes[i + 1]), "got": got}
	return {"ok": true, "at": commands.size(), "err": "", "want": "", "got": "", "ending": str(campaign.state.get("ending", ""))}


# ---------------------------------------------------------------- 战斗模板（§8.5）

## 「现有」的 7 张模板；B 只追加新模板，这 7 张的 golden 必须不变
const TEMPLATES := ["arcole", "elite_a", "major_a", "rivoli", "skirmish_a", "skirmish_b", "skirmish_c"]
const ACTS := [1, 2, 3, 4, 5, 6]
const SEEDS := [1, 2, 3]
const STEPS := 60
## 60 步之后最多再交火这么多次把仗打完（模板回合上限 ≤ 12）
const FINISH_FIGHTS := 40
## 状态哈希先去掉 B 新增的这两个键
const NEW_KEYS := ["level", "weather"]


static func battle_setup(seed_value: int, act: int) -> Dictionary:
	var k := seed_value + act
	return {"seed": seed_value, "act": act, "cp_bonus": k % 5, "protagonist": {"enabled": k % 3 != 0},
		"roster": [
			{"id": "milon", "cls": "line", "name": "Milon", "hp": 16, "atk": 5, "cost": 5, "skill": "raise_flag", "tags": ["italy"], "fated": k % 4 == 0},
			{"id": "corso", "cls": "jager", "name": "Corso", "cost": 3, "skill": "mark_target", "tags": ["italy", "quartermaster"], "scarred": k % 5 == 0},
			{"id": "baptiste", "cls": "engineer", "name": "Baptiste", "cost": 3, "skill": "fortify", "tags": ["italy", "quartermaster"]},
			{"id": "marie", "cls": "medic", "name": "Marie", "cost": 3, "tags": ["quartermaster", "family"]}],
		"troops": [{"id": "bat", "cls": "artillery"}, {"id": "gren", "cls": "grenadier"}, {"id": "gren2", "cls": "grenadier"},
			{"id": "hus", "cls": "hussar"}, {"id": "drum", "cls": "drummer"}, {"id": "line", "cls": "line"}],
		"bonds_trust": {"hero|milon": k % 4}}


static func battle_hash(s: Dictionary, text: bool = true) -> String:
	var copy: Dictionary = s.duplicate(true)
	for key in NEW_KEYS:
		copy.erase(key)
	return JSON.stringify(copy if text else textless(copy), "", true).sha256_text()


## 一局：{template, act, seed, steps, finish_fights, hash60, result, hash_end, chain, *_textless}
static func run_battle(tid: String, act: int, seed_value: int) -> Dictionary:
	var s: Dictionary = R.new_battle(tid, battle_setup(seed_value, act))
	if s.has("error"):
		return {"template": tid, "act": act, "seed": seed_value, "error": str(s["error"])}
	var x: int = ((TEMPLATES.find(tid) * 18 + (act - 1) * 3 + (seed_value - 1)) + 1) * 2654435761 & 0xFFFFFFFF
	var cmds := 0
	var since_fight := 0
	var chain := battle_hash(s)
	var chain_textless := battle_hash(s, false)
	while s["phase"] == "command" and cmds < STEPS:
		x = xs(x ^ (cmds * 40503))
		var pick: Array = random_cmd(s, x)
		if since_fight >= 10:
			pick = ["fight", {}]
		if (x >> 22) % 300 == 0:
			pick = ["retreat", {}]
		var res: Dictionary = R.apply(s, pick[0], pick[1])
		cmds += 1
		since_fight = 0 if pick[0] == "fight" else since_fight + 1
		var step := "|" + str(pick[0]) + ":" + str(res.get("ok", false)) + ":" + str(res.get("err", "")) + ":"
		chain = (chain + step + battle_hash(s)).sha256_text()
		chain_textless = (chain_textless + step + battle_hash(s, false)).sha256_text()
	var hash60 := battle_hash(s)
	var extra := 0
	while s["phase"] == "command" and extra < FINISH_FIGHTS:
		R.apply(s, "fight", {})
		extra += 1
	return {"template": tid, "act": act, "seed": seed_value, "steps": cmds, "finish_fights": extra,
		"hash60": hash60, "result": JSON.stringify(R.result(s)), "hash_end": battle_hash(s), "chain": chain,
		"result_textless": JSON.stringify(textless(R.result(s))), "hash_end_textless": battle_hash(s, false), "chain_textless": chain_textless}


static func record_battles() -> Dictionary:
	var runs: Array = []
	for tid in TEMPLATES:
		for act in ACTS:
			for seed_value in SEEDS:
				runs.append(run_battle(tid, act, seed_value))
	return {
		"_doc": ["Golden for battle_rules.gd on the 7 pre-existing templates (WORLD_MAP_DESIGN 8.5 / 15.1). Recorded by scripts/tests/cards/OCEAN/test_golden.gd with DEHOUDANG_GOLDEN_WRITE=1.",
			"Each run: R.new_battle(template, golden_lib.battle_setup(seed, act)), then up to 60 commands from test_battle_v2's random command generator (golden_lib.random_cmd), then fight until over (at most 40).",
			"hash60 / hash_end: JSON.stringify(state without level/weather, '', true).sha256_text(); result: JSON.stringify(R.result(state)); chain: running sha256 over every step's command, ok, err and state hash.",
			"*_textless: the same with every string value that has a non-ASCII character replaced by '*' (battle name, log lines, unit and enemy names, bond texts), for text-only changes."],
		"baseline": BASELINE, "steps": STEPS, "runs": runs,
	}


## test_battle_v2.gd 的 _xs（xorshift32）
static func xs(x: int) -> int:
	x = x & 0xFFFFFFFF
	if x == 0:
		x = 1
	x = (x ^ (x << 13)) & 0xFFFFFFFF
	x = x ^ (x >> 17)
	x = (x ^ (x << 5)) & 0xFFFFFFFF
	return x


## test_battle_v2.gd 的 _random_cmd（逐字照抄；那份文件不许改，所以这里留一份）
static func random_cmd(s: Dictionary, x: int) -> Array:
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


# ---------------------------------------------------------------- 文件

static func read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var parsed := JSON.new()
	if parsed.parse(FileAccess.get_file_as_string(path)) != OK:
		return null
	return parsed.data


static func write_json(path: String, value: Variant) -> bool:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(value, "  ", true) + "\n")
	file.close()
	return true


## JSON 读回来的数字都是浮点；整数值转回 int（指令参数要求整数）
static func _int_tree(v: Variant) -> Variant:
	match typeof(v):
		TYPE_FLOAT:
			return int(v) if float(int(v)) == v else v
		TYPE_DICTIONARY:
			var d := {}
			for k in v:
				d[k] = _int_tree(v[k])
			return d
		TYPE_ARRAY:
			var a: Array = []
			for item in v:
				a.append(_int_tree(item))
			return a
	return v
