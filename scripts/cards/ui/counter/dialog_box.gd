# Shared dialog box: name strip, typewriter, click to continue, skip, replies.
# Owner C04. Text only through CardText, colour only through CardTheme. Contract 7.11.5.
# Anchors: a.dialog while shown, a.dialog.next on the skip button while it shows. Reply anchors are
# registered here for the reply owner and dropped when the replies are cleared.
# UI events: dialog_advanced {uid}, dialog_skipped {uid}, reply_chosen {uid, reply}.
# Reskin 10-23 (web prototype, RESKIN SPEC 6): frame.dialog pixel wood x2 on dialog_bg with a drop
# shadow (gold ring for gold cards); brush name + role line; the previous line on top; three body
# looks (speech, narration, system); skip only while something is left to show (b29); a blinking
# continue mark; replies are a list with style marks from ui keys (b27) and every number inside the
# frame (b28); set_header() adds the item row (64 px picture, bold title, grey tags), the gold-bar
# inspect notes and a gold lead line above the replies.
# Public beyond CardDialogApi: set_header(info) (C04 counter; listed in the PR).
class_name CardDialogBox
extends CardDialogApi

# Kept for callers that read them; one reply row is 34 high, tight rows go down to 28.
const REPLY_ROW := 34.0
const REPLY_BUTTON := 34.0
const REPLY_ROW_MIN := 28.0

const PAD_X := 24.0         # frame 14 + 10
const PAD_TOP := 20.0       # frame 14 + 6
const PAD_BOTTOM := 24.0    # frame 14 + 10
const NAME_H := 32.0
const BODY_SPACING := 5     # 18 px text at about 30 px a line (prototype 17.5 / 30.6)
const BODY_MIN_LINES := 2
const MORE_H := 18.0
const MARK_X := 8.0
const MARK_W := 14.0
const TEXT_X := 30.0        # mark 8 + 14 + gap 8
const ART := 64.0           # item picture, x1 (whole-number scale)
const HEADER_MIN := 72.0
const REPLY_SIZE := 17
const LATER_SIZE := 15
const SMALL := 14

const STYLE_KEYS := {
	"choice": "c04.reply.mark.choice", "tier": "c04.reply.mark.tier", "look": "c04.reply.mark.look",
	"roll": "c04.reply.mark.roll", "wheel": "c04.reply.mark.wheel", "later": "c04.reply.mark.later",
}

var bus: CardEventBus = null

var _uid: String = ""
var _lines: Array = []
var _index: int = -1
var _shown: int = 0
var _acc: float = 0.0
var _full: String = ""
var _kind: String = "narr"
var _done_emitted: bool = false
var _replies: Array = []
var _reply_anchors: Array = []
var _rows: Array = []          # [{node, kind: "reply"/"reason", button, style, h}]
var _header: Dictionary = {}
var _max_bottom: int = CardLayout.DIALOG_MAX_BOTTOM
var _said_rule_y: float = -1.0
var _reply_rule_y: float = -1.0
var _blink: Tween = null
var _boxes: Dictionary = {}
var _sys_font: Font = null

var _shadow: Panel
var _glow: Panel
var _panel: Panel
var _said_name: Label
var _said: Label
var _name: Label
var _role: Label
var _body: Label
var _nums: HBoxContainer
var _more: Label
var _head: Control
var _art_bg: Panel
var _art: TextureRect
var _head_title: Label
var _head_tags: Label
var _notes: Panel
var _lead: Label
var _reply_list: Control
var _skip: Button


func _ready() -> void:
	_build()
	_apply_visibility()


func _exit_tree() -> void:
	# Do not call clear()/_build() while leaving the tree.
	_clear_replies()
	_stop_blink()
	if _skip != null and is_instance_valid(_skip):
		CardAnchors.unregister(&"a.dialog", self)
		CardAnchors.unregister(&"a.dialog.next", _skip)
	bus = null


func _process(delta: float) -> void:
	if not _typing():
		return
	_acc += delta * float(maxi(chars_per_sec, 0))
	var add := int(_acc)
	if add <= 0:
		return
	_acc -= float(add)
	_shown = mini(_full.length(), _shown + add)
	_body.visible_characters = _shown
	if _shown >= _full.length():
		_acc = 0.0
		_sync_chrome()
		if is_idle():
			_emit_done()


func show_lines(uid: String, lines: Array, append: bool = false) -> void:
	_build()
	var old_size := _lines.size()
	if uid != _uid and not append:
		_set_said("", "", "")
	_uid = uid
	if not append:
		_lines = []
		_index = -1
		old_size = 0
		set_replies([])
	for entry in lines:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		_append_line(entry)
	_done_emitted = false
	if _lines.is_empty():
		_full = ""
		_body.text = ""
		_name.text = ""
		_role.text = ""
		_apply_visibility()
		_emit_done()
		return
	if chars_per_sec <= 0:
		_index = _lines.size() - 1
		_show_current()
		_shown = _full.length()
		_body.visible_characters = -1
		_apply_visibility()
		_emit_done()
		return
	if not append or _index < 0:
		_index = 0
	elif _index >= old_size - 1:
		_index = old_size if old_size < _lines.size() else _lines.size() - 1
	_show_current()
	_apply_visibility()


