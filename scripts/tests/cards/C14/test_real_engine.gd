# Real engine, seed 7.
# Default: example-set regression (only_examples true).
# --data=k11: production data. A guest pawns the K11 gold hairpin, G04 params are weigh,
# autoplay(0.8) plays to the end; autoplay(1.0) reads clear, mg.report succeeds, the call is stored on the item.
# The hairpin's minigame (spot or weigh) is a seeded draw on day, card uid and item id, so any data
# change before it (the 1938 tutorial's handover card, 10-22) can turn every visit to spot. With
# production data the walk tries seeds from 7 up and uses the first one whose hairpin asks to weigh.
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const Fix = preload("res://scripts/tests/cards/C14/weigh_fix.gd")

const HAIRPIN_DEF := "p.linsao.1938.pawn_hairpin"
const HAIRPIN_ITEM := "it.jewelry.hairpin"
const HAIRPIN_TEMPLATE := "jewelry.hairpin"
const SEED := 7
const K11_SEED_TRIES := 12


func _initialize() -> void:
	var test_name := "C14_real_engine"
	var data_mode := "examples"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--name="):
			test_name = a.substr("--name=".length())
		elif a.begins_with("--data="):
			data_mode = a.substr("--data=".length())
	var t := T.new(self, test_name)
	t.run_async(_body.bind(t, data_mode))


func _body(t, data_mode: String) -> void:
	var examples: bool = data_mode != "k11"
	var label := "examples" if examples else "k11"
	var eng: CardEngine = null
	var found: Dictionary = {}
	var last_seed := SEED if examples else SEED + K11_SEED_TRIES - 1
	for game_seed in range(SEED, last_seed + 1):
		eng = CardEngine.new()
		var started: Dictionary = eng.new_game({
			"seed": game_seed,
			"only_examples": examples,
			"save_dir": t.user_dir(),
		})
		if game_seed == SEED:
			t.ok(bool(started.get("ok", false)), "real new_game seed 7 " + label)
			if not bool(started.get("ok", false)):
				return
			t.eq(str(eng.view().get("phase", "")), "month_open", "new game waits at month open")
			if not examples:
				_assert_k11(t, eng)
		elif not bool(started.get("ok", false)):
			t.ok(false, "real new_game seed %d %s" % [game_seed, label])
			return
		found = _walk_to_hairpin(t, eng)
		if not found.is_empty():
			print("C14 hairpin weigh guest: seed %d" % game_seed)
			break
	t.ok(found.has("uid") and not found.has("stop"), "a guest came to pawn a gold hairpin")
	if not found.has("uid") or found.has("stop"):
		return
	var uid := str(found["uid"])
	var item_id := str(found["item"])
	var counter: Dictionary = eng.query(&"counter", {"uid": uid})
	t.eq(str(counter.get("intent", "")), "pawn", "counter intent is pawn")
	var item_v: Variant = counter.get("item")
	t.eq(typeof(item_v), TYPE_DICTIONARY, "counter shows the pawned item")
	if typeof(item_v) == TYPE_DICTIONARY:
		t.eq(str((item_v as Dictionary).get("template", "")), HAIRPIN_TEMPLATE, "item template is the gold hairpin")
		t.eq(str((item_v as Dictionary).get("item", "")), item_id, "counter item id")
	var req: Dictionary = found["req"]
	t.ok(bool(req.get("ok", false)), "mg.request " + str(req.get("err", "")))
	t.eq(str(req.get("kind", "")), "weigh", "this time the minigame is weigh")
	var params: Dictionary = req.get("params", {}) as Dictionary
	t.eq(str(params.get("kind", "")), "weigh", "G04 params kind")
	t.eq(str(params.get("tool", "")), "dengzi", "G04 tool is the dengzi")
	t.eq(str(params.get("item", "")), item_id, "G04 params name this item")
	t.eq(typeof(params.get("claimed_fen")), TYPE_INT, "claimed_fen is int")
	t.eq(typeof(params.get("actual_fen")), TYPE_INT, "actual_fen is int")
	t.ok(int(params.get("claimed_fen", 0)) > 0, "claimed_fen from G04")
	t.ok(int(params.get("actual_fen", 0)) > 0, "actual_fen from G04")
	if not examples:
		var claimed := int(params.get("claimed_fen", 0))
		t.ok(claimed >= 280 and claimed <= 320, "K11 claimed_fen band 280-320")
	t.eq(typeof(params.get("resolution_fen")), TYPE_INT, "resolution_fen is int")
	t.eq(typeof(params.get("weights_fen")), TYPE_ARRAY, "weights_fen is an array")
	t.ok((params.get("weights_fen", []) as Array).size() > 0, "G04 sent weights")
	t.eq(typeof(params.get("seed")), TYPE_INT, "param seed is int")
	for key in CardAppraisal.FORBIDDEN_PARAM_KEYS:
		t.ok(not params.has(str(key)), "params omit " + str(key))
	var fix = Fix.new()
	# The table's own autoplay skill (0.8 = right eight times in ten) plays the real params to the end.
	var g08 = fix.open(self, params)
	await t.frames(2)
	var r08: Dictionary = fix.play(g08, 0.8)
	t.ok(not r08.is_empty(), "autoplay(0.8) finished")
	t.eq(bool(r08.get("aborted", true)), false, "autoplay(0.8) was not an abort")
	t.ok(fix.catalog().has(str((r08.get("observations", [""]) as Array)[0])), "autoplay(0.8) call is in the catalog")
	g08.queue_free()
	await t.frames(1)
	# Skill 1.0 levels and reads clear; its call is the true category of the real params.
	var game = fix.open(self, params)
	await t.frames(2)
	var result: Dictionary = fix.play(game, 1.0)
	t.ok(not result.is_empty(), "autoplay(1.0) finished")
	t.eq(bool(result.get("aborted", true)), false, "autoplay was not an abort")
	t.eq(typeof(result.get("quality_permille")), TYPE_INT, "quality is int")
	t.ok(int(result.get("quality_permille", -1)) >= 700, "skill 1.0 reads a clear weigh")
	t.eq(fix.call_of(result), fix.answer(params), "skill 1.0 calls the real params' category")
	var obs: Array = result.get("observations", [])
	t.eq(obs.size(), 1, "one observation")
	if obs.size() == 1:
		t.ok(fix.catalog().has(str(obs[0])), "observation is in the weigh catalog")
	var reported: Dictionary = eng.send(&"mg.report", {"uid": uid, "item": item_id, "result": result})
	t.ok(bool(reported.get("ok", false)), "mg.report success (%s)" % str(reported.get("err", "")))
	t.eq(str(reported.get("err", "")), "", "mg.report err empty")
	var accepted: Array = reported.get("observations", [])
	if obs.size() == 1:
		t.ok(accepted.has(obs[0]), "report kept " + str(obs[0]))
	var after: Dictionary = eng.query(&"counter", {"uid": uid})
	var after_item: Variant = after.get("item")
	if typeof(after_item) == TYPE_DICTIONARY and obs.size() == 1:
		var kept: Array = (after_item as Dictionary).get("observations", [])
		t.ok(kept.has(obs[0]), "observation stored on the pawned hairpin")
	game.queue_free()
	await t.frames(2)


