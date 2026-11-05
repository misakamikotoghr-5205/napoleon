## Map UI text and public command descriptions; no campaign internals are read here.
extends RefCounted

const PATH := "res://data/hd/map_ui.json"
static var _data: Dictionary = {}

static func text(key: String, args: Dictionary = {}) -> String:
	if _data.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		if typeof(parsed) == TYPE_DICTIONARY:
			_data = parsed
	var value: Variant = _data
	for part in key.split("."):
		if typeof(value) != TYPE_DICTIONARY or not value.has(part):
			return ""
		value = value[part]
	return str(value).format(args) if typeof(value) == TYPE_STRING else ""

static func error(code: String) -> String:
	var message := text("errors." + code)
	return message if message != "" else text("errors.unknown")

static func card_name(id: String, fallback: String = "") -> String:
	var label := text("cards." + id)
	return label if label != "" else (fallback if fallback != "" and fallback != id else text("march_card"))

static func card_hint(row: Dictionary) -> String:
	var lines := PackedStringArray([text("card_hint")])
	for key in ["effects", "coins"]:
		var effects: Dictionary = row.get(key, {})
		for id in effects:
			var label := text("resources." + str(id))
			if label != "":
				lines.append(label + " " + ("+" if int(effects[id]) > 0 else "") + str(effects[id]))
	if int(row.get("reveal", 0)) > 0:
		lines.append(text("card_reveal", {"n": int(row["reveal"])}))
	if bool(row.get("ignore_forced", false)):
		lines.append(text("card_ignore_forced"))
	if int(row.get("voyage_minus", 0)) > 0:
		lines.append(text("card_voyage", {"n": int(row["voyage_minus"])}))
	return "\n".join(lines)

static func node(map: Dictionary, id: String) -> Dictionary:
	for row in map.get("nodes", []):
		if str(row.get("id", "")) == id:
			return row
	return {}

static func command(action: String) -> Dictionary:
	var head := action.get_slice(":", 0)
	var tail := action.substr(head.length() + 1) if action.contains(":") else ""
	match head:
		"visit": return {"cmd": &"campaign.visit", "args": {"place": tail}}
		"trade": return {"cmd": &"campaign.trade", "args": {"kind": tail}}
		"activity": return {"cmd": &"campaign.activity", "args": {"id": tail}}
		"schedule": return {"cmd": &"campaign.schedule", "args": {"action": tail}}
		"recruit": return {"cmd": &"campaign.recruit", "args": {"id": tail}}
		"demand": return {"cmd": &"campaign.demand", "args": {"id": tail, "action": "fulfill"}}
		"build": return {"cmd": &"campaign.build", "args": {}}
		"explore": return {"cmd": &"campaign.explore", "args": {}}
		"build_depot": return {"cmd": &"campaign.map_build", "args": {}}
		"muster": return {"cmd": &"campaign.map_muster", "args": {}}
		"fund": return {"cmd": &"campaign.fund", "args": {"support": tail == "yes"}}
	return {}

static func action_name(action: String) -> String:
	var label := text("actions." + action)
	if label != "":
		return label
	if action.begins_with("recruit:"):
		var id := action.trim_prefix("recruit:")
		return text("recruit_named", {"name": CardText.person_name(id)})
	return text("node_action")

static func destination(result: Dictionary) -> String:
	match str(result.get("kind", "")):
		"story": return "story:" + str(result.get("scene", ""))
		"event": return "event:" + str(result.get("event", ""))
		"battle": return "battle"
	return ""
