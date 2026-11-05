# 小镇界面（h）：睡觉 → 日结 → 第二天早上这一整条线，用真实的（非快钟）淡入淡出走一遍。
#   H1  睡过一觉之后画面不能是黑的：黑幕透明度回到 0、晨间告示看得见（黑幕也不能压在弹窗之上）
#   M1  day_started 发出时，告示已经挂上、钟已经停了（听到信号的人不会误以为能走动）
#   M5  sleep() 不能重入：同一帧连调两次，只有第一次算数，夜里的事只跑一遍
#   M4  自动试玩/测试的存档不碰玩家自己的 user://town_save.json，文件名带进程号
#   返回标题：从日结弹窗（要先问一句）、反复来回，不出错；标题的“继续”接上最近一次自动存档
# godot --headless -s res://scripts/tests/town_ui_night.gd
extends SceneTree

const Common = preload("res://scripts/tests/town_ui_common.gd")
const TownGame = preload("res://scripts/town/town_game.gd")

var c
var main
var town
var seen: Dictionary = {}

func _initialize() -> void:
	_run()

func _on_day_started(day: int) -> void:
	seen[day] = {"depth": town._modal_depth, "paused": town.paused, "idle": town.is_idle_in_town(), "mode": town.mode}

func _summary_panel():
	for m in town.modal_layer.get_children():
		if m.get_script() != null and str(m.get_script().resource_path).ends_with("summary_panel.gd"):
			return m
	return null

func _notice_panel():
	for m in town.modal_layer.get_children():
		if m.get_script() != null and str(m.get_script().resource_path).ends_with("notice_panel.gd"):
			return m
	return null

func _key(code: int) -> void:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.physical_keycode = code
	ev.pressed = true
	root.push_input(ev)
	await process_frame

# 走到当天晚上，睡下，等日结弹窗出来
func _sleep_to_summary(first_try: bool = true) -> bool:
	town.seconds_per_minute = 100000.0
	town.skip_to(1100)
	await town.goto("bed")
	var started: bool = town.sleep()
	if first_try:
		c.check(started, "18:00 后在床边睡觉：sleep() 返回 true")
	return await c.until(func(): return _summary_panel() != null, 1200)

func _title_buttons() -> Array:
	var out: Array = []
	var stack: Array = [main.title_layer]
	while not stack.is_empty():
		var n = stack.pop_back()
		for ch in n.get_children():
			if ch is Button:
				out.append(ch)
			stack.append(ch)
	return out

func _title_button(text: String) -> Button:
	for b in _title_buttons():
		if (b as Button).text.find(text) >= 0:
			return b
	return null

# 标题按钮会调 main._begin_town()；先把小镇建好，接上 autoplayer（回应夜里的剧情），再开局
func _prepare_town() -> void:
	main._ensure_town()
	town = main.town
	town.auto_dismiss = true
	town.director_ready.connect(c._on_director)
	town.day_started.connect(_on_day_started)

func _wait_game_ready() -> bool:
	var ok: bool = await c.until(func(): return main.town != null and main.town.running and main.town.mode == "town", 1500)
	if not ok:
		return false
	town = main.town
	await c.until(func(): return town._modal_depth > 0 or town.is_idle_in_town(), 600)
	town.dismiss_modals()
	return await c.until(func(): return town.is_idle_in_town(), 900)

func _return_to_title_from_summary() -> void:
	var panel = _summary_panel()
	panel.title_btn.pressed.emit()
	await process_frame
	c.check(panel.confirm_lbl != null and not panel.go_btn.visible, "日结上点“返回标题”：先问一句，“睡下”按钮收起")
	await _key(KEY_ENTER)
	await _key(KEY_ESCAPE)
	c.check(_summary_panel() != null and panel.confirm_lbl == null and panel.go_btn.visible and town.mode == "night", "问话时 Enter 不算“睡下”；Esc 是取消，日结还在")
	panel.title_btn.pressed.emit()
	await process_frame
	panel.yes_btn.pressed.emit()
	await c.frames(6)

