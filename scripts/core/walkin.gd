# [shop-only] 过路客人与门口吆喝（v0.4.2，设计见 docs/town/DESIGN_walkin.md）。
# 只守铺子版从第 2 天起，每天黎明排一张“过路客人”时刻表；到点时店里没站满，这位就进门——
# 和保护费的胡二一样，把一份完整的来访追加到 world.town.s["visits"]，visitors.poll 下一刻就看得见。
# 门口吆喝不凭空多造人：把时刻表上下一位还没到的人提前叫来，按吆喝的种类定他的来意。
# 想买货的人从“当时”架上挑一件他买得起的（按原型口味加权），到柜台上一次只谈这一件；货不在了改挑，挑不到就说一句走人。
# 数据全在 data/town/walkin.json；状态存在导演账上 vars["town"]["walkin"]（随存档走，全是整数/字符串）。
# 随机只用 JevRng.draw(种子, 域, [天, 序号, …])，不碰天气、米价、外生轮盘；耐心、出价上限这些隐藏的数不给玩家看。
extends RefCounted

const R = preload("res://scripts/sim/jev_rng.gd")
const Items = preload("res://scripts/sim/item_gen.gd")
const PATH := "res://data/town/walkin.json"

static var _cfg: Dictionary = {}

static func config() -> Dictionary:
	if _cfg.is_empty() and FileAccess.file_exists(PATH):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		if typeof(parsed) == TYPE_DICTIONARY:
			_cfg = parsed
	return _cfg

static func clear() -> void:
	_cfg = {}

# 给玩家看的一句话：数据里的 {name} {n} {price} 换成实际的名字和玩家自己账上的数
static func line(key: String, subs: Dictionary = {}) -> String:
	return fill(str(config().get("lines", {}).get(key, "")), subs)

static func fill(text: String, subs: Dictionary) -> String:
	for k in subs:
		text = text.replace("{%s}" % str(k), str(subs[k]))
	return text

# 过路客人的来访 / 人：自己的命名空间，不和自然排的客人、故事卡撞
static func visit_id(day: int, n: int) -> String:
	return "walkin_d%d_%d" % [day, n]

static func who_of(arch: String, day: int, n: int) -> String:
	return "walkin:%s#d%d_%d" % [arch, day, n]

static func is_walkin(visit: Dictionary) -> bool:
	return str(visit.get("id", "")).begins_with("walkin_d")

# 日结里合成的一行：“还有 N 位过路的没等到”
static func summary_missed_line(n: int) -> String:
	return line("summary_missed", {"n": n})

# 柜台上卖出去以后的提示：“卖出：{名字}，进账 X 蚨”
static func sold_toast(name: String, price: int) -> String:
	return line("sold_toast", {"name": name, "price": price})

var d = null            # 导演
# 店里眼下站着几位客人（界面那边 visitors 的名单最准：town_game.bind 时接上）；没接上（无头测试）就按导演的来访名单数
var waiting_source: Callable = Callable()

func _init(p_director) -> void:
	d = p_director

# ====================================================================
# 状态
func active() -> bool:
	if d == null or not d._is_town():
		return false
	var c: Dictionary = config()
	return bool(c.get("enabled_shop_only", false)) if d.shop_only() else bool(c.get("enabled_town", false))

# vars["town"]["walkin"] = {day, slots:[{minute, at, status, called, id}], calls, skipped, quiet}
#   slots 按序号 n 排：at 是黎明排的钟点，minute 是现在的钟点（吆喝会提前）；
#   status：pending 还没到 / in 进门了（来访已追加）/ skipped 到点时店里站满了，探头看看就走了 /
#           passed 只能吆喝的那天（开张头一天）没人吆喝，从门口走过去了
#   quiet："" 平常 / calls_only 开张头一天：街上的人不自己进门，吆喝才进 / early 还没到吆喝得应的日子 / boycott 断客
func st() -> Dictionary:
	var town: Dictionary = d._town_state()
	if not town.has("walkin") or typeof(town["walkin"]) != TYPE_DICTIONARY:
		town["walkin"] = {}
	var w: Dictionary = town["walkin"]
	var defaults := {"day": -1, "slots": [], "calls": 0, "skipped": 0, "quiet": ""}
	for k in defaults:
		if not w.has(k):
			w[k] = defaults[k].duplicate(true) if defaults[k] is Array else defaults[k]
	return w

