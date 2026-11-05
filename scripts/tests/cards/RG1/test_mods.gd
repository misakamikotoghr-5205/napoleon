# RG1_mods: the seven modifier providers (price_pct patience_pct appraise_pct cap pool_pct deal_count coins), each
# with a matching and a non-matching question and with "when" true / false; the clamp (products and sums pushed
# past rules/relics.json clamp come back to its edge); pool_pct by tags_any and by intents; coins only for "self" in
# a slot tagged official (placements the engine accepts, on the real data's self-accepting official slots); the
# real call sites pricing.gd tiers(), appraisal.gd report() / _aids(), shelf / piles cap, weights.gd, composer and
# slots.gd; everything neutral while the shelf is dormant (street mode, jailed).
# Expected values: base (no relic held, same state) through the relic's own factor, since CardMods.pct multiplies
# provider by provider and the RG1 provider is the last one registered. ROGUE_V1.md §4.5, §5.4. Owner RG1.
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const H = preload("res://scripts/tests/cards/RG1/helper.gd")
const Api = preload("res://scripts/cards/relic/relic_api.gd")
const Mods = preload("res://scripts/cards/relic/relic_mods.gd")

var t
var e: CardEngine
var ctx: CardCtx
## A coins question about a real official slot (built in _coins, asked again in _dormant).
var coin_q: Array = []


func _initialize() -> void:
	t = T.new(self, "RG1_mods")
	e = H.engine(t, H.data_root(t))
	ctx = e.ctx
	t.ok(H.advance(e, 1, "morning"), "first morning")
	_price()
	_patience_and_appraise()
	var seller := _medicine_customer()
	_pricing_call_site(seller[0], seller[1])
	_report_call_site(seller[0], seller[1])
	_caps()
	_pool()
	_deal_count()
	_coins()
	_clamp()
	_dormant()
	t.eq(t.find_floats(ctx.state.data), PackedStringArray(), "no floats in state")
	t.finish()


# ---------------- helpers ----------------
func _hold(ids: Array) -> void:
	H.clear_relics(e)
	for id in ids:
		t.eq(Api.take(ctx, str(id), "", "test"), "", "take " + str(id))


## pct question: with these relics held the answer is base * factor / 100 (base = nothing held, same state).
func _pct(ids: Array, kind: StringName, args: Dictionary, factor: int, msg: String) -> void:
	H.clear_relics(e)
	var base := ctx.mods.pct(ctx, kind, args)
	_hold(ids)
	t.eq(ctx.mods.pct(ctx, kind, args), base * factor / 100, "%s (base %d, factor %d)" % [msg, base, factor])
	H.clear_relics(e)


## sum question: base + delta.
func _sum(ids: Array, kind: StringName, args: Dictionary, delta: int, msg: String) -> void:
	H.clear_relics(e)
	var base := ctx.mods.sum_int(ctx, kind, args)
	_hold(ids)
	t.eq(ctx.mods.sum_int(ctx, kind, args), base + delta, "%s (base %d, delta %d)" % [msg, base, delta])
	H.clear_relics(e)


func _flag(key: String, on: bool) -> void:
	if on:
		ctx.run([{"op": "flag", "key": key, "value": true}], "test")
	else:
		ctx.run([{"op": "flag_clear", "key": key}], "test")


func _almanac_with(want: Array, avoid: Array) -> String:
	for id in ctx.db.ids_of(&"almanac_day"):
		var yi: Array = ctx.db.def(id).get("yi", [])
		if want.all(func(a): return yi.has(a)) and not avoid.any(func(a): return yi.has(a)):
			return id
	return ""


func _set_almanac(id: String) -> void:
	ctx.state.ns("fate")["almanac"] = {"id": id, "done": [], "settled": false}


func _first_def(type: StringName, test: Callable) -> String:
	for id in ctx.db.ids_of(type):
		if test.call(ctx.db.def(id)):
			return id
	return ""


