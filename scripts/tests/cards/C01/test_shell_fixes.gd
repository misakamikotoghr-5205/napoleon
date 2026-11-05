# C01 外框换皮（10-22）的按钮 bug：层次（b02/b32）、Esc 先放回选中的牌（b31）、柜台回车（b15）、暂停键盘（b05）、
# 夜里打烊按钮不再是红的、放大镜和灯（b33/b35）、设置排进右抽屉且“合上”点得到（b22/b23）、文字速度写成字（b46）、
# 标签角标不出屏（b40）。真按键、真悬停都走视口（push_input），点到的就是画在最上面的。
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const S = preload("res://scripts/tests/cards/C01/support.gd")
const C04 := "res://scripts/tests/cards/C04/fixtures/"


func _initialize() -> void:
	var t := T.new(self, "C01_shell_fixes")
	t.run_async(_body.bind(t))


func _body(t) -> void:
	var bus := CardEventBus.new()
	root.add_child(bus)
	await _layers(t, bus)
	await _title_layer(t, bus)
	await _esc_deselects(t, bus)
	await _pause_keys(t, bus)
	await _counter_enter(t, bus)
	await _night_tone(t, bus)
	await _tools(t, bus)
	await _drawers(t, bus)
	await _street_redeem(t, bus)
	bus.queue_free()
	await t.frames(1)


## Sum of z_index up the tree (z_as_relative), i.e. the layer the item is really drawn on.
func _abs_z(n: Node) -> int:
	var z := 0
	var cur: Node = n
	while cur != null:
		if cur is CanvasItem:
			z += (cur as CanvasItem).z_index
			if not (cur as CanvasItem).z_as_relative:
				break
		cur = cur.get_parent()
	return z


func _max_z(n: Node) -> int:
	var best := -4096
	if n is CanvasItem and (n as CanvasItem).is_visible_in_tree():
		best = _abs_z(n)
	for c in n.get_children():
		best = maxi(best, _max_z(c))
	return best


func _hover(at: Vector2) -> Control:
	var mv := InputEventMouseMotion.new()
	mv.position = at
	mv.global_position = at
	root.push_input(mv, true)
	await process_frame
	return root.gui_get_hovered_control()


func _key(code: Key) -> void:
	for down in [true, false]:
		var ev := InputEventKey.new()
		ev.keycode = code
		ev.physical_keycode = code
		ev.pressed = down
		root.push_input(ev)
		await process_frame


func _center(c: Control) -> Vector2:
	return c.get_global_rect().get_center()


func _drop_game(game: Node) -> void:
	game.queue_free()
	CardAnchors.clear()
	await process_frame


func _close_all(game: CardGameRoot) -> void:
	var guard := 0
	while game.host.top_panel() != null and guard < 8:
		guard += 1
		game.host.close_panel(game.host.top_panel())
		await process_frame


