# 剧情插件层（packs/<id>/text/**）：按字段穿透各层、插件叠放顺序、停用/启用、坏插件只警告不挡新局、
# 不改机制哈希、.pck 挂载、校验器的 V26/V27，以及缺字默认空串（has_text）。夹具正文全是 ASCII 假字。
# 框架版收尾（2026-10-22，Claude）；合同 §4.5，说明 docs/cards/PLUGINS.md。
extends SceneTree
const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const H = preload("res://scripts/tests/cards/G01/helper.gd")
const GOOD := "res://scripts/tests/cards/G01/fixtures/good"
const CARD := "p.linsao.1938.pawn_hairpin"
const HUMAN_PROV := "human:A:2026-10-22"
const AI_PROV := "ai:fixture:fixture:2026-10-22:packs-test"


func _initialize() -> void:
	var t := T.new(self, "G01_packs")
	var root: String = t.user_dir() + "/cards"
	var packs: String = t.user_dir() + "/packs"
	H.copy_tree(GOOD, root)
	_layers(t, root, packs)
	_bad_packs_do_not_block(t, root, packs)
	_validator(t, root, packs)
	_example_pack(t)
	_pck(t, root)
	_fallback(t, root)
	CardText.setup(null)
	t.finish()


func _manifest(id: String, source: String, extra: Dictionary = {}) -> Dictionary:
	var m := {"id": id, "name": "PACK_" + id, "version": "1", "source": source,
		"_provenance": HUMAN_PROV if source == "human" else AI_PROV, "compat": "cards-text/1"}
	m.merge(extra, true)
	return m


func _pack(dir: String, id: String, source: String, text: Dictionary, extra: Dictionary = {}) -> void:
	H.write(dir + "/" + id + "/pack.json", _manifest(id, source, extra))
	if not text.is_empty():
		H.write(dir + "/" + id + "/text/era/1938/people.text.json", text)


func _raw(path: String, text: String) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()


func _opts(packs: String, extra: Dictionary = {}) -> Dictionary:
	var o := {"packs": [packs], "pck_dirs": []}
	o.merge(extra, true)
	return o


func _state(db: CardDB, id: String) -> String:
	for row in db.packs():
		if str(row["id"]) == id:
			return str(row["state"])
	return "absent"


func _warned(db: CardDB, needle: String) -> bool:
	for w in db.warnings():
		if str(w).contains(needle):
			return true
	return false


# 人写层只给 title / body / greet；AI 层给 title 与选项；插件只给部分字段。
func _layers(t, root: String, packs: String) -> void:
	H.write(root + "/text_ai/era/1938/people.text.json", {"_meta": {"_provenance": AI_PROV},
		CARD: {"title": "AI_TITLE", "lines": {"accept": "AI_ACCEPT"}}})
	var base := CardDB.load_all(root, {"no_packs": true})
	_pack(packs, "alpha", "human", {CARD: {"body": "ALPHA_BODY", "lines": {"greet": "ALPHA_GREET", "leave": "ALPHA_LEAVE"}}},
		{"order": 10})
	_pack(packs, "beta", "ai", {"_meta": {"_provenance": AI_PROV}, CARD: {"lines": {"greet": "BETA_GREET"}}}, {"order": 20})
	_pack(packs, "gamma", "human", {CARD: {"title": "GAMMA_TITLE", "lines": {"greet": "GAMMA_GREET"}}},
		{"order": 30, "enabled": false})
	# 同 order 按 id：zeta 在 beta 之上
	_pack(packs, "zeta", "human", {CARD: {"lines": {"leave": "ZETA_LEAVE"}}}, {"order": 20})
	var db := CardDB.load_all(root, _opts(packs))
	CardText.setup(db)
	t.eq(db.errors(), PackedStringArray(), "story packs never enter errors()")
	t.eq(db.hash(), base.hash(), "text-only packs leave the mechanism hash alone")
	t.eq(CardText.card(CARD, "title"), "TXT_1", "pack without title falls through to the human layer")
	t.eq(CardText.card(CARD, "body"), "ALPHA_BODY", "pack field wins over the human layer")
	t.eq(CardText.card(CARD, "lines.greet"), "BETA_GREET", "higher order pack wins per field")
	t.eq(CardText.card(CARD, "lines.leave"), "ZETA_LEAVE", "same order: later id wins")
	t.eq(CardText.card(CARD, "lines.accept"), "AI_ACCEPT", "field nobody above writes reaches the AI layer")
	t.eq(db.text_source(CARD, "lines.greet"), "pack:beta", "source of greet")
	t.eq(db.text_source(CARD, "body"), "pack:alpha", "source of body")
	t.eq(db.text_source(CARD, "title"), "human", "source of title")
	t.eq(db.text_source(CARD, "lines.accept"), "ai", "source of accept")
	t.eq(db.text_source(CARD, "lines.refused"), "", "no source")
	t.eq(db.text_entry(CARD).get("body"), "TXT_1", "raw human entry is untouched by packs")
	t.ok(not db.ai_text_entry(CARD).has("body"), "raw AI entry is untouched by packs")
	t.eq(db.pack_text_entry("alpha", CARD)["lines"]["greet"], "ALPHA_GREET", "pack entry accessor")
	t.eq(db.pack_hit(CARD, "lines.greet").get("source"), "ai", "pack hit reports the pack source")
	t.eq(_state(db, "gamma"), "disabled", "enabled false is not loaded")
	var order: Array = []
	for row in db.packs():
		if str(row["state"]) == "loaded":
			order.append(row["id"])
	t.eq(order, ["alpha", "beta", "zeta"], "loaded packs stacked by order then id")
	t.ok(not db.packs()[0].has("text"), "packs() returns no text")
	var enabled := CardDB.load_all(root, _opts(packs, {"enable_packs": ["gamma"]}))
	t.eq(enabled.text_value(CARD, "title"), "GAMMA_TITLE", "enable_packs turns a disabled pack on")
	var no_beta := CardDB.load_all(root, _opts(packs, {"disable_packs": ["beta"]}))
	t.eq(no_beta.text_value(CARD, "lines.greet"), "ALPHA_GREET", "disable_packs drops one pack")
	var no_ai := CardDB.load_all(root, _opts(packs, {"no_ai": true}))
	t.eq(no_ai.text_value(CARD, "lines.greet"), "ALPHA_GREET", "no_ai build skips AI packs")
	t.ok(_warned(no_ai, "AI pack in a no-AI build"), "skipped AI pack is reported")
	t.eq(CardDB.load_all(root, {}).packs(), [], "other data roots read no packs by default")
	# 改插件正文让缓存失效，哈希不变
	H.write(packs + "/beta/text/era/1938/people.text.json", {CARD: {"lines": {"greet": "BETA_NEW"}}})
	var edited := CardDB.load_all(root, _opts(packs))
	t.ok(edited != db, "pack edit invalidates the cache")
	t.eq(edited.text_value(CARD, "lines.greet"), "BETA_NEW", "edited pack text visible")
	t.eq(edited.hash(), base.hash(), "pack edit leaves the hash alone")


