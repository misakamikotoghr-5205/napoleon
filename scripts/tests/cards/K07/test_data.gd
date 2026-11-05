# K07 条子数据：48 张齐、档位与年份单调、原因键、brief 自查。
# 主人 K07。合同 §4.7.6、§4.9 V17；任务卡 docs/handoff_cards/K07_data-demand.md。
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const YEARS: Array[String] = ["1938", "1939", "1940"]
const KINDS: Array[String] = ["money", "goods", "people", "info"]
const ATTRS: Array[String] = ["eye", "tongue", "pull", "nerve"]
const EXTRA := {
	"money": ["haggle"],
	"goods": ["substitute"],
	"people": ["substitute"],
	"info": ["fabricate"],
}
## 归属表 K07：data/cards/demand/**。CardDB.file_of 是相对数据根的路径。
const OWN_PREFIX := "demand/"


func _initialize() -> void:
	var t := T.new(self, "K07_data")
	var db := CardDB.load_all("res://data/cards")
	var errs := PackedStringArray()
	errs.append_array(_own_load_errors(db))
	errs.append_array(_grid_errors(db))
	errs.append_array(_shape_errors(db))
	errs.append_array(_mono_errors(db))
	errs.append_array(_copy_errors(db))
	errs.append_array(_close_errors(db))
	errs.append_array(_key_errors(db))
	errs.append_array(_meta_errors())
	if errs.is_empty():
		t.ok(true, "demand data")
	else:
		for e in errs:
			t.ok(false, e)
	t.finish()


func _id(year: String, kind: String, tier: int) -> String:
	return "dm.%s.%s.t%d" % [year, kind, tier]


func _owned(db: CardDB, id: String) -> bool:
	return db.file_of(id).begins_with(OWN_PREFIX)


func _own_load_errors(db: CardDB) -> PackedStringArray:
	var errs := PackedStringArray()
	for e in db.errors():
		var s := str(e)
		if s.begins_with(OWN_PREFIX):
			errs.append(s)
	return errs


func _owned_ids(db: CardDB, type_name: StringName) -> PackedStringArray:
	var out := PackedStringArray()
	for id in db.ids_of(type_name):
		if _owned(db, id):
			out.append(id)
	return out


func _grid_errors(db: CardDB) -> PackedStringArray:
	var errs := PackedStringArray()
	var demands := _owned_ids(db, &"demand")
	if demands.size() != 48:
		errs.append("demand count %d" % demands.size())
	var events := _owned_ids(db, &"event")
	if events.size() != 1 or str(events[0]) != "ev.any.demand_return":
		errs.append("expected only ev.any.demand_return")
	var seen := {}
	for year in YEARS:
		for kind in KINDS:
			for tier in range(4):
				var id := _id(year, kind, tier)
				if not db.has(id):
					errs.append("missing " + id)
					continue
				seen[id] = true
				var c := db.def(id)
				if str(c.get("kind", "")) != kind or int(c.get("tier", -1)) != tier:
					errs.append(id + " kind/tier")
				var era: Array = c.get("era", [])
				if era.size() != 1 or str(era[0]) != year:
					errs.append(id + " era")
				if int(c.get("weight", -1)) != 10:
					errs.append(id + " weight")
				if c.has("schedule") or c.has("choices") or c.has("on_fail"):
					errs.append(id + " schedule/choices/on_fail")
				if str(c.get("art", "")) != "illus.dm." + kind:
					errs.append(id + " art")
				if db.file_of(id) != "demand/demands_%s.json" % year:
					errs.append(id + " file")
	for id in demands:
		if not seen.has(id):
			errs.append("unexpected " + id)
	return errs


func _shape_errors(db: CardDB) -> PackedStringArray:
	var errs := PackedStringArray()
	var tpl = CardDB.read_json("res://data/town/item_templates.json")
	var cats: Dictionary = tpl.get("categories", {}) if typeof(tpl) == TYPE_DICTIONARY else {}
	var known: Dictionary = db.tags()
	for id in _owned_ids(db, &"demand"):
		errs.append_array(_shape_one(db.def(id), cats, known))
	if _owned(db, "ev.any.demand_return"):
		errs.append_array(_event_shape(db.def("ev.any.demand_return"), known))
	else:
		errs.append("return file")
	return errs


