## Adapts the narrative campaign to the existing CardEngine API and save envelope.
## All presentation stays in the existing card widgets; this module owns no nodes.
## 两本书（WORLD_MAP_DESIGN §6、ARCH §1.7）：单段书 ocean_pawn（回归用，行为和存档照旧）和多段书 napoleon
## （game.new 认 campaign "napoleon"、book（书 id 或 res:// / user:// 路径）、segment、stage）。
## 多段书另外写：段切换的检查点 checkpoint_NN.json（之后 suspend 的命令日志从检查点算起，meta.replay_base 指回去）、
## 进分岔场景时的 branch.json、每次收场和段切换时的局外记录 napoleon_meta.json。
## 读档时定义哈希不符（数据改过）且存档自身一致，就用 run_replay 在新数据上重放接续；重放失败报 replay_failed。
extends RefCounted

const Campaign = preload("res://scripts/cards/campaign/ocean_campaign.gd")
const View = preload("res://scripts/cards/campaign/ocean_view.gd")
const RunBook = preload("res://scripts/cards/campaign/run/run_book.gd")
const RunReplay = preload("res://scripts/cards/campaign/run/run_replay.gd")
const SAVE_ROOT := "user://cards/ocean_pawn"
const NAPOLEON_SAVE_ROOT := "user://cards/napoleon"
const VOLUME2_SAVE_ROOT := "user://cards/napoleon-volume2"
const DEMO_SAVE_ROOT := "user://cards/napoleon-demo"
## 不指定书时从土伦开局；环境变量 DEHOUDANG_CAMPAIGN=napoleon|ocean_pawn 优先
const DEFAULT_BOOK := "napoleon"
## 书 id → 书文件
const BOOKS := {"napoleon": RunBook.DEMO, "napoleon_demo": RunBook.DEMO,
	"napoleon_volume2": RunBook.NAPOLEON, "napoleon_volume1": RunBook.VOLUME1}
const META_FILE := "napoleon_meta.json"
const BRANCH_FILE := "branch.json"
## 读档时数据已更新、进度按新版重算过（界面据此提示一句；文字在界面的文字表里）
const NOTICE_REPLAYED := "data_replayed"
const COMMANDS := [&"campaign.appraise", &"campaign.choose", &"campaign.sign", &"campaign.wait",
	&"campaign.visit", &"campaign.trade", &"campaign.build", &"campaign.explore", &"campaign.fund", &"campaign.demand",
	&"campaign.roll_dice", &"campaign.pick_route", &"campaign.activity", &"campaign.schedule",
	&"campaign.recruit", &"campaign.promote", &"campaign.companion_duty", &"campaign.use_prop", &"campaign.big_fate",
	&"campaign.battle_prepare", &"campaign.battle_reveal", &"campaign.battle_begin", &"campaign.battle_cmd",
	&"campaign.battle_finish",
	&"campaign.map_roll", &"campaign.map_card", &"campaign.map_move", &"campaign.map_enter", &"campaign.map_choose",
	&"campaign.map_appraise", &"campaign.map_scout", &"campaign.map_build", &"campaign.map_pay", &"campaign.map_muster"]
## 战斗规则 v2 的查询（战役查询 campaign 里也带 battle2）；世界地图和一局的结构（§5.8）
const QUERIES := [&"campaign", &"campaign.battle2", &"campaign.battle_preview", &"campaign.map", &"campaign.run"]

var model: RefCounted
var save_dir: String = SAVE_ROOT
## 多段书：当前命令日志从哪个检查点算起（{file, hash}；空 = 从开局）
var replay_base: Dictionary = {}
## 最近一次读档的提示（NOTICE_REPLAYED 或 ""）
var notice := ""


static func selected(opts: Dictionary) -> bool:
	if opts.has("campaign"):
		return str(opts["campaign"]) in ["ocean_pawn", "napoleon"]
	if opts.has("data_root") or bool(opts.get("only_examples", false)):
		return false
	return OS.get_environment("DEHOUDANG_CAMPAIGN") != "legacy"


