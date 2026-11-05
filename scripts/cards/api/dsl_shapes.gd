# 效果 / 条件 DSL 每个 op 的参数形状，以及新手指引数据的形状。校验器（V10、V30–V35）和各模块登记 op 时都用它。
# 主人 W0（Claude），冻结；改形状走 [api] issue。合同：docs/cards/CARDS_INTERFACES.md §5.1–§5.3、§4.7.21。
# 用法：ctx.ops.register(&"rep", handler, CardDslShapes.shape(&"rep"), "G03")；
#       条件 op 和效果 op 有同名的（flag、story、person_state、weather），条件用 CardDslShapes.shape(&"weather", true)。
# 形状函数签名 func(value_or_eff) -> String：空串 = 合法，否则是英文错误说明。
class_name CardDslShapes
extends RefCounted

# 效果 op → 主人（§5.2）
const EFFECT_OPS := {
	&"rep": "G03", &"heat": "G03", &"conscience": "G03", &"attr": "G03", &"flag": "G03", &"flag_clear": "G03",
	&"counter": "G03", &"story": "G03", &"dossier": "G03", &"dossier_gap": "G03", &"notice": "G03", &"if": "G03",
	&"coin_check": "G03", &"person_state": "G03", &"contact_gain": "G03", &"contact_lose": "G03",
	&"demand_tier": "G03", &"kept_risk": "G03",
	&"add_card": "G01", &"remove_card": "G01", &"waive": "G01", &"extra_deal": "G01",
	&"money": "G04", &"pay": "G04", &"item_gain": "G04", &"item_lose": "G04", &"shop_closed": "G04",
	&"price_mod": "G04", &"currency_convert": "G04",
	&"estate_seize": "G06", &"arrest": "G06",
	&"deck_mod": "G05", &"fate_now": "G05", &"big_wheel": "G05", &"wheel_offer": "G05", &"pressure": "G05",
	&"weather": "G05", &"peek": "G05",
	&"goal": "G02", &"game_over": "G02",
	&"stock_offer": "RG2",
}

# 条件 op → 主人（§5.3）
const COND_OPS := {
	&"all": "G03", &"any": "G03", &"not": "G03", &"flag": "G03", &"flag_eq": "G03", &"counter_gte": "G03",
	&"story": "G03", &"rep_tier_gte": "G03", &"rep_tier_lte": "G03", &"heat_tier_gte": "G03",
	&"heat_tier_lte": "G03", &"conscience_gte": "G03", &"conscience_lte": "G03", &"attr_gte": "G03",
	&"has_contact": "G03", &"has_kept": "G03", &"person_state": "G03", &"dossier_has": "G03",
	&"dossier_page_complete": "G03", &"demand_open": "G03",
	&"day_gte": "G02", &"abs_day_gte": "G02", &"weekday": "G02", &"era": "G02", &"stage_gte": "G02",
	&"mode": "G02", &"phase": "G02", &"goal_status": "G02",
	&"money_gte": "G04", &"money_lt": "G04", &"stock_cat_gte": "G04", &"stock_has": "G04", &"ticket_open": "G04",
	&"currency": "G04", &"mg_read": "G04",
	&"estate_status": "G06",
	&"weather": "G05", &"market_day": "G05", &"pressure_gte": "G05", &"fortune": "G05", &"almanac_yi": "G05",
	&"veteran": "RG5",
}

