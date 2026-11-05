# [shop-only] 保护费：维持会的人（胡二）每天上门收一份，是「只守铺子」版里最主要的生活压力。
# 数据全在 data/town/protection.json；状态存在导演账上 vars["town"]["protect"]（随存档走，全是整数/字符串，没有浮点）。
# 每天的上门钟点、基数、浮动都用 JevRng（种子 + 日期）抽，同一个种子每次一样。
# 玩家看不到公式：收钱的人只在对白里报一个数；底价（能不能讲价、讲到哪）是隐藏的。
extends RefCounted

const R = preload("res://scripts/sim/jev_rng.gd")
const Rules = preload("res://scripts/town/rules.gd")
const PATH := "res://data/town/protection.json"

static var _cfg: Dictionary = {}

static func config() -> Dictionary:
	if _cfg.is_empty() and FileAccess.file_exists(PATH):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		if typeof(parsed) == TYPE_DICTIONARY:
			_cfg = parsed
	return _cfg

static func clear() -> void:
	_cfg = {}

# 一天里结了的状态（不再改）
const RESOLVED := ["paid", "haggled", "delayed", "refused", "goods", "missed", "skipped"]

var d = null            # 导演

func _init(p_director) -> void:
	d = p_director

# ====================================================================
# 状态
func active() -> bool:
	if d == null or not d._is_town():
		return false
	return d.shop_only() or bool(config().get("always", false))

func st() -> Dictionary:
	var town: Dictionary = d._town_state()
	if not town.has("protect") or typeof(town["protect"]) != TYPE_DICTIONARY:
		town["protect"] = {}
	var p: Dictionary = town["protect"]
	var defaults := {"owed": 0, "strikes": 0, "streak": 0, "delay_chain": 0, "missed": 0, "boycott_day": -1,
		"told": false, "days": {}, "history": [], "paid_total": 0, "seized_total": 0}
	for k in defaults:
		if not p.has(k):
			p[k] = defaults[k].duplicate(true) if defaults[k] is Dictionary or defaults[k] is Array else defaults[k]
	return p

# 眼下欠着的保护费（家用簿里看得见；不在守铺的局里是 0）
func owed_now() -> int:
	return int(st()["owed"]) if active() else 0

func entry(day: int = -1) -> Dictionary:
	var key := str(d.world.day if day < 0 else day)
	return st()["days"].get(key, {})

func collector() -> String:
	return str(config().get("collector", "hu2"))

func payee() -> String:
	return str(config().get("payee", "维持会公账"))

func _seed() -> int:
	return int(d.world.town.s["seed"])

func _draw(domain: String, key: Array) -> float:
	return R.draw(_seed(), "protect:" + domain, key)

func visit_id(day: int = -1) -> String:
	return "protect_d%d" % (d.world.day if day < 0 else day)

# 第一天：哥哥还没交代过之前，收钱的人不上门（不能没说就罚）
func visible() -> bool:
	return d.world.day > 1 or bool(st()["told"])

# ====================================================================
# 每天的一笔
func ensure_day() -> Dictionary:
	var day: int = d.world.day
	var p := st()
	var key := str(day)
	if p["days"].has(key):
		return p["days"][key]
	var c: Dictionary = config()
	var v: Dictionary = c.get("visit", {})
	var lo := int(v.get("earliest", 600))
	var hi := int(v.get("latest", 990))
	var minute := lo + int(floor(_draw("minute", [day]) * float(hi - lo + 1)))
	var calc := compute_amount(day)
	var e := {"day": day, "minute": minute, "who": collector(), "status": "pending", "received": false,
		"base": int(calc["base"]), "today": int(calc["today"]), "backlog": int(calc["backlog"]),
		"amount": int(calc["total"]), "floor": int(calc["floor"]), "paid": 0, "goods": [], "goods_value": 0,
		"owed_after": 0, "level": 0, "haggled": false}
	p["days"][key] = e
	return e

