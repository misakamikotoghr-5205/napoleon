# RG4 title run box (card_title.gd + title_run_box.gd; ROGUE_V1.md 7.5). CardTitle.tscn on its own:
# without set_rogue there is no box and the C16 focus rules hold (focus starts on new, arrows and Tab wrap among the
# four buttons); with set_rogue the box sits at (744, 400, 456 x 280), the seed field shows the seed, "another one"
# sends chose(&"reseed"), switching the opening sends chose(&"opening") and opening_id() follows, a locked opening
# hides the row; with focus in the seed field W A S D, Space and the arrows go into the field (button focus does not
# move), Esc hands focus back to new and Enter sends chose(&"new"); one spine per closed ledger, hovering one shows
# its book number and chronicle line; all words from CardText; three title round trips keep the object count flat;
# a set_rogue call before the title is ready (the root boots off-tree) still puts the box over the background, focus wired.
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const H = preload("res://scripts/tests/cards/RG4/rg4_harness.gd")
const SEED := 1844671223


func _initialize() -> void:
	var t := T.new(self, "RG4_title")
	t.run_async(_body.bind(t))


func _body(t) -> void:
	CardSave.set_root(t.user_dir())
	await _plain(t)
	await _box(t)
	await _early(t)
	await _open_ledger(t)
	await _confirm_new(t)
	await _locked(t)
	await _seed_keys(t)
	await _focus_ring(t)
	await _update(t)
	await _cycles(t)
	print("RG4_title checks %d" % t.checks)
	await t.frames(2)


func _data(unlocked: bool) -> Dictionary:
	return {"run_no": 4, "seed": SEED, "opening": "og.default",
		"openings": [{"id": "og.default", "unlocked": true}, {"id": "og.shanghai", "unlocked": unlocked}],
		"shelf": [
			{"no": 1, "key": "rg5.chronicle.prison.1939", "args": {"d": 17}, "reason": "prison", "opening": "og.default"},
			{"no": 2, "key": "rg5.chronicle.abandoned.1938", "args": {"d": 9}, "reason": "abandoned", "opening": "og.default"},
			{"no": 3, "key": "rg5.chronicle.ending.kind", "args": {}, "reason": "ending", "opening": "og.shanghai"}],
		"notice_key": ""}


func _title(t) -> CardTitle:
	var title: CardTitle = load(H.TITLE_SCENE).instantiate()
	root.add_child(title)
	await t.frames(2)
	return title


func _drop(t, title: Node) -> void:
	title.queue_free()
	await t.frames(2)


func _box_of(title: CardTitle):
	return title.get_node_or_null("RunBox")


func _focus() -> Control:
	return root.gui_get_focus_owner()


## No set_rogue: the title is exactly the C16 title.
func _plain(t) -> void:
	var title := await _title(t)
	t.ok(_box_of(title) == null, "no set_rogue: no run box")
	t.eq(title.seed_text(), "", "no box: seed_text is empty")
	t.eq(title.opening_id(), "og.default", "no box: default opening")
	t.eq(_focus(), title.get_node("new"), "no box: focus starts on new")
	for i in 6:
		await H.tap(self, KEY_UP)
		var f := _focus()
		t.ok(f != null and title.is_ancestor_of(f) and f is Button, "no box: Up #%d stays on the title buttons" % i)
	await H.tap(self, KEY_TAB)
	t.ok(title.is_ancestor_of(_focus()), "no box: Tab stays on the title")
	await _drop(t, title)


