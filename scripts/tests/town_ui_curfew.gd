# 小镇界面（宵禁）：九点以后每出一趟门都可能撞上巡夜的，待在屋里不会；先有人说过规矩才可能被拦；次数越多处置越重；
# 塞钱走账本、押回家要到第二天九点才起；同一局同样的走法结果一样；存档读档不丢违规次数。
# 出行系统（“去哪儿”地图）只要在每趟出发前 await curfew.check_trip(from, to, minute)；这里直接调它来测。
# godot --headless -s res://scripts/tests/town_ui_curfew.gd      （调试：-- --only=<场景名> 只跑一个）
extends SceneTree

const Common = preload("res://scripts/tests/town_ui_common.gd")
const Curfew = preload("res://scripts/town/curfew.gd")
const TownGame = preload("res://scripts/town/town_game.gd")
const Costs = preload("res://scripts/sim/living_costs.gd")
const R = preload("res://scripts/sim/jev_rng.gd")

var c
var town
var main
var failures_total: int = 0
var beats: Array = []            # 导演发过的、要等玩家回应的 beat（type / text / options）
var _from: int = 0

func _initialize() -> void:
	_run()

# ---------------------------------------------------------------- 公共
# 开一局小镇（快钟冻住，只听本测试的）。自动试玩器当“玩家”回应对白；拦下一幕里的选项由 choice_queue 指定
func _boot(seed_v: int) -> void:
	c = Common.new(self)
	await c.boot(seed_v, true, true)
	_attach(c)

func _attach(common) -> void:
	c = common
	town = c.town
	main = c.main
	beats = []
	town.director.beat.connect(func(b):
		if not b.get("nowait", false):
			var row := {"type": str(b.get("type", "")), "text": str(b.get("text", ""))}
			if b.has("options"):
				var ids: Array = []
				var labels: Array = []
				for o in b["options"]:
					ids.append(str(o["id"]))
					labels.append(str(o["label"]))
				row["options"] = ids
				row["labels"] = labels
			beats.append(row))
	main.dialogue.instant = true
	town.seconds_per_minute = 100000.0

func _end() -> void:
	failures_total += c.failures
	await c.shutdown()

func _st() -> Dictionary:
	return town.curfew.state()

func _seed() -> int:
	return int(town.world.town.s["seed"])

func _home() -> Dictionary:
	return town.director.vars["town"]["household"]

# 想要“还没人说过规矩”的局面：让哥哥 20:30 那一回算已经过了
func _skip_brother() -> void:
	_st()["brother_day"] = town.world.day

# 夜里出一趟门：自动试玩器当玩家，拦下一幕里选 pick。返回 {trip, texts, options, labels, types}
func _trip(from_place: String, to_place: String, minute: int, pick: String = "honest") -> Dictionary:
	c.ap.choice_queue = [pick]
	_from = beats.size()
	var trip: Dictionary = await town.curfew.check_trip(from_place, to_place, minute)
	c.ap.choice_queue = []
	var out := {"trip": trip, "texts": [], "options": [], "labels": [], "types": []}
	for row in beats.slice(_from):
		(out["types"] as Array).append(row["type"])
		if row["type"] in ["say", "narr"]:
			(out["texts"] as Array).append(row["text"])
		elif row["type"] == "choice":
			out["options"] = row["options"]
			out["labels"] = row["labels"]
	return out

# 等正在演的一段（哥哥的话）演完
func _settle() -> void:
	var n := 0
	while town.curfew.busy and n < 4000:
		n += 1
		await process_frame
	await c.until_idle(900)

func _sleep_through() -> bool:
	var day0: int = town.world.day
	return await c.until(func(): return town.world.day == day0 + 1 and town.is_idle_in_town(), 9000)

func _toast_text() -> String:
	var out := ""
	for t in town.overlay._toast_box.get_children():
		out += (t as Label).text + "|"
	for q in town.overlay._toast_queue:
		out += str(q["text"]) + "|"
	return out

func _notes_have(fragment: String) -> bool:
	for e in town.world.notebook:
		if str(e["text"]).find(fragment) >= 0:
			return true
	return false

func _labels_in(node: Node) -> String:
	var out := ""
	if node is Label:
		out += (node as Label).text + "\n"
	for ch in node.get_children():
		out += _labels_in(ch)
	return out

func _give_pass() -> void:
	var spec := {"id": "certificate", "label": "良民证", "amount": 6, "min": 6, "max": 6, "payee": "维持会公账", "building": "baogong", "due_days": 0}
	Costs.add(town.world.town.pack, town.world.town.s, spec, "test", "bill:certificate:once", town.world)
	town.world.town.pay_bill("bill:certificate:once", 6, "test|cert")

func _find_k(domain: String, want: Callable, from: int = 0) -> int:
	var day: int = town.world.day
	for k in range(from, from + 600):
		if want.call(R.draw(_seed(), domain, [day, k])):
			return k
	return -1

# 把“下一趟”钉在序号 k 上：拦人的那一签必中（u 很小），另一签（domain）满足 want
func _pin(domain: String = "", want: Callable = Callable()) -> int:
	var day: int = town.world.day
	var cur: int = int(_st()["trips"].get(str(day), 0))
	for k in range(cur, cur + 600):
		var hit: bool = R.draw(_seed(), "curfew_trip", [day, k]) < 0.04
		if hit and (domain == "" or want.call(R.draw(_seed(), domain, [day, k]))):
			_st()["trips"][str(day)] = k
			return k
	return -1

func _ctx(idx: int) -> Dictionary:
	return town.curfew._context(town.minute, idx)

func _bill_by(id: String) -> Dictionary:
	for b in town.world.town.s["bills"]:
		if str(b["id"]) == id:
			return b
	return {}

func _fine_bill() -> Dictionary:
	for b in town.world.town.s["bills"]:
		if str(b.get("cost_id", "")) == "curfew_fine":
			return b
	return {}

