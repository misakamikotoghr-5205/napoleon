# C14 (DESIGN P5, 13 test_no_reveal): from open to hand-back the screen never shows an observation's text, the
# reading, the hidden fen or a percent sign; the only numbers are weight faces, the claim and star numbers.
# A right call and a wrong call on the same read paint the same set of colours (no right/wrong colouring);
# no node uses the good / bad / danger / seal colours; nothing changes colour when the beam comes level.
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const Fix = preload("res://scripts/tests/cards/C14/weigh_fix.gd")
const R = preload("res://scripts/cards/minigames/weigh/weigh_rules.gd")

var fix


func _initialize() -> void:
	var t := T.new(self, "C14_no_reveal")
	t.run_async(_body.bind(t))


func _body(t) -> void:
	fix = Fix.new()
	fix.setup_text()
	var obs_texts := PackedStringArray()
	for key in fix.catalog().keys():
		var txt := CardText.obs(str(key))
		if txt != "":
			obs_texts.append(txt)
	t.ok(obs_texts.size() >= 8, "observation texts loaded (%d)" % obs_texts.size())
	for name in Fix.FIXTURES:
		var pars: Dictionary = fix.params(name)
		var game = fix.open(self, pars)
		await t.frames(2)
		var allowed := _allowed_numbers(game, pars)
		_scan(t, game, pars, obs_texts, allowed, name + " open")
		fix.level_ops(game)
		game._refresh(false)
		await t.frames(1)
		_scan(t, game, pars, obs_texts, allowed, name + " level")
		var at_level := _colours(game)
		var lvl_step := int(game._poise_step)
		var away := lvl_step + 6 if lvl_step + 6 <= int(game._poise_max) else lvl_step - 6
		game.apply_op(["poise", away])
		await t.frames(1)
		t.eq(_colours(game), at_level, name + " nothing changes colour when the beam comes level")
		game.apply_op(["poise", lvl_step])
		game.apply_op(["commit"])
		await t.frames(1)
		_scan(t, game, pars, obs_texts, allowed, name + " stars")
		var read := int(game._read_fen)
		for txt in fix.visible_text(game):
			t.ok(not txt.contains(str(read)) or str(read).length() <= 2, name + " reading %d not on screen: %s" % [read, txt])
		var right := Fix.CALLS.find(fix.answer(pars))
		game.apply_op(["call", right])
		await t.frames(1)
		_scan(t, game, pars, obs_texts, allowed, name + " called right")
		var colours_right := _colours(game)
		var wrong := Fix.CALLS.find(R.neighbour(fix.answer(pars)))
		game.apply_op(["call", wrong])
		await t.frames(1)
		var colours_wrong := _colours(game)
		t.eq(colours_wrong, colours_right, name + " right and wrong calls paint the same colours")
		game.queue_free()
		await t.frames(1)
	var src := ""
	for f in ["weigh_game.gd", "weigh_beam.gd", "weigh_zoom.gd", "weigh_rules.gd"]:
		src += FileAccess.get_file_as_string("res://scripts/cards/minigames/weigh/" + f)
	for key in ["&\"good\"", "&\"bad\"", "&\"danger\"", "&\"seal\"", "CardText.obs("]:
		t.ok(not src.contains(key), "weigh code never uses " + key)


## Numbers the player may see: weight faces, the claim's parts, the rule (one step, the "a little" limit: rules
## of the game, not the hidden weight), the legend (what a big star and a small dot are worth) and star numbers 0..cap.
func _allowed_numbers(game, pars: Dictionary) -> Dictionary:
	var ok := {}
	for w in pars.get("weights_fen", []):
		var s := R.split(int(w))
		for k in ["liang", "qian", "fen"]:
			ok[str(s[k])] = true
	var tool := str(game._tool)
	for v in [int(pars["claimed_fen"]), int(game._res), R.small_fen(pars), R.minor_fen(tool, int(game._res), bool(game._fine)),
			R.major_fen(tool, int(game._res))]:
		var c := R.split(v)
		for k in ["liang", "qian", "fen"]:
			ok[str(c[k])] = true
	var major := R.major_fen(str(game._tool), int(game._res))
	for v in range(0, int(game._poise_max) * int(game._res) / major + 1):
		ok[str(v)] = true
	return ok


func _scan(t, game, pars: Dictionary, obs_texts: PackedStringArray, allowed: Dictionary, label: String) -> void:
	var leaked: PackedStringArray = fix.secret_text(game, int(pars["actual_fen"]))
	t.ok(leaked.is_empty(), label + ": no hidden fen, no percent: " + ", ".join(leaked))
	var bad: PackedStringArray = t.all_text_from_cardtext(game)
	t.ok(bad.is_empty(), label + ": text from CardText or digits: " + ", ".join(bad))
	var re := RegEx.create_from_string("[0-9]+")
	for txt in fix.visible_text(game):
		for o in obs_texts:
			t.ok(not txt.contains(o), label + ": observation text on screen: " + txt)
		for m in re.search_all(txt):
			t.ok(allowed.has(m.get_string()), label + ": number %s allowed in '%s'" % [m.get_string(), txt])


## Every colour the game's own nodes are painted with (modulate, font colours, style boxes of buttons).
func _colours(game) -> Array:
	var seen := {}
	for n in fix._walk(game):
		if not (n is Control):
			continue
		var c := n as Control
		if not c.is_visible_in_tree():
			continue
		seen[c.modulate.to_html()] = true
		for fc in ["font_color", "font_hover_color", "font_pressed_color", "font_disabled_color"]:
			if c.has_theme_color_override(fc):
				seen[c.get_theme_color(fc).to_html()] = true
		if c is Button:
			for st in ["normal", "hover", "pressed", "disabled"]:
				if c.has_theme_stylebox_override(st):
					var sb := c.get_theme_stylebox(st)
					if sb is StyleBoxFlat:
						seen[(sb as StyleBoxFlat).border_color.to_html()] = true
						seen[(sb as StyleBoxFlat).bg_color.to_html()] = true
	var out := seen.keys()
	out.sort()
	return out
