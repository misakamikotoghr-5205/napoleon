class_name OceanCampaign
extends RefCounted
## Deterministic campaign rules. Presentation, persistence and real-world procedures
## are deliberately outside this model; appraisals reveal fictional evidence only.
## 泛化成「书 → 段 → 章 → 场」（WORLD_MAP_DESIGN §6）：book 是 RunBook 的书包（只在内存里），definition 是当前段的定义。
## 单段书 ocean_pawn（load_definition）没有地图、没有 rules，一切回落 run_ocean_rules.gd，每一步的 hash_v1 等于 golden。

const DEFAULT_DEFINITION := "res://data/campaigns/ocean_pawn.json"
const RogueRules = preload("res://scripts/cards/campaign/ocean_rogue_rules.gd")
const Battle2 = preload("res://scripts/cards/campaign/ocean_battle2.gd")
const BattleRules = preload("res://scripts/cards/campaign/battle/battle_rules.gd")
const RunBook = preload("res://scripts/cards/campaign/run/run_book.gd")
const RunConditions = preload("res://scripts/cards/campaign/run/run_conditions.gd")
const RunOceanRules = preload("res://scripts/cards/campaign/run/run_ocean_rules.gd")
const RunCarry = preload("res://scripts/cards/campaign/run/run_carry.gd")
const RunBranchStart = preload("res://scripts/cards/campaign/run/run_branch_start.gd")
const MapRules = preload("res://scripts/cards/campaign/map/map_rules.gd")
const CompanionRules = preload("res://scripts/cards/campaign/companion_rules.gd")
## 不算结局的收场：主角阵亡的讣告（战斗规则 v2，见 ocean_battle2.gd）
const OBITUARY := "obituary"
const METRICS := ["treasury", "morale", "heat", "vitality", "construction", "exploration"]
const PHASES := ["month_open", "morning", "day", "settle", "year_jump", "game_over"]
const SIGNS := ["red", "white", "black"]
const MAX_INTEGER := 1000000000000
const PERFECT_FLAGS := RunOceanRules.PERFECT_FLAGS
## 远洋单段书 scene01 那两条催逼的标题（远洋内置规则没有文字，标题照旧写在这里）
const OCEAN_DEMAND_TITLES := {"medicine": "朗伍德庄园的冬季急需", "bond": "总督查账：一千先令治安保证金"}
const FIELDS_V1 := ["v", "campaign", "definition_hash", "seed", "scene_index", "phase", "day", "daily_applied_day", "sign", "metrics", "flags",
	"inventory", "clues", "used_actions", "ledger", "ending", "end_reason", "chapter_balances", "demands", "open_panel", "rogue"]
const FIELDS_V2 := ["segment", "run", "map", "archive"]
const OCEAN_ENDINGS := ["alliance", "ghost", "dark", "tragedy", "bittersweet", "bankruptcy", "loss", "blockade"]
const RUN_KEYS := ["book", "volume", "path", "level_offset", "chapter_ord", "stats", "start", "events_seen", "fate_once", "dice"]
## 归档里的账目只留最后这么多条（外加一条 summary）
const ARCHIVE_LEDGER := 40
const COMMANDS_MAP := ["campaign.map_roll", "campaign.map_card", "campaign.map_move", "campaign.map_enter", "campaign.map_choose",
	"campaign.map_appraise", "campaign.map_scout", "campaign.map_build", "campaign.map_pay", "campaign.map_muster"]

var definition: Dictionary = {}
var state: Dictionary = {}
## 书包（RunBook.builtin / RunBook.load_bundle）：defs、maps、events、companions、raw、hash……
var book: Dictionary = {}
var _definition_hash := ""
var _cache: Dictionary = {}


## 单段书 ocean_pawn（旧接口，测试和 bridge 都在用）
func load_definition(path: String = DEFAULT_DEFINITION) -> Dictionary:
	var read := RunBook.read_json(path)
	if not bool(read["ok"]):
		return _fail(str(read["err"]))
	if typeof(read["data"]) != TYPE_DICTIONARY:
		return _fail("definition_invalid")
	var candidate: Dictionary = read["data"]
	if candidate.get("id") != "ocean_pawn" or not _valid_definition(candidate):
		return _fail("definition_invalid")
	definition = candidate
	_definition_hash = JSON.stringify(definition, "", true).sha256_text()
	book = RunBook.builtin(definition, _definition_hash)
	_cache = {}
	state = {}
	return _ok()


## 多段书（napoleon、fixtures/mini_book）：读全书、逐段校验、全书校验（§8.2、R1–R12……），有错就整本拒绝
func load_book(path: String) -> Dictionary:
	var loaded := RunBook.load_bundle(path)
	if not bool(loaded["ok"]):
		return {"ok": false, "err": str(loaded["err"]), "path": str(loaded.get("path", path))}
	var bundle: Dictionary = loaded["book"]
	for seg in bundle["defs"]:
		if not _valid_definition(bundle["defs"][seg]):
			return {"ok": false, "err": "definition_invalid", "segment": seg}
	var checked := RunBook.validate(bundle)
	if not (checked["errors"] as Array).is_empty():
		return {"ok": false, "err": "book_invalid", "errors": checked["errors"]}
	book = bundle
	_definition_hash = str(bundle["hash"])
	definition = bundle["defs"][str(bundle["start"])]
	_cache = {}
	state = {}
	return _ok()


func is_builtin() -> bool:
	return bool(book.get("builtin", true))


