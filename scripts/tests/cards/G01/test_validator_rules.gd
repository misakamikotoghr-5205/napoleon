# 完整发行正例及 V01–V42 的独立反例；每个反例都是完整根且只破坏一条规则。
# 主人 G01；合同 §4.9、§12.2。正文全部 ASCII 夹具，不用于发行内容。
extends SceneTree
const H = preload("res://scripts/tests/cards/G01/helper.gd")
const T = preload("res://scripts/tests/cards/lib/card_t.gd")

func _initialize() -> void:
	var t := T.new(self, "G01_validator_rules")
	var base := "res://scripts/tests/cards/G01/fixtures"
	for mode in [&"default", &"strict", &"ship"]:
		var positive := CardValidator.validate(base + "/good", mode)
		t.eq(positive["errors"], PackedStringArray(), "complete positive " + str(mode))
	t.eq(CardValidator.validate(CardDB.DEFAULT_ROOT, &"default", {"examples": true})["errors"], PackedStringArray(), "W0 examples default clean")
	var manifest: Dictionary = CardDB.read_json(base + "/manifest.json")
	# V38/V41 的形状在 CardDslShapes.check_stage（X02）。基线上还没有这个函数时不把缺 API 当成夹具失败。
	var stage_api := (load("res://scripts/cards/api/dsl_shapes.gd") as GDScript).has_method("check_stage")
	for number in range(1, 43):
		var rule := "V%02d" % number
		if not stage_api and rule in ["V38", "V41"]:
			continue
		var spec: Dictionary = manifest[rule]
		var opts: Dictionary = {}
		if str(spec.get("only", "")) != "":
			opts["only"] = PackedStringArray([str(spec["only"])])
		var staged := t.user_dir() + "/" + rule
		H.copy_tree(base + "/good", staged)
		H.copy_tree(base + "/bad/" + rule, staged)
		var negative := CardValidator.validate(staged, StringName(str(spec["mode"])), opts)
		var errors: PackedStringArray = negative["errors"]
		t.ok(not errors.is_empty(), rule + " catches negative")
		for error in errors:
			var allowed := [rule, "V03"] if rule == "V40" else [rule]
			var own := false
			for allowed_rule in allowed:
				own = own or error.contains(" " + allowed_rule + " ")
			t.ok(own, rule + " only allowed error: " + error)
		if rule in ["V09", "V11", "V12", "V16", "V18", "V19", "V21", "V29", "V34", "V36", "V37", "V39", "V42"]:
			var dev := CardValidator.validate(staged, &"default", opts)
			t.eq(dev["errors"], PackedStringArray(), rule + " default NOTE")
			t.ok(not dev["notes"].is_empty(), rule + " emits NOTE")
		if rule == "V37":
			t.eq(CardValidator.validate(staged, &"ship")["errors"], errors, "V37 ship also rejects missing expiry decision")
	# 1.3 改名锚点：开发模式提示，严格/发行模式拒绝。表在 CardIds.ANCHORS_RENAMED（X02）。
	var renamed_api: bool = (load("res://scripts/cards/api/card_ids.gd") as GDScript).get_script_constant_map().has("ANCHORS_RENAMED")
	if renamed_api:
		_check_renamed_anchors(t, base)
	else:
		_check_removed_anchors(t, base)
	# V27 covers every stage beat ref, W0's three narration keys, and registered extra names.
	var stage_text_root := t.user_dir() + "/stage_text"
	H.copy_tree(base + "/good", stage_text_root)
	var stage_text: Dictionary = CardDB.read_json(stage_text_root + "/text/fixture.text.json")
	stage_text["ev.stage.valid"]["lines"].erase("scene")
	H.write(stage_text_root + "/text/fixture.text.json", stage_text)
	_only_rule(t, CardValidator.validate(stage_text_root, &"ship")["errors"], "V27", "stage beat ref")
	var w0_text_root := t.user_dir() + "/w0_stage_text"
	H.copy_tree(base + "/good", w0_text_root)
	var w0_text: Dictionary = CardDB.read_json(w0_text_root + "/text/fixture.text.json")
	w0_text.erase("w0.stage.enter")
	H.write(w0_text_root + "/text/fixture.text.json", w0_text)
	_only_rule(t, CardValidator.validate(w0_text_root, &"ship")["errors"], "V27", "W0 stage narration")
	var extra_text_root := t.user_dir() + "/extra_text"
	H.copy_tree(base + "/good", extra_text_root)
	var extra_text: Dictionary = CardDB.read_json(extra_text_root + "/text/fixture.text.json")
	extra_text.erase("ex_patrol")
	H.write(extra_text_root + "/text/fixture.text.json", extra_text)
	_only_rule(t, CardValidator.validate(extra_text_root, &"ship")["errors"], "V27", "extra name")
	# 显式声明今天的机会可以跳过，不需要写处罚；类型默认仍必须写明。
	var optional_root := t.user_dir() + "/optional_fate"
	H.copy_tree(base + "/good", optional_root)
	H.copy_tree(base + "/bad/V37", optional_root)
	var fate: Dictionary = CardDB.read_json(optional_root + "/era/common/fate.json")
	fate["cards"][0]["must_resolve"] = false
	H.write(optional_root + "/era/common/fate.json", fate)
	t.eq(CardValidator.validate(optional_root, &"strict")["errors"], PackedStringArray(), "V37 respects optional override")
	# 非空到期效果需要打烊后果正文，空的 on_expire 则不要求额外字段。
	var ignored_root := t.user_dir() + "/ignored_text"
	H.copy_tree(base + "/good", ignored_root)
	var text: Dictionary = CardDB.read_json(ignored_root + "/text/fixture.text.json")
	text["lf.any.coal_out"]["outcomes"].erase("ignored")
	H.write(ignored_root + "/text/fixture.text.json", text)
	var missing := CardValidator.validate(ignored_root, &"ship")
	t.ok(not missing["errors"].is_empty(), "ignored consequence text required")
	for error in missing["errors"]:
		t.ok(error.contains(" V27 ") and error.contains("outcomes.ignored"), "ignored only V27: " + error)
	var scoped := CardValidator.validate(t.user_dir() + "/V11", &"strict", {"only": PackedStringArray(["fortune/**"])})
	t.eq(scoped["errors"], PackedStringArray(), "relative glob only hides unrelated errors")
	_check_loop_dusk_pct(t, base)
	t.finish()


