# K09 通用牌数量、预留 id、字段、标签、原因键、brief 自查、悬空引用。
# 主人 K09。合同：docs/handoff_cards/K09_data-common.md 测试与验收标准。
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")

const KEPT_IDS: Array[String] = ["kp.ma_owes", "kp.liangmin", "kp.sunfu_letter", "kp.gold_bar",
	"kp.blank_ticket", "kp.brother_note", "kp.mystery_box"]
const CONTACT_IDS: Array[String] = ["ct.zhouma", "ct.chen", "ct.ma", "ct.xiaoding", "ct.wangshan",
	"ct.li", "ct.linsao", "ct.zhang", "ct.wu", "ct.guanjia", "ct.postman", "ct.tudi"]
const ESTATE_IDS: Array[String] = ["es.jewel_cabinet", "es.storeroom", "es.counter", "es.old_house",
	"es.shopfront"]
const NIGHT_IDS: Array[String] = ["nt.tidy", "nt.accounts", "nt.backdoor", "nt.telegraph",
	"nt.family_dinner", "nt.early_sleep"]
const STREET_IDS: Array[String] = ["st.beg", "st.odd_job", "st.stall", "st.write_letters", "st.errand",
	"st.pawn_own", "st.gamble", "st.ask_kin", "st.scavenge", "st.watch", "st.copy", "st.carry"]
const EXTRA_IDS: Array[String] = ["ex_patrol", "ex_soldier", "ex_newsboy", "ex_girl", "ex_shopboy",
	"ex_oldman", "ex_porter", "ex_student", "ex_hu2_man"]
const ATTRS: Array[String] = ["eye", "tongue", "pull", "nerve"]
const TEXT_KEYS: Array[String] = ["text", "title", "body", "label", "name", "lines", "desc", "use",
	"mortgaged"]
const REGIMES: Array[String] = ["维持会", "维新政府", "国民政府", "中储券", "商统会", "县政府", "政权"]
const QUOTE_OPEN := {"\"": "\"", "'": "'", "“": "”", "‘": "’", "「": "」", "『": "』"}


func _initialize() -> void:
	var t := T.new(self, "K09_data")
	var db := CardDB.load_all("res://data/cards")
	t.eq(db.errors(), PackedStringArray(), "db load")
	_counts(t, db)
	_reserved(t, db)
	_each(t, db)
	_critical(t, db)
	_close_day(t, db)
	_extras(t, db)
	_briefs(t)
	_dangling(db)
	t.finish()


func _counts(t, db: CardDB) -> void:
	t.ok(db.ids_of(&"kept").size() >= 13, "kept >= 13")
	t.eq(db.ids_of(&"contact").size(), 12, "contacts == 12")
	t.eq(db.ids_of(&"estate").size(), 5, "estates == 5")
	t.eq(db.ids_of(&"night").size(), 6, "nights == 6")
	t.ok(db.ids_of(&"street").size() >= 10, "streets >= 10")
	var prisons := db.ids_of(&"prison")
	t.ok(prisons.size() >= 1 and prisons.size() <= 2, "prison 1-2")
	t.eq(db.ids_of(&"self").size(), 1, "self == 1")


func _reserved(t, db: CardDB) -> void:
	for id in KEPT_IDS + CONTACT_IDS + ESTATE_IDS + NIGHT_IDS + STREET_IDS:
		t.ok(db.has(id), "missing " + id)
	t.ok(db.has("pr.cell"), "pr.cell")
	t.ok(db.has("self.ruhua"), "self.ruhua")
	t.ok(not db.has("kp.history_issue"), "no kp.history_issue")
	t.ok(not db.has("kp.brother_ledger"), "no ledger kept card")
	_eq_ids(t, db, &"contact", CONTACT_IDS, "contact set")
	_eq_ids(t, db, &"estate", ESTATE_IDS, "estate set")
	_eq_ids(t, db, &"night", NIGHT_IDS, "night set")
	var lev := 0
	for id in db.ids_of(&"kept"):
		if str(id).begins_with("kp.leverage."):
			lev += 1
			t.eq(str(db.def(id).get("kind", "")), "leverage", str(id) + " kind")
			t.ok(typeof(db.def(id).get("risk")) == TYPE_ARRAY and (db.def(id)["risk"] as Array).size() > 0,
				str(id) + " risk")
	t.ok(lev >= 1, "leverage cards")
	var ru: Dictionary = db.persons().get("ruhua", {})
	t.eq(str(ru.get("portrait", "")), "portrait.ruhua", "ruhua portrait")
	t.eq(ru.get("dossier"), false, "ruhua dossier")
	t.ok(str(ru.get("brief", "")).strip_edges() != "", "ruhua brief")


