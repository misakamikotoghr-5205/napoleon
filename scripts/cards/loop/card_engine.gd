# 真引擎门面：实现 CardEngineApi；指令/查询分发、busy 防重入、把 ctx.out 里的可见事件按序发到 bus，
# 然后 command_done，最后 view_changed；指令日志交给 CardSave 放进存档信封。
# 主人 G02；W0（Claude）已写好分发、busy、事件顺序与模块安装顺序（这些行为冻结），开局/日循环留给 G02。
# 合同：docs/cards/CARDS_INTERFACES.md §7.2、§7.3（安装顺序）、§7.4、§7.9（G02 loop）。
class_name CardEngine
extends CardEngineApi

var ctx: CardCtx
var _commands: Dictionary = {}   # cmd → {fn: Callable, owner}
var _queries: Dictionary = {}    # q → {fn: Callable, owner}
var _busy: bool = false
var _cmd_log: Array = []         # [[cmd, args], …]（不含 ui.*；不在状态里）

const _ApprenticeInstall = preload("res://scripts/cards/apprentice/apprentice_install.gd")
const _RelicInstall = preload("res://scripts/cards/relic/relic_install.gd")
const _StockInstall = preload("res://scripts/cards/stock/stock_install.gd")
const _LegacyInstall = preload("res://scripts/cards/legacy/legacy_install.gd")
const _OceanBridge = preload("res://scripts/cards/campaign/ocean_bridge.gd")
const _OceanView = preload("res://scripts/cards/campaign/ocean_view.gd")
var _ocean: RefCounted = null


func _init(p_bus: CardEventBus = null) -> void:
	bus = p_bus
	ctx = CardCtx.new()
	ctx.bus = p_bus
	# 模块安装顺序（冻结）：core → rules → economy → ladder → fate → loop。
	# K18 收徒接在这六段之后（合同 1.4），不插入、不重排。
	CardCoreInstall.install(self, ctx)
	CardRulesInstall.install(self, ctx)
	CardEconomyInstall.install(self, ctx)
	CardLadderInstall.install(self, ctx)
	CardFateInstall.install(self, ctx)
	CardLoopInstall.install(self, ctx)
	_ApprenticeInstall.install(self, ctx)
	# Rogue v1 (ROGUE_V1.md): relics, weekly stocktake and sources, run context. Appended after K18; never reorder.
	_RelicInstall.install(self, ctx)
	_StockInstall.install(self, ctx)
	_LegacyInstall.install(self, ctx)


## handler: func(ctx: CardCtx, args: Dictionary) -> Dictionary（必须带 ok/err）
func register_command(cmd: StringName, handler: Callable, owner: String) -> void:
	if _commands.has(cmd):
		push_error("CardEngine: command '%s' already registered by %s (now %s)" % [cmd, _commands[cmd]["owner"], owner])
		return
	_commands[cmd] = {"fn": handler, "owner": owner}


## handler: func(ctx: CardCtx, args: Dictionary) -> Dictionary（只读）
func register_query(q: StringName, handler: Callable, owner: String) -> void:
	if _queries.has(q):
		push_error("CardEngine: query '%s' already registered by %s (now %s)" % [q, _queries[q]["owner"], owner])
		return
	_queries[q] = {"fn": handler, "owner": owner}


# ---------------- CardEngineApi ----------------
func new_game(opts: Dictionary) -> Dictionary:
	return send(&"game.new", opts)


func load_game(path: String) -> Dictionary:
	return send(&"game.load", {"path": path})


func save_game(path: String) -> Dictionary:
	return send(&"game.save", {"path": path})


func view() -> Dictionary:
	if _ocean != null:
		var ocean_view: Dictionary = _OceanView.build(_ocean.model)
		var run: Dictionary = ctx.state.data.get("run", {})
		if not run.is_empty():
			ocean_view["run"] = {"no": int(run["no"]), "opening": str(run["opening"])}
		ocean_view["busy"] = _busy
		return ocean_view
	if ctx.state == null:
		return {"v": 1, "phase": str(CardIds.PH_BOOT), "busy": _busy}
	var v := CardViewModel.build(ctx)
	v["busy"] = _busy
	return v


