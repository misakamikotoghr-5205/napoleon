# 《德厚当》剧情导演：解释 data/story/*.json 与 data/sessions/*.json（docs/INTERFACES.md §5–§8、§11）。
# 剧情按 flow.json 顺序：序章 → 第一天 → 第一晚 → 第二天 → 第二晚 → “德字第一九六号”。
# 每个需要玩家回应的 beat 通过信号发给界面（或自动试玩器），用 await 等待 submit()。
# 底下由 GameJev 系统驱动：人格大脑（mind/PersonaResidual）、账本（ledger）、日程与世界轮盘、消息传播（world）。
extends Node

const World = preload("res://scripts/core/world.gd")
const Session = preload("res://scripts/core/session.gd")
const Cond = preload("res://scripts/core/cond.gd")
const ScriptVM = preload("res://scripts/core/script_vm.gd")
const SaveState = preload("res://scripts/core/save.gd")
const TownCosts = preload("res://scripts/sim/living_costs.gd")
const Protection = preload("res://scripts/core/protection.gd")      # [shop-only]
const Walkin = preload("res://scripts/core/walkin.gd")              # [shop-only] 过路客人与门口吆喝
const ShopOnly = preload("res://scripts/town/shop_only.gd")         # [shop-only]

var script_vm
var town_storylets: Dictionary = {}

signal beat(b)
signal input_received(r)
signal checkpoint(name)
signal finished

const KNOWN_OPS = ["caption", "narr", "say", "choice", "tutorial", "practice", "scene", "enter", "leave", "set", "var", "stat",
	"if", "session", "run", "call", "unlock", "page", "note", "rumor", "slot", "item", "move_item", "money", "debt", "todo",
	"summary", "ledger", "night", "telegraph", "chess", "door_flag", "ending", "reprice", "end", "set_judged", "select", "sfx", "repay", "give_stock", "town_action"]

var db
var world
var ctx
var vars: Dictionary = {}
var customer: String = ""
var brother: bool = false
var bg: String = "dark"
var lamp: bool = false
var session = null
var queued_sessions: Array = []
var done: bool = false
var stop_at: String = ""          # 测试用：到达某个 checkpoint 就停
var stopped: bool = false
var beats_emitted: int = 0
var current_script: String = ""
var night_no: int = 0
var lamps: int = 0
var _halt: bool = false
var _action_ok: bool = true
var _last_expr: Dictionary = {}       # 夜里的事真做成了才耗灯油           # `end` 让当前会话里剩下的步骤跳过

func setup(p_seed: int = 19380306) -> void:
	vars.erase("town")
	town_storylets = {}
	db = DB.get_db()
	world = World.new()
	world.setup(p_seed)
	ctx = Cond.new(world, self)
	ensure_vm()

func submit(r) -> void:
	emit_signal("input_received", r)

func _wait(b: Dictionary):
	beats_emitted += 1
	b["date"] = world.date_text()
	b["slot"] = world.slot_name()
	emit_signal("beat", b)
	var r = await input_received
	if typeof(r) != TYPE_DICTIONARY:
		r = {}
	return r

func _show(b: Dictionary) -> void:
	b["nowait"] = true
	b["date"] = world.date_text()
	b["slot"] = world.slot_name()
	emit_signal("beat", b)

func _scene() -> void:
	_show({"type": "scene", "bg": bg, "customer": customer, "brother": brother, "lamp": lamp})

# ====================================================================
func run() -> void:
	for ch in db.flow.get("chapters", []):
		await run_script(str(ch))
		var cp := str(db.flow.get("checkpoints", {}).get(ch, ch))
		emit_signal("checkpoint", cp)
		if stopped or (stop_at != "" and cp == stop_at):
			stopped = true
			break
	done = true
	emit_signal("finished")

func run_script(id: String) -> void:
	if not db.scripts.has(id):
		push_error("缺少剧情脚本：" + id)
		return
	var prev := current_script
	current_script = id
	var previous_slot: int = world.slot
	if _is_town() and id == "prologue": world.slot = 5
	await exec(db.scripts[id].get("steps", []))
	if _is_town() and id == "prologue":
		_town_state()["prologue_done"] = true
		world.slot = previous_slot
	current_script = prev

func fmt(text: String) -> String:
	if text.find("{") < 0:
		return text
	var re := RegEx.new()
	re.compile("\\{([A-Za-z0-9_]+)\\}")
	var out := text
	for m in re.search_all(text):
		var k := m.get_string(1)
		var v = null
		if session != null and session.vars.has(k):
			v = session.vars[k]
		elif vars.has(k):
			v = vars[k]
		elif world.flags.has(k):
			v = world.flags[k]
		if v != null:
			out = out.replace("{" + k + "}", str(v))
	return out

func ensure_vm() -> void:
	if script_vm == null:
		script_vm = ScriptVM.new()
		script_vm.setup(self)

func exec(steps: Array) -> void:
	ensure_vm()
	await script_vm.execute(steps)

func do_step(st: Dictionary) -> void:
	var op := str(st["op"])
	match op:
		"caption":
			await _wait({"type": "caption", "text": fmt(str(st.get("text", ""))), "style": str(st.get("style", "date"))})
		"narr":
			await narr(fmt(str(st.get("text", ""))))
		"say":
			await say(str(st.get("who", "narr")), fmt(str(st.get("text", ""))))
		"choice":
			await _choice(st)
		"tutorial":
			var target := str(st.get("target", ""))
			if st.get("unlock", false):
				world.unlocked[target] = true
			await _wait({"type": "tutorial", "target": target, "who": str(st.get("who", "narr")), "name": db.npc_label(str(st.get("who", "narr"))), "text": fmt(str(st.get("text", "")))})
			world.unlocked[target] = true
		"practice":
			await _practice(st)
		"scene":
			if st.has("bg"):
				bg = str(st["bg"])
			if st.has("brother"):
				brother = bool(st["brother"])
			if st.has("lamp"):
				lamp = bool(st["lamp"])
			_scene()
		"enter":
			enter(str(st.get("who", "")))
		"leave":
			leave()
		"set":
			world.flags[str(st["flag"])] = st.get("value", true)
			world.emit_signal("changed")
		"var":
			var v = st.get("value", null)
			if st.has("expr"):
				v = ctx.eval(str(st["expr"]))
			if session != null:
				session.vars[str(st["name"])] = v
			vars[str(st["name"])] = v
		"stat":
			world.add(str(st["stat"]), int(st.get("delta", 0)), str(st.get("why", current_script)))
		"if":
			if ctx.test(str(st.get("cond", "false"))):
				await exec(st.get("then", []))
			else:
				await exec(st.get("else", []))
		"session":
			await run_session(str(st["id"]))
		"run":
			await run_script(str(st["script"]))
		"call":
			await call_hook(str(st["fn"]), st.get("args", {}))
		"unlock":
			world.unlocked[str(st["target"])] = true
			world.emit_signal("changed")
		"page":
			world.add_page(str(st["id"]))
		"note":
			world.note(str(st.get("kind", "消息")), fmt(str(st.get("text", ""))), str(st.get("source", "seen")), str(st.get("via", "")))
		"rumor":
			world.plant_rumor(str(st["key"]), str(st.get("origin", "")))
			if st.get("told", false) and world.rumors.has(str(st["key"])):
				world.rumors[str(st["key"])]["player_knows"] = true   # 主角自己就是当事人/已经听过，不会再“听说”一遍
		"slot":
			await advance_to(str(st.get("to", "")), int(st.get("day", -1)))
		"item":
			var iid: String = new_item(str(st["def"]), str(st.get("owner", "player")), str(st.get("location", "counter")))
			if st.has("as"):
				vars[str(st["as"])] = iid
		"move_item":
			var mid := ""
			if st.has("var"):
				mid = str(vars.get(str(st["var"]), ""))
			else:
				mid = _find_movable(str(st.get("def", "")))
			if mid != "" and world.ledger.items.has(mid):
				var to := str(st.get("to", "stock"))
				var owner := ""
				if to.begins_with("npc:"):
					owner = to.substr(4)
				elif to in ["stock", "trash", "drawer"]:
					owner = "player"
				world.ledger.move_item(mid, to, owner, str(st.get("note", "")))
				if session != null and session.item_ids.has(mid) and to != "counter":
					session.withdraw(mid)
				world.emit_signal("changed")
		"money":
			var ok: bool = world.ledger.transfer(str(st["from"]), str(st["to"]), int(st.get("amount", 0)), fmt(str(st.get("reason", "")))) != ""
			vars["money_ok"] = ok
			world.emit_signal("changed")
		"debt":
			var did: String = world.ledger.open_debt("iou" if not st.get("cash", false) else "loan", str(st["debtor"]), str(st["creditor"]), int(st["amount"]), world.day, int(st.get("due_day", -1)), bool(st.get("cash", false)), fmt(str(st.get("note", ""))))
			vars["money_ok"] = did != ""
			if did != "":
				world.note("借条", fmt(str(st.get("note", "借据"))), "seen")
			world.emit_signal("changed")
		"todo":
			world.add_todo(str(st.get("who", "")), fmt(str(st.get("text", ""))), int(st.get("due_day", -1)), bool(st.get("countdown", false)))
			if st.has("amount"):
				# 应付义务（不是钱）：账簿“应付”里看得见，到期才真付
				world.add_liability(str(st.get("pay_to", st.get("who", ""))), fmt(str(st.get("what", st.get("text", "")))), int(fmt(str(st["amount"]))), int(st.get("due_day", -1)))
		"summary":
			await day_summary(fmt(str(st.get("title", "账目"))))
		"ledger":
			await _wait({"type": "ledger"})
		"night":
			await night_menu(int(st.get("night", 1)), int(st.get("max_actions", 99)))
		"telegraph":
			await telegraph(st)
		"chess":
			await chess()
		"door_flag":
			await door_flag_choice(st.get("options", ["none", "blue"]))
		"ending":
			var tk := {"no": str(st.get("no", "德字第一九六号")), "date": str(st.get("date", "民国二十七年 正月十九")), "borrower": "", "hand": "爸的笔迹"}
			# 这张当票不在本铺这两天的账上：记作“外来当票”，不涉及一个蚨
			var ticket_recorded := false
			if _is_town():
				for existing in world.ledger.foreign_tickets:
					if existing.get("no", "") == tk["no"]: ticket_recorded = true
			if not ticket_recorded:
				world.ledger.foreign_tickets.append(tk)
			if _is_town():
				world.flags["ticket196"] = true
			world.emit_signal("changed")
			await _wait({"type": "ending", "ticket": tk})
		"repay":
			# 欠债的人用自己的钱还：能力（手头的钱）与意愿分开；账本只转移，不造钱
			var paid := 0
			var debtor := str(st.get("debtor", ""))
			for did in world.ledger.debts:
				var dd: Dictionary = world.ledger.debts[did]
				if dd["debtor"] == debtor and dd["creditor"] == "player" and dd["status"] != "settled" and dd["kind"] != "recourse":
					paid += world.ledger.pay_debt(did, int(st.get("amount", 0)) - paid)
					if paid >= int(st.get("amount", 0)):
						break
			vars["repaid"] = paid
			if session != null:
				session.vars["repaid"] = paid
			if paid > 0:
				world.note("借条", "%s还了 %d 蚨（%s）" % [db.npc_label(debtor), paid, fmt(str(st.get("note", "还债")))], "seen")
			world.emit_signal("changed")
		"give_stock":
			var gid: String = new_item(str(st["def"]), "player", "stock")
			world.ledger.items[gid]["history"].append("%s送的（%s）" % [db.npc_label(str(st.get("from", ""))), fmt(str(st.get("note", "")))])
			world.ledger.items[gid]["cost"] = 0
			world.note("消息", fmt(str(st.get("note", "收到一件东西"))), "seen", str(st.get("from", "")))
		"sfx":
			_show({"type": "sfx", "name": str(st.get("name", ""))})
		"reprice":
			if session != null:
				session.reprice(int(st.get("ask", session.ask)), int(st.get("floor", session.floor_v)), int(st.get("suggest", -1)))
		"end":
			if session != null:
				session.closed = true
				session.result = str(st.get("result", "end"))
				session.vars["result"] = session.result
				_halt = true
		"set_judged":
			if session != null:
				var j: String = session.iid_of(str(st["def"]))
				if j != "":
					session.set_judged(j, str(st.get("value", "fake")))
		"select":
			if session != null:
				var j2: String = session.iid_of(str(st["def"]))
				if j2 != "":
					session.set_selected(j2, bool(st.get("on", true)))
		_:
			push_error("未知剧情操作 op=%s（%s）" % [op, current_script])

# ---------------- 基本表现 ----------------
func say(who: String, text: String) -> void:
	if who == "narr":
		await narr(text)
		return
	if who != "you" and db.cast.has(who):
		world.notebook.append({"day": world.day, "slot": world.slot, "kind": "对话", "source": "heard", "via": who, "conf": 1.0, "text": "%s：%s" % [db.npc_label(who), text]})
	var expr := ""
	if world.npcs.has(who) and who == customer:
		expr = world.mind.expression(world.npcs[who])
		# 同一个神色不连着说两遍（R2：重复的“（笑了笑）”）
		if expr != "" and _last_expr.get(who, "") == expr:
			expr = ""
		else:
			_last_expr[who] = expr
	await _wait({"type": "say", "who": who, "name": db.npc_label(who), "text": text, "expr": expr})

func narr(text: String) -> void:
	await _wait({"type": "narr", "text": text})

