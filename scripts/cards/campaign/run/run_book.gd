## 书：把几段串成一局（WORLD_MAP_DESIGN §6.2）。读书、读各段定义 / 地图 / 事件 / 伙伴总表，算整本书的哈希，做全书校验
## （§8.2 等级规则、R6 插曲轮换、id 全书唯一、跨段旗标登记、恰好一条保底分支……；地图本身的 R1–R12 在 map_validate.gd）。
## 没有 class_name，别处 preload。书包（bundle）只放在内存里，不进状态；状态里只有 definition_hash。
extends RefCounted

const RunConditions = preload("res://scripts/cards/campaign/run/run_conditions.gd")
const BattleApi = preload("res://scripts/cards/campaign/run/run_battle_api.gd")
const MapValidate = preload("res://scripts/cards/campaign/map/map_validate.gd")

const OCEAN_PAWN := "res://data/campaigns/ocean_pawn.json"
const VOLUME1 := "res://data/campaigns/napoleon/book.json"
const NAPOLEON := "res://data/campaigns/napoleon/book_volume2.json"
const DEMO := "res://data/campaigns/napoleon/book_demo.json"
const MAX_INTEGER := 1000000000000
const KINDS := ["trunk", "branch", "single"]
## 失败收场：允许跨段重复（C12），任何一段都可能落到这里
const FAILURE_ENDINGS := ["bankruptcy", "loss", "blockade", "exile"]
const INTERLUDES := ["audience", "camp_night", "bond", "council", "minigame:weigh", "minigame:decode", "minigame:ring", "minigame:fragments"]
const EVENT_FORBIDDEN := ["branch", "ending", "advance"]

static var _checked: Dictionary = {}


## 单段书 ocean_pawn：只有一段 ocean、没有地图、offset 0（§6.2 末条）。哈希就是段定义的哈希（v1 存档照读）
static func builtin(definition: Dictionary, def_hash: String) -> Dictionary:
	return {"id": "ocean_pawn", "path": "", "builtin": true, "volume": 1, "start": "ocean",
		"raw": {"id": "ocean_pawn", "version": 1, "volume": 1, "start": "ocean",
			"segments": {"ocean": {"file": OCEAN_PAWN, "map": "", "kind": "single"}}, "branches": {}},
		"defs": {"ocean": definition}, "maps": {"ocean": {}}, "events": {"ocean": []}, "events_common": [],
		"companions": {}, "hash": def_hash}


## 读 JSON：整数树（浮点只许是整数值）并归一成 int
static func read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"ok": false, "err": "definition_missing", "path": path}
	var parsed := JSON.new()
	if parsed.parse(FileAccess.get_file_as_string(path)) != OK:
		return {"ok": false, "err": "definition_invalid", "path": path}
	if not integer_tree(parsed.data):
		return {"ok": false, "err": "definition_invalid", "path": path}
	return {"ok": true, "err": "", "data": normalise(parsed.data)}


