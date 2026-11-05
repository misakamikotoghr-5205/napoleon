# 合同1.2：未转大命运作废，香案和押牌解除预留，不花钱或用掉牌。
# W0 独立上下文与真实模块均通过冻结钩子和修正项运行。
extends SceneTree
const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const F = preload("res://scripts/tests/cards/G05/fixture.gd")
const S = preload("res://scripts/cards/fate/fate_support.gd")

func _initialize() -> void:
	var t := T.new(self, "G05_end_day")
	var db := F.db()
	var ctx := F.ctx(db, 719)
	CardFateTrigger.on_crisis(ctx, &"arrested")
	var uid := CardPiles.list(ctx, CardIds.ZONE_HAND)[0]
	var kept := CardPiles.spawn(ctx, "kp.ma_owes", CardIds.ZONE_KEPT)
	var staked := CardPiles.spawn(ctx, "kp.ma_owes", CardIds.ZONE_KEPT)
	var gamble := F.wheel_uid(ctx, "wh.gamble")
	t.ok(bool(CardWheel.offer(ctx, "wh.big", uid, {"kind": "money", "amount": 10}).get("ok")), "money offered")
	t.ok(bool(CardWheel.offer(ctx, "wh.big", uid, {"kind": "kept", "uid": kept}).get("ok")), "kept offered")
	t.ok(bool(CardWheel.stake(ctx, "wh.gamble", gamble, staked).get("ok")), "stake reserved")
	var money := S.money(ctx)
	var quota: Dictionary = ctx.state.ns("fate")["big"].duplicate(true)
	var hash := ctx.state.hash()
	var rows := ctx.mods.collect(ctx, &"end_rows", {})
	var owned := rows.filter(_owned_row)
	var foreign := rows.filter(func(row: Dictionary) -> bool: return not _owned_row(row))
	t.eq(owned, [{"uid": uid, "def": "bf.wheel", "kind": "void", "consequence_key": "g05.end.void", "args": {}}], "void preview matches owned card exactly once")
	t.eq(rows.filter(func(row: Dictionary) -> bool: return str(row.get("uid", "")) == uid).size(), 1, "owned card has one aggregate row")
	t.eq(ctx.state.hash(), hash, "end preview readonly")
	t.no_leaks(rows, "end rows")
	ctx.out = []
	ctx.hooks.fire(ctx, &"day_end", {})
	t.eq(CardPiles.zone_of(ctx, uid), CardIds.ZONE_DISCARD, "unspun big wheel expired")
	t.ok(ctx.out.any(func(event: Array) -> bool: return event[0] == &"card_left" and event[1] == uid and event[2] == &"expired"), "expired event emitted")
	t.ok(not ctx.out.any(func(event: Array) -> bool: return event[0] == &"wheel_spun"), "void does not spin")
	t.eq(ctx.state.ns("fate")["big"], quota, "consumed crisis quota retained without doubling")
	CardFateTrigger.on_crisis(ctx, &"arrested")
	t.ok(not Array(CardPiles.list(ctx, CardIds.ZONE_HAND)).any(func(card_uid: String) -> bool: return str(CardPiles.def_of(ctx, card_uid).get("id", "")) == "bf.wheel"), "same crisis not reissued")
	t.eq(ctx.state.ns("fate")["big"], quota, "same crisis still used")
	t.eq(S.money(ctx), money, "cancelled incense never paid")
	t.eq(CardPiles.zone_of(ctx, kept), CardIds.ZONE_KEPT, "unused incense kept card returned")
	t.eq(CardPiles.zone_of(ctx, staked), CardIds.ZONE_KEPT, "unspun stake returned")
	t.ok(not S.reserved(ctx, kept) and not S.reserved(ctx, staked), "all wheel resource reservations cleared")
	t.eq(S.reserved_money(ctx), 0, "wheel money reservation released")
	var settled_rows := ctx.mods.collect(ctx, &"end_rows", {})
	t.eq(settled_rows.filter(_owned_row), [], "owned void row gone after settlement")
	t.eq(settled_rows.filter(func(row: Dictionary) -> bool: return not _owned_row(row)), foreign, "isolated G05 settlement preserves foreign rows")
	for event in ctx.out:
		t.no_leaks(event, "end event")
	_month_equivalence(t, db)
	t.eq(t.find_floats(ctx.state.data), PackedStringArray(), "end state integers")
	t.finish()

func _owned_row(row: Dictionary) -> bool:
	return str(row.get("consequence_key", "")).begins_with("g05.")

func _month_equivalence(t, db: CardDB) -> void:
	var direct := F.ctx(db, 887)
	var automatic := F.ctx(db, 887)
	for ctx in [direct, automatic]:
		ctx.state.ns("loop")["phase"] = "month_open"
		CardDayLoop.request_panel(ctx, &"wheel", {"wheel": "wh.month", "uid": "", "required": true})
		CardWheel.offer(ctx, "wh.month", "", {"kind": "money", "amount": 10})
	var user := CardFateInstall._command(direct, {"wheel": "wh.month", "uid": ""}, &"wheel.spin")
	var auto := CardWheel.spin(automatic, "wh.month", "")
	t.ok(bool(user.get("ok")) and bool(auto.get("ok")), "both monthly routes spin")
	t.eq(auto["segment"], user["segment"], "monthly automatic and manual same segment")
	t.eq(auto["stop_deg"], user["stop_deg"], "monthly automatic and manual same needle")
	t.eq(automatic.state.hash(), direct.state.hash(), "monthly automatic and manual same state")
	t.ok(automatic.out.any(func(event: Array) -> bool: return event[0] == &"wheel_spun"), "auto spin emits wheel event")
	t.eq(automatic.state.ns("fate")["month_segment"], auto["segment"], "auto spin records monthly segment")
	t.eq(CardFortune.temporal(direct, direct.abs_day() + 1).state.ns("loop")["phase"], "morning", "future context represents undealt morning")
