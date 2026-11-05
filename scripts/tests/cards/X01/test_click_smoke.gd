# X01 真点鼠标冒烟（10-22 能玩版）：像玩家一样不带参数把 CardGame.tscn 设成当前场景，
# 只用鼠标移动 + 按下/松开（root.push_input(ev, true)，无头窗口是 0×0）和少量真按键走一遍：
#   标题 → 设置（面板中心最上层的控件属于设置面板）→ 关掉 → 标题上 F1/Esc 不在背后开面板
#   → 新局 → 开月面板点着往下翻 → 开始 → 月轮盘转一下、继续 → 早上自动开张（第 1 天）
#   → 点手牌、点“出牌”开出一张牌的面板 → Esc 收起 → 打烊 · 下一天（要确认就点确认）→ 夜里点“睡了”
#   → 日结点“天亮” → 早上自动开张（第 2 天）。
# 每次点击前先发鼠标移动，断言 root.gui_get_hovered_control() 就是要点的控件（或它里面的控件），
# 层级遮挡（比如标题盖住设置）因此会红。
# 玩家路径写 user://cards/** 和 user://settings.json：开跑前备份、删掉（当作第一次启动），跑完还原。
# 带 --shots=<目录> 时在关键画面存 1280×720 截图（要在 xvfb 下跑，无头模式不出图）。
# 主人 X01（10-22 能玩版，Claude）。
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const SAVE_DIR := "user://cards"
const LEGACY_SETTINGS := "user://settings.json"
const WAIT_MS := 25000

var t
var game: CardGameRoot = null
var _shots: String = ""
var _backup: Dictionary = {}


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if str(a).begins_with("--shots="):
			_shots = str(a).substr(8)
	t = T.new(self, "X01_click_smoke")
	t.run_async(_body)


func _body() -> void:
	_take_backup()
	var t0 := Time.get_ticks_msec()
	await _run()
	if game != null and is_instance_valid(game):
		game.queue_free()
		await t.frames(3)
	await _new_game_error()
	_restore_backup()
	print("X01_click_smoke_ms %d" % (Time.get_ticks_msec() - t0))


func _run() -> void:
	change_scene_to_file(CardIds.ROOT_SCENE)
	for _i in range(60):
		await process_frame
		game = current_scene as CardGameRoot
		if game != null and game.engine != null and game.title != null:
			break
	t.ok(game != null and game.title != null, "CardGame.tscn boots to the title with no args")
	if game == null or game.title == null:
		return
	game.allow_quit = false
	t.ok(game.engine is CardEngine, "player launch runs the real engine")
	await t.frames(2)
	await _shot("title")
	if not await _title_settings():
		return
	if not await _title_keys():
		return
	# 新局
	var new_btn := game.title.get_node_or_null("new") as Button
	t.ok(new_btn != null and not new_btn.disabled, "new game button is clickable")
	if not await _click(new_btn, "title new"):
		return
	await t.frames(3)
	t.ok(game.title == null, "new game closes the title")
	t.eq(str(game.engine.view().get("phase", "")), "month_open", "new game opens the month")
	if not await _month_open():
		return
	if not await _wheel():
		return
	if not await _morning(1, "morning auto-starts day 1"):
		return
	await t.frames(5)
	await _shot("day1")
	if not await _open_hand_card():
		return
	if not await _end_day():
		return
	if not await _night():
		return
	if not await _settle():
		return
	await _morning(2, "morning auto-starts day 2")


## 牌的骨架数据有错（这里是一份截断的 JSON）时 game.new 会拒绝：标题上要看得见提示，不能点了没反应。
## 文本（text_ai、剧情插件）有错只警告、不挡新局，所以这里用骨架数据。
func _new_game_error() -> void:
	var bad: CardGameRoot = load(CardIds.ROOT_SCENE).instantiate()
	bad.boot({"mock": false, "bus": root.get_node_or_null("CardBus"), "guide": "off", "save_dir": t.user_dir(), "settings_path": "",
		"data_root": "res://scripts/tests/cards/X01/fixtures/bad_card_data"})
	bad.allow_quit = false
	root.add_child(bad)
	await t.frames(2)
	var keep := game
	game = bad
	var btn := bad.title.get_node_or_null("new") as Button
	await _click(btn, "broken data: title new")
	await t.frames(2)
	t.ok(bad.title != null, "failed new game keeps the title up")
	t.eq(str(bad.engine.view().get("phase", "")), "boot", "failed new game does not start")
	var err := bad.title.get_node_or_null("Error") as Label if bad.title != null else null
	t.ok(err != null and err.is_visible_in_tree(), "failed new game shows an error line on the title")
	if err != null:
		t.ok(err.text.contains(CardText.ui("c16.title.new_failed")), "error line uses c16.title.new_failed")
		t.ok(err.text.contains("broken.json"), "error line names the broken file")
	await _shot("new_game_error")
	game = keep
	bad.queue_free()
	await t.frames(3)


