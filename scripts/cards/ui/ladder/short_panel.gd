# Not enough money: pay with goods, mortgage an estate, or accept the default.
# Owner C11. Args from open() (request_panel "short"), else query("short"). §7.4.5.
# Closing or Esc is "accept the default": short.resolve {by: default}. Anchor: a.short.options.
# TODO(design): guide teacher for money_short stays "" (contract §7.10.10 conflict c).
# Reskin 10-22 (b26): a dark modal panel 720 wide, centred and clamped to OVERLAY_MAX; "short by n" in brush gold;
# each way to pay is a gold heading over a wrapping row (HFlowContainer) of choices, so five estates no longer run
# off the right edge; "accept it" is a red warn button with its note beside it; 关上 is a small button bottom right.
class_name CardShortPanel
extends CardPanel

const Ui = preload("res://scripts/cards/ui/ladder/ladder_ui.gd")
const Kit = preload("res://scripts/cards/ui/slots/drawer_kit.gd")
const KIND := &"short"

var _args: Dictionary = {}
var _data: Dictionary = {}
var _source := ""
var _chrome := false
var _grab := true
var _closed := false
var _body: VBoxContainer
var _amount_words: Label
var _amount_n: Label
var _payee: Label
var _options: VBoxContainer
var _reason: Label
var _box: Control


func bind(p_engine: CardEngineApi, p_bus: CardEventBus) -> void:
	super.bind(p_engine, p_bus)
	if bus != null and not bus.view_changed.is_connected(_on_view_changed):
		bus.view_changed.connect(_on_view_changed)


func open(args: Dictionary) -> void:
	_args = args.duplicate(true)
	_closed = false
	_data = _payload(_args)
	_source = str(_data.get("source", ""))
	_ensure()
	_fill()


func refresh(_view: Dictionary) -> void:
	if not _chrome or _closed:
		return
	if not (_args.has("amount") or _args.has("options") or _args.has("goods") or _args.has("estates")):
		_data = _payload({})
		_source = str(_data.get("source", ""))
	_fill()


## Goods if that path is open and there is stock; else the first estate; else default.
func autoplay_step() -> bool:
	if _closed or engine == null:
		return false
	var options: Array = _data.get("options", [])
	var goods: Array = _data.get("goods", [])
	var estates := _offerable(_data.get("estates", []))
	if options.has("goods") and not goods.is_empty() and typeof(goods[0]) == TYPE_DICTIONARY:
		_resolve({"source": _source, "by": "goods", "item": str(goods[0].get("item", ""))})
	elif options.has("estate") and not estates.is_empty():
		_resolve({"source": _source, "by": "estate", "estate": str(estates[0].get("id", ""))})
	elif options.has("default"):
		_resolve({"source": _source, "by": "default"})
	else:
		return false
	return _closed


## Closing is the default path (contract §7.8). Sends short.resolve, then closes.
func dismiss() -> void:
	if _closed:
		return
	_resolve({"source": _source, "by": "default"})


func _unhandled_input(event: InputEvent) -> void:
	var act := Ui.handle_key(self, event, true)
	if act == "":
		return
	if act == "close":
		dismiss()
	var vp := get_viewport()
	if vp != null:
		vp.set_input_as_handled()


func _on_view_changed(_topics: PackedStringArray) -> void:
	call_deferred("_deferred_fill")


func _deferred_fill() -> void:
	if not is_inside_tree() or _closed or not _chrome:
		return
	refresh(engine.view() if engine != null else {})


func _ensure() -> void:
	if _chrome:
		return
	_chrome = true
	var chrome: Dictionary = Ui.mount(self, &"event")
	_body = chrome["body"]
	_box = chrome["box"]
	var head := Kit.row(10)
	head.name = "head"
	_body.add_child(head)
	_amount_words = Ui.line("", 30, true)
	_amount_words.name = "amount_words"
	_amount_words.clip_text = false
	head.add_child(_amount_words)
	_amount_n = Ui.number_label(0)
	_amount_n.name = "amount_n"
	_amount_n.add_theme_font_override("font", CardTheme.font_body_bold())
	_amount_n.add_theme_font_size_override("font_size", 28)
	_amount_n.add_theme_color_override("font_color", CardTheme.color(&"money_down"))
	_amount_n.custom_minimum_size = Vector2(0, 40)
	_amount_n.clip_text = false
	head.add_child(_amount_n)
	_payee = Kit.label("", 14, &"text_2", false, true)
	_payee.name = "payee"
	_body.add_child(_payee)
	_body.add_child(Kit.divider())
	_options = VBoxContainer.new()
	_options.name = "options"
	_options.add_theme_constant_override("separation", 8)
	_body.add_child(_options)
	CardAnchors.register(&"a.short.options", _options)
	_reason = Ui.line("", 15, false)
	_reason.name = "reason"
	_reason.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_reason.clip_text = false
	_body.add_child(_reason)
	var close := Kit.small_button(CardText.ui("c11.btn.close"))
	close.name = "close"
	close.size_flags_horizontal = Control.SIZE_SHRINK_END
	close.pressed.connect(dismiss)
	_body.add_child(close)


