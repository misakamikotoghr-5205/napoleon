# 柜台一次接待：验货（有限信息）+ 双方议价（NPC 大脑决定让步 / 坚持 / 求情 / 离开）
# GameJev G04 验货是有成本的信息获取；NEG01 双方动态讨价还价；UX01 玩家看不到底价与概率
# （第一天例外：剧本要求把客人底价写在顾客下方 → def.show_floor）。
# 数据：data/sessions/<id>.json（docs/INTERFACES.md §6）
extends RefCounted

const Appraise = preload("res://scripts/core/appraise.gd")

signal changed

var world
var def: Dictionary = {}
var npc_id: String = ""
var mode: String = "buy"          # buy 收购 / pawn 活当 / sell 卖给客人
var item_ids: Array = []          # 物品实例 ID
var selected: Dictionary = {}     # iid -> bool（拆开按样出价）
var judged: Dictionary = {}       # iid -> "fake" / ""（玩家自己的判断）
var inspected: Dictionary = {}    # iid -> {part_id: true}
var circles: Dictionary = {}      # iid -> [{c:[x,y], r, tool, kind, pids, text, tone, pts}]：验货时用朱笔圈过的地方（一笔一条，再验一次原样画回去）
var base_ask: int = 0
var base_floor: int = 0
var ask: int = 0                  # 客人当前要价（显示）／卖货时：客人当前出价
var floor_v: int = 0              # 底价（隐藏，第一天显示）／卖货时：客人最多肯出
var suggestion: int = 0           # 建议价（规矩算出来的，不是对方底价）
var show_floor: bool = false
var hard_floor: bool = false
var fund_button: bool = false
var split: bool = false
var min_inspect: int = 0
var hint: String = ""
var est_lo: int = 0
var est_hi: int = 0
var rounds: int = 0
var last_offer: int = 0
var price: int = 0                # 成交价
var used_extras: Dictionary = {}
var pending_events: Array = []    # 验货触发的剧情事件（on_inspect）
var closed: bool = false
var result: String = ""           # accept / leave / deal:<id> / <end result>
var last_npc_line: String = ""
var vars: Dictionary = {}

func setup(p_world, p_def: Dictionary) -> void:
	world = p_world
	def = p_def
	npc_id = str(def.get("npc", ""))
	mode = str(def.get("mode", "buy"))
	show_floor = bool(def.get("show_floor", false))
	hard_floor = bool(def.get("hard_floor", false))
	fund_button = bool(def.get("fund_button", false))
	split = bool(def.get("split", false))
	min_inspect = int(def.get("min_inspect", 0))
	hint = str(def.get("hint", ""))
	var est: Array = def.get("est", [0, 0])
	est_lo = int(est[0])
	est_hi = int(est[1])
	if mode == "sell":
		_setup_sell()
	else:
		for it in def.get("items", []):
			var iid: String = world.ledger.add_item(_item_def(str(it["def"])), npc_id, "counter")
			_add(iid)
		base_ask = int(def.get("ask", 0))
		base_floor = int(def.get("floor", 0))
		ask = base_ask
		floor_v = base_floor
		suggestion = int(def.get("suggest", 0))
		if mode == "buy":
			suggestion = calc_buy_suggest()
		if est_lo == 0 and est_hi == 0:
			_est_from_items()

func _item_def(def_id: String) -> Dictionary:
	var d: Dictionary = world.db.items.get(def_id, {}).duplicate(true)
	if d.is_empty():
		push_error("未知物品：" + def_id)
		d = {"name": def_id, "cat": "scrap", "market": 0, "parts": []}
	d["def_id"] = def_id
	return d

func _add(iid: String) -> void:
	item_ids.append(iid)
	selected[iid] = true
	judged[iid] = ""
	inspected[iid] = {}

func _setup_sell() -> void:
	var prices: Dictionary = def.get("buyer_prices", {})
	for d in def.get("stock", []):
		for iid in world.ledger.items_at("stock"):
			var it: Dictionary = world.ledger.items[iid]
			if world.town != null and (str(it.get("owner", "")) != "player" or str(it.get("pledged_to", "")) != ""):
				continue      # 小镇：只卖自己的、没押给人的架上货
			if it.get("def_id", "") == d and not item_ids.has(iid):
				_add(iid)
				for p in it.get("parts", []):
					pass
				break
	_rescale_sell(prices)
	base_ask = ask
	base_floor = floor_v
	_est_from_items()

