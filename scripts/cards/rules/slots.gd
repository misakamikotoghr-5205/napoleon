# 放格子先预留资源，掷时才支付；人物与留牌在用后记账。
# 格子视图使用 wants，不泄露牌的标签；所有状态只进 rules。
class_name CardSlots
extends RefCounted
const H = preload("res://scripts/cards/rules/rules_helpers.gd")

static func slots_of(ctx: CardCtx, uid: String) -> Array:
	var d := CardPiles.def_of(ctx, uid)
	if str(d.get("type", "")) == "demand": return CardDemands.slots_for(ctx, uid)
	var ch := CardChoices.definition(ctx, uid, str(H.card_peek(ctx, uid).get("choice", "")))
	if ch.has("check"): return (ch["check"].get("slots", []) as Array).duplicate(true)
	return (d.get("slots", []) as Array).duplicate(true)

static func can_place(ctx: CardCtx, uid: String, slot_id: String, source: Dictionary) -> String:
	var err := H.open_error(ctx, uid)
	if err != "": return err
	if CardPiles.zone_of(ctx, uid) not in [&"hand", &"demands"]: return "not_allowed"
	var slot := _slot(ctx, uid, slot_id)
	if slot.is_empty(): return "bad_args"
	var kind := str(source.get("kind", ""))
	if not (slot.get("accepts", []) as Array).has(kind): return "slot_reject"
	if (H.card_peek(ctx, uid).get("placed", {}).get(slot_id, []) as Array).size() >= int(slot.get("max", 1)): return "slot_full"
	if kind == "money":
		if typeof(source.get("amount")) != TYPE_INT or int(source["amount"]) <= 0: return "bad_args"
		return "" if H.afford(ctx, reserved_money(ctx) + wheel_money(ctx) + int(source["amount"])) else "insufficient_money"
	if kind in ["self", "contact"]:
		if kind == "contact" and CardPiles.zone_of(ctx, str(source.get("uid", ""))) != &"contacts": return "unknown_uid"
		var person := H.person(ctx, source)
		if kind == "self" and source.has("uid") and str(CardPiles.def_of(ctx, str(source["uid"])).get("type", "")) != "self": return "unknown_uid"
		if _wheel_reserved(ctx, str(source.get("uid", ""))): return "person_busy"
		if person == "": return "unknown_uid"
		var row := H.person_peek(ctx, person)
		if str(row.get("state", "ok")) in ["away", "hurt", "jailed", "gone"]: return "person_busy"
		if bool(ctx.rules("slots").get("person_once_per_day", true)) and (int(row.get("used_abs_day", -1)) == ctx.abs_day() or _reserved_person(ctx, person)): return "person_busy"
	elif kind in ["kept", "news"]:
		var source_uid := str(source.get("uid", ""))
		var d := CardPiles.def_of(ctx, source_uid)
		if d.is_empty(): return "unknown_uid"
		if CardPiles.zone_of(ctx, source_uid) not in [&"hand", &"kept"] or source_uid == uid: return "not_allowed"
		if kind == "news" and str(d.get("type", "")) != "news": return "slot_reject"
		if kind == "kept" and str(d.get("type", "")) != "kept" and not bool(d.get("keepable", false)): return "slot_reject"
		if str(CardPiles.def_of(ctx, uid).get("type", "")) == "demand" and kind == "news" and CardPiles.zone_of(ctx, source_uid) != &"kept": return "not_allowed"
		if _reserved_resource(ctx, kind, source_uid) or _wheel_reserved(ctx, source_uid): return "not_allowed"
	elif kind == "item":
		var item_id := str(source.get("item", ""))
		var item := _item(ctx, item_id)
		if item.is_empty(): return "unknown_uid"
		if not _on_shelf(ctx, item_id): return "not_allowed"
		for key in (slot.get("item_match", {}) as Dictionary).keys():
			if str(item.get(key, "")) != str(slot["item_match"][key]): return "slot_reject"
		if _reserved_resource(ctx, kind, item_id): return "not_allowed"
	return ""

