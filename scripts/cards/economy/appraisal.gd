# 鉴定桥：参数只放物理量和摆设；这一回的答案只记在 econ.appraisals[uid].answer（私账），不进参数、视图、查询、事件。
# G04；观察 = 玩家自己的判断，按目录的 hedge 规则记下，绝不按对错过滤。judge() 只在引擎里对答案；
# 来当 / 来卖的会话里第一次没放弃的鉴定结算一次“说破”（主创 10-25；DESIGN 鉴定改版 §3）。文书（当票、信、电报）记 econ.readings。
class_name CardAppraisal
extends RefCounted
const E = preload("res://scripts/cards/economy/economy_support.gd")
const Pet = preload("res://scripts/cards/rules/pet.gd")
const FORBIDDEN_PARAM_KEYS: Array = ["fake", "real", "genuine", "authentic", "forged", "stolen", "origin", "market",
	"value", "true_value", "floor", "tell", "benign", "fake_text", "real_text", "est", "verdict", "rare", "grade", "quality"]
const KINDS: Array = ["spot", "coin_ring", "weigh", "fragments", "decode"]
const LEVER_LINE := "g04.counter.lever."
## Player codes reported in measures (DESIGN 4.4 / 5.4 / 6.4 / 7.4). spot pin tag: 1 wear, 2 differs.
const TAG_WEAR := 1
const TAG_DIFFERS := 2
## coin_ring: call 1 like the silver sample, 2 like the dull sample, 3 unsure; marks 0 unset, 1 ring, 2 dull.
const CALL_DULL := 2
const MARK_DULL := 2
## weigh call -> answer category (index = call code).
const WEIGH_CALLS: Array = ["", "match", "light_small", "light_much", "heavy", "unsure"]
## fragments seal_call: 1 aligned, 2 offset.
const SEAL_OFFSET := 2
## Digits a smudged telegraph slip lets the reader confuse (DESIGN 8.2).
const CONFUSABLE := {"0": ["8"], "1": ["7"], "2": ["7"], "3": ["8"], "4": ["9"], "5": ["6"], "6": ["5"],
	"7": ["1", "2"], "8": ["3", "0"], "9": ["4"]}

static func request(ctx: CardCtx, uid: String, item_id: String) -> Dictionary:
	E.ensure(ctx)
	var d := CardPiles.def_of(ctx, uid)
	if d.is_empty() or CardPiles.zone_of(ctx, uid) not in [&"hand", &"kept"]:
		return {"ok": false, "err": "bad_args"}
	if item_id != "" and (E.meta(ctx, item_id).is_empty() or str(E.session(ctx, uid).get("item", "")) != item_id):
		return {"ok": false, "err": "bad_args"}
	var kind := str(d.get("minigame", ""))
	if kind == "" and item_id != "":
		var games: Array = _spec(ctx, item_id).get("minigames", [])
		if not games.is_empty():
			kind = str(games[mini(games.size() - 1, int(ctx.draw("c.mg.pick", [ctx.abs_day(), uid, item_id]) * games.size()))])
	if kind not in KINDS:
		return {"ok": false, "err": "no_minigame"}
	var built := _build(ctx, item_id, StringName(kind), {} if item_id != "" else d)
	var params: Dictionary = built["params"]
	ctx.state.ns("econ")["appraisals"][uid] = {"item": item_id, "kind": kind, "answer": built["answer"]}
	CardFirsts.mark(ctx, StringName("mg." + kind), {"uid": uid, "kind": kind})
	ctx.emit(&"minigame_requested", [uid, item_id, StringName(kind), params])
	E.sync(ctx)
	return {"ok": true, "err": "", "kind": kind, "params": params}

## Physical parameters for one item (frozen signature, contract 7.9). The answer stays private.
static func params_for(ctx: CardCtx, item_id: String, kind: StringName) -> Dictionary:
	return _build(ctx, item_id, kind, {})["params"]

## Same for a document without an item (pawn ticket, letter, telegram): the spec is on the card definition.
static func doc_params(ctx: CardCtx, doc: Dictionary, kind: StringName) -> Dictionary:
	return _build(ctx, "", kind, doc)["params"]

## Pre-10-25 helper kept for callers that still build document params in two steps
## (params_for(ctx, "", kind) then _document(ctx, params, def)); same result as doc_params.
static func _document(ctx: CardCtx, p: Dictionary, d: Dictionary) -> Dictionary:
	return doc_params(ctx, d, StringName(str(p.get("kind", d.get("minigame", "")))))

static func report(ctx: CardCtx, uid: String, item_id: String, result: Dictionary) -> Dictionary:
	var active: Dictionary = ctx.state.ns("econ").get("appraisals", {}).get(uid, {})
	if CardPiles.zone_of(ctx, uid) not in [&"hand", &"kept"] or active.is_empty() or str(active.get("item", "")) != item_id or not _valid_result(result):
		return {"ok": false, "err": "bad_args"}
	var m := E.meta(ctx, item_id)
	var kind := StringName(str(active["kind"]))
	var pct: int = ctx.mods.pct(ctx, &"appraise_pct", {"cat": str(m.get("cat", "")), "item_id": item_id})
	var clarity: int = clampi(int(result["quality_permille"]), 0, 1000) * pct / 100
	var cfg := _cfg(ctx)
	var fidelity := "clear" if clarity >= int(cfg.get("clear_permille", 700)) else ("partial" if clarity >= int(cfg.get("partial_permille", 350)) else "vague")
	var accepted := record(ctx.db.obs_catalog(kind), fidelity, result["observations"])
	if not m.is_empty():
		for key in accepted:
			if not m["observations"].has(key):
				m["observations"].append(key)
		m["observations"].sort()
	var aborted := bool(result.get("aborted", false))
	var verdict := judge(kind, active.get("answer", {}), result)
	var exhausted := CardCustomer.spend_patience(ctx, uid, int(result["minutes"]))
	ctx.state.ns("econ")["appraisals"].erase(uid)
	if item_id == "" and not aborted:
		_read(ctx, uid, kind, active.get("answer", {}), result, verdict)
		var d := CardPiles.def_of(ctx, uid)
		if str(d.get("type", "")) == "ticket" or str(d.get("id", "")).begins_with("tk."):
			CardTickets.foreign(ctx, uid)
		E.end(ctx, uid, &"resolved")
	elif exhausted == &"leave":
		E.end(ctx, uid, &"left")
	elif not aborted and _lever(ctx, uid, verdict) == &"leave":
		E.end(ctx, uid, &"left")
	E.sync(ctx)
	return {"ok": true, "err": "", "observations": accepted}

