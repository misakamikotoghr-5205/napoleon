# Month-open interlude: stage background, intro paragraphs, then this stage's goals.
# Closing the panel is C01's cue to open the month wheel the engine already requested.
# Owner C09. Contract: docs/cards/CARDS_INTERFACES.md section 3.3 C09, 4.7.22, 7.8, 7.11.
# Full-screen overlay. Esc / dismiss() closes at any paragraph and sends no command.
# Anchor a.month.goals only while the goal block is on screen.
# Text from CardText. Colors from CardTheme. No Chinese literals.
class_name CardMonthOpen
extends CardPanel

const MonthUi = preload("res://scripts/cards/ui/month/month_ui.gd")
const KIND := &"month_open"

var _args: Dictionary = {}
var _view: Dictionary = {}
var _intro_n: int = 0
var _page: int = 0
var _closed: bool = false
var _built: bool = false
var _paras: Control
var _goals: Control
var _begin_btn: Button
var _tween: Tween


func bind(p_engine: CardEngineApi, p_bus: CardEventBus) -> void:
	super.bind(p_engine, p_bus)


func open(args: Dictionary) -> void:
	_args = args.duplicate(true)
	_view = engine.view().duplicate(true) if engine != null else {}
	_closed = false
	_page = 0
	_build()
	_built = true
	MonthUi.take_focus(self)


func refresh(view: Dictionary) -> void:
	_view = view.duplicate(true)
	if not _built or _closed or _goals == null:
		return
	_fill_goals()
	_apply_page()


## Esc and the host both land here. Close only; the phase stays put (section 7.8).
func dismiss() -> void:
	if _closed or not _built:
		return
	_closed = true
	_drop_anchor()
	close_requested.emit({})


func autoplay_step() -> bool:
	if _closed or not _built:
		return false
	_advance()
	return true


func _gui_input(event: InputEvent) -> void:
	# Mouse players: a left click turns the intro page (keys only before, so mouse-only play stuck on page one). On the goals page a click begins, like the Begin button.
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			_advance()
			accept_event()
		return
	if not (event is InputEventKey):
		return
	var ke := event as InputEventKey
	if not ke.pressed or ke.echo:
		return
	if ke.keycode == KEY_SPACE or ke.keycode == KEY_ENTER or ke.keycode == KEY_KP_ENTER:
		_advance()
		accept_event()
	elif ke.keycode == KEY_ESCAPE:
		dismiss()
		accept_event()


# TODO(design): the view and month queries do not carry stage bg or intro_paras.
# Read only those two fields until a query exists. Do not read or show brief.
func _stage_bits(era: String) -> Dictionary:
	if era == "":
		return {"bg": "", "intro_paras": 0}
	var d = CardDB.read_json("res://data/cards/era/%s/stage.json" % era)
	if typeof(d) != TYPE_DICTIONARY:
		d = CardDB.read_json("res://data/cards/_examples/era/%s/stage.json" % era)
	if typeof(d) != TYPE_DICTIONARY:
		return {"bg": "", "intro_paras": 0}
	return {"bg": str(d.get("bg", "")), "intro_paras": maxi(int(d.get("intro_paras", 0)), 0)}


func _era() -> String:
	var date = _view.get("date", {})
	if typeof(date) != TYPE_DICTIONARY:
		return ""
	return str(date.get("era", ""))


func _build() -> void:
	MonthUi.clear(self)
	MonthUi.prepare(self)
	var bits := _stage_bits(_era())
	_intro_n = int(bits["intro_paras"])
	MonthUi.shade(self)
	_add_bg(str(bits["bg"]))
	# Reskin 10-22: the band is the prototype's dark dialog sheet (deep wood in the pixel frame).
	var band := PanelContainer.new()
	band.name = "Band"
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	MonthUi.place(band, Vector2(80, 390), Vector2(1120, 300))
	band.add_theme_stylebox_override("panel", CardTheme.modal_style())
	add_child(band)
	_paras = VBoxContainer.new()
	_paras.name = "Paras"
	_paras.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_paras.add_theme_constant_override("separation", 12)
	MonthUi.place(_paras, Vector2(116, 424), Vector2(1048, 240))
	add_child(_paras)
	var era := _era()
	for i in _intro_n:
		var ref := "stage.%s#intro.p%d" % [era, i + 1]
		var line := CardText.t(ref)
		if line.strip_edges() == "":
			continue  # Unwritten paragraph: skip the page (no blank page). With --show-drafts it is a draft line.
		var lab := MonthUi.label(line, 18, false, CardText.is_draft(ref))
		lab.name = "P%d" % [i + 1]
		_paras.add_child(lab)
	_intro_n = _paras.get_child_count()
	_goals = VBoxContainer.new()
	_goals.name = "Goals"
	# PASS, not STOP: a click on the goal list reaches _gui_input and begins, like the button (b30).
	_goals.mouse_filter = Control.MOUSE_FILTER_PASS
	_goals.add_theme_constant_override("separation", 8)
	_goals.visible = false
	MonthUi.place(_goals, Vector2(116, 420), Vector2(1048, 244))
	add_child(_goals)
	_begin_btn = MonthUi.button(CardText.ui("c09.btn.begin"), "Begin", true)
	_begin_btn.size_flags_horizontal = Control.SIZE_SHRINK_END
	_begin_btn.size_flags_vertical = Control.SIZE_SHRINK_END | Control.SIZE_EXPAND
	_begin_btn.pressed.connect(_begin)
	_goals.add_child(_begin_btn)
	# Small triangle at the bottom right of an intro page: "click for more". Not text, so not CardText.
	var more := Polygon2D.new()
	more.name = "More"
	more.polygon = PackedVector2Array([Vector2(1150, 652), Vector2(1170, 652), Vector2(1160, 666)])
	more.color = CardTheme.color(&"gold_hi")
	add_child(more)
	_fill_goals()
	_apply_page()