# ---------------- cases ----------------
func _price() -> void:
	var pay_art := {"direction": "pay", "cat": "art", "item_id": ""}
	var pay_med := {"direction": "pay", "cat": "medicine", "item_id": ""}
	var rec_med := {"direction": "receive", "cat": "medicine", "item_id": ""}
	_pct(["rl.rosewood_abacus"], &"price_pct", pay_art, 95, "abacus: pay any category")
	_pct(["rl.rosewood_abacus"], &"price_pct", rec_med, 105, "abacus: receive any category")
	_pct(["rl.chen_mortar"], &"price_pct", pay_med, 95, "mortar: pay medicine")
	_pct(["rl.chen_mortar"], &"price_pct", pay_art, 100, "mortar: pay art does not match its cats")
	_pct(["rl.chen_mortar"], &"price_pct", rec_med, 100, "mortar: receive does not match its direction")
	var keep = ctx.state.ns("fate").get("almanac", {}).duplicate(true)
	var pawn_day := _almanac_with(["pawn_in"], ["sell_out"])
	var plain_day := _almanac_with([], ["pawn_in", "sell_out"])
	t.ok(pawn_day != "" and plain_day != "", "almanac days for the when test (%s, %s)" % [pawn_day, plain_day])
	_set_almanac(pawn_day)
	t.ok(ctx.test({"almanac_yi": "pawn_in"}), "almanac today says pawn_in")
	_pct(["rl.old_almanac"], &"price_pct", pay_art, 96, "almanac: when almanac_yi pawn_in is true")
	_pct(["rl.old_almanac"], &"price_pct", rec_med, 100, "almanac: receive row needs sell_out (when false)")
	_set_almanac(plain_day)
	_pct(["rl.old_almanac"], &"price_pct", pay_art, 100, "almanac: when false -> unchanged")
	ctx.state.ns("fate")["almanac"] = keep
	t.eq(Mods.clamp_key(&"price_pct", pay_art), "price_pay", "clamp key per direction")


## A real medicine seller at the counter (a person card whose item template is medicine.*): [uid, item].
func _medicine_customer() -> Array:
	var def := _first_def(&"person", func(d):
		var spec = d.get("item", {})
		return str(d.get("intent", "")) in ["pawn", "sell"] and typeof(spec) == TYPE_DICTIONARY \
			and str(spec.get("template", "")).begins_with("medicine."))
	t.ok(def != "", "a real medicine seller: " + def)
	var uid := CardPiles.spawn(ctx, def, &"hand")
	CardCounter.open(ctx, uid)
	var item := str(ctx.state.ns("econ").get("sessions", {}).get(uid, {}).get("item", ""))
	t.ok(item != "", "counter session with an item for " + def)
	t.eq(str(ctx.state.ns("econ")["items_meta"][item]["cat"]), "medicine", "the seller brings medicine")
	return [uid, item]


## The real call site economy/pricing.gd tiers(): the mortar's "pay 95 on medicine" reaches the fair tier, so
## tiers() asks with direction "pay" and the item's own cat.
func _pricing_call_site(uid: String, item: String) -> void:
	var s: Dictionary = ctx.state.ns("econ")["sessions"][uid]
	var fair_rule := int(ctx.rules("economy")["tiers"]["pay"]["fair"])
	H.clear_relics(e)
	var pct0 := ctx.mods.pct(ctx, &"price_pct", {"direction": "pay", "cat": "medicine", "item_id": item})
	var fair0 := int(CardPricing.tiers(ctx, uid)["fair"])
	t.eq(fair0, maxi(1, int(s["asking"]) * fair_rule * pct0 / 10000), "pricing.gd: fair tier with no relic")
	_hold(["rl.chen_mortar"])
	var fair1 := int(CardPricing.tiers(ctx, uid)["fair"])
	t.eq(fair1, maxi(1, int(s["asking"]) * fair_rule * (pct0 * 95 / 100) / 10000),
		"pricing.gd: mortar pay 95 in the fair tier")
	t.ok(fair1 < fair0, "pricing.gd: the fair tier drops with the mortar (%d -> %d)" % [fair0, fair1])
	H.clear_relics(e)


