# 铜钱：随机域 c.coin，键 [abs_day, uid, attempt, i]；正面概率读 slots.json.head（num/den）。
# 主人 G03；W0 只给了冻结签名和桩（标 TODO(G03) 的地方由主人实现）。合同：docs/cards/CARDS_INTERFACES.md §4.4.2、§6.3、§7.9（G03 rules）。
class_name CardCoins
extends RefCounted



## Array[bool]（W0 写了能用的版本）
static func toss(ctx: CardCtx, uid: String, attempt: int, n: int) -> Array:
	var head: Dictionary = ctx.rules("slots").get("head", {"num": 1, "den": 2})
	var num := int(head.get("num", 1))
	var den := maxi(1, int(head.get("den", 2)))
	var faces: Array = []
	for i in range(n):
		faces.append(ctx.draw("c.coin", [ctx.abs_day(), uid, attempt, i]) * float(den) < float(num))
	return faces