# ---------------------------------------------------------------- 场景
func _s_data() -> void:
	print("-- 数据与规矩")
	var cfg: Dictionary = Curfew.config()
	c = Common.new(self)
	c.check(not cfg.is_empty() and cfg.has("trip") and cfg.has("ladder"), "data/town/curfew.json 读得出来")
	var db = DB.get_db()
	for key in ["stop", "result", "lantern"]:
		c.check(db.scripts.has(str(cfg["scripts"][key])), "脚本在：" + str(cfg["scripts"][key]))
	c.check(db.scripts.has(str(cfg["brother"]["script"])) and db.scripts.has("town_curfew_ma"), "哥哥、马保长的提醒脚本在")
	var page: Dictionary = db.pages.get("curfew", {})
	c.check(str(page.get("title", "")) == "宵禁" and str(page.get("body", "")).length() > 80, "知识页 curfew 在 data/pages.json 里")
	var body := str(page.get("body", ""))
	var digit := false
	for ch in body:
		if ch >= "0" and ch <= "9":
			digit = true
	c.check(not digit and body.find("概率") < 0 and body.find("%") < 0, "知识页只用白话，不露数字、概率")
	for word in ["九点", "灯笼", "每走一趟", "撞上", "训诫", "罚洋", "押", "马保长", "跨桥", "铺子里"]:
		c.check(body.find(word) >= 0, "知识页说到了：" + word)
	var d2: String = FileAccess.get_file_as_string("res://data/story/d2_ma.json")
	c.check(d2.find("town_curfew_ma") >= 0 and d2.find("is('town_mode')") >= 0, "马保长第二天的场景里挂着宵禁提醒（只在小镇版）")
	var pack = JSON.parse_string(FileAccess.get_file_as_string("res://data/town/town_pack.json"))
	var rumor: Array = pack["rumors"].get("curfew_caught", [])
	c.check(rumor.size() >= 3 and str(rumor[0]) == "沈家丫头半夜还在街上晃", "流言 curfew_caught 有三种说法")
	var places: Dictionary = cfg["trip"]["places"]
	for p in ["德厚当", "茶馆", "米行", "济生堂", "保公所", "邮电局", "孙府", "集市", "码头"]:
		c.check(places.has(p), "出行距离表里有：" + p)
	failures_total += c.failures
	DB.shutdown()

func _s_inside_and_brother() -> void:
	print("-- 待在屋里不会被拦；哥哥 20:30 提醒；20:45 轻提醒；知识页")
	await _boot(21)
	c.check(not town.world.pages.has("curfew"), "开局没有宵禁这一页")
	var stamina0: int = int(_home()["stamina"])
	town.skip_to(1229)
	c.check(not town.curfew.busy and not town.world.pages.has("curfew"), "20:29 还没人提")
	_from = beats.size()
	town.skip_to(1231)
	await process_frame
	c.check(beats.size() > _from, "20:30 铺子里：哥哥开口了")
	await _settle()
	var said := ""
	for row in beats.slice(_from):
		said += str(row["text"]) + "|"
	c.check(said.find("九点以后别上街") >= 0 and said.find("灯笼") >= 0, "哥哥说：九点以后别上街，维持会的人提着灯笼巡夜")
	c.check(town.world.pages.has("curfew"), "知识页 curfew 解锁了")
	c.check(_st()["told_by"].has("brother") and town.curfew.is_told(), "记下了：哥哥说过")
	c.check(_notes_have("九点以后别上街"), "档案簿里记了一笔")
	town.skip_to(1246)
	c.check(_toast_text().find("快到宵禁的时辰") >= 0, "20:45 轻轻提醒了一句")
	town.skip_to(1262)
	c.check(town.curfew.badge != null and town.curfew.badge.visible and town.curfew.badge.text.find("宵禁") >= 0, "屏幕左下角有红牌“宵禁”")
	var red: Color = town.curfew.badge.get_theme_color("font_color")
	c.check(red.r > 0.8 and red.g < 0.6 and red.b < 0.5, "牌子上的字是红的")
	c.check(town.hud.place_lbl.text.find("宵禁") >= 0 and town.hud.place_lbl.has_theme_color_override("font_color"), "时辰旁的地点也标了宵禁、变红")
	town.skip_to(1439)
	c.check(int(_st()["stops"]) == 0 and int(_st()["offences"]) == 0 and not town.curfew.stop_active, "待在屋里一整夜：什么也没发生")
	c.check(int(_home()["stamina"]) == stamina0, "屋里不冷，体力没耗")
	c.check(town.curfew.trace.is_empty() and (_st()["trips"] as Dictionary).is_empty(), "没出过门，一次也没抽过签")
	await _end()

func _s_far_brother() -> void:
	print("-- 人不在铺子里，哥哥不会隔空说话")
	await _boot(22)
	await town.goto("ricehall")
	town.skip_to(1255)
	c.check(not town.curfew.busy and not _st()["told_by"].has("brother") and not town.world.pages.has("curfew"), "人不在铺子里：哥哥没有开口，也没有白送一页")
	c.check(_toast_text().find("快到宵禁的时辰") >= 0, "但 20:45 的提醒还在")
	await _end()

