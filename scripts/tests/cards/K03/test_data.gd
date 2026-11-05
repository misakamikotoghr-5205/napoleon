# K03 data checks: counts, ids, tags, keys, briefs, dangling refs, close-of-day grudges.
# Contract: docs/cards/CARDS_INTERFACES.md ; task: docs/handoff_cards/K03_data-1939-people.md
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")

const MAJORS: Array[String] = [
	"brother", "chen", "xiaoding", "zhang", "wangshan", "li", "linsao", "zhouma", "zhao",
	"sunyoung", "ma", "hu2", "sunlaoye", "guanjia", "wu", "postman",
]
const PRESENT: Array[String] = [
	"chen", "xiaoding", "zhang", "wangshan", "li", "linsao", "zhouma", "zhao",
	"sunyoung", "ma", "hu2", "sunlaoye", "guanjia", "wu", "postman",
]
const NEW_FACES: Array[String] = ["nf1939a", "nf1939b", "nf1939c", "nf1939d"]
const OUR_NODES: Array[String] = ["s1939.year_end", "s1939.brother_letter", "s1939.wangshan_whereabouts"]
const K04_NODES: Array[String] = ["s1939.gate_check", "s1939.wu_price"]
const FORBIDDEN: Array[String] = ["\u6982\u7387", "\u672c\u5fc3", "\u5e95\u4ef7", "\u771f\u5047", "\u771f\u503c", "%", "\uff05"]
const QUOTES := {"\u201c": "\u201d", "\u2018": "\u2019", "\u300c": "\u300d", "\u300e": "\u300f"}
const BANNED_KEYS: Array[String] = ["stage", "text", "title", "body", "label", "name", "lines", "desc"]
const GRUDGE_IDS: Array[String] = [
	"p.ma.1939.ask_hard",
	"p.wu.1939.sell_rice",
	"p.sunlaoye.1939.buy_deed",
	"p.nf1939d.1939.ask_office",
]
const GRUDGE_OPS: Array[String] = ["flag", "rep", "counter", "person_state"]


func _initialize() -> void:
	var t := T.new(self, "K03_data")
	var db := CardDB.load_all("res://data/cards", {})
	t.eq(db.errors(), PackedStringArray(), "CardDB load")
	var cards := _our_cards(db)
	t.ok(cards.size() >= 36, "person cards >= 36, got %d" % cards.size())
	var by_person := {}
	var pawn_people := {}
	var redeem_people := {}
	var nodes := {}
	var id_re := RegEx.create_from_string("^p\\.[a-z0-9_]+\\.1939\\.[a-z0-9_]+$")
	var date_re := RegEx.create_from_string("^\\d{4}-\\d{2}-\\d{2}$")
	var tags: Dictionary = db.tags()
	var ui: Dictionary = db.ui_keys()
	var refs := {}
	for c in cards:
		var id := str(c["id"])
		var person := str(c["person"])
		by_person[person] = int(by_person.get(person, 0)) + 1
		t.ok(id_re.search(id) != null, id + " id shape")
		var era: Array = c["era"]
		t.ok(era.size() == 1 and str(era[0]) == "1939", id + " era")
		var pv: Dictionary = c.get("_provenance", {})
		t.eq(str(pv.get("by", "")), "ai", id + " provenance.by")
		t.eq(str(pv.get("task", "")), "K03", id + " provenance.task")
		t.ok(date_re.search(str(pv.get("date", ""))) != null, id + " provenance.date")
		t.eq(str(pv.get("date", "")), "2026-10-13", id + " provenance date value")
		t.eq(str(c.get("art", "")), "portrait." + person, id + " art")
		t.ok(not c.has("minigame"), id + " must not fix a minigame")
		var brief := str(c.get("brief", ""))
		_brief_ok(t, id, brief)
		_briefs_in(t, id, c)
		var omen := false
		for tag in c.get("tags", []):
			var ts := str(tag)
			if ts.begins_with("omen_"):
				omen = true
			t.ok(tags.has(ts), id + " tag not declared: " + ts)
		t.ok(omen, id + " needs omen_*")
		var intent := str(c.get("intent", ""))
		if intent == "pawn" or intent == "sell":
			var item: Dictionary = c.get("item", {})
			t.ok(item.has("template") or item.has("cat"), id + " item")
			t.ok(_pct_ok(c.get("asking")), id + " asking")
			t.ok(_pct_ok(c.get("floor")), id + " floor")
			t.ok(_range_ok(c.get("patience_min")), id + " patience_min")
		if intent == "buy":
			var want: Dictionary = c.get("want", {})
			var cats: Array = want.get("cats", [])
			t.ok(not cats.is_empty(), id + " want.cats")
		if intent == "ask" or intent == "help" or intent == "story":
			var choices: Array = c.get("choices", [])
			t.ok(choices.size() >= 2, id + " needs choices")
		if intent == "pawn" and MAJORS.has(person):
			pawn_people[person] = true
		if intent == "redeem" and MAJORS.has(person):
			redeem_people[person] = true
		if str(c.get("story_node", "")) != "":
			nodes[str(c["story_node"])] = id
		_collect_refs(c, refs)
		_keys_ok(t, id, c, ui)
	t.ok(not by_person.has("brother"), "brother has left; no 1939 pool card")
	for person in PRESENT:
		var n := int(by_person.get(person, 0))
		t.ok(n >= 2 and n <= 4, person + " card count %d not in 2-4" % n)
	for nf in NEW_FACES:
		var n2 := int(by_person.get(nf, 0))
		t.ok(n2 >= 1 and n2 <= 2, nf + " card count %d" % n2)
		var reg: Dictionary = db.persons().get(nf, {})
		t.eq(str(reg.get("portrait", "")), "portrait." + nf, nf + " portrait")
		t.eq(reg.get("dossier", false), true, nf + " dossier")
		_brief_ok(t, nf, str(reg.get("brief", "")))
	for person in pawn_people.keys():
		t.ok(redeem_people.has(person), person + " has pawn but no redeem")
	for node in OUR_NODES:
		t.ok(nodes.has(node), "missing story node " + node)
		var host: Dictionary = db.def(str(nodes[node]))
		t.eq(host.get("gold", false), true, node + " card is gold")
		t.eq(db.file_of(str(nodes[node])), "era/1939/story.json", node + " lives in story.json")
	for node2 in K04_NODES:
		t.ok(not nodes.has(node2), "K04 node must not be in K03: " + node2)
	var known := _known_ids(db)
	var dangling: Array = refs.keys()
	dangling.sort()
	for ref in dangling:
		if not known.has(str(ref)):
			print("NOTE: dangling " + str(ref))
	_close_ok(t, cards)
	t.finish()