func _rescale_sell(prices: Dictionary = {}) -> void:
	# v0.3：统一定价——客人心价以当日市价为锚，buyer_prices 只作性格修正；可只勾一件卖
	if prices.is_empty():
		prices = def.get("buyer_prices", {})
	var o := 0
	var m := 0
	var sug := 0
	for iid in item_ids:
		if not selected.get(iid, false):
			continue
		var it: Dictionary = item(iid)
		var bp: Dictionary = prices.get(it["def_id"], {})
		var market: int = int(world.market_now(it))
		var tidy_m: float = 1.0 + float(it.get("tidy_bonus", 0.0)) + float(it.get("market_bonus", 0.0))
		# 锚：市价；剧本 offer/max 若有，按相对市价的比例修正，避免「收贵卖贱」脱节
		var base_market := maxf(1.0, float(it.get("market", market)))
		var offer_ratio := float(bp["offer"]) / base_market if bp.has("offer") else 0.85
		var max_ratio := float(bp["max"]) / base_market if bp.has("max") else 1.05
		offer_ratio = clampf(offer_ratio, 0.5, 1.2)
		max_ratio = clampf(maxf(max_ratio, offer_ratio), 0.55, 1.35)
		o += int(round(float(market) * offer_ratio * tidy_m))
		m += int(round(float(market) * max_ratio * tidy_m))
		sug += market
	var have: int = world.ledger.balance(npc_id)
	ask = mini(maxi(o, 1), have) if have > 0 else maxi(o, 1)
	floor_v = mini(maxi(m, ask), have) if have > 0 else maxi(m, ask)
	suggestion = sug

func _est_from_items() -> void:
	var lo := 0
	var hi := 0
	for iid in item_ids:
		var e: Array = item(iid).get("est", [0, 0])
		lo += int(e[0])
		hi += int(e[1])
	est_lo = lo
	est_hi = hi

func item(iid: String) -> Dictionary:
	return world.ledger.items[iid]

func iid_of(def_id: String) -> String:
	for iid in item_ids:
		if item(iid).get("def_id", "") == def_id:
			return iid
	return ""

func npc() -> Dictionary:
	return world.npcs[npc_id]

# ---------------- 验货 ----------------
# 每点一个部位揭开一条结果，写进档案簿；可能缩小心里估价；需要工具时检查解锁
func can_use_tool(tool: String) -> bool:
	match tool:
		"scale": return world.unlocked.get("scale", false)
		"book": return world.unlocked.get("medbook", false)
	return true

func inspect(iid: String, pid: String) -> String:
	if not item_ids.has(iid) and not world.ledger.items.has(iid):
		return ""
	var it: Dictionary = world.ledger.items[iid]
	if not inspected.has(iid):
		inspected[iid] = {}
	for p in it.get("parts", []):
		if p["id"] != pid:
			continue
		if inspected[iid].has(pid):
			return p["text"]
		var tool := str(p.get("tool", "magnifier"))
		if not can_use_tool(tool):
			return "（还用不上%s。）" % {"scale": "小秤", "book": "鉴别录"}.get(tool, tool)
		inspected[iid][pid] = true
		var text: String = str(p["text"])
		if p.has("est") and item_ids.size() == 1:
			var e: Array = p["est"]
			est_lo = clampi(maxi(est_lo, int(e[0])), 0, 1 << 30)
			est_hi = mini(est_hi, int(e[1])) if est_hi > 0 else int(e[1])
			if est_lo > est_hi:
				est_lo = int(e[0])
				est_hi = int(e[1])
		if p.has("flag") and str(p["flag"]) != "":
			world.flags[p["flag"]] = true
		if str(p.get("event", "")) != "":
			pending_events.append(str(p["event"]))
		if p.has("weight") or tool == "scale":
			it["weighed"] = true
		world.note("鉴定", "%s · %s：%s" % [it["name"], p["label"], text], "seen")
		p["_shown"] = text
		emit_signal("changed")
		return text
	return ""

func is_inspected(def_id: String, pid: String) -> bool:
	var iid := iid_of(def_id)
	if iid == "":
		return false
	return inspected.get(iid, {}).has(pid)

func inspected_total() -> int:
	var n := 0
	for iid in inspected:
		n += inspected[iid].size()
	return n

