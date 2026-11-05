## 战役层调用战斗内核的薄转接层（WORLD_MAP_DESIGN §15.3 交给 A 的接口，B1 已在 battle_rules.gd 里实现，见 BATTLE_V2.md 第五片）：
##   level_of_act(a)、row(L)、caps(scale, L)、power(tpl, L, setup)、can_stand(cls, terrain)、pick_weather、new_battle(tpl, {level, weather, mods, …})
## 这里只剩三件 battle_rules.gd 不管的事：模板库缓存、mods 夹进 B1 的取值范围、等级折回幕。
## 没有 class_name，别处 preload。只用整数。
extends RefCounted

const BattleRules = preload("res://scripts/cards/campaign/battle/battle_rules.gd")

## 模板库只读一次（BattleRules.load_templates() 每次都深拷贝一份，校验器和地图规则一次要查几百回）
static var _lib: Dictionary = {}


## 模板库（缓存）：{templates, scene_map, bond_sets, …}。只读，别改它
static func lib() -> Dictionary:
	if _lib.is_empty():
		_lib = BattleRules.load_templates()
	return _lib


static func template(id: String) -> Dictionary:
	return lib().get("templates", {}).get(id, {})


static func level_of_act(act: int) -> int:
	return BattleRules.level_of_act(act)


## 等级折回幕（旧字段 act 给现有内核和界面用；L = 2a−1 时正好是 a）
static func act_of_level(level: int) -> int:
	return clampi((clampi(level, 1, 24) + 1) / 2, 1, 6)


## §8.1 的一行：{level, hp_pct, morale_pct, atk, def, boss_hunters, boss_elites, elite_hunters,
## skirmish_hunters, boss_turns, elite_turns, skirmish_turns, stars}
static func row(level: int) -> Dictionary:
	return BattleRules.row(level)


static func stars(level: int) -> int:
	return int(row(level).get("stars", 1))


## 在场 / 伙伴名额 {field, companions}
static func caps(scale: String, level: int) -> Dictionary:
	var c: Dictionary = BattleRules.caps(scale, level)
	return {"field": int(c.get("field", 5)), "companions": int(c.get("companions", 2))}


## 敌方战力（ARCH §3.4）
static func power(template_id: String, level: int, setup: Dictionary = {}) -> int:
	return BattleRules.power(template_id, level, setup)


## 推荐战力（§8.4）
static func recommended_power(template_id: String, level: int, setup: Dictionary = {}) -> int:
	return BattleRules.recommended_power(template_id, level, setup)


static func can_stand(cls: String, terrain: String) -> bool:
	return BattleRules.can_stand(cls, terrain)


## 开战：setup 带 level / weather / mods（§6.6），开场军令点另走 setup.cp_bonus。
## mods 按 B1 的 MOD_RANGES 夹住（cp_bonus 超出的部分挪进 setup.cp_bonus；拖延带来的正的敌军心超出范围时只能先丢掉，
## 等 B 把 enemy_morale 的上限放宽到 +8）
static func new_battle(template_id: String, setup: Dictionary) -> Dictionary:
	return BattleRules.new_battle(template_id, fit_mods(setup))


## mods 夹进 B1 的取值范围（B1 的 _setup_errors 越界就整场拒绝）
static func fit_mods(setup: Dictionary) -> Dictionary:
	var su: Dictionary = setup.duplicate(true)
	var ranges: Dictionary = BattleRules.MOD_RANGES
	var mods = su.get("mods", {})
	if typeof(mods) != TYPE_DICTIONARY:
		return su
	for k in ranges:
		if not (mods as Dictionary).has(k):
			continue
		var lo := int(ranges[k][0])
		var hi := int(ranges[k][1])
		var v := int(mods[k])
		if k == "cp_bonus" and v > hi:
			su["cp_bonus"] = int(su.get("cp_bonus", 0)) + v - hi
		mods[k] = clampi(v, lo, hi)
	return su


## 模板的天时候选（节点没写就用模板的；都没写是 clear）
static func weather_options(template_id: String) -> Array:
	var tpl: Dictionary = template(template_id)
	var w = tpl.get("weather", [])
	if typeof(w) in [TYPE_STRING, TYPE_STRING_NAME] and str(w) != "":
		return [str(w)]
	return (w as Array).duplicate() if typeof(w) == TYPE_ARRAY and not (w as Array).is_empty() else ["clear"]


## 从候选里按种子确定地挑一个天时（B1 的 pick_weather；key_seed 用 seed_for(种子, "weather|<战斗键>")）
static func pick_weather(options: Array, key_seed: int) -> String:
	return BattleRules.pick_weather(options, key_seed)