func _patience_and_appraise() -> void:
	_pct(["rl.blue_curtain"], &"patience_pct", {"uid": ""}, 115, "curtain: patience for everyone")
	_pct(["rl.cat_bowl"], &"patience_pct", {"uid": ""}, 100, "cat bowl: no lost cat (when false)")
	_flag("pet_lost", true)
	_pct(["rl.cat_bowl"], &"patience_pct", {"uid": ""}, 90, "cat bowl: lost cat (when true)")
	_pct(["rl.cat_bowl"], &"appraise_pct", {"cat": "art", "item_id": ""}, 100, "cat bowl: home row false while lost")
	_flag("pet_lost", false)
	_flag("pet_home", true)
	_pct(["rl.cat_bowl"], &"appraise_pct", {"cat": "art", "item_id": ""}, 110, "cat bowl: cat at home, any category")
	_flag("pet_home", false)
	var med := {"cat": "medicine", "item_id": ""}
	var art := {"cat": "art", "item_id": ""}
	_pct(["rl.chen_mortar"], &"appraise_pct", med, 125, "mortar: medicine")
	_pct(["rl.chen_mortar"], &"appraise_pct", {"cat": "rice", "item_id": ""}, 100, "mortar: rice does not match")
	t.ok(not ctx.test({"has_contact": "chen"}), "no chen contact yet")
	_pct(["rl.chen_mortar"], &"appraise_pct", art, 100, "mortar: art needs chen (when false)")
	ctx.run([{"op": "contact_gain", "person": "chen"}], "test")
	t.ok(ctx.test({"has_contact": "chen"}), "chen is a contact now")
	_pct(["rl.chen_mortar"], &"appraise_pct", art, 120, "mortar: art with chen (when true)")
	_pct(["rl.master_steelyard"], &"appraise_pct", {"cat": "silver", "item_id": ""}, 120, "steelyard: silver")
	_pct(["rl.master_steelyard"], &"patience_pct", {"uid": ""}, 92, "steelyard: its flaw row still counts")
	# The real call site economy/appraisal.gd _aids() (after the 10-25 rework) treats appraise_pct above
	# economy.appraise.expert_pct as a knowing eye (full legend / backlight); report() is in _report_call_site.
	H.clear_relics(e)
	var expert := int(ctx.rules("economy").get("appraise", {}).get("expert_pct", 100))
	t.ok(ctx.mods.pct(ctx, &"appraise_pct", {"cat": "silver", "item_id": ""}) <= expert, "silver: no knowing eye yet")
	t.eq(bool(CardAppraisal._aids(ctx, &"spot", "silver", "")["legend_full"]), false, "appraisal aids: plain legend")
	_hold(["rl.master_steelyard"])
	t.eq(bool(CardAppraisal._aids(ctx, &"spot", "silver", "")["legend_full"]), true,
		"appraisal aids: the steelyard (appraise 120 on silver) reads as a knowing eye")
	t.eq(bool(CardAppraisal._aids(ctx, &"fragments", "silver", "")["backlight"]), true, "appraisal aids: backlight too")
	t.eq(bool(CardAppraisal._aids(ctx, &"spot", "rice", "")["legend_full"]), false, "appraisal aids: not on rice")
	H.clear_relics(e)


