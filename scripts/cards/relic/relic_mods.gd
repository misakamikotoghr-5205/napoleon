# Rogue v1 relics: the seven standing modifier providers (price_pct patience_pct appraise_pct cap pool_pct deal_count
# coins) and the data check for relic definitions. Owner RG1 (docs/cards/rogue/ROGUE_V1.md §4.5, §5.4). No class_name.
# Per kind: every matching row of every held relic, in holding order, is multiplied (pct kinds, floor at each step)
# or added (delta kinds); the result is clamped by rules/relics.json "clamp" and only then handed to CardMods.
# No held relic, a dormant shelf or no matching row = the neutral value (100 or 0) on the first lines.
extends RefCounted

const Ids = preload("res://scripts/cards/relic/relic_ids.gd")
const Api = preload("res://scripts/cards/relic/relic_api.gd")
const _NO_LIMIT := 1 << 30


static func install(ctx: CardCtx) -> void:
	for kind in Ids.PCT_KINDS:
		ctx.mods.register(kind, _provide.bind(kind), Ids.OWNER)
	for kind in Ids.SUM_KINDS:
		ctx.mods.register(kind, _provide.bind(kind), Ids.OWNER)


static func _provide(ctx: CardCtx, args: Dictionary, kind: StringName) -> int:
	var defs := Api.working_defs(ctx)
	if defs.is_empty():
		return _neutral(kind)
	return combine(ctx, kind, args, defs)


## The clamped combination of the matching rows of these relic definitions (in order) for one modifier question.
static func combine(ctx: CardCtx, kind: StringName, args: Dictionary, defs: Array) -> int:
	var pct_kind := Ids.PCT_KINDS.has(kind)
	var total := _neutral(kind)
	var matched := false
	var slot_tags = null
	for d in defs:
		var rows = d.get("mods", [])
		if typeof(rows) != TYPE_ARRAY:
			continue
		for row in rows:
			if typeof(row) != TYPE_DICTIONARY or not _matches(ctx, kind, row, args):
				continue
			if row.has("when") and not ctx.test(row["when"]):
				continue
			if not _empty_list(row.get("slot_tags_any")):
				if slot_tags == null:
					slot_tags = _slot_tags(ctx, args)
				if not _intersects(row["slot_tags_any"], slot_tags):
					continue
			matched = true
			if pct_kind:
				total = total * int(row.get("pct", 100)) / 100
			else:
				total += int(row.get("delta", 0))
	if not matched:
		return _neutral(kind)
	var key := clamp_key(kind, args)
	return clampi(total, limit(ctx, key + "_min", -_NO_LIMIT), limit(ctx, key + "_max", _NO_LIMIT))


## rules/relics.json clamp key prefix for one question: price_pay / price_receive / patience / appraise / pool /
## shelf_cap / kept_cap / deal_count / coins.
static func clamp_key(kind: StringName, args: Dictionary) -> String:
	match kind:
		&"price_pct":
			return "price_" + str(args.get("direction", ""))
		&"patience_pct":
			return "patience"
		&"appraise_pct":
			return "appraise"
		&"pool_pct":
			return "pool"
		&"cap":
			return str(args.get("zone", "")) + "_cap"
	return str(kind)


static func limit(ctx: CardCtx, key: String, fallback: int) -> int:
	var bounds = ctx.rules(Ids.RULES).get("clamp", {})
	if typeof(bounds) == TYPE_DICTIONARY and bounds.has(key):
		return int(bounds[key])
	return int(Ids.CLAMP_DEFAULTS.get(key, fallback))


static func _neutral(kind: StringName) -> int:
	return 100 if Ids.PCT_KINDS.has(kind) else 0


