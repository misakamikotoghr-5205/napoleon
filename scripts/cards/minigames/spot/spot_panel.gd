# Spot the difference: the board. Item well left, pattern book right, tools / ink / legend / the player's
# own calls in the middle, "done" (gold) with the host's abort spot beside it. It turns clicks into ops
# (op_asked) and shows the state it is given; it never marks a call right or wrong, never names a part,
# never counts what is left to find. Owner C12. Contract: CARDS_INTERFACES 8.2, 3.3 C12; DESIGN 4.3, 4.9.
# No class_name.
extends Control

const Chrome = preload("res://scripts/cards/minigames/mg_chrome.gd")
const Marks = preload("res://scripts/cards/minigames/spot/spot_marks.gd")
const WellScript = preload("res://scripts/cards/minigames/spot/spot_well.gd")

const BOARD := Vector2(1100, 600)
const VIEW := 384.0
const ITEM_AT := Vector2(34, 76)       # screen (124, 136)
const ATLAS_AT := Vector2(682, 76)     # screen (772, 136)
const MID_X := 434.0                   # screen 524
const MID_W := 232.0
const INK_Y := 176.0
const RULE_Y := 202.0                  # the standing rule line under the ink (screen y 262)
const LEGEND_Y := 226.0
const LEGEND_ROW := 104.0              # title 20, gap 2, tile 60, name 16, gap 6
const TILE_K := 5                      # legend tiles: the 12x12 swatch at x5 = 60 px
const LIST_RECT := Rect2(434, 436, 232, 96)
const DONE_RECT := Rect2(410, 540, 160, 44)   # screen (500, 600)
const ABORT_SPOT := Rect2(582, 540, 120, 44)  # screen (672, 600)
const BUBBLE_H := 36.0
const TAG_WEAR := 1
const TAG_DIFFERS := 2

signal op_asked(op: Array)

var _tools: Dictionary = {}
var _state: Dictionary = {}
var _pending := Vector2i(-1, -1)
var _selected := -1
var _blink_param := false
var _legend_rows := 0
var _key_px := Vector2i(32, 32)

var _item_well: Control
var _atlas_well: Control
var _eye_tex: Texture2D
var _lens_tex: Texture2D
var _book_tex: Texture2D
var _atlas_cover: Control
var _eye_btn: Button
var _lens_btn: Button
var _blink_btn: Button
var _ink_dots: Control
var _ink_max := 0
var _legend: Control
var _list: Control
var _bubble: Panel


func build(params: Dictionary, opts: Dictionary) -> void:
	_tools = {}
	for entry in (params.get("tools", []) if typeof(params.get("tools")) == TYPE_ARRAY else []):
		_tools[str(entry)] = true
	_blink_param = bool(opts.get("blink", false))
	_ink_max = int(opts.get("ink_max", 0))
	mouse_filter = Control.MOUSE_FILTER_STOP
	size = BOARD
	custom_minimum_size = BOARD
	gui_input.connect(_on_board_input)
	var frame := Panel.new()
	frame.name = "Frame"
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_theme_stylebox_override("panel", Chrome.frame())
	add_child(frame)
	add_child(Chrome.plate(Chrome.well(), ITEM_AT - Vector2(6, 6), Vector2(VIEW + 12, VIEW + 12)))
	add_child(Chrome.plate(Chrome.well(), ATLAS_AT - Vector2(6, 6), Vector2(VIEW + 12, VIEW + 12)))
	_add_titles()
	_add_pictures(params, int(opts.get("lens_px", 72)))
	_add_tools()
	_add_rule()
	_add_legend(params)
	_add_list()
	_add_done()
	_add_bubble()
	CardAnchors.register(&"a.mg.spot.main", self)
	CardAnchors.register(&"a.mg.spot.atlas", _atlas_well)
	if _lens_btn.visible:
		CardAnchors.register(&"a.mg.spot.lens", _lens_btn)
	if CardIds.is_known_anchor("a.mg.spot.tag"):
		CardAnchors.register(&"a.mg.spot.tag", _list)