func _box(t) -> void:
	var title := await _title(t)
	var got: Array = []
	title.chose.connect(func(a: StringName) -> void: got.append(a))
	var data := _data(true)
	data["notice_key"] = "rg5.toast.profile_reset"
	title.set_rogue(data)
	await t.frames(1)
	var box = _box_of(title)
	t.ok(box != null, "set_rogue builds the run box")
	if box == null:
		await _drop(t, title)
		return
	t.eq(box.get_global_rect(), Rect2(744, 400, 456, 280), "run box rectangle")
	t.eq(_focus(), title.get_node("new"), "box: focus still starts on new")
	t.eq(H.count_text(box, CardText.ui("rg4.title.run_no", {"n": 4})), 1, "which ledger opens next")
	t.eq(H.count_text(box, CardText.ui("rg4.title.shelf_empty")), 0, "a shelf with spines has no empty line")
	t.eq(box.seed_field().tooltip_text, CardText.ui("rg4.title.seed_tip"), "the seed field says what a seed is on hover")
	t.eq(box.seed_field().text, str(SEED), "the seed field shows the seed")
	t.eq(title.seed_text(), str(SEED), "seed_text gives the field text")
	t.eq(box.seed_field().size, Vector2(180, 32), "seed field 180 x 32")
	t.ok(Rect2(744, 400, 456, 280).encloses(box.reseed_button().get_global_rect()), "another-one button inside the box")
	t.eq(H.count_text(box, CardText.ui("rg5.toast.profile_reset")), 1, "notice shown on top of the box")
	await H.click(self, box.reseed_button().get_global_rect().get_center())
	t.eq(got, [&"reseed"], "another one sends chose(reseed)")
	var buttons: Dictionary = box.opening_buttons()
	t.eq(buttons.keys(), ["og.default", "og.shanghai"], "two unlocked openings: both buttons")
	t.eq((buttons["og.shanghai"] as Button).text, CardText.ui("rg5.opening.shanghai"), "opening words from rg5.opening.*")
	for id in buttons:
		t.ok(Rect2(744, 400, 456, 280).encloses((buttons[id] as Button).get_global_rect()), id + ": opening button inside the box")
	t.ok(bool((buttons["og.default"] as Button).get_meta("on")), "the shell's opening is marked")
	await H.click(self, (buttons["og.shanghai"] as Button).get_global_rect().get_center())
	t.eq(got, [&"reseed", &"opening"], "switching the opening sends chose(opening)")
	t.eq(title.opening_id(), "og.shanghai", "opening_id follows the switch")
	await H.click(self, (buttons["og.shanghai"] as Button).get_global_rect().get_center())
	t.eq(got.size(), 2, "pressing the chosen opening again sends nothing")
	await _spines(t, box)
	t.eq(t.all_text_from_cardtext(title).size(), 0, "title and box words from CardText")
	t.eq(_focus(), title.get_node("new"), "mouse use of the box leaves focus on new")
	await _drop(t, title)


func _spines(t, box) -> void:
	var spines: Array = box.spines()
	t.eq(spines.size(), 3, "one spine per closed ledger")
	var tones := [&"seal", &"wood", &"gold"]
	for i in spines.size():
		var p: Panel = spines[i]
		t.eq(p.size, Vector2(24, 100), "spine %d is 24 x 100" % i)
		var sb := p.get_theme_stylebox("panel") as StyleBoxFlat
		t.ok(sb != null and sb.bg_color.is_equal_approx(CardTheme.color(tones[i])), "spine %d coloured by how it closed" % i)
		t.eq(H.count_text(p, CardText.ui("rg4.title.book_no", {"n": i + 1})), 1, "spine %d shows its book number" % i)
		t.ok(Rect2(744, 400, 456, 280).encloses(p.get_global_rect()), "spine %d inside the box" % i)
	t.ok(spines[2].get_global_rect().position.x > spines[0].get_global_rect().position.x, "newest spine on the right")
	var read: Array = box.read_labels()
	t.ok(not (read[0] as Control).is_visible_in_tree(), "chronicle line hidden until a spine is hovered")
	await H.hover(self, (spines[0] as Control).get_global_rect().get_center())
	t.ok((read[0] as Control).is_visible_in_tree(), "hovering a spine shows its line")
	t.eq((read[0] as Label).text, CardText.ui("rg4.title.book_no", {"n": 1}), "hover: book number")
	t.eq((read[1] as Label).text, CardText.ui("rg5.chronicle.prison.1939", {"d": 17}), "hover: chronicle line")
	await H.hover(self, (spines[2] as Control).get_global_rect().get_center())
	t.eq((read[1] as Label).text, CardText.ui("rg5.chronicle.ending.kind", {}), "hover another spine: its line")
	await H.hover(self, Vector2(200, 100))
	t.ok(not (read[0] as Control).is_visible_in_tree(), "leaving the spines hides the line")


