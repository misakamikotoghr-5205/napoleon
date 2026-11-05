# 九种策略的可见信息决策器；只读门面的 view/query，只提出指令。
# G06；合同 §7.9、§12.6。种子由构造传入，随机域固定 c.ai.<policy>。
# 肉鸽 v1（RG6，docs/cards/rogue/ROGUE_V1.md §14）：盘账叠层开着时按策略口味排 stock.pick；货郎的 look 排在 send_off 前；
# 新策略 trader（不为柜台押家当）与 idle（只白拿盘账第一样，其余同 refuser）在 policies/ 里。
class_name CardPolicy
extends RefCounted

## Rogue v1 (ROGUE_V1.md §14 RG6): the peddler's "have a look" choice and each policy's stocktake taste.
const LOOK_CHOICE := "look"
const STOCK_DEPTHS: Array = ["treasure", "storied", "plain"]
const STOCK_TRADER_SOURCES: Array = ["ky.traveling_buyers", "ky.needy_neighbors"]
const STOCK_KIND_SOURCES: Array = ["ky.old_customers", "ky.needy_neighbors"]

var _seed: int = 0
var _step: int = 0
var _tried: Dictionary = {}
var _mg_state: Dictionary = {}
var _lot_seen: Dictionary = {}
var _cezi_seen: Dictionary = {}
var _choice_selected: Dictionary = {}
var _decision_key: String = ""


func _init(seed_value: int = 0) -> void:
	_seed = seed_value


func policy_name() -> StringName:
	return &"fair"


func decide(engine: CardEngineApi, view: Dictionary) -> Array:
	_step += 1
	var state_key: String = _state_key(view)
	_decision_key = state_key
	var candidates: Array = _candidates(engine, view)
	var available: Array = []
	for action in candidates:
		var key: String = state_key + _action_key(action)
		if not _tried.has(key):
			available.append(action)
	if available.is_empty():
		return []
	var pick: int = 0
	if policy_name() == &"random":
		pick = mini(available.size() - 1,
			int(JevRng.draw(_seed, "c.ai.random", [_seed, _step]) * available.size()))
	var chosen: Array = available[pick]
	_tried[state_key + _action_key(chosen)] = true
	if chosen[0] == &"card.choose":
		_choice_selected[str(chosen[1].get("uid", ""))] = str(chosen[1].get("choice", ""))
	elif chosen[0] == &"mg.request":
		_mg_state[str(chosen[1].get("uid", ""))] = "requested"
	elif chosen[0] == &"fortune.cezi":
		_cezi_seen[str(chosen[1].get("uid", "")) + ":" + str(chosen[1].get("char", ""))] = true
	elif chosen[0] == &"fortune.lot":
		_lot_seen[str(chosen[1].get("uid", ""))] = true
	elif chosen[0] == &"mg.report":
		_mg_state[str(chosen[1].get("uid", ""))] = "done"
	return chosen


func _candidates(engine: CardEngineApi, view: Dictionary) -> Array:
	var out: Array = []
	for pending in view.get("pending", []):
		if str(pending.get("status", "")) == "overflow" and str(pending.get("type", "")) != "contact":
			out.append([&"card.discard", {"uid": pending.get("uid", "")}])
	if not out.is_empty():
		return out
	var phase: String = str(view.get("phase", ""))
	var panel: Dictionary = view.get("open_panel", {})
	var kind: String = str(panel.get("kind", ""))
	var args: Dictionary = panel.get("args", {})
	if kind == "short":
		var short_view: Dictionary = engine.query(&"short")
		var routes: Array = short_view.get("options", []).duplicate()
		if policy_name() == &"refuser":
			routes = ["default"]
		for route in routes:
			var action: Dictionary = {"source": short_view.get("source", ""), "by": route}
			if route == "goods" and not short_view.get("goods", []).is_empty():
				action["item"] = short_view["goods"][0].get("item", "")
			elif route == "estate" and not short_view.get("estates", []).is_empty():
				action["estate"] = short_view["estates"][0].get("id", "")
			out.append([&"short.resolve", action])
	elif kind == "kept_full":
		out.append([&"card.discard", {"uid": args.get("new_uid", "")}])
	elif kind == "contacts_full":
		var contacts: Array = view.get("contacts", [])
		if not contacts.is_empty():
			out.append([&"contact.release", {"uid": contacts[0].get("uid", "")}])
	elif kind == "wheel":
		out.append_array(_wheel(engine, view, args))
	elif kind == "stocktake":
		out.append_array(_stocktake(engine, args))
	match phase:
		"month_open":
			if kind != "wheel":
				out.append_array(_wheel(engine, view, {"wheel": "wh.month", "uid": ""}))
			out.append([&"month.begin", {}])
		"morning": out.append([&"day.begin", {}])
		"day":
			if policy_name() != &"refuser":
				out.append_array(_day(engine, view))
			out.append([&"day.end", {"confirm": true}])
		"night":
			if view.get("night_offers", []).is_empty():
				out.append([&"night.choose", {"def": ""}])
			out.append_array(_night_actions(view))
		"settle": out.append([&"settle.next", {}])
		"month_close": out.append([&"month.next", {}])
		"year_jump": out.append([&"year.next", {}])
	return out


