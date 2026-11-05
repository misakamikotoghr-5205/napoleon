# K16: new-game days 1-3 on the real table + Mock scenario light the 21 steps of _test.d1_3.
# Virtual clock (skip_fades, tick 0.5, evaluate_now): this checks the data and the order, not that the
# guide lights in real time (that is C16/test_guide_realtime.gd). The reader presses "got it" each time.
# cards holds all 67 steps. This test reloads that array with CardGuide.load_steps before the first frame.
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")
## The Mock scenario is not the 1938 tutorial: the brother's gold card is the farewell on day 2 (no day-1
## handover), so gd.d2.gold and gd.choice come on day 2; and this reader presses "got it" on gd.d1.look
## before looking, so gd.d1.tiers lights before the minigame's gd.d1.spot. Same 21 steps as _test.d1_3.
const MOCK_D1_3: Array[String] = ["gd.m.open", "gd.m.wheel", "gd.m.incense", "gd.d1.notice", "gd.d1.deal",
	"gd.d1.person", "gd.d1.close", "gd.d1.look", "gd.d1.tiers", "gd.d1.spot", "gd.d1.ticket", "gd.d1.shelf",
	"gd.d1.buyer", "gd.d1.night", "gd.d1.settle", "gd.d2.rules", "gd.d2.gold", "gd.choice", "gd.d2.keep",
	"gd.slots", "gd.coins"]


func _initialize() -> void:
	var t := T.new(self, "K16_d1_3_mock")
	t.run_async(_body.bind(t))


func _body(t) -> void:
	var raw: Dictionary = CardDB.read_json("res://data/cards/guide/steps.json")
	var want: Array = raw.get("_test", {}).get("d1_3", [])
	t.ok(want.size() == 21, "_test.d1_3 has 21 steps")
	var bus := CardEventBus.new()
	root.add_child(bus)
	var game: CardGameRoot = load(CardIds.ROOT_SCENE).instantiate()
	game.boot({"mock": true, "bus": bus, "seed": 7, "skip_title": true, "guide": "on"})
	root.add_child(game)
	game.guide.force(true)
	game.guide.skip_fades = true
	var settings: Dictionary = game.engine.query(&"guide_data").get("settings", {})
	game.guide.load_steps({"steps": raw.get("cards", []), "pages": [], "settings": settings})
	game.guide.shown_log = PackedStringArray()
	await t.frames(2)
	var steps := 0
	var trace := PackedStringArray()
	while steps < 600:
		var v: Dictionary = game.engine.view()
		var phase := str(v.get("phase", ""))
		var day := int(v.get("date", {}).get("stage_day", 0))
		if phase == "morning" and day == 4:
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
		trace.append("%d %s d%d active=%s shown=%d" % [steps, phase, day, game.guide.active_step(), game.guide.shown_log.size()])
		steps += 1
	var got: Array = Array(game.guide.shown_log)
	if not _same_list(got, Array(MOCK_D1_3)):
		var f := FileAccess.open("/tmp/k16_d1_3_trace.txt", FileAccess.WRITE)
		if f != null:
			f.store_string("GOT\n" + "\n".join(got) + "\nWANT\n" + "\n".join(want) + "\nTRACE\n" + "\n".join(trace) + "\n")
	t.eq(got, Array(MOCK_D1_3), "guide steps lit in the Mock scenario's order on days 1-3")
	var sorted_got := got.duplicate()
	sorted_got.sort()
	var sorted_want := want.duplicate()
	sorted_want.sort()
	t.eq(sorted_got, sorted_want, "the same 21 steps as _test.d1_3, each once")
	await t.frames(2)
	var mock: MockCardEngine = game.engine
	var ui_guide: Array = []
	for row in mock.sent:
		if row[0] == "ui.guide":
			ui_guide.append(row)
	for step in want:
		t.ok(_sent(ui_guide, str(step), "shown"), "ui.guide shown " + str(step))
		t.ok(_sent(ui_guide, str(step), "done"), "ui.guide done " + str(step))
	game.queue_free()
	bus.queue_free()
	await t.frames(2)


func _same_list(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for i in range(a.size()):
		if str(a[i]) != str(b[i]):
			return false
	return true


func _sent(rows: Array, step: String, status: String) -> bool:
	for r in rows:
		var args: Dictionary = r[1]
		if str(args.get("step", "")) == step and str(args.get("status", "")) == status:
			return true
	return false

