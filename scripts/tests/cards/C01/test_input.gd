# C01 1.3 键盘：回话、选手牌、推进对话、打出、Esc 顺序、F1、Tab。
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const S = preload("res://scripts/tests/cards/C01/support.gd")


func _initialize() -> void:
	var t := T.new(self, "C01_input")
	t.run_async(_body.bind(t))


func _body(t) -> void:
	var bus := CardEventBus.new()
	root.add_child(bus)
	var spy = t.spy(bus)
	var game := S.boot(self, bus, "day_full")
	await t.frames(2)
	await _help(t, game)
	await _select(t, game, spy)
	await _replies(t, game)
	await _advance_and_play(t, game)
	await _escape_order(t, game)
	await _overlay_blocks_hand(t, game, spy)
	await _drawer_chrome(t, game)
	await _shared_dialog_inject(t, game)
	await _tab(t, game)
	await _keep(t, game)
	game.queue_free()
	CardAnchors.clear()
	bus.queue_free()
	await t.frames(1)


func _help(t, game) -> void:
	S.press(game, KEY_F1)
	await t.frames(1)
	t.eq(game.host.top_kind(), &"help", "F1 opens help")
	S.press(game, KEY_F1)
	await t.frames(1)
	t.ok(game.host.top_panel() == null, "second F1 closes help")
	S.press(game, KEY_ESCAPE)
	await t.frames(1)
	t.eq(game.host.top_kind(), &"pause", "Esc with nothing open pauses")
	S.press(game, KEY_ESCAPE)
	await t.frames(1)
	t.ok(game.host.top_panel() == null, "Esc closes pause")


func _select(t, game, spy) -> void:
	var uid := str(game.engine.view()["hand"][0].get("uid", ""))
	S.press(game, KEY_1)
	await t.frames(1)
	t.ok(_has_ui(spy, &"hand_selected", "uid", uid), "key 1 selects the first card")


func _replies(t, game) -> void:
	var got := {"id": ""}
	game.dialog.reply_chosen.connect(func(reply_id: String) -> void: got["id"] = reply_id)
	game.dialog.set_replies([
		{"id": "one", "ref": "c01.notice.a", "enabled": true},
		{"id": "two", "ref": "c01.notice.b", "enabled": true},
	])
	S.press(game, KEY_1)
	await t.frames(1)
	t.eq(str(got["id"]), "one", "key 1 picks the first reply")
	game.dialog.clear()


func _advance_and_play(t, game) -> void:
	# 夹具开快放（chars_per_sec 0 时 C04 的对话框直接跳到末行）；这里要逐行，临时调回正常字速
	var cps: int = game.dialog.chars_per_sec
	game.dialog.chars_per_sec = 40
	game.dialog.show_lines("u", [
		{"kind": "narr", "ref": "c01.notice.a"},
		{"kind": "narr", "ref": "c01.notice.b"},
	])
	t.ok(not game.dialog.is_idle(), "two lines are not idle")
	# 空格：先打完这一行，再翻到下一行；两行最多按三下到末行
	for _i in range(3):
		if game.dialog.is_idle():
			break
		S.press(game, KEY_SPACE)
		await t.frames(1)
	t.ok(game.dialog.is_idle(), "space advances to the last line")
	game.dialog.clear()
	game.dialog.chars_per_sec = cps
	var uid := str(game.engine.view()["hand"][0].get("uid", ""))
	var panel := StringName(str(game.engine.query(&"card", {"uid": uid}).get("panel", "none")))
	S.press(game, KEY_1)
	S.press(game, KEY_ENTER)
	await t.frames(1)
	t.eq(game.host.top_kind(), panel, "enter plays the selected card")
	while game.host.top_panel() != null:
		game.host.close_panel(game.host.top_panel())
	await t.frames(1)


