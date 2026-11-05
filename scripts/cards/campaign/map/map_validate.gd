## 地图校验（WORLD_MAP_DESIGN §7.2 的 R1–R12；R6 和 §8.2 的跨章部分在 run_book.gd）。
## validate(bundle, 段) → {errors, warnings}。没有 class_name，别处 preload。只读数据，不碰状态。
extends RefCounted

const MapRules = preload("res://scripts/cards/campaign/map/map_rules.gd")
const RunConditions = preload("res://scripts/cards/campaign/run/run_conditions.gd")
const BattleApi = preload("res://scripts/cards/campaign/run/run_battle_api.gd")

const SCREEN := Vector2i(1280, 720)
const MIN_GAP := 40
const WARN_GAP := 52
const MP_PER_DAY := 3
const SCALE_TYPE := {"skirmish": "battle", "elite": "elite", "major": "boss", "grand": "boss", "epic": "boss"}

static var _geo_views: Dictionary = {}


static func sheet_of(bundle: Dictionary, seg: String, chapter_id: String) -> Dictionary:
	return MapRules.sheet_of(bundle, seg, chapter_id)


static func validate(bundle: Dictionary, seg: String) -> Dictionary:
	var errors: Array = []
	var warnings: Array = []
	var map: Dictionary = MapRules.map_of(bundle, seg)
	var def: Dictionary = bundle.get("defs", {}).get(seg, {})
	if typeof(map.get("sheets")) != TYPE_ARRAY or typeof(map.get("views", {})) != TYPE_DICTIONARY:
		errors.append("map %s: sheets/views" % seg)
		return {"errors": errors, "warnings": warnings}
	var chapters := {}
	for c in def.get("chapters", []):
		chapters[str(c.get("id", ""))] = c
	var offset := int(bundle.get("raw", {}).get("branches", {}).get(seg, {}).get("level_offset", 0))
	for sheet in map["sheets"]:
		var ch := str(sheet.get("chapter", ""))
		var at := "%s:%s" % [seg, ch]
		if not chapters.has(ch):
			errors.append("%s: sheet for unknown chapter" % at)
			continue
		if not (map["views"] as Dictionary).has(str(sheet.get("view", ""))):
			errors.append("%s: unknown view %s" % [at, sheet.get("view", "")])
		var shape := _check_shape(bundle, seg, sheet, at)
		errors.append_array(shape)
		if not shape.is_empty():
			continue
		var volume_open := int(chapters[ch].get("volume", 1)) <= int(bundle.get("volume", 1))
		_r1(sheet, at, errors)
		_r2(bundle, seg, sheet, at, offset, errors)
		_r3(bundle, seg, sheet, at, errors)
		_r4(sheet, at, errors)
		if int(bundle.get("volume", 1)) >= 2:
			for route in campaign_routes(sheet, def):
				_r5(route["sheet"], at + str(route["suffix"]), errors)
		else:
			_r5(sheet, at, errors)
		_r7(sheet, def, chapters[ch], at, errors, warnings)
		_r8(bundle, seg, sheet, def, chapters[ch], at, offset, errors)
		_r9(sheet, at, errors)
		_r10(bundle, seg, sheet, at, volume_open, errors)
		_r11(bundle, seg, sheet, def, chapters[ch], at, errors)
		_r12(bundle, seg, sheet, map["views"].get(str(sheet.get("view", "")), {}), at, errors, warnings)
	return {"errors": errors, "warnings": warnings}


