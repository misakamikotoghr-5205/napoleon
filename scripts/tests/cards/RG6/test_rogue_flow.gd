# RG6_rogue_flow: the rogue v1 loop end to end on the real data (docs/cards/rogue/ROGUE_V1.md §14 RG6 phase 2, §15.1).
# fair, seed 7, the whole first stage (30 days): the weekly stocktake opens on stage days 7 / 14 / 21 / 28 (and only
# there), the peddler comes on day 8 and spreads two plain relics, at least one relic and one source are taken; every
# new (day, phase) the view, the relics query and the stocktake query pass CardViewModel.leaks, and so does every bus
# event; replaying the command log gives the same hash; a save on the morning of day 10, loaded into a fresh engine,
# plays on with the same hash every morning. refuser, 30 days: never sends stock.pick, never gets a relic key, every
# day.end {confirm: true} moves the phase or the date, and the stocktakes it is shown lapse unpicked. A full curio
# shelf: stock.pick without a replace -> relic_full (the offer stays open), with one -> ok and the replaced relic in
# gone. Owner RG6.
extends SceneTree

const T := preload("res://scripts/tests/cards/lib/card_t.gd")
const Runner := preload("res://scripts/cards/sim/balance_main.gd")
const RelicApi := preload("res://scripts/cards/relic/relic_api.gd")
const PEDDLER := "p.stranger_peddler.1938.curios"
const WEEK_DAYS: Array = [7, 14, 21, 28]
const LAST_DAY := 30
const SAVE_DAY := 10
const SEED := 7

var t: RefCounted


func _initialize() -> void:
	t = T.new(self, "RG6_rogue_flow")
	var fair: Dictionary = _fair()
	_replay(fair)
	_save_load(fair)
	_refuser()
	_full_shelf()
	t.finish()


# ---------------- driver ----------------
func _opts(tag: String) -> Dictionary:
	return {"seed": SEED, "save_dir": t.user_dir() + "/" + tag}


## A fresh run record: per-morning hashes by abs day, the open panel of every (day, phase), what was sent and how it
## went, and the day.end {confirm: true} presses that did not move the game.
func _run_row() -> Dictionary:
	return {"hashes": {}, "panels": {}, "picks": [], "sent": {}, "stuck": [], "end": "", "steps": 0}


## Plays policy until the morning of abs day `until`, the stage's end (year_jump) or game over. Checks every new
## (day, phase) for leaks and keeps each morning's state hash.
func _drive(e: CardEngine, policy: CardPolicy, until: int, run: Dictionary) -> void:
	var seen: Dictionary = {}
	while int(run["steps"]) < 30000:
		var v: Dictionary = e.view()
		var day: int = int(v.get("date", {}).get("abs_day", 0))
		var phase: String = str(v.get("phase", ""))
		var key: String = "%d:%s" % [day, phase]
		if not seen.has(key):
			seen[key] = true
			_check_leaks(e, v, key)
			run["panels"][key] = (v.get("open_panel", {}) as Dictionary).duplicate(true)
			if phase == "morning":
				run["hashes"][day] = e.state_hash()
		if phase in ["game_over", "year_jump"] or (phase == "morning" and day >= until):
			run["end"] = key
			return
		var action: Array = policy.decide(e, v)
		if action.is_empty():
			action = [&"day.end", {"confirm": true}]
		var cmd: String = str(action[0])
		var r: Dictionary = e.send(StringName(cmd), action[1])
		run["steps"] = int(run["steps"]) + 1
		run["sent"][cmd] = int(run["sent"].get(cmd, 0)) + 1
		if cmd in ["stock.pick", "day.end"]:
			t.no_leaks(r, "result of " + cmd)
		if cmd == "stock.pick":
			run["picks"].append([(action[1] as Dictionary).duplicate(true), r.duplicate(true)])
		if cmd == "day.end" and bool(action[1].get("confirm", false)):
			_check_day_end(e, v, r, run)
	t.ok(false, "drive: step guard hit at " + str(e.view().get("date", {})))


## day.end {confirm: true} always succeeds and moves the phase or the date (red line 3), unless the game is over.
func _check_day_end(e: CardEngine, before: Dictionary, r: Dictionary, run: Dictionary) -> void:
	if str(before.get("phase", "")) == "game_over":
		return
	var after: Dictionary = e.view()
	var moved: bool = str(after.get("phase", "")) != str(before.get("phase", "")) \
		or int(after.get("date", {}).get("abs_day", 0)) > int(before.get("date", {}).get("abs_day", 0))
	if not bool(r.get("ok", false)) or not moved:
		run["stuck"].append([before.get("date", {}), str(before.get("phase", "")), str(r.get("err", ""))])