## state: {pins, ink, tool, atlas_open, blink}
func show_state(st: Dictionary) -> void:
	_state = st.duplicate(true)
	var pins: Array = _state.get("pins", [])
	if _selected >= pins.size():
		_selected = -1
	var mode := str(_state.get("tool", "eye"))
	var book_open := bool(_state.get("atlas_open", false))
	var blink := bool(_state.get("blink", false))
	for w in [_item_well, _atlas_well]:
		w.pins = pins
		w.mode = mode
		w.pending = _pending
		w.selected = _selected
	_atlas_well.lens_on = book_open
	_item_well.set_pictures(_book_tex if blink else _eye_tex, _book_tex if blink else _lens_tex)
	_atlas_well.redraw()
	_atlas_cover.visible = not book_open
	_legend.visible = book_open and _legend_rows > 0
	_mark_active(_eye_btn, mode == "eye")
	_mark_active(_lens_btn, mode == "lens")
	_blink_btn.disabled = not book_open
	_ink_dots.queue_redraw()
	_fill_list(pins)


# ---------------- build ----------------
func _add_titles() -> void:
	add_child(Chrome.title(CardText.ui("c12.title"), CardText.is_draft("c12.title"), BOARD.x))
	for pair in [["c12.cap.item", ITEM_AT], ["c12.cap.atlas", ATLAS_AT]]:
		var cap := Chrome.note(CardText.ui(str(pair[0])), CardText.is_draft(str(pair[0])))
		cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cap.position = (pair[1] as Vector2) + Vector2(0, VIEW + 8)
		cap.size = Vector2(VIEW, 22)
		add_child(cap)


func _add_pictures(params: Dictionary, lens_px: int) -> void:
	var marks: Array = params.get("marks", []) if typeof(params.get("marks")) == TYPE_ARRAY else []
	var parts: Array = params.get("parts", []) if typeof(params.get("parts")) == TYPE_ARRAY else []
	var layout_seed := int(params.get("seed", 0))
	var base := Marks.base_image(str(params.get("art", "")))
	var eye := base.duplicate() as Image
	Marks.paint(eye, marks, parts, false, layout_seed)
	var lens := base.duplicate() as Image
	Marks.paint(lens, marks, parts, true, layout_seed)
	_eye_tex = Marks.texture(eye)
	_lens_tex = Marks.texture(lens)
	var book_art := str(params.get("atlas_art", ""))
	_book_tex = Marks.texture(Marks.base_image(book_art if book_art != "" else str(params.get("art", ""))))
	_item_well = _make_well("Item", ITEM_AT, _eye_tex, _lens_tex, true, lens_px)
	_item_well.clicked.connect(_on_item_click)
	_atlas_well = _make_well("Atlas", ATLAS_AT, _book_tex, _book_tex, false, lens_px)
	_atlas_well.clicked.connect(func(_px: Vector2i, _b: int) -> void: _close_bubble())
	_add_cover()


func _make_well(node_name: String, at: Vector2, pic: Texture2D, lens: Texture2D, item: bool, lens_px: int) -> Control:
	var w: Control = WellScript.new()
	w.name = node_name
	w.position = at
	w.show_pins = item
	w.lens_px = float(lens_px)
	w.short_wear = CardText.ui("c12.tag.short.wear")
	w.short_differs = CardText.ui("c12.tag.short.differs")
	add_child(w)
	w.setup(pic, lens)
	w.hovered.connect(_on_hover)
	return w


func _add_cover() -> void:
	_atlas_cover = Control.new()
	_atlas_cover.name = "AtlasCover"
	_atlas_cover.position = ATLAS_AT
	_atlas_cover.size = Vector2(VIEW, VIEW)
	_atlas_cover.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_atlas_cover)
	var paper := ColorRect.new()
	paper.color = CardTheme.color(&"paper_old")
	paper.set_anchors_preset(Control.PRESET_FULL_RECT)
	paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_atlas_cover.add_child(paper)
	if _tools.has("atlas"):
		var open := Chrome.button(CardText.ui("c12.btn.atlas_open"))
		open.name = "AtlasOpen"
		open.position = Vector2(100, 170)
		open.size = Vector2(184, 44)
		open.pressed.connect(func() -> void: _ask(["atlas"]))
		_atlas_cover.add_child(open)
	else:
		var none := Chrome.label(CardText.ui("c12.atlas.none"), 16, CardText.is_draft("c12.atlas.none"))
		none.add_theme_color_override("font_color", Chrome.paper_ink(CardText.is_draft("c12.atlas.none")))
		none.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		none.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		none.position = Vector2(40, 170)
		none.size = Vector2(VIEW - 80, 44)
		_atlas_cover.add_child(none)


