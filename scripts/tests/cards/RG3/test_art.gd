# RG3：肉鸽 v1 的程序美术（docs/cards/rogue/ROGUE_V1.md §12、§14 RG3）。
# gen_ai_rogue.py --check 与仓库里的 PNG 和 .import 字节一致；两次生成到 user:// 字节相同（确定性）；
# --palette 用到的配色键都还在；check_manifest.py 输出 ART CHECK OK；美术清单里恰好这 19 条、写法照 §12；
# 每张 AI 图的尺寸对、物件四角透明、博古格和客源图不透明。找不到 python3 时试 python。
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")

const GEN := "tools/cards/art/gen_ai_rogue.py"
const CHECK := "tools/cards/art/check_manifest.py"
const PROVENANCE := "ai:claude:opus-5.5:2026-10-25:art-rogue"
const RELICS := [
	"blue_curtain", "camphor_chest", "cat_bowl", "chen_mortar", "hu2_pipe", "master_steelyard",
	"oilpaper_umbrella", "old_almanac", "old_signboard", "rosewood_abacus", "stub_box", "sun_inkpad"]
const SOURCES := ["big_households", "dockhands", "junk_runners", "needy_neighbors", "old_customers", "traveling_buyers"]


func _initialize() -> void:
	var t := T.new(self, "RG3_art")
	_manifest(t)
	var py := _python()
	t.ok(py != "", "python3 or python on PATH")
	if py != "":
		_tools(t, py)
	t.finish()


## art id -> [w, h, folder under art/cards, file stem, opaque]
func _expected() -> Dictionary:
	var out := {"prop.curio": [52, 38, "props", "curio", true]}
	for slug in RELICS:
		out["prop.relic." + slug] = [32, 32, "props", "relic." + slug, false]
	for slug in SOURCES:
		out["illus.ky." + slug] = [64, 48, "illus", "ky." + slug, true]
	return out


func _manifest(t) -> void:
	var doc: Dictionary = CardDB.read_json("res://data/cards/art/manifest.json")
	var art: Dictionary = doc.get("art", {})
	var want := _expected()
	var ours := []
	for id in art.keys():
		var s := str(id)
		if s == "prop.curio" or s.begins_with("prop.relic.") or s.begins_with("illus.ky."):
			ours.append(s)
	ours.sort()
	var keys := want.keys()
	keys.sort()
	t.eq(ours, keys, "manifest has exactly the 19 rogue art ids")
	for id in keys:
		var e: Dictionary = art.get(id, {})
		var w: Array = want[id]
		var cat := str(id).get_slice(".", 0)
		var ai := "art/ai/%s/%s.png" % [cat, w[3]]
		t.eq(e, {
			"base": [w[0], w[1]],
			"human": "art/cards/%s/%s.png" % [w[2], w[3]],
			"ai": ai,
			"_provenance": PROVENANCE,
			"placeholder": "art/_placeholder/cards/%s/%s.png" % [w[2], w[3]],
		}, id + " manifest entry")
		_png(t, id, "res://" + ai, w)
		t.ok(FileAccess.file_exists("res://" + ai + ".import"), id + " ai .import sidecar")
		t.ok(FileAccess.file_exists("res://" + str(e.get("placeholder", "")) + ".import"), id + " placeholder .import sidecar")


func _png(t, id: String, path: String, w: Array) -> void:
	var img := Image.new()
	var err := img.load_png_from_buffer(FileAccess.get_file_as_bytes(path))
	t.eq(err, OK, id + " ai png decodes")
	if err != OK:
		return
	t.eq([img.get_width(), img.get_height()], [w[0], w[1]], id + " ai png size")
	var corners := [Vector2i(0, 0), Vector2i(img.get_width() - 1, 0), Vector2i(0, img.get_height() - 1),
		Vector2i(img.get_width() - 1, img.get_height() - 1)]
	if bool(w[4]):
		var holes := 0
		for y in range(img.get_height()):
			for x in range(img.get_width()):
				if img.get_pixel(x, y).a8 != 255:
					holes += 1
		t.eq(holes, 0, id + " is fully opaque")
	else:
		var opaque := 0
		for y in range(img.get_height()):
			for x in range(img.get_width()):
				if img.get_pixel(x, y).a8 == 255:
					opaque += 1
		for c in corners:
			t.eq(img.get_pixelv(c).a8, 0, "%s corner %s transparent" % [id, c])
		t.ok(opaque >= 120, id + " draws an object")


func _tools(t, py: String) -> void:
	var root := ProjectSettings.globalize_path("res://").trim_suffix("/")
	var res := _run(py, [root + "/" + GEN, "--check"])
	t.eq(int(res[0]), 0, "gen_ai_rogue --check exit")
	t.ok(str(res[1]).contains("CHECK 19 images"), "gen_ai_rogue --check covers 19 images: " + str(res[1]))
	res = _run(py, [root + "/" + GEN, "--palette"])
	t.eq(int(res[0]), 0, "gen_ai_rogue --palette exit")
	t.ok(str(res[1]).contains("PALETTE OK"), "palette keys still exist: " + str(res[1]))
	var base := ProjectSettings.globalize_path(t.user_dir()).trim_suffix("/")
	var dir_a := base + "/gen_a"
	var dir_b := base + "/gen_b"
	for dir in [dir_a, dir_b]:
		DirAccess.make_dir_recursive_absolute(dir)
		res = _run(py, [root + "/" + GEN, "--out=" + dir])
		t.eq(int(res[0]), 0, "gen_ai_rogue into %s exit: %s" % [dir.get_file(), res[1]])
	_compare(t, dir_a, dir_b, root)
	res = _run(py, [root + "/" + CHECK])
	t.eq(int(res[0]), 0, "check_manifest exit")
	t.ok(str(res[1]).contains("ART CHECK OK"), "check_manifest says ART CHECK OK")
	if int(res[0]) != 0:
		for line in str(res[1]).split("\n"):
			if line.strip_edges() != "":
				t.ok(false, line.strip_edges())


## Two fresh runs are byte-identical, and equal to the committed files.
func _compare(t, dir_a: String, dir_b: String, root: String) -> void:
	var files := PackedStringArray()
	_walk(dir_a, dir_a, files)
	files.sort()
	t.eq(files.size(), 38, "19 PNGs and 19 .import sidecars generated")
	var same := 0
	for rel in files:
		var a := FileAccess.get_file_as_bytes(dir_a + "/" + rel)
		if a != FileAccess.get_file_as_bytes(dir_b + "/" + rel):
			t.ok(false, "two runs differ: " + rel)
		elif a != FileAccess.get_file_as_bytes(root + "/" + rel):
			t.ok(false, "generated file differs from the repo: " + rel)
		else:
			same += 1
	t.eq(same, files.size(), "every generated file is byte-identical")


func _walk(root: String, dir: String, out: PackedStringArray) -> void:
	for name in DirAccess.get_files_at(dir):
		out.append((dir + "/" + name).substr(root.length() + 1))
	for sub in DirAccess.get_directories_at(dir):
		_walk(root, dir + "/" + sub, out)


func _run(py: String, args: Array) -> Array:
	var out: Array = []
	var code := OS.execute(py, PackedStringArray(args), out, true)
	var text := ""
	for part in out:
		text += str(part)
	return [code, text.strip_edges()]


func _python() -> String:
	for bin in ["python3", "python"]:
		var out: Array = []
		if OS.execute(bin, PackedStringArray(["-c", "import sys"]), out, true) == 0:
			return bin
	return ""
