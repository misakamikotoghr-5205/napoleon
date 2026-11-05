# G05 lot_accuracy 验收入口。
# 场景与种子配置集中在专属测试目录。
extends SceneTree
const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const S = preload("res://scripts/tests/cards/G05/scenarios.gd")
func _initialize() -> void:
	var args: Dictionary = {}
	for arg in OS.get_cmdline_user_args():
		var pair := arg.trim_prefix("--").split("=", true, 1)
		if pair.size() == 2:
			args[pair[0]] = pair[1]
	var name := str(args.get("name", "G05_lot_accuracy_d"))
	var t := T.new(self, name)
	S.run(t, name, args)
	t.finish()
