## 条件小语言（WORLD_MAP_DESIGN §6.3）：纯函数、只用整数。一个对象里的各键是「且」。
## 没有 class_name，别处 preload。campaign 只读：state、definition、book（RunBook 的书包）。
##   {"flags":[..]} 全有      {"any_flags":[..]} 至少一个      {"not_flags":[..]} 一个都没有
##   {"metric":{"heat":[">=",100]}}  {"stat":{"medal_earned":[">=",10]}}  {"coins":{"gold":[">=",2]}}
##   {"alive":["faria"]}  {"items":[..]}  {"count_flags":{"of":[..],"min":2}}  {"scene_done":"scene03"}
##   {"hero_ok":true}  {"trust":{"murat":[">=",3]}}  {"chapter":[..]}  {"segment":[..]}  {"volume":2}  {"mustered":true}
##   {"any":[c1,c2]}  {"not":c}
## reason() 返回第一条不满足的键：带子键的写成 "键:子键"（flags:t_x、stat:medal_earned、metric:heat），其余就是键名。
extends RefCounted

const OPS := [">=", "<=", ">", "<", "=="]
const KEYS := ["flags", "any_flags", "not_flags", "metric", "stat", "coins", "alive", "items", "count_flags", "scene_done",
	"hero_ok", "trust", "chapter", "segment", "volume", "mustered", "any", "not"]
const METRICS := ["treasury", "morale", "heat", "vitality", "construction", "exploration"]
const STATS := ["medal_earned", "gold_earned", "supply_earned", "intel_earned", "battles", "wins", "boss_wins", "days"]
const COINS := ["gold", "supply", "medal", "intel"]


static func eval(campaign, cond) -> bool:
	return reason(campaign, cond) == ""


## 第一条不满足的键；全满足返回 ""。条件本身写坏了返回 "bad_cond"（校验器会先拦下）
static func reason(campaign, cond) -> String:
	if cond == null:
		return ""
	if typeof(cond) != TYPE_DICTIONARY:
		return "bad_cond"
	var state: Dictionary = campaign.state
	var flags: Dictionary = state.get("flags", {})
	for key in cond:
		var v = cond[key]
		match str(key):
			"flags":
				for f in _list(v):
					if not bool(flags.get(f, false)):
						return "flags:" + str(f)
			"any_flags":
				var hit := false
				for f in _list(v):
					hit = hit or bool(flags.get(f, false))
				if not hit:
					return "any_flags"
			"not_flags":
				for f in _list(v):
					if bool(flags.get(f, false)):
						return "not_flags:" + str(f)
			"metric":
				for m in _dict(v):
					if not _cmp(int(state.get("metrics", {}).get(m, 0)), v[m]):
						return "metric:" + str(m)
			"stat":
				for s in _dict(v):
					if not _cmp(stat(campaign, str(s)), v[s]):
						return "stat:" + str(s)
			"coins":
				for c in _dict(v):
					if not _cmp(int(state.get("rogue", {}).get("coins", {}).get(c, 0)), v[c]):
						return "coins:" + str(c)
			"alive":
				var comps: Dictionary = state.get("rogue", {}).get("companions", {})
				for c_id in _list(v):
					var row: Dictionary = comps.get(c_id, {})
					if not bool(row.get("recruited", false)) or not bool(row.get("alive", false)):
						return "alive:" + str(c_id)
			"items":
				for item in _list(v):
					if not item in state.get("inventory", []):
						return "items:" + str(item)
			"count_flags":
				var spec: Dictionary = _dict(v)
				var n := 0
				for f in _list(spec.get("of", [])):
					if bool(flags.get(f, false)):
						n += 1
				if n < int(spec.get("min", 0)):
					return "count_flags"
			"scene_done":
				if not scene_done(campaign, str(v)):
					return "scene_done"
			"hero_ok":
				var ok := not bool(state.get("rogue", {}).get("army", {}).get("hero_wounded", false))
				if ok != bool(v):
					return "hero_ok"
			"trust":
				var trust: Dictionary = state.get("rogue", {}).get("army", {}).get("trust", {})
				for c_id in _dict(v):
					if not _cmp(int(trust.get("hero|" + str(c_id), 0)), v[c_id]):
						return "trust:" + str(c_id)
			"chapter":
				var current := str(campaign.scene().get("chapter", ""))
				if not current in _list(v):
					return "chapter"
			"segment":
				if not str(state.get("segment", "")) in _list(v):
					return "segment"
			"volume":
				if int(campaign.book.get("volume", 1)) < int(v):
					return "volume"
			"mustered":
				if bool(state.get("map", {}).get("mustered", false)) != bool(v):
					return "mustered"
			"any":
				var any_ok := false
				for sub in _list(v):
					if reason(campaign, sub) == "":
						any_ok = true
						break
				if not any_ok:
					return "any"
			"not":
				if reason(campaign, v) == "":
					return "not"
			_:
				return "bad_cond"
	return ""


