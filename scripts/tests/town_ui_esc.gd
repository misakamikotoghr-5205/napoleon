# Esc 全局可用（标题除外）与弹窗用 E 关闭：序章、柜台交易、夜里、街上的对话里 Esc 都先关面板、再开暂停菜单；
# 对白只用 E/空格/回车推进；暂停时钟和打字机冻结；返回标题（序章中、柜台中）拆干净；告示/家用簿/日结/货架都能用 E 关，且这一下不漏给背后的“按 E 交互”。
# godot --headless -s res://scripts/tests/town_ui_esc.gd
extends SceneTree

const Common = preload("res://scripts/tests/town_ui_common.gd")
const TownGame = preload("res://scripts/town/town_game.gd")

var failures: int = 0
var main
var town

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

func _key(code: int) -> void:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.physical_keycode = code
	ev.pressed = true
	root.push_input(ev)
	await process_frame

func _until(cond: Callable, max_frames: int = 1800) -> bool:
	var n := 0
	while not cond.call() and n < max_frames:
		n += 1
		await process_frame
	return cond.call()

func _pause_menu():
	if town == null or town.modal_layer == null:
		return null
	for m in town.modal_layer.get_children():
		if m.get_script() != null and str(m.get_script().resource_path).ends_with("pause_menu.gd"):
			return m
	return null

func _modal_named(file: String):
	if town == null or town.modal_layer == null:
		return null
	for m in town.modal_layer.get_children():
		if m.get_script() != null and str(m.get_script().resource_path).ends_with(file):
			return m
	return null

func _buttons(node: Node, out: Array = []) -> Array:
	for c in node.get_children():
		if c is Button:
			out.append(c)
		_buttons(c, out)
	return out

func _make_main() -> void:
	main = load("res://scenes/Main.tscn").instantiate()
	main.autostart = false
	root.add_child(main)
	await process_frame
	main._ensure_town()
	town = main.town
	town.autosave = false
	town.save_path = TownGame.scratch_save_path("ui_esc")

func _cleanup() -> void:
	TownGame.remove_save_files(TownGame.scratch_save_path("ui_esc"))
	if main != null and is_instance_valid(main):
		main.queue_free()
	main = null
	town = null
	await _frames(3)

# 点“返回标题”并确认
func _title_via_menu() -> void:
	var menu = _pause_menu()
	menu.title_btn.pressed.emit()
	var yes: Button = _buttons(menu.confirm_box)[0]
	yes.pressed.emit()
	await _frames(6)

