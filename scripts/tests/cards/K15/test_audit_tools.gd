# K15：用标准库单测跑来源审核工具（stage_ship / audit / check_pr_paths / missing_text）。
# 成功时不打印 Python 的输出——ResourceWarning 里含有 WARNING，会被卡牌测试当成失败。
# 合同：docs/cards/CARDS_INTERFACES.md §11、§12.1；任务卡 docs/handoff_cards/K15_audit-provenance.md。
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")


func _initialize() -> void:
	var t := T.new(self, "K15_audit_tools")
	var output: Array = []
	var args := PackedStringArray(["-m", "unittest", "discover", "-s", "tools/cards/audit/tests"])
	var code := _python(args, output)
	if code != 0:
		_print_tail(output)
		t.ok(false, "python unittest exit %d" % code)
	else:
		t.ok(true, "python unittest exit 0")
	t.finish()


func _python(args: PackedStringArray, output: Array) -> int:
	var code := OS.execute("python3", args, output, true)
	if code == -1:
		output.clear()
		code = OS.execute("python", args, output, true)
	return code


func _print_tail(output: Array) -> void:
	var start := maxi(0, output.size() - 40)
	for i in range(start, output.size()):
		var line := str(output[i]).strip_edges()
		if line != "":
			print(line)