## Separate books keep their Continue/profile slots; an explicit directory always wins.
static func default_save_dir(opts: Dictionary = {}) -> String:
	var path := str(game_opts(opts).get("book", ""))
	if path == "":
		return SAVE_ROOT
	if path == RunBook.DEMO:
		return DEMO_SAVE_ROOT
	return VOLUME2_SAVE_ROOT if path == RunBook.NAPOLEON else NAPOLEON_SAVE_ROOT


## game.new 的参数 → {ok, err, book: 书文件（单段书为 ""）, game: OceanCampaign.new_game 的参数}
static func game_opts(opts: Dictionary) -> Dictionary:
	if opts.has("entry") and (typeof(opts["entry"]) != TYPE_STRING or opts["entry"] != "branch_point" or opts.has("segment") or opts.has("stage")):
		return _error("bad_args")
	for key in ["book", "segment", "campaign"]:
		if opts.has(key) and (typeof(opts[key]) != TYPE_STRING or str(opts[key]).is_empty()):
			return _error("bad_args")
	var campaign := str(opts.get("campaign", ""))
	var book := str(opts.get("book", ""))
	if campaign == "" and book == "":
		var env := OS.get_environment("DEHOUDANG_CAMPAIGN")
		campaign = env if env in ["ocean_pawn", "napoleon"] else DEFAULT_BOOK
	if book == "":
		book = "napoleon" if campaign == "napoleon" else "ocean_pawn"
	if campaign == "ocean_pawn" and book != "ocean_pawn":
		return _error("bad_args")
	var path := "" if book == "ocean_pawn" else str(BOOKS.get(book, book))
	if path != "" and not (path.begins_with("res://") or path.begins_with("user://")):
		return _error("bad_args")
	var game := {"seed": opts.get("seed", 0), "stage": opts.get("stage", 0)}
	if opts.has("entry"):
		if path == "":
			return _error("bad_args")
		game.erase("stage")
		game["entry"] = opts["entry"]
	elif opts.has("segment"):
		game["segment"] = opts["segment"]
	elif path != "" and not opts.has("stage") and OS.get_environment("DEHOUDANG_START").contains(":"):
		# 无头测试用：DEHOUDANG_START=cristo:2 直接开某段某章（ARCH §1.10）
		var spec := OS.get_environment("DEHOUDANG_START")
		game["segment"] = spec.get_slice(":", 0)
		game["stage"] = int(spec.get_slice(":", 1))
	if path != "":
		game["book"] = path
	return {"ok": true, "err": "", "book": path, "game": game}


## 按 game.new 的参数造一个开好局的模型（重放也用）：{ok, err, model}
static func new_model(opts: Dictionary) -> Dictionary:
	if opts.has("entry") and (not opts.has("seed") or typeof(opts["seed"]) != TYPE_INT):
		return _error("bad_args")
	var g := game_opts(opts)
	if not bool(g.get("ok", false)):
		return g
	var candidate := Campaign.new()
	var result: Dictionary = candidate.load_book(str(g["book"])) if str(g["book"]) != "" else candidate.load_definition()
	if not bool(result.get("ok", false)):
		return result
	result = candidate.new_game(g["game"])
	if not bool(result.get("ok", false)):
		return result
	return {"ok": true, "err": "", "model": candidate}