func new_game(opts: Dictionary = {}) -> Dictionary:
	for key in opts:
		if key not in ["seed", "stage", "campaign", "book", "segment", "entry"]:
			return _fail("bad_args")
	if opts.has("entry") and (typeof(opts["entry"]) != TYPE_STRING or opts["entry"] != "branch_point" or opts.has("stage") or opts.has("segment")):
		return _fail("bad_args")
	if typeof(opts.get("seed", 1)) != TYPE_INT or typeof(opts.get("stage", 0)) != TYPE_INT:
		return _fail("bad_args")
	if opts.has("campaign") and opts["campaign"] not in ["ocean_pawn", "napoleon"]:
		return _fail("bad_args")
	for key in ["book", "segment"]:
		if opts.has(key) and (typeof(opts[key]) != TYPE_STRING or str(opts[key]).is_empty()):
			return _fail("bad_args")
	var want_book := str(opts.get("book", RunBook.NAPOLEON if str(opts.get("campaign", "")) == "napoleon" else ""))
	if want_book != "":
		if is_builtin() or str(book.get("path", "")) != want_book:
			var lb := load_book(want_book)
			if not lb["ok"]:
				return lb
	elif str(opts.get("campaign", "")) == "ocean_pawn" and not is_builtin() or definition.is_empty():
		var loaded := load_definition()
		if not loaded["ok"]:
			return loaded
	var seg := str(opts.get("segment", book.get("start", "ocean")))
	var opening := RunBranchStart.locate(book) if opts.get("entry", "") == "branch_point" else {}
	if opts.has("entry") and opening.is_empty():
		return _fail("bad_args")
	if not book.get("defs", {}).has(seg):
		return _fail("bad_args")
	definition = book["defs"][seg]
	_cache = {}
	var stage: int = int(opening["stage"]) if not opening.is_empty() else int(opts.get("stage", 0))
	if stage < 0 or stage >= definition["chapters"].size() or opts.get("seed", 1) < -MAX_INTEGER or opts.get("seed", 1) > MAX_INTEGER:
		return _fail("bad_args")
	var selected: Dictionary = definition["chapters"][stage]
	var first_scene: int = int(opening["scene_index"]) if not opening.is_empty() else _scene_index(str(selected["scene_ids"][0]))
	var branch_row := RunBook.branch(book, seg)
	if stage == 0 and seg != str(book.get("start", seg)) and str(branch_row.get("entry", "")) != "":
		first_scene = _scene_index(str(branch_row["entry"]))
		selected = _chapter_of(str(definition["scenes"][first_scene]["chapter"]))
	# Limited releases use the same boundary for play and explicit chapter starts.
	# Existing full books keep their historical developer preview entries.
	if bool(book.get("raw", {}).get("enforce_chapter_limits", false)) and int(selected.get("volume", 1)) > int(book.get("volume", 1)):
		return _fail("bad_args")
	var metrics: Dictionary = definition["initial"].duplicate(true)
	metrics["treasury"] = selected["treasury_start"]
	var debug := opening.is_empty() and not is_builtin() and (seg != str(book.get("start", seg)) or stage > 0)
	state = {
		"v": 2, "campaign": str(definition["id"]), "definition_hash": _definition_hash,
		"seed": opts.get("seed", 1), "scene_index": first_scene, "phase": "month_open",
		"day": 1, "daily_applied_day": 0, "sign": "white", "metrics": metrics,
		"flags": {}, "inventory": [], "clues": {}, "used_actions": {}, "ledger": [],
		"ending": "", "end_reason": "", "chapter_balances": {}, "demands": [], "open_panel": "",
		"rogue": {},
		"segment": seg,
		"run": {"book": str(book.get("id", "ocean_pawn")), "volume": int(book.get("volume", 1)), "path": [seg],
			"level_offset": int(branch_row.get("level_offset", 0)) if seg != str(book.get("start", seg)) else 0,
			"chapter_ord": stage, "stats": {"battles": 0, "wins": 0, "boss_wins": 0},
			"start": {"book": str(book.get("path", "")), "segment": seg, "stage": stage, "seed": opts.get("seed", 1), "carry": "branch_point" if not opening.is_empty() else ("debug" if debug else "")},
			"events_seen": [], "fate_once": [], "dice": 0},
		"map": {}, "archive": {},
	}
	_enter_scene()
	_record("start", {"chapter": selected["id"], "currency": selected["currency"], "treasury": metrics["treasury"]})
	if debug:
		RunCarry.debug(self, seg, stage)
	elif not opening.is_empty():
		RunCarry.debug(self, "branch_point", 0)
	RogueRules.apply_opening_hooks(self)
	_open_map(str(selected["id"]))
	if not opening.is_empty() and MapRules.enabled(self):
		RunBranchStart.place(self, opening)
	CompanionRules.on_scene(self)
	return _ok()


func send(cmd: StringName, args: Dictionary = {}) -> Dictionary:
	if state.is_empty() or state.get("phase", "") == "game_over":
		return _fail("bad_phase")
	# Run every command against a private candidate. Even a failed multi-step
	# choice, payment or restore leaves the previous state byte-for-byte intact.
	var previous := state
	var previous_definition := definition
	state = state.duplicate(true)
	var result: Dictionary
	match str(cmd):
		"campaign.appraise": result = _appraise(args)
		"campaign.choose": result = _choose(args)
		"campaign.sign": result = _sign(args)
		"campaign.wait": result = _wait(args)
		"campaign.visit": result = _visit(args)
		"campaign.trade": result = _trade(args)
		"campaign.build": result = _project(args, "build")
		"campaign.explore": result = _project(args, "explore")
		"campaign.fund": result = _fund(args)
		"campaign.demand": result = _demand(args)
		"campaign.roll_dice", "campaign.pick_route", "campaign.activity", "campaign.schedule", \
		"campaign.recruit", "campaign.promote", "campaign.companion_duty", "campaign.use_prop", "campaign.big_fate", \
		"campaign.battle_prepare", "campaign.battle_reveal", "campaign.battle_begin", \
		"campaign.battle_cmd", "campaign.battle_finish":
			result = RogueRules.handle(self, str(cmd), args)
		_:
			if str(cmd) in COMMANDS_MAP:
				result = MapRules.handle(self, str(cmd), args)
			else:
				result = _fail("bad_args")
	if not result["ok"]:
		state = previous
		if definition != previous_definition:
			definition = previous_definition
			_cache = {}
	else:
		_check_failure()
	return result


func scene() -> Dictionary:
	if state.is_empty() or definition.is_empty():
		return {}
	return definition["scenes"][state["scene_index"]].duplicate(true)


func chapter() -> Dictionary:
	var current := scene()
	if current.is_empty():
		return {}
	for entry in definition["chapters"]:
		if entry["id"] == current["chapter"]:
			return entry.duplicate(true)
	return {}


func snapshot() -> Dictionary:
	return state.duplicate(true)


