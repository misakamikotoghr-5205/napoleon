# C15: every input is an op. Game A plays autoplay(x); its ops_log() played into a fresh game B gives the same
# result dict, key by key (observations, measures, minutes, quality). Changing one op changes the result.
# Ops that do not apply change nothing and are not logged. x in 0.0, 0.3, 0.8, 1.0 (DESIGN 3.6, 13).
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const H = preload("res://scripts/tests/cards/C15/harness.gd")
const SKILLS := [0.0, 0.3, 0.8, 1.0]


func _initialize() -> void:
	var t := T.new(self, "C15_replay")
	t.run_async(_body.bind(t))


func _body(t) -> void:
	for name in H.FRAG_FIXTURES:
		await _game(t, H.FRAG, str(name))
	for name2 in H.DEC_FIXTURES:
		await _game(t, H.DEC, str(name2))
	await _frag_changed(t)
	await _dec_changed(t)
	await _rejects(t)


func _game(t, scene: String, name: String) -> void:
	var fix := H.params(name)
	for skill in SKILLS:
		var a := H.open_game(self, scene, fix)
		var box := H.take(a["game"])
		a["game"].autoplay(float(skill))
		var ops: Array = a["game"].ops_log()
		var ra: Dictionary = box["r"]
		H.close(a)
		t.ok(not ops.is_empty() and ops[ops.size() - 1] == ["done"], name + " ends with done at " + str(skill))
		for op in ops:
			t.ok(_plain(op), name + " op is ints and short ascii " + str(op))
		var rb := H.replay(self, scene, fix, ops)
		for k in ["quality_permille", "observations", "minutes", "measures", "aborted"]:
			t.eq(rb.get(k), ra.get(k), name + " replay " + k + " at " + str(skill))
		await t.frames(1)


func _plain(op) -> bool:
	if typeof(op) != TYPE_ARRAY or (op as Array).is_empty() or typeof(op[0]) != TYPE_STRING:
		return false
	var head := str(op[0])
	if head.length() > 8 or not head.is_valid_ascii_identifier():
		return false
	for i in range(1, (op as Array).size()):
		if typeof(op[i]) != TYPE_INT:
			return false
	return true


## Fragments: dropping the seal call or a cross changes what is reported.
func _frag_changed(t) -> void:
	var fix := H.params("ticket_fake.json")
	var a := H.open_game(self, H.FRAG, fix)
	var box := H.take(a["game"])
	a["game"].autoplay(1.0)
	var ops: Array = a["game"].ops_log()
	var base: Dictionary = box["r"]
	H.close(a)
	var changed := false
	var cut_done := false
	for i in range(ops.size()):
		var op: Array = ops[i]
		if str(op[0]) == "seal":
			var alt: Array = ops.duplicate(true)
			alt[i] = ["seal", 3 - int(op[1])]
			var r := H.replay(self, H.FRAG, fix, alt)
			t.ok(r["observations"] != base["observations"], "other seal call, other observation")
			t.ok(r["measures"]["seal_call"] != base["measures"]["seal_call"], "other seal call measured")
			changed = true
		if str(op[0]) == "seam" and not cut_done:
			var cut: Array = ops.duplicate(true)
			cut.remove_at(i)
			var r2 := H.replay(self, H.FRAG, fix, cut)
			t.ok(r2["measures"]["seams"] != base["measures"]["seams"], "one cross fewer is measured")
			cut_done = true
	t.ok(changed, "ticket_fake has a seal call to change")
	t.ok(cut_done, "ticket_fake has a cross to drop")
	await t.frames(1)


## Decode: copying another line into one group changes the reading.
func _dec_changed(t) -> void:
	var fix := H.params("chen_code.json")
	var a := H.open_game(self, H.DEC, fix)
	var box := H.take(a["game"])
	a["game"].autoplay(1.0)
	var ops: Array = a["game"].ops_log()
	var base: Dictionary = box["r"]
	H.close(a)
	for i in range(ops.size()):
		var op: Array = ops[i]
		if str(op[0]) == "pick":
			var alt: Array = ops.duplicate(true)
			alt[i] = ["pick", int(op[1]), int(op[2]) + 1]
			var r := H.replay(self, H.DEC, fix, alt)
			t.ok(r["observations"] != base["observations"], "another line copied, another reading")
			t.ok(r["measures"]["picked"] != base["measures"]["picked"], "picked follows the op")
			break
	await t.frames(1)


func _rejects(t) -> void:
	var f := H.open_game(self, H.FRAG, H.params("ticket_fake.json"))
	var g = f["game"]
	t.eq(g.apply_op(["seam", 0, 1]), false, "no cross before both pieces lie in place")
	t.eq(g.apply_op(["seal", 2]), false, "no seal call before both halves lie in place")
	t.eq(g.apply_op(["rotate", 0, 5]), false, "bad turn refused")
	t.eq(g.apply_op(["move", 99, 0, 0]), false, "unknown piece refused")
	t.eq(g.apply_op(["fly"]), false, "unknown op refused")
	t.eq(g.apply_op(["lens", 0]), false, "lens already off")
	t.eq(g.ops_log(), [], "nothing logged for refused ops")
	var p := int(g.layout()["tray_order"][0])
	while g.piece_rot(p) != 0:
		g.apply_op(["rotate", p, 1])
	var slot: Vector2i = g.layout()["slots"][p]
	t.ok(g.apply_op(["move", p, slot.x + 20, slot.y - 20]), "drop near the slot")
	t.ok(g.is_placed(p), "piece lies in its place")
	t.eq(g.piece_pos(p), slot, "snapped to the slot")
	t.eq(g.apply_op(["move", p, 600, 200]), false, "a piece in place stays there")
	H.close(f)
	var d := H.open_game(self, H.DEC, H.params("chen_code.json"))
	var dg = d["game"]
	t.eq(dg.apply_op(["pick", 0, 5160]), false, "a line not on the open page cannot be copied")
	t.eq(dg.apply_op(["pick", 9, 5101]), false, "no such group")
	t.eq(dg.apply_op(["key", 3]), false, "no key wheel on a plain telegram")
	t.eq(dg.apply_op(["page", 99]), false, "no such page")
	t.eq(dg.ops_log(), [], "nothing logged for refused ops")
	H.close(d)
	await t.frames(1)
