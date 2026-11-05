# Mock 引擎：同一个 CardEngineApi，界面任务对着它开发（第 1 波）。两种用法：
#  ① 夹具模式 load_fixture(path)：按夹具回放（§7.7）——view 原样给；查询按键 "<查询名>|<参数 JSON，键排序、无空格>" 查表；
#     指令按 responses 找第一条 cmd 相同、match 的键值都相等的（"*" 兜底；W0 扩展："once": true 用过一次就不再匹配），
#     套 patch（set / append / remove_from / merge；path "" 表示整个视图）、发 events，自动补 command_done 与 view_changed。
#  ② 情景模式（不加载夹具直接 new_game）：mock_scenario.gd 里的小牌局，可以连着玩好几天（--cards 默认就是它）。
# 指引查询：guide_data 读 data/cards/guide/*.json（没有就退回例子集；夹具写 "guide": "examples" 时直接读例子集），
# guide_progress 从夹具的 "guide_progress" 取、ui.guide 在内存里更新；firsts 从夹具的查询取（情景模式自己记）。
# 所有收到的指令记在 sent（界面测试断言用）。随机只用 c.mock。主人 W0（Claude）。合同：docs/cards/CARDS_INTERFACES.md §7.7。
class_name MockCardEngine
extends CardEngineApi

const Scenario = preload("res://scripts/cards/mock/mock_scenario.gd")
const FIXTURE_DIR := "res://scripts/cards/mock/fixtures"

## 收到过的 [cmd, args]（含 ui.*），界面测试断言用
var sent: Array = []
var fixture_path: String = ""
## 例子集的数据库（CardText 用它给【稿】+ brief；情景模式的牌也来自它）
var db: CardDB = null

var _fx: Dictionary = {}
var _view: Dictionary = {}
var _used: Dictionary = {}           # 用过的 once 响应下标
var _progress: Dictionary = {}       # guide_progress
var _guide_data: Dictionary = {}
## W0 的测试用：Engine 的元数据 EXAMPLE_GUIDE_META 为真时 guide_data 只读例子集（真数据里已有 K16 的步骤，W0 测试不该跟着变）。
const EXAMPLE_GUIDE_META := &"cards_mock_example_guide_only"
var _scn = null                      # 情景（mock_scenario.gd）
var _busy: bool = false


func _init(p_bus: CardEventBus = null) -> void:
	bus = p_bus
	db = CardDB.load_all(CardDB.DEFAULT_ROOT, {"only_examples": true})
	CardText.setup(db)


## 加载夹具（res:// 路径；只写文件名时到 scripts/cards/mock/fixtures/ 下找）
func load_fixture(path: String) -> void:
	if not path.contains("/"):
		path = "%s/%s%s" % [FIXTURE_DIR, path, "" if path.ends_with(".json") else ".json"]
	var d = CardDB.read_json(path)
	if typeof(d) != TYPE_DICTIONARY:
		push_error("MockCardEngine: cannot read fixture %s" % path)
		return
	fixture_path = path
	_fx = CardState.int_restore(d)
	_scn = null
	_used = {}
	_view = (_fx.get("view", {}) as Dictionary).duplicate(true)
	_progress = (_fx.get("guide_progress", {}) as Dictionary).duplicate(true)
	_guide_data = {}


## 夹具模式：回到夹具的 view；情景模式：opts {seed, stage} 开一局（阶段 month_open，要求开本月运势轮盘）
func new_game(opts: Dictionary) -> Dictionary:
	sent.append(["game.new", opts.duplicate(true)])
	if not _fx.is_empty():
		_view = (_fx.get("view", {}) as Dictionary).duplicate(true)
		_used = {}
		_emit_all([], &"game.new", opts, true)
		return {"ok": true, "err": ""}
	_scn = Scenario.new(db, opts)
	_scn.start()
	_emit_all(_scn.events, &"game.new", opts, true)
	return {"ok": true, "err": ""}


func load_game(path: String) -> Dictionary:
	sent.append(["game.load", {"path": path}])
	return {"ok": true, "err": "", "meta": {}}


func save_game(path: String) -> Dictionary:
	sent.append(["game.save", {"path": path}])
	return {"ok": true, "err": ""}


func view() -> Dictionary:
	var v: Dictionary = _scn.view() if _scn != null else _view.duplicate(true)
	v["busy"] = _busy
	return v


func send(cmd: StringName, args: Dictionary = {}) -> Dictionary:
	if _busy:
		return {"ok": false, "err": CardIds.ERR_BUSY}
	sent.append([str(cmd), args.duplicate(true)])
	if str(cmd).begins_with("ui."):
		return _ui(cmd, args)
	_busy = true
	var result: Dictionary
	var events: Array = []
	if _scn != null:
		result = _scn.send(str(cmd), args)
		events = _scn.events
	else:
		var r := _respond(cmd, args)
		result = r[0]
		events = r[1]
	_emit_all(events, cmd, args, bool(result.get("ok", false)))
	_busy = false
	return result


func query(q: StringName, args: Dictionary = {}) -> Dictionary:
	match q:
		&"guide_data":
			return _guide()
		&"guide_progress":
			return {"progress": _progress.duplicate(true)}
		&"guide_conds":
			var out: Dictionary = {}
			for id in args.get("ids", []):
				out[str(id)] = true
			return out
	if _scn != null:
		return _scn.query(str(q), args)
	var key := query_key(q, args)
	var qs: Dictionary = _fx.get("queries", {})
	if qs.has(key):
		return (qs[key] as Dictionary).duplicate(true)
	return {"ok": false, "err": CardIds.ERR_NOT_IMPLEMENTED}


