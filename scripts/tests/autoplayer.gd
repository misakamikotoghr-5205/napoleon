# 自动试玩器：按策略回应导演的每个 beat。用于无界面冒烟测试、界面驱动测试和截图。
# 策略：fair（公道、细心、像个会还价的人）/ greedy（压价、写破旧、卖假药）/ random<N>（种子随机）
#       plan:<名字>（scripts/tests/plans.json 里逐个顾客指定走哪条分支，并在结束时核对标记）
# 若设置了 ui（main.gd），回应会经由界面面板执行（测试界面代码路径），否则直接 submit。
extends RefCounted

signal checkpoint(name)

const PLANS_PATH = "res://scripts/tests/plans.json"

var director
var policy: String = "fair"
var base: String = "fair"
var plan: Dictionary = {}
var choice_queue: Array = []
var rng := RandomNumberGenerator.new()
var errors: Array = []
var log_lines: Array = []
var beat_count: int = 0
var max_beats: int = 6000
var step_delay: float = 0.0
var tree: SceneTree = null
var ui = null
var counts: Dictionary = {}
var sessions_seen: Dictionary = {}
var _sess_state: Dictionary = {}
var town: bool = false           # v0.4 小镇策略（town_fair 等）：基础策略同旧版，几处按小镇主线微调

func _init(p_director, p_policy: String, p_seed: int = 1) -> void:
	director = p_director
	policy = p_policy
	base = p_policy
	if p_policy.begins_with("town_"):
		town = true
		base = p_policy.substr(5)
	if p_policy.begins_with("plan:"):
		var all: Dictionary = load_plans()
		var name := p_policy.substr(5)
		if not all.has(name):
			errors.append("没有这个测试计划：" + name)
		plan = all.get(name, {})
		base = str(plan.get("base", "fair"))
		choice_queue = plan.get("choices", []).duplicate()
	rng.seed = hash(p_policy + str(p_seed))
	director.beat.connect(_on_beat, CONNECT_DEFERRED)

static func load_plans() -> Dictionary:
	if not FileAccess.file_exists(PLANS_PATH):
		return {}
	var j = JSON.parse_string(FileAccess.get_file_as_string(PLANS_PATH))
	return j.get("plans", {}) if typeof(j) == TYPE_DICTIONARY else {}

func _is_random() -> bool:
	return base.begins_with("random")

func _on_beat(b: Dictionary) -> void:
	if b.get("nowait", false):
		return
	beat_count += 1
	counts[b["type"]] = int(counts.get(b["type"], 0)) + 1
	if beat_count > max_beats:
		errors.append("beat 数超过上限 %d（可能死循环）：%s" % [max_beats, str(b.get("type"))])
		director.stopped = true
		director.submit({})
		return
	var errs: Array = director.world.ledger.check_invariants()
	if not errs.is_empty():
		errors.append("beat %d（%s）账本不变量失败：%s" % [beat_count, b["type"], str(errs)])
	if step_delay > 0.0 and tree != null:
		await tree.create_timer(step_delay, false).timeout     # 暂停时（process_always=false）自动试玩也停
	var r: Dictionary = respond(b)
	if ui != null:
		ui.auto_apply(b, r)   # 界面自己负责最后 submit
	else:
		director.submit(r)

