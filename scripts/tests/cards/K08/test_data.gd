# K08 数量、页与碎片闭合、消息形状、brief 自查。悬空引用只打印 NOTE，不断言。
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const Own = preload("res://scripts/tests/cards/K08/own_files.gd")

const MAINS: Array[String] = [
	"brother", "chen", "xiaoding", "zhang", "wangshan", "li", "linsao", "zhouma",
	"zhao", "sunyoung", "ma", "hu2", "sunlaoye", "guanjia", "wu", "postman",
]
const NEW_FACES: Array[String] = [
	"nf1938a", "nf1938b", "nf1938c", "nf1938d",
	"nf1939a", "nf1939b", "nf1939c", "nf1939d",
	"nf1940a", "nf1940b", "nf1940c", "nf1940d",
]
const PASSERS: Array[String] = [
	"stranger_refugee", "stranger_peddler", "stranger_collector", "stranger_fence",
	"stranger_waixiang", "stranger_boatman", "stranger_student", "stranger_widow",
]
const NEWS_KINDS: Array[String] = ["price", "lead", "rumor", "letter", "paper", "telegram"]
const FRAG_KINDS: Array[String] = ["pawn", "said", "heard", "clipping", "ticket", "letter", "year_after"]

var _id_re: RegEx


func _initialize() -> void:
	var t := T.new(self, "K08_data")
	var db := CardDB.load_all("res://data/cards", {})
	t.eq(db.errors(), PackedStringArray(), "CardDB loads real data")
	t.ok(Own.rule_count() >= 2, "K08 ownership paths loaded")
	_id_re = RegEx.new()
	_id_re.compile("(df|dp)\\.[a-z0-9_]+(?:\\.[a-z0-9_]+)+")
	_pages(t, db)
	_frags(t, db)
	_news(t, db)
	_dangling(db)
	t.finish()


func _pages(t, db: CardDB) -> void:
	var persons: Dictionary = db.persons()
	var pages := Own.ids(db, &"dossier_page")
	t.ok(pages.size() >= MAINS.size() + NEW_FACES.size(), "page count %d" % pages.size())
	for pid in MAINS:
		var page := db.def("dp." + pid)
		t.ok(not page.is_empty(), "main page dp.%s" % pid)
		t.eq(str(page.get("person", "")), pid, "page person %s" % pid)
		t.ok((page.get("fragments", []) as Array).size() >= 5, "dp.%s has >= 5 fragments" % pid)
	for pid in NEW_FACES:
		t.ok(db.has("dp." + pid), "new face page dp.%s" % pid)
	for pid in PASSERS:
		t.ok(db.has("dp." + pid), "passer page dp.%s" % pid)
	t.ok(not db.has("dp.suanming"), "suanming has no page")
	t.ok(not db.has("dp.ruhua"), "ruhua has no page")
	for pid in persons.keys():
		var info = persons[pid]
		if typeof(info) == TYPE_DICTIONARY and bool(info.get("dossier", false)):
			t.ok(db.has("dp." + str(pid)), "dossier:true person has page %s" % pid)


