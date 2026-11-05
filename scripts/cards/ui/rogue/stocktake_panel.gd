# Rogue v1 weekly stocktake / peddler pick overlay (stocktake). The engine asks for it (view.open_panel) on the
# settle of stage days 7/14/21/28 and when the peddler opens his pack; the curio drawer's "one left to pick" button
# opens it too. Reads the stocktake query only: two or three cards (relics framed by depth, sources in jade), the
# week's deal count (the player's own work, a visible count), no effect sizes anywhere.
# Buttons: take this one -> stock.pick {offer, pick} (a relic while the shelf is full first asks which held relic
# to give up, then stock.pick {offer, pick, replace}); none of them -> stock.pick {offer, pick: ""}; later -> only
# closes. Esc, the scrim and dismiss() close without a command (Esc steps back out of the release step first).
# A pick that went through closes with {"say": [the notices it added to view.notice.news]} (the gain / released /
# passed lines): the root says them in the dialog at once, since a night pick's board is wiped at dawn unseen.
# Keys: 1-3 pick a card (gold edge), Enter presses its button; in the release step 1-6 pick a held relic,
# Enter confirms. refresh() closes the overlay once the offer is no longer open (closed for the night, lapsed).
# Owner RG4. Overlay space = CardLayout.OVERLAY_MAX (90, 40, 1100 x 640); the coordinates below are sheet space.
# Contract: docs/cards/rogue/ROGUE_V1.md sections 4.2, 4.3, 7.1, 7.2, 11.
extends CardPanel

const Ui = preload("res://scripts/cards/ui/rogue/rogue_ui.gd")
const OfferCard = preload("res://scripts/cards/ui/rogue/offer_card.gd")
const ReleaseRow = preload("res://scripts/cards/ui/rogue/release_row.gd")

const KIND := &"stocktake"
const CMD_PICK := &"stock.pick"
const ERR_FULL := "relic_full"
const ERR_LINE := "rg2.reason.offer_closed"
const TITLE_AT := Vector2(40, 20)
const TITLE_SIZE := Vector2(1020, 36)
const TITLE_FONT := 26
const SUB_AT := Vector2(40, 60)
const CARD_Y := 100.0
const CARD_GAP := 32.0
const PASS_AT := Vector2(310, 516)
const LATER_AT := Vector2(590, 516)
const FOOT_BTN := Vector2(200, 44)
const RELEASE_Y := 512.0
const NOTE_Y := 260.0

var _offer: String = ""
var _q: Dictionary = {}
var _sig: String = ""
var _cards: Array = []
var _sel: int = -1
var _swap_pick: String = ""
var _failed: bool = false
var _closed: bool = false
## While our own stock.pick runs: the view_changed it raises must not close the sheet before the pick's lines are read.
var _sending: bool = false
var _sheet: Panel
var _body: Control
var _row: Control
var _release: ReleaseRow = null
var _pass_btn: Button
var _later_btn: Button


func open(args: Dictionary) -> void:
	_offer = str(args.get("offer", ""))
	_closed = false
	_failed = false
	_swap_pick = ""
	_sel = -1
	_ensure()
	_q = _ask()
	_sig = JSON.stringify(_q, "", true)
	_render()


func refresh(_view: Dictionary) -> void:
	if _closed or _sheet == null or _failed or _sending:
		return
	var q := _ask()
	if not _is_open(q):
		_close()
		return
	var sig := JSON.stringify(q, "", true)
	if sig == _sig:
		return
	_q = q
	_sig = sig
	if _swap_pick != "" and not (_has_item(_swap_pick) and bool(_q.get("full", false))):
		_swap_pick = ""
	_render()


## Same state, same step: pick the first card (a relic on a full shelf gives up the oldest held one).
func autoplay_step() -> bool:
	if _closed or _failed or not _is_open(_q):
		return false
	var items := _items()
	var first: Dictionary = items[0]
	var replace := ""
	if str(first.get("kind", "")) == "relic" and bool(_q.get("full", false)):
		var held := Ui.array(_q.get("held", []))
		replace = str(Ui.dict(held[0]).get("id", "")) if not held.is_empty() else ""
	_send(str(first.get("id", "")), replace)
	return true


## Esc / the host: step back out of the release step, otherwise close. Never sends a command.
func dismiss() -> void:
	if _closed:
		return
	if _swap_pick != "" and not _failed:
		_leave_swap()
		return
	_close()


func offer_id() -> String:
	return str(_q.get("offer", _offer))


func cards() -> Array:
	return _cards.duplicate()


func selected() -> int:
	return _sel


func in_release_step() -> bool:
	return _swap_pick != ""


func release_row() -> Control:
	return _release


func pass_button() -> Button:
	return _pass_btn


func later_button() -> Button:
	return _later_btn


func _exit_tree() -> void:
	engine = null
	bus = null


func _unhandled_input(event: InputEvent) -> void:
	if _closed or not is_visible_in_tree():
		return
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if _on_key(key.keycode):
		var vp := get_viewport()
		if vp != null:
			vp.set_input_as_handled()


