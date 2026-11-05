# [shop-only] 小镇界面：只守铺子 + 每天上门的保护费。
#   门口不放人出去（按 E 只说一句）；每天告示提一句、哥哥第一天交代、规矩页只写不隐藏的数
#   胡二每天都来；数目逐日不同但不出数据里的界；同一个种子数目一样
#   照数给 / 讲价 / 求缓 / 不给 / 钱不够拿货抵 / 没人接他自己走
#   不给的后果一档一档升；欠的账存档后还在；账本不变量始终成立
# godot --headless -s res://scripts/tests/town_ui_protect.gd
extends SceneTree

const Common = preload("res://scripts/tests/town_ui_common.gd")
const TownGame = preload("res://scripts/town/town_game.gd")
const ShopOnly = preload("res://scripts/town/shop_only.gd")
const Protection = preload("res://scripts/core/protection.gd")
const Rules = preload("res://scripts/town/rules.gd")
const Director = preload("res://scripts/core/director.gd")
const WalkinCallPanel = preload("res://scripts/town/walkin_call_panel.gd")      # v0.4.2：门口按 E 是门口吆喝的小窗

var SAVE: String = TownGame.scratch_save_path("ui_protect")
var c
var town
var main
var stats: Dictionary = {}
var total_fail: int = 0

func _initialize() -> void:
	_run()

# ---------------------------------------------------------------- 小工具
func _pr():
	return town.director.protect()

func _entry() -> Dictionary:
	return _pr().entry()

func _ready_protect() -> Dictionary:
	for id in town.visitors.present:
		var row: Dictionary = town.visitors.present[id]
		if str(row["visit"].get("intent", "")) == "protect":
			var w = row.get("walker", null)
			if w != null and is_instance_valid(w) and not w.is_walking():
				return row["visit"]
	return {}

func _wait_collector() -> bool:
	# 钟拨到他进门的钟点，等他走到等候点
	var e: Dictionary = _entry()
	if town.minute < int(e["minute"]):
		town.skip_to(int(e["minute"]))
	return await c.until(func(): return not _ready_protect().is_empty(), 1500)

# 接待收钱人：menu 是各次出现菜单时选的项；haggle 是议价怎么回（floor 出他的底价 / ask 出足 / lowball 狠压 / back 自己收手）
func _drive(plan: Dictionary) -> Dictionary:
	var out := {"menus": 0, "options": [], "lines": [], "counters": 0, "chosen": []}
	var visit: Dictionary = _ready_protect()
	if visit.is_empty():
		out["error"] = "no_visit"
		return out
	var menu: Array = plan.get("menu", ["pay"])
	var last_cur = null
	_manual(true)
	town.start_counter(visit)
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
			"choice":
				var ids: Array = []
				for o in main.cur.get("options", []):
					ids.append(str(o["id"]))
				out["options"].append(ids)
				var pick: String = str(menu[mini(int(out["menus"]), menu.size() - 1)])
				out["menus"] = int(out["menus"]) + 1
				if not ids.has(pick):
					pick = ids[0]
				out["chosen"].append(pick)
				main._respond({"id": pick})
			"counter":
				out["counters"] = int(out["counters"]) + 1
				var s = main.cur["session"]
				match str(plan.get("haggle", "floor")):
					"floor": main._respond({"action": "offer", "value": mini(int(_entry().get("floor", s.ask)), town.world.cash())})
					"mid":      # 头一回出个中间价；他回了价就接他的回价（讲下来一点算一点）
						var fl: int = int(_entry().get("floor", s.ask))
						var first: bool = int(out["counters"]) == 1
						var v: int = fl + int(ceil(float(int(_entry().get("amount", s.ask)) - fl) * 0.5)) if first else s.ask
						main._respond({"action": "offer", "value": mini(v, town.world.cash())})
					"ask": main._respond({"action": "offer", "value": mini(s.ask, town.world.cash())})
					"lowball": main._respond({"action": "offer", "value": 1})
					_: main._respond({"action": "refuse"})
			_:
				main._respond({})
	out["guard"] = guard
	_manual(false)
	await c.until_idle()
	return out

func _next_day() -> void:
	var before: int = town.world.day
	town.skip_to(1100)
	await town.goto("bed")
	await _sleep_now()
	c.check(town.world.day == before + 1, "睡一觉，第 %d 天" % town.world.day)