func _frags(t, db: CardDB) -> void:
	var owner: Dictionary = {}
	var orders: Dictionary = {}
	for pid in Own.ids(db, &"dossier_page"):
		var page := db.def(pid)
		var person := str(page.get("person", ""))
		var prev := -1
		var seen_order: Dictionary = {}
		for fid in page.get("fragments", []):
			var id := str(fid)
			t.ok(db.has(id), "%s lists missing %s" % [pid, id])
			if owner.has(id):
				t.ok(false, "%s on two pages %s and %s" % [id, owner[id], pid])
			owner[id] = pid
			var fr := db.def(id)
			t.eq(str(fr.get("person", "")), person, "%s person matches page" % id)
			var ord := int(fr.get("order", -1))
			t.ok(not seen_order.has(ord), "%s duplicate order %d" % [pid, ord])
			seen_order[ord] = true
			t.ok(ord > prev, "%s fragments not in order" % pid)
			prev = ord
			orders[id] = ord
	var kind_seen: Dictionary = {}
	for fid in Own.ids(db, &"dossier_fragment"):
		t.ok(owner.has(fid), "fragment %s is on exactly one page" % fid)
		var fr := db.def(fid)
		t.eq(int(fr.get("weight", -1)), 0, "%s weight 0" % fid)
		t.eq(str(fr.get("_provenance", {}).get("task", "")), "K08", "%s provenance" % fid)
		t.ok(str(fr.get("brief", "")).strip_edges() != "", "%s brief" % fid)
		var kind := str(fr.get("kind", ""))
		t.ok(kind in FRAG_KINDS, "%s kind %s" % [fid, kind])
		kind_seen[kind] = true
		_brief_ok(t, fid, str(fr.get("brief", "")))
	for kind in FRAG_KINDS:
		t.ok(kind_seen.has(kind), "fragment kind %s exists" % kind)


func _news(t, db: CardDB) -> void:
	var persons: Dictionary = db.persons()
	var tags: Dictionary = db.tags()
	var ids := Own.ids(db, &"news")
	t.ok(ids.size() >= 36, "news count %d" % ids.size())
	var kind_seen: Dictionary = {}
	var year_n := {"1938": 0, "1939": 0, "1940": 0, "*": 0}
	var decode := false
	var torn := false
	var rumor_cap := 0
	var letter_floor := -1
	var telegram_floor := -1
	for nid in ids:
		var c := db.def(nid)
		t.eq(str(c.get("_provenance", {}).get("task", "")), "K08", "%s provenance" % nid)
		t.eq(str(c.get("_provenance", {}).get("date", "")), "2026-10-13", "%s date" % nid)
		var brief := str(c.get("brief", ""))
		t.ok(brief.strip_edges() != "", "%s brief" % nid)
		_brief_ok(t, nid, brief)
		var kind := str(c.get("kind", ""))
		t.ok(kind in NEWS_KINDS, "%s kind" % nid)
		kind_seen[kind] = true
		var omen := false
		for tag in c.get("tags", []):
			var ts := str(tag)
			t.ok(tags.has(ts), "%s tag %s declared" % [nid, ts])
			if ts.begins_with("omen_"):
				omen = true
		t.ok(omen, "%s has omen tag" % nid)
		t.eq(bool(c.get("must_resolve", true)), false, "%s must_resolve" % nid)
		t.eq(bool(c.get("keepable", false)), true, "%s keepable" % nid)
		t.ok(not c.has("stage"), "%s no stage" % nid)
		var days_v = c.get("expires_days")
		t.ok(typeof(days_v) == TYPE_INT and int(days_v) > 0, "%s expires_days positive int" % nid)
		var days := int(days_v)
		if kind == "rumor":
			rumor_cap = maxi(rumor_cap, days)
		elif kind == "letter":
			letter_floor = days if letter_floor < 0 else mini(letter_floor, days)
		elif kind == "telegram":
			telegram_floor = days if telegram_floor < 0 else mini(telegram_floor, days)
		var about := str(c.get("info_about", ""))
		t.ok(about != "" and persons.has(about), "%s info_about registered" % nid)
		var source := str(c.get("source", ""))
		if source != "":
			t.ok(persons.has(source), "%s source registered" % nid)
		if c.has("minigame"):
			t.ok(kind in ["telegram", "letter"], "%s minigame kind" % nid)
			t.ok(str(c["minigame"]) in ["decode", "fragments"], "%s minigame value" % nid)
			if str(c["minigame"]) == "decode" and kind == "telegram":
				decode = true
			if str(c["minigame"]) == "fragments" and kind == "letter":
				torn = true
		for era in c.get("era", []):
			var es := str(era)
			if year_n.has(es):
				year_n[es] = int(year_n[es]) + 1
	for kind in NEWS_KINDS:
		t.ok(kind_seen.has(kind), "news kind %s" % kind)
	t.ok(decode, "a telegram uses decode")
	t.ok(torn, "a letter uses fragments")
	t.ok(int(year_n["1938"]) >= 10 and int(year_n["1939"]) >= 10 and int(year_n["1940"]) >= 10,
		"each year has news")
	t.ok(letter_floor >= rumor_cap and telegram_floor >= rumor_cap,
		"letter %d telegram %d not shorter than rumor cap %d" % [letter_floor, telegram_floor, rumor_cap])
	var fam := db.def("nw.any.family_word")
	t.eq(int(fam.get("weight", -1)), 0, "family_word weight")
	print("K08 counts news=%d pages=%d frags=%d" % [
		ids.size(), Own.ids(db, &"dossier_page").size(), Own.ids(db, &"dossier_fragment").size()])