func _eq_ids(t, db: CardDB, typ: StringName, want: Array, msg: String) -> void:
	var got: Array = []
	for id in db.ids_of(typ):
		got.append(str(id))
	got.sort()
	var exp: Array = want.duplicate()
	exp.sort()
	t.eq(got, exp, msg)


func _each(t, db: CardDB) -> void:
	var tags: Dictionary = db.tags()
	var ui: Dictionary = db.ui_keys()
	for id in db.all_ids():
		var rel := db.file_of(id)
		if not str(rel).begins_with("common/"):
			continue
		var c := db.def(id)
		var typ := str(c.get("type", ""))
		t.eq(t.find_floats(c), PackedStringArray(), id + " floats")
		var pv: Dictionary = c.get("_provenance", {})
		t.eq(str(pv.get("task", "")), "K09", id + " task")
		t.eq(str(pv.get("by", "")), "ai", id + " by")
		t.eq(str(pv.get("date", "")), "2026-10-13", id + " date")
		t.ok(str(c.get("brief", "")).strip_edges() != "", id + " brief")
		_no_text(t, c, id)
		_tags_of(t, c, tags, id)
		if typ == "kept":
			t.eq(c.get("keepable"), true, id + " keepable")
			t.ok(int(c.get("expires_days", -1)) >= 0, id + " expires")
			t.eq(int(c.get("weight", -1)), 0, id + " weight")
		elif typ in ["contact", "estate", "prison", "self"]:
			t.eq(int(c.get("weight", -1)), 0, id + " weight")
		elif typ in ["street", "night"]:
			t.ok(int(c.get("weight", 0)) > 0, id + " drawn weight")
		_slot_attrs(t, c.get("slots", []), id)
		for ch in c.get("choices", []):
			if typeof(ch) == TYPE_DICTIONARY:
				var chk = ch.get("check", {})
				if typeof(chk) == TYPE_DICTIONARY:
					_slot_attrs(t, chk.get("slots", []), id)
		_reasons(t, c, ui, id)
		if typ == "contact":
			var attrs: Dictionary = c.get("attrs", {})
			for a in ATTRS:
				t.ok(CardDslShapes.is_int(attrs.get(a)), id + " attr " + a)
			t.eq(str(c.get("art", "")), "portrait." + str(c.get("person", "")), id + " art")
			t.ok(db.persons().has(str(c.get("person", ""))), id + " person registered")


