# trader 自动玩策略入口（肉鸽 v1，RG6）：柜台按 fair 档，但不为柜台押家当；盘账挑物件优先（镇店 > 有来历 > 寻常）、
# 客源先挑跑单帮的买主和急等钱用的街坊。合同 §12.6；docs/cards/rogue/ROGUE_V1.md §14 RG6。随机只在基类用 c.ai.random。
extends "res://scripts/cards/sim/policy.gd"


func policy_name() -> StringName:
	return &"trader"


## The fair counter, minus the estate mortgages the base policy offers when cash is short for the fair tier.
func _counter(engine: CardEngineApi, uid: String, view: Dictionary) -> Array:
	var out: Array = []
	for action in super._counter(engine, uid, view):
		if action[0] != &"estate.mortgage":
			out.append(action)
	return out