func _escape_order(t, game) -> void:
	game.host.open_panel(&"shelf", {})
	game.host.open_panel(&"help", {})
	# day_full 夹具没有 mg.request 的回放；宿主听的是总线。参数形状跟 day_counter 一样。
	game.bus.minigame_requested.emit("c0002", "I001", &"spot", {"kind": "spot", "item": "I001"})
	await t.frames(1)
	t.ok(game.mg_host.is_active(), "minigame is up under help")
	S.press(game, KEY_ESCAPE)
	await t.frames(1)
	t.eq(game.host.top_kind(), &"shelf", "help handles Esc and closes first")
	t.ok(game.mg_host.is_active(), "minigame stays while help closes")
	S.press(game, KEY_ESCAPE)
	await t.frames(2)
	t.ok(not game.mg_host.is_active(), "next Esc aborts the minigame")
	t.eq(game.host.top_kind(), &"shelf", "the drawer stays under the minigame")
	S.press(game, KEY_ESCAPE)
	await t.frames(1)
	t.ok(not game.host.drawer_open(), "Esc closes the drawer")
	t.ok(game.host.top_panel() == null, "the table is back")
	S.press(game, KEY_ESCAPE)
	await t.frames(1)
	t.eq(game.host.top_kind(), &"pause", "Esc then opens pause")
	game.host.close_panel(game.host.top_panel())


func _hand_moved(spy, from: int) -> bool:
	for row in spy.ui_events().slice(from):
		if row[0] == &"hand_played" or row[0] == &"hand_selected":
			return true
	return false


