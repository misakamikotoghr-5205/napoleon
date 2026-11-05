# C15 decode, acceptance fix2 (10-25, "the player must see it for it to count"): what a careful eye can use.
# - Every smudge draws as its own look: each confusable pair has its own window, the blot never leaves it, and
#   with the whole window inked each reading still shows a part of its own strokes (pixels rasterised from the
#   real body font at the slip's own geometry; 0/8 used to read as a plain 0). The stain over the digit changes
#   many pixels against either clean reading (never invisible), and the drawing is the same pixel for pixel
#   whichever reading is real (never a glance giveaway).
# - The legend on the sheet lists exactly the engine's confusable pairs (never contradicts what can happen).
# - Rule lines stay on screen under the sheet: how to copy, what a blot means, the pairs, the key; they hold no
#   word of this sheet's answer, fit the space and keep clear of the buttons.
# - The real telegram nw.1940.chen_code: every smudge the engine draws, at any eye, offers only a reading that
#   makes no sense there (decode.smudge_alts), and the sign-off comes last as its dossier fragment says.
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const H = preload("res://scripts/tests/cards/C15/harness.gd")
const SlipSc = preload("res://scripts/cards/minigames/decode/decode_slip.gd")
const GameSc = preload("res://scripts/cards/minigames/decode/decode_game.gd")
## Readings that make sense in the main-line telegram (5170 hang-bu, 5171, 5122 "east", 5172, 5117 "tonight").
const SENSIBLE := ["5170", "5171", "5122", "5172", "5117"]


func _initialize() -> void:
	var t := T.new(self, "C15_decode_eye")
	t.run_async(_body.bind(t))


func _body(t) -> void:
	_legend(t)
	for compact in [false, true]:
		for pr in SlipSc.PAIRS:
			_pair_pixels(t, int(pr[0]), int(pr[1]), compact)
	await _rules(t)
	await _real_telegram(t)


## The legend is the engine's table: the same unordered pairs, each with its own window.
func _legend(t) -> void:
	var engine := {}
	for a in CardAppraisal.CONFUSABLE.keys():
		for b in CardAppraisal.CONFUSABLE[a]:
			var lo := mini(int(a), int(b))
			var hi := maxi(int(a), int(b))
			engine["%d/%d" % [lo, hi]] = true
	var shown := {}
	for pr in SlipSc.PAIRS:
		var lo2 := mini(int(pr[0]), int(pr[1]))
		var hi2 := maxi(int(pr[0]), int(pr[1]))
		shown["%d/%d" % [lo2, hi2]] = true
		t.ok(SlipSc.has_own_mask(pr), "pair %s has its own window" % str(pr))
	var ek: Array = engine.keys()
	var sk: Array = shown.keys()
	ek.sort()
	sk.sort()
	t.eq(sk, ek, "legend pairs = engine confusable pairs")
	var text: String = GameSc.pairs_text()
	for pr2 in SlipSc.PAIRS:
		t.ok(text.find("%d/%d" % [int(pr2[0]), int(pr2[1])]) >= 0, "legend text lists " + str(pr2))
	var windows := {}
	for pr3 in SlipSc.PAIRS:
		windows[str(SlipSc._mask_rect(pr3))] = true
	t.ok(windows.size() >= 5, "pairs draw in their own windows, not one shared box")