# 今天要多少：基数 × 星期 × 集日 × (1 + 热度/动荡/怀疑/前科 − 连着按时付) × 抖动 × 难度，再加欠着的
func compute_amount(day: int) -> Dictionary:
	var c: Dictionary = config()
	var a: Dictionary = c.get("amount", {})
	var h: Dictionary = c.get("haggle", {})
	var p := st()
	var town = d.world.town
	var range_a: Array = a.get("base_range", [15, 40])
	var lo := int(range_a[0])
	var hi := int(range_a[1])
	var base := lo + int(floor(_draw("base", [day]) * float(hi - lo + 1)))
	var wk: Array = a.get("weekday_mult", [1.0])
	var mult := float(wk[d.world.weekday(day) % wk.size()])
	if town._market_day():
		mult *= float(a.get("market_day_mult", 1.0))
	var heat := float(town.s["pressures"].get("heat", 0.0))
	var unrest := float(town.s["pressures"].get("unrest", 0.0))
	var susp := float(d.world.stat("suspicion"))
	var strikes := mini(int(p["strikes"]), int(a.get("strike_cap", 4)))
	var streak := mini(int(p["streak"]), int(a.get("streak_cap", 4)))
	var factor := 1.0 + heat * float(a.get("heat_gain", 0.0)) + unrest * float(a.get("unrest_gain", 0.0)) \
		+ susp * float(a.get("suspicion_gain", 0.0)) + float(strikes) * float(a.get("strike_gain", 0.0)) \
		- float(streak) * float(a.get("streak_discount", 0.0))
	factor = maxf(0.5, factor)
	var jitter := float(a.get("jitter", 0.0))
	var jit := 1.0 + jitter * (2.0 * _draw("jitter", [day]) - 1.0)
	var diff_name := str(town.s.get("difficulty", "常年"))
	var diff_mult := float(town.pack.get("difficulty", {}).get(diff_name, {}).get("cost_mult", 1.0))
	var today := clampi(int(round(float(base) * mult * factor * jit * diff_mult)), int(a.get("min_today", 1)), int(a.get("max_today", 999)))
	var backlog := int(p["owed"])
	var total := mini(today + backlog, int(a.get("max_total", 999)))
	var ratio := float(h.get("floor_base", 0.7)) + heat * float(h.get("floor_heat", 0.0)) + unrest * float(h.get("floor_unrest", 0.0)) \
		+ float(strikes) * float(h.get("floor_strike", 0.0)) + float(streak) * float(h.get("floor_streak", 0.0)) \
		+ float(h.get("floor_jitter", 0.0)) * (2.0 * _draw("floor", [day]) - 1.0)
	ratio = clampf(ratio, float(h.get("floor_min", 0.5)), float(h.get("floor_max", 1.0)))
	return {"base": base, "today": today, "backlog": backlog, "total": total, "floor": maxi(1, int(round(float(total) * ratio))), "ratio_x100": int(round(ratio * 100.0))}

# ====================================================================
# 每天一早：排今天的来访、处理断客
func on_day_start() -> void:
	if not active() or d.world.day < int(config().get("from_day", 1)):
		return
	var e := ensure_day()
	var p := st()
	# 上回不给，今天街坊绕着走：这一天里随机来的客人都不来（剧情里的人、收钱的人照旧）
	if int(p["boycott_day"]) == d.world.day and not bool(e.get("boycott_done", false)):
		e["boycott_done"] = true
		var keep: Array = []
		var dropped := 0
		for visit in d.world.town.s["visits"]:
			if str(visit.get("storylet", "")) != "" or str(visit.get("intent", "")) == "protect":
				keep.append(visit)
			else:
				dropped += 1
		d.world.town.s["visits"].clear()
		d.world.town.s["visits"].append_array(keep)
		e["boycott_dropped"] = dropped
	# 把收钱的人排进今天的来访名单（和别的客人一样：到点进铺子，站在等候点，等你去柜台接）
	if str(e["status"]) == "pending":
		var vid := visit_id()
		var found := false
		for visit in d.world.town.s["visits"]:
			if str(visit.get("id", "")) == vid:
				found = true
		if not found:
			var v: Dictionary = config().get("visit", {})
			d.world.town.s["visits"].append({"id": vid, "who": str(e["who"]), "intent": "protect", "slot": 1, "storylet": "",
				"minute": int(e["minute"]), "patience_min": int(v.get("patience_min", 150)), "status": "planned",
				"script": "town_protect_visit", "session": {}})

