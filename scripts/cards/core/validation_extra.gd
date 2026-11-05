# 校验器的引用、完整性与发行规则；错误经主校验器输出以保留 only/mode 语义。
# 主人 G01；合同 §4.9 V09/V11/V12/V16–V21/V27/V29/V34/V36/V37。
extends RefCounted

const SYSTEM := ["ev.any.demand_return", "ev.any.wheel_go", "nw.any.family_word", "p.any.redeem", "pr.cell", "bf.wheel"]
const DEALT := ["person", "event", "fate", "big_fate", "demand", "life", "news", "kept", "night", "street", "prison", "pawn_ticket"]
var run: RefCounted
var db: CardDB
var references: Dictionary = {}
var nodes: Dictionary = {}


func check(p_run: RefCounted) -> void:
	run = p_run
	# 剧情插件按校验器的目录读（不挂 .pck）；不带声明版不读 source 为 ai 的插件（它们另报 V27）。
	db = CardDB.load_all(run.root, {"only_examples": run.examples, "ship": run.mode == &"ship",
		"packs": run.pack_dirs, "pck_dirs": PackedStringArray(), "enable_packs": run.enable_packs,
		"no_ai": run.variant == "no-disclosure"})
	_propagate_db_errors()
	for id in db.all_ids():
		var d := db.def(id)
		if d.has("story_node"):
			nodes[str(d["story_node"])] = true
	for id in db.all_ids():
		var d := db.def(id)
		if not _shape_safe(d):
			continue
		_tags(id, d)
		_endable(id, d)
		_stage(id, d)
		_refs(id, d, "")
		if str(d.get("art", "")) != "" and not db.art_manifest().get("art", {}).has(d["art"]):
			problem(db.file_of(id), id, "V12", "unknown art id '%s'" % d["art"])
	_card_reachability()
	_demands()
	_wheels()
	_lots()
	_dossier()
	_guide()
	_system()
	_stage_refs()
	if run.mode == &"ship":
		_ship()


func problem(rel: String, id: String, rule: String, message: String) -> void:
	if run.mode == &"default":
		run._note(rel, id, rule, message)
	else:
		run._err(rel, id, rule, message)


## V37 只认顶层检定或显式 on_expire；空数组是数据明确声明无需额外处罚。
func _endable(id: String, d: Dictionary) -> void:
	if str(d.get("type", "")) not in ["event", "fate", "street", "big_fate"] or id == "bf.wheel":
		return
	if CardViewModel.must_resolve(d) and not d.has("check") and not d.get("effects", {}).has("on_expire"):
		problem(db.file_of(id), id, "V37", "must-resolve card needs top-level check or explicit effects.on_expire")


## V39 的登记部分与 V42 的美术清单部分；本地形状/站位由 CardDslShapes.check_stage 管。
func _stage(id: String, d: Dictionary) -> void:
	if typeof(d.get("stage")) != TYPE_DICTIONARY:
		return
	var stage: Dictionary = d.stage
	var registered := db.persons()
	var art: Dictionary = db.art_manifest().get("art", {})
	for row in stage.get("cast", []):
		if typeof(row) != TYPE_DICTIONARY:
			continue
		var who := str(row.get("who", ""))
		var at := str(row.get("at", ""))
		if not registered.has(who) and who != "ruhua":
			problem(db.file_of(id), id, "V39", "stage cast person '%s' is not registered" % who)
		if at in ["customer", "companion"] and not art.has("portrait." + who):
			problem(db.file_of(id), id, "V42", "stage portrait art 'portrait.%s' is not declared" % who)
		if who.begins_with("ex_") and at in ["door", "door_l", "door_r", "street"] and not art.has("walk." + who):
			problem(db.file_of(id), id, "V42", "stage walk art 'walk.%s' is not declared" % who)
	for row in stage.get("props", []):
		if typeof(row) == TYPE_DICTIONARY:
			var prop_art := str(row.get("art", ""))
			if prop_art != "" and not art.has(prop_art):
				problem(db.file_of(id), id, "V42", "stage prop art '%s' is not declared" % prop_art)
	var set_name := str(stage.get("set", "counter"))
	if set_name != "counter" and not art.has("bg." + set_name):
		problem(db.file_of(id), id, "V42", "stage background art 'bg.%s' is not declared" % set_name)


