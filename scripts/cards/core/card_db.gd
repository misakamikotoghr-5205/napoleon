# 卡牌数据库：读一套数据（例子集或真数据，一次只读一套，§4.10）、规则文件（深合并 balance_overrides）、标签、界面键、
# 正文覆盖层、观察目录、美术清单、开场；按类型建索引。主人 G01；W0 写了能用的最小版。
# 正文分层（框架版收尾默认，2026-10-22，主创可改）：剧情插件 packs/<id>/text/**（按 order 叠放，后者覆盖前者）
# → 人写层 text/** → AI 基础层 text_ai/**，各层分开存、按字段往下找（text_value）。正文层出的问题记进 warnings()，
# 不进 errors()（errors 只管骨架，非空时新局失败）；严格校验（validate_main）照样把它们报成错。
# 合同：docs/cards/CARDS_INTERFACES.md §4.1、§4.5、§4.6、§4.10、§7.9（G01 core）；插件说明 docs/cards/PLUGINS.md。
class_name CardDB
extends RefCounted

const Packs = preload("res://scripts/cards/core/card_packs.gd")

const DEFAULT_ROOT := "res://data/cards"
## 真数据里放牌的目录（相对数据根）；另有 minigames/items.json
const CARD_DIRS: Array[String] = ["era", "demand", "news", "dossier", "common", "fortune", "guide"]
## 例子集里不是牌文件的（相对 _examples/）
const EXAMPLE_NON_CARD: Array[String] = ["ui_keys.json", "tags.json", "items/templates_extra.json",
	"minigames/codebook.json"]
const CAST_PATH := "res://data/cast.json"

var root: String = DEFAULT_ROOT
var only_examples: bool = false
var ship: bool = false

var _cards: Dictionary = {}       # id → def（整数已还原）
var _file_of: Dictionary = {}     # id → 相对数据根的文件路径
var _order: Dictionary = {}       # id → 读入顺序（文件路径排序后、文件内顺序）
var _by_type: Dictionary = {}     # type → Array[String]（排好序）
var _persons: Dictionary = {}
var _rules: Dictionary = {}
var _tags: Dictionary = {}
var _ui_keys: Dictionary = {}     # key → {brief, owner}
var _text: Dictionary = {}        # id / 键 → 覆盖层条目
var _ai_text: Dictionary = {}     # #212：与人写层隔离，不能充当 human 审核证据
var _packs: Array = []            # 已载入的剧情插件 {id, order, source, provenance, text, …}，按 (order, id) 升序
var _pack_info: Array = []        # 找到的每个插件一行（含停用、跳过的原因）
var _pack_cfg: Dictionary = {}    # Packs.resolve 的结果：dirs、pck_dirs、enable、disable、no_ai
var _pack_files := PackedStringArray()
var _warnings := PackedStringArray()
var _obs: Dictionary = {}         # kind → {key: {fidelity, brief}}
var _manifest: Dictionary = {}
var _stage_files: Dictionary = {} # era → stage.json
var _guide_test: Dictionary = {}
var _deal_cache: Dictionary = {}  # 只读发牌候选缓存（不是游戏状态）
var _hash_cache: String = ""
var _hash_sig: int = 0
var _guide_data_cache: Dictionary = {}
var _file_sources: Dictionary = {}
var _dir_sig: Array = []
var _errors := PackedStringArray()

static var _db_cache: Dictionary = {}
static var _json_cache: Dictionary = {}


## opts: {only_examples: bool, ship: bool,
##        packs: Array（插件目录；不给时真数据读 res://packs + user://packs，别的数据根不读）, pck_dirs: Array,
##        enable_packs / disable_packs: Array（插件 id）, no_packs: bool, no_ai: bool（跳过 source 为 ai 的插件）}
static func load_all(p_root: String = DEFAULT_ROOT, opts: Dictionary = {}) -> CardDB:
	var r := p_root.trim_suffix("/")
	var ex := bool(opts.get("only_examples", false))
	var sh := bool(opts.get("ship", false))
	var cfg := Packs.resolve(r, ex, opts, DEFAULT_ROOT)
	var key := "%s|%s|%s|%s" % [r, ex, sh, JSON.stringify(cfg, "", true)]
	if _db_cache.has(key):
		var cached: CardDB = _db_cache[key]
		if cached._sig_matches():
			return cached
	var db := CardDB.new()
	db.root = r
	db.only_examples = ex
	db.ship = sh
	db._pack_cfg = cfg
	db._load()
	db._record_sig()
	_db_cache[key] = db
	return db