## 读整本书：{ok, err, book}。段定义的逐项校验由 ocean_campaign._valid_definition 做，全书校验由 validate()
static func load_bundle(path: String) -> Dictionary:
	var read := read_json(path)
	if not bool(read["ok"]):
		return read
	var raw = read["data"]
	if typeof(raw) != TYPE_DICTIONARY or typeof(raw.get("segments")) != TYPE_DICTIONARY or (raw["segments"] as Dictionary).is_empty():
		return {"ok": false, "err": "definition_invalid", "path": path}
	var bundle := {"id": str(raw.get("id", "")), "path": path, "builtin": false, "volume": int(raw.get("volume", 1)),
		"start": str(raw.get("start", "")), "raw": raw, "defs": {}, "maps": {}, "events": {}, "events_common": [], "companions": {}, "hash": ""}
	for seg in raw["segments"]:
		var spec = raw["segments"][seg]
		if typeof(spec) != TYPE_DICTIONARY or typeof(spec.get("file")) != TYPE_STRING:
			return {"ok": false, "err": "definition_invalid", "path": path, "segment": seg}
		var d := read_json(str(spec["file"]))
		if not bool(d["ok"]) or typeof(d["data"]) != TYPE_DICTIONARY:
			return {"ok": false, "err": str(d.get("err", "definition_invalid")), "path": str(spec["file"])}
		bundle["defs"][seg] = d["data"]
		var map_data := {}
		if typeof(spec.get("map", "")) == TYPE_STRING and not str(spec.get("map", "")).is_empty():
			var m := read_json(str(spec["map"]))
			if not bool(m["ok"]) or typeof(m["data"]) != TYPE_DICTIONARY:
				return {"ok": false, "err": str(m.get("err", "definition_invalid")), "path": str(spec["map"])}
			map_data = m["data"]
		bundle["maps"][seg] = map_data
		var events: Array = (d["data"].get("events", []) as Array).duplicate(true) if typeof(d["data"].get("events", [])) == TYPE_ARRAY else []
		if typeof(spec.get("events", "")) == TYPE_STRING and not str(spec.get("events", "")).is_empty():
			var e := read_json(str(spec["events"]))
			if not bool(e["ok"]):
				return {"ok": false, "err": str(e["err"]), "path": str(spec["events"])}
			events.append_array(_event_list(e["data"]))
		bundle["events"][seg] = events
	for key in ["events_common", "companions"]:
		if typeof(raw.get(key, "")) == TYPE_STRING and not str(raw.get(key, "")).is_empty():
			var r := read_json(str(raw[key]))
			if not bool(r["ok"]):
				return {"ok": false, "err": str(r["err"]), "path": str(raw[key])}
			if key == "events_common":
				bundle["events_common"] = _event_list(r["data"])
			else:
				bundle["companions"] = _companion_rows(r["data"])
	bundle["hash"] = book_hash(bundle)
	return {"ok": true, "err": "", "book": bundle}


## 整本书的哈希：书本身 + 各段定义 + 地图 + 事件 + 伙伴总表（键排序后 sha256）
static func book_hash(bundle: Dictionary) -> String:
	var parts := {"book": bundle["raw"], "defs": bundle["defs"], "maps": bundle["maps"], "events": bundle["events"],
		"events_common": bundle["events_common"], "companions": bundle["companions"]}
	return JSON.stringify(parts, "", true).sha256_text()


static func _event_list(data) -> Array:
	if typeof(data) == TYPE_ARRAY:
		return (data as Array).duplicate(true)
	if typeof(data) == TYPE_DICTIONARY and typeof(data.get("events")) == TYPE_ARRAY:
		return (data["events"] as Array).duplicate(true)
	return []


## 伙伴总表：{id: 行}，去掉 _doc 之类的说明键
static func _companion_rows(data) -> Dictionary:
	var out := {}
	if typeof(data) != TYPE_DICTIONARY:
		return out
	var rows: Dictionary = data.get("companions", data) if typeof(data.get("companions")) == TYPE_DICTIONARY else data
	for id in rows:
		if not str(id).begins_with("_") and typeof(rows[id]) == TYPE_DICTIONARY:
			out[str(id)] = rows[id]
	return out


# ================================================================ 查书

static func segment_spec(bundle: Dictionary, seg: String) -> Dictionary:
	return bundle.get("raw", {}).get("segments", {}).get(seg, {})


## 书里登记的分支（入口场、等级偏移、条件）
static func branch(bundle: Dictionary, seg: String) -> Dictionary:
	return bundle.get("raw", {}).get("branches", {}).get(seg, {})


## 一场的场景战斗：{template, level, mods_when, order_flag} 或 {}（这一场在本书里没有仗）。
## book.segments.<段>.scene_battles 优先（template "" = 空模板，C24）；否则读 scene_map 的幕，L = 2a−1 + offset（C1）
static func scene_battle(bundle: Dictionary, seg: String, scene_id: String, level_offset: int = 0) -> Dictionary:
	return MapValidate.MapRules.scene_battle(bundle, seg, scene_id, level_offset)