func restore(saved: Dictionary) -> Dictionary:
	if definition.is_empty():
		return _fail("definition_missing")
	if not RunBook.integer_tree(saved):
		return _fail("save_invalid")
	var candidate: Dictionary = RunBook.normalise(saved)
	_migrate(candidate)
	var previous_definition := definition
	var seg := str(candidate.get("segment", ""))
	if typeof(candidate.get("segment")) == TYPE_STRING and book.get("defs", {}).has(seg):
		definition = book["defs"][seg]
		_cache = {}
	if not _valid_state(candidate):
		definition = previous_definition
		_cache = {}
		return _fail("save_invalid")
	# 战斗 v2 的状态读回来交给规则内核整理（整数化、校验版本）
	var b2: Variant = candidate.get("rogue", {}).get("battle2", {})
	if typeof(b2) == TYPE_DICTIONARY and typeof(b2.get("state")) == TYPE_DICTIONARY and not (b2["state"] as Dictionary).is_empty():
		var loaded: Dictionary = BattleRules.load_state(b2["state"])
		if loaded.has("error"):
			definition = previous_definition
			_cache = {}
			return _fail("save_invalid")
		b2["state"] = loaded
	state = candidate
	return _ok()


## 旧存档：战斗 v2 之前的没有 army / battle2；v1（单段书）没有 segment / run / map / archive / rogue.tally
func _migrate(candidate: Dictionary) -> void:
	var rogue: Variant = candidate.get("rogue")
	if typeof(rogue) != TYPE_DICTIONARY or (rogue as Dictionary).is_empty() or typeof(candidate.get("scene_index")) != TYPE_INT:
		return
	var index: int = candidate["scene_index"]
	if index < 0 or index >= definition["scenes"].size():
		return
	Battle2.migrate(rogue, str(definition["scenes"][index]["chapter"]))
	if candidate.get("v") != 1 or not is_builtin() or candidate.get("campaign") != "ocean_pawn":
		return
	var ord := 0
	for i in definition["chapters"].size():
		if str(definition["chapters"][i]["id"]) == str(definition["scenes"][index]["chapter"]):
			ord = i
	candidate["v"] = 2
	candidate["segment"] = "ocean"
	candidate["run"] = {"book": "ocean_pawn", "volume": 1, "path": ["ocean"], "level_offset": 0, "chapter_ord": ord,
		"stats": {"battles": 0, "wins": 0, "boss_wins": 0},
		"start": {"book": "", "segment": "ocean", "stage": ord, "seed": candidate.get("seed", 1), "carry": "migrated"},
		"events_seen": [], "fate_once": [], "dice": 0}
	candidate["map"] = {}
	candidate["archive"] = {}
	if not (rogue as Dictionary).has("tally"):
		rogue["tally"] = {"gold": 0, "supply": 0, "medal": 0, "intel": 0}


func hash() -> String:
	return JSON.stringify(state, "", true).sha256_text()


func available_choices() -> Array:
	var choices: Array = []
	if state.is_empty():
		return choices
	for entry in scene().get("choices", []):
		var row: Dictionary = entry.duplicate(true)
		var reason := _choice_error(row)
		row["available"] = reason == ""
		row["reason"] = reason
		if reason in ["branch_locked", "locked"]:
			row["cond"] = _choice_cond_reason(row)
		choices.append(row)
	return choices


# ================================================================ 书与规则（MapRules / Battle2 / RogueRules 也用）

## 当前段的有效规则（rules.* 缺省回落远洋内置）
func rules() -> Dictionary:
	var key := "rules:" + str(definition.get("id", ""))
	if not _cache.has(key):
		_cache[key] = RunOceanRules.rules(definition)
	return _cache[key]


func _demand_specs() -> Dictionary:
	var key := "demands:" + str(definition.get("id", ""))
	if not _cache.has(key):
		_cache[key] = RunOceanRules.demand_specs(definition)
	return _cache[key]


func event_def(id: String) -> Dictionary:
	if not _cache.has("events"):
		_cache["events"] = RunBook.all_events(book)
	return _cache["events"].get(id, {})


func roster() -> Dictionary:
	var key := "roster:" + str(state.get("segment", book.get("start", "ocean")))
	if not _cache.has(key):
		_cache[key] = RogueRules.build_roster(self)
	return _cache[key]


func start_troops(chapter_id: String) -> Array:
	var own = book.get("raw", {}).get("start_troops", {}).get(chapter_id) if not is_builtin() else null
	if typeof(own) == TYPE_ARRAY:
		return own
	return Battle2.data().get("start_troops", {}).get(chapter_id, [])


func add_coin(coin_id: String, delta: int) -> void:
	RogueRules._add_coin(state["rogue"], coin_id, delta)


func route_reward(route: String) -> void:
	RogueRules.route_reward(self, route)


## 没有在打的仗、没有待处理的大命运、地图上没有没打完的遭遇
func battle_idle() -> bool:
	var rogue: Dictionary = state.get("rogue", {})
	if bool(rogue.get("big_fate", {}).get("pending", false)):
		return false
	if str(rogue.get("battle2", {}).get("phase", "none")) == "active":
		return false
	return not MapRules.enabled(self) or (state["map"].get("encounter", {}) as Dictionary).is_empty()


func prepare_battle() -> Dictionary:
	return Battle2.prepare(self, {})


func scene_battle(scene_id: String) -> Dictionary:
	return MapRules.scene_battle(book, str(state.get("segment", "")), scene_id, int(state.get("run", {}).get("level_offset", 0)))


## 剧情、事件共用的抉择效果：指标、旗标、物品、rogue（币、道具、伙伴、部队、伤愈、信赖）
func apply_choice(entry: Dictionary, pick: Array = []) -> String:
	_apply_effects(entry.get("effects", {}))
	for flag in entry.get("flags", []):
		state["flags"][flag] = true
	for flag in entry.get("remove_flags", []):
		state["flags"].erase(flag)
	for item in entry.get("items", []):
		if item not in state["inventory"]:
			state["inventory"].append(item)
	for item in entry.get("remove_items", []):
		state["inventory"].erase(item)
	if typeof(entry.get("rogue")) == TYPE_DICTIONARY and not (entry["rogue"] as Dictionary).is_empty():
		return RogueRules.apply_rogue(self, entry["rogue"], pick)
	return ""


func _open_map(chapter_id: String) -> void:
	if is_builtin() or OS.get_environment("DEHOUDANG_NO_MAP") == "1" or MapRules.sheet_of(book, str(state["segment"]), chapter_id).is_empty():
		state["map"] = {}
		return
	MapRules.open_sheet(self, chapter_id)


func _chapter_of(chapter_id: String) -> Dictionary:
	for entry in definition["chapters"]:
		if str(entry["id"]) == chapter_id:
			return entry
	return {}


# ================================================================ 剧情

