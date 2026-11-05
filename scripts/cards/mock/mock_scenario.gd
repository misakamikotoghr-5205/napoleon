# Mock 的“情景模式”：不是真规则，只是一个看起来像样的小牌局，让界面任务在真引擎合入之前就能点完一整天、跑几天。
# 牌都来自例子集（data/cards/_examples/），文字走 CardText（开发版显示【稿】+ brief）。
# 第 1 天：林嫂来当金簪（出找不同）、货郎来卖、陈文庭来买；第 2 天：哥哥告别（金色牌）；第 3 天：警察查良民证（格子）。
# 之后每天随便发几张例子牌；30 天一关。随机只用 JevRng.draw(seed, "c.mock", …)。
# 打烊 · 下一天（§7.4.7，主创 10-13）：day.end 除 game_over 外任何阶段都能发、永远往前走；没处理的牌按“没理会”结算，
# 预览 query("day.end_preview") 和确认后真结算的是同一张清单。牢房没处理就多待一晚，连续 PRISON_MAX_DAYS 晚没出来按打点失败。
# 主人 W0（Claude）。不写 class_name（由 MockCardEngine preload）。合同：docs/cards/CARDS_INTERFACES.md §7.7。
extends RefCounted

const TOWN_PACK := "res://data/town/town_pack.json"
const STAGE_EXAMPLES := "res://scripts/cards/mock/stage_examples.json"
const STAGE_DAYS := 30
const DAY_PLAN := {
	1: ["p.linsao.1938.pawn_hairpin", "p.stranger_peddler.any.sell_bowl", "p.chen.1938.buy_scroll"],
	2: ["p.brother.1938.farewell", "p.stranger_peddler.any.sell_bowl"],
	3: ["ev.1938.police_check", "p.chen.1938.buy_scroll", "p.stranger_peddler.any.sell_bowl"],
	4: ["fa.any.fire_next_door", "lf.any.coal_out", "p.linsao.1938.pawn_hairpin", "tk.1938.de196"],
	5: ["ev.any.fortune_teller", "p.stranger_peddler.any.sell_bowl"],
	6: ["nw.1938.wangshan_dock", "p.chen.1938.buy_scroll"],
}
const RANDOM_POOL: Array[String] = ["p.stranger_peddler.any.sell_bowl", "p.chen.1938.buy_scroll", "ev.1938.police_check",
	"fa.any.fire_next_door", "lf.any.coal_out", "nw.1938.wangshan_dock", "ev.any.fortune_teller"]
const NIGHT_OFFERS: Array[String] = ["nt.tidy", "nt.family_dinner", "nt.early_sleep"]
const SELF_ATTRS := {"eye": 2, "tongue": 1, "pull": 1, "nerve": 1}
## 牢房连续几晚没出来按打点失败（合同 §7.4.7；正式值是 G06 的 ladder.json prison.max_days【待调】）
const PRISON_MAX_DAYS := 3

var db: CardDB
var seed_value: int = 7
var st: Dictionary = {}          # 情景的全部状态（只在 Mock 里）
var events: Array = []           # 本条指令的事件 [[信号名, 参数…], …]
var _stage_examples: Dictionary = {}


func _init(p_db: CardDB, opts: Dictionary) -> void:
	db = p_db
	seed_value = int(opts.get("seed", 7))
	var stage_data = CardDB.read_json(STAGE_EXAMPLES)
	if typeof(stage_data) == TYPE_DICTIONARY:
		_stage_examples = stage_data
	st = {"phase": "boot", "mode": "shop", "stage": int(opts.get("stage", 0)), "stage_day": 0, "abs_day": 0,
		"minute": 480, "money": 340, "rep_tier": 1, "heat_tier": 0, "uid_seq": 0, "item_seq": 0, "ticket_seq": 0,
		"cards": {}, "zones": {"hand": [], "kept": [], "contacts": [], "pending": [], "demands": []},
		"items": {}, "shelf": [], "tickets": [], "goals": [{"id": "gl.1938.keep_shop", "main": true, "status": "open"}],
		"night_offers": [], "open_panel": {"kind": "", "args": {}}, "lots": [], "dossier": {}, "dossier_new": 0,
		"weather": "clear", "fortune": "", "almanac_done": [], "notices": [], "firsts": {}, "counter": {},
		"wheels": {}, "attempts": {}, "settle_lines": [], "used_self": false, "estates": {}, "game_over": "",
		"prison": {"uid": "", "nights": 0}, "ended": [], "dealt_today": []}
	for es in ["es.jewel_cabinet", "es.storeroom", "es.counter", "es.old_house", "es.shopfront"]:
		st["estates"][es] = "held"
	st["self_uid"] = _new_uid()


# ---------------- 开局与跳转（夹具生成器用） ----------------
func start() -> void:
	_set_phase("month_open")
	_first("month_open", {})
	st["open_panel"] = {"kind": "wheel", "args": {"wheel": "wh.month", "uid": "", "required": true}}
	_ev(["request_panel", &"wheel", st["open_panel"]["args"].duplicate()])
	_first("month_wheel", {})


## 直接摆出 day_full 夹具要的局面：9 张手牌（含金色牌）、留着的牌、人脉、条子
func setup_day_full() -> void:
	st["stage_day"] = 9
	st["abs_day"] = 9
	st["fortune"] = "ws.1938.month.caixing"
	st["open_panel"] = {"kind": "", "args": {}}
	st["notices"] = ["w0.mock.notice"]
	_set_phase("day")
	for d in ["p.brother.1938.farewell", "ev.1938.police_check", "fa.any.fire_next_door", "p.linsao.1938.pawn_hairpin",
			"p.chen.1938.buy_scroll", "p.stranger_peddler.any.sell_bowl", "ev.any.fortune_teller", "lf.any.coal_out",
			"nw.1938.wangshan_dock"]:
		_spawn(d, "hand")
	st["dealt_today"] = (st["zones"]["hand"] as Array).duplicate()
	_spawn("kp.ma_owes", "kept")
	_spawn("kp.liangmin", "kept")
	_spawn("ct.ma", "contacts")
	_spawn("dm.1938.money.t1", "demands")
	_add_item("utensils", "bowl", true)
	_add_item("art", "landscape", true)
	for m in ["month_open", "month_wheel", "incense", "notice", "deal", "person", "counter", "mg.spot", "ticket",
			"shelf", "buyer", "night", "settle", "gold", "choice", "keep", "slots", "coins", "almanac", "demand",
			"contact", "fate", "life", "news", "lot", "cezi"]:
		st["firsts"][m] = 1
	events = []


## 流落街头 + 牢房（street_prison 夹具）
func setup_street_prison() -> void:
	setup_day_full()
	st["mode"] = "street"
	st["estates"]["es.shopfront"] = "lost"
	st["zones"]["hand"] = []
	var uid := _spawn("pr.cell", "hand")
	_spawn("st.write_letters", "hand")
	st["dealt_today"] = (st["zones"]["hand"] as Array).duplicate()
	st["open_panel"] = {"kind": "prison", "args": {"uid": uid}}
	for m in ["street", "prison", "money_short", "mortgage"]:
		st["firsts"][m] = 9
	events = []


## 月底（month_close 夹具）
func setup_month_close() -> void:
	setup_day_full()
	st["zones"]["hand"] = []
	st["stage_day"] = STAGE_DAYS
	st["abs_day"] = STAGE_DAYS
	_set_phase("month_close")
	st["settle_lines"] = [{"key": "g02.month.interest", "args": {"money": 12}}, {"key": "g02.month.expenses",
		"args": {"money": 30}}, {"key": "g02.month.verdict.1", "args": {}}]
	st["firsts"]["month_close"] = STAGE_DAYS
	events = []


## 跳一年（year_jump 夹具）
func setup_year_jump() -> void:
	setup_month_close()
	_set_phase("year_jump")
	st["settle_lines"] = [{"key": "g02.year.forfeit", "args": {"n": 2}}, {"key": "g02.year.after", "args": {}},
		{"key": "g02.year.contacts", "args": {}}]
	st["firsts"]["year_jump"] = STAGE_DAYS
	st["firsts"]["year_after"] = STAGE_DAYS
	events = []


