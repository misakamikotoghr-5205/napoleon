# 规矩：每条规矩在它的时机由世界里的人/物说出口，记进档案簿“规矩”一栏；不重复；文字里没有隐藏数值；关着的门说得出为什么。
# godot --headless -s res://scripts/tests/town_ui_rules.gd
extends SceneTree

const Common = preload("res://scripts/tests/town_ui_common.gd")
const Rules = preload("res://scripts/town/rules.gd")
const Guide = preload("res://scripts/town/guide.gd")
const ShopOnly = preload("res://scripts/town/shop_only.gd")      # [shop-only] 守铺版改写的规矩页、引导话

var c
var SET_PATH: String = "user://town_ui_rules_settings_%d.json" % OS.get_process_id()

var failures: int = 0

func _chk(cond: bool, msg: String) -> void:
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

func _step_on(g, id: String) -> Callable:
	return func(): return str(g.active.get("id", "")) == id and g._phase == "in"

func _boot() -> void:
	c = Common.new(self)
	await c.make_main()
	c.main.settings.path = SET_PATH
	c.town.set_fast(true)
	c.town.auto_dismiss = false
	c.town.new_game(7, "常年", true)
	await c.town.day_started
	c.town.seconds_per_minute = 100000.0

# 清场：让引导空着、没有客人等着、不在柜台上（站着不动半秒会自己开场）
func _calm(g, ids: Array = []) -> void:
	for vid in c.town.visitors.present.keys():
		c.town.visitors.abandon(str(vid))
	for id in ids:
		g.mark_done(str(id))
	g.active = {}
	g._phase = ""
	g._gap = 0.0
	g._idle_t = 99.0
	g._eval_t = 0.0

func _toast_texts() -> Array:
	var out: Array = []
	for ch in c.town.overlay._toast_box.get_children():
		if ch is Label:
			out.append((ch as Label).text)
	for row in c.town.overlay._toast_queue:
		out.append(str(row.get("text", "")))
	return out

func _any_has(rows: Array, frag: String) -> bool:
	for r in rows:
		if str(r).find(frag) >= 0:
			return true
	return false

func _lint(text: String, what: String) -> void:
	var hits: Array = Rules.hidden_number_hits(text)
	_chk(hits.is_empty(), "%s 里没有隐藏数值（%s）" % [what, str(hits)])

