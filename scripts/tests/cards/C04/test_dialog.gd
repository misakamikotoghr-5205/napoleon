# C04 dialog: typewriter, click, skip, blank-line split, draft opt lines,
# reply enablement, anchors, echo, the three ui events, set_max_bottom.
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const BOX := "res://scenes/cards/counter/DialogBox.tscn"


func _initialize() -> void:
	var t := T.new(self, "C04_dialog")
	t.run_async(_body.bind(t))


func _body(t) -> void:
	CardText.setup(CardDB.load_all(CardDB.DEFAULT_ROOT, {"only_examples": true}))
	var bus := CardEventBus.new()
	root.add_child(bus)
	var events: Array = []
	bus.ui_event.connect(func(name: StringName, args: Dictionary) -> void:
		events.append([str(name), args.duplicate(true)]))
	var box: CardDialogBox = load(BOX).instantiate()
	box.bus = bus
	root.add_child(box)
	await t.frames(1)
	await _typewriter(t, box, events)
	await _split(t, box)
	await _opt(t, box)
	await _replies(t, box, events)
	_bottom(t, box)
	await _fan_safe(t)
	await _reskin(t, bus)
	var plain: CardDialogBox = load(BOX).instantiate()
	plain.bus = bus
	plain.chars_per_sec = 0
	root.add_child(plain)
	plain.show_lines("c0002", [_line("c04.reply.look", false)])
	plain.set_replies([{
		"id": "look", "ref": "c04.reply.look", "style": "look",
		"anchor": "a.counter.look", "enabled": true, "echo": false,
	}])
	var bad: PackedStringArray = t.all_text_from_cardtext(plain)
	t.ok(bad.is_empty(), "dialog text comes from CardText: " + ", ".join(bad))
	plain.queue_free()
	box.queue_free()
	bus.queue_free()
	await t.frames(2)


func _typewriter(t, box: CardDialogBox, events: Array) -> void:
	box.chars_per_sec = 40
	var advanced: Array = []
	var done: Array = [0]
	box.advanced.connect(func(index: int) -> void: advanced.append(index))
	box.lines_done.connect(func() -> void: done[0] += 1)
	events.clear()
	box.show_lines("c0002", [_line("c04.reply.look", false), _line("c04.reply.later", false)])
	var body := box.find_child("ReplyLine", true, false) as Label
	t.eq(body.visible_characters, 0, "typewriter starts hidden")
	box._process(0.1)
	t.eq(body.visible_characters, 4, "40 chars per second reveals 4 in 0.1s")
	_click(box)
	t.ok(body.visible_characters < 0 or body.visible_characters >= body.text.length(), "click finishes the line")
	t.eq(str(body.get_meta("text_ref", "")), "c04.reply.look", "still the first line")
	_click(box)
	t.eq(advanced, [1], "second click advances")
	t.eq(str(body.get_meta("text_ref", "")), "c04.reply.later", "second line is showing")
	t.ok(events.any(func(row: Array) -> bool: return row[0] == "dialog_advanced"), "dialog_advanced")
	events.clear()
	box.show_lines("c0002", [_line("c04.reply.look", false), _line("c04.reply.refuse", false)])
	box.skip()
	t.ok(box.is_idle(), "skip reaches the end")
	t.eq(str(body.get_meta("text_ref", "")), "c04.reply.refuse", "skip shows the last line")
	t.ok(events.any(func(row: Array) -> bool: return row[0] == "dialog_skipped"), "dialog_skipped")
	t.ok(done[0] >= 1, "lines_done")
	await t.frames(1)


func _split(t, box: CardDialogBox) -> void:
	box.chars_per_sec = 40
	box.show_lines("c0002", [_line("c04.dialog.sample", false)])
	var body := box.find_child("ReplyLine", true, false) as Label
	var parts := CardText.t("c04.dialog.sample").split("\n\n", false)
	t.ok(parts.size() >= 2, "sample brief splits on a blank line")
	t.eq(body.text, str(parts[0]), "first sentence is the first paragraph")
	box.skip()
	t.eq(body.text, str(parts[parts.size() - 1]), "skip lands on the last paragraph")


# 界面键都有了正文（text_ai 基础层），这里用一个不登记、没有正文的键当草稿句。
func _opt(t, box: CardDialogBox) -> void:
	const DRAFT_REF := "c04.test.draft_opt"
	box.chars_per_sec = 0
	box.show_lines("c0002", [_line(DRAFT_REF, true), _line("c04.reply.look", false)])
	var body := box.find_child("ReplyLine", true, false) as Label
	t.eq(str(body.get_meta("text_ref", "")), "c04.reply.look", "draft opt line is skipped")
	t.ok(CardText.is_draft(DRAFT_REF), "test key is still a draft")


