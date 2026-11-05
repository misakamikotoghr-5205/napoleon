# Fortune stall: pay, draw a lot, or pick a character. No forecast of which card arrives.
# Owner C07. Frozen CardPanel: open / refresh / autoplay_step. Kind "fortune".
# Lot and cezi views are preloaded and have no class_name.
# TODO(shared#unfiled): fast_anim has no frozen reader. C16 is expected to add CardSettings.fast_anim().
# TODO(content): prop.fortune.tube / prop.fortune.slip / prop.fortune.char are missing; views paint paper.
# Reskin 10-22: the stall is a dark .modal (pixel frame, brush-gold title, light text, wood buttons),
# centred on the screen. A stall only shows the actions it offers: a temple lot stall has no
# character reading, so that button is hidden instead of sitting there disabled with no reason (b48).
class_name CardFortunePanel
extends CardPanel

const LotView = preload("res://scripts/cards/ui/fortune/lot_view.gd")
const CeziView = preload("res://scripts/cards/ui/fortune/cezi_view.gd")
const Style = preload("res://scripts/cards/ui/fortune/fortune_style.gd")
const KIND := &"fortune"
const BOX_POS := Vector2(150, 50)   # old fixed spot; the box is now centred on the screen (_centred_pos)
const BOX_SIZE := Vector2(980, 600)

## When true, the tube does not tween; the result still arrives. Tests and the future settings switch.
var fast_anim: bool = false

var _uid := ""
var _q: Dictionary = {}
var _card: Dictionary = {}
var _phase := "menu"
var _built := false
var _lot_sent := false
var _fi := 0
var _foci: Array = []
var _shade: ColorRect
var _box: Panel
var _portrait: TextureRect
var _title: Label
var _cost_caption: Label
var _cost_amount: Label
var _err: Label
var _lot_btn: Button
var _cezi_btn: Button
var _pass_btn: Button
var _ok_btn: Button
var _lot_view
var _cezi_view


func bind(p_engine: CardEngineApi, p_bus: CardEventBus) -> void:
	super.bind(p_engine, p_bus)
	if bus != null and not bus.card_left.is_connected(_on_card_left):
		bus.card_left.connect(_on_card_left)
	if bus != null and not bus.view_changed.is_connected(_on_view):
		bus.view_changed.connect(_on_view)


func open(args: Dictionary) -> void:
	_uid = str(args.get("uid", ""))
	_lot_sent = false
	_phase = "menu"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	if not _built:
		_build()
		_built = true
	_load()
	_show_menu()
	if _has_last():
		var last: Dictionary = _q.get("last", {})
		_show_poem(str(last.get("lot", "")), int(last.get("grade", -1)))


func refresh(_view: Dictionary) -> void:
	if engine == null or not _built or _phase != "menu":
		return
	_load()
	_apply_query()
	_sync_offer()


func autoplay_step() -> bool:
	if not _built or _phase == "closed":
		return false
	if _phase == "shake":
		_lot_view.skip()
		return true
	if _phase == "lot" or _phase == "read" or _phase == "err":
		_close()
		return true
	if _phase == "cezi":
		_cezi_view.pick_at(0)
		return true
	if bool(_q.get("can_lot", false)):
		_start_lot()
		return true
	if bool(_q.get("can_cezi", false)):
		_open_cezi()
		if _cezi_view.buttons.is_empty():
			_pass()
		else:
			_cezi_view.pick_at(0)
		return true
	_pass()
	return true


func _exit_tree() -> void:
	if bus != null and bus.card_left.is_connected(_on_card_left):
		bus.card_left.disconnect(_on_card_left)
	if bus != null and bus.view_changed.is_connected(_on_view):
		bus.view_changed.disconnect(_on_view)


func _input(event: InputEvent) -> void:
	if _phase != "shake" or not (event is InputEventKey):
		return
	var key := event as InputEventKey
	if key.pressed and not key.echo and key.keycode == KEY_SPACE:
		_lot_view.skip()
		_mark_input()


