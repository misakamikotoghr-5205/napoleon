# 无头自动玩循环；只通过 send/view/query 与引擎交互。
# G06；合同 1.2 §7.4.7、§7.9、§12.4。策略卡住就打烊，打烊失败判引擎失败。
class_name CardAutoplay
extends RefCounted


static func play(engine: CardEngineApi, policy: CardPolicy, until: Dictionary) -> Dictionary:
	var steps: int = 0
	var stagnant: int = 0
	var previous: int = 0
	var has_previous: bool = false
	var reason: String = ""
	var stages_cleared: int = 0
	var failed_action: String = ""
	var repeated_failures: int = 0
	var last_error: String = ""
	var recoveries: int = 0
	var initial: Dictionary = engine.view()
	var first_stage: int = int(initial.get("date", {}).get("stage", 0))
	var max_steps: int = int(until.get("max_steps", 20000))
	while steps < max_steps:
		var view: Dictionary = engine.view()
		var phase: String = str(view.get("phase", ""))
		var day: int = int(view.get("date", {}).get("abs_day", 0))
		var stage: int = int(view.get("date", {}).get("stage", 0))
		stages_cleared = maxi(stages_cleared, stage - first_stage)
		if phase == "year_jump":
			stages_cleared = maxi(stages_cleared, stage - first_stage + 1)
		if phase in ["game_over", "branch_pick"]:
			reason = str(view.get("game_over_reason", view.get("reason", phase)))
			if reason == "ending":
				stages_cleared = maxi(stages_cleared, stage - first_stage + 1)
			break
		if int(until.get("days", 0)) > 0 and day >= int(until["days"]) and phase in ["morning", "month_close"]:
			break
		if int(until.get("stages", 0)) > 0 and stages_cleared >= int(until["stages"]):
			break
		var snapshot: int = view.hash()
		stagnant = stagnant + 1 if (has_previous and snapshot == previous) else 0
		previous = snapshot
		has_previous = true
		var recover: bool = stagnant >= 40 or repeated_failures >= 3
		var action: Array = [] if recover else policy.decide(engine, view)
		if action.is_empty():
			action = [&"day.end", {"confirm": true}]
			recover = true
		if action.size() != 2 or str(action[0]).begins_with("ui."):
			reason = "invalid_policy_action"
			break
		var result: Dictionary = engine.send(StringName(str(action[0])), action[1])
		steps += 1
		if str(action[0]) == "day.end" and bool(action[1].get("confirm", false)) and not bool(result.get("ok", false)):
			if str(engine.view().get("phase", "")) != "game_over":
				last_error = str(result.get("err", ""))
				reason = "day_end_failed"
				break
		if recover:
			recoveries += 1
			stagnant = 0
			has_previous = false
			repeated_failures = 0
			failed_action = ""
		var action_key: String = "%s:%d" % [str(action[0]), (action[1] as Dictionary).hash()]
		if not bool(result.get("ok", false)):
			repeated_failures = repeated_failures + 1 if action_key == failed_action else 1
			failed_action = action_key
			last_error = str(result.get("err", ""))
		else:
			repeated_failures = 0
			failed_action = ""
	if steps >= max_steps:
		reason = "max_steps"
	var final_view: Dictionary = engine.view()
	return {"ok": not reason in ["invalid_policy_action", "max_steps", "day_end_failed"],
		"stages_cleared": stages_cleared, "days": int(final_view.get("date", {}).get("abs_day", 0)),
		"game_over_reason": reason, "steps": steps, "hash": _hash(engine), "last_error": last_error,
		"day_end_recoveries": recoveries}


static func _hash(engine: CardEngineApi) -> String:
	# 只返回不透明哈希的只读诊断例外，合同缺口见 issue #41。
	return str(engine.call("state_hash")) if engine.has_method("state_hash") else ""
