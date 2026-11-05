# K05 data checks for 1940 person cards. Strings in this file stay ASCII.
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")

const MAJORS := [
	"brother", "chen", "xiaoding", "zhang", "wangshan", "li", "linsao", "zhouma",
	"zhao", "sunyoung", "ma", "hu2", "sunlaoye", "guanjia", "wu", "postman",
]
const NEW_FACES := ["nf1940a", "nf1940b", "nf1940c", "nf1940d"]
const SUN := ["sunlaoye", "sunyoung", "guanjia"]
const PERSON_NODES := ["s1940.sunfu_stance", "s1940.dossier_link", "s1940.hook"]
const EVENT_NODES := ["s1940.wang_regime", "s1940.new_official"]
const GRUDGE_OPS := ["flag", "rep", "counter", "person_state"]
const GRUDGE := {
	"p.linsao.1940.pawn_coat": "grudge_linsao",
	"p.ma.1940.levy_old": "grudge_ma",
	"p.hu2.1940.slip_old": "grudge_hu2",
	"p.nf1940a.1940.register": "grudge_nf1940a",
}
const FOLLOW_FLAG := {
	"p.linsao.1940.ask_gone": "grudge_linsao",
	"p.ma.1940.levy_harsh": "grudge_ma",
	"p.hu2.1940.slip_cold": "grudge_hu2",
	"p.nf1940a.1940.register_cold": "grudge_nf1940a",
}
const FOLLOW_COUNTER := {
	"p.ma.1940.levy_harsh": "snub_ma",
	"p.hu2.1940.slip_cold": "snub_hu2",
	"p.nf1940a.1940.register_cold": "snub_nf1940a",
}
const FILES := [
	"res://data/cards/era/1940/people.json",
	"res://data/cards/era/1940/story.json",
]

var _cjk: RegEx
var _id_re: RegEx
var _date_re: RegEx