## Catalog hedge rule (DESIGN 3.2): a claim is kept when its fidelity is this clarity band or "any"; otherwise
## an entry with "hedge" is replaced by hedge[band] ("" = record nothing); old entries without hedge are dropped.
## Never looks at whether the claim is right.
static func record(catalog: Dictionary, fidelity: String, claims: Array) -> Array:
	var out: Array = []
	for key in claims:
		if typeof(key) != TYPE_STRING or not catalog.has(key) or typeof(catalog[key]) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = catalog[key]
		var band := str(entry.get("fidelity", ""))
		var got := ""
		if band == fidelity or band == "any":
			got = str(key)
		elif typeof(entry.get("hedge")) == TYPE_DICTIONARY:
			got = str(entry["hedge"].get(fidelity, ""))
		if got != "" and catalog.has(got) and not out.has(got):
			out.append(got)
	out.sort()
	return out

## Scores the player's own calls (result.measures) against the private answer. Pure; the counts never reach the UI.
## right = a real flaw named (fake mark, dull coin, short weight, odd paper, offset seal, a correct code group);
## soft = an honest wear / slightly light named as such; wrong = something sound called faulty (missing a flaw is 0).
static func judge(kind: StringName, answer: Dictionary, result: Dictionary) -> Dictionary:
	var out := {"right": 0, "wrong": 0, "soft": 0}
	var ms = result.get("measures", {})
	if bool(result.get("aborted", false)) or answer.is_empty() or typeof(ms) != TYPE_DICTIONARY:
		return out
	match kind:
		&"spot": _judge_spot(answer, ms, out)
		&"coin_ring": _judge_coin(answer, ms, out)
		&"weigh": _judge_weigh(answer, ms, out)
		&"fragments": _judge_fragments(answer, ms, out)
		&"decode": _judge_decode(answer, ms, out)
	return out

static func _judge_spot(answer: Dictionary, ms: Dictionary, out: Dictionary) -> void:
	var marks: Array = answer.get("marks", [])
	var tol: Array = answer.get("tol", [2, 1, 500])
	var right := {}
	var soft := {}
	for pin in _arr(ms.get("spots")):
		if typeof(pin) != TYPE_ARRAY or (pin as Array).size() < 3:
			continue
		var x := int(pin[0])
		var y := int(pin[1])
		var tag := int(pin[2])
		var best := -1
		var best_d := 1 << 30
		for i in range(marks.size()):
			var mk: Array = marks[i]
			var t: int = int(tol[1]) if int(mk[6]) >= int(tol[2]) else int(tol[0])
			if x >= int(mk[2]) - t and x <= int(mk[2]) + int(mk[4]) - 1 + t and y >= int(mk[3]) - t and y <= int(mk[3]) + int(mk[5]) - 1 + t:
				var dist: int = absi(2 * x + 1 - 2 * int(mk[2]) - int(mk[4])) + absi(2 * y + 1 - 2 * int(mk[3]) - int(mk[5]))
				if dist < best_d:
					best = i
					best_d = dist
		if best < 0:
			if tag == TAG_DIFFERS:
				out["wrong"] += 1
			continue
		var mark_kind := str(marks[best][1])
		if tag == TAG_DIFFERS:
			if mark_kind == "differs":
				right[best] = true
			else:
				out["wrong"] += 1
		elif tag == TAG_WEAR and mark_kind == "wear":
			soft[best] = true
	out["right"] += right.size()
	out["soft"] += soft.size()

static func _judge_coin(answer: Dictionary, ms: Dictionary, out: Dictionary) -> void:
	var bad: Array = answer.get("bad", [])
	if int(answer.get("n", 1)) <= 1 and ms.has("call"):
		if int(ms["call"]) == CALL_DULL:
			out["right" if bad.has(0) else "wrong"] += 1
		return
	var marks := _arr(ms.get("marks"))
	for i in range(mini(marks.size(), int(answer.get("n", marks.size())))):
		if int(marks[i]) == MARK_DULL:
			out["right" if bad.has(i) else "wrong"] += 1

static func _judge_weigh(answer: Dictionary, ms: Dictionary, out: Dictionary) -> void:
	var call := int(ms.get("call", 0))
	var said: String = WEIGH_CALLS[call] if call >= 0 and call < WEIGH_CALLS.size() else ""
	var truth := str(answer.get("cat", ""))
	if said in ["light_much", "heavy"]:
		if said == truth:
			out["right"] += 1
		elif truth in ["match", "light_small"]:
			out["wrong"] += 1
	elif said == "light_small" and truth == "light_small":
		out["soft"] += 1

static func _judge_fragments(answer: Dictionary, ms: Dictionary, out: Dictionary) -> void:
	var odd: Array = answer.get("odd", [])
	var found := {}
	for seam in _arr(ms.get("seams")):
		if typeof(seam) != TYPE_ARRAY or (seam as Array).size() < 2:
			continue
		var hit := false
		for side in [int(seam[0]), int(seam[1])]:
			if odd.has(side):
				found[side] = true
				hit = true
		if not hit:
			out["wrong"] += 1
	out["right"] += found.size()
	if int(ms.get("seal_call", 0)) == SEAL_OFFSET:
		out["right" if bool(answer.get("seal_off", false)) else "wrong"] += 1

static func _judge_decode(answer: Dictionary, ms: Dictionary, out: Dictionary) -> void:
	var codes: Array = answer.get("codes", [])
	var picked := _arr(ms.get("picked"))
	for g in range(mini(picked.size(), codes.size())):
		var p := int(picked[g])
		if p < 0:
			continue
		out["right" if p == int(str(codes[g])) else "wrong"] += 1

