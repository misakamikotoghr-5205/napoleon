# K18 猫走丢：英雄头像牌位截图。参照 C02 test_hero，不进清单。
# /tmp/godot/Godot_v4.7-stable_linux.x86_64 --headless --path /tmp/dehoudang -s res://scripts/tests/cards/K18/shots/lost/shot_lost.gd
extends SceneTree

const S = preload("res://scripts/tests/cards/C02/support.gd")
const OUT := "res://scripts/tests/cards/K18/shots/lost/pet_lost.png"


func _initialize() -> void:
	# --headless 走假纹理，get_image 是空的，也不会发 frame_post_draw。
	# 有 xvfb 时转一次真窗口，视口图仍由这次脚本保存。
	if DisplayServer.get_name() == "headless":
		_reexec()
		return
	_run()


func _reexec() -> void:
	var libs := "/tmp/xlibs/usr/lib/x86_64-linux-gnu"
	var prev := OS.get_environment("LD_LIBRARY_PATH")
	OS.set_environment("LD_LIBRARY_PATH", libs if prev == "" else libs + ":" + prev)
	var output: Array = []
	var code := OS.execute("/usr/bin/xvfb-run", PackedStringArray([
		"-a", "-s", "-screen 0 1280x720x24",
		OS.get_executable_path(),
		"--rendering-driver", "opengl3",
		"--audio-driver", "Dummy",
		"--path", ProjectSettings.globalize_path("res://"),
		"-s", "res://scripts/tests/cards/K18/shots/lost/shot_lost.gd",
	]), output, true)
	var text := ""
	for item in output:
		text += str(item)
	text = text.trim_suffix("\n")
	if text != "":
		print(text)
	quit(0 if code == 0 else 1)


func _run() -> void:
	S.setup_db()
	root.size = Vector2i(1280, 720)
	var bar: CardHeroBar = load("res://scenes/cards/card/HeroBar.tscn").instantiate()
	root.add_child(bar)
	bar.refresh({
		"self": {
			"uid": "self1",
			"attrs": {"eye": 3, "tongue": 2, "pull": 4, "nerve": 1},
		},
		"contacts": [],
		"pet": {"show": true, "home": false, "lost": true},
	})
	await process_frame
	await RenderingServer.frame_post_draw
	var plaque := bar.get_node_or_null("PetPlaque") as CanvasItem
	var label := bar.get_node_or_null("PetPlaque/PetText") as Label
	var lost := CardText.ui("k18.pet.lost")
	if plaque == null or label == null or not plaque.visible or label.text != lost:
		push_error("pet lost plaque not showing")
		quit(1)
		return
	if bar.get_node_or_null("Contact0") != null:
		push_error("contacts should be empty")
		quit(1)
		return
	for attr in ["eye", "tongue", "pull", "nerve"]:
		var value := bar.get_node_or_null("Hero/Val_" + attr) as Label
		if value == null or not value.text.is_valid_int():
			push_error("attr %s is not an int" % attr)
			quit(1)
			return
	var tex := root.get_viewport().get_texture()
	var img: Image = tex.get_image() if tex != null else null
	if img == null or img.get_width() < 1280 or img.get_height() < 720:
		push_error("viewport image empty")
		quit(1)
		return
	if img.get_pixel(238, 586).is_equal_approx(img.get_pixel(640, 300)):
		push_error("pet plaque not drawn")
		quit(1)
		return
	var path := ProjectSettings.globalize_path(OUT)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var err := img.save_png(path)
	if err != OK:
		push_error("save_png failed %s" % err)
		quit(1)
		return
	print("CARDS TEST PASS K18_shot_lost")
	quit(0)