func _replies(t, box: CardDialogBox, events: Array) -> void:
	box.chars_per_sec = 0
	box.show_lines("c0002", [_line("c04.reply.look", false)])
	events.clear()
	box.set_replies([{
		"id": "tier:fair",
		"ref": "c04.tier.fair.pay",
		"args": {"n": 220},
		"style": "tier",
		"anchor": "a.counter.tier.fair",
		"enabled": true,
		"echo": true,
	}, {
		"id": "choice:gift",
		"ref": "p.brother.1938.farewell#choices.gift",
		"style": "choice",
		"enabled": false,
		"reason_ref": "g03.reason.money",
		"echo": true,
	}])
	t.ok(CardAnchors.has(&"a.counter.tier.fair"), "reply anchor registered")
	var gift := box.find_child("Choice_gift", true, false) as Button
	var reason := box.find_child("Reason_gift", true, false) as Label
	t.ok(gift != null and gift.disabled, "disabled reply")
	t.ok(gift.modulate.a < 0.6, "disabled reply is dimmed")
	t.ok(reason != null, "reason label")
	if reason != null:
		t.eq(reason.text, CardText.t("g03.reason.money"), "reason text")
	var before := events.size()
	gift.pressed.emit()
	t.eq(events.size(), before, "disabled reply sends no ui event")
	var fair := box.find_child("TierFair", true, false) as Button
	fair.pressed.emit()
	var said := box.find_child("SaidLine", true, false) as Label
	t.ok(said.visible, "echo shows what you said")
	t.eq(said.text, CardText.t("c04.tier.fair.pay", {"n": 220}), "echo text")
	t.ok(events.any(func(row: Array) -> bool:
		return row[0] == "reply_chosen" and str(row[1].get("reply", "")) == "tier:fair"), "reply_chosen")
	box.set_replies([])
	t.ok(not CardAnchors.has(&"a.counter.tier.fair"), "reply anchor unregistered")
	box.clear()
	t.ok(not CardAnchors.has(&"a.dialog"), "dialog anchor clears")


func _bottom(t, box: CardDialogBox) -> void:
	box.chars_per_sec = 0
	box.show_lines("c0002", [_line("c04.reply.look", false)])
	var replies: Array = []
	for i in 6:
		replies.append({
			"id": "later", "ref": "c04.reply.later", "style": "later",
			"enabled": true, "echo": false,
		})
	box.set_max_bottom(420)
	box.set_replies(replies)
	t.ok(box.size.y <= 420.0 - CardLayout.DIALOG.position.y + 0.5, "dialog stays above the max bottom")
	t.ok(box.size.y >= float(CardLayout.DIALOG_MIN_HEIGHT), "dialog keeps its minimum height")



# Contract 7.11.2: the bottom never passes y520, so the box stays off the hand fan
# and the hero even when a caller asks for 570 and there are many replies.
func _fan_safe(t) -> void:
	var box: CardDialogBox = load(BOX).instantiate()
	box.chars_per_sec = 0
	root.add_child(box)
	await t.frames(1)
	box.set_max_bottom(570)
	box.show_lines("c0002", [_line("c04.reply.look", false)])
	var replies: Array = []
	for i in 9:
		replies.append({
			"id": "later", "ref": "c04.reply.later", "style": "later",
			"enabled": true, "echo": false,
		})
	box.set_replies(replies)
	await t.frames(2)
	var frame := Rect2(box.position, box.size)
	t.ok(frame.end.y <= float(CardLayout.DIALOG_MAX_BOTTOM) + 0.5, "dialog bottom %.0f <= 520" % frame.end.y)
	t.ok(not frame.intersects(CardLayout.FAN), "dialog does not cover the hand fan")
	t.ok(not frame.intersects(CardLayout.HERO), "dialog does not cover the hero")
	var low := 0.0
	var n := 0
	for node in box.find_children("*", "Button", true, false):
		if node.has_meta("reply_id"):
			low = maxf(low, (node as Button).get_global_rect().end.y)
			n += 1
	t.eq(n, 9, "nine reply buttons")
	t.ok(low <= float(CardLayout.DIALOG_MAX_BOTTOM) + 0.5, "every reply stays above y520 (%.0f)" % low)
	box.queue_free()
	await t.frames(1)