# 快钟下一整个过夜流程可能在同一帧里走完：先挂计数，再睡，再等
func _sleep_now() -> void:
	var seen := [0]
	var cb := func(_d): seen[0] += 1
	town.day_started.connect(cb)
	var began: bool = town.sleep()
	if not began:
		print("（睡不下）mode=%s modal=%d trans=%s busy=%s speaking=%s cur=%s min=%d map=%s" % [town.mode, town._modal_depth, str(town._transitioning), str(main.is_scene_busy()), str(town.overlay.is_speaking()), main.cur_type, town.minute, town.map_id])
	var okd: bool = await c.until(func(): return seen[0] > 0, 900)
	if not okd:
		print("（过夜卡住）mode=%s sleeping=%s cur=%s script=%s session=%s modal=%d min=%d ap_conn=%s" % [town.mode, str(town._sleeping), main.cur_type + ":" + str(main.cur.get("text", main.cur.get("night", ""))).substr(0, 20), town.director.current_script, str(town.director.session != null), town._modal_depth, town.minute, str(town.director.beat.is_connected(c.ap._on_beat))])
	town.day_started.disconnect(cb)
	await c.until_idle()

func _brother_talk() -> void:
	var ok: bool = await c.until(func(): return not town.visitors.next_ready().is_empty(), 1500)
	c.check(ok, "第一天早上哥哥在铺里等着")
	var v: Dictionary = town.visitors.next_ready()
	c.check(str(v.get("who", "")) == "brother", "最早等着的是哥哥")
	_manual(true)
	town.start_counter(v)
	var last_cur = null
	var texts: Array = []
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
	stats["brother_texts"] = texts

func _ledger_ok(tag: String) -> void:
	c.check(town.world.ledger.check_invariants().is_empty(), "账本不变量没破（%s）" % tag)

# 夜里和别的剧情交给 autoplayer；收钱人的一幕由本测试自己回应（先让 autoplayer 退场，演完再请回来）
func _manual(on: bool) -> void:
	var ap = c.ap
	if ap == null:
		return
	var d = town.director
	if on and d.beat.is_connected(ap._on_beat):
		d.beat.disconnect(ap._on_beat)
	elif not on and not d.beat.is_connected(ap._on_beat):
		d.beat.connect(ap._on_beat, CONNECT_DEFERRED)

func _boot_shop(seed_v: int, shop: bool = true) -> void:
	if c != null:
		total_fail += c.failures
	c = Common.new(self)
	c.shop_only = shop
	await c.boot(seed_v, true, true)
	town = c.town
	main = c.main
	main.dialogue.instant = true
	town.seconds_per_minute = 100000.0

# ---------------------------------------------------------------- 主流程
func _run() -> void:
	Protection.clear()
	await _part_paths()
	await _part_escalation()
	await _part_door_and_text()
	await _part_determinism()
	await _part_save()
	var fails: int = total_fail + c.failures
	print("RESULT: ", "OK" if fails == 0 else "FAILED (%d)" % fails)
	await c.shutdown()
	quit(0 if fails == 0 else 1)

