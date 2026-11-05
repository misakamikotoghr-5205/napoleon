# [shop-only] 过路客人与门口吆喝（v0.4.2，设计 docs/town/DESIGN_walkin.md；代码 scripts/core/walkin.gd）的无头测试。
# 真导演、真小镇模拟，不开界面：时钟一分钟一分钟地走（和 town_game.advance_minute 一样，先 set_minute 再 walkin().tick()），
# 柜台上的议价交给 town_play_policy 的 town_fair 玩家。
# 查：时刻表确定、只看种子和日期；第 1 天没人自己进门、但哥哥交代完以后吆喝叫得来；断客日、出门版没有过路客人；店里站满不进门；
# ID/身份各有命名空间；白天存档→读档不重排、不重复进门；吆喝（提前叫下一位、按种类定来意、各种不成、request_id 去重；
# 路上的人也算进店里的人数，叫来的人到门口店里满了照样进门；架上没一样过路的人看得上，吆喝卖货灰着）；
# 买主只从当时架上挑买得起的；货没了改挑（先说出原先看中的那件），挑不到就体面地走（账上不动）；成交记账、钱货两清；外生隔离；
# 货架只看不卖（自己账上的数）、夜里不夜卖、夜里对账和整理库房不露市价、日结合成一行、立绘、给玩家看的字里没有隐藏的数。
# godot --headless -s res://scripts/tests/test_walkin.gd    （失败退出码 1）
extends SceneTree

const Director = preload("res://scripts/core/director.gd")
const Player = preload("res://scripts/tests/town_play_policy.gd")
const Save = preload("res://scripts/core/save.gd")
const Walkin = preload("res://scripts/core/walkin.gd")
const Items = preload("res://scripts/sim/item_gen.gd")
const Rules = preload("res://scripts/town/rules.gd")
const TownData = preload("res://scripts/town/town_data.gd")
const CounterView = preload("res://scripts/ui/counter_view.gd")
const ShelfPanel = preload("res://scripts/town/shelf_panel.gd")

# 货架面板只要 game.director / toast / refresh_hud：不开整个界面也能把面板搭出来看字
class FakeGame:
	var director
	func toast(_text: String, _secs: float = 0.0) -> void:
		pass
	func refresh_hud() -> void:
		pass

var failures: Array = []
var checks: int = 0
var started: int = 0
var running: bool = true
var players: Array = []          # 柜台上的玩家（RefCounted，留着引用才不会被释放）
var directors: Array = []
var beats: Array = []            # 录下来的对白、柜台（看“没货走人”有没有卡在柜台上）

func _initialize() -> void:
	started = Time.get_ticks_msec()
	_test_schedule()
	_test_quiet_days()
	_test_cap_and_ids()
	_test_save_resume()
	_test_calls()
	_test_call_cap()
	_test_no_buyer()
	await _test_buyer_repick()
	await _test_nostock()
	await _test_exogenous()
	await _test_shelf_night_text()
	await _test_night_no_market()
	running = false
	_finish()

func _process(_delta: float) -> bool:
	if running and started > 0 and Time.get_ticks_msec() - started > 280000:
		failures.append("280 秒看门狗：协程卡住了")
		running = false
		_finish()
	return false

func _finish() -> void:
	for p in players:
		if p.director.beat.is_connected(p._on_beat):
			p.director.beat.disconnect(p._on_beat)
	players.clear()
	for d in directors:
		if is_instance_valid(d):
			d.queue_free()
	directors.clear()
	await process_frame
	DB.shutdown()
	Walkin.clear()
	for f in failures:
		print("FAIL: ", f)
	print("RESULT: %s（%d 项检查，%d 项失败）" % ["PASS" if failures.is_empty() else "FAIL", checks, failures.size()])
	quit(0 if failures.is_empty() else 1)

func _check(ok: bool, what: String) -> void:
	checks += 1
	if ok:
		print("PASS: ", what)
	else:
		failures.append(what)

# ====================================================================
# 小工具
func _new(seed: int, shop_only: bool = true, with_player: bool = false):
	var d = Director.new()
	root.add_child(d)
	directors.append(d)
	d.setup_town(seed, "常年", shop_only)
	d.town_action("prologue_done")
	if with_player:
		players.append(Player.new(d, "town_fair", seed))
	return d

# 开到第 day 天（今天没收的先收了）
func _goto_day(d, day: int) -> void:
	while true:
		var ended: bool = bool(d.world.town.s.get("day_ended", true))
		if not ended and d.world.day >= day:
			return
		if not ended:
			_close_day(d)
		d.town_start_day()

# 收工。测试夹具：今天没人接的收保护费的那一笔记作“不算”，免得一路升到断客（断客日单独测）
func _close_day(d) -> void:
	var e: Dictionary = d.protect().entry()
	if not e.is_empty() and str(e.get("status", "")) == "pending":
		e["status"] = "skipped"
	d.town_finish_day()

# 一分钟一分钟地走：返回这段时间里进门的过路客人
func _tick_to(d, minute: int) -> Array:
	var came: Array = []
	while int(d.world.town.s["minute"]) < minute:
		d.world.town.set_minute(int(d.world.town.s["minute"]) + 1)
		came.append_array(d.walkin().tick())
	return came

func _now(d) -> int:
	return int(d.world.town.s["minute"])

func _walkins(d) -> Array:
	var out: Array = []
	for v in d.world.town.s["visits"]:
		if Walkin.is_walkin(v):
			out.append(v)
	return out

func _find(d, vid: String) -> Dictionary:
	for v in d.world.town.s["visits"]:
		if str(v.get("id", "")) == vid:
			return v
	return {}

func _rows(d) -> String:
	var out: Array = []
	for v in _walkins(d):
		out.append([str(v["id"]), str(v["who"]), str(v["intent"]), int(v["minute"]), int(v["patience_min"]), str(v.get("called", ""))])
	return JSON.stringify(out)

# 过一遍 JSON（读档后的整数会变成浮点）再比
func _canon(value) -> String:
	return JSON.stringify(JSON.parse_string(JSON.stringify(value)))

