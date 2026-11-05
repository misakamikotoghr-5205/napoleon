# 生命周期钩子登记表（钩子名与 priority 分配见合同 §7.3 的钩子表、CardIds.HOOKS）。
# 主人 G01；W0 写了能用的版本。合同：docs/cards/CARDS_INTERFACES.md §7.3。
class_name CardHooks
extends RefCounted

var _hooks: Dictionary = {}   # name → [{fn, priority, owner, seq}]
var _seq: int = 0


## fn: func(ctx: CardCtx, args: Dictionary) -> void
func on(name: StringName, fn: Callable, priority: int, owner: String) -> void:
	if not _hooks.has(name):
		_hooks[name] = []
	_seq += 1
	(_hooks[name] as Array).append({"fn": fn, "priority": priority, "owner": owner, "seq": _seq})
	(_hooks[name] as Array).sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a["priority"]) != int(b["priority"]):
			return int(a["priority"]) < int(b["priority"])
		return int(a["seq"]) < int(b["seq"]))


## 按 priority 从小到大，同 priority 按登记顺序
func fire(ctx: CardCtx, name: StringName, args: Dictionary = {}) -> void:
	for h in _hooks.get(name, []).duplicate():
		(h["fn"] as Callable).call(ctx, args)


func listeners(name: StringName) -> Array:
	var out: Array = []
	for h in _hooks.get(name, []):
		out.append([int(h["priority"]), str(h["owner"])])
	return out
