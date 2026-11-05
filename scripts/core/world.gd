# 世界状态与自主运行（GameJev W02 日程、R01/R02 世界轮盘、I01/I02 影响与传播、P05 信息边界、W07 承诺）
# 主角不在场时，人物照样按日程过日子、花钱、传话；玩家只能从门外街景、来客的话、电报里看到碎片。
extends RefCounted

const Mind = preload("res://scripts/core/mind.gd")
const Ledger = preload("res://scripts/core/ledger.gd")
const SaveState = preload("res://scripts/core/save.gd")

signal observed(entry)   # 档案簿新增条目（UI 刷新）
signal changed           # 数值/钱/时间变化（HUD 刷新）

const SLOTS = ["清晨", "上午", "中午", "下午", "傍晚", "夜"]
const SOURCE_CN = {"seen": "亲眼", "heard": "听说", "inferred": "推测"}

var db
var world_seed: int = 19380306
var ledger
var mind
var npcs: Dictionary = {}
var day: int = 0          # 0 = 序章夜
var slot: int = 5         # 0..5 = 清晨..夜
var koubei: int = 50      # 口碑（显示）
var benxin: int = 50      # 本心（隐藏）
var suspicion: int = 0    # 维持会怀疑（隐藏，0-10）
var faction_trust: Dictionary = {}
var chen_trust: int = 0
var flags: Dictionary = {}
var notebook: Array = []  # 档案簿：{day, slot, kind, source(seen/heard/inferred), via, conf, text}
var pages: Array = []     # 已解锁的知识页 id
var todos: Array = []     # 待办：{who, text, due_day, countdown, status}
var risks: Array = []     # 待发的风险：{kind, ref, text, status}（如当票写“破旧”，赎当时口碑 -3）
var liabilities: Array = []  # 应付（不是钱，是要付的义务）：{to, what, amount, due_day, status}
var unlocked: Dictionary = {}
var rumors: Dictionary = {}
var street_log: Array = []
var world_log: Array = [] # 开发者看的全知日志（玩家看不到）
var weather: String = "薄雾"
var rice_mod: float = 1.0
var med_mod: float = 1.0
var patrol_cooldown: int = 0
var news: Array = []          # 世界轮盘带来的、主角“听来”的消息：{text, via}（导演负责念出来）
var prev_rice_mod: float = 1.0
var prev_med_mod: float = 1.0
var door_flag: String = "none"
var door_flag_next: String = "none"
var sign_board: String = "rice"
var day_journal_start: int = 0
var town = null          # 可选小镇模拟；为 null 时保留线性版所有行为

# Content and runtime object references belong to setup, not to the save.
# Save every script state field, including NPC personalities and memories,
# with exact floating-point values so future decisions keep the same keys.
func to_dict() -> Dictionary:
	return SaveState._encode_state(SaveState.object_state_to_dict(self, SaveState.WORLD_EXCLUDED))

func from_dict(d: Dictionary) -> void:
	if not SaveState._json_safe(d):
		return
	var state: Dictionary = SaveState._decode_state(d)
	if not SaveState._object_shape(state, SaveState.object_state_to_dict(self, SaveState.WORLD_EXCLUDED)):
		return
	SaveState.object_state_from_dict(self, state, SaveState.WORLD_EXCLUDED)
	if mind == null:
		mind = Mind.new(world_seed)
	else:
		mind.world_seed = world_seed

func setup(p_seed: int = 19380306) -> void:
	db = DB.get_db()
	world_seed = p_seed
	ledger = Ledger.new()
	mind = Mind.new(world_seed)
	ledger.open_account("player", 600)
	for id in db.cast:
		var def: Dictionary = db.cast[id]
		var n := {"id": id, "def": def, "name": def.get("name", id), "label": def.get("label", id), "persona": Mind.make_persona(def),
			"rel": {"player": Mind.fresh_rel()}, "location": "", "present": true, "knows": {}, "log": []}
		npcs[id] = n
		ledger.open_account(id, int(def.get("cash", 0)))
	for e in db.edges:
		if npcs.has(e[0]) and npcs.has(e[1]):
			Mind.relate(npcs[e[0]], e[1], {"trust": 0.1 * e[2], "affection": 0.1 * e[2], "familiarity": e[2]})
			Mind.relate(npcs[e[1]], e[0], {"trust": 0.1 * e[2], "affection": 0.1 * e[2], "familiarity": e[2]})
	for k in db.outside_accounts:
		ledger.open_account(k, int(db.outside_accounts[k]))
	for f in db.factions.get("factions", []):
		faction_trust[f["key"]] = 0
	faction_trust["王山那边"] = 0
	_place_everyone()
	# 开局时镇上已经在传的事（世界不从主角开始）
	_plant("liangmin_notice", "ma", true)
	_plant("hospital_requisition", "zhang", true)
	# v0.3 P1：开局账单（铺租）。开局当品改由剧情 give_stock 发放，避免冲掉「无库存」分支测试
	liabilities.append({"to": "保长", "what": "铺租", "amount": 30, "due_day": 7, "status": "未付"})
	add_todo("账房", "铺租 30 蚨（七日之内）", 7, true)

