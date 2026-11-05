# 美术解析：美术 id → 正式图（art/cards/**）→ AI 图（art/ai/**，纯人工包跳过）→ 占位图（开发版）→ 缺图方块。
# legacy 条目按占位对待，发行版不返回。主人 C02。合同 §4.8、§7.8。
class_name CardArt
extends RefCounted

const MANIFEST := "res://data/cards/art/manifest.json"

static var _m: Dictionary = {}
static var _tex: Dictionary = {}


static func texture(art_id: String) -> Texture2D:
	var p := path(art_id)
	if p == "":
		return null
	if _tex.has(p) and _tex[p] is Texture2D:
		return _tex[p]
	var full := "res://" + p
	if not ResourceLoader.exists(full):
		return null
	var tex := load(full) as Texture2D
	if tex != null:
		_tex[p] = tex
	return tex


## 实际会用的文件路径（相对项目根）。查找顺序：human（非 legacy）→ ai（非 no_ai）→ placeholder（开发版）→ missing（开发版）。
static func path(art_id: String) -> String:
	var e := _entry(art_id)
	var legacy := bool(e.get("legacy", false))
	var human := str(e.get("human", ""))
	var human_ok := human != "" and ResourceLoader.exists("res://" + human)
	if human_ok and not legacy:
		return human
	if not OS.has_feature("no_ai"):
		var ai := str(e.get("ai", ""))
		if ai != "" and ResourceLoader.exists("res://" + ai):
			return ai
	if CardShip.is_ship():
		return ""
	if legacy and human_ok:
		return human
	var ph := str(e.get("placeholder", ""))
	if ph != "" and ResourceLoader.exists("res://" + ph):
		return ph
	var missing := str(_manifest().get("missing", ""))
	if missing != "" and ResourceLoader.exists("res://" + missing):
		return missing
	return ""


static func is_placeholder(art_id: String) -> bool:
	var p := path(art_id)
	if p == "":
		return true
	var e := _entry(art_id)
	if p == str(e.get("human", "")) and not bool(e.get("legacy", false)):
		return false
	if not OS.has_feature("no_ai") and p == str(e.get("ai", "")):
		return false
	return true


## 解析结果是清单的缺图方块，或什么文件都没有。
static func is_missing(art_id: String) -> bool:
	var p := path(art_id)
	if p == "":
		return true
	var e := _entry(art_id)
	if p == str(e.get("human", "")) or p == str(e.get("ai", "")) or p == str(e.get("placeholder", "")):
		return false
	return true


static func base_size(art_id: String) -> Vector2i:
	var b: Variant = _entry(art_id).get("base", [])
	if typeof(b) != TYPE_ARRAY or (b as Array).size() < 2:
		return Vector2i.ZERO
	return Vector2i(int(b[0]), int(b[1]))


## 9 宫格边距 [左, 上, 右, 下]；清单没有 nine 时返回空数组。
static func nine_margins(art_id: String) -> Array:
	var n: Variant = _entry(art_id).get("nine", [])
	if typeof(n) != TYPE_ARRAY:
		return []
	var out: Array = []
	for v in n:
		out.append(int(v))
	return out


static func _entry(art_id: String) -> Dictionary:
	var art: Variant = _manifest().get("art", {})
	if typeof(art) != TYPE_DICTIONARY:
		return {}
	var e: Variant = (art as Dictionary).get(art_id, {})
	return e if typeof(e) == TYPE_DICTIONARY else {}


static func _manifest() -> Dictionary:
	if _m.is_empty():
		var d: Variant = CardDB.read_json(MANIFEST)
		if typeof(d) == TYPE_DICTIONARY:
			_m = d
	return _m
