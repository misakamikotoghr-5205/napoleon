# RG6_sim_zero: the two new policies on the real engine with the example set (no rogue data, so no stocktake ever
# opens): idle plays exactly like refuser (same commands, same hashes); trader never mortgages, only ever offers the
# fair tier and never picks; fair never sends stock.pick. ROGUE_V1.md §14 RG6.
extends SceneTree
const T := preload("res://scripts/tests/cards/lib/card_t.gd")
const Runner := preload("res://scripts/cards/sim/balance_main.gd")
const Telemetry := preload("res://scripts/cards/sim/telemetry.gd")


func _initialize() -> void:
	var t: RefCounted = T.new(self, "RG6_sim_zero")
	_idle_is_refuser(t)
	for seed_value in [3, 7]:
		_trader(t, seed_value)
	var fair: Dictionary = _run(t, "fair", 7, 20)
	t.ok(not _sent(fair["log"], "stock.pick"), "fair on examples never sends stock.pick")
	t.finish()


func _run(t: RefCounted, name: String, seed_value: int, days: int) -> Dictionary:
	var bus := CardEventBus.new()
	var engine := CardEngine.new(bus)
	var tele: RefCounted = Telemetry.new()
	tele.attach(engine, CardDB.load_all("res://data/cards", {"only_examples": true}))
	var opts: Dictionary = {"seed": seed_value, "only_examples": true, "save_dir": t.user_dir() + "/run"}
	t.ok(bool(engine.new_game(opts).get("ok", false)), "new game " + name)
	var result: Dictionary = CardAutoplay.play(engine, Runner.POLICIES[name].new(seed_value),
		{"days": days, "max_steps": 12000})
	t.ok(bool(result.get("ok", false)), "%s seed %d plays %d days: %s" % [name, seed_value, days, result])
	var out: Dictionary = {"result": result, "log": engine.command_log(), "hashes": tele.hashes.duplicate(true),
		"stages": tele.stages.duplicate(true), "hash": engine.state_hash()}
	t.ok(not engine.ctx.state.data.has("stock") and not engine.ctx.state.data.has("relic"),
		name + ": no rogue namespace on the example set")
	bus.free()
	return out


func _idle_is_refuser(t: RefCounted) -> void:
	var refuser: Dictionary = _run(t, "refuser", 7, 21)
	var idle: Dictionary = _run(t, "idle", 7, 21)
	t.eq(idle["log"], refuser["log"], "idle sends exactly what refuser sends when nothing is offered")
	t.eq(idle["hashes"], refuser["hashes"], "idle checkpoint hashes = refuser")
	t.eq(idle["hash"], refuser["hash"], "idle final hash = refuser")
	t.ok(not _sent(idle["log"], "stock.pick"), "idle never picks without an offer")


func _trader(t: RefCounted, seed_value: int) -> void:
	var trader: Dictionary = _run(t, "trader", seed_value, 30)
	t.ok(not _sent(trader["log"], "estate.mortgage"), "trader seed %d never mortgages" % seed_value)
	t.ok(not _sent(trader["log"], "stock.pick"), "trader seed %d: nothing to pick on examples" % seed_value)
	var offers: int = 0
	for entry in trader["log"]:
		if str(entry[0]) == "counter.offer":
			offers += 1
			t.eq(str(entry[1].get("tier", "")), "fair", "trader offers the fair tier")
	t.ok(offers > 0, "trader seed %d works the counter (%d offers)" % [seed_value, offers])
	for stage in trader["stages"].values():
		t.eq(int(stage.get("stock", {}).get("offers", -1)), 0, "trader telemetry: no stocktake on examples")


func _sent(log: Array, cmd: String) -> bool:
	for entry in log:
		if str(entry[0]) == cmd:
			return true
	return false