# ---------- 路径：照数给 / 讲价 / 求缓 / 欠账滚到明天 / 钱不够 / 没人接 ----------
func _part_paths() -> void:
	await _boot_shop(5)
	var d = town.director
	c.check(d.shop_only(), "本局是只守铺子")
	c.check(bool(town.world.flags.get("shop_only", false)), "世界标志 shop_only 在")
	# 第一天
	var plan_p: Dictionary = town.last_plan.get("protect", {})
	c.check(not plan_p.is_empty() and str(plan_p.get("text", "")).contains("保护费"), "晨间告示提了一句维持会的人今天要来收保护费")
	c.check(str(plan_p.get("text", "")).find("蚨") < 0, "告示上没写数目")
	c.check(_pr().entry().get("status", "") == "pending", "今天这笔排上了")
	c.check(not _pr().visible(), "哥哥没交代以前收钱的人不上门")
	c.check(town.world.pages.find("rule_protect") < 0, "规矩页还没记")
	await _brother_talk()
	var bro: String = "\n".join(stats["brother_texts"])
	c.check(bro.contains("保护费") and bro.contains("胡二") and bro.contains("守着铺子"), "哥哥交代了保护费、胡二，也说了守着铺子")
	c.check(_pr().visible() and town.world.pages.has("rule_protect"), "交代之后收钱的人上门，规矩页记进档案簿")
	c.check(not town.world.pages.has("rule_leave"), "出门的规矩不记（守铺）")
	var rp: Dictionary = Rules.page(town.world, "rule_protect")
	c.check(Rules.hidden_number_hits(str(rp.get("body", ""))).is_empty(), "保护费规矩页没写隐藏的数")
	c.check(str(rp.get("body", "")).find("蚨") < 0, "规矩页没有具体数目")
	var cash0: int = town.world.cash()
	var public0: int = town.world.ledger.balance("维持会公账")
	var e1: Dictionary = _entry()
	c.check(int(e1["minute"]) >= 600 and int(e1["minute"]) <= 990, "上门钟点在 10:00–16:30 之间（%d）" % int(e1["minute"]))
	var arrived: bool = await _wait_collector()
	c.check(arrived, "胡二走进铺子、站到了等候点")
	var spot_ok := false
	for id in town.visitors.present:
		var w = town.visitors.present[id].get("walker", null)
		if str(town.visitors.present[id]["visit"].get("intent", "")) == "protect" and w != null:
			spot_ok = true
	c.check(spot_ok, "他是有身体的等候人物")
	var r1: Dictionary = await _drive({"menu": ["pay"]})
	c.check(int(r1["menus"]) == 1 and r1["options"][0].has("pay") and r1["options"][0].has("delay") and r1["options"][0].has("refuse"), "菜单有 照数给/求缓/不给（%s）" % str(r1["options"]))
	c.check(str(r1["lines"][0] if not r1["lines"].is_empty() else "").length() > 0 and "\n".join(r1["lines"]).contains("%d 蚨" % int(e1["amount"])), "胡二在对白里报了数目 %d" % int(e1["amount"]))
	c.check(str(_entry()["status"]) == "paid" and int(_entry()["paid"]) == int(e1["amount"]), "照数给：付了 %d" % int(e1["amount"]))
	c.check(town.world.cash() == cash0 - int(e1["amount"]), "钱匣少了 %d" % int(e1["amount"]))
	c.check(town.world.ledger.balance("维持会公账") == public0 + int(e1["amount"]), "钱走账本进了维持会公账")
	c.check(int(_pr().st()["streak"]) == 1 and int(_pr().st()["owed"]) == 0, "按时付，连付一回；没有欠账")
	_ledger_ok("第一天照数给")
	var amounts: Array = [int(e1["amount"])]
	# 日结有保护费一行
	await _next_day()
	var sm: Array = town.last_summary.get("protect_lines", [])
	c.check(not sm.is_empty() and str(sm[0]).contains("保护费") and str(sm[0]).contains("%d" % int(e1["amount"])), "日结有保护费一行：%s" % str(sm))
	# 第二天：讲价
	var plan2: Dictionary = town.last_plan.get("protect", {})
	c.check(str(plan2.get("text", "")).contains("保护费"), "第二天告示照样提一句")
	Protection.config()["haggle"]["min_amount"] = 1       # 保证这一天能讲价（不管当天抽到多少）
	var e2: Dictionary = _entry()
	amounts.append(int(e2["amount"]))
	var cash2: int = town.world.cash()
	c.check(await _wait_collector(), "第二天他也来了")
	var r2: Dictionary = await _drive({"menu": ["haggle"], "haggle": "mid"})
	c.check(r2["options"][0].has("haggle"), "第二天菜单有“讲讲价”")
	c.check(int(r2["counters"]) >= 1, "讲价开了一场议价（%d 轮）" % int(r2["counters"]))
	var st2 := str(_entry()["status"])
	c.check(st2 == "haggled" and int(_entry()["paid"]) <= int(e2["amount"]) and int(_entry()["paid"]) >= int(e2["floor"]), "讲下价来：付了 %d（要价 %d，底线 %d；状态 %s / %s；%s）" % [int(_entry()["paid"]), int(e2["amount"]), int(e2["floor"]), st2, str(town.director.vars.get("protect_result", "")), " | ".join(r2["lines"])])
	c.check(town.world.cash() == cash2 - int(_entry()["paid"]), "钱匣只少了讲下来的数")
	_ledger_ok("讲价")
	await _next_day()
	# 第三天：先狠压价，他翻脸走人（算不给），再看后果；换一个：自己收手回菜单后求缓
	var e3: Dictionary = _entry()
	amounts.append(int(e3["amount"]))
	var cash3: int = town.world.cash()
	c.check(await _wait_collector(), "第三天他也来了")
	var r3: Dictionary = await _drive({"menu": ["haggle", "delay"], "haggle": "back"})
	c.check(r3["options"].size() == 2 and not r3["options"][1].has("haggle"), "收手之后菜单里没有讲价了（%s）" % str(r3["options"]))
	var st3 := str(_entry()["status"])
	var owed3 := int(ceil(float(int(e3["amount"])) * 1.25))
	c.check(st3 == "delayed" and int(_pr().st()["owed"]) == owed3, "求缓一天：欠 %d（%d 加利）" % [owed3, int(e3["amount"])])
	c.check(town.world.cash() == cash3, "求缓没花钱")
	c.check(int(_pr().st()["strikes"]) == 0, "求缓不算不给")
	_ledger_ok("求缓")
	await _next_day()
	# 第四天：欠账滚进来
	var e4: Dictionary = _entry()
	amounts.append(int(e4["amount"]))
	c.check(int(e4["backlog"]) == owed3 and int(e4["amount"]) == mini(int(e4["today"]) + owed3, int(Protection.config()["amount"]["max_total"])), "第四天要的数 = 当天的 %d + 欠的 %d" % [int(e4["today"]), owed3])
	c.check(bool(town.last_plan.get("protect", {}).get("owed", false)), "告示提了一句昨天的账还挂着")
	var r4: Dictionary = await _drive_when_ready({"menu": ["pay"]})
	c.check(str(_entry()["status"]) == "paid" and int(_pr().st()["owed"]) == 0, "第四天连本带利付清，欠账清零")
	_ledger_ok("还欠账")
	await _next_day()
	# 第五天：钱不够，他拿货架上最值钱的一件
	var e5: Dictionary = _entry()
	amounts.append(int(e5["amount"]))
	var shelf: Array = d._town_shelf()
	c.check(not shelf.is_empty(), "货架上有货（%d 件）" % shelf.size())
	var top_name := ""
	var top_price := -1
	for row in shelf:
		if int(row["price"]) > top_price:
			top_price = int(row["price"])
			top_name = str(row["name"])
	var drain: int = town.world.cash() - 3
	c.check(town.world.ledger.transfer("player", "市场", drain, "（测试）花光") != "", "（测试）把钱花得只剩 3 蚨")
	var r5: Dictionary = await _drive_when_ready({"menu": ["pay"]})
	c.check(str(_entry()["status"]) == "goods" and _entry()["goods"].has(top_name), "钱不够：最值钱的「%s」被抵走了" % top_name)
	var taken_iid := ""
	for iid in town.world.ledger.items:
		if str(town.world.ledger.items[iid].get("name", "")) == top_name and str(town.world.ledger.items[iid].get("owner", "")) == "hu2":
			taken_iid = iid
	c.check(taken_iid != "", "货走账本：归了胡二")
	c.check(taken_iid != "" and "\n".join(town.world.ledger.items[taken_iid]["history"]).contains("抵"), "物件的来历里记了被抵走")
	var noted := false
	for n in town.world.notebook:
		if str(n.get("text", "")).contains("拿走了「%s」" % top_name):
			noted = true
	c.check(noted, "档案簿记了一笔")
	c.check(town.world.cash() >= 0, "钱没扣成负的")
	_ledger_ok("钱不够拿货抵")
	c.check("\n".join(r5["lines"]).contains(top_name), "对白里他拿起了「%s」" % top_name)
	await _next_day()
	# 第六天：不去柜台，他等一阵走了——头一回当求缓
	var e6: Dictionary = _entry()
	amounts.append(int(e6["amount"]))
	c.check(await _wait_collector(), "第六天他也来了")
	town.skip_to(int(e6["minute"]) + 160)
	await c.frames(3)
	c.check(str(_entry()["status"]) == "missed" and int(_pr().st()["owed"]) > 0 and int(_pr().st()["strikes"]) == 0, "没人接他：头一回当求缓（欠 %d）" % int(_pr().st()["owed"]))
	_ledger_ok("没人接（头一回）")
	await _next_day()
	# 第七天：又没人接——这回当不给
	var e7: Dictionary = _entry()
	amounts.append(int(e7["amount"]))
	var strikes_before := int(_pr().st()["strikes"])
	town.skip_to(int(e7["minute"]) + 160)
	await c.frames(3)
	c.check(str(_entry()["status"]) == "missed" and int(_pr().st()["strikes"]) == strikes_before + 1, "没人接他：第二回当不给，记一次前科")
	_ledger_ok("没人接（第二回）")
	# 数目逐日不同、不出界
	var a: Dictionary = Protection.config()["amount"]
	var lo_ok := true
	var distinct: Dictionary = {}
	for k in _pr().st()["days"]:
		var en: Dictionary = _pr().st()["days"][k]
		distinct[int(en["today"])] = true
		if int(en["today"]) < int(a["min_today"]) or int(en["today"]) > int(a["max_today"]) or int(en["amount"]) > int(a["max_total"]):
			lo_ok = false
		var bl: Array = a["base_range"]
		if int(en["base"]) < int(bl[0]) or int(en["base"]) > int(bl[1]):
			lo_ok = false
		if int(en["minute"]) < 600 or int(en["minute"]) > 990:
			lo_ok = false
	c.check(lo_ok, "每天的钟点、基数、数目都在 data/town/protection.json 的界里")
	c.check(distinct.size() >= 4, "七天里当天的数有 %d 种，不是一个死数" % distinct.size())
	c.check(town.world.day == 7, "走到了第 7 天，没卡死")
	print("七天要的数：", amounts)
	await c.shutdown()
	stats["failures_paths"] = c.failures