func _seed() -> int:
	return int(d.world.town.s["seed"])

func _draw(domain: String, key: Array) -> float:
	return R.draw(_seed(), domain, key)

func _now() -> int:
	return int(d.world.town.s.get("minute", 360))

# ====================================================================
# 每天一早：排今天的时刻表（读档续玩时导演会再调一次：今天的表已经在了就不动）
func on_day_start() -> void:
	if not active():
		return
	var w := st()
	var day: int = d.world.day
	if int(w["day"]) == day:
		return
	w["day"] = day
	w["slots"] = []
	w["calls"] = 0
	w["skipped"] = 0
	w["quiet"] = ""
	if day < calls_from_day():
		w["quiet"] = "early"
		return
	if int(d.protect().st().get("boycott_day", -1)) == day:
		w["quiet"] = "boycott"        # 街坊绕着走：没有过路客人，吆喝也没人应
		return
	if day < int(config().get("from_day", 2)):
		w["quiet"] = "calls_only"     # 开张头一天：剧情里的客人已经很满，街上的人不自己进门；到门口吆喝，照样叫得来
	w["slots"] = schedule(day)
	# 读的是这个版本以前的白天存档（今天的表还没排过）：已经过了钟点的几位就当没来过，不一下子涌进门
	for slot in w["slots"]:
		if int(slot["minute"]) <= _now():
			slot["status"] = "skipped"

# 从哪天起吆喝有人应（calls_from_day，默认 1）；过路客人自己进门从 from_day 起（默认 2）
func calls_from_day() -> int:
	return mini(int(config().get("calls_from_day", 1)), int(config().get("from_day", 2)))

# 这一天的时刻表：从 open_minute 起，每隔 gap_range 分钟一位，到 last_minute 为止（只看种子和日期）
func schedule(day: int) -> Array:
	var c: Dictionary = config()
	var gaps: Array = c.get("gap_range", [55, 110])
	var lo := maxi(1, int(gaps[0]))
	var hi := maxi(lo, int(gaps[1]))
	var t := int(c.get("open_minute", 420))
	var last := int(c.get("last_minute", 1050))
	var out: Array = []
	var n := 0
	while n < 200:
		t += lo + int(floor(_draw("walkin_gap", [day, n]) * float(hi - lo + 1)))
		if t > last:
			break
		out.append({"at": t, "minute": t, "status": "pending", "called": "", "id": ""})
		n += 1
	return out

# 还没到的（吆喝没叫过的）下一位；没有返回 -1
func _next_slot() -> int:
	var slots: Array = st()["slots"]
	for n in slots.size():
		if str(slots[n]["status"]) == "pending" and str(slots[n].get("called", "")) == "":
			return n
	return -1

# 吆喝叫来了、还在路上的几位（他们一到，店里就多站一位）
func _on_the_way() -> int:
	var k := 0
	for slot in st()["slots"]:
		if str(slot["status"]) == "pending" and str(slot.get("called", "")) != "":
			k += 1
	return k

# ====================================================================
# 每个游戏分钟（town_game.advance_minute 在 visitors.poll 之前调）：到点的过路客人进门。返回这一刻进门的来访 ID。
func tick() -> Array:
	var came: Array = []
	if not active():
		return came
	var w := st()
	if int(w["day"]) != int(d.world.day) or bool(d.world.town.s.get("day_ended", true)):
		return came
	var now := _now()
	var slots: Array = w["slots"]
	var due: Array = []
	for n in slots.size():
		if str(slots[n]["status"]) == "pending" and int(slots[n]["minute"]) <= now:
			due.append(n)
	if due.is_empty():
		return came
	due.sort_custom(func(a, b):
		if int(slots[a]["minute"]) != int(slots[b]["minute"]):
			return int(slots[a]["minute"]) < int(slots[b]["minute"])
		return a < b)
	var waiting := waiting_now()
	var cap := int(config().get("max_waiting", 3))
	var calls_only := str(w.get("quiet", "")) == "calls_only"
	for n in due:
		var slot: Dictionary = slots[n]
		var called := str(slot.get("called", ""))
		if called == "" and calls_only:
			slot["status"] = "passed"           # 开张头一天：没人吆喝，从门口走过去了（不记账、不报错过）
			continue
		# 店里站满了：门口探头看看就走了（不记账、不报错过）。吆喝叫来的人不算：吆喝时已经数过店里的人和路上的人，
		# 这期间胡二、剧情里的人、自然排的客人进了门，他也照样进来（第四位往后排着站，visitors.spot_for）
		if waiting >= cap and called == "":
			slot["status"] = "skipped"
			w["skipped"] = int(w["skipped"]) + 1
			continue
		var vid := _materialize(int(n), now)
		if vid == "":
			if str(slot["status"]) == "pending":
				slot["status"] = "skipped"
				w["skipped"] = int(w["skipped"]) + 1
			continue
		came.append(vid)
		waiting += 1
	return came

