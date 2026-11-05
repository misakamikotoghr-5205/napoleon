# K04 data: counts, shape, provenance, tags, ui keys, briefs, dangling ids.
# Contract: docs/handoff_cards/K04_data-1939-world.md (test_data checklist).
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")

const FILES := [
	"era/common/fate.json",
	"era/1939/events.json",
	"era/1939/fate.json",
	"era/1939/big_fate.json",
	"era/1939/life.json",
	"era/1939/goals.json",
]
const OMEN_TYPES := ["event", "fate", "life"]
const TEXT_KEYS := ["text", "title", "body", "label", "name", "lines", "desc"]
const VALENCES := ["good", "bad", "mixed"]
const WEI := "\u4f2a"
const NEEDLES := ["\u53bf\u653f\u5e9c", "\u533a\u516c\u6240", "\u7ef4\u6301\u4f1a"]
const QUOTE_PAIRS := [
	["\"", "\""],
	["\u201c", "\u201d"],
	["\u300c", "\u300d"],
	["\u300e", "\u300f"],
	["\u2018", "\u2019"],
]
const STOPS := ["\u3002", "\uff01", "\uff1f"]


func _initialize() -> void:
	var t := T.new(self, "K04_data")
	var db := CardDB.load_all()
	t.eq(db.errors(), PackedStringArray(), "card db loads")
	var by_file := {}
	for id in db.all_ids():
		var f := db.file_of(id)
		if not FILES.has(f):
			continue
		if not by_file.has(f):
			by_file[f] = []
		(by_file[f] as Array).append(id)
	var common: Array = by_file.get("era/common/fate.json", [])
	var events: Array = by_file.get("era/1939/events.json", [])
	var fates: Array = by_file.get("era/1939/fate.json", [])
	var bigs: Array = by_file.get("era/1939/big_fate.json", [])
	var lives: Array = by_file.get("era/1939/life.json", [])
	var goals: Array = by_file.get("era/1939/goals.json", [])
	t.ok(absi(common.size() - 18) <= 2, "common fate count %d" % common.size())
	t.ok(events.size() >= 10, "1939 events %d" % events.size())
	t.ok(absi(fates.size() - 4) <= 1, "1939 fate count %d" % fates.size())
	t.ok(bigs.size() >= 1 and bigs.size() <= 2, "1939 big fate %d" % bigs.size())
	t.ok(lives.size() >= 3 and lives.size() <= 4, "1939 life %d" % lives.size())
	var mains := 0
	var optional := 0
	var valence_n := {"good": 0, "bad": 0, "mixed": 0}
	var choice_cards := 0
	var slot_cards := 0
	var story_nodes := {}
	var defined_stories := {}
	for id in db.all_ids():
		var sn := str(db.def(id).get("story_node", ""))
		if sn != "":
			defined_stories[sn] = true
	for id in common:
		var c := db.def(id)
		_check_card(t, db, id, c, true)
		var v := str(c.get("valence", ""))
		t.ok(VALENCES.has(v), "%s valence" % id)
		if valence_n.has(v):
			valence_n[v] = int(valence_n[v]) + 1
		var ch: Array = c.get("choices", [])
		t.ok(ch.size() >= 2 and ch.size() <= 3, "%s choice count" % id)
		if not ch.is_empty():
			choice_cards += 1
		if _has_slots(ch):
			slot_cards += 1
		t.ok(_era_has(c, "*"), "%s era *" % id)
	t.eq(int(valence_n["good"]), 5, "common good")
	t.eq(int(valence_n["bad"]), 7, "common bad")
	t.eq(int(valence_n["mixed"]), 6, "common mixed")
	t.ok(choice_cards >= 4, "common fates with choices")
	t.ok(slot_cards >= 2, "common fates with check slots")
	for id in events + fates + bigs + lives + goals:
		var c2 := db.def(id)
		_check_card(t, db, id, c2, false)
		t.ok(_era_only(c2, "1939"), "%s era 1939" % id)
		var sn2 := str(c2.get("story_node", ""))
		if sn2 != "":
			story_nodes[sn2] = id
	for id in events:
		var ev := db.def(id)
		if int(ev.get("weight", 10)) == 0:
			t.ok(typeof(ev.get("schedule")) == TYPE_DICTIONARY, "%s weight 0 needs schedule" % id)
		_check_day(t, ev)
	t.eq(story_nodes.size(), 2, "only two story nodes")
	t.ok(story_nodes.has("s1939.gate_check"), "gate story node")
	t.ok(story_nodes.has("s1939.wu_price"), "wu story node")
	t.eq(str(story_nodes.get("s1939.gate_check", "")), "ev.1939.gate_check", "gate card")
	t.eq(str(story_nodes.get("s1939.wu_price", "")), "ev.1939.wu_price", "wu card")
	for id in fates:
		t.ok(VALENCES.has(str(db.def(id).get("valence", ""))), "%s valence" % id)
	for id in bigs:
		var bf := db.def(id)
		t.eq(int(bf.get("weight", -1)), 0, "%s weight" % id)
		t.ok(VALENCES.has(str(bf.get("valence", ""))), "%s valence" % id)
		var crisis = bf.get("crisis", [])
		t.ok(typeof(crisis) == TYPE_ARRAY and not (crisis as Array).is_empty(), "%s crisis" % id)
	for id in lives:
		var lf := db.def(id)
		var season = lf.get("season", [])
		t.ok(typeof(season) == TYPE_ARRAY and (season as Array).has(3), "%s winter" % id)
		t.ok(int(lf.get("due_days", 0)) > 0, "%s due_days" % id)
		t.ok(typeof(lf.get("waivable")) == TYPE_BOOL, "%s waivable" % id)
	for id in goals:
		var g := db.def(id)
		if bool(g.get("main", false)):
			mains += 1
			t.eq(str(g.get("eval", "")), "month_close", "main eval")
		else:
			optional += 1
			t.ok(int(g.get("weight", 0)) > 0, "%s optional weight" % id)
		t.ok(typeof(g.get("done_when")) == TYPE_DICTIONARY, "%s done_when" % id)
	t.eq(mains, 1, "one main goal")
	t.ok(optional >= 4, "optional goals %d" % optional)
	var intro: Dictionary = db.stage(1).get("intro", {})
	t.eq(str(intro.get("main_goal", "")), "gl.1939.clear_books", "stage main goal")
	t.eq(str(intro.get("bg", "")), "bg.stage.1939", "stage bg")
	t.eq(bool(db.def("gl.1939.clear_books").get("main", false)), true, "stage goal is main")
	_check_briefs(t)
	var dangling := _dangling(db, defined_stories)
	var unexpected := PackedStringArray()
	var ids := dangling.keys()
	ids.sort()
	for d in ids:
		print("NOTE: dangling %s" % d)
		if not _expected_dangle(str(d)):
			unexpected.append(str(d))
	t.ok(unexpected.is_empty(), "unexpected dangling: %s" % ", ".join(unexpected))
	bigs.sort()
	for id in bigs:
		print("NOTE: bigfate_for_k10 %s" % id)
	t.finish()