## The real call site economy/appraisal.gd report(): the clarity is quality_permille * appraise_pct (asked with the
## item's cat). A quality just short of clear_permille alone is lifted to clear by the mortar's 125 on medicine, so
## a "clear" claim is recorded as itself instead of its partial hedge.
func _report_call_site(uid: String, item: String) -> void:
	var clear := int(ctx.rules("economy").get("appraise", {}).get("clear_permille", 700))
	var partial := int(ctx.rules("economy").get("appraise", {}).get("partial_permille", 350))
	H.clear_relics(e)
	var pct0 := ctx.mods.pct(ctx, &"appraise_pct", {"cat": "medicine", "item_id": item})
	var pct1 := pct0 * 125 / 100
	var quality := (clear * 100 + pct1 - 1) / pct1
	t.ok(quality * pct1 / 100 >= clear and quality * pct0 / 100 < clear and quality * pct0 / 100 >= partial,
		"quality %d: partial alone (pct %d), clear with the mortar (pct %d)" % [quality, pct0, pct1])
	var kind := str(CardAppraisal.request(ctx, uid, item).get("kind", ""))
	var claim := ""
	var hedge := ""
	var catalog := ctx.db.obs_catalog(StringName(kind))
	var keys: Array = catalog.keys()
	keys.sort()
	for k in keys:
		var h = catalog[k].get("hedge")
		if claim == "" and str(catalog[k].get("fidelity", "")) == "clear" and typeof(h) == TYPE_DICTIONARY \
				and not str(h.get("partial", "")) in ["", str(k)]:
			claim = str(k)
			hedge = str(h["partial"])
	t.ok(claim != "", "a clear claim with a partial hedge in the %s catalog" % kind)
	t.eq(_report_once(uid, item, quality, claim), [hedge], "report(): no relic -> partial, the hedge is recorded")
	_hold(["rl.chen_mortar"])
	t.eq(str(CardAppraisal.request(ctx, uid, item).get("kind", "")), kind, "same minigame on the second look")
	t.eq(_report_once(uid, item, quality, claim), [claim], "report(): the mortar lifts the clarity to clear")
	H.clear_relics(e)


## One CardAppraisal.report on an open request (no minutes spent, no calls made): the observations it accepted.
func _report_once(uid: String, item: String, quality: int, claim: String) -> Array:
	var r := CardAppraisal.report(ctx, uid, item,
		{"quality_permille": quality, "observations": [claim], "minutes": 0, "measures": {}, "aborted": false})
	t.ok(bool(r.get("ok", false)), "appraisal report accepted: %s" % r)
	return r.get("observations", [])


func _caps() -> void:
	_sum(["rl.stub_box"], &"cap", {"zone": &"kept"}, 1, "stub box: kept +1")
	_sum(["rl.stub_box"], &"cap", {"zone": &"shelf"}, -1, "stub box: shelf -1 (flaw)")
	_sum(["rl.stub_box"], &"cap", {"zone": &"hand"}, 0, "stub box: other zones untouched")
	var estates: Dictionary = ctx.state.ns("ladder").get("estates", {})
	t.eq(str(estates.get("es.old_house", {}).get("status", "")), "held", "old house held at the start")
	_sum(["rl.camphor_chest"], &"cap", {"zone": &"kept"}, 1, "chest: kept +1 while the old house is held")
	_sum(["rl.camphor_chest"], &"cap", {"zone": &"shelf"}, 2, "chest: shelf +2 while the old house is held")
	estates["es.old_house"]["status"] = "mortgaged"
	_sum(["rl.camphor_chest"], &"cap", {"zone": &"kept"}, 0, "chest: nothing once the house is mortgaged (when false)")
	_sum(["rl.camphor_chest"], &"cap", {"zone": &"shelf"}, 0, "chest: no shelf either")
	estates["es.old_house"]["status"] = "held"
	# The real call sites: shelf.gd cap and card_piles.gd cap.
	H.clear_relics(e)
	var shelf0 := CardShelf.cap(ctx)
	var kept0 := CardPiles.cap(ctx, &"kept")
	_hold(["rl.camphor_chest"])
	t.eq(CardShelf.cap(ctx), shelf0 + 2, "CardShelf.cap sees the chest")
	t.eq(CardPiles.cap(ctx, &"kept"), kept0 + 1, "CardPiles.cap(kept) sees the chest")
	t.eq(e.view()["caps"]["shelf"], shelf0 + 2, "view caps.shelf (a visible count)")
	H.clear_relics(e)