func _add_bg(art_id: String) -> void:
	var bg := TextureRect.new()
	bg.name = "Bg"
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.position = Vector2.ZERO
	bg.size = Vector2(1280, 720)
	if art_id != "":
		bg.texture = CardArt.texture(art_id)
		bg.set_meta("art_id", art_id)
		var base := CardArt.base_size(art_id)
		if base.x > 0 and base.y > 0:
			var sx := 1280 / base.x
			var sy := 720 / base.y
			var mul := sx if sx < sy else sy
			if mul < 1:
				mul = 1
			bg.size = Vector2(base.x * mul, base.y * mul)
			bg.position = (Vector2(1280, 720) - bg.size) / 2.0
			bg.set_meta("scale", mul)
	add_child(bg)


func _fill_goals() -> void:
	if _goals == null:
		return
	var drop: Array = []
	for c in _goals.get_children():
		if c != _begin_btn:
			drop.append(c)
	for c in drop:
		_goals.remove_child(c)
		c.free()
	var title_ref := "c09.goals.title"
	var head := MonthUi.label(CardText.ui(title_ref), MonthUi.TITLE_SIZE, true, CardText.is_draft(title_ref))
	head.name = "GoalsTitle"
	_goals.add_child(head)
	_goals.move_child(head, 0)
	var goals = _view.get("goals", [])
	if typeof(goals) != TYPE_ARRAY:
		return
	for g in goals:
		if typeof(g) != TYPE_DICTIONARY:
			continue
		var id := str(g.get("id", ""))
		if id == "":
			continue
		var row := HBoxContainer.new()
		row.set_meta("goal_id", id)
		row.set_meta("main", bool(g.get("main", false)))
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_theme_constant_override("separation", 10)
		var ref := id + "#title"
		var lab := MonthUi.label(CardText.t(ref), 18, false, CardText.is_draft(ref))
		lab.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		lab.autowrap_mode = TextServer.AUTOWRAP_OFF   # shrunk in a row, a wrapping label wraps per glyph
		row.add_child(lab)
		if bool(g.get("main", false)):
			row.add_child(MonthUi.chip(CardText.ui("c09.goals.main"), &"gold_deep", &"btn_primary_ink"))
		_goals.add_child(row)
	if _begin_btn != null:
		_goals.move_child(_begin_btn, _goals.get_child_count() - 1)


func _apply_page() -> void:
	var on_goals := _page >= _intro_n
	var more := get_node_or_null("More") as CanvasItem
	if more != null:
		more.visible = not on_goals
	if _paras != null:
		_paras.visible = not on_goals
		for i in _paras.get_child_count():
			var lab := _paras.get_child(i) as CanvasItem
			var on := (not on_goals) and i == _page
			lab.visible = on
			if on:
				_fade(lab)
	if _goals == null:
		return
	_goals.visible = on_goals
	if on_goals:
		CardAnchors.register(&"a.month.goals", _goals)
	else:
		_drop_anchor()
	# Turning a page sends no bus event: tell the guide its anchor came or went (gd.m.open lights now).
	if is_inside_tree():
		get_tree().call_group(&"card_guide", &"anchors_changed")


func _fade(lab: CanvasItem) -> void:
	if _tween != null and is_instance_valid(_tween):
		_tween.kill()
		_tween = null
	if CardSettings.fast_anim():
		lab.modulate = Color.WHITE
		return
	lab.modulate = Color(1, 1, 1, 0)
	if not is_inside_tree():
		if not ready.is_connected(_fade_pending):
			ready.connect(_fade_pending, CONNECT_ONE_SHOT)
		return
	_tween = create_tween()
	_tween.tween_property(lab, "modulate:a", 1.0, 0.35)


func _fade_pending() -> void:
	if _paras == null or _page < 0 or _page >= _paras.get_child_count() or _page >= _intro_n:
		return
	_fade(_paras.get_child(_page))


func _advance() -> void:
	if _closed:
		return
	if _page >= _intro_n:
		_begin()
		return
	_page += 1
	_apply_page()


func _drop_anchor() -> void:
	if _goals != null:
		CardAnchors.unregister(&"a.month.goals", _goals)


func _begin() -> void:
	if _closed or _page < _intro_n:
		return
	_closed = true
	_drop_anchor()
	close_requested.emit({})
