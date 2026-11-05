# K01 data checks for 1938 people, story nodes, and passersby.
# Dangling refs are printed as NOTE and do not fail the test.
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")

const FILES := [
	"era/1938/people.json",
	"era/1938/story.json",
	"era/common/passersby.json",
]
const MAINS := [
	"brother", "chen", "xiaoding", "zhang", "wangshan", "li", "linsao", "zhouma",
	"zhao", "sunyoung", "ma", "hu2", "sunlaoye", "guanjia", "wu", "postman",
]
const FACES := ["nf1938a", "nf1938b", "nf1938c", "nf1938d"]
const ARCH := [
	"stranger_refugee", "stranger_peddler", "stranger_collector", "stranger_fence",
	"stranger_waixiang", "stranger_boatman", "stranger_student", "stranger_widow",
]
const NODES := [
	"s1938.brother_farewell", "s1938.ticket196", "s1938.wangshan",
	"s1938.zhao_borrow", "s1938.linsao_term", "s1938.ma_levy",
]


func _initialize() -> void:
	var t := T.new(self, "K01_data")
	var db := CardDB.load_all("res://data/cards", {})
	t.eq(db.errors(), PackedStringArray(), "CardDB load errors")
	var mine := _mine(db)
	_counts(t, db, mine)
	_each(t, db, mine)
	_pawn_redeem(t, mine)
	_briefs_and_keys(t, db, mine)
	_story_roads(t, mine)
	_close_shop(t, db, mine)
	_dangling(db)
	t.finish()


func _mine(db: CardDB) -> Array:
	var out: Array = []
	for id in db.all_ids():
		if FILES.has(db.file_of(id)):
			out.append(db.def(id))
	return out


func _counts(t, db: CardDB, mine: Array) -> void:
	var n_person := 0
	var by_person := {}
	var nodes := {}
	for c in mine:
		var id := str(c.get("id", ""))
		var rel := db.file_of(id)
		if str(c.get("type", "")) == "person" and (rel == "era/1938/people.json" or rel == "era/common/passersby.json"):
			n_person += 1
		if str(c.get("type", "")) == "person":
			var person := str(c.get("person", ""))
			var era: Array = c.get("era", [])
			if era.has("1938"):
				by_person[person] = int(by_person.get(person, 0)) + 1
		if rel == "era/1938/story.json" and str(c.get("story_node", "")) != "":
			nodes[str(c.get("story_node"))] = true
	t.ok(n_person >= 40, "person cards in people+passersby = %d" % n_person)
	for person in MAINS:
		if person == "brother":
			continue
		t.ok(int(by_person.get(person, 0)) >= 2, "%s 1938 cards = %d" % [person, int(by_person.get(person, 0))])
	for face in FACES:
		t.ok(int(by_person.get(face, 0)) >= 1, "%s cards" % face)
	for arch in ARCH:
		var n := 0
		for c in mine:
			if str(c.get("person", "")) == arch:
				n += 1
		t.ok(n >= 1, "%s cards = %d" % [arch, n])
	for node in NODES:
		t.ok(nodes.has(node), "story node %s" % node)
	t.ok(db.has("tk.1938.de196"), "tk.1938.de196")
	var people = CardDB.read_json("res://data/cards/era/1938/people.json")
	var persons: Dictionary = people.get("persons", {})
	for face in FACES:
		t.ok(persons.has(face), "persons %s" % face)
		t.eq(str(persons[face].get("portrait", "")), "portrait." + face, face)
		t.eq(bool(persons[face].get("dossier", false)), true, "%s dossier" % face)
	var pb = CardDB.read_json("res://data/cards/era/common/passersby.json")
	var pp: Dictionary = pb.get("persons", {})
	for arch in ARCH:
		t.ok(pp.has(arch), "passer %s" % arch)
		t.eq(str(pp[arch].get("portrait", "")), "portrait." + arch, arch)
	t.ok(pp.has("suanming"), "suanming in passersby")