func tells_found(def_id: String) -> int:
	var iid := iid_of(def_id)
	if iid == "":
		return 0
	var n := 0
	for p in item(iid).get("parts", []):
		if p.get("tell", false) and inspected[iid].has(p["id"]):
			n += 1
	return n

func set_judged(iid: String, v: String) -> void:
	judged[iid] = v
	if mode == "buy":
		suggestion = calc_buy_suggest()
	emit_signal("changed")

func set_selected(iid: String, on: bool) -> void:
	selected[iid] = on
	if mode == "sell":
		_rescale_sell()
	else:
		_rescale_ask()
	emit_signal("changed")

func toggle_selected(iid: String) -> void:
	set_selected(iid, not selected.get(iid, true))

# 东西被拿回去了（客人收回、塞还……）：不再算在这笔买卖里
func withdraw(iid: String) -> void:
	if not item_ids.has(iid):
		return
	item_ids.erase(iid)
	selected.erase(iid)
	if mode == "sell":
		_rescale_sell()
	else:
		_rescale_ask()
	emit_signal("changed")

func selected_ids() -> Array:
	var out: Array = []
	for i in item_ids:
		if selected.get(i, false):
			out.append(i)
	return out

func any_selected() -> bool:
	return not selected_ids().is_empty()

# 拆开按样出价时，客人按自己心里的分量重算要价 / 底价
func _selected_ratio() -> float:
	var tot := 0.0
	var sel := 0.0
	for i in item_ids:
		var w := float(item(i).get("ask_w", 1.0))
		tot += w
		if selected.get(i, false):
			sel += w
	return sel / tot if tot > 0.0 else 1.0

# 第一天收购建议价 = 市价 × 60%（设计稿）。按“你以为的”价值算：没看出是假货的，按它冒充的价值算；
# 你认定是假的，算 0。行情（世界轮盘）变了，建议价跟着变。
func calc_buy_suggest() -> int:
	var sug := 0
	for i in item_ids:
		if not selected.get(i, false):
			continue
		var it: Dictionary = item(i)
		var v := 0
		if judged.get(i, "") == "fake":
			v = 0
		elif it.get("fake", false):
			v = int(round(float(it.get("claimed", 0)) * world.price_mod(it)))
		else:
			v = world.market_now(it)
		sug += int(round(v * 0.6))
	return sug

func _rescale_ask() -> void:
	var tot := 0.0
	var sel := 0.0
	var sug := 0
	for i in item_ids:
		var w := float(item(i).get("ask_w", 1.0))
		tot += w
		if selected.get(i, false):
			sel += w
			sug += int(item(i).get("suggest", 0))
	if tot <= 0.0:
		return
	var r := sel / tot
	ask = int(round(base_ask * r))
	floor_v = int(round(base_floor * r))
	if mode == "buy":
		suggestion = calc_buy_suggest()
	elif split:
		suggestion = sug

func reprice(new_ask: int, new_floor: int, new_suggest: int = -1) -> void:
	# 新的整批要价 / 底价；若玩家已拆开挑选，按挑选的分量重算
	# 新价是针对“眼下挑出来的这些”说的：反推整批的基数，之后再挑拣时按分量缩放
	var r := _selected_ratio() if split else 1.0
	base_ask = int(round(new_ask / maxf(r, 0.01)))
	base_floor = int(round(new_floor / maxf(r, 0.01)))
	ask = new_ask
	floor_v = new_floor
	if mode == "buy":
		suggestion = calc_buy_suggest()
	if new_suggest >= 0:
		suggestion = new_suggest
	emit_signal("changed")

# ---------------- 验货的墨（找不同：每件三笔，有这一类的鉴别录多一笔） ----------------
# 墨只在界面上圈的时候花；session.inspect 本身不看墨（自动试玩、剧情脚本照旧能揭开部位）。
func ink_max(iid: String) -> int:
	if not world.ledger.items.has(iid):
		return 0
	return Appraise.ink_max(world, world.ledger.items[iid])

func ink_left(iid: String) -> int:
	return maxi(0, ink_max(iid) - circles.get(iid, []).size())

func add_circle(iid: String, entry: Dictionary) -> void:
	if not circles.has(iid):
		circles[iid] = []
	circles[iid].append(entry)
	emit_signal("changed")

func _any_ink_left() -> bool:
	for iid in item_ids:
		if ink_left(iid) > 0:
			return true
	return false

