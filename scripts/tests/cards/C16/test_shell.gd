# 标题、暂停、牌桌往返。没有续玩点时“继续”不能点。暂停按钮发出约定的 close_requested。
# 主人 C16。合同：docs/cards/CARDS_INTERFACES.md §3.3 C16、§7.8。
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")


func _initialize() -> void:
	var t := T.new(self, "C16_shell")
	t.run_async(_body.bind(t))


func _body(t) -> void:
	CardSave.set_root(t.user_dir())
	# 隔离目录固定按测试名；上次中断残留的 suspend 会让「无存档」门假绿。
	var suspend := CardSave.suspend_path()
	var had_leftover := CardSave.exists(suspend)
	print("C16_shell_user_dir " + t.user_dir() + " leftover_suspend=" + str(had_leftover))
	if had_leftover:
		DirAccess.remove_absolute(suspend)
	var bus := CardEventBus.new()
	root.add_child(bus)
	await _continue_gate(t, bus, false)
	_touch(CardSave.suspend_path())
	await _continue_gate(t, bus, true)
	await _cycle(t, bus, true, true)
	await t.frames(4)
	var before := int(Performance.get_monitor(Performance.OBJECT_COUNT))
	for _i in 3:
		await _cycle(t, bus, true, false)
		await t.frames(3)
	var after := int(Performance.get_monitor(Performance.OBJECT_COUNT))
	print("C16_shell_delta " + str(after - before))
	t.ok(after <= before + 8, "three title round-trips do not leak objects")
	t.eq(int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)), 0, "no orphan nodes")
	bus.queue_free()
	await t.frames(2)


func _continue_gate(t, bus: CardEventBus, enabled: bool) -> void:
	var game: CardGameRoot = load(CardIds.ROOT_SCENE).instantiate()
	game.boot(_opts(bus))
	root.add_child(game)
	await t.frames(2)
	t.ok(game.title != null, "title is up")
	var cont := _button(game.title, "c16.title.continue")
	t.ok(cont != null, "continue button exists")
	t.eq(cont.disabled, not enabled, "continue enabled only with a suspend file")
	if not enabled:
		await _title_keys(t)
	else:
		await _title_real_keys(t, game)
	var bad: PackedStringArray = t.all_text_from_cardtext(game.title)
	t.ok(bad.is_empty(), "title text comes from CardText")
	game.queue_free()
	await t.frames(2)


func _cycle(t, bus: CardEventBus, use_continue: bool, check_pause: bool) -> void:
	var game: CardGameRoot = load(CardIds.ROOT_SCENE).instantiate()
	game.boot(_opts(bus))
	if game.get("allow_quit") != null:
		game.set("allow_quit", false)
	root.add_child(game)
	await t.frames(2)
	var key := "c16.title.continue" if use_continue else "c16.title.new"
	_button(game.title, key).pressed.emit()
	await t.frames(2)
	t.ok(game.title == null, "title closes into the table")
	t.ok(game.table != null, "table is up")
	_key(game, KEY_ESCAPE)
	await t.frames(1)
	t.eq(str(game.host.top_kind()), "pause", "escape opens pause")
	if check_pause:
		await _pause_results(t, game)
		_key(game, KEY_ESCAPE)
		await t.frames(1)
	var pause: CardPause = game.host.top_panel()
	t.ok(t.anchor_ok(&"a.pause.help"), "pause help anchor is on screen")
	var got: Array = []
	pause.close_requested.connect(func(r: Dictionary) -> void: got.append(r))
	t.ok(pause.autoplay_step(), "pause autoplay takes a step")
	t.eq(got[0], {}, "pause autoplay resumes")
	game.queue_free()
	CardAnchors.clear()


