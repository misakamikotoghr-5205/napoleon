# V25：G02 的 loop.json.dusk_pct 是必需键（#141）。缺了报 V25，写上 60 则通过。
# 主人 G01。不改 G02 的规则文件，只用本任务夹具。
extends SceneTree
const H = preload("res://scripts/tests/cards/G01/helper.gd")
const T = preload("res://scripts/tests/cards/lib/card_t.gd")

func _initialize() -> void:
	var t := T.new(self, "G01_loop_dusk_pct")
	var base := "res://scripts/tests/cards/G01/fixtures"
	var root: String = t.user_dir() + "/loop_dusk"
	H.copy_tree(base + "/good", root)
	var loop: Dictionary = CardDB.read_json(root + "/rules/loop.json")
	t.ok(loop.has("dusk_pct") and int(loop["dusk_pct"]) == 60, "fixture registers dusk_pct 60")
	loop.erase("dusk_pct")
	H.write(root + "/rules/loop.json", loop)
	var missing: PackedStringArray = CardValidator.validate(root, &"default")["errors"]
	t.ok(not missing.is_empty(), "missing dusk_pct is rejected")
	var named := false
	var only_v25 := true
	for row in missing:
		named = named or row.contains("dusk_pct")
		only_v25 = only_v25 and row.contains(" V25 ")
	t.ok(named, "V25 names missing dusk_pct")
	t.ok(only_v25, "missing dusk_pct reports only V25")
	loop["dusk_pct"] = 60
	H.write(root + "/rules/loop.json", loop)
	for mode in [&"default", &"strict", &"ship"]:
		var present: PackedStringArray = CardValidator.validate(root, mode)["errors"]
		t.eq(present, PackedStringArray(), "loop.dusk_pct present " + str(mode))
	t.ok(CardValidator.RULE_KEYS["loop"].has("dusk_pct"), "RULE_KEYS lists loop.dusk_pct")
	t.finish()
