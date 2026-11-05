# K10 数据数量与形状。合同：docs/handoff_cards/K10_data-fortune.md 测试清单。
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")

const YEARS: Array[String] = ["1938", "1939", "1940"]
const VALENCES: Array[String] = ["good", "neutral", "bad"]
const COUNTER: Array[String] = ["pawn_in", "buy_in", "sell_out", "trade", "redeem"]
const FORTUNE_TYPES: Array[String] = ["wheel", "wheel_segment", "fortune_lot", "cezi", "almanac_day"]
const QUOTE_CLOSE := {34: 34, 0x201C: 0x201D, 0x2018: 0x2019, 0x300C: 0x300D, 0x300E: 0x300F}


func _initialize() -> void:
	var t := T.new(self, "K10_data")
	var db := CardDB.load_all()
	t.eq(db.errors(), PackedStringArray(), "CardDB load")
	_wheels(t, db)
	_segments(t, db)
	_lots(t, db)
	_cezi(t, db)
	_almanac(t, db)
	_cards(t, db)
	t.finish()


func _wheels(t, db: CardDB) -> void:
	t.eq(db.ids_of(&"wheel").size(), 4, "four wheels")
	for id in ["wh.month", "wh.big", "wh.fair", "wh.gamble"]:
		t.ok(db.has(id), "wheel " + id)
		var c := db.def(id)
		t.eq(int(c.get("weight", -1)), 0, id + " weight")
		t.eq(str(c.get("art", "")), "wheel." + str(c.get("kind", "")), id + " art")
		t.ok((c.get("era", []) as Array).has("*"), id + " era")
	var month := db.def("wh.month")
	var big := db.def("wh.big")
	t.eq(str(month.get("kind", "")), "month", "month kind")
	t.eq(str(big.get("kind", "")), "big", "big kind")
	t.eq(str(db.def("wh.fair").get("kind", "")), "fair", "fair kind")
	t.eq(str(db.def("wh.gamble").get("kind", "")), "gamble", "gamble kind")
	for w in [month, big]:
		var inc: Dictionary = w.get("incense", {})
		for kind in ["money", "kept", "contact"]:
			t.ok((inc.get("accepts", []) as Array).has(kind), str(w["id"]) + " accepts " + kind)
		t.eq(str(inc.get("contact_attr", "")), "pull", str(w["id"]) + " contact_attr")
		t.ok(int(inc.get("money_per_unit", 0)) > 0, str(w["id"]) + " money_per_unit")
		t.ok(int(inc.get("unit_widen_pct", 0)) > 0, str(w["id"]) + " unit_widen_pct")
		t.ok(int(inc.get("max_units", 0)) > 0, str(w["id"]) + " max_units")
		t.ok((w.get("cost", {1: 1}) as Dictionary).is_empty(), str(w["id"]) + " cost empty")
	t.ok(int(db.def("wh.fair").get("cost", {}).get("money", 0)) > 0, "fair costs money")
	t.eq(bool(db.def("wh.gamble").get("cost", {}).get("stake", false)), true, "gamble stakes a kept card")


func _segments(t, db: CardDB) -> void:
	for year in YEARS:
		var month := _segs(db, "wh.month", year)
		t.ok(month.size() >= 6 and month.size() <= 8, year + " month count %d" % month.size())
		t.ok(_count_valence(month, "good") >= 1, year + " month has a good segment")
		t.ok(_count_valence(month, "bad") >= 1, year + " month has a bad segment")
		var big := _segs(db, "wh.big", year)
		for valence in VALENCES:
			var n := _count_valence(big, valence)
			t.ok(n >= 2 and n <= 3, "%s big %s count %d" % [year, valence, n])
		t.ok(_segs(db, "wh.fair", year).size() >= 3, year + " fair available")
		t.ok(_segs(db, "wh.gamble", year).size() >= 3, year + " gamble available")
	t.eq(_segs(db, "wh.fair", "").size(), 6, "fair has 6 segments")
	t.eq(_segs(db, "wh.gamble", "").size(), 6, "gamble has 6 segments")
	for id in db.ids_of(&"wheel_segment"):
		var c := db.def(str(id))
		t.ok(int(c.get("arc", 0)) > 0, str(id) + " arc")
		t.ok(VALENCES.has(str(c.get("valence", ""))), str(id) + " valence")
		t.ok(c.get("effects") is Array, str(id) + " effects array")
		var on_month := str(c.get("wheel", "")) == "wh.month"
		t.eq(c.has("month_mods"), on_month, str(id) + " month_mods only on wh.month")