# 告示上的话（不带数目）
func notice() -> Dictionary:
	if not active():
		return {}
	var t: Dictionary = config().get("text", {})
	var p := st()
	var out := {"text": str(t.get("notice", "")), "owed": int(p["owed"]) > 0, "boycott": int(p["boycott_day"]) == d.world.day}
	if bool(out["owed"]):
		out["owed_text"] = str(t.get("notice_owed", ""))
	if bool(out["boycott"]):
		out["boycott_text"] = str(t.get("notice_boycott", ""))
	return out

# 日结里的一行：[{text, kind}]
func summary_lines() -> Array:
	if not active():
		return []
	var t: Dictionary = config().get("text", {})
	var p := st()
	var e := entry()
	var lines: Array = []
	if e.is_empty():
		return lines
	match str(e["status"]):
		"paid": lines.append(str(t.get("summary_paid", "")) % int(e["paid"]))
		"haggled": lines.append(str(t.get("summary_haggled", "")) % int(e["paid"]))
		"delayed": lines.append(str(t.get("summary_delayed", "")) % int(e["owed_after"]))
		"refused": lines.append(str(t.get("summary_refused", "")))
		"goods": lines.append(str(t.get("summary_goods", "")) % "、".join(e["goods"]))
		"missed": lines.append(str(t.get("summary_missed", "")))
		"skipped": pass
		_: lines.append(str(t.get("summary_pending", "")))
	if str(e["status"]) in ["refused", "missed"] and not e["goods"].is_empty():
		lines.append(str(t.get("summary_goods", "")) % "、".join(e["goods"]))
	if int(p["owed"]) > 0:
		lines.append(str(t.get("summary_owed", "")) % int(p["owed"]))
	return lines

# ====================================================================
# 剧情动作（town_action 里 protect_* 走这里）
func act(name: String, _args: Dictionary = {}) -> Dictionary:
	if not active():
		return {"ok": false, "error": "protection_off"}
	match name:
		"protect_begin": return begin_visit()
		"protect_told": return on_told()
		"protect_pay": return pay()
		"protect_delay": return delay()
		"protect_refuse": return refuse()
		"protect_rule": Rules.tell(d.world, "rule_protect"); return {"ok": true}
		"protect_haggle": return {"ok": false, "error": "needs_session"}
	return {"ok": false, "error": "unknown_protect_act"}

# 哥哥交代过了：从这一刻起收钱的人才会来（第一天他的钟点往后挪，不早于“现在”之后一小会儿）
func on_told() -> Dictionary:
	var p := st()
	p["told"] = true
	Rules.tell(d.world, "rule_protect")
	if d.world.day == 1:
		var e := ensure_day()
		var minute := int(d.world.town.s.get("minute", 360))
		var gap := int(config().get("visit", {}).get("intro_gap_min", 20))
		if str(e["status"]) == "pending" and int(e["minute"]) < minute + gap:
			e["minute"] = minute + gap
			for visit in d.world.town.s["visits"]:
				if str(visit.get("id", "")) == visit_id():
					visit["minute"] = int(e["minute"])
	return {"ok": true}

# 玩家在柜台接他：把对白要用的几个数放进 vars（只放他会说出口的那一个数）
func begin_visit() -> Dictionary:
	var e := ensure_day()
	var p := st()
	var c: Dictionary = config()
	e["received"] = true
	var mood := "normal"
	if d.world.day == 1 or (int(p["paid_total"]) == 0 and int(p["strikes"]) == 0 and int(p["missed"]) == 0 and not _any_history()):
		mood = "first"
	if int(p["strikes"]) >= 1:
		mood = "angry"
	elif int(p["owed"]) > 0:
		mood = "owed"
	d.vars["protect_amount"] = int(e["amount"])
	d.vars["protect_mood"] = mood
	d.vars["protect_strikes"] = int(p["strikes"])
	d.vars["protect_owed"] = int(p["owed"])
	d.vars["protect_result"] = ""
	d.vars["protect_level"] = 0
	d.vars["protect_variant"] = int(floor(_draw("variant", [d.world.day]) * 3.0))
	d.vars["protect_owed_after"] = 0
	d.vars["protect_goods"] = ""
	d.vars["protect_can_haggle"] = 1 if (int(e["amount"]) >= int(c.get("haggle", {}).get("min_amount", 0)) and not bool(e["haggled"])) else 0
	d.vars["protect_can_delay"] = 1 if int(p["delay_chain"]) < int(c.get("delay", {}).get("max_chain", 1)) else 0
	d.vars["protect_cash_ok"] = 1 if d.world.cash() >= int(e["amount"]) else 0
	Rules.tell(d.world, "rule_protect")
	return {"ok": true, "amount": int(e["amount"]), "mood": mood}