func _payload(args: Dictionary) -> Dictionary:
	if args.has("amount") or args.has("options") or args.has("goods") or args.has("estates"):
		return args
	if engine == null:
		return {}
	var q := engine.query(&"short", {})
	if q.has("amount") or q.has("options") or q.has("goods") or q.has("estates"):
		return q
	return {}


func _fill() -> void:
	if not _chrome:
		return
	_amount_words.text = CardText.ui("c11.short.amount")
	_amount_words.add_theme_color_override("font_color", CardTheme.color(
			&"text_2" if CardText.is_draft("c11.short.amount") else &"gold_hi"))
	_amount_n.text = str(int(_data.get("amount", 0)))
	var payee := str(_data.get("payee", ""))
	_payee.visible = payee != ""
	if payee != "":
		_payee.text = CardText.ui(payee)
		_payee.add_theme_color_override("font_color", CardTheme.color(
				&"text_3" if CardText.is_draft(payee) else &"text_2"))
	Ui.clear(_options)
	var options: Array = _data.get("options", [])
	if options.has("goods"):
		_options.add_child(_header("c11.short.goods", "hdr_goods"))
		_options.add_child(_goods_row(_data.get("goods", [])))
	if options.has("estate"):
		_options.add_child(_header("c11.short.estate", "hdr_estate"))
		_options.add_child(_estate_row(_offerable(_data.get("estates", []))))
	if options.has("default"):
		_options.add_child(_default_row())
	Ui.chain_focus(self, _grab)
	_grab = false
	Ui.fit_overlay.call_deferred(_box)


func _header(key: String, node_name: String) -> Label:
	var l := Kit.heading(CardText.ui(key))
	l.name = node_name
	if CardText.is_draft(key):
		l.add_theme_color_override("font_color", CardTheme.color(&"text_2"))
	return l


func _flow(node_name: String) -> HFlowContainer:
	var row := HFlowContainer.new()
	row.name = node_name
	row.add_theme_constant_override("h_separation", 10)
	row.add_theme_constant_override("v_separation", 8)
	row.custom_minimum_size = Vector2(Ui.OVERLAY_W - 76.0, 0)
	return row


## One choice: a small picture and a wood button (wraps with its neighbours).
func _choice(art_id: String, k: int, fallback: Vector2i, b: Button) -> HBoxContainer:
	var box := Kit.row(6)
	var art := Ui.art_rect(art_id, k, fallback)
	art.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	box.add_child(art)
	b.custom_minimum_size = Vector2(112, 40)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	box.add_child(b)
	return box


func _goods_row(goods: Variant) -> HFlowContainer:
	var row := _flow("goods_row")
	if typeof(goods) != TYPE_ARRAY:
		return row
	for g in goods:
		if typeof(g) != TYPE_DICTIONARY:
			continue
		var template := str(g.get("template", ""))
		var ref := "item." + template + "#name"
		var b := Ui.button(CardText.item_text(template, "name"), CardText.is_draft(ref))
		b.name = "goods_" + str(g.get("item", ""))
		b.pressed.connect(_choose_goods.bind(str(g.get("item", ""))))
		row.add_child(_choice(str(g.get("art", "")), 1, Vector2i(32, 32), b))
	return row


func _estate_row(estates: Array) -> HFlowContainer:
	var row := _flow("estate_row")
	for e in estates:
		var id := str(e.get("id", ""))
		var b := Ui.button(CardText.card(id, "title"), CardText.is_draft(id + "#title"))
		b.name = "estate_" + id.replace(".", "_")
		b.pressed.connect(_choose_estate.bind(id))
		row.add_child(_choice("illus." + id, 1, Vector2i(64, 48), b))
	return row


func _default_row() -> HBoxContainer:
	var row := Kit.row(12)
	row.name = "default_row"
	var b := Ui.button(CardText.ui("c11.short.default"), CardText.is_draft("c11.short.default"))
	b.name = "default"
	b.theme_type_variation = &"WarnButton"
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(b)
	b.pressed.connect(_choose_default)
	var note := Kit.label(CardText.ui("c11.short.default_note"), 14,
		&"text_3" if CardText.is_draft("c11.short.default_note") else &"text_2", false, true)
	note.name = "default_note"
	note.custom_minimum_size = Vector2(420, 0)
	row.add_child(note)
	return row


func _offerable(rows: Variant) -> Array:
	var out: Array = []
	if typeof(rows) != TYPE_ARRAY:
		return out
	for e in rows:
		if typeof(e) != TYPE_DICTIONARY:
			continue
		var status := str(e.get("status", "held"))
		if status == "" or status == "held":
			out.append(e)
	return out


func _choose_goods(item_id: String) -> void:
	_resolve({"source": _source, "by": "goods", "item": item_id})


func _choose_estate(estate_id: String) -> void:
	_resolve({"source": _source, "by": "estate", "estate": estate_id})


func _choose_default() -> void:
	_resolve({"source": _source, "by": "default"})


func _resolve(args: Dictionary) -> void:
	if _closed or engine == null:
		return
	var r := engine.send(&"short.resolve", args)
	if not bool(r.get("ok", false)):
		Ui.show_reason(_reason, r)
		return
	_request_close()


func _request_close() -> void:
	if _closed:
		return
	_closed = true
	close_requested.emit({})