func _shape_one(c: Dictionary, cats: Dictionary, known: Dictionary) -> PackedStringArray:
	var errs := PackedStringArray()
	var id := str(c.get("id", ""))
	errs.append_array(_prov_errors(c, id))
	if str(c.get("brief", "")).strip_edges() == "":
		errs.append(id + " empty brief")
	errs.append_array(_tag_errors(c, known, id))
	errs.append_array(_float_errors(c, id))
	var kind := str(c.get("kind", ""))
	var res = c.get("resolve", {})
	if typeof(res) != TYPE_DICTIONARY:
		errs.append(id + " resolve")
		return errs
	if _join_sorted(res.keys()) != _join_sorted(_want_keys(kind)):
		errs.append(id + " resolve keys")
		return errs
	var pay := _pay_count(c)
	if kind == "money" or kind == "goods":
		if pay < 1:
			errs.append(id + " needs pay slot")
	elif pay != 0:
		errs.append(id + " unexpected pay slot")
	if kind == "money":
		errs.append_array(_money_shape(c, id))
	elif kind == "goods":
		errs.append_array(_goods_shape(c, id, cats))
	elif kind == "people":
		errs.append_array(_people_shape(c, id))
	elif kind == "info":
		errs.append_array(_info_shape(c, id))
	return errs


func _money_shape(c: Dictionary, id: String) -> PackedStringArray:
	var errs := PackedStringArray()
	var res: Dictionary = c["resolve"]
	var money = res.get("money", {})
	if typeof(money) != TYPE_DICTIONARY:
		errs.append(id + " money")
		return errs
	for key in ["amount", "jitter_pct", "heat_tier_pct"]:
		if typeof(money.get(key)) != TYPE_INT or int(money[key]) < 0:
			errs.append(id + " money." + key)
	if int(money.get("amount", 0)) <= 0:
		errs.append(id + " amount")
	var h = res.get("haggle", {})
	if typeof(h) != TYPE_DICTIONARY:
		errs.append(id + " haggle")
		return errs
	var slots = h.get("slots", [])
	if typeof(slots) != TYPE_ARRAY or (slots as Array).is_empty():
		errs.append(id + " haggle slots")
	if typeof(h.get("need")) != TYPE_INT or int(h["need"]) < 0 or int(h["need"]) > 12:
		errs.append(id + " haggle need")
	if typeof(h.get("tier_down")) != TYPE_INT or int(h["tier_down"]) < 1:
		errs.append(id + " tier_down")
	if not _slot_has(c, "cash", "money"):
		errs.append(id + " cash slot")
	return errs


func _goods_shape(c: Dictionary, id: String, cats: Dictionary) -> PackedStringArray:
	var errs := PackedStringArray()
	var res: Dictionary = c["resolve"]
	var goods: Dictionary = res["goods"]
	var cat := str(goods.get("cat", ""))
	var n := int(goods.get("n", 0))
	if cat == "" or not cats.has(cat) or typeof(goods.get("n")) != TYPE_INT or n < 1:
		errs.append(id + " goods")
	var sub: Dictionary = res.get("substitute", {})
	if typeof(sub.get("money")) != TYPE_INT or int(sub.get("money", 0)) <= 0:
		errs.append(id + " substitute")
	var slot := _slot(c, "goods")
	if slot.is_empty() or not _accepts(slot, "item") or not bool(slot.get("pay", false)):
		errs.append(id + " goods slot")
	var match = slot.get("item_match", {})
	if typeof(match) != TYPE_DICTIONARY or str(match.get("cat", "")) != cat:
		errs.append(id + " item_match")
	if int(slot.get("max", 0)) != n:
		errs.append(id + " goods max")
	return errs


func _people_shape(c: Dictionary, id: String) -> PackedStringArray:
	var errs := PackedStringArray()
	var res: Dictionary = c["resolve"]
	var people: Dictionary = res["people"]
	var n := int(people.get("n", 0))
	var chk = people.get("return_check", {})
	if typeof(people.get("n")) != TYPE_INT or n < 1:
		errs.append(id + " people n")
	if typeof(people.get("away_days")) != TYPE_INT or int(people.get("away_days", 0)) < 1:
		errs.append(id + " away")
	if typeof(chk) != TYPE_DICTIONARY or not ATTRS.has(str(chk.get("attr", ""))):
		errs.append(id + " return attr")
	if typeof(chk) != TYPE_DICTIONARY or typeof(chk.get("need")) != TYPE_INT:
		errs.append(id + " return need")
	var sub: Dictionary = res.get("substitute", {})
	if typeof(sub.get("money")) != TYPE_INT or int(sub.get("money", 0)) <= 0:
		errs.append(id + " substitute")
	var slot := _slot(c, "man")
	if slot.is_empty() or not _accepts(slot, "self") or not _accepts(slot, "contact"):
		errs.append(id + " man slot")
	if typeof(chk) == TYPE_DICTIONARY and str(slot.get("attr", "")) != str(chk.get("attr", "")):
		errs.append(id + " man attr")
	if int(slot.get("max", 0)) != n:
		errs.append(id + " man max")
	return errs


