# Writes the spot body masks (items.json "spot": {"opaque": ...}) from the item art the spot game shows.
# Run it after an item picture changes (C12_evidence goes red when a mask no longer matches its picture):
#   $GODOT --headless --path . -s res://scripts/tests/cards/C12/spot_body_tool.gd -- --write
# Without --write it only lists the item cards whose mask is stale. It edits the file as text (only each
# card's "spot" object), so the rest of K11's file keeps its formatting. Owner C12.
extends SceneTree

const Marks = preload("res://scripts/cards/minigames/spot/spot_marks.gd")
const ITEMS := "res://data/cards/minigames/items.json"


func _initialize() -> void:
	var write := OS.get_cmdline_user_args().has("--write")
	var text := FileAccess.get_file_as_string(ITEMS)
	var doc: Dictionary = JSON.parse_string(text)
	var stale := 0
	for card in doc.get("cards", []):
		if not (card.get("minigames", []) as Array).has("spot"):
			continue
		var mask := Marks.body_mask(Marks.base_image("item." + str(card.get("template", ""))))
		var spec: Dictionary = card.get("spot", {})
		if str(spec.get("opaque", "")) == mask:
			continue
		stale += 1
		print("STALE ", card.get("id", ""))
		text = _set_body(text, str(card.get("id", "")), mask)
	if write and stale > 0:
		if typeof(JSON.parse_string(text)) != TYPE_DICTIONARY:
			push_error("spot_body_tool: the edited file does not parse; nothing written")
			quit(1)
			return
		var f := FileAccess.open(ITEMS, FileAccess.WRITE)
		f.store_string(text)
		f.close()
		print("WROTE ", stale)
	print("DONE stale=", stale)
	quit(0)


## The card's "spot" object (it holds only "opaque") replaced by one with this mask, indented as json.dumps
## (indent 2) writes it.
func _set_body(text: String, id: String, mask: String) -> String:
	var at := text.find("\"id\": \"%s\"" % id)
	var key := text.find("\"spot\": {", at)
	if at < 0 or key < 0:
		push_error("spot_body_tool: no spot spec for " + id)
		return text
	var line_start := text.rfind("\n", key) + 1
	var pad := text.substr(line_start, key - line_start)
	var close := text.find("}", key)
	var body := "\"spot\": {\n%s  \"opaque\": \"%s\"\n%s}" % [pad, mask, pad]
	return text.substr(0, key) + body + text.substr(close + 1)