func _our_cards(db: CardDB) -> Array:
	var out: Array = []
	for id in db.ids_of(&"person"):
		var rel := db.file_of(id)
		if rel == "era/1939/people.json" or rel == "era/1939/story.json":
			out.append(db.def(id))
	return out


func _pct_ok(box) -> bool:
	if typeof(box) != TYPE_DICTIONARY:
		return false
	return _range_ok((box as Dictionary).get("pct"))


func _range_ok(pair) -> bool:
	if typeof(pair) != TYPE_ARRAY or (pair as Array).size() != 2:
		return false
	return CardDslShapes.is_int(pair[0]) and CardDslShapes.is_int(pair[1])


func _brief_ok(t, id: String, brief: String) -> void:
	t.ok(brief.strip_edges() != "", id + " empty brief")
	for bad in FORBIDDEN:
		t.ok(not brief.contains(bad), id + " brief contains " + bad)
	for word in ["\u53bf\u653f\u5e9c", "\u533a\u516c\u6240", "\u7ef4\u6301\u4f1a"]:
		var from := 0
		while true:
			var at := brief.find(word, from)
			if at < 0:
				break
			t.ok(at > 0 and brief.substr(at - 1, 1) == "\u4f2a", id + " missing wei before " + word)
			from = at + word.length()
	var i := 0
	while i < brief.length():
		var ch := brief.substr(i, 1)
		if QUOTES.has(ch):
			var j := brief.find(str(QUOTES[ch]), i + 1)
			t.ok(j > i, id + " unclosed quote")
			if j > i:
				var inner := brief.substr(i + 1, j - i - 1)
				t.ok(inner.length() <= 12, id + " quote longer than 12")
				t.ok(inner.find("\u3002") < 0 and inner.find("\uff01") < 0 and inner.find("\uff1f") < 0, id + " quote looks like dialogue")
				i = j + 1
				continue
		i += 1


func _briefs_in(t, id: String, v) -> void:
	if typeof(v) == TYPE_DICTIONARY:
		for k in v.keys():
			if str(k) == "brief" and typeof(v[k]) == TYPE_STRING and str(k) != "":
				if v != null:
					_brief_ok(t, id + "#" + str(k), str(v[k]))
			else:
				_briefs_in(t, id, v[k])
	elif typeof(v) == TYPE_ARRAY:
		for item in v:
			_briefs_in(t, id, item)