func _pool() -> void:
	var buyer := _first_def(&"person", func(d): return str(d.get("intent", "")) == "buy")
	var pawner := _first_def(&"person", func(d): return str(d.get("intent", "")) == "pawn")
	var search := _first_def(&"event", func(d): return (d.get("tags", []) as Array).has("search"))
	var quiet := _first_def(&"event", func(d): return not (d.get("tags", []) as Array).has("search"))
	var poor := _first_def(&"person", func(d): return (d.get("tags", []) as Array).has("poor"))
	t.ok(buyer != "" and pawner != "" and search != "" and quiet != "" and poor != "", "real cards for the pool test")
	_pct(["rl.blue_curtain"], &"pool_pct", {"pool": "person", "def": buyer}, 85, "curtain: buyers (intents)")
	_pct(["rl.blue_curtain"], &"pool_pct", {"pool": "person", "def": pawner}, 100, "curtain: pawners do not match")
	_pct(["rl.blue_curtain"], &"pool_pct", {"pool": "event", "def": buyer}, 100, "curtain: other pool")
	_pct(["rl.chen_mortar"], &"pool_pct", {"pool": "event", "def": search}, 115, "mortar: search events (tags_any)")
	_pct(["rl.chen_mortar"], &"pool_pct", {"pool": "event", "def": quiet}, 100, "mortar: other events")
	_pct(["rl.rosewood_abacus"], &"pool_pct", {"pool": "person", "def": poor}, 60, "abacus: poor people")
	# Through the real call site (fate/weights.gd): the factor list ends with the modifier answer.
	H.clear_relics(e)
	var before: Array = CardWeights._percentages(ctx, "person", ctx.db.def(buyer), [])
	_hold(["rl.blue_curtain"])
	var after: Array = CardWeights._percentages(ctx, "person", ctx.db.def(buyer), [])
	t.eq(after.back(), int(before.back()) * 85 / 100, "weights.gd sees the curtain")
	H.clear_relics(e)


func _deal_count() -> void:
	var fate := ctx.state.ns("fate")
	var weather := str(fate.get("weather", "clear"))
	fate["weather"] = "rain"
	_sum(["rl.oilpaper_umbrella"], &"deal_count", {"type": &"person", "abs_day": ctx.abs_day()}, 1, "umbrella: rain")
	_sum(["rl.oilpaper_umbrella"], &"deal_count", {"type": &"event", "abs_day": ctx.abs_day()}, 0, "umbrella: other pools")
	# Through the real call site (core/card_composer.gd: today's and projected deal counts).
	H.clear_relics(e)
	var n0 := CardComposer._modified_count(ctx, &"person", 3, ctx.abs_day())
	var news0 := CardComposer._modified_count(ctx, &"news", 1, ctx.abs_day())
	_hold(["rl.oilpaper_umbrella"])
	t.eq(CardComposer._modified_count(ctx, &"person", 3, ctx.abs_day()), n0 + 1, "composer: one more person in the rain")
	t.eq(CardComposer._modified_count(ctx, &"news", 1, ctx.abs_day()), news0, "composer: news count untouched")
	H.clear_relics(e)
	fate["weather"] = "clear"
	_sum(["rl.oilpaper_umbrella"], &"deal_count", {"type": &"person", "abs_day": ctx.abs_day()}, 0, "umbrella: dry day")
	fate["weather"] = weather


