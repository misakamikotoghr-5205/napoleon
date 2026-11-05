# C12 screenshots in the real game (not in the suite): real engine, seed 7, the day-1 tutorial pawn; the
# table steps until the counter opens, then real mouse clicks: "look", the lens, a pin on each mark's spot
# with its right call, "done"; the counter then reads back the player's calls.
# xvfb-run -a -s "-screen 0 1280x720x24" $GODOT --rendering-driver opengl3 --audio-driver Dummy \
#     --resolution 1280x720 --path . -s res://scripts/tests/cards/C12/shot_flow.gd -- --out=<dir>
extends SceneTree

const Lib = preload("res://scripts/tests/cards/C12/c12_lib.gd")

var game: CardGameRoot
var out := "/tmp/shots/C12"


func _initialize() -> void:
	_run()


func _run() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
	DirAccess.make_dir_recursive_absolute(out)
	var bus := CardEventBus.new()
	root.add_child(bus)
	game = load(CardIds.ROOT_SCENE).instantiate()
	game.boot({"bus": bus, "seed": 7, "skip_title": true, "mock": false, "save_dir": "user://shots_c12_flow",
		"guide": "off"})
	root.add_child(game)
	game.guide.skip_fades = true
	game.guide.force(false)
	await _frames(3)
	var n := 0
	while n < 400 and game.host.top_kind() != &"counter":
		game.autoplay_step()
		await _frames(2)
		n += 1
	print("steps to counter: ", n, " top=", game.host.top_kind())
	if game.stage != null:
		game.stage.fast = true
	if game.dialog != null:
		game.dialog.chars_per_sec = 0
	for _i in 30:
		if game.dialog != null and not game.dialog.is_idle():
			game.dialog.skip()
		await _frames(2)
	await _shot("20_counter_before_look")
	var look := _button_with(game, CardText.ui("c04.reply.look"))
	print("look button: ", look)
	if look == null:
		quit(1)
		return
	await _click(look.get_global_rect().get_center())
	await _frames(5)
	var mg := game.mg_host.current as CardSpotGame
	print("spot game: ", mg)
	if mg == null:
		await _shot("21_no_game")
		quit(1)
		return
	var p: Dictionary = mg._params
	print("params marks: ", JSON.stringify(p.get("marks", [])))
	print("params parts: ", JSON.stringify(p.get("parts", [])))
	print("params atlas_open/ink: ", p.get("atlas_open"), " ", p.get("ink"))
	var got: Array = []
	mg.finished.connect(func(r: Dictionary) -> void: got.append(r))
	await _shot("21_spot_in_game")
	var board := Lib.board(mg)
	await _click(Lib.center_of(board.get_node("LensButton")))
	var spots := Lib.answer(p)
	if not spots.is_empty():
		var s0: Array = spots[0]
		Lib.move(self, Lib.item_px(mg, int(s0[0]), int(s0[1])))
		await _shot("22_spot_lens_in_game")
	for s in spots:
		await _click(Lib.item_px(mg, int(s[0]), int(s[1])))
		await _click(Lib.center_of(Lib.bubble_button(mg, "TagWear" if int(s[2]) == 1 else "TagDiffers")))
	Lib.move(self, Lib.center_of(board.get_node("Done")))
	await _shot("23_spot_pinned_in_game")
	await _click(Lib.center_of(board.get_node("Done")))
	await _frames(10)
	print("result: ", JSON.stringify(got))
	for _i in 40:
		if game.dialog != null and not game.dialog.is_idle():
			game.dialog.skip()
		await _frames(2)
	await _shot("24_counter_after_look")
	var item: Dictionary = game.engine.query(&"counter", {"uid": str(game.host.top_panel().get("_uid"))}).get("item", {})
	print("item observations: ", item.get("observations", []))
	game.queue_free()
	bus.queue_free()
	await _frames(3)
	quit(0)


func _button_with(node: Node, text: String) -> Button:
	if node is Button and (node as Button).text == text and (node as Button).is_visible_in_tree():
		return node as Button
	for c in node.get_children():
		var b := _button_with(c, text)
		if b != null:
			return b
	return null


func _click(at: Vector2) -> void:
	Lib.move(self, at)
	await process_frame
	Lib.button_event(self, at, true)
	await process_frame
	Lib.button_event(self, at, false)
	await process_frame


func _shot(leaf: String) -> void:
	await _frames(3)
	await RenderingServer.frame_post_draw
	var path := out.path_join(leaf + ".png")
	root.get_viewport().get_texture().get_image().save_png(path)
	print("SHOT ", path)


func _frames(k: int) -> void:
	for _i in k:
		await process_frame
