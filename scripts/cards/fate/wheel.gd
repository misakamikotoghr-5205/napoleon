# 轮盘按牌 UID 隔离，扇区保持数据库显示顺序。
# 状态只存整数；香案与押牌先完整检查，付钱失败不改变状态。
class_name CardWheel
extends RefCounted
const S = preload("res://scripts/cards/fate/fate_support.gd")
const Slots = preload("res://scripts/cards/rules/slots.gd")

static func view(ctx: CardCtx, wheel_id: String, uid: String) -> Dictionary:
	var err := _access(ctx, wheel_id, uid)
	if err != "":
		return {"ok": false, "err": err}
	var wheel := ctx.db.def(wheel_id)
	var state := _state(ctx, wheel_id, uid)
	var rows := weights(ctx, wheel_id, uid)
	var total := 0
	for row in rows:
		total += int(row[1])
	var segments: Array = []
	for row in rows:
		segments.append({"id": str(row[0]), "arc_deg": 360.0 * int(row[1]) / total,
			"art": str(ctx.db.def(str(row[0])).get("art", ""))})
	var result: Dictionary = state.get("result", {})
	return {"wheel": wheel_id, "uid": uid, "kind": str(wheel.get("kind", "")), "art": str(wheel.get("art", "")),
		"segments": segments, "incense": {"accepts": wheel.get("incense", {}).get("accepts", []),
			"placed": state.get("incense", []).duplicate(true), "full": _units(ctx, wheel, state) >= _setting(ctx, wheel, "max_units")},
		"cost": _cost(ctx, wheel_id, uid), "staked": str(state.get("stake", "")), "spun": not result.is_empty(),
		"result": {"segment": str(result.get("segment", "")), "stop_deg": float(result.get("stop_mdeg", 0)) / 1000.0}}

static func offer(ctx: CardCtx, wheel_id: String, uid: String, source: Dictionary) -> Dictionary:
	var err := _editable(ctx, wheel_id, uid)
	if err != "":
		return {"ok": false, "err": err}
	var wheel := ctx.db.def(wheel_id)
	var state := _state(ctx, wheel_id, uid)
	var kind := str(source.get("kind", ""))
	if not wheel.get("incense", {}).get("accepts", []).has(kind):
		return {"ok": false, "err": "slot_reject"}
	if _units(ctx, wheel, state) >= _setting(ctx, wheel, "max_units"):
		return {"ok": false, "err": "slot_full"}
	var entry := _source(ctx, kind, source)
	if entry.has("err"):
		return {"ok": false, "err": entry["err"]}
	var incense: Array = state.get("incense", [])
	incense.append(entry)
	state["incense"] = incense
	_save(ctx, wheel_id, uid, state)
	CardFirsts.mark(ctx, &"incense", {"uid": uid})
	CardAlmanac.note(ctx, ["pray"])
	return {"ok": true, "err": ""}

static func _source(ctx: CardCtx, kind: String, source: Dictionary) -> Dictionary:
	if kind == "money":
		if typeof(source.get("amount")) != TYPE_INT or int(source["amount"]) <= 0:
			return {"err": "bad_args"}
		if int(source["amount"]) > S.available_money(ctx):
			return {"err": "insufficient_money"}
		return {"kind": kind, "amount": int(source["amount"])}
	var uid := str(source.get("uid", ""))
	var zone := CardIds.ZONE_KEPT if kind == "kept" else CardIds.ZONE_CONTACTS
	if CardPiles.zone_of(ctx, uid) != zone:
		return {"err": "slot_reject"}
	if S.reserved(ctx, uid):
		return {"err": "person_busy" if kind == "contact" else "slot_reject"}
	if kind == "contact" and not S.person_ready(ctx, uid):
		return {"err": "person_busy"}
	return {"kind": kind, "uid": uid}

static func withdraw(ctx: CardCtx, wheel_id: String, uid: String, index: int) -> Dictionary:
	var err := _editable(ctx, wheel_id, uid)
	if err != "":
		return {"ok": false, "err": err}
	var state := _state(ctx, wheel_id, uid)
	var incense: Array = state.get("incense", [])
	if index < 0 or index >= incense.size():
		return {"ok": false, "err": "bad_args"}
	incense.remove_at(index)
	state["incense"] = incense
	_save(ctx, wheel_id, uid, state)
	return {"ok": true, "err": ""}

