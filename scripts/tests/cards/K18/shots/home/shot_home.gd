# K18 截图：猫在店。英雄条整屏，牌位显示在店。不进清单。
# /tmp/godot/Godot_v4.7-stable_linux.x86_64 --headless --path /tmp/dehoudang -s res://scripts/tests/cards/K18/shots/home/shot_home.gd
extends SceneTree

const S = preload("res://scripts/tests/cards/C02/support.gd")
const OUT := "res://scripts/tests/cards/K18/shots/home/pet_home.png"


func _initialize() -> void:
	# --headless 的假纹理上 get_image() 为空，也不会发 frame_post_draw。
	# 有 xvfb 时转一次真窗口；视口图仍由这次脚本保存，不造假图。
	if DisplayServer.get_name() == "headless":
		_reexec()
		return
	_run()


func _reexec() -> void:
	var output: Array = []
	var code := OS.execute("/usr/bin/xvfb-run", PackedStringArray([
		"-a", "-s", "-screen 0 1280x720x24",
		OS.get_executable_path(),
		"--rendering-driver", "opengl3",
		"--audio-driver", "Dummy",
		"--path", ProjectSettings.globalize_path("res://"),
		"-s", "res://scripts/tests/cards/K18/shots/home/shot_home.gd",
	]), output, true)
	var text := ""
	for item in output:
		text += str(item)
	text = text.trim_suffix("\n")
	if text != "":
		print(text)
	if code != 0 and text == "":
		print("NOTE: no display, png not written")
	quit(0 if code == 0 else 1)


func _run() -> void:
	S.setup_db()
	root.size = Vector2i(1280, 720)
	var bar: CardHeroBar = load("res://scenes/cards/card/HeroBar.tscn").instantiate()
	root.add_child(bar)
	await process_frame
	var view := {
		"self": {
			"uid": "self1",
			"attrs": {"eye": 3, "tongue": 2, "pull": 4, "nerve": 1},
		},
		"contacts": [],
		"pet": {"show": true, "home": true, "lost": false},
	}
	if not CardViewModel.leaks(view).is_empty():
		await _fail(bar, "view has hidden keys")
		return
	bar.refresh(view)
	await process_frame
	await RenderingServer.frame_post_draw
	if not _plaque_ok(bar):
		await _fail(bar, "pet home plaque not showing")
		return
	var tex := root.get_viewport().get_texture()
	var img: Image = tex.get_image() if tex != null else null
	if img == null or img.get_width() < 1280 or img.get_height() < 720:
		await _fail(bar, "viewport image empty")
		return
	if img.get_pixel(238, 586).is_equal_approx(img.get_pixel(640, 300)):
		await _fail(bar, "pet plaque not drawn")
		return
	var path := ProjectSettings.globalize_path(OUT)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var err := img.save_png(path)
	if err != OK:
		await _fail(bar, "save_png failed %s" % err)
		return
	await _shutdown(bar)
	print("CARDS TEST PASS K18_shot_home")
	quit(0)


func _plaque_ok(bar: Node) -> bool:
	var plaque := bar.get_node_or_null("PetPlaque") as CanvasItem
	var label := bar.get_node_or_null("PetPlaque/PetText") as Label
	if plaque == null or label == null or not plaque.visible:
		return false
	if label.text != CardText.ui("k18.pet.home"):
		return false
	if bar.get_node_or_null("Contact0") != null:
		return false
	for attr in ["eye", "tongue", "pull", "nerve"]:
		var value := bar.get_node_or_null("Hero/Val_" + attr) as Label
		if value == null or not value.text.is_valid_int():
			return false
	return true


func _fail(bar: Node, msg: String) -> void:
	print("NOTE: " + msg + ", png not written")
	await _shutdown(bar)
	quit(1)


func _shutdown(bar: Node) -> void:
	if bar != null and is_instance_valid(bar) and bar.is_inside_tree():
		bar.queue_free()
		await process_frame
	CardAnchors.clear()
	CardText.setup(null)
