# [shop-only] 小镇界面：过路客人与门口吆喝（v0.4.2，设计 docs/town/DESIGN_walkin.md；引擎 scripts/core/walkin.gd），在真的 Main 上跑。
#   第一天：哥哥没交代完以前吆喝不成；哥哥交代“人不来，就到门口吆喝一声”；门口的提示是「门口吆喝」；走进门口那一格只说一句守铺的话、
#           不开小窗；按 E 开小窗（钟停），E / Esc 关上；第一天吆喝叫得来人（花钟点、叫来的人进门），可过路的人不自己进门
#   规矩页（卖满当货、柜台规矩）、操作说明、哥哥看货架后那句话都按只守铺子改写，出门版原样，没有隐藏的数
#   第三天：店里空了一阵（约 60 游戏分钟），门口亮一下“没人上门，就到门口吆喝一声”
#           吆喝卖货：花钟点，被叫的人 call_delay 内进门、站到等候点、能招呼；他在柜台上说要哪件、能问两句、谈价、成交：
#           货离架、钱进匣、记账、提示“卖出：…，进账 X 蚨”；柜台上写他的原型名（不是 walkin:… 这串 ID）；货架面板只看（没有「卖掉」、不写市价）；
#           档案簿“人物”不给过路客人一人一张，末尾合成一行；整理库房挑货时不写市价（买来的假货不露底）
#           一整天过路客人自己进门，店里站满了不进门；日结把没等到的过路客人合成一行
#   第四天：断客（街坊绕着走）——吆喝没人应、一位过路客人也没有；架上的货过路的人都看不上——“吆喝卖货”灰着、写“过路的看不上”；
#           架上没货——“吆喝卖货”灰着、写“架上没货”
# godot --headless -s res://scripts/tests/town_ui_walkin.gd
extends SceneTree

const Common = preload("res://scripts/tests/town_ui_common.gd")
const Walkin = preload("res://scripts/core/walkin.gd")
const WalkinCallPanel = preload("res://scripts/town/walkin_call_panel.gd")
const SummaryPanel = preload("res://scripts/town/summary_panel.gd")
const HelpPanel = preload("res://scripts/town/help_panel.gd")
const Rules = preload("res://scripts/town/rules.gd")
const ShopOnly = preload("res://scripts/town/shop_only.gd")
const Guide = preload("res://scripts/town/guide.gd")

# 出门版的世界（只有 flags）：看规矩页在出门版里是不是原样
class FakeWorld:
	var flags: Dictionary = {}

var c
var town
var main
var cfg: Dictionary = {}

func _initialize() -> void:
	_run()

# ---------------------------------------------------------------- 小工具
func _key(code: int) -> void:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.physical_keycode = code
	ev.pressed = true
	root.push_input(ev)
	await process_frame
	var up := InputEventKey.new()
	up.keycode = code
	up.physical_keycode = code
	up.pressed = false
	root.push_input(up)
	await process_frame

func _d():
	return town.director

func _w():
	return town.director.walkin()

# 眼下最上面那个门口吆喝的小窗（没有就是 null）
func _call_panel():
	for i in range(town._open_modals.size() - 1, -1, -1):
		var m = town._open_modals[i]
		if is_instance_valid(m) and not m.is_closed() and m.get_script() == WalkinCallPanel:
			return m
	return null

func _toasts() -> Array:
	var out: Array = []
	for ch in town.overlay._toast_box.get_children():
		if ch is Label:
			out.append((ch as Label).text)
	for row in town.overlay._toast_queue:
		out.append(str(row.get("text", "")))
	return out

func _clear_toasts() -> void:
	town.overlay._toast_queue.clear()
	for ch in town.overlay._toast_box.get_children():
		town.overlay._toast_box.remove_child(ch)
		ch.queue_free()

func _bubble_text() -> String:
	if not town.overlay.is_speaking():
		return ""
	return str(town.overlay._bubble_lbl.text)

func _collect(node, texts: Array, buttons: Array) -> void:
	if node is Button:
		buttons.append(node)
		texts.append(str((node as Button).text))
	elif node is Label:
		texts.append(str((node as Label).text))
	for ch in node.get_children():
		_collect(ch, texts, buttons)

func _texts_of(node) -> Array:
	var texts: Array = []
	_collect(node, texts, [])
	return texts

func _any_has(rows: Array, frag: String) -> bool:
	for r in rows:
		if str(r).find(frag) >= 0:
			return true
	return false

func _to_door() -> void:
	var door: Dictionary = town.world_view.map.door_to_map("town")
	town.player.teleport(door["front"])
	await c.frames(3)