func set_replies(replies: Array) -> void:
	_build()
	_clear_replies()
	_replies = replies.duplicate(true)
	var i := 0
	for entry in _replies:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		_add_reply(entry, i)
		i += 1
	_layout()
	_apply_visibility()


## C04 counter: the item row, inspect notes and lead line above the replies, and the gold ring.
## info = {"art": art id, "title_ref", "title_args", "tags": [{ref, args}], "notes": [{label_ref,
## text_ref, args}], "lead_ref", "lead_args", "gold": bool}. {} clears it. Shown with the replies.
func set_header(info: Dictionary) -> void:
	_build()
	_header = info.duplicate(true)
	_fill_header()
	_layout()


func clear() -> void:
	_build()
	_clear_replies()
	_uid = ""
	_lines = []
	_replies = []
	_index = -1
	_shown = 0
	_acc = 0.0
	_full = ""
	_kind = "narr"
	_done_emitted = false
	_body.text = ""
	_name.text = ""
	_role.text = ""
	_set_said("", "", "")
	_clear_nums()
	_header = {}
	_fill_header()
	_layout()
	_apply_visibility()


func skip() -> void:
	_build()
	if not _lines.is_empty():
		_index = _lines.size() - 1
		_show_current()
		_shown = _full.length()
		_body.visible_characters = -1
		_acc = 0.0
	_ui(&"dialog_skipped", {"uid": _uid})
	_apply_visibility()
	_emit_done()


func is_idle() -> bool:
	return not _typing() and (_lines.is_empty() or _index >= _lines.size() - 1)


func has_replies() -> bool:
	return not _replies.is_empty()


func set_max_bottom(y: int) -> void:
	_max_bottom = clampi(y, int(CardLayout.DIALOG.position.y) + CardLayout.DIALOG_MIN_HEIGHT, CardLayout.DIALOG_MAX_BOTTOM)
	if _panel != null:
		_layout()


func current_uid() -> String:
	return _uid


func _unhandled_input(event: InputEvent) -> void:
	if not visible or not (event is InputEventKey):
		return
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return
	if key.keycode == KEY_SPACE or key.keycode == KEY_ENTER or key.keycode == KEY_KP_ENTER:
		_advance_or_finish()
		_accept(key)
	elif key.keycode >= KEY_1 and key.keycode <= KEY_9:
		_press_index(key.keycode - KEY_1)
		_accept(key)


# ---------------- lines ----------------
func _append_line(entry: Dictionary) -> void:
	var ref := str(entry.get("ref", ""))
	var opt := bool(entry.get("opt", false))
	if opt and ref != "" and CardText.is_draft(ref):
		return
	var args: Dictionary = entry.get("args", {}) if typeof(entry.get("args")) == TYPE_DICTIONARY else {}
	var full := CardText.t(ref, args) if ref != "" else ""
	if ref != "" and full.strip_edges() == "":
		return  # no layer wrote this line (drafts hidden by default): skip it, never play a blank beat
	var parts := full.split("\n\n", false)
	if parts.size() <= 1:
		var one := entry.duplicate(true)
		one["args"] = args.duplicate(true)
		_lines.append(one)
		return
	for part in parts:
		if str(part) == "":
			continue
		var piece := entry.duplicate(true)
		piece["args"] = args.duplicate(true)
		piece["_text"] = str(part)
		_lines.append(piece)


func _line_text(line: Dictionary) -> String:
	if line.has("_text"):
		return str(line["_text"])
	var args: Dictionary = line.get("args", {}) if typeof(line.get("args")) == TYPE_DICTIONARY else {}
	return CardText.t(str(line.get("ref", "")), args)


func _show_current() -> void:
	if _index < 0 or _index >= _lines.size():
		return
	var line: Dictionary = _lines[_index]
	_kind = str(line.get("kind", "narr"))
	var who := "ruhua" if _kind == "me" else str(line.get("who", ""))
	var show_name := _kind in ["say", "me"] and who != ""
	_name.visible = show_name
	_name.text = CardText.person_name(who) if show_name else ""
	_name.add_theme_color_override("font_color", CardTheme.color(&"dialog_me" if _kind == "me" else &"dialog_name"))
	var role_ref := "c04.role." + who
	_role.text = CardText.ui(role_ref) if show_name and _kind == "say" and CardText.has_text(role_ref) else ""
	_role.visible = _role.text != ""
	var args: Dictionary = line.get("args", {}) if typeof(line.get("args")) == TYPE_DICTIONARY else {}
	_full = _line_text(line)
	_body.text = _full
	_body.set_meta("text_ref", str(line.get("ref", "")))
	_body.name = "ReplyLine"
	_style_body()
	_shown = 0 if chars_per_sec > 0 else _full.length()
	_acc = 0.0
	_body.visible_characters = -1 if chars_per_sec <= 0 else 0
	_clear_nums()
	if not line.has("_text") and bool(line.get("nums", true)):
		_add_line_nums(_full, args)
	_talk(who if _kind == "say" else "")
	_layout()