func _choice(st: Dictionary) -> void:
	var opts: Array = []
	for o in st.get("options", []):
		if o.has("when") and not ctx.test(str(o["when"])):
			continue
		opts.append(o)
	if opts.is_empty():
		return
	var shown: Array = []
	for o in opts:
		shown.append({"id": str(o["id"]), "label": fmt(str(o.get("label", o["id"])))})
	var who := str(st.get("who", "you"))
	var r = await _wait({"type": "choice", "who": who, "name": db.npc_label(who), "text": fmt(str(st.get("text", ""))), "options": shown})
	var id := str(r.get("id", shown[0]["id"]))
	var picked: Dictionary = opts[0]
	for o in opts:
		if str(o["id"]) == id:
			picked = o
	if st.has("store"):
		world.flags[str(st["store"])] = str(picked["id"])
	await exec(picked.get("steps", []))

func enter(who: String) -> void:
	_last_expr.erase(who)
	if customer != "" and world.npcs.has(customer):
		world.npcs[customer]["at_counter"] = false
	customer = who
	if world.npcs.has(who):
		world.npcs[who]["at_counter"] = true
		world.mind.relate(world.npcs[who], "player", {"familiarity": 0.05})
	_scene()

func leave() -> void:
	if customer != "" and world.npcs.has(customer):
		world.npcs[customer]["at_counter"] = false
	customer = ""
	_scene()

func new_item(def_id: String, owner: String, location: String) -> String:
	var d: Dictionary = db.items.get(def_id, {}).duplicate(true)
	if d.is_empty():
		push_error("未知物品：" + def_id)
		d = {"name": def_id, "cat": "scrap", "market": 0, "parts": []}
	d["def_id"] = def_id
	var iid: String = world.ledger.add_item(d, owner, location)
	world.emit_signal("changed")
	return iid

func _find_movable(def_id: String) -> String:
	if session != null:
		var s: String = session.iid_of(def_id)
		if s != "":
			return s
	for loc in ["counter", "stock", "pawnbox", "trash", "drawer", ""]:
		var f: String = world.ledger.find_item(def_id, loc)
		if f != "":
			return f
	return ""

func advance_to(slot_name: String, target_day: int = -1) -> void:
	if _is_town():
		return # TownGame alone owns the clock; reused story slots are stage directions.
	var idx: int = World.SLOTS.find(slot_name)
	if idx < 0:
		push_error("未知时段：" + slot_name)
		return
	if target_day < 0:
		target_day = world.day if idx > world.slot else world.day + 1
	var guard := 0
	while (world.day < target_day or (world.day == target_day and world.slot < idx)) and guard < 60:
		guard += 1
		var seen: Array = world.advance_slot()
		if world.slot == 0:
			world.day_journal_start = world.ledger.journal.size()
			_deliver_orders()
			if world.flags.get("trash_rummaged", false):
				world.flags["trash_rummaged"] = false
				world.note("街景", "一早发现后门的垃圾箱被人翻过，昨晚没烧的那几张纸不见了。", "seen")
				await narr("一早开后门，垃圾箱翻倒在地上。昨晚没烧的那几张纸，不见了。")
		_scene()
		for s in seen:
			await narr("门外：" + s)
		while not world.news.is_empty():
			var n: Dictionary = world.news.pop_front()
			await narr("（听%s说）%s" % [n["via"], n["text"]])

func _deliver_orders() -> void:
	var keep: Array = []
	for o in world.flags.get("_orders", []):
		if int(o["day"]) <= world.day:
			var oid: String = new_item(str(o["def"]), "player", "stock")
			world.ledger.items[oid]["cost"] = int(o.get("cost", 0))
			world.note("消息", "一早，%s送来了昨晚订的%s。" % [o["from"], db.items.get(o["def"], {}).get("name", o["def"])], "seen")
		else:
			keep.append(o)
	world.flags["_orders"] = keep

# ---------------- 练习（序章、第二天清晨） ----------------
func _practice(st: Dictionary) -> void:
	var kind := str(st.get("kind", "inspect"))
	match kind:
		"inspect":
			var iid: String = world.ledger.find_item(str(st.get("item", "")), "counter")
			if iid == "":
				iid = new_item(str(st.get("item", "coin")), "player", "counter")
			var s = Session.new()
			s.world = world
			s.mode = "practice"
			s._add(iid)
			_show({"type": "scene", "bg": bg, "customer": customer, "brother": brother, "lamp": lamp})
			await _wait({"type": "practice", "kind": "inspect", "session": s})
		"abacus":
			var r = await _wait({"type": "practice", "kind": "abacus"})
			vars["abacus_practice"] = int(r.get("value", 0))
		"ticket":
			var iid2: String = world.ledger.find_item(str(st.get("item", "handwarmer")), "counter")
			if iid2 == "":
				iid2 = new_item(str(st.get("item", "handwarmer")), "brother", "counter")
			var it: Dictionary = world.ledger.items[iid2]
			var s2 = Session.new()
			s2.world = world
			s2.mode = "practice"
			s2._add(iid2)
			await _wait({"type": "practice", "kind": "inspect", "session": s2})
			var draft := _ticket_draft(iid2, "练习（哥哥）", 0, true)
			var r2 = await _wait({"type": "ticket", "practice": true, "draft": draft})
			vars["practice_condition"] = str(r2.get("condition", "true"))
			await _wait({"type": "stow", "iids": [iid2], "practice": true})
			world.ledger.move_item(iid2, "drawer", "", "练习完收回抽屉")

func _ticket_draft(iid: String, borrower_name: String, principal: int, practice: bool) -> Dictionary:
	var it: Dictionary = world.ledger.items[iid]
	var no: String = "德字第%s号" % world.ledger._cn_num(world.ledger.next_ticket) if not practice else "德字第〇号（练习）"
	return {"no": no, "date": world.date_text(), "borrower": borrower_name, "item": it["name"],
		"weight": it.get("weight", "") if it.get("weighed", false) else "",
		"condition_options": [{"id": "true", "text": _true_condition(iid)}, {"id": "old", "text": "破旧"}],
		"principal": principal, "rate": "月息三分", "term": "三十天", "due": world.date_text(world.day + 30), "due_day": world.day + 30}

# 当票“成色”如实写：只能写你亲眼看出来的（没细看就只能写个大概）
func _true_condition(iid: String) -> String:
	var it: Dictionary = world.ledger.items[iid]
	var seen := 0
	for p in it.get("parts", []):
		if str(p.get("_shown", "")) != "":
			seen += 1
	if seen == 0:
		return "%s（未细看）" % it["name"]
	if seen >= 2 or it.get("parts", []).size() <= 1:
		return str(it.get("ticket_condition", it["name"]))
	return "%s（只看了一处）" % str(it.get("ticket_condition", it["name"]))

# ---------------- 柜台会话 ----------------
func run_session(spec) -> void:
	var id := str(spec.get("id", "town_runtime")) if typeof(spec) == TYPE_DICTIONARY else str(spec)
	if typeof(spec) != TYPE_DICTIONARY and not db.sessions.has(id):
		push_error("缺少顾客会话：" + id)
		return
	var d: Dictionary = spec.duplicate(true) if typeof(spec) == TYPE_DICTIONARY else db.sessions[id]
	if _is_town():
		d = d.duplicate(true)
		d["show_floor"] = false
	var runtime_previous: Dictionary = _install_runtime_session(d)
	var prev := current_script
	current_script = id
	await exec(d.get("pre", []))
	var s = Session.new()
	s.setup(world, d)
	session = s
	ctx.session = s
	enter(s.npc_id)
	await exec(d.get("intro", []))
	_halt = false
	while not s.closed and not stopped:
		var extras: Array = []
		for e in d.get("extras", []):
			if e.get("once", true) and s.used_extras.has(e["id"]):
				continue
			if e.has("when") and not ctx.test(str(e["when"])):
				continue
			extras.append({"id": e["id"], "label": fmt(str(e.get("label", e["id"])))})
		var deals: Array = []
		for dl in d.get("deals", []):
			if dl.has("when") and not ctx.test(str(dl["when"])):
				continue
			deals.append({"id": dl["id"], "label": fmt(str(dl.get("label", dl["id"])))})
		var r = await _wait({"type": "counter", "session": s, "extras": extras, "deals": deals})
		var action := str(r.get("action", ""))
		match action:
			"event":
				while not s.pending_events.is_empty() and not s.closed:
					var ev: String = s.pending_events.pop_front()
					await exec(d.get("on_inspect", {}).get(ev, []))
			"offer":
				await _offer(s, d, int(r.get("value", 0)))
			"extra":
				var eid := str(r.get("id", ""))
				for e in d.get("extras", []):
					if str(e["id"]) == eid:
						s.used_extras[eid] = true
						await exec(e.get("steps", []))
			"deal":
				var did := str(r.get("id", ""))
				for dl in d.get("deals", []):
					if str(dl["id"]) == did:
						s.closed = true
						s.result = "deal:" + did
						await exec(dl.get("steps", []))
			"refuse":
				s.closed = true
				s.result = "refused"
				await say("you", str(d.get("labels", {}).get("refuse_line", "（这笔不做了。）" if s.mode != "sell" else "（不卖了。）")))      # [shop-only] labels 可换字眼
				await exec(d.get("on_leave", []))
			_:
				push_error("未知柜台动作：" + action)
				s.closed = true
		_halt = false
	_halt = false
	await exec(d.get("outro", []))
	_halt = false
	# 客人临走会不会把听来的事告诉你，由他自己的大脑决定（GameJev P05 / I02）
	if not d.get("no_gossip", false) and world.npcs.has(s.npc_id):
		for t in world.share_rumors(s.npc_id):
			await say(s.npc_id, "对了，听人说……" + (str(t.get("text", "")) if t is Dictionary else str(t)))
	# 没成交留在柜台上的东西，客人带走
	for iid in s.item_ids:
		var it: Dictionary = world.ledger.items[iid]
		if it["location"] == "counter":
			world.ledger.move_item(iid, "npc:" + s.npc_id, s.npc_id, "带回去了")
	for iid in world.ledger.items_at("counter"):
		var it2: Dictionary = world.ledger.items[iid]
		if it2["owner"] == s.npc_id:
			world.ledger.move_item(iid, "npc:" + s.npc_id, s.npc_id, "带回去了")
	leave()
	vars["result"] = s.result
	vars["session_outcome"] = {"result": s.result, "price": s.price, "npc": s.npc_id, "mode": s.mode, "items": s.selected_ids().duplicate()}
	session = null
	ctx.session = null
	await exec(d.get("post", []))
	current_script = prev
	_restore_runtime_session(runtime_previous)
	world.emit_signal("changed")
	while not queued_sessions.is_empty():
		await run_session(queued_sessions.pop_front())

func _offer(s, d: Dictionary, v: int) -> void:
	if v <= 0:
		return
	if s.needs_more_inspection():
		await say("brother" if brother else "you", "先别急着谈价。东西还没看清楚——多看几处。")
		return
	if s.mode != "sell" and v > world.cash():
		await say("you", "（钱匣里只有 %d 蚨，出不起这个价。）" % world.cash())
		return
	if s.mode == "sell" and not s.any_selected() and not d.has("_town_levy") and not d.has("_town_protect"):
		await say("you", "（先挑出要卖的东西。）")
		return
	if s.mode != "sell" and not s.any_selected() and not d.has("_town_levy") and not d.has("_town_protect"):      # [shop-only]
		await say("you", "（先选好要收哪几样。）")
		return
	await say("you", ("%d 蚨。" % v) if s.mode != "sell" else (("这件，%d 蚨。" if s.selected_ids().size() == 1 else "这些，%d 蚨。") % v))
	var res: Dictionary = s.offer(v)
	await say(s.npc_id, res["text"])
	match res["result"]:
		"accept":
			await _accept(s, d)
		"leave":
			s.closed = true
			s.result = "leave"
			await exec(d.get("on_leave", []))