# ---------------- 视图 ----------------
func view() -> Dictionary:
	var stage_def := db.stage(int(st["stage"]))
	var date := _date(int(st["stage_day"]))
	var v := {"v": 1, "phase": st["phase"], "mode": st["mode"], "busy": false, "stage": _stage_view(),
		"date": {"stage": st["stage"], "era": str(stage_def.get("era", "1938")), "y": date[0], "m": date[1], "d": date[2],
			"weekday": date[3], "stage_day": st["stage_day"], "stage_days": STAGE_DAYS, "abs_day": st["abs_day"],
			"minute": st["minute"]},
		"notice": {"weather": st["weather"], "market_day": _is_market(int(st["stage_day"])),
			"news": (st["notices"] as Array).duplicate(), "almanac": _almanac(), "fortune": st["fortune"]},
		"money": {"amount": st["money"], "currency": "fabi"}, "rep_tier": st["rep_tier"], "heat_tier": st["heat_tier"],
		"self": {"uid": st["self_uid"], "def": "self.ruhua", "attrs": SELF_ATTRS.duplicate(), "used_today": st["used_self"]},
		"caps": {"kept": 5, "contacts": 3, "shelf": 12}, "shelf_count": (st["shelf"] as Array).size(),
		"tickets": (st["tickets"] as Array).duplicate(true), "estates": _estates_view(),
		"goals": (st["goals"] as Array).duplicate(true), "night_offers": (st["night_offers"] as Array).duplicate(true),
		"open_panel": (st["open_panel"] as Dictionary).duplicate(true), "lots": (st["lots"] as Array).duplicate(true),
		"dossier_new": st["dossier_new"]}
	for z in ["hand", "kept", "contacts", "pending", "demands"]:
		var arr: Array = []
		for uid in st["zones"][z]:
			arr.append(card_view(uid, false))
		v[z] = arr
	return v


func _stage_view() -> Dictionary:
	var set_name := "counter"
	var has_cell := false
	for uid in st["zones"]["hand"]:
		if str(st["cards"][uid].get("def", "")) == "pr.cell":
			has_cell = true
			break
	if has_cell or str(st["prison"].get("uid", "")) != "":
		set_name = "prison"
	elif str(st["mode"]) == "street":
		set_name = "street"
	var time_name := "day"
	if str(st["phase"]) in ["night", "settle"]:
		time_name = "night"
	elif str(st["phase"]) == "day":
		var dealt: Array = st["dealt_today"]
		var removed := 0
		for uid in dealt:
			if not (st["zones"]["hand"] as Array).has(uid):
				removed += 1
		if not dealt.is_empty() and removed * 100 >= dealt.size() * 60:
			time_name = "dusk"
	return {"set": set_name, "time": time_name, "sealed": false}


func _card_stage(d: Dictionary) -> Dictionary:
	var block: Dictionary = d.get("stage", _stage_examples.get(str(d.get("id", "")), {}))
	return _without_brief(block) as Dictionary


func _without_brief(value: Variant) -> Variant:
	if typeof(value) == TYPE_DICTIONARY:
		var copied: Dictionary = {}
		for key in value:
			if str(key) != "brief":
				copied[key] = _without_brief(value[key])
		return copied
	if typeof(value) == TYPE_ARRAY:
		var copied: Array = []
		for entry in value:
			copied.append(_without_brief(entry))
		return copied
	return value


func _night_offer_views() -> Array:
	var offers: Array = []
	for def_id in NIGHT_OFFERS:
		var d := db.def(def_id)
		var choices: Array = []
		for choice in d.get("choices", []):
			choices.append(str(choice.get("id", "")))
		offers.append({"def": def_id, "art": str(d.get("art", "")), "choices": choices})
	return offers


func _has_night_offer(def_id: String) -> bool:
	for offer in st["night_offers"]:
		var offered_def := str(offer.get("def", "")) if typeof(offer) == TYPE_DICTIONARY else str(offer)
		if offered_def == def_id:
			return true
	return false


func card_view(uid: String, detailed: bool) -> Dictionary:
	var c: Dictionary = st["cards"].get(uid, {})
	if c.is_empty():
		return {}
	var d := db.def(str(c["def"]))
	var type := str(d.get("type", ""))
	var keepable := (type == "kept" or bool(d.get("keepable", false))) and not bool(d.get("gold", false))
	var cv := {"uid": uid, "def": c["def"], "type": type, "zone": c["zone"], "gold": bool(d.get("gold", false)),
		"must_resolve": CardViewModel.must_resolve(d), "keepable": keepable,
		"expires_in": int(c.get("expires_in", -1)), "status": c.get("status", "open"), "art": str(d.get("art", "")),
		"person": str(d.get("person", "")), "intent": str(d.get("intent", "")), "item": null, "asking": -1,
		"observations": [], "days_left": int(c.get("days_left", -1)), "attrs": d.get("attrs", {}),
		"used_today": false, "away_days": 0, "can_appraise": false, "panel": str(CardViewModel.panel_of(d)),
		"actions": _actions(uid), "stage": _card_stage(d), "source": str(d.get("source", "")) if type == "news" else "",
		"wheel": "wh.big" if str(c["def"]) == "bf.wheel" else str(d.get("opens_wheel", "")),
		"fortune": str(d.get("opens_fortune", ""))}
	if type == "demand":
		cv["demand"] = {"kind": str(d.get("kind", "")), "tier": int(c.get("tier", d.get("tier", 0)))}
		# 1.5：条子按当前办法要交的钱（Mock 只给“直接交钱”那一档）。
		cv["amount"] = int(d.get("resolve", {}).get("money", {}).get("amount", 0)) if str(d.get("kind", "")) == "money" else 0
	var sess: Dictionary = st["counter"].get(uid, {})
	if not sess.is_empty() and str(sess.get("item", "")) != "":
		cv["item"] = _item_view(str(sess["item"]))
		cv["observations"] = cv["item"]["observations"]
		cv["asking"] = int(sess.get("asking", -1))
		cv["can_appraise"] = str(d.get("intent", "")) in ["pawn", "sell"]
	if detailed:
		cv["slots"] = _slot_views(uid)
		cv["choices"] = _choices(uid)
	return cv


# ---------------- 指令 ----------------
## 返回 {ok, err, …}；事件在 events 里
func send(cmd: String, a: Dictionary) -> Dictionary:
	events = []
	match cmd:
		"game.new":
			return {"ok": true, "err": ""}
		"game.save", "game.load":
			return {"ok": true, "err": "", "meta": {}}
		"game.retry_stage":
			_first("retry", {})
			st["zones"]["hand"] = []
			st["stage_day"] = 0
			st["prison"] = {"uid": "", "nights": 0}
			st["game_over"] = ""
			start()
			return _ok()
		"month.begin":
			if str(st["phase"]) != "month_open":
				return _err("bad_phase")
			if str(st["fortune"]) == "":
				return _err("wheel_pending")
			_to_morning()
			return _ok()
		"day.begin":
			if str(st["phase"]) != "morning":
				return _err("bad_phase")
			return _deal()
		"day.end":
			return _end_day(bool(a.get("confirm", false)))
		"night.choose":
			if str(st["phase"]) != "night":
				return _err("bad_phase")
			var nd := str(a.get("def", ""))
			if nd != "" and not _has_night_offer(nd):
				return _err("bad_args")
			_night(nd)
			return _ok()
		"settle.next":
			if str(st["phase"]) != "settle":
				return _err("bad_phase")
			return _settle_next()
		"month.next":
			if str(st["phase"]) != "month_close":
				return _err("bad_phase")
			_month_next()
			return _ok()
		"year.next":
			if str(st["phase"]) != "year_jump":
				return _err("bad_phase")
			_year_next()
			return _ok()
		"card.keep":
			return _keep(str(a.get("uid", "")))
		"card.discard":
			return _leave(str(a.get("uid", "")), "resolved")
		"card.read":
			var d := _def(str(a.get("uid", "")))
			if d.is_empty():
				return _err("unknown_uid")
			for e in d.get("effects", {}).get("on_read", []):
				if str(e.get("op", "")) == "dossier":
					_dossier(str(e["frag"]))
			return _leave(str(a.get("uid", "")), "resolved")
		"card.choose":
			return _choose(str(a.get("uid", "")), str(a.get("choice", "")))
		"slot.place":
			return _place(str(a.get("uid", "")), str(a.get("slot", "")), a.get("source", {}))
		"slot.remove":
			var c: Dictionary = st["cards"].get(str(a.get("uid", "")), {})
			var pl: Array = c.get("placed", {}).get(str(a.get("slot", "")), [])
			if int(a.get("index", 0)) < pl.size():
				pl.remove_at(int(a.get("index", 0)))
			return _ok()
		"slot.roll":
			return _roll(str(a.get("uid", "")))
		"demand.submit":
			return _leave(str(a.get("uid", "")), "resolved", {"success": true})
		"demand.delay":
			var c2: Dictionary = st["cards"].get(str(a.get("uid", "")), {})
			c2["days_left"] = int(c2.get("days_left", 7)) + 3
			c2["tier"] = mini(3, int(c2.get("tier", 1)) + 1)
			_first("demand_delay", {"uid": str(a.get("uid", ""))})
			return _ok({"days_left": c2["days_left"], "tier": c2["tier"]})
		"contact.release":
			return _leave(str(a.get("uid", "")), "resolved")
		"counter.open":
			return _counter_open(str(a.get("uid", "")))
		"counter.offer":
			return _counter_offer(str(a.get("uid", "")), str(a.get("tier", "fair")))
		"counter.answer":
			return _counter_answer(str(a.get("uid", "")), bool(a.get("accept", false)))
		"counter.pick_stock":
			var s: Dictionary = st["counter"].get(str(a.get("uid", "")), {})
			if s.is_empty() or not (st["shelf"] as Array).has(str(a.get("item", ""))):
				return _err("stock_empty")
			s["item"] = str(a.get("item", ""))
			s["asking"] = int(st["items"][s["item"]]["base"])
			return _ok()
		"counter.redeem":
			return _leave(str(a.get("uid", "")), "resolved", {"reply": "accept"})
		"counter.refuse":
			return _leave(str(a.get("uid", "")), "refused")
		"counter.close":
			return _ok()
		"mg.request":
			return _mg_request(str(a.get("uid", "")), str(a.get("item", "")))
		"mg.report":
			var obs: Array = (a.get("result", {}) as Dictionary).get("observations", [])
			var it: Dictionary = st["items"].get(str(a.get("item", "")), {})
			if not it.is_empty():
				(it["observations"] as Array).append_array(obs)
			_ev(["card_updated", str(a.get("uid", ""))])
			return _ok({"observations": obs.duplicate()})
		"estate.mortgage", "estate.redeem":
			var es := str(a.get("estate", ""))
			var mort := cmd == "estate.mortgage"
			st["estates"][es] = "mortgaged" if mort else "held"
			_money(80 if mort else -80, "w0.mock.estate")
			_first("mortgage", {})
			return _ok({"money": 80})
		"short.resolve":
			st["open_panel"] = {"kind": "", "args": {}}
			return _ok()
		"street.redeem_shop":
			st["mode"] = "shop"
			return _ok()
		"wheel.offer":
			return _wheel_offer(a)
		"wheel.withdraw":
			var w := _wheel(str(a.get("wheel", "")), str(a.get("uid", "")))
			if int(a.get("index", 0)) < (w["placed"] as Array).size():
				(w["placed"] as Array).remove_at(int(a.get("index", 0)))
			return _ok()
		"wheel.stake":
			_wheel(str(a.get("wheel", "")), str(a.get("uid", "")))["staked"] = str(a.get("kept_uid", ""))
			_first("wheel_stake", {})
			return _ok()
		"wheel.spin":
			return _wheel_spin(str(a.get("wheel", "")), str(a.get("uid", "")))
		"fortune.lot":
			st["lots"].append({"lot": "lot.g1.official", "abs_day": st["abs_day"]})
			_money(-3, "w0.mock.fortune")
			_leave(str(a.get("uid", "")), "resolved")
			return _ok({"lot": "lot.g1.official", "grade": 1})
		"fortune.cezi":
			_money(-3, "w0.mock.fortune")
			_leave(str(a.get("uid", "")), "resolved")
			return _ok({"char": str(a.get("char", "cz.shui")), "reading": "has"})
	return _err("not_implemented")