func is_busy() -> bool:
	return _busy


## 查询键的唯一写法：<查询名>|<参数的 JSON，键排序、无空格>（没有参数写 |{}）
static func query_key(q: StringName, args: Dictionary) -> String:
	return "%s|%s" % [q, JSON.stringify(args, "", true)]


## W0 扩展（列在 PR 里）：情景模式的状态快照，夹具生成器用
func scenario():
	return _scn


# ---------------- 内部 ----------------
func _ui(cmd: StringName, args: Dictionary) -> Dictionary:
	if cmd != &"ui.guide":
		return {"ok": false, "err": CardIds.ERR_BAD_ARGS}
	var step := str(args.get("step", ""))
	var status := str(args.get("status", ""))
	if step == "" or not (status == "shown" or status == "done"):
		return {"ok": false, "err": CardIds.ERR_BAD_ARGS}
	var row: Dictionary = _progress.get(step, {"shows": 0, "status": "shown", "abs_day": 0})
	if status == "shown":
		row["shows"] = int(row.get("shows", 0)) + 1
	if str(row.get("status", "")) != "done":
		row["status"] = status
	row["abs_day"] = int(view().get("date", {}).get("abs_day", 0))
	_progress[step] = row
	return {"ok": true, "err": ""}


func _respond(cmd: StringName, args: Dictionary) -> Array:
	var rows: Array = _fx.get("responses", [])
	for i in range(rows.size()):
		var r: Dictionary = rows[i]
		if _used.has(i):
			continue
		var rc := str(r.get("cmd", ""))
		if rc != str(cmd) and rc != "*":
			continue
		var m: Dictionary = r.get("match", {})
		var hit := true
		for k in m.keys():
			if not args.has(k) or _canon(args[k]) != _canon(m[k]):
				hit = false
				break
		if not hit:
			continue
		if bool(r.get("once", false)):
			_used[i] = true
		for p in r.get("patch", []):
			_patch(p)
		var result: Dictionary = (r.get("result", {"ok": true, "err": ""}) as Dictionary).duplicate(true)
		if not result.has("ok"):
			result["ok"] = true
		if not result.has("err"):
			result["err"] = ""
		return [result, (r.get("events", []) as Array).duplicate(true)]
	return [{"ok": false, "err": CardIds.ERR_NOT_IMPLEMENTED}, []]


## 比较用的规范写法：整数值的浮点当整数、字典按键排序（夹具读回来的数是浮点）
static func _canon(v) -> String:
	return JSON.stringify(CardState.int_restore(v), "", true)


func _patch(p: Dictionary) -> void:
	var op := str(p.get("op", ""))
	var path := str(p.get("path", ""))
	if path == "" and op == "set":
		_view = (p.get("value", {}) as Dictionary).duplicate(true)
		return
	var parts := path.split(".", false)
	var parent = _view
	for i in range(parts.size() - 1):
		if typeof(parent) != TYPE_DICTIONARY:
			return
		if not parent.has(parts[i]):
			parent[parts[i]] = {}
		parent = parent[parts[i]]
	if typeof(parent) != TYPE_DICTIONARY:
		return
	var leaf := parts[parts.size() - 1] if parts.size() > 0 else ""
	var target = parent.get(leaf) if leaf != "" else _view
	match op:
		"set":
			parent[leaf] = p.get("value")
		"append":
			if typeof(target) == TYPE_ARRAY:
				(target as Array).append(p.get("value"))
		"remove_from":
			if typeof(target) == TYPE_ARRAY:
				var uid := str(p.get("uid", ""))
				var keep: Array = []
				for x in target:
					if not (typeof(x) == TYPE_DICTIONARY and str(x.get("uid", "")) == uid) and str(x) != uid:
						keep.append(x)
				parent[leaf] = keep
		"merge":
			if typeof(target) == TYPE_DICTIONARY:
				(target as Dictionary).merge(p.get("value", {}), true)
		_:
			push_error("MockCardEngine: unknown patch op '%s'" % op)


## 按顺序发事件；在最后的 view_changed 前补 command_done；没有 view_changed 补一条
func _emit_all(events: Array, cmd: StringName, args: Dictionary, ok: bool) -> void:
	if bus == null:
		return
	var topics := PackedStringArray()
	for ev in events:
		if typeof(ev) != TYPE_ARRAY or (ev as Array).is_empty():
			continue
		var name := StringName(str(ev[0]))
		if name == &"view_changed":
			topics.append_array(PackedStringArray(ev[1]) if ev.size() > 1 else PackedStringArray())
			continue
		if name == &"command_done":
			continue
		bus.emit_event(name, (ev as Array).slice(1))
	bus.command_done.emit(cmd, args, ok)
	bus.view_changed.emit(topics)


func _guide() -> Dictionary:
	if not _guide_data.is_empty():
		return _guide_data.duplicate(true)
	var use_examples := bool(Engine.get_meta(EXAMPLE_GUIDE_META, false)) or str(_fx.get("guide", "")) == "examples"
	if not use_examples:
		var real := CardDB.load_all(CardDB.DEFAULT_ROOT, {})
		_guide_data = CardCoreInstall.guide_data_of(real)
		if (_guide_data.get("steps", []) as Array).is_empty():
			use_examples = true
	if use_examples:
		_guide_data = CardCoreInstall.guide_data_of(db)
	return _guide_data.duplicate(true)