func start(engine: CardEngine, opts: Dictionary) -> Dictionary:
	if opts.has("save_dir") and (typeof(opts["save_dir"]) != TYPE_STRING or str(opts["save_dir"]).is_empty()):
		return _error("bad_args")
	var made := new_model(opts)
	if not bool(made.get("ok", false)):
		return made
	var candidate = made["model"]
	var target_dir := str(opts.get("save_dir", default_save_dir(opts))).trim_suffix("/")
	if opts.get("entry", "") == "branch_point" and not branch_unlocked(target_dir):
		return _error("entry_locked")
	var result := {"ok": true, "err": ""}
	var run_result := _run_context(opts.get("run", {}), candidate.definition)
	if not bool(run_result.get("ok", false)):
		return run_result
	model = candidate
	replay_base = {}
	notice = ""
	save_dir = str(opts.get("save_dir", default_save_dir(opts))).trim_suffix("/")
	CardSave.set_root(save_dir)
	engine.ctx.state = CardState.create(int(model.state["seed"]), {"db_hash": model.state["definition_hash"]})
	if not (run_result["run"] as Dictionary).is_empty():
		engine.ctx.state.data["run"] = run_result["run"]
	engine.ctx.ledger = null
	engine.clear_command_log()
	sync(engine)
	return result


func restore(engine: CardEngine, path: String, envelope: Dictionary) -> Dictionary:
	if not bool(envelope.get("ok", false)):
		return envelope
	var saved: CardState = envelope["state"]
	if typeof(saved.data.get("ocean")) != TYPE_DICTIONARY:
		return _error("campaign_mismatch")
	var loaded := restore_model(envelope, path.get_base_dir())
	if not bool(loaded.get("ok", false)):
		return loaded
	var candidate = loaded["model"]
	var run_result := _run_context(saved.data.get("run", {}), candidate.definition, true)
	if not bool(run_result.get("ok", false)):
		return run_result
	var history: Array = envelope.get("cmd_log", [])
	for entry in history:
		if typeof(entry) != TYPE_ARRAY or entry.size() != 2 or typeof(entry[0]) != TYPE_STRING or typeof(entry[1]) != TYPE_DICTIONARY:
			return _error("bad_args")
	var old_ui: Dictionary = engine.ctx.state.ns("ui") if engine.ctx.state != null else {}
	var saved_ui: Dictionary = saved.ns("ui")
	if not _valid_ui(saved_ui) or not _valid_ui(old_ui):
		return _error("save_invalid")
	var merged_ui := CardCoreInstall.merge_ui(old_ui, saved_ui)
	model = candidate
	var base = envelope.get("meta", {}).get("replay_base", {})
	replay_base = (base as Dictionary).duplicate(true) if typeof(base) == TYPE_DICTIONARY and not model.is_builtin() else {}
	notice = str(loaded.get("notice", ""))
	save_dir = path.get_base_dir()
	CardSave.set_root(save_dir)
	saved.data["ui"] = merged_ui
	engine.ctx.state = saved
	engine.ctx.ledger = null
	engine.restore_command_log(history)
	sync(engine)
	var meta := {"campaign": campaign_id(), "db_changed": notice != ""}
	if notice != "":
		meta["notice"] = notice
	return {"ok": true, "err": "", "meta": meta}


## 读档里的战役状态装进一个新模型：{ok, err, model, notice}。按状态里 run.start.book 选书（没有就是单段书）。
## 定义哈希不符、而存档自身一致（信封 db_hash = 状态里的 db_hash = 战役的 definition_hash）时，说明是数据改过：
## 在新数据上按命令日志重放（检查点也重放），每一步都成功才接受；存档自相矛盾（被改过）照旧拒绝。
static func restore_model(envelope: Dictionary, dir: String) -> Dictionary:
	var saved: CardState = envelope["state"]
	var ocean: Dictionary = saved.data["ocean"]
	var book_path := book_path_of(ocean)
	var candidate := Campaign.new()
	var result: Dictionary = candidate.load_book(book_path) if book_path != "" else candidate.load_definition()
	if not bool(result.get("ok", false)):
		return result
	result = candidate.restore(ocean)
	if bool(result.get("ok", false)):
		return {"ok": true, "err": "", "model": candidate, "notice": ""}
	var old_hash = ocean.get("definition_hash")
	if typeof(old_hash) != TYPE_STRING or str(old_hash) == str(candidate._definition_hash) \
			or str(old_hash) != str(envelope.get("db_hash", "")) or str(old_hash) != str(saved.data.get("db_hash", "")):
		return result
	var rebuilt := RunReplay.rebuild(envelope, dir, func(args: Dictionary) -> Dictionary: return new_model(args),
		func(m, cmd: StringName, args: Dictionary) -> Dictionary: return dispatch_model(m, cmd, args))
	if not bool(rebuilt.get("ok", false)):
		return {"ok": false, "err": "replay_failed", "at": int(rebuilt.get("at", -1)), "cause": str(rebuilt.get("err", ""))}
	return {"ok": true, "err": "", "model": rebuilt["model"], "notice": NOTICE_REPLAYED}


