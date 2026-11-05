# 剧情 VN 的数据：界面文字 data/hd/vn_ui.json、人物叫法和每场演出表 data/hd/vn_cast.json。只读、缓存。
# 没有 class_name，用的地方 preload("res://scripts/cards/ui/vn/vn_data.gd")。说明：docs/cards/HD_UI.md。
extends RefCounted

const UI_PATH := "res://data/hd/vn_ui.json"
const CAST_PATH := "res://data/hd/vn_cast.json"
const POSITIONS := ["left", "center", "right"]
const EXPRS := ["normal", "smile", "angry", "sad", "surprise"]

static var _ui: Dictionary = {}
static var _cast: Dictionary = {}
static var _aliases: Array = []


static func ui() -> Dictionary:
	if _ui.is_empty():
		_ui = _read(UI_PATH)
	return _ui


static func cast() -> Dictionary:
	if _cast.is_empty():
		_cast = _read(CAST_PATH)
	return _cast


## 一条界面文字；args 填 {占位符}。没有这条就回空串（不把键名露给玩家）。
static func text(key: String, args: Dictionary = {}) -> String:
	var raw = ui().get("text", {}).get(key, "")
	return _fill(str(raw), args) if typeof(raw) == TYPE_STRING else ""


## 灰掉的抉择的原因（vn_ui.json 的 reason.<code>）；没有这条回空串
static func reason(code: String, args: Dictionary = {}) -> String:
	var group = ui().get("text", {}).get("reason", {})
	if typeof(group) != TYPE_DICTIONARY or not group.has(code):
		return ""
	return _fill(str(group[code]), args)


static func chars() -> Dictionary:
	var c = cast().get("chars", {})
	return c if typeof(c) == TYPE_DICTIONARY else {}


static func scene(scene_id: String, presentation: Dictionary = {}) -> Dictionary:
	var s = cast().get("scenes", {}).get(scene_id, {})
	var result: Dictionary = s.duplicate(true) if typeof(s) == TYPE_DICTIONARY else {}
	# A map event may supply its own staging; never mutate the cached cast table.
	for key in ["bg", "cast"]:
		if typeof(presentation.get(key)) == TYPE_ARRAY:
			result[key] = presentation[key].duplicate(true)
	for key in ["enter", "exit", "expr", "art"]:
		if typeof(presentation.get(key)) == TYPE_DICTIONARY:
			result[key] = presentation[key].duplicate(true)
	return result


static func protagonist() -> String:
	return str(cast().get("protagonist", ""))


static func max_on_stage() -> int:
	return clampi(int(cast().get("max_on_stage", 3)), 1, 3)


static func say_verbs() -> Array:
	var v = cast().get("say_verbs", [])
	return v if typeof(v) == TYPE_ARRAY else []


## 人物 id -> 立绘 id（清单 chara 条目的 id；没写就是人物 id 本身）
static func art_id(char_id: String, overrides: Dictionary = {}) -> String:
	if typeof(overrides.get(char_id)) == TYPE_STRING and not str(overrides[char_id]).is_empty():
		return str(overrides[char_id])
	var row = chars().get(char_id, {})
	if typeof(row) == TYPE_DICTIONARY and str(row.get("art", "")) != "":
		return str(row["art"])
	return char_id


## 全部叫法 [[叫法, 人物 id], ...]，长的在前（“埃德蒙·唐泰斯”先于“唐泰斯”）
static func aliases() -> Array:
	if not _aliases.is_empty():
		return _aliases
	var out: Array = []
	var table := chars()
	for id in table:
		var row = table[id]
		if typeof(row) != TYPE_DICTIONARY:
			continue
		for a in row.get("aliases", []):
			if str(a) != "":
				out.append([str(a), str(id)])
	out.sort_custom(func(x: Array, y: Array) -> bool:
		return str(x[0]).length() > str(y[0]).length() or (str(x[0]).length() == str(y[0]).length() and str(x[0]) < str(y[0])))
	_aliases = out
	return _aliases


## 测试换数据时用
static func clear_cache() -> void:
	_ui = {}
	_cast = {}
	_aliases = []


static func _read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


static func _fill(line: String, args: Dictionary) -> String:
	if args.is_empty():
		return line
	var clean := {}
	for k in args:
		var v = args[k]
		clean[k] = str(int(v)) if typeof(v) == TYPE_FLOAT else str(v)
	return line.format(clean)