static func stake(ctx: CardCtx, wheel_id: String, uid: String, kept_uid: String) -> Dictionary:
	var err := _editable(ctx, wheel_id, uid)
	if err != "":
		return {"ok": false, "err": err}
	if not bool(_cost(ctx, wheel_id, uid)["stake"]) or CardPiles.zone_of(ctx, kept_uid) != CardIds.ZONE_KEPT:
		return {"ok": false, "err": "slot_reject"}
	var state := _state(ctx, wheel_id, uid)
	if str(state.get("stake", "")) == kept_uid:
		return {"ok": true, "err": ""}
	if S.reserved(ctx, kept_uid):
		return {"ok": false, "err": "slot_reject"}
	state["stake"] = kept_uid
	_save(ctx, wheel_id, uid, state)
	return {"ok": true, "err": ""}

static func spin(ctx: CardCtx, wheel_id: String, uid: String) -> Dictionary:
	var err := _editable(ctx, wheel_id, uid)
	if err != "":
		return {"ok": false, "err": err}
	var state := _state(ctx, wheel_id, uid)
	var cost := _cost(ctx, wheel_id, uid)
	var preflight := _preflight(ctx, state, cost, wheel_id + ":" + uid)
	if preflight != "":
		return {"ok": false, "err": preflight}
	var rows := weights(ctx, wheel_id, uid)
	if rows.is_empty():
		return {"ok": false, "err": "cond_failed"}
	var u := ctx.draw("c.wheel." + wheel_id, [ctx.abs_day(), uid, int(state.get("spin_no", 0))])
	var segment := JevRng.weighted_choice(rows, u)
	var def := ctx.db.def(segment)
	S.pay(ctx, int(cost["money"]), "g05.reason.wheel", uid)
	_consume(ctx, state, uid)
	state["spin_no"] = int(state.get("spin_no", 0)) + 1
	state["result"] = {"segment": segment, "stop_mdeg": int(floor(u * 360000.0))}
	_save(ctx, wheel_id, uid, state)
	if wheel_id == "wh.month":
		ctx.state.ns("fate")["month_segment"] = segment
		ctx.state.ns("fate")["month_mods"] = def.get("month_mods", []).duplicate(true)
	var stop_deg := 360.0 * u
	ctx.emit(&"wheel_spun", [wheel_id, segment, stop_deg])
	ctx.run(def.get("effects", []), "wheel:" + wheel_id + "/" + uid)
	if str(state.get("stake", "")) != "" and str(def.get("valence", "neutral")) == "bad":
		CardPiles.discard(ctx, str(state["stake"]))
	if uid != "":
		CardPiles.resolve(ctx, uid, &"resolved", {"almanac": CardPiles.def_of(ctx, uid).get("almanac", [])})
	return {"ok": true, "err": "", "segment": segment, "stop_deg": stop_deg}

static func _preflight(ctx: CardCtx, state: Dictionary, cost: Dictionary, wheel_key: String) -> String:
	var kept_uid := str(state.get("stake", ""))
	if bool(cost["stake"]) and (kept_uid == "" or CardPiles.zone_of(ctx, kept_uid) != CardIds.ZONE_KEPT):
		return "stake_required"
	var amount := int(cost["money"])
	for entry in state.get("incense", []):
		match str(entry.get("kind", "")):
			"money":
				amount += int(entry["amount"])
			"kept":
				if CardPiles.zone_of(ctx, str(entry["uid"])) != CardIds.ZONE_KEPT:
					return "slot_reject"
			"contact":
				if CardPiles.zone_of(ctx, str(entry["uid"])) != CardIds.ZONE_CONTACTS or not S.person_ready(ctx, str(entry["uid"])):
					return "person_busy"
	return "insufficient_money" if amount > S.available_money(ctx, wheel_key) else ""

static func _consume(ctx: CardCtx, state: Dictionary, uid: String) -> void:
	for entry in state.get("incense", []):
		if str(entry.get("kind", "")) == "money":
			S.pay(ctx, int(entry["amount"]), "g05.reason.incense", uid)
	for entry in state.get("incense", []):
		match str(entry.get("kind", "")):
			"kept":
				CardPiles.resolve(ctx, str(entry["uid"]), &"resolved")
			"contact":
				var person := str(CardPiles.def_of(ctx, str(entry["uid"])).get("person", ""))
				var slots_script: Script = Slots
				if slots_script.has_method("mark_person_used"):
					slots_script.call("mark_person_used", ctx, person)
				# TODO(G03 mark_person_used): W0 lacks this helper; integration supplies it.

