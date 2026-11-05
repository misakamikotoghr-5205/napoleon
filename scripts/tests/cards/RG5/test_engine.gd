# RG5_engine: game.new {run} (zero identity without it, the frozen run block, bad arguments), og.shanghai on the
# tutorial days, the opening notice, legacy.harvest (read only, frags, the four chronicle keys) and legacy.old_ink.
# Owner RG5. docs/cards/rogue/ROGUE_V1.md §3.3, §4.1, §4.3, §4.4, §5.6.
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const H = preload("res://scripts/tests/cards/RG5/helper.gd")
const Runner := preload("res://scripts/cards/sim/balance_main.gd")
const Telemetry := preload("res://scripts/cards/sim/telemetry.gd")
const GOLDEN := "res://scripts/tests/cards/golden/golden.json"


func _initialize() -> void:
	var t := T.new(self, "RG5_engine")
	_zero_identity(t)
	var root := H.data_root(t)
	_context(t, root)
	_bad_args(t, root)
	_shanghai(t, root)
	_default_opening(t, root)
	_harvest(t, root)
	_chronicle(t, root)
	_old_ink(t, root)
	t.finish()


## No run / run {} on the example set: no run key anywhere, and the golden day-10 hash is unchanged.
func _zero_identity(t) -> void:
	var golden := ""
	for case in CardDB.read_json(GOLDEN).get("cases", []):
		if str(case.get("data", "")) == "examples":
			for row in case.get("hashes", []):
				if int(row.get("abs_day", 0)) == 10:
					golden = str(row.get("hash", ""))
	t.ok(golden != "", "golden example case has a day-10 hash")
	var got: Array = []
	for run in [null, {}]:
		var opts := {"seed": 7, "only_examples": true, "save_dir": t.user_dir() + "/zero"}
		if run != null:
			opts["run"] = run
		var bus := CardEventBus.new()
		var engine := CardEngine.new(bus)
		var observer: RefCounted = Telemetry.new()
		observer.attach(engine, CardDB.load_all("res://data/cards", {"only_examples": true}))
		t.ok(bool(engine.new_game(opts).get("ok", false)), "zero: new_game ok (run %s)" % [run])
		t.ok(not engine.ctx.state.data.has("run"), "zero: no run namespace right after new_game")
		CardAutoplay.play(engine, Runner.POLICIES["fair"].new(7), {"days": 10, "max_steps": 10000})
		t.ok(not engine.ctx.state.data.has("run"), "zero: no run namespace after 10 days")
		t.ok(not engine.view().has("run"), "zero: no run block in the view")
		var day10 := ""
		for row in observer.hashes:
			if int(row["abs_day"]) == 10:
				day10 = str(row["hash"])
		got.append(day10)
		t.eq(day10, golden, "zero: day-10 hash equals the golden example case (run %s)" % [run])
		bus.free()
	t.eq(got[0], got[1], "zero: run {} hashes like no run at all")


## A valid run: state.run is frozen with known deduplicated, sorted and filtered to existing dossier fragments.
func _context(t, root: String) -> void:
	var run := {"no": 3, "opening": "og.shanghai", "known": ["df.linsao.1938.husband", "df.brother.1938.farewell",
		"df.linsao.1938.husband", "df.nope.1938.gone", "p.zhang.1938.tut_pawn"]}
	var e := H.engine(root, t.user_dir() + "/context", 7, run)
	t.eq(e.ctx.state.data.get("run"), {"_v": 1, "no": 3, "opening": "og.shanghai",
		"known": ["df.brother.1938.farewell", "df.linsao.1938.husband"]}, "state.run frozen at game.new")
	t.eq(e.view().get("run"), {"no": 3, "opening": "og.shanghai"}, "view.run")
	t.no_leaks(e.view(), "view with run")
	t.eq(t.find_floats(e.ctx.state.data), PackedStringArray(), "no floats with a run")
	var first: Array = e.command_log()[0] if not e.command_log().is_empty() else []
	t.eq(first.size(), 2, "game.new is the first log entry")
	if first.size() == 2:
		t.eq(first[1].get("run"), run, "run travels in the command log as given")
	var minimal := H.engine(root, t.user_dir() + "/context_min", 7, {"no": 1})
	t.eq(minimal.ctx.state.data.get("run"), {"_v": 1, "no": 1, "opening": "og.default", "known": []},
		"opening and known default when left out")
	var before := e.state_hash()
	e.send(&"day.end", {"confirm": true})
	t.eq(e.ctx.state.data["run"]["known"], ["df.brother.1938.farewell", "df.linsao.1938.husband"], "known never changes in play")
	t.ok(e.state_hash() != before, "the game moves on")