# ---------------- 读 ----------------
func _load() -> void:
	_load_rules()
	_load_persons_cast()
	var order := 0
	for rel in card_files(root, only_examples):
		var parsed = read_json(root + "/" + rel)
		if typeof(parsed) != TYPE_DICTIONARY:
			_errors.append("%s: cannot parse" % rel)
			continue
		var doc: Dictionary = CardState.int_restore(parsed)
		var persons: Dictionary = doc["persons"] if typeof(doc.get("persons")) == TYPE_DICTIONARY else {}
		for pid in persons.keys():
			if typeof(persons[pid]) != TYPE_DICTIONARY:
				_errors.append("%s: person %s is not an object" % [rel, pid])
				continue
			if _persons.has(str(pid)):
				_errors.append("%s: duplicate person %s" % [rel, pid])
			else:
				_persons[str(pid)] = persons[pid]
		if doc.has("_test"):
			_guide_test.merge(doc["_test"], true)
		var card_rows: Array = doc["cards"] if typeof(doc.get("cards")) == TYPE_ARRAY else []
		for c in card_rows:
			if typeof(c) != TYPE_DICTIONARY or not c.has("id"):
				continue
			var id := str(c["id"])
			if _cards.has(id):
				_errors.append("%s: duplicate id %s" % [rel, id])
				continue
			_cards[id] = c
			_file_of[id] = rel
			_order[id] = order
			order += 1
			var t := str(c.get("type", ""))
			if not _by_type.has(t):
				_by_type[t] = []
			(_by_type[t] as Array).append(id)
	for t in _by_type.keys():
		(_by_type[t] as Array).sort()
	var base := set_base()
	for f in key_files(root, "tags", only_examples):
		var d = read_json(f)
		if typeof(d) == TYPE_DICTIONARY:
			for k in d.get("tags", {}).keys():
				if not _tags.has(k):
					_tags[k] = d["tags"][k]
	for f in key_files(root, "ui_keys", only_examples):
		var d2 = read_json(f)
		if typeof(d2) == TYPE_DICTIONARY:
			var owner := str(d2.get("_meta", {}).get("owner", ""))
			for k in d2.get("keys", {}).keys():
				var e: Dictionary = (d2["keys"][k] as Dictionary).duplicate()
				e["owner"] = owner
				_ui_keys[str(k)] = e
	for f in list_json(base + "/minigames/obs"):
		var d3 = read_json(f)
		if typeof(d3) == TYPE_DICTIONARY:
			_obs[str(d3.get("_meta", {}).get("kind", f.get_file().get_basename()))] = d3.get("obs", {})
	var m = read_json(root + "/art/manifest.json")
	_manifest = m if typeof(m) == TYPE_DICTIONARY else {}
	var era_dirs := DirAccess.get_directories_at(base + "/era") if DirAccess.dir_exists_absolute(base + "/era") \
		else PackedStringArray()
	for era_dir in era_dirs:
		var st = read_json(base + "/era/" + era_dir + "/stage.json")
		if typeof(st) == TYPE_DICTIONARY:
			_stage_files[era_dir] = CardState.int_restore(st)
	for f in list_json_recursive(root + "/text"):
		var d4 = read_json(f)
		if typeof(d4) != TYPE_DICTIONARY:
			_warnings.append("%s: cannot parse human text; file skipped" % f)
			continue
		for k in d4.keys():
			if not str(k).begins_with("_"):
				_text[str(k)] = d4[k]
	_load_ai_text()
	_load_packs()
	for w in _warnings:
		print("CardDB note: " + w)


