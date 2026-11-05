# RG3：肉鸽 v1 的数据与 AI 基础层正文（docs/cards/rogue/ROGUE_V1.md §5.6、§6、§12、§14 RG3）。
# 12 件老物件（寻常 5 / 有来历 5 / 镇店 2）、6 种客源；每件 title body use lines.gain 有字，
# 有毛病（flaw 行或 downsides）的有 lines.flaw；货郎五个字段有字；这些正文没有阿拉伯数字、百分号、
# “倍”“几成”“几分”和 §6.7 的禁用词；所有 art 在美术清单里；tutorial.json 恰好 §5.6 的 9 张教学牌
# 日程带 {"not": {"veteran": true}}，其余 3 张没带。中文词表写成 \u 转义（测试脚本只放 ASCII 字面量）。
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")

const PROVENANCE := "ai:claude:opus-5.5:2026-10-25:rogue-v1"
const PEDDLER := "p.stranger_peddler.1938.curios"
const DEPTHS := {"plain": 5, "storied": 5, "treasure": 2}
const CARD_FIELDS := ["title", "body", "use", "lines.gain"]
const PEDDLER_FIELDS := ["title", "body", "lines.greet", "choices.look", "choices.send_off"]
const VETERAN_SKIP := [
	"p.brother.1938.tut_handover", "p.zhang.1938.tut_pawn", "p.wu.1938.tut_sell", "p.xiaoding.1938.tut_buy",
	"p.sunyoung.1938.tut_pawn", "p.guanjia.1938.tut_buy", "ev.1938.tut_slots", "p.li.1938.tut_sell",
	"p.postman.1938.tut_buy"]
const VETERAN_WHEN := {"not": {"veteran": true}}
# ROGUE_V1 §6.2: never in a relic / source row (V04 text keys, V07 integer keys, unregistered tags).
const BANNED_KEYS := ["title", "body", "name", "lines", "text", "label", "desc", "grade", "tier", "order", "tags"]
const RELIC_MODS := ["price_pct", "patience_pct", "appraise_pct", "shelf_cap", "kept_cap", "deal_count", "pool_weight", "coins"]
const SOURCE_MODS := ["pool_weight", "deal_count"]
const RELIC_CLAMPS := ["price_pay", "price_receive", "patience", "appraise", "pool", "shelf_cap", "kept_cap", "deal_count", "coins"]
# 倍 几分 耐心 鉴定 权重 档位 修正 概率 加成 触发 冷却 属性 稀有 传说 史诗 遗物 装备
const BANNED_WORDS := [
	"\u500d", "\u51e0\u5206", "\u8010\u5fc3", "\u9274\u5b9a", "\u6743\u91cd", "\u6863\u4f4d", "\u4fee\u6b63",
	"\u6982\u7387", "\u52a0\u6210", "\u89e6\u53d1", "\u51b7\u5374", "\u5c5e\u6027", "\u7a00\u6709", "\u4f20\u8bf4",
	"\u53f2\u8bd7", "\u9057\u7269", "\u88c5\u5907", "buff"]
# 一二三四五六七八九十两几半 + 成 ("three tenths" style amounts)
const NUMERALS := "\u4e00\u4e8c\u4e09\u56db\u4e94\u516d\u4e03\u516b\u4e5d\u5341\u4e24\u51e0\u534a"
const CHENG := "\u6210"

var _digit_re := RegEx.create_from_string("[0-9\\x{ff10}-\\x{ff19}%\\x{ff05}]")


func _initialize() -> void:
	var t := T.new(self, "RG3_data")
	var db := CardDB.load_all()
	t.eq(db.errors(), PackedStringArray(), "real data loads without errors")
	var art: Dictionary = (CardDB.read_json("res://data/cards/art/manifest.json") as Dictionary).get("art", {})
	_relics(t, db, art)
	_sources(t, db, art)
	_peddler(t, db, art)
	_rules(t, db)
	_tutorial(t)
	_ascii_literals(t)
	t.finish()