func _check_card(t, db: CardDB, id: String, c: Dictionary, common: bool) -> void:
	var type := str(c.get("type", ""))
	var prefix := str(CardIds.TYPE_PREFIX.get(type, ""))
	t.ok(prefix != "" and id.begins_with(prefix + "."), "%s prefix" % id)
	if common:
		t.ok(id.begins_with("fa.any."), id)
	elif type == "fate":
		t.ok(id.begins_with("fa.1939."), id)
	elif type == "event":
		t.ok(id.begins_with("ev.1939."), id)
	elif type == "big_fate":
		t.ok(id.begins_with("bf.1939."), id)
	elif type == "life":
		t.ok(id.begins_with("lf.1939."), id)
	elif type == "goal":
		t.ok(id.begins_with("gl.1939."), id)
	t.ok(not id.contains("1940"), "%s id year" % id)
	var pv = c.get("_provenance", {})
	t.ok(typeof(pv) == TYPE_DICTIONARY, "%s provenance" % id)
	t.eq(str(pv.get("task", "")), "K04", "%s task" % id)
	t.eq(str(pv.get("by", "")), "ai", "%s by" % id)
	t.eq(str(pv.get("date", "")), "2026-10-13", "%s date" % id)
	t.ok(str(c.get("brief", "")).strip_edges() != "", "%s brief" % id)
	t.ok(t.find_floats(c).is_empty(), "%s floats" % id)
	if OMEN_TYPES.has(type):
		t.ok(_has_omen(c), "%s omen" % id)
	if type == "fate" or type == "big_fate":
		t.ok(VALENCES.has(str(c.get("valence", ""))), "%s valence set" % id)
	if type == "big_fate":
		t.eq(int(c.get("weight", -1)), 0, "%s big weight" % id)
	for tag in c.get("tags", []):
		t.ok(db.tags().has(str(tag)), "%s tag %s" % [id, tag])
	_walk_effects(t, db, c)
	_no_text_keys(t, id, c)
	_check_close(t, id, c)


