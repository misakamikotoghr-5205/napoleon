# RG4 house rules on its own files (IMPL_BRIEF, ROGUE_V1.md section 14): the rogue UI scripts have no class_name;
# every function is at most 80 lines; string literals are ASCII only (Chinese only in comments and JSON); no colour
# literals but Color.WHITE / Color.TRANSPARENT / Color(1, 1, 1, a); no timers and no wall clock; tweens are
# at most 0.6 s per step. The two shared files RG4 touches (card_stage.gd, card_title.gd) get the string and function
# checks. The rogue scenes carry no Chinese.
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const ROGUE_DIR := "res://scripts/cards/ui/rogue"
const SHARED := ["res://scripts/cards/ui/table/card_stage.gd", "res://scripts/cards/ui/shell/card_title.gd"]
const SCENES_DIR := "res://scenes/cards/rogue"
const MAX_FUNC := 80
const MAX_TWEEN := 0.6


func _initialize() -> void:
	var t := T.new(self, "RG4_lint")
	var files := _rogue_files()
	t.ok(files.size() >= 6, "the rogue UI scripts are there (%d)" % files.size())
	for path in files:
		var src := FileAccess.get_file_as_string(path)
		_check_common(t, path, src)
		var code := _strip(src)
		t.ok(not RegEx.create_from_string("(?m)^class_name\\s").search(code), path + ": no class_name")
		_check_colours(t, path, code)
		for bad in ["Timer.new", "create_timer", "Time.get_", "OS.get_ticks", "OS.get_unix_time", "randi(", "randf("]:
			t.ok(not code.contains(bad), "%s: no %s" % [path, bad])
		_check_tweens(t, path, src)
	for path in SHARED:
		_check_common(t, path, FileAccess.get_file_as_string(path))
	for f in DirAccess.get_files_at(SCENES_DIR):
		if f.ends_with(".tscn"):
			t.ok(not _cjk(FileAccess.get_file_as_string(SCENES_DIR + "/" + f)), f + ": no Chinese in the scene")
	t.finish()


func _rogue_files() -> PackedStringArray:
	var out := PackedStringArray()
	for f in DirAccess.get_files_at(ROGUE_DIR):
		if f.ends_with(".gd"):
			out.append(ROGUE_DIR + "/" + f)
	out.sort()
	return out


func _check_common(t, path: String, src: String) -> void:
	for lit in _strings(src):
		t.ok(_ascii(lit), "%s: ASCII string literal '%s'" % [path, lit])
	for row in _func_lengths(src):
		t.ok(int(row[1]) <= MAX_FUNC, "%s: func %s is %d lines (max %d)" % [path, row[0], row[1], MAX_FUNC])


## Only Color.WHITE, Color.TRANSPARENT and Color(1, 1, 1, a) are allowed; everything else goes through CardTheme.
func _check_colours(t, path: String, code: String) -> void:
	var re := RegEx.create_from_string("Color\\(([^)]*)\\)")
	for m in re.search_all(code):
		var parts := m.get_string(1).replace(" ", "").split(",")
		var ok := parts.size() == 4 and parts[0] == "1" and parts[1] == "1" and parts[2] == "1"
		t.ok(ok, "%s: colour literal %s" % [path, m.get_string(0)])
	t.ok(not code.contains("Color8(") and not code.contains("Color.html") and not code.contains("Color.from_"),
		path + ": no other colour constructors")


## tween_property(..., seconds): the seconds are a number or a constant of this file, each at most 0.6.
func _check_tweens(t, path: String, src: String) -> void:
	var consts := {}
	for m in RegEx.create_from_string("(?m)^const\\s+(\\w+)\\s*:?=\\s*([0-9.]+)").search_all(src):
		consts[m.get_string(1)] = float(m.get_string(2))
	for m in RegEx.create_from_string("tween_(?:property|interval)\\(([^\\n]*)\\)").search_all(src):
		var last := m.get_string(1).split(",")[-1].strip_edges()
		var secs := float(consts[last]) if consts.has(last) else float(last)
		t.ok(secs > 0.0 and secs <= MAX_TWEEN, "%s: tween step %s is %.2f s" % [path, last, secs])


## [name, line count] per func: from its line to the line before the next top-level statement.
func _func_lengths(src: String) -> Array:
	var out: Array = []
	var lines := src.split("\n")
	var name := ""
	var start := -1
	var last := -1
	for i in lines.size():
		var line: String = lines[i]
		var top := line != "" and not line.begins_with("\t") and not line.begins_with(" ") and not line.begins_with("#")
		if top and name != "":
			out.append([name, last - start + 1])
			name = ""
		if top and (line.begins_with("func ") or line.begins_with("static func ")):
			name = line.get_slice("(", 0).get_slice(" ", line.get_slice("(", 0).get_slice_count(" ") - 1)
			start = i
		if line.strip_edges() != "" and not line.strip_edges().begins_with("#"):
			last = i
	if name != "":
		out.append([name, last - start + 1])
	return out


func _ascii(s: String) -> bool:
	for i in s.length():
		if s.unicode_at(i) > 127:
			return false
	return true


func _cjk(s: String) -> bool:
	for i in s.length():
		var c := s.unicode_at(i)
		if c >= 0x3000 and c <= 0x9FFF:
			return true
	return false


## String literals outside comments (double quotes; StringName and NodePath literals included).
func _strings(src: String) -> PackedStringArray:
	var out := PackedStringArray()
	var i := 0
	var n := src.length()
	while i < n:
		var c := src.unicode_at(i)
		if c == 35:
			while i < n and src.unicode_at(i) != 10:
				i += 1
			continue
		if c == 34:
			i += 1
			var start := i
			while i < n and src.unicode_at(i) != 34:
				if src.unicode_at(i) == 92:
					i += 2
					continue
				i += 1
			out.append(src.substr(start, i - start))
			i += 1
			continue
		i += 1
	return out


## The source with comments and string literals taken out.
func _strip(src: String) -> String:
	var out := ""
	var i := 0
	var n := src.length()
	while i < n:
		var c := src.unicode_at(i)
		if c == 35:
			while i < n and src.unicode_at(i) != 10:
				i += 1
			continue
		if c == 34:
			i += 1
			while i < n and src.unicode_at(i) != 34:
				if src.unicode_at(i) == 92:
					i += 2
					continue
				i += 1
			i += 1
			out += "\"\""
			continue
		out += src.substr(i, 1)
		i += 1
	return out