func _night_actions(view: Dictionary) -> Array:
	var out: Array = []
	for offer in view.get("night_offers", []):
		var def_id: String = str(offer.get("def", "")) if typeof(offer) == TYPE_DICTIONARY else str(offer)
		var choices: Array = offer.get("choices", []) if typeof(offer) == TYPE_DICTIONARY else []
		if choices.is_empty():
			out.append([&"night.choose", {"def": def_id}])
			continue
		for choice in choices:
			var choice_id: String = str(choice.get("id", "")) if typeof(choice) == TYPE_DICTIONARY else str(choice)
			if not choice_id.is_empty():
				out.append([&"night.choose", {"def": def_id, "choice": choice_id}])
	return out


func _day(engine: CardEngineApi, view: Dictionary) -> Array:
	var out: Array = []
	if str(view.get("mode", "")) == "street" and int(view.get("money", {}).get("amount", 0)) >= _shop_price(view):
		out.append([&"street.redeem_shop", {}])
		if _fresh(out):
			return out
		out.clear()
	var cards: Array = view.get("hand", []).duplicate()
	cards.append_array(view.get("demands", []))
	for card in cards:
		var uid: String = str(card.get("uid", ""))
		if policy_name() == &"hoarder" and bool(card.get("keepable", false)):
			out.append([&"card.keep", {"uid": uid}])
			if _fresh(out):
				return out
			out.clear()
			continue
		var panel: String = str(card.get("panel", ""))
		var detailed: Dictionary = {}
		if panel == "" or panel == "wheel" or not (panel in ["counter", "fortune", "read"]):
			detailed = engine.query(&"card", {"uid": uid})
			if detailed.has("card"):
				detailed = detailed["card"]
			if panel == "":
				panel = str(detailed.get("panel", ""))
		if panel == "counter":
			if policy_name() == &"hoarder" and str(card.get("intent", "")) == "buy":
				continue
			out.append_array(_counter(engine, uid, view))
		elif panel == "wheel":
			var wheel_id: String = str(detailed.get("wheel", "wh.big"))
			out.append_array(_wheel(engine, view, {"uid": uid, "wheel": wheel_id}))
		elif panel == "fortune":
			var fortune: Dictionary = engine.query(&"fortune", {"uid": uid})
			if str(fortune.get("last", {}).get("lot", "")) == "":
				if not _lot_seen.has(uid):
					out.append([&"fortune.lot", {"uid": uid}])
				for char_id in fortune.get("cezi", []):
					if not _cezi_seen.has(uid + ":" + str(char_id)):
						out.append([&"fortune.cezi", {"uid": uid, "char": char_id}])
		elif panel == "read":
			out.append([&"card.read", {"uid": uid}])
		else:
			var choices: Array = detailed.get("choices", []).duplicate()
			choices.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
				return _choice_score(str(a.get("id", ""))) > _choice_score(str(b.get("id", ""))))
			for choice in choices:
				if bool(choice.get("enabled", true)) and not _choice_selected.has(uid):
					out.append([&"card.choose", {"uid": uid, "choice": str(choice.get("id", ""))}])
			out.append_array(_slots(engine, uid, view, str(detailed.get("type", "")) == "demand",
				int(detailed.get("amount", 0))))
		if _fresh(out):
			return out
		out.clear()
	return out


## Higher sorts first. A preferred word scores 2 per rank (the pre-rogue scores doubled, so every comparison between
## choice ids that existed before is unchanged); the peddler's exact "look" scores 1, so it beats "send_off" and every
## other unmatched id but never a preferred word (ROGUE_V1.md §14 RG6).
func _choice_score(choice_id: String) -> int:
	var preferred: Array = ["fair", "accept", "help"]
	if policy_name() == &"greedy":
		preferred = ["harsh", "squeeze", "demand", "refuse"]
	elif policy_name() == &"kind":
		preferred = ["kind", "give", "free", "help"]
	for word in preferred:
		if choice_id.contains(str(word)):
			return 2 * (preferred.size() - preferred.find(word))
	return 1 if choice_id == LOOK_CHOICE else 0