func _add_tools() -> void:
	_eye_btn = _tool_button("EyeButton", "c12.tool.eye", Rect2(MID_X, ITEM_AT.y, 112, 40))
	_eye_btn.visible = _tools.has("eye")
	_eye_btn.pressed.connect(func() -> void: _ask(["tool", "eye"]))
	_lens_btn = _tool_button("LensButton", "c12.tool.lens", Rect2(MID_X + 120, ITEM_AT.y, 112, 40))
	_lens_btn.visible = _tools.has("lens")
	_lens_btn.pressed.connect(func() -> void: _ask(["tool", "lens"]))
	_blink_btn = _tool_button("BlinkButton", "c12.tool.blink", Rect2(MID_X, ITEM_AT.y + 48, MID_W, 40))
	_blink_btn.visible = _blink_param
	_blink_btn.button_down.connect(func() -> void: _ask(["blink", 1]))
	_blink_btn.button_up.connect(func() -> void: _release_blink())
	var ink := Chrome.note(CardText.ui("c12.ink"), CardText.is_draft("c12.ink"))
	ink.name = "InkLabel"
	ink.position = Vector2(MID_X, INK_Y)
	ink.size = Vector2(84, 24)
	ink.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(ink)
	_ink_dots = Control.new()
	_ink_dots.name = "Ink"
	_ink_dots.position = Vector2(MID_X + 84, INK_Y)
	_ink_dots.size = Vector2(MID_W - 84, 24)
	_ink_dots.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ink_dots.draw.connect(_draw_ink)
	add_child(_ink_dots)


func _tool_button(node_name: String, key: String, r: Rect2) -> Button:
	var btn := Chrome.button(CardText.ui(key))
	btn.name = node_name
	btn.position = r.position
	btn.size = r.size
	btn.custom_minimum_size = r.size
	add_child(btn)
	return btn


## The active tool keeps the pressed look with a gold edge (the player's choice, not a verdict).
func _mark_active(btn: Button, on: bool) -> void:
	if on:
		var small := btn.theme_type_variation == &"SmallButton"
		var sb := CardTheme.button_style(&"btn_hover_top", &"btn_top", &"gold_hi", 10.0 if small else 14.0,
			4.0 if small else 8.0, 5 if small else 6)
		sb.shadow_size = 0
		btn.add_theme_stylebox_override("normal", sb)
		btn.add_theme_stylebox_override("hover", sb)
		btn.add_theme_color_override("font_color", CardTheme.color(&"gold_hi"))
	else:
		btn.remove_theme_stylebox_override("normal")
		btn.remove_theme_stylebox_override("hover")
		btn.remove_theme_color_override("font_color")


func _draw_ink() -> void:
	var left := int(_state.get("ink", 0))
	var n := maxi(_ink_max, left)
	var step := minf(20.0, (_ink_dots.size.x - 8.0) / maxf(1.0, float(n)))
	for i in n:
		var c := Vector2(8.0 + step * float(i), 12.0)
		if i < left:
			_ink_dots.draw_circle(c, 6.0, CardTheme.color(&"gold_hi"))
		else:
			_ink_dots.draw_arc(c, 5.5, 0.0, TAU, 20, CardTheme.color(&"text_3"), 1.5, true)


## The standing rule under the ink (a rule of the game, not an answer): the fine spots show only through
## the lens. Always there, book open or shut.
func _add_rule() -> void:
	var rule := Chrome.note(CardText.ui("c12.rule.lens"), CardText.is_draft("c12.rule.lens"))
	rule.name = "Rule"
	rule.position = Vector2(MID_X, RULE_Y)
	rule.size = Vector2(MID_W, 20)
	rule.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	rule.autowrap_mode = TextServer.AUTOWRAP_OFF
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rule)