func _initialize() -> void:
	var t := T.new(self, "K05_data")
	_cjk = RegEx.create_from_string(CardValidator.CJK_RE)
	_id_re = RegEx.create_from_string("^p\\.[a-z0-9_]+\\.1940\\.[a-z0-9_]+$")
	_date_re = RegEx.create_from_string("^\\d{4}-\\d{2}-\\d{2}$")
	var db := CardDB.load_all("res://data/cards", {})
	t.eq(db.errors(), PackedStringArray(), "card db loads")
	var cards: Array = []
	var docs: Array = []
	var briefs: Array = []
	for path in FILES:
		var doc = CardState.int_restore(CardDB.read_json(path))
		t.ok(typeof(doc) == TYPE_DICTIONARY, "parse " + path)
		docs.append(doc)
		_each_brief(doc, briefs)
		var bad_cjk: Array = []
		_cjk_outside(doc, path.get_file(), bad_cjk)
		t.eq(bad_cjk, [], "CJK outside brief in " + path)
		var floats: Array = []
		_floats(doc, floats)
		t.eq(floats, [], "integers only in " + path)
		for c in doc.get("cards", []):
			cards.append(c)
	var tag_doc = CardState.int_restore(CardDB.read_json("res://data/cards/tags/K05.json"))
	var key_doc = CardState.int_restore(CardDB.read_json("res://data/cards/ui_keys/K05.json"))
	t.eq(str(tag_doc.get("_meta", {}).get("owner", "")), "K05", "tags owner")
	t.eq(str(key_doc.get("_meta", {}).get("owner", "")), "K05", "ui keys owner")
	_each_brief(tag_doc, briefs)
	_each_brief(key_doc, briefs)
	var people = CardState.int_restore(CardDB.read_json(FILES[0]))
	var persons: Dictionary = people.get("persons", {})
	for pid in NEW_FACES:
		t.ok(persons.has(pid), "persons block has " + pid)
		t.eq(str(persons[pid].get("portrait", "")), "portrait." + pid, pid + " portrait")
		t.ok(bool(persons[pid].get("dossier", false)), pid + " dossier")
	for pid in MAJORS:
		t.ok(not persons.has(pid), "cast person not re-registered " + pid)
	t.ok(cards.size() >= 36, "person card count %d" % cards.size())
	var by_person := {}
	var nodes := {}
	var pawn := {}
	var redeem := {}
	var declared: Dictionary = db.tags()
	var ui: Dictionary = key_doc.get("keys", {})
	for k in ui.keys():
		t.ok(str(k).begins_with("k05."), "ui key prefix " + str(k))
		t.ok(str(ui[k].get("brief", "")).strip_edges() != "", "ui key brief " + str(k))
	for c in cards:
		var id := str(c.get("id", ""))
		t.ok(_id_re.search(id) != null, "id " + id)
		t.eq(str(c.get("type", "")), "person", id + " type")
		t.eq(c.get("era", []), ["1940"], id + " era")
		var pv = c.get("_provenance", {})
		t.eq(str(pv.get("by", "")), "ai", id + " provenance by")
		t.eq(str(pv.get("task", "")), "K05", id + " provenance task")
		t.ok(_date_re.search(str(pv.get("date", ""))) != null, id + " provenance date")
		t.ok(str(c.get("brief", "")).strip_edges() != "", id + " brief")
		var omen := false
		for tag in c.get("tags", []):
			var ts := str(tag)
			if ts.begins_with("omen_"):
				omen = true
			t.ok(declared.has(ts), id + " tag declared " + ts)
		t.ok(omen, id + " omen tag")
		var person := str(c.get("person", ""))
		by_person[person] = int(by_person.get(person, 0)) + 1
		var intent := str(c.get("intent", ""))
		if intent == "pawn" or intent == "sell":
			t.ok(typeof(c.get("item")) == TYPE_DICTIONARY and str(c["item"].get("template", c["item"].get("cat", ""))) != "", id + " item")
			t.ok(_pair(c.get("asking", {}).get("pct", [])), id + " asking")
			t.ok(_pair(c.get("floor", {}).get("pct", [])), id + " floor")
			t.ok(_pair(c.get("patience_min", [])), id + " patience")
			var imp := str(c.get("impatience", ""))
			t.ok(imp == "leave" or imp == "raise", id + " impatience")
			if intent == "pawn":
				pawn[person] = true
				t.ok(int(c.get("term_days", 0)) > 0, id + " term_days")
		if intent == "buy":
			var cats = c.get("want", {}).get("cats", [])
			t.ok(typeof(cats) == TYPE_ARRAY and not cats.is_empty(), id + " want.cats")
		if intent == "redeem":
			redeem[person] = true
		var node := str(c.get("story_node", ""))
		if node != "":
			nodes[node] = id
		if bool(c.get("gold", false)):
			t.ok(node != "", id + " gold story_node")
		var used: Array = []
		_k05_strings(c, used)
		for key in used:
			t.ok(ui.has(key), "ui key registered " + str(key))
	for person in MAJORS:
		var n := int(by_person.get(person, 0))
		t.ok(n >= 2 and n <= 4, "%s card count %d" % [person, n])
	for person in NEW_FACES:
		var n2 := int(by_person.get(person, 0))
		t.ok(n2 >= 1 and n2 <= 2, "%s card count %d" % [person, n2])
	for person in SUN:
		t.ok(int(by_person.get(person, 0)) >= 1, "sun family " + person)
	for node in PERSON_NODES:
		t.ok(nodes.has(node), "person node card " + node)
	for node in EVENT_NODES:
		t.ok(not nodes.has(node), "event node left to K06 " + node)
	for person in pawn.keys():
		t.ok(redeem.has(person), "redeem card for pawn person " + person)
	for brief in briefs:
		var qerr := _quote_err(str(brief))
		t.eq(qerr, "", "brief quotes")
		var perr := _pseudo_err(str(brief))
		t.eq(perr, "", "pseudo wording: " + perr)
		for word in _banned():
			t.ok(str(brief).find(word) < 0, "brief bans a word")
	var dangling := {}
	var templates := _templates()
	var refs: Array = []
	_refs(cards, refs)
	for r in refs:
		var id := str(r)
		if id.begins_with("template:"):
			var tpl := id.substr(9)
			if not templates.has(tpl):
				dangling[tpl] = true
		elif id.begins_with("df.") or id.begins_with("dp.") or id.begins_with("kp.") or id.begins_with("ct."):
			if not db.has(id):
				dangling[id] = true
	var names: Array = dangling.keys()
	names.sort()
	for name in names:
		print("NOTE: dangling " + str(name))
	_close_day(t, cards, docs)
	t.finish()


