# 为开发平衡跑生成标明补齐范围的私有例子集数据根。
# G06；仅工具入口，正式运行仍用原始 examples 或 real 数据。
extends SceneTree
const Scenario := preload("res://scripts/tests/cards/G06/scenario.gd")


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.is_empty():
		print("Usage: make_fixture.gd -- <output-directory>")
		quit(1)
		return
	print(Scenario.build(args[0]))
	quit(0)
