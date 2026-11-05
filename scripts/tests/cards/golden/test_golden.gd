# 例子集黄金种子逐日哈希、重复运行与指令回放一致。
# G06；合同 §12.5。新增或更新哈希必须在 PR 说明。
extends SceneTree
const T := preload("res://scripts/tests/cards/lib/card_t.gd")
const Runner := preload("res://scripts/cards/sim/balance_main.gd")
const Telemetry := preload("res://scripts/cards/sim/telemetry.gd")


func _initialize() -> void:
	var t: RefCounted = T.new(self, "G06_golden")
	var document: Dictionary = CardDB.read_json("res://scripts/tests/cards/golden/golden.json")
	t.ok(not document.get("cases", []).is_empty(), "golden cases present")
	for case in document.get("cases", []):
		var opts: Dictionary = {"seed": int(case["seed"]), "only_examples": case["data"] == "examples",
			"save_dir": t.user_dir()}
		var first: String = ""
		for repeat in range(2):
			var bus: CardEventBus = CardEventBus.new()
			var engine: CardEngineApi = CardEngine.new(bus)
			var observer: RefCounted = Telemetry.new()
			observer.attach(engine, CardDB.load_all("res://data/cards", {"only_examples": opts["only_examples"]}))
			engine.new_game(opts)
			var result: Dictionary = CardAutoplay.play(engine, Runner.POLICIES[case["policy"]].new(int(case["seed"])),
				{"days": int(case["days"]), "max_steps": 10000})
			t.ok(bool(result.get("ok", false)), "golden run completes without an engine stall")
			var expected: Array = []
			for day in [10, 20, 30]:
				if day <= int(case["days"]):
					expected.append(day)
			t.eq(observer.hashes.map(func(row: Dictionary) -> int: return int(row["abs_day"])), expected,
				"golden reaches every required checkpoint")
			t.eq(observer.hashes, case["hashes"], "checkpoint hashes")
			if repeat == 0:
				first = str(result["hash"])
			else:
				t.eq(result["hash"], first, "same seed repeated")
			t.eq(CardReplay.replay(opts, CardReplay.record(engine)), result["hash"], "golden command replay")
			bus.free()
	t.finish()