func _unhandled_input(event: InputEvent) -> void:
	if _phase == "closed" or not (event is InputEventKey):
		return
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return
	if key.keycode == KEY_ESCAPE:
		_close()
		_mark_input()
	elif key.keycode == KEY_TAB:
		_cycle(key.shift_pressed)
		_mark_input()
	elif key.keycode == KEY_ENTER or key.keycode == KEY_KP_ENTER:
		_activate()
		_mark_input()


# --- build -----------------------------------------------------------------
func _build() -> void:
	_shade = ColorRect.new()
	# The modal host already dims the table (meta "shade"); ours only catches clicks there.
	_shade.color = Color.TRANSPARENT if has_meta("shade") else CardTheme.color(&"shade")
	_shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_shade)
	_box = Panel.new()
	_box.name = "Box"
	_box.position = _centred_pos()
	_box.size = BOX_SIZE
	_box.custom_minimum_size = BOX_SIZE
	_box.add_theme_stylebox_override("panel", CardTheme.modal_style())
	_box.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_box)
	var frame := Panel.new()
	frame.position = Vector2(34, 34)
	frame.size = Vector2(176, 236)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_theme_stylebox_override("panel", CardTheme.paper_card_style())
	_box.add_child(frame)
	_portrait = TextureRect.new()
	_portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait.position = Vector2(34, 34)
	_portrait.size = Vector2(176, 236)
	_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_child(_portrait)
	_title = Style.label("", 28, true)
	_title.position = Vector2(232, 28)
	_title.size = Vector2(714, 48)
	_box.add_child(_title)
	_cost_caption = Style.label("", 16, true)
	_cost_caption.position = Vector2(232, 78)
	_cost_caption.size = Vector2(560, 32)
	_cost_caption.set_meta("c07_cost", true)
	_box.add_child(_cost_caption)
	_cost_amount = Style.label("", 16, false)
	_cost_amount.position = Vector2(800, 78)
	_cost_amount.size = Vector2(80, 32)
	_cost_amount.set_meta("c07_cost", true)
	_box.add_child(_cost_amount)
	_err = Style.label("", 16, true)
	_err.position = Vector2(232, 176)
	_err.size = Vector2(714, 48)
	_err.visible = false
	_box.add_child(_err)
	_lot_btn = _action_button("c07.btn.lot", Vector2(232, 120), Vector2(180, 44))
	_lot_btn.theme_type_variation = &"PrimaryButton"
	_cezi_btn = _action_button("c07.btn.cezi", Vector2(424, 120), Vector2(180, 44))
	_pass_btn = _action_button("c07.btn.pass", Vector2(616, 120), Vector2(160, 44))
	_ok_btn = _action_button("c07.btn.ok", Vector2(BOX_SIZE.x - 34.0 - 140.0, BOX_SIZE.y - 34.0 - 44.0), Vector2(140, 44))
	_ok_btn.theme_type_variation = &"PrimaryButton"
	_ok_btn.visible = false
	_lot_btn.pressed.connect(_start_lot)
	_cezi_btn.pressed.connect(_open_cezi)
	_pass_btn.pressed.connect(_pass)
	_ok_btn.pressed.connect(_close)
	CardAnchors.register(&"a.fortune.lot", _lot_btn)
	CardAnchors.register(&"a.fortune.cezi", _cezi_btn)
	_lot_view = LotView.new()
	_lot_view.position = Vector2(232, 232)
	_lot_view.visible = false
	_box.add_child(_lot_view)
	_cezi_view = CeziView.new()
	_cezi_view.position = Vector2(232, 232)
	_cezi_view.visible = false
	_cezi_view.picked.connect(_on_picked)
	_box.add_child(_cezi_view)
	CardAnchors.register(&"a.fortune.chars", _cezi_view)


## Centre the stall on the screen; the host pins overlays at (90, 40).
func _centred_pos() -> Vector2:
	var origin := get_global_transform_with_canvas().origin if is_inside_tree() else position
	return ((Vector2(1280, 720) - BOX_SIZE) * 0.5).round() - origin