func _relics(t, db: CardDB, art: Dictionary) -> void:
	var ids := db.ids_of(&"relic")
	t.eq(ids.size(), 12, "twelve relics")
	var depth_count := {}
	var plain_open := 0
	for id in ids:
		var c := db.def(id)
		t.eq(db.file_of(id), "era/common/relics.json", id + " lives in relics.json")
		var depth := str(c.get("depth", ""))
		t.ok(DEPTHS.has(depth), id + " depth is plain / storied / treasure")
		depth_count[depth] = int(depth_count.get(depth, 0)) + 1
		if depth == "plain" and not c.has("conditions"):
			plain_open += 1
		_row_common(t, c, id, art, "prop.relic." + id.substr(3))
		_mod_rows(t, c, id, RELIC_MODS)
		for hook_key in ["passives", "downsides"]:
			for row in c.get(hook_key, []):
				t.ok(str(row.get("hook", "")) in ["day_start", "settle"], "%s %s hook" % [id, hook_key])
		for field in CARD_FIELDS:
			_field(t, db, id, field)
		if _has_flaw(c):
			_field(t, db, id, "lines.flaw")
		_clean_entry(t, db, id)
	for depth in DEPTHS.keys():
		t.eq(int(depth_count.get(depth, 0)), int(DEPTHS[depth]), "relic depth count " + str(depth))
	# The day-8 peddler offers two plain relics; before the cat arrives only unconditional ones qualify.
	t.ok(plain_open >= 2, "at least two unconditional plain relics for the peddler")


func _sources(t, db: CardDB, art: Dictionary) -> void:
	var ids := db.ids_of(&"source")
	t.eq(ids.size(), 6, "six customer sources")
	for id in ids:
		var c := db.def(id)
		t.eq(db.file_of(id), "era/common/sources.json", id + " lives in sources.json")
		t.ok(not c.has("depth") and not c.has("passives") and not c.has("downsides"), id + " has no relic-only keys")
		_row_common(t, c, id, art, "illus.ky." + id.substr(3))
		_mod_rows(t, c, id, SOURCE_MODS)
		for field in CARD_FIELDS:
			_field(t, db, id, field)
		_clean_entry(t, db, id)


## Fields every relic / source row shares (ROGUE_V1 §6.2).
func _row_common(t, c: Dictionary, id: String, art: Dictionary, want_art: String) -> void:
	t.eq(c.get("era", []), ["*"], id + " era")
	t.ok(typeof(c.get("weight")) == TYPE_INT and int(c.get("weight", 0)) > 0, id + " integer weight > 0")
	t.eq(str(c.get("art", "")), want_art, id + " art id")
	t.ok(art.has(str(c.get("art", ""))), id + " art is in the manifest")
	t.ok(str(c.get("brief", "")) != "", id + " brief")
	t.eq(c.get("_provenance", {}), {"by": "ai", "task": "RG3", "date": "2026-10-25"}, id + " _provenance")
	for key in BANNED_KEYS:
		t.ok(not _has_key(c, key), "%s has no %s key at any depth" % [id, key])


func _mod_rows(t, c: Dictionary, id: String, allowed: Array) -> void:
	t.ok(typeof(c.get("mods")) == TYPE_ARRAY, id + " mods is an array")
	for row in c.get("mods", []):
		t.ok(str(row.get("mod", "")) in allowed, "%s mod %s allowed" % [id, row.get("mod", "")])
		if row.has("pct"):
			t.ok(typeof(row["pct"]) == TYPE_INT and int(row["pct"]) >= 1 and int(row["pct"]) <= 400, id + " pct 1..400")
		if row.has("delta"):
			t.ok(typeof(row["delta"]) == TYPE_INT, id + " integer delta")
		if row.has("when"):
			t.eq(CardDslShapes.check_cond(row["when"]), "", id + " when is a valid condition")


func _has_flaw(c: Dictionary) -> bool:
	if not (c.get("downsides", []) as Array).is_empty():
		return true
	for row in c.get("mods", []):
		if bool(row.get("flaw", false)):
			return true
	return false


