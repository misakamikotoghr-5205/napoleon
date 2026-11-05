# K06 数据自测：数量、id、来源、征兆、季节、付钱 short、史实措辞、悬空引用、大赌清单。
# 合同：docs/cards/CARDS_INTERFACES.md §4.7、§4.9；任务卡 docs/handoff_cards/K06_data-1940-world.md。
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const ROOT := "res://data/cards"
const VALENCE := ["good", "bad", "mixed"]
const CRISES := ["cash_short", "arrested", "heat_max", "street_long"]
const EVALS := ["month_close", "any_time"]

var _pay_bad := 0
var _key_bad := 0
var _word_bad := 0
var _float_bad := 0
var _refs := {}


func _initialize() -> void:
	var t := T.new(self, "K06_data")
	var common := _cards("era/common/life.json")
	var events := _cards("era/1940/events.json")
	var fates := _cards("era/1940/fate.json")
	var bigs := _cards("era/1940/big_fate.json")
	var lives := _cards("era/1940/life.json")
	var goals := _cards("era/1940/goals.json")
	var stage: Dictionary = _read("era/1940/stage.json")
	_check_counts(t, common, events, fates, bigs, lives, goals)
	var declared := _tag_set()
	var keys := _key_set()
	_check_group(t, common, "lf.any.", "life", "*", declared, keys)
	_check_group(t, events, "ev.1940.", "event", "1940", declared, keys)
	_check_group(t, fates, "fa.1940.", "fate", "1940", declared, keys)
	_check_group(t, bigs, "bf.1940.", "big_fate", "1940", declared, keys)
	_check_group(t, lives, "lf.1940.", "life", "1940", declared, keys)
	_check_group(t, goals, "gl.1940.", "goal", "1940", declared, keys)
	_check_nodes(t, events)
	_check_stage(t, stage, goals)
	_check_close(t, events, fates, bigs, common, lives, goals, stage)
	_check_wording()
	t.eq(_pay_bad, 0, "every pay has short")
	t.eq(_key_bad, 0, "reason and notice keys are registered k06.*")
	t.eq(_word_bad, 0, "brief quotes and regime names")
	t.eq(_float_bad, 0, "integers only")
	var db := CardDB.load_all(ROOT, {})
	t.eq(db.errors(), PackedStringArray(), "CardDB load")
	_report(t, db, [common, events, fates, bigs, lives, goals])
	t.finish()


func _check_counts(t, common: Array, events: Array, fates: Array, bigs: Array, lives: Array, goals: Array) -> void:
	t.ok(common.size() >= 10, "common life %d" % common.size())
	t.ok(events.size() >= 10, "1940 events %d" % events.size())
	t.ok(fates.size() >= 3 and fates.size() <= 5, "1940 fate %d" % fates.size())
	t.ok(bigs.size() >= 1 and bigs.size() <= 2, "1940 big fate %d" % bigs.size())
	t.ok(lives.size() >= 2 and lives.size() <= 3, "1940 life %d" % lives.size())
	var mains := 0
	var opts := 0
	for raw in goals:
		if bool((raw as Dictionary).get("main", false)):
			mains += 1
		else:
			opts += 1
	t.eq(mains, 1, "one main goal")
	t.ok(opts >= 4, "optional goals %d" % opts)