# 在 _drive 之前等他站定
func _drive_when_ready(plan: Dictionary) -> Dictionary:
	c.check(await _wait_collector(), "第 %d 天他来了" % town.world.day)
	return await _drive(plan)

# ---------- 不给的后果一档一档升 ----------
func _part_escalation() -> void:
	var failures_before: int = c.failures if c != null else 0
	await _boot_shop(9)
	await _brother_talk()
	var d = town.director
	var koubei0: int = town.world.koubei
	var susp0: int = town.world.suspicion
	# 第一回不给：警告 + 风声，不拿东西
	var shelf_n: int = d._town_shelf().size()
	var r1: Dictionary = await _drive_when_ready({"menu": ["refuse"]})
	var st: Dictionary = _pr().st()
	c.check(str(_entry()["status"]) == "refused" and int(st["strikes"]) == 1 and _entry()["goods"].is_empty(), "头一回不给：只是警告，不拿东西")
	c.check(d._town_shelf().size() == shelf_n, "货架原样")
	c.check("\n".join(r1["lines"]).contains("马保长"), "他撂了话（提到马保长）")
	c.check(int(st["owed"]) > 0, "账不会白免，记着 %d" % int(st["owed"]))
	var heard_rumor := false
	for k in town.world.town.s["known"].get("ma", {}):
		if str(k) == "protect_refused":
			heard_rumor = true
	c.check(heard_rumor, "风声传出去了（protect_refused）")
	_ledger_ok("第一回不给")
	await _next_day()
	# 第二回：拿货架上最值钱的一件抵押
	var amount2: int = int(_entry()["amount"])
	c.check(int(_entry()["backlog"]) > 0 and amount2 > int(_entry()["today"]) - 1, "第二天的数里带着欠账 %d（共 %d）" % [int(_entry()["backlog"]), amount2])
	var shelf2: Array = d._town_shelf()
	var top_name := ""
	var top_price := -1
	for row in shelf2:
		if int(row["price"]) > top_price:
			top_price = int(row["price"])
			top_name = str(row["name"])
	var r2: Dictionary = await _drive_when_ready({"menu": ["refuse"]})
	c.check(int(_pr().st()["strikes"]) == 2 and _entry()["goods"].has(top_name), "第二回不给：货架上最值钱的「%s」被抵押" % top_name)
	c.check("\n".join(r2["lines"]).contains(top_name), "对白里拿走了它")
	c.check(d._town_shelf().size() == shelf2.size() - 1, "货架少了一件")
	_ledger_ok("第二回不给")
	await _next_day()
	# 第三回：街坊绕着走（明天断客）、口碑和怀疑吃亏
	var r3: Dictionary = await _drive_when_ready({"menu": ["refuse"]})
	var st3: Dictionary = _pr().st()
	c.check(int(st3["strikes"]) == 3 and int(st3["boycott_day"]) == town.world.day + 1, "第三回不给：明天街坊绕着走")
	c.check(town.world.koubei < koubei0, "口碑掉了（%d → %d）" % [koubei0, town.world.koubei])
	c.check(town.world.suspicion > susp0, "怀疑涨了（%d → %d）" % [susp0, town.world.suspicion])
	c.check("\n".join(r3["lines"]).contains("绕着"), "他把话撂明白了")
	_ledger_ok("第三回不给")
	await _next_day()
	var plan4: Dictionary = town.last_plan.get("protect", {})
	c.check(bool(plan4.get("boycott", false)), "告示上写了街坊绕着走")
	var strangers := 0
	for v in town.world.town.s["visits"]:
		if str(v.get("storylet", "")) == "" and str(v.get("intent", "")) != "protect":
			strangers += 1
	c.check(strangers == 0, "这一天随机来的客人一个没有")
	c.check(await _wait_collector(), "收钱的人照样来")
	# 付清一回，前科减一档，连付的天数涨
	var r4: Dictionary = await _drive({"menu": ["pay"]})
	c.check(int(_pr().st()["strikes"]) == 2 and str(_entry()["status"]) == "paid", "付清一回，前科减一档（%d）" % int(_pr().st()["strikes"]))
	_ledger_ok("付清")
	c.check(town.world.day == 4, "没卡死")
	# 第五天：狠压价，他翻脸走人——按不给算，还恼了
	await _next_day()
	Protection.config()["haggle"]["min_amount"] = 1
	var strikes_b4: int = int(_pr().st()["strikes"])
	var r5: Dictionary = await _drive_when_ready({"menu": ["haggle"], "haggle": "lowball"})
	c.check(int(r5["counters"]) >= 1 and "\n".join(r5["lines"]).contains("不识抬举"), "狠压价：他翻脸了（%d 轮）" % int(r5["counters"]))
	c.check(str(_entry()["status"]) == "refused" and int(_pr().st()["strikes"]) == strikes_b4 + 1 and int(_entry()["paid"]) == 0, "翻脸走人按不给算，一个子儿没付")
	_ledger_ok("讲崩了")
	await c.shutdown()