func _tags(id: String, d: Dictionary) -> void:
	var tags := db.tags()
	for tag in d.get("tags", []):
		if not tags.has(str(tag)):
			problem(db.file_of(id), id, "V09", "undeclared tag '%s'" % tag)
	var type := str(d.get("type", ""))
	if type in ["event", "fate", "person", "life", "news"]:
		var has_omen := false
		for tag in d.get("tags", []):
			has_omen = has_omen or (str(tag).begins_with("omen_") and tags.has(str(tag)))
		if not has_omen:
			problem(db.file_of(id), id, "V34", "card needs a declared omen_* tag")
	if type in ["fortune_lot", "cezi"]:
		for tag in d.get("hint_tags", []) if type == "fortune_lot" else d.get("tags", []):
			if not str(tag).begins_with("omen_") or not tags.has(str(tag)):
				problem(db.file_of(id), id, "V34", "fortune tag must be a declared omen_*")


func _refs(id: String, value, path: String) -> void:
	if typeof(value) == TYPE_ARRAY:
		for row in value:
			_refs(id, row, path)
	elif typeof(value) == TYPE_DICTIONARY:
		for key in value.keys():
			if str(key).begins_with("_") or key == "brief":
				continue
			var v = value[key]
			var op := str(value.get("op", ""))
			if typeof(v) == TYPE_STRING:
				var target := str(v)
				# add_card 的 card、以及 keep 效果的 card/id，都算 V16 的效果引用（合同 §4.9）。
				if key in ["card", "def", "frag", "fragment", "page", "opens_wheel", "wheel", "main_goal", "year_after_of"] or (key == "id" and op in ["goal", "keep"]) or (op == "keep" and key == "card"):
					_ref(id, target, db.has(target), str(key))
				elif key in ["dossier_has", "dossier_page_complete"]:
					_ref(id, target, db.has(target) or db.has("dp." + target), str(key))
				elif key in ["has_contact", "person", "holder"] and target != "":
					_ref(id, target, db.persons().has(target), str(key))
				elif key in ["template", "item_template"]:
					_ref(id, target, run._template_exists(target), str(key))
				elif key == "node" or key == "story_node":
					_ref(id, target, nodes.has(target), str(key))
				elif (key == "key" and op == "notice") or (key == "reason" and target.contains(".")):
					var exists := _text_ref_exists(target) if target.contains("#") else db.ui_keys().has(target)
					_ref(id, target, exists, "text")
				elif target.contains("#"):
					_ref(id, target, _text_ref_exists(target), str(key))
			elif key == "fragments" and typeof(v) == TYPE_ARRAY:
				for target in v:
					_ref(id, str(target), db.has(str(target)), str(key))
			elif key == "story" and typeof(v) == TYPE_ARRAY and v.size() > 0:
				_ref(id, str(v[0]), nodes.has(str(v[0])), "story")
			_refs(id, v, path + "." + str(key))


func _ref(id: String, target: String, exists: bool, kind: String) -> void:
	if target in ["{person}", "{uid}", "{item}"]:
		return
	if exists:
		references[target] = true
	else:
		problem(db.file_of(id), id, "V11", "%s reference '%s' does not exist" % [kind, target])


func _text_ref_exists(ref: String) -> bool:
	var id := ref.get_slice("#", 0)
	var field := ref.get_slice("#", 1)
	if field == "":
		return false
	if id.begins_with("stage."):
		for i in range(db.rules("stages").get("stages", []).size()):
			if str(db.stage(i).get("era", "")) == id.substr(6):
				return true
	if not db.has(id):
		return false
	var d := db.def(id)
	if field.begins_with("choices.") or field.begins_with("slots."):
		var group := field.get_slice(".", 0)
		var sought := field.get_slice(".", 1)
		for row in CardDB._all_rows(d, group):
			if str(row.get("id", "")) == sought:
				return true
		return false
	return field.get_slice(".", 0) in ["title", "body", "use", "lines", "outcomes", "say", "bubble", "verse", "gloss", "char", "has", "none", "done", "failed", "mortgaged"]


func _card_reachability() -> void:
	for id in db.all_ids():
		var d := db.def(id)
		if str(d.get("type", "")) in DEALT and int(d.get("weight", 10)) == 0:
			# 可达 = 日程、效果引用（含 add_card / keep）、扇区或 §3.5 系统牌。
			# kept 仍在 DEALT 里：没人发的 weight 0 留牌照样是 V16，不按类型放行。
			if not d.has("schedule") and not references.has(id) and not SYSTEM.has(id):
				problem(db.file_of(id), id, "V16", "weight-zero card is unreachable")