## coins (rl.sun_inkpad: "self" in a slot tagged official, +1). Every question is about a placement the engine
## accepts (CardSlots.can_place == ""). The real data tags the "man" slot (self or a contact) of the official events
## (police check, road pass, patrols, household count, shop search ...) official, so this asks one of those.
func _coins() -> void:
	var me := {"kind": "self"}
	var seat := _event_slot(func(s): return _has(s, "tags", "official") and _has(s, "accepts", "self"))
	t.ok(not seat.is_empty(), "a real event slot tagged official that takes self")
	if seat.is_empty():
		return
	var uid := CardPiles.spawn(ctx, seat[0], &"hand")
	var official := str(seat[2])
	t.eq(CardSlots.can_place(ctx, uid, official, me), "",
		"self may stand in the real official slot %s/%s" % [seat[0], official])
	coin_q = [&"coins", {"uid": uid, "slot_id": official, "source": me}]
	_sum(["rl.sun_inkpad"], &"coins", coin_q[1], 1, "inkpad: self in an official slot")
	var cash := _event_slot(func(s): return _has(s, "tags", "official") and _has(s, "accepts", "money"))
	var cash_uid := CardPiles.spawn(ctx, cash[0], &"hand")
	var coin := {"kind": "money", "amount": 10}
	t.eq(CardSlots.can_place(ctx, cash_uid, str(cash[2]), coin), "", "money may go in the real official slot " + cash[0])
	_sum(["rl.sun_inkpad"], &"coins", {"uid": cash_uid, "slot_id": str(cash[2]), "source": coin}, 0,
		"inkpad: money in an official slot")
	var plain := _event_slot(func(s): return _has(s, "accepts", "self") and not _has(s, "tags", "official"))
	var plain_uid := CardPiles.spawn(ctx, plain[0], &"hand")
	t.eq(CardSlots.can_place(ctx, plain_uid, str(plain[2]), me), "", "self may stand in the untagged slot " + plain[0])
	_sum(["rl.sun_inkpad"], &"coins", {"uid": plain_uid, "slot_id": str(plain[2]), "source": me}, 0,
		"inkpad: self in an untagged slot")
	# Through the real call site: CardSlots.place, then the slot view (rules/slots.gd _source_view asks coins).
	H.clear_relics(e)
	var placed := CardSlots.place(ctx, uid, official, me)
	t.ok(bool(placed.get("ok", false)), "self placed in the official slot: %s" % placed)
	t.eq(_slot_coins(uid, official), int(placed.get("coins", -1)), "slot view coins = place() coins")
	_hold(["rl.sun_inkpad"])
	t.eq(_slot_coins(uid, official), int(placed.get("coins", -1)) + 1, "slots.gd slot view shows one more coin")
	t.ok(bool(CardSlots.remove(ctx, uid, official, 0).get("ok", false)), "self taken back out")
	H.clear_relics(e)


## The first top-level slot of a real event card that passes test: [def id, slot index, slot id]; [] when none.
func _event_slot(test: Callable) -> Array:
	for id in ctx.db.ids_of(&"event"):
		var slots = ctx.db.def(id).get("slots", [])
		if typeof(slots) != TYPE_ARRAY:
			continue
		for i in range(slots.size()):
			if typeof(slots[i]) == TYPE_DICTIONARY and test.call(slots[i]):
				return [id, i, str(slots[i].get("id", ""))]
	return []


func _has(slot: Dictionary, key: String, value: String) -> bool:
	return typeof(slot.get(key)) == TYPE_ARRAY and (slot[key] as Array).has(value)


func _slot_coins(uid: String, slot_id: String) -> int:
	for v in CardSlots.slot_views(ctx, uid):
		if str(v["id"]) == slot_id:
			return int(v["coins"])
	return -1


func _clamp() -> void:
	t.eq(Mods.limit(ctx, "price_pay_min", 0), 90, "clamp read from rules/relics.json")
	var keep = ctx.state.ns("fate").get("almanac", {}).duplicate(true)
	_set_almanac(_almanac_with(["pawn_in"], []))
	var three := ["rl.rosewood_abacus", "rl.chen_mortar", "rl.old_almanac"]
	var med := {"direction": "pay", "cat": "medicine", "item_id": ""}
	t.eq(Mods.combine(ctx, &"price_pct", med, []), 100, "no relic -> neutral")
	var raw := 100 * 95 / 100 * 95 / 100 * 96 / 100
	t.ok(raw < 90, "three pay rows multiply below the clamp (%d)" % raw)
	_pct(three, &"price_pct", med, 90, "pay product clamped up to price_pay_min")
	ctx.state.ns("fate")["almanac"] = keep
	_pct(["rl.chen_mortar", "rl.master_steelyard"], &"appraise_pct", {"cat": "medicine", "item_id": ""}, 140,
		"appraise 125 x 120 clamped down to appraise_max")
	_sum(["rl.stub_box", "rl.camphor_chest"], &"cap", {"zone": &"kept"}, 1, "kept +1 +1 clamped to kept_cap_max")
	_sum(["rl.stub_box", "rl.camphor_chest"], &"cap", {"zone": &"shelf"}, 1, "shelf -1 +2 inside the clamp")
	_clamp_two()