static func _check_shape(bundle: Dictionary, seg: String, sheet: Dictionary, at: String) -> Array:
	var errors: Array = []
	var ids := {}
	for n in sheet.get("nodes", []):
		var id := str(n.get("id", ""))
		if id.is_empty() or ids.has(id):
			errors.append("%s: node id %s missing or duplicated" % [at, id])
		ids[id] = true
		if not str(n.get("type", "")) in MapRules.TYPES:
			errors.append("%s: node %s type %s" % [at, id, n.get("type", "")])
		if not str(n.get("role", "")) in MapRules.ROLES:
			errors.append("%s: node %s role %s" % [at, id, n.get("role", "")])
		if not n.has("xy") and not n.has("geo"):
			errors.append("%s: node %s has no xy/geo" % [at, id])
		if not str(n.get("fog", "open")) in ["open", "type", "hidden"]:
			errors.append("%s: node %s fog" % [at, id])
		if not str(n.get("phase", "accumulate")) in ["accumulate", "campaign"]:
			errors.append("%s: node %s phase" % [at, id])
		var e := RunConditions.check(n.get("requires", {}))
		if e != "":
			errors.append("%s: node %s requires %s" % [at, id, e])
		if str(n.get("type", "")) == "event" and str(n.get("event", "")) != "" and not _event_exists(bundle, str(n["event"])):
			errors.append("%s: node %s unknown event %s" % [at, id, n["event"]])
		if str(n.get("type", "")) == "slot" and typeof(n.get("slot")) != TYPE_DICTIONARY:
			errors.append("%s: slot node %s has no slot" % [at, id])
	for l in sheet.get("links", []):
		if not ids.has(str(l.get("a", ""))) or not ids.has(str(l.get("b", ""))):
			errors.append("%s: link %s-%s to unknown node" % [at, l.get("a", ""), l.get("b", "")])
		var legs := int(l.get("legs", 1))
		if int(l.get("voyage_days", 0)) == 0 and (legs < 1 or legs > 4):
			errors.append("%s: link %s-%s legs %d" % [at, l.get("a", ""), l.get("b", ""), legs])
	for key in ["start"]:
		if not ids.has(str(sheet.get(key, ""))):
			errors.append("%s: %s node %s" % [at, key, sheet.get(key, "")])
	for key in ["boss", "muster"]:
		for id in MapRules.node_list(sheet, key):
			if not ids.has(str(id)):
				errors.append("%s: %s node %s" % [at, key, id])
	if MapRules.node_list(sheet, "boss").is_empty():
		errors.append("%s: no boss" % at)
	return errors


static func _event_exists(bundle: Dictionary, id: String) -> bool:
	for seg in bundle.get("events", {}):
		for ev in bundle["events"][seg]:
			if str(ev.get("id", "")) == id:
				return true
	for ev in bundle.get("events_common", []):
		if str(ev.get("id", "")) == id:
			return true
	return false


static func _ids_of(sheet: Dictionary, pred: Callable) -> Dictionary:
	var out := {}
	for n in sheet.get("nodes", []):
		if pred.call(n):
			out[str(n["id"])] = true
	return out


## R1：起点到 Boss 的每条路上至少一个 camp、至少一个 supply 或 shop（去掉它们以后到不了 Boss）
static func _r1(sheet: Dictionary, at: String, errors: Array) -> void:
	var start := str(sheet.get("start", ""))
	for boss in MapRules.node_list(sheet, "boss"):
		var no_camp := _ids_of(sheet, func(n): return str(n.get("type", "")) == "camp")
		if MapRules.distances(sheet, start, true, no_camp).has(str(boss)):
			errors.append("R1: %s: a path to boss %s avoids every camp" % [at, boss])
		var no_supply := _ids_of(sheet, func(n): return str(n.get("type", "")) in ["supply", "shop"])
		if MapRules.distances(sheet, start, true, no_supply).has(str(boss)):
			errors.append("R1: %s: a path to boss %s avoids every supply/shop" % [at, boss])


## R2：战斗类节点之间不相邻（rush 连线除外）
static func _r2(bundle: Dictionary, seg: String, sheet: Dictionary, at: String, offset: int, errors: Array) -> void:
	var battle := {}
	for n in sheet.get("nodes", []):
		if MapRules.is_battle_node(bundle, seg, n, offset):
			battle[str(n["id"])] = true
	for l in sheet.get("links", []):
		if bool(l.get("rush", false)):
			continue
		if battle.has(str(l.get("a", ""))) and battle.has(str(l.get("b", ""))):
			errors.append("R2: %s: battle nodes %s and %s are adjacent" % [at, l["a"], l["b"]])


