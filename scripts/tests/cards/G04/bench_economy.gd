# G04 非清单性能基准；墙钟只用于测量，绝不写入游戏状态。
# 运行参数和输出均为 ASCII。
extends SceneTree
const S = preload("res://scripts/tests/cards/G04/economy_test_support.gd")
const E = preload("res://scripts/cards/economy/economy_support.gd")
func _initialize() -> void:
	var engine := CardEngine.new()
	engine.ctx = S.ctx()
	var ctx := engine.ctx
	ctx.run([{"op":"money","delta":100000,"reason":"g04.reason.test"}], "bench")
	var times: Dictionary = {}
	for i in range(60):
		var uid := S.spawn(ctx)
		measure(engine, &"counter.open", {"uid":uid}, times)
		var item := str(E.session(ctx,uid)["item"])
		measure(engine, &"mg.request", {"uid":uid,"item":item}, times)
		measure(engine, &"mg.report", {"uid":uid,"item":item,"result":S.result()}, times)
		measure(engine, &"counter.offer", {"uid":uid,"tier":"fair"}, times)
	var start := Time.get_ticks_usec()
	CardTickets.tick(ctx)
	var tick_us := Time.get_ticks_usec() - start
	var out: Dictionary = {"settle_us":tick_us,"tickets":ctx.ledger.contracts.size(),"econ_bytes":JSON.stringify(ctx.state.ns("econ")).to_utf8_buffer().size()}
	for key in times:
		var row: Dictionary = times[key]
		out[key] = {"mean_us":int(row["sum"])/int(row["n"]),"max_us":int(row["max"])}
	print("G04 BENCH " + JSON.stringify(out))
	quit(0)

func measure(engine: CardEngine, command: StringName, args: Dictionary, times: Dictionary) -> void:
	var start := Time.get_ticks_usec()
	var result := engine.send(command,args)
	var elapsed := Time.get_ticks_usec() - start
	if not result.get("ok",false):
		push_error("bench command failed: " + str(command))
	var row: Dictionary = times.get(str(command),{"sum":0,"n":0,"max":0})
	row["sum"] = int(row["sum"]) + elapsed
	row["n"] = int(row["n"]) + 1
	row["max"] = maxi(int(row["max"]),elapsed)
	times[str(command)] = row
