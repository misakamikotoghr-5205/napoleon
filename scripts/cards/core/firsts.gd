# 新手指引的引擎一侧：某机制第一次出现时记进 core.firsts 并发 first_time（不管指引开没开都记、都发；进状态哈希）。
# 主人 G01；W0 写了能用的版本。合同：docs/cards/CARDS_INTERFACES.md §7.10.6、§7.10.10。
class_name CardFirsts
extends RefCounted


## mech 必须在 CardIds.FIRSTS 里（否则 push_error）。core.firsts 里还没有它 → 记 {mech: abs_day}、
## ctx.emit(&"first_time", [mech, args])、返回 true；已经有了 → 什么都不做、返回 false。
## args 只放看得见的（uid def kind person no）。
static func mark(ctx: CardCtx, mech: StringName, args: Dictionary = {}) -> bool:
	if not CardIds.FIRSTS.has(mech):
		push_error("CardFirsts.mark: '%s' is not in CardIds.FIRSTS" % mech)
		return false
	var core := ctx.state.ns("core")
	if not core.has("firsts"):
		core["firsts"] = {}
	var firsts: Dictionary = core["firsts"]
	if firsts.has(str(mech)):
		return false
	firsts[str(mech)] = ctx.abs_day()
	var shown: Dictionary = {}
	for k in ["uid", "def", "kind", "person", "no"]:
		if args.has(k):
			shown[k] = args[k]
	ctx.emit(&"first_time", [mech, shown])
	return true


## core.firsts 的只读副本
static func all(ctx: CardCtx) -> Dictionary:
	return (ctx.state.ns("core").get("firsts", {}) as Dictionary).duplicate(true)
