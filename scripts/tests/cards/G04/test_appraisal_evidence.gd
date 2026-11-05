# G04 鉴定改版：证据真假同分布（找不同固定 3 处、部位一样；一摞几枚一样）、B2 每个称分量模板都压得平、
# B3 拼碎片真货印不偏纸不异、眼力 / 懂行人脉 / 猫换成辅助参数、老规格照旧能出参数。
extends SceneTree
const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const S = preload("res://scripts/tests/cards/G04/economy_test_support.gd")
const A = preload("res://scripts/tests/cards/G04/appraisal_support.gd")
const E = preload("res://scripts/cards/economy/economy_support.gd")

## Poise reach of the C14 scale. The old game (weigh_game.gd POISE_MAX_FEN_*) stops at 100 / 400 fen; the 10-25
## game (WP4 weigh_rules.gd poise_cap_fen) widens it to bridge weight gaps and reach the claim + 15 percent but never
## below these bases. Balancing with the bases alone is the conservative check that holds for both.
const POISE := {"dengzi": 100, "steelyard": 400}
## WP4 travel rule, mirrored for the check below (claim reach in per mille, steps per beam).
const REACH_PERMILLE := 1150
const MAX_STEPS := 320


func _initialize() -> void:
	var t := T.new(self, "G04_appraisal_evidence")
	_spot_counts(t)
	_coin_counts(t)
	_weigh_balance(t)
	_fragments_truth(t)
	_aids(t)
	_compat(t)
	t.finish()


## 250 items x two truths each (same item, truth flipped): the number of marks and the parts they sit on
## must not depend on the truth; only kind/look differ.
func _spot_counts(t) -> void:
	var c := A.real_ctx(21)
	var shapes := {false: {}, true: {}}
	var thirds := {false: 0, true: 0}
	var n := 0
	var fine := {false: 0, true: 0}
	for tpl in ["jewelry.hairpin", "utensils.bowl", "art.calligraphy", "rice.jing", "medicine.quinine"]:
		for k in range(50):
			var r := CardItems.generate(c, ["c", 1, "dist", tpl, k], tpl)
			var id := str(r["item"])
			var parts_by_truth := {}
			for fake in [false, true]:
				A.set_truth(c, id, fake, false)
				var p := CardAppraisal.params_for(c, id, &"spot")
				var parts: Array = []
				for mk in p["marks"]:
					parts.append(str(mk["part"]))
					if int(mk["fine"]) >= 500:
						fine[fake] += 1
					t.ok(typeof(mk.get("at")) == TYPE_ARRAY and (mk["at"] as Array).size() == 4, "every mark has an at rect")
					t.ok(str(mk.get("look", "")) != "", "every mark has a look")
				t.eq(parts.size(), 3, "%s: always three marks (fake=%s)" % [tpl, fake])
				t.ok(parts.has("authenticity") and parts.has("provenance"), "authenticity and provenance always marked")
				parts_by_truth[fake] = parts
				shapes[fake][",".join(PackedStringArray(parts))] = int(shapes[fake].get(",".join(PackedStringArray(parts)), 0)) + 1
				if parts.has("condition"):
					thirds[fake] += 1
				t.eq(bool(p["atlas_open"]), false, "B5: the atlas starts closed")
			t.eq(parts_by_truth[false], parts_by_truth[true], "%s: the same parts for either truth" % tpl)
			n += 1
	t.eq(shapes[false], shapes[true], "part layouts are identically distributed for real and fake")
	t.eq(thirds[false], thirds[true], "the third mark falls on condition equally often")
	print("NOTE: spot fine marks real=%d fake=%d over %d items" % [fine[false], fine[true], n])


func _coin_counts(t) -> void:
	var c := A.real_ctx(22)
	c.db._cards["it.silver.yuan_a"]["coin_ring"]["stack"] = [1, 5]
	var sizes := {false: {}, true: {}}
	for k in range(250):
		var r := CardItems.generate(c, ["c", 1, "coins", k], "silver.yuan_a")
		var id := str(r["item"])
		var ns := {}
		for fake in [false, true]:
			A.set_truth(c, id, fake)
			var p := CardAppraisal.params_for(c, id, &"coin_ring")
			var coins: Array = p["coins"]
			ns[fake] = coins.size()
			sizes[fake][coins.size()] = int(sizes[fake].get(coins.size(), 0)) + 1
			t.eq((p["samples"] as Array).size(), 2, "two shop samples")
			t.eq(str(p["samples"][0]["id"]) + str(p["samples"][1]["id"]), "gooddull", "samples are the silver (good) and the dull one")
			t.eq(bool(p["clink"]), coins.size() >= 2, "clink only with two coins or more")
		t.eq(ns[false], ns[true], "stack size does not depend on the truth")
	t.eq(sizes[false], sizes[true], "stack sizes identically distributed for real and fake")
	var answers := {1: 0, 2: 0}
	var c2 := A.real_ctx(23)
	c2.db._cards["it.silver.yuan_a"]["coin_ring"]["stack"] = [5, 5]
	for id in A.items_of(c2, "silver.yuan_a", true, 40, "dull"):
		var b := CardAppraisal._build(c2, id, &"coin_ring", {})
		var bad: Array = b["answer"]["bad"]
		t.ok(bad.size() >= 1 and bad.size() <= 2, "a fake stack of five has one or two dull coins")
		answers[bad.size()] += 1
	t.ok(answers[1] > 0 and answers[2] > 0, "both one and two dull coins happen in a stack of five")


