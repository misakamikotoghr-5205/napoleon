# Rogue v1 old ledger, read-only queries: legacy.harvest (what this ledger has seen, plus the chronicle line when
# the shell closes it) and legacy.old_ink (fragments earlier ledgers saw that this one has not). Owner RG5.
# No class_name; preload it. docs/cards/rogue/ROGUE_V1.md §4.3, §5.6. Nothing here writes state: every read goes
# through state.data.get / CardDossier.view, so the state hash is the same before and after.
extends RefCounted

const Ids = preload("res://scripts/cards/legacy/legacy_ids.gd")
const Run = preload("res://scripts/cards/legacy/legacy_run.gd")


## legacy.harvest {close?: String}
static func harvest(ctx: CardCtx, args: Dictionary) -> Dictionary:
	if args.has("close") and typeof(args["close"]) != TYPE_STRING and typeof(args["close"]) != TYPE_STRING_NAME:
		return {"ok": false, "err": CardIds.ERR_BAD_ARGS}
	var loop: Dictionary = ctx.state.data.get("loop", {})
	var stage := int(loop.get("stage", 0))
	var stage_day := int(loop.get("stage_day", 0))
	var out := {"ok": true, "err": "", "no": int(Run.run_of(ctx).get("no", 0)),
		"phase": str(loop.get("phase", CardIds.PH_BOOT)), "reason": str(loop.get("reason", "")),
		"stage": stage, "era": _era(ctx, stage), "stage_day": stage_day, "frags": have_ids(ctx)}
	if args.has("close"):
		out["chronicle"] = chronicle(ctx, str(args["close"]), str(out["era"]), stage_day)
	return out


## The fragments this ledger holds (state "have" in CardDossier.view), sorted.
static func have_ids(ctx: CardCtx) -> Array:
	var out: Array = []
	for page in CardDossier.view(ctx).get("pages", []):
		for frag in page.get("fragments", []):
			if str(frag.get("state", "")) == "have":
				out.append(str(frag.get("id", "")))
	out.sort()
	return out


## {key, args}: §5.6. The conscience value only picks the key; it never leaves the engine. The day shown is at
## least 1 (a ledger closed at the month opening, stage day 0, reads as its first day).
static func chronicle(ctx: CardCtx, close: String, era: String, stage_day: int) -> Dictionary:
	var d := maxi(1, stage_day)
	if close == Ids.CLOSE_ENDING:
		var cfg: Dictionary = ctx.rules(Ids.RULES).get("chronicle", {})
		var conscience := CardMeters.value(ctx, &"conscience")
		var key := Ids.KEY_ENDING_PLAIN
		if conscience >= int(cfg.get("kind_at", Ids.KIND_AT)):
			key = Ids.KEY_ENDING_KIND
		elif conscience <= int(cfg.get("hard_at", Ids.HARD_AT)):
			key = Ids.KEY_ENDING_HARD
		return {"key": key, "args": {}}
	if (close == Ids.CLOSE_PRISON or close == Ids.CLOSE_ABANDONED) and Ids.CHRONICLE_ERAS.has(era):
		return {"key": Ids.KEY_PREFIX + close + "." + era, "args": {"d": d}}
	return {"key": Ids.KEY_OTHER, "args": {"d": d}}


## legacy.old_ink {}: run.known minus what this ledger holds or has torn out, one page per person.
static func old_ink(ctx: CardCtx, _args: Dictionary) -> Dictionary:
	var known: Array = Run.run_of(ctx).get("known", [])
	if known.is_empty():
		return {"ok": true, "err": "", "pages": []}
	var seen := _seen(ctx)
	var by_person: Dictionary = {}
	for id in known:
		var fid := str(id)
		var d: Dictionary = ctx.db._cards.get(fid, {})
		if str(d.get("type", "")) != "dossier_fragment" or seen.has(fid):
			continue
		var person := str(d.get("person", ""))
		if not by_person.has(person):
			by_person[person] = []
		(by_person[person] as Array).append({"id": fid, "order": int(d.get("order", 0))})
	var persons: Array = by_person.keys()
	persons.sort()
	var pages: Array = []
	for person in persons:
		var frags: Array = by_person[person]
		frags.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			if int(a["order"]) != int(b["order"]):
				return int(a["order"]) < int(b["order"])
			return str(a["id"]) < str(b["id"]))
		pages.append({"person": str(person), "fragments": frags})
	return {"ok": true, "err": "", "pages": pages}


## Ids this ledger already has or has torn out (gap) — neither is drawn as old ink.
static func _seen(ctx: CardCtx) -> Dictionary:
	var seen: Dictionary = {}
	for page in CardDossier.view(ctx).get("pages", []):
		for frag in page.get("fragments", []):
			seen[str(frag.get("id", ""))] = true
	return seen


static func _era(ctx: CardCtx, stage: int) -> String:
	return str(ctx.db.stage(stage).get("era", "")) if ctx.db != null else ""
