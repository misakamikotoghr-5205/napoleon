# K16: every FIRSTS mechanism has a step and a rule page; the §7.10.10 table matches cards.
# _test.d1_3 is ordered; briefs stay free of hidden numbers. The validator indexes cards, not _bundle.
# 10-22 (prototype): bubbles stay until got it or the deed (seconds 0); no after chain across phases.
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const D1_3: Array[String] = ["gd.m.open", "gd.m.wheel", "gd.m.incense", "gd.d1.notice", "gd.d1.deal", "gd.d2.gold", "gd.d1.person", "gd.d1.close", "gd.choice", "gd.d1.look", "gd.d1.spot", "gd.d1.tiers", "gd.d1.ticket", "gd.d1.shelf", "gd.d1.buyer", "gd.d1.night", "gd.d1.settle", "gd.d2.rules", "gd.d2.keep", "gd.slots", "gd.coins"]
## 10-22 prototype flow: only these same-panel orders remain as trigger.after (TUTORIAL.md P1).
const AFTER_OK := {"gd.m.incense": ["gd.m.wheel"], "gd.d1.tiers": ["gd.d1.look"], "gd.coins": ["gd.slots"]}
const PAGE_IDS: Array[String] = ["rule.day", "rule.night", "rule.person", "rule.counter", "rule.appraise", "rule.ticket", "rule.shelf", "rule.gold", "rule.kept", "rule.slots", "rule.demand", "rule.fate", "rule.wheel", "rule.almanac", "rule.fortune", "rule.news", "rule.dossier", "rule.contact", "rule.tiers", "rule.life", "rule.month", "rule.year", "rule.ladder", "rule.prison", "rule.retry", "rule.branch"]
const STEPS_FILE := "guide/steps.json"
const PAGES_FILE := "guide/rule_pages.json"