func _demands() -> void:
	for era in run._eras:
		for kind in CardIds.DEMAND_KINDS:
			for tier in range(4):
				var found := false
				for id in db.ids_of(&"demand"):
					var d := db.def(id)
					found = found or (str(d.get("kind", "")) == str(kind) and int(d.get("tier", -1)) == tier and _in_era(d, str(era)))
				if not found:
					problem("demand/coverage.json", "", "V17", "missing demand %s/%s/t%d" % [era, kind, tier])


func _wheels() -> void:
	for wheel in db.ids_of(&"wheel"):
		for era in run._eras:
			if not _in_era(db.def(wheel), str(era)):
				continue
			var count := 0
			var valences: Array = []
			for id in db.ids_of(&"wheel_segment"):
				var d := db.def(id)
				if str(d.get("wheel", "")) != wheel or not _in_era(d, str(era)):
					continue
				count += 1
				valences.append(str(d.get("valence", "")))
				if int(d.get("arc", 0)) <= 0:
					problem(db.file_of(id), id, "V18", "wheel segment arc must be positive")
			if count < 3:
				problem(db.file_of(wheel), wheel, "V18", "wheel needs at least three segments for %s" % era)
			if wheel == "wh.big" and not (valences.has("good") and valences.has("neutral") and valences.has("bad")):
				problem(db.file_of(wheel), wheel, "V18", "big wheel needs good/neutral/bad for %s" % era)


func _lots() -> void:
	var generic: Array = []
	for id in db.ids_of(&"fortune_lot"):
		var d := db.def(id)
		var grade := int(d.get("grade", -1))
		if grade < 0 or grade > 4:
			problem(db.file_of(id), id, "V19", "lot grade must be 0-4")
		elif d.get("hint_tags", []).is_empty():
			generic.append(grade)
	for grade in range(5):
		if not generic.has(grade):
			problem("fortune/lots.json", "", "V19", "missing generic lot for grade %d" % grade)


func _dossier() -> void:
	var pages: Dictionary = {}
	var orders: Dictionary = {}
	for id in db.ids_of(&"dossier_page"):
		pages[str(db.def(id).get("person", ""))] = true
	for id in db.ids_of(&"dossier_fragment"):
		var d := db.def(id)
		var person := str(d.get("person", ""))
		if not pages.has(person):
			problem(db.file_of(id), id, "V21", "fragment's person has no dossier page")
		var slot := person + ":" + str(d.get("order", 0))
		if orders.has(slot):
			problem(db.file_of(id), id, "V21", "duplicate order within dossier page")
		orders[slot] = true
		var before := str(d.get("year_after_of", ""))
		if before != "":
			var old := db.def(before)
			if old.is_empty() or _earliest(old) >= _earliest(d):
				problem(db.file_of(id), id, "V21", "year_after_of needs an earlier fragment")


func _guide() -> void:
	var taught: Array = []
	var unlock: Array = []
	for id in db.ids_of(&"guide_step"):
		taught.append_array(db.def(id).get("teaches", []))
	for id in db.ids_of(&"rule_page"):
		unlock.append_array(db.def(id).get("unlock_first", []))
	for mech in CardIds.FIRSTS:
		if not taught.has(str(mech)) or not unlock.has(str(mech)):
			problem("guide/steps.json", str(mech), "V29", "mechanism needs a guide step and rule page")


func _system() -> void:
	for id in SYSTEM:
		if not db.has(id) or int(db.def(id).get("weight", 10)) != 0:
			problem(db.file_of(id) if db.has(id) else "common/system.json", id, "V36", "system card must exist with weight zero")
	for id in db.ids_of(&"big_fate"):
		if id == "bf.wheel":
			continue
		var d := db.def(id)
		var referenced := false
		for segment in db.ids_of(&"wheel_segment"):
			if JSON.stringify(db.def(segment).get("effects", [])).contains('"' + id + '"'):
				referenced = true
		if int(d.get("weight", 10)) != 0 or not referenced:
			problem(db.file_of(id), id, "V36", "big fate needs weight zero and a wheel-segment reference")