func _lots(t, db: CardDB) -> void:
	var lots := _typed(db, &"fortune_lot")
	t.ok(lots.size() >= 30, "lots >= 30 (%d)" % lots.size())
	var omens := _omens(db)
	for grade in range(0, 5):
		var families := {}
		var generic := 0
		for c in lots:
			if int(c.get("grade", -1)) != grade:
				continue
			var tags: Array = c.get("hint_tags", [])
			if tags.is_empty():
				generic += 1
			else:
				t.eq(tags.size(), 1, str(c["id"]) + " one omen family")
				var tag := str(tags[0])
				t.ok(omens.has(tag), str(c["id"]) + " hint " + tag)
				families[tag] = true
		t.ok(families.size() >= 6, "grade %d families %d" % [grade, families.size()])
		t.ok(generic >= 1, "grade %d generic lot" % grade)


func _cezi(t, db: CardDB) -> void:
	var rows := _typed(db, &"cezi")
	t.ok(rows.size() >= 12 and rows.size() <= 16, "cezi count %d" % rows.size())
	var omens := _omens(db)
	var used := {}
	for c in rows:
		var id := str(c["id"])
		t.ok(_ascii(id), id + " ascii")
		var tags: Array = c.get("tags", [])
		t.ok(tags.size() >= 1 and tags.size() <= 2, id + " tag count")
		for tag in tags:
			t.ok(omens.has(str(tag)), id + " tag " + str(tag))
			used[str(tag)] = true
	t.ok(used.size() >= 8, "cezi covers %d omen families" % used.size())


func _almanac(t, db: CardDB) -> void:
	var rows := _typed(db, &"almanac_day")
	t.ok(rows.size() >= 24, "almanac >= 24 (%d)" % rows.size())
	var by_season := [0, 0, 0, 0]
	var spring: Array = []
	for c in rows:
		var seasons: Array = c.get("season", [])
		t.ok(not seasons.is_empty(), str(c["id"]) + " season")
		for s in seasons:
			var n := int(s)
			t.ok(n >= 0 and n <= 3, str(c["id"]) + " season range")
			by_season[n] += 1
		if seasons.has(0):
			spring.append(c)
		_actions(t, c, "yi")
		_actions(t, c, "ji")
		t.ok(_reward_ok(c.get("reward", [])), str(c["id"]) + " reward does not punish")
	for i in 4:
		t.ok(by_season[i] >= 6, "season %d count %d" % [i, by_season[i]])
	var hit := 0
	for c in spring:
		if _yi_has_counter(c):
			hit += 1
	t.ok(spring.size() >= 6, "spring rows")
	t.ok(hit * 2 >= spring.size(), "spring counter yi %d/%d" % [hit, spring.size()])


func _cards(t, db: CardDB) -> void:
	var keys: Dictionary = db.ui_keys()
	for type in FORTUNE_TYPES:
		for id in db.ids_of(StringName(type)):
			var c := db.def(str(id))
			var pv: Dictionary = c.get("_provenance", {})
			t.eq(str(pv.get("task", "")), "K10", str(id) + " provenance")
			t.eq(str(pv.get("date", "")), "2026-10-13", str(id) + " date")
			t.ok(str(c.get("brief", "")).strip_edges() != "", str(id) + " brief")
			_quotes(t, str(id), str(c.get("brief", "")))
			var reasons: Array = []
			var notices: Array = []
			_collect(c, reasons, notices)
			for reason in reasons:
				t.ok(str(reason).begins_with("k10."), str(id) + " reason " + str(reason))
				t.ok(keys.has(str(reason)), str(id) + " reason registered " + str(reason))
			for key in notices:
				t.ok(str(key).begins_with("k10."), str(id) + " notice " + str(key))
				t.ok(keys.has(str(key)), str(id) + " notice registered " + str(key))