# ---------------- 日期 ----------------
func date_text(d: int = -1) -> String:
	if d < 0: d = day
	if d == 0:
		return "民国二十七年 二月初四 · 夜"
	var lunar := 4 + d          # 二月初四 = 第 0 天；农历按每月三十天近似
	var month := 2 + int((lunar - 1) / 30)
	var mday := (lunar - 1) % 30 + 1
	var months := ["", "正月", "二月", "三月", "四月", "五月", "六月", "七月", "八月", "九月", "十月", "冬月", "腊月"]
	var weekdays := ["星期日", "星期一", "星期二", "星期三", "星期四", "星期五", "星期六"]
	return "民国二十七年 %s%s · %s" % [months[clampi(month, 1, 12)], _lunar_day(mday), weekdays[(d - 1) % 7]]

func weekday(d: int = -1) -> int:
	if d < 0: d = day
	return (d - 1) % 7

static func _lunar_day(n: int) -> String:
	var cn := ["", "一", "二", "三", "四", "五", "六", "七", "八", "九", "十"]
	if n <= 10: return "初" + cn[n]
	if n < 20: return "十" + cn[n - 10]
	if n == 20: return "二十"
	if n < 30: return "廿" + cn[n - 20]
	return "三十"

func slot_name() -> String:
	return SLOTS[slot]

func days_to_saturday() -> int:
	var w := weekday()
	return (6 - w + 7) % 7

# ---------------- 数值 ----------------
func add(stat: String, delta: int, why: String = "") -> void:
	if stat.begins_with("favor:"):
		var who := stat.substr(6)
		if npcs.has(who):
			favor(who, delta)
	elif stat.begins_with("faction:"):
		var k := stat.substr(8)
		faction_trust[k] = clampi(int(faction_trust.get(k, 0)) + delta, -20, 20)
	else:
		match stat:
			"koubei": koubei = clampi(koubei + delta, 0, 100)
			"benxin": benxin = clampi(benxin + delta, 0, 100)
			"suspicion": suspicion = clampi(suspicion + delta, 0, 10)
			"chen", "chen_trust": chen_trust = clampi(chen_trust + delta, -20, 20)
			_:
				if faction_trust.has(stat):
					faction_trust[stat] = clampi(int(faction_trust[stat]) + delta, -20, 20)
				else:
					push_error("未知数值：" + stat)
					return
	world_log.append("[%s %s] %s %+d %s" % [date_text(), slot_name(), stat, delta, why])
	# 口碑是公开的：变化时档案簿里记一笔（原因是主角自己的推测）；本心、怀疑等隐藏数值不记
	if stat == "koubei" and delta != 0:
		note("口碑", "街坊的口碑%s了（%s）。" % ["好了些" if delta > 0 else "差了些", why if why != "" else "说不清为什么"], "inferred")
	emit_signal("changed")

func stat(name: String) -> int:
	if name.begins_with("faction:"):
		return int(faction_trust.get(name.substr(8), 0))
	if name.begins_with("favor:"):
		var who := name.substr(6)
		if npcs.has(who):
			var r: Dictionary = npcs[who]["rel"].get("player", Mind.fresh_rel())
			return int(round((float(r["affection"]) - 0.3) * 40.0))
		return 0
	match name:
		"koubei": return koubei
		"benxin": return benxin
		"suspicion": return suspicion
		"chen", "chen_trust": return chen_trust
		"cash": return cash()
	return int(faction_trust.get(name, 0))

# 人物好感：映射到 GameJev 面向对象关系的多个维度，不是单一好感条
func favor(npc_id: String, delta: int) -> void:
	var n: Dictionary = npcs[npc_id]
	var d := float(delta) / 40.0
	if delta >= 0:
		Mind.relate(n, "player", {"trust": d * 0.8, "affection": d, "respect": d * 0.5, "indebtedness": d * 0.6})
		Mind.feel(n, {"joy": d, "help": d, "positive": d, "recency": 0.5})
	else:
		Mind.relate(n, "player", {"trust": d * 0.6, "affection": d, "resentment": -d})
		Mind.feel(n, {"anger": -d, "negative": -d, "humiliation": -d * 0.5, "recency": 0.5})

func fuzzy_trust(v: int) -> String:
	if v >= 8: return "亲近"
	if v <= -5: return "冷淡"
	return "一般"

# 世界轮盘给的当日行情系数（米价、药价随世界自己走）
func price_mod(it: Dictionary) -> float:
	match str(it.get("cat", "")):
		"rice": return rice_mod
		"medicine": return med_mod
	return 1.0