func _walkin_present() -> Array:
	var out: Array = []
	for id in town.visitors.present:
		if Walkin.is_walkin(town.visitors.present[id]["visit"]):
			out.append(str(id))
	return out

# 夜里和别的剧情交给 autoplayer；要看的那一幕由本测试自己回应（先让 autoplayer 退场，演完再请回来）
func _manual(on: bool) -> void:
	var ap = c.ap
	if ap == null:
		return
	var d = town.director
	if on and d.beat.is_connected(ap._on_beat):
		d.beat.disconnect(ap._on_beat)
	elif not on and not d.beat.is_connected(ap._on_beat):
		d.beat.connect(ap._on_beat, CONNECT_DEFERRED)

func _next_day() -> void:
	var before: int = town.world.day
	town.skip_to(1100)
	await town.goto("bed")
	var seen := [0]
	var cb := func(_d): seen[0] += 1
	town.day_started.connect(cb)
	var began: bool = town.sleep()
	c.check(began, "第 %d 天晚上睡下了" % before)
	await c.until(func(): return seen[0] > 0, 900)
	town.day_started.disconnect(cb)
	await c.until_idle()
	c.check(town.world.day == before + 1, "睡一觉，第 %d 天" % town.world.day)

# 第一天哥哥在柜台前等着：接他，把他说的话都记下来
func _brother_talk() -> Array:
	var texts: Array = []
	var ok: bool = await c.until(func(): return not town.visitors.next_ready().is_empty(), 1500)
	c.check(ok and str(town.visitors.next_ready().get("who", "")) == "brother", "第一天早上哥哥在铺里等着")
	if not ok:
		return texts
	_manual(true)
	town.start_counter(town.visitors.next_ready())
	var last_cur = null
	var guard := 0
	while guard < 4000 and town.mode == "counter":
		guard += 1
		await process_frame
		var t: String = main.cur_type
		if t == "" or main.cur == last_cur:
			continue
		last_cur = main.cur
		if t in ["say", "narr"]:
			texts.append(str(main.cur.get("text", "")))
			main._on_dialogue_advanced()
		else:
			main._respond({})
	_manual(false)
	await c.until_idle()
	return texts

# 柜台上头一回拨算盘时，界面上写的客人名字：侧栏顶上那行、柜台提示的说话人、柜台上指着他的悬停提示
func _counter_names(out: Dictionary) -> void:
	out["npc_lbl"] = str(main.sidebar.npc_lbl.text) if main.sidebar != null else ""
	out["tip_name"] = str(main.dialogue.name_lbl.text)
	out["hover"] = str(main.view._tip("customer"))

# 柜台上接买主：说的话都记下；先把能问的两句问了，再拨算盘——头一回报在他出的价和最多肯出的价中间，他还价就按他的价卖
func _drive_buyer(visit: Dictionary) -> Dictionary:
	var out := {"lines": [], "counters": 0, "extras": [], "labels": [], "used": [], "offers": [], "mode": "", "items": 0}
	_manual(true)
	town.start_counter(visit)
	var last_cur = null
	var guard := 0
	while guard < 6000:
		guard += 1
		await process_frame
		if town.mode != "counter":
			break
		var t: String = main.cur_type
		if t == "" or main.cur == last_cur:
			continue
		last_cur = main.cur
		match t:
			"say", "narr":
				out["lines"].append(str(main.cur.get("text", "")))
				main._on_dialogue_advanced()
			"counter":
				out["counters"] = int(out["counters"]) + 1
				var s = main.cur["session"]
				if int(out["counters"]) == 1:
					out["mode"] = str(s.mode)
					out["items"] = s.item_ids.size()
					out["ask0"] = int(s.ask)
					out["abacus"] = int(main.sidebar.abacus_value) if main.sidebar != null else -1
					for e in main.cur.get("extras", []):
						out["extras"].append(str(e["id"]))
						out["labels"].append(str(e["label"]))
					_counter_names(out)
				var left := ""
				for e in main.cur.get("extras", []):
					if not out["used"].has(str(e["id"])):
						left = str(e["id"])
						break
				if left != "":
					out["used"].append(left)
					main._respond({"action": "extra", "id": left})
					continue
				var v: int = s.ask + int(float(s.floor_v - s.ask) * 0.5) if out["offers"].is_empty() else s.ask
				out["offers"].append(v)
				main._respond({"action": "offer", "value": v})
			"choice":
				var opts: Array = main.cur.get("options", [])
				main._respond({"id": str(opts[0]["id"])} if not opts.is_empty() else {})
			_:
				main._respond({})
	_manual(false)
	await c.until_idle()
	return out