func _s_chance() -> void:
	print("-- 一趟路撞上巡夜的有多大可能：越晚、越远、越被记着，越容易")
	await _boot(5)
	_skip_brother()
	town.skip_to(1262)
	var cf = town.curfew
	c.check(cf.trip_segments("德厚当", "茶馆") == 1.0 and cf.trip_segments("pawnshop", "teahouse") == 1.0, "隔壁一段路（地点名和建筑 id 都认）")
	c.check(cf.trip_segments("德厚当", "米行") == 2.0 and cf.trip_segments("米行", "德厚当") == 2.0, "米行两段，来回一样")
	var to_market: float = cf.trip_segments("德厚当", "集市")
	var to_dock: float = cf.trip_segments("德厚当", "码头")
	c.check(to_market > 4.0 and to_dock > to_market, "过桥的路长得多（集市 %.1f 段、码头 %.1f 段）" % [to_market, to_dock])
	c.check(cf.trip_segments("集市", "码头") < to_market, "桥南两处之间不用再过桥")
	c.check(cf.trip_segments("德厚当", "不知名的地方") == float(Curfew.config()["trip"]["unknown_segments"]) and cf.trip_segments("米行", "米行") == 0.0, "没记的地方按默认的路算；原地不动不算一趟")
	var m := 1275
	var near: float = cf.trip_chance("德厚当", "茶馆", m)["chance"]
	var mid: float = cf.trip_chance("德厚当", "米行", m)["chance"]
	var far: float = cf.trip_chance("德厚当", "集市", m)["chance"]
	var farther: float = cf.trip_chance("德厚当", "码头", m)["chance"]
	c.check(near < mid and mid < far and far < farther, "隔壁比过桥稳当（%.2f < %.2f < %.2f < %.2f）" % [near, mid, far, farther])
	var early: float = cf.trip_chance("德厚当", "米行", 1265)["chance"]
	var late: float = cf.trip_chance("德厚当", "米行", 1400)["chance"]
	var dawn: float = cf.trip_chance("德厚当", "米行", 120)["chance"]
	c.check(early > late and late > dawn, "刚宵禁时巡得最紧，后半夜松些（%.2f > %.2f > %.2f）" % [early, late, dawn])
	var base: float = cf.trip_chance("德厚当", "米行", m)["chance"]
	town.world.town.s["pressures"]["heat"] = 0.4
	_st()["patrol_day"] = -1
	c.check(cf.patrol_count() == 2 and cf.trip_chance("德厚当", "米行", m)["chance"] > base, "热度高的夜里是两个人巡，更容易撞上")
	town.world.town.s["pressures"]["heat"] = 0.0
	town.world.town.s["pressures"]["unrest"] = 0.3
	_st()["patrol_day"] = -1
	c.check(cf.patrol_count() == 2, "民心不稳也是两个人")
	town.world.town.s["pressures"]["unrest"] = 0.0
	_st()["patrol_day"] = -1
	c.check(cf.patrol_count() == 1 and absf(cf.trip_chance("德厚当", "米行", m)["chance"] - base) < 0.0001, "太平的夜里一个人巡")
	_st()["offences"] = 2
	var wary: float = cf.trip_chance("德厚当", "米行", m)["chance"]
	c.check(wary > base, "被记过的人更容易被盯上（%.2f → %.2f）" % [base, wary])
	_st()["offences"] = 0
	var tc: Dictionary = Curfew.config()["trip"]
	c.check(cf.trip_chance("德厚当", "茶馆", 1400)["chance"] >= float(tc["min_chance"]) and cf.trip_chance("德厚当", "码头", 1262)["chance"] <= float(tc["max_chance"]), "概率有上下限")
	# 白天出门：不查、不耗体力、不占序号
	var s0: int = int(_home()["stamina"])
	var day_trip: Dictionary = await cf.check_trip("德厚当", "米行", 600)
	c.check(not day_trip["active"] and not day_trip["stopped"] and day_trip["proceed"] and int(_home()["stamina"]) == s0 and (_st()["trips"] as Dictionary).is_empty(), "白天出门：什么也没发生")
	var same: Dictionary = await cf.check_trip("德厚当", "pawnshop", 1300)
	c.check(not same["active"], "原地不动不算一趟")
	await _end()

func _s_first_trip() -> void:
	print("-- 先说后罚：头一趟夜路只让你看见灯笼，规矩说过之后才可能被拦")
	await _boot(5)
	_skip_brother()
	town.skip_to(1262)
	c.check(not town.world.pages.has("curfew") and not town.curfew.is_told() and int(_st()["stops"]) == 0, "还没有人说过规矩，也没被拦过")
	var k: int = _pin()
	c.check(k >= 0, "（把头一趟的签钉在必中上）")
	var r1: Dictionary = await _trip("德厚当", "码头", 1270)
	var t1: Dictionary = r1["trip"]
	var said := "|".join(r1["texts"])
	c.check(t1["active"] and t1["kind"] == "told" and not t1["stopped"] and t1["proceed"], "头一趟：就算这一签必中，也只是看见灯笼，没被拦")
	c.check(said.find("灯笼") >= 0 and said.find("街上不许有人") >= 0, "灯笼、“九点以后街上不许有人”")
	c.check(town.world.pages.has("curfew") and _st()["told"] and _st()["told_by"].has("lantern"), "看见灯笼 = 规矩说过了：知识页解锁")
	c.check(_toast_text().find("宵禁") >= 0, "册子里添了一页的提示")
	c.check(int(_st()["stops"]) == 0 and int(_st()["offences"]) == 0 and not town.curfew.busy, "还没被拦过，这一幕演完了")
	c.check((_st()["trips"] as Dictionary)[str(town.world.day)] == k + 1, "这一趟记了序号")
	_pin()
	var r2: Dictionary = await _trip("德厚当", "码头", 1275)
	c.check(r2["trip"]["stopped"] and r2["trip"]["kind"] == "warn", "规矩说过之后，同样必中的下一趟被拦下了")
	c.check(int(_st()["stops"]) == 1 and not town.curfew.stop_active and not town.curfew.busy, "拦下的一幕演完，一切放开")
	await _end()