## Legend (DESIGN 4.3, decisions 2): what old wear and tampering look like, each look drawn by the same
## painter as the item's marks on a swatch of the book's own body, with its name under it; the row titles
## say what tells the two rows apart. Shown once the book is open. Same for every item of the kind.
func _add_legend(params: Dictionary) -> void:
	_legend = Control.new()
	_legend.name = "Legend"
	_legend.position = Vector2(MID_X, LEGEND_Y)
	_legend.size = Vector2(MID_W, LEGEND_ROW * 2.0)
	_legend.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_legend.visible = false
	add_child(_legend)
	var rows: Array = [["wear", "c12.legend.wear"], ["differs", "c12.legend.differs"]]
	var looks_by_row: Array = []
	var most := 0
	for row in rows:
		var looks := Marks.legend_looks(params.get("legend", {}), str(row[0]))
		looks_by_row.append(looks)
		most = maxi(most, looks.size())
	if most == 0:
		return
	var book_art := str(params.get("atlas_art", ""))
	var sw := Marks.swatch(Marks.base_image(book_art if book_art != "" else str(params.get("art", ""))))
	# Every look the params name gets its tile (a row of four or more takes smaller tiles, never fewer).
	var per_row := maxi(3, most)
	var tile_px := float(Marks.TILE * clampi(int((MID_W - 8.0 * float(per_row - 1)) / float(Marks.TILE * per_row)), 2, TILE_K))
	var gap := (MID_W - tile_px * float(per_row)) / float(per_row - 1)
	var layout_seed := int(params.get("seed", 0))
	var index := 0
	for r in rows.size():
		var looks: Array = looks_by_row[r]
		if looks.is_empty():
			continue
		var y := float(_legend_rows) * LEGEND_ROW
		_legend_rows += 1
		var key := str(rows[r][1])
		var title := Chrome.note(CardText.ui(key), CardText.is_draft(key))
		title.name = "Title%d" % r
		title.position = Vector2(0, y)
		title.size = Vector2(MID_W, 20)
		_legend.add_child(title)
		for i in mini(looks.size(), per_row):
			var look := str(looks[i])
			index += 1
			var at := Vector2(float(i) * (tile_px + gap), y + 22.0)
			var img := Marks.legend_tile(sw, look, layout_seed, index)
			_legend.add_child(_tile(Marks.texture(img), at, tile_px, "Tile%d_%d" % [r, index]))
			var name_key := "c12.look." + look
			var cap := Chrome.note(CardText.ui(name_key), CardText.is_draft(name_key))
			cap.name = "Name%d_%d" % [r, index]
			cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			cap.position = at + Vector2(-6.0, tile_px + 1.0)
			cap.size = Vector2(tile_px + 12.0, 16)
			_legend.add_child(cap)


func _tile(tex: Texture2D, at: Vector2, px: float, node_name: String) -> Control:
	var holder := Panel.new()
	holder.name = node_name
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_theme_stylebox_override("panel", CardTheme.flat_style(&"paper", &"umber", 1, 2))
	holder.position = at
	holder.size = Vector2(px, px)
	var pic := TextureRect.new()
	pic.texture = tex
	pic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	pic.stretch_mode = TextureRect.STRETCH_SCALE
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pic.size = Vector2(px, px)
	holder.add_child(pic)
	return holder


func _add_list() -> void:
	_list = Control.new()
	_list.name = "PinList"
	_list.position = LIST_RECT.position
	_list.size = LIST_RECT.size
	_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_list)


## The player's calls so far: number + "old wear" / "not like the book". Click one to change it.
func _fill_list(pins: Array) -> void:
	for c in _list.get_children():
		_list.remove_child(c)
		c.queue_free()
	for i in pins.size():
		var col := i / 4
		var row := i % 4
		if col > 1:
			break
		var btn := Button.new()
		btn.name = "Pin%d" % (i + 1)
		btn.focus_mode = Control.FOCUS_NONE
		btn.flat = true
		btn.position = Vector2(float(col) * 118.0, float(row) * 24.0)
		btn.size = Vector2(114, 22)
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var n := i
		btn.pressed.connect(func() -> void: _open_pin(n))
		_list.add_child(btn)
		var num := Chrome.label(str(i + 1), 14, false)
		num.add_theme_color_override("font_color", CardTheme.color(&"gold_hi"))
		num.position = Vector2(4, 0)
		num.size = Vector2(18, 22)
		num.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		btn.add_child(num)
		var key := "c12.tag.wear" if int(pins[i][2]) == TAG_WEAR else "c12.tag.differs"
		var tag := Chrome.label(CardText.ui(key), 14, CardText.is_draft(key))
		tag.position = Vector2(24, 0)
		tag.size = Vector2(88, 22)
		tag.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		btn.add_child(tag)


