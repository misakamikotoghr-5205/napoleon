# G02 的 calendar 需求测试入口。
# 清单测试不依赖墙钟，运行数据与存档隔离。
extends SceneTree
const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const Cases = preload("res://scripts/tests/cards/G02/test_cases.gd")
func _initialize() -> void:
	var t := T.new(self, "G02_calendar")
	Cases.run(t, "calendar")
	t.finish()