## Level B (DESIGN 3.4, decided 10-25): once per pawn/sell visit, on the first non-aborted report.
## Changes only the session's asking / floor / patience; the player sees the customer's line and the new money.
static func _lever(ctx: CardCtx, uid: String, v: Dictionary) -> StringName:
	var s := E.session(ctx, uid)
	if s.is_empty() or str(s.get("intent", "")) not in ["pawn", "sell"] or bool(s.get("lever_done", false)):
		return &""
	s["lever_done"] = true
	var cfg: Dictionary = _cfg(ctx).get("lever", {})
	if int(v["right"]) - int(v["wrong"]) >= 1:
		s["asking"] = maxi(1, int(s["asking"]) * int(cfg.get("caught_ask_pct", 70)) / 100)
		s["floor"] = maxi(1, int(s["floor"]) * int(cfg.get("caught_floor_pct", 55)) / 100)
		s["lever_line"] = LEVER_LINE + "caught"
	elif int(v["wrong"]) >= 1:
		s["lever_line"] = LEVER_LINE + "offended"
		if CardCustomer.spend_patience(ctx, uid, int(cfg.get("offend_min", 20))) == &"leave":
			return &"leave"
		s["floor"] = maxi(1, int(s["floor"]) * maxi(100, int(cfg.get("offend_floor_pct", 110))) / 100)
		s["asking"] = maxi(int(s["asking"]), int(s["floor"]))
		if int(cfg.get("offend_rep", 0)) != 0:
			ctx.run([{"op": "rep", "delta": -absi(int(cfg["offend_rep"]))}], uid + "/lever")
	elif int(v["soft"]) >= 1:
		s["asking"] = maxi(1, int(s["asking"]) * int(cfg.get("soft_pct", 95)) / 100)
		s["floor"] = maxi(1, int(s["floor"]) * int(cfg.get("soft_pct", 95)) / 100)
		s["lever_line"] = LEVER_LINE + "soft"
	return &""

## Documents without a customer (DESIGN 3.4 B2): econ.readings[def id] = right / partial / wrong; condition op mg_read.
static func _read(ctx: CardCtx, uid: String, kind: StringName, answer: Dictionary, result: Dictionary, v: Dictionary) -> void:
	var def_id := str(CardPiles.def_of(ctx, uid).get("id", ""))
	if def_id == "" or kind not in [&"fragments", &"decode"]:
		return
	var reading := "partial"
	if int(v["wrong"]) >= 1:
		reading = "wrong"
	elif kind == &"decode":
		if int(v["right"]) >= (answer.get("codes", []) as Array).size():
			reading = "right"
	else:
		var evidence: int = (answer.get("odd", []) as Array).size() + (1 if bool(answer.get("seal_off", false)) else 0)
		var ms = result.get("measures", {})
		var placed := int(ms.get("placed", 0)) if typeof(ms) == TYPE_DICTIONARY else 0
		if placed >= int(answer.get("present", answer.get("pieces", 0))) and int(v["right"]) >= evidence:
			reading = "right"
	var e := ctx.state.ns("econ")
	if not e.has("readings"):
		e["readings"] = {}
	e["readings"][def_id] = reading

static func reading(ctx: CardCtx, def_id: String) -> String:
	return str(ctx.state.ns("econ").get("readings", {}).get(def_id, ""))

static func _valid_result(r: Dictionary) -> bool:
	for key in r.keys():
		if str(key) not in ["quality_permille", "observations", "minutes", "measures", "aborted"]:
			return false
	if typeof(r.get("quality_permille")) != TYPE_INT or typeof(r.get("minutes")) != TYPE_INT or int(r.get("minutes", -1)) < 0:
		return false
	if typeof(r.get("observations")) != TYPE_ARRAY or typeof(r.get("measures", {})) != TYPE_DICTIONARY or typeof(r.get("aborted", false)) != TYPE_BOOL:
		return false
	for key in r["observations"]:
		if typeof(key) != TYPE_STRING:
			return false
	return _integer_tree(r.get("measures", {}))

static func _integer_tree(v) -> bool:
	if typeof(v) == TYPE_DICTIONARY:
		for child in v.values():
			if not _integer_tree(child):
				return false
		return true
	if typeof(v) == TYPE_ARRAY:
		for child in v:
			if not _integer_tree(child):
				return false
		return true
	return typeof(v) in [TYPE_INT, TYPE_BOOL]

# ---------------- parameters and the private answer ----------------

static func _build(ctx: CardCtx, item_id: String, kind: StringName, doc: Dictionary) -> Dictionary:
	var m := E.meta(ctx, item_id)
	# B8: itemless documents key their draws by the card definition, not by an empty item id.
	var subject := item_id if item_id != "" else "doc:" + str(doc.get("id", ""))
	var spec: Dictionary = _spec(ctx, item_id).get(str(kind), {}) if item_id != "" else _doc_spec(doc, kind)
	var params := {"kind": str(kind), "seed": int(ctx.draw("c.mg.param", [subject, str(kind), "seed"]) * 2147483647),
		"item": item_id, "art": str(m.get("art", "")), "minutes_per_step": int(spec.get("minutes_per_step", 1)), "max_minutes": int(spec.get("max_minutes", 30))}
	var aids := _aids(ctx, kind, str(m.get("cat", "")), item_id)
	var bad: bool = bool(m.get("fake", false))
	var craft: bool = int(m.get("craft", 0)) > 0
	var answer: Dictionary = {}
	match kind:
		&"spot": answer = _spot(ctx, subject, m, craft, params, aids)
		&"coin_ring": answer = _coin_ring(ctx, subject, spec, bad, craft, params, aids)
		&"weigh": answer = _weigh(ctx, subject, spec, bad, params, aids)
		&"fragments": answer = _fragments(ctx, subject, spec, bad, item_id != "", params, aids)
		&"decode": answer = _decode(ctx, subject, spec, doc, params, aids)
	return {"params": Pet.apply_look(ctx, params), "answer": answer}

