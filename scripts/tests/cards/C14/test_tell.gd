# C14 fix2 (blind eye test 10-25: "the player has to see it"). The tell is honest and learnable:
# - the needle stands straight at exactly one step for any weight (between two stars too), one step off leans it
#   at least NEEDLE_MIN_PX on every eye, more steps never lean it less, and it leans the right way;
# - one step off is not level: no clear read there, and the steady hand never stops there;
# - real engine params put every weight on a step: the steady hand reads it exactly with the needle straight;
#   honest wear stays inside "a little light", most fakes of every template fall beyond it (or are heavy);
# - the legend says what a big star and a small dot are worth on this scale and how a reading is made, inside the
#   beam frame, left of the lifting cord, never clipped;
# - star numbers under the open close-up are left out whole, never cut in half; the rest stay.
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const Fix = preload("res://scripts/tests/cards/C14/weigh_fix.gd")
const R = preload("res://scripts/cards/minigames/weigh/weigh_rules.gd")
const BEAM = preload("res://scripts/cards/minigames/weigh/weigh_beam.gd")
const A = preload("res://scripts/tests/cards/G04/appraisal_support.gd")

## Every eye the engine can hand out (needle_gain 6 + eye, eye 0-6) and the game's whole clamp range.
const GAINS := [1, 2, 4, 6, 7, 8, 9, 10, 11, 12, 16, 20]
## Share of a template's fakes (whole spec grid) a careful weigher must be able to name (light_much / heavy).
const CAUGHT_MIN_PERMILLE := 650

var fix


func _initialize() -> void:
	var t := T.new(self, "C14_tell")
	t.run_async(_body.bind(t))


func _body(t) -> void:
	fix = Fix.new()
	fix.setup_text()
	t.eq(int(BEAM.NEEDLE_MIN_PX) >= 3, true, "one step off leans the needle 3 px or more")
	_rules(t)
	await _needle(t)
	await _deadband(t)
	await _one_step_off(t)
	await _real_engine(t)
	_spec_spread(t)
	await _legend(t)
	await _cover(t)


## Pure rules: the step error rounds to the nearest step, and only the nearest step is a clear read.
func _rules(t) -> void:
	for res in [1, 2, 10, 20]:
		for d in range(-3 * res, 3 * res + 1):
			var off := R.off_steps(1000 + d, 1000, res)
			t.ok(absi(d - off * res) * 2 <= res, "res %d d %d: off %d is the nearest step" % [res, d, off])
			var q := R.quality(1000 + d, 1000, res, true)
			if off == 0:
				t.eq(q, R.Q_LEVEL, "res %d d %d: the straight step reads clear" % [res, d])
			else:
				t.ok(q < R.Q_LEVEL, "res %d d %d: %d step(s) off is not a clear read (%d)" % [res, d, off, q])
		# A weight exactly half way between two steps: one of the two stands the needle straight, not both, not none.
		if res % 2 == 0:
			var a: int = 1000 + res / 2
			var straight := 0
			for ind in [1000, 1000 + res]:
				straight += 1 if R.off_steps(a, ind, res) == 0 else 0
			t.eq(straight, 1, "res %d: half way between two steps, exactly one is straight" % res)
	t.eq(R.quality(301, 300, 1, true), R.Q_NEAR, "one fen off on a 1-fen dengzi is near, not level")
	t.eq(R.quality(299, 300, 1, true), R.Q_NEAR, "one fen the other way is near too")


## Opens a game on these params with the beam settling at once.
func _open(pars: Dictionary):
	var game = fix.open(self, pars)
	game._beam.set("fast", true)
	return game


## Puts exactly these weights on the hook and the poise on this step.
func _put(game, on: Array, step: int) -> void:
	for i in game._on.size():
		var want: bool = on.has(i)
		if bool(game._on[i]) != want:
			game.apply_op(["weight", i])
	if int(game._poise_step) != step:
		game.apply_op(["poise", step])
	game._beam.call("settle")