func _info_shape(c: Dictionary, id: String) -> PackedStringArray:
	var errs := PackedStringArray()
	var res: Dictionary = c["resolve"]
	var info: Dictionary = res["info"]
	var n := int(info.get("n", 0))
	if typeof(info.get("n")) != TYPE_INT or n < 1:
		errs.append(id + " info n")
	var fab = res.get("fabricate", {})
	if typeof(fab) != TYPE_DICTIONARY or not ATTRS.has(str(fab.get("attr", ""))):
		errs.append(id + " fabricate attr")
	if typeof(fab) != TYPE_DICTIONARY or typeof(fab.get("need")) != TYPE_INT:
		errs.append(id + " fabricate need")
	var fail = fab.get("on_fail", []) if typeof(fab) == TYPE_DICTIONARY else []
	if typeof(fail) != TYPE_ARRAY or (fail as Array).is_empty():
		errs.append(id + " fabricate on_fail")
	else:
		for eff in fail:
			if typeof(eff) != TYPE_DICTIONARY or str(eff.get("op", "")) != "heat":
				errs.append(id + " fabricate op")
	var slot := _slot(c, "news")
	if slot.is_empty() or not _accepts(slot, "news") or int(slot.get("max", 0)) != n:
		errs.append(id + " news slot")
	return errs


func _event_shape(c: Dictionary, known: Dictionary) -> PackedStringArray:
	var errs := PackedStringArray()
	var id := "ev.any.demand_return"
	if c.is_empty():
		errs.append("missing return event")
		return errs
	errs.append_array(_prov_errors(c, id))
	if str(c.get("type", "")) != "event" or int(c.get("weight", -1)) != 0:
		errs.append(id + " type/weight")
	if not bool(c.get("must_resolve", false)):
		errs.append(id + " must_resolve")
	var era: Array = c.get("era", [])
	if era.size() != 1 or str(era[0]) != "*":
		errs.append(id + " era")
	if c.has("choices"):
		errs.append(id + " choices")
	errs.append_array(_tag_errors(c, known, id))
	if not _has_omen(c.get("tags", [])):
		errs.append(id + " omen")
	var slot := _slot(c, "who")
	if slot.is_empty() or not _accepts(slot, "self") or not _accepts(slot, "contact"):
		errs.append(id + " slot")
	if not ATTRS.has(str(slot.get("attr", ""))):
		errs.append(id + " attr")
	var chk = c.get("check", {})
	if typeof(chk) != TYPE_DICTIONARY or typeof(chk.get("need")) != TYPE_INT:
		errs.append(id + " check")
	if str(c.get("brief", "")).strip_edges() == "":
		errs.append(id + " brief")
	return errs


func _mono_errors(db: CardDB) -> PackedStringArray:
	var errs := PackedStringArray()
	for kind in KINDS:
		for year in YEARS:
			for tier in range(1, 4):
				var prev := _metric(db.def(_id(year, kind, tier - 1)))
				var cur := _metric(db.def(_id(year, kind, tier)))
				if not _ge(cur, prev):
					errs.append("%s %s t%d dropped" % [year, kind, tier])
				elif not _gt_any(cur, prev):
					errs.append("%s %s t%d flat" % [year, kind, tier])
		for tier in range(4):
			var early := _metric(db.def(_id("1938", kind, tier)))
			var mid := _metric(db.def(_id("1939", kind, tier)))
			var late := _metric(db.def(_id("1940", kind, tier)))
			if not _ge(mid, early) or not _ge(late, mid):
				errs.append("%s t%d year drop" % [kind, tier])
			elif not _gt_any(late, early):
				errs.append("%s t%d no year growth" % [kind, tier])
	return errs