func _close_day(t, cards: Array, docs: Array) -> void:
	for doc in docs:
		t.ok(not _has_field(doc, "stage"), "no stage block")
		t.ok(not _has_field(doc, "outcomes"), "no player outcome text")
	var gold_n := 0
	var redeem_n := 0
	var plain_n := 0
	var grudge_n := 0
	var seen := {}
	var follow_seen := {}
	var ops_used := {}
	for c in cards:
		var id := str(c.get("id", ""))
		var gold := bool(c.get("gold", false))
		var intent := str(c.get("intent", ""))
		var expire: Array = c.get("effects", {}).get("on_expire", [])
		if gold:
			gold_n += 1
			t.ok(not GRUDGE.has(id), id + " gold is not a grudge card")
			t.eq(intent, "story", id + " gold intent")
			var node := str(c.get("story_node", ""))
			var saw_ignored := false
			var saw_gap := false
			for e in expire:
				if str(e.get("op", "")) == "story" and str(e.get("node", "")) == node and str(e.get("outcome", "")) == "ignored":
					saw_ignored = true
				if str(e.get("op", "")) == "dossier_gap" and str(e.get("frag", "")) != "":
					saw_gap = true
			t.ok(saw_ignored, id + " gold on_expire story ignored")
			t.ok(saw_gap, id + " gold on_expire dossier_gap")
		elif intent == "redeem":
			redeem_n += 1
			plain_n += 1
			t.ok(expire.is_empty(), id + " redeem has no on_expire")
		else:
			plain_n += 1
			if GRUDGE.has(id):
				grudge_n += 1
				seen[id] = true
				var key := str(GRUDGE[id])
				t.ok(not expire.is_empty(), id + " grudge on_expire")
				t.ok(_cond_not_flag(c.get("conditions", {}), key), id + " hides after grudge")
				t.ok(str(c.get("brief", "")).find(key) >= 0, id + " brief names the grudge")
				var saw_flag := false
				for e in expire:
					var op := str(e.get("op", ""))
					t.ok(GRUDGE_OPS.has(op), id + " grudge op " + op)
					ops_used[op] = true
					if op == "flag" and str(e.get("key", "")) == key:
						saw_flag = true
				t.ok(saw_flag, id + " sets " + key)
			else:
				t.ok(expire.is_empty(), id + " no grudge on_expire")
		if FOLLOW_FLAG.has(id):
			follow_seen[id] = true
			var flag := str(FOLLOW_FLAG[id])
			t.ok(_cond_has(c.get("conditions", {}), "flag", flag), id + " reads " + flag)
			t.ok(str(c.get("brief", "")).find(flag) >= 0, id + " follow brief")
			t.ok(expire.is_empty(), id + " follow-up is not another on_expire")
		if FOLLOW_COUNTER.has(id):
			t.ok(_cond_has(c.get("conditions", {}), "counter_gte", str(FOLLOW_COUNTER[id])), id + " reads counter")
	t.ok(gold_n >= 3, "gold cards present")
	t.ok(redeem_n >= 1, "redeem cards present")
	t.eq(grudge_n, GRUDGE.size(), "grudge list complete")
	t.eq(seen.size(), GRUDGE.size(), "every grudge id exists")
	t.eq(follow_seen.size(), FOLLOW_FLAG.size(), "every grudge has a later card")
	t.ok(grudge_n >= 1 and grudge_n * 2 < plain_n, "grudge is a minority")
	for op in GRUDGE_OPS:
		t.ok(ops_used.has(op), "grudge uses op " + op)


func _has_field(v, name: String) -> bool:
	match typeof(v):
		TYPE_DICTIONARY:
			for k in v.keys():
				if str(k) == name:
					return true
				if _has_field(v[k], name):
					return true
		TYPE_ARRAY:
			for x in v:
				if _has_field(x, name):
					return true
	return false


func _cond_has(v, op: String, key: String) -> bool:
	match typeof(v):
		TYPE_DICTIONARY:
			if v.has(op):
				var val = v[op]
				if op == "flag" and str(val) == key:
					return true
				if op == "counter_gte" and typeof(val) == TYPE_ARRAY and val.size() >= 1 and str(val[0]) == key:
					return true
			for k in v.keys():
				if _cond_has(v[k], op, key):
					return true
		TYPE_ARRAY:
			for x in v:
				if _cond_has(x, op, key):
					return true
	return false


func _cond_not_flag(v, key: String) -> bool:
	match typeof(v):
		TYPE_DICTIONARY:
			if v.has("not") and typeof(v["not"]) == TYPE_DICTIONARY and str(v["not"].get("flag", "")) == key:
				return true
			for k in v.keys():
				if _cond_not_flag(v[k], key):
					return true
		TYPE_ARRAY:
			for x in v:
				if _cond_not_flag(x, key):
					return true
	return false


func _pair(v) -> bool:
	return typeof(v) == TYPE_ARRAY and v.size() == 2 and typeof(v[0]) == TYPE_INT and typeof(v[1]) == TYPE_INT


func _banned() -> Array:
	return [
		"\u672c\u5fc3",
		"\u5e95\u4ef7",
		"\u771f\u5047",
		"\u6982\u7387",
		"\u6297\u6218\u80dc\u5229",
		"\u80dc\u5229",
		"%",
	]