func _run() -> void:
	# ============ 序章（柜台画面，小镇模式里的第一段）============
	await _make_main()
	town.set_fast(false)
	town.new_game(5, "常年", false)        # 不 await：序章要一直演下去，由测试来推
	var got: bool = await _until(func(): return main.cur_type != "", 600)
	var guard := 0
	while main.cur_type == "caption" and guard < 12:        # 序章先是几张字幕：空格往下翻
		guard += 1
		await _key(KEY_SPACE)
		await _frames(3)
	got = await _until(func(): return main.cur_type in ["say", "narr"], 600)
	_check(got and main.mode == "counter" and town.map_id == "" and not town.running, "序章：柜台画面里有一句对白在等（%s）" % main.cur_type)
	var beat0: Dictionary = main.cur
	_check(not main.dialogue.instant, "（前提）对白是逐字打出来的")
	await _key(KEY_ESCAPE)
	var menu = _pause_menu()
	_check(menu != null and get_root_paused(), "序章里 Esc 打开暂停菜单，整棵树停住")
	_check(main.cur == beat0, "Esc 没有把这句对白推进（对白只用 E/空格/回车/点击）")
	var texts: Array = []
	for b in _buttons(menu):
		texts.append((b as Button).text)
	var joined := str(texts)
	_check(joined.find("继续游戏") >= 0 and joined.find("存档") >= 0 and joined.find("设置") >= 0 and joined.find("返回标题") >= 0 and joined.find("退出游戏") >= 0, "序章里的暂停菜单五项齐全")
	_check(menu.save_btn.disabled and menu.save_note.visible and menu.save_note.text.length() > 4, "序章里存档灰着并说明原因（%s）" % menu.save_note.text)
	# 打字机冻结
	main.dialogue.show_line("测试", "这一句很长很长很长很长很长很长很长很长很长很长很长很长很长。", Color.WHITE, false, true)
	await _frames(3)
	var typed0: float = main.dialogue.shown_chars
	await _frames(40)
	_check(main.dialogue.typing and absf(main.dialogue.shown_chars - typed0) < 0.001, "暂停时对白打字机不动（%.1f）" % main.dialogue.shown_chars)
	var m_before: int = town.minute
	await _frames(20)
	_check(town.minute == m_before, "暂停时钟不走")
	# 再按 Esc 关掉；对白还在原处
	await _key(KEY_ESCAPE)
	_check(_pause_menu() == null and not get_root_paused(), "再按 Esc 回到序章，树放开了")
	await _frames(10)
	_check(main.dialogue.shown_chars > typed0, "放开后打字机继续")
	# E 推进对白（用补全+再按）
	main.dialogue.finish_typing()
	await _frames(40)       # 过了防连点的间隔
	var beat1: Dictionary = main.cur
	main.dialogue.instant = true
	await _key(KEY_E)
	_check(main.cur != beat1 or main.cur_type == "", "E 推进了序章的对白")
	main.dialogue.instant = false
	# 返回标题（序章中）
	await _key(KEY_ESCAPE)
	var old_town = town
	var old_director = main.director
	await _title_via_menu()
	_check(main.town == null and main.director == null and main.world == null, "序章中返回标题：小镇、导演、世界都拆掉了")
	_check(not is_instance_valid(old_town) and not is_instance_valid(old_director), "旧的 TownGame 和导演已释放")
	_check(main.title_layer != null and main.mode == "title" and not get_root_paused(), "回到标题，树没停住")
	_check(not main.scene_holder.visible and not main.dialogue.visible and not main.ticket.visible and not main.telegraph.visible and not main.caption_layer.visible, "柜台层、对白框、当票、电报、字幕都收起了")
	_check(main.cur_type == "" and main.cur.is_empty(), "没有残留的待回应拍子")
	town = null
	await _key(KEY_ESCAPE)
	_check(main.mode == "title" and main.title_layer != null and main.get_node_or_null("TownGame") == null, "标题上 Esc 什么都不开")
	await _cleanup()
	var fails1 := failures
	print("== 序章段完成，失败累计 ", fails1)
	await _phase_counter()
	await _phase_modals()
	print("RESULT: ", "OK" if failures == 0 else "FAILED (%d)" % failures)
	DB.shutdown()
	quit(0 if failures == 0 else 1)

func get_root_paused() -> bool:
	return paused