## Coverage (0..1) of digit v drawn the way the slip draws it (draw_string, centred in the digit box), on a
## grid of w x h slip pixels.
func _coverage(slip, d: int, v: int, w: int, h: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(w * h)
	var font: Font = CardTheme.font_body()
	var fs: int = slip.digit_size()
	var ts := TextServerManager.get_primary_interface()
	var rid: RID = font.get_rids()[0]
	var size := Vector2i(fs, 0)
	var gi := ts.font_get_glyph_index(rid, fs, str(v).unicode_at(0), 0)
	ts.font_render_glyph(rid, size, gi)
	var img: Image = ts.font_get_texture_image(rid, size, ts.font_get_glyph_texture_idx(rid, size, gi))
	var uv := Rect2i(ts.font_get_glyph_uv_rect(rid, size, gi))
	var off := ts.font_get_glyph_offset(rid, size, gi)
	var adv := ts.font_get_glyph_advance(rid, fs, gi).x
	var at: Vector2 = slip.digit_at(d)
	var pen := Vector2(at.x + floorf((float(fs) - adv) * 0.5), at.y + float(fs) * 0.95)
	var o := Vector2i((pen + off).round())
	for y in range(uv.size.y):
		for x in range(uv.size.x):
			var px := o.x + x
			var py := o.y + y
			if px >= 0 and py >= 0 and px < w and py < h:
				out[py * w + px] = img.get_pixel(uv.position.x + x, uv.position.y + y).a
	return out


func _inside(rects: Array, p: Vector2) -> bool:
	for r in rects:
		if (r as Rect2).has_point(p):
			return true
	return false


## The ink a pixel shows (0 paper .. 1 ink): stain, both faint readings, the blot, layered as the slip draws.
func _shade(slip, ca: PackedFloat32Array, cb: PackedFloat32Array, i: int, p: Vector2) -> float:
	var keep := 1.0
	for wr in slip.wash_rects():
		if (wr as Rect2).has_point(p):
			keep *= 1.0 - SlipSc.WASH_ALPHA
	keep *= 1.0 - SlipSc.FAINT_ALPHA * ca[i]
	keep *= 1.0 - SlipSc.FAINT_ALPHA * cb[i]
	for br in slip.blot_rects():
		if (br as Rect2).has_point(p):
			keep *= 1.0 - SlipSc.BLOT_ALPHA
	return 1.0 - keep


func _slip(a: int, b: int, compact: bool, seed_v: int):
	var slip = SlipSc.new()
	slip.compact = compact
	slip.size = Vector2(148, 84) if compact else Vector2(224, 112)
	slip.digits = [5, 1, 0, a]
	slip.smudge_at = 3
	slip.smudge_pair = [a, b]
	var seeds: Array = []
	for i in range(5):
		seeds.append([JevRng.draw(seed_v, "c.mg.decode.layout", [5000 + 30 + i]), JevRng.draw(seed_v, "c.mg.decode.layout", [5500 + 30 + i])])
	slip.blot_seed = seeds
	return slip


func _pair_pixels(t, a: int, b: int, compact: bool) -> void:
	var label := "%d/%d %s" % [a, b, "compact" if compact else "full"]
	var probe = _slip(a, b, compact, 1)
	var w := int(probe.size.x)
	var h := int(probe.size.y)
	var ca := _coverage(probe, 3, a, w, h)
	var cb := _coverage(probe, 3, b, w, h)
	var window: Rect2 = probe.blot_window()
	t.ok(window.size.x >= 4.0 and window.size.y >= 4.0, label + " the blot window is a real patch " + str(window))
	# The blot stays in its window on every layout seed; with the whole window inked, each reading keeps a
	# part of its own strokes in sight (a pixel is a reading's own when it is inked there and the other is not).
	var inside := true
	for s in range(1, 25):
		var sl = _slip(a, b, compact, s)
		for r in sl.blot_rects():
			if not window.encloses(r as Rect2):
				inside = false
		sl.free()
	t.ok(inside, label + " the blot never leaves its window")
	probe.free()
	var own := [0, 0]
	var seen := [0, 0]
	for y in range(h):
		for x in range(w):
			var i := y * w + x
			var hidden := window.has_point(Vector2(x + 0.5, y + 0.5))
			if ca[i] >= 0.5 and cb[i] < 0.25:
				own[0] += 1
				if not hidden:
					seen[0] += 1
			if cb[i] >= 0.5 and ca[i] < 0.25:
				own[1] += 1
				if not hidden:
					seen[1] += 1
	print("C15 eye %s: own strokes in sight %d/%d and %d/%d, window %s" % [label, seen[0], own[0], seen[1], own[1], str(window)])
	var need := 6 if compact else 8
	for k in range(2):
		var v := a if k == 0 else b
		var want := mini(need, int(ceil(float(own[k]) * 0.5)))
		t.ok(seen[k] >= want and seen[k] * 4 >= own[k],
			label + " reading %d shows %d of its own %d pixels (need %d and a quarter)" % [v, seen[k], own[k], want])
	# Never invisible: the smudged digit differs from either clean reading in many pixels. Never a giveaway:
	# the same pixels whichever reading is the real one.
	var s1 = _slip(a, b, compact, 7)
	var s2 = _slip(b, a, compact, 7)
	t.eq(s1.blot_rects(), s2.blot_rects(), label + " same blot either way round")
	t.eq(s1.wash_rects(), s2.wash_rects(), label + " same stain either way round")
	var diff_a := 0
	var diff_b := 0
	var same := true
	for y2 in range(h):
		for x2 in range(w):
			var i2 := y2 * w + x2
			var p := Vector2(x2 + 0.5, y2 + 0.5)
			var v1: float = _shade(s1, ca, cb, i2, p)
			var v2: float = _shade(s2, cb, ca, i2, p)
			if absf(v1 - v2) > 0.001:
				same = false
			if absf(v1 - ca[i2]) > 0.1:
				diff_a += 1
			if absf(v1 - cb[i2]) > 0.1:
				diff_b += 1
	t.ok(same, label + " the drawn smudge is identical whichever reading is real")
	var min_diff := 150 if compact else 250
	t.ok(diff_a >= min_diff and diff_b >= min_diff, label + " smudged digit differs from either clean one: %d / %d px" % [diff_a, diff_b])
	s1.free()
	s2.free()


## Rule lines: present, from CardText, only the ones that apply, clear of the sheet and buttons, no answer.
func _rules(t) -> void:
	var fix := H.params("chen_code.json")
	var ctx := H.open_game(self, H.DEC, fix)
	var g = ctx["game"]
	await t.frames(2)
	var lines: PackedStringArray = g.rule_lines()
	t.eq(lines, PackedStringArray([CardText.ui("c15.decode.rule.find"), CardText.ui("c15.decode.rule.blot"),
		CardText.ui("c15.decode.rule.pairs", {"pairs": GameSc.pairs_text()})]), "smudged telegram: find, blot, pairs")
	for key in ["c15.decode.rule.find", "c15.decode.rule.blot", "c15.decode.rule.pairs", "c15.decode.rule.key"]:
		t.ok(CardText.ui(key) != "" and CardText.ui(key) != key, key + " has text")
	var panel: Control = g.get("_panel")
	var sheet := Rect2(panel.global_position + GameSc.SHEET_RECT.position, GameSc.SHEET_RECT.size)
	var rules: Control = g.get("_rules")
	var used := 0.0
	for l in rules.get_children():
		var lr := (l as Control).get_global_rect()
		t.ok(not lr.intersects(sheet), "rule line below the sheet " + str(lr))
		t.ok(not lr.intersects(g.done_rect()) and not lr.intersects(g.abort_rect()), "rule line clear of the buttons")
		t.ok(panel.get_global_rect().encloses(lr), "rule line inside the panel")
		t.ok((l as Label).get_line_count() <= 2, "rule line wraps to two lines at most")
		used += (l as Control).get_combined_minimum_size().y
	t.ok(used <= GameSc.RULES_RECT.size.y, "the rule lines fit their space (%d px)" % int(used))
	var before: PackedStringArray = g.rule_lines()
	for op in _plan(g, 0.0):
		g.apply_op(op)
	t.eq(g.rule_lines(), before, "the rules do not change with what the player copies")
	H.close(ctx)
	await t.frames(1)
	var other := H.params("chen_code.json")
	other["codes"] = ["5133", "5134", "5141", "5112", "5163"]
	other["smudges"] = [[0, 3, "5138"]]
	var ctx2 := H.open_game(self, H.DEC, other)
	await t.frames(1)
	t.eq(ctx2["game"].rule_lines(), lines, "another sheet with a blot: the same rule lines (nothing about the answer)")
	H.close(ctx2)
	await t.frames(1)
	var clean := H.params("chen_code.json")
	clean["smudges"] = []
	var ctx3 := H.open_game(self, H.DEC, clean)
	await t.frames(1)
	t.eq(ctx3["game"].rule_lines(), PackedStringArray([CardText.ui("c15.decode.rule.find")]), "no blot: no blot rules")
	H.close(ctx3)
	await t.frames(1)
	var keyed := H.params("ledger_key.json")
	var ctx4 := H.open_game(self, H.DEC, keyed)
	await t.frames(1)
	var kl: PackedStringArray = ctx4["game"].rule_lines()
	t.eq(kl[kl.size() - 1], CardText.ui("c15.decode.rule.key"), "a key in use: the key rule last")
	t.eq(t.all_text_from_cardtext(ctx4["game"]), PackedStringArray(), "all rule text from CardText")
	H.close(ctx4)
	await t.frames(1)


func _plan(g, skill: float) -> Array:
	var ops: Array = g._plan(skill)
	return ops.filter(func(op: Array) -> bool: return str(op[0]) != "done")


## The real telegram through the real engine: sign-off last; at every eye and on every run the smudges offer
## only checked readings, none of the sensible ones; and they reach the sheet as drawn blots.
func _real_telegram(t) -> void:
	var eng := CardEngine.new()
	var boot: Dictionary = eng.new_game({"seed": 7, "only_examples": false, "save_dir": t.user_dir()})
	t.ok(bool(boot.get("ok", false)), "new_game")
	if not bool(boot.get("ok", false)):
		return
	var d: Dictionary = eng.ctx.db.def("nw.1940.chen_code")
	var spec: Dictionary = d.get("decode", {})
	var codes: Array = spec.get("codes", [])
	t.eq(str(codes[codes.size() - 1]), "5112", "the sign-off (the form of address) is the last group")
	t.eq(CardText.card("cb.word.5112", "word") != "", true, "the sign-off has a word")
	var checked: Array = spec.get("smudge_alts", [])
	for bad in SENSIBLE:
		t.ok(not checked.has(bad), "a reading that makes sense is never offered: " + bad)
	var offered := {}
	for less in [0, 1, 2]:
		for run in range(12):
			var aids := {"smudge_less": less}
			var p := {}
			CardAppraisal._decode(eng.ctx, "doc:nw.1940.chen_code#%d" % run, spec, d, p, aids)
			for sm in p["smudges"]:
				offered[str(sm[2])] = true
				t.ok(checked.has(str(sm[2])), "eye aid %d run %d: offered %s is a checked nonsense reading" % [less, run, str(sm[2])])
	t.ok(offered.size() >= 3, "several checked readings come up: " + str(offered.keys()))
	var params := CardAppraisal.doc_params(eng.ctx, d, &"decode")
	var ctx := H.open_game(self, H.DEC, params)
	await t.frames(1)
	var slips: Array = ctx["game"].get("_slips")
	for sm2 in params["smudges"]:
		var slip = slips[int(sm2[0])]
		t.ok(slip.blot_rects().size() > 0 and slip.wash_rects().size() > 0, "engine smudge drawn with blot and stain")
	t.ok((ctx["game"].rule_lines() as PackedStringArray).size() >= 3, "the real telegram shows the blot rules")
	H.close(ctx)
	await t.frames(1)