func _check_group(t, cards: Array, prefix: String, type: String, era: String, tags: Dictionary, keys: Dictionary) -> void:
	for raw in cards:
		var c: Dictionary = raw
		var id := str(c.get("id", ""))
		t.ok(id.begins_with(prefix) and str(c.get("type", "")) == type, "id/type " + id)
		t.ok(_era_is(c, era), "era " + id)
		t.ok(_prov_ok(c), "provenance " + id)
		t.ok(_brief_ok(c), "brief " + id)
		t.ok(_season_ok(c), "season " + id)
		t.ok(_schedule_ok(c), "schedule " + id)
		t.ok(not c.has("minigame"), "no minigame " + id)
		var tag_list: Array = c.get("tags", [])
		var missing := _missing_tag(tag_list, tags)
		t.ok(missing == "", "tag declared " + id)
		if type in ["event", "fate", "life"]:
			t.ok(_has_omen(tag_list), "omen " + id)
		if type == "life":
			t.ok(not c.has("schedule"), "life has no schedule " + id)
			t.ok(typeof(c.get("due_days")) == TYPE_INT and int(c["due_days"]) > 0, "due " + id)
			t.ok(typeof(c.get("waivable")) == TYPE_BOOL, "waivable " + id)
			t.ok(c.get("must_resolve") == false, "life must_resolve " + id)
			t.ok(_expire_ok(c), "on_expire " + id)
			t.ok(int(c.get("weight", 0)) > 0, "life weight " + id)
			if era == "1940":
				t.ok((c.get("season", []) as Array).has(0), "1940 life spring " + id)
		if type == "fate":
			t.ok(str(c.get("valence", "")) in VALENCE, "valence " + id)
		if type == "big_fate":
			t.eq(int(c.get("weight", -1)), 0, "big fate weight " + id)
			t.ok(str(c.get("valence", "")) in VALENCE, "big valence " + id)
			t.ok(_crisis_ok(c), "crisis " + id)
		if type == "goal":
			t.ok(str(c.get("eval", "")) in EVALS, "goal eval " + id)
		if type in ["event", "fate", "life"] and int(c.get("weight", 0)) == 0:
			t.ok(c.has("schedule"), "weight 0 scheduled " + id)
		_scan_effects(c, keys)
		_floats(c, id)


func _check_nodes(t, events: Array) -> void:
	var nodes := {}
	for raw in events:
		var c: Dictionary = raw
		var node := str(c.get("story_node", ""))
		if node != "":
			nodes[node] = c
	var got: Array = nodes.keys()
	got.sort()
	t.eq(got, ["s1940.new_official", "s1940.wang_regime"], "event story nodes")
	t.eq(int(nodes["s1940.wang_regime"]["schedule"]["stage_day"]), 30, "wang regime day")
	t.eq(int(nodes["s1940.wang_regime"]["weight"]), 0, "wang weight")
	t.ok(int(nodes["s1940.new_official"]["schedule"]["stage_day"]) <= 30, "official day")
	t.eq(int(nodes["s1940.new_official"]["weight"]), 0, "official weight")
	t.ok(_has_op(events, "demand_tier"), "demand_tier present")


func _check_stage(t, stage: Dictionary, goals: Array) -> void:
	t.eq(str(stage.get("era", "")), "1940", "stage era")
	t.eq(str(stage.get("bg", "")), "bg.stage.1940", "stage bg")
	t.ok(typeof(stage.get("intro_paras")) == TYPE_INT and int(stage["intro_paras"]) > 0, "intro_paras")
	t.ok(_prov_ok(stage), "stage provenance")
	t.ok(_brief_ok(stage), "stage brief")
	var main_id := str(stage.get("main_goal", ""))
	var ok := false
	for raw in goals:
		var g: Dictionary = raw
		if str(g.get("id", "")) == main_id and bool(g.get("main", false)):
			ok = true
	t.ok(ok, "stage main_goal")


func _check_wording() -> void:
	var paths := [
		"era/common/life.json", "era/1940/events.json", "era/1940/fate.json", "era/1940/big_fate.json",
		"era/1940/life.json", "era/1940/goals.json", "era/1940/stage.json", "tags/K06.json", "ui_keys/K06.json",
	]
	for rel in paths:
		var briefs: PackedStringArray = []
		_collect_briefs(_read(rel), briefs)
		for b in briefs:
			if _quotes_ok(b) != "" or _regime_ok(b) != "":
				_word_bad += 1


func _report(t, db: CardDB, groups: Array) -> void:
	var known_cards := {}
	for id in db.all_ids():
		known_cards[str(id)] = true
	var known_persons: Dictionary = db.persons()
	var known_nodes := {}
	for id2 in db.all_ids():
		var node := str(db.def(str(id2)).get("story_node", ""))
		if node != "":
			known_nodes[node] = true
	for group in groups:
		for raw in group:
			_walk_refs(raw, _refs)
	var dangling: Array = []
	for rid in _refs.keys():
		var kind := str(_refs[rid])
		var missing := false
		if kind == "card":
			missing = not known_cards.has(str(rid))
		elif kind == "person":
			missing = not known_persons.has(str(rid))
		elif kind == "story":
			missing = not known_nodes.has(str(rid))
		if missing:
			dangling.append(str(rid))
	dangling.sort()
	for rid2 in dangling:
		print("NOTE: dangling %s" % rid2)
	var big_ids: Array = db.ids_of(&"big_fate")
	var mine: Array = []
	for bid in big_ids:
		if str(db.def(str(bid)).get("_provenance", {}).get("task", "")) == "K06":
			mine.append(str(bid))
	mine.sort()
	for bid2 in mine:
		print("NOTE: bigfate_for_k10 %s" % bid2)
	t.ok(true, "notes emitted")


