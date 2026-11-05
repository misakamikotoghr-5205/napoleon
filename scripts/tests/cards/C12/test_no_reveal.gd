# The game reveals nothing by itself (DESIGN P5, 4.3, 13): what it hands back depends only on what the
# player did (the same clicks on the tampered and the clean twin give the same result); to the naked eye
# the twins look the same (the tampered spot is fine: lens only), and the book and legend are the same;
# the screen only shows CardText words and pin numbers, never an observation line, a part name, a look
# name or a "%"; right and wrong calls look the same on screen (same colours); only mg_tool events.
# Owner C12.
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const Lib = preload("res://scripts/tests/cards/C12/c12_lib.gd")
const Marks = preload("res://scripts/cards/minigames/spot/spot_marks.gd")

const NAMES: Array[String] = ["authenticity", "condition", "material", "provenance", "differs", "wear"]
const VERDICT_KEYS: Array[String] = ["&\"good\"", "&\"bad\"", "&\"danger\"", "&\"seal\"", "&\"money_up\"",
	"&\"money_down\"", "&\"wheel_good_a\"", "&\"wheel_bad_a\""]


func _initialize() -> void:
	var t := T.new(self, "C12_no_reveal")
	t.run_async(_body.bind(t))


func _body(t) -> void:
	var bus := CardEventBus.new()
	root.add_child(bus)
	var mock := MockCardEngine.new(bus)
	t.ok(mock.db != null, "text db")
	var spy = t.spy(bus)
	await t.frames(1)
	_twins_same_result(t)
	_twins_same_look(t)
	await _screen_words(t, bus, spy)
	await _same_colours(t)
	_source(t)
	bus.queue_free()
	CardAnchors.clear()
	await t.frames(3)


func _twins_same_result(t) -> void:
	var a: Dictionary = Lib.fixture("hairpin3")
	var b: Dictionary = Lib.fixture("hairpin3_clean")
	var scripts: Array = [
		[["atlas"], ["pin", 38, 24, 1], ["tool", "lens"], ["pin", 28, 35, 2], ["pin", 11, 51, 1], ["done"]],
		[["pin", 28, 35, 1], ["pin", 5, 5, 2], ["unpin", 1], ["done"]],
		[["atlas"], ["done"]],
	]
	for ops in scripts:
		t.eq(Lib.replay(self, a, ops), Lib.replay(self, b, ops), "same clicks, same result on both twins " + str(ops))
	var ra := {}
	var rb := {}
	var ga := Lib.open_game(self, a)
	ga.finished.connect(func(r: Dictionary) -> void: ra.merge(r))
	ga.apply_op(["atlas"])
	ga.apply_op(["pin", 28, 35, 2])
	ga.apply_op(["done"])
	ga.queue_free()
	t.eq(Lib.keys_of(ra.get("measures", {})), PackedStringArray(Lib.MEASURE_KEYS), "measures are the player's own")
	var gb := Lib.open_game(self, b)
	gb.finished.connect(func(r: Dictionary) -> void: rb.merge(r))
	gb.autoplay(1.0)
	gb.queue_free()
	t.eq(Lib.keys_of(rb.get("measures", {})), PackedStringArray(Lib.MEASURE_KEYS), "autoplay measures too")


func _twins_same_look(t) -> void:
	var a: Dictionary = Lib.fixture("hairpin3")
	var b: Dictionary = Lib.fixture("hairpin3_clean")
	var base := Marks.base_image(str(a["art"]))
	var eye_a := base.duplicate() as Image
	var eye_b := base.duplicate() as Image
	Marks.paint(eye_a, a["marks"], a["parts"], false, int(a["seed"]))
	Marks.paint(eye_b, b["marks"], b["parts"], false, int(b["seed"]))
	t.ok(eye_a.get_data() == eye_b.get_data(), "naked eye: tampered and clean twins look the same")
	var lens_a := base.duplicate() as Image
	var lens_b := base.duplicate() as Image
	Marks.paint(lens_a, a["marks"], a["parts"], true, int(a["seed"]))
	Marks.paint(lens_b, b["marks"], b["parts"], true, int(b["seed"]))
	t.ok(lens_a.get_data() != lens_b.get_data(), "lens: the fine spot is there to be seen")
	t.ok(lens_a.get_data() != base.get_data() and eye_a.get_data() != base.get_data(), "marks are drawn")
	var sw := Marks.swatch(base)
	for row in ["wear", "differs"]:
		for look in Marks.legend_looks(a["legend"], row):
			var ta := Marks.legend_tile(sw, look, int(a["seed"]), 1)
			var tb := Marks.legend_tile(sw, look, int(b["seed"]), 1)
			t.ok(ta.get_data() == tb.get_data(), "legend tile %s is the same for both twins" % look)
			t.ok(ta.get_data() != sw.get_data(), "legend tile %s shows its look" % look)