# ---------------- 标题 ----------------

func _title_settings() -> bool:
	var btn := game.title.get_node_or_null("settings") as Button
	t.ok(btn != null, "title settings button")
	if not await _click(btn, "title settings"):
		return false
	await t.frames(3)
	t.eq(str(game.host.top_kind()), "settings", "settings opens from the title")
	var panel := game.host.top_panel()
	if panel == null:
		return false
	t.ok(panel.is_visible_in_tree(), "settings panel is visible")
	# b22（换皮 10-22）：设置是右抽屉（PANEL_SHOW drawer_r），排在抽屉身子里，不再是屏幕正中的方块；
	# 量抽屉身子的正中（以前量 (640, 340)，那是旧的居中样子）。
	var body := panel.get_node_or_null("Body") as Control
	var at := body.get_global_rect().get_center() if body != null else CardLayout.DRAWER_R.get_center()
	t.ok(CardLayout.DRAWER_R.encloses(Rect2(at, Vector2.ONE)), "settings body sits in the right drawer")
	var hit := await _hover(at)
	t.ok(hit != null and (hit == panel or panel.is_ancestor_of(hit)),
		"top control at the settings panel centre belongs to settings (got %s)" % _path_of(hit))
	await _shot("settings")
	var close := _find_button(panel, CardText.ui("c16.settings.close"))
	t.ok(close != null, "settings close button")
	if not await _click(close, "settings close"):
		return false
	await t.frames(3)
	t.eq(str(game.host.top_kind()), "", "settings closes")
	t.ok(game.title != null, "title is still up after settings")
	# 再开一次，用 Esc 关（键给标题上开着的面板，不给背后的牌桌）。
	if not await _click(btn, "title settings again"):
		return false
	await t.frames(3)
	t.eq(str(game.host.top_kind()), "settings", "settings opens again")
	await _key(KEY_ESCAPE)
	await t.frames(3)
	t.eq(str(game.host.top_kind()), "", "escape closes settings over the title")
	return true


func _title_keys() -> bool:
	await _key(KEY_F1)
	await t.frames(2)
	t.eq(str(game.host.top_kind()), "", "F1 on the title does not open help behind it")
	await _key(KEY_ESCAPE)
	await t.frames(2)
	t.eq(str(game.host.top_kind()), "", "escape on the title does not open pause behind it")
	t.ok(game.title != null, "title stays up")
	return game.title != null


# ---------------- 开月、轮盘 ----------------

func _month_open() -> bool:
	if not await _wait(func() -> bool: return game.host.top_kind() == &"month_open", "month_open panel opens"):
		return false
	var panel := game.host.top_panel()
	t.ok(panel.is_visible_in_tree(), "month_open panel is visible")
	var hit := await _hover(Vector2(640, 300))
	t.ok(hit != null and (hit == panel or panel.is_ancestor_of(hit)),
		"top control over the month intro belongs to month_open (got %s)" % _path_of(hit))
	await _shot("month_open")
	var goals := panel.find_child("Goals", true, false) as Control
	var guard := 0
	while goals != null and not goals.is_visible_in_tree() and guard < 12:
		guard += 1
		await _click_at(Vector2(640, 300), panel, "month intro page")
		await t.frames(2)
	t.ok(goals != null and goals.is_visible_in_tree(), "clicking turns the intro pages to the goals (%d clicks)" % guard)
	var begin := panel.find_child("Begin", true, false) as Button
	t.ok(begin != null, "begin button")
	if not await _click(begin, "month begin"):
		return false
	return await _wait(func() -> bool: return game.host.top_kind() == &"wheel", "wheel opens after the month panel")