# ---------------- 查询 ----------------
func query(q: String, a: Dictionary) -> Dictionary:
	var uid := str(a.get("uid", ""))
	match q:
		"card":
			var cv := card_view(uid, true)
			return cv if not cv.is_empty() else {"ok": false, "err": "unknown_uid"}
		"actions":
			return {"actions": _actions(uid)}
		"slots":
			var sv := _slot_views(uid)
			var p := _preview(uid)
			return {"slots": sv, "coins": p["coins"], "auto_heads": p["auto_heads"], "need": p["need"],
				"auto_pass": p["auto_pass"], "ready": true}
		"counter":
			return _counter_view(uid)
		"stock":
			var arr: Array = []
			for iid in st["shelf"]:
				arr.append(_item_view(iid))
			return {"items": arr}
		"tickets":
			return {"tickets": (st["tickets"] as Array).duplicate(true)}
		"estates":
			return {"estates": _estates_view()}
		"short":
			return {"amount": 20, "payee": "w0.mock.payee", "source": "", "options": ["goods", "estate", "default"],
				"goods": [], "estates": _estates_view()}
		"wheel":
			return _wheel_view(str(a.get("wheel", "")), uid)
		"fortune":
			return {"cost": 3, "can_lot": true, "can_cezi": true, "cezi": ["cz.shui"], "last": {}}
		"almanac":
			return _almanac()
		"dossier":
			return _dossier_view()
		"settle_report", "month_report", "year_report":
			return {"lines": (st["settle_lines"] as Array).duplicate(true)}
		"firsts":
			return {"firsts": (st["firsts"] as Dictionary).duplicate()}
		"day.end_preview":
			return _end_preview()
	return {"ok": false, "err": "not_implemented"}


# ---------------- 日 ----------------
func _to_morning() -> void:
	st["stage_day"] = int(st["stage_day"]) + 1
	st["abs_day"] = int(st["abs_day"]) + 1
	st["minute"] = 480
	st["used_self"] = false
	st["almanac_done"] = []
	st["open_panel"] = {"kind": "", "args": {}}
	st["weather"] = "rain" if int(st["stage_day"]) % 4 == 2 else "clear"
	st["notices"] = ["w0.mock.notice"]
	_set_phase("morning")
	_first("notice", {})
	_first("almanac", {})
	if str(st["weather"]) != "clear":
		_first("weather", {})
	if _is_market(int(st["stage_day"])):
		_first("market_day", {})
	for t in st["tickets"]:
		t["days_left"] = int(t["days_left"]) - 1
	for uid in st["zones"]["kept"].duplicate() + st["zones"]["hand"].duplicate():
		var c: Dictionary = st["cards"][uid]
		if int(c.get("expires_in", -1)) > 0:
			c["expires_in"] = int(c["expires_in"]) - 1
			if int(c["expires_in"]) == 0:
				_first("kept_expire", {"uid": uid})
				_leave(uid, "expired")


func _deal() -> Dictionary:
	_set_phase("day")
	var day := int(st["stage_day"])
	var defs: Array = DAY_PLAN.get(day, []).duplicate() if int(st["stage"]) == 0 else []
	if defs.is_empty():
		for k in range(3):
			var u := JevRng.draw(seed_value, "c.mock", ["deal", int(st["abs_day"]), k])
			defs.append(RANDOM_POOL[int(u * RANDOM_POOL.size())])
	if _in_jail():
		# 在牢里过夜的第二天：铺子关门，不发人物牌（§7.4.6 “在牢里”一列）
		defs = defs.filter(func(x) -> bool: return str(db.def(str(x)).get("type", "")) != "person")
	var uids: Array = []
	for d in defs:
		uids.append(_spawn(str(d), "hand"))
	st["dealt_today"] = uids.duplicate()
	if day == 7 and int(st["stage"]) == 0:
		var dm := _spawn("dm.1938.money.t1", "demands")
		st["cards"][dm]["days_left"] = 7
		_first("demand", {"uid": dm})
	_ev(["cards_dealt", PackedStringArray(uids)])
	_first("deal", {})
	for uid in uids:
		var d := _def(uid)
		var type := str(d.get("type", ""))
		if type in ["person", "news", "life", "fate"]:
			_first(type, {"uid": uid, "def": str(d.get("id", ""))})
		if bool(d.get("gold", false)):
			_first("gold", {"uid": uid, "def": str(d.get("id", ""))})
		if not (d.get("slots", []) as Array).is_empty():
			_first("slots", {"uid": uid})
		if not (d.get("choices", []) as Array).is_empty():
			_first("choice", {"uid": uid})
		if str(d.get("opens_fortune", "")) != "":
			_first("lot", {"uid": uid})
			_first("cezi", {"uid": uid})
		if bool(d.get("keepable", false)) and type != "kept":
			_first("keep", {"uid": uid})
	return _ok({"dealt": uids})


## 打烊 · 下一天（§7.4.7）：除 game_over 外任何阶段都往前走一步。confirm 为假、清单里有要确认的行 → 返回清单等确认
## （只记 first must_resolve / gold_leave）；否则按阶段做那一步。
func _end_day(confirm: bool) -> Dictionary:
	var pv := _end_preview()
	var step := str(pv["step"])
	if step == "":
		return _err("bad_phase")
	var items: Array = pv["items"]
	_end_firsts(items)
	if bool(pv["needs_confirm"]) and not confirm:
		return {"ok": false, "err": "must_resolve_pending", "step": step, "items": items, "needs_confirm": true}
	var extra := {"step": step, "items": items}
	match step:
		"end_day":
			_settle_rows(items)
			if str(st["phase"]) == "day":
				st["night_offers"] = [] if _in_jail() else _night_offer_views()
				_set_phase("night")
				_first("night", {})
		"skip_night":
			_night("")
		"next_day":
			extra.merge(_settle_next(), true)
		"open_day":
			extra.merge(_deal(), true)
		"begin_month":
			if str(st["fortune"]) == "":
				_wheel_spin("wh.month", "")
			_to_morning()
		"month_next":
			_month_next()
		"year_next":
			_year_next()
	extra["ok"] = true
	extra["err"] = ""
	return extra