func respond(b: Dictionary) -> Dictionary:
	match str(b["type"]):
		"say", "narr", "caption", "summary", "ledger":
			if b["type"] == "summary":
				emit_signal("checkpoint", "summary_%d" % director.world.day)
			return {}
		"ending":
			emit_signal("checkpoint", "ending")
			log_lines.append("到达结尾：德字第一九六号")
			return {}
		"choice":
			return {"id": _choose(b["options"])}
		"tutorial":
			emit_signal("checkpoint", "tutorial_" + str(b["target"]))
			return {"target": b["target"]}
		"practice":
			return _practice(b)
		"counter":
			return _counter(b)
		"ticket":
			emit_signal("checkpoint", "ticket")
			var old := base == "greedy" or (_is_random() and rng.randf() < 0.3)
			if plan.has("ticket"):
				old = str(plan["ticket"]) == "old"
			return {"condition": "old" if old else "true"}
		"stow":
			var to := "pawnbox"
			if plan.has("stow"):
				to = str(plan["stow"])
			elif _is_random() and rng.randf() < 0.15:
				to = "trash"
			# 界面上活当只亮典当盒（垃圾箱不亮，点了也没反应）：经由界面时别去点垃圾箱，否则卡住
			if b.get("practice", false) or (ui != null and b.get("pawn", false)):
				to = "pawnbox"
			return {"to": to}
		"night":
			emit_signal("checkpoint", "night%d" % int(b["night"]))
			return {"id": _night(b)}
		"pick_item":
			var ids: Array = b.get("iids", [])
			return {"id": ids[rng.randi() % ids.size()] if not ids.is_empty() else ""}
		"telegraph":
			emit_signal("checkpoint", "telegraph")
			return _telegraph(b)
		"chess":
			var rem: Array = b["remaining"]
			return {"piece": rem[rng.randi() % rem.size()] if _is_random() else rem[0]}
		"door_flag":
			var opts: Array = b["options"]
			if _is_random():
				return {"id": opts[rng.randi() % opts.size()]["id"]}
			return {"id": "blue" if base == "fair" else opts[0]["id"]}
		_:
			errors.append("未知 beat：" + str(b["type"]))
			return {}

func _choose(opts: Array) -> String:
	if opts.is_empty():
		return ""
	if not choice_queue.is_empty():
		for o in opts:
			if str(o["id"]) == str(choice_queue[0]):
				choice_queue.pop_front()
				return str(o["id"])
	if _is_random():
		return str(opts[rng.randi() % opts.size()]["id"])
	if base == "greedy":
		return str(opts[opts.size() - 1]["id"]) if opts.size() > 1 else str(opts[0]["id"])
	return str(opts[0]["id"])

func _practice(b: Dictionary) -> Dictionary:
	if b["kind"] == "inspect":
		var s = b["session"]
		for iid in s.item_ids:
			for p in _parts_in_order(s, iid):
				if s.can_use_tool(str(p.get("tool", "magnifier"))):
					_look(s, iid, str(p["id"]))
		return {}
	return {"value": 50}

# ---------------- 验货：经由界面时真的拿朱笔圈 ----------------
# 有界面（ui）时打开验货面板，在部位中心画一个真圈（circle_at）；每件墨有限，圈不了就算了。
# 无界面时照旧直接揭开（session.inspect 不看墨）。
func _panel():
	if ui == null:
		return null
	var p = ui.get("inspect")
	return p if p != null and p.has_method("circle_at") else null

func _look(s, iid: String, pid: String) -> bool:
	var panel = _panel()
	if panel == null:
		s.inspect(iid, pid)
		return true
	if s.ink_left(iid) <= 0:
		return false
	if not panel.visible or panel.session != s:
		panel.open(s, iid, false)
	elif panel.iid != iid:
		panel.open(s, iid, panel.practice)
	var r: Rect2 = panel.part_local_rect(pid)
	if r.size == Vector2.ZERO:
		return false
	var part: Dictionary = {}
	for p in s.item(iid).get("parts", []):
		if str(p["id"]) == pid:
			part = p
	var rad := clampf(maxf(r.size.x, r.size.y) / 2.0 * 0.8, 17.5, 110.0)
	var res: Dictionary = panel.circle_at(r.get_center(), rad, str(part.get("tool", "magnifier")))
	if str(res.get("kind", "")) != "hit":
		errors.append("经由界面圈 %s.%s 没圈中：%s" % [s.item(iid).get("def_id", ""), pid, str(res)])
		s.inspect(iid, pid)   # 记下错误，仍然揭开，免得一处界面问题连累整条流程
	return true