func _shelf_defs(d) -> Array:
	var out: Array = []
	for row in d._town_shelf():
		out.append(str(d.world.ledger.items[str(row["iid"])].get("def_id", "")))
	return out

func _iid_of(d, def_id: String) -> String:
	for row in d._town_shelf():
		if str(d.world.ledger.items[str(row["iid"])].get("def_id", "")) == def_id:
			return str(row["iid"])
	return ""

# 搭一块货架面板，收它上面的字和按钮
func _panel_texts(d) -> Dictionary:
	var game := FakeGame.new()
	game.director = d
	var p = ShelfPanel.new()
	p.build(game)
	var texts: Array = []
	var buttons: Array = []
	var stack: Array = [p]
	while not stack.is_empty():
		var node = stack.pop_back()
		if node is Button:
			buttons.append(str(node.text))
		elif node is Label:
			texts.append(str(node.text))
		stack.append_array(node.get_children())
	p.free()
	return {"text": "\n".join(texts), "buttons": buttons}

func _none() -> int:
	return 0

func _three() -> int:
	return int(Walkin.config().get("max_waiting", 3))

func _two() -> int:
	return int(Walkin.config().get("max_waiting", 3)) - 1

func _record(beat: Dictionary) -> void:
	beats.append({"type": str(beat.get("type", "")), "text": str(beat.get("text", "")), "who": str(beat.get("who", "")),
		"actions": beat.get("actions", []).duplicate(true) if beat.get("actions", []) is Array else [],
		"stock": beat.get("stock", []).duplicate(true) if beat.get("stock", []) is Array else [],
		"iids": beat.get("iids", []).duplicate(true) if beat.get("iids", []) is Array else []})

func _exogenous(sim) -> String:
	var pressures: Dictionary = {}
	for key in sim.pack["pressures"]:
		if str(sim.pack["pressures"][key]["kind"]) == "exogenous":
			pressures[key] = sim.s["pressures"][key]
	var wheels: Array = []
	for row in sim.s["day_report"].get("wheels", []):
		if str(row["mode"]) == "exogenous":
			wheels.append(row.duplicate(true))
	return JSON.stringify({"weather": sim.s["weather"], "pressures": pressures, "wheels": wheels,
		"rice": sim.price("rice"), "medicine": sim.price("medicine")}, "", true, true)

# 叫一位想买货的进门（吆喝卖货），返回他的来访
func _call_buyer(d) -> Dictionary:
	var r: Dictionary = d.town_action("walkin_call", {"kind": "buy"})
	if not bool(r.get("ok", false)):
		return {}
	var vid := Walkin.visit_id(int(d.world.day), int(r["n"]))
	_tick_to(d, _now(d) + int(Walkin.config()["call_delay"][1]))
	return _find(d, vid)

# ====================================================================
func _test_schedule() -> void:
	var a = _new(11)
	var b = _new(11)
	var c = _new(12)
	var cfg: Dictionary = Walkin.config()
	var lo := int(cfg["gap_range"][0])
	var hi := int(cfg["gap_range"][1])
	var open := int(cfg["open_minute"])
	var last := int(cfg["last_minute"])
	var same := true
	var differs := false
	var bounds := true
	var filled := true
	for day in range(2, 16):
		var sa: Array = a.walkin().schedule(day)
		if JSON.stringify(sa) != JSON.stringify(b.walkin().schedule(day)):
			same = false
		if JSON.stringify(sa) != JSON.stringify(c.walkin().schedule(day)):
			differs = true
		var prev := open
		for slot in sa:
			var t := int(slot["at"])
			if t - prev < lo or t - prev > hi or t < open or t > last or int(slot["minute"]) != t:
				bounds = false
			prev = t
		if sa.is_empty() or last - prev >= hi:
			filled = false
	_check(same, "时刻表：同一个种子、同一天永远一样")
	_check(differs, "时刻表：换个种子就不一样")
	_check(bounds, "时刻表：从开门起每隔 %d–%d 分钟一位，都在 %d–%d 之间" % [lo, hi, open, last])
	_check(filled, "时刻表：一直排到收工前（最后一位之后再没有空当排得下一位）")
	_goto_day(a, 2)
	_goto_day(c, 2)
	_check(JSON.stringify(a.walkin().st()["slots"]) == JSON.stringify(a.walkin().schedule(2)) and int(a.walkin().st()["day"]) == 2, "第 2 天一早按时刻表排好，存在导演账上 vars.town.walkin")
	_check(JSON.stringify(a.walkin().st()["slots"]) != JSON.stringify(c.walkin().st()["slots"]), "两个种子第 2 天排的不一样")
	var before := JSON.stringify(a.walkin().st())
	a.town_start_day()
	_check(JSON.stringify(a.walkin().st()) == before, "同一天再开一次门（读档续玩）：时刻表不重排")