# Reskin 10-23 bug fixes and the item row:
# b29 skip only while something is left to show; b27 the style mark is a small label inside the
# row, not a bar stretched over the row height; b28 a number the text lacks stays inside the frame;
# set_header() shows the item row, notes and lead line inside the frame, text from CardText.
func _reskin(t, bus: CardEventBus) -> void:
	var box: CardDialogBox = load(BOX).instantiate()
	box.bus = bus
	root.add_child(box)
	await t.frames(1)
	var skip := box.find_child("SkipButton", true, false) as Button
	box.chars_per_sec = 40
	box.show_lines("c0002", [_line("c04.reply.look", false), _line("c04.reply.later", false)])
	t.ok(skip.visible, "b29: skip shows while lines are left")
	box.skip()
	t.ok(box.is_idle() and not skip.visible, "b29: skip hides once everything is shown")
	box.chars_per_sec = 0
	box.set_replies([
		{"id": "look", "ref": "c04.reply.look", "args": {"n": 77}, "style": "look", "enabled": true, "echo": false},
		{"id": "tier:fair", "ref": "c04.tier.fair.pay", "args": {"n": 220}, "style": "tier", "enabled": true},
		{"id": "roll", "ref": "c04.reply.refuse", "style": "roll", "enabled": true, "echo": false},
		{"id": "later", "ref": "c04.reply.later", "style": "later", "enabled": true, "echo": false},
	])
	box.set_header({
		"art": "item.jewelry.hairpin", "title_ref": "c04.header.pawn", "title_args": {"name": "x"},
		"tags": [{"ref": "c04.intent.pawn"}, {"ref": "c04.header.asking", "args": {"n": 294}}],
		"notes": [{"label_ref": "c04.note.weigh", "text_ref": "c04.tickets.note", "args": {}}],
		"lead_ref": "c04.result.ticket", "gold": true,
	})
	await t.frames(1)
	var frame := Rect2(box.global_position, box.size)
	var prev_mark := Rect2()
	var buttons: Array = []
	for n in box.find_children("*", "Button", true, false):
		if n.has_meta("reply_id"):
			buttons.append(n)
	t.eq(buttons.size(), 4, "four reply rows")
	var styles := ["look", "tier", "roll", "later"]
	for i in buttons.size():
		var b: Button = buttons[i]
		var mark := b.find_child("Mark", false, false) as Label
		t.ok(mark != null and mark.text == CardText.ui("c04.reply.mark." + styles[i]), "b27: mark from the ui key " + styles[i])
		if mark == null:
			continue
		var mr := mark.get_global_rect()
		t.ok(mr.size.x <= 16.0 and mr.size.y <= b.size.y + 0.5, "b27: mark is a small glyph, not a bar")
		t.ok(prev_mark == Rect2() or mr.position.y >= prev_mark.end.y, "b27: marks of two rows do not join")
		prev_mark = mr
		t.ok(frame.encloses(b.get_global_rect()), "b28: reply row inside the frame " + b.text)
	var fair := box.find_child("TierFair", true, false) as Button
	t.ok(fair != null and fair.text.contains("220"), "b28: the tier price is in the row text")
	var num: Label = null
	for n in box.find_children("Num", "Label", true, false):
		if (n as Label).text == "77":
			num = n
	t.ok(num != null, "b28: a number the text lacks gets a label in the row")
	if num != null:
		t.ok(frame.encloses(num.get_global_rect()), "b28: that number stays inside the frame")
		t.ok(num.get_parent() == buttons[0].get_parent(), "b28: the number sits in its reply row")
	var header := box.find_child("ItemHeader", true, false) as Control
	t.ok(header != null and header.is_visible_in_tree(), "item row shows with the replies")
	var tags := box.find_child("HeaderTags", true, false) as Label
	t.ok(tags != null and tags.text.contains(CardText.ui("c04.intent.pawn")) and tags.text.contains("294"), "tags joined in one grey line")
	var title := box.find_child("HeaderTitle", true, false) as Label
	t.eq(title.text if title != null else "", CardText.ui("c04.header.pawn", {"name": "x"}), "item row title")
	var notes := box.find_child("Notes", true, false) as Control
	t.ok(notes != null and notes.is_visible_in_tree() and frame.encloses(notes.get_global_rect()), "inspect note bar inside the frame")
	var lead := box.find_child("LeadLine", true, false) as Label
	t.ok(lead != null and lead.is_visible_in_tree() and lead.text == CardText.t("c04.result.ticket"), "lead line")
	t.ok((box.find_child("GoldRing", true, false) as Control).visible, "gold ring for a gold card")
	for n in [header, notes, lead]:
		t.ok(frame.encloses((n as Control).get_global_rect()), "inside the frame: " + str(n.name))
	t.ok(box.size.y + box.position.y <= float(CardLayout.DIALOG_MAX_BOTTOM) + 0.5, "header box stays above y520")
	var bad: PackedStringArray = t.all_text_from_cardtext(box)
	t.ok(bad.is_empty(), "header and marks come from CardText: " + ", ".join(bad))
	box.clear()
	t.ok(not header.visible or not box.visible, "clear hides the item row")
	t.ok(not (box.find_child("GoldRing", true, false) as Control).visible, "clear drops the gold ring")
	box.queue_free()
	await t.frames(1)


func _line(ref: String, opt: bool) -> Dictionary:
	return {"kind": "narr", "who": "", "ref": ref, "args": {}, "opt": opt}


func _click(box: CardDialogBox) -> void:
	var ev := InputEventMouseButton.new()
	ev.pressed = true
	ev.button_index = MOUSE_BUTTON_LEFT
	box._on_body_input(ev)