## 打烊确认的清单（query "day.end_preview"）：{step, needs_confirm, items:[{uid, def, kind, consequence_key, args}]}
func _end_preview() -> Dictionary:
	var items: Array = []
	var step := ""
	match str(st["phase"]):
		"day":
			step = "end_day"
			items = _end_rows()
		"night":
			step = "skip_night"
			items = [_row("", "skip_night", "g02.end.skip_night", {})]
		"settle":
			step = "next_day"
		"morning":
			step = "open_day"
		"month_open":
			step = "begin_month"
			if str(st["fortune"]) == "":
				items = [_row("", "auto_spin", "g02.end.auto_spin", {})]
		"month_close":
			step = "month_next"
		"year_jump":
			step = "year_next"
	var needs := false
	for it in items:
		if not CardIds.END_NO_CONFIRM_KINDS.has(StringName(str(it["kind"]))):
			needs = true
	return {"step": step, "needs_confirm": needs, "items": items}


## 白天打烊时每样没处理的东西会怎样（§7.4.7 的表；真引擎里各模块经修正项 end_rows 交）
func _end_rows() -> Array:
	var rows: Array = []
	for uid in st["zones"]["hand"]:
		var c: Dictionary = st["cards"][uid]
		var d := _def(uid)
		var id := str(d.get("id", ""))
		var type := str(d.get("type", ""))
		var expire: Array = d.get("effects", {}).get("on_expire", [])
		if bool(d.get("gold", false)):
			rows.append(_row(uid, "gold_leave", id + "#outcomes.ignored", {}))
		elif type == "prison":
			var nights := int(st["prison"]["nights"]) + 1 if str(st["prison"]["uid"]) == uid else 1
			var kind := "fail" if nights >= PRISON_MAX_DAYS else "stay"
			rows.append(_row(uid, kind, "g06.end." + kind, {"nights": nights, "max": PRISON_MAX_DAYS}))
		elif id == "bf.wheel":
			rows.append(_row(uid, "void", "g05.end.void", {}))
		elif CardViewModel.must_resolve(d):
			var key := "g02.end.leave" if type == "person" else "g02.end.ignore"
			if not expire.is_empty():
				key = id + "#outcomes.ignored"
			elif type != "person" and typeof(d.get("check")) == TYPE_DICTIONARY:
				key = id + "#outcomes.fail"
			rows.append(_row(uid, "leave" if type == "person" else "ignore", key, {}))
		elif type == "life":
			var left := int(c.get("days_left", 1))
			if left <= 1:
				rows.append(_row(uid, "ignore", id + "#outcomes.ignored", {}))
			else:
				rows.append(_row(uid, "wait", "g01.end.wait", {"days": left - 1}))
		elif bool(d.get("keepable", false)) or type == "kept":
			rows.append(_row(uid, "wait", "g01.end.wait", {"days": int(c.get("expires_in", -1))}))
		else:
			rows.append(_row(uid, "pass", "g02.end.pass", {}))
	for uid in st["zones"]["demands"]:
		rows.append(_row(uid, "wait", "g03.end.demand", {"days": int(st["cards"][uid].get("days_left", -1))}))
	if str(st["open_panel"].get("kind", "")) == "short":
		rows.append(_row("", "short", "g06.end.short", {}))
	return rows


func _row(uid: String, kind: String, key: String, args: Dictionary) -> Dictionary:
	var d := _def(uid) if uid != "" else {}
	return {"uid": uid, "def": str(d.get("id", "")), "kind": kind, "consequence_key": key, "args": args}


## 第一次打烊时手上还有要了断的牌 → first must_resolve；有金色牌那一行 → first gold_leave（确认之前就记，§7.4.7）
func _end_firsts(items: Array) -> void:
	for it in items:
		if CardIds.END_MUST_KINDS.has(StringName(str(it["kind"]))):
			_first("must_resolve", {"uid": str(it["uid"])})
		elif str(it["kind"]) == "gold_leave":
			_first("gold_leave", {"uid": str(it["uid"])})


## 确认之后按清单结算（真引擎里是 day_end 钩子里各模块按 priority 做的）
func _settle_rows(items: Array) -> void:
	st["ended"] = []
	for it in items:
		var uid := str(it["uid"])
		var d := _def(uid) if uid != "" else {}
		var kind := str(it["kind"])
		match kind:
			"gold_leave", "leave", "pass":
				_apply(d.get("effects", {}).get("on_expire", []))
				_leave(uid, "gold_left" if kind == "gold_leave" else ("left" if kind == "leave" else "expired"))
			"ignore":
				if d.get("effects", {}).has("on_expire"):
					_apply(d["effects"]["on_expire"])
				elif typeof(d.get("check")) == TYPE_DICTIONARY:
					_apply(d["check"].get("on_fail", []))
				_leave(uid, "expired")
			"void":
				_leave(uid, "expired")
			"stay":
				st["prison"] = {"uid": uid, "nights": int(it["args"]["nights"])}
			"fail":
				st["prison"] = {"uid": "", "nights": 0}
				_leave(uid, "expired")
				_game_over("prison")
			"wait":
				if str(d.get("type", "")) == "life":
					var c: Dictionary = st["cards"][uid]
					c["days_left"] = int(c.get("days_left", 1)) - 1
			"short":
				st["open_panel"] = {"kind": "", "args": {}}
		if not CardIds.END_NO_CONFIRM_KINDS.has(StringName(kind)):
			(st["ended"] as Array).append({"key": str(it["consequence_key"]), "args": (it["args"] as Dictionary).duplicate()})


## Mock 只认几种效果（真效果归各模块）：补碎片、留缺口、钱、局终
func _apply(effects: Array) -> void:
	for e in effects:
		match str(e.get("op", "")):
			"dossier":
				_dossier(str(e["frag"]))
			"dossier_gap":
				_dossier(str(e["frag"]), true)
			"money":
				_money(int(e.get("delta", 0)), str(e.get("reason", "")))
			"game_over":
				_game_over(str(e.get("reason", "")))


func _game_over(reason: String) -> void:
	st["game_over"] = reason
	_set_phase("game_over")
	_ev(["game_over", StringName(reason)])
	_first("game_over", {"kind": reason})


## 手上有在牢里过夜的牢房牌
func _in_jail() -> bool:
	var uid := str(st["prison"]["uid"])
	return uid != "" and (st["zones"]["hand"] as Array).has(uid)


## 夜里选一张夜牌（def 为空 = 今晚不选，“算了”）→ 日结；打烊时按“没理会”结算的东西各一行进日结
func _night(def_id: String) -> void:
	_set_phase("settle")
	st["settle_lines"] = [{"key": "g02.settle.money", "args": {"money": st["money"]}}]
	if def_id != "":
		st["settle_lines"].append({"key": "g02.settle.night", "args": {"def": def_id}})
	for row in st["ended"]:
		st["settle_lines"].append(row)
	st["ended"] = []
	for t in st["tickets"]:
		st["settle_lines"].append({"key": "g02.settle.ticket", "args": {"no": t["no"], "days": t["days_left"]}})
	_first("settle", {})


func _settle_next() -> Dictionary:
	if int(st["stage_day"]) >= STAGE_DAYS:
		_set_phase("month_close")
		_first("month_close", {})
		return _ok({"next_phase": "month_close"})
	_to_morning()
	return _ok({"next_phase": "morning"})


func _month_next() -> void:
	_set_phase("year_jump")
	_first("year_jump", {})


func _year_next() -> void:
	st["stage"] = int(st["stage"]) + 1
	st["stage_day"] = 0
	st["fortune"] = ""
	start()


# ---------------- 柜台 ----------------
func _counter_open(uid: String) -> Dictionary:
	var d := _def(uid)
	if str(CardViewModel.panel_of(d)) != "counter":
		return _err("bad_args")
	var intent := str(d.get("intent", ""))
	if not st["counter"].has(uid):
		var sess := {"round": 0, "last_reply": "", "last_price": 0, "item": "", "asking": -1}
		if intent in ["pawn", "sell"]:
			var tpl: Dictionary = d.get("item", {})
			var parts := str(tpl.get("template", "")).split(".")
			var cat := parts[0] if parts.size() == 2 else str(tpl.get("cat", "utensils"))
			var variant := parts[1] if parts.size() == 2 else _pick_variant(cat, uid)
			sess["item"] = _add_item(cat, variant, false)
			var base := int(st["items"][sess["item"]]["base"])
			var ask: Array = d.get("asking", {}).get("pct", [100, 100])
			sess["asking"] = base * (int(ask[0]) + int(ask[1])) / 200
		st["counter"][uid] = sess
	_first("counter", {"uid": uid})
	if intent == "buy":
		_first("buyer", {"uid": uid})
	return _ok(_counter_view(uid))


