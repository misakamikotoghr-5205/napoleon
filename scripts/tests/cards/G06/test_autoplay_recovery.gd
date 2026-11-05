# 策略空动作、反复失败和无进展时打烊；打烊自己失败立即暴露。
# G06；合同 1.2 §7.4.7。替身只模拟门面，不复制游戏规则。
extends SceneTree
const T := preload("res://scripts/tests/cards/lib/card_t.gd")
const Refuser := preload("res://scripts/cards/sim/policies/refuser.gd")


class ProbeEngine extends CardEngineApi:
	var day: int = 0
	var end_calls: int = 0
	var reject_end: bool = false
	var cmds: Array = []

	func new_game(_opts: Dictionary) -> Dictionary:
		return {"ok": true}
	func load_game(_path: String) -> Dictionary:
		return {"ok": true}
	func save_game(_path: String) -> Dictionary:
		return {"ok": true}
	func view() -> Dictionary:
		return {"phase": "morning" if day > 0 else "day", "date": {"abs_day": day, "stage": 0}}
	func query(_q: StringName, _args: Dictionary = {}) -> Dictionary:
		return {}
	func is_busy() -> bool:
		return false
	func state_hash() -> String:
		return "probe_hash"
	func send(cmd: StringName, args: Dictionary = {}) -> Dictionary:
		cmds.append([cmd, args])
		if cmd == &"day.end":
			end_calls += 1
			if reject_end:
				return {"ok": false, "err": "probe_bad_phase"}
			day += 1
			return {"ok": true}
		return {"ok": cmd == &"noop", "err": "probe_rejected"}


class EmptyPolicy extends CardPolicy:
	func decide(_engine: CardEngineApi, _view: Dictionary) -> Array:
		return []


class FailingPolicy extends CardPolicy:
	func decide(_engine: CardEngineApi, _view: Dictionary) -> Array:
		return [&"bad_cmd", {}]


class StuckPolicy extends CardPolicy:
	func decide(_engine: CardEngineApi, _view: Dictionary) -> Array:
		return [&"noop", {}]


func _initialize() -> void:
	var t: RefCounted = T.new(self, "G06_autoplay_recovery")
	for policy in [EmptyPolicy.new(), FailingPolicy.new(), StuckPolicy.new(), Refuser.new()]:
		var e: ProbeEngine = ProbeEngine.new()
		var result: Dictionary = CardAutoplay.play(e, policy, {"days": 1, "max_steps": 100})
		t.ok(result["ok"], "policy recovers through confirmed day end")
		t.eq(e.end_calls, 1, "one escape advances the day")
		t.eq(e.cmds[-1], [&"day.end", {"confirm": true}], "escape uses canonical confirmation")
	var failures: ProbeEngine = ProbeEngine.new()
	var failed: Dictionary = CardAutoplay.play(failures, FailingPolicy.new(), {"days": 1, "max_steps": 100})
	t.eq(failed["steps"], 4, "three repeated failures trigger immediate escape")
	var broken: ProbeEngine = ProbeEngine.new()
	broken.reject_end = true
	var broken_result: Dictionary = CardAutoplay.play(broken, EmptyPolicy.new(), {"days": 1})
	t.ok(not broken_result["ok"], "failed escape is a failed run")
	t.eq(broken_result["game_over_reason"], "day_end_failed", "failed escape identifies engine failure")
	t.eq(broken_result["steps"], 1, "failed escape terminates immediately")
	for phase in ["month_open", "morning", "day", "night", "settle", "month_close", "year_jump"]:
		t.eq(Refuser.new().decide(ProbeEngine.new(), {"phase": phase}), [&"day.end", {"confirm": true}], "refuser only ends " + phase)
	t.finish()