func _check_close(t, id: String, c: Dictionary) -> void:
	# 10-13 打烊（合同 §7.4.7）。演出块另开 PR，这里不许写 stage。
	t.ok(not c.has("stage"), "%s no stage" % id)
	t.ok(id != "bf.wheel", "%s is not bf.wheel" % id)
	if str(c.get("opens_fortune", "")) != "" or str(c.get("opens_wheel", "")) != "":
		t.eq(c.get("must_resolve", null), false, "%s opportunity must_resolve" % id)
	var type := str(c.get("type", ""))
	if type in ["event", "fate", "big_fate"]:
		var has_check := typeof(c.get("check")) == TYPE_DICTIONARY
		var fx = c.get("effects", {})
		var has_exp := typeof(fx) == TYPE_DICTIONARY and (fx as Dictionary).has("on_expire") \
				and typeof((fx as Dictionary).get("on_expire")) == TYPE_ARRAY
		if CardViewModel.must_resolve(c) and not has_check:
			t.ok(has_exp, "%s on_expire" % id)
		var sn := str(c.get("story_node", ""))
		if sn != "":
			t.ok(_expire_story(c, sn), "%s ignored story" % id)
		t.eq(str(c.get("brief", "")).count("没理会"), 1, "%s one ignore line" % id)
	elif type == "life":
		t.eq(c.get("must_resolve", null), false, "%s life must_resolve" % id)
		var fx2 = c.get("effects", {})
		t.ok(typeof(fx2) == TYPE_DICTIONARY and (fx2 as Dictionary).has("on_expire"), "%s life on_expire" % id)
		var exp = (fx2 as Dictionary).get("on_expire")
		t.ok(typeof(exp) == TYPE_ARRAY and not (exp as Array).is_empty(), "%s life expire" % id)
		t.ok(_expire_matches_choice(c), "%s expire is endure choice" % id)
		var brief := str(c.get("brief", ""))
		t.eq(brief.count("挨过去"), 1, "%s endure line" % id)
		t.eq(brief.count("打烊没到期"), 1, "%s stays till due" % id)


func _expire_story(c: Dictionary, node: String) -> bool:
	var fx = c.get("effects", {})
	if typeof(fx) != TYPE_DICTIONARY or not (fx as Dictionary).has("on_expire"):
		return false
	for e in (fx as Dictionary).get("on_expire", []):
		if typeof(e) != TYPE_DICTIONARY:
			continue
		if str(e.get("op", "")) == "story" and str(e.get("node", "")) == node \
				and str(e.get("outcome", "")) == "ignored":
			return true
	return false


func _expire_matches_choice(c: Dictionary) -> bool:
	var fx = c.get("effects", {})
	if typeof(fx) != TYPE_DICTIONARY:
		return false
	var exp = (fx as Dictionary).get("on_expire", null)
	if typeof(exp) != TYPE_ARRAY:
		return false
	for ch in c.get("choices", []):
		if typeof(ch) != TYPE_DICTIONARY:
			continue
		var ef = ch.get("effects", null)
		if typeof(ef) == TYPE_ARRAY and ef == exp:
			return true
	return false


func _walk_effects(t, db: CardDB, node) -> void:
	match typeof(node):
		TYPE_DICTIONARY:
			if node.has("op"):
				_check_effect(t, db, node)
			for k in node.keys():
				if str(k) == "brief" or str(k).begins_with("_"):
					continue
				_walk_effects(t, db, node[k])
		TYPE_ARRAY:
			for v in node:
				_walk_effects(t, db, v)


func _check_effect(t, db: CardDB, e: Dictionary) -> void:
	var op := str(e.get("op", ""))
	if op == "pay":
		t.eq(str(e.get("short", "")), "ladder", "pay short")
	if op in ["money", "pay", "item_lose", "arrest"] and e.has("reason"):
		_check_ui(t, db, str(e.get("reason", "")))
	if op == "notice":
		_check_ui(t, db, str(e.get("key", "")))


func _check_ui(t, db: CardDB, key: String) -> void:
	t.ok(key.begins_with("k04."), "ui key prefix %s" % key)
	t.ok(db.ui_keys().has(key), "ui key registered %s" % key)


func _check_briefs(t) -> void:
	var paths := [
		"res://data/cards/era/common/fate.json",
		"res://data/cards/era/1939/events.json",
		"res://data/cards/era/1939/fate.json",
		"res://data/cards/era/1939/big_fate.json",
		"res://data/cards/era/1939/life.json",
		"res://data/cards/era/1939/goals.json",
		"res://data/cards/era/1939/stage.json",
		"res://data/cards/tags/K04.json",
		"res://data/cards/ui_keys/K04.json",
	]
	for path in paths:
		var doc = CardDB.read_json(path)
		t.ok(typeof(doc) == TYPE_DICTIONARY, path)
		_walk_briefs(t, doc, path)


