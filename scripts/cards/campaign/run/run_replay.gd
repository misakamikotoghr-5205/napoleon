## 命令日志重放（WORLD_MAP_DESIGN §6.7、ARCH §1.7）：
##   rebuild(envelope, dir, make, dispatch) 从开局（日志第一条 game.new 的参数，或 meta.start）或检查点（meta.replay_base，
##     递归重建）出发，把信封里的命令逐条在**当前数据**上重放，返回 {ok, err, at, model}；
##   verify(envelope, dir, make, dispatch) 重放后和信封里的状态比哈希，返回 {ok, err, at, want, got}。
## 数据改过（定义哈希不符）时 bridge 用 rebuild 接续旧存档；每一步都成功才接受，有一步失败就报 replay_failed。
## make(args) -> {ok, err, model}：按 game.new 的参数造一个开好局的战役模型（bridge 提供）；
## dispatch(model, cmd, args) -> {ok, err}：把引擎层的命令（card.choose、day.end、campaign.* …）落到模型上（bridge 提供）。
## 没有 class_name，别处 preload。只读存档文件，不写。
extends RefCounted

const RunBook = preload("res://scripts/cards/campaign/run/run_book.gd")
const MAX_DEPTH := 16


static func rebuild(envelope: Dictionary, dir: String, make: Callable, dispatch: Callable, depth: int = 0) -> Dictionary:
	if depth > MAX_DEPTH:
		return _fail("replay_base_loop", -1)
	var meta: Dictionary = envelope.get("meta", {}) if typeof(envelope.get("meta")) == TYPE_DICTIONARY else {}
	var log: Array = envelope.get("cmd_log", []) if typeof(envelope.get("cmd_log")) == TYPE_ARRAY else []
	for entry in log:
		if typeof(entry) != TYPE_ARRAY or (entry as Array).size() != 2 or typeof(entry[0]) != TYPE_STRING or typeof(entry[1]) != TYPE_DICTIONARY:
			return _fail("bad_command_log", -1)
	var model = null
	var first := 0
	var base = meta.get("replay_base", {})
	if typeof(base) == TYPE_DICTIONARY and not (base as Dictionary).is_empty():
		var file := str(base.get("file", ""))
		if file.is_empty() or file.contains("/") or file.contains(".."):
			return _fail("replay_base_missing", -1)
		var benv := CardSave.read(dir.path_join(file))
		if not bool(benv.get("ok", false)):
			return _fail("replay_base_missing", -1)
		var b := rebuild(benv, dir, make, dispatch, depth + 1)
		if not bool(b["ok"]):
			return b
		model = b["model"]
	else:
		var args = null
		if not log.is_empty() and str(log[0][0]) == "game.new":
			args = (log[0][1] as Dictionary).duplicate(true)
			# A later release may change the default book or an alias. Replay
			# against the path resolved when this run started, not today's default.
			var logged_book := str(args.get("book", ""))
			var pinned_book := str(meta.get("start", {}).get("book", "")) if typeof(meta.get("start")) == TYPE_DICTIONARY else ""
			if (pinned_book.begins_with("res://") or pinned_book.begins_with("user://")) and not (logged_book.begins_with("res://") or logged_book.begins_with("user://")):
				args["book"] = pinned_book
			first = 1
		elif typeof(meta.get("start")) == TYPE_DICTIONARY:
			args = start_args(meta["start"])
		if typeof(args) != TYPE_DICTIONARY:
			return _fail("replay_no_start", -1)
		var made: Dictionary = make.call(RunBook.normalise(args))
		if not bool(made.get("ok", false)):
			return _fail(str(made.get("err", "replay_failed")), 0)
		model = made["model"]
	for i in range(first, log.size()):
		var cmd := str(log[i][0])
		if cmd.begins_with("game.") or cmd.begins_with("ui."):
			continue
		var res: Dictionary = dispatch.call(model, StringName(cmd), RunBook.normalise(log[i][1]))
		if not bool(res.get("ok", false)):
			return _fail(str(res.get("err", "replay_failed")), i)
	return {"ok": true, "err": "", "at": log.size(), "model": model}


## 重放并核对：信封里存的战役状态（state.ocean）和重放出来的哈希相等
static func verify(envelope: Dictionary, dir: String, make: Callable, dispatch: Callable) -> Dictionary:
	var want := saved_hash(envelope)
	var r := rebuild(envelope, dir, make, dispatch)
	if not bool(r["ok"]):
		return {"ok": false, "err": str(r["err"]), "at": int(r["at"]), "want": want, "got": ""}
	var got: String = r["model"].hash()
	return {"ok": got == want, "err": "" if got == want else "hash_mismatch", "at": int(r["at"]), "want": want, "got": got}


## 信封里战役状态的哈希（和 OceanCampaign.hash() 同一种算法；读盘来的浮点先归一成整数）
static func saved_hash(envelope: Dictionary) -> String:
	var st = envelope.get("state")
	var data: Dictionary = {}
	if st is CardState:
		data = (st as CardState).data
	elif typeof(st) == TYPE_DICTIONARY:
		data = st
	var ocean = data.get("ocean", {})
	if typeof(ocean) != TYPE_DICTIONARY:
		return ""
	return JSON.stringify(RunBook.normalise(ocean), "", true).sha256_text()


## run.start（{book, segment, stage, seed, carry}）→ game.new 的参数
static func start_args(start: Dictionary) -> Dictionary:
	var out := {"seed": int(start.get("seed", 1)), "stage": int(start.get("stage", 0))}
	var book := str(start.get("book", ""))
	if book != "":
		out["campaign"] = "napoleon"
		out["book"] = book
		if str(start.get("segment", "")) != "":
			out["segment"] = str(start["segment"])
		if str(start.get("carry", "")) == "branch_point":
			out.erase("segment")
			out.erase("stage")
			out["entry"] = "branch_point"
	else:
		out["campaign"] = "ocean_pawn"
	return out


static func _fail(err: String, at: int) -> Dictionary:
	return {"ok": false, "err": err, "at": at, "model": null}
