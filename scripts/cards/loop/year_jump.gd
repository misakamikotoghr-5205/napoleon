# 跨年钩子按合同的 priority 触发；报告收告示，人脉逐 uid 按确定域变化。
# G02：不修改别的命名空间，人脉结果经 effects 执行。
class_name CardYearJump
extends RefCounted

const Reports = preload("res://scripts/cards/loop/loop_reports.gd")

static func run(ctx: CardCtx) -> Dictionary:
	var stage := int(ctx.state.ns("loop").get("stage", 0))
	var current := ctx.db.stage(stage)
	var next := ctx.db.stage(stage + 1)
	if next.is_empty():
		return {"ok": false, "err": CardIds.ERR_BAD_ARGS}
	var start := ctx.out.size()
	ctx.hooks.fire(ctx, CardIds.HOOK_YEAR_JUMP, {"from": str(current.get("era", "")), "to": str(next.get("era", ""))})
	var rows := Reports.notices(ctx, start)
	rows.append({"key": "g02.year.advance", "args": {"from": int(current.get("era", "0")), "to": int(next.get("era", "0"))}})
	# section 只是年报面板（C09）分组用的可见标签，不进规则。
	for row in rows:
		var key := str(row.get("key", ""))
		var section := "other"
		if key.begins_with("g03.") or key == "g02.year.contact": section = "people"
		elif key.begins_with("g04."): section = "ledger"
		elif key.begins_with("g06."): section = "estates"
		elif key == "g02.year.advance": section = "era"
		row["section"] = section
	ctx.state.ns("loop")["reports"]["year"] = {"lines": rows}
	return {"ok": true, "err": ""}

static func contacts(ctx: CardCtx, args: Dictionary) -> void:
	var uids := CardPiles.list(ctx, CardIds.ZONE_CONTACTS)
	uids.sort()
	var stage := int(ctx.state.ns("loop").get("stage", 0))
	for uid in uids:
		var d := CardPiles.def_of(ctx, uid)
		var person := str(d.get("person", ""))
		for change in d.get("year_changes", []):
			if str(change.get("to_era", "")) != str(args.get("to", "")):
				continue
			if ctx.draw("c.year." + person, [stage]) * maxi(1, int(change.get("den", 1))) < int(change.get("num", 0)):
				ctx.run(change.get("effects", []), uid + "/year_changes")
