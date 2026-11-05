# Mouse only (DESIGN 13): a whole round with InputEventMouseMotion / InputEventMouseButton pushed through
# the viewport, in the minigame host. Every click lands on the control it means (top control under the
# mouse); a click alone pins nothing; the call bubble pins, changes, takes away, or closes; the list
# reopens a pin; holding "compare" swaps the picture only while held; out of ink no new pin; "done",
# the host's abort and Esc all close the round. Owner C12.
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const Lib = preload("res://scripts/tests/cards/C12/c12_lib.gd")

var t


func _initialize() -> void:
	t = T.new(self, "C12_mouse")
	t.run_async(_body)


func _body() -> void:
	var bus := CardEventBus.new()
	root.add_child(bus)
	var mock := MockCardEngine.new(bus)
	t.ok(mock.db != null, "text db")
	var spy = t.spy(bus)
	var host := CardMiniGameHost.new()
	host.bind(mock, bus)
	root.add_child(host)
	await t.frames(1)
	await _hairpin(host, bus, spy)
	await _scroll(host)
	await _closers(host)
	host.queue_free()
	bus.queue_free()
	CardAnchors.clear()
	await t.frames(3)


func _open(host: CardMiniGameHost, name: String) -> CardSpotGame:
	host._on_requested("c0001", "I001", &"spot", Lib.fixture(name))
	await t.frames(2)
	return host.current as CardSpotGame


func _hairpin(host: CardMiniGameHost, bus: CardEventBus, spy) -> void:
	var game := await _open(host, "hairpin3")
	game.bind_bus(bus)
	var done: Array = []
	game.finished.connect(func(r: Dictionary) -> void: done.append(r))
	var board := Lib.board(game)
	spy.clear()
	t.ok(not game.atlas_is_open(), "book starts shut")
	t.ok(not (board.get_node("Legend") as Control).visible, "legend is in the shut book")
	await _click(board.get_node("AtlasCover/AtlasOpen"), "open the book")
	t.ok(game.atlas_is_open(), "book opened by a click")
	t.ok((board.get_node("Legend") as Control).visible, "legend shows with the book")
	await _click_at(Lib.item_px(game, 38, 24), board.get_node("Item"), "item pixel")
	t.ok(board.bubble_open(), "click on the item opens the call bubble")
	t.eq(game.pins().size(), 0, "a click alone pins nothing")
	t.eq(game.ink_left(), 4, "a click alone spends no ink")
	t.ok(not Lib.bubble_button(game, "TagRemove").visible, "new spot: no take-away")
	await _click(Lib.bubble_button(game, "TagCancel"), "cancel")
	t.ok(not board.bubble_open(), "x closes the bubble")
	t.eq(game.pins().size(), 0, "x pins nothing")
	await _click_at(Lib.item_px(game, 38, 24), board.get_node("Item"), "item again")
	await _click_at(board.get_global_rect().position + Vector2(540, 500), board, "empty board")
	t.ok(not board.bubble_open(), "a click elsewhere closes the bubble")
	t.eq(game.pins().size(), 0, "a click elsewhere pins nothing")
	await _pin(game, 38, 24, "TagWear")
	t.eq(game.pins(), [[38, 24, 1]], "wear pinned at the clicked pixel")
	t.eq(game.ink_left(), 3, "one ink for the pin")
	await _click(board.get_node("LensButton"), "lens")
	t.eq(game.current_tool(), "lens", "lens by a click")
	await _pin(game, 28, 35, "TagDiffers")
	await _pin(game, 11, 51, "TagWear")
	t.eq(game.pins(), [[38, 24, 1], [28, 35, 2], [11, 51, 1]], "three calls")
	await _click_at(Lib.item_px(game, 38, 24), board.get_node("Item"), "existing pin")
	t.ok(board.bubble_open() and Lib.bubble_button(game, "TagRemove").visible, "pin bubble offers take-away")
	t.eq(game.ink_left(), 1, "opening a pin spends nothing")
	await _click(Lib.bubble_button(game, "TagDiffers"), "change the call")
	t.eq(game.pins()[0], [38, 24, 2], "call changed in place")
	t.eq(game.ink_left(), 1, "changing a call is free")
	var row := board.get_node("PinList/Pin3") as Control
	await _click(row, "list row 3")
	t.ok(board.bubble_open(), "list row reopens its pin")
	await _click(Lib.bubble_button(game, "TagRemove"), "take away")
	t.eq(game.pins(), [[38, 24, 2], [28, 35, 2]], "pin 3 taken away")
	t.eq(game.ink_left(), 1, "ink is not given back")
	await _pin(game, 50, 12, "TagWear")
	t.eq(game.ink_left(), 0, "ink used up")
	await _click_at(Lib.item_px(game, 20, 44), board.get_node("Item"), "no ink")
	t.ok(not board.bubble_open(), "no ink: no new call")
	await _click_at(Lib.item_px(game, 50, 12), board.get_node("Item"), "pin with no ink")
	t.ok(board.bubble_open(), "no ink: old pins still open")
	await _click(Lib.bubble_button(game, "TagCancel"), "cancel")
	var tools: Array = []
	for ev in spy.ui_events():
		t.eq(str(ev[0]), "mg_tool", "only mg_tool events")
		t.eq(Lib.keys_of(ev[1]), PackedStringArray(["kind", "tool"]), "mg_tool payload")
		tools.append(str(ev[1].get("tool", "")))
	t.eq(tools, ["atlas", "lens"], "tool events from clicks")
	await _click(board.get_node("Done"), "done")
	t.eq(done.size(), 1, "done by a click")
	if done.size() == 1:
		var r: Dictionary = done[0]
		t.eq(r.get("measures", {}).get("spots"), [[38, 24, 2], [28, 35, 2], [50, 12, 1]], "spots are the clicks")
		t.eq(int(r.get("measures", {}).get("ink_used", 0)), 4, "ink used")
		t.eq(int(r.get("minutes", 0)), 9, "minutes: 4 pins x 2 + book 1")
		t.eq(bool(r.get("aborted", true)), false, "not aborted")
	await t.frames(2)
	t.ok(not host.is_active(), "host closed the round")