func market_now(it: Dictionary) -> int:
	return int(round(float(it.get("market", 0)) * price_mod(it) * (1.0 + float(it.get("tidy_bonus", 0.0)) + float(it.get("market_bonus", 0.0)))))

func cash() -> int:
	return ledger.balance("player")

# ---------------- 档案簿 / 待办 ----------------
# 信息带来源标签：seen 亲眼 / heard 听说 / inferred 推测（GameJev P05、设计 10）
func note(kind: String, text: String, source: String = "seen", via: String = "", conf: float = 1.0) -> void:
	if not SOURCE_CN.has(source):
		source = "seen"
	var e := {"day": day, "slot": slot, "kind": kind, "source": source, "via": via, "conf": conf, "text": text}
	notebook.append(e)
	emit_signal("observed", e)

func add_page(id: String) -> void:
	if not pages.has(id):
		pages.append(id)
		emit_signal("observed", {"kind": "页", "text": id})

func add_risk(kind: String, ref: String, text: String) -> void:
	risks.append({"kind": kind, "ref": ref, "text": text, "status": "未发", "day": day})
	note("线索", "埋下的隐患：" + text, "inferred")

func add_liability(to: String, what: String, amount: int, due_day: int) -> void:
	for l in liabilities:
		if l["what"] == what and l["status"] == "未付":
			l["amount"] = amount
			l["due_day"] = due_day
			emit_signal("changed")
			return
	liabilities.append({"to": to, "what": what, "amount": amount, "due_day": due_day, "status": "未付"})
	emit_signal("changed")

# 赎当：账本收款与返物一起成功；若当票写了“破旧”，当户发现，口碑 -3（设计稿第二天清晨）
func redeem_contract(tid: String) -> bool:
	if not ledger.redeem(tid, day):
		return false
	for r in risks:
		if r["kind"] == "ticket_old" and r["ref"] == tid and r["status"] == "未发":
			r["status"] = "已发"
			add("koubei", -3, "当户赎当时发现当票写了“破旧”")
	return true

# 夜里每过一盏灯油：消息照样沿熟人传，巡夜的可能经过（世界不等主角）
func night_tick(night_no: int, step: int) -> Array:
	var out: Array = []
	_propagate_rumors()
	var r := RandomNumberGenerator.new()
	r.seed = hash("%d|night|%d|%d" % [world_seed, night_no, step])
	var p := _pick({"quiet": 5.0, "boots": 1.0, "truck": 1.0, "dog": 1.0}, r)
	match p:
		"boots": out.append("街上有皮靴声走过去，停了一下，又走远了。")
		"truck": out.append("远处有卡车开过，灯光从门板缝里扫了一下。")
		"dog": out.append("桥那头的狗叫了几声，很快停了。")
	if p != "quiet":
		world_log.append("[夜] %s" % p)
		for s in out:
			note("街景", s, "seen")
	return out

func add_todo(who: String, text: String, due_day: int = -1, countdown: bool = false) -> void:
	todos.append({"who": who, "text": text, "due_day": due_day, "countdown": countdown, "status": "未了", "day": day})
	emit_signal("changed")

func countdown_text() -> String:
	for t in todos:
		if t["countdown"] and t["status"] == "未了" and int(t["due_day"]) >= day:
			var amt := ""
			for l in liabilities:
				if l["status"] == "未付" and int(l["due_day"]) == int(t["due_day"]):
					amt = "（%d 蚨）" % int(l["amount"])
			return "距缴费还有 %d 天%s" % [int(t["due_day"]) - day, amt]
	return ""

# ---------------- 日程 ----------------
func _place_everyone() -> void:
	for id in npcs:
		var n: Dictionary = npcs[id]
		if not n["present"]:
			continue
		var sched: Dictionary = n["def"]["sched"]
		var arr: Array = sched.get(str(day), sched["default"])
		n["location"] = arr[slot]
		var override = n.get("loc_override", {})
		var key := "%d_%d" % [day, slot]
		if override.has(key):
			n["location"] = override[key]

func where(npc_id: String) -> String:
	return npcs[npc_id]["location"] if npcs[npc_id]["present"] else "（不在镇上）"