func _brief_ok(t, id: String, brief: String) -> void:
	var q := _quote_problem(brief)
	t.ok(q == "", "%s brief quote: %s" % [id, q])
	var p := _puppet_problem(brief)
	t.ok(p == "", "%s brief puppet: %s" % [id, p])
	t.ok(not brief.contains("%"), "%s brief has percent" % id)


func _quote_problem(brief: String) -> String:
	var pairs: Array = [
		["\u201c", "\u201d"], ["\u2018", "\u2019"], ["\u300c", "\u300d"],
		["\u300e", "\u300f"], ["\"", "\""],
	]
	var bad: Array = ["\u3002", "\uff01", "\uff1f"]
	for pair in pairs:
		var left: String = pair[0]
		var right: String = pair[1]
		var from := 0
		while true:
			var i := brief.find(left, from)
			if i < 0:
				break
			var j := brief.find(right, i + left.length())
			if j < 0:
				return "unclosed"
			var inside := brief.substr(i + left.length(), j - (i + left.length()))
			if inside.length() > 12:
				return "len"
			for punct in bad:
				if inside.contains(str(punct)):
					return "punct"
			from = j + right.length()
	return ""


func _puppet_problem(brief: String) -> String:
	var rules: Array = [
		["\u7ef4\u6301\u4f1a", "\u4f2a"],
		["\u7ef4\u65b0\u653f\u5e9c", "\u4f2a"],
		["\u53bf\u653f\u5e9c", "\u4f2a"],
		["\u533a\u516c\u6240", "\u4f2a"],
		["\u56fd\u6c11\u653f\u5e9c", "\u6c6a\u4f2a"],
		["\u4e2d\u50a8\u5238", "\u4f2a"],
	]
	for rule in rules:
		var term: String = rule[0]
		var prefix: String = rule[1]
		var from := 0
		while true:
			var i := brief.find(term, from)
			if i < 0:
				break
			var got := ""
			if i >= prefix.length():
				got = brief.substr(i - prefix.length(), prefix.length())
			if got != prefix:
				return "prefix"
			from = i + term.length()
	if brief.contains("\u6297\u6218\u80dc\u5229") or brief.contains("\u89e3\u653e"):
		return "year-word"
	return ""


## 引用覆盖报告：扫全部真数据里的 df.* / dp.*，没有定义的只打印 NOTE，不断言。
func _dangling(db: CardDB) -> void:
	var seen: Dictionary = {}
	for id in db.all_ids():
		_walk(db, db.def(id), id, seen)


func _walk(db: CardDB, v, owner: String, seen: Dictionary) -> void:
	match typeof(v):
		TYPE_STRING:
			for m in _id_re.search_all(str(v)):
				var ref := m.get_string(0)
				if db.has(ref):
					continue
				var key := ref + "|" + owner
				if seen.has(key):
					continue
				seen[key] = true
				print("NOTE: dangling %s (referenced by %s)" % [ref, owner])
		TYPE_DICTIONARY:
			for k in v.keys():
				_walk(db, v[k], owner, seen)
		TYPE_ARRAY:
			for item in v:
				_walk(db, item, owner, seen)
