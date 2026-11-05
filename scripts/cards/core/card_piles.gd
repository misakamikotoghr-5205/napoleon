# 牌的区：手牌、留着的、人脉、条子、待办、弃牌；上限、过期、留着、扔掉；手牌排序的唯一写法 order_hand()。
# 主人 G01；W0 写了能用的最小版（留牌满了的溢出流程、过期结算留给 G01）。
# 合同：docs/cards/CARDS_INTERFACES.md §6.1、§7.4.2、§7.9（G01 core）、§10.2。
class_name CardPiles
extends RefCounted


## 新 uid；进手牌后 order_hand()。extra: {vars, item_id, status}
static func spawn(ctx: CardCtx, def_id: String, zone: StringName, extra: Dictionary = {}) -> String:
	if not CardIds.ZONES.has(zone):
		return ""
	if not ctx.db.has(def_id):
		push_error("CardPiles.spawn: unknown def '%s'" % def_id)
		return ""
	var core := ctx.state.ns("core")
	var uid := ctx.state.new_uid()
	core["deal_seq"] = int(core.get("deal_seq", 0)) + 1
	var d := ctx.db.def(def_id)
	var exp_days := int(d.get("expires_days", 0))
	var expires := zone == CardIds.ZONE_KEPT or (zone == CardIds.ZONE_HAND and _hand_keepable(d))
	var card := {"uid": uid, "def": def_id, "zone": str(zone), "seq": int(core["deal_seq"]),
		"dealt_abs_day": ctx.abs_day(),
		"expires_abs_day": ctx.abs_day() + exp_days if expires and exp_days > 0 else -1,
		"status": str(extra.get("status", "open")), "placed": {}, "choice": "", "item_id": str(extra.get("item_id", "")),
		"vars": (extra.get("vars", {}) as Dictionary).duplicate(true)}
	(core["cards"] as Dictionary)[uid] = card
	_zone_list(ctx, zone).append(uid)
	if str(d.get("type", "")) == "life":
		card["vars"]["due_abs_day"] = ctx.abs_day() + maxi(1, int(d.get("due_days", 1))) - 1
	if zone == CardIds.ZONE_HAND:
		order_hand(ctx)
		_mark_hand_firsts(ctx, uid)
	elif zone == CardIds.ZONE_KEPT:
		CardFirsts.mark(ctx, &"keep", {"uid": uid, "def": def_id})
	return uid


## 错误码，"" 成功
static func move(ctx: CardCtx, uid: String, zone: StringName) -> String:
	var card := _card_ref(ctx, uid)
	if card.is_empty():
		return CardIds.ERR_UNKNOWN_UID
	_zone_list(ctx, StringName(str(card["zone"]))).erase(uid)
	_zone_list(ctx, zone).append(uid)
	card["zone"] = str(zone)
	if zone == CardIds.ZONE_HAND:
		order_hand(ctx)
		_mark_hand_firsts(ctx, uid)
	return ""


static func zone_of(ctx: CardCtx, uid: String) -> StringName:
	return StringName(str(_card_ref(ctx, uid).get("zone", "")))


static func list(ctx: CardCtx, zone: StringName) -> PackedStringArray:
	return PackedStringArray(_zone_list(ctx, zone))


static func card(ctx: CardCtx, uid: String) -> Dictionary:
	return _card_ref(ctx, uid).duplicate(true)


static func def_of(ctx: CardCtx, uid: String) -> Dictionary:
	var c := _card_ref(ctx, uid)
	return ctx.db._cards.get(str(c["def"]), {}) if not c.is_empty() and ctx.db != null else {}


## card.keep：错误码，"" 成功
static func keep(ctx: CardCtx, uid: String) -> String:
	var c := _card_ref(ctx, uid)
	if c.is_empty():
		return CardIds.ERR_UNKNOWN_UID
	if not [CardIds.ZONE_HAND, CardIds.ZONE_PENDING].has(zone_of(ctx, uid)):
		return CardIds.ERR_BAD_ARGS
	var d := def_of(ctx, uid)
	var keepable := str(d.get("type", "")) == "kept" or bool(d.get("keepable", false))
	if bool(d.get("gold", false)) or not keepable:
		return CardIds.ERR_NOT_KEEPABLE
	var cap_n := cap(ctx, CardIds.ZONE_KEPT)
	if cap_n >= 0 and _zone_list(ctx, CardIds.ZONE_KEPT).size() >= cap_n:
		_move_to_overflow(ctx, uid)
		return CardIds.ERR_KEPT_FULL
	_promote_to_kept(ctx, uid)
	return ""