# 效果参数表：参数名 → 规格。"int" "str"(非空) "anystr"(可空) "bool" "dict" "strs"(字符串数组) "effects" "cond" "scalar"
# "match"(牌的匹配) "itemmatch"(物品的匹配) "e:a,b,c"(枚举)；末尾 "?" = 可选。
const EFFECT_PARAMS := {
	&"rep": {"delta": "int?", "tier": "int?"},
	&"heat": {"delta": "int?", "tier": "int?"},
	&"conscience": {"delta": "int"},
	&"attr": {"who": "str", "attr": "e:eye,tongue,pull,nerve", "delta": "int", "days": "int?"},
	&"flag": {"key": "str", "value": "scalar?"},
	&"flag_clear": {"key": "str"},
	&"counter": {"key": "str", "delta": "int"},
	&"story": {"node": "str", "outcome": "str"},
	&"dossier": {"frag": "str"},
	&"dossier_gap": {"frag": "str"},
	&"notice": {"key": "str", "args": "dict?"},
	&"if": {"cond": "cond", "then": "effects", "else": "effects?"},
	&"coin_check": {"coins": "int", "need": "int", "then": "effects", "else": "effects?"},
	&"person_state": {"person": "str", "state": "e:ok,hurt,jailed,away,gone,changed", "days": "int?"},
	&"contact_gain": {"person": "str"},
	&"contact_lose": {"person": "str"},
	&"demand_tier": {"delta": "int"},
	&"kept_risk": {"tags_any": "strs"},
	&"add_card": {"card": "str", "to": "e:hand,kept,contacts,pending,queue", "in_days": "int?"},
	&"remove_card": {"match": "match", "from": "e:hand,kept,pending,any", "n": "int?"},
	&"waive": {"match": "match", "n": "int?"},
	&"extra_deal": {"type": "str", "n": "int?", "day": "e:today,tomorrow"},
	&"money": {"delta": "int", "reason": "str"},
	&"pay": {"amount": "int", "payee": "str", "reason": "str", "short": "e:ladder,partial,fail"},
	&"item_gain": {"template": "str?", "cat": "str?", "n": "int?"},
	&"item_lose": {"match": "itemmatch", "n": "int?", "reason": "str"},
	&"estate_seize": {"pick": "str"},
	&"shop_closed": {"days": "int"},
	&"arrest": {"reason": "str"},
	&"price_mod": {"scope": "e:shelf,cat", "cat": "str?", "pct": "int", "days": "int"},
	&"currency_convert": {"to": "str", "num": "int", "den": "int"},
	&"deck_mod": {"pool": "str", "tags_any": "strs?", "def": "str?", "valence": "e:good,bad,mixed,neutral?",
		"pct": "int", "days": "int"},
	&"fate_now": {"day": "e:today,tomorrow"},
	&"big_wheel": {"crisis": "e:cash_short,arrested,heat_max,street_long"},
	&"wheel_offer": {"wheel": "str", "cost": "dict?"},
	&"pressure": {"key": "str", "delta_milli": "int"},
	&"weather": {"value": "e:clear,rain,fog,wind,snow"},
	&"peek": {"pool": "str", "n": "int?"},
	&"goal": {"id": "str", "status": "e:done,failed"},
	&"game_over": {"reason": "str"},
	&"stock_offer": {"n": "int", "kinds": "strs", "depths": "strs?", "from": "str"},
}

# 条件值表：op → 规格。"[str,int]" 这类写成数组规格。
const COND_VALUES := {
	&"flag": "str", &"flag_eq": ["str", "scalar"], &"counter_gte": ["str", "int"], &"story": ["str", "str"],
	&"rep_tier_gte": "tier", &"rep_tier_lte": "tier", &"heat_tier_gte": "tier", &"heat_tier_lte": "tier",
	&"conscience_gte": "int", &"conscience_lte": "int", &"attr_gte": ["str", "e:eye,tongue,pull,nerve", "int"],
	&"has_contact": "str", &"has_kept": "keptmatch", &"person_state": ["str", "e:ok,hurt,jailed,away,gone,changed"],
	&"dossier_has": "str", &"dossier_page_complete": "str", &"demand_open": "str",
	&"day_gte": "int", &"abs_day_gte": "int", &"weekday": "weekday", &"era": "str", &"stage_gte": "int",
	&"mode": "e:shop,street",
	&"phase": "e:boot,month_open,morning,day,night,settle,month_close,year_jump,game_over,branch_pick",
	&"goal_status": ["str", "str"], &"money_gte": "int", &"money_lt": "int", &"stock_cat_gte": ["str", "int"],
	&"stock_has": "str", &"ticket_open": "str", &"estate_status": ["str", "e:held,mortgaged,lost"],
	&"currency": "str", &"mg_read": ["str", "e:right,partial,wrong"], &"weather": "e:clear,rain,fog,wind,snow", &"market_day": "bool",
	&"pressure_gte": ["str", "int"], &"fortune": "str",
	&"almanac_yi": "e:pawn_in,buy_in,sell_out,redeem,trade,meet,travel,pray,repair,rest,lend,wed",
	&"veteran": "bool",
}

