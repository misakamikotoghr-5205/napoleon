# 非清单性能基准；墙钟只用于报告，绝不参与游戏状态。
# G06；合同 §12.4。公开门面之外的 project 用独立只读夹具上下文测量。
extends SceneTree
const Fair := preload("res://scripts/cards/sim/policies/fair.gd")
const Refuser := preload("res://scripts/cards/sim/policies/refuser.gd")


func _initialize() -> void:
	var data_root: String = "res://data/cards"
	for arg in OS.get_cmdline_user_args():
		if str(arg).begins_with("--data-root="):
			data_root = str(arg).trim_prefix("--data-root=")
	var started: int = Time.get_ticks_usec()
	var db: CardDB = CardDB.load_all(data_root, {"only_examples": true})
	print("| operation | milliseconds |")
	print("|---|---:|")
	_print_time("load_all", started)
	var projection_ctx: CardCtx = CardCtx.new()
	projection_ctx.db = db
	projection_ctx.state = CardState.create(7, {})
	projection_ctx.state.ns("loop").merge({"stage": 0, "stage_day": 5, "abs_day": 5, "mode": "shop"})
	for op in CardDslShapes.COND_OPS.keys():
		projection_ctx.conds.register(op, _fixture_cond, CardDslShapes.shape(op, true), "G06_bench")
	started = Time.get_ticks_usec()
	CardComposer.project(projection_ctx, 6)
	_print_time("project_fixture", started)
	for stages in [1, 3]:
		var engine: CardEngineApi = CardEngine.new()
		engine.new_game({"seed": 7, "only_examples": true, "data_root": data_root, "save_dir": "user://bench/%s" % stages})
		started = Time.get_ticks_usec()
		var result: Dictionary = CardAutoplay.play(engine, Refuser.new(7), {"stages": stages, "max_steps": 20000})
		_print_time("autoplay_%s_stages_refuser" % stages, started)
		print("BENCH RESULT " + JSON.stringify(result))
	var full_save: FileAccess = FileAccess.open("user://bench/3/suspend.json", FileAccess.READ)
	print("BENCH SAVE_BYTES_3_STAGES %s" % (full_save.get_length() if full_save != null else 0))
	var probe: CardEngineApi = CardEngine.new()
	probe.new_game({"seed": 7, "only_examples": true, "data_root": data_root, "save_dir": "user://bench/probe"})
	probe.send(&"wheel.spin", {"wheel": "wh.month", "uid": ""})
	probe.send(&"month.begin")
	started = Time.get_ticks_usec()
	probe.send(&"day.begin")
	_print_time("day.begin", started)
	probe.send(&"day.end", {"confirm": true})
	var night_action: Array = Fair.new(7).decide(probe, probe.view())
	if not night_action.is_empty():
		probe.send(night_action[0], night_action[1])
	started = Time.get_ticks_usec()
	probe.send(&"settle.next")
	_print_time("settle.next", started)
	probe.save_game("user://bench/size.json")
	var file: FileAccess = FileAccess.open("user://bench/size.json", FileAccess.READ)
	print("BENCH SAVE_BYTES %s" % (file.get_length() if file != null else 0))
	_bench_lot(data_root)
	quit(0)


func _bench_lot(data_root: String) -> void:
	var engine: CardEngineApi = CardEngine.new()
	engine.new_game({"seed": 7, "only_examples": true, "data_root": data_root, "save_dir": "user://bench/lot"})
	var policy: CardPolicy = Fair.new(7)
	for step in range(500):
		var action: Array = policy.decide(engine, engine.view())
		if action.is_empty():
			break
		var started: int = Time.get_ticks_usec()
		var result: Dictionary = engine.send(action[0], action[1])
		if action[0] == &"fortune.lot":
			_print_time("fortune.lot", started)
			print("BENCH LOT_RESULT " + JSON.stringify(result))
			return
	print("BENCH fortune.lot unavailable: no offer reached")


func _print_time(operation: String, started: int) -> void:
	print("| %s | %.3f |" % [operation, (Time.get_ticks_usec() - started) / 1000.0])


func _fixture_cond(_ctx: CardCtx, _value: Variant) -> bool:
	# 原始牌库选择基准；真实生命周期/状态条件的基准由 G05 专用 harness 测。
	return true
