# Rogue v1: the stock.pick command (ROGUE_V1.md §4.2, §5.3). Relics go through RelicApi.take (RG1, the only writer
# of state.relic); sources are written here. A failed relic take leaves the offer open. Owner RG2. No class_name.
extends RefCounted

const Ids = preload("res://scripts/cards/stock/stock_ids.gd")
const S = preload("res://scripts/cards/stock/stock_state.gd")
const RelicApi = preload("res://scripts/cards/relic/relic_api.gd")


## {offer, pick, replace?} -> {ok, err, offer, picked, kind, released}. pick "" = none of them (passed).
static func pick(ctx: CardCtx, args: Dictionary) -> Dictionary:
	var bad := _arg_error(args)
	if bad != "":
		return _fail(bad)
	if S.phase(ctx) == str(CardIds.PH_GAME_OVER):
		return _fail(CardIds.ERR_BAD_PHASE)
	if not S.active(ctx):
		return _fail(CardIds.ERR_NOT_ALLOWED)
	var offer_id := str(args["offer"])
	var pick_id := str(args["pick"])
	var replace := str(args.get("replace", ""))
	var rec := S.offer(ctx, offer_id)
	if rec.is_empty():
		return _fail(CardIds.ERR_BAD_ARGS)
	if str(rec.get("status", "")) != Ids.ST_OPEN:
		return _fail(CardIds.ERR_ALREADY_RESOLVED)
	if pick_id == "":
		if replace != "":
			return _fail(CardIds.ERR_BAD_ARGS)
		ctx.emit(&"notice", [Ids.N_PASSED, {}])
		return _close(ctx, offer_id, Ids.ST_PASSED, "", "", "")
	var kind := _kind_in(rec, pick_id)
	if kind == "":
		return _fail(CardIds.ERR_NOT_ALLOWED)
	if str(S.def_of(ctx, pick_id).get("type", "")) != kind:
		return _fail(CardIds.ERR_UNKNOWN_DEF)
	if kind == Ids.KIND_RELIC:
		var err := str(RelicApi.take(ctx, pick_id, replace, Ids.SRC_PREFIX + offer_id))
		if err != "":
			return _fail(err)
		return _close(ctx, offer_id, Ids.ST_PICKED, pick_id, kind, replace)
	if replace != "":
		return _fail(CardIds.ERR_BAD_ARGS)
	if S.live_source_ids(ctx).has(pick_id):
		return _fail(CardIds.ERR_NOT_ALLOWED)
	(S.ns(ctx)["sources"] as Array).append({"id": pick_id, "stage": S.stage(ctx), "since": ctx.abs_day()})
	ctx.emit(&"notice", [pick_id + Ids.GAIN_SUFFIX, {}])
	return _close(ctx, offer_id, Ids.ST_PICKED, pick_id, kind, "")


static func _close(ctx: CardCtx, offer_id: String, status: String, picked: String, kind: String,
		released: String) -> Dictionary:
	var rec: Dictionary = (S.ns(ctx)["offers"] as Dictionary)[offer_id]
	rec["status"] = status
	rec["picked"] = picked
	var panel = S.loop_of(ctx).get("open_panel", {})
	if typeof(panel) == TYPE_DICTIONARY and str(panel.get("kind", "")) == str(Ids.PANEL) \
			and typeof(panel.get("args")) == TYPE_DICTIONARY and str(panel["args"].get("offer", "")) == offer_id:
		CardDayLoop.request_panel(ctx, &"", {})
	S.changed(ctx, ["stock", "relics"])
	return {"ok": true, "err": "", "offer": offer_id, "picked": picked, "kind": kind, "released": released}


## Missing or mistyped offer / pick, an empty offer id, a mistyped replace or an unknown key -> bad_args
## (unknown keys are refused like day.end does; the keys are sorted first so the scan never depends on order).
static func _arg_error(args: Dictionary) -> String:
	var keys: Array = args.keys().map(func(key: Variant) -> String: return str(key))
	keys.sort()
	for key in keys:
		if not Ids.PICK_KEYS.has(key):
			return CardIds.ERR_BAD_ARGS
	for key in Ids.PICK_KEYS:
		if (args.has(key) or key != "replace") and not _is_text(args.get(key)):
			return CardIds.ERR_BAD_ARGS
	return CardIds.ERR_BAD_ARGS if str(args["offer"]) == "" else ""


static func _kind_in(rec: Dictionary, id: String) -> String:
	var items = rec.get("items", [])
	if typeof(items) != TYPE_ARRAY:
		return ""
	for row in items:
		if typeof(row) == TYPE_DICTIONARY and str(row.get("id", "")) == id:
			return str(row.get("kind", ""))
	return ""


static func _is_text(v: Variant) -> bool:
	return typeof(v) == TYPE_STRING or typeof(v) == TYPE_STRING_NAME


static func _fail(err: String) -> Dictionary:
	return {"ok": false, "err": err}