func _appraise(args: Dictionary) -> Dictionary:
	if not _args(args, {"id": TYPE_STRING}):
		return _fail("bad_args")
	if state["phase"] != "day":
		return _fail("bad_phase")
	var gate := MapRules.story_gate(self)
	if gate != "":
		return _fail(gate)
	var current := scene()
	for appraisal in current["appraisals"]:
		if appraisal["id"] != args["id"]:
			continue
		var clues: Array = state["clues"].get(current["id"], [])
		if args["id"] in clues:
			return _fail("already_used")
		clues.append(args["id"])
		state["clues"][current["id"]] = clues
		_record("appraisal", {"id": args["id"], "observation": appraisal["observation"]})
		return {"ok": true, "err": "", "observation": appraisal["observation"]}
	return _fail("bad_args")


func _choose(args: Dictionary) -> Dictionary:
	var pick: Array = []
	if args.size() == 2 and typeof(args.get("pick")) == TYPE_ARRAY and typeof(args.get("choice")) == TYPE_STRING:
		pick = args["pick"]
		args = {"choice": args["choice"]}
	if not _args(args, {"choice": TYPE_STRING}):
		return _fail("bad_args")
	for entry in scene()["choices"]:
		if entry["id"] != args["choice"]:
			continue
		var error := _choice_error(entry)
		if error != "":
			return _fail(error)
		_apply_effects(entry.get("effects", {}))
		for flag in entry.get("flags", []):
			state["flags"][flag] = true
		for flag in entry.get("remove_flags", []):
			state["flags"].erase(flag)
		for item in entry.get("items", []):
			if item not in state["inventory"]:
				state["inventory"].append(item)
		for item in entry.get("remove_items", []):
			state["inventory"].erase(item)
		if typeof(entry.get("rogue")) == TYPE_DICTIONARY and not (entry["rogue"] as Dictionary).is_empty():
			var err := RogueRules.apply_rogue(self, entry["rogue"], pick)
			if err != "":
				return _fail(err)
		_use("choice:" + str(entry["id"]))
		_record("choice", {"id": entry["id"], "effects": entry.get("effects", {}).duplicate(true)})
		CompanionRules.after_choice(self, str(scene().get("id", "")))
		_check_failure()
		if state["phase"] == "game_over":
			return _ok()
		if str(entry.get("branch", "")) != "":
			_switch_segment(str(entry["branch"]), "choice:" + str(entry["id"]))
			return _ok()
		for _d in range(int(entry.get("days", 0))):
			_tick_day()
			if state["phase"] == "game_over":
				return _ok()
		if entry.get("advance", true):
			_advance_scene()
		return _ok()
	return _fail("bad_args")


func _choice_error(choice: Dictionary) -> String:
	if state["phase"] != "day":
		return "bad_phase"
	var gate := MapRules.story_gate(self)
	if gate != "":
		return gate
	if _used("choice:" + str(choice["id"])):
		return "already_used"
	var flags: Array = choice.get("flags", [])
	for group in rules()["exclusive_flags"]:
		var touches := false
		var taken := false
		for f in group:
			touches = touches or f in flags
			taken = taken or bool(state["flags"].get(f, false))
		if touches and taken:
			return "already_used"
	var clues: Array = state["clues"].get(scene()["id"], [])
	for clue in choice.get("requires_clues", []):
		if clue not in clues:
			return "missing_clue"
	for flag in choice.get("requires_flags", []):
		if not state["flags"].get(flag, false):
			return "missing_flag"
	if _choice_cond_reason(choice) != "":
		return "branch_locked" if str(choice.get("branch", "")) != "" else "locked"
	for item in choice.get("remove_items", []):
		if item not in state["inventory"]:
			return "missing_item"
	if int(state["metrics"]["treasury"]) + int(choice.get("effects", {}).get("treasury", 0)) < 0:
		return "insufficient_funds"
	var coins: Dictionary = choice.get("rogue", {}).get("coins", {}) if typeof(choice.get("rogue")) == TYPE_DICTIONARY else {}
	for c in coins:
		if int(state["rogue"]["coins"].get(c, 0)) + int(coins[c]) < 0:
			return "insufficient_funds"
	# 推进剧情的决定要等本场的仗打完：打赢、撤出，或者打输并处理完大命运（ocean_battle2.gd 的 resolved）
	if (bool(choice.get("advance", true)) or str(choice.get("branch", "")) != "") and not Battle2.resolved(self):
		return "battle_pending"
	return ""


## 抉择的条件（requires；带 branch 的再并上书里这条分支的 requires）第一条不满足的键
func _choice_cond_reason(choice: Dictionary) -> String:
	var r := RunConditions.reason(self, choice.get("requires", {}))
	if r != "":
		return r
	var target := str(choice.get("branch", ""))
	if target != "":
		return RunConditions.reason(self, RunBook.branch(book, target).get("requires", {}))
	return ""


func _sign(args: Dictionary) -> Dictionary:
	if not _args(args, {"sign": TYPE_STRING}) or args["sign"] not in SIGNS:
		return _fail("bad_args")
	if state["phase"] not in ["morning", "day"]:
		return _fail("bad_phase")
	state["sign"] = args["sign"]
	return _ok()


func _wait(args: Dictionary) -> Dictionary:
	if not args.is_empty():
		return _fail("bad_args")
	match state["phase"]:
		"month_open": state["phase"] = "morning"
		"morning": state["phase"] = "day"
		"day":
			_tick_day()
			if state["phase"] != "game_over":
				state["phase"] = "settle"
		"settle": state["phase"] = "morning"
		"year_jump": state["phase"] = "month_open"
		_: return _fail("bad_phase")
	return _ok()


# ================================================================ 营地动作（rules.actions；地图模式下要站在提供它的节点上）

func _action_rule(key: String) -> Dictionary:
	return rules()["actions"].get(key, {})


func _visit(args: Dictionary) -> Dictionary:
	if not _args(args, {"place": TYPE_STRING}) or args["place"] not in ["town", "backdoor"]:
		return _fail("bad_args")
	var action := "visit:" + str(args["place"])
	var gate := MapRules.gate(self, action)
	if gate != "":
		return _fail(gate)
	var error := _action_error(action)
	if error != "":
		return _fail(error)
	var rule := _action_rule("visit_town" if args["place"] == "town" else "visit_backdoor")
	var cost := int(rule.get("cost", 0))
	if state["metrics"]["treasury"] < cost:
		return _fail("insufficient_funds")
	var effects: Dictionary = (rule.get("effects", {}) as Dictionary).duplicate()
	if cost > 0:
		effects["treasury"] = int(effects.get("treasury", 0)) - cost
	_apply_effects(effects)
	_rule_extras(rule)
	for item in rule.get("items_by_chapter", {}).get(str(chapter().get("id", "")), []):
		if item not in state["inventory"]:
			state["inventory"].append(item)
	state["open_panel"] = args["place"]
	_use(action)
	_record("visit", {"place": args["place"]})
	return _ok()


