## 世界地图的规则（WORLD_MAP_DESIGN §5、§7）：一章一张图（sheet），积累段 → 开拔 → 战役段。
## 行军（骰子 / 行军牌 / 连线 / 航程）、雾、随机槽、对手分遣队、驿站印、兵站、开拔、天数预算，全是整数、完全确定。
## 状态在 campaign.state.map（§5.9 的形状，由 valid() 校验）。没有 class_name，别处 preload。
## campaign 提供：state、book、definition、scene()、chapter()、_apply_effects、_record、_use、_used、_tick_day、
## add_coin(id, delta)、battle_resolved()；本文件不 preload 战斗或伙伴规则（防止循环引用）。
extends RefCounted

const CompanionRules = preload("res://scripts/cards/campaign/companion_rules.gd")

const RunConditions = preload("res://scripts/cards/campaign/run/run_conditions.gd")
const BattleApi = preload("res://scripts/cards/campaign/run/run_battle_api.gd")

const TYPES := ["story", "battle", "elite", "boss", "event", "camp", "supply", "shop", "branch", "slot", "teaser"]
const ROLES := ["", "post", "muster", "depot", "port", "intel", "project", "council"]
const BATTLE_TYPES := ["battle", "elite", "boss"]
const SLOT_KINDS := ["event", "battle", "camp", "supply", "shop"]
const HAND := 3
const HAND_MAX := 4
const DEPOT_COST := 2
## 随机槽定成 camp / supply / shop、或节点没写 actions 时，按类型给的默认动作
const DEFAULT_ACTIONS := {
	"camp": ["activity:rest", "schedule:recruit", "schedule:train", "schedule:bond_story", "schedule:diplomacy", "schedule:festival", "schedule:smuggle"],
	"supply": ["visit:town", "trade:fair", "build_depot"],
	"shop": ["activity:merchant", "recruit:troop"],
}
## 书里没写行军牌时的兜底（§6.2 的数值）
const MARCH_CARDS := {"march_2": {"mp": 2}, "march_3": {"mp": 3}, "forced_4": {"mp": 4, "effects": {"vitality": -4}},
	"scout_1": {"mp": 1, "reveal": 2}, "wagon_1": {"mp": 1, "coins": {"supply": 2}}, "night_2": {"mp": 2, "ignore_forced": true},
	"fair_wind": {"mp": 0, "voyage_minus": 1}, "dive_3": {"mp": 3, "ignore_forced": true}}
const MARCH_DECK := ["march_2", "march_2", "march_2", "march_3", "march_3", "forced_4", "scout_1", "wagon_1", "night_2"]
const STATE_KEYS := ["id", "sheet", "pos", "pending", "pending_kind", "meet", "toll", "mp", "rolled_today", "moved_today", "rolls",
	"deck", "hand", "discard", "visited", "done", "revealed", "slots", "stamps", "stamped", "depots", "rivals", "days_on_sheet",
	"delay", "mustered", "routes_taken", "boss_mod", "cp_early", "event", "interlude", "encounter", "today", "boss_waves_minus"]
const ROUTE_IDS := ["salon_route", "duel_route", "smuggle_route"]


# ================================================================ 查图（纯函数，校验器也用）

static func map_of(bundle: Dictionary, seg: String) -> Dictionary:
	return bundle.get("maps", {}).get(seg, {})


static func sheet_of(bundle: Dictionary, seg: String, chapter_id: String) -> Dictionary:
	for s in map_of(bundle, seg).get("sheets", []):
		if str(s.get("chapter", "")) == chapter_id:
			return s
	return {}


static func node_of(sheet: Dictionary, id: String) -> Dictionary:
	for n in sheet.get("nodes", []):
		if str(n.get("id", "")) == id:
			return n
	return {}


static func node_ids(sheet: Dictionary) -> Array:
	var out: Array = []
	for n in sheet.get("nodes", []):
		out.append(str(n.get("id", "")))
	return out


## 两点之间的连线（oneway 只能 a→b）；没有返回 {}
static func link_between(sheet: Dictionary, from: String, to: String) -> Dictionary:
	for l in sheet.get("links", []):
		if str(l.get("a", "")) == from and str(l.get("b", "")) == to:
			return l
		if str(l.get("b", "")) == from and str(l.get("a", "")) == to and not bool(l.get("oneway", false)):
			return l
	return {}


## 邻接表：{id: [邻点…]}；directed = true 时按 oneway 方向
static func adjacency(sheet: Dictionary, directed: bool = false, skip: Dictionary = {}) -> Dictionary:
	var adj := {}
	for id in node_ids(sheet):
		adj[id] = []
	for l in sheet.get("links", []):
		var a := str(l.get("a", ""))
		var b := str(l.get("b", ""))
		if skip.has(a) or skip.has(b) or not adj.has(a) or not adj.has(b):
			continue
		adj[a].append(b)
		if not directed or not bool(l.get("oneway", false)):
			adj[b].append(a)
	return adj


## 从 start 出发的连线段数（BFS，不看锁）
static func distances(sheet: Dictionary, start: String, directed: bool = false, skip: Dictionary = {}) -> Dictionary:
	var adj := adjacency(sheet, directed, skip)
	var dist := {}
	if not adj.has(start) or skip.has(start):
		return dist
	dist[start] = 0
	var queue: Array = [start]
	while not queue.is_empty():
		var cur: String = queue.pop_front()
		for nb in adj[cur]:
			if not dist.has(nb):
				dist[nb] = int(dist[cur]) + 1
				queue.append(nb)
	return dist


## muster / boss 可以写成数组：取第一个 requires 成立的节点（campaign 为 null 时取第一个）
static func pick_node(campaign, sheet: Dictionary, key: String) -> String:
	var v = sheet.get(key, "")
	if typeof(v) == TYPE_STRING:
		return str(v)
	if typeof(v) != TYPE_ARRAY:
		return ""
	for id in v:
		var n := node_of(sheet, str(id))
		if campaign == null or RunConditions.eval(campaign, n.get("requires", {})):
			return str(id)
	return str(v[0]) if not (v as Array).is_empty() else ""


static func node_list(sheet: Dictionary, key: String) -> Array:
	var v = sheet.get(key, "")
	if typeof(v) == TYPE_ARRAY:
		return (v as Array).duplicate()
	return [str(v)] if str(v) != "" else []


## 节点是不是战斗类（R2）：battle / elite / boss、带场景战斗的锚点、权重里有 battle 的随机槽
static func is_battle_node(bundle: Dictionary, seg: String, node: Dictionary, level_offset: int = 0) -> bool:
	var t := str(node.get("type", ""))
	if t in BATTLE_TYPES:
		return true
	if str(node.get("scene", "")) != "" and not scene_battle(bundle, seg, str(node["scene"]), level_offset).is_empty():
		return true
	if t == "slot" and int(node.get("slot", {}).get("kinds", {}).get("battle", 0)) > 0:
		return true
	return false


## 一场的场景战斗（RunBook.scene_battle 的实现）：书的 scene_battles 优先（template "" = 空模板），否则 scene_map 的幕
static func scene_battle(bundle: Dictionary, seg: String, scene_id: String, level_offset: int = 0) -> Dictionary:
	var sb: Dictionary = bundle.get("raw", {}).get("segments", {}).get(seg, {}).get("scene_battles", {})
	if sb.has(scene_id) and typeof(sb[scene_id]) == TYPE_DICTIONARY:
		var row: Dictionary = sb[scene_id]
		if str(row.get("template", "")).is_empty():
			return {}
		var out: Dictionary = row.duplicate(true)
		out["level"] = int(row.get("level", 1))
		return out
	var sm = BattleApi.lib().get("scene_map", {}).get(scene_id)
	if typeof(sm) != TYPE_DICTIONARY:
		return {}
	return {"template": str(sm["template"]), "level": 2 * int(sm["act"]) - 1 + level_offset, "act": int(sm["act"])}