# ---------------- 推进时段：世界自己转 ----------------
# 返回：主角能直接看到的门外街景（只有这些进入档案簿“亲眼所见”）
func advance_slot() -> Array:
	if town != null:
		# 小镇的日期由时钟主人决定，旧剧情不能另摇轮盘或替 NPC 花钱。
		if slot < 5:
			town.set_minute(int(town.pack["time"]["slot_hours"][slot + 1]) * 60)
		emit_signal("changed")
		return []
	slot += 1
	if slot > 5:
		slot = 0
		day += 1
		door_flag = door_flag_next
		ledger.tick_contracts(day)
		ledger.tick_debts(day)
	_place_everyone()
	var seen: Array = []
	seen.append_array(_wheel())
	_offscreen_life()
	_propagate_rumors()
	for id in npcs:
		Mind.decay(npcs[id])
	seen.append_array(_street_view())
	if slot == 0 and flags.get("zhouma_news", false) and npcs.has("zhouma") and npcs["zhouma"]["present"]:
		# 周妈从此每天带一条“镇上新闻”（设计稿第二天）——她知道什么就说什么，带转述层次
		for key in npcs["zhouma"]["knows"]:
			var rr: Dictionary = rumors.get(key, {})
			if rr.is_empty() or rr.get("player_knows", false):
				continue
			rr["player_knows"] = true
			var k: Dictionary = npcs["zhouma"]["knows"][key]
			var text := rumor_text(key, int(k["hops"]))
			news.append({"text": text, "via": "周妈"})
			note("消息", text, "heard", "zhouma", float(k["conf"]))
			break
	for s in seen:
		street_log.append({"day": day, "slot": slot, "text": s})
		note("街景", s, "seen")
	emit_signal("changed")
	return seen

func _rng(domain: String) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = hash("%d|%s|%d|%d" % [world_seed, domain, day, slot])
	return r

func _pick(weights: Dictionary, r: RandomNumberGenerator) -> String:
	var tot := 0.0
	for k in weights: tot += float(weights[k])
	var x := r.randf() * tot
	for k in weights:
		x -= float(weights[k])
		if x <= 0.0:
			return k
	return weights.keys()[0]

# 世界轮盘：天气、巡逻、米船、收药都不读取玩家好坏（外生）；每个轮盘都有 quiet。内生压力反馈尚未接入（v0.1）。
func _wheel() -> Array:
	var out: Array = []
	var w := _pick({"quiet": 6.0, "薄雾": 1.0, "细雨": 1.0, "放晴": 1.0}, _rng("climate"))
	if day == 1 and slot == 0:
		w = "quiet"   # 第一天清晨剧本写定“薄雾”
	if w != "quiet" and w != weather:
		weather = w
		if slot != 5:
			out.append({"薄雾": "河面上起了雾，桥那头的人影看不清了。", "细雨": "下起了细雨，青石板一片湿亮。", "放晴": "雾散了，太阳照在对面墙的告示上。"}[w])
	if patrol_cooldown > 0:
		patrol_cooldown -= 1
	else:
		var p := _pick({"quiet": 8.0, "patrol": 1.0}, _rng("order"))
		if p == "patrol":
			patrol_cooldown = 4
			out.append("远处传来皮靴声，一队人从街口过去了。街上的人都低下头。")
			for id in npcs:
				if npcs[id]["location"] in ["桥头街", "街上", "茶馆"]:
					Mind.feel(npcs[id], {"fear": 0.2})
			world_log.append("[轮盘] 巡逻经过")
	if slot == 0 and day > 0:
		prev_rice_mod = rice_mod
		prev_med_mod = med_mod
		var rb := _pick({"quiet": 2.0, "boat": 1.0, "noboat": 1.0}, _rng("logistics"))
		if rb == "boat":
			rice_mod = maxf(0.85, rice_mod - 0.05)
			world_log.append("[轮盘] 米船到了，米价回落 → %.2f" % rice_mod)
			_news("米船昨夜到了码头，米行今早落了价。", "挑担的")
		elif rb == "noboat":
			rice_mod = minf(1.3, rice_mod + 0.08)
			world_log.append("[轮盘] 米船没来，米价上涨 → %.2f" % rice_mod)
			_news("说是河上设了卡，米船没来，米行一早就涨了价。", "挑担的")
		var md := _pick({"quiet": 2.0, "requisition": 1.0, "smuggle": 1.0}, _rng("medicine"))
		if md == "requisition":
			med_mod = minf(1.4, med_mod + 0.1)
			world_log.append("[轮盘] 城里在收药，药价上涨 → %.2f" % med_mod)
			_news("城里的兵在各乡收药，药铺里西药一天一个价。", "卖菜的")
		elif md == "smuggle":
			med_mod = maxf(0.85, med_mod - 0.05)
			world_log.append("[轮盘] 有人从上海带药回来，药价稍落 → %.2f" % med_mod)
			_news("有船从上海带了一批药回来，药价松了点。", "卖菜的")
	return out

func _news(text: String, via: String) -> void:
	news.append({"text": text, "via": via})
	note("行情", text, "heard", via)

# 行情牌（右侧栏）：两样参照货的当日市价，跟昨天比涨跌——世界自己转，不看主角
func price_board() -> String:
	var rice := int(round(68.0 * rice_mod))
	var med := int(round(100.0 * med_mod))
	return "行情：中白米一袋 %d%s　奈宁一瓶 %d%s" % [rice, _arrow(rice_mod, prev_rice_mod), med, _arrow(med_mod, prev_med_mod)]