func _s_ladder() -> void:
	print("-- 第一次训诫、第二次罚洋、第三次押回家")
	await _boot(5)
	town.skip_to(1262)                 # 在铺子里，哥哥 20:30 说过了
	await _settle()
	c.check(town.curfew.is_told() and town.world.pages.has("curfew"), "哥哥说过，规矩算说过了")
	var cash0: int = town.world.cash()
	var stamina0: int = int(_home()["stamina"])
	# ---- 第一次：训诫
	_pin()
	var o1: Dictionary = await _trip("德厚当", "米行", 1270)
	var t1: Dictionary = o1["trip"]
	c.check(t1["stopped"] and t1["kind"] == "warn" and t1["proceed"] and not t1["go_home"] and not t1["night_over"], "第一次：训诫，放你过去")
	c.check(int(t1["extra_minutes"]) == int(Curfew.config()["trip"]["delay_minutes"]["warn"]), "耽搁了几分钟（%d）" % int(t1["extra_minutes"]))
	c.check(int(_home()["stamina"]) < stamina0, "夜里走一趟，体力耗了一点（%d → %d）" % [stamina0, int(_home()["stamina"])])
	c.check(o1["options"].has("honest") and o1["options"].has("explain") and o1["options"].has("flee"), "选项：认错 / 解释 / 跑")
	c.check(not o1["options"].has("pass"), "没有良民证，就没有“出示良民证”")
	c.check("|".join(o1["labels"]).find("塞几个钱") >= 0, "塞钱的选项标着数目")
	var said := "|".join(o1["texts"])
	c.check(said.find("站住") >= 0 and said.find("记着") >= 0, "巡夜的开口，头一回只是训诫")
	c.check(int(_st()["offences"]) == 1 and _notes_have("训诫") and town.world.cash() == cash0, "违规 1，档案簿里记了一笔，没罚钱")
	# 刚被拦过：一阵子不会再拦（就算这一签中了）
	_pin()
	var quiet: Dictionary = await _trip("德厚当", "米行", 1280)
	c.check(not quiet["trip"]["stopped"] and quiet["trip"]["active"], "刚被拦过，巡夜的一阵子不会再拦")
	# ---- 第二次：罚洋
	_pin()
	var o2: Dictionary = await _trip("德厚当", "米行", 1330)
	var r2: Dictionary = town.curfew.last_result
	c.check(o2["trip"]["kind"] == "fine" and o2["trip"]["proceed"], "第二次：罚洋，放你过去")
	var fine: int = int(r2["fine"])
	c.check(fine >= 5 and fine <= 20, "罚洋在 5~20 蚨之间（%d）" % fine)
	c.check(cash0 - town.world.cash() == fine, "钱匣里少了正好那么多")
	var fb: Dictionary = _fine_bill()
	c.check(not fb.is_empty() and str(fb["status"]) == "paid" and str(fb["payee"]) == "维持会公账" and int(fb["amount"]) == fine, "罚洋走了账：付给维持会公账")
	c.check(town.world.ledger.check_invariants().is_empty(), "账本不变量没破")
	c.check(int(_st()["offences"]) == 2 and "|".join(o2["texts"]).find("第二回") >= 0, "违规 2，巡夜的认得你了")
	c.check(_notes_have("罚了"), "档案簿里记了一笔")
	# ---- 第三次：押回
	var koubei_pre: int = town.world.koubei
	var cap := {"minute": -1, "t": "", "koubei": -1}
	town.day_started.connect(func(_d):
		cap["minute"] = town.minute
		cap["koubei"] = town.world.koubei
		for m in town._open_modals:
			if is_instance_valid(m):
				cap["t"] += _labels_in(m)
		, CONNECT_ONE_SHOT)
	_pin()
	var o3: Dictionary = await _trip("德厚当", "米行", 1400)
	var t3: Dictionary = o3["trip"]
	c.check(t3["kind"] == "detain" and not t3["proceed"] and t3["night_over"], "第三次：押回家，这一趟取消，这一夜到此为止")
	c.check("|".join(o3["texts"]).find("跟我走") >= 0, "“跟我走”")
	c.check(bool(_st()["detained_next"]) and int(_st()["detentions"]) == 1, "记下了：被押回过一回")
	c.check(float(town.world.town.s["pressures"]["heat"]) > 0.0, "热度涨了：马保长那边有数了")
	c.check(town.world.town.s["known"].has("ma") and town.world.town.s["known"]["ma"].has("curfew_caught"), "马保长听说了")
	var ok: bool = await _sleep_through()
	c.check(ok and town.world.day == 2, "押回之后这一夜立刻过去，第二天开始了（day=%d）" % town.world.day)
	c.check(int(cap["minute"]) == 540, "第二天九点才起（%d）" % int(cap["minute"]))
	var stamina_after: int = int(_home()["stamina"])
	c.check(stamina_after <= 100 - int(Curfew.config()["detain"]["stamina"]), "人也乏：体力低了（%d）" % stamina_after)
	c.check(str(cap["t"]).find("昨夜") >= 0 and str(cap["t"]).find("押回") >= 0, "告示上写着昨夜的事")
	c.check(not bool(_st()["detained_next"]) and not bool(_st()["morning"]), "说过一回就不再说")
	c.check(_notes_have("押回了德厚当"), "档案簿里有这一笔")
	c.check(town.world.ledger.check_invariants().is_empty(), "过夜之后账本不变量没破")
	# 流言传到街坊：口碑 −2，只记一次
	var spread := false
	for npc in town.world.town.s["known"]:
		if str(npc) != "ma" and town.world.town.s["known"][npc].has("curfew_caught"):
			spread = true
	c.check(bool(_st()["rumors"][0]["applied"]) == spread, "流言传到街坊耳朵里没有：%s，口碑记没记也一致" % str(spread))
	if spread:
		c.check(int(cap["koubei"]) == koubei_pre - 2, "传开了：口碑 −2（%d → %d）" % [koubei_pre, int(cap["koubei"])])
	else:
		c.check(int(cap["koubei"]) == koubei_pre, "没传开：口碑不动（%d）" % int(cap["koubei"]))
		town.world.town.s["known"]["zhouma"] = {"curfew_caught": {"hops": 1, "conf": 0.6, "via": "ma", "at": 0, "root": "x", "origin": 0}}
		town.curfew._check_rumor_spread()
		c.check(town.world.koubei == int(cap["koubei"]) - 2 and bool(_st()["rumors"][0]["applied"]), "（让它传到周妈那儿）口碑 −2")
	var koubei_now: int = town.world.koubei
	town.curfew._check_rumor_spread()
	c.check(town.world.koubei == koubei_now, "同一桩只记一次")
	await _end()