func _cards(rel: String) -> Array:
	var doc: Dictionary = _read(rel)
	var out: Array = []
	for raw in doc.get("cards", []):
		if typeof(raw) == TYPE_DICTIONARY:
			out.append(raw)
	return out


func _read(rel: String) -> Dictionary:
	var parsed = CardDB.read_json(ROOT + "/" + rel)
	var restored = CardState.int_restore(parsed)
	return restored if typeof(restored) == TYPE_DICTIONARY else {}


func _tag_set() -> Dictionary:
	var out := {}
	for f in CardDB.list_json(ROOT + "/tags"):
		var d = CardDB.read_json(f)
		if typeof(d) == TYPE_DICTIONARY:
			for k in d.get("tags", {}).keys():
				out[str(k)] = true
	return out


func _key_set() -> Dictionary:
	var out := {}
	for f in CardDB.list_json(ROOT + "/ui_keys"):
		var d = CardDB.read_json(f)
		if typeof(d) == TYPE_DICTIONARY:
			for k in d.get("keys", {}).keys():
				out[str(k)] = true
	return out


func _era_is(c: Dictionary, want: String) -> bool:
	var era = c.get("era", [])
	if typeof(era) != TYPE_ARRAY:
		return false
	if want == "*":
		return (era as Array).has("*")
	return era.size() == 1 and str(era[0]) == want


func _prov_ok(c: Dictionary) -> bool:
	var p = c.get("_provenance")
	if typeof(p) != TYPE_DICTIONARY:
		return false
	return str(p.get("by", "")) == "ai" and str(p.get("task", "")) == "K06" and str(p.get("date", "")) == "2026-10-13"


func _brief_ok(c: Dictionary) -> bool:
	return typeof(c.get("brief")) == TYPE_STRING and str(c.get("brief", "")).strip_edges() != ""


func _season_ok(c: Dictionary) -> bool:
	if str(c.get("type", "")) == "life":
		if typeof(c.get("season")) != TYPE_ARRAY or (c["season"] as Array).is_empty():
			return false
	if not c.has("season"):
		return true
	for n in c["season"]:
		if typeof(n) != TYPE_INT or int(n) < 0 or int(n) > 3:
			return false
	return true


func _schedule_ok(c: Dictionary) -> bool:
	if not c.has("schedule"):
		return true
	var sch = c["schedule"]
	if typeof(sch) != TYPE_DICTIONARY or not sch.has("stage_day"):
		return false
	var sd = sch["stage_day"]
	if typeof(sd) == TYPE_ARRAY:
		return sd.size() == 2 and int(sd[0]) >= 1 and int(sd[1]) <= 30
	return typeof(sd) == TYPE_INT and int(sd) >= 1 and int(sd) <= 30


func _expire_ok(c: Dictionary) -> bool:
	var fx = c.get("effects", {})
	if typeof(fx) != TYPE_DICTIONARY:
		return false
	var ex = fx.get("on_expire", [])
	return typeof(ex) == TYPE_ARRAY and not (ex as Array).is_empty()


func _crisis_ok(c: Dictionary) -> bool:
	var crisis = c.get("crisis", [])
	if typeof(crisis) != TYPE_ARRAY or (crisis as Array).is_empty():
		return false
	for x in crisis:
		if not str(x) in CRISES:
			return false
	return true


func _has_omen(tags: Array) -> bool:
	for x in tags:
		if str(x).begins_with("omen_"):
			return true
	return false


func _missing_tag(tags: Array, declared: Dictionary) -> String:
	for x in tags:
		if not declared.has(str(x)):
			return str(x)
	return ""


func _has_op(cards: Array, op: String) -> bool:
	var found := [false]
	for raw in cards:
		_each_effect(raw, op, found)
	return bool(found[0])


func _each_effect(v, op: String, found: Array) -> void:
	if typeof(v) == TYPE_DICTIONARY:
		if str(v.get("op", "")) == op:
			found[0] = true
		for k in v.keys():
			_each_effect(v[k], op, found)
	elif typeof(v) == TYPE_ARRAY:
		for x in v:
			_each_effect(x, op, found)