## 节点自己的战斗（不带 scene 的 battle / elite / boss）：模板不在库里就用 fallback
static func node_template(node: Dictionary) -> String:
	var tpl := str(node.get("template", ""))
	var lib: Dictionary = BattleApi.lib().get("templates", {})
	if tpl != "" and lib.has(tpl):
		return tpl
	var fb := str(node.get("fallback", ""))
	return fb if fb != "" and lib.has(fb) else tpl


# ================================================================ 开图

## 进一章：开这一章的图，随机槽、牌组、对手一次性定下（之后读档、改数据都不再变）
static func open_sheet(campaign, chapter_id: String) -> Dictionary:
	var seg := str(campaign.state.get("segment", ""))
	var sheet := sheet_of(campaign.book, seg, chapter_id)
	if sheet.is_empty():
		return {}
	var start := str(sheet.get("start", ""))
	var map := {"id": str(map_of(campaign.book, seg).get("id", seg)), "sheet": chapter_id, "pos": start, "pending": "", "pending_kind": "",
		"meet": "", "toll": {}, "mp": 0, "rolled_today": false, "moved_today": false, "rolls": 0,
		"deck": _shuffled_deck(campaign, seg, chapter_id), "hand": [], "discard": [],
		"visited": [start], "done": [], "revealed": [], "slots": {}, "stamps": 0, "stamped": [], "depots": [], "rivals": {},
		"days_on_sheet": 0, "delay": 0, "mustered": false, "routes_taken": [],
		"boss_mod": {"cp_bonus": 0, "enemy_morale": 0, "prep_turn": 0}, "cp_early": 0,
		"event": "", "interlude": "", "encounter": {}, "today": [], "boss_waves_minus": 0}
	campaign.state["map"] = map
	_roll_slots(campaign, seg, chapter_id, sheet)
	for r in sheet.get("rivals", []):
		map["rivals"][str(r["id"])] = {"step": int(r.get("start", 0)), "stopped_until": 0, "beaten": false}
	_refill_hand(campaign)
	reveal_around(campaign)
	map["interlude"] = _pick_interlude(campaign, seg, chapter_id, sheet)
	return map


static func _shuffled_deck(campaign, seg: String, chapter_id: String) -> Array:
	var raw: Dictionary = campaign.book.get("raw", {})
	var deck: Array = (raw.get("march_deck", MARCH_DECK) as Array).duplicate()
	var extra = raw.get("march_deck_extra", {}).get(seg, {}).get(chapter_id, [])
	if typeof(extra) == TYPE_ARRAY:
		deck.append_array(extra)
	var x := seed_for(int(campaign.state.get("seed", 1)), "deck|%s|%s" % [seg, chapter_id])
	if x == 0:
		x = 0x9E3779B9
	for i in range(deck.size() - 1, 0, -1):
		x = _xorshift(x)
		var j := x % (i + 1)
		var tmp = deck[i]
		deck[i] = deck[j]
		deck[j] = tmp
	return deck


static func _xorshift(x: int) -> int:
	x = (x ^ (x << 13)) & 0xFFFFFFFF
	x = (x ^ (x >> 17)) & 0xFFFFFFFF
	x = (x ^ (x << 5)) & 0xFFFFFFFF
	return x


## FNV-1a 32 位（与 ocean_battle2.seed_for 相同）
static func seed_for(campaign_seed: int, key: String) -> int:
	var k := "%d|%s" % [campaign_seed, key]
	var h := 2166136261
	for i in range(k.length()):
		h = ((h ^ k.unicode_at(i)) * 16777619) & 0xFFFFFFFF
	return h


## §5.5：按节点 id 排序依次定随机槽；和战斗节点相邻的槽去掉 battle 权重（R2）
static func _roll_slots(campaign, seg: String, chapter_id: String, sheet: Dictionary) -> void:
	var map: Dictionary = campaign.state["map"]
	var ids: Array = []
	for n in sheet.get("nodes", []):
		if str(n.get("type", "")) == "slot":
			ids.append(str(n["id"]))
	ids.sort()
	var adj := adjacency(sheet)
	var offset := int(campaign.state.get("run", {}).get("level_offset", 0))
	var seed_v := int(campaign.state.get("seed", 1))
	for id in ids:
		var node := node_of(sheet, id)
		var slot: Dictionary = node.get("slot", {})
		var kinds: Dictionary = slot.get("kinds", {})
		var near_battle := false
		for nb in adj.get(id, []):
			var other := node_of(sheet, str(nb))
			if str(other.get("type", "")) != "slot" and is_battle_node(campaign.book, seg, other, offset):
				near_battle = true
		var keys: Array = []
		for k in kinds:
			if str(k) in SLOT_KINDS and int(kinds[k]) > 0 and not (near_battle and str(k) == "battle"):
				keys.append(str(k))
		keys.sort()
		var total := 0
		for k in keys:
			total += int(kinds[k])
		var kind := "camp"
		if total > 0:
			var roll := seed_for(seed_v, "slot|%s|%s|%s" % [seg, chapter_id, id]) % total
			for k in keys:
				roll -= int(kinds[k])
				if roll < 0:
					kind = k
					break
		var row := {"kind": kind, "id": "", "level": int(slot.get("level", 0))}
		var pick_key := "event|%s|%s|%s" % [seg, chapter_id, id]
		if kind == "event":
			var ev := _pick_event(campaign, seg, chapter_id, str(slot.get("pool", chapter_id)), seed_for(seed_v, pick_key))
			if ev == "":
				row["kind"] = "camp"
			else:
				row["id"] = ev
				var seen: Array = campaign.state["run"]["events_seen"]
				if not ev in seen:
					seen.append(ev)
		elif kind == "battle":
			var tpl := _pick_pool_battle(campaign, seg, int(row["level"]), seed_for(seed_v, pick_key))
			if tpl == "":
				row["kind"] = "camp"
			else:
				row["id"] = tpl
		map["slots"][id] = row


## 三层池（本章池 slot.pool、本段池 pool == 段、全书通用池）里此刻可用的随机事件，按权重挑一个
static func _pick_event(campaign, seg: String, chapter_id: String, pool: String, h: int) -> String:
	var cands: Array = []
	var seen: Array = campaign.state.get("run", {}).get("events_seen", [])
	var sources: Array = (campaign.book.get("events", {}).get(seg, []) as Array) + (campaign.book.get("events_common", []) as Array)
	for ev in sources:
		var p := str(ev.get("pool", ""))
		if p == "fixed" or bool(ev.get("council", false)) or str(ev.get("interlude", "")) != "":
			continue
		var common: bool = ev in campaign.book.get("events_common", [])
		if not common and p != pool and p != seg:
			continue
		if ev.has("chapters") and not chapter_id in ev.get("chapters", []):
			continue
		if bool(ev.get("once", true)) and str(ev.get("id", "")) in seen:
			continue
		if not RunConditions.eval(campaign, ev.get("requires", {})):
			continue
		var w := int(ev.get("weight", 1))
		var wbt = ev.get("weight_by_trust", {})
		if typeof(wbt) == TYPE_DICTIONARY and not wbt.is_empty():
			var trust := int(campaign.state.get("rogue", {}).get("army", {}).get("trust", {}).get("hero|" + str(wbt.get("companion", "")), 0))
			w += int(wbt.get("per_trust", 0)) * trust
		if w > 0:
			cands.append([str(ev["id"]), w])
	cands.sort_custom(func(a, b): return str(a[0]) < str(b[0]))
	var total := 0
	for c in cands:
		total += int(c[1])
	if total <= 0:
		return ""
	var roll := h % total
	for c in cands:
		roll -= int(c[1])
		if roll < 0:
			return str(c[0])
	return ""


