# 条子界面的可见文字拼法：天数、档位、类别都走 CardText。没有 class_name。
# 主人 C05。合同：docs/cards/CARDS_INTERFACES.md §3.3 C05、§4.5、§11.2。
extends RefCounted


## 开发版正文还没写进 {n} 时，只显示引擎给的天数；人写的句子里带上这个数以后用整句。
static func days_line(n: int) -> String:
	if n < 0:
		return ""
	var line := CardText.ui("c05.days", {"n": n})
	if line.find(str(n)) >= 0:
		return line
	return str(n)


## 按现在的办法要交的钱（CardView.amount）；0 或没有就不显示。正文没写进 {n} 时只显示这个数。
static func amount_line(n: int) -> String:
	if n <= 0:
		return ""
	var line := CardText.ui("c05.amount", {"n": n})
	if line.find(str(n)) >= 0:
		return line
	return str(n)


static func tier_line(tier: int) -> String:
	return CardText.ui("c05.tier.%d" % tier)


static func kind_line(kind: String) -> String:
	return CardText.ui("c05.kind." + kind)


## 到期前一天（含当天）用 danger。没有期限（-1）不变色。
static func days_danger(n: int) -> bool:
	return n >= 0 and n <= 1