# ---------------------------------------------------------------- 主流程
func _run() -> void:
	cfg = Walkin.config()
	c = Common.new(self)
	c.shop_only = true
	await c.boot(7, true, true)
	town = c.town
	main = c.main
	main.dialogue.instant = true
	town.seconds_per_minute = 100000.0      # 钟只听测试的（skip_to / 吆喝 / 接待）
	c.check(_d().shop_only() and _w().active(), "本局是只守铺子，过路客人开着")
	await _part_day1()
	_part_text()
	await _next_day()
	await _next_day()
	await _part_call_and_buy()
	await _part_whole_day()
	await _part_boycott_and_empty()
	var fails: int = c.failures
	print("RESULT: ", "OK" if fails == 0 else "FAILED (%d)" % fails)
	await c.shutdown()
	quit(0 if fails == 0 else 1)

# ---------- 第一天：哥哥的话、门口的提示、走进门口、按 E、E / Esc 关、第一天吆喝没人应 ----------
func _part_day1() -> void:
	var shut: Dictionary = _w().call_check("pawn")
	c.check(str(shut.get("error", "")) == "not_open" and str(_w().st()["quiet"]) == "calls_only", "第一天哥哥还没交代完：吆喝不成（%s）" % str(shut.get("line", "")))
	var bro: Array = await _brother_talk()
	var said: String = "\n".join(bro)
	c.check(said.contains("人不来，就到门口吆喝一声。"), "第一天哥哥交代：人不来，就到门口吆喝一声")
	c.check(said.contains("架上的东西别急着出手，等买主进门，在柜台上谈。"), "第一天哥哥交代：架上的东西等买主进门，在柜台上谈")
	c.check(said.contains("守着铺子") and said.contains("胡二"), "保护费那几句照旧")
	var door: Dictionary = town.world_view.map.door_to_map("town")
	await _to_door()
	var near: Dictionary = town._find_near()
	c.check(str(near.get("label", "")) == "门口吆喝" and str(near.get("id", "")) == "door:" + str(door["building"]), "站在门口：提示是「门口吆喝」（%s）" % str(near.get("label", "")))
	c.check(town.overlay.prompt_text() == "【E】 门口吆喝", "头顶的提示写着「【E】 门口吆喝」（%s）" % town.overlay.prompt_text())
	# 往门里走（按住下方向键停在门口那一格）：只说一句守铺的话，不开小窗、不出门
	var m0: int = town.minute
	town.player.use_external = true
	town.player.external_input = Vector2(0, 1)
	await c.until(func(): return town.overlay.is_speaking(), 1500)
	await c.frames(20)
	town.player.use_external = false
	town.player.external_input = Vector2.ZERO
	var line := _bubble_text()
	c.check(town.overlay.is_speaking() and (line == ShopOnly.door_line(0) or line == ShopOnly.door_line(1)), "走进门口那一格：只说一句守铺的话（%s）" % line)
	c.check(_call_panel() == null and town._modal_depth == 0, "走进门口那一格不开吆喝的小窗")
	c.check(town.map_id == "pawnshop" and town.minute == m0, "没出门，也没花时间")
	town.overlay.end_speech()
	await c.frames(30)          # 等门口的锁过去（_door_lock）
	# 按 E：开小窗，钟停
	await _to_door()
	await _key(KEY_E)
	var p = _call_panel()
	c.check(p != null, "门口按 E：打开门口吆喝的小窗")
	if p == null:
		return
	c.check(town.paused and town._modal_depth > 0, "小窗开着，钟停")
	var ptexts: Array = _texts_of(p)
	c.check(_any_has(ptexts, Walkin.line("menu_title")), "小窗的题目：%s" % Walkin.line("menu_title"))
	c.check(p.buttons.has("pawn") and p.buttons.has("buy") and p.buttons.has("cancel") and str(p.buttons["pawn"].text).begins_with("吆喝收当") and str(p.buttons["buy"].text).begins_with("吆喝卖货") and str(p.buttons["cancel"].text).begins_with("算了"), "三项：吆喝收当 / 吆喝卖货 / 算了（%s）" % str(ptexts))
	c.check(not _d()._town_shelf().is_empty() and not p.buttons["buy"].disabled and not p.notes.has("buy"), "架上有货：吆喝卖货可以点")
	await _key(KEY_ESCAPE)
	c.check(_call_panel() == null and town._modal_depth == 0 and not town.is_pause_open(), "Esc 关上小窗（不开暂停菜单）")
	await _key(KEY_E)
	c.check(_call_panel() != null, "再按 E：又开了")
	await _key(KEY_E)
	c.check(_call_panel() == null and town._modal_depth == 0, "小窗开着按 E：关上（算了）")
	c.check(town.minute == m0 and int(_w().st()["calls"]) == 0, "开开关关不花时间、不算吆喝")
	# 第一天吆喝：哥哥交代完了，吆喝叫得来人（街上的人不自己进门，吆喝才进）
	await _key(KEY_E)
	p = _call_panel()
	_clear_toasts()
	if p != null:
		p.choose("pawn")
	await c.frames(2)
	c.check(_call_panel() == null, "选了就关窗")
	c.check(_bubble_text() == Walkin.line("call_pawn") and town.minute == m0 + int(cfg["call_minutes"]) and int(_w().st()["calls"]) == 1, "第一天也吆喝得应：%s（花 %d 分钟）" % [_bubble_text(), town.minute - m0])
	town.overlay.advance_speech()
	var hi: int = m0 + int(cfg["call_delay"][1])
	if town.minute < hi:
		town.skip_to(hi)
	var called: Array = _walkin_present()
	c.check(called.size() == 1 and str(town.visitors.present[called[0]]["visit"].get("called", "")) == "pawn" if called.size() == 1 else false, "第一天吆喝叫来一位过路客人（%s）" % str(called))
	town.skip_to(int(cfg["last_minute"]) + 5)
	await c.frames(2)
	var day1: Array = []
	for v in town.world.town.s["visits"]:
		if Walkin.is_walkin(v):
			day1.append(str(v["id"]))
	var passed := 0
	for slot in _w().st()["slots"]:
		if str(slot["status"]) == "passed":
			passed += 1
	c.check(day1.size() == 1 and passed == _w().st()["slots"].size() - 1, "第一天过路的人不自己进门：只来了吆喝叫的那一位（%s），其余 %d 位走过去了" % [str(day1), passed])