## Does this mods row answer this question (before its "when")? §5.4 matching table.
static func _matches(ctx: CardCtx, kind: StringName, row: Dictionary, args: Dictionary) -> bool:
	var mod := str(row.get("mod", ""))
	match kind:
		&"price_pct":
			return mod == "price_pct" and str(row.get("direction", "")) == str(args.get("direction", "")) \
				and _listed(row.get("cats"), str(args.get("cat", "")))
		&"patience_pct":
			return mod == "patience_pct"
		&"appraise_pct":
			return mod == "appraise_pct" and _listed(row.get("cats"), str(args.get("cat", "")))
		&"cap":
			var zone := str(args.get("zone", ""))
			return (mod == "shelf_cap" and zone == "shelf") or (mod == "kept_cap" and zone == "kept")
		&"deal_count":
			return mod == "deal_count" and str(row.get("type", "")) == str(args.get("type", ""))
		&"pool_pct":
			return mod == "pool_weight" and str(row.get("pool", "")) == str(args.get("pool", "")) \
				and _card_fits(ctx, row, str(args.get("def", "")))
		&"coins":
			var source = args.get("source", {})
			var source_kind := str(source.get("kind", "")) if typeof(source) == TYPE_DICTIONARY else ""
			return mod == "coins" and source_kind != "" and str(row.get("source_kind", "")) == source_kind
	return false


## pool_weight: tags_any absent (or empty) or meeting the card's tags; intents absent (or empty) or holding its intent.
## Reads the definition in place (no copy): pool_pct is asked for every candidate of every draw.
static func _card_fits(ctx: CardCtx, row: Dictionary, def_id: String) -> bool:
	var tags_any = row.get("tags_any")
	var intents = row.get("intents")
	if _empty_list(tags_any) and _empty_list(intents):
		return true
	var d: Dictionary = ctx.db._cards.get(def_id, {})
	if not _empty_list(tags_any) and not _intersects(tags_any, d.get("tags", [])):
		return false
	return _listed(intents, str(d.get("intent", "")))


## The tags of the slot the coins question is about (CardSlots.slots_of the card, found by slot_id).
static func _slot_tags(ctx: CardCtx, args: Dictionary) -> Array:
	var slot_id := str(args.get("slot_id", ""))
	for slot in CardSlots.slots_of(ctx, str(args.get("uid", ""))):
		if typeof(slot) == TYPE_DICTIONARY and str(slot.get("id", "")) == slot_id:
			var tags = slot.get("tags", [])
			return tags if typeof(tags) == TYPE_ARRAY else []
	return []


## An absent or empty list puts no restriction; otherwise the value must be in it.
static func _listed(list, value: String) -> bool:
	return _empty_list(list) or (list as Array).has(value)


static func _empty_list(list) -> bool:
	return typeof(list) != TYPE_ARRAY or (list as Array).is_empty()


static func _intersects(a, b) -> bool:
	if typeof(a) != TYPE_ARRAY or typeof(b) != TYPE_ARRAY:
		return false
	for x in a:
		if (b as Array).has(x):
			return true
	return false


# ---------------- data check (RG1_data; RG3 / RG6 may call it too) ----------------
## Problems of one relic definition against ROGUE_V1.md §5.4 / §6.2; [] = fine.
static func check_def(d: Dictionary) -> PackedStringArray:
	var out := PackedStringArray()
	var id := str(d.get("id", ""))
	if str(d.get("type", "")) != "relic" or not id.begins_with("rl."):
		out.append("%s: type must be relic and the id must start with rl." % id)
	if not Ids.DEPTHS.has(str(d.get("depth", ""))):
		out.append("%s: depth must be one of %s" % [id, ", ".join(PackedStringArray(Ids.DEPTHS))])
	if not str(d.get("art", "")).begins_with("prop.relic."):
		out.append("%s: art must start with prop.relic." % id)
	if d.has("conditions") and CardDslShapes.check_cond(d["conditions"]) != "":
		out.append("%s: conditions: %s" % [id, CardDslShapes.check_cond(d["conditions"])])
	var rows = d.get("mods", [])
	if typeof(rows) != TYPE_ARRAY:
		out.append("%s: mods must be an array" % id)
		rows = []
	for i in range(rows.size()):
		var e := check_row(rows[i])
		if e != "":
			out.append("%s: mods[%d]: %s" % [id, i, e])
	for field in Ids.PASSIVE_FIELDS:
		for e in _check_passives(d.get(field, []), field):
			out.append("%s: %s" % [id, e])
	return out