const GUIDE_STEP_FIELDS := {
	"teaches": "strs", "trigger": "dict?", "teacher": "anystr", "anchor": "str", "anchor_fallback": "anystr?",
	"done_when": "strs", "rule_page": "str", "priority": "int?", "interrupt": "bool?", "max_shows": "int?",
	"seconds": "int?",
}
const GUIDE_TRIGGER_FIELDS := {
	"first": "str?", "phase": "phase?", "mode": "e:shop,street?", "stage_gte": "int?", "stage_day_gte": "int?",
	"abs_day_gte": "int?", "after": "strs?", "panel": "str?", "hand_clear": "bool?", "cond": "cond?",
}
const RULE_PAGE_FIELDS := {"order": "int", "unlock_first": "strs", "teacher": "anystr?"}


## 某个 op 的形状函数（cond = true 取条件 op 的）。不认识的 op 返回的函数永远报错。
static func shape(op: StringName, cond: bool = false) -> Callable:
	return CardDslShapes._shape_dispatch.bind(op, cond)


static func _shape_dispatch(value, op: StringName, cond: bool) -> String:
	if cond:
		return cond_param_error(op, value)
	return effect_param_error(op, value)


static func is_effect_op(op: String) -> bool:
	return EFFECT_OPS.has(StringName(op))


static func is_cond_op(op: String) -> bool:
	return COND_OPS.has(StringName(op))


## 一个效果的形状：op 认识、参数齐、类型对、没有多余参数（_ 开头的除外）。
static func check_effect(eff) -> String:
	if typeof(eff) != TYPE_DICTIONARY:
		return "effect must be an object"
	if not eff.has("op") or typeof(eff["op"]) != TYPE_STRING:
		return "effect has no op"
	var op := StringName(str(eff["op"]))
	if not EFFECT_OPS.has(op):
		return "unknown effect op '%s'" % op
	return effect_param_error(op, eff)


## 一串效果：返回所有错误（带下标）。
static func check_effects(effects) -> PackedStringArray:
	var out := PackedStringArray()
	if typeof(effects) != TYPE_ARRAY:
		out.append("effects must be an array")
		return out
	for i in range(effects.size()):
		var e := check_effect(effects[i])
		if e != "":
			out.append("[%d] %s" % [i, e])
	return out


static func effect_param_error(op: StringName, eff) -> String:
	if typeof(eff) != TYPE_DICTIONARY:
		return "effect must be an object"
	if not EFFECT_PARAMS.has(op):
		return "unknown effect op '%s'" % op
	var spec: Dictionary = EFFECT_PARAMS[op]
	for k in eff.keys():
		var key := str(k)
		if key == "op" or key.begins_with("_"):
			continue
		if not spec.has(key):
			return "%s: unknown param '%s'" % [op, key]
	for key in spec.keys():
		var e := _check_spec(str(spec[key]), eff.has(key), eff.get(key))
		if e != "":
			return "%s.%s: %s" % [op, key, e]
	if op == &"rep" or op == &"heat":
		if eff.has("delta") == eff.has("tier"):
			return "%s: give exactly one of delta / tier" % op
	if op == &"coin_check":
		if int(eff["need"]) < 0 or int(eff["need"]) > 12 or int(eff["coins"]) < 0:
			return "coin_check: coins >= 0, need 0-12"
	return ""


## 一个条件（{} 为真；单键对象；all/any/not 递归）。
static func check_cond(c) -> String:
	if typeof(c) != TYPE_DICTIONARY:
		return "condition must be an object"
	if c.is_empty():
		return ""
	if c.size() != 1:
		return "condition must have exactly one key"
	var op := StringName(str(c.keys()[0]))
	if not COND_OPS.has(op):
		return "unknown condition op '%s'" % op
	return cond_param_error(op, c[c.keys()[0]])