func _run() -> void:
	var real_save := TownGame.SAVE_PATH
	var real_time: int = FileAccess.get_modified_time(real_save) if FileAccess.file_exists(real_save) else -1
	var scratch := TownGame.scratch_save_path("auto")
	TownGame.remove_save_files(scratch)
	c = Common.new(self)
	await c.make_main()
	main = c.main
	town = c.town
	main.args = {"seed": "5", "skip-prologue": "1", "clock": "0.05", "save": TownGame.scratch_save_path("night_test")}
	TownGame.remove_save_files(main.args["save"])
	# 存档路径故意留成玩家的默认路径，并且开着自动存档：自动模式应当改写到带进程号的临时文件
	town.autosave = true
	town.save_path = real_save
	town.set_fast(false)
	town.auto_dismiss = true
	town.director_ready.connect(c._on_director)
	town.day_started.connect(_on_day_started)
	town.new_game(5, "常年", true)
	await town.day_started
	c.check(seen.has(1) and int(seen[1]["depth"]) >= 1 and bool(seen[1]["paused"]) and not bool(seen[1]["idle"]),
		"M1：day_started 发出时告示已挂上、钟已停（depth=%s paused=%s idle=%s）" % [str(seen[1]["depth"]), str(seen[1]["paused"]), str(seen[1]["idle"])])
	c.check(_notice_panel() != null and _notice_panel().visible, "M1：这时候晨间告示就在界面上")
	c.check(town.sleep() == false, "M1：告示开着时 sleep() 被拒并返回 false（不让调用方傻等 day_finished）")
	await c.until_idle()
	c.check(FileAccess.file_exists(scratch), "M4：自动存档写在带进程号的临时文件里（%s）" % scratch)
	var real_time2: int = FileAccess.get_modified_time(real_save) if FileAccess.file_exists(real_save) else -1
	c.check(real_time2 == real_time, "M4：玩家自己的 town_save.json 没被碰（%d → %d）" % [real_time, real_time2])
	town.save_path = main.args["save"]      # 之后的自动存档写到本测试自己的文件，供“继续”读

	# ---------- 睡觉 ----------
	c.check(await _sleep_to_summary(), "睡下后日结弹窗出现")
	var actions_before: int = int(town.director.vars["town"].get("night_actions", 0))
	c.check(town.sleep() == false and town.sleep(true) == false, "M5：已经在睡了，再调 sleep() / sleep(true) 都被拒")
	c.check(int(town.director.vars["town"].get("night_actions", 0)) == actions_before, "M5：强制睡的惩罚没被重复记（night_actions=%d）" % actions_before)
	c.check(town.fade_rect.modulate.a < 0.01, "H1：日结弹窗出来时黑幕是透明的（%.2f）" % town.fade_rect.modulate.a)
	c.check(town.fade_rect.get_index() < town.modal_layer.get_index(), "H1：黑幕画在弹窗层之下")
	var summary = _summary_panel()
	c.check(summary != null and summary.visible and summary.title_btn != null, "日结弹窗上有“返回标题”")
	summary.go_btn.pressed.emit()
	await town.day_started
	await c.frames(2)
	c.check(town.world.day == 2, "第 2 天")
	c.check(seen.has(2) and int(seen[2]["depth"]) >= 1 and bool(seen[2]["paused"]) and not bool(seen[2]["idle"]), "M1：第 2 天 day_started 发出时告示已挂上")
	var notice = _notice_panel()
	c.check(notice != null and notice.visible and notice.is_inside_tree(), "H1：第 2 天早上的告示在界面上")
	c.check(town.sleep(true) == false and town.world.day == 2, "M5：过夜流程（含晨间告示）没走完之前，强制睡也被拒")
	c.check(town.fade_rect.modulate.a < 0.01, "H1：第 2 天早上黑幕是透明的（%.2f）" % town.fade_rect.modulate.a)
	c.check(town.world_view.visible and town.mode == "town" and main.mode == "town", "H1：第 2 天早上看得见当铺（world_view 可见，mode=%s）" % town.mode)
	c.check(not main.scene_holder.visible, "H1：柜台层不盖在上面")
	await c.frames(10)
	c.check(town.fade_rect.modulate.a < 0.01 and _notice_panel() != null, "H1：过几帧之后还是亮的")
	town.dismiss_modals()
	await c.until_idle()
	c.check(town.fade_rect.modulate.a < 0.01, "H1：进入第 2 天可走动状态后仍是亮的")

	# ---------- 第 2 天夜里：从日结弹窗返回标题 ----------
	c.check(await _sleep_to_summary(false), "第 2 天夜里，日结弹窗出现")
	await _return_to_title_from_summary()
	c.check(main.town == null and main.director == null and main.world == null, "确认后：小镇、导演、世界都拆掉了")
	c.check(main.title_layer != null and main.mode == "title", "回到标题画面")
	var cont: Button = _title_button("继")
	c.check(cont != null, "标题上有“继续”（有自动存档）")
	# 继续：接上最近一次存档（第 2 天早上）
	_prepare_town()
	main._begin_town("", true)
	c.check(await _wait_game_ready(), "继续：读档回到小镇")
	c.check(abs(town.seconds_per_minute - 0.05) < 0.0001, "M2：--clock=0.05 在读档后仍然生效（%s）" % str(town.seconds_per_minute))
	c.check(main.world.day == 2 and town.minute >= 360 and town.minute < 420, "继续：第 2 天早上（day=%d minute=%d）" % [main.world.day, town.minute])
	c.check(town.world.ledger.check_invariants().is_empty(), "继续后账本不变量没破")

	# ---------- 再来一轮：日结 → 标题 → 开张 → 日结 → 标题 ----------
	c.check(await _sleep_to_summary(false), "继续之后又睡下，日结弹窗出现（第 %d 天）" % town.world.day)
	await _return_to_title_from_summary()
	c.check(main.town == null and main.title_layer != null, "第二次从日结返回标题")
	var start: Button = _title_button("开")
	c.check(start != null, "标题上有“开张”")
	_prepare_town()
	main._begin_town()
	c.check(await _wait_game_ready(), "再次开张")
	c.check(abs(town.seconds_per_minute - 0.05) < 0.0001, "M2：--clock=0.05 在新局里生效（%s）" % str(town.seconds_per_minute))
	c.check(main.world.day == 1 and town.minute >= 360 and town.minute < 420, "新局：第 1 天早上（minute=%d）" % town.minute)
	c.check(main.director.beat.get_connections().size() <= 2, "导演的 beat 信号只连了一份（%d）" % main.director.beat.get_connections().size())
	c.check(await _sleep_to_summary(false), "新局第一夜，日结弹窗出现")
	await _return_to_title_from_summary()
	c.check(main.town == null and main.title_layer != null and not main.scene_holder.visible and not main.dialogue.visible, "第三次从日结返回标题，柜台层和对白框都收起")

	# 没有存档却点了“继续”（或存档读不出来）：读档失败也要拆干净、回到标题，并且之后还能正常开张
	TownGame.remove_save_files(main.args["save"])
	main._begin_town("", true)
	await c.frames(8)
	c.check(main.town == null and main.director == null and main.title_layer != null, "读档失败：回到标题，半开的小镇已拆掉")
	_prepare_town()
	main._begin_town()
	c.check(await _wait_game_ready(), "读档失败之后还能正常开张")
	main._return_to_title()
	await c.frames(4)
	c.check(main.town == null and main.title_layer != null, "最后一次返回标题")

	for p in [scratch, main.args["save"]]:
		TownGame.remove_save_files(p)
	var fails: int = c.failures
	print("RESULT: ", "OK" if fails == 0 else "FAILED (%d)" % fails)
	await c.shutdown()
	quit(0 if fails == 0 else 1)
