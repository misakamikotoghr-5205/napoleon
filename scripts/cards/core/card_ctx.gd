# 引擎上下文：状态、数据、总线、五个登记表、本次指令的可见事件。主人 G01；W0 写了能用的版本。
# 合同：docs/cards/CARDS_INTERFACES.md §7.3、§6.2（随机只经 draw，域必须在 CardIds.RNG_DOMAINS 登记）。
class_name CardCtx
extends RefCounted

var state: CardState
var db: CardDB
var bus: CardEventBus
var ops: CardOps = CardOps.new()
var conds: CardConds = CardConds.new()
var mods: CardMods = CardMods.new()
var hooks: CardHooks = CardHooks.new()
var actions: CardActions = CardActions.new()
## 本次指令的可见事件 [[信号名, 参数…], …]；门面在指令结束时按顺序发到 bus
var out: Array = []
## G04 挂上的账本对象（economy/card_ledger.gd，继承 scripts/core/ledger.gd）
var ledger = null


func seed() -> int:
	return int(state.data.get("seed", 0)) if state != null else 0


## 开局起第几天（loop.abs_day，G02 写）
func abs_day() -> int:
	if state == null:
		return 0
	return int(state.ns("loop").get("abs_day", 0))


## JevRng.draw(seed(), domain, key)；开发版里检查 domain 精确命中 CardIds.RNG_DOMAINS，没登记 push_error
func draw(domain: String, key: Array) -> float:
	if not CardShip.is_ship() and CardIds.rng_owner(domain) == "":
		push_error("CardCtx.draw: RNG domain '%s' is not registered in CardIds.RNG_DOMAINS" % domain)
	return JevRng.draw(self.seed(), domain, key)


## 追加一条可见事件到 out
func emit(signal_name: StringName, args: Array) -> void:
	var row: Array = [signal_name]
	row.append_array(args)
	out.append(row)


func run(effects: Array, source: String) -> void:
	ops.run(self, effects, source)


func test(cond) -> bool:
	return conds.test(self, cond)


func rules(name: String) -> Dictionary:
	return db._rules.get(name, {}) if db != null else {}
