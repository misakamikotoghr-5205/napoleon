# RG2_peddler: the peddler's first visit (ROGUE_V1.md §5.2, §6.6) on fixture data. Day 8 he is in the hand;
# "look" runs stock_offer -> offer p8 with 2 plain relics and the overlay requested; "send_off" makes no offer;
# ignoring him and closing the day lets him leave like any visitor. The op itself: asked again it only reopens an
# open offer, never a closed one; nothing to set out -> the peddler_empty notice; module off -> nothing. Owner RG2.
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const H = preload("res://scripts/tests/cards/RG2/helper.gd")
const OFFER := {"op": "stock_offer", "n": 2, "kinds": ["relic"], "depths": ["plain"], "from": "peddler"}


func _initialize() -> void:
	var t := T.new(self, "RG2_peddler")
	var root := H.data_root(t)
	var bus := CardEventBus.new()
	var spy = t.spy(bus)
	var e := H.engine(t, root, 7, "main", bus)
	t.ok(H.walk_to(e, 8, "morning"), "day 8 morning")
	var morning := CardSave.suspend_path()
	t.ok(FileAccess.file_exists(morning), "day 8 resume point")
	t.ok(H.walk_to(e, 8, "day"), "day 8")
	_look(t, e)
	_op_again(t, e)
	_reload(t, e, morning)
	_send_off(t, e)
	_reload(t, e, morning)
	_ignore(t, e)
	_empty(t, e)
	H.events_clean(t, spy, "peddler")
	t.eq(t.find_floats(e.ctx.state.data), PackedStringArray(), "integer-only state")
	_disabled(t)
	bus.free()
	t.finish()


func _look(t, e: CardEngine) -> void:
	var uid := H.hand_uid(e, H.PEDDLER)
	t.ok(uid != "", "the peddler is in the day 8 hand")
	t.eq(CardViewModel.card_view(e.ctx, uid, false).get("panel"), "slots", "a story visitor opens the slots panel")
	var r: Dictionary = e.send(&"card.choose", {"uid": uid, "choice": "look"})
	t.ok(bool(r.get("ok", false)), "choose look: " + str(r.get("err", "")))
	t.eq(H.hand_uid(e, H.PEDDLER), "", "the peddler card is done after the choice")
	var view := e.view()
	t.eq(view.get("open_panel"), {"kind": "stocktake", "args": {"offer": "p8"}}, "the overlay is requested for p8")
	t.eq(view.get("stock", {}).get("open"), "p8", "view.stock.open")
	var q: Dictionary = e.query(&"stocktake", {})
	t.eq(q.get("offer"), "p8", "latest open offer is the peddler's")
	t.eq(q.get("from"), "peddler", "from peddler")
	t.eq(q.get("week"), -1, "a peddler offer has no week")
	t.eq(q.get("status"), "open", "open")
	var items: Array = q.get("items", [])
	t.eq(items.size(), 2, "two things on the tray")
	var ids: Dictionary = {}
	for row in items:
		t.eq(row.get("kind"), "relic", "relics only")
		t.eq(row.get("depth"), "plain", "plain household things only (%s)" % row.get("id"))
		t.eq(str(e.ctx.db.def(str(row.get("id"))).get("depth", "")), "plain", "plain in the data too")
		t.ok(str(row.get("id")) != "rl.cat_bowl", "no cat bowl before a cat")
		ids[str(row.get("id"))] = true
	t.eq(ids.size(), 2, "two different relics")
	var rec := H.offer(e, "p8")
	t.eq(rec.get("abs_day"), 8, "recorded on day 8")
	t.eq(rec.get("stage"), 0, "stage 0")
	t.no_leaks(view, "view with the peddler offer")
	t.no_leaks(q, "peddler query")


## The op asked again the same day: an open offer is only reopened; once closed it stays closed.
func _op_again(t, e: CardEngine) -> void:
	var before: Dictionary = H.offer(e, "p8").duplicate(true)
	CardDayLoop.request_panel(e.ctx, &"", {})
	e.ctx.out = []
	e.ctx.run([OFFER.duplicate(true)], "rg2test/again")
	t.eq(H.offer(e, "p8"), before, "same offer, not re-rolled")
	t.eq(e.ctx.state.ns("loop").get("open_panel"), {"kind": "stocktake", "args": {"offer": "p8"}}, "reopened")
	var first := str(before.get("items", [{}])[0].get("id", ""))
	var took: Dictionary = e.send(&"stock.pick", {"offer": "p8", "pick": first})
	if bool(took.get("ok", false)):
		t.eq(H.offer(e, "p8").get("status"), "picked", "relic taken (RG1 merged)")
	else:
		t.eq(took.get("err"), "not_implemented", "RelicApi stub before RG1")
		t.eq(e.send(&"stock.pick", {"offer": "p8", "pick": ""}).get("ok"), true, "pass instead")
	var closed: Dictionary = H.offer(e, "p8").duplicate(true)
	t.ok(str(closed.get("status")) != "open", "p8 closed")
	e.ctx.out = []
	e.ctx.run([OFFER.duplicate(true)], "rg2test/closed")
	t.eq(H.offer(e, "p8"), closed, "a closed offer is not reopened or replaced")
	t.eq(str(e.ctx.state.ns("loop").get("open_panel", {}).get("kind", "")), "", "no panel for a closed offer")
	e.ctx.out = []