## Eye (CardMeters.attr ruhua eye, 0-6) and a knowledgeable contact (appraise_pct above expert_pct) turn into
## plain aid fields the minigame reads (DESIGN 3.5). The shop cat adds +1 ink / try afterwards (pet.gd).
static func _aids(ctx: CardCtx, kind: StringName, cat: String, item_id: String = "") -> Dictionary:
	var cfg := _cfg(ctx)
	var a: Dictionary = cfg.get("aids", {}).get(str(kind), {})
	var eye: int = CardMeters.attr(ctx, "ruhua", &"eye")
	var expert: bool = ctx.mods.pct(ctx, &"appraise_pct", {"cat": cat, "item_id": item_id}) > int(cfg.get("expert_pct", 100))
	match kind:
		&"spot":
			return {"ink": int(a.get("ink_base", 3)) + eye / maxi(1, int(a.get("ink_eye_div", 2))),
				"lens_px": int(a.get("lens_px_base", 56)) + int(a.get("lens_px_per_eye", 8)) * eye,
				"blink": eye >= int(a.get("blink_eye", 3)), "legend_full": expert}
		&"coin_ring":
			return {"tries": int(a.get("tries_base", 4)) + eye / maxi(1, int(a.get("tries_eye_div", 2))),
				"ghosts": int(a.get("ghosts_base", 1)) + (1 if eye >= int(a.get("ghosts_eye", 3)) else 0)}
		&"weigh":
			return {"zoom": int(a.get("zoom_base", 2)) + (1 if eye >= int(a.get("zoom_eye", 4)) else 0),
				"minor_ticks": eye >= int(a.get("minor_ticks_eye", 2)),
				"needle_gain": int(a.get("needle_gain_base", 6)) + int(a.get("needle_gain_per_eye", 1)) * eye}
		&"fragments":
			return {"lens_px": int(a.get("lens_px_base", 56)) + int(a.get("lens_px_per_eye", 8)) * eye,
				"backlight": eye >= int(a.get("backlight_eye", 3)) or expert}
		&"decode":
			return {"smudge_less": eye / maxi(1, int(a.get("smudge_eye_div", 2)))}
	return {}

## spot (DESIGN 4.2): always marks_total marks, one per part: authenticity and provenance always carry one
## (differs when faked / taken, an honest old wear otherwise), the third sits on condition (worn items) or
## material. Count and place carry no information; only the look does. Every mark sits on the item's body
## (the item card's spot.opaque mask, _at), and the legend lists every look this category can draw (a look the
## player never saw in the book cannot be learned).
static func _spot(ctx: CardCtx, subject: String, m: Dictionary, craft: bool, p: Dictionary, aids: Dictionary) -> Dictionary:
	var lay: Dictionary = m.get("spot", {})
	var cfg: Dictionary = _cfg(ctx).get("spot", {})
	var cat := str(m.get("cat", ""))
	var body := _body_sums(str(_spec(ctx, subject).get("spot", {}).get("opaque", "")))
	var alias: Dictionary = cfg.get("look_alias", {})
	var edge_looks: Array = cfg.get("edge_looks", ["chip", "base_metal"])
	var rects := {}
	for part in lay.get("parts", []):
		rects[str(part.get("id", ""))] = part.get("rect", [0, 0, 8, 8])
	var src := {}
	for mk in lay.get("marks", []):
		if not src.has(str(mk.get("part", ""))):
			src[str(mk.get("part", ""))] = mk
	var looks := _looks(ctx, cat, alias)
	var slots: Array = []
	if rects.has("authenticity"):
		slots.append(["authenticity", "differs" if bool(m.get("fake", false)) else "wear"])
	if rects.has("provenance"):
		slots.append(["provenance", "differs" if bool(m.get("stolen", false)) else "wear"])
	var third := "condition" if src.has("condition") and rects.has("condition") else "material"
	if rects.has(third):
		slots.append([third, "wear"])
	for extra in ["material", "condition"]:
		if slots.size() < int(cfg.get("marks_total", 3)) and rects.has(extra) and not _slot_has(slots, extra):
			slots.append([extra, "wear"])
	slots = slots.slice(0, int(cfg.get("marks_total", 3)))
	slots.sort_custom(func(a: Array, b: Array) -> bool: return str(a[0]) < str(b[0]))
	var marks: Array = []
	var rows: Array = []
	var taken: Array = []
	for slot in slots:
		var part := str(slot[0])
		var kind := str(slot[1])
		var key := "%s." % part
		var have: Dictionary = src.get(part, {})
		var look := str(have.get("look", "")) if str(have.get("kind", "")) == kind else ""
		look = str(alias.get(look, look))
		var pool: Array = looks["fake"] if kind == "differs" and part == "authenticity" else (looks["stolen"] if kind == "differs" else looks["wear"])
		if look == "" or not pool.has(look):
			look = str(pool[mini(pool.size() - 1, int(ctx.draw("c.mg.param", [subject, "spot", key + "look"]) * pool.size()))]) if not pool.is_empty() else "scuff"
		var fine_p: int = int(cfg.get("fine_differs_permille", 700)) + (int(cfg.get("fine_craft_permille", 200)) if craft else 0) if kind == "differs" else int(cfg.get("fine_wear_permille", 300))
		var is_fine: bool = ctx.draw("c.mg.param", [subject, "spot", key + "fine"]) * 1000.0 < float(fine_p)
		var fine: int = E.range_int(ctx, "c.mg.param", [subject, "spot", key + "fv"], [600, 950] if is_fine else [150, 400])
		var at := _at(ctx, subject, key, rects[part], cfg.get("at_fine_px", [4, 6]) if is_fine else cfg.get("at_px", [5, 8]),
			body, edge_looks.has(look), taken, cfg)
		taken.append(at)
		var seed: int = int(have.get("seed", 0)) if not have.is_empty() else int(ctx.draw("c.mg.param", [subject, "spot", key + "seed"]) * 2147483647)
		marks.append({"part": part, "kind": kind, "look": look, "at": at, "fine": fine, "seed": seed})
		rows.append([part, kind, at[0], at[1], at[2], at[3], fine])
	var legend := {"wear": looks["wear"].duplicate(), "differs": looks["differs"].duplicate()}
	var parts: Array = (lay.get("parts", []) as Array).duplicate(true)
	# parts[].tool = which tool shows this part's mark: a fine mark (decoy or not) only shows under the lens.
	# Old minigames pick their tool from this; it says nothing about the truth (honest wear can be fine too).
	for part in parts:
		for mk in marks:
			if str(mk["part"]) == str(part.get("id", "")) and int(mk["fine"]) >= int(cfg.get("fine_cut", 500)):
				part["tool"] = "lens"
	p.merge({"parts": parts, "marks": marks, "legend": legend, "atlas_art": str(lay.get("atlas_art", "")), "atlas_open": false,
		"ink": int(aids.get("ink", 3)), "lens_px": int(aids.get("lens_px", 56)), "blink": bool(aids.get("blink", false)),
		"tools": (lay.get("tools", ["eye", "lens", "atlas"]) as Array).duplicate()}, true)
	return {"marks": rows, "tol": [int(cfg.get("tol_px", 2)), int(cfg.get("tol_fine_px", 1)), int(cfg.get("fine_cut", 500))]}