static func cond_param_error(op: StringName, value) -> String:
	if op == &"all" or op == &"any":
		if typeof(value) != TYPE_ARRAY:
			return "%s: needs an array of conditions" % op
		for i in range(value.size()):
			var e := check_cond(value[i])
			if e != "":
				return "%s[%d]: %s" % [op, i, e]
		return ""
	if op == &"not":
		return check_cond(value) if typeof(value) == TYPE_DICTIONARY else "not: needs a condition object"
	if not COND_VALUES.has(op):
		return "unknown condition op '%s'" % op
	var spec = COND_VALUES[op]
	if typeof(spec) == TYPE_ARRAY:
		if typeof(value) != TYPE_ARRAY or value.size() != spec.size():
			return "%s: needs [%s]" % [op, ", ".join(PackedStringArray(spec))]
		for i in range(spec.size()):
			var e := _check_spec(str(spec[i]), true, value[i])
			if e != "":
				return "%s[%d]: %s" % [op, i, e]
		return ""
	var e2 := _check_spec(str(spec), true, value)
	return "" if e2 == "" else "%s: %s" % [op, e2]


## 条件里用到的所有 op（递归），给 V35 用。
static func cond_ops_used(c) -> PackedStringArray:
	var out := PackedStringArray()
	if typeof(c) != TYPE_DICTIONARY:
		return out
	for k in c.keys():
		var op := str(k)
		out.append(op)
		var v = c[k]
		if (op == "all" or op == "any") and typeof(v) == TYPE_ARRAY:
			for sub in v:
				out.append_array(cond_ops_used(sub))
		elif op == "not":
			out.append_array(cond_ops_used(v))
	return out


## 新手指引步骤的字段形状（语义检查 V30–V32、V35 在校验器里）。
static func check_guide_step(step: Dictionary) -> String:
	for key in GUIDE_STEP_FIELDS.keys():
		var e := _check_spec(str(GUIDE_STEP_FIELDS[key]), step.has(key), step.get(key))
		if e != "":
			return "%s: %s" % [key, e]
	if step.has("trigger"):
		var trig: Dictionary = step["trigger"]
		for k in trig.keys():
			if not GUIDE_TRIGGER_FIELDS.has(str(k)):
				return "trigger: unknown key '%s'" % k
		for key in GUIDE_TRIGGER_FIELDS.keys():
			var e2 := _check_spec(str(GUIDE_TRIGGER_FIELDS[key]), trig.has(key), trig.get(key))
			if e2 != "":
				return "trigger.%s: %s" % [key, e2]
	if (step.get("done_when", []) as Array).is_empty():
		return "done_when: must not be empty"
	return ""


static func check_rule_page(page: Dictionary) -> String:
	for key in RULE_PAGE_FIELDS.keys():
		var e := _check_spec(str(RULE_PAGE_FIELDS[key]), page.has(key), page.get(key))
		if e != "":
			return "%s: %s" % [key, e]
	return ""


# Contract 1.3 local stage checks. Registration and art checks belong to G01.
static func check_stage(card: Dictionary) -> PackedStringArray:
	var out := PackedStringArray()
	if not card.has("stage"):
		return out
	if not CardIds.STAGE_TYPES.has(StringName(str(card.get("type", "")))):
		out.append("V40: card type cannot have stage")
	if typeof(card.stage) != TYPE_DICTIONARY:
		out.append("V38: stage must be an object")
		return out
	var stage: Dictionary = card.stage
	var keys := stage.keys()
	keys.sort_custom(func(a, b): return str(a) < str(b))
	for key in keys:
		if not CardIds.STAGE_KEYS.has(str(key)):
			out.append("V38: stage has unknown key '%s'" % key)
	_stage_enum(stage, "set", CardIds.STAGE_SETS, out)
	_stage_enum(stage, "walk", CardIds.STAGE_WALKS, out)
	if stage.has("brief") and typeof(stage.brief) != TYPE_STRING:
		out.append("V38: stage.brief must be a string")
	var speakers: Array = ["", "me"]
	if typeof(card.get("person")) == TYPE_STRING:
		speakers.append(card.person)
	_stage_cast(stage, speakers, out)
	_stage_props(stage, out)
	_stage_fx(stage, out)
	if stage.has("intro"):
		_stage_beats(stage.intro, int(CardIds.STAGE_LIMITS.intro), speakers, "intro", out)
	_stage_after(card, stage, speakers, out)
	if str(stage.get("set", "counter")) != "counter" and stage.has("walk"):
		out.append("V41: walk is only allowed in counter")
	return out


static func _stage_enum(stage: Dictionary, key: String, values: Array, out: PackedStringArray) -> void:
	if stage.has(key) and (typeof(stage[key]) != TYPE_STRING or not values.has(StringName(str(stage[key])))):
		out.append("V38: stage.%s has invalid value" % key)


