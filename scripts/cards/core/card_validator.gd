# 数据校验器：合同1.2 §4.9 V01–V37；默认模式的 NOTE 在 strict/ship 里升级为错误。
# 主校验器做形状、归属与基础格式；validation_extra 补引用、完整性及发行正文检查。
# 主人 G01。合同：docs/cards/CARDS_INTERFACES.md §4.9、§4.10、§11.4。
class_name CardValidator
extends RefCounted

const Extra = preload("res://scripts/cards/core/validation_extra.gd")
const Packs = preload("res://scripts/cards/core/card_packs.gd")
## 剧情插件里不许有的文件（插件只放数据：pack.json、text/**.json，以后的 cards/**.json、art/**）
const PACK_CODE_EXT: Array[String] = ["gd", "gdc", "cs", "tscn", "scn", "tres", "res", "gdshader", "gdextension",
	"so", "dll", "dylib", "exe", "pck", "zip", "sh", "py", "bat"]

const OWNERSHIP_PATH := "res://docs/cards/ownership.json"
const SCHEMA_DIR := "res://data/cards/_schema"
const TEMPLATES_PATH := "res://data/town/item_templates.json"
const TEXT_FIELDS: Array[String] = ["text", "title", "body", "label", "name", "lines", "desc"]
const PROVENANCE_RE := "^human:(A|B):\\d{4}-\\d{2}-\\d{2}$"
const AI_PROVENANCE_RE := "^ai:[^:]+:[^:]+:[0-9]{4}-[0-9]{2}-[0-9]{2}:.+$"
const CJK_RE := "[\\x{3000}-\\x{9fff}\\x{f900}-\\x{faff}\\x{ff00}-\\x{ffef}]"
const CONTACT_HOOKS: Array[String] = ["day_start", "deal", "demand_issue", "settle"]
## 各规则文件必需的顶层键（V25）。loop.dusk_pct 来自 G02 的 loop.json（#141）。
const RULE_KEYS := {
	"deal": ["person", "event", "news", "night_offer", "street_per_day", "caps", "hand_order", "scripted_days"],
	"slots": ["head", "money_per_coin", "item_coins", "news_coins", "max_coins"],
	"meters": ["rep", "heat", "conscience", "attr"],
	"demand_rules": ["issue_weekday", "deadline_days", "delay", "tier_by_stage", "max_tier", "fail"],
	"economy": ["start_money", "shelf_cap", "max_rounds", "tiers", "patience", "ticket", "redeem", "appraise"],
	"ladder": ["mortgage", "short", "street", "prison"],
	"guide": ["gap_ms", "fade_in_ms", "fade_out_ms", "fade_fast_ms", "default_seconds", "max_new_per_day",
		"bubble_max_w"],
	"fate": ["fate", "big"],
	"fortune": ["lot", "cezi", "almanac", "wheel"],
	"stages": ["stages"],
	"loop": ["open_minute", "close_minute", "dusk_pct", "life_per_week"],
	"goals_rules": ["optional_count", "verdict_done_min"],
	"currency": ["currencies", "conversions"],
	"items_balance": ["items"],
	"weights": ["factors"],
	"pressures": ["pressures", "daily_cap_milli"],
	"daily_wheels": ["climate"],
}
## 正文覆盖层里各类型的必填字段（§4.5；V26 的“允许的字段” = 这些 + lines.* outcomes.* choices.* slots.* use）
const TEXT_REQUIRED := {
	"person": ["title", "body", "lines.greet"], "self": ["title", "body"], "contact": ["title", "body"],
	"event": ["title", "body"], "fate": ["title", "body"], "big_fate": ["title", "body"], "life": ["title", "body"],
	"street": ["title", "body"], "prison": ["title", "body"],
	"demand": ["title", "body", "outcomes.success", "outcomes.fail", "lines.issue"], "news": ["title", "body"],
	"kept": ["title", "body", "use"], "estate": ["title", "body", "mortgaged"], "night": ["title", "body"],
	"wheel": ["title"], "wheel_segment": ["title", "body"], "fortune_lot": ["verse", "gloss"],
	"cezi": ["char", "has", "none"], "dossier_page": ["title"], "dossier_fragment": ["body"],
	"goal": ["title", "done", "failed"], "pawn_ticket": ["body"], "guide_step": ["say", "bubble"],
	"rule_page": ["title", "body"], "item": [], "almanac_day": [],
	"relic": ["title", "body", "use"], "source": ["title", "body", "use"],
}


## X02 的演出形状。符号还没在这条基线上时跳过，合入后原样调用。
static func _stage_errors(card: Dictionary) -> PackedStringArray:
	var shapes := load("res://scripts/cards/api/dsl_shapes.gd") as GDScript
	if shapes == null or not shapes.has_method("check_stage"):
		return PackedStringArray()
	return shapes.call("check_stage", card)


## X02 的改名锚点表。没有这张表时按现有锚点表检查。
static func _renamed_anchors() -> Dictionary:
	var ids := load("res://scripts/cards/api/card_ids.gd") as GDScript
	if ids == null:
		return {}
	var renamed = ids.get_script_constant_map().get("ANCHORS_RENAMED", {})
	return renamed if typeof(renamed) == TYPE_DICTIONARY else {}


## {errors: PackedStringArray, notes: PackedStringArray, cards: int}；opts: {examples: bool, only: PackedStringArray, variant: String,
##   packs: PackedStringArray（剧情插件目录；不给时真数据查 res://packs，别的数据根不查）, enable_packs: PackedStringArray}
static func validate(root: String, mode: StringName, opts: Dictionary = {}) -> Dictionary:
	var run := _Run.new()
	run.root = root.trim_suffix("/")
	run.mode = mode
	run.examples = bool(opts.get("examples", false))
	run.only = PackedStringArray(opts.get("only", PackedStringArray()))
	if opts.has("packs"):
		run.pack_dirs = PackedStringArray(opts["packs"])
	elif run.root == CardDB.DEFAULT_ROOT and not run.examples:
		run.pack_dirs = PackedStringArray([Packs.RES_DIR])
	run.enable_packs = PackedStringArray(opts.get("enable_packs", PackedStringArray()))
	var raw_variant := str(opts.get("variant", "")).strip_edges().to_lower().replace("_", "-")
	if bool(opts.get("no_ai", false)) or raw_variant in ["no-ai", "no-disclosure", "human-only", "human"]:
		run.variant = "no-disclosure"
	elif raw_variant == "" and OS.has_feature("no_ai"):
		run.variant = "no-disclosure"
	else:
		run.variant = "ai-disclosure"
	run.go()
	return {"errors": run.errors, "notes": run.notes, "cards": run.card_count}


