# RG2_seed: CardRunSeed (ROGUE_V1.md §5.7) — run 1 is always 7, later runs derive distinct in-range seeds, typed
# text maps deterministically; the same seed and the same commands give the same state day after day, and a derived
# seed deals a different first day than seed 7. Owner RG2.
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const H = preload("res://scripts/tests/cards/RG2/helper.gd")


func _initialize() -> void:
	var t := T.new(self, "RG2_seed")
	_derive(t)
	_parse(t)
	_same_seed_same_days(t)
	_different_first_day(t)
	t.finish()


func _derive(t) -> void:
	t.eq(CardRunSeed.derive(0, 1, 0), 7, "first run, no reroll -> 7")
	t.eq(CardRunSeed.derive(12345, 1, 0), 7, "first run ignores the salt")
	t.eq(CardRunSeed.derive(0, 0, 0), 7, "run 0 (never started) also 7")
	t.ok(CardRunSeed.derive(0, 1, 1) != 7, "first run with one reroll moves off 7")
	var seen: Dictionary = {}
	var out_of_range := 0
	var dup := 0
	for run_no in range(2, 201):
		for reroll in range(0, 4):
			var s := CardRunSeed.derive(0, run_no, reroll)
			if s < 1 or s > CardRunSeed.MAX_SEED:
				out_of_range += 1
			if seen.has(s):
				dup += 1
			seen[s] = [run_no, reroll]
	t.eq(out_of_range, 0, "derived seeds stay in 1..MAX_SEED")
	t.eq(dup, 0, "run 2..200 x reroll 0..3 are pairwise different")
	t.eq(seen.size(), 199 * 4, "796 distinct seeds")
	t.eq(CardRunSeed.derive(0, 2, 0), CardRunSeed.derive(0, 2, 0), "derive is a pure function")
	t.ok(CardRunSeed.derive(1, 2, 0) != CardRunSeed.derive(0, 2, 0), "the salt changes later runs")


func _parse(t) -> void:
	var m := CardRunSeed.MAX_SEED
	t.eq(CardRunSeed.parse(""), -1, "empty -> -1 (use the suggestion)")
	t.eq(CardRunSeed.parse("   "), -1, "blank -> -1")
	t.eq(CardRunSeed.parse("12345"), 12345, "digits are used as is")
	t.eq(CardRunSeed.parse("  12345 "), 12345, "surrounding blanks are ignored")
	t.eq(CardRunSeed.parse("7"), 7, "7 stays 7")
	t.eq(CardRunSeed.parse(str(m)), m, "MAX_SEED stays")
	t.eq(CardRunSeed.parse("0"), m, "0 folds back to MAX_SEED")
	t.eq(CardRunSeed.parse(str(m + 1)), 1, "MAX_SEED + 1 folds back to 1")
	var big := CardRunSeed.parse("999999999999999999")
	t.ok(big >= 1 and big <= m, "18 digits fold into range: %d" % big)
	t.eq(CardRunSeed.parse("999999999999999999"), big, "folding is stable")
	var long_digits := CardRunSeed.parse("1234567890123456789")
	t.ok(long_digits >= 1 and long_digits <= m, "19 digits are hashed into range")
	# The shop's name typed into the seed box (three CJK code points, built from numbers: no non-ASCII literal).
	var shop := String.chr(0x5FB7) + String.chr(0x539A) + String.chr(0x5F53)
	var a := CardRunSeed.parse(shop)
	t.eq(CardRunSeed.parse(shop), a, "text maps to the same seed twice")
	t.ok(a >= 1 and a <= m, "text seed in range: %d" % a)
	t.eq(CardRunSeed.parse(" " + shop + " "), a, "blanks around text are ignored")
	t.ok(CardRunSeed.parse("abc") != CardRunSeed.parse("abd"), "different text, different seed")
	t.ok(CardRunSeed.parse("12a") >= 1, "mixed text is hashed")
	var long_text := "x".repeat(CardRunSeed.TEXT_MAX)
	t.eq(CardRunSeed.parse(long_text + "tail"), CardRunSeed.parse(long_text + "other"), "only the first 24 characters count")
	t.eq(CardRunSeed.text(12345), "12345", "text() prints the seed")
	t.eq(CardRunSeed.parse(CardRunSeed.text(CardRunSeed.derive(0, 9, 2))), CardRunSeed.derive(0, 9, 2), "text round trip")


## Two engines, same seed, same commands: identical state hash at every step (fixture data: stock module on).
func _same_seed_same_days(t) -> void:
	var root := H.data_root(t, "same")
	var s := CardRunSeed.derive(0, 2, 0)
	var a := H.engine(t, root, s, "same_a")
	var b := H.engine(t, root, s, "same_b")
	t.eq(a.ctx.state.hash(), b.ctx.state.hash(), "same start")
	var diverged := -1
	for i in range(80):
		var ra: Dictionary = a.send(&"day.end", {"confirm": true})
		var rb: Dictionary = b.send(&"day.end", {"confirm": true})
		if a.ctx.state.hash() != b.ctx.state.hash() or bool(ra.get("ok", false)) != bool(rb.get("ok", false)):
			diverged = i
			break
		if H.phase(a) == "game_over":
			break
	t.eq(diverged, -1, "no step diverged")
	t.ok(H.stage_day(a) >= 16, "walked past two stocktakes (day %d)" % H.stage_day(a))
	t.eq(H.stock(a), H.stock(b), "same offers")
	t.ok(H.stock(a).get("offers", {}).has("w0.1"), "the second week's stocktake is in both")
	t.eq(a.command_log().slice(1), b.command_log().slice(1), "same commands after game.new (save dirs differ)")
	t.eq(t.find_floats(a.ctx.state.data), PackedStringArray(), "integer-only state")


## Seed 7 and the second run's seed deal different random cards on day 1. Stage 0 days 1-3 are tutorial days
## (rules/deal.json scripted_days, no random cards whatever the seed), so the first day is taken at stage 1.
func _different_first_day(t) -> void:
	var s2 := CardRunSeed.derive(0, 2, 0)
	var hands: Array = []
	for seed_value in [7, s2]:
		var e := H.engine(t, CardDB.DEFAULT_ROOT, seed_value, "first_%d" % seed_value, null, {"stage": 1})
		t.ok(H.walk_to(e, 1, "day"), "stage 1 day 1 reached (seed %d)" % seed_value)
		var defs := Array(H.hand_defs(e))
		defs.sort()
		hands.append(defs)
	t.ok(not (hands[0] as Array).is_empty(), "day 1 dealt something")
	t.ok(JSON.stringify(hands[0]) != JSON.stringify(hands[1]), "seed 7 and derive(0,2,0) deal different day 1 cards")
	var e0 := H.engine(t, CardDB.DEFAULT_ROOT, 7, "first_again", null, {"stage": 1})
	H.walk_to(e0, 1, "day")
	var again := Array(H.hand_defs(e0))
	again.sort()
	t.eq(again, hands[0], "seed 7 deals the same day 1 again")