static func _slot_has(slots: Array, part: String) -> bool:
	for s in slots:
		if str(s[0]) == part:
			return true
	return false

## A small rect (item image pixels 0-63) where the mark is drawn and judged. With the item's body mask: a
## spot inside the part rect that is mostly body (body_pct of its pixels; a look that bites the outline,
## edge_body_pct and at least two outline pixels), clear of the marks already placed (grown by the judging
## tolerance, so one pin never names two marks); when the part rect has none (its rect was drawn for another
## picture), the near_spots nearest such spots anywhere in the picture. The draw picks among them. Without a
## mask (old cards): anywhere in the part rect.
static func _at(ctx: CardCtx, subject: String, key: String, rect: Array, size: Array, body: Dictionary = {},
		edge: bool = false, taken: Array = [], cfg: Dictionary = {}) -> Array:
	var rx := clampi(int(rect[0]), 0, 63)
	var ry := clampi(int(rect[1]), 0, 63)
	var rw := clampi(int(rect[2]), 1, 64 - rx)
	var rh := clampi(int(rect[3]), 1, 64 - ry)
	var dw := E.range_int(ctx, "c.mg.param", [subject, "spot", key + "w"], size)
	var dh := E.range_int(ctx, "c.mg.param", [subject, "spot", key + "h"], size)
	var u: float = ctx.draw("c.mg.param", [subject, "spot", key + "x"])
	var v: float = ctx.draw("c.mg.param", [subject, "spot", key + "y"])
	if not body.is_empty():
		var spots := _body_spots(body, Rect2i(rx, ry, rw, rh), dw, dh, edge, taken, cfg)
		if spots.is_empty():
			var mid := Vector2(rx + rw / 2.0, ry + rh / 2.0)
			var near: Array = []
			for s in _body_spots(body, Rect2i(0, 0, 64, 64), dw, dh, edge, taken, cfg):
				near.append([(Vector2(s) + Vector2(dw, dh) / 2.0).distance_squared_to(mid), s.y, s.x])
			near.sort()
			for row in near.slice(0, int(cfg.get("near_spots", 12))):
				spots.append(Vector2i(int(row[2]), int(row[1])))
		if not spots.is_empty():
			var at: Vector2i = spots[mini(spots.size() - 1, int(u * spots.size()))]
			return [at.x, at.y, dw, dh]
	var w := mini(rw, dw)
	var h := mini(rh, dh)
	var x := rx + mini(rw - w, int(u * (rw - w + 1)))
	var y := ry + mini(rh - h, int(v * (rh - h + 1)))
	return [x, y, w, h]

## Every top-left corner in area where a w x h spot sits on the body (see _at), row by row.
static func _body_spots(body: Dictionary, area: Rect2i, w: int, h: int, edge: bool, taken: Array, cfg: Dictionary) -> Array:
	var out: Array = []
	var need := float(cfg.get("edge_body_pct" if edge else "body_pct", 40 if edge else 60)) / 100.0
	var tol := int(cfg.get("tol_px", 2))
	for y in range(area.position.y, area.end.y - h + 1):
		for x in range(area.position.x, area.end.x - w + 1):
			if float(_sum(body["solid"], x, y, w, h)) < need * float(w * h):
				continue
			if edge and _sum(body["rim"], x, y, w, h) < 2:
				continue
			var clear := true
			for t in taken:
				if Rect2i(x, y, w, h).grow(tol).intersects(Rect2i(int(t[0]), int(t[1]), int(t[2]), int(t[3])).grow(tol)):
					clear = false
					break
			if clear:
				out.append(Vector2i(x, y))
	return out

## The body mask (items.json spot.opaque: 64 rows of 16 hex digits, one bit per opaque pixel, most significant
## first, rows joined by spaces) as summed-area tables: "solid" (opaque) and "rim" (opaque next to clear or
## the picture's border). {} when absent or malformed.
static func _body_sums(mask: String) -> Dictionary:
	var rows := mask.split(" ", false)
	if rows.size() != 64:
		return {}
	var bits := PackedByteArray()
	bits.resize(64 * 64)
	for y in 64:
		var row: String = rows[y]
		if row.length() != 16 or not row.is_valid_hex_number():
			return {}
		for d in 16:
			var nib := ("0x" + row[d]).hex_to_int()
			for b in 4:
				bits[y * 64 + d * 4 + b] = 1 if nib & (8 >> b) else 0
	var rim := PackedByteArray()
	rim.resize(64 * 64)
	for y in 64:
		for x in 64:
			if bits[y * 64 + x] == 0:
				continue
			for dv: Vector2i in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
				var q := Vector2i(x, y) + dv
				if q.x < 0 or q.y < 0 or q.x > 63 or q.y > 63 or bits[q.y * 64 + q.x] == 0:
					rim[y * 64 + x] = 1
					break
	return {"solid": _sum_table(bits), "rim": _sum_table(rim)}

static func _sum_table(bits: PackedByteArray) -> PackedInt32Array:
	var t := PackedInt32Array()
	t.resize(65 * 65)
	for y in 64:
		var run := 0
		for x in 64:
			run += bits[y * 64 + x]
			t[(y + 1) * 65 + x + 1] = t[y * 65 + x + 1] + run
	return t

static func _sum(t: PackedInt32Array, x: int, y: int, w: int, h: int) -> int:
	return t[(y + h) * 65 + x + w] - t[y * 65 + x + w] - t[(y + h) * 65 + x] + t[y * 65 + x]