func _needle(t) -> void:
	var pars: Dictionary = fix.params("match")
	pars["resolution_fen"] = 1
	pars["actual_fen"] = 300
	for gain in GAINS:
		pars["needle_gain"] = gain
		var game = _open(pars)
		await t.frames(1)
		var beam = game._beam
		var prev := 0
		var mono := true
		var pxs: Array = []
		for s in range(0, 15):
			_put(game, [0, 1], s)                 # 200 + 100 + s fen: s steps heavier on the poise side
			var px := int(beam.needle_offset_px())
			pxs.append(px)
			if absi(px) < prev:
				mono = false
			prev = absi(px)
		t.eq(int(pxs[0]), 0, "gain %d: level, the needle is straight" % gain)
		t.ok(int(pxs[1]) >= BEAM.NEEDLE_MIN_PX, "gain %d: one step off leans %d px (>= %d)" % [gain, int(pxs[1]), BEAM.NEEDLE_MIN_PX])
		t.ok(mono, "gain %d: more steps off never lean less %s" % [gain, str(pxs)])
		t.ok(absi(int(pxs[14])) <= int(BEAM.NEEDLE_MAX), "gain %d: the needle stops at its pin" % gain)
		_put(game, [0, 2, 3, 4], 19)                   # 200 + 50 + 20 + 10 + 19 = 299: the goods one fen heavier
		t.ok(int(beam.needle_offset_px()) <= -BEAM.NEEDLE_MIN_PX, "gain %d: goods one step heavier, needle leans toward the pan (%d)" % [gain, int(beam.needle_offset_px())])
		game.queue_free()
		await t.frames(1)


## Weights between two stars (old params, mocks): one step still stands the needle straight, its neighbours lean.
func _deadband(t) -> void:
	for row in [["steelyard_rice", 10], ["match", 2]]:
		var pars: Dictionary = fix.params(str(row[0]))
		var res := int(row[1])
		pars["resolution_fen"] = res
		for r in range(0, res):
			var base := 1500 if str(row[0]) == "steelyard_rice" else 280
			pars["actual_fen"] = base + 7 * res + r
			var game = _open(pars)
			await t.frames(1)
			var on: Array = [0, 1, 2, 3] if str(row[0]) == "steelyard_rice" else [0, 2, 3, 4]   # 1500 / 280 fen
			var zero: Array = []
			var levels: Array = []
			var clear: Array = []
			for s in range(0, 16):
				_put(game, on, s)
				if int(game._beam.needle_offset_px()) == 0:
					zero.append(s)
				if game._level():
					levels.append(s)
				if R.quality(int(game._actual), int(game._indicated()), res, true) == R.Q_LEVEL:
					clear.append(s)
			var label := "%s res %d actual %d" % [row[0], res, int(pars["actual_fen"])]
			t.eq(zero.size(), 1, label + ": exactly one step stands the needle straight " + str(zero))
			t.eq(levels, zero, label + ": that step and only that step counts as level")
			t.eq(clear, zero, label + ": that step and only that step reads clear")
			if zero.size() == 1:
				var s0 := int(zero[0])
				t.ok(absi(int(pars["actual_fen"]) - (base + s0 * res)) * 2 <= res, label + ": it is the step nearest the weight")
				for s in [s0 - 1, s0 + 1]:
					_put(game, on, s)
					t.ok(absi(int(game._beam.needle_offset_px())) >= BEAM.NEEDLE_MIN_PX, label + ": one step off leans plainly")
			game.queue_free()
			await t.frames(1)


## The steady hand ends on the straight step; one step either side is neither level nor a clear read; the
## opening is never level or one step off it.
func _one_step_off(t) -> void:
	for name in Fix.FIXTURES:
		var pars: Dictionary = fix.params(name)
		var game = _open(pars)
		await t.frames(1)
		t.ok(not game._near_level(), name + ": the opening is at least two steps off")
		fix.level_ops(game)
		game._beam.call("settle")
		t.ok(game._level(), name + ": the steady hand ends level")
		t.eq(int(game._beam.needle_offset_px()), 0, name + ": the needle is straight there")
		var lvl := int(game._poise_step)
		for s in [lvl - 1, lvl + 1]:
			if s < 0 or s > int(game._poise_max):
				continue
			game.apply_op(["poise", s])
			game._beam.call("settle")
			t.ok(not game._level(), name + ": one step off is not level")
			t.ok(absi(int(game._beam.needle_offset_px())) >= BEAM.NEEDLE_MIN_PX, name + ": one step off leans plainly")
			game.apply_op(["commit"])
			t.eq(int(game._quality_last), R.Q_NEAR, name + ": reading one step off is not a clear read")
			game.apply_op(["again"])
		game.queue_free()
		await t.frames(1)
	var near := 0
	for k in 40:
		var p: Dictionary = fix.params(Fix.FIXTURES[k % Fix.FIXTURES.size()])
		p["seed"] = 31000 + k * 13
		var g = _open(p)
		near += 1 if g._near_level() else 0
		g.queue_free()
		if k % 10 == 9:
			await t.frames(1)
	t.eq(near, 0, "no opening of 40 starts level or one step off")