func send(cmd: StringName, args: Dictionary = {}) -> Dictionary:
	if _busy:
		return {"ok": false, "err": CardIds.ERR_BUSY}
	var legacy_load_path := ""
	var previous_db := ctx.db
	if cmd == &"game.new":
		if args.has("campaign") and str(args["campaign"]) not in ["ocean_pawn", "napoleon", "legacy"]:
			return _reject_command(cmd, args, {"ok": false, "err": CardIds.ERR_BAD_ARGS})
		if _OceanBridge.selected(args):
			return _send_ocean(cmd, args)
	elif cmd == &"game.load":
		if args.keys().any(func(key: Variant) -> bool: return str(key) != "path") or (args.has("path") and (typeof(args["path"]) != TYPE_STRING or str(args["path"]).is_empty())):
			return _reject_command(cmd, args, {"ok": false, "err": CardIds.ERR_BAD_ARGS})
		var default_path: String = _ocean.save_dir + "/suspend.json" if _ocean != null else CardSave.suspend_path()
		var path := str(args.get("path", default_path))
		var envelope := CardSave.read(path)
		if not bool(envelope.get("ok", false)):
			return _reject_command(cmd, args, envelope)
		if (envelope["state"] as CardState).data.has("ocean"):
			return _send_ocean(cmd, args, envelope)
		if str(envelope.get("meta", {}).get("campaign", "")) in ["ocean_pawn", "napoleon"]:
			return _reject_command(cmd, args, {"ok": false, "err": "campaign_mismatch"})
		if int((envelope["state"] as CardState).ns("loop").get("_v", 0)) > 1:
			return _reject_command(cmd, args, {"ok": false, "err": CardIds.ERR_SAVE_NEWER})
		# Legacy saves stay legacy; their currency and story IDs are never reinterpreted.
		legacy_load_path = path
		if _ocean != null:
			ctx.db = null
	elif _ocean != null:
		return _send_ocean(cmd, args)
	if not _commands.has(cmd):
		return {"ok": false, "err": CardIds.ERR_BAD_ARGS}
	if ctx.state == null and cmd != &"game.new" and cmd != &"game.load":
		return {"ok": false, "err": CardIds.ERR_BAD_PHASE}
	var is_ui := str(cmd).begins_with("ui.")
	_busy = true
	ctx.out = []
	var overflow := _overflow_pending(cmd, is_ui)
	var res = {"ok": false, "err": "overflow_pending"} if overflow else (_commands[cmd]["fn"] as Callable).call(ctx, args)
	var result: Dictionary = res if typeof(res) == TYPE_DICTIONARY else {"ok": false, "err": CardIds.ERR_NOT_IMPLEMENTED}
	if not result.has("ok"):
		result["ok"] = false
	if not result.has("err"):
		result["err"] = "" if bool(result["ok"]) else CardIds.ERR_NOT_IMPLEMENTED
	if cmd == &"game.new" and bool(result["ok"]):
		_ocean = null
	if legacy_load_path != "":
		if bool(result["ok"]):
			_ocean = null
			CardSave.set_root(legacy_load_path.get_base_dir())
		else:
			ctx.db = previous_db
	if is_ui:
		ctx.out = []
		_busy = false
		return result
	if not overflow and cmd != &"game.save" and cmd != &"game.load":
		_cmd_log.append([str(cmd), args.duplicate(true)])
	_capture_notices()
	_autosave(cmd, result)
	var events: Array = ctx.out
	ctx.out = []
	# 发事件时仍然 busy：总线回调里同步调用 send() 会得到 err "busy"（§7.2）
	if bus != null:
		var topics := PackedStringArray()
		for ev in events:
			if StringName(ev[0]) == &"view_changed":
				topics.append_array(PackedStringArray(ev[1]) if ev.size() > 1 else PackedStringArray())
				continue
			bus.emit_event(StringName(ev[0]), ev.slice(1))
		bus.command_done.emit(cmd, _visible_args(args), bool(result["ok"]))
		bus.view_changed.emit(topics)
	_busy = false
	return result


func query(q: StringName, args: Dictionary = {}) -> Dictionary:
	if _ocean != null:
		if q == &"guide_progress":
			return {"progress": ctx.state.ns("ui").get("guide", {}).duplicate(true)}
		if q in [&"legacy.harvest", &"legacy.old_ink"]:
			return _ocean.query(self, q, args)
		var answer: Dictionary = _OceanView.query(_ocean.model, q, args)
		if q == &"campaign.run" and not answer.is_empty():
			# 局外记录（篇章解锁、各段结局收集）只由 bridge 读写
			answer["meta"] = _OceanBridge.read_meta(_ocean.save_dir)
		return answer
	if not _queries.has(q):
		return {"ok": false, "err": CardIds.ERR_BAD_ARGS}
	if ctx.state == null:
		return {"ok": false, "err": CardIds.ERR_BAD_PHASE}
	var res = (_queries[q]["fn"] as Callable).call(ctx, args)
	return res if typeof(res) == TYPE_DICTIONARY else {"ok": false, "err": CardIds.ERR_NOT_IMPLEMENTED}


