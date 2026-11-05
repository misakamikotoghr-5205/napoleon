## 多段书的测试驾驶员（模型层，确定）：开迷你书、走到某个节点、了结一仗、按计划把一章打完、一路打到收场。
## test_map / test_run_book / test_run_replay 共用；A2 的界面测试和 map_policy 可以接着用。没有 class_name，preload。
## 走法：每天先看有没有没了结的强制节点（过路费 / 对手 / 强制节点），再拿行军点（手里点数最大的行军牌；没牌就掷骰），
## 沿最短路（按 legs，航程按天 ×3）一段段走，走不动就扎营过夜。仗一律空名单出征、立刻撤出（撤出也算了结）。
extends RefCounted

const Campaign = preload("res://scripts/cards/campaign/ocean_campaign.gd")
const MapRules = preload("res://scripts/cards/campaign/map/map_rules.gd")
const B2 = preload("res://scripts/cards/campaign/ocean_battle2.gd")
const RunConditions = preload("res://scripts/cards/campaign/run/run_conditions.gd")

const MINI := "res://data/campaigns/napoleon/fixtures/mini_book.json"

## 最近一次失败的命令（测试拿来报错）
static var last_error: String = ""


static func new_mini(seed_value: int = 7, extra: Dictionary = {}, path: String = MINI) -> RefCounted:
	var c := Campaign.new()
	var loaded: Dictionary = c.load_book(path)
	if not bool(loaded.get("ok", false)):
		last_error = "load_book " + str(loaded)
		return null
	var opts := {"seed": seed_value}
	opts.merge(extra, true)
	var r: Dictionary = c.new_game(opts)
	if not bool(r.get("ok", false)):
		last_error = "new_game " + str(r)
		return null
	return c


static func send(c, cmd: String, args: Dictionary = {}) -> Dictionary:
	var r: Dictionary = c.send(StringName(cmd), args)
	if not bool(r.get("ok", false)):
		last_error = "%s %s -> %s (scene %s, pos %s)" % [cmd, args, r.get("err", ""), c.scene().get("id", ""),
			c.state.get("map", {}).get("pos", "")]
	return r


static func over(c) -> bool:
	return str(c.state.get("phase", "")) == "game_over"


## 推到白天（月初 / 早晨 / 夜里 / 年终跳转都按 wait 往前走）
static func to_day(c) -> void:
	var guard := 0
	while not over(c) and str(c.state["phase"]) != "day" and guard < 8:
		send(c, "campaign.wait")
		guard += 1


## 过完今天：夜里结算、早晨、白天
static func next_day(c) -> void:
	to_day(c)
	if not over(c):
		send(c, "campaign.wait")
	to_day(c)


## 从当前位置到 target 的最短路（按 legs，航程 = 3 × 天；只走现在走得通的连线和没锁的节点）
static func path_to(c, target: String) -> Array:
	var sh: Dictionary = MapRules.sheet(c)
	var from := str(c.state["map"]["pos"])
	var best := {from: 0}
	var prev := {}
	var frontier: Array = [from]
	while not frontier.is_empty():
		frontier.sort_custom(func(x, y): return int(best[x]) < int(best[y]))
		var cur: String = frontier.pop_front()
		if cur == target:
			break
		for l in sh.get("links", []):
			var nb := ""
			if str(l["a"]) == cur:
				nb = str(l["b"])
			elif str(l["b"]) == cur and not bool(l.get("oneway", false)):
				nb = str(l["a"])
			if nb == "" or not RunConditions.eval(c, l.get("requires", {})):
				continue
			var n := MapRules.node_of(sh, nb)
			if nb != target and MapRules.lock_reason(c, n) != "":
				continue
			if nb == target and MapRules.lock_reason(c, n) != "":
				continue
			var w := 3 * int(l.get("voyage_days", 0)) if int(l.get("voyage_days", 0)) > 0 else int(l.get("legs", 1))
			var cost := int(best[cur]) + w
			if not best.has(nb) or cost < int(best[nb]):
				best[nb] = cost
				prev[nb] = cur
				if not nb in frontier:
					frontier.append(nb)
	if not best.has(target):
		return []
	var path: Array = [target]
	while str(path[0]) != from:
		path.push_front(prev[path[0]])
	path.pop_front()
	return path


