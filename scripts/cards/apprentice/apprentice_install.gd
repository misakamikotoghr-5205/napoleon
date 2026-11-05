# 收徒：会成长的人脉、隐藏忠心、不在铺时看铺、偷 / 通风 / 接班。
# 主人 K18。无 class_name。合同 1.4（#187）。装在冻结的六段之后。
extends RefCounted

const OWNER := "K18"
const H = preload("res://scripts/cards/rules/rules_helpers.gd")
const AUDIT := "ev.any.apprentice_audit"
const STEAL := "ev.any.apprentice_steal"
const TIP := "ev.any.apprentice_tip"
const SUCCEED := "ev.any.apprentice_succeed"
const ATTRS: Array[String] = ["eye", "tongue", "pull", "nerve"]


static func install(engine: CardEngine, ctx: CardCtx) -> void:
	# engine 只为了和别的 install 签名一致；本模块不登记指令。
	if engine == null:
		return
	ctx.mods.register(&"view_section", _view_section, OWNER)
	ctx.mods.register(&"card_view_part", _card_view_part, OWNER)
	ctx.hooks.on(&"deal_composed", _dealt, 40, OWNER)
	ctx.hooks.on(&"day_start", _day_start, 60, OWNER)
	ctx.hooks.on(&"settle", _settle, 55, OWNER)
	ctx.hooks.on(&"month_close", _month_close, 40, OWNER)
	ctx.hooks.on(&"pre_ending_window", _pre_ending_window, 40, OWNER)
	ctx.hooks.on(&"card_resolved", _close_books, 40, OWNER)
	ctx.hooks.on(&"day_end", _close_books, 45, OWNER)


static func _view_section(ctx: CardCtx, _args: Dictionary) -> Dictionary:
	var peek := H.peek(ctx)
	return {"apprentice_desk": {
		"has": _has_contact(ctx),
		"watching": bool(peek.get("flags", {}).get("apprentice_watching", false)),
		"months": int(peek.get("counters", {}).get("apprentice_months", 0)),
	}}


static func _card_view_part(ctx: CardCtx, args: Dictionary) -> Dictionary:
	var tags: Array = CardPiles.def_of(ctx, str(args.get("uid", ""))).get("tags", [])
	if tags.has("apprentice"):
		return {"apprentice": true}
	return {}


static func _dealt(ctx: CardCtx, args: Dictionary) -> void:
	for uid in args.get("uids", []):
		var d := CardPiles.def_of(ctx, str(uid))
		var tags: Array = d.get("tags", [])
		if str(d.get("type", "")) == "person" and tags.has("apprentice"):
			CardFirsts.mark(ctx, &"apprentice", {
				"uid": str(uid), "def": str(d.get("id", "")), "person": str(d.get("person", "")),
			})


static func _day_start(ctx: CardCtx, _args: Dictionary) -> void:
	_clamp(ctx)
	if not _has_contact(ctx):
		_clear_watch(ctx)
		return
	# 接班在白天发到手上：合法 card.choose 窗口；非末关时靠下关 day_start（months 已达标）。
	_offer_succeed(ctx)
	if _away(ctx):
		_begin_watch(ctx)
		return
	if _flag(ctx, "apprentice_watching"):
		_clear_watch(ctx)
		_spawn_audit(ctx)


static func _settle(ctx: CardCtx, _args: Dictionary) -> void:
	if not _flag(ctx, "apprentice_watching") or not _has_contact(ctx):
		return
	var effects: Array = [{"op": "counter", "key": "apprentice_watch_days", "delta": 1}]
	if _loyalty(ctx) < _rule(ctx, "honest_at", 50):
		effects.append({"op": "counter", "key": "apprentice_skim_pending", "delta": _rule(ctx, "skim_per_day", 6)})
	ctx.run(effects, "k18/settle")
	_clamp(ctx)


static func _month_close(ctx: CardCtx, _args: Dictionary) -> void:
	if not _has_contact(ctx) or not _flag(ctx, "apprentice_taken"):
		return
	# 抵押利息不够时，同一次月底会再 fire month_close。成长只记一次；开窗口每次都重试。
	var stage := int(ctx.state.ns("loop").get("stage", 0))
	var counters: Dictionary = H.state(ctx)["counters"]
	if int(counters.get("apprentice_grown_stage", -1)) != stage:
		counters["apprentice_grown_stage"] = stage
		_grow(ctx)
		ctx.run([{"op": "counter", "key": "apprentice_months", "delta": 1}], "k18/month")
		_clamp(ctx)
		_branches(ctx)
	# 合同门槛达标后：末关无下一关 day_start，打开结局前白天窗口；非末关留给下关 day_start。
	# 短款未清时这里到不了发牌；账务完成、month.next 重入后再试。
	_open_succeed_before_ending(ctx)