func _reload(t, e: CardEngine, path: String) -> void:
	var r: Dictionary = e.load_game(path)
	t.ok(bool(r.get("ok", false)), "reload day 8 morning: " + str(r.get("err", "")))
	t.ok(H.walk_to(e, 8, "day"), "day 8 again")
	t.ok(not H.stock(e).get("offers", {}).has("p8"), "no p8 after reloading")


func _send_off(t, e: CardEngine) -> void:
	var uid := H.hand_uid(e, H.PEDDLER)
	t.ok(uid != "", "the peddler is back")
	var r: Dictionary = e.send(&"card.choose", {"uid": uid, "choice": "send_off"})
	t.ok(bool(r.get("ok", false)), "choose send_off: " + str(r.get("err", "")))
	t.ok(not H.stock(e).get("offers", {}).has("p8"), "send_off makes no offer")
	t.eq(str(e.view().get("open_panel", {}).get("kind", "")), "", "no overlay")
	t.eq(H.hand_uid(e, H.PEDDLER), "", "he left")


func _ignore(t, e: CardEngine) -> void:
	var uid := H.hand_uid(e, H.PEDDLER)
	t.ok(uid != "", "the peddler is back once more")
	var preview: Dictionary = e.query(&"day.end_preview")
	var leave := false
	for row in preview.get("items", []):
		if str(row.get("uid", "")) == uid:
			leave = str(row.get("kind", "")) == "leave"
	t.ok(leave, "closing lists him as an ordinary visitor who leaves")
	var r: Dictionary = e.send(&"day.end", {"confirm": true})
	t.ok(bool(r.get("ok", false)), "day.end with the peddler unanswered: " + str(r.get("err", "")))
	t.eq(H.phase(e), "night", "night")
	t.eq(str(CardPiles.zone_of(e.ctx, uid)), "discard", "he is gone")
	t.ok(not H.stock(e).get("offers", {}).has("p8"), "no offer when ignored")
	t.ok(H.walk_to(e, 9, "day"), "the next day goes on")


## Nothing matches -> the peddler_empty notice and no offer.
func _empty(t, e: CardEngine) -> void:
	var day := e.ctx.abs_day()
	e.ctx.out = []
	var eff := OFFER.duplicate(true)
	eff["depths"] = ["none_such"]
	e.ctx.run([eff], "rg2test/empty")
	var noticed := false
	for ev in e.ctx.out:
		noticed = noticed or (ev[0] == &"notice" and str(ev[1]) == "rg2.notice.peddler_empty")
	t.ok(noticed, "peddler_empty notice")
	t.ok(not H.stock(e).get("offers", {}).has("p%d" % day), "no offer recorded")
	e.ctx.out = []


## rules/stock.json enabled = false: the peddler still visits but "look" sets nothing out.
func _disabled(t) -> void:
	var root := H.data_root(t, "off", {"enabled": false})
	var e := H.engine(t, root, 7, "off")
	t.ok(H.walk_to(e, 8, "day"), "day 8 (module off)")
	var uid := H.hand_uid(e, H.PEDDLER)
	t.ok(uid != "", "the peddler card is plain data and still comes")
	t.ok(bool(e.send(&"card.choose", {"uid": uid, "choice": "look"}).get("ok", false)), "look with the module off")
	t.ok(not e.ctx.state.data.has("stock"), "no stock namespace at all")
	t.ok(not e.view().has("stock"), "no stock view block")
	t.eq(str(e.view().get("open_panel", {}).get("kind", "")), "", "no overlay")
	t.eq(e.query(&"stocktake", {}).get("err"), "not_allowed", "nothing to query")
	t.eq(e.send(&"stock.pick", {"offer": "p8", "pick": ""}).get("err"), "not_allowed", "module off -> not_allowed")
