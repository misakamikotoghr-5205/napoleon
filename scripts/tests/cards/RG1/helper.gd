# RG1 test support: a private data root (res://data/cards copied under the test's user dir, then the RG1 fixtures
# written over era/common/relics.json = ROGUE_V1.md §6.4 and rules/relics.json = §6.3, so RG3's later data or RG6's
# tuning never changes what these tests see), engines on it, and a driver that presses "close shop" until a day.
# Owner RG1.
extends RefCounted

const G01 = preload("res://scripts/tests/cards/G01/helper.gd")
const FIX := "res://scripts/tests/cards/RG1/fixtures/"


## Builds <user dir>/<name> once; rules_patch is merged over the §6.3 rules (e.g. {"enabled": false}).
static func data_root(t, rules_patch: Dictionary = {}, name: String = "cards") -> String:
	var root: String = t.user_dir() + "/" + name
	if FileAccess.file_exists(root + "/rules/relics.json"):
		return root
	G01.copy_tree("res://data/cards", root)
	G01.write(root + "/era/common/relics.json", CardDB.read_json(FIX + "relics.json"))
	var rules: Dictionary = CardDB.read_json(FIX + "rules_relics.json")
	rules.merge(rules_patch, true)
	G01.write(root + "/rules/relics.json", rules)
	return root


static func engine(t, root: String, seed_value: int = 7, save: String = "save", bus: CardEventBus = null) -> CardEngine:
	var e := CardEngine.new(bus)
	var r := e.new_game({"seed": seed_value, "data_root": root, "save_dir": t.user_dir() + "/" + save})
	t.ok(bool(r.get("ok", false)), "new_game on %s: %s" % [root, r])
	return e


## Presses day.end {confirm: true} until the view shows this stage day in this phase. false if it never gets there.
static func advance(e: CardEngine, stage_day: int, phase: String = "morning", max_steps: int = 400) -> bool:
	for i in range(max_steps):
		var v := e.view()
		if int(v.get("date", {}).get("stage_day", 0)) == stage_day and str(v.get("phase", "")) == phase:
			return true
		if str(v.get("phase", "")) == "game_over":
			return false
		var r := e.send(&"day.end", {"confirm": true})
		if not bool(r.get("ok", false)) and str(e.view().get("phase", "")) != "game_over":
			return false
	return false


static func meter(e: CardEngine, name: StringName) -> int:
	return CardMeters.value(e.ctx, name)


## The weekly demand G03 issued for "<stage>:<week>": {} when none.
static func issued(e: CardEngine, week_key: String) -> Dictionary:
	var demand: Dictionary = e.ctx.state.data.get("rules", {}).get("demand", {})
	var uid := str(demand.get("weeks", {}).get(week_key, ""))
	return (demand.get("issued", {}).get(uid, {}) as Dictionary).duplicate(true) if uid != "" else {}


## Rewrites state.relic as "never written" (tests only; the game never removes it).
static func clear_relics(e: CardEngine) -> void:
	e.ctx.state.data.erase("relic")
