# Run over: ending copy, retry this stage, resume from the suspend file, or return to the title.
# Owner C09. Contract: docs/cards/CARDS_INTERFACES.md section 3.3 C09, 7.8, 7.11.
# Overlay. Esc / dismiss() returns to the title and sends no command.
# Anchor a.over.retry on the stage-retry button while it is on screen.
# close_requested({"to_title": true}) is C01's title-return agreement.
class_name CardGameOver
extends CardPanel

const MonthUi = preload("res://scripts/cards/ui/month/month_ui.gd")
const KIND := &"game_over"
const BOX_SIZE := Vector2(760, 380)
const BG_ART := "bg.title"

var _args: Dictionary = {}
var _bus_reason: String = ""
var _closed: bool = false
var _built: bool = false
var _body: Label
var _retry_btn: Button
var _resume_btn: Button
var _title_btn: Button


func bind(p_engine: CardEngineApi, p_bus: CardEventBus) -> void:
	super.bind(p_engine, p_bus)
	if bus != null and not bus.game_over.is_connected(_on_game_over):
		bus.game_over.connect(_on_game_over)


func open(args: Dictionary) -> void:
	_args = args.duplicate(true)
	_closed = false
	_build()
	_built = true
	_apply_body()
	MonthUi.take_focus(self)


func refresh(_view: Dictionary) -> void:
	if not _built or _closed:
		return
	_apply_body()
	_sync_resume()


## Esc and the host both land here. Closing the run-over panel returns to the title (section 7.8).
func dismiss() -> void:
	if _closed or not _built:
		return
	_closed = true
	_drop_anchor()
	close_requested.emit({"to_title": true})


func autoplay_step() -> bool:
	if _closed or not _built:
		return false
	_retry()
	return true


func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var ke := event as InputEventKey
	if not ke.pressed or ke.echo:
		return
	if ke.keycode == KEY_SPACE or ke.keycode == KEY_ENTER or ke.keycode == KEY_KP_ENTER:
		_retry()
		accept_event()
	elif ke.keycode == KEY_ESCAPE:
		dismiss()
		accept_event()


# TODO(design): the view has no run-end reason. Prefer open(args).reason,
# else the reason remembered from bus game_over(reason).
func _on_game_over(reason: StringName) -> void:
	_bus_reason = str(reason)
	if _built and str(_args.get("reason", "")) == "":
		_apply_body()


func _reason() -> String:
	var r := str(_args.get("reason", ""))
	if r == "":
		r = _bus_reason
	if r == "" and engine != null:
		r = str(engine.view().get("game_over_reason", ""))
	return r


func _build() -> void:
	MonthUi.clear(self)
	MonthUi.prepare(self)
	_add_bg()
	MonthUi.shade(self)
	# Reskin 10-22: prototype end screen, a dark .modal with a brush-gold title, the ending paragraph and
	# one row of buttons (the first one gold).
	var box := MonthUi.modal(self, MonthUi.centred(BOX_SIZE))
	var col := VBoxContainer.new()
	col.name = "Column"
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", 14)
	box.add_child(col)
	var title_ref := "c09.over.title"
	var title := MonthUi.label(CardText.ui(title_ref), MonthUi.TITLE_SIZE, true, CardText.is_draft(title_ref))
	title.name = "Heading"
	col.add_child(title)
	_body = MonthUi.label("", 18, false, false)
	_body.name = "Ending"
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(_body)
	var row := HBoxContainer.new()
	row.name = "Buttons"
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 12)
	col.add_child(row)
	_retry_btn = MonthUi.button(CardText.ui("c09.btn.retry"), "Retry", true)
	_retry_btn.pressed.connect(_retry)
	row.add_child(_retry_btn)
	CardAnchors.register(&"a.over.retry", _retry_btn)
	_resume_btn = MonthUi.button(CardText.ui("c09.btn.resume"), "Resume")
	_resume_btn.pressed.connect(_resume)
	row.add_child(_resume_btn)
	_sync_resume()
	_title_btn = MonthUi.button(CardText.ui("c09.btn.title"), "Title")
	_title_btn.pressed.connect(dismiss)
	row.add_child(_title_btn)


## Prototype: the run-end screen sits on the title picture (bg.title, x4), dimmed; skipped without the art.
func _add_bg() -> void:
	if CardArt.is_missing(BG_ART):
		return
	var base := CardArt.base_size(BG_ART)
	if base.x <= 0 or base.y <= 0:
		return
	var k := maxi(mini(1280 / base.x, 720 / base.y), 1)
	var bg := TextureRect.new()
	bg.name = "Bg"
	bg.texture = CardArt.texture(BG_ART)
	bg.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	MonthUi.place(bg, ((MonthUi.VIEW - Vector2(base * k)) / 2.0).round(), Vector2(base * k))
	add_child(bg)
	var dim := ColorRect.new()
	dim.name = "BgDim"
	dim.color = CardTheme.color(&"shade")
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	MonthUi.place(dim, Vector2.ZERO, MonthUi.VIEW)
	add_child(dim)


func _apply_body() -> void:
	if _body == null:
		return
	var reason := _reason()
	if reason == "":
		_body.text = ""
		return
	var ref := "g02.ending." + reason
	_body.text = CardText.t(ref)
	_body.add_theme_color_override("font_color", CardTheme.color(MonthUi.ink(false, CardText.is_draft(ref), false)))


func _sync_resume() -> void:
	if _resume_btn == null:
		return
	_resume_btn.disabled = not CardSave.exists(CardSave.suspend_path())


func _drop_anchor() -> void:
	if _retry_btn != null:
		CardAnchors.unregister(&"a.over.retry", _retry_btn)


func _retry() -> void:
	if _closed:
		return
	_closed = true
	_drop_anchor()
	if engine != null:
		engine.send(&"game.retry_stage", {})
	close_requested.emit({})


func _resume() -> void:
	if _closed or _resume_btn == null or _resume_btn.disabled:
		return
	_closed = true
	_drop_anchor()
	if engine != null:
		engine.send(&"game.load", {})
	close_requested.emit({})
