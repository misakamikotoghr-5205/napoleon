# K15：真 Godot 发行校验（validate_main.gd --mode=ship）双变体回归测试（#212-3 / #202）。
# 覆盖：
# 1) 纯 AI 台词（无 data/cards/text，仅有带合法 ai: 来源的 data/cards/text_ai）在 ai-disclosure 下通过真 validate_main.gd --mode=ship；
# 2) 同一份纯 AI 台词在 no-disclosure 下 FAIL（V27）；
# 3) 人写部分字段（如只写 title）+ AI 补齐其余字段（body / lines.greet）在 ai-disclosure 下按字段 human -> ai 通过，在 no-disclosure 下因缺人写字段 FAIL；
# 4) AI 台词缺字段或坏 _provenance 在 ai-disclosure 下 FAIL（V26 / V27）。
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const H = preload("res://scripts/tests/cards/G01/helper.gd")
const GOOD_BASE := "res://scripts/tests/cards/G01/fixtures/good"
const AI_SOURCE := "ai:google:gemini-2.5-pro:2026-10-18:212-ship-test"


func _initialize() -> void:
	var t := T.new(self, "K15_ship_variants_real")
	var ai_only_root := t.user_dir() + "/ai_only"
	_build_ai_only_root(ai_only_root)

	# 1. 正例：五段文件级 _meta._provenance 在真 CardDB/CardText 与真 validate_main.gd --mode=ship --variant=ai-disclosure 下均通过
	var db_pos := CardDB.load_all(ai_only_root, {"ship": true})
	CardText.setup(db_pos)
	t.eq(db_pos.errors(), PackedStringArray(), "positive 5-segment file _meta._provenance has 0 CardDB errors")
	t.eq(db_pos.ai_text_entry("p.linsao.1938.pawn_hairpin").get("_provenance"), AI_SOURCE, "CardDB loads AI entry with file _meta._provenance")
	t.ok(CardText.card("p.linsao.1938.pawn_hairpin", "title") != "", "CardText resolves AI title in ship mode")
	t.ok(not CardText.is_draft("p.linsao.1938.pawn_hairpin#title"), "CardText marks valid AI field as non-draft")
	var pos_ai := CardValidator.validate(ai_only_root, &"ship", {"variant": "ai-disclosure"})
	t.eq(pos_ai["errors"], PackedStringArray(), "AI-only text passes CardValidator ship in ai-disclosure mode")
	var cli_pos := _run_validate_cli(ai_only_root, "ai-disclosure", "ai_ship_pos")
	t.eq(int(cli_pos["code"]), 0, "validate_main.gd --mode=ship --variant=ai-disclosure exit 0")
	t.ok(str(cli_pos["out"]).contains("CARDS TEST PASS ai_ship_pos"), "validate_main.gd prints CARDS TEST PASS ai_ship_pos")

	# 2. 反例：同一份纯 AI 台词在 no-disclosure 下必须 FAIL（V27）
	var neg_no_ai := CardValidator.validate(ai_only_root, &"ship", {"variant": "no-disclosure"})
	t.ok(not (neg_no_ai["errors"] as PackedStringArray).is_empty(), "AI-only root fails ship validation in no-disclosure mode")
	t.ok(_has_rule(neg_no_ai["errors"], "V27"), "no-disclosure rejects AI-only root with V27")
	var cli_neg := _run_validate_cli(ai_only_root, "no-disclosure", "no_ai_neg")
	t.ok(int(cli_neg["code"]) != 0, "validate_main.gd --mode=ship --variant=no-disclosure exits non-zero")
	t.ok(str(cli_neg["out"]).contains("DATA ERROR:") and str(cli_neg["out"]).contains("V27"), "CLI no-disclosure outputs V27 DATA ERROR")

	# 剥除 text_ai 后（模拟 stage_ship --no-ai）在 no-disclosure 下同样因缺人写字段 FAIL（V27）
	var stripped_no_ai_root := t.user_dir() + "/stripped_no_ai"
	H.copy_tree(ai_only_root, stripped_no_ai_root)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(stripped_no_ai_root + "/text_ai/fixture.text.json"))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(stripped_no_ai_root + "/text_ai"))
	var neg_stripped := CardValidator.validate(stripped_no_ai_root, &"ship", {"variant": "no-disclosure"})
	t.ok(_has_rule(neg_stripped["errors"], "V27"), "stripped no-disclosure root fails V27 on missing human text")

	# 3. 正例 & 反例：人写覆盖部分字段（title）优先于 AI，其余字段（body / lines.greet）回退到 AI
	var partial_root := t.user_dir() + "/partial_override"
	H.copy_tree(ai_only_root, partial_root)
	var ai_doc: Dictionary = CardDB.read_json(partial_root + "/text_ai/fixture.text.json")
	# AI 的 title 故意放违禁 '%'，如果人写 title 生效则不会触发 V27 '%' 错误；body 和 lines.greet 仍由 AI 提供
	ai_doc["p.linsao.1938.pawn_hairpin"]["title"] = "AI_BAD_50%"
	H.write(partial_root + "/text_ai/fixture.text.json", ai_doc)
	H.write(partial_root + "/text/fixture.text.json", {
		"p.linsao.1938.pawn_hairpin": {
			"_provenance": "human:A:2026-10-18",
			"title": "HUMAN_CLEAN_TITLE",
		}
	})
	var pos_partial := CardValidator.validate(partial_root, &"ship", {"variant": "ai-disclosure"})
	t.eq(pos_partial["errors"], PackedStringArray(), "human partial field override + AI fallback passes ship in ai-disclosure mode")
	var neg_partial_no_ai := CardValidator.validate(partial_root, &"ship", {"variant": "no-disclosure"})
	t.ok(_has_rule(neg_partial_no_ai["errors"], "V27"), "partial human text fails no-disclosure ship mode with V27")

	# 4. 反例：ai-disclosure 下缺字段必须报错
	var missing_field_root := t.user_dir() + "/missing_field"
	H.copy_tree(ai_only_root, missing_field_root)
	var miss_doc: Dictionary = CardDB.read_json(missing_field_root + "/text_ai/fixture.text.json")
	miss_doc["p.linsao.1938.pawn_hairpin"]["lines"].erase("greet")
	H.write(missing_field_root + "/text_ai/fixture.text.json", miss_doc)
	var neg_miss := CardValidator.validate(missing_field_root, &"ship", {"variant": "ai-disclosure"})
	t.ok(_has_rule_and_text(neg_miss["errors"], "V27", "lines.greet"), "missing AI field fails V27 in ai-disclosure mode")

	# 5a. 反例：四段来源（缺 model 段）在真 CardDB/CardText 中被拒载且记入 db.warnings()（2026-10-22 起不进 errors，不挡新局），validate_main 同步失败
	var four_seg_root := t.user_dir() + "/four_seg_prov"
	H.copy_tree(ai_only_root, four_seg_root)
	var four_seg_doc: Dictionary = CardDB.read_json(four_seg_root + "/text_ai/fixture.text.json")
	four_seg_doc["_meta"]["_provenance"] = "ai:google-gemini:2026-10-18:212-ship-test"
	H.write(four_seg_root + "/text_ai/fixture.text.json", four_seg_doc)
	_assert_rejected_by_runtime_and_validator(t, four_seg_root, "four_seg_prov")

	# 5b. 反例：缺文件 _meta._provenance、仅条目带五段 _provenance，在真 CardDB/CardText 中被整文件跳过，validate_main 同步失败
	var entry_only_root := t.user_dir() + "/entry_only_prov"
	H.copy_tree(ai_only_root, entry_only_root)
	var entry_only_doc: Dictionary = CardDB.read_json(entry_only_root + "/text_ai/fixture.text.json")
	entry_only_doc["_meta"].erase("_provenance")
	for k in entry_only_doc.keys():
		if not str(k).begins_with("_") and typeof(entry_only_doc[k]) == TYPE_DICTIONARY:
			entry_only_doc[k]["_provenance"] = AI_SOURCE
	H.write(entry_only_root + "/text_ai/fixture.text.json", entry_only_doc)
	_assert_rejected_by_runtime_and_validator(t, entry_only_root, "entry_only_prov")

	# 5c. 反例：文件 _meta._provenance 与条目 _provenance 冲突（文件来源非法/四段，条目写合法五段），CardDB 跳过整文件且 validate_main 同步失败
	var conflict_root := t.user_dir() + "/conflict_prov"
	H.copy_tree(ai_only_root, conflict_root)
	var conflict_doc: Dictionary = CardDB.read_json(conflict_root + "/text_ai/fixture.text.json")
	conflict_doc["_meta"]["_provenance"] = "human:A:2026-10-18"
	for k in conflict_doc.keys():
		if not str(k).begins_with("_") and typeof(conflict_doc[k]) == TYPE_DICTIONARY:
			conflict_doc[k]["_provenance"] = AI_SOURCE
	H.write(conflict_root + "/text_ai/fixture.text.json", conflict_doc)
	_assert_rejected_by_runtime_and_validator(t, conflict_root, "conflict_prov")

	# 5d. 反例：文件 _meta._provenance 为合法五段，但条目自带冲突的五段 _provenance，validate_main 报 V26 拒绝
	var conflict_entry_root := t.user_dir() + "/conflict_entry_prov"
	H.copy_tree(ai_only_root, conflict_entry_root)
	var conflict_entry_doc: Dictionary = CardDB.read_json(conflict_entry_root + "/text_ai/fixture.text.json")
	conflict_entry_doc["p.linsao.1938.pawn_hairpin"]["_provenance"] = "ai:other:model:2026-10-18:other-id"
	H.write(conflict_entry_root + "/text_ai/fixture.text.json", conflict_entry_doc)
	var neg_conflict_entry := CardValidator.validate(conflict_entry_root, &"ship", {"variant": "ai-disclosure"})
	t.ok(_has_rule(neg_conflict_entry["errors"], "V26"), "conflicting entry _provenance against valid file _meta emits V26")
	var cli_conflict_entry := _run_validate_cli(conflict_entry_root, "ai-disclosure", "conflict_entry_prov")
	t.ok(int(cli_conflict_entry["code"]) != 0, "validate_main.gd rejects conflicting entry _provenance")
	t.ok(str(cli_conflict_entry["out"]).contains("V26"), "CLI outputs V26 on conflicting entry _provenance")

	CardText.setup(null)
	t.finish()