func _each(t, db: CardDB, mine: Array) -> void:
	var date_re := RegEx.create_from_string("^\\d{4}-\\d{2}-\\d{2}$")
	for c in mine:
		var id := str(c.get("id", ""))
		var typ := str(c.get("type", ""))
		var rel := db.file_of(id)
		if typ == "person":
			t.ok(id.begins_with("p."), "%s prefix" % id)
		elif typ == "pawn_ticket":
			t.ok(id.begins_with("tk."), "%s prefix" % id)
		else:
			t.ok(false, "%s unexpected type %s" % [id, typ])
		var era: Array = c.get("era", [])
		if rel == "era/common/passersby.json":
			t.eq(era, ["*"], "%s era" % id)
		else:
			t.eq(era, ["1938"], "%s era" % id)
		var pv: Dictionary = c.get("_provenance", {})
		t.eq(str(pv.get("task", "")), "K01", "%s task" % id)
		t.ok(date_re.search(str(pv.get("date", ""))) != null, "%s date" % id)
		t.ok(str(c.get("brief", "")).strip_edges() != "", "%s brief" % id)
		var omen := false
		for tag in c.get("tags", []):
			var ts := str(tag)
			if ts.begins_with("omen_"):
				omen = true
			t.ok(db.tags().has(ts), "%s tag %s" % [id, ts])
		t.ok(omen, "%s omen" % id)
		var intent := str(c.get("intent", ""))
		if intent == "pawn" or intent == "sell":
			var item: Dictionary = c.get("item", {})
			t.ok(item.has("template") or item.has("cat"), "%s item" % id)
			t.ok(_pair(c.get("asking", {}).get("pct", null)), "%s asking" % id)
			t.ok(_pair(c.get("floor", {}).get("pct", null)), "%s floor" % id)
			t.ok(_pair(c.get("patience_min", null)), "%s patience" % id)
		if intent == "buy":
			var cats = c.get("want", {}).get("cats", [])
			t.ok(typeof(cats) == TYPE_ARRAY and (cats as Array).size() > 0, "%s want.cats" % id)
		if c.has("minigame"):
			t.eq(id, "tk.1938.de196", "%s minigame" % id)
	var tk := db.def("tk.1938.de196")
	t.eq(int(tk.get("number", -1)), 196, "ticket number")
	t.eq(str(tk.get("item_template", "")), "documents.receipt", "ticket template")
	t.eq(bool(tk.get("foreign", false)), true, "ticket foreign")
	t.eq(bool(tk.get("keepable", false)), true, "ticket keepable")
	t.eq(bool(tk.get("must_resolve", true)), false, "ticket must_resolve")
	t.eq(str(tk.get("minigame", "")), "fragments", "ticket minigame")
	t.eq(int(tk.get("weight", -1)), 0, "ticket weight")


func _pawn_redeem(t, mine: Array) -> void:
	var pawn := {}
	var redeem := {}
	for c in mine:
		var person := str(c.get("person", ""))
		if not MAINS.has(person):
			continue
		var intent := str(c.get("intent", ""))
		if intent == "pawn":
			pawn[person] = true
		if intent == "redeem":
			redeem[person] = true
	for person in pawn.keys():
		t.ok(redeem.has(person), "%s pawn without redeem" % person)


func _briefs_and_keys(t, db: CardDB, mine: Array) -> void:
	var ui := db.ui_keys()
	for c in mine:
		_keys(c, t, ui, str(c.get("id", "")))
	var files := FILES.duplicate()
	files.append("tags/K01.json")
	files.append("ui_keys/K01.json")
	for rel in files:
		var briefs: Array = []
		_collect_briefs(CardDB.read_json("res://data/cards/" + rel), briefs)
		for b in briefs:
			var s := str(b)
			var q := _quote_err(s)
			t.ok(q == "", "%s quote: %s" % [rel, q])
			t.ok(_wei_ok(s), "%s missing wei prefix" % rel)
			t.ok(_clean(s), "%s hidden-number word" % rel)


func _story_roads(t, mine: Array) -> void:
	var made := {}
	var need := {}
	for c in mine:
		_roads(c, made, need)
	for key in need.keys():
		t.ok(made.has(key), "story condition without outcome %s" % key)


