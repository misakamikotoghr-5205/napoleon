# C15 decode (appraisal redesign, DESIGN 8): the real code book sorted by code, seven lines a page, number
# tabs; words from the contract field "word" of codebook.text.json; whatever line the player copies is
# recorded (a wrong one too), nothing is refused or marked; a smudged digit looks the same whichever reading
# is real; with a key, pencil lines take the dialled key off. Contract 4.7.23, 8.1, 8.2.
# Changed 10-25: the old one-word-a-page book (page showed its own code, wrong copies refused) is gone.
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const H = preload("res://scripts/tests/cards/C15/harness.gd")
const Scenario = preload("res://scripts/cards/mock/mock_scenario.gd")


func _initialize() -> void:
	var t := T.new(self, "C15_decode")
	t.run_async(_body.bind(t))


func _body(t) -> void:
	await _book(t)
	await _words(t)
	await _readings(t)
	await _smudge(t)
	await _key(t)
	await _quality_minutes(t)
	await _catalog(t)
	await _abort(t)


func _book(t) -> void:
	var fix := H.params("chen_code.json")
	var rows: Array = fix["book"]
	var ctx := H.open_game(self, H.DEC, fix)
	var g = ctx["game"]
	await t.frames(1)
	t.eq(g.book_codes().size(), rows.size(), "the whole book from params.book")
	var sorted := Array(g.book_codes())
	sorted.sort()
	t.eq(Array(g.book_codes()), sorted, "sorted by code")
	t.eq(g.page_codes().size(), 7, "seven lines a page")
	t.eq(g.page_count(), int(ceil(float(rows.size()) / 7.0)), "pages")
	for code in fix["codes"]:
		t.ok(g.page_of(str(code)) >= 0, "telegram code in the book " + str(code))
		t.eq(g.codebook_key(str(code)), "cb.word." + str(code), "book key " + str(code))
	var tabs: Array = g.tab_rects()
	t.ok(tabs.size() >= 2, "number tabs")
	var spy = t.spy(ctx["bus"])
	var tab_btns: Array = g.get("_tabs")
	var last: Array = tab_btns[tab_btns.size() - 1]
	t.ok(g.apply_op(["page", int(last[1])]), "a tab opens its page")
	var head := (last[0] as Button).text
	var holds := false
	for c in g.page_codes():
		if str(c).begins_with(head):
			holds = true
	t.ok(holds, "the tab's page holds codes starting " + head)
	var saw := false
	for row in spy.ui_events():
		if row[0] == &"mg_tool" and str(row[1].get("tool", "")) == "lookup":
			saw = true
	t.ok(saw, "turning a page emits mg_tool lookup")
	H.close(ctx)
	await t.frames(1)


## Book lines and copied words read the contract field "word" (not "t").
func _words(t) -> void:
	var fix := H.params("chen_code.json")
	var ctx := H.open_game(self, H.DEC, fix)
	var g = ctx["game"]
	await t.frames(1)
	var text = CardDB.read_json("res://data/cards/text_ai/codebook.text.json")
	for code in fix["codes"]:
		var key := "cb.word." + str(code)
		t.eq(g.word_of(str(code)), CardText.card(key, "word"), "word field " + str(code))
		t.ok(g.word_of(str(code)) != "", "word shown " + str(code))
		if typeof(text) == TYPE_DICTIONARY and (text as Dictionary).has(key):
			t.eq(g.word_of(str(code)), str(text[key].get("word", "")), "same as codebook.text.json word " + str(code))
	var first := str(fix["codes"][0])
	g.apply_op(["page", g.page_of(first)])
	var rows: Array = g.get("_rows")
	var line: int = g.page_codes().find(first)
	t.eq((rows[line][2] as Label).text, g.word_of(first), "book line shows the word")
	g.apply_op(["pick", 0, int(first)])
	var slip = g.get("_slips")[0]
	t.eq(slip.get("_word").text, g.word_of(first), "copied word under the group")
	H.close(ctx)
	await t.frames(1)


