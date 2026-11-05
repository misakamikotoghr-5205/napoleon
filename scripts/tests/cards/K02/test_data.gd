# K02 data asserts (docs/handoff_cards/K02_data-1938-world.md).
# Dangling ids and the big-fate list for K10 are printed as NOTE lines (not failures).
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")

const OURS: Array[String] = [
	"era/common/events.json", "era/common/big_fate.json",
	"era/1938/events.json", "era/1938/fate.json", "era/1938/big_fate.json",
	"era/1938/life.json", "era/1938/goals.json",
]
const VALENCE: Array[String] = ["good", "bad", "mixed"]
const BANNED: Array[String] = ["\u6982\u7387", "%", "\uff05", "\u70b9\u6570", "\u672c\u5fc3", "\u5e95\u4ef7", "\u771f\u5047"]
const PUPPET: Array[String] = ["\u7ef4\u6301\u4f1a", "\u7ef4\u65b0\u653f\u5e9c", "\u53bf\u653f\u5e9c"]


func _initialize() -> void:
	var t := T.new(self, "K02_data")
	var db := CardDB.load_all()
	t.eq(db.errors(), PackedStringArray(), "db loads")
	var mine := _ids_in(db, OURS)
	_counts(t, db)
	_each(t, db, mine)
	_special(t, db)
	_expire(t, db)
	_goals(t, db)
	_keys_and_briefs(t, db, mine)
	_notes(db, mine)
	t.finish()


func _ids_in(db: CardDB, files: Array) -> Array:
	var out: Array = []
	for id in db.all_ids():
		if files.has(db.file_of(id)):
			out.append(id)
	out.sort()
	return out


func _counts(t, db: CardDB) -> void:
	t.ok(_ids_in(db, ["era/common/events.json"]).size() >= 10, "common events >= 10")
	t.ok(_ids_in(db, ["era/1938/events.json"]).size() >= 10, "1938 events >= 10")
	var fates := _ids_in(db, ["era/1938/fate.json"]).size()
	t.ok(fates >= 3 and fates <= 5, "1938 fate count is 4 plus or minus 1")
	var big_common := _ids_in(db, ["era/common/big_fate.json"])
	var bets := 0
	for id in big_common:
		if id != "bf.wheel":
			bets += 1
	t.ok(bets >= 4 and bets <= 6, "common big bets 4-6")
	var big_year := _ids_in(db, ["era/1938/big_fate.json"]).size()
	t.ok(big_year >= 1 and big_year <= 2, "1938 big fate 1-2")
	var lives := _ids_in(db, ["era/1938/life.json"]).size()
	t.ok(lives >= 2 and lives <= 3, "1938 life 2-3")
	var mains := 0
	var opts := 0
	for id in _ids_in(db, ["era/1938/goals.json"]):
		if bool(db.def(id).get("main", false)):
			mains += 1
		elif int(db.def(id).get("weight", 0)) > 0:
			opts += 1
	t.eq(mains, 1, "one main goal")
	t.ok(opts >= 4, "at least 4 optional goals")


func _each(t, db: CardDB, mine: Array) -> void:
	var known: Dictionary = db.tags()
	for id in mine:
		var c := db.def(id)
		var type := str(c.get("type", ""))
		t.eq(id.get_slice(".", 0), str(CardIds.TYPE_PREFIX[type]), id + " prefix")
		t.ok(_era_ok(id, c.get("era", [])), id + " era")
		var pv: Dictionary = c.get("_provenance", {})
		t.eq(str(pv.get("by", "")), "ai", id + " provenance by")
		t.eq(str(pv.get("task", "")), "K02", id + " provenance task")
		t.eq(str(pv.get("date", "")), "2026-10-13", id + " provenance date")
		t.ok(str(c.get("brief", "")).strip_edges() != "", id + " brief")
		t.eq(str(c.get("art", "")), "illus." + id, id + " art")
		t.ok(not id.begins_with("ev.rule."), id + " is not a rule card")
		if type == "event" or type == "fate" or type == "life":
			t.ok(_has_omen(c.get("tags", [])), id + " omen tag")
		for tag in c.get("tags", []):
			t.ok(known.has(str(tag)), id + " tag declared " + str(tag))
		if c.has("schedule"):
			t.ok(_days_ok(c["schedule"]), id + " schedule day")
		if type == "big_fate":
			t.eq(int(c.get("weight", -1)), 0, id + " big fate weight")
		if type == "fate":
			t.ok(VALENCE.has(str(c.get("valence", ""))), id + " valence")


