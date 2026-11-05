# 打烊清单只读组合与 G02 负责的牌离场；其他主人的结算仍由对应钩子执行。
extends RefCounted

const Reports = preload("res://scripts/cards/loop/loop_reports.gd")
const STEPS := {"day": "end_day", "night": "skip_night", "settle": "next_day", "morning": "open_day",
	"month_open": "begin_month", "month_close": "month_next", "year_jump": "year_next"}

static func preview(ctx: CardCtx) -> Dictionary:
	var phase := str(ctx.state.ns("loop").get("phase", ""))
	var items: Array = []
	if phase in STEPS and phase != "day":
		items = ctx.mods.collect(ctx, &"end_rows", {}).filter(func(row: Dictionary) -> bool:
			return str(row.get("kind", "")) == "short")
	if phase == "day":
		items = ctx.mods.collect(ctx, &"end_rows", {})
		_sort(ctx, items)
	elif phase == "night":
		items.append(_row("", "", "skip_night", "g02.end.skip_night"))
	elif phase == "month_open" and month_unspun(ctx):
		items.append(_row("", "", "auto_spin", "g02.end.auto_spin"))
	var needs := items.any(func(row: Dictionary) -> bool:
		return not CardIds.END_NO_CONFIRM_KINDS.has(StringName(str(row["kind"]))))
	return {"step": str(STEPS.get(phase, "")), "needs_confirm": needs, "items": items}

static func month_unspun(ctx: CardCtx) -> bool:
	var fate := ctx.state.ns("fate")
	var completed: Dictionary = fate.get("wheels", {}).get("wh.month:", {}).get("result", {})
	return ctx.db.has("wh.month") and str(fate.get("month_segment", "")) == "" and completed.is_empty()

static func own_rows(ctx: CardCtx, _args: Dictionary) -> Array:
	if str(ctx.state.ns("loop").get("phase", "")) != "day":
		return []
	var rows: Array = []
	for uid in CardPiles.list(ctx, CardIds.ZONE_HAND):
		var d := CardPiles.def_of(ctx, uid)
		var id := str(d.get("id", CardPiles.card(ctx, uid).get("def", "")))
		var type := str(d.get("type", ""))
		if id == "bf.wheel" or type in ["life", "prison", "demand"]:
			continue
		if bool(d.get("gold", false)):
			rows.append(_row(uid, id, "gold_leave", id + "#outcomes.ignored"))
		elif type == "person":
			var key := id + "#outcomes.ignored" if not d.get("effects", {}).get("on_expire", []).is_empty() else "g02.end.leave"
			rows.append(_row(uid, id, "leave", key))
		elif CardViewModel.must_resolve(d):
			var effects: Dictionary = d.get("effects", {})
			var key := id + "#outcomes.ignored" if effects.has("on_expire") else (id + "#outcomes.fail" if d.has("check") else "g02.end.ignore")
			rows.append(_row(uid, id, "ignore", key))
		elif not bool(d.get("keepable", type == "kept")) and int(d.get("expires_days", 0)) <= 0 and int(d.get("due_days", 0)) <= 0:
			rows.append(_row(uid, id, "pass", "g02.end.pass"))
	return rows

static func execute_owned(ctx: CardCtx) -> void:
	for row in own_rows(ctx, {}):
		var uid := str(row["uid"])
		if CardPiles.zone_of(ctx, uid) != CardIds.ZONE_HAND:
			continue
		var d := CardPiles.def_of(ctx, uid)
		var effects: Dictionary = d.get("effects", {})
		match str(row["kind"]):
			"gold_leave":
				CardGoldRule.leave(ctx, uid)
			"leave":
				ctx.emit(&"card_left", [uid, &"left"])
				ctx.run(effects.get("on_expire", []), uid + "/on_expire")
				CardPiles.move(ctx, uid, CardIds.ZONE_DISCARD)
			"ignore", "pass":
				var exp: Array = effects.get("on_expire", [])
				if str(row["kind"]) == "ignore" and not effects.has("on_expire"):
					exp = d.get("check", {}).get("on_fail", [])
				ctx.run(exp, uid + "/end_day")
				ctx.emit(&"card_left", [uid, &"expired"])
				CardPiles.move(ctx, uid, CardIds.ZONE_DISCARD)

static func report_lines(items: Array) -> Array:
	var lines: Array = []
	for row in items:
		if not CardIds.END_NO_CONFIRM_KINDS.has(StringName(str(row["kind"]))):
			lines.append({"key": str(row["consequence_key"]), "args": Reports.integer_args(row["args"])})
	return lines

static func _row(uid: String, id: String, kind: String, key: String) -> Dictionary:
	return {"uid": uid, "def": id, "kind": kind, "consequence_key": key, "args": {}}

static func _sort(ctx: CardCtx, items: Array) -> void:
	var hand := Array(CardPiles.list(ctx, CardIds.ZONE_HAND))
	items.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ka := _sort_key(a, hand)
		var kb := _sort_key(b, hand)
		for i in range(3):
			if ka[i] != kb[i]: return ka[i] < kb[i]
		return str(a["uid"]) < str(b["uid"]))

static func _sort_key(row: Dictionary, hand: Array) -> Array:
	var uid := str(row.get("uid", ""))
	if hand.has(uid): return [0, hand.find(uid), 0]
	if str(row.get("kind", "")) == "wait": return [1, int(row.get("args", {}).get("days", -1)), 0]
	var panel := ["discard", "release", "short"].find(str(row.get("kind", "")))
	return [2, panel if panel >= 0 else 3, 0]