# 教学：哥哥在旁边时，不看够就不让谈价。require = ["物品.部位", …] 必须看的部位
# 墨用完了还没看够，就不再拦着（不能卡死在柜台上）。
func needs_more_inspection() -> bool:
	if min_inspect > 0 and inspected_total() < min_inspect and _any_ink_left():
		return true
	for r in missing_required():
		var iid := iid_of(str(r).split(".")[0])
		if iid == "" or ink_left(iid) > 0:
			return true
	return false

func missing_required() -> Array:
	var out: Array = []
	for r in def.get("require", []):
		var parts := str(r).split(".")
		if parts.size() == 2 and not is_inspected(parts[0], parts[1]):
			out.append(str(r))
	return out

# ---------------- 议价 ----------------
# 出价：返回 {result: accept/counter/plead/leave, text}
func offer(v: int) -> Dictionary:
	rounds += 1
	last_offer = v
	var n: Dictionary = npc()
	var t: Dictionary = n["persona"]["traits"]
	var need: float = float(n["persona"]["needs"].get("resources", 0.5))
	var res := {}
	if mode == "sell":
		res = _offer_sell(v, n, t)
	else:
		res = _offer_buy(v, n, t, need)
	last_npc_line = res["text"]
	if res["result"] == "accept":
		price = v
	emit_signal("changed")
	return res

const MAX_ROUNDS = 5   # 讨价还价最多来回五轮：再谈不拢，客人就走（v0.2：不再无限还价）

func _offer_buy(v: int, n: Dictionary, t: Dictionary, need: float) -> Dictionary:
	if v >= ask:
		world.mind.feel(n, {"joy": 0.2, "hope": 0.1})
		return {"result": "accept", "text": _line("accept_happy")}
	# 骗子只要把钱匣掏空就行（设计稿：孙少爷“收下（钱匣允许的最高价）”）
	if def.get("accept_all_cash", false) and v >= world.cash() and v >= int(def.get("min_cash", 100)):
		return {"result": "accept", "text": str(def.get("accept_all_cash_line", "……行吧，就当帮你们小铺子开个张。"))}
	if hard_floor and v < base_floor:
		# 少一个也不行：不是讨价还价，是赎人的价
		if rounds >= 2:   # 少一个也不行：说过一遍还压价，他就走了
			closed = true
			world.favor(npc_id, -1)
			return {"result": "leave", "text": _line("leave")}
		return {"result": "counter", "text": _line("counter") % base_floor}
	if rounds >= MAX_ROUNDS and v >= floor_v:
		return {"result": "accept", "text": _line("accept")}   # 谈到第五轮还在底价之上：成交
	if rounds >= MAX_ROUNDS and v < floor_v:
		closed = true
		world.favor(npc_id, -1)
		return {"result": "leave", "text": _line("leave")}
	var gap_floor := float(v - floor_v) / maxf(1.0, float(ask - floor_v))
	var lowball := v < int(floor_v * 0.6)
	if lowball:
		world.mind.feel(n, {"anger": 0.3, "humiliation": 0.15, "shame": 0.1})
	var cands: Array = []
	if v >= floor_v:
		cands.append({"id": "accept", "utility": 0.25 + gap_floor * 0.9 + need * 0.55 - float(t.get("assertiveness", 0.5)) * 0.7 + rounds * 0.12 - float(t.get("patience", 0.5)) * 0.15, "attrs": {"gain": 0.4 + gap_floor * 0.4, "immediacy": 0.8, "commitment": 0.7, "safety": 0.5, "fairness": gap_floor}})
	cands.append({"id": "counter", "utility": 0.25 + float(t.get("assertiveness", 0.5)) * 0.5 - rounds * 0.12, "attrs": {"gain": 0.6, "confrontation": 0.3, "delay": 0.3, "dignity": 0.5, "effort": 0.3}})
	if need > 0.6:
		cands.append({"id": "plead", "utility": 0.1 + need * 0.4 - rounds * 0.15, "attrs": {"disclosure": 0.7, "dignity": 0.1, "care": 0.4, "affiliation": 0.4, "social_exposure": 0.4}})
	var below := maxf(0.0, float(floor_v - v) / maxf(1.0, float(floor_v)))
	cands.append({"id": "leave", "utility": -0.5 + below * 1.6 + rounds * 0.25 - need * 0.3 + (0.4 if lowball else 0.0), "attrs": {"withdrawal": 0.9, "dignity": 0.7, "safety": 0.3, "reversibility": 0.2}})
	var d: Dictionary = world.mind.decide(n, cands, {"context": {"stakes": 0.7, "time_pressure": 0.5, "publicness": 0.2}}, "haggle_%s_%d_%d" % [npc_id, rounds, v])
	match d["id"]:
		"accept":
			return {"result": "accept", "text": _line("accept")}
		"counter":
			var concede := 0.5 - float(t.get("assertiveness", 0.5)) * 0.3 + need * 0.2
			var target := maxi(floor_v, v)
			ask = maxi(floor_v, int(round(ask - (ask - target) * clampf(concede, 0.1, 0.8))))
			return {"result": "counter", "text": _line("counter") % ask}
		"plead":
			return {"result": "plead", "text": _line("plead")}
		_:
			closed = true
			world.favor(npc_id, -3 if lowball else -1)
			return {"result": "leave", "text": _line("leave")}

