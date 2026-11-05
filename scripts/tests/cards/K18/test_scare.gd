# K18: hide the pistol in 1939, scare only from 1940, day.end stays usable.
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const PAWN := "p.nf_pistol.1939.pawn_gun"
const GUEST := "p.chen.1939.pawn_clock"
const GOLD := "p.brother.1938.farewell"
const PISTOL := "kp.pistol"
const BUY := "p.sunyoung.1939.buy_scroll"
const REDEEM := "p.chen.1939.redeem"


func _initialize() -> void:
	var t := T.new(self, "K18_scare")
	_stage_one(t)
	_stage_two(t)
	t.finish()


func _boot(t, stage: int, tag: String) -> CardEngine:
	var e := CardEngine.new()
	var made := e.new_game({"seed": 7, "stage": stage, "save_dir": t.user_dir() + "/" + tag})
	t.ok(bool(made.get("ok", false)), "new " + tag + " " + str(made.get("err", "")))
	var guard := 0
	while str(e.view().get("phase", "")) != "day" and guard < 6:
		var adv := e.send(&"day.end", {"confirm": true})
		t.ok(bool(adv.get("ok", false)), "advance " + tag + " " + str(adv.get("err", "")))
		guard += 1
	t.eq(str(e.view().get("phase", "")), "day", "phase day " + tag)
	t.no_leaks(e.view(), "view " + tag)
	return e


func _ids(ctx: CardCtx, uid: String) -> Array:
	var out: Array = []
	for row in CardChoices.options(ctx, uid):
		out.append(str(row.get("id", "")))
	return out


func _kept(ctx: CardCtx, def_id: String) -> bool:
	for uid in CardPiles.list(ctx, &"kept"):
		if str(CardPiles.card(ctx, uid).get("def", "")) == def_id:
			return true
	return false


func _stage_one(t) -> void:
	var e := _boot(t, 1, "y1939")
	var ctx := e.ctx
	var pawn := CardPiles.spawn(ctx, PAWN, &"hand")
	t.ok(pawn != "", "pawn spawned")
	var ids := _ids(ctx, pawn)
	t.ok(not ids.has("scare"), "no scare in 1939")
	t.ok(not ids.has("act"), "no act on pawn")
	var hid := e.send(&"card.choose", {"uid": pawn, "choice": "hide"})
	t.ok(bool(hid.get("ok", false)), "hide " + str(hid.get("err", "")))
	t.ok(_kept(ctx, PISTOL), "pistol kept")
	t.ok(ctx.test({"flag": "weapon_held"}), "weapon_held")
	var guest := CardPiles.spawn(ctx, GUEST, &"hand")
	t.ok(not _ids(ctx, guest).has("scare"), "no scare on guest in 1939")
	var end := e.send(&"day.end", {"confirm": true})
	t.ok(bool(end.get("ok", false)), "1939 day.end " + str(end.get("err", "")))
	t.ok(str(e.view().get("phase", "")) != "day", "1939 day.end advances")


func _stage_two(t) -> void:
	var e := _boot(t, 2, "y1940")
	var ctx := e.ctx
	var pistol := CardPiles.spawn(ctx, PISTOL, &"kept")
	t.eq(CardPiles.zone_of(ctx, pistol), &"kept", "pistol zone")
	var guest := CardPiles.spawn(ctx, GUEST, &"hand")
	t.ok(not CardFirsts.all(ctx).has("scare"), "scare not marked yet")
	CardChoices.options(ctx, guest)
	t.ok(not CardFirsts.all(ctx).has("scare"), "options read only")
	t.ok(_ids(ctx, guest).has("scare"), "scare on guest")
	t.ok(not _ids(ctx, guest).has("act"), "no act")
	ctx.hooks.fire(ctx, CardIds.HOOK_DEAL_COMPOSED, {"uids": [guest]})
	t.ok(CardFirsts.all(ctx).has("scare"), "scare marked")
	var marked := int(CardFirsts.all(ctx)["scare"])
	ctx.hooks.fire(ctx, CardIds.HOOK_DEAL_COMPOSED, {"uids": [guest]})
	t.eq(int(CardFirsts.all(ctx)["scare"]), marked, "scare once")
	var gold := CardPiles.spawn(ctx, GOLD, &"hand")
	t.ok(not _ids(ctx, gold).has("scare"), "no scare on gold")
	CardPiles.move(ctx, pistol, &"discard")
	var bare := CardPiles.spawn(ctx, GUEST, &"hand")
	t.ok(not _ids(ctx, bare).has("scare"), "no pistol no scare")
	CardPiles.move(ctx, pistol, &"kept")
	_intent_scare(t, e)
	_success(t, e)
	_fail(t, e)
	_end_open(t, e)