# 店里眼下站着几位等着的客人（到了、还没走、还没办完；不算没有身体的“你”的事）。
# 界面接上了 visitors 就问它；没接上就和 visitors.poll 用同一份名单、同一个耐心算法数一遍。
func waiting_now() -> int:
	if waiting_source.is_valid():
		return int(waiting_source.call())
	var now := _now()
	var n := 0
	for v in d.town_visits():
		var who := str(v.get("who", ""))
		if who == "" or who == "you":
			continue
		if int(v.get("minute", 0)) > now:
			continue
		var expiry := int(v.get("minute", 0)) + int(v.get("patience_min", 0))
		if str(v.get("storylet", "")) != "" and v.has("end_minute"):
			expiry = int(v["end_minute"])
		if now > expiry:
			continue
		n += 1
	return n

# 第 n 位进门：定来意和身份，配好柜台上的那一场，追加进今天的来访名单
func _materialize(n: int, now: int) -> String:
	var town = d.world.town
	var day: int = d.world.day
	var w := st()
	var slot: Dictionary = w["slots"][n]
	var vid := visit_id(day, n)
	for v in town.s["visits"]:
		if str(v.get("id", "")) == vid:
			slot["status"] = "in"           # 已经在名单里了：不重复进门
			slot["id"] = vid
			return ""
	var c: Dictionary = config()
	var called := str(slot.get("called", ""))
	var weights: Dictionary = c.get("intents", {})
	if called != "":
		weights = c.get("calls", {}).get(called, {}).get("intents", weights)
	var family := _weighted(weights, _draw("walkin_intent", [day, n]))
	var buyers: Array = _buyer_archetypes(day, n) if family == "buy" else []
	if family == "buy" and buyers.is_empty():
		# 架上没有他买得起的货：“买”改抽成别的
		var rest: Dictionary = c.get("intents", {}).duplicate()
		rest.erase("buy")
		family = _weighted(rest, _draw("walkin_intent", [day, n, "nobuy"]))
	if family == "":
		return ""
	var archetypes: Dictionary = c.get("archetypes", {})
	var rows: Array = []
	for arch in _sorted(archetypes.keys()):
		var a: Dictionary = archetypes[arch]
		if not a.get("intents", []).has(family) or not _pack_ok(str(arch)):
			continue
		if family == "buy" and not buyers.has(str(arch)):
			continue
		if float(a.get("weight", 0.0)) > 0.0:
			rows.append([str(arch), float(a["weight"])])
	if rows.is_empty():
		return ""
	var arch: String = R.weighted_choice(rows, _draw("walkin_arch", [day, n]))
	var intent := str(archetypes[arch].get("intent_as", {}).get(family, family))
	var pr: Array = c.get("patience_range", [40, 90])
	var plo := int(pr[0])
	var phi := maxi(plo, int(pr[1]))
	var visit := {"id": vid, "who": who_of(arch, day, n), "intent": intent, "slot": town._slot_at(now), "storylet": "",
		"minute": now, "patience_min": plo + int(floor(_draw("walkin_patience", [day, n]) * float(phi - plo + 1))),
		"status": "planned", "walkin": true, "called": called, "archetype": arch, "session": {}}
	var session: Dictionary = {}
	if family == "buy":
		session = buyer_session(visit, n, 0, -1)
	else:
		session = Items.session(town.templates, town.pack, town.s, visit, d.world)
	if session.is_empty():
		return ""
	visit["session"] = session
	town._register_session(session)
	town.s["visits"].append(visit)
	slot["status"] = "in"
	slot["id"] = vid
	return vid