## R3：随机槽 ≥ 30% 节点，期望事件数 ≥ 3（教学章免检）
static func _r3(bundle: Dictionary, seg: String, sheet: Dictionary, at: String, errors: Array) -> void:
	if bool(sheet.get("tutorial", false)):
		return
	var nodes: Array = sheet.get("nodes", [])
	var slots := 0
	var expect_x100 := 0
	var counted := 0
	for n in nodes:
		var t := str(n.get("type", ""))
		if t == "teaser":
			continue
		counted += 1
		if t == "slot":
			slots += 1
			var kinds: Dictionary = n.get("slot", {}).get("kinds", {})
			var total := 0
			for k in kinds:
				total += int(kinds[k])
			if total > 0:
				expect_x100 += 100 * int(kinds.get("event", 0)) / total
		elif t == "event" and str(n.get("role", "")) != "council":
			expect_x100 += 100
	if slots * 100 < counted * 30:
		errors.append("R3: %s: %d slots of %d nodes (< 30%%)" % [at, slots, counted])
	if expect_x100 < 300:
		errors.append("R3: %s: expected events %d.%02d (< 3)" % [at, expect_x100 / 100, expect_x100 % 100])


## R4：每个精英都能绕开（去掉它，本章所有锚点和 Boss 仍然到得了）
static func _r4(sheet: Dictionary, at: String, errors: Array) -> void:
	var start := str(sheet.get("start", ""))
	var targets: Array = MapRules.node_list(sheet, "boss")
	for n in sheet.get("nodes", []):
		if str(n.get("scene", "")) != "":
			targets.append(str(n["id"]))
	for n in sheet.get("nodes", []):
		if str(n.get("type", "")) != "elite" or str(n.get("scene", "")) != "":
			continue
		var dist := MapRules.distances(sheet, start, true, {str(n["id"]): true})
		for t in targets:
			if not dist.has(str(t)) and str(t) != str(n["id"]):
				errors.append("R4: %s: elite %s cannot be bypassed (cuts off %s)" % [at, n["id"], t])
				break


## R5：战役段 muster → 军议（唯一）→ [精英] → 野营夜（唯一）→ Boss；去掉军议或野营夜就到不了 Boss；战役段不连回积累段；muster 是积累段
## 二选一战区按段定义声明的互斥旗标分别检查；不能把两个有效军议错算为同一条路线的重复军议。
static func campaign_routes(sheet: Dictionary, definition: Dictionary) -> Array:
	var used := {}
	for node in sheet.get("nodes", []):
		if str(node.get("phase", "accumulate")) == "campaign":
			for flag in node.get("requires", {}).get("flags", []):
				used[str(flag)] = true
	var selections: Array = [{"chosen": [], "excluded": []}]
	for group in definition.get("rules", {}).get("exclusive_flags", []):
		var relevant: Array = []
		for flag in group:
			if used.has(str(flag)):
				relevant.append(str(flag))
		if relevant.size() < 2:
			continue
		var next: Array = []
		for previous in selections:
			for choice in relevant:
				var pick: Dictionary = previous.duplicate(true)
				pick["chosen"].append(choice)
				for other in group:
					if str(other) != choice:
						pick["excluded"].append(str(other))
				next.append(pick)
		selections = next
	var out: Array = []
	for selection in selections:
		var projected: Dictionary = sheet.duplicate(true)
		var allowed := {}
		projected["nodes"] = []
		for node in sheet.get("nodes", []):
			if _route_condition(node.get("requires", {}), selection):
				projected["nodes"].append(node.duplicate(true))
				allowed[str(node["id"])] = true
		projected["links"] = []
		for link in sheet.get("links", []):
			if allowed.has(str(link["a"])) and allowed.has(str(link["b"])) and _route_condition(link.get("requires", {}), selection):
				projected["links"].append(link.duplicate(true))
		for field in ["boss", "muster"]:
			projected[field] = MapRules.node_list(sheet, field).filter(func(id): return allowed.has(str(id)))
		var names := PackedStringArray(selection["chosen"])
		out.append({"sheet": projected, "suffix": "[" + ",".join(names) + "]" if not names.is_empty() else ""})
	return out


