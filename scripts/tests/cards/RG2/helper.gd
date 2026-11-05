# RG2 test helpers: a private copy of the data with the rogue v1 fixtures written in (ROGUE_V1.md §14 RG2
# "test data": sources §6.5, relics §6.4, the peddler §6.6, rules/stock.json and rules/relics.json §6.3). After RG3
# lands the same paths hold the real files; the copies overwrite them so these tests keep their own numbers.
# Owner RG2. No class_name.
extends RefCounted

const G01 = preload("res://scripts/tests/cards/G01/helper.gd")
const FIX := "res://scripts/tests/cards/RG2/fixtures/"
## fixture file -> path under the data root
const FILES := {
	"sources.json": "era/common/sources.json",
	"relics.json": "era/common/relics.json",
	"curio_peddler.json": "era/1938/curio_peddler.json",
	"rules_stock.json": "rules/stock.json",
	"rules_relics.json": "rules/relics.json",
}
const PEDDLER := "p.stranger_peddler.1938.curios"


## Copies res://data/cards to <user_dir>/<tag>, then writes the fixtures. stock_over is merged into rules/stock.json;
## files listed in skip are left out (and removed from the copy).
static func data_root(t, tag: String = "cards", stock_over: Dictionary = {}, skip: Array = []) -> String:
	var root: String = t.user_dir() + "/" + tag
	G01.copy_tree("res://data/cards", root)
	var names: Array = FILES.keys()
	names.sort()
	for name in names:
		var dst: String = root + "/" + str(FILES[name])
		if skip.has(name):
			if FileAccess.file_exists(dst):
				DirAccess.remove_absolute(dst)
			continue
		var data = JSON.parse_string(FileAccess.get_file_as_string(FIX + str(name)))
		if name == "rules_stock.json":
			(data as Dictionary).merge(stock_over, true)
		G01.write(dst, data)
	return root


## Copies only the examples set's data root with the two rules files (no relic / source cards there).
static func examples_root(t, tag: String = "examples") -> String:
	return data_root(t, tag, {}, ["sources.json", "relics.json", "curio_peddler.json"])


static func engine(t, root: String, seed_value: int = 7, tag: String = "save", bus: CardEventBus = null,
		extra: Dictionary = {}) -> CardEngine:
	var e := CardEngine.new(bus)
	var opts := {"seed": seed_value, "data_root": root, "save_dir": t.user_dir() + "/" + tag}
	opts.merge(extra, true)
	var r: Dictionary = e.new_game(opts)
	t.ok(bool(r.get("ok", false)), "new_game %s: %s" % [tag, str(r.get("err", ""))])
	return e


static func phase(e: CardEngine) -> String:
	return str(e.ctx.state.ns("loop").get("phase", ""))


static func stage_day(e: CardEngine) -> int:
	return int(e.ctx.state.ns("loop").get("stage_day", 0))


## day.end {confirm: true} until stage_day == day and the phase is the wanted one; false on game over / guard.
static func walk_to(e: CardEngine, day: int, want_phase: String, guard: int = 400) -> bool:
	for _i in range(guard):
		if stage_day(e) == day and phase(e) == want_phase:
			return true
		if phase(e) == "game_over":
			return false
		var r: Dictionary = e.send(&"day.end", {"confirm": true})
		if not bool(r.get("ok", false)):
			push_error("RG2 walk_to: day.end failed at day %d phase %s: %s" % [stage_day(e), phase(e), r.get("err", "")])
			return false
	return false


## One deal of the week, the way the counter reports it (card_piles.gd resolve -> card_resolved).
static func trade(e: CardEngine) -> void:
	e.ctx.hooks.fire(e.ctx, &"card_resolved", {"uid": "", "outcome": &"resolved", "almanac": ["pawn_in", "trade"]})


static func stock(e: CardEngine) -> Dictionary:
	var st = e.ctx.state.data.get("stock", {})
	return st if typeof(st) == TYPE_DICTIONARY else {}


static func stock_of(ctx: CardCtx) -> Dictionary:
	var st = ctx.state.data.get("stock", {})
	return st if typeof(st) == TYPE_DICTIONARY else {}


static func offer(e: CardEngine, id: String) -> Dictionary:
	return stock(e).get("offers", {}).get(id, {})


static func hand_defs(e: CardEngine) -> PackedStringArray:
	return G01.defs(e.ctx, CardPiles.list(e.ctx, CardIds.ZONE_HAND))


static func hand_uid(e: CardEngine, def_id: String) -> String:
	for uid in CardPiles.list(e.ctx, CardIds.ZONE_HAND):
		if str(CardPiles.card(e.ctx, uid).get("def", "")) == def_id:
			return str(uid)
	return ""


## Every event on the bus so far, checked for hidden keys.
static func events_clean(t, spy, label: String) -> void:
	for row in spy.log:
		t.no_leaks(Array(row).slice(1), "%s event %s" % [label, str(row[0])])