func _offer_sell(v: int, n: Dictionary, t: Dictionary) -> Dictionary:
	# 卖给客人：ask = 客人愿出的价，floor_v = 他最多肯出到
	if v <= ask:
		return {"result": "accept", "text": _line("accept_happy")}
	var over := float(v - ask) / maxf(1.0, float(floor_v - ask))
	# 高于他心里最高价，说了五轮还不降——他就走（不再无限还价）
	if rounds >= MAX_ROUNDS and v > floor_v:
		closed = true
		return {"result": "leave", "text": _line("leave")}
	if rounds >= MAX_ROUNDS:
		return {"result": "accept", "text": _line("accept")}
	var cands: Array = []
	if v <= floor_v:
		# 在他“出价—最高价”之间的公道要价，有相当的机会成交，谈得越久越可能点头
		cands.append({"id": "accept", "utility": 0.75 - over * 0.45 + rounds * 0.12, "attrs": {"gain": 0.4, "immediacy": 0.7, "commitment": 0.6, "resource_cost": clampf(over, 0.0, 1.0)}})
	cands.append({"id": "counter", "utility": 0.3 + float(t.get("assertiveness", 0.5)) * 0.4 - rounds * 0.1, "attrs": {"gain": 0.5, "confrontation": 0.3, "delay": 0.3}})
	cands.append({"id": "leave", "utility": -0.6 + maxf(0.0, over - 1.0) * 1.5 + rounds * 0.2, "attrs": {"withdrawal": 0.8, "dignity": 0.5}})
	var d: Dictionary = world.mind.decide(n, cands, {"context": {"stakes": 0.4}}, "sell_%s_%d_%d" % [npc_id, rounds, v])
	match d["id"]:
		"accept":
			return {"result": "accept", "text": _line("accept")}
		"counter":
			ask = mini(floor_v, int(round(ask + (mini(v, floor_v) - ask) * 0.5)))
			return {"result": "counter", "text": _line("counter_sell") % ask}
		_:
			closed = true
			return {"result": "leave", "text": _line("leave")}

func _line(kind: String) -> String:
	var lines: Dictionary = world.db.cast.get(npc_id, {}).get("lines", {})
	var s := str(lines.get(kind, {"counter": "%d。", "counter_sell": "%d。"}.get(kind, "……")))
	return s   # 外显神色由 director.say 统一加（不重复）

# ---------------- 玩家可见的摘要（不含底价，除非 show_floor） ----------------
func visible_view() -> Dictionary:
	var v := {"npc": npc_id, "mode": mode, "ask": ask, "suggest": suggestion, "est": [est_lo, est_hi], "hint": hint}
	if show_floor:
		v["floor"] = floor_v
	return v


# v0.3：单件可见价（卖货时按当前勾选重算后的均摊展示用）
func unit_price_of(iid: String) -> Dictionary:
	var it: Dictionary = item(iid)
	var market: int = int(world.market_now(it))
	var prices: Dictionary = def.get("buyer_prices", {})
	var bp: Dictionary = prices.get(it.get("def_id", ""), {})
	var base_market := maxf(1.0, float(it.get("market", market)))
	var offer_ratio := float(bp["offer"]) / base_market if bp.has("offer") else 0.85
	var max_ratio := float(bp["max"]) / base_market if bp.has("max") else 1.05
	return {"market": market, "offer": int(round(market * clampf(offer_ratio, 0.5, 1.2))), "max": int(round(market * clampf(max_ratio, 0.55, 1.35)))}