## Only resolve the mutually exclusive theatre flags; unrelated conditions stay possible.
static func _route_condition(condition: Dictionary, selection: Dictionary) -> bool:
	for flag in condition.get("flags", []):
		if str(flag) in selection["excluded"]:
			return false
	for flag in condition.get("not_flags", []):
		if str(flag) in selection["chosen"]:
			return false
	for part in condition.get("all", []):
		if not _route_condition(part, selection):
			return false
	if condition.has("any"):
		var any := false
		for part in condition["any"]:
			any = any or _route_condition(part, selection)
		if not any:
			return false
	return true


static func _r5(sheet: Dictionary, at: String, errors: Array) -> void:
	var camp_nodes := _ids_of(sheet, func(n): return str(n.get("phase", "accumulate")) == "campaign")
	if camp_nodes.is_empty():
		return
	var musters: Array = MapRules.node_list(sheet, "muster")
	if musters.is_empty():
		errors.append("R5: %s: campaign nodes but no muster" % at)
		return
	for m in musters:
		if camp_nodes.has(str(m)):
			errors.append("R5: %s: muster %s must be an accumulate node" % [at, m])
	var councils: Array = []
	var camps: Array = []
	for n in sheet.get("nodes", []):
		if not camp_nodes.has(str(n["id"])):
			continue
		if str(n.get("role", "")) == "council":
			councils.append(str(n["id"]))
		if str(n.get("type", "")) == "camp":
			camps.append(str(n["id"]))
	if councils.size() != 1:
		errors.append("R5: %s: %d councils in the campaign phase (need 1)" % [at, councils.size()])
	if camps.size() != 1:
		errors.append("R5: %s: %d camps in the campaign phase (need 1)" % [at, camps.size()])
	for l in sheet.get("links", []):
		var a := str(l.get("a", ""))
		var b := str(l.get("b", ""))
		if camp_nodes.has(a) != camp_nodes.has(b) and not a in musters and not b in musters:
			errors.append("R5: %s: campaign node linked back to accumulate (%s-%s)" % [at, a, b])
	for m in musters:
		for boss in MapRules.node_list(sheet, "boss"):
			if not camp_nodes.has(str(boss)):
				continue
			for gate in councils + camps:
				var skip := {str(gate): true}
				for n in sheet.get("nodes", []):
					if not camp_nodes.has(str(n["id"])) and str(n["id"]) != str(m):
						skip[str(n["id"])] = true
				if MapRules.distances(sheet, str(m), true, skip).has(str(boss)):
					errors.append("R5: %s: boss %s reachable from muster %s without %s" % [at, boss, m, gate])


## 最短路（按 legs；航程连线按天，记在 voyage 里）：{cost, path}
static func _shortest(sheet: Dictionary, from: String, to: String) -> Dictionary:
	var best := {from: 0}
	var prev := {}
	var frontier: Array = [from]
	while not frontier.is_empty():
		frontier.sort_custom(func(x, y): return int(best[x]) < int(best[y]))
		var cur: String = frontier.pop_front()
		if cur == to:
			break
		for l in sheet.get("links", []):
			var nb := ""
			if str(l.get("a", "")) == cur:
				nb = str(l.get("b", ""))
			elif str(l.get("b", "")) == cur and not bool(l.get("oneway", false)):
				nb = str(l.get("a", ""))
			if nb == "":
				continue
			var w := int(l.get("voyage_days", 0)) * MP_PER_DAY if int(l.get("voyage_days", 0)) > 0 else int(l.get("legs", 1))
			var c := int(best[cur]) + w
			if not best.has(nb) or c < int(best[nb]):
				best[nb] = c
				prev[nb] = cur
				if not nb in frontier:
					frontier.append(nb)
	if not best.has(to):
		return {"cost": -1, "path": []}
	var path: Array = [to]
	while path[0] != from:
		path.push_front(prev[path[0]])
	return {"cost": int(best[to]), "path": path}