func _bad_packs_do_not_block(t, root: String, packs: String) -> void:
	_raw(packs + "/bad_json/pack.json", "{not json")
	_pack(packs, "bad_prov", "ai", {CARD: {"title": "BAD"}}, {"_provenance": HUMAN_PROV})
	_pack(packs, "bad_key", "human", {CARD: {"title": "BAD"}}, {"enabeld": false})
	_pack(packs, "bad_compat", "human", {CARD: {"title": "BAD"}}, {"compat": "cards-text/9"})
	H.write(packs + "/mismatch/pack.json", _manifest("other_id", "human"))
	_pack(packs, "needs", "human", {CARD: {"title": "BAD"}}, {"requires": ["missing_pack"]})
	_pack(packs, "partial", "human", {CARD: {"lines": {"refused": "PARTIAL_REFUSED"}}, "no.such.key": {"t": "BAD"},
		"bad.entry": 7}, {"order": 5})
	_raw(packs + "/partial/text/broken.text.json", "[1, 2")
	H.write(packs + "/partial/text/wrong_source.text.json", {"_meta": {"_provenance": AI_PROV}, CARD: {"title": "BAD"}})
	var db := CardDB.load_all(root, _opts(packs))
	CardText.setup(db)
	t.eq(db.errors(), PackedStringArray(), "bad packs never block a new game")
	for id in ["bad_json", "bad_prov", "bad_key", "bad_compat", "mismatch", "needs"]:
		t.eq(_state(db, id), "skipped", id + " skipped")
	t.ok(_warned(db, "bad_json/pack.json: pack.json cannot be parsed"), "invalid manifest JSON reported")
	t.ok(_warned(db, "_provenance must match"), "bad provenance reported")
	t.ok(_warned(db, "unknown manifest key 'enabeld'"), "unknown manifest key reported")
	t.ok(_warned(db, "compat 'cards-text/9'"), "unsupported compat reported")
	t.ok(_warned(db, "must equal its folder name"), "id mismatch reported")
	t.ok(_warned(db, "requires pack 'missing_pack'"), "missing requirement reported")
	t.eq(_state(db, "partial"), "loaded", "pack with a few bad files still loads")
	t.ok(_warned(db, "unknown text key no.such.key"), "unknown text key reported")
	t.ok(_warned(db, "entry bad.entry is not an object"), "bad entry reported")
	t.ok(_warned(db, "broken.text.json: pack text cannot be parsed"), "bad text file reported")
	t.ok(_warned(db, "wrong_source.text.json: _meta._provenance does not match"), "file source mismatch reported")
	t.eq(CardText.card(CARD, "lines.refused"), "PARTIAL_REFUSED", "good entries of a partial pack load")
	t.ok(CardText.card(CARD, "title") != "BAD", "skipped packs and files give no text")
	# 坏的 AI 基础层文件也只警告：新局照开（以前 db.errors() 非空会让 game.new 失败）
	var game_root: String = t.user_dir() + "/game"
	H.copy_tree(GOOD, game_root)
	H.write(game_root + "/text_ai/broken.text.json", {"_meta": {"_provenance": "ai:incomplete"}, CARD: {"title": "BAD"}})
	_raw(game_root + "/text_ai/not_json.text.json", "{")
	var gdb := CardDB.load_all(game_root)
	t.eq(gdb.errors(), PackedStringArray(), "bad text_ai files stay out of errors()")
	t.eq(gdb.warnings().size(), 2, "bad text_ai files are warnings")
	var engine := CardEngine.new()
	var res := engine.new_game({"seed": 7, "data_root": game_root, "only_examples": false, "save_dir": game_root + "/saves"})
	t.ok(bool(res.get("ok", false)), "new game starts with a malformed text_ai file: %s" % res)
	var strict := CardValidator.validate(game_root, &"strict", {"packs": []})
	t.ok(_has(strict["errors"], "text_ai/broken.text.json", "V26"), "strict validation still reports bad text_ai provenance")
	t.ok(_has(strict["errors"], "text_ai/not_json.text.json", ""), "strict validation still reports unparsable text_ai")


