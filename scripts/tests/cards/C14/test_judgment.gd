# C14 (DESIGN 13 test_judgment): the observation handed back is the player's call, right or wrong, never
# filtered. autoplay(1.0) calls every fixture right (by this test's own answer rule), autoplay(0.0) calls every
# one wrong (the neighbouring category), autoplay(0.5) lands in between over many seeds. G04's scoring of the
# calls (right / soft / wrong, DESIGN 6.5) is checked on the fixtures. small_fen from the params wins over the
# fallback (claim * 60 / 1000).
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const Fix = preload("res://scripts/tests/cards/C14/weigh_fix.gd")

var fix


func _initialize() -> void:
	var t := T.new(self, "C14_judgment")
	t.run_async(_body.bind(t))


func _body(t) -> void:
	fix = Fix.new()
	fix.setup_text()
	var cats := {}
	for name in Fix.FIXTURES:
		var pars: Dictionary = fix.params(name)
		var cat: String = fix.answer(pars)
		cats[cat] = true
		t.eq(cat, str(Fix.EXPECT[name]), name + " answer rule")
		var hi: Dictionary = fix.run_skill(self, pars, 1.0)
		var lo: Dictionary = fix.run_skill(self, pars, 0.0)
		t.eq(fix.call_of(hi), cat, name + " skill 1.0 calls it right")
		t.ok(fix.call_of(lo) != cat and fix.call_of(lo) != "", name + " skill 0.0 calls it wrong: " + fix.call_of(lo))
		t.eq(int(hi["measures"]["call"]), Fix.CALLS.find(cat), name + " measures.call is the pick")
		await t.frames(1)
	t.ok(cats.size() == 4, "fixtures cover all four categories")
	# Scoring as G04 will (DESIGN 6.5).
	t.eq(fix.judge("light_much", "light_much"), "right", "light_much caught")
	t.eq(fix.judge("heavy", "heavy"), "right", "heavy caught")
	t.eq(fix.judge("light_small", "light_small"), "soft", "a little light is soft")
	t.eq(fix.judge("match", "light_much"), "wrong", "accusing a true weight is wrong")
	t.eq(fix.judge("light_small", "heavy"), "wrong", "accusing a worn piece is wrong")
	t.eq(fix.judge("light_much", "match"), "", "missing it is not wrong (you fooled yourself)")
	# Skill 0.5 over many seeds: some right, some wrong.
	var right := 0
	var total := 0
	for k in 24:
		var p: Dictionary = fix.params(Fix.FIXTURES[k % 4])
		p["seed"] = 15000 + k * 7
		var r: Dictionary = fix.run_skill(self, p, 0.5)
		total += 1
		if fix.call_of(r) == fix.answer(p):
			right += 1
		if k % 6 == 5:
			await t.frames(1)
	t.ok(right > 0 and right < total, "skill 0.5 is in between (%d of %d right)" % [right, total])
	# small_fen from the params decides "a little": 12 fen light is a little at 18, a lot at 10.
	var ls: Dictionary = fix.params("light_small")
	t.eq(fix.answer(ls), "light_small", "fallback small_fen 18: light_small")
	ls["small_fen"] = 10
	t.eq(fix.answer(ls), "light_much", "small_fen 10: light_much")
	t.eq(fix.call_of(fix.run_skill(self, ls, 1.0)), "light_much", "the game uses small_fen from the params")
	await _rule_on_screen(t)
	# The call is never filtered: a wrong call on a level, clear read comes back as is.
	var g = fix.open(self, fix.params("match"))
	await t.frames(1)
	var box := {"r": {}}
	g.finished.connect(func(r: Dictionary) -> void: box["r"] = r)
	fix.level_ops(g)
	g.apply_op(["commit"])
	g.apply_op(["call", 3])
	g.apply_op(["done"])
	t.eq(box["r"]["observations"], ["obs.weigh.light_much"], "a wrong call is handed back unchanged")
	t.eq(int(box["r"]["quality_permille"]), 1000, "and it is a clear read")
	g.queue_free()
	await t.frames(1)


