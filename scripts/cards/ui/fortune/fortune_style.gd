# Shared look for the fortune stall. No class_name. Text from CardText, colors from CardTheme.
# Owner C07. Contract: docs/cards/CARDS_INTERFACES.md section 3.3 C07.
extends RefCounted

# Art ids are not in the manifest yet. Callers paint paper when CardArt.texture returns null.
# TODO(content): prop.fortune.tube, prop.fortune.slip, prop.fortune.char
const ART_TUBE := "prop.fortune.tube"
const ART_SLIP := "prop.fortune.slip"
const ART_CHAR := "prop.fortune.char"


static func label(text: String, size: int, draft: bool) -> Label:
	var l := Label.new()
	set_label(l, text, size, draft)
	return l


static func set_label(l: Label, text: String, size: int, draft: bool) -> void:
	l.text = text
	l.tooltip_text = text
	l.clip_text = true
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var title := size >= 28
	l.add_theme_font_override("font", CardTheme.font_title() if title else CardTheme.font_body())
	l.add_theme_font_size_override("font_size", size)
	# Reskin 10-22: light text on the stall's dark sheet; the title is brush gold.
	var ink := &"gold_hi" if title else &"hud_ink"
	l.add_theme_color_override("font_color", CardTheme.color(&"text_3" if draft else ink))
	l.mouse_filter = Control.MOUSE_FILTER_STOP


static func button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.tooltip_text = text
	b.focus_mode = Control.FOCUS_ALL
	b.clip_text = true
	b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	# Wood button from the card theme (reskin): disabled reads 45% and dim, clearly off.
	b.add_theme_font_size_override("font_size", 16)
	return b
