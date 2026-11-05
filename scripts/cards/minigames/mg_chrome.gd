# One look for every minigame panel (reskin 10-22, the web prototype's minigame .modal): dark sheet in the
# pixel frame.dialog frame, centred brush-gold title, light body text, wood buttons with one gold primary,
# paper wells for item pictures and a dark inset for drawn instruments. No class_name; preload it.
# Owners C12 C13 C14 C15 (shared so the five games match). Colors from CardTheme, text from the callers.
# The host's visible "abort" button sits in a spot each game keeps free in its own button row
# (abort_rect() on the game, read by CardMiniGameHost; b03, b51).
extends RefCounted

const PAD := 34.0   # frame 14 + prototype padding 20
const TITLE_SIZE := 30
const ABORT_W := 120.0
const BUTTON_H := 44.0


static func frame() -> StyleBox:
	return CardTheme.modal_style()


## Centred brush-gold title across the sheet's inner width.
static func title(text: String, draft: bool, width: float) -> Label:
	var l := label(text, TITLE_SIZE, draft)
	l.add_theme_font_override("font", CardTheme.font_title())
	l.add_theme_color_override("font_color", CardTheme.color(&"text_3" if draft else &"gold_hi"))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.position = Vector2(PAD, PAD - 10.0)
	l.size = Vector2(width - PAD * 2.0, 42)
	return l


## Light text on the dark sheet; draft text is dimmer.
static func label(text: String, size: int, draft: bool) -> Label:
	var l := Label.new()
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_override("font", CardTheme.font_body())
	l.add_theme_font_size_override("font_size", maxi(size, 14))
	l.add_theme_color_override("font_color", ink(draft))
	return l


## Secondary line (prototype .modal p: 14px, --text-2).
static func note(text: String, draft: bool) -> Label:
	var l := label(text, 14, draft)
	l.add_theme_color_override("font_color", CardTheme.color(&"text_3" if draft else &"text_2"))
	return l


static func ink(draft: bool) -> Color:
	return CardTheme.color(&"text_3" if draft else &"hud_ink")


## Ink for text sitting on a paper well.
static func paper_ink(draft: bool) -> Color:
	return CardTheme.color(&"ink_soft" if draft else &"ink")


## Wood button from the card theme; primary = the gold .btn.primary.
static func button(text: String, primary: bool = false) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.theme_type_variation = &"PrimaryButton" if primary else &""
	return b


## Paper well behind an item picture (prototype: #e9dcb8, 3px umber edge, radius 4).
static func well() -> StyleBoxFlat:
	var sb := CardTheme.flat_style(&"paper", &"umber", 3, 4, 6.0, 6.0)
	sb.shadow_color = CardTheme.with_alpha(&"card_shadow", 0.35)
	sb.shadow_size = 4
	sb.shadow_offset = Vector2(0, 2)
	return sb


## Dark inset behind a drawn instrument (beam, timing bar, sound lines).
static func inset() -> StyleBoxFlat:
	var sb := CardTheme.flat_style(&"wood_0", &"line", 1, 6, 0.0, 0.0)
	return sb


## A Panel drawing a style box at rect (no input).
static func plate(style: StyleBox, at: Vector2, sz: Vector2) -> Panel:
	var p := Panel.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_theme_stylebox_override("panel", style)
	p.position = at
	p.size = sz
	return p


## Where the host's abort button goes: a rect in the game's own coordinates (panel position + spot).
static func abort_at(panel: Control, spot: Vector2, height: float = BUTTON_H) -> Rect2:
	if panel == null:
		return Rect2()
	return Rect2(panel.position + spot, Vector2(ABORT_W, height))