func _overlay_blocks_hand(t, game, spy) -> void:
	# GPT #42 P1 ×2：顶层（暂停/帮助/轮盘/小游戏）开着时 1–9 / 空格 / 回车
	# 不能动底层手牌或底层对话框，但顶层自己的键盘操作必须照常可用。
	var mock: MockCardEngine = game.engine
	# 暂停：回车 = 激活当前项（第一项“继续”）→ 关掉暂停；底层手牌不动。
	var before: int = int(spy.ui_events().size())
	game.host.open_panel(&"pause", {})
	await t.frames(1)
	t.eq(game.host.top_kind(), &"pause", "pause overlay is up")
	S.press(game, KEY_ENTER)
	await t.frames(2)
	t.ok(not game.host.is_open(&"pause"), "Enter activates pause resume (pause closes)")
	t.ok(not _hand_moved(spy, before), "pause Enter does not select/play a hand card")
	# 暂停：空格同样激活。
	before = int(spy.ui_events().size())
	game.host.open_panel(&"pause", {})
	await t.frames(1)
	S.press(game, KEY_SPACE)
	await t.frames(2)
	t.ok(not game.host.is_open(&"pause"), "Space activates pause resume (pause closes)")
	t.ok(not _hand_moved(spy, before), "pause Space does not select/play a hand card")
	# 暂停：数字既不选手牌，也不点底层对话框的回话。
	var got := {"n": 0}
	var on_reply := func(_id: String) -> void: got["n"] = int(got["n"]) + 1
	game.dialog.reply_chosen.connect(on_reply)
	game.dialog.set_replies([
		{"id": "one", "ref": "c01.notice.a", "enabled": true},
		{"id": "two", "ref": "c01.notice.b", "enabled": true},
	])
	before = int(spy.ui_events().size())
	game.host.open_panel(&"pause", {})
	await t.frames(1)
	S.press(game, KEY_1)
	S.press(game, KEY_2)
	await t.frames(1)
	t.eq(int(got["n"]), 0, "pause digits do not pick the dialog reply underneath")
	t.ok(not _hand_moved(spy, before), "pause digits do not select a hand card")
	t.eq(game.host.top_kind(), &"pause", "pause ignores digits and stays")
	# 先开暂停，再显式聚焦底牌并断言前置；必测顶层继续且底层不出牌。
	# （正常暂停会转移焦点，旧写法“先聚焦再开暂停、焦点仍是底牌才测”会被跳过。）
	var card := _focusable_card(game)
	t.ok(card != null, "have a focusable hand card for pause focus test")
	# 关掉上一轮仍开着的暂停
	while game.host.top_panel() != null:
		game.host.close_panel(game.host.top_panel())
	await t.frames(1)
	game.host.open_panel(&"pause", {})
	await t.frames(1)
	t.eq(game.host.top_kind(), &"pause", "pause is up before focusing hand card")
	if card != null:
		card.grab_focus()
		await t.frames(1)
		t.eq(game.get_viewport().gui_get_focus_owner(), card, "hand card focused under open pause")
		before = int(spy.ui_events().size())
		S.press(game, KEY_ENTER)
		await t.frames(2)
		t.ok(not game.host.is_open(&"pause"), "Enter with a hand card focused still goes to pause")
		t.ok(not _hand_moved(spy, before), "focused hand card is not played under pause")
		t.ok(game.host.top_panel() == null or game.host.top_kind() != &"counter", "no card panel opened under pause")
		while game.host.top_panel() != null:
			game.host.close_panel(game.host.top_panel())
		await t.frames(1)
		card.release_focus()
	# 帮助：数字/回车不动手牌。
	game.host.open_panel(&"help", {})
	await t.frames(1)
	before = int(spy.ui_events().size())
	S.press(game, KEY_2)
	S.press(game, KEY_ENTER)
	await t.frames(1)
	t.ok(not _hand_moved(spy, before), "help blocks hand select/play")
	t.eq(int(got["n"]), 0, "help digits do not pick the dialog reply underneath")
	t.eq(game.host.top_kind(), &"help", "help stays")
	game.host.close_panel(game.host.top_panel())
	await t.frames(1)
	# 轮盘：空格 = 开转（真发 wheel.spin，一次），底层不动。
	# 测前开 fast_anim，跳过 2s+ 补间；有界等待并断言揭晓，再必测 Enter。
	# day_full 夹具的 "*" 回包 ok 但无 segment，_play_spin("") 会直接 return——
	# Space 仍断言发了 wheel.spin；揭晓走生产同款 _play_spin(真实扇区)。
	game.host.open_panel(&"wheel", {"wheel": "wh.month"})
	await t.frames(2)
	t.eq(game.host.top_kind(), &"wheel", "wheel overlay is up")
	var wheel: Node = game.host.top_overlay()
	t.ok(wheel != null, "wheel overlay node present")
	if wheel != null and wheel.get("fast_anim") != null:
		wheel.set("fast_anim", true)
	var spins := _count(mock, "wheel.spin")
	before = int(spy.ui_events().size())
	S.press(game, KEY_SPACE)
	await t.frames(2)
	t.eq(_count(mock, "wheel.spin") - spins, 1, "wheel Space spins (one wheel.spin)")
	t.ok(not _hand_moved(spy, before), "wheel Space does not touch the hand")
	t.eq(int(got["n"]), 0, "wheel keys do not pick the dialog reply underneath")
	# 夹具无 segment 时补一次生产揭晓路径，再有界等待（不能条件不成立就略过）。
	if wheel != null and not bool(wheel.get("_revealed")):
		wheel.call("_play_spin", "ws.1938.month.caixing", 13.185)
	var revealed := false
	if wheel != null:
		for _i in range(120):
			if is_instance_valid(wheel) and bool(wheel.get("_revealed")):
				revealed = true
				break
			await t.frames(1)
	t.ok(revealed, "wheel reveals within bound (120 frames)")
	if revealed:
		S.press(game, KEY_ENTER)
		await t.frames(2)
		t.ok(not game.host.is_open(&"wheel"), "wheel Enter continues after the reveal")
	while game.host.top_panel() != null:
		game.host.close_panel(game.host.top_panel())
	await t.frames(1)
	# 小游戏（找瑕疵）：回车 = 落一圈，数字不点底层回话、不选手牌。
	# 给几笔墨（ink），不然 commit_stroke 直接不算。
	game.bus.minigame_requested.emit("c0002", "I001", &"spot", {"kind": "spot", "item": "I001", "ink": 3})
	await t.frames(1)
	t.ok(game.mg_host.is_active(), "spot minigame is up")
	if game.mg_host.is_active():
		var mg: Node = game.mg_host.current
		var strokes := int(mg.get("_strokes"))
		before = int(spy.ui_events().size())
		S.press(game, KEY_1)
		S.press(game, KEY_ENTER)
		await t.frames(1)
		t.eq(int(mg.get("_strokes")) - strokes, 1, "minigame gets its own Enter (one stroke)")
		t.ok(not _hand_moved(spy, before), "minigame keys do not touch the hand")
		t.eq(int(got["n"]), 0, "minigame digits do not pick the dialog reply underneath")
		game.mg_host.abort()
		await t.frames(2)
	game.dialog.reply_chosen.disconnect(on_reply)
	game.dialog.clear()
	await t.frames(1)