func _s_resolve() -> void:
	print("-- 处置：塞钱走账本、良民证、解释、跑、欠账、淡忘")
	await _boot(9)
	town.skip_to(1262)
	await _settle()
	var cf = town.curfew
	var led = town.world.ledger
	var day: int = town.world.day
	var p0: float = cf.bribe_accept_chance(0)
	# ---- 塞钱：收下
	var ka: int = _find_k("curfew_bribe", func(u): return u < p0)
	var ctx: Dictionary = _ctx(ka)
	c.check(bool(ctx["can_bribe"]) and int(ctx["bribe"]) >= 3 and int(ctx["bribe"]) <= 6, "头一回塞钱的数目是几个蚨（%d）" % int(ctx["bribe"]))
	var cash_a: int = town.world.cash()
	var bao_a: int = led.balance("保安队")
	var res: Dictionary = cf.resolve("bribe", ctx)
	c.check(res["kind"] == "bribed", "塞钱：收下了")
	c.check(cash_a - town.world.cash() == int(ctx["bribe"]) and led.balance("保安队") - bao_a == int(ctx["bribe"]), "钱从钱匣走到了保安队的账上")
	var j: Dictionary = led.journal.back()
	c.check(str(j["from"]) == "player" and str(j["to"]) == "保安队" and int(j["amount"]) == int(ctx["bribe"]), "流水里记着这一笔")
	c.check(int(_st()["offences"]) == 0 and int(_st()["bribes"]) == 1, "收了钱就不记违规")
	c.check(led.check_invariants().is_empty(), "账本不变量没破（蚨总量守恒）")
	# ---- 塞钱：不收
	var kr: int = _find_k("curfew_bribe", func(u): return u >= p0)
	ctx = _ctx(kr)
	bao_a = led.balance("保安队")
	res = cf.resolve("bribe", ctx)
	c.check(res["via"] == "bribe_refused" and led.balance("保安队") == bao_a, "塞钱：不收，钱没动")
	c.check(int(res["tier"]) == 2 and int(_st()["offences"]) == 1, "不收还要加重一级：直接罚洋")
	c.check(led.check_invariants().is_empty(), "账本不变量没破")
	_st()["offences"] = 0
	# ---- 良民证
	c.check(not cf.has_pass(), "还没办良民证")
	_give_pass()
	c.check(cf.has_pass(), "付清了良民证的钱：有证")
	ctx = _ctx(50)
	c.check(bool(ctx["has_pass"]), "（拦下时知道有证）")
	res = cf.resolve("pass", ctx)
	c.check(res["kind"] == "released" and int(_st()["offences"]) == 0, "亮证：头一回放行，不记名")
	_st()["offences"] = 1
	res = cf.resolve("pass", _ctx(51))
	c.check(res["kind"] == "warn" and int(_st()["offences"]) == 2, "有证的第二回：只是训诫（比没证轻一级）")
	_st()["offences"] = 2
	res = cf.resolve("pass", _ctx(52))
	c.check(res["kind"] == "fine", "有证的第三回：罚洋，不押")
	_st()["offences"] = 0
	# ---- 解释
	var home: Dictionary = _home()
	c.check(cf.reason() == "", "眼下没有说得通的缘由")
	var kd: int = _find_k("curfew_doubt", func(u): return u < 0.2)
	res = cf.resolve("explain", _ctx(kd))
	c.check(res["via"] == "doubted" and res["kind"] == "released" and int(_st()["offences"]) == 0, "没有缘由，碰巧被半信半疑放过")
	var kn: int = _find_k("curfew_doubt", func(u): return u >= 0.2)
	res = cf.resolve("explain", _ctx(kn))
	c.check(res["via"] == "doubted" and res["kind"] == "warn" and int(_st()["offences"]) == 1, "没有缘由：不信，照次数处置")
	_st()["offences"] = 0
	home["illness"] = 1
	c.check(cf.reason() == "illness", "家里有人病着：说得通")
	res = cf.resolve("explain", _ctx(70))
	c.check(res["kind"] == "excused" and int(_st()["offences"]) == 0 and int(_st()["excused"]) == 1, "给病人抓药：放行，不记违规")
	home["illness"] = 0
	town.director.vars["town"]["invitations"]["t1"] = {"status": "pending", "due_day": day, "who": "zhouma"}
	c.check(cf.reason() == "invitation", "今天有人请：说得通")
	town.director.vars["town"]["invitations"]["t1"]["due_day"] = day + 3
	c.check(cf.reason() == "", "请帖是几天后的：说不通")
	town.director.vars["town"]["invitations"].erase("t1")
	# ---- 跑
	var fc: float = cf.flee_chance(0)
	var heat0: float = float(town.world.town.s["pressures"]["heat"])
	var kf: int = _find_k("curfew_flee", func(u): return u < fc)
	res = cf.resolve("flee", _ctx(kf))
	c.check(res["kind"] == "fled" and int(_st()["offences"]) == 0, "跑掉了：不记违规")
	c.check(float(town.world.town.s["pressures"]["heat"]) > heat0 and town.world.town.s["known"]["ma"].has("curfew_seen"), "但被人瞥见了：热度涨一点、有了闲话")
	var kx: int = _find_k("curfew_flee", func(u): return u >= fc)
	res = cf.resolve("flee", _ctx(kx))
	c.check(res["kind"] == "detain" and res["via"] == "flee_fail" and int(_st()["offences"]) == 1 and bool(_st()["detained_next"]), "没跑掉：直接押回")
	_st()["detained_next"] = false
	_st()["offences"] = 0
	home["stamina"] = 10
	c.check(cf.flee_chance(0) < fc, "累了更难跑掉")
	home["stamina"] = 100
	# ---- 没带够钱：罚洋记成欠账
	var cash_all: int = town.world.cash()
	led.transfer("player", "米行", cash_all - 2, "（测试）把钱花光")
	_st()["offences"] = 1
	res = cf.resolve("honest", _ctx(90))
	var owed: Dictionary = _bill_by("bill:curfew_fine:d%d:e90" % day)
	c.check(res["kind"] == "fine_unpaid" and not owed.is_empty(), "钱不够：罚洋记成欠账")
	c.check(str(owed.get("status")) == "due" and int(owed.get("paid", -1)) == 0 and str(owed.get("payee")) == "维持会公账" and str(owed.get("building")) == "baogong" and int(owed.get("due_day")) == day + 1, "欠的是保公所的账，明天到期")
	c.check(town.world.cash() == 2, "钱匣没动")
	c.check(town.world.town.bills().any(func(b): return str(b["id"]) == "bill:curfew_fine:d%d:e90" % day), "晨间告示的账单里看得见")
	led.transfer("米行", "player", cash_all - 2, "（测试）钱回来")
	var paid: Dictionary = town.world.town.pay_bill(str(owed["id"]), int(owed["amount"]), "test|pay_owed")
	c.check(bool(paid["ok"]) and str(_bill_by(str(owed["id"]))["status"]) == "paid", "凑到钱去保公所能结清")
	c.check(led.check_invariants().is_empty(), "账本不变量没破")
	# ---- 押回：有剧情夜的日子，剧情照旧；平常的夜，这一夜作罢
	_st()["offences"] = 2
	town.director.vars["town"].erase("night_done")
	res = cf.resolve("honest", _ctx(95))
	c.check(res["kind"] == "detain" and int(town.director.vars["town"].get("night_done", -1)) != day, "第一天夜里有剧情：押回了，剧情夜照旧")
	_st()["detained_next"] = false
	town.world.day = 4
	_st()["offences"] = 2
	res = cf.resolve("honest", _ctx(96))
	c.check(res["kind"] == "detain" and int(town.director.vars["town"].get("night_done", -1)) == 4, "平常的夜：被押回就没有夜里的自由活动了")
	town.world.day = day
	_st()["detained_next"] = false
	# ---- 旧账淡忘
	_st()["offences"] = 2
	_st()["last_offence_day"] = day - 6
	cf.on_day_start({})
	c.check(int(_st()["offences"]) == 2, "六天不够忘")
	_st()["last_offence_day"] = day - 7
	cf.on_day_start({})
	c.check(int(_st()["offences"]) == 1 and int(_st()["last_offence_day"]) == day, "隔了七天：少记一次")
	c.check(town.world.flags.get("town_mode", false), "小镇版的标记在（d2_ma 里的宵禁提醒认这个）")
	await _end()