func _counter_view(uid: String) -> Dictionary:
	var d := _def(uid)
	var sess: Dictionary = st["counter"].get(uid, {})
	if d.is_empty() or sess.is_empty():
		return {"ok": false, "err": "bad_phase"}
	var intent := str(d.get("intent", ""))
	var direction := "receive" if intent == "buy" else "pay"
	var asking := int(sess.get("asking", -1))
	var t := _tiers(asking, direction)
	var stock: Array = []
	for iid in st["shelf"]:
		stock.append(iid)
	return {"uid": uid, "person": str(d.get("person", "")), "intent": intent,
		"item": _item_view(str(sess["item"])) if str(sess.get("item", "")) != "" else null, "asking": asking,
		"tiers": t, "direction": direction, "round": sess["round"], "last_reply": sess["last_reply"],
		"last_price": sess["last_price"], "line_key": "%s#lines.%s" % [d.get("id", ""),
			"greet" if str(sess["last_reply"]) == "" else sess["last_reply"]],
		"can_appraise": intent in ["pawn", "sell"] and str(sess.get("item", "")) != "", "stock": stock, "ticket": null}


func _tiers(asking: int, direction: String) -> Dictionary:
	if asking <= 0:
		return {"harsh": 0, "fair": 0, "kind": 0}
	if direction == "pay":
		return {"harsh": asking * 55 / 100, "fair": asking * 75 / 100, "kind": asking * 95 / 100}
	return {"harsh": asking * 130 / 100, "fair": asking * 105 / 100, "kind": asking * 85 / 100}


func _counter_offer(uid: String, tier: String) -> Dictionary:
	var sess: Dictionary = st["counter"].get(uid, {})
	if sess.is_empty():
		return _err("bad_phase")
	var d := _def(uid)
	if str(d.get("intent", "")) == "buy" and str(sess.get("item", "")) == "":
		return _err("stock_empty")
	var view := _counter_view(uid)
	var price := int(view["tiers"].get(tier, 0))
	sess["round"] = int(sess["round"]) + 1
	if tier == "harsh" and int(sess["round"]) < 3:
		sess["last_reply"] = "counter"
		sess["last_price"] = int(view["tiers"]["fair"])
		_ev(["card_updated", uid])
		return _ok({"reply": "counter", "price": sess["last_price"]})
	if tier == "harsh":
		sess["last_reply"] = "leave"
		_leave(uid, "left")
		return _ok({"reply": "leave", "price": 0})
	_deal_done(uid, price)
	return _ok({"reply": "accept", "price": price})


func _counter_answer(uid: String, accept: bool) -> Dictionary:
	var sess: Dictionary = st["counter"].get(uid, {})
	if sess.is_empty():
		return _err("bad_phase")
	if accept:
		_deal_done(uid, int(sess["last_price"]))
		return _ok({"reply": "accept", "price": sess["last_price"]})
	_leave(uid, "left")
	return _ok({"reply": "leave", "price": 0})


func _deal_done(uid: String, price: int) -> void:
	var d := _def(uid)
	var sess: Dictionary = st["counter"][uid]
	var intent := str(d.get("intent", ""))
	var iid := str(sess.get("item", ""))
	sess["last_reply"] = "accept"
	sess["last_price"] = price
	if intent == "buy":
		_money(price, "w0.mock.sold")
		st["shelf"].erase(iid)
		st["almanac_done"].append("sell_out")
	elif intent == "pawn":
		_money(-price, "w0.mock.pawn_out")
		st["ticket_seq"] = int(st["ticket_seq"]) + 1
		st["tickets"].append({"no": st["ticket_seq"], "person": str(d.get("person", "")), "item": iid, "principal": price,
			"days_left": int(d.get("term_days", 15)), "status": "open", "foreign": false})
		_first("ticket", {"no": st["ticket_seq"]})
		st["almanac_done"].append("pawn_in")
	elif intent == "sell":
		_money(-price, "w0.mock.bought")
		st["shelf"].append(iid)
		st["items"][iid]["on_shelf_since"] = st["abs_day"]
		_first("shelf", {})
		st["almanac_done"].append("buy_in")
	for e in d.get("effects", {}).get("on_accept", []):
		if str(e.get("op", "")) == "dossier":
			_dossier(str(e["frag"]))
	_leave(uid, "resolved")


# ---------------- 小游戏 ----------------
func _mg_request(uid: String, item_id: String) -> Dictionary:
	var d := _def(uid)
	if d.is_empty():
		return _err("unknown_uid")
	var kind := ""
	var params: Dictionary = {}
	if item_id == "":
		kind = str(d.get("minigame", ""))
		if kind == "":
			return _err("no_minigame")
	else:
		var it: Dictionary = st["items"].get(item_id, {})
		if it.is_empty():
			return _err("bad_args")
		kind = "spot" if str(it["cat"]) in ["jewelry", "art", "documents", "clothing"] else "weigh"
		if str(it["cat"]) == "silver":
			kind = "coin_ring"
	var mseed := int(JevRng.draw(seed_value, "c.mock", ["mg", uid, item_id, kind]) * 2147483647.0)
	params = {"kind": kind, "seed": mseed, "item": item_id, "art": _item_art(item_id), "minutes_per_step": 1,
		"max_minutes": 30}
	params.merge(_mg_params(kind, item_id), true)
	_ev(["minigame_requested", uid, item_id, StringName(kind), params.duplicate(true)])
	_first("mg." + kind, {"uid": uid, "kind": kind})
	return _ok({"kind": kind, "params": params})


## 10-25 鉴定改版（DESIGN 鉴定改版 §3–§8）：新参数照 §8.2 新表给全，老小游戏不读的字段不碍事（P9）。
## 答案不进参数；mock 自己不判分（说破只在真引擎里）。
func _mg_params(kind: String, item_id: String) -> Dictionary:
	match kind:
		"spot":
			var it: Dictionary = st["items"].get(item_id, {})
			return spot_layout(seed_value, str(it.get("cat", "jewelry")), str(it.get("variant", "hairpin")))
		"weigh":
			return {"tool": "dengzi", "claimed_fen": 300, "actual_fen": 291, "weights_fen": [100, 100, 50, 20, 10, 5],
				"resolution_fen": 5, "small_fen": 10, "zoom": 2, "minor_ticks": true, "needle_gain": 8}
		"coin_ring":
			return {"coins": [{"id": "a", "ring_ms": 1350, "pitch_cents": -40, "buzz": 12}],
				"reference": {"ring_ms": 1450, "pitch_cents": 0, "buzz": 8},
				"samples": [{"id": "good", "ring_ms": 1450, "pitch_cents": 0, "buzz": 8},
					{"id": "dull", "ring_ms": 500, "pitch_cents": -190, "buzz": 65}],
				"tries": 5, "ghosts": 1, "clink": false}
		"fragments":
			return {"doc": "pawn_ticket", "pieces": 6, "seal_offset_px": 2, "ink_mismatch": [], "dangzi_marks": 3,
				"missing_piece": -1, "stain": 4, "rotate": false, "lens_px": 72, "backlight": false}
		"decode":
			return {"cipher": "telegraph", "message": "", "codes": ["0417", "2201"], "book_words": ["cb.word.0417",
				"cb.word.2201"], "book": [["0411", "cb.word.0411"], ["0417", "cb.word.0417"], ["2201", "cb.word.2201"],
				["2207", "cb.word.2207"]], "smudges": [[0, 3, "0411"]], "key_shift": 0, "crib": ""}
	return {}