static func _arrow(now: float, before: float) -> String:
	if now > before + 0.001:
		return "↑"
	if now < before - 0.001:
		return "↓"
	return ""

# 场外生活：人物按日程和自身处境行动，钱真实流转。玩家没参与的事也照样发生。
func _offscreen_life() -> void:
	var key := "%d_%d" % [day, slot]
	# 小丁：拿到钱后，下午去济生堂给娘抓药
	if day == 1 and slot == 3:
		var c: int = ledger.balance("xiaoding")
		if c > 0:
			var spend := mini(c, 15)
			ledger.transfer("xiaoding", "济生堂柜", spend, "小丁抓药")
			_learn("chen", "xiaoding_herbs", "xiaoding")
			world_log.append("[场外] 小丁在济生堂花 %d 蚨抓了退热的草药" % spend)
	# 张护士：凑够路费就走；没凑够，她自己想办法（大脑决定）
	if day == 1 and slot == 4:
		var zc: int = ledger.balance("zhang")
		var zh: Dictionary = npcs["zhang"]
		if zc >= 120:
			var d: Dictionary = mind.decide(zh, [
				{"id": "leave", "utility": 0.8, "attrs": {"safety": 0.7, "gain": 0.3, "withdrawal": 0.6, "commitment": 0.6, "immediacy": 0.8, "risk": 0.3}},
				{"id": "wait", "utility": 0.2, "attrs": {"delay": 0.7, "uncertainty": 0.6, "safety": 0.2}}], {"context": {"time_pressure": 0.7, "threat": 0.4}}, "zhang_leave")
			if d["id"] == "leave":
				flags["zhang_left"] = true
				zh["loc_override"] = {"2_0": "码头"}
				world_log.append("[场外] 张护士买了明早的船票，带弟弟走")
		else:
			world_log.append("[场外] 张护士路费不够，在客栈多住一晚")
	if day == 2 and slot == 1 and flags.get("zhang_left", false):
		npcs["zhang"]["present"] = false
		_plant("zhang_gone", "zhang", true)
	# 王山：入夜出镇
	if day == 1 and slot == 5:
		npcs["wangshan"]["present"] = false
	# 赵老三：中午若还没凑到三百，自己去孙府想办法（世界不等主角）
	if day == 2 and slot == 2:
		var zz: Dictionary = npcs["zhao"]
		if ledger.balance("zhao") < 300 and not flags.get("zhao_sold_land", false):
			var d2: Dictionary = mind.decide(zz, [
				{"id": "sell_to_sun", "utility": 0.9, "attrs": {"gain": 0.6, "immediacy": 0.9, "resource_cost": 0.9, "reversibility": 0.0, "fulfill": 0.0, "care": 0.8, "dignity": 0.1}},
				{"id": "borrow_kin", "utility": 0.3, "attrs": {"affiliation": 0.6, "delay": 0.6, "uncertainty": 0.7, "dignity": 0.4}}], {"context": {"time_pressure": 0.95, "stakes": 0.95, "exit_access": 0.2}}, "zhao_noon")
			if d2["id"] == "sell_to_sun" and ledger.transfer("sunlaoye", "zhao", 400, "孙府低价收地", "赵家红契") != "":
				flags["zhao_sold_land"] = true
				var did := _item_of("zhao", "deed_zhao")
				if did != "":
					ledger.move_item(did, "npc:sunlaoye", "sunlaoye", "赵老三以 400 蚨卖给孙府")
				_plant("zhao_sold_land", "zhao", true)
				world_log.append("[场外] 赵老三把一亩二分水田以 400 蚨卖给了孙府")
			else:
				world_log.append("[场外] 赵老三去找本家借钱")
	# 下午：赵老三拿钱去保安队赎人；林嫂去银楼付金锁定钱；孙少爷去告状
	if day == 2 and slot == 3:
		if ledger.balance("zhao") >= 300:
			ledger.transfer("zhao", "保安队", 300, "赎壮丁")
			flags["zhao_son_free"] = true
			npcs["zhao"]["loc_override"] = {"2_4": "桥头街"}
			_plant("zhao_son_free", "zhao", true)
			world_log.append("[场外] 赵老三交了 300 蚨，儿子放回来了")
		if ledger.balance("linsao") >= 100:
			ledger.transfer("linsao", "银楼", 100, "金锁定钱")
			flags["linsao_lock_ordered"] = true
			world_log.append("[场外] 林嫂在银楼付了金锁定钱")
	if day == 2 and slot == 4 and flags.get("sun_young", "") == "exposed":
		var sy: Dictionary = npcs["sunyoung"]
		var d3: Dictionary = mind.decide(sy, [
			{"id": "complain", "utility": 1.2, "attrs": {"status": 0.7, "confrontation": 0.5, "harm": 0.3, "dignity": 0.8, "social_exposure": 0.3}},
			{"id": "let_go", "utility": -0.2, "attrs": {"withdrawal": 0.5, "dignity": 0.2}}], {"context": {"publicness": 0.6}}, "sun_complain")
		if d3["id"] == "complain":
			_learn("ma", "sun_exposed", "sunyoung")
			world_log.append("[场外] 孙少爷去维持会跟马保长说了德厚当的坏话")