## B2: for every weigh template, every actual weight its spec can produce balances on its own scale.
func _weigh_balance(t) -> void:
	var c := A.real_ctx(24)
	for item_def in c.db.ids_of(&"item"):
		var d := c.db.def(item_def)
		if not d.has("weigh"):
			continue
		var spec: Dictionary = d["weigh"]
		var r := CardItems.generate(c, ["c", 1, "weigh", item_def], str(d["template"]))
		var p := CardAppraisal.params_for(c, str(r["item"]), &"weigh")
		var tool := str(p["tool"])
		var res := int(p["resolution_fen"])
		var sums := _sums(p["weights_fen"])
		var lo := 1 << 30
		var hi := 0
		for dev_key in ["dev_bad_pct", "dev_worn_pct"]:
			for claimed in spec["claimed_fen"]:
				for dev in spec.get(dev_key, [0, 0]):
					var actual := maxi(1, int(claimed) * (100 - int(dev)) / 100)
					lo = mini(lo, actual)
					hi = maxi(hi, actual)
		var fails: Array = []
		for actual in range(lo, hi + 1, maxi(1, res)):
			if not _balances(sums, actual, int(POISE.get(tool, 100)), res):
				fails.append(actual)
		t.eq(fails.slice(0, 3), [], "B2: %s balances from %d to %d fen" % [item_def, lo, hi])
		t.ok(int(p["small_fen"]) >= res, "%s small_fen at least one resolution" % item_def)
		var total := 0
		for w in p["weights_fen"]:
			total += int(w)
		t.ok(total + int(POISE.get(tool, 100)) >= int(spec["claimed_fen"][1]) * 1000 / REACH_PERMILLE, "%s: the box alone nearly reaches the top claim" % item_def)
		t.ok(int(POISE.get(tool, 100)) <= MAX_STEPS * res, "%s: the base poise fits one beam" % item_def)


func _sums(weights: Array) -> Array:
	var seen := {0: true}
	for w in weights:
		for s in seen.keys():
			seen[int(s) + int(w)] = true
	var out: Array = seen.keys()
	out.sort()
	return out


func _balances(sums: Array, actual: int, poise: int, res: int) -> bool:
	for s in sums:
		if int(s) - res <= actual and actual <= int(s) + poise + res:
			return true
	return false


## B3: a sound document has an aligned seal and no odd paper; a forgery has at least one of the two.
func _fragments_truth(t) -> void:
	var c := A.real_ctx(25)
	var stains := {false: 0, true: 0}
	var evidence := {"seal": 0, "odd": 0}
	for tpl in ["art.landscape", "documents.receipt", "papers.iou"]:
		for k in range(60):
			var r := CardItems.generate(c, ["c", 1, "frag", tpl, k], tpl)
			var id := str(r["item"])
			for fake in [false, true]:
				A.set_truth(c, id, fake)
				var b := CardAppraisal._build(c, id, &"fragments", {})
				var p: Dictionary = b["params"]
				t.ok(int(p["pieces"]) <= 6, "random items have at most six pieces")
				if int(p["stain"]) >= 0:
					stains[fake] += 1
					t.ok(not (p["ink_mismatch"] as Array).has(int(p["stain"])), "the stain is never the odd piece")
				if fake:
					t.ok(bool(b["answer"]["seal_off"]) or not (b["answer"]["odd"] as Array).is_empty(), "a forgery shows at least one sign")
					evidence["seal"] += 1 if bool(b["answer"]["seal_off"]) else 0
					evidence["odd"] += 1 if not (b["answer"]["odd"] as Array).is_empty() else 0
				else:
					t.eq(int(p["seal_offset_px"]), 0, "B3: sound seal offset 0")
					t.eq(p["ink_mismatch"], [], "B3: sound paper all one kind")
			t.eq(bool(CardAppraisal.params_for(c, id, &"fragments")["rotate"]), tpl.begins_with("art."), "rotate only for art")
	t.eq(stains[false], stains[true], "water stains do not depend on the truth")
	t.ok(evidence["seal"] > 0 and evidence["odd"] > 0, "forgeries show both kinds of sign")


func _set_eye(c: CardCtx, eye: int) -> void:
	c.state.ns("rules")["attrs"] = {"ruhua": {"eye": eye, "tongue": 1, "pull": 1, "nerve": 1}}