static func weights(ctx: CardCtx, wheel_id: String, uid: String) -> Array:
	var wheel := ctx.db.def(wheel_id)
	var units := _units(ctx, wheel, _state(ctx, wheel_id, uid))
	var ids: Array = Array(ctx.db.ids_of(&"wheel_segment"))
	ids.sort_custom(func(a: String, b: String) -> bool: return ctx.db.order_of(a) < ctx.db.order_of(b))
	var out: Array = []
	for id in ids:
		var def := ctx.db.def(id)
		var eras: Array = def.get("era", [])
		if str(def.get("wheel", "")) != wheel_id or not (eras.has(S.era(ctx)) or (wheel_id == "wh.big" and eras.has("*"))):
			continue
		if not ctx.test(def.get("conditions", {})):
			continue
		var weight := int(def.get("arc", 0)) * (100 + units * _setting(ctx, wheel, "unit_widen_pct") if str(def.get("valence", "")) == "good" else 100)
		if weight > 0:
			out.append([id, weight])
	return out

static func _units(ctx: CardCtx, wheel: Dictionary, state: Dictionary) -> int:
	var units := 0
	var money := 0
	var attr := StringName(str(wheel.get("incense", {}).get("contact_attr", "pull")))
	for entry in state.get("incense", []):
		var uid := str(entry.get("uid", ""))
		var def := CardPiles.def_of(ctx, uid)
		match str(entry.get("kind", "")):
			"money":
				money += int(entry.get("amount", 0))
			"kept":
				units += int(def.get("incense_units", 1))
			"contact":
				units += CardMeters.attr(ctx, str(def.get("person", "")), attr)
	units += money / maxi(1, _setting(ctx, wheel, "money_per_unit"))
	return clampi(units, 0, _setting(ctx, wheel, "max_units"))

static func _setting(ctx: CardCtx, wheel: Dictionary, key: String) -> int:
	return int(wheel.get("incense", {}).get(key, ctx.rules("fortune").get("wheel", {}).get("default_" + key, 1)))

static func _state(ctx: CardCtx, wheel_id: String, uid: String) -> Dictionary:
	return ctx.state.ns("fate").get("wheels", {}).get(wheel_id + ":" + uid,
		{"spin_no": 0, "incense": [], "stake": "", "result": {}}).duplicate(true)

static func _save(ctx: CardCtx, wheel_id: String, uid: String, state: Dictionary) -> void:
	var fate := ctx.state.ns("fate")
	var wheels: Dictionary = fate.get("wheels", {})
	wheels[wheel_id + ":" + uid] = state
	fate["wheels"] = wheels

static func _cost(ctx: CardCtx, wheel_id: String, uid: String) -> Dictionary:
	var cost: Dictionary = ctx.db.def(wheel_id).get("cost", {})
	if uid != "":
		cost = CardPiles.def_of(ctx, uid).get("cost", cost)
		cost = CardPiles.card(ctx, uid).get("vars", {}).get("cost", cost)
	return {"money": maxi(0, int(cost.get("money", 0))), "stake": bool(cost.get("stake", false))}

static func _access(ctx: CardCtx, wheel_id: String, uid: String) -> String:
	if str(ctx.db.def(wheel_id).get("type", "")) != "wheel":
		return "unknown_def"
	if uid == "":
		return "" if wheel_id == "wh.month" else "unknown_uid"
	var card := CardPiles.card(ctx, uid)
	if card.is_empty():
		return "unknown_uid"
	var opened := str(card.get("vars", {}).get("wheel", CardPiles.def_of(ctx, uid).get("opens_wheel", "")))
	return "" if opened == wheel_id else "not_allowed"

static func _editable(ctx: CardCtx, wheel_id: String, uid: String) -> String:
	var err := _access(ctx, wheel_id, uid)
	if err != "":
		return err
	if not _state(ctx, wheel_id, uid).get("result", {}).is_empty():
		return "already_resolved"
	if uid != "" and CardPiles.zone_of(ctx, uid) != CardIds.ZONE_HAND:
		return "not_allowed"
	var phase := str(ctx.state.ns("loop").get("phase", "day"))
	return "" if phase in ["day", "month_open"] else "bad_phase"

static func cancel_unspun(ctx: CardCtx) -> void:
	var wheels: Dictionary = ctx.state.ns("fate").get("wheels", {})
	var keys: Array = wheels.keys()
	keys.sort()
	for key in keys:
		var state: Dictionary = wheels[key]
		if not (state.get("result", {}) as Dictionary).is_empty():
			continue
		state["incense"] = []
		state["stake"] = ""
