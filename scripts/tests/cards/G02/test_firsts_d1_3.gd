# G02 完整引擎的前三天指引证据；依赖模块全部合入后登记。
# --update 写自己的黄金 first 串，其余运行逐项比对。
extends SceneTree
const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const Real = preload("res://scripts/tests/cards/G02/real_firsts.gd")
func _initialize() -> void:
	var t := T.new(self, "G02_firsts_d1_3")
	Real.run(t, OS.get_cmdline_user_args().has("--update"))
	t.finish()
