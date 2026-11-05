# Weigh (C14): pure rules shared by the game, the drawing and the tests. No class_name; preload it.
# Owner C14. Contract: docs/cards/CARDS_INTERFACES.md 8.1 / 8.2, appraisal redesign DESIGN 6.
# Nothing here is shown to the player. The answer helpers are for autoplay and tests only (the engine keeps its
# own answer in its private ledger); the game never prints a reading or a verdict.
extends RefCounted

## Index of a call op ["call", c]; 0 = not chosen yet.
const CALLS: Array[String] = ["", "match", "light_small", "light_much", "heavy", "unsure"]
const CALL_MATCH := 1
const CALL_LIGHT_SMALL := 2
const CALL_LIGHT_MUCH := 3
const CALL_HEAVY := 4
const CALL_UNSURE := 5

## Defaults when the engine sends no aids yet (eye 2 at the start: zoom 2, small dots on, needle 6 + 2).
const DEFAULT_ZOOM := 2
const DEFAULT_MINOR_TICKS := true
const DEFAULT_NEEDLE_GAIN := 8
## Old rule when the item spec has no small_fen yet: light by up to 60 per mille of the claim is "a little".
const SMALL_FALLBACK_PERMILLE := 60
## Poise travel by tool before the weights and the claim widen it (fen).
const POISE_BASE_DENGZI := 100
const POISE_BASE_STEELYARD := 400
## The scale must reach this much above the claim (per mille): rice soaked to 14 percent heavier still levels.
const REACH_PERMILLE := 1150
## Most poise steps one beam can hold (beyond this the stars are too fine to drag; the zoom still reads).
const MAX_STEPS := 320
## Clarity from the needle at the last commit (process only, never from the call): Q_LEVEL only with the needle
## straight (the step nearest the weight), Q_NEAR up to three steps off.
const Q_LEVEL := 1000
const Q_NEAR := 600
const Q_OFF := 250
const Q_NONE := 100


static func call_name(c: int) -> String:
	return CALLS[c] if c > 0 and c < CALLS.size() else ""


static func call_index(cat: String) -> int:
	return maxi(0, CALLS.find(cat))


static func obs_key(c: int) -> String:
	var n := call_name(c)
	return "obs.weigh." + (n if n != "" else "unsure")


static func small_fen(params: Dictionary) -> int:
	if params.has("small_fen"):
		return maxi(0, int(params["small_fen"]))
	return maxi(0, int(params.get("claimed_fen", 0)) * SMALL_FALLBACK_PERMILLE / 1000)


## The category the hidden weight falls in (same rule as G04's answer): match, light_small, light_much, heavy.
static func answer(params: Dictionary) -> String:
	var res := maxi(1, int(params.get("resolution_fen", 1)))
	var d := int(params.get("actual_fen", 0)) - int(params.get("claimed_fen", 0))
	if absi(d) <= res:
		return "match"
	if d > 0:
		return "heavy"
	if -d <= small_fen(params):
		return "light_small"
	return "light_much"


## The wrong call a careless clerk makes for a category (DESIGN 6.8: the neighbouring one).
static func neighbour(cat: String) -> String:
	match cat:
		"match":
			return "light_small"
		"light_small":
			return "light_much"
		"light_much":
			return "light_small"
		"heavy":
			return "match"
	return "match"


## Stars: a big numbered star every qian (10 fen) on the dengzi, every liang (100 fen) on the steelyard.
static func major_fen(tool: String, res: int) -> int:
	var m := 100 if tool == "steelyard" else 10
	while m < res:
		m *= 10
	return m


## Small dots: every resolution step with the fine stars, else every half star (eye low: guess between).
static func minor_fen(tool: String, res: int, fine: bool) -> int:
	var major := major_fen(tool, res)
	if fine:
		return maxi(1, res)
	return maxi(maxi(1, res), major / 2)


## Largest hole between the sums the weights can make (the poise has to bridge it).
static func largest_gap(weights: Array) -> int:
	var sums := {0: true}
	for w in weights:
		var wi := int(w)
		if wi <= 0:
			continue
		for s in sums.keys():
			sums[int(s) + wi] = true
	var keys: Array = sums.keys()
	keys.sort()
	var gap := 0
	for i in range(1, keys.size()):
		gap = maxi(gap, int(keys[i]) - int(keys[i - 1]))
	return gap


static func weight_total(weights: Array) -> int:
	var t := 0
	for w in weights:
		t += maxi(0, int(w))
	return t


## Poise travel in fen. Built only from what the player sees (tool, weights, the claim), never from the hidden
## weight. Wide enough that weights + poise bridge every gap and reach the claim plus 15 percent (B2: rice,
## the ten-liang bar and the big silver box level with DESIGN's weight sets). An explicit poise_fen wins.
static func poise_cap_fen(tool: String, weights: Array, claimed: int, res: int, explicit: int = 0) -> int:
	res = maxi(1, res)
	var top := MAX_STEPS * res
	if explicit > 0:
		return clampi(_ceil_to(explicit, res), res, top)
	var unit := major_fen(tool, res)
	var base := POISE_BASE_STEELYARD if tool == "steelyard" else POISE_BASE_DENGZI
	var need := maxi(0, claimed) * REACH_PERMILLE / 1000 - weight_total(weights)
	var cap := maxi(base, maxi(largest_gap(weights) + res, need))
	cap = _ceil_to(cap, unit)
	if cap > top:
		cap = maxi(res, top - top % unit)
	return cap


## Clarity of a commit: the needle stood straight (the step nearest the weight), near (up to three steps off) or
## off. One step off is not level: it can change the call on a small piece, and the needle shows it plainly.
static func quality(actual: int, indicated: int, res: int, committed: bool) -> int:
	if not committed:
		return Q_NONE
	var off := absi(off_steps(actual, indicated, res))
	if off == 0:
		return Q_LEVEL
	if off <= 3:
		return Q_NEAR
	return Q_OFF


## Star steps between the reading and the weight, to the nearest step (a weight exactly half way between two
## steps counts toward the heavier reading). 0 = the needle stands straight: the scale cannot show less than one
## step, so exactly one step levels the beam for any weight, and every other step leans the needle.
static func off_steps(actual: int, indicated: int, res: int) -> int:
	res = maxi(1, res)
	return _floor_div(2 * (actual - indicated) + res, 2 * res)


static func _floor_div(a: int, b: int) -> int:
	var q := a / b
	if a % b != 0 and (a < 0) != (b < 0):
		q -= 1
	return q


## Fen split for the text keys (1 liang = 10 qian = 100 fen).
static func split(fen: int) -> Dictionary:
	var f := absi(fen)
	return {"liang": f / 100, "qian": (f / 10) % 10, "fen": f % 10, "qian_all": f / 10}


static func _ceil_to(v: int, unit: int) -> int:
	unit = maxi(1, unit)
	return ((v + unit - 1) / unit) * unit
