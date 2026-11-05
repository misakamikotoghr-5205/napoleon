# C15: autoplay(skill) reads skill as the chance each judgment is right (DESIGN P8, 7.8, 8.8).
# autoplay(1.0): every call right (all other paper found, seal called right, nothing wrongly crossed; every
# group copied with its real code). autoplay(0.0): no call right. autoplay(0.5): in between over many seeds.
# Scored with the harness judges (the G04 rules), never with anything the game says.
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const H = preload("res://scripts/tests/cards/C15/harness.gd")


func _initialize() -> void:
	var t := T.new(self, "C15_judgment")
	t.run_async(_body.bind(t))


func _body(t) -> void:
	for name in H.FRAG_FIXTURES:
		await _frag(t, str(name))
	await _frag_half(t)
	for name2 in H.DEC_FIXTURES:
		await _dec(t, str(name2))
	await _dec_half(t)


func _frag_run(fix: Dictionary, skill: float) -> Dictionary:
	var ctx := H.open_game(self, H.FRAG, fix)
	var box := H.take(ctx["game"])
	ctx["game"].autoplay(skill)
	var j := H.judge_frag(ctx["game"], box["r"])
	j["result"] = box["r"]
	H.close(ctx)
	return j


func _frag(t, name: String) -> void:
	var fix := H.params(name)
	var hi := _frag_run(fix, 1.0)
	t.ok(bool(hi["all"]), name + " skill 1.0: all calls right " + str(hi))
	t.eq(int(hi["wrong"]), 0, name + " skill 1.0: no wrong call")
	t.eq(int(hi["found"]), int(hi["odd"]), name + " skill 1.0: every piece of other paper found")
	var lo := _frag_run(fix, 0.0)
	t.eq(int(lo["right"]), 0, name + " skill 0.0: nothing found")
	t.eq(int(lo["good"]), 0, name + " skill 0.0: no call right " + str(lo))
	t.eq(int(lo["found"]), 0, name + " skill 0.0: other paper missed")
	await t.frames(1)


## Over many seeds, skill 0.5 gets some calls right and some wrong.
func _frag_half(t) -> void:
	var good := 0
	var chances := 0
	for s in range(16):
		var fix := H.params("ticket_fake.json")
		fix["seed"] = 7000 + s
		var j := _frag_run(fix, 0.5)
		good += int(j["found"]) + (1 if bool(j["seal_ok"]) else 0)
		chances += int(j["chances"])
	var share := float(good) / float(maxi(1, chances))
	print("C15 judgment frag 0.5 share " + str(share))
	t.ok(share > 0.15 and share < 0.85, "fragments skill 0.5 lands between all wrong and all right " + str(share))
	await t.frames(1)


func _dec_run(fix: Dictionary, skill: float) -> Dictionary:
	var ctx := H.open_game(self, H.DEC, fix)
	var box := H.take(ctx["game"])
	ctx["game"].autoplay(skill)
	var j := H.judge_decode(fix["codes"], box["r"])
	H.close(ctx)
	return j


func _dec(t, name: String) -> void:
	var fix := H.params(name)
	var n := (fix["codes"] as Array).size()
	var hi := _dec_run(fix, 1.0)
	t.eq(int(hi["right"]), n, name + " skill 1.0: every group read right")
	t.eq(int(hi["wrong"]), 0, name + " skill 1.0: no wrong reading")
	var lo := _dec_run(fix, 0.0)
	t.eq(int(lo["right"]), 0, name + " skill 0.0: no group read right")
	t.eq(int(lo["wrong"]), n, name + " skill 0.0: every group copied, all wrong (recorded, not refused)")
	await t.frames(1)


func _dec_half(t) -> void:
	var right := 0
	var total := 0
	for s in range(16):
		var fix := H.params("chen_code.json")
		fix["seed"] = 9100 + s
		var j := _dec_run(fix, 0.5)
		right += int(j["right"])
		total += int(j["groups"])
	var share := float(right) / float(maxi(1, total))
	print("C15 judgment decode 0.5 share " + str(share))
	t.ok(share > 0.2 and share < 0.8, "decode skill 0.5 lands between all wrong and all right " + str(share))
	await t.frames(1)