func _test_quiet_days() -> void:
	var d = _new(21)
	_goto_day(d, 1)
	var w1 = d.walkin()
	w1.waiting_source = Callable(self, "_none")
	_check(str(w1.st()["quiet"]) == "calls_only" and not w1.st()["slots"].is_empty() and JSON.stringify(w1.st()["slots"]) == JSON.stringify(w1.schedule(1)), "第 1 天也排一张表，只是表上的人不自己进门（只等吆喝）")
	var shut: Dictionary = d.town_action("walkin_call", {"kind": "pawn"})
	_check(str(shut.get("error", "")) == "not_open" and str(shut.get("line", "")) == Walkin.line("call_not_open") and int(w1.st()["calls"]) == 0, "第 1 天哥哥还没交代完：吆喝不成（%s）" % Walkin.line("call_not_open"))
	d.world.flags["town_first_open"] = true          # 哥哥第一天的话交代完了（town_day1_open 末尾）
	var first_at := int(w1.st()["slots"][0]["minute"])
	_tick_to(d, first_at + 1)
	_check(_walkins(d).is_empty() and str(w1.st()["slots"][0]["status"]) == "passed" and int(w1.st()["skipped"]) == 0, "第 1 天到点的人没人吆喝，从门口走过去了（不进门、不算店里站满）")
	var r1: Dictionary = d.town_action("walkin_call", {"kind": "pawn"})
	var n1 := int(r1.get("n", -1))
	_check(bool(r1.get("ok", false)) and n1 == 1 and str(r1.get("line", "")) == Walkin.line("call_pawn"), "第 1 天哥哥交代完以后到门口吆喝：叫的是表上下一位（第 %d 位）" % n1)
	var came1 := _tick_to(d, _now(d) + int(Walkin.config()["call_delay"][1]))
	var v1 := _find(d, Walkin.visit_id(1, n1))
	_check(came1.has(Walkin.visit_id(1, n1)) and str(v1.get("called", "")) == "pawn" and str(v1.get("intent", "")) in ["pawn", "sell", "sell_stolen"], "第 1 天吆喝叫来的人进门了，来意按吆喝的种类")
	_tick_to(d, 1100)
	var passed := 0
	for slot in w1.st()["slots"]:
		if str(slot["status"]) == "passed":
			passed += 1
	_check(_walkins(d).size() == 1 and passed == w1.st()["slots"].size() - 1, "第 1 天一位过路客人也不自己进门：只有吆喝叫来的那一位（其余 %d 位走过去了）" % passed)
	var early: Dictionary = d.walkin().call_check("pawn")
	_check(str(early.get("error", "")) in ["no_walkers", "too_late"] and not bool(early.get("ok", true)), "第 1 天天黑以后吆喝没人应")
	w1.waiting_source = Callable()
	var off = _new(21, false)
	_goto_day(off, 2)
	_tick_to(off, 1100)
	_check(_walkins(off).is_empty() and not off.vars["town"].has("walkin"), "出门版（--shop-only=0）不开过路客人")
	_check(str(off.town_action("walkin_call", {"kind": "pawn"}).get("error", "")) == "walkin_off", "出门版吆喝不成")
	var bo = _new(22)
	_goto_day(bo, 2)
	_tick_to(bo, 1100)
	_check(not _walkins(bo).is_empty(), "第 2 天有过路客人进门")
	_close_day(bo)
	bo.protect().st()["boycott_day"] = 3
	bo.town_start_day()
	var w: Dictionary = bo.walkin().st()
	_check(str(w["quiet"]) == "boycott" and w["slots"].is_empty(), "断客那天（街坊绕着走）不排过路客人")
	_tick_to(bo, 700)
	var r: Dictionary = bo.town_action("walkin_call", {"kind": "pawn"})
	_check(str(r.get("error", "")) == "boycott" and str(r.get("line", "")) == Walkin.line("call_boycott"), "断客那天吆喝没人应（说的是街坊绕着走）")
	_tick_to(bo, 1100)
	var any3 := false
	for v in _walkins(bo):
		if str(v["id"]).begins_with("walkin_d3_"):
			any3 = true
	_check(not any3, "断客那天一位过路客人也不进门")

func _test_cap_and_ids() -> void:
	var cap := int(Walkin.config()["max_waiting"])
	var pr: Array = Walkin.config()["patience_range"]
	var arches: Dictionary = Walkin.config()["archetypes"]
	var d = _new(31)
	var ok_cap := true
	var ids: Dictionary = {}
	var ok_ns := true
	var count := 0
	for day in range(2, 5):
		_goto_day(d, day)
		while _now(d) < 1100:
			d.world.town.set_minute(_now(d) + 1)
			var before: int = d.walkin().waiting_now()
			var came: Array = d.walkin().tick()
			if not came.is_empty() and before + came.size() > cap:
				ok_cap = false
		for v in _walkins(d):
			count += 1
			ids[str(v["id"])] = true
			var vid := str(v["id"])
			var n := int(vid.split("_")[2])
			var arch := str(v.get("archetype", ""))
			if vid != Walkin.visit_id(day, n) or str(v["who"]) != Walkin.who_of(arch, day, n) or not arches.has(arch):
				ok_ns = false
			if str(v["storylet"]) != "" or not bool(v.get("walkin", false)) or not v["session"] is Dictionary or v["session"].is_empty():
				ok_ns = false
			if str(v["session"].get("npc", "")) != str(v["who"]) or not d.world.ledger.accounts.has(str(v["who"])):
				ok_ns = false
			if int(v["patience_min"]) < int(pr[0]) or int(v["patience_min"]) > int(pr[1]):
				ok_ns = false
		_close_day(d)
		var missed_walkins := 0
		for m in d.world.town.s["summary"].get("missed", []):
			if Walkin.is_walkin(m):
				missed_walkins += 1
		_check(missed_walkins > 0 and Walkin.summary_missed_line(missed_walkins) == "还有 %d 位过路的没等到" % missed_walkins, "第 %d 天没人接的过路客人记作错过，日结合成一行" % day)
	_check(count > 0 and ids.size() == count, "过路客人的来访 ID 不重复（%d 位）" % count)
	_check(ok_ns, "ID walkin_d<天>_<序号>、身份 walkin:<原型>#d<天>_<序号>，各有账户、柜台那场是他的、耐心在界里")
	_check(ok_cap, "到点时店里已经站着 %d 位：这位不进门（进门后店里不超过 %d 位）" % [cap, cap])
	var e = _new(32)
	_goto_day(e, 2)
	e.walkin().waiting_source = Callable(self, "_three")
	_tick_to(e, 1100)
	var all_skipped := true
	for slot in e.walkin().st()["slots"]:
		if str(slot["status"]) != "skipped":
			all_skipped = false
	_check(_walkins(e).is_empty() and all_skipped and int(e.walkin().st()["skipped"]) == e.walkin().st()["slots"].size(), "店里一直站满：到点的都在门口探头看看就走了（不进名单、不报错过）")
	e.walkin().waiting_source = Callable()

