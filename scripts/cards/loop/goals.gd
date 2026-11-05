# 本关目标按确定域挑选，完成与失败效果仅触发一次，月底评语按完成数量分档。
# G02：目标视图只有 id、main、status，隐藏条件与权重不输出。
class_name CardGoals
extends RefCounted

static func pick(ctx: CardCtx) -> void:
	var loop := ctx.state.ns("loop")
	var stage := int(loop.get("stage", 0))
	var st := ctx.db.stage(stage)
	var era := str(st.get("era", ""))
	var main := str(st.get("intro", {}).get("main_goal", ""))
	var out: Array = []
	if ctx.db.has(main):
		out.append({"id": main, "main": true, "status": "open"})
	var rows: Array = []
	for id in ctx.db.pool(&"goal", era):
		var d := ctx.db.def(id)
		if not bool(d.get("main", false)) and id != main:
			rows.append([id, int(d.get("weight", 10))])
	for k in range(int(ctx.rules("goals_rules").get("optional_count", 2))):
		if rows.is_empty():
			break
		var id := JevRng.weighted_choice(rows, ctx.draw("c.goal.pick", [stage, k]))
		out.append({"id": id, "main": false, "status": "open"})
		for i in range(rows.size()):
			if str(rows[i][0]) == id:
				rows.remove_at(i)
				break
	loop["goals"] = out

static func evaluate(ctx: CardCtx, when: StringName) -> void:
	for row in (ctx.state.ns("loop").get("goals", []) as Array).duplicate():
		if str(row.get("status", "open")) != "open":
			continue
		var id := str(row["id"])
		var d := ctx.db.def(id)
		var eval_when := str(d.get("eval", "month_close"))
		if eval_when != str(when) and not (when == &"month_close" and eval_when == "any_time"):
			continue
		if ctx.test(d.get("done_when", {})):
			set_status(ctx, id, "done")
		elif when == &"month_close":
			set_status(ctx, id, "failed")

static func set_status(ctx: CardCtx, id: String, status: String) -> void:
	if not ["done", "failed"].has(status):
		return
	for row in ctx.state.ns("loop").get("goals", []):
		if str(row.get("id", "")) != id or str(row.get("status", "open")) != "open":
			continue
		row["status"] = status
		ctx.run(ctx.db.def(id).get("effects", {}).get("on_" + status, []), id + "/on_" + status)
		return

static func verdict_key(ctx: CardCtx) -> String:
	var done := 0
	for row in ctx.state.ns("loop").get("goals", []):
		if str(row.get("status", "open")) == "done":
			done += 1
	var tier := 0
	var limits: Array = ctx.rules("goals_rules").get("verdict_done_min", [0, 1, 2, 3])
	for i in range(limits.size()):
		if done >= int(limits[i]):
			tier = i
	return "g02.month.verdict.%d" % tier