func _intent_scare(t, e: CardEngine) -> void:
	var ctx := e.ctx
	var redeem := CardPiles.spawn(ctx, REDEEM, &"hand")
	t.ok(_ids(ctx, redeem).has("scare"), "scare on redeem guest")
	t.eq(str(CardViewModel.panel_of(CardPiles.def_of(ctx, redeem))), "counter", "redeem uses counter")
	if ctx.db.has(BUY):
		var buy := CardPiles.spawn(ctx, BUY, &"hand")
		t.ok(_ids(ctx, buy).has("scare"), "scare on buy guest")
		t.eq(str(CardViewModel.panel_of(CardPiles.def_of(ctx, buy))), "counter", "buy uses counter")
	# needs_slots only — do not day.end here; phase must stay day for later rolls.
	var guest := CardPiles.spawn(ctx, GUEST, &"hand")
	var chose := e.send(&"card.choose", {"uid": guest, "choice": "scare"})
	t.ok(bool(chose.get("ok", false)) and bool(chose.get("needs_slots", false)), "counter scare needs_slots")


func _spawn_heads(t, ctx: CardCtx) -> String:
	var seq := int(ctx.state.ns("core")["uid_seq"])
	var head: Dictionary = ctx.rules("slots").get("head", {"num": 1, "den": 2})
	var num := float(int(head.get("num", 1)))
	var den := float(maxi(1, int(head.get("den", 2))))
	var abs_day := ctx.abs_day()
	var pad := 0
	var want := ""
	var found := false
	while pad < 40:
		want = "c%04d" % (seq + 1 + pad)
		var draw := JevRng.draw(ctx.seed(), "c.coin", [abs_day, want, 0, 0])
		if draw * den < num:
			found = true
			break
		pad += 1
	t.ok(found, "found heads")
	var n := 0
	while n < pad:
		CardPiles.spawn(ctx, "kp.brother_note", &"discard")
		n += 1
	var uid := CardPiles.spawn(ctx, GUEST, &"hand")
	t.eq(uid, want, "heads uid")
	return uid


func _success(t, e: CardEngine) -> void:
	var ctx := e.ctx
	var uid := _spawn_heads(t, ctx)
	var heat := CardMeters.value(ctx, &"heat")
	var rep := CardMeters.value(ctx, &"rep")
	var chose := e.send(&"card.choose", {"uid": uid, "choice": "scare"})
	t.ok(bool(chose.get("ok", false)) and bool(chose.get("needs_slots", false)), "scare needs slots")
	var placed := e.send(&"slot.place", {"uid": uid, "slot": "nerve", "source": {"kind": "self"}})
	t.ok(bool(placed.get("ok", false)), "place self " + str(placed.get("err", "")))
	t.eq(int(placed.get("coins", -1)), 1, "one nerve coin")
	var rolled := e.send(&"slot.roll", {"uid": uid})
	t.ok(bool(rolled.get("ok", false)) and bool(rolled.get("success", false)), "scare success")
	t.ok(ctx.test({"flag": "weapon_scare_yield"}), "yield flag")
	t.ok(not ctx.test({"flag": "weapon_scare_reported"}), "no report on success")
	t.eq(CardMeters.value(ctx, &"heat"), heat + 1, "success heat")
	t.eq(CardMeters.value(ctx, &"rep"), rep - 1, "success rep")
	t.ok(_kept(ctx, PISTOL), "pistol stays after success")
	t.no_leaks(rolled, "roll")


func _fail(t, e: CardEngine) -> void:
	var ctx := e.ctx
	ctx.state.ns("loop")["abs_day"] = ctx.abs_day() + 1
	var attrs: Dictionary = ctx.state.ns("rules")["attrs"]
	attrs["ruhua"]["nerve"] = 0
	var uid := CardPiles.spawn(ctx, GUEST, &"hand")
	t.ok(_ids(ctx, uid).has("scare"), "scare still on")
	var heat := CardMeters.value(ctx, &"heat")
	var rep := CardMeters.value(ctx, &"rep")
	t.ok(bool(e.send(&"card.choose", {"uid": uid, "choice": "scare"}).get("ok", false)), "choose fail path")
	t.eq(str(e.send(&"slot.roll", {"uid": uid}).get("err", "")), "slot_required", "roll needs a person")
	var placed := e.send(&"slot.place", {"uid": uid, "slot": "nerve", "source": {"kind": "self"}})
	t.ok(bool(placed.get("ok", false)), "place for fail " + str(placed.get("err", "")))
	var rolled := e.send(&"slot.roll", {"uid": uid})
	t.ok(bool(rolled.get("ok", false)) and not bool(rolled.get("success", true)), "scare fail")
	t.ok(ctx.test({"flag": "weapon_scare_reported"}), "reported")
	t.eq(CardMeters.value(ctx, &"heat"), heat + 3, "fail heat")
	t.eq(CardMeters.value(ctx, &"rep"), rep, "fail rep unchanged")
	t.eq(int(ctx.state.ns("rules").get("counters", {}).get("weapon_scare_uses", 0)), 2, "two uses")
	t.ok(_kept(ctx, PISTOL), "pistol stays after fail")


func _end_open(t, e: CardEngine) -> void:
	var uid := CardPiles.spawn(e.ctx, GUEST, &"hand")
	var chose := e.send(&"card.choose", {"uid": uid, "choice": "scare"})
	t.ok(bool(chose.get("needs_slots", false)), "chosen but not rolled")
	var end := e.send(&"day.end", {"confirm": true})
	t.ok(bool(end.get("ok", false)), "day.end after scare " + str(end.get("err", "")))
	t.ok(str(e.view().get("phase", "")) != "day", "day.end leaves day")
