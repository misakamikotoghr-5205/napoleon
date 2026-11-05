# 六个真实模块的固定打烊脚本性能；私有资金与抓捕门槛隔离正常局终。
# 只为测量使用时钟，不登记进清单，不用时间改变任何状态。
extends SceneTree
const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const Scenario = preload("res://scripts/tests/cards/G02/real_scenario.gd")
const H = preload("res://scripts/tests/cards/G02/helpers.gd")
func _initialize() -> void:
	var t := T.new(self, "G02_real_bench")
	var data_root := Scenario.build(t.user_dir() + "/data")
	var rules: Dictionary = CardState.int_restore(CardDB.read_json(data_root + "/rules/economy.json"))
	rules["start_money"] = 100000
	H._write(data_root + "/rules/economy.json", JSON.stringify(rules))
	rules = CardState.int_restore(CardDB.read_json(data_root + "/rules/meters.json"))
	rules["heat"]["arrest_at"] = 1000000
	H._write(data_root + "/rules/meters.json", JSON.stringify(rules))
	var e := CardEngine.new()
	t.ok(bool(e.new_game({"seed": 7, "data_root": data_root, "only_examples": true, "save_dir": t.user_dir()}).get("ok")), "real bench new")
	var normal_start := Time.get_ticks_usec()
	for _i in range(100): e.send(&"card.read", {"uid": "missing"})
	var normal_ms := float(Time.get_ticks_usec() - normal_start) / 100000.0
	var begin_max := 0
	var next_max := 0
	var end_max := 0
	var stage_times: Array = []
	var all_start := Time.get_ticks_usec()
	for stage in range(3):
		var stage_start := Time.get_ticks_usec()
		e.send(&"wheel.spin", {"wheel": "wh.month", "uid": ""})
		e.send(&"month.begin")
		for _day in range(30):
			var start := Time.get_ticks_usec()
			e.send(&"day.begin")
			begin_max = maxi(begin_max, Time.get_ticks_usec() - start)
			start = Time.get_ticks_usec()
			e.send(&"day.end", {"confirm": true})
			end_max = maxi(end_max, Time.get_ticks_usec() - start)
			e.send(&"night.choose", {"def": "nt.tidy"})
			start = Time.get_ticks_usec()
			e.send(&"settle.next")
			next_max = maxi(next_max, Time.get_ticks_usec() - start)
		stage_times.append(float(Time.get_ticks_usec() - stage_start) / 1000000.0)
		e.send(&"month.next")
		if stage < 2: e.send(&"year.next")
	print("G02 REAL BENCH send_ms=%.3f day_begin_max_ms=%.3f settle_next_max_ms=%.3f day_end_max_ms=%.3f stages_s=%s three_s=%.3f" % [normal_ms, float(begin_max) / 1000.0, float(next_max) / 1000.0, float(end_max) / 1000.0, stage_times, float(Time.get_ticks_usec() - all_start) / 1000000.0])
	t.eq(e.view()["phase"], "game_over", "real bench ends")
	t.finish()