# W2 #212：AI 文件必须登记完整来源；缺来源、重复键或坏条目均不静默覆盖。
# 2026-10-22：问题记进 warnings（不挡新局）；validate_main 仍把它们报成 V26 错。
func _load_ai_text() -> void:
	var source_re := RegEx.create_from_string("^ai:[^:]+:[^:]+:[0-9]{4}-[0-9]{2}-[0-9]{2}:.+$")
	for path in list_json_recursive(root + "/text_ai"):
		var doc = read_json(path)
		if typeof(doc) != TYPE_DICTIONARY:
			_warnings.append("%s: cannot parse AI text" % path)
			continue
		var meta = doc.get("_meta", {})
		var source = meta.get("_provenance", "") if typeof(meta) == TYPE_DICTIONARY else ""
		if typeof(source) != TYPE_STRING or source_re.search(source) == null:
			_warnings.append("%s: missing or invalid AI text provenance" % path)
			continue
		var keys: Array = doc.keys()
		keys.sort()
		for key in keys:
			if str(key).begins_with("_"):
				continue
			if typeof(doc[key]) != TYPE_DICTIONARY:
				_warnings.append("%s: AI text entry %s is not an object" % [path, key])
				continue
			if _ai_text.has(key):
				_warnings.append("%s: duplicate AI text key %s" % [path, key])
				continue
			var entry: Dictionary = doc[key].duplicate(true)
			entry["_provenance"] = source
			_ai_text[key] = entry


# 剧情插件：每个插件一层，不与人写层、AI 层合并（按字段往下找才成立）。
func _load_packs() -> void:
	var res := Packs.load_packs(_pack_cfg, _known_text_key, _warnings)
	_packs = res["loaded"]
	_pack_info = res["info"]
	_pack_files = res["files"]


## 正文键在骨架里有没有（插件里没有对应的键就跳过那一条）
func _known_text_key(key: String) -> bool:
	if _cards.has(key) or _ui_keys.has(key) or _persons.has(key):
		return true
	if key.begins_with("stage."):
		return _stage_files.has(key.substr(6))
	if key.begins_with("item.") or key.begins_with("cb.word."):
		return true
	for kind in _obs.keys():
		if (_obs[kind] as Dictionary).has(key):
			return true
	return false


func _load_rules() -> void:
	var overrides: Dictionary = {}
	for f in list_json(root + "/rules"):
		var d = read_json(f)
		if typeof(d) != TYPE_DICTIONARY:
			_errors.append("rules/%s: cannot parse" % f.get_file())
			continue
		var name := f.get_file().get_basename()
		if name == "balance_overrides":
			overrides = CardState.int_restore(d)
		else:
			_rules[name] = CardState.int_restore(d)
	for name in overrides.keys():
		if str(name).begins_with("_"):
			continue
		if not _rules.has(name) or typeof(overrides[name]) != TYPE_DICTIONARY:
			_errors.append("rules/balance_overrides.json: unknown or malformed rule %s" % name)
			continue
		_rules[name] = _merge_override(_rules[name], overrides[name], str(name))


func _load_persons_cast() -> void:
	var cast = read_json(CAST_PATH)
	if typeof(cast) == TYPE_DICTIONARY:
		for pid in cast.get("npcs", {}).keys():
			_persons[str(pid)] = {"cast": true}


# ---------------- 查 ----------------
## 只读副本；没有返回 {}
func def(id: String) -> Dictionary:
	return (_cards[id] as Dictionary).duplicate(false) if _cards.has(id) else {}


func has(id: String) -> bool:
	return _cards.has(id)


## 排好序
func ids_of(type: StringName) -> PackedStringArray:
	return PackedStringArray(_by_type.get(str(type), []))


## weight > 0、年代命中（或 "*"）、排好序
func pool(type: StringName, era: String) -> PackedStringArray:
	var out := PackedStringArray()
	for id in ids_of(type):
		var c: Dictionary = _cards[id]
		if int(c.get("weight", 10)) <= 0:
			continue
		var eras: Array = c.get("era", [])
		if eras.has("*") or eras.has(era):
			out.append(id)
	return out


## cast.json 的 npcs + 各文件的 persons 块
func persons() -> Dictionary:
	return _persons.duplicate(true)


## rules/<name>.json 深合并 balance_overrides
func rules(name: String) -> Dictionary:
	return (_rules.get(name, {}) as Dictionary).duplicate(true)


func tags() -> Dictionary:
	return _tags.duplicate(true)


## 覆盖层原样（可能为空）
func text_entry(id: String) -> Dictionary:
	var e = _text.get(id, {})
	return e.duplicate(true) if typeof(e) == TYPE_DICTIONARY else {}