func _check_leaks(e: CardEngine, v: Dictionary, key: String) -> void:
	t.no_leaks(v, "view " + key)
	t.no_leaks(e.query(&"relics", {}), "relics query " + key)
	var newest: Dictionary = e.query(&"stocktake", {})
	t.no_leaks(newest, "stocktake query " + key)
	var offers: Dictionary = e.ctx.state.data.get("stock", {}).get("offers", {})
	var ids: Array = offers.keys()
	ids.sort()
	for id in ids:
		var q: Dictionary = e.query(&"stocktake", {"offer": str(id)})
		t.ok(bool(q.get("ok", false)), "stocktake query %s on %s" % [id, key])
		t.no_leaks(q, "stocktake query %s on %s" % [id, key])


## Every bus event passes leaks(), except the one documented path (CARDS_INTERFACES.md §7.5, #46): the layout seed of
## minigame_requested (params.seed, params.marks[i].seed), which must be an int and not the game seed.
func _events_clean(spy: RefCounted, label: String) -> void:
	var layout := RegEx.create_from_string("^\\[3\\]\\.(marks\\[(\\d+)\\]\\.)?seed$")
	for row in spy.log:
		var args: Array = Array(row).slice(1)
		var bad := PackedStringArray()
		for path in CardViewModel.leaks(args):
			var hit: RegExMatch = layout.search(path) if row[0] == &"minigame_requested" else null
			if hit == null:
				bad.append(path)
				continue
			var holder: Dictionary = args[3] if hit.get_string(2) == "" else args[3]["marks"][int(hit.get_string(2))]
			if typeof(holder["seed"]) != TYPE_INT or int(holder["seed"]) == SEED:
				bad.append(path)
		t.ok(bad.is_empty(), "%s bus event %s leaks hidden keys: %s" % [label, str(row[0]), ", ".join(bad)])


# ---------------- fair ----------------
## fair from day 1 to the end of the stage; the policy is swapped for a fresh one on the morning of SAVE_DAY (where
## _save_load saves), so the continuation compared there depends on the engine only.
func _fair() -> Dictionary:
	var bus := CardEventBus.new()
	var spy: RefCounted = t.spy(bus)
	var e := CardEngine.new(bus)
	t.ok(bool(e.new_game(_opts("fair")).get("ok", false)), "fair: new game on the real data")
	var run: Dictionary = _run_row()
	_drive(e, Runner.POLICIES["fair"].new(SEED), SAVE_DAY, run)
	t.eq(run["end"], "%d:morning" % SAVE_DAY, "fair reaches the morning of day %d" % SAVE_DAY)
	var path: String = t.user_dir() + "/rg6_flow_day%d.json" % SAVE_DAY
	t.ok(bool(e.save_game(path).get("ok", false)), "fair: save on the morning of day %d" % SAVE_DAY)
	_drive(e, Runner.POLICIES["fair"].new(SEED), LAST_DAY + 1, run)
	t.eq(run["end"], "%d:year_jump" % LAST_DAY, "fair plays the whole first stage (30 days)")
	t.eq(run["stuck"], [], "fair: every day.end {confirm: true} moved the game")
	_fair_offers(e, run)
	_events_clean(spy, "fair")
	t.eq(t.find_floats(e.ctx.state.data), PackedStringArray(), "fair: no floats in state")
	print("RG6_rogue_flow fair: %d steps, %d bus events, picks %s, held %s" % [run["steps"], spy.log.size(),
		JSON.stringify(run["picks"].map(func(p): return p[0])), RelicApi.held_ids(e.ctx)])
	var out: Dictionary = {"run": run, "log": e.command_log(), "hash": e.state_hash(), "save": path}
	bus.free()
	return out