## Category knowledge (same for every item of the category): the looks of honest wear and of tampering, old
## FlawRender names mapped (economy.json appraise.spot.look_alias) onto the look the minigame draws for them.
static func _looks(ctx: CardCtx, cat: String, alias: Dictionary = {}) -> Dictionary:
	if not ctx.ledger.has_meta("item_templates"):
		ctx.ledger.set_meta("item_templates", CardItems.templates())
	var rules: Dictionary = (ctx.ledger.get_meta("item_templates") as Dictionary).get("appraise", {}).get("categories", {}).get(cat, {})
	var wear: Array = []
	for k in rules.get("worn", []) + rules.get("wear", []):
		var w := str(alias.get(str(k), str(k)))
		if not wear.has(w):
			wear.append(w)
	var fake: Array = []
	for k in rules.get("fake", []):
		var f := str(alias.get(str(k), str(k)))
		if not fake.has(f):
			fake.append(f)
	var taken_from := str(rules.get("stolen", "scrape"))
	var stolen: Array = [str(alias.get(taken_from, taken_from))]
	var differs := fake.duplicate()
	for k in stolen:
		if not differs.has(k):
			differs.append(k)
	return {"wear": wear if not wear.is_empty() else ["scuff"], "fake": fake if not fake.is_empty() else ["speck"], "stolen": stolen, "differs": differs if not differs.is_empty() else ["speck"]}

## coin_ring (DESIGN 5.2): a stack of n coins (spec stack, default one); a fake stack has one or two dull coins.
## Decoys: worn good coins ring shorter but not lower; well made dull coins ring long enough but stay low.
## Review 3 (blind re-check 2, 10-26): only the pitch tells, as the panel's rule says. A plain dull coin rings and buzzes like a
## worn good one (spec ring_ms_bad / buzz_bad sit inside the worn range), a well made one like a fresh good one
## (ring_ms_good x well_made_ring_pct, buzz_good); so length and fuzz never give a coin away. The low band sits just
## under the good one (spec pitch_cents_bad): every dull coin is a little sparser than the silver sample, none at a glance.
static func _coin_ring(ctx: CardCtx, subject: String, spec: Dictionary, bad: bool, craft: bool, p: Dictionary, aids: Dictionary) -> Dictionary:
	var cfg: Dictionary = _cfg(ctx).get("coin_ring", {})
	var n := clampi(_sample(ctx, subject, &"coin_ring", "stack", spec.get("stack", [1, 1])), 1, 5)
	var bad_idx: Array = []
	if bad:
		var nb := 1
		if n >= int(cfg.get("stack_two_bad_from", 4)) and ctx.draw("c.mg.param", [subject, "coin_ring", "bad.n"]) < 0.5:
			nb = 2
		var pool: Array = range(n)
		for k in range(nb):
			bad_idx.append(pool.pop_at(mini(pool.size() - 1, int(ctx.draw("c.mg.param", [subject, "coin_ring", "bad.%d" % k]) * pool.size()))))
		bad_idx.sort()
	var ring_good: Array = spec.get("ring_ms_good", [1200, 1600])
	var ring_bad: Array = spec.get("ring_ms_bad", [840, 1360])
	# Good silver of one kind rings at one pitch (fix2): a narrow band, so on the trace a good coin is as dense as
	# the silver sample and only a dull one is sparser (the rule the panel states).
	var pitch_good: Array = spec.get("pitch_cents_good", [-8, 8])
	var pitch_bad: Array = spec.get("pitch_cents_bad", [-82, -52])
	var buzz_good: Array = spec.get("buzz_good", [0, 15])
	var buzz_bad: Array = spec.get("buzz_bad", [4, 25])
	var worn_p := int(spec.get("worn_permille", cfg.get("worn_permille", 350)))
	var made_p := int(spec.get("well_made_permille", cfg.get("well_made_permille", 400))) + (int(cfg.get("well_made_craft_permille", 300)) if craft else 0)
	var coins: Array = []
	for i in range(n):
		var key := "coin.%d." % i
		var coin := {"id": char(97 + i)}
		if bad_idx.has(i):
			coin["pitch_cents"] = _cr(ctx, subject, key + "pitch", pitch_bad)
			if ctx.draw("c.mg.param", [subject, "coin_ring", key + "made"]) * 1000.0 < float(made_p):
				coin["ring_ms"] = _cr(ctx, subject, key + "ring", ring_good) * _cr(ctx, subject, key + "ring_pct", cfg.get("well_made_ring_pct", [90, 100])) / 100
				coin["buzz"] = _cr(ctx, subject, key + "buzz", buzz_good)
			else:
				coin["ring_ms"] = _cr(ctx, subject, key + "ring", ring_bad)
				coin["buzz"] = _cr(ctx, subject, key + "buzz", buzz_bad)
		else:
			var ring := _cr(ctx, subject, key + "ring", ring_good)
			var buzz := _cr(ctx, subject, key + "buzz", buzz_good)
			if ctx.draw("c.mg.param", [subject, "coin_ring", key + "worn"]) * 1000.0 < float(worn_p):
				ring = ring * (100 - _cr(ctx, subject, key + "worn_cut", cfg.get("worn_ring_cut_pct", [15, 30]))) / 100
				buzz += _cr(ctx, subject, key + "worn_buzz", cfg.get("worn_buzz_add", [0, 10]))
			coin["ring_ms"] = ring
			coin["pitch_cents"] = _cr(ctx, subject, key + "pitch", pitch_good)
			coin["buzz"] = buzz
		coins.append(coin)
	var jitter: Array = [-int(cfg.get("sample_jitter_pct", 3)), int(cfg.get("sample_jitter_pct", 3))]
	var samples: Array = []
	for row in [["good", ring_good, pitch_good, buzz_good], ["dull", ring_bad, pitch_bad, buzz_bad]]:
		var sk := "sample.%s." % str(row[0])
		samples.append({"id": str(row[0]), "ring_ms": _mid(row[1]) * (100 + _cr(ctx, subject, sk + "ring", jitter)) / 100,
			"pitch_cents": _mid(row[2]) + _cr(ctx, subject, sk + "pitch", jitter),
			"buzz": maxi(0, _mid(row[3]) * (100 + _cr(ctx, subject, sk + "buzz", jitter)) / 100)})
	p.merge({"coins": coins, "reference": {"ring_ms": int(samples[0]["ring_ms"]), "pitch_cents": int(samples[0]["pitch_cents"]), "buzz": int(samples[0]["buzz"])},
		"samples": samples, "tries": int(aids.get("tries", 4)), "ghosts": int(aids.get("ghosts", 1)), "clink": n >= 2}, true)
	return {"bad": bad_idx, "n": n}

