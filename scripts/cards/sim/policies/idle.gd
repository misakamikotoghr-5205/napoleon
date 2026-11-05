# idle 自动玩策略入口（肉鸽 v1，RG6）：同 refuser 永远只打烊，唯一的例外是盘账叠层开着时白拿第一样（量“拒绝一切但白拿”）。
# 不理货郎（不选 look），所以只会碰到周末盘账。合同 §12.6；docs/cards/rogue/ROGUE_V1.md §14 RG6。不用随机。
extends "res://scripts/cards/sim/policy.gd"


func policy_name() -> StringName:
	return &"idle"


## The first untried item of an open stocktake (offer order; never the pass); otherwise close the day like refuser.
func decide(engine: CardEngineApi, view: Dictionary) -> Array:
	_step += 1
	var panel: Dictionary = view.get("open_panel", {})
	if str(panel.get("kind", "")) == "stocktake":
		_decision_key = _state_key(view)
		for action in _stocktake(engine, panel.get("args", {})):
			var key: String = _decision_key + _action_key(action)
			if str(action[1].get("pick", "")) != "" and not _tried.has(key):
				_tried[key] = true
				return action
	return [&"day.end", {"confirm": true}]