## Menu buttons: only what this stall offers is shown, left to right; "pass" always (b48).
func _sync_offer() -> void:
	if _lot_btn == null:
		return
	var x := 232.0
	for pair in [[_lot_btn, bool(_q.get("can_lot", false))], [_cezi_btn, bool(_q.get("can_cezi", false))],
			[_pass_btn, true]]:
		var b: Button = pair[0]
		b.visible = bool(pair[1])
		b.disabled = not bool(pair[1])
		if b.visible:
			b.position.x = x
			x += b.size.x + 12.0


func _action_button(key: String, pos: Vector2, sz: Vector2) -> Button:
	var b := Style.button(CardText.ui(key))
	b.position = pos
	b.size = sz
	b.custom_minimum_size = sz
	_box.add_child(b)
	return b


# --- query / phases --------------------------------------------------------
func _load() -> void:
	_q = {"cost": 0, "can_lot": false, "can_cezi": false, "cezi": [], "last": {}}
	_card = {}
	if engine == null or _uid == "":
		return
	var q: Dictionary = engine.query(&"fortune", {"uid": _uid})
	if q.has("can_lot") or q.has("can_cezi") or q.has("cost") or q.has("cezi") or q.has("last"):
		_q = q
	var c: Dictionary = engine.query(&"card", {"uid": _uid})
	if c.has("def") or c.has("art"):
		_card = c


func _show_menu() -> void:
	_phase = "menu"
	_lot_view.visible = false
	_cezi_view.visible = false
	_ok_btn.visible = false
	_err.visible = false
	Style.set_label(_err, "", 16, true)
	_apply_query()
	_sync_offer()
	_pass_btn.disabled = false
	_rebuild_focus()


func _apply_query() -> void:
	_apply_title()
	_apply_portrait()
	_apply_cost()
	if _lot_btn != null:
		_lot_btn.text = CardText.ui("c07.btn.lot")
		_lot_btn.tooltip_text = _lot_btn.text
		_cezi_btn.text = CardText.ui("c07.btn.cezi")
		_cezi_btn.tooltip_text = _cezi_btn.text
		_pass_btn.text = CardText.ui("c07.btn.pass")
		_pass_btn.tooltip_text = _pass_btn.text
		_ok_btn.text = CardText.ui("c07.btn.ok")
		_ok_btn.tooltip_text = _ok_btn.text


func _apply_title() -> void:
	var def := str(_card.get("def", ""))
	if def == "":
		Style.set_label(_title, "", 28, true)
		_title.visible = false
		return
	_title.visible = true
	Style.set_label(_title, CardText.card(def, "title"), 28, CardText.is_draft(def + "#title"))


func _apply_portrait() -> void:
	var id := "portrait.suanming"
	var def := str(_card.get("def", ""))
	var art := str(_card.get("art", ""))
	var person := str(_card.get("person", ""))
	if def != "" and person != "suanming" and not def.contains("fortune_teller") and art != "":
		id = art
	_portrait.texture = CardArt.texture(id)
	_portrait.set_meta("art_id", id)


func _apply_cost() -> void:
	var n := int(_q.get("cost", 0))
	var caption := CardText.ui("c07.cost", {"n": n})
	Style.set_label(_cost_caption, caption, 16, CardText.is_draft("c07.cost"))
	_cost_caption.set_meta("c07_cost", true)
	var amount := str(n)
	_cost_amount.visible = not caption.contains(amount)
	Style.set_label(_cost_amount, amount, 16, false)
	_cost_amount.set_meta("c07_cost", true)


func _has_last() -> bool:
	var last = _q.get("last", {})
	return typeof(last) == TYPE_DICTIONARY and str(last.get("lot", "")) != ""


func _start_lot() -> void:
	if _phase == "shake" or _phase == "closed" or _phase == "lot":
		return
	_phase = "shake"
	_lot_sent = false
	_lot_view.visible = true
	_cezi_view.visible = false
	_ok_btn.visible = false
	_lock_actions()
	if fast_anim:
		_finish_lot()
		return
	_lot_view.play(_finish_lot)


func _finish_lot() -> void:
	if _lot_sent or _phase != "shake":
		return
	_lot_sent = true
	var r := {}
	if engine != null:
		r = engine.send(&"fortune.lot", {"uid": _uid})
	if not bool(r.get("ok", false)):
		_show_err(r)
		return
	_show_poem(str(r.get("lot", "")), int(r.get("grade", -1)))


