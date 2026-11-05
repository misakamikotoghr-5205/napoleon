# 日历：真实公历日期、星期、集市日（只按 stages.json 的 market_every / market_offset 算，不抽签）、钟点。
# 主人 G02；W0 写了能用的整数日期算法。合同：docs/cards/CARDS_INTERFACES.md §4.6（stages.json）、§7.9（G02 loop）。
class_name CardCalendar
extends RefCounted


## {y, m, d, weekday(0 周一 … 6 周日), stage_day, abs_day, minute}
static func today(ctx: CardCtx) -> Dictionary:
	var loop := ctx.state.ns("loop")
	var out := date_of(ctx, int(loop.get("stage_day", 0)))
	out["abs_day"] = int(loop.get("abs_day", 0))
	out["minute"] = int(loop.get("minute", 480))
	return out


## 本关第 stage_day 天（1 起）的公历日期；第 0 天 = 开月那一刻，按第 1 天算
static func date_of(ctx: CardCtx, stage_day: int) -> Dictionary:
	var st := ctx.db.stage(int(ctx.state.ns("loop").get("stage", 0)))
	var parts := str(st.get("start", "1938-03-01")).split("-")
	var days := days_from_civil(int(parts[0]), int(parts[1]), int(parts[2])) + maxi(stage_day, 1) - 1
	var ymd := civil_from_days(days)
	return {"y": ymd[0], "m": ymd[1], "d": ymd[2], "weekday": posmod(days + 3, 7), "stage_day": stage_day}


static func is_market_day(ctx: CardCtx, stage_day: int) -> bool:
	var st := ctx.db.stage(int(ctx.state.ns("loop").get("stage", 0)))
	var every := int(st.get("market_every", 0))
	if every <= 0 or stage_day <= 0:
		return false
	return posmod(stage_day - 1 - int(st.get("market_offset", 0)), every) == 0


## 本关第几周（0 起；按星期一分周）
static func week_of(ctx: CardCtx, stage_day: int) -> int:
	var first_wd := int(date_of(ctx, 1)["weekday"])
	return (maxi(stage_day, 1) - 1 + first_wd) / 7


## 1970-01-01 起的天数（Howard Hinnant 的整数算法；1970-01-01 是星期四 → weekday = (days + 3) mod 7）
static func days_from_civil(y: int, m: int, d: int) -> int:
	var yy := y - 1 if m <= 2 else y
	var era := (yy if yy >= 0 else yy - 399) / 400
	var yoe := yy - era * 400
	var mp := m + 9 if m <= 2 else m - 3
	var doy := (153 * mp + 2) / 5 + d - 1
	var doe := yoe * 365 + yoe / 4 - yoe / 100 + doy
	return era * 146097 + doe - 719468


static func civil_from_days(z: int) -> Array:
	z += 719468
	var era := (z if z >= 0 else z - 146096) / 146097
	var doe := z - era * 146097
	var yoe := (doe - doe / 1460 + doe / 36524 - doe / 146096) / 365
	var y := yoe + era * 400
	var doy := doe - (365 * yoe + yoe / 4 - yoe / 100)
	var mp := (5 * doy + 2) / 153
	var d := doy - (153 * mp + 2) / 5 + 1
	var m := mp + 3 if mp < 10 else mp - 9
	return [y + 1 if m <= 2 else y, m, d]