## 一段的章节顺序（chapters 数组的顺序就是游玩顺序）
static func chapter_ids(def: Dictionary) -> Array:
	var out: Array = []
	for c in def.get("chapters", []):
		out.append(str(c.get("id", "")))
	return out


## 全书所有事件 id → 事件（段事件 + 通用池）
static func all_events(bundle: Dictionary) -> Dictionary:
	var out := {}
	for seg in bundle.get("events", {}):
		for ev in bundle["events"][seg]:
			out[str(ev.get("id", ""))] = ev
	for ev in bundle.get("events_common", []):
		out[str(ev.get("id", ""))] = ev
	return out


# ================================================================ 全书校验

## {errors:[...], warnings:[...]}。书包已经读进来、各段定义各自合法
static func validate(bundle: Dictionary) -> Dictionary:
	var h := str(bundle.get("hash", ""))
	if h != "" and _checked.has(h):
		return (_checked[h] as Dictionary).duplicate(true)
	var errors: Array = []
	var warnings: Array = []
	var raw: Dictionary = bundle.get("raw", {})
	var segs: Dictionary = raw.get("segments", {})
	if typeof(raw.get("version")) != TYPE_INT or typeof(raw.get("volume", 1)) != TYPE_INT or int(raw.get("volume", 1)) < 1:
		errors.append("book: version/volume")
	if raw.has("enforce_chapter_limits") and typeof(raw["enforce_chapter_limits"]) != TYPE_BOOL:
		errors.append("book: enforce_chapter_limits must be boolean")
	if raw.has("chapter_locked_message") and typeof(raw["chapter_locked_message"]) != TYPE_STRING:
		errors.append("book: chapter_locked_message must be text")
	if raw.has("title"):
		if typeof(raw["title"]) != TYPE_DICTIONARY:
			errors.append("book: title must be an object")
		else:
			for key in ["name", "sub"]:
				if raw["title"].has(key) and typeof(raw["title"][key]) != TYPE_STRING:
					errors.append("book: title.%s must be text" % key)
	if not segs.has(str(raw.get("start", ""))):
		errors.append("book: start segment %s" % raw.get("start", ""))
	for seg in segs:
		if str(segs[seg].get("kind", "")) not in KINDS:
			errors.append("segment %s: kind" % seg)
	_check_unique_ids(bundle, errors)
	_check_branches(bundle, errors)
	_check_events(bundle, errors)
	_check_endings(bundle, errors, warnings)
	_check_shared_flags(bundle, errors)
	_check_conditions(bundle, errors)
	for seg in bundle.get("maps", {}):
		if not (bundle["maps"][seg] as Dictionary).is_empty():
			var mv := MapValidate.validate(bundle, str(seg))
			errors.append_array(mv["errors"])
			warnings.append_array(mv["warnings"])
	_check_interludes(bundle, errors)
	_check_levels(bundle, errors, warnings)
	var out := {"errors": errors, "warnings": warnings}
	if h != "":
		_checked[h] = out.duplicate(true)
	return out


## 场景、章节、事件 id 全书唯一（地图节点以「段:节点」计，段内唯一由地图校验查）
static func _check_unique_ids(bundle: Dictionary, errors: Array) -> void:
	var seen := {}
	for seg in bundle["defs"]:
		var def: Dictionary = bundle["defs"][seg]
		for c in def.get("chapters", []):
			_unique(seen, "chapter:" + str(c.get("id", "")), seg, errors)
		for s in def.get("scenes", []):
			_unique(seen, "scene:" + str(s.get("id", "")), seg, errors)
	for seg in bundle["events"]:
		for ev in bundle["events"][seg]:
			_unique(seen, "event:" + str(ev.get("id", "")), seg, errors)
	for ev in bundle.get("events_common", []):
		_unique(seen, "event:" + str(ev.get("id", "")), "common", errors)


static func _unique(seen: Dictionary, key: String, where: String, errors: Array) -> void:
	if seen.has(key):
		errors.append("duplicate %s (%s, %s)" % [key, seen[key], where])
	else:
		seen[key] = where