## One mods row: a known mod, every parameter present and well typed, nothing extra, a cheap "when".
static func check_row(row) -> String:
	if typeof(row) != TYPE_DICTIONARY:
		return "row must be an object"
	var mod := str(row.get("mod", ""))
	if not Ids.MOD_ROWS.has(mod):
		return "unknown mod '%s'" % mod
	var spec: Dictionary = Ids.MOD_ROWS[mod]
	var keys: Array = row.keys()
	keys.sort()
	for k in keys:
		var key := str(k)
		if not key.begins_with("_") and not Ids.ROW_COMMON.has(key) and not spec.has(key):
			return "%s: unknown key '%s'" % [mod, key]
	var params: Array = spec.keys()
	params.sort()
	for p in params:
		var e := _check_param(str(spec[p]), row.has(p), row.get(p))
		if e != "":
			return "%s.%s: %s" % [mod, p, e]
	if row.has("flaw") and typeof(row["flaw"]) != TYPE_BOOL:
		return "%s.flaw: must be a bool" % mod
	if row.has("when"):
		var ce := CardDslShapes.check_cond(row["when"])
		if ce != "":
			return "%s.when: %s" % [mod, ce]
		for op in CardDslShapes.cond_ops_used(row["when"]):
			if not Ids.WHEN_OPS.has(op):
				return "%s.when: op '%s' is not allowed here" % [mod, op]
	return ""


static func _check_param(spec: String, present: bool, value) -> String:
	var optional := spec.ends_with("?")
	var s := spec.trim_suffix("?")
	if not present:
		return "" if optional else "missing"
	if s == "pct":
		if typeof(value) != TYPE_INT or int(value) < Ids.PCT_MIN or int(value) > Ids.PCT_MAX:
			return "must be an integer %d-%d" % [Ids.PCT_MIN, Ids.PCT_MAX]
	elif s == "int":
		if typeof(value) != TYPE_INT:
			return "must be an integer"
	elif s == "str":
		if typeof(value) != TYPE_STRING or str(value) == "":
			return "must be a non-empty string"
	elif s == "strs":
		if typeof(value) != TYPE_ARRAY or (value as Array).is_empty():
			return "must be a non-empty array of strings"
		for x in value:
			if typeof(x) != TYPE_STRING or str(x) == "":
				return "must be a non-empty array of strings"
	elif s.begins_with("e:"):
		if typeof(value) != TYPE_STRING or not s.substr(2).split(",").has(str(value)):
			return "must be one of %s" % s.substr(2)
	return ""


static func _check_passives(rows, field: String) -> PackedStringArray:
	var out := PackedStringArray()
	if typeof(rows) != TYPE_ARRAY:
		out.append("%s must be an array" % field)
		return out
	for i in range(rows.size()):
		var row = rows[i]
		if typeof(row) != TYPE_DICTIONARY:
			out.append("%s[%d] must be an object" % [field, i])
			continue
		var keys: Array = row.keys()
		keys.sort()
		for k in keys:
			if not str(k) in ["hook", "effects"] and not str(k).begins_with("_"):
				out.append("%s[%d]: unknown key '%s'" % [field, i, k])
		if not Ids.PASSIVE_HOOKS.has(str(row.get("hook", ""))):
			out.append("%s[%d].hook must be day_start or settle" % [field, i])
		for e in CardDslShapes.check_effects(row.get("effects", [])):
			out.append("%s[%d].effects%s" % [field, i, e])
	return out