func _accept(s, d: Dictionary) -> void:
	if d.has("_town_protect"):          # [shop-only] 保护费讲价成交：按讲下的数付
		var pay_result: Dictionary = protect().haggle_settle(s.price)
		vars["town_result"] = pay_result
		vars["town_ok"] = bool(pay_result.get("ok", false))
		s.closed = true
		s.result = "accept" if vars["town_ok"] else "refused"
		return
	if d.has("_town_levy"):
		var levy_result: Dictionary = _settle_levy(str(d["_town_levy"]), s.price)
		vars["town_result"] = levy_result
		vars["town_ok"] = bool(levy_result.get("ok", false))
		s.closed = true
		s.result = "accept" if vars["town_ok"] else "refused"
		return
	var iids: Array = s.selected_ids()
	var npc_name: String = db.npc_label(s.npc_id)
	match s.mode:
		"buy":
			if world.ledger.transfer("player", s.npc_id, s.price, "收购：%s（%s）" % [_names(iids), npc_name], "", "buy|%s|%d" % [s.npc_id, world.ledger.journal.size()]) == "":
				await say("you", "（钱匣里的钱不够。）")
				return
			for iid in iids:
				world.ledger.move_item(iid, "stock", "player", "%s以买断卖给德厚当（%d 蚨）" % [npc_name, s.price])
				world.ledger.items[iid]["cost"] = int(round(float(s.price) / max(1, iids.size())))
		"pawn":
			var r = await _wait({"type": "ticket", "practice": false, "draft": _ticket_draft(iids[0], npc_name, s.price, false)})
			var old: bool = str(r.get("condition", "true")) == "old"
			var it: Dictionary = world.ledger.items[iids[0]]
			var cond: String = "破旧" if old else str(it.get("ticket_condition", it["name"]))
			var tid: String = world.ledger.open_pawn(s.npc_id, iids, s.price, world.day, 30, cond, old)
			if tid == "":
				await say("you", "（钱匣里的钱不够。）")
				return
			if it.get("fake", false):
				# 收下的是伪契：合同照记（钱是真付出去了），但标明当物不值钱——当户不会来赎，满当也卖不掉
				world.ledger.contracts[tid]["fake_collateral"] = true
				world.add_risk("fake_collateral", tid, "%s 押的是伪契：%d 蚨多半收不回来" % [tid, s.price])
			world.flags["ticket_old_last"] = old
			if old:
				world.flags["ticket_old_any"] = true
			vars["ticket_no"] = tid
			if old:
				world.add("benxin", -2, "当票成色写“破旧”")
				it["market_bonus"] = 0.15
				# 待发的风险：当户来赎时会发现当票写了“破旧”（口碑 -3），记在合同上，赎当时结算
				world.add_risk("ticket_old", tid, "%s 来赎 %s 时会发现当票成色写成了“破旧”（口碑 -3）" % [npc_name, tid])
			world.note("借条", "%s：%s 当 %s，当本 %d 蚨，到期 %s。成色：%s" % [tid, npc_name, it["name"], s.price, world.date_text(world.day + 30), cond], "seen")
		"sell":
			# 小镇：成交前再看一眼，要卖的还是自己的、没押给人的架上货（谈的时候不会变，防的是别处动过账）
			for iid in iids:
				var sale: Dictionary = world.ledger.items[iid]
				if _is_town() and (sale["location"] != "stock" or str(sale.get("owner", "")) != "player" or str(sale.get("pledged_to", "")) != ""):
					await say(s.npc_id, Walkin.line("gone_at_accept"))
					s.closed = true
					s.result = "nostock"
					await exec(d.get("on_leave", []))
					return
			if world.ledger.transfer(s.npc_id, "player", s.price, "卖出：%s（%s）" % [_names(iids), npc_name], "", "sell|%s|%d" % [s.npc_id, world.ledger.journal.size()]) == "":
				await say(s.npc_id, "（摸了摸口袋）……钱不够。算了。")
				s.closed = true
				s.result = "leave"
				await exec(d.get("on_leave", []))
				return
			for iid in iids:
				world.ledger.move_item(iid, "npc:" + s.npc_id, s.npc_id, "德厚当卖给%s" % npc_name)
			if _is_town():
				world.note("账目", "%s卖给%s，%d蚨。" % [_names(iids), npc_name, s.price], "seen")
	s.closed = true
	s.result = "accept"
	_show({"type": "sfx", "name": "coins"})
	await exec(d.get("on_accept", []))
	_halt = false
	if s.mode == "buy":
		var still: Array = []
		for iid in iids:
			if world.ledger.items[iid]["location"] == "stock":
				still.append(iid)
		if not still.is_empty():
			var r2 = await _wait({"type": "stow", "iids": still})
			if str(r2.get("to", "pawnbox")) == "trash":
				for iid in still:
					world.ledger.move_item(iid, "trash", "player", "扔进垃圾箱")
	elif s.mode == "pawn":
		await _wait({"type": "stow", "iids": iids, "pawn": true})
	world.emit_signal("changed")

func _names(iids: Array) -> String:
	var n: Array = []
	for iid in iids:
		n.append(world.ledger.items[iid]["name"])
	return "、".join(n)

# ---------------- 日结 ----------------
func day_summary(title: String) -> void:
	var f: Dictionary = world.ledger.day_flows(world.day_journal_start)
	var stock: Array = []
	for iid in world.ledger.items_at("stock"):
		var it: Dictionary = world.ledger.items[iid]
		if it.get("contraband", false) and int(it.get("market", 0)) == 0:
			stock.append("%s（禁报，没有标价）" % it["name"])
		elif shop_only():      # [shop-only] 不写市价（买来的假货在这里不露底），写自己账上的数：当初收价 / 满当的当本 / 店里旧存
			stock.append("%s（%s）" % [it["name"], walkin().record_of(iid)])
		else:
			stock.append("%s（市价约 %d 蚨）" % [it["name"], world.market_now(it)])
	for iid in world.ledger.items_at("pawnbox"):
		var it2: Dictionary = world.ledger.items[iid]
		stock.append("%s（活当，%s）" % [it2["name"], it2.get("pledged_to", "")])
	var debts: Array = []
	for did in world.ledger.debts:
		var dd: Dictionary = world.ledger.debts[did]
		if dd["status"] != "settled" and dd["kind"] != "recourse":
			debts.append("%s 欠 %s %d 蚨（%s）" % [db.npc_label(dd["debtor"]) if dd["debtor"] != "player" else "你", db.npc_label(dd["creditor"]) if dd["creditor"] != "player" else "你", dd["outstanding"], dd["note"]])
	for tid in world.ledger.contracts:
		var c: Dictionary = world.ledger.contracts[tid]
		if c["status"] in ["active", "overdue"]:
			debts.append("%s：%s 当本 %d 蚨，到期 %s（还有 %d 天）" % [tid, db.npc_label(c["borrower"]), c["principal"], world.date_text(int(c["due_day"])), int(c["due_day"]) - world.day])
	for l in world.liabilities:
		if l["status"] == "未付":
			debts.append("应付：%s %d 蚨（期限 %s）" % [l["what"], int(l["amount"]), world.date_text(int(l["due_day"])) if int(l["due_day"]) >= 0 else "—"])
	for rk in world.risks:
		if rk["status"] == "未发":
			debts.append("隐患：" + str(rk["text"]))
	_show({"type": "sfx", "name": "coins"})
	await _wait({"type": "summary", "title": title, "income": f["income"], "expense": f["expense"], "balance": world.cash(),
		"rows": f["rows"], "stock": stock, "debts": debts})

# ---------------- 夜晚 ----------------
func night_menu(night: int, max_actions: int = 99) -> void:
	night_no = night
	lamps = int(db.night.get("lamps", 3))
	if _is_town():
		var oil_cost := maxi(1, int(_town_config("household").get("oil_night", 1)))
		lamps = mini(lamps, int(_town_state()["household"]["oil"]) / oil_cost)
	var used := 0
	while lamps > 0 and used < max_actions and not stopped:
		var acts: Array = []
		for a in db.night.get("actions", []):
			var nights: Array = a.get("nights", [1, 2])
			if not nights.has(night) and not nights.has(float(night)):
				continue
			var en := _night_enabled(str(a["id"]))
			if _is_town() and str(a["id"]) == "order":
				continue
			if shop_only() and str(a["id"]) == "nightsell":      # [shop-only] 架上的货只等买主进门在柜台上谈，夜里不往后门卖
				continue
			if str(a["id"]) == "diary" and world.benxin >= 40:
				continue
			if str(a["id"]) == "tell_sun" and (not str(world.flags.get("sun_young", "")) in ["exposed", "declined", "bluffed", "scammed"] or world.flags.get("sun_told_father", false)):
				continue
			var desc := str(a.get("desc", ""))
			if shop_only() and ShopOnly.night_desc(str(a["id"])) != "":
				desc = ShopOnly.night_desc(str(a["id"]))      # [shop-only] 整理库房不写“价值 +5%”
			acts.append({"id": a["id"], "label": a.get("label", a["id"]), "star": a.get("star", false), "cost": int(a.get("cost", 1)), "desc": desc, "enabled": en})
		var r = await _wait({"type": "night", "night": night, "lamps": lamps, "max_lamps": int(db.night.get("lamps", 3)), "actions": acts, "used": used, "max_actions": max_actions})
		var id := str(r.get("id", "sleep"))
		var cost := 0
		for a in acts:
			if a["id"] == id:
				cost = int(a["cost"])
				if not a["enabled"]:
					id = "_disabled"
		if id == "sleep":
			break
		_action_ok = true
		match id:
			"ledger":
				await day_summary("今夜对账")
			"tidy":
				await _night_tidy()
			"burn":
				await call_hook("burn_trash", {})
			"nightsell":
				await _night_sell()
			"order":
				await _night_order()
			"flag":
				await door_flag_choice(_flag_options())
				await _sign_choice()
			"telegraph":
				await _free_telegraph()
			"tell_sun":
				world.flags["sun_told_father"] = true
				world.add("faction:孙府", 5, "告诉孙老爷伪契的事")
				world.favor("sunlaoye", 5)
				world.favor("sunyoung", -20)
				world.ledger.transfer("player", "市场", mini(5, world.cash()), "托跑腿捎口信")
				world.plant_rumor("sun_fake_deed", "sunlaoye")
				await narr("你托跑腿的孩子给孙府递了个口信：少爷拿着一张契尾缺失的地契来当过。")
			"diary":
				world.add("benxin", 2, "写日记")
				await narr(_diary_text())
			"_disabled":
				continue
		if not _action_ok:
			continue
		lamps -= cost
		if cost > 0:
			used += 1
			# 一盏灯油的工夫，外面的世界照样在走（传话、巡夜……）
			if _is_town():
				_town_state()["night_actions"] = int(_town_state()["night_actions"]) + cost
			else:
				for line in world.night_tick(night, used):
					await narr("门外：" + line)
	if not _is_town():
		_trash_risk()

func _night_enabled(id: String) -> bool:
	match id:
		"tidy", "nightsell":
			return not world.ledger.items_at("stock").is_empty()
		"burn":
			return not world.ledger.items_at("trash").is_empty()
		"telegraph":
			return world.unlocked.get("telegraph", false)
		"letter":
			return false
	return true

func _pick_stock(text: String) -> String:
	var ids: Array = world.ledger.items_at("stock")
	if ids.is_empty():
		return ""
	var r = await _wait({"type": "pick_item", "text": text, "iids": ids})
	var id := str(r.get("id", ""))
	return id if ids.has(id) else ""

func _night_tidy() -> void:
	var iid: String = await _pick_stock("整理哪一件？" if shop_only() else "整理哪一件？（价值 +5%）")      # [shop-only] 不写数
	if iid == "":
		_action_ok = false
		return
	var it: Dictionary = world.ledger.items[iid]
	if int(it.get("tidy_day", -1)) == world.day:
		await narr("%s今晚已经收拾过了。" % it["name"])
		_action_ok = false
		return
	var before: int = world.market_now(it)
	it["tidy_bonus"] = float(it.get("tidy_bonus", 0.0)) + 0.05
	it["tidy_day"] = world.day
	it["history"].append("夜里整理过")
	var how := {"rice": "摊开晾了晾", "gold": "用软布擦亮", "deed": "压平", "medicine": "擦净瓶身、码齐", "scrap": "理齐、捆好"}
	if shop_only():      # [shop-only] 不报市价：买来的假货在这里不露底
		await narr("你把%s%s。" % [it["name"], how.get(it.get("cat", ""), "收拾干净")])
		return
	await narr("你把%s%s。（市价约 %d → %d 蚨）" % [it["name"], how.get(it.get("cat", ""), "收拾干净"), before, world.market_now(it)])

func _buyer_for(it: Dictionary) -> String:
	match str(it.get("cat", "")):
		"rice": return "米行"
		"medicine": return "济生堂柜"
	return "废品摊"

func _night_sell() -> void:
	if _is_town():
		var town_iid: String = await _pick_stock("挑一件满当货卖给收货人。")
		if town_iid != "":
			var town_sale: Dictionary = town_action("sell", {"iid": town_iid, "channel": "pawnshop", "buyer": _buyer_for(world.ledger.items[town_iid])})
			_action_ok = bool(town_sale.get("ok", false))
		return
	var iid: String = await _pick_stock("卖哪一件给后门的收货人？（市价的七到八成半）")
	if iid == "":
		return
	var it: Dictionary = world.ledger.items[iid]
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%d|nightsell|%d|%s" % [world.world_seed, world.day, iid])
	var rate := rng.randf_range(0.70, 0.85)
	var p := int(round(world.market_now(it) * rate))
	var buyer := _buyer_for(it)
	if p <= 0:
		await narr("后门的收货人翻看了一下%s，摇摇头：“这个不值钱，不收。”" % it["name"])
		return
	var c = await _wait({"type": "choice", "who": "narr", "name": "", "text": "%s的伙计出价 %d 蚨收%s。" % [buyer.replace("柜", ""), p, it["name"]], "options": [{"id": "yes", "label": "卖"}, {"id": "no", "label": "不卖了"}]})
	if str(c.get("id", "no")) != "yes":
		return
	if world.ledger.balance(buyer) < p:
		await narr("后门的伙计摸了摸口袋：“今晚带的钱不够，收不下。”")
		_action_ok = false
		return
	if world.ledger.transfer(buyer, "player", p, "夜卖：%s" % it["name"]) != "":
		world.ledger.move_item(iid, "sold:" + buyer, buyer, "夜里卖给%s（%d 蚨）" % [buyer, p])
		await narr("钱从后门递进来，%s被抱走了。" % it["name"])

