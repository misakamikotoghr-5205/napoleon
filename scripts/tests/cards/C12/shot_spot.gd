# C12 screenshots (not in the suite): the spot round played with real mouse events through the minigame
# host (its abort button included), 1280x720.
# xvfb-run -a -s "-screen 0 1280x720x24" $GODOT --rendering-driver opengl3 --audio-driver Dummy \
#     --resolution 1280x720 --path . -s res://scripts/tests/cards/C12/shot_spot.gd -- --out=<dir>
extends SceneTree

const Lib = preload("res://scripts/tests/cards/C12/c12_lib.gd")

var _out := "/tmp/shots/C12"
var _host: CardMiniGameHost = null
var _results: Array = []


func _initialize() -> void:
	_run()


func _run() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.substr(6)
	DirAccess.make_dir_recursive_absolute(_out)
	var bus := CardEventBus.new()
	root.add_child(bus)
	var mock := MockCardEngine.new(bus)
	if mock.db == null:
		push_error("shot: no card db")
	_host = CardMiniGameHost.new()
	_host.theme = CardTheme.build_theme()   # the table root gives the host this theme in the game
	_host.bind(mock, bus)
	root.add_child(_host)
	await _frames(2)
	await _hairpin()
	await _scroll()
	await _old()
	for r in _results:
		print("RESULT ", JSON.stringify(r))
	_host.queue_free()
	bus.queue_free()
	CardText.setup(null)
	CardAnchors.clear()
	await process_frame
	quit(0)


func _open(params: Dictionary) -> CardSpotGame:
	_host._on_requested("c0001", str(params.get("item", "I001")), &"spot", params)
	var game := _host.current as CardSpotGame
	game.finished.connect(func(result: Dictionary) -> void: _results.append(result))
	await _frames(3)
	return game


## Tampered hairpin: book shut -> open it -> two coarse wear marks by eye -> the lens on the shaft.
func _hairpin() -> void:
	var p := Lib.fixture("hairpin3")
	var game := await _open(p)
	await _shot("01_book_shut")
	Lib.click_node(self, Lib.board(game).get_node("AtlasCover/AtlasOpen"))
	await _frames(2)
	Lib.move(self, Lib.item_px(game, 38, 24))
	await _shot("02_book_open_hover")
	Lib.click(self, Lib.item_px(game, 38, 24))
	await _shot("03_call_bubble")
	Lib.click_node(self, Lib.bubble_button(game, "TagWear"))
	Lib.click_pin(self, game, 11, 51, 1)
	Lib.move(self, Lib.center_of(Lib.board(game).get_node("Done")))
	await _shot("04_two_pins")
	Lib.click_node(self, Lib.board(game).get_node("LensButton"))
	Lib.move(self, Lib.item_px(game, 28, 35))
	await _shot("05_lens_on_item")
	Lib.move(self, Lib.board(game).get_global_rect().position + Vector2(682, 76) + Vector2(28.5, 35.5) * 6.0)
	await _shot("06_lens_on_book")
	Lib.click_pin(self, game, 28, 35, 2)
	Lib.move(self, Lib.center_of(Lib.board(game).get_node("Done")))
	await _shot("07_three_pins")
	Lib.click(self, Lib.item_px(game, 38, 24))
	await _shot("08_change_call")
	Lib.click_node(self, Lib.bubble_button(game, "TagCancel"))
	Lib.click_node(self, Lib.board(game).get_node("Done"))
	await _frames(2)


## Scroll with "hold to compare" (eye >= 3): the item well shows the book while the button is held.
func _scroll() -> void:
	var game := await _open(Lib.fixture("scroll3"))
	Lib.click_node(self, Lib.board(game).get_node("AtlasCover/AtlasOpen"))
	Lib.click_pin(self, game, 29, 22, 2)
	Lib.move(self, Lib.item_px(game, 25, 57))
	await _shot("09_scroll")
	var blink := Lib.board(game).get_node("BlinkButton") as Control
	Lib.move(self, Lib.center_of(blink))
	Lib.button_event(self, Lib.center_of(blink), true)
	await _shot("10_scroll_hold_compare")
	Lib.button_event(self, Lib.center_of(blink), false)
	await _frames(2)
	_host.abort()
	await _frames(2)


## Old engine params (no at / look / legend): still playable, book already open.
func _old() -> void:
	var game := await _open(Lib.fixture("hairpin"))
	Lib.click_pin(self, game, 12, 50, 1)
	Lib.move(self, Lib.item_px(game, 30, 34))
	await _shot("11_old_params")
	Lib.click_node(self, Lib.board(game).get_node("Done"))
	await _frames(2)


func _shot(leaf: String) -> void:
	await _frames(3)
	await RenderingServer.frame_post_draw
	var path := _out.path_join(leaf + ".png")
	root.get_viewport().get_texture().get_image().save_png(path)
	print("SHOT ", path)


func _frames(n: int) -> void:
	for _i in n:
		await process_frame