func _metric(c: Dictionary) -> Dictionary:
	var kind := str(c.get("kind", ""))
	var res: Dictionary = c.get("resolve", {})
	var out := {}
	if kind == "money":
		out["amount"] = int(res.get("money", {}).get("amount", 0))
		out["need"] = int(res.get("haggle", {}).get("need", 0))
	elif kind == "goods":
		out["n"] = int(res.get("goods", {}).get("n", 0))
		out["sub"] = int(res.get("substitute", {}).get("money", 0))
	elif kind == "people":
		var people: Dictionary = res.get("people", {})
		out["n"] = int(people.get("n", 0))
		out["away"] = int(people.get("away_days", 0))
		out["need"] = int(people.get("return_check", {}).get("need", 0))
		out["sub"] = int(res.get("substitute", {}).get("money", 0))
	else:
		out["n"] = int(res.get("info", {}).get("n", 0))
		out["need"] = int(res.get("fabricate", {}).get("need", 0))
	return out


func _ge(later: Dictionary, earlier: Dictionary) -> bool:
	for k in later.keys():
		if int(later[k]) < int(earlier[k]):
			return false
	return true


func _gt_any(later: Dictionary, earlier: Dictionary) -> bool:
	for k in later.keys():
		if int(later[k]) > int(earlier[k]):
			return true
	return false


func _copy_errors(db: CardDB) -> PackedStringArray:
	var errs := PackedStringArray()
	for id in _owned_ids(db, &"demand"):
		var c := db.def(id)
		var brief := str(c.get("brief", ""))
		errs.append_array(_text_errors(brief, id))
		var year := str(c.get("era", [""])[0])
		if brief.find(_year_mark(year)) < 0:
			errs.append(id + " year nominal")
	if not _owned(db, "ev.any.demand_return"):
		return errs
	var back := db.def("ev.any.demand_return")
	errs.append_array(_text_errors(str(back.get("brief", "")), "ev.any.demand_return"))
	if str(back.get("brief", "")).find("person_state gone") < 0:
		errs.append("return brief missing person_state gone")
	return errs


## 打烊：48 张条子不加 on_expire；回来了吗没理会是晚回来，不是走丢；不写 stage。
func _close_errors(db: CardDB) -> PackedStringArray:
	var errs := PackedStringArray()
	var demands := _owned_ids(db, &"demand")
	if demands.size() != 48:
		errs.append("close demand count %d" % demands.size())
	for id in demands:
		var c := db.def(id)
		if c.has("stage") or c.has("on_expire"):
			errs.append(id + " close field")
		var fx = c.get("effects", {})
		if typeof(fx) == TYPE_DICTIONARY and fx.has("on_expire"):
			errs.append(id + " on_expire")
	if not _owned(db, "ev.any.demand_return"):
		return errs
	var back := db.def("ev.any.demand_return")
	if back.has("stage"):
		errs.append("return stage")
	var fx2 = back.get("effects", {})
	var expire = fx2.get("on_expire", []) if typeof(fx2) == TYPE_DICTIONARY else []
	if typeof(expire) != TYPE_ARRAY or (expire as Array).is_empty():
		errs.append("return on_expire empty")
		return errs
	var late := false
	for e in expire:
		if typeof(e) != TYPE_DICTIONARY:
			errs.append("return on_expire row")
			continue
		if str(e.get("op", "")) != "person_state":
			continue
		if str(e.get("state", "")) == "gone":
			errs.append("return on_expire gone")
		if str(e.get("person", "")) != "{person}":
			errs.append("return person token")
		if str(e.get("state", "")) == "away" and int(e.get("days", 0)) == 1:
			late = true
	if not late:
		errs.append("return not late home")
	var brief := str(back.get("brief", ""))
	if brief.find("晚回来") < 0 or brief.find("走丢") < 0:
		errs.append("return brief close")
	return errs


func _key_errors(db: CardDB) -> PackedStringArray:
	var errs := PackedStringArray()
	var keys: Dictionary = db.ui_keys()
	for key in keys.keys():
		if not str(key).begins_with("k07."):
			continue
		var owner := str(keys[key].get("owner", ""))
		if owner != "K07":
			errs.append("ui owner " + str(key))
	var needed: Array[String] = ["k07.reason.pay", "k07.reason.fine", "k07.reason.substitute"]
	needed.append("k07.notice.not_back")
	needed.append("k07.notice.fine")
	for need in needed:
		if not keys.has(need):
			errs.append("missing ui key " + need)
	var reasons := PackedStringArray()
	var notices := PackedStringArray()
	for id in db.all_ids():
		if not _owned(db, id):
			continue
		_collect(db.def(id), reasons, notices)
	for reason in reasons:
		if not reason.begins_with("k07.") or not keys.has(reason):
			errs.append("reason " + reason)
	var saw_back := false
	for note in notices:
		if not note.begins_with("k07.") or not keys.has(note):
			errs.append("notice " + note)
		if note == "k07.notice.not_back":
			saw_back = true
	if not saw_back:
		errs.append("notice not_back unused")
	return errs


