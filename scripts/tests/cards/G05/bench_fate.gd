# G05 性能测量只供开发者，不进验收清单，不影响游戏状态。
# 用独立上下文准备工作，计时范围只包含目标函数。
extends SceneTree
const F = preload("res://scripts/tests/cards/G05/fixture.gd")

func _initialize() -> void:
	var db := F.db()
	var total := {"lot": 0, "spin": 0, "rows": 0}
	for seed in range(100):
		var ctx := F.ctx(db, seed)
		var uid := F.fortune_uid(ctx)
		var start := Time.get_ticks_usec()
		CardFortune.draw_lot(ctx, uid)
		total["lot"] += Time.get_ticks_usec() - start
		ctx = F.ctx(db, seed)
		start = Time.get_ticks_usec()
		CardWheel.spin(ctx, "wh.month", "")
		total["spin"] += Time.get_ticks_usec() - start
		start = Time.get_ticks_usec()
		CardWeights.rows(ctx, &"person")
		total["rows"] += Time.get_ticks_usec() - start
	print("G05 BENCH fortune.lot=%.3fms wheel.spin=%.3fms pool_rows=%.3fms (100 examples mean)" % [float(total["lot"]) / 100000.0, float(total["spin"]) / 100000.0, float(total["rows"]) / 100000.0])
	quit(0)