## 分支：来源段和分岔场景存在、场上有指向它的抉择；每个分岔点恰好一条无条件分支（保底）；带 branch 的抉择都登记过
static func _check_branches(bundle: Dictionary, errors: Array) -> void:
	var raw: Dictionary = bundle["raw"]
	var branches: Dictionary = raw.get("branches", {})
	var open_count := {}
	for target in branches:
		var b: Dictionary = branches[target]
		if not bundle["defs"].has(target):
			errors.append("branch %s: no such segment" % target)
			continue
		var from := str(b.get("from", ""))
		if not bundle["defs"].has(from):
			errors.append("branch %s: from %s" % [target, from])
			continue
		var scene := _find_scene(bundle["defs"][from], str(b.get("scene", "")))
		if scene.is_empty():
			errors.append("branch %s: scene %s not in %s" % [target, b.get("scene", ""), from])
			continue
		var hit := false
		for c in scene.get("choices", []):
			hit = hit or str(c.get("branch", "")) == target
		if not hit:
			errors.append("branch %s: no choice in %s points to it" % [target, scene["id"]])
		var e := RunConditions.check(b.get("requires", {}))
		if e != "":
			errors.append("branch %s: requires %s" % [target, e])
		var entry := str(b.get("entry", ""))
		if entry != "" and _find_scene(bundle["defs"][target], entry).is_empty():
			errors.append("branch %s: entry %s" % [target, entry])
		var point := from + ":" + str(b.get("scene", ""))
		if not open_count.has(point):
			open_count[point] = 0
		if (b.get("requires", {}) as Dictionary).is_empty():
			open_count[point] = int(open_count[point]) + 1
	for point in open_count:
		if int(open_count[point]) != 1:
			errors.append("branch point %s: %d unconditional branches (need exactly 1)" % [point, open_count[point]])
	for seg in bundle["defs"]:
		for s in bundle["defs"][seg].get("scenes", []):
			for c in s.get("choices", []):
				var t := str(c.get("branch", ""))
				if t == "":
					continue
				if not branches.has(t) or str(branches[t].get("from", "")) != seg or str(branches[t].get("scene", "")) != str(s["id"]):
					errors.append("choice %s.%s: branch %s not registered for this scene" % [s["id"], c.get("id", ""), t])
		for fate in bundle["defs"][seg].get("big_fate_extra", []):
			var j := str(fate.get("jump", ""))
			if j != "" and not bundle["defs"].has(j):
				errors.append("big_fate_extra %s: jump %s" % [fate.get("id", ""), j])


## 事件：禁止 branch / ending / advance；抉择要的线索必须是本事件的查验；插曲形状
static func _check_events(bundle: Dictionary, errors: Array) -> void:
	for ev in all_events(bundle).values():
		var id := str(ev.get("id", ""))
		if id.is_empty():
			errors.append("event without id")
			continue
		for key in EVENT_FORBIDDEN:
			if ev.has(key):
				errors.append("event %s: forbidden key %s" % [id, key])
		var clues := {}
		for a in ev.get("appraisals", []):
			clues[str(a.get("id", ""))] = true
		var choices: Array = ev.get("choices", [])
		var questions: Array = ev.get("questions", [])
		if choices.is_empty() and questions.is_empty():
			errors.append("event %s: no choices" % id)
		for q in questions:
			for side in ["a", "b"]:
				if typeof(q.get(side)) != TYPE_DICTIONARY:
					errors.append("event %s: question %s needs a and b" % [id, q.get("id", "")])
				else:
					choices = choices + [q[side]]
		for c in choices:
			for key in EVENT_FORBIDDEN:
				if c.has(key):
					errors.append("event %s choice %s: forbidden key %s" % [id, c.get("id", ""), key])
			for clue in c.get("requires_clues", []):
				if not clues.has(str(clue)):
					errors.append("event %s choice %s: unknown clue %s" % [id, c.get("id", ""), clue])
			var e := RunConditions.check(c.get("requires", {}))
			if e != "":
				errors.append("event %s choice %s: requires %s" % [id, c.get("id", ""), e])
		var e2 := RunConditions.check(ev.get("requires", {}))
		if e2 != "":
			errors.append("event %s: requires %s" % [id, e2])
		var il := str(ev.get("interlude", ""))
		if il != "" and il not in INTERLUDES:
			errors.append("event %s: interlude %s" % [id, il])
		if il.begins_with("minigame:"):
			var kind := il.trim_prefix("minigame:")
			var has_kind := false
			for a in ev.get("appraisals", []):
				has_kind = has_kind or str(a.get("kind", "")) == kind
			if not has_kind:
				errors.append("event %s: minigame %s needs an appraisal of that kind" % [id, kind])


