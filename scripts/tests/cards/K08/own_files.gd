# K08 测试只查归属表里自己的牌。CardDB.file_of 相对 data/cards，对照 ownership.json 的 K08 路径。
extends RefCounted

const TASK := "K08"
const DATA_ROOT := "data/cards/"


static func ids(db: CardDB, type: StringName) -> PackedStringArray:
	var rules := _rules()
	var out := PackedStringArray()
	for id in db.ids_of(type):
		if owns(db.file_of(id), rules):
			out.append(id)
	return out


static func rule_count() -> int:
	return _rules().size()


static func owns(rel: String, rules: Array) -> bool:
	var path := rel.replace("\\", "/")
	if path.begins_with("res://"):
		path = path.trim_prefix("res://")
	if path.begins_with(DATA_ROOT):
		path = path.trim_prefix(DATA_ROOT)
	for rule in rules:
		var kind := str(rule.get("kind", ""))
		var value := str(rule.get("value", ""))
		if kind == "prefix" and path.begins_with(value):
			return true
		if kind == "exact" and path == value:
			return true
	return false


static func _rules() -> Array:
	var out: Array = []
	var raw := FileAccess.get_file_as_string("res://docs/cards/ownership.json")
	var parsed = JSON.parse_string(raw)
	if typeof(parsed) != TYPE_DICTIONARY:
		return out
	var paths: Variant = (parsed as Dictionary).get("paths", {}).get(TASK, [])
	if typeof(paths) != TYPE_ARRAY:
		return out
	for item in paths:
		var glob := str(item).replace("\\", "/")
		if not glob.begins_with(DATA_ROOT):
			continue
		var rest := glob.trim_prefix(DATA_ROOT)
		if rest.ends_with("/**"):
			out.append({"kind": "prefix", "value": rest.trim_suffix("**")})
		else:
			out.append({"kind": "exact", "value": rest})
	return out