## 处理完：进弃牌、发 card_left、触发 card_resolved（extra.almanac 原样带上）、执行 on_resolve
static func resolve(ctx: CardCtx, uid: String, outcome: StringName, extra: Dictionary = {}) -> void:
	var c := _card_ref(ctx, uid)
	if c.is_empty() or zone_of(ctx, uid) == CardIds.ZONE_DISCARD:
		return
	move(ctx, uid, CardIds.ZONE_DISCARD)
	c["status"] = "resolved"
	var reason: StringName = outcome if CardIds.CARD_LEFT_REASONS.has(outcome) else &"resolved"
	ctx.emit(&"card_left", [uid, reason])
	ctx.hooks.fire(ctx, CardIds.HOOK_CARD_RESOLVED, {"uid": uid, "outcome": outcome,
		"almanac": extra.get("almanac", [])})
	ctx.run(def_of(ctx, uid).get("effects", {}).get("on_resolve", []), uid + "/on_resolve")


## 手牌排序的唯一写法：按 (deal.json.hand_order 的先后, 修正项 hand_sub, seq)；每次往手牌里加牌后调（§10.2）
static func order_hand(ctx: CardCtx) -> void:
	var order: Array = ctx.rules("deal").get("hand_order", [])
	var hand := _zone_list(ctx, CardIds.ZONE_HAND)
	var keyed: Array = []
	for uid in hand:
		var d := def_of(ctx, uid)
		var rank := order.find("gold") if bool(d.get("gold", false)) else order.find(str(d.get("type", "")))
		if rank < 0:
			rank = order.size()
		var sub := ctx.mods.sum_int(ctx, &"hand_sub", {"uid": uid})
		keyed.append([rank, sub, int(_card_ref(ctx, uid).get("seq", 0)), uid])
	keyed.sort_custom(func(a: Array, b: Array) -> bool:
		for i in range(3):
			if int(a[i]) != int(b[i]):
				return int(a[i]) < int(b[i])
		return false)
	hand.clear()
	for row in keyed:
		hand.append(row[3])


## card.discard：扔掉，不执行 on_expire；错误码，"" 成功
static func discard(ctx: CardCtx, uid: String) -> String:
	var c := _card_ref(ctx, uid)
	if c.is_empty():
		return CardIds.ERR_UNKNOWN_UID
	if zone_of(ctx, uid) == CardIds.ZONE_DISCARD:
		return "already_resolved"
	move(ctx, uid, CardIds.ZONE_DISCARD)
	c["status"] = "discarded"
	ctx.emit(&"card_left", [uid, &"resolved"])
	_promote_overflow_if_room(ctx)
	return ""


## 执行 on_expire、移走
static func expire(ctx: CardCtx, uid: String) -> void:
	var c := _card_ref(ctx, uid)
	if c.is_empty() or zone_of(ctx, uid) == CardIds.ZONE_DISCARD:
		return
	ctx.run(def_of(ctx, uid).get("effects", {}).get("on_expire", []), uid + "/on_expire")
	move(ctx, uid, CardIds.ZONE_DISCARD)
	c["status"] = "expired"
	ctx.emit(&"card_left", [uid, &"expired"])


## 区的上限：deal.json.caps + 修正项 cap；没有上限返回 -1
static func cap(ctx: CardCtx, zone: StringName) -> int:
	var caps: Dictionary = ctx.rules("deal").get("caps", {})
	var key := "hand_soft" if zone == CardIds.ZONE_HAND else str(zone)
	if not caps.has(key):
		return -1
	return maxi(0, int(caps[key]) + ctx.mods.sum_int(ctx, &"cap", {"zone": zone}))


## 有没处理的留牌溢出；按 pending 的确定顺序取第一张。
static func overflow_uid(ctx: CardCtx) -> String:
	for uid in _zone_list(ctx, CardIds.ZONE_PENDING):
		if str(_card_ref(ctx, uid).get("status", "")) == "overflow":
			return str(uid)
	return ""


static func _move_to_overflow(ctx: CardCtx, uid: String) -> void:
	var c := _card_ref(ctx, uid)
	move(ctx, uid, CardIds.ZONE_PENDING)
	c["status"] = "overflow"
	c["expires_abs_day"] = -1
	CardFirsts.mark(ctx, &"kept_full", {"uid": uid, "def": str(c.get("def", ""))})
	CardDayLoop.request_panel(ctx, &"kept_full", {"new_uid": uid})


static func _promote_to_kept(ctx: CardCtx, uid: String) -> void:
	var c := _card_ref(ctx, uid)
	var d := def_of(ctx, uid)
	move(ctx, uid, CardIds.ZONE_KEPT)
	c["status"] = "open"
	var exp_days := int(d.get("expires_days", 0))
	c["expires_abs_day"] = ctx.abs_day() + exp_days if exp_days > 0 else -1
	CardFirsts.mark(ctx, &"keep", {"uid": uid, "def": str(c["def"])})
	ctx.run(d.get("effects", {}).get("on_keep", []), uid + "/on_keep")