## AI 覆盖层只读副本；text_entry 仍只返回人写层，避免审核把 AI 当成人写。
func ai_text_entry(id: String) -> Dictionary:
	return (_ai_text.get(id, {}) as Dictionary).duplicate(true)


## 按字段查正文：剧情插件（叠在最上面的先）→ 人写层 → AI 层；都没有（或是空串）返回 ""
func text_value(id: String, field: String) -> String:
	for i in range(_packs.size() - 1, -1, -1):
		var v = _dig_text((_packs[i]["text"] as Dictionary).get(id), field)
		if typeof(v) == TYPE_STRING and v != "":
			return v
	var human = _dig_text(_text.get(id), field)
	if typeof(human) == TYPE_STRING and human != "":
		return human
	var ai = _dig_text(_ai_text.get(id), field)
	return ai if typeof(ai) == TYPE_STRING else ""


## 这段正文由哪一层给出："pack:<id>" "human" "ai"；都没有返回 ""
func text_source(id: String, field: String) -> String:
	var hit := pack_hit(id, field)
	if not hit.is_empty():
		return "pack:" + str(hit["pack"])
	var human = _dig_text(_text.get(id), field)
	if typeof(human) == TYPE_STRING and human != "":
		return "human"
	var ai = _dig_text(_ai_text.get(id), field)
	return "ai" if typeof(ai) == TYPE_STRING and ai != "" else ""


## 叠在最上面、给出这段正文的插件：{pack, source, provenance, value}；没有返回 {}
func pack_hit(id: String, field: String) -> Dictionary:
	for i in range(_packs.size() - 1, -1, -1):
		var p: Dictionary = _packs[i]
		var v = _dig_text((p["text"] as Dictionary).get(id), field)
		if typeof(v) == TYPE_STRING and v != "":
			return {"pack": p["id"], "source": p["source"], "provenance": p["provenance"], "value": v}
	return {}


## 某个插件里这一条的只读副本
func pack_text_entry(pack_id: String, id: String) -> Dictionary:
	for p in _packs:
		if str(p["id"]) == pack_id:
			var e = (p["text"] as Dictionary).get(id, {})
			return (e as Dictionary).duplicate(true) if typeof(e) == TYPE_DICTIONARY else {}
	return {}


## 找到的插件（不含正文）：{id, dir, state: loaded|disabled|skipped, reason, name, version, order, source, …}；
## loaded 的按叠放顺序排在前面
func packs() -> Array:
	var out: Array = []
	for p in _packs:
		var row: Dictionary = (p as Dictionary).duplicate(true)
		row["keys"] = (row["text"] as Dictionary).size()
		row.erase("text")
		out.append(row)
	for p in _pack_info:
		if str(p["state"]) != "loaded":
			out.append((p as Dictionary).duplicate(true))
	return out


## 正文层（人写坏文件、AI 层、剧情插件）的问题；不挡新局，validate_main 会报
func warnings() -> PackedStringArray:
	return _warnings.duplicate()


static func _dig_text(e, path: String):
	var cur = e
	for part in path.split("."):
		if typeof(cur) != TYPE_DICTIONARY or not cur.has(part):
			return null
		cur = cur[part]
	return cur


## 牌 id、"<牌 id>#<字段>"、界面键、观察键、人物 id 都行；找不到返回 ""
func brief_of(ref: String) -> String:
	var hash_at := ref.find("#")
	if hash_at >= 0:
		var id := ref.substr(0, hash_at)
		var field := ref.substr(hash_at + 1)
		var c: Dictionary = _cards.get(id, {})
		var parts := field.split(".")
		if parts.size() == 2 and (parts[0] == "choices" or parts[0] == "slots"):
			for row in _all_rows(c, parts[0]):
				if str(row.get("id", "")) == parts[1] and str(row.get("brief", "")) != "":
					return str(row["brief"])
		if c.is_empty() and id.begins_with("stage."):
			return str(_stage_files.get(id.substr(6), {}).get("brief", ""))
		return str(c.get("brief", ""))
	if _cards.has(ref):
		return str(_cards[ref].get("brief", ""))
	if _ui_keys.has(ref):
		return str(_ui_keys[ref].get("brief", ""))
	for kind in _obs.keys():
		if (_obs[kind] as Dictionary).has(ref):
			return str(_obs[kind][ref].get("brief", ""))
	if _persons.has(ref):
		return str(_persons[ref].get("brief", ""))
	return ""