## Speech and "me" 18 dialog_ink; narration 18 dialog_narr (C05 reads the body by its 18 size);
## system lines 15 gold, centred, letter-spaced.
func _style_body() -> void:
	var sys := _kind == "sys"
	_body.add_theme_font_size_override("font_size", 15 if sys else 18)
	var key := &"dialog_ink"
	if sys:
		key = &"dialog_sys"
	elif _kind == "narr":
		key = &"dialog_narr"
	_body.add_theme_color_override("font_color", CardTheme.color(key))
	_body.add_theme_font_override("font", _system_font() if sys else CardTheme.font_body())
	_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if sys else HORIZONTAL_ALIGNMENT_LEFT


func _advance_or_finish() -> void:
	if _lines.is_empty():
		return
	if _typing():
		_shown = _full.length()
		_body.visible_characters = -1
		_acc = 0.0
		_sync_chrome()
		if is_idle():
			_emit_done()
		return
	if _index >= _lines.size() - 1:
		_emit_done()
		return
	_remember(_lines[_index])
	_index += 1
	_show_current()
	advanced.emit(_index)
	_ui(&"dialog_advanced", {"uid": _uid})
	_sync_chrome()
	if is_idle() and chars_per_sec <= 0:
		_emit_done()


## The line just left becomes the small previous line on top (speech and "me" only).
func _remember(line: Dictionary) -> void:
	var kind := str(line.get("kind", "narr"))
	if kind != "say" and kind != "me":
		return
	var who := "ruhua" if kind == "me" else str(line.get("who", ""))
	_set_said(who, _line_text(line), str(line.get("ref", "")))


func _set_said(who: String, text: String, ref: String) -> void:
	if _said == null:
		return
	_said.text = text
	_said.set_meta("text_ref", ref)
	_said.visible = text != ""
	_said_name.text = CardText.person_name(who) if who != "" and text != "" else ""
	_said_name.visible = _said_name.text != ""
	_said_name.add_theme_color_override("font_color", CardTheme.color(&"dialog_me" if who == "ruhua" else &"text_2"))


func _choose_reply(reply: Dictionary) -> void:
	if not bool(reply.get("enabled", true)):
		return
	var reply_id := str(reply.get("id", ""))
	var ref := str(reply.get("ref", ""))
	var args: Dictionary = reply.get("args", {}) if typeof(reply.get("args")) == TYPE_DICTIONARY else {}
	if bool(reply.get("echo", true)):
		_set_said("ruhua", CardText.t(ref, args), ref)
		_layout()
	reply_chosen.emit(reply_id)
	_ui(&"reply_chosen", {"uid": _uid, "reply": reply_id})


func _press_index(i: int) -> void:
	var buttons := _reply_buttons()
	if i < 0 or i >= buttons.size():
		return
	var button: Button = buttons[i]
	if button.disabled:
		return
	button.pressed.emit()


func _reply_buttons() -> Array:
	var out: Array = []
	for row in _rows:
		if row["kind"] == "reply":
			out.append(row["button"])
	return out


func _typing() -> bool:
	return chars_per_sec > 0 and _full != "" and _shown < _full.length() and _index >= 0


func _emit_done() -> void:
	if _done_emitted:
		return
	_done_emitted = true
	lines_done.emit()


func _talk(who: String) -> void:
	var stage := _find_stage()
	if stage != null:
		stage.set_talking(who)


func _find_stage() -> CardStageApi:
	var n: Node = self
	while n != null:
		for child in n.get_children():
			if child is CardStageApi:
				return child
		n = n.get_parent()
	return null