static func _stage_cast(stage: Dictionary, speakers: Array, out: PackedStringArray) -> void:
	if not stage.has("cast"):
		return
	if typeof(stage.cast) != TYPE_ARRAY:
		out.append("V38: stage.cast must be an array")
		return
	if stage.cast.size() > int(CardIds.STAGE_LIMITS.cast):
		out.append("V38: stage.cast exceeds limit")
	var spots: Array = []
	for i in range(stage.cast.size()):
		var entry = stage.cast[i]
		var shape_error := _check_keys(entry, {"who": "str", "at": "str", "look": "str?", "brief": "anystr?"})
		if shape_error != "":
			out.append("V38: cast[%d]: %s" % [i, shape_error])
			continue
		speakers.append(str(entry.who))
		var at := StringName(str(entry.at))
		var look := StringName(str(entry.get("look", "stand")))
		if not CardIds.STAGE_SPOTS.has(at) or not CardIds.CAST_LOOKS.has(look):
			out.append("V38: cast[%d] has invalid at or look" % i)
		if (look == &"walk" and at != &"street") or (at == &"street" and look not in [&"walk", &"shadow"]):
			out.append("V38: cast[%d] has incompatible at and look" % i)
		if spots.has(at):
			out.append("V41: duplicate cast spot '%s'" % at)
		spots.append(at)
		if at == &"street" and str(stage.get("set", "counter")) != "counter":
			out.append("V41: street spot is only allowed in counter")
	if spots.has(&"door") and (spots.has(&"door_l") or spots.has(&"door_r")):
		out.append("V41: door conflicts with door_l or door_r")


static func _stage_props(stage: Dictionary, out: PackedStringArray) -> void:
	if not stage.has("props"):
		return
	if typeof(stage.props) != TYPE_ARRAY:
		out.append("V38: stage.props must be an array")
		return
	if stage.props.size() > int(CardIds.STAGE_LIMITS.props):
		out.append("V38: stage.props exceeds limit")
	var art_pattern := RegEx.create_from_string("^prop\\.[a-z0-9_]+$")
	for i in range(stage.props.size()):
		var entry = stage.props[i]
		var shape_error := _check_keys(entry, {"art": "str", "at": "str", "brief": "anystr?"})
		if shape_error != "":
			out.append("V38: props[%d]: %s" % [i, shape_error])
			continue
		if art_pattern.search(str(entry.art)) == null or not CardIds.PROP_SPOTS.has(StringName(str(entry.at))):
			out.append("V38: props[%d] has invalid art or at" % i)


static func _stage_fx(stage: Dictionary, out: PackedStringArray) -> void:
	if not stage.has("fx"):
		return
	if typeof(stage.fx) != TYPE_ARRAY:
		out.append("V38: stage.fx must be an array")
		return
	if stage.fx.size() > int(CardIds.STAGE_LIMITS.fx):
		out.append("V38: stage.fx exceeds limit")
	var seen: Array = []
	for value in stage.fx:
		if typeof(value) != TYPE_STRING or not CardIds.STAGE_FX.has(StringName(str(value))):
			out.append("V38: invalid stage.fx value")
		if seen.has(value):
			out.append("V38: duplicate stage.fx value")
		seen.append(value)


static func _stage_beats(value, limit: int, speakers: Array, path: String, out: PackedStringArray) -> void:
	if typeof(value) != TYPE_ARRAY:
		out.append("V38: %s must be an array" % path)
		return
	if value.size() > limit:
		out.append("V38: %s exceeds beat limit" % path)
	var ref_pattern := RegEx.create_from_string(CardIds.STAGE_REF_REGEX)
	for i in range(value.size()):
		var beat = value[i]
		var shape_error := _check_keys(beat, {"who": "anystr", "ref": "str", "brief": "str"})
		if shape_error != "":
			out.append("V38: %s[%d]: %s" % [path, i, shape_error])
			continue
		if str(beat.brief).strip_edges() == "" or ref_pattern.search(str(beat.ref)) == null:
			out.append("V38: %s[%d] has invalid ref or empty brief" % [path, i])
		if not speakers.has(str(beat.who)):
			out.append("V39: %s[%d] speaker is not in this stage" % [path, i])


