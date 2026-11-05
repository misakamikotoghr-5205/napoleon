# 无界面全流程测试：godot --headless -s res://scripts/tests/run_playthrough.gd -- [--until=<checkpoint>] [--policy=fair] [--seed=N] [--ui]
# --ui：实例化 Main 场景，经由界面面板回应（测试界面代码路径）。
# 退出码：0 = 通过；1 = 失败（数据错误、账本不变量、超时、未到达目标）。
extends SceneTree

const Autoplayer = preload("res://scripts/tests/autoplayer.gd")
const Director = preload("res://scripts/core/director.gd")

var until: String = "ending"
var policy: String = "fair"
var seed_v: int = 19380306
var use_ui: bool = false
var say_mode: String = "click"
var director
var ap
var reached: Dictionary = {}
var t0: int = 0
var finished_ok: bool = false
var failed: bool = false

func _init() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--until="):
			until = a.substr(8)
		elif a.begins_with("--policy="):
			policy = a.substr(9)
		elif a.begins_with("--seed="):
			seed_v = int(a.substr(7))
		elif a.begins_with("--plan="):
			policy = "plan:" + a.substr(7)
			var pl: Dictionary = Autoplayer.load_plans().get(a.substr(7), {})
			until = str(pl.get("until", "day1_done"))
		elif a == "--ui":
			use_ui = true
		elif a.begins_with("--say-mode="):
			say_mode = a.substr(11)

func _initialize() -> void:
	t0 = Time.get_ticks_msec()
	var db = DB.get_db()
	if not db.errors.is_empty():
		for e in db.errors:
			printerr("DATA ERROR: ", e)
		_fail("数据加载失败")
		return
	if use_ui:
		var main = load("res://scenes/Main.tscn").instantiate()
		main.autostart = false
		root.add_child(main)
		await process_frame
		director = main.start_game(seed_v)
		ap = Autoplayer.new(director, policy, seed_v)
		ap.ui = main
		main.autoplayer = ap
		main.auto_say_mode = say_mode
	else:
		director = Director.new()
		root.add_child(director)
		director.setup(seed_v)
		ap = Autoplayer.new(director, policy, seed_v)
	director.stop_at = until if until != "ending" else ""
	director.checkpoint.connect(func(n): reached[n] = true; print("CHECKPOINT ", n, "  (", director.world.date_text(), " ", director.world.slot_name(), ")"))
	ap.checkpoint.connect(func(n): reached[n] = true)
	director.finished.connect(_on_finished, CONNECT_DEFERRED)
	director.run()

func _process(_delta: float) -> bool:
	if failed or finished_ok:
		return false
	if Time.get_ticks_msec() - t0 > 240000:
		_fail("超时（240 秒）")
	return false

func _on_finished() -> void:
	var w = director.world
	var errs: Array = ap.errors.duplicate()
	if policy.begins_with("plan:"):
		errs.append_array(ap.check_expectations(w))
	errs.append_array(w.ledger.check_invariants())
	if not reached.has(until):
		errs.append("没有到达目标 checkpoint：" + until)
	print("—— 结果（策略 %s，种子 %d，界面 %s）——" % [policy, seed_v, str(use_ui)])
	print("beats: ", ap.beat_count, "  ", ap.counts)
	print("日期：", w.date_text(), " ", w.slot_name(), "  钱匣 ", w.cash(), "  口碑 ", w.koubei, "  本心 ", w.benxin, "  怀疑 ", w.suspicion, "  陈叔信任 ", w.chen_trust)
	print("库存：", w.ledger.items_at("stock").size(), "  活当：", w.ledger.contracts.size(), "  借据：", w.ledger.debts.size(), "  档案簿：", w.notebook.size())
	var fl := {}
	for k in w.flags:
		if not str(k).begins_with("_"):
			fl[k] = w.flags[k]
	print("标记：", fl)
	for l in w.world_log.slice(maxi(0, w.world_log.size() - 12)):
		print("  ", l)
	if errs.is_empty():
		finished_ok = true
		print("PLAYTHROUGH OK")
		await _cleanup()
		quit(0)
	else:
		for e in errs:
			printerr("FAIL: ", e)
		_fail("%d 个错误" % errs.size())

func _fail(why: String) -> void:
	failed = true
	printerr("PLAYTHROUGH FAILED: ", why)
	await _cleanup()
	quit(1)

func _cleanup() -> void:
	ap = null
	for c in root.get_children():
		c.queue_free()
	director = null
	await process_frame
	await process_frame
	DB.shutdown()
