# C15: the three story documents with real data (DESIGN 14 WP5 acceptance): the 196 pawn ticket
# (tk.1938.de196) and the torn letter (nw.1939.brother_torn) through fragments, the telegram
# (nw.1940.chen_code) through decode. Params come from G04 (params_for + the document's own block), so this
# follows whatever the engine and the K data give: older engines and data without the new fields still play.
# Each plays at skill 1.0 (every call right by the test's judge) and 0.0 (none right), results pass the
# engine's shape check, and every reported key is in the real catalog.
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const H = preload("res://scripts/tests/cards/C15/harness.gd")
const DOCS := [["tk.1938.de196", "fragments"], ["nw.1939.brother_torn", "fragments"], ["nw.1940.chen_code", "decode"]]


func _initialize() -> void:
	var t := T.new(self, "C15_mainline")
	t.run_async(_body.bind(t))


func _body(t) -> void:
	var eng := CardEngine.new()
	var boot: Dictionary = eng.new_game({"seed": 7, "only_examples": false, "save_dir": t.user_dir()})
	t.ok(bool(boot.get("ok", false)), "new_game")
	if not bool(boot.get("ok", false)):
		return
	for row in DOCS:
		await _doc(t, eng, str(row[0]), str(row[1]))
	await _telegram_smudge(t, eng)


## The engine's smudges ([g, d, alt], alt = the whole other code) reach the telegram: the blot is drawn over
## both readings, and a miss on that group copies the other reading.
func _telegram_smudge(t, eng: CardEngine) -> void:
	var d: Dictionary = eng.ctx.db.def("nw.1940.chen_code")
	if d.is_empty():
		return
	var params := CardAppraisal.doc_params(eng.ctx, d, &"decode")
	var sms: Array = params.get("smudges", [])
	t.ok(sms.size() > 0, "the main-line telegram has a smudged digit at the starting eye")
	var ctx := H.open_game(self, H.DEC, params)
	var g = ctx["game"]
	await t.frames(1)
	var slips: Array = g.get("_slips")
	var shift := int(params.get("key_shift", 0))
	var drawn := 0
	for sm in sms:
		var gi := int(sm[0])
		var at := int(sm[1])
		if gi >= slips.size():
			continue
		var code := str(params["codes"][gi])
		var alt := str(sm[2])
		var slip = slips[gi]
		t.eq(int(slip.smudge_at), at, "group %d smudged at digit %d" % [gi, at])
		t.eq(slip.smudge_pair, [posmod(int(code.substr(at, 1)) + shift, 10), posmod(int(alt.substr(at, 1)) + shift, 10)],
			"group %d shows both readings %s / %s" % [gi, code, alt])
		if int(slip.smudge_at) >= 0 and (slip.smudge_pair as Array).size() == 2:
			drawn += 1
	t.eq(drawn, sms.size(), "every engine smudge drawn on the telegram")
	var box := H.take(g)
	g.autoplay(0.0)
	var picked: Array = box["r"]["measures"]["picked"]
	for sm2 in sms:
		if shift == 0 and int(sm2[0]) < picked.size() and g.page_of(str(sm2[2])) >= 0:
			t.eq(int(picked[int(sm2[0])]), int(str(sm2[2])), "a miss on the smudged group copies its other reading")
	H.close(ctx)
	await t.frames(1)


func _doc(t, eng: CardEngine, def_id: String, kind: String) -> void:
	var d: Dictionary = eng.ctx.db.def(def_id)
	t.ok(not d.is_empty(), def_id + " in the real data")
	if d.is_empty():
		return
	t.eq(str(d.get("minigame", "")), kind, def_id + " plays " + kind)
	var params := CardAppraisal.params_for(eng.ctx, "", StringName(kind))
	params = CardAppraisal._document(eng.ctx, params, d)
	for k in params.keys():
		t.ok(not CardAppraisal.FORBIDDEN_PARAM_KEYS.has(str(k)), def_id + " no forbidden param " + str(k))
	var scene := H.FRAG if kind == "fragments" else H.DEC
	var catalog: Dictionary = eng.ctx.db.obs_catalog(StringName(kind))
	if kind == "decode" and (params.get("codes", []) as Array).size() > 12:
		print("C15 NOTE: " + def_id + " has no codes of its own yet (B6, WP1 data); the sheet shows the first 12")
	for skill in [1.0, 0.0]:
		var ctx := H.open_game(self, scene, params)
		var g = ctx["game"]
		await t.frames(1)
		var box := H.take(g)
		g.autoplay(float(skill))
		var r: Dictionary = box["r"]
		var label := def_id + " at " + str(skill)
		t.eq(r.get("aborted", true), false, label + " plays through")
		t.ok(CardAppraisal._valid_result(r), label + " result shape")
		for key in r.get("observations", []):
			t.ok(catalog.has(str(key)), label + " reports a catalog key " + str(key))
		if kind == "fragments":
			var j := H.judge_frag(g, r)
			if skill == 1.0:
				t.ok(bool(j["all"]), label + " every call right " + str(j))
			else:
				t.eq(int(j["good"]), 0, label + " no call right " + str(j))
		else:
			var shown := int(g.group_count())
			var j2 := H.judge_decode((params["codes"] as Array).slice(0, shown), r)
			if skill == 1.0:
				t.eq(int(j2["right"]), shown, label + " every group read right")
			else:
				t.eq(int(j2["right"]), 0, label + " no group read right")
		H.close(ctx)
		await t.frames(1)
