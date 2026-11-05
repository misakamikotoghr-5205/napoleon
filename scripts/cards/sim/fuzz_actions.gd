# Visible-action fuzz selector shared by no-deadlock tests and development simulation.
# G06, contract 1.3: only the public facade is read; night offers accept old strings and new dictionaries.
# Rogue v1 (RG6, docs/cards/rogue/ROGUE_V1.md §4.2): stock.pick from the stocktake query (each item, each held relic as
# the replace, the pass) plus three rejected shapes (no such offer, an item that is not offered, empty arguments).
extends RefCounted


static func select(engine: CardEngineApi, seed_value: int, step: int, view: Dictionary = {}) -> Array:
	var draw: int = int(JevRng.draw(seed_value, "c.ai.fuzz", [seed_value, step, 0]) * 10000)
	if draw < 1500:
		return [&"day.end", {"confirm": draw % 2 == 0}]
	if draw < 2500:
		var bad: Array = invalid_actions()
		return bad[draw % bad.size()]
	var actions: Array = legal_actions(engine, engine.view() if view.is_empty() else view)
	if actions.is_empty():
		return [&"day.end", {"confirm": true}]
	var pick: int = int(JevRng.draw(seed_value, "c.ai.fuzz", [seed_value, step, 1]) * actions.size())
	return actions[mini(pick, actions.size() - 1)]


static func invalid_actions() -> Array:
	return [[&"card.keep", {"uid": "missing.uid"}], [&"card.discard", {"uid": 42}],
		[&"counter.offer", {"uid": "missing.uid", "tier": "unknown"}],
		[&"slot.place", {"uid": "missing.uid", "slot": [], "source": {"kind": "invalid"}}],
		[&"wheel.spin", {"uid": "missing.uid", "wheel": "wh.missing"}],
		[&"fortune.cezi", {"uid": "missing.uid", "char": "missing"}],
		[&"short.resolve", {"source": "wrong", "by": "unknown"}],
		[&"night.choose", {"def": "missing.card"}], [&"year.next", {}],
		[&"estate.redeem", {"estate": "es.missing"}],
		[&"stock.pick", {"offer": "w9.9", "pick": ""}], [&"stock.pick", {"offer": "w0.0", "pick": "rl.nope"}],
		[&"stock.pick", {}]]


static func legal_actions(engine: CardEngineApi, view: Dictionary) -> Array:
	var phase: String = str(view.get("phase", ""))
	var actions: Array = _phase_actions(view)
	if phase == "game_over":
		return actions
	for card in view.get("pending", []):
		actions.append([&"card.discard", {"uid": card.get("uid", "")}])
	if phase in ["day", "morning", "month_open"]:
		for contact in view.get("contacts", []):
			actions.append([&"contact.release", {"uid": contact.get("uid", "")}])
	if phase in ["morning", "day"]:
		for estate in engine.query(&"estates").get("estates", []):
			var status: String = str(estate.get("status", ""))
			if status in ["held", "mortgaged"]:
				var cmd: StringName = &"estate.mortgage" if status == "held" else &"estate.redeem"
				actions.append([cmd, {"estate": estate.get("id", "")}])
	var short_view: Dictionary = engine.query(&"short")
	if not short_view.is_empty():
		actions.append_array(_short_actions(short_view))
	actions.append_array(stock_actions(engine))
	if phase == "month_open":
		actions.append_array(_wheel_actions(engine, view, "", "wh.month"))
	if phase == "day":
		if str(view.get("mode", "")) == "street":
			actions.append([&"street.redeem_shop", {}])
		var cards: Array = view.get("hand", []).duplicate()
		cards.append_array(view.get("demands", []))
		for card in cards:
			actions.append_array(_card_actions(engine, view, card))
	return actions


static func _phase_actions(view: Dictionary) -> Array:
	match str(view.get("phase", "")):
		"month_open": return [[&"month.begin", {}]]
		"morning": return [[&"day.begin", {}]]
		"settle": return [[&"settle.next", {}]]
		"month_close": return [[&"month.next", {}]]
		"year_jump": return [[&"year.next", {}]]
		"game_over": return [[&"game.retry_stage", {}]]
		"night":
			var actions: Array = [[&"night.choose", {"def": ""}]]
			actions.append_array(_night_actions(view))
			return actions
	return []