func _keys_ok(t, id: String, v, ui: Dictionary) -> void:
	if typeof(v) == TYPE_DICTIONARY:
		var op := str(v.get("op", ""))
		if op == "notice":
			var key := str(v.get("key", ""))
			t.ok(key.begins_with("k03."), id + " notice key " + key)
			t.ok(ui.has(key), id + " notice key not registered " + key)
		if op == "money" or op == "pay" or op == "item_lose" or op == "arrest":
			var reason := str(v.get("reason", ""))
			t.ok(reason.begins_with("k03."), id + " reason " + reason)
			t.ok(ui.has(reason), id + " reason not registered " + reason)
		for k in v.keys():
			_keys_ok(t, id, v[k], ui)
	elif typeof(v) == TYPE_ARRAY:
		for item in v:
			_keys_ok(t, id, item, ui)


func _close_ok(t, cards: Array) -> void:
	var grudges := {}
	var golds := 0
	var redeems := 0
	var non_gold := 0
	for c in cards:
		var id := str(c["id"])
		_ban_keys(t, id, c)
		var intent := str(c.get("intent", ""))
		var gold: bool = c.get("gold", false) == true
		var fx: Dictionary = c.get("effects", {})
		if intent == "redeem":
			redeems += 1
			t.ok(not fx.has("on_expire"), id + " redeem must not have on_expire")
		if gold:
			golds += 1
			_gold_expire(t, c)
		else:
			non_gold += 1
			if fx.has("on_expire"):
				var expire: Array = fx["on_expire"]
				t.ok(not expire.is_empty(), id + " empty on_expire")
				grudges[id] = true
				_grudge_expire(t, id, expire)
				t.ok(str(c.get("brief", "")).contains("\u6253\u70ca\u6ca1\u63a5"), id + " brief says an unanswered visit turns into a grudge")
	t.eq(grudges.size(), GRUDGE_IDS.size(), "grudge card count")
	for gid in GRUDGE_IDS:
		t.ok(grudges.has(gid), "missing grudge card " + gid)
	for gid2 in grudges.keys():
		t.ok(GRUDGE_IDS.has(str(gid2)), "unexpected on_expire " + str(gid2))
	t.ok(grudges.size() >= 3 and grudges.size() <= 6, "only a few people hold a grudge")
	t.ok(grudges.size() * 2 < non_gold, "most guests do not write on_expire")
	t.ok(golds >= 1, "gold cards stay in the set")
	t.ok(redeems >= 4, "redeem cards stay in the set")
	var by := {}
	for c2 in cards:
		by[str(c2["id"])] = c2
	_follow(t, by, "p.ma.1939.ask_grudge", "counter", "snub_ma")
	_follow(t, by, "p.wu.1939.ask_cold", "flag", "grudge_wu")
	_follow(t, by, "p.guanjia.1939.ask_snub", "flag", "grudge_sunlaoye")
	_follow(t, by, "p.nf1939d.1939.ask_return", "counter", "snub_nf1939d")


func _gold_expire(t, c: Dictionary) -> void:
	var id := str(c.get("id", ""))
	var fx: Dictionary = c.get("effects", {})
	var expire: Array = fx.get("on_expire", [])
	t.ok(not expire.is_empty(), id + " gold on_expire")
	var story := false
	var gap := false
	for e in expire:
		if typeof(e) != TYPE_DICTIONARY:
			t.ok(false, id + " gold expire entry")
			continue
		var op := str(e.get("op", ""))
		t.ok(op != "flag" and op != "rep" and op != "counter", id + " gold is not a grudge op " + op)
		if op == "story":
			t.eq(str(e.get("outcome", "")), "ignored", id + " gold ignored")
			t.eq(str(e.get("node", "")), str(c.get("story_node", "")), id + " gold node")
			story = true
		elif op == "dossier_gap":
			t.ok(str(e.get("frag", "")) != "", id + " dossier_gap")
			gap = true
	t.ok(story and gap, id + " on_expire story ignored + dossier_gap")
	t.ok(str(c.get("brief", "")).contains("\u6253\u70ca"), id + " gold brief says what ignoring does")


