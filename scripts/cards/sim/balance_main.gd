# 多种子、九策略真实门面自动玩；输出逐局开发报告，可重算例子集黄金种子。
# G06；合同 §12.5–§12.6。日期只来自命令行，引擎不读取墙钟。
extends SceneTree

const Telemetry := preload("res://scripts/cards/sim/telemetry.gd")
const FuzzRunner := preload("res://scripts/cards/sim/fuzz_runner.gd")
const CachedAPI := preload("res://scripts/cards/sim/cached_api.gd")
const POLICIES: Dictionary = {
	"fair": preload("res://scripts/cards/sim/policies/fair.gd"),
	"greedy": preload("res://scripts/cards/sim/policies/greedy.gd"),
	"kind": preload("res://scripts/cards/sim/policies/kind.gd"),
	"random": preload("res://scripts/cards/sim/policies/random.gd"),
	"refuser": preload("res://scripts/cards/sim/policies/refuser.gd"),
	"wheel": preload("res://scripts/cards/sim/policies/wheel.gd"),
	"hoarder": preload("res://scripts/cards/sim/policies/hoarder.gd"),
	# Rogue v1 (ROGUE_V1.md §14 RG6): fair counter without mortgages; refuser that still takes free stocktake picks.
	"trader": preload("res://scripts/cards/sim/policies/trader.gd"),
	"idle": preload("res://scripts/cards/sim/policies/idle.gd")}


func _initialize() -> void:
	var opts: Dictionary = _arguments()
	if not str(opts.get("data", "examples")) in ["examples", "real"]:
		push_error("--data must be examples or real")
		quit(1)
		return
	var examples: bool = str(opts.get("data", "examples")) == "examples"
	var db: CardDB = CardDB.load_all(str(opts.get("data-root", "res://data/cards")), {"only_examples": examples})
	if not db.errors().is_empty():
		push_error("Invalid balance database: " + str(db.errors()))
		quit(1)
		return
	var runs: Array = []
	var golden: Array = []
	var seed_from: int = int(opts.get("seed_from", 1))
	var count: int = int(opts.get("fuzz", opts.get("seeds", 200)))
	var seed_to: int = int(opts.get("seed_to", seed_from + count - 1))
	for seed_value in range(seed_from, seed_to + 1):
		for name in ("fuzz" if opts.has("fuzz") else str(opts.get("policies", "fair,greedy,kind"))).split(","):
			if name != "fuzz" and not POLICIES.has(name):
				push_error("Unknown policy: " + name)
				quit(1)
				return
			var run: Dictionary = _play(seed_value, name, examples, db, opts)
			runs.append(run)
			print("BALANCE PROGRESS seed=%s policy=%s ok=%s reason=%s steps=%s error=%s" % [seed_value, name,
				run["result"].get("ok", false), run["result"].get("game_over_reason", ""),
				run["result"].get("steps", 0), run["result"].get("last_error", "")])
			if opts.has("update-golden"):
				var expected: Array = []
				for day in [10, 20, 30]:
					if day <= int(opts.get("days", 30)):
						expected.append(day)
				var actual: Array = run["hashes"].map(func(row: Dictionary) -> int: return int(row["abs_day"]))
				if not bool(run["result"].get("ok", false)) or actual != expected:
					push_error("Golden run did not reach every required checkpoint: " + JSON.stringify(run["result"]))
					quit(1)
					return
				golden.append({"seed": seed_value, "policy": name, "data": opts.get("data", "examples"),
					"days": int(opts.get("days", 30)), "hashes": run["hashes"]})
	var output: String = str(opts.get("out", "user://balance"))
	DirAccess.make_dir_recursive_absolute(output)
	_write(output + "/runs_%s_%s.json" % [seed_from, seed_to], {"schema": 1,
		"date": str(opts.get("date", "undated")), "data": opts.get("data", "examples"),
		"dataset_label": str(opts.get("label", opts.get("data", "examples"))), "db_hash": db.hash(),
		"engine": "CardEngine", "godot": Engine.get_version_info().get("string", ""),
		"balance_overrides": CardDB.read_json(db.root + "/rules/balance_overrides.json"),
		"source_revision": str(opts.get("source-rev", "not_recorded")), "runs": runs})
	if opts.has("update-golden"):
		_write(str(opts.get("golden-out", "res://scripts/tests/cards/golden/golden.json")), {"cases": golden})
	print("BALANCE RUNS %d" % runs.size())
	var failed: int = runs.filter(func(run: Dictionary) -> bool: return not run["result"].get("ok", false)).size()
	print("BALANCE RESULT passed=%d failed=%d" % [runs.size() - failed, failed])
	quit(1 if failed > 0 else 0)


func _play(seed_value: int, name: String, examples: bool, db: CardDB, opts: Dictionary) -> Dictionary:
	var bus: CardEventBus = CardEventBus.new()
	var engine: CardEngineApi = CachedAPI.new(CardEngine.new(bus))
	var observer: RefCounted = Telemetry.new()
	if name != "fuzz":
		observer.attach(engine, db)
	var game_opts: Dictionary = {"seed": seed_value, "only_examples": examples,
		"data_root": str(opts.get("data-root", "res://data/cards")), "save_dir": "user://balance/%s/%s" % [name, seed_value]}
	var start: Dictionary = engine.new_game(game_opts)
	var result: Dictionary = {"ok": false, "game_over_reason": str(start.get("err", "new_game_failed"))}
	if bool(start.get("ok", false)):
		var until: Dictionary = {"stages": int(opts.get("stages", 3)), "days": int(opts.get("days", 0)),
			"max_steps": int(opts.get("max_steps", 30000 if name == "fuzz" else 20000)),
			"save_path": "user://balance/fuzz/%s/probe.json" % seed_value, "game_opts": game_opts}
		result = FuzzRunner.play(engine, seed_value, until) if name == "fuzz" \
			else CardAutoplay.play(engine, POLICIES[name].new(seed_value), until)
	var run: Dictionary = {"seed": seed_value, "policy": name, "result": result,
		"stages": observer.stages.duplicate(true), "hashes": observer.hashes.duplicate(true),
		"stages_requested": int(opts.get("stages", 3))}
	bus.free()
	return run


func _arguments() -> Dictionary:
	var args: Dictionary = {}
	for arg in OS.get_cmdline_user_args():
		if not str(arg).begins_with("--"):
			continue
		var parts: PackedStringArray = str(arg).trim_prefix("--").split("=", true, 1)
		args[parts[0]] = parts[1] if parts.size() == 2 else true
	return args


func _write(path: String, value: Dictionary) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Cannot write: " + path)
		return
	file.store_string(JSON.stringify(value, "\t", true, true) + "\n")