## R7：days_max ≥ 最短天数 + 3（多出 9 天以上提醒）。最短：依次走过积累段锚点、凑够驿站印、到 muster；每场锚点算一天
static func _r7(sheet: Dictionary, def: Dictionary, chapter: Dictionary, at: String, errors: Array, warnings: Array) -> void:
	var anchors: Array = []
	for scene_id in chapter.get("scene_ids", []):
		for n in sheet.get("nodes", []):
			if str(n.get("scene", "")) == str(scene_id) and str(n.get("phase", "accumulate")) != "campaign":
				anchors.append(str(n["id"]))
	var musters: Array = MapRules.node_list(sheet, "muster")
	var waypoints: Array = [str(sheet.get("start", ""))] + anchors
	if not musters.is_empty():
		waypoints.append(str(musters[0]))
	var mp := 0
	var visited := {}
	for i in range(1, waypoints.size()):
		var sp := _shortest(sheet, str(waypoints[i - 1]), str(waypoints[i]))
		if int(sp["cost"]) < 0:
			errors.append("R7: %s: %s unreachable from %s" % [at, waypoints[i], waypoints[i - 1]])
			return
		mp += int(sp["cost"])
		for id in sp["path"]:
			visited[str(id)] = true
	var stamps := 0
	var posts: Array = []
	for n in sheet.get("nodes", []):
		if int(n.get("pass", {}).get("stamp", 0)) > 0:
			if visited.has(str(n["id"])):
				stamps += int(n["pass"]["stamp"])
			else:
				posts.append(str(n["id"]))
	var need := int(sheet.get("stamps_need", 0))
	var base := str(musters[0]) if not musters.is_empty() else str(sheet.get("start", ""))
	var detours: Array = []
	for p in posts:
		detours.append(2 * maxi(0, int(_shortest(sheet, base, p)["cost"])))
	detours.sort()
	var di := 0
	while stamps < need and di < detours.size():
		mp += int(detours[di])
		stamps += 1
		di += 1
	if stamps < need:
		errors.append("R7: %s: only %d stamps reachable (need %d)" % [at, stamps, need])
	var min_days := (mp + MP_PER_DAY - 1) / MP_PER_DAY + anchors.size()
	var days_max := int(sheet.get("days_max", 0))
	if days_max < min_days + 3:
		errors.append("R7: %s: days_max %d < shortest %d + 3" % [at, days_max, min_days])
	elif days_max > min_days + 9:
		warnings.append("R7: %s: days_max %d is more than shortest %d + 9" % [at, days_max, min_days])


## R8：每场恰好一个锚点、按 scene_ids 的顺序（积累段的锚点都在战役段之前）；Boss 带本章最后一场带仗的场景；锚点类型合战斗规模
static func _r8(bundle: Dictionary, seg: String, sheet: Dictionary, def: Dictionary, chapter: Dictionary, at: String, offset: int, errors: Array) -> void:
	var scene_ids: Array = chapter.get("scene_ids", [])
	var anchor := {}
	for n in sheet.get("nodes", []):
		var s := str(n.get("scene", ""))
		if s == "":
			continue
		if not s in scene_ids:
			errors.append("R8: %s: node %s anchors scene %s of another chapter" % [at, n["id"], s])
		elif anchor.has(s):
			errors.append("R8: %s: scene %s has two anchors" % [at, s])
		anchor[s] = n
	var seen_campaign := false
	var last_battle := ""
	for s in scene_ids:
		if not anchor.has(str(s)):
			errors.append("R8: %s: scene %s has no anchor" % [at, s])
			continue
		var n: Dictionary = anchor[str(s)]
		var phase := str(n.get("phase", "accumulate"))
		if phase == "campaign":
			seen_campaign = true
		elif seen_campaign:
			errors.append("R8: %s: accumulate anchor %s after a campaign anchor" % [at, n["id"]])
		var sb := MapRules.scene_battle(bundle, seg, str(s), offset)
		var t := str(n.get("type", ""))
		if sb.is_empty():
			if t in MapRules.BATTLE_TYPES:
				errors.append("R8: %s: anchor %s is %s but scene %s has no battle" % [at, n["id"], t, s])
		else:
			var scale := str(BattleApi.template(str(sb["template"])).get("scale", ""))
			if scale != "" and t != str(SCALE_TYPE.get(scale, t)) and not (t == "boss" and scale in ["major", "grand", "epic", "elite"]):
				errors.append("R8: %s: anchor %s type %s does not match %s scale %s" % [at, n["id"], t, sb["template"], scale])
			if not _scene_has_when(def, str(s)):
				last_battle = str(s)
	for boss in MapRules.node_list(sheet, "boss"):
		var bn := MapRules.node_of(sheet, str(boss))
		var bs := str(bn.get("scene", ""))
		if bs == "":
			continue
		if MapRules.scene_battle(bundle, seg, bs, offset).is_empty():
			errors.append("R8: %s: boss %s scene %s has no battle" % [at, boss, bs])
		elif not _scene_has_when(def, bs) and last_battle != "" and bs != last_battle:
			errors.append("R8: %s: boss %s carries %s but the last battle scene is %s" % [at, boss, bs, last_battle])