func _pause_results(t, game: CardGameRoot) -> void:
	var expect := [
		["c16.pause.settings", {"next": {"kind": "settings", "args": {}}}],
		["c16.pause.help", {"next": {"kind": "help", "args": {}}}],
		["c16.pause.title", {"to_title": true}],
		["c16.pause.quit", {"quit": true}],
	]
	for row in expect:
		if str(game.host.top_kind()) != "pause":
			_key(game, KEY_ESCAPE)
			await t.frames(1)
		var pause: CardPause = game.host.top_panel()
		var got: Array = []
		pause.close_requested.connect(func(r: Dictionary) -> void: got.append(r))
		var btn := _button(pause, str(row[0]))
		t.ok(btn != null, "pause button " + str(row[0]))
		btn.pressed.emit()
		if (row[1] as Dictionary).has("to_title") or (row[1] as Dictionary).has("quit"):
			# b50（换皮 10-22）：离开 / 回到标题先问一句（早上以后的进度会丢），“再想想”回到菜单，“确定”才发出去。
			await t.frames(1)
			t.eq(got.size(), 0, "%s asks before leaving" % str(row[0]))
			var no := _button(pause, "c16.pause.confirm_no")
			t.ok(no != null, "%s confirm has a way back" % str(row[0]))
			if no != null:
				no.pressed.emit()
				await t.frames(1)
				t.eq(got.size(), 0, "%s: going back sends nothing" % str(row[0]))
				t.ok(_button(pause, str(row[0])) != null, "%s: back on the pause menu" % str(row[0]))
			_button(pause, str(row[0])).pressed.emit()
			await t.frames(1)
			var yes := _button(pause, "c16.pause.confirm_yes")
			t.ok(yes != null, "%s confirm button" % str(row[0]))
			if yes != null:
				yes.pressed.emit()
		t.eq(got[0] if not got.is_empty() else {}, row[1], "close_requested for " + str(row[0]))
		await t.frames(1)
		if (row[1] as Dictionary).has("to_title"):
			# 回标题：桌上的面板全收掉；标题上按 Esc 不在背后开暂停（10-22 能玩版）。再从标题回到牌桌。
			t.ok(game.title != null, "to_title shows the title")
			t.eq(str(game.host.top_kind()), "", "to_title closes every panel")
			_key(game, KEY_ESCAPE)
			await t.frames(1)
			t.eq(str(game.host.top_kind()), "", "escape on the title does not open pause behind it")
			_key(game, KEY_F1)
			await t.frames(1)
			t.eq(str(game.host.top_kind()), "", "F1 on the title does not open help behind it")
			_button(game.title, "c16.title.continue").pressed.emit()
			await t.frames(2)
			t.ok(game.title == null, "title closes back into the table")


func _opts(bus: CardEventBus) -> Dictionary:
	return {
		"mock": true, "bus": bus, "seed": 7, "fixture": "morning", "guide": "off",
		"settings_path": CardSave.root() + "/boot_settings.json",
	}


func _title_keys(t) -> void:
	var title: CardTitle = load("res://scenes/cards/shell/CardTitle.tscn").instantiate()
	root.add_child(title)
	await t.frames(1)
	var got: Array = []
	title.chose.connect(func(a: StringName) -> void: got.append(a))
	_key(title, KEY_DOWN)
	_key(title, KEY_ENTER)
	t.eq(got, [&"settings"], "keyboard skips a disabled continue and confirms settings")
	title.queue_free()
	await t.frames(1)


## b04 / b06（换皮 10-22）：真按键走视口。有存档时按一下“下”焦点到“接着做生意”，回车就是接着做生意（以前开了新局）；
## 焦点在四颗按钮里绕圈，不跑到标题背后的牌桌上。
func _title_real_keys(t, game: CardGameRoot) -> void:
	var title: CardTitle = game.title
	var got: Array = []
	var spy := func(a: StringName) -> void: got.append(a)
	title.chose.connect(spy)
	var vp := title.get_viewport()
	t.eq(vp.gui_get_focus_owner(), title.get_node("new"), "title focus starts on new")
	for i in 6:
		await _push_key(KEY_UP)
		var f: Control = vp.gui_get_focus_owner()
		t.ok(f != null and title.is_ancestor_of(f), "Up #%d keeps focus on the title (got %s)" % [i, str(f)])
	await _push_key(KEY_TAB)
	t.ok(title.is_ancestor_of(vp.gui_get_focus_owner()), "Tab keeps focus on the title")
	title.call("_select", 0)
	await _push_key(KEY_DOWN)
	t.eq(vp.gui_get_focus_owner(), title.get_node("continue"), "Down moves focus to continue")
	# 只看 chose 发了什么，不真的读档：先把标题的 chose 和根断开。
	if title.chose.is_connected(game._on_title):
		title.chose.disconnect(game._on_title)
	await _push_key(KEY_ENTER)
	t.eq(got, [&"continue"], "Enter after Down picks continue, once")
	title.chose.connect(game._on_title)


func _push_key(code: Key) -> void:
	for down in [true, false]:
		var ev := InputEventKey.new()
		ev.keycode = code
		ev.physical_keycode = code
		ev.pressed = down
		root.push_input(ev)
		await process_frame


func _touch(path: String) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string("{}\n")
	f.close()


func _button(node: Node, key: String) -> Button:
	var want := CardText.ui(key)
	for n in _all(node):
		if n is Button and (n as Button).text == want:
			return n
	return null


func _all(n: Node) -> Array:
	var out: Array = [n]
	for c in n.get_children():
		out.append_array(_all(c))
	return out


func _key(node: Node, code: Key) -> void:
	var ev := InputEventKey.new()
	ev.pressed = true
	ev.keycode = code
	ev.physical_keycode = code
	node._unhandled_input(ev)