func obs_catalog(kind: StringName) -> Dictionary:
	return (_obs.get(str(kind), {}) as Dictionary).duplicate(true)


func art_manifest() -> Dictionary:
	return _manifest.duplicate(true)


## stages.json 里第 index 关，并上那一年的 stage.json（键 "intro" 下）
func stage(index: int) -> Dictionary:
	var key := "stage:" + str(index)
	if not _deal_cache.has(key):
		var found: Dictionary = {}
		for s in _rules.get("stages", {}).get("stages", []):
			if int(s.get("index", -1)) == index:
				found = s.duplicate(true)
				found["intro"] = (_stage_files.get(str(s.get("era", "")), {}) as Dictionary).duplicate(true)
				break
		_deal_cache[key] = found
	return _deal_cache[key]


## 机制数据（不含正文、brief、_provenance、_doc 等 _ 开头的键）的 sha256
func hash() -> String:
	var sig := _rules.hash() ^ _cards.hash() ^ _persons.hash()
	if _hash_cache == "" or _hash_sig != sig:
		var mech: Dictionary = {}
		for id in _cards.keys():
			mech[id] = strip_notes(_cards[id])
		var rules_mech: Dictionary = {}
		for name in _rules.keys():
			rules_mech[name] = strip_notes(_rules[name])
		var ctx := HashingContext.new()
		ctx.start(HashingContext.HASH_SHA256)
		ctx.update(JSON.stringify({"cards": mech, "rules": rules_mech, "persons": strip_notes(_persons)}, "", true, true).to_utf8_buffer())
		_hash_cache = ctx.finish().hex_encode()
		_hash_sig = sig
	return _hash_cache


func _all_loaded_paths() -> PackedStringArray:
	var out := PackedStringArray()
	out.append_array(list_json(root + "/rules"))
	for rel in card_files(root, only_examples):
		out.append(root + "/" + rel)
	out.append_array(key_files(root, "tags", only_examples))
	out.append_array(key_files(root, "ui_keys", only_examples))
	out.append_array(list_json_recursive(root + "/text"))
	out.append_array(list_json_recursive(root + "/text_ai"))
	out.append_array(_pack_paths())
	return out


# 插件目录里现在有的清单与正文（缓存失效用；不挂载 .pck）
func _pack_paths() -> PackedStringArray:
	var out := PackedStringArray()
	for dir in _pack_cfg.get("dirs", PackedStringArray()):
		if not DirAccess.dir_exists_absolute(dir):
			continue
		var folders := DirAccess.get_directories_at(dir)
		folders.sort()
		for folder in folders:
			var base := str(dir).path_join(folder)
			if FileAccess.file_exists(base.path_join(Packs.MANIFEST)):
				out.append(base.path_join(Packs.MANIFEST))
				out.append_array(list_json_recursive(base.path_join("text")))
	return out


func _record_sig() -> void:
	_hash_sig = _rules.hash() ^ _cards.hash() ^ _persons.hash()
	_dir_sig = Array(_all_loaded_paths())
	_file_sources.clear()
	for p in _dir_sig:
		_file_sources[p] = FileAccess.get_file_as_string(str(p)) if FileAccess.file_exists(str(p)) else ""


func _sig_matches() -> bool:
	if (_rules.hash() ^ _cards.hash() ^ _persons.hash()) != _hash_sig:
		return false
	if root == DEFAULT_ROOT:
		return true
	var cur := Array(_all_loaded_paths())
	if cur != _dir_sig:
		return false
	for p in _dir_sig:
		var s := FileAccess.get_file_as_string(str(p)) if FileAccess.file_exists(str(p)) else ""
		if _file_sources.get(p, "") != s:
			return false
	return true


func errors() -> PackedStringArray:
	return _errors.duplicate()


# ---------------- W0 加的公开辅助（列在 PR 里） ----------------
## 这张牌在哪个文件（相对数据根）
func file_of(id: String) -> String:
	return str(_file_of.get(id, ""))


## 读入顺序（新手指引的步骤按文件里的顺序参加挑选，§7.10.3）
func order_of(id: String) -> int:
	return int(_order.get(id, -1))


## 本套数据里步骤文件的 _test（例：{"d1_3": [...]}）
func guide_test() -> Dictionary:
	return _guide_test.duplicate(true)