# ---------- 规矩页、操作说明、引导话：只守铺子改写，出门版原样，没有隐藏的数 ----------
func _part_text() -> void:
	var world = town.world
	var out_world := FakeWorld.new()
	for id in ["rule_sell", "rule_counter"]:
		var pg: Dictionary = Rules.page(world, id)
		var over: Dictionary = ShopOnly.rule_text(id)
		var body := str(pg.get("body", ""))
		c.check(not over.is_empty() and body == str(over.get("body", "")), "规矩页 %s：只守铺子用改写的正文" % id)
		c.check(body.contains("门口") and body.contains("吆喝"), "规矩页 %s 写了门口吆喝" % id)
		c.check(not body.contains("集市") and not body.contains("茶馆") and not body.contains("出门办事") and not body.contains("按市面价卖"), "规矩页 %s 不再提集市、茶馆、出门办事、货架上直接卖" % id)
		c.check(Rules.hidden_number_hits(body).is_empty() and not body.contains("市价"), "规矩页 %s 没有隐藏的数" % id)
		c.check(str(Rules.page(out_world, id).get("body", "")) == str(Rules.page_defs()[id]["body"]), "出门版的规矩页 %s 原样" % id)
		c.check(str(pg.get("title", "")) == str(Rules.page_defs()[id]["title"]), "规矩页 %s 的标题不变" % id)
	c.check(str(Rules.page(world, "rule_sell").get("body", "")).contains("柜台上谈"), "卖满当货：架上的货等买主进门，在柜台上谈")
	# 哥哥看过货架后那句话（rule_sell_brother）
	var step: Dictionary = {}
	for s in Guide.expand_steps(Guide.data().get("steps", [])):
		if str(s.get("id", "")) == "rule_sell_brother":
			step = s
	var said: String = town.guide._step_text(step, true)
	c.check(said == str(ShopOnly.step_text("rule_sell_brother").get("text", "")) and said.contains("吆喝") and not said.contains("集上"), "哥哥看过货架后那句话按只守铺子改写：%s" % said)
	c.check(str(step.get("text", "")).contains("集上"), "onboarding.json 里出门版那句原样")
	# F1 操作说明
	c.check(HelpPanel.open_from(main), "F1 操作说明打开了")
	var hp = HelpPanel.current
	var htexts: Array = _texts_of(hp.content) if hp != null else []
	var help_all: String = "\n".join(htexts)
	c.check(help_all.contains("门口吆喝") and help_all.contains("吆喝卖货") and help_all.contains("门口按 E 吆喝"), "操作说明写了门口吆喝（按键、一天怎么过、去哪儿办事）")
	c.check(not help_all.contains("可以只卖一件") and not help_all.contains("门口按 E 只会说一句话") and not help_all.contains("卖给路过的买主"), "操作说明不再说货架上直接卖、门口只说一句话")
	c.check(Rules.hidden_number_hits(help_all).is_empty(), "操作说明没有隐藏的数")
	if hp != null and is_instance_valid(hp):
		hp.close()