## book.battle_pool[段] 里覆盖这个等级的那一档（键写成 "13-16"）
static func _pick_pool_battle(campaign, seg: String, level: int, h: int) -> String:
	var pools: Dictionary = campaign.book.get("raw", {}).get("battle_pool", {}).get(seg, {})
	for band in pools:
		var lo := int(str(band).get_slice("-", 0))
		var hi := int(str(band).get_slice("-", 1)) if str(band).contains("-") else lo
		if level >= lo and level <= hi:
			var list: Array = pools[band]
			if not list.is_empty():
				return str(list[h % list.size()])
	return ""


## 插曲：本章 interlude 类型的事件池（interlude 字段等于这一类、chapters 含本章），按 interlude|段|章 的种子挑一张
static func _pick_interlude(campaign, seg: String, chapter_id: String, sheet: Dictionary) -> String:
	var kind := str(sheet.get("interlude", ""))
	if kind == "":
		return ""
	var cands: Array = []
	for ev in (campaign.book.get("events", {}).get(seg, []) as Array) + (campaign.book.get("events_common", []) as Array):
		if str(ev.get("interlude", "")) != kind:
			continue
		if ev.has("chapters") and not chapter_id in ev.get("chapters", []):
			continue
		if RunConditions.eval(campaign, ev.get("requires", {})):
			cands.append(str(ev["id"]))
	cands.sort()
	if cands.is_empty():
		return ""
	return str(cands[seed_for(int(campaign.state.get("seed", 1)), "interlude|%s|%s" % [seg, chapter_id]) % cands.size()])


# ================================================================ 现在的图

static func enabled(campaign) -> bool:
	return typeof(campaign.state.get("map")) == TYPE_DICTIONARY and not (campaign.state["map"] as Dictionary).is_empty()


static func sheet(campaign) -> Dictionary:
	if not enabled(campaign):
		return {}
	return sheet_of(campaign.book, str(campaign.state.get("segment", "")), str(campaign.state["map"]["sheet"]))


## 节点在这一局里的实际类型（随机槽按定下的 kind）
static func node_kind(campaign, node: Dictionary) -> String:
	var t := str(node.get("type", ""))
	if t == "slot":
		return str(campaign.state["map"]["slots"].get(str(node.get("id", "")), {}).get("kind", "camp"))
	return t


## 节点能办的动作：写了 actions 用写的，没写按类型默认；role:muster 自动有「开拔」
static func node_actions(campaign, node: Dictionary) -> Array:
	var out: Array = []
	if node.has("actions") and str(node.get("type", "")) != "slot":
		out = (node["actions"] as Array).duplicate()
	else:
		out = (DEFAULT_ACTIONS.get(node_kind(campaign, node), []) as Array).duplicate()
	if str(node.get("role", "")) == "muster" and not "muster" in out:
		out.append("muster")
	return out


## 当前场景的锚点节点 id（找不到返回 ""）
static func anchor_of(campaign, scene_id: String) -> String:
	for n in sheet(campaign).get("nodes", []):
		if str(n.get("scene", "")) == scene_id:
			return str(n["id"])
	return ""


## 当前场景的锚点已经在战役段（= 积累段的锚点都走完了，C5）
static func anchors_done(campaign) -> bool:
	var anchor := node_of(sheet(campaign), anchor_of(campaign, str(campaign.scene().get("id", ""))))
	return anchor.is_empty() or str(anchor.get("phase", "accumulate")) == "campaign"


## 节点锁：返回 "" 或原因键（phase 锁、requires、预告）。scene_order 只挡进入，不挡路过
static func lock_reason(campaign, node: Dictionary) -> String:
	var map: Dictionary = campaign.state["map"]
	if str(node.get("type", "")) == "teaser":
		return "volume"
	var phase := str(node.get("phase", "accumulate"))
	if phase == "campaign" and not bool(map["mustered"]):
		return "muster"
	if phase != "campaign" and bool(map["mustered"]) and str(node.get("id", "")) != str(map["pos"]):
		return "mustered"
	var r := RunConditions.reason(campaign, node.get("requires", {}))
	if r != "":
		return r
	return ""


static func enter_reason(campaign, node: Dictionary) -> String:
	var lock := lock_reason(campaign, node)
	if lock != "":
		return lock
	var scene_id := str(node.get("scene", ""))
	if scene_id != "" and scene_id != str(campaign.scene().get("id", "")):
		return "scene_order"
	return ""


static func visible(campaign, id: String) -> bool:
	var node := node_of(sheet(campaign), id)
	var fog := str(node.get("fog", "open"))
	return fog != "hidden" or id in campaign.state["map"]["revealed"] or id == str(campaign.state["map"]["pos"])


static func revealed(campaign, id: String) -> bool:
	var node := node_of(sheet(campaign), id)
	return str(node.get("fog", "open")) == "open" or id in campaign.state["map"]["revealed"]


## 雾：type 两段以内、hidden 相邻自动揭开
static func reveal_around(campaign, radius_all: int = 0) -> void:
	var map: Dictionary = campaign.state["map"]
	var sh := sheet(campaign)
	var dist := distances(sh, str(map["pos"]))
	for n in sh.get("nodes", []):
		var id := str(n["id"])
		if not dist.has(id) or id in map["revealed"]:
			continue
		var d := int(dist[id])
		var fog := str(n.get("fog", "open"))
		if d <= radius_all or (fog == "type" and d <= 2) or (fog == "hidden" and d <= 1):
			map["revealed"].append(id)


# ================================================================ 每天

## _tick_day 里调用：对手走一步、mp 清零、补手牌、天数预算（单段书不调用）
static func on_tick(campaign) -> void:
	if not enabled(campaign):
		return
	var map: Dictionary = campaign.state["map"]
	map["mp"] = 0
	map["rolled_today"] = false
	map["moved_today"] = false
	map["today"] = []
	map["days_on_sheet"] = int(map["days_on_sheet"]) + 1
	# 在自己的兵站上过夜：军需券 +3（§7.3「停留时 +3」）
	if at_depot(campaign):
		campaign.add_coin("supply", 3)
	var sh := sheet(campaign)
	var days_max := int(sh.get("days_max", 99))
	if not bool(map["mustered"]):
		if int(map["days_on_sheet"]) > days_max:
			map["delay"] = int(map["delay"]) + 1
		if int(map["days_on_sheet"]) >= days_max + 4 and anchors_done(campaign) and str(map["pending"]) == "" and campaign.battle_idle():
			var muster := pick_node(campaign, sh, "muster")
			if muster != "":
				map["pos"] = muster
				if not muster in map["visited"]:
					map["visited"].append(muster)
				reveal_around(campaign)
				_muster(campaign, true)
	_move_rivals(campaign)
	_refill_hand(campaign)