static func _night_actions(view: Dictionary) -> Array:
	var actions: Array = []
	for offer in view.get("night_offers", []):
		var def_id: String = str(offer.get("def", "")) if typeof(offer) == TYPE_DICTIONARY else str(offer)
		var choices: Array = offer.get("choices", []) if typeof(offer) == TYPE_DICTIONARY else []
		if choices.is_empty():
			actions.append([&"night.choose", {"def": def_id}])
			continue
		for choice in choices:
			var choice_id: String = str(choice.get("id", "")) if typeof(choice) == TYPE_DICTIONARY else str(choice)
			if not choice_id.is_empty():
				actions.append([&"night.choose", {"def": def_id, "choice": choice_id}])
	return actions


## Picks for the newest open offer, straight from the stocktake query: the pass, every item, and for a relic every held
## relic as the replace (a full shelf without a replace is rejected with relic_full, which the fuzz wants too).
## No open offer (or the module is dormant / not implemented yet) gives nothing.
static func stock_actions(engine: CardEngineApi) -> Array:
	var offer: Dictionary = engine.query(&"stocktake", {})
	if not bool(offer.get("ok", false)) or str(offer.get("status", "")) != "open":
		return []
	var offer_id: String = str(offer.get("offer", ""))
	var actions: Array = [[&"stock.pick", {"offer": offer_id, "pick": ""}]]
	for item in offer.get("items", []):
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var pick: Dictionary = {"offer": offer_id, "pick": str(item.get("id", ""))}
		actions.append([&"stock.pick", pick])
		if str(item.get("kind", "")) != "relic":
			continue
		for held in offer.get("held", []):
			if typeof(held) == TYPE_DICTIONARY:
				var swap: Dictionary = pick.duplicate()
				swap["replace"] = str(held.get("id", ""))
				actions.append([&"stock.pick", swap])
	return actions


static func _short_actions(short_view: Dictionary) -> Array:
	var source: String = str(short_view.get("source", ""))
	var actions: Array = [[&"short.resolve", {"source": source, "by": "default"}]]
	for item in short_view.get("goods", []):
		actions.append([&"short.resolve", {"source": source, "by": "goods", "item": item.get("item", "")}])
	for estate in short_view.get("estates", []):
		actions.append([&"short.resolve", {"source": source, "by": "estate", "estate": estate.get("id", "")}])
	return actions


static func _card_actions(engine: CardEngineApi, view: Dictionary, card: Dictionary) -> Array:
	var uid: String = str(card.get("uid", ""))
	var actions: Array = []
	if bool(card.get("keepable", false)):
		actions.append([&"card.keep", {"uid": uid}])
	var panel: String = str(card.get("panel", ""))
	var detail: Dictionary = {}
	if panel == "" or panel == "wheel" or not (panel in ["counter", "fortune", "read"]):
		detail = engine.query(&"card", {"uid": uid})
		detail = detail.get("card", detail)
		if panel == "":
			panel = str(detail.get("panel", ""))
	match panel:
		"counter": actions.append_array(_counter_actions(engine, uid))
		"wheel": actions.append_array(_wheel_actions(engine, view, uid, str(detail.get("wheel", "wh.big"))))
		"fortune":
			actions.append([&"fortune.lot", {"uid": uid}])
			for char_id in engine.query(&"fortune", {"uid": uid}).get("cezi", []):
				actions.append([&"fortune.cezi", {"uid": uid, "char": char_id}])
		"read": actions.append([&"card.read", {"uid": uid}])
		_:
			for choice in detail.get("choices", []):
				if bool(choice.get("enabled", true)):
					actions.append([&"card.choose", {"uid": uid, "choice": choice.get("id", "")}])
			actions.append_array(_slot_actions(engine, view, uid, str(card.get("type", "")) == "demand"))
	return actions