# ====================================================================
# 门口吆喝：town_action("walkin_call", {kind: "pawn"|"buy"}) 走这里（导演外面套了 request_id 去重）。
# 成：{ok, kind, n, line, minutes}——调用方说这句话、再花 minutes 游戏分钟（被叫的人 call_delay 分钟后进门）；
# 不成：{ok:false, error, line}，error ∈ unknown_call / walkin_off / too_late / boycott / quiet_day / not_open / shop_full / no_stock / no_buyer / no_walkers。
func call_in(args: Dictionary) -> Dictionary:
	var kind := str(args.get("kind", ""))
	var check := call_check(kind)
	if not bool(check.get("ok", false)):
		return check
	var w := st()
	var n := _next_slot()
	var slot: Dictionary = w["slots"][n]
	var cd: Array = config().get("call_delay", [3, 12])
	var lo := int(cd[0])
	var hi := maxi(lo, int(cd[1]))
	var delay := lo + int(floor(_draw("walkin_call_delay", [int(d.world.day), n]) * float(hi - lo + 1)))
	slot["minute"] = mini(int(slot["minute"]), _now() + delay)
	slot["called"] = kind
	w["calls"] = int(w["calls"]) + 1
	return {"ok": true, "kind": kind, "n": n, "line": line("call_" + kind), "minutes": int(config().get("call_minutes", 10))}

# 只问能不能吆喝，不动任何状态（门口的小窗用它把“吆喝卖货”灰掉）
func call_check(kind: String) -> Dictionary:
	if kind not in ["pawn", "buy"]:
		return _no("unknown_call", "call_quiet")
	if not active():
		return _no("walkin_off", "call_quiet")
	var w := st()
	if int(w["day"]) != int(d.world.day):
		return _no("walkin_off", "call_quiet")
	if _now() >= int(config().get("call_until", 1080)):
		return _no("too_late", "call_late")
	var quiet := str(w.get("quiet", ""))
	if quiet == "boycott":
		return _no("boycott", "call_boycott")
	if quiet not in ["", "calls_only"]:
		return _no("quiet_day", "call_quiet")
	if quiet == "calls_only" and not bool(d.world.flags.get("town_first_open", false)):
		return _no("not_open", "call_not_open")      # 开张头一天、门板还没卸（哥哥的话还没交代完）
	# 店里站着的，加上吆喝叫来了、还在路上的
	if waiting_now() + _on_the_way() >= int(config().get("max_waiting", 3)):
		return _no("shop_full", "call_full")
	if kind == "buy" and d._town_shelf().is_empty():
		return _no("no_stock", "call_no_stock")
	if kind == "buy" and _buyer_archetypes(int(d.world.day), maxi(_next_slot(), 0)).is_empty():
		return _no("no_buyer", "call_no_buyer")      # 架上的货，过路的人没一个看得上、买得起
	if _next_slot() < 0:
		return _no("no_walkers", "call_exhausted")
	return {"ok": true, "kind": kind}

func _no(error: String, line_key: String) -> Dictionary:
	return {"ok": false, "error": error, "line": line(line_key)}

# 门口小窗的选项（界面用）：[{id, label, enabled, note}]。“吆喝卖货”在架上没货时灰着，写“架上没货”；
# 架上有货、可没一样是过路的人看得上、买得起的，也灰着，写“过路的看不上”（不写数）
func menu_options() -> Array:
	var buy_note := ""
	if d._town_shelf().is_empty():
		buy_note = line("menu_no_stock")
	elif _buyer_archetypes(int(d.world.day), maxi(_next_slot(), 0)).is_empty():
		buy_note = line("menu_no_buyer")
	return [{"id": "pawn", "label": line("menu_pawn"), "enabled": true, "note": ""},
		{"id": "buy", "label": line("menu_buy"), "enabled": buy_note == "", "note": buy_note},
		{"id": "cancel", "label": line("menu_cancel"), "enabled": true, "note": ""}]

func door_label() -> String:
	return line("door_label")