func _fair_offers(e: CardEngine, run: Dictionary) -> void:
	var stock: Dictionary = e.ctx.state.data.get("stock", {})
	var offers: Dictionary = stock.get("offers", {})
	var want: Array = ["p8"]
	for week in range(WEEK_DAYS.size()):
		want.append("w0.%d" % week)
	want.sort()
	var have: Array = offers.keys()
	have.sort()
	t.eq(have, want, "fair: the four weekly offers and the peddler's, nothing else")
	for week in range(WEEK_DAYS.size()):
		var day: int = int(WEEK_DAYS[week])
		var row: Dictionary = offers.get("w0.%d" % week, {})
		t.eq(int(row.get("abs_day", 0)), day, "w0.%d made on day %d" % [week, day])
		t.eq(str(row.get("from", "")), "week", "w0.%d is a weekly stocktake" % week)
		t.eq(run["panels"].get("%d:settle" % day, {}), {"kind": "stocktake", "args": {"offer": "w0.%d" % week}},
			"day %d settle opens the stocktake overlay" % day)
	for key in run["panels"].keys():
		var day_phase: PackedStringArray = str(key).split(":")
		if str(run["panels"][key].get("kind", "")) == "stocktake" and day_phase[1] == "settle":
			t.ok(WEEK_DAYS.has(int(day_phase[0])), "stocktake opens at settle only on week days (%s)" % key)
	_peddler_offer(e, offers.get("p8", {}))
	var kinds: Dictionary = {}
	for pair in run["picks"]:
		if bool(pair[1].get("ok", false)):
			kinds[str(pair[1].get("kind", ""))] = int(kinds.get(str(pair[1].get("kind", "")), 0)) + 1
	t.ok(int(kinds.get("relic", 0)) >= 1, "fair took at least one relic: %s" % kinds)
	t.ok(int(kinds.get("source", 0)) >= 1, "fair took at least one source: %s" % kinds)
	t.ok(RelicApi.held_ids(e.ctx).size() >= 1, "fair holds a relic at the end: %s" % RelicApi.held_ids(e.ctx))
	t.ok(not (stock.get("sources", []) as Array).is_empty(), "fair has a source this stage")
	t.eq(e.query(&"relics", {}).get("count", -1), RelicApi.held_ids(e.ctx).size(), "relics query counts the shelf")


func _peddler_offer(e: CardEngine, row: Dictionary) -> void:
	t.eq(int(row.get("abs_day", 0)), 8, "the peddler's offer is made on day 8")
	t.eq(str(row.get("from", "")), "peddler", "p8 comes from the peddler")
	var items: Array = row.get("items", [])
	t.eq(items.size(), 2, "the peddler spreads two things")
	for item in items:
		t.eq(str(item.get("kind", "")), "relic", "peddler item %s is a relic" % str(item.get("id", "")))
		t.eq(str(e.ctx.db.def(str(item.get("id", ""))).get("depth", "")), "plain",
			"peddler item %s is plain" % str(item.get("id", "")))


# ---------------- replay / save ----------------
func _replay(fair: Dictionary) -> void:
	var hash: String = CardReplay.replay(_opts("replay"), fair["log"])
	t.eq(hash, fair["hash"], "replaying fair's command log gives the same hash")


## Loads the morning-of-SAVE_DAY save into a fresh engine and plays on with a fresh fair: same hash every morning.
func _save_load(fair: Dictionary) -> void:
	var e := CardEngine.new()
	t.ok(bool(e.new_game(_opts("load")).get("ok", false)), "load: fresh engine")
	t.ok(bool(e.load_game(fair["save"]).get("ok", false)), "load the day %d save" % SAVE_DAY)
	var straight: Dictionary = fair["run"]["hashes"]
	t.eq(e.state_hash(), str(straight.get(SAVE_DAY, "")), "loaded hash = the straight run's day %d hash" % SAVE_DAY)
	var run: Dictionary = _run_row()
	_drive(e, Runner.POLICIES["fair"].new(SEED), LAST_DAY + 1, run)
	t.eq(run["end"], "%d:year_jump" % LAST_DAY, "the loaded run also plays to the end of the stage")
	var mornings: Array = []
	for day in straight.keys():
		if int(day) >= SAVE_DAY:
			mornings.append(int(day))
	mornings.sort()
	t.ok(mornings.size() >= LAST_DAY - SAVE_DAY, "mornings after the save: %d" % mornings.size())
	for day in mornings:
		t.eq(str(run["hashes"].get(day, "")), str(straight[day]), "morning %d hash after save -> load" % day)
	t.eq(e.state_hash(), fair["hash"], "same final hash after save -> load")
	print("RG6_rogue_flow save/load: %d mornings compared from day %d" % [mornings.size(), SAVE_DAY])