func _scan_effects(v, keys: Dictionary) -> void:
	if typeof(v) == TYPE_DICTIONARY:
		if v.has("op"):
			_one_effect(v, keys)
		for k in v.keys():
			_scan_effects(v[k], keys)
	elif typeof(v) == TYPE_ARRAY:
		for x in v:
			_scan_effects(x, keys)


func _one_effect(e: Dictionary, keys: Dictionary) -> void:
	var op := str(e.get("op", ""))
	if op == "pay" and str(e.get("short", "")) not in ["ladder", "partial", "fail"]:
		_pay_bad += 1
	if op in ["pay", "money", "item_lose"]:
		var reason := str(e.get("reason", ""))
		if not reason.begins_with("k06.") or not keys.has(reason):
			_key_bad += 1
	if op == "notice":
		var key := str(e.get("key", ""))
		if not key.begins_with("k06.") or not keys.has(key):
			_key_bad += 1


func _floats(v, path: String) -> void:
	# int_restore already ran; a leftover float is a non-integer.
	if typeof(v) == TYPE_FLOAT:
		_float_bad += 1
	elif typeof(v) == TYPE_DICTIONARY:
		for k in v.keys():
			_floats(v[k], path + "." + str(k))
	elif typeof(v) == TYPE_ARRAY:
		for i in range(v.size()):
			_floats(v[i], "%s[%d]" % [path, i])


func _collect_briefs(v, out: PackedStringArray) -> void:
	if typeof(v) == TYPE_DICTIONARY:
		for k in v.keys():
			if str(k) == "brief" and typeof(v[k]) == TYPE_STRING:
				out.append(str(v[k]))
			_collect_briefs(v[k], out)
	elif typeof(v) == TYPE_ARRAY:
		for x in v:
			_collect_briefs(x, out)


func _quotes_ok(s: String) -> String:
	var pairs := [["\u201c", "\u201d"], ["\u300c", "\u300d"], ["\u300e", "\u300f"]]
	for pair in pairs:
		var open := str(pair[0])
		var close := str(pair[1])
		var i := 0
		while true:
			var a := s.find(open, i)
			if a < 0:
				break
			var b := s.find(close, a + 1)
			if b < 0:
				return "unclosed"
			var inner := s.substr(a + 1, b - a - 1)
			if inner.length() > 12:
				return "long"
			if inner.contains("\u3002") or inner.contains("\uff01") or inner.contains("\uff1f"):
				return "punct"
			i = b + 1
	return ""


func _regime_ok(s: String) -> String:
	var stems := [
		["\u56fd\u6c11\u653f\u5e9c", "\u6c6a\u4f2a"],
		["\u7ef4\u65b0\u653f\u5e9c", "\u4f2a"],
		["\u7ef4\u6301\u4f1a", "\u4f2a"],
		["\u4e2d\u50a8\u5238", "\u4f2a"],
		["\u53bf\u653f\u5e9c", "\u4f2a"],
		["\u653f\u6743", "\u4f2a"],
	]
	for row in stems:
		var stem := str(row[0])
		var prefix := str(row[1])
		var at := 0
		while true:
			var i := s.find(stem, at)
			if i < 0:
				break
			var got := ""
			if i >= prefix.length():
				got = s.substr(i - prefix.length(), prefix.length())
			if got != prefix:
				return "bad"
			at = i + stem.length()
	return ""


func _walk_refs(v, refs: Dictionary) -> void:
	if typeof(v) == TYPE_DICTIONARY:
		if v.has("op"):
			_effect_ref(v, refs)
		elif v.size() == 1:
			_cond_ref(v, refs)
		for k in v.keys():
			_walk_refs(v[k], refs)
	elif typeof(v) == TYPE_ARRAY:
		for x in v:
			_walk_refs(x, refs)


func _effect_ref(e: Dictionary, refs: Dictionary) -> void:
	match str(e.get("op", "")):
		"add_card":
			_add_ref(refs, e.get("card", ""), "card")
		"goal":
			_add_ref(refs, e.get("id", ""), "card")
		"dossier", "dossier_gap":
			_add_ref(refs, e.get("frag", ""), "card")
		"person_state", "contact_gain", "contact_lose":
			_add_ref(refs, e.get("person", ""), "person")
		"attr":
			_add_ref(refs, e.get("who", ""), "person")
		"story":
			_add_ref(refs, e.get("node", ""), "story")