static func _scene_has_when(def: Dictionary, scene_id: String) -> bool:
	for s in def.get("scenes", []):
		if str(s.get("id", "")) == scene_id:
			return not (s.get("when", {}) as Dictionary).is_empty()
	return false


## R9：每个节点从起点到得了（不看条件）；对手只走真实存在的连线
static func _r9(sheet: Dictionary, at: String, errors: Array) -> void:
	var dist := MapRules.distances(sheet, str(sheet.get("start", "")), true)
	for n in sheet.get("nodes", []):
		if not dist.has(str(n["id"])):
			errors.append("R9: %s: node %s unreachable from start" % [at, n["id"]])
	for r in sheet.get("rivals", []):
		var path: Array = r.get("path", [])
		for i in path.size():
			var a := str(path[i])
			var b := str(path[(i + 1) % path.size()])
			if a != b and MapRules.link_between(sheet, a, b).is_empty() and MapRules.link_between(sheet, b, a).is_empty():
				errors.append("R9: %s: rival %s walks %s-%s without a link" % [at, r.get("id", ""), a, b])


## R10：地图上用到的模板都在库里；不在的要列进 templates_needed，并且那个节点属于第二卷（requires volume 2）
static func _r10(bundle: Dictionary, seg: String, sheet: Dictionary, at: String, volume_open: bool, errors: Array) -> void:
	var lib: Dictionary = BattleApi.lib().get("templates", {})
	var needed: Array = sheet.get("templates_needed", [])
	for n in sheet.get("nodes", []):
		var tpl := str(n.get("template", ""))
		if tpl == "" or lib.has(tpl) or lib.has(str(n.get("fallback", ""))):
			continue
		var vol2 := int(n.get("requires", {}).get("volume", 1)) > int(bundle.get("volume", 1)) or not volume_open
		if not tpl in needed or not vol2:
			errors.append("R10: %s: node %s template %s is missing" % [at, n["id"], tpl])
	for r in sheet.get("rivals", []):
		var b = r.get("meet", {}).get("battle")
		if typeof(b) == TYPE_DICTIONARY and not lib.has(str(b.get("template", ""))):
			errors.append("R10: %s: rival %s template %s is missing" % [at, r.get("id", ""), b.get("template", "")])
	var pools: Dictionary = bundle.get("raw", {}).get("battle_pool", {}).get(seg, {})
	for n in sheet.get("nodes", []):
		if str(n.get("type", "")) != "slot" or int(n.get("slot", {}).get("kinds", {}).get("battle", 0)) <= 0:
			continue
		var lv := int(n["slot"].get("level", 0))
		var hit := false
		for band in pools:
			var lo := int(str(band).get_slice("-", 0))
			var hi := int(str(band).get_slice("-", 1)) if str(band).contains("-") else lo
			if lv >= lo and lv <= hi:
				hit = true
				for tpl in pools[band]:
					if not lib.has(str(tpl)):
						errors.append("R10: %s: battle_pool %s template %s is missing" % [at, band, tpl])
		if not hit:
			errors.append("R10: %s: slot %s level %d has no battle_pool band" % [at, n["id"], lv])