## weigh (DESIGN 6.2): the weight box comes from the rules (B2: every claimed range can be balanced).
static func _weigh(ctx: CardCtx, subject: String, spec: Dictionary, bad: bool, p: Dictionary, aids: Dictionary) -> Dictionary:
	var cfg: Dictionary = _cfg(ctx).get("weigh", {})
	var tool := str(spec.get("tool", "dengzi"))
	var claimed := _range(ctx, subject, &"weigh", "claimed", spec.get("claimed_fen", [280, 320]))
	var dev := _range(ctx, subject, &"weigh", "deviation", spec.get("dev_bad_pct" if bad else "dev_worn_pct", [0, 2]))
	var actual := maxi(1, claimed * (100 - dev) / 100)
	var res := maxi(1, int(spec.get("resolution_fen", 1)))
	# The weight sits on one of the scale's own steps (rounded toward the claim, so the gap is never wider than the
	# spec drew): one step levels the beam with the needle dead straight and the stars read the weight exactly, so
	# a careful reading always lands in the answer's own category (steelyard 1 qian, ten-liang bar 2 fen).
	if actual % res != 0:
		actual = (actual / res + (1 if actual < claimed else 0)) * res
	actual = maxi(res, actual)
	var weights = spec.get("weights_fen")
	if typeof(weights) != TYPE_ARRAY:
		weights = cfg.get("boxes", {}).get(str(spec.get("weight_box", tool)), [1, 2, 5, 10, 20, 50, 100, 200])
	var small := int(spec.get("small_fen", maxi(res, claimed * int(cfg.get("small_permille", 60)) / 1000)))
	p.merge({"tool": tool, "claimed_fen": claimed, "actual_fen": actual, "weights_fen": (weights as Array).duplicate(),
		"resolution_fen": res, "small_fen": small, "zoom": int(aids.get("zoom", 2)), "minor_ticks": bool(aids.get("minor_ticks", false)),
		"needle_gain": int(aids.get("needle_gain", 6))}, true)
	return {"cat": weigh_cat(actual - claimed, res, small)}

## actual - claimed -> match / light_small / light_much / heavy (DESIGN 6.2; replaces the old 60 permille ratio).
static func weigh_cat(d: int, res: int, small: int) -> String:
	if absi(d) <= res:
		return "match"
	if d > res:
		return "heavy"
	return "light_small" if -d <= small else "light_much"

## fragments (DESIGN 7.2, B3): a sound document has its seal aligned and one kind of paper; a forgery has an
## offset seal and/or odd paper pieces (at least one). A water stain is the decoy, on either.
## A forged seal is off by the cut (2 px) and no more (acceptance r2): 3 px and up read at a glance once the sheet
## is whole, 2 px needs the glass. Specs without seal_offset_px_bad fall back to [0, cut].
static func _fragments(ctx: CardCtx, subject: String, spec: Dictionary, bad: bool, is_item: bool, p: Dictionary, aids: Dictionary) -> Dictionary:
	var cfg: Dictionary = _cfg(ctx).get("fragments", {})
	var cut := int(cfg.get("seal_off_px", 2))
	var pieces := maxi(1, _sample(ctx, subject, &"fragments", "pieces", spec.get("pieces", 6)))
	if is_item:
		pieces = mini(pieces, int(cfg.get("item_pieces_max", 6)))
	var missing := int(spec.get("missing_piece", -1))
	if missing >= pieces:
		missing = -1
	var free: Array = []
	for i in range(pieces):
		if i != missing:
			free.append(i)
	var seal := 0
	if spec.has("seal_offset_px_good") or spec.has("seal_offset_px_bad"):
		seal = _sample(ctx, subject, &"fragments", "seal", spec.get("seal_offset_px_bad" if bad else "seal_offset_px_good", [0, cut] if bad else [0, 0]))
		if bad and seal < cut:
			seal = 0
	else:
		seal = _sample(ctx, subject, &"fragments", "seal", spec.get("seal_offset_px", 0))
	var odd: Array = []
	if is_item and bad:
		# Old specs without ink_mismatch_bad keep the old single odd piece.
		var count := _sample(ctx, subject, &"fragments", "odd", spec.get("ink_mismatch_bad", 1))
		if seal < cut:
			count = maxi(1, count)
		odd = _pick(ctx, subject, "odd", free, count)
	elif not is_item:
		for x in spec.get("ink_mismatch", []):
			if free.has(int(x)) and not odd.has(int(x)):
				odd.append(int(x))
	odd.sort()
	var stain := -1
	var clean: Array = free.filter(func(i: int) -> bool: return not odd.has(i))
	if not clean.is_empty() and ctx.draw("c.mg.param", [subject, "fragments", "stain"]) * 1000.0 < float(int(spec.get("stain_permille", cfg.get("stain_permille", 500)))):
		stain = int(clean[mini(clean.size() - 1, int(ctx.draw("c.mg.param", [subject, "fragments", "stain.at"]) * clean.size()))])
	p.merge({"doc": str(spec.get("doc", "pawn_ticket")), "pieces": pieces, "seal_offset_px": seal, "ink_mismatch": odd,
		"dangzi_marks": _sample(ctx, subject, &"fragments", "dangzi", spec.get("dangzi_marks", 2)), "missing_piece": missing,
		"stain": stain, "rotate": bool(spec.get("rotate", false)), "lens_px": int(aids.get("lens_px", 56)), "backlight": bool(aids.get("backlight", false))}, true)
	return {"seal_off": seal >= cut, "odd": odd, "pieces": pieces, "present": free.size()}