## 规则动作附带的旗标和功能币
func _rule_extras(rule: Dictionary) -> void:
	for flag in rule.get("flags", []):
		state["flags"][flag] = true
	for c in rule.get("coins", {}):
		add_coin(str(c), int(rule["coins"][c]))


func _trade(args: Dictionary) -> Dictionary:
	if not _args(args, {"kind": TYPE_STRING}) or args["kind"] not in ["fair", "counterfeit"]:
		return _fail("bad_args")
	var gate := MapRules.gate(self, "trade:" + str(args["kind"]))
	if gate != "":
		return _fail(gate)
	var error := _action_error("trade")
	if error != "":
		return _fail(error)
	var rule := _action_rule("trade_" + str(args["kind"]))
	_apply_effects(rule.get("effects", {}))
	_rule_extras(rule)
	_use("trade")
	_record("trade", {"kind": args["kind"]})
	return _ok()


func _project(args: Dictionary, key: String) -> Dictionary:
	if not args.is_empty():
		return _fail("bad_args")
	var rule := _action_rule(key)
	var metric := str(rule.get("metric", "construction" if key == "build" else "exploration"))
	var gate := MapRules.gate(self, key)
	if gate != "":
		return _fail(gate)
	var error := _action_error(metric)
	if error != "":
		return _fail(error)
	if not str(chapter()["id"]) in rule.get("chapters", []):
		return _fail("bad_phase")
	if state["metrics"][metric] >= 100:
		return _fail("already_complete")
	var cost := int(rule.get("cost", 200))
	if state["metrics"]["treasury"] < cost:
		return _fail("insufficient_funds")
	_apply_effects({"treasury": -cost, metric: int(rule.get("gain", 25))})
	_use(metric)
	_record("project", {"metric": metric, "cost": cost})
	return _ok()


func _fund(args: Dictionary) -> Dictionary:
	if not _args(args, {"support": TYPE_BOOL}):
		return _fail("bad_args")
	var rule := _action_rule("fund")
	if state["phase"] != "day" or not str(chapter()["id"]) in rule.get("chapters", []):
		return _fail("bad_phase")
	var gate := MapRules.gate(self, "fund")
	if gate != "":
		return _fail(gate)
	var yes: Dictionary = rule.get("yes", {})
	var no: Dictionary = rule.get("no", {})
	for flag in (yes.get("flags", []) as Array) + (no.get("flags", []) as Array):
		if state["flags"].get(flag, false):
			return _fail("already_used")
	if args["support"]:
		var cost := int(yes.get("cost", 0))
		if state["metrics"]["treasury"] < cost:
			return _fail("insufficient_funds")
		var effects: Dictionary = (yes.get("effects", {}) as Dictionary).duplicate()
		effects["treasury"] = int(effects.get("treasury", 0)) - cost
		_apply_effects(effects)
		_rule_extras(yes)
	else:
		_apply_effects(no.get("effects", {}))
		_rule_extras(no)
	_record("funding", {"support": args["support"]})
	return _ok()


func _demand(args: Dictionary) -> Dictionary:
	if not _args(args, {"id": TYPE_STRING, "action": TYPE_STRING}) or args["action"] != "fulfill":
		return _fail("bad_args")
	if state["phase"] != "day":
		return _fail("bad_phase")
	for demand in state["demands"]:
		if demand["id"] != args["id"]:
			continue
		if demand["status"] != "pending":
			return _fail("already_used")
		if demand["chapter"] != chapter()["id"]:
			return _fail("bad_phase")
		var gate := MapRules.gate(self, "demand:" + str(demand["id"]))
		if gate != "":
			return _fail(gate)
		if demand["item"] != "" and demand["item"] not in state["inventory"]:
			return _fail("missing_item")
		if state["metrics"]["treasury"] < demand["cost"]:
			return _fail("insufficient_funds")
		_apply_effects({"treasury": -int(demand["cost"])})
		if demand["item"] != "":
			state["inventory"].erase(demand["item"])
		demand["status"] = "fulfilled"
		var spec: Dictionary = _demand_specs().get(str(demand["id"]), {})
		for flag in spec.get("on_fulfill", {}).get("flags", []):
			state["flags"][flag] = true
		_record("demand_fulfilled", {"id": demand["id"], "cost": demand["cost"], "currency": chapter()["currency"]})
		return _ok()
	return _fail("bad_args")


# ================================================================ 天、场、章、段

func _tick_day() -> void:
	var day: int = state["day"]
	if state["daily_applied_day"] < day:
		var effects: Dictionary = (rules()["signs"].get(state["sign"], {}).get("daily", {}) as Dictionary).duplicate()
		_apply_effects(effects)
		state["daily_applied_day"] = day
		_record("daily_sign", {"sign": state["sign"], "effects": effects, "currency": chapter()["currency"]})
	state["day"] = day + 1
	_expire_demands(false)
	_check_failure()
	if state["phase"] != "game_over":
		MapRules.on_tick(self)


func _expire_demands(leaving_chapter: bool) -> void:
	if OS.get_environment("DEHOUDANG_NO_MAP") == "1" and not leaving_chapter:
		return
	for demand in state["demands"]:
		if demand["status"] != "pending":
			continue
		if state["day"] < demand["due_day"] and not leaving_chapter:
			continue
		demand["status"] = "expired"
		var spec: Dictionary = _demand_specs().get(str(demand["id"]), {})
		_apply_effects(spec.get("on_expire", {}).get("effects", {}))
		for flag in spec.get("on_expire", {}).get("flags", []):
			state["flags"][flag] = true
		_record("demand_expired", {"id": demand["id"]})


## 下一场：跳过 when 为假的场（连续跳过的不扣天数）
func _next_scene(from: int) -> int:
	var i := from
	while i < definition["scenes"].size():
		var s: Dictionary = definition["scenes"][i]
		if (s.get("when", {}) as Dictionary).is_empty() or RunConditions.eval(self, s["when"]):
			return i
		i += 1
	return i