## 结局：规则里提到的结局都有正文（远洋单段书的正文另有出处，只提醒）；卷终带 kind volume；非失败结局 id 全书唯一
static func _check_endings(bundle: Dictionary, errors: Array, warnings: Array) -> void:
	var seen := {}
	for seg in bundle["defs"]:
		var def: Dictionary = bundle["defs"][seg]
		var texts := {}
		for e in def.get("endings", []):
			var id := str(e.get("id", ""))
			texts[id] = e
			if id in FAILURE_ENDINGS:
				continue
			if seen.has(id):
				errors.append("ending %s in %s and %s" % [id, seen[id], seg])
			seen[id] = seg
		var spec: Dictionary = bundle["raw"]["segments"][seg]
		if spec.has("collection_endings"):
			if typeof(spec["collection_endings"]) != TYPE_ARRAY:
				errors.append("segment %s: collection_endings must be an array" % seg)
			else:
				var listed := {}
				for id in spec["collection_endings"]:
					if typeof(id) != TYPE_STRING or not texts.has(id) or listed.has(id):
						errors.append("segment %s: invalid collection ending %s" % [seg, id])
					listed[id] = true
		var rules: Dictionary = def.get("rules", {}) if typeof(def.get("rules")) == TYPE_DICTIONARY else {}
		for f in rules.get("failures", []):
			_ending_text(texts, str(f.get("ending", "")), seg, warnings)
		for e in rules.get("endings", []):
			_ending_text(texts, str(e.get("id", "")), seg, warnings)
		for e in rules.get("volume_endings", []):
			var vid := str(e.get("id", ""))
			if not texts.has(vid) or str(texts[vid].get("kind", "")) != "volume":
				errors.append("segment %s: volume ending %s needs an endings entry with kind volume" % [seg, vid])
		var dv := str(rules.get("default_volume_ending", ""))
		if dv != "" and (not texts.has(dv) or str(texts[dv].get("kind", "")) != "volume"):
			errors.append("segment %s: default volume ending %s" % [seg, dv])
		var has_volume_chapter := false
		for c in def.get("chapters", []):
			has_volume_chapter = has_volume_chapter or int(c.get("volume", 1)) > int(bundle.get("volume", 1))
		if has_volume_chapter and dv == "" and (rules.get("volume_endings", []) as Array).is_empty():
			errors.append("segment %s: chapters beyond volume %d but no volume ending" % [seg, bundle.get("volume", 1)])


static func _ending_text(texts: Dictionary, id: String, seg: String, warnings: Array) -> void:
	if id != "" and not texts.has(id):
		warnings.append("segment %s: ending %s has no text" % [seg, id])


## 跨段读取的旗标必须登记在 shared_flags（分岔抉择可以写目标段前缀的旗标，C30）
static func _check_shared_flags(bundle: Dictionary, errors: Array) -> void:
	var shared: Array = bundle["raw"].get("shared_flags", [])
	var written := {}
	for seg in bundle["defs"]:
		var def: Dictionary = bundle["defs"][seg]
		var mine := {}
		for s in def.get("scenes", []):
			for c in s.get("choices", []):
				for f in c.get("flags", []):
					mine[str(f)] = true
		for ev in bundle["events"].get(seg, []):
			for c in _event_choices(ev):
				for f in c.get("flags", []):
					mine[str(f)] = true
		for f in _action_flags(def):
			mine[f] = true
		written[seg] = mine
	for seg in bundle["defs"]:
		for f in _flags_read_in(bundle, seg):
			if bool(written[seg].get(f, false)) or f in shared:
				continue
			for other in written:
				if other != seg and bool(written[other].get(f, false)):
					errors.append("segment %s reads flag %s written in %s: add it to shared_flags" % [seg, f, other])
					break