# ---------- 第三天：店里空一阵门口亮；吆喝卖货、买主进门、柜台上谈成；货架只看 ----------
func _part_call_and_buy() -> void:
	var d = _d()
	var day: int = town.world.day
	c.check(day == 3 and str(_w().st()["quiet"]) == "" and not _w().st()["slots"].is_empty(), "第 %d 天排了过路客人（%d 位）" % [day, _w().st()["slots"].size()])
	var open := int(cfg["open_minute"])
	var first := int(_w().st()["slots"][0]["minute"])
	c.check(first > open + 60, "（前提）头一位过路客人 %d 分才来，店里能空上一阵" % first)
	# 引导：店里空了约 60 游戏分钟，门口亮一下
	var g = town.guide
	g.allow_autoplay = true
	g.reset_progress()
	g._hard_reset()
	town.player.teleport(town.world_view.map.counter_spot)
	town.skip_to(open + 40)
	await c.frames(2)
	g.evaluate()
	c.check(not g.shown_log.has("walkin_call"), "店里才空了 40 分钟：门口不亮（%s）" % str(g.shown_log))
	g._finish(false, "context")
	g._gap = 0.0
	g.active = {}
	town.skip_to(open + 61)
	await c.frames(2)
	var tries := 0
	while not g.shown_log.has("walkin_call") and tries < 8:
		tries += 1
		g._gap = 0.0
		if not g.active.is_empty() and str(g.active.get("id", "")) != "walkin_call":
			g.active = {}           # 别的步骤占着：让开（这里只看门口这一步）
			g._phase = ""
		g.evaluate()
		await c.frames(2)
	c.check(g.shown_log.has("walkin_call") and town.visitors.count() == 0, "店里空了一个钟头：门口亮了（%s）" % str(g.shown_log))
	var info: Dictionary = g.anchor_info(g.active.get("anchor", {}), true) if not g.active.is_empty() else {}
	var door: Dictionary = town.world_view.map.door_to_map("town")
	c.check(str(info.get("kind", "")) == "rect" and info.get("world", Rect2()) == door["rect"], "亮的是门口那一格")
	c.check(str(g._btxt.text).replace("\n", "") == "没人上门，就到门口吆喝一声。", "气泡：%s" % str(g._btxt.text))
	# 去门口按 E：这一步就算做完了
	var m0: int = town.minute
	await _to_door()
	await _key(KEY_E)
	var p = _call_panel()
	c.check(p != null, "第三天门口按 E 开了小窗")
	g.evaluate()
	c.check(g.is_done("walkin_call"), "门口按过 E：门口那一步做完了，以后不再亮")
	g.allow_autoplay = false
	if p == null:
		return
	# 吆喝卖货（数字键 2）
	var cash0: int = town.world.cash()
	var shelf0: int = d._town_shelf().size()
	c.check(not p.buttons["buy"].disabled, "架上有 %d 件货：吆喝卖货可以点" % shelf0)
	_clear_toasts()
	await _key(KEY_2)
	c.check(_call_panel() == null, "按 2：吆喝卖货，小窗关上")
	var st: Dictionary = _w().st()
	var n := -1
	for i in st["slots"].size():
		if str(st["slots"][i]["called"]) == "buy":
			n = i
	c.check(int(st["calls"]) == 1 and n == 0, "吆喝叫的是今天时刻表上的下一位（第 %d 位）" % n)
	c.check(town.minute == m0 + int(cfg["call_minutes"]), "吆喝花了 %d 分钟（%d → %d）" % [int(cfg["call_minutes"]), m0, town.minute])
	c.check(_bubble_text() == Walkin.line("call_buy"), "自己头顶冒了一句吆喝：%s" % _bubble_text())
	var vid := Walkin.visit_id(day, n)
	var lo: int = m0 + int(cfg["call_delay"][0])
	var hi: int = m0 + int(cfg["call_delay"][1])
	town.overlay.advance_speech()
	if town.minute < hi:
		town.skip_to(hi)
	var visit: Dictionary = {}
	for v in town.world.town.s["visits"]:
		if str(v.get("id", "")) == vid:
			visit = v
	c.check(not visit.is_empty() and int(visit["minute"]) >= lo and int(visit["minute"]) <= hi, "被叫的人 %d–%d 分之间进门（%d）" % [lo, hi, int(visit.get("minute", -1))])
	c.check(str(visit.get("intent", "")) == "buy" and str(visit.get("called", "")) == "buy" and str(visit.get("who", "")).begins_with("walkin:"), "进门的是想买架上货的过路客人（%s）" % str(visit.get("who", "")))
	c.check(town.visitors.present.has(vid), "他在店里等着")
	var stood: bool = await c.until(func(): return town.visitors.walker_of(vid) != null and not town.visitors.walker_of(vid).is_walking(), 900)
	var wk = town.visitors.walker_of(vid)
	c.check(stood and wk != null and wk.position.distance_to(town.visitors.spot_for(town.visitors.present[vid])) < 4.0, "他走到等候点站定了")
	if wk == null:
		return
	town.player.teleport(town.world_view.map.nearest_free(wk.position + Vector2(0, 16)))
	await c.frames(3)
	var near: Dictionary = town._find_near()
	c.check(str(near.get("label", "")).begins_with("招呼"), "站在他身边：提示“%s”" % str(near.get("label", "")))
	# 柜台上谈
	var sess: Dictionary = visit.get("session", {})
	var iid := str(sess.get("_walkin", {}).get("iid", ""))
	var it: Dictionary = town.world.ledger.items.get(iid, {})
	var item_name := str(it.get("name", "?"))
	c.check(iid != "" and str(it.get("location", "")) == "stock", "他要的是架上的「%s」" % item_name)
	_clear_toasts()
	var m1: int = town.minute
	var r: Dictionary = await _drive_buyer(town.visitors.present[vid]["visit"])
	var said: String = "\n".join(r["lines"])
	c.check(r["mode"] == "sell" and int(r["items"]) == 1, "柜台上是卖货（他买），一次只谈这一件")
	# 生成的客人只登记在这一局的 world.db 里：柜台上写的是原型的名字（挑货的、外乡人……），不是 walkin:… 这串 ID
	var arch_name := ""
	for spec in town.world.town.pack.get("strangers", {}).get("archetypes", []):
		if str(spec.get("id", "")) == str(visit.get("archetype", "")):
			arch_name = str(spec.get("name", ""))
	var npc_lbl := str(r.get("npc_lbl", ""))
	var tip_name := str(r.get("tip_name", ""))
	var hover := str(r.get("hover", ""))
	c.check(arch_name != "" and npc_lbl.begins_with(arch_name + " · ") and not npc_lbl.contains("walkin:"), "侧栏顶上写他的原型名「%s」（%s）" % [arch_name, npc_lbl])
	c.check(tip_name == arch_name and hover == arch_name, "柜台提示的说话人、柜台上指着他的提示都是「%s」（%s / %s）" % [arch_name, tip_name, hover])
	c.check(said.contains("架上那件%s" % item_name), "他先说要哪件：%s" % (r["lines"][0] if not r["lines"].is_empty() else ""))
	c.check(r["labels"] == [Walkin.line("use_label"), Walkin.line("look_label")], "能问两句：%s" % str(r["labels"]))
	c.check(int(r.get("abacus", -1)) == int(r.get("ask0", -2)), "算盘先拨到他自己报的价 %d，不拨市价（%d）" % [int(r.get("ask0", -2)), int(r.get("abacus", -1))])
	var answered := 0
	for ex in sess.get("extras", []):
		for stp in ex.get("steps", []):
			if said.contains(str(stp.get("text", "")).substr(0, 6)):
				answered += 1
	c.check(answered == 2 and r["used"].size() == 2, "两句都问了，回答是原型数据里写的（%d）" % answered)
	c.check(int(r["counters"]) >= 2 and r["offers"].size() >= 1, "拨算盘出了价（%s），他还价或点头" % str(r["offers"]))
	var o: Dictionary = town.last_outcome
	c.check(str(o.get("mode", "")) == "sell" and str(o.get("result", "")) == "accept", "谈成了（%s）" % str(o.get("result", "")))
	var price := int(o.get("price", 0))
	var it2: Dictionary = town.world.ledger.items.get(iid, {})
	c.check(str(it2.get("location", "")) == "npc:" + str(visit["who"]) and str(it2.get("owner", "")) == str(visit["who"]), "货归了买主")
	var still := false
	for row in d._town_shelf():
		if str(row["iid"]) == iid:
			still = true
	c.check(not still and d._town_shelf().size() == shelf0 - 1, "货离了架（%d → %d 件）" % [shelf0, d._town_shelf().size()])
	c.check(price > 0 and town.world.cash() == cash0 + price, "钱匣多了 %d 蚨（%d → %d）" % [price, cash0, town.world.cash()])
	c.check(_any_has(_toasts(), Walkin.sold_toast(item_name, price)), "提示：%s（%s）" % [Walkin.sold_toast(item_name, price), str(_toasts())])
	var noted := false
	for note in town.world.notebook:
		if str(note.get("kind", "")) == "账目" and str(note.get("text", "")).contains(item_name) and str(note.get("text", "")).contains("%d蚨" % price):
			noted = true
	c.check(noted, "记了一笔账目")
	c.check(town.minute >= m1 + 10 and not town.visitors.present.has(vid), "接待花了时间，他走了")
	c.check(town.world.ledger.check_invariants().is_empty(), "账本不变量没破")
	# 货架面板：只看
	town.open_shelf()
	var shelf_panel = town._open_modals.back() if not town._open_modals.is_empty() else null
	var texts: Array = []
	var buttons: Array = []
	if shelf_panel != null:
		_collect(shelf_panel, texts, buttons)
	var btn_texts: Array = buttons.map(func(b): return str(b.text))
	c.check(shelf_panel != null and not btn_texts.has("卖掉") and btn_texts.size() == 1, "货架面板没有「卖掉」，只有合上（%s）" % str(btn_texts))
	c.check(not _any_has(texts, "市价") and _any_has(texts, _w().shelf_text("hint")), "货架面板不写市价，写着：%s" % _w().shelf_text("hint"))
	c.check(not _any_has(texts, item_name), "卖掉的那件不在架上了")
	if shelf_panel != null and is_instance_valid(shelf_panel):
		shelf_panel.close()
	await c.frames(2)
	# 档案簿“人物”：没名没姓的过路客人不一人一张（不露 walkin:… / stranger:…），末尾合成一行
	main.book.open("notebook", town.world)
	main.book.tab = "人物"
	main.book._render()
	var people := str(main.book.body.text)
	main.book.visible = false
	c.check(not people.contains("walkin:") and not people.contains("stranger:") and not people.contains("挑货的（挑货的）") and people.contains("过路客人：接待过"), "档案簿人物：过路客人合成一行（%s）" % people.right(40).replace("\n", " "))
	c.check(people.contains("[b]%s[/b]" % town.world.db.npc_label("brother")), "档案簿人物：有名有姓的人照列")
	# 整理库房挑货（夜里的 pick_item）：只守铺子不写市价、不写加成——架上一件买来的假货在这里不露底
	var shelf_now: Array = d._town_shelf()
	if not shelf_now.is_empty():
		var fid := str(shelf_now[0]["iid"])
		var fake: Dictionary = town.world.ledger.items[fid]
		var keep := {"fake": fake.get("fake", false), "market": fake.get("market", 0), "cost": fake.get("cost", 0), "tidy_bonus": fake.get("tidy_bonus", 0.0)}
		fake["fake"] = true
		fake["market"] = 6
		fake["cost"] = 80
		fake["tidy_bonus"] = 0.05
		var opts: Array = main._options_for({"type": "pick_item", "iids": [fid]})
		var label := str(opts[0]["label"]) if not opts.is_empty() else ""
		c.check(label == "%s（当初收价 80 蚨，整理过）" % str(fake["name"]), "整理库房挑货：写自己账上的数，不写市价、不写加成（%s）" % label)
		for k in keep:
			fake[k] = keep[k]