# ---------------- refuser ----------------
func _refuser() -> void:
	var bus := CardEventBus.new()
	var spy: RefCounted = t.spy(bus)
	var e := CardEngine.new(bus)
	t.ok(bool(e.new_game(_opts("refuser")).get("ok", false)), "refuser: new game")
	var run: Dictionary = _run_row()
	_drive(e, Runner.POLICIES["refuser"].new(SEED), LAST_DAY + 1, run)
	t.ok(str(run["end"]) != "", "refuser: the drive ended (%s)" % run["end"])
	t.eq(run["sent"].keys(), ["day.end"], "refuser only ever closes the day")
	t.eq(int(run["sent"].get("stock.pick", 0)), 0, "refuser never sends stock.pick")
	t.eq(run["stuck"], [], "refuser: every day.end {confirm: true} moved the game")
	t.ok(not e.ctx.state.data.has("relic"), "refuser: no relic key in the state")
	t.ok(not e.view().has("relics") or int(e.view()["relics"].get("count", 0)) == 0, "refuser: empty shelf")
	var offers: Dictionary = e.ctx.state.data.get("stock", {}).get("offers", {})
	t.ok(not offers.is_empty(), "refuser is still shown stocktakes (%d)" % offers.size())
	var ids: Array = offers.keys()
	ids.sort()
	for id in ids:
		var row: Dictionary = offers[id]
		t.ok(str(id).begins_with("w"), "refuser never meets the peddler's offer (%s)" % id)
		t.eq(str(row.get("picked", "")), "", "refuser picked nothing from %s" % id)
		t.eq(int(row.get("deals", -1)), 0, "refuser made no deals in the week of %s" % id)
		t.eq((row.get("items", []) as Array).size(), 2, "no deals -> two things in %s" % id)
		if int(row.get("abs_day", 0)) < e.ctx.abs_day():
			t.eq(str(row.get("status", "")), "lapsed", "%s lapsed the next morning" % id)
	_events_clean(spy, "refuser")
	print("RG6_rogue_flow refuser: ended %s after %d presses, offers %s" % [run["end"], run["steps"], ids])
	bus.free()


# ---------------- full shelf ----------------
## Six relics on the shelf (no plain one, so the peddler still has two to show), then the peddler's offer.
func _full_shelf() -> void:
	var e := CardEngine.new()
	t.ok(bool(e.new_game(_opts("full")).get("ok", false)), "full shelf: new game")
	var ctx: CardCtx = e.ctx
	var fill: Array = []
	for id in ctx.db.ids_of(&"relic"):
		if str(ctx.db.def(id).get("depth", "")) != "plain" and fill.size() < RelicApi.cap(ctx):
			fill.append(str(id))
	fill.sort()
	for id in fill:
		t.eq(RelicApi.take(ctx, id, "", "test"), "", "full shelf: take " + id)
	t.ok(RelicApi.is_full(ctx), "the shelf is full (%d)" % RelicApi.held_ids(ctx).size())
	t.ok(_walk_to(e, 8, "day"), "full shelf: day 8")
	var uid: String = _hand_uid(e, PEDDLER)
	t.ok(uid != "", "the peddler is in the hand on day 8")
	t.ok(bool(e.send(&"card.choose", {"uid": uid, "choice": "look"}).get("ok", false)), "have a look")
	var q: Dictionary = e.query(&"stocktake", {"offer": "p8"})
	t.ok(bool(q.get("full", false)), "the stocktake query says the shelf is full")
	var pick: String = str(q.get("items", [{}])[0].get("id", ""))
	var r: Dictionary = e.send(&"stock.pick", {"offer": "p8", "pick": pick})
	t.eq(str(r.get("err", "")), "relic_full", "full shelf, no replace -> relic_full")
	t.eq(str(e.query(&"stocktake", {"offer": "p8"}).get("status", "")), "open", "the offer stays open")
	var bad: Dictionary = e.send(&"stock.pick", {"offer": "p8", "pick": pick, "replace": "rl.nope"})
	t.eq(str(bad.get("err", "")), "not_held", "replace something not on the shelf -> not_held")
	var old: String = str(RelicApi.held_ids(ctx)[0])
	r = e.send(&"stock.pick", {"offer": "p8", "pick": pick, "replace": old})
	t.ok(bool(r.get("ok", false)), "full shelf, with a replace -> ok: %s" % r)
	t.eq(str(r.get("released", "")), old, "the result names the released relic")
	t.ok(RelicApi.gone_ids(ctx).has(old), "the replaced relic is gone")
	t.ok(RelicApi.held_ids(ctx).has(pick) and not RelicApi.held_ids(ctx).has(old), "the new one took its cell")
	t.eq(RelicApi.held_ids(ctx).size(), RelicApi.cap(ctx), "still a full shelf")
	t.eq(str(e.query(&"stocktake", {"offer": "p8"}).get("status", "")), "picked", "the offer is picked")
	t.no_leaks(e.view(), "full shelf view")


func _walk_to(e: CardEngine, day: int, phase: String) -> bool:
	for _i in range(400):
		var v: Dictionary = e.view()
		if int(v.get("date", {}).get("stage_day", 0)) == day and str(v.get("phase", "")) == phase:
			return true
		if str(v.get("phase", "")) == "game_over":
			return false
		if not bool(e.send(&"day.end", {"confirm": true}).get("ok", false)):
			return false
	return false


func _hand_uid(e: CardEngine, def_id: String) -> String:
	for uid in CardPiles.list(e.ctx, CardIds.ZONE_HAND):
		if str(CardPiles.card(e.ctx, uid).get("def", "")) == def_id:
			return str(uid)
	return ""