static func _event_choices(ev: Dictionary) -> Array:
	var out: Array = (ev.get("choices", []) as Array).duplicate()
	for q in ev.get("questions", []):
		for side in ["a", "b"]:
			if typeof(q.get(side)) == TYPE_DICTIONARY:
				out.append(q[side])
	return out


static func _action_flags(def: Dictionary) -> Array:
	var out: Array = []
	var rules = def.get("rules", {})
	if typeof(rules) != TYPE_DICTIONARY:
		return out
	for key in rules.get("actions", {}):
		var a = rules["actions"][key]
		if typeof(a) == TYPE_DICTIONARY:
			for f in a.get("flags", []):
				out.append(str(f))
	return out


## 一段里读到的旗标：场景 when、抉择 requires / requires_flags、事件 requires、节点 / 连线 requires、规则结局、大命运
static func _flags_read_in(bundle: Dictionary, seg: String) -> Array:
	var out: Array = []
	var def: Dictionary = bundle["defs"][seg]
	for s in def.get("scenes", []):
		RunConditions.flags_read(s.get("when", {}), out)
		for c in s.get("choices", []):
			if str(c.get("branch", "")) != "":
				continue
			RunConditions.flags_read(c.get("requires", {}), out)
			for f in c.get("requires_flags", []):
				if not str(f) in out:
					out.append(str(f))
	for ev in bundle["events"].get(seg, []):
		RunConditions.flags_read(ev.get("requires", {}), out)
		for c in _event_choices(ev):
			RunConditions.flags_read(c.get("requires", {}), out)
	var rules = def.get("rules", {})
	if typeof(rules) == TYPE_DICTIONARY:
		for key in ["endings", "volume_endings"]:
			for e in rules.get(key, []):
				RunConditions.flags_read(e.get("when", {}), out)
	for fate in def.get("big_fate_extra", []):
		RunConditions.flags_read(fate.get("when", {}), out)
	for sheet in bundle["maps"].get(seg, {}).get("sheets", []):
		for n in sheet.get("nodes", []):
			RunConditions.flags_read(n.get("requires", {}), out)
		for l in sheet.get("links", []):
			RunConditions.flags_read(l.get("requires", {}), out)
	for scene_id in segment_spec(bundle, seg).get("scene_battles", {}):
		var row = segment_spec(bundle, seg)["scene_battles"][scene_id]
		if typeof(row) == TYPE_DICTIONARY:
			for mw in row.get("mods_when", []):
				RunConditions.flags_read(mw.get("when", {}), out)
	return out


## 段定义里所有条件的形状
static func _check_conditions(bundle: Dictionary, errors: Array) -> void:
	for seg in bundle["defs"]:
		var def: Dictionary = bundle["defs"][seg]
		for s in def.get("scenes", []):
			var e := RunConditions.check(s.get("when", {}))
			if e != "":
				errors.append("scene %s: when %s" % [s.get("id", ""), e])
			for c in s.get("choices", []):
				var e2 := RunConditions.check(c.get("requires", {}))
				if e2 != "":
					errors.append("choice %s.%s: requires %s" % [s.get("id", ""), c.get("id", ""), e2])
		var rules = def.get("rules", {})
		if typeof(rules) == TYPE_DICTIONARY:
			for key in ["failures", "endings", "volume_endings"]:
				for row in rules.get(key, []):
					var e3 := RunConditions.check(row.get("when", {}))
					if e3 != "":
						errors.append("segment %s rules.%s: %s" % [seg, key, e3])
		for fate in def.get("big_fate_extra", []):
			var e4 := RunConditions.check(fate.get("when", {}))
			if e4 != "":
				errors.append("big_fate_extra %s: %s" % [fate.get("id", ""), e4])