func _validator(t, root: String, packs: String) -> void:
	var res := CardValidator.validate(root, &"strict", {"packs": [packs]})
	var errors: PackedStringArray = res["errors"]
	for needle in ["bad_json/pack.json", "bad_prov/pack.json", "bad_key/pack.json", "bad_compat/pack.json",
			"mismatch/pack.json", "partial/text/broken.text.json", "partial/text/wrong_source.text.json"]:
		t.ok(_has(errors, needle, "V26"), "V26 for " + needle)
	t.ok(_has(errors, "no.such.key", "V26"), "unknown key is V26 in strict validation")
	for good in ["alpha/", "beta/", "zeta/", "gamma/"]:
		t.ok(not _has(errors, good, ""), "valid pack %s has no error" % good)
	var only: String = t.user_dir() + "/packs_v"
	_pack(only, "pct", "human", {CARD: {"body": "50% off"}})
	_pack(only, "field", "human", {CARD: {"nope": "X"}})
	_pack(only, "code", "human", {})
	_raw(only + "/code/run.gd", "extends Node\n")
	_pack(only, "nocompat", "human", {})
	var m: Dictionary = CardDB.read_json(only + "/nocompat/pack.json")
	m.erase("compat")
	H.write(only + "/nocompat/pack.json", m)
	_pack(only, "future", "human", {}, {"cards": ["cards/new.json"]})
	var v := CardValidator.validate(root, &"strict", {"packs": [only]})
	t.ok(_has(v["errors"], "pct/", "percent sign"), "percent sign in pack text is V26")
	t.ok(_has(v["errors"], "field/", "field 'nope'"), "unknown field is V26")
	t.ok(_has(v["errors"], "code/run.gd", "V26"), "code files are not allowed in a pack")
	t.ok(_has(v["errors"], "nocompat/", "compat missing"), "compat is required by the validator")
	t.ok(_has(v["errors"], "future/", "reserved"), "cards delta reported in strict mode")
	var dev := CardValidator.validate(root, &"default", {"packs": [only]})
	t.ok(not _has(dev["errors"], "future/", "reserved") and _has(dev["notes"], "future/", "reserved"), "cards delta only a NOTE in default mode")
	# 发行覆盖：人写层缺 body，由插件补上
	var ship_root: String = t.user_dir() + "/ship"
	H.copy_tree(GOOD, ship_root)
	var text: Dictionary = CardDB.read_json(ship_root + "/text/fixture.text.json")
	text[CARD].erase("body")
	H.write(ship_root + "/text/fixture.text.json", text)
	var missing := CardValidator.validate(ship_root, &"ship", {"packs": []})
	t.ok(_has(missing["errors"], CARD, "missing human text 'body'"), "fixture really misses body")
	var ai_packs: String = t.user_dir() + "/ship_ai"
	_pack(ai_packs, "story", "ai", {CARD: {"body": "AI_PACK_BODY"}})
	var with_ai := CardValidator.validate(ship_root, &"ship", {"packs": [ai_packs], "variant": "ai-disclosure"})
	t.eq(with_ai["errors"], PackedStringArray(), "AI pack covers the field in the ai-disclosure build")
	var no_disc := CardValidator.validate(ship_root, &"ship", {"packs": [ai_packs], "variant": "no-disclosure"})
	t.ok(_has(no_disc["errors"], "story/pack.json", "V27"), "AI pack must not be present in the no-disclosure build")
	t.ok(_has(no_disc["errors"], CARD, "missing human text 'body'"), "AI pack does not count in the no-disclosure build")
	var human_packs: String = t.user_dir() + "/ship_human"
	_pack(human_packs, "story", "human", {CARD: {"body": "HUMAN_PACK_BODY"}})
	var human := CardValidator.validate(ship_root, &"ship", {"packs": [human_packs], "variant": "no-disclosure"})
	t.eq(human["errors"], PackedStringArray(), "human pack covers the field in the no-disclosure build")