## 地图上没了结的事：过路费交钱、对手交钱或开打、强制节点进去
static func clear_pending(c) -> void:
	var guard := 0
	while not over(c) and str(c.state["map"]["pending"]) != "" and guard < 6:
		guard += 1
		var kind := str(c.state["map"]["pending_kind"])
		if kind == "toll":
			send(c, "campaign.map_pay", {"how": "gold"})
		elif kind == "rival":
			var r := send(c, "campaign.map_pay", {"how": "gold"})
			if not bool(r["ok"]):
				send(c, "campaign.map_pay", {"how": "fight"})
				resolve_battle(c)
		else:
			var r2 := send(c, "campaign.map_enter")
			if bool(r2.get("ok", false)):
				if str(r2.get("kind", "")) == "battle":
					resolve_battle(c)
				elif str(r2.get("kind", "")) == "event":
					play_event(c)


## 今天拿行军点：手里点数最大的行军牌；没牌就掷骰
static func take_mp(c) -> void:
	var m: Dictionary = c.state["map"]
	if bool(m["rolled_today"]) or str(m["pending"]) != "":
		return
	var best := -1
	var best_mp := -1
	for i in (m["hand"] as Array).size():
		var mp := int(MapRules.card_def(c, str(m["hand"][i])).get("mp", 0))
		if mp > best_mp:
			best_mp = mp
			best = i
	if best >= 0 and best_mp > 0:
		send(c, "campaign.map_card", {"index": best})
	else:
		send(c, "campaign.map_roll")


## 走到 target（最多 max_days 天）；到了返回 true
static func walk_to(c, target: String, max_days: int = 30) -> bool:
	for _d in range(max_days):
		if over(c):
			return false
		to_day(c)
		clear_pending(c)
		if str(c.state["map"]["pos"]) == target:
			return true
		var path := path_to(c, target)
		if path.is_empty():
			last_error = "no path to %s from %s" % [target, c.state["map"]["pos"]]
			return false
		var sh := MapRules.sheet(c)
		# 航程：当天还没走、还没拿点数时才能上船
		var first := MapRules.link_between(sh, str(c.state["map"]["pos"]), str(path[0]))
		if int(first.get("voyage_days", 0)) > 0:
			if int(c.state["map"]["mp"]) == 0 and not bool(c.state["map"]["moved_today"]):
				send(c, "campaign.map_move", {"to": str(path[0])})
				clear_pending(c)
				continue
			next_day(c)
			continue
		take_mp(c)
		for step in path:
			var l := MapRules.link_between(sh, str(c.state["map"]["pos"]), str(step))
			if int(l.get("voyage_days", 0)) > 0 or int(l.get("legs", 1)) > int(c.state["map"]["mp"]):
				break
			if not bool(send(c, "campaign.map_move", {"to": str(step)})["ok"]):
				break
			clear_pending(c)
			if over(c) or str(c.state["map"]["pos"]) != str(step):
				break
		if str(c.state["map"]["pos"]) == target:
			return true
		next_day(c)
	return str(c.state["map"]["pos"]) == target


## 进事件或插曲后选：问答题每题选 a；其余选第一个能选的
static func play_event(c, prefer: String = "") -> void:
	var ev_id := MapRules.current_event(c)
	var ev: Dictionary = c.event_def(ev_id)
	for _i in range(8):
		if MapRules.current_event(c) != ev_id or ev.is_empty():
			return
		var picked := ""
		for ch in MapRules.event_choices(c, ev):
			if MapRules.choice_error(c, ev, ch) != "":
				continue
			if prefer != "" and str(ch["id"]) == prefer:
				picked = prefer
				break
			if picked == "" and (str(ch.get("question", "")) == "" or str(ch["id"]).ends_with(":a")):
				picked = str(ch["id"])
		if picked == "":
			return
		if not bool(send(c, "campaign.map_choose", {"choice": picked})["ok"]):
			return