## 游玩链：主干按章；主干最后一章接每条分支的入口章；每条分支按章。[[段, 章], …] 的列表
static func chains(bundle: Dictionary) -> Array:
	var out: Array = []
	var start := str(bundle.get("start", ""))
	if not bundle["defs"].has(start):
		return out
	var trunk: Array = []
	for c in chapter_ids(bundle["defs"][start]):
		if _chapter_open(bundle, start, c):
			trunk.append([start, c])
	var branches: Dictionary = bundle["raw"].get("branches", {})
	if branches.is_empty():
		out.append(trunk)
		return out
	for target in branches:
		if not bundle["defs"].has(target):
			continue
		var chain: Array = trunk.duplicate()
		var def: Dictionary = bundle["defs"][target]
		var entry := str(branches[target].get("entry", ""))
		var first_chapter := str(_find_scene(def, entry).get("chapter", "")) if entry != "" else ""
		var started := first_chapter == ""
		for c in chapter_ids(def):
			started = started or c == first_chapter
			if started and _chapter_open(bundle, target, c):
				chain.append([target, c])
		out.append(chain)
	return out


static func _chapter_open(bundle: Dictionary, seg: String, chapter_id: String) -> bool:
	for c in bundle["defs"][seg].get("chapters", []):
		if str(c.get("id", "")) == chapter_id:
			return int(c.get("volume", 1)) <= int(bundle.get("volume", 1))
	return false


## R6：同一条游玩链上相邻两章的插曲类型不同；每种用到的插曲在池里都有能抽到的事件
static func _check_interludes(bundle: Dictionary, errors: Array) -> void:
	var pools := {}
	for seg in bundle["events"]:
		for ev in bundle["events"][seg]:
			if str(ev.get("interlude", "")) != "":
				pools[str(ev["interlude"]) + "|" + str(seg)] = true
	for ev in bundle.get("events_common", []):
		if str(ev.get("interlude", "")) != "":
			pools[str(ev["interlude"]) + "|*"] = true
	var seen_pairs := {}
	for chain in chains(bundle):
		var prev := ""
		var prev_at := ""
		for link in chain:
			var sheet := MapValidate.sheet_of(bundle, str(link[0]), str(link[1]))
			var il := str(sheet.get("interlude", ""))
			if il != "":
				if il == prev and not seen_pairs.has(prev_at + ">" + str(link[1])):
					seen_pairs[prev_at + ">" + str(link[1])] = true
					errors.append("R6: chapters %s and %s:%s both use interlude %s" % [prev_at, link[0], link[1], il])
				if not pools.has(il + "|" + str(link[0])) and not pools.has(il + "|*"):
					errors.append("R6: interlude %s (%s:%s) has no event in the pools" % [il, link[0], link[1]])
			prev = il
			prev_at = "%s:%s" % [link[0], link[1]]