## Bad run arguments: bad_args, and the running game's state is untouched.
func _bad_args(t, root: String) -> void:
	var e := H.engine(root, t.user_dir() + "/bad", 7, {"no": 1})
	e.send(&"day.end", {"confirm": true})
	var before := e.state_hash()
	var day: Dictionary = e.view()["date"]
	var bad: Array = [{"no": 0}, {"no": "3"}, {"no": 1, "opening": "og.nope"}, {"no": 1, "opening": 5},
		{"no": 1, "known": "df.brother.1938.farewell"}, {"no": 1, "known": [1]}, {"opening": "og.default"}, "run"]
	for run in bad:
		var r := e.new_game({"seed": 9, "data_root": root, "save_dir": t.user_dir() + "/bad", "run": run})
		t.eq(r.get("err"), "bad_args", "bad run %s -> bad_args" % [run])
		t.eq(e.state_hash(), before, "bad run %s leaves the state alone" % [run])
	t.eq(e.view()["date"], day, "still the same day after the refused new games")


## og.shanghai: day 1 has no tutorial cards but random customers, the opening notice; day 2 the brother's farewell.
func _shanghai(t, root: String) -> void:
	var e := H.engine(root, t.user_dir() + "/shanghai", 7, {"no": 2, "opening": "og.shanghai"})
	t.ok(H.to_morning(e, 1), "shanghai: first morning")
	t.ok(_notices(e).has("rg5.notice.shanghai"), "shanghai: the opening notice is on the first morning")
	t.ok(e.ctx.test({"veteran": true}) and not e.ctx.test({"veteran": false}), "shanghai: veteran is true")
	t.ok(bool(e.send(&"day.begin").get("ok", false)), "shanghai: day 1 opens")
	var day1 := H.hand_defs(e)
	for id in H.TUTORIAL_GATED:
		t.ok(not day1.has(id), "shanghai: no tutorial card %s on day 1" % id)
	t.ok(day1.any(func(d: String) -> bool: return d.begins_with("p.")), "shanghai: day 1 deals random customers")
	t.ok(not CardComposer.is_scripted_day(e.ctx), "shanghai: day 1 is not a scripted day")
	t.no_leaks(e.view(), "shanghai day 1 view")
	t.ok(H.to_morning(e, 2), "shanghai: second morning")
	t.ok(not _notices(e).has("rg5.notice.shanghai"), "shanghai: the notice is only on day 1")
	e.send(&"day.begin")
	var day2 := H.hand_defs(e)
	t.ok(day2.has("p.brother.1938.farewell"), "shanghai: the brother still says goodbye on day 2")
	for id in H.TUTORIAL_GATED:
		t.ok(not day2.has(id), "shanghai: no tutorial card %s on day 2" % id)


## og.default plays the tutorial days exactly like a game without a run.
func _default_opening(t, root: String) -> void:
	var hands: Array = []
	for run in [{}, {"no": 1, "opening": "og.default"}]:
		var e := H.engine(root, t.user_dir() + "/default", 7, run)
		t.ok(H.to_morning(e, 1), "default: first morning")
		t.ok(not _notices(e).has("rg5.notice.shanghai"), "default: no opening notice")
		t.ok(not e.ctx.test({"veteran": true}), "default: veteran is false")
		e.send(&"day.begin")
		t.ok(CardComposer.is_scripted_day(e.ctx), "default: day 1 is a scripted day")
		hands.append(H.hand_defs(e))
	t.ok((hands[1] as Array).has("p.brother.1938.tut_handover") and (hands[1] as Array).has("p.zhang.1938.tut_pawn"),
		"default: day 1 is the tutorial")
	t.eq(hands[1], hands[0], "default: the same day-1 hand as without a run")


func _notices(e: CardEngine) -> Array:
	var out: Array = []
	for row in e.view().get("notice", {}).get("news", []):
		out.append(str(row.get("key", "")))
	return out


## legacy.harvest {} is read only, leak free and lists exactly the fragments this ledger holds.
func _harvest(t, root: String) -> void:
	var e := H.engine(root, t.user_dir() + "/harvest", 7, {"no": 2, "opening": "og.default"})
	H.to_morning(e, 1)
	CardDossier.add(e.ctx, "df.linsao.1938.husband")
	CardDossier.add(e.ctx, "df.zhao.1938.borrow")
	CardDossier.gap(e.ctx, "df.zhao.1938.borrow")
	var before := e.state_hash()
	var h := e.query(&"legacy.harvest", {})
	t.eq(e.state_hash(), before, "harvest is read only")
	t.no_leaks(h, "harvest")
	t.eq(t.find_floats(h), PackedStringArray(), "harvest has no floats")
	t.eq([h.get("ok"), h.get("no"), h.get("phase"), h.get("stage"), h.get("era"), h.get("stage_day"), h.get("reason")],
		[true, 2, "morning", 0, "1938", 1, ""], "harvest header")
	var expect: Array = []
	for page in CardDossier.view(e.ctx)["pages"]:
		for f in page["fragments"]:
			if f["state"] == "have":
				expect.append(f["id"])
	expect.sort()
	t.eq(h.get("frags"), expect, "harvest frags = the fragments held")
	t.ok((h["frags"] as Array).has("df.linsao.1938.husband"), "harvest has the added fragment")
	t.ok(not (h["frags"] as Array).has("df.zhao.1938.borrow"), "a torn-out fragment is not harvested")
	t.ok(not h.has("chronicle"), "no chronicle without close")
	t.eq(e.query(&"legacy.harvest", {"close": 5}).get("err"), "bad_args", "close must be a string")
	var plain := H.engine(root, t.user_dir() + "/harvest_plain", 7, {})
	t.eq(plain.query(&"legacy.harvest", {}).get("no"), 0, "no run: no is 0")
	t.eq(plain.query(&"legacy.harvest", {}).get("ok"), true, "no run: harvest still answers")