## 「键:子键」的根键（branches[段].reasons 按根键查文字）
static func root(reason_key: String) -> String:
	return reason_key.get_slice(":", 0)


## stat.* 的取值：*_earned 来自 rogue.tally（一辈子挣到的币，只加不减）；battles/wins/boss_wins 来自 run.stats
static func stat(campaign, key: String) -> int:
	var state: Dictionary = campaign.state
	if key.ends_with("_earned"):
		return int(state.get("rogue", {}).get("tally", {}).get(key.trim_suffix("_earned"), 0))
	if key == "days":
		return int(state.get("day", 1))
	return int(state.get("run", {}).get("stats", {}).get(key, 0))


## 某场已经演过：当前段里排在当前场之前；或者属于已经离开（归档）的段
static func scene_done(campaign, scene_id: String) -> bool:
	var scenes: Array = campaign.definition.get("scenes", [])
	for i in scenes.size():
		if str(scenes[i].get("id", "")) == scene_id:
			return i < int(campaign.state.get("scene_index", 0))
	var archive: Dictionary = campaign.state.get("archive", {})
	for seg in archive:
		var def: Dictionary = campaign.book.get("defs", {}).get(seg, {})
		var list: Array = def.get("scenes", [])
		for i in list.size():
			if str(list[i].get("id", "")) == scene_id:
				return i <= int(archive[seg].get("scene_index", -1))
	return false


## 结构检查：返回 "" 或第一处错误（校验器用）
static func check(cond, depth: int = 0) -> String:
	if cond == null:
		return ""
	if depth > 8 or typeof(cond) != TYPE_DICTIONARY:
		return "not_object"
	for key in cond:
		var v = cond[key]
		match str(key):
			"flags", "any_flags", "not_flags", "alive", "items", "chapter", "segment":
				if not _strings(v):
					return str(key)
			"metric", "stat", "coins", "trust":
				if typeof(v) != TYPE_DICTIONARY or (v as Dictionary).is_empty():
					return str(key)
				for sub in v:
					if str(key) == "metric" and not str(sub) in METRICS:
						return "metric:" + str(sub)
					if str(key) == "stat" and not str(sub) in STATS:
						return "stat:" + str(sub)
					if str(key) == "coins" and not str(sub) in COINS:
						return "coins:" + str(sub)
					if not _op_ok(v[sub]):
						return "%s:%s" % [key, sub]
			"count_flags":
				if typeof(v) != TYPE_DICTIONARY or not _strings(v.get("of")) or typeof(v.get("min")) != TYPE_INT:
					return "count_flags"
			"scene_done":
				if typeof(v) != TYPE_STRING or str(v).is_empty():
					return "scene_done"
			"hero_ok", "mustered":
				if typeof(v) != TYPE_BOOL:
					return str(key)
			"volume":
				if typeof(v) != TYPE_INT or int(v) < 1:
					return "volume"
			"any":
				if typeof(v) != TYPE_ARRAY or (v as Array).is_empty():
					return "any"
				for sub in v:
					var e := check(sub, depth + 1)
					if e != "":
						return "any/" + e
			"not":
				var e2 := check(v, depth + 1)
				if e2 != "":
					return "not/" + e2
			_:
				return "unknown:" + str(key)
	return ""


## 条件里读到的全部旗标（跨段旗标登记检查用）
static func flags_read(cond, out: Array = []) -> Array:
	if typeof(cond) != TYPE_DICTIONARY:
		return out
	for key in cond:
		var v = cond[key]
		match str(key):
			"flags", "any_flags", "not_flags":
				for f in _list(v):
					if not str(f) in out:
						out.append(str(f))
			"count_flags":
				for f in _list(_dict(v).get("of", [])):
					if not str(f) in out:
						out.append(str(f))
			"any":
				for sub in _list(v):
					flags_read(sub, out)
			"not":
				flags_read(v, out)
	return out


static func _cmp(value: int, spec) -> bool:
	if typeof(spec) != TYPE_ARRAY or (spec as Array).size() != 2:
		return false
	var rhs := int(spec[1])
	match str(spec[0]):
		">=": return value >= rhs
		"<=": return value <= rhs
		">": return value > rhs
		"<": return value < rhs
		"==": return value == rhs
	return false


static func _op_ok(spec) -> bool:
	return typeof(spec) == TYPE_ARRAY and (spec as Array).size() == 2 and str(spec[0]) in OPS and typeof(spec[1]) == TYPE_INT


static func _list(v) -> Array:
	return v if typeof(v) == TYPE_ARRAY else []


static func _dict(v) -> Dictionary:
	return v if typeof(v) == TYPE_DICTIONARY else {}


static func _strings(v) -> bool:
	if typeof(v) != TYPE_ARRAY:
		return false
	for x in v:
		if typeof(x) != TYPE_STRING or str(x).is_empty():
			return false
	return true