# 打烊：少数记仇；金色牌仍是 story ignored + dossier_gap；赎牌不写；不许 stage。
func _close_shop(t, db: CardDB, mine: Array) -> void:
	var files := FILES.duplicate()
	files.append("tags/K01.json")
	files.append("ui_keys/K01.json")
	for rel in files:
		t.ok(not _has_key(CardDB.read_json("res://data/cards/" + rel), "stage"), "%s has stage" % rel)
	var grudges := {
		"p.linsao.1938.pawn_hairpin": ["flag", "rep"],
		"p.ma.1938.ask_names": ["flag", "counter", "rep"],
		"p.guanjia.1938.help_rice": ["flag", "counter"],
		"p.sunlaoye.1938.ask_land": ["flag", "rep"],
	}
	var roads := {
		"p.linsao.1938.help_wait": "grudge_linsao",
		"p.ma.1938.sell_rice": "grudge_ma",
		"p.hu2.1938.sell_ring": "snub_ma",
		"p.guanjia.1938.ask_ledger": "grudge_guanjia",
		"p.sunyoung.1938.buy_jade": "snub_guanjia",
		"p.sunlaoye.1938.buy_field": "grudge_sunlaoye",
	}
	var allowed := ["flag", "rep", "counter", "person_state"]
	for c in mine:
		var id := str(c.get("id", ""))
		var gold := bool(c.get("gold", false))
		var intent := str(c.get("intent", ""))
		var fx = c.get("effects", {})
		var has_expire := typeof(fx) == TYPE_DICTIONARY and (fx as Dictionary).has("on_expire")
		if gold:
			t.ok(_gold_expire(c), "%s gold story+dossier_gap" % id)
		elif intent == "redeem":
			t.ok(not has_expire, "%s redeem has on_expire" % id)
		elif grudges.has(id):
			t.ok(has_expire, "%s missing on_expire" % id)
			var expire: Array = (fx as Dictionary).get("on_expire", [])
			t.ok(expire.size() > 0, "%s empty on_expire" % id)
			var ops: Array = []
			for e in expire:
				t.ok(typeof(e) == TYPE_DICTIONARY, "%s effect object" % id)
				if typeof(e) != TYPE_DICTIONARY:
					continue
				var err := CardDslShapes.check_effect(e)
				t.eq(err, "", "%s op shape" % id)
				var op := str(e.get("op", ""))
				t.ok(allowed.has(op), "%s illegal op %s" % [id, op])
				t.ok(_grudge_shape(e), "%s grudge shape %s" % [id, op])
				ops.append(op)
			t.eq(ops, grudges[id], "%s ops" % id)
			t.ok(str(c.get("brief", "")).find("没接") >= 0, "%s brief names 没接" % id)
			t.ok(not bool(c.get("gold", false)) and intent != "redeem", "%s grudge is gold or redeem" % id)
		else:
			t.ok(not has_expire, "%s unexpected on_expire" % id)
	for rid in roads.keys():
		t.ok(_mentions(db.def(str(rid)), str(roads[rid])), "%s does not read %s" % [rid, roads[rid]])


func _gold_expire(c: Dictionary) -> bool:
	var node := str(c.get("story_node", ""))
	var fx = c.get("effects", {})
	if typeof(fx) != TYPE_DICTIONARY or node == "":
		return false
	var story_ok := false
	var gap_ok := false
	for e in (fx as Dictionary).get("on_expire", []):
		if typeof(e) != TYPE_DICTIONARY:
			continue
		if str(e.get("op", "")) == "story":
			var outcome := str(e.get("outcome", ""))
			if outcome != "" and outcome == "ignored" and str(e.get("node", "")) == node:
				story_ok = true
		if str(e.get("op", "")) == "dossier_gap" and str(e.get("frag", "")) != "":
			gap_ok = true
	return story_ok and gap_ok


func _grudge_shape(e: Dictionary) -> bool:
	var op := str(e.get("op", ""))
	if op == "flag":
		return str(e.get("key", "")).begins_with("grudge_")
	if op == "rep":
		return int(e.get("delta", 0)) == -1 and not e.has("tier")
	if op == "counter":
		return str(e.get("key", "")).begins_with("snub_") and int(e.get("delta", 0)) == 1
	if op == "person_state":
		var st := str(e.get("state", ""))
		return ["ok", "hurt", "jailed", "away", "gone", "changed"].has(st)
	return false


func _has_key(node, key: String) -> bool:
	if typeof(node) == TYPE_DICTIONARY:
		for k in node.keys():
			if str(k) == key or _has_key(node[k], key):
				return true
	elif typeof(node) == TYPE_ARRAY:
		for x in node:
			if _has_key(x, key):
				return true
	return false


func _mentions(node, needle: String) -> bool:
	if typeof(node) == TYPE_STRING or typeof(node) == TYPE_STRING_NAME:
		return str(node) == needle
	if typeof(node) == TYPE_DICTIONARY:
		for k in node.keys():
			if _mentions(node[k], needle):
				return true
	elif typeof(node) == TYPE_ARRAY:
		for x in node:
			if _mentions(x, needle):
				return true
	return false


func _dangling(db: CardDB) -> void:
	var templates = CardDB.read_json("res://data/town/item_templates.json")
	var extra = CardDB.read_json("res://data/cards/items/templates_extra.json")
	if typeof(extra) == TYPE_DICTIONARY:
		for cat in extra.get("categories", {}).keys():
			if not templates.get("categories", {}).has(cat):
				templates["categories"][cat] = extra["categories"][cat]
	var found := {}
	for rel in FILES:
		_scan_refs(CardDB.read_json("res://data/cards/" + rel), db, templates, found)
	var keys: Array = found.keys()
	keys.sort()
	for k in keys:
		print("NOTE: dangling %s" % str(k))


