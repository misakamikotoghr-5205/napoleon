# 七策略通过真引擎三关或正常局终，不能因为指令重试而卡死。
# G06；合同 §12.6。指令日志不允许 ui.*，失败指令也必须可回放。
extends SceneTree
const T := preload("res://scripts/tests/cards/lib/card_t.gd")
const Scenario := preload("res://scripts/tests/cards/G06/scenario.gd")
const Runner := preload("res://scripts/cards/sim/balance_main.gd")


func _initialize() -> void:
	var t: RefCounted = T.new(self, "G06_policies_no_stall")
	var data_root: String = Scenario.build(t.user_dir() + "/data")
	var engine: CardEngineApi = Runner.CachedAPI.new(CardEngine.new())
	for seed_value in range(1, 4):
		for name in Runner.POLICIES.keys():
			var start: Dictionary = engine.new_game({"seed": seed_value, "only_examples": true,
				"data_root": data_root, "save_dir": t.user_dir() + "/%s/%s" % [name, seed_value]})
			t.ok(bool(start.get("ok", false)), "new game " + str(name))
			var result: Dictionary = CardAutoplay.play(engine, Runner.POLICIES[name].new(seed_value),
				{"stages": 3, "max_steps": 12000})
			t.ok(bool(result.get("ok", false)), "%s seed %s: %s" % [name, seed_value, result])
			t.ok(int(result.get("days", 0)) > 0, "days progressed " + str(name))
			for entry in CardReplay.record(engine):
				t.ok(not str(entry[0]).begins_with("ui."), "no guide commands")
	t.finish()
