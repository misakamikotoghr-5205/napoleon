# K08 指引支撑：周妈教学碎片、哥哥告别两块、译电、家人消息、一年后的链。
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const Own = preload("res://scripts/tests/cards/K08/own_files.gd")


func _initialize() -> void:
	var t := T.new(self, "K08_guide_support")
	var db := CardDB.load_all("res://data/cards", {})
	t.eq(db.errors(), PackedStringArray(), "CardDB loads")
	t.ok(Own.rule_count() >= 2, "K08 ownership paths loaded")
	var zhou := db.def("dp.zhouma")
	t.ok(not zhou.is_empty(), "dp.zhouma exists")
	var zfrags: Array = zhou.get("fragments", [])
	t.ok(zfrags.has("df.zhouma.1938.tut_news"), "zhouma page lists tut fragment")
	var tut := db.def("df.zhouma.1938.tut_news")
	t.ok(not tut.is_empty(), "tut fragment exists")
	t.ok((tut.get("era", []) as Array).has("1938"), "tut era has 1938")
	t.ok(str(tut.get("kind", "")) in ["heard", "said"], "tut kind heard or said")
	var bro := db.def("dp.brother")
	var bfrags: Array = bro.get("fragments", [])
	t.ok(bfrags.has("df.brother.1938.farewell"), "brother page has farewell")
	t.ok(bfrags.has("df.brother.1938.farewell_cold"), "brother page has farewell_cold")
	var decode := false
	for nid in Own.ids(db, &"news"):
		var c := db.def(nid)
		if str(c.get("kind", "")) == "telegram" and str(c.get("minigame", "")) == "decode":
			decode = true
	t.ok(decode, "a telegram minigame decode")
	var fam := db.def("nw.any.family_word")
	t.ok(not fam.is_empty(), "family_word exists")
	t.eq(int(fam.get("weight", -1)), 0, "family_word weight 0")
	_year_after(t, db)
	t.finish()


func _year_after(t, db: CardDB) -> void:
	var page_of: Dictionary = {}
	for pid in Own.ids(db, &"dossier_page"):
		for fid in db.def(pid).get("fragments", []):
			page_of[str(fid)] = pid
	var n38 := 0
	var n39 := 0
	for fid in Own.ids(db, &"dossier_fragment"):
		var fr := db.def(fid)
		if str(fr.get("kind", "")) != "year_after":
			continue
		var prev_id := str(fr.get("year_after_of", ""))
		t.ok(db.has(prev_id), "%s year_after_of exists" % fid)
		var prev := db.def(prev_id)
		var earlier := _year(prev)
		var later := _year(fr)
		t.ok(earlier > 0 and later > earlier, "%s era is later than %s" % [fid, prev_id])
		t.eq(str(page_of.get(fid, "")), str(page_of.get(prev_id, "missing")),
			"%s shares a page with its earlier fragment" % fid)
		if earlier == 1938 and later == 1939:
			n38 += 1
		elif earlier == 1939 and later == 1940:
			n39 += 1
	t.ok(n38 >= 4, "1938 to 1939 year_after count %d" % n38)
	t.ok(n39 >= 4, "1939 to 1940 year_after count %d" % n39)


func _year(card: Dictionary) -> int:
	var best := 0
	for era in card.get("era", []):
		var s := str(era)
		if s.is_valid_int():
			var n := int(s)
			if best == 0 or n < best:
				best = n
	return best