func _initialize() -> void:
	var t := T.new(self, "K16_guide_coverage")
	var steps_doc: Dictionary = CardDB.read_json("res://data/cards/guide/steps.json")
	var pages_doc: Dictionary = CardDB.read_json("res://data/cards/guide/rule_pages.json")
	var table: Dictionary = CardDB.read_json("res://scripts/tests/cards/K16/table_71010.json")
	var guide_rules: Dictionary = CardDB.read_json("res://data/cards/rules/guide.json")
	t.ok(typeof(steps_doc) == TYPE_DICTIONARY, "steps.json parses")
	t.ok(not steps_doc.has("_bundle"), "steps live in cards; the validator does not read _bundle")
	var bundle: Array = steps_doc.get("cards", [])
	var pages: Array = pages_doc.get("cards", [])
	t.eq(bundle.size(), 70, "70 steps in cards (1.4 gd.office + K18 gd.pet + K18 gd.apprentice + gd.scare)")
	t.eq(pages.size(), 26, "26 rule pages")
	t.eq(Array(steps_doc.get("_test", {}).get("d1_3", [])), D1_3, "_test.d1_3 matches the locked order")
	t.eq(Array(table.get("d1_3", [])), D1_3, "table file order matches")
	var by_id := {}
	for s in bundle:
		var sid := str(s.get("id", ""))
		t.ok(not by_id.has(sid), "duplicate step " + sid)
		by_id[sid] = s
		_brief_ok(t, sid, str(s.get("brief", "")))
		t.ok(pages_have(pages, str(s.get("rule_page", ""))), sid + " rule_page exists")
		var prov := str(s.get("_provenance", {}).get("task", ""))
		if sid == "gd.apprentice" or sid == "gd.pet" or sid == "gd.scare":
			t.eq(prov, "K18", sid + " provenance")
		else:
			t.ok(["K16", "K17"].has(prov), sid + " provenance (K17 = 1.4 gd.office)")
		var tf := str(s.get("trigger", {}).get("first", ""))
		for tok in s.get("done_when", []):
			if str(tok).begins_with("first:"):
				t.ok(str(tok).substr(6) != tf, sid + " done_when first is not trigger.first")
	var taught := {}
	for s in bundle:
		for m in s.get("teaches", []):
			taught[str(m)] = true
	for m in CardIds.FIRSTS.keys():
		t.ok(taught.has(str(m)), "teaches covers " + str(m))
	t.eq(taught.size(), CardIds.FIRSTS.size(), "no extra teaches")
	var unlocked := {}
	var page_ids: Array = []
	for p in pages:
		page_ids.append(str(p.get("id", "")))
		_brief_ok(t, str(p.get("id", "")), str(p.get("brief", "")))
		t.eq(str(p.get("_provenance", {}).get("task", "")), "K16", str(p.get("id", "")) + " provenance")
		for m in p.get("unlock_first", []):
			unlocked[str(m)] = true
			t.ok(CardIds.FIRSTS.has(StringName(str(m))), "unlock_first known " + str(m))
	t.eq(page_ids, PAGE_IDS, "rule page ids and order")
	for m2 in CardIds.FIRSTS.keys():
		t.ok(unlocked.has(str(m2)), "unlock_first covers " + str(m2))
	var rows: Array = table.get("rows", [])
	t.eq(rows.size(), 70, "contract table has 70 rows (gd.office + gd.apprentice + gd.scare + gd.pet)")
	var dev: Dictionary = table.get("deviations", {})
	for row in rows:
		var id := str(row.get("id", ""))
		var s: Dictionary = by_id.get(id, {})
		t.ok(not s.is_empty(), "step exists " + id)
		t.eq(s.get("teaches", []), row.get("teaches", []), id + " teaches")
		t.eq(str(s.get("teacher", "")), str(row.get("teacher", "")), id + " teacher")
		t.eq(str(s.get("anchor", "")), str(row.get("anchor", "")), id + " anchor")
		t.eq(str(s.get("rule_page", "")), str(row.get("rule", "")), id + " rule_page")
		var want_fb := str(row.get("fallback", ""))
		var got_fb := str(s.get("anchor_fallback", ""))
		if got_fb != want_fb:
			var why := str(dev.get(id, {}).get("why", ""))
			t.ok(why != "" and str(dev[id].get("anchor_fallback", "")) == got_fb, id + " fallback deviation is explained")
		else:
			t.ok(not dev.has(id) or not dev[id].has("anchor_fallback"), id + " fallback matches the table")
		if row.has("trigger_panel"):
			t.eq(str(s.get("trigger", {}).get("panel", "")), str(row["trigger_panel"]), id + " trigger.panel")
		if row.has("done_when"):
			t.eq(s.get("done_when", []), row["done_when"], id + " done_when")
		if row.has("hand_clear"):
			t.eq(bool(s.get("trigger", {}).get("hand_clear", false)), bool(row["hand_clear"]), id + " hand_clear")
		if row.has("priority"):
			t.eq(int(s.get("priority", -1)), int(row["priority"]), id + " priority")
	t.ok(int(by_id["gd.gold_leave"].get("priority", 0)) > int(by_id["gd.must"].get("priority", 0)), "gd.gold_leave priority above gd.must")
	var index := {}
	for i in range(D1_3.size()):
		index[D1_3[i]] = i
		t.ok(by_id.has(D1_3[i]), "d1_3 step exists " + D1_3[i])
	for id2 in D1_3:
		for a in by_id[id2].get("trigger", {}).get("after", []):
			t.ok(index.has(str(a)) and int(index[str(a)]) < int(index[id2]), id2 + " after " + str(a) + " is earlier")
	var early := 0
	for id3 in D1_3:
		if id3.begins_with("gd.m.") or id3.begins_with("gd.d1."):
			early += 1
	t.ok(early <= int(guide_rules.get("max_new_per_day", 16)), "opening + day 1 steps <= max_new_per_day (%d)" % early)
	t.ok((by_id["gd.d1.deal"].get("done_when", []) as Array).has("ui:hand_played"), "gd.d1.deal done_when includes ui:hand_played")
	for s2 in bundle:
		var sid2 := str(s2.get("id", ""))
		t.eq(int(s2.get("seconds", -1)), 0, sid2 + " has no clock (stays until got it or the deed)")
		t.eq(Array(s2.get("trigger", {}).get("after", [])), AFTER_OK.get(sid2, []), sid2 + " after only within one panel")
	t.ok(not bool(by_id["gd.d1.close"].get("trigger", {}).get("hand_clear", false)), "gd.d1.close is taught on the morning of day 1")
	var db := CardDB.load_all()
	var indexed := 0
	for id in db.all_ids():
		if db.file_of(id) != STEPS_FILE:
			continue
		indexed += 1
		t.ok(by_id.has(id), id + " in steps.json is a K16 step")
	t.eq(indexed, by_id.size(), "CardDB indexes every step in the K16 file")
	for p2 in pages:
		var pid := str(p2.get("id", ""))
		t.eq(db.file_of(pid), PAGES_FILE, pid + " indexed from K16 rule pages")
	t.finish()


func pages_have(pages: Array, id: String) -> bool:
	for p in pages:
		if str(p.get("id", "")) == id:
			return true
	return false


func _brief_ok(t, id: String, brief: String) -> void:
	t.ok(brief.strip_edges() != "", id + " brief non-empty")
	for w in _forbid():
		t.ok(not brief.contains(w), id + " brief hides numbers")
	for q in [_u(0x0022), _u(0x201c), _u(0x201d), _u(0x300c), _u(0x300d), _u(0x300e), _u(0x300f), _u(0x0027)]:
		t.ok(not brief.contains(q), id + " brief has no quoted line")


func _forbid() -> PackedStringArray:
	return PackedStringArray([
		_u(0x6982) + _u(0x7387),
		_u(0x51e0) + _u(0x7387),
		_u(0x767e) + _u(0x5206),
		"%",
		_u(0x70b9) + _u(0x6570),
		_u(0x6743) + _u(0x91cd),
		_u(0x672c) + _u(0x5fc3),
		_u(0x5e95) + _u(0x4ef7),
		_u(0x771f) + _u(0x5047),
	])


func _u(code: int) -> String:
	return char(code)