func _scroll(host: CardMiniGameHost) -> void:
	var game := await _open(host, "scroll3")
	var board := Lib.board(game)
	var blink := board.get_node("BlinkButton") as Button
	t.ok(blink.visible and blink.disabled, "compare waits for the book")
	await _click(board.get_node("AtlasCover/AtlasOpen"), "open the book")
	t.ok(not blink.disabled, "compare after the book")
	var pic := board.get_node("Item/Picture") as TextureRect
	var own := pic.texture
	var at := Lib.center_of(blink)
	await _hover(at)
	Lib.button_event(self, at, true)
	await t.frames(1)
	t.ok(game.blink_held(), "held")
	t.ok(pic.texture != own, "item well shows the book while held")
	Lib.button_event(self, at, false)
	await t.frames(1)
	t.ok(not game.blink_held(), "released")
	t.eq(pic.texture, own, "item back on release")
	Lib.button_event(self, at, true)
	await t.frames(1)
	var away := Lib.item_px(game, 5, 5)
	Lib.move(self, away)
	Lib.button_event(self, away, false)
	await t.frames(1)
	t.ok(not game.blink_held(), "released off the button")
	t.eq(pic.texture, own, "item back after releasing elsewhere")
	host.abort()
	await t.frames(2)


func _closers(host: CardMiniGameHost) -> void:
	var game := await _open(host, "hairpin3")
	var got: Array = []
	game.finished.connect(func(r: Dictionary) -> void: got.append(r))
	await _click(Lib.board(game).get_node("AtlasCover/AtlasOpen"), "open")
	await _pin(game, 38, 24, "TagWear")
	var abort := host.get_node("Abort") as Button
	await _click(abort, "host abort")
	t.eq(got.size(), 1, "abort button closes the round")
	if got.size() == 1:
		t.eq(bool(got[0].get("aborted", false)), true, "aborted")
		t.eq((got[0].get("observations", ["x"]) as Array).size(), 0, "aborted: no observations")
		t.eq(int(got[0].get("minutes", 0)), 3, "aborted: minutes spent so far")
	await t.frames(2)
	game = await _open(host, "hairpin3")
	got.clear()
	game.finished.connect(func(r: Dictionary) -> void: got.append(r))
	await _click_at(Lib.item_px(game, 38, 24), Lib.board(game).get_node("Item"), "bubble open")
	var esc := InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	esc.pressed = true
	root.push_input(esc)
	await t.frames(2)
	t.eq(got.size(), 1, "Esc closes the round even with the bubble open")
	if got.size() == 1:
		t.eq(bool(got[0].get("aborted", false)), true, "Esc aborts")
	t.ok(not host.is_active(), "host free after Esc")


func _pin(game: CardSpotGame, x: int, y: int, button: String) -> void:
	await _click_at(Lib.item_px(game, x, y), Lib.board(game).get_node("Item"), "pixel %d,%d" % [x, y])
	await _click(Lib.bubble_button(game, button), button)


func _hover(at: Vector2) -> Control:
	Lib.move(self, at)
	await process_frame
	return root.gui_get_hovered_control()


func _click(c: Control, label: String) -> void:
	t.ok(c != null and c.is_visible_in_tree(), label + ": visible")
	if c == null:
		return
	await _click_at(c.get_global_rect().get_center(), c, label)


func _click_at(at: Vector2, owner: Control, label: String) -> void:
	var hit := await _hover(at)
	var ok := hit != null and (hit == owner or owner.is_ancestor_of(hit))
	t.ok(ok, "%s: top control under the mouse is %s" % [label, hit.get_path() if hit != null else "nothing"])
	Lib.button_event(self, at, true)
	await process_frame
	Lib.button_event(self, at, false)
	await process_frame