## 找不同的布局：用真 ItemGen 生成这一类物品，再照 G04 的规矩只留布局：每件固定 3 处痕迹（authenticity、provenance
## 各一处，第三处在 condition 或 material），每处带 FlawRender 画法 look 和精确小矩形 at；图例是这一类的基本图例。
## 搜索语义键直到抽出要的那个式样（确定的；优先挑有一处 differs 的，夹具里要看得到 differs 和 wear）。
## 不给 tell / benign / fake_text / real_text / est，也不给答案。
static func spot_layout(p_seed: int, cat: String, variant: String) -> Dictionary:
	var templates = CardDB.read_json("res://data/town/item_templates.json")
	var pack = CardDB.read_json(TOWN_PACK)
	if typeof(templates) != TYPE_DICTIONARY or typeof(pack) != TYPE_DICTIONARY:
		return {"parts": [], "marks": [], "legend": {"wear": [], "differs": []}, "atlas_art": "", "ink": 4, "lens_px": 72,
			"blink": false, "tools": ["eye", "lens", "atlas"], "atlas_open": false}
	var item: Dictionary = {}
	for k in range(200):
		var s := {"seed": p_seed, "day": 1}
		var cand := ItemGen.generate(templates, pack, s, ["c", 1, "mock_spot", k], cat)
		if str(cand.get("template_id", "")) != variant:
			continue
		if item.is_empty() or (bool(cand.get("fake", false)) and not bool(item.get("fake", false))):
			item = cand
		if bool(item.get("fake", false)):
			break
	var tool_map := {"magnifier": "lens", "hand": "eye", "book": "atlas", "scale": "eye", "nose": "eye"}
	var parts: Array = []
	var rects := {}
	for p in item.get("parts", []):
		var r: Array = p.get("rect", [0, 0, 8, 8])
		var rect := [int(r[0]), int(r[1]), int(r[2]), int(r[3])]
		rects[str(p.get("id", ""))] = rect
		parts.append({"id": str(p.get("id", "")), "rect": rect, "tool": str(tool_map.get(str(p.get("tool", "hand")), "eye"))})
	var flaws := {}
	for f in item.get("flaws", []):
		flaws[str(f.get("part", ""))] = f
	var rules: Dictionary = templates.get("appraise", {}).get("categories", {}).get(cat, {})
	var wear: Array = []
	for w in rules.get("worn", []) + rules.get("wear", []):
		if not wear.has(str(w)):
			wear.append(str(w))
	var differs: Array = []
	for w in rules.get("fake", []) + [str(rules.get("stolen", "scrape"))]:
		if not differs.has(str(w)):
			differs.append(str(w))
	if wear.is_empty():
		wear = ["scuff"]
	var slots: Array = [["authenticity", "differs" if bool(item.get("fake", false)) else "wear"],
		["provenance", "differs" if bool(item.get("stolen", false)) else "wear"],
		["condition" if flaws.has("condition") else "material", "wear"]]
	slots.sort_custom(func(a: Array, b: Array) -> bool: return str(a[0]) < str(b[0]))
	var marks: Array = []
	var i := 0
	for slot in slots:
		var part := str(slot[0])
		if not rects.has(part):
			continue
		var f: Dictionary = flaws.get(part, {})
		var flaw_kind := "wear" if bool(f.get("benign", false)) else "differs"
		var look := str(f.get("kind", "")) if not f.is_empty() and flaw_kind == str(slot[1]) else ""
		if look == "":
			look = str(wear[i % wear.size()]) if str(slot[1]) == "wear" else str(differs[0] if not differs.is_empty() else "speck")
		var fine := 800 if str(slot[1]) == "differs" or i == 2 else 300
		var size := 5 if fine >= 500 else 7
		var rect: Array = rects[part]
		var w := mini(size, int(rect[2]))
		var h := mini(size, int(rect[3]))
		var x := int(rect[0]) + int(JevRng.draw(p_seed, "c.mock", ["spot_at", cat, variant, part, "x"]) * (int(rect[2]) - w + 1))
		var y := int(rect[1]) + int(JevRng.draw(p_seed, "c.mock", ["spot_at", cat, variant, part, "y"]) * (int(rect[3]) - h + 1))
		marks.append({"part": part, "kind": str(slot[1]), "look": look, "at": [x, y, w, h], "fine": fine,
			"seed": int(f.get("seed", int(JevRng.draw(p_seed, "c.mock", ["spot_seed", cat, variant, part]) * 2147483647.0)))})
		i += 1
	# Same rule as G04: a part holding a fine mark shows it only under the lens.
	for p in parts:
		for mk in marks:
			if str(mk["part"]) == str(p["id"]) and int(mk["fine"]) >= 500:
				p["tool"] = "lens"
	return {"parts": parts, "marks": marks, "legend": {"wear": wear.slice(0, 2), "differs": differs.slice(0, 2)},
		"atlas_art": "item.%s.%s" % [cat, variant], "ink": 4, "lens_px": 72, "blink": false,
		"tools": ["eye", "lens", "atlas"], "atlas_open": false}


# ---------------- 格子与选项 ----------------
func _slot_defs(uid: String) -> Array:
	var d := _def(uid)
	var c: Dictionary = st["cards"].get(uid, {})
	var choice := str(c.get("choice", ""))
	if choice != "":
		for ch in d.get("choices", []):
			if str(ch.get("id", "")) == choice and typeof(ch.get("check")) == TYPE_DICTIONARY:
				return ch["check"].get("slots", [])
	return d.get("slots", [])


func _need(uid: String) -> int:
	var d := _def(uid)
	var choice := str(st["cards"].get(uid, {}).get("choice", ""))
	for ch in d.get("choices", []):
		if str(ch.get("id", "")) == choice and typeof(ch.get("check")) == TYPE_DICTIONARY:
			return int(ch["check"].get("need", 1))
	return int(d.get("check", {}).get("need", 0))


func _slot_views(uid: String) -> Array:
	var out: Array = []
	var placed: Dictionary = st["cards"].get(uid, {}).get("placed", {})
	for s in _slot_defs(uid):
		var pl: Array = placed.get(str(s.get("id", "")), [])
		var coins := 0
		for p in pl:
			coins += int(p.get("coins", 0))
		out.append({"id": str(s.get("id", "")), "accepts": (s.get("accepts", []) as Array).duplicate(),
			"attr": str(s.get("attr", "")), "wants": (s.get("tags", []) as Array).duplicate(),
			"required": bool(s.get("required", false)), "max": int(s.get("max", 1)), "placed": pl.duplicate(true),
			"coins": coins})
	return out


func _preview(uid: String) -> Dictionary:
	var coins := 0
	var heads := 0
	var auto := false
	for sv in _slot_views(uid):
		for p in sv["placed"]:
			coins += int(p.get("coins", 0))
			heads += int(p.get("heads", 0))
			auto = auto or bool(p.get("auto_pass", false))
	return {"coins": coins, "auto_heads": heads, "need": _need(uid), "auto_pass": auto}


func _choices(uid: String) -> Array:
	var out: Array = []
	for ch in _def(uid).get("choices", []):
		var cost := int(ch.get("cost", {}).get("money", 0))
		out.append({"id": str(ch.get("id", "")), "enabled": cost <= int(st["money"]),
			"reason_key": "" if cost <= int(st["money"]) else "g03.reason.money", "has_check": ch.has("check")})
	return out


func _choose(uid: String, choice: String) -> Dictionary:
	var d := _def(uid)
	if d.is_empty():
		return _err("unknown_uid")
	var ch: Dictionary = {}
	for c in d.get("choices", []):
		if str(c.get("id", "")) == choice:
			ch = c
	if ch.is_empty():
		return _err("no_such_choice")
	if ch.has("check"):
		st["cards"][uid]["choice"] = choice
		_first("coins", {"uid": uid})
		_ev(["card_updated", uid])
		return _ok({"needs_slots": true})
	for e in ch.get("effects", []):
		match str(e.get("op", "")):
			"add_card":
				var nuid := _spawn(str(e["card"]), str(e.get("to", "hand")))
				_ev(["cards_dealt", PackedStringArray([nuid])])
				if str(e.get("to", "")) == "kept":
					_first("keep", {"uid": nuid, "def": str(e["card"])})
			"dossier":
				_dossier(str(e["frag"]))
			"money":
				_money(int(e.get("delta", 0)), str(e.get("reason", "")))
	_leave(uid, "resolved")
	return _ok({"needs_slots": false})


func _place(uid: String, slot_id: String, source: Dictionary) -> Dictionary:
	var c: Dictionary = st["cards"].get(uid, {})
	if c.is_empty():
		return _err("unknown_uid")
	var sdef: Dictionary = {}
	for s in _slot_defs(uid):
		if str(s.get("id", "")) == slot_id:
			sdef = s
	if sdef.is_empty():
		return _err("bad_args")
	var kind := str(source.get("kind", ""))
	if not (sdef.get("accepts", []) as Array).has(kind):
		return _err("slot_reject")
	var row := source.duplicate(true)
	row["coins"] = 0
	row["heads"] = 0
	row["auto_pass"] = false
	match kind:
		"self":
			if bool(st["used_self"]):
				return _err("person_busy")
			st["used_self"] = true
			row["uid"] = st["self_uid"]
			row["coins"] = int(SELF_ATTRS.get(str(sdef.get("attr", "nerve")), 1))
		"contact":
			row["coins"] = int(_def(str(source.get("uid", ""))).get("attrs", {}).get(str(sdef.get("attr", "pull")), 1))
			_first("contact", {})
		"money":
			row["coins"] = int(source.get("amount", 0)) / maxi(1, int(sdef.get("money_per_coin", 10)))
		"kept":
			for b in _def(str(source.get("uid", ""))).get("slot_bonus", []):
				var tags: Array = sdef.get("tags", [])
				for t in b.get("slot_tags_any", []):
					if tags.has(t):
						row["heads"] = int(b.get("heads", 0))
						row["coins"] = int(b.get("coins", 0))
						row["auto_pass"] = bool(b.get("auto_pass", false))
		_:
			row["coins"] = 1
	var placed: Dictionary = c.get("placed", {})
	if not placed.has(slot_id):
		placed[slot_id] = []
	(placed[slot_id] as Array).append(row)
	c["placed"] = placed
	_first("coins", {"uid": uid})
	_ev(["card_updated", uid])
	return _ok({"coins": row["coins"]})