func _count(mock: MockCardEngine, cmd: String) -> int:
	var n := 0
	for row in mock.sent:
		if str(row[0]) == cmd:
			n += 1
	return n


func _focusable_card(game) -> Control:
	if game.hand == null:
		return null
	for n in (game.hand as Node).find_children("*", "Control", true, false):
		var c := n as Control
		if c is CardWidget and c.focus_mode != Control.FOCUS_NONE and c.is_visible_in_tree():
			return c
	return null


func _drawer_chrome(t, game) -> void:
	# Title/close hide with the frame (GPT #42 P2).
	var drawer: Node = game.get("_drawer") as Node
	if drawer == null:
		drawer = game.table.get_node_or_null("Drawer")
	t.ok(drawer != null, "drawer host present")
	if drawer == null:
		return
	drawer.show_frame(&"shelf", "r", "c01.tab.shelf")
	await t.frames(1)
	t.ok(drawer._title.visible, "drawer title visible when open")
	t.ok(drawer._close.visible, "drawer close visible when open")
	drawer.hide_frame()
	await t.frames(1)
	t.ok(not drawer._title.visible, "drawer title hidden when closed")
	t.ok(not drawer._close.visible, "drawer close hidden when closed")
	t.ok(drawer._close.focus_mode == Control.FOCUS_NONE, "closed drawer close not focusable")


func _shared_dialog_inject(t, game) -> void:
	# Stage panels receive the shared root dialog (GPT #42 P1).
	var panel := game.host.open_panel(&"demand", {}) as CardStagePanel
	await t.frames(1)
	t.ok(panel != null, "demand panel opened")
	if panel != null:
		t.ok(panel.dialog == game.dialog, "demand uses shared root dialog")
		t.ok(not bool(panel.get("_owns_dialog")), "demand did not spawn a second dialog")
		game.host.close_panel(panel)
	await t.frames(1)


func _tab(t, game) -> void:
	# 打烊按钮挂在叠层宿主里（抽屉之上、叠层之下，换皮 10-22），不再是牌桌的直接子节点。
	var end: Button = game.get("_end")
	end.grab_focus()
	await t.frames(1)
	t.eq(game.get_viewport().gui_get_focus_owner(), end, "close-day has focus")
	S.press(game, KEY_TAB)
	await t.frames(1)
	var nxt: Control = game.get_viewport().gui_get_focus_owner()
	t.ok(nxt != null and nxt != end, "Tab moves focus")


func _keep(t, game) -> void:
	var mock: MockCardEngine = game.engine
	var before := mock.sent.size()
	game._on_action("c0010", "keep")
	t.eq(mock.sent.back(), ["card.keep", {"uid": "c0010"}], "keep action")
	t.ok(mock.sent.size() == before + 1, "one keep command")


func _has_ui(spy, ev_name: StringName, key: String, value: String) -> bool:
	for row in spy.ui_events():
		if row[0] == ev_name and str(row[1].get(key, "")) == value:
			return true
	return false
