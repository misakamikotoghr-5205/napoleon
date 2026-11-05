# C15: same params, same cut and scatter; another seed, another cut; same ops, same result. Random only
# from JevRng in each game's own layout domain (no randi / randf / randomize). Contract 6.3, 12.2.
# Changed 10-25: the decode book is no longer shuffled (it is the real book, sorted), and play goes through
# apply_op instead of the old keyboard shortcuts.
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const H = preload("res://scripts/tests/cards/C15/harness.gd")


func _initialize() -> void:
	var t := T.new(self, "C15_determinism")
	t.run_async(_body.bind(t))


func _body(t) -> void:
	var ticket: Dictionary = H.params("ticket_fake.json")
	var a := H.open_game(self, H.FRAG, ticket)
	var b := H.open_game(self, H.FRAG, ticket)
	await t.frames(1)
	t.eq(a["game"].layout_signature(), b["game"].layout_signature(), "same cut")
	var same_px := true
	for p in range(int(a["game"].layout()["n"])):
		var ia: Image = a["game"].paint_row(p)["img"]
		var ib: Image = b["game"].paint_row(p)["img"]
		if ia.get_data() != ib.get_data():
			same_px = false
	t.ok(same_px, "same pieces, pixel for pixel")
	var other := ticket.duplicate(true)
	other["seed"] = 4197
	var c := H.open_game(self, H.FRAG, other)
	t.ok(a["game"].layout_signature() != c["game"].layout_signature(), "seed changes the cut")
	var box_a := H.take(a["game"])
	var box_b := H.take(b["game"])
	a["game"].autoplay(0.6)
	b["game"].autoplay(0.6)
	t.eq(box_a["r"], box_b["r"], "same autoplay, same result")
	H.close(a)
	H.close(b)
	H.close(c)
	var tele: Dictionary = H.params("chen_code.json")
	var d1 := H.open_game(self, H.DEC, tele)
	var d2 := H.open_game(self, H.DEC, tele)
	await t.frames(1)
	t.eq(d1["game"].book_codes(), d2["game"].book_codes(), "same book")
	t.eq(d1["game"].get("_slips")[1].blot_seed, d2["game"].get("_slips")[1].blot_seed, "same blot")
	var db1 := H.take(d1["game"])
	var db2 := H.take(d2["game"])
	d1["game"].autoplay(0.4)
	d2["game"].autoplay(0.4)
	t.eq(db1["r"], db2["r"], "same decode autoplay")
	H.close(d1)
	H.close(d2)
	_domains(t)


func _domains(t) -> void:
	var files := [
		"res://scripts/cards/minigames/fragments/fragments_game.gd",
		"res://scripts/cards/minigames/fragments/frag_layout.gd",
		"res://scripts/cards/minigames/fragments/frag_piece.gd",
		"res://scripts/cards/minigames/fragments/frag_board.gd",
		"res://scripts/cards/minigames/fragments/frag_lens.gd",
		"res://scripts/cards/minigames/decode/decode_game.gd",
		"res://scripts/cards/minigames/decode/decode_slip.gd",
	]
	for path in files:
		var src := FileAccess.get_file_as_string(path)
		t.ok(src != "", "read " + path)
		t.ok(src.find("randi") < 0, "no randi " + path)
		t.ok(src.find("randf") < 0, "no randf " + path)
		t.ok(src.find("randomize") < 0, "no randomize " + path)
		t.ok(src.find("RandomNumberGenerator") < 0, "no RandomNumberGenerator " + path)
		t.ok(src.find("Time.") < 0, "no clock " + path)
	var frag := FileAccess.get_file_as_string(files[1])
	t.ok(frag.find("c.mg.fragments.layout") >= 0, "fragments domain")
	t.ok(frag.find("c.mg.decode.layout") < 0, "fragments stays on its domain")
	var dec := FileAccess.get_file_as_string(files[5])
	t.ok(dec.find("c.mg.decode.layout") >= 0, "decode domain")
	t.ok(dec.find("c.mg.fragments.layout") < 0, "decode stays on its domain")