# ---------- 门口、告示、日结、规矩 ----------
func _part_door_and_text() -> void:
	await _boot_shop(11)
	var map = town.world_view.map
	var door: Dictionary = map.door_to_map("town")
	c.check(not door.is_empty(), "铺子有一扇通街的门")
	c.check(town.map_id == "pawnshop", "在铺子里醒来")
	# 走到门口：提示是“门口吆喝”，不是“出门”（v0.4.2：门口按 E 是吆喝的小窗，细节在 town_ui_walkin）
	town.player.teleport(door["front"])
	await c.frames(3)
	var near: Dictionary = town._find_near()
	c.check(not near.is_empty() and str(near["label"]) == "门口吆喝", "门口的提示是「门口吆喝」（%s）" % str(near.get("label", "")))
	# 按 E：不出门，开门口吆喝的小窗
	town.interact()
	await c.frames(3)
	c.check(town.map_id == "pawnshop" and town.mode == "town", "按 E 没有出门")
	var top = town._open_modals.back() if not town._open_modals.is_empty() else null
	c.check(top != null and top.get_script() == WalkinCallPanel, "按 E 打开门口吆喝的小窗")
	if top != null and is_instance_valid(top):
		top.close()
	await c.frames(2)
	var line := ShopOnly.door_line(1)
	c.check(line.contains("守着铺子") or line.contains("不卸"), "是守铺的话：%s" % line)
	# 直接 _try_door（走进门口那一格）：只说一句，不出门
	await town._try_door(door)
	c.check(town.map_id == "pawnshop", "走进门区也出不去")
	c.check(town.overlay.is_speaking(), "走进门区：头顶冒了一句话")
	town.overlay.end_speech()
	# 往门里走（模拟按住下方向键停在门区里）
	town.player.teleport(door["front"])
	town.player.use_external = true
	town.player.external_input = Vector2(0, 1)
	await c.frames(40)
	town.player.use_external = false
	town.player.external_input = Vector2.ZERO
	c.check(town.map_id == "pawnshop", "按住往外走也出不去")
	town.overlay.end_speech()
	# 宵禁的提醒不响、巡夜不动
	# 家里的开销：不扣不罚
	var plan: Dictionary = town.last_plan
	for b in plan.get("bills", []):
		c.check(str(b.get("status", "")) in ["waived", "paid"], "账单 %s 暂免（%s）" % [str(b.get("label", "")), str(b.get("status", ""))])
	# 不去睡觉也不会饿：睡一觉后米缸原样
	town.skip_to(1100)
	await town.goto("bed")
	await _sleep_now()
	var h: Dictionary = town.household()
	c.check(int(h.get("rice", 0)) >= 12 and int(h.get("hunger", 0)) == 0 and int(h.get("illness", 0)) == 0, "米缸没少、没饿着、没病：米 %d" % int(h.get("rice", 0)))
	c.check(int(h.get("stamina", 0)) >= 100, "体力满：%d" % int(h.get("stamina", 0)))
	var unpaid := 0
	for b in town.world.town.bills():
		if str(b.get("status", "")) in ["due", "overdue"]:
			unpaid += 1
	c.check(unpaid == 0, "没有要出门去付的账")
	# 出门的引导不亮
	var g = town.guide
	g.allow_autoplay = true
	g.reset_progress()
	town.skip_to(500)
	await c.frames(30)
	for sid in ["leave_shop", "rice_low_exit", "travel_pick", "rice_low_travel"]:
		c.check(not g.shown_log.has(sid), "出门的引导 %s 不亮" % sid)
	c.check(not town.world.pages.has("rule_leave") and not town.world.pages.has("rule_levy"), "出门的规矩页没解锁")
	# 剧情卡：要出门才能办的不触发
	for v in town.director.town_visits():
		if str(v.get("storylet", "")) != "":
			c.check(str(v.get("storylet", "")) not in ["d7_fees", "d14_fees", "d6_invitation", "d10_invitation"], "要出门才能办的卡 %s 没出现" % str(v.get("storylet", "")))
	# 关掉守铺：出门、开销、保护费都回到原样
	await c.shutdown()
	await _boot_shop(11, false)
	c.check(not town.director.shop_only() and not town.director.protect().active(), "守铺关掉后没有保护费")
	var d2: Dictionary = town.world_view.map.door_to_map("town")
	town.player.teleport(d2["front"])
	await c.frames(3)
	var near2: Dictionary = town._find_near()
	c.check(str(near2.get("label", "")) == "出门", "关掉后门口还是「出门」")
	var pv := false
	for v in town.director.town_visits():
		if str(v.get("intent", "")) == "protect":
			pv = true
	c.check(not pv, "关掉后名单里没有收保护费的人")
	await c.shutdown()

