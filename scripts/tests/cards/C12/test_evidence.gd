# What the player can see with the real engine's params (fix2 after the blind acceptance review, 10-25):
# every spot item card's body mask is its picture's (items.json spot.opaque, spot_body_tool.gd regenerates it);
# for every spot template, real, fake and taken: every mark sits on the body (a look that bites the outline
# over the outline), changes at least MIN_PX pixels of the lens picture and moves its strongest pixel
# plainly, shows to the naked eye exactly when it is coarse, is a look its legend row shows (the legend lists
# every look the category can draw, old wear drawn as aged colour, tampering in colours of its own), and no
# two marks are close enough for one pin to name both. Owner C12.
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const A = preload("res://scripts/tests/cards/G04/appraisal_support.gd")
const Marks = preload("res://scripts/cards/minigames/spot/spot_marks.gd")
const FlawRender = preload("res://scripts/core/flaw_render.gd")

const ITEMS_PER := 4
const SHOWS := 0.2      # a mark's strongest pixel moves at least this far (a bite counts as 1)


func _initialize() -> void:
	var t := T.new(self, "C12_evidence")
	_bodies(t)
	_marks(t)
	FlawRender.clear_cache()
	t.finish()


## Every item card that plays spot carries the body mask of the picture the game shows.
func _bodies(t) -> void:
	var doc = CardDB.read_json("res://data/cards/minigames/items.json")
	var n := 0
	for card in doc.get("cards", []):
		if not (card.get("minigames", []) as Array).has("spot"):
			continue
		n += 1
		var art := "item." + str(card.get("template", ""))
		var mask := str((card.get("spot", {}) as Dictionary).get("opaque", ""))
		t.eq(mask, Marks.body_mask(Marks.base_image(art)), "%s: spot.opaque is %s's opaque pixels (stale: run spot_body_tool.gd)" % [card.get("id", ""), art])
	t.ok(n >= 20, "spot item cards checked (%d)" % n)


func _marks(t) -> void:
	var c := A.real_ctx(31)
	var cfg: Dictionary = c.rules("economy")["appraise"]["spot"]
	var edge_looks: Array = cfg.get("edge_looks", [])
	var doc = CardDB.read_json("res://data/cards/minigames/items.json")
	var bad := {}
	var counts := {"wear": 0, "differs": 0}
	for card in doc.get("cards", []):
		if not (card.get("minigames", []) as Array).has("spot"):
			continue
		var tpl := str(card["template"])
		for k in ITEMS_PER:
			var r := CardItems.generate(c, ["c", 1, "evidence", tpl, k], tpl)
			if not bool(r.get("ok", false)):
				continue
			var id := str(r["item"])
			for truth in [[false, false], [true, false], [false, true]]:
				A.set_truth(c, id, truth[0], truth[1])
				var p := CardAppraisal.params_for(c, id, &"spot")
				for why in _check(p, edge_looks, int(cfg.get("tol_px", 2)), counts):
					if not bad.has(why):
						bad[why] = "%s fake=%s stolen=%s" % [tpl, truth[0], truth[1]]
	for why in bad.keys():
		t.ok(false, "%s (first: %s)" % [why, bad[why]])
	t.ok(counts["wear"] > 300 and counts["differs"] > 100, "marks checked: %s" % str(counts))


func _check(p: Dictionary, edge_looks: Array, tol: int, counts: Dictionary) -> Array:
	var out: Array = []
	var base := Marks.base_image(str(p["art"]))
	var parts: Array = p["parts"]
	var marks: Array = p["marks"]
	var legend: Dictionary = p["legend"]
	for row in ["wear", "differs"]:
		for look in legend.get(row, []):
			if (row == "wear") != Marks.is_wear_look(str(look)):
				out.append("legend row %s holds %s, drawn as the other row's kind of picture" % [row, look])
	for i in marks.size():
		var mk: Dictionary = marks[i]
		var kind := str(mk["kind"])
		counts[kind] += 1
		var at := Marks.rect_of(mk["at"])
		if not (legend.get(kind, []) as Array).has(str(mk["look"])):
			out.append("a %s mark's look %s is not in its legend row" % [kind, mk["look"]])
		var solid := 0
		var rim := 0
		for y in range(at.position.y, at.end.y):
			for x in range(at.position.x, at.end.x):
				if base.get_pixel(x, y).a > 0.5:
					solid += 1
					if Marks._rim(base, x, y):
						rim += 1
		var edge := edge_looks.has(str(mk["look"]))
		if float(solid) < (0.4 if edge else 0.6) * float(at.get_area()):
			out.append("%s sits off the body" % mk["look"])
		if edge and rim < 2:
			out.append("%s does not sit on the outline" % mk["look"])
		var lens := base.duplicate() as Image
		Marks.paint(lens, [mk], parts, true, int(p["seed"]))
		var changed := 0
		var top := 0.0
		for y in Marks.IMG:
			for x in Marks.IMG:
				var a := base.get_pixel(x, y)
				var b := lens.get_pixel(x, y)
				if a == b:
					continue
				if not at.has_point(Vector2i(x, y)):
					out.append("%s paints outside its at" % mk["look"])
				changed += 1
				top = maxf(top, 1.0 if b.a <= 0.5 else Marks._step(a, b))
		if changed < Marks.MIN_PX:
			out.append("%s changes fewer than MIN_PX pixels" % mk["look"])
		if top < SHOWS:
			out.append("%s hardly shows (strongest pixel %.2f)" % [mk["look"], top])
		var eye := base.duplicate() as Image
		Marks.paint(eye, [mk], parts, false, int(p["seed"]))
		if Marks.is_fine(mk, parts) == (eye.get_data() != base.get_data()):
			out.append("a %s mark shows to the naked eye when it should not, or hides when coarse" % ("fine" if Marks.is_fine(mk, parts) else "coarse"))
		for j in range(i + 1, marks.size()):
			var other := Marks.rect_of(marks[j]["at"])
			if at.grow(tol).intersects(other.grow(tol)):
				out.append("two marks close enough for one pin to name both")
	return out
