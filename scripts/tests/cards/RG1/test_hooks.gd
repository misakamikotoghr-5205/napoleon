# RG1_hooks: relic passives / downsides on the real day loop. rl.hu2_pipe on Monday morning (day_start 25): the
# tier bias it adds is used up by G03 issuing that week's demand (day_start 30), so the demand comes one tier lower,
# and rep drops; with contact ma neither happens. rl.old_signboard: rep +1 on market-day settles, heat +1 every
# settle (cancelling G03's daily decay). Same seed twice = same hashes; save on a morning, load into another engine,
# play on = same hashes. A dormant shelf runs nothing. Each comparison is between engines that differ only in the
# relic, all on the RG1 data root. ROGUE_V1.md §4.6, §5.4. Owner RG1.
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const H = preload("res://scripts/tests/cards/RG1/helper.gd")
const Api = preload("res://scripts/cards/relic/relic_api.gd")
const Hooks = preload("res://scripts/cards/relic/relic_hooks.gd")

const MONDAY := 7          # 1938-03-01 is a Tuesday: stage days 7, 14, 21, 28 are Mondays
const MONDAY_WEEK := "0:1"  # CardCalendar.week_of(7) with a Tuesday start
const MIX := ["rl.hu2_pipe", "rl.old_signboard", "rl.blue_curtain", "rl.stub_box", "rl.oilpaper_umbrella",
	"rl.chen_mortar"]

var t
var data: String


func _initialize() -> void:
	t = T.new(self, "RG1_hooks")
	data = H.data_root(t)
	_pipe()
	_signboard()
	_dormant()
	_determinism()
	t.finish()


func _start(save: String, relics: Array, heat: int, contacts: Array = []) -> CardEngine:
	var e := H.engine(t, data, 7, save)
	for id in relics:
		t.eq(Api.take(e.ctx, str(id), "", "test"), "", "%s: take %s" % [save, id])
	for person in contacts:
		e.ctx.run([{"op": "contact_gain", "person": person}], "test")
	if heat != 0:
		CardMeters.add(e.ctx, &"heat", heat, "test")
	return e


func _pipe() -> void:
	# Heat 50 at the start keeps heat / 40 at 1 on day 7 (six daily decays): the demand's base tier is 1.
	var a := _start("pipe_a", ["rl.hu2_pipe"], 50)
	var b := _start("pipe_b", [], 50)
	var c := _start("pipe_c", ["rl.hu2_pipe"], 50, ["ma"])
	var d := _start("pipe_d", [], 50, ["ma"])
	t.ok(c.ctx.test({"has_contact": "ma"}), "contact ma for the second pair")
	for e in [a, b, c, d]:
		t.ok(H.advance(e, MONDAY - 1, "morning"), "reach the Sunday morning")
	t.eq(H.meter(a, &"rep"), H.meter(b, &"rep"), "no effect before Monday")
	for e in [a, b, c, d]:
		t.ok(H.advance(e, MONDAY, "morning"), "reach the Monday morning")
	t.eq(int(a.view()["date"]["weekday"]), 0, "day 7 is a Monday (weekday 0)")
	var ta := H.issued(a, MONDAY_WEEK)
	var tb := H.issued(b, MONDAY_WEEK)
	t.ok(not ta.is_empty() and not tb.is_empty(), "both issued the Monday demand")
	t.ok(int(tb.get("tier", 0)) >= 1, "base tier is above the floor (%s)" % tb.get("tier"))
	t.eq(int(ta.get("tier", -1)), int(tb.get("tier", 0)) - 1, "pipe: that demand comes one tier lower")
	t.eq(int(a.ctx.state.data["rules"]["demand"]["tier_bias"]), 0, "pipe: G03 used the bias up")
	t.eq(H.meter(a, &"rep"), H.meter(b, &"rep") - 2, "pipe: rep drops (its downside)")
	t.eq(int(H.issued(c, MONDAY_WEEK).get("tier", -1)), int(H.issued(d, MONDAY_WEEK).get("tier", -2)),
		"pipe with ma: same tier as without the pipe")
	t.eq(H.meter(c, &"rep"), H.meter(d, &"rep"), "pipe with ma: no rep loss")
	t.ok(H.advance(a, MONDAY + 1, "morning") and H.advance(b, MONDAY + 1, "morning"), "Tuesday")
	t.eq(H.meter(a, &"rep") - H.meter(b, &"rep"), -2, "pipe: nothing more on Tuesday")