func _any_history() -> bool:
	return not st()["history"].is_empty()

# ---------------- 照数给 ----------------
func pay() -> Dictionary:
	var e := ensure_day()
	if str(e["status"]) in RESOLVED:
		return {"ok": false, "error": "already_resolved"}
	var amount := int(e["amount"])
	if d.world.cash() >= amount:
		var j: String = d.world.ledger.transfer("player", payee(), amount, "保护费", visit_id(), "protect|%s|pay" % visit_id())
		if j == "":
			return {"ok": false, "error": "transfer_failed"}
		_settle_paid(e, amount, "paid")
		return {"ok": true, "result": "paid", "amount": amount}
	return _short_pay(e, amount)

func _settle_paid(e: Dictionary, paid: int, status: String) -> void:
	var p := st()
	var c: Dictionary = config()
	e["paid"] = paid
	e["status"] = status
	p["owed"] = 0
	p["delay_chain"] = 0
	p["streak"] = int(p["streak"]) + 1
	p["strikes"] = maxi(0, int(p["strikes"]) - int(c.get("refuse", {}).get("relief_on_pay", 1)))
	p["paid_total"] = int(p["paid_total"]) + paid
	d.vars["protect_result"] = status
	d.vars["protect_amount_paid"] = paid
	_log(e, status)
	d.world.note("消息", "保护费：付给维持会 %d 蚨%s。" % [paid, "（讲下价来）" if status == "haggled" else ""], "seen", collector())
	d.world.emit_signal("changed")

# 钱不够：他不空手走，拿货架上最值钱的一件抵
func _short_pay(e: Dictionary, amount: int) -> Dictionary:
	var item := _top_shelf_item()
	if item == "":
		# 货架上也没东西可拿：只好记账，算求缓一天（加利）
		var r := _do_delay(e, true)
		d.vars["protect_result"] = "owed"
		return r
	var p := st()
	var c: Dictionary = config()
	var credit := _credit_of(item)
	var name := _seize(e, item, credit, "钱不够，拿货抵")
	var cover := mini(amount, credit)
	var rest := amount - cover
	var left := rest
	var paid_cash := 0
	if rest > 0 and d.world.cash() >= rest:
		var j: String = d.world.ledger.transfer("player", payee(), rest, "保护费（余数）", visit_id(), "protect|%s|rest" % visit_id())
		if j != "":
			paid_cash = rest
			left = 0
	e["paid"] = paid_cash
	e["status"] = "goods"
	p["delay_chain"] = 0
	p["streak"] = 0
	if left > 0:
		p["owed"] = int(ceil(float(left) * (1.0 + float(c.get("delay", {}).get("surcharge", 0.25)))))
		e["owed_after"] = int(p["owed"])
	else:
		p["owed"] = 0
	d.vars["protect_result"] = "goods"
	d.vars["protect_goods"] = name
	_log(e, "goods")
	d.world.emit_signal("changed")
	return {"ok": true, "result": "goods", "goods": name, "credit": credit, "cash": paid_cash, "owed": int(p["owed"])}

# ---------------- 求缓一天 ----------------
func delay() -> Dictionary:
	var e := ensure_day()
	if str(e["status"]) in RESOLVED:
		return {"ok": false, "error": "already_resolved"}
	if int(st()["delay_chain"]) >= int(config().get("delay", {}).get("max_chain", 1)):
		return refuse()
	return _do_delay(e, false)

