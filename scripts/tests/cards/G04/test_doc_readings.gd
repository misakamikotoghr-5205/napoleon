# G04 鉴定改版：没有客人的文书（当票、信、电报）不结算说破，记 econ.readings[<def id>]；条件 op mg_read；
# 文书的 c.mg.param 键用 "doc:<def id>"（B8）；主线三件文书用真数据出参数（B6：电报只列真码）。
extends SceneTree
const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const S = preload("res://scripts/tests/cards/G04/economy_test_support.gd")
const A = preload("res://scripts/tests/cards/G04/appraisal_support.gd")


func _initialize() -> void:
	var t := T.new(self, "G04_doc_readings")
	_fragments(t)
	_decode(t)
	_decode_checked(t)
	_story_docs(t)
	_shape(t)
	t.finish()


func _read(c: CardCtx, def_id: String, measures: Dictionary, aborted: bool = false) -> Dictionary:
	var uid := S.spawn(c, def_id)
	var req := CardAppraisal.request(c, uid, "")
	var ans: Dictionary = c.state.ns("econ")["appraisals"][uid]["answer"]
	var r := A.result([], measures)
	r["aborted"] = aborted
	CardAppraisal.report(c, uid, "", r)
	return {"req": req, "answer": ans, "reading": CardAppraisal.reading(c, def_id)}


func _fragments(t) -> void:
	var c := A.real_ctx(2)
	var whole := _read(c, "tk.1938.de196", {"placed": 6, "rotations": 0, "seal_checked": true, "seams": [], "seal_call": 1})
	t.eq(str(whole["req"].get("kind", "")), "fragments", "main-line ticket is fragments")
	t.eq(whole["answer"]["odd"], [], "the main-line ticket is sound paper")
	t.eq(bool(whole["answer"]["seal_off"]), false, "the main-line ticket seal is aligned")
	t.eq(whole["reading"], "right", "all placed, nothing wrongly crossed: right")
	t.ok(c.test({"mg_read": ["tk.1938.de196", "right"]}), "mg_read right")
	t.ok(not c.test({"mg_read": ["tk.1938.de196", "wrong"]}), "mg_read is exact")
	t.eq(_read(c, "tk.1938.de196", {"placed": 6, "seams": [[0, 1]], "seal_call": 1})["reading"], "wrong", "crossing a sound seam: wrong")
	t.eq(_read(c, "tk.1938.de196", {"placed": 3, "seams": [], "seal_call": 1})["reading"], "partial", "half pieced: partial")
	t.eq(_read(c, "tk.1938.de196", {"placed": 6, "seams": [], "seal_call": 2})["reading"], "wrong", "calling an aligned seal offset: wrong")
	var before := CardAppraisal.reading(c, "tk.1938.de196")
	_read(c, "tk.1938.de196", {"placed": 0}, true)
	t.eq(CardAppraisal.reading(c, "tk.1938.de196"), before, "an aborted look records no reading")
	t.ok(not c.test({"mg_read": ["nw.1939.brother_torn", "right"]}), "unread document has no reading")
	S.assert_clean(t, c)


func _decode(t) -> void:
	var c := A.real_ctx(2)
	var good := _read(c, "nw.1940.chen_code", {"picked": [5120, 5121, 5101, 5127, 5112], "decoded": 5, "lookups": 9, "key": 0})
	var p: Dictionary = good["req"]["params"]
	t.eq(p["codes"], ["5120", "5121", "5101", "5127", "5112"], "B6: the telegram lists only its own groups, the sign-off last")
	t.eq(good["answer"]["codes"], p["codes"], "decode answer = the true groups")
	t.ok((p["book"] as Array).size() >= 60, "the whole code book travels in params")
	t.ok((p["book"][0] as Array).size() == 2, "book rows are [code, key]")
	t.eq(int(p["key_shift"]), 0, "main-line telegram is plain code")
	t.eq((p["smudges"] as Array).size(), 1, "smudges 2 minus eye 2 / 2 = one smudge at the start")
	var sm: Array = p["smudges"][0]
	var book := {}
	for row in p["book"]:
		book[str(row[0])] = true
	t.ok(book.has(str(sm[2])), "the smudged digit reads as another real entry")
	t.ok(str(sm[2]) != str(p["codes"][int(sm[0])]), "the other reading differs from the true group")
	t.eq(good["reading"], "right", "every group right: right")
	var misread: Array = [5120, 5121, 5101, 5127, 5112]
	misread[int(sm[0])] = int(str(sm[2]))
	t.eq(_read(c, "nw.1940.chen_code", {"picked": misread})["reading"], "wrong", "the smudge read the other way: wrong")
	t.eq(_read(c, "nw.1940.chen_code", {"picked": [5120, -1, -1, -1, -1]})["reading"], "partial", "only some groups: partial")
	t.eq(_read(c, "nw.1940.chen_code", {"decoded": 5, "lookups": 9})["reading"], "partial", "old decode measures: partial, no error")