# ====================================================================
# 买主：从当时架上挑一件他买得起的
func _pack_ok(arch: String) -> bool:
	var spec := _pack_archetype(arch)
	if spec.is_empty():
		return false
	if spec.has("requires_building") and not bool(d.world.town.s.get("unlocked", {}).get(str(spec["requires_building"]), false)):
		return false            # 收旧物的要码头开了才来
	return true

func _pack_archetype(arch: String) -> Dictionary:
	for spec in d.world.town.pack.get("strangers", {}).get("archetypes", []):
		if str(spec.get("id", "")) == arch:
			return spec
	return {}

# 眼下架上能挑到东西的买主原型
func _buyer_archetypes(day: int, n: int) -> Array:
	var out: Array = []
	var archetypes: Dictionary = config().get("archetypes", {})
	for arch in _sorted(archetypes.keys()):
		if not archetypes[arch].get("intents", []).has("buy") or not _pack_ok(str(arch)):
			continue
		if not _candidates(str(arch), day, n, -1).is_empty():
			out.append(str(arch))
	return out

# 他会看的货：自己的、没押给人的架上货，口味权重 > 0、市面价在他肯看的范围里；purse >= 0 时还要他身上的钱够他最多肯出的价
func _candidates(arch: String, day: int, n: int, purse: int) -> Array:
	var a: Dictionary = config().get("archetypes", {}).get(arch, {})
	var taste: Dictionary = a.get("taste", {})
	var budget := int(a.get("budget", 0))
	var rows: Array = []
	for row in d._town_shelf():
		var iid := str(row["iid"])
		var it: Dictionary = d.world.ledger.items[iid]
		if bool(it.get("contraband", false)):
			continue            # 禁报这类东西，过路的不会当着人在柜台上买
		var weight := float(taste.get(str(it.get("cat", "")), taste.get("_other", 0.0)))
		if weight <= 0.0:
			continue
		var price: int = d.world.market_now(it)
		if price <= 0 or price > budget:
			continue
		if purse >= 0 and _max_price(it, _prices(it, day, n)) > purse:
			continue
		rows.append([iid, weight])
	return rows

# 他开口的价和最多肯出的价（隐藏），和 town_pack 的 sell_offer / sell_max 同义：按物件的基准市价
func _prices(it: Dictionary, day: int, n: int) -> Dictionary:
	var c: Dictionary = config()
	var base := int(it.get("market", 0))
	var key: Array = [day, n, str(it.get("def_id", ""))]
	return {"offer": maxi(1, int(round(float(base) * _range(c.get("buyer_offer", [0.8, 0.9]), _draw("walkin_buyer_offer", key))))),
		"max": maxi(1, int(round(float(base) * _range(c.get("buyer_max", [1.0, 1.15]), _draw("walkin_buyer_max", key)))))}

# 柜台上他最多肯出到多少（和 Session._rescale_sell 同一个算法）：用来定他身上带多少钱，让他买得起他挑的那件
func _max_price(it: Dictionary, prices: Dictionary) -> int:
	var market := float(d.world.market_now(it))
	var tidy_m := 1.0 + float(it.get("tidy_bonus", 0.0)) + float(it.get("market_bonus", 0.0))
	var base := maxf(1.0, float(it.get("market", market)))
	var offer_ratio := clampf(float(prices["offer"]) / base, 0.5, 1.2)
	var max_ratio := clampf(maxf(float(prices["max"]) / base, offer_ratio), 0.55, 1.35)
	return int(ceil(market * max_ratio * tidy_m))

# 买主这一场（Session 的 sell 模式：客人从铺子里买）。attempt 0 = 进门时挑；之后是到柜台时那件不在了、改挑的第几回。
# purse < 0：还没开账户，他带的钱 = 原型的钱和这件他最多肯出的价，取大的；purse >= 0：只挑他身上的钱够的。
# old：改挑时他原先看中、已经不在架上的那件的名字（他开口先提它，玩家才知道“那件”是哪件）。
func buyer_session(visit: Dictionary, n: int, attempt: int, purse: int, old: String = "") -> Dictionary:
	var day: int = d.world.day
	var arch := str(visit.get("archetype", ""))
	var rows := _candidates(arch, day, n, purse)
	if rows.is_empty():
		return {}
	var key: Array = [day, n] if attempt == 0 else [day, n, "repick", attempt]
	var iid: String = R.weighted_choice(rows, _draw("walkin_pick", key))
	return _buyer_spec(visit, n, iid, attempt, purse, old)