func _in_era(d: Dictionary, era: String) -> bool:
	return d.get("era", []).has("*") or d.get("era", []).has(era)


func _earliest(d: Dictionary) -> int:
	var earliest := 9999
	for era in d.get("era", []):
		if str(era).is_valid_int():
			earliest = mini(earliest, int(era))
	return earliest


# 发行检查只读覆盖层；每类字段和人写来源一起检查，ASCII 夹具也能证明通过路径。
func _ship() -> void:
	for id in db.all_ids():
		var d := db.def(id)
		var fields: Array = CardValidator.TEXT_REQUIRED.get(str(d.get("type", "")), []).duplicate()
		for choice in d.get("choices", []):
			fields.append("choices." + str(choice.get("id", "")))
		for slot in CardDB._all_rows(d, "slots"):
			fields.append("slots." + str(slot.get("id", "")))
		if d.has("check"):
			fields.append_array(["outcomes.success", "outcomes.fail"])
		fields.append_array(_stage_text_fields(d))
		if str(d.get("type", "")) in ["person", "event", "fate", "big_fate", "street", "life"] and not d.get("effects", {}).get("on_expire", []).is_empty():
			fields.append("outcomes.ignored")
		for field in fields:
			_require(id, str(field), db.file_of(id))
	for ref in references.keys():
		if str(ref).contains("#"):
			_require(str(ref).get_slice("#", 0), str(ref).get_slice("#", 1), "text/refs.text.json")
	for key in db.ui_keys().keys():
		_require(str(key), "t", "ui_keys/" + str(db.ui_keys()[key].get("owner", "")) + ".json")
	for key in ["w0.stage.enter", "w0.stage.at_door", "w0.stage.leave"]:
		_require(key, "t", "ui_keys/W0.json")
	for person in db.persons().keys():
		_require(str(person), "name", "text/persons.text.json")
	for kind in CardIds.MINIGAMES:
		for key in db.obs_catalog(kind).keys():
			_require(str(key), "t", "minigames/obs/%s.json" % kind)
	for id in db.ids_of(&"item"):
		var tpl := str(db.def(id).get("template", ""))
		_require("item." + tpl, "name", db.file_of(id))
		_require("item." + tpl, "desc", db.file_of(id))
	for index in range(db.rules("stages").get("stages", []).size()):
		var stage := db.stage(index)
		var era := str(stage.get("era", ""))
		for paragraph in range(1, int(stage.get("intro", {}).get("intro_paras", 0)) + 1):
			_require("stage." + era, "intro.p%d" % paragraph, "era/%s/stage.json" % era)
	var codebook = CardDB.read_json(db.set_base() + "/minigames/codebook.json")
	if typeof(codebook) == TYPE_DICTIONARY:
		for row in codebook.get("codes", {}).values():
			_require(str(row.get("key", "")), "word", "minigames/codebook.json")


func _stage_text_fields(d: Dictionary) -> PackedStringArray:
	var out := PackedStringArray()
	var stage = d.get("stage", {})
	if typeof(stage) != TYPE_DICTIONARY:
		return out
	for beat in stage.get("intro", []):
		if typeof(beat) == TYPE_DICTIONARY and typeof(beat.get("ref")) == TYPE_STRING:
			out.append(str(beat.ref))
	var after = stage.get("after", {})
	if typeof(after) == TYPE_DICTIONARY:
		for beats in after.values():
			if typeof(beats) != TYPE_ARRAY:
				continue
			for beat in beats:
				if typeof(beat) == TYPE_DICTIONARY and typeof(beat.get("ref")) == TYPE_STRING:
					out.append(str(beat.ref))
	return out


func _dig(entry: Dictionary, field: String):
	var cur = entry
	for part in field.split("."):
		if typeof(cur) != TYPE_DICTIONARY or not cur.has(part):
			return null
		cur = cur[part]
	return cur