static func _move_rivals(campaign) -> void:
	var map: Dictionary = campaign.state["map"]
	var day := int(campaign.state.get("day", 1))
	for r in sheet(campaign).get("rivals", []):
		var id := str(r["id"])
		var row: Dictionary = map["rivals"].get(id, {})
		if row.is_empty() or bool(row.get("beaten", false)) or not RunConditions.eval(campaign, r.get("requires", {})):
			continue
		if int(row.get("stopped_until", 0)) >= day:
			continue
		var path: Array = r.get("path", [])
		if path.is_empty():
			continue
		row["step"] = (int(row["step"]) + int(r.get("speed", 1))) % path.size()
		var at := str(path[int(row["step"])])
		# A moving patrol cannot keep blocking a place it has already left.
		if str(map["pending_kind"]) == "rival" and str(map["meet"]) == id and at != str(map["pos"]):
			map["pending"] = ""
			map["pending_kind"] = ""
			map["meet"] = ""
			campaign._record("rival_passed", {"rival": id})
		if at in map["depots"] and CompanionRules.reserve_bonus(campaign, "depot_guard") == 0 and (bool(r.get("burns_depots", false)) or bool(r.get("buys_depots", false))):
			map["depots"].erase(at)
			campaign._record("depot_lost", {"node": at, "rival": id})
		if at == str(map["pos"]) and str(map["pending"]) == "":
			_meet(campaign, r)


## 对手站的位置
static func rival_pos(campaign, r: Dictionary) -> String:
	var path: Array = r.get("path", [])
	if path.is_empty():
		return ""
	return str(path[int(campaign.state["map"]["rivals"].get(str(r["id"]), {}).get("step", 0)) % path.size()])


static func rival_active(campaign, r: Dictionary) -> bool:
	var row: Dictionary = campaign.state["map"]["rivals"].get(str(r.get("id", "")), {})
	return not row.is_empty() and not bool(row.get("beaten", false)) and RunConditions.eval(campaign, r.get("requires", {}))


static func _meet(campaign, r: Dictionary) -> void:
	var map: Dictionary = campaign.state["map"]
	map["pending"] = str(map["pos"])
	map["pending_kind"] = "rival"
	map["meet"] = str(r["id"])
	var eff: Dictionary = r.get("meet", {}).get("effects", {})
	_effects(campaign, eff)
	campaign._record("rival_meet", {"rival": str(r["id"]), "node": str(map["pos"])})


static func _refill_hand(campaign) -> void:
	var map: Dictionary = campaign.state["map"]
	while (map["hand"] as Array).size() < HAND + CompanionRules.reserve_bonus(campaign, "march_hand"):
		if (map["deck"] as Array).is_empty():
			if (map["discard"] as Array).is_empty():
				break
			map["deck"] = (map["discard"] as Array).duplicate()
			map["discard"] = []
		map["hand"].append(map["deck"].pop_front())


# ================================================================ 指令

static func handle(campaign, cmd: String, args: Dictionary) -> Dictionary:
	if not enabled(campaign):
		return _fail("bad_phase")
	var phase := str(campaign.state.get("phase", ""))
	var interlude_ok: bool = cmd in ["campaign.map_choose", "campaign.map_appraise"] and str(campaign.state["map"]["event"]) == "" \
		and str(campaign.state["map"]["interlude"]) != "" and phase in ["year_jump", "month_open", "morning", "day"]
	if phase != "day" and not interlude_ok:
		return _fail("bad_phase")
	if bool(campaign.state.get("rogue", {}).get("big_fate", {}).get("pending", false)) and cmd != "campaign.map_scout":
		return _fail("big_fate_pending")
	match cmd:
		"campaign.map_roll": return _roll(campaign, args)
		"campaign.map_card": return _card(campaign, args)
		"campaign.map_move": return _move(campaign, args)
		"campaign.map_enter": return _enter(campaign, args)
		"campaign.map_choose": return _choose(campaign, args)
		"campaign.map_appraise": return _appraise(campaign, args)
		"campaign.map_scout": return _scout(campaign, args)
		"campaign.map_build": return _build(campaign, args)
		"campaign.map_pay": return _pay(campaign, args)
		"campaign.map_muster": return _muster_cmd(campaign, args)
	return _fail("bad_args")


static func _black_minus(campaign, mp: int) -> int:
	var signs: Dictionary = campaign.rules().get("signs", {})
	var m: Dictionary = signs.get(str(campaign.state.get("sign", "white")), {}).get("map", {})
	if mp > 0 and int(m.get("mp", 0)) != 0:
		return maxi(1, mp + int(m["mp"]))
	return mp


static func _roll(campaign, args: Dictionary) -> Dictionary:
	for k in args:
		if k != "steps" or typeof(args[k]) != TYPE_INT:
			return _fail("bad_args")
	var map: Dictionary = campaign.state["map"]
	if bool(map["rolled_today"]):
		return _fail("already_used")
	if str(map["pending"]) != "":
		return _fail("pending_node")
	var steps := 0
	if args.has("steps"):
		steps = int(args["steps"])
		if steps < 1 or steps > 6:
			return _fail("bad_args")
		var props: Array = campaign.state["rogue"]["props"]
		if "prop_loaded_dice" in props:
			props.erase("prop_loaded_dice")
		elif int(campaign.state["rogue"]["coins"].get("intel", 0)) >= 1:
			campaign.add_coin("intel", -1)
		else:
			return _fail("missing_item")
	else:
		var run: Dictionary = campaign.state["run"]
		steps = seed_for(int(campaign.state["seed"]), "dice|%s|%d" % [campaign.state["segment"], int(run.get("dice", 0))]) % 6 + 1
		run["dice"] = int(run.get("dice", 0)) + 1
	steps = _black_minus(campaign, steps)
	map["mp"] = int(map["mp"]) + steps
	map["rolled_today"] = true
	map["rolls"] = int(map["rolls"]) + 1
	campaign._record("map_roll", {"steps": steps})
	return {"ok": true, "err": "", "steps": steps}


static func _card(campaign, args: Dictionary) -> Dictionary:
	if args.size() != 1 or typeof(args.get("index")) != TYPE_INT:
		return _fail("bad_args")
	var map: Dictionary = campaign.state["map"]
	var i := int(args["index"])
	if i < 0 or i >= (map["hand"] as Array).size():
		return _fail("bad_args")
	if bool(map["rolled_today"]):
		return _fail("already_used")
	if str(map["pending"]) != "":
		return _fail("pending_node")
	var id := str(map["hand"][i])
	var card := card_def(campaign, id)
	map["hand"].remove_at(i)
	map["discard"].append(id)
	var mp := _black_minus(campaign, int(card.get("mp", 0)))
	map["mp"] = int(map["mp"]) + mp
	map["rolled_today"] = true
	_effects(campaign, card.get("effects", {}))
	for c in card.get("coins", {}):
		campaign.add_coin(str(c), int(card["coins"][c]))
	if int(card.get("reveal", 0)) > 0:
		reveal_around(campaign, int(card["reveal"]))
	map["today"].append("card:" + id)
	campaign._record("map_card", {"id": id, "mp": mp})
	return {"ok": true, "err": "", "mp": mp, "card": id}


static func card_def(campaign, id: String) -> Dictionary:
	var cards: Dictionary = campaign.book.get("raw", {}).get("march_cards", MARCH_CARDS)
	return cards.get(id, MARCH_CARDS.get(id, {"mp": 1}))


static func _today_card(campaign, key: String) -> int:
	var total := 0
	for t in campaign.state["map"]["today"]:
		if str(t).begins_with("card:"):
			total += int(card_def(campaign, str(t).trim_prefix("card:")).get(key, 0))
	return total


