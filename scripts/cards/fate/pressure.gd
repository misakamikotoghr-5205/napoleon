# 旧压力与天气模块只接收临时浮点字典，结果转回整数千分数。
# 卡牌数据自带最小 ASCII 配置，不读取旧 town_pack。
class_name CardPressure
extends RefCounted

static func step_day(ctx: CardCtx) -> void:
	var pack := _pack(ctx)
	var temporary := _temporary(ctx, pack)
	PressureModel.step(pack, temporary)
	var wheel: Dictionary = ctx.rules("daily_wheels").get("climate", {})
	if not wheel.is_empty():
		ctx.state.ns("fate")["weather"] = WorldWheel.spin(pack, temporary, wheel, _ignore)
	_persist(ctx, temporary)
	var fate := ctx.state.ns("fate")
	if fate.has("weather_next"):
		fate["weather"] = str(fate["weather_next"])
		fate.erase("weather_next")
	if str(fate.get("weather", "clear")) != "clear":
		CardFirsts.mark(ctx, &"weather", {})
	if CardCalendar.is_market_day(ctx, int(ctx.state.ns("loop").get("stage_day", 0))):
		CardFirsts.mark(ctx, &"market_day", {})

static func value_milli(ctx: CardCtx, key: String) -> int:
	return int(ctx.state.ns("fate").get("pressures_milli", {}).get(key, ctx.rules("pressures").get("pressures", {}).get(key, {}).get("base_milli", 0)))

static func influence(ctx: CardCtx, key: String, delta_milli: int, source: String) -> void:
	var pack := _pack(ctx)
	if not pack["pressures"].has(key) or str(pack["pressures"][key].get("kind", "")) != "endogenous":
		return
	var temporary := _temporary(ctx, pack)
	PressureModel.add_influence(pack, temporary, key, float(delta_milli) / 1000.0, source)
	_persist(ctx, temporary)

static func _pack(ctx: CardCtx) -> Dictionary:
	var pressures: Dictionary = {}
	var config := ctx.rules("pressures")
	var keys: Array = config.get("pressures", {}).keys()
	keys.sort()
	for key in keys:
		var spec: Dictionary = config["pressures"][key]
		pressures[key] = {"kind": str(spec.get("kind", "exogenous")), "half_life_days": int(spec.get("half_life_days", 10))}
		for field in ["base", "min", "max", "noise", "revert"]:
			pressures[key][field] = float(spec.get(field + "_milli", 0)) / 1000.0
	var caps: Dictionary = {}
	var cap_keys: Array = config.get("daily_cap_milli", {}).keys()
	cap_keys.sort()
	for key in cap_keys:
		caps[key] = float(config["daily_cap_milli"][key]) / 1000.0
	return {"pressures": pressures, "influence": {"daily_cap": caps}, "difficulty": {"normal": {}}, "time": {"season_days": 90}}

static func _temporary(ctx: CardCtx, pack: Dictionary) -> Dictionary:
	var fate := ctx.state.ns("fate")
	var values: Dictionary = {}
	var keys: Array = pack["pressures"].keys()
	keys.sort()
	for key in keys:
		values[key] = float(value_milli(ctx, str(key))) / 1000.0
	var spent: Dictionary = {}
	var spent_keys: Array = fate.get("influence_spent", {}).keys()
	spent_keys.sort()
	for key in spent_keys:
		spent[key] = float(fate["influence_spent"][key]) / 1000.0
	return {"seed": ctx.seed(), "day": ctx.abs_day(), "difficulty": "normal", "pressures": values,
		"influence_spent": spent, "day_report": {}, "wheel_last": fate.get("wheel_last", {}).duplicate(true)}

static func _persist(ctx: CardCtx, temporary: Dictionary) -> void:
	var fate := ctx.state.ns("fate")
	for fields in [["pressures", "pressures_milli"], ["influence_spent", "influence_spent"]]:
		var result: Dictionary = {}
		var keys: Array = temporary[fields[0]].keys()
		keys.sort()
		for key in keys:
			result[key] = int(round(float(temporary[fields[0]][key]) * 1000.0))
		fate[fields[1]] = result
	fate["wheel_last"] = temporary["wheel_last"].duplicate(true)

static func _ignore(_effect: Dictionary, _source: String) -> void:
	pass