## The real root boots before it enters the tree, so the shell can call set_rogue before the title's _ready
## (CardGameRoot.boot -> _show_title -> keeper.on_title). The box still sits over the background and the wash,
## and the seed field's focus neighbours still point at new (Tab from the field never leaves the title).
func _early(t) -> void:
	var title: CardTitle = load(H.TITLE_SCENE).instantiate()
	title.set_rogue(_data(true))
	root.add_child(title)
	await t.frames(2)
	var box = _box_of(title)
	t.ok(box != null, "set_rogue before _ready: the box is there once the title is ready")
	if box == null:
		await _drop(t, title)
		return
	for under in ["Back", "Wash"]:
		t.ok(box.get_index() > title.get_node(under).get_index(), "set_rogue before _ready: box drawn over " + under)
	t.eq(title.seed_text(), str(SEED), "set_rogue before _ready: the seed field shows the seed")
	t.eq(_focus(), title.get_node("new"), "set_rogue before _ready: focus starts on new")
	var field: LineEdit = box.seed_field()
	var home := field.get_path_to(title.get_node("new"))
	t.eq([field.focus_next, field.focus_previous, field.focus_neighbor_top, field.focus_neighbor_bottom],
		[home, home, home, home], "set_rogue before _ready: the seed field's focus neighbours point at new")
	await H.click(self, field.get_global_rect().get_center())
	t.eq(_focus(), field, "set_rogue before _ready: a click gives the seed field focus")
	await H.tap(self, KEY_TAB)
	t.eq(_focus(), title.get_node("new"), "set_rogue before _ready: Tab from the seed field goes to new")
	await _drop(t, title)


## A ledger still open (open_no): the head line says it is not closed yet and that "open shop" starts the next one
## (never "this is ledger n+1" next to a resumable ledger n); an empty shelf says what will stand there.
func _open_ledger(t) -> void:
	var title := await _title(t)
	var data := _data(false)
	data["run_no"] = 2
	data["open_no"] = 1
	data["shelf"] = []
	title.set_rogue(data)
	await t.frames(1)
	var box = _box_of(title)
	t.eq(H.count_text(box, CardText.ui("rg4.title.run_open", {"open": 1, "n": 2})), 1, "open ledger: not closed yet")
	t.eq(H.count_text(box, CardText.ui("rg4.title.run_no", {"n": 2})), 0, "open ledger: no bare next-ledger line")
	t.eq(H.count_text(box, CardText.ui("rg4.title.shelf_empty")), 1, "empty shelf: one line on what goes there")
	t.ok(Rect2(744, 400, 456, 280).encloses(box.find_child("RunNo", true, false).get_global_rect()), "head line inside the box")
	t.eq(t.all_text_from_cardtext(title).size(), 0, "open ledger: words from CardText")
	await _drop(t, title)