func _advance_scene() -> void:
	_tick_day()
	if state["phase"] == "game_over":
		return
	var next_index := _next_scene(state["scene_index"] + 1)
	if next_index >= definition["scenes"].size():
		_finish(_ending(), "finale")
		return
	var previous_chapter := chapter()
	var next: Dictionary = definition["scenes"][next_index]
	var transition: bool = next["chapter"] != previous_chapter["id"]
	if transition:
		if int(_chapter_of(str(next["chapter"])).get("volume", 1)) > int(book.get("volume", 1)):
			_finish(_volume_ending(), "volume")
			return
		_expire_demands(true)
		_check_failure()
		if state["phase"] == "game_over":
			return
		state["chapter_balances"][previous_chapter["id"]] = {
			"currency": previous_chapter["currency"], "treasury": state["metrics"]["treasury"], "day": state["day"],
		}
	if MapRules.enabled(self):
		var anchor := MapRules.anchor_of(self, str(scene()["id"]))
		if anchor != "" and not anchor in state["map"]["done"]:
			state["map"]["done"].append(anchor)
	state["scene_index"] = next_index
	state["open_panel"] = ""
	state["phase"] = "year_jump" if transition else "day"
	if transition:
		var current_chapter := chapter()
		state["metrics"]["treasury"] = current_chapter["treasury_start"]
		_record("chapter_open", {
			"from": previous_chapter["id"], "to": current_chapter["id"],
			"currency": current_chapter["currency"], "treasury_start": current_chapter["treasury_start"],
			"conversion": "separate_accounts",
		})
		state["run"]["chapter_ord"] = int(state["run"]["chapter_ord"]) + 1
		_open_map(str(current_chapter["id"]))
	_enter_scene()


func _enter_scene() -> void:
	var current := scene()
	if not state["clues"].has(current["id"]):
		state["clues"][current["id"]] = []
	if not state["used_actions"].has(current["id"]):
		state["used_actions"][current["id"]] = []
	var present := {}
	for d in state["demands"]:
		present[str(d.get("id", ""))] = true
	for spec in RunOceanRules.scene_demands(definition, current):
		var id := str(spec.get("id", ""))
		if present.has(id):
			continue
		state["demands"].append({"id": id, "title": str(spec.get("title", OCEAN_DEMAND_TITLES.get(id, id))), "chapter": current["chapter"],
			"due_day": state["day"] + int(spec.get("due_in", 5)), "cost": int(spec.get("cost", 0)), "item": str(spec.get("item", "")), "status": "pending"})
	RogueRules.on_enter_scene(self)
	CompanionRules.on_scene(self)


## 段切换（ARCH §1.6 的七步，都在 send() 的候选副本里）：带 branch 的抉择，或带 jump 的大命运项
func _switch_segment(target: String, via: String) -> void:
	_tick_day()
	if state["phase"] == "game_over":
		return
	_expire_demands(true)
	_check_failure()
	if state["phase"] == "game_over":
		return
	var from := str(state["segment"])
	var old_chapter := chapter()
	var balances: Dictionary = state["chapter_balances"].duplicate(true)
	balances[old_chapter["id"]] = {"currency": old_chapter["currency"], "treasury": state["metrics"]["treasury"], "day": state["day"]}
	var ledger: Array = state["ledger"]
	var kept: Array = ledger.slice(maxi(0, ledger.size() - ARCHIVE_LEDGER))
	kept.append({"type": "summary", "rows": ledger.size(), "day": state["day"]})
	state["archive"][from] = {"scene_index": state["scene_index"], "ending": "", "end_reason": "", "day": state["day"], "ledger": kept,
		"clues": state["clues"], "used_actions": state["used_actions"], "chapter_balances": balances, "demands": state["demands"], "map": state["map"]}
	var target_def: Dictionary = book["defs"][target]
	var entry := str(RunBook.branch(book, target).get("entry", ""))
	var index := 0
	if entry != "":
		index = maxi(0, _scene_index(entry, target_def))
	var target_chapter: Dictionary = {}
	for c in target_def["chapters"]:
		if str(c["id"]) == str(target_def["scenes"][index]["chapter"]):
			target_chapter = c
	RunCarry.apply(self, target_def, target_chapter, old_chapter)
	definition = target_def
	_cache.erase("rules:" + str(target_def.get("id", "")))
	state["campaign"] = str(target_def["id"])
	state["segment"] = target
	state["scene_index"] = index
	state["ledger"] = []
	state["clues"] = {}
	state["used_actions"] = {}
	state["chapter_balances"] = {}
	state["demands"] = []
	state["open_panel"] = ""
	state["phase"] = "year_jump"
	var run: Dictionary = state["run"]
	run["path"].append(target)
	run["level_offset"] = int(RunBook.branch(book, target).get("level_offset", 0))
	run["chapter_ord"] = int(run["chapter_ord"]) + 1
	RogueRules.apply_opening_hooks(self)
	_open_map(str(target_chapter.get("id", "")))
	_record("segment_open", {"from": from, "to": target, "via": via})
	_enter_scene()


func _ending() -> String:
	for row in rules()["endings"]:
		if RunConditions.eval(self, row.get("when", {})):
			return str(row["id"])
	var fallback := str(rules()["default_ending"])
	return fallback if fallback != "" else "bittersweet"


func _volume_ending() -> String:
	for row in rules()["volume_endings"]:
		if RunConditions.eval(self, row.get("when", {})):
			return str(row["id"])
	var fallback := str(rules()["default_volume_ending"])
	return fallback if fallback != "" else _ending()


func _check_failure() -> void:
	if state["phase"] == "game_over":
		return
	for row in rules()["failures"]:
		if RunConditions.eval(self, row.get("when", {})):
			_finish(str(row["ending"]), str(row["reason"]))
			return


func _finish(ending: String, reason: String) -> void:
	state["ending"] = ending
	state["end_reason"] = reason
	state["phase"] = "game_over"
	state["open_panel"] = ""
	_record("ending", {"id": ending, "reason": reason})


func _apply_effects(effects: Dictionary) -> void:
	for metric in effects:
		var value: int = int(state["metrics"][metric]) + int(effects[metric])
		state["metrics"][metric] = clampi(value, 0, MAX_INTEGER if metric == "treasury" else 100)


func _action_error(action: String) -> String:
	if state["phase"] != "day":
		return "bad_phase"
	return "already_used" if _used(action) else ""


func _used(action: String) -> bool:
	return action in state["used_actions"].get(scene()["id"], [])