# ---------- 同一个种子数目一样，不同种子不一样 ----------
func _sim(seed_v: int, days: int) -> Array:
	var d = Director.new()
	root.add_child(d)
	d.setup_town(seed_v, "常年", true)
	d.protect().on_told()
	var rows: Array = []
	for i in days:
		d.town_start_day()
		var e: Dictionary = d.protect().ensure_day()
		rows.append([int(e["minute"]), int(e["today"]), int(e["amount"]), int(e["floor"])])
		d.protect().begin_visit()
		d.protect().pay()
		d.world.town.set_minute(1200)
		d.town_finish_day()
	var inv: Array = d.world.ledger.check_invariants()
	if not inv.is_empty():
		rows.append(["不变量", str(inv)])
	d.free()
	return rows

func _part_determinism() -> void:
	var a: Array = _sim(21, 8)
	var b: Array = _sim(21, 8)
	var other: Array = _sim(22, 8)
	c.check(a == b, "同一个种子，8 天的钟点/数目/底线逐日一样：%s" % str(a.map(func(r): return r[2])))
	c.check(a != other, "换个种子，数目不同：%s" % str(other.map(func(r): return r[2])))
	var inv_bad := false
	for r in a:
		if r.size() == 2:
			inv_bad = true
	c.check(not inv_bad, "只付不欠的 8 天，账本不变量始终成立")
	# 欠账、前科会把数目抬高：同一天，有前科的比没前科的多（不看抖动，只看因素）
	var d = Director.new()
	root.add_child(d)
	d.setup_town(21, "常年", true)
	d.protect().on_told()
	d.town_start_day()
	var plain: int = int(d.protect().compute_amount(1)["today"])
	d.protect().st()["strikes"] = 3
	var rough: int = int(d.protect().compute_amount(1)["today"])
	d.protect().st()["strikes"] = 0
	d.protect().st()["streak"] = 4
	var kind: int = int(d.protect().compute_amount(1)["today"])
	c.check(rough > plain and kind <= plain, "有前科要得多（%d > %d），连着按时付要得少（%d）" % [rough, plain, kind])
	d.world.town.s["pressures"]["heat"] = 0.8
	d.protect().st()["streak"] = 0
	var hot: int = int(d.protect().compute_amount(1)["today"])
	c.check(hot > plain, "风声紧（热度高）要得多（%d > %d）" % [hot, plain])
	d.free()
	# 要出门才能办的剧情卡：守铺时第 7、14 天不出现；不守铺时照旧
	for shop_flag in [true, false]:
		var dd = Director.new()
		root.add_child(dd)
		dd.setup_town(21, "常年", shop_flag)
		var seen_cards: Array = []
		for i in 14:
			dd.town_start_day()
			for v in dd.town_visits():
				if str(v.get("storylet", "")) != "":
					seen_cards.append(str(v["storylet"]))
			dd.world.town.set_minute(1200)
			if shop_flag:
				dd.protect().begin_visit()
				dd.protect().pay()
			dd.town_finish_day()
		var has_fee: bool = seen_cards.has("d7_fees") or seen_cards.has("d14_fees") or seen_cards.has("d6_invitation")
		c.check(has_fee != shop_flag, "守铺=%s 时，要出门办的卡%s出现" % [str(shop_flag), "没有" if shop_flag else "照常"])
		if shop_flag:
			var home: Dictionary = dd._town_state()["household"]
			c.check(int(home["rice"]) == 12 and int(home["fuel"]) == 8, "守铺 14 天，米缸柴炭原样（米 %d 柴 %d）" % [int(home["rice"]), int(home["fuel"])])
			var unpaid := 0
			for bill in dd.world.town.bills():
				if str(bill["status"]) in ["due", "overdue"]:
					unpaid += 1
			c.check(unpaid == 0, "守铺 14 天没有出门才能付的账挂着")
			c.check(dd.world.ledger.check_invariants().is_empty(), "14 天账本不变量没破")
		dd.free()