# 门外街景：只看见经过桥头街的人（信息边界）
func _street_view() -> Array:
	var out: Array = []
	if slot == 5:
		return out
	for id in npcs:
		var n: Dictionary = npcs[id]
		if not n["present"] or n["location"] != "桥头街" or n.get("at_counter", false):
			continue
		if id == "zhao" and flags.get("zhao_son_free", false) and day == 2 and slot == 4:
			out.append("赵老三领着一个后生从桥上走过，后生一瘸一拐，赵老三一只手一直搭在他肩上。")
		if id == "ma" and slot == 4 and day == 2:
			out.append("马保长挨家挨户敲门，账本夹在胳膊底下。")
		elif id == "sunyoung" and slot == 3:
			pass
	# 赵老三卖地：不管他在哪儿，下午总有人看见（街坊的眼睛）
	if day == 2 and slot >= 3 and flags.get("zhao_sold_land", false) and not flags.get("_seen_zhao_sold", false):
		flags["_seen_zhao_sold"] = true
		out.append("赵老三从孙府那边过来，低着头，烟杆没点。手里攥着一卷钞票——那张红契不在他怀里了。")
	if day == 2 and slot == 0 and flags.get("zhang_left", false):
		out.append("清早的乌篷船从桥下过，船头坐着一个穿蓝旗袍的女人，身边是个半大孩子。")
	return out

# ---------------- 消息传播（只沿熟人边，有衰减、跳数、变样） ----------------
const FACTS = {
	"sunji_rice": ["德厚当卖的米，袋子上印着“孙记”", "孙家的米跑到当铺里去了", "孙家库里的米让人偷出去当了"],
	"xiaoding_herbs": ["小丁给他娘抓了退热的药", "小丁他娘病得不轻", "小丁家里出了事"],
	"zhang_gone": ["张护士带着弟弟坐早船走了", "教会医院的张护士跑了", "医院里的人都在往外跑"],
	"zhao_son_free": ["赵老三把儿子从保安队赎回来了", "赵家儿子放回来了，腿打坏了", "保安队收钱放人"],
	"zhao_sold_land": ["赵老三把水田卖给孙家了，才四百", "孙家又收了一块地", "孙家趁乱收地"],
	"sun_exposed": ["沈家丫头当面拆穿了孙少爷的假地契", "孙少爷在德厚当丢了脸", "德厚当跟孙家结了梁子"],
	"li_reported": ["德厚当的丫头把学生的小报交给了维持会", "沈家丫头跟维持会走得近", "德厚当靠不住"],
	"fair_shop": ["德厚当的小掌柜给价公道", "德厚当的丫头心善", "德厚当好说话"],
	"liangmin_notice": ["维持会贴了告示：人人要办良民证，一个人三十蚨", "办良民证要三十蚨，不办的要抓去问话", "良民证的钱怕是要涨到五十蚨了"],
	"hospital_requisition": ["县城教会医院被征用了，西医生都走了", "教会医院让城里的兵占了，病人都赶出来了", "县城里在抓懂医的人"],
	"sun_fake_deed": ["孙少爷拿假地契去德厚当周转", "孙家少爷在外头欠了钱", "孙家要败了"],
	"fake_hospital": ["医院里有人往药里掺假", "教会医院的磺胺是假的", "县城的药都靠不住"],
}

func plant_rumor(key: String, origin: String) -> void:
	if town != null:
		town.plant_rumor(key, origin)
		return
	if npcs.has(origin):
		_plant(key, origin, true)
	else:
		push_error("流言来源不是人物：" + origin)

func _plant(key: String, origin: String, truth: bool) -> void:
	if not rumors.has(key):
		rumors[key] = {"key": key, "origin": origin, "truth": truth, "player_knows": false}
	_learn(origin, key, origin, 0, 1.0)

func _learn(npc_id: String, key: String, via: String, hops: int = 0, conf: float = 1.0) -> void:
	if not rumors.has(key):
		rumors[key] = {"key": key, "origin": via, "truth": true, "player_knows": false}
	var n: Dictionary = npcs[npc_id]
	if n["knows"].has(key):
		return  # 同源只记一次
	n["knows"][key] = {"hops": hops, "conf": conf, "via": via, "day": day, "slot": slot}
	_on_learn(npc_id, key)