# ---------------- replies ----------------
func _add_reply(reply: Dictionary, index: int) -> void:
	var style := str(reply.get("style", "choice"))
	if not STYLE_KEYS.has(style):
		style = "choice"
	var ref := str(reply.get("ref", ""))
	var args: Dictionary = reply.get("args", {}) if typeof(reply.get("args")) == TYPE_DICTIONARY else {}
	var row := Control.new()
	row.name = "Row%d" % index
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_reply_list.add_child(row)
	var button := Button.new()
	button.name = _button_name(str(reply.get("id", "")))
	button.theme_type_variation = &"ReplyButton"
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.text = CardText.t(ref, args)
	if style == "later" and button.text != "":
		# The aside rows read "(come back later)" in small grey, as in the prototype.
		button.text = CardText.ui("c04.reply.aside", {"text": button.text})
	button.disabled = not bool(reply.get("enabled", true))
	button.clip_text = true
	button.set_meta("text_ref", ref)
	button.set_meta("reply_id", str(reply.get("id", "")))
	_ink_reply(button, style)
	if button.disabled:
		button.modulate = Color(1, 1, 1, 0.5)
		button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(_choose_reply.bind(reply.duplicate(true)))
	row.add_child(button)
	button.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var mark := Label.new()
	mark.name = "Mark"
	mark.text = CardText.ui(STYLE_KEYS[style])
	mark.set_meta("text_ref", STYLE_KEYS[style])
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mark.add_theme_font_size_override("font_size", LATER_SIZE if style == "later" else 15)
	mark.add_theme_color_override("font_color", CardTheme.color(&"text_3" if style == "later" else &"gold_hi"))
	button.add_child(mark)
	var nums := _arg_nums(button.text, args)
	var reserve := 0.0
	for n in nums:
		var lab := _small(str(n), &"text_2", REPLY_SIZE if style != "later" else LATER_SIZE)
		lab.name = "Num"
		lab.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(lab)
		reserve += lab.get_minimum_size().x + 8.0
	_rows.append({"node": row, "kind": "reply", "button": button, "style": style, "h": REPLY_ROW,
		"reserve": reserve, "mark": mark})
	var anchor := StringName(str(reply.get("anchor", "")))
	if anchor != &"":
		CardAnchors.register(anchor, button)
		_reply_anchors.append([anchor, button])
	var reason_ref := str(reply.get("reason_ref", ""))
	if button.disabled and reason_ref != "":
		var reason := _small(CardText.t(reason_ref), &"text_3", SMALL)
		var choice_id := str(reply.get("id", ""))
		reason.name = "Reason_" + choice_id.substr(7) if choice_id.begins_with("choice:") else "Reason%d" % index
		reason.set_meta("text_ref", reason_ref)
		reason.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_reply_list.add_child(reason)
		_rows.append({"node": reason, "kind": "reason", "h": 0.0})


func _ink_reply(button: Button, style: String) -> void:
	var ink := &"reply_ink"
	var size_px := REPLY_SIZE
	match style:
		"look":
			ink = &"reply_look"
		"roll", "wheel":
			ink = &"focus"
			button.add_theme_font_override("font", CardTheme.font_body_bold())
		"later":
			ink = &"text_3"
			size_px = LATER_SIZE
	button.add_theme_font_size_override("font_size", size_px)
	button.add_theme_color_override("font_color", CardTheme.color(ink))
	button.add_theme_color_override("font_focus_color", CardTheme.color(ink))
	button.add_theme_color_override("font_disabled_color", CardTheme.color(&"reply_off"))


func _arg_nums(shown: String, args: Dictionary) -> Array:
	var out: Array = []
	for k in args.keys():
		var v = args[k]
		if typeof(v) != TYPE_INT and typeof(v) != TYPE_FLOAT:
			continue
		var n := int(v)
		if n == 0 or shown.find(str(n)) >= 0:
			continue
		out.append(n)
	return out


func _reply_style(hover: bool, pad_v: float, pad_r: float) -> StyleBox:
	var key := "%s:%d:%d" % [hover, int(pad_v), int(pad_r)]
	if _boxes.has(key):
		return _boxes[key]
	var sb: StyleBox
	if hover:
		sb = CardTheme.flat_style(&"reply_hover", &"", 0, 3)
	else:
		sb = StyleBoxEmpty.new()
	sb.content_margin_left = TEXT_X
	sb.content_margin_right = pad_r
	sb.content_margin_top = pad_v
	sb.content_margin_bottom = pad_v
	_boxes[key] = sb
	return sb


# ---------------- header ----------------
func _fill_header() -> void:
	var title_ref := str(_header.get("title_ref", ""))
	var title_args: Dictionary = _header.get("title_args", {}) if typeof(_header.get("title_args")) == TYPE_DICTIONARY else {}
	_head_title.text = CardText.t(title_ref, title_args) if title_ref != "" else ""
	_head_title.set_meta("text_ref", title_ref)
	_head_tags.text = _join_tags(_header.get("tags", []))
	var art := str(_header.get("art", ""))
	var tex: Texture2D = CardArt.texture(art) if art != "" else null
	_art.texture = tex
	_art.visible = tex != null
	_art_bg.visible = tex != null
	_head.visible = _head_title.text != "" or _head_tags.text != "" or tex != null
	for c in _notes.get_children():
		_notes.remove_child(c)
		c.queue_free()
	var last_label := ""
	for entry in _header.get("notes", []):
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var note: Dictionary = entry
		var nargs: Dictionary = note.get("args", {}) if typeof(note.get("args")) == TYPE_DICTIONARY else {}
		var text := CardText.t(str(note.get("text_ref", "")), nargs)
		if text.strip_edges() == "":
			continue
		var label_ref := str(note.get("label_ref", ""))
		var tag := _small(CardText.ui(label_ref) if label_ref != "" and label_ref != last_label else "", &"gold_hi", SMALL)
		tag.add_theme_font_override("font", CardTheme.font_body_bold())
		tag.set_meta("text_ref", label_ref)
		tag.set_meta("note_tag", true)
		last_label = label_ref
		_notes.add_child(tag)
		var body := _small(text, &"text_2", SMALL)
		body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.set_meta("text_ref", str(note.get("text_ref", "")))
		_notes.add_child(body)
	_notes.visible = _notes.get_child_count() > 0
	var lead_ref := str(_header.get("lead_ref", ""))
	var lead_args: Dictionary = _header.get("lead_args", {}) if typeof(_header.get("lead_args")) == TYPE_DICTIONARY else {}
	_lead.text = CardText.t(lead_ref, lead_args) if lead_ref != "" else ""
	_lead.set_meta("text_ref", lead_ref)
	_lead.visible = _lead.text != ""
	_glow.visible = bool(_header.get("gold", false))