func _era_ok(id: String, era) -> bool:
	if typeof(era) != TYPE_ARRAY:
		return false
	if id == "bf.wheel" or id.contains(".any."):
		return era.has("*")
	if id.contains(".1938."):
		return era.size() == 1 and str(era[0]) == "1938"
	return false


func _has_omen(tags) -> bool:
	for tag in tags:
		if str(tag).begins_with("omen_"):
			return true
	return false


func _days_ok(sch) -> bool:
	if typeof(sch) != TYPE_DICTIONARY or not sch.has("stage_day"):
		return false
	var sd = sch["stage_day"]
	var days: Array = sd if typeof(sd) == TYPE_ARRAY else [sd]
	if days.is_empty():
		return false
	for d in days:
		if int(d) < 4 or int(d) > 30:
			return false
	return true


func _special(t, db: CardDB) -> void:
	for id in ["ev.any.fortune_teller", "ev.any.cezi_stall", "ev.any.temple_lot", "ev.any.fair",
			"ev.any.gamble_stall", "ev.any.wheel_go", "bf.wheel", "bf.any.mystery_box",
			"bf.any.sun_guarantee", "bf.any.house_offer", "bf.any.ship_ticket", "bf.any.quiet_fee",
			"bf.any.street_bed", "ev.1938.police_check", "ev.1938.police_open", "gl.1938.keep_shop",
			"bf.1938.bail_shop", "bf.1938.night_cargo"]:
		t.ok(db.has(id), "has " + id)
	var fort := db.def("ev.any.fortune_teller")
	t.eq(str(fort.get("opens_fortune", "")), "both", "fortune both")
	t.ok(int(fort.get("cost", {}).get("money", 0)) > 0, "fortune money")
	t.eq(bool(fort.get("must_resolve", true)), false, "fortune optional")
	t.eq(str(db.def("ev.any.fair").get("opens_wheel", "")), "wh.fair", "fair wheel")
	var gamble := db.def("ev.any.gamble_stall")
	t.eq(str(gamble.get("opens_wheel", "")), "wh.gamble", "gamble wheel")
	t.eq(bool(gamble.get("cost", {}).get("stake", false)), true, "gamble stakes")
	t.eq(int(db.def("ev.any.wheel_go").get("weight", -1)), 0, "wheel_go weight")
	var wheel := db.def("bf.wheel")
	t.eq(str(wheel.get("opens_wheel", "")), "wh.big", "only design of bf.wheel")
	t.ok((wheel.get("tags", []) as Array).has("big"), "bf.wheel tag big")
	for id in db.ids_of(&"big_fate"):
		if not OURS.has(db.file_of(id)):
			continue
		if id == "bf.wheel":
			continue
		var c := db.def(id)
		t.ok(str(c.get("opens_wheel", "")) == "", id + " does not open a wheel")
		t.ok(VALENCE.has(str(c.get("valence", ""))), id + " big valence")
		t.ok(typeof(c.get("crisis")) == TYPE_ARRAY and (c["crisis"] as Array).size() > 0, id + " crisis")
		t.ok(typeof(c.get("choices")) == TYPE_ARRAY and (c["choices"] as Array).size() > 0, id + " choices")
	var node := db.def("ev.1938.police_open")
	t.eq(str(node.get("story_node", "")), "s1938.police_open", "police_open node")
	t.eq(int(node.get("weight", -1)), 0, "police_open weight")
	t.eq(int(node.get("schedule", {}).get("stage_day", 0)), 28, "police_open day")
	for id in _ids_in(db, ["era/1938/life.json"]):
		t.ok(_has_ladder_pay(db.def(id)), id + " pay ladder")