## R11：每个催逼的交付节点都能在期限内从发出它的那一场走到（每天 3 MP）
static func _r11(bundle: Dictionary, seg: String, sheet: Dictionary, def: Dictionary, chapter: Dictionary, at: String, errors: Array) -> void:
	var RunOceanRules = load("res://scripts/cards/campaign/run/run_ocean_rules.gd")
	var spec_nodes: Dictionary = bundle.get("raw", {}).get("segments", {}).get(seg, {}).get("demand_nodes", {})
	for s in def.get("scenes", []):
		if str(s.get("chapter", "")) != str(chapter.get("id", "")):
			continue
		for d in RunOceanRules.scene_demands(def, s):
			var did := str(d.get("id", ""))
			var targets: Array = []
			for n in sheet.get("nodes", []):
				if did in n.get("demands", []):
					targets.append(str(n["id"]))
			for ref in spec_nodes.get(did, []):
				if str(ref).get_slice(":", 0) == str(chapter["id"]):
					targets.append(str(ref).get_slice(":", 1))
			if targets.is_empty():
				continue
			var from := ""
			for n in sheet.get("nodes", []):
				if str(n.get("scene", "")) == str(s["id"]):
					from = str(n["id"])
			if from == "":
				continue
			var ok := false
			for tgt in targets:
				var sp := _shortest(sheet, from, str(tgt))
				ok = ok or (int(sp["cost"]) >= 0 and int(sp["cost"]) <= int(d.get("due_in", 0)) * MP_PER_DAY)
			if not ok:
				errors.append("R11: %s: demand %s cannot reach %s within %d days" % [at, did, targets, d.get("due_in", 0)])


## R12：每个镜头窗里节点标记在屏幕上的间距 ≥ 40 px（< 52 提醒）。没写 frames 时框住全部节点；世界图默认放大 2 倍
static func _r12(bundle: Dictionary, seg: String, sheet: Dictionary, view: Dictionary, at: String, errors: Array, warnings: Array) -> void:
	var pts := {}
	for n in sheet.get("nodes", []):
		var p := _project(view, n)
		if p.x >= 0.0:
			var off = n.get("offset", [0, 0])
			if typeof(off) == TYPE_ARRAY and (off as Array).size() == 2:
				p += Vector2(float(off[0]), float(off[1]))
			pts[str(n["id"])] = p
	if pts.size() < 2:
		return
	var frames: Array = sheet.get("frames", [])
	if frames.is_empty():
		var lo := Vector2(1e9, 1e9)
		var hi := Vector2(-1e9, -1e9)
		for id in pts:
			lo = Vector2(minf(lo.x, pts[id].x), minf(lo.y, pts[id].y))
			hi = Vector2(maxf(hi.x, pts[id].x), maxf(hi.y, pts[id].y))
		var span := (hi - lo) + Vector2(120.0, 120.0)
		var s := minf(float(SCREEN.x) / span.x, float(SCREEN.y) / span.y)
		if str(view.get("proj", "")) == "miller":
			s *= 2.0
		_gaps(pts, pts.keys(), s, "%s (fit)" % at, errors, warnings)
		return
	var size := _canvas_size(view)
	for f in frames:
		var zoom := float(int(f.get("zoom", 100))) / 100.0
		var s := minf(float(SCREEN.x) / size.x, float(SCREEN.y) / size.y) * zoom
		var c := _project(view, {"xy": f.get("center")}) if str(view.get("proj", "canvas")) == "canvas" else _project(view, {"geo": f.get("center")})
		var half := Vector2(float(SCREEN.x), float(SCREEN.y)) / (2.0 * s)
		var inside: Array = []
		for id in pts:
			var d: Vector2 = pts[id] - c
			if absf(d.x) <= half.x and absf(d.y) <= half.y:
				inside.append(id)
		_gaps(pts, inside, s, "%s frame %s" % [at, f.get("id", "")], errors, warnings)


static func _gaps(pts: Dictionary, ids: Array, s: float, at: String, errors: Array, warnings: Array) -> void:
	ids.sort()
	for i in ids.size():
		for j in range(i + 1, ids.size()):
			var d: float = (pts[ids[i]] - pts[ids[j]]).length() * s
			if d < float(MIN_GAP):
				errors.append("R12: %s: %s and %s are %d px apart on screen" % [at, ids[i], ids[j], int(d)])
			elif d < float(WARN_GAP):
				warnings.append("R12: %s: %s and %s are %d px apart" % [at, ids[i], ids[j], int(d)])