# ---------------------------------------------------------------- 柜台交易
func _phase_counter() -> void:
	var c = Common.new(self)
	await c.boot(13, false, false)
	main = c.main
	town = c.town
	town.seconds_per_minute = 100000.0
	town.skip_to(1090)                   # 傍晚的路人客有议价会话（早上的是剧情客人）
	await c.until(func(): return not town.visitors.present.is_empty(), 900)
	var visit: Dictionary = {}
	for id in town.visitors.present:
		if str(id).begins_with("visit_d1"):
			visit = town.visitors.present[id]["visit"]
	_check(not visit.is_empty(), "（前提）傍晚有路人客：%s" % str(visit.get("id", "")))
	town.start_counter(visit)            # 不 await：交易由测试来推
	var got: bool = await _until(func(): return main.cur_type != "" and town.mode == "counter", 600)
	_check(got, "柜台交易开始：%s 拍在等（模式 %s）" % [main.cur_type, town.mode])
	# 推到议价拍，沿途每一拍 Esc 都是暂停，不是推进
	var n := 0
	while main.cur_type != "counter" and n < 60 and main.cur_type != "":
		n += 1
		var beat: Dictionary = main.cur
		await _key(KEY_ESCAPE)
		_check(_pause_menu() != null and main.cur == beat, "交易里（%s 拍）Esc 开暂停菜单，拍子没被推进" % main.cur_type) if n <= 2 else null
		await _key(KEY_ESCAPE)
		_check(_pause_menu() == null and not paused, "再按 Esc 回到交易") if n <= 2 else null
		main.dialogue.instant = true
		await _key(KEY_SPACE)
		await _frames(2)
	_check(main.cur_type == "counter" and director_session_open(), "走到了议价拍")
	var session_beat: Dictionary = main.cur
	# 放大镜面板开着：Esc 先关它，再按才是暂停菜单
	main.inspect.open(town.director.session)
	await _frames(2)
	_check(main.inspect.visible, "（前提）放大镜面板开着")
	await _key(KEY_ESCAPE)
	_check(not main.inspect.visible and _pause_menu() == null, "Esc 先关放大镜面板，不弹暂停菜单")
	await _key(KEY_ESCAPE)
	_check(_pause_menu() != null and main.cur == session_beat, "放大镜关了以后再按 Esc 才是暂停菜单；议价拍还在")
	var menu = _pause_menu()
	_check(menu.save_btn.disabled and menu.save_note.visible, "议价中存档灰着并说明原因（%s）" % menu.save_note.text)
	await _key(KEY_ESCAPE)
	_check(_pause_menu() == null and not paused, "关掉暂停菜单回到议价")
	# 账簿册子：E 和 Esc 都能关
	main.book.open("ledger", town.world)
	await _frames(2)
	_check(main.book.visible, "（前提）账簿开着")
	await _key(KEY_E)
	_check(not main.book.visible and _pause_menu() == null, "E 关掉账簿，不触发别的")
	main.book.open("notebook", town.world)
	await _frames(2)
	await _key(KEY_ESCAPE)
	_check(not main.book.visible and _pause_menu() == null, "Esc 关掉档案簿，不弹暂停菜单")
	# 万年历
	main._open_calendar()
	await _frames(2)
	_check(main.generic_panel.visible, "（前提）万年历开着")
	await _key(KEY_ESCAPE)
	_check(not main.generic_panel.visible and _pause_menu() == null, "Esc 关掉万年历")
	main._open_calendar()
	await _frames(2)
	await _key(KEY_E)
	_check(not main.generic_panel.visible, "E 关掉万年历")
	# 钱匣侧栏：议价中它是交易的一部分，Esc 不能把它关掉（只会暂停）
	_check(main.sidebar.visible and main.sidebar.session != null, "（前提）议价侧栏开着")
	await _key(KEY_ESCAPE)
	_check(_pause_menu() != null and main.sidebar.visible, "议价侧栏不被 Esc 关掉，只是暂停")
	# 柜台中途返回标题：拆干净
	var old_town = town
	var old_director = main.director
	await _title_via_menu()
	_check(main.town == null and main.director == null and not is_instance_valid(old_town) and not is_instance_valid(old_director), "柜台交易中返回标题：小镇和导演都释放了")
	_check(main.title_layer != null and not paused, "回到标题，树没停住")
	_check(not main.scene_holder.visible and not main.dialogue.visible and not main.sidebar.visible and not main.inspect.visible and not main.book.visible and not main.generic_panel.visible, "柜台层、侧栏、验货面板、册子全收起了")
	_check(main.cur_type == "" and main.cur.is_empty() and main.sidebar.session == null and not main.sidebar.practice_mode, "没有残留的拍子、议价会话")
	# 返回标题之后能重新开张，再来一遍不出错
	main.args = {"seed": "41", "skip-prologue": "1", "fast": "1", "save": TownGame.scratch_save_path("ui_esc")}
	var ok: bool = await _until(func(): return main.title_layer != null, 30)
	_check(ok, "标题画面在")
	main._begin_town()
	ok = await _until(func(): return main.town != null and main.town.running and main.town.mode == "town", 1500)
	_check(ok and main.world.day == 1, "返回标题后再开张：新的第 1 天")
	await _until(func(): return main.town._modal_depth > 0, 600)
	main.town.dismiss_modals()
	town = main.town
	await _until(func(): return town.is_idle_in_town(), 600)
	await _key(KEY_ESCAPE)
	_check(_pause_menu() != null, "新局里 Esc 照常打开暂停菜单")
	await _key(KEY_ESCAPE)
	await c.shutdown()
	main = null
	town = null