## The chronicle keys of §5.6; the conscience meter only picks the ending key.
func _chronicle(t, root: String) -> void:
	var e := H.engine(root, t.user_dir() + "/chronicle", 7, {"no": 1})
	H.to_morning(e, 3)
	var cases := [["prison", "rg5.chronicle.prison.1938", {"d": 3}], ["abandoned", "rg5.chronicle.abandoned.1938", {"d": 3}],
		["street", "rg5.chronicle.other", {"d": 3}]]
	for c in cases:
		var line: Dictionary = e.query(&"legacy.harvest", {"close": c[0]}).get("chronicle", {})
		t.eq(line, {"key": c[1], "args": c[2]}, "chronicle for close " + str(c[0]))
	var meters: Dictionary = e.ctx.state.ns("rules")["meters"]
	var keep = meters.get("conscience", 0)
	for row in [[25, "rg5.chronicle.ending.kind"], [20, "rg5.chronicle.ending.kind"], [0, "rg5.chronicle.ending.plain"],
			[-20, "rg5.chronicle.ending.hard"], [-25, "rg5.chronicle.ending.hard"]]:
		meters["conscience"] = row[0]
		var before := e.state_hash()
		var h := e.query(&"legacy.harvest", {"close": "ending"})
		t.eq(h.get("chronicle"), {"key": row[1], "args": {}}, "ending chronicle at conscience %d" % row[0])
		t.eq(e.state_hash(), before, "ending harvest is read only")
		t.no_leaks(h, "ending harvest")
	meters["conscience"] = keep
	var loop: Dictionary = e.ctx.state.ns("loop")
	loop["stage"] = 1
	t.eq(e.query(&"legacy.harvest", {"close": "prison"}).get("chronicle"), {"key": "rg5.chronicle.prison.1939", "args": {"d": 3}},
		"prison chronicle in 1939")
	t.eq(e.query(&"legacy.harvest", {"close": "abandoned"}).get("era"), "1939", "era follows the stage")
	loop["stage"] = 2
	t.eq(e.query(&"legacy.harvest", {"close": "abandoned"}).get("chronicle"),
		{"key": "rg5.chronicle.abandoned.1940", "args": {"d": 3}}, "abandoned chronicle in 1940")
	loop["stage"] = 0


## legacy.old_ink: run.known minus have and gaps, one page per person (sorted), fragments by order then id.
func _old_ink(t, root: String) -> void:
	var known := ["df.zhao.1938.land", "df.linsao.1938.husband", "df.linsao.1938.hairpin", "df.brother.1938.farewell",
		"df.zhao.1938.borrow", "df.linsao.1938.term"]
	var e := H.engine(root, t.user_dir() + "/ink", 7, {"no": 4, "known": known})
	CardDossier.add(e.ctx, "df.linsao.1938.hairpin")
	CardDossier.add(e.ctx, "df.zhao.1938.borrow")
	CardDossier.gap(e.ctx, "df.zhao.1938.borrow")
	var before := e.state_hash()
	var ink := e.query(&"legacy.old_ink", {})
	t.eq(e.state_hash(), before, "old_ink is read only")
	t.no_leaks(ink, "old_ink")
	t.eq(ink, {"ok": true, "err": "", "pages": [
		{"person": "brother", "fragments": [{"id": "df.brother.1938.farewell", "order": 1}]},
		{"person": "linsao", "fragments": [{"id": "df.linsao.1938.husband", "order": 2}, {"id": "df.linsao.1938.term", "order": 4}]},
		{"person": "zhao", "fragments": [{"id": "df.zhao.1938.land", "order": 2}]}]}, "old ink pages")
	t.ok(not e.ctx.test({"dossier_has": "df.linsao.1938.husband"}), "old ink does not count as held")
	t.ok(not CardDossier.complete(e.ctx, "linsao"), "old ink never completes a page")
	var plain := H.engine(root, t.user_dir() + "/ink_plain", 7, {})
	t.eq(plain.query(&"legacy.old_ink", {}), {"ok": true, "err": "", "pages": []}, "no run: no old ink")
