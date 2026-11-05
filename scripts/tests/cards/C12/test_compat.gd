# Old params still play (DESIGN P9, WP2): the pre-10-25 engine and mock gave marks without at / look and no
# legend / lens_px / blink. Then a mark is painted over its whole part (the old picture), the spot to hit
# is the part centre 6x6, there is no legend, ink 3 and lens 72 by default; the round starts and finishes
# without errors and the result passes the engine's result check. Empty params do not crash.
# Owner C12.
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const Lib = preload("res://scripts/tests/cards/C12/c12_lib.gd")
const Marks = preload("res://scripts/cards/minigames/spot/spot_marks.gd")
const Scenario = preload("res://scripts/cards/mock/mock_scenario.gd")
const FlawRender = preload("res://scripts/core/flaw_render.gd")


func _initialize() -> void:
	var t := T.new(self, "C12_compat")
	t.run_async(_body.bind(t))


func _body(t) -> void:
	var bus := CardEventBus.new()
	root.add_child(bus)
	var mock := MockCardEngine.new(bus)
	t.ok(mock.db != null, "text db")
	await t.frames(1)
	var cases: Dictionary = {}
	for name in Lib.old_fixture_names():
		cases[name] = Lib.fixture(name)
	for pair in [["jewelry", "hairpin"], ["art", "calligraphy"], ["clothing", "qipao"], ["documents", "iou"]]:
		var p: Dictionary = _old_shape(Scenario.spot_layout(4242, str(pair[0]), str(pair[1])))
		p.merge({"kind": "spot", "seed": 99, "item": "I-mock", "art": "item.%s.%s" % pair, "minutes_per_step": 1,
			"max_minutes": 30}, false)
		cases["mock " + str(pair[1])] = p
	for name in cases.keys():
		var params: Dictionary = cases[name]
		for skill in [0.0, 0.8, 1.0]:
			var r = Lib.run(self, params, func(g: CardSpotGame) -> void: g.autoplay(skill))
			t.ok(r != null, "%s %.1f finishes" % [name, skill])
			if r != null:
				t.ok(_valid(r), "%s %.1f passes the engine's result check" % [name, skill])
		var game := Lib.open_game(self, params)
		await t.frames(1)
		var board := Lib.board(game)
		t.eq((board.get_node("Legend") as Control).get_child_count(), 0, name + " no legend without params.legend")
		t.eq(game.ink_left(), int(params.get("ink", 3)), name + " ink from params")
		t.eq((board.get_node("Item") as Control).get("lens_px"), 72.0, name + " lens 72 by default")
		t.ok(not (board.get_node("BlinkButton") as Control).visible, name + " no compare without params.blink")
		game.queue_free()
		CardAnchors.clear()
		await t.frames(1)
		_old_picture(t, name, params)
	var empty = Lib.run(self, {}, func(g: CardSpotGame) -> void:
		g.autoplay(1.0))
	t.ok(empty != null and _valid(empty), "empty params finish")
	var ink3 = Lib.run(self, {"tools": ["eye", "lens", "atlas"], "marks": []}, func(g: CardSpotGame) -> void:
		t.eq(g.ink_left(), 3, "no ink in params: 3")
		g.apply_op(["done"]))
	t.ok(ink3 != null, "no-ink params finish")
	bus.queue_free()
	CardAnchors.clear()
	await t.frames(3)


## [shared] WP0 10-25: the mock now hands out the new params (at / look / legend / lens_px / blink); strip them
## so these cases keep testing the old shape this file is about.
func _old_shape(p: Dictionary) -> Dictionary:
	var out := p.duplicate(true)
	for key in ["legend", "lens_px", "blink"]:
		out.erase(key)
	out["ink"] = 3
	out["atlas_open"] = true
	for mk in out.get("marks", []):
		(mk as Dictionary).erase("at")
		(mk as Dictionary).erase("look")
	return out


## Old marks: painted on their whole part rect, judged at the part centre 6x6.
func _old_picture(t, name: String, params: Dictionary) -> void:
	var parts: Array = params.get("parts", [])
	for mark in params.get("marks", []):
		t.ok(not Marks.has_at(mark), name + " old mark has no at")
		var part := Marks.part_of(parts, str(mark.get("part", "")))
		var pr := Marks.rect_of(part.get("rect", []))
		t.eq(Marks.paint_rect(mark, parts), pr, name + " old mark painted over its part")
		var spot := Marks.spot_rect(mark, parts)
		t.eq(spot.size, Vector2i(6, 6), name + " old spot is 6x6")
		t.ok(pr.encloses(spot) or pr.size.x < 6 or pr.size.y < 6, name + " old spot inside the part")
		t.eq(spot.get_center(), Vector2i(pr.position + pr.size / 2), name + " old spot at the part centre")
	var base := Marks.base_image(str(params.get("art", "")))
	var eye := base.duplicate() as Image
	Marks.paint(eye, params.get("marks", []), parts, false, int(params.get("seed", 0)))
	for y in 64:
		for x in 64:
			if eye.get_pixel(x, y) == base.get_pixel(x, y):
				continue
			var inside := false
			for mark in params.get("marks", []):
				# notch / chip dig a small hole around an edge pixel: up to 3 px past the rect (FlawRender)
				if Marks.paint_rect(mark, parts).grow(4).has_point(Vector2i(x, y)):
					inside = true
			t.ok(inside, "%s changed pixel %d,%d lies at a marked part" % [name, x, y])
	FlawRender.clear_cache()


## CardAppraisal._valid_result, restated (five keys, ints, integer measures).
func _valid(r: Dictionary) -> bool:
	if Lib.keys_of(r) != PackedStringArray(Lib.RESULT_KEYS):
		return false
	if typeof(r["quality_permille"]) != TYPE_INT or typeof(r["minutes"]) != TYPE_INT or int(r["minutes"]) < 0:
		return false
	if typeof(r["observations"]) != TYPE_ARRAY or typeof(r["measures"]) != TYPE_DICTIONARY:
		return false
	for key in r["observations"]:
		if typeof(key) != TYPE_STRING:
			return false
	return _ints(r["measures"])


func _ints(v) -> bool:
	if typeof(v) == TYPE_DICTIONARY:
		for c in (v as Dictionary).values():
			if not _ints(c):
				return false
		return true
	if typeof(v) == TYPE_ARRAY:
		for c in v:
			if not _ints(c):
				return false
		return true
	return typeof(v) in [TYPE_INT, TYPE_BOOL]