# 听到消息后的后果：只有消息真的到了这个人，才会影响这个人
func _on_learn(npc_id: String, key: String) -> void:
	match [npc_id, key]:
		["sunlaoye", "sunji_rice"]:
			flags["sun_rice_rumor"] = true
			world_log.append("[传播] 孙老爷听说了“孙记”米的事，打算派人去德厚当问问")
		["ma", "sun_exposed"]:
			flags["ma_heard_sun"] = true
			Mind.relate(npcs["ma"], "player", {"resentment": 0.2})
		["ma", "li_reported"]:
			pass
		["zhouma", "fair_shop"], ["linsao", "fair_shop"]:
			add("koubei", 1, "街坊传：给价公道（%s 听说）" % npcs[npc_id]["label"])
		["zhouma", "li_reported"]:
			add("koubei", -3, "周妈听说举报的事")
		["chen", "fake_hospital"]:
			add("chen", 1, "陈叔叔得知假药")
		["xiaoding", "sunji_rice"]:
			Mind.feel(npcs["xiaoding"], {"fear": 0.4})

func _propagate_rumors() -> void:
	var pending: Array = []
	for id in npcs:
		var n: Dictionary = npcs[id]
		if not n["present"]:
			continue
		for key in n["knows"]:
			var k: Dictionary = n["knows"][key]
			if k["day"] == day and k["slot"] == slot:
				continue  # 刚听到的，下个时段才会转述（延迟）
			if int(k["hops"]) >= 3 or float(k["conf"]) < 0.3:
				continue
			for other in n["rel"]:
				if other == "player" or not npcs.has(other) or npcs[other]["knows"].has(key) or not npcs[other]["present"]:
					continue
				var edge: float = float(n["rel"][other].get("familiarity", 0.0))
				if edge <= 0.0:
					continue
				var soc: float = float(n["persona"]["traits"].get("sociability", 0.5))
				var p := edge * soc * float(k["conf"]) * 0.7
				var r := RandomNumberGenerator.new()
				r.seed = hash("%d|rumor|%s|%s|%s|%d|%d" % [world_seed, key, id, other, day, slot])
				if r.randf() < p:
					pending.append([other, key, id, int(k["hops"]) + 1, float(k["conf"]) * 0.75])
	for p in pending:
		_learn(p[0], p[1], p[2], p[3], p[4])
		world_log.append("[传播] %s → %s：%s" % [npcs[p[2]]["label"], npcs[p[0]]["label"], rumor_text(p[1], p[3])])

func rumor_text(key: String, hops: int) -> String:
	var v: Array = FACTS.get(key, [key])
	return v[mini(hops, v.size() - 1)]

# 来客是否把听到的事告诉主角：由人物大脑决定（关系、性格、场合），不是自动全知
func share_rumors(npc_id: String) -> Array:
	if town != null:
		return town.share_rumors(npc_id)
	var out: Array = []
	var n: Dictionary = npcs[npc_id]
	for key in n["knows"]:
		var r: Dictionary = rumors.get(key, {})
		if r.is_empty() or r.get("player_knows", false):
			continue
		if r["origin"] == npc_id and key in ["sun_exposed", "zhao_sold_land", "li_reported"]:
			continue
		var k: Dictionary = n["knows"][key]
		var d: Dictionary = mind.decide(n, [
			{"id": "tell", "utility": 0.3 + float(n["persona"]["traits"]["sociability"]) * 0.6, "attrs": {"disclosure": 0.8, "affiliation": 0.6, "information": 0.6, "social_exposure": 0.3}},
			{"id": "keep", "utility": 0.3, "attrs": {"withdrawal": 0.4, "safety": 0.5}}], {"context": {"publicness": 0.3}}, "share_" + key)
		if d["id"] == "tell":
			r["player_knows"] = true
			var text := rumor_text(key, int(k["hops"]))
			if int(k["hops"]) > 0:
				text += "（%s也是听别人讲的）" % n["label"]
			note("消息", text, "heard", npc_id, float(k["conf"]))
			out.append(text)
	return out

func _item_of(owner: String, def_id: String) -> String:
	for iid in ledger.items:
		var it: Dictionary = ledger.items[iid]
		if it.get("def_id", "") == def_id and it["owner"] == owner:
			return iid
	return ""

# ---------------- 后台延展模拟（开发者 / 冒烟测试：第三天以后世界自己怎么走） ----------------
# 玩家在这段时间里什么都不做，只看世界与已有的债务、合同自己推进。
func backend_simulate(until_day: int) -> Array:
	var out_log: Array = []
	while day < until_day:
		for i in range(6):
			advance_slot()
			if slot == 0:
				out_log.append_array(_backend_day_events())
		var errs: Array = ledger.check_invariants()
		if not errs.is_empty():
			out_log.append("!! 账本不变量失败：" + str(errs))
	return out_log