func _peddler(t, db: CardDB, art: Dictionary) -> void:
	var c := db.def(PEDDLER)
	t.ok(not c.is_empty(), "peddler card exists")
	t.eq(db.file_of(PEDDLER), "era/1938/curio_peddler.json", "peddler lives in curio_peddler.json")
	t.eq(str(c.get("person", "")), "stranger_peddler", "peddler reuses stranger_peddler")
	t.eq(int(c.get("weight", -1)), 0, "peddler weight 0 (scheduled only)")
	t.eq(c.get("schedule", {}), {"stage_day": 8, "order": 50}, "peddler comes on day 8")
	t.ok("omen_wealth" in c.get("tags", []), "peddler has an omen tag")
	t.ok(art.has(str(c.get("art", ""))), "peddler art is in the manifest")
	var by_choice := {}
	for ch in c.get("choices", []):
		by_choice[str(ch.get("id", ""))] = ch.get("effects", [])
	t.eq(by_choice.keys().size(), 2, "peddler has two choices")
	t.eq(by_choice.get("send_off", null), [], "send_off does nothing")
	var look: Array = by_choice.get("look", [])
	t.eq(look.size(), 1, "look has one effect")
	if look.size() == 1:
		t.eq(look[0], {"op": "stock_offer", "n": 2, "kinds": ["relic"], "depths": ["plain"], "from": "peddler"}, "look opens a plain two-way offer")
	for field in PEDDLER_FIELDS:
		_field(t, db, PEDDLER, field)
	_clean_entry(t, db, PEDDLER)


func _rules(t, db: CardDB) -> void:
	var relics := db.rules("relics")
	t.ok(relics.get("enabled", false) == true, "rules/relics enabled")
	t.ok(typeof(relics.get("cap")) == TYPE_INT and int(relics.get("cap", 0)) > 0, "rules/relics cap")
	for key in ["dormant_in_street", "dormant_in_prison"]:
		t.ok(typeof(relics.get(key)) == TYPE_BOOL, "rules/relics " + key)
	_int_clamp(t, relics.get("clamp", {}), "relics", RELIC_CLAMPS)
	var stock := db.rules("stock")
	t.ok(stock.get("enabled", false) == true, "rules/stock enabled")
	t.ok(not (stock.get("week_days", []) as Array).is_empty(), "rules/stock week_days")
	for key in ["deals_needed", "offers_full", "offers_few"]:
		t.ok(typeof(stock.get(key)) == TYPE_INT, "rules/stock " + key)
	for kind in stock.get("slot_kinds", []):
		t.ok(str(kind) in ["relic", "source"], "rules/stock slot kind " + str(kind))
	_int_clamp(t, stock.get("clamp", {}), "stock", ["pool", "deal_count"])
	var openings: Dictionary = db.rules("legacy").get("openings", {})
	t.eq(openings.keys().size(), 2, "two openings")
	t.ok(openings.get("og.default", {}).get("veteran", true) == false, "og.default is not veteran")
	t.ok(openings.get("og.shanghai", {}).get("veteran", false) == true, "og.shanghai is veteran")
	t.eq(str(openings.get("og.shanghai", {}).get("notice", "")), "rg5.notice.shanghai", "og.shanghai notice key")
	for id in openings.keys():
		for key in ["unlock_closed", "order"]:
			t.ok(typeof(openings[id].get(key)) == TYPE_INT, "%s %s is an integer" % [id, key])
	var chron: Dictionary = db.rules("legacy").get("chronicle", {})
	t.ok(typeof(chron.get("kind_at")) == TYPE_INT and typeof(chron.get("hard_at")) == TYPE_INT, "chronicle thresholds")


func _int_clamp(t, clamp: Dictionary, label: String, kinds: Array) -> void:
	for kind in kinds:
		var lo := str(kind) + "_min"
		var hi := str(kind) + "_max"
		t.ok(typeof(clamp.get(lo)) == TYPE_INT and typeof(clamp.get(hi)) == TYPE_INT, "%s clamp %s integers" % [label, kind])
		t.ok(int(clamp.get(lo, 0)) <= int(clamp.get(hi, 0)), "%s clamp %s min <= max" % [label, kind])