# 1.3 改名锚点。只有 CardIds.ANCHORS_RENAMED 已在基线上时才跑。
func _check_renamed_anchors(t, base: String) -> void:
	var renamed_root: String = t.user_dir() + "/renamed_anchor"
	H.copy_tree(base + "/good", renamed_root)
	var steps: Dictionary = CardDB.read_json(renamed_root + "/guide/steps.json")
	steps["cards"][0]["anchor"] = "a.top.notice"
	H.write(renamed_root + "/guide/steps.json", steps)
	var renamed_default := CardValidator.validate(renamed_root, &"default")
	t.eq(renamed_default["errors"], PackedStringArray(), "renamed anchor default is NOTE")
	t.ok(_has_rule(renamed_default["notes"], "V30"), "renamed anchor emits V30 NOTE")
	t.ok(_has_rule(CardValidator.validate(renamed_root, &"strict")["errors"], "V30"), "renamed anchor strict rejects")


# X01-b 删掉 1.2 旧锚点名以后：旧名在所有模式下都是 V30 错（不再只是开发模式提示）。
func _check_removed_anchors(t, base: String) -> void:
	var removed_root: String = t.user_dir() + "/removed_anchor"
	H.copy_tree(base + "/good", removed_root)
	var steps: Dictionary = CardDB.read_json(removed_root + "/guide/steps.json")
	steps["cards"][0]["anchor"] = "a.top.notice"
	H.write(removed_root + "/guide/steps.json", steps)
	for mode in [&"default", &"strict"]:
		t.ok(_has_rule(CardValidator.validate(removed_root, mode)["errors"], "V30"), "removed 1.2 anchor rejected " + str(mode))


# Issue #141: G02's loop.json.dusk_pct is a V25 required key. Missing it fails; 60 passes.
func _check_loop_dusk_pct(t, base: String) -> void:
	var root: String = t.user_dir() + "/loop_dusk"
	H.copy_tree(base + "/good", root)
	var loop: Dictionary = CardDB.read_json(root + "/rules/loop.json")
	loop.erase("dusk_pct")
	H.write(root + "/rules/loop.json", loop)
	var missing: PackedStringArray = CardValidator.validate(root, &"default")["errors"]
	_only_rule(t, missing, "V25", "missing loop.dusk_pct")
	var named := false
	for row in missing:
		named = named or row.contains("dusk_pct")
	t.ok(named, "V25 names missing dusk_pct")
	loop["dusk_pct"] = 60
	H.write(root + "/rules/loop.json", loop)
	for mode in [&"default", &"strict", &"ship"]:
		var present: PackedStringArray = CardValidator.validate(root, mode)["errors"]
		t.eq(present, PackedStringArray(), "loop.dusk_pct present " + str(mode))


func _has_rule(rows: PackedStringArray, rule: String) -> bool:
	for row in rows:
		if row.contains(" " + rule + " "):
			return true
	return false


func _only_rule(t, rows: PackedStringArray, rule: String, label: String) -> void:
	t.ok(not rows.is_empty(), label + " is required")
	for row in rows:
		t.ok(row.contains(" " + rule + " "), label + " only " + rule + ": " + row)

