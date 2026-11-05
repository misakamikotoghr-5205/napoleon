# 条件 op 登记表。{} 为真；单键对象；all/any/not 由 G03 登记（W0 的 G03 桩里已有能用的组合）。
# 主人 G01；W0 写了能用的版本。合同：docs/cards/CARDS_INTERFACES.md §5.1、§5.3、§7.3。
class_name CardConds
extends RefCounted

var _conds: Dictionary = {}   # op → {fn: Callable, shape: Callable, owner: String}


## fn: func(ctx: CardCtx, value) -> bool；shape 用 CardDslShapes.shape(op, true)
func register(op: StringName, fn: Callable, shape: Callable, owner: String) -> void:
	if _conds.has(op):
		push_error("CardConds: op '%s' already registered by %s (now %s)" % [op, _conds[op]["owner"], owner])
		return
	_conds[op] = {"fn": fn, "shape": shape, "owner": owner}


func test(ctx: CardCtx, cond) -> bool:
	if cond == null:
		return true
	if typeof(cond) != TYPE_DICTIONARY:
		push_error("CardConds.test: condition is not an object")
		return false
	if cond.is_empty():
		return true
	if cond.size() != 1:
		push_error("CardConds.test: condition must have exactly one key")
		return false
	var op := StringName(str(cond.keys()[0]))
	if not _conds.has(op):
		push_error("CardConds.test: unknown condition op '%s'" % op)
		return false
	return bool((_conds[op]["fn"] as Callable).call(ctx, cond[cond.keys()[0]]))


func validate(cond) -> String:
	if typeof(cond) != TYPE_DICTIONARY:
		return "condition must be an object"
	if cond.is_empty():
		return ""
	if cond.size() != 1:
		return "condition must have exactly one key"
	var op := StringName(str(cond.keys()[0]))
	if not _conds.has(op):
		return "unknown condition op '%s'" % op
	return str((_conds[op]["shape"] as Callable).call(cond[cond.keys()[0]]))


func known() -> PackedStringArray:
	var out := PackedStringArray()
	for k in _conds.keys():
		out.append(str(k))
	out.sort()
	return out