## With the s6.4 numbers two pay rows land exactly on 90 (95 x 95 / 100); on a data root whose price_pay_min is 92
## the same two relics are pulled back up to 92 before CardMods sees them.
func _clamp_two() -> void:
	var e2 := H.engine(t, H.data_root(t, {"clamp": {"price_pay_min": 92}}, "cards_clamp"), 7, "clamp")
	var c2 := e2.ctx
	var med := {"direction": "pay", "cat": "medicine", "item_id": ""}
	var base := c2.mods.pct(c2, &"price_pct", med)
	for id in ["rl.rosewood_abacus", "rl.chen_mortar"]:
		t.eq(Api.take(c2, id, "", "test"), "", "clamp root: take " + id)
	t.eq(Mods.combine(c2, &"price_pct", med, Api.working_defs(c2)), 92, "two pay rows (90) clamped up to price_pay_min 92")
	t.eq(c2.mods.pct(c2, &"price_pct", med), base * 92 / 100, "CardMods hands out the clamped factor")
	t.eq(Mods.limit(c2, "price_pay_max", 0), 105, "a clamp key the rules leave out falls back to the s6.3 default")


func _dormant() -> void:
	var fate := ctx.state.ns("fate")
	fate["weather"] = "rain"
	var buyer := _first_def(&"person", func(d): return str(d.get("intent", "")) == "buy")
	var six := ["rl.rosewood_abacus", "rl.blue_curtain", "rl.chen_mortar", "rl.stub_box", "rl.oilpaper_umbrella",
		"rl.sun_inkpad"]
	var questions := [
		[&"price_pct", {"direction": "pay", "cat": "medicine", "item_id": ""}], [&"patience_pct", {"uid": ""}],
		[&"appraise_pct", {"cat": "medicine", "item_id": ""}], [&"pool_pct", {"pool": "person", "def": buyer}],
		[&"cap", {"zone": &"kept"}], [&"cap", {"zone": &"shelf"}], [&"deal_count", {"type": &"person", "abs_day": 1}],
	]
	t.ok(not coin_q.is_empty(), "the coins question from _coins")
	questions.append(coin_q)
	H.clear_relics(e)
	var base: Array = []
	for q in questions:
		base.append(_ask(q))
	_hold(six)
	var awake := 0
	for i in range(questions.size()):
		if _ask(questions[i]) != base[i]:
			awake += 1
	t.eq(awake, questions.size(), "awake: every question changes")
	ctx.state.ns("loop")["mode"] = "street"
	for i in range(questions.size()):
		t.eq(_ask(questions[i]), base[i], "street: %s neutral" % str(questions[i][0]))
	ctx.state.ns("loop")["mode"] = "shop"
	var ladder := ctx.state.ns("ladder")
	var had: bool = ladder.has("prison")
	var old = ladder.get("prison")
	ladder["prison"] = {"uid": "c9999", "nights": 0}
	for i in range(questions.size()):
		t.eq(_ask(questions[i]), base[i], "jailed: %s neutral" % str(questions[i][0]))
	if had:
		ladder["prison"] = old
	else:
		ladder.erase("prison")
	H.clear_relics(e)
	fate["weather"] = "clear"


func _ask(q: Array) -> int:
	if q[0] in [&"cap", &"deal_count", &"coins"]:
		return ctx.mods.sum_int(ctx, q[0], q[1])
	return ctx.mods.pct(ctx, q[0], q[1])
