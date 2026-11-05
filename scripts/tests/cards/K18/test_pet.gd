# K18: shop cat. Extra look, rice while home, wander, find-card, day.end still moves.
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const Pet = preload("res://scripts/cards/rules/pet.gd")
const ARRIVE := "ev.1938.cat_arrive"
const FIND := "ev.1938.find_cat"


func _initialize() -> void:
	var t := T.new(self, "K18_pet")
	_defs(t)
	_schedule(t)
	_play(t)
	t.finish()


func _defs(t) -> void:
	var db := CardDB.load_all()
	var arrive := db.def(ARRIVE)
	var find := db.def(FIND)
	t.eq(int(arrive.get("weight", -1)), 0, "arrive weight 0")
	t.eq(int(arrive.get("schedule", {}).get("stage_day", -1)), 15, "arrive day 15")
	t.eq(int(find.get("weight", -1)), 0, "find weight 0")
	t.ok(not find.has("schedule"), "find is not on the calendar")
	var ids: Array = []
	for choice in find.get("choices", []):
		ids.append(str(choice.get("id", "")))
	t.ok(ids.has("search") and ids.has("leave_it"), "find choices")
	t.ok(arrive.get("effects", {}).has("on_expire"), "arrive on_expire")
	t.ok(find.get("effects", {}).has("on_expire"), "find on_expire")
	t.ok(str(JSON.stringify(arrive.get("effects", {}))).contains(FIND), "wander effect names the find card")


func _schedule(t) -> void:
	var engine := CardEngine.new()
	t.ok(bool(engine.new_game({"seed": 11, "only_examples": false, "save_dir": t.user_dir() + "/sched"}).get("ok", false)), "schedule game")
	engine.ctx.state.ns("loop")["stage_day"] = 15
	var due := CardSchedule.due(engine.ctx, engine.ctx.abs_day())
	t.ok(due.has(ARRIVE), "day 15 schedules the cat")


