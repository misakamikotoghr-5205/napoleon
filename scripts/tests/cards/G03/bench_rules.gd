# 性能测量不进验收清单，也不影响状态的随机或黄金种子。
# 使用普通 send 路径，逐次设置独立资源和当天日期。
extends SceneTree
const S = preload("res://scripts/tests/cards/G03/test_support.gd")
func _initialize() -> void:
	var e := S.engine()
	var sums := {"slot.place": [], "slot.roll": [], "card.choose": [], "settle": []}
	for i in range(200):
		e.ctx.state.ns("loop")["abs_day"] = i + 1
		var uid := S.event(e.ctx, 0)
		_measure(e, &"slot.place", {"uid": uid, "slot": "man", "source": {"kind": "self"}}, sums["slot.place"])
		_measure(e, &"slot.roll", {"uid": uid}, sums["slot.roll"])
		var choice := S.card(e.ctx, "ev.bench_choice", {"type": "event", "choices": [{"id": "yes", "effects": []}]})
		_measure(e, &"card.choose", {"uid": choice, "choice": "yes"}, sums["card.choose"])
		var start := Time.get_ticks_usec()
		e.ctx.hooks.fire(e.ctx, &"settle", {})
		(sums["settle"] as Array).append(Time.get_ticks_usec() - start)
	for kind in ["slot.place", "slot.roll", "card.choose", "settle"]:
		var values: Array = sums[kind]
		values.sort()
		var total := 0
		for n in values: total += int(n)
		print("BENCH G03 %s mean_us=%d p95_us=%d max_us=%d" % [kind, total / values.size(), values[values.size() * 95 / 100], values.back()])
	quit(0)

func _measure(e: CardEngine, cmd: StringName, args: Dictionary, times: Array) -> void:
	var start := Time.get_ticks_usec()
	e.send(cmd, args)
	times.append(Time.get_ticks_usec() - start)