func _meta_errors() -> PackedStringArray:
	var errs := PackedStringArray()
	var dir := "res://data/cards/demand"
	var files: Array[String] = []
	for name in DirAccess.get_files_at(dir):
		if str(name).ends_with(".json"):
			files.append(str(name))
	files.sort()
	var expect: Array[String] = ["demand_return.json", "demands_1938.json", "demands_1939.json", "demands_1940.json"]
	if files != expect:
		errs.append("demand filenames")
	for f in files:
		var doc = CardDB.read_json(dir + "/" + f)
		if typeof(doc) != TYPE_DICTIONARY:
			errs.append(f + " parse")
			continue
		var meta = doc.get("_meta", {})
		if typeof(meta) != TYPE_DICTIONARY or str(meta.get("owner", "")) != "K07" or int(meta.get("schema", 0)) != 1:
			errs.append(f + " meta")
		var brief := str(meta.get("brief", "")) if typeof(meta) == TYPE_DICTIONARY else ""
		errs.append_array(_text_errors(brief, f))
		if f == "demands_1938.json" and brief.find("1938") < 0:
			errs.append("1938 pricing note")
	return errs


func _text_errors(text: String, where: String) -> PackedStringArray:
	var errs := PackedStringArray()
	if text.strip_edges() == "":
		errs.append(where + " empty brief")
		return errs
	for word in _banned():
		if text.find(word) >= 0:
			errs.append(where + " banned word")
	var bad := _regime_bad(text)
	if bad != "":
		errs.append(where + " regime " + bad)
	_scan_quotes(text, where, errs)
	return errs


func _banned() -> PackedStringArray:
	var out := PackedStringArray()
	out.append("%")
	out.append(char(0xff05))
	out.append(_s([0x6982, 0x7387]))
	out.append(_s([0x70b9, 0x6570]))
	out.append(_s([0x672c, 0x5fc3]))
	out.append(_s([0x5e95, 0x4ef7]))
	out.append(_s([0x771f, 0x5047]))
	out.append(char(0x771f))
	out.append(char(0x5047))
	return out


func _year_mark(year: String) -> String:
	if year == "1938":
		return _s([0x4f2a, 0x7ef4, 0x6301, 0x4f1a])
	if year == "1939":
		return _s([0x4f2a, 0x53bf, 0x653f, 0x5e9c])
	return _s([0x6c6a, 0x4f2a])


func _regime_bad(text: String) -> String:
	var wei := char(0x4f2a)
	var wang := _s([0x6c6a, 0x4f2a])
	var stems: Array[String] = [
		_s([0x7ef4, 0x65b0, 0x653f, 0x5e9c]),
		_s([0x56fd, 0x6c11, 0x653f, 0x5e9c]),
		_s([0x53bf, 0x653f, 0x5e9c]),
		_s([0x533a, 0x516c, 0x6240]),
		_s([0x7ef4, 0x6301, 0x4f1a]),
	]
	for stem in stems:
		var from := 0
		while true:
			var i := text.find(stem, from)
			if i < 0:
				break
			var before := text.substr(0, i)
			if not before.ends_with(wei) and not before.ends_with(wang):
				return stem
			from = i + stem.length()
	return ""


func _scan_quotes(text: String, where: String, errs: PackedStringArray) -> void:
	var pairs := [[0x300c, 0x300d], [0x300e, 0x300f], [0x201c, 0x201d], [0x2018, 0x2019]]
	for pair in pairs:
		_scan_pair(text, int(pair[0]), int(pair[1]), where, errs)
	_scan_same(text, 0x22, where, errs)
	_scan_same(text, 0x27, where, errs)


func _scan_pair(text: String, open_c: int, close_c: int, where: String, errs: PackedStringArray) -> void:
	var from := 0
	var open_s := char(open_c)
	var close_s := char(close_c)
	while true:
		var i := text.find(open_s, from)
		if i < 0:
			return
		var j := text.find(close_s, i + 1)
		if j < 0:
			errs.append(where + " unclosed quote")
			return
		_quote_inner(text.substr(i + 1, j - i - 1), where, errs)
		from = j + 1