static func _move(campaign, args: Dictionary) -> Dictionary:
	if args.size() != 1 or typeof(args.get("to")) != TYPE_STRING:
		return _fail("bad_args")
	var map: Dictionary = campaign.state["map"]
	if str(map["pending"]) != "":
		return _fail("pending_node")
	if not campaign.battle_idle():
		return _fail("battle_pending")
	var sh := sheet(campaign)
	var to := str(args["to"])
	var node := node_of(sh, to)
	if node.is_empty():
		return _fail("bad_args")
	var link := link_between(sh, str(map["pos"]), to)
	if link.is_empty():
		return _fail("not_adjacent")
	if not visible(campaign, to):
		return _fail("fog")
	if lock_reason(campaign, node) != "" or not RunConditions.eval(campaign, link.get("requires", {})):
		return _fail("locked")
	var voyage := int(link.get("voyage_days", 0))
	var toll: Dictionary = link.get("toll", {})
	var free: bool = "prop_free_toll" in map["today"] or CompanionRules.reserve_bonus(campaign, "toll_free") > 0
	if not toll.is_empty() and not free and int(campaign.state["rogue"]["coins"].get("gold", 0)) < int(toll.get("gold", 0)) \
			and not "prop_bribe_pouch" in campaign.state["rogue"]["props"]:
		return _fail("insufficient_funds")
	if voyage > 0:
		if bool(map["moved_today"]) or int(map["mp"]) != 0:
			return _fail("no_mp")
		var days := maxi(1, voyage - _today_card(campaign, "voyage_minus") - CompanionRules.reserve_bonus(campaign, "voyage_days"))
		var started_mustered := bool(map["mustered"])
		for _d in range(days):
			campaign._tick_day()
			if str(campaign.state["phase"]) == "game_over":
				return _ok()
			# Forced muster interrupts travel. Its position must not be replaced
			# by an accumulation node that has just become inaccessible.
			if not started_mustered and bool(map["mustered"]):
				map["moved_today"] = true
				return _ok()
	else:
		var legs := int(link.get("legs", 1))
		if legs > int(map["mp"]):
			return _fail("no_mp")
		map["mp"] = int(map["mp"]) - legs
		var supply := int(link.get("supply", 0))
		if supply > 0 and not "prop_field_ration" in map["today"]:
			var have := int(campaign.state["rogue"]["coins"].get("supply", 0))
			campaign.add_coin("supply", -mini(have, supply))
			if have < supply:
				_effects(campaign, {"vitality": -5 * (supply - have)})
				campaign._record("map_starve", {"short": supply - have})
	map["pos"] = to
	map["moved_today"] = true
	if not to in map["visited"]:
		map["visited"].append(to)
	reveal_around(campaign)
	var route := str(link.get("route", ""))
	if route in ROUTE_IDS and not route in map["routes_taken"]:
		map["routes_taken"].append(route)
		campaign.route_reward(route)
	campaign._record("map_move", {"to": to})
	if not toll.is_empty() and not free:
		map["pending"] = to
		map["pending_kind"] = "toll"
		map["toll"] = toll.duplicate(true)
		return _ok()
	_arrive(campaign, node)
	return _ok()


## 到达一个节点：结算 pass（路过），然后看对手和强制节点
static func _arrive(campaign, node: Dictionary) -> void:
	var map: Dictionary = campaign.state["map"]
	var id := str(node["id"])
	var fx: Dictionary = node.get("pass", {})
	for c in fx.get("coins", {}):
		campaign.add_coin(str(c), int(fx["coins"][c]))
	_effects(campaign, fx.get("metrics", {}))
	if int(fx.get("stamp", 0)) > 0 and not id in map["stamped"]:
		map["stamped"].append(id)
		map["stamps"] = int(map["stamps"]) + int(fx["stamp"])
	if id in map["depots"]:
		campaign.add_coin("supply", 1 + _set_bonus(campaign, "pass_supply"))
	var sign_map: Dictionary = campaign.rules().get("signs", {}).get(str(campaign.state.get("sign", "white")), {}).get("map", {})
	if int(sign_map.get("pass_supply", 0)) > 0:
		campaign.add_coin("supply", int(sign_map["pass_supply"]))
	for r in sheet(campaign).get("rivals", []):
		if rival_active(campaign, r) and rival_pos(campaign, r) == id and int(map["rivals"][str(r["id"])].get("stopped_until", 0)) < int(campaign.state["day"]):
			_meet(campaign, r)
			return
	if bool(node.get("forced", false)) and not id in map["done"] and _today_card(campaign, "ignore_forced") == 0:
		map["pending"] = id
		map["pending_kind"] = "forced"


## 站在自己的兵站上（过夜军需券 +3、征兵便宜 1 金）
static func at_depot(campaign) -> bool:
	return enabled(campaign) and str(campaign.state["map"]["pos"]) in campaign.state["map"]["depots"]


## 凑齐 sets 的兵站另有加成
static func _set_bonus(campaign, key: String) -> int:
	var total := 0
	var depots: Array = campaign.state["map"]["depots"]
	for s in sheet(campaign).get("sets", []):
		var all := true
		for n in s.get("nodes", []):
			all = all and str(n) in depots
		if all:
			total += int(s.get("bonus", {}).get(key, 0))
	return total


static func _effects(campaign, eff) -> void:
	if typeof(eff) != TYPE_DICTIONARY or (eff as Dictionary).is_empty():
		return
	var metrics := {}
	for k in eff:
		if str(k) in ["treasury", "morale", "heat", "vitality", "construction", "exploration"]:
			metrics[k] = int(eff[k])
		elif str(k) in ["gold", "supply", "medal", "intel"]:
			campaign.add_coin(str(k), int(eff[k]))
	if not metrics.is_empty():
		campaign._apply_effects(metrics)


## 进入节点（§7.1）
static func _enter(campaign, args: Dictionary) -> Dictionary:
	if not args.is_empty():
		return _fail("bad_args")
	var map: Dictionary = campaign.state["map"]
	var id := str(map["pos"])
	var node := node_of(sheet(campaign), id)
	if node.is_empty():
		return _fail("bad_args")
	if str(map["pending_kind"]) in ["toll", "rival"]:
		return _fail("battle_pending" if str(map["pending_kind"]) == "rival" else "pending_node")
	var reason := enter_reason(campaign, node)
	if reason != "":
		return {"ok": false, "err": "locked", "reason": reason}
	var kind := node_kind(campaign, node)
	if str(node.get("scene", "")) != "":
		_clear_pending(campaign, id)
		return {"ok": true, "err": "", "kind": "story", "scene": str(node["scene"])}
	if id in map["done"] and bool(node.get("once", kind in ["event", "battle", "elite", "boss"])):
		return _fail("already_used")
	match kind:
		"event":
			var ev_id := str(node.get("event", "")) if str(node.get("type", "")) != "slot" else str(map["slots"][id]["id"])
			if ev_id == "" or campaign.event_def(ev_id).is_empty():
				return _fail("bad_args")
			map["event"] = ev_id
			_clear_pending(campaign, id)
			if not ev_id in campaign.state["run"]["events_seen"]:
				campaign.state["run"]["events_seen"].append(ev_id)
			campaign._use("event:" + ev_id)
			return {"ok": true, "err": "", "kind": "event", "event": ev_id}
		"battle", "elite", "boss":
			if not campaign.battle_idle():
				return _fail("battle_pending")
			map["encounter"] = encounter_for_node(campaign, node)
			if (map["encounter"] as Dictionary).is_empty():
				return _fail("no_battle")
			_clear_pending(campaign, id)
			var res: Dictionary = campaign.prepare_battle()
			if not bool(res.get("ok", false)):
				map["encounter"] = {}
				return res
			return {"ok": true, "err": "", "kind": "battle"}
		"teaser":
			return {"ok": false, "err": "locked", "reason": "volume"}
	_clear_pending(campaign, id)
	if bool(node.get("once", false)) and not id in map["done"]:
		map["done"].append(id)
	return {"ok": true, "err": "", "kind": kind}