func ui_keys() -> Dictionary:
	return _ui_keys.duplicate(true)


func all_ids() -> PackedStringArray:
	var out := PackedStringArray(_cards.keys())
	out.sort()
	return out


## 这套数据的根目录（真数据 = root；例子集 = root/_examples）
func set_base() -> String:
	return root + "/_examples" if only_examples else root


# ---------------- 静态工具（校验器也用） ----------------
## 一套数据里的牌文件，相对数据根，排好序
static func card_files(p_root: String, examples: bool) -> PackedStringArray:
	var out := PackedStringArray()
	if examples:
		for f in list_json_recursive(p_root + "/_examples"):
			var rel := f.substr(p_root.length() + 1)
			var rel_ex := rel.trim_prefix("_examples/")
			if EXAMPLE_NON_CARD.has(rel_ex) or rel_ex.begins_with("minigames/obs/") or rel_ex.get_file() == "stage.json":
				continue
			out.append(rel)
	else:
		for d in CARD_DIRS:
			for f in list_json_recursive(p_root + "/" + d):
				var rel2 := f.substr(p_root.length() + 1)
				if rel2.get_file() == "stage.json":
					continue
				out.append(rel2)
		if FileAccess.file_exists(p_root + "/minigames/items.json"):
			out.append("minigames/items.json")
	out.sort()
	return out


## 标签文件 / 界面键文件（两套都读真数据目录；例子集另加 _examples/<名>.json）
static func key_files(p_root: String, dir_name: String, examples: bool) -> PackedStringArray:
	var out := list_json(p_root + "/" + dir_name)
	if examples and FileAccess.file_exists(p_root + "/_examples/" + dir_name + ".json"):
		out.append(p_root + "/_examples/" + dir_name + ".json")
	return out


static var _special_num_re: RegEx = null


static func read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var source := FileAccess.get_file_as_string(path)
	if _json_cache.has(path) and _json_cache[path]["s"] == source:
		var cached = _json_cache[path]["d"]
		return cached.duplicate(true) if typeof(cached) in [TYPE_DICTIONARY, TYPE_ARRAY] else cached
	if _special_num_re == null:
		_special_num_re = RegEx.create_from_string("[:\\[,][\\s]*-?([0-9]{16,}|0[0-9]|[0-9]+(\\.[0-9]|[eE][+-]?[0-9]))")
	var parser := JSON.new()
	var restored: Variant = null
	if _special_num_re.search(source) == null:
		if parser.parse(source) != OK:
			return null
		restored = CardState.int_restore(parser.data)
	else:
		var prefix := "__g01_int__"
		while source.contains(prefix):
			prefix += "_"
		if parser.parse(_protect_integers(source, prefix)) != OK:
			return null
		restored = _restore_integer_tokens(parser.data, prefix)
	_json_cache[path] = {"s": source, "d": restored.duplicate(true) if typeof(restored) in [TYPE_DICTIONARY, TYPE_ARRAY] else restored}
	return restored


static func list_json(dir: String) -> PackedStringArray:
	var out := PackedStringArray()
	if not DirAccess.dir_exists_absolute(dir):
		return out
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".json"):
			out.append(dir + "/" + f)
	out.sort()
	return out


static func list_json_recursive(dir: String) -> PackedStringArray:
	var out := list_json(dir)
	if DirAccess.dir_exists_absolute(dir):
		for sub in DirAccess.get_directories_at(dir):
			out.append_array(list_json_recursive(dir + "/" + sub))
	out.sort()
	return out


static func deep_merge(base: Dictionary, over: Dictionary) -> Dictionary:
	var out := base.duplicate(true)
	for k in over.keys():
		if typeof(out.get(k)) == TYPE_DICTIONARY and typeof(over[k]) == TYPE_DICTIONARY:
			out[k] = deep_merge(out[k], over[k])
		else:
			out[k] = over[k]
	return out


## 去掉 brief 和 _ 开头的键（递归）
static func strip_notes(v):
	match typeof(v):
		TYPE_DICTIONARY:
			var out: Dictionary = {}
			for k in v.keys():
				var key := str(k)
				if key in ["brief", "text"] or key.begins_with("_"):
					continue
				out[k] = strip_notes(v[k])
			return out
		TYPE_ARRAY:
			var arr: Array = []
			for x in v:
				arr.append(strip_notes(x))
			return arr
	return v