func _critical(t, db: CardDB) -> void:
	var note := db.def("kp.brother_note")
	t.eq(str(note.get("type", "")), "kept", "note type")
	t.eq(note.get("keepable"), true, "note keepable")
	t.eq(int(note.get("expires_days", -1)), 0, "note expires")
	t.eq(str(note.get("kind", "")), "token", "note kind")
	t.eq(note.get("consumed_on_use"), false, "note not consumed")
	t.ok(_bonus(note, "family", "coins", 1), "note family coin")
	var paper := db.def("kp.liangmin")
	t.eq(str(paper.get("kind", "")), "paper", "liangmin kind")
	t.eq(int(paper.get("expires_days", -1)), 0, "liangmin expires")
	t.eq(paper.get("consumed_on_use"), false, "liangmin not consumed")
	t.ok(_bonus_flag(paper, "papers", "auto_pass"), "liangmin auto_pass")
	var box := db.def("kp.mystery_box")
	t.ok((box.get("tags", []) as Array).has("contraband"), "box tag")
	t.ok(_effect_is(box.get("risk", []), "arrest", "reason", "k09.arrest.contraband"), "box arrest")
	t.eq(int(box.get("expires_days", 0)), 7, "box days")
	var self_card := db.def("self.ruhua")
	t.eq(str(self_card.get("person", "")), "ruhua", "self person")
	t.eq(int(self_card["attrs"]["eye"]), 2, "self eye")
	t.eq(int(self_card["attrs"]["tongue"]), 1, "self tongue")
	t.eq(int(self_card["attrs"]["pull"]), 1, "self pull")
	t.eq(int(self_card["attrs"]["nerve"]), 1, "self nerve")
	var zhou := db.def("ct.zhouma")
	t.eq(str(zhou.get("person", "")), "zhouma", "zhouma person")
	t.ok(_hook_op(zhou.get("passives", []), "extra_deal", "type", "news"), "zhouma news")
	var chen: Array = db.def("ct.chen").get("mods", [])
	t.eq(str(chen[0].get("mod", "")), "appraise_pct", "chen appraise")
	t.ok((chen[0].get("cats", []) as Array).has("art"), "chen art")
	t.ok((chen[0].get("cats", []) as Array).has("medicine"), "chen medicine")
	t.eq(int(chen[0].get("pct", 0)), 120, "chen appraise pct is a multiplier")
	t.ok(_effect_is(db.def("nt.tidy").get("effects", {}).get("on_choose", []), "price_mod", "pct", "5"), "tidy price_mod raises")
	t.ok(_effect_is(db.def("nt.backdoor").get("effects", {}).get("on_choose", []), "price_mod", "pct", "-8"), "backdoor price_mod lowers")
	t.eq(db.def("es.shopfront").get("lose_if_unredeemed"), true, "shopfront lost")
	t.eq(str(db.def("es.jewel_cabinet")["while_mortgaged"][0]["mod"]), "no_intake_cat", "jewel mod")
	t.eq(str(db.def("es.jewel_cabinet")["while_mortgaged"][0]["cat"]), "jewelry", "jewel cat")
	t.eq(int(db.def("es.storeroom")["while_mortgaged"][0]["delta"]), -4, "shelf cap")
	t.eq(int(db.def("es.counter")["while_mortgaged"][0]["delta"]), -1, "counter deals")
	t.eq(int(db.def("es.old_house")["while_mortgaged"][0]["pct"]), 150, "house weight")
	var tel := db.def("nt.telegraph")
	t.ok(_cond_val(tel.get("conditions", {}), "day_gte", "3"), "telegraph day")
	t.ok(_cond_val(tel.get("conditions", {}), "flag", "telegraph_ok"), "telegraph flag")
	t.ok(_cond_val(tel.get("conditions", {}), "mode", "shop"), "telegraph shop")
	var sleep := db.def("nt.early_sleep")
	t.ok(_effect_is(sleep.get("effects", {}).get("on_choose", []), "extra_deal", "type", "person"), "early guest")
	var dinner := db.def("nt.family_dinner")
	t.ok(_choice_has(dinner, "waive_life"), "dinner waive")
	t.ok(_choice_has(dinner, "family_word"), "dinner word")
	var cell := db.def("pr.cell")
	t.eq(int(cell.get("weight", -1)), 0, "cell weight")
	t.ok(_effect_is(cell.get("check", {}).get("on_fail", []), "game_over", "reason", "prison"), "cell over")
	var bail := false
	for s in cell.get("slots", []):
		if str(s.get("id", "")) == "bail":
			bail = str(s.get("attr", "")) == "pull"
	t.ok(bail, "bail pull")
	var gamble := db.def("st.gamble")
	t.ok(not gamble.has("opens_wheel"), "gamble has no opens_wheel")
	t.ok(_choice_effect(gamble, "go", "wheel_offer", "wheel", "wh.gamble"), "gamble wheel")
	t.ok(not gamble.has("check"), "gamble no top check")
	t.eq(gamble.get("effects", {}).get("on_expire", null), [], "gamble on_expire empty")
	for id in STREET_IDS:
		if id == "st.gamble":
			continue
		var st := db.def(id)
		t.ok((st.get("slots", []) as Array).size() > 0, id + " slots")
		t.ok(st.has("check"), id + " check")
		t.ok(_effect_is(st.get("check", {}).get("on_success", []), "money", "reason", "k09.reason.street_work"),
			id + " pay")


