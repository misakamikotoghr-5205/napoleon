# 前期引导（onboarding）：第一天的步骤会亮、按对的事完成、存档继续不重来、关掉开关就不亮、操作说明从暂停菜单/标题/F1 都能开关。
# godot --headless -s res://scripts/tests/town_ui_guide.gd
extends SceneTree

const Common = preload("res://scripts/tests/town_ui_common.gd")
const TownGame = preload("res://scripts/town/town_game.gd")
const HelpPanel = preload("res://scripts/town/help_panel.gd")
const Guide = preload("res://scripts/town/guide.gd")

var c
var failures: int = 0
var SET_PATH: String = "user://town_ui_guide_settings_%d.json" % OS.get_process_id()

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("PASS: ", msg)
	else:
		failures += 1
		print("FAIL: ", msg)

func _initialize() -> void:
	_run()

func _key(code: int) -> void:
	for down in [true, false]:
		var ev := InputEventKey.new()
		ev.keycode = code
		ev.physical_keycode = code
		ev.pressed = down
		root.push_input(ev)
		await process_frame

func _active_id(g) -> String:
	return str(g.active.get("id", ""))

func _step_on(g, id: String) -> Callable:
	return func(): return str(g.active.get("id", "")) == id and g._phase == "in"

# 新局：不自动关告示、不用自动试玩；让引导自己亮。fast：瞬间淡入淡出、人走得快
func _boot(seed_v: int = 7) -> void:
	c = Common.new(self)
	await c.make_main()
	c.main.settings.path = SET_PATH
	c.town.set_fast(true)
	c.town.auto_dismiss = false
	c.town.new_game(seed_v, "常年", true)
	await c.town.day_started

func _free_idle(g) -> void:
	g._idle_t = 99.0
	g._gap = 0.0