## 存档状态是哪本书：run.start.book（多段书的书文件）；单段书和旧存档是 ""
static func book_path_of(ocean: Dictionary) -> String:
	var run = ocean.get("run", {})
	if typeof(run) != TYPE_DICTIONARY or typeof(run.get("start")) != TYPE_DICTIONARY:
		return ""
	var path := str(run["start"].get("book", ""))
	return path if path.begins_with("res://") or path.begins_with("user://") else ""


## 重放 / 核对一份存档（测试与工具用）：{ok, err, at, want, got}
static func verify(envelope: Dictionary, dir: String) -> Dictionary:
	return RunReplay.verify(envelope, dir, func(args: Dictionary) -> Dictionary: return new_model(args),
		func(m, cmd: StringName, args: Dictionary) -> Dictionary: return dispatch_model(m, cmd, args))


func campaign_id() -> String:
	return "ocean_pawn" if model == null or model.is_builtin() else str(model.book.get("id", "napoleon"))


func sync(engine: CardEngine) -> void:
	engine.ctx.state.data["ocean"] = model.snapshot()
	engine.ctx.state.data["db_hash"] = model.state["definition_hash"]
	engine.ctx.state.data["loop"] = {"_v": 1, "phase": model.state["phase"],
		"stage": chapter_index(), "abs_day": model.state["day"], "mode": "shop"}
	engine.ctx.db = View.setup_text(model)


## 第几章：单段书是本段的章下标；多段书是 run.chapter_ord（整局唯一、递增，stage_NN.json 用它编号）
func chapter_index() -> int:
	if not model.is_builtin():
		return int(model.state.get("run", {}).get("chapter_ord", 0))
	var chapters: Array = model.definition.get("chapters", [])
	for i in chapters.size():
		if str(chapters[i]["id"]) == str(model.scene()["chapter"]):
			return i
	return 0


## The v0.9 ledger keeper consumes these queries without reading campaign internals.
## Campaign history shares the shell contract, but never imports the old campaign's fragments or openings.
func query(engine: CardEngine, q: StringName, args: Dictionary = {}) -> Dictionary:
	if q == &"legacy.harvest":
		return _harvest(model, engine.ctx.state.data.get("run", {}), args)
	if q == &"legacy.old_ink":
		# All character dossiers are available from the prologue; none are hidden behind prior runs.
		return {"ok": true, "err": "", "pages": []}
	return _error("bad_args")


## Read a suspended campaign's ledger summary without installing it into the live engine.
static func saved_harvest(saved: CardState, args: Dictionary = {}) -> Dictionary:
	if typeof(saved.data.get("ocean")) != TYPE_DICTIONARY:
		return _error("campaign_mismatch")
	var candidate := Campaign.new()
	var book_path := book_path_of(saved.data["ocean"])
	var result: Dictionary = candidate.load_book(book_path) if book_path != "" else candidate.load_definition()
	if not bool(result.get("ok", false)):
		return result
	result = candidate.restore(saved.data["ocean"])
	if not bool(result.get("ok", false)):
		return result
	var run_result := _run_context(saved.data.get("run", {}), candidate.definition, true)
	if not bool(run_result.get("ok", false)):
		return run_result
	return _harvest(candidate, run_result["run"], args)