func _add_done() -> void:
	var done := Chrome.button(CardText.ui("c12.btn.done"), true)
	done.name = "Done"
	done.position = DONE_RECT.position
	done.size = DONE_RECT.size
	done.custom_minimum_size = DONE_RECT.size
	done.pressed.connect(func() -> void: _ask(["done"]))
	add_child(done)


# ---------------- the call bubble ----------------
func _add_bubble() -> void:
	_bubble = Panel.new()
	_bubble.name = "Bubble"
	_bubble.mouse_filter = Control.MOUSE_FILTER_STOP
	_bubble.add_theme_stylebox_override("panel", CardTheme.flat_style(&"wood_0", &"gold_deep", 2, 6))
	_bubble.visible = false
	add_child(_bubble)
	for spec in [["TagWear", "c12.tag.wear"], ["TagDiffers", "c12.tag.differs"], ["TagRemove", "c12.tag.remove"],
			["TagCancel", "c12.tag.cancel"]]:
		var b := Chrome.button(CardText.ui(str(spec[1])))
		b.name = str(spec[0])
		b.theme_type_variation = &"SmallButton"
		_bubble.add_child(b)
	(_bubble.get_node("TagWear") as Button).pressed.connect(func() -> void: _choose(TAG_WEAR))
	(_bubble.get_node("TagDiffers") as Button).pressed.connect(func() -> void: _choose(TAG_DIFFERS))
	(_bubble.get_node("TagRemove") as Button).pressed.connect(_remove_chosen)
	(_bubble.get_node("TagCancel") as Button).pressed.connect(_close_bubble)


func _on_item_click(px: Vector2i, button: int) -> void:
	if button != MOUSE_BUTTON_LEFT:
		_close_bubble()
		return
	var hit := _pin_near(px)
	if hit >= 0:
		_open_pin(hit)
	elif int(_state.get("ink", 0)) > 0:
		_selected = -1
		_pending = px
		_place_bubble(px, false)
	else:
		_close_bubble()


## Pin under the click: the closest within one item pixel.
func _pin_near(px: Vector2i) -> int:
	var pins: Array = _state.get("pins", [])
	var best := -1
	var best_d := 99
	for i in pins.size():
		var d := maxi(absi(int(pins[i][0]) - px.x), absi(int(pins[i][1]) - px.y))
		if d <= 1 and d < best_d:
			best_d = d
			best = i
	return best


func _open_pin(n: int) -> void:
	var pins: Array = _state.get("pins", [])
	if n < 0 or n >= pins.size():
		return
	_pending = Vector2i(-1, -1)
	_selected = n
	_place_bubble(Vector2i(int(pins[n][0]), int(pins[n][1])), true)


func _place_bubble(px: Vector2i, existing: bool) -> void:
	var wear := _bubble.get_node("TagWear") as Button
	var differs := _bubble.get_node("TagDiffers") as Button
	var remove := _bubble.get_node("TagRemove") as Button
	var cancel := _bubble.get_node("TagCancel") as Button
	var widths: Array = [88.0, 88.0, 64.0, 36.0] if existing else [88.0, 88.0, 0.0, 36.0]
	var x := 4.0
	var row: Array = [wear, differs, remove, cancel]
	for i in row.size():
		var b: Button = row[i]
		b.visible = float(widths[i]) > 0.0
		if not b.visible:
			continue
		b.position = Vector2(x, 3)
		b.size = Vector2(float(widths[i]), BUBBLE_H - 6.0)
		x += float(widths[i]) + 4.0
	var w := x
	_bubble.size = Vector2(w, BUBBLE_H)
	var tag := -1
	if existing:
		tag = int((_state.get("pins", []) as Array)[_selected][2])
	_mark_active(wear, tag == TAG_WEAR)
	_mark_active(differs, tag == TAG_DIFFERS)
	# Above or below the pin, clear of its ring (or of the whole lens), inside the item well, so it never
	# hides the pin, the lens or the legend while the player decides.
	var c := ITEM_AT + WellScript.pixel_center(px)
	var gap := (float(_item_well.lens_px) if str(_state.get("tool", "eye")) == "lens" else WellScript.PIN_R) + 8.0
	var pos := Vector2(c.x - w / 2.0, c.y + gap)
	if pos.y + BUBBLE_H > ITEM_AT.y + VIEW:
		pos.y = c.y - gap - BUBBLE_H
	pos.x = clampf(pos.x, ITEM_AT.x + 2.0, ITEM_AT.x + VIEW - w - 2.0)
	pos.y = clampf(pos.y, ITEM_AT.y + 2.0, ITEM_AT.y + VIEW - BUBBLE_H - 2.0)
	_bubble.position = pos
	_bubble.visible = true
	move_child(_bubble, -1)
	_freeze(px)