func _walk_briefs(t, node, where: String) -> void:
	match typeof(node):
		TYPE_DICTIONARY:
			for k in node.keys():
				if str(k) == "brief" and typeof(node[k]) == TYPE_STRING:
					_check_brief_text(t, str(node[k]), where)
				elif not str(k).begins_with("_"):
					_walk_briefs(t, node[k], where)
				elif str(k) == "_meta" or str(k) == "_provenance":
					_walk_briefs(t, node[k], where)
		TYPE_ARRAY:
			for v in node:
				_walk_briefs(t, v, where)


func _check_brief_text(t, text: String, where: String) -> void:
	for pair in QUOTE_PAIRS:
		var open := str(pair[0])
		var close := str(pair[1])
		var i := 0
		while true:
			var a := text.find(open, i)
			if a < 0:
				break
			var b := text.find(close, a + open.length())
			if b < 0:
				t.ok(false, "%s unclosed quote" % where)
				break
			var inner := text.substr(a + open.length(), b - a - open.length())
			t.ok(inner.length() <= 12, "%s quote length" % where)
			for stop in STOPS:
				t.ok(not inner.contains(stop), "%s quote punctuation" % where)
			i = b + close.length()
	for needle in NEEDLES:
		var at := 0
		while true:
			var j := text.find(needle, at)
			if j < 0:
				break
			t.ok(j > 0 and text.substr(j - 1, 1) == WEI, "%s missing wei" % where)
			at = j + needle.length()


func _dangling(db: CardDB, stories: Dictionary) -> Dictionary:
	var out := {}
	var templates := _templates()
	var arts: Dictionary = db.art_manifest().get("art", {})
	for id in db.all_ids():
		if not _our_file(db.file_of(id)):
			continue
		var c := db.def(id)
		var art := str(c.get("art", ""))
		if art != "" and not arts.has(art):
			out[art] = true
		if c.has("opens_wheel") and not db.has(str(c.get("opens_wheel", ""))):
			out[str(c.get("opens_wheel", ""))] = true
		var effects: Array = []
		var conds: Array = []
		_collect(c, effects, conds)
		for e in effects:
			_effect_dangling(db, e, templates, out)
		for cond in conds:
			_cond_dangling(db, cond, stories, templates, out)
	var intro: Dictionary = db.stage(1).get("intro", {})
	var bg := str(intro.get("bg", ""))
	if bg != "" and not arts.has(bg):
		out[bg] = true
	var mg := str(intro.get("main_goal", ""))
	if mg != "" and not db.has(mg):
		out[mg] = true
	return out


func _effect_dangling(db: CardDB, e: Dictionary, templates: Dictionary, out: Dictionary) -> void:
	var op := str(e.get("op", ""))
	if op == "add_card":
		_miss_card(db, str(e.get("card", "")), out)
	elif op == "remove_card":
		var m = e.get("match", {})
		if typeof(m) == TYPE_DICTIONARY and m.has("def"):
			_miss_card(db, str(m["def"]), out)
	elif op == "dossier" or op == "dossier_gap":
		_miss_card(db, str(e.get("frag", "")), out)
	elif op == "person_state" or op == "contact_gain" or op == "contact_lose":
		_miss_person(db, str(e.get("person", "")), out)
	elif op == "attr":
		_miss_person(db, str(e.get("who", "")), out)
	elif op == "goal":
		_miss_card(db, str(e.get("id", "")), out)
	elif op == "item_gain" and e.has("template"):
		_miss_template(templates, str(e.get("template", "")), out)
	elif op == "item_lose":
		var im = e.get("match", {})
		if typeof(im) == TYPE_DICTIONARY and im.has("template"):
			_miss_template(templates, str(im["template"]), out)
	elif op == "wheel_offer":
		_miss_card(db, str(e.get("wheel", "")), out)