static func _promote_overflow_if_room(ctx: CardCtx) -> void:
	var cap_n := cap(ctx, CardIds.ZONE_KEPT)
	if cap_n >= 0 and _zone_list(ctx, CardIds.ZONE_KEPT).size() >= cap_n:
		return
	var uid := overflow_uid(ctx)
	if uid != "":
		_promote_to_kept(ctx, uid)


# ---------------- 内部 ----------------
static func _card_ref(ctx: CardCtx, uid: String) -> Dictionary:
	var cards: Dictionary = ctx.state.ns("core").get("cards", {})
	return cards.get(uid, {})


static func _zone_list(ctx: CardCtx, zone: StringName) -> Array:
	var core := ctx.state.ns("core")
	if not core.has("zones"):
		core["zones"] = {}
	var zones: Dictionary = core["zones"]
	if not zones.has(str(zone)):
		zones[str(zone)] = []
	return zones[str(zone)]


# 任一路径进手牌都登记机制；每日发牌由 Composer 先记 deal，保证指引顺序。
static func _mark_hand_firsts(ctx: CardCtx, uid: String) -> void:
	var d := def_of(ctx, uid)
	var args := {"uid": uid, "def": str(d.get("id", ""))}
	var type := str(d.get("type", ""))
	if type in ["person", "life", "news"]:
		CardFirsts.mark(ctx, StringName(type), args)
	if bool(d.get("keepable", false)) or type == "kept":
		CardFirsts.mark(ctx, &"keep", args)


## 打烊只结算到期生活牌；手中能留的牌到 settle 才按发到手上那天倒计时失效。
static func end_day(ctx: CardCtx) -> void:
	for uid in list(ctx, CardIds.ZONE_HAND):
		var c := card(ctx, uid)
		var d := def_of(ctx, uid)
		var type := str(d.get("type", ""))
		if type == "life" and int(c.get("vars", {}).get("due_abs_day", -1)) <= ctx.abs_day():
			expire(ctx, uid)


## 打烊清单纯读取；只交可见整数，执行与对应的 day_end/settle 钩子同用到期日。
static func end_rows(ctx: CardCtx) -> Array:
	if str(ctx.state.ns("loop").get("phase", "")) != "day":
		return []
	var rows: Array = []
	for uid in list(ctx, CardIds.ZONE_PENDING):
		if str(card(ctx, uid).get("status", "")) == "overflow":
			rows.append(_end_row(ctx, uid, "discard", "g01.end.discard", {}))
	for uid in list(ctx, CardIds.ZONE_HAND):
		var c := card(ctx, uid)
		var d := def_of(ctx, uid)
		if str(d.get("type", "")) == "life":
			var days := maxi(0, int(c.get("vars", {}).get("due_abs_day", -1)) - ctx.abs_day())
			var kind := "ignore" if days == 0 else "wait"
			var key := str(c["def"]) + "#outcomes.ignored" if days == 0 else "g01.end.wait"
			rows.append(_end_row(ctx, uid, kind, key, {} if days == 0 else {"days": days}))
		elif _hand_keepable(d):
			var due := _hand_expiry(c, d)
			rows.append(_end_row(ctx, uid, "wait", "g01.end.wait", {"days": maxi(0, due - ctx.abs_day()) if due >= 0 else -1}))
	return rows


static func _end_row(ctx: CardCtx, uid: String, kind: String, key: String, args: Dictionary) -> Dictionary:
	return {"uid": uid, "def": str(card(ctx, uid).get("def", "")), "kind": kind,
		"consequence_key": key, "args": args}


static func _hand_keepable(d: Dictionary) -> bool:
	return (bool(d.get("keepable", false)) or str(d.get("type", "")) == "kept") and not CardViewModel.must_resolve(d) and not bool(d.get("gold", false))


## 老存档的手牌还没有实例期限；仅用原发牌日回算，预览不迁移/写状态。
static func _hand_expiry(c: Dictionary, d: Dictionary) -> int:
	var due := int(c.get("expires_abs_day", -1))
	var days := int(d.get("expires_days", 0))
	return int(c.get("dealt_abs_day", 0)) + days if due < 0 and days > 0 else due


## settle20：留牌及手中可留的牌过期；不触发 on_read/on_resolve，不消费成功被动。
static func settle_kept(ctx: CardCtx) -> void:
	for uid in list(ctx, CardIds.ZONE_KEPT):
		var due := int(card(ctx, uid).get("expires_abs_day", -1))
		if due >= 0 and due <= ctx.abs_day():
			CardFirsts.mark(ctx, &"kept_expire", {"uid": uid, "def": str(card(ctx, uid).get("def", ""))})
			expire(ctx, uid)
	for uid in list(ctx, CardIds.ZONE_HAND):
		var d := def_of(ctx, uid)
		if _hand_keepable(d):
			var due := _hand_expiry(card(ctx, uid), d)
			if due >= 0 and due <= ctx.abs_day():
				expire(ctx, uid)
	_promote_overflow_if_room(ctx)