## Plays days until a hairpin guest asks to weigh: {"uid", "item", "req"}; {"stop": true} on an
## error; {} when this seed's month never brings one.
func _walk_to_hairpin(t, eng: CardEngine) -> Dictionary:
	var guard := 0
	while guard < 160:
		guard += 1
		var phase := str(eng.view().get("phase", ""))
		if phase == "game_over":
			break
		var step: Dictionary = _step(eng, phase)
		if not bool(step.get("ok", false)):
			t.ok(false, "advance %s failed: %s" % [phase, str(step.get("err", ""))])
			return {"stop": true}
		if bool(step.get("scan", false)):
			var found := _take_hairpin(eng)
			if found.has("err"):
				t.ok(false, "hairpin guest: " + str(found["err"]))
				return {"stop": true}
			if not found.is_empty():
				return found
	return {}


func _assert_k11(t, eng: CardEngine) -> void:
	var card: Dictionary = eng.ctx.db.def(HAIRPIN_DEF)
	t.eq(str(card.get("minigame_hint", "")), "weigh", "real pawn card is the K01 hairpin")
	t.eq(str(card.get("intent", "")), "pawn", "real hairpin card intent is pawn")
	var spec: Dictionary = eng.ctx.db.def(HAIRPIN_ITEM)
	t.eq(str(spec.get("template", "")), HAIRPIN_TEMPLATE, "K11 item template")
	t.eq(spec.get("minigames", []), ["spot", "weigh"], "K11 hairpin minigames")
	var weigh: Dictionary = spec.get("weigh", {})
	t.eq(str(weigh.get("tool", "")), "dengzi", "K11 weigh tool")
	t.eq(weigh.get("claimed_fen", []), [280, 320], "K11 claimed_fen spec")


func _step(eng: CardEngine, phase: String) -> Dictionary:
	var res: Dictionary = {"ok": false, "err": "stuck " + phase, "scan": false}
	if phase == "month_open":
		res = eng.send(&"wheel.spin", {"wheel": "wh.month", "uid": ""})
		if bool(res.get("ok", false)):
			res = eng.send(&"month.begin", {})
	elif phase == "morning":
		res = eng.send(&"day.begin", {})
		res["scan"] = true
	elif phase == "day":
		res = eng.send(&"day.end", {"confirm": true})
	elif phase == "night":
		res = eng.send(&"night.choose", {"def": ""})
	elif phase == "settle":
		res = eng.send(&"settle.next", {})
	elif phase == "month_close":
		res = eng.send(&"month.next", {})
	elif phase == "year_jump":
		res = eng.send(&"year.next", {})
	return res


func _take_hairpin(eng: CardEngine) -> Dictionary:
	var hand: Array = eng.view().get("hand", [])
	for card in hand:
		if typeof(card) != TYPE_DICTIONARY:
			continue
		if str(card.get("def", "")) != HAIRPIN_DEF:
			continue
		var uid := str(card.get("uid", ""))
		var opened: Dictionary = eng.send(&"counter.open", {"uid": uid})
		if not bool(opened.get("ok", false)):
			return {"err": str(opened.get("err", "open"))}
		var item_v: Variant = opened.get("item")
		if typeof(item_v) != TYPE_DICTIONARY:
			return {"err": "no item"}
		var item_id := str((item_v as Dictionary).get("item", ""))
		var template := str((item_v as Dictionary).get("template", ""))
		if item_id == "" or template != HAIRPIN_TEMPLATE:
			return {"err": "template " + template}
		var req: Dictionary = eng.send(&"mg.request", {"uid": uid, "item": item_id})
		if not bool(req.get("ok", false)):
			return {"err": str(req.get("err", "mg.request"))}
		if str(req.get("kind", "")) != "weigh":
			var refused: Dictionary = eng.send(&"counter.refuse", {"uid": uid})
			if not bool(refused.get("ok", false)):
				return {"err": "refuse " + str(refused.get("err", ""))}
			continue
		return {"uid": uid, "item": item_id, "req": req}
	return {}
