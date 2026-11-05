# C15 W2: real engine, example set. Ticket tk.1938.de196 in hand,
# mg.request {uid, item: ""} uses G04 params, autoplay(0.8), mg.report
# records a foreign pawn ticket and does not move cash.
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const H = preload("res://scripts/tests/cards/C15/harness.gd")
const TICKET := "tk.1938.de196"
const TICKET_NO := 196


func _initialize() -> void:
	var args := _args()
	var name := str(args.get("name", "C15_real_engine"))
	var t := T.new(self, name)
	t.run_async(_body.bind(t))


func _body(t) -> void:
	var eng := CardEngine.new()
	var boot: Dictionary = eng.new_game({"seed": 7, "only_examples": true, "save_dir": t.user_dir()})
	t.ok(bool(boot.get("ok", false)), "new_game")
	if not bool(boot.get("ok", false)):
		t.finish()
		return
	var reached := _reach_ticket_day(t, eng)
	t.ok(reached, "day 4 of the example month")
	if not reached:
		t.finish()
		return
	var uid := _ticket_uid(eng)
	t.ok(uid != "", "tk.1938.de196 in hand: " + _hand_defs(eng))
	if uid == "":
		t.finish()
		return
	t.eq(str(eng.view().get("phase", "")), "day", "phase day before request")
	var cash_before := _money(eng)
	var req: Dictionary = eng.send(&"mg.request", {"uid": uid, "item": ""})
	t.ok(bool(req.get("ok", false)), "mg.request " + str(req.get("err", "")))
	t.eq(str(req.get("kind", "")), "fragments", "request kind")
	var params: Dictionary = req.get("params", {})
	_g04_params(t, params)
	var packed: PackedScene = load(H.FRAG)
	var game: CardFragmentsGame = packed.instantiate() as CardFragmentsGame
	root.add_child(game)
	await t.frames(1)
	game.start(params)
	var box: Dictionary = H.take(game)
	game.autoplay(0.8)
	var result: Dictionary = box.get("r", {})
	t.eq(bool(result.get("aborted", true)), false, "autoplay not aborted")
	t.eq(typeof(result.get("quality_permille")), TYPE_INT, "quality int")
	t.eq(typeof(result.get("minutes")), TYPE_INT, "minutes int")
	t.ok(int(result.get("quality_permille", 0)) >= 700, "autoplay 0.8 is clear")
	var played: Array = result.get("observations", [])
	t.ok(played.size() > 0, "autoplay produced observations")
	for key in played:
		t.ok(str(key).begins_with("obs.fragments."), "played " + str(key))
	var rep: Dictionary = eng.send(&"mg.report", {"uid": uid, "item": "", "result": result})
	t.ok(bool(rep.get("ok", false)), "mg.report " + str(rep.get("err", "")))
	t.eq(str(rep.get("err", "")), "", "report err empty")
	var accepted: Array = rep.get("observations", [])
	for key in accepted:
		t.ok(played.has(key), "accepted was played " + str(key))
	# Example set loads obs from _examples/minigames/obs only. That folder has
	# weigh.json and no fragments catalog, so G04 keeps none of these keys.
	var example_cat := "res://data/cards/_examples/minigames/obs/fragments.json"
	if not FileAccess.file_exists(example_cat):
		t.eq(accepted, [], "example catalog has no fragments keys")
	else:
		t.ok(accepted.size() > 0, "example fragments catalog keeps clear keys")
	_foreign(t, eng)
	t.eq(_money(eng), cash_before, "foreign ticket does not move cash")
	t.eq(str(CardPiles.zone_of(eng.ctx, uid)), "discard", "ticket resolved")
	game.queue_free()
	await t.frames(1)
	t.finish()


func _reach_ticket_day(t, eng: CardEngine) -> bool:
	var guard := 0
	while guard < 40:
		guard += 1
		var phase := str(eng.view().get("phase", ""))
		var day := int(eng.ctx.state.ns("loop").get("stage_day", 0))
		if phase == "day" and day == 4:
			return _ticket_uid(eng) != ""
		if phase == "game_over":
			t.ok(false, "game over before ticket day")
			return false
		var adv: Dictionary = eng.send(&"day.end", {"confirm": true})
		if not bool(adv.get("ok", false)):
			t.ok(false, "advance " + phase + " day " + str(day) + " " + str(adv.get("err", "")))
			return false
	t.ok(false, "did not reach day 4; hand " + _hand_defs(eng))
	return false


func _g04_params(t, params: Dictionary) -> void:
	t.eq(str(params.get("kind", "")), "fragments", "G04 kind")
	t.eq(str(params.get("item", "missing")), "", "G04 item empty")
	t.eq(str(params.get("doc", "")), "pawn_ticket", "G04 doc")
	t.eq(typeof(params.get("pieces")), TYPE_INT, "G04 pieces")
	t.ok(int(params.get("pieces", 0)) >= 1, "G04 pieces positive")
	t.eq(typeof(params.get("seed")), TYPE_INT, "G04 seed")
	t.eq(typeof(params.get("seal_offset_px")), TYPE_INT, "G04 seal")
	t.eq(typeof(params.get("dangzi_marks")), TYPE_INT, "G04 dangzi")
	t.eq(typeof(params.get("missing_piece")), TYPE_INT, "G04 missing")
	t.eq(typeof(params.get("ink_mismatch")), TYPE_ARRAY, "G04 ink")
	t.eq(typeof(params.get("minutes_per_step")), TYPE_INT, "G04 minutes step")
	t.eq(typeof(params.get("max_minutes")), TYPE_INT, "G04 max minutes")


func _foreign(t, eng: CardEngine) -> void:
	var listed: Dictionary = eng.query(&"tickets")
	var rows: Array = listed.get("tickets", [])
	var hit := false
	for row in rows:
		if typeof(row) != TYPE_DICTIONARY:
			continue
		var one: Dictionary = row
		if int(one.get("no", -1)) != TICKET_NO or not bool(one.get("foreign", false)):
			continue
		hit = true
		t.eq(str(one.get("status", "")), "recorded", "foreign status")
		t.eq(str(one.get("item", "x")), "", "foreign item")
		t.eq(int(one.get("principal", -1)), 0, "foreign principal")
		t.eq(int(one.get("days_left", 0)), -1, "foreign days")
	t.ok(hit, "recorded as foreign pawn ticket " + str(TICKET_NO))


func _ticket_uid(eng: CardEngine) -> String:
	for uid in CardPiles.list(eng.ctx, CardIds.ZONE_HAND):
		if str(CardPiles.card(eng.ctx, uid).get("def", "")) == TICKET:
			return str(uid)
	return ""


func _hand_defs(eng: CardEngine) -> String:
	var parts := PackedStringArray()
	for uid in CardPiles.list(eng.ctx, CardIds.ZONE_HAND):
		parts.append(str(CardPiles.card(eng.ctx, uid).get("def", "")))
	return ",".join(parts)


func _money(eng: CardEngine) -> int:
	var view: Dictionary = eng.view()
	var money = view.get("money", {})
	if typeof(money) != TYPE_DICTIONARY:
		return -1
	return int((money as Dictionary).get("amount", -1))


func _args() -> Dictionary:
	var out := {}
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--"):
			var kv := a.substr(2).split("=", true, 1)
			out[kv[0]] = kv[1] if kv.size() > 1 else "1"
	return out