func _assert_rejected_by_runtime_and_validator(t: RefCounted, root_path: String, label: String) -> void:
	var db := CardDB.load_all(root_path, {"ship": true})
	CardText.setup(db)
	t.ok(not db.warnings().is_empty(), label + ": CardDB records the load problem in db.warnings()")
	t.eq(db.errors(), PackedStringArray(), label + ": a bad text_ai file does not block a new game")
	t.ok(db.ai_text_entry("p.linsao.1938.pawn_hairpin").is_empty(), label + ": CardDB skips whole text_ai file")
	t.eq(CardText.card("p.linsao.1938.pawn_hairpin", "title"), "", label + ": CardText leaves ship field unresolved")
	t.ok(CardText.is_draft("p.linsao.1938.pawn_hairpin#title"), label + ": CardText reports skipped AI field as draft")
	var res := CardValidator.validate(root_path, &"ship", {"variant": "ai-disclosure"})
	t.ok(_has_rule(res["errors"], "V26"), label + ": CardValidator emits V26")
	t.ok(_has_rule(res["errors"], "V27"), label + ": CardValidator emits V27 because CardDB skipped the file")
	var cli := _run_validate_cli(root_path, "ai-disclosure", label)
	t.ok(int(cli["code"]) != 0, label + ": validate_main.gd --mode=ship --variant=ai-disclosure exits non-zero")
	t.ok(str(cli["out"]).contains("V26") and str(cli["out"]).contains("V27"), label + ": CLI outputs both V26 and V27")