## Acceptance 2: with a ledger still open, "new" (click, Enter on it, Enter in the seed field) first asks in place of
## the four buttons, focus on "think again"; Enter there / Esc / "think again" send nothing and bring the buttons back;
## only "close it, start another" sends chose(&"new"). No ledger open: "new" goes straight through as before.
func _confirm_new(t) -> void:
	var title := await _title(t)
	var got: Array = []
	title.chose.connect(func(a: StringName) -> void: got.append(a))
	var data := _data(false)
	data["run_no"] = 2
	data["open_no"] = 1
	title.set_rogue(data)
	await t.frames(1)
	var new_btn := title.get_node("new") as Button
	t.eq(_focus(), new_btn, "open ledger: focus still starts on new")
	await H.tap(self, KEY_ENTER)
	t.eq(got, [], "open ledger: Enter on new sends nothing yet")
	t.ok(title.is_asking_new(), "open ledger: Enter on new asks first")
	var ask := title.get_node_or_null("ConfirmNew")
	t.ok(ask != null and H.count_text(ask, CardText.ui("rg4.title.confirm_new", {"open": 1, "n": 2})) == 1,
		"the question names the open ledger and the next one")
	t.ok(not new_btn.visible, "the four buttons step aside while asking")
	t.eq(_focus(), ask.find_child("ConfirmNo", true, false) if ask != null else null, "think again has the focus")
	t.eq(t.all_text_from_cardtext(title).size(), 0, "the question's words come from CardText")
	await H.tap(self, KEY_ENTER)
	t.eq(got, [], "a second Enter (think again) sends nothing")
	t.ok(not title.is_asking_new() and new_btn.visible, "think again brings the buttons back")
	t.eq(_focus(), new_btn, "focus returns to new")
	new_btn.pressed.emit()
	t.ok(title.is_asking_new(), "a click on new asks too")
	await H.tap(self, KEY_ESCAPE)
	t.ok(not title.is_asking_new(), "Esc is think again")
	t.eq(got, [], "Esc sends nothing")
	var field: LineEdit = _box_of(title).seed_field()
	await H.click(self, field.get_global_rect().get_center())
	await H.tap(self, KEY_ENTER)
	t.ok(title.is_asking_new(), "Enter in the seed field asks too")
	t.eq(got, [], "Enter in the seed field sends nothing yet")
	var yes := title.get_node("ConfirmNew").find_child("ConfirmYes", true, false) as Button
	await H.click(self, yes.get_global_rect().get_center())
	t.eq(got, [&"new"], "close it, start another sends new once")
	t.ok(not title.is_asking_new(), "the question goes away")
	data["open_no"] = 0
	title.set_rogue(data)
	await t.frames(1)
	new_btn.pressed.emit()
	t.eq(got, [&"new", &"new"], "no ledger open: new goes straight through")
	t.ok(not title.is_asking_new(), "no ledger open: nothing asked")
	await _drop(t, title)


## Only one opening unlocked: no opening row at all; the default opening is used.
func _locked(t) -> void:
	var title := await _title(t)
	title.set_rogue(_data(false))
	await t.frames(1)
	var box = _box_of(title)
	t.eq(box.opening_buttons().size(), 0, "locked opening: no opening buttons")
	t.eq(H.count_text(box, CardText.ui("rg4.title.opening")), 0, "locked opening: no opening label")
	t.eq(H.count_text(box, CardText.ui("rg5.opening.shanghai")), 0, "locked opening is not shown")
	t.eq(title.opening_id(), "og.default", "locked opening: opening_id is the default")
	var stale := _data(false)
	stale["opening"] = "og.shanghai"
	title.set_rogue(stale)
	await t.frames(1)
	t.eq(title.opening_id(), "og.default", "a locked opening is never the chosen one")
	var many := _data(false)
	var shelf: Array = []
	for i in 20:
		shelf.append({"no": i + 1, "key": "rg5.chronicle.other", "args": {"d": 3}, "reason": "other", "opening": "og.default"})
	many["shelf"] = shelf
	title.set_rogue(many)
	await t.frames(1)
	var spines: Array = box.spines()
	t.eq(spines.size(), 16, "at most sixteen spines")
	t.eq(int(spines[15].get_meta("no")), 20, "the newest ledger is the last spine")
	t.ok(Rect2(744, 400, 456, 280).encloses(spines[15].get_global_rect()), "sixteen spines fit the box")
	await _drop(t, title)


