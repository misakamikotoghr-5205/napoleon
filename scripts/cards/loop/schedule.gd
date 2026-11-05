# 日程只读，未来日用独立状态投影时间条件；窗口选首个满足日，每周生活牌避开脚本日。
# G02：随机仅使用 c.sched.life.*，已发脚本牌记录在 loop.sched_done。
class_name CardSchedule
extends RefCounted

static func due(ctx: CardCtx, abs_day: int) -> PackedStringArray:
	var loop := ctx.state.ns("loop")
	var stage_day := int(loop.get("stage_day", 0)) + abs_day - ctx.abs_day()
	var stage := int(loop.get("stage", 0))
	var st := ctx.db.stage(stage)
	if abs_day < ctx.abs_day() or stage_day < 1 or stage_day > int(st.get("days", 30)):
		return PackedStringArray()
	var era := str(st.get("era", ""))
	var rows: Array = []
	var projected := _project(ctx, stage_day, abs_day)
	var done: Dictionary = loop.get("sched_done", {})
	for type in CardIds.DEALT_TYPES:
		for id in ctx.db.ids_of(type):
			var d := ctx.db.def(id)
			var sch = d.get("schedule")
			if typeof(sch) != TYPE_DICTIONARY or not _era_matches(d, era):
				continue
			if bool(sch.get("once", true)) and done.has(id):
				continue
			if _matches(ctx, projected, sch, stage_day, abs_day):
				rows.append([int(sch.get("order", 0)), id])
	rows.append_array(_life(ctx, projected, stage_day, era))
	rows.sort_custom(func(a: Array, b: Array) -> bool:
		return int(a[0]) < int(b[0]) if int(a[0]) != int(b[0]) else str(a[1]) < str(b[1]))
	var out := PackedStringArray()
	for row in rows:
		out.append(str(row[1]))
	return out

static func _matches(ctx: CardCtx, projected: CardCtx, sch: Dictionary, day: int, abs_day: int) -> bool:
	var sd = sch.get("stage_day")
	if typeof(sd) == TYPE_INT:
		return int(sd) == day and projected.test(sch.get("when", {}))
	if typeof(sd) == TYPE_ARRAY:
		if sd.size() != 2 or day < int(sd[0]) or day > int(sd[1]):
			return false
		# Past days are already represented by sched_done; don't re-evaluate past mutable conditions.
		var first := maxi(int(sd[0]), _first_available(ctx))
		for candidate in range(first, day + 1):
			var c := _project(ctx, candidate, abs_day - day + candidate)
			if c.test(sch.get("when", {})):
				return candidate == day
		return false
	if not sch.has("when"):
		return false
	if not bool(sch.get("once", true)):
		return projected.test(sch["when"])
	var first := _first_available(ctx)
	for candidate in range(first, day + 1):
		if _project(ctx, candidate, abs_day - day + candidate).test(sch["when"]):
			return candidate == day
	return false

static func _life(ctx: CardCtx, projected: CardCtx, day: int, era: String) -> Array:
	var loop := ctx.state.ns("loop")
	var stage := int(loop.get("stage", 0))
	var week := CardCalendar.week_of(ctx, day)
	var days: Array = []
	var scripted: Array = ctx.rules("deal").get("scripted_days", {}).get(str(stage), [])
	for candidate in range(1, int(ctx.db.stage(stage).get("days", 30)) + 1):
		if CardCalendar.week_of(ctx, candidate) == week and not scripted.has(candidate):
			days.append(candidate)
	var range_n: Dictionary = ctx.rules("loop").get("life_per_week", {"min": 1, "max": 2})
	var lo := maxi(0, int(range_n.get("min", 1)))
	var hi := maxi(lo, int(range_n.get("max", 2)))
	var n := mini(days.size(), lo + int(ctx.draw("c.sched.life.n", [stage, week]) * (hi - lo + 1)))
	var out: Array = []
	for k in range(n):
		var index := mini(days.size() - 1, int(ctx.draw("c.sched.life.day", [stage, week, k]) * days.size()))
		var chosen_day := int(days[index])
		days.remove_at(index)
		if chosen_day != day:
			continue
		var rows: Array = []
		for id in ctx.db.pool(&"life", era):
			var d := ctx.db.def(id)
			var seasons: Array = d.get("season", [])
			var season := posmod(int(CardCalendar.date_of(ctx, day)["m"]) - 3, 12) / 3
			if not d.has("schedule") and (seasons.is_empty() or seasons.has(season)) and projected.test(d.get("conditions", {})):
				rows.append([id, int(d.get("weight", 10))])
		if not rows.is_empty():
			out.append([0, JevRng.weighted_choice(rows, ctx.draw("c.sched.life.pick", [stage, week, k]))])
	return out

static func _era_matches(d: Dictionary, era: String) -> bool:
	var eras: Array = d.get("era", [])
	return eras.has("*") or eras.has(era)

static func _project(ctx: CardCtx, stage_day: int, abs_day: int) -> CardCtx:
	var c := CardCtx.new()
	c.db = ctx.db
	c.state = CardState.new()
	c.state.data = ctx.state.data.duplicate()
	c.state.data["loop"] = ctx.state.ns("loop").duplicate(true)
	c.state.ns("loop")["stage_day"] = stage_day
	c.state.ns("loop")["abs_day"] = abs_day
	c.state.ns("loop")["phase"] = "morning"
	c.conds = ctx.conds
	c.ops = ctx.ops
	c.mods = ctx.mods
	c.hooks = ctx.hooks
	c.actions = ctx.actions
	return c


static func _first_available(ctx: CardCtx) -> int:
	var loop := ctx.state.ns("loop")
	var day := maxi(1, int(loop.get("stage_day", 0)))
	if str(loop.get("phase", "")) in ["day", "night", "settle", "month_close", "year_jump", "game_over"]:
		day += 1
	return day