func _close_day(t, db: CardDB) -> void:
	for id in db.ids_of(&"street"):
		var st := db.def(id)
		var fx = st.get("effects", {})
		var has_expire := typeof(fx) == TYPE_DICTIONARY and (fx as Dictionary).has("on_expire")
		t.ok(st.has("check") or has_expire, str(id) + " check or on_expire")
		t.ok(not st.has("stage"), str(id) + " no stage")
	for typ in ["night", "kept", "contact", "estate", "self", "prison"]:
		for id in db.ids_of(StringName(typ)):
			t.ok(not db.def(id).has("stage"), str(id) + " no stage")
	var cell := db.def("pr.cell")
	var slot_ids: Array = []
	for s in cell.get("slots", []):
		if typeof(s) == TYPE_DICTIONARY:
			slot_ids.append(str(s.get("id", "")))
	t.eq(slot_ids, ["bribe", "bail", "favor"], "cell slots unchanged")
	t.eq(int(cell.get("check", {}).get("need", -1)), 3, "cell need unchanged")
	var stayed := false
	for e in cell.get("effects", {}).get("on_expire", []):
		if typeof(e) == TYPE_DICTIONARY and str(e.get("op", "")) == "shop_closed" and int(e.get("days", 0)) == 1:
			stayed = true
	t.ok(stayed, "cell another night is shop_closed 1")


func _extras(t, db: CardDB) -> void:
	var doc = CardDB.read_json("res://data/cards/common/extras.json")
	t.ok(typeof(doc) == TYPE_DICTIONARY, "extras file")
	var file_persons: Dictionary = (doc as Dictionary).get("persons", {})
	var got: Array = []
	for id in file_persons.keys():
		got.append(str(id))
	got.sort()
	var want: Array = EXTRA_IDS.duplicate()
	want.sort()
	t.eq(got, want, "nine extras")
	t.eq((doc as Dictionary).get("cards", null), [], "extras no cards")
	t.ok(not _has_key(doc, "stage"), "extras no stage")
	var persons: Dictionary = db.persons()
	for id in EXTRA_IDS:
		var p: Dictionary = persons.get(id, {})
		t.ok(not p.is_empty(), "extra loaded " + id)
		t.eq(str(p.get("portrait", "")), "portrait." + id, id + " portrait")
		t.eq(p.get("dossier"), false, id + " dossier")
		t.ok(str(p.get("brief", "")).strip_edges() != "", id + " brief")
	t.ok(str(persons.get("ex_soldier", {}).get("brief", "")).find("伪") >= 0, "soldier brief 伪")


func _has_key(v, key: String) -> bool:
	if typeof(v) == TYPE_DICTIONARY:
		for k in (v as Dictionary).keys():
			if str(k) == key or _has_key((v as Dictionary)[k], key):
				return true
	elif typeof(v) == TYPE_ARRAY:
		for x in v:
			if _has_key(x, key):
				return true
	return false


func _bonus(c: Dictionary, tag: String, key: String, val: int) -> bool:
	for b in c.get("slot_bonus", []):
		if typeof(b) != TYPE_DICTIONARY:
			continue
		if (b.get("slot_tags_any", []) as Array).has(tag) and int(b.get(key, -999)) == val:
			return true
	return false


func _bonus_flag(c: Dictionary, tag: String, key: String) -> bool:
	for b in c.get("slot_bonus", []):
		if typeof(b) != TYPE_DICTIONARY:
			continue
		if (b.get("slot_tags_any", []) as Array).has(tag) and b.get(key) == true:
			return true
	return false