func _cond_ref(c: Dictionary, refs: Dictionary) -> void:
	var op := str(c.keys()[0])
	var val = c[c.keys()[0]]
	if op in ["estate_status", "goal_status"] and typeof(val) == TYPE_ARRAY and not (val as Array).is_empty():
		_add_ref(refs, val[0], "card")
	elif op == "story" and typeof(val) == TYPE_ARRAY and not (val as Array).is_empty():
		_add_ref(refs, val[0], "story")
	elif op == "has_contact":
		_add_ref(refs, val, "person")
	elif op == "person_state" and typeof(val) == TYPE_ARRAY and not (val as Array).is_empty():
		_add_ref(refs, val[0], "person")


func _add_ref(refs: Dictionary, id, kind: String) -> void:
	var s := str(id)
	if s != "":
		refs[s] = kind


# 打烊：没理会。无顶层 check 的事件/命运/大赌必须有 on_expire，且等于最消极的那个选项
# （含 pay 的选项不算，没理会不会付钱；story 走向记成 ignored）。有空后果的选项则 on_expire 为 []。
# 有顶层 check 的不写，没理会当没过。机会牌 must_resolve false。不写 bf.wheel，不写演出块 stage。
# 生活牌 on_expire 等于「挨过去」（endure）。
func _check_close(t, events: Array, fates: Array, bigs: Array, common: Array, lives: Array, goals: Array, stage: Dictionary) -> void:
	for raw in events:
		_check_ignored(t, raw)
	for raw2 in fates:
		_check_ignored(t, raw2)
	for raw3 in bigs:
		_check_ignored(t, raw3)
	for raw4 in common:
		_check_life_endure(t, raw4)
	for raw5 in lives:
		_check_life_endure(t, raw5)
	for raw6 in goals:
		t.eq(_stage_at(raw6, str((raw6 as Dictionary).get("id", "goal"))), "", "no stage")
	t.eq(_stage_at(stage, "stage.json"), "", "no stage")


func _check_ignored(t, raw) -> void:
	var c: Dictionary = raw
	var id := str(c.get("id", ""))
	t.ok(id != "bf.wheel", "do not author bf.wheel")
	t.eq(_stage_at(c, id), "", "no stage " + id)
	var brief := str(c.get("brief", ""))
	t.eq(brief.count("没理会"), 1, "one 没理会 sentence " + id)
	if _is_opportunity(c):
		t.eq(bool(c.get("must_resolve", true)), false, "opportunity must_resolve " + id)
		if _has_expire_key(c):
			t.eq(_expire_of(c), [], "opportunity has no extra expire " + id)
		return
	if _top_check(c):
		t.ok(not _has_expire_key(c), "check omits on_expire " + id)
		return
	t.ok(_has_expire_key(c), "on_expire key " + id)
	var ex = _expire_of(c)
	t.ok(typeof(ex) == TYPE_ARRAY, "on_expire array " + id)
	t.ok(not _has_op_tree(ex, "pay"), "on_expire does not pay " + id)
	var node := str(c.get("story_node", ""))
	if node != "":
		t.ok(_story_ignored(ex, node), "story ignored " + id)
	if _has_empty_choice(c):
		t.eq(ex, [], "no-consequence choice " + id)
		return
	var pick: Array = _most_negative(c)
	t.ok(bool(pick[0]), "negative choice " + id)
	if bool(pick[0]):
		t.eq(_norm_story(ex), _norm_story(pick[1]), "on_expire is most negative " + id)


func _check_life_endure(t, raw) -> void:
	var c: Dictionary = raw
	var id := str(c.get("id", ""))
	t.eq(_stage_at(c, id), "", "no stage " + id)
	t.eq(c.get("must_resolve"), false, "life must_resolve " + id)
	var endure = null
	for ch in c.get("choices", []):
		if typeof(ch) == TYPE_DICTIONARY and str(ch.get("id", "")) == "endure":
			endure = ch.get("effects", [])
	t.ok(endure != null, "endure choice " + id)
	if endure != null:
		t.eq(_expire_of(c), endure, "life on_expire is endure " + id)