## Tags in one grey line, joined through the c04.header.join key ("a . b").
func _join_tags(raw) -> String:
	var out := ""
	if typeof(raw) != TYPE_ARRAY:
		return out
	for entry in raw:
		var text := ""
		if typeof(entry) == TYPE_DICTIONARY:
			var args: Dictionary = entry.get("args", {}) if typeof(entry.get("args")) == TYPE_DICTIONARY else {}
			text = CardText.t(str(entry.get("ref", "")), args)
		if text.strip_edges() == "":
			continue
		out = text if out == "" else CardText.ui("c04.header.join", {"a": out, "b": text})
	return out


# ---------------- layout ----------------
func _layout() -> void:
	if _panel == null:
		return
	var limit := float(_max_bottom) - position.y
	var replying := not _rows.is_empty()
	var row_h := REPLY_ROW
	var keep_said := true
	var height := _measure(row_h, keep_said, replying)
	if replying and height > limit:
		var n := 0
		for row in _rows:
			if row["kind"] == "reply":
				n += 1
		var over := height - limit
		row_h = maxf(REPLY_ROW_MIN, floorf(REPLY_ROW - over / float(maxi(n, 1))))
		height = _measure(row_h, keep_said, replying)
		if height > limit:
			keep_said = false
			height = _measure(row_h, keep_said, replying)
	height = clampf(height, float(CardLayout.DIALOG_MIN_HEIGHT), maxf(limit, float(CardLayout.DIALOG_MIN_HEIGHT)))
	size = Vector2(CardLayout.DIALOG.size.x, height)
	_panel.size = size
	_shadow.size = size
	_glow.size = size
	_place_skip()
	_more.position = Vector2(size.x - PAD_X - MARK_W - 2.0, _more.position.y)
	_panel.queue_redraw()


## Places everything top-down and returns the frame height.
func _measure(row_h: float, keep_said: bool, replying: bool) -> float:
	var w := CardLayout.DIALOG.size.x - PAD_X * 2.0
	var y := PAD_TOP
	_said_rule_y = -1.0
	var said_on := keep_said and _said.text != ""
	_said.visible = said_on
	_said_name.visible = said_on and _said_name.text != ""
	if said_on:
		var name_w := _said_name.get_minimum_size().x + 8.0 if _said_name.visible else 0.0
		_said_name.position = Vector2(PAD_X, y)
		var skip_w := _skip.size.x + 8.0 if _skip.visible else 0.0
		_said.position = Vector2(PAD_X + name_w, y)
		y += _fit(_said, maxf(40.0, w - name_w - skip_w)) + 6.0
		_said_rule_y = y
		y += 7.0
	_name.position = Vector2(PAD_X + 2.0, y - 4.0)
	_name.size = Vector2(0, 0)
	if _role.visible:
		var nm := _name.get_minimum_size()
		var rm := _role.get_minimum_size()
		_role.position = Vector2(_name.position.x + nm.x + 8.0, _name.position.y + nm.y - rm.y - 3.0)
		_role.size = Vector2(maxf(20.0, w - nm.x - 12.0), 0)
	# A blank beat (the guest has no line for this reply; the line was skipped) takes no room, so the
	# tall reply list does not push the echoed reply above it out of the box (QA 10-25).
	var blank := replying and _body.text == ""
	# Narration under a previous line needs no empty name row.
	if blank:
		y += 0.0 if said_on else 4.0
	else:
		y += NAME_H if _name.visible or not said_on else 10.0
	if _kind == "sys" and not blank:
		y += 10.0
	_body.position = Vector2(PAD_X + 2.0, y)
	_body.size = Vector2(w - 4.0, 0)
	var line_h := _body.get_line_height() + float(BODY_SPACING)
	var body_h := 0.0 if blank else maxf(_body.get_minimum_size().y, line_h * float(BODY_MIN_LINES) - float(BODY_SPACING))
	_body.size = Vector2(w - 4.0, body_h)
	y += body_h
	if _nums.get_child_count() > 0:
		_nums.position = Vector2(PAD_X + 2.0, y + 2.0)
		_nums.size = Vector2(w - 4.0, 24)
		y += 26.0
	_reply_rule_y = -1.0
	var area := [_head, _notes, _lead, _reply_list]
	if not replying:
		_more.position = Vector2(_more.position.x, y - 4.0)
		y += MORE_H
		for node in area:
			(node as Control).visible = false
		return y + PAD_BOTTOM - 10.0
	if blank and said_on:
		y += 2.0   # the echoed line's own rule already separates it from the replies (no double rule)
	else:
		y += 8.0
		_reply_rule_y = y
		y += 9.0
	_head.visible = _head_title.text != "" or _head_tags.text != "" or _art.visible
	if _head.visible:
		y += _place_header(y, w) + 4.0
	_notes.visible = _notes.get_child_count() > 0
	if _notes.visible:
		y += _place_notes(y, w) + 6.0
	_lead.visible = _lead.text != ""
	if _lead.visible:
		_lead.position = Vector2(PAD_X + 8.0, y)
		y += _fit(_lead, w - 16.0) + 4.0
	_reply_list.visible = true
	_reply_list.position = Vector2(PAD_X, y)
	var ly := 0.0
	for row in _rows:
		var node: Control = row["node"]
		if row["kind"] == "reason":
			node.position = Vector2(TEXT_X, ly - 2.0)
			ly += _fit(node as Label, w - TEXT_X) + 2.0
			continue
		_place_row(row, row_h, w)
		node.position = Vector2(0, ly)
		ly += row_h + 2.0
	_reply_list.size = Vector2(w, maxf(ly - 2.0, 0.0))
	return y + maxf(ly - 2.0, 0.0) + PAD_BOTTOM