func is_busy() -> bool:
	return _busy


# ---------------- W0 加的公开辅助（列在 PR 里） ----------------
## 指令日志（不含 ui.*），存档信封与 CardReplay 用
func command_log() -> Array:
	return _cmd_log.duplicate(true)


func clear_command_log() -> void:
	_cmd_log = []


func has_command(cmd: StringName) -> bool:
	return _commands.has(cmd) or cmd in _OceanBridge.COMMANDS


func has_query(q: StringName) -> bool:
	return _queries.has(q) or q in _OceanBridge.QUERIES


## Keep the existing signal order and busy guard for the new campaign as well.
func _send_ocean(cmd: StringName, args: Dictionary, envelope: Dictionary = {}) -> Dictionary:
	_busy = true
	var previous: Dictionary = view()
	var before_scene := str(_ocean.model.scene().get("id", "")) if _ocean != null else ""
	var before_chapter: int = _ocean.chapter_index() if _ocean != null else -1
	var before_segment := str(_ocean.model.state.get("segment", "")) if _ocean != null else ""
	var result: Dictionary
	var saved_path := ""
	var autosave_events: Array = []
	if cmd == &"game.new":
		var candidate := _OceanBridge.new()
		result = candidate.start(self, args)
		if bool(result.get("ok", false)):
			_ocean = candidate
	elif cmd == &"game.load" or cmd == &"game.retry_stage":
		if cmd == &"game.retry_stage" and not args.is_empty():
			result = {"ok": false, "err": CardIds.ERR_BAD_ARGS}
		else:
			var default_path: String = _ocean.save_dir + "/suspend.json" if _ocean != null else CardSave.suspend_path()
			var path := str(args.get("path", default_path))
			if cmd == &"game.retry_stage":
				path = _ocean.save_dir + "/stage_%02d.json" % _ocean.chapter_index()
				envelope = CardSave.read(path)
			var candidate := _OceanBridge.new()
			result = candidate.restore(self, path, envelope)
			if bool(result.get("ok", false)):
				_ocean = candidate
	elif cmd == &"game.save":
		if args.keys().any(func(key: Variant) -> bool: return str(key) != "path") or (args.has("path") and typeof(args["path"]) != TYPE_STRING):
			result = {"ok": false, "err": CardIds.ERR_BAD_ARGS}
		else:
			saved_path = str(args.get("path", _ocean.save_dir + "/suspend.json"))
			result = _ocean.save(self, saved_path)
	elif cmd == &"ui.guide":
		result = CardCoreInstall._cmd_ui_guide(ctx, args)
		_busy = false
		return result
	else:
		result = _ocean.dispatch(cmd, args)
	var ok := bool(result.get("ok", false))
	if ok and _ocean != null:
		_ocean.sync(self)
		if cmd not in [&"game.save", &"game.load", &"game.retry_stage"]:
			_cmd_log.append([str(cmd), args.duplicate(true)])
			if cmd != &"game.new":
				# 多段书：段切换写检查点（命令日志从这里重新算起）、进分岔场景写 branch.json、收场写局外记录
				autosave_events.append_array(_ocean.after_command(self, before_segment, before_scene))
		if cmd not in [&"game.save", &"game.load"]:
			var suspend_path: String = _ocean.save_dir + "/suspend.json"
			var autosave: Dictionary = _ocean.save(self, suspend_path)
			autosave_events.append([suspend_path, bool(autosave.get("ok", false))])
			if not bool(autosave.get("ok", false)):
				result["autosave_error"] = str(autosave.get("err", "save_failed"))
			if cmd == &"game.new" or before_chapter != _ocean.chapter_index():
				var stage_path: String = _ocean.save_dir + "/stage_%02d.json" % _ocean.chapter_index()
				var stage_save: Dictionary = _ocean.save(self, stage_path)
				autosave_events.append([stage_path, bool(stage_save.get("ok", false))])
	var after: Dictionary = view()
	if bus != null:
		if ok:
			if str(previous.get("phase", "boot")) != str(after.get("phase", "boot")):
				bus.phase_changed.emit(StringName(str(previous.get("phase", "boot"))), StringName(str(after.get("phase", "boot"))))
			var old_money := int(previous.get("money", {}).get("amount", 0))
			var new_money := int(after.get("money", {}).get("amount", 0))
			if old_money != new_money:
				bus.money_changed.emit(old_money, new_money, "ocean.treasury")
			if cmd in [&"card.choose", &"card.read"]:
				bus.card_left.emit(str(args.get("uid", "")), &"resolved")
			if _ocean != null and before_scene != str(_ocean.model.scene().get("id", "")):
				var uids := PackedStringArray()
				for card in after.get("hand", []): uids.append(str(card["uid"]))
				bus.cards_dealt.emit(uids)
			if str(after.get("phase", "")) == "game_over" and str(previous.get("phase", "")) != "game_over":
				bus.game_over.emit(StringName(str(after.get("game_over_reason", ""))))
		if saved_path != "":
			bus.saved.emit(saved_path, ok)
		for event in autosave_events:
			bus.saved.emit(str(event[0]), bool(event[1]))
		bus.command_done.emit(cmd, _visible_args(args), ok)
		bus.view_changed.emit(PackedStringArray(["campaign"]))
	_busy = false
	return result


