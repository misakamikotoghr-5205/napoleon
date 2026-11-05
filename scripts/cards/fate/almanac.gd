# 黄历每天按年代与季度挑选，动作去重记录。
# 日结只奖不罚，并防止重复结算同一天奖励。
class_name CardAlmanac
extends RefCounted
const S = preload("res://scripts/cards/fate/fate_support.gd")
const ACTIONS := ["pawn_in", "buy_in", "sell_out", "redeem", "trade", "meet", "travel", "pray", "repair", "rest", "lend", "wed"]

static func start_day(ctx: CardCtx) -> void:
	var season := posmod(int(CardCalendar.today(ctx).get("m", 1)) - 3, 12) / 3
	var rows: Array = []
	for id in ctx.db.pool(&"almanac_day", S.era(ctx)):
		var def := ctx.db.def(id)
		if def.get("season", [0, 1, 2, 3]).has(season) and ctx.test(def.get("conditions", {})):
			rows.append([id, int(def.get("weight", 10))])
	var loop := ctx.state.ns("loop")
	var id := "" if rows.is_empty() else JevRng.weighted_choice(rows, ctx.draw("c.almanac", [int(loop.get("stage", 0)), int(loop.get("stage_day", 0))]))
	ctx.state.ns("fate")["almanac"] = {"id": id, "done": [], "settled": false}
	if id != "":
		CardFirsts.mark(ctx, &"almanac", {})

static func today(ctx: CardCtx) -> Dictionary:
	var almanac: Dictionary = ctx.state.ns("fate").get("almanac", {})
	var id := str(almanac.get("id", ""))
	var def := ctx.db.def(id)
	return {"id": id, "yi": def.get("yi", []).duplicate(), "ji": def.get("ji", []).duplicate(), "done": almanac.get("done", []).duplicate()}

static func note(ctx: CardCtx, actions: Array) -> void:
	var fate := ctx.state.ns("fate")
	var almanac: Dictionary = fate.get("almanac", {"id": "", "done": []})
	var done: Array = almanac.get("done", [])
	for action in actions:
		if ACTIONS.has(str(action)) and not done.has(str(action)):
			done.append(str(action))
	done.sort()
	almanac["done"] = done
	fate["almanac"] = almanac

static func settle(ctx: CardCtx) -> void:
	var almanac: Dictionary = ctx.state.ns("fate").get("almanac", {})
	if bool(almanac.get("settled", false)):
		return
	almanac["settled"] = true
	ctx.state.ns("fate")["almanac"] = almanac
	var view := today(ctx)
	if not S.intersects(view["done"], view["yi"]) or S.intersects(view["done"], view["ji"]):
		return
	ctx.run(ctx.db.def(str(view["id"])).get("reward", []), "almanac:" + str(view["id"]))
	ctx.emit(&"notice", ["g05.notice.almanac", {}])
