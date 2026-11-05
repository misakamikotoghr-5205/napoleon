# 真引擎连续运行、逐条日志重放与存档后的后续指令一致。
# G06；合同 §12.5，黄金与存档不读取 ctx。
extends SceneTree
const T := preload("res://scripts/tests/cards/lib/card_t.gd")
const Fair := preload("res://scripts/cards/sim/policies/fair.gd")


func _initialize() -> void:
	var t: RefCounted = T.new(self, "G06_replay")
	var opts: Dictionary = {"seed": 7, "only_examples": true, "save_dir": t.user_dir()}
	var engine: CardEngine = CardEngine.new()
	t.ok(engine.new_game(opts).get("ok", false), "new game")
	var path: String = t.user_dir() + "/snapshot.json"
	t.ok(engine.save_game(path).get("ok", false), "save month open")
	var result: Dictionary = CardAutoplay.play(engine, Fair.new(7), {"days": 10, "max_steps": 4000})
	t.ok(result.get("ok", false), "fair ten days")
	var log: Array = CardReplay.record(engine)
	t.ok(not str(result.get("hash", "")).is_empty(), "state hash public diagnostic")
	t.eq(CardReplay.replay(opts, log), result["hash"], "full replay hash")
	var restored: CardEngine = CardEngine.new()
	restored.new_game(opts)
	t.ok(restored.load_game(path).get("ok", false), "load month open")
	for entry in log:
		if str(entry[0]) != "game.new":
			restored.send(StringName(str(entry[0])), entry[1])
	t.eq(_continuation_hash(restored), _continuation_hash(engine), "save continuation excluding system resume marker")
	t.finish()


func _continuation_hash(engine: CardEngine) -> String:
	# 仅测试归一化 G02 明确允许的系统首次读档/重来标记，不改变真实哈希或状态。
	var copy: Dictionary = engine.ctx.state.to_dict()
	for mechanism in ["resume", "retry"]:
		(copy.get("core", {}).get("firsts", {}) as Dictionary).erase(mechanism)
	return CardState.from_dict(copy).hash()