# 有界面时墨有限：先圈要紧的（破绽、剧情记号、必看的、能定价的），其余靠后
func _parts_in_order(s, iid: String) -> Array:
	var parts: Array = s.item(iid).get("parts", []).duplicate()
	if _panel() == null:
		return parts
	var req: Array = s.def.get("require", []) if s.def is Dictionary else []
	var def_id := str(s.item(iid).get("def_id", ""))
	var keyed: Array = []
	for i in parts.size():
		var p: Dictionary = parts[i]
		var rank := 3
		if p.get("tell", false):
			rank = 0
		elif str(p.get("flag", "")) != "" or str(p.get("event", "")) != "" or req.has("%s.%s" % [def_id, p["id"]]):
			rank = 1
		elif p.has("est"):
			rank = 2
		keyed.append([rank, i, p])
	keyed.sort_custom(func(x, y): return x[0] < y[0] or (x[0] == y[0] and x[1] < y[1]))
	var out: Array = []
	for k in keyed:
		out.append(k[2])
	return out

# ---------------- 柜台 ----------------
func _sp(s) -> Dictionary:
	return plan.get("sessions", {}).get(str(s.def.get("id", "")), {})

func _wants_inspect(s, iid: String, pid: String, sp: Dictionary) -> bool:
	var ins = sp.get("inspect", "all" if not (base == "greedy" and s.mode == "sell") else "none")
	if typeof(ins) == TYPE_ARRAY:
		return ins.has("%s.%s" % [s.item(iid).get("def_id", ""), pid])
	if str(ins) == "none":
		return false
	if _is_random() and rng.randf() < 0.2 and s.inspected_total() >= s.min_inspect:
		return false
	return true

