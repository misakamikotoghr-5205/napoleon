# 剧情条件求值上下文（docs/INTERFACES.md §5.1）。
# 条件字符串用 Godot Expression 执行，base_instance 就是本对象，所以条件里只能调用这里公开的函数。
extends RefCounted

var world
var director
var session = null   # 当前柜台会话（可能为空）

func _init(p_world, p_director) -> void:
	world = p_world
	director = p_director

func c_flag(name: String):
	return world.flags.get(name, null)

func c_is(name: String) -> bool:
	var v = world.flags.get(name, null)
	if v == null:
		return false
	match typeof(v):
		TYPE_BOOL: return v
		TYPE_INT, TYPE_FLOAT: return v != 0
		TYPE_STRING: return v != "" and v != "false"
	return true

func c_stat(name: String) -> int:
	return world.stat(name)

func c_cash() -> int:
	return world.cash()

func c_day() -> int:
	return world.day

func c_stock_has(def_id: String) -> bool:
	return world.ledger.find_item(def_id, "stock") != ""

func c_stock_cat(cat: String) -> int:
	var n := 0
	for iid in world.ledger.items_at("stock"):
		if str(world.ledger.items[iid].get("cat", "")) == cat:
			n += 1
	return n

func c_stock_count() -> int:
	return world.ledger.items_at("stock").size()

func c_trash_has(def_id: String) -> bool:
	return world.ledger.find_item(def_id, "trash") != ""

func c_inspected(def_id: String, part_id: String) -> bool:
	if session != null and session.is_inspected(def_id, part_id):
		return true
	return world.flags.get("_insp_%s_%s" % [def_id, part_id], false)

func c_var(name: String):
	if name == "result" and session != null:
		return session.result
	if session != null and session.vars.has(name):
		return session.vars[name]
	return director.vars.get(name, "" if name == "result" else 0)

# ---- 只在柜台会话里有意义 ----
func c_price() -> int:
	return session.price if session != null else 0

func c_ask() -> int:
	return session.ask if session != null else 0

func c_floor() -> int:
	return session.floor_v if session != null else 0

func c_suggest() -> int:
	return session.suggestion if session != null else 0

func c_selected(def_id: String) -> bool:
	if session == null:
		return false
	var iid: String = session.iid_of(def_id)
	return iid != "" and session.selected.get(iid, false)

func c_tells(def_id: String) -> int:
	return session.tells_found(def_id) if session != null else 0

func c_judged_fake(def_id: String) -> bool:
	if session == null:
		return false
	var iid: String = session.iid_of(def_id)
	return iid != "" and session.judged.get(iid, "") == "fake"

func c_rounds() -> int:
	return session.rounds if session != null else 0

# ---- 求值 ----
static var _cache: Dictionary = {}
const FUNCS = ["flag", "is", "stat", "cash", "day", "stock_has", "stock_cat", "stock_count", "trash_has", "inspected", "var", "price", "ask", "floor", "suggest", "selected", "tells", "judged_fake", "rounds"]
static var _re: RegEx = null

static func clear_cache() -> void:
	_cache.clear()
	_re = null

# 条件里的函数名（is / var / floor 与 GDScript 关键字或内建冲突）统一改写成 c_ 前缀
static func rewrite(expr_text: String) -> String:
	if _re == null:
		_re = RegEx.new()
		_re.compile("(?<![A-Za-z0-9_.])(" + "|".join(FUNCS) + ")\\s*\\(")
	return _re.sub(expr_text, "c_$1(", true)

func eval(expr_text: String):
	if expr_text.strip_edges() == "":
		return true
	var e: Expression = _cache.get(expr_text, null)
	if e == null:
		e = Expression.new()
		var err := e.parse(rewrite(expr_text))
		if err != OK:
			push_error("条件解析失败：%s（%s）" % [expr_text, e.get_error_text()])
			return null
		_cache[expr_text] = e
	var r = e.execute([], self, false)
	if e.has_execute_failed():
		push_error("条件执行失败：%s（%s）" % [expr_text, e.get_error_text()])
		return null
	return r

func test(expr_text: String) -> bool:
	var r = eval(expr_text)
	if r == null:
		return false
	return bool(r)