## While the bubble is open the lens / hover stays on the pixel being called.
func _freeze(px: Vector2i) -> void:
	var at := Vector2(px) + Vector2(0.5, 0.5)
	for w in [_item_well, _atlas_well]:
		w.pending = _pending
		w.selected = _selected
		w.cursor = at
		w.cursor_on = false
		w.redraw()


func _close_bubble() -> void:
	_pending = Vector2i(-1, -1)
	_selected = -1
	if _bubble != null:
		_bubble.visible = false
	for w in [_item_well, _atlas_well]:
		if w == null:
			continue
		w.pending = _pending
		w.selected = _selected
		w.redraw()


func _choose(tag: int) -> void:
	if _pending.x >= 0:
		var p := _pending
		_close_bubble()
		_ask(["pin", p.x, p.y, tag])
	elif _selected >= 0:
		var n := _selected
		_close_bubble()
		var pins: Array = _state.get("pins", [])
		if n < pins.size() and int(pins[n][2]) != tag:
			_ask(["retag", n, tag])
	else:
		_close_bubble()


func _remove_chosen() -> void:
	var n := _selected
	_close_bubble()
	if n >= 0:
		_ask(["unpin", n])


func bubble_open() -> bool:
	return _bubble != null and _bubble.visible


# ---------------- input glue ----------------
func _ask(op: Array) -> void:
	if str(op[0]) != "blink":
		_close_bubble()
	op_asked.emit(op)


func _release_blink() -> void:
	if bool(_state.get("blink", false)):
		op_asked.emit(["blink", 0])


func _on_hover(img_pos: Vector2, inside: bool) -> void:
	if inside:
		_key_px = Vector2i(clampi(int(floor(img_pos.x)), 0, 63), clampi(int(floor(img_pos.y)), 0, 63))
	if _pending.x >= 0 or _selected >= 0:
		return
	for w in [_item_well, _atlas_well]:
		w.cursor = img_pos
		w.cursor_on = inside
		w.redraw()


# ---------------- keyboard (contract 8.2: playable by keyboard; the same ops as the mouse) ----------------
## Arrows: move the cursor pixel (the hover square / lens follows it).
func key_move(delta: Vector2i) -> void:
	_close_bubble()
	_key_px = Vector2i(clampi(_key_px.x + delta.x, 0, 63), clampi(_key_px.y + delta.y, 0, 63))
	_on_hover(Vector2(_key_px) + Vector2(0.5, 0.5), true)


## Enter / Space: open the call at the cursor (its pin's call when it sits on a pin); again closes it.
func key_enter() -> void:
	if bubble_open():
		_close_bubble()
		return
	_on_item_click(_key_px, MOUSE_BUTTON_LEFT)


## 1 / 2: call the open spot (or the pin under the cursor, or a new pin at the cursor) wear / differs.
func key_call(tag: int) -> void:
	if bubble_open():
		_choose(tag)
		return
	var hit := _pin_near(_key_px)
	if hit >= 0:
		var pins: Array = _state.get("pins", [])
		if int(pins[hit][2]) != tag:
			_ask(["retag", hit, tag])
	elif int(_state.get("ink", 0)) > 0:
		_ask(["pin", _key_px.x, _key_px.y, tag])


## 0 / Delete / Backspace: take the open pin away, or close a new call.
func key_remove() -> void:
	if _selected >= 0:
		_remove_chosen()
	else:
		_close_bubble()


func key_cursor() -> Vector2i:
	return _key_px


func _on_board_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		_close_bubble()