## b02: with a card selected (zoomed preview + its buttons), overlays draw above the hand and take the click.
func _layers(t, bus: CardEventBus) -> void:
	var game := S.boot(self, bus, "day_full")
	await t.frames(2)
	await _close_all(game)
	game.hand.select_index(0)
	await t.frames(2)
	var buttons: Control = game.hand.get("_buttons") as Control
	t.ok(buttons != null and buttons.is_visible_in_tree(), "preview buttons are up")
	var hand_top := _max_z(game.hand)
	t.ok(hand_top <= 150, "hand draws at z <= 150 (got %d)" % hand_top)
	for kind in [&"pause", &"help"]:
		game.host.open_panel(kind, {})
		await t.frames(2)
		var overlay := game.host.top_overlay()
		t.ok(_abs_z(overlay) > hand_top, "%s draws above the hand (%d > %d)" % [kind, _abs_z(overlay), hand_top])
		if buttons != null:
			var hit := await _hover(_center(buttons))
			t.ok(hit != null and game.host.is_ancestor_of(hit), "%s: the click over the preview buttons lands on the overlay (got %s)" % [
				kind, str(hit.get_path()) if hit != null else "null"])
		game.host.close_top()
		await t.frames(1)
	# Minigame host: above the hand too.
	game.bus.minigame_requested.emit("c0002", "I001", &"spot", {"kind": "spot", "item": "I001"})
	await t.frames(2)
	t.ok(game.mg_host.is_active(), "minigame is up")
	t.ok(_abs_z(game.mg_host.current) > hand_top, "minigame draws above the hand")
	game.mg_host.abort()
	await t.frames(2)
	# Table top band (tabs, drawer frame) is above the hand and later in the tree.
	for node_name in ["Tabs", "Drawer"]:
		var n: Node = game.table.get_node(node_name)
		t.ok(_abs_z(n) > hand_top, node_name + " draws above the hand")
		t.ok(n.get_index() > game.hand.get_index(), node_name + " is hit-tested before the hand")
	# Close-day (contract layer 9): above the drawer panel, below overlays; it lives in the modal host.
	var end: Button = game.get("_end")
	t.ok(game.host.is_ancestor_of(end) and _abs_z(end) > hand_top, "close-day draws above the hand")
	game._on_tab(&"estates")
	await t.frames(2)
	var drawer_panel := game.host.drawer_panel()
	t.ok(drawer_panel != null and end.get_index() > drawer_panel.get_index(), "close-day is above the open drawer panel")
	var hit := await _hover(_center(end))
	t.ok(hit == end, "close-day takes the click over the right drawer (got %s)" % (str(hit.get_path()) if hit != null else "null"))
	t.eq(game.table.get_node("Drawer").get("_title").text, CardText.ui("c01.drawer.estates"), "estates drawer title")
	game.host.open_panel(&"help", {})
	await t.frames(2)
	hit = await _hover(_center(end))
	t.ok(hit != end and game.host.top_overlay().get_index() > end.get_index(), "an overlay covers close-day")
	await _close_all(game)
	await _drop_game(game)


## b32 / b06: back to the title hides the old hand, the title covers the hand and the table chrome.
func _title_layer(t, bus: CardEventBus) -> void:
	var game := S.boot(self, bus, "day_full")
	await t.frames(2)
	await _close_all(game)
	game._close_session_ui()
	game._show_title()
	await t.frames(2)
	var title: Control = game.title
	t.ok(title != null and title.is_visible_in_tree(), "title is up")
	t.ok(_abs_z(title) > _max_z(game.hand), "title draws above anything left in the hand")
	var cards := 0
	for n in game.hand.find_children("*", "CardWidget", true, false):
		if (n as CanvasItem).is_visible_in_tree():
			cards += 1
	t.eq(cards, 0, "back to the title clears the old hand")
	t.ok(not (game.get("_end") as Control).visible and not game.table.get_node("Tabs").visible,
		"close-day and tabs are put away under the title")
	var hit := await _hover(Vector2(640, 640))
	t.ok(hit != null and (hit == title or title.is_ancestor_of(hit)), "clicks on the lower title land on the title")
	game._on_title(&"settings")
	await t.frames(2)
	t.eq(game.host.top_kind(), &"settings", "settings opens over the title")
	var frame: Control = game.table.get_node("Drawer").get("_frame")
	t.ok(frame != null and frame.is_visible_in_tree() and _abs_z(frame) > _abs_z(title), "the drawer frame draws over the title")
	game.host.close_top()
	await t.frames(1)
	await _drop_game(game)


## b31: the first Esc puts a selected card back; the next one pauses.
func _esc_deselects(t, bus: CardEventBus) -> void:
	var game := S.boot(self, bus, "day_full")
	await t.frames(2)
	await _close_all(game)
	game.hand.select_index(1)
	await t.frames(1)
	t.ok(int(game.hand.get("_selected")) == 1, "card 2 is selected")
	await _key(KEY_ESCAPE)
	t.eq(int(game.hand.get("_selected")), -1, "Esc puts the selected card back")
	t.ok(game.host.top_panel() == null, "that Esc does not open pause")
	await _key(KEY_ESCAPE)
	t.eq(game.host.top_kind(), &"pause", "the next Esc pauses")
	await _drop_game(game)


