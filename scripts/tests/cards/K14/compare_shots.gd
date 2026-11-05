# Not in the suite. Pixel-compare two screenshot directories. Identical bytes pass.
# godot --headless --path . -s res://scripts/tests/cards/K14/compare_shots.gd -- --a=<dir> --b=<dir>
extends SceneTree


func _initialize() -> void:
	_run()


func _run() -> void:
	var a := ""
	var b := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--a="):
			a = arg.substr(4)
		elif arg.begins_with("--b="):
			b = arg.substr(4)
	a = _abs(a)
	b = _abs(b)
	if a == "" or b == "":
		print("NOTE: compare_shots needs --a= and --b=")
		quit(1)
		return
	var names := _pngs(a)
	var diff := 0
	if names.is_empty():
		print("NOTE: no png files to compare in " + a)
		quit(1)
		return
	for fn in names:
		var pb: String = b.path_join(str(fn))
		if not FileAccess.file_exists(pb):
			print("DIFF missing %s" % fn)
			diff += 1
			continue
		var ia := Image.load_from_file(a.path_join(str(fn)))
		var ib := Image.load_from_file(pb)
		if ia == null or ib == null:
			print("DIFF unreadable %s" % fn)
			diff += 1
			continue
		if ia.get_width() != ib.get_width() or ia.get_height() != ib.get_height():
			print("DIFF %s size %dx%d vs %dx%d" % [fn, ia.get_width(), ia.get_height(), ib.get_width(), ib.get_height()])
			diff += 1
			continue
		ia.convert(Image.FORMAT_RGBA8)
		ib.convert(Image.FORMAT_RGBA8)
		if ia.get_data() == ib.get_data():
			continue
		var found := false
		for y in range(ia.get_height()):
			for x in range(ia.get_width()):
				if ia.get_pixel(x, y) != ib.get_pixel(x, y):
					print("DIFF %s %d %d" % [fn, x, y])
					found = true
					break
			if found:
				break
		diff += 1
	if diff == 0:
		print("SHOTS MATCH %d" % names.size())
		quit(0)
	else:
		print("SHOTS DIFFER %d" % diff)
		quit(1)


func _abs(p: String) -> String:
	if p.begins_with("res://") or p.begins_with("user://"):
		return ProjectSettings.globalize_path(p)
	return p


func _pngs(dir: String) -> Array:
	if not DirAccess.dir_exists_absolute(dir):
		print("NOTE: cannot open " + dir)
		return []
	var names: Array = []
	for f in DirAccess.get_files_at(dir):
		var name := str(f)
		if name.ends_with(".png"):
			names.append(name)
	names.sort()
	return names