func _place_row(row: Dictionary, row_h: float, w: float) -> void:
	var node: Control = row["node"]
	var button: Button = row["button"]
	var style := str(row["style"])
	var font := button.get_theme_font("font")
	var px := LATER_SIZE if style == "later" else REPLY_SIZE
	var pad_v := maxf(0.0, floorf((row_h - font.get_height(px)) / 2.0))
	var pad_r := 8.0 + float(row.get("reserve", 0.0))
	node.size = Vector2(w, row_h)
	for s in [&"normal", &"pressed", &"disabled"]:
		button.add_theme_stylebox_override(s, _reply_style(false, pad_v, pad_r))
	for s in [&"hover", &"hover_pressed", &"focus"]:
		button.add_theme_stylebox_override(s, _reply_style(true, pad_v, pad_r))
	var mark: Label = row["mark"]
	mark.position = Vector2(MARK_X, 0)
	mark.size = Vector2(MARK_W, row_h)
	# Numbers the text did not carry sit right after it, inside the row (b28).
	var x := TEXT_X + font.get_string_size(button.text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x + 8.0
	x = minf(x, w - float(row.get("reserve", 0.0)))
	for c in node.get_children():
		if c is Label:
			var lab := c as Label
			var m := lab.get_minimum_size()
			lab.position = Vector2(x, floorf((row_h - m.y) / 2.0))
			lab.size = m
			x += m.x + 8.0


func _place_header(y: float, w: float) -> float:
	_head.position = Vector2(PAD_X, y)
	var tx := 8.0
	if _art.visible:
		_art_bg.position = Vector2(8, 4)
		_art_bg.size = Vector2(ART, ART)
		_art.position = Vector2(8, 4)
		_art.size = Vector2(ART, ART)
		tx = 8.0 + ART + 10.0
	_head_title.position = Vector2(tx, 8)
	var th := _fit(_head_title, w - tx - 8.0) if _head_title.text != "" else 0.0
	_head_tags.position = Vector2(tx, 8.0 + th + 2.0)
	var tags_h := _fit(_head_tags, w - tx - 8.0) if _head_tags.text != "" else 0.0
	var h := maxf(HEADER_MIN, 8.0 + th + 2.0 + tags_h + 8.0) if _art.visible else 8.0 + th + 2.0 + tags_h + 6.0
	_head.size = Vector2(w, h)
	return h


func _place_notes(y: float, w: float) -> float:
	_notes.position = Vector2(PAD_X, y)
	var inner_x := 13.0
	var ny := 6.0
	var kids := _notes.get_children()
	var tag_w := 0.0
	for i in range(0, kids.size(), 2):
		tag_w = maxf(tag_w, (kids[i] as Label).get_minimum_size().x)
	for i in range(0, kids.size(), 2):
		var tag := kids[i] as Label
		var body := kids[i + 1] as Label
		tag.position = Vector2(inner_x, ny)
		tag.size = tag.get_minimum_size()
		body.position = Vector2(inner_x + tag_w + 8.0, ny)
		ny += _fit(body, w - inner_x - tag_w - 18.0) + 2.0
	var h := ny + 4.0
	_notes.size = Vector2(w, h)
	return h


## An autowrap label's height at this width. The minimum height is only right after the width
## is set, so set the width first and then shrink the height to it.
func _fit(lab: Label, width: float) -> float:
	lab.size = Vector2(width, 0)
	var h := lab.get_minimum_size().y
	lab.size = Vector2(width, h)
	return h


func _place_skip() -> void:
	_skip.size = _skip.get_minimum_size()
	_skip.position = Vector2(size.x - PAD_X - _skip.size.x, PAD_TOP - 2.0)


func _draw_rules() -> void:
	var w := CardLayout.DIALOG.size.x
	var line := CardTheme.color(&"line")
	if _said_rule_y >= 0.0 and _said.visible:
		_panel.draw_dashed_line(Vector2(PAD_X, _said_rule_y), Vector2(w - PAD_X, _said_rule_y), line, 1.0, 3.0)
	if _reply_rule_y >= 0.0 and not _rows.is_empty():
		_panel.draw_line(Vector2(PAD_X, _reply_rule_y), Vector2(w - PAD_X, _reply_rule_y), line, 1.0)


# ---------------- chrome ----------------
func _build() -> void:
	if _panel != null:
		return
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	position = CardLayout.DIALOG.position
	_shadow = Panel.new()
	_shadow.name = "Shadow"
	_shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var drop := StyleBoxFlat.new()
	drop.bg_color = Color.TRANSPARENT
	drop.shadow_color = CardTheme.color(&"shade")
	drop.shadow_size = 30
	drop.shadow_offset = Vector2(0, 12)
	_shadow.add_theme_stylebox_override("panel", drop)
	add_child(_shadow)
	_glow = Panel.new()
	_glow.name = "GoldRing"
	_glow.visible = false
	_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ring := StyleBoxFlat.new()
	ring.bg_color = Color.TRANSPARENT
	ring.border_color = CardTheme.with_alpha(&"gold_hi", 0.6)
	ring.set_border_width_all(2)
	ring.set_expand_margin_all(2.0)
	ring.shadow_color = CardTheme.with_alpha(&"gold_hi", 0.35)
	ring.shadow_size = 24
	_glow.add_theme_stylebox_override("panel", ring)
	add_child(_glow)
	_panel = Panel.new()
	_panel.name = "Frame"
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.gui_input.connect(_on_frame_input)
	_panel.add_theme_stylebox_override("panel", CardTheme.nine_box_filled(CardTheme.FRAME_DIALOG, 2, CardTheme.color(&"dialog_bg")))
	_panel.draw.connect(_draw_rules)
	add_child(_panel)
	_said_name = _small("", &"text_2", SMALL)
	_said_name.name = "SaidName"
	_said_name.add_theme_font_override("font", CardTheme.font_body_bold())
	_said_name.visible = false
	_panel.add_child(_said_name)
	_said = _small("", &"text_3", SMALL)
	_said.name = "SaidLine"
	_said.visible = false
	_said.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_said.max_lines_visible = 2
	_panel.add_child(_said)
	_name = Label.new()
	_name.name = "Name"
	_name.add_theme_font_override("font", CardTheme.font_title())
	_name.add_theme_font_size_override("font_size", CardTheme.font_size(&"name"))
	_name.add_theme_color_override("font_color", CardTheme.color(&"dialog_name"))
	_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_name)
	_role = _small("", &"text_3", SMALL)
	_role.name = "Role"
	_role.clip_text = true
	_role.visible = false
	_panel.add_child(_role)
	_body = Label.new()
	_body.name = "ReplyLine"
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.visible_characters_behavior = TextServer.VC_CHARS_AFTER_SHAPING
	_body.add_theme_constant_override("line_spacing", BODY_SPACING)
	_body.add_theme_font_override("font", CardTheme.font_body())
	_body.add_theme_font_size_override("font_size", 18)
	_body.add_theme_color_override("font_color", CardTheme.color(&"dialog_ink"))
	_body.mouse_filter = Control.MOUSE_FILTER_STOP
	_body.gui_input.connect(_on_body_input)
	_panel.add_child(_body)
	_nums = HBoxContainer.new()
	_nums.name = "Nums"
	_nums.add_theme_constant_override("separation", 10)
	_nums.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_nums)
	_more = _small(CardText.ui("c04.dialog.more"), &"gold_hi", SMALL)
	_more.name = "More"
	_more.set_meta("text_ref", "c04.dialog.more")
	_more.visible = false
	_panel.add_child(_more)
	_head = Control.new()
	_head.name = "ItemHeader"
	_head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_head.visible = false
	_panel.add_child(_head)
	_art_bg = Panel.new()
	_art_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var well := StyleBoxFlat.new()
	well.bg_color = CardTheme.with_alpha(&"paper", 0.1)
	well.set_corner_radius_all(4)
	_art_bg.add_theme_stylebox_override("panel", well)
	_head.add_child(_art_bg)
	_art = TextureRect.new()
	_art.name = "ItemArt"
	_art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_head.add_child(_art)
	_head_title = _small("", &"hud_ink", 15)
	_head_title.name = "HeaderTitle"
	_head_title.add_theme_font_override("font", CardTheme.font_body_bold())
	_head_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_head.add_child(_head_title)
	_head_tags = _small("", &"text_2", SMALL)
	_head_tags.name = "HeaderTags"
	_head_tags.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_head.add_child(_head_tags)
	_notes = Panel.new()
	_notes.name = "Notes"
	_notes.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_notes.visible = false
	_notes.add_theme_stylebox_override("panel", CardTheme.row_note_style())
	_panel.add_child(_notes)
	_lead = _small("", &"gold_hi", SMALL)
	_lead.name = "LeadLine"
	_lead.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lead.visible = false
	_panel.add_child(_lead)
	_reply_list = Control.new()
	_reply_list.name = "Replies"
	_reply_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_reply_list)
	# Skip sits visually at the top right, but after the replies in the tree.
	# C05 walks dialog Buttons and treats the first one as the first reply.
	_skip = Button.new()
	_skip.name = "SkipButton"
	_skip.theme_type_variation = &"SkipButton"
	_skip.text = CardText.ui("c04.dialog.skip")
	_skip.set_meta("text_ref", "c04.dialog.skip")
	_skip.focus_mode = Control.FOCUS_NONE
	_skip.visible = false
	_skip.pressed.connect(skip)
	_panel.add_child(_skip)
	_layout()


