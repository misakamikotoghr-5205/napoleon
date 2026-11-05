# 暂停菜单与标题流程：Esc 暂停（钟停）、手动存档（空闲才许、否则灰掉）、设置落盘、返回标题拆干净、
# 标题 → 开张 → 返回标题 → 继续 → 返回标题 → 开张，反复多轮不出错、不重复连信号。
# godot --headless -s res://scripts/tests/town_ui_menu.gd
extends SceneTree

const Settings = preload("res://scripts/town/settings.gd")
const TownGame = preload("res://scripts/town/town_game.gd")
const ShopOnly = preload("res://scripts/town/shop_only.gd")      # [shop-only]

var SAVE: String = TownGame.scratch_save_path("ui_menu")                         # 带进程号：并行跑不抢同一个文件
var SET_PATH: String = "user://town_ui_menu_settings_%d.json" % OS.get_process_id()

var failures: int = 0
var main

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("PASS: ", msg)
	else:
		failures += 1
		print("FAIL: ", msg)

func _initialize() -> void:
	_run()

func _frames(n: int) -> void:
	for i in n:
		await process_frame

func _esc() -> void:
	var ev := InputEventKey.new()
	ev.keycode = KEY_ESCAPE
	ev.physical_keycode = KEY_ESCAPE
	ev.pressed = true
	root.push_input(ev)
	await process_frame

func _buttons(node: Node, out: Array = []) -> Array:
	for c in node.get_children():
		if c is Button:
			out.append(c)
		_buttons(c, out)
	return out

func _button_texts() -> Array:
	var out: Array = []
	for b in _buttons(main.title_layer):
		out.append((b as Button).text)
	return out

func _find_button(texts: Array, wanted: String) -> Button:
	for b in texts:
		if (b as Button).text.find(wanted) >= 0:
			return b
	return null

func _until(cond: Callable, max_frames: int = 1800) -> bool:
	var n := 0
	while not cond.call() and n < max_frames:
		n += 1
		await process_frame
	return cond.call()

func _wait_game(expect_notice: bool = true) -> bool:
	# 新局：等晨间告示弹出再关；读档（白天中途）：不弹告示，等空闲就行
	var ok: bool = await _until(func(): return main.town != null and main.town.running and main.town.mode == "town", 1500)
	if not ok:
		return false
	if expect_notice:
		await _until(func(): return main.town._modal_depth > 0, 600)
		main.town.dismiss_modals()
	return await _until(func(): return main.town.is_idle_in_town(), 600)

func _pause_menu():
	for m in main.town.modal_layer.get_children():
		if m.get_script() != null and str(m.get_script().resource_path).ends_with("pause_menu.gd"):
			return m
	return null

func _cleanup_files() -> void:
	for p in [SAVE, SAVE + ".tmp", SET_PATH]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))

func _new_game_from_title() -> bool:
	var b: Button = _find_button(_buttons(main.title_layer), "开")
	_check(b != null, "标题上有“开张”")
	b.pressed.emit()
	return await _wait_game()