static func place(ctx: CardCtx, uid: String, slot_id: String, source: Dictionary) -> Dictionary:
	var err := can_place(ctx, uid, slot_id, source)
	if err != "": return H.error(err)
	var row := _source_view(ctx, uid, _slot(ctx, uid, slot_id), source)
	var placed: Dictionary = H.card_state(ctx, uid)["placed"]
	if not placed.has(slot_id): placed[slot_id] = []
	(placed[slot_id] as Array).append(source.duplicate(true))
	ctx.emit(&"card_updated", [uid])
	CardFirsts.mark(ctx, &"slots", {"uid": uid, "def": str(CardPiles.card(ctx, uid).get("def", ""))})
	CardFirsts.mark(ctx, &"coins", {"uid": uid})
	H.kept_first(ctx)
	return {"ok": true, "err": "", "coins": int(row["coins"])}

static func remove(ctx: CardCtx, uid: String, slot_id: String, index: int) -> Dictionary:
	var err := H.open_error(ctx, uid)
	if err != "": return H.error(err)
	var rows: Array = H.card_peek(ctx, uid).get("placed", {}).get(slot_id, [])
	if index < 0 or index >= rows.size(): return H.error("bad_args")
	rows.remove_at(index)
	ctx.emit(&"card_updated", [uid])
	H.kept_first(ctx)
	return {"ok": true, "err": ""}

static func preview(ctx: CardCtx, uid: String) -> Dictionary:
	var result := {"coins": 0, "auto_heads": 0, "need": int(check_of(ctx, uid).get("need", 0)), "auto_pass": false, "ready": true}
	for slot in slot_views(ctx, uid):
		if bool(slot["required"]) and (slot["placed"] as Array).is_empty(): result["ready"] = false
		for row in slot["placed"]:
			result["coins"] += int(row["coins"])
			result["auto_heads"] += int(row["heads"])
			result["auto_pass"] = bool(result["auto_pass"]) or bool(row["auto_pass"])
	result["coins"] = clampi(int(result["coins"]), 0, int(ctx.rules("slots").get("max_coins", 12)))
	return result

static func roll(ctx: CardCtx, uid: String) -> Dictionary:
	var err := H.open_error(ctx, uid)
	if err != "": return H.error(err)
	if str(CardPiles.def_of(ctx, uid).get("type", "")) == "demand": return H.error("not_allowed")
	var check := check_of(ctx, uid)
	if check.is_empty(): return H.error("not_allowed")
	var result := toss_placed(ctx, uid)
	if not bool(result.get("ok", false)): return result
	var branch := "on_success" if bool(result["success"]) else "on_fail"
	ctx.run(check.get(branch, []), check_source(ctx, uid) + "/" + branch)
	var almanac: Array = CardChoices.definition(ctx, uid, str(H.card_peek(ctx, uid).get("choice", ""))).get("almanac", []).duplicate()
	consume(ctx, uid, almanac)
	CardPiles.resolve(ctx, uid, &"resolved", {"almanac": almanac})
	H.kept_first(ctx)
	return result

static func mark_person_used(ctx: CardCtx, person: String) -> void:
	H.person_row(ctx, person)["used_abs_day"] = ctx.abs_day()

static func check_of(ctx: CardCtx, uid: String) -> Dictionary:
	if str(CardPiles.def_of(ctx, uid).get("type", "")) == "demand": return CardDemands.check_for(ctx, uid)
	var ch := CardChoices.definition(ctx, uid, str(H.card_peek(ctx, uid).get("choice", "")))
	return ch.get("check", CardPiles.def_of(ctx, uid).get("check", {}))

static func check_source(ctx: CardCtx, uid: String) -> String:
	var choice := str(H.card_peek(ctx, uid).get("choice", ""))
	return uid + "/choices/" + choice + "/check" if choice != "" else uid + "/check"

