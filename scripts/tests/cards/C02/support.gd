# C02 测试共用：读夹具、把一张牌摆进树、查斜体和百分号。不写 class_name。
extends RefCounted

const FIXTURES := "res://scripts/tests/cards/C02/fixtures"


static func setup_db() -> CardDB:
	var db := CardDB.load_all("res://data/cards", {"only_examples": true})
	CardText.setup(db)
	return db


static func read_json(path: String) -> Dictionary:
	var parsed: Variant = CardDB.read_json(path)
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	var restored: Variant = CardState.int_restore(parsed)
	return restored if typeof(restored) == TYPE_DICTIONARY else {}


static func examples() -> Array:
	return read_json(FIXTURES + "/all_examples.json").get("cards", [])


static func states() -> Dictionary:
	var doc := read_json(FIXTURES + "/states.json")
	var block: Variant = doc.get("states", {})
	return block if typeof(block) == TYPE_DICTIONARY else {}


static func mount(tree: SceneTree, view: Dictionary, mode: StringName, at: Vector2) -> CardWidget:
	var w: CardWidget = load("res://scenes/cards/card/CardWidget.tscn").instantiate()
	w.position = at
	tree.root.add_child(w)
	w.set_size_mode(mode)
	w.set_card(view)
	return w


static func art_base(view: Dictionary) -> Vector2i:
	var base := CardArt.base_size(str(view.get("art", "")))
	if base != Vector2i.ZERO:
		return base
	if str(view.get("type", "")) in ["person", "self", "contact"]:
		return Vector2i(48, 64)
	return Vector2i(64, 48)


## 换皮后插图在插图格 Well 里（格子裁掉多出来的部分），不再是牌的直接子节点。
static func art(w: Node) -> TextureRect:
	return w.get_node("Well/Art") as TextureRect


## 牌名放得下：一行时整行字宽不超过 Label 宽；放不下时两行、省略号，牌上有悬停提示写全名（b43）。
static func title_fits(w: CardWidget) -> bool:
	var title := w.get_node("Title") as Label
	if title.text == "":
		return true
	var font := title.get_theme_font("font")
	var px := title.get_theme_font_size("font_size")
	var width := font.get_string_size(title.text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	if title.autowrap_mode == TextServer.AUTOWRAP_OFF:
		return width <= title.size.x + 0.5 and not title.clip_text
	var two_lines := title.max_lines_visible == 2 and title.text_overrun_behavior == TextServer.OVERRUN_TRIM_ELLIPSIS
	return two_lines and (width <= title.size.x * 2.0 - float(px) or w.tooltip_text == title.text)


static func art_k(mode: StringName) -> int:
	if mode == &"zoom":
		return 4
	if mode == &"mini":
		return 1
	return 2


static func italic(font: Font) -> bool:
	if font is FontVariation:
		return (font as FontVariation).variation_transform != Transform2D.IDENTITY
	return false


static func has_pct(node: Node) -> bool:
	var bad := false
	for n in _walk(node):
		var txt := ""
		if n is Label:
			txt = (n as Label).text
		elif n is Button:
			txt = (n as Button).text
		elif n is RichTextLabel:
			txt = (n as RichTextLabel).get_parsed_text()
		if txt.contains("%"):
			bad = true
	return bad


static func joined_text(node: Node) -> String:
	var parts: PackedStringArray = []
	for n in _walk(node):
		if n is Label:
			parts.append((n as Label).text)
		elif n is Button:
			parts.append((n as Button).text)
	return "\n".join(parts)


static func find_uid(node: Node, uid: String) -> CardWidget:
	if node is CardWidget:
		var w := node as CardWidget
		if w.name != "Zoom" and w.get_uid() == uid:
			return w
	for c in node.get_children():
		var hit := find_uid(c, uid)
		if hit != null:
			return hit
	return null


static func _walk(n: Node) -> Array:
	var out: Array = [n]
	for c in n.get_children():
		if str(c.name) == "Zoom":
			continue
		out.append_array(_walk(c))
	return out