func _night_order() -> void:
	var ri: Dictionary = db.items.get("rice_jing_a", {})
	var mi: Dictionary = db.items.get("mercuro", {})
	var opts: Array = [{"id": "rice_jing_a", "label": "向米行订%s（市价八成，约 %d 蚨）" % [ri.get("name", "一袋上白粳米"), int(round(float(ri.get("market", 90)) * world.rice_mod * 0.8))]}]
	var med_ok: bool = world.chen_trust >= 2 or world.flags.get("chen_med_supply", false)
	if med_ok:
		opts.append({"id": "mercuro", "label": "托济生堂代进%s（约 %d 蚨）" % [mi.get("name", "红药水"), int(round(float(mi.get("market", 24)) * world.med_mod * 0.8))]})
	else:
		opts.append({"id": "_med_locked", "label": "托济生堂进药（陈叔叔还不放心）"})
	opts.append({"id": "none", "label": "算了"})
	var r = await _wait({"type": "choice", "who": "narr", "name": "", "text": "订什么货？明天一早送到。", "options": opts})
	var id := str(r.get("id", "none"))
	if id == "none" or id == "_med_locked":
		if id == "_med_locked":
			await narr("药品进货要陈叔叔点头。")
		return
	var it: Dictionary = db.items.get(id, {})
	var p := int(round(float(it.get("market", 0)) * world.price_mod(it) * 0.8))
	var seller := "米行" if id.begins_with("rice") else "济生堂柜"
	if world.ledger.transfer("player", seller, p, "定货：%s" % it.get("name", id)) == "":
		await narr("钱匣里的钱不够。")
		return
	var orders: Array = world.flags.get("_orders", [])
	orders.append({"def": id, "day": world.day + 1, "from": seller.replace("柜", ""), "cost": p})
	world.flags["_orders"] = orders
	world.add_todo(seller.replace("柜", ""), "在途：%s（已付 %d 蚨），明早送到" % [it.get("name", id), p], world.day + 1)
	await narr("你写好单子，压在后门的砖下。明天一早送到。")

func _flag_options() -> Array:
	var out: Array = ["none", "blue"]
	for f in db.factions.get("door_flags", []):
		if world.flags.get("flag_unlocked_" + str(f["id"]), false) and not out.has(f["id"]):
			out.append(f["id"])
	return out

func door_flag_choice(options: Array) -> void:
	var shown: Array = []
	for f in db.factions.get("door_flags", []):
		if options.has(f["id"]):
			shown.append({"id": f["id"], "label": f.get("label", f["id"]), "public": f.get("public", ""), "secret": f.get("secret", "")})
	var r = await _wait({"type": "door_flag", "options": shown, "current": world.door_flag_next, "name": "门旗", "text": "门口挂什么旗？（明天一早生效）"})
	var id := str(r.get("id", "none"))
	world.door_flag_next = id
	if world.day == 0:
		world.door_flag = id
	world.flags["door_flag_next"] = id
	var lbl := id
	for f in shown:
		if f["id"] == id:
			lbl = f["label"]
	world.note("消息", "门旗：明天挂「%s」。" % lbl, "seen")
	world.emit_signal("changed")

func _sign_choice() -> void:
	var opts: Array = []
	for sgn in db.factions.get("signs", []):
		opts.append({"id": sgn["id"], "label": "招牌：“%s”" % sgn["label"]})
	if opts.is_empty():
		return
	opts.append({"id": world.sign_board, "label": "不换"})
	var r = await _wait({"type": "choice", "who": "narr", "name": "", "text": "招牌换成哪一块？（明天生效，影响来的客人）", "options": opts})
	world.sign_board = str(r.get("id", world.sign_board))
	world.emit_signal("changed")

func _free_telegraph() -> void:
	vars["_tg_skipped"] = false
	await _free_telegraph_inner()
	if vars.get("_tg_skipped", false):
		_action_ok = false

func _free_telegraph_inner() -> void:
	await telegraph({"incoming": [], "prompt": "给陈叔叔发报：从电码本里选词组（最多四个），再按发报键。", "allow_skip": true,
		"replies": [
			{"words": ["危险"], "steps": [{"op": "telegraph", "incoming": ["收到", "不要", "来"], "prompt": "陈叔叔回电。", "allow_skip": false}]},
			{"words": ["需要", "药"], "when": "stock_cat('medicine') == 0", "steps": [{"op": "set", "flag": "chen_med_supply", "value": true}, {"op": "telegraph", "incoming": ["明日", "来"], "prompt": "陈叔叔回电。", "allow_skip": false}]},
		],
		"default_steps": [{"op": "telegraph", "incoming": ["收到"], "prompt": "陈叔叔回电。", "allow_skip": false}],
		"skip_steps": [{"op": "var", "name": "_tg_skipped", "value": true}],
		"sent_steps": [{"op": "stat", "stat": "suspicion", "delta": 1, "why": "发电报（无线电会被侦测）"}]})

func _diary_text() -> String:
	var t := "（日记）今天"
	if world.flags.get("li_paper", "") == "reported":
		t += "，那个学生的脸一直在眼前。"
	elif world.flags.get("sold_fake_to_wangshan", false):
		t += "，那盒磺胺不知道会用在谁身上。"
	else:
		t += "，钱匣子一直在响，心里却空落落的。"
	return t

func _trash_risk() -> void:
	for iid in world.ledger.items_at("trash"):
		if world.ledger.items[iid].get("contraband", false):
			var rr := RandomNumberGenerator.new()
			rr.seed = hash("%d|trash|%d|%s" % [world.world_seed, world.day, iid])
			if rr.randf() < 0.35:
				world.ledger.move_item(iid, "lost", "", "垃圾箱被人翻走")
				world.add("suspicion", 2, "垃圾箱里的禁报被人翻走")
				world.flags["trash_rummaged"] = true

# ---------------- 电报 ----------------
func telegraph(st: Dictionary) -> void:
	var incoming: Array = st.get("incoming", [])
	var codes: Array = []
	for w in incoming:
		codes.append(db.code_of(str(w)))
	var r = await _wait({"type": "telegraph", "incoming_codes": codes, "_answer": incoming, "prompt": fmt(str(st.get("prompt", ""))),
		"allow_skip": bool(st.get("allow_skip", incoming.is_empty())), "reply": _wants_reply(st),
		"codebook": db.codebook.get("words", []), "callsign": db.codebook.get("callsign", "")})
	if not incoming.is_empty():
		world.note("消息", "收到电报：" + " / ".join(incoming), "seen", "chen")
	if not _wants_reply(st):
		return
	if r.get("skip", false) or r.get("words", []).is_empty():
		await exec(st.get("skip_steps", []))
		return
	var words: Array = r.get("words", [])
	world.note("消息", "你发报：" + " / ".join(words), "seen")
	world.flags["last_telegram"] = " / ".join(words)
	await exec(st.get("sent_steps", []))
	for rep in st.get("replies", []):
		if rep.has("when") and not ctx.test(str(rep["when"])):
			continue
		if _same_words(rep.get("words", []), words):
			await exec(rep.get("steps", []))
			return
	await exec(st.get("default_steps", []))

static func _wants_reply(st: Dictionary) -> bool:
	return not st.get("replies", []).is_empty() or not st.get("default_steps", []).is_empty() or not st.get("sent_steps", []).is_empty() or not st.get("skip_steps", []).is_empty()