func _use(action: String) -> void:
	var actions: Array = state["used_actions"].get(scene()["id"], [])
	actions.append(action)
	state["used_actions"][scene()["id"]] = actions


func _record(kind: String, details: Dictionary) -> void:
	var entry := {"day": state["day"], "scene": scene()["id"], "type": kind}
	entry.merge(details.duplicate(true))
	state["ledger"].append(entry)


func _scene_index(id: String, source: Dictionary = {}) -> int:
	var data: Dictionary = definition if source.is_empty() else source
	for index in data.get("scenes", []).size():
		if data["scenes"][index].get("id") == id:
			return index
	return -1


func _args(args: Dictionary, schema: Dictionary) -> bool:
	if args.size() != schema.size():
		return false
	for key in schema:
		if not args.has(key) or typeof(args[key]) != schema[key]:
			return false
	return true


func _strings(value: Variant) -> bool:
	if typeof(value) != TYPE_ARRAY:
		return false
	var seen := {}
	for item in value:
		if typeof(item) != TYPE_STRING or item.is_empty() or seen.has(item):
			return false
		seen[item] = true
	return true


# ================================================================ 校验

func _valid_definition(data: Dictionary) -> bool:
	if typeof(data.get("id")) != TYPE_STRING or str(data["id"]).is_empty() or data.get("version") not in [1, 2]:
		return false
	if typeof(data.get("initial")) != TYPE_DICTIONARY or not _valid_metrics(data["initial"]):
		return false
	if data["initial"]["treasury"] == 0 or data["initial"]["vitality"] == 0 or data["initial"]["heat"] == 100:
		return false
	if typeof(data.get("tuning", {})) != TYPE_DICTIONARY:
		return false
	if typeof(data.get("tuning", {}).get("wealth_limit", 20000)) != TYPE_INT or data.get("tuning", {}).get("wealth_limit", 20000) <= 0:
		return false
	for key in ["chapters", "scenes", "items", "endings"]:
		if typeof(data.get(key)) != TYPE_ARRAY or data[key].is_empty():
			return false
	for key in ["rules", "gauges"]:
		if data.has(key) and typeof(data[key]) != TYPE_DICTIONARY:
			return false
	for key in ["events", "big_fate_extra"]:
		if data.has(key) and typeof(data[key]) != TYPE_ARRAY:
			return false
	var chapter_ids := {}
	var declared_scenes: Array = []
	for entry in data["chapters"]:
		if typeof(entry) != TYPE_DICTIONARY or typeof(entry.get("id")) != TYPE_STRING or chapter_ids.has(entry["id"]):
			return false
		if typeof(entry.get("currency")) != TYPE_STRING or not _strings(entry.get("scene_ids")) or entry["scene_ids"].is_empty():
			return false
		if typeof(entry.get("treasury_start")) != TYPE_INT or entry["treasury_start"] <= 0:
			return false
		if typeof(entry.get("volume", 1)) != TYPE_INT or int(entry.get("volume", 1)) < 1:
			return false
		chapter_ids[entry["id"]] = true
		declared_scenes.append_array(entry["scene_ids"])
	var scene_ids := {}
	for entry in data["scenes"]:
		if typeof(entry) != TYPE_DICTIONARY or typeof(entry.get("id")) != TYPE_STRING or scene_ids.has(entry["id"]):
			return false
		if not chapter_ids.has(entry.get("chapter")):
			return false
		scene_ids[entry["id"]] = true
		if typeof(entry.get("appraisals")) != TYPE_ARRAY or typeof(entry.get("choices")) != TYPE_ARRAY or entry["choices"].is_empty():
			return false
		if typeof(entry.get("when", {})) != TYPE_DICTIONARY:
			return false
		var appraisal_ids := {}
		for appraisal in entry["appraisals"]:
			if typeof(appraisal) != TYPE_DICTIONARY or typeof(appraisal.get("id")) != TYPE_STRING or appraisal_ids.has(appraisal["id"]):
				return false
			if appraisal.get("kind") not in ["spot", "weigh", "ring", "decode"] or typeof(appraisal.get("observation")) != TYPE_STRING:
				return false
			appraisal_ids[appraisal["id"]] = true
		var choice_ids := {}
		for choice in entry["choices"]:
			if typeof(choice) != TYPE_DICTIONARY or typeof(choice.get("id")) != TYPE_STRING or choice_ids.has(choice["id"]):
				return false
			choice_ids[choice["id"]] = true
			for key in ["requires_clues", "requires_flags", "flags", "remove_flags", "items", "remove_items"]:
				if not _strings(choice.get(key, [])):
					return false
			for clue in choice.get("requires_clues", []):
				if not appraisal_ids.has(clue):
					return false
			if typeof(choice.get("advance", true)) != TYPE_BOOL or typeof(choice.get("effects", {})) != TYPE_DICTIONARY:
				return false
			if typeof(choice.get("branch", "")) != TYPE_STRING or typeof(choice.get("requires", {})) != TYPE_DICTIONARY \
					or typeof(choice.get("rogue", {})) != TYPE_DICTIONARY or typeof(choice.get("days", 0)) != TYPE_INT or int(choice.get("days", 0)) < 0:
				return false
			for metric in choice.get("effects", {}):
				if metric not in METRICS or typeof(choice["effects"][metric]) != TYPE_INT:
					return false
	if declared_scenes.size() != scene_ids.size() or not _strings(declared_scenes):
		return false
	for index in declared_scenes.size():
		if declared_scenes[index] != data["scenes"][index]["id"]:
			return false
	for entry in data["chapters"]:
		for id in entry["scene_ids"]:
			if data["scenes"][_scene_index(id, data)]["chapter"] != entry["id"]:
				return false
	return true


func _valid_metrics(metrics: Dictionary) -> bool:
	if metrics.size() != METRICS.size():
		return false
	for metric in METRICS:
		if typeof(metrics.get(metric)) != TYPE_INT or metrics[metric] < 0 or metrics[metric] > (MAX_INTEGER if metric == "treasury" else 100):
			return false
	return true


## 全书可能落到的结局：各段 endings / rules 里的结局与卷终、四种失败、讣告；单段书再加远洋原表
func _allowed_endings() -> Array:
	if _cache.has("endings"):
		return _cache["endings"]
	var out: Array = ["", OBITUARY, "exile"] + OCEAN_ENDINGS + RunBook.FAILURE_ENDINGS
	for seg in book.get("defs", {}):
		var def: Dictionary = book["defs"][seg]
		for e in def.get("endings", []):
			out.append(str(e.get("id", "")))
		var r := RunOceanRules.rules(def)
		for key in ["failures", "endings", "volume_endings"]:
			for row in r[key]:
				out.append(str(row.get("ending", row.get("id", ""))))
		out.append(str(r["default_ending"]))
		out.append(str(r["default_volume_ending"]))
	_cache["endings"] = out
	return out