## §8.2 的等级规则：Boss 沿游玩链严格递增；同章精英 ≤ Boss−1、遭遇 ≤ Boss−2；分支里任何仗 ≥ 主干最终 Boss；
## 相邻两章 Boss 战力 ≥ ×1.12；带补兵的模板只用在 [b, b+11]，写了 level 的模板只用在 level ± 1
static func _check_levels(bundle: Dictionary, errors: Array, warnings: Array) -> void:
	var start := str(bundle.get("start", ""))
	var trunk_final := 0
	var chapter_rows := {}
	for seg in bundle["defs"]:
		var offset := int(branch(bundle, seg).get("level_offset", 0))
		for c in chapter_ids(bundle["defs"][seg]):
			if not _chapter_open(bundle, seg, c):
				continue
			var row := MapValidate.chapter_battles(bundle, str(seg), c, offset)
			chapter_rows["%s:%s" % [seg, c]] = row
			if row.get("boss", {}).is_empty():
				continue
			var boss_l := int(row["boss"]["level"])
			for e in row.get("elites", []):
				if int(e["level"]) > boss_l - 1:
					errors.append("8.2 rule 2: %s:%s elite %s L%d > boss L%d - 1" % [seg, c, e["at"], e["level"], boss_l])
			for e in row.get("battles", []):
				if int(e["level"]) > boss_l - 2:
					errors.append("8.2 rule 2: %s:%s battle %s L%d > boss L%d - 2" % [seg, c, e["at"], e["level"], boss_l])
			for e in row.get("elites", []) + row.get("battles", []) + [row["boss"]]:
				_check_template_level(e, seg, c, errors)
			if seg == start:
				trunk_final = boss_l
	for chain in chains(bundle):
		var prev: Dictionary = {}
		for link in chain:
			var row: Dictionary = chapter_rows.get("%s:%s" % [link[0], link[1]], {})
			var boss: Dictionary = row.get("boss", {})
			if boss.is_empty():
				continue
			if not prev.is_empty():
				if int(boss["level"]) <= int(prev["level"]):
					errors.append("8.2 rule 1: boss %s L%d not above %s L%d" % [boss["at"], boss["level"], prev["at"], prev["level"]])
				var p0 := BattleApi.power(str(prev["template"]), int(prev["level"]))
				var p1 := BattleApi.power(str(boss["template"]), int(boss["level"]))
				if p0 > 0 and p1 * 100 < p0 * 112:
					errors.append("8.2 rule 4: boss %s power %d < %d x 1.12 (%s)" % [boss["at"], p1, p0, prev["at"]])
			prev = boss
	if trunk_final > 0:
		for key in chapter_rows:
			if str(key).get_slice(":", 0) == start:
				continue
			var row: Dictionary = chapter_rows[key]
			var all: Array = row.get("elites", []) + row.get("battles", [])
			if not row.get("boss", {}).is_empty():
				all.append(row["boss"])
			for e in all:
				if int(e["level"]) < trunk_final:
					errors.append("8.2 rule 3: %s battle %s L%d below trunk final boss L%d" % [key, e["at"], e["level"], trunk_final])


static func _check_template_level(e: Dictionary, seg: String, chapter_id: String, errors: Array) -> void:
	var tpl: Dictionary = BattleApi.template(str(e.get("template", "")))
	if tpl.is_empty():
		return
	var lv := int(e["level"])
	if tpl.has("base_level"):
		var b := int(tpl["base_level"])
		if lv < b or lv > b + 11:
			errors.append("8.2 rule 5: %s:%s %s uses %s at L%d outside [%d, %d]" % [seg, chapter_id, e["at"], e["template"], lv, b, b + 11])
	elif tpl.has("level") and absi(lv - int(tpl["level"])) > 1:
		errors.append("8.2 rule 5: %s:%s %s uses %s at L%d (template level %d)" % [seg, chapter_id, e["at"], e["template"], lv, tpl["level"]])


static func _find_scene(def: Dictionary, scene_id: String) -> Dictionary:
	for s in def.get("scenes", []):
		if str(s.get("id", "")) == scene_id:
			return s
	return {}


# ================================================================ 整数树

static func integer_tree(value: Variant, depth: int = 0) -> bool:
	if depth > 32:
		return false
	match typeof(value):
		TYPE_INT: return value >= -MAX_INTEGER and value <= MAX_INTEGER
		TYPE_FLOAT: return is_finite(value) and value == floor(value) and absf(value) <= MAX_INTEGER
		TYPE_NIL, TYPE_BOOL, TYPE_STRING: return true
		TYPE_ARRAY:
			for entry in value:
				if not integer_tree(entry, depth + 1):
					return false
		TYPE_DICTIONARY:
			for key in value:
				if typeof(key) != TYPE_STRING or not integer_tree(value[key], depth + 1):
					return false
		_: return false
	return true


static func normalise(value: Variant) -> Variant:
	if typeof(value) == TYPE_FLOAT:
		return int(value)
	if typeof(value) == TYPE_DICTIONARY:
		var result := {}
		for key in value:
			result[key] = normalise(value[key])
		return result
	if typeof(value) == TYPE_ARRAY:
		var result: Array = []
		for entry in value:
			result.append(normalise(entry))
		return result
	return value