static func slot_views(ctx: CardCtx, uid: String) -> Array:
	var views: Array = []
	for slot in slots_of(ctx, uid):
		var placed: Array = []
		var coins := 0
		for source in H.card_peek(ctx, uid).get("placed", {}).get(str(slot["id"]), []):
			var row := _source_view(ctx, uid, slot, source)
			placed.append(row)
			coins += int(row["coins"])
		views.append({"id": str(slot["id"]), "accepts": slot.get("accepts", []), "attr": str(slot.get("attr", "")), "wants": slot.get("tags", []), "required": bool(slot.get("required", false)), "max": int(slot.get("max", 1)), "placed": placed, "coins": coins})
	return views

static func _source_view(ctx: CardCtx, uid: String, slot: Dictionary, source: Dictionary) -> Dictionary:
	var row := {"kind": str(source.get("kind", "")), "coins": 0, "heads": 0, "auto_pass": false}
	for key in ["uid", "amount", "item"]:
		if source.has(key): row[key] = source[key]
	match str(row["kind"]):
		"self", "contact": row["coins"] = CardMeters.attr(ctx, H.person(ctx, source), StringName(str(slot.get("attr", "nerve"))))
		"money":
			if not bool(slot.get("pay", false)): row["coins"] = int(source.get("amount", 0)) / maxi(1, int(slot.get("money_per_coin", ctx.rules("slots").get("money_per_coin", 10))))
		"item": row["coins"] = int(ctx.rules("slots").get("item_coins", 1))
		"news": row["coins"] = int(ctx.rules("slots").get("news_coins", 1))
		"kept": row.merge(CardKeptRules.bonus(ctx, str(source.get("uid", "")), slot), true)
	row["coins"] = maxi(0, int(row["coins"]) + ctx.mods.sum_int(ctx, &"coins", {"uid": uid, "slot_id": str(slot["id"]), "source": source}))
	return row

static func toss_placed(ctx: CardCtx, uid: String) -> Dictionary:
	var p := preview(ctx, uid)
	if not bool(p["ready"]): return H.error("slot_required")
	if not H.afford(ctx, reserved_money(ctx) + wheel_money(ctx)): return H.error("insufficient_money")
	var amount := placed_money(ctx, uid, false)
	H.pay(ctx, amount, uid + "/slot_money")
	var attempts: Dictionary = H.state(ctx)["attempts"]
	var attempt := int(attempts.get(uid, 0))
	var faces: Array = []
	if not bool(p["auto_pass"]):
		faces = CardCoins.toss(ctx, uid, attempt, int(p["coins"]))
		attempts[uid] = attempt + 1
	var heads := faces.count(true) + int(p["auto_heads"])
	var success := bool(p["auto_pass"]) or heads >= int(p["need"])
	ctx.emit(&"coins_tossed", [uid, faces, int(p["need"]), success])
	return {"ok": true, "err": "", "faces": faces, "heads": heads, "need": int(p["need"]), "success": success}

static func consume(ctx: CardCtx, uid: String, almanac: Array = []) -> void:
	for slot in slots_of(ctx, uid):
		for source in H.card_peek(ctx, uid).get("placed", {}).get(str(slot["id"]), []):
			var kind := str(source.get("kind", ""))
			if kind in ["self", "contact"]:
				mark_person_used(ctx, H.person(ctx, source))
				if kind == "contact" and not almanac.has("meet"): almanac.append("meet")
			elif kind == "kept":
				var source_uid := str(source.get("uid", ""))
				var d := CardPiles.def_of(ctx, source_uid)
				ctx.run(d.get("effects", {}).get("on_play", []), source_uid + "/on_play")
				if bool(d.get("consumed_on_use", false)): CardPiles.resolve(ctx, source_uid, &"consumed")
	H.card_state(ctx, uid)["placed"] = {}

static func placed_money(ctx: CardCtx, uid: String, pay_slots: bool) -> int:
	var total := 0
	for slot in slots_of(ctx, uid):
		if bool(slot.get("pay", false)) != pay_slots: continue
		for source in H.card_peek(ctx, uid).get("placed", {}).get(str(slot["id"]), []):
			if str(source.get("kind", "")) == "money": total += int(source.get("amount", 0))
	return total

