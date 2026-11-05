# 钉签记录指定未来发牌，禁签限制未来的随机部分。
# 只写 fate；替身选择与名额处理由 G01 composer 完成。
class_name CardPins
extends RefCounted

static func pin(ctx: CardCtx, abs_day: int, def_id: String, _source: String) -> void:
	if abs_day < ctx.abs_day() or not ctx.db.has(def_id):
		return
	var fate := ctx.state.ns("fate")
	var pins: Dictionary = fate.get("pins", {})
	var rows: Array = pins.get(str(abs_day), [])
	if not rows.has(def_id):
		rows.append(def_id)
		rows.sort()
	pins[str(abs_day)] = rows
	fate["pins"] = pins

static func pinned(ctx: CardCtx, abs_day: int) -> PackedStringArray:
	return PackedStringArray(ctx.state.ns("fate").get("pins", {}).get(str(abs_day), []))

static func ban(ctx: CardCtx, abs_day: int, tags: Array, _source: String) -> void:
	if abs_day < ctx.abs_day():
		return
	var fate := ctx.state.ns("fate")
	var bans: Dictionary = fate.get("bans", {})
	var rows: Array = bans.get(str(abs_day), [])
	for tag in tags:
		if str(tag).begins_with("omen_") and not rows.has(str(tag)):
			rows.append(str(tag))
	rows.sort()
	bans[str(abs_day)] = rows
	fate["bans"] = bans

static func banned(ctx: CardCtx, abs_day: int) -> PackedStringArray:
	return PackedStringArray(ctx.state.ns("fate").get("bans", {}).get(str(abs_day), []))

static func clear_past(ctx: CardCtx) -> void:
	var fate := ctx.state.ns("fate")
	for field in ["pins", "bans"]:
		var rows: Dictionary = fate.get(field, {})
		var keys := rows.keys()
		keys.sort()
		for key in keys:
			if int(key) < ctx.abs_day():
				rows.erase(key)
		fate[field] = rows