# ---------- 第三天剩下的钟点：过路客人自己进门，店里站满了不进门；日结合成一行 ----------
func _part_whole_day() -> void:
	var cap := int(cfg["max_waiting"])
	var seen: Dictionary = {}
	var own := 0
	var cap_ok := true
	var worst := ""
	for id in _walkin_present():
		seen[id] = true
	var m: int = town.minute
	while m < int(cfg["call_until"]):
		var before: int = town.visitors.waiting()
		town.skip_to(m + 1)
		m = town.minute
		var fresh := 0
		for id in _walkin_present():
			if not seen.has(id):
				seen[id] = true
				fresh += 1
				if str(town.visitors.present[id]["visit"].get("called", "")) == "":
					own += 1
		if fresh > 0 and before + fresh > cap:
			cap_ok = false
			worst = "%d 分：原来站着 %d 位，又进来 %d 位" % [m, before, fresh]
		if m % 30 == 0:
			await c.frames(1)
	c.check(own >= 2, "没人吆喝，过路客人也一位一位自己进门（%d 位）" % own)
	c.check(cap_ok, "店里站着 %d 位时过路的不进门：%s" % [cap, worst if worst != "" else "一直没超过"])
	var skipped := 0
	for slot in _w().st()["slots"]:
		if str(slot["status"]) == "skipped":
			skipped += 1
	print("第三天：自己进门 %d 位，门口探头就走 %d 位" % [own, skipped])
	_w().st()      # 存在导演账上
	town.director.protect().st()["boycott_day"] = town.world.day + 1      # 明天断客（街坊绕着走），下一段看
	await _next_day()
	var sm: Dictionary = town.last_summary
	var missed_walkins := 0
	var missed_others := 0
	for v in sm.get("missed", []):
		if Walkin.is_walkin(v):
			missed_walkins += 1
		else:
			missed_others += 1
	c.check(missed_walkins > 0, "日结：有 %d 位过路的没等到" % missed_walkins)
	var p = SummaryPanel.new()
	p.build(town, sm)
	var texts: Array = _texts_of(p)
	p.free()
	c.check(texts.has(Walkin.summary_missed_line(missed_walkins)), "日结合成一行：%s" % Walkin.summary_missed_line(missed_walkins))
	var listed := 0
	for t in texts:
		if str(t).begins_with("没等到您就走了："):
			listed = str(t).trim_prefix("没等到您就走了：").split("、").size()
	c.check(listed == missed_others, "“没等到您就走了”只列有名有姓的 %d 位（%d）" % [missed_others, listed])

