# greedy 自动玩策略入口，公共决策只读可见视图。
# G06；合同 §12.6；随机只在基类使用 c.ai.random。
extends "res://scripts/cards/sim/policy.gd"


func policy_name() -> StringName:
	return &"greedy"
