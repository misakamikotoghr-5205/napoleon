# 全长随机门面验收：预览、确认打烊和八步逃生都用公开接口核验。
# G06；合同 1.2 §7.4.7；动作由 c.ai.fuzz [seed,step] 的纯可见 picker 产生。
extends RefCounted
const CachedAPI := preload("res://scripts/cards/sim/cached_api.gd")


static func play(engine: CardEngineApi, seed_value: int, until: Dictionary) -> Dictionary:
	var picker: Script = load("res://scripts/cards/sim/fuzz_actions.gd")
	var stats: Dictionary = {"steps": 0, "preview_checks": 0, "end_checks": 0, "escape_checks": 0,
		"max_escape_steps": 0, "save_loads": 0, "fresh_facades": 0, "expected_rejections": 0, "error": "", "last_actions": []}
	var first_stage: int = int(engine.view().get("date", {}).get("stage", 0))
	var cleared: int = 0
	var escape_bucket: int = 0
	var limit: int = int(until.get("max_steps", 30000))
	while int(stats["steps"]) < limit:
		var view: Dictionary = engine.view()
		var phase: String = str(view.get("phase", ""))
		var stage: int = int(view.get("date", {}).get("stage", 0))
		cleared = maxi(cleared, stage - first_stage + (1 if phase == "year_jump" else 0))
		if phase == "game_over":
			var result: Dictionary = _result(engine, stats, cleared,
				str(view.get("game_over_reason", "game_over")))
			if result["game_over_reason"] == "ending":
				result["stages_cleared"] = maxi(cleared, stage - first_stage + 1)
			var retry: Dictionary = engine.send(&"game.retry_stage", {})
			result["retry_verified"] = bool(retry.get("ok", false)) and str(engine.view().get("phase", "")) == "month_open"
			if not result["retry_verified"]:
				result["ok"] = false
				result["last_error"] = "retry_failed"
			return result
		if phase in ["boot", "branch_pick"]:
			stats["error"] = "unreachable_phase:" + phase
			break
		if int(until.get("stages", 3)) > 0 and cleared >= int(until.get("stages", 3)):
			break
		if int(until.get("days", 0)) > 0 and int(view.get("date", {}).get("abs_day", 0)) >= int(until["days"]) \
				and phase in ["morning", "month_close"]:
			break
		if not CardViewModel.leaks(view).is_empty():
			stats["error"] = "view_leak"
			break
		if int(stats["steps"]) / 25 > escape_bucket:
			escape_bucket = int(stats["steps"]) / 25
			if not _escape(engine, stats):
				break
			continue
		if phase == "morning" and JevRng.draw(seed_value, "c.ai.fuzz", [seed_value, int(stats["steps"])]) < 0.1:
			var path: String = str(until.get("save_path", "user://balance/fuzz/%s/probe.json" % seed_value))
			var saved: Dictionary = engine.send(&"game.save", {"path": path})
			stats["steps"] += 1
			var restored: CardEngineApi = CachedAPI.new(CardEngine.new())
			var opts: Dictionary = until.get("game_opts", {"seed": seed_value, "only_examples": true, "save_dir": path.get_base_dir()})
			var started: Dictionary = restored.send(&"game.new", opts) if bool(saved.get("ok", false)) else {}
			var loaded: Dictionary = restored.send(&"game.load", {"path": path}) if bool(started.get("ok", false)) else {}
			stats["steps"] += 2
			if not bool(saved.get("ok", false)) or not bool(loaded.get("ok", false)):
				stats["error"] = "save_load_failed"
				break
			engine = restored
			stats["save_loads"] += 1
			stats["fresh_facades"] += 1
			continue
		var action: Array = picker.call("select", engine, seed_value, int(stats["steps"]))
		if not _send(engine, action, stats):
			break
	if int(stats["steps"]) >= limit:
		stats["error"] = "max_steps"
	return _result(engine, stats, cleared, "")