func _test_save_resume() -> void:
	var a = _new(41)
	_goto_day(a, 3)
	_tick_to(a, 700)
	var state_before := _canon(a.walkin().st())
	var rows_before := _rows(a)
	var saved: Dictionary = Save.snapshot(a.world, a.world.town, a, {"minute": 700, "map_id": "pawnshop", "player_pos": [136.0, 74.0]})
	_check(not saved.is_empty(), "白天中途能存档：" + Save.last_error)
	var b = _new(1)
	var context: Dictionary = {}
	var restored: bool = Save.restore(JSON.parse_string(JSON.stringify(saved, "", true, true)), b.world, b.world.town, b, a.world.town.pack, context)
	_check(restored, "白天的存档读得回来：" + Save.last_error)
	b.town_start_day()      # 读档后 town_game._start_day 会再开一次门（续玩今天）
	_check(_canon(b.walkin().st()) == state_before, "读档续玩：时刻表、已经来过几位都不变")
	_check(_rows(b) == rows_before, "读档续玩：不重复进门")
	_tick_to(a, 1100)
	_tick_to(b, 1100)
	_check(_rows(a) == _rows(b) and _rows(a) != rows_before, "读档后剩下的过路客人和没读档一样（钟点、身份、来意）")
	var ids: Dictionary = {}
	for v in _walkins(b):
		ids[str(v["id"])] = true
	_check(ids.size() == _walkins(b).size(), "读档后来访 ID 仍不重复")

func _test_calls() -> void:
	var cfg: Dictionary = Walkin.config()
	var d = _new(51)
	_goto_day(d, 2)
	var w = d.walkin()
	w.waiting_source = Callable(self, "_none")
	_tick_to(d, 400)
	var first: Dictionary = w.st()["slots"][0]
	var was := int(first["minute"])
	var r: Dictionary = d.town_action("walkin_call", {"kind": "pawn", "request_id": "walkin-test-1"})
	_check(bool(r.get("ok", false)) and int(r.get("n", -1)) == 0 and int(r.get("minutes", 0)) == int(cfg["call_minutes"]) and str(r.get("line", "")) == Walkin.line("call_pawn"), "吆喝收当：叫的是今天时刻表上下一位，花 %d 分钟，说一句“%s”" % [int(cfg["call_minutes"]), Walkin.line("call_pawn")])
	var slot0: Dictionary = w.st()["slots"][0]
	var lo := 400 + int(cfg["call_delay"][0])
	var hi := 400 + int(cfg["call_delay"][1])
	var m := int(slot0["minute"])
	_check(str(slot0["called"]) == "pawn" and m <= mini(was, hi) and (m == was or m >= lo), "被叫的人 %d–%d 分钟后进门" % [int(cfg["call_delay"][0]), int(cfg["call_delay"][1])])
	var again: Dictionary = d.town_action("walkin_call", {"kind": "pawn", "request_id": "walkin-test-1"})
	_check(JSON.stringify(again) == JSON.stringify(r) and int(w.st()["calls"]) == 1 and str(w.st()["slots"][1]["called"]) == "", "同一个 request_id 吆喝两遍只算一回（回执一样，不多叫人）")
	_check(str(d.town_action("walkin_call", {"kind": "buy", "request_id": "walkin-test-1"}).get("error", "")) == "request_conflict", "同一个 request_id 换了种类：冲突")
	var came := _tick_to(d, hi)
	var v0 := _find(d, Walkin.visit_id(2, 0))
	_check(came.has(Walkin.visit_id(2, 0)) and str(v0.get("called", "")) == "pawn" and str(v0.get("intent", "")) in ["pawn", "sell", "sell_stolen"], "吆喝收当招来的是要当、要卖东西的人")
	var v1 := _call_buyer(d)
	var sess: Dictionary = v1.get("session", {})
	_check(str(v1.get("intent", "")) == "buy" and str(v1.get("called", "")) == "buy" and str(sess.get("mode", "")) == "sell" and sess.get("stock", []).size() == 1 and not bool(sess.get("split", true)), "吆喝卖货招来的是想买架上货的人，一次只谈一件")
	if not sess.is_empty():
		var def_id := str(sess["stock"][0])
		var iid := _iid_of(d, def_id)
		var it: Dictionary = d.world.ledger.items.get(iid, {})
		var arch := str(v1.get("archetype", ""))
		var a: Dictionary = cfg["archetypes"].get(arch, {})
		var taste: Dictionary = a.get("taste", {})
		_check(iid != "" and str(it.get("owner", "")) == "player" and str(it.get("pledged_to", "")) == "", "买主挑的是当时架上自己的、没押给人的货")
		_check(float(taste.get(str(it.get("cat", "")), taste.get("_other", 0.0))) > 0.0 and d.world.market_now(it) <= int(a.get("budget", 0)), "买主只挑合他口味、他买得起的货")
		var prices: Dictionary = sess["buyer_prices"][def_id]
		_check(d.world.ledger.balance(str(v1["who"])) >= w._max_price(it, prices) and int(prices["offer"]) <= int(prices["max"]), "他身上带的钱够他最多肯出的价")
		_check(str(sess["intro"][0]["text"]).find(str(it.get("name", "?"))) >= 0, "进门先说要哪件（说出名字）")
		var labels: Array = []
		for ex in sess.get("extras", []):
			labels.append(str(ex.get("label", "")))
		_check(labels == [Walkin.line("use_label"), Walkin.line("look_label")], "柜台上能问两句：问他买去做什么、请他上手看看")
	w.waiting_source = Callable(self, "_three")
	var full: Dictionary = d.town_action("walkin_call", {"kind": "pawn"})
	_check(str(full.get("error", "")) == "shop_full" and str(full.get("line", "")) == Walkin.line("call_full"), "店里还站着三位：先招呼他们")
	w.waiting_source = Callable(self, "_none")
	var left: int = 0
	for slot in w.st()["slots"]:
		if str(slot["status"]) == "pending" and str(slot["called"]) == "":
			left += 1
	var k := 0
	var last: Dictionary = {}
	while k < 200:
		last = d.town_action("walkin_call", {"kind": "pawn"})
		if not bool(last.get("ok", false)):
			break
		k += 1
		_tick_to(d, _now(d) + int(cfg["call_delay"][1]))      # 等叫来的人进了门再吆喝（路上的人也算店里的人数）
	_check(k > 0 and k <= left and str(last.get("error", "")) == "no_walkers" and str(last.get("line", "")) == Walkin.line("call_exhausted"), "今天的人都叫来过了：街上没什么人了（%d 回）" % k)
	_tick_to(d, 1100)
	_check(_walkins(d).size() <= w.st()["slots"].size() and w.st()["slots"].size() == w.schedule(2).size(), "吆喝不凭空多造人：今天进门的过路客人不比表上多（%d / %d）" % [_walkins(d).size(), w.st()["slots"].size()])
	var late = _new(52)
	_goto_day(late, 2)
	late.walkin().waiting_source = Callable(self, "_none")
	_tick_to(late, int(cfg["call_until"]) - 1)
	_check(str(late.walkin().call_check("pawn").get("error", "")) != "too_late", "天黑以前不说“天晚了”")
	_tick_to(late, int(cfg["call_until"]))
	var too_late: Dictionary = late.town_action("walkin_call", {"kind": "pawn"})
	_check(str(too_late.get("error", "")) == "too_late" and str(too_late.get("line", "")) == Walkin.line("call_late"), "天黑以后吆喝：天晚了，街上没人了")
	var empty = _new(53)
	_goto_day(empty, 2)
	empty.walkin().waiting_source = Callable(self, "_none")
	_tick_to(empty, 400)
	for row in empty._town_shelf():
		empty.world.ledger.move_item(str(row["iid"]), "trash", "player", "测试：挪开")
	var no_stock: Dictionary = empty.town_action("walkin_call", {"kind": "buy"})
	_check(str(no_stock.get("error", "")) == "no_stock" and int(empty.walkin().st()["calls"]) == 0, "架上没货：吆喝卖货不成")
	var menu: Array = empty.walkin().menu_options()
	_check(menu.size() == 3 and not bool(menu[1]["enabled"]) and str(menu[1]["note"]) == Walkin.line("menu_no_stock") and bool(menu[0]["enabled"]), "门口小窗：架上没货时“吆喝卖货”灰着，写“架上没货”")
	_check(bool(empty.town_action("walkin_call", {"kind": "pawn"}).get("ok", false)), "架上没货也能吆喝收当")