func _build_ai_only_root(dst: String) -> void:
	H.copy_tree(GOOD_BASE, dst)
	var human_doc: Dictionary = CardDB.read_json(dst + "/text/fixture.text.json")
	var ai_doc: Dictionary = {"_meta": {"_provenance": AI_SOURCE}}
	for k in human_doc.keys():
		if str(k).begins_with("_"):
			continue
		var entry: Dictionary = (human_doc[k] as Dictionary).duplicate(true)
		entry.erase("_provenance")
		ai_doc[k] = entry
	H.write(dst + "/text_ai/fixture.text.json", ai_doc)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(dst + "/text/fixture.text.json"))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(dst + "/text"))


func _run_validate_cli(root: String, variant: String, test_name: String) -> Dictionary:
	var output: Array = []
	var args := PackedStringArray([
		"--headless", "--path", ProjectSettings.globalize_path("res://"),
		"-s", "res://scripts/cards/core/validate_main.gd",
		"--", "--mode=ship", "--variant=" + variant,
		"--root=" + ProjectSettings.globalize_path(root),
		"--name=" + test_name,
	])
	var code := OS.execute(OS.get_executable_path(), args, output, true)
	var text := ""
	for chunk in output:
		text += str(chunk) + "\n"
	return {"code": code, "out": text}


func _has_rule(errors: PackedStringArray, rule: String) -> bool:
	for err in errors:
		if str(err).contains(" " + rule + " "):
			return true
	return false


func _has_rule_and_text(errors: PackedStringArray, rule: String, needle: String) -> bool:
	for err in errors:
		if str(err).contains(" " + rule + " ") and str(err).contains(needle):
			return true
	return false