## Focus in the seed field: every key but Enter / Esc belongs to the field.
func _seed_keys(t) -> void:
	var title := await _title(t)
	var got: Array = []
	title.chose.connect(func(a: StringName) -> void: got.append(a))
	title.set_rogue(_data(true))
	await t.frames(1)
	var field: LineEdit = _box_of(title).seed_field()
	await H.click(self, field.get_global_rect().get_center())
	t.eq(_focus(), field, "a click gives the seed field focus")
	var keys := [[KEY_W, 119], [KEY_A, 97], [KEY_S, 115], [KEY_D, 100], [KEY_SPACE, 32]]
	for k in keys:
		await H.tap(self, k[0], k[1])
		t.eq(_focus(), field, "key %s keeps focus in the field" % OS.get_keycode_string(k[0]))
	# push_input bypasses the Input singleton, so LineEdit's select-all-on-click (done on mouse release in real
	# play) does not run here: the letters land at the caret instead of replacing the seed.
	t.ok(field.text.contains("wasd ") and field.text.replace("wasd ", "") == str(SEED),
		"W A S D and Space type into the field (got '%s')" % field.text)
	for code in [KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT]:
		await H.tap(self, code)
		t.eq(_focus(), field, "arrow %s stays in the field" % OS.get_keycode_string(code))
	t.eq(got, [], "typing sends nothing")
	await H.tap(self, KEY_ESCAPE)
	t.eq(_focus(), title.get_node("new"), "Esc hands focus back to new")
	t.eq(got, [], "Esc sends nothing")
	await H.tap(self, KEY_DOWN)
	t.eq(_focus(), title.get_node("settings"), "after Esc the arrows move among the buttons again (continue is off)")
	await H.click(self, field.get_global_rect().get_center())
	t.eq(_focus(), field, "a second click gives the field focus again")
	field.select_all()
	for ch in "12345":
		await H.tap(self, OS.find_keycode_from_string(ch), ch.unicode_at(0))
	t.eq(title.seed_text(), "12345", "typed seed replaces the selected text")
	await H.tap(self, KEY_ENTER)
	t.eq(got, [&"new"], "Enter in the seed field opens the shop, once")
	await _drop(t, title)


## With the box shown, Up / Down / Tab still wrap among the four buttons; the field and the box are mouse only.
func _focus_ring(t) -> void:
	var title := await _title(t)
	title.set_rogue(_data(true))
	await t.frames(1)
	var box = _box_of(title)
	for i in 8:
		await H.tap(self, KEY_DOWN if i % 2 == 0 else KEY_TAB)
		var f := _focus()
		t.ok(f is Button and f.get_parent() == title, "box shown: key #%d keeps focus on the four buttons" % i)
		t.ok(not box.is_ancestor_of(f), "box shown: key #%d never lands in the box" % i)
	await _drop(t, title)


## The shell calls set_rogue again: a new seed (after another one) replaces the field; the same seed keeps typing.
func _update(t) -> void:
	var title := await _title(t)
	title.set_rogue(_data(true))
	await t.frames(1)
	var box = _box_of(title)
	box.seed_field().text = "777"
	var same := _data(true)
	same["opening"] = "og.shanghai"
	title.set_rogue(same)
	await t.frames(1)
	t.eq(title.seed_text(), "777", "same seed: the typed text stays")
	t.eq(title.opening_id(), "og.shanghai", "set_rogue sets the chosen opening")
	t.ok(bool((box.opening_buttons()["og.shanghai"] as Button).get_meta("on")), "the chosen opening is marked")
	var fresh := _data(true)
	fresh["seed"] = 99117
	title.set_rogue(fresh)
	await t.frames(1)
	t.eq(title.seed_text(), "99117", "a new seed replaces the field")
	t.eq(_box_of(title), box, "set_rogue reuses the box")
	await _drop(t, title)


## Three title round trips with the box (C16's +8 tolerance).
func _cycles(t) -> void:
	var t0 := await _title(t)
	t0.set_rogue(_data(true))
	await t.frames(2)
	await _drop(t, t0)
	await t.frames(3)
	var before := int(Performance.get_monitor(Performance.OBJECT_COUNT))
	for _i in 3:
		var title := await _title(t)
		title.set_rogue(_data(true))
		title.set_rogue(_data(false))
		await H.hover(self, Vector2(760, 600))
		await _drop(t, title)
		await t.frames(3)
	var after := int(Performance.get_monitor(Performance.OBJECT_COUNT))
	print("RG4_title_delta " + str(after - before))
	t.ok(after <= before + 8, "three title round trips with the box do not leak objects")
	t.eq(int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)), 0, "no orphan nodes")