func _on_key(code: int) -> bool:
	if code == KEY_ESCAPE:
		dismiss()
		return true
	var digit := code - KEY_1 if code >= KEY_1 and code <= KEY_9 else -1
	var enter := code == KEY_ENTER or code == KEY_KP_ENTER
	if _failed or not _is_open(_q):
		if enter:
			_close()
		return enter
	if _swap_pick != "" and _release != null:
		if digit >= 0 and digit < _release.held.size():
			_release.pick(digit)
			return true
		if enter:
			_confirm_swap()
			return true
		return false
	if digit >= 0 and digit < _cards.size():
		_select(digit)
		return true
	if enter:
		if _sel >= 0:
			_take(_sel)
		else:
			_press_focused()
		return true
	return false


func _press_focused() -> void:
	var vp := get_viewport()
	var focus := vp.gui_get_focus_owner() if vp != null else null
	if focus is Button and is_ancestor_of(focus) and not (focus as Button).disabled:
		(focus as Button).pressed.emit()


# ---------------- building ----------------

## Full-screen catcher (the host already shades the table) + the dark modal sheet over the whole overlay box.
func _ensure() -> void:
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	position = CardLayout.OVERLAY_MAX.position
	size = CardLayout.OVERLAY_MAX.size
	mouse_filter = Control.MOUSE_FILTER_STOP
	if _sheet != null:
		return
	var scrim := ColorRect.new()
	scrim.name = "Scrim"
	scrim.color = Color.TRANSPARENT if has_meta("shade") else CardTheme.color(&"shade")
	scrim.position = -CardLayout.OVERLAY_MAX.position
	scrim.size = Vector2(1280, 720)
	scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	scrim.gui_input.connect(_on_scrim)
	add_child(scrim)
	var lift := Panel.new()
	lift.name = "SheetShadow"
	lift.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lift.size = CardLayout.OVERLAY_MAX.size
	lift.add_theme_stylebox_override("panel", CardTheme.modal_shadow_style())
	add_child(lift)
	_sheet = Panel.new()
	_sheet.name = "Sheet"
	_sheet.size = CardLayout.OVERLAY_MAX.size
	_sheet.mouse_filter = Control.MOUSE_FILTER_STOP
	_sheet.add_theme_stylebox_override("panel", CardTheme.modal_style())
	add_child(_sheet)


