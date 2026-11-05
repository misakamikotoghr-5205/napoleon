# 被捕发牢房牌；格子判定归 G03，打烊留宿次数由规则配置。
# G06；合同 1.2 §7.4.7、§7.9。
class_name CardPrison
extends RefCounted

const DEFAULT_UNRESOLVED_DAYS := 3


static func arrest(ctx: CardCtx, reason: String) -> void:
	if _active(ctx):
		return
	var uid: String = CardPiles.spawn(ctx, "pr.cell", &"hand")
	if uid == "":
		return
	ctx.state.ns("ladder")["prison"] = {"uid": uid, "nights": 0}
	CardDayLoop.request_panel(ctx, &"prison", {"uid": uid})
	CardFirsts.mark(ctx, &"prison", {"uid": uid})
	ctx.hooks.fire(ctx, &"arrested", {"reason": reason})


static func _active(ctx: CardCtx) -> bool:
	var uid: String = str(ctx.state.ns("ladder").get("prison", {}).get("uid", ""))
	return uid != "" and CardPiles.zone_of(ctx, uid) == &"hand"


static func _day_end(ctx: CardCtx, _args: Dictionary) -> void:
	if not _active(ctx):
		return
	var prison: Dictionary = ctx.state.ns("ladder")["prison"]
	prison["nights"] = _nights(ctx) + 1
	prison.erase("days")
	prison.erase("last_abs_day")
	ctx.run([{"op": "shop_closed", "days": 1}], str(prison["uid"]) + "/stay")
	if int(prison["nights"]) >= _limit(ctx):
		var uid: String = str(prison["uid"])
		ctx.run(ctx.db.def("pr.cell").get("check", {}).get("on_fail", []), uid + "/check/on_fail")


static func _limit(ctx: CardCtx) -> int:
	return maxi(1, int(ctx.rules("ladder").get("prison", {}).get("max_days", DEFAULT_UNRESOLVED_DAYS)))


static func _nights(ctx: CardCtx) -> int:
	var prison: Dictionary = ctx.state.ns("ladder").get("prison", {})
	# 旧版续玩点按已住晚数迁移；新局只写 nights。
	return int(prison.get("nights", prison.get("days", 0)))


static func _card_view_part(ctx: CardCtx, args: Dictionary) -> Dictionary:
	if not _active(ctx) or str(args.get("uid", "")) != str(ctx.state.ns("ladder")["prison"]["uid"]):
		return {}
	return {"days_left": maxi(0, _limit(ctx) - _nights(ctx))}


static func end_row(ctx: CardCtx) -> Dictionary:
	if not _active(ctx):
		return {}
	var nights: int = _nights(ctx) + 1
	var fails: bool = nights >= _limit(ctx)
	return {"uid": str(ctx.state.ns("ladder")["prison"]["uid"]), "def": "pr.cell",
		"kind": "fail" if fails else "stay", "consequence_key": "g06.end.fail" if fails else "g06.end.stay",
		"args": {"nights": nights, "max": _limit(ctx)}}


static func _resolved(ctx: CardCtx, args: Dictionary) -> void:
	var prison: Dictionary = ctx.state.ns("ladder").get("prison", {})
	if str(args.get("uid", "")) == str(prison.get("uid", "")):
		ctx.state.ns("ladder")["prison"] = {}