func _propagate_db_errors() -> void:
	# 运行时 text_ai 的问题只是 warnings（不挡新局）；这里照旧报成 V26。剧情插件的问题由 _check_packs 自己报。
	var raws := db.errors()
	for w in db.warnings():
		if str(w).begins_with(run.root + "/text_ai/"):
			raws.append(w)
	for raw in raws:
		var err := str(raw)
		var sep := err.find(": ")
		var path := err.substr(0, sep) if sep >= 0 else ""
		var msg := err.substr(sep + 2) if sep >= 0 else err
		if path.begins_with(run.root + "/"):
			path = path.substr(run.root.length() + 1)
		if path.begins_with("text_ai/"):
			if run.mode == &"ship" and run.variant == "no-disclosure":
				continue
			run._err(path, "_meta", "V26", msg)
		elif path == "rules/balance_overrides.json":
			run._err(path, "", "V25", msg)
		elif msg.begins_with("duplicate "):
			run._err(path, "", "V02", msg)
		elif msg.contains("is not an object"):
			run._err(path, "", "V03", msg)
		else:
			run._err(path, "", "V01", msg)


func _require(id: String, field: String, rel: String) -> void:
	# 剧情插件在最上层：source human 的总算数；source ai 的只在带 AI 声明版算（不带声明版根本不读）。
	# 插件正文的 % 与来源由 _check_packs（V26）在各模式都查。
	var hit := db.pack_hit(id, field)
	if not hit.is_empty() and (str(hit["source"]) == "human" or run.variant == "ai-disclosure"):
		return
	var e := db.text_entry(id)
	var value = _dig(e, field)
	var has_human := typeof(value) == TYPE_STRING and str(value).strip_edges() != ""
	var human_prov_re := RegEx.create_from_string(CardValidator.PROVENANCE_RE)
	if has_human:
		if str(value).contains("%"):
			run._err(rel, id, "V27", "human text contains percent sign")
		if not human_prov_re.search(str(e.get("_provenance", ""))):
			run._err(rel, id, "V27", "text provenance must be human:A|B:date")
		return
	if not e.is_empty() and not human_prov_re.search(str(e.get("_provenance", ""))):
		run._err(rel, id, "V27", "text provenance must be human:A|B:date")
	if run.variant == "ai-disclosure":
		var ai_e: Dictionary = db.ai_text_entry(id)
		var ai_val = _dig(ai_e, field)
		var ai_prov_re := RegEx.create_from_string(CardValidator.AI_PROVENANCE_RE)
		if typeof(ai_val) == TYPE_STRING and str(ai_val).strip_edges() != "":
			if str(ai_val).contains("%"):
				run._err(rel, id, "V27", "AI text contains percent sign")
			if not ai_prov_re.search(str(ai_e.get("_provenance", ""))):
				run._err(rel, id, "V27", "AI text provenance must be ai:<tool>:<model>:YYYY-MM-DD:<id>")
			return
	run._err(rel, id, "V27", "missing human text '%s'" % field)
	if e.is_empty() and run.variant != "ai-disclosure":
		run._err(rel, id, "V27", "text provenance must be human:A|B:date")


# 主校验器已报出的基本类型错误不再参加引用/完整性检查，避免坏数组或对象导致运行时异常。
func _shape_safe(d: Dictionary) -> bool:
	var schema: Dictionary = run._schemas.get(str(d.get("type", "")), {})
	var accepted := {"string": [TYPE_STRING], "array": [TYPE_ARRAY], "object": [TYPE_DICTIONARY],
		"boolean": [TYPE_BOOL], "integer": [TYPE_INT], "number": [TYPE_INT, TYPE_FLOAT]}
	for key in d.keys():
		if not schema.get("properties", {}).has(key):
			continue
		var expected := str(schema["properties"][key].get("type", ""))
		if accepted.has(expected) and not accepted[expected].has(typeof(d[key])):
			return false
	return true


func _stage_refs() -> void:
	for index in range(db.rules("stages").get("stages", []).size()):
		var stage := db.stage(index)
		var intro: Dictionary = stage.get("intro", {})
		if intro.is_empty():
			continue
		var rel := ("_examples/" if run.examples else "") + "era/" + str(stage.get("era", "")) + "/stage.json"
		if not db.has(str(intro.get("main_goal", ""))):
			problem(rel, "", "V11", "stage main_goal does not exist")
		if not db.art_manifest().get("art", {}).has(str(intro.get("bg", ""))):
			problem(rel, "", "V12", "stage background art is not declared")
	for person in db.persons().keys():
		var portrait := str(db.persons()[person].get("portrait", ""))
		if portrait != "" and not db.art_manifest().get("art", {}).has(portrait):
			problem("era/common/passersby.json", str(person), "V12", "person portrait art is not declared")