func _show_poem(lot: String, grade: int) -> void:
	_phase = "lot"
	_lot_view.visible = true
	_lot_view.show_poem(lot, grade)
	_cezi_view.visible = false
	_err.visible = false
	_ok_btn.visible = true
	_lock_actions()
	_rebuild_focus()


func _open_cezi() -> void:
	if _phase == "closed":
		return
	_phase = "cezi"
	_lot_view.visible = false
	_cezi_view.visible = true
	_cezi_view.show_offer(_q.get("cezi", []))
	_ok_btn.visible = false
	_err.visible = false
	_lot_btn.disabled = true
	_cezi_btn.disabled = true
	_rebuild_focus()


func _on_picked(char_id: String) -> void:
	if engine == null or _phase == "closed":
		return
	var r: Dictionary = engine.send(&"fortune.cezi", {"uid": _uid, "char": char_id})
	if not bool(r.get("ok", false)):
		_show_err(r)
		return
	var cid := str(r.get("char", char_id))
	var reading := str(r.get("reading", ""))
	_phase = "read"
	_cezi_view.show_reading(cid, reading)
	_ok_btn.visible = true
	_lock_actions()
	_rebuild_focus()


func _show_err(r: Dictionary) -> void:
	_phase = "err"
	var key := str(r.get("reason_key", ""))
	if key == "" and str(r.get("err", "")) == CardIds.ERR_INSUFFICIENT_MONEY:
		key = "c07.err.money"
	var text := CardText.ui(key) if key != "" else ""
	Style.set_label(_err, text, 16, key == "" or CardText.is_draft(key))
	_err.visible = text != ""
	_lot_view.visible = false
	_ok_btn.visible = true
	_lock_actions()
	_rebuild_focus()


func _pass() -> void:
	if _phase == "closed":
		return
	if engine != null:
		engine.send(&"card.choose", {"uid": _uid, "choice": "pass"})
	_close()


func _close() -> void:
	if _phase == "closed":
		return
	_phase = "closed"
	if _lot_view != null:
		_lot_view.halt()
	close_requested.emit({})


func _lock_actions() -> void:
	_lot_btn.disabled = true
	_cezi_btn.disabled = true
	_pass_btn.disabled = true


func _on_card_left(uid: String, reason: StringName) -> void:
	if uid != _uid or _uid == "" or _phase == "closed":
		return
	# A successful draw resolves the card. The reading stays until the player presses OK.
	if reason == &"resolved":
		return
	_close()


func _on_view(_topics: PackedStringArray) -> void:
	if engine == null or _phase != "menu":
		return
	refresh.call_deferred(engine.view())


# --- keyboard --------------------------------------------------------------
func _rebuild_focus() -> void:
	_foci = []
	for b in [_lot_btn, _cezi_btn, _pass_btn]:
		if b.visible and not b.disabled:
			_foci.append(b)
	if _cezi_view.visible:
		for b in _cezi_view.buttons:
			if is_instance_valid(b) and (b as Button).visible and not (b as Button).disabled:
				_foci.append(b)
	if _ok_btn.visible and not _ok_btn.disabled:
		_foci.append(_ok_btn)
	_fi = 0
	if not _foci.is_empty() and is_inside_tree():
		(_foci[0] as Button).grab_focus()


func _cycle(back: bool) -> void:
	if _foci.is_empty():
		_rebuild_focus()
	if _foci.is_empty():
		return
	var step := -1 if back else 1
	_fi = (_fi + step) % _foci.size()
	if _fi < 0:
		_fi += _foci.size()
	var b: Button = _foci[_fi]
	if is_inside_tree() and is_instance_valid(b):
		b.grab_focus()


func _activate() -> void:
	if _fi < 0 or _fi >= _foci.size():
		return
	var b: Button = _foci[_fi]
	if is_instance_valid(b) and not b.disabled:
		b.pressed.emit()


func _mark_input() -> void:
	var vp := get_viewport()
	if vp != null:
		vp.set_input_as_handled()