func _run() -> void:
	ShopOnly.set_override(0)      # [shop-only] 这个测试要走到米行里按 Esc：关掉守铺
	_cleanup_files()
	main = load("res://scenes/Main.tscn").instantiate()
	main.autostart = false
	root.add_child(main)
	await process_frame
	main.settings.path = SET_PATH
	main.args = {"seed": "41", "skip-prologue": "1", "fast": "1", "save": SAVE}
	main._show_title()
	await _frames(2)
	# --- 标题按钮 ---
	var texts := _button_texts()
	_check(_find_button(_buttons(main.title_layer), "开") != null, "标题：开张")
	_check(_find_button(_buttons(main.title_layer), "继") == null, "标题：没有存档时没有“继续”")
	_check(_find_button(_buttons(main.title_layer), "设") != null and _find_button(_buttons(main.title_layer), "退") != null, "标题：设置、退出（%s）" % str(texts))
	# --- 开张：新游戏 ---
	var ok: bool = await _new_game_from_title()
	_check(ok and main.title_layer == null and main.mode == "town", "点“开张”进入小镇")
	var town = main.town
	town.seconds_per_minute = 0.01
	town.visitors.abandon("story_d1_open")      # [shop-only] 哥哥的头一场对白会趁玩家站在柜台后自己开始（没人回应就卡住）：这个测试不管剧情，先把他请出去（原来就有的时序不稳）
	town.player.teleport(Vector2(110, 72))      # 不站在柜台后：快钟下客人一到，站着不动半秒就自动开始接待，菜单测试会被拽进柜台页（机器一忙就出现）
	await _frames(4)
	# --- Esc：暂停菜单，钟停 ---
	var m0: int = town.minute
	await _esc()
	var menu = _pause_menu()
	_check(menu != null and town.paused, "Esc 打开暂停菜单，游戏暂停")
	await _frames(60)
	_check(town.minute == m0, "暂停时钟不走（%d）" % town.minute)
	var texts2: Array = []
	for b in _buttons(menu):
		texts2.append((b as Button).text)
	var joined := str(texts2)
	_check(joined.find("继续游戏") >= 0 and joined.find("存档") >= 0 and joined.find("设置") >= 0 and joined.find("返回标题") >= 0 and joined.find("退出游戏") >= 0, "菜单五项齐全")
	# 存档：空闲时可存
	_check(not menu.save_btn.disabled, "空闲时存档可点")
	menu.save_btn.pressed.emit()
	_check(FileAccess.file_exists(SAVE) and menu.status_lbl.text.find("已存档") >= 0, "手动存档写进文件：" + menu.status_lbl.text)
	# 不空闲：灰掉并说明原因
	town.director.current_script = "busy_probe"
	menu.refresh_save_state()
	_check(menu.save_btn.disabled and menu.save_note.visible and menu.save_note.text.length() > 4, "剧情进行中：存档变灰并说明原因（%s）" % menu.save_note.text)
	_check(not town.manual_save().get("ok", true), "手动存档在剧情中被拒绝")
	town.director.current_script = ""
	var real_mode: String = town.mode
	town.mode = "counter"
	_check(not town.can_save().get("ok", true) and str(town.can_save().get("reason", "")) != "", "柜台里不能存档：" + str(town.can_save().get("reason", "")))
	town.mode = real_mode
	# Esc 关掉，继续走钟
	await _esc()
	_check(_pause_menu() == null and not town.paused, "再按 Esc 回到游戏")
	await _frames(40)
	_check(town.minute > m0, "继续后钟又走了（%d → %d）" % [m0, town.minute])
	town.seconds_per_minute = 100000.0     # 钟的检查做完了：往后停住。快钟下走去米行要几秒真实时间，机器一忙当天就过完了（并行跑测试时出现过）
	# 上面那 40 帧在无头快机器上往往只走到 6:50 左右，米行 7:00 才开门，open_shop 会直接返回。
	# 钟已经核对过，这里拨到开门点，不靠帧间隔，也不把这一段的客人拜访放出来。
	town.world.town.s["minute"] = 420
	town.minute = 420
	# --- 店铺特写里：子菜单 Esc 返回，主菜单 Esc 暂停 ---
	await town.goto("ricehall")
	await town.open_shop("ricehall")
	await _until(func(): return town.shop_view.is_open, 120)
	await _esc()
	_check(_pause_menu() != null and town.shop_view.is_open, "店铺特写里 Esc 打开暂停菜单")
	await _esc()
	_check(_pause_menu() == null and town.shop_view.is_open, "关掉菜单仍在店里")
	town.shop_view._run_action({"kind": "buy", "category": "rice", "units": [1, 2], "label": "买米"})
	_check(town.shop_view.menu_title.visible, "进了子菜单")
	await _esc()
	_check(not town.shop_view.menu_title.visible and _pause_menu() == null, "子菜单里 Esc 是返回，不弹暂停菜单")
	town.shop_view.close_shop()
	await _until(func(): return town.is_idle_in_town(), 300)
	# --- 返回标题：要确认 ---
	await _esc()
	menu = _pause_menu()
	menu.title_btn.pressed.emit()
	_check(menu.confirm_box != null and not menu.menu_box.visible, "返回标题先问一句（未存档的进度会丢失）")
	menu._cancel_confirm()
	_check(menu.confirm_box == null and menu.menu_box.visible, "取消：回到暂停菜单")
	var old_town = town
	var old_director = main.director
	menu.title_btn.pressed.emit()
	var yes: Button = _buttons(menu.confirm_box)[0]
	yes.pressed.emit()
	await _frames(6)
	_check(main.town == null and main.director == null and main.world == null, "确认后：小镇、导演、世界都拆掉了")
	_check(not is_instance_valid(old_town) and not is_instance_valid(old_director), "旧的 TownGame 和导演已释放")
	_check(main.title_layer != null and main.mode == "title", "回到标题画面")
	_check(not main.scene_holder.visible and not main.dialogue.visible, "柜台层和对白框是收起的")
	# --- 继续：读刚才的存档 ---
	var cont: Button = _find_button(_buttons(main.title_layer), "继")
	_check(cont != null, "有存档了：标题出现“继续”")
	var saved_day := 1
	cont.pressed.emit()
	ok = await _wait_game(false)
	_check(ok and main.world.day == saved_day, "继续：回到第 %d 天" % main.world.day)
	_check(main.town.minute > 360, "继续：回到白天中途（%d），不重弹告示" % main.town.minute)
	_check(main.director.beat.get_connections().size() <= 2, "导演的 beat 信号没有重复连接（%d）" % main.director.beat.get_connections().size())
	# --- 再回标题，再开新局 ---
	await _esc()
	menu = _pause_menu()
	menu.title_btn.pressed.emit()
	yes = _buttons(menu.confirm_box)[0]
	yes.pressed.emit()
	await _frames(6)
	_check(main.town == null and main.title_layer != null, "第二次返回标题")
	ok = await _new_game_from_title()
	_check(ok and main.world.day == 1 and main.town.minute == 360, "再次“开张”：新的第 1 天 6:00")
	_check(main.director.beat.get_connections().size() <= 2, "新局的 beat 信号也只连了一份（%d）" % main.director.beat.get_connections().size())
	_check(main.world.ledger.check_invariants().is_empty(), "账本不变量没破")
	await _esc()
	menu = _pause_menu()
	menu.title_btn.pressed.emit()
	yes = _buttons(menu.confirm_box)[0]
	yes.pressed.emit()
	await _frames(6)
	# --- 设置：滑条、文字速度、落盘 ---
	main._open_settings()
	await _frames(2)
	var sp: Control = null
	for c in main.get_children():
		if c.get_script() != null and str(c.get_script().resource_path).ends_with("settings_panel.gd"):
			sp = c
	_check(sp != null, "标题上能打开设置面板")
	sp.music_slider.value = 35
	sp.sfx_slider.value = 55
	sp._pick_speed(0)
	_check(main.settings.music == 35 and main.settings.sfx == 55 and main.settings.text_speed == 0, "滑条和文字速度改到了设置里")
	_check(main.dialogue.cps < 30.0, "文字速度“慢”作用到对白打字机（cps=%s）" % str(main.dialogue.cps))
	sp._pick_speed(3)
	_check(main.dialogue.cps > 1000.0, "文字速度“瞬间”")
	sp._pick_speed(1)
	var reread = Settings.new(SET_PATH)
	_check(reread.load_file() and reread.music == 35 and reread.sfx == 55 and reread.text_speed == 1, "设置写进了文件并能读回")
	_check(abs(main.music.volume - 0.35) < 0.001, "音乐音量传给了音乐挂钩（%s）" % str(main.music.volume))
	sp.close()
	await _frames(2)
	# 坏文件：读不出来就用默认，不报错
	var f := FileAccess.open(SET_PATH, FileAccess.WRITE)
	f.store_string("{not json")
	f.close()
	var broken = Settings.new(SET_PATH)
	_check(not broken.load_file() and broken.music == 70, "设置文件损坏时回到默认值")
	_cleanup_files()
	main.queue_free()
	await _frames(3)
	DB.shutdown()
	print("RESULT: ", "OK" if failures == 0 else "FAILED (%d)" % failures)
	quit(0 if failures == 0 else 1)
