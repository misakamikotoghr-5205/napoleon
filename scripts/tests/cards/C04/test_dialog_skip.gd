# C04 dialog with the default text fallback (no draft text): a line nobody has written is skipped,
# never shown as an empty beat; all lines unwritten = the box finishes at once.
# Framework wrap-up 2026-10-22 (story packs, docs/cards/PLUGINS.md). ASCII fixture text only.
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const H = preload("res://scripts/tests/cards/G01/helper.gd")
const BOX := "res://scenes/cards/counter/DialogBox.tscn"


func _initialize() -> void:
	var t := T.new(self, "C04_dialog_skip")
	t.run_async(_body.bind(t))


func _line(ref: String, kind: String = "narr") -> Dictionary:
	return {"kind": kind, "who": "ruhua" if kind == "say" else "", "ref": ref, "args": {}, "opt": false}


func _body(t) -> void:
	var root_dir: String = t.user_dir() + "/cards"
	H.write(root_dir + "/text/ui/test.text.json", {"c04.reply.look": {"t": "LOOK"}, "c04.reply.later": {"t": "LATER"}})
	CardText.setup(CardDB.load_all(root_dir))
	CardText.set_show_drafts(false)
	var bus := CardEventBus.new()
	root.add_child(bus)
	var box: CardDialogBox = load(BOX).instantiate()
	box.bus = bus
	box.chars_per_sec = 0
	root.add_child(box)
	await t.frames(1)
	var done := [0]
	box.lines_done.connect(func() -> void: done[0] += 1)
	box.show_lines("c0002", [_line("c04.reply.look"), _line("c04.unwritten.one"), _line("c04.unwritten.two", "say"),
		_line("c04.reply.later")])
	var body := box.find_child("ReplyLine", true, false) as Label
	t.eq(str(body.get_meta("text_ref", "")), "c04.reply.later", "unwritten lines skipped, last written line shows")
	t.eq(body.text, "LATER", "written text")
	t.ok(box.is_idle(), "box idle after the written lines")
	done[0] = 0
	box.show_lines("c0002", [_line("c04.unwritten.one"), _line("c04.unwritten.two", "say")])
	t.ok(box.is_idle(), "nothing written: box is idle at once")
	t.ok(done[0] >= 1, "nothing written: lines_done fires so the scene goes on")
	t.eq(body.text, "", "no blank beat is shown")
	CardText.set_show_drafts(true)
	box.show_lines("c0002", [_line("c04.unwritten.one")])
	t.ok(body.text != "", "drafts on: the draft line shows (development view)")
	box.queue_free()
	bus.queue_free()
	await t.frames(2)
