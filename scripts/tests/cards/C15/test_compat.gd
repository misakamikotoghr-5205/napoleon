# C15: params from before the appraisal redesign still open and play to the end (DESIGN P9): the mock's
# _mg_params, the older fixtures, and bare minimal dicts. Missing stain / rotate / lens_px / backlight /
# book / smudges / key_shift fall back to defaults (no stain, turned pieces, a 72 px glass, no light; the
# code book file; no smudges; no key).
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const H = preload("res://scripts/tests/cards/C15/harness.gd")
const Scenario = preload("res://scripts/cards/mock/mock_scenario.gd")

const OLD_FRAG := {"kind": "fragments", "seed": 12345, "item": "", "art": "", "minutes_per_step": 1,
	"max_minutes": 30, "doc": "pawn_ticket", "pieces": 6, "seal_offset_px": 2, "ink_mismatch": [],
	"dangzi_marks": 3, "missing_piece": -1}
const OLD_DEC := {"kind": "decode", "seed": 54321, "item": "", "art": "", "minutes_per_step": 1,
	"max_minutes": 30, "cipher": "telegraph", "message": "", "codes": ["0417", "2201"],
	"book_words": ["cb.word.0417", "cb.word.2201"]}


func _initialize() -> void:
	var t := T.new(self, "C15_compat")
	t.run_async(_body.bind(t))


func _body(t) -> void:
	var cases: Array = []
	cases.append(["old fragments", H.FRAG, OLD_FRAG])
	cases.append(["old decode", H.DEC, OLD_DEC])
	cases.append(["bare fragments", H.FRAG, {"kind": "fragments", "seed": 1, "pieces": 4}])
	cases.append(["bare decode", H.DEC, {"kind": "decode", "seed": 2, "codes": ["5101"]}])
	cases.append(["one piece", H.FRAG, {"kind": "fragments", "seed": 3, "pieces": 1}])
	cases.append(["no pieces", H.FRAG, {"kind": "fragments", "seed": 4, "pieces": 0}])
	cases.append(["no codes", H.DEC, {"kind": "decode", "seed": 5}])
	for name in ["ticket196.json", "letter_missing.json", "scroll.json", "telegram.json", "ledger.json"]:
		cases.append([name, H.FRAG if str(name).find("tele") < 0 and str(name).find("ledger") < 0 else H.DEC, H.params(str(name))])
	var mock_ctx := H.open_game(self, H.DEC, OLD_DEC)
	var scn = Scenario.new(mock_ctx["mock"].db, {"seed": 7})
	for kind in ["fragments", "decode"]:
		var p: Dictionary = {"kind": kind, "seed": 99, "item": "", "art": "", "minutes_per_step": 1, "max_minutes": 30}
		p.merge(scn._mg_params(kind, ""), true)
		cases.append(["mock " + kind, H.FRAG if kind == "fragments" else H.DEC, p])
	H.close(mock_ctx)
	for c in cases:
		await _play(t, str(c[0]), str(c[1]), c[2])
	await _defaults(t)


func _play(t, label: String, scene: String, fix: Dictionary) -> void:
	for skill in [1.0, 0.0]:
		var ctx := H.open_game(self, scene, fix)
		var g = ctx["game"]
		await t.frames(1)
		var box := H.take(g)
		g.autoplay(float(skill))
		var r: Dictionary = box["r"]
		t.eq(r.get("aborted", true), false, label + " plays to the end at " + str(skill))
		t.eq(typeof(r.get("quality_permille")), TYPE_INT, label + " quality int")
		t.eq(typeof(r.get("minutes")), TYPE_INT, label + " minutes int")
		t.ok(not (r.get("observations", []) as Array).is_empty(), label + " has observations")
		t.ok(CardAppraisal._valid_result(r), label + " result passes the engine's shape check")
		H.close(ctx)
		await t.frames(1)


func _defaults(t) -> void:
	var ctx := H.open_game(self, H.FRAG, OLD_FRAG)
	var g = ctx["game"]
	t.eq(g.tool_button("light"), null, "no backlight button without the aid")
	t.eq(g.apply_op(["light", 1]), false, "no light without the aid")
	t.eq((g.layout()["stain"] as Dictionary).is_empty(), true, "no stain without params.stain")
	var turned := 0
	for p in range(int(g.layout()["n"])):
		turned += 1 if g.piece_rot(p) != 0 else 0
	t.ok(turned > 0, "pieces lie turned when params.rotate is missing (old behaviour)")
	t.eq(int(g.get("_lens_px")), 72, "default glass")
	H.close(ctx)
	var flat := OLD_FRAG.duplicate(true)
	flat["rotate"] = false
	var ctx2 := H.open_game(self, H.FRAG, flat)
	for p2 in range(int(ctx2["game"].layout()["n"])):
		t.eq(ctx2["game"].piece_rot(p2), 0, "rotate false: piece " + str(p2) + " lies straight")
	H.close(ctx2)
	var dec := H.open_game(self, H.DEC, H.params("telegram.json"))
	t.ok(dec["game"].book_codes().size() >= 40, "no params.book: the whole code book file, not the telegram's own words")
	var codes: PackedStringArray = dec["game"].book_codes()
	var sorted := Array(codes)
	sorted.sort()
	t.eq(Array(codes), sorted, "the book is sorted by code")
	t.eq(dec["game"].page_codes().size(), 7, "seven lines a page")
	t.eq(dec["game"].key_in_use(), false, "no key without key_shift")
	H.close(dec)
	await t.frames(1)