## Real engine params (two seeds, every weigh template, real and fake): the weight is on a step, the steady hand
## reads it exactly with the needle straight, honest pieces are never short or heavy beyond "a little".
func _real_engine(t) -> void:
	var n := 0
	for seed in [7, 31]:
		var c := A.real_ctx(seed)
		for item_def in c.db.ids_of(&"item"):
			var d := c.db.def(item_def)
			if not d.has("weigh"):
				continue
			for fake in [false, true]:
				for id in A.items_of(c, str(d["template"]), fake, 2, "tell"):
					var p := CardAppraisal.params_for(c, str(id), &"weigh")
					var res := int(p["resolution_fen"])
					var actual := int(p["actual_fen"])
					var label := "%s seed %d %s claim %d actual %d" % [item_def, seed, "fake" if fake else "real", int(p["claimed_fen"]), actual]
					t.eq(actual % res, 0, label + ": the weight is on one of the scale's steps")
					var cat: String = fix.answer(p)
					if not fake:
						t.ok(cat == "match" or cat == "light_small", label + ": honest piece reads match or a little light (" + cat + ")")
					var game = _open(p)
					var result: Dictionary = fix.play(game, 1.0)
					t.eq(int(result.get("quality_permille", 0)), R.Q_LEVEL, label + ": the steady hand reads clear")
					t.eq(int(result.get("measures", {}).get("read_fen", -1)), actual, label + ": and reads the weight exactly")
					t.eq(int(game._beam.needle_offset_px()), 0, label + ": with the needle straight")
					game.queue_free()
					n += 1
					if n % 8 == 0:
						await t.frames(1)
	t.ok(n >= 60, "real engine cases played (%d)" % n)


## Whole spec grid per template (claims x deviations, the engine's formula in appraisal.gd _weigh): honest wear
## never goes past "a little light" (a correct call never accuses an honest customer) and most fakes are caught.
func _spec_spread(t) -> void:
	var d = CardDB.read_json("res://data/cards/minigames/items.json")
	var n := 0
	for card in d.get("cards", []):
		if typeof(card) != TYPE_DICTIONARY or typeof(card.get("weigh")) != TYPE_DICTIONARY:
			continue
		var spec: Dictionary = card["weigh"]
		var res := maxi(1, int(spec.get("resolution_fen", 1)))
		var claim: Array = spec["claimed_fen"]
		var pars := {"resolution_fen": res, "small_fen": int(spec["small_fen"])}
		var worst := ""
		var fakes := 0
		var caught := 0
		for c in range(int(claim[0]), int(claim[1]) + 1):
			for key in ["dev_worn_pct", "dev_bad_pct"]:
				var dev: Array = spec[key]
				for v in range(int(dev[0]), int(dev[1]) + 1):
					var actual := maxi(1, c * (100 - v) / 100)
					if actual % res != 0:
						actual = (actual / res + (1 if actual < c else 0)) * res
					pars["claimed_fen"] = c
					pars["actual_fen"] = maxi(res, actual)
					var cat: String = fix.answer(pars)
					if key == "dev_worn_pct":
						if cat == "light_much" or cat == "heavy":
							worst = "claim %d dev %d -> %s" % [c, v, cat]
					else:
						fakes += 1
						caught += 1 if (cat == "light_much" or cat == "heavy") else 0
		n += 1
		t.eq(worst, "", str(card["id"]) + ": honest wear stays within a little light")
		t.ok(caught * 1000 >= fakes * CAUGHT_MIN_PERMILLE, "%s: most fakes are plainly short or heavy (%d of %d)" % [card["id"], caught, fakes])
	t.ok(n >= 10, "weigh templates checked (%d)" % n)