# 吆喝叫来、还在路上的人也算进店里的人数；叫来的人到门口时店里满了（胡二、剧情里的人、自然排的客人这期间进了门），他照样进门
func _test_call_cap() -> void:
	var cfg: Dictionary = Walkin.config()
	var d = _new(54)
	_goto_day(d, 2)
	var w = d.walkin()
	w.waiting_source = Callable(self, "_two")
	_tick_to(d, 400)
	var r1: Dictionary = d.town_action("walkin_call", {"kind": "pawn"})
	_check(bool(r1.get("ok", false)), "店里站着两位：吆喝一声，叫来一位")
	var r2: Dictionary = d.town_action("walkin_call", {"kind": "pawn"})
	_check(str(r2.get("error", "")) == "shop_full" and str(r2.get("line", "")) == Walkin.line("call_full") and int(w.st()["calls"]) == 1, "站着两位、叫来的一位还在路上：再吆喝说“%s”，不白花工夫、不多叫人" % Walkin.line("call_full"))
	_check(str(w.call_check("buy").get("error", "")) == "shop_full", "路上那位还没到：吆喝卖货也不成")
	w.waiting_source = Callable(self, "_three")      # 他在路上的时候，又有人进了门：店里站满了
	var n1 := int(r1.get("n", -1))
	var came := _tick_to(d, 400 + int(cfg["call_delay"][1]))
	var slot: Dictionary = w.st()["slots"][n1] if n1 >= 0 else {}
	_check(came.has(Walkin.visit_id(2, n1)) and str(slot.get("status", "")) == "in" and int(w.st()["skipped"]) == 0, "叫来的人到门口时店里满了：他照样进门（不白叫）")
	_tick_to(d, 1100)
	var others_skipped := true
	for i in w.st()["slots"].size():
		if i != n1 and str(w.st()["slots"][i]["status"]) != "skipped":
			others_skipped = false
	_check(others_skipped, "没人叫的过路客人，到点时店里站满了照旧不进门")
	w.waiting_source = Callable()

# 架上有货，可没一样是过路的人看得上、买得起的：吆喝卖货灰着（写“过路的看不上”，不写数），吆喝了说一句世界里的话
func _test_no_buyer() -> void:
	var d = _new(55)
	_goto_day(d, 2)
	var w = d.walkin()
	w.waiting_source = Callable(self, "_none")
	_tick_to(d, 400)
	_check(bool(w.call_check("buy").get("ok", false)) and bool(w.menu_options()[1]["enabled"]), "（前提）架上原来有过路的人看得上的货：吆喝卖货可以点")
	for row in d._town_shelf():
		d.world.ledger.items[str(row["iid"])]["market"] = 100000      # 都是过路的人买不起的贵东西
	var r: Dictionary = d.town_action("walkin_call", {"kind": "buy"})
	_check(not d._town_shelf().is_empty() and str(r.get("error", "")) == "no_buyer" and str(r.get("line", "")) == Walkin.line("call_no_buyer") and int(w.st()["calls"]) == 0, "架上的货过路的人都看不上：吆喝卖货不成（%s），不算吆喝" % Walkin.line("call_no_buyer"))
	var menu: Array = w.menu_options()
	_check(not bool(menu[1]["enabled"]) and str(menu[1]["note"]) == Walkin.line("menu_no_buyer") and bool(menu[0]["enabled"]), "门口小窗：吆喝卖货灰着，写“%s”；吆喝收当还能点" % Walkin.line("menu_no_buyer"))
	_check(Rules.hidden_number_hits(Walkin.line("menu_no_buyer") + Walkin.line("call_no_buyer")).is_empty() and not (Walkin.line("menu_no_buyer") + Walkin.line("call_no_buyer")).contains("市价"), "这两句里没有数")
	_check(bool(d.town_action("walkin_call", {"kind": "pawn"}).get("ok", false)), "架上的货没人要，也能吆喝收当")
	w.waiting_source = Callable()