static func _all_rows(c: Dictionary, field: String) -> Array:
	var rows: Array = []
	for r in c.get(field, []):
		if typeof(r) == TYPE_DICTIONARY:
			rows.append(r)
	if field == "slots":
		for ch in c.get("choices", []):
			if typeof(ch) == TYPE_DICTIONARY and typeof(ch.get("check")) == TYPE_DICTIONARY:
				rows.append_array(ch["check"].get("slots", []))
		if typeof(c.get("resolve", {}).get("haggle")) == TYPE_DICTIONARY:
			rows.append_array(c["resolve"]["haggle"].get("slots", []))
	return rows


# 平衡覆盖只允许替换已有键、保持原有类型；无效覆盖记录为数据库错误而不污染规则。
func _merge_override(base: Dictionary, over: Dictionary, path: String) -> Dictionary:
	var out := base.duplicate(true)
	var keys := over.keys()
	keys.sort()
	for key in keys:
		if not out.has(key):
			_errors.append("rules/balance_overrides.json: unknown key %s.%s" % [path, key])
		elif typeof(out[key]) != typeof(over[key]):
			_errors.append("rules/balance_overrides.json: changed type %s.%s" % [path, key])
		elif typeof(out[key]) == TYPE_DICTIONARY:
			out[key] = _merge_override(out[key], over[key], path + "." + str(key))
		else:
			out[key] = over[key]
	return out


## 只读候选 [id, weight, conditions, tags, valence]；避免预测在每张牌上复制完整定义。
func deal_rows(type: StringName, era: String) -> Array:
	var key := str(type) + ":" + era
	if not _deal_cache.has(key):
		var rows: Array = []
		for id in pool(type, era):
			var d: Dictionary = _cards[id]
			var row: Array = [id, int(d.get("weight", 10)), d.get("conditions", {}).duplicate(true), d.get("tags", []).duplicate(true), str(d.get("valence", ""))]
			_freeze(row)
			rows.append(row)
		rows.make_read_only()
		_deal_cache[key] = rows
	return _deal_cache[key]


static func _freeze(v) -> void:
	if typeof(v) == TYPE_ARRAY:
		for child in v:
			_freeze(child)
		v.make_read_only()
	elif typeof(v) == TYPE_DICTIONARY:
		for child in v.values():
			_freeze(child)
		v.make_read_only()


# JSON 原生解析把整数先转成 double；保护整数字面量避免 2^53 以上的存档数丢精度。
static func _protect_integers(source: String, prefix: String) -> String:
	var out := PackedStringArray()
	var integer_re := RegEx.create_from_string("^-?(0|[1-9][0-9]*)$")
	var number_re := RegEx.create_from_string("^-?(0|[1-9][0-9]*)(\\.[0-9]+)?([eE][+-]?[0-9]+)?$")
	var i := 0
	while i < source.length():
		var ch := source[i]
		if ch == '\"':
			var start := i
			i += 1
			while i < source.length():
				if source[i] == "\\":
					i += 2
				elif source[i] == '\"':
					i += 1
					break
				else:
					i += 1
			out.append(source.substr(start, i - start))
		elif ch == "-" or (ch >= "0" and ch <= "9"):
			var start := i
			i += 1
			while i < source.length() and "0123456789.eE+-".contains(source[i]):
				i += 1
			var token := source.substr(start, i - start)
			if number_re.search(token) == null:
				return "__G01_INVALID_JSON_NUMBER__"
			if integer_re.search(token) != null and token.is_valid_int():
				out.append('\"' + prefix + token + '\"')
			else:
				out.append(token)
		else:
			out.append(ch)
			i += 1
	return "".join(out)


static func _restore_integer_tokens(value, prefix: String):
	if typeof(value) == TYPE_STRING and str(value).begins_with(prefix):
		return str(value).substr(prefix.length()).to_int()
	if typeof(value) == TYPE_ARRAY:
		for i in range(value.size()):
			value[i] = _restore_integer_tokens(value[i], prefix)
	elif typeof(value) == TYPE_DICTIONARY:
		for key in value.keys():
			value[key] = _restore_integer_tokens(value[key], prefix)
	return value