static func _same_words(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for w in a:
		if not b.has(w):
			return false
	return true

# ---------------- 陈叔叔的六枚棋子 ----------------
func chess() -> void:
	var pieces: Array = db.factions.get("factions", [])
	var remaining: Array = []
	for p in pieces:
		remaining.append(p["key"])
	while not remaining.is_empty() and not stopped:
		var r = await _wait({"type": "chess", "pieces": pieces, "remaining": remaining.duplicate()})
		var k := str(r.get("piece", remaining[0]))
		if not remaining.has(k):
			k = remaining[0]
		remaining.erase(k)
		for p in pieces:
			if p["key"] == k:
				await say("chen", "%s（%s）：%s" % [p.get("piece", ""), k, p.get("line", "")])
	world.note("势力", "陈叔叔用六枚棋子讲了镇上各方：城里的兵、维持会、湖上的人、山里的人、孙府、水路上的。", "heard", "chen")

# ---------------- 钩子（§5.2） ----------------
func call_hook(fn: String, args: Dictionary) -> void:
	ensure_vm()
	await script_vm.call_hook(fn, args)

func _legacy_call_hook(fn: String, args: Dictionary) -> void:
	match fn:
		"swap_rice_bag":
			for iid in world.ledger.items_at("stock"):
				var it: Dictionary = world.ledger.items[iid]
				if it.get("tags", []).has("孙记"):
					it["tags"].erase("孙记")
					it["history"].append("拆掉“孙记”袋子，换成德厚当自家的袋子")
			world.flags["rice_bag_swapped"] = true
		"give_item":
			var to := str(args.get("to", ""))
			var iid := ""
			if args.get("pick", false):
				var cands: Array = []
				for i in world.ledger.items_at("stock"):
					if not args.has("cat") or str(world.ledger.items[i].get("cat", "")) == str(args["cat"]):
						cands.append(i)
				if cands.is_empty():
					vars["gave"] = false
					return
				var r = await _wait({"type": "pick_item", "text": str(args.get("reason", "给哪一件？")), "iids": cands})
				iid = str(r.get("id", ""))
				if not cands.has(iid):
					iid = cands[0]
			else:
				iid = world.ledger.find_item(str(args.get("def", "")), "stock")
			if iid == "":
				vars["gave"] = false
				return
			world.ledger.move_item(iid, "npc:" + to, to, "送给%s（%s）" % [db.npc_label(to), str(args.get("reason", ""))])
			vars["gave"] = true
			vars["gave_name"] = world.ledger.items[iid]["name"]
			world.emit_signal("changed")
		"burn_trash":
			var had_tabloid := false
			var n := 0
			for iid in world.ledger.items_at("trash"):
				if world.ledger.items[iid].get("def_id", "") == "tabloid":
					had_tabloid = true
				world.ledger.move_item(iid, "burned", "player", "夜里烧掉")
				n += 1
			if had_tabloid:
				world.flags["tabloid_burned"] = true
				await narr("火光里，纸上的字一个一个卷起来。你看见了县城的名字。")
			elif n > 0:
				await narr("灶膛里的火慢慢灭了。")
			else:
				await narr("垃圾箱是空的。")
		"ma_fee":
			var fee := 120
			if world.flags.get("li_paper", "") == "reported":
				fee = 100
			elif world.flags.get("sun_young", "") == "exposed" and world.flags.get("ma_heard_sun", false):
				fee = 150   # 孙少爷已经告过状（他自己决定去告的）
			vars["fee"] = fee
			vars["fee_cn"] = {100: "一百", 120: "一百二", 150: "一百五"}.get(fee, str(fee))
		"brother_money":
			var opts: Array = [{"id": "0", "label": "（还是算了，钱匣得留着）"}]
			for amt in [50, 100]:
				if world.cash() >= amt:
					opts.append({"id": str(amt), "label": "给哥哥 %d 蚨" % amt})
			var r2 = await _wait({"type": "choice", "who": "you", "name": "你", "text": "带多少？", "options": opts})
			var a := int(str(r2.get("id", "0")))
			if a > 0 and world.ledger.transfer("player", "brother", a, "给哥哥路上用") == "":
				a = 0
			world.flags["brother_money"] = a
			if a > 0:
				await say("brother", "……好。我省着用。")
			world.emit_signal("changed")
		"day_close_lines":
			pass
		"share_rumors":
			var who := str(args.get("who", customer))
			if world.npcs.has(who):
				var told: Array = world.share_rumors(who)
				for t in told:
					await say(who, "对了，听人说……%s" % (str(t.get("text", "")) if t is Dictionary else str(t)))
		"sun_real_deed":
			queued_sessions.append("d2_sunyoung_real")
		"set_door_flag":
			var fid := str(args.get("id", "blue"))
			world.door_flag_next = fid
			world.flags["door_flag_next"] = fid
			world.emit_signal("changed")
		_:
			push_error("未实现的钩子：" + fn)

# ---------------- Town runtime (the frontend owns minutes and day transitions) ----------------
func _is_town() -> bool:
	return vars.has("town")

# [shop-only] 只守铺子：本局是不是只在铺子里过（setup_town 时定，随存档走）；保护费见 scripts/core/protection.gd
func shop_only() -> bool:
	return vars.has("town") and bool(vars["town"].get("shop_only", false))

var _protect = null
func protect():
	if _protect == null:
		_protect = Protection.new(self)
	return _protect

# [shop-only] 过路客人与门口吆喝：时刻表、到点进门、吆喝、买主挑货（scripts/core/walkin.gd）
var _walkin = null
func walkin():
	if _walkin == null:
		_walkin = Walkin.new(self)
	return _walkin

# [shop-only] 出门才能付的账（伙食、柴炭、药、人情、维持费、房捐、良民证、修缮）暂免：不扣、不罚。其余（合同周转等）照旧。
func _shop_only_suspend() -> void:
	if not shop_only():
		return
	var note := str(ShopOnly.config().get("suspend_note", "守铺不出门，这笔暂免"))
	for bill in world.town.s["bills"]:
		if str(bill["status"]) in ["due", "overdue"] and ShopOnly.suspended(str(bill.get("cost_id", ""))):
			bill["status"] = "waived"
			bill["source"] = note
			bill["late_effects"] = []
	for l in world.liabilities:
		if str(l.get("status", "")) == "未付":
			l["status"] = "暂缓"
	var todos_keep: Array = []
	for td in world.todos:
		if bool(td.get("countdown", false)) and str(td.get("text", "")).contains("铺租"):
			continue          # “距缴费还有几天”的倒计时：守铺期间不用交
		todos_keep.append(td)
	world.todos = todos_keep

# [shop-only] 保护费：town_action("protect_*")
func _protect_haggle() -> void:
	var spec: Dictionary = protect().haggle_spec()
	vars["protect_result"] = ""
	if spec.is_empty():
		vars["protect_result"] = "backoff"
		return
	await run_session(spec)
	protect().haggle_done(str(vars.get("result", "")))

func _town_state() -> Dictionary:
	return vars.get("town", {})

func _town_config(group: String) -> Dictionary:
	return town_storylets.get("config", {}).get(group, {})

func _load_town_storylets() -> void:
	var path := "res://data/town/storylets.json"
	if FileAccess.file_exists(path):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
		if typeof(parsed) == TYPE_DICTIONARY:
			town_storylets = parsed

func setup_town(seed: int, difficulty: String = "常年", shop_only_on: bool = false) -> void:   # [shop-only] 第三个参数：只守铺子
	setup(seed)
	_load_town_storylets()
	var pack_data = JSON.parse_string(FileAccess.get_file_as_string("res://data/town/town_pack.json"))
	if typeof(pack_data) != TYPE_DICTIONARY:
		push_error("小镇配置无法读取")
		return
	var pack: Dictionary = pack_data.duplicate(true)
	pack["default_difficulty"] = difficulty
	var town_script = load("res://scripts/sim/town_sim.gd")
	if town_script == null:
		return
	var sim = town_script.new()
	world.town = sim
	sim.setup(pack, seed, world)
	db = world.db # TownSim isolates generated content in a per-world database.
	var opening_cash := int(pack.get("initial", {}).get("cash", pack.get("difficulty", {}).get(difficulty, {}).get("initial_cash", world.cash())))
	world.ledger.initial_total += opening_cash - world.cash()
	world.ledger.accounts["player"] = opening_cash
	var home: Dictionary = _town_config("household")
	vars["town"] = {"difficulty": difficulty, "done_cards": {}, "done_visits": {}, "household": {
		"rice": int(home.get("initial_rice", 0)), "fuel": int(home.get("initial_fuel", 0)),
		"oil": int(home.get("initial_oil", 0)), "medicine": int(home.get("initial_medicine", 0)),
		"stamina": int(home.get("stamina_max", 100)), "hunger": 0, "cold": 0, "illness": 0},
		"buyers": {}, "delayed": [], "invitations": {}, "negotiations": {}, "requests": {},
		"generated_defs": {}, "generated_npcs": {}, "day_started": -1, "day_finished": -1, "night_done": -1,
		"night_actions": 0, "ate_out_day": -1, "letters": [], "prologue_done": false, "request_specs": {},
		"shop_only": shop_only_on, "protect": {}}      # [shop-only]
	if shop_only_on:
		world.flags["shop_only"] = true      # [shop-only] 剧情条件里 is('shop_only')
	# These are inherited dead pawns, not a wholesale restocking catalogue.
	for row in town_storylets.get("initial_stock", []):
		var iid: String = new_item(str(row["def"]), "player", "stock")
		world.ledger.items[iid]["history"].append(str(row.get("history", "家里留下的满当货")))
		world.ledger.items[iid]["cost"] = int(row.get("cost", 0))
	for row in town_storylets.get("initial_pawns", []):
		var borrower_id := str(row["borrower"])
		var iid: String = new_item(str(row["def"]), borrower_id, "counter")
		# The advance preceded the opening balance; don't disburse it for a second time.
		var signed := int(row.get("signed_day", 0))
		var due := int(row.get("due_day", 0))
		var tid: String = world.ledger.open_pawn(borrower_id, [iid], 0, signed, due - signed,
			str(row.get("condition", "旧当物")), bool(row.get("ticket_old", false)))
		world.ledger.contracts[tid]["principal"] = int(row.get("principal", 0))
		world.ledger.items[iid]["history"].append(str(row.get("history", "父亲经手的旧活当")))
	world.emit_signal("changed")

func _town_restore_runtime() -> void:
	_load_town_storylets()
	ensure_vm()
	if not _is_town():
		return
	var state := _town_state()
	for key in state.get("generated_defs", {}):
		db.items[key] = state["generated_defs"][key].duplicate(true)
	for key in state.get("generated_npcs", {}):
		db.cast[key] = state["generated_npcs"][key].duplicate(true)

func _install_runtime_session(spec: Dictionary) -> Dictionary:
	var previous := {"items": {}, "npcs": {}}
	var definitions: Dictionary = spec.get("_item_defs", {})
	for key in definitions:
		previous["items"][key] = db.items.get(key, null)
		db.items[key] = definitions[key].duplicate(true)
		if _is_town():
			_town_state()["generated_defs"][key] = definitions[key].duplicate(true)
	var npc_definition: Dictionary = spec.get("_npc_def", {})
	var npc_id := str(spec.get("npc", ""))
	if not npc_definition.is_empty():
		previous["npcs"][npc_id] = db.cast.get(npc_id, null)
		db.cast[npc_id] = npc_definition.duplicate(true)
		if _is_town():
			_town_state()["generated_npcs"][npc_id] = npc_definition.duplicate(true)
		if not world.npcs.has(npc_id):
			world.npcs[npc_id] = {"id": npc_id, "def": npc_definition, "name": npc_definition.get("name", npc_id),
				"label": npc_definition.get("label", npc_id), "persona": World.Mind.make_persona(npc_definition),
				"rel": {"player": World.Mind.fresh_rel()}, "location": "德厚当", "present": true, "knows": {}, "log": []}
		if not world.ledger.accounts.has(npc_id):
			world.ledger.open_account(npc_id, int(npc_definition.get("cash", 0)))
	return previous

func _restore_runtime_session(previous: Dictionary) -> void:
	# In town generated definitions remain registered for later appraisal and saves.
	if _is_town():
		return
	for key in previous.get("items", {}):
		if previous["items"][key] == null:
			db.items.erase(key)
		else:
			db.items[key] = previous["items"][key]
	for key in previous.get("npcs", {}):
		if previous["npcs"][key] == null:
			db.cast.erase(key)
		else:
			db.cast[key] = previous["npcs"][key]

func town_start_day() -> Dictionary:
	if not _is_town():
		return {"ok": false, "error": "town_not_setup"}
	var plan: Dictionary
	if not world.town.s.get("day_ended", true) and int(_town_state().get("day_started", -1)) == world.day:
		plan = world.town._day_plan()
	else:
		plan = world.town.start_day()
	var state := _town_state()
	if int(state.get("day_started", -1)) != world.day:
		state["day_started"] = world.day
		state["night_actions"] = 0
		state["buyers"] = {}
		world.day_journal_start = world.ledger.journal.size()
		_town_delayed()
		_town_sync_invitations()
	_town_import_liabilities()
	_town_cover_household_bills()
	_town_cover_social_bills()
	_shop_only_suspend()                    # [shop-only]
	protect().on_day_start()                # [shop-only]
	walkin().on_day_start()                 # [shop-only] 过路客人：排今天的时刻表（读档续玩不重排）
	plan["bills"] = world.town.bills()
	plan["visits"] = town_visits()
	plan["protect"] = protect().notice()    # [shop-only]
	plan["household"] = state["household"].duplicate(true)
	plan["prologue"] = str(town_storylets.get("prologue", "prologue")) if not state["prologue_done"] else ""
	return plan

func _town_card_available(card: Dictionary, night: bool = false) -> bool:
	if (str(card.get("kind", "visit")) == "night") != night:
		return false
	if world.day < int(card.get("day_min", 0)) or world.day > int(card.get("day_max", card.get("day_min", 0))):
		return false
	if card.get("once", true) and _town_state()["done_cards"].has(str(card["id"])):
		return false
	return not card.has("when") or ctx.test(str(card["when"]))

func town_visits() -> Array:
	if not _is_town():
		return []
	var out: Array = []
	var state := _town_state()
	for visit in world.town.visits_today():
		var visitor := str(visit.get("who", ""))
		if world.npcs.has(visitor) and not world.npcs[visitor].get("present", true): continue
		if str(visit.get("status", "planned")) in ["missed", "completed"]: continue
		if str(visit.get("intent", "")) == "protect" and not protect().visible(): continue      # [shop-only] 哥哥还没交代，不上门
		if not state["done_visits"].has(str(visit["id"])):
			out.append(visit.duplicate(true))
	for card in town_storylets.get("cards", []):
		if shop_only() and ShopOnly.skip_card(str(card.get("id", ""))): continue      # [shop-only] 要出门才能办的剧情卡不触发
		if not _town_card_available(card):
			continue
		var visitor := str(card.get("who", ""))
		if world.npcs.has(visitor) and not world.npcs[visitor].get("present", true): continue
		if int(world.town.s.get("minute", 360)) > int(card.get("end_minute", 1260)):
			continue
		var visit: Dictionary = card.duplicate(true)
		visit["id"] = "story_" + str(card["id"])
		visit["storylet"] = str(card["id"])
		visit["intent"] = str(card.get("intent", "story"))
		visit["patience_min"] = maxi(0, int(card.get("end_minute", 1260)) - int(card.get("minute", 540)))
		if card.has("session") and typeof(card["session"]) == TYPE_STRING:
			visit["session"] = db.sessions.get(str(card["session"]), {}).duplicate(true)
		out.append(visit)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a.get("minute", 540)) != int(b.get("minute", 540)):
			return int(a.get("minute", 540)) < int(b.get("minute", 540))
		return str(a["id"]) < str(b["id"]))
	return out

func run_town_visit(visit: Dictionary) -> Dictionary:
	if not _is_town():
		return {"ok": false, "error": "town_not_setup"}
	var state := _town_state()
	var visit_id := str(visit.get("id", ""))
	if state["done_visits"].has(visit_id):
		return state["done_visits"][visit_id].duplicate(true)
	var card_id := ""
	var minute := int(world.town.s.get("minute", 360))
	var actual: Dictionary = {}
	for planned in world.town.s["visits"]:
		if str(planned["id"]) == visit_id: actual = planned; break
	if not actual.is_empty():
		if str(actual.get("status", "planned")) not in ["planned", "waiting"]:
			return {"ok": false, "error": "visit_unavailable"}
		visit = actual.duplicate(true)
	else:
		var authored: Dictionary = {}
		for card in town_storylets.get("cards", []):
			if "story_" + str(card["id"]) == visit_id: authored = card; break
		if authored.is_empty(): return {"ok": false, "error": "visit_missing"}
		card_id = str(authored["id"])
		actual = authored.duplicate(true)
		actual["id"] = visit_id
		actual["storylet"] = card_id
		actual["intent"] = str(authored.get("intent", "story"))
		actual["patience_min"] = maxi(0, int(authored.get("end_minute", 1260)) - int(authored.get("minute", 540)))
		if authored.has("session") and typeof(authored["session"]) == TYPE_STRING:
			actual["session"] = db.sessions.get(str(authored["session"]), {}).duplicate(true)
		for key in ["storylet", "script", "session", "minute", "end_minute", "day_min", "day_max", "who"]:
			if visit.has(key) != actual.has(key) or (visit.has(key) and visit[key] != actual[key]):
				return {"ok": false, "error": "visit_spec_changed"}
		if world.day < int(authored.get("day_min", 0)) or world.day > int(authored.get("day_max", authored.get("day_min", 0))):
			return {"ok": false, "error": "story_wrong_day"}
		if state["done_cards"].has(card_id): return {"ok": false, "error": "story_already_run"}
		if not _town_card_available(authored): return {"ok": false, "error": "condition_changed"}
		visit = actual.duplicate(true)
	if minute < int(actual.get("minute", 540)):
		return {"ok": false, "error": "visit_not_arrived"}
	var expiry := int(actual.get("end_minute", 1260)) if card_id != "" else int(actual.get("minute", 540)) + int(actual.get("patience_min", 0))
	if minute > expiry:
		if card_id == "": world.town.visit_missed(visit_id)
		return {"ok": false, "error": "visit_window_closed"}
	var visitor := str(actual.get("who", ""))
	if world.npcs.has(visitor) and not world.npcs[visitor].get("present", true):
		return {"ok": false, "error": "visitor_absent"}
	if visit.has("when") and not ctx.test(str(visit["when"])):
		return {"ok": false, "error": "condition_changed"}
	if card_id == "" and visit.get("session", {}) is Dictionary and str(visit.get("session", {}).get("mode", "")) == "sell":
		# 买主要的货不在了（卖了、被胡二拿走了）：过路的改挑一件，挑不到、或自然排的买主要的都没了，就说一句走人
		walkin().before_counter(actual)
		visit["session"] = actual["session"].duplicate(true)
	vars.erase("session_outcome")
	var previous_presence: Dictionary = _town_stage_presence(visit)
	if visit.has("script"):
		await run_script(str(visit["script"]))
	elif str(visit.get("intent", "")) in ["redeem", "renew"] and _town_contract({"borrower": str(visit.get("who", ""))}) != "":
		vars["session_outcome"] = town_action(str(visit["intent"]), {"borrower": str(visit.get("who", ""))})
	elif visit.has("session") and not visit["session"].is_empty():
		await run_session(visit["session"])
	elif str(visit.get("intent", "")) in ["redeem", "renew"]:
		town_action(str(visit["intent"]), {"borrower": str(visit.get("who", ""))})
	else:
		world.town.hear(str(visit.get("who", "")))
	var outcome: Dictionary = vars.get("session_outcome", {"result": "story"}).duplicate(true)
	if outcome.has("ok") and not outcome["ok"]:
		outcome["action_ok"] = false # A failed redemption is still a completed conversation.
	outcome["ok"] = true
	state["done_visits"][visit_id] = outcome
	if card_id != "":
		state["done_cards"][card_id] = world.day
	else:
		world.town.visit_result(visit_id, outcome)
	_town_restore_presence(previous_presence)
	return outcome