static func _stage_after(card: Dictionary, stage: Dictionary, speakers: Array, out: PackedStringArray) -> void:
	if not stage.has("after"):
		return
	if typeof(stage.after) != TYPE_DICTIONARY:
		out.append("V38: stage.after must be an object")
		return
	var allowed: Array = []
	for key in CardIds.STAGE_AFTER_KEYS:
		allowed.append(str(key))
	if str(card.get("type", "")) == "demand":
		for key in CardIds.DEMAND_MODES:
			allowed.append(str(key))
	if typeof(card.get("choices")) == TYPE_ARRAY:
		for choice in card.choices:
			if typeof(choice) == TYPE_DICTIONARY and typeof(choice.get("id")) == TYPE_STRING:
				allowed.append(str(choice.id))
	var keys: Array = stage.after.keys()
	keys.sort_custom(func(a, b): return str(a) < str(b))
	for key in keys:
		if not allowed.has(str(key)):
			out.append("V38: unknown stage.after key '%s'" % key)
		_stage_beats(stage.after[key], int(CardIds.STAGE_LIMITS.after), speakers, "after.%s" % key, out)


# ---------------- 规格检查 ----------------
static func is_int(v) -> bool:
	if typeof(v) == TYPE_INT:
		return true
	return typeof(v) == TYPE_FLOAT and is_finite(v) and v == floorf(v)


static func _check_spec(spec: String, present: bool, v) -> String:
	var optional := spec.ends_with("?")
	if optional:
		spec = spec.substr(0, spec.length() - 1)
	if not present:
		return "" if optional else "missing"
	if spec.begins_with("e:"):
		var allowed := spec.substr(2).split(",")
		if typeof(v) != TYPE_STRING or not allowed.has(str(v)):
			return "must be one of %s" % ", ".join(allowed)
		return ""
	match spec:
		"int":
			return "" if is_int(v) else "must be an integer"
		"tier":
			return "" if is_int(v) and int(v) >= 0 and int(v) <= 4 else "must be an integer 0-4"
		"weekday":
			return "" if is_int(v) and int(v) >= 0 and int(v) <= 6 else "must be an integer 0-6"
		"str":
			return "" if typeof(v) == TYPE_STRING and str(v) != "" else "must be a non-empty string"
		"anystr":
			return "" if typeof(v) == TYPE_STRING else "must be a string"
		"bool":
			return "" if typeof(v) == TYPE_BOOL else "must be true/false"
		"dict":
			return "" if typeof(v) == TYPE_DICTIONARY else "must be an object"
		"scalar":
			return "" if typeof(v) in [TYPE_BOOL, TYPE_STRING] or is_int(v) else "must be bool, integer or string"
		"strs":
			if typeof(v) != TYPE_ARRAY:
				return "must be an array of strings"
			for x in v:
				if typeof(x) != TYPE_STRING:
					return "must be an array of strings"
			return ""
		"phase":
			if typeof(v) == TYPE_STRING:
				return "" if CardIds.PHASES.has(StringName(str(v))) else "unknown phase"
			if typeof(v) == TYPE_ARRAY:
				for x in v:
					if typeof(x) != TYPE_STRING or not CardIds.PHASES.has(StringName(str(x))):
						return "unknown phase"
				return ""
			return "must be a phase name or an array of them"
		"effects":
			var errs := check_effects(v)
			return "" if errs.is_empty() else errs[0]
		"cond":
			return check_cond(v)
		"match":
			return _check_keys(v, {"def": "str?", "type": "str?", "tags_any": "strs?"})
		"itemmatch":
			return _check_keys(v, {"cat": "str?", "template": "str?", "pick": "e:best,worst,any?"})
		"keptmatch":
			return _check_keys(v, {"def": "str?", "tags_any": "strs?"})
	return "bad spec '%s'" % spec


static func _check_keys(v, spec: Dictionary) -> String:
	if typeof(v) != TYPE_DICTIONARY:
		return "must be an object"
	for k in v.keys():
		if not spec.has(str(k)):
			return "unknown key '%s'" % k
	for key in spec.keys():
		var e := _check_spec(str(spec[key]), v.has(key), v.get(key))
		if e != "":
			return "%s: %s" % [key, e]
	return ""