func _small(text: String, ink: StringName, px: int) -> Label:
	var lab := Label.new()
	lab.text = text
	lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lab.add_theme_font_override("font", CardTheme.font_body())
	lab.add_theme_font_size_override("font_size", px)
	lab.add_theme_color_override("font_color", CardTheme.color(ink))
	return lab


## System lines: body font with 2 px between glyphs (prototype letter-spacing .14em).
func _system_font() -> Font:
	if _sys_font == null:
		var f := FontVariation.new()
		f.base_font = CardTheme.font_body()
		f.spacing_glyph = 2
		_sys_font = f
	return _sys_font


func _apply_visibility() -> void:
	visible = not _lines.is_empty() or not _replies.is_empty()
	if _skip != null:
		# A new game/load replaces CardText's database after this widget was built.
		_skip.text = CardText.ui("c04.dialog.skip")
		_more.text = CardText.ui("c04.dialog.more")
	if visible and _skip != null:
		CardAnchors.register(&"a.dialog", self)
	elif _skip != null:
		CardAnchors.unregister(&"a.dialog", self)
	_sync_chrome()


## Skip only while something is still to show (b29); the continue mark blinks while a click shows
## the next line.
func _sync_chrome() -> void:
	if _skip == null:
		return
	var waiting := visible and not _lines.is_empty() and not is_idle()
	if _skip.visible != waiting:
		_skip.visible = waiting
		_layout()
	if waiting:
		CardAnchors.register(&"a.dialog.next", _skip)
	else:
		CardAnchors.unregister(&"a.dialog.next", _skip)
	var more := visible and not _typing() and _index >= 0 and _index < _lines.size() - 1
	_more.visible = more
	if more:
		_start_blink()
	else:
		_stop_blink()