func _on_scrim(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		_close()


func _render() -> void:
	if _body != null:
		_sheet.remove_child(_body)
		_body.queue_free()
	_cards = []
	_row = null
	_release = null
	_pass_btn = null
	_later_btn = null
	_body = Control.new()
	_body.name = "Body"
	_body.size = CardLayout.OVERLAY_MAX.size
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sheet.add_child(_body)
	if _failed or not _is_open(_q):
		_render_note()
		return
	_render_head()
	_render_cards()
	if _swap_pick != "":
		_render_release()
	else:
		_render_foot()


func _render_head() -> void:
	var peddler := str(_q.get("from", "")) == "peddler"
	var key := "rg4.stock.title.peddler" if peddler else "rg4.stock.title.week"
	var args := {} if peddler else {"n": int(_q.get("week", 0)) + 1}
	var title := Ui.label(CardText.ui(key, args), TITLE_FONT, &"gold_hi", &"title", CardText.is_draft(key))
	title.name = "Title"
	title.position = TITLE_AT
	title.size = TITLE_SIZE
	_body.add_child(title)
	var sub := Ui.row_box(10)
	sub.name = "Sub"
	sub.position = SUB_AT
	sub.size = Vector2(TITLE_SIZE.x, 24)
	_body.add_child(sub)
	if peddler:
		sub.add_child(_sub_label("PeddlerSub", "rg4.stock.peddler_sub", {}, &"hud_ink"))
		return
	sub.add_child(_sub_label("Deals", "rg4.stock.deals", {"deals": int(_q.get("deals", 0))}, &"hud_ink"))
	if _items().size() == 2:
		sub.add_child(_sub_label("Few", "rg4.stock.few", {}, &"text_2"))
	sub.add_child(_sub_label("How", "rg4.stock.how", {}, &"text_2"))


func _sub_label(node_name: String, key: String, args: Dictionary, tone: StringName) -> Label:
	var l := Ui.label(CardText.ui(key, args), 16, tone, &"body", CardText.is_draft(key))
	l.name = node_name
	return l


func _render_cards() -> void:
	var items := _items()
	var n := items.size()
	var width := float(n) * OfferCard.SIZE.x + float(maxi(n - 1, 0)) * CARD_GAP
	_row = Control.new()
	_row.name = "Offers"
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_row.position = Vector2(roundf((CardLayout.OVERLAY_MAX.size.x - width) * 0.5), CARD_Y)
	_row.size = Vector2(width, OfferCard.SIZE.y)
	_body.add_child(_row)
	for i in n:
		var card = OfferCard.new()
		card.setup(Ui.dict(items[i]), i)
		card.position = Vector2(float(i) * (OfferCard.SIZE.x + CARD_GAP), 0.0)
		card.take_pressed.connect(_take)
		card.face_pressed.connect(_select)
		_row.add_child(card)
		_cards.append(card)
	CardAnchors.register(&"a.stock.offers", _row)
	if _swap_pick != "":
		for card in _cards:
			card.set_locked(true)
			card.set_dim(card.item_id != _swap_pick)
			card.set_selected(card.item_id == _swap_pick)
	elif _sel >= 0 and _sel < _cards.size():
		_cards[_sel].set_selected(true)


func _render_foot() -> void:
	_pass_btn = _foot_button("Pass", "rg4.stock.pass", PASS_AT)
	_pass_btn.pressed.connect(_send.bind("", ""))
	_later_btn = _foot_button("Later", "rg4.stock.later", LATER_AT)
	_later_btn.pressed.connect(_close)
	if _sel < 0 and _later_btn.is_inside_tree():
		_later_btn.grab_focus()


func _render_release() -> void:
	var row: ReleaseRow = ReleaseRow.new()
	row.position = Vector2(0, RELEASE_Y)
	_body.add_child(row)
	row.setup(Ui.array(_q.get("held", [])))
	row.confirmed.connect(_confirm_swap)
	row.cancelled.connect(_leave_swap)
	_release = row


## The offer is gone (picked elsewhere, lapsed, no offer at all) or a pick failed: one line and a way out.
func _render_note() -> void:
	var note := Ui.label(CardText.ui(ERR_LINE), 18, &"hud_ink", &"body", CardText.is_draft(ERR_LINE))
	note.name = "Note"
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.position = Vector2(140, NOTE_Y)
	note.size = Vector2(820, 60)
	_body.add_child(note)
	_later_btn = _foot_button("Later", "rg4.stock.later", LATER_AT - Vector2(140, 0))
	_later_btn.pressed.connect(_close)
	if _later_btn.is_inside_tree():
		_later_btn.grab_focus()


func _foot_button(node_name: String, key: String, at: Vector2) -> Button:
	var b := Button.new()
	b.name = node_name
	b.text = CardText.ui(key)
	b.focus_mode = Control.FOCUS_ALL
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.position = at
	b.size = FOOT_BTN
	_body.add_child(b)
	return b


# ---------------- acting ----------------

func _select(i: int) -> void:
	if _swap_pick != "" or i < 0 or i >= _cards.size():
		return
	_sel = i
	for j in _cards.size():
		_cards[j].set_selected(j == i)
	var b: Button = _cards[i].button()
	if b != null and b.is_inside_tree():
		b.grab_focus()


func _take(i: int) -> void:
	var items := _items()
	if _closed or i < 0 or i >= items.size():
		return
	var item := Ui.dict(items[i])
	var id := str(item.get("id", ""))
	if str(item.get("kind", "")) == "relic" and bool(_q.get("full", false)):
		_enter_swap(id)
		return
	_send(id, "")


func _enter_swap(id: String) -> void:
	_swap_pick = id
	_render()


func _leave_swap() -> void:
	_swap_pick = ""
	_render()


func _confirm_swap() -> void:
	if _release == null or _release.picked_id() == "":
		return
	_send(_swap_pick, _release.picked_id())


func _send(pick: String, replace: String) -> void:
	if _closed or engine == null:
		return
	var args := {"offer": offer_id(), "pick": pick}
	if replace != "":
		args["replace"] = replace
	var before := _news().size()
	_sending = true
	var r := engine.send(CMD_PICK, args)
	_sending = false
	if bool(r.get("ok", false)):
		var said := _news()
		_close({"say": said.slice(before)} if said.size() > before else {})
		return
	if str(r.get("err", "")) == ERR_FULL and pick != "" and replace == "":
		# The shelf filled up after the overlay last looked: ask again and go to the release step.
		_q = _ask()
		_sig = JSON.stringify(_q, "", true)
		if _is_open(_q):
			_enter_swap(pick)
			return
	_failed = true
	_swap_pick = ""
	_render()


func _close(result: Dictionary = {}) -> void:
	if _closed:
		return
	_closed = true
	if _row != null:
		CardAnchors.unregister(&"a.stock.offers", _row)
	close_requested.emit(result)


# ---------------- reading ----------------

func _ask() -> Dictionary:
	if engine == null:
		return {}
	var args := {"offer": _offer} if _offer != "" else {}
	var q = engine.query(KIND, args)
	return q if typeof(q) == TYPE_DICTIONARY else {}


## The notice board as it stands (entries {key, args}, or bare keys from Mock fixtures).
func _news() -> Array:
	if engine == null:
		return []
	return Ui.array(Ui.dict(engine.view().get("notice", {})).get("news", []))


func _is_open(q: Dictionary) -> bool:
	if not bool(q.get("ok", false)) or str(q.get("status", "")) != "open":
		return false
	return not Ui.array(q.get("items", [])).is_empty()


func _items() -> Array:
	var out: Array = []
	for row in Ui.array(_q.get("items", [])):
		if typeof(row) == TYPE_DICTIONARY and str(row.get("id", "")) != "":
			out.append(row)
	return out


func _has_item(id: String) -> bool:
	for row in _items():
		if str(row.get("id", "")) == id:
			return true
	return false
