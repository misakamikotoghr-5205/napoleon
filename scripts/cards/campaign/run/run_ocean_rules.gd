## 远洋内置规则（WORLD_MAP_DESIGN §6.3、ARCH §1.5）：段定义没写 rules.* / on_enter.demands 时，内核回落到这里。
## 这些常量和 0bf260eb 的 ocean_campaign.gd 硬编码逐条等价（单段书 ocean_pawn 的 hash_v1 序列等于 golden）。
## 没有 class_name，别处 preload。玩家看得见的字不在这里（催逼标题仍由 ocean_campaign.gd 填）。
extends RefCounted

const PERFECT_FLAGS := ["escape_prepared", "arsenic_evidence", "viper_captured", "vigo_decoy_exposed", "orichalcum_cut"]

const FAILURES := [
	{"ending": "tragedy", "reason": "vigo_decoy", "when": {"flags": ["vigo_decoy_missed"], "metric": {"heat": [">=", 100]}}},
	{"ending": "bankruptcy", "reason": "treasury", "when": {"metric": {"treasury": ["<=", 0]}}},
	{"ending": "loss", "reason": "vitality", "when": {"metric": {"vitality": ["<=", 0]}}},
	{"ending": "blockade", "reason": "heat", "when": {"metric": {"heat": [">=", 100]}}},
]

const DEFAULT_ENDING := "bittersweet"

const EXCLUSIVE_FLAGS := [["revolution_funded", "refused_funding"]]

## 营地动作的金额和章节（_visit / _trade / _project / _fund）
const ACTIONS := {
	"visit_town": {"cost": 100, "effects": {"vitality": 5, "morale": 3}, "items_by_chapter": {"st_helena": ["medicine"]}},
	"visit_backdoor": {"effects": {"heat": 8, "exploration": 10}},
	"trade_fair": {"effects": {"treasury": 200, "morale": 4}},
	"trade_counterfeit": {"effects": {"treasury": 1500, "morale": -20, "heat": 10}, "flags": ["counterfeit_trade"]},
	"build": {"metric": "construction", "chapters": ["new_elba"], "cost": 200, "gain": 25},
	"explore": {"metric": "exploration", "chapters": ["nautilus"], "cost": 200, "gain": 25},
	"fund": {"chapters": ["nautilus"], "yes": {"cost": 1000, "effects": {"morale": 15}, "flags": ["revolution_funded"]},
		"no": {"flags": ["refused_funding"]}},
}

## 营令三色旗：每天（daily）的指标效果；地图效果（map）远洋单段书没有
const SIGNS := {
	"red": {"daily": {"heat": 15}, "map": {}},
	"white": {"daily": {}, "map": {}},
	"black": {"daily": {"treasury": -10, "heat": -10}, "map": {}},
}

## scene01 进场时发的两条催逼（title 由 ocean_campaign.gd 按 id 填）
const DEMANDS := {
	"scene01": [
		{"id": "medicine", "due_in": 5, "cost": 0, "item": "medicine",
			"on_expire": {"effects": {"vitality": -25}, "flags": ["medicine_missed"]}, "on_fulfill": {"flags": ["medicine_delivered"]}},
		{"id": "bond", "due_in": 5, "cost": 1000, "item": "",
			"on_expire": {"effects": {"heat": 25}, "flags": ["bond_missed"]}, "on_fulfill": {"flags": ["bond_paid"]}},
	],
}


## 远洋结局表（tuning.wealth_limit 进 dark 的门槛）
static func endings(definition: Dictionary) -> Array:
	var wealth := int(definition.get("tuning", {}).get("wealth_limit", 20000))
	return [
		{"id": "tragedy", "when": {"flags": ["vigo_decoy_missed"], "metric": {"heat": [">=", 100]}}},
		{"id": "dark", "when": {"metric": {"treasury": [">", wealth], "morale": ["<", 30]}, "flags": ["theft_treasure", "counterfeit_trade"]}},
		{"id": "ghost", "when": {"metric": {"construction": [">=", 100], "exploration": [">=", 100]}, "flags": ["refused_funding"]}},
		{"id": "alliance", "when": {"flags": PERFECT_FLAGS.duplicate()}},
	]


## 一段的有效规则：段定义写了的键用段的，没写的回落远洋内置
static func rules(definition: Dictionary) -> Dictionary:
	var own: Dictionary = definition.get("rules", {}) if typeof(definition.get("rules")) == TYPE_DICTIONARY else {}
	var out := {
		"failures": own.get("failures", FAILURES),
		"endings": own.get("endings", endings(definition)),
		"default_ending": own.get("default_ending", DEFAULT_ENDING if not own.has("endings") else ""),
		"exclusive_flags": own.get("exclusive_flags", EXCLUSIVE_FLAGS),
		"actions": _merge_actions(own.get("actions", {})),
		"signs": own.get("signs", SIGNS),
		"volume_endings": own.get("volume_endings", []),
		"default_volume_ending": own.get("default_volume_ending", ""),
	}
	return out


## 段写了 actions 时逐项覆盖（没写的动作沿用远洋数值；fund 的章节为空就是本段不开）
static func _merge_actions(own) -> Dictionary:
	var out: Dictionary = ACTIONS.duplicate(true)
	if typeof(own) != TYPE_DICTIONARY:
		return out
	for key in own:
		if str(key).begins_with("_") or typeof(own[key]) != TYPE_DICTIONARY:
			continue
		out[key] = (own[key] as Dictionary).duplicate(true)
	return out


## 一场进场时要发的催逼：段定义的 on_enter.demands；ocean_pawn（没有 on_enter）回落内置
static func scene_demands(definition: Dictionary, scene: Dictionary) -> Array:
	var on_enter = scene.get("on_enter")
	if typeof(on_enter) == TYPE_DICTIONARY:
		return (on_enter.get("demands", []) as Array).duplicate(true)
	if _uses_builtin_demands(definition):
		return (DEMANDS.get(str(scene.get("id", "")), []) as Array).duplicate(true)
	return []


## 全段所有催逼的定义（存档校验、到期、交付用）：{id: spec + chapter}
static func demand_specs(definition: Dictionary) -> Dictionary:
	var out := {}
	for scene in definition.get("scenes", []):
		for spec in scene_demands(definition, scene):
			var row: Dictionary = spec.duplicate(true)
			row["chapter"] = str(scene.get("chapter", ""))
			out[str(spec.get("id", ""))] = row
	return out


## 段里没有一场写 on_enter 时，才用远洋内置的两条（新段不会凭空多出 scene01 的催逼）
static func _uses_builtin_demands(definition: Dictionary) -> bool:
	for scene in definition.get("scenes", []):
		if typeof(scene.get("on_enter")) == TYPE_DICTIONARY:
			return false
	return str(definition.get("id", "")) == "ocean_pawn"