func _keys(node, t, ui: Dictionary, id: String) -> void:
	if typeof(node) == TYPE_DICTIONARY:
		if str(node.get("op", "")) == "notice":
			var k := str(node.get("key", ""))
			t.ok(k.begins_with("k01."), "%s notice %s" % [id, k])
			t.ok(ui.has(k), "%s notice missing %s" % [id, k])
		if node.has("reason") and typeof(node["reason"]) == TYPE_STRING:
			var r := str(node["reason"])
			t.ok(r.begins_with("k01."), "%s reason %s" % [id, r])
			t.ok(ui.has(r), "%s reason missing %s" % [id, r])
		for k in node.keys():
			_keys(node[k], t, ui, id)
	elif typeof(node) == TYPE_ARRAY:
		for x in node:
			_keys(x, t, ui, id)


func _collect_briefs(node, acc: Array) -> void:
	if typeof(node) == TYPE_DICTIONARY:
		for k in node.keys():
			var key := str(k)
			if key == "brief" and typeof(node[k]) == TYPE_STRING:
				acc.append(node[k])
			if key.begins_with("_") and key != "_meta":
				continue
			_collect_briefs(node[k], acc)
	elif typeof(node) == TYPE_ARRAY:
		for x in node:
			_collect_briefs(x, acc)


func _roads(node, made: Dictionary, need: Dictionary) -> void:
	if typeof(node) == TYPE_DICTIONARY:
		if str(node.get("op", "")) == "story":
			made["%s|%s" % [str(node.get("node", "")), str(node.get("outcome", ""))]] = true
		if node.has("story") and typeof(node["story"]) == TYPE_ARRAY and (node["story"] as Array).size() == 2:
			need["%s|%s" % [str(node["story"][0]), str(node["story"][1])]] = true
		for k in node.keys():
			_roads(node[k], made, need)
	elif typeof(node) == TYPE_ARRAY:
		for x in node:
			_roads(x, made, need)


func _scan_refs(node, db: CardDB, templates: Dictionary, found: Dictionary) -> void:
	if typeof(node) == TYPE_DICTIONARY:
		for k in node.keys():
			var key := str(k)
			var v = node[k]
			if (key == "template" or key == "item_template") and typeof(v) == TYPE_STRING:
				if not _tpl(str(v), templates):
					found[str(v)] = true
			if typeof(v) == TYPE_STRING:
				var s := str(v)
				if _is_ref(s) and not db.has(s):
					found[s] = true
			else:
				_scan_refs(v, db, templates, found)
	elif typeof(node) == TYPE_ARRAY:
		for x in node:
			_scan_refs(x, db, templates, found)


func _is_ref(s: String) -> bool:
	return s.begins_with("df.") or s.begins_with("dp.") or s.begins_with("kp.") or s.begins_with("ct.")


func _tpl(s: String, templates: Dictionary) -> bool:
	var parts := s.split(".")
	if parts.size() != 2:
		return false
	var cats: Dictionary = templates.get("categories", {})
	if not cats.has(parts[0]):
		return false
	for v in cats[parts[0]].get("variants", []):
		if str(v.get("id", "")) == parts[1]:
			return true
	return false


func _pair(v) -> bool:
	if typeof(v) != TYPE_ARRAY or (v as Array).size() != 2:
		return false
	for x in v:
		if typeof(x) != TYPE_INT and typeof(x) != TYPE_FLOAT:
			return false
	return int(v[0]) <= int(v[1])


func _quote_err(s: String) -> String:
	var pairs := [["\u201c", "\u201d"], ["\u2018", "\u2019"], ["\u300c", "\u300d"]]
	var bad := ["\u3002", "\uff01", "\uff1f"]
	for pair in pairs:
		var i := 0
		var open := str(pair[0])
		var close := str(pair[1])
		while true:
			var a := s.find(open, i)
			if a < 0:
				break
			var b := s.find(close, a + 1)
			if b < 0:
				return "unclosed"
			var inner := s.substr(a + open.length(), b - a - open.length())
			if inner.length() > 12:
				return "long"
			for ch in bad:
				if inner.find(str(ch)) >= 0:
					return "punct"
			i = b + 1
	return ""


func _wei_ok(s: String) -> bool:
	var words := ["\u7ef4\u6301\u4f1a", "\u7ef4\u65b0\u653f\u5e9c", "\u53bf\u653f\u5e9c"]
	for w in words:
		var i := 0
		while true:
			var a := s.find(w, i)
			if a < 0:
				break
			if a == 0 or s.substr(a - 1, 1) != "\u4f2a":
				return false
			i = a + w.length()
	return true


func _clean(s: String) -> bool:
	var words := ["\u6982\u7387", "\u672c\u5fc3", "\u5e95\u4ef7", "\u771f\u5047", "\u70b9\u6570", "\u6743\u91cd", "\u767e\u5206\u6bd4", "%"]
	for w in words:
		if s.find(w) >= 0:
			return false
	return true
