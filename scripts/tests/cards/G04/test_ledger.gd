# G04 经济验收：ledger。
# 用独立夹具，直接驱动冻结接口。
extends SceneTree
const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const S = preload("res://scripts/tests/cards/G04/economy_test_support.gd")
func _initialize() -> void:
	var t := T.new(self, "G04_ledger")
	S.ledger(t)
	t.finish()