func _run() -> void:
	# ---------------- 1. 第一天早晨：告示上的“按 E 收起” ----------------
	await _boot()
	var town = c.town
	var g = town.guide
	town.seconds_per_minute = 100000.0             # 钟停住，免得时间一走带出别的步骤
	c.check(g != null and g.enabled(), "引导默认开着")
	c.check(g.key_defs.size() == 5, "按键条数据：WASD / Shift / E / Esc / 走到门口按 E 出门，五项")
	c.check(await c.until(_step_on(g, "notice_close"), 600), "第一天告示一打开，亮出“按 E 收起”")
	c.check(str(g._btxt.text).find("按 E") >= 0 and g._bubble.visible, "提示文字写着“按 E 收起”，气泡显示着")
	c.check(town._modal_depth > 0, "此时告示还开着（提示不替玩家收起）")
	var map = town.world_view.map
	await _key(KEY_E)
	town.player.teleport(map.nearest_free(Vector2(100, 160)))      # 离开柜台：哥哥的事不会自己开场（站着不动半秒就开场了）；柜台前的空地，往右走不碰柜台和长凳
	await c.frames(2)
	c.check(town._modal_depth == 0, "按 E 把告示收起了")
	c.check(await c.until(func(): return g.is_done("notice_close"), 400), "告示一收起，这一步算完成")
	c.check(await c.until(func(): return g.active.is_empty(), 600), "完成后提示渐隐消失")

	# ---------------- 2. 走路、跑、交互、菜单：按键条逐个淡出 ----------------
	_free_idle(g)
	c.check(await c.until(func(): return g.strip_visible_keys().size() == 5, 600), "第一天空闲时，底部按键条五项都亮着")
	c.check(await c.until(_step_on(g, "brother_calls"), 900), "哥哥在铺里等着、人不在柜台：他喊你去柜台后面")
	c.check(not g._active_speaker.is_empty() and str(g._active_speaker.get("label", "")).find("哥哥") >= 0, "这句话是哥哥的气泡（从他站的地方冒出来）")
	c.check(g._marker.info.get("kind", "") == "point", "柜台那一格亮着发光标记")
	# 走起来：moved；按住 Shift：ran
	town.player.use_external = true
	town.player.external_input = Vector2(1, 0)
	town.player.running_external = true
	await c.frames(40)
	town.player.external_input = Vector2(0, 0)
	town.player.use_external = false
	town.player.running_external = false
	c.check(g.has_seen("moved"), "走了几步：记下 moved")
	c.check(g.has_seen("ran"), "按住 Shift 走：记下 ran")
	c.check(await c.until(func(): return not g.strip_visible_keys().has("moved") and not g.strip_visible_keys().has("ran"), 900), "走过、跑过的键从按键条上淡出了")
	c.check(g.strip_visible_keys().has("interacted") and g.strip_visible_keys().has("pause_opened"), "没用过的 E、Esc 还留在条上")
	# E 交互：站到货架边，interact() 成功
	town.player.teleport(map.nearest_free(Vector2(110, 72)))
	await c.frames(3)
	town._near = town._find_near()
	c.check(not town._near.is_empty(), "货架边有可交互的东西（%s）" % str(town._near.get("label", "")))
	town.interact()
	await c.frames(3)
	c.check(g.has_seen("interacted"), "按 E 交互成功：记下 interacted")
	town.dismiss_modals()
	await c.frames(3)
	# Esc 菜单
	town.open_pause()
	await c.frames(3)
	c.check(g.has_seen("pause_opened"), "打开菜单：记下 pause_opened")
	town.dismiss_modals()
	await c.frames(3)
	c.check(await c.until(func(): return g.strip_visible_keys() == ["left_shop"], 900), "四个键都用过：只剩“走到门口按 E 出门”还亮着")
	g.on_travel_opened()                                              # 打开“去哪儿”地图（或走出当铺）
	c.check(await c.until(func(): return g.strip_visible_keys().is_empty(), 900), "出过门：按键条整条消失")
	town.dismiss_modals()
	await c.frames(3)

	# ---------------- 3. 第一位客人 ----------------
	town.player.teleport(map.nearest_free(Vector2(240, 140)))
	for id in ["brother_calls", "move_keys", "interact_e", "esc_menu", "hud_buttons", "rule_pawn", "rule_sell_brother", "go_counter"]:
		g.mark_done(id)
	g._finish(false, "context")
	await c.frames(30)
	town.skip_to(545)
	c.check(await c.until(func(): return not town.visitors.next_ready().is_empty(), 900), "九点，小丁进门站定")
	await c.frames(10)
	_free_idle(g)
	g.active = {}
	g._phase = ""
	c.check(await c.until(_step_on(g, "customer_arrives"), 900), "客人站定、玩家不在柜台：亮出“站到柜台后按 E 接待”")
	c.check(str(g._btxt.text).find("柜台") >= 0 and str(g._btxt.text).find("E") >= 0, "文字：站到柜台后面，按 E 接待")
	c.check(town.world.pages.has("rule_counter"), "这句话说出口时，柜台规矩记进了档案簿")
	g.on_counter({"who": "xiaoding", "kind": "visit"})             # 接待开始（钩子）
	c.check(await c.until(func(): return g.is_done("customer_arrives"), 400), "开始接待：这一步按“customer_served”完成")
	c.check(await c.until(func(): return g.active.is_empty(), 600), "完成后渐隐")

	# ---------------- 4. 店铺特写：第一次进米行，一行字说这里能办什么 ----------------
	for vid in town.visitors.present.keys():
		town.visitors.abandon(str(vid))                       # 铺里没有客人等着了
	g.active = {}
	g._phase = ""
	_free_idle(g)
	await town.open_shop("ricehall")
	c.check(await c.until(_step_on(g, "shop_ricehall"), 900), "第一次进米行特写：亮出这家店能办的事")
	c.check(str(g._btxt.text).find("米行") >= 0 and str(g._btxt.text).find("买米") >= 0, "文字取自 shops/ricehall.json 的动作名：%s" % str(g._btxt.text))
	c.check(g._marker.info.get("kind", "") == "rect", "动作菜单旁亮着标记")
	c.check(town.world.pages.has("rule_shops"), "第一次说“这家店能办什么”：镇上的店记进了档案簿")
	town.shop_view.close_shop()
	await c.until(func(): return town.mode == "town", 600)
	await c.frames(6)
	await c.until(func(): return g.active.is_empty(), 900)
	g._gap = 0.0

	# ---------------- 5. 出门：当铺的门口；“去哪儿”地图的接口 ----------------
	town.day_number = 2
	town.director.vars["town"]["household"]["rice"] = 2
	town._refresh_home()
	await town.goto("inside")
	_free_idle(g)
	g.state()["seen"].erase("left_shop")
	c.check(await c.until(_step_on(g, "rice_low_exit"), 900), "米缸快空了：当铺里指向出门")
	c.check(str(g.active.get("anchor", {}).get("to_map", "")) == "town", "标记在当铺的门上")
	g.on_travel_opened()
	await c.frames(10)
	c.check(g.has_seen("left_shop") and g.has_seen("travel_opened"), "出门（打开去哪儿地图）：记下 left_shop")
	c.check(await c.until(func(): return g.active.is_empty(), 900), "出了门，当铺门口的提示收起")
	# 去哪儿地图：登记图标位置、盖过 ui
	g.state()["seen"].erase("travel_chosen")            # 前面进过米行特写：这里模拟“第一次打开地图”
	g.state()["done"].erase("travel_pick")
	g.register_travel_anchor("_map", func() -> Rect2: return Rect2(300, 200, 600, 360))
	g.register_travel_anchor("ricehall", func() -> Rect2: return Rect2(640, 300, 96, 80))
	g.set_ui_override("travel")
	g._gap = 0.0
	g._eval_t = 0.0
	c.check(await c.until(_step_on(g, "travel_pick"), 900), "打开“去哪儿”地图：第一次提示选去处")
	c.check(g._marker.info.get("kind", "") == "rect", "整张地图亮着标记（地图那边登记的位置）")
	g.on_travel_chosen("pharmacy")
	c.check(await c.until(func(): return g.is_done("travel_pick"), 600), "选定一个去处：这一步完成")
	c.check(await c.until(func(): return g.active.is_empty(), 900), "完成后渐隐")
	g._gap = 0.0
	g._eval_t = 0.0
	c.check(await c.until(_step_on(g, "rice_low_travel"), 900), "米缸快空：地图上米行的图标亮着（travel_map:ricehall）")
	c.check(g.active_info.get("kind", "") != "" or g._marker.info.get("kind", "") == "rect", "标记落在登记的矩形上")
	g.set_ui_override("")
	g.unregister_travel_anchors()
	await c.frames(6)
	c.check(await c.until(func(): return g.active.is_empty(), 900), "地图关上后提示消失")
	g._gap = 0.0

	# ---------------- 6. 存档继续：不重来 ----------------
	var done_before: Dictionary = g.state()["done"].duplicate()
	c.check(done_before.has("notice_close") and done_before.has("customer_arrives"), "进度里记着完成过的步骤")
	town.player.teleport(map.nearest_free(Vector2(240, 140)))
	await town.goto("inside")
	c.check(town.save_game(), "存档成功")
	var save_path: String = town.save_path
	var shown_before: Dictionary = g.state()["shown"].duplicate()
	c.main.queue_free()
	await c.frames(3)
	var main2
	var c2 = Common.new(self)
	await c2.make_main()
	c2.main.settings.path = SET_PATH
	c2.town.save_path = save_path
	c2.town.set_fast(true)
	c2.town.auto_dismiss = false
	c2.town.autosave = false
	var ok2: bool = await c2.town.load_game()
	c.check(ok2, "继续游戏：读档成功")
	await c2.frames(20)
	if c2.town._modal_depth > 0:
		c2.town.dismiss_modals()
	var g2 = c2.town.guide
	await c2.frames(5)
	c.check(g2.is_done("notice_close") and g2.is_done("customer_arrives"), "读档后，完成过的步骤还记着")
	c.check(g2.has_seen("moved") and g2.has_seen("ran") and g2.has_seen("interacted") and g2.has_seen("pause_opened"), "读档后，用过的键还记着")
	c2.town.seconds_per_minute = 100000.0
	c2.town.player.teleport(c2.town.world_view.map.nearest_free(Vector2(240, 140)))
	g2._idle_t = 99.0
	await c2.frames(40)
	var shown_after: Dictionary = g2.state()["shown"]
	var repeated: Array = []
	for id in done_before:
		if shown_after.get(id, 0) != shown_before.get(id, 0):
			repeated.append(id)
	c.check(repeated.is_empty(), "读档后完成过的步骤没有重新亮起（重复的：%s）" % str(repeated))
	c.check(not g2.strip_visible_keys().has("moved"), "按键条上没有再出现已经用过的键")
	c.check(await c2.until(func(): return g2.strip_visible_keys().is_empty(), 900), "四个键都用过：读档后按键条也不再出现")

	# ---------------- 7. 开关：关掉就不亮，开着就继续 ----------------
	c2.main.settings.guide_hints = true
	g2.active = {}
	g2._phase = ""
	g2.state()["done"].erase("move_keys")
	g2.state()["seen"].erase("moved")
	g2.state()["shown"].erase("move_keys")
	g2._travel = 0.0
	g2._gap = 0.0
	g2._idle_t = 99.0
	c.check(await c2.until(func(): return g2.active.has("id"), 600), "开着：又有步骤亮起来")
	c2.main.settings.guide_hints = false
	await c2.frames(5)
	c.check(g2.active.is_empty() and not g2._bubble.visible, "新手提示=关：正在亮的提示立刻收起")
	await c2.frames(60)
	c.check(g2.active.is_empty() and not g2._strip.visible, "关着：不会有新的提示，按键条也不显示")
	c.check(not g2.enabled(), "enabled() 为 false")
	# 设置落盘：存进 settings.json
	c2.main.settings.save_file()
	var Settings = load("res://scripts/town/settings.gd")
	var st2 = Settings.new(SET_PATH)
	st2.load_file()
	c.check(st2.guide_hints == false, "关掉的开关写进了 settings.json，重新读回来还是关")
	c2.main.settings.guide_hints = true
	st2.guide_hints = true
	st2.save_file()
	var st3 = Settings.new(SET_PATH)
	st3.load_file()
	c.check(st3.guide_hints == true, "再打开：写进去，读回来是开")
	var st4 = Settings.new("user://does_not_exist_%d.json" % OS.get_process_id())
	c.check(st4.guide_hints == true, "没有设置文件：默认是开")
	# 设置面板里有这一行
	var SettingsPanel = load("res://scripts/town/settings_panel.gd")
	var sp = SettingsPanel.new()
	sp.build(c2.main, c2.main.settings)
	var texts: Array = []
	_collect_text(sp, texts)
	c.check(texts.has("新手提示"), "设置面板里有“新手提示”一行")
	sp.free()

	# ---------------- 7b. 日结：按 E 收起 ----------------
	c2.main.settings.guide_hints = true
	g2.active = {}
	g2._phase = ""
	g2._gap = 0.0
	g2.state()["done"].erase("summary_close")
	g2.state()["seen"].erase("summary_closed")
	var summ: Dictionary = c2.town.director.town_finish_day()
	var SummaryPanel = load("res://scripts/town/summary_panel.gd")
	var sum_panel = SummaryPanel.new()
	sum_panel.build(c2.town, summ)
	c2.town._open_modal(sum_panel)
	c.check(await c2.until(_step_on(g2, "summary_close"), 600), "日结弹出：亮出“按 E 收起，进入新的一天”")
	await _key(KEY_E)
	await c2.frames(3)
	c.check((not is_instance_valid(sum_panel) or sum_panel.is_closed()) and c2.town._modal_depth == 0, "按 E 收起日结")
	c.check(await c2.until(func(): return g2.is_done("summary_close"), 600), "收起后这一步完成")

	# ---------------- 8. 操作说明：暂停菜单、F1、标题 ----------------
	c2.town.open_pause()
	await c2.frames(4)
	var menu = null
	for m in c2.town.modal_layer.get_children():
		if m.get_script() != null and str(m.get_script().resource_path).ends_with("pause_menu.gd"):
			menu = m
	c.check(menu != null and menu.help_btn != null, "暂停菜单里有“操作说明”按钮")
	menu.help_btn.pressed.emit()
	await c2.frames(4)
	var hp = HelpPanel.current
	c.check(hp != null and is_instance_valid(hp) and hp.visible, "点“操作说明”：说明页打开")
	c.check(c2.town._modal_depth == 2, "说明页叠在暂停菜单上面")
	var all_text: Array = []
	_collect_text(hp, all_text)
	var joined := "\n".join(all_text)
	c.check(joined.find("WASD") >= 0 and joined.find("Shift") >= 0 and joined.find("Esc") >= 0, "说明页里有按键说明")
	c.check(joined.find("米行") >= 0 and joined.find("保公所") >= 0, "说明页里写了去哪儿买米、交账")
	c.check(joined.find("好感") < 0 and joined.find("概率") < 0 and joined.find("底价") < 0, "说明页里没有隐藏数值")
	hp._pick(1)
	await c2.frames(2)
	var rules_text: Array = []
	_collect_text(hp, rules_text)
	c.check("\n".join(rules_text).find("规矩") >= 0, "第二页“规矩”打得开")
	await _key(KEY_ESCAPE)
	await c2.frames(3)
	c.check(not is_instance_valid(hp) or hp.is_closed(), "Esc 关掉说明页")
	c.check(c2.town._modal_depth == 1 and menu != null and is_instance_valid(menu) and not menu.is_closed(), "关说明页后，暂停菜单还在")
	await _key(KEY_ESCAPE)
	await c2.frames(3)
	c.check(c2.town._modal_depth == 0, "再按 Esc 才关暂停菜单")
	# F1 在街上直接开；E / Enter 也能关
	await _key(KEY_F1)
	await c2.frames(3)
	c.check(HelpPanel.current != null and is_instance_valid(HelpPanel.current) and not HelpPanel.current.is_closed(), "F1 打开说明页")
	await _key(KEY_E)
	await c2.frames(3)
	c.check(HelpPanel.current == null, "E 关上说明页")
	await _key(KEY_F1)
	await c2.frames(3)
	await _key(KEY_ENTER)
	await c2.frames(3)
	c.check(HelpPanel.current == null and c2.town._modal_depth == 0, "Enter 关上说明页，钟恢复")
	# 标题画面
	c2.main._return_to_title()
	await c2.frames(6)
	c.check(c2.main.title_layer != null, "回到标题")
	var title_btn: Button = null
	for b in _buttons(c2.main.title_layer):
		if (b as Button).text.find("操作说明") >= 0:
			title_btn = b
	c.check(title_btn != null, "标题画面有“操作说明”按钮")
	title_btn.pressed.emit()
	await c2.frames(4)
	c.check(HelpPanel.current != null and is_instance_valid(HelpPanel.current), "标题画面点按钮：说明页打开（没有进游戏也能看）")
	hp = HelpPanel.current
	hp._pick(1)
	var t2: Array = []
	_collect_text(hp, t2)
	c.check("\n".join(t2).find("档案簿") >= 0, "标题画面的“规矩”页说明规矩记在档案簿里")
	await _key(KEY_ENTER)
	await c2.frames(3)
	c.check(HelpPanel.current == null, "标题画面：Enter 关上说明页")
	await _key(KEY_F1)
	await c2.frames(3)
	c.check(HelpPanel.current != null and is_instance_valid(HelpPanel.current), "标题画面：F1 也能开")
	await _key(KEY_ESCAPE)
	await c2.frames(3)
	c.check(HelpPanel.current == null, "标题画面：Esc 关上")

	# 收拾
	for p in [SET_PATH, save_path, save_path + ".tmp"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	await c2.shutdown()
	print("FAILURES: ", failures + c.failures + c2.failures)
	quit(0 if (failures + c.failures + c2.failures) == 0 else 1)

func _buttons(node: Node, out: Array = []) -> Array:
	for ch in node.get_children():
		if ch is Button:
			out.append(ch)
		_buttons(ch, out)
	return out

func _collect_text(node: Node, out: Array) -> void:
	if node is Label:
		out.append((node as Label).text)
	elif node is Button:
		out.append((node as Button).text)
	for ch in node.get_children():
		_collect_text(ch, out)