static func _close_books(ctx: CardCtx, _args: Dictionary) -> void:
	if not _flag(ctx, "apprentice_audit_open"):
		return
	if _holding(ctx, AUDIT):
		return
	_zero_skim(ctx)
	ctx.run([{"op": "flag", "key": "apprentice_audit_open", "value": false}], "k18/audit")


static func _begin_watch(ctx: CardCtx) -> void:
	if _flag(ctx, "apprentice_watching"):
		return
	ctx.run([
		{"op": "flag", "key": "apprentice_watching", "value": true},
		{"op": "notice", "key": "k18.notice.watching"},
	], "k18/watch")


static func _clear_watch(ctx: CardCtx) -> void:
	if _flag(ctx, "apprentice_watching"):
		ctx.run([{"op": "flag", "key": "apprentice_watching", "value": false}], "k18/watch")


static func _spawn_audit(ctx: CardCtx) -> void:
	if _holding(ctx, AUDIT):
		return
	ctx.run([
		{"op": "add_card", "card": AUDIT, "to": "hand"},
		{"op": "flag", "key": "apprentice_audit_open", "value": true},
	], "k18/audit")


static func _grow(ctx: CardCtx) -> void:
	var n := int(H.peek(ctx).get("counters", {}).get("apprentice_months", 0))
	var attr_name := ATTRS[n % ATTRS.size()]
	if CardMeters.attr(ctx, "tudi", StringName(attr_name)) >= _rule(ctx, "attr_cap", 5):
		return
	ctx.run([{"op": "attr", "who": "tudi", "attr": attr_name, "delta": 1, "days": 0}], "k18/grow")


static func _branches(ctx: CardCtx) -> void:
	var loy := _loyalty(ctx)
	var months := int(H.peek(ctx).get("counters", {}).get("apprentice_months", 0))
	if loy < _rule(ctx, "steal_at", 25):
		_queue_once(ctx, "apprentice_branch_steal", STEAL)
	if loy < _rule(ctx, "tip_at", 12):
		_queue_once(ctx, "apprentice_branch_tip", TIP)
	# 接班改由 _offer_succeed / _open_succeed_before_ending；此处不再于 month_close 塞手牌（非末关）。
	if loy >= _rule(ctx, "succeed_at", 80) and months >= _rule(ctx, "succeed_months", 2):
		pass


static func _queue_once(ctx: CardCtx, flag_key: String, card_id: String) -> void:
	if _flag(ctx, flag_key) or _holding(ctx, card_id):
		return
	ctx.run([
		{"op": "flag", "key": flag_key, "value": true},
		{"op": "add_card", "card": card_id, "to": "queue", "in_days": 1},
	], "k18/queue")


static func _hand_once(ctx: CardCtx, flag_key: String, card_id: String) -> void:
	if _flag(ctx, flag_key) or _holding(ctx, card_id):
		return
	ctx.run([
		{"op": "flag", "key": flag_key, "value": true},
		{"op": "add_card", "card": card_id, "to": "hand"},
	], "k18/hand")


## 白天发接班牌：months 已达 succeed_months 合同门槛；仅 day/morning/month_open 合法窗口。
static func _offer_succeed(ctx: CardCtx) -> void:
	if not _flag(ctx, "apprentice_taken"):
		return
	if str(ctx.state.ns("loop").get("phase", "")) not in ["day", "morning", "month_open"]:
		return
	var loy := _loyalty(ctx)
	var months := int(H.peek(ctx).get("counters", {}).get("apprentice_months", 0))
	var need := _rule(ctx, "succeed_months", 2)
	var at := _rule(ctx, "succeed_at", 80)
	if loy < at:
		return
	# 合同门槛：months 必须达到 succeed_months，不提前一个月。
	if months < need:
		return
	_hand_once(ctx, "apprentice_branch_succeed", SUCCEED)