func _segs(db: CardDB, wheel_id: String, year: String) -> Array:
	var out: Array = []
	for id in db.ids_of(&"wheel_segment"):
		var c := db.def(str(id))
		if str(c.get("wheel", "")) != wheel_id:
			continue
		if year != "" and not _applies(c, year):
			continue
		out.append(c)
	return out


func _applies(c: Dictionary, year: String) -> bool:
	var era: Array = c.get("era", [])
	return era.has("*") or era.has(year)


func _count_valence(rows: Array, valence: String) -> int:
	var n := 0
	for c in rows:
		if str(c.get("valence", "")) == valence:
			n += 1
	return n


func _typed(db: CardDB, type: StringName) -> Array:
	var out: Array = []
	for id in db.ids_of(type):
		out.append(db.def(str(id)))
	return out


func _omens(db: CardDB) -> Dictionary:
	var out := {}
	for k in db.tags().keys():
		if str(k).begins_with("omen_"):
			out[str(k)] = true
	return out


func _ascii(s: String) -> bool:
	for i in s.length():
		if s.unicode_at(i) > 127:
			return false
	return true


func _actions(t, c: Dictionary, field: String) -> void:
	var list: Array = c.get(field, [])
	t.ok(list is Array, str(c["id"]) + " " + field)
	for a in list:
		t.ok(CardIds.ALMANAC_ACTIONS.has(StringName(str(a))), "%s %s %s" % [c["id"], field, a])


func _yi_has_counter(c: Dictionary) -> bool:
	for a in c.get("yi", []):
		if COUNTER.has(str(a)):
			return true
	return false


func _reward_ok(effects) -> bool:
	if not (effects is Array):
		return false
	for e in effects:
		if typeof(e) != TYPE_DICTIONARY:
			return false
		var op := str(e.get("op", ""))
		if op == "money" and int(e.get("delta", 0)) < 0:
			return false
		if op == "pay" or op == "item_lose" or op == "arrest" or op == "estate_seize":
			return false
		if op == "shop_closed" or op == "game_over":
			return false
		if op == "rep" and e.has("delta") and int(e["delta"]) < 0:
			return false
		if op == "rep" and e.has("tier") and int(e["tier"]) < 0:
			return false
		if op == "heat" and e.has("delta") and int(e["delta"]) > 0:
			return false
		if op == "heat" and e.has("tier") and int(e["tier"]) > 0:
			return false
		if e.has("then") and not _reward_ok(e["then"]):
			return false
		if e.has("else") and not _reward_ok(e["else"]):
			return false
	return true


func _collect(node, reasons: Array, notices: Array) -> void:
	match typeof(node):
		TYPE_DICTIONARY:
			if str(node.get("op", "")) == "money" and node.has("reason"):
				reasons.append(str(node["reason"]))
			if str(node.get("op", "")) == "notice" and node.has("key"):
				notices.append(str(node["key"]))
			for k in node.keys():
				var key := str(k)
				if key == "brief" or key.begins_with("_"):
					continue
				_collect(node[k], reasons, notices)
		TYPE_ARRAY:
			for v in node:
				_collect(v, reasons, notices)


func _quotes(t, id: String, brief: String) -> void:
	var i := 0
	while i < brief.length():
		var ch := brief.unicode_at(i)
		if QUOTE_CLOSE.has(ch):
			var close := int(QUOTE_CLOSE[ch])
			var j := i + 1
			var found := false
			while j < brief.length():
				if brief.unicode_at(j) == close:
					found = true
					break
				j += 1
			t.ok(found, id + " quote closed")
			if not found:
				return
			var inner := brief.substr(i + 1, j - i - 1)
			t.ok(inner.length() <= 12, id + " quote length %d" % inner.length())
			t.ok(inner.find("。") < 0 and inner.find("！") < 0 and inner.find("？") < 0, id + " quote punctuation")
			i = j
		i += 1