static func reserved_money(ctx: CardCtx) -> int:
	var total := 0
	var cards: Dictionary = H.peek(ctx).get("cards", {})
	var uids := Array(CardPiles.list(ctx, &"hand")) + Array(CardPiles.list(ctx, &"demands"))
	uids.sort()
	for uid in uids:
		if cards.has(uid):
			total += placed_money(ctx, str(uid), true) + placed_money(ctx, str(uid), false)
	return total

static func _slot(ctx: CardCtx, uid: String, slot_id: String) -> Dictionary:
	for slot in slots_of(ctx, uid):
		if str(slot.get("id", "")) == slot_id: return slot
	return {}

static func _reserved_person(ctx: CardCtx, person: String) -> bool:
	return _reserved_resource(ctx, "person", person)

static func _reserved_resource(ctx: CardCtx, kind: String, resource: String) -> bool:
	var cards: Dictionary = H.peek(ctx).get("cards", {})
	var uids := Array(CardPiles.list(ctx, &"hand")) + Array(CardPiles.list(ctx, &"demands"))
	uids.sort()
	for uid in uids:
		if not cards.has(uid): continue
		var placed: Dictionary = cards[uid].get("placed", {})
		var slots := placed.keys()
		slots.sort()
		for slot in slots:
			for source in placed[slot]:
				var source_kind := str(source.get("kind", ""))
				if kind == "person" and source_kind in ["self", "contact"] and H.person(ctx, source) == resource: return true
				if source_kind in ["kept", "news"] and kind in ["kept", "news"] and str(source.get("uid", "")) == resource: return true
				if kind == "item" and source_kind == kind and str(source.get("item", "")) == resource: return true
	return false

static func _item(ctx: CardCtx, item_id: String) -> Dictionary:
	return ctx.state.ns("econ").get("items_meta", {}).get(item_id, {})

static func _on_shelf(ctx: CardCtx, item_id: String) -> bool:
	# Read the public serialized ledger location; W1 money tests have no live ledger.
	var row: Dictionary = ctx.state.ns("econ").get("ledger", {}).get("items", {}).get(item_id, {})
	return str(row.get("location", "")) == "stock" or CardShelf.items(ctx).has(item_id)

static func _wheel_reserved(ctx: CardCtx, source_uid: String) -> bool:
	if source_uid == "": return false
	var wheels: Dictionary = ctx.state.ns("fate").get("wheels", {})
	var keys := wheels.keys()
	keys.sort()
	for key in keys:
		var row: Dictionary = wheels[key]
		if not (row.get("result", {}) as Dictionary).is_empty(): continue
		if str(row.get("stake", "")) == source_uid: return true
		for source in row.get("incense", []):
			if str(source.get("uid", "")) == source_uid: return true
	return false

static func wheel_money(ctx: CardCtx) -> int:
	var total := 0
	var wheels: Dictionary = ctx.state.ns("fate").get("wheels", {})
	var keys := wheels.keys()
	keys.sort()
	for key in keys:
		var row: Dictionary = wheels[key]
		if not (row.get("result", {}) as Dictionary).is_empty(): continue
		for source in row.get("incense", []):
			if str(source.get("kind", "")) == "money": total += int(source.get("amount", 0))
	return total

static func return_unrolled(ctx: CardCtx) -> void:
	var cards: Dictionary = H.peek(ctx).get("cards", {})
	var uids := cards.keys()
	uids.sort()
	for uid in uids:
		var placed: Dictionary = cards[uid].get("placed", {})
		if placed.is_empty(): continue
		var active := CardPiles.zone_of(ctx, str(uid)) in [&"hand", &"demands"]
		var slots := placed.keys()
		slots.sort()
		if active:
			for slot in slots:
				for source in placed[slot]:
					if str(source.get("kind", "")) in ["self", "contact"]:
						mark_person_used(ctx, H.person(ctx, source))
		cards[uid]["placed"] = {}
		if active: ctx.emit(&"card_updated", [str(uid)])
