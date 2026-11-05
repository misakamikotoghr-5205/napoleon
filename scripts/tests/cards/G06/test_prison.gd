# G06 阶梯验收入口；测试工具负责独立输出目录与清理。
# 合同 §12，具体断言在本任务 checks.gd。
extends SceneTree
const T := preload("res://scripts/tests/cards/lib/card_t.gd")
const Checks := preload("res://scripts/tests/cards/G06/checks.gd")


func _initialize() -> void:
	var t: RefCounted = T.new(self, "G06_prison")
	Checks.prison(t)
	t.finish()