func _effect_is(effects, op: String, key: String, val: String) -> bool:
	if typeof(effects) != TYPE_ARRAY:
		return false
	for e in effects:
		if typeof(e) == TYPE_DICTIONARY and str(e.get("op", "")) == op and str(e.get(key, "")) == val:
			return true
	return false


func _hook_op(rows, op: String, key: String, val: String) -> bool:
	if typeof(rows) != TYPE_ARRAY:
		return false
	for row in rows:
		if typeof(row) == TYPE_DICTIONARY and _effect_is(row.get("effects", []), op, key, val):
			return true
	return false


func _choice_has(c: Dictionary, cid: String) -> bool:
	for ch in c.get("choices", []):
		if typeof(ch) == TYPE_DICTIONARY and str(ch.get("id", "")) == cid:
			return true
	return false


func _choice_effect(c: Dictionary, cid: String, op: String, key: String, val: String) -> bool:
	for ch in c.get("choices", []):
		if typeof(ch) != TYPE_DICTIONARY or str(ch.get("id", "")) != cid:
			continue
		if _effect_is(ch.get("effects", []), op, key, val):
			return true
	return false


func _cond_val(cond, op: String, val: String) -> bool:
	if typeof(cond) != TYPE_DICTIONARY:
		return false
	for k in cond.keys():
		if str(k) == op and str(cond[k]) == val:
			return true
		if str(k) in ["all", "any"] and typeof(cond[k]) == TYPE_ARRAY:
			for sub in cond[k]:
				if _cond_val(sub, op, val):
					return true
		elif str(k) == "not" and _cond_val(cond[k], op, val):
			return true
	return false


func _tags_of(t, c: Dictionary, tags: Dictionary, id: String) -> void:
	for tag in c.get("tags", []):
		t.ok(tags.has(str(tag)), id + " tag " + str(tag))
	for b in c.get("slot_bonus", []):
		if typeof(b) == TYPE_DICTIONARY:
			for tag in b.get("slot_tags_any", []):
				t.ok(tags.has(str(tag)), id + " bonus tag " + str(tag))
	for s in c.get("slots", []):
		if typeof(s) == TYPE_DICTIONARY:
			for tag in s.get("tags", []):
				t.ok(tags.has(str(tag)), id + " slot tag " + str(tag))
	for m in c.get("mods", []):
		if typeof(m) == TYPE_DICTIONARY:
			for tag in m.get("tags_any", []):
				t.ok(tags.has(str(tag)), id + " mod tag " + str(tag))


func _slot_attrs(t, slots, id: String) -> void:
	if typeof(slots) != TYPE_ARRAY:
		return
	for s in slots:
		if typeof(s) != TYPE_DICTIONARY:
			continue
		var acc: Array = s.get("accepts", [])
		if acc.has("self") or acc.has("contact"):
			t.ok(ATTRS.has(str(s.get("attr", ""))), id + " person slot attr")


func _reasons(t, c: Dictionary, ui: Dictionary, id: String) -> void:
	for batch in _effect_lists(c):
		_walk_fx(batch, func(e: Dictionary) -> void:
			var op := str(e.get("op", ""))
			if op in ["money", "pay", "item_lose", "arrest"]:
				var reason := str(e.get("reason", ""))
				t.ok(reason.begins_with("k09."), id + " reason prefix " + reason)
				t.ok(ui.has(reason), id + " reason registered " + reason)
			if op == "notice" and str(e.get("key", "")).begins_with("k09."):
				t.ok(ui.has(str(e.get("key", ""))), id + " notice " + str(e.get("key", "")))
		)


func _effect_lists(c: Dictionary) -> Array:
	var out: Array = []
	var fx = c.get("effects", {})
	if typeof(fx) == TYPE_DICTIONARY:
		for k in fx.keys():
			out.append(fx[k])
	if c.has("risk"):
		out.append(c["risk"])
	var chk = c.get("check", {})
	if typeof(chk) == TYPE_DICTIONARY:
		for k in ["on_success", "on_fail"]:
			if chk.has(k):
				out.append(chk[k])
	for ch in c.get("choices", []):
		if typeof(ch) != TYPE_DICTIONARY:
			continue
		if ch.has("effects"):
			out.append(ch["effects"])
	for key in ["passives", "downsides", "leave_when", "year_changes"]:
		for row in c.get(key, []):
			if typeof(row) == TYPE_DICTIONARY and row.has("effects"):
				out.append(row["effects"])
	return out