func _each_brief(v, acc: Array) -> void:
	match typeof(v):
		TYPE_DICTIONARY:
			for k in v.keys():
				var ks := str(k)
				if ks == "brief" and typeof(v[k]) == TYPE_STRING:
					acc.append(v[k])
				elif ks == "_meta":
					_each_brief(v[k], acc)
				elif ks.begins_with("_"):
					continue
				else:
					_each_brief(v[k], acc)
		TYPE_ARRAY:
			for x in v:
				_each_brief(x, acc)


func _cjk_outside(v, path: String, bad: Array) -> void:
	match typeof(v):
		TYPE_STRING:
			if _cjk.search(v) != null:
				bad.append(path)
		TYPE_DICTIONARY:
			for k in v.keys():
				var ks := str(k)
				if ks == "brief" or ks.begins_with("_"):
					continue
				if _cjk.search(ks) != null:
					bad.append(path + "." + ks)
				_cjk_outside(v[k], path + "." + ks, bad)
		TYPE_ARRAY:
			for i in range(v.size()):
				_cjk_outside(v[i], "%s[%d]" % [path, i], bad)


func _floats(v, bad: Array) -> void:
	match typeof(v):
		TYPE_FLOAT:
			bad.append(str(v))
		TYPE_DICTIONARY:
			for k in v.keys():
				if not str(k).begins_with("_"):
					_floats(v[k], bad)
		TYPE_ARRAY:
			for x in v:
				_floats(x, bad)


func _k05_strings(v, acc: Array) -> void:
	match typeof(v):
		TYPE_DICTIONARY:
			for k in v.keys():
				var ks := str(k)
				if ks == "brief" or ks.begins_with("_"):
					continue
				_k05_strings(v[k], acc)
		TYPE_ARRAY:
			for x in v:
				_k05_strings(x, acc)
		TYPE_STRING:
			if v.begins_with("k05."):
				acc.append(v)


func _refs(v, acc: Array) -> void:
	match typeof(v):
		TYPE_DICTIONARY:
			var op := str(v.get("op", ""))
			if (op == "dossier" or op == "dossier_gap") and v.has("frag"):
				acc.append(str(v["frag"]))
			if op == "add_card" and v.has("card"):
				acc.append(str(v["card"]))
			if op == "item_gain" and v.has("template"):
				acc.append("template:" + str(v["template"]))
			if v.has("template") and str(v.get("op", "")) == "" and typeof(v.get("template")) == TYPE_STRING:
				acc.append("template:" + str(v["template"]))
			for k in v.keys():
				var ks := str(k)
				if ks == "brief" or ks.begins_with("_"):
					continue
				_refs(v[k], acc)
		TYPE_ARRAY:
			for x in v:
				_refs(x, acc)


func _templates() -> Dictionary:
	var known := {}
	for path in ["res://data/town/item_templates.json", "res://data/cards/items/templates_extra.json"]:
		var doc = CardDB.read_json(path)
		if typeof(doc) != TYPE_DICTIONARY:
			continue
		for cat in doc.get("categories", {}).keys():
			for v in doc["categories"][cat].get("variants", []):
				known["%s.%s" % [str(cat), str(v.get("id", ""))]] = true
	return known


func _quote_err(text: String) -> String:
	var pairs := [
		["\u201c", "\u201d"],
		["\u2018", "\u2019"],
		["\u300c", "\u300d"],
		["\u300e", "\u300f"],
	]
	for pair in pairs:
		var i := 0
		while true:
			var a := text.find(pair[0], i)
			if a < 0:
				break
			var b := text.find(pair[1], a + 1)
			if b < 0:
				return "unclosed"
			var inner := text.substr(a + 1, b - a - 1)
			if inner.length() > 12:
				return "long"
			if inner.find("\u3002") >= 0 or inner.find("\uff01") >= 0 or inner.find("\uff1f") >= 0:
				return "punct"
			i = b + 1
	return ""


func _pseudo_err(text: String) -> String:
	var ng := "\u56fd\u6c11\u653f\u5e9c"
	var wangwei := "\u6c6a\u4f2a"
	var wei := "\u4f2a"
	var i := 0
	while true:
		var j := text.find(ng, i)
		if j < 0:
			break
		if j < 2 or text.substr(j - 2, 2) != wangwei:
			return "guomin"
		i = j + ng.length()
	for key in ["\u7ef4\u65b0\u653f\u5e9c", "\u7ef4\u6301\u4f1a", "\u53bf\u653f\u5e9c"]:
		i = 0
		while true:
			var j2 := text.find(key, i)
			if j2 < 0:
				break
			if j2 < 1 or text.substr(j2 - 1, 1) != wei:
				return "wei"
			i = j2 + key.length()
	return ""
