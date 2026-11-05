# 600 张合成牌的性能记录，测量只在独立 bench 脚本，绝不进入确定性测试清单。
# 主人 G01；合同 §12.4。
extends SceneTree
const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const H = preload("res://scripts/tests/cards/G01/helper.gd")

func _initialize() -> void:
	var t := T.new(self, "G01_bench")
	var root := t.user_dir() + "/cards"
	H.copy_tree("res://scripts/tests/cards/G01/fixtures/good", root)
	var rows: Array = []
	for i in range(470):
		rows.append({"id": "ev.bench.card%03d" % i, "type": "event", "era": ["*"], "weight": 10,
			"tags": ["omen_family"], "brief": "TEST", "_provenance": {"by": "ai", "task": "G01", "date": "2026-10-13"}})
	H.write(root + "/era/common/bench.json", {"_meta": {"owner": "K02", "schema": 1}, "cards": rows})
	var start := Time.get_ticks_usec()
	var db := CardDB.load_all(root)
	var load_us := Time.get_ticks_usec() - start
	start = Time.get_ticks_usec()
	var valid := CardValidator.validate(root, &"default")
	var validate_us := Time.get_ticks_usec() - start
	var c := H.ctx(7, root, false)
	var total_us := 0
	for _i in range(100):
		start = Time.get_ticks_usec()
		CardComposer.project(c, 5)
		total_us += Time.get_ticks_usec() - start
	start = Time.get_ticks_usec()
	CardComposer.compose(c)
	var compose_us := Time.get_ticks_usec() - start
	start = Time.get_ticks_usec()
	var result := CardSave.write(t.user_dir() + "/bench.json", c.state, {})
	var save_us := Time.get_ticks_usec() - start
	var bytes := FileAccess.get_file_as_bytes(t.user_dir() + "/bench.json").size()
	print("G01 BENCH cards=%d load_us=%d validate_us=%d project_mean_us=%d compose_us=%d save_bytes=%d save_us=%d" % [db.all_ids().size(), load_us, validate_us, total_us / 100, compose_us, bytes, save_us])
	t.eq(db.all_ids().size(), 600, "600 card corpus")
	t.eq(valid["errors"], PackedStringArray(), "bench default valid")
	t.ok(result["ok"], "bench save")
	t.finish()