func _reject_command(cmd: StringName, args: Dictionary, result: Dictionary) -> Dictionary:
	_busy = true
	if bus != null:
		bus.command_done.emit(cmd, _visible_args(args), false)
		bus.view_changed.emit(PackedStringArray())
	_busy = false
	return result


func command_owner(cmd: StringName) -> String:
	return str(_commands[cmd]["owner"]) if _commands.has(cmd) else ""


func query_owner(q: StringName) -> String:
	return str(_queries[q]["owner"]) if _queries.has(q) else ""


## Restore replay history from the save envelope; state hashes never include this log.
func restore_command_log(log: Array) -> void:
	_cmd_log = log.duplicate(true)

func _overflow_pending(cmd: StringName, is_ui: bool) -> bool:
	if ctx.state == null or is_ui or cmd in [&"card.discard", &"day.end", &"game.save", &"game.load", &"game.retry_stage"]:
		return false
	return CardPiles.overflow_uid(ctx) != ""

func _capture_notices() -> void:
	if ctx.state == null:
		return
	var rows: Array = ctx.state.ns("loop").get("notices", [])
	# TODO(design): visible notice events also enter the current morning's notice board.
	for ev in ctx.out:
		if ev.size() >= 3 and StringName(ev[0]) == &"notice":
			rows.append({"key": str(ev[1]), "args": preload("res://scripts/cards/loop/loop_reports.gd").integer_args(ev[2])})
	ctx.state.ns("loop")["notices"] = rows

func _autosave(cmd: StringName, result: Dictionary) -> void:
	if not bool(result["ok"]) or ctx.state == null:
		return
	var path := ""
	var loop := ctx.state.ns("loop")
	if (cmd in [&"game.new", &"year.next"] or (cmd == &"day.end" and result.get("step") == "year_next")) and str(loop.get("phase", "")) == "month_open":
		path = CardSave.stage_path(int(loop.get("stage", 0)))
	elif (cmd in [&"month.begin", &"settle.next"] or (cmd == &"day.end" and result.get("step") in ["begin_month", "next_day"])) and str(loop.get("phase", "")) == "morning":
		path = CardSave.suspend_path()
	if path != "":
		var saved := CardSave.write(path, ctx.state, {"stage": int(loop.get("stage", 0)), "abs_day": ctx.abs_day(), "cmd_log": _cmd_log})
		ctx.emit(&"saved", [path, bool(saved.get("ok", false))])


# Contract §7.5: commands carry hidden input such as the new-game seed; only visible arguments reach the bus.
func _visible_args(value: Variant) -> Variant:
	if typeof(value) == TYPE_DICTIONARY:
		var out: Dictionary = {}
		for key in value.keys():
			if not CardViewModel._FORBIDDEN_SET.has(str(key)):
				out[key] = _visible_args(value[key])
		return out
	if typeof(value) == TYPE_ARRAY:
		var out: Array = []
		for row in value:
			out.append(_visible_args(row))
		return out
	return value


## Read-only diagnostic for simulation/replay; never exposes the state object or hidden values.
func state_hash() -> String:
	return ctx.state.hash() if ctx.state != null else ""