func _backend_day_events() -> Array:
	var out: Array = []
	var d := day
	# 工钱与日常开销（真实流转）
	if npcs["xiaoding"]["present"]:
		ledger.transfer("sunlaoye", "xiaoding", 4, "伙夫工钱")
		if not flags.get("xiaoding_mother_well", false):
			ledger.transfer("xiaoding", "济生堂柜", mini(2, ledger.balance("xiaoding")), "给娘抓药")
	if d == 3 and flags.get("quinine_in_stock_day1", false) and flags.get("xiaoding_rice", "") == "fair":
		out.append("第%d天：小丁回来想买奈宁（剧本伏笔，后台记录为来访意图）" % d)
	if d == 4:
		out.append("第4天：哥哥的第一封家书到了——教“吹银元听响”。（家书解锁鉴定技能，待做）")
		if flags.get("li_paper", "") == "reported":
			npcs["li"]["present"] = false
			_plant("li_reported", "ma", true)
			out.append("第4天：李敬之被维持会带走了。")
	if d <= 5 and flags.get("sun_rice_rumor", false) and not flags.get("sun_sent_man", false):
		flags["sun_sent_man"] = true
		out.append("第%d天：孙府管家到德厚当打听那袋“孙记”的米。" % d)
	if d == 5 and flags.get("sold_fake_to_wangshan", false):
		out.append("第5天：王山带着两个人回来了，脸色很难看。")
	# 小丁的借款：能还/想还分开判断
	for did in ledger.debts:
		var debt: Dictionary = ledger.debts[did]
		if debt["status"] in ["settled"] or debt["kind"] == "recourse":
			continue
		if debt["debtor"] == "xiaoding" and d >= 5:
			out.append(_debtor_turn(did, d))
		if debt["debtor"] == "wangshan" and d == 9:
			out.append(_debtor_turn(did, d))
	# 林嫂：船行汇款是外生事件
	var r := _rng("remit")
	if npcs["linsao"]["present"] and not flags.get("linsao_remit", false) and r.randf() < 0.12:
		ledger.transfer("船行", "linsao", 150, "丈夫汇款")
		flags["linsao_remit"] = true
		out.append("第%d天：林嫂丈夫的汇款到了（她还没来赎，当期到第32天）。" % d)
	if weekday(d) == 6:
		out.append("第%d天（星期六）：马保长来收维持费。（后台模拟不替玩家做决定）" % d)
	return out

func _debtor_turn(did: String, d: int) -> String:
	var debt: Dictionary = ledger.debts[did]
	var who: String = debt["debtor"]
	var n: Dictionary = npcs[who]
	if not n["present"]:
		return "第%d天：%s 不在镇上，借据挂着（缺席不等于赖账）。" % [d, n["label"]]
	var have: int = ledger.balance(who)
	var owe: int = int(debt["outstanding"])
	var cands: Array = []
	# 知识条件筛选：没钱就不能足额还（守约人格也变不出钱）
	if have >= owe:
		cands.append({"id": "repay_full", "utility": 0.6 + float(n["rel"]["player"]["indebtedness"]), "attrs": {"commitment": 0.9, "fairness": 0.8, "repair": 0.5, "resource_cost": 0.7, "target_benefit": 0.8}})
	if have > 0:
		cands.append({"id": "repay_part", "utility": 0.4, "attrs": {"commitment": 0.6, "fairness": 0.6, "resource_cost": 0.4, "target_benefit": 0.5}})
	cands.append({"id": "ask_grace", "utility": 0.2, "attrs": {"delay": 0.7, "disclosure": 0.6, "dignity": 0.3, "repair": 0.3}})
	cands.append({"id": "avoid", "utility": -0.3 + float(n["rel"]["player"]["resentment"]), "attrs": {"withdrawal": 0.8, "deception": 0.4, "norm_violation": 0.5}})
	var dec: Dictionary = mind.decide(n, cands, {"context": {"stakes": 0.5}}, "debt_%s_%d" % [did, d])
	match dec["id"]:
		"repay_full":
			var p: int = ledger.pay_debt(did, owe)
			return "第%d天：%s 来还了 %d 蚨，借据结清。" % [d, n["label"], p]
		"repay_part":
			var p2: int = ledger.pay_debt(did, maxi(1, have / 2))
			return "第%d天：%s 先还了 %d 蚨，说剩下的过些日子。" % [d, n["label"], p2]
		"ask_grace":
			return "第%d天：%s 来求宽限，手头只有 %d 蚨（还不起 ≠ 不想还）。" % [d, n["label"], have]
		_:
			return "第%d天：%s 这几天绕着德厚当走。" % [d, n["label"]]