func _signboard() -> void:
	# Heat 30 for both: the plain shop decays one a night, the signboard's +1 at settle 45 holds it.
	var a := _start("sign_a", ["rl.old_signboard"], 30)
	var b := _start("sign_b", [], 30)
	var market := 0
	for day in range(1, 6):
		t.ok(H.advance(a, day, "day") and H.advance(b, day, "day"), "day %d open" % day)
		if bool(a.view()["notice"]["market_day"]):
			market += 1
		t.ok(H.advance(a, day + 1, "morning") and H.advance(b, day + 1, "morning"), "after the settle of day %d" % day)
		t.eq(H.meter(a, &"heat") - H.meter(b, &"heat"), day, "signboard: heat +1 per settle (%d nights)" % day)
		t.eq(H.meter(a, &"rep") - H.meter(b, &"rep"), market, "signboard: rep +1 per market day (%d)" % market)
	t.ok(market >= 1, "at least one market day in the first five (stage 0 markets on days 3, 8, ...)")
	t.eq(H.meter(a, &"heat"), 30, "signboard: heat never fell")


func _dormant() -> void:
	var e := _start("dormant", ["rl.old_signboard", "rl.hu2_pipe"], 0)
	t.ok(H.advance(e, 3, "morning"), "a morning with the shelf")
	var ctx := e.ctx
	var h := e.state_hash()
	ctx.state.ns("loop")["mode"] = "street"
	Hooks.run_hook(ctx, "settle")
	Hooks.run_hook(ctx, "day_start")
	ctx.state.ns("loop")["mode"] = "shop"
	t.eq(e.state_hash(), h, "street: hooks run nothing")
	var ladder := ctx.state.ns("ladder")
	var had: bool = ladder.has("prison")
	var old = ladder.get("prison")
	ladder["prison"] = {"uid": "c9999", "nights": 0}
	Hooks.run_hook(ctx, "settle")
	if had:
		ladder["prison"] = old
	else:
		ladder.erase("prison")
	t.eq(e.state_hash(), h, "jailed: hooks run nothing")
	var heat := H.meter(e, &"heat")
	Hooks.run_hook(ctx, "settle")
	t.eq(H.meter(e, &"heat"), heat + 1, "awake: the signboard's settle downside runs")


func _determinism() -> void:
	var a := _start("det_a", MIX, 0)
	var b := _start("det_b", MIX, 0)
	var ha: Array = []
	var hb: Array = []
	for day in range(1, 10):
		t.ok(H.advance(a, day, "morning") and H.advance(b, day, "morning"), "morning %d" % day)
		ha.append(a.state_hash())
		hb.append(b.state_hash())
	t.eq(ha, hb, "same seed, same relics, same presses: same hash every morning")
	t.eq(Api.held_ids(a.ctx), PackedStringArray(MIX), "shelf unchanged by nine days")
	# Save on the morning of day 5 (in a third engine), play to day 9; load that save into a fourth engine, play on.
	var c := _start("det_c", MIX, 0)
	t.ok(H.advance(c, 5, "morning"), "det_c morning 5")
	var path: String = t.user_dir() + "/rg1_hooks_day5.json"
	t.ok(bool(c.save_game(path).get("ok", false)), "save on the morning of day 5")
	var played: Array = []
	for day in range(6, 10):
		t.ok(H.advance(c, day, "morning"), "det_c morning %d" % day)
		played.append(c.state_hash())
	var d := H.engine(t, data, 7, "det_d")
	t.ok(bool(d.load_game(path).get("ok", false)), "load the day-5 save")
	t.eq(d.state_hash(), ha[4], "loaded hash = the day-5 hash of the straight run")
	var replayed: Array = []
	for day in range(6, 10):
		t.ok(H.advance(d, day, "morning"), "det_d morning %d" % day)
		replayed.append(d.state_hash())
	t.eq(replayed, played, "save -> load -> play on: same hashes")
	t.eq(played, ha.slice(5, 9), "and the same as the straight run")
	t.eq(t.find_floats(d.ctx.state.data), PackedStringArray(), "no floats after load and play")