func _is_opportunity(c: Dictionary) -> bool:
	var id := str(c.get("id", ""))
	return c.has("opens_fortune") or c.has("opens_wheel") or id == "ev.any.wheel_go"


func _top_check(c: Dictionary) -> bool:
	return typeof(c.get("check")) == TYPE_DICTIONARY


func _has_expire_key(c: Dictionary) -> bool:
	var fx = c.get("effects", null)
	return typeof(fx) == TYPE_DICTIONARY and (fx as Dictionary).has("on_expire")


func _expire_of(c: Dictionary):
	if not _has_expire_key(c):
		return null
	return c["effects"]["on_expire"]


func _has_empty_choice(c: Dictionary) -> bool:
	for ch in c.get("choices", []):
		if typeof(ch) != TYPE_DICTIONARY:
			continue
		var fx = ch.get("effects", null)
		if typeof(fx) == TYPE_ARRAY and (fx as Array).is_empty():
			return true
	return false


func _most_negative(c: Dictionary) -> Array:
	var found := false
	var best_score := 0
	var best: Array = []
	for ch in c.get("choices", []):
		if typeof(ch) != TYPE_DICTIONARY:
			continue
		var fx = ch.get("effects", null)
		if typeof(fx) != TYPE_ARRAY:
			continue
		if _has_op_tree(fx, "pay"):
			continue
		var sc := _neg_score(fx)
		if not found or sc >= best_score:
			found = true
			best_score = sc
			best = fx
	return [found, best]


func _neg_score(effects) -> int:
	if typeof(effects) != TYPE_ARRAY:
		return 0
	var s := 0
	for raw in effects:
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var e: Dictionary = raw
		var op := str(e.get("op", ""))
		if op == "if":
			var a := _neg_score(e.get("then", []))
			var b := _neg_score(e.get("else", []))
			s += a if a > b else b
		elif op == "heat":
			s += 10 * int(e.get("tier", 0)) + int(e.get("delta", 0))
		elif op == "rep":
			s += -8 * int(e.get("tier", 0)) - int(e.get("delta", 0))
		elif op == "shop_closed":
			s += 6 * int(e.get("days", 0))
		elif op == "conscience":
			s += -3 * int(e.get("delta", 0))
		elif op == "item_lose":
			s += 7 * int(e.get("n", 1))
		elif op == "item_gain":
			s -= 5 * int(e.get("n", 1))
		elif op == "person_state":
			if str(e.get("state", "")) != "ok":
				s += 7
		elif op == "attr":
			s += -3 * int(e.get("delta", 0))
		elif op == "money":
			s -= int(float(int(e.get("delta", 0))) / 4.0)
		elif op == "demand_tier":
			s += 5 * int(e.get("delta", 0))
		elif op == "kept_risk":
			s += 6
	return s


func _has_op_tree(v, op: String) -> bool:
	if typeof(v) == TYPE_DICTIONARY:
		if str(v.get("op", "")) == op:
			return true
		for k in v.keys():
			if _has_op_tree(v[k], op):
				return true
	elif typeof(v) == TYPE_ARRAY:
		for x in v:
			if _has_op_tree(x, op):
				return true
	return false


func _story_ignored(effects, node: String) -> bool:
	if typeof(effects) != TYPE_ARRAY:
		return false
	for raw in effects:
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		if str(raw.get("op", "")) == "story" and str(raw.get("node", "")) == node and str(raw.get("outcome", "")) == "ignored":
			return true
	return false


func _norm_story(v):
	if typeof(v) == TYPE_DICTIONARY:
		var out := {}
		for k in v.keys():
			out[k] = _norm_story(v[k])
		if str(out.get("op", "")) == "story":
			out["outcome"] = "ignored"
		return out
	if typeof(v) == TYPE_ARRAY:
		var arr: Array = []
		for x in v:
			arr.append(_norm_story(x))
		return arr
	return v


func _stage_at(v, path: String) -> String:
	if typeof(v) == TYPE_DICTIONARY:
		for k in v.keys():
			if str(k) == "stage":
				return path + ".stage"
			var sub := _stage_at(v[k], path + "." + str(k))
			if sub != "":
				return sub
	elif typeof(v) == TYPE_ARRAY:
		for i in range(v.size()):
			var sub2 := _stage_at(v[i], "%s[%d]" % [path, i])
			if sub2 != "":
				return sub2
	return ""