static func _pick(ctx: CardCtx, subject: String, name: String, from: Array, count: int) -> Array:
	var pool := from.duplicate()
	var out: Array = []
	for k in range(mini(count, pool.size())):
		out.append(pool.pop_at(mini(pool.size() - 1, int(ctx.draw("c.mg.param", [subject, "fragments", "%s.%d" % [name, k]]) * pool.size()))))
	return out

## decode (DESIGN 8.2, B6): the engine hands over the whole code book (the minigame no longer reads files),
## the true groups, smudged digits whose other reading is mostly another real entry, and an optional key shift.
static func _decode(ctx: CardCtx, subject: String, spec: Dictionary, doc: Dictionary, p: Dictionary, aids: Dictionary) -> Dictionary:
	var book := _codebook(ctx)
	var rows: Array = book["rows"]
	var in_book := {}
	for row in rows:
		in_book[str(row[0])] = str(row[1])
	var codes: Array = []
	for c in spec.get("codes", []):
		codes.append(str(c))
	if codes.is_empty() and not rows.is_empty():
		var pool: Array = rows.map(func(row: Array) -> String: return str(row[0]))
		for k in range(mini(int(_cfg(ctx).get("decode", {}).get("groups_default", 4)), pool.size())):
			codes.append(str(pool.pop_at(mini(pool.size() - 1, int(ctx.draw("c.mg.param", [subject, "decode", "code.%d" % k]) * pool.size())))))
	var words: Array = []
	for row in rows:
		if codes.has(str(row[0])):
			words.append(str(row[1]))
	var shift := clampi(int(spec.get("key_shift", 0)), 0, 9)
	var want := maxi(0, int(spec.get("smudges", 1)) - int(aids.get("smudge_less", 0)))
	# Acceptance fix2 (10-25): a document may list the other readings its writer checked to make no sense in this
	# message (decode.smudge_alts); then no other book entry is ever offered, so the true reading is the only one
	# that reads (a smudge that reads both ways, or reads better the wrong way, cannot be seen through).
	var checked: Array = []
	for a in _arr(spec.get("smudge_alts", [])):
		checked.append(str(a))
	p.merge({"cipher": str(spec.get("cipher", "telegraph")), "message": str(spec.get("message", doc.get("id", ""))), "codes": codes,
		"book_words": words, "book": rows.duplicate(true), "smudges": _smudges(ctx, subject, codes, in_book, shift, want, checked),
		"key_shift": shift, "crib": str(spec.get("crib", book["crib"]))}, true)
	return {"codes": codes}

## [group, digit, alt]: digit `digit` of group `group` is smudged on the slip; read the other way it gives code `alt`
## (already un-shifted, i.e. what the player would look up). Prefers alts that are real entries; one per group.
## With `checked` (the document's smudge_alts) only those book entries may be offered; a reading that is not in
## the book at all is the fallback (it cannot make sense either); any other book entry is never used.
static func _smudges(ctx: CardCtx, subject: String, codes: Array, in_book: Dictionary, shift: int, want: int, checked: Array = []) -> Array:
	var cands: Array = []
	for g in range(codes.size()):
		var code := str(codes[g])
		for d in range(code.length()):
			if not code[d].is_valid_int():
				continue
			var shown := str((int(code[d]) + shift) % 10)
			for partner in CONFUSABLE.get(shown, []):
				var alt := code.substr(0, d) + str((int(partner) - shift + 10) % 10) + code.substr(d + 1)
				var u: float = ctx.draw("c.mg.param", [subject, "decode", "smudge.%d.%d.%s" % [g, d, alt]])
				if in_book.has(alt) and not checked.is_empty() and not checked.has(alt):
					continue
				cands.append([0 if in_book.has(alt) else 1, u, g, d, alt])
	cands.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0] or (a[0] == b[0] and a[1] < b[1]))
	var out: Array = []
	var used := {}
	for c in cands:
		if out.size() >= want:
			break
		if used.has(c[2]):
			continue
		used[c[2]] = true
		out.append([int(c[2]), int(c[3]), str(c[4])])
	out.sort()
	return out

static func _codebook(ctx: CardCtx) -> Dictionary:
	var book = CardDB.read_json(ctx.db.set_base() + "/minigames/codebook.json")
	var rows: Array = []
	var crib := ""
	if typeof(book) == TYPE_DICTIONARY:
		crib = str(book.get("crib", ""))
		for row in book.get("entries", []):
			rows.append([str(row.get("code", "")), str(row.get("key", ""))])
		var ids: Array = book.get("codes", {}).keys()
		ids.sort()
		for code in ids:
			rows.append([str(code), str(book["codes"][code].get("key", ""))])
	rows.sort_custom(func(a: Array, b: Array) -> bool: return str(a[0]) < str(b[0]))
	return {"rows": rows, "crib": crib}

static func _doc_spec(doc: Dictionary, kind: StringName) -> Dictionary:
	var spec = doc.get(str(kind), doc.get("params", {}))
	return spec if typeof(spec) == TYPE_DICTIONARY else {}

static func _cfg(ctx: CardCtx) -> Dictionary:
	return ctx.rules("economy").get("appraise", {})

static func _cr(ctx: CardCtx, subject: String, key: String, bounds: Array) -> int:
	return E.range_int(ctx, "c.mg.param", [subject, "coin_ring", key], bounds)

static func _mid(bounds: Array) -> int:
	return (int(bounds[0]) + int(bounds[1 if bounds.size() > 1 else 0])) / 2

static func _arr(v) -> Array:
	return v if typeof(v) == TYPE_ARRAY else []

static func _range(ctx: CardCtx, item: String, kind: StringName, key: String, bounds: Array) -> int:
	return E.range_int(ctx, "c.mg.param", [item, str(kind), key], bounds)

static func _sample(ctx: CardCtx, item: String, kind: StringName, key: String, spec) -> int:
	return _range(ctx, item, kind, key, spec) if typeof(spec) == TYPE_ARRAY else int(spec)

static func _spec(ctx: CardCtx, item: String) -> Dictionary:
	var template := str(E.meta(ctx, item).get("template", ""))
	for id in ctx.db.ids_of(&"item"):
		var d := ctx.db.def(id)
		if str(d.get("template", "")) == template:
			return d
	return {}