func _cond_dangling(db: CardDB, cond: Dictionary, stories: Dictionary, templates: Dictionary, out: Dictionary) -> void:
	if cond.size() != 1:
		return
	var op := str(cond.keys()[0])
	var v = cond[op]
	match op:
		"all", "any":
			if typeof(v) == TYPE_ARRAY:
				for sub in v:
					if typeof(sub) == TYPE_DICTIONARY:
						_cond_dangling(db, sub, stories, templates, out)
		"not":
			if typeof(v) == TYPE_DICTIONARY:
				_cond_dangling(db, v, stories, templates, out)
		"estate_status", "goal_status":
			if typeof(v) == TYPE_ARRAY and not v.is_empty():
				_miss_card(db, str(v[0]), out)
		"story":
			if typeof(v) == TYPE_ARRAY and not v.is_empty() and not stories.has(str(v[0])):
				out[str(v[0])] = true
		"has_contact", "ticket_open":
			_miss_person(db, str(v), out)
		"person_state":
			if typeof(v) == TYPE_ARRAY and not v.is_empty():
				_miss_person(db, str(v[0]), out)
		"stock_has":
			_miss_template(templates, str(v), out)
		"has_kept":
			if typeof(v) == TYPE_DICTIONARY and v.has("def"):
				_miss_card(db, str(v["def"]), out)
		"fortune":
			_miss_card(db, str(v), out)
		"dossier_has":
			_miss_card(db, str(v), out)


func _collect(node, effects: Array, conds: Array) -> void:
	match typeof(node):
		TYPE_DICTIONARY:
			if node.has("op") and typeof(node["op"]) == TYPE_STRING:
				effects.append(node)
			if node.size() == 1 and CardDslShapes.is_cond_op(str(node.keys()[0])):
				conds.append(node)
			for k in node.keys():
				if str(k) == "brief" or str(k).begins_with("_"):
					continue
				_collect(node[k], effects, conds)
		TYPE_ARRAY:
			for v in node:
				_collect(v, effects, conds)


func _miss_card(db: CardDB, id: String, out: Dictionary) -> void:
	if id != "" and not db.has(id):
		out[id] = true


func _miss_person(db: CardDB, id: String, out: Dictionary) -> void:
	if id != "" and not db.persons().has(id):
		out[id] = true


func _miss_template(templates: Dictionary, id: String, out: Dictionary) -> void:
	if id != "" and not templates.has(id):
		out[id] = true


func _templates() -> Dictionary:
	var out := {}
	var doc = CardDB.read_json("res://data/town/item_templates.json")
	if typeof(doc) != TYPE_DICTIONARY:
		return out
	var cats: Dictionary = doc.get("categories", {})
	for cat in cats.keys():
		var variants = cats[cat].get("variants", []) if typeof(cats[cat]) == TYPE_DICTIONARY else []
		if typeof(variants) != TYPE_ARRAY:
			continue
		for v in variants:
			if typeof(v) == TYPE_DICTIONARY:
				out["%s.%s" % [cat, str(v.get("id", ""))]] = true
	return out


func _expected_dangle(id: String) -> bool:
	if id == "ruhua" or id == "es.shopfront" or id == "es.jewel_cabinet" or id == "bg.stage.1939":
		return true
	return id.begins_with("illus.")


func _our_file(f: String) -> bool:
	return FILES.has(f)


func _era_has(c: Dictionary, era: String) -> bool:
	var eras = c.get("era", [])
	return typeof(eras) == TYPE_ARRAY and (eras as Array).has(era)


func _era_only(c: Dictionary, era: String) -> bool:
	var eras = c.get("era", [])
	return typeof(eras) == TYPE_ARRAY and (eras as Array).size() == 1 and str(eras[0]) == era


func _has_omen(c: Dictionary) -> bool:
	for tag in c.get("tags", []):
		if str(tag).begins_with("omen_"):
			return true
	return false


func _has_slots(choices: Array) -> bool:
	for ch in choices:
		if typeof(ch) != TYPE_DICTIONARY:
			continue
		var chk = ch.get("check", null)
		if typeof(chk) != TYPE_DICTIONARY:
			continue
		var slots = chk.get("slots", [])
		if typeof(slots) == TYPE_ARRAY and not (slots as Array).is_empty():
			return true
	return false


func _check_day(t, c: Dictionary) -> void:
	var sch = c.get("schedule", null)
	if typeof(sch) != TYPE_DICTIONARY or not sch.has("stage_day"):
		return
	var sd = sch["stage_day"]
	var hi := -1
	if typeof(sd) == TYPE_ARRAY and sd.size() == 2:
		hi = int(sd[1])
	elif typeof(sd) == TYPE_INT or typeof(sd) == TYPE_FLOAT:
		hi = int(sd)
	t.ok(hi >= 1 and hi <= 30, "%s stage_day" % str(c.get("id", "")))


func _no_text_keys(t, id: String, node) -> void:
	match typeof(node):
		TYPE_DICTIONARY:
			for k in node.keys():
				var key := str(k)
				if key.begins_with("_"):
					continue
				t.ok(not TEXT_KEYS.has(key), "%s text field %s" % [id, key])
				_no_text_keys(t, id, node[k])
		TYPE_ARRAY:
			for v in node:
				_no_text_keys(t, id, v)