func _walk_fx(effects, fn: Callable) -> void:
	if typeof(effects) != TYPE_ARRAY:
		return
	for e in effects:
		if typeof(e) != TYPE_DICTIONARY:
			continue
		fn.call(e)
		var op := str(e.get("op", ""))
		if op == "if" or op == "coin_check":
			_walk_fx(e.get("then", []), fn)
			_walk_fx(e.get("else", []), fn)


func _no_text(t, v, path: String) -> void:
	if typeof(v) == TYPE_DICTIONARY:
		for k in v.keys():
			var key := str(k)
			if key.begins_with("_"):
				continue
			if TEXT_KEYS.has(key):
				t.ok(false, "player text field " + path + "." + key)
			_no_text(t, v[k], path + "." + key)
	elif typeof(v) == TYPE_ARRAY:
		for i in range(v.size()):
			_no_text(t, v[i], "%s[%d]" % [path, i])


func _briefs(t) -> void:
	var files: Array = []
	for f in CardDB.list_json("res://data/cards/common"):
		files.append(f)
	files.append("res://data/cards/tags/K09.json")
	files.append("res://data/cards/ui_keys/K09.json")
	for f in files:
		_walk_briefs(t, CardDB.read_json(f), str(f))


func _walk_briefs(t, v, path: String) -> void:
	if typeof(v) == TYPE_DICTIONARY:
		for k in v.keys():
			if str(k) == "brief" and typeof(v[k]) == TYPE_STRING:
				_brief_ok(t, str(v[k]), path)
			elif not str(k).begins_with("_"):
				_walk_briefs(t, v[k], path + "." + str(k))
	elif typeof(v) == TYPE_ARRAY:
		for i in range(v.size()):
			_walk_briefs(t, v[i], "%s[%d]" % [path, i])


func _brief_ok(t, s: String, path: String) -> void:
	var i := 0
	while i < s.length():
		var ch := s.substr(i, 1)
		if QUOTE_OPEN.has(ch):
			var end := s.find(str(QUOTE_OPEN[ch]), i + 1)
			t.ok(end >= 0, path + " unclosed quote")
			if end < 0:
				return
			var inner := s.substr(i + 1, end - i - 1)
			t.ok(inner.length() <= 12, path + " quote longer than 12")
			t.ok(inner.find("。") < 0 and inner.find("！") < 0 and inner.find("？") < 0, path + " quote punct")
			i = end + 1
		else:
			i += 1
	for stem in REGIMES:
		var from := 0
		while true:
			var at := s.find(stem, from)
			if at < 0:
				break
			var prev := "" if at == 0 else s.substr(at - 1, 1)
			t.ok(prev == "伪", path + " missing 伪 before " + stem)
			from = at + stem.length()


func _dangling(db: CardDB) -> void:
	var refs := {}
	for id in db.all_ids():
		if not str(db.file_of(id)).begins_with("common/"):
			continue
		for batch in _effect_lists(db.def(id)):
			_walk_fx(batch, func(e: Dictionary) -> void:
				var op := str(e.get("op", ""))
				if op == "add_card" and str(e.get("card", "")) != "":
					refs[str(e.get("card"))] = true
				elif op == "wheel_offer" and str(e.get("wheel", "")) != "":
					refs[str(e.get("wheel"))] = true
				elif op == "remove_card" and typeof(e.get("match")) == TYPE_DICTIONARY:
					var d := str(e["match"].get("def", ""))
					if d != "":
						refs[d] = true
			)
	var missing: Array = []
	for id in refs.keys():
		if not db.has(str(id)):
			missing.append(str(id))
	missing.sort()
	for id in missing:
		print("NOTE: dangling " + str(id))