static func _harvest(campaign, run: Dictionary, args: Dictionary) -> Dictionary:
	if args.keys().any(func(key: Variant) -> bool: return str(key) != "close"):
		return _error("bad_args")
	if args.has("close") and typeof(args["close"]) not in [TYPE_STRING, TYPE_STRING_NAME]:
		return _error("bad_args")
	var chapter: Dictionary = campaign.chapter()
	var scene: Dictionary = campaign.scene()
	var chapters: Array = campaign.definition.get("chapters", [])
	var stage := 0
	for i in chapters.size():
		if str(chapters[i].get("id", "")) == str(chapter.get("id", "")):
			stage = i
			break
	var scene_ids: Array = chapter.get("scene_ids", [])
	var day := maxi(1, scene_ids.find(str(scene.get("id", ""))) + 1)
	var ending: Variant = campaign.state.get("ending", "")
	var reason := str(ending.get("id", "")) if typeof(ending) == TYPE_DICTIONARY else str(ending)
	var fragments := _character_fragments(campaign.definition)
	var out := {"ok": true, "err": "", "no": int(run.get("no", 0)),
		"phase": str(campaign.state.get("phase", "")), "reason": reason,
		"stage": stage, "era": str(chapter.get("id", "")), "stage_day": day, "frags": fragments}
	if args.has("close"):
		var close := str(args["close"])
		var key := "ocean.chronicle.other"
		if close == "abandoned":
			key = "ocean.chronicle.abandoned"
		elif reason in ["alliance", "ghost", "dark", "tragedy", "bittersweet", "bankruptcy", "loss", "blockade", "obituary"]:
			key = "ocean.chronicle." + reason
		out["chronicle"] = {"key": key, "args": {"d": day}}
	return out


static func _character_fragments(definition: Dictionary) -> Array:
	var fragments: Array = []
	for person in definition.get("characters", []):
		fragments.append("ocean.person." + str(person["id"]))
	fragments.sort()
	return fragments


## Keep the same run envelope as v0.9, while validating it before any live state or save path changes.
static func _run_context(raw: Variant, definition: Dictionary, saved: bool = false) -> Dictionary:
	var error := "save_invalid" if saved else "bad_args"
	if typeof(raw) != TYPE_DICTIONARY:
		return _error(error)
	if raw.is_empty():
		return {"ok": true, "err": "", "run": {}}
	if saved and (typeof(raw.get("_v")) != TYPE_INT or int(raw["_v"]) != 1):
		return _error("save_newer" if typeof(raw.get("_v")) == TYPE_INT and int(raw["_v"]) > 1 else error)
	if typeof(raw.get("no")) != TYPE_INT or int(raw["no"]) < 1:
		return _error(error)
	if typeof(raw.get("opening", "og.default")) != TYPE_STRING or str(raw.get("opening", "og.default")) != "og.default":
		return _error(error)
	var known: Variant = raw.get("known", [])
	if typeof(known) not in [TYPE_ARRAY, TYPE_PACKED_STRING_ARRAY]:
		return _error(error)
	var allowed := _character_fragments(definition)
	var filtered: Array = []
	for id in known:
		if typeof(id) not in [TYPE_STRING, TYPE_STRING_NAME]:
			return _error(error)
		if allowed.has(str(id)) and not filtered.has(str(id)):
			filtered.append(str(id))
	filtered.sort()
	var run := {"_v": 1, "no": int(raw["no"]), "opening": "og.default", "known": filtered}
	if saved and raw != run:
		return _error(error)
	return {"ok": true, "err": "", "run": run}


func save(engine: CardEngine, path: String) -> Dictionary:
	if path.is_empty():
		return _error("bad_args")
	var meta := {"campaign": "ocean_pawn", "stage": chapter_index(), "abs_day": model.state["day"], "cmd_log": engine.command_log()}
	if not model.is_builtin():
		# 信封 meta（ARCH §1.7）：书、段、整局的开局参数、检查点
		meta["campaign"] = campaign_id()
		meta["book"] = str(model.book.get("id", ""))
		meta["book_path"] = str(model.book.get("path", ""))
		meta["segment"] = str(model.state.get("segment", ""))
		meta["start"] = (model.state.get("run", {}).get("start", {}) as Dictionary).duplicate(true)
		meta["replay_base"] = replay_base.duplicate(true)
	return CardSave.write(path, engine.ctx.state, meta)