func _counter(b: Dictionary) -> Dictionary:
	var s = b["session"]
	var sid := str(s.def.get("id", ""))
	var key := sid + "#" + str(s.get_instance_id())
	sessions_seen[sid] = true
	var sp: Dictionary = _sp(s)
	var st: Dictionary = _sess_state.get(key, {"extras_done": [], "offers": 0, "last": 0, "init": false})
	_sess_state[key] = st
	emit_signal("checkpoint", "counter_" + sid)
	if not s.pending_events.is_empty():
		return {"action": "event"}
	# “拒绝者”策略：每一笔都不做——验证任何柜台都能体面地走出去（v0.2 防卡死）
	if base == "refuser":
		return {"action": "refuse"}
	# 1. 验货：一次揭一个部位（事件要及时处理）；看了新东西后要一个新的 beat（新解锁的附加动作才会出现）
	var looked := false
	for iid in s.item_ids:
		for p in _parts_in_order(s, iid):
			if not s.inspected[iid].has(p["id"]) and s.can_use_tool(str(p.get("tool", "magnifier"))) and _wants_inspect(s, iid, p["id"], sp):
				if not _look(s, iid, str(p["id"])):
					continue
				looked = true
				if not s.pending_events.is_empty():
					return {"action": "event"}
	if looked:
		return {"action": "event"}
	# 2. 判断真假、勾选
	if not st["init"]:
		st["init"] = true
		for iid in s.item_ids:
			var it: Dictionary = s.item(iid)
			var tells: int = s.tells_found(str(it.get("def_id", "")))
			if it.get("fake", false) and (tells > 0 or s.mode == "sell") and base != "greedy" and not sp.get("keep_fake", false):
				s.set_judged(iid, "fake")
				if (s.split or s.mode == "sell") and s.item_ids.size() > 1:
					s.set_selected(iid, false)
		for d in sp.get("deselect", []):
			var di: String = s.iid_of(str(d))
			if di != "":
				s.set_selected(di, false)
		for d in sp.get("select", []):
			var di2: String = s.iid_of(str(d))
			if di2 != "":
				s.set_selected(di2, true)
	# 3. 附加动作
	var extras: Array = b.get("extras", [])
	var avail: Array = []
	for e in extras:
		avail.append(str(e["id"]))
	if sp.has("extras"):
		for e in sp["extras"]:
			if avail.has(str(e)) and not st["extras_done"].has(str(e)):
				st["extras_done"].append(str(e))
				return {"action": "extra", "id": str(e)}
	elif not avail.is_empty() and st["extras_done"].size() < 6:
		if base == "fair" or (_is_random() and rng.randf() < 0.6):
			var pick: String = avail[0] if base == "fair" else avail[rng.randi() % avail.size()]
			if not st["extras_done"].has(pick):
				st["extras_done"].append(pick)
				return {"action": "extra", "id": pick}
	# 4. 特殊成交
	var deals: Array = b.get("deals", [])
	if sp.has("deal"):
		for d in deals:
			if str(d["id"]) == str(sp["deal"]):
				return {"action": "deal", "id": str(d["id"])}
	elif not deals.is_empty() and _is_random() and rng.randf() < 0.25:
		return {"action": "deal", "id": deals[rng.randi() % deals.size()]["id"]}
	if str(sp.get("offer", "")) == "refuse":
		return {"action": "refuse"}
	# 小镇版 fair：钱不够给足赵老三（≥400）就体面地拒收，不走“刚好 300”那一支（town_day3_zhao 的条件里 flag 是数字时会报错）
	if town and base == "fair" and sid == "d2_zhao" and director.world.cash() < 400:
		for d in deals:
			if str(d["id"]) == "refuse":
				return {"action": "deal", "id": "refuse"}
	if s.mode == "sell" and not s.any_selected():
		if not deals.is_empty():
			return {"action": "deal", "id": deals[deals.size() - 1]["id"]}
		return {"action": "refuse"}
	# 公道策略也要留出礼拜六的维持费（约 120 蚨）；赵老三赎人的钱除外
	if base == "fair" and sp.is_empty() and s.mode != "sell" and not s.hard_floor and director.world.day >= 2:
		if director.world.cash() - maxi(s.suggestion, s.floor_v) < 120:
			for d in deals:
				return {"action": "deal", "id": str(d["id"])}
			return {"action": "refuse"}
	# 5. 出价
	st["offers"] = int(st["offers"]) + 1
	if int(st["offers"]) > 10:
		return {"action": "refuse"}
	var v := _offer_value(s, sp, st)
	st["last"] = v
	return {"action": "offer", "value": v}

func _offer_value(s, sp: Dictionary, st: Dictionary) -> int:
	var cash: int = director.world.cash()
	var n: int = int(st["offers"])
	var v := 0
	var sug: int = maxi(1, s.suggestion)
	if sp.has("offers"):
		var seq: Array = sp["offers"]
		var x = seq[mini(n - 1, seq.size() - 1)]
		v = _named_value(s, str(x), sug)
	elif sp.has("offer"):
		v = _named_value(s, str(sp["offer"]), sug)
		if str(sp["offer"]) == "low" and n > 2:
			v = int(s.floor_v * 0.9) if s.mode != "sell" else s.ask
	elif s.mode == "sell":
		match base:
			"greedy":
				v = int(s.floor_v * 1.2) if n == 1 else s.ask
			_:
				v = mini(s.suggestion, s.floor_v) if n == 1 else s.ask
	else:
		match base:
			"greedy":
				v = maxi(1, int(s.ask * 0.5)) if n == 1 else s.ask
			"fair":
				# 像一个会还价的人：先按建议价，客人回价不离谱就接，否则往中间靠
				if n == 1:
					v = sug
				elif s.ask <= int(sug * 1.3) or n >= 4:
					v = s.ask
				else:
					v = int((int(st["last"]) + s.ask) / 2.0)
			_:
				v = int(s.ask * rng.randf_range(0.5, 1.4))
		if s.hard_floor:
			v = maxi(v, s.base_floor) if base != "greedy" or n > 1 else v
			if base == "fair" and not sp.has("offer") and not sp.has("offers"):
				v = s.base_floor   # 他只要刚好够赎人的钱
	# 小镇版 fair：赵老三的儿子被抓了壮丁，给足（高于底价），走“主动给足”的主线分支
	if town and base == "fair" and s.hard_floor and str(s.def.get("id", "")) == "d2_zhao":
		v = maxi(v, 400)
	if s.mode != "sell":
		v = clampi(v, 1, maxi(1, cash))
	return maxi(1, v)

