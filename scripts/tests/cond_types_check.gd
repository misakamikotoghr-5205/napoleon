# 条件类型体检：data/** 里每一条 cond / when 字符串，在 flag() / var() 取到各种类型的值
# （null、空串、字符串、整数、小数、布尔）时都不能求值失败。
# Godot 的 Expression 没有短路：`a or b` 两边都会算，所以 flag('x') == 'abc' 在 flag 是数字时
# 会报 Invalid operands。写法必须是 str(flag('x')) == 'abc'（两边都按字符串比）。
# 用法：被 test_town_shops.gd 调用；也可以单独跑
#   godot --headless -s res://scripts/tests/test_town_shops.gd
extends RefCounted

const Cond = preload("res://scripts/core/cond.gd")
const COND_KEYS := ["cond", "when"]
const ROOT := "res://data"

# 用项目自己的 Cond（同一套函数名改写、同一个 Expression 执行方式），只把取值换成可控的。
# flag() 是任意类型（剧情里 set 的值可能是字符串、整数、JSON 读进来的小数、布尔，没设过是 null），
# 所以要把每种类型都试一遍。var() 的类型是确定的：result 是字符串，*_ok / gave 是布尔，
# town_result 是字典，其余是计数（整数）。
class TypedCond extends "res://scripts/core/cond.gd":
	var fv = null      # flag() 返回什么
	var vmode: int = 0 # var() 取哪一组值
	func _init() -> void:
		super(null, null)
	func c_flag(_name: String):
		return fv
	func c_is(_name: String) -> bool:
		match typeof(fv):
			TYPE_NIL: return false
			TYPE_BOOL: return fv
			TYPE_INT, TYPE_FLOAT: return fv != 0
			TYPE_STRING: return fv != "" and fv != "false"
		return true
	func c_var(name: String):
		if name == "result":
			return "" if vmode == 0 else "accept"
		if name == "money_ok" or name == "town_ok" or name == "gave":
			return vmode == 0
		if name == "town_result":
			return {"status": "active", "outstanding": vmode, "paid": vmode}
		return 0 if vmode == 0 else 7
	func c_stat(_name: String) -> int:
		return 5
	func c_cash() -> int:
		return 100
	func c_day() -> int:
		return 3
	func c_stock_has(_d: String) -> bool:
		return true
	func c_stock_cat(_c: String) -> int:
		return 1
	func c_stock_count() -> int:
		return 2
	func c_trash_has(_d: String) -> bool:
		return false
	func c_inspected(_d: String, _p: String) -> bool:
		return true
	func c_price() -> int:
		return 40
	func c_ask() -> int:
		return 50
	func c_floor() -> int:
		return 30
	func c_suggest() -> int:
		return 40
	func c_selected(_d: String) -> bool:
		return true
	func c_tells(_d: String) -> int:
		return 1
	func c_judged_fake(_d: String) -> bool:
		return false
	func c_rounds() -> int:
		return 2

# null、空串、各种字符串、整数、小数（JSON 读进来的数字都是小数）、布尔
const FLAG_VALUES := [null, "", "x", "fair", "reported", "300", 0, 20, 60, 100, 300, 1.5, 20.0, 60.0, 300.0, true, false]

static func collect() -> Array:
	# [{file, key, text}]
	var out: Array = []
	_scan_dir(ROOT, out)
	return out

static func _scan_dir(path: String, out: Array) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	var names: Array = []
	for n in dir.get_files():
		names.append(n)
	names.sort()
	for n in names:
		if n.ends_with(".json"):
			var full := path.path_join(n)
			var j := JSON.new()
			if j.parse(FileAccess.get_file_as_string(full)) == OK:
				_walk(j.data, full, out)
	var subdirs: Array = []
	for d in dir.get_directories():
		subdirs.append(d)
	subdirs.sort()
	for d in subdirs:
		_scan_dir(path.path_join(d), out)

static func _walk(node, file: String, out: Array) -> void:
	if node is Dictionary:
		for k in node:
			var v = node[k]
			if v is String and COND_KEYS.has(str(k)) and (v as String).strip_edges() != "":
				out.append({"file": file, "key": str(k), "text": v})
			else:
				_walk(v, file, out)
	elif node is Array:
		for v in node:
			_walk(v, file, out)

# 返回错误列表（空 = 全部通过）；stats 里放条件数
static func run(stats: Dictionary = {}) -> Array:
	var errs: Array = []
	var ctx = TypedCond.new()
	var rows: Array = collect()
	var seen := {}
	var checked := 0
	for row in rows:
		var text: String = row["text"]
		if seen.has(text):
			continue
		seen[text] = true
		var e := Expression.new()
		if e.parse(Cond.rewrite(text)) != OK:
			errs.append("%s [%s] 解析失败：%s（%s）" % [row["file"], row["key"], text, e.get_error_text()])
			continue
		var bad := ""
		for fv in FLAG_VALUES:
			for vmode in 2:
				ctx.fv = fv
				ctx.vmode = vmode
				e.execute([], ctx, false)
				if e.has_execute_failed():
					bad = "flag()=%s(%s)：%s" % [var_to_str(fv), type_string(typeof(fv)), e.get_error_text()]
					break
			if bad != "":
				break
		checked += 1
		if bad != "":
			errs.append("%s [%s] 求值失败：%s ← %s" % [row["file"], row["key"], text, bad])
	stats["conds"] = checked
	return errs