# .pck 里放 packs/<id>/**，挂上后就是 res://packs/<id>/
func _pck(t, root: String) -> void:
	var src: String = t.user_dir() + "/pck_src"
	H.write(src + "/pack.json", _manifest("_pcktest", "human", {"order": 1}))
	H.write(src + "/people.text.json", {CARD: {"lines": {"impatient": "PCK_IMPATIENT"}}})
	var pck_dir: String = t.user_dir() + "/pcks"
	DirAccess.make_dir_recursive_absolute(pck_dir)
	var packer := PCKPacker.new()
	t.eq(packer.pck_start(pck_dir + "/story.pck"), OK, "pck start")
	t.eq(packer.add_file("res://packs/_pcktest/pack.json", src + "/pack.json"), OK, "pck add manifest")
	t.eq(packer.add_file("res://packs/_pcktest/text/era/1938/people.text.json", src + "/people.text.json"), OK, "pck add text")
	t.eq(packer.flush(), OK, "pck flush")
	var db := CardDB.load_all(root, {"packs": ["res://packs"], "pck_dirs": [pck_dir]})
	t.eq(_state(db, "_pcktest"), "loaded", "pack inside a mounted .pck is read from res://packs")
	t.eq(db.text_value(CARD, "lines.impatient"), "PCK_IMPATIENT", "pck pack text visible")
	t.eq(_state(db, "_example"), "disabled", "folder packs next to the mounted one still listed")


# 真数据 + 仓库里的示例插件（默认停用）
func _example_pack(t) -> void:
	var off := CardDB.load_all(CardDB.DEFAULT_ROOT, {"packs": ["res://packs"], "pck_dirs": []})
	t.eq(_state(off, "_example"), "disabled", "example pack is off by default")
	var on := CardDB.load_all(CardDB.DEFAULT_ROOT, {"packs": ["res://packs"], "pck_dirs": [], "enable_packs": ["_example"]})
	t.eq(_state(on, "_example"), "loaded", "example pack can be enabled")
	t.eq(on.errors(), PackedStringArray(), "example pack: no errors")
	var stage: Dictionary = CardDB.read_json("res://packs/_example/text/era/1938/stage.text.json")
	t.eq(on.text_value("stage.1938", "intro.p1"), str(stage["stage.1938"]["intro"]["p1"]), "example intro p1")
	t.ok(on.text_source("stage.1938", "intro.p2") != "pack:_example", "example pack leaves p2 to the base layers")
	t.ok(on.text_source("p.chen.1938.buy_scroll", "title") != "pack:_example", "example pack leaves the title to the base")
	t.eq(on.text_source("p.chen.1938.buy_scroll", "lines.greet"), "pack:_example", "example greet from the pack")
	t.eq(on.hash(), off.hash(), "example pack keeps the real data hash")


# 缺字：默认空串，开发开关开时【稿】+ brief；has_text 给界面判断
func _fallback(t, root: String) -> void:
	CardText.setup(CardDB.load_all(root, {"no_packs": true}))
	CardText.set_show_drafts(false)
	t.ok(not CardText.shows_drafts(), "drafts off")
	t.eq(CardText.card(CARD, "lines.refused"), "", "missing text is empty by default")
	t.ok(not CardText.has_text(CARD + "#lines.refused"), "has_text false for missing text")
	t.ok(CardText.has_text(CARD + "#title"), "has_text true for written text")
	t.ok(not CardText.issued_contains(""), "empty fallback is not issued")
	CardText.set_show_drafts(true)
	var draft := CardText.card(CARD, "lines.refused")
	var mark: Dictionary = CardDB.read_json(CardText.DEV_STRINGS)
	t.ok(draft.begins_with(str(mark["draft_mark"])), "drafts on: draft mark")
	t.ok(CardText.issued_contains(draft), "draft text issued")
	t.ok(not CardText.has_text(CARD + "#lines.refused"), "has_text stays false while showing drafts")


func _has(errors, needle: String, rule: String) -> bool:
	for e in errors:
		if str(e).contains(needle) and (rule == "" or str(e).contains(rule)):
			return true
	return false