func _screen_words(t, bus: CardEventBus, spy) -> void:
	var cat: Dictionary = CardDB.read_json("res://data/cards/minigames/obs/spot.json").get("obs", {})
	var obs_text: Array = []
	for key in cat.keys():
		var s := CardText.obs(str(key))
		if s != "":
			obs_text.append(s)
	for name in Lib.fixture_names():
		spy.clear()
		var params: Dictionary = Lib.fixture(name)
		var game := Lib.open_game(self, params)
		game.bind_bus(bus)
		await t.frames(1)
		_words(t, game, obs_text, name + " start")
		game.apply_op(["atlas"])
		game.apply_op(["tool", "lens"])
		for pin in Lib.answer(params):
			game.apply_op(["pin", pin[0], pin[1], pin[2]])
		await t.frames(1)
		_words(t, game, obs_text, name + " pinned")
		var board := Lib.board(game)
		if not game.pins().is_empty():
			board._open_pin(0)
			await t.frames(1)
			_words(t, game, obs_text, name + " bubble")
		for ev in spy.ui_events():
			t.eq(str(ev[0]), "mg_tool", name + " only mg_tool")
		game.queue_free()
		CardAnchors.clear()
		await t.frames(1)


func _words(t, game: CardSpotGame, obs_text: Array, label: String) -> void:
	t.eq(t.all_text_from_cardtext(game), PackedStringArray(), label + ": every word from CardText")
	var digits := RegEx.create_from_string("^[0-9]+$")
	for n in _walk(game):
		var txt := ""
		if n is Label:
			txt = (n as Label).text
		elif n is Button:
			txt = (n as Button).text
		if txt == "":
			continue
		t.ok(not txt.contains("%"), label + ": no percent in " + txt)
		t.ok(not obs_text.has(txt), label + ": no observation line on screen: " + txt)
		for w in NAMES:
			t.ok(not txt.contains(w), label + ": no part or call name " + w)
		for look in Marks.KNOWN_LOOKS:
			t.ok(not txt.contains(look), label + ": no look name " + look)
		if digits.search(txt) != null:
			t.ok(int(txt) >= 1 and int(txt) <= 8, label + ": only pin numbers as digits, got " + txt)


## Right calls and wrong calls at the same pixels: the same colours everywhere on screen.
func _same_colours(t) -> void:
	var params: Dictionary = Lib.fixture("hairpin3")
	var right: Array = Lib.answer(params)
	var wrong: Array = []
	for pin in right:
		wrong.append([pin[0], pin[1], 1 if int(pin[2]) == 2 else 2])
	var prints: Array = []
	for pins in [right, wrong]:
		var game := Lib.open_game(self, params)
		game.apply_op(["atlas"])
		game.apply_op(["tool", "lens"])
		for pin in pins:
			game.apply_op(["pin", pin[0], pin[1], pin[2]])
		await t.frames(1)
		prints.append(_colours(game))
		game.queue_free()
		CardAnchors.clear()
		await t.frames(1)
	t.eq(prints[0], prints[1], "right and wrong calls are drawn in the same colours")


func _colours(root_node: Node) -> PackedStringArray:
	var seen: Dictionary = {}
	for n in _walk(root_node):
		if n is CanvasItem:
			seen["m" + (n as CanvasItem).modulate.to_html()] = true
			seen["s" + (n as CanvasItem).self_modulate.to_html()] = true
		if n is ColorRect:
			seen["c" + (n as ColorRect).color.to_html()] = true
		if n is Control:
			var c := n as Control
			for k in ["font_color", "font_hover_color", "font_pressed_color"]:
				if c.has_theme_color_override(k):
					seen["f" + c.get_theme_color(k).to_html()] = true
			for k in ["panel", "normal", "hover", "pressed"]:
				if c.has_theme_stylebox_override(k):
					var sb := c.get_theme_stylebox(k)
					if sb is StyleBoxFlat:
						seen["b" + (sb as StyleBoxFlat).bg_color.to_html() + (sb as StyleBoxFlat).border_color.to_html()] = true
	var out := PackedStringArray()
	for k in seen.keys():
		out.append(str(k))
	out.sort()
	return out


## No verdict colours anywhere in the spot code (P5: the player's pen is gold_hi, nothing is good / bad).
func _source(t) -> void:
	var dir := "res://scripts/cards/minigames/spot"
	for f in DirAccess.get_files_at(dir):
		if not str(f).ends_with(".gd"):
			continue
		var text := FileAccess.get_file_as_string(dir + "/" + str(f))
		for key in VERDICT_KEYS:
			t.ok(not text.contains(key), "%s does not use %s" % [f, key])


func _walk(n: Node) -> Array:
	var out: Array = [n]
	for c in n.get_children():
		out.append_array(_walk(c))
	return out