## A wrong line is copied and reported as the player's reading; blanks report partial.
func _readings(t) -> void:
	var fix := H.params("chen_code.json")
	var ctx := H.open_game(self, H.DEC, fix)
	var g = ctx["game"]
	var codes: Array = fix["codes"]
	var c0 := str(codes[0])
	g.apply_op(["page", g.page_of(c0)])
	var line: int = g.page_codes().find(c0)
	var wrong_code: String = g.page_codes()[line + 1 if line + 1 < 7 else line - 1]
	t.ok(g.apply_op(["pick", 0, int(wrong_code)]), "a wrong line is accepted")
	t.eq(g.picked(0), wrong_code, "as the player's reading")
	t.ok(g.apply_op(["pick", 0, int(c0)]), "copy over it")
	t.ok(g.apply_op(["clear", 0]), "rub it out")
	t.eq(g.picked(0), "", "blank again")
	g.apply_op(["pick", 0, int(wrong_code)])
	var c1 := str(codes[1])
	g.apply_op(["page", g.page_of(c1)])
	g.apply_op(["pick", 1, int(c1)])
	var box := H.take(g)
	g.apply_op(["done"])
	var r: Dictionary = box["r"]
	t.ok((r["observations"] as Array).has("obs.decode." + wrong_code), "wrong reading reported")
	t.ok((r["observations"] as Array).has("obs.decode." + c1), "right reading reported")
	t.ok((r["observations"] as Array).has("obs.decode.partial"), "blank groups: partial")
	t.eq(r["measures"]["decoded"], 2, "two groups copied")
	t.eq(r["measures"]["picked"][0], int(wrong_code), "picked records the wrong code")
	t.eq(r["measures"]["picked"][2], -1, "blank is -1")
	var mkeys: Array = (r["measures"] as Dictionary).keys()
	mkeys.sort()
	t.eq(mkeys, ["decoded", "key", "lookups", "picked"], "measures keys (DESIGN 8.5)")
	t.ok(CardAppraisal._valid_result(r), "engine shape check")
	H.close(ctx)
	await t.frames(1)


## A smudged digit is drawn from the unordered pair: real 5121 read-as 5127, and real 5127 read-as 5121,
## look the same.
func _smudge(t) -> void:
	var a := H.params("chen_code.json")
	var b := a.duplicate(true)
	b["codes"][1] = "5127"
	b["smudges"] = [[1, 3, "5121"], [3, 3, "5117"]]
	var ga = H.open_game(self, H.DEC, a)
	var gb = H.open_game(self, H.DEC, b)
	await t.frames(1)
	var sa = ga["game"].get("_slips")[1]
	var sb = gb["game"].get("_slips")[1]
	t.eq(int(sa.smudge_at), 3, "fourth digit smudged")
	var pa: Array = sa.smudge_pair.duplicate()
	var pb: Array = sb.smudge_pair.duplicate()
	pa.sort()
	pb.sort()
	t.eq(pa, pb, "same two readings drawn")
	t.eq(sa.digits.slice(0, 3), sb.digits.slice(0, 3), "same clear digits")
	t.eq(sa.blot_seed, sb.blot_seed, "same blot")
	H.close(ga)
	H.close(gb)
	await t.frames(1)
	await _smudge_rows(t)


## Contract 8.2: smudges[i] = [g, d, alt] where alt is the whole other code ("5127", the key already taken
## off), as the engine and the mock send it. A bare 0-9 digit (older form) still reads; rows that do not
## fit the group are dropped.
func _smudge_rows(t) -> void:
	var p := H.params("chen_code.json")
	p["smudges"] = [[0, 3, "5128"], [1, 3, 5127], [2, 3, 7], [3, 2, "5117"], [4, 3, "512"], [4, 3, "5108"]]
	var ctx := H.open_game(self, H.DEC, p)
	var g = ctx["game"]
	await t.frames(1)
	var slips: Array = g.get("_slips")
	t.eq(int(slips[0].smudge_at), 3, "engine form [0, 3, \"5128\"] reaches the slip")
	t.eq(slips[0].smudge_pair, [0, 8], "5120 or 5128 under the blot")
	t.eq(int(slips[1].smudge_at), 3, "a code sent as a number reads too")
	t.eq(slips[1].smudge_pair, [1, 7], "5121 or 5127")
	t.eq(int(slips[2].smudge_at), 3, "older digit form still reads")
	t.eq(slips[2].smudge_pair, [1, 7], "5101 or 5107")
	t.eq(int(slips[3].smudge_at), -1, "alt that differs away from the smudged digit: dropped")
	t.eq(int(slips[4].smudge_at), -1, "alt equal to the group or the wrong length: dropped")
	# The mock engine's own decode request (mock_scenario _mg_params), not a copy of it.
	var mock: Dictionary = {"kind": "decode", "seed": 5}
	mock.merge(Scenario.new(ctx["mock"].db, {"seed": 7})._mg_params("decode", ""), true)
	H.close(ctx)
	await t.frames(1)
	var msm: Array = mock.get("smudges", [])
	t.ok(not msm.is_empty(), "the mock decode has a smudge")
	var ctx2 := H.open_game(self, H.DEC, mock)
	var g2 = ctx2["game"]
	await t.frames(1)
	var box := H.take(g2)
	g2.autoplay(0.0)
	for row in msm:
		var mg := int(row[0])
		var md := int(row[1])
		var malt := str(row[2])
		var mcode := str(mock["codes"][mg])
		var s2 = g2.get("_slips")[mg]
		t.eq(int(s2.smudge_at), md, "mock row %s reaches the slip" % str(row))
		t.eq(s2.smudge_pair, [int(mcode.substr(md, 1)), int(malt.substr(md, 1))], "%s or %s under the blot" % [mcode, malt])
		t.eq(box["r"]["measures"]["picked"][mg], int(malt), "a miss on a smudged group copies its other reading")
	H.close(ctx2)
	await t.frames(1)
	var k := H.params("ledger_key.json")
	var ctx3 := H.open_game(self, H.DEC, k)
	var g3 = ctx3["game"]
	await t.frames(1)
	var s3 = g3.get("_slips")[2]
	t.eq(int(s3.smudge_at), 3, "keyed group smudged")
	t.eq(s3.smudge_pair, [7, 2], "5114 / 5119 written with key 3: 7 or 2")
	t.eq(g3._wrong_reading(2, "5114", 3), "5119", "with the right key, the other reading is the other code itself")
	H.close(ctx3)
	await t.frames(1)


