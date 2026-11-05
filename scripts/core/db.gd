# 数据库：启动时读入 data/ 下全部 JSON（剧情、顾客、物品、人物、页面……）。
# 剧情与内容全部是数据；代码只解释它们（docs/INTERFACES.md）。
extends RefCounted
class_name DB

static var _inst: DB = null

var cast: Dictionary = {}          # npc_id -> def
var edges: Array = []
var outside_accounts: Dictionary = {}
var items: Dictionary = {}         # def_id -> def
var pages: Dictionary = {}
var factions: Dictionary = {}
var medbook: Dictionary = {}
var codebook: Dictionary = {}
var night: Dictionary = {}
var layout: Dictionary = {}
var palette: Array = []
var flow: Dictionary = {}
var scripts: Dictionary = {}       # script_id -> {id,title,steps}
var sessions: Dictionary = {}      # session_id -> def
var errors: Array = []

static func get_db() -> DB:
	if _inst == null:
		_inst = DB.new()
		_inst.load_all()
	return _inst

# 退出前释放静态缓存（否则 Godot 退出时报 ObjectDB 泄漏）
static func shutdown() -> void:
	_inst = null
	var Cond = load("res://scripts/core/cond.gd")
	Cond.clear_cache()

static func reload() -> DB:
	_inst = null
	return get_db()

func load_all() -> void:
	var c: Dictionary = _json("res://data/cast.json")
	cast = c.get("npcs", {})
	edges = c.get("edges", [])
	outside_accounts = c.get("outside_accounts", {})
	for f in _list("res://data/items", ".json"):
		var d: Dictionary = _json(f)
		var its: Dictionary = d.get("items", {})
		for k in its:
			if items.has(k):
				errors.append("物品重复定义：%s（%s）" % [k, f])
			items[k] = its[k]
			items[k]["def_id"] = k
	pages = _json("res://data/pages.json").get("pages", {})
	factions = _json("res://data/factions.json")
	medbook = _json("res://data/medbook.json")
	codebook = _json("res://data/codebook.json")
	night = _json("res://data/night.json")
	layout = _json("res://data/layout.json")
	palette = _json("res://data/palette.json").get("colors", [])
	flow = _json("res://data/story/flow.json")
	for f in _list("res://data/story", ".json"):
		if f.get_file() == "flow.json":
			continue
		var s: Dictionary = _json(f)
		if s.has("id"):
			scripts[s["id"]] = s
	for f in _list("res://data/sessions", ".json"):
		var s2: Dictionary = _json(f)
		if s2.has("id"):
			sessions[s2["id"]] = s2

func _json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		errors.append("缺少数据文件：" + path)
		return {}
	var txt := FileAccess.get_file_as_string(path)
	var j := JSON.new()
	if j.parse(txt) != OK:
		errors.append("JSON 解析失败：%s 第 %d 行：%s" % [path, j.get_error_line(), j.get_error_message()])
		return {}
	if typeof(j.data) != TYPE_DICTIONARY:
		errors.append("JSON 顶层不是对象：" + path)
		return {}
	return j.data

func _list(dir: String, ext: String) -> Array:
	var out: Array = []
	var d := DirAccess.open(dir)
	if d == null:
		return out
	for f in d.get_files():
		if f.ends_with(ext):
			out.append(dir + "/" + f)
	out.sort()
	return out

func npc_label(id: String) -> String:
	if id == "you":
		return "你"
	if id == "narr" or id == "":
		return ""
	return str(cast.get(id, {}).get("label", id))

func npc_color(id: String) -> Color:
	if id == "you":
		return Color("#c99a5e")
	return Color(str(cast.get(id, {}).get("color", "#e8c88a")))

func hotspot(id: String) -> Rect2:
	var h: Dictionary = layout.get("hotspots", {}).get(id, {})
	var r: Array = h.get("rect", [0, 0, 0, 0])
	return Rect2(r[0], r[1], r[2], r[3])

func hotspot_label(id: String) -> String:
	return str(layout.get("hotspots", {}).get(id, {}).get("label", id))

func code_of(word: String) -> String:
	for w in codebook.get("words", []) + codebook.get("locked", []):
		if w["word"] == word:
			return str(w["code"])
	return "????"

func word_of(code: String) -> String:
	for w in codebook.get("words", []) + codebook.get("locked", []):
		if str(w["code"]) == code:
			return w["word"]
	return ""

static func tex(path: String) -> Texture2D:
	var p := path if path.begins_with("res://") else "res://" + path
	if ResourceLoader.exists(p):
		return load(p)
	return null