## 了结眼前这一仗：mode "retreat"（空名单出征立刻撤出）或 "lose"（空名单一直交火到输）；
## 输了就按 fate 选大命运（默认拼死突围，永远选得了）
static func resolve_battle(c, mode: String = "retreat", fate: String = "desperate_breakout") -> void:
	var b2: Dictionary = c.state["rogue"]["battle2"]
	if str(b2["phase"]) != "active":
		if not bool(send(c, "campaign.battle_prepare")["ok"]) and str(c.state["rogue"]["battle2"]["phase"]) != "lineup":
			return
		send(c, "campaign.battle_begin", {"companions": [], "troops": [], "protagonist": false})
	for _i in range(40):
		var st: Dictionary = c.state["rogue"]["battle2"].get("state", {})
		if str(c.state["rogue"]["battle2"]["phase"]) != "active" or str(st.get("phase", "")) != "command":
			break
		send(c, "campaign.battle_cmd", {"cmd": "retreat" if mode == "retreat" else "fight", "args": {}})
	if str(c.state["rogue"]["battle2"]["phase"]) == "active":
		send(c, "campaign.battle_finish")
	if bool(c.state["rogue"]["big_fate"].get("pending", false)):
		send(c, "campaign.big_fate", {"choice": fate})


## 本场有仗而且还没了结（站在锚点上）
static func scene_battle_open(c) -> bool:
	return B2.has_battle(c) and not B2.resolved(c)


## 剧情：站到本场锚点上（战役段的先开拔、过军议），打掉本场的仗，作出抉择 choice（"" = 第一个能选的推进抉择）
static func play_scene(c, choice: String = "", council: String = "") -> bool:
	if over(c):
		return false
	to_day(c)
	if MapRules.enabled(c):
		var anchor := MapRules.anchor_of(c, str(c.scene()["id"]))
		var node := MapRules.node_of(MapRules.sheet(c), anchor)
		if str(node.get("phase", "accumulate")) == "campaign" and not bool(c.state["map"]["mustered"]):
			if not muster(c, council):
				return false
		if anchor != "" and not walk_to(c, anchor):
			return false
		to_day(c)
		clear_pending(c)
		send(c, "campaign.map_enter")
	if scene_battle_open(c):
		resolve_battle(c)
	var pick := choice
	if pick == "":
		for row in c.available_choices():
			if bool(row["available"]) and bool(row.get("advance", true)) and str(row.get("branch", "")) == "":
				pick = str(row["id"])
				break
	if pick == "":
		last_error = "no choice in " + str(c.scene()["id"])
		return false
	return bool(send(c, "campaign.choose", {"choice": pick})["ok"])


## 开拔：先凑驿站印，再到 muster 开拔，然后进军议选 council（"" = 第一项）
static func muster(c, council: String = "") -> bool:
	var sh := MapRules.sheet(c)
	var guard := 0
	while int(c.state["map"]["stamps"]) < int(sh.get("stamps_need", 0)) and guard < 4:
		guard += 1
		var post := ""
		for n in sh.get("nodes", []):
			if int(n.get("pass", {}).get("stamp", 0)) > 0 and not str(n["id"]) in c.state["map"]["stamped"]:
				post = str(n["id"])
				break
		if post == "" or not walk_to(c, post):
			return false
	var m := MapRules.pick_node(c, sh, "muster")
	if not walk_to(c, m):
		return false
	to_day(c)
	if not bool(send(c, "campaign.map_muster")["ok"]):
		return false
	for n in sh.get("nodes", []):
		if str(n.get("role", "")) == "council" and str(n.get("phase", "")) == "campaign":
			if walk_to(c, str(n["id"])):
				to_day(c)
				if bool(send(c, "campaign.map_enter")["ok"]):
					play_event(c, council)
	return true


## 插曲（章开头的事件牌）：有就打掉
static func play_interlude(c) -> void:
	if MapRules.enabled(c) and str(c.state["map"]["interlude"]) != "" and str(c.state["map"]["event"]) == "":
		play_event(c)


## 一路打到收场或段切换；plan：{场景 id: 抉择 id}
static func play_until(c, plan: Dictionary = {}, stop_segment_change: bool = true, max_scenes: int = 40) -> bool:
	var seg := str(c.state["segment"])
	for _i in range(max_scenes):
		if over(c):
			return true
		if stop_segment_change and str(c.state["segment"]) != seg:
			return true
		play_interlude(c)
		var sid := str(c.scene()["id"])
		if not play_scene(c, str(plan.get(sid, ""))):
			return false
	return over(c)
