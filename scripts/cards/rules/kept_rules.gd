# 留牌的格子加成和持有风险；不把风险或标签交给视图。
# G03 按牌区顺序执行，来源路径包含留牌 uid。
class_name CardKeptRules
extends RefCounted
const H = preload("res://scripts/cards/rules/rules_helpers.gd")

static func bonus(ctx: CardCtx, kept_uid: String, slot: Dictionary) -> Dictionary:
	var result := {"coins": 0, "heads": 0, "auto_pass": false}
	for row in CardPiles.def_of(ctx, kept_uid).get("slot_bonus", []):
		if H.intersects(row.get("slot_tags_any", []), slot.get("tags", [])):
			result["coins"] += int(row.get("coins", 0))
			result["heads"] += int(row.get("heads", 0))
			result["auto_pass"] = bool(result["auto_pass"]) or bool(row.get("auto_pass", false))
	return result

static func run_risk(ctx: CardCtx, tags_any: Array, source: String) -> void:
	var uids := CardPiles.list(ctx, &"kept")
	uids.sort()
	for uid in uids:
		var d := CardPiles.def_of(ctx, uid)
		if H.intersects(d.get("tags", []), tags_any):
			ctx.run(d.get("risk", []), source + "/" + uid + "/risk")