func _test_buyer_repick() -> void:
	# 找一个“他要的那件卖掉以后，架上还有他买得起的”局面（种子轮着试）
	var done := false
	for seed in range(61, 80):
		var d = _new(seed, true, true)
		_goto_day(d, 2)
		var w = d.walkin()
		w.waiting_source = Callable(self, "_none")
		_tick_to(d, 400)
		var v := _call_buyer(d)
		if v.is_empty() or str(v.get("intent", "")) != "buy":
			continue
		var want := str(v["session"]["stock"][0])
		var want_name := str(d.world.ledger.items[_iid_of(d, want)]["name"]) if _iid_of(d, want) != "" else ""
		var sale: Dictionary = d.town_action("sell", {"iid": _iid_of(d, want)})      # 买主还没到柜台，那件先卖掉了
		var n := int(v["session"]["_walkin"]["n"])
		var who := str(v["who"])
		if not bool(sale.get("ok", false)) or w._candidates(str(v["archetype"]), 2, n, d.world.ledger.balance(who)).is_empty():
			continue
		var cash0: int = d.world.cash()
		beats.clear()
		d.beat.connect(_record)
		var outcome: Dictionary = await d.run_town_visit(v)
		d.beat.disconnect(_record)
		var after := _find(d, str(v["id"]))
		var sess: Dictionary = after.get("session", {})
		var picked := str(sess.get("stock", [""])[0])
		_check(int(sess.get("_walkin", {}).get("repicks", 0)) == 1 and picked != want and not _shelf_defs(d).has(want), "要的那件先卖掉了：他到柜台时改挑架上另一件")
		var sold_iids: Array = outcome.get("items", [])
		var picked_name := ""
		for id in d.world.ledger.items:
			if str(d.world.ledger.items[id].get("def_id", "")) == picked:
				picked_name = str(d.world.ledger.items[id]["name"])
		var said_repick := false
		var repick_line := Walkin.line("repick", {"name": picked_name, "old": want_name})
		for b in beats:
			if b["type"] == "say" and b["who"] == who and b["text"] == repick_line:
				said_repick = true
		_check(said_repick and want_name != "" and repick_line.contains(want_name) and repick_line.contains(picked_name), "改挑时先说出原先看中的那件、再说改看哪件：“%s”" % repick_line)
		_check(str(outcome.get("result", "")) == "accept" and str(outcome.get("mode", "")) == "sell" and sold_iids.size() == 1, "柜台上谈成了（town_fair 按他的价卖）")
		if sold_iids.size() == 1:
			var it: Dictionary = d.world.ledger.items[str(sold_iids[0])]
			_check(str(it["location"]) == "npc:" + who and str(it["owner"]) == who and str(it.get("def_id", "")) == picked, "货归买主（npc:<他>）")
			_check(d.world.cash() - cash0 == int(outcome["price"]) and int(outcome["price"]) > 0, "钱从他身上付给你")
			var noted := false
			for note in d.world.notebook:
				if str(note.get("kind", "")) == "账目" and str(note.get("text", "")).find(str(it["name"])) >= 0 and str(note.get("text", "")).find("%d蚨" % int(outcome["price"])) >= 0:
					noted = true
			_check(noted, "记了一笔账目")
			_check(Walkin.sold_toast(str(it["name"]), int(outcome["price"])) == "卖出：%s，进账 %d 蚨" % [str(it["name"]), int(outcome["price"])], "提示：卖出：名字，进账 X 蚨")
		_check(d.world.ledger.check_invariants().is_empty(), "账本守恒、没有负数账户")
		var used: Dictionary = {}
		for b in beats:
			if b["type"] in ["say", "narr"]:
				used[b["text"]] = true
		var talk := false
		for ex in sess.get("extras", []):
			for step in ex.get("steps", []):
				if used.has(str(step.get("text", ""))):
					talk = true
		_check(talk, "柜台上问了两句，回答是原型数据里写的（只说观察，不报价）")
		done = true
		break
	_check(done, "找到了能改挑的局面")

func _test_nostock() -> void:
	var done := false
	for seed in range(71, 90):
		var d = _new(seed, true, true)
		_goto_day(d, 2)
		d.walkin().waiting_source = Callable(self, "_none")
		_tick_to(d, 400)
		var v := _call_buyer(d)
		if v.is_empty() or str(v.get("intent", "")) != "buy":
			continue
		for row in d._town_shelf():
			d.world.ledger.move_item(str(row["iid"]), "trash", "player", "测试：挪开")      # 架上一件也不剩
		var ledger_before := JSON.stringify(d.world.ledger.to_dict(), "", true, true)
		var cash0: int = d.world.cash()
		beats.clear()
		d.beat.connect(_record)
		var outcome: Dictionary = await d.run_town_visit(v)
		d.beat.disconnect(_record)
		var stuck := false
		var counter := 0
		var said := false
		var old_name := str(d.world.ledger.items.get(str(v["session"]["_walkin"]["iid"]), {}).get("name", ""))
		var nostock_line := Walkin.fill(str(Walkin.config()["archetypes"][str(v["archetype"])].get("buyer", {}).get("nostock", Walkin.line("nostock"))), {"old": old_name})
		for b in beats:
			if b["text"] == "（先挑出要卖的东西。）":
				stuck = true
			if b["type"] == "counter":
				counter += 1
			if b["type"] == "say" and b["text"] == nostock_line:
				said = true
		_check(bool(outcome.get("ok", false)) and str(outcome.get("result", "")) == "nostock" and said and old_name != "" and nostock_line.contains(old_name), "过路的买主：架上一件也没了，说出他看中的是哪件，一句“%s”，体面地走" % nostock_line)
		_check(not stuck and counter == 0, "不卡在柜台上（没有“先挑出要卖的东西”）")
		_check(JSON.stringify(d.world.ledger.to_dict(), "", true, true) == ledger_before and d.world.cash() == cash0, "没货走人：账上一文不动")
		done = true
		break
	_check(done, "找到了能测“没货”的买主")
	# 黎明排好的自然买主：要的都不在了。玩家没听他说过要哪件，所以他说出名字；只要一件时不说“那几样”
	var one: Dictionary = await _natural_nostock(72, 1)
	var line_one := Walkin.line("nostock_natural_one", {"name": one.get("names", [""])[0] if not one.get("names", []).is_empty() else ""})
	_check(str(one.get("result", "")) == "nostock" and one.get("said", []).has(line_one) and not bool(one.get("stuck", true)), "自然买主要的那一件不在了：说出是哪件，一句走人，不再干站着（%s）" % line_one)
	_check(not line_one.contains("那几样") and line_one.contains(str(one.get("names", ["?"])[0])), "只要一件时不说“那几样”")
	_check(bool(one.get("ledger_same", false)), "自然买主没货走人：账上不动")
	var many: Dictionary = await _natural_nostock(72, 0)
	if many.get("names", []).size() >= 2:
		var line_many := Walkin.line("nostock_natural", {"name": "、".join(many["names"])})
		_check(str(many.get("result", "")) == "nostock" and many.get("said", []).has(line_many) and not bool(many.get("stuck", true)), "自然买主要的几件都不在了：一句说出是哪几件，走人（%s）" % line_many)

