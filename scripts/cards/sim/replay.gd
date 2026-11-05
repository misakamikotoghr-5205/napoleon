# 记录与重放完整指令序列；状态哈希由只读诊断查询给出。
# G06；合同 §12.5。失败指令也按原顺序送入，game.new 只运行一次。
class_name CardReplay
extends RefCounted


static func record(engine: CardEngineApi) -> Array:
	return engine.call("command_log") if engine.has_method("command_log") else []


static func replay(opts: Dictionary, log: Array) -> String:
	var engine: CardEngineApi = CardEngine.new()
	engine.new_game(opts)
	for entry in log:
		if typeof(entry) != TYPE_ARRAY or entry.size() != 2:
			continue
		if str(entry[0]) == "game.new":
			continue
		engine.send(StringName(str(entry[0])), entry[1])
	return CardAutoplay._hash(engine)