class _Run:
	extends RefCounted
	var root: String = ""
	var mode: StringName = &"default"
	var examples: bool = false
	var only := PackedStringArray()
	var variant: String = "ai-disclosure"
	var pack_dirs := PackedStringArray()
	var enable_packs := PackedStringArray()
	var errors := PackedStringArray()
	var notes := PackedStringArray()
	var card_count: int = 0
	var _cards: Dictionary = {}      # id → card（已还原整数）
	var _file: Dictionary = {}       # id → rel
	var _persons: Dictionary = {}
	var _eras: Array = []
	var _stage_days: Dictionary = {} # era → days
	var _ownership: Array = []       # [[regex, owner]]
	var _schemas: Dictionary = {}
	var _templates: Dictionary = {}
	var _ui_key_seen: Dictionary = {}
	var _ai_text: Dictionary = {}    # id → text_ai 条目（含合法 _provenance）
	var _cjk := RegEx.create_from_string(CardValidator.CJK_RE)
	var _id_re := RegEx.create_from_string(CardIds.ID_REGEX)
	var _slug_re := RegEx.create_from_string(CardIds.SLUG_REGEX)
	var _prov_re := RegEx.create_from_string(CardValidator.PROVENANCE_RE)
	var _ai_prov_re := RegEx.create_from_string(CardValidator.AI_PROVENANCE_RE)

	func go() -> void:
		_load_context()
		var docs: Dictionary = {}
		for rel in CardDB.card_files(root, examples):
			var doc = _read(rel)
			if typeof(doc) == TYPE_DICTIONARY:
				docs[rel] = doc
				if doc.has("persons") and typeof(doc["persons"]) != TYPE_DICTIONARY:
					_err(rel, "", "V03", "persons must be an object")
					doc["persons"] = {}
				if doc.has("cards") and typeof(doc["cards"]) != TYPE_ARRAY:
					_err(rel, "", "V03", "cards must be an array")
					doc["cards"] = []
				for pid in doc.get("persons", {}).keys():
					if _persons.has(str(pid)):
						_err(rel, str(pid), "V02", "duplicate registered person")
					_persons[str(pid)] = true
				for c in doc.get("cards", []):
					if typeof(c) == TYPE_DICTIONARY and typeof(c.get("id")) == TYPE_STRING:
						if not _cards.has(c["id"]):
							_cards[c["id"]] = c
							_file[c["id"]] = rel
		for rel in docs.keys():
			_check_card_file(rel, docs[rel])
		_check_rules()
		_check_key_files()
		_check_stage_files()
		if not examples:
			_check_text()
			_check_packs()
		CardValidator.Extra.new().check(self)

	# ---------------- 上下文 ----------------
	func _load_context() -> void:
		var stages = CardDB.read_json(root + "/rules/stages.json")
		if typeof(stages) == TYPE_DICTIONARY:
			for s in stages.get("stages", []):
				_eras.append(str(s.get("era", "")))
				_stage_days[str(s.get("era", ""))] = int(s.get("days", 30))
		var cast = CardDB.read_json(CardDB.CAST_PATH)
		if typeof(cast) == TYPE_DICTIONARY:
			for pid in cast.get("npcs", {}).keys():
				_persons[str(pid)] = true
		var own = CardDB.read_json(CardValidator.OWNERSHIP_PATH)
		if typeof(own) == TYPE_DICTIONARY:
			for task in own.get("paths", {}).keys():
				for pat in own["paths"][task]:
					_ownership.append([RegEx.create_from_string(_glob_re(str(pat))), str(task)])
		else:
			_note("", "", "V01", "docs/cards/ownership.json not found; owner check skipped")
		for f in CardDB.list_json(CardValidator.SCHEMA_DIR):
			var sc = CardDB.read_json(f)
			if typeof(sc) == TYPE_DICTIONARY and sc.has("properties"):
				_schemas[f.get_file().get_basename()] = sc
		var t = CardDB.read_json(CardValidator.TEMPLATES_PATH)
		if typeof(t) == TYPE_DICTIONARY:
			_templates = t.get("categories", {}).duplicate(true)
		var base := root + "/_examples" if examples else root
		var extra = CardDB.read_json(base + "/items/templates_extra.json")
		if typeof(extra) == TYPE_DICTIONARY:
			_templates.merge(extra.get("categories", {}), false)

	# ---------------- 牌文件 ----------------
	func _check_card_file(rel: String, raw: Dictionary) -> void:
		var doc: Dictionary = CardState.int_restore(raw)
		_check_meta(rel, doc)
		for k in doc.keys():
			if not (str(k) in ["_meta", "persons", "cards"] or str(k).begins_with("_")):
				_err(rel, "", "V03", "unknown top-level key '%s'" % k)
		for pid in doc.get("persons", {}).keys():
			var p = doc["persons"][pid]
			if typeof(p) != TYPE_DICTIONARY:
				_err(rel, str(pid), "V03", "person entry must be an object")
				continue
			if not _slug_re.search(str(pid)):
				_err(rel, str(pid), "V02", "person id must be [a-z0-9_]")
			_cjk_walk(rel, str(pid), p, "persons." + str(pid))
		var seen: Dictionary = {}
		for c in doc.get("cards", []):
			if typeof(c) != TYPE_DICTIONARY:
				_err(rel, "", "V03", "card is not an object")
				continue
			card_count += 1
			var id := str(c.get("id", ""))
			if seen.has(id) or (_file.get(id, rel) != rel):
				_err(rel, id, "V02", "duplicate id in this data set")
			seen[id] = true
			_check_card(rel, c)

	func _check_card(rel: String, c: Dictionary) -> void:
		var id := str(c.get("id", ""))
		var type := str(c.get("type", ""))
		# V02
		if not _id_re.search(id):
			_err(rel, id, "V02", "id does not match %s" % CardIds.ID_REGEX)
		elif CardIds.TYPE_PREFIX.has(type) and id.get_slice(".", 0) != str(CardIds.TYPE_PREFIX[type]):
			_err(rel, id, "V02", "id prefix must be '%s.' for type %s" % [CardIds.TYPE_PREFIX[type], type])
		# V03
		if not _schemas.has(type):
			_err(rel, id, "V03", "unknown type '%s'" % type)
			return
		var sc: Dictionary = _schemas[type]
		for req in sc.get("required", []):
			if str(req) == "brief" or str(req) == "_provenance":
				continue   # V06 查（发行模式下 brief 已被剥掉）
			if not c.has(req):
				_err(rel, id, "V03", "missing required field '%s'" % req)
		for k in c.keys():
			if not str(k).begins_with("_") and not CardValidator.TEXT_FIELDS.has(str(k)) and not (sc["properties"] as Dictionary).has(k):
				_err(rel, id, "V03", "unknown field '%s'" % k)
		var wrong_type := false
		for key in c.keys():
			if not sc["properties"].has(key):
				continue
			var expected := str(sc["properties"][key].get("type", ""))
			var actual := typeof(c[key])
			var accepted := {"string": [TYPE_STRING], "array": [TYPE_ARRAY], "object": [TYPE_DICTIONARY],
				"boolean": [TYPE_BOOL], "integer": [TYPE_INT], "number": [TYPE_INT, TYPE_FLOAT]}
			if accepted.has(expected) and not accepted[expected].has(actual):
				_err(rel, id, "V07" if expected in ["integer", "number"] else "V03", "%s must have type %s" % [key, expected])
				wrong_type = true
		if wrong_type:
			return
		# X02 还没合入时没有 check_stage；有了就用它做 V38–V41。
		for stage_error in CardValidator._stage_errors(c):
			var split := str(stage_error).find(":")
			var rule := str(stage_error).substr(0, split) if split >= 0 else "V38"
			var message := str(stage_error).substr(split + 1).strip_edges() if split >= 0 else str(stage_error)
			_err(rel, id, rule, message)
		_check_text_fields(rel, id, c, "")
		_cjk_walk(rel, id, c, "")
		# V06
		if mode != &"ship":
			if typeof(c.get("brief")) != TYPE_STRING or str(c.get("brief", "")).strip_edges() == "":
				_err(rel, id, "V06", "missing non-empty brief")
			var pv = c.get("_provenance")
			if typeof(pv) != TYPE_DICTIONARY or not (pv.has("by") and pv.has("task") and pv.has("date")):
				_err(rel, id, "V06", "missing _provenance {by, task, date}")
		# V07
		_float_walk(rel, id, c, "")
		if c.has("weight") and (not CardDslShapes.is_int(c["weight"]) or int(c["weight"]) < 0):
			_err(rel, id, "V07", "weight must be an integer >= 0")
		for k in ["expires_days", "term_days", "due_days", "deadline_days", "tier", "number", "order", "arc", "grade",
				"mortgage_value", "interest_pct_month", "incense_units", "priority", "max_shows", "seconds"]:
			if c.has(k) and not CardDslShapes.is_int(c[k]):
				_err(rel, id, "V07", "%s must be an integer" % k)
		# V08
		var eras = c.get("era")
		if typeof(eras) != TYPE_ARRAY or (eras as Array).is_empty():
			_err(rel, id, "V08", "era must be a non-empty array")
		else:
			for e in eras:
				if str(e) != "*" and not _eras.has(str(e)):
					_err(rel, id, "V08", "unknown era '%s'" % e)
		_check_effects_and_conds(rel, id, c)
		_check_gold(rel, id, c)
		_check_kept(rel, id, c)
		_check_slots(rel, id, c)
		_check_demand(rel, id, c)
		_check_almanac(rel, id, c)
		_check_item(rel, id, c)
		_check_schedule(rel, id, c)
		_check_minigame_field(rel, id, c)
		if type == "guide_step":
			_check_guide_step(rel, id, c)
		elif type == "rule_page":
			_check_rule_page(rel, id, c)

	# V04
	func _check_text_fields(rel: String, id: String, v, path: String) -> void:
		if typeof(v) == TYPE_DICTIONARY:
			for k in v.keys():
				var key := str(k)
				if key.begins_with("_"):
					continue
				if CardValidator.TEXT_FIELDS.has(key):
					_err(rel, id, "V04", "text field '%s' not allowed in skeleton (player text goes to data/cards/text/**)" % _p(path, key))
				_check_text_fields(rel, id, v[k], _p(path, key))
		elif typeof(v) == TYPE_ARRAY:
			for i in range(v.size()):
				_check_text_fields(rel, id, v[i], "%s[%d]" % [path, i])

	# V05：brief、_ 开头的键以外不许有中日韩字符
	func _cjk_walk(rel: String, id: String, v, path: String) -> void:
		match typeof(v):
			TYPE_STRING, TYPE_STRING_NAME:
				if _cjk.search(str(v)):
					_err(rel, id, "V05", "CJK characters outside brief at '%s'" % path)
			TYPE_DICTIONARY:
				for k in v.keys():
					var key := str(k)
					if key == "brief" or key.begins_with("_"):
						continue
					if _cjk.search(key):
						_err(rel, id, "V05", "CJK characters in key '%s'" % key)
					_cjk_walk(rel, id, v[k], _p(path, key))
			TYPE_ARRAY:
				for i in range(v.size()):
					_cjk_walk(rel, id, v[i], "%s[%d]" % [path, i])

	# V07：数据里不写小数
	func _float_walk(rel: String, id: String, v, path: String) -> void:
		match typeof(v):
			TYPE_FLOAT:
				_err(rel, id, "V07", "non-integer number at '%s' (use pct/permille/num-den)" % path)
			TYPE_DICTIONARY:
				for k in v.keys():
					if not str(k).begins_with("_"):
						_float_walk(rel, id, v[k], _p(path, str(k)))
			TYPE_ARRAY:
				for i in range(v.size()):
					_float_walk(rel, id, v[i], "%s[%d]" % [path, i])

	# V10（以及 need 的范围 V07）
	func _check_effects_and_conds(rel: String, id: String, c: Dictionary) -> void:
		var type := str(c.get("type", ""))
		var fx = c.get("effects")
		if type == "wheel_segment":
			if fx != null:
				_fx(rel, id, fx, "effects")
		elif fx != null:
			if typeof(fx) != TYPE_DICTIONARY:
				_err(rel, id, "V10", "effects must be {hook: [effects]}")
			else:
				for hook in fx.keys():
					if not CardIds.EFFECT_HOOKS.has(StringName(str(hook))):
						_err(rel, id, "V10", "unknown effect hook '%s'" % hook)
					_fx(rel, id, fx[hook], "effects." + str(hook))
		if c.has("conditions"):
			_cond(rel, id, c["conditions"], "conditions")
		if typeof(c.get("schedule")) == TYPE_DICTIONARY and c["schedule"].has("when"):
			_cond(rel, id, c["schedule"]["when"], "schedule.when")
		_check_check(rel, id, c.get("check"), "check")
		var choices = c.get("choices", [])
		if typeof(choices) != TYPE_ARRAY:
			_err(rel, id, "V03", "choices must be an array")
			choices = []
		var choice_ids: Dictionary = {}
		for i in range(choices.size()):
			var ch = choices[i]
			if typeof(ch) != TYPE_DICTIONARY:
				_err(rel, id, "V03", "choices[%d] is not an object" % i)
				continue
			var cid := str(ch.get("id", ""))
			if not _slug_re.search(cid) or choice_ids.has(cid):
				_err(rel, id, "V03", "choices[%d].id must be a unique [a-z0-9_] id" % i)
			choice_ids[cid] = true
			for k in ch.keys():
				if not (str(k) in ["id", "conditions", "cost", "effects", "check", "almanac", "brief"] or str(k).begins_with("_")):
					_err(rel, id, "V03", "choices[%d]: unknown field '%s'" % [i, k])
			if ch.has("effects"):
				_fx(rel, id, ch["effects"], "choices.%s.effects" % cid)
			if ch.has("conditions"):
				_cond(rel, id, ch["conditions"], "choices.%s.conditions" % cid)
			_check_check(rel, id, ch.get("check"), "choices.%s.check" % cid)
		for k in ["risk", "on_fail", "reward"]:
			if c.has(k):
				_fx(rel, id, c[k], k)
		for k in ["passives", "downsides"]:
			for row in c.get(k, []):
				if typeof(row) != TYPE_DICTIONARY or not CardValidator.CONTACT_HOOKS.has(str(row.get("hook", ""))):
					_err(rel, id, "V10", "%s: hook must be one of %s" % [k, ", ".join(CardValidator.CONTACT_HOOKS)])
				elif row.has("effects"):
					_fx(rel, id, row["effects"], k)
		for row in c.get("leave_when", []):
			if typeof(row) == TYPE_DICTIONARY:
				_cond(rel, id, row.get("cond", {}), "leave_when.cond")
				_fx(rel, id, row.get("effects", []), "leave_when.effects")
		for row in c.get("year_changes", []):
			if typeof(row) == TYPE_DICTIONARY:
				_fx(rel, id, row.get("effects", []), "year_changes.effects")
		if type == "goal" and c.has("done_when"):
			_cond(rel, id, c["done_when"], "done_when")

	func _check_check(rel: String, id: String, chk, path: String) -> void:
		if chk == null:
			return
		if typeof(chk) != TYPE_DICTIONARY:
			_err(rel, id, "V03", "%s must be an object" % path)
			return
		if not chk.has("need") or not CardDslShapes.is_int(chk["need"]) or int(chk["need"]) < 0 or int(chk["need"]) > 12:
			_err(rel, id, "V07", "%s.need must be an integer 0-12" % path)
		for k in ["on_success", "on_fail"]:
			if chk.has(k):
				_fx(rel, id, chk[k], "%s.%s" % [path, k])

	func _fx(rel: String, id: String, effects, path: String) -> void:
		for e in CardDslShapes.check_effects(effects):
			_err(rel, id, "V10", "%s%s" % [path, e])

	func _cond(rel: String, id: String, cond, path: String) -> void:
		var e := CardDslShapes.check_cond(cond)
		if e != "":
			_err(rel, id, "V10", "%s: %s" % [path, e])

	# V13
	func _check_gold(rel: String, id: String, c: Dictionary) -> void:
		if not bool(c.get("gold", false)):
			return
		if str(c.get("type", "")) != "person":
			_err(rel, id, "V13", "gold card must be type person")
		if str(c.get("story_node", "")) == "":
			_err(rel, id, "V13", "gold card needs story_node")
		if bool(c.get("keepable", false)):
			_err(rel, id, "V13", "gold card cannot be keepable")
		var ops: Array = []
		var fx = c.get("effects", {})
		if typeof(fx) == TYPE_DICTIONARY:
			for e in fx.get("on_expire", []):
				if typeof(e) == TYPE_DICTIONARY:
					ops.append(str(e.get("op", "")))
		if not (ops.has("story") and ops.has("dossier_gap")):
			_err(rel, id, "V13", "gold card on_expire needs story and dossier_gap")

	# V14
	func _check_kept(rel: String, id: String, c: Dictionary) -> void:
		if str(c.get("type", "")) == "kept" and c.has("keepable") and not bool(c["keepable"]):
			_err(rel, id, "V14", "kept card must be keepable")
		if bool(c.get("keepable", false)) and c.has("expires_days") and int(c["expires_days"]) < 0:
			_err(rel, id, "V14", "keepable card needs expires_days >= 0")

	# V15
	func _check_slots(rel: String, id: String, c: Dictionary) -> void:
		_slot_list(rel, id, c.get("slots", []), "slots")
		if c.has("check") and (c.get("slots", []) as Array).is_empty():
			_err(rel, id, "V15", "card has check but no slots")
		var i := 0
		for ch in c.get("choices", []):
			if typeof(ch) == TYPE_DICTIONARY and typeof(ch.get("check")) == TYPE_DICTIONARY:
				var sl = ch["check"].get("slots", [])
				if typeof(sl) != TYPE_ARRAY or sl.is_empty():
					_err(rel, id, "V15", "choices[%d].check needs slots" % i)
				else:
					_slot_list(rel, id, sl, "choices[%d].check.slots" % i)
			i += 1
		var res = c.get("resolve", {})
		if typeof(res) == TYPE_DICTIONARY and typeof(res.get("haggle")) == TYPE_DICTIONARY:
			_slot_list(rel, id, res["haggle"].get("slots", []), "resolve.haggle.slots")

	func _slot_list(rel: String, id: String, slots, path: String) -> void:
		if typeof(slots) != TYPE_ARRAY:
			_err(rel, id, "V15", "%s must be an array" % path)
			return
		var ids: Dictionary = {}
		for s in slots:
			if typeof(s) != TYPE_DICTIONARY:
				_err(rel, id, "V15", "%s: slot is not an object" % path)
				continue
			var sid := str(s.get("id", ""))
			if not _slug_re.search(sid) or ids.has(sid):
				_err(rel, id, "V15", "%s: slot id '%s' must be a unique [a-z0-9_] id" % [path, sid])
			ids[sid] = true
			for k in s.keys():
				if not (str(k) in ["id", "accepts", "attr", "tags", "money_per_coin", "item_match", "required", "max",
						"pay", "brief"] or str(k).begins_with("_")):
					_err(rel, id, "V15", "%s.%s: unknown slot field '%s'" % [path, sid, k])
			var acc = s.get("accepts", [])
			if typeof(acc) != TYPE_ARRAY or acc.is_empty():
				_err(rel, id, "V15", "%s.%s: accepts must be a non-empty array" % [path, sid])
				continue
			for a in acc:
				if not CardIds.SLOT_ACCEPTS.has(StringName(str(a))):
					_err(rel, id, "V15", "%s.%s: accepts '%s' unknown" % [path, sid, a])
			if (acc.has("self") or acc.has("contact")) and not CardIds.ATTRS.has(StringName(str(s.get("attr", "")))):
				_err(rel, id, "V15", "%s.%s: a slot that takes people needs attr (eye/tongue/pull/nerve)" % [path, sid])
			if s.has("money_per_coin") and (not CardDslShapes.is_int(s["money_per_coin"]) or int(s["money_per_coin"]) <= 0):
				_err(rel, id, "V15", "%s.%s: money_per_coin must be > 0" % [path, sid])

	# V17（形状部分）
	func _check_demand(rel: String, id: String, c: Dictionary) -> void:
		if str(c.get("type", "")) != "demand":
			return
		var kind := str(c.get("kind", ""))
		if not CardIds.DEMAND_KINDS.has(StringName(kind)):
			_err(rel, id, "V17", "demand kind must be money/goods/people/info")
		if not CardDslShapes.is_int(c.get("tier")) or int(c.get("tier", -1)) < 0 or int(c.get("tier", -1)) > 3:
			_err(rel, id, "V17", "demand tier must be 0-3")
		var res = c.get("resolve")
		if typeof(res) != TYPE_DICTIONARY or not res.has(kind):
			_err(rel, id, "V17", "resolve must contain '%s'" % kind)
			return
		for k in res.keys():
			if not (str(k) == kind or str(k) in ["haggle", "substitute", "fabricate"]):
				_err(rel, id, "V17", "resolve key '%s' does not fit kind %s" % [k, kind])
		if typeof(res.get("fabricate")) == TYPE_DICTIONARY:
			_fx(rel, id, res["fabricate"].get("on_fail", []), "resolve.fabricate.on_fail")

	# V20
	func _check_almanac(rel: String, id: String, c: Dictionary) -> void:
		var lists: Array = []
		for k in ["yi", "ji", "almanac"]:
			if c.has(k):
				lists.append([k, c[k]])
		for ch in c.get("choices", []):
			if typeof(ch) == TYPE_DICTIONARY and ch.has("almanac"):
				lists.append(["choices.almanac", ch["almanac"]])
		for pair in lists:
			if typeof(pair[1]) != TYPE_ARRAY:
				_err(rel, id, "V20", "%s must be an array" % pair[0])
				continue
			for a in pair[1]:
				if not CardIds.ALMANAC_ACTIONS.has(StringName(str(a))):
					_err(rel, id, "V20", "%s: unknown almanac action '%s'" % [pair[0], a])

	# V22
	func _check_item(rel: String, id: String, c: Dictionary) -> void:
		if str(c.get("type", "")) != "item":
			return
		var tpl := str(c.get("template", ""))
		if not _template_exists(tpl):
			_err(rel, id, "V22", "template '%s' not found" % tpl)
		var kinds = c.get("minigames", [])
		for k in kinds:
			if not CardIds.MINIGAMES.has(StringName(str(k))):
				_err(rel, id, "V22", "unknown minigame kind '%s'" % k)
			elif c.has(str(k)) and typeof(c[str(k)]) != TYPE_DICTIONARY:
				_err(rel, id, "V22", "%s params must be an object" % k)
			elif c.has(str(k)):
				for pk in c[str(k)].keys():
					var pv = c[str(k)][pk]
					var ok := typeof(pv) == TYPE_STRING or CardDslShapes.is_int(pv)
					if typeof(pv) == TYPE_ARRAY:
						ok = pv.size() == 2 and CardDslShapes.is_int(pv[0]) and CardDslShapes.is_int(pv[1])
					if not ok:
						_err(rel, id, "V22", "%s.%s must be an integer, [lo, hi] or a string" % [k, pk])

	func _template_exists(tpl: String) -> bool:
		var parts := tpl.split(".")
		if parts.size() != 2 or not _templates.has(parts[0]):
			return false
		for v in _templates[parts[0]].get("variants", []):
			if str(v.get("id", "")) == parts[1]:
				return true
		return false

	# V28
	func _check_schedule(rel: String, id: String, c: Dictionary) -> void:
		var sch = c.get("schedule")
		if typeof(sch) != TYPE_DICTIONARY or not sch.has("stage_day"):
			return
		var sd = sch["stage_day"]
		var hi := int(sd[1]) if typeof(sd) == TYPE_ARRAY and sd.size() == 2 else int(sd) if CardDslShapes.is_int(sd) else -1
		if hi < 1:
			_err(rel, id, "V28", "schedule.stage_day must be a day number or [from, to]")
			return
		for e in c.get("era", []):
			if _stage_days.has(str(e)) and hi > int(_stage_days[str(e)]):
				_err(rel, id, "V28", "schedule.stage_day %d is past the %s stage (%d days)" % [hi, e, _stage_days[str(e)]])

	# V33
	func _check_minigame_field(rel: String, id: String, c: Dictionary) -> void:
		if not c.has("minigame"):
			return
		var type := str(c.get("type", ""))
		var ok := type == "pawn_ticket"
		ok = ok or (type == "news" and str(c.get("kind", "")) in ["telegram", "letter"])
		ok = ok or (type == "person" and int(c.get("weight", 10)) == 0 and c.has("schedule"))
		if not ok:
			_err(rel, id, "V33", "minigame only on pawn_ticket, telegram/letter news, or weight-0 scheduled person")
		if not CardIds.MINIGAMES.has(StringName(str(c["minigame"]))):
			_err(rel, id, "V33", "unknown minigame '%s'" % c["minigame"])

	# V30–V32、V35
	func _check_guide_step(rel: String, id: String, c: Dictionary) -> void:
		var shape := CardDslShapes.check_guide_step(c)
		if shape != "":
			_err(rel, id, "V32", shape)
			return
		var renamed := CardValidator._renamed_anchors()
		for k in ["anchor", "anchor_fallback"]:
			var a := str(c.get(k, ""))
			if renamed.has(StringName(a)):
				var message := "%s '%s' was renamed to '%s'" % [k, a, renamed[StringName(a)]]
				if mode == &"default":
					_note(rel, id, "V30", message)
				else:
					_err(rel, id, "V30", message)
			elif a != "" and not CardIds.is_known_anchor(a):
				_err(rel, id, "V30", "%s '%s' is not in CardIds.ANCHORS" % [k, a])
		_check_teacher(rel, id, str(c.get("teacher", "")))
		var rp := str(c.get("rule_page", ""))
		if not (_cards.has(rp) and str(_cards[rp].get("type", "")) == "rule_page"):
			_err(rel, id, "V31", "rule_page '%s' does not exist" % rp)
		var trig: Dictionary = c.get("trigger", {})
		var tfirst := str(trig.get("first", ""))
		if tfirst != "" and not CardIds.FIRSTS.has(StringName(tfirst)):
			_err(rel, id, "V32", "trigger.first '%s' is not in CardIds.FIRSTS" % tfirst)
		for m in c.get("teaches", []):
			if not CardIds.FIRSTS.has(StringName(str(m))):
				_err(rel, id, "V32", "teaches '%s' is not in CardIds.FIRSTS" % m)
		if trig.has("panel") and not CardIds.PANELS.has(StringName(str(trig["panel"]))):
			_err(rel, id, "V32", "trigger.panel '%s' is not a panel kind" % trig["panel"])
		for tok in c.get("done_when", []):
			var e := _done_token_error(str(tok), tfirst)
			if e != "":
				_err(rel, id, "V32", e)
		for a in trig.get("after", []):
			if not (_cards.has(str(a)) and str(_cards[str(a)].get("type", "")) == "guide_step"):
				_err(rel, id, "V32", "trigger.after '%s' is not a guide step" % a)
		if _after_cycle(id, {}):
			_err(rel, id, "V32", "trigger.after forms a cycle")
		if trig.has("cond"):
			for op in CardDslShapes.cond_ops_used(trig["cond"]):
				if not (CardIds.GUIDE_COND_OPS.has(StringName(op)) or CardIds.GUIDE_COMBINATORS.has(StringName(op))):
					_err(rel, id, "V35", "trigger.cond uses hidden or unknown op '%s'" % op)
			_cond(rel, id, trig["cond"], "trigger.cond")

	func _done_token_error(tok: String, tfirst: String) -> String:
		if tok == "timeout":
			return ""
		var at := tok.find(":")
		if at < 0:
			return "done_when token '%s' must be cmd:/ui:/first:/panel: or timeout" % tok
		var kind := tok.substr(0, at + 1)
		var val := tok.substr(at + 1)
		match kind:
			"cmd:":
				return "" if CardIds.COMMANDS.has(StringName(val)) else "done_when '%s': unknown command" % tok
			"ui:":
				return "" if CardIds.UI_EVENTS.has(StringName(val)) else "done_when '%s': unknown ui event" % tok
			"first:":
				if not CardIds.FIRSTS.has(StringName(val)):
					return "done_when '%s': not in CardIds.FIRSTS" % tok
				return "done_when '%s' equals trigger.first" % tok if val == tfirst else ""
			"panel:":
				return "" if CardIds.PANELS.has(StringName(val)) else "done_when '%s': unknown panel kind" % tok
		return "done_when token '%s' must be cmd:/ui:/first:/panel: or timeout" % tok

	func _after_cycle(id: String, visiting: Dictionary) -> bool:
		if visiting.has(id):
			return true
		visiting[id] = true
		var c: Dictionary = _cards.get(id, {})
		var trig = c.get("trigger", {})
		if typeof(trig) == TYPE_DICTIONARY:
			for a in trig.get("after", []):
				if _cards.has(str(a)) and _after_cycle(str(a), visiting):
					return true
		visiting.erase(id)
		return false

	func _check_rule_page(rel: String, id: String, c: Dictionary) -> void:
		var shape := CardDslShapes.check_rule_page(c)
		if shape != "":
			_err(rel, id, "V32", shape)
			return
		for m in c.get("unlock_first", []):
			if not CardIds.FIRSTS.has(StringName(str(m))):
				_err(rel, id, "V32", "unlock_first '%s' is not in CardIds.FIRSTS" % m)
		_check_teacher(rel, id, str(c.get("teacher", "")))

	func _check_teacher(rel: String, id: String, teacher: String) -> void:
		if teacher == "" or CardIds.GUIDE_TEACHER_OBJECTS.has(teacher) or _persons.has(teacher):
			return
		_err(rel, id, "V31", "teacher '%s' is not a registered person, obj.notice/obj.almanac/obj.brother_ledger or \"\"" % teacher)

	# ---------------- 其他文件 ----------------
	func _check_meta(rel: String, doc: Dictionary) -> void:
		var meta = doc.get("_meta")
		if typeof(meta) != TYPE_DICTIONARY or not meta.has("owner") or not meta.has("schema"):
			_err(rel, "", "V01", "missing _meta.owner / _meta.schema")
			return
		var want := _owner_of("data/cards/" + rel)
		if rel.begins_with("tags/") or rel.begins_with("ui_keys/"):
			want = rel.get_file().get_basename()   # 每个任务默认拥有自己的标签文件、界面键文件
		var got := str(meta["owner"])
		if want != "" and got != want and not (want == "Claude" and got == "W0") and not _human_owner(want, got):
			_err(rel, "", "V01", "_meta.owner is '%s' but this path belongs to %s" % [got, want])

	func _human_owner(want: String, got: String) -> bool:
		return want == "human" and (got == "A" or got == "B")

	func _check_rules() -> void:
		var rules: Dictionary = {}
		for f in CardDB.list_json(root + "/rules"):
			var rel := "rules/" + f.get_file()
			var d = _read(rel)
			if typeof(d) != TYPE_DICTIONARY:
				continue
			_check_meta(rel, d)
			rules[f.get_file().get_basename()] = CardState.int_restore(d)
		for name in rules.keys():
			var d: Dictionary = rules[name]
			var rel := "rules/%s.json" % name
			_float_walk(rel, "", d, "")
			_cjk_walk(rel, "", d, "")
			if name == "balance_overrides":
				for target in d.keys():
					if str(target).begins_with("_"):
						continue
					if not rules.has(target):
						_err(rel, "", "V25", "overrides unknown rules file '%s'" % target)
					else:
						_override_walk(rel, rules[target], d[target], str(target))
				continue
			for k in CardValidator.RULE_KEYS.get(name, []):
				if not d.has(k):
					_err(rel, "", "V25", "missing required key '%s'" % k)
				else:
					var baseline = CardDB.read_json(CardDB.DEFAULT_ROOT + "/rules/" + str(name) + ".json")
					if typeof(baseline) == TYPE_DICTIONARY and baseline.has(k):
						if typeof(CardState.int_restore(baseline[k])) != typeof(d[k]):
							_err(rel, "", "V25", "rule key '%s' has wrong type" % k)
			if name == "demand_rules":
				for t in d.get("fail", {}).keys():
					_fx(rel, "", d["fail"][t], "fail." + str(t))

	func _override_walk(rel: String, base, over, path: String) -> void:
		if typeof(over) == TYPE_DICTIONARY:
			if typeof(base) != TYPE_DICTIONARY:
				_err(rel, "", "V25", "override '%s' changes the structure" % path)
				return
			for k in over.keys():
				if not base.has(k):
					_err(rel, "", "V25", "override '%s.%s' is not an existing key" % [path, k])
				else:
					_override_walk(rel, base[k], over[k], path + "." + str(k))
		elif typeof(over) != typeof(base):
			_err(rel, "", "V25", "override '%s' changes the type" % path)

	func _check_key_files() -> void:
		for f in CardDB.key_files(root, "tags", examples):
			var rel := f.substr(root.length() + 1)
			var d = _read(rel)
			if typeof(d) == TYPE_DICTIONARY:
				_check_meta(rel, d)
				for t in d.get("tags", {}).keys():
					if not _slug_re.search(str(t)):
						_err(rel, str(t), "V02", "tag must be [a-z0-9_]")
		for f in CardDB.key_files(root, "ui_keys", examples):
			var rel := f.substr(root.length() + 1)
			var d = _read(rel)
			if typeof(d) != TYPE_DICTIONARY:
				continue
			_check_meta(rel, d)
			var is_example := rel.begins_with("_examples/")
			var prefix := str(d.get("_meta", {}).get("owner", "")).to_lower() + "."
			for k in d.get("keys", {}).keys():
				var key := str(k)
				if _cjk.search(key):
					_err(rel, key, "V05", "CJK characters in key")
				if is_example:
					continue
				if not key.begins_with(prefix):
					_err(rel, key, "V24", "ui key must start with '%s'" % prefix)
				if _ui_key_seen.has(key):
					_err(rel, key, "V24", "ui key already defined in %s" % _ui_key_seen[key])
				_ui_key_seen[key] = rel
		var base := root + "/_examples" if examples else root
		for f in CardDB.list_json(base + "/minigames/obs"):
			var rel := f.substr(root.length() + 1)
			var d = _read(rel)
			if typeof(d) != TYPE_DICTIONARY:
				continue
			_check_meta(rel, d)
			var kind := str(d.get("_meta", {}).get("kind", f.get_file().get_basename()))
			for k in d.get("obs", {}).keys():
				var key := str(k)
				if not key.begins_with("obs.%s." % kind):
					_err(rel, key, "V23", "observation key must start with 'obs.%s.'" % kind)
				for w in CardIds.VERDICT_WORDS:
					if key.split(".").has(w) or key.contains("_" + w) or key.contains(w + "_"):
						_err(rel, key, "V23", "observation key contains verdict word '%s'" % w)
				var fid := str(d["obs"][k].get("fidelity", "")) if typeof(d["obs"][k]) == TYPE_DICTIONARY else ""
				if not CardIds.OBS_FIDELITY.has(StringName(fid)):
					_err(rel, key, "V23", "fidelity must be clear/partial/vague/any")
				# 10-25 appraisal redesign: hedge maps a lower clarity band to a softer key of the same catalog ("" = drop).
				var hedge = d["obs"][k].get("hedge", {}) if typeof(d["obs"][k]) == TYPE_DICTIONARY else {}
				if typeof(hedge) != TYPE_DICTIONARY:
					_err(rel, key, "V23", "hedge must be an object")
				else:
					for band in hedge.keys():
						if not str(band) in ["clear", "partial", "vague"]:
							_err(rel, key, "V23", "hedge band '%s' must be clear/partial/vague" % band)
						elif typeof(hedge[band]) != TYPE_STRING or (str(hedge[band]) != "" and not d["obs"].has(str(hedge[band]))):
							_err(rel, key, "V23", "hedge.%s must be \"\" or a key of this catalog" % band)
		for rel in ["art/manifest.json", "audio/music.json"]:
			if FileAccess.file_exists(root + "/" + rel):
				var d2 = _read(rel)
				if typeof(d2) == TYPE_DICTIONARY:
					_check_meta(rel, d2)
		for rel2 in [("_examples/" if examples else "") + "items/templates_extra.json",
				("_examples/" if examples else "") + "minigames/codebook.json"]:
			if FileAccess.file_exists(root + "/" + rel2):
				var d3 = _read(rel2)
				if typeof(d3) == TYPE_DICTIONARY:
					_check_meta(rel2, d3)
					if rel2.ends_with("templates_extra.json"):
						_check_templates_extra(rel2, d3)

	func _check_templates_extra(rel: String, d: Dictionary) -> void:
		for cat in d.get("categories", {}).keys():
			var c: Dictionary = d["categories"][cat]
			for k in c.keys():
				if typeof(c[k]) == TYPE_STRING and str(c[k]) != "":
					_err(rel, str(cat), "V05", "text field '%s' must be empty (text goes to items.text.json)" % k)
			for v in c.get("variants", []):
				for k2 in v.keys():
					if typeof(v[k2]) == TYPE_STRING and str(v[k2]) != "" and not (str(k2) in ["id", "sprite"]):
						_err(rel, "%s.%s" % [cat, v.get("id", "")], "V05", "text field '%s' must be empty" % k2)

	func _check_stage_files() -> void:
		var base := root + "/_examples" if examples else root
		if not DirAccess.dir_exists_absolute(base + "/era"):
			return
		for era in DirAccess.get_directories_at(base + "/era"):
			var rel := ("_examples/" if examples else "") + "era/%s/stage.json" % era
			if not FileAccess.file_exists(root + "/" + rel):
				continue
			var d = _read(rel)
			if typeof(d) != TYPE_DICTIONARY:
				continue
			_check_meta(rel, d)
			_cjk_walk(rel, "stage." + era, d, "")
			for k in ["era", "bg", "intro_paras", "main_goal"]:
				if not d.has(k):
					_err(rel, "stage." + era, "V03", "stage.json missing '%s'" % k)
			for k in d.keys():
				if not (str(k) in ["era", "bg", "intro_paras", "main_goal", "brief"] or str(k).begins_with("_")):
					_err(rel, "stage." + era, "V03", "stage.json unknown field '%s'" % k)

	# V26
	func _check_text() -> void:
		for f in CardDB.list_json_recursive(root + "/text"):
			var rel := f.substr(root.length() + 1)
			var d = _read(rel)
			if typeof(d) != TYPE_DICTIONARY:
				continue
			for k in d.keys():
				var key := str(k)
				if key.begins_with("_"):
					continue
				var e = d[k]
				if typeof(e) != TYPE_DICTIONARY:
					_err(rel, key, "V26", "entry must be an object")
					continue
				if not _prov_re.search(str(e.get("_provenance", ""))):
					_err(rel, key, "V26", "_provenance must match human:(A|B):YYYY-MM-DD")
				var allowed := _text_allowed(key)
				if allowed.is_empty() and not _text_key_known(key):
					_err(rel, key, "V26", "no such id / key for this text entry")
					continue
				for fk in e.keys():
					if str(fk).begins_with("_"):
						continue
					if not _text_field_ok(allowed, str(fk), e[fk]) or not _text_reference_fields_ok(key, str(fk), e[fk]):
						_err(rel, key, "V26", "field '%s' is not allowed for this entry" % fk)
		var ai_files := CardDB.list_json_recursive(root + "/text_ai")
		if mode == &"ship" and variant == "no-disclosure":
			for f in ai_files:
				var rel := f.substr(root.length() + 1)
				_err(rel, "", "V27", "text_ai must not be present in no-disclosure ship build")
			return
		for f in ai_files:
			var rel := f.substr(root.length() + 1)
			var d = _read(rel)
			if typeof(d) != TYPE_DICTIONARY:
				continue
			var meta = d.get("_meta", {})
			var raw_source = meta.get("_provenance", "") if typeof(meta) == TYPE_DICTIONARY else ""
			var file_prov := String(raw_source) if typeof(raw_source) == TYPE_STRING else ""
			var file_prov_ok := typeof(raw_source) == TYPE_STRING and _ai_prov_re.search(file_prov) != null
			if not file_prov_ok:
				_err(rel, "_meta", "V26", "_provenance must match ai:<tool>:<model>:YYYY-MM-DD:<id>")
			var keys: Array = d.keys()
			keys.sort()
			for k in keys:
				var key := str(k)
				if key.begins_with("_"):
					continue
				var e = d[k]
				if typeof(e) != TYPE_DICTIONARY:
					_err(rel, key, "V26", "entry must be an object")
					continue
				if e.has("_provenance"):
					var entry_prov = e.get("_provenance")
					if typeof(entry_prov) != TYPE_STRING or String(entry_prov) != file_prov or not file_prov_ok:
						_err(rel, key, "V26", "entry _provenance conflicts with file _meta._provenance")
				var allowed := _text_allowed(key)
				if allowed.is_empty() and not _text_key_known(key):
					_err(rel, key, "V26", "no such id / key for this text entry")
					continue
				for fk in e.keys():
					if str(fk).begins_with("_"):
						continue
					if not _text_field_ok(allowed, str(fk), e[fk]) or not _text_reference_fields_ok(key, str(fk), e[fk]):
						_err(rel, key, "V26", "field '%s' is not allowed for this entry" % fk)
				if not file_prov_ok:
					continue
				if _ai_text.has(key):
					_err(rel, key, "V26", "duplicate AI text key '%s'" % key)
					continue
				var copy: Dictionary = (e as Dictionary).duplicate(true)
				copy["_provenance"] = file_prov
				_ai_text[key] = copy

	# V26 剧情插件：清单（同 CardPacks.manifest_problems）、来源、键在骨架里、字段合法、没有 %、没有代码文件；
	# V27 不带声明的发行版里不许有 source 不是 human 的插件。插件正文怎么算进发行缺字见 validation_extra._require。
	func _check_packs() -> void:
		var seen: Dictionary = {}
		for dir in pack_dirs:
			if not DirAccess.dir_exists_absolute(dir):
				continue
			var folders := DirAccess.get_directories_at(dir)
			folders.sort()
			for folder in folders:
				_check_pack(str(dir).path_join(folder), folder, seen)

	func _pack_rel(path: String) -> String:
		return path.trim_prefix("res://")

	func _check_pack(base: String, folder: String, seen: Dictionary) -> void:
		var mrel := _pack_rel(base.path_join(Packs.MANIFEST))
		if not FileAccess.file_exists(base.path_join(Packs.MANIFEST)):
			_err(_pack_rel(base), folder, "V26", "story pack folder has no pack.json")
			return
		var m = CardDB.read_json(base.path_join(Packs.MANIFEST))
		if typeof(m) != TYPE_DICTIONARY:
			_err(mrel, folder, "V26", "pack.json cannot be parsed")
			return
		for problem in Packs.manifest_problems(m, folder):
			_err(mrel, folder, "V26", problem)
		if not m.has("compat"):
			_err(mrel, folder, "V26", "compat missing (use %s)" % Packs.FORMAT)
		if seen.has(folder):
			_err(mrel, folder, "V26", "duplicate story pack id (also in %s)" % seen[folder])
		seen[folder] = base
		var source := str(m.get("source", ""))
		if mode == &"ship" and variant == "no-disclosure" and source != "human":
			_err(mrel, folder, "V27", "AI story pack must not be present in no-disclosure ship build")
		if not (m.get("cards", []) as Array).is_empty() or str(m.get("art", "")) != "":
			var msg := "cards/art deltas are reserved and not loaded yet; only text counts"
			if mode == &"default":
				_note(mrel, folder, "V26", msg)
			else:
				_err(mrel, folder, "V26", msg)
		if str(m.get("base_db_hash", "")) != "":
			var db_hash := CardDB.load_all(root, {"only_examples": examples, "no_packs": true}).hash()
			if str(m["base_db_hash"]) != db_hash:
				_note(mrel, folder, "V26", "base_db_hash differs from this data set (%s); check that the keys still fit" % db_hash.substr(0, 12))
		for f in _pack_files(base):
			var ext := f.get_extension().to_lower()
			if ext in CardValidator.PACK_CODE_EXT:
				_err(_pack_rel(f), folder, "V26", "code or packed resources are not allowed in a story pack")
		var kind_re := RegEx.create_from_string(Packs.prov_re(source)) if source in Packs.SOURCES else null
		var keys_seen: Dictionary = {}
		for f in CardDB.list_json_recursive(base.path_join("text")):
			var rel := _pack_rel(f)
			var d = CardDB.read_json(f)
			if typeof(d) != TYPE_DICTIONARY:
				_err(rel, "", "V26", "pack text cannot be parsed")
				continue
			var meta = d.get("_meta", {})
			if typeof(meta) == TYPE_DICTIONARY and meta.has("_provenance") and (kind_re == null
					or typeof(meta["_provenance"]) != TYPE_STRING or kind_re.search(str(meta["_provenance"])) == null):
				_err(rel, "_meta", "V26", "_meta._provenance must match the pack source (%s)" % source)
			var keys: Array = d.keys()
			keys.sort()
			for k in keys:
				var key := str(k)
				if key.begins_with("_"):
					continue
				var e = d[k]
				if typeof(e) != TYPE_DICTIONARY:
					_err(rel, key, "V26", "entry must be an object")
					continue
				if e.has("_provenance") and (kind_re == null or typeof(e["_provenance"]) != TYPE_STRING
						or kind_re.search(str(e["_provenance"])) == null):
					_err(rel, key, "V26", "entry _provenance must match the pack source (%s)" % source)
				if keys_seen.has(key):
					_err(rel, key, "V26", "duplicate text key in this pack (also in %s)" % keys_seen[key])
				keys_seen[key] = rel
				var allowed := _text_allowed(key)
				if allowed.is_empty() and not _text_key_known(key):
					_err(rel, key, "V26", "no such id / key for this text entry")
					continue
				for fk in e.keys():
					if str(fk).begins_with("_"):
						continue
					if not _text_field_ok(allowed, str(fk), e[fk]) or not _text_reference_fields_ok(key, str(fk), e[fk]):
						_err(rel, key, "V26", "field '%s' is not allowed for this entry" % fk)
				if _has_percent(e):
					_err(rel, key, "V26", "pack text contains percent sign")

	func _pack_files(dir: String) -> PackedStringArray:
		var out := PackedStringArray()
		for f in DirAccess.get_files_at(dir):
			out.append(dir.path_join(f))
		for sub in DirAccess.get_directories_at(dir):
			out.append_array(_pack_files(dir.path_join(sub)))
		return out

	func _has_percent(v) -> bool:
		match typeof(v):
			TYPE_STRING:
				return str(v).contains("%")
			TYPE_DICTIONARY:
				for k in v.keys():
					if not str(k).begins_with("_") and _has_percent(v[k]):
						return true
			TYPE_ARRAY:
				for x in v:
					if _has_percent(x):
						return true
		return false

	func _text_allowed(key: String) -> Array:
		if _cards.has(key):
			return CardValidator.TEXT_REQUIRED.get(str(_cards[key].get("type", "")), [])
		return []

	func _text_key_known(key: String) -> bool:
		if _ui_key_seen.has(key) or _persons.has(key):
			return true
		if key.begins_with("stage."):
			return _eras.has(key.substr(6))
		if key.begins_with("cb.word."):
			var base := root + "/_examples" if examples else root
			var book = CardDB.read_json(base + "/minigames/codebook.json")
			if typeof(book) == TYPE_DICTIONARY:
				for entry in book.get("codes", {}).values():
					if typeof(entry) == TYPE_DICTIONARY and str(entry.get("key", "")) == key:
						return true
			return false
		if key.begins_with("item."):
			return _template_exists(key.substr(5))
		if key.begins_with("obs."):
			var base := root + "/_examples" if examples else root
			for file in CardDB.list_json(base + "/minigames/obs"):
				var catalog = CardDB.read_json(file)
				if typeof(catalog) == TYPE_DICTIONARY and catalog.get("obs", {}).has(key):
					return true
		return false

	func _text_field_ok(allowed: Array, field: String, value) -> bool:
		if allowed.is_empty():
			return true   # 界面键 / 观察键 / 人名 / 物品 / 开场 / 电码本：字段由各自格式定
		if field in ["lines", "outcomes", "choices", "slots"]:
			return typeof(value) == TYPE_DICTIONARY
		if field == "use":
			return true
		for a in allowed:
			if str(a) == field or str(a).begins_with(field + "."):
				return true
		return false

	func _text_reference_fields_ok(key: String, field: String, value) -> bool:
		if not _cards.has(key):
			return true
		if field not in ["choices", "slots"] or typeof(value) != TYPE_DICTIONARY:
			return true
		var ids: Array = []
		for row in CardDB._all_rows(_cards[key], field):
			ids.append(str(row.get("id", "")))
		for id in value.keys():
			if not ids.has(str(id)) or typeof(value[id]) != TYPE_STRING:
				return false
		return true

	# ---------------- 工具 ----------------
	func _read(rel: String) -> Variant:
		var d = CardDB.read_json(root + "/" + rel)
		if typeof(d) != TYPE_DICTIONARY:
			_err(rel, "", "V01", "cannot parse JSON")
			return null
		return d

	func _owner_of(path: String) -> String:
		for row in _ownership:
			if (row[0] as RegEx).search(path):
				return str(row[1])
		return ""

	func _glob_re(pat: String) -> String:
		var out := "^"
		var i := 0
		while i < pat.length():
			var ch := pat[i]
			if pat.substr(i, 3) == "**/":
				out += "(.*/)?"
				i += 3
				continue
			if pat.substr(i, 2) == "**":
				out += ".*"
				i += 2
				continue
			if ch == "*":
				out += "[^/]*"
			elif ch == "{":
				out += "("
			elif ch == "}":
				out += ")"
			elif ch == "," and out.count("(") > out.count(")"):
				out += "|"
			elif ".+?()[]^$|\\".contains(ch):
				out += "\\" + ch
			else:
				out += ch
			i += 1
		return out + "$"

	func _p(path: String, key: String) -> String:
		return key if path == "" else path + "." + key

	func _in_scope(rel: String) -> bool:
		if only.is_empty():
			return true
		var full := "data/cards/" + rel
		for pat in only:
			if full == pat or rel == pat or full.begins_with(pat.trim_suffix("/") + "/") or rel.begins_with(pat.trim_suffix("/") + "/") or RegEx.create_from_string(_glob_re(pat)).search(full) != null or RegEx.create_from_string(_glob_re(pat)).search(rel) != null:
				return true
		return false

	func _err(rel: String, id: String, rule: String, msg: String) -> void:
		if rel != "" and not _in_scope(rel):
			return
		errors.append("%s: %s: %s %s" % [rel if rel != "" else "-", id if id != "" else "-", rule, msg])

	func _note(rel: String, id: String, rule: String, msg: String) -> void:
		if rel != "" and not _in_scope(rel):
			return
		notes.append("%s: %s: %s %s" % [rel if rel != "" else "-", id if id != "" else "-", rule, msg])