func _town_stage_presence(visit: Dictionary) -> Dictionary:
	var previous: Dictionary = {}
	var people: Array = visit.get("companions", []).duplicate()
	people.append(str(visit.get("who", "")))
	for person in people:
		var who := str(person)
		if not world.npcs.has(who) or not world.npcs[who].get("present", true): continue
		previous[who] = {"world": world.npcs[who].get("location", ""), "sim": world.town.s["npc_locations"].get(who, "")}
		world.npcs[who]["location"] = "德厚当"
		world.town.s["npc_locations"][who] = "德厚当"
	return previous

func _town_restore_presence(previous: Dictionary) -> void:
	for who in previous:
		if not world.npcs[who].get("present", true): continue
		world.npcs[who]["location"] = previous[who]["world"]
		world.town.s["npc_locations"][who] = previous[who]["sim"]

func town_night() -> void:
	if not _is_town() or int(_town_state().get("night_done", -1)) == world.day:
		return
	for card in town_storylets.get("cards", []):
		if _town_card_available(card, true):
			await run_script(str(card.get("script", "")))
			_town_state()["done_cards"][str(card["id"])] = world.day
	if world.day >= int(_town_config("story").get("free_night_from", 3)) and not stopped:
		await night_menu(2) # Reuse the unlocked action set after the two authored tutorial nights.
	_town_state()["night_done"] = world.day

func town_finish_day() -> Dictionary:
	if not _is_town():
		return {"ok": false, "error": "town_not_setup"}
	var state := _town_state()
	if int(state.get("day_finished", -1)) == world.day:
		return state.get("last_summary", {}).duplicate(true)
	protect().on_day_end()                  # [shop-only] 今天没接上的收钱人，在这里结
	_town_cover_household_bills()
	_town_cover_social_bills()
	_town_consume_household()
	_town_close_invitations()
	_shop_only_suspend()                    # [shop-only]
	var summary: Dictionary = world.town.end_day()
	state["day_finished"] = world.day
	summary["household"] = state["household"].duplicate(true)
	summary["cash"] = world.cash()
	summary["accounts"] = world.ledger.day_flows(world.day_journal_start)
	summary["ticket196"] = bool(world.flags.get("ticket196", false))
	summary["protect_lines"] = protect().summary_lines()      # [shop-only]
	if shop_only():      # [shop-only] 暂免的账不算“今日应付”
		var due_total := 0
		var paid_total := 0
		for bill in world.town.s["bills"]:
			if int(bill.get("created_day", 0)) == world.day and str(bill["status"]) != "waived":
				due_total += int(bill["amount"])
				paid_total += int(bill.get("paid", 0))
		summary["bill_total"] = due_total
		summary["bill_paid"] = paid_total
	state["last_summary"] = summary.duplicate(true)
	return summary

func _town_step(step: Dictionary) -> void:
	var args: Dictionary = step.get("args", {}).duplicate(true)
	for key in step:
		if key not in ["op", "act", "args", "when"]:
			args[key] = step[key]
	await _town_hook({"act": str(step.get("act", "")), "args": args})

func _town_hook(spec: Dictionary) -> void:
	var act := str(spec.get("act", ""))
	var args: Dictionary = spec.get("args", spec).duplicate(true)
	if act == "protect_haggle":                # [shop-only] 讲价：开一场议价
		await _protect_haggle()
		return
	if act == "negotiate_levy" and not args.has("offer"):
		vars["town_ok"] = false
		vars["town_result"] = {"ok": false, "error": "bill_missing"}
		var bill: Dictionary = _town_find_bill(args)
		if not bill.is_empty():
			var negotiation: Dictionary = _town_levy_spec(bill)
			await run_session(negotiation)
			if vars.get("result", "") != "accept":
				vars["town_ok"] = false
				vars["town_result"] = {"ok": false, "result": vars.get("result", "refused")}
			return
	var outcome: Dictionary = town_action(act, args)
	vars["town_result"] = outcome
	vars["town_ok"] = bool(outcome.get("ok", false))

func town_action(act: String, args: Dictionary = {}) -> Dictionary:
	if not _is_town():
		return {"ok": false, "error": "town_not_setup"}
	var state := _town_state()
	var request := str(args.get("request_id", ""))
	if not state.has("request_specs"): state["request_specs"] = {}
	var semantic_args: Dictionary = args.duplicate(true)
	semantic_args.erase("request_id")
	var request_spec := {"act": act, "args": semantic_args}
	if request != "" and state["requests"].has(request):
		if state["request_specs"].get(request, request_spec) != request_spec:
			return {"ok": false, "error": "request_conflict"}
		return state["requests"][request].duplicate(true)
	var outcome: Dictionary
	match act:
		"shelf", "stock": outcome = {"ok": true, "items": _town_shelf()}
		"sell", "sell_to_shop", "sell_rice", "sell_medicine", "find_buyer", "risk_sell": outcome = _town_sell(act, args)
		"contract_status": outcome = _town_contract_status(args)
		"debt_status": outcome = _town_debt_status(args)
		"redeem": outcome = _town_redeem(args)
		"renew": outcome = _town_renew(args)
		"buy_rice", "buy_fuel", "buy_oil", "buy_medicine", "eat", "meal": outcome = _town_buy_household(act, args)
		"household": outcome = {"ok": true, "household": state["household"].duplicate(true)}
		"invitation", "attend", "gift", "skip": outcome = _town_invitation(act, args)
		"negotiate_levy": outcome = _town_negotiate_levy(args)
		"pay_bills": outcome = _town_pay_bills(args)
		"letters": outcome = _town_letters(args)
		"npc_present": outcome = _town_npc_present(args)
		"protect_begin", "protect_told", "protect_pay", "protect_delay", "protect_refuse", "protect_rule", "protect_haggle": outcome = protect().act(act, args)      # [shop-only]
		"walkin_call": outcome = walkin().call_in(args)      # [shop-only] 门口吆喝：{kind: pawn|buy} → {ok, kind, n, line, minutes} / {ok:false, error, line}（scripts/core/walkin.gd call_in）
		"prologue_done": state["prologue_done"] = true; outcome = {"ok": true}
		_: outcome = world.town.player_act(act, args)
	if request != "" and (outcome.get("ok", false) or int(outcome.get("paid", 0)) > 0):
		state["requests"][request] = outcome.duplicate(true)
		state["request_specs"][request] = request_spec
	vars["town_result"] = outcome
	vars["town_ok"] = bool(outcome.get("ok", false))
	world.emit_signal("changed")
	return outcome

func _town_npc_present(args: Dictionary) -> Dictionary:
	var who := str(args.get("who", ""))
	if not world.npcs.has(who): return {"ok": false, "error": "npc_missing"}
	var present := bool(args.get("present", true))
	world.npcs[who]["present"] = present
	world.npcs[who]["location"] = world.town.npc_location(who) if present else ""
	world.town.s["npc_locations"][who] = world.npcs[who]["location"]
	if not present:
		for visit in world.town.s["visits"]:
			if str(visit.get("who", "")) == who and str(visit.get("status", "planned")) in ["planned", "waiting"]:
				visit["status"] = "absent"
	return {"ok": true, "who": who, "present": present}

func _town_shelf() -> Array:
	var out: Array = []
	var ids: Array = world.ledger.items_at("stock")
	ids.sort()
	for iid in ids:
		var it: Dictionary = world.ledger.items[iid]
		if it.get("owner", "") != "player" or it.get("pledged_to", "") != "":
			continue
		out.append({"iid": iid, "name": it["name"], "category": it.get("cat", "scrap"), "price": world.market_now(it)})
	return out

func _town_sell(act: String, args: Dictionary) -> Dictionary:
	var iid := str(args.get("iid", ""))
	if not world.ledger.items.has(iid):
		return {"ok": false, "error": "item_missing"}
	var it: Dictionary = world.ledger.items[iid]
	var tid := str(it.get("pledged_to", ""))
	var risky := act == "risk_sell" or bool(args.get("risk", false))
	if tid != "":
		if not risky or not world.ledger.contracts.has(tid) or it["location"] != "pawnbox":
			return {"ok": false, "error": "live_pawn_requires_explicit_risk", "contract": tid}
	elif it["location"] != "stock" or it["owner"] != "player":
		return {"ok": false, "error": "not_sale_stock"}
	var channel := str(args.get("channel", "pawnshop"))
	if act == "sell_rice": channel = "ricehall"
	if act == "sell_medicine": channel = "pharmacy"
	if act == "find_buyer": channel = "teahouse"
	var cat := str(it.get("cat", "scrap"))
	if channel not in ["pawnshop", "teahouse", "market", "ricehall", "pharmacy"]:
		return {"ok": false, "error": "unknown_channel"}
	if channel == "ricehall" and cat != "rice":
		return {"ok": false, "error": "rice_only"}
	if channel == "pharmacy" and cat != "medicine":
		return {"ok": false, "error": "medicine_only"}
	if channel != "pawnshop" and world.town.building_state(channel) != "open":
		return {"ok": false, "error": "channel_closed"}
	if channel == "market" and not world.town.notice().get("market_day", false):
		return {"ok": false, "error": "no_market_today"}
	var config := _town_config("trade")
	var buyers: Dictionary = _town_state()["buyers"]
	var limit := int(config.get("buyer_daily_limit", 0))
	if int(buyers.get(channel, 0)) >= limit:
		return {"ok": false, "error": "buyers_finished_today"}
	var buyer := str(args.get("buyer", ""))
	if buyer == "":
		buyer = {"ricehall": "米行", "pharmacy": "济生堂柜", "market": "废品摊", "teahouse": "市场", "pawnshop": "市场"}[channel]
	if not world.ledger.accounts.has(buyer) or buyer == "player":
		return {"ok": false, "error": "buyer_missing"}
	var market: int = world.market_now(it)
	if market <= 0:
		return {"ok": false, "error": "no_public_price"}
	# Public price anchors all buyers; stock and real buyer cash bound every sale.
	var ceiling := int(round(market * float(config.get("max_ratio", 1.0))))
	var price := int(args.get("price", round(market * float(config.get("offer_ratio", 1.0)))))
	if price <= 0 or price > ceiling:
		return {"ok": false, "error": "buyer_declined", "asking_price": price}
	var fee := int(config.get("tea_fee", 0)) if channel == "teahouse" else 0
	if world.ledger.balance(buyer) < price or world.cash() + price < fee:
		return {"ok": false, "error": "cash_short"}
	var jid: String = world.ledger.transfer(buyer, "player", price, "卖出满当货：" + str(it["name"]), tid,
		str(args.get("request_id", "sale|%d|%s" % [world.day, iid])))
	if jid == "":
		return {"ok": false, "error": "payment_failed"}
	if fee > 0:
		world.ledger.transfer("player", "zhouma", fee, "茶馆牵线茶钱", iid)
	world.ledger.move_item(iid, "npc:" + buyer, buyer, "经%s卖出，%d蚨" % [channel, price])
	buyers[channel] = int(buyers.get(channel, 0)) + 1
	if tid != "":
		var contract: Dictionary = world.ledger.contracts[tid]
		contract["unauthorized_disposal"] = true
		contract["restitution_due"] = true
		if not contract.has("disposals"): contract["disposals"] = []
		contract["disposals"].append({"iid": iid, "buyer": buyer, "price": price, "day": world.day})
		world.add("benxin", -int(config.get("risky_conscience", 0)), "提前处置活当")
		world.note("借条", "%s原物提前卖出，返还原物的义务仍在。" % tid, "seen")
	world.note("账目", "%s卖了%d蚨。" % [it["name"], price], "seen")
	return {"ok": true, "iid": iid, "price": price, "fee": fee, "contract": tid, "risky": tid != ""}

func _town_contract(args: Dictionary) -> String:
	var tid := str(args.get("tid", ""))
	if world.ledger.contracts.has(tid): return tid
	var keys: Array = world.ledger.contracts.keys()
	keys.sort()
	for key in keys:
		var c: Dictionary = world.ledger.contracts[key]
		if c["borrower"] == str(args.get("borrower", "")) and (c["status"] in ["active", "overdue"] or bool(c.get("restitution_due", false))):
			return str(key)
	return ""

func _town_contract_status(args: Dictionary) -> Dictionary:
	var tid := _town_contract(args)
	if tid == "":
		var keys: Array = world.ledger.contracts.keys(); keys.sort()
		for key in keys:
			if str(world.ledger.contracts[key]["borrower"]) == str(args.get("borrower", "")): tid = str(key)
	if tid == "": return {"ok": true, "status": "missing", "due_day": -1}
	var contract: Dictionary = world.ledger.contracts[tid]
	return {"ok": true, "contract": tid, "status": "restitution_due" if contract.get("restitution_due", false) else str(contract["status"]),
		"due_day": int(contract["due_day"]), "principal": int(contract["principal"])}

func _town_debt_status(args: Dictionary) -> Dictionary:
	var total := 0
	for debt in world.ledger.debts.values():
		if str(debt["debtor"]) == str(args.get("debtor", "")) and str(debt["creditor"]) == str(args.get("creditor", "player")):
			total += int(debt["outstanding"])
	return {"ok": true, "outstanding": total}