func _start_blink() -> void:
	if _blink != null and _blink.is_valid():
		return
	_more.modulate = Color(1, 1, 1, 1)
	if not is_inside_tree() or chars_per_sec <= 0 or CardSettings.fast_anim():
		return
	_blink = create_tween().set_loops()
	_blink.tween_property(_more, "modulate:a", 0.3, 0.55)
	_blink.tween_property(_more, "modulate:a", 1.0, 0.55)


func _stop_blink() -> void:
	if _blink != null and _blink.is_valid():
		_blink.kill()
	_blink = null
	if _more != null and is_instance_valid(_more):
		_more.modulate = Color(1, 1, 1, 1)


func _clear_replies() -> void:
	for row in _reply_anchors:
		if is_instance_valid(row[1]):
			CardAnchors.unregister(row[0], row[1])
	_reply_anchors = []
	_replies = []
	_rows = []
	if _reply_list == null:
		return
	for child in _reply_list.get_children():
		_reply_list.remove_child(child)
		child.queue_free()


func _clear_nums() -> void:
	if _nums == null:
		return
	for child in _nums.get_children():
		_nums.remove_child(child)
		child.free()


## Numbers in a line's args that its text does not show yet (fixtures without {price}). A line with "nums": false
## (the night report: tier indices, counts the words already tell) never shows them.
func _add_line_nums(shown: String, args: Dictionary) -> void:
	for n in _arg_nums(shown, args):
		var lab := _small(str(n), &"gold_hi", 16)
		_nums.add_child(lab)


func _on_body_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		_advance_or_finish()
		_body.accept_event()


func _on_frame_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		_advance_or_finish()
		_panel.accept_event()


func _accept(key: InputEventKey) -> void:
	var vp := get_viewport()
	if vp != null:
		vp.set_input_as_handled()
	key.pressed = false


func _button_name(id: String) -> String:
	if id.begins_with("tier:"):
		return "Tier" + id.substr(5).capitalize()
	if id.begins_with("redeem:"):
		return "Redeem_" + id.substr(7)
	if id.begins_with("choice:"):
		return "Choice_" + id.substr(7)
	match id:
		"look":
			return "LookButton"
		"pick":
			return "PickButton"
		"accept":
			return "AcceptButton"
		"decline":
			return "DeclineButton"
		"refuse":
			return "RefuseButton"
		"later":
			return "LaterButton"
		"send_off":
			return "SendOffButton"
	return "Reply_" + id.replace(":", "_")


func _ui(event_name: StringName, args: Dictionary) -> void:
	var event_bus := bus
	if event_bus == null and is_inside_tree():
		event_bus = get_node_or_null("/root/CardBus") as CardEventBus
	if event_bus != null:
		event_bus.ui_event.emit(event_name, args)