static func _clear_pending(campaign, id: String) -> void:
	var map: Dictionary = campaign.state["map"]
	if str(map["pending"]) == id and str(map["pending_kind"]) == "forced":
		map["pending"] = ""
		map["pending_kind"] = ""


## 地图上的一场仗：节点自己的 template / level，或随机槽定下的模板（战斗键 node|段|节点）
static func encounter_for_node(campaign, node: Dictionary) -> Dictionary:
	var seg := str(campaign.state["segment"])
	var id := str(node["id"])
	var kind := node_kind(campaign, node)
	var tpl := node_template(node)
	var level := int(node.get("level", 1))
	if str(node.get("type", "")) == "slot":
		var slot: Dictionary = campaign.state["map"]["slots"].get(id, {})
		tpl = str(slot.get("id", ""))
		level = int(slot.get("level", 1))
	if tpl == "":
		return {}
	return {"key": "node|%s|%s" % [seg, id], "node": id, "template": tpl, "level": level, "kind": kind,
		"weather": (node.get("weather", []) as Array).duplicate(), "reward": (node.get("reward", {}) as Dictionary).duplicate(true), "rival": ""}


## 事件（含插曲）：查验
static func _appraise(campaign, args: Dictionary) -> Dictionary:
	if args.size() != 1 or typeof(args.get("id")) != TYPE_STRING:
		return _fail("bad_args")
	var ev_id := current_event(campaign)
	var ev: Dictionary = campaign.event_def(ev_id)
	if ev.is_empty():
		return _fail("bad_phase")
	for a in ev.get("appraisals", []):
		if str(a.get("id", "")) != str(args["id"]):
			continue
		var key := "event:%s:clue:%s" % [ev_id, args["id"]]
		if campaign._used(key):
			return _fail("already_used")
		campaign._use(key)
		campaign._record("event_appraisal", {"event": ev_id, "id": str(args["id"]), "observation": str(a.get("observation", ""))})
		return {"ok": true, "err": "", "observation": str(a.get("observation", ""))}
	return _fail("bad_args")


static func current_event(campaign) -> String:
	var map: Dictionary = campaign.state["map"]
	if str(map["event"]) != "":
		return str(map["event"])
	return str(map["interlude"])


## 事件的抉择：问答题写 "<题id>:a"；野营夜按种子只给 offer 项
static func event_choices(campaign, ev: Dictionary) -> Array:
	var out: Array = []
	for c in ev.get("choices", []):
		out.append(c)
	for q in ev.get("questions", []):
		for side in ["a", "b"]:
			if typeof(q.get(side)) == TYPE_DICTIONARY:
				var row: Dictionary = (q[side] as Dictionary).duplicate(true)
				row["id"] = "%s:%s" % [q.get("id", ""), side]
				row["question"] = str(q.get("id", ""))
				out.append(row)
	var offer := int(ev.get("offer", 0))
	if offer > 0 and offer < out.size():
		var ids: Array = []
		for c in out:
			ids.append(c)
		var seg := str(campaign.state.get("segment", ""))
		var x := seed_for(int(campaign.state.get("seed", 1)), "interlude|%s|%s|%s" % [seg, campaign.state["map"]["sheet"], ev.get("id", "")])
		if x == 0:
			x = 1
		for i in range(ids.size() - 1, 0, -1):
			x = _xorshift(x)
			var j := x % (i + 1)
			var tmp = ids[i]
			ids[i] = ids[j]
			ids[j] = tmp
		out = ids.slice(0, offer)
	return out


static func choice_error(campaign, ev: Dictionary, c: Dictionary) -> String:
	var ev_id := str(ev.get("id", ""))
	var q := str(c.get("question", ""))
	if q != "":
		if campaign._used("event:%s:%s:a" % [ev_id, q]) or campaign._used("event:%s:%s:b" % [ev_id, q]):
			return "already_used"
	elif _event_done(campaign, ev_id):
		return "already_used"
	for clue in c.get("requires_clues", []):
		if not campaign._used("event:%s:clue:%s" % [ev_id, clue]):
			return "missing_clue"
	for f in c.get("requires_flags", []):
		if not bool(campaign.state["flags"].get(f, false)):
			return "missing_flag"
	if RunConditions.reason(campaign, c.get("requires", {})) != "":
		return "missing_flag"
	if int(campaign.state["metrics"]["treasury"]) + int(c.get("effects", {}).get("treasury", 0)) < 0:
		return "insufficient_funds"
	for coin in c.get("rogue", {}).get("coins", {}):
		if int(campaign.state["rogue"]["coins"].get(coin, 0)) + int(c["rogue"]["coins"][coin]) < 0:
			return "insufficient_funds"
	return ""


static func _event_done(campaign, ev_id: String) -> bool:
	return campaign._used("event:%s:done" % ev_id)


static func _choose(campaign, args: Dictionary) -> Dictionary:
	var pick: Array = []
	if args.size() == 2 and typeof(args.get("pick")) == TYPE_ARRAY and typeof(args.get("choice")) == TYPE_STRING:
		pick = args["pick"]
	elif args.size() != 1 or typeof(args.get("choice")) != TYPE_STRING:
		return _fail("bad_args")
	var map: Dictionary = campaign.state["map"]
	var ev_id := current_event(campaign)
	var ev: Dictionary = campaign.event_def(ev_id)
	if ev.is_empty():
		return _fail("bad_phase")
	var picked: Dictionary = {}
	for c in event_choices(campaign, ev):
		if str(c.get("id", "")) == str(args["choice"]):
			picked = c
	if picked.is_empty():
		return _fail("bad_args")
	var err := choice_error(campaign, ev, picked)
	if err != "":
		return _fail(err)
	var interlude := str(map["event"]) == "" and str(map["interlude"]) == ev_id
	var rogue_err: String = campaign.apply_choice(picked, pick)
	if rogue_err != "":
		return _fail(rogue_err)
	if picked.has("boss_mod"):
		var bm: Dictionary = map["boss_mod"]
		for k in ["cp_bonus", "enemy_morale", "prep_turn"]:
			bm[k] = int(bm.get(k, 0)) + int(picked["boss_mod"].get(k, 0))
	if picked.has("reveal"):
		var rv = picked["reveal"]
		if typeof(rv) == TYPE_INT:
			reveal_around(campaign, int(rv))
		elif typeof(rv) == TYPE_ARRAY:
			for n in rv:
				if not str(n) in map["revealed"]:
					map["revealed"].append(str(n))
	campaign._use("event:%s:%s" % [ev_id, picked["id"]])
	var complete := true
	if not (ev.get("questions", []) as Array).is_empty() and (ev.get("choices", []) as Array).is_empty():
		for q in ev["questions"]:
			if not campaign._used("event:%s:%s:a" % [ev_id, q.get("id", "")]) and not campaign._used("event:%s:%s:b" % [ev_id, q.get("id", "")]):
				complete = false
	campaign._record("event_choice", {"event": ev_id, "choice": str(picked["id"])})
	if complete:
		campaign._use("event:%s:done" % ev_id)
		if interlude:
			map["interlude"] = ""
		else:
			map["event"] = ""
			if not str(map["pos"]) in map["done"]:
				map["done"].append(str(map["pos"]))
	if typeof(picked.get("battle")) == TYPE_DICTIONARY and not interlude:
		var b: Dictionary = picked["battle"]
		map["encounter"] = {"key": "event|%s|%s|%s" % [campaign.state["segment"], ev_id, picked["id"]], "node": str(map["pos"]),
			"template": str(b.get("template", "")), "level": int(b.get("level", 1)), "kind": "battle",
			"weather": (b.get("weather", []) as Array).duplicate(), "reward": {}, "rival": ""}
		var res: Dictionary = campaign.prepare_battle()
		if not bool(res.get("ok", false)):
			return res
	for _d in range(int(picked.get("days", 0))):
		if str(campaign.state["phase"]) != "day":
			break
		campaign._tick_day()
	return _ok()


