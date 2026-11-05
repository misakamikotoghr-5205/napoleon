# K18 find-cat shot. Real CardEngine, one CardWidget, viewport PNG. Not a suite test.
# --headless uses the dummy renderer, which cannot read pixels. This script then
# runs itself once under xvfb-run with OpenGL and saves the real viewport.
# /tmp/godot/Godot_v4.7-stable_linux.x86_64 --headless --path /tmp/dehoudang -s res://scripts/tests/cards/K18/shots/find/shot_find.gd
extends SceneTree

const FIND := "ev.1938.find_cat"
const OUT := "res://scripts/tests/cards/K18/shots/find/find_cat.png"
const CARD_AT := Vector2i(568, 260)
const CARD_SIZE := Vector2i(144, 200)


func _initialize() -> void:
	_run()


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		if OS.get_environment("K18_SHOT_FIND") == "1":
			print("FAIL: headless has no viewport image")
			quit(1)
			return
		quit(_paint_via_xvfb())
		return
	var engine := CardEngine.new()
	var opened: Dictionary = engine.new_game({
		"seed": 7,
		"only_examples": false,
		"save_dir": "user://test/K18_shot_find",
	})
	if not bool(opened.get("ok", false)):
		print("FAIL: new_game " + str(opened.get("err", "")))
		quit(1)
		return
	var uid := CardPiles.spawn(engine.ctx, FIND, &"hand")
	if uid == "":
		print("FAIL: spawn")
		quit(1)
		return
	var card_view := _hand_card(engine.view(), uid)
	if card_view.is_empty():
		print("FAIL: hand view has no find_cat")
		quit(1)
		return
	_mount(card_view)
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var img := _image()
	if img == null or img.is_empty() or not _painted(img):
		print("FAIL: viewport not painted")
		quit(1)
		return
	var path := ProjectSettings.globalize_path(OUT)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	if img.save_png(path) != OK:
		print("FAIL: save_png")
		quit(1)
		return
	print("CARDS TEST PASS K18_shot_find")
	quit(0)


func _paint_via_xvfb() -> int:
	OS.set_environment("K18_SHOT_FIND", "1")
	var lib := "/tmp/xlibs/usr/lib/x86_64-linux-gnu"
	if DirAccess.dir_exists_absolute(lib):
		var prev := OS.get_environment("LD_LIBRARY_PATH")
		OS.set_environment("LD_LIBRARY_PATH", lib if prev == "" else lib + ":" + prev)
	var out: Array = []
	var code := OS.execute("xvfb-run", [
		"-a", "-s", "-screen 0 1280x720x24",
		OS.get_executable_path(),
		"--rendering-driver", "opengl3",
		"--audio-driver", "Dummy",
		"--path", ProjectSettings.globalize_path("res://"),
		"-s", "res://scripts/tests/cards/K18/shots/find/shot_find.gd",
	], out, false)
	for line in out:
		var text := str(line).rstrip("\n")
		if text != "":
			print(text)
	if code != 0 and out.is_empty():
		print("FAIL: xvfb %s" % code)
	elif code == 0 and not FileAccess.file_exists(ProjectSettings.globalize_path(OUT)):
		print("FAIL: png missing")
		return 1
	return code


func _hand_card(view: Dictionary, uid: String) -> Dictionary:
	var hand: Variant = view.get("hand", [])
	if typeof(hand) != TYPE_ARRAY:
		return {}
	for row in hand:
		if typeof(row) != TYPE_DICTIONARY:
			continue
		if str(row.get("uid", "")) == uid and str(row.get("def", "")) == FIND:
			return row
	return {}


func _mount(card_view: Dictionary) -> void:
	root.size = Vector2i(1280, 720)
	var host := Control.new()
	host.position = Vector2.ZERO
	host.size = Vector2(1280, 720)
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(host)
	var bg := ColorRect.new()
	bg.color = CardTheme.color(&"wood_dark")
	bg.position = Vector2.ZERO
	bg.size = Vector2(1280, 720)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(bg)
	var w: CardWidget = load("res://scenes/cards/card/CardWidget.tscn").instantiate()
	w.position = Vector2(CARD_AT)
	root.add_child(w)
	w.set_size_mode(&"hand")
	w.set_card(card_view)


func _image() -> Image:
	var tex := root.get_viewport().get_texture()
	if tex == null:
		return null
	return tex.get_image()


func _painted(img: Image) -> bool:
	if img.get_width() < 1280 or img.get_height() < 720:
		return false
	var bg := img.get_pixel(8, 8)
	for y in CARD_SIZE.y:
		for x in CARD_SIZE.x:
			if not img.get_pixel(CARD_AT.x + x, CARD_AT.y + y).is_equal_approx(bg):
				return true
	return false