## Rogue v1 stocktake overlay (ROGUE_V1.md §4.2, §4.3, §7.2): one stock.pick per offered item in this policy's order
## (a relic while the curio shelf is full replaces the oldest held one), then the explicit pass. Refuser never picks.
func _stocktake(engine: CardEngineApi, args: Dictionary) -> Array:
	if engine == null or policy_name() == &"refuser":
		return []
	var query_args: Dictionary = {}
	if str(args.get("offer", "")) != "":
		query_args["offer"] = str(args.get("offer", ""))
	var offer: Dictionary = engine.query(&"stocktake", query_args)
	if not bool(offer.get("ok", false)) or str(offer.get("status", "")) != "open":
		return []
	var offer_id: String = str(offer.get("offer", ""))
	var held: Array = offer.get("held", [])
	var replace: String = ""
	if bool(offer.get("full", false)) and not held.is_empty() and typeof(held[0]) == TYPE_DICTIONARY:
		replace = str(held[0].get("id", ""))
	var out: Array = []
	for item in _stock_order(offer.get("items", [])):
		var pick: Dictionary = {"offer": offer_id, "pick": str(item.get("id", ""))}
		if replace != "" and str(item.get("kind", "")) == "relic":
			pick["replace"] = replace
		out.append([&"stock.pick", pick])
	out.append([&"stock.pick", {"offer": offer_id, "pick": ""}])
	return out


## Stable sort of the offered items by _stock_rank (ties keep the offer's own order).
func _stock_order(items: Array) -> Array:
	var keyed: Array = []
	for index in range(items.size()):
		if typeof(items[index]) == TYPE_DICTIONARY:
			keyed.append([_stock_rank(items[index]), index, items[index]])
	keyed.sort_custom(func(a: Array, b: Array) -> bool:
		return int(a[0]) < int(b[0]) or (int(a[0]) == int(b[0]) and int(a[1]) < int(b[1])))
	var out: Array = []
	for row in keyed:
		out.append(row[2])
	return out


## Lower ranks first. fair / wheel / random / idle keep the offer's order; greedy and trader take relics first (the
## deeper the better), then the buyer and pawner sources; hoarder takes relics first; kind takes sources first, old
## customers and needy neighbours before the rest.
func _stock_rank(item: Dictionary) -> int:
	var relic: bool = str(item.get("kind", "")) == "relic"
	var id: String = str(item.get("id", ""))
	match policy_name():
		&"greedy", &"trader":
			if relic:
				var depth: int = STOCK_DEPTHS.find(str(item.get("depth", "")))
				return depth if depth >= 0 else STOCK_DEPTHS.size()
			return 10 + _preferred_rank(STOCK_TRADER_SOURCES, id)
		&"hoarder":
			return 0 if relic else 1
		&"kind":
			return 10 if relic else _preferred_rank(STOCK_KIND_SOURCES, id)
	return 0


func _preferred_rank(preferred: Array, id: String) -> int:
	var rank: int = preferred.find(id)
	return rank if rank >= 0 else preferred.size()


func _counter(engine: CardEngineApi, uid: String, view: Dictionary) -> Array:
	var counter: Dictionary = engine.query(&"counter", {"uid": uid})
	if not counter.has("intent"):
		return [[&"counter.open", {"uid": uid}]]
	var tier: String = "harsh" if policy_name() == &"greedy" else "kind" if policy_name() == &"kind" else "fair"
	var out: Array = []
	if str(counter.get("intent", "")) == "redeem":
		out.append([&"counter.redeem", {"uid": uid, "mode": "squeeze" if policy_name() == &"greedy" else "by_rule"}])
	elif str(counter.get("last_reply", "")) == "counter":
		out.append([&"counter.answer", {"uid": uid, "accept": policy_name() != &"greedy"}])
	else:
		var stock: Array = counter.get("stock", [])
		if str(counter.get("intent", "")) == "buy" and not stock.is_empty():
			out.append([&"counter.pick_stock", {"uid": uid, "item": _item_id(stock[0])}])
		if bool(counter.get("can_appraise", false)) and str(_mg_state.get(uid, "")) != "done" \
				and typeof(counter.get("item")) == TYPE_DICTIONARY:
			var item: String = str(counter.get("item", {}).get("item", ""))
			if str(_mg_state.get(uid, "")) == "requested":
				out.append([&"mg.report", {"uid": uid, "item": item, "result": {
					"quality_permille": 700, "observations": [], "minutes": 1, "measures": {}, "aborted": false}}])
			else:
				out.append([&"mg.request", {"uid": uid, "item": item}])
		out.append([&"counter.offer", {"uid": uid, "tier": tier}])
	if int(view.get("money", {}).get("amount", 0)) < int(counter.get("tiers", {}).get(tier, 0)):
		for estate in view.get("estates", []):
			if str(estate.get("status", "")) == "held":
				out.append([&"estate.mortgage", {"estate": estate.get("id", "")}])
	out.append([&"counter.refuse", {"uid": uid}])
	return out


