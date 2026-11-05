# 效果 op 登记表（合同里的 card_registries.gd 之一；GDScript 一个文件只能有一个 class_name，所以五个登记表各占一个文件）。
# 主人 G01；W0 写了能用的版本。合同：docs/cards/CARDS_INTERFACES.md §5.1、§7.3。
class_name CardOps
extends RefCounted

var _ops: Dictionary = {}   # op → {handler: Callable, shape: Callable, owner: String}


## handler: func(ctx: CardCtx, eff: Dictionary, source: String) -> void；shape 用 CardDslShapes.shape(op)
func register(op: StringName, handler: Callable, shape: Callable, owner: String) -> void:
	if _ops.has(op):
		push_error("CardOps: op '%s' already registered by %s (now %s)" % [op, _ops[op]["owner"], owner])
		return
	_ops[op] = {"handler": handler, "shape": shape, "owner": owner}


## 按顺序执行；第 i 个效果的来源路径 = source + "/" + str(i)（嵌套的 then/else 由 op 自己往后接）
func run(ctx: CardCtx, effects: Array, source: String) -> void:
	for i in range(effects.size()):
		var eff = effects[i]
		if typeof(eff) != TYPE_DICTIONARY:
			push_error("CardOps.run: effect %s/%d is not an object" % [source, i])
			continue
		var op := StringName(str(eff.get("op", "")))
		if not _ops.has(op):
			push_error("CardOps.run: unknown op '%s' at %s/%d" % [op, source, i])
			continue
		(_ops[op]["handler"] as Callable).call(ctx, eff, "%s/%d" % [source, i])


## 空串 = 合法；否则错误说明（校验器 V10 用）
func validate(effect: Dictionary) -> String:
	var op := StringName(str(effect.get("op", "")))
	if not _ops.has(op):
		return "unknown effect op '%s'" % op
	return str((_ops[op]["shape"] as Callable).call(effect))


func known() -> PackedStringArray:
	var out := PackedStringArray()
	for k in _ops.keys():
		out.append(str(k))
	out.sort()
	return out


func owner_of(op: StringName) -> String:
	return str(_ops[op]["owner"]) if _ops.has(op) else ""