func _aids(t) -> void:
	var c := A.real_ctx(26)
	var hairpin := str(A.items_of(c, "jewelry.hairpin", false, 1, "aid")[0])
	var yuan := str(A.items_of(c, "silver.yuan_a", false, 1, "aid")[0])
	var scroll := str(A.items_of(c, "art.calligraphy", false, 1, "aid")[0])
	var rows := [[0, 3, 56, false, 4, 1, 2, false, 6], [2, 4, 72, false, 5, 1, 2, true, 8], [4, 5, 88, true, 6, 2, 3, true, 10]]
	for row in rows:
		_set_eye(c, int(row[0]))
		var sp := CardAppraisal.params_for(c, hairpin, &"spot")
		var cr := CardAppraisal.params_for(c, yuan, &"coin_ring")
		var we := CardAppraisal.params_for(c, hairpin, &"weigh")
		var fr := CardAppraisal.params_for(c, scroll, &"fragments")
		t.eq([int(sp["ink"]), int(sp["lens_px"]), bool(sp["blink"])], [row[1], row[2], row[3]], "spot aids at eye %d" % row[0])
		t.eq([int(cr["tries"]), int(cr["ghosts"])], [row[4], row[5]], "coin aids at eye %d" % row[0])
		t.eq([int(we["zoom"]), bool(we["minor_ticks"]), int(we["needle_gain"])], [row[6], row[7], row[8]], "weigh aids at eye %d" % row[0])
		t.eq(bool(fr["backlight"]), int(row[0]) >= 3, "backlight from eye 3 at eye %d" % row[0])
		var doc := c.db.def("nw.1940.chen_code")
		t.eq((CardAppraisal.doc_params(c, doc, &"decode")["smudges"] as Array).size(), maxi(0, 2 - int(row[0]) / 2), "smudges at eye %d" % row[0])
	_set_eye(c, 2)
	# fix2 (blind review 10-25): the legend always lists every look the category can draw (the stolen look
	# included); a look the player never saw in the book cannot be learned.
	var every := {"wear": ["scuff", "chip", "shine"], "differs": ["base_metal", "speck", "scrape"]}
	t.eq(CardAppraisal.params_for(c, hairpin, &"spot")["legend"], every, "the legend lists every look of the category")
	t.eq(bool(CardAppraisal.params_for(c, scroll, &"fragments")["backlight"]), false, "no backlight without a contact at eye 2")
	c.mods.register(&"appraise_pct", func(_ctx: CardCtx, args: Dictionary) -> int: return 120 if str(args.get("cat", "")) in ["art", "jewelry"] else 100, "test")
	t.eq(CardAppraisal.params_for(c, hairpin, &"spot")["legend"], every, "with a knowledgeable contact too")
	t.eq(bool(CardAppraisal.params_for(c, scroll, &"fragments")["backlight"]), true, "a knowledgeable contact lets you hold it to the light")
	for tpl_kind in [[hairpin, &"spot"], [yuan, &"coin_ring"]]:
		var a := CardAppraisal._aids(c, tpl_kind[1], "jewelry")
		t.ok(not a.is_empty(), "aids for %s" % tpl_kind[1])


## Old specs (the example set: no stack, small_fen, weight_box, seal_offset_px_good/bad) still produce params.
func _compat(t) -> void:
	var c := S.ctx(3)
	for item_def in c.db.ids_of(&"item"):
		var d := c.db.def(item_def)
		var r := CardItems.generate(c, ["c", 1, "compat", item_def], str(d["template"]))
		for kind in d.get("minigames", []):
			var p := CardAppraisal.params_for(c, str(r["item"]), StringName(str(kind)))
			t.ok(not S.forbidden(p), "%s %s old spec params safe" % [item_def, kind])
			match str(kind):
				"weigh":
					t.eq(p["weights_fen"], [1, 2, 5, 10, 20, 50, 100, 200], "old weigh spec: the default box")
					t.eq(int(p["small_fen"]), maxi(1, int(p["claimed_fen"]) * 60 / 1000), "old weigh spec: small_fen falls back to 60 permille")
				"coin_ring":
					t.eq((p["coins"] as Array).size(), 1, "old coin spec: one coin")
					t.ok(p.has("reference") and p.has("samples"), "old coin spec: reference and samples")
	var cr := A.real_ctx(27)
	cr.db._cards["it.art.landscape"]["fragments"] = {"doc": "scroll", "pieces": [4, 6], "seal_offset_px": [0, 6], "ink_mismatch": [0, 2]}
	var id := str(A.items_of(cr, "art.landscape", true, 1, "oldfrag")[0])
	var p2 := CardAppraisal._build(cr, id, &"fragments", {})
	t.eq((p2["params"]["ink_mismatch"] as Array).size(), 1, "old fragments spec: a forgery keeps the old single odd piece")
	t.ok(int(p2["params"]["seal_offset_px"]) >= 0, "old fragments spec: seal sampled from the old range")