static func _scout(campaign, args: Dictionary) -> Dictionary:
	if args.size() != 1 or typeof(args.get("node")) != TYPE_STRING:
		return _fail("bad_args")
	var map: Dictionary = campaign.state["map"]
	var id := str(args["node"])
	if node_of(sheet(campaign), id).is_empty():
		return _fail("bad_args")
	if id in map["revealed"]:
		return _fail("already_used")
	if int(campaign.state["rogue"]["coins"].get("intel", 0)) < 1:
		return _fail("insufficient_funds")
	campaign.add_coin("intel", -1)
	map["revealed"].append(id)
	campaign._record("map_scout", {"node": id})
	return _ok()


static func _build(campaign, args: Dictionary) -> Dictionary:
	if not args.is_empty():
		return _fail("bad_args")
	var map: Dictionary = campaign.state["map"]
	var node := node_of(sheet(campaign), str(map["pos"]))
	if not "build_depot" in node_actions(campaign, node):
		return _fail("wrong_node")
	if str(map["pos"]) in map["depots"]:
		return _fail("already_complete")
	if int(campaign.state["rogue"]["coins"].get("gold", 0)) < DEPOT_COST:
		return _fail("insufficient_funds")
	campaign.add_coin("gold", -DEPOT_COST)
	map["depots"].append(str(map["pos"]))
	campaign._record("depot_built", {"node": str(map["pos"])})
	return _ok()


## The legacy "gold" command pays the authored toll, including supplies/intel.
static func toll_error(campaign, toll: Dictionary) -> String:
	if toll.is_empty():
		return "bad_args"
	var coins: Dictionary = campaign.state["rogue"]["coins"]
	for currency in toll:
		if currency not in ["gold", "supply", "medal", "intel"] or typeof(toll[currency]) not in [TYPE_INT, TYPE_FLOAT] or int(toll[currency]) < 0:
			return "bad_args"
	if CompanionRules.reserve_bonus(campaign, "toll_free") > 0:
		return ""
	for currency in toll:
		if int(coins.get(currency, 0)) < int(toll[currency]):
			return "insufficient_funds"
	return ""


## 过路费 / 对手：按标价支付、道具（密使金币袋）或开打
static func _pay(campaign, args: Dictionary) -> Dictionary:
	if args.size() != 1 or typeof(args.get("how")) != TYPE_STRING or not str(args["how"]) in ["gold", "prop", "fight"]:
		return _fail("bad_args")
	var map: Dictionary = campaign.state["map"]
	var kind := str(map["pending_kind"])
	if not kind in ["toll", "rival"]:
		return _fail("bad_phase")
	var how := str(args["how"])
	var rival: Dictionary = {}
	for r in sheet(campaign).get("rivals", []):
		if str(r["id"]) == str(map["meet"]):
			rival = r
	var toll: Dictionary = map["toll"] if kind == "toll" else rival.get("meet", {}).get("toll", {})
	match how:
		"gold":
			var error := toll_error(campaign, toll)
			if error != "":
				return _fail(error)
			if CompanionRules.reserve_bonus(campaign, "toll_free") == 0:
				for currency in toll:
					campaign.add_coin(str(currency), -int(toll[currency]))
		"prop":
			if not "prop_bribe_pouch" in campaign.state["rogue"]["props"]:
				return _fail("missing_item")
			campaign.state["rogue"]["props"].erase("prop_bribe_pouch")
		"fight":
			if kind != "rival" or typeof(rival.get("meet", {}).get("battle")) != TYPE_DICTIONARY:
				return _fail("bad_args")
			var b: Dictionary = rival["meet"]["battle"]
			map["encounter"] = {"key": "rival|%s|%s" % [campaign.state["segment"], rival["id"]], "node": str(map["pos"]),
				"template": str(b.get("template", "")), "level": int(b.get("level", 1)), "kind": "battle",
				"weather": (b.get("weather", []) as Array).duplicate(), "reward": {}, "rival": str(rival["id"])}
			var res: Dictionary = campaign.prepare_battle()
			if not bool(res.get("ok", false)):
				map["encounter"] = {}
				return res
	var at := str(map["pending"])
	map["pending"] = ""
	map["pending_kind"] = ""
	map["toll"] = {}
	if kind == "rival" and how != "fight":
		map["rivals"][str(map["meet"])]["stopped_until"] = int(campaign.state["day"])
	if kind == "rival":
		map["meet"] = ""
	campaign._record("map_pay", {"how": how, "kind": kind})
	if kind == "toll":
		_arrive(campaign, node_of(sheet(campaign), at))
	return _ok()


static func _muster_cmd(campaign, args: Dictionary) -> Dictionary:
	if not args.is_empty():
		return _fail("bad_args")
	var map: Dictionary = campaign.state["map"]
	if bool(map["mustered"]):
		return _fail("already_used")
	var sh := sheet(campaign)
	var node := node_of(sh, str(map["pos"]))
	if str(node.get("role", "")) != "muster" and str(map["pos"]) != pick_node(campaign, sh, "muster"):
		return _fail("wrong_node")
	if not anchors_done(campaign):
		return _fail("scene_order")
	if int(map["stamps"]) < int(sh.get("stamps_need", 0)):
		return _fail("stamps")
	if str(map["pending"]) != "" or not campaign.battle_idle():
		return _fail("battle_pending")
	_muster(campaign, false)
	return _ok()


static func _muster(campaign, forced: bool) -> void:
	var map: Dictionary = campaign.state["map"]
	var days_max := int(sheet(campaign).get("days_max", 0))
	map["mustered"] = true
	map["cp_early"] = clampi(days_max - int(map["days_on_sheet"]), 0, 3)
	campaign._record("map_muster", {"day": int(map["days_on_sheet"]), "forced": forced, "cp_early": int(map["cp_early"])})


# ================================================================ 节点门禁（§5.7）

## 地图模式下营地动作要在提供它的节点上办；不在地图模式返回 ""
static func gate(campaign, action: String) -> String:
	if not enabled(campaign):
		return ""
	var map: Dictionary = campaign.state["map"]
	if str(map["pending"]) != "":
		return "pending_node"
	var node := node_of(sheet(campaign), str(map["pos"]))
	var actions := node_actions(campaign, node)
	if action in actions:
		return ""
	if action.begins_with("recruit:troop:") and "recruit:troop" in actions:
		return ""
	if action.begins_with("demand:"):
		var did := action.trim_prefix("demand:")
		if did in node.get("demands", []):
			return ""
		# book.segments.<段>.demand_nodes：{催逼: ["章:节点", …]}（远洋的催逼写在书里，C13）
		var refs = campaign.book.get("raw", {}).get("segments", {}).get(str(campaign.state.get("segment", "")), {}).get("demand_nodes", {}).get(did, [])
		if typeof(refs) == TYPE_ARRAY and ("%s:%s" % [map["sheet"], map["pos"]]) in refs:
			return ""
	return "wrong_node"