func _run() -> void:
	# ---------------- 0. 数据体检 ----------------
	var rd: Dictionary = Rules.data()
	var od: Dictionary = Guide.data()
	_chk(not rd.is_empty() and not od.is_empty(), "rules.json 和 onboarding.json 都读得到")
	var page_defs: Dictionary = Rules.page_defs()
	for id in Rules.tab_ids():
		_chk(page_defs.has(id) or id == "curfew", "规矩栏的页 %s 有定义（curfew 留给宵禁那边）" % id)
	for id in page_defs:
		var pg: Dictionary = page_defs[id]
		_chk(str(pg.get("title", "")) != "" and (str(pg.get("body", "")) != "" or str(pg.get("dynamic", "")) != ""), "规矩页 %s 有标题和正文" % id)
		_lint(str(pg.get("title", "")) + str(pg.get("body", "")) + str(pg.get("toast", "")), "规矩页 %s" % id)
		_chk(Rules.is_rule_page(id), "规矩页 %s 在“规矩”一栏里" % id)
	var steps: Array = Guide.expand_steps(od.get("steps", []))
	var ids_seen: Dictionary = {}
	for s in steps:
		var sid := str(s.get("id", ""))
		_chk(sid != "" and not ids_seen.has(sid), "步骤 id 唯一：" + sid)
		ids_seen[sid] = true
		if str(s.get("rule", "")) != "":
			_chk(page_defs.has(str(s["rule"])), "步骤 %s 引用的规矩页 %s 存在" % [sid, str(s["rule"])])
		_lint(str(s.get("text", "")) + str(s.get("neutral", "")), "步骤 %s 的文字" % sid)
	for row in od.get("shop_lines", []):
		_chk(page_defs.has(str(row.get("rule", ""))), "掌柜的话 %s 引用的规矩页存在" % str(row.get("id", "")))
		_lint("".join(row.get("lines", [])), "掌柜的话 " + str(row.get("id", "")))
	_lint(str(od.get("notice_quote", {}).get("text", "")), "告示里哥哥的话")
	for bid in rd.get("locked_text", {}):
		for st in rd["locked_text"][bid]:
			if typeof(rd["locked_text"][bid][st]) == TYPE_STRING:
				_lint(str(rd["locked_text"][bid][st]), "关门的说法 %s/%s" % [bid, st])
	_lint(JSON.stringify(rd.get("help", {})), "操作说明")
	# [shop-only] 守铺版改写的字（shop_only.json 的 rule_text / step_text、rules.json 的 help_shop_only）也不许写隐藏的数
	_lint(JSON.stringify(rd.get("help_shop_only", {})), "操作说明（只守铺子）")
	var so: Dictionary = ShopOnly.config()
	for id in so.get("rule_text", {}):
		_chk(page_defs.has(str(id)), "只守铺子改写的规矩页 %s 在 rules.json 里有" % str(id))
		_lint(JSON.stringify(so["rule_text"][id]), "只守铺子改写的规矩页 %s" % str(id))
	for id in so.get("step_text", {}):
		_chk(ids_seen.has(str(id)), "只守铺子改写的引导步骤 %s 在 onboarding.json 里有" % str(id))
		_lint(JSON.stringify(so["step_text"][id]), "只守铺子改写的引导步骤 %s" % str(id))
	var night_ids: Array = []
	for a in DB.get_db().night.get("actions", []):
		night_ids.append(str(a.get("id", "")))
	for id in so.get("night_desc", {}):
		_chk(night_ids.has(str(id)), "只守铺子改写的夜里的事 %s 在 night.json 里有" % str(id))
		_lint(str(so["night_desc"][id]), "只守铺子改写的夜里的事 %s" % str(id))
	for key in ["WASD", "Shift", "E", "Esc"]:
		var found := false
		for kd in od.get("key_strip", {}).get("keys", []):
			if str(kd.get("key", "")) == key:
				found = true
		_chk(found, "按键条里有 " + key)

	# ---------------- 1. 第一天早晨：告示里哥哥交代“家用账” ----------------
	await _boot()
	var town = c.town
	var g = town.guide
	var world = town.world
	_chk(world.pages.has("rule_home"), "第一天告示一打开，哥哥那句“每天早上都看一眼”出来了，家用账记进档案簿")
	var notice = town._open_modals.back() if not town._open_modals.is_empty() else null
	var texts: Array = []
	if notice != null:
		_collect_text(notice, texts)
	_chk(_any_has(texts, "每天早上都看一眼"), "这句话写在告示上（物件旁边），署名哥哥")
	_chk(not _any_has(_toast_texts(), "家用账"), "告示还开着：弹窗不盖在告示底下")
	var map = town.world_view.map
	await _key(KEY_E)
	town.player.teleport(map.nearest_free(Vector2(240, 140)))
	await c.frames(3)
	_chk(await c.until(func(): return _any_has(_toast_texts(), "档案簿 · 规矩：家用账 记下了"), 600), "告示收起后弹“档案簿 · 规矩：家用账 记下了”")
	# 档案簿里“规矩”一栏
	town.open_panel("notebook")
	await c.frames(2)
	c.main.book._set_tab("规矩")
	await c.frames(2)
	_chk(c.main.book.body.text.find("家用账") >= 0 and c.main.book.body.text.find("米缸") >= 0, "档案簿“规矩”一栏里读得到家用账")
	c.main.book._set_tab("知识")
	await c.frames(2)
	_chk(c.main.book.body.text.find("家用账") < 0, "“知识”一栏里不再混着规矩页")
	c.main.book._close()
	await c.frames(2)

	# ---------------- 2. 哥哥在头两天说：当铺规矩 / 体力 / 睡觉存档 / 满当货 ----------------
	g.emit_event("moved")
	_calm(g, ["brother_calls", "move_keys", "interact_e", "esc_menu", "hud_buttons", "go_counter", "notice_close"])
	town.player.teleport(map.nearest_free(Vector2(240, 140)))
	_chk(await c.until(_step_on(g, "rule_pawn"), 900), "第一天早晨：哥哥交代当铺规矩")
	_chk(world.pages.has("rule_pawn"), "当铺规矩记进了档案簿")
	_chk(str(g._active_speaker.get("label", "")).find("哥哥") >= 0, "这句话是哥哥说的（他的气泡）")
	_chk(str(g._btxt.text).find("三十天") >= 0 and str(g._btxt.text).find("月息三分") >= 0, "文字：当期三十天、月息三分")
	var n_pages: int = world.pages.size()
	g._finish(true, "done")
	await c.frames(2)
	_calm(g)
	# 货架：满当货
	g.emit_event("interacted:看货架")
	_chk(await c.until(_step_on(g, "rule_sell_brother"), 900), "看过货架后，哥哥说满当货怎么卖")
	_chk(world.pages.has("rule_sell"), "卖满当货记进了档案簿")
	g._finish(true, "done")
	await c.frames(2)
	# 出门：第一天哥哥说“出门要花时间”
	g.emit_event("interacted")
	town.skip_to(430)
	_calm(g)
	town.player.teleport(map.nearest_free(Vector2(240, 140)))
	_chk(await c.until(_step_on(g, "leave_shop"), 900), "第一天：哥哥说出门要走到门口按 E、选去处")
	_chk(world.pages.has("rule_leave"), "“出门”规矩记进了档案簿")
	_chk(str(g._active_speaker.get("label", "")).find("哥哥") >= 0, "这句话是哥哥的气泡")
	_chk(str(g._btxt.text).find("按 E") >= 0 and str(g._btxt.text).find("没人守柜台") >= 0, "文字：走到门口按 E；出门就没人守柜台")
	g._finish(true, "done")
	await c.frames(2)
	# 傍晚：体力、睡觉存档
	town.skip_to(1060)
	_calm(g)
	town.player.teleport(map.nearest_free(Vector2(240, 140)))
	_chk(await c.until(_step_on(g, "rule_stamina"), 900), "傍晚：哥哥说体力")
	_chk(world.pages.has("rule_stamina"), "体力记进了档案簿")
	_chk(str(g.active.get("anchor", {}).get("id", "")) == "stamina", "标记指着右上角的体力条")
	g._finish(true, "done")
	await c.frames(2)
	town.skip_to(1100)
	_calm(g)
	town.player.teleport(map.nearest_free(Vector2(240, 140)))
	_chk(await c.until(_step_on(g, "bed_time"), 900), "天黑了：床边亮出“按 E 睡觉”")
	_chk(world.pages.has("rule_save"), "睡觉自动存档、白天可手动存档：存档规矩记进了档案簿")
	_chk(str(g._btxt.text).find("自动存档") >= 0, "文字提到自动存档")
	# 不重复
	var count_before: int = world.pages.size()
	for id in ["rule_home", "rule_pawn", "rule_sell", "rule_stamina", "rule_save", "rule_leave"]:
		_chk(not Rules.tell(world, id), "规矩 %s 已经记过：再说一遍不会重复记" % id)
	_chk(world.pages.size() == count_before, "档案簿页数没变")
	var uniq: Dictionary = {}
	for p in world.pages:
		uniq[p] = true
	_chk(uniq.size() == world.pages.size(), "档案簿里没有重复的页")
	_chk(n_pages <= world.pages.size(), "（页只增不减）")
	g._finish(true, "done")
	await c.frames(2)
	# 马保长上门（第一次收费）：他站在铺里时当面说一句
	_chk(not world.pages.has("rule_levy"), "还没人说过摊派可以讲价")
	var Walker = load("res://scripts/town/walker.gd")
	var TownData = load("res://scripts/town/town_data.gd")
	var mw = Walker.new()
	mw.setup("ma", TownData.char_sheet_id("ma"), TownData.char_texture(TownData.char_sheet_id("ma")))
	town.world_view.add_actor(mw)
	mw.position = map.customer_spots[0]
	town.visitors.present["story_ma_test"] = {"visit": {"id": "story_ma_test", "who": "ma", "kind": "event"}, "walker": mw, "expiry": 99999, "order": 99}
	g.active = {}
	g._phase = ""
	g._gap = 0.0
	g._idle_t = 99.0
	_chk(await c.until(_step_on(g, "rule_levy_ma"), 900), "马保长站在铺里：他自己说摊派可以讲价")
	_chk(str(g._active_speaker.get("label", "")).find("马") >= 0, "气泡是马保长的（从他站的地方冒出来）")
	_chk(world.pages.has("rule_levy"), "摊派讲价记进了档案簿")
	g._finish(true, "done")
	town.visitors.present.erase("story_ma_test")
	mw.queue_free()
	await c.frames(3)
	c.main.queue_free()
	await c.frames(3)

	# ---------------- 3. 关着的门、周妈、马保长、当票背面、验货 ----------------
	await _boot()
	town = c.town
	g = town.guide
	world = town.world
	map = town.world_view.map
	var quiet: Array = ["notice_close", "brother_calls", "move_keys", "interact_e", "esc_menu", "hud_buttons", "go_counter", "customer_arrives", "customer_outside", "rule_pawn", "rule_sell_brother", "rule_stamina", "bed_time"]
	await _key(KEY_E)
	town.player.teleport(map.nearest_free(Vector2(240, 140)))
	await c.frames(3)
	town.skip_to(500)
	_calm(g, quiet)
	# 出门的规矩：玩家抢在哥哥开口前就出门了：悄悄记下（不会漏）
	_chk(not world.pages.has("rule_leave"), "还没出过门：没有“出门”页")
	g.on_travel_opened()
	await c.frames(30)
	_chk(world.pages.has("rule_leave"), "没等哥哥说就出了门：“出门”规矩照样记下")
	_chk(_any_has(_toast_texts(), "规矩：出门 记下了"), "弹出“档案簿 · 规矩：出门 记下了”")
	# 7. 关着的店：说得出为什么
	town.open_shop("pharmacy")
	await c.frames(3)
	_chk(_any_has(_toast_texts(), "陈先生这两天不在铺里"), "第一天济生堂的门：门缝里夹着字条，说陈先生不在")
	town.open_shop("post")
	await c.frames(3)
	_chk(_any_has(_toast_texts(), "筹备中"), "邮电代办所：窗上贴着“筹备中”")
	_chk(town._locked_text("police").find("封条") >= 0, "警察所：门上贴着封条")
	_chk(town._locked_text("sunfu").find("帖子") >= 0, "孙府：没有帖子不让进")
	_chk(town._locked_text("dock").find("船家") >= 0, "码头：只有船家和过路的人")
	for bid in ["pharmacy", "baogong", "post", "market", "police", "sunfu"]:
		var generic: String = "%s还没开门。" % town.building_name(bid)
		_chk(town._locked_text(bid) != generic and town._locked_text(bid) != "", "%s 锁着时的说法不是干巴巴的“还没开门”：%s" % [bid, town._locked_text(bid)])
	# 周妈：第一次进茶馆说卖满当货
	_chk(world.town.building_state("teahouse") == "open", "上午茶馆开着")
	await town.open_shop("teahouse")
	await c.frames(3)
	_chk(world.pages.has("rule_sell"), "第一次进茶馆：周妈说满当货怎么卖，记进档案簿")
	_chk(town.shop_view.pending_lines() >= 1, "周妈的话排在她的招呼后面（掌柜的气泡里，不是系统弹窗）")
	_chk(g.is_done("tea_sell"), "这一段记为说过")
	_chk(await c.until(func(): return world.pages.has("rule_shops"), 600), "进店特写：这家店能办什么说了一遍，镇上的店记进档案簿")
	town.shop_view.close_shop()
	await c.until(func(): return town.mode == "town", 600)
	await town.open_shop("teahouse")
	await c.frames(3)
	_chk(town.shop_view.pending_lines() == 0, "第二次进茶馆：不重说")
	town.shop_view.close_shop()
	await c.until(func(): return town.mode == "town", 600)
	# 马保长：第一次进保公所
	world.town.s["unlocked"]["baogong"] = true
	town.skip_to(600)
	_calm(g, quiet)
	await town.open_shop("baogong")
	await c.frames(3)
	_chk(world.pages.has("rule_levy"), "第一次进保公所：马保长说摊派可以讲价，记进档案簿")
	_chk(town.shop_view.pending_lines() >= 1, "是马保长在店里说的")
	town.shop_view.close_shop()
	await c.until(func(): return town.mode == "town", 600)
	# 当票背面
	_calm(g, quiet)
	town.player.teleport(map.nearest_free(Vector2(240, 140)))
	var tid: String = world.ledger.open_pawn("zhouma", [], 0, world.day, 30, "测试当票", false)
	await c.frames(2)
	_chk(not tid.is_empty(), "写出一张新当票")
	_chk(await c.until(_step_on(g, "ticket_back"), 900), "新当票写出来：亮出“当票背面”那一行")
	_chk(str(g._btxt.text).find("当期三十天") >= 0 and str(g._btxt.text).find("五天") >= 0, "文字：当期三十天，月息三分，过期五天不赎")
	_chk(world.pages.has("rule_pawn"), "当票背面也记下当铺规矩（哥哥没来得及说也不会漏）")
	g._finish(true, "done")
	await c.frames(2)
	# 验货：第一次点开放大镜
	_calm(g, quiet)
	g.emit_event("inspect_opened")
	await c.frames(30)
	_chk(world.pages.has("rule_inspect"), "第一次验货（点开放大镜）：验货规矩记进档案簿")
	# 晚上：关门的店也说得出为什么
	# 20:30 在当铺里会触发宵禁那边“哥哥提醒别上街”的对白；这里只测关门说法，先当他已经说过
	if town.curfew != null:
		(town.curfew.state()["told_by"] as Array).append("brother")
	town.skip_to(1230)
	_calm(g, quiet)
	town.open_shop("ricehall")
	await c.frames(3)
	_chk(_any_has(_toast_texts(), "米行的门板上着"), "晚上米行关着：门板上着，伙计在盘米")
	town.open_shop("teahouse")
	await c.frames(3)
	_chk(_any_has(_toast_texts(), "茶馆上了门板"), "晚上茶馆关着：上了门板")
	# 镇上的店：随着店开门会变长
	var body0: String = Rules.page(world, "rule_shops")["body"]
	_chk(body0.find("茶馆") >= 0 and body0.find("米行") >= 0 and body0.find("买米") >= 0, "“镇上的店”一页：茶馆、米行各自能办什么")
	world.town.s["unlocked"]["pharmacy"] = true
	var body1: String = Rules.page(world, "rule_shops")["body"]
	_chk(body1.find("济生堂") >= 0 and body1.find("买药") >= 0, "济生堂开门后，这一页多了济生堂")
	_chk(body0.find("好感") < 0, "（镇上的店页没有隐藏数值）")
	_lint(body1, "镇上的店页")
	# 档案簿“规矩”一栏分页
	var ids: Array = Rules.page_ids(world, true)
	_chk(ids.size() >= 6, "规矩一栏里已有 %d 页" % ids.size())
	_chk(Rules.page_ids(world, false).size() + ids.size() == world.pages.size(), "规矩页和知识页分得开")
	# 开关关掉：不再记
	c.main.settings.guide_hints = false
	await c.frames(3)
	var pages_off: int = world.pages.size()
	g.emit_event("moved")
	await c.frames(30)
	_chk(world.pages.size() == pages_off, "新手提示关着：不再往档案簿里添页")
	for p in [SET_PATH]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	await c.shutdown()
	print("FAILURES: ", failures)
	quit(0 if failures == 0 else 1)

func _collect_text(node: Node, out: Array) -> void:
	if node is Label:
		out.append((node as Label).text)
	elif node is Button:
		out.append((node as Button).text)
	for ch in node.get_children():
		_collect_text(ch, out)
