# K12：占位生成器两次字节相同；清单覆盖检查（--refs=note）必须退出 0。
# 没有 Pillow 时跳过生成器那一步并打印 NOTE（CI 装上之前不算失败）。
# 合同：docs/cards/CARDS_INTERFACES.md §3.4 K12、§12.1；docs/handoff_cards/K12_art-pipeline.md。
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")


func _initialize() -> void:
	var t := T.new(self, "K12_art_tools")
	var py := _python()
	t.ok(py != "", "python3 or python on PATH")
	if py == "":
		t.finish()
		return
	var root := ProjectSettings.globalize_path("res://").trim_suffix("/")
	var check := root + "/tools/cards/art/check_manifest.py"
	var gen := root + "/tools/cards/art/gen_placeholders.py"
	var check_out: Array = []
	var check_code := OS.execute(py, PackedStringArray([check, "--refs=note"]), check_out, true)
	var check_text := _join(check_out)
	for raw in check_text.split("\n"):
		var line := raw.strip_edges()
		if line.begins_with("ART MISSING"):
			print("NOTE: " + line)
	t.ok(check_code == 0, "check_manifest --refs=note exit %d" % check_code)
	t.ok(check_text.contains("ART CHECK OK"), "check_manifest summary missing")
	if check_code != 0:
		for raw2 in check_text.split("\n"):
			var bad := raw2.strip_edges()
			if bad != "":
				t.ok(false, bad)
	var pillow_out: Array = []
	var pillow := OS.execute(py, PackedStringArray(["-c", "import PIL"]), pillow_out, true) == 0
	if not pillow:
		print("NOTE: Pillow not installed; generator determinism skipped")
		t.finish()
		return
	var base := ProjectSettings.globalize_path(t.user_dir()).trim_suffix("/")
	var dir_a := base + "/gen_a"
	var dir_b := base + "/gen_b"
	DirAccess.make_dir_recursive_absolute(dir_a)
	DirAccess.make_dir_recursive_absolute(dir_b)
	var out_a: Array = []
	var out_b: Array = []
	var code_a := OS.execute(py, PackedStringArray([gen, "--out=" + dir_a]), out_a, true)
	var code_b := OS.execute(py, PackedStringArray([gen, "--out=" + dir_b]), out_b, true)
	t.ok(code_a == 0, "generator run A exit %d" % code_a)
	t.ok(code_b == 0, "generator run B exit %d" % code_b)
	if code_a != 0:
		t.ok(false, _join(out_a))
	if code_b != 0:
		t.ok(false, _join(out_b))
	if code_a == 0 and code_b == 0:
		_compare_trees(t, dir_a, dir_b)
	t.finish()


func _python() -> String:
	for bin in ["python3", "python"]:
		var out: Array = []
		if OS.execute(bin, PackedStringArray(["-c", "import sys"]), out, true) == 0:
			return bin
	return ""


func _join(parts: Array) -> String:
	var text := ""
	for part in parts:
		text += str(part)
	return text


func _compare_trees(t, dir_a: String, dir_b: String) -> void:
	var files_a := _files(dir_a)
	var files_b := _files(dir_b)
	t.ok(files_a.size() > 0, "generator wrote files")
	t.ok(files_a.size() == files_b.size(), "generated file count")
	var same := 0
	for rel in files_a:
		if not files_b.has(rel):
			continue
		var ba := FileAccess.get_file_as_bytes(dir_a + "/" + rel)
		var bb := FileAccess.get_file_as_bytes(dir_b + "/" + rel)
		if ba != bb:
			t.ok(false, "byte mismatch " + rel)
		else:
			same += 1
	t.ok(same == files_a.size() and same > 0, "all %d files byte-identical" % same)


func _files(root: String) -> PackedStringArray:
	var out := PackedStringArray()
	_walk(root, root, out)
	out.sort()
	return out


func _walk(root: String, dir: String, out: PackedStringArray) -> void:
	for name in DirAccess.get_files_at(dir):
		var full := dir.trim_suffix("/") + "/" + name
		var rel := full.substr(root.length()).trim_prefix("/")
		out.append(rel)
	for sub in DirAccess.get_directories_at(dir):
		_walk(root, dir.trim_suffix("/") + "/" + sub, out)