# 排一位黎明的自然买主（keep > 0 只留他要的头 keep 件），把他要的货都从架上挪开，接他：返回 {result, said, stuck, names, ledger_same}
func _natural_nostock(seed: int, keep: int) -> Dictionary:
	var n = _new(seed, true, true)
	_goto_day(n, 2)
	_tick_to(n, 600)
	var town = n.world.town
	var nv := {"id": "visit_d2_walkintest", "who": "stranger:peddler#d2_9", "intent": "buy", "slot": 2, "storylet": "", "archetype": "peddler",
		"minute": 600, "patience_min": 60, "status": "planned"}
	nv["session"] = Items.session(town.templates, town.pack, town.s, nv, n.world)
	_check(str(nv["session"].get("mode", "")) == "sell" and not nv["session"].get("stock", []).is_empty(), "自然买主（黎明排的）要的是架上的货")
	if keep > 0 and nv["session"].get("stock", []).size() > keep:
		nv["session"]["stock"] = nv["session"]["stock"].slice(0, keep)
	town._register_session(nv["session"])
	town.s["visits"].append(nv)
	var names: Array = []
	for def_id in nv["session"].get("stock", []):
		if _iid_of(n, str(def_id)) != "":
			names.append(str(n.world.ledger.items[_iid_of(n, str(def_id))]["name"]))
		while _iid_of(n, str(def_id)) != "":
			n.world.ledger.move_item(_iid_of(n, str(def_id)), "trash", "player", "测试：挪开")
	var ledger0 := JSON.stringify(n.world.ledger.to_dict(), "", true, true)
	beats.clear()
	n.beat.connect(_record)
	var out: Dictionary = await n.run_town_visit(nv)
	n.beat.disconnect(_record)
	var said: Array = []
	var stuck := false
	for b in beats:
		if b["type"] == "say":
			said.append(str(b["text"]))
		if b["type"] == "counter" or b["text"] == "（先挑出要卖的东西。）":
			stuck = true
	return {"result": str(out.get("result", "")), "said": said, "stuck": stuck, "names": names,
		"ledger_same": JSON.stringify(n.world.ledger.to_dict(), "", true, true) == ledger0}

func _test_exogenous() -> void:
	var plain = _new(81)
	var calls = _new(81, true, true)
	calls.walkin().waiting_source = Callable(self, "_none")
	var same := true
	var served := 0
	for day in range(1, 7):
		_goto_day(plain, day)
		_goto_day(calls, day)
		if day >= 2:
			_tick_to(calls, 480)
			calls.town_action("walkin_call", {"kind": "pawn"})
			_tick_to(calls, 600)
			calls.town_action("walkin_call", {"kind": "buy"})
			_tick_to(calls, 640)
			for v in calls.town_visits():
				if Walkin.is_walkin(v) and int(v["minute"]) <= _now(calls) and _now(calls) <= int(v["minute"]) + int(v["patience_min"]):
					var o: Dictionary = await calls.run_town_visit(v)
					if bool(o.get("ok", false)):
						served += 1
		_tick_to(plain, 1100)
		_tick_to(calls, 1100)
		if _exogenous(plain.world.town) != _exogenous(calls.world.town):
			same = false
		_close_day(plain)
		_close_day(calls)
	_check(served > 0 and int(calls.walkin().st()["calls"]) > 0, "对照组真的吆喝了、接了过路客人（%d 位）" % served)
	_check(same, "吆喝、过路客人不动天气、米价、药价、外生轮盘（第 1–6 天逐日一样）")
	_check(calls.world.ledger.check_invariants().is_empty(), "六天下来账本守恒")