func _roll(uid: String) -> Dictionary:
	var c: Dictionary = st["cards"].get(uid, {})
	if c.is_empty():
		return _err("unknown_uid")
	var p := _preview(uid)
	var attempt := int(st["attempts"].get(uid, 0))
	st["attempts"][uid] = attempt + 1
	var faces: Array = []
	var heads := int(p["auto_heads"])
	for i in range(mini(int(p["coins"]), 12)):
		var face := JevRng.draw(seed_value, "c.mock", ["coin", uid, attempt, i]) < 0.5
		faces.append(face)
		heads += 1 if face else 0
	var need := int(p["need"])
	var success := bool(p["auto_pass"]) or heads >= need
	for sv in _slot_views(uid):
		for row in sv["placed"]:
			if str(row.get("kind", "")) == "money":
				_money(-int(row.get("amount", 0)), "w0.mock.slot_money")
	_ev(["coins_tossed", uid, faces, need, success])
	if not success and str(_def(uid).get("id", "")) == "ev.1938.police_check":
		st["heat_tier"] = int(st["heat_tier"]) + 1
		_ev(["tier_changed", &"heat", int(st["heat_tier"]) - 1, int(st["heat_tier"])])
		_first("tier_heat", {})
	_leave(uid, "resolved")
	return _ok({"faces": faces, "heads": heads, "need": need, "success": success})


func _keep(uid: String) -> Dictionary:
	var c: Dictionary = st["cards"].get(uid, {})
	if c.is_empty():
		return _err("unknown_uid")
	var d := _def(uid)
	if bool(d.get("gold", false)) or not (str(d.get("type", "")) == "kept" or bool(d.get("keepable", false))):
		return _err("not_keepable")
	if (st["zones"]["kept"] as Array).size() >= 5:
		_first("kept_full", {"uid": uid})
		return _err("kept_full")
	st["zones"][c["zone"]].erase(uid)
	st["zones"]["kept"].append(uid)
	c["zone"] = "kept"
	if int(c.get("expires_in", -1)) <= 0:
		c["expires_in"] = int(d.get("expires_days", 0)) if int(d.get("expires_days", 0)) > 0 else -1
	_first("keep", {"uid": uid})
	_ev(["card_updated", uid])
	return _ok()


# ---------------- 轮盘 ----------------
func _wheel(wheel_id: String, uid: String) -> Dictionary:
	var key := "%s:%s" % [wheel_id, uid]
	if not st["wheels"].has(key):
		st["wheels"][key] = {"placed": [], "staked": "", "spun": false, "segment": "", "stop_mdeg": 0, "spin_no": 0}
	return st["wheels"][key]


func _segments(wheel_id: String) -> Array:
	var era := str(db.stage(int(st["stage"])).get("era", "1938"))
	var out: Array = []
	for id in db.ids_of(&"wheel_segment"):
		var d := db.def(id)
		var eras: Array = d.get("era", [])
		if str(d.get("wheel", "")) == wheel_id and (eras.has("*") or eras.has(era)):
			out.append(d)
	out.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return db.order_of(str(x["id"])) < db.order_of(str(y["id"])))
	return out


func _units(wheel_id: String, uid: String) -> int:
	var w := _wheel(wheel_id, uid)
	var inc: Dictionary = db.def(wheel_id).get("incense", {})
	var u := 0
	var money := 0
	for p in w["placed"]:
		match str(p.get("kind", "")):
			"money":
				money += int(p.get("amount", 0))
			"kept":
				u += int(_def(str(p.get("uid", ""))).get("incense_units", 1))
			"contact":
				u += int(_def(str(p.get("uid", ""))).get("attrs", {}).get(str(inc.get("contact_attr", "pull")), 1))
	u += money / maxi(1, int(inc.get("money_per_unit", 5)))
	return mini(u, int(inc.get("max_units", 6)))


func _wheel_weights(wheel_id: String, uid: String) -> Array:
	var units := _units(wheel_id, uid)
	var widen := int(db.def(wheel_id).get("incense", {}).get("unit_widen_pct", 15))
	var rows: Array = []
	for s in _segments(wheel_id):
		var good := str(s.get("valence", "")) == "good"
		rows.append([str(s["id"]), int(s.get("arc", 1)) * (100 + units * widen if good else 100)])
	return rows


func _wheel_view(wheel_id: String, uid: String) -> Dictionary:
	var w := _wheel(wheel_id, uid)
	var rows := _wheel_weights(wheel_id, uid)
	var total := 0
	for r in rows:
		total += int(r[1])
	var segs: Array = []
	for r in rows:
		segs.append({"id": r[0], "arc_deg": 360.0 * float(r[1]) / float(maxi(1, total)),
			"art": str(db.def(str(r[0])).get("art", ""))})
	var wd := db.def(wheel_id)
	var cost: Dictionary = wd.get("cost", {})
	return {"wheel": wheel_id, "uid": uid, "kind": str(wd.get("kind", "")), "art": str(wd.get("art", "")),
		"segments": segs, "incense": {"accepts": (wd.get("incense", {}).get("accepts", []) as Array).duplicate(),
			"placed": (w["placed"] as Array).duplicate(true), "full": _units(wheel_id, uid) >= int(wd.get("incense", {}).get("max_units", 6))},
		"cost": {"money": int(cost.get("money", 0)), "stake": bool(cost.get("stake", false))}, "staked": w["staked"],
		"spun": w["spun"], "result": {"segment": w["segment"], "stop_deg": float(w["stop_mdeg"]) / 1000.0}}


func _wheel_offer(a: Dictionary) -> Dictionary:
	var w := _wheel(str(a.get("wheel", "")), str(a.get("uid", "")))
	(w["placed"] as Array).append((a.get("source", {}) as Dictionary).duplicate(true))
	_first("incense", {})
	st["almanac_done"].append("pray")
	return _ok()


func _wheel_spin(wheel_id: String, uid: String) -> Dictionary:
	var w := _wheel(wheel_id, uid)
	if bool(w["spun"]):
		return _err("already_resolved")
	var rows := _wheel_weights(wheel_id, uid)
	if rows.is_empty():
		return _err("bad_args")
	var u := JevRng.draw(seed_value, "c.mock", ["wheel", wheel_id, uid, int(w["spin_no"])])
	var seg := JevRng.weighted_choice(rows, u)
	for p in w["placed"]:
		if str(p.get("kind", "")) == "money":
			_money(-int(p.get("amount", 0)), "w0.mock.incense")
	w["spun"] = true
	w["spin_no"] = int(w["spin_no"]) + 1
	w["segment"] = seg
	w["stop_mdeg"] = int(u * 360000.0)
	_ev(["wheel_spun", wheel_id, seg, float(w["stop_mdeg"]) / 1000.0])
	if wheel_id == "wh.month":
		st["fortune"] = seg
		st["open_panel"] = {"kind": "", "args": {}}
	elif uid != "":
		_leave(uid, "resolved")
	return _ok({"segment": seg, "stop_deg": float(w["stop_mdeg"]) / 1000.0})


# ---------------- 杂项 ----------------
func _actions(uid: String) -> Array:
	var d := _def(uid)
	var c: Dictionary = st["cards"].get(uid, {})
	var out: Array = []
	if d.is_empty():
		return out
	if CardViewModel.panel_of(d) != &"none":
		out.append({"id": "open", "enabled": true, "reason_key": ""})
	var keepable := (str(d.get("type", "")) == "kept" or bool(d.get("keepable", false))) and not bool(d.get("gold", false))
	if keepable and str(c.get("zone", "")) == "hand":
		out.append({"id": "keep", "enabled": true, "reason_key": ""})
	if str(d.get("type", "")) == "news":
		out.append({"id": "read", "enabled": true, "reason_key": ""})
	if str(CardViewModel.panel_of(d)) == "counter":
		out.append({"id": "refuse", "enabled": true, "reason_key": ""})
	for ch in _choices(uid):
		out.append({"id": "choose:" + str(ch["id"]), "enabled": ch["enabled"], "reason_key": ch["reason_key"]})
	return out