func _s_ui_picks() -> void:
	print("-- 经由界面选：塞钱、亮证、解释、跑")
	await _boot(11)
	town.skip_to(1262)
	await _settle()
	var cf = town.curfew
	var led = town.world.ledger
	var p0: float = cf.bribe_accept_chance(0)
	# ---- 塞钱（收下）
	_pin("curfew_bribe", func(u): return u < p0)
	var cash0: int = town.world.cash()
	var bao0: int = led.balance("保安队")
	var out: Dictionary = await _trip("德厚当", "米行", 1270, "bribe")
	var res: Dictionary = cf.last_result
	c.check(out["options"].has("bribe") and "|".join(out["labels"]).find("塞几个钱（%d 蚨）" % int(res["bribe"])) >= 0, "选项上写明了塞多少")
	c.check(res["kind"] == "bribed" and out["trip"]["proceed"], "塞钱：收下了，这一趟照走")
	c.check(cash0 - town.world.cash() == int(res["bribe"]) and led.balance("保安队") - bao0 == int(res["bribe"]), "走的账本，蚨一个不多一个不少")
	c.check("|".join(out["texts"]).find("什么都没看见") >= 0 and int(_st()["offences"]) == 0, "巡夜的装没看见，不记违规")
	c.check(led.check_invariants().is_empty(), "账本不变量没破")
	# ---- 亮证
	_give_pass()
	_st()["quiet_until"] = 0
	_pin()
	out = await _trip("德厚当", "米行", 1400, "pass")
	c.check(out["options"].has("pass"), "办了良民证：多了“出示良民证”")
	c.check(cf.last_result["kind"] == "released" and "|".join(out["texts"]).find("证是真的") >= 0 and int(_st()["offences"]) == 0, "亮证：放行，不记名")
	# ---- 解释
	_home()["illness"] = 1
	_st()["quiet_until"] = 0
	_pin()
	out = await _trip("德厚当", "米行", 1405, "explain")
	c.check(cf.last_result["kind"] == "excused" and "|".join(out["texts"]).find("病人") >= 0 and int(_st()["offences"]) == 0, "家里有病人：解释说得通，放行")
	_home()["illness"] = 0
	# ---- 跑（成功）：回铺子里
	var fc: float = cf.flee_chance(0)
	_st()["quiet_until"] = 0
	_pin("curfew_flee", func(u): return u < fc)
	out = await _trip("德厚当", "码头", 1410, "flee")
	c.check(cf.last_result["kind"] == "fled" and out["trip"]["go_home"] and not out["trip"]["proceed"], "跑掉了：这一趟取消，回家")
	c.check(int(_st()["offences"]) == 0 and not out["trip"]["night_over"], "不记违规，夜还长着")
	# ---- 跑（失败）：押回
	_st()["quiet_until"] = 0
	_pin("curfew_flee", func(u): return u >= fc)
	out = await _trip("德厚当", "码头", 1415, "flee")
	c.check(cf.last_result["kind"] == "detain" and cf.last_result["via"] == "flee_fail" and out["trip"]["night_over"], "没跑掉：押回")
	var ok: bool = await _sleep_through()
	c.check(ok and town.world.day == 2, "押回之后这一夜过去，第二天开始")
	await _end()