## 每条有效命令之后（引擎已经记进命令日志、还没自动存档）：多段书的检查点、分岔存档、局外记录。返回 [[路径, 成功], …]
func after_command(engine: CardEngine, before_segment: String, before_scene: String) -> Array:
	var out: Array = []
	if model == null or model.is_builtin():
		return out
	var seg := str(model.state.get("segment", ""))
	if seg != before_segment:
		var n := (model.state.get("run", {}).get("path", []) as Array).size() - 1
		var file := "checkpoint_%02d.json" % n
		var r := save(engine, save_dir + "/" + file)
		out.append([save_dir + "/" + file, bool(r.get("ok", false))])
		if bool(r.get("ok", false)):
			replay_base = {"file": file, "hash": model.hash()}
			engine.clear_command_log()
		write_meta()
	var scene: Dictionary = model.scene()
	if str(scene.get("id", "")) != before_scene:
		for c in scene.get("choices", []):
			if str(c.get("branch", "")) != "":
				var r2 := save(engine, save_dir + "/" + BRANCH_FILE)
				out.append([save_dir + "/" + BRANCH_FILE, bool(r2.get("ok", false))])
				write_meta()
				break
	if str(model.state.get("phase", "")) == "game_over":
		write_meta()
	return out


## 局外记录 napoleon_meta.json（§4.6）：只记解锁了什么。{v:1, endings:{段:[id]}, volumes:{段:[id]}, branches_reached, trunk_cleared, codex}
func write_meta() -> void:
	var meta := read_meta(save_dir)
	var st: Dictionary = model.state
	var path: Array = st.get("run", {}).get("path", [])
	var start := str(model.book.get("start", ""))
	for seg in path:
		if str(seg) != start and not str(seg) in meta["branches_reached"]:
			meta["branches_reached"].append(str(seg))
	if path.size() > 1 or (model.scene().get("choices", []) as Array).any(func(c: Dictionary) -> bool: return str(c.get("branch", "")) != ""):
		meta["trunk_cleared"] = true
	var ending := str(st.get("ending", ""))
	if ending != "":
		var seg := str(st.get("segment", ""))
		var kind := "fixed"
		for e in model.definition.get("endings", []):
			if str(e.get("id", "")) == ending:
				kind = str(e.get("kind", "fixed"))
		var bucket := "volumes" if kind == "volume" else "endings"
		var list: Array = meta[bucket].get(seg, [])
		if not ending in list:
			list.append(ending)
		meta[bucket][seg] = list
	var met: Array = meta["codex"]["companions_met"]
	var comps: Dictionary = st.get("rogue", {}).get("companions", {})
	for c_id in comps:
		if bool(comps[c_id].get("recruited", false)) and not str(c_id) in met:
			met.append(str(c_id))
	DirAccess.make_dir_recursive_absolute(save_dir)
	var f := FileAccess.open(save_dir + "/" + META_FILE, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(meta, "", true))
		f.close()


static func read_meta(dir: String = SAVE_ROOT) -> Dictionary:
	var out := {"v": 1, "endings": {}, "volumes": {}, "branches_reached": [], "trunk_cleared": false, "codex": {"companions_met": []}}
	var p := dir + "/" + META_FILE
	if not FileAccess.file_exists(p):
		return out
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(p))
	if typeof(parsed) != TYPE_DICTIONARY or int(parsed.get("v", 0)) != 1:
		return out
	for key in ["endings", "volumes"]:
		if typeof(parsed.get(key)) == TYPE_DICTIONARY:
			for seg in parsed[key]:
				if typeof(parsed[key][seg]) == TYPE_ARRAY:
					out[key][str(seg)] = (parsed[key][seg] as Array).map(func(x): return str(x))
	if typeof(parsed.get("branches_reached")) == TYPE_ARRAY:
		out["branches_reached"] = (parsed["branches_reached"] as Array).map(func(x): return str(x))
	out["trunk_cleared"] = bool(parsed.get("trunk_cleared", false))
	if typeof(parsed.get("codex")) == TYPE_DICTIONARY and typeof(parsed["codex"].get("companions_met")) == TYPE_ARRAY:
		out["codex"]["companions_met"] = (parsed["codex"]["companions_met"] as Array).map(func(x): return str(x))
	return out