func _key(t) -> void:
	var fix := H.params("ledger_key.json")
	var ctx := H.open_game(self, H.DEC, fix)
	var g = ctx["game"]
	await t.frames(1)
	t.ok(g.key_in_use(), "key in use")
	var crib = g.get("_crib_slip")
	t.ok(crib != null, "the book's number group comes first")
	t.eq(crib.digits, [8, 4, 8, 3], "5150 plus key 3")
	var slip = g.get("_slips")[0]
	t.eq(slip.digits, [8, 4, 3, 5], "5102 written with key 3")
	g.apply_op(["key", 2])
	t.eq(slip.pencil_digits, [6, 2, 1, 3], "pencil: shown minus the dialled 2")
	g.apply_op(["key", 3])
	t.eq(slip.pencil_digits, [5, 1, 0, 2], "pencil: shown minus 3 gives the real code")
	var smudged = g.get("_slips")[2]
	t.eq(int(smudged.pencil_digits[3]), -1, "pencil does not guess under the blot")
	H.close(ctx)
	await t.frames(1)


func _quality_minutes(t) -> void:
	var fix := H.params("ledger_key.json")
	var ctx := H.open_game(self, H.DEC, fix)
	var g = ctx["game"]
	g.apply_op(["key", 1])
	g.apply_op(["key", 3])
	t.eq(g.minutes_spent(), 1, "the key wheel: one minute the first time")
	var codes: Array = fix["codes"]
	g.apply_op(["page", g.page_of(str(codes[0]))])
	g.apply_op(["pick", 0, int(str(codes[0]))])
	t.eq(g.minutes_spent(), 2, "a copy: one minute; turning pages: none")
	var box := H.take(g)
	g.apply_op(["done"])
	t.eq(box["r"]["quality_permille"], 333, "one of three: 333")
	H.close(ctx)
	var ctx2 := H.open_game(self, H.DEC, H.params("chen_code.json"))
	var box2 := H.take(ctx2["game"])
	ctx2["game"].autoplay(0.0)
	t.eq(box2["r"]["quality_permille"], 1000, "all copied (even wrongly): full clarity, it only sets the tone")
	H.close(ctx2)
	await t.frames(1)


func _catalog(t) -> void:
	var cat = CardDB.read_json("res://data/cards/minigames/obs/decode.json")
	for row in H.book_rows():
		t.ok((cat["obs"] as Dictionary).has("obs.decode." + str(row[0])), "catalog has " + str(row[0]))
	t.ok((cat["obs"] as Dictionary).has("obs.decode.partial"), "catalog has partial")
	await t.frames(1)


func _abort(t) -> void:
	var ctx := H.open_game(self, H.DEC, H.params("chen_code.json"))
	var g = ctx["game"]
	var c := str(H.params("chen_code.json")["codes"][0])
	g.apply_op(["page", g.page_of(c)])
	g.apply_op(["pick", 0, int(c)])
	var box := H.take(g)
	H.press(g, KEY_ESCAPE)
	t.eq(box["r"]["aborted"], true, "esc aborts")
	t.eq(box["r"]["observations"], [], "esc reports nothing")
	t.eq(box["r"]["minutes"], 1, "abort keeps the minutes spent")
	H.close(ctx)
	await t.frames(1)