func _town_redeem(args: Dictionary) -> Dictionary:
	var tid := _town_contract(args)
	if tid == "": return {"ok": false, "error": "contract_missing"}
	var c: Dictionary = world.ledger.contracts[tid]
	if c["status"] not in ["active", "overdue"] and not c.get("restitution_due", false):
		return {"ok": false, "error": "contract_closed"}
	var missing: Array = []
	var held_stock: Array = []
	for iid in c["item_ids"]:
		var original: Dictionary = world.ledger.items[iid]
		if original["location"] == "pawnbox": continue
		if original["location"] == "stock" and original["owner"] == "player": held_stock.append(iid)
		else: missing.append(iid)
	var mode := str(args.get("mode", "normal"))
	if not missing.is_empty() and mode not in ["buyback", "compensate"]:
		return {"ok": false, "error": "original_missing", "contract": tid, "choices": ["buyback", "compensate"]}
	var cfg := _town_config("trade")
	if mode == "compensate" and not missing.is_empty():
		var compensation := 0
		for iid in missing:
			compensation += int(round(world.market_now(world.ledger.items[iid]) * float(cfg.get("compensation_ratio", 1.0))))
		if compensation <= 0 or world.cash() < compensation:
			return {"ok": false, "error": "compensation_cash_short", "amount": compensation}
		var jid: String = world.ledger.transfer("player", c["borrower"], compensation, "活当原物损失赔偿", tid, "compensation|" + tid)
		if jid == "": return {"ok": false, "error": "payment_failed"}
		for iid in c["item_ids"]:
			world.ledger.items[iid]["pledged_to"] = ""
			if world.ledger.items[iid]["location"] == "pawnbox" or held_stock.has(iid):
				world.ledger.move_item(iid, "npc:" + str(c["borrower"]), str(c["borrower"]), "原物赔偿时一并返还")
		c["status"] = "compensated"
		c["restitution_due"] = false
		c["compensation"] = compensation
		c["journal"].append(jid)
		world.add("koubei", -int(cfg.get("compensation_reputation", 0)), "活当原物卖掉，赔钱结清")
		world.note("借条", "%s赔偿%d蚨，合同结清。" % [tid, compensation], "seen")
		return {"ok": true, "result": "compensated", "contract": tid, "amount": compensation}
	var due: int = world.ledger.redeem_amount(tid, world.day)
	if world.ledger.balance(c["borrower"]) < due:
		return {"ok": false, "error": "borrower_cash_short", "amount": due}
	var buybacks: Array = []
	var total := 0
	for iid in missing:
		var it: Dictionary = world.ledger.items[iid]
		var owner := str(it["owner"])
		if not world.ledger.accounts.has(owner) or it["location"] != "npc:" + owner:
			return {"ok": false, "error": "original_unavailable", "iid": iid}
		var amount := int(round(world.market_now(it) * float(cfg.get("buyback_ratio", 1.0))))
		total += amount
		buybacks.append({"iid": iid, "owner": owner, "amount": amount})
	if total > world.cash(): return {"ok": false, "error": "buyback_cash_short", "amount": total}
	for row in buybacks:
		var jid: String = world.ledger.transfer("player", row["owner"], int(row["amount"]), "买回活当原物", tid, "buyback|%s|%s" % [tid, row["iid"]])
		if jid == "": return {"ok": false, "error": "buyback_failed"}
		world.ledger.move_item(str(row["iid"]), "pawnbox", str(c["borrower"]), "为赎当买回原物")
		c["journal"].append(jid)
	for iid in held_stock:
		world.ledger.move_item(str(iid), "pawnbox", str(c["borrower"]), "返还仍在铺内的原当物")
		world.ledger.items[iid]["pledged_to"] = tid
	if c.get("restitution_due", false) and c["status"] == "forfeited":
		c["status"] = "overdue"
		for iid in c["item_ids"]: world.ledger.items[iid]["pledged_to"] = tid
	var ok: bool = world.redeem_contract(tid)
	if ok: c["restitution_due"] = false
	if ok and not missing.is_empty():
		world.add("koubei", -int(cfg.get("buyback_reputation", 0)), "活当原物卖后买回")
	return {"ok": ok, "result": "redeemed" if ok else "unpaid", "contract": tid, "amount": due, "buyback": total}

func _town_renew(args: Dictionary) -> Dictionary:
	var tid := _town_contract(args)
	if tid == "": return {"ok": false, "error": "contract_missing"}
	var c: Dictionary = world.ledger.contracts[tid]
	if c["status"] not in ["active", "overdue"]: return {"ok": false, "error": "contract_closed"}
	var cfg := _town_config("renewal")
	var fee := int(args.get("fee", round(int(c["principal"]) * float(cfg.get("fee_ratio", 0.0)))))
	if fee < 0: return {"ok": false, "error": "invalid_fee"}
	var collateral_id := str(args.get("collateral", ""))
	for prior in c["renewals"]:
		if int(prior.get("day", -1)) == world.day and str(prior.get("collateral", "")) == collateral_id:
			return {"ok": true, "contract": tid, "due_day": prior["due_day"], "fee": prior["fee"], "collateral": collateral_id, "replayed": true}
	var collateral: Dictionary = world.ledger.items.get(collateral_id, {})
	if collateral_id != "":
		if collateral.is_empty() or collateral.get("owner", "") != c["borrower"] or collateral.get("pledged_to", "") != "" or collateral.get("location", "") != "npc:" + str(c["borrower"]):
			return {"ok": false, "error": "collateral_not_owned"}
		var credit := int(round(world.market_now(collateral) * float(cfg.get("collateral_ratio", 0.0))))
		if credit < fee: return {"ok": false, "error": "collateral_insufficient"}
	elif fee > world.ledger.balance(c["borrower"]):
		return {"ok": false, "error": "renewal_cash_short", "amount": fee}
	var old_due := int(c["due_day"])
	var new_due := maxi(world.day, old_due) + int(cfg.get("term_days", 0))
	if new_due <= old_due: return {"ok": false, "error": "renewal_terms_missing"}
	var jid := ""
	if collateral_id == "" and fee > 0:
		jid = world.ledger.transfer(c["borrower"], "player", fee, "续当付息", tid, "renew|%s|%d" % [tid, old_due])
		if jid == "": return {"ok": false, "error": "payment_failed"}
	if collateral_id != "":
		collateral["pledged_to"] = tid
		world.ledger.move_item(collateral_id, "pawnbox", "", "续当追加抵押")
		c["item_ids"].append(collateral_id)
	c["renewals"].append({"day": world.day, "old_due": old_due, "due_day": new_due, "fee": fee,
		"collateral": collateral_id, "journal": jid})
	c["due_day"] = new_due
	c["status"] = "active"
	if jid != "": c["journal"].append(jid)
	world.note("借条", "%s续当至%s，%s。" % [tid, world.date_text(new_due), "付息%d蚨" % fee if collateral_id == "" else "追加当物"], "seen")
	return {"ok": true, "contract": tid, "due_day": new_due, "fee": fee, "collateral": collateral_id}

func _town_buy_household(act: String, args: Dictionary) -> Dictionary:
	var home: Dictionary = _town_state()["household"]
	var cfg := _town_config("household")
	var units := int(args.get("units", 1))
	if units <= 0 or units > int(cfg.get("purchase_max", 0)):
		return {"ok": false, "error": "invalid_units"}
	var key := act.trim_prefix("buy_")
	var building := "ricehall"
	var payee := "米行"
	var unit_price := 0
	match key:
		"rice": unit_price = int(round(int(cfg.get("rice_price", 0)) * world.rice_mod))
		"fuel": unit_price = int(cfg.get("fuel_price", 0)); payee = "市场"
		"oil": unit_price = int(cfg.get("oil_price", 0)); payee = "市场"
		"medicine":
			unit_price = int(round(int(cfg.get("medicine_price", 0)) * world.med_mod))
			building = "pharmacy"; payee = "济生堂柜"
		"eat", "meal":
			unit_price = int(round(int(cfg.get("meal_price", 0)) * world.rice_mod))
			building = "teahouse"; payee = "zhouma"; units = 1
		_:
			return {"ok": false, "error": "not_household_supply"}
	if world.town.building_state(building) != "open": return {"ok": false, "error": "shop_closed"}
	if unit_price <= 0: return {"ok": false, "error": "price_missing"}
	var price := units * unit_price
	var jid: String = world.ledger.transfer("player", payee, price, "家用：" + key, "", str(args.get("request_id", "")))
	if jid == "": return {"ok": false, "error": "cash_short", "amount": price}
	if key in ["eat", "meal"]:
		_town_state()["ate_out_day"] = world.day
		home["hunger"] = maxi(0, int(home["hunger"]) - 1)
	else:
		home[key] = int(home.get(key, 0)) + units
	world.note("家用", "买%s花了%d蚨。" % [key, price], "seen")
	return {"ok": true, "amount": price, "units": units, "household": home.duplicate(true)}

func _town_consume_household() -> void:
	var state := _town_state()
	var home: Dictionary = state["household"]
	var cfg := _town_config("household")
	if shop_only():          # [shop-only] 出不了门、买不了东西：米缸柴炭灯油不扣，睡一觉体力回满
		home["stamina"] = int(cfg.get("stamina_max", 100))
		world.flags["player_sick"] = false
		return
	var rice := int(cfg.get("rice_per_day", 0))
	if int(state.get("ate_out_day", -1)) != world.day:
		if int(home["rice"]) >= rice:
			home["rice"] = int(home["rice"]) - rice
			home["hunger"] = maxi(0, int(home["hunger"]) - 1)
		else:
			home["rice"] = 0
			home["hunger"] = int(home["hunger"]) + 1
	var fuel := int(cfg.get("fuel_per_day", 0))
	if world.weather in cfg.get("cold_weather", []): fuel += int(cfg.get("cold_fuel_extra", 0))
	if int(home["fuel"]) >= fuel:
		home["fuel"] = int(home["fuel"]) - fuel
		home["cold"] = maxi(0, int(home["cold"]) - 1)
	else:
		home["fuel"] = 0
		home["cold"] = int(home["cold"]) + 1
	var oil := int(state["night_actions"]) * int(cfg.get("oil_night", 0))
	home["oil"] = maxi(0, int(home["oil"]) - oil)
	var strain := int(home["hunger"]) + int(home["cold"])
	if strain >= int(cfg.get("illness_threshold", 100)):
		home["illness"] = int(home["illness"]) + 1
	if int(home["illness"]) > 0 and int(home["medicine"]) > 0:
		home["medicine"] = int(home["medicine"]) - 1
		home["illness"] = maxi(0, int(home["illness"]) - int(cfg.get("medicine_recovery", 0)))
	var stamina := int(home["stamina"]) + int(cfg.get("rest_stamina", 0))
	stamina -= int(home["hunger"]) * int(cfg.get("hunger_stamina", 0))
	stamina -= int(home["cold"]) * int(cfg.get("cold_stamina", 0))
	stamina -= int(home["illness"]) * int(cfg.get("illness_stamina", 0))
	stamina -= int(state["night_actions"]) * int(cfg.get("late_stamina", 0))
	home["stamina"] = clampi(stamina, 0, int(cfg.get("stamina_max", 100)))
	world.flags["player_sick"] = int(home["illness"]) > 0
	world.note("家用", "米缸还剩%d份米，柴炭%d份，灯油%d份。" % [home["rice"], home["fuel"], home["oil"]], "seen")

func _town_sync_invitations() -> void:
	var invitations: Dictionary = _town_state()["invitations"]
	for source in world.town.s.get("invitations", []):
		var id := str(source["id"])
		if not invitations.has(id):
			var row: Dictionary = source.duplicate(true)
			row["status"] = "pending"
			invitations[id] = row