func _scan_same(text: String, code: int, where: String, errs: PackedStringArray) -> void:
	var mark := char(code)
	var from := 0
	var open_at := -1
	while true:
		var i := text.find(mark, from)
		if i < 0:
			break
		if open_at < 0:
			open_at = i
		else:
			_quote_inner(text.substr(open_at + 1, i - open_at - 1), where, errs)
			open_at = -1
		from = i + 1
	if open_at >= 0:
		errs.append(where + " unclosed quote")


func _quote_inner(inner: String, where: String, errs: PackedStringArray) -> void:
	if inner.length() > 12:
		errs.append(where + " quote too long")
	for code in [0x3002, 0xff01, 0xff1f]:
		if inner.find(char(code)) >= 0:
			errs.append(where + " quote punct")


func _prov_errors(c: Dictionary, id: String) -> PackedStringArray:
	var errs := PackedStringArray()
	var pv = c.get("_provenance", {})
	if typeof(pv) != TYPE_DICTIONARY:
		errs.append(id + " provenance")
		return errs
	if str(pv.get("by", "")) != "ai" or str(pv.get("task", "")) != "K07" or str(pv.get("date", "")) != "2026-10-13":
		errs.append(id + " provenance fields")
	return errs


func _tag_errors(c: Dictionary, known: Dictionary, id: String) -> PackedStringArray:
	var errs := PackedStringArray()
	var tags = c.get("tags", [])
	if typeof(tags) != TYPE_ARRAY or (tags as Array).is_empty():
		errs.append(id + " tags")
		return errs
	for tag in tags:
		if not known.has(str(tag)):
			errs.append(id + " undeclared " + str(tag))
	return errs


func _float_errors(v, id: String) -> PackedStringArray:
	var errs := PackedStringArray()
	_float_walk(v, id, errs)
	return errs


func _float_walk(v, path: String, errs: PackedStringArray) -> void:
	match typeof(v):
		TYPE_FLOAT:
			errs.append(path + " float")
		TYPE_DICTIONARY:
			var keys: Array = v.keys()
			keys.sort()
			for k in keys:
				if not str(k).begins_with("_"):
					_float_walk(v[k], path + "." + str(k), errs)
		TYPE_ARRAY:
			for i in range(v.size()):
				_float_walk(v[i], "%s[%d]" % [path, i], errs)


func _collect(v, reasons: PackedStringArray, notices: PackedStringArray) -> void:
	match typeof(v):
		TYPE_DICTIONARY:
			if v.has("reason"):
				reasons.append(str(v["reason"]))
			if str(v.get("op", "")) == "notice":
				notices.append(str(v.get("key", "")))
			var keys: Array = v.keys()
			keys.sort()
			for k in keys:
				var ks := str(k)
				if ks != "brief" and not ks.begins_with("_"):
					_collect(v[k], reasons, notices)
		TYPE_ARRAY:
			for item in v:
				_collect(item, reasons, notices)


func _pay_count(c: Dictionary) -> int:
	var n := 0
	for s in c.get("slots", []):
		if typeof(s) == TYPE_DICTIONARY and bool(s.get("pay", false)):
			n += 1
	return n


func _slot(c: Dictionary, sid: String) -> Dictionary:
	for s in c.get("slots", []):
		if typeof(s) == TYPE_DICTIONARY and str(s.get("id", "")) == sid:
			return s
	return {}


func _slot_has(c: Dictionary, sid: String, accept: String) -> bool:
	var s := _slot(c, sid)
	return not s.is_empty() and _accepts(s, accept) and bool(s.get("pay", false))


func _accepts(s: Dictionary, kind: String) -> bool:
	var acc = s.get("accepts", [])
	return typeof(acc) == TYPE_ARRAY and (acc as Array).has(kind)


func _has_omen(tags) -> bool:
	if typeof(tags) != TYPE_ARRAY:
		return false
	for tag in tags:
		if str(tag).begins_with("omen_"):
			return true
	return false


func _want_keys(kind: String) -> Array:
	var out: Array = [kind]
	for extra in EXTRA.get(kind, []):
		out.append(extra)
	return out


func _join_sorted(keys: Array) -> String:
	var parts: Array[String] = []
	for k in keys:
		parts.append(str(k))
	parts.sort()
	return ",".join(parts)


func _s(codes: Array) -> String:
	var out := ""
	for code in codes:
		out += char(int(code))
	return out