func _named_value(s, x: String, sug: int) -> int:
	match x:
		"suggest": return sug if s.mode != "sell" else s.suggestion
		"ask": return s.ask
		"floor": return s.floor_v
		"low": return maxi(1, int(s.floor_v * 0.8))
		"fund": return maxi(40, int(sug * 1.6))
	return int(x)

func _night(b: Dictionary) -> String:
	var acts: Array = b["actions"]
	var order: Array = plan.get("night%d" % int(b["night"]), ["ledger", "burn", "tidy", "telegraph", "nightsell", "order", "flag", "diary"])
	if _is_random():
		order = order.duplicate()
		order.shuffle()
	var used: Dictionary = _sess_state.get("night%d" % int(b["night"]), {})
	_sess_state["night%d" % int(b["night"])] = used
	for id in order:
		if used.has(id):
			continue
		for a in acts:
			if a["id"] == id and a["enabled"]:
				used[id] = true
				return id
	return "sleep"

func _telegraph(b: Dictionary) -> Dictionary:
	if not b.get("reply", false):
		return {}
	if plan.has("telegram"):
		var t = plan["telegram"]
		if typeof(t) == TYPE_ARRAY and not t.is_empty() and str(t[0]) == "skip":
			return {"skip": true}
		return {"words": t}
	match base:
		"greedy":
			return {"words": ["维持会", "钱"]}
		"random1":
			return {"words": ["有人", "药"]}
		"random2":
			return {"words": ["需要", "药"]}
		"random3":
			return {"skip": true}
	return {"words": ["平安"]}

# 计划结束时核对标记：expect 里 null 表示“不应被设置”；数字按数值比较
func check_expectations(world) -> Array:
	var out: Array = []
	var ex: Dictionary = plan.get("expect", {})
	for k in ex:
		var want = ex[k]
		var got = world.flags.get(k, null)
		var ok := false
		if want == null:
			ok = got == null
		elif typeof(want) in [TYPE_INT, TYPE_FLOAT] and typeof(got) in [TYPE_INT, TYPE_FLOAT]:
			ok = is_equal_approx(float(want), float(got))
		else:
			ok = str(want) == str(got)
		if not ok:
			out.append("计划 %s：标记 %s 期望 %s，实际 %s" % [policy, k, str(want), str(got)])
	var es: Dictionary = plan.get("expect_stats", {})
	for k in es:
		var spec := str(es[k])
		var val: int = world.stat(k)
		var op := spec.substr(0, 2) if spec.substr(0, 2) in [">=", "<=", "=="] else spec.substr(0, 1)
		var num := int(spec.substr(op.length()))
		var ok2 := false
		match op:
			">=": ok2 = val >= num
			"<=": ok2 = val <= num
			"==": ok2 = val == num
			">": ok2 = val > num
			"<": ok2 = val < num
		if not ok2:
			out.append("计划 %s：数值 %s 期望 %s，实际 %d" % [policy, k, spec, val])
	for sid in plan.get("sessions", {}):
		if not sessions_seen.has(sid) and plan.get("require_sessions", true):
			out.append("计划 %s：没有遇到会话 %s" % [policy, sid])
	if not choice_queue.is_empty():
		out.append("计划 %s：这些选项没有用上 %s" % [policy, str(choice_queue)])
	return out