static func _preview(engine: CardEngineApi, stats: Dictionary) -> Dictionary:
	var preview: Dictionary = engine.query(&"day.end_preview", {})
	stats["preview_checks"] += 1
	if not CardViewModel.leaks(preview).is_empty() or not preview.has("step") \
			or typeof(preview.get("items")) != TYPE_ARRAY or typeof(preview.get("needs_confirm")) != TYPE_BOOL:
		stats["error"] = "preview_shape_or_leak"
		return {}
	var needs: bool = false
	for row in preview["items"]:
		if typeof(row) != TYPE_DICTIONARY or row.keys().size() != 5:
			stats["error"] = "end_row_shape"
			return {}
		for key in ["uid", "def", "kind", "consequence_key"]:
			if typeof(row.get(key)) not in [TYPE_STRING, TYPE_STRING_NAME]:
				stats["error"] = "end_row_field:" + key
				return {}
		if not CardIds.END_KINDS.has(StringName(str(row["kind"]))) or typeof(row.get("args")) != TYPE_DICTIONARY:
			stats["error"] = "end_row_kind_or_args"
			return {}
		for key in row["args"]:
			if not str(key) in ["days", "nights", "max"] or typeof(row["args"][key]) != TYPE_INT:
				stats["error"] = "end_row_hidden_or_noninteger_args"
				return {}
		needs = needs or not CardIds.END_NO_CONFIRM_KINDS.has(StringName(str(row["kind"])))
	if needs != bool(preview["needs_confirm"]):
		stats["error"] = "needs_confirm_mismatch"
		return {}
	return preview


static func _send(engine: CardEngineApi, action: Array, stats: Dictionary) -> bool:
	var preview: Dictionary = _preview(engine, stats)
	if not str(stats["error"]).is_empty():
		return false
	if action.size() != 2 or typeof(action[1]) != TYPE_DICTIONARY or str(action[0]).begins_with("ui."):
		stats["error"] = "invalid_picker_action"
		return false
	var result: Dictionary = engine.send(StringName(str(action[0])), action[1])
	stats["steps"] += 1
	(stats["last_actions"] as Array).append([str(action[0]), action[1], result])
	if stats["last_actions"].size() > 20:
		stats["last_actions"].pop_front()
	if str(action[0]) == "day.end":
		stats["end_checks"] += 1
		var err: String = str(result.get("err", ""))
		if not bool(result.get("ok", false)) and (bool(action[1].get("confirm", false)) or err != "must_resolve_pending"):
			stats["error"] = "day_end_failed:" + err
			return false
		if not CardViewModel.leaks(result).is_empty() or str(result.get("step", "")) != str(preview["step"]):
			stats["error"] = "end_step_mismatch_or_leak"
			return false
		if JSON.stringify(result.get("items", null), "", true) != JSON.stringify(preview["items"], "", true):
			stats["error"] = "preview_execution_mismatch"
			return false
	elif not bool(result.get("ok", false)):
		stats["expected_rejections"] += 1
	return true


static func _escape(engine: CardEngineApi, stats: Dictionary) -> bool:
	var before: int = int(engine.view().get("date", {}).get("abs_day", 0))
	stats["escape_checks"] += 1
	for count in range(1, CardIds.END_MAX_STEPS_TO_NEXT_DAY + 1):
		if not _send(engine, [&"day.end", {"confirm": true}], stats):
			return false
		var view: Dictionary = engine.view()
		if int(view.get("date", {}).get("abs_day", 0)) > before or str(view.get("phase", "")) == "game_over":
			stats["max_escape_steps"] = maxi(int(stats["max_escape_steps"]), count)
			return true
	stats["error"] = "escape_exceeded_eight_steps"
	return false


static func _result(engine: CardEngineApi, stats: Dictionary, cleared: int, reason: String) -> Dictionary:
	var view: Dictionary = engine.view()
	var evidence: Dictionary = stats.duplicate(true)
	if str(stats["error"]).is_empty():
		evidence.erase("last_actions")
	return {"ok": str(stats["error"]).is_empty(), "stages_cleared": cleared,
		"days": int(view.get("date", {}).get("abs_day", 0)), "game_over_reason": reason,
		"steps": int(stats["steps"]), "hash": CardAutoplay._hash(engine), "last_error": str(stats["error"]),
		"fuzz": evidence}