func director_session_open() -> bool:
	return town.director != null and town.director.session != null

# ---------------------------------------------------------------- 弹窗用 E 关；街上的对话；夜里
func _phase_modals() -> void:
	var c = Common.new(self)
	await c.boot(13, false, false)
	main = c.main
	town = c.town
	town.seconds_per_minute = 100000.0
	town.auto_dismiss = false
	town.dismiss_modals()
	await _frames(3)
	# --- 街上（当铺里）的对话气泡：Esc 暂停，不推进；E 推进 ---
	town.overlay.speak(town.player, "测试", ["第一句", "第二句"])
	await _frames(2)
	_check(town.overlay.is_speaking(), "（前提）头顶气泡在说话")
	await _key(KEY_ESCAPE)
	_check(_pause_menu() != null and town.overlay.is_speaking() and town.overlay._line_index == 0, "气泡说话时 Esc 开暂停菜单，没有推进对白")
	await _key(KEY_ESCAPE)
	_check(_pause_menu() == null and town.overlay._line_index == 0, "关掉菜单，对白还在第一句")
	await _key(KEY_E)
	_check(town.overlay._line_index == 1, "E 推进气泡对白")
	await _key(KEY_ESCAPE)
	_check(_pause_menu() != null and town.overlay.is_speaking() and town.overlay._line_index == 1, "第二句上 Esc 依然只是暂停")
	await _key(KEY_ESCAPE)
	await _key(KEY_SPACE)
	_check(not town.overlay.is_speaking(), "空格把对白说完")
	# --- 站在床边（18:00 后 E 会睡觉）：用 E 关弹窗不能顺手睡下 ---
	town.skip_to(1100)
	await town.goto("bed")
	await _frames(3)
	var near: Dictionary = town._find_near()
	_check(str(near.get("label", "")) == "睡觉", "（前提）傍晚站在床边，E 是睡觉（提示：%s）" % str(near.get("label", "")))
	town.open_panel("household")
	await _frames(2)
	var household = _modal_named("household_panel.gd")
	_check(household != null and town.paused, "家用簿弹出")
	await _key(KEY_E)
	_check(_modal_named("household_panel.gd") == null and town._modal_depth == 0, "E 关掉家用簿")
	_check(not town.is_sleeping() and town.mode == "town", "关家用簿的那下 E 没有漏给床：没有睡下")
	town.open_panel("household")
	await _frames(2)
	await _key(KEY_ESCAPE)
	_check(_modal_named("household_panel.gd") == null and _pause_menu() == null, "Esc 关家用簿，不弹暂停菜单")
	town.open_panel("household")
	await _frames(2)
	await _key(KEY_SPACE)
	_check(_modal_named("household_panel.gd") == null and not town.is_sleeping(), "空格也能关家用簿")
	town.open_panel("household")
	await _frames(2)
	await _key(KEY_ENTER)
	_check(_modal_named("household_panel.gd") == null and not town.is_sleeping(), "回车也能关家用簿")
	# 货架、告示
	town.open_shelf()
	await _frames(2)
	_check(_modal_named("shelf_panel.gd") != null, "货架弹出")
	await _key(KEY_E)
	_check(_modal_named("shelf_panel.gd") == null and not town.is_sleeping(), "E 关掉货架，没有睡下")
	town.show_board()
	await _frames(2)
	_check(_modal_named("notice_panel.gd") != null, "告示弹出")
	await _key(KEY_E)
	_check(_modal_named("notice_panel.gd") == null and town._modal_depth == 0 and not town.is_sleeping(), "E 关掉告示，没有睡下")
	# 早上的告示（第二天用的同一个面板）：和 show_board 同类，再确认按钮标注
	var plan: Dictionary = {"day": town.world.day, "notice": town.world.town.notice(), "bills": town.world.town.bills(), "household": town.household()}
	var NoticePanel = load("res://scripts/town/notice_panel.gd")
	var np = NoticePanel.new()
	np.build(town, plan)
	town._open_modal(np)
	await _frames(2)
	var labels: Array = []
	for b in _buttons(np):
		labels.append((b as Button).text)
	_check(str(labels).find("E") >= 0, "告示的按钮标着 E（%s）" % str(labels))
	await _key(KEY_E)
	_check(not is_instance_valid(np) or np.is_closed(), "晨间告示 E 可关")
	_check(town._modal_depth == 0, "弹窗计数落回 0")
	# 日结弹窗：E 关（睡下）；返回标题的确认态里 E 不关
	var SummaryPanel = load("res://scripts/town/summary_panel.gd")
	var sp = SummaryPanel.new()
	sp.build(town, {"day": 1, "weather": "晴", "cash": 100, "accounts": {"income": 10, "expense": 5}, "handled": [], "missed": [], "bill_total": 0, "bill_paid": 0, "unpaid": 0, "household": town.household()})
	town._open_modal(sp)
	await _frames(2)
	sp.title_btn.pressed.emit()
	await _key(KEY_E)
	_check(is_instance_valid(sp) and not sp.is_closed(), "日结里问“返回标题？”时 E 不会把日结关掉")
	await _key(KEY_ESCAPE)
	_check(is_instance_valid(sp) and not sp.is_closed() and sp.confirm_lbl == null, "Esc 是取消返回标题")
	await _key(KEY_E)
	_check((not is_instance_valid(sp) or sp.is_closed()) and town._modal_depth == 0, "日结 E 可关")
	# --- 设置面板：Esc 关 ---
	town.open_pause()
	await _frames(2)
	_pause_menu().settings_btn.pressed.emit()
	await _frames(2)
	_check(_modal_named("settings_panel.gd") != null, "设置面板弹出")
	await _key(KEY_ESCAPE)
	_check(_modal_named("settings_panel.gd") == null and _pause_menu() != null, "Esc 关设置面板，回到暂停菜单")
	await _key(KEY_ESCAPE)
	_check(_pause_menu() == null and not paused, "再 Esc 关暂停菜单")
	# --- 夜里：睡觉 → 夜里的事（柜台层），Esc 暂停 ---
	var slept: bool = town.sleep()
	_check(slept, "傍晚睡觉：开始过夜")
	var night_ok: bool = await _until(func(): return town.mode == "night" and main.cur_type != "", 900)
	_check(night_ok, "夜里：%s 拍在等（模式 %s）" % [main.cur_type, town.mode])
	var nbeat: Dictionary = main.cur
	await _key(KEY_ESCAPE)
	_check(_pause_menu() != null and main.cur == nbeat, "夜里 Esc 开暂停菜单，不推进")
	_check(_pause_menu().save_btn.disabled, "夜里存档灰着（%s）" % _pause_menu().save_note.text)
	await _key(KEY_ESCAPE)
	_check(_pause_menu() == null and not paused, "关掉菜单回到夜里")
	await _key(KEY_ESCAPE)
	await _title_via_menu()
	_check(main.town == null and main.title_layer != null and not paused and not main.scene_holder.visible, "夜里返回标题：拆干净")
	await c.shutdown()
	main = null
	town = null