func _slots(engine: CardEngineApi, uid: String, view: Dictionary, is_demand: bool = false,
		demand_amount: int = 0) -> Array:
	var slots: Dictionary = engine.query(&"slots", {"uid": uid})
	slots["amount"] = demand_amount
	var out: Array = []
	for slot in slots.get("slots", []):
		if slot.get("placed", []).size() >= int(slot.get("max", 1)):
			continue
		for kind in slot.get("accepts", []):
			for source in _sources(str(kind), engine, view, slots, is_demand):
				out.append([&"slot.place", {"uid": uid, "slot": slot.get("id", ""), "source": source}])
	if bool(slots.get("ready", false)):
		out.append([&"demand.submit" if is_demand else &"slot.roll", {"uid": uid}])
	if is_demand:
		out.append([&"demand.delay", {"uid": uid}])
	return out


func _wheel(engine: CardEngineApi, view: Dictionary, args: Dictionary) -> Array:
	var query_args: Dictionary = {"wheel": args.get("wheel", "wh.month"), "uid": args.get("uid", "")}
	var wheel: Dictionary = engine.query(&"wheel", query_args)
	if bool(wheel.get("spun", false)):
		return []
	var out: Array = []
	if policy_name() == &"wheel" and not bool(wheel.get("incense", {}).get("full", false)):
		for pair in [["contacts", "contact"], ["kept", "kept"]]:
			for card in view.get(pair[0], []):
				var offer: Dictionary = query_args.duplicate()
				offer["source"] = {"kind": pair[1], "uid": card.get("uid", "")}
				out.append([&"wheel.offer", offer])
		if int(view.get("money", {}).get("amount", 0)) >= 10:
			var offer: Dictionary = query_args.duplicate()
			offer["source"] = {"kind": "money", "amount": 10}
			out.append([&"wheel.offer", offer])
	if bool(wheel.get("cost", {}).get("stake", false)) and str(wheel.get("staked", "")) == "":
		for card in view.get("kept", []):
			var stake: Dictionary = query_args.duplicate()
			stake["kept_uid"] = card.get("uid", "")
			out.append([&"wheel.stake", stake])
	out.append([&"wheel.spin", query_args])
	return out


func _item_id(item: Variant) -> String:
	return str(item.get("item", "")) if typeof(item) == TYPE_DICTIONARY else str(item)


func _state_key(view: Dictionary) -> String:
	return "%d:%s:%d:" % [int(view.get("date", {}).get("abs_day", 0)), str(view.get("phase", "")), view.hash()]


func _action_key(action: Array) -> String:
	return "%s:%d" % [str(action[0]), (action[1] as Dictionary).hash()]


func _fresh(actions: Array) -> bool:
	for action in actions:
		if not _tried.has(_decision_key + _action_key(action)):
			return true
	return false


func _shop_price(view: Dictionary) -> int:
	for estate in view.get("estates", []):
		if str(estate.get("id", "")) == "es.shopfront":
			return int(estate.get("money", 400))
	return 400


func _sources(kind: String, engine: CardEngineApi, view: Dictionary, slots: Dictionary, is_demand: bool) -> Array:
	if kind == "self":
		return [] if bool(view.get("self", {}).get("used_today", false)) else [{"kind": "self"}]
	if kind == "money":
		var money: int = int(view.get("money", {}).get("amount", 0))
		var demand_cash: int = int(slots.get("amount", 0))
		var amount: int = mini(money, demand_cash) if is_demand and demand_cash > 0 else money if is_demand \
			else mini(money, maxi(20, int(slots.get("need", 1)) * 20))
		return [{"kind": "money", "amount": amount}] if amount > 0 else []
	var out: Array = []
	if kind == "item":
		for item in engine.query(&"stock").get("items", []):
			out.append({"kind": kind, "item": _item_id(item)})
	else:
		var zone: String = "contacts" if kind == "contact" else "kept"
		for card in view.get(zone, []):
			if bool(card.get("used_today", false)) or int(card.get("away_days", 0)) > 0:
				continue
			if kind == "news" and str(card.get("type", "")) != "news":
				continue
			out.append({"kind": kind, "uid": card.get("uid", "")})
	return out