## b05: keyboard focus and the highlighted pause button are the same; focus never leaves the box.
func _pause_keys(t, bus: CardEventBus) -> void:
	var game := S.boot(self, bus, "day_full")
	await t.frames(2)
	await _close_all(game)
	game.hand.select_index(0)
	await t.frames(1)
	game.host.open_panel(&"pause", {})
	await t.frames(2)
	var pause := game.host.top_panel()
	var got: Array = []
	pause.close_requested.connect(func(r: Dictionary) -> void: got.append(r))
	for i in 7:
		await _key(KEY_DOWN)
		var f: Control = get_root().gui_get_focus_owner()
		t.ok(f != null and pause.is_ancestor_of(f), "Down #%d keeps focus in the pause box" % i)
	# resume, settings, help, title, quit: from resume, Down twice is help.
	pause.call("_select", 0)
	await _key(KEY_DOWN)
	await _key(KEY_DOWN)
	t.eq(str(get_root().gui_get_focus_owner().name), "help", "Down twice lands on help")
	await _key(KEY_ENTER)
	await t.frames(2)
	t.eq(got, [{"next": {"kind": "help", "args": {}}}], "Enter presses the focused help, once")
	await _drop_game(game)


## b15: Enter on the counter confirms the default reply (fair price) instead of doing nothing.
func _counter_enter(t, bus: CardEventBus) -> void:
	var game := S.boot(self, bus, C04 + "pawn.json", {"guide": "off"})
	await t.frames(2)
	await _close_all(game)
	game._on_card_pressed("c0002")
	await t.frames(3)
	t.eq(game.host.top_kind(), &"counter", "counter is open")
	var guard := 0
	while not game.dialog.is_idle() and guard < 20:
		guard += 1
		game.dialog.skip()
		await t.frames(1)
	var mock: MockCardEngine = game.engine
	var n := mock.sent.size()
	await _key(KEY_ENTER)
	await t.frames(2)
	var offers: Array = mock.sent.slice(n).filter(func(r: Array) -> bool: return str(r[0]) == "counter.offer")
	t.eq(offers, [["counter.offer", {"uid": "c0002", "tier": "fair"}]], "Enter offers the fair price")
	# A reply that has focus wins over the default.
	var rows: Array = []
	for b in game.dialog.find_children("*", "Button", true, false):
		if (b as Button).has_meta("reply_id") and (b as Button).is_visible_in_tree() and not (b as Button).disabled:
			rows.append(b)
	if not rows.is_empty():
		var last: Button = rows.back()
		var want := str(last.get_meta("reply_id"))
		var picked: Array = []
		game.dialog.reply_chosen.connect(func(id: String) -> void: picked.append(id))
		last.grab_focus()
		await t.frames(1)
		await _key(KEY_ENTER)
		await t.frames(2)
		t.eq(picked, [want], "Enter presses the focused reply, once")
	await _drop_game(game)


## SPEC §1 #9: after 照样打烊 the night button is blue, not stuck on the confirm red.
func _night_tone(t, bus: CardEventBus) -> void:
	var game := S.boot(self, bus, "day_full")
	await t.frames(2)
	await _close_all(game)
	var mock: MockCardEngine = game.engine
	game._on_close_day()
	await t.frames(1)
	if game.host.top_kind() == &"end_day":
		t.eq(game.get("_end_tone"), &"confirm", "confirm sheet open: the button is red")
		game.host.top_panel().autoplay_step()
		await t.frames(3)
	var guard := 0
	while str(mock.view().get("phase", "")) != "night" and guard < 6:
		guard += 1
		game._on_close_day()
		await t.frames(1)
		if game.host.top_kind() == &"end_day":
			game.host.top_panel().autoplay_step()
			await t.frames(2)
	t.eq(str(mock.view().get("phase", "")), "night", "reached the night")
	t.ok(not game.host.is_open(&"end_day"), "confirm sheet is closed")
	t.eq(game.get("_end_tone"), &"night", "the night button is blue")
	await _drop_game(game)


## b33 magnifier says something with no guest; b35 the day lamp is off, locked and does not glow.
func _tools(t, bus: CardEventBus) -> void:
	var game := S.boot(self, bus, "day_full")
	await t.frames(2)
	await _close_all(game)
	(game.stage.get_node("magnifier") as BaseButton).pressed.emit()
	await t.frames(1)
	var toast = game.get("_toast")
	t.ok(toast != null and toast.is_showing(), "magnifier with no guest shows a note")
	t.eq(toast.text(), CardText.ui("c01.toast.nothing_to_look"), "note says there is nothing to look at")
	var lamp := game.stage.get_node("lamp") as TextureButton
	t.ok(lamp.disabled, "lamp is locked by day")
	t.eq(lamp.texture_normal, CardArt.texture("prop.lamp_off"), "day lamp is drawn unlit")
	await _hover(_center(lamp))
	await t.frames(2)
	t.ok(not game.stage.glow_on(&"lamp"), "locked lamp does not glow")
	var abacus := game.stage.get_node("abacus") as Control
	await _hover(_center(abacus))
	await t.frames(2)
	t.ok(game.stage.glow_on(&"abacus"), "hovered abacus glows")
	await _hover(Vector2(640, 200))
	await t.frames(2)
	t.ok(not game.stage.glow_on(&"abacus"), "glow goes when the mouse leaves")
	await _drop_game(game)


