# K14 W1: Mock scenario, seed 7, autoplay 7 days twice (guide forced on, then off).
# The command lists match once ui.guide is removed. The on-run day-4 snapshot of shown_log
# equals _test.d1_3 (data/cards/guide/steps.json if K16 has landed, otherwise the W0 examples).
# The W0 stub table has no 1.3 scene anchors, so gd.d1.ticket (a.scene.ledger) never lights
# and the day-4 snapshot stops at gd.d1.tiers. Register the same stand-ins as K16_d1_3_mock
# after the stub's _ready, then the real 21-step list can complete. Guide off sends no ui.guide.
# Virtual clock only: skip_fades and tick(0.5). No sleep. The reader presses "got it" on each bubble
# (10-22 prototype flow); the Mock scenario's day-4 snapshot is MOCK_D1_3 (same steps as _test.d1_3).
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const U = preload("res://scripts/tests/cards/K14/qa_util.gd")
const EXAMPLES := "res://data/cards/_examples/guide/steps.json"
const REAL_STEPS := "res://data/cards/guide/steps.json"
## The Mock scenario is not the 1938 tutorial: the brother's gold card is the farewell on day 2 (no day-1
## handover), so gd.d2.gold and gd.choice come on day 2; and this reader presses "got it" on gd.d1.look
## before looking, so gd.d1.tiers lights before the minigame's gd.d1.spot. Same 21 steps as _test.d1_3.
const MOCK_D1_3: Array[String] = ["gd.m.open", "gd.m.wheel", "gd.m.incense", "gd.d1.notice", "gd.d1.deal",
	"gd.d1.person", "gd.d1.close", "gd.d1.look", "gd.d1.tiers", "gd.d1.spot", "gd.d1.ticket", "gd.d1.shelf",
	"gd.d1.buyer", "gd.d1.night", "gd.d1.settle", "gd.d2.rules", "gd.d2.gold", "gd.choice", "gd.d2.keep",
	"gd.slots", "gd.coins"]


func _initialize() -> void:
	var t := T.new(self, "K14_guide_onoff_mock")
	t.run_async(_body.bind(t))


func _body(t) -> void:
	var on_run: Dictionary = await _run(t, true)
	var off_run: Dictionary = await _run(t, false)
	_cmp_cmds(t, on_run["sent"], off_run["sent"])
	var steps_path := REAL_STEPS if FileAccess.file_exists(REAL_STEPS) else EXAMPLES
	if steps_path == EXAMPLES:
		print("NOTE: data/cards/guide/steps.json missing; days 1-3 compared to examples _test.d1_3")
	var doc = CardDB.read_json(steps_path)
	var want: Array = doc.get("_test", {}).get("d1_3", []) if typeof(doc) == TYPE_DICTIONARY else []
	t.ok(not want.is_empty(), "guide file has _test.d1_3")
	t.ok(bool(on_run["snapped"]), "saw the morning of day 4 with guide on")
	t.eq(on_run["snap"], Array(MOCK_D1_3), "guide on shown_log through day 3 is the Mock scenario's order")
	var got_sorted: Array = Array(on_run["snap"]).duplicate()
	got_sorted.sort()
	var want_sorted: Array = want.duplicate()
	want_sorted.sort()
	t.eq(got_sorted, want_sorted, "the same steps as _test.d1_3")
	_check_shows(t, on_run["log"], on_run["meta"])
	t.eq(off_run["log"], [], "guide off shown_log is empty")
	var leaked := false
	for row in off_run["sent"]:
		if str(row[0]) == "ui.guide":
			leaked = true
			break
	t.ok(not leaked, "guide off sent no ui.guide")
	print("K14 GUIDE on_day4=%s on_full=%s" % [",".join(PackedStringArray(on_run["snap"])), ",".join(PackedStringArray(on_run["log"]))])


func _run(t, guide_on: bool) -> Dictionary:
	var bus := CardEventBus.new()
	root.add_child(bus)
	var game: CardGameRoot = load(CardIds.ROOT_SCENE).instantiate()
	game.boot({"mock": true, "bus": bus, "seed": 7, "skip_title": true, "guide": "on" if guide_on else "off"})
	root.add_child(game)
	game.guide.skip_fades = true
	game.guide.force(guide_on)
	await t.frames(2)
	var snap: Array = []
	var snapped := false
	var steps := 0
	var phase := ""
	var sd := 0
	while steps < 2500:
		var v := game.engine.view()
		phase = str(v.get("phase", ""))
		sd = int(v.get("date", {}).get("stage_day", 0))
		if phase == "morning" and sd == 4 and not snapped:
			snap = Array(game.guide.shown_log)
			snapped = true
		if phase == "morning" and sd >= 8:
			break
		game.autoplay_step()
		await t.frames(1)
		game.guide.tick(0.5)
		game.guide.evaluate_now()
		# The reader: presses "got it" on every bubble before the next action (10-22 prototype flow).
		var reads := 0
		while game.guide.active_step() != "" and reads < 8:
			game.guide.acknowledge()
			game.guide.tick(0.5)
			game.guide.evaluate_now()
			reads += 1
		steps += 1
	await t.frames(2)
	t.ok(phase == "morning" and sd >= 8, "guide %s walked 7 days (phase=%s day=%d steps=%d)" % [
		"on" if guide_on else "off", phase, sd, steps])
	var sent: Array = []
	if game.engine is MockCardEngine:
		sent = (game.engine as MockCardEngine).sent.duplicate(true)
	var meta := {}
	var data: Dictionary = game.engine.query(&"guide_data")
	for s in data.get("steps", []):
		if typeof(s) == TYPE_DICTIONARY:
			meta[str(s.get("id", ""))] = int(s.get("max_shows", 2))
	var log: Array = Array(game.guide.shown_log)
	game.queue_free()
	bus.queue_free()
	CardAnchors.clear()
	await t.frames(2)
	return {"sent": sent, "log": log, "snap": snap, "snapped": snapped, "meta": meta}


func _cmp_cmds(t, on_sent: Array, off_sent: Array) -> void:
	var a := _strip(on_sent)
	var b := _strip(off_sent)
	if a.size() != b.size():
		t.ok(false, "command count guide-on=%d guide-off=%d" % [a.size(), b.size()])
		return
	for i in range(a.size()):
		var sa := JSON.stringify(CardState.int_restore(a[i]), "", true)
		var sb := JSON.stringify(CardState.int_restore(b[i]), "", true)
		if sa != sb:
			t.ok(false, "command mismatch at %d" % i)
			print("K14 GUIDE MISMATCH on=", U.ascii_snip(sa))
			print("K14 GUIDE MISMATCH off=", U.ascii_snip(sb))
			return
	t.ok(true, "guide on/off commands match (%d)" % a.size())


func _strip(sent: Array) -> Array:
	var out: Array = []
	for row in sent:
		if str(row[0]) != "ui.guide":
			out.append(row)
	return out


func _check_shows(t, log: Array, meta: Dictionary) -> void:
	var counts := {}
	for id in log:
		var key := str(id)
		t.ok(meta.has(key), "shown step is in guide_data: " + key)
		counts[key] = int(counts.get(key, 0)) + 1
	for key in counts.keys():
		var cap := int(meta.get(key, 2))
		t.ok(int(counts[key]) <= cap, "shows %d <= max_shows %d for %s" % [int(counts[key]), cap, key])
	t.ok(true, "shown_log checked against current steps")