func _has_ladder_pay(c: Dictionary) -> bool:
	return _find_pay(c.get("choices", [])) or _find_pay(c.get("effects", {}))


func _find_pay(v) -> bool:
	if typeof(v) == TYPE_DICTIONARY:
		if str(v.get("op", "")) == "pay" and str(v.get("short", "")) == "ladder":
			return true
		for k in v.keys():
			if _find_pay(v[k]):
				return true
	elif typeof(v) == TYPE_ARRAY:
		for x in v:
			if _find_pay(x):
				return true
	return false


# Day-end (contract 1.2 / V37): event/fate/big_fate with no top-level check and
# must_resolve not false must have an on_expire key (array may be empty).
# Opportunity cards are must_resolve false. bf.wheel is voided by the engine.
# No stage block.
func _expire(t, db: CardDB) -> void:
	var files: Array[String] = [
		"era/common/events.json", "era/common/big_fate.json",
		"era/1938/events.json", "era/1938/fate.json", "era/1938/big_fate.json",
		"era/1938/life.json", "era/1938/goals.json",
	]
	for id in _ids_in(db, files):
		var c: Dictionary = db.def(id)
		t.ok(not c.has("stage"), id + " no stage")
		var type := str(c.get("type", ""))
		if type != "event" and type != "fate" and type != "big_fate":
			continue
		if id == "bf.wheel":
			var wfx = c.get("effects", {})
			var wrote: bool = typeof(wfx) == TYPE_DICTIONARY and (wfx as Dictionary).has("on_expire")
			t.ok(not wrote, "bf.wheel has no on_expire")
			continue
		var opportunity: bool = type == "event" and (
			str(c.get("opens_fortune", "")) != ""
			or str(c.get("opens_wheel", "")) != ""
			or id == "ev.any.wheel_go"
		)
		if opportunity:
			t.eq(bool(c.get("must_resolve", true)), false, id + " opportunity must_resolve false")
			continue
		if c.has("check"):
			continue
		if not bool(c.get("must_resolve", true)):
			continue
		var fx = c.get("effects", {})
		t.ok(typeof(fx) == TYPE_DICTIONARY and (fx as Dictionary).has("on_expire"), id + " on_expire key")
		if typeof(fx) == TYPE_DICTIONARY and (fx as Dictionary).has("on_expire"):
			t.ok(typeof((fx as Dictionary).get("on_expire")) == TYPE_ARRAY, id + " on_expire array")


func _goals(t, db: CardDB) -> void:
	for id in _ids_in(db, ["era/1938/goals.json"]):
		var c := db.def(id)
		var err := CardDslShapes.check_cond(c.get("done_when", {"nope": 1}))
		t.ok(err == "", id + " done_when " + err)
		for op in CardDslShapes.cond_ops_used(c.get("done_when", {})):
			t.ok(CardDslShapes.is_cond_op(op), id + " cond op " + op)
		var ev := str(c.get("eval", ""))
		t.ok(ev == "month_close" or ev == "any_time", id + " eval")


func _keys_and_briefs(t, db: CardDB, mine: Array) -> void:
	var keys: Dictionary = db.ui_keys()
	var found := {"reason": {}, "notice": {}}
	for id in mine:
		_scan_keys(db.def(id), found)
	for kind in found.keys():
		for key in found[kind].keys():
			t.ok(str(key).begins_with("k02."), str(key) + " prefix")
			t.ok(keys.has(str(key)), str(key) + " registered")
	var blobs := _all_briefs()
	t.ok(blobs.size() > 0, "briefs collected")
	for row in blobs:
		var msg := _brief_problem(row[1])
		t.ok(msg == "", row[0] + " brief " + msg)