func _play(t) -> void:
	var engine := CardEngine.new()
	t.ok(bool(engine.new_game({"seed": 7, "only_examples": false, "save_dir": t.user_dir() + "/play"}).get("ok", false)), "play game")
	var ctx := engine.ctx
	t.ok(not engine.view().has("pet"), "no plaque before the cat")
	var uid := CardPiles.spawn(ctx, ARRIVE, &"hand")
	t.ok(uid != "", "spawn arrive")
	var chosen: Dictionary = engine.send(&"card.choose", {"uid": uid, "choice": "keep"})
	t.ok(bool(chosen.get("ok", false)), "keep the cat: " + str(chosen.get("err", "")))
	t.ok(CardFirsts.all(ctx).has("pet"), "first pet")
	var view := engine.view()
	t.eq(view.get("pet", {}), {"show": true, "home": true, "lost": false}, "plaque home")
	t.no_leaks(view)
	var rice := _gain_rice(ctx)
	t.ok(rice != "", "rice on the shelf")
	var before := _condition(ctx, rice)
	Pet.on_night(ctx, {})
	t.eq(_condition(ctx, rice), before, "home night does not mold rice")
	t.eq(int(CardMeters.value(ctx, &"conscience")), 1, "one night of company")
	# 10-25 appraisal redesign: the base ink / tries now come from the eye aids (G04 _aids); the cat adds one on top.
	var base_ink := int(CardAppraisal._aids(ctx, &"spot", "")["ink"])
	var base_tries := int(CardAppraisal._aids(ctx, &"coin_ring", "")["tries"])
	var spot := CardAppraisal.params_for(ctx, "", &"spot")
	t.eq(int(spot.get("ink", -1)), base_ink + 1, "one extra look")
	var again := CardAppraisal.params_for(ctx, "", &"spot")
	t.eq(int(again.get("ink", -1)), base_ink, "second look is not free")
	ctx.state.ns("rules")["pet"]["look_left"] = 1
	var weigh := CardAppraisal.params_for(ctx, "", &"weigh")
	t.ok(not weigh.has("ink") and not weigh.has("tries"), "weigh has no look counters")
	t.eq(int(ctx.state.ns("rules")["pet"]["look_left"]), 1, "weigh does not spend the look")
	var ring := CardAppraisal.params_for(ctx, "", &"coin_ring")
	t.eq(int(ring.get("tries", -1)), base_tries + 1, "coin ring gets the extra try")
	# GPT：keep-home 打烊验收必须在走丢前、且先断言 Pet.home（不可复用已走丢 ctx）。
	t.ok(Pet.home(ctx), "keep-home precondition: still home")
	_assert_day_advances(t, engine, "keep-home")
	var origin := ctx.abs_day()
	var wandered := false
	for day in range(1, 49):
		ctx.state.ns("loop")["abs_day"] = day
		ctx.state.ns("rules")["pet"]["nights"] = 3
		ctx.state.ns("rules")["flags"]["pet_home"] = true
		ctx.state.ns("rules")["flags"].erase("pet_lost")
		Pet.on_night(ctx, {})
		if bool(ctx.state.ns("rules").get("flags", {}).get("pet_lost", false)):
			wandered = true
			break
	t.ok(wandered, "cat wanders within 48 nights")
	t.ok(_queued(ctx), "find card queued")
	var mold_before := _condition(ctx, rice)
	Pet.on_night(ctx, {})
	t.eq(_condition(ctx, rice), maxi(0, mold_before - 50), "lost night molds rice")
	ctx.state.ns("loop")["abs_day"] = origin
	# GPT 要改 #1：走丢找猫未处理 / 找回 — 最多 8 次 day.end 后 abs_day 前进或 game_over。
	var lost_engine := CardEngine.new()
	t.ok(bool(lost_engine.new_game({"seed": 7, "only_examples": false, "save_dir": t.user_dir() + "/lost_day"}).get("ok", false)), "lost day game")
	var lost_ctx := lost_engine.ctx
	var lost_uid := CardPiles.spawn(lost_ctx, ARRIVE, &"hand")
	t.ok(bool(lost_engine.send(&"card.choose", {"uid": lost_uid, "choice": "keep"}).get("ok", false)), "keep for lost path")
	lost_ctx.state.ns("rules")["flags"]["pet_home"] = false
	lost_ctx.state.ns("rules")["flags"]["pet_lost"] = true
	lost_ctx.state.ns("rules")["pet"]["had"] = true
	var find_uid := CardPiles.spawn(lost_ctx, FIND, &"hand")
	t.ok(find_uid != "", "find card in hand while lost")
	_assert_day_advances(t, lost_engine, "lost-find-pending")
	var found_engine := CardEngine.new()
	t.ok(bool(found_engine.new_game({"seed": 7, "only_examples": false, "save_dir": t.user_dir() + "/found_day"}).get("ok", false)), "found day game")
	var found_ctx := found_engine.ctx
	var keep_uid := CardPiles.spawn(found_ctx, ARRIVE, &"hand")
	t.ok(bool(found_engine.send(&"card.choose", {"uid": keep_uid, "choice": "keep"}).get("ok", false)), "keep for found path")
	found_ctx.state.ns("rules")["flags"]["pet_lost"] = true
	found_ctx.state.ns("rules")["flags"].erase("pet_home")
	var find2 := CardPiles.spawn(found_ctx, FIND, &"hand")
	found_ctx.run([
		{"op": "flag", "key": "pet_home"},
		{"op": "flag_clear", "key": "pet_lost"},
	], "K18:test/found")
	CardPiles.resolve(found_ctx, find2, &"resolved")
	t.ok(Pet.home(found_ctx), "found path home again")
	_assert_day_advances(t, found_engine, "found-home")
	t.ok(t.find_floats(ctx.state.data).is_empty(), "no floats: " + ", ".join(t.find_floats(ctx.state.data)))
	t.no_leaks(engine.view())



func _assert_day_advances(t, engine: CardEngine, tag: String) -> void:
	var today := engine.ctx.abs_day()
	var guard := 0
	while engine.ctx.abs_day() == today and str(engine.view().get("phase", "")) != "game_over" and guard < 8:
		guard += 1
		var step: Dictionary = engine.send(&"day.end", {"confirm": true})
		t.ok(bool(step.get("ok", false)), tag + " day.end: " + str(step.get("err", "")))
		if not bool(step.get("ok", false)):
			break
	var over := str(engine.view().get("phase", "")) == "game_over"
	t.ok(engine.ctx.abs_day() > today or over, tag + " abs_day advanced or game_over")


func _gain_rice(ctx: CardCtx) -> String:
	var had: Dictionary = {}
	for id in CardShelf.items(ctx):
		had[id] = true
	ctx.run([{"op": "item_gain", "cat": "rice", "n": 1}], "K18:test/rice")
	for id in CardShelf.items(ctx):
		if had.has(id):
			continue
		var meta: Dictionary = ctx.state.ns("econ").get("items_meta", {}).get(id, {})
		if str(meta.get("cat", "")) == "rice":
			return id
	return ""


func _condition(ctx: CardCtx, id: String) -> int:
	return int(ctx.state.ns("econ").get("items_meta", {}).get(id, {}).get("condition_permille", -1))


func _queued(ctx: CardCtx) -> bool:
	for row in ctx.state.ns("core").get("queue", []):
		if str(row.get("def", "")) == FIND:
			return true
	for uid in CardPiles.list(ctx, &"hand"):
		if str(CardPiles.card(ctx, uid).get("def", "")) == FIND:
			return true
	return false
