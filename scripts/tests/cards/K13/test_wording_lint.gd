# K13：用 Python unittest 跑措辞夹具。清单里不扫真数据。
# 合同：docs/handoff_cards/K13_review-history.md ；找不到 python3 时试 python。
extends SceneTree


func _initialize() -> void:
	var bin := _python()
	if bin == "":
		print("FAIL: python3 and python not found")
		quit(1)
		return
	var out: Array = []
	var code := OS.execute(bin, PackedStringArray([
		"-m", "unittest", "discover", "-s", "tools/cards/review/tests",
	]), out, true)
	if code == 0:
		print("CARDS TEST PASS K13_wording_lint")
		quit(0)
		return
	for line in out:
		print(line)
	print("FAIL: wording_lint unittest exit %d" % code)
	quit(1)


func _python() -> String:
	for bin in ["python3", "python"]:
		var out: Array = []
		var code := OS.execute(bin, PackedStringArray(["-c", "import sys"]), out, true)
		if code == 0:
			return bin
	return ""