func _do_delay(e: Dictionary, forced: bool) -> Dictionary:
	var p := st()
	var owed := int(ceil(float(int(e["amount"])) * (1.0 + float(config().get("delay", {}).get("surcharge", 0.25)))))
	owed = mini(owed, int(config().get("amount", {}).get("max_total", 999)))
	p["owed"] = owed
	p["delay_chain"] = int(p["delay_chain"]) + 1
	p["streak"] = 0
	e["status"] = "delayed"
	e["owed_after"] = owed
	d.vars["protect_result"] = "delayed"
	d.vars["protect_owed_after"] = owed
	_log(e, "delayed")
	d.world.note("借条", "保护费：求缓一天，欠维持会 %d 蚨（加了利）。" % owed, "seen", collector())
	d.world.emit_signal("changed")
	return {"ok": true, "result": "delayed", "owed": owed, "forced": forced}

# ---------------- 不给 ----------------
func refuse(missed: bool = false) -> Dictionary:
	var e := ensure_day()
	if str(e["status"]) in RESOLVED:
		return {"ok": false, "error": "already_resolved"}
	var p := st()
	var c: Dictionary = config()
	p["strikes"] = int(p["strikes"]) + 1
	p["streak"] = 0
	p["delay_chain"] = 0
	var carry := float(c.get("refuse", {}).get("carry", 0.5))
	p["owed"] = int(ceil(float(int(e["amount"])) * carry))
	e["status"] = "missed" if missed else "refused"
	var ladder: Array = c.get("refuse", {}).get("escalation", [])
	var level := mini(int(p["strikes"]), ladder.size())
	e["level"] = level
	var step: Dictionary = ladder[level - 1] if level >= 1 and not ladder.is_empty() else {}
	var town = d.world.town
	if step.has("heat"):
		town.add_influence("heat", float(step["heat"]), "protect_refused")
	if step.has("unrest"):
		town.add_influence("unrest", float(step["unrest"]), "protect_refused")
	if step.has("koubei"):
		d.world.add("koubei", int(step["koubei"]), "没给维持会保护费")
	if step.has("suspicion"):
		d.world.add("suspicion", int(step["suspicion"]), "没给维持会保护费")
	if step.has("rumor") and town.pack.get("rumors", {}).has(str(step["rumor"])):
		town.plant_rumor(str(step["rumor"]), "ma")
	if int(step.get("boycott_days", 0)) > 0:
		p["boycott_day"] = d.world.day + 1
	var taken := ""
	if int(step.get("seize", 0)) > 0:
		var item := _top_shelf_item()
		if item != "":
			var credit := _credit_of(item)
			taken = _seize(e, item, credit, "不给保护费，拿货抵押")
			p["owed"] = maxi(0, int(p["owed"]) - credit)
	d.vars["protect_result"] = "refused"
	d.vars["protect_level"] = level
	d.vars["protect_goods"] = taken
	d.vars["protect_owed_after"] = int(p["owed"])
	e["owed_after"] = int(p["owed"])
	_log(e, str(e["status"]))
	d.world.note("消息", "保护费：没给。胡二%s。" % (("拿走了「%s」抵押" % taken) if taken != "" else "撂下话走了"), "seen", collector())
	d.world.emit_signal("changed")
	return {"ok": true, "result": "refused", "level": level, "goods": taken, "boycott": int(step.get("boycott_days", 0)) > 0}

# ---------------- 讲价 ----------------
func haggle_spec() -> Dictionary:
	var e := ensure_day()
	if str(e["status"]) in RESOLVED or bool(e["haggled"]):
		return {}
	e["haggled"] = true
	var amount := int(e["amount"])
	return {"id": "town_protect_" + str(e["day"]), "npc": collector(), "mode": "buy", "items": [],
		"ask": amount, "floor": mini(amount, int(e["floor"])), "_town_protect": visit_id(),
		"no_gossip": true, "show_floor": false,
		"labels": {"mode": "保护费", "ask": "他要", "refuse": "不讲了，回去选", "refuse_line": "（算了，不讲了。）", "tip": "（胡二等着。拨算盘出个价，或者点右边的选项。）", "no_inspect": true}}