func _scan_keys(v, found: Dictionary) -> void:
	if typeof(v) == TYPE_DICTIONARY:
		var op := str(v.get("op", ""))
		if (op == "money" or op == "pay" or op == "item_lose" or op == "arrest") and v.has("reason"):
			found["reason"][str(v["reason"])] = true
		if op == "notice" and v.has("key"):
			found["notice"][str(v["key"])] = true
		for k in v.keys():
			_scan_keys(v[k], found)
	elif typeof(v) == TYPE_ARRAY:
		for x in v:
			_scan_keys(x, found)


func _all_briefs() -> Array:
	var out: Array = []
	var paths := OURS.duplicate()
	paths.append("era/1938/stage.json")
	paths.append("tags/K02.json")
	paths.append("ui_keys/K02.json")
	for rel in paths:
		var doc = CardDB.read_json("res://data/cards/" + rel)
		_collect_briefs(doc, rel, out)
	return out


func _collect_briefs(v, path: String, out: Array) -> void:
	if typeof(v) == TYPE_DICTIONARY:
		for k in v.keys():
			if str(k) == "brief" and typeof(v[k]) == TYPE_STRING:
				out.append([path, str(v[k])])
			elif not str(k).begins_with("_") or str(k) == "_meta":
				_collect_briefs(v[k], path, out)
	elif typeof(v) == TYPE_ARRAY:
		for x in v:
			_collect_briefs(x, path, out)


func _brief_problem(s: String) -> String:
	for b in BANNED:
		if s.contains(b):
			return "banned token"
	var q := _quote_problem(s)
	if q != "":
		return q
	return _puppet_problem(s)


func _quote_problem(s: String) -> String:
	var pairs := {"\"": "\"", "'": "'", "\u201c": "\u201d", "\u2018": "\u2019", "\u300c": "\u300d", "\u300e": "\u300f"}
	var i := 0
	while i < s.length():
		var ch := s.substr(i, 1)
		if not pairs.has(ch):
			i += 1
			continue
		var j := s.find(pairs[ch], i + 1)
		if j < 0:
			return "unclosed quote"
		var inner := s.substr(i + 1, j - i - 1)
		if inner.length() > 12:
			return "quote over 12"
		if inner.contains("\u3002") or inner.contains("\uff01") or inner.contains("\uff1f"):
			return "quote punctuation"
		i = j + 1
	return ""


func _puppet_problem(s: String) -> String:
	var wei := "\u4f2a"
	for n in PUPPET:
		var from := 0
		while true:
			var at := s.find(n, from)
			if at < 0:
				break
			if at == 0 or s.substr(at - 1, 1) != wei:
				return "puppet prefix"
			from = at + n.length()
	return ""


func _notes(db: CardDB, mine: Array) -> void:
	var refs := {"cards": {}, "persons": {}, "wheels": {}, "templates": {}}
	for id in mine:
		_scan_refs(db.def(id), refs)
	var templates := _templates()
	var dangling := {}
	for id in refs["cards"]:
		if not db.has(str(id)):
			dangling[str(id)] = true
	for id in refs["wheels"]:
		if not db.has(str(id)):
			dangling[str(id)] = true
	for id in refs["persons"]:
		if not db.persons().has(str(id)):
			dangling[str(id)] = true
	for id in refs["templates"]:
		if not templates.has(str(id)):
			dangling[str(id)] = true
	var names: Array = dangling.keys()
	names.sort()
	for n in names:
		print("NOTE: dangling " + str(n))
	var bets: Array = []
	for id in db.ids_of(&"big_fate"):
		if not OURS.has(db.file_of(id)):
			continue
		if id != "bf.wheel":
			bets.append(id)
	bets.sort()
	for id in bets:
		print("NOTE: bigfate_for_k10 " + str(id))