func _valid_state(saved: Dictionary) -> bool:
	var fields: Array = FIELDS_V1 + FIELDS_V2
	if saved.size() != fields.size():
		return false
	for key in saved:
		if key not in fields:
			return false
	if saved.get("v") != 2 or saved.get("campaign") != definition.get("id") or saved.get("definition_hash") != _definition_hash:
		return false
	if typeof(saved.get("segment")) != TYPE_STRING or not book.get("defs", {}).has(str(saved["segment"])):
		return false
	if not RogueRules.valid_rogue(saved.get("rogue"), roster()["ids"]):
		return false
	for key in ["seed", "scene_index", "day", "daily_applied_day"]:
		if typeof(saved.get(key)) != TYPE_INT:
			return false
	if saved["scene_index"] < 0 or saved["scene_index"] >= definition["scenes"].size() or saved["day"] < 1 or saved["daily_applied_day"] < 0 or saved["daily_applied_day"] >= saved["day"]:
		return false
	if saved.get("phase") not in PHASES or saved.get("sign") not in SIGNS:
		return false
	for key in ["metrics", "flags", "clues", "used_actions", "chapter_balances", "run", "archive"]:
		if typeof(saved.get(key)) != TYPE_DICTIONARY:
			return false
	if not _valid_metrics(saved["metrics"]) or not _strings(saved.get("inventory")):
		return false
	for key in ["ending", "end_reason", "open_panel"]:
		if typeof(saved.get(key)) != TYPE_STRING:
			return false
	if (saved["phase"] == "game_over") != (saved["ending"] != ""):
		return false
	if saved["ending"] not in _allowed_endings():
		return false
	if saved["open_panel"] not in ["", "town", "backdoor"]:
		return false
	if saved["phase"] != "game_over" and (saved["metrics"]["treasury"] == 0 or saved["metrics"]["vitality"] == 0 or saved["metrics"]["heat"] == 100):
		return false
	for flag in saved["flags"]:
		if typeof(flag) != TYPE_STRING or typeof(saved["flags"][flag]) != TYPE_BOOL:
			return false
	for group in RunOceanRules.rules(definition)["exclusive_flags"]:
		var n := 0
		for f in group:
			if bool(saved["flags"].get(f, false)):
				n += 1
		if n > 1:
			return false
	for key in ["clues", "used_actions"]:
		for id in saved[key]:
			if typeof(id) != TYPE_STRING or _scene_index(id) < 0 or not _strings(saved[key][id]):
				return false
			if key == "clues":
				var known: Array = []
				for clue in definition["scenes"][_scene_index(id)]["appraisals"]:
					known.append(clue["id"])
				for clue in saved[key][id]:
					if clue not in known:
						return false
	if typeof(saved.get("ledger")) != TYPE_ARRAY or typeof(saved.get("demands")) != TYPE_ARRAY:
		return false
	for row in saved["ledger"]:
		if typeof(row) != TYPE_DICTIONARY or typeof(row.get("type")) != TYPE_STRING or typeof(row.get("day")) != TYPE_INT or row["day"] < 1 or row["day"] > saved["day"] or _scene_index(str(row.get("scene", ""))) < 0:
			return false
	if not _valid_demands(saved):
		return false
	for id in saved["chapter_balances"]:
		var balance: Variant = saved["chapter_balances"][id]
		if typeof(balance) != TYPE_DICTIONARY or typeof(balance.get("treasury")) != TYPE_INT or balance["treasury"] < 0 or typeof(balance.get("day")) != TYPE_INT or balance["day"] < 1 or balance["day"] > saved["day"]:
			return false
		var found := false
		for entry in definition["chapters"]:
			if entry["id"] == id and entry["currency"] == balance.get("currency"):
				found = true
		if not found:
			return false
	return _valid_run(saved) and MapRules.valid(book, str(saved["segment"]), saved.get("map"))


func _valid_demands(saved: Dictionary) -> bool:
	var specs := RunOceanRules.demand_specs(definition)
	var demand_ids := {}
	for demand in saved["demands"]:
		if typeof(demand) != TYPE_DICTIONARY or not specs.has(str(demand.get("id", ""))) or demand_ids.has(demand["id"]):
			return false
		var spec: Dictionary = specs[str(demand["id"])]
		demand_ids[demand["id"]] = true
		if demand.get("chapter") != spec["chapter"] or typeof(demand.get("title")) != TYPE_STRING or demand.get("status") not in ["pending", "fulfilled", "expired"] or typeof(demand.get("due_day")) != TYPE_INT or demand["due_day"] < 1:
			return false
		if demand.get("cost") != int(spec.get("cost", 0)) or demand.get("item") != str(spec.get("item", "")):
			return false
		if demand["status"] == "pending" and demand["due_day"] <= saved["day"]:
			return false
	return true


func _valid_run(saved: Dictionary) -> bool:
	var run: Dictionary = saved["run"]
	if run.size() != RUN_KEYS.size():
		return false
	for key in RUN_KEYS:
		if not run.has(key):
			return false
	if typeof(run["book"]) != TYPE_STRING or run["book"] != str(book.get("id", "")) or typeof(run["path"]) != TYPE_ARRAY or (run["path"] as Array).is_empty():
		return false
	if str(run["path"][-1]) != str(saved["segment"]):
		return false
	for key in ["volume", "level_offset", "chapter_ord", "dice"]:
		if typeof(run[key]) != TYPE_INT or int(run[key]) < 0:
			return false
	for key in ["stats", "start"]:
		if typeof(run[key]) != TYPE_DICTIONARY:
			return false
	if not _strings(run["events_seen"]) or not _strings(run["fate_once"]):
		return false
	for seg in saved["archive"]:
		var row = saved["archive"][seg]
		if not book.get("defs", {}).has(str(seg)) or typeof(row) != TYPE_DICTIONARY or typeof(row.get("scene_index")) != TYPE_INT:
			return false
	return true


func _ok() -> Dictionary:
	return {"ok": true, "err": ""}


func _fail(error: String) -> Dictionary:
	return {"ok": false, "err": error}
