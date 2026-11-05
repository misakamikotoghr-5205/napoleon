# 截图（不进清单）：从真的牌桌（CardGame.tscn）经小游戏宿主打开吹银元，用真的鼠标事件（root.push_input）玩：
# 单枚四种（好的、哑的、旧洋、做得好的哑板）、一摞（拖一枚碰另一枚、标响/哑）、宿主的“算了”。1280x720。
# xvfb-run -a -s "-screen 0 1280x720x24" $GODOT --path . --rendering-driver opengl3 --audio-driver Dummy \
#   --resolution 1280x720 -s res://scripts/tests/cards/C13/shot_coin_ring.gd -- --out=/tmp/shots/C13
extends SceneTree

const H = preload("res://scripts/tests/cards/C13/harness.gd")
var OUT := "/tmp/shots/C13"

var game: CardGameRoot
var results: Array = []


func _initialize() -> void:
	_main.call_deferred()


func _main() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			OUT = a.substr(6)
	DirAccess.make_dir_recursive_absolute(OUT)
	change_scene_to_file(CardIds.ROOT_SCENE)
	for _i in range(240):
		await process_frame
		game = current_scene as CardGameRoot
		if game != null and game.engine != null and game.title != null:
			break
	game.allow_quit = false
	await _frames(20)
	game._start()
	await _frames(40)
	if game.host.has_method("close_all"):
		game.host.close_all()
	await _frames(20)
	await _single("v2_good", "a")
	await _single("v2_dull", "b")
	await _single("v2_worn", "c")
	await _single("v2_wellmade", "d")
	await _stack()
	await _abort_case()
	for r in results:
		print("RESULT ", JSON.stringify(r))
	quit(0)


func _open(name: String) -> CardCoinRingGame:
	var params := H.fixture(name)
	game.mg_host._on_requested("c0001", "", &"coin_ring", params)
	await _frames(6)
	var g := game.mg_host.current as CardCoinRingGame
	g.finished.connect(func(r: Dictionary) -> void: results.append({"fixture": name, "result": r}))
	return g


func _single(name: String, tag: String) -> void:
	var g := await _open(name)
	if tag == "a":
		await _shot("%s1_open_%s.png" % [tag, name])
		await _hover(_center(g._sample_faces[0]))
		await _shot("%s2_hover_sample_%s.png" % [tag, name])
	await _click(_center(g._sample_faces[0]))
	await _wait_draw()
	if tag == "a":
		await _shot("%s3_blow_good_%s.png" % [tag, name])
	await _click(_center(g._sample_faces[1]))
	await _wait_draw()
	await _click(_center(g._coin_faces[0]))
	await _wait_draw()
	await _shot("%s4_dull_then_coin_%s.png" % [tag, name])
	await _click(_center(g._sample_faces[0]))
	await _wait_draw()
	await _shot("%s5_coin_then_good_%s.png" % [tag, name])
	var pick := 1 if name in ["v2_good", "v2_worn"] else 2
	await _click(_center(g._call_btns[pick - 1]))
	await _frames(4)
	await _shot("%s6_called_%s.png" % [tag, name])
	await _click(_center(g._done_btn))
	await _frames(6)


func _stack() -> void:
	var g := await _open("v2_stack")
	await _shot("e1_open_stack.png")
	await _click(_center(g._sample_faces[0]))
	await _wait_draw()
	for i in [0, 1, 2]:
		await _click(_center(g._coin_faces[i]))
		await _wait_draw()
	await _shot("e2_stack_blown.png")
	# drag coin 3 onto coin 2: clink
	await _drag(_center(g._coin_faces[3]), _center(g._coin_faces[2]), true)
	await _wait_draw()
	await _shot("e3_stack_clink_dull.png")
	await _drag(_center(g._coin_faces[0]), _center(g._coin_faces[3]), false)
	await _wait_draw()
	await _shot("e4_stack_clink_clean.png")
	for i in range(5):
		var clicks := 2 if i in [2, 4] else 1
		for _k in range(clicks):
			await _click(_center(g._chips[i]))
			await _frames(2)
	await _shot("e5_stack_marked.png")
	await _click(_center(g._done_btn))
	await _frames(6)


func _abort_case() -> void:
	var g := await _open("v2_good")
	await _click(_center(g._sample_faces[0]))
	await _wait_draw()
	var abort := game.mg_host.get_node("Abort") as Button
	await _hover(_center(abort))
	await _shot("f1_abort_hover.png")
	await _click(_center(abort))
	await _frames(6)
	print("ABORT active=", game.mg_host.is_active())


func _center(c: Control) -> Vector2:
	return c.get_global_rect().get_center()


func _frames(n: int) -> void:
	for _i in range(n):
		await process_frame


func _wait_draw() -> void:
	await create_timer(0.75).timeout


func _hover(at: Vector2) -> void:
	var mv := InputEventMouseMotion.new()
	mv.position = at
	mv.global_position = at
	root.push_input(mv, true)
	await _frames(3)


func _click(at: Vector2) -> void:
	await _hover(at)
	for pressed in [true, false]:
		var mb := InputEventMouseButton.new()
		mb.button_index = MOUSE_BUTTON_LEFT
		mb.pressed = pressed
		mb.position = at
		mb.global_position = at
		root.push_input(mb, true)
		await _frames(2)


func _drag(from: Vector2, to: Vector2, shot_mid: bool) -> void:
	await _hover(from)
	var mb := InputEventMouseButton.new()
	mb.button_index = MOUSE_BUTTON_LEFT
	mb.pressed = true
	mb.position = from
	mb.global_position = from
	root.push_input(mb, true)
	await _frames(2)
	for k in range(1, 9):
		var at := from.lerp(to, float(k) / 8.0)
		var mv := InputEventMouseMotion.new()
		mv.position = at
		mv.global_position = at
		mv.button_mask = MOUSE_BUTTON_MASK_LEFT
		root.push_input(mv, true)
		await _frames(1)
	if shot_mid:
		await _shot("e3a_stack_dragging.png")
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = to
	up.global_position = to
	root.push_input(up, true)
	await _frames(2)


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := root.get_viewport().get_texture().get_image()
	var path := OUT.path_join(name)
	image.save_png(path)
	print("SHOT ", path)