static func _canvas_size(view: Dictionary) -> Vector2:
	if str(view.get("proj", "canvas")) == "canvas":
		var sz = view.get("size", [1920, 1080])
		return Vector2(float(sz[0]), float(sz[1]))
	var gv := _geo_view(str(view.get("base", "")))
	return Vector2(float(gv.get("width", 1920)), float(gv.get("height", 1080)))


## 节点在画布上的位置（xy 优先；geo 按底图 view 的公式投影）；算不出返回 (-1, -1)
static func _project(view: Dictionary, n: Dictionary) -> Vector2:
	if typeof(n.get("xy")) == TYPE_ARRAY and (n["xy"] as Array).size() == 2:
		return Vector2(float(n["xy"][0]), float(n["xy"][1]))
	if typeof(n.get("geo")) != TYPE_ARRAY or (n["geo"] as Array).size() != 2:
		return Vector2(-1.0, -1.0)
	var gv := _geo_view(str(view.get("base", "")))
	if gv.is_empty():
		return Vector2(-1.0, -1.0)
	var lon := float(n["geo"][0]) / 100.0
	var lat := float(n["geo"][1]) / 100.0
	var scale := float(gv.get("scale", 1.0))
	var x := scale * (deg_to_rad(lon) - deg_to_rad(float(gv.get("lon_min", 0.0))))
	var y := 0.0
	if str(gv.get("projection", "")) == "miller":
		y = scale * (float(gv.get("y_top", 0.0)) - 1.25 * log(tan(PI / 4.0 + 0.4 * deg_to_rad(lat))))
	else:
		y = scale * (float(gv.get("y_top", 0.0)) - log(tan(PI / 4.0 + deg_to_rad(lat) / 2.0)))
	return Vector2(x, y)


static func _geo_view(base: String) -> Dictionary:
	if base == "":
		return {}
	if not _geo_views.has(base):
		var path := "res://data/campaigns/napoleon/maps/geo/%s.json" % base
		var v := {}
		if FileAccess.file_exists(path):
			var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
			if typeof(parsed) == TYPE_DICTIONARY and typeof(parsed.get("view")) == TYPE_DICTIONARY:
				v = parsed["view"]
		_geo_views[base] = v
	return _geo_views[base]


## 一章的仗（§8.2 用）：{boss:{at, template, level}, elites:[…], battles:[…]}；没有图返回 {}
static func chapter_battles(bundle: Dictionary, seg: String, chapter_id: String, offset: int) -> Dictionary:
	var sheet := MapRules.sheet_of(bundle, seg, chapter_id)
	if sheet.is_empty():
		return {}
	var out := {"boss": {}, "elites": [], "battles": []}
	var bosses: Array = MapRules.node_list(sheet, "boss")
	for n in sheet.get("nodes", []):
		var id := str(n["id"])
		var t := str(n.get("type", ""))
		var row := {}
		if str(n.get("scene", "")) != "":
			var sb := MapRules.scene_battle(bundle, seg, str(n["scene"]), offset)
			if not sb.is_empty():
				row = {"at": id, "template": str(sb["template"]), "level": int(sb["level"])}
		elif t in MapRules.BATTLE_TYPES:
			row = {"at": id, "template": MapRules.node_template(n), "level": int(n.get("level", 1))}
		elif t == "slot" and int(n.get("slot", {}).get("kinds", {}).get("battle", 0)) > 0:
			out["battles"].append({"at": id, "template": "", "level": int(n["slot"].get("level", 0))})
			continue
		if row.is_empty():
			continue
		if not bosses.is_empty() and id == str(bosses[0]):
			out["boss"] = row
		elif id in bosses:
			continue
		elif t == "elite" or t == "boss":
			out["elites"].append(row)
		else:
			out["battles"].append(row)
	for r in sheet.get("rivals", []):
		var b = r.get("meet", {}).get("battle")
		if typeof(b) == TYPE_DICTIONARY:
			out["battles"].append({"at": "rival:" + str(r.get("id", "")), "template": str(b.get("template", "")), "level": int(b.get("level", 1))})
	return out
