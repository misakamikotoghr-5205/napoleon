# 远洋战役营地（高清主画面、事务面板、日终 / 开部 / 换部 / 终局面板）的界面文字：data/hd/hub_ui.json。
# 只读、缓存。没有 class_name，用的地方 preload("res://scripts/cards/ui/hub/hub_data.gd")。说明：docs/cards/HD_UI.md。
extends RefCounted

const HdText = preload("res://scripts/cards/ui/hd/hd_text.gd")
const UI_PATH := "res://data/hd/hub_ui.json"
## 剧情 VN 的演出表：营地背景跟着当前这一场的第一张背景走
const CAST_PATH := "res://data/hd/vn_cast.json"

static var _ui: Dictionary = {}
static var _cast: Dictionary = {}


static func ui() -> Dictionary:
	if _ui.is_empty():
		_ui = _read(UI_PATH)
	return _ui


## 一条界面文字；key 可以用点号进子表（"gauge.treasury"）；args 填 {占位符}。没有这条回空串。
static func text(key: String, args: Dictionary = {}) -> String:
	var node = ui().get("text", {})
	for part in key.split("."):
		if typeof(node) != TYPE_DICTIONARY or not (node as Dictionary).has(part):
			return ""
		node = node[part]
	if typeof(node) != TYPE_STRING:
		return ""
	return _fill(str(node), args)


## 一种牌的样子（标签、圆章里的字、上面的小字）；uid 的前缀（demand: item: prop: companion:）按种类取
static func card_spec(uid: String) -> Dictionary:
	var cards = ui().get("text", {}).get("cards", {})
	if typeof(cards) != TYPE_DICTIONARY:
		return {}
	var key := uid
	if uid.contains(":"):
		key = uid.get_slice(":", 0)
	var spec = cards.get(key, {})
	return spec if typeof(spec) == TYPE_DICTIONARY else {}


## 这一场开场的背景（vn_cast.json scenes.<id>.bg 的第一项）：{id, variant}
static func scene_bg(scene_id: String) -> Dictionary:
	if _cast.is_empty():
		_cast = _read(CAST_PATH)
	var s = _cast.get("scenes", {}).get(scene_id, {})
	if typeof(s) != TYPE_DICTIONARY:
		return {}
	for row in s.get("bg", []):
		if typeof(row) == TYPE_DICTIONARY:
			return {"id": str(row.get("id", "")), "variant": str(row.get("variant", ""))}
	return {}


## 两个标题说的是不是同一件事（见 hd_text.gd）
static func same_title(a: String, b: String) -> bool:
	return HdText.same_title(a, b)


## 旧对话框分页还原成一行一句（见 hd_text.gd）
static func unpage(text: String) -> String:
	return HdText.unpage(text)


static func _fill(s: String, args: Dictionary) -> String:
	var out := s
	for k in args:
		out = out.replace("{" + str(k) + "}", str(args[k]))
	return out


static func _read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}
