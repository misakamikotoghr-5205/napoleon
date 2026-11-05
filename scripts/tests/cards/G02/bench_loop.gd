# G02 性能测量：时钟只用于测试输出，不改变引擎状态，不登记进清单。
# 所有存档落入独立测试目录，正常指令、发牌、推进和三关分别计时。
extends SceneTree
const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const H = preload("res://scripts/tests/cards/G02/helpers.gd")
func _initialize() -> void:
	var t := T.new(self, "G02_bench")
	var e := H.engine(t)
	e.register_command(&"bench.noop", func(_c: CardCtx, _a: Dictionary) -> Dictionary:
		return {"ok": true, "err": ""}, "bench")
	var start := Time.get_ticks_usec()
	for _i in range(500): e.send(&"bench.noop")
	var normal := float(Time.get_ticks_usec() - start) / 500000.0
	H.morning(t, e)
	start = Time.get_ticks_usec()
	e.send(&"day.begin")
	var begin := float(Time.get_ticks_usec() - start) / 1000.0
	e.send(&"day.end", {"confirm": true})
	e.send(&"night.choose", {"def": "nt.test.a"})
	start = Time.get_ticks_usec()
	e.send(&"settle.next")
	var next := float(Time.get_ticks_usec() - start) / 1000.0
	var all := H.engine(t)
	start = Time.get_ticks_usec()
	H.play_three(t, all)
	var three := float(Time.get_ticks_usec() - start) / 1000000.0
	print("G02 BENCH send_ms=%.3f day_begin_ms=%.3f settle_next_ms=%.3f stage_s=%.3f three_s=%.3f" % [normal, begin, next, three / 3.0, three])
	t.finish()