func _town_invitation(act: String, args: Dictionary) -> Dictionary:
	_town_sync_invitations()
	var invitations: Dictionary = _town_state()["invitations"]
	if act == "invitation" and args.has("id") and args.has("who") and args.has("due_day") and not invitations.has(str(args["id"])):
		var created: Dictionary = args.duplicate(true)
		created["status"] = "pending"
		created["received_day"] = world.day
		created["payee"] = str(args["who"])
		invitations[str(args["id"])] = created
		world.town.s["invitations"].append(created.duplicate(true))
		return {"ok": true, "id": args["id"], "due_day": args["due_day"]}
	if act == "invitation" and not args.has("id"):
		var visible: Array = []
		var keys: Array = invitations.keys(); keys.sort()
		for key in keys:
			var row: Dictionary = invitations[key]
			visible.append({"id": key, "who": row.get("who", "街坊"), "text": row.get("text", "请帖"),
				"due_day": row["due_day"], "status": row["status"]})
		return {"ok": true, "invitations": visible}
	var id := str(args.get("id", ""))
	if id == "" and args.has("who"):
		var keys: Array = invitations.keys(); keys.sort()
		for key in keys:
			if invitations[key].get("who", "") == args["who"] and invitations[key]["status"] == "pending":
				id = str(key); break
	if not invitations.has(id): return {"ok": false, "error": "invitation_missing"}
	var row: Dictionary = invitations[id]
	if row["status"] != "pending": return {"ok": false, "error": "invitation_answered"}
	var response := str(args.get("response", "skip")) if act == "invitation" else act
	if response not in ["attend", "gift", "skip"]: return {"ok": false, "error": "unknown_response"}
	if world.day > int(row["due_day"]): return {"ok": false, "error": "invitation_expired"}
	if response == "attend" and world.day != int(row["due_day"]):
		return {"ok": false, "error": "not_invitation_day"}
	var cfg := _town_config("social")
	var who := str(row.get("who", ""))
	var social_bills: Array = []
	var already_paid := 0
	var expected := int(cfg.get("attend_cost", 0))
	for bill in world.town.s["bills"]:
		if str(bill.get("cost_id", "")) == "social" and (str(bill["id"]) == "bill:social:" + id or str(bill.get("source", "")) == "event:" + id):
			social_bills.append(bill)
			already_paid += int(bill.get("paid", 0))
			expected = maxi(expected, int(bill["amount"]))
	var desired := int(args.get("amount", cfg.get("gift", 0))) if response == "gift" else expected
	var amount := maxi(0, desired - already_paid) if response != "skip" else 0
	var journal := ""
	if response != "skip":
		if desired <= 0 or not world.ledger.accounts.has(who): return {"ok": false, "error": "gift_terms_missing"}
		if amount > 0:
			journal = world.ledger.transfer("player", who, amount, "请帖人情送礼" if response == "gift" else "赴约人情", id, "invitation|" + id)
			if journal == "": return {"ok": false, "error": "cash_short"}
	for bill in social_bills:
		if response == "skip":
			bill["status"] = "waived" if int(bill.get("paid", 0)) == 0 else "paid"
			bill["amount"] = int(bill.get("paid", 0))
		else:
			bill["amount"] = maxi(desired, already_paid)
			bill["paid"] = bill["amount"]
			bill["status"] = "paid"
			bill["source"] = "请帖已" + ("送礼" if response == "gift" else "赴约")
			bill["invitation_journal"] = journal
	for invitation in world.town.s["invitations"]:
		if str(invitation["id"]) == id:
			invitation["status"] = response
			invitation["amount"] = maxi(desired, already_paid) if response != "skip" else already_paid
			invitation["payee"] = who
	if response == "attend":
		var home: Dictionary = _town_state()["household"]
		home["stamina"] = maxi(0, int(home["stamina"]) - int(cfg.get("attend_stamina", 0)))
		home["hunger"] = maxi(0, int(home["hunger"]) - 1)
		_town_state()["ate_out_day"] = world.day
	row["status"] = response
	row["paid_amount"] = already_paid + amount
	row["payment_journal"] = journal
	row["answered_day"] = world.day
	_town_state()["delayed"].append({"id": id, "who": who, "due_day": int(row["due_day"]) + int(cfg.get("delay", 0)), "response": response})
	world.note("人情", "%s的请帖：%s。" % [db.npc_label(who), {"attend": "赴约", "gift": "送礼", "skip": "谢绝"}[response]], "seen")
	return {"ok": true, "id": id, "response": response, "amount": amount}

func _town_close_invitations() -> void:
	_town_sync_invitations()
	var invitations: Dictionary = _town_state()["invitations"]
	var keys: Array = invitations.keys(); keys.sort()
	for key in keys:
		var row: Dictionary = invitations[key]
		if row["status"] == "pending" and int(row["due_day"]) <= world.day:
			_town_invitation("skip", {"id": key})

func _town_delayed() -> void:
	var state := _town_state()
	var keep: Array = []
	var cfg := _town_config("social")
	for row in state["delayed"]:
		if world.day < int(row["due_day"]):
			keep.append(row); continue
		var response := str(row["response"])
		var who := str(row["who"])
		if world.npcs.has(who):
			world.favor(who, int(cfg.get(response + "_favor", 0)))
		var text := str(cfg.get(response + "_text", "街坊捎了个口信。"))
		world.note("人情", text, "heard", who)
	state["delayed"] = keep

func _town_import_liabilities() -> void:
	if shop_only():          # [shop-only] 铺租、维持费要去保公所交：守铺期间不记成账单
		return
	for index in range(world.liabilities.size()):
		var liability: Dictionary = world.liabilities[index]
		if liability.get("status", "") != "未付": continue
		var id := "legacy_bill_%d" % index
		var exists := false
		for bill in world.town.s["bills"]:
			if bill["id"] == id: exists = true; break
		if exists: continue
		var payee := str(liability["to"])
		if not world.ledger.accounts.has(payee):
			payee = "维持会公账" if str(liability["what"]).contains("维持") else "保长"
		if not world.ledger.accounts.has(payee): world.ledger.open_account(payee, 0)
		var cost_id := "levy" if str(liability["what"]).contains("维持") else "rent"
		var specification: Dictionary = {}
		for cost in world.town.pack.get("living_costs", []):
			if str(cost["id"]) == cost_id: specification = cost.duplicate(true); break
		specification.merge({"id": cost_id, "label": liability["what"], "amount": int(liability["amount"]),
			"min": int(liability["amount"]), "max": int(liability["amount"]), "payee": payee,
			"building": "baogong", "due_day": int(liability["due_day"])}, true)
		var row: Dictionary = TownCosts.add(world.town.pack, world.town.s, specification, "当铺账簿", id, world)
		if not row.is_empty(): row["legacy_index"] = index

func _town_cover_household_bills() -> void:
	var home: Dictionary = _town_state()["household"]
	var cfg := _town_config("household")
	for bill in world.town.s["bills"]:
		if int(bill.get("created_day", 0)) != world.day or bill["status"] != "due": continue
		var covered := false
		var cost_id := str(bill.get("cost_id", ""))
		if cost_id == "food":
			covered = int(home["rice"]) >= int(cfg.get("rice_per_day", 0)) or int(_town_state()["ate_out_day"]) == world.day
		elif cost_id == "fuel":
			var fuel := int(cfg.get("fuel_per_day", 0))
			if world.weather in cfg.get("cold_weather", []): fuel += int(cfg.get("cold_fuel_extra", 0))
			covered = int(home["fuel"]) >= fuel
		if covered:
			bill["status"] = "waived"
			bill["source"] = "家里实物支付" # Consumption is recorded in the household book at bedtime.

func _town_cover_social_bills() -> void:
	var invitations: Dictionary = _town_state()["invitations"]
	for bill in world.town.s["bills"]:
		if str(bill.get("cost_id", "")) != "social": continue
		for id in invitations:
			var invitation: Dictionary = invitations[id]
			if invitation["status"] == "pending": continue
			if str(bill["id"]) != "bill:social:" + str(id) and str(bill.get("source", "")) != "event:" + str(id): continue
			var paid := maxi(int(bill.get("paid", 0)), int(invitation.get("paid_amount", 0)))
			bill["amount"] = paid
			bill["paid"] = paid
			bill["status"] = "paid" if paid > 0 else "waived"
			bill["source"] = "请帖已答复"

func _town_find_bill(args: Dictionary) -> Dictionary:
	_town_import_liabilities()
	var id := str(args.get("bill_id", ""))
	for bill in world.town.s["bills"]:
		if id != "" and str(bill["id"]) == id: return bill
		if id == "" and str(bill.get("cost_id", "")) == "levy" and str(bill["status"]) in ["due", "overdue"]:
			return bill
	return {}

func _town_levy_spec(bill: Dictionary) -> Dictionary:
	var cfg := _town_config("levy")
	var amount := maxi(1, int(bill["amount"]) - int(bill.get("paid", 0)))
	return {"id": "town_levy_" + str(bill["id"]), "npc": "ma", "mode": "buy", "items": [],
		"ask": amount, "floor": maxi(1, int(round(amount * float(cfg.get("floor_ratio", 1.0))))),
		"_town_levy": str(bill["id"]), "no_gossip": true, "show_floor": false,
		"intro": [{"op": "say", "who": "ma", "text": "%s，账上记着%d蚨。你说说。" % [bill["label"], amount]}]}

func _town_negotiate_levy(args: Dictionary) -> Dictionary:
	var bill: Dictionary = _town_find_bill(args)
	if bill.is_empty(): return {"ok": false, "error": "bill_missing"}
	if world.town.building_state("baogong") != "open": return {"ok": false, "error": "office_closed"}
	if not args.has("offer"): return {"ok": false, "error": "offer_required"}
	var amount := int(args["offer"])
	if amount <= 0 or amount > world.cash(): return {"ok": false, "error": "cash_short"}
	var id := str(bill["id"])
	var negotiations: Dictionary = _town_state()["negotiations"]
	var saved: Dictionary = negotiations.get(id, {})
	if saved.get("closed", false): return saved.get("outcome", {}).duplicate(true)
	var s = Session.new()
	s.setup(world, _town_levy_spec(bill))
	if not saved.is_empty():
		s.rounds = int(saved.get("rounds", 0)); s.ask = int(saved.get("ask", s.ask))
		# A repeated offer returns its previous reaction, without drawing again.
		if int(saved.get("offer", -1)) == amount: return saved["outcome"].duplicate(true)
	var result: Dictionary = s.offer(amount)
	var outcome := {"ok": true, "result": result["result"], "text": result["text"], "ask": s.ask, "bill_id": id}
	if result["result"] == "accept": outcome = _settle_levy(id, amount)
	negotiations[id] = {"rounds": s.rounds, "ask": s.ask, "offer": amount, "outcome": outcome,
		"closed": result["result"] in ["accept", "leave"]}
	return outcome

func _settle_levy(id: String, amount: int) -> Dictionary:
	var bill: Dictionary = _town_find_bill({"bill_id": id})
	if bill.is_empty() or str(bill["status"]) not in ["due", "overdue"]:
		return {"ok": false, "error": "bill_closed"}
	if amount <= 0 or world.cash() < amount: return {"ok": false, "error": "cash_short"}
	var old := int(bill["amount"])
	bill["amount"] = int(bill.get("paid", 0)) + amount
	var result: Dictionary = world.town.pay_bill(id, amount, "negotiated|" + id)
	if not result.get("ok", false):
		bill["amount"] = old
		return result
	bill["negotiated_from"] = old
	if bill.has("legacy_index"):
		world.liabilities[int(bill["legacy_index"])]["status"] = "已付"
		world.liabilities[int(bill["legacy_index"])]["amount"] = bill["amount"]
	world.note("账目", "%s议定%d蚨，已付清。" % [bill["label"], amount], "seen", "ma")
	result["result"] = "accept"
	return result

func _town_pay_bills(args: Dictionary) -> Dictionary:
	_town_import_liabilities()
	_town_cover_household_bills()
	_town_cover_social_bills()
	var receipts: Array = []
	var total := 0
	var all_paid := true
	for bill in world.town.s["bills"]:
		if args.has("bill_id") and str(bill["id"]) != str(args["bill_id"]): continue
		if args.has("building") and str(bill["building"]) != str(args["building"]): continue
		if args.has("payee") and str(bill["payee"]) != str(args["payee"]): continue
		if str(bill["status"]) not in ["due", "overdue"]: continue
		var amount := maxi(0, int(bill["amount"]) - int(bill.get("paid", 0)))
		if args.has("amount"): amount = mini(amount, int(args["amount"]))
		var receipt: Dictionary = world.town.pay_bill(str(bill["id"]), amount,
			str(args.get("request_id", "pay")) + "|%s|%d" % [bill["id"], int(bill.get("paid", 0))])
		receipts.append(receipt)
		all_paid = all_paid and bool(receipt.get("ok", false)) and int(receipt.get("remaining", 0)) == 0
		total += int(receipt.get("paid", 0))
		if receipt.get("ok", false) and int(receipt.get("remaining", 0)) == 0 and int(bill.get("created_day", 0)) == world.day:
			var home: Dictionary = _town_state()["household"]
			if str(bill.get("cost_id", "")) == "food":
				_town_state()["ate_out_day"] = world.day
				home["hunger"] = maxi(0, int(home["hunger"]) - 1)
			if str(bill.get("cost_id", "")) == "fuel":
				var required := int(_town_config("household").get("fuel_per_day", 0))
				if world.weather in _town_config("household").get("cold_weather", []): required += int(_town_config("household").get("cold_fuel_extra", 0))
				home["fuel"] = maxi(int(home["fuel"]), required)
		if bill.has("legacy_index") and bill["status"] == "paid":
			world.liabilities[int(bill["legacy_index"])]["status"] = "已付"
	return {"ok": all_paid and not receipts.is_empty(), "paid": total, "receipts": receipts}

func _town_letters(args: Dictionary = {}) -> Dictionary:
	var letter_id := str(args.get("id", "brother_first"))
	var earliest := int(_town_config("story").get("first_letter_day", 4))
	if letter_id == "brother_second": earliest = int(_town_config("story").get("second_letter_day", 13))
	if world.day < earliest: return {"ok": false, "error": "no_letter_yet"}
	world.town.s["unlocked"]["post"] = true
	world.flags["post_unlocked"] = true
	var letters: Array = _town_state()["letters"]
	if letters.has(letter_id): return {"ok": true, "letters": [], "already_collected": true}
	letters.append(letter_id)
	return {"ok": true, "letters": [letter_id]}

func to_dict() -> Dictionary:
	return SaveState._encode_state({"vars": vars.duplicate(true), "customer": customer, "brother": brother, "bg": bg, "lamp": lamp,
		"queued_sessions": queued_sessions.duplicate(true), "done": done, "stop_at": stop_at, "stopped": stopped,
		"beats_emitted": beats_emitted, "current_script": current_script, "night_no": night_no, "lamps": lamps,
		"_halt": _halt, "_action_ok": _action_ok, "_last_expr": _last_expr.duplicate(true)})

func from_dict(encoded: Dictionary) -> void:
	if not SaveState._json_safe(encoded): return
	var data: Dictionary = SaveState._decode_state(encoded)
	for key in ["vars", "customer", "brother", "bg", "lamp", "queued_sessions", "done", "stop_at", "stopped", "beats_emitted", "current_script", "night_no", "lamps", "_halt", "_action_ok", "_last_expr"]:
		if data.has(key): set(key, data[key].duplicate(true) if data[key] is Dictionary or data[key] is Array else data[key])
	session = null
	if ctx != null: ctx.session = null
	_town_restore_runtime()