## Acceptance fix2 (10-25): a smudge on the main-line telegram may only be read the other way as one of the
## readings its writer checked to make no sense there (decode.smudge_alts). The ones a careful player could not
## see through (5170 hang-bu, a real-sounding place; 5171; 5122 "east"; 5172 "after"; 5117 "tonight", which
## reads better than the truth) never come up, at any eye, on any run. Off the list only a code missing from
## the book can stand in (it reads as nothing). Without a list the old choice is unchanged.
func _decode_checked(t) -> void:
	var c0 := A.real_ctx(2)
	var d := c0.db.def("nw.1940.chen_code")
	var spec: Dictionary = d.get("decode", {})
	var checked: Array = []
	for a in spec.get("smudge_alts", []):
		checked.append(str(a))
	t.ok(checked.size() >= 2, "the telegram lists its checked other readings")
	for bad in ["5170", "5171", "5122", "5172", "5117"]:
		t.ok(not checked.has(bad), "a reading that makes sense is not on the list: " + bad)
	var codes: Array = []
	for code in spec.get("codes", []):
		codes.append(str(code))
	var in_book := {}
	for row in CardAppraisal._codebook(c0)["rows"]:
		in_book[str(row[0])] = true
	var groups := {}
	for a2 in checked:
		t.ok(in_book.has(a2), "a checked reading is a real book entry " + a2)
		var fits := false
		for g in range(codes.size()):
			var code := str(codes[g])
			for at in range(code.length()):
				var same_rest: bool = code.substr(0, at) + code.substr(at + 1) == a2.substr(0, at) + a2.substr(at + 1)
				if same_rest and (CardAppraisal.CONFUSABLE.get(code[at], []) as Array).has(a2[at]):
					fits = true
					groups[g] = true
		t.ok(fits, "a checked reading is one confusable digit away from a group " + a2)
	t.ok(groups.size() >= 2, "checked readings sit on at least two groups (two smudges at eye 0-1)")
	var seen := {}
	for seed in range(1, 41):
		var c := A.real_ctx(seed)
		for extra in [0, 1, 2]:
			var dd := d.duplicate(true)
			dd["decode"]["smudges"] = int(spec.get("smudges", 1)) - 1 + extra
			var p := CardAppraisal.doc_params(c, dd, &"decode")
			var used := {}
			for sm in p["smudges"]:
				var alt := str(sm[2])
				seen[alt] = true
				t.ok(checked.has(alt), "seed %d: the other reading %s is a checked one" % [seed, alt])
				t.ok(not used.has(int(sm[0])), "one smudge per group")
				used[int(sm[0])] = true
		for want in range(1, 7):
			for sm2 in CardAppraisal._smudges(c, "doc:probe%d" % seed, codes, in_book, 0, want, checked):
				var alt2 := str(sm2[2])
				t.ok(checked.has(alt2) or not in_book.has(alt2), "want %d: %s is checked or not in the book" % [want, alt2])
				if want <= groups.size():
					t.ok(checked.has(alt2), "while checked ones last, only checked ones (%s)" % alt2)
	t.eq(seen.size(), checked.size(), "every checked reading comes up across runs")
	var free_alts := {}
	for seed2 in range(1, 41):
		for sm3 in CardAppraisal._smudges(A.real_ctx(seed2), "doc:free", codes, in_book, 0, 2, []):
			free_alts[str(sm3[2])] = true
	t.ok(free_alts.has("5170") or free_alts.has("5117") or free_alts.has("5172"), "without a list the old choice stands")


func _story_docs(t) -> void:
	var c := A.real_ctx(8)
	var seeds := {}
	for def_id in ["tk.1938.de196", "nw.1939.brother_torn", "nw.1940.chen_code", "tk.test.foreign"]:
		var d := c.db.def(def_id)
		var p := CardAppraisal.doc_params(c, d, StringName(str(d.get("minigame", ""))))
		t.ok(not S.forbidden(p), "%s params have no forbidden keys" % def_id)
		t.eq(CardAppraisal.doc_params(c, d, StringName(str(d.get("minigame", "")))), p, "%s params deterministic" % def_id)
		t.ok(not seeds.has(int(p["seed"])), "B8: %s has its own layout seed" % def_id)
		seeds[int(p["seed"])] = def_id
	var letter := CardAppraisal.doc_params(c, c.db.def("nw.1939.brother_torn"), &"fragments")
	t.eq(int(letter["pieces"]), 5, "brother's letter: five pieces")
	t.eq(int(letter["dangzi_marks"]), 0, "a letter has no pawn marks")
	var ticket := CardAppraisal.doc_params(c, c.db.def("tk.1938.de196"), &"fragments")
	t.eq([int(ticket["pieces"]), int(ticket["dangzi_marks"]), int(ticket["seal_offset_px"])], [6, 3, 0], "ticket 196 spec")


func _shape(t) -> void:
	t.eq(CardDslShapes.cond_param_error(&"mg_read", ["tk.1938.de196", "right"]), "", "mg_read shape ok")
	t.ok(CardDslShapes.cond_param_error(&"mg_read", ["tk.1938.de196", "maybe"]) != "", "mg_read rejects unknown readings")
	t.ok(CardDslShapes.cond_param_error(&"mg_read", "tk.1938.de196") != "", "mg_read needs [card, reading]")
	t.eq(CardDslShapes.COND_OPS[&"mg_read"], "G04", "mg_read is G04's")
