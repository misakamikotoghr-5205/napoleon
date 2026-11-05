# K09 指引验收：哥哥的交代、周妈、第 1 天夜牌、会过期的留牌、牢房、五件家当。
# 主人 K09。合同：docs/handoff_cards/K09_data-common.md 新手指引。
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")

const ATTRS: Array[String] = ["eye", "tongue", "pull", "nerve"]
const ESTATES: Array[String] = ["es.jewel_cabinet", "es.storeroom", "es.counter", "es.old_house", "es.shopfront"]
const DAY1: Array[String] = ["nt.tidy", "nt.accounts", "nt.backdoor", "nt.family_dinner", "nt.early_sleep"]


func _initialize() -> void:
	var t := T.new(self, "K09_guide_support")
	var db := CardDB.load_all("res://data/cards")
	t.eq(db.errors(), PackedStringArray(), "db load")
	_note(t, db)
	_zhouma(t, db)
	_night(t, db)
	_kept_and_cell(t, db)
	_estates(t, db)
	t.finish()


func _note(t, db: CardDB) -> void:
	var c := db.def("kp.brother_note")
	t.ok(db.has("kp.brother_note"), "kp.brother_note exists")
	t.eq(str(c.get("type", "")), "kept", "brother_note type")
	t.eq(c.get("keepable"), true, "brother_note keepable")
	t.eq(int(c.get("expires_days", -1)), 0, "brother_note expires_days")


func _zhouma(t, db: CardDB) -> void:
	var c := db.def("ct.zhouma")
	t.ok(db.has("ct.zhouma"), "ct.zhouma exists")
	t.eq(str(c.get("person", "")), "zhouma", "zhouma person")
	var attrs: Dictionary = c.get("attrs", {})
	for a in ATTRS:
		t.ok(attrs.has(a), "zhouma attr " + a)


func _night(t, db: CardDB) -> void:
	var ready := 0
	for id in db.ids_of(&"night"):
		if _day1(db.def(id).get("conditions", {})):
			ready += 1
	t.ok(ready >= 3, "day1 shop night cards %d" % ready)
	for id in DAY1:
		t.ok(db.has(id), id + " exists")
		t.ok(_day1(db.def(id).get("conditions", {})), id + " available day 1")
	t.ok(not _day1(db.def("nt.telegraph").get("conditions", {})), "telegraph waits")
	var dinner := db.def("nt.family_dinner")
	var waive := _choice(dinner, "waive_life")
	var word := _choice(dinner, "family_word")
	t.ok(not waive.is_empty(), "waive_life choice")
	t.ok(not word.is_empty(), "family_word choice")
	t.ok(_has_op(waive.get("effects", []), "waive", "type", "life"), "waive life")
	t.ok(_has_card(word.get("effects", []), "nw.any.family_word"), "family_word adds news")


func _kept_and_cell(t, db: CardDB) -> void:
	var expiring := 0
	var risky := 0
	for id in db.ids_of(&"kept"):
		var c := db.def(id)
		if int(c.get("expires_days", 0)) > 0:
			expiring += 1
		if typeof(c.get("risk")) == TYPE_ARRAY and (c["risk"] as Array).size() > 0:
			risky += 1
	t.ok(expiring >= 2, "kept that expire")
	t.ok(risky >= 1, "kept with risk")
	var over := false
	for e in db.def("pr.cell").get("check", {}).get("on_fail", []):
		if typeof(e) == TYPE_DICTIONARY and str(e.get("op", "")) == "game_over":
			over = true
	t.ok(over, "pr.cell on_fail game_over")


func _estates(t, db: CardDB) -> void:
	for id in ESTATES:
		t.ok(db.has(id), id + " exists")
	t.eq(db.ids_of(&"estate").size(), 5, "five estates")
	t.eq(db.def("es.shopfront").get("lose_if_unredeemed"), true, "shopfront lose_if_unredeemed")


## Day-1 shop: only mode / day_gte / flag. day_gte must be <= 1. A required flag is not set.
func _day1(cond) -> bool:
	if typeof(cond) != TYPE_DICTIONARY or (cond as Dictionary).is_empty():
		return true
	if (cond as Dictionary).size() != 1:
		return false
	var k := str((cond as Dictionary).keys()[0])
	var v = cond[k]
	if k == "mode":
		return str(v) == "shop"
	if k == "day_gte":
		return int(v) <= 1
	if k == "flag":
		return false
	if k == "all":
		if typeof(v) != TYPE_ARRAY:
			return false
		for sub in v:
			if not _day1(sub):
				return false
		return true
	if k == "any":
		if typeof(v) != TYPE_ARRAY:
			return false
		for sub in v:
			if _day1(sub):
				return true
		return false
	if k == "not":
		return not _day1(v)
	return false


func _choice(c: Dictionary, cid: String) -> Dictionary:
	for ch in c.get("choices", []):
		if typeof(ch) == TYPE_DICTIONARY and str(ch.get("id", "")) == cid:
			return ch
	return {}


func _has_op(effects, op: String, match_key: String, match_val: String) -> bool:
	if typeof(effects) != TYPE_ARRAY:
		return false
	for e in effects:
		if typeof(e) != TYPE_DICTIONARY or str(e.get("op", "")) != op:
			continue
		var m = e.get("match", {})
		if typeof(m) == TYPE_DICTIONARY and str(m.get(match_key, "")) == match_val:
			return true
	return false


func _has_card(effects, cid: String) -> bool:
	if typeof(effects) != TYPE_ARRAY:
		return false
	for e in effects:
		if typeof(e) == TYPE_DICTIONARY and str(e.get("op", "")) == "add_card" and str(e.get("card", "")) == cid:
			return true
	return false