## The legend: what a big star and a small dot are worth here, read at the poise cord, weights plus stars.
func _legend(t) -> void:
	var cases := [
		["match", 1, true, "c14.star.qian", 1],
		["match", 1, false, "c14.star.qian", 5],
		["match", 2, true, "c14.star.qian", 2],
		["steelyard_rice", 10, true, "c14.star.liang", 10],
		["steelyard_rice", 10, false, "c14.star.liang", 50],
	]
	for row in cases:
		var pars: Dictionary = fix.params(str(row[0]))
		pars["resolution_fen"] = int(row[1])
		pars["minor_ticks"] = bool(row[2])
		var game = _open(pars)
		await t.frames(1)
		var label := "%s res %d fine %s" % [row[0], int(row[1]), str(row[2])]
		var beam: Control = game._beam
		var want := {
			"LegendStar": CardText.ui(str(row[3])),
			"LegendDot": CardText.ui("c14.legend.dot", {"w": game._wt(int(row[4]))}),
			"LegendCord": CardText.ui("c14.legend.cord"),
			"LegendSum": CardText.ui("c14.legend.sum"),
		}
		t.eq(int(R.minor_fen(str(game._tool), int(row[1]), bool(row[2]))), int(row[4]), label + ": the dot is worth what the legend says")
		var rects: Array = []
		var cord_x: float = float((beam.call("_fulcrum") as Vector2).x) - BEAM.GATE_HALF - 2.0
		for node_name in want.keys():
			var l := beam.get_node_or_null(str(node_name)) as Label
			t.ok(l != null and l.is_visible_in_tree(), label + ": legend line " + str(node_name))
			if l == null:
				continue
			t.eq(l.text, str(want[node_name]), label + ": " + str(node_name) + " text")
			var font := l.get_theme_font("font")
			var fs := l.get_theme_font_size("font_size")
			var w := font.get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			t.ok(w <= l.size.x, label + ": '%s' fits its line (%d <= %d px)" % [l.text, int(w), int(l.size.x)])
			var r := Rect2(l.position, l.size)
			t.ok(r.end.x <= cord_x, label + ": " + str(node_name) + " stays left of the lifting cord")
			t.ok(r.end.y <= BEAM.ARM_Y - 34.0, label + ": " + str(node_name) + " stays above the beam and its star numbers")
			for o in rects:
				t.ok(not r.intersects(o), label + ": legend lines do not overlap")
			rects.append(r)
		for txt in want.values():
			t.ok(not str(txt).contains(str(int(pars["actual_fen"]))) or str(int(pars["actual_fen"])).length() <= 1, label + ": the legend never carries the hidden weight")
		game.queue_free()
		await t.frames(1)


## After "read the stars" no star number of the beam is cut by the close-up: those under it are left out whole,
## the others stay; reopening ("again") draws them all again. Checked level, tilted down and tilted up.
func _cover(t) -> void:
	for row in [["match", 0], ["match", 40], ["steelyard_rice", 0], ["steelyard_rice", 30], ["steelyard_rice", 10]]:
		var pars: Dictionary = fix.params(str(row[0]))
		var game = _open(pars)
		await t.frames(1)
		fix.level_ops(game)
		if int(row[1]) > 0:
			game.apply_op(["poise", clampi(int(game._poise_step) + int(row[1]) - 20, 0, int(game._poise_max))])
		game._beam.call("settle")
		var beam = game._beam
		var before := PackedStringArray(beam.tick_texts())
		game.apply_op(["commit"])
		game._beam.call("settle")
		var label := "%s poise %d" % [row[0], int(game._poise_step)]
		var zoom_rect := Rect2(game._zoom.position - beam.position, game._zoom.size)
		var shown := PackedStringArray(beam.tick_texts())
		var font := CardTheme.font_body()
		var cap := int(beam.poise_max) * int(beam.resolution)
		var major := int(beam.major)
		var every := int(beam.call("_label_every"))
		var hidden := 0
		var kept := 0
		var m := 0
		while m <= cap:
			if (m / major) % every == 0:
				var txt := str(m / major)
				var box := _label_box(beam, m, txt, font)
				var under := box.intersects(zoom_rect)
				if under:
					t.ok(not shown.has(txt), label + ": star %s under the close-up is left out whole" % txt)
					hidden += 1 if not shown.has(txt) else 0
				elif not zoom_rect.grow(4.0).intersects(box):
					t.ok(shown.has(txt), label + ": star %s clear of the close-up stays" % txt)
					kept += 1
			m += major
		if int(row[1]) == 0:
			t.ok(hidden >= 1 and kept >= 2, label + ": level, the far stars hidden (%d), the near ones kept (%d)" % [hidden, kept])
		game.apply_op(["again"])
		game._beam.call("settle")
		t.eq(PackedStringArray(beam.tick_texts()).size() >= before.size(), true, label + ": weighing again draws every star number")
		game.queue_free()
		await t.frames(1)


## A star number's glyph box in beam coordinates (as weigh_beam draws it: centred 40 px cell, baseline 14 px
## above the arm, turned with the beam).
func _label_box(beam, v: int, txt: String, font: Font) -> Rect2:
	var x := float(beam.call("_x_of_fen", v))
	var sz := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_CENTER, 40, 14) if font != null else Vector2(16, 18)
	var asc := font.get_ascent(14) if font != null else 14.0
	var top := BEAM.ARM_Y - 14.0 - asc
	var corners := [Vector2(x - sz.x * 0.5, top), Vector2(x + sz.x * 0.5, top), Vector2(x - sz.x * 0.5, top + sz.y),
		Vector2(x + sz.x * 0.5, top + sz.y)]
	var box := Rect2(beam.call("_xform", corners[0]), Vector2.ZERO)
	for p in corners:
		box = box.expand(beam.call("_xform", p))
	return box
