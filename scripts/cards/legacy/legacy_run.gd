# Rogue v1 run context: checking and writing state.run, the opening rules, the veteran condition, the
# unscripted_day provider, the opening notice and the view block. Owner RG5. No class_name; preload it.
# docs/cards/rogue/ROGUE_V1.md §3.3, §4.1, §4.4, §4.6, §5.6. Reads stay lazy: nothing here creates state.run
# except init_run with a non-empty run, so a game without one hashes exactly as before.
extends RefCounted

const Ids = preload("res://scripts/cards/legacy/legacy_ids.gd")


## game.new {run} before the state exists. "" = ok; otherwise bad_args.
static func check_run(db: CardDB, run: Dictionary) -> String:
	if run.is_empty():
		return ""
	var no = run.get("no")
	if typeof(no) != TYPE_INT or int(no) < 1:
		return CardIds.ERR_BAD_ARGS
	var opening = run.get("opening", Ids.DEFAULT_OPENING)
	if typeof(opening) != TYPE_STRING or not openings_of(db.rules(Ids.RULES)).has(str(opening)):
		return CardIds.ERR_BAD_ARGS
	var known = run.get("known", [])
	if typeof(known) != TYPE_ARRAY and typeof(known) != TYPE_PACKED_STRING_ARRAY:
		return CardIds.ERR_BAD_ARGS
	for id in known:
		if typeof(id) != TYPE_STRING and typeof(id) != TYPE_STRING_NAME:
			return CardIds.ERR_BAD_ARGS
	return ""


## Right after CardState.create (check_run already passed). Unknown fragment ids are dropped silently.
static func init_run(ctx: CardCtx, run: Dictionary) -> void:
	if run.is_empty():
		return
	var seen: Dictionary = {}
	for id in run.get("known", []):
		var fid := str(id)
		if str(ctx.db._cards.get(fid, {}).get("type", "")) == "dossier_fragment":
			seen[fid] = true
	var known: Array = seen.keys()
	known.sort()
	var ns := ctx.state.ns(Ids.NS)
	ns["_v"] = Ids.NS_VERSION
	ns["no"] = int(run["no"])
	ns["opening"] = str(run.get("opening", Ids.DEFAULT_OPENING))
	ns["known"] = known


## The openings table of rules/legacy.json, or the built-in default when the file (or the table) is missing.
static func openings_of(rules: Dictionary) -> Dictionary:
	var table = rules.get("openings")
	if typeof(table) != TYPE_DICTIONARY or (table as Dictionary).is_empty():
		return Ids.DEFAULT_OPENINGS
	return table


## Read-only view of state.run ({} without a run).
static func run_of(ctx: CardCtx) -> Dictionary:
	if ctx.state == null:
		return {}
	var run = ctx.state.data.get(Ids.NS, {})
	return run if typeof(run) == TYPE_DICTIONARY else {}


## The rules row of this run's opening ({} without a run or for an unknown id).
static func opening_rules(ctx: CardCtx) -> Dictionary:
	var run := run_of(ctx)
	if run.is_empty():
		return {}
	var row = openings_of(ctx.rules(Ids.RULES)).get(str(run.get("opening", "")), {})
	return row if typeof(row) == TYPE_DICTIONARY else {}


## rules.legacy.openings[run.opening].veteran; false without a run.
static func veteran(ctx: CardCtx) -> bool:
	return bool(opening_rules(ctx).get("veteran", false))


## Condition op veteran: value "bool".
static func cond_veteran(ctx: CardCtx, value: Variant) -> bool:
	return veteran(ctx) == bool(value)


## Modifier unscripted_day (any_true), args {stage, stage_day}: true on stage 0 for a veteran opening.
static func mod_unscripted(ctx: CardCtx, args: Dictionary) -> bool:
	if not veteran(ctx):
		return false
	return int(args.get("stage", -1)) == Ids.UNSCRIPTED_STAGE


## day_start priority 2: the opening notice on the first morning of the first stage.
static func on_day_start(ctx: CardCtx, _args: Dictionary) -> void:
	var row := opening_rules(ctx)
	if row.is_empty() or not bool(row.get("veteran", false)):
		return
	var loop: Dictionary = ctx.state.data.get("loop", {})
	if int(loop.get("stage", -1)) != Ids.NOTICE_STAGE or int(loop.get("stage_day", 0)) != Ids.NOTICE_DAY:
		return
	var key := str(row.get("notice", ""))
	if key != "":
		ctx.emit(&"notice", [key, {}])


## view_section key run: {no, opening}; nothing without state.run.
static func view_section(ctx: CardCtx, _args: Dictionary) -> Dictionary:
	var run := run_of(ctx)
	if run.is_empty():
		return {}
	return {Ids.VIEW_KEY: {"no": int(run.get("no", 0)), "opening": str(run.get("opening", ""))}}