## Unlocks survive removal of the optional branch snapshot. This is only an
## entry gate; deterministic model creation and save replay never consult meta.
static func branch_unlocked(dir: String) -> bool:
	var meta := read_meta(dir)
	return bool(meta.get("trunk_cleared", false)) or not meta.get("branches_reached", []).is_empty() or FileAccess.file_exists(dir + "/" + BRANCH_FILE)


## 标题页用（§3）：局外记录 + 挂起存档的书、段、章、日期 + 有没有分岔存档。只读文件，不装进引擎
static func title_info(dir: String = SAVE_ROOT) -> Dictionary:
	var out := {"meta": read_meta(dir), "suspend": {}, "branch": FileAccess.file_exists(dir + "/" + BRANCH_FILE)}
	if CardSave.exists(dir + "/suspend.json"):
		var env := CardSave.read(dir + "/suspend.json")
		if bool(env.get("ok", false)):
			var m: Dictionary = env.get("meta", {})
			out["suspend"] = {"campaign": str(m.get("campaign", "ocean_pawn")), "book": str(m.get("book", "")),
				"segment": str(m.get("segment", "")), "stage": int(m.get("stage", 0)), "abs_day": int(m.get("abs_day", 0))}
	return out


func dispatch(cmd: StringName, args: Dictionary) -> Dictionary:
	return dispatch_model(model, cmd, args)


## 引擎层命令落到模型上（重放也用这一份，所以是静态的）
static func dispatch_model(m, cmd: StringName, args: Dictionary) -> Dictionary:
	if str(cmd).begins_with("campaign."):
		return m.send(cmd, args)
	var phase := str(m.state["phase"])
	var progress := {&"month.begin": "month_open", &"day.begin": "morning", &"settle.next": "settle",
		&"year.next": "year_jump"}
	if progress.has(cmd):
		if phase != progress[cmd]:
			return _error("bad_phase")
		if not args.is_empty():
			return _error("bad_args")
		return m.send(&"campaign.wait", {})
	if cmd == &"day.end":
		for key in args:
			if str(key) != "confirm" or typeof(args[key]) != TYPE_BOOL:
				return _error("bad_args")
		var result: Dictionary = m.send(&"campaign.wait", {})
		if bool(result.get("ok", false)):
			result["step"] = {"month_open": "begin_month", "morning": "begin_day", "day": "end_day",
				"settle": "next_day", "year_jump": "year_next"}.get(phase, "next_day")
		return result
	if cmd == &"card.choose":
		if args.size() != 2 or typeof(args.get("uid")) != TYPE_STRING or typeof(args.get("choice")) != TYPE_STRING:
			return _error("bad_args")
		var card: Dictionary = View.card(m, args["uid"], true)
		if card.is_empty():
			return _error("unknown_uid")
		for choice in card.get("choices", []):
			if str(choice.get("id", "")) == str(args["choice"]):
				if not bool(choice.get("enabled", false)):
					return _error("choice_disabled")
				return _choice(m, str(args["choice"]))
		return _error("bad_args")
	if cmd == &"card.read":
		if args.size() != 1 or typeof(args.get("uid")) != TYPE_STRING:
			return _error("bad_args")
		if typeof(args.get("uid")) != TYPE_STRING or View.card(m, str(args["uid"]), true).is_empty():
			return _error("unknown_uid")
		return {"ok": true, "err": ""}
	if cmd == &"demand.submit":
		if args.size() != 1 or typeof(args.get("uid")) != TYPE_STRING or not str(args["uid"]).begins_with("demand:"):
			return _error("bad_args")
		var id := str(args["uid"]).trim_prefix("demand:")
		for demand in m.state.get("demands", []):
			if str(demand.get("id", "")) == id and str(demand.get("status", "")) == "fulfilled":
				# The existing demand panel confirms after card.choose; never debit twice.
				return {"ok": true, "err": "", "success": true}
		return m.send(&"campaign.demand", {"id": id, "action": "fulfill"})
	return _error("bad_args")