static func _counter_actions(engine: CardEngineApi, uid: String) -> Array:
	var counter: Dictionary = engine.query(&"counter", {"uid": uid})
	if not counter.has("intent"):
		return [[&"counter.open", {"uid": uid}]]
	var actions: Array = [[&"counter.close", {"uid": uid}], [&"counter.refuse", {"uid": uid}]]
	var tiers: Array = counter.get("tiers", {}).keys()
	tiers.sort()
	for tier in tiers:
		actions.append([&"counter.offer", {"uid": uid, "tier": tier}])
	if str(counter.get("last_reply", "")) == "counter":
		for accept in [true, false]:
			actions.append([&"counter.answer", {"uid": uid, "accept": accept}])
	if str(counter.get("intent", "")) == "redeem":
		for mode in ["by_rule", "squeeze"]:
			actions.append([&"counter.redeem", {"uid": uid, "mode": mode}])
	for stock in counter.get("stock", []):
		actions.append([&"counter.pick_stock", {"uid": uid, "item": _item_id(stock)}])
	if bool(counter.get("can_appraise", false)) and typeof(counter.get("item")) == TYPE_DICTIONARY:
		var item: String = _item_id(counter["item"])
		actions.append([&"mg.request", {"uid": uid, "item": item}])
		actions.append([&"mg.report", {"uid": uid, "item": item, "result": {"quality_permille": 700,
			"observations": [], "minutes": 1, "measures": {}, "aborted": false}}])
		actions.append([&"mg.report", {"uid": uid, "item": item, "result": {"quality_permille": 0,
			"observations": [], "minutes": 0, "measures": {}, "aborted": true}}])
	return actions


static func _slot_actions(engine: CardEngineApi, view: Dictionary, uid: String, demand: bool) -> Array:
	var slots: Dictionary = engine.query(&"slots", {"uid": uid})
	var actions: Array = []
	for slot in slots.get("slots", []):
		for index in range(slot.get("placed", []).size()):
			actions.append([&"slot.remove", {"uid": uid, "slot": slot.get("id", ""), "index": index}])
		if slot.get("placed", []).size() >= int(slot.get("max", 1)):
			continue
		for kind in slot.get("accepts", []):
			for source in _sources(engine, view, str(kind)):
				actions.append([&"slot.place", {"uid": uid, "slot": slot.get("id", ""), "source": source}])
	if bool(slots.get("ready", false)):
		actions.append([&"demand.submit" if demand else &"slot.roll", {"uid": uid}])
	if demand:
		actions.append([&"demand.delay", {"uid": uid}])
	return actions


static func _sources(engine: CardEngineApi, view: Dictionary, kind: String) -> Array:
	if kind == "self":
		return [] if bool(view.get("self", {}).get("used_today", false)) else [{"kind": "self"}]
	if kind == "money":
		var amount: int = mini(10, int(view.get("money", {}).get("amount", 0)))
		return [{"kind": "money", "amount": amount}] if amount > 0 else []
	var sources: Array = []
	if kind == "item":
		for item in engine.query(&"stock").get("items", []):
			sources.append({"kind": "item", "item": _item_id(item)})
	else:
		var zone: String = "contacts" if kind == "contact" else "kept"
		for card in view.get(zone, []):
			if bool(card.get("used_today", false)) or int(card.get("away_days", 0)) > 0:
				continue
			if kind != "news" or str(card.get("type", "")) == "news":
				sources.append({"kind": kind, "uid": card.get("uid", "")})
	return sources


static func _wheel_actions(engine: CardEngineApi, view: Dictionary, uid: String, wheel_id: String) -> Array:
	var args: Dictionary = {"uid": uid, "wheel": wheel_id}
	var wheel: Dictionary = engine.query(&"wheel", args)
	if wheel.is_empty() or bool(wheel.get("spun", false)):
		return []
	var actions: Array = [[&"wheel.spin", args]]
	for source in _sources(engine, view, "money") + _sources(engine, view, "contact") + _sources(engine, view, "kept"):
		var offer: Dictionary = args.duplicate()
		offer["source"] = source
		actions.append([&"wheel.offer", offer])
	for index in range(wheel.get("incense", {}).get("placed", []).size()):
		var withdraw: Dictionary = args.duplicate()
		withdraw["index"] = index
		actions.append([&"wheel.withdraw", withdraw])
	if bool(wheel.get("cost", {}).get("stake", false)):
		for kept in view.get("kept", []):
			var stake: Dictionary = args.duplicate()
			stake["kept_uid"] = kept.get("uid", "")
			actions.append([&"wheel.stake", stake])
	return actions


static func _item_id(item: Variant) -> String:
	return str(item.get("item", "")) if typeof(item) == TYPE_DICTIONARY else str(item)
