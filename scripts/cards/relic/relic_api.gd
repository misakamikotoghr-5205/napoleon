# Rogue v1 relics: the only write path into state.relic (RG2 calls take()). Owner RG1. No class_name; preload it.
# State (ROGUE_V1.md §3.1): {"_v": 1, "held": [{"id", "since", "src"}], "gone": [ids]}. Built lazily on the first take:
# reads never create the namespace, so a game without relics keeps its state hash byte for byte.
extends RefCounted

const Ids = preload("res://scripts/cards/relic/relic_ids.gd")


## rules/relics.json exists with enabled (default true), and at least one relic in the data base. No rules file =
## off (ROGUE_V1.md §6.3), the same contract as stock_state.active.
static func active(ctx: CardCtx) -> bool:
	var r := ctx.rules(Ids.RULES)
	return not r.is_empty() and bool(r.get("enabled", true)) and not ctx.db.ids_of(&"relic").is_empty()


## Held relic ids in the order they were taken.
static func held_ids(ctx: CardCtx) -> PackedStringArray:
	var out := PackedStringArray()
	for row in _peek(ctx).get("held", []):
		if typeof(row) == TYPE_DICTIONARY:
			out.append(str(row.get("id", "")))
	return out


## Relics given up this run; never offered again.
static func gone_ids(ctx: CardCtx) -> PackedStringArray:
	var out := PackedStringArray()
	for id in _peek(ctx).get("gone", []):
		out.append(str(id))
	return out


static func cap(ctx: CardCtx) -> int:
	return int(ctx.rules(Ids.RULES).get("cap", Ids.DEFAULT_CAP))


static func is_full(ctx: CardCtx) -> bool:
	return held_ids(ctx).size() >= cap(ctx)


## "" when take() would succeed, otherwise the error code it would return (ROGUE_V1.md §4.7).
static func can_take(ctx: CardCtx, id: String, replace: String) -> String:
	if not active(ctx):
		return CardIds.ERR_NOT_ALLOWED
	var d: Dictionary = ctx.db._cards.get(id, {})
	if d.is_empty() or str(d.get("type", "")) != "relic":
		return CardIds.ERR_UNKNOWN_DEF
	var held := held_ids(ctx)
	if held.has(id) or gone_ids(ctx).has(id):
		return CardIds.ERR_NOT_ALLOWED
	if replace != "" and not held.has(replace):
		return Ids.ERR_NOT_HELD
	if replace == "" and held.size() >= cap(ctx):
		return Ids.ERR_RELIC_FULL
	return ""


## Puts a relic on the shelf; with replace, that one goes back to the store room first (into gone).
## src is only for logs ("stock:<offer id>" / "test"). Emits the notices and view_changed ["relics"].
static func take(ctx: CardCtx, id: String, replace: String, src: String) -> String:
	var err := can_take(ctx, id, replace)
	if err != "":
		return err
	var ns := _ensure(ctx)
	if replace != "":
		var kept: Array = []
		for row in ns["held"]:
			if typeof(row) == TYPE_DICTIONARY and str(row.get("id", "")) != replace:
				kept.append(row)
		ns["held"] = kept
		(ns["gone"] as Array).append(replace)
		ctx.emit(&"notice", [Ids.NOTICE_RELEASED, {}])
	(ns["held"] as Array).append({"id": id, "since": ctx.abs_day(), "src": src})
	ctx.emit(&"notice", [id + Ids.GAIN_FIELD, {}])
	ctx.emit(&"view_changed", [[Ids.VIEW_KEY]])
	return ""


## Relics do nothing while the shop is lost (street mode) or the player is jailed (rules switches, default on).
static func dormant(ctx: CardCtx) -> bool:
	if ctx.state == null:
		return false
	var rules := ctx.rules(Ids.RULES)
	if bool(rules.get("dormant_in_street", true)) \
			and str(ctx.state.data.get("loop", {}).get("mode", CardIds.MODE_SHOP)) == str(CardIds.MODE_STREET):
		return true
	var prison = ctx.state.data.get("ladder", {}).get("prison", {})
	return bool(rules.get("dormant_in_prison", true)) and typeof(prison) == TYPE_DICTIONARY \
		and str(prison.get("uid", "")) != ""


## Held relic definitions in holding order, skipping ids the data base no longer has. [] when the module is off,
## nothing is held or the relics are dormant: the modifier providers and hooks start with this.
static func working_defs(ctx: CardCtx) -> Array:
	var rows: Array = _peek(ctx).get("held", [])
	if rows.is_empty() or not active(ctx) or dormant(ctx):
		return []
	var out: Array = []
	for row in rows:
		if typeof(row) != TYPE_DICTIONARY:
			continue
		var d: Dictionary = ctx.db._cards.get(str(row.get("id", "")), {})
		if str(d.get("type", "")) == "relic":
			out.append(d)
	return out


## Read-only view of state.relic ({} when it was never written). Never creates the namespace.
static func _peek(ctx: CardCtx) -> Dictionary:
	if ctx.state == null:
		return {}
	var ns = ctx.state.data.get(Ids.NS, {})
	return ns if typeof(ns) == TYPE_DICTIONARY else {}


static func _ensure(ctx: CardCtx) -> Dictionary:
	var ns := ctx.state.ns(Ids.NS)
	if not ns.has("_v"):
		ns["_v"] = Ids.STATE_V
	if typeof(ns.get("held")) != TYPE_ARRAY:
		ns["held"] = []
	if typeof(ns.get("gone")) != TYPE_ARRAY:
		ns["gone"] = []
	return ns
