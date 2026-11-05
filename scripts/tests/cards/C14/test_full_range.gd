# C14 B2: every weigh item in the real K11 spec levels across its whole range. For each template, both ends of
# the claim, each with the far ends of the worn and the bad deviation (the engine's own formula), the steady
# hand levels the beam (quality 1000, read within one step) with DESIGN 6.2's weight sets: small dengzi set,
# the ten-liang bar and the big silver box on [10..500], rice on the steelyard (10 fen steps, [100..2000, 2000]).
# Weight sets the spec already carries (WP1 data) are used as they are. The old default set cannot carry the
# ten-liang bar: that round still commits and hands back "unsure" without error.
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const Fix = preload("res://scripts/tests/cards/C14/weigh_fix.gd")
const R = preload("res://scripts/cards/minigames/weigh/weigh_rules.gd")

const SMALL_SET := [1, 2, 5, 10, 20, 50, 100, 200]
const BIG_SET := [10, 20, 50, 100, 200, 500]
const RICE_SET := [100, 200, 500, 1000, 2000, 2000]


func _initialize() -> void:
	var t := T.new(self, "C14_full_range")
	t.run_async(_body.bind(t))


func _body(t) -> void:
	var fix = Fix.new()
	fix.setup_text()
	var specs := _weigh_specs()
	t.ok(specs.size() >= 10, "K11 weigh specs found (%d)" % specs.size())
	var seen_rice := false
	var seen_bar := false
	var seen_box := false
	var n := 0
	for row in specs:
		var id := str(row[0])
		var spec: Dictionary = row[1]
		var tool := str(spec.get("tool", "dengzi"))
		var claim: Array = spec.get("claimed_fen", [280, 320])
		var weights: Array = _design_weights(spec)
		var res := 10 if tool == "steelyard" else int(spec.get("resolution_fen", 1))
		if spec.has("resolution_fen"):
			res = int(spec["resolution_fen"])
		if tool == "steelyard":
			seen_rice = true
		elif int(claim[1]) >= 900:
			seen_bar = true
		elif int(claim[1]) > 400:
			seen_box = true
		for claimed in [int(claim[0]), int(claim[1])]:
			for key in ["dev_worn_pct", "dev_bad_pct"]:
				var dev: Array = spec.get(key, [0, 2])
				for d in [int(dev[0]), int(dev[1])]:
					var actual := maxi(1, claimed * (100 - d) / 100)
					var pars := {"kind": "weigh", "seed": 14100 + n, "item": id, "art": "", "minutes_per_step": 1,
						"max_minutes": 30, "tool": tool, "claimed_fen": claimed, "actual_fen": actual,
						"weights_fen": weights.duplicate(), "resolution_fen": res}
					n += 1
					var result: Dictionary = fix.run_skill(self, pars, 1.0)
					var label := "%s claim %d dev %d actual %d" % [id, claimed, d, actual]
					t.eq(int(result.get("quality_permille", 0)), 1000, label + " levels")
					var read := int(result.get("measures", {}).get("read_fen", -9999))
					t.ok(absi(read - actual) <= res, label + " read %d" % read)
					t.eq(fix.call_of(result), fix.answer(pars), label + " call")
		await t.frames(1)
	t.ok(seen_rice and seen_bar and seen_box, "rice, ten-liang bar and big silver box all covered")
	# Old engine default set on the ten-liang bar: cannot level, still finishes cleanly with "unsure".
	var old := {"kind": "weigh", "seed": 14199, "item": "it.goldbar.bar_ten", "art": "", "minutes_per_step": 1,
		"max_minutes": 30, "tool": "dengzi", "claimed_fen": 1020, "actual_fen": 1010,
		"weights_fen": SMALL_SET.duplicate(), "resolution_fen": 1}
	var game = fix.open(self, old)
	await t.frames(1)
	var reach := R.weight_total(SMALL_SET) + int(game._poise_max) * 1
	t.ok(reach < 1010, "old set cannot reach the bar (%d)" % reach)
	var box := {"r": {}}
	game.finished.connect(func(r: Dictionary) -> void: box["r"] = r)
	t.ok(game.apply_op(["commit"]), "old params: commit")
	t.ok(game.apply_op(["call", 5]), "old params: unsure")
	t.ok(game.apply_op(["done"]), "old params: done")
	t.eq(box["r"].get("observations", []), ["obs.weigh.unsure"], "old params hand back unsure")
	game.queue_free()
	await t.frames(1)


## Every weigh block in the real K11 item spec: [[card id, weigh dict], ...].
func _weigh_specs() -> Array:
	var out: Array = []
	var d = CardDB.read_json("res://data/cards/minigames/items.json")
	if typeof(d) != TYPE_DICTIONARY:
		return out
	for card in d.get("cards", []):
		if typeof(card) == TYPE_DICTIONARY and typeof(card.get("weigh")) == TYPE_DICTIONARY:
			out.append([str(card.get("id", "")), card["weigh"]])
	return out


## DESIGN 6.2: the spec's own set when it has one, else rice -> steelyard set, claims reaching 900 fen or the
## big silver box (claims over 400) -> [10..500], everything else the small dengzi set.
func _design_weights(spec: Dictionary) -> Array:
	if typeof(spec.get("weights_fen")) == TYPE_ARRAY and not (spec["weights_fen"] as Array).is_empty():
		var own: Array = []
		for w in spec["weights_fen"]:
			own.append(int(w))
		return own
	if str(spec.get("tool", "")) == "steelyard":
		return RICE_SET.duplicate()
	var claim: Array = spec.get("claimed_fen", [0, 0])
	if int(claim[1]) > 400:
		return BIG_SET.duplicate()
	return SMALL_SET.duplicate()