func _almanac() -> Dictionary:
	return {"id": "alm.shoudang", "yi": ["pawn_in", "meet"], "ji": ["travel"],
		"done": (st["almanac_done"] as Array).duplicate()}


func _estates_view() -> Array:
	var out: Array = []
	for es in st["estates"].keys():
		var d := db.def(es)
		out.append({"id": es, "status": st["estates"][es], "money": int(d.get("mortgage_value", 0)),
			"interest_money": int(d.get("mortgage_value", 0)) * int(d.get("interest_pct_month", 0)) / 100})
	return out


func _dossier(frag: String, gap: bool = false) -> void:
	var fd := db.def(frag)
	var person := str(fd.get("person", frag.get_slice(".", 1)))
	if not st["dossier"].has(person):
		st["dossier"][person] = {"have": [], "gaps": []}
	var page: Dictionary = st["dossier"][person]
	if gap:
		if not (page["gaps"] as Array).has(frag):
			page["gaps"].append(frag)
			_ev(["dossier_changed", person, frag, &"gap"])
			_first("dossier_gap", {"person": person})
		return
	if (page["have"] as Array).has(frag) or (page["gaps"] as Array).has(frag):
		return
	page["have"].append(frag)
	st["dossier_new"] = int(st["dossier_new"]) + 1
	_ev(["dossier_changed", person, frag, &"added"])
	_first("dossier", {"person": person})


func _dossier_view() -> Dictionary:
	var pages: Array = []
	var persons: Array = st["dossier"].keys()
	persons.sort()
	for person in persons:
		var page: Dictionary = st["dossier"][person]
		var frags: Array = []
		for f in page["have"]:
			frags.append({"id": f, "order": int(db.def(f).get("order", 0)), "era": str(db.def(f).get("era", ["1938"])[0]),
				"kind": str(db.def(f).get("kind", "")), "state": "have", "new": true})
		for f in page["gaps"]:
			frags.append({"id": f, "order": int(db.def(f).get("order", 0)), "era": str(db.def(f).get("era", ["1938"])[0]),
				"kind": str(db.def(f).get("kind", "")), "state": "gap", "new": false})
		pages.append({"person": person, "complete": false, "new": (page["have"] as Array).size(), "fragments": frags})
	return {"pages": pages}


func _add_item(cat: String, variant: String, on_shelf: bool) -> String:
	st["item_seq"] = int(st["item_seq"]) + 1
	var iid := "I%03d" % int(st["item_seq"])
	var base := 30
	var templates = CardDB.read_json("res://data/town/item_templates.json")
	if typeof(templates) == TYPE_DICTIONARY:
		for v in templates.get("categories", {}).get(cat, {}).get("variants", []):
			if str(v.get("id", "")) == variant:
				base = int(v.get("base_price", 30))
	st["items"][iid] = {"cat": cat, "variant": variant, "base": base, "observations": [], "on_shelf_since": -1}
	if on_shelf:
		st["shelf"].append(iid)
		st["items"][iid]["on_shelf_since"] = st["abs_day"]
	return iid


func _item_view(iid: String) -> Dictionary:
	var it: Dictionary = st["items"].get(iid, {})
	if it.is_empty():
		return {}
	return {"item": iid, "template": "%s.%s" % [it["cat"], it["variant"]], "cat": it["cat"], "art": _item_art(iid),
		"condition_word": 2, "observations": (it["observations"] as Array).duplicate(), "on_shelf_since": it["on_shelf_since"]}


func _item_art(iid: String) -> String:
	var it: Dictionary = st["items"].get(iid, {})
	return "item.%s.%s" % [it.get("cat", ""), it.get("variant", "")] if not it.is_empty() else ""


func _pick_variant(cat: String, uid: String) -> String:
	var templates = CardDB.read_json("res://data/town/item_templates.json")
	var ids: Array = []
	if typeof(templates) == TYPE_DICTIONARY:
		for v in templates.get("categories", {}).get(cat, {}).get("variants", []):
			ids.append(str(v.get("id", "")))
	ids.sort()
	if ids.is_empty():
		return "bowl"
	return str(ids[int(JevRng.draw(seed_value, "c.mock", ["variant", uid]) * ids.size())])


func _spawn(def_id: String, zone: String) -> String:
	var uid := _new_uid()
	var d := db.def(def_id)
	st["cards"][uid] = {"def": def_id, "zone": zone, "status": "open", "placed": {}, "choice": "",
		"expires_in": int(d.get("expires_days", 0)) if _counts_down(d, zone) else -1,
		"days_left": int(d.get("due_days", -1)) if d.has("due_days") else -1}
	if str(d.get("type", "")) == "demand":
		st["cards"][uid]["tier"] = int(d.get("tier", 0))
	st["zones"][zone].append(uid)
	if zone == "hand":
		_order_hand()
	return uid


## 能留的牌留着、或在手上（消息、信物）就开始倒计时（§7.4.7：手上没处理的能留的牌明天接着算）
func _counts_down(d: Dictionary, zone: String) -> bool:
	if int(d.get("expires_days", 0)) <= 0 or bool(d.get("gold", false)):
		return false
	return zone == "kept" or (zone == "hand" and (str(d.get("type", "")) == "kept" or bool(d.get("keepable", false))))


## 和 G01 的 order_hand 同一个顺序：hand_order 的先后，金色牌按 schedule.order，再按发到手上的先后
func _order_hand() -> void:
	var order: Array = db.rules("deal").get("hand_order", [])
	var keyed: Array = []
	for uid in st["zones"]["hand"]:
		var d := _def(uid)
		var rank := order.find("gold") if bool(d.get("gold", false)) else order.find(str(d.get("type", "")))
		keyed.append([rank if rank >= 0 else order.size(), int(str(uid).substr(1)), uid])
	keyed.sort_custom(func(x: Array, y: Array) -> bool: return x[0] < y[0] if x[0] != y[0] else x[1] < y[1])
	st["zones"]["hand"] = keyed.map(func(r: Array) -> String: return str(r[2]))


func _leave(uid: String, reason: String, extra: Dictionary = {}) -> Dictionary:
	var c: Dictionary = st["cards"].get(uid, {})
	if c.is_empty():
		return _err("unknown_uid")
	st["zones"][c["zone"]].erase(uid)
	c["zone"] = "discard"
	c["status"] = reason
	st["counter"].erase(uid)
	if str(st["open_panel"].get("args", {}).get("uid", "")) == uid:
		st["open_panel"] = {"kind": "", "args": {}}
	_ev(["card_left", uid, StringName(reason)])
	return _ok(extra)


func _money(delta: int, reason: String) -> void:
	if delta == 0:
		return
	var old := int(st["money"])
	st["money"] = old + delta
	_ev(["money_changed", old, int(st["money"]), reason])


func _set_phase(p: String) -> void:
	var from := str(st["phase"])
	st["phase"] = p
	if from != p:
		_ev(["phase_changed", StringName(from), StringName(p)])


func _first(mech: String, args: Dictionary) -> void:
	if st["firsts"].has(mech) or not CardIds.FIRSTS.has(StringName(mech)):
		return
	st["firsts"][mech] = st["abs_day"]
	_ev(["first_time", StringName(mech), args.duplicate()])


func _ev(row: Array) -> void:
	events.append(row)


func _def(uid: String) -> Dictionary:
	var c: Dictionary = st["cards"].get(uid, {})
	return db.def(str(c["def"])) if not c.is_empty() else {}


func _new_uid() -> String:
	st["uid_seq"] = int(st["uid_seq"]) + 1
	return "c%04d" % int(st["uid_seq"])


func _is_market(stage_day: int) -> bool:
	var s := db.stage(int(st["stage"]))
	var every := int(s.get("market_every", 5))
	return stage_day > 0 and every > 0 and posmod(stage_day - 1 - int(s.get("market_offset", 2)), every) == 0


func _date(stage_day: int) -> Array:
	var parts := str(db.stage(int(st["stage"])).get("start", "1938-03-01")).split("-")
	var days := CardCalendar.days_from_civil(int(parts[0]), int(parts[1]), int(parts[2])) + maxi(stage_day, 1) - 1
	var ymd := CardCalendar.civil_from_days(days)
	return [ymd[0], ymd[1], ymd[2], posmod(days + 3, 7)]


func _ok(extra: Dictionary = {}) -> Dictionary:
	var r := {"ok": true, "err": ""}
	r.merge(extra, true)
	return r


func _err(code: String) -> Dictionary:
	return {"ok": false, "err": code}