func _buyer_spec(visit: Dictionary, n: int, iid: String, attempt: int, purse: int, old: String = "") -> Dictionary:
	var town = d.world.town
	var day: int = d.world.day
	var it: Dictionary = d.world.ledger.items[iid]
	var who := str(visit["who"])
	var arch := str(visit.get("archetype", ""))
	var def_id := str(it.get("def_id", ""))
	var prices := _prices(it, day, n)
	var npc: Dictionary = Items._npc_def(town.templates, town.pack, who)
	npc["cash"] = purse if purse >= 0 else maxi(int(npc.get("cash", 0)), _max_price(it, prices))
	var subs := {"name": str(it.get("name", def_id)), "old": old}
	var buyer: Dictionary = config().get("archetypes", {}).get(arch, {}).get("buyer", {})
	var intro := fill(str(buyer.get("intro", "掌柜的，架上那件{name}，我看看。")), subs) if attempt == 0 else line("repick", subs)
	# 柜台上可以问的两句：回答按原型写在数据里，只说观察，不报价
	var extras: Array = []
	for kind in ["use", "look"]:
		var opts: Array = buyer.get(kind, [])
		if opts.is_empty():
			continue
		var pick := mini(opts.size() - 1, int(floor(_draw("walkin_talk", [day, n, kind]) * float(opts.size()))))
		var step: Dictionary = {"op": "say", "who": who, "text": fill(str(opts[pick]), subs)} if kind == "use" else {"op": "narr", "text": fill(str(opts[pick]), subs)}
		extras.append({"id": "walkin_" + kind, "label": line(kind + "_label"), "once": true, "steps": [step]})
	var market: int = d.world.market_now(it)
	return {"id": "gen_d%d_%s" % [day, str(visit["id"])], "npc": who, "mode": "sell",
		"show_floor": false, "hard_floor": false, "fund_button": false, "min_inspect": 0, "split": false, "hint": "",
		"stock": [def_id], "buyer_prices": {def_id: prices},
		"ask": int(prices["offer"]), "floor": maxi(int(prices["offer"]), int(prices["max"])), "suggest": market, "est": [market, market],
		"pre": [], "intro": [{"op": "say", "who": who, "text": intro}], "on_inspect": {}, "extras": extras, "deals": [],
		"on_accept": [], "on_leave": [], "outro": [], "post": [], "labels": {"tip": line("counter_tip")},
		"_item_defs": {}, "_npc_def": npc, "_walkin": {"n": n, "arch": arch, "iid": iid, "repicks": attempt}}

func _arch_line(arch: String, key: String) -> String:
	var buyer: Dictionary = config().get("archetypes", {}).get(arch, {}).get("buyer", {})
	return str(buyer.get(key, line(key)))

# ====================================================================
# 柜台上要开始谈之前（导演 run_town_visit 调）：买主要的那件还在不在架上（自己的、没押给人的）。
# 过路的买主：不在了改挑架上另一件他买得起的；一件也没有，就说“我是冲架上那件××来的——没了？那改天再来”，体面地走。
# 黎明排好的自然买主：要的都不在了，说出想看的是哪件（哪几件），一句走人，不再干站着。改动写回 s.visits 里的那份来访（随存档走）。
# 玩家还没听他说过要哪件，所以这些话都把东西的名字说出来，不说没头没脑的“那件”。
func before_counter(visit: Dictionary) -> void:
	var session = visit.get("session", {})
	if typeof(session) != TYPE_DICTIONARY or str(session.get("mode", "")) != "sell" or str(visit.get("storylet", "")) != "":
		return
	var who := str(session.get("npc", visit.get("who", "")))
	var wanted: Array = session.get("stock", [])
	if session.has("_walkin"):
		var meta: Dictionary = session["_walkin"]
		if not wanted.is_empty() and _available(str(wanted[0])):
			return
		var attempt := int(meta.get("repicks", 0)) + 1
		var old := _item_name(str(meta.get("iid", "")), str(wanted[0]) if not wanted.is_empty() else "")
		var spec := buyer_session(visit, int(meta.get("n", 0)), attempt, int(d.world.ledger.balance(who)), old)
		if spec.is_empty():
			session["intro"] = _nostock_steps(who, fill(_arch_line(str(meta.get("arch", "")), "nostock"), {"old": old}))
			session["extras"] = []
			return
		visit["session"] = spec
		d.world.town._register_session(spec)
		return
	var names: Array = []
	for def_id in wanted:
		if _available(str(def_id)):
			return
		var nm := _item_name("", str(def_id))
		if not names.has(nm):
			names.append(nm)
	session["intro"] = _nostock_steps(who, line("nostock_natural_one" if names.size() <= 1 else "nostock_natural", {"name": "、".join(names)}))
	session["extras"] = []