func _scan_refs(v, refs: Dictionary) -> void:
	if typeof(v) == TYPE_DICTIONARY:
		if v.has("opens_wheel"):
			refs["wheels"][str(v["opens_wheel"])] = true
		if v.has("op"):
			_scan_effect(v, refs)
		if v.size() == 1:
			var op := str(v.keys()[0])
			if CardDslShapes.is_cond_op(op):
				_scan_cond(op, v[v.keys()[0]], refs)
		var match = v.get("item_match", null)
		if typeof(match) == TYPE_DICTIONARY and match.has("template"):
			refs["templates"][str(match["template"])] = true
		for k in v.keys():
			if str(k) == "brief" or str(k).begins_with("_"):
				continue
			_scan_refs(v[k], refs)
	elif typeof(v) == TYPE_ARRAY:
		for x in v:
			_scan_refs(x, refs)


func _scan_effect(e: Dictionary, refs: Dictionary) -> void:
	match str(e.get("op", "")):
		"add_card", "goal":
			refs["cards"][str(e.get("card", e.get("id", "")))] = true
		"dossier", "dossier_gap":
			refs["cards"][str(e.get("frag", ""))] = true
		"person_state", "contact_gain", "contact_lose":
			refs["persons"][str(e.get("person", ""))] = true
		"attr":
			refs["persons"][str(e.get("who", ""))] = true
		"estate_seize":
			if str(e.get("pick", "")).contains("."):
				refs["cards"][str(e["pick"])] = true
		"wheel_offer":
			refs["wheels"][str(e.get("wheel", ""))] = true
		"item_gain":
			if e.has("template"):
				refs["templates"][str(e["template"])] = true
		"item_lose":
			var m = e.get("match", {})
			if typeof(m) == TYPE_DICTIONARY and m.has("template"):
				refs["templates"][str(m["template"])] = true
		"if":
			_scan_cond_node(e.get("cond", {}), refs)


func _scan_cond_node(c, refs: Dictionary) -> void:
	if typeof(c) == TYPE_DICTIONARY and c.size() == 1:
		var op := str(c.keys()[0])
		if CardDslShapes.is_cond_op(op):
			_scan_cond(op, c[c.keys()[0]], refs)


func _scan_cond(op: String, val, refs: Dictionary) -> void:
	match op:
		"all", "any":
			if typeof(val) == TYPE_ARRAY:
				for sub in val:
					_scan_cond_node(sub, refs)
		"not":
			_scan_cond_node(val, refs)
		"has_contact", "dossier_page_complete", "ticket_open":
			refs["persons"][str(val)] = true
		"person_state":
			if typeof(val) == TYPE_ARRAY and val.size() > 0:
				refs["persons"][str(val[0])] = true
		"estate_status":
			if typeof(val) == TYPE_ARRAY and val.size() > 0:
				refs["cards"][str(val[0])] = true
		"has_kept":
			if typeof(val) == TYPE_DICTIONARY and val.has("def"):
				refs["cards"][str(val["def"])] = true
		"stock_has":
			refs["templates"][str(val)] = true
		"fortune":
			refs["cards"][str(val)] = true


func _templates() -> Dictionary:
	var out := {}
	var doc = CardDB.read_json("res://data/town/item_templates.json")
	if typeof(doc) != TYPE_DICTIONARY:
		return out
	for cat in doc.get("categories", {}).keys():
		for v in doc["categories"][cat].get("variants", []):
			out["%s.%s" % [cat, v.get("id", "")]] = true
	var extra = CardDB.read_json("res://data/cards/items/templates_extra.json")
	if typeof(extra) == TYPE_DICTIONARY:
		for cat2 in extra.get("categories", {}).keys():
			for v2 in extra["categories"][cat2].get("variants", []):
				out["%s.%s" % [cat2, v2.get("id", "")]] = true
	return out