# ---------- 存档：欠的账、前科、课过的天数都在 ----------
func _part_save() -> void:
	if FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	await _boot_shop(33)
	await _brother_talk()
	var r1: Dictionary = await _drive_when_ready({"menu": ["delay"]})
	c.check(str(_entry()["status"]) == "delayed", "第一天求缓，欠 %d" % int(_pr().st()["owed"]))
	await _next_day()
	var owed: int = int(_pr().st()["owed"])
	var amount: int = int(_entry()["amount"])
	var minute: int = int(_entry()["minute"])
	var days_json := JSON.stringify(_pr().st(), "", true, true)
	town.autosave = true
	town.save_path = SAVE
	c.check(town.save_game(SAVE), "存档")
	await c.shutdown()
	var c2 = Common.new(self)
	c2.shop_only = true
	await c2.make_main()
	var town2 = c2.town
	town2.set_fast(true)
	town2.auto_dismiss = true
	town2.autosave = false
	town2.save_path = SAVE
	var ok: bool = await town2.load_game(SAVE)
	c2.check(ok, "读档成功")
	await c2.until_idle()
	var p2 = town2.director.protect()
	c2.check(town2.director.shop_only(), "读档后仍是守铺")
	c2.check(int(p2.st()["owed"]) == owed and owed > 0, "读档后欠的账还在：%d" % int(p2.st()["owed"]))
	c2.check(int(p2.entry()["amount"]) == amount and int(p2.entry()["minute"]) == minute, "今天要的数和钟点不变：%d" % int(p2.entry()["amount"]))
	c2.check(JSON.stringify(p2.st(), "", true, true) == days_json, "保护费的账（欠、前科、逐日记录）逐字一致")
	var has_visit := false
	for v in town2.director.town_visits():
		if str(v.get("intent", "")) == "protect":
			has_visit = true
	c2.check(has_visit, "读档后今天的收钱人还在名单里")
	c2.check(town2.world.ledger.check_invariants().is_empty(), "读档后账本不变量没破")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	total_fail += c2.failures
	await c2.shutdown()