func _grudge_expire(t, id: String, expire: Array) -> void:
	var ops := {}
	for e in expire:
		t.ok(typeof(e) == TYPE_DICTIONARY, id + " expire entry")
		if typeof(e) != TYPE_DICTIONARY:
			continue
		var op := str(e.get("op", ""))
		t.ok(GRUDGE_OPS.has(op), id + " grudge op " + op)
		ops[op] = e
	if id == "p.ma.1939.ask_hard":
		_need_ops(t, id, ops, ["flag", "rep", "counter"])
		if ops.has("flag"):
			t.eq(str(ops["flag"].get("key", "")), "grudge_ma", id + " flag")
		if ops.has("counter"):
			t.eq(str(ops["counter"].get("key", "")), "snub_ma", id + " counter")
	elif id == "p.wu.1939.sell_rice":
		_need_ops(t, id, ops, ["flag", "rep"])
		if ops.has("flag"):
			t.eq(str(ops["flag"].get("key", "")), "grudge_wu", id + " flag")
	elif id == "p.sunlaoye.1939.buy_deed":
		_need_ops(t, id, ops, ["flag", "rep", "person_state"])
		if ops.has("flag"):
			t.eq(str(ops["flag"].get("key", "")), "grudge_sunlaoye", id + " flag")
		if ops.has("person_state"):
			t.eq(str(ops["person_state"].get("person", "")), "sunlaoye", id + " person")
			t.eq(str(ops["person_state"].get("state", "")), "away", id + " away")
	elif id == "p.nf1939d.1939.ask_office":
		_need_ops(t, id, ops, ["flag", "counter"])
		if ops.has("flag"):
			t.eq(str(ops["flag"].get("key", "")), "grudge_nf1939d", id + " flag")
		if ops.has("counter"):
			t.eq(str(ops["counter"].get("key", "")), "snub_nf1939d", id + " counter")
	if ops.has("rep"):
		t.eq(int(ops["rep"].get("delta", 0)), -1, id + " rep")
	if ops.has("counter"):
		t.eq(int(ops["counter"].get("delta", 0)), 1, id + " snub delta")


func _need_ops(t, id: String, ops: Dictionary, need: Array) -> void:
	for op in need:
		t.ok(ops.has(str(op)), id + " missing " + str(op))


func _follow(t, by: Dictionary, id: String, kind: String, key: String) -> void:
	t.ok(by.has(id), "missing follow-up " + id)
	if not by.has(id):
		return
	var c: Dictionary = by[id]
	t.ok(c.get("gold", false) != true, id + " follow-up not gold")
	t.ok(str(c.get("intent", "")) != "redeem", id + " follow-up not redeem")
	var fx: Dictionary = c.get("effects", {})
	t.ok(not fx.has("on_expire"), id + " follow-up has no on_expire")
	t.ok(_cond_has(c.get("conditions", {}), kind, key), id + " reads " + kind + " " + key)


func _cond_has(v, kind: String, key: String) -> bool:
	if typeof(v) == TYPE_ARRAY:
		for item in v:
			if _cond_has(item, kind, key):
				return true
		return false
	if typeof(v) != TYPE_DICTIONARY:
		return false
	if kind == "flag" and v.has("flag") and str(v["flag"]) == key:
		return true
	if kind == "counter" and v.has("counter_gte") and typeof(v["counter_gte"]) == TYPE_ARRAY:
		var pair: Array = v["counter_gte"]
		if not pair.is_empty() and str(pair[0]) == key:
			return true
	for k in v.keys():
		if _cond_has(v[k], kind, key):
			return true
	return false


func _ban_keys(t, id: String, v) -> void:
	if typeof(v) == TYPE_DICTIONARY:
		for k in v.keys():
			t.ok(not BANNED_KEYS.has(str(k)), id + " banned key " + str(k))
			_ban_keys(t, id, v[k])
	elif typeof(v) == TYPE_ARRAY:
		for item in v:
			_ban_keys(t, id, item)


func _collect_refs(v, refs: Dictionary) -> void:
	if typeof(v) == TYPE_ARRAY:
		for item in v:
			_collect_refs(item, refs)
		return
	if typeof(v) != TYPE_DICTIONARY:
		return
	var op := str(v.get("op", ""))
	if op == "add_card" and typeof(v.get("card")) == TYPE_STRING:
		refs[str(v["card"])] = true
	if (op == "dossier" or op == "dossier_gap") and typeof(v.get("frag")) == TYPE_STRING:
		refs[str(v["frag"])] = true
	if typeof(v.get("template")) == TYPE_STRING:
		var tpl := str(v["template"])
		if not _template_ok(tpl):
			refs[tpl] = true
	for k in v.keys():
		_collect_refs(v[k], refs)


func _template_ok(tpl: String) -> bool:
	var parts := tpl.split(".")
	if parts.size() != 2:
		return false
	var raw = JSON.parse_string(FileAccess.get_file_as_string("res://data/town/item_templates.json"))
	if typeof(raw) != TYPE_DICTIONARY:
		return false
	var cat: Dictionary = (raw.get("categories", {}) as Dictionary).get(parts[0], {})
	for row in cat.get("variants", []):
		if typeof(row) == TYPE_DICTIONARY and str(row.get("id", "")) == parts[1]:
			return true
	return false


func _known_ids(db: CardDB) -> Dictionary:
	var known := {}
	for id in db.all_ids():
		known[id] = true
	return known