## A perfect reading must not end in a guess: the rule that splits the calls (one step either way matches; light
## by up to small_fen is "a little") is on screen, in the same units as the claim and the weight faces.
## Hairpin, claim 300, read 288 = 12 fen light: "a little" at small_fen 18, "a lot" at 10; the screen says which.
func _rule_on_screen(t) -> void:
	var u := func(key: String, args: Dictionary) -> String: return CardText.ui(key, args)
	var pars: Dictionary = fix.params("light_small")
	var g = fix.open(self, pars)
	await t.frames(1)
	var claim := g.get_node("Panel/Claimed") as Label
	t.eq(claim.text, u.call("c14.claimed", {"w": u.call("c14.weight.face_liang", {"liang": 3})}), "claim in liang: 3 liang")
	var faces := PackedStringArray()
	for b in g._weight_btns:
		faces.append((b as Button).text)
	t.eq(faces, PackedStringArray([u.call("c14.weight.face_liang", {"liang": 2}), u.call("c14.weight.face_liang", {"liang": 1}),
		u.call("c14.weight.face_qian", {"qian": 5}), u.call("c14.weight.face_qian", {"qian": 2}),
		u.call("c14.weight.face_qian", {"qian": 1})]), "faces in the claim's units")
	# One scheme for every weight: zero parts left out.
	var cases := [[288, "c14.weight.face_lqf", {"liang": 2, "qian": 8, "fen": 8}], [18, "c14.weight.face", {"qian": 1, "fen": 8}],
		[105, "c14.weight.face_lf", {"liang": 1, "fen": 5}], [150, "c14.weight.face_lq", {"liang": 1, "qian": 5}],
		[1005, "c14.weight.face_lf", {"liang": 10, "fen": 5}], [5650, "c14.weight.face_lq", {"liang": 56, "qian": 5}],
		[2, "c14.weight.face_fen", {"fen": 2}], [0, "c14.weight.face_fen", {"fen": 0}]]
	for c in cases:
		t.eq(g._wt(int(c[0])), u.call(str(c[1]), c[2]), "weight %d written in one scheme" % int(c[0]))
	var rm := g.get_node_or_null("Panel/RuleMatch") as Label
	var rs := g.get_node_or_null("Panel/RuleSmall") as Label
	t.ok(rm != null and rs != null, "both rule lines on screen")
	if rm != null and rs != null:
		t.eq(rm.text, u.call("c14.rule.match", {"w": u.call("c14.weight.face_fen", {"fen": 2})}), "one step either way matches")
		t.eq(rs.text, u.call("c14.rule.small", {"w": u.call("c14.weight.face", {"qian": 1, "fen": 8})}), "a little = up to 1 qian 8 fen")
		var claim_end := claim.position.x + _text_w(claim)
		for l in [rm, rs]:
			t.ok(l.is_visible_in_tree(), str(l.name) + " visible")
			var w := _text_w(l)
			t.ok(w <= l.size.x, str(l.name) + " fits its line (%d of %d px)" % [int(w), int(l.size.x)])
			t.ok(Rect2(Vector2.ZERO, (g.get_node("Panel") as Control).size).encloses(Rect2(l.position, l.size)), str(l.name) + " inside the panel")
			t.ok(l.position.x + l.size.x - w > claim_end + 8.0, str(l.name) + " clear of the claim")
	g.queue_free()
	await t.frames(1)
	pars["small_fen"] = 10
	g = fix.open(self, pars)
	await t.frames(1)
	rs = g.get_node_or_null("Panel/RuleSmall") as Label
	t.ok(rs != null and rs.text == u.call("c14.rule.small", {"w": u.call("c14.weight.face_qian", {"qian": 1})}),
		"small_fen 10: a little = up to 1 qian, so 12 fen light reads as a lot")
	g.queue_free()
	await t.frames(1)
	pars["small_fen"] = 2
	g = fix.open(self, pars)
	await t.frames(1)
	t.ok(g.get_node_or_null("Panel/RuleSmall") == null, "no 'a little' band (small_fen = one step): no small line")
	g.queue_free()
	await t.frames(1)
	var rice = fix.open(self, fix.params("steelyard_rice"))
	await t.frames(1)
	t.eq((rice.get_node("Panel/Claimed") as Label).text, u.call("c14.claimed", {"w": u.call("c14.weight.face_liang", {"liang": 16})}),
		"steelyard claim in the same scheme")
	rice.queue_free()
	await t.frames(1)


func _text_w(l: Label) -> float:
	return l.get_theme_font("font").get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, l.get_theme_font_size("font_size")).x