static func _choice(m, id: String) -> Dictionary:
	var parts := id.split(":")
	if parts.size() < 2 or parts[0] != "action":
		return _error("bad_args")
	var arg := ":".join(parts.slice(2))
	match parts[1]:
		"appraise": return m.send(&"campaign.appraise", {"id": arg})
		"choose": return m.send(&"campaign.choose", {"choice": arg})
		"sign": return m.send(&"campaign.sign", {"sign": arg})
		"wait": return m.send(&"campaign.wait", {})
		"visit": return m.send(&"campaign.visit", {"place": arg})
		"trade": return m.send(&"campaign.trade", {"kind": arg})
		"build": return m.send(&"campaign.build", {})
		"explore": return m.send(&"campaign.explore", {})
		"fund": return m.send(&"campaign.fund", {"support": arg == "yes"})
		"demand": return m.send(&"campaign.demand", {"id": arg, "action": "fulfill"})
		"roll_dice": return m.send(&"campaign.roll_dice", {} if arg == "" else {"steps": int(arg)})
		"pick_route": return m.send(&"campaign.pick_route", {"route": arg})
		"activity": return m.send(&"campaign.activity", {"id": arg})
		"schedule": return m.send(&"campaign.schedule", {"action": arg})
		"recruit": return m.send(&"campaign.recruit", {"id": arg})
		"promote": return m.send(&"campaign.promote", {"id": arg})
		"reserve": return m.send(&"campaign.companion_duty", {"id": arg, "duty": "reserve"})
		"recall": return m.send(&"campaign.companion_duty", {"id": arg, "duty": "field"})
		"use_prop": return m.send(&"campaign.use_prop", {"id": arg})
		"big_fate": return m.send(&"campaign.big_fate", {"choice": arg})
		# 世界地图上的节点牌（A2 的 node:<id> 牌映射到这些动作）
		"map_enter": return m.send(&"campaign.map_enter", {})
		"map_choose": return m.send(&"campaign.map_choose", {"choice": arg})
		"map_appraise": return m.send(&"campaign.map_appraise", {"id": arg})
		"map_build": return m.send(&"campaign.map_build", {})
		"map_pay": return m.send(&"campaign.map_pay", {"how": arg})
		"map_muster": return m.send(&"campaign.map_muster", {})
		"map_roll": return m.send(&"campaign.map_roll", {} if arg == "" else {"steps": int(arg)})
		"map_card": return m.send(&"campaign.map_card", {"index": int(arg)})
		"map_move": return m.send(&"campaign.map_move", {"to": arg})
		"map_scout": return m.send(&"campaign.map_scout", {"node": arg})
	return _error("bad_args")


static func _error(code: String) -> Dictionary:
	return {"ok": false, "err": code}


static func _valid_ui(ui: Dictionary) -> bool:
	if not ui.has("guide"):
		return true
	if typeof(ui["guide"]) != TYPE_DICTIONARY:
		return false
	for step in ui["guide"]:
		var row: Variant = ui["guide"][step]
		if typeof(step) != TYPE_STRING or typeof(row) != TYPE_DICTIONARY:
			return false
		if row.get("status", "shown") not in ["shown", "done"]:
			return false
		for key in ["shows", "abs_day"]:
			if typeof(row.get(key, 0)) != TYPE_INT or int(row.get(key, 0)) < 0:
				return false
	return true