## 末关 month_close 把 months 推到门槛后没有下一关 day_start：开结局前受控 day 窗口发牌，供合法 card.choose，打烊即结局。
static func _open_succeed_before_ending(ctx: CardCtx) -> void:
	if not _flag(ctx, "apprentice_taken"):
		return
	var loy := _loyalty(ctx)
	var months := int(H.peek(ctx).get("counters", {}).get("apprentice_months", 0))
	if loy < _rule(ctx, "succeed_at", 80):
		return
	if months < _rule(ctx, "succeed_months", 2):
		return
	var stage := int(ctx.state.ns("loop").get("stage", 0))
	if not ctx.db.stage(stage + 1).is_empty():
		# 还有下一关：留给下关 day_start/_offer_succeed，不在 month_close 塞牌。
		return
	if str(ctx.state.ns("loop").get("phase", "")) != "month_close":
		return
	var loop := ctx.state.ns("loop")
	# month_pending 或 short 面板：不开窗口、不发牌。open 会记下重试，等账完再开。
	if bool(loop.get("month_pending", false)) or str(loop.get("open_panel", {}).get("kind", "")) == "short":
		CardDayLoop.open_pre_ending_window(ctx, OWNER)
		return
	if CardDayLoop.open_pre_ending_window(ctx, OWNER):
		_hand_once(ctx, "apprentice_branch_succeed", SUCCEED)


## close_month 在短款结清、pending 重算为 false 之后才真正打开窗口，这里补发一次接班牌。
static func _pre_ending_window(ctx: CardCtx, args: Dictionary) -> void:
	if str(args.get("owner", "")) != OWNER:
		return
	if not _flag(ctx, "apprentice_taken"):
		return
	if _loyalty(ctx) < _rule(ctx, "succeed_at", 80):
		return
	if int(H.peek(ctx).get("counters", {}).get("apprentice_months", 0)) < _rule(ctx, "succeed_months", 2):
		return
	_hand_once(ctx, "apprentice_branch_succeed", SUCCEED)


static func _zero_skim(ctx: CardCtx) -> void:
	var n := int(H.peek(ctx).get("counters", {}).get("apprentice_skim_pending", 0))
	if n > 0:
		# 钱物一次落账；钱不够只扣到 0（money op 自带上限），不挡打烊。
		ctx.run([
			{"op": "money", "delta": -n, "reason": "k18.reason.skim"},
			{"op": "counter", "key": "apprentice_skim_pending", "delta": -n},
		], "k18/skim")
	elif n != 0:
		ctx.run([{"op": "counter", "key": "apprentice_skim_pending", "delta": -n}], "k18/skim")
	_clamp(ctx)


static func _clamp(ctx: CardCtx) -> void:
	# 缺席的键保持缺席，避免普通对局的状态哈希被 0 值写脏。
	var counters: Dictionary = H.peek(ctx).get("counters", {})
	if counters.has("apprentice_loyalty"):
		counters["apprentice_loyalty"] = clampi(int(counters["apprentice_loyalty"]), 0, 100)
	if counters.has("apprentice_skim_pending"):
		counters["apprentice_skim_pending"] = maxi(0, int(counters["apprentice_skim_pending"]))


static func _away(ctx: CardCtx) -> bool:
	if str(ctx.state.ns("loop").get("mode", "shop")) == str(CardIds.MODE_STREET):
		return true
	var uid := str(ctx.state.ns("ladder").get("prison", {}).get("uid", ""))
	return uid != "" and CardPiles.zone_of(ctx, uid) == &"hand"


static func _has_contact(ctx: CardCtx) -> bool:
	return H.contact_uid(ctx, "tudi") != ""


static func _flag(ctx: CardCtx, key: String) -> bool:
	return bool(H.peek(ctx).get("flags", {}).get(key, false))


static func _loyalty(ctx: CardCtx) -> int:
	return int(H.peek(ctx).get("counters", {}).get("apprentice_loyalty", 0))


static func _rule(ctx: CardCtx, key: String, fallback: int) -> int:
	return int(ctx.rules("apprentice").get(key, fallback))


static func _holding(ctx: CardCtx, def_id: String) -> bool:
	if _in_zone(ctx, &"hand", def_id) or _in_zone(ctx, &"pending", def_id):
		return true
	for row in ctx.state.ns("core").get("queue", []):
		if str(row.get("def", "")) == def_id:
			return true
	return false


static func _in_zone(ctx: CardCtx, zone: StringName, def_id: String) -> bool:
	for uid in CardPiles.list(ctx, zone):
		if str(CardPiles.card(ctx, uid).get("def", "")) == def_id:
			return true
	return false
