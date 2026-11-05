# 安装 G06 家当、短缺、街头与牢房；登记修正项和生命周期钩子。
# G06；合同 1.2 §7.3、§7.4、§5.2、§5.3。
class_name CardLadderInstall
extends RefCounted

const OWNER := "G06"


static func install(engine: CardEngine, ctx: CardCtx) -> void:
	for cmd in [&"estate.mortgage", &"estate.redeem", &"short.resolve", &"street.redeem_shop"]:
		engine.register_command(cmd, _command.bind(cmd), OWNER)
	engine.register_query(&"estates", _estates, OWNER)
	engine.register_query(&"short", _short, OWNER)
	for op in [&"arrest", &"estate_seize"]:
		ctx.ops.register(op, _effect.bind(op), CardDslShapes.shape(op), OWNER)
	ctx.conds.register(&"estate_status", _estate_status, CardDslShapes.shape(&"estate_status", true), OWNER)
	for kind in [&"cap", &"deal_count", &"intake_blocked", &"pool_pct"]:
		ctx.mods.register(kind, _modifier.bind(kind), OWNER)
	ctx.mods.register(&"view_section", _view_section, OWNER)
	ctx.mods.register(&"card_view_part", CardPrison._card_view_part, OWNER)
	ctx.mods.register(&"end_rows", _end_rows, OWNER)
	ctx.hooks.on(&"stage_start", CardMortgage._stage_start, 15, OWNER)
	ctx.hooks.on(&"month_close", _month_close, 15, OWNER)
	ctx.hooks.on(&"money_short", CardShortLadder.on_short, 5, OWNER)
	ctx.hooks.on(&"day_end", CardShortLadder._day_end, 7, OWNER)
	ctx.hooks.on(&"day_end", CardPrison._day_end, 25, OWNER)
	ctx.hooks.on(&"card_resolved", CardPrison._resolved, 15, OWNER)


static func _command(ctx: CardCtx, args: Dictionary, cmd: StringName) -> Dictionary:
	var phase: String = str(ctx.state.ns("loop").get("phase", ""))
	if cmd == &"short.resolve":
		return CardShortLadder.resolve(ctx, args)
	if cmd == &"street.redeem_shop":
		if phase != "day":
			return {"ok": false, "err": CardIds.ERR_BAD_PHASE}
		return CardStreet.redeem_shop(ctx)
	if not phase in ["morning", "day"]:
		return {"ok": false, "err": CardIds.ERR_BAD_PHASE}
	if str(args.get("estate", "")) == "":
		return {"ok": false, "err": CardIds.ERR_BAD_ARGS}
	return CardMortgage.mortgage(ctx, str(args["estate"])) if cmd == &"estate.mortgage" \
		else CardMortgage.redeem(ctx, str(args["estate"]))


static func _estates(ctx: CardCtx, _args: Dictionary) -> Dictionary:
	return {"estates": CardMortgage.view(ctx)}


static func _short(ctx: CardCtx, _args: Dictionary) -> Dictionary:
	return CardShortLadder.view(ctx)


static func _effect(ctx: CardCtx, eff: Dictionary, _source: String, op: StringName) -> void:
	if op == &"arrest":
		CardPrison.arrest(ctx, str(eff.get("reason", "")))
	else:
		CardMortgage._seize(ctx, str(eff.get("pick", "worst")))


static func _estate_status(ctx: CardCtx, value: Variant) -> bool:
	return typeof(value) == TYPE_ARRAY and value.size() == 2 \
		and str(CardMortgage._entry(ctx, str(value[0])).get("status", "")) == str(value[1])


static func _month_close(ctx: CardCtx, _args: Dictionary) -> void:
	CardMortgage.on_month_close(ctx)


static func _view_section(ctx: CardCtx, _args: Dictionary) -> Dictionary:
	return {"estates": CardMortgage.view(ctx)}


static func _end_rows(ctx: CardCtx, _args: Dictionary) -> Array:
	var rows: Array = []
	if str(ctx.state.ns("loop").get("phase", "")) == "day":
		var prison: Dictionary = CardPrison.end_row(ctx)
		if not prison.is_empty():
			rows.append(prison)
	if not CardShortLadder.view(ctx).is_empty():
		rows.append({"uid": "", "def": "", "kind": "short", "consequence_key": "g06.end.short", "args": {}})
	return rows


static func _modifier(ctx: CardCtx, args: Dictionary, kind: StringName) -> Variant:
	var total: int = 100 if kind == &"pool_pct" else 0
	if kind == &"deal_count" and str(args.get("type", "")) in ["person", "night", "street"] and CardPrison._active(ctx):
		return -100000
	for mod in CardMortgage._modifiers(ctx):
		var name: String = str(mod.get("mod", ""))
		if kind == &"cap" and ((name == "shelf_cap" and str(args.get("zone", "")) == "shelf")
				or (name == "kept_cap" and str(args.get("zone", "")) == "kept")):
			total += int(mod.get("delta", 0))
		elif kind == &"deal_count" and name == "deal_count" and str(mod.get("type", "")) == str(args.get("type", "")):
			total += int(mod.get("delta", 0))
		elif kind == &"intake_blocked" and name == "no_intake_cat" and str(mod.get("cat", "")) == str(args.get("cat", "")):
			return true
		elif kind == &"pool_pct" and name == "pool_weight" and str(mod.get("pool", "")) == str(args.get("pool", "")):
			var tags: Array = mod.get("tags_any", [])
			var matches: bool = tags.is_empty()
			for tag in ctx.db.def(str(args.get("def", ""))).get("tags", []):
				matches = matches or tags.has(tag)
			if matches:
				total = total * int(mod.get("pct", 100)) / 100
	return false if kind == &"intake_blocked" else total