func _trace_run(seed_v: int) -> Dictionary:
	await _boot(seed_v)
	town.skip_to(1262)
	await _settle()
	var kinds: Array = []
	var fines: Array = []
	var dests := ["米行", "码头", "集市", "茶馆", "米行", "济生堂", "码头", "集市", "米行", "茶馆", "孙府", "码头"]
	var m := 1270
	for d in dests:
		_st()["quiet_until"] = 0
		var o: Dictionary = await _trip("德厚当", d, m)
		kinds.append(str(o["trip"]["kind"]))
		if o["trip"]["stopped"]:
			fines.append(int(town.curfew.last_result["fine"]))
		m += 7
		if o["trip"]["night_over"]:
			break
	var out := {"trace": town.curfew.trace.duplicate(true), "kinds": kinds, "fines": fines,
		"cash": town.world.cash(), "seed": _seed(), "day": town.world.day, "stamina": int(_home()["stamina"])}
	await _end()
	return out

func _s_determinism() -> void:
	print("-- 同一局同样的走法：同样的结果")
	var a: Dictionary = await _trace_run(14)
	var b: Dictionary = await _trace_run(14)
	var d: Dictionary = await _trace_run(15)
	c = Common.new(self)
	var stops := 0
	for k in a["kinds"]:
		if k != "" and k != "told":
			stops += 1
	c.check((a["trace"] as Array).size() >= 6 and stops >= 1, "有抽签记录（%d 趟），也有被拦的（%d 次）" % [(a["trace"] as Array).size(), stops])
	c.check(a["trace"] == b["trace"] and a["kinds"] == b["kinds"] and a["fines"] == b["fines"], "同一个种子：每一趟的概率、抽签、处置完全一样")
	c.check(a["cash"] == b["cash"] and a["stamina"] == b["stamina"], "花掉的钱、耗掉的体力都一样")
	c.check(a["trace"] != d["trace"], "换个种子就不一样了")
	var all_match := true
	for row in a["trace"]:
		if float(row["u"]) >= 0.0:
			var u: float = R.draw(int(a["seed"]), "curfew_trip", [int(row["day"]), int(row["idx"])])
			if absf(u - float(row["u"])) > 0.00002:
				all_match = false
	c.check(all_match, "每一签都是（种子、天、第几趟）的函数，不是随机数")
	var sequential := true
	for i in (a["trace"] as Array).size():
		if int(a["trace"][i]["idx"]) != i:
			sequential = false
	c.check(sequential, "序号一趟一趟往上数")
	failures_total += c.failures

func _s_save() -> void:
	print("-- 存档读档：违规次数还在，趟数序号接着走")
	await _boot(8)
	town.skip_to(1262)
	await _settle()
	_pin()
	await _trip("德厚当", "米行", 1270)
	c.check(int(_st()["offences"]) == 1 and town.curfew.last_result["kind"] == "warn", "先被训诫了一回")
	var path: String = TownGame.scratch_save_path("curfew_test")
	var trips: Dictionary = _st()["trips"].duplicate(true)
	var told: Array = (_st()["told_by"] as Array).duplicate()
	var minute0: int = town.minute
	c.check(town.save_game(path), "存档")
	var ok: bool = await town.load_game(path)
	_attach(c)
	c.check(ok, "读档（继续）")
	c.check(int(_st()["offences"]) == 1 and int(_st()["stops"]) == 1, "违规次数、被拦次数还在")
	c.check(_st()["trips"] == trips and _st()["told_by"] == told and town.world.pages.has("curfew"), "趟数序号、谁说过规矩、知识页都还在")
	c.check(town.minute == minute0, "回到存档时的钟点")
	_pin()
	_st()["quiet_until"] = 0
	await _trip("德厚当", "米行", 1400)
	c.check(int(_st()["offences"]) == 2 and town.curfew.last_result["kind"] == "fine", "接着往下加重：第二回是罚洋")
	var first_idx: int = int(town.curfew.trace.front()["idx"])
	c.check(first_idx >= int(trips[str(town.world.day)]), "趟数序号是接着上次的（%d），不是从头来" % first_idx)
	TownGame.remove_save_files(path)
	await _end()

func _s_board() -> void:
	print("-- 告示墙上的宵禁告示")
	await _boot(3)
	c.check(not town.world.pages.has("curfew"), "开局没有宵禁这一页")
	town.show_board()
	var panel = town._open_modals.back()
	var txt: String = _labels_in(panel)
	c.check(txt.find("维持会告示") >= 0 and txt.find("戌时") >= 0 and txt.find("晚九点") >= 0 and txt.find("屋内无妨") >= 0, "告示上贴着维持会的宵禁告示")
	c.check(txt.find("初次训诫") >= 0 and txt.find("再犯，罚洋") >= 0 and txt.find("屡犯，带回问话") >= 0, "写明了初次训诫、再犯罚洋、屡犯带回问话")
	c.check(town.world.pages.has("curfew") and _st()["told_by"].has("board"), "看过告示：知识页解锁")
	c.check(_notes_have("告示墙上贴着维持会的宵禁告示"), "档案簿里记了一笔")
	var first_child: Node = (panel.body as Node).get_child(1)
	c.check(first_child is PanelContainer, "告示贴在最上头")
	town.dismiss_modals()
	await _end()