func _wheel() -> bool:
	var panel := game.host.top_panel()
	var spin := panel.find_child("Spin", true, false) as Button
	var cont := panel.find_child("Continue", true, false) as Button
	t.ok(spin != null and cont != null, "wheel spin and continue buttons")
	if spin == null or cont == null:
		return false
	await _shot("wheel")
	if not await _click(spin, "wheel spin"):
		return false
	await t.frames(3)
	var err := panel.find_child("Err", true, false) as Label
	if not cont.visible and err != null and err.visible:
		# 要先上香（交钱）才能转：点“上香”，再转。
		var offer := panel.find_child("Offer", true, false) as Button
		if offer != null and offer.visible and not offer.disabled:
			await _click(offer, "wheel offer")
			await t.frames(3)
		await _click(spin, "wheel spin after offer")
	if not await _wait(func() -> bool: return cont.is_visible_in_tree(), "wheel stops and shows continue"):
		return false
	await t.frames(2)
	if not await _click(cont, "wheel continue"):
		return false
	return true


# ---------------- 白天 ----------------

func _open_hand_card() -> bool:
	var fan := game.hand
	var cards: Array = fan.get("_cards")
	var slots: Array = fan.get("_slots")
	var pick := -1
	for i in cards.size():
		if str((cards[i] as Dictionary).get("panel", "none")) not in ["none", ""]:
			pick = i
			break
	t.ok(pick >= 0, "day 1 hand has a card with a panel (%d cards)" % cards.size())
	if pick < 0 or pick >= slots.size():
		return false
	var uid := str((cards[pick] as Dictionary).get("uid", ""))
	var want := str(game.engine.query(&"card", {"uid": uid}).get("panel", ""))
	var slot := slots[pick] as Control
	# 悬停会把牌抬起来：先移过去、等一帧，再按抬起后的位置点。
	await _hover(_center(slot))
	await t.frames(2)
	if not await _click(slot, "hand card"):
		return false
	await t.frames(2)
	var play := fan.get_node_or_null("PreviewButtons/Play") as Button
	t.ok(play != null and play.is_visible_in_tree(), "selected card shows the play button")
	if play == null:
		return false
	if not await _click(play, "hand play"):
		return false
	if not await _wait(func() -> bool: return game.host.top_panel() != null, "playing the card opens its panel"):
		return false
	await t.frames(10)
	t.ok(game.host.is_open(StringName(want)), "the clicked card opened its own panel '%s' (top %s)" % [want, game.host.top_kind()])
	await _shot("day1_" + want)
	# 收起面板（Esc，真按键），回到牌桌。
	var guard := 0
	while game.host.top_panel() != null and guard < 4:
		guard += 1
		await _key(KEY_ESCAPE)
		await t.frames(4)
	t.eq(str(game.host.top_kind()), "", "escape puts the card panel away")
	return true


func _end_day() -> bool:
	var end := game.get("_end") as Button
	t.ok(end != null, "close-day button")
	if not await _click(end, "close day"):
		return false
	await t.frames(4)
	if game.host.top_kind() == &"end_day":
		var confirm := game.host.top_panel().find_child("BtnConfirm", true, false) as Button
		t.ok(confirm != null, "end-day confirm button")
		if not await _click(confirm, "end-day confirm"):
			return false
	if not await _wait_phase("night", 1, "close day goes to night"):
		return false
	return await _wait(func() -> bool: return game.host.is_open(&"night"), "night panel opens")


func _night() -> bool:
	await t.frames(6)
	await _shot("night")
	var fan := game.hand
	var cards: Array = fan.get("_cards")
	var slots: Array = fan.get("_slots")
	var pick := -1
	for i in cards.size():
		if str((cards[i] as Dictionary).get("def", "")) == "":
			pick = i
	t.ok(pick >= 0, "night fan has the sleep card (%d cards)" % cards.size())
	if pick < 0 or pick >= slots.size():
		return false
	var slot := slots[pick] as Control
	await _hover(_center(slot))
	await t.frames(2)
	if not await _click(slot, "night sleep card"):
		return false
	await t.frames(2)
	var play := fan.get_node_or_null("PreviewButtons/Play") as Button
	if not await _click(play, "night play"):
		return false
	return await _wait_phase("settle", 1, "sleeping goes to settle")


func _settle() -> bool:
	if not await _wait(_dawn_ready, "settle offers dawn"):
		return false
	await t.frames(2)
	return await _click(_reply_button("dawn"), "settle dawn")


func _dawn_ready() -> bool:
	var b := _reply_button("dawn")
	return b != null and b.is_visible_in_tree()


# ---------------- 工具 ----------------

func _reply_button(reply_id: String) -> Button:
	for n in _walk(game.dialog):
		if n is Button and str((n as Button).get_meta("reply_id", "")) == reply_id:
			return n
	return null