func _test_shelf_night_text() -> void:
	var d = _new(91, true, true)
	_goto_day(d, 2)
	var w = d.walkin()
	var rows: Array = w.shelf_rows()
	var shelf: Array = d._town_shelf()
	var ok_rows := rows.size() == shelf.size() and not rows.is_empty()
	for r in rows:
		var it: Dictionary = d.world.ledger.items[str(r["iid"])]
		if r.has("price") or str(r["category"]) != str(it.get("cat_cn", "")) or str(r["record"]) != "店里旧存":
			ok_rows = false
	_check(ok_rows, "货架（只看）：名字、类别、成色和“店里旧存”，不写市价")
	var iid := str(rows[0]["iid"])
	d.world.ledger.items[iid]["cost"] = 33
	_check(str(w.shelf_rows()[0]["record"]) == "当初收价 33 蚨", "收来的货写“当初收价 X 蚨”（自己账上的数）")
	d.world.ledger.tick_contracts(80, 0)
	d.world.ledger.tick_contracts(80, 0)
	var forfeited := false
	for r in w.shelf_rows():
		if str(r["record"]) == "满当的当本 24 蚨":
			forfeited = true
	_check(forfeited, "满当的货写“满当的当本 X 蚨”")
	_check(w.shelf_text("hint") == "想卖，到门口吆喝一声，买主进门在柜台上谈。", "货架上一句话：想卖，到门口吆喝一声")
	var view: Dictionary = _panel_texts(d)
	_check(not view["buttons"].has("卖掉") and view["text"].find("市价") < 0 and view["text"].find(w.shelf_text("hint")) >= 0 and view["text"].find("当初收价 33 蚨") >= 0, "货架面板（只守铺子）：没有「卖掉」、不写市价，写着“想卖，到门口吆喝一声”")
	var out_view: Dictionary = _panel_texts(_new(93, false))
	_check(out_view["buttons"].has("卖掉") and out_view["text"].find("市价约") >= 0, "货架面板（出门版）照旧：市价约、卖掉")
	_check(w.door_label() == "门口吆喝" and w.menu_options()[0]["label"] == "吆喝收当" and w.menu_options()[2]["label"] == "算了", "门口的字（给下一步的界面用）")
	# 夜里：只守铺子不出现「夜卖」
	_goto_day(d, 3)
	_tick_to(d, 1100)
	beats.clear()
	d.beat.connect(_record)
	await d.town_night()
	d.beat.disconnect(_record)
	var nights := 0
	var nightsell := false
	for b in beats:
		if b["type"] == "night":
			nights += 1
			for a in b["actions"]:
				if str(a.get("id", "")) == "nightsell":
					nightsell = true
	_check(nights > 0 and not nightsell, "只守铺子：夜里的事里没有「夜卖」")
	var off = _new(92, false, true)
	_goto_day(off, 3)
	off.world.town.set_minute(1100)
	beats.clear()
	off.beat.connect(_record)
	await off.town_night()
	off.beat.disconnect(_record)
	var off_sell := false
	for b in beats:
		if b["type"] == "night":
			for a in b["actions"]:
				if str(a.get("id", "")) == "nightsell":
					off_sell = true
	_check(off_sell, "出门版：夜里照旧有「夜卖」")
	# 给玩家看的字里没有隐藏的数
	var texts: Array = []
	var cfg: Dictionary = Walkin.config()
	for k in cfg.get("lines", {}):
		texts.append(str(cfg["lines"][k]))
	for k in cfg.get("shelf", {}):
		texts.append(str(cfg["shelf"][k]))
	for arch in cfg.get("archetypes", {}):
		var buyer: Dictionary = cfg["archetypes"][arch].get("buyer", {})
		for k in buyer:
			if buyer[k] is Array:
				for t in buyer[k]:
					texts.append(str(t))
			else:
				texts.append(str(buyer[k]))
	var hits: Array = []
	for t in texts:
		hits.append_array(Rules.hidden_number_hits(t))
	_check(texts.size() > 30 and hits.is_empty(), "过路客人、吆喝、货架的字里没有好感、概率、底价、百分号（%d 句）" % texts.size())
	# 立绘与行走图
	_check(CounterView.portrait_path("walkin:peddler#d2_3") == "art/portraits/stranger_peddler.png" and ResourceLoader.exists("res://art/portraits/stranger_peddler.png"), "过路客人的立绘用原型的 stranger_<原型>.png")
	_check(CounterView.portrait_path("stranger:collector#d4_0") == "art/portraits/stranger_collector.png", "自然排的生客也用原型立绘")
	_check(CounterView.portrait_path("zhouma") == "art/portraits/zhouma.png", "有名有姓的人立绘不变")
	_check(CounterView.portrait_path("walkin:student#d2_1") == CounterView.STRANGER_FALLBACK and DB.tex(CounterView.portrait_path("walkin:student#d2_1")) != null, "学生没有自己的立绘：借一张过路人的（%s），柜台后不空着" % CounterView.STRANGER_FALLBACK)
	_check(TownData.char_sheet_id("walkin:peddler#d2_3", "peddler") == "stranger_peddler" and TownData.char_sheet_id("walkin:fence#d2_3") == "stranger_fence", "过路客人的行走图和自然排的生客一样")

# 只守铺子的夜里：对账的库存、整理库房挑哪一件、整理后的那句话都不写市价（买来的假货在这里不露底），说明里没有“%”
func _test_night_no_market() -> void:
	var d = _new(94)
	players.append(Player.new(d, "town_fair", 94, {"night2": ["ledger", "tidy"]}))
	_goto_day(d, 3)
	_tick_to(d, 1100)
	var stock: Array = d.world.ledger.items_at("stock")
	_check(not stock.is_empty(), "（前提）第 3 天库里有货")
	if stock.is_empty():
		return
	var fid := str(stock[0])          # 自动玩家整理库房时挑头一件：把它变成一件当初 80 蚨收来的假货
	var fake: Dictionary = d.world.ledger.items[fid]
	fake["fake"] = true
	fake["market"] = 6
	fake["cost"] = 80
	fake["contraband"] = false
	var mv: int = d.world.market_now(fake)
	beats.clear()
	d.beat.connect(_record)
	await d.town_night()
	d.beat.disconnect(_record)
	var rows: Array = []
	var picks: Array = []
	var descs: Array = []
	var narrs: Array = []
	for b in beats:
		match b["type"]:
			"summary":
				rows.append_array(b["stock"])
			"pick_item":
				picks.append(b["text"])
			"night":
				for a in b["actions"]:
					descs.append(str(a.get("desc", "")))
			"narr":
				narrs.append(b["text"])
	var row := "%s（当初收价 80 蚨）" % str(fake["name"])
	var leak := false
	for t in rows + picks + narrs:
		if str(t).contains("市价") or str(t).contains("约 %d 蚨" % mv) or str(t).contains("→"):
			leak = true
	_check(rows.has(row), "夜里对账：假货那行写自己账上的“当初收价 80 蚨”（%s）" % str(rows))
	_check(not picks.is_empty() and picks[0] == "整理哪一件？", "整理库房：问“整理哪一件？”，不写“价值 +5%%”（%s）" % str(picks))
	var tidied := false
	for t in narrs:
		if str(t).begins_with("你把%s" % str(fake["name"])):
			tidied = true
	_check(tidied and float(d.world.ledger.items[fid].get("tidy_bonus", 0.0)) > 0.0, "整理库房照样整理了（%s）" % str(narrs))
	_check(not leak, "对账、整理库房的字里都没有市价")
	var hits: Array = []
	for t in descs:
		hits.append_array(Rules.hidden_number_hits(t))
	_check(not descs.is_empty() and hits.is_empty(), "夜里的事的说明里没有百分号这类数（%s）" % str(hits))