func haggle_settle(price: int) -> Dictionary:
	var e := ensure_day()
	if str(e["status"]) in RESOLVED:
		return {"ok": false, "error": "already_resolved"}
	if price <= 0 or d.world.cash() < price:
		return {"ok": false, "error": "cash_short"}
	var j: String = d.world.ledger.transfer("player", payee(), price, "保护费（讲价）", visit_id(), "protect|%s|haggle" % visit_id())
	if j == "":
		return {"ok": false, "error": "transfer_failed"}
	e["negotiated_from"] = int(e["amount"])
	_settle_paid(e, price, "haggled")
	return {"ok": true, "result": "haggled", "amount": price}

# 议价结束：成交的已经在 haggle_settle 里付了；他走人了算不给（还恼了）；你自己收手回到选项里
func haggle_done(result: String) -> Dictionary:
	var e := ensure_day()
	if str(e["status"]) in RESOLVED:
		d.vars["protect_can_haggle"] = 0
		return {"ok": true, "result": str(e["status"])}
	d.vars["protect_can_haggle"] = 0
	if result == "leave":
		var r := refuse()
		d.vars["protect_result"] = "walkout"
		return r
	d.vars["protect_result"] = "backoff"
	return {"ok": true, "result": "backoff"}

# ---------------- 没人接他 ----------------
# 他等不到人，走了。头一回记作求缓，以后记作不给。返回一句给玩家的提示（空 = 没事发生）。
func left_unreceived() -> String:
	if not active() or not visible():
		return ""
	var e := ensure_day()
	if str(e["status"]) in RESOLVED:
		return ""
	var p := st()
	var c: Dictionary = config()
	p["missed"] = int(p["missed"]) + 1
	var as_delay: bool = int(p["missed"]) == 1 and str(c.get("missed", {}).get("first_as", "delay")) == "delay"
	if as_delay:
		_do_delay(e, true)
		e["status"] = "missed"
		_log(e, "missed")
		return "胡二等不到人，撂下话走了：明天连本带利一起算。"
	var r := refuse(true)
	var line := "胡二等不到人，脸一沉走了。"
	if str(r.get("goods", "")) != "":
		line += "货架上的「%s」叫他顺手拿走了。" % str(r["goods"])
	return line

func on_day_end() -> void:
	if not active():
		return
	var e := entry()
	if e.is_empty():
		return
	if str(e["status"]) in RESOLVED:
		return
	if not visible():
		e["status"] = "skipped"      # 第一天哥哥还没交代他就没来：不算
		return
	left_unreceived()

# ====================================================================
# 货架上最值钱的一件（自己的、没押给人的）
func _top_shelf_item() -> String:
	var best := ""
	var best_price := -1
	for row in d._town_shelf():
		var price := int(row["price"])
		if price > best_price or (price == best_price and str(row["iid"]) < best):
			best_price = price
			best = str(row["iid"])
	return best

func _credit_of(iid: String) -> int:
	var it: Dictionary = d.world.ledger.items[iid]
	var ratio := float(config().get("seize", {}).get("credit_ratio", 0.7))
	return maxi(1, int(round(float(d.world.market_now(it)) * ratio)))

func _seize(e: Dictionary, iid: String, credit: int, why: String) -> String:
	var it: Dictionary = d.world.ledger.items[iid]
	var name := str(it.get("name", iid))
	d.world.ledger.move_item(iid, "npc:" + collector(), collector(),
		"维持会的胡二拿去%s（%s，折 %d 蚨）" % [str(config().get("seize", {}).get("tag", "抵账")), why, credit])
	e["goods"].append(name)
	e["goods_value"] = int(e["goods_value"]) + credit
	var p := st()
	p["seized_total"] = int(p["seized_total"]) + 1
	d.world.note("消息", "胡二从货架上拿走了「%s」，折 %d 蚨抵保护费。" % [name, credit], "seen", collector())
	return name

func _log(e: Dictionary, status: String) -> void:
	var p := st()
	var h: Array = p["history"]
	for row in h:
		if int(row["day"]) == int(e["day"]):
			row["status"] = status
			row["paid"] = int(e["paid"])
			row["goods"] = e["goods"].duplicate()
			return
	h.append({"day": int(e["day"]), "status": status, "demanded": int(e["amount"]), "paid": int(e["paid"]), "goods": e["goods"].duplicate()})