## 早上自动开张要等指引讲完（合同 §7.10.7：is_pending 为真就等，不设上限）：像玩家一样真点“知道了”。
func _morning(day: int, msg: String) -> bool:
	var start := Time.get_ticks_msec()
	while Time.get_ticks_msec() - start < WAIT_MS:
		if _at_phase("day", day):
			t.ok(true, msg)
			return true
		var ok := game.guide.get_node_or_null("Chrome/Bubble/Ok") as Button
		var step := game.guide.active_step()
		if step != "" and ok != null and ok.is_visible_in_tree() and str(game.engine.view().get("phase", "")) == "morning":
			if not await _click(ok, "got it on " + step):
				return false
			await t.frames(2)
			continue
		await process_frame
	return await _wait_phase("day", day, msg)


func _wait_phase(phase: String, day: int, msg: String) -> bool:
	return await _wait(_at_phase.bind(phase, day), msg)


func _at_phase(phase: String, day: int) -> bool:
	var v := game.engine.view()
	return str(v.get("phase", "")) == phase and int(v.get("date", {}).get("stage_day", 0)) == day


func _wait(cond: Callable, msg: String) -> bool:
	var start := Time.get_ticks_msec()
	while Time.get_ticks_msec() - start < WAIT_MS:
		if cond.call():
			t.ok(true, msg)
			return true
		await process_frame
	var v := game.engine.view()
	t.ok(false, "%s (timed out; phase=%s day=%s top=%s)" % [msg, v.get("phase", ""),
		v.get("date", {}).get("stage_day", 0), game.host.top_kind()])
	return false


func _center(c: Control) -> Vector2:
	return c.get_global_transform_with_canvas() * (c.size * 0.5)


func _hover(at: Vector2) -> Control:
	var mv := InputEventMouseMotion.new()
	mv.position = at
	mv.global_position = at
	root.push_input(mv, true)
	await process_frame
	return root.gui_get_hovered_control()


## Real click on a control: move there, check it is the top control under the mouse, press, release.
func _click(c: Control, label: String) -> bool:
	t.ok(c != null and c.is_visible_in_tree(), label + ": control is visible")
	if c == null or not c.is_visible_in_tree():
		return false
	return await _click_at(_center(c), c, label)


func _click_at(at: Vector2, owner: Control, label: String) -> bool:
	var hit := await _hover(at)
	var ok := hit != null and (hit == owner or owner.is_ancestor_of(hit))
	t.ok(ok, "%s: top control under the mouse is %s (want %s)" % [label, _path_of(hit), _path_of(owner)])
	if not ok:
		return false
	for down in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = down
		ev.position = at
		ev.global_position = at
		ev.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
		root.push_input(ev, true)
		await process_frame
	return true


func _key(code: Key) -> void:
	for down in [true, false]:
		var ev := InputEventKey.new()
		ev.keycode = code
		ev.physical_keycode = code
		ev.pressed = down
		root.push_input(ev)
		await process_frame


func _find_button(node: Node, text: String) -> Button:
	for n in _walk(node):
		if n is Button and (n as Button).text == text:
			return n
	return null


func _walk(n: Node) -> Array:
	var out: Array = [n]
	for c in n.get_children():
		out.append_array(_walk(c))
	return out


func _path_of(n: Node) -> String:
	if n == null:
		return "<none>"
	return str(n.get_path()).replace("/root/", "")


func _shot(shot_name: String) -> void:
	if _shots == "" or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(_shots)
	var img := root.get_texture().get_image()
	img.save_png(_shots.path_join(shot_name + ".png"))
	print("X01_click_smoke shot %s %dx%d" % [shot_name, img.get_width(), img.get_height()])


# ---------------- 玩家文件的备份与还原 ----------------

func _take_backup() -> void:
	_backup = {}
	for path in _player_files():
		_backup[path] = FileAccess.get_file_as_bytes(path)
	for path in _backup.keys():
		DirAccess.remove_absolute(path)


func _restore_backup() -> void:
	for path in _player_files():
		if not _backup.has(path):
			DirAccess.remove_absolute(path)
	for path in _backup.keys():
		DirAccess.make_dir_recursive_absolute(str(path).get_base_dir())
		var f := FileAccess.open(path, FileAccess.WRITE)
		if f != null:
			f.store_buffer(_backup[path])
			f.close()


func _player_files() -> Array:
	var out: Array = []
	if FileAccess.file_exists(LEGACY_SETTINGS):
		out.append(LEGACY_SETTINGS)
	if DirAccess.dir_exists_absolute(SAVE_DIR):
		for f in DirAccess.get_files_at(SAVE_DIR):
			out.append(SAVE_DIR.path_join(f))
	return out