func _tutorial(t) -> void:
	var doc: Dictionary = CardDB.read_json("res://data/cards/era/1938/tutorial.json")
	t.eq(str(doc.get("_meta", {}).get("owner", "")), "K16", "tutorial.json stays K16's")
	var cards: Array = doc.get("cards", [])
	t.eq(cards.size(), 12, "tutorial.json has twelve cards")
	var with_when := []
	for c in cards:
		var id := str(c.get("id", ""))
		var sch: Dictionary = c.get("schedule", {})
		if sch.has("when"):
			with_when.append(id)
			t.eq(sch["when"], VETERAN_WHEN, id + " schedule.when skips veterans")
			t.ok(int(sch.get("stage_day", 0)) in [1, 2, 3], id + " is a day 1-3 lesson")
		else:
			t.ok(int(sch.get("stage_day", 0)) in [5, 6, 7], id + " (days 5-7) keeps its schedule")
	with_when.sort()
	var want := VETERAN_SKIP.duplicate()
	want.sort()
	t.eq(with_when, want, "exactly the nine section 5.6 lessons carry the veteran when")


## ROGUE_V1 section 14: no Chinese string literals in .gd. In the RG3 test scripts only comment lines may
## carry non-ASCII; the word lists above are \u escapes and must decode to the intended characters.
func _ascii_literals(t) -> void:
	t.ok(CHENG == String.chr(0x6210) and String.chr(0x500d) in BANNED_WORDS, "escaped word lists decode")
	var dir := "res://scripts/tests/cards/RG3/"
	var names := Array(DirAccess.get_files_at(dir))
	names.sort()
	for name in names:
		if not str(name).ends_with(".gd"):
			continue
		var lines := FileAccess.get_file_as_string(dir + str(name)).split("\n")
		t.ok(lines.size() > 1, str(name) + " readable")
		for i in range(lines.size()):
			var line: String = lines[i]
			if line.strip_edges().begins_with("#"):
				continue
			var ascii := true
			for j in range(line.length()):
				if line.unicode_at(j) > 127:
					ascii = false
					break
			t.ok(ascii, "%s:%d code line is ASCII" % [name, i + 1])


## The text comes from the AI base layer with the rogue-v1 provenance.
func _field(t, db: CardDB, id: String, field: String) -> void:
	t.ok(db.text_value(id, field) != "", "%s#%s has text" % [id, field])
	t.eq(db.text_source(id, field), "ai", "%s#%s comes from the AI base layer" % [id, field])


## Every string of the entry (title, body, use, lines.*, choices.*, outcomes.*): no figures, no banned words.
func _clean_entry(t, db: CardDB, id: String) -> void:
	var entry := db.ai_text_entry(id)
	t.eq(str(entry.get("_provenance", "")), PROVENANCE, id + " AI text provenance")
	var texts := PackedStringArray()
	_strings(entry, id, texts)
	t.ok(texts.size() >= 4, id + " has text entries")
	for row in texts:
		var at := row.find("=")
		var path := row.substr(0, at)
		var s := row.substr(at + 1)
		t.ok(_digit_re.search(s) == null, "%s has no digit or percent sign: %s" % [path, s])
		for word in BANNED_WORDS:
			t.ok(s.to_lower().find(word) < 0, "%s avoids a banned word: %s" % [path, s])
		for i in range(NUMERALS.length()):
			t.ok(s.find(NUMERALS[i] + CHENG) < 0, "%s states no tenths: %s" % [path, s])


func _strings(v, path: String, out: PackedStringArray) -> void:
	if typeof(v) == TYPE_STRING:
		out.append(path + "=" + v)
	elif typeof(v) == TYPE_DICTIONARY:
		var keys: Array = v.keys()
		keys.sort()
		for k in keys:
			if not str(k).begins_with("_"):
				_strings(v[k], path + "." + str(k), out)


func _has_key(v, key: String) -> bool:
	if typeof(v) == TYPE_DICTIONARY:
		for k in v.keys():
			if str(k) == key or _has_key(v[k], key):
				return true
	elif typeof(v) == TYPE_ARRAY:
		for item in v:
			if _has_key(item, key):
				return true
	return false
