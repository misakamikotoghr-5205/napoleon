# Not in the suite. Pack PNG screenshots in a directory into one sheet at 1/4 size (Image.blit_rect).
# godot --headless --path . -s res://scripts/tests/cards/K14/sheet.gd -- --dir=<dir> [--out=<file>]
extends SceneTree

const CELL_W := 320
const CELL_H := 180
const COLS := 4


func _initialize() -> void:
	_run()


func _run() -> void:
	var dir := ""
	var out := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--dir="):
			dir = a.substr(6)
		elif a.begins_with("--out="):
			out = a.substr(6)
	if dir.begins_with("res://") or dir.begins_with("user://"):
		dir = ProjectSettings.globalize_path(dir)
	if dir == "":
		print("NOTE: sheet.gd needs --dir=")
		quit(1)
		return
	if out == "":
		out = dir.path_join("sheet.png")
	var names: Array = _pngs(dir)
	if names.is_empty():
		print("NOTE: no png screenshots in " + dir)
		quit(0)
		return
	var rows := int(ceil(float(names.size()) / float(COLS)))
	var sheet := Image.create(COLS * CELL_W, rows * CELL_H, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0, 0, 0, 1))
	for i in range(names.size()):
		var img := Image.load_from_file(dir.path_join(str(names[i])))
		if img == null:
			continue
		img.convert(Image.FORMAT_RGBA8)
		img.resize(CELL_W, CELL_H, Image.INTERPOLATE_NEAREST)
		var dst := Vector2i((i % COLS) * CELL_W, int(i / COLS) * CELL_H)
		sheet.blit_rect(img, Rect2i(0, 0, CELL_W, CELL_H), dst)
	sheet.save_png(out)
	print("SHEET ", out)
	quit(0)


func _pngs(dir: String) -> Array:
	if not DirAccess.dir_exists_absolute(dir):
		print("NOTE: cannot open " + dir)
		return []
	var names: Array = []
	for f in DirAccess.get_files_at(dir):
		var name := str(f)
		if name.ends_with(".png") and name != "sheet.png" and not name.begins_with("guide_d1_3_sheet"):
			names.append(name)
	names.sort()
	return names