func _s_ma() -> void:
	print("-- 马保长第二天傍晚提宵禁（d2_ma 里的一行钩子）")
	await _boot(4)
	town.skip_to(1100)
	c.check(town.sleep(), "睡下，过到第二天")
	var ok: bool = await _sleep_through()
	c.check(ok and town.world.day == 2, "第二天了")
	c.check(town.world.flags.get("town_mode", false), "小镇版标记在")
	c.check(not town.world.pages.has("curfew"), "（还没人提过宵禁）")
	town.skip_to(1125)
	var visit := {}
	for v in town.director.town_visits():
		if str(v["id"]) == "story_d2_ma":
			visit = v
	c.check(not visit.is_empty(), "马保长傍晚上门")
	_from = beats.size()
	await town.start_counter(visit)
	var said := ""
	for row in beats.slice(_from):
		said += str(row["text"]) + "|"
	c.check(said.find("九点以后镇上宵禁") >= 0 and said.find("提着灯笼巡夜") >= 0, "马保长顺口说了宵禁")
	c.check(said.find("维持费") >= 0, "他原本的话还在（维持费）")
	c.check(town.world.pages.has("curfew") and bool(town.world.flags.get("curfew_told_ma", false)), "知识页解锁")
	c.check(town.curfew.is_told(), "算说过规矩了")
	await _end()

func _s_cold() -> void:
	print("-- 夜里出一趟门，人要冷：路越远耗得越多")
	await _boot(6)
	_skip_brother()
	_st()["told"] = true
	town.skip_to(1262)
	_st()["quiet_day"] = town.world.day
	_st()["quiet_until"] = 9999            # 不让巡夜的插进来，只看体力
	var s0: int = int(_home()["stamina"])
	await town.curfew.check_trip("德厚当", "茶馆", 1270)
	c.check(int(_home()["stamina"]) == s0 - 2, "隔壁一趟：体力 −2（%d → %d）" % [s0, int(_home()["stamina"])])
	c.check(_toast_text().find("风冷") >= 0, "提示：风冷")
	await town.curfew.check_trip("德厚当", "码头", 1280)
	c.check(int(_home()["stamina"]) == s0 - 2 - 4, "过桥到码头：再 −4（现在 %d）" % int(_home()["stamina"]))
	var before: int = int(_home()["stamina"])
	await town.curfew.check_trip("德厚当", "码头", 600)
	c.check(int(_home()["stamina"]) == before, "白天走一趟不冷")
	await _end()

# 夜里从铺子出门走“去哪儿”：打开地图不算一趟；选定去处才交给 check_trip。天黑了店关着就出不去。
func _s_door() -> void:
	print("-- 去哪儿：夜里选定去处才算一趟")
	await _boot(7)
	town.world.town.pack["buildings"]["teahouse"]["hours"] = [360, 1500]
	town.skip_to(1100)
	await _settle()
	var door: Dictionary = town.world_view.map.door_to_map("town")
	c.check(not door.is_empty() and town.map_id == "pawnshop", "在铺子里，前门通向去哪儿")
	await town._try_door(door)
	await c.frames(3)
	c.check(town.travel_panel != null and town.map_id == "pawnshop", "打开去哪儿，人还在铺子里")
	c.check(int(_st()["trips"].get(str(town.world.day), 0)) == 0, "光打开地图不算一趟")
	town.dismiss_modals()
	await c.until_idle()
	town.skip_to(1262)
	await _settle()
	_st()["told"] = true
	var day_key := str(town.world.day)
	var before := int(_st()["trips"].get(day_key, 0))
	# 关着的地方点了也不出门
	town.world.town.pack["buildings"]["ricehall"]["hours"] = [360, 1080]
	var m_closed: int = town.minute
	await town.travel_to("ricehall")
	await c.until_idle(400)
	c.check(not town.shop_view.is_open and town.map_id == "pawnshop", "打烊的米行去不了")
	c.check(int(_st()["trips"].get(day_key, 0)) == before and town.minute == m_closed, "没出门：不记巡夜，钟也不走")
	# 茶馆夜里仍开着（只这一段测试把时辰放宽）：撞上训诫，耽搁之后还是到了
	_st()["quiet_day"] = town.world.day
	_st()["quiet_until"] = 0
	var pinned := _pin()
	c.ap.choice_queue = ["honest"]
	var m0: int = town.minute
	await town.travel_to("teahouse")
	await c.until(func(): return town.shop_view.is_open, 900)
	c.check(town.shop_view.is_open and town.map_id == "pawnshop", "被训诫之后还是到了茶馆，人没走到街上")
	c.check(town.minute >= m0 + int(Curfew.config()["trip"]["delay_minutes"]["warn"]), "路上耽搁了几分钟")
	c.check(int(_st()["trips"].get(day_key, 0)) == pinned + 1, "这一趟记了一笔")
	# 回来再记一趟。先安静，免得又被拦
	_st()["quiet_until"] = 9999
	var mid := int(_st()["trips"].get(day_key, 0))
	town.shop_view.close_shop()
	await c.until_idle(900)
	c.check(town.map_id == "pawnshop" and not town.shop_view.is_open, "从茶馆回来，人在铺子里")
	c.check(int(_st()["trips"].get(day_key, 0)) == mid + 1, "夜里回来也记一趟")
	# 再出门，跑掉：店没进成
	_st()["quiet_until"] = 0
	var fc: float = town.curfew.flee_chance(int(_st()["offences"]))
	_pin("curfew_flee", func(u): return u < fc)
	c.ap.choice_queue = ["flee"]
	await town.travel_to("teahouse")
	await c.until_idle(900)
	c.check(town.map_id == "pawnshop" and not town.shop_view.is_open and town.curfew.last_result["kind"] == "fled", "跑掉了：这一趟没出成，人还在铺子里")
	await _end()

func _run() -> void:
	var only := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			only = a.substr(7)
	var plan := {
		"data": _s_data, "inside": _s_inside_and_brother, "far": _s_far_brother, "chance": _s_chance, "first": _s_first_trip,
		"ladder": _s_ladder, "resolve": _s_resolve, "picks": _s_ui_picks, "determinism": _s_determinism, "save": _s_save,
		"board": _s_board, "ma": _s_ma, "cold": _s_cold, "door": _s_door,
	}
	for key in plan:
		if only == "" or only == key:
			await (plan[key] as Callable).call()
	print("RESULT: ", "OK" if failures_total == 0 else "FAILED (%d)" % failures_total)
	quit(0 if failures_total == 0 else 1)