# ---------- 第四天：断客吆喝没人应；架上没货“吆喝卖货”灰着 ----------
func _part_boycott_and_empty() -> void:
	var day: int = town.world.day
	c.check(str(_w().st()["quiet"]) == "boycott" and _w().st()["slots"].is_empty(), "第 %d 天街坊绕着走：不排过路客人" % day)
	town.skip_to(700)
	await c.frames(2)
	var m0: int = town.minute
	await _to_door()
	await _key(KEY_E)
	var p = _call_panel()
	c.check(p != null, "断客那天门口按 E 也开小窗")
	_clear_toasts()
	if p != null:
		p.choose("pawn")
	await c.frames(2)
	c.check(_any_has(_toasts(), Walkin.line("call_boycott")) and town.minute == m0 and not town.overlay.is_speaking(), "断客那天吆喝：%s（不花时间）" % str(_toasts()))
	c.check(int(_w().st()["calls"]) == 0, "不算吆喝")
	town.skip_to(1000)
	await c.frames(2)
	var any := false
	for v in town.world.town.s["visits"]:
		if Walkin.is_walkin(v) and str(v["id"]).begins_with("walkin_d%d_" % day):
			any = true
	c.check(not any, "断客那天一位过路客人也没进门")
	# 架上的货过路的人都看不上（都是买不起的贵东西）：吆喝卖货灰着，写“过路的看不上”
	var saved: Dictionary = {}
	for row in _d()._town_shelf():
		saved[str(row["iid"])] = town.world.ledger.items[str(row["iid"])].get("market", 0)
		town.world.ledger.items[str(row["iid"])]["market"] = 100000
	await c.frames(30)
	await _to_door()
	await _key(KEY_E)
	p = _call_panel()
	c.check(p != null and not _d()._town_shelf().is_empty() and p.buttons["buy"].disabled and p.notes.has("buy") and str(p.notes["buy"].text) == Walkin.line("menu_no_buyer"), "架上有货、过路的人都看不上：吆喝卖货灰着，写着“%s”" % Walkin.line("menu_no_buyer"))
	if p != null:
		await _key(KEY_E)
	for iid in saved:
		town.world.ledger.items[iid]["market"] = saved[iid]
	# 架上没货
	for row in _d()._town_shelf():
		town.world.ledger.move_item(str(row["iid"]), "trash", "player", "测试：挪开")
	await c.frames(30)
	await _to_door()
	await _key(KEY_E)
	p = _call_panel()
	c.check(p != null, "架上没货：门口按 E 照样开小窗")
	if p == null:
		return
	c.check(p.buttons["buy"].disabled and p.notes.has("buy") and str(p.notes["buy"].text) == Walkin.line("menu_no_stock"), "吆喝卖货灰着，写着“%s”" % Walkin.line("menu_no_stock"))
	c.check(not p.buttons["pawn"].disabled, "吆喝收当还能点")
	p.choose("buy")
	await _key(KEY_2)
	c.check(_call_panel() == p and int(_w().st()["calls"]) == 0, "点灰着的吆喝卖货、按 2：没反应，小窗还开着")
	await _key(KEY_E)
	c.check(_call_panel() == null and town._modal_depth == 0, "E 关上")
	town.open_shelf()
	var sp = town._open_modals.back() if not town._open_modals.is_empty() else null
	c.check(sp != null and _any_has(_texts_of(sp), _w().shelf_text("empty")), "货架面板：%s" % _w().shelf_text("empty"))
	if sp != null and is_instance_valid(sp):
		sp.close()
	c.check(town.world.ledger.check_invariants().is_empty(), "账本不变量没破（结尾）")