## b22 / b23 / b46 / b40.
func _drawers(t, bus: CardEventBus) -> void:
	var game := S.boot(self, bus, "day_full")
	await t.frames(2)
	await _close_all(game)
	game._on_tab(&"settings")
	await t.frames(2)
	var panel := game.host.top_panel()
	t.eq(game.host.top_kind(), &"settings", "settings tab opens settings")
	var body := panel.get_node("Body") as Control
	t.ok(CardLayout.DRAWER_R.grow(1.0).encloses(body.get_global_rect()), "settings sits inside the right drawer")
	var hit := await _hover(_center(body))
	t.ok(hit != null and panel.is_ancestor_of(hit), "the drawer body takes the click")
	var words: Array = []
	for i in 4:
		var b := panel.find_child("Speed%d" % i, true, false) as Button
		words.append(b.text if b != null else "")
	t.eq(words, [CardText.ui("c16.settings.speed.0"), CardText.ui("c16.settings.speed.1"),
		CardText.ui("c16.settings.speed.2"), CardText.ui("c16.settings.speed.3")], "text speeds are words")
	var close: Button = game.table.get_node("Drawer").get("_close")
	hit = await _hover(_center(close))
	t.ok(hit == close, "the drawer's close button is on top (got %s)" % (str(hit.get_path()) if hit != null else "null"))
	for kind in [&"tickets", &"contacts", &"demands", &"dossier", &"shelf"]:
		game._on_tab(kind)
		await t.frames(2)
		if game.host.drawer_open():
			hit = await _hover(_center(close))
			t.ok(hit == close, "%s: close is clickable (got %s)" % [kind, str(hit.get_path()) if hit != null else "null"])
	game.host.close_top()
	await t.frames(1)
	var drawer: Node = game.table.get_node("Drawer")
	for id in CardIds.TABS_L + CardIds.TABS_R:
		var pill: Control = drawer.get("_badges").get(id)
		if pill != null and pill.visible:
			t.ok(CardLayout.SCREEN.encloses(pill.get_global_rect()), "%s badge is on screen" % id)
		var tab: Button = drawer.get("_tabs").get(id)
		var cap := tab.get_node("Caption") as Label
		t.ok(Rect2(Vector2.ZERO, tab.size).encloses(Rect2(cap.position, cap.size)), "%s caption fits its tab" % id)
	await _drop_game(game)


## A mock whose street.redeem_shop fails the way the real engine does when money is short.
class ShortMock:
	extends MockCardEngine

	func send(cmd: StringName, args: Dictionary = {}) -> Dictionary:
		if cmd == &"street.redeem_shop":
			return {"ok": false, "err": CardIds.ERR_INSUFFICIENT_MONEY}
		return super(cmd, args)

	func view() -> Dictionary:
		var v := super()
		v["estates"] = [{"id": "es.shopfront", "money": 400}]
		return v


## b36: 赎回铺面 with too little money says so instead of doing nothing.
func _street_redeem(t, bus: CardEventBus) -> void:
	var game := S.boot(self, bus, "res://scripts/tests/cards/C01/fixtures/street.json")
	await t.frames(2)
	var real = game.engine
	var short := ShortMock.new(bus)
	short.load_fixture("res://scripts/tests/cards/C01/fixtures/street.json")
	game.engine = short
	game._on_redeem_shop()
	game.engine = real
	await t.frames(1)
	var toast = game.get("_toast")
	t.ok(toast.is_showing(), "a failed redeem shows a note")
	t.eq(toast.text(), CardText.ui("c01.toast.redeem_short",
		{"price": 400, "unit": CardText.ui("c01.money.unit.fabi")}), "the note names the price")
	await _drop_game(game)