## 剧情的查验和抉择：要站在当前场景的锚点上（本章图上没有这一场的锚点时不拦）
static func story_gate(campaign) -> String:
	if not enabled(campaign):
		return ""
	var anchor := anchor_of(campaign, str(campaign.scene().get("id", "")))
	if anchor == "" or anchor == str(campaign.state["map"]["pos"]):
		return ""
	return "wrong_node"


## 道具在地图上的附加效果（§7.3；原效果照旧由 RogueRules 结算）
static func prop_effect(campaign, prop_id: String) -> void:
	if not enabled(campaign):
		return
	var map: Dictionary = campaign.state["map"]
	match prop_id:
		"prop_forced_march":
			map["mp"] = int(map["mp"]) + 2
		"prop_spyglass":
			reveal_around(campaign, 2)
		"prop_barricade":
			var best := ""
			var best_d := 1 << 30
			var dist := distances(sheet(campaign), str(map["pos"]))
			for r in sheet(campaign).get("rivals", []):
				if rival_active(campaign, r):
					var d := int(dist.get(rival_pos(campaign, r), 999))
					if d < best_d:
						best_d = d
						best = str(r["id"])
			if best != "":
				map["rivals"][best]["stopped_until"] = int(campaign.state["day"]) + 1
		"prop_bribe_pouch":
			map["today"].append("prop_free_toll")
		"prop_smoke_bomb":
			if str(map["pending_kind"]) in ["forced", "rival"]:
				map["pending"] = ""
				map["pending_kind"] = ""
				map["meet"] = ""
		"prop_field_ration":
			map["today"].append("prop_field_ration")


## 一场地图上的仗打完了（结算之后，含大命运处理完）：节点完成、对手被打掉、奖赏
static func battle_settled(campaign, enc: Dictionary, outcome: String) -> void:
	if not enabled(campaign) or enc.is_empty():
		return
	var map: Dictionary = campaign.state["map"]
	var node_id := str(enc.get("node", ""))
	if node_id != "" and str(enc.get("rival", "")) == "" and not str(enc.get("key", "")).begins_with("event|") and not node_id in map["done"]:
		map["done"].append(node_id)
	if str(enc.get("rival", "")) != "" and outcome == "victory":
		var rid := str(enc["rival"])
		map["rivals"][rid]["beaten"] = true
		for r in sheet(campaign).get("rivals", []):
			if str(r["id"]) == rid:
				map["boss_waves_minus"] = int(map["boss_waves_minus"]) + int(r.get("boss_waves_minus", 0))
	if outcome == "victory":
		var reward: Dictionary = enc.get("reward", {})
		for c in reward.get("coins", {}):
			campaign.add_coin(str(c), int(reward["coins"][c]))
		for p in reward.get("props", []):
			if not str(p) in campaign.state["rogue"]["props"]:
				campaign.state["rogue"]["props"].append(str(p))
	map["encounter"] = {}


## 这一场仗要不要 Boss 修正：本章 Boss 节点（军议 boss_mod、拖延、打掉的对手）；开拔后第一仗另记早到奖励 _cp_early
static func battle_mods(campaign, node_id: String, tpl_id: String) -> Dictionary:
	var mods := {}
	if not enabled(campaign):
		return mods
	var map: Dictionary = campaign.state["map"]
	var sh := sheet(campaign)
	if node_id != "" and node_id in node_list(sh, "boss"):
		var bm: Dictionary = map["boss_mod"]
		if int(bm.get("cp_bonus", 0)) != 0:
			mods["cp_bonus"] = int(bm["cp_bonus"])
		var em := int(bm.get("enemy_morale", 0)) + mini(8, 2 * int(map["delay"]))
		if em != 0:
			mods["enemy_morale"] = em
		if int(bm.get("prep_turn", 0)) != 0:
			mods["prep_turn"] = int(bm["prep_turn"])
		var minus := int(map["boss_waves_minus"])
		if minus > 0:
			var waves: Array = BattleApi.template(tpl_id).get("waves", [])
			var drop: Array = []
			for i in range(maxi(0, waves.size() - minus), waves.size()):
				drop.append(i)
			mods["drop_waves"] = drop
	if bool(map["mustered"]) and int(map["cp_early"]) > 0:
		var node := node_of(sh, node_id)
		if str(node.get("phase", "accumulate")) == "campaign":
			# 早到奖励算开场军令点（开战时并进 setup.cp_bonus，和军需券折的一起），不算 Boss 修正
			mods["_cp_early"] = int(map["cp_early"])
	return mods


# ================================================================ 存档校验

static func valid(bundle: Dictionary, seg: String, map) -> bool:
	if typeof(map) != TYPE_DICTIONARY:
		return false
	if (map as Dictionary).is_empty():
		return true
	for k in STATE_KEYS:
		if not map.has(k):
			return false
	if map.size() != STATE_KEYS.size():
		return false
	var sh := sheet_of(bundle, seg, str(map.get("sheet", "")))
	if sh.is_empty():
		return false
	var ids := {}
	for id in node_ids(sh):
		ids[id] = true
	for k in ["pos"]:
		if typeof(map[k]) != TYPE_STRING or not ids.has(str(map[k])):
			return false
	if typeof(map["pending"]) != TYPE_STRING or (str(map["pending"]) != "" and not ids.has(str(map["pending"]))):
		return false
	if not str(map["pending_kind"]) in ["", "forced", "toll", "rival"]:
		return false
	for k in ["mp", "rolls", "stamps", "days_on_sheet", "delay", "cp_early", "boss_waves_minus"]:
		if typeof(map[k]) != TYPE_INT or int(map[k]) < 0:
			return false
	for k in ["rolled_today", "moved_today", "mustered"]:
		if typeof(map[k]) != TYPE_BOOL:
			return false
	for k in ["deck", "hand", "discard", "today", "routes_taken"]:
		if typeof(map[k]) != TYPE_ARRAY:
			return false
	for k in ["visited", "done", "revealed", "stamped", "depots"]:
		if typeof(map[k]) != TYPE_ARRAY:
			return false
		for id in map[k]:
			if typeof(id) != TYPE_STRING or not ids.has(str(id)):
				return false
	for k in ["slots", "rivals", "boss_mod", "toll", "encounter"]:
		if typeof(map[k]) != TYPE_DICTIONARY:
			return false
	for id in map["slots"]:
		var row = map["slots"][id]
		if not ids.has(str(id)) or typeof(row) != TYPE_DICTIONARY or not str(row.get("kind", "")) in SLOT_KINDS or typeof(row.get("level")) != TYPE_INT:
			return false
	for id in map["rivals"]:
		var row = map["rivals"][id]
		if typeof(row) != TYPE_DICTIONARY or typeof(row.get("step")) != TYPE_INT or typeof(row.get("beaten")) != TYPE_BOOL or typeof(row.get("stopped_until")) != TYPE_INT:
			return false
	for k in ["event", "interlude", "meet", "id", "sheet"]:
		if typeof(map[k]) != TYPE_STRING:
			return false
	return (map["hand"] as Array).size() <= HAND_MAX


static func _ok() -> Dictionary:
	return {"ok": true, "err": ""}


static func _fail(err: String) -> Dictionary:
	return {"ok": false, "err": err}
