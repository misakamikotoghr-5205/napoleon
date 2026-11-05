# Rogue v1 UI helpers shared by the stocktake overlay, the curio drawer, the scene shelf and the title box:
# frame colour per depth, labels, pixel art at an integer scale, paper card styles. No class_name (preload).
# Colours only through CardTheme keys, words only through CardText (callers pass the text in).
# Owner RG4. Contract: docs/cards/rogue/ROGUE_V1.md sections 7.2-7.5, 11, 12.
extends RefCounted

## Depth / kind -> frame colour (section 7.2: plain wood, storied seal, treasure frame_gold, source jade).
const FRAME_KEYS := {"plain": &"wood", "storied": &"seal", "treasure": &"frame_gold", "source": &"jade"}
## Ink on a pill of that frame colour (frame_gold is light, the rest are dark).
const PILL_INKS := {"plain": &"paper", "storied": &"paper", "treasure": &"ink", "source": &"paper"}
const DEPTHS: Array[String] = ["plain", "storied", "treasure"]
## Wrapped text sits a little tighter than the font's own line height (CJK glyphs fill about 1 em).
const LINE_TRIM := -3


## "plain" / "storied" / "treasure" for relics, "source" for customer sources; unknown depths read as plain.
static func look_of(kind: String, depth: String) -> String:
	if kind == "source":
		return "source"
	return depth if DEPTHS.has(depth) else "plain"


static func frame_key(look: String) -> StringName:
	return FRAME_KEYS.get(look, &"wood")


## The words for a depth (rg4.depth.<d>) or for a source card (rg4.kind.source).
static func depth_word_key(look: String) -> String:
	return "rg4.kind.source" if look == "source" else "rg4.depth." + look


## A label in one palette tone. font: &"body" / &"bold" / &"title" (brush). Draft text (no words written yet)
## keeps its own muted tone so a missing line never looks finished.
static func label(text: String, size: int, tone: StringName, font: StringName = &"body", draft: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	match font:
		&"bold":
			l.add_theme_font_override("font", CardTheme.font_body_bold())
		&"title":
			l.add_theme_font_override("font", CardTheme.font_title())
		_:
			l.add_theme_font_override("font", CardTheme.font_body())
	l.add_theme_font_size_override("font_size", maxi(size, CardTheme.font_size(&"min")))
	l.add_theme_color_override("font_color", CardTheme.color(&"text_3" if draft else tone))
	return l


## A wrapped label with a fixed box: at most max_lines lines, the rest clipped.
static func block(text: String, size: int, tone: StringName, box: Vector2, max_lines: int, draft: bool = false) -> Label:
	var l := label(text, size, tone, &"body", draft)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.clip_text = true
	l.max_lines_visible = max_lines
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	l.add_theme_constant_override("line_spacing", LINE_TRIM)
	l.custom_minimum_size = box
	l.size = box
	return l


## A wrapped label that grows with its text inside a container (drawer rows): nothing is cut off.
static func flow(text: String, size: int, tone: StringName, draft: bool = false) -> Label:
	var l := label(text, size, tone, &"body", draft)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.clip_text = false
	l.add_theme_constant_override("line_spacing", LINE_TRIM)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.custom_minimum_size = Vector2(1, 0)
	return l


## How many lines the body font needs for text at this width and size (same breaks as an autowrapped Label).
static func lines_of(text: String, width: float, size: int) -> int:
	if text == "" or width <= 0.0:
		return 1
	var f := CardTheme.font_body()
	var brk := TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE
	var box := f.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, width, size, -1, brk)
	return maxi(1, int(roundf(box.y / maxf(f.get_height(size), 1.0))))


## Height of n lines of block() text (line_spacing LINE_TRIM between lines), plus one pixel of slack.
static func text_height(lines: int, size: int) -> float:
	var n := maxi(lines, 1)
	return CardTheme.font_body().get_height(size) * float(n) + LINE_TRIM * float(n - 1) + 1.0


## A one-line label that never grows: clipped with an ellipsis.
static func line(text: String, size: int, tone: StringName, width: float, draft: bool = false) -> Label:
	var l := label(text, size, tone, &"body", draft)
	l.clip_text = true
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	l.custom_minimum_size = Vector2(width, 0)
	return l


## Small coloured tag (depth word, use / flaw marks): the Label carries its own pill box.
static func pill(text: String, bg: StringName, ink: StringName, size: int = 14, draft: bool = false) -> Label:
	var l := label(text, size, ink, &"bold", draft)
	l.add_theme_stylebox_override("normal", CardTheme.pill_style(bg, &"", 4, 6.0, 0.0))
	l.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	l.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	return l


## Pixel art at an integer scale (nearest). Missing art leaves an empty box of the same size.
static func art(art_id: String, box: Vector2) -> TextureRect:
	var r := TextureRect.new()
	r.texture = CardArt.texture(art_id) if art_id != "" else null
	r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_SCALE
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.custom_minimum_size = box
	r.size = box
	r.set_meta("art", art_id)
	return r


## Base size of an art id; relic props are 32x32 and source pictures 64x48 when the manifest has no entry yet.
static func base_of(art_id: String, look: String) -> Vector2:
	var b := CardArt.base_size(art_id)
	if b != Vector2i.ZERO:
		return Vector2(b)
	return Vector2(64, 48) if look == "source" else Vector2(32, 32)


## Paper card with a frame in the depth colour (section 7.2). on = picked with the keyboard: a gold edge.
static func card_style(look: String, on: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = CardTheme.mix(&"card_face_top", &"card_face_bot")
	sb.border_color = CardTheme.color(&"gold_hi" if on else frame_key(look))
	sb.set_border_width_all(5 if on else 4)
	sb.set_corner_radius_all(6)
	sb.corner_detail = 6
	sb.shadow_color = CardTheme.color(&"gold_glow") if on else CardTheme.with_alpha(&"card_shadow", 0.6)
	sb.shadow_size = 12 if on else 8
	sb.shadow_offset = Vector2(0, 0) if on else Vector2(0, 4)
	return sb


## The darker well the picture sits in (same as the card widget's art well).
static func well_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = CardTheme.color(&"card_well")
	sb.border_color = CardTheme.color(&"card_well_line")
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(3)
	return sb


## A paper row in the dark drawer with the depth colour as a bar on the left.
static func row_style(look: String) -> StyleBoxFlat:
	var sb := CardTheme.paper_card_style()
	sb.border_color = CardTheme.color(frame_key(look))
	sb.border_width_left = 5
	sb.content_margin_left = 12.0
	return sb


## Card text by field; draft when no layer has the words yet (RG3 writes them).
static func card_text(def_id: String, field: String) -> String:
	return CardText.card(def_id, field)


static func is_draft(def_id: String, field: String) -> bool:
	return CardText.is_draft(def_id + "#" + field)


static func dict(v) -> Dictionary:
	return v if typeof(v) == TYPE_DICTIONARY else {}


static func array(v) -> Array:
	return v if typeof(v) == TYPE_ARRAY else []


## A row that lays its children left to right and never takes the mouse.
static func row_box(sep: int) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_theme_constant_override("separation", sep)
	return h


## A column that never takes the mouse.
static func column(sep: int) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_theme_constant_override("separation", sep)
	return v


## Removes and frees every child (rebuilds are rare: open, refresh with new data).
static func clear(node: Node) -> void:
	if node == null:
		return
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()