# 东西的名字：先按 iid 找，找不到就在账上找同一个 def_id 的（卖掉、被拿走的也还在账上）
func _item_name(iid: String, def_id: String) -> String:
	var items: Dictionary = d.world.ledger.items
	if iid != "" and items.has(iid):
		return str(items[iid].get("name", def_id))
	var ids: Array = items.keys()
	ids.sort()
	for id in ids:
		if str(items[id].get("def_id", "")) == def_id:
			return str(items[id].get("name", def_id))
	return def_id

func _nostock_steps(who: String, text: String) -> Array:
	return [{"op": "say", "who": who, "text": text}, {"op": "end", "result": "nostock"}]

func _available(def_id: String) -> bool:
	for iid in d.world.ledger.items_at("stock"):
		var it: Dictionary = d.world.ledger.items[iid]
		if str(it.get("def_id", "")) == def_id and str(it.get("owner", "")) == "player" and str(it.get("pledged_to", "")) == "":
			return true
	return false

# ====================================================================
# [shop-only] 货架（只看）：一行一件，名字、类别、成色，和玩家自己账上的数（当初收价 / 满当的当本 / 店里旧存）。
# 不写市价：买来的假货在这里不露底。
func shelf_rows() -> Array:
	var sh: Dictionary = config().get("shelf", {})
	var out: Array = []
	for row in d._town_shelf():
		var iid := str(row["iid"])
		var it: Dictionary = d.world.ledger.items[iid]
		var cond := ""
		if typeof(it.get("condition")) in [TYPE_FLOAT, TYPE_INT]:
			cond = fill(str(sh.get("condition", "")), {"n": maxi(1, int(round(float(it["condition"]) * 10.0)))})
		out.append({"iid": iid, "name": str(it.get("name", iid)), "category": str(it.get("cat_cn", it.get("cat", ""))),
			"condition": cond, "record": record_of(iid)})
	return out

# 一件货在玩家自己账上的数：“当初收价 X 蚨 / 满当的当本 X 蚨 / 店里旧存”（货架、夜里对账、整理库房都用这句，不写市价）
func record_of(iid: String) -> String:
	var sh: Dictionary = config().get("shelf", {})
	var it: Dictionary = d.world.ledger.items.get(iid, {})
	var principal := _forfeit_principal(iid)
	if principal > 0:
		return fill(str(sh.get("pawn", "")), {"n": principal})
	if int(it.get("cost", 0)) > 0:
		return fill(str(sh.get("cost", "")), {"n": int(it["cost"])})
	return str(sh.get("old", "店里旧存"))

func shelf_text(key: String) -> String:
	return str(config().get("shelf", {}).get(key, ""))

func _forfeit_principal(iid: String) -> int:
	var keys: Array = d.world.ledger.contracts.keys()
	keys.sort()
	for tid in keys:
		var c: Dictionary = d.world.ledger.contracts[tid]
		if str(c.get("status", "")) == "forfeited" and c.get("item_ids", []).has(iid):
			return int(c.get("principal", 0))
	return 0

# ====================================================================
static func _weighted(weights: Dictionary, u: float) -> String:
	var rows: Array = []
	for k in _sorted(weights.keys()):
		if float(weights[k]) > 0.0:
			rows.append([str(k), float(weights[k])])
	return "" if rows.is_empty() else R.weighted_choice(rows, u)

static func _range(bounds: Array, u: float) -> float:
	return float(bounds[0]) + (float(bounds[1]) - float(bounds[0])) * u

static func _sorted(values: Array) -> Array:
	var out: Array = values.duplicate()
	out.sort()
	return out
